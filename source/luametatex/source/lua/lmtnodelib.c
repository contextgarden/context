/*
    See license.txt in the root of this project.
*/

/*tex TODO: update |[get|set]field| for added node entries */

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


# define hlist_usage          ((lua_Integer) 1 << (hlist_node          + 1))
# define vlist_usage          ((lua_Integer) 1 << (vlist_node          + 1))
# define rule_usage           ((lua_Integer) 1 << (rule_node           + 1))
# define insert_usage         ((lua_Integer) 1 << (insert_node         + 1))
# define mark_usage           ((lua_Integer) 1 << (mark_node           + 1))
# define adjust_usage         ((lua_Integer) 1 << (adjust_node         + 1))
# define boundary_usage       ((lua_Integer) 1 << (boundary_node       + 1))
# define disc_usage           ((lua_Integer) 1 << (disc_node           + 1))
# define whatsit_usage        ((lua_Integer) 1 << (whatsit_node        + 1))
# define par_usage            ((lua_Integer) 1 << (par_node            + 1))
# define dir_usage            ((lua_Integer) 1 << (dir_node            + 1))
# define math_usage           ((lua_Integer) 1 << (math_node           + 1))
# define glue_usage           ((lua_Integer) 1 << (glue_node           + 1))
# define kern_usage           ((lua_Integer) 1 << (kern_node           + 1))
# define penalty_usage        ((lua_Integer) 1 << (penalty_node        + 1))
# define style_usage          ((lua_Integer) 1 << (style_node          + 1))
# define choice_usage         ((lua_Integer) 1 << (choice_node         + 1))
# define parameter_usage      ((lua_Integer) 1 << (parameter_node      + 1))
# define simple_usage         ((lua_Integer) 1 << (simple_noad         + 1))
# define radical_usage        ((lua_Integer) 1 << (radical_noad        + 1))
# define fraction_usage       ((lua_Integer) 1 << (fraction_noad       + 1))
# define accent_usage         ((lua_Integer) 1 << (accent_noad         + 1))
# define fence_usage          ((lua_Integer) 1 << (fence_noad          + 1))
# define math_char_usage      ((lua_Integer) 1 << (math_char_node      + 1))
# define math_text_char_usage ((lua_Integer) 1 << (math_text_char_node + 1))
# define sub_box_usage        ((lua_Integer) 1 << (sub_box_node        + 1))
# define sub_mlist_usage      ((lua_Integer) 1 << (sub_mlist_node      + 1))
# define delimiter_usage      ((lua_Integer) 1 << (delimiter_node      + 1))
# define glyph_usage          ((lua_Integer) 1 << (glyph_node          + 1))
# define unset_usage          ((lua_Integer) 1 << (unset_node          + 1))
# define align_record_usage   ((lua_Integer) 1 << (align_record_node   + 1))
# define attribute_usage      ((lua_Integer) 1 << (attribute_node      + 1))
# define glue_spec_usage      ((lua_Integer) 1 << (glue_spec_node      + 1))

# define common_usage         ((lua_Integer) 1 << (last_nodetype       + 2))
# define generic_usage        ((lua_Integer) 1 << (last_nodetype       + 3))

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

static inline halfword nodelib_valid_direct_from_index(lua_State *L, int i)
{
    halfword n = lmt_tohalfword(L, i);
    return n && _valid_node_(n) ? n : null;
}

static inline void nodelib_push_direct_or_nil(lua_State *L, halfword n)
{
    if (n) {
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
}

static inline void nodelib_push_direct_or_nil_node_prev(lua_State *L, halfword n)
{
    if (n) {
        node_prev(n) = null;
        lua_pushinteger(L, n);
    } else {
        lua_pushnil(L);
    }
}

static inline void nodelib_push_node_on_top(lua_State *L, halfword n)
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

static void nodelib_push_attribute_data(lua_State *L, halfword n)
{
    if (node_subtype(n) == attribute_list_subtype) {
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

/*tex maybe: Floyd's cycle finding: */

# define isloop_usage common_usage

static int nodelib_direct_isloop(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    if (head) {
        halfword slow = head;
        halfword fast = head;
        while (slow && fast && node_next(fast)) {
            slow = node_next(slow);
            fast = node_next(node_next(fast));
            if (slow == fast) {
                lua_pushboolean(L, 1);
                return 1;
            }
        }
    }
    lua_pushboolean(L, 0);
    return 0;
}

/*tex Another shortcut: */

static inline singleword nodelib_getdirection(lua_State *L, int i)
{
    return ((lua_type(L, i) == LUA_TNUMBER) ? (singleword) checked_direction_value(lmt_tohalfword(L, i)) : direction_def_value);
}

/*tex

    This routine finds the numerical value of a string (or number) at \LUA\ stack index |n|. If it
    is not a valid node type |-1| is returned.

*/

static quarterword nodelib_aux_get_node_type_id_from_name(lua_State *L, int n, node_info *data, int all)
{
    if (data) {
        const char *s = lua_tostring(L, n);
        for (int j = 0; data[j].id != -1; j++) {
            if (s == data[j].name) {
                if (all || data[j].visible) {
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
            i = nodelib_aux_get_node_type_id_from_name(L, n, lmt_interface.node_data, 0);
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

// void lmt_push_node(lua_State *L)
// {
//     halfword n = null;
//     if (lua_type(L, -1) == LUA_TNUMBER) {
//         n = lmt_tohalfword(L, -1);
//     }
//     lua_pop(L, 1);
//     if ((! n) || (n > lmt_node_memory_state.nodes_data.allocated)) {
//         lua_pushnil(L);
//     } else {
//         halfword *a = lua_newuserdatauv(L, sizeof(halfword), 0);
//         *a = n;
//         lua_get_metatablelua(node_instance);
//         lua_setmetatable(L, -2);
//     }
// }

void lmt_push_node(lua_State *L)
{
    halfword n = null;
    if (lua_type(L, -1) == LUA_TNUMBER) {
        n = lmt_tohalfword(L, -1);
    }
    lua_pop(L, 1);
    if (n && n <= lmt_node_memory_state.nodes_data.allocated) {
        halfword *a = lua_newuserdatauv(L, sizeof(halfword), 0);
        *a = n;
        lua_get_metatablelua(node_instance);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }
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

# define id_usage common_usage

static int nodelib_shared_id(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        int i = nodelib_aux_get_node_type_id_from_name(L, 1, lmt_interface.node_data, 0);
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

# define getid_usage common_usage

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

# define getsubtype_usage common_usage
# define setsubtype_usage common_usage

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

# define getexpansion_usage (glyph_usage | kern_usage)
# define setexpansion_usage getexpansion_usage

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

# define getfont_usage (glyph_usage | glue_usage | math_char_usage | math_text_char_usage | delimiter_usage)
# define setfont_usage (glyph_usage | rule_usage | glue_usage)

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
                    rule_strut_character(n) = lmt_tohalfword(L, 3);
                }
                break;
            case glue_node:
                glue_font(n) = tex_checked_font(lmt_tohalfword(L, 2));
                break;
        }
    }
    return 0;
}

# define getchardict_usage (glyph_usage | math_char_usage | math_text_char_usage | delimiter_usage)
# define setchardict_usage getchardict_usage

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
            case delimiter_node:
                lua_pushinteger(L, delimiter_math_properties(n));
                lua_pushinteger(L, delimiter_math_group(n));
                lua_pushinteger(L, delimiter_math_index(n));
                lua_pushinteger(L, tex_fam_fnt(delimiter_small_family(n),0));
                lua_pushinteger(L, delimiter_small_character(n));
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
            case delimiter_node:
                delimiter_math_properties(n) = lmt_optquarterword(L, 2, 0);
                delimiter_math_group(n) = lmt_optquarterword(L, 3, 0);
                delimiter_math_index(n) = lmt_opthalfword(L, 4, 0);
                break;
        }
    }
    return 0;
}

/* node.direct.getchar */
/* node.direct.setchar */

# define getchar_usage (glyph_usage | rule_usage | math_char_usage | math_text_char_usage | delimiter_usage)
# define setchar_usage getchar_usage

static int nodelib_direct_getchar(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch(node_type(n)) {
            case glyph_node:
                lua_pushinteger(L, glyph_character(n));
                break;
            case rule_node:
                lua_pushinteger(L, rule_strut_character(n));
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
                rule_strut_character(n) = lmt_tohalfword(L, 2);
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

# define getcharspec_usage (glyph_usage | rule_usage | simple_usage | math_char_usage | math_text_char_usage | delimiter_usage)
# define setcharspec_usage getcharspec_usage

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
                lua_pushinteger(L, rule_strut_character(n));
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

# define getfam_usage (math_char_usage | math_text_char_usage | simple_usage | radical_usage | fraction_usage | accent_usage | fence_usage | rule_usage)
# define setfam_usage getfam_usage

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
                delimiter_large_family(n) = delimiter_small_family(n);
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

# define getstate_usage (glyph_usage | hlist_usage | vlist_usage)
# define setstate_usage getstate_usage

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

# define getclass_usage (simple_usage | radical_usage | fraction_usage | accent_usage | fence_usage | glyph_usage | disc_usage | hlist_usage | vlist_usage | delimiter_usage)
# define setclass_usage getclass_usage

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
            case glyph_node:
                {
                    singleword mathclass = node_subtype(n) - glyph_math_ordinary_subtype;
                    if (mathclass >= 0) {
                        lua_push_integer(L, mathclass);
                        return 1;
                    } else {
                        break;
                    }
                }
            case disc_node:
                lua_push_integer(L, disc_class(n));
                return 1;
            case hlist_node:
            case vlist_node:
                {
                    singleword mathclass = node_subtype(n) - noad_class_list_base;
                    if (mathclass >= 0) {
                        lua_push_integer(L, mathclass);
                        return 1;
                    } else {
                        break;
                    }
                }
            case delimiter_node:
                lua_push_integer(L, node_subtype(n));
                return 1;
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
                    set_noad_main_class(n, lmt_tosingleword(L, 2));
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    set_noad_left_class(n, lmt_tosingleword(L, 3));
                }
                if (lua_type(L, 4) == LUA_TNUMBER) {
                    set_noad_right_class(n, lmt_tosingleword(L, 4));
                }
                break;
            case glyph_node:
                node_subtype(n) = glyph_math_ordinary_subtype + lmt_tosingleword(L, 2);
                break;
            case disc_node:
                disc_class(n) = lmt_tosingleword(L, 2);
                break;
            case hlist_node:
            case vlist_node:
                node_subtype(n) = noad_class_list_base + lmt_tosingleword(L, 2);
                break;
            case delimiter_node:
                node_subtype(n) = lmt_tosingleword(L, 2);
                return 1;
        }
    }
    return 0;
}

/* node.direct.getscript(n) */
/* node.direct.setscript(n) */

# define getscript_usage (glyph_usage)
# define setscript_usage getscript_usage

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

/* node.direct.getlanguage */
/* node.direct.setlanguage */

# define getlanguage_usage (glyph_usage)
# define setlanguage_usage getlanguage_usage

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

/* node.direct.getcontrol */
/* node.direct.setcontrol */

# define getcontrol_usage (glyph_usage)
# define setcontrol_usage getcontrol_usage

static int nodelib_direct_getcontrol(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, get_glyph_control(n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_setcontrol(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        set_glyph_control(n, lmt_opthalfword(L, 2, 0));
    }
    return 0;
}

/* node.direct.getattributelist */
/* node.direct.setattributelist */

# define getattributelist_usage common_usage
# define setattributelist_usage getattributelist_usage

static int nodelib_direct_getattributelist(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && tex_nodetype_has_attributes(node_type(n)) && node_attr(n)) {
        if (lua_toboolean(L, 2)) {
            nodelib_push_attribute_data(L, node_attr(n));
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

# define getpenalty_usage (penalty_usage | disc_usage | math_node)
# define setpenalty_usage getpenalty_usage

static int nodelib_direct_getpenalty(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case penalty_node:
                lua_pushinteger(L, lua_toboolean(L, 2) ? penalty_tnuoma(n) : penalty_amount(n));
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
/* node.direct.setnucleus */

# define atomlike_usage (simple_usage | accent_usage | radical_usage)

# define getnucleus_usage atomlike_usage
# define setnucleus_usage atomlike_usage

static int nodelib_direct_getnucleus(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_nucleus(n));
                if (lua_toboolean(L, 2)) {
                    nodelib_push_direct_or_nil(L, noad_prime(n));
                    nodelib_push_direct_or_nil(L, noad_supscr(n));
                    nodelib_push_direct_or_nil(L, noad_subscr(n));
                    nodelib_push_direct_or_nil(L, noad_supprescr(n));
                    nodelib_push_direct_or_nil(L, noad_subprescr(n));
                    return 6;
                } else {
                    return 1;
                }
        }
    }
    lua_pushnil(L);
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

/* node.direct.getscripts */
/* node.direct.setscripts */

# define getscripts_usage atomlike_usage
# define setscripts_usage atomlike_usage

static int nodelib_direct_getscripts(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                nodelib_push_direct_or_nil(L, noad_prime(n));
                nodelib_push_direct_or_nil(L, noad_supscr(n));
                nodelib_push_direct_or_nil(L, noad_subscr(n));
                nodelib_push_direct_or_nil(L, noad_supprescr(n));
                nodelib_push_direct_or_nil(L, noad_subprescr(n));
                return 5;
        }
    }
    return 0;
}

static int nodelib_direct_setscripts(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case simple_noad:
            case accent_noad:
            case radical_noad:
                noad_prime(n) = nodelib_valid_direct_from_index(L, 2);
                noad_supscr(n) = nodelib_valid_direct_from_index(L, 3);
                noad_subscr(n) = nodelib_valid_direct_from_index(L, 4);
                noad_supprescr(n) = nodelib_valid_direct_from_index(L, 5);
                noad_subprescr(n) = nodelib_valid_direct_from_index(L, 6);
                break;
        }
    }
    return 0;
}

/* node.direct.getsub */
/* node.direct.setsub */

# define getsub_usage atomlike_usage
# define setsub_usage atomlike_usage

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

/* node.direct.getsubpre */
/* node.direct.setsubpre */

# define getsubpre_usage atomlike_usage
# define setsubpre_usage atomlike_usage

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

/* node.direct.getsup */
/* node.direct.setsup */

# define getsup_usage atomlike_usage
# define setsup_usage atomlike_usage

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

/* node.direct.getsuppre */
/* node.direct.setsuppre */

# define getsuppre_usage atomlike_usage
# define setsuppre_usage atomlike_usage

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

/* node.direct.getprime */
/* node.direct.setprime */

# define getprime_usage atomlike_usage
# define setprime_usage atomlike_usage

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

# define getkern_usage (kern_usage | math_usage)
# define setkern_usage getkern_usage

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

# define getdirection_usage (dir_usage | hlist_usage | vlist_usage | par_usage)
# define setdirection_usage getdirection_usage

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

# define getanchors_usage (hlist_usage | vlist_usage | simple_usage | radical_usage | fraction_usage | accent_usage | fence_usage)
# define setanchors_usage getanchors_usage

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
                    lua_pushinteger(L, box_anchor(n) & 0x0FFF);
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

/* node.direct.getoffsets */
/* node.direct.getoffsets */

# define getoffsets_usage (glyph_usage | hlist_usage | vlist_usage | rule_usage)
# define setoffsets_usage getoffsets_usage

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
                lua_pushinteger(L, tex_get_rule_left(n));
                lua_pushinteger(L, tex_get_rule_right(n));
                lua_pushinteger(L, tex_get_rule_on(n));
                lua_pushinteger(L, tex_get_rule_off(n));
                return 6;
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
                    tex_set_rule_left(n,  (halfword) lmt_roundnumber(L, 4));
                }
                if (lua_type(L, 5) == LUA_TNUMBER) {
                    tex_set_rule_right(n, (halfword) lmt_roundnumber(L, 5));
                }
                if (lua_type(L, 6) == LUA_TNUMBER) {
                    tex_set_rule_on(n,  (halfword) lmt_roundnumber(L, 6));
                }
                if (lua_type(L, 7) == LUA_TNUMBER) {
                    tex_set_rule_off(n, (halfword) lmt_roundnumber(L, 7));
                }
                break;
        }
    }
    return 0;
}

/* node.direct.addxoffset */
/* node.direct.addyoffset */

# define addxoffset_usage (glyph_usage | hlist_usage | vlist_usage | rule_usage)
# define addyoffset_usage addxoffset_usage

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

/* node.direct.addmargins */
/* node.direct.addxymargins */

# define addmargins_usage   (glyph_usage | rule_usage)
# define addxymargins_usage glyph_usage

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
                    tex_set_rule_left(n, tex_get_rule_left(n) + (halfword) lmt_roundnumber(L, 2));
                }
                if (lua_type(L, 3) == LUA_TNUMBER) {
                    tex_set_rule_right(n, tex_get_rule_right(n) + (halfword) lmt_roundnumber(L, 3));
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

# define getscale_usage glyph_usage
# define setscale_usage getscale_usage

static int nodelib_direct_getscale(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, glyph_scale(n));
        return 1;
    }
    return 0;
}

static int nodelib_direct_setscale(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        if (lua_type(L, 2) == LUA_TNUMBER) {
            glyph_scale(n) = (halfword) lmt_roundnumber(L, 2);
            if (! glyph_scale(n)) {
                glyph_scale(n) = scaling_factor;
            }
        }
    }
    return 0;
}

/* node.direct.getscales  */
/* node.direct.setscales  */

# define getscales_usage glyph_usage
# define setscales_usage getscales_usage

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
                glyph_scale(n) = scaling_factor;
            }
        }
        if (lua_type(L, 3) == LUA_TNUMBER) {
            glyph_x_scale(n) = (halfword) lmt_roundnumber(L, 3);
            if (! glyph_x_scale(n)) {
                glyph_x_scale(n) = scaling_factor;
            }
        }
        if (lua_type(L, 4) == LUA_TNUMBER) {
            glyph_y_scale(n) = (halfword) lmt_roundnumber(L, 4);
            if (! glyph_y_scale(n)) {
                glyph_y_scale(n) = scaling_factor;
            }
        }
    }
    return 0;
}

/* node.direct.getxscale  */
/* node.direct.getyscale  */

# define getxscale_usage (glue_usage | glyph_usage)
# define getyscale_usage getxscale_usage

static int nodelib_direct_getxscale(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glue_node:
                {
                    switch (node_subtype(n)) {
                        case space_skip_glue:
                        case xspace_skip_glue:
                            if (tex_char_exists(glue_font(n), 0x20)) {
                                halfword prv = node_prev(n);
                                halfword nxt = node_next(n);
                                if (prv) {
                                    if (node_type(prv) == kern_node && font_related_kern(node_subtype(prv))) {
                                        prv = node_prev(prv);
                                    }
                                    if (prv && node_type(prv) == glyph_node && glyph_font(prv) == glue_font(n)) {
                                        n = prv;
                                        goto COMMON;
                                    }
                                }
                                if (nxt) {
                                    if (node_type(nxt) == kern_node && font_related_kern(node_subtype(nxt))) {
                                        prv = node_prev(nxt);
                                    }
                                    if (nxt && node_type(nxt) == glyph_node && glyph_font(nxt) == glue_font(n)) {
                                        n = nxt;
                                        goto COMMON;
                                    }
                                }
                            }
                            break;
                    }
                    break;
                }
            case glyph_node:
              COMMON:
                {
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
        }
    }
  DONE:
    lua_pushinteger(L, 1);
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

/* node.direct.xscaled  */
/* node.direct.yscaled  */

# define xscaled_usage glyph_usage
# define yscaled_usage xscaled_usage

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

/* node.direct.getxyscales */

# define getxyscales_usage glyph_usage
# define setxyscales_usage getxyscales_usage

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

/* node.direct.getslant */
/* node.direct.setslant */

# define getslant_usage glyph_usage
# define setslant_usage getslant_usage

static int nodelib_direct_getslant(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    lua_pushinteger(L, n && node_type(n) == glyph_node ? glyph_slant(n) : 0);
    return 1;
}

static int nodelib_direct_setslant(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        glyph_slant(n) = lmt_opthalfword(L, 2, 0);
    }
    return 0;
}

/* node.direct.getweight */
/* node.direct.setweight */

# define getweight_usage glyph_usage
# define setweight_usage getweight_usage

static int nodelib_direct_getweight(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    halfword b = n && node_type(n) == glyph_node;
    lua_pushinteger(L, b ? glyph_weight(n) : 0);
    lua_pushboolean(L, b ? tex_has_glyph_option(n, glyph_option_weight_less) : 0);
    return 2;
}

static int nodelib_direct_setweight(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        glyph_weight(n) = lmt_opthalfword(L, 2, 0);
        if (lua_type(L, 3) == LUA_TBOOLEAN && lua_toboolean(L, 3)) {
            tex_add_glyph_option(n, glyph_option_weight_less);
        }
    }
    return 0;
}

/*tex
    For the moment we don't provide setters for math discretionaries, mainly because these are
    special and I don't want to waste time on checking and intercepting errors. They are not that
    widely used anyway.
*/

/* node.direct.getdisc */
/* node.direct.setdisc */

# define getdisc_usage (disc_usage | choice_usage)
# define setdisc_usage getdisc_usage

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

/* node.direct.getdiscpart */
/* node.direct.setdiscpart */

# define getdiscpart_usage glyph_node
# define setdiscpart_usage getdiscpart_usage

static int nodelib_direct_getdiscpart(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        lua_pushinteger(L, get_glyph_discpart(n));
        lua_pushinteger(L, get_glyph_discafter(n));
        return 2;
    } else {
        return 0;
    }
}

static int nodelib_direct_setdiscpart(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        set_glyph_discpart(n, luaL_optinteger(L, 2, 0));
        set_glyph_discafter(n, luaL_optinteger(L, 3, 0));
        return 1;
    } else {
        return 0;
    }
}

/* node.direct.getpre */
/* node.direct.getpost */
/* node.direct.getreplace */

# define getpre_usage     (disc_usage | hlist_usage | vlist_usage | choice_usage)
# define getpost_usage    getpre_usage
# define getreplace_usage (disc_usage | choice_usage)

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

/* node.direct.setpre */
/* node.direct.setpost */
/* node.direct.setreplace */

# define setpre_usage     (disc_usage | hlist_usage | vlist_usage)
# define setpost_usage    setpre_usage
# define setreplace_usage (disc_usage)

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

/* split ifs for clearity .. compiler will optimize */

# define getwidth_usage (hlist_usage | vlist_usage | unset_usage | align_record_usage | rule_usage | glue_usage | glue_spec_usage | glyph_usage | kern_usage | math_usage)

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

# define setwidth_usage (hlist_usage | vlist_usage | unset_usage | align_record_usage | rule_usage | glue_usage | glue_spec_usage | kern_usage | math_usage)

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

/* node.direct.getheight */
/* node.direct.setheight */

# define getheight_usage (hlist_usage | vlist_usage | unset_usage | rule_usage | insert_usage | glyph_usage | fence_usage)

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

# define setheight_usage (hlist_usage | vlist_usage | unset_usage | rule_usage | insert_usage | fence_usage)

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

/* node.direct.getdepth */
/* node.direct.setdepth */

# define getdepth_usage getheight_usage

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

# define setdepth_usage setheight_usage

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

/* node.direct.gettotal */
/* node.direct.settotal */

# define gettotal_usage (hlist_usage | vlist_usage | unset_usage | rule_usage | insert_usage | glyph_usage | fence_usage)
# define settotal_usage insert_usage

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

# define getshift_usage (hlist_usage | vlist_usage)
# define setshift_usage getshift_usage

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

/* node.direct.getindex */
/* node.direct.setindex */

# define getindex_usage (hlist_usage | vlist_usage | insert_usage | mark_usage | adjust_usage)
# define setindex_usage getindex_usage

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

/* node.direct.hasgeometry */
/* node.direct.getgeometry */
/* node.direct.setgeometry */

# define hasgeometry_usage (hlist_usage | vlist_usage)
# define getgeometry_usage hasgeometry_usage
# define setgeometry_usage hasgeometry_usage

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
                        lua_pushinteger(L, checked_direction_value(box_dir(n)));
                        return 5;
                    } else {
                        return 1;
                    }
                } else if (lua_toboolean(L, 2)) {
                    lua_pushboolean(L, 0);
                    lua_pushboolean(L, 0);
                    lua_pushboolean(L, 0);
                    lua_pushboolean(L, 0);
                    lua_pushinteger(L, checked_direction_value(box_dir(n)));
                    return 5;
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

/* node.direct.getorientation */
/* node.direct.setorientation */

# define getorientation_usage (hlist_usage |vlist_usage)
# define setorientation_usage getorientation_usage

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

# define setoptions_usage (glyph_usage | disc_usage | glue_usage | rule_usage | math_usage | penalty_usage | simple_usage | radical_usage | fraction_usage | accent_usage | math_char_usage | math_text_char_usage)
# define getoptions_usage setoptions_usage

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
            case glue_node:
                lua_pushinteger(L, glue_options(n));
                return 1;
            case rule_node:
                lua_pushinteger(L, rule_options(n));
                return 1;
            case math_node:
                lua_pushinteger(L, math_options(n));
                return 1;
            case penalty_node:
                lua_pushinteger(L, penalty_options(n));
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
                set_glyph_options(n, lmt_tohalfword(L, 2) & glyph_option_valid);
                break;
            case disc_node:
                set_disc_options(n, lmt_tohalfword(L, 2) & disc_option_valid);
                break;
            case glue_node:
                tex_add_glue_option(n, lmt_tohalfword(L, 2));
                return 1;
            case rule_node:
                set_rule_options(n, lmt_tohalfword(L, 2) & rule_option_valid);
                break;
            case math_node:
                tex_add_math_option(n, lmt_tohalfword(L, 2));
                return 1;
            case penalty_node:
                tex_add_penalty_option(n, lmt_tohalfword(L, 2));
                return 1;
            case simple_noad:
            case radical_noad:
            case fraction_noad:
            case accent_noad:
            case fence_noad:
                noad_options(n) = lmt_tofullword(L, 2);
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

# define getwhd_usage (hlist_usage | vlist_usage | unset_usage | rule_usage | glyph_usage | glue_usage )
# define setwhd_usage getwhd_usage

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

/* node.direct.getcornerkerns */

# define getcornerkerns_usage glyph_usage

static int nodelib_direct_getcornerkerns(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == glyph_node) {
        scaledkrn krn = tex_char_corner_kerns_from_glyph(n);
        lua_pushinteger(L, krn.bl);
        lua_pushinteger(L, krn.br);
        lua_pushinteger(L, krn.tl);
        lua_pushinteger(L, krn.tr);
        return 4;
    }
    return 0;
}

/* node.direct.hasdimensions */

# define hasdimensions_usage (hlist_usage | vlist_usage | unset_usage | rule_usage | glyph_usage | glue_usage)

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

/*tex

    When the height and depth of a box is calculated the |y-offset| is taken into account. In \LUATEX\
    this is different for the height and depth, an historic artifact. However, because that can be
    controlled we now have this helper, mostly for tracing purposes because it listens to the mode
    parameter (and one can emulate other scenarios already).

*/

/* node.direct.getglyphdimensions */

# define getglyphdimensions_usage glyph_usage

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
        lua_pushnumber(L, (double) glyph_slant(n) / 1000);
        lua_pushnumber(L, (double) glyph_weight(n) / 1000);
     // lua_pushinteger(L, glyph_slant(n));
        return 8;
    } else {
        return 0;
    }
}

/* node.direct.getkerndimension */

# define getkerndimension_usage kern_usage

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

/* node.direct.getlistdimensions */

# define getlistdimensions_usage (hlist_usage | vlist_usage)

static int nodelib_direct_getlistdimensions(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            /* when we need it more node types will be handled */
            case hlist_node:
            case vlist_node:
                lua_pushinteger(L, box_width(n));
                lua_pushinteger(L, box_height(n));
                lua_pushinteger(L, box_depth(n));
                lua_pushinteger(L, box_shift_amount(n));
                nodelib_push_direct_or_nil_node_prev(L, box_list(n));
                nodelib_push_direct_or_nil(L, box_except(n)); /* experiment */
                return 6;
        }
    }
    return 0;
}

/* node.direct.getruledimensions */
/* node.direct.setruledimensions */

# define getruledimensions_usage rule_usage
# define setruledimensions_usage rule_usage

static int nodelib_direct_getruledimensions(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == rule_node) {
        if (node_subtype(n) == virtual_rule_subtype) {
            lua_pushinteger(L, rule_virtual_width(n));
            lua_pushinteger(L, rule_virtual_height(n));
            lua_pushinteger(L, rule_virtual_depth(n));
            lua_pushboolean(L, 1);
        } else {
            lua_pushinteger(L, rule_width(n));
            lua_pushinteger(L, rule_height(n));
            lua_pushinteger(L, rule_depth(n));
            lua_pushboolean(L, 0);
        }
        return 4;
    } else {
        return 0;
    }
}

static int nodelib_direct_setruledimensions(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == rule_node) {
        scaled wd = (scaled) lmt_roundnumber(L, 2);
        scaled ht = (scaled) lmt_roundnumber(L, 3);
        scaled dp = (scaled) lmt_roundnumber(L, 4);
        if (node_subtype(n) == virtual_rule_subtype) {
            rule_virtual_width(n) = wd;
            rule_virtual_height(n) = ht;
            rule_virtual_depth(n) = dp;
            rule_width(n) = 0;
            rule_height(n) = 0;
            rule_depth(n) = 0;
        } else {
            rule_width(n) = wd;
            rule_height(n) = ht;
            rule_depth(n) = dp;
        }
        if (lua_type(L, 5) == LUA_TNUMBER) {
            rule_data(n) = (halfword) lmt_roundnumber(L, 5);
        }
    }
    return 0;
}

/* node.direct.getlist */
/* node.direct.setlist */

# define getlist_usage (hlist_usage | vlist_usage | unset_usage | sub_box_usage | sub_mlist_usage | insert_usage | adjust_usage)
# define setlist_usage getlist_usage

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

/* node.direct.getexcept */
/* node.direct.setexcept */

# define getexcept_usage (hlist_usage | vlist_usage | unset_usage)
# define setexcept_usage getexcept_usage

static int nodelib_direct_getexcept(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
            default:
                nodelib_push_direct_or_nil(L, box_except(n));
                lua_pushinteger(L, box_exdepth(n));
                return 2;
        }
    }
    lua_pushnil(L);
    lua_pushnil(L);
    return 2;
}

static int nodelib_direct_setexcept(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
            case unset_node:
                box_except(n) = nodelib_valid_direct_from_index(L, 2);
                box_exdepth(n) = lmt_optinteger(L, 3, 0);
                break;
        }
    }
    return 0;
}

/* node.direct.getleader */
/* node.direct.setleader */

# define getleader_usage glue_usage
# define setleader_usage getleader_usage

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

# define getdata_usage (glyph_usage | rule_usage | glue_usage | boundary_usage | attribute_usage | mark_usage)
# define setdata_usage getdata_usage

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
                lua_pushinteger(L, boundary_reserved(n));
                return 2;
            case attribute_node:
                switch (node_subtype(n)) {
                    case attribute_list_subtype:
                        nodelib_push_attribute_data(L, n);
                        return 1;
                    case attribute_value_subtype:
                        /*tex Only used for introspection so it's okay to return 2 values. */
                        lua_pushinteger(L, attribute_index(n));
                        lua_pushinteger(L, attribute_value(n));
                        return 2;
                    default:
                        /*tex We just ignore. */
                        break;
                }
                break;
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
                boundary_reserved(n) = lmt_opthalfword(L, 3, 0);
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

/* node.direct.get[left|right|top|bottom|]delimiter */
/* node.direct.set[left|right|top|bottom|]delimiter */

# define getdelimiter_usage       (fraction_usage | fence_usage | radical_usage | accent_usage)
# define setdelimiter_usage       getdelimiter_usage

# define getleftdelimiter_usage   (fraction_usage | radical_usage)
# define setleftdelimiter_usage   getleftdelimiter_usage

# define getrightdelimiter_usage  getleftdelimiter_usage
# define setrightdelimiter_usage  setleftdelimiter_usage

# define gettopdelimiter_usage    (fence_usage | radical_usage)
# define settopdelimiter_usage    gettopdelimiter_usage

# define getbottomdelimiter_usage gettopdelimiter_usage
# define setbottomdelimiter_usage settopdelimiter_usage

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

static int nodelib_direct_gettopdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case radical_noad:
                nodelib_push_direct_or_nil(L, radical_top_delimiter(n));
                return 1;
            case fence_noad:
                nodelib_push_direct_or_nil(L, fence_delimiter_top(n));
                return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int nodelib_direct_getbottomdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case radical_noad:
                nodelib_push_direct_or_nil(L, radical_bottom_delimiter(n));
                return 1;
            case fence_noad:
                nodelib_push_direct_or_nil(L, fence_delimiter_bottom(n));
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
                nodelib_push_direct_or_node(L, n, fence_delimiter(n));
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

static int nodelib_direct_settopdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case radical_noad:
                radical_top_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                return 1;
            case fence_noad:
                fence_delimiter_top(n) = nodelib_valid_direct_from_index(L, 2);
                return 1;
        }
    }
    return 0;
}

static int nodelib_direct_setbottomdelimiter(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case radical_noad:
                radical_bottom_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
                return 1;
            case fence_noad:
                fence_delimiter_bottom(n) = nodelib_valid_direct_from_index(L, 2);
                return 1;
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
                fence_delimiter(n) = nodelib_valid_direct_from_index(L, 2);
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

# define gettop_usage    (accent_usage | fence_usage)
# define settop_usage    gettop_usage
# define getbottom_usage gettop_usage
# define setbottom_usage getbottom_usage

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

# define getdenominator_usage fraction_usage
# define setdenominator_usage fraction_usage
# define getnumerator_usage   fraction_usage
# define setnumerator_usage   fraction_usage

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

# define getdegree_usage radical_usage
# define setdegree_usage getdegree_usage

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

# define getchoice_usage choice_usage
# define setchoice_usage getchoice_usage

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

/* node.direct.getglyphdata */
/* node.direct.setglyphdata */

# define getglyphdata_usage glyph_usage
# define setglyphdata_usage getglyphdata_usage

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

# define getnext_usage common_usage
# define setnext_usage common_usage

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

/* node.direct.getprev */
/* node.direct.setprev */

# define getprev_usage common_usage
# define setprev_usage common_usage

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

/* node.direct.getboth */
/* node.direct.setboth */

# define getboth_usage common_usage
# define setboth_usage common_usage

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

/* node.direct.isnext */
/* node.direct.isprev */
/* node.direct.isboth */

# define isnext_usage common_usage
# define isprev_usage common_usage
# define isboth_usage common_usage

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

/* node.direct.setlink  */

/*
    a b b nil c d         : prev-a-b-c-d-next
    nil a b b nil c d nil : nil-a-b-c-d-nil
*/

# define setlink_usage common_usage

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
        switch (lua_type(L, i)) {
            case LUA_TNUMBER:
                {
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
                }
                break;
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, i)) {
                    /*tex Just skip this one. */
                    break;
                } else {
                    /* fall through */
                }
            default:
                if (t) {
                    /* safeguard: a nil in the list can be meant as end so we nil the next of tail */
                    node_next(t) = null;
                } else {
                    /* we just ignore nil nodes and have no tail yet */
                }
        }
    }
    nodelib_push_direct_or_nil(L, h);
    return 1;
}

/* node.direct.setsplit */

# define setsplit_usage common_usage

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

/* node.direct.validpar */
/* node.direct.patchparshape */
/* node.direct.getparstate */

# define validpar_usage      par_usage
# define patchparshape_usage par_usage
# define getparstate_usage   par_usage

static halfword nodelib_direct_aux_validpar(lua_State *L, int index)
{
    halfword p = nodelib_valid_direct_from_index(L, index);
    if (! p) {
        p = tex_find_par_par(cur_list.head);
    } else if (node_type(p) != par_node) {
        while (node_prev(p)) {
            p = node_prev(p);
        }
    }
    return (p && node_type(p) == par_node) ? p : null;
}

static int nodelib_direct_patchparshape(lua_State *L) // maybe also patchparstate
{
    halfword par = nodelib_direct_aux_validpar(L, 1);
    if (par) {
        halfword shape = par_par_shape(par);
        halfword options = shape ? specification_options(shape) : 0;
        if (shape) {
            tex_flush_node(shape);
            par_par_shape(par) = null;
        }
        if (lua_type(L, 2) == LUA_TTABLE) {
            halfword size = (halfword) lua_rawlen(L, 2);
            shape = tex_new_specification_node(size, par_shape_code, options);
            par_par_shape(par) = shape;
            for (int i = 1; i <= size; i++) {
                if (lua_rawgeti(L, 2, i) == LUA_TTABLE) {
                    if (lua_rawgeti(L, -1, 1) == LUA_TNUMBER) {
                        scaled indent = lmt_roundnumber(L, -1);
                        if (lua_rawgeti(L, -2, 2) == LUA_TNUMBER) {
                            scaled width = lmt_roundnumber(L, -1);
                            tex_set_specification_indent(shape, i, indent);
                            tex_set_specification_width(shape, i, width);
                        }
                        lua_pop(L, 1);
                    }
                    lua_pop(L, 1);
                }
                lua_pop(L, 1);
            }
        }
    }
    return 0;
}

static int nodelib_direct_getparstate(lua_State *L)
{
    halfword p = nodelib_direct_aux_validpar(L, 1);
    if (p) {
        int limited = lua_toboolean(L, 2);
        lua_createtable(L, 0, 24);
        switch (node_subtype(p)) {
            case vmode_par_par_subtype:
            case hmode_par_par_subtype:
                {
                    /* todo: optional: all skip components */
                    lua_push_integer_at_key(L, hsize,                              tex_get_par_par(p, par_hsize_code));
                    lua_push_integer_at_key(L, leftskip,               glue_amount(tex_get_par_par(p, par_left_skip_code)));
                    lua_push_integer_at_key(L, rightskip,              glue_amount(tex_get_par_par(p, par_right_skip_code)));
                    lua_push_integer_at_key(L, hangindent,                         tex_get_par_par(p, par_hang_indent_code));
                    lua_push_integer_at_key(L, hangafter,                          tex_get_par_par(p, par_hang_after_code));
                    lua_push_integer_at_key(L, parindent,                          tex_get_par_par(p, par_par_indent_code));
                    lua_push_integer_at_key(L, prevgraf,                           par_prev_graf(p));
                    if (! limited) {
                        lua_push_integer_at_key(L, parfillleftskip,    glue_amount(tex_get_par_par(p, par_par_fill_left_skip_code)));
                        lua_push_integer_at_key(L, parfillskip,        glue_amount(tex_get_par_par(p, par_par_fill_right_skip_code)));
                        lua_push_integer_at_key(L, parinitleftskip,    glue_amount(tex_get_par_par(p, par_par_init_left_skip_code)));
                        lua_push_integer_at_key(L, parinitrightskip,   glue_amount(tex_get_par_par(p, par_par_init_right_skip_code)));
                        lua_push_integer_at_key(L, emergencyleftskip,  glue_amount(tex_get_par_par(p, emergency_left_skip_code)));
                        lua_push_integer_at_key(L, emergencyrightskip, glue_amount(tex_get_par_par(p, emergency_right_skip_code)));
                        lua_push_integer_at_key(L, adjustspacing,                  tex_get_par_par(p, par_adjust_spacing_code));
                        lua_push_integer_at_key(L, protrudechars,                  tex_get_par_par(p, par_protrude_chars_code));
                        lua_push_integer_at_key(L, pretolerance,                   tex_get_par_par(p, par_pre_tolerance_code));
                        lua_push_integer_at_key(L, tolerance,                      tex_get_par_par(p, par_tolerance_code));
                        lua_push_integer_at_key(L, emergencystretch,               tex_get_par_par(p, par_emergency_stretch_code));
                        lua_push_integer_at_key(L, looseness,                      tex_get_par_par(p, par_looseness_code));
                        lua_push_integer_at_key(L, lastlinefit,                    tex_get_par_par(p, par_last_line_fit_code));
                        lua_push_integer_at_key(L, linepenalty,                    tex_get_par_par(p, par_line_penalty_code));
                        lua_push_integer_at_key(L, interlinepenalty,               tex_get_par_par(p, par_inter_line_penalty_code));
                        lua_push_integer_at_key(L, clubpenalty,                    tex_get_par_par(p, par_club_penalty_code));
                        lua_push_integer_at_key(L, widowpenalty,                   tex_get_par_par(p, par_widow_penalty_code));
                        lua_push_integer_at_key(L, displaywidowpenalty,            tex_get_par_par(p, par_display_widow_penalty_code));
                        lua_push_integer_at_key(L, lefttwindemerits,               tex_get_par_par(p, par_left_twin_demerits_code));
                        lua_push_integer_at_key(L, righttwindemerits,              tex_get_par_par(p, par_right_twin_demerits_code));
                        lua_push_integer_at_key(L, singlelinepenalty,              tex_get_par_par(p, par_single_line_penalty_code));
                        lua_push_integer_at_key(L, hyphenpenalty,                  tex_get_par_par(p, par_hyphen_penalty_code));
                        lua_push_integer_at_key(L, exhyphenpenalty,                tex_get_par_par(p, par_ex_hyphen_penalty_code));
                        lua_push_integer_at_key(L, brokenpenalty,                  tex_get_par_par(p, par_broken_penalty_code));
                        lua_push_integer_at_key(L, adjdemerits,                    tex_get_par_par(p, par_adj_demerits_code));
                        lua_push_integer_at_key(L, doublehyphendemerits,           tex_get_par_par(p, par_double_hyphen_demerits_code));
                        lua_push_integer_at_key(L, finalhyphendemerits,            tex_get_par_par(p, par_final_hyphen_demerits_code));
                        lua_push_integer_at_key(L, baselineskip,       glue_amount(tex_get_par_par(p, par_baseline_skip_code)));
                        lua_push_integer_at_key(L, lineskip,           glue_amount(tex_get_par_par(p, par_line_skip_code)));
                        lua_push_integer_at_key(L, lineskiplimit,                  tex_get_par_par(p, par_line_skip_limit_code));
                        lua_push_integer_at_key(L, shapingpenaltiesmode,           tex_get_par_par(p, par_shaping_penalties_mode_code));
                        lua_push_integer_at_key(L, shapingpenalty,                 tex_get_par_par(p, par_shaping_penalty_code));
                        lua_push_integer_at_key(L, emergencyextrastretch,          tex_get_par_par(p, par_emergency_extra_stretch_code));
                    }
                    lua_push_specification_at_key(L, parshape,                     tex_get_par_par(p, par_par_shape_code));
                    if (! limited) {
                        lua_push_specification_at_key(L, interlinepenalties,       tex_get_par_par(p, par_inter_line_penalties_code));
                        lua_push_specification_at_key(L, clubpenalties,            tex_get_par_par(p, par_club_penalties_code));
                        lua_push_specification_at_key(L, widowpenalties,           tex_get_par_par(p, par_widow_penalties_code));
                        lua_push_specification_at_key(L, displaywidowpenalties,    tex_get_par_par(p, par_display_widow_penalties_code));
                        lua_push_specification_at_key(L, orphanpenalties,          tex_get_par_par(p, par_orphan_penalties_code));
                        lua_push_specification_at_key(L, toddlerpenalties,         tex_get_par_par(p, par_toddler_penalties_code));
                        lua_push_specification_at_key(L, parpasses,                tex_get_par_par(p, par_par_passes_code));
                        lua_push_specification_at_key(L, linebreakchecks,          tex_get_par_par(p, par_line_break_checks_code));
                        lua_push_specification_at_key(L, adjacentdemerits,         tex_get_par_par(p, par_adjacent_demerits_code));
                        lua_push_specification_at_key(L, fitnessclasses,           tex_get_par_par(p, par_fitness_classes_code));
                    }
                    break;
                }
         // case local_box_par_subtype:
         // case penalty_par_subtype:
         // case math_par_subtype:
        }
        return 1;
    } else {
        return 0;
    }
}

/* node.type (converts id numbers to type names) */

# define type_usage common_usage

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
         // if (! tex_nodetype_is_visible(i)) {
         //     i = unknown_node;
         // }
            break;
        case LUA_TSTRING:
            i = nodelib_aux_get_node_type_id_from_name(L, 1, lmt_interface.node_data, 0);
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

# define new_usage common_usage

static int nodelib_direct_new(lua_State *L)
{
    lua_pushinteger(L, nodelib_new_node(L));
    return 1;
}

/* node.size (kind of private, needed for manuals) */

# define size_usage common_usage

static halfword nodelib_shared_size(lua_State *L)
{
    quarterword i = unknown_node;
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            i = lmt_toquarterword(L, 1);
            break;
        case LUA_TSTRING:
            i = nodelib_aux_get_node_type_id_from_name(L, 1, lmt_interface.node_data, 1);
            break;
    }
    if (tex_nodetype_is_valid(i)) {
        lua_pushinteger(L, lmt_interface.node_data[i].size * 8);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_newtextglyph(lua_State* L)
{
    halfword glyph = tex_new_text_glyph(lmt_tohalfword(L, 1), lmt_tohalfword(L, 2));
    nodelib_aux_setattributelist(L, glyph, 3);
    lua_pushinteger(L, glyph);
    return 1;
}

# define newmathglyph_usage        common_usage
# define newtextglyph_usage        common_usage
# define newcontinuationatom_usage common_usage

static int nodelib_direct_newmathglyph(lua_State* L)
{
    /*tex For now we don't set a properties, group and/or index here. */
    halfword glyph = tex_new_math_glyph(lmt_tohalfword(L, 1), lmt_tohalfword(L, 2));
    nodelib_aux_setattributelist(L, glyph, 3);
    lua_pushinteger(L, glyph);
    return 1;
}

static int nodelib_direct_newcontinuationatom(lua_State* L)
{
    if (lua_type(L, 1) == LUA_TBOOLEAN) {
        halfword n = tex_new_math_continuation_atom(null, null);
        nodelib_aux_setattributelist(L, n, 2);
        lua_pushinteger(L, n);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            n = tex_new_math_continuation_atom(n, null);
        }
        return 0;
    }
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

# define free_usage common_usage

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

/* node.direct.flushnode */

# define flushnode_usage common_usage

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

/* node.direct.flushlist */

# define flushlist_usage common_usage

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

# define remove_usage common_usage

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
            nodelib_push_direct_or_nil(L, head);
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

# define removefromlist_usage common_usage

static int nodelib_direct_removefromlist(lua_State *L)
{
    halfword head = nodelib_valid_direct_from_index(L, 1);
    int count = 0;
    if (head) {
        halfword id = lmt_tohalfword(L, 2);
        halfword subtype = lmt_opthalfword(L, 3, -1);
        halfword current = head;
        while (current) {
            halfword next = node_next(current);
            if (node_type(current) == id && (subtype < 0 || node_subtype(current) == subtype)) {
                if (current == head) {
                    head = next;
                    node_prev(next) = null;
                } else {
                    tex_try_couple_nodes(node_prev(current), next);
                }
                tex_flush_node(current);
                ++count;
            }
            current = next;
        }
    }
    nodelib_push_direct_or_nil(L, head);
    lua_push_integer(L, count);
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

# define insertbefore_usage common_usage

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
            tex_couple_nodes(n, current); /* nice but incompatible: tex_couple_nodes(tail_of_list(n),current) */
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

# define insertafter_usage common_usage

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

# define appendaftertail_usage   common_usage
# define prependbeforehead_usage common_usage

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

# define copylist_usage common_usage

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

# define show_usage common_usage

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

# define showlist_usage common_usage

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

# define serialized_usage common_usage

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

# define copy_usage common_usage

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

# define copyonly_usage common_usage

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

# define write_usage common_usage

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

# define lastnode_usage common_usage

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

# define hpack_usage common_usage

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
    p = tex_hpack(n, w, m, d, holding_none_option, box_limit_none);
    lua_pushinteger(L, p);
    lua_pushinteger(L, lmt_packaging_state.last_badness);
    lua_pushinteger(L, lmt_packaging_state.last_overshoot);
    return 3;
}

# define repack_usage common_usage

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

# define freeze_usage common_usage

static int nodelib_direct_freeze(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
            case vlist_node:
                 tex_freeze(n, lua_toboolean(L, 2), lua_toboolean(L, 3) ? node_type(n) : -1, lmt_opthalfword(L, 4, 0));
                 break;
        }
    }
    return 0;
}

/* node.direct.verticalbreak */
/* node.direct.vpack */

# define verticalbreak_usage common_usage
# define vpack_usage         common_usage

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
    p = tex_vpack(n, w, m, max_dimension, d, holding_none_option, NULL);
    lua_pushinteger(L, p);
    lua_pushinteger(L, lmt_packaging_state.last_badness);
    return 2;
}

/* node.direct.dimensions */
/* node.direct.rangedimensions */
/* node.direct.naturalwidth */

/* mult sign order firstnode          verticalbool */
/* mult sign order firstnode lastnode verticalbool */
/*                 firstnode          verticalbool */
/*                 firstnode lastnode verticalbool */

# define dimensions_usage common_usage

static int nodelib_direct_dimensions(lua_State *L)
{
    int top = lua_gettop(L);
    if (top > 0) {
        scaledwhd siz = { .wd = 0, .ht = 0, .dp = 0, .ns = 0 };
        glueratio g_mult = normal_glue_multiplier;
        int vertical = 0;
        int g_sign = normal_glue_sign;
        int g_order = normal_glue_order;
        int i = 1;
        halfword n = null;
        halfword p = null;
        if (top > 3) {
            g_mult = (glueratio) lua_tonumber(L, i++);
            g_sign = tex_checked_glue_sign(lmt_tohalfword(L, i++));
            g_order = tex_checked_glue_order(lmt_tohalfword(L, i++));
        }
        n = nodelib_valid_direct_from_index(L, i++);
        if (lua_type(L, i) == LUA_TBOOLEAN) {
            vertical = lua_toboolean(L, i++);
        } else {
            p = nodelib_valid_direct_from_index(L, i++);
            vertical = lua_toboolean(L, i);
        }
        if (n) {
            siz = (vertical ? tex_natural_vsizes : tex_natural_hsizes)(n, p, g_mult, g_sign, g_order);
        }
        lua_pushinteger(L, siz.wd);
        lua_pushinteger(L, siz.ht);
        lua_pushinteger(L, siz.dp);
        return 3;
    } else {
        return luaL_error(L, "missing argument to 'dimensions' (direct node expected)");
    }
}

/* parentnode firstnode lastnode vertical */
/* parentnode firstnode          vertical */
/* parentnode firstnode lastnode vertical nsizetoo */
/* parentnode firstnode          vertical nsizetoo */

# define rangedimensions_usage common_usage

static int nodelib_direct_rangedimensions(lua_State *L)
{
    int top = lua_gettop(L);
    if (top > 1) {
        scaledwhd siz = { .wd = 0, .ht = 0, .dp = 0, .ns = 0 };
        int vertical = 0;
        int nsizetoo = 0;
        int index = 1;
        halfword parent = nodelib_valid_direct_from_index(L, index++);
        halfword first = nodelib_valid_direct_from_index(L, index++);
        halfword last = first;
        if (lua_type(L, index) == LUA_TBOOLEAN) {
            vertical = lua_toboolean(L, index++);
        } else {
            last = nodelib_valid_direct_from_index(L, index++);
            vertical = lua_toboolean(L, index++);
        }
        nsizetoo = lua_toboolean(L, index);
        if (parent && first) {
            siz = (vertical ? tex_natural_vsizes : tex_natural_hsizes)(first, last, (glueratio) box_glue_set(parent), box_glue_sign(parent), box_glue_order(parent));
        }
        lua_pushinteger(L, siz.wd);
        lua_pushinteger(L, siz.ht);
        lua_pushinteger(L, siz.dp);
        if (nsizetoo) {
            lua_pushinteger(L, siz.ns);
            return 4;
        } else {
            return 3;
        }
    } else {
        return luaL_error(L, "missing argument to 'rangedimensions' (2 or more direct nodes expected)");
    }
}

/* parentnode firstnode [last] */

# define naturalwidth_usage common_usage

static int nodelib_direct_naturalwidth(lua_State *L)
{
    int top = lua_gettop(L);
    if (top > 1) {
        scaled wd = 0;
        halfword parent = nodelib_valid_direct_from_index(L, 1);
        halfword first = nodelib_valid_direct_from_index(L, 2);
        halfword last = nodelib_valid_direct_from_index(L, 3);
        if (parent && first) {
            wd = tex_natural_width(first, last, (glueratio) box_glue_set(parent), box_glue_sign(parent), box_glue_order(parent));
        }
        lua_pushinteger(L, wd);
        return 1;
    } else {
        return luaL_error(L, "missing argument to 'naturalwidth' (2 or more direct nodes expected)");
    }
}

# define naturalhsize_usage common_usage

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

# define mlisttohlist_usage common_usage

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

# define hasfield_usage common_usage

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

# define fields_usage common_usage

static int nodelib_shared_fields(lua_State *L)
{
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
        int offset = 0;
        lua_push_key(id);
        lua_rawseti(L, -2, offset++);
        if (tex_nodetype_has_subtype(t)) {
            lua_push_key(subtype);
            lua_rawseti(L, -2, offset++);
        }
        lua_push_key(next);
        lua_rawseti(L, -2, offset++);
        if (tex_nodetype_has_prev(t)) {
            lua_push_key(prev);
            lua_rawseti(L, -2, offset++);
        }
        if (fields) {
            for (lua_Integer i = 0; fields[i].lua != 0; i++) {
             // lua_push_key_by_index(L, fields[i].lua);
                lua_rawgeti(L, LUA_REGISTRYINDEX, fields[i].lua);
                lua_rawseti(L, -2, offset++);
            }
        }
    }
    return 1;
}

/* These should move to texlib ... which might happen.  */

// static int nodelib_shared_values(lua_State *L)
// {
//     if (lua_type(L, 1) == LUA_TSTRING) {
//         /*
//             delimiter options (bit set)
//             delimiter modes   (bit set)
//         */
//         const char *s = lua_tostring(L, 1);
//         if (lua_key_eq(s, glue) || lua_key_eq(s, fill)) {
//             return lmt_push_info_values(L, lmt_interface.node_fill_values);
//         } else if (lua_key_eq(s, dir)) {
//             /* moved to lmttexlib */
//             return lmt_push_info_values(L, lmt_interface.direction_values);
//         } else if (lua_key_eq(s, math)) {
//             /* moved to lmttexlib */
//             return lmt_push_info_keys(L, lmt_interface.math_parameter_values);
//         } else if (lua_key_eq(s, style)) {
//             /* moved to lmttexlib */
//             return lmt_push_info_values(L, lmt_interface.math_style_values);
//         } else if (lua_key_eq(s, page)) {
//             /*tex These are never used, whatsit related. */
//             return lmt_push_info_values(L, lmt_interface.page_contribute_values);
//         }
//     }
//     lua_pushnil(L);
//     return 1;
// }

static int nodelib_shared_subtypes(lua_State *L)
{
    value_info *subtypes = NULL;
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L,1);
                /* */
                if  (lua_key_eq(s, list)) {
                    subtypes = lmt_interface.node_data[hlist_node].subtypes;
                } else {
                    for (int id = first_nodetype; id <= last_nodetype; id++) {
                        if (lmt_interface.node_data[id].name && ! strcmp(lmt_interface.node_data[id].name, s)) {
                            subtypes = lmt_interface.node_data[id].subtypes;
                            break;
                        }
                    }
                }
                /* no need for speed for more popular types: */
                /*
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
                     ||  lua_key_eq(s, vlist))     subtypes = lmt_interface.node_data[hlist_node]    .subtypes;
                else if (lua_key_eq(s, adjust))    subtypes = lmt_interface.node_data[adjust_node]   .subtypes;
                else if (lua_key_eq(s, disc))      subtypes = lmt_interface.node_data[disc_node]     .subtypes;
                else if (lua_key_eq(s, math))      subtypes = lmt_interface.node_data[math_node]     .subtypes;
                else if (lua_key_eq(s, noad))      subtypes = lmt_interface.node_data[simple_noad]   .subtypes;
                else if (lua_key_eq(s, radical))   subtypes = lmt_interface.node_data[radical_noad]  .subtypes;
                else if (lua_key_eq(s, accent))    subtypes = lmt_interface.node_data[accent_noad]   .subtypes;
                else if (lua_key_eq(s, fence))     subtypes = lmt_interface.node_data[fence_noad]    .subtypes;
                else if (lua_key_eq(s, fraction))  subtypes = lmt_interface.node_data[fraction_noad] .subtypes;
                else if (lua_key_eq(s, choice))    subtypes = lmt_interface.node_data[choice_node]   .subtypes;
                else if (lua_key_eq(s, par))       subtypes = lmt_interface.node_data[par_node]      .subtypes;
                else if (lua_key_eq(s, attribute)) subtypes = lmt_interface.node_data[attribute_node].subtypes;
                */
            }
            break;
        case LUA_TNUMBER:
            {
                int id = lua_tointeger(L, 1);
                if (id >= first_nodetype && id <= last_nodetype) {
                    subtypes = lmt_interface.node_data[id].subtypes;
                }
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

# define slide_usage common_usage

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

# define tail_usage common_usage

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

/* node.direct.beginofmath */
/* node.direct.endofmath */

# define beginofmath_usage common_usage
# define endofmath_usage   common_usage

static int nodelib_direct_beginofmath(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        if (node_type(n) == math_node && (node_subtype(n) == begin_inline_math || node_subtype(n) == begin_broken_math)) {
            lua_pushinteger(L, n);
            return 1;
        } else {
            int level = 1;
            while (node_next(n)) {
                n = node_next(n);
                if (n && node_type(n) == math_node) {
                    /*tex We can't really have nested math but we can be at the end so: */
                    switch (node_subtype(n)) {
                        case begin_inline_math:
                        case begin_broken_math:
                            ++level;
                            if (level > 0) {
                                lua_pushinteger(L, n);
                                return 1;
                            } else {
                                break;
                            }
                        case end_inline_math:
                        case end_broken_math:
                            --level;
                            break;
                    }
                }
            }
        }
    }
    return 0;
}

static int nodelib_direct_endofmath(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        if (node_type(n) == math_node && (node_subtype(n) == end_inline_math || node_subtype(n) == end_broken_math)) {
            lua_pushinteger(L, n);
            return 1;
        } else {
            int level = 1;
            while (node_next(n)) {
                n = node_next(n);
                if (n && node_type(n) == math_node) {
                    /*tex We can't really have nested math but we can be at a begin so: */
                    switch (node_subtype(n)) {
                        case begin_inline_math:
                        case begin_broken_math:
                            ++level;
                            break;
                        case end_inline_math:
                        case end_broken_math:
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

# define hasattribute_usage common_usage

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

# define findattributerange_usage common_usage

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

/* maybe: getsplitattribute(n,a,24,8) => (v & ~(~0 << 24)) (v & ~(~0 << 8)) */

# define getattribute_usage  common_usage
# define getattributes_usage common_usage

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

# define setattribute_usage  common_usage
# define setattributes_usage common_usage

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

# define patchattributes_usage common_usage

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

/* firstnode attributeid [nodetype] */

# define findattribute_usage common_usage

static int nodelib_direct_findattribute(lua_State *L) /* returns attr value and node */
{
    halfword c = nodelib_valid_direct_from_index(L, 1);
    if (c) {
        halfword i = lmt_tohalfword(L, 2);
        halfword t = lmt_optinteger(L, 3, -1);
        halfword a = null;
        while (c) {
            if ((t < 0 || node_type(c) == t) && tex_nodetype_has_attributes(node_type(c))) {
                /* We skip if the previous value is the same and didn't match. */
                halfword p = node_attr(c);
                if (p && a != p) {
                    a = p;
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

# define unsetattribute_usage  common_usage
# define unsetattributes_usage common_usage

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

/* node.setattribute */
/* node.unsetattribute */

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

# define getglue_usage    (glue_usage | glue_spec_usage | hlist_usage | vlist_usage | unset_usage | math_usage)
# define setglue_usage    getglue_usage
# define iszeroglue_usage getglue_usage

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

# define startofpar_usage common_usage

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
/* node.direct.traverseid */
/* node.direct.traversechar */
/* node.direct.traverseglyph */
/* node.direct.traverselist */
/* node.direct.traverseleader */
/* node.direct.traverseitalic */
/* node.direct.traversecontent */

# define traverse_usage        common_usage
# define traverseid_usage      common_usage
# define traversechar_usage    common_usage
# define traverseglyph_usage   common_usage
# define traverselist_usage    common_usage
# define traverseleader_usage  common_usage
# define traverseitalic_usage  common_usage
# define traversecontent_usage common_usage

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

/* maybe a variant that checks for an attribute  */

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

/*tex */

static int nodelib_direct_aux_next_italic(lua_State *L)
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
    while (t && ! (node_type(t) == kern_node && (node_subtype(t) == italic_kern_subtype || node_subtype(t) == left_correction_kern_subtype || node_subtype(t) == right_correction_kern_subtype))) {
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

static int nodelib_direct_traverseitalic(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, nodelib_aux_nil, 0);
        return 1;
    } else {
        halfword n = nodelib_valid_direct_from_index(L, 1);
        if (n) {
            lua_pushcclosure(L, nodelib_direct_aux_next_italic, 0);
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, nodelib_aux_nil, 0);
            return 1;
        }
    }
}

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
/* node.traverseid */
/* node.traversechar */
/* node.traverseglyph */
/* node.traverselist */

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

# define length_usage common_usage
# define count_usage  common_usage

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

static inline int nodelib_getattribute_value(lua_State *L, halfword n, int index)
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

static inline void nodelib_setattribute_value(lua_State *L, halfword n, int kindex, int vindex)
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

typedef enum lua_field_errors {
    lua_no_field_error,
    lua_set_field_error,
    lua_get_field_error,
} lua_field_errors ;

static int last_field_error   = lua_no_field_error;
static int ignore_field_error = 0;

static int nodelib_common_getfield(lua_State *L, int direct, halfword n)
{
    last_field_error = lua_no_field_error;
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
                         goto CANTGET;
                    }
                } else if (lua_key_eq(s, prev)) {
                    if (tex_nodetype_has_prev(t)) {
                        nodelib_push_direct_or_node(L, direct, node_prev(n));
                    } else {
                         goto CANTGET;
                    }
                } else if (lua_key_eq(s, attr)) {
                    if (tex_nodetype_has_attributes(t)) {
                        nodelib_push_direct_or_node(L, direct, node_attr(n));
                    } else {
                         goto CANTGET;
                    }
                } else if (lua_key_eq(s, subtype)) {
                    if (tex_nodetype_has_subtype(t)) {
                        lua_pushinteger(L, node_subtype(n));
                    } else {
                         goto CANTGET;
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
                            } else if (lua_key_eq(s, slant)) {
                                lua_pushinteger(L, glyph_slant(n));
                            } else if (lua_key_eq(s, weight)) {
                                lua_pushinteger(L, glyph_weight(n));
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
                            } else if (lua_key_eq(s, control)) {
                                lua_pushinteger(L, get_glyph_control(n));
                            } else {
                                goto CANTGET;
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
                            } else if (lua_key_eq(s, except)) {
                                nodelib_push_direct_or_node(L, direct, box_except(n));
                            } else {
                                goto CANTGET;
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
                                goto CANTGET;
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
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, glue_options(n));
                            } else {
                                goto CANTGET;
                            }
                            break;
                        case kern_node:
                            if (lua_key_eq(s, kern)) {
                                lua_pushinteger(L, kern_amount(n));
                            } else if (lua_key_eq(s, expansion)) {
                                lua_pushinteger(L, kern_expansion(n));
                            } else {
                                goto CANTGET;
                            }
                            break;
                        case penalty_node:
                            if (lua_key_eq(s, penalty)) {
                                lua_pushinteger(L, penalty_amount(n));
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, penalty_options(n));
                            } else {
                                goto CANTGET;
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
                                lua_pushinteger(L, rule_x_offset(n));
                            } else if (lua_key_eq(s, yoffset)) {
                                lua_pushinteger(L, rule_y_offset(n));
                            } else if (lua_key_eq(s, left)) {
                                lua_pushinteger(L, tex_get_rule_left(n));
                            } else if (lua_key_eq(s, right)) {
                                lua_pushinteger(L, tex_get_rule_right(n));
                            } else if (lua_key_eq(s, on)) {
                                lua_pushinteger(L, tex_get_rule_on(n));
                            } else if (lua_key_eq(s, off)) {
                                lua_pushinteger(L, tex_get_rule_off(n));
                            } else if (lua_key_eq(s, data)) {
                                lua_pushinteger(L, rule_data(n));
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, rule_options(n));
                            } else if (lua_key_eq(s, font)) {
                                lua_pushinteger(L, tex_get_rule_font(n, text_style));
                            } else if (lua_key_eq(s, fam)) {
                                lua_pushinteger(L, tex_get_rule_font(n, text_style));
                            } else if (lua_key_eq(s, char)) {
                                lua_pushinteger(L, rule_strut_character(n));
                            } else {
                                goto CANTGET;
                            }
                            break;
                        case dir_node:
                            if (lua_key_eq(s, direction)) {
                                lua_pushinteger(L, dir_direction(n));
                            } else if (lua_key_eq(s, level)) {
                                lua_pushinteger(L, dir_level(n));
                            } else {
                                goto CANTGET;
                            }
                            break;
                        case whatsit_node:
                            goto CANTGET;
                        case par_node:
                            /* not all of them here */
                            if (lua_key_eq(s, interlinepenalty)) {
                                lua_pushinteger(L, tex_get_local_interline_penalty(n));
                            } else if (lua_key_eq(s, brokenpenalty)) {
                                lua_pushinteger(L, tex_get_local_broken_penalty(n));
                            } else if (lua_key_eq(s, tolerance)) {
                                lua_pushinteger(L, tex_get_local_tolerance(n));
                            } else if (lua_key_eq(s, pretolerance)) {
                                lua_pushinteger(L, tex_get_local_pre_tolerance(n));
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
                                goto CANTGET;
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
                                goto CANTGET;
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
                                goto CANTGET;
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
                                goto CANTGET;
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
                            } else if (lua_key_eq(s, options)) {
                                lua_pushinteger(L, math_options(n));
                            } else {
                                goto CANTGET;
                            }
                            break;
                        case style_node:
                            if (lua_key_eq(s, style)) {
                                lmt_push_math_style_name(L, style_style(n));
                            } else {
                                goto CANTGET;
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
                                goto CANTGET;
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
                                         goto CANTGET;
                                    case radical_noad:
                                        if (lua_key_eq(s, left) || lua_key_eq(s, delimiter)) {
                                            nodelib_push_direct_or_node(L, direct, radical_left_delimiter(n));
                                        } else if (lua_key_eq(s, right)) {
                                            nodelib_push_direct_or_node(L, direct, radical_right_delimiter(n));
                                        } else if (lua_key_eq(s, top)) {
                                            nodelib_push_direct_or_node(L, direct, radical_top_delimiter(n));
                                        } else if (lua_key_eq(s, bottom)) {
                                            nodelib_push_direct_or_node(L, direct, radical_bottom_delimiter(n));
                                        } else if (lua_key_eq(s, degree)) {
                                            nodelib_push_direct_or_node(L, direct, radical_degree(n));
                                        } else if (lua_key_eq(s, width)) {
                                            lua_pushinteger(L, noad_width(n));
                                        } else {
                                             goto CANTGET;
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
                                             goto CANTGET;
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
                                             goto CANTGET;
                                        }
                                        break;
                                    case fence_noad:
                                        if (lua_key_eq(s, delimiter)) {
                                            nodelib_push_direct_or_node(L, direct, fence_delimiter(n));
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
                                        } else if (lua_key_eq(s, variant)) {
                                            lua_pushinteger(L, fence_delimiter_variant(n));
                                        } else {
                                             goto CANTGET;
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
                                 goto CANTGET;
                            }
                            break;
                        case sub_box_node:
                        case sub_mlist_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct,  kernel_math_list(n));
                            } else {
                                 goto CANTGET;
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
                                 goto CANTGET;
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
                                 goto CANTGET;
                            }
                            break;
                        case attribute_node:
                            switch (node_subtype(n)) {
                                case attribute_list_subtype:
                                    if (lua_key_eq(s, count)) {
                                        lua_pushinteger(L, attribute_count(n));
                                    } else if (lua_key_eq(s, data)) {
                                        nodelib_push_attribute_data(L, node_attr(n));
                                    } else {
                                        goto CANTGET;
                                    }
                                    break;
                                case attribute_value_subtype:
                                    if (lua_key_eq(s, index) || lua_key_eq(s, number)) {
                                        lua_pushinteger(L, attribute_index(n));
                                    } else if (lua_key_eq(s, value)) {
                                        lua_pushinteger(L, attribute_value(n));
                                    } else {
                                        goto CANTGET;
                                    }
                                    break;
                                default:
                                    goto CANTGET;
                            }
                            break;
                        case adjust_node:
                            if (lua_key_eq(s, list) || lua_key_eq(s, head)) {
                                nodelib_push_direct_or_node_node_prev(L, direct, adjust_list(n));
                            } else if (lua_key_eq(s, index) || lua_key_eq(s, class)) {
                                lua_pushinteger(L, adjust_index(n));
                            } else {
                                goto CANTGET;
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
                                goto CANTGET;
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
                            } else if (lua_key_eq(s, reserved)) {
                                lua_pushinteger(L, boundary_reserved(n));
                            } else {
                                goto CANTGET;
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
                                last_field_error = lua_get_field_error;
                                lua_pushnil(L);
                            }
                            break;
                        default:
                            goto CANTGET;
                    }
                }
                break;
            }
        default:
            {
              CANTGET:
                last_field_error = lua_get_field_error;
                lua_pushnil(L);
                break;
            }
    }
    return 1;
}

# define getfield_usage common_usage

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
    last_field_error = lua_no_field_error;
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
                                     glyph_scale(n) = scaling_factor;
                                 }
                            } else if (lua_key_eq(s, xscale)) {
                                 glyph_x_scale(n) = (halfword) lmt_roundnumber(L, 3);
                                 if (! glyph_x_scale(n)) {
                                     glyph_x_scale(n) = scaling_factor;
                                 }
                            } else if (lua_key_eq(s, yscale)) {
                                 glyph_y_scale(n) = (halfword) lmt_roundnumber(L, 3);
                                 if (! glyph_y_scale(n)) {
                                     glyph_y_scale(n) = scaling_factor;
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
                            } else if (lua_key_eq(s, slant)) {
                                set_glyph_slant(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, weight)) {
                                set_glyph_weight(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, lhmin)) {
                                set_glyph_lhmin(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, rhmin)) {
                                set_glyph_rhmin(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, uchyph)) {
                                set_glyph_uchyph(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, hyphenate)) {
                                set_glyph_hyphenate(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, options)) {
                                set_glyph_options(n, lmt_tohalfword(L, 3) & glyph_option_valid);
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
                            } else if (lua_key_eq(s, control)) {
                                set_glyph_control(n, lmt_tohalfword(L, 3));
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
                            } else if (lua_key_eq(s, except)) {
                                box_except(n) = nodelib_direct_or_node_from_index(L, direct, 3);;
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
                                disc_options(n) = lmt_tohalfword(L, 3) & disc_option_valid;
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
                            } else if (lua_key_eq(s, options)) {
                                glue_options(n) |= lmt_tohalfword(L, 3);
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
                            } else if (lua_key_eq(s, options)) {
                                penalty_options(n) |= lmt_tohalfword(L, 3);
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
                                tex_set_rule_left(n, (halfword) lmt_roundnumber(L, 3));
                            } else if (lua_key_eq(s, right)) {
                                tex_set_rule_right(n, (halfword) lmt_roundnumber(L, 3));
                            } else if (lua_key_eq(s, on)) {
                                tex_set_rule_on(n, (halfword) lmt_roundnumber(L, 3));
                            } else if (lua_key_eq(s, off)) {
                                tex_set_rule_off(n, (halfword) lmt_roundnumber(L, 3));
                            } else if (lua_key_eq(s, data)) {
                                rule_data(n) = lmt_tohalfword(L, 3);
                             } else if (lua_key_eq(s, options)) {
                                rule_options(n) = lmt_tohalfword(L, 3) & rule_option_valid;
                            } else if (lua_key_eq(s, font)) {
                                tex_set_rule_font(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, fam)) {
                                tex_set_rule_family(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, char)) {
                                rule_strut_character(n) = lmt_tohalfword(L, 3);
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
                            } else if (lua_key_eq(s, tolerance)) {
                                tex_set_local_tolerance(n, lmt_tohalfword(L, 3));
                            } else if (lua_key_eq(s, pretolerance)) {
                                tex_set_local_pre_tolerance(n, lmt_tohalfword(L, 3));
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
                                halfword m = ignore_field_error ? lmt_opthalfword(L, 3, 1) : lmt_tohalfword(L, 3);
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
                                halfword index = ignore_field_error ? lmt_opthalfword(L, 3, 1) : lmt_tohalfword(L, 3);
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
                            } else if (lua_key_eq(s, options)) {
                                math_options(n) |= lmt_tohalfword(L, 3);
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
                                noad_options(n) = lmt_tofullword(L, 3);
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
                                        } else if (lua_key_eq(s, top)) {
                                            radical_top_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
                                        } else if (lua_key_eq(s, bottom)) {
                                            radical_bottom_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
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
                                            fence_delimiter(n) = nodelib_direct_or_node_from_index(L, direct, 3);
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
                                        } else if (lua_key_eq(s, variant)) {
                                            fence_delimiter_variant(n) = (halfword) lmt_roundnumber(L, 3);
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
                                        attribute_index(n) = (quarterword) lmt_tohalfword(L, 3);
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
                            if (lua_key_eq(s, value) || lua_key_eq(s, data)) {
                                boundary_data(n) = lmt_tohalfword(L, 3);
                            } else if (lua_key_eq(s, reserved)) {
                                boundary_reserved(n) = lmt_tohalfword(L, 3);
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
                            last_field_error = lua_set_field_error;
                            return ignore_field_error ? 0 : luaL_error(L, "you can't assign to a %s node (%d)\n", lmt_interface.node_data[t].name, n);
                    }
                  CANTSET:
                    last_field_error = lua_set_field_error;
                    return ignore_field_error ? 0 : luaL_error(L,"you can't set field %s in a %s node (%d)", s, lmt_interface.node_data[t].name, n);
                }
                return 0;
            }
    }
    return 0;
}

static int nodelib_shared_setfielderror(lua_State *L)
{
    ignore_field_error = lua_toboolean(L, 1);
    last_field_error = lua_no_field_error;
    return 1;
}

static int nodelib_shared_getfielderror(lua_State *L)
{
    lua_pushinteger(L, last_field_error);
    return 1;
}


# define setfield_usage common_usage

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

# define ligaturing_usage common_usage

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

# define kerning_usage common_usage

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

# define hyphenating_usage common_usage
# define collapsing_usage  common_usage

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

static inline void nodelib_aux_protect_all(halfword h)
{
    while (h) {
        if (node_type(h) == glyph_node) {
            glyph_protected(h) = glyph_protected_text_code;
        }
        h = node_next(h);
    }
}
static inline void nodelib_aux_unprotect_all(halfword h)
{
    while (h) {
        if (node_type(h) == glyph_node) {
            glyph_protected(h) = glyph_unprotected_code;
        }
        h = node_next(h);
    }
}

static inline void nodelib_aux_protect_node(halfword n)
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

static inline void nodelib_aux_unprotect_node(halfword n)
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

# define protectglyph_usage        (glyph_usage | disc_usage)
# define unprotectglyph_usage      (glyph_usage | disc_usage)

# define protectglyphs_usage       common_usage
# define unprotectglyphs_usage     common_usage

# define protectglyphsnone_usage   common_usage
# define unprotectglyphsnone_usage common_usage

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

static inline void nodelib_aux_protect_all_none(halfword h)
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

static inline void nodelib_aux_protect_node_none(halfword n)
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

static int nodelib_direct_protectglyphsnone(lua_State *L)
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

/* node.direct.first_glyphnode */
/* node.direct.first_glyph */
/* node.direct.first_char */

# define firstglyphnode_usage common_usage
# define firstglyph_usage     common_usage
# define firstchar_usage      common_usage

static int nodelib_direct_firstglyphnode(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    halfword t = nodelib_valid_direct_from_index(L, 2);
    if (h) {
        halfword savetail = null;
        if (t) {
            savetail = node_next(t);
            node_next(t) = null;
        }
        while (h && node_type(h) != glyph_node) {
            h = node_next(h);
        }
        if (savetail) {
            node_next(t) = savetail;
        }
    }
    if (h) {
        lua_pushinteger(L, h);
    } else {
        lua_pushnil(L);
    }
    return 1;
}


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
            We go to the first processed character so that is one with a value <= 0xFF and we
            don't care about what the value is.
        */
        while (h && ! (node_type(h) == glyph_node && glyph_protected(h))) {
            h = node_next(h);
        }
        if (savetail) {
            node_next(t) = savetail;
        }
    }
    if (h) {
        lua_pushinteger(L, h);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int nodelib_direct_firstchar(lua_State *L)
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
        while (h && ! (node_type(h) == glyph_node && ! glyph_protected(h))) {
            h = node_next(h);
        }
        if (savetail) {
            node_next(t) = savetail;
        }
    }
    if (h) {
        lua_pushinteger(L, h);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* node.direct.find_node(head)         : node, subtype*/
/* node.direct.find_node(head,subtype) : node */

# define findnode_usage common_usage

static int nodelib_direct_findnode(lua_State *L)
{
    halfword h = nodelib_valid_direct_from_index(L, 1);
    if (h) {
        halfword type = lmt_tohalfword(L, 2);
        if (lua_gettop(L) > 2) {
            halfword subtype = lmt_tohalfword(L, 3);
            while (h) {
                if (node_type(h) == type && node_subtype(h) == subtype) {
                    lua_pushinteger(L, h);
                    return 1;
                } else {
                    h = node_next(h);
                }
            }
        } else {
            while (h) {
                if (node_type(h) == type) {
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

# define hasglyph_usage common_usage

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

static inline int nodelib_aux_in_word(halfword n)
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

# define getwordrange_usage common_usage

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

# define usedlist_usage common_usage

static int nodelib_direct_usedlist(lua_State *L)
{
    lua_pushinteger(L, tex_list_node_mem_usage());
    return 1;
}

/* node.direct.protrusionskipable(node m) */

# define protrusionskippable_usage common_usage

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

# define currentattributes_usage common_usage

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

# define todirect_usage      common_usage
# define tovaliddirect_usage common_usage

static int nodelib_shared_todirect(lua_State* L)
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

# define tonode_usage common_usage

static int nodelib_shared_tonode(lua_State* L)
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
                    /* (node,scale,xscale,yscale) */
                    if (lua_tointeger(L, 3) == glyph_scale(n) && lua_tointeger(L, 4) == glyph_x_scale(n) && lua_tointeger(L, 5) == glyph_y_scale(n)) {
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
                    /* (node,font,data,state,scale,xscale,yscale)*/
            }
        }
    }
    return -1;
  OKAY:
    return glyph_character(n);
}

# define ischar_usage         common_usage
# define isnextchar_usage     common_usage
# define isprevchar_usage     common_usage

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

static inline int nodelib_aux_similar_glyph(halfword first, halfword second)
{
    return
        node_type(second)     == glyph_node
     && glyph_font(second)    == glyph_font(first)
     && glyph_data(second)    == glyph_data(first)
  /* && glyph_state(second)   == glyph_state(first) */
     && glyph_scale(second)   == glyph_scale(first)
     && glyph_x_scale(second) == glyph_x_scale(first)
     && glyph_y_scale(second) == glyph_y_scale(first)
     && glyph_slant(second)   == glyph_slant(first)
     && glyph_weight(second)  == glyph_weight(first)
    ;
}

# define issimilarglyph_usage common_usage

static int nodelib_direct_issimilarglyph(lua_State *L)
{
    halfword first = nodelib_valid_direct_from_index(L, 1);
    halfword second = nodelib_valid_direct_from_index(L, 2);
    lua_pushboolean(L, nodelib_aux_similar_glyph(first, second));
    return 1;
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

# define isglyph_usage     common_usage
# define isnextglyph_usage common_usage
# define isprevglyph_usage common_usage

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

static inline int nodelib_aux_uses_font_disc(lua_State *L, halfword n, halfword font)
{
    if (font) {
        while (n) {
            if ((node_type(n) == glyph_node) && (glyph_font(n) == font)) {
                lua_pushboolean(L, 1);
                return 1;
            }
            n = node_next(n);
        }
    } else {
        while (n) {
            if (node_type(n) == glyph_node) {
                lua_pushinteger(L, glyph_font(n));
                return 1;
            }
            n = node_next(n);
        }
    }
    return 0;
}

# define usesfont_usage common_usage

static int nodelib_direct_usesfont(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        halfword f = lmt_opthalfword(L, 2, 0);
        switch (node_type(n)) {
            case glyph_node:
                if (f) {
                    lua_pushboolean(L, glyph_font(n) == f);
                } else {
                    lua_pushinteger(L, glyph_font(n));
                }
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

# define getbox_usage common_usage
# define setbox_usage common_usage

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

# define isdirect_usage common_usage
# define isnode_usage   common_usage

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

# define getproperty_usage common_usage
# define setproperty_usage common_usage

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

# define effectiveglue_usage (glue_usage | math_usage)

static int nodelib_direct_effectiveglue(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        switch (node_type(n)) {
            case glue_node:
                nodelib_direct_effect_done(L, glue_amount(n), glue_stretch(n), glue_shrink(n), glue_stretch_order(n), glue_shrink_order(n));
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

# define checkdiscretionaries_usage common_usage
# define checkdiscretionary_usage   disc_usage

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

# define flattendiscretionaries_usage common_usage

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

# define softenhyphens_usage common_usage

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

# define getinputfields_usage (glyph_usage | hlist_usage | vlist_usage | unset_usage)
# define setinputfields_usage getinputfields_usage

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

/*tex
    Likely we pas the wrong |chr| here as we're after the analysis phase. Buit we don't use this
    helper any longer (it seems).
*/

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

# define flattenleaders_usage common_usage

static int nodelib_direct_flattenleaders(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    int count = 0;
    if (n) {
        switch (node_type(n)) {
            case hlist_node:
                count = tex_flatten_leaders(n, hbox_group, 0, uleader_lua, 0);
                break;
            case vlist_node:
                count = tex_flatten_leaders(n, vbox_group, 0, uleader_lua, 0);
                break;
        }
    }
    lua_pushinteger(L, count);
    return 1;
}

/*tex test */

# define isvalid_usage common_usage

static int nodelib_direct_isvalid(lua_State *L)
{
    lua_pushboolean(L, nodelib_valid_direct_from_index(L, 1));
    return 1;
}

/* getlinestuff : LS RS LH RH ID PF FIRST LAST */

static inline scaled set_effective_width(halfword source, halfword sign, halfword order, double glue)
{
    scaled amount = glue_amount(source);
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

# define getnormalizedline_usage hlist_usage

static int nodelib_direct_getnormalizedline(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n && node_type(n) == hlist_node && node_subtype(n) == line_list) {
        halfword head = box_list(n);
        halfword tail = head;
        halfword first = head;    /* the first special glue before the content */
        halfword last = tail;     /* the first special glue after the content */
        halfword current = head;
        scaled ls = 0;
        scaled rs = 0;
        scaled is = 0;
        scaled pr = 0;
        scaled pl = 0;
        scaled ir = 0;
        scaled il = 0;
        scaled lh = 0;
        scaled rh = 0;
        scaled cs = 0;
        halfword sign = box_glue_sign(n);
        halfword order = box_glue_order(n);
        double glue = box_glue_set(n);
        int details = lua_toboolean(L, 2);
        while (current) {
            tail = current ;
            if (node_type(current) == glue_node) {
                switch (node_subtype(current)) {
                    case left_skip_glue           : ls = set_effective_width(current, sign, order, glue); break; // first = current; break;
                    case right_skip_glue          : rs = set_effective_width(current, sign, order, glue); break; // if (last == tail) { last = current; } break;
                    case par_fill_left_skip_glue  : pl = set_effective_width(current, sign, order, glue); break; // first = current; break;
                    case par_fill_right_skip_glue : pr = set_effective_width(current, sign, order, glue); break; // if (last == tail) { last = current; } break;
                    case par_init_left_skip_glue  : il = set_effective_width(current, sign, order, glue); break; // first = current; break;
                    case par_init_right_skip_glue : ir = set_effective_width(current, sign, order, glue); break; // if (last == tail) { last = current; } break;
                    case indent_skip_glue         : is = set_effective_width(current, sign, order, glue); break; // first = current; break;
                    case left_hang_skip_glue      : lh = set_effective_width(current, sign, order, glue); break; // first = current; break;
                    case right_hang_skip_glue     : rh = set_effective_width(current, sign, order, glue); break; // if (last == tail) { last = current; } break;
                    case correction_skip_glue     : cs = set_effective_width(current, sign, order, glue); break; // break;
                }
            }
            current = node_next(current);
        }
        tex_get_line_content_range(head, tail, &first, &last);
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
        lua_push_integer_at_key(L, correctionskip, cs);
        lua_push_integer_at_key(L, first, first); /* points to a skip */
        lua_push_integer_at_key(L, last, last);   /* points to a skip */
        lua_push_integer_at_key(L, head, head);
        lua_push_integer_at_key(L, tail, tail);
        if (details) {
            scaled ns = tex_natural_hsize(box_list(n), &cs); /* todo: check if cs is the same */
            lua_push_integer_at_key(L, width, box_width(n));
            lua_push_integer_at_key(L, height, box_height(n));
            lua_push_integer_at_key(L, depth, box_depth(n));
            lua_push_integer_at_key(L, left, ls + lh + pl + il);
            lua_push_integer_at_key(L, right, rs + rh + pr + ir);
            lua_push_integer_at_key(L, size, ns);
        }
        return 1;
    }
    return 0;
}

/*tex new */

# define ignoremathskip_usage math_usage

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

# define reverse_usage common_usage

static int nodelib_direct_reverse(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    if (n) {
        n = tex_reversed_node_list(n);
    }
    nodelib_push_direct_or_nil(L, n);
    return 1;
}

# define exchange_usage common_usage

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

static inline halfword nodelib_aux_migrate_decouple(halfword head, halfword current, halfword next, halfword *first, halfword *last)
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

# define migrate_usage (hlist_usage | vlist_usage | insert_usage)

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
                case hlist_node:
                case vlist_node:
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

/*tex This one also checks is we have a glyph. */

# define hasglyphoption_usage glyph_usage

static int nodelib_direct_hasglyphoption(lua_State *L)
{
    halfword current = nodelib_valid_direct_from_index(L, 1);
    int result = 0;
    if (current && node_type(current) == glyph_node) {
        int option = lmt_tointeger(L, 2);
        switch (option) {
            case glyph_option_normal_glyph:
                break;
            case glyph_option_no_left_ligature:
                result = nodelib_aux_no_left(current, glyph_option_no_left_ligature, glyph_option_no_right_ligature);
                break;
            case glyph_option_no_right_ligature:
                result = nodelib_aux_no_right(current, glyph_option_no_right_ligature, glyph_option_no_left_ligature);
                break;
            case glyph_option_no_left_kern:
                result = nodelib_aux_no_left(current, glyph_option_no_left_kern, glyph_option_no_right_kern);
                break;
            case glyph_option_no_right_kern:
                result = nodelib_aux_no_right(current, glyph_option_no_right_kern, glyph_option_no_left_kern);
                break;
            case glyph_option_no_expansion:
            case glyph_option_no_protrusion:
            case glyph_option_apply_x_offset:
            case glyph_option_apply_y_offset:
                /* todo */
                break;
            case glyph_option_no_italic_correction:
            case glyph_option_no_zero_italic_correction:
            case glyph_option_math_discretionary:
            case glyph_option_math_italics_too:
                result = tex_has_glyph_option(current, option);
                break;
            default:
                /* user options */
                result = tex_has_glyph_option(current, option);
        }
    }
    lua_pushboolean(L, result);
    return 1;
}

# define hasdiscoption_usage disc_usage

static int nodelib_direct_hasdiscoption(lua_State *L)
{
    halfword current = nodelib_valid_direct_from_index(L, 1);
    int result = 0;
    if (current && node_type(current) == disc_node) {
        /*tex No specific checking, maybe some day check of pre/post/replace. */
        result = tex_has_disc_option(current, lmt_tointeger(L, 2));
    }
    lua_pushboolean(L, result);
    return 1;
}

# define isitalicglyph_usage glyph_usage

static int nodelib_direct_isitalicglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    lua_pushboolean(L,
        n && node_type(n) == glyph_node && ! tex_has_glyph_option(n, glyph_option_no_italic_correction) && (
            glyph_slant(n)
         || has_font_text_control(glyph_font(n), text_control_has_italics)
         || has_font_text_control(glyph_font(n), text_control_auto_italics)
        )
    );
    return 1;
}

# define firstitalicglyph_usage common_usage

static int nodelib_direct_firstitalicglyph(lua_State *L)
{
    halfword n = nodelib_valid_direct_from_index(L, 1);
    int kerntoo = lua_toboolean(L, 2);
    while (n) {
        switch (node_type(n)) {
            case glyph_node:
                if (! tex_has_glyph_option(n, glyph_option_no_italic_correction) && (glyph_slant(n)
                     || has_font_text_control(glyph_font(n), text_control_has_italics)
                     || has_font_text_control(glyph_font(n), text_control_auto_italics)
                   )) {
                    goto DONE;
                }
                break;
            case kern_node:
                if (kerntoo) {
                    switch (node_subtype(n)) {
                        case italic_kern_subtype:
                        case left_correction_kern_subtype:
                        case right_correction_kern_subtype:
                            goto DONE;
                    }
                }
                break;
        }
        n = node_next(n);
    }
  DONE:
    nodelib_push_direct_or_nil(L, n);
    return 1;
}

# define isspeciallist_usage  common_usage
# define getspeciallist_usage common_usage
# define setspeciallist_usage common_usage

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

# define getnodes_usage common_usage

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

# define gluetostring_usage (glue_usage | glue_spec_usage)

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

/*tex This is an experiment: */

typedef enum usage_targets {
    no_usage_target       = 0,
    direct_usage_target   = 1, /* only available for direct nodes */
    userdata_usage_target = 2, /* only available for userdata nodes */
    separate_usage_target = 3, /* dedicated versions for direct and userdata nodes */
    hybrid_usage_target   = 4, /* shared version for direct and userdata nodes */
    general_usage_target  = 5, /* no direct or userdata arguments */
} usage_targets;

typedef struct usage_record {
    const char  *name;
    lua_Integer  usage;
    int          target;
} usage_record;

static const usage_record usage_data[] = {
    { .name = "addmargins",             .target = direct_usage_target,   .usage = addmargins_usage             },
    { .name = "addxoffset",             .target = direct_usage_target,   .usage = addxoffset_usage             },
    { .name = "addxymargins",           .target = direct_usage_target,   .usage = addxymargins_usage           },
    { .name = "addyoffset",             .target = direct_usage_target,   .usage = addyoffset_usage             },
    { .name = "appendaftertail",        .target = direct_usage_target,   .usage = appendaftertail_usage        },
    { .name = "beginofmath",            .target = direct_usage_target,   .usage = beginofmath_usage            },
    { .name = "checkdiscretionaries",   .target = direct_usage_target,   .usage = checkdiscretionaries_usage   },
    { .name = "checkdiscretionary",     .target = direct_usage_target,   .usage = checkdiscretionary_usage     },
    { .name = "collapsing",             .target = direct_usage_target,   .usage = collapsing_usage             },
    { .name = "copy",                   .target = separate_usage_target, .usage = copy_usage                   },
    { .name = "copylist",               .target = separate_usage_target, .usage = copylist_usage               },
    { .name = "copyonly",               .target = direct_usage_target,   .usage = copyonly_usage               },
    { .name = "count",                  .target = direct_usage_target,   .usage = count_usage                  },
    { .name = "currentattributes",      .target = separate_usage_target, .usage = currentattributes_usage      },
    { .name = "dimensions",             .target = direct_usage_target,   .usage = dimensions_usage             },
    { .name = "effectiveglue",          .target = direct_usage_target,   .usage = effectiveglue_usage          },
    { .name = "endofmath",              .target = direct_usage_target,   .usage = endofmath_usage              },
    { .name = "exchange",               .target = direct_usage_target,   .usage = exchange_usage               },
    { .name = "fields",                 .target = general_usage_target,  .usage = fields_usage                 },
    { .name = "findattribute",          .target = direct_usage_target,   .usage = findattribute_usage          },
    { .name = "findattributerange",     .target = direct_usage_target,   .usage = findattributerange_usage     },
    { .name = "findnode",               .target = direct_usage_target,   .usage = findnode_usage               },
    { .name = "firstchar",              .target = direct_usage_target,   .usage = firstchar_usage              },
    { .name = "firstglyph",             .target = direct_usage_target,   .usage = firstglyph_usage             },
    { .name = "firstglyphnode",         .target = direct_usage_target,   .usage = firstglyphnode_usage         },
    { .name = "firstitalicglyph",       .target = direct_usage_target,   .usage = firstitalicglyph_usage       },
    { .name = "flattendiscretionaries", .target = direct_usage_target,   .usage = flattendiscretionaries_usage },
    { .name = "flattenleaders",         .target = direct_usage_target,   .usage = flattenleaders_usage         },
    { .name = "flushlist",              .target = separate_usage_target, .usage = flushlist_usage              },
    { .name = "flushnode",              .target = separate_usage_target, .usage = flushnode_usage              },
    { .name = "free",                   .target = separate_usage_target, .usage = free_usage                   },
    { .name = "freeze",                 .target = direct_usage_target,   .usage = freeze_usage                 },
    { .name = "getanchors",             .target = direct_usage_target,   .usage = getanchors_usage             },
    { .name = "getattribute",           .target = separate_usage_target, .usage = getattribute_usage           },
    { .name = "getattributelist",       .target = direct_usage_target,   .usage = getattributelist_usage       },
    { .name = "getattributes",          .target = direct_usage_target,   .usage = getattributes_usage          },
    { .name = "getboth",                .target = direct_usage_target,   .usage = getboth_usage                },
    { .name = "getbottom",              .target = direct_usage_target,   .usage = getbottom_usage              },
    { .name = "getbottomdelimiter",     .target = direct_usage_target,   .usage = getbottomdelimiter_usage     },
    { .name = "getbox",                 .target = direct_usage_target,   .usage = getbox_usage                 },
    { .name = "getcachestate",          .target = general_usage_target,  .usage = common_usage                 }, /* todo */
    { .name = "getchar",                .target = direct_usage_target,   .usage = getchar_usage                },
    { .name = "getchardict",            .target = direct_usage_target,   .usage = getchardict_usage            },
    { .name = "getcharspec",            .target = direct_usage_target,   .usage = getcharspec_usage            },
    { .name = "getchoice",              .target = direct_usage_target,   .usage = getchoice_usage              },
    { .name = "getclass",               .target = direct_usage_target,   .usage = getclass_usage               },
    { .name = "getcontrol",             .target = direct_usage_target,   .usage = getcontrol_usage             },
    { .name = "getcornerkerns",         .target = direct_usage_target,   .usage = getcornerkerns_usage         },
    { .name = "getdata",                .target = direct_usage_target,   .usage = getdata_usage                },
    { .name = "getdegree",              .target = direct_usage_target,   .usage = getdegree_usage              },
    { .name = "getdelimiter",           .target = direct_usage_target,   .usage = getdelimiter_usage           },
    { .name = "getdenominator",         .target = direct_usage_target,   .usage = getdenominator_usage         },
    { .name = "getdepth",               .target = direct_usage_target,   .usage = getdepth_usage               },
    { .name = "getdirection",           .target = direct_usage_target,   .usage = getdirection_usage           },
    { .name = "getdisc",                .target = direct_usage_target,   .usage = getdisc_usage                },
    { .name = "getdiscpart",            .target = direct_usage_target,   .usage = getdiscpart_usage            },
    { .name = "getexcept",              .target = direct_usage_target,   .usage = getexcept_usage              },
    { .name = "getexpansion",           .target = direct_usage_target,   .usage = getexpansion_usage           },
    { .name = "getfam",                 .target = direct_usage_target,   .usage = getfam_usage                 },
    { .name = "getfield",               .target = separate_usage_target, .usage = getfield_usage               },
    { .name = "getfont",                .target = direct_usage_target,   .usage = getfont_usage                },
    { .name = "getgeometry",            .target = direct_usage_target,   .usage = getgeometry_usage            },
    { .name = "getglue",                .target = direct_usage_target,   .usage = getglue_usage                },
    { .name = "getglyphdata",           .target = direct_usage_target,   .usage = getglyphdata_usage           },
    { .name = "getglyphdimensions",     .target = direct_usage_target,   .usage = getglyphdimensions_usage     },
    { .name = "getheight",              .target = direct_usage_target,   .usage = getheight_usage              },
    { .name = "getid",                  .target = direct_usage_target,   .usage = getid_usage                  },
    { .name = "getindex",               .target = direct_usage_target,   .usage = getindex_usage               },
    { .name = "getinputfields",         .target = direct_usage_target,   .usage = getinputfields_usage         },
    { .name = "getkern",                .target = direct_usage_target,   .usage = getkern_usage                },
    { .name = "getkerndimension",       .target = direct_usage_target,   .usage = getkerndimension_usage       },
    { .name = "getlanguage",            .target = direct_usage_target,   .usage = getlanguage_usage            },
    { .name = "getleader",              .target = direct_usage_target,   .usage = getleader_usage              },
    { .name = "getleftdelimiter",       .target = direct_usage_target,   .usage = getleftdelimiter_usage       },
    { .name = "getlist",                .target = direct_usage_target,   .usage = getlist_usage                },
    { .name = "getlistdimensions",      .target = direct_usage_target,   .usage = getlistdimensions_usage      },
    { .name = "getnext",                .target = direct_usage_target,   .usage = getnext_usage                },
    { .name = "getnodes",               .target = direct_usage_target,   .usage = getnodes_usage               },
    { .name = "getnormalizedline",      .target = direct_usage_target,   .usage = getnormalizedline_usage      },
    { .name = "getnucleus",             .target = direct_usage_target,   .usage = getnucleus_usage             },
    { .name = "getnumerator",           .target = direct_usage_target,   .usage = getnumerator_usage           },
    { .name = "getoffsets",             .target = direct_usage_target,   .usage = getoffsets_usage             },
    { .name = "getoptions",             .target = direct_usage_target,   .usage = getoptions_usage             },
    { .name = "getorientation",         .target = direct_usage_target,   .usage = getorientation_usage         },
    { .name = "getparstate",            .target = direct_usage_target,   .usage = getparstate_usage            },
    { .name = "getpenalty",             .target = direct_usage_target,   .usage = getpenalty_usage             },
    { .name = "getpost",                .target = direct_usage_target,   .usage = getpost_usage                },
    { .name = "getpre",                 .target = direct_usage_target,   .usage = getpre_usage                 },
    { .name = "getprev",                .target = direct_usage_target,   .usage = getprev_usage                },
    { .name = "getprime",               .target = direct_usage_target,   .usage = getprime_usage               },
    { .name = "getpropertiestable",     .target = separate_usage_target, .usage = common_usage                 }, /* todo */
    { .name = "getproperty",            .target = separate_usage_target, .usage = getproperty_usage            },
    { .name = "getreplace",             .target = direct_usage_target,   .usage = getreplace_usage             },
    { .name = "getrightdelimiter",      .target = direct_usage_target,   .usage = getrightdelimiter_usage      },
    { .name = "getruledimensions",      .target = direct_usage_target,   .usage = getruledimensions_usage      },
    { .name = "getscale",               .target = direct_usage_target,   .usage = getscale_usage               },
    { .name = "getscales",              .target = direct_usage_target,   .usage = getscales_usage              },
    { .name = "getscript",              .target = direct_usage_target,   .usage = getscript_usage              },
    { .name = "getscripts",             .target = direct_usage_target,   .usage = getscripts_usage             },
    { .name = "getshift",               .target = direct_usage_target,   .usage = getshift_usage               },
    { .name = "getslant",               .target = direct_usage_target,   .usage = getslant_usage               },
    { .name = "getspeciallist",         .target = direct_usage_target,   .usage = getspeciallist_usage         },
    { .name = "getstate",               .target = direct_usage_target,   .usage = getstate_usage               },
    { .name = "getsub",                 .target = direct_usage_target,   .usage = getsub_usage                 },
    { .name = "getsubpre",              .target = direct_usage_target,   .usage = getsubpre_usage              },
    { .name = "getsubtype",             .target = direct_usage_target,   .usage = getsubtype_usage             },
    { .name = "getsup",                 .target = direct_usage_target,   .usage = getsup_usage                 },
    { .name = "getsuppre",              .target = direct_usage_target,   .usage = getsuppre_usage              },
    { .name = "gettop",                 .target = direct_usage_target,   .usage = gettop_usage                 },
    { .name = "gettopdelimiter",        .target = direct_usage_target,   .usage = gettopdelimiter_usage        },
    { .name = "gettotal",               .target = direct_usage_target,   .usage = gettotal_usage               },
    { .name = "getweight",              .target = direct_usage_target,   .usage = getweight_usage              },
    { .name = "getwhd",                 .target = direct_usage_target,   .usage = getwhd_usage                 },
    { .name = "getwidth",               .target = direct_usage_target,   .usage = getwidth_usage               },
    { .name = "getwordrange",           .target = direct_usage_target,   .usage = getwordrange_usage           },
    { .name = "getxscale",              .target = direct_usage_target,   .usage = getxscale_usage              },
    { .name = "getxyscales",            .target = direct_usage_target,   .usage = getxyscales_usage            },
    { .name = "getyscale",              .target = direct_usage_target,   .usage = getyscale_usage              },
    { .name = "gluetostring" ,          .target = hybrid_usage_target,   .usage = gluetostring_usage           },
    { .name = "hasattribute",           .target = separate_usage_target, .usage = hasattribute_usage           },
    { .name = "hasdimensions",          .target = direct_usage_target,   .usage = hasdimensions_usage          },
    { .name = "hasdiscoption",          .target = direct_usage_target,   .usage = hasdiscoption_usage          },
    { .name = "hasfield",               .target = separate_usage_target, .usage = hasfield_usage               },
    { .name = "hasgeometry",            .target = direct_usage_target,   .usage = hasgeometry_usage            },
    { .name = "hasglyph",               .target = direct_usage_target,   .usage = hasglyph_usage               },
    { .name = "hasglyphoption",         .target = direct_usage_target,   .usage = hasglyphoption_usage         },
    { .name = "hpack",                  .target = direct_usage_target,   .usage = hpack_usage                  },
    { .name = "hyphenating",            .target = direct_usage_target,   .usage = hyphenating_usage            },
    { .name = "id",                     .target = general_usage_target,  .usage = id_usage                     },
    { .name = "ignoremathskip",         .target = direct_usage_target,   .usage = ignoremathskip_usage         },
    { .name = "insertafter",            .target = separate_usage_target, .usage = insertafter_usage            },
    { .name = "insertbefore",           .target = separate_usage_target, .usage = insertbefore_usage           },
    { .name = "instock",                .target = userdata_usage_target, .usage = common_usage                 }, /* todo */
    { .name = "inuse",                  .target = userdata_usage_target, .usage = common_usage                 }, /* todo */
    { .name = "isboth",                 .target = direct_usage_target,   .usage = isboth_usage                 },
    { .name = "ischar",                 .target = direct_usage_target,   .usage = ischar_usage                 },
    { .name = "isdirect",               .target = direct_usage_target,   .usage = isdirect_usage               },
    { .name = "isglyph",                .target = direct_usage_target,   .usage = isglyph_usage                },
    { .name = "isitalicglyph",          .target = direct_usage_target,   .usage = isitalicglyph_usage          },
    { .name = "isloop",                 .target = direct_usage_target,   .usage = isloop_usage                 },
    { .name = "isnext",                 .target = direct_usage_target,   .usage = isnext_usage                 },
    { .name = "isnextchar",             .target = direct_usage_target,   .usage = isnextchar_usage             },
    { .name = "isnextglyph",            .target = direct_usage_target,   .usage = isnextglyph_usage            },
    { .name = "isnode",                 .target = separate_usage_target, .usage = isnode_usage                 },
    { .name = "isprev",                 .target = direct_usage_target,   .usage = isprev_usage                 },
    { .name = "isprevchar",             .target = direct_usage_target,   .usage = isnextchar_usage             },
    { .name = "isprevglyph",            .target = direct_usage_target,   .usage = isprevglyph_usage            },
    { .name = "issimilarglyph",         .target = direct_usage_target,   .usage = issimilarglyph_usage         },
    { .name = "isspeciallist",          .target = direct_usage_target,   .usage = isspeciallist_usage          },
    { .name = "isvalid",                .target = direct_usage_target,   .usage = isvalid_usage                },
    { .name = "iszeroglue",             .target = direct_usage_target,   .usage = iszeroglue_usage             },
    { .name = "kerning",                .target = direct_usage_target,   .usage = kerning_usage                },
    { .name = "lastnode",               .target = direct_usage_target,   .usage = lastnode_usage               },
    { .name = "length",                 .target = direct_usage_target,   .usage = length_usage                 },
    { .name = "ligaturing",             .target = direct_usage_target,   .usage = ligaturing_usage             },
    { .name = "migrate",                .target = direct_usage_target,   .usage = migrate_usage                },
    { .name = "mlisttohlist",           .target = direct_usage_target,   .usage = mlisttohlist_usage           },
    { .name = "naturalhsize",           .target = direct_usage_target,   .usage = naturalhsize_usage           },
    { .name = "naturalwidth",           .target = direct_usage_target,   .usage = naturalwidth_usage           },
    { .name = "new",                    .target = separate_usage_target, .usage = new_usage                    },
    { .name = "newcontinuationatom",    .target = direct_usage_target,   .usage = newcontinuationatom_usage    },
    { .name = "newmathglyph",           .target = direct_usage_target,   .usage = newmathglyph_usage           },
    { .name = "newtextglyph",           .target = direct_usage_target,   .usage = newtextglyph_usage           },
    { .name = "patchattributes",        .target = direct_usage_target,   .usage = patchattributes_usage        },
    { .name = "patchparshape",          .target = direct_usage_target,   .usage = patchparshape_usage          },
    { .name = "prependbeforehead",      .target = direct_usage_target,   .usage = prependbeforehead_usage      },
    { .name = "protectglyph",           .target = direct_usage_target,   .usage = protectglyph_usage           },
    { .name = "protectglyphs",          .target = direct_usage_target,   .usage = protectglyphs_usage          },
    { .name = "protectglyphsnone",      .target = direct_usage_target,   .usage = protectglyphsnone_usage      },
    { .name = "protrusionskippable",    .target = direct_usage_target,   .usage = protrusionskippable_usage    },
    { .name = "rangedimensions",        .target = direct_usage_target,   .usage = rangedimensions_usage        },
    { .name = "remove",                 .target = separate_usage_target, .usage = remove_usage                 },
    { .name = "removefromlist",         .target = direct_usage_target,   .usage = removefromlist_usage         },
    { .name = "repack",                 .target = direct_usage_target,   .usage = repack_usage                 },
    { .name = "reverse",                .target = direct_usage_target,   .usage = reverse_usage                },
    { .name = "serialized",             .target = separate_usage_target, .usage = serialized_usage             },
    { .name = "setanchors",             .target = direct_usage_target,   .usage = setanchors_usage             },
    { .name = "setattribute",           .target = separate_usage_target, .usage = setattribute_usage           },
    { .name = "setattributelist",       .target = direct_usage_target,   .usage = setattributelist_usage       },
    { .name = "setattributes",          .target = direct_usage_target,   .usage = setattributes_usage          },
    { .name = "setboth",                .target = direct_usage_target,   .usage = setboth_usage                },
    { .name = "setbottom",              .target = direct_usage_target,   .usage = setbottom_usage              },
    { .name = "setbottomdelimiter",     .target = direct_usage_target,   .usage = setbottomdelimiter_usage     },
    { .name = "setbox",                 .target = direct_usage_target,   .usage = setbox_usage                 },
    { .name = "setchar",                .target = direct_usage_target,   .usage = setchar_usage                },
    { .name = "setchardict",            .target = direct_usage_target,   .usage = setchardict_usage            },
    { .name = "setcharspec",            .target = direct_usage_target,   .usage = setcharspec_usage            },
    { .name = "setchoice",              .target = direct_usage_target,   .usage = setchoice_usage              },
    { .name = "setclass",               .target = direct_usage_target,   .usage = setclass_usage               },
    { .name = "setcontrol",             .target = direct_usage_target,   .usage = setcontrol_usage             },
    { .name = "setdata",                .target = direct_usage_target,   .usage = setdata_usage                },
    { .name = "setdegree",              .target = direct_usage_target,   .usage = setdegree_usage              },
    { .name = "setdelimiter",           .target = direct_usage_target,   .usage = setdelimiter_usage           },
    { .name = "setdenominator",         .target = direct_usage_target,   .usage = setdenominator_usage         },
    { .name = "setdepth",               .target = direct_usage_target,   .usage = setdepth_usage               },
    { .name = "setdirection",           .target = direct_usage_target,   .usage = setdirection_usage           },
    { .name = "setdisc",                .target = direct_usage_target,   .usage = setdisc_usage                },
    { .name = "setdiscpart",            .target = direct_usage_target,   .usage = setdiscpart_usage            },
    { .name = "setexcept",              .target = direct_usage_target,   .usage = setexcept_usage              },
    { .name = "setexpansion",           .target = direct_usage_target,   .usage = setexpansion_usage           },
    { .name = "setfam",                 .target = direct_usage_target,   .usage = setfam_usage                 },
    { .name = "setfield",               .target = separate_usage_target, .usage = setfield_usage               },
    { .name = "setfont",                .target = direct_usage_target,   .usage = setfont_usage                },
    { .name = "setgeometry",            .target = direct_usage_target,   .usage = setgeometry_usage            },
    { .name = "setglue",                .target = direct_usage_target,   .usage = setglue_usage                },
    { .name = "setglyphdata",           .target = direct_usage_target,   .usage = setglyphdata_usage           },
    { .name = "setheight",              .target = direct_usage_target,   .usage = setheight_usage              },
    { .name = "setindex",               .target = direct_usage_target,   .usage = setindex_usage               },
    { .name = "setinputfields",         .target = direct_usage_target,   .usage = setinputfields_usage         },
    { .name = "setkern",                .target = direct_usage_target,   .usage = setkern_usage                },
    { .name = "setlanguage",            .target = direct_usage_target,   .usage = setlanguage_usage            },
    { .name = "setleader",              .target = direct_usage_target,   .usage = setleader_usage              },
    { .name = "setleftdelimiter",       .target = direct_usage_target,   .usage = setleftdelimiter_usage       },
    { .name = "setlink",                .target = direct_usage_target,   .usage = setlink_usage                },
    { .name = "setlist",                .target = direct_usage_target,   .usage = setlist_usage                },
    { .name = "setnext",                .target = direct_usage_target,   .usage = setnext_usage                },
    { .name = "setnucleus",             .target = direct_usage_target,   .usage = setnucleus_usage             },
    { .name = "setnumerator",           .target = direct_usage_target,   .usage = setnumerator_usage           },
    { .name = "setoffsets",             .target = direct_usage_target,   .usage = setoffsets_usage             },
    { .name = "setoptions",             .target = direct_usage_target,   .usage = setoptions_usage             },
    { .name = "setorientation",         .target = direct_usage_target,   .usage = setorientation_usage         },
    { .name = "setpenalty",             .target = direct_usage_target,   .usage = setpenalty_usage             },
    { .name = "setpost",                .target = direct_usage_target,   .usage = setpost_usage                },
    { .name = "setpre",                 .target = direct_usage_target,   .usage = setpre_usage                 },
    { .name = "setprev",                .target = direct_usage_target,   .usage = setprev_usage                },
    { .name = "setprime",               .target = direct_usage_target,   .usage = setprime_usage               },
    { .name = "setproperty",            .target = separate_usage_target, .usage = setproperty_usage            },
    { .name = "setreplace",             .target = direct_usage_target,   .usage = setreplace_usage             },
    { .name = "setrightdelimiter",      .target = direct_usage_target,   .usage = setrightdelimiter_usage      },
    { .name = "setruledimensions",      .target = direct_usage_target,   .usage = setruledimensions_usage      },
    { .name = "setruledimensions",      .target = direct_usage_target,   .usage = setruledimensions_usage      },
    { .name = "setscale",               .target = direct_usage_target,   .usage = setscale_usage               },
    { .name = "setscales",              .target = direct_usage_target,   .usage = setscales_usage              },
    { .name = "setscript",              .target = direct_usage_target,   .usage = setscript_usage              },
    { .name = "setscripts",             .target = direct_usage_target,   .usage = setscripts_usage             },
    { .name = "setshift",               .target = direct_usage_target,   .usage = setshift_usage               },
    { .name = "setslant",               .target = direct_usage_target,   .usage = setslant_usage               },
    { .name = "setspeciallist",         .target = direct_usage_target,   .usage = setspeciallist_usage         },
    { .name = "setsplit",               .target = direct_usage_target,   .usage = setsplit_usage               },
    { .name = "setstate",               .target = direct_usage_target,   .usage = setstate_usage               },
    { .name = "setsub",                 .target = direct_usage_target,   .usage = setsub_usage                 },
    { .name = "setsubpre",              .target = direct_usage_target,   .usage = setsubpre_usage              },
    { .name = "setsubtype",             .target = direct_usage_target,   .usage = setsubtype_usage             },
    { .name = "setsup",                 .target = direct_usage_target,   .usage = setsup_usage                 },
    { .name = "setsuppre",              .target = direct_usage_target,   .usage = setsuppre_usage              },
    { .name = "settop",                 .target = direct_usage_target,   .usage = settop_usage                 },
    { .name = "settopdelimiter",        .target = direct_usage_target,   .usage = settopdelimiter_usage        },
    { .name = "settotal",               .target = direct_usage_target,   .usage = settotal_usage               },
    { .name = "setweight",              .target = direct_usage_target,   .usage = setweight_usage              },
    { .name = "setwhd",                 .target = direct_usage_target,   .usage = setwhd_usage                 },
    { .name = "setwidth",               .target = direct_usage_target,   .usage = setwidth_usage               },
    { .name = "setxyscales",            .target = direct_usage_target,   .usage = setxyscales_usage            },
    { .name = "show",                   .target = separate_usage_target, .usage = show_usage                   },
    { .name = "showlist",               .target = direct_usage_target,   .usage = showlist_usage               },
    { .name = "size",                   .target = direct_usage_target,   .usage = size_usage                   },
    { .name = "size",                   .target = general_usage_target,  .usage = common_usage                 }, /* todo */
    { .name = "slide",                  .target = direct_usage_target,   .usage = slide_usage                  },
    { .name = "softenhyphens",          .target = direct_usage_target,   .usage = softenhyphens_usage          },
    { .name = "startofpar",             .target = direct_usage_target,   .usage = startofpar_usage             },
    { .name = "subtypes",               .target = general_usage_target,  .usage = common_usage                 }, /* todo */
    { .name = "tail",                   .target = separate_usage_target, .usage = tail_usage                   },
    { .name = "todirect",               .target = userdata_usage_target, .usage = todirect_usage               },
    { .name = "tonode",                 .target = direct_usage_target,   .usage = tonode_usage                 },
    { .name = "tostring",               .target = separate_usage_target, .usage = common_usage                 }, /* todo */
    { .name = "tovaliddirect",          .target = direct_usage_target,   .usage = tovaliddirect_usage          },
    { .name = "traverse",               .target = separate_usage_target, .usage = traverse_usage               },
    { .name = "traversechar",           .target = direct_usage_target,   .usage = traversechar_usage           },
    { .name = "traversecontent",        .target = direct_usage_target,   .usage = traversecontent_usage        },
    { .name = "traverseglyph",          .target = direct_usage_target,   .usage = traverseglyph_usage          },
    { .name = "traverseid",             .target = separate_usage_target, .usage = traverseid_usage             },
    { .name = "traverseitalic",         .target = direct_usage_target,   .usage = traverseitalic_usage         },
    { .name = "traverseleader",         .target = direct_usage_target,   .usage = traverseleader_usage         },
    { .name = "traverselist",           .target = direct_usage_target,   .usage = traverselist_usage           },
    { .name = "type",                   .target = hybrid_usage_target,   .usage = type_usage                   },
    { .name = "types",                  .target = general_usage_target,  .usage = common_usage                 }, /* todo */
    { .name = "unprotectglyph",         .target = direct_usage_target,   .usage = unprotectglyph_usage         },
    { .name = "unprotectglyphs",        .target = direct_usage_target,   .usage = unprotectglyphs_usage        },
    { .name = "unprotectglyphsnone",    .target = direct_usage_target,   .usage = unprotectglyphsnone_usage    },
    { .name = "unsetattribute",         .target = separate_usage_target, .usage = unsetattribute_usage         },
    { .name = "unsetattributes",        .target = direct_usage_target,   .usage = unsetattributes_usage        },
    { .name = "usedlist",               .target = separate_usage_target, .usage = usedlist_usage               },
    { .name = "usesfont",               .target = direct_usage_target,   .usage = usesfont_usage               },
    { .name = "validpar",               .target = direct_usage_target,   .usage = validpar_usage               },
    { .name = "verticalbreak",          .target = direct_usage_target,   .usage = verticalbreak_usage          },
    { .name = "vpack",                  .target = direct_usage_target,   .usage = vpack_usage                  },
    { .name = "write",                  .target = separate_usage_target, .usage = write_usage                  },
    { .name = "xscaled",                .target = direct_usage_target,   .usage = xscaled_usage                },
    { .name = "yscaled",                .target = direct_usage_target,   .usage = yscaled_usage                },
    { .name = NULL,                     .target = no_usage_target,       .usage = 0                            },
} ;

static int nodelib_direct_hasusage(lua_State *L)
{
    const char *str = lua_tostring(L, 1);
    if (str) {
        int target = lmt_optinteger(L, 2, 0);
        for (int i = 0; usage_data[i].name != NULL; i++) {
            if ((! target || usage_data[i].target == target) && ! strcmp(usage_data[i].name, str)) {
                lua_pushboolean(L, 1);
                return 1;
            }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int nodelib_direct_getusage(lua_State *L)
{
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            {
                const char *str = lua_tostring(L, 1);
                if (str) {
                    int target = lmt_optinteger(L, 2, 0);
                    for (int i = 0; usage_data[i].name != NULL; i++) {
                        if ((! target || usage_data[i].target == target) && ! strcmp(usage_data[i].name, str)) {
                            if (usage_data[i].usage & common_usage) {
                                lua_pushboolean(L, 1);
                            } else {
                                int n = 0;
                                lua_newtable(L);
                                for (int id = 0; id <= passive_node; id++) {
                                    lua_Integer bit = (lua_Integer) 1 << (id + 1);
                                    if (usage_data[i].usage & bit) {
                                        lua_pushinteger(L, id);
                                        lua_rawseti(L, -2, ++n);
                                    }
                                }
                            }
                            return 1;
                        }
                    }
                }
            }
            break;
        case LUA_TNUMBER:
            {
                int id = lua_tointeger(L, 1);
                if (id >= 0 && id <= passive_node) {
                    int target = lmt_optinteger(L, 2, 0);
                    lua_Integer bit = (lua_Integer) 1 << (id + 1);
                    int n = 0;
                    lua_newtable(L);
                    for (int i = 0; usage_data[i].name != NULL; i++) {
                        if ((! target || usage_data[i].target == target) && ((usage_data[i].usage & bit) || (usage_data[i].usage & common_usage))) {
                            lua_pushstring(L, usage_data[i].name);
                            lua_rawseti(L, -2, ++n);
                        }
                    }
                    return 1;
                }
            }
            break;
    }
    return 0;
}

/* node.direct.* */

static const struct luaL_Reg nodelib_direct_function_list[] = {

    { "addmargins",              nodelib_direct_addmargins             },
    { "addxoffset",              nodelib_direct_addxoffset             },
    { "addxymargins",            nodelib_direct_addxymargins           },
    { "addyoffset",              nodelib_direct_addyoffset             },
    { "appendaftertail",         nodelib_direct_appendaftertail        },
    { "beginofmath",             nodelib_direct_beginofmath            },
    { "checkdiscretionaries",    nodelib_direct_checkdiscretionaries   },
    { "checkdiscretionary",      nodelib_direct_checkdiscretionary     },
    { "collapsing",              nodelib_direct_collapsing             }, /*tex A funny name but like |ligaturing| and |hyphenating|. */
    { "copy",                    nodelib_direct_copy                   },
    { "copylist",                nodelib_direct_copylist               },
    { "copyonly",                nodelib_direct_copyonly               },
    { "count",                   nodelib_direct_count                  },
    { "currentattributes",       nodelib_direct_currentattributes      },
    { "dimensions",              nodelib_direct_dimensions             },
    { "effectiveglue",           nodelib_direct_effectiveglue          },
    { "endofmath",               nodelib_direct_endofmath              },
    { "exchange",                nodelib_direct_exchange               },
    { "findattribute",           nodelib_direct_findattribute          },
    { "findattributerange",      nodelib_direct_findattributerange     },
    { "findnode",                nodelib_direct_findnode               },
    { "firstchar",               nodelib_direct_firstchar              },
    { "firstglyph",              nodelib_direct_firstglyph             },
    { "firstglyphnode",          nodelib_direct_firstglyphnode         },
    { "firstitalicglyph",        nodelib_direct_firstitalicglyph       },
    { "flattendiscretionaries",  nodelib_direct_flattendiscretionaries },
    { "flattenleaders",          nodelib_direct_flattenleaders         },
    { "flushlist",               nodelib_direct_flushlist              },
    { "flushnode",               nodelib_direct_flushnode              },
    { "free",                    nodelib_direct_free                   },
    { "freeze",                  nodelib_direct_freeze                 },
    { "getanchors",              nodelib_direct_getanchors             },
    { "getattribute",            nodelib_direct_getattribute           },
    { "getattributelist",        nodelib_direct_getattributelist       },
    { "getattributes",           nodelib_direct_getattributes          },
    { "getboth",                 nodelib_direct_getboth                },
    { "getbottom",               nodelib_direct_getbottom              },
    { "getbottomdelimiter",      nodelib_direct_getbottomdelimiter     },
    { "getbox",                  nodelib_direct_getbox                 },
    { "getchar",                 nodelib_direct_getchar                },
    { "getchardict",             nodelib_direct_getchardict            },
    { "getcharspec",             nodelib_direct_getcharspec            },
    { "getchoice",               nodelib_direct_getchoice              },
    { "getclass",                nodelib_direct_getclass               },
    { "getcontrol",              nodelib_direct_getcontrol             },
    { "getcornerkerns",          nodelib_direct_getcornerkerns         },
    { "getdata",                 nodelib_direct_getdata                },
    { "getdegree",               nodelib_direct_getdegree              },
    { "getdelimiter",            nodelib_direct_getdelimiter           },
    { "getdenominator",          nodelib_direct_getdenominator         },
    { "getdepth",                nodelib_direct_getdepth               },
    { "getdirection",            nodelib_direct_getdirection           },
    { "getdisc",                 nodelib_direct_getdisc                },
    { "getdiscpart",             nodelib_direct_getdiscpart            },
    { "getexcept",               nodelib_direct_getexcept              },
    { "getexpansion",            nodelib_direct_getexpansion           },
    { "getfam",                  nodelib_direct_getfam                 },
    { "getfield",                nodelib_direct_getfield               },
    { "getfont",                 nodelib_direct_getfont                },
    { "getgeometry",             nodelib_direct_getgeometry            },
    { "getglue",                 nodelib_direct_getglue                },
    { "getglyphdata",            nodelib_direct_getglyphdata           },
    { "getglyphdimensions",      nodelib_direct_getglyphdimensions     },
    { "getheight",               nodelib_direct_getheight              },
    { "getid",                   nodelib_direct_getid                  },
    { "getindex",                nodelib_direct_getindex               },
    { "getinputfields",          nodelib_direct_getinputfields         },
    { "getkern",                 nodelib_direct_getkern                },
    { "getkerndimension",        nodelib_direct_getkerndimension       },
    { "getlanguage",             nodelib_direct_getlanguage            },
    { "getleader",               nodelib_direct_getleader              },
    { "getleftdelimiter",        nodelib_direct_getleftdelimiter       },
    { "getlist",                 nodelib_direct_getlist                },
    { "getlistdimensions",       nodelib_direct_getlistdimensions      },
    { "getnext",                 nodelib_direct_getnext                },
    { "getnodes",                nodelib_direct_getnodes               },
    { "getnormalizedline",       nodelib_direct_getnormalizedline      },
    { "getnucleus",              nodelib_direct_getnucleus             },
    { "getnumerator",            nodelib_direct_getnumerator           },
    { "getoffsets",              nodelib_direct_getoffsets             },
    { "getoptions",              nodelib_direct_getoptions             },
    { "getorientation",          nodelib_direct_getorientation         },
    { "getparstate",             nodelib_direct_getparstate            },
    { "getpenalty",              nodelib_direct_getpenalty             },
    { "getpost",                 nodelib_direct_getpost                },
    { "getpre",                  nodelib_direct_getpre                 },
    { "getprev",                 nodelib_direct_getprev                },
    { "getprime",                nodelib_direct_getprime               },
    { "getpropertiestable",      nodelib_direct_getpropertiestable     },
    { "getproperty",             nodelib_direct_getproperty            },
    { "getreplace",              nodelib_direct_getreplace             },
    { "getrightdelimiter",       nodelib_direct_getrightdelimiter      },
    { "getruledimensions",       nodelib_direct_getruledimensions      },
    { "getscale",                nodelib_direct_getscale               },
    { "getscales",               nodelib_direct_getscales              },
    { "getscript",               nodelib_direct_getscript              },
    { "getscripts",              nodelib_direct_getscripts             },
    { "getshift",                nodelib_direct_getshift               },
    { "getslant",                nodelib_direct_getslant               },
    { "getspeciallist",          nodelib_direct_getspeciallist         },
    { "getstate",                nodelib_direct_getstate               },
    { "getsub",                  nodelib_direct_getsub                 },
    { "getsubpre",               nodelib_direct_getsubpre              },
    { "getsubtype",              nodelib_direct_getsubtype             },
    { "getsup",                  nodelib_direct_getsup                 },
    { "getsuppre",               nodelib_direct_getsuppre              },
    { "gettop",                  nodelib_direct_gettop                 },
    { "gettopdelimiter",         nodelib_direct_gettopdelimiter        },
    { "gettotal" ,               nodelib_direct_gettotal               },
    { "getusage",                nodelib_direct_getusage               },
    { "getusedattributes",       nodelib_direct_getusedattributes      },
    { "getweight",               nodelib_direct_getweight              },
    { "getwhd",                  nodelib_direct_getwhd                 },
    { "getwidth",                nodelib_direct_getwidth               },
    { "getwordrange",            nodelib_direct_getwordrange           },
    { "getxscale",               nodelib_direct_getxscale              },
    { "getxyscales",             nodelib_direct_getxyscales            },
    { "getyscale",               nodelib_direct_getyscale              },
    { "hasattribute",            nodelib_direct_hasattribute           },
    { "hasdimensions",           nodelib_direct_hasdimensions          },
    { "hasdiscoption",           nodelib_direct_hasdiscoption          },
    { "hasfield",                nodelib_direct_hasfield               },
    { "hasgeometry",             nodelib_direct_hasgeometry            },
    { "hasglyph",                nodelib_direct_hasglyph               },
    { "hasglyphoption",          nodelib_direct_hasglyphoption         },
    { "hasusage",                nodelib_direct_hasusage               },
    { "hpack",                   nodelib_direct_hpack                  },
    { "hyphenating",             nodelib_direct_hyphenating            },
    { "ignoremathskip",          nodelib_direct_ignoremathskip         },
    { "insertafter",             nodelib_direct_insertafter            },
    { "insertbefore",            nodelib_direct_insertbefore           },
    { "isboth",                  nodelib_direct_isboth                 },
    { "ischar",                  nodelib_direct_ischar                 },
    { "isdirect",                nodelib_direct_isdirect               },
    { "isglyph",                 nodelib_direct_isglyph                },
    { "isitalicglyph",           nodelib_direct_isitalicglyph          },
    { "isloop",                  nodelib_direct_isloop                 },
    { "isnext",                  nodelib_direct_isnext                 },
    { "isnextchar",              nodelib_direct_isnextchar             },
    { "isnextglyph",             nodelib_direct_isnextglyph            },
    { "isnode",                  nodelib_direct_isnode                 },
    { "isprev",                  nodelib_direct_isprev                 },
    { "isprevchar",              nodelib_direct_isprevchar             },
    { "isprevglyph",             nodelib_direct_isprevglyph            },
    { "issimilarglyph",          nodelib_direct_issimilarglyph         },
    { "isspeciallist",           nodelib_direct_isspeciallist          },
    { "isvalid",                 nodelib_direct_isvalid                },
    { "iszeroglue",              nodelib_direct_iszeroglue             },
    { "kerning",                 nodelib_direct_kerning                },
    { "lastnode",                nodelib_direct_lastnode               },
    { "length",                  nodelib_direct_length                 },
    { "ligaturing",              nodelib_direct_ligaturing             },
    { "makeextensible",          nodelib_direct_makeextensible         },
    { "migrate",                 nodelib_direct_migrate                },
    { "mlisttohlist",            nodelib_direct_mlisttohlist           },
    { "naturalhsize",            nodelib_direct_naturalhsize           },
    { "naturalwidth",            nodelib_direct_naturalwidth           },
    { "new",                     nodelib_direct_new                    },
    { "newcontinuationatom",     nodelib_direct_newcontinuationatom    },
    { "newmathglyph",            nodelib_direct_newmathglyph           },
    { "newtextglyph",            nodelib_direct_newtextglyph           },
    { "patchattributes",         nodelib_direct_patchattributes        },
    { "patchparshape",           nodelib_direct_patchparshape          },
    { "prependbeforehead",       nodelib_direct_prependbeforehead      },
    { "protectglyph",            nodelib_direct_protectglyph           },
    { "protectglyphs",           nodelib_direct_protectglyphs          },
    { "protectglyphsnone",       nodelib_direct_protectglyphsnone      },
    { "protrusionskippable",     nodelib_direct_protrusionskipable     },
    { "rangedimensions",         nodelib_direct_rangedimensions        }, /* maybe get... */
    { "remove",                  nodelib_direct_remove                 },
    { "removefromlist",          nodelib_direct_removefromlist         },
    { "repack",                  nodelib_direct_repack                 },
    { "reverse",                 nodelib_direct_reverse                },
    { "serialized",              nodelib_direct_serialized             },
    { "setanchors",              nodelib_direct_setanchors             },
    { "setattribute",            nodelib_direct_setattribute           },
    { "setattributelist",        nodelib_direct_setattributelist       },
    { "setattributes",           nodelib_direct_setattributes          },
    { "setboth",                 nodelib_direct_setboth                },
    { "setbottom",               nodelib_direct_setbottom              },
    { "setbottomdelimiter",      nodelib_direct_setbottomdelimiter     },
    { "setbox",                  nodelib_direct_setbox                 },
    { "setchar",                 nodelib_direct_setchar                },
    { "setchardict",             nodelib_direct_setchardict            },
    { "setchoice",               nodelib_direct_setchoice              },
    { "setclass",                nodelib_direct_setclass               },
    { "setcontrol",              nodelib_direct_setcontrol             },
    { "setdata",                 nodelib_direct_setdata                },
    { "setdegree",               nodelib_direct_setdegree              },
    { "setdelimiter",            nodelib_direct_setdelimiter           },
    { "setdenominator",          nodelib_direct_setdenominator         },
    { "setdepth",                nodelib_direct_setdepth               },
    { "setdirection",            nodelib_direct_setdirection           },
    { "setdisc",                 nodelib_direct_setdisc                },
    { "setdiscpart",             nodelib_direct_setdiscpart            },
    { "setexcept",               nodelib_direct_setexcept              },
    { "setexpansion",            nodelib_direct_setexpansion           },
    { "setfam",                  nodelib_direct_setfam                 },
    { "setfield",                nodelib_direct_setfield               },
    { "setfont",                 nodelib_direct_setfont                },
    { "setgeometry",             nodelib_direct_setgeometry            },
    { "setglue",                 nodelib_direct_setglue                },
    { "setglyphdata",            nodelib_direct_setglyphdata           },
    { "setheight",               nodelib_direct_setheight              },
    { "setindex",                nodelib_direct_setindex               },
    { "setinputfields",          nodelib_direct_setinputfields         },
    { "setkern",                 nodelib_direct_setkern                },
    { "setlanguage",             nodelib_direct_setlanguage            },
    { "setleader",               nodelib_direct_setleader              },
    { "setleftdelimiter",        nodelib_direct_setleftdelimiter       },
    { "setlink",                 nodelib_direct_setlink                },
    { "setlist",                 nodelib_direct_setlist                },
    { "setnext",                 nodelib_direct_setnext                },
    { "setnucleus",              nodelib_direct_setnucleus             },
    { "setnumerator",            nodelib_direct_setnumerator           },
    { "setoffsets",              nodelib_direct_setoffsets             },
    { "setoptions",              nodelib_direct_setoptions             },
    { "setorientation",          nodelib_direct_setorientation         },
    { "setpenalty",              nodelib_direct_setpenalty             },
    { "setpost",                 nodelib_direct_setpost                },
    { "setpre",                  nodelib_direct_setpre                 },
    { "setprev",                 nodelib_direct_setprev                },
    { "setprime" ,               nodelib_direct_setprime               },
    { "setproperty",             nodelib_direct_setproperty            },
    { "setreplace",              nodelib_direct_setreplace             },
    { "setrightdelimiter",       nodelib_direct_setrightdelimiter      },
    { "setruledimensions",       nodelib_direct_setruledimensions      },
    { "setscale",                nodelib_direct_setscale               },
    { "setscales",               nodelib_direct_setscales              },
    { "setscript",               nodelib_direct_setscript              },
    { "setscripts",              nodelib_direct_setscripts             },
    { "setshift",                nodelib_direct_setshift               },
    { "setslant",                nodelib_direct_setslant               },
    { "setspeciallist",          nodelib_direct_setspeciallist         },
    { "setsplit",                nodelib_direct_setsplit               },
    { "setstate",                nodelib_direct_setstate               },
    { "setsub",                  nodelib_direct_setsub                 },
    { "setsubpre",               nodelib_direct_setsubpre              },
    { "setsubtype",              nodelib_direct_setsubtype             },
    { "setsup",                  nodelib_direct_setsup                 },
    { "setsuppre",               nodelib_direct_setsuppre              },
    { "settop" ,                 nodelib_direct_settop                 },
    { "settopdelimiter",         nodelib_direct_settopdelimiter        },
    { "settotal" ,               nodelib_direct_settotal               },
    { "setweight",               nodelib_direct_setweight              },
    { "setwhd",                  nodelib_direct_setwhd                 },
    { "setwidth",                nodelib_direct_setwidth               },
    { "show",                    nodelib_direct_show                   },
    { "slide",                   nodelib_direct_slide                  },
    { "softenhyphens",           nodelib_direct_softenhyphens          },
    { "startofpar",              nodelib_direct_startofpar             },
    { "tail",                    nodelib_direct_tail                   },
    { "tostring",                nodelib_direct_tostring               },
    { "tovaliddirect",           nodelib_direct_tovaliddirect          },
    { "traverse",                nodelib_direct_traverse               },
    { "traversechar",            nodelib_direct_traversechar           },
    { "traversecontent",         nodelib_direct_traversecontent        },
    { "traverseglyph",           nodelib_direct_traverseglyph          },
    { "traverseid",              nodelib_direct_traverseid             },
    { "traverseitalic",          nodelib_direct_traverseitalic         },
    { "traverseleader",          nodelib_direct_traverseleader         },
    { "traverselist",            nodelib_direct_traverselist           },
    { "unprotectglyph",          nodelib_direct_unprotectglyph         },
    { "unprotectglyphs",         nodelib_direct_unprotectglyphs        },
    { "unsetattribute",          nodelib_direct_unsetattribute         },
    { "unsetattributes",         nodelib_direct_unsetattributes        },
    { "usedlist",                nodelib_direct_usedlist               },
    { "usesfont",                nodelib_direct_usesfont               },
    { "verticalbreak",           nodelib_direct_verticalbreak          },
    { "vpack",                   nodelib_direct_vpack                  },
    { "write",                   nodelib_direct_write                  },
    { "xscaled",                 nodelib_direct_xscaled                },
    { "yscaled",                 nodelib_direct_yscaled                },
 /* { "appendtocurrentlist",     nodelib_direct_appendtocurrentlist    }, */ /* beware, we conflict in ctx */

    { "gluetostring",            nodelib_hybrid_gluetostring           },
    { "type",                    nodelib_hybrid_type                   },

    { "fields",                  nodelib_shared_fields                 },
    { "getcachestate",           nodelib_shared_getcachestate          },
    { "id",                      nodelib_shared_id                     },
    { "size",                    nodelib_shared_size                   },
    { "subtypes",                nodelib_shared_subtypes               },
    { "todirect",                nodelib_shared_todirect               },
    { "tonode",                  nodelib_shared_tonode                 },
    { "types",                   nodelib_shared_types                  },
 /* { "values",                  nodelib_shared_values                 }, */ /* finally all are now in tex. */

    { "setfielderror",            nodelib_shared_setfielderror         }, /* private */
    { "getfielderror",            nodelib_shared_getfielderror         }, /* private */

    { NULL,                      NULL                                  },

};

/* node.* */

static const struct luaL_Reg nodelib_function_list[] = {

    { "copy",                     nodelib_userdata_copy                 },
    { "copylist",                 nodelib_userdata_copylist             },
    { "currentattributes",        nodelib_userdata_currentattributes    },
    { "flushlist",                nodelib_userdata_flushlist            },
    { "flushnode",                nodelib_userdata_flushnode            },
    { "free",                     nodelib_userdata_free                 },
    { "getattribute",             nodelib_userdata_getattribute         },
    { "getfield",                 nodelib_userdata_getfield             },
    { "getpropertiestable",       nodelib_userdata_getpropertiestable   },
    { "getproperty",              nodelib_userdata_getproperty          },
    { "hasattribute",             nodelib_userdata_hasattribute         },
    { "hasfield",                 nodelib_userdata_hasfield             },
    { "insertafter",              nodelib_userdata_insertafter          },
    { "insertbefore",             nodelib_userdata_insertbefore         },
    { "instock",                  nodelib_userdata_instock              },
    { "inuse",                    nodelib_userdata_inuse                },
    { "isnode",                   nodelib_userdata_isnode               },
    { "new",                      nodelib_userdata_new                  },
    { "remove",                   nodelib_userdata_remove               },
    { "serialized",               nodelib_userdata_serialized           },
    { "setattribute",             nodelib_userdata_setattribute         },
    { "setfield",                 nodelib_userdata_setfield             },
    { "setproperty",              nodelib_userdata_setproperty          },
    { "show",                     nodelib_userdata_show                 },
    { "tail",                     nodelib_userdata_tail                 },
    { "tostring",                 nodelib_userdata_tostring             },
    { "traverse",                 nodelib_userdata_traverse             },
    { "traverseid",               nodelib_userdata_traverse_id          },
    { "unsetattribute",           nodelib_userdata_unsetattribute       },
    { "usedlist",                 nodelib_userdata_usedlist             },
    { "write",                    nodelib_userdata_write                },
 /* { "appendtocurrentlist",      nodelib_userdata_append               }, */ /* beware, we conflict in ctx */

    { "gluetostring",             nodelib_hybrid_gluetostring           },
    { "type",                     nodelib_hybrid_type                   },

    { "fields",                   nodelib_shared_fields                 },
    { "getcachestate",            nodelib_shared_getcachestate          },
    { "id",                       nodelib_shared_id                     },
    { "size",                     nodelib_shared_size                   },
    { "subtypes",                 nodelib_shared_subtypes               },
    { "todirect",                 nodelib_shared_todirect               },
    { "tonode",                   nodelib_shared_tonode                 },
    { "types",                    nodelib_shared_types                  },
 /* { "values",                   nodelib_shared_values                 }, */ /* finally all are now in tex. */

    { "setfielderror",            nodelib_shared_setfielderror          }, /* private */
    { "getfielderror",            nodelib_shared_getfielderror          }, /* private */

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
            lmt_push_par_trigger(L, context);
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
                        *tail = tex_tail_of_node_list(head);
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
    halfword  head,
    int       isbroken, /* display_math */
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
    halfword callback,
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
                lua_pushinteger(L, callback);
                lmt_node_list_to_lua(L, attrlist);
                lmt_node_list_to_lua(L, preamble);
                i = lmt_callback_call(L, 5, 0, top);
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

/* watch the -3 here, we skip over the repeat boolean  */

# define get_dimension_par(P,A,B) \
    lua_push_key(A); \
    P = (lua_rawget(L, -3) == LUA_TNUMBER) ? lmt_roundnumber(L, -1) : B; \
    lua_pop(L, 1);

# define get_integer_par(P,A,B) \
    lua_push_key(A); \
    P = (lua_rawget(L, -3) == LUA_TNUMBER) ? lmt_tohalfword(L, -1) : B; \
    lua_pop(L, 1);

int lmt_par_pass_callback(
    halfword               head,
    line_break_properties *properties,
    halfword               identifier,
    halfword               subpass,
    halfword               callback,
    halfword               features,
    scaled                 overfull,
    scaled                 underfull,
    halfword               verdict,
    halfword               classified,
    scaled                 threshold,
    halfword               demerits,
    halfword               classes,
    int                   *repeat
)
{
 // if (head) {
        int callback_id = lmt_callback_defined(paragraph_pass_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            int result = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, head);
                lua_push_integer(L, identifier);
                lua_push_integer(L, subpass);
                lua_push_integer(L, callback);
                lua_push_integer(L, overfull);
                lua_push_integer(L, underfull);
                lua_push_integer(L, verdict);
                lua_push_integer(L, classified);
                lua_push_integer(L, threshold);
                lua_push_integer(L, demerits);
                lua_push_integer(L, classes);
                i = lmt_callback_call(L, 10, 2, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    switch (lua_type(L, -2)) {
                        case LUA_TBOOLEAN:
                            {
                                result = lua_toboolean(L, -2);
                                break;
                            }
                        case LUA_TTABLE:
                            {
                                /*tex
                                    This is untested and might go away at some point.
                                */
                                get_integer_par(properties->tolerance, tolerance, properties->tolerance);
                                lmt_linebreak_state.threshold = properties->tolerance;
                                lmt_linebreak_state.global_threshold = lmt_linebreak_state.threshold;
                                get_integer_par(properties->line_penalty, linepenalty, properties->line_penalty);
                                get_integer_par(properties->left_twin_demerits, lefttwindemerits, properties->left_twin_demerits);
                                get_integer_par(properties->right_twin_demerits, righttwindemerits, properties->right_twin_demerits);
                                get_integer_par(properties->extra_hyphen_penalty, extrahyphenpenalty, properties->extra_hyphen_penalty);
                                get_integer_par(properties->double_hyphen_demerits, doublehyphendemerits, properties->double_hyphen_demerits);
                                get_integer_par(properties->final_hyphen_demerits, finalhyphendemerits, properties->final_hyphen_demerits);
                                get_integer_par(properties->adj_demerits, adjdemerits, properties->adj_demerits);
                                get_dimension_par(properties->emergency_stretch, emergencystretch, properties->emergency_stretch);
                                get_integer_par(properties->adjust_spacing_step, adjustspacingstep, properties->adjust_spacing_step);
                                get_integer_par(properties->adjust_spacing_shrink, adjustspacingshrink, properties->adjust_spacing_shrink);
                                get_integer_par(properties->adjust_spacing_stretch, adjustspacingstretch, properties->adjust_spacing_stretch);
                                get_integer_par(properties->adjust_spacing, adjustspacing, properties->adjust_spacing);
                                get_integer_par(properties->line_break_optional, optional, properties->line_break_optional);
                                get_integer_par(properties->line_break_checks, linebreakchecks, properties->line_break_checks);
                                get_integer_par(properties->math_penalty_factor, mathpenaltyfactor, properties->math_penalty_factor);
                                get_integer_par(properties->sf_factor, sffactor, properties->sf_factor);
                                get_integer_par(properties->sf_stretch_factor, sfstretchfactor, properties->sf_stretch_factor);
                                /*tex
                                    These are not properties (yet, but we could just add these as hidden fields):

                                    emergencyfactor
                                    emergencypercentage
                                    emergencyleftextra
                                    emergencyrightextra
                                    emergencywidthextra

                                    These make no sense here:

                                    fitnessdemerits
                                    hyphenation

                                */
                                result = 1;
                                break;
                            }
                        default:
                            {
                                /* just quit */
                                break;
                            }
                    }
                    if (lua_type(L, -1) == LUA_TBOOLEAN) {
                        *repeat = lua_toboolean(L, -1);
                    }
                }
            }
            lmt_callback_wrapup(L, top);
            return result;
        }
 // }
    return 0;
}

halfword lmt_uleader_callback(
    halfword    head,
    halfword    index,
    int         context,
    halfword    box,
    int         location
)
{
    if (head) {
        int callback_id = lmt_callback_defined(handle_uleader_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, head);
             // lua_pushinteger(L, context);
                lmt_push_group_code(L, context);
                lua_pushinteger(L, index);
                lmt_node_list_to_lua(L, box);
                lua_pushinteger(L, location); /* maybe also string */
                i = lmt_callback_call(L, 5, 1, top);
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

void lmt_insert_par_callback(
    halfword node,
    halfword mode
)
{
    int callback_id = lmt_callback_defined(insert_par_callback);
    if (callback_id > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int top = 0;
        if (lmt_callback_okay(L, callback_id, &top)) {
            int i;
            lmt_node_list_to_lua(L, node);
            lmt_push_par_mode(L, mode);
            i = lmt_callback_call(L, 2, 0, top);
            if (i) {
                lmt_callback_error(L, top, i);
            } else {
                lmt_callback_wrapup(L, top);
            }
        }
    }
}

scaled lmt_italic_correction_callback(
    halfword glyph,
    scaled   kern,
    halfword subtype
)
{
    int callback_id = lmt_callback_defined(italic_correction_callback);
    if (callback_id > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int top = 0;
        if (lmt_callback_okay(L, callback_id, &top)) {
            int i;
            lmt_node_list_to_lua(L, glyph);
            lua_pushinteger(L, kern);
            lua_pushinteger(L, subtype);
            i = lmt_callback_call(L, 3, 1, top);
            if (i) {
                lmt_callback_error(L, top, i);
            } else {
                kern = lmt_tohalfword(L, -1);
                lmt_callback_wrapup(L, top);
            }
        }
    }
    return kern;
}
