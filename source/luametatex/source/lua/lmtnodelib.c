/*
    See license.txt in the root of this project.
*/

/*tex

    This module is one of the backbones on \LUAMETATEX. It has gradually been extended based on
    experiences in \CONTEXT\ \MKIV\ and later \LMTX. There are many helpers here and the main
    reason is that the more callbacks one enables and the more one does in them, the larger the
    impact on performance.

    After doing lots of tests with \LUATEX\ and \LUAJITTEX, with and without jit, and with and
    without ffi, I came to the conclusion that userdata prevents a speedup. I also found that the
    checking of metatables as well as assignment comes with overhead that can't be neglected. This
    is normally not really a problem but when processing fonts for more complex scripts it's quite
    some  overhead. So \unknown\ direct nodes were introduced (we call them nuts in \CONTEXT).

    Because the userdata approach has some benefits, we keep that interface too. We did some
    experiments with fast access (assuming nodes), but eventually settled for the direct approach.
    For code that is proven to be okay, one can use the direct variants and operate on nodes more
    directly. Currently these are numbers but don't rely on that property; treat them aslhmin

    abstractions. An important aspect is that one cannot mix both methods, although with |tonode|
    and |todirect| one can cast representations.

    So the advice is: use the indexed (userdata) approach when possible and investigate the direct
    one when speed might be an issue. For that reason we also provide some get* and set* functions
    in the top level node namespace. There is a limited set of getters for nodes and a generic
    getfield to complement them. The direct namespace has a few more.

    Keep in mind that such speed considerations only make sense when we're accessing nodes millions
    of times (which happens in font processing for instance). Setters are less important as
    documents have not that many content related nodes and setting many thousands of properties is
    hardly a burden contrary to millions of consultations. And with millions, we're talking of tens
    of millions which is not that common.

    Another change is that |__index| and |__newindex| are (as expected) exposed to users but do no
    checking. The getfield and setfield functions do check. In fact, a fast mode can be simulated
    by fast_getfield = __index but the (measured) benefit on average runs is not that large (some
    5\% when we also use the other fast ones) which is easily nilled by inefficient coding. The
    direct variants on the other hand can be significantly faster but with the drawback of lack of
    userdata features. With respect to speed: keep in mind that measuring a speedup on these
    functions is not representative for a normal run, where much more happens.

    A user should beware of the fact that messing around with |prev|, |next| and other links can
    lead to crashes. Don't complain about this: you get what you ask for. Examples are bad loops
    in nodes lists that make the program run out of stack space.

    The code below differs from the \LUATEX\ code in that it drops some userdata related
    accessors. These can easily be emulates in \LUA, which is what we do in \CONTEXT\ \LMTX. Also,
    some optimizations, like using macros and dedicated |getfield| and |setfield| functions for
    userdata and direct nodes were removed because on a regular run there is not much impact and
    the less code we have, the better. In the early days of \LUATEX\ it really did improve the
    overall performance but computers (as well as compilers) have become better. But still, it
    could be that \LUATEX\ has a better performance here; so be it. A performance hit can also be
    one of the side effects of the some more rigourous testing of direct node validity introduced
    here.

    Attribute nodes are special as their prev and subtype fields are used for other purposes.
    Setting them can confuse the checkers but we don't check each case for performance reasons.
    Messing a list up is harmless and only affects functionality which is the users responsibility
    anyway.

    In \LUAMETATEX\ nodes can have different names and properties as in \LUATEX. Some might be
    backported but that is kind of dangerous as macro packages other than \CONTEXT\ depend on
    stability of \LUATEX. (It's one of the reasons for \LUAMETATEX\ being around: it permits us
    to move on).

    Todo: getters/setters for leftovers.

*/

/*
    direct_prev_id(n) => returns prev and id
    direct_next_id(n) => returns next and id
*/

# include "luametatex.h"

/* # define NODE_METATABLE_INSTANCE   "node.instance" */
/* # define NODE_PROPERTIES_DIRECT    "node.properties" */
/* # define NODE_PROPERTIES_INDIRECT  "node.properties.indirect" */
/* # define NODE_PROPERTIES_INSTANCE  "node.properties.instance" */

/*tex

    There is a bit of checking for validity of direct nodes but of course one can still create
    havoc by using flushed nodes, setting bad links, etc.

    Although we could gain a little by moving the body of the valid checker into the caller (that
    way the field variables might be shared) there is no real measurable gain in that on a regular
    run. So, in the end I settled for function calls.

*/

halfword lmt_check_isdirect(lua_State *L, int i)
{
    halfword n = lmt_tohalfword(L, i);
    return n && _valid_node_(n) ? n : null;
}

inline static halfword nodelib_valid_direct_from_index(lua_State *L, int i)
{
    halfword n = lmt_tohalfword(L, i);
    return n && _valid_node_(n) ? n : null;
}

inline static void nodelib_push_direct_or_nil(lua_State *L, halfword n)
{
    if (n) {
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
}

inline static void nodelib_push_direct_or_nil_node_prev(lua_State *L, halfword n)
{
    if (n) {
        node_prev(n) = null;
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
}

inline static void nodelib_push_node_on_top(lua_State *L, halfword n)
{
     *(halfword *) lua_newuserdatauv(L, sizeof(halfword), 0) = n;
     lua_getmetatable(L, -2);
     lua_setmetatable(L, -2);
}

/*tex
    Many of these small functions used to be macros but that no longer pays off because compilers
    became better (for instance at deciding when to inline small functions). We could have explicit
    inline variants of these too but normally the compiler will inline small functions anyway.

*/

static halfword lmt_maybe_isnode(lua_State *L, int i)
{
    halfword *p = lua_touserdata(L, i);
    halfword n = null;
    if (p && lua_getmetatable(L, i)) {
        lua_get_metatablelua(node_instance);
        if (lua_rawequal(L, -1, -2)) {
            n = *p;
        }
        lua_pop(L, 2);
    }
    return n;
}

halfword lmt_check_isnode(lua_State *L, int i)
{
    halfword n = lmt_maybe_isnode(L, i);
    if (! n) {
     // formatted_error("node lib", "lua <node> expected, not an object with type %s", luaL_typename(L, i));
        luaL_error(L, "invalid node");
    }
    return n;
}

/* helpers */

static void nodelib_push_direct_or_node(lua_State *L, int direct, halfword n)
{
    if (n) {
        if (direct) {
            lua_pushinteger(L, n);
        } else {
            *(halfword *) lua_newuserdatauv(L, sizeof(halfword), 0) = n;
            lua_getmetatable(L, 1);
            lua_setmetatable(L, -2);
        }
    } else {
        lua_pushnil(L);
    }
}

static void nodelib_push_direct_or_node_node_prev(lua_State *L, int direct, halfword n)
{
    if (n) {
        node_prev(n) = null;
        if (direct) {
            lua_pushinteger(L, n);
        } else {
            *(halfword *) lua_newuserdatauv(L, sizeof(halfword), 0) = n;
            lua_getmetatable(L, 1);
            lua_setmetatable(L, -2);
        }
    } else {
        lua_pushnil(L);
    }
}

static halfword nodelib_direct_or_node_from_index(lua_State *L, int direct, int i)
{
    if (direct) {
        return nodelib_valid_direct_from_index(L, i);
    } else if (lua_isuserdata(L, i)) {
        return lmt_check_isnode(L, i);
    } else {
        return null;
    }
}

halfword lmt_check_isdirectornode(lua_State *L, int i, int *isdirect)
{
    *isdirect = ! lua_isuserdata(L, i);
    return *isdirect ? nodelib_valid_direct_from_index(L, i) : lmt_check_isnode(L, i);
}

static void nodelib_push_attribute_data(lua_State* L, halfword n)
{
    if (node_type(n) == attribute_list_subtype) {
        lua_newtable(L);
        n = node_next(n);
        while (n) {
            lua_pushinteger(L, attribute_value(n));
            lua_rawseti(L, -2, attribute_index(n));
            n = node_next(n);
        }
    } else {
        lua_pushnil(L);
    }
}

/*tex Another shortcut: */

inline static singleword nodelib_getdirection(lua_State *L, int i)
{
    return ((lua_type(L, i) == LUA_TNUMBER) ? (singleword) checked_direction_value(lmt_tohalfword(L, i)) : direction_def_value);
}

/*tex

    This routine finds the numerical value of a string (or number) at \LUA\ stack index |n|. If it
    is not a valid node type |-1| is returned.

*/

static quarterword nodelib_aux_get_node_type_id_from_name(lua_State *L, int n, node_info *data)
{
    if (data) {
        const char *s = lua_tostring(L, n);
        for (int j = 0; data[j].id != -1; j++) {
            if (s == data[j].name) {
                if (data[j].visible) {
                    return (quarterword) j;
                } else {
                    break;
                }
            }
        }
    }
    return unknown_node;
}

static quarterword nodelib_aux_get_node_subtype_id_from_name(lua_State *L, int n, value_info *data)
{
    if (data) {
        const char *s = lua_tostring(L, n);
        for (quarterword j = 0; data[j].id != -1; j++) {
            if (s == data[j].name) {
                return j;
            }
        }
    }
    return unknown_subtype;
}

static quarterword nodelib_aux_get_field_index_from_name(lua_State *L, int n, value_info *data)
{
    if (data) {
        const char *s = lua_tostring(L, n);
        for (quarterword j = 0; data[j].name; j++) {
            if (s == data[j].name) {
                return j;
            }
        }
    }
    return unknown_field;
}

static quarterword nodelib_aux_get_valid_node_type_id(lua_State *L, int n)
{
    quarterword i = unknown_node;
    switch (lua_type(L, n)) {
        case LUA_TSTRING:
            i = nodelib_aux_get_node_type_id_from_name(L, n, lmt_interface.node_data);
            if (i == unknown_node) {
                luaL_error(L, "invalid node type id: %s", lua_tostring(L, n));
            }
            break;
        case LUA_TNUMBER:
            i = lmt_toquarterword(L, n);
            if (! tex_nodetype_is_visible(i)) {
                luaL_error(L, "invalid node type id: %d", i);
            }
            break;
        default:
            luaL_error(L, "invalid node type id");
    }
    return i;
}

int lmt_get_math_style(lua_State *L, int n, int dflt)
{
    int i = -1;
    switch (lua_type(L, n)) {
        case LUA_TNUMBER:
            i = lmt_tointeger(L, n);
            break;
        case LUA_TSTRING:
            i = nodelib_aux_get_field_index_from_name(L, n, lmt_interface.math_style_values);
            break;
    }
    if (i >= 0 && i <= cramped_script_script_style) {
        return i;
    } else {
        return dflt;
    }
}

int lmt_get_math_parameter(lua_State *L, int n, int dflt)
{
    int i;
    switch (lua_type(L, n)) {
        case LUA_TNUMBER:
            i = lmt_tointeger(L, n);
            break;
        case LUA_TSTRING:
            i = nodelib_aux_get_field_index_from_name(L, n, lmt_interface.math_parameter_values);
            break;
        default: 
            i = -1;
            break;
    }
    if (i >= 0 && i < math_parameter_last) {
        return i;
    } else {
        return dflt;
    }
}

/*tex

    Creates a userdata object for a number found at the stack top, if it is representing a node
    (i.e. an pointer into |varmem|). It replaces the stack entry with the new userdata, or pushes
    |nil| if the number is |null|, or if the index is definately out of range. This test could be
    improved.

*/

void lmt_push_node(lua_State *L)
{
    halfword n = null;
    if (lua_type(L, -1) == LUA_TNUMBER) {
        n = lmt_tohalfword(L, -1);
    }
    lua_pop(L, 1);
    if ((! n) || (n > lmt_node_memory_state.nodes_data.allocated)) {
        lua_pushnil(L);
    } else {
        halfword *a = lua_newuserdatauv(L, sizeof(halfword), 0);
        *a = n;
        lua_get_metatablelua(node_instance);
        lua_setmetatable(L, -2);
    }
    return;
}

void lmt_push_node_fast(lua_State *L, halfword n)
{
    if (n) {
        halfword *a = lua_newuserdatauv(L, sizeof(halfword), 0);
        *a = n;
        lua_get_metatablelua(node_instance);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }
}

void lmt_push_directornode(lua_State *L, halfword n, int isdirect)
{
    if (! n) {
        lua_pushnil(L);
    } else if (isdirect) { 
        lua_push_integer(L, n);
    } else {
        lmt_push_node_fast(L, n);
    }
}

/*tex getting and setting fields (helpers) */

static int nodelib_getlist(lua_State *L, int n)
{
    if (lua_isuserdata(L, n)) {
        return lmt_check_isnode(L, n);
    } else {
        return null;
    }
}

/*tex converts type strings to type ids */

static int nodelib_shared_id(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        int i = nodelib_aux_get_node_type_id_from_name(L, 1, lmt_interface.node_data);
        if (i >= 0) {
            lua_pushinteger(L, i);
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.getid */

static int nodelib_direct_getid(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        lua_pushinteger(L, node_type(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.getsubtype */
/* node.direct.setsubtype */

static int nodelib_direct_getsubtype(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        lua_pushinteger(L, node_subtype(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setsubtype(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && lua_type(L, 2) == LUA_TNUMBER) {
        node_subtype(n) = lmt_toquarterword(L, 2);
    }
    return 0;
}

/* node.direct.getexpansion */
/* node.direct.setexpansion */

static int nodelib_direct_getexpansion(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_expansion(n));
                break;
            case kern_node:
                lua_pushinteger(L, kern_expansion(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setexpansion(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword e = 0;
        if (lua_type(L, 2) == LUA_TNUMBER) {
            e = (halfword) lmt_roundnumber(L, 2);
        }
        switch (node_type(n)) {
            case glyph_node:
                glyph_expansion(n) = e;
                break;
            case kern_node:
                kern_expansion(n) = e;
                break;
        }
    }
    return 0;
}

/* node.direct.getfont */
/* node.direct.setfont */

static int nodelib_direct_getfont(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_font(n));
                break;
            case glue_node:
                lua_pushinteger(L, glue_font(n));
                break;
            case math_char_node:
            case math_text_char_node:
                lua_pushinteger(L, tex_fam_fnt(kernel_math_family(n), 0));
                break;
            case delimiter_node:
                lua_pushinteger(L, tex_fam_fnt(delimiter_small_family(n), 0));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setfont(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                glyph_font(n) = tex_checked_font(lmt_tohalfword(L, 2));
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    glyph_character(n) = lmt_tohalfword(L, 3);
                }
                break;
            case rule_node:
                tex_set_rule_font(n, lmt_tohalfword(L, 2));
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    rule_character(n) = lmt_tohalfword(L, 3);
                }
                break;
            case glue_node:
                glue_font(n) = tex_checked_font(lmt_tohalfword(L, 2));
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getchardict(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_properties(n));
                lua_pushinteger(L, glyph_group(n));
                lua_pushinteger(L, glyph_index(n));
                lua_pushinteger(L, glyph_font(n));
                lua_pushinteger(L, glyph_character(n));
                return 5;
            case math_char_node:
            case math_text_char_node:
                lua_pushinteger(L, kernel_math_properties(n));
                lua_pushinteger(L, kernel_math_group(n));
                lua_pushinteger(L, kernel_math_index(n));
                lua_pushinteger(L, tex_fam_fnt(kernel_math_family(n),0));
                lua_pushinteger(L, kernel_math_character(n));
                return 5;
        }
    }
    return 0;
}

static int nodelib_direct_setchardict(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                glyph_properties(n) = lmt_optquarterword(L, 2, 0);
                glyph_group(n) = lmt_optquarterword(L, 3, 0);
                glyph_index(n) = lmt_opthalfword(L, 4, 0);
                break;
            case math_char_node:
            case math_text_char_node:
                kernel_math_properties(n) = lmt_optquarterword(L, 2, 0);
                kernel_math_group(n) = lmt_optquarterword(L, 3, 0);
                kernel_math_index(n) = lmt_opthalfword(L, 4, 0);
                break;
        }
    }
    return 0;
}

/* node.direct.getchar */
/* node.direct.setchar */

static int nodelib_direct_getchar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch(node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_character(n));
                break;
            case rule_node:
                lua_pushinteger(L, rule_character(n));
                break;
            case math_char_node:
            case math_text_char_node:
                lua_pushinteger(L, kernel_math_character(n));
                break;
            case delimiter_node:
                 /* used in wide fonts */
                lua_pushinteger(L, delimiter_small_character(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setchar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && lua_type(L, 2) == LUA_TNUMBER) {
        switch (node_type(n)) {
            case glyph_node:
                glyph_character(n) = lmt_tohalfword(L, 2);
                break;
            case rule_node:
                rule_character(n) = lmt_tohalfword(L, 2);
                break;
            case math_char_node:
            case math_text_char_node:
                kernel_math_character(n) = lmt_tohalfword(L, 2);
                break;
            case delimiter_node:
                /* used in wide fonts */
                delimiter_small_character(n) = lmt_tohalfword(L, 2);
                break;
        }
    }
    return 0;
}

/* bonus */

static int nodelib_direct_getcharspec(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
      AGAIN:
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_character(n));
                lua_pushinteger(L, glyph_font(n));
                return 2;
            case rule_node:
                lua_pushinteger(L, rule_character(n));
                lua_pushinteger(L, tex_get_rule_font(n, text_style));
                break;
            case simple_noad: 
                n = noad_nucleus(n);
                if (n) { 
                    goto AGAIN;
                } else { 
                    break;
                }
            case math_char_node:
            case math_text_char_node:
                lua_pushinteger(L, kernel_math_character(n));
                lua_pushinteger(L, tex_fam_fnt(kernel_math_family(n), 0));
                lua_pushinteger(L, kernel_math_family(n));
                return 3;
            case delimiter_node:
                lua_pushinteger(L, delimiter_small_character(n));
                lua_pushinteger(L, tex_fam_fnt(delimiter_small_family(n), 0));
                lua_pushinteger(L, delimiter_small_family(n));
                return 3;
        }
    }
    return 0;
}

/* node.direct.getfam */
/* node.direct.setfam */

static int nodelib_direct_getfam(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch(node_type(n)) {
            case math_char_node:
            case math_text_char_node:
                lua_pushinteger(L, kernel_math_family(n));
                break;
            case delimiter_node:
                lua_pushinteger(L, delimiter_small_family(n));
                break;
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                /*tex Not all are used or useful at the tex end! */
                lua_pushinteger(L, noad_family(n));
                break;
            case rule_node:
                lua_pushinteger(L, tex_get_rule_family(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setfam(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && lua_type(L, 2) == LUA_TNUMBER) {
        switch (node_type(n)) {
            case math_char_node:
            case math_text_char_node:
                kernel_math_family(n) = lmt_tohalfword(L, 2);
                break;
            case delimiter_node:
                delimiter_small_family(n) = lmt_tohalfword(L, 2);
                break;
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                /*tex Not all are used or useful at the tex end! */
                set_noad_family(n, lmt_tohalfword(L, 2));
                break;
            case rule_node:
                tex_set_rule_family(n, lmt_tohalfword(L, 2));
                break;
        }
    }
    return 0;
}

/* node.direct.getstate(n) */
/* node.direct.setstate(n) */

/*tex
    A zero state is considered to be false or basically the same as \quote {unset}. That way we
    can are compatible with an unset property. This is cheaper on testing too. But I might
    reconsider this at some point. (In which case I need to adapt the context source but by then
    we have a lua/lmt split.)
*/

static int nodelib_direct_getstate(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int state = 0;
        switch (node_type(n)) {
            case glyph_node:
                state = get_glyph_state(n);
                break;
            case hlist_node:
            case vlist_node:
                state = box_package_state(n);
                break;
            default:
                goto NOPPES;
        }
        if (lua_type(L, 2) == LUA_TNUMBER) {
            lua_pushboolean(L, lua_tointeger(L, 2) == state);
            return 1;
        } else if (state) {
            lua_pushinteger(L, state);
            return 1;
        } else {
            /*tex Indeed, |nil|. */
        }
    }
  NOPPES:
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setstate(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                set_glyph_state(n, lmt_opthalfword(L, 2, 0));
                break;
            case hlist_node:
            case vlist_node:
                box_package_state(n) = (singleword) lmt_opthalfword(L, 2, 0);
                break;
        }
    }
    return 0;
}

/* node.direct.getclass(n,main,left,right) */
/* node.direct.setclass(n,main,left,right) */

static int nodelib_direct_getclass(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) { 
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                lua_push_integer(L, get_noad_main_class(n)); 
                lua_push_integer(L, get_noad_left_class(n)); 
                lua_push_integer(L, get_noad_right_class(n));
                return 3;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setclass(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) { 
        switch (node_type(n)) { 
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    set_noad_main_class(n, lmt_tohalfword(L, 2)); 
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    set_noad_left_class(n, lmt_tohalfword(L, 3)); 
                }
                if (lua_type(L, 4) == LUA_TNUMBER) {
                    set_noad_right_class(n, lmt_tohalfword(L, 4)); 
                }
                break;
        }
    }
    return 0;
}

/* node.direct.getscript(n) */
/* node.direct.setscript(n) */

static int nodelib_direct_getscript(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node && get_glyph_script(n)) {
        if (lua_type(L, 2) == LUA_TNUMBER) {
            lua_pushboolean(L, lua_tointeger(L, 2) == get_glyph_script(n));
        } else {
            lua_pushinteger(L, get_glyph_script(n));
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setscript(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        set_glyph_script(n, lmt_opthalfword(L, 2, 0));
    }
    return 0;
}

/* node.direct.getlang */
/* node.direct.setlang */

static int nodelib_direct_getlanguage(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, get_glyph_language(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setlanguage(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        set_glyph_language(n, lmt_opthalfword(L, 2, 0));
    }
    return 0;
}

/* node.direct.getattributelist */
/* node.direct.setattributelist */

static int nodelib_direct_getattributelist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && tex_nodetype_has_attributes(node_type(n)) && node_attr(n)) {
        if (lua_toboolean(L, 2)) {
            nodelib_push_attribute_data(L, n);
        } else {
            lua_pushinteger(L, node_attr(n));
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static void nodelib_aux_setattributelist(lua_State *L, halfword n, int index)
{
    if (n && tex_nodetype_has_attributes(node_type(n))) {
        halfword a = null;
        switch (lua_type(L, index)) {
            case LUA_TNUMBER:
                {
                    halfword m = nodelib_valid_direct_from_index(L, index);
                    if (m) {
                        quarterword t = node_type(m);
                        if (t == attribute_node) {
                            if (node_subtype(m) == attribute_list_subtype) {
                              a = m;
                            } else {
                                /* invalid list, we could make a proper one if needed */
                            }
                        } else if (tex_nodetype_has_attributes(t)) {
                            a = node_attr(m);
                        }
                    }
                }
                break;
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, index)) {
                    a = tex_current_attribute_list();
                }
                break;
            case LUA_TTABLE:
                {
                    /* kind of slow because we need a sorted inject */
                    lua_pushnil(L); /* push initial key */
                    while (lua_next(L, index)) {
                        halfword key = lmt_tohalfword(L, -2);
                        halfword val = lmt_tohalfword(L, -1);
                        a = tex_patch_attribute_list(a, key, val);
                        lua_pop(L, 1); /* pop value, keep key */
                    }
                    lua_pop(L, 1); /* pop key */
                }
                break;
        }
        tex_attach_attribute_list_attribute(n, a);
    }
}

static int nodelib_direct_setattributelist(lua_State *L)
{
    nodelib_aux_setattributelist(L, nodelib_valid_direct_from_index(L, 1), 2);
    return 0;
}

/* node.direct.getpenalty */
/* node.direct.setpenalty */

static int nodelib_direct_getpenalty(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case penalty_node:
                lua_pushinteger(L, penalty_amount(n));
                break;
            case disc_node:
                lua_pushinteger(L, disc_penalty(n));
                break;
            case math_node:
                lua_pushinteger(L, math_penalty(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setpenalty(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case penalty_node:
                penalty_amount(n) = (halfword) luaL_optinteger(L, 2, 0);
                break;
            case disc_node:
                disc_penalty(n) = (halfword) luaL_optinteger(L, 2, 0);
                break;
            case math_node:
                math_penalty(n) = (halfword) luaL_optinteger(L, 2, 0);
                break;
        }
    }
    return 0;
}

/* node.direct.getnucleus */
/* node.direct.getsub */
/* node.direct.getsup */

static int nodelib_direct_getnucleus(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_nucleus(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setnucleus(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_nucleus(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getsub(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_subscr(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getsubpre(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_subprescr(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setsub(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_subscr(n) = nodelib_valid_direct_from_index(L, 2);
             // if (lua_gettop(L) > 2) {
             //     noad_subprescr(n) = nodelib_valid_direct_from_index(L, 3);
             // }
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setsubpre(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_subprescr(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getsup(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_supscr(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getsuppre(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_supprescr(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getprime(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_prime(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setsup(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_supscr(n) = nodelib_valid_direct_from_index(L, 2);
             // if (lua_gettop(L) > 2) {
             //     supprescr(n) = nodelib_valid_direct_from_index(L, 3);
             // }
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setsuppre(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_supprescr(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setprime(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_prime(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

/* node.direct.getkern (overlaps with getwidth) */
/* node.direct.setkern (overlaps with getwidth) */

static int nodelib_direct_getkern(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case kern_node:
                lua_pushnumber(L, kern_amount(n));
                if (lua_toboolean(L, 2)) {
                    lua_pushinteger(L, kern_expansion(n));
                    return 2;
                } else {
                    break;
                }
            case math_node:
                lua_pushinteger(L, math_surround(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setkern(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case kern_node:
                kern_amount(n) = lua_type(L, 2) == LUA_TNUMBER ? (halfword) lmt_roundnumber(L, 2) : 0;
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    node_subtype(n) = lmt_toquarterword(L, 3);
                }
                break;
            case math_node:
                math_surround(n) = lua_type(L, 2) == LUA_TNUMBER ? (halfword) lmt_roundnumber(L, 2) : 0;
                break;
        }
    }
    return 0;
}

/* node.direct.getdirection */
/* node.direct.setdirection */

static int nodelib_direct_getdirection(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case dir_node:
                lua_pushinteger(L, dir_direction(n));
                lua_pushboolean(L, node_subtype(n));
                return 2;
            case hlist_node:
            case vlist_node:
                lua_pushinteger(L, checked_direction_value(box_dir(n)));
                break;
            case par_node:
                lua_pushinteger(L, par_dir(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setdirection(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case dir_node:
                dir_direction(n) = nodelib_getdirection(L, 2);
                if (lua_type(L, 3) == LUA_TBOOLEAN) {
                    if (lua_toboolean(L, 3)) {
                        node_subtype(n) = (quarterword) (lua_toboolean(L, 3) ? cancel_dir_subtype : normal_dir_subtype);
                    }
                }
                break;
            case hlist_node:
            case vlist_node:
                box_dir(n) = (singleword) nodelib_getdirection(L, 2);
                break;
            case par_node:
                par_dir(n) = nodelib_getdirection(L, 2);
                break;
        }
    }
    return 0;
}

/* node.direct.getanchors */
/* node.direct.setanchors */

static int nodelib_direct_getanchors(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                if (box_anchor(n)) {
                    lua_pushinteger(L, box_anchor(n));
                } else {
                    lua_pushnil(L);
                }
                if (box_source_anchor(n)) {
                    lua_pushinteger(L, box_source_anchor(n));
                } else {
                    lua_pushnil(L);
                }
                if (box_target_anchor(n)) {
                    lua_pushinteger(L, box_target_anchor(n));
                } else {
                    lua_pushnil(L);
                }
                /* bonus detail: source, target */
                if (box_anchor(n)) {
                    lua_pushinteger(L,  box_anchor(n)        & 0x0FFF);
                } else {
                    lua_pushnil(L);
                }
                if (box_anchor(n)) {
                    lua_pushinteger(L, (box_anchor(n) >> 16) & 0x0FFF);
                } else {
                    lua_pushnil(L);
                }
                return 5;
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                if (noad_source(n)) {
                    lua_pushinteger(L, noad_source(n));
                } else {
                    lua_pushnil(L);
                }
                return 1;
        }
    }
    return 0;
}

static int nodelib_direct_setanchors(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                switch (lua_type(L, 2)) {
                    case LUA_TNUMBER:
                        box_anchor(n) = lmt_tohalfword(L, 2);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 2)) {
                            break;
                        }
                    default:
                        box_anchor(n) = 0;
                        break;
                }
                switch (lua_type(L, 3)) {
                    case LUA_TNUMBER :
                        box_source_anchor(n) = lmt_tohalfword(L, 3);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 3)) {
                            break;
                        }
                    default:
                        box_source_anchor(n) = 0;
                        break;
                }
                switch (lua_type(L, 4)) {
                    case LUA_TNUMBER:
                        box_target_anchor(n) = lmt_tohalfword(L, 4);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 4)) {
                            break;
                        }
                    default:
                        box_target_anchor(n) = 0;
                        break;
                }
                tex_check_box_geometry(n);
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                switch (lua_type(L, 2)) {
                    case LUA_TNUMBER :
                        noad_source(n) = lmt_tohalfword(L, 2);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 2)) {
                            break;
                        }
                    default:
                        noad_source(n) = 0;
                        break;
                }
                tex_check_box_geometry(n);
        }
    }
    return 0;
}

/* node.direct.getxoffset */
/* node.direct.getyoffset */
/* node.direct.getoffsets */
/* node.direct.setxoffset */
/* node.direct.setyoffset */
/* node.direct.setoffsets */

static int nodelib_direct_getoffsets(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_x_offset(n));
                lua_pushinteger(L, glyph_y_offset(n));
                lua_pushinteger(L, glyph_left(n));
                lua_pushinteger(L, glyph_right(n));
                lua_pushinteger(L, glyph_raise(n));
                return 5;
            case hlist_node:
            case vlist_node:
                lua_pushinteger(L, box_x_offset(n));
                lua_pushinteger(L, box_y_offset(n));
                return 2;
            case rule_node:
                lua_pushinteger(L, rule_x_offset(n));
                lua_pushinteger(L, rule_y_offset(n));
                lua_pushinteger(L, rule_left(n));
                lua_pushinteger(L, rule_right(n));
                return 4;
        }
    }
    return 0;
}

static int nodelib_direct_setoffsets(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    glyph_x_offset(n) = (halfword) lmt_roundnumber(L, 2);
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    glyph_y_offset(n) = (halfword) lmt_roundnumber(L, 3);
                }
                if (lua_type(L, 4) == LUA_TNUMBER) {
                    glyph_left(n) = (halfword) lmt_roundnumber(L, 4);
                }
                if (lua_type(L, 5) == LUA_TNUMBER) {
                    glyph_right(n) = (halfword) lmt_roundnumber(L, 5);
                }
                if (lua_type(L, 6) == LUA_TNUMBER) {
                    glyph_raise(n) = (halfword) lmt_roundnumber(L, 6);
                }
                break;
            case hlist_node:
            case vlist_node:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    box_x_offset(n) = (halfword) lmt_roundnumber(L, 2);
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    box_y_offset(n) = (halfword) lmt_roundnumber(L, 3);
                }
                tex_check_box_geometry(n);
                break;
            case rule_node:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    rule_x_offset(n) = (halfword) lmt_roundnumber(L, 2);
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    rule_y_offset(n) = (halfword) lmt_roundnumber(L, 3);
                }
                if (lua_type(L, 4) == LUA_TNUMBER) {
                    rule_left(n) = (halfword) lmt_roundnumber(L, 4);
                }
                if (lua_type(L, 5) == LUA_TNUMBER) {
                    rule_right(n) = (halfword) lmt_roundnumber(L, 5);
                }
                break;
        }
    }
    return 0;
}

static int nodelib_direct_addxoffset(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                glyph_x_offset(n) += (halfword) lmt_roundnumber(L, 2);
                break;
            case hlist_node:
            case vlist_node:
                box_x_offset(n) += (halfword) lmt_roundnumber(L, 2);
                tex_check_box_geometry(n);
                break;
            case rule_node:
                rule_x_offset(n) += (halfword) lmt_roundnumber(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_addyoffset(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                glyph_y_offset(n) += (halfword) lmt_roundnumber(L, 2);
                break;
            case hlist_node:
            case vlist_node:
                box_y_offset(n) += (halfword) lmt_roundnumber(L, 2);
                tex_check_box_geometry(n);
                break;
            case rule_node:
                rule_y_offset(n) += (halfword) lmt_roundnumber(L, 2);
                break;
        }
    }
    return 0;
}

/* */

static int nodelib_direct_addmargins(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    glyph_left(n) += (halfword) lmt_roundnumber(L, 2);
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    glyph_right(n) += (halfword) lmt_roundnumber(L, 3);
                }
                if (lua_type(L, 4) == LUA_TNUMBER) {
                    glyph_raise(n) += (halfword) lmt_roundnumber(L, 3);
                }
                break;
            case rule_node:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    rule_left(n) += (halfword) lmt_roundnumber(L, 2);
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    rule_right(n) += (halfword) lmt_roundnumber(L, 3);
                }
                break;
        }
    }
    return 0;
}

static int nodelib_direct_addxymargins(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        scaled s = glyph_scale(n);
        scaled x = glyph_x_scale(n);
        scaled y = glyph_y_scale(n);
        double sx, sy;
        if (s == 0 || s == 1000) {
            if (x == 0 || x == 1000) {
                sx = 1;
            } else {
                sx = 0.001 * x;
            }
            if (y == 0 || y == 1000) {
                sy = 1;
            } else {
                sy = 0.001 * y;
            }
        } else {
            if (x == 0 || x == 1000) {
                sx = 0.001 * s;
            } else {
                sx = 0.000001 * s * x;
            }
            if (y == 0 || y == 1000) {
                sy = 0.001 * s;
            } else {
                sy = 0.000001 * s * y;
            }
        }
        if (lua_type(L, 2) == LUA_TNUMBER) {
            glyph_left(n) += scaledround(sx * lua_tonumber(L, 2));
        }
        if (lua_type(L, 3) == LUA_TNUMBER) {
            glyph_right(n) += scaledround(sx * lua_tonumber(L, 3));
        }
        if (lua_type(L, 4) == LUA_TNUMBER) {
            glyph_raise(n) += scaledround(sy * lua_tonumber(L, 4));
        }
    }
    return 0;
}

/* node.direct.getscale   */
/* node.direct.getxscale  */
/* node.direct.getyscale  */
/* node.direct.getxyscale */
/* node.direct.setscale   */
/* node.direct.setxscale  */
/* node.direct.setyscale  */
/* node.direct.setxyscale */

static int nodelib_direct_getscale(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, glyph_scale(n));
        return 1;
    }
    return 0;
}

static int nodelib_direct_getscales(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, glyph_scale(n));
        lua_pushinteger(L, glyph_x_scale(n));
        lua_pushinteger(L, glyph_y_scale(n));
        return 3;
    } else {
        return 0;
    }
}

static int nodelib_direct_setscales(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        if (lua_type(L, 2) == LUA_TNUMBER) {
            glyph_scale(n) = (halfword) lmt_roundnumber(L, 2);
            if (! glyph_scale(n)) {
                glyph_scale(n) = 1000;
            }
        }
        if (lua_type(L, 3) == LUA_TNUMBER) {
            glyph_x_scale(n) = (halfword) lmt_roundnumber(L, 3);
            if (! glyph_x_scale(n)) {
                glyph_x_scale(n) = 1000;
            }
        }
        if (lua_type(L, 4) == LUA_TNUMBER) {
            glyph_y_scale(n) = (halfword) lmt_roundnumber(L, 4);
            if (! glyph_y_scale(n)) {
                glyph_y_scale(n) = 1000;
            }
        }
    }
    return 0;
}

static int nodelib_direct_getxscale(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        scaled s = glyph_scale(n);
        scaled x = glyph_x_scale(n);
        double d;
        if (s == 0 || s == 1000) {
            if (x == 0 || x == 1000) {
                goto DONE;
            } else {
                d = 0.001 * x;
            }
        } else if (x == 0 || x == 1000) {
            d = 0.001 * s;
        } else {
            d = 0.000001 * s * x;
        }
        lua_pushnumber(L, d);
        return 1;
    }
  DONE:
    lua_pushinteger(L, 1);
    return 1;
}

static int nodelib_direct_xscaled(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    lua_Number v = lua_tonumber(L, 2);
    if (n && node_type(n) == glyph_node) {
        scaled s = glyph_scale(n);
        scaled x = glyph_x_scale(n);
        if (s == 0 || s == 1000) {
            if (x == 0 || x == 1000) {
                /* okay */
            } else {
                v = 0.001 * x * v;
            }
        } else if (x == 0 || x == 1000) {
            v = 0.001 * s * v;
        } else {
            v = 0.000001 * s * x * v;
        }
    }
    lua_pushnumber(L, v);
    return 1;
}

static int nodelib_direct_getyscale(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        scaled s = glyph_scale(n);
        scaled y = glyph_y_scale(n);
        double d;
        if (s == 0 || s == 1000) {
            if (y == 0 || y == 1000) {
                goto DONE;
            } else {
                d = 0.001 * y;
            }
        } else if (y == 0 || y == 1000) {
            d = 0.001 * s;
        } else {
            d = 0.000001 * s * y;
        }
        lua_pushnumber(L, d);
        return 1;
    }
  DONE:
    lua_pushinteger(L, 1);
    return 1;
}

static int nodelib_direct_yscaled(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    lua_Number v = lua_tonumber(L, 2);
    if (n && node_type(n) == glyph_node) {
        scaled s = glyph_scale(n);
        scaled y = glyph_y_scale(n);
        if (s == 0 || s == 1000) {
            if (y == 0 || y == 1000) {
                /* okay */
            } else {
                v = 0.001 * y * v;
            }
        } else if (y == 0 || y == 1000) {
            v = 0.001 * s * v;
        } else {
            v = 0.000001 * s * y * v;
        }
    }
    lua_pushnumber(L, v);
    return 1;
}

static void nodelib_aux_pushxyscales(lua_State *L, halfword n)
{
    scaled s = glyph_scale(n);
    scaled x = glyph_x_scale(n);
    scaled y = glyph_y_scale(n);
    double dx;
    double dy;
    if (s && s != 1000) {
        dx = (x && x != 1000) ? 0.000001 * s * x : 0.001 * s;
    } else if (x && x != 1000) {
        dx = 0.001 * x;
    } else {
        lua_pushinteger(L, 1);
        goto DONEX;
    }
    lua_pushnumber(L, dx);
  DONEX:
    if (s && s != 1000) {
        dy = (y && y != 1000) ? 0.000001 * s * y : 0.001 * s;
    } else if (y && y != 1000) {
        dy = 0.001 * y;
    } else {
        lua_pushinteger(L, 1);
        goto DONEY;
    }
    lua_pushnumber(L, dy);
  DONEY: ;
}

static int nodelib_direct_getxyscales(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        nodelib_aux_pushxyscales(L, n);
    } else {
        lua_pushinteger(L, 1);
        lua_pushinteger(L, 1);
    }
    return 2;
}

/* node.direct.getdisc */
/* node.direct.setdisc */

/*tex 
    For the moment we don't provide setters for math discretionaries, mainly because these are
    special and I don't want to waste time on checking and intercepting errors. They are not that
    widely used anyway. 
*/

static int nodelib_direct_getdisc(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) { 
        switch (node_type(n)) { 
            case disc_node:
                nodelib_push_direct_or_nil(L, disc_pre_break_head(n));
                nodelib_push_direct_or_nil(L, disc_post_break_head(n));
                nodelib_push_direct_or_nil(L, disc_no_break_head(n));
                if (lua_isboolean(L, 2) && lua_toboolean(L, 2)) {
                    nodelib_push_direct_or_nil(L, disc_pre_break_tail(n));
                    nodelib_push_direct_or_nil(L, disc_post_break_tail(n));
                    nodelib_push_direct_or_nil(L, disc_no_break_tail(n));
                    return 6;
                } else {
                    return 3;
                }
            case choice_node:
                if (node_subtype(n) == discretionary_choice_subtype) {
                    nodelib_push_direct_or_nil(L, choice_pre_break(n));
                    nodelib_push_direct_or_nil(L, choice_post_break(n));
                    nodelib_push_direct_or_nil(L, choice_no_break(n));
                    if (lua_isboolean(L, 2) && lua_toboolean(L, 2)) {
                        nodelib_push_direct_or_nil(L, tex_tail_of_node_list(choice_pre_break(n)));
                        nodelib_push_direct_or_nil(L, tex_tail_of_node_list(choice_post_break(n)));
                        nodelib_push_direct_or_nil(L, tex_tail_of_node_list(choice_no_break(n)));
                        return 6;
                    } else {
                        return 3;
                    }
                } else { 
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_getdiscpart(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, get_glyph_discpart(n));
        return 1;
    } else {
        return 0;
    }
}

static int nodelib_direct_getpre(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case disc_node:
                nodelib_push_direct_or_nil(L, disc_pre_break_head(n));
                nodelib_push_direct_or_nil(L, disc_pre_break_tail(n));
                return 2;
            case hlist_node:
            case vlist_node:
                {
                    halfword h = box_pre_migrated(n);
                    halfword t = tex_tail_of_node_list(h);
                    nodelib_push_direct_or_nil(L, h);
                    nodelib_push_direct_or_nil(L, t);
                    return 2;
                }
            case choice_node:
                if (node_subtype(n) == discretionary_choice_subtype) {
                    nodelib_push_direct_or_nil(L, choice_pre_break(n));
                    return 1;
                } else { 
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_getpost(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case disc_node:
                nodelib_push_direct_or_nil(L, disc_post_break_head(n));
                nodelib_push_direct_or_nil(L, disc_post_break_tail(n));
                return 2;
            case hlist_node:
            case vlist_node:
                {
                    halfword h = box_post_migrated(n);
                    halfword t = tex_tail_of_node_list(h);
                    nodelib_push_direct_or_nil(L, h);
                    nodelib_push_direct_or_nil(L, t);
                    return 2;
                }
            case choice_node:
                if (node_subtype(n) == discretionary_choice_subtype) {
                    nodelib_push_direct_or_nil(L, choice_post_break(n));
                    return 1;
                } else { 
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_getreplace(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) { 
        switch (node_type(n)) { 
            case disc_node:
                nodelib_push_direct_or_nil(L, disc_no_break_head(n));
                nodelib_push_direct_or_nil(L, disc_no_break_tail(n));
                return 2;
            case choice_node:
                if (node_subtype(n) == discretionary_choice_subtype) {
                    nodelib_push_direct_or_nil(L, choice_no_break(n));
                    return 1;
                } else { 
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_setdisc(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == disc_node) {
        int t = lua_gettop(L) ;
        if (t > 1) {
            tex_set_disc_field(n, pre_break_code, nodelib_valid_direct_from_index(L, 2));
            if (t > 2) {
                tex_set_disc_field(n, post_break_code, nodelib_valid_direct_from_index(L, 3));
                if (t > 3) {
                    tex_set_disc_field(n, no_break_code, nodelib_valid_direct_from_index(L, 4));
                    if (t > 4) {
                        node_subtype(n) = lmt_toquarterword(L, 5);
                        if (t > 5) {
                            disc_penalty(n) = lmt_tohalfword(L, 6);
                        }
                    }
                } else {
                    tex_set_disc_field(n, no_break_code, null);
                }
            } else {
                tex_set_disc_field(n, post_break_code, null);
                tex_set_disc_field(n, no_break_code, null);
            }
        } else {
            tex_set_disc_field(n, pre_break_code, null);
            tex_set_disc_field(n, post_break_code, null);
            tex_set_disc_field(n, no_break_code, null);
        }
    }
    return 0;
}

static int nodelib_direct_setdiscpart(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        set_glyph_discpart(n, luaL_optinteger(L, 2, glyph_discpart_unset));
        return 1;
    } else {
        return 0;
    }
}

static int nodelib_direct_setpre(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword m = (lua_gettop(L) > 1) ? nodelib_valid_direct_from_index(L, 2) : null;
        switch (node_type(n)) {
            case disc_node:
                tex_set_disc_field(n, pre_break_code, m);
                break;
            case hlist_node:
            case vlist_node:
                box_pre_migrated(n) = m;
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setpost(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword m = (lua_gettop(L) > 1) ? nodelib_valid_direct_from_index(L, 2) : null;
        switch (node_type(n)) {
            case disc_node:
                tex_set_disc_field(n, post_break_code, m);
                break;
            case hlist_node:
            case vlist_node:
                box_post_migrated(n) = m;
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setreplace(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == disc_node) {
        halfword m = (lua_gettop(L) > 1) ? nodelib_valid_direct_from_index(L, 2) : null;
        tex_set_disc_field(n, no_break_code, m);
    }
    return 0;
}

/* node.direct.getwidth  */
/* node.direct.setwidth  */
/* node.direct.getheight (for consistency) */
/* node.direct.setheight (for consistency) */
/* node.direct.getdepth  (for consistency) */
/* node.direct.setdepth  (for consistency) */

/* split ifs for clearity .. compiler will optimize */

static int nodelib_direct_getwidth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushinteger(L, box_width(n));
                break;
            case align_record_node:
                lua_pushinteger(L, box_width(n));
                if (lua_toboolean(L, 2)) {
                    lua_pushinteger(L, box_size(n));
                    return 2;
                }
                break;
            case rule_node:
                lua_pushinteger(L, rule_width(n));
                break;
            case glue_node:
            case glue_spec_node:
                lua_pushinteger(L, glue_amount(n));
                break;
            case glyph_node:
                lua_pushnumber(L, tex_glyph_width(n));
                if (lua_toboolean(L, 2)) {
                    lua_pushinteger(L, glyph_expansion(n));
                    return 2;
                }
                break;
            case kern_node:
                lua_pushinteger(L, kern_amount(n));
                if (lua_toboolean(L, 2)) {
                    lua_pushinteger(L, kern_expansion(n));
                    return 2;
                }
                break;
            case math_node:
                lua_pushinteger(L, math_amount(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setwidth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
            case align_record_node:
                box_width(n) = lua_type(L, 2) == LUA_TNUMBER ? lmt_roundnumber(L, 2) : 0;
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    box_size(n) = lmt_roundnumber(L, 3);
                    box_package_state(n) = package_dimension_size_set;
                }
                break;
            case rule_node:
                rule_width(n) = lua_type(L, 2) == LUA_TNUMBER ? lmt_roundnumber(L, 2) : 0;
                break;
            case glue_node:
            case glue_spec_node:
                glue_amount(n) = lua_type(L, 2) == LUA_TNUMBER ? lmt_roundnumber(L, 2) : 0;
                break;
            case kern_node:
                kern_amount(n) = lua_type(L, 2) == LUA_TNUMBER ? lmt_roundnumber(L, 2) : 0;
                break;
            case math_node:
                math_amount(n) = lua_type(L, 2) == LUA_TNUMBER ? lmt_roundnumber(L, 2) : 0;
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getindex(lua_State* L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                lua_pushinteger(L, box_index(n));
                break;
            case insert_node:
                lua_pushinteger(L, insert_index(n));
                break;
            case mark_node:
                lua_pushinteger(L, mark_index(n));
                break;
            case adjust_node:
                lua_pushinteger(L, adjust_index(n));
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setindex(lua_State* L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                {
                    halfword index = lmt_tohalfword(L, 2);
                    if (tex_valid_box_index(index)) {
                        box_index(n) = index;
                    } else {
                        /* error or just ignore */
                    }
                    break;
                }
            case insert_node:
                {
                    halfword index = lmt_tohalfword(L, 2);
                    if (tex_valid_insert_id(index)) {
                        insert_index(n) = index;
                    } else {
                        /* error or just ignore */
                    }
                    break;
                }
            case mark_node:
                {
                    halfword index = lmt_tohalfword(L, 2);
                    if (tex_valid_mark(index)) {
                       mark_index(n) = index;
                    }
                }
                break;
            case adjust_node:
                {
                    halfword index = lmt_tohalfword(L, 2);
                    if (tex_valid_adjust_index(index)) {
                        adjust_index(n) = index;
                    }
                }
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_getheight(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushinteger(L, box_height(n));
                break;
            case rule_node:
                lua_pushinteger(L, rule_height(n));
                break;
            case insert_node:
                lua_pushinteger(L, insert_total_height(n));
                break;
            case glyph_node:
                lua_pushinteger(L, tex_glyph_height(n));
                break;
            case fence_noad:
                lua_pushinteger(L, noad_height(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setheight(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword h = 0;
        if (lua_type(L, 2) == LUA_TNUMBER) {
            h = lmt_roundnumber(L, 2);
        }
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                box_height(n) = h;
                break;
            case rule_node:
                rule_height(n) = h;
                break;
            case insert_node:
                insert_total_height(n) = h;
                break;
            case fence_noad:
                noad_height(n) = h;
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getdepth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushinteger(L, box_depth(n));
                break;
            case rule_node:
                lua_pushinteger(L, rule_depth(n));
                break;
            case insert_node:
                lua_pushinteger(L, insert_max_depth(n));
                break;
            case glyph_node:
                lua_pushinteger(L, tex_glyph_depth(n));
                break;
            case fence_noad:
                lua_pushinteger(L, noad_depth(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setdepth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword d = 0;
        if (lua_type(L, 2) == LUA_TNUMBER) {
            d = lmt_roundnumber(L, 2);
        }
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                box_depth(n) = d;
                break;
            case rule_node:
                rule_depth(n) = d;
                break;
            case insert_node:
                insert_max_depth(n) = d;
                break;
            case fence_noad:
                noad_depth(n) = d;
                break;
        }
    }
    return 0;
}

static int nodelib_direct_gettotal(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushinteger(L, (lua_Integer) box_total(n));
                break;
            case rule_node:
                lua_pushinteger(L, (lua_Integer) rule_total(n));
                break;
            case insert_node:
                lua_pushinteger(L, (lua_Integer) insert_total_height(n));
                break;
            case glyph_node:
                lua_pushinteger(L, (lua_Integer) tex_glyph_total(n));
                break;
            case fence_noad:
                lua_pushinteger(L, (lua_Integer) noad_total(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_settotal(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case insert_node:
                insert_total_height(n) = lua_type(L, 2) == LUA_TNUMBER ? (halfword) lmt_roundnumber(L,2) : 0;
                break;
        }
    }
    return 0;
}

/* node.direct.getshift */
/* node.direct.setshift */

static int nodelib_direct_getshift(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                lua_pushinteger(L, box_shift_amount(n));
                return 1;
        }
    }
    return 0;
}

static int nodelib_direct_setshift(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    box_shift_amount(n) = (halfword) lmt_roundnumber(L,2);
                } else {
                    box_shift_amount(n) = 0;
                }
                break;
        }
    }
    return 0;
}

/* node.direct.hasgeometry */
/* node.direct.getgeometry */
/* node.direct.setgeometry */
/* node.direct.getorientation */
/* node.direct.setorientation */

static int nodelib_direct_hasgeometry(lua_State* L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                if (box_geometry(n)) {
                    lua_pushinteger(L, box_geometry(n));
                    return 1;
                }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int nodelib_direct_getgeometry(lua_State* L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                if (box_geometry(n)) {
                    lua_pushinteger(L, box_geometry(n));
                    if (lua_toboolean(L, 2)) {
                        lua_pushboolean(L, tex_has_box_geometry(n, offset_geometry));
                        lua_pushboolean(L, tex_has_box_geometry(n, orientation_geometry));
                        lua_pushboolean(L, tex_has_box_geometry(n, anchor_geometry));
                        return 4;
                    } else {
                        return 1;
                    }
                }
                break;
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int nodelib_direct_setgeometry(lua_State* L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                box_geometry(n) = (singleword) lmt_tohalfword(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getorientation(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                lua_pushinteger(L, box_orientation(n));
                lua_pushinteger(L, box_x_offset(n));
                lua_pushinteger(L, box_y_offset(n));
                lua_pushinteger(L, box_w_offset(n));
                lua_pushinteger(L, box_h_offset(n));
                lua_pushinteger(L, box_d_offset(n));
                return 6;
        }
    }
    return 0;
}

static int nodelib_direct_setorientation(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                switch (lua_type(L, 2)) {
                    case LUA_TNUMBER:
                        box_orientation(n) = lmt_tohalfword(L, 2);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 2)) {
                            break;
                       }
                    default:
                        box_orientation(n) = 0;
                        break;
                }
                switch (lua_type(L, 3)) {
                    case LUA_TNUMBER:
                        box_x_offset(n) = lmt_tohalfword(L, 3);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 3)) {
                            break;
                        }
                    default:
                        box_x_offset(n) = 0;
                        break;
                }
                switch (lua_type(L, 4)) {
                    case LUA_TNUMBER:
                        box_y_offset(n) = lmt_tohalfword(L, 4);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 4)) {
                            break;
                        }
                    default:
                        box_y_offset(n) = 0;
                        break;
                }
                switch (lua_type(L, 5)) {
                    case LUA_TNUMBER:
                        box_w_offset(n) = lmt_tohalfword(L, 5);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 5)) {
                            break;
                        }
                    default:
                        box_w_offset(n) = 0;
                        break;
                }
                switch (lua_type(L, 6)) {
                    case LUA_TNUMBER:
                        box_h_offset(n) = lmt_tohalfword(L, 6);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 6)) {
                            break;
                        }
                    default:
                        box_h_offset(n) = 0;
                        break;
                }
                switch (lua_type(L, 7)) {
                    case LUA_TNUMBER:
                        box_d_offset(n) = lmt_tohalfword(L, 7);
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, 7)) {
                            break;
                        }
                    default:
                        box_d_offset(n) = 0;
                        break;
                }
                tex_check_box_geometry(n);
                break;
        }
    }
    return 0;
}

/* node.direct.setoptions */
/* node.direct.getoptions */

static int nodelib_direct_getoptions(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_options(n));
                return 1;
            case disc_node:
                lua_pushinteger(L, disc_options(n));
                return 1;
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                lua_pushinteger(L, noad_options(n));
                return 1;
            case math_char_node:
            case math_text_char_node:
                lua_pushinteger(L, kernel_math_options(n));
                return 1;
          }
    }
    return 0;
}

static int nodelib_direct_setoptions(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                set_glyph_options(n, lmt_tohalfword(L, 2));
                break;
            case disc_node:
                set_disc_options(n, lmt_tohalfword(L, 2));
                break;
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                noad_options(n) = lmt_tohalfword(L, 2);
                break;
            case math_char_node:
            case math_text_char_node:
                kernel_math_options(n) = lmt_tohalfword(L, 2);
                break;
        }
    }
    return 0;
}

/* node.direct.getwhd */
/* node.direct.setwhd */

static int nodelib_direct_getwhd(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
      AGAIN:
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushinteger(L, box_width(n));
                lua_pushinteger(L, box_height(n));
                lua_pushinteger(L, box_depth(n));
                return 3;
            case rule_node:
                lua_pushinteger(L, rule_width(n));
                lua_pushinteger(L, rule_height(n));
                lua_pushinteger(L, rule_depth(n));
                return 3;
            case glyph_node:
                /* or glyph_dimensions: */
                lua_pushinteger(L, tex_glyph_width(n));
                lua_pushinteger(L, tex_glyph_height(n));
                lua_pushinteger(L, tex_glyph_depth(n));
                if (lua_toboolean(L,2)) {
                    lua_pushinteger(L, glyph_expansion(n));
                    return 4;
                } else {
                    return 3;
                }
            case glue_node:
                n = glue_leader_ptr(n);
                if (n) {
                    goto AGAIN;
                } else {
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_setwhd(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
      AGAIN:
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                {
                    int top = lua_gettop(L) ;
                    if (top > 1) {
                        if ((lua_type(L, 2) == LUA_TNUMBER)) {
                            box_width(n) = (halfword) lmt_roundnumber(L, 2);
                        } else {
                            /*Leave as is */
                        }
                        if (top > 2) {
                            if ((lua_type(L, 3) == LUA_TNUMBER)) {
                                box_height(n) = (halfword) lmt_roundnumber(L, 3);
                            } else {
                                /*Leave as is */
                            }
                            if (top > 3) {
                                if ((lua_type(L, 4) == LUA_TNUMBER)) {
                                    box_depth(n) = (halfword) lmt_roundnumber(L, 4);
                                } else {
                                    /*Leave as is */
                                }
                            }
                        }
                    }
                }
                break;
            case rule_node:
                {
                    int top = lua_gettop(L) ;
                    if (top > 1) {
                        if ((lua_type(L, 2) == LUA_TNUMBER)) {
                            rule_width(n) = (halfword) lmt_roundnumber(L, 2);
                        } else {
                            /*Leave as is */
                        }
                        if (top > 2) {
                            if ((lua_type(L, 3) == LUA_TNUMBER)) {
                                rule_height(n) = (halfword) lmt_roundnumber(L, 3);
                            } else {
                                /*Leave as is */
                            }
                            if (top > 3) {
                                if ((lua_type(L, 4) == LUA_TNUMBER)) {
                                    rule_depth(n) = (halfword) lmt_roundnumber(L, 4);
                                } else {
                                    /*Leave as is */
                                }
                            }
                        }
                    }
                }
                break;
            case glue_node:
                n = glue_leader_ptr(n);
                if (n) {
                    goto AGAIN;
                } else {
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_hasdimensions(lua_State *L)
{
    int b = 0;
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                b = (box_width(n) > 0) || (box_total(n) > 0);
                break;
            case rule_node:
                b = (rule_width(n) > 0) || (rule_total(n) > 0);
                break;
            case glyph_node:
                b = tex_glyph_has_dimensions(n);
                break;
            case glue_node:
                {
                    halfword l = glue_leader_ptr(n);
                    if (l) {
                        switch (node_type(l)) {
                            case hlist_node:
                            case vlist_node:
                                b = (box_width(l) > 0) || (box_total(l) > 0);
                                break;
                            case rule_node:
                                b = (rule_width(l) > 0) || (rule_total(l) > 0);
                                break;
                        }
                    }
                }
                break;
        }
    }
    lua_pushboolean(L, b);
    return 1;
}

/* node.direct.getglyphwhd */

/*tex

    When the height and depth of a box is calculated the |y-offset| is taken into account. In \LUATEX\
    this is different for the height and depth, an historic artifact. However, because that can be
    controlled we now have this helper, mostly for tracing purposes because it listens to the mode
    parameter (and one can emulate other scenarios already).

*/

static int nodelib_direct_getglyphdimensions(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        scaledwhd whd = tex_glyph_dimensions_ex(n);
        lua_pushinteger(L, whd.wd);
        lua_pushinteger(L, whd.ht);
        lua_pushinteger(L, whd.dp);
        lua_pushinteger(L, glyph_expansion(n)); /* in case we need it later on */
        nodelib_aux_pushxyscales(L, n);
        return 6;
    } else {
        return 0;
    }
}

static int nodelib_direct_getkerndimension(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == kern_node) {
        lua_pushinteger(L, tex_kern_dimension_ex(n));
        return 1;
    } else {
        return 0;
    }
}

/* node.direct.getlist */

static int nodelib_direct_getlist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
            case align_record_node:
                nodelib_push_direct_or_nil_node_prev(L, box_list(n));
                break;
            case sub_box_node:
            case sub_mlist_node:
                nodelib_push_direct_or_nil_node_prev(L, kernel_math_list(n));
                break;
            case insert_node:
                /* kind of fuzzy */
                nodelib_push_direct_or_nil_node_prev(L, insert_list(n));
                break;
            case adjust_node:
                nodelib_push_direct_or_nil_node_prev(L, adjust_list(n));
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setlist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                box_list(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case sub_box_node:
            case sub_mlist_node:
                kernel_math_list(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case insert_node:
                /* kind of fuzzy */
                insert_list(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case adjust_node:
                adjust_list(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

/* node.direct.getleader */
/* node.direct.setleader */

static int nodelib_direct_getleader(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glue_node) {
        nodelib_push_direct_or_nil(L, glue_leader_ptr(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setleader(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glue_node) {
        glue_leader_ptr(n) = nodelib_valid_direct_from_index(L, 2);
    }
    return 0;
}

/* node.direct.getdata */
/* node.direct.setdata */

/*tex

    These getter and setter get |data| as well as |value| fields. One can make them equivalent to
    |getvalue| and |setvalue| if needed.

*/

static int nodelib_direct_getdata(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_data(n));
                return 1;
            case rule_node:
                lua_pushinteger(L, rule_data(n));
                return 1;
            case glue_node:
                lua_pushinteger(L, glue_data(n));
                return 1;
            case boundary_node:
                lua_pushinteger(L, boundary_data(n));
                return 1;
            case attribute_node:
                switch (node_subtype(n)) {
                    case attribute_list_subtype:
                        nodelib_push_attribute_data(L, n);
                        break;
                    case attribute_value_subtype:
                        /*tex Only used for introspection so it's okay to return 2 values. */
                        lua_pushinteger(L, attribute_index(n));
                        lua_pushinteger(L, attribute_value(n));
                        return 2;
                    default:
                        /*tex We just ignore. */
                        break;
                }
            case mark_node:
                if (lua_toboolean(L, 2)) {
                    lmt_token_list_to_luastring(L, mark_ptr(n), 0, 0, 0);
                } else {
                    lmt_token_list_to_lua(L, mark_ptr(n));
                }
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setdata(lua_State *L) /* data and value */
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                glyph_data(n) = lmt_tohalfword(L, 2);
                break;
            case rule_node:
                rule_data(n) = lmt_tohalfword(L, 2);
                break;
            case glue_node:
                glue_data(n) = lmt_tohalfword(L, 2);
                break;
            case boundary_node:
                boundary_data(n) = lmt_tohalfword(L, 2);
                break;
            case attribute_node:
                /*tex Not supported for now! */
                break;
            case mark_node:
                tex_delete_token_reference(mark_ptr(n));
                mark_ptr(n) = lmt_token_list_from_lua(L, 2); /* check ref */
                break;
        }
    }
    return 0;
}

/* node.direct.get[left|right|]delimiter */
/* node.direct.set[left|right|]delimiter */

static int nodelib_direct_getleftdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:
                nodelib_push_direct_or_nil(L, fraction_left_delimiter(n));
                return 1;
            case radical_noad:
                nodelib_push_direct_or_nil(L, radical_left_delimiter(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getrightdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:
                nodelib_push_direct_or_nil(L, fraction_right_delimiter(n));
                return 1;
            case radical_noad:
                nodelib_push_direct_or_nil(L, radical_right_delimiter(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:
                nodelib_push_direct_or_nil(L, fraction_middle_delimiter(n));
                return 1;
            case fence_noad:
                nodelib_push_direct_or_node(L, n, fence_delimiter_list(n));
                return 1;
            case radical_noad:
                nodelib_push_direct_or_node(L, n, radical_left_delimiter(n));
                return 1;
            case accent_noad:
                nodelib_push_direct_or_node(L, n, accent_middle_character(n)); /* not really a delimiter */
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setleftdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                fraction_left_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case radical_noad:                  
                radical_left_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setrightdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                fraction_right_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case radical_noad:                  
                radical_right_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                fraction_middle_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case fence_noad:
                fence_delimiter_list(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case radical_noad:
                radical_left_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                break;
            case accent_noad:
                accent_middle_character(n) = nodelib_valid_direct_from_index(L, 2); /* not really a delimiter */
                break;
        }
    }
    return 0;
}

/* node.direct.get[top|bottom] */
/* node.direct.set[top|bottom] */

static int nodelib_direct_gettop(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case accent_noad:
                nodelib_push_direct_or_nil(L, accent_top_character(n));
                return 1;
            case fence_noad:
                nodelib_push_direct_or_nil(L, fence_delimiter_top(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getbottom(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case accent_noad:
                nodelib_push_direct_or_nil(L, accent_bottom_character(n));
                return 1;
            case fence_noad:
                nodelib_push_direct_or_nil(L, fence_delimiter_bottom(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_settop(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case accent_noad:
                accent_top_character(n) = nodelib_valid_direct_from_index(L, 2);
                return 0;
            case fence_noad:
                fence_delimiter_top(n) = nodelib_valid_direct_from_index(L, 2);
                return 0;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setbottom(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case accent_noad:
                accent_bottom_character(n) = nodelib_valid_direct_from_index(L, 2);
                return 0;
            case fence_noad:
                fence_delimiter_bottom(n) = nodelib_valid_direct_from_index(L, 2);
                return 0;
        }
    }
    lua_pushnil(L);
    return 1;
}

/* node.direct.get[numerator|denominator] */
/* node.direct.set[numerator|denominator] */

static int nodelib_direct_getnumerator(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                nodelib_push_direct_or_nil(L, fraction_numerator(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getdenominator(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                nodelib_push_direct_or_nil(L, fraction_denominator(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setnumerator(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                fraction_numerator(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_setdenominator(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case fraction_noad:                  
                fraction_denominator(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

/* node.direct.getdegree */
/* node.direct.setdegree */

static int nodelib_direct_getdegree(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case radical_noad:                  
                nodelib_push_direct_or_nil(L, radical_degree(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setdegree(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case radical_noad:                  
                radical_degree(n) = nodelib_valid_direct_from_index(L, 2);
                break;
        }
    }
    return 0;
}

/* node.direct.getchoice */
/* node.direct.setchoice */

static int nodelib_direct_getchoice(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    halfword c = null;
    if (n && node_type(n) == choice_node) {
        switch (lmt_tointeger(L, 2)) {
            case 1: c = 
                choice_display_mlist(n); 
                break;
            case 2: c = 
                choice_text_mlist(n); 
                break;
            case 3: 
                c = choice_script_mlist(n); 
                break;
            case 4: 
                c = choice_script_script_mlist(n); 
                break;
        }
    }
    nodelib_push_direct_or_nil(L, c);
    return 1;
}

static int nodelib_direct_setchoice(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == choice_node) {
        halfword c = nodelib_valid_direct_from_index(L, 2);
        switch (lmt_tointeger(L, 2)) {
            case 1: 
                choice_display_mlist(n) = c; 
                break;
            case 2: 
                choice_text_mlist(n) = c; 
                break;
            case 3: 
                choice_script_mlist(n) = c; 
                break;
            case 4: 
                choice_script_script_mlist(n) = c; 
                break;
        }
    }
    return 0;
}

/* This is an experiment, we have a field left that we can use as attribute. */

static int nodelib_direct_getglyphdata(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && (node_type(n) == glyph_node) && (glyph_data(n) != unused_attribute_value)) {
        lua_pushinteger(L, glyph_data(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setglyphdata(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        glyph_data(n) = (halfword) luaL_optinteger(L, 2, unused_attribute_value);
    }
    return 0;
}

/* node.direct.getnext */
/* node.direct.setnext */

static int nodelib_direct_getnext(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_push_direct_or_nil(L, node_next(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setnext(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
       node_next(n) = nodelib_valid_direct_from_index(L, 2);
    }
    return 0;
}

static int nodelib_direct_isnext(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == lmt_tohalfword(L, 2)) {
        nodelib_push_direct_or_nil(L, node_next(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.getprev */
/* node.direct.setprev */

static int nodelib_direct_getprev(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_push_direct_or_nil(L, node_prev(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setprev(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        node_prev(n) = nodelib_valid_direct_from_index(L, 2);
    }
    return 0;
}

static int nodelib_direct_isprev(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == lmt_tohalfword(L, 2)) {
        nodelib_push_direct_or_nil(L, node_prev(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.getboth */
/* node.direct.setboth */

static int nodelib_direct_getboth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_push_direct_or_nil(L, node_prev(n));
        nodelib_push_direct_or_nil(L, node_next(n));
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

static int nodelib_direct_setboth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        node_prev(n) = nodelib_valid_direct_from_index(L, 2);
        node_next(n) = nodelib_valid_direct_from_index(L, 3);
    }
    return 0;
}

static int nodelib_direct_isboth(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword typ = lmt_tohalfword(L, 2);
        halfword prv = node_prev(n);
        halfword nxt = node_next(n);
        nodelib_push_direct_or_nil(L, prv && node_type(prv) == typ ? prv : null);
        nodelib_push_direct_or_nil(L, nxt && node_type(nxt) == typ ? nxt : null);
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

/* node.direct.setlink */
/* node.direct.setsplit  */

/*
    a b b nil c d         : prev-a-b-c-d-next
    nil a b b nil c d nil : nil-a-b-c-d-nil
*/

static int nodelib_direct_setlink(lua_State *L)
{
    int n = lua_gettop(L);
    halfword h = null; /* head node */
    halfword t = null; /* tail node */
    for (int i = 1; i <= n; i++) {
        /*
            We don't go for the tail of the current node because we can inject between existing nodes
            and the nodes themselves can have old values for prev and next, so ... only single nodes
            are looked at!
        */
        if (lua_type(L, i) == LUA_TNUMBER) {
            halfword c = nodelib_valid_direct_from_index(L, i); /* current node */
            if (c) {
                if (c != t) {
                    if (t) {
                        node_next(t) = c;
                        node_prev(c) = t;
                    } else if (i > 1) {
                        /* we assume that the first node is a kind of head */
                        node_prev(c) = null;
                    }
                    t = c;
                    if (! h) {
                        h = t;
                    }
                } else {
                    /* we ignore duplicate nodes which can be tails or the previous */
                }
            } else {
                /* we ignore bad nodes, but we could issue a message */
            }
        } else if (t) {
            /* safeguard: a nil in the list can be meant as end so we nil the next of tail */
            node_next(t) = null;
        } else {
            /* we just ignore nil nodes and have no tail yet */
        }
    }
    nodelib_push_direct_or_nil(L, h);
    return 1;
}

static int nodelib_direct_setsplit(lua_State *L)
{
    halfword l = nodelib_valid_direct_from_index(L, 1);
    halfword r = nodelib_valid_direct_from_index(L, 2); /* maybe default to next */
    if (l && r) {
        if (l != r) {
            node_prev(node_next(l)) = null;
            node_next(node_prev(r)) = null;
        }
        node_next(l) = null;
        node_prev(r) = null;
    }
    return 0;
}

/*tex Local_par nodes can have frozen properties. */

static int nodelib_direct_getparstate(lua_State *L)
{
    halfword p = nodelib_valid_direct_from_index(L, 1);
    if (! p) {
        p = tex_find_par_par(cur_list.head);
    } else if (node_type(p) != par_node) {
        while (node_prev(p)) {
            p = node_prev(p);
        }
    }
    if (p && node_type(p) == par_node) {
        int limited = lua_toboolean(L, 2);
        lua_createtable(L, 0, 24);
        if (p && node_type(p) == par_node) {
            /* todo: optional: all skip components */
            lua_push_integer_at_key(L, hsize,                            tex_get_par_par(p, par_hsize_code));
            lua_push_integer_at_key(L, leftskip,             glue_amount(tex_get_par_par(p, par_left_skip_code)));
            lua_push_integer_at_key(L, rightskip,            glue_amount(tex_get_par_par(p, par_right_skip_code)));
            lua_push_integer_at_key(L, hangindent,                       tex_get_par_par(p, par_hang_indent_code));
            lua_push_integer_at_key(L, hangafter,                        tex_get_par_par(p, par_hang_after_code));
            lua_push_integer_at_key(L, parindent,                        tex_get_par_par(p, par_par_indent_code));
            if (! limited) {
                lua_push_integer_at_key(L, parfillleftskip,  glue_amount(tex_get_par_par(p, par_par_fill_left_skip_code)));
                lua_push_integer_at_key(L, parfillskip,      glue_amount(tex_get_par_par(p, par_par_fill_right_skip_code)));
                lua_push_integer_at_key(L, parinitleftskip,  glue_amount(tex_get_par_par(p, par_par_init_left_skip_code)));
                lua_push_integer_at_key(L, parinitrightskip, glue_amount(tex_get_par_par(p, par_par_init_right_skip_code)));
                lua_push_integer_at_key(L, adjustspacing,                tex_get_par_par(p, par_adjust_spacing_code));
                lua_push_integer_at_key(L, protrudechars,                tex_get_par_par(p, par_protrude_chars_code));
                lua_push_integer_at_key(L, pretolerance,                 tex_get_par_par(p, par_pre_tolerance_code));
                lua_push_integer_at_key(L, tolerance,                    tex_get_par_par(p, par_tolerance_code));
                lua_push_integer_at_key(L, emergencystretch,             tex_get_par_par(p, par_emergency_stretch_code));
                lua_push_integer_at_key(L, looseness,                    tex_get_par_par(p, par_looseness_code));
                lua_push_integer_at_key(L, lastlinefit,                  tex_get_par_par(p, par_last_line_fit_code));
                lua_push_integer_at_key(L, linepenalty,                  tex_get_par_par(p, par_line_penalty_code));
                lua_push_integer_at_key(L, interlinepenalty,             tex_get_par_par(p, par_inter_line_penalty_code));
                lua_push_integer_at_key(L, clubpenalty,                  tex_get_par_par(p, par_club_penalty_code));
                lua_push_integer_at_key(L, widowpenalty,                 tex_get_par_par(p, par_widow_penalty_code));
                lua_push_integer_at_key(L, displaywidowpenalty,          tex_get_par_par(p, par_display_widow_penalty_code));
                lua_push_integer_at_key(L, orphanpenalty,                tex_get_par_par(p, par_orphan_penalty_code));
                lua_push_integer_at_key(L, brokenpenalty,                tex_get_par_par(p, par_broken_penalty_code));
                lua_push_integer_at_key(L, adjdemerits,                  tex_get_par_par(p, par_adj_demerits_code));
                lua_push_integer_at_key(L, doublehyphendemerits,         tex_get_par_par(p, par_double_hyphen_demerits_code));
                lua_push_integer_at_key(L, finalhyphendemerits,          tex_get_par_par(p, par_final_hyphen_demerits_code));
                lua_push_integer_at_key(L, baselineskip,     glue_amount(tex_get_par_par(p, par_baseline_skip_code)));
                lua_push_integer_at_key(L, lineskip,         glue_amount(tex_get_par_par(p, par_line_skip_code)));
                lua_push_integer_at_key(L, lineskiplimit,                tex_get_par_par(p, par_line_skip_limit_code));
                lua_push_integer_at_key(L, shapingpenaltiesmode,         tex_get_par_par(p, par_shaping_penalties_mode_code));
                lua_push_integer_at_key(L, shapingpenalty,               tex_get_par_par(p, par_shaping_penalty_code));
            }
            lua_push_specification_at_key(L, parshape,                   tex_get_par_par(p, par_par_shape_code));
            if (! limited) {
                lua_push_specification_at_key(L, interlinepenalties,     tex_get_par_par(p, par_inter_line_penalties_code));
                lua_push_specification_at_key(L, clubpenalties,          tex_get_par_par(p, par_club_penalties_code));
                lua_push_specification_at_key(L, widowpenalties,         tex_get_par_par(p, par_widow_penalties_code));
                lua_push_specification_at_key(L, displaywidowpenalties,  tex_get_par_par(p, par_display_widow_penalties_code));
                lua_push_specification_at_key(L, orphanpenalties,        tex_get_par_par(p, par_orphan_penalties_code));
            }
        }
        return 1;
    } else {
        return 0;
    }
}

/* node.type (converts id numbers to type names) */

static int nodelib_hybrid_type(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TNUMBER) {
        halfword i = lmt_tohalfword(L, 1);
        if (tex_nodetype_is_visible(i)) {
            lua_push_key_by_index(lmt_interface.node_data[i].lua);
            return 1;
        }
    } else if (lmt_maybe_isnode(L, 1)) {
        lua_push_key(node);
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

/* node.new (allocate a new node) */

static halfword nodelib_new_node(lua_State *L)
{
    quarterword i = unknown_node;
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            i = lmt_toquarterword(L, 1);
            if (! tex_nodetype_is_visible(i)) {
                i = unknown_node;
            }
            break;
        case LUA_TSTRING:
            i = nodelib_aux_get_node_type_id_from_name(L, 1, lmt_interface.node_data);
            break;
    }
    if (tex_nodetype_is_visible(i)) {
        quarterword j = unknown_subtype;
        switch (lua_type(L, 2)) {
            case LUA_TNUMBER:
                j = lmt_toquarterword(L, 2);
                break;
            case LUA_TSTRING:
                j = nodelib_aux_get_node_subtype_id_from_name(L, 2, lmt_interface.node_data[i].subtypes);
                break;
        }
        return tex_new_node(i, (j == unknown_subtype) ? 0 : j);
    } else {
        return luaL_error(L, "invalid node id for creating new node");
    }
}

static int nodelib_userdata_new(lua_State *L)
{
    lmt_push_node_fast(L, nodelib_new_node(L));
    return 1;
}

/* node.direct.new */

static int nodelib_direct_new(lua_State *L)
{
    lua_pushinteger(L, nodelib_new_node(L));
    return 1;
}

static int nodelib_direct_newtextglyph(lua_State* L)
{
    halfword glyph = tex_new_text_glyph(lmt_tohalfword(L, 1), lmt_tohalfword(L, 2));
    nodelib_aux_setattributelist(L, glyph, 3);
    lua_pushinteger(L, glyph);
    return 1;
}

static int nodelib_direct_newmathglyph(lua_State* L)
{
    /*tex For now we don't set a properties, group and/or index here. */
    halfword glyph = tex_new_math_glyph(lmt_tohalfword(L, 1), lmt_tohalfword(L, 2));
    nodelib_aux_setattributelist(L, glyph, 3);
    lua_pushinteger(L, glyph);
    return 1;
}

/* node.free (this function returns the 'next' node, because that may be helpful) */

static int nodelib_userdata_free(lua_State *L)
{
    if (lua_gettop(L) < 1) {
        lua_pushnil(L);
    } else if (! lua_isnil(L, 1)) {
        halfword n = lmt_check_isnode(L, 1);
        halfword p = node_next(n);
        tex_flush_node(n);
        lmt_push_node_fast(L, p);
    }
    return 1;
}

/* node.direct.free */

static int nodelib_direct_free(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword p = node_next(n);
        tex_flush_node(n);
        n = p;
    } else {
        n = null;
    }
    nodelib_push_direct_or_nil(L, n);
    return 1;
}

/* node.flushnode (no next returned) */

static int nodelib_userdata_flushnode(lua_State *L)
{
    if (! lua_isnil(L, 1)) {
        halfword n = lmt_check_isnode(L, 1);
        tex_flush_node(n);
    }
    return 0;
}

/* node.direct.flush_node */

static int nodelib_direct_flushnode(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        tex_flush_node(n);
    }
    return 0;
}

/* node.flushlist */

static int nodelib_userdata_flushlist(lua_State *L)
{
    if (! lua_isnil(L, 1)) {
        halfword n_ptr = lmt_check_isnode(L, 1);
        tex_flush_node_list(n_ptr);
    }
    return 0;
}

/* node.direct.flush_list */

static int nodelib_direct_flushlist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        tex_flush_node_list(n);
    }
    return 0;
}

/* node.remove */

static int nodelib_userdata_remove(lua_State *L)
{
    if (lua_gettop(L) < 2) {
        return luaL_error(L, "Not enough arguments for node.remove()");
    } else {
        halfword head = lmt_check_isnode(L, 1);
        if (lua_isnil(L, 2)) {
            return 2;
        } else {
            halfword current = lmt_check_isnode(L, 2);
            halfword removed = current;
            int remove = lua_toboolean(L, 3);
            if (head == current) {
                if (node_prev(current)){
                    node_next(node_prev(current)) = node_next(current);
                }
                if (node_next(current)){
                    node_prev(node_next(current)) = node_prev(current);
                }
                head = node_next(current);
                current = node_next(current);
            } else {
                halfword t = node_prev(current);
                if (t) {
                    node_next(t) = node_next(current);
                    if (node_next(current)) {
                        node_prev(node_next(current)) = t;
                    }
                    current = node_next(current);
                } else {
                    return luaL_error(L, "Bad arguments to node.remove()");
                }
            }
            lmt_push_node_fast(L, head);
            lmt_push_node_fast(L, current);
            if (remove) {
                tex_flush_node(removed);
                return 2;
            } else {
                lmt_push_node_fast(L, removed);
                node_next(removed) = null;
                node_prev(removed) = null;
                return 3;
            }
        }
    }
}

/* node.direct.remove */

static int nodelib_direct_remove(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    if (head) {
        halfword current = nodelib_valid_direct_from_index(L, 2);
        if (current) {
            halfword removed = current;
            int remove = lua_toboolean(L, 3);
            halfword prev = node_prev(current);
            if (head == current) {
                halfword next = node_next(current);
                if (prev){
                    node_next(prev) = next;
                }
                if (next){
                    node_prev(next) = prev;
                }
                head = node_next(current);
                current = head;
            } else {
                if (prev) {
                    halfword next = node_next(current);
                    node_next(prev) = next;
                    if (next) {
                        node_prev(next) = prev;
                    }
                    current = next;
                } else {
                 /* tex_formatted_warning("nodes","invalid arguments to node.remove"); */
                    return 2;
                }
            }
            nodelib_push_direct_or_nil(L, head);
            nodelib_push_direct_or_nil(L, current);
            if (remove) {
                tex_flush_node(removed);
                return 2;
            } else {
                nodelib_push_direct_or_nil(L, removed);
                node_next(removed) = null;
                node_prev(removed) = null;
                return 3;
            }
        } else {
            lua_pushinteger(L, head);
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

/* node.insertbefore (insert a node in a list) */

static int nodelib_userdata_insertbefore(lua_State *L)
{
    if (lua_gettop(L) < 3) {
        return luaL_error(L, "Not enough arguments for node.insertbefore()");
    } else if (lua_isnil(L, 3)) {
        lua_settop(L, 2);
    } else {
        halfword n = lmt_check_isnode(L, 3);
        if (lua_isnil(L, 1)) {
            node_next(n) = null;
            node_prev(n) = null;
            lmt_push_node_fast(L, n);
            lua_pushvalue(L, -1);
        } else {
            halfword current;
            halfword head = lmt_check_isnode(L, 1);
            if (lua_isnil(L, 2)) {
                current = tex_tail_of_node_list(head);
            } else {
                current = lmt_check_isnode(L, 2);
            }
            if (head != current) {
                halfword t = node_prev(current);
                if (t) {
                    tex_couple_nodes(t, n);
                } else {
                    return luaL_error(L, "Bad arguments to node.insertbefore()");
                }
            }
            tex_couple_nodes(n, current);
            lmt_push_node_fast(L, (head == current) ? n : head);
            lmt_push_node_fast(L, n);
        }
    }
    return 2;
}

/* node.direct.insertbefore */

static int nodelib_direct_insertbefore(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 3);
    if (n) {
        halfword head = nodelib_valid_direct_from_index(L, 1);
        halfword current = nodelib_valid_direct_from_index(L, 2);
        /* no head, ignore current */
        if (head) {
            if (! current) {
                current = tex_tail_of_node_list(head);
            }
            if (head != current) {
                halfword prev = node_prev(current);
                if (prev) {
                    tex_couple_nodes(prev, n);
                } else {
                    /* error so just quit and return originals */
                    return 2;
                }
            }
            tex_couple_nodes(n, current); /*  nice but incompatible: tex_couple_nodes(tail_of_list(n),current) */
            lua_pushinteger(L, (head == current) ? n : head);
            lua_pushinteger(L, n);
        } else {
            node_next(n) = null;
            node_prev(n) = null;
            lua_pushinteger(L, n);
            lua_pushinteger(L, n);
            /* n, n */
        }
    } else {
        lua_settop(L, 2);
    }
    return 2;
}

/* node.insertafter */

static int nodelib_userdata_insertafter(lua_State *L)
{
    if (lua_gettop(L) < 3) {
        return luaL_error(L, "Not enough arguments for node.insertafter()");
    } else if (lua_isnil(L, 3)) {
        lua_settop(L, 2);
    } else {
        halfword n = lmt_check_isnode(L, 3);
        if (lua_isnil(L, 1)) {
            node_next(n) = null;
            node_prev(n) = null;
            lmt_push_node_fast(L, n);
            lua_pushvalue(L, -1);
        } else {
            halfword current;
            halfword head = lmt_check_isnode(L, 1);
            if (lua_isnil(L, 2)) {
                current = head;
                while (node_next(current)) {
                    current = node_next(current);
                }
            } else {
                current = lmt_check_isnode(L, 2);
            }
            tex_try_couple_nodes(n, node_next(current));
            tex_couple_nodes(current, n);
            lua_pop(L, 2);
            lmt_push_node_fast(L, n);
        }
    }
    return 2;
}

/* node.direct.insertafter */

static int nodelib_direct_insertafter(lua_State *L)
{
    /*[head][current][new]*/
    halfword n = nodelib_valid_direct_from_index(L, 3);
    if (n) {
        halfword head = nodelib_valid_direct_from_index(L, 1);
        halfword current = nodelib_valid_direct_from_index(L, 2);
        if (head) {
            if (! current) {
                current = head;
                while (node_next(current)) {
                    current = node_next(current);
                }
            }
            tex_try_couple_nodes(n, node_next(current)); /* nice but incompatible: try_couple_nodes(tail_of_list(n), node_next(current)); */
            tex_couple_nodes(current, n);
            lua_pop(L, 2);
            lua_pushinteger(L, n);
        } else {
            /* no head, ignore current */
            node_next(n) = null;
            node_prev(n) = null;
            lua_pushinteger(L, n);
            lua_pushvalue(L, -1);
            /* n, n */
        }
    } else {
        lua_settop(L, 2);
    }
    return 2;
}

/* */

static int nodelib_direct_appendaftertail(lua_State *L)
{
    /*[head][current][new]*/
    halfword h = nodelib_valid_direct_from_index(L, 1);
    halfword n = nodelib_valid_direct_from_index(L, 2);
    if (h && n) {
        tex_couple_nodes(tex_tail_of_node_list(h), n);
    }
    return 0;
}

static int nodelib_direct_prependbeforehead(lua_State *L)
{
    /*[head][current][new]*/
    halfword h = nodelib_valid_direct_from_index(L, 1);
    halfword n = nodelib_valid_direct_from_index(L, 2);
    if (h && n) {
        tex_couple_nodes(n, tex_head_of_node_list(h));
    }
    return 0;
}

/* node.copylist */

/*tex

    We need to use an intermediate variable as otherwise target is used in the loop and subfields
    get overwritten (or something like that) which results in crashes and unexpected side effects.

*/

static int nodelib_userdata_copylist(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        return 1; /* the nil itself */
    } else {
        halfword m;
        halfword s = null;
        halfword n = lmt_check_isnode(L, 1);
        if ((lua_gettop(L) > 1) && (! lua_isnil(L, 2))) {
            s = lmt_check_isnode(L, 2);
        }
        m = tex_copy_node_list(n, s);
        lmt_push_node_fast(L, m);
        return 1;
    }
}

/* node.direct.copylist */

static int nodelib_direct_copylist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    halfword s = nodelib_valid_direct_from_index(L, 2);
    if (n) {
        halfword m = tex_copy_node_list(n, s);
        lua_pushinteger(L, m);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.show (node, threshold, max) */
/* node.direct.show */

static int nodelib_userdata_show(lua_State *L)
{
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        tex_show_node_list(n, lmt_optinteger(L, 2, show_box_depth_par), lmt_optinteger(L, 3, show_box_breadth_par));
    }
    return 0;
}

static int nodelib_direct_show(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        tex_show_node_list(n, lmt_optinteger(L, 2, show_box_depth_par), lmt_optinteger(L, 3, show_box_breadth_par));
    }
    return 0;
}

/* node.serialize(node, details, threshold, max) */
/* node.direct.serialize */

static int nodelib_aux_showlist(lua_State* L, halfword box)
{
    if (box) {
        luaL_Buffer buffer;
        int saved_selector = lmt_print_state.selector;
        halfword levels = tracing_levels_par;
        halfword online = tracing_online_par;
        halfword details = show_node_details_par;
        halfword depth = lmt_opthalfword(L, 3, show_box_depth_par);
        halfword breadth = lmt_opthalfword(L, 4, show_box_breadth_par);
        tracing_levels_par = 0;
        tracing_online_par = 0;
        show_node_details_par = lmt_opthalfword(L, 2, details);
        lmt_print_state.selector = luabuffer_selector_code;
        lmt_lua_state.used_buffer = &buffer;
        luaL_buffinit(L, &buffer);
        tex_show_node_list(box, depth, breadth);
        tex_print_ln();
        luaL_pushresult(&buffer);
        lmt_lua_state.used_buffer = NULL;
        lmt_print_state.selector = saved_selector;
        show_node_details_par = details;
        tracing_levels_par = levels;
        tracing_online_par = online;
    } else {
        lua_pushliteral(L, "");
    }
    return 1;
}

static int nodelib_common_serialized(lua_State *L, halfword n)
{
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                return nodelib_aux_showlist(L, n);
            default:
                {
                    halfword prv = null;
                    halfword nxt = null;
                    if (tex_nodetype_has_prev(n)) {
                        prv = node_prev(n);
                        node_prev(n) = null;
                    }
                    if (tex_nodetype_has_next(n)) {
                        nxt = node_next(n);
                        node_next(n) = null;
                    }
                    nodelib_aux_showlist(L, n);
                    if (prv) {
                        node_prev(n) = prv;
                    }
                    if (nxt) {
                        node_next(n) = nxt;
                    }
                    return 1;
                }
        }
    }
    lua_pushliteral(L, "");
    return 1;
}

static int nodelib_userdata_serialized(lua_State *L)
{
    return nodelib_common_serialized(L, lmt_check_isnode(L, 1));
}

/* node.direct.show */

static int nodelib_direct_serialized(lua_State *L)
{
    return nodelib_common_serialized(L, nodelib_valid_direct_from_index(L, 1));
}


/* node.copy (deep copy) */

static int nodelib_userdata_copy(lua_State *L)
{
    if (! lua_isnil(L, 1)) {
        halfword n = lmt_check_isnode(L, 1);
        n = tex_copy_node(n);
        lmt_push_node_fast(L, n);
    }
    return 1;
}

/* node.direct.copy (deep copy) */

static int nodelib_direct_copy(lua_State *L)
{
    if (! lua_isnil(L, 1)) {
        /* beware, a glue node can have number 0 (zeropt) so we cannot test for null) */
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            n = tex_copy_node(n);
            lua_pushinteger(L, n);
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

/* node.direct.copyonly (use with care) */

static int nodelib_direct_copyonly(lua_State *L)
{
    if (! lua_isnil(L, 1)) {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            n = tex_copy_node_only(n);
            lua_pushinteger(L, n);
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

/* node.write (output a node to tex's processor) */
/* node.append (idem but no attributes) */

static int nodelib_userdata_write(lua_State *L)
{
    int j = lua_gettop(L);
    for (int i = 1; i <= j; i++) {
        halfword n = lmt_check_isnode(L, i);
        if (n) {
            halfword m = node_next(n);
            tex_tail_append(n);
            if (tex_nodetype_has_attributes(node_type(n)) && ! node_attr(n)) {
                attach_current_attribute_list(n);
            }
            while (m) {
                tex_tail_append(m);
                if (tex_nodetype_has_attributes(node_type(m)) && ! node_attr(m)) {
                    attach_current_attribute_list(m);
                }
                m = node_next(m);
            }
        }
    }
    return 0;
}

/*
static int nodelib_userdata_append(lua_State *L)
{
    int j = lua_gettop(L);
    for (int i = 1; i <= j; i++) {
        halfword n = lmt_check_isnode(L, i);
        if (n) {
            halfword m = node_next(n);
            tail_append(n);
            while (m) {
                tex_tail_append(m);
                m = node_next(m);
            }
        }
    }
    return 0;
}
*/

/* node.direct.write (output a node to tex's processor) */
/* node.direct.append (idem no attributes) */

static int nodelib_direct_write(lua_State *L)
{
    int j = lua_gettop(L);
    for (int i = 1; i <= j; i++) {
        halfword n = nodelib_valid_direct_from_index(L, i);
        if (n) {
            halfword m = node_next(n);
            tex_tail_append(n);
            if (tex_nodetype_has_attributes(node_type(n)) && ! node_attr(n)) {
                attach_current_attribute_list(n);
            }
            while (m) {
                tex_tail_append(m);
                if (tex_nodetype_has_attributes(node_type(m)) && ! node_attr(m)) {
                    attach_current_attribute_list(m);
                }
                m = node_next(m);
            }
        }
    }
    return 0;
}

/*
static int nodelib_direct_appendtocurrentlist(lua_State *L)
{
    int j = lua_gettop(L);
    for (int i = 1; i <= j; i++) {
        halfword n = nodelib_valid_direct_from_index(L, i);
        if (n) {
            halfword m = node_next(n);
            tex_tail_append(n);
            while (m) {
                tex_tail_append(m);
                m = node_next(m);
            }
        }
    }
    return 0;
}
*/

/* node.direct.last */

static int nodelib_direct_lastnode(lua_State *L)
{
    halfword m = tex_pop_tail();
    lua_pushinteger(L, m);
    return 1;
}

/* node.direct.hpack */

static int nodelib_aux_packing(lua_State *L, int slot) 
{
    switch (lua_type(L, slot)) {
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L, slot);
                if (lua_key_eq(s, exactly)) {
                    return packing_exactly;
                } else if (lua_key_eq(s, additional)) {
                    return packing_additional;
                } else if (lua_key_eq(s, expanded)) {
                    return packing_expanded;
                } else if (lua_key_eq(s, substitute)) {
                    return packing_substitute;
                } else if (lua_key_eq(s, adapted)) {
                    return packing_adapted;
                }
                break;
            }
        case LUA_TNUMBER:
            {
                int m = (int) lua_tointeger(L, slot);
                if (m >= packing_exactly && m <= packing_adapted) {
                    return m;
                }
                break;
            }
    }
    return packing_additional;
}

static int nodelib_direct_hpack(lua_State *L)
{
    halfword p;
    int w = 0;
    int m = packing_additional;
    singleword d = direction_def_value;
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int top = lua_gettop(L);
        if (top > 1) {
            w = lmt_roundnumber(L, 2);
            if (top > 2) {
                m = nodelib_aux_packing(L, 3);
                if (top > 3) {
                    d = nodelib_getdirection(L, 4);
                }
            }
        }
    } else {
        n = null;
    }
    p = tex_hpack(n, w, m, d, holding_none_option);
    lua_pushinteger(L, p);
    lua_pushinteger(L, lmt_packaging_state.last_badness);
    lua_pushinteger(L, lmt_packaging_state.last_overshoot);
    return 3;
}

static int nodelib_direct_repack(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                {
                    int top = lua_gettop(L);
                    int w = top > 1 ? lmt_roundnumber(L, 2) : 0;
                    int m = top > 2 ? nodelib_aux_packing(L, 3) : packing_additional;
                    tex_repack(n, w, m);
                    break;
                }
        }
    }
    return 0;
}

static int nodelib_direct_freeze(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                 tex_freeze(n, lua_toboolean(L, 2));
                 break;
        }
    }
    return 0;
}


/* node.direct.vpack */

static int nodelib_direct_verticalbreak(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        scaled ht = lmt_roundnumber(L, 2);
        scaled dp = lmt_roundnumber(L, 3);
        n = tex_vert_break(n, ht, dp);
    }
    lua_pushinteger(L, n);
    return 1;
}

static int nodelib_direct_vpack(lua_State *L)
{
    halfword p;
    int w = 0;
    int m = packing_additional;
    singleword d = direction_def_value;
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int top = lua_gettop(L);
        if (top > 1) {
            w = lmt_roundnumber(L, 2);
            if (top > 2) {
                switch (lua_type(L, 3)) {
                    case LUA_TSTRING:
                        {
                            const char *s = lua_tostring(L, 3);
                            if (lua_key_eq(s, additional)) {
                                m = packing_additional;
                            } else if (lua_key_eq(s, exactly)) {
                                m = packing_exactly;
                            }
                            break;
                        }
                    case LUA_TNUMBER:
                        {
                            m = (int) lua_tointeger(L, 3);
                            if (m != packing_exactly && m != packing_additional) {
                                m = packing_additional;
                            }
                            break;
                        }
                }
                if (top > 3) {
                    d = nodelib_getdirection(L, 4);
                }
            }
        }
    } else {
        n = null;
    }
    p = tex_vpack(n, w, m, max_dimen, d, holding_none_option);
    lua_pushinteger(L, p);
    lua_pushinteger(L, lmt_packaging_state.last_badness);
    return 2;
}

/* node.direct.dimensions */
/* node.direct.rangedimensions */
/* node.direct.naturalwidth */

static int nodelib_direct_dimensions(lua_State *L)
{
    int top = lua_gettop(L);
    if (top > 0) {
        scaledwhd siz = { 0, 0, 0, 0 };
        glueratio g_mult = normal_glue_multiplier;
        int vertical = 0;
        int g_sign = normal_glue_sign;
        int g_order = normal_glue_order;
        int i = 1;
        halfword n = null;
        halfword p = null;
        if (top > 3) {
            i += 3;
            g_mult = (glueratio) lua_tonumber(L, 1); /* integer or float */
            g_sign = tex_checked_glue_sign(lmt_tohalfword(L, 2));
            g_order = tex_checked_glue_order(lmt_tohalfword(L, 3));
        }
        n = nodelib_valid_direct_from_index(L, i);
        if (lua_type(L, i + 1) == LUA_TBOOLEAN) {
            vertical = lua_toboolean(L, i + 1);
        } else {
            p = nodelib_valid_direct_from_index(L, i + 1);
            vertical = lua_toboolean(L, i + 2);
        }
        if (n) {
            if (vertical) {
                siz = tex_natural_vsizes(n, p, g_mult, g_sign, g_order);
            } else {
                siz = tex_natural_hsizes(n, p, g_mult, g_sign, g_order);
            }
        }
        lua_pushinteger(L, siz.wd);
        lua_pushinteger(L, siz.ht);
        lua_pushinteger(L, siz.dp);
        return 3;
    } else {
        return luaL_error(L, "missing argument to 'dimensions' (direct node expected)");
    }
}

static int nodelib_direct_rangedimensions(lua_State *L) /* parent, first, last */
{
    int top = lua_gettop(L);
    if (top > 1) {
        scaledwhd siz = { 0, 0, 0, 0 };
        int vertical = 0;
        halfword l = nodelib_valid_direct_from_index(L, 1); /* parent */
        halfword n = nodelib_valid_direct_from_index(L, 2); /* first  */
        halfword p = n;
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            vertical = lua_toboolean(L, 3);
        } else {
            p = nodelib_valid_direct_from_index(L, 3); /* last   */
            vertical = lua_toboolean(L, 4);
        }
        if (l && n) {
            if (vertical) {
                siz = tex_natural_vsizes(n, p, (glueratio) box_glue_set(l), box_glue_sign(l), box_glue_order(l));
            } else {
                siz = tex_natural_hsizes(n, p, (glueratio) box_glue_set(l), box_glue_sign(l), box_glue_order(l));
            }
        }
        lua_pushinteger(L, siz.wd);
        lua_pushinteger(L, siz.ht);
        lua_pushinteger(L, siz.dp);
        return 3;
    } else {
        return luaL_error(L, "missing argument to 'rangedimensions' (2 or more direct nodes expected)");
    }
}

static int nodelib_direct_naturalwidth(lua_State *L) /* parent, first, [last] */
{
    int top = lua_gettop(L);
    if (top > 1) {
        scaled wd = 0;
        halfword l = nodelib_valid_direct_from_index(L, 1); /* parent */
        halfword n = nodelib_valid_direct_from_index(L, 2); /* first  */
        halfword p = nodelib_valid_direct_from_index(L, 3); /* last   */
        if (l && n) {
            wd = tex_natural_width(n, p, (glueratio) box_glue_set(l), box_glue_sign(l), box_glue_order(l));
        }
        lua_pushinteger(L, wd);
        return 1;
    } else {
        return luaL_error(L, "missing argument to 'naturalwidth' (2 or more direct nodes expected)");
    }
}

static int nodelib_direct_naturalhsize(lua_State *L)
{
    scaled wd = 0;
    halfword c = null;
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        wd = tex_natural_hsize(n, &c);
    }
    lua_pushinteger(L, wd);
    lua_pushinteger(L, c ? glue_amount(c) : 0);
    nodelib_push_direct_or_nil(L, c);
    return 3;
}

static int nodelib_direct_mlisttohlist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int style = lmt_get_math_style(L, 2, text_style);
        int penalties = lua_toboolean(L, 3);
        int beginclass = lmt_optinteger(L, 4, unset_noad_class);
        int endclass = lmt_optinteger(L, 5, unset_noad_class);
        if (! valid_math_class_code(beginclass)) {
            beginclass = unset_noad_class;
        }
        if (! valid_math_class_code(endclass)) {
            endclass = unset_noad_class;
        }
        n = tex_mlist_to_hlist(n, penalties, style, beginclass, endclass, NULL);
    }
    nodelib_push_direct_or_nil(L, n);
    return 1;
}

/*tex

    This function is similar to |get_node_type_id|, for field identifiers. It has to do some more
    work, because not all identifiers are valid for all types of nodes. We can make this faster if
    needed but when this needs to be called often something is wrong with the code.

*/

static int nodelib_aux_get_node_field_id(lua_State *L, int n, int node)
{
    int t = node_type(node);
    const char *s = lua_tostring(L, n);
    if (! s) {
        return -2;
    } else if (lua_key_eq(s, next)) {
        return 0;
    } else if (lua_key_eq(s, id)) {
        return 1;
    } else if (lua_key_eq(s, subtype)) {
        if (tex_nodetype_has_subtype(t)) {
            return 2;
        }
    } else if (lua_key_eq(s, attr)) {
        if (tex_nodetype_has_attributes(t)) {
            return 3;
        }
    } else if (lua_key_eq(s, prev)) {
        if (tex_nodetype_has_prev(t)) {
            return -1;
        }
    } else {
        value_info *fields = lmt_interface.node_data[t].fields;
        if (fields) {
            if (lua_key_eq(s, list)) {
                const char *sh = lua_key(head);
                for (int j = 0; fields[j].lua; j++) {
                    if (fields[j].name == s || fields[j].name == sh) {
                        return j + 3;
                    }
                }
            } else {
                for (int j = 0; fields[j].lua; j++) {
                    if (fields[j].name == s) {
                        return j + 3;
                    }
                }
            }
        }
    }
    return -2;
}

/* node.hasfield */

static int nodelib_userdata_hasfield(lua_State *L)
{
    int i = -2;
    if (! lua_isnil(L, 1)) {
        i = nodelib_aux_get_node_field_id(L, 2, lmt_check_isnode(L, 1));
    }
    lua_pushboolean(L, (i != -2));
    return 1;
}

/* node.direct.hasfield */

static int nodelib_direct_hasfield(lua_State *L)
{
    int i = -2;
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        i = nodelib_aux_get_node_field_id(L, 2, n);
    }
    lua_pushboolean(L, (i != -2));
    return 1;
}

/* node.types */

static int nodelib_shared_types(lua_State *L)
{
    lua_newtable(L);
    for (int i = 0; lmt_interface.node_data[i].id != -1; i++) {
        if (lmt_interface.node_data[i].visible) {
            lua_pushstring(L, lmt_interface.node_data[i].name);
            lua_rawseti(L, -2, lmt_interface.node_data[i].id);
        }
    }
    return 1;
}

/* node.fields (fetch the list of valid fields) */

static int nodelib_shared_fields(lua_State *L)
{
    int offset = 2;
    int t = nodelib_aux_get_valid_node_type_id(L, 1);
    int f = lua_toboolean(L, 2);
    value_info *fields = lmt_interface.node_data[t].fields;
    lua_newtable(L);
    if (f) {
        lua_push_key(next);
        lua_push_key(node);
        lua_rawset(L, -3);
        lua_push_key(id)
        lua_push_key(integer);
        lua_rawset(L, -3);
        if (tex_nodetype_has_subtype(t)) {
            lua_push_key(subtype);
            lua_push_key(integer);
            lua_rawset(L, -3);
            offset++;
        }
        if (tex_nodetype_has_prev(t)) {
            lua_push_key(prev);
            lua_push_key(node);
            lua_rawset(L, -3);
        }
        if (fields) {
            for (lua_Integer i = 0; fields[i].lua != 0; i++) {
                /* todo: use other macros */
                lua_push_key_by_index(fields[i].lua);
                lua_push_key_by_index(lmt_interface.field_type_values[fields[i].type].lua);
             // lua_pushinteger(L, fields[i].type);
                lua_rawset(L, -3);
            }
        }
    } else {
        lua_push_key(next);
        lua_rawseti(L, -2, 0);
        lua_push_key(id);
        lua_rawseti(L, -2, 1);
        if (tex_nodetype_has_subtype(t)) {
            lua_push_key(subtype);
            lua_rawseti(L, -2, 2);
            offset++;
        }
        if (tex_nodetype_has_prev(t)) {
            lua_push_key(prev);
            lua_rawseti(L, -2, -1);
        }
        if (fields) {
            for (lua_Integer i = 0; fields[i].lua != 0; i++) {
             // lua_push_key_by_index(L, fields[i].lua);
                lua_rawgeti(L, LUA_REGISTRYINDEX, fields[i].lua);
                lua_rawseti(L, -2, i + offset);
            }
        }
    }
    return 1;
}

/* These should move to texlib ... which might happen.  */

static int nodelib_shared_values(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        /*
            delimiter options (bit set)
            delimiter modes   (bit set)
        */
        const char *s = lua_tostring(L, 1);
        if (lua_key_eq(s, glue) || lua_key_eq(s, fill)) {
            return lmt_push_info_values(L, lmt_interface.node_fill_values);
        } else if (lua_key_eq(s, dir)) {
            return lmt_push_info_values(L, lmt_interface.direction_values);
        } else if (lua_key_eq(s, math)) {
            /*tex A bit strange place, so moved to lmttexlib. */
            return lmt_push_info_keys(L, lmt_interface.math_parameter_values);
        } else if (lua_key_eq(s, style)) {
            /*tex A bit strange place, so moved to lmttexlib. */
            return lmt_push_info_values(L, lmt_interface.math_style_values);
        } else if (lua_key_eq(s, page)) {
            /*tex These are never used, whatsit related. */
            return lmt_push_info_values(L, lmt_interface.page_contribute_values);
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_shared_subtypes(lua_State *L)
{
    value_info *subtypes = NULL;
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            {
                /* official accessors */
                const char *s = lua_tostring(L,1);
                     if (lua_key_eq(s, glyph))     subtypes = lmt_interface.node_data[glyph_node]    .subtypes;
                else if (lua_key_eq(s, glue))      subtypes = lmt_interface.node_data[glue_node]     .subtypes;
                else if (lua_key_eq(s, dir))       subtypes = lmt_interface.node_data[dir_node]      .subtypes;
                else if (lua_key_eq(s, mark))      subtypes = lmt_interface.node_data[mark_node]     .subtypes;
                else if (lua_key_eq(s, boundary))  subtypes = lmt_interface.node_data[boundary_node] .subtypes;
                else if (lua_key_eq(s, penalty))   subtypes = lmt_interface.node_data[penalty_node]  .subtypes;
                else if (lua_key_eq(s, kern))      subtypes = lmt_interface.node_data[kern_node]     .subtypes;
                else if (lua_key_eq(s, rule))      subtypes = lmt_interface.node_data[rule_node]     .subtypes;
                else if (lua_key_eq(s, list)
                     ||  lua_key_eq(s, hlist)
                     ||  lua_key_eq(s, vlist))     subtypes = lmt_interface.node_data[hlist_node]    .subtypes; /* too many but ok as reserved */
                else if (lua_key_eq(s, adjust))    subtypes = lmt_interface.node_data[adjust_node]   .subtypes;
                else if (lua_key_eq(s, disc))      subtypes = lmt_interface.node_data[disc_node]     .subtypes;
                else if (lua_key_eq(s, math))      subtypes = lmt_interface.node_data[math_node]     .subtypes;
                else if (lua_key_eq(s, noad))      subtypes = lmt_interface.node_data[simple_noad]   .subtypes;
                else if (lua_key_eq(s, radical))   subtypes = lmt_interface.node_data[radical_noad]  .subtypes;
                else if (lua_key_eq(s, accent))    subtypes = lmt_interface.node_data[accent_noad]   .subtypes;
                else if (lua_key_eq(s, fence))     subtypes = lmt_interface.node_data[fence_noad]    .subtypes;
                else if (lua_key_eq(s, choice))    subtypes = lmt_interface.node_data[choice_node]   .subtypes;
                else if (lua_key_eq(s, par))       subtypes = lmt_interface.node_data[par_node]      .subtypes;
                else if (lua_key_eq(s, attribute)) subtypes = lmt_interface.node_data[attribute_node].subtypes;
            }
            break;
        case LUA_TNUMBER:
            switch (lua_tointeger(L, 1)) {
                case glyph_node:     subtypes = lmt_interface.node_data[glyph_node]    .subtypes; break;
                case glue_node:      subtypes = lmt_interface.node_data[glue_node]     .subtypes; break;
                case dir_node:       subtypes = lmt_interface.node_data[dir_node]      .subtypes; break;
                case boundary_node:  subtypes = lmt_interface.node_data[boundary_node] .subtypes; break;
                case penalty_node:   subtypes = lmt_interface.node_data[penalty_node]  .subtypes; break;
                case kern_node:      subtypes = lmt_interface.node_data[kern_node]     .subtypes; break;
                case rule_node:      subtypes = lmt_interface.node_data[rule_node]     .subtypes; break;
                case hlist_node:     subtypes = lmt_interface.node_data[hlist_node]    .subtypes; break;
                case vlist_node:     subtypes = lmt_interface.node_data[vlist_node]    .subtypes; break;
                case adjust_node:    subtypes = lmt_interface.node_data[adjust_node]   .subtypes; break;
                case disc_node:      subtypes = lmt_interface.node_data[disc_node]     .subtypes; break;
                case math_node:      subtypes = lmt_interface.node_data[math_node]     .subtypes; break;
                case simple_noad:    subtypes = lmt_interface.node_data[simple_noad]   .subtypes; break;
                case radical_noad:   subtypes = lmt_interface.node_data[radical_noad]  .subtypes; break;
                case accent_noad:    subtypes = lmt_interface.node_data[accent_noad]   .subtypes; break;
                case fence_noad:     subtypes = lmt_interface.node_data[fence_noad]    .subtypes; break;
                case choice_node:    subtypes = lmt_interface.node_data[choice_node]   .subtypes; break;
                case par_node:       subtypes = lmt_interface.node_data[par_node]      .subtypes; break;
                case attribute_node: subtypes = lmt_interface.node_data[attribute_node].subtypes; break;
            }
            break;
    }
    if (subtypes) {
        lua_newtable(L);
        for (int i = 0; subtypes[i].name; i++) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, subtypes[i].lua);
            lua_rawseti(L, -2, subtypes[i].id);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.slide */

static int nodelib_direct_slide(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        while (node_next(n)) {
            node_prev(node_next(n)) = n;
            n = node_next(n);
        }
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.tail (find the end of a list) */

static int nodelib_userdata_tail(lua_State *L)
{
    if (! lua_isnil(L, 1)) {
        halfword n = lmt_check_isnode(L, 1);
        if (n) {
            while (node_next(n)) {
                n = node_next(n);
            }
            lmt_push_node_fast(L, n);
        } else {
            /*tex We keep the old userdata. */
        }
    }
    return 1;
}

/* node.direct.tail */

static int nodelib_direct_tail(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        while (node_next(n)) {
            n = node_next(n);
        }
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.endofmath */

static int nodelib_direct_endofmath(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        if (node_type(n) == math_node && node_subtype(n) == end_inline_math) {
            lua_pushinteger(L, n);
            return 1;
        } else {
            int level = 1;
            while (node_next(n)) {
                n = node_next(n);
                if (n && node_type(n) == math_node) { 
                    switch (node_subtype(n)) { 
                        case begin_inline_math:
                            ++level;
                            break;
                        case end_inline_math:
                            --level;
                            if (level > 0) {
                                break;
                            } else {
                                lua_pushinteger(L, n);
                                return 1;
                            }
                        
                    }
                }
            }
         // if (level > 0) { 
         //     /* something is wrong */
         // }
        }
    }
    return 0;
}

/* node.hasattribute (gets attribute) */

static int nodelib_userdata_hasattribute(lua_State *L)
{
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        int key = lmt_tointeger(L, 2);
        int val = tex_has_attribute(n, key, lmt_optinteger(L, 3, unused_attribute_value));
        if (val > unused_attribute_value) {
            lua_pushinteger(L, val);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

/* node.direct.has_attribute */

static int nodelib_direct_hasattribute(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int key = nodelib_valid_direct_from_index(L, 2);
        int val = tex_has_attribute(n, key, lmt_optinteger(L, 3, unused_attribute_value));
        if (val > unused_attribute_value) {
            lua_pushinteger(L, val);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

/* node.get_attribute */

static int nodelib_userdata_getattribute(lua_State *L)
{
    halfword p = lmt_check_isnode(L, 1);
    if (tex_nodetype_has_attributes(node_type(p))) {
        p = node_attr(p);
        if (p) {
            p = node_next(p);
            if (p) {
                int i = lmt_optinteger(L, 2, 0);
                while (p) {
                    if (attribute_index(p) == i) {
                        int v = attribute_value(p);
                        if (v == unused_attribute_value) {
                            break;
                        } else {
                            lua_pushinteger(L, v);
                            return 1;
                        }
                    } else if (attribute_index(p) > i) {
                        break;
                    }
                    p = node_next(p);
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_findattributerange(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    if (h) {
        halfword i = lmt_tohalfword(L, 2);
        while (h) {
            if (tex_nodetype_has_attributes(node_type(h))) {
                halfword p = node_attr(h);
                if (p) {
                    p = node_next(p);
                    while (p) {
                        if (attribute_index(p) == i) {
                            if (attribute_value(p) == unused_attribute_value) {
                                break;
                            } else {
                                halfword t = h;
                                while (node_next(t)) {
                                    t = node_next(t);
                                }
                                while (t != h) {
                                    if (tex_nodetype_has_attributes(node_type(t))) {
                                        halfword a = node_attr(t);
                                        if (a) {
                                            a = node_next(a);
                                            while (a) {
                                                if (attribute_index(a) == i) {
                                                    if (attribute_value(a) == unused_attribute_value) {
                                                        break;
                                                    } else {
                                                        goto FOUND;
                                                    }
                                                } else if (attribute_index(a) > i) {
                                                    break;
                                                }
                                                a = node_next(a);
                                            }
                                        }
                                    }
                                    t = node_prev(t);
                                }
                              FOUND:
                                lua_pushinteger(L, h);
                                lua_pushinteger(L, t);
                                return 2;
                            }
                        } else if (attribute_index(p) > i) {
                            break;
                        }
                        p = node_next(p);
                    }
                }
            }
            h = node_next(h);
        }
    }
    return 0;
}

/* node.direct.getattribute */
/* node.direct.setattribute */
/* node.direct.unsetattribute */
/* node.direct.findattribute */

static int nodelib_direct_getattribute(lua_State *L)
{
    halfword p = nodelib_valid_direct_from_index(L, 1);
    if (p) {
        if (node_type(p) != attribute_node) {
            p = tex_nodetype_has_attributes(node_type(p)) ? node_attr(p) : null;
        }
        if (p) {
            if (node_subtype(p) == attribute_list_subtype) {
                p = node_next(p);
            }
            if (p) {
                halfword index = lmt_opthalfword(L, 2, 0);
                while (p) {
                    halfword i = attribute_index(p);
                    if (i == index) {
                        int v = attribute_value(p);
                        if (v == unused_attribute_value) {
                            break;
                        } else {
                            lua_pushinteger(L, v);
                            return 1;
                        }
                    } else if (i > index) {
                        break;
                    }
                    p = node_next(p);
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getattributes(lua_State *L)
{
    halfword p = nodelib_valid_direct_from_index(L, 1);
    if (p) {
        if (node_type(p) != attribute_node) {
            p = tex_nodetype_has_attributes(node_type(p)) ? node_attr(p) : null;
        }
        if (p) {
            if (node_subtype(p) == attribute_list_subtype) {
                p = node_next(p);
            }
            if (p) {
                int top = lua_gettop(L);
                for (int i = 2; i <= top; i++) {
                    halfword a = lmt_tohalfword(L, i);
                    halfword n = p;
                    halfword v = unused_attribute_value;
                    while (n) {
                        halfword id = attribute_index(n);
                        if (id == a) {
                            v = attribute_value(n);
                            break;
                        } else if (id > a) {
                            break;
                        } else {
                            n = node_next(n);
                        }
                    }
                    if (v == unused_attribute_value) {
                        lua_pushnil(L);
                    } else {
                        lua_pushinteger(L, v);
                    }
                }
                return top - 1;
            }
        }
    }
    return 0;
}

static int nodelib_direct_setattribute(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && tex_nodetype_has_attributes(node_type(n))) { // already checked
        halfword index = lmt_tohalfword(L, 2);
        halfword value = lmt_optinteger(L, 3, unused_attribute_value);
     // if (value == unused_attribute_value) {
     //     tex_unset_attribute(n, index, value);
     // } else {
            tex_set_attribute(n, index, value);
     // }
    }
    return 0;
}

/* set_attributes(n,[initial,]key1,val1,key2,val2,...) */

static int nodelib_direct_setattributes(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && tex_nodetype_has_attributes(node_type(n))) {
        int top = lua_gettop(L);
        int ini = 2;
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            ++ini;
            if (lua_toboolean(L, 2) && ! node_attr(n)) {
                attach_current_attribute_list(n);
            }
        }
        for (int i = ini; i <= top; i += 2) {
            halfword key = lmt_tohalfword(L, i);
            halfword val = lmt_optinteger(L, i + 1, unused_attribute_value);
         // if (val == unused_attribute_value) {
         //     tex_unset_attribute(p, key, val);
         // } else {
                tex_set_attribute(n, key, val);
         // }
        }
    }
    return 0;
}

static int nodelib_direct_patchattributes(lua_State *L)
{
    halfword p = nodelib_valid_direct_from_index(L, 1);
    if (p) { /* todo: check if attributes */
        halfword att = null;
        int top = lua_gettop(L);
        for (int i = 2; i <= top; i += 2) {
            halfword index = lmt_tohalfword(L, i);
            halfword value = lua_type(L, i + 1) == LUA_TNUMBER ? lmt_tohalfword(L, i + 1) : unused_attribute_value;
            if (att) {
                att = tex_patch_attribute_list(att, index, value);
            } else {
                att = tex_copy_attribute_list_set(node_attr(p), index, value);
            }
        }
        tex_attach_attribute_list_attribute(p, att);
    }
    return 0;
}

static int nodelib_direct_findattribute(lua_State *L) /* returns attr value and node */
{
    halfword c = nodelib_valid_direct_from_index(L, 1);
    if (c) {
        halfword i = lmt_tohalfword(L, 2);
        while (c) {
            if (tex_nodetype_has_attributes(node_type(c))) {
                halfword p = node_attr(c);
                if (p) {
                    p = node_next(p);
                    while (p) {
                        if (attribute_index(p) == i) {
                            halfword ret = attribute_value(p);
                            if (ret == unused_attribute_value) {
                                break;
                            } else {
                                lua_pushinteger(L, ret);
                                lua_pushinteger(L, c);
                                return 2;
                            }
                        } else if (attribute_index(p) > i) {
                            break;
                        }
                        p = node_next(p);
                    }
                }
            }
            c = node_next(c);
        }
    }
    return 0;
}

static int nodelib_direct_unsetattribute(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword key = lmt_checkhalfword(L, 2);
        halfword val = lmt_opthalfword(L, 3, unused_attribute_value);
        halfword ret = tex_unset_attribute(n, key, val);
        if (ret > unused_attribute_value) { /* != */
            lua_pushinteger(L, ret);
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}
static int nodelib_direct_unsetattributes(lua_State *L)
{
    halfword key = lmt_checkhalfword(L, 1);
    halfword first = nodelib_valid_direct_from_index(L, 2);
    halfword last = nodelib_valid_direct_from_index(L, 3);
    if (first) {
        tex_unset_attributes(first, last, key);
    }
    return 0;
}

/* node.set_attribute */
/* node.unset_attribute */

static int nodelib_userdata_setattribute(lua_State *L)
{
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        halfword key = lmt_tohalfword(L, 2);
        halfword val = lmt_opthalfword(L, 3, unused_attribute_value);
        if (val == unused_attribute_value) {
            tex_unset_attribute(n, key, val);
        } else {
            tex_set_attribute(n, key, val);
        }
    }
    return 0;
}

static int nodelib_userdata_unsetattribute(lua_State *L)
{
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        halfword key = lmt_checkhalfword(L, 2);
        halfword val = lmt_opthalfword(L, 3, unused_attribute_value);
        halfword ret = tex_unset_attribute(n, key, val);
        if (ret > unused_attribute_value) {
            lua_pushinteger(L, ret);
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.getglue */
/* node.direct.setglue */
/* node.direct.iszeroglue */

static int nodelib_direct_getglue(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glue_node:
            case glue_spec_node:
                lua_pushinteger(L, glue_amount(n));
                lua_pushinteger(L, glue_stretch(n));
                lua_pushinteger(L, glue_shrink(n));
                lua_pushinteger(L, glue_stretch_order(n));
                lua_pushinteger(L, glue_shrink_order(n));
                return 5;
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushnumber(L, (double) box_glue_set(n)); /* float */
                lua_pushinteger(L, box_glue_order(n));
                lua_pushinteger(L, box_glue_sign(n));
                return 3;
            case math_node:
                lua_pushinteger(L, math_amount(n));
                lua_pushinteger(L, math_stretch(n));
                lua_pushinteger(L, math_shrink(n));
                lua_pushinteger(L, math_stretch_order(n));
                lua_pushinteger(L, math_shrink_order(n));
                return 5;
        }
    }
    return 0;
}

static int nodelib_direct_setglue(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int top = lua_gettop(L);
        switch (node_type(n)) {
            case glue_node:
            case glue_spec_node:
                glue_amount(n)        = ((top > 1 && lua_type(L, 2) == LUA_TNUMBER)) ? (halfword) lmt_roundnumber(L, 2) : 0;
                glue_stretch(n)       = ((top > 2 && lua_type(L, 3) == LUA_TNUMBER)) ? (halfword) lmt_roundnumber(L, 3) : 0;
                glue_shrink(n)        = ((top > 3 && lua_type(L, 4) == LUA_TNUMBER)) ? (halfword) lmt_roundnumber(L, 4) : 0;
                glue_stretch_order(n) = tex_checked_glue_order((top > 4 && lua_type(L, 5) == LUA_TNUMBER) ? lmt_tohalfword(L, 5) : 0);
                glue_shrink_order(n)  = tex_checked_glue_order((top > 5 && lua_type(L, 6) == LUA_TNUMBER) ? lmt_tohalfword(L, 6) : 0);
                break;
            case hlist_node:
            case vlist_node:
            case unset_node:
                box_glue_set(n)   = ((top > 1 && lua_type(L, 2) == LUA_TNUMBER)) ? (glueratio) lua_tonumber(L, 2)  : 0;
                box_glue_order(n) = tex_checked_glue_order((top > 2 && lua_type(L, 3) == LUA_TNUMBER) ? (halfword)  lua_tointeger(L, 3) : 0);
                box_glue_sign(n)  = tex_checked_glue_sign((top > 3 && lua_type(L, 4) == LUA_TNUMBER) ? (halfword)  lua_tointeger(L, 4) : 0);
                break;
            case math_node:
                math_amount(n)        = ((top > 1 && lua_type(L, 2) == LUA_TNUMBER)) ? (halfword) lmt_roundnumber(L, 2) : 0;
                math_stretch(n)       = ((top > 2 && lua_type(L, 3) == LUA_TNUMBER)) ? (halfword) lmt_roundnumber(L, 3) : 0;
                math_shrink(n)        = ((top > 3 && lua_type(L, 4) == LUA_TNUMBER)) ? (halfword) lmt_roundnumber(L, 4) : 0;
                math_stretch_order(n) = tex_checked_glue_order((top > 4 && lua_type(L, 5) == LUA_TNUMBER) ? lmt_tohalfword(L, 5) : 0);
                math_shrink_order(n)  = tex_checked_glue_order((top > 5 && lua_type(L, 6) == LUA_TNUMBER) ? lmt_tohalfword(L, 6) : 0);
                break;
        }
    }
    return 0;
}

static int nodelib_direct_iszeroglue(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glue_node:
            case glue_spec_node:
                lua_pushboolean(L, glue_amount(n) == 0 && glue_stretch(n) == 0 && glue_shrink(n) == 0);
                return 1;
            case hlist_node:
            case vlist_node:
                lua_pushboolean(L, box_glue_set(n) == 0.0 && box_glue_order(n) == 0 && box_glue_sign(n) == 0);
                return 1;
            case math_node:
                lua_pushboolean(L, math_amount(n) == 0 && math_stretch(n) == 0 && math_shrink(n) == 0);
                return 1;
        }
    }
    return 0;
}

/* direct.startofpar */

static int nodelib_direct_startofpar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    lua_pushboolean(L, n && tex_is_start_of_par_node(n));
    return 1;
}

/* iteration */

static int nodelib_aux_nil(lua_State *L)
{
    lua_pushnil(L);
    return 1;
}

/* node.direct.traverse */
/* node.direct.traverse_id */
/* node.direct.traverse_char */
/* node.direct.traverse_glyph */
/* node.direct.traverse_list */
/* node.direct.traverse_leader */

static int nodelib_direct_aux_next(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_aux_prev(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_traverse(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_pushcclosure(L, nodelib_direct_aux_prev, 0);
            } else {
                lua_pushcclosure(L, nodelib_direct_aux_next, 0);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}

static int nodelib_direct_aux_next_filtered(lua_State *L)
{
    halfword t;
    int i = (int) lua_tointeger(L, lua_upvalueindex(1));
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t && node_type(t) != i) {
        t = node_next(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_subtype(t));
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_aux_prev_filtered(lua_State *L)
{
    halfword t;
    int i = (int) lua_tointeger(L, lua_upvalueindex(1));
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    while (t && node_type(t) != i) {
        t = node_prev(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_subtype(t));
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_traverseid(lua_State *L)
{
    if (lua_isnil(L, 2)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 2);
        if (n) {
            if (lua_toboolean(L, 3)) {
                if (lua_toboolean(L, 4)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_settop(L, 1);
                lua_pushcclosure(L, nodelib_direct_aux_prev_filtered, 1);
            } else {
                lua_settop(L, 1);
                lua_pushcclosure(L, nodelib_direct_aux_next_filtered, 1);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            return 0;
        }
    }
}

static int nodelib_direct_aux_next_char(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t && (node_type(t) != glyph_node || glyph_protected(t))) {
        t = node_next(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, glyph_character(t));
        lua_pushinteger(L, glyph_font(t));
        lua_pushinteger(L, glyph_data(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_aux_prev_char(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    while (t && (node_type(t) != glyph_node || glyph_protected(t))) {
        t = node_prev(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, glyph_character(t));
        lua_pushinteger(L, glyph_font(t));
        lua_pushinteger(L, glyph_data(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_traversechar(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_pushcclosure(L, nodelib_direct_aux_prev_char, 0);
            } else {
                lua_pushcclosure(L, nodelib_direct_aux_next_char, 0);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}

static int nodelib_direct_aux_next_glyph(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t && node_type(t) != glyph_node) {
        t = node_next(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, glyph_character(t));
        lua_pushinteger(L, glyph_font(t));
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_aux_prev_glyph(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    while (t && node_type(t) != glyph_node) {
        t = node_prev(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, glyph_character(t));
        lua_pushinteger(L, glyph_font(t));
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_traverseglyph(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_pushcclosure(L, nodelib_direct_aux_prev_glyph, 0);
            } else {
                lua_pushcclosure(L, nodelib_direct_aux_next_glyph, 0);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}

static int nodelib_direct_aux_next_list(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t && node_type(t) != hlist_node && node_type(t) != vlist_node) {
        t = node_next(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        nodelib_push_direct_or_nil(L, box_list(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_aux_prev_list(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    while (t && node_type(t) != hlist_node && node_type(t) != vlist_node) {
        t = node_prev(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        nodelib_push_direct_or_nil(L, box_list(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_traverselist(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_pushcclosure(L, nodelib_direct_aux_prev_list, 0);
            } else {
                lua_pushcclosure(L, nodelib_direct_aux_next_list, 0);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}

/*tex This is an experiment. */

static int nodelib_direct_aux_next_leader(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t && ! ((node_type(t) == hlist_node || node_type(t) == vlist_node) && has_box_package_state(t, package_u_leader_set))) {
        t = node_next(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        nodelib_push_direct_or_nil(L, box_list(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_aux_prev_leader(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    while (t && ! ((node_type(t) == hlist_node || node_type(t) == vlist_node) && has_box_package_state(t, package_u_leader_set))) {
        t = node_prev(t);
    }
    if (t) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        nodelib_push_direct_or_nil(L, box_list(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_direct_traverseleader(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_pushcclosure(L, nodelib_direct_aux_prev_leader, 0);
            } else {
                lua_pushcclosure(L, nodelib_direct_aux_next_leader, 0);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}


/*tex This is an experiment. */

static int nodelib_direct_aux_next_content(lua_State *L)
{
    halfword t;
    halfword l = null;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t) {
        switch (node_type(t)) {
            case glyph_node:
            case disc_node:
            case rule_node:
                goto FOUND;
            case glue_node:
                l = glue_leader_ptr(t);
                if (l) {
                    goto FOUND;
                } else {
                    break;
                }
            case hlist_node:
            case vlist_node:
                l = box_list(t);
                goto FOUND;
        }
        t = node_next(t);
    }
    lua_pushnil(L);
    return 1;
  FOUND:
    lua_pushinteger(L, t);
    lua_pushinteger(L, node_type(t));
    lua_pushinteger(L, node_subtype(t));
    if (l) {
        nodelib_push_direct_or_nil(L, l);
        return 4;
    } else {
        return 3;
    }
}

static int nodelib_direct_aux_prev_content(lua_State *L)
{
    halfword t;
    halfword l = null;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_prev(t);
        lua_settop(L, 2);
    }
    while (t) {
        switch (node_type(t)) {
            case glyph_node:
            case disc_node:
            case rule_node:
                goto FOUND;
            case glue_node:
                l = glue_leader_ptr(t);
                if (l) {
                    goto FOUND;
                } else {
                    break;
                }
            case hlist_node:
            case vlist_node:
                l = box_list(t);
                goto FOUND;
        }
        t = node_prev(t);
    }
    lua_pushnil(L);
    return 1;
  FOUND:
    lua_pushinteger(L, t);
    lua_pushinteger(L, node_type(t));
    lua_pushinteger(L, node_subtype(t));
    if (l) {
        nodelib_push_direct_or_nil(L, l);
        return 4;
    } else {
        return 3;
    }
}

static int nodelib_direct_traversecontent(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    n = tex_tail_of_node_list(n);
                }
                lua_pushcclosure(L, nodelib_direct_aux_prev_content, 0);
            } else {
                lua_pushcclosure(L, nodelib_direct_aux_next_content, 0);
            }
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}

/* node.traverse */
/* node.traverse_id */
/* node.traverse_char */
/* node.traverse_glyph */
/* node.traverse_list */

static int nodelib_aux_next(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_check_isnode(L, 1);
        lua_settop(L, 1);
    } else {
        t = lmt_check_isnode(L, 2);
        t = node_next(t);
        lua_settop(L, 2);
    }
    if (t) {
        nodelib_push_node_on_top(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_aux_prev(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_check_isnode(L, 1);
        lua_settop(L, 1);
    } else {
        t = lmt_check_isnode(L, 2);
        t = node_prev(t);
        lua_settop(L, 2);
    }
    if (t) {
        nodelib_push_node_on_top(L, t);
        lua_pushinteger(L, node_type(t));
        lua_pushinteger(L, node_subtype(t));
        return 3;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_userdata_traverse(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = lmt_check_isnode(L, 1);
        if (lua_toboolean(L, 2)) {
            if (lua_toboolean(L, 3)) {
                n = tex_tail_of_node_list(n);
            }
            lua_pushcclosure(L, nodelib_aux_prev, 0);
        } else {
            lua_pushcclosure(L, nodelib_aux_next, 0);
        }
        lmt_push_node_fast(L, n);
        lua_pushnil(L);
        return 3;
    }
}

static int nodelib_aux_next_filtered(lua_State *L)
{
    halfword t;
    int i = (int) lua_tointeger(L, lua_upvalueindex(1));
    if (lua_isnil(L, 2)) {
        /* first call */
        t = lmt_check_isnode(L, 1);
        lua_settop(L,1);
    } else {
        t = lmt_check_isnode(L, 2);
        t = node_next(t);
        lua_settop(L,2);
    }
    while (t && node_type(t) != i) {
        t = node_next(t);
    }
    if (t) {
        nodelib_push_node_on_top(L, t);
        lua_pushinteger(L, node_subtype(t));
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_aux_prev_filtered(lua_State *L)
{
    halfword t;
    int i = (int) lua_tointeger(L, lua_upvalueindex(1));
    if (lua_isnil(L, 2)) {
        /* first call */
        t = lmt_check_isnode(L, 1);
        lua_settop(L,1);
    } else {
        t = lmt_check_isnode(L, 2);
        t = node_prev(t);
        lua_settop(L,2);
    }
    while (t && node_type(t) != i) {
        t = node_prev(t);
    }
    if (t) {
        nodelib_push_node_on_top(L, t);
        lua_pushinteger(L, node_subtype(t));
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_userdata_traverse_id(lua_State *L)
{
    if (lua_isnil(L, 2)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = lmt_check_isnode(L, 2);
        if (lua_toboolean(L, 3)) {
            if (lua_toboolean(L, 4)) {
                n = tex_tail_of_node_list(n);
            }
            lua_settop(L, 1);
            lua_pushcclosure(L, nodelib_aux_prev_filtered, 1);
        } else {
            lua_settop(L, 1);
            lua_pushcclosure(L, nodelib_aux_next_filtered, 1);
        }
        lmt_push_node_fast(L, n);
        lua_pushnil(L);
        return 3;
    }
}

/* node.direct.length */
/* node.direct.count */

/*tex As with some other function that have a |last| we don't take that one into account. */

static int nodelib_direct_length(lua_State *L)
{
    halfword first = nodelib_valid_direct_from_index(L, 1);
    halfword last = nodelib_valid_direct_from_index(L, 2);
    int count = 0;
    if (first) {
        while (first != last) {
            count++;
            first = node_next(first);
        }
    }
    lua_pushinteger(L, count);
    return 1;
}

static int nodelib_direct_count(lua_State *L)
{
    quarterword id = lmt_toquarterword(L, 1);
    halfword first = nodelib_valid_direct_from_index(L, 2);
    halfword last = nodelib_valid_direct_from_index(L, 3);
    int count = 0;
    if (first) {
        while (first != last) {
            if (node_type(first) == id) {
                count++;
            }
            first = node_next(first);
        }
    }
    lua_pushinteger(L, count);
    return 1;
}

/*tex A few helpers for later usage: */

inline static int nodelib_getattribute_value(lua_State *L, halfword n, int index)
{
    halfword key = (halfword) lua_tointeger(L, index);
    halfword val = tex_has_attribute(n, key, unused_attribute_value);
    if (val == unused_attribute_value) {
        lua_pushnil(L);
    } else {
        lua_pushinteger(L, val);
    }
    return 1;
}

inline static void nodelib_setattribute_value(lua_State *L, halfword n, int kindex, int vindex)
{
    if (lua_gettop(L) >= kindex) {
        halfword key = lmt_tohalfword(L, kindex);
        halfword val = lmt_opthalfword(L, vindex, unused_attribute_value);
        if (val == unused_attribute_value) {
            tex_unset_attribute(n, key, val);
        } else {
            tex_set_attribute(n, key, val);
        }
    } else {
       luaL_error(L, "incorrect number of arguments");
    }
}

/* node.direct.getfield */
/* node.getfield */

/*tex

    The order is somewhat determined by the occurance of nodes and importance of fields. We use
    |somenode[9]| as interface to attributes ... 30\% faster than has_attribute (1) because there
    is no \LUA\ function overhead, and (2) because we already know that we deal with a node so no
    checking is needed. The fast typecheck is needed (lua_check... is a slow down actually).

    This is just a reminder for me: when used in the build page routine the |last_insert_ptr| and
    |best_insert_ptr| are sort of tricky as the first in a list can be a fake node (zero zero list
    being next). Because no properties are accessed this works ok. In the getfield routines we
    can assume that these nodes are never seen (the pagebuilder constructs insert nodes using that
    data). But it is something to keep an eye on when we open up more or add callbacks. So there
    is a comment below.

*/

static int nodelib_common_getfield(lua_State *L, int direct, halfword n)
{
    switch (lua_type(L, 2)) {
        case LUA_TNUMBER:
            {
                return nodelib_getattribute_value(L, n, 2);
            }
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L, 2);
                int t = node_type(n);
                if (lua_key_eq(s, id)) {
                    lua_pushinteger(L, t);
                } else if (lua_key_eq(s, next)) {
                    if (tex_nodetype_has_next(t)) {
                        nodelib_push_direct_or_node(L, direct, node_next(n));
                    } else {
                     /* nodelib_invalid_field_error(L, s, n); */
                        lua_pushnil(L);
                    }
                } else if (lua_key_eq(s, prev)) {
                    if (tex_nodetype_has_prev(t)) {
                        nodelib_push_direct_or_node(L, direct, node_prev(n));
                    } else {
                     /* nodelib_invalid_field_error(L, s, n); */
                        lua_pushnil(L);
                    }
                } else if (lua_key_eq(s, attr)) {
                    if (tex_nodetype_has_attributes(t)) {
                        nodelib_push_direct_or_node(L, direct, node_attr(n));
                    } else {
                     /* nodelib_invalid_field_error(L, s, n); */
                        lua_pushnil(L);
                    }
                } else if (lua_key_eq(s, subtype)) {
                    if (tex_nodetype_has_subtype(t)) {
                        lua_pushinteger(L, node_subtype(n));
                    } else {
                     /* nodelib_invalid_field_error(L, s, n); */
                        lua_pushnil(L);
                    }
                } else {
                    switch(t) {
                        case glyph_node:
                            if (lua_key_eq(s, font)) {
                                lua_pushinteger(L, glyph_font(n));
                            } else if (lua_key_eq(s, char)) {
                                lua_pushinteger(L, glyph_character(n));
                            } else if (lua_key_eq(s, xoffset)) {
                                lua_pushinteger(L, glyph_x_offset(n));
                            } else if (lua_key_eq(s, yoffset)) {
                                lua_pushinteger(L, glyph_y_offset(n));
                            } else if (lua_key_eq(s, data)) {
                                lua_pushinteger(L, glyph_data(n));
                            } else if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, tex_glyph_width(n));
                            } else if (lua_key_eq(s, height)) {
                                lua_pushinteger(L, tex_glyph_height(n));
                            } else if (lua_key_eq(s, depth)) {
                             // lua_pushinteger(L, char_depth_from_glyph(n));
                                lua_pushinteger(L, tex_glyph_depth(n));
                            } else if (lua_key_eq(s, total)) {
                             // lua_pushinteger(L, char_total_from_glyph(n));
                                lua_pushinteger(L, tex_glyph_total(n));
                            } else if (lua_key_eq(s, scale)) {
                                lua_pushinteger(L, glyph_scale(n));
                            } else if (lua_key_eq(s, xscale)) {
                                lua_pushinteger(L, glyph_x_scale(n));
                            } else if (lua_key_eq(s, yscale)) {
                                lua_pushinteger(L, glyph_y_scale(n));
                            } else if (lua_key_eq(s, expansion)) {
                                lua_pushinteger(L, glyph_expansion(n));
                            } else if (lua_key_eq(s, state)) {
                                lua_pushinteger(L, get_glyph_state(n));
                            } else if (lua_key_eq(s, script)) {
                                lua_pushinteger(L, get_glyph_script(n));
                            } else if (lua_key_eq(s, language)) {
                                lua_pushinteger(L, get_glyph_language(n));
                            } else if (lua_key_eq(s, lhmin)) {
                                lua_pushinteger(L, get_glyph_lhmin(n));
                            } else if (lua_key_eq(s, rhmin)) {
                                lua_pushinteger(L, get_glyph_rhmin(n));
                            } else if (lua_key_eq(s, left)) {
                                lua_pushinteger(L, get_glyph_left(n));
                            } else if (lua_key_eq(s, right)) {
                                lua_pushinteger(L, get_glyph_right(n));
                            } else if (lua_key_eq(s, uchyph)) {
                                lua_pushinteger(L, get_glyph_uchyph(n));
                            } else if (lua_key_eq(s, hyphenate)) {
                                lua_pushinteger(L, get_glyph_hyphenate(n));
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, get_glyph_options(n));
                            } else if (lua_key_eq(s, discpart)) {
                                lua_pushinteger(L, get_glyph_discpart(n));
                            } else if (lua_key_eq(s, protected)) {
                                lua_pushinteger(L, glyph_protected(n));
                            } else if (lua_key_eq(s, properties)) {
                                lua_pushinteger(L, glyph_properties(n));
                            } else if (lua_key_eq(s, group)) {
                                lua_pushinteger(L, glyph_group(n));
                            } else if (lua_key_eq(s, index)) {
                                lua_pushinteger(L, glyph_index(n));
                           } else {
                                lua_pushnil(L);
                            }
                            break;
                        case hlist_node:
                        case vlist_node:
                            /* candidates: whd (width,height,depth) */
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct, box_list(n));
                            } else if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, box_width(n));
                            } else if (lua_key_eq(s, height)) {
                                lua_pushinteger(L, box_height(n));
                            } else if (lua_key_eq(s, depth)) {
                                lua_pushinteger(L, box_depth(n));
                            } else if (lua_key_eq(s, total)) {
                                lua_pushinteger(L, box_total(n));
                            } else if (lua_key_eq(s, direction)) {
                                lua_pushinteger(L, checked_direction_value(box_dir(n)));
                            } else if (lua_key_eq(s, shift)) {
                                lua_pushinteger(L, box_shift_amount(n));
                            } else if (lua_key_eq(s, glueorder)) {
                                lua_pushinteger(L, box_glue_order(n));
                            } else if (lua_key_eq(s, gluesign)) {
                                lua_pushinteger(L, box_glue_sign(n));
                            } else if (lua_key_eq(s, glueset)) {
                                lua_pushnumber(L, (double) box_glue_set(n)); /* float */
                            } else if (lua_key_eq(s, geometry)) {
                                lua_pushinteger(L, box_geometry(n));
                            } else if (lua_key_eq(s, orientation)) {
                                lua_pushinteger(L, box_orientation(n));
                            } else if (lua_key_eq(s, anchor)) {
                                lua_pushinteger(L, box_anchor(n));
                            } else if (lua_key_eq(s, source)) {
                                lua_pushinteger(L, box_source_anchor(n));
                            } else if (lua_key_eq(s, target)) {
                                lua_pushinteger(L, box_target_anchor(n));
                            } else if (lua_key_eq(s, xoffset)) {
                                lua_pushinteger(L, box_x_offset(n));
                            } else if (lua_key_eq(s, yoffset)) {
                                lua_pushinteger(L, box_y_offset(n));
                            } else if (lua_key_eq(s, woffset)) {
                                lua_pushinteger(L, box_w_offset(n));
                            } else if (lua_key_eq(s, hoffset)) {
                                lua_pushinteger(L, box_h_offset(n));
                            } else if (lua_key_eq(s, doffset)) {
                                lua_pushinteger(L, box_d_offset(n));
                            } else if (lua_key_eq(s, pre)) {
                                nodelib_push_direct_or_node(L, direct, box_pre_migrated(n));
                            } else if (lua_key_eq(s, post)) {
                                nodelib_push_direct_or_node(L, direct, box_post_migrated(n));
                            } else if (lua_key_eq(s, state)) {
                                lua_pushinteger(L, box_package_state(n));
                            } else if (lua_key_eq(s, index)) {
                                lua_pushinteger(L, box_index(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case disc_node:
                            if (lua_key_eq(s, pre)) {
                                nodelib_push_direct_or_node(L, direct, disc_pre_break_head(n));
                            } else if (lua_key_eq(s, post)) {
                                nodelib_push_direct_or_node(L, direct, disc_post_break_head(n));
                            } else if (lua_key_eq(s, replace)) {
                                nodelib_push_direct_or_node(L, direct, disc_no_break_head(n));
                            } else if (lua_key_eq(s, penalty)) {
                                lua_pushinteger(L, disc_penalty(n));
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, disc_options(n));
                            } else if (lua_key_eq(s, class)) {
                                lua_pushinteger(L, disc_class(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case glue_node:
                            if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, glue_amount(n));
                            } else if (lua_key_eq(s, stretch)) {
                                lua_pushinteger(L, glue_stretch(n));
                            } else if (lua_key_eq(s, shrink)) {
                                lua_pushinteger(L, glue_shrink(n));
                            } else if (lua_key_eq(s, stretchorder)) {
                                lua_pushinteger(L, glue_stretch_order(n));
                            } else if (lua_key_eq(s, shrinkorder)) {
                                lua_pushinteger(L, glue_shrink_order(n));
                            } else if (lua_key_eq(s, leader)) {
                                nodelib_push_direct_or_node(L, direct, glue_leader_ptr(n));
                            } else if (lua_key_eq(s, font)) {
                                lua_pushinteger(L, glue_font(n));
                            } else if (lua_key_eq(s, data)) {
                                lua_pushinteger(L, glue_data(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case kern_node:
                            if (lua_key_eq(s, kern)) {
                                lua_pushinteger(L, kern_amount(n));
                            } else if (lua_key_eq(s, expansion)) {
                                lua_pushinteger(L, kern_expansion(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case penalty_node:
                            if (lua_key_eq(s, penalty)) {
                                lua_pushinteger(L, penalty_amount(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case rule_node:
                            /* candidates: whd (width,height,depth) */
                            if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, rule_width(n));
                            } else if (lua_key_eq(s, height)) {
                                lua_pushinteger(L, rule_height(n));
                            } else if (lua_key_eq(s, depth)) {
                                lua_pushinteger(L, rule_depth(n));
                            } else if (lua_key_eq(s, total)) {
                                lua_pushinteger(L, rule_total(n));
                            } else if (lua_key_eq(s, xoffset)) {
                                lua_pushinteger(L,rule_x_offset(n));
                            } else if (lua_key_eq(s, yoffset)) {
                                lua_pushinteger(L,rule_y_offset(n));
                            } else if (lua_key_eq(s, left)) {
                                lua_pushinteger(L,rule_left(n));
                            } else if (lua_key_eq(s, right)) {
                                lua_pushinteger(L,rule_right(n));
                            } else if (lua_key_eq(s, data)) {
                                lua_pushinteger(L,rule_data(n));
                            } else if (lua_key_eq(s, font)) {
                                lua_pushinteger(L, tex_get_rule_font(n, text_style));
                            } else if (lua_key_eq(s, fam)) {
                                lua_pushinteger(L, tex_get_rule_font(n, text_style));
                            } else if (lua_key_eq(s, char)) {
                                lua_pushinteger(L, rule_character(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case dir_node:
                            if (lua_key_eq(s, direction)) {
                                lua_pushinteger(L, dir_direction(n));
                            } else if (lua_key_eq(s, level)) {
                                lua_pushinteger(L, dir_level(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case whatsit_node:
                            lua_pushnil(L);
                            break;
                        case par_node:
                            /* not all of them here */
                            if (lua_key_eq(s, interlinepenalty)) {
                                lua_pushinteger(L, tex_get_local_interline_penalty(n));
                            } else if (lua_key_eq(s, brokenpenalty)) {
                                lua_pushinteger(L, tex_get_local_broken_penalty(n));
                            } else if (lua_key_eq(s, direction)) {
                                lua_pushinteger(L, par_dir(n));
                            } else if (lua_key_eq(s, leftbox)) {
                                nodelib_push_direct_or_node(L, direct, par_box_left(n));
                            } else if (lua_key_eq(s, leftboxwidth)) {
                                lua_pushinteger(L, tex_get_local_left_width(n));
                            } else if (lua_key_eq(s, rightbox)) {
                                nodelib_push_direct_or_node(L, direct, par_box_right(n));
                            } else if (lua_key_eq(s, rightboxwidth)) {
                                lua_pushinteger(L, tex_get_local_right_width(n));
                            } else if (lua_key_eq(s, middlebox)) {
                                nodelib_push_direct_or_node(L, direct, par_box_middle(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case math_char_node:
                        case math_text_char_node:
                            if (lua_key_eq(s, fam)) {
                                lua_pushinteger(L, kernel_math_family(n));
                            } else if (lua_key_eq(s, char)) {
                                lua_pushinteger(L, kernel_math_character(n));
                            } else if (lua_key_eq(s, font)) {
                                lua_pushinteger(L, tex_fam_fnt(kernel_math_family(n), 0));
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, kernel_math_options(n));
                            } else if (lua_key_eq(s, properties)) {
                                lua_pushinteger(L, kernel_math_properties(n));
                            } else if (lua_key_eq(s, group)) {
                                lua_pushinteger(L, kernel_math_group(n));
                            } else if (lua_key_eq(s, index)) {
                                lua_pushinteger(L, kernel_math_index(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case mark_node:
                            if (lua_key_eq(s, index) || lua_key_eq(s, class)) {
                                lua_pushinteger(L, mark_index(n));
                            } else if (lua_key_eq(s, data) || lua_key_eq(s, mark)) {
                                if (lua_toboolean(L, 3)) {
                                    lmt_token_list_to_luastring(L, mark_ptr(n), 0, 0, 0);
                                } else {
                                    lmt_token_list_to_lua(L, mark_ptr(n));
                                }
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case insert_node:
                            if (lua_key_eq(s, index)) {
                                lua_pushinteger(L, insert_index(n));
                            } else if (lua_key_eq(s, cost)) {
                                lua_pushinteger(L, insert_float_cost(n));
                            } else if (lua_key_eq(s, depth)) {
                                lua_pushinteger(L, insert_max_depth(n));
                            } else if (lua_key_eq(s, height) || lua_key_eq(s, total)) {
                                lua_pushinteger(L, insert_total_height(n));
                            } else if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct, insert_list(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case math_node:
                            if (lua_key_eq(s, surround)) {
                                lua_pushinteger(L, math_surround(n));
                            } else if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, math_amount(n));
                            } else if (lua_key_eq(s, stretch)) {
                                lua_pushinteger(L, math_stretch(n));
                            } else if (lua_key_eq(s, shrink)) {
                                lua_pushinteger(L, math_shrink(n));
                            } else if (lua_key_eq(s, stretchorder)) {
                                lua_pushinteger(L, math_stretch_order(n));
                            } else if (lua_key_eq(s, shrinkorder)) {
                                lua_pushinteger(L, math_shrink_order(n));
                            } else if (lua_key_eq(s, penalty)) {
                                lua_pushinteger(L, math_penalty(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case style_node:
                            if (lua_key_eq(s, style)) {
                                lmt_push_math_style_name(L, style_style(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case parameter_node:
                            if (lua_key_eq(s, style)) {
                                lmt_push_math_style_name(L, parameter_style(n));
                            } else if (lua_key_eq(s, name)) {
                                lmt_push_math_parameter(L, parameter_name(n));
                            } else if (lua_key_eq(s, value)) {
                                halfword code = parameter_name(n);
                                if (code < 0 || code >= math_parameter_last) {
                                    /* error */
                                    lua_pushnil(L);
                                } else if (math_parameter_value_type(code)) {
                                    /* todo, see tex_getmathparm */
                                    lua_pushnil(L);
                                } else {
                                    lua_pushinteger(L, parameter_value(n));
                                }
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case simple_noad:
                        case radical_noad:
                        case fraction_noad:
                        case accent_noad:
                        case fence_noad:
                            if (lua_key_eq(s, nucleus)) {
                                nodelib_push_direct_or_nil(L, noad_nucleus(n));
                            } else if (lua_key_eq(s, sub)) {
                                nodelib_push_direct_or_nil(L, noad_subscr(n));
                            } else if (lua_key_eq(s, sup)) {
                                nodelib_push_direct_or_nil(L, noad_supscr(n));
                            } else if (lua_key_eq(s, prime)) {
                                nodelib_push_direct_or_nil(L, noad_prime(n));
                            } else if (lua_key_eq(s, subpre)) {
                                nodelib_push_direct_or_nil(L, noad_subprescr(n));
                            } else if (lua_key_eq(s, suppre)) {
                                nodelib_push_direct_or_nil(L, noad_supprescr(n));
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, noad_options(n));
                            } else if (lua_key_eq(s, source)) {
                                lua_pushinteger(L, noad_source(n));
                            } else if (lua_key_eq(s, scriptorder)) {
                                lua_pushinteger(L, noad_script_order(n));
                            } else if (lua_key_eq(s, class)) {
                                lua_pushinteger(L, get_noad_main_class(n));
                                lua_pushinteger(L, get_noad_left_class(n));
                                lua_pushinteger(L, get_noad_right_class(n));
                                return 3;
                            } else if (lua_key_eq(s, fam)) {
                                lua_pushinteger(L, noad_family(n));
                            } else {
                                switch(t) {
                                    case simple_noad:
                                        lua_pushnil(L);
                                        break;
                                    case radical_noad:
                                        if (lua_key_eq(s, left) || lua_key_eq(s, delimiter)) {
                                            nodelib_push_direct_or_node(L, direct, radical_left_delimiter(n));
                                        } else if (lua_key_eq(s, right)) {
                                            nodelib_push_direct_or_node(L, direct, radical_right_delimiter(n));
                                        } else if (lua_key_eq(s, degree)) {
                                            nodelib_push_direct_or_node(L, direct, radical_degree(n));
                                        } else if (lua_key_eq(s, width)) {
                                            lua_pushinteger(L, noad_width(n));
                                        } else {
                                            lua_pushnil(L);
                                        }
                                        break;
                                    case fraction_noad:
                                        if (lua_key_eq(s, width)) {
                                            lua_pushinteger(L, fraction_rule_thickness(n));
                                        } else if (lua_key_eq(s, numerator)) {
                                            nodelib_push_direct_or_nil(L, fraction_numerator(n));
                                        } else if (lua_key_eq(s, denominator)) {
                                            nodelib_push_direct_or_nil(L, fraction_denominator(n));
                                        } else if (lua_key_eq(s, left)) {
                                            nodelib_push_direct_or_nil(L, fraction_left_delimiter(n));
                                        } else if (lua_key_eq(s, right)) {
                                            nodelib_push_direct_or_nil(L, fraction_right_delimiter(n));
                                        } else if (lua_key_eq(s, middle)) {
                                            nodelib_push_direct_or_nil(L, fraction_middle_delimiter(n));
                                        } else {
                                            lua_pushnil(L);
                                        }
                                        break;
                                    case accent_noad:
                                        if (lua_key_eq(s, top) || lua_key_eq(s, topaccent)) {
                                            nodelib_push_direct_or_node(L, direct, accent_top_character(n));
                                        } else if (lua_key_eq(s, bottom) || lua_key_eq(s, bottomaccent)) {
                                            nodelib_push_direct_or_node(L, direct, accent_bottom_character(n));
                                        } else if (lua_key_eq(s, middle) || lua_key_eq(s, overlayaccent)) {
                                            nodelib_push_direct_or_node(L, direct, accent_middle_character(n));
                                        } else if (lua_key_eq(s, fraction)) {
                                            lua_pushinteger(L, accent_fraction(n));
                                        } else {
                                            lua_pushnil(L);
                                        }
                                        break;
                                    case fence_noad:
                                        if (lua_key_eq(s, delimiter)) {
                                            nodelib_push_direct_or_node(L, direct, fence_delimiter_list(n));
                                        } else if (lua_key_eq(s, top)) {
                                            nodelib_push_direct_or_node(L, direct, fence_delimiter_top(n));
                                        } else if (lua_key_eq(s, bottom)) {
                                            nodelib_push_direct_or_node(L, direct, fence_delimiter_bottom(n));
                                        } else if (lua_key_eq(s, italic)) {
                                            lua_pushinteger(L, noad_italic(n));
                                        } else if (lua_key_eq(s, height)) {
                                            lua_pushinteger(L, noad_height(n));
                                        } else if (lua_key_eq(s, depth)) {
                                            lua_pushinteger(L, noad_depth(n));
                                        } else if (lua_key_eq(s, total)) {
                                            lua_pushinteger(L, noad_total(n));
                                        } else {
                                            lua_pushnil(L);
                                        }
                                        break;
                                }
                            }
                            break;
                        case delimiter_node:
                            if (lua_key_eq(s, smallfamily)) {
                                lua_pushinteger(L, delimiter_small_family(n));
                            } else if (lua_key_eq(s, smallchar)) {
                                lua_pushinteger(L, delimiter_small_character(n));
                            } else if (lua_key_eq(s, largefamily)) {
                                lua_pushinteger(L, delimiter_large_family(n));
                            } else if (lua_key_eq(s, largechar)) {
                                lua_pushinteger(L, delimiter_large_character(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case sub_box_node:
                        case sub_mlist_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct,  kernel_math_list(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case split_node:
                            if (lua_key_eq(s, index)) {
                                lua_push_integer(L, split_insert_index(n));
                            } else if (lua_key_eq(s, lastinsert)) {
                                nodelib_push_direct_or_node(L, direct, split_last_insert(n)); /* see comment */
                            } else if (lua_key_eq(s, bestinsert)) {
                                nodelib_push_direct_or_node(L, direct, split_best_insert(n)); /* see comment */
                            } else if (lua_key_eq(s, broken)) {
                                nodelib_push_direct_or_node(L, direct, split_broken(n));
                            } else if (lua_key_eq(s, brokeninsert)) {
                                nodelib_push_direct_or_node(L, direct, split_broken_insert(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case choice_node:
                            /*tex We could check and combine some here but who knows how things evolve. */
                            if (lua_key_eq(s, display)) {
                                nodelib_push_direct_or_node(L, direct, choice_display_mlist(n));
                            } else if (lua_key_eq(s, text)) {
                                nodelib_push_direct_or_node(L, direct, choice_text_mlist(n));
                            } else if (lua_key_eq(s, script)) {
                                nodelib_push_direct_or_node(L, direct, choice_script_mlist(n));
                            } else if (lua_key_eq(s, scriptscript)) {
                                nodelib_push_direct_or_node(L, direct, choice_script_script_mlist(n));
                            } else if (lua_key_eq(s, pre)) {
                                nodelib_push_direct_or_node(L, direct, choice_pre_break(n));
                            } else if (lua_key_eq(s, post)) {
                                nodelib_push_direct_or_node(L, direct, choice_post_break(n));
                            } else if (lua_key_eq(s, replace)) {
                                nodelib_push_direct_or_node(L, direct, choice_no_break(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case attribute_node:
                            switch (node_subtype(n)) {
                                case attribute_list_subtype:
                                    if (lua_key_eq(s, count)) {
                                        lua_pushinteger(L, attribute_count(n));
                                    } else if (lua_key_eq(s, data)) {
                                        nodelib_push_attribute_data(L, n);
                                    } else {
                                        lua_pushnil(L);
                                    }
                                    break;
                                case attribute_value_subtype:
                                    if (lua_key_eq(s, index) || lua_key_eq(s, number)) {
                                        lua_pushinteger(L, attribute_index(n));
                                    } else if (lua_key_eq(s, value)) {
                                        lua_pushinteger(L, attribute_value(n));
                                    } else {
                                        lua_pushnil(L);
                                    }
                                    break;
                                default:
                                    lua_pushnil(L);
                                    break;
                            }
                            break;
                        case adjust_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct, adjust_list(n));
                            } else if (lua_key_eq(s, index) || lua_key_eq(s, class)) {
                                lua_pushinteger(L, adjust_index(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case unset_node:
                            if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, box_width(n));
                            } else if (lua_key_eq(s, height)) {
                                lua_pushinteger(L, box_height(n));
                            } else if (lua_key_eq(s, depth)) {
                                lua_pushinteger(L, box_depth(n));
                            } else if (lua_key_eq(s, total)) {
                                lua_pushinteger(L, box_total(n));
                            } else if (lua_key_eq(s, direction)) {
                                lua_pushinteger(L, checked_direction_value(box_dir(n)));
                            } else if (lua_key_eq(s, shrink)) {
                                lua_pushinteger(L, box_glue_shrink(n));
                            } else if (lua_key_eq(s, glueorder)) {
                                lua_pushinteger(L, box_glue_order(n));
                            } else if (lua_key_eq(s, gluesign)) {
                                lua_pushinteger(L, box_glue_sign(n));
                            } else if (lua_key_eq(s, stretch)) {
                                lua_pushinteger(L, box_glue_stretch(n));
                            } else if (lua_key_eq(s, count)) {
                                lua_pushinteger(L, box_span_count(n));
                            } else if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct, box_list(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        /*
                        case attribute_list_node:
                            lua_pushnil(L);
                            break;
                        */
                        case boundary_node:
                            if (lua_key_eq(s, data) || lua_key_eq(s, value)) {
                                lua_pushinteger(L, boundary_data(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        case glue_spec_node:
                            if (lua_key_eq(s, width)) {
                                lua_pushinteger(L, glue_amount(n));
                            } else if (lua_key_eq(s, stretch)) {
                                lua_pushinteger(L, glue_stretch(n));
                            } else if (lua_key_eq(s, shrink)) {
                                lua_pushinteger(L, glue_shrink(n));
                            } else if (lua_key_eq(s, stretchorder)) {
                                lua_pushinteger(L, glue_stretch_order(n));
                            } else if (lua_key_eq(s, shrinkorder)) {
                                lua_pushinteger(L, glue_shrink_order(n));
                            } else {
                                lua_pushnil(L);
                            }
                            break;
                        default:
                            lua_pushnil(L);
                            break;
                    }
                }
                break;
            }
        default:
            {
                lua_pushnil(L);
                break;
            }
    }
    return 1;
}

static int nodelib_direct_getfield(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        return nodelib_common_getfield(L, 1, n);
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_userdata_index(lua_State *L)
{
    halfword n = *((halfword *) lua_touserdata(L, 1));
    if (n) {
        return nodelib_common_getfield(L, 0, n);
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int nodelib_userdata_getfield(lua_State *L)
{
    halfword n = lmt_maybe_isnode(L, 1);
    if (n) {
        return nodelib_common_getfield(L, 0, n);
    } else {
        lua_pushnil(L);
        return 1;
    }
}

/* node.setfield */
/* node.direct.setfield */

/*
    We used to check for glue_spec nodes in some places but if you do such a you have it coming
    anyway.
*/

static int nodelib_common_setfield(lua_State *L, int direct, halfword n)
{
    switch (lua_type(L, 2)) {
        case LUA_TNUMBER:
            {
                nodelib_setattribute_value(L, n, 2, 3);
                break;
            }
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L, 2);
                int t = node_type(n);
                if (lua_key_eq(s, next)) {
                    if (tex_nodetype_has_next(t)) {
                        node_next(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                    } else {
                        goto CANTSET;
                    }
                } else if (lua_key_eq(s, prev)) {
                    if (tex_nodetype_has_prev(t)) {
                        node_prev(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                    } else {
                        goto CANTSET;
                    }
                } else if (lua_key_eq(s, attr)) {
                    if (tex_nodetype_has_attributes(t)) {
                        tex_attach_attribute_list_attribute(n, nodelib_direct_or_node_from_index(L, direct, 3));
                    } else {
                        goto CANTSET;
                    }
                } else if (lua_key_eq(s, subtype)) {
                    if (tex_nodetype_has_subtype(t)) {
                        node_subtype(n) = lmt_toquarterword(L, 3);
                    } else {
                        goto CANTSET;
                    }
                } else {
                    switch(t) {
                        case glyph_node:
                            if (lua_key_eq(s, font)) {
                                glyph_font(n) = tex_checked_font(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, char)) {
                                glyph_character(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, xoffset)) {
                                glyph_x_offset(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, yoffset)) {
                                glyph_y_offset(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, scale)) {
                                 glyph_scale(n) = (halfword) lmt_roundnumber(L, 3);
                                 if (! glyph_scale(n)) {
                                     glyph_scale(n) = 1000;
                                 }
                            } else if (lua_key_eq(s, xscale)) {
                                 glyph_x_scale(n) = (halfword) lmt_roundnumber(L, 3);
                                 if (! glyph_x_scale(n)) {
                                     glyph_x_scale(n) = 1000;
                                 }
                            } else if (lua_key_eq(s, yscale)) {
                                 glyph_y_scale(n) = (halfword) lmt_roundnumber(L, 3);
                                 if (! glyph_y_scale(n)) {
                                     glyph_y_scale(n) = 1000;
                                 }
                            } else if (lua_key_eq(s, data)) {
                                glyph_data(n) = lmt_opthalfword(L, 3, unused_attribute_value);
                            } else if (lua_key_eq(s, expansion)) {
                                glyph_expansion(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, state)) {
                                set_glyph_state(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, script)) {
                                set_glyph_script(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, language)) {
                                set_glyph_language(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, left)) {
                                set_glyph_left(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, right)) {
                                set_glyph_right(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, lhmin)) {
                                set_glyph_lhmin(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, rhmin)) {
                                set_glyph_rhmin(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, uchyph)) {
                                set_glyph_uchyph(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, hyphenate)) {
                                set_glyph_hyphenate(n, lmt_tohalfword(L, 3));
                             } else if (lua_key_eq(s, options)) {
                                set_glyph_options(n, lmt_tohalfword(L, 3));
                             } else if (lua_key_eq(s, discpart)) {
                                set_glyph_discpart(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, protected)) {
                                glyph_protected(n) = lmt_tosingleword(L, 3);
                            } else if (lua_key_eq(s, width)) {
                                /* not yet */
                            } else if (lua_key_eq(s, height)) {
                                /* not yet */
                            } else if (lua_key_eq(s, depth)) {
                                /* not yet */
                            } else if (lua_key_eq(s, properties)) {
                                glyph_properties(n) = lmt_toquarterword(L, 3);
                            } else if (lua_key_eq(s, group)) {
                                glyph_group(n) = lmt_toquarterword(L, 3);
                            } else if (lua_key_eq(s, index)) {
                                glyph_index(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case hlist_node:
                        case vlist_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                box_list(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, width)) {
                                box_width(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, height)) {
                                box_height(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, depth)) {
                                box_depth(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, direction)) {
                                box_dir(n) = (singleword) nodelib_getdirection(L, 3);
                            } else if (lua_key_eq(s, shift)) {
                                box_shift_amount(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, glueorder)) {
                                box_glue_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, gluesign)) {
                                box_glue_sign(n) = tex_checked_glue_sign(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, glueset)) {
                                box_glue_set(n) = (glueratio) lua_tonumber(L, 3);  /* integer or float */
                            } else if (lua_key_eq(s, geometry)) {
                                box_geometry(n) = (singleword) lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, orientation)) {
                                box_orientation(n) = lmt_tohalfword(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, anchor)) {
                                box_anchor(n) = lmt_tohalfword(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, source)) {
                                box_source_anchor(n) = lmt_tohalfword(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, target)) {
                                box_target_anchor(n) = lmt_tohalfword(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, xoffset)) {
                                box_x_offset(n) = (halfword) lmt_roundnumber(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, yoffset)) {
                                box_y_offset(n) = (halfword) lmt_roundnumber(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, woffset)) {
                                box_w_offset(n) = (halfword) lmt_roundnumber(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, hoffset)) {
                                box_h_offset(n) = (halfword) lmt_roundnumber(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, doffset)) {
                                box_d_offset(n) = (halfword) lmt_roundnumber(L, 3);
                                tex_check_box_geometry(n);
                            } else if (lua_key_eq(s, pre)) {
                                box_pre_migrated(n) = nodelib_direct_or_node_from_index(L, direct, 3);;
                            } else if (lua_key_eq(s, post)) {
                                box_post_migrated(n) = nodelib_direct_or_node_from_index(L, direct, 3);;
                            } else if (lua_key_eq(s, state)) {
                                box_package_state(n) = (singleword) lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, index)) {
                                box_index(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case disc_node:
                            if (lua_key_eq(s, pre)) {
                                tex_set_disc_field(n, pre_break_code, nodelib_direct_or_node_from_index(L, direct, 3));
                            } else if (lua_key_eq(s, post)) {
                                tex_set_disc_field(n, post_break_code, nodelib_direct_or_node_from_index(L, direct, 3));
                            } else if (lua_key_eq(s, replace)) {
                                tex_set_disc_field(n, no_break_code, nodelib_direct_or_node_from_index(L, direct, 3));
                            } else if (lua_key_eq(s, penalty)) {
                                disc_penalty(n) = lmt_tohalfword(L, 3);
                             } else if (lua_key_eq(s, options)) {
                                disc_options(n) = lmt_tohalfword(L, 3);
                             } else if (lua_key_eq(s, class)) {
                                disc_class(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case glue_node:
                            if (lua_key_eq(s, width)) {
                                glue_amount(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, stretch)) {
                                glue_stretch(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, shrink)) {
                                glue_shrink(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, stretchorder)) {
                                glue_stretch_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, shrinkorder)) {
                                glue_shrink_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, leader)) {
                                glue_leader_ptr(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, font)) {
                                glue_font(n) = tex_checked_font(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, data)) {
                                glue_data(n) = (halfword) lmt_roundnumber(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case kern_node:
                            if (lua_key_eq(s, kern)) {
                                kern_amount(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, expansion)) {
                                kern_expansion(n) = (halfword) lmt_roundnumber(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case penalty_node:
                            if (lua_key_eq(s, penalty)) {
                                penalty_amount(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case rule_node:
                            if (lua_key_eq(s, width)) {
                                rule_width(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, height)) {
                                rule_height(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, depth)) {
                                rule_depth(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, xoffset)) {
                                rule_x_offset(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, yoffset)) {
                                rule_y_offset(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, left)) {
                                rule_left(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, right)) {
                                rule_right(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, data)) {
                                rule_data(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, font)) {
                                tex_set_rule_font(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, fam)) {
                                tex_set_rule_family(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, char)) {
                                rule_character(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case dir_node:
                            if (lua_key_eq(s, direction)) {
                                dir_direction(n) = nodelib_getdirection(L, 3);
                            } else if (lua_key_eq(s, level)) {
                                dir_level(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case whatsit_node:
                            return 0;
                        case par_node:
                            /* not all of them here */
                            if (lua_key_eq(s, interlinepenalty)) {
                                tex_set_local_interline_penalty(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, brokenpenalty)) {
                                tex_set_local_broken_penalty(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, direction)) {
                                par_dir(n) = nodelib_getdirection(L, 3);
                            } else if (lua_key_eq(s, leftbox)) {
                                par_box_left(n) = nodelib_getlist(L, 3);
                            } else if (lua_key_eq(s, leftboxwidth)) {
                                tex_set_local_left_width(n, lmt_roundnumber(L, 3));
                            } else if (lua_key_eq(s, rightbox)) {
                                par_box_right(n) = nodelib_getlist(L, 3);
                            } else if (lua_key_eq(s, rightboxwidth)) {
                                tex_set_local_right_width(n, lmt_roundnumber(L, 3));
                            } else if (lua_key_eq(s, middlebox)) {
                                par_box_middle(n) = nodelib_getlist(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case math_char_node:
                        case math_text_char_node:
                            if (lua_key_eq(s, fam)) {
                                kernel_math_family(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, char)) {
                                kernel_math_character(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, options)) {
                                kernel_math_options(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, properties)) {
                                kernel_math_properties(n) = lmt_toquarterword(L, 3);
                            } else if (lua_key_eq(s, group)) {
                                kernel_math_group(n) = lmt_toquarterword(L, 3);
                            } else if (lua_key_eq(s, index)) {
                                kernel_math_index(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case mark_node:
                            if (lua_key_eq(s, index) || lua_key_eq(s, class)) {
                                halfword m = lmt_tohalfword(L, 3);
                                if (tex_valid_mark(m)) {
                                    mark_index(n) = m;
                                }
                            } else if (lua_key_eq(s, data) || lua_key_eq(s, mark)) {
                                tex_delete_token_reference(mark_ptr(n));
                                mark_ptr(n) = lmt_token_list_from_lua(L, 3); /* check ref */
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case insert_node:
                            if (lua_key_eq(s, index)) {
                                halfword index = lmt_tohalfword(L, 3);
                                if (tex_valid_insert_id(index)) {
                                    insert_index(n) = index;
                                }
                            } else if (lua_key_eq(s, cost)) {
                                insert_float_cost(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, depth)) {
                                insert_max_depth(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, height) || lua_key_eq(s, total)) {
                                insert_total_height(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                insert_list(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case math_node:
                            if (lua_key_eq(s, surround)) {
                                math_surround(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, width)) {
                                math_amount(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, stretch)) {
                                math_stretch(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, shrink)) {
                                math_shrink(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, stretchorder)) {
                                math_stretch_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, shrinkorder)) {
                                math_shrink_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, penalty)) {
                                math_penalty(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case style_node:
                            if (lua_key_eq(s, style)) {
                                style_style(n) = (quarterword) lmt_get_math_style(L, 2, text_style);
                            } else {
                                /* return nodelib_cantset(L, n, s); */
                            }
                            return 0;
                        case parameter_node:
                            if (lua_key_eq(s, style)) {
                                parameter_style(n) = (quarterword) lmt_get_math_style(L, 2, text_style);
                            } else if (lua_key_eq(s, name)) {
                                parameter_name(n) = lmt_get_math_parameter(L, 2, parameter_name(n));
                            } else if (lua_key_eq(s, value)) {
                                halfword code = parameter_name(n);
                                if (code < 0 || code >= math_parameter_last) {
                                    /* error */
                                } else if (math_parameter_value_type(code)) {
                                    /* todo, see tex_setmathparm */
                                } else {
                                    parameter_value(n) = lmt_tohalfword(L, 3);
                                }
                            }
                            return 0;
                        case simple_noad:
                        case radical_noad:
                        case fraction_noad:
                        case accent_noad:
                        case fence_noad:
                            /* fence has less */
                            if (lua_key_eq(s, nucleus)) {
                                noad_nucleus(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, sub)) {
                                noad_subscr(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, sup)) {
                                noad_supscr(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, subpre)) {
                                noad_subprescr(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, suppre)) {
                                noad_supprescr(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, prime)) {
                                noad_prime(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, source)) {
                                noad_source(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, options)) {
                                noad_options(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, scriptorder)) {
                                noad_script_order(n) = lmt_tosingleword(L, 3);
                            } else if (lua_key_eq(s, class)) {
                                halfword c = lmt_tohalfword(L, 3);
                                set_noad_main_class(n, c);
                                set_noad_left_class(n, lmt_opthalfword(L, 4, c));
                                set_noad_right_class(n, lmt_opthalfword(L, 5, c));
                            } else if (lua_key_eq(s, fam)) {
                                set_noad_family(n, lmt_tohalfword(L, 3));
                            } else {
                                switch (t) {
                                    case simple_noad:
                                        break;
                                    case radical_noad:
                                        if (lua_key_eq(s, left) || lua_key_eq(s, delimiter)) {
                                            radical_left_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, right)) {
                                            radical_right_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, degree)) {
                                            radical_degree(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, width)) {
                                            noad_width(n) = lmt_roundnumber(L, 3);
                                        } else {
                                            goto CANTSET;
                                        }
                                        return 0;
                                    case fraction_noad:
                                        if (lua_key_eq(s, width)) {
                                            fraction_rule_thickness(n) = (halfword) lmt_roundnumber(L, 3);
                                        } else if (lua_key_eq(s, numerator)) {
                                            fraction_numerator(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, denominator)) {
                                            fraction_denominator(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, left)) {
                                            fraction_left_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, right)) {
                                            fraction_right_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, middle)) {
                                            fraction_middle_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else {
                                            goto CANTSET;
                                        }
                                        return 0;
                                    case accent_noad:
                                        if (lua_key_eq(s, top) || lua_key_eq(s, topaccent)) {
                                            accent_top_character(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, bottom) || lua_key_eq(s, bottomaccent)) {
                                            accent_bottom_character(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, middle) || lua_key_eq(s, overlayaccent)) {
                                            accent_middle_character(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, fraction)) {
                                            accent_fraction(n) = (halfword) lmt_roundnumber(L, 3);
                                        } else {
                                            goto CANTSET;
                                        }
                                        return 0;
                                    case fence_noad:
                                        if (lua_key_eq(s, delimiter)) {
                                            fence_delimiter_list(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, top)) {
                                            fence_delimiter_top(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, bottom)) {
                                            fence_delimiter_bottom(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, italic)) {
                                            noad_italic(n) = (halfword) lmt_roundnumber(L, 3);
                                        } else if (lua_key_eq(s, height)) {
                                            noad_height(n) = (halfword) lmt_roundnumber(L, 3);
                                        } else if (lua_key_eq(s, depth)) {
                                            noad_depth(n) = (halfword) lmt_roundnumber(L, 3);
                                        } else {
                                            goto CANTSET;
                                        }
                                        return 0;
                                    }
                            }
                            return 0;
                        case delimiter_node:
                            if (lua_key_eq(s, smallfamily)) {
                                delimiter_small_family(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, smallchar)) {
                                delimiter_small_character(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, largefamily)) {
                                delimiter_large_family(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, largechar)) {
                                delimiter_large_character(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case sub_box_node:
                        case sub_mlist_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                kernel_math_list(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case split_node: /* might go away */
                            if (lua_key_eq(s, index)) {
                                halfword index = lmt_tohalfword(L, 3);
                                if (tex_valid_insert_id(index)) {
                                    split_insert_index(n) = index;
                                }
                            } else if (lua_key_eq(s, lastinsert)) {
                                split_last_insert(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, bestinsert)) {
                                split_best_insert(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, broken)) {
                                split_broken(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, brokeninsert)) {
                                split_broken_insert(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case choice_node:
                            if (lua_key_eq(s, display)) {
                                choice_display_mlist(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, text)) {
                                choice_text_mlist(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, script)) {
                                choice_script_mlist(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, scriptscript)) {
                                choice_script_script_mlist(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case attribute_node:
                            switch (node_subtype(n)) {
                                case attribute_list_subtype:
                                    if (lua_key_eq(s, count)) {
                                        attribute_count(n) = lmt_tohalfword(L, 3);
                                    } else {
                                        goto CANTSET;
                                    }
                                    return 0;
                                case attribute_value_subtype:
                                    if (lua_key_eq(s, index) || lua_key_eq(s, number)) {
                                        attribute_index(n) = lmt_tohalfword(L, 3);
                                    } else if (lua_key_eq(s, value)) {
                                        attribute_value(n) = lmt_tohalfword(L, 3);
                                    } else {
                                        goto CANTSET;
                                    }
                                    return 0;
                                default:
                                    /* just ignored */
                                    return 0; 
                            }
                         // break;
                        case adjust_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                adjust_list(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else if (lua_key_eq(s, index)) {
                                halfword index = lmt_tohalfword(L, 3);
                                if (tex_valid_adjust_index(index)) {
                                    adjust_index(n) = index;
                                }
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case unset_node:
                            if (lua_key_eq(s, width)) {
                                box_width(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, height)) {
                                box_height(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, depth)) {
                                box_depth(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, direction)) {
                                box_dir(n) = (singleword) nodelib_getdirection(L, 3);
                            } else if (lua_key_eq(s, shrink)) {
                                box_glue_shrink(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, glueorder)) {
                                box_glue_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, gluesign)) {
                                box_glue_sign(n) = tex_checked_glue_sign(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, stretch)) {
                                box_glue_stretch(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, count)) {
                                box_span_count(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                box_list(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case boundary_node:
                            if (lua_key_eq(s, value)) {
                                boundary_data(n) = lmt_tohalfword(L, 3);
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        case glue_spec_node:
                            if (lua_key_eq(s, width)) {
                                glue_amount(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, stretch)) {
                                glue_stretch(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, shrink)) {
                                glue_shrink(n) = (halfword) lmt_roundnumber(L, 3);
                            } else if (lua_key_eq(s, stretchorder)) {
                                glue_stretch_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, shrinkorder)) {
                                glue_shrink_order(n) = tex_checked_glue_order(lmt_tohalfword(L, 3));
                            } else {
                                goto CANTSET;
                            }
                            return 0;
                        default:
                            return luaL_error(L, "you can't assign to a %s node (%d)\n", lmt_interface.node_data[t].name, n);
                    }
                  CANTSET:
                    return luaL_error(L,"you can't set field %s in a %s node (%d)", s, lmt_interface.node_data[t].name, n);
                }
                return 0;
            }
    }
    return 0;
}

static int nodelib_direct_setfield(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_common_setfield(L, 1, n);
    }
    return 0;
}

static int nodelib_userdata_newindex(lua_State *L)
{
    halfword n = *((halfword *) lua_touserdata(L, 1));
    if (n) {
        nodelib_common_setfield(L, 0, n);
    }
    return 0;
}

static int nodelib_userdata_setfield(lua_State *L)
{
    halfword n = lmt_maybe_isnode(L, 1);
    if (n) {
        nodelib_common_setfield(L, 0, n);
    }
    return 0;
}

/* tex serializing */

static int verbose = 1; /* This might become an option (then move this in a state)! */

static void nodelib_tostring(lua_State *L, halfword n, const char *tag)
{
    char msg[256];
    char a[7] = { ' ', ' ', ' ', 'n', 'i', 'l', 0 };
    char v[7] = { ' ', ' ', ' ', 'n', 'i', 'l', 0 };
    halfword t = node_type(n);
    halfword s = node_subtype(n);
    node_info nd = lmt_interface.node_data[t];
    if (tex_nodetype_has_prev(t) && node_prev(n)) {
        snprintf(a, 7, "%6d", (int) node_prev(n));
    }
    if (node_next(n)) {
        snprintf(v, 7, "%6d", (int) node_next(n));
    }
    if (t == whatsit_node) {
        snprintf(msg, 255, "<%s : %s < %6d > %s : %s %d>", tag, a, (int) n, v, nd.name, s);
    } else if (! tex_nodetype_has_subtype(n)) {
        snprintf(msg, 255, "<%s : %s < %6d > %s : %s>", tag, a, (int) n, v, nd.name);
    } else if (verbose) {
        /*tex Sloooow! But subtype lists can have holes. */
        value_info *sd = nd.subtypes;
        int j = -1;
        if (sd) {
         // if (t == glyph_node) {
         //     s = tex_subtype_of_glyph(n);
         // }
            if (s >= nd.first && s <= nd.last) {
                for (int i = 0; ; i++) {
                    if (sd[i].id == s) {
                        j = i;
                        break ;
                    } else if (sd[i].id < 0) {
                        break;
                    }
                }
            }
        }
        if (j < 0) {
            snprintf(msg, 255, "<%s : %s <= %6d => %s : %s %d>", tag, a, (int) n, v, nd.name, s);
        } else {
            snprintf(msg, 255, "<%s : %s <= %6d => %s : %s %s>", tag, a, (int) n, v, nd.name, sd[j].name);
        }
    } else {
        snprintf(msg, 255, "<%s : %s < %6d > %s : %s %d>", tag, a, (int) n, v, nd.name, s);
    }
    lua_pushstring(L, (const char *) msg);
}

/* __tostring node.tostring */

static int nodelib_userdata_tostring(lua_State *L)
{
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        nodelib_tostring(L, n, lua_key(node));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.tostring */

static int nodelib_direct_tostring(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_tostring(L, n, lua_key(direct));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* __eq */

static int nodelib_userdata_equal(lua_State *L)
{
    halfword n = *((halfword *) lua_touserdata(L, 1));
    halfword m = *((halfword *) lua_touserdata(L, 2));
    lua_pushboolean(L, (n == m));
    return 1;
}

/* node.ligaturing */

static int nodelib_direct_ligaturing(lua_State *L)
{
    if (lua_gettop(L) >= 1) {
        halfword h = nodelib_valid_direct_from_index(L, 1);
        halfword t = nodelib_valid_direct_from_index(L, 2);
        if (h) {
            halfword tmp_head = tex_new_node(nesting_node, unset_nesting_code);
            halfword p = node_prev(h);
            tex_couple_nodes(tmp_head, h);
            node_tail(tmp_head) = t;
            t = tex_handle_ligaturing(tmp_head, t);
            if (p) {
                node_next(p) = node_next(tmp_head) ;
            }
            node_prev(node_next(tmp_head)) = p ;
            lua_pushinteger(L, node_next(tmp_head));
            lua_pushinteger(L, t);
            lua_pushboolean(L, 1);
            tex_flush_node(tmp_head);
            return 3;
        }
    }
    lua_pushnil(L);
    lua_pushboolean(L, 0);
    return 2;
}

/* node.kerning */

static int nodelib_direct_kerning(lua_State *L)
{
    if (lua_gettop(L) >= 1) {
        halfword h = nodelib_valid_direct_from_index(L, 1);
        halfword t = nodelib_valid_direct_from_index(L, 2);
        if (h) {
            halfword tmp_head = tex_new_node(nesting_node, unset_nesting_code);
            halfword p = node_prev(h);
            tex_couple_nodes(tmp_head, h);
            node_tail(tmp_head) = t;
            t = tex_handle_kerning(tmp_head, t);
            if (p) {
                node_next(p) = node_next(tmp_head) ;
            }
            node_prev(node_next(tmp_head)) = p ;
            lua_pushinteger(L, node_next(tmp_head));
            if (t) {
                lua_pushinteger(L, t);
            } else {
                lua_pushnil(L);
            }
            lua_pushboolean(L, 1);
            tex_flush_node(tmp_head);
            return 3;
        }
    }
    lua_pushnil(L);
    lua_pushboolean(L, 0);
    return 2;
}

/*tex
    It's more consistent to have it here (so we will alias in lang later). Todo: if no glyph then
    quit.
*/

static int nodelib_direct_hyphenating(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    halfword t = nodelib_valid_direct_from_index(L, 2);
    if (h) {
        if (! t) {
            t = h;
            while (node_next(t)) {
                t = node_next(t);
            }
        }
        tex_hyphenate_list(h, t); /* todo: grab new tail */
    } else {
        /*tex We could consider setting |h| and |t| to |null|. */
    }
    lua_pushinteger(L, h);
    lua_pushinteger(L, t);
    lua_pushboolean(L, 1);
    return 3;
}

static int nodelib_direct_collapsing(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    if (h) {
        halfword c1 = lmt_optinteger(L, 2, ex_hyphen_char_par);
        halfword c2 = lmt_optinteger(L, 3, 0x2013);
        halfword c3 = lmt_optinteger(L, 4, 0x2014);
        tex_collapse_list(h, c1, c2, c3);
    }
    lua_pushinteger(L, h);
    return 1;
}

/* node.protect_glyphs */
/* node.unprotect_glyphs */

inline static void nodelib_aux_protect_all(halfword h)
{
    while (h) {
        if (node_type(h) == glyph_node) {
            glyph_protected(h) = glyph_protected_text_code;
        }
        h = node_next(h);
    }
}
inline static void nodelib_aux_unprotect_all(halfword h)
{
    while (h) {
        if (node_type(h) == glyph_node) {
            glyph_protected(h) = glyph_unprotected_code;
        }
        h = node_next(h);
    }
}

inline static void nodelib_aux_protect_node(halfword n)
{
    switch (node_type(n)) {
        case glyph_node:
            glyph_protected(n) = glyph_protected_text_code;
            break;
        case disc_node:
            nodelib_aux_protect_all(disc_no_break_head(n));
            nodelib_aux_protect_all(disc_pre_break_head(n));
            nodelib_aux_protect_all(disc_post_break_head(n));
            break;
    }
}

inline static void nodelib_aux_unprotect_node(halfword n)
{
    switch (node_type(n)) {
        case glyph_node:
            glyph_protected(n) = glyph_unprotected_code;
            break;
        case disc_node:
            nodelib_aux_unprotect_all(disc_no_break_head(n));
            nodelib_aux_unprotect_all(disc_pre_break_head(n));
            nodelib_aux_unprotect_all(disc_post_break_head(n));
            break;
    }
}

/* node.direct.protect_glyphs */
/* node.direct.unprotect_glyphs */

static int nodelib_direct_protectglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_aux_protect_node(n);
    }
    return 0;
}

static int nodelib_direct_unprotectglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_aux_unprotect_node(n);
    }
    return 0;
}

static int nodelib_direct_protectglyphs(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    halfword tail = nodelib_valid_direct_from_index(L, 2);
    if (head) {
        while (head) {
            nodelib_aux_protect_node(head);
            if (head == tail) {
                break;
            } else {
                head = node_next(head);
            }
        }
    }
    return 0;
}

static int nodelib_direct_unprotectglyphs(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    halfword tail = nodelib_valid_direct_from_index(L, 2);
    if (head) {
        while (head) {
            nodelib_aux_unprotect_node(head);
            if (head == tail) {
                break;
            } else {
                head = node_next(head);
            }
        }
    }
    return 0;
}

/*tex This is an experiment. */

inline static void nodelib_aux_protect_all_none(halfword h)
{
    while (h) {
        if (node_type(h) == glyph_node) {
            halfword f =  glyph_font(h);
            if (f >= 0 && f <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[f] && has_font_text_control(f, text_control_none_protected)) { 
                glyph_protected(h) = glyph_protected_text_code;
            }
        }
        h = node_next(h);
    }
}

inline static void nodelib_aux_protect_node_none(halfword n)
{
    switch (node_type(n)) {
        case glyph_node:
            {
                halfword f =  glyph_font(n);
                if (f >= 0 && f <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[f] && has_font_text_control(f, text_control_none_protected)) { 
                    glyph_protected(n) = glyph_protected_text_code;
                }
            }
            break;
        case disc_node:
            nodelib_aux_protect_all_none(disc_no_break_head(n));
            nodelib_aux_protect_all_none(disc_pre_break_head(n));
            nodelib_aux_protect_all_none(disc_post_break_head(n));
            break;
    }
}

static int nodelib_direct_protectglyphs_none(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    halfword tail = nodelib_valid_direct_from_index(L, 2);
    if (head) {
        while (head) {
            nodelib_aux_protect_node_none(head);
            if (head == tail) {
                break;
            } else {
                head = node_next(head);
            }
        }
    }
    return 0;
}

/* node.direct.first_glyph */

static int nodelib_direct_firstglyph(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    halfword t = nodelib_valid_direct_from_index(L, 2);
    if (h) {
        halfword savetail = null;
        if (t) {
            savetail = node_next(t);
            node_next(t) = null;
        }
        /*tex
            We go to the first unprocessed character so that is one with a value <= 0xFF and we
            don't care about what the value is.
        */
        while (h && (node_type(h) != glyph_node || glyph_protected(h))) {
            h = node_next(h);
        }
        if (savetail) {
            node_next(t) = savetail;
        }
        lua_pushinteger(L, h);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.find_node(head)         : node, subtype*/
/* node.direct.find_node(head,subtype) : node */

static int nodelib_direct_findnode(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    if (h) {
        halfword t = lmt_tohalfword(L, 2);
        if (lua_gettop(L) > 2) {
            halfword s = lmt_tohalfword(L, 3);
            while (h) {
                if (node_type(h) == t && node_subtype(h) == s) {
                    lua_pushinteger(L, h);
                    return 1;
                } else {
                    h = node_next(h);
                }
            }
        } else {
            while (h) {
                if (node_type(h) == t) {
                    lua_pushinteger(L, h);
                    lua_pushinteger(L, node_subtype(h));
                    return 2;
                } else {
                    h = node_next(h);
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

/* node.direct.has_glyph */

static int nodelib_direct_hasglyph(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    while (h) {
        switch (node_type(h)) {
            case glyph_node:
            case disc_node:
                nodelib_push_direct_or_nil(L, h);
                return 1;
            default:
                h = node_next(h);
                break;
        }
    }
    lua_pushnil(L);
    return 1;
}

/* node.getword */

inline static int nodelib_aux_in_word(halfword n)
{
    switch (node_type(n)) {
        case glyph_node:
        case disc_node:
            return 1;
        case kern_node:
            return node_subtype(n) == font_kern_subtype;
        default:
            return 0;
    }
}

static int nodelib_direct_getwordrange(lua_State *L)
{
    halfword m = nodelib_valid_direct_from_index(L, 1);
    if (m) {
        /*tex We don't check on type if |m|. */
        halfword l = m;
        halfword r = m;
        while (node_prev(l) && nodelib_aux_in_word(node_prev(l))) {
            l = node_prev(l);
        }
        while (node_next(r) && nodelib_aux_in_word(node_next(r))) {
            r = node_next(r);
        }
        nodelib_push_direct_or_nil(L, l);
        nodelib_push_direct_or_nil(L, r);
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

/* node.inuse */

static int nodelib_userdata_inuse(lua_State *L)
{
    int counts[max_node_type + 1] = { 0 };
    int n = tex_n_of_used_nodes(&counts[0]);
    lua_createtable(L, 0, max_node_type);
    for (int i = 0; i < max_node_type; i++) {
        if (counts[i]) {
            lua_pushstring(L, lmt_interface.node_data[i].name);
            lua_pushinteger(L, counts[i]);
            lua_rawset(L, -3);
        }
    }
    lua_pushinteger(L, n);
    return 2;
}

/*tex A bit of a cheat: some nodes can turn into another one due to the same size. */

static int nodelib_userdata_instock(lua_State *L)
{
    int counts[max_node_type + 1] = { 0 };
    int n = 0;
    lua_createtable(L, 0, max_node_type);
    for (int i = 1; i < max_chain_size; i++) {
        halfword p = lmt_node_memory_state.free_chain[i];
        while (p) {
            if (node_type(p) <= max_node_type) {
                 ++counts[node_type(p)];
            }
            p = node_next(p);
        }
    }
    for (int i = 0; i < max_node_type; i++) {
        if (counts[i]) {
            lua_pushstring(L, lmt_interface.node_data[i].name);
            lua_pushinteger(L, counts[i]);
            lua_rawset(L, -3);
            n += counts[i];
        }
    }
    lua_pushinteger(L, n);
    return 2;
}


/* node.usedlist */

static int nodelib_userdata_usedlist(lua_State *L)
{
    lmt_push_node_fast(L, tex_list_node_mem_usage());
    return 1;
}

/* node.direct.usedlist */

static int nodelib_direct_usedlist(lua_State *L)
{
    lua_pushinteger(L, tex_list_node_mem_usage());
    return 1;
}

/* node.direct.protrusionskipable(node m) */

static int nodelib_direct_protrusionskipable(lua_State *L)
{
    halfword n = lmt_tohalfword(L, 1);
    if (n) {
        lua_pushboolean(L, tex_protrusion_skipable(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.currentattributes(node m) */

static int nodelib_userdata_currentattributes(lua_State* L)
{
    halfword n = tex_current_attribute_list();
    if (n) {
        lmt_push_node_fast(L, n);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.currentattributes(node m) */

static int nodelib_direct_currentattributes(lua_State* L)
{
    halfword n = tex_current_attribute_list();
    if (n) {
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.todirect */

static int nodelib_direct_todirect(lua_State* L)
{
    if (lua_type(L, 1) != LUA_TNUMBER) {
        /* assume node, no further testing, used in known situations */
        void* n = lua_touserdata(L, 1);
        if (n) {
            lua_pushinteger(L, *((halfword*)n));
        }
        else {
            lua_pushnil(L);
        }
    } /* else assume direct and returns argument */
    return 1;
}

static int nodelib_direct_tovaliddirect(lua_State* L)
{
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.tonode */

static int nodelib_direct_tonode(lua_State* L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword* a = (halfword*) lua_newuserdatauv(L, sizeof(halfword), 0);
        *a = n;
        lua_get_metatablelua(node_instance);
        lua_setmetatable(L, -2);
    } /* else assume node and return argument */
    return 1;
}

/* direct.ischar  */
/* direct.isglyph */

/*tex

    This can save a lookup call, but although there is a little benefit it doesn't pay of in the end
    as we have to simulate it in \MKIV.

    \starttyping
    if (glyph_data(n) != unused_attribute_value) {
        lua_pushinteger(L, glyph_data(n));
        return 2;
    }
    \stoptyping

    possible return values:

    \starttyping
    <nil when no node>
    <nil when no glyph> <id of node>
    <false when glyph and already marked as done or when not>
    <character code when font matches or when no font passed>
    \stoptyping

    data  : when checked should be equal, false or nil is zero
    state : when checked should be equal, unless false or zero

*/

static int nodelib_direct_check_char(lua_State* L, halfword n)
{
    if (! glyph_protected(n)) {
        halfword b = 0;
        halfword f = (halfword) lua_tointegerx(L, 2, &b);
        if (! b) {
            goto OKAY;
        } else if (f == glyph_font(n)) {
            switch (lua_gettop(L)) {
                case 2:
                    /* (node,font) */
                    goto OKAY;
                case 3:
                    /* (node,font,data) */
                    if ((halfword) lua_tointegerx(L, 3, NULL) == glyph_data(n)) {
                        goto OKAY;
                    } else {
                        break;
                    }
                case 4:
                    /* (node,font,data,state) */
                    if ((halfword) lua_tointegerx(L, 3, NULL) == glyph_data(n)) {
                        halfword state = (halfword) lua_tointegerx(L, 4, NULL);
                        if (! state || state == glyph_state(n)) {
                            goto OKAY;
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                case 5:
                    /* (node,font,data,scale,xscale,yscale) */
                    if (lua_tointeger(L, 3) == glyph_scale(n) &&  lua_tointeger(L, 4) == glyph_x_scale(n) && lua_tointeger(L, 5) == glyph_y_scale(n)) {
                        goto OKAY;
                    } else {
                        break;
                    }
                case 6:
                    /* (node,font,data,scale,xscale,yscale) */
                    if (lua_tointegerx(L, 3, NULL) == glyph_data(n) && lua_tointeger(L, 4) == glyph_scale(n) &&  lua_tointeger(L, 5) == glyph_x_scale(n) && lua_tointeger(L, 6) == glyph_y_scale(n)) {
                        goto OKAY;
                    } else {
                        break;
                    }
                /* case 7: */
                    /* (node,font,data,scale,scale,xscale,yscale)*/
            }
        }
    }
    return -1;
  OKAY:
    return glyph_character(n);
}

static int nodelib_direct_ischar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        if (node_type(n) != glyph_node) {
            lua_pushnil(L);
            lua_pushinteger(L, node_type(n));
            return 2;
        } else {
            halfword chr = nodelib_direct_check_char(L, n);
            if (chr >= 0) {
                lua_pushinteger(L, chr);
            } else {
                lua_pushboolean(L, 0);
            }
            return 1;
        }
    } else {
        lua_pushnil(L);
        return 1;
    }
}

/*
    This one is kind of special and is a way to quickly test what we are at now and what is
    coming. It saves some extra calls but has a rather hybrid set of return values, depending
    on the situation:

    \starttyping
    isnextchar(n,[font],[data],[state],[scale,xscale,yscale])
    isprevchar(n,[font],[data],[state],[scale,xscale,yscale])

    glyph     : nil | next false | next char | next char nextchar
    otherwise : nil | next false id
    \stoptyping

    Beware: it is not always measurable faster than multiple calls but it can make code look a
    bit better (at least in \CONTEXT\ where we can use it a few times). There are more such
    hybrid helpers where the return value depends on the node type.

    The second glyph is okay when the most meaningful properties are the same. We assume that
    states can differ so we don't check for that. One of the few assumptions when using
    \CONTEXT.

*/

inline static int nodelib_aux_similar_glyph(halfword first, halfword second)
{
    return
        node_type(second)     == glyph_node
     && glyph_font(second)    == glyph_font(first)
     && glyph_data(second)    == glyph_data(first)
  /* && glyph_state(second)   == glyph_state(first) */
     && glyph_scale(second)   == glyph_scale(first)
     && glyph_x_scale(second) == glyph_x_scale(first)
     && glyph_y_scale(second) == glyph_y_scale(first)
    ;
}

static int nodelib_direct_isnextchar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        /* beware, don't mix push and pop */
        halfword nxt = node_next(n);
        if (node_type(n) != glyph_node) {
            nodelib_push_direct_or_nil(L, nxt);
            lua_pushnil(L);
            lua_pushinteger(L, node_type(n));
            return 3;
        } else {
            halfword chr = nodelib_direct_check_char(L, n);
            nodelib_push_direct_or_nil(L, nxt);
            if (chr >= 0) {
                lua_pushinteger(L, chr);
                if (nxt && nodelib_aux_similar_glyph(n, nxt)) {
                    lua_pushinteger(L, glyph_character(nxt));
                    return 3;
                }
            } else {
                lua_pushboolean(L, 0);
            }
            return 2;
        }
    } else {
        return 0;
    }
}

static int nodelib_direct_isprevchar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        /* beware, don't mix push and pop */
        halfword prv = node_prev(n);
        if (node_type(n) != glyph_node) {
            nodelib_push_direct_or_nil(L, prv);
            lua_pushnil(L);
            lua_pushinteger(L, node_type(n));
            return 3;
        } else {
            halfword chr = nodelib_direct_check_char(L, n);
            nodelib_push_direct_or_nil(L, prv);
            if (chr >= 0) {
                lua_pushinteger(L, chr);
                if (prv && nodelib_aux_similar_glyph(n, prv)) {
                    lua_pushinteger(L, glyph_character(prv));
                    return 3;
                }
            } else {
                lua_pushboolean(L, 0);
            }
            return 2;
        }
    } else {
        return 0;
    }
}

static int nodelib_direct_isglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        if (node_type(n) != glyph_node) {
            lua_pushboolean(L, 0);
            lua_pushinteger(L, node_type(n));
        } else {
            /* protected as well as unprotected */
            lua_pushinteger(L, glyph_character(n));
            lua_pushinteger(L, glyph_font(n));
        }
    } else {
        lua_pushnil(L); /* no glyph at all */
        lua_pushnil(L); /* no glyph at all */
    }
    return 2;
}

static int nodelib_direct_isnextglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_push_direct_or_nil(L, node_next(n));
        if (node_type(n) != glyph_node) {
            lua_pushboolean(L, 0);
            lua_pushinteger(L, node_type(n));
        } else {
            /* protected as well as unprotected */
            lua_pushinteger(L, glyph_character(n));
            lua_pushinteger(L, glyph_font(n));
        }
        return 3;
    } else {
        return 0;
    }
}

static int nodelib_direct_isprevglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        nodelib_push_direct_or_nil(L, node_prev(n));
        if (node_type(n) != glyph_node) {
            lua_pushboolean(L, 0);
            lua_pushinteger(L, node_type(n));
        } else {
            /* protected as well as unprotected */
            lua_pushinteger(L, glyph_character(n));
            lua_pushinteger(L, glyph_font(n));
        }
        return 3;
    } else {
        return 0;
    }
}


/* direct.usesfont */

inline static int nodelib_aux_uses_font_disc(lua_State *L, halfword n, halfword font)
{
    while (n) {
        if ((node_type(n) == glyph_node) && (glyph_font(n) == font)) {
            lua_pushboolean(L, 1);
            return 1;
        }
        n = node_next(n);
    }
    return 0;
}

static int nodelib_direct_usesfont(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword f = lmt_tohalfword(L, 2);
        switch (node_type(n)) {
            case glyph_node:
                lua_pushboolean(L, glyph_font(n) == f);
                return 1;
            case disc_node:
                if (nodelib_aux_uses_font_disc(L, disc_pre_break_head(n), f)) {
                    return 1;
                } else if (nodelib_aux_uses_font_disc(L, disc_post_break_head(n), f)) {
                    return 1;
                } else if (nodelib_aux_uses_font_disc(L, disc_no_break_head(n), f)) {
                    return 1;
                }
                /*
                {
                    halfword c = disc_pre_break_head(n);
                    while (c) {
                        if (type(c) == glyph_node && font(c) == f) {
                            lua_pushboolean(L, 1);
                            return 1;
                        }
                        c = node_next(c);
                    }
                    c = disc_post_break_head(n);
                    while (c) {
                        if (type(c) == glyph_node && font(c) == f) {
                            lua_pushboolean(L, 1);
                            return 1;
                        }
                        c = node_next(c);
                    }
                    c = disc_no_break_head(n);
                    while (c) {
                        if (type(c) == glyph_node && font(c) == f) {
                            lua_pushboolean(L, 1);
                            return 1;
                        }
                        c = node_next(c);
                    }
                }
                */
                break;
            /* todo: other node types */
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

/* boxes */

/* node.getbox = tex.getbox */
/* node.setbox = tex.setbox */

/* node.direct.getbox */
/* node.direct.setbox */

static int nodelib_direct_getbox(lua_State *L)
{
    int id = lmt_get_box_id(L, 1, 1);
    if (id >= 0) {
        int t = tex_get_tex_box_register(id, 0);
        if (t) {
            lua_pushinteger(L, t);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_setbox(lua_State *L)
{
    int flags = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int id = lmt_get_box_id(L, slot++, 1);
    if (id >= 0) {
        int n;
        switch (lua_type(L, slot)) {
            case LUA_TBOOLEAN:
                {
                    n = lua_toboolean(L, slot);
                    if (n == 0) {
                        n = null;
                    } else {
                        return 0;
                    }
                }
                break;
            case LUA_TNIL:
                n = null;
                break;
            default:
                {
                    n = nodelib_valid_direct_from_index(L, slot);
                    if (n) {
                        switch (node_type(n)) {
                            case hlist_node:
                            case vlist_node:
                                break;
                            default:
                                /*tex Alternatively we could |hpack|. */
                                return luaL_error(L, "setbox: incompatible node type (%s)\n",get_node_name(node_type(n)));
                        }
                    }
                }
                break;
        }
        tex_set_tex_box_register(id, n, flags, 0);
    }
    return 0;
}

/* node.isnode(n) */

static int nodelib_userdata_isnode(lua_State *L)
{
    halfword n = lmt_maybe_isnode(L, 1);
    if (n) {
        lua_pushinteger (L, n);
    } else {
        lua_pushboolean (L, 0);
    }
    return 1;
}

/* node.direct.isdirect(n) (handy for mixed usage testing) */

static int nodelib_direct_isdirect(lua_State *L)
{
    if (lua_type(L, 1) != LUA_TNUMBER) {
        lua_pushboolean(L, 0); /* maybe valid test too */
    }
    /* else return direct */
    return 1;
}

/* node.direct.isnode(n) (handy for mixed usage testing) */

static int nodelib_direct_isnode(lua_State *L)
{
    if (! lmt_maybe_isnode(L, 1)) {
        lua_pushboolean(L, 0);
    } else {
        /*tex Assume and return node. */
    }
    return 1;
}

/*tex Maybe we should allocate a proper index |0 .. var_mem_max| but not now. */

static int nodelib_userdata_getproperty(lua_State *L)
{   /* <node> */
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        lua_rawgeti(L, -1, n); /* actually it is a hash */
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_getproperty(lua_State *L)
{   /* <direct> */
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        lua_rawgeti(L, -1, n); /* actually it is a hash */
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_userdata_setproperty(lua_State *L)
{
    /* <node> <value> */
    halfword n = lmt_check_isnode(L, 1);
    if (n) {
        lua_settop(L, 2);
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        /* <node> <value> <propertytable> */
        lua_replace(L, -3);
        /* <propertytable> <value> */
        lua_rawseti(L, -2, n); /* actually it is a hash */
    }
    return 0;
}

static int nodelib_direct_setproperty(lua_State *L)
{
    /* <direct> <value> */
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        lua_settop(L, 2);
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        /* <node> <value> <propertytable> */
        lua_replace(L, 1);
        /* <propertytable> <value> */
        lua_rawseti(L, 1, n); /* actually it is a hash */
    }
    return 0;
}

/*tex

    These two getters are kind of tricky as they can mess up the otherwise hidden table. But
    normally these are under control of the macro package so we can control it somewhat.

*/

static int nodelib_direct_getpropertiestable(lua_State *L)
{   /* <node|direct> */
    if (lua_toboolean(L, lua_gettop(L))) {
        /*tex Beware: this can have side effects when used without care. */
        lmt_initialize_properties(1);
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
    return 1;
}

static int nodelib_userdata_getpropertiestable(lua_State *L)
{   /* <node|direct> */
    lua_get_metatablelua(node_properties_indirect);
    return 1;
}

/* extra helpers */

static void nodelib_direct_effect_done(lua_State *L, halfword amount, halfword stretch, halfword shrink, halfword stretch_order, halfword shrink_order)
{
    halfword parent = nodelib_valid_direct_from_index(L, 2);
    if (parent) {
        halfword sign = box_glue_sign(parent);
        if (sign != normal_glue_sign) { 
            switch (node_type(parent)) {
                case hlist_node:
                case vlist_node:
                    {
                        double w = (double) amount;
                        switch (sign) {
                            case stretching_glue_sign:
                                if (stretch_order == box_glue_order(parent)) {
                                    w += stretch * (double) box_glue_set(parent);
                                }
                                break;
                            case shrinking_glue_sign:
                                if (shrink_order == box_glue_order(parent)) {
                                    w -= shrink * (double) box_glue_set(parent);
                                }
                                break;
                        }
                        if (lua_toboolean(L, 3)) {
                            lua_pushinteger(L, lmt_roundedfloat(w));
                        } else {
                            lua_pushnumber(L, w);
                        }
                        return;
                    }
            }
        }
    }
    lua_pushinteger(L, amount);
}

static int nodelib_direct_effectiveglue(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glue_node:
                nodelib_direct_effect_done(L, glue_amount(n), glue_stretch(n), glue_shrink(n),glue_stretch_order(n), glue_shrink_order(n));
                break;
            case math_node:
                if (math_surround(n)) {
                    lua_pushinteger(L, math_surround(n));
                } else {
                    nodelib_direct_effect_done(L, math_amount(n), math_stretch(n), math_shrink(n), math_stretch_order(n), math_shrink_order(n));
                }
                break;
            default:
                lua_pushinteger(L, 0);
                break;
        }
    } else {
        lua_pushinteger(L, 0);
    }
    return 1;
}

/*tex

    Disc nodes are kind of special in the sense that their head is not the head as we see it, but
    a special node that has status info of which head and tail are part. Normally when proper
    set/get functions are used this status node is all right but if a macro package permits
    arbitrary messing around, then it can at some point call the following cleaner, just before
    linebreaking kicks in. This one is not called automatically because if significantly slows down
    the line break routing.

*/

static int nodelib_direct_checkdiscretionaries(lua_State *L) {
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        while (n) {
            if (node_type(n) == disc_node) {
                tex_check_disc_field(n);
            }
            n = node_next(n) ;
        }
    }
    return 0;
}

static int nodelib_direct_checkdiscretionary(lua_State *L) {
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == disc_node) {
        halfword p = disc_pre_break_head(n);
        disc_pre_break_tail(n) = p ? tex_tail_of_node_list(p) : null;
        p = disc_post_break_head(n);
        disc_post_break_tail(n) = p ? tex_tail_of_node_list(p) : null;
        p = disc_no_break_head(n);
        disc_no_break_tail(n) = p ? tex_tail_of_node_list(p) : null;
    }
    return 0;
}

static int nodelib_direct_flattendiscretionaries(lua_State *L)
{
    int count = 0;
    halfword head = nodelib_valid_direct_from_index(L, 1);
    if (head) {
        head = tex_flatten_discretionaries(head, &count, lua_toboolean(L, 2)); /* nest */
    } else {
        head = null;
    }
    nodelib_push_direct_or_nil(L, head);
    lua_pushinteger(L, count);
    return 2;
}

static int nodelib_direct_softenhyphens(lua_State *L)
{
    int found = 0;
    int replaced = 0;
    halfword head = nodelib_valid_direct_from_index(L, 1);
    if (head) {
        tex_soften_hyphens(head, &found, &replaced);
    }
    nodelib_push_direct_or_nil(L, head);
    lua_pushinteger(L, found);
    lua_pushinteger(L, replaced);
    return 3;
}

/*tex The fields related to input tracking: */

static int nodelib_direct_setinputfields(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        /* there is no need to test for tag and line as two arguments are mandate */
        halfword tag = lmt_tohalfword(L, 2);
        halfword line = lmt_tohalfword(L, 3);
        switch (node_type(n)) {
            case glyph_node:
                glyph_input_file(n)  = tag;
                glyph_input_line(n) = line;
                break;
            case hlist_node:
            case vlist_node:
            case unset_node:
                box_input_file(n)  = tag;
                box_input_line(n) = line;
                break;
        }
    }
    return 0;
}

static int nodelib_direct_getinputfields(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_input_file(n));
                lua_pushinteger(L, glyph_input_line(n));
                break;
            case hlist_node:
            case vlist_node:
            case unset_node:
                lua_pushinteger(L, box_input_file(n));
                lua_pushinteger(L, box_input_line(n));
                break;
            default:
                return 0;
        }
        return 2;
    }
    return 0;
}

static int nodelib_direct_makeextensible(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 3) {
        halfword fnt = lmt_tohalfword(L, 1);
        halfword chr = lmt_tohalfword(L, 2);
        halfword target = lmt_tohalfword(L, 3);
        halfword size = lmt_opthalfword(L, 4, 0);
        halfword overlap = lmt_opthalfword(L, 5, 65536);
        halfword attlist = null;
        halfword b = null;
        int horizontal = 0;
        if (top >= 4) {
            overlap = lmt_tohalfword(L, 4);
            if (top >= 5) {
                horizontal = lua_toboolean(L, 5);
                if (top >= 6) {
                    attlist = nodelib_valid_direct_from_index(L, 6);
                }
            }
        }
        b = tex_make_extensible(fnt, chr, target, overlap, horizontal, attlist, size);
        lua_pushinteger(L, b);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex experiment */

static int nodelib_direct_flattenleaders(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    int count = 0;
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                tex_flatten_leaders(n, &count);
                break;
        }
    }
    lua_pushinteger(L, count);
    return 1;
}

/*tex test */

static int nodelib_direct_isvalid(lua_State *L)
{
    lua_pushboolean(L, nodelib_valid_direct_from_index(L, 1));
    return 1;
}

/* getlinestuff : LS RS LH RH ID PF FIRST LAST */

inline static halfword set_effective_width(halfword source, halfword sign, halfword order, double glue)
{
    halfword amount = glue_amount(source);
    switch (sign) {
        case stretching_glue_sign:
            if (glue_stretch_order(source) == order) {
                return amount + scaledround((double) glue_stretch(source) * glue);
            } else {
                break;
            }
        case shrinking_glue_sign:
            if (glue_shrink_order(source) == order) {
                return amount + scaledround((double) glue_shrink(source) * glue);
            } else {
                break;
            }
    }
    return amount;
}

static int nodelib_direct_getnormalizedline(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == hlist_node && node_subtype(n) == line_list) {
        halfword head = box_list(n);
        halfword tail = head;
        halfword first = head;
        halfword last = tail;
        halfword current = head;
        halfword ls = 0;
        halfword rs = 0;
        halfword is = 0;
        halfword pr = 0;
        halfword pl = 0;
        halfword ir = 0;
        halfword il = 0;
        halfword lh = 0;
        halfword rh = 0;
        halfword sign = box_glue_sign(n);
        halfword order = box_glue_order(n);
        double glue = box_glue_set(n);
        while (current) {
            tail = current ;
            if (node_type(current) == glue_node) {
                switch (node_subtype(current)) {
                    case left_skip_glue           : ls = set_effective_width(current, sign, order, glue); break;
                    case right_skip_glue          : rs = set_effective_width(current, sign, order, glue); break;
                    case par_fill_left_skip_glue  : pl = set_effective_width(current, sign, order, glue); break;
                    case par_fill_right_skip_glue : pr = set_effective_width(current, sign, order, glue); break;
                    case par_init_left_skip_glue  : il = set_effective_width(current, sign, order, glue); break;
                    case par_init_right_skip_glue : ir = set_effective_width(current, sign, order, glue); break;
                    case indent_skip_glue         : is = set_effective_width(current, sign, order, glue); break;
                    case left_hang_skip_glue      : lh = set_effective_width(current, sign, order, glue); break;
                    case right_hang_skip_glue     : rh = set_effective_width(current, sign, order, glue); break;
                }
            }
            current = node_next(current);
        }
        current = head;
        while (current) {
            if (node_type(current) == glue_node) {
                switch (node_subtype(current)) {
                    case left_skip_glue:
                    case par_fill_left_skip_glue:
                    case par_init_left_skip_glue:
                    case indent_skip_glue:
                    case left_hang_skip_glue:
                        first = current;
                        current = node_next(current);
                        break;
                    default:
                        current = null;
                        break;
                }
            } else {
                current = null;
            }
        }
        current = tail;
        while (current) {
            if (node_type(current) == glue_node) {
                switch (node_subtype(current)) {
                    case right_skip_glue:
                    case par_fill_right_skip_glue:
                    case par_init_right_skip_glue:
                    case right_hang_skip_glue:
                        last = current;
                        current = node_prev(current);
                        break;
                    default:
                        current = null;
                        break;
                }
            } else {
                current = null;
            }
        }
        lua_createtable(L, 0, 14); /* we could add some more */
        lua_push_integer_at_key(L, leftskip, ls);
        lua_push_integer_at_key(L, rightskip, rs);
        lua_push_integer_at_key(L, lefthangskip, lh);
        lua_push_integer_at_key(L, righthangskip, rh);
        lua_push_integer_at_key(L, indent, is);
        lua_push_integer_at_key(L, parfillleftskip, pl);
        lua_push_integer_at_key(L, parfillrightskip, pr);
        lua_push_integer_at_key(L, parinitleftskip, il);
        lua_push_integer_at_key(L, parinitrightskip, ir);
        lua_push_integer_at_key(L, first, first); /* points to a skip */
        lua_push_integer_at_key(L, last, last);   /* points to a skip */
        lua_push_integer_at_key(L, head, head);
        lua_push_integer_at_key(L, tail, tail);
     // lua_push_integer_at_key(L, width, box_width(n));
        return 1;
    }
    return 0;
}

/*tex new */

static int nodelib_direct_ignoremathskip(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == math_node) {
        lua_pushboolean(L, tex_ignore_math_skip(n));
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int nodelib_direct_reverse(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        n = tex_reversed_node_list(n);
    }
    nodelib_push_direct_or_nil(L, n);
    return 1;
}

static int nodelib_direct_exchange(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    if (head) {
        halfword first = nodelib_valid_direct_from_index(L, 2);
        if (first) {
            halfword second = nodelib_valid_direct_from_index(L, 3);
            if (! second) {
                second = node_next(first);
            }
            if (second) {
                halfword pf = node_prev(first);
                halfword ns = node_next(second);
                if (first == head) {
                    head = second;
                } else if (second == head) {
                    head = first;
                }
                if (second == node_next(first)) {
                    node_prev(first) = second;
                    node_next(second) = first;
                } else {
                    halfword nf = node_next(first);
                    halfword ps = node_prev(second);
                    node_prev(first) = ps;
                    if (ps) {
                        node_next(ps) = first;
                    }
                    node_next(second) = nf;
                    if (nf) {
                        node_prev(nf) = second;
                    }
                }
                node_next(first) = ns;
                node_prev(second) = pf;
                if (pf) {
                    node_next(pf) = second;
                }
                if (ns) {
                    node_prev(ns) = first;
                }
            }
        }
    }
    nodelib_push_direct_or_nil(L, head);
    return 1;
}

/*tex experiment */

inline static halfword nodelib_aux_migrate_decouple(halfword head, halfword current, halfword next, halfword *first, halfword *last)
{
    halfword prev = node_prev(current);
    tex_uncouple_node(current);
    if (current == head) {
        node_prev(next) = null;
        head = next;
    } else {
        tex_try_couple_nodes(prev, next);
    }
    if (*first) {
        tex_couple_nodes(*last, current);
    } else {
        *first = current;
    }
    *last = current;
    return head;
}

static halfword lmt_direct_migrate_locate(halfword head, halfword *first, halfword *last, int inserts, int marks)
{
    halfword current = head;
    while (current) {
        halfword next = node_next(current);
        switch (node_type(current)) {
            case vlist_node:
            case hlist_node:
                {
                    halfword list = box_list(current);
                    if (list) {
                        box_list(current) = lmt_direct_migrate_locate(list, first, last, inserts, marks);
                    }
                    break;
                }
            case insert_node:
                {
                    if (inserts) {
                        halfword list; 
                        head = nodelib_aux_migrate_decouple(head, current, next, first, last);
                        list = insert_list(current);
                        if (list) {
                            insert_list(current) = lmt_direct_migrate_locate(list, first, last, inserts, marks);
                        }
                    }
                    break;
                }
            case mark_node:
                {
                    if (marks) {
                        head = nodelib_aux_migrate_decouple(head, current, next, first, last);
                    }
                    break;
                }
            default:
                break;
        }
        current = next;
    }
    return head;
}

static int nodelib_direct_migrate(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    if (head) {
        int inserts = lua_type(L, 3) == LUA_TBOOLEAN ? lua_toboolean(L, 2) : 1;
        int marks = lua_type(L, 2) == LUA_TBOOLEAN ? lua_toboolean(L, 3) : 1;
        halfword first = null;
        halfword last = null;
        halfword current = head;
        while (current) {
            switch (node_type(current)) {
                case vlist_node:
                case hlist_node:
                    {
                        halfword list = box_list(current);
                        if (list) {
                            box_list(current) = lmt_direct_migrate_locate(list, &first, &last, inserts, marks);
                        }
                        break;
                    }
                 case insert_node:
                     if (inserts) {
                         halfword list = insert_list(current);
                         if (list) {
                             insert_list(current) = lmt_direct_migrate_locate(list, &first, &last, inserts, marks);
                         }
                         break;
                     }
            }
            current = node_next(current);
        }
        nodelib_push_direct_or_nil(L, head);
        nodelib_push_direct_or_nil(L, first);
        nodelib_push_direct_or_nil(L, last);
        return 3;
    }
    return 0;
}

/*tex experiment */

static int nodelib_aux_no_left(halfword n, halfword l, halfword r)
{
    if (tex_has_glyph_option(n, (singleword) l)) {
        return 1;
    } else {
        n = node_prev(n);
        if (n) {
            if (node_type(n) == disc_node) {
                n = disc_no_break_tail(n);
            }
            if (n && node_type(n) == glyph_node && tex_has_glyph_option(n, (singleword) r)) {
                return 1;
            }
        }
    }
    return 0;
}

static int nodelib_aux_no_right(halfword n, halfword r, halfword l)
{
    if (tex_has_glyph_option(n, (singleword) r)) {
        return 1;
    } else {
        n = node_next(n);
        if (node_type(n) == disc_node) {
            n = disc_no_break_head(n);
        }
        if (n && node_type(n) == glyph_node && tex_has_glyph_option(n, (singleword) l)) {
            return 1;
        }
    }
    return 0;
}

static int nodelib_direct_hasglyphoption(lua_State *L)
{
    halfword current = nodelib_valid_direct_from_index(L, 1);
    int result = 0;
    if (current && node_type(current) == glyph_node) {
        int option = lmt_tointeger(L, 2);
        switch (option) {
            case glyph_option_normal_glyph:      // 0x00
                break;
            case glyph_option_no_left_ligature:  // 0x01
                result = nodelib_aux_no_left(current, glyph_option_no_left_ligature, glyph_option_no_right_ligature);
                break;
            case glyph_option_no_right_ligature: // 0x02
                result = nodelib_aux_no_right(current, glyph_option_no_right_ligature, glyph_option_no_left_ligature);
                break;
            case glyph_option_no_left_kern:      // 0x04
                result = nodelib_aux_no_left(current, glyph_option_no_left_kern, glyph_option_no_right_kern);
                break;
            case glyph_option_no_right_kern:     // 0x08
                result = nodelib_aux_no_right(current, glyph_option_no_right_kern, glyph_option_no_left_kern);
                break;
            case glyph_option_no_expansion:      // 0x10
                /* some day */
                break;
            case glyph_option_no_protrusion:     // 0x20
                /* some day */
                break;
            case glyph_option_no_italic_correction:
            case glyph_option_math_discretionary:
            case glyph_option_math_italics_too:
                result = tex_has_glyph_option(current, option);
                break;
        }
    }
    lua_pushboolean(L, result);
    return 1;
}

static int nodelib_direct_getspeciallist(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    halfword head = null;
    halfword tail = null;
    if (! s) {
        /* error */
    } else if (lua_key_eq(s, pageinserthead)) {
        head = tex_get_special_node_list(page_insert_list_type, &tail);
    } else if (lua_key_eq(s, contributehead)) {
        head = tex_get_special_node_list(contribute_list_type, &tail);
    } else if (lua_key_eq(s, pagehead)) {
        head = tex_get_special_node_list(page_list_type, &tail);
    } else if (lua_key_eq(s, temphead)) {
        head = tex_get_special_node_list(temp_list_type, &tail);
    } else if (lua_key_eq(s, holdhead)) {
        head = tex_get_special_node_list(hold_list_type, &tail);
    } else if (lua_key_eq(s, postadjusthead)) {
        head = tex_get_special_node_list(post_adjust_list_type, &tail);
    } else if (lua_key_eq(s, preadjusthead)) {
        head = tex_get_special_node_list(pre_adjust_list_type, &tail);
    } else if (lua_key_eq(s, postmigratehead)) {
        head = tex_get_special_node_list(post_migrate_list_type, &tail);
    } else if (lua_key_eq(s, premigratehead)) {
        head = tex_get_special_node_list(pre_migrate_list_type, &tail);
    } else if (lua_key_eq(s, alignhead)) {
        head = tex_get_special_node_list(align_list_type, &tail);
    } else if (lua_key_eq(s, pagediscardshead)) {
        head = tex_get_special_node_list(page_discards_list_type, &tail);
    } else if (lua_key_eq(s, splitdiscardshead)) {
        head = tex_get_special_node_list(split_discards_list_type, &tail);
    }
    nodelib_push_direct_or_nil(L, head);
    nodelib_push_direct_or_nil(L, tail);
    return 2;
}

static int nodelib_direct_isspeciallist(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    int istail = 0;
    int checked = tex_is_special_node_list(head, &istail);
    if (checked >= 0) {
        lua_pushinteger(L, checked);
        if (istail) {
            lua_pushboolean(L, 1);
            return 2;
        }
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int nodelib_direct_setspeciallist(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 2);
    const char *s = lua_tostring(L, 1);
    if (! s) {
        /* error */
    } else if (lua_key_eq(s, pageinserthead)) {
        tex_set_special_node_list(page_insert_list_type, head);
    } else if (lua_key_eq(s, contributehead)) {
        tex_set_special_node_list(contribute_list_type, head);
    } else if (lua_key_eq(s, pagehead)) {
        tex_set_special_node_list(page_list_type, head);
    } else if (lua_key_eq(s, temphead)) {
        tex_set_special_node_list(temp_list_type, head);
    } else if (lua_key_eq(s, holdhead)) {
        tex_set_special_node_list(hold_list_type, head);
    } else if (lua_key_eq(s, postadjusthead)) {
        tex_set_special_node_list(post_adjust_list_type, head);
    } else if (lua_key_eq(s, preadjusthead)) {
        tex_set_special_node_list(pre_adjust_list_type, head);
    } else if (lua_key_eq(s, postmigratehead)) {
        tex_set_special_node_list(post_migrate_list_type, head);
    } else if (lua_key_eq(s, premigratehead)) {
        tex_set_special_node_list(pre_migrate_list_type, head);
    } else if (lua_key_eq(s, alignhead)) {
        tex_set_special_node_list(align_list_type, head);
    } else if (lua_key_eq(s, pagediscardshead)) {
        tex_set_special_node_list(page_discards_list_type, head);
    } else if (lua_key_eq(s, splitdiscardshead)) {
        tex_set_special_node_list(split_discards_list_type, head);
    }
    return 0;
}

/*tex 
    This is just an experiment, so it might go away. Using a list can be a bit faster that traverse
    (2-4 times) but you only see a difference on very last lists and even then one need some 10K 
    loops to notice it. If that gain is needed, I bet that the document takes a while to process 
    anyway. 
*/

static int nodelib_direct_getnodes(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        int i = 0;
        /* maybe count */
        lua_newtable(L);
        if (lua_type(L, 2) == LUA_TNUMBER) {
            int t = lmt_tointeger(L, 2);
            if (lua_type(L, 3) == LUA_TNUMBER) {
                int s = lmt_tointeger(L, 3);
                while (n) {
                    if (node_type(n) == t && node_subtype(n) == s) {
                        lua_pushinteger(L, n);
                        lua_rawseti(L, -2, ++i);
                    }
                    n = node_next(n);
                }
            } else {
                while (n) {
                    if (node_type(n) == t) {
                        lua_pushinteger(L, n);
                        lua_rawseti(L, -2, ++i);
                    }
                    n = node_next(n);
                }
            }
        } else { 
            while (n) {
                lua_pushinteger(L, n);
                lua_rawseti(L, -2, ++i);
                n = node_next(n);
            }
        }
        if (i) {
            return 1;
        } else { 
            lua_pop(L, 1);
        }
    }
    lua_pushnil(L);
    return 1;
}

/*tex experiment */

static int nodelib_direct_getusedattributes(lua_State* L)
{
    lua_newtable(L); /* todo: preallocate */
    for (int current = lmt_node_memory_state.nodes_data.top; current > lmt_node_memory_state.reserved; current--) {
        if (lmt_node_memory_state.nodesizes[current] > 0 && (node_type(current) == attribute_node && node_subtype(current) != attribute_list_subtype)) {
            if (lua_rawgeti(L, -1, attribute_index(current)) == LUA_TTABLE) {
                lua_pushboolean(L, 1);
                lua_rawseti(L, -2, attribute_value(current));
                lua_pop(L, 1);
                /* not faster: */
             // if (lua_rawgeti(L, -1, attribute_value(current)) != LUA_TBOOLEAN) {
             //     lua_pushboolean(L, 1);
             //     lua_rawseti(L, -3, attribute_value(current));
             // }
             // lua_pop(L, 2);
            } else {
                lua_pop(L, 1);
                lua_newtable(L);
                lua_pushboolean(L, 1);
                lua_rawseti(L, -2, attribute_value(current));
                lua_rawseti(L, -2, attribute_index(current));
            }
        }
    }
    return 1;
}

static int nodelib_shared_getcachestate(lua_State *L)
{
    lua_pushboolean(L, attribute_cache_disabled);
    return 1;
}

/*tex done */

static int nodelib_get_property_t(lua_State *L)
{   /* <table> <node> */
    halfword n = lmt_check_isnode(L, 2);
    if (n) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        /* <table> <node> <properties> */
        lua_rawgeti(L, -1, n);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_set_property_t(lua_State *L)
{
    /* <table> <node> <value> */
    halfword n = lmt_check_isnode(L, 2);
    if (n) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        /* <table> <node> <value> <properties> */
        lua_insert(L, -2);
        /* <table> <node> <properties> <value> */
        lua_rawseti(L, -2, n);
    }
    return 0;
}

/* */

static int nodelib_hybrid_gluetostring(lua_State *L)
{
    halfword glue = lua_type(L, 1) == LUA_TNUMBER ? nodelib_valid_direct_from_index(L, 1): lmt_maybe_isnode(L, 1);
    if (glue) { 
        switch (node_type(glue)) {
            case glue_node: 
            case glue_spec_node: 
                {
                    int saved_selector = lmt_print_state.selector;
                    char *str = NULL;
                    lmt_print_state.selector = new_string_selector_code;
                    tex_print_spec(glue, pt_unit);
                    str = tex_take_string(NULL);
                    lmt_print_state.selector = saved_selector;
                    lua_pushstring(L, str);
                    return 1;
            }
        }
    }
    return 0;
}

static const struct luaL_Reg nodelib_p[] = {
    { "__index",    nodelib_get_property_t },
    { "__newindex", nodelib_set_property_t },
    { NULL,         NULL                   },
};

void lmt_initialize_properties(int set_size)
{
    lua_State *L = lmt_lua_state.lua_instance;
    if (lmt_node_memory_state.node_properties_id) {
        /*tex
            We should clean up but for now we accept a leak because these tables are still empty,
            and when you do this once again you're probably messing up. This should actually be
            enough:
        */
        luaL_unref(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
        lmt_node_memory_state.node_properties_id = 0;
    }
    if (set_size) {
        tex_engine_get_config_number("propertiessize", &lmt_node_memory_state.node_properties_table_size);
        if (lmt_node_memory_state.node_properties_table_size < 0) {
            lmt_node_memory_state.node_properties_table_size = 0;
        }
        /*tex It's a hash, not an array because we jump by size. */
        lua_createtable(L, 0, lmt_node_memory_state.node_properties_table_size);
    } else {
        lua_newtable(L);
    }
    /* <properties table> */
    lmt_node_memory_state.node_properties_id = luaL_ref(L, LUA_REGISTRYINDEX);
    /* not needed, so unofficial */
    lua_pushstring(L, NODE_PROPERTIES_DIRECT);
    /* <direct identifier> */
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_node_memory_state.node_properties_id);
    /* <direct identifier> <properties table> */
    lua_settable(L, LUA_REGISTRYINDEX);
    /* */
    lua_pushstring(L, NODE_PROPERTIES_INDIRECT);
    /* <indirect identifier> */
    lua_newtable(L);
    /* <indirect identifier> <stub table> */
    luaL_newmetatable(L, NODE_PROPERTIES_INSTANCE);
    /* <indirect identifier> <stub table> <metatable> */
    luaL_setfuncs(L, nodelib_p, 0);
    /* <indirect identifier> <stub table> <metatable> */
    lua_setmetatable(L, -2);
    /* <indirect identifier> <stub table> */
    lua_settable(L, LUA_REGISTRYINDEX);
    /* */
}

/* node.direct.* */

static const struct luaL_Reg nodelib_direct_function_list[] = {
    { "checkdiscretionaries",    nodelib_direct_checkdiscretionaries   },
    { "checkdiscretionary",      nodelib_direct_checkdiscretionary     },
    { "copy",                    nodelib_direct_copy                   },
    { "copylist",                nodelib_direct_copylist               },
    { "copyonly",                nodelib_direct_copyonly               },
    { "count",                   nodelib_direct_count                  },
    { "currentattributes",       nodelib_direct_currentattributes      },
    { "dimensions",              nodelib_direct_dimensions             },
    { "effectiveglue",           nodelib_direct_effectiveglue          },
    { "endofmath",               nodelib_direct_endofmath              },
    { "findattribute",           nodelib_direct_findattribute          },
    { "findattributerange",      nodelib_direct_findattributerange     },
    { "findnode",                nodelib_direct_findnode               },
    { "firstglyph",              nodelib_direct_firstglyph             },
    { "flattendiscretionaries",  nodelib_direct_flattendiscretionaries },
    { "softenhyphens",           nodelib_direct_softenhyphens          },
    { "flushlist",               nodelib_direct_flushlist              },
    { "flushnode",               nodelib_direct_flushnode              },
    { "free",                    nodelib_direct_free                   },
    { "getattribute",            nodelib_direct_getattribute           },
    { "getattributes",           nodelib_direct_getattributes          },
    { "getpropertiestable",      nodelib_direct_getpropertiestable     },
    { "getinputfields",          nodelib_direct_getinputfields         },
    { "getattributelist",        nodelib_direct_getattributelist       },
    { "getboth",                 nodelib_direct_getboth                },
    { "getbottom",               nodelib_direct_getbottom              },
    { "getbox",                  nodelib_direct_getbox                 },
    { "getchar",                 nodelib_direct_getchar                },
    { "getchardict",             nodelib_direct_getchardict            },
    { "getcharspec",             nodelib_direct_getcharspec            },
    { "getchoice",               nodelib_direct_getchoice              },
    { "getclass",                nodelib_direct_getclass               },
    { "getstate",                nodelib_direct_getstate               },
    { "getscript",               nodelib_direct_getscript              },
    { "getdata",                 nodelib_direct_getdata                },
    { "getleftdelimiter",        nodelib_direct_getleftdelimiter       },
    { "getrightdelimiter",       nodelib_direct_getrightdelimiter      },
    { "getdelimiter",            nodelib_direct_getdelimiter           },
    { "getdenominator",          nodelib_direct_getdenominator         },
    { "getdegree",               nodelib_direct_getdegree              },
    { "getdepth",                nodelib_direct_getdepth               },
    { "getdirection",            nodelib_direct_getdirection           },
    { "getdisc",                 nodelib_direct_getdisc                },
    { "getdiscpart",             nodelib_direct_getdiscpart            },
    { "getexpansion",            nodelib_direct_getexpansion           },
    { "getfam",                  nodelib_direct_getfam                 },
    { "getfield",                nodelib_direct_getfield               },
    { "getfont",                 nodelib_direct_getfont                },
    { "getglue",                 nodelib_direct_getglue                },
    { "getglyphdata",            nodelib_direct_getglyphdata           },
    { "getheight",               nodelib_direct_getheight              },
    { "getindex",                nodelib_direct_getindex               },
    { "getid",                   nodelib_direct_getid                  },
    { "getkern",                 nodelib_direct_getkern                },
    { "getlanguage",             nodelib_direct_getlanguage            },
    { "getleader",               nodelib_direct_getleader              },
    { "getlist",                 nodelib_direct_getlist                },
    { "getnext",                 nodelib_direct_getnext                },
    { "getnormalizedline",       nodelib_direct_getnormalizedline      },
    { "getnodes",                nodelib_direct_getnodes               }, 
    { "getnucleus",              nodelib_direct_getnucleus             },
    { "getnumerator",            nodelib_direct_getnumerator           },
    { "getoffsets",              nodelib_direct_getoffsets             },
    { "getanchors",              nodelib_direct_getanchors             },
    { "gettop",                  nodelib_direct_gettop                 },
    { "getscales",               nodelib_direct_getscales              },
    { "getscale",                nodelib_direct_getscale               },
    { "getxscale",               nodelib_direct_getxscale              },
    { "getyscale",               nodelib_direct_getyscale              },
    { "xscaled",                 nodelib_direct_xscaled                },
    { "yscaled",                 nodelib_direct_yscaled                },
    { "getxyscales",             nodelib_direct_getxyscales            },
    { "getoptions",              nodelib_direct_getoptions             },
    { "hasgeometry",             nodelib_direct_hasgeometry            },
    { "getgeometry",             nodelib_direct_getgeometry            },
    { "setgeometry",             nodelib_direct_setgeometry            },
    { "getorientation",          nodelib_direct_getorientation         },
    { "getpenalty",              nodelib_direct_getpenalty             },
    { "getpost",                 nodelib_direct_getpost                },
    { "getpre",                  nodelib_direct_getpre                 },
    { "getprev",                 nodelib_direct_getprev                },
    { "getproperty",             nodelib_direct_getproperty            },
    { "getreplace",              nodelib_direct_getreplace             },
    { "getshift",                nodelib_direct_getshift               },
    { "getsub",                  nodelib_direct_getsub                 },
    { "getsubpre",               nodelib_direct_getsubpre              },
    { "getsubtype",              nodelib_direct_getsubtype             },
    { "getsup",                  nodelib_direct_getsup                 },
    { "getsuppre",               nodelib_direct_getsuppre              },
    { "getprime",                nodelib_direct_getprime               },
    { "gettotal" ,               nodelib_direct_gettotal               },
    { "getwhd",                  nodelib_direct_getwhd                 },
    { "getwidth",                nodelib_direct_getwidth               },
    { "getwordrange",            nodelib_direct_getwordrange           },
    { "getparstate",             nodelib_direct_getparstate            },
    { "hasattribute",            nodelib_direct_hasattribute           },
    { "hasdimensions",           nodelib_direct_hasdimensions          },
    { "hasfield",                nodelib_direct_hasfield               },
    { "hasglyph",                nodelib_direct_hasglyph               },
    { "hasglyphoption",          nodelib_direct_hasglyphoption         },
    { "hpack",                   nodelib_direct_hpack                  },
    { "hyphenating",             nodelib_direct_hyphenating            },
    { "collapsing",              nodelib_direct_collapsing             }, /*tex A funny name but like |ligaturing| and |hyphenating|. */
    { "ignoremathskip",          nodelib_direct_ignoremathskip         },
    { "insertafter",             nodelib_direct_insertafter            },
    { "insertbefore",            nodelib_direct_insertbefore           },
    { "appendaftertail",         nodelib_direct_appendaftertail        },
    { "prependbeforehead",       nodelib_direct_prependbeforehead      },
    { "ischar",                  nodelib_direct_ischar                 },
    { "isnextchar",              nodelib_direct_isnextchar             },
    { "isprevchar",              nodelib_direct_isprevchar             },
    { "isnextglyph",             nodelib_direct_isnextglyph            },
    { "isprevglyph",             nodelib_direct_isprevglyph            },
    { "isdirect",                nodelib_direct_isdirect               },
    { "isglyph",                 nodelib_direct_isglyph                },
    { "isnode",                  nodelib_direct_isnode                 },
    { "isvalid",                 nodelib_direct_isvalid                },
    { "iszeroglue",              nodelib_direct_iszeroglue             },
    { "isnext",                  nodelib_direct_isnext                 },
    { "isprev",                  nodelib_direct_isprev                 },
    { "isboth",                  nodelib_direct_isboth                 },
    { "kerning",                 nodelib_direct_kerning                },
    { "lastnode",                nodelib_direct_lastnode               },
    { "length",                  nodelib_direct_length                 },
    { "ligaturing",              nodelib_direct_ligaturing             },
    { "makeextensible",          nodelib_direct_makeextensible         },
    { "mlisttohlist",            nodelib_direct_mlisttohlist           },
    { "naturalwidth",            nodelib_direct_naturalwidth           },
    { "naturalhsize",            nodelib_direct_naturalhsize           },
    { "new",                     nodelib_direct_new                    },
    { "newtextglyph",            nodelib_direct_newtextglyph           },
    { "newmathglyph",            nodelib_direct_newmathglyph           },
    { "protectglyph",            nodelib_direct_protectglyph           },
    { "protectglyphs",           nodelib_direct_protectglyphs          },
    { "protectglyphsnone",       nodelib_direct_protectglyphs_none     },
    { "protrusionskippable",     nodelib_direct_protrusionskipable     },
    { "rangedimensions",         nodelib_direct_rangedimensions        }, /* maybe get... */
    { "getglyphdimensions",      nodelib_direct_getglyphdimensions     },
    { "getkerndimension",        nodelib_direct_getkerndimension       },
    { "patchattributes",         nodelib_direct_patchattributes        },
    { "remove",                  nodelib_direct_remove                 },
    { "repack",                  nodelib_direct_repack                 },
    { "freeze",                  nodelib_direct_freeze                 },
    { "setattribute",            nodelib_direct_setattribute           },
    { "setattributes",           nodelib_direct_setattributes          },
    { "setinputfields",          nodelib_direct_setinputfields         },
    { "setattributelist",        nodelib_direct_setattributelist       },
    { "setboth",                 nodelib_direct_setboth                },
    { "setbottom",               nodelib_direct_setbottom              },
    { "setbox",                  nodelib_direct_setbox                 },
    { "setchar",                 nodelib_direct_setchar                },
    { "setchardict",             nodelib_direct_setchardict            },
    { "setchoice",               nodelib_direct_setchoice              },
    { "setclass",                nodelib_direct_setclass               },
    { "setstate",                nodelib_direct_setstate               },
    { "setscript",               nodelib_direct_setscript              },
    { "setdata",                 nodelib_direct_setdata                },
    { "setleftdelimiter",        nodelib_direct_setleftdelimiter       },
    { "setrightdelimiter",       nodelib_direct_setrightdelimiter      },
    { "setdelimiter",            nodelib_direct_setdelimiter           },
    { "setdenominator",          nodelib_direct_setdenominator         },
    { "setdegree",               nodelib_direct_setdegree              },
    { "setdepth",                nodelib_direct_setdepth               },
    { "setdirection",            nodelib_direct_setdirection           },
    { "setdisc",                 nodelib_direct_setdisc                },
    { "setdiscpart",             nodelib_direct_setdiscpart            },
    { "setexpansion",            nodelib_direct_setexpansion           },
    { "setfam",                  nodelib_direct_setfam                 },
    { "setfield",                nodelib_direct_setfield               },
    { "setfont",                 nodelib_direct_setfont                },
    { "setglue",                 nodelib_direct_setglue                },
    { "setglyphdata",            nodelib_direct_setglyphdata           },
    { "setheight",               nodelib_direct_setheight              },
    { "setindex",                nodelib_direct_setindex               },
    { "setkern",                 nodelib_direct_setkern                },
    { "setlanguage",             nodelib_direct_setlanguage            },
    { "setleader",               nodelib_direct_setleader              },
    { "setlink",                 nodelib_direct_setlink                },
    { "setlist",                 nodelib_direct_setlist                },
    { "setnext",                 nodelib_direct_setnext                },
    { "setnucleus",              nodelib_direct_setnucleus             },
    { "setnumerator",            nodelib_direct_setnumerator           },
    { "setoffsets",              nodelib_direct_setoffsets             },
    { "addxoffset",              nodelib_direct_addxoffset             },
    { "addyoffset",              nodelib_direct_addyoffset             },
    { "addmargins",              nodelib_direct_addmargins             },
    { "addxymargins",            nodelib_direct_addxymargins           },
    { "setscales",               nodelib_direct_setscales              },
    { "setanchors",              nodelib_direct_setanchors             },
    { "setorientation",          nodelib_direct_setorientation         },
    { "setoptions",              nodelib_direct_setoptions             },
    { "setpenalty",              nodelib_direct_setpenalty             },
    { "setpost",                 nodelib_direct_setpost                },
    { "setpre",                  nodelib_direct_setpre                 },
    { "setprev",                 nodelib_direct_setprev                },
    { "setproperty",             nodelib_direct_setproperty            },
    { "setreplace",              nodelib_direct_setreplace             },
    { "setshift",                nodelib_direct_setshift               },
    { "setsplit",                nodelib_direct_setsplit               },
    { "setsub",                  nodelib_direct_setsub                 },
    { "setsubpre",               nodelib_direct_setsubpre              },
    { "setsubtype",              nodelib_direct_setsubtype             },
    { "setsup",                  nodelib_direct_setsup                 },
    { "setsuppre",               nodelib_direct_setsuppre              },
    { "setprime" ,               nodelib_direct_setprime               },
    { "settotal" ,               nodelib_direct_settotal               },
    { "settop" ,                 nodelib_direct_settop                 },
    { "setwhd",                  nodelib_direct_setwhd                 },
    { "setwidth",                nodelib_direct_setwidth               },
    { "slide",                   nodelib_direct_slide                  },
    { "startofpar",              nodelib_direct_startofpar             },
    { "tail",                    nodelib_direct_tail                   },
    { "todirect",                nodelib_direct_todirect               },
    { "tonode",                  nodelib_direct_tonode                 },
    { "tostring",                nodelib_direct_tostring               },
    { "tovaliddirect",           nodelib_direct_tovaliddirect          },
    { "traverse",                nodelib_direct_traverse               },
    { "traversechar",            nodelib_direct_traversechar           },
    { "traverseglyph",           nodelib_direct_traverseglyph          },
    { "traverseid",              nodelib_direct_traverseid             },
    { "traverselist",            nodelib_direct_traverselist           },
    { "traversecontent",         nodelib_direct_traversecontent        },
    { "traverseleader",          nodelib_direct_traverseleader         },
    { "unprotectglyph",          nodelib_direct_unprotectglyph         },
    { "unprotectglyphs",         nodelib_direct_unprotectglyphs        },
    { "unsetattribute",          nodelib_direct_unsetattribute         },
    { "unsetattributes",         nodelib_direct_unsetattributes        },
    { "usedlist",                nodelib_direct_usedlist               },
    { "usesfont",                nodelib_direct_usesfont               },
    { "vpack",                   nodelib_direct_vpack                  },
    { "flattenleaders",          nodelib_direct_flattenleaders         },
    { "write",                   nodelib_direct_write                  },
 /* { "appendtocurrentlist",     nodelib_direct_appendtocurrentlist    }, */ /* beware, we conflict in ctx */
    { "verticalbreak",           nodelib_direct_verticalbreak          },
    { "reverse",                 nodelib_direct_reverse                },
    { "exchange",                nodelib_direct_exchange               },
    { "migrate",                 nodelib_direct_migrate                },
    { "getspeciallist",          nodelib_direct_getspeciallist         },
    { "setspeciallist",          nodelib_direct_setspeciallist         },
    { "isspeciallist",           nodelib_direct_isspeciallist          },
    { "getusedattributes",       nodelib_direct_getusedattributes      },
    /* dual node and direct */
    { "type",                    nodelib_hybrid_type                   },
    { "types",                   nodelib_shared_types                  },
    { "fields",                  nodelib_shared_fields                 },
    { "subtypes",                nodelib_shared_subtypes               },
    { "values",                  nodelib_shared_values                 },
    { "id",                      nodelib_shared_id                     },
    { "show",                    nodelib_direct_show                   },
    { "gluetostring",            nodelib_hybrid_gluetostring           },
    { "serialized",              nodelib_direct_serialized             },
    { "getcachestate",           nodelib_shared_getcachestate          },
    { NULL,                      NULL                                  },
};

/* node.* */

static const struct luaL_Reg nodelib_function_list[] = {
    /* the bare minimum for reasonable performance */
    { "copy",                     nodelib_userdata_copy                 },
    { "copylist",                 nodelib_userdata_copylist             },
    { "new",                      nodelib_userdata_new                  },
    { "flushlist",                nodelib_userdata_flushlist            },
    { "flushnode",                nodelib_userdata_flushnode            },
    { "free",                     nodelib_userdata_free                 },
    { "currentattributes",        nodelib_userdata_currentattributes    },
    { "hasattribute",             nodelib_userdata_hasattribute         },
    { "getattribute",             nodelib_userdata_getattribute         },
    { "setattribute",             nodelib_userdata_setattribute         },
    { "unsetattribute",           nodelib_userdata_unsetattribute       },
    { "getpropertiestable",       nodelib_userdata_getpropertiestable   },
    { "getproperty",              nodelib_userdata_getproperty          },
    { "setproperty",              nodelib_userdata_setproperty          },
    { "getfield",                 nodelib_userdata_getfield             },
    { "setfield",                 nodelib_userdata_setfield             },
    { "hasfield",                 nodelib_userdata_hasfield             },
    { "tail",                     nodelib_userdata_tail                 },
    { "write",                    nodelib_userdata_write                },
 /* { "appendtocurrentlist",      nodelib_userdata_append               }, */ /* beware, we conflict in ctx */
    { "isnode",                   nodelib_userdata_isnode               },
    { "tostring",                 nodelib_userdata_tostring             },
    { "usedlist",                 nodelib_userdata_usedlist             },
    { "inuse",                    nodelib_userdata_inuse                },
    { "instock",                  nodelib_userdata_instock              },
    { "traverse",                 nodelib_userdata_traverse             },
    { "traverseid",               nodelib_userdata_traverse_id          },
    { "insertafter",              nodelib_userdata_insertafter          },
    { "insertbefore",             nodelib_userdata_insertbefore         },
    { "remove",                   nodelib_userdata_remove               },
    /* shared between userdata and direct */
    { "type",                     nodelib_hybrid_type                   },
    { "types",                    nodelib_shared_types                  },
    { "fields",                   nodelib_shared_fields                 },
    { "subtypes",                 nodelib_shared_subtypes               },
    { "values",                   nodelib_shared_values                 },
    { "id",                       nodelib_shared_id                     },
    { "show",                     nodelib_userdata_show                 },
    { "gluetostring",             nodelib_hybrid_gluetostring           },
    { "serialized",               nodelib_userdata_serialized           },
    { "getcachestate",            nodelib_shared_getcachestate          },
    { NULL,                       NULL                                  },
};

static const struct luaL_Reg nodelib_metatable[] = {
    { "__index",    nodelib_userdata_index    },
    { "__newindex", nodelib_userdata_newindex },
    { "__tostring", nodelib_userdata_tostring },
    { "__eq",       nodelib_userdata_equal    },
    { NULL,         NULL                      },
};

int luaopen_node(lua_State *L)
{
    /*tex the main metatable of node userdata */
    luaL_newmetatable(L, NODE_METATABLE_INSTANCE);
    /* node.* */
    luaL_setfuncs(L, nodelib_metatable, 0);
    lua_newtable(L);
    luaL_setfuncs(L, nodelib_function_list, 0);
    /* node.direct */
    lua_pushstring(L, lua_key(direct));
    lua_newtable(L);
    luaL_setfuncs(L, nodelib_direct_function_list, 0);
    lua_rawset(L, -3);
    return 1;
}

void lmt_node_list_to_lua(lua_State *L, halfword n)
{
    lmt_push_node_fast(L, n);
}

halfword lmt_node_list_from_lua(lua_State *L, int n)
{
    if (lua_isnil(L, n)) {
        return null;
    } else {
        halfword list = lmt_check_isnode(L, n);
        return list ? list : null;
    }
}

/*tex
    Here come the callbacks that deal with node lists. Some are called in multiple locations and
    then get additional information passed concerning the whereabouts.

    The begin paragraph callback first got |cmd| and |chr| but in the end it made more sense to
    do it like the rest and pass a string. There is no need for more granularity.
 */

void lmt_begin_paragraph_callback(
    int  invmode,
    int *indented,
    int  context
)
{
    int callback_id = lmt_callback_defined(begin_paragraph_callback);
    if (callback_id > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int top = 0;
        if (lmt_callback_okay(L, callback_id, &top)) {
            int i;
            lua_pushboolean(L, invmode);
            lua_pushboolean(L, *indented);
            lmt_push_par_begin(L, context);
            i = lmt_callback_call(L, 3, 1, top);
            /* done */
            if (i) {
                lmt_callback_error(L, top, i);
            }
            else {
                *indented = lua_toboolean(L, -1);
                lmt_callback_wrapup(L, top);
            }
        }
    }
}

void lmt_paragraph_context_callback(
    int  context,
    int *ignore
)
{
    int callback_id = lmt_callback_defined(paragraph_context_callback);
    if (callback_id > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int top = 0;
        if (lmt_callback_okay(L, callback_id, &top)) {
            int i;
            lmt_push_par_context(L, context);
            i = lmt_callback_call(L, 1, 1, top);
            if (i) {
                lmt_callback_error(L, top, i);
            }
            else {
                *ignore = lua_toboolean(L, -1);
                lmt_callback_wrapup(L, top);
            }
        }
    }
}

void lmt_page_filter_callback(
    int      context,
    halfword boundary
)
{
    int callback_id = lmt_callback_defined(buildpage_filter_callback);
    if (callback_id > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int top = 0;
        if (lmt_callback_okay(L, callback_id, &top)) {
            int i;
            lmt_push_page_context(L, context);
            lua_push_halfword(L, boundary);
            i = lmt_callback_call(L, 2, 0, top);
            if (i) {
                lmt_callback_error(L, top, i);
            } else {
                lmt_callback_wrapup(L, top);
            }
        }
    }
}

/*tex This one gets |tail| and optionally gets back |head|. */

void lmt_append_line_filter_callback(
    halfword context,
    halfword index /* class */
)
{
    if (cur_list.tail) {
        int callback_id = lmt_callback_defined(append_line_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, node_next(cur_list.head));
                lmt_node_list_to_lua(L, cur_list.tail);
                lmt_push_append_line_context(L, context);
                lua_push_halfword(L, index);
                i = lmt_callback_call(L, 4, 1, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    if (lua_type(L, -1) == LUA_TUSERDATA) {
                        int a = lmt_node_list_from_lua(L, -1);
                        node_next(cur_list.head) = a;
                        cur_list.tail = tex_tail_of_node_list(a);
                    }
                    lmt_callback_wrapup(L, top);
                }
            }
        }
    }
}

/*tex

    Eventually the optional fixing of lists will go away because we assume that proper double linked
    lists get returned. Keep in mind that \TEX\ itself never looks back (we didn't change that bit,
    at least not until now) so it's only callbacks that suffer from bad |prev| fields.

*/

void lmt_node_filter_callback(
    int       filterid,
    int       extrainfo,
    halfword  head,
    halfword *tail
)
{
    if (head) {
        /*tex We start after head (temp). */
        halfword start = node_next(head);
        if (start) {
            int callback_id = lmt_callback_defined(filterid);
            if (callback_id > 0) {
                lua_State *L = lmt_lua_state.lua_instance;
                int top = 0;
                if (lmt_callback_okay(L, callback_id, &top)) {
                    int i;
                    /*tex We make sure we have no prev */
                    node_prev(start) = null;
                    /*tex the action */
                    lmt_node_list_to_lua(L, start);
                    lmt_push_group_code(L, extrainfo);
                    i = lmt_callback_call(L, 2, 1, top);
                    if (i) {
                        lmt_callback_error(L, top, i);
                    } else {
                        /*tex append to old head */
                        halfword list = lmt_node_list_from_lua(L, -1);
                        tex_try_couple_nodes(head, list);
                        /*tex redundant as we set top anyway */
                        lua_pop(L, 2);
                        /*tex find tail in order to update tail */
                        start = node_next(head);
                        if (start) {
                            /*tex maybe just always slide (harmless and fast) */
                            halfword last = node_next(start);
                            while (last) {
                                start = last;
                                last = node_next(start);
                            }
                            /*tex we're at the end now */
                            *tail = start;
                        } else {
                            /*tex we're already at the end */
                            *tail = head;
                        }
                        lmt_callback_wrapup(L, top);
                    }
                }
            }
        }
    }
    return;
}

/*tex
    Maybe this one will get extended a bit in due time.
*/

int lmt_linebreak_callback(
    int       isbroken,
    halfword  head,
    halfword *newhead
)
{
    if (head) {
        halfword start = node_next(head);
        if (start) {
            int callback_id = lmt_callback_defined(linebreak_filter_callback);
            if (callback_id > 0) {
                lua_State *L = lmt_lua_state.lua_instance;
                int top = 0;
                if (callback_id > 0 && lmt_callback_okay(L, callback_id, &top)) {
                    int i;
                    int ret = 0;
                    node_prev(start) = null;
                    lmt_node_list_to_lua(L, start);
                    lua_pushboolean(L, isbroken);
                    i = lmt_callback_call(L, 2, 1, top);
                    if (i) {
                        lmt_callback_error(L, top, i);
                    } else {
                        halfword *result = lua_touserdata(L, -1);
                        if (result) {
                            halfword list = lmt_node_list_from_lua(L, -1);
                            tex_try_couple_nodes(*newhead, list);
                            ret = 1;
                        }
                        lmt_callback_wrapup(L, top);
                    }
                    return ret;
                }
            }
        }
    }
    return 0;
}

void lmt_alignment_callback(
    halfword head,
    halfword context,
    halfword attrlist,
    halfword preamble
)
{
    if (head || preamble) {
        int callback_id = lmt_callback_defined(alignment_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, head);
                lmt_push_alignment_context(L, context);
                lmt_node_list_to_lua(L, attrlist);
                lmt_node_list_to_lua(L, preamble);
                i = lmt_callback_call(L, 4, 0, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    lmt_callback_wrapup(L, top);
                }
            }
        }
    }
    return;
}

void lmt_local_box_callback(
    halfword linebox,
    halfword leftbox,
    halfword rightbox,
    halfword middlebox,
    halfword linenumber,
    scaled   leftskip,
    scaled   rightskip,
    scaled   lefthang,
    scaled   righthang,
    scaled   indentation,
    scaled   parinitleftskip,
    scaled   parinitrightskip,
    scaled   parfillleftskip,
    scaled   parfillrightskip,
    scaled   overshoot
)
{
    if (linebox) {
        int callback_id = lmt_callback_defined(local_box_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, linebox);
                lmt_node_list_to_lua(L, leftbox);
                lmt_node_list_to_lua(L, rightbox);
                lmt_node_list_to_lua(L, middlebox);
                lua_pushinteger(L, linenumber);
                lua_pushinteger(L, leftskip);
                lua_pushinteger(L, rightskip);
                lua_pushinteger(L, lefthang);
                lua_pushinteger(L, righthang);
                lua_pushinteger(L, indentation);
                lua_pushinteger(L, parinitleftskip);
                lua_pushinteger(L, parinitrightskip);
                lua_pushinteger(L, parfillleftskip);
                lua_pushinteger(L, parfillrightskip);
                lua_pushinteger(L, overshoot);
                i = lmt_callback_call(L, 15, 0, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    /* todo: check if these boxes are still okay (defined) */
                    lmt_callback_wrapup(L, top);
                }
            }
        }
    }
}

/*tex
    This one is a bit different from the \LUATEX\ variant. The direction parameter has been dropped
    and prevdepth correction can be controlled.
*/

int lmt_append_to_vlist_callback(
    halfword  box,
    int       location,
    halfword  prevdepth,
    halfword *result,
    int      *nextdepth,
    int      *prevset,
    int      *checkdepth
)
{
    if (box) {
        int callback_id = lmt_callback_defined(append_to_vlist_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, box);
                lua_push_key_by_index(location);
                lua_pushinteger(L, (int) prevdepth);
                i = lmt_callback_call(L, 3, 3, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    switch (lua_type(L, -3)) {
                        case LUA_TUSERDATA:
                            *result = lmt_check_isnode(L, -3);
                            break;
                        case LUA_TNIL:
                            *result = null;
                            break;
                        default:
                            tex_normal_warning("append to vlist callback", "node or nil expected");
                            break;
                    }
                    if (lua_type(L, -2) == LUA_TNUMBER) {
                        *nextdepth = lmt_roundnumber(L, -2);
                        *prevset = 1;
                    }
                    if (*result && lua_type(L, -1) == LUA_TBOOLEAN) {
                        *checkdepth = lua_toboolean(L, -1);
                    }
                    lmt_callback_wrapup(L, top);
                    return 1;
                }
            }
        }
    }
    return 0;
}

/*tex
    Here we keep the directions although they play no real role in the
    packing process.
 */

halfword lmt_hpack_filter_callback(
    halfword head,
    scaled   size,
    int      packtype,
    int      extrainfo,
    int      direction,
    halfword attr
)
{
    if (head) {
        int callback_id = lmt_callback_defined(hpack_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                node_prev(head) = null;
                lmt_node_list_to_lua(L, head);
                lmt_push_group_code(L, extrainfo);
                lua_pushinteger(L, size);
                lmt_push_pack_type(L, packtype);
                if (direction >= 0) {
                    lua_pushinteger(L, direction);
                } else {
                    lua_pushnil(L);
                }
                /* maybe: (attr && attr != cache_disabled) */
                lmt_node_list_to_lua(L, attr);
                i = lmt_callback_call(L, 6, 1, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    head = lmt_node_list_from_lua(L, -1);
                    lmt_callback_wrapup(L, top);
                }
            }
        }
    }
    return head;
}

extern halfword lmt_packed_vbox_filter_callback(
    halfword box,
    int      extrainfo
)
{
    if (box) {
        int callback_id = lmt_callback_defined(packed_vbox_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, box);
                lmt_push_group_code(L, extrainfo);
                i = lmt_callback_call(L, 2, 1, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    box = lmt_node_list_from_lua(L, -1);
                    lmt_callback_wrapup(L, top);
                }
            }
        }
    }
    return box;
}

halfword lmt_vpack_filter_callback(
    halfword head,
    scaled   size,
    int      packtype,
    scaled   maxdepth,
    int      extrainfo,
    int      direction,
    halfword attr
)
{
    if (head) {
        int callback_id = lmt_callback_defined(extrainfo == output_group ? pre_output_filter_callback : vpack_filter_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                node_prev(head) = null;
                lmt_node_list_to_lua(L, head);
                lmt_push_group_code(L, extrainfo);
                lua_pushinteger(L, size);
                lmt_push_pack_type(L, packtype);
                lua_pushinteger(L, maxdepth);
                if (direction >= 0) {
                    lua_pushinteger(L, direction);
                } else {
                    lua_pushnil(L);
                }
                lmt_node_list_to_lua(L, attr);
                i = lmt_callback_call(L, 7, 1, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    head = lmt_node_list_from_lua(L, -1);
                    lmt_callback_wrapup(L, top);
                }
            }
        }
    }
    return head;
}
