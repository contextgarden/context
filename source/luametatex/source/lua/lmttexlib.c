/*
    See license.txt in the root of this project.
*/

/*

    This module deals with access to some if the internal quanities of \TEX, like registers,
    internal variables and all kind of lists. Because we provide access by name and/or number
    (index) there is quite a bit of code here, and sometimes if can look a bit confusing.

    The code here differs from \LUATEX\ in the sense that there are some more checks, a bit
    more abstraction, more access and better performance. What we see here is the result of
    years of experimenting and usage in \CONTEXT.

    A remark about some of the special node lists that one can query: because some start with
    a so called |temp| node, we have to set the |prev| link to |nil| because otherwise at the
    \LUA\ end we expose that |temp| node and users are not suposed to touch them! In the setter
    no |prev| link is set so we can presume that it's not used later on anyway; this is because
    original \TEX\ has no |prev| links.

    There is still room for improvement but I'll deal with that when I have a reason (read: when
    I need something).

*/

# include "luametatex.h"

/*tex
    Due to the nature of the accessors, this is the module with most metatables. However, we
    provide getters and setters too. Users can choose what they like most.
*/

# define TEX_METATABLE_ATTRIBUTE "tex.attribute"
# define TEX_METATABLE_SKIP      "tex.skip"
# define TEX_METATABLE_GLUE      "tex.glue"
# define TEX_METATABLE_MUSKIP    "tex.muskip"
# define TEX_METATABLE_MUGLUE    "tex.muglue"
# define TEX_METATABLE_DIMEN     "tex.dimen"
# define TEX_METATABLE_COUNT     "tex.count"
# define TEX_METATABLE_TOKS      "tex.toks"
# define TEX_METATABLE_BOX       "tex.box"
# define TEX_METATABLE_SFCODE    "tex.sfcode"
# define TEX_METATABLE_LCCODE    "tex.lccode"
# define TEX_METATABLE_UCCODE    "tex.uccode"
# define TEX_METATABLE_HCCODE    "tex.hccode"
# define TEX_METATABLE_HMCODE    "tex.hmcode"
# define TEX_METATABLE_CATCODE   "tex.catcode"
# define TEX_METATABLE_MATHCODE  "tex.mathcode"
# define TEX_METATABLE_DELCODE   "tex.delcode"
# define TEX_METATABLE_LISTS     "tex.lists"
# define TEX_METATABLE_NEST      "tex.nest"

# define TEX_METATABLE_TEX       "tex.tex"

# define TEX_NEST_INSTANCE       "tex.nest.instance"

/*tex Let's share these. */

static void texlib_aux_show_box_index_error(lua_State *L)
{
    luaL_error(L, "invalid index passed, range 0.." LMT_TOSTRING(max_box_register_index) " or name expected");
}

static void texlib_aux_show_character_error(lua_State *L, int i)
{
    luaL_error(L, "invalid character value %d passed, range 0.." LMT_TOSTRING(max_character_code), i);
}

static void texlib_aux_show_catcode_error(lua_State *L, int i)
{
    luaL_error(L, "invalid catcode %d passed, range 0.." LMT_TOSTRING(max_category_code), i);
}

static void texlib_aux_show_family_error(lua_State *L, int i)
{
    luaL_error(L, "invalid family %d passed, range 0.." LMT_TOSTRING(max_math_family_index), i);
}

static void texlib_aux_show_class_error(lua_State *L, int i)
{
    luaL_error(L, "invalid class %d passed, range 0.." LMT_TOSTRING(max_math_class_code), i);
}

static void texlib_aux_show_half_error(lua_State *L, int i)
{
    luaL_error(L, "invalid value %d passed, range 0.." LMT_TOSTRING(max_half_value), i);
}

/*tex

    The rope model dates from the time that we had multiple \LUA\ instances so probably we can
    simplify it a bit. On the other hand, it works, and also is upgraded for nodes, tokens and some
    caching, so there is no real need to change anything now. A complication is anyway that input
    states can nest and any change can mess it up.

    We use a flag to indicate the kind of data that we are dealing with:

    \starttabulate
    \NC 0 \NC string \NC \NR
    \NC 1 \NC char   \NC \NR
    \NC 2 \NC token  \NC \NR
    \NC 3 \NC node   \NC \NR
    \stoptabulate

    By treating simple \ASCII\ characters special we prevent mallocs. We also pack small strings if
    only because we have the room available anyway (due to padding).

    For quite a while we used to have this:

    \starttyping
    typedef struct spindle_char {
        unsigned char c1, c2, c3, c4;
    } spindle_char;

    typedef union spindle_data {
        spindle_char c;
        halfword      h;
    } spindle_data;
    \stopttyping

    The spindle and rope terminology was introduced by Taco early in the development of \LUATEX,
    but in the meantime the datastructures have been adapted to deal with tokens and nodes. There
    are also quite some optimizations in performance and memort usage (e.g. for small strings and 
    single characters). 

*/

# define FULL_LINE         0
# define PARTIAL_LINE      1
# define PACKED_SIZE       8
# define INITIAL_SIZE     32
# define MAX_ROPE_CACHE 5000

typedef union spindle_data {
    unsigned char  c[PACKED_SIZE];
    halfword       h;
    char          *t;
} spindle_data;

typedef struct spindle_rope {
//  char          *text;
    void          *next;
    union { 
        unsigned int tsize;
        halfword     tail;
    };
    unsigned char  kind;
    unsigned char  partial;
    short          cattable;
    spindle_data   data;
    /* alignment, not needed when we have c[PACKED_SIZE] */
 /* int            padding; */
} spindle_rope;

typedef struct spindle {
    spindle_rope *head;
    spindle_rope *tail;
    int           complete;
    /* alignment */
    int           padding;
} spindle;

typedef struct spindle_state_info {
    int           spindle_size;
    int           spindle_index;
    spindle      *spindles;
    spindle_rope *rope_cache;
    int           rope_count;
    /* alignment */
    int           padding;
} spindle_state_info ;

static spindle_state_info lmt_spindle_state = {
    .spindle_size  = 0,
    .spindle_index = 0,
    .spindles      = NULL,
    .rope_cache    = NULL,
    .rope_count    = 0,
    .padding       = 0
};

# define write_spindle lmt_spindle_state.spindles[lmt_spindle_state.spindle_index]
# define read_spindle  lmt_spindle_state.spindles[lmt_spindle_state.spindle_index - 1]

inline static void texlib_aux_reset_spindle(int i)
{
    lmt_spindle_state.spindles[i].head = NULL;
    lmt_spindle_state.spindles[i].tail = NULL;
    lmt_spindle_state.spindles[i].complete = 0;
}

/*

    Each rope takes 48 bytes. So, caching some 100 K ropes is not really a problem. In practice we
    seldom reach that number anyway.

*/

inline static spindle_rope *texlib_aux_new_rope(void)
{
    spindle_rope *r;
    if (lmt_spindle_state.rope_cache) {
        r = lmt_spindle_state.rope_cache;
        lmt_spindle_state.rope_cache = r->next;
    } else {
        r = (spindle_rope *) lmt_memory_malloc(sizeof(spindle_rope));
        ++lmt_spindle_state.rope_count;
        if (r) {
            r->next = NULL;
        } else {
            tex_overflow_error("spindle", sizeof(spindle_rope));
        }
    }
    return r;
}

inline static void texlib_aux_dispose_rope(spindle_rope *r)
{
    if (r) {
        if (lmt_spindle_state.rope_count > MAX_ROPE_CACHE) {
            lmt_memory_free(r);
            --lmt_spindle_state.rope_count;
        } else {
            r->next = lmt_spindle_state.rope_cache;
            lmt_spindle_state.rope_cache = r;
        }
    }
}

static void texlib_aux_initialize(void)
{
    lmt_spindle_state.spindles = lmt_memory_malloc(INITIAL_SIZE * sizeof(spindle));
    if (lmt_spindle_state.spindles) {
        for (int i = 0; i < INITIAL_SIZE; i++) {
            texlib_aux_reset_spindle(i);
        }
        lmt_spindle_state.spindle_index = 0;
        lmt_spindle_state.spindle_size = INITIAL_SIZE;
    } else {
        tex_overflow_error("spindle", sizeof(spindle));
    }
}

/*tex
    We could convert strings into tokenlists here but conceptually the split is cleaner.
*/

static int texlib_aux_store(lua_State *L, int i, int partial, int cattable)
{
    size_t tsize = 0;
    spindle_rope *rn = NULL;
    unsigned char kind = unset_lua_input;
    spindle_data data = { .h = 0 };
    switch (lua_type(L, i)) {
        case LUA_TNUMBER:
        case LUA_TSTRING:
            {
                const char *sttemp = lua_tolstring(L, i, &tsize);
                if (! partial) {
                    while (tsize > 0 && sttemp[tsize-1] == ' ') {
                        tsize--;
                    }
                }
                if (tsize > PACKED_SIZE) {
                    data.t = lmt_memory_malloc(tsize + 1);
                    kind = string_lua_input;
                    if (data.t) {
                        memcpy(data.t, sttemp, (tsize + 1));
                        break;
                    } else {
                        return 0;
                    }
                } else {
                    /*tex
                        We could append to a previous but partial interferes and in practice it then
                        never can be done.
                    */
                    for (unsigned i = 0; i < tsize; i++) {
                        /*tex When we end up here we often don't have that many bytes. */
                        data.c[i] = (unsigned char) sttemp[i];
                    }
                    kind = packed_lua_input;
                }
            }
            break;
        case LUA_TUSERDATA:
            {
                void *p = lua_touserdata(L, i);
                if (p && lua_getmetatable(L, i)) {
                    lua_get_metatablelua(token_instance);
                    if (lua_rawequal(L, -1, -2)) {
                        halfword token = (*((lua_token *) p)).token;
                        if (token_link(token)) {
                            /*tex
                                We cannnot pass a list unless we copy it, alternatively we can bump the ref count
                                but a quick test didn't work out that well.
                            */
                            token = token_link(token);
                            if (token) {
                                /*tex
                                    We're now past the ref count head. Like below we could actually append to a
                                    current rope but so far we seldom end up in here. Maybe I'll do add that later.
                                */
                                halfword t = null;
                                kind = token_list_lua_input;
                                data.h = tex_copy_token_list(token, &t);
                                tsize = t;
                            } else {
                                lua_pop(L, 2);
                                return 0;
                            }
                        } else {
                            /*tex
                                This is a little (mostly memory) optimization. We use token list instead of adding
                                single token ropes. That way we also need to push less back into the input. We
                                check for partial. This optimization is experimental and might go.
                            */
                            if (write_spindle.tail && write_spindle.tail->partial && partial == write_spindle.tail->partial) {
                                switch (write_spindle.tail->kind) {
                                    case token_lua_input:
                                        /*tex
                                            Okay, we now allocate a token but still pushing into the input later has
                                            less (nesting) overhead then because we process a sequence.
                                        */
                                        write_spindle.tail->kind = token_list_lua_input;
                                        write_spindle.tail->data.h = tex_store_new_token(null, write_spindle.tail->data.h);
                                        write_spindle.tail->tail = tex_store_new_token(write_spindle.tail->data.h, token_info(token));
                                        break;
                                    case token_list_lua_input:
                                        /*tex
                                            Normally we have short lists but it still pays off to store the tail
                                            in |tsize| instead of locating the tail each time.
                                        */
                                        write_spindle.tail->tail = tex_store_new_token(write_spindle.tail->tail, token_info(token));
                                        break;
                                    default:
                                        goto SINGLE;
                                }
                                lmt_token_state.luacstrings++; /* already set */
                                write_spindle.complete = 0; /* already set */
                                lua_pop(L, 2);
                                return 1;
                            }
                            /*tex The non-optimized case: */
                          SINGLE:
                            kind = token_lua_input;
                            data.h = token_info(token);
                        }
                        lua_pop(L, 2);
                    } else {
                        lua_get_metatablelua(node_instance);
                        if (lua_rawequal(L, -1, -3)) {
                            kind = node_lua_input;
                            data.h = *((halfword *) p);
                            lua_pop(L, 3);
                        } else {
                            lua_pop(L, 3);
                            return 0;
                        }
                    }
                } else {
                    return 0;
                }
            }
            break;
        default:
            return 0;
    }
    lmt_token_state.luacstrings++;
    rn = texlib_aux_new_rope();
    /* set */
    rn->tsize = (unsigned) tsize;
    rn->next = NULL;
    rn->kind = kind;
    rn->partial = (unsigned char) partial;
    rn->cattable = (short) cattable;
    rn->data = data;
    /* add */
    if (write_spindle.head) {
        write_spindle.tail->next = rn;
    } else {
        write_spindle.head = rn;
    }
    write_spindle.tail = rn;
    write_spindle.complete = 0;
    return 1;
}

static void texlib_aux_store_token(halfword token, int partial, int cattable)
{
    spindle_rope *rn = texlib_aux_new_rope();
    /* set */
    rn->tsize = 0;
    rn->next = NULL;
    rn->kind = token_lua_input;
    rn->partial = (unsigned char) partial;
    rn->cattable = (short) cattable;
    rn->data.h = token;
    /* add */
    if (write_spindle.head) {
        write_spindle.tail->next = rn;
    } else {
        write_spindle.head = rn;
    }
    write_spindle.tail = rn;
    write_spindle.complete = 0;
    lmt_token_state.luacstrings++;
}

static void lmx_aux_store_string(char *str, int len, int cattable)
{
    spindle_rope *rn = texlib_aux_new_rope();
    rn->data.h = 0; /* wipes */
    if (len > PACKED_SIZE) {
        rn->data.t = lmt_memory_malloc((size_t) len + 1);
        if (rn->data.t) {
            memcpy(rn->data.t, str, (size_t) len + 1);
        } else {
            len = 0;
        }
        rn->kind = string_lua_input;
    } else {
        for (int i = 0; i < len; i++) {
            /* when we end up here we often don't have that many bytes */
            rn->data.c[i] = (unsigned char) str[i];
        }
        rn->kind = packed_lua_input;
    }
    /* set */
    rn->tsize = (unsigned) len;
    rn->next = NULL;
    rn->partial = FULL_LINE;
    rn->cattable = (unsigned char) cattable;
    /* add */
    if (write_spindle.head) {
        write_spindle.tail->next = rn;
    } else {
        write_spindle.head = rn;
    }
    write_spindle.tail = rn;
    write_spindle.complete = 0;
    lmt_token_state.luacstrings++;
}

static int texlib_aux_cprint(lua_State *L, int partial, int cattable, int startstrings)
{
    int n = lua_gettop(L);
    int t = lua_type(L, startstrings);
    if (n > startstrings && cattable != no_catcode_table_preset && t == LUA_TNUMBER) {
        cattable = lmt_tointeger(L, startstrings);
        ++startstrings;
        if (cattable != default_catcode_table_preset && cattable != no_catcode_table_preset && ! tex_valid_catcode_table(cattable)) {
            cattable = default_catcode_table_preset;
        }
        t = lua_type(L, startstrings);
    }
    if (t == LUA_TTABLE) {
        for (int i = 1;; i++) {
            lua_rawgeti(L, startstrings, i);
            if (texlib_aux_store(L, -1, partial, cattable)) {
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
                break;
            }
        }
    } else {
        for (int i = startstrings; i <= n; i++) {
            texlib_aux_store(L, i, partial, cattable);
        }
    }
    return 0;
}

/*tex
    We now feed back to be tokenized input from the \TEX\ end into the same handler as we use for
    \LUA. It saves code but more important is that we no longer need the pseudo files and lines
    that are kind of inefficient and depend on variable nodes.
*/

void lmt_cstring_store(char *str, int len, int cattable)
{
    lmx_aux_store_string(str, len, cattable);
}

void lmt_tstring_store(strnumber s, int cattable)
{
    lmx_aux_store_string((char *) str_string(s), (int) str_length(s), cattable);
}

/*tex
    This is a bit of a dirty trick, needed for an experiment and it's fast enough for our purpose.
*/

void lmt_cstring_print(int cattable, const char *s, int ispartial)
{
    lua_State *L = lmt_lua_state.lua_instance;
    int top = lua_gettop(L);
    lua_settop(L, 0);
    lua_pushinteger(L, cattable);
    lua_pushstring(L, s);
    texlib_aux_cprint(L, ispartial ? PARTIAL_LINE : FULL_LINE, default_catcode_table_preset, 1);
    lua_settop(L, top);
}

/* lua.write */

static int texlib_write(lua_State *L)
{
    return texlib_aux_cprint(L, FULL_LINE, no_catcode_table_preset, 1);
}

/* lua.print */

static int texlib_print(lua_State *L)
{
    return texlib_aux_cprint(L, FULL_LINE, default_catcode_table_preset, 1);
}

/* lua.sprint */

static int texlib_sprint(lua_State *L)
{
    return texlib_aux_cprint(L, PARTIAL_LINE, default_catcode_table_preset, 1);
}

static int texlib_mprint(lua_State *L)
{
    int ini = 1;
    if (tracing_nesting_par > 2) {
        tex_local_control_message("entering local control via (run) macro");
    }
    texlib_aux_store_token(token_val(end_local_cmd, 0), PARTIAL_LINE, default_catcode_table_preset);
    if (lmt_token_state.luacstrings > 0) {
        tex_lua_string_start();
    }
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        int cs = tex_string_locate(name, lname, 0);
        int cmd = eq_type(cs);
        if (is_call_cmd(cmd)) {
            texlib_aux_store_token(cs_token_flag + cs, PARTIAL_LINE, default_catcode_table_preset);
            ++ini;
        } else {
            tex_local_control_message("invalid (mprint) macro");
        }
    }
    if (lua_gettop(L) >= ini) {
        texlib_aux_cprint(L, PARTIAL_LINE, default_catcode_table_preset, ini);
    }
    if (tracing_nesting_par > 2) {
        tex_local_control_message("entering local control via mprint");
    }
    tex_local_control(1);
    return 0;
}

/* we default to obeymode */

static int texlib_pushlocal(lua_State *L)
{
    (void) L;
    if (tracing_nesting_par > 2) {
        tex_local_control_message("pushing local control");
    }
    texlib_aux_store_token(token_val(end_local_cmd, 0), PARTIAL_LINE, default_catcode_table_preset);
    if (lmt_token_state.luacstrings > 0) {
        tex_lua_string_start();
    }
    return 0;
}

static int texlib_poplocal(lua_State *L)
{
    (void) L;
    if (tracing_nesting_par > 2) {
        tex_local_control_message("entering local control via pop");
    }
    tex_local_control(1);
    return 0;
}

/* lua.cprint */

static int texlib_cprint(lua_State *L)
{
    /*tex
        We map a catcode to a pseudo cattable. So a negative value is a specific catcode with offset 1.
    */
    int cattable = lmt_tointeger(L, 1);
    if (cattable < 0 || cattable > 15) {
        cattable = - 12 - 0xFF ;
    } else {
        cattable = - cattable - 0xFF;
    }
    if (lua_type(L, 2) == LUA_TTABLE) {
        for (int i = 1; ; i++) {
            lua_rawgeti(L, 2, i);
            if (texlib_aux_store(L, -1, PARTIAL_LINE, cattable)) {
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
                break;
            }
        }
    } else {
        int n = lua_gettop(L);
        for (int i = 2; i <= n; i++) {
            texlib_aux_store(L, i, PARTIAL_LINE, cattable);
        }
    }
    return 0;
}

/* lua.tprint */

static int texlib_tprint(lua_State *L)
{
    int n = lua_gettop(L);
    for (int i = 1; i <= n; i++) {
        int cattable = default_catcode_table_preset;
        int startstrings = 1;
        if (lua_type(L, i) != LUA_TTABLE) {
            luaL_error(L, "no string to print");
        }
        lua_pushvalue(L, i); /* the table */
        lua_pushinteger(L, 1);
        lua_gettable(L, -2);
        if (lua_type(L, -1) == LUA_TNUMBER) {
            cattable = lmt_tointeger(L, -1);
            startstrings = 2;
            if (cattable != default_catcode_table_preset && cattable != no_catcode_table_preset && ! tex_valid_catcode_table(cattable)) {
                cattable = default_catcode_table_preset;
            }
        }
        lua_pop(L, 1);
        for (int j = startstrings; ; j++) {
            lua_pushinteger(L, j);
            lua_gettable(L, -2);
            if (texlib_aux_store(L, -1, PARTIAL_LINE, cattable)) {
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
                break;
            }
        }
        lua_pop(L, 1); /* the table */
    }
    return 0;
}

static int texlib_isprintable(lua_State* L)
{
    halfword okay = 0;
    switch (lua_type(L, 1)) {
        case LUA_TSTRING :
            okay = 1;
            break;
        case LUA_TUSERDATA :
            {
                if (lua_getmetatable(L, 1)) {
                    lua_get_metatablelua(token_instance);
                    if (lua_rawequal(L, -1, -2)) {
                        okay = 1;
                     // lua_pop(L, 2);
                    } else {
                        lua_get_metatablelua(node_instance);
                        if (lua_rawequal(L, -1, -3)) {
                            okay = 1;
                        }
                     // lua_pop(L, 3);
                    }
                }
                break;
            }
    }
    lua_pushboolean(L, okay);
    return 1;
}

/*tex We actually don't need to copy and could read from the string. */

int lmt_cstring_input(halfword *n, int *cattable, int *partial, int *finalline)
{
    spindle_rope *t = read_spindle.head;
    int ret = eof_tex_input ;
    if (! read_spindle.complete) {
        read_spindle.complete = 1;
        read_spindle.tail = NULL;
    }
    if (t) {
        switch (t->kind) {
            case string_lua_input:
                {
                    if (t->data.t) {
                        /*tex put that thing in the buffer */
                        int strsize = (int) t->tsize;
                        int newlast = lmt_fileio_state.io_first + strsize;
                        lmt_fileio_state.io_last = lmt_fileio_state.io_first;
                        if (tex_room_in_buffer(newlast)) {
                            memcpy(&lmt_fileio_state.io_buffer[lmt_fileio_state.io_last], &t->data.t[0], sizeof(unsigned char) * strsize);
                            lmt_fileio_state.io_last = newlast;
                            lmt_memory_free(t->data.t);
                            t->data.t = NULL;
                        } else {
                            return ret;
                        }
                    }
                    *cattable = t->cattable;
                    *partial = t->partial;
                    *finalline = (t->next == NULL);
                    ret = string_tex_input;
                    break;
                }
            case packed_lua_input:
                {
                    unsigned strsize = t->tsize;
                    int newlast = lmt_fileio_state.io_first + strsize;
                    lmt_fileio_state.io_last = lmt_fileio_state.io_first;
                    if (tex_room_in_buffer(newlast)) {
                        for (unsigned i = 0; i < strsize; i++) {
                            /* when we end up here we often don't have that many bytes */
                            lmt_fileio_state.io_buffer[lmt_fileio_state.io_last + i] = t->data.c[i];
                        }
                        lmt_fileio_state.io_last = newlast;
                        *cattable = t->cattable;
                        *partial = t->partial;
                        *finalline = (t->next == NULL);
                        ret = string_tex_input;
                    } else {
                        return ret;
                    }
                    break;
                }
            case token_lua_input:
                {
                    *n = t->data.h;
                    ret = token_tex_input;
                    break;
                }
            case token_list_lua_input:
                {
                    *n = t->data.h;
                    ret = token_list_tex_input;
                    break;
                }
            case node_lua_input:
                {
                    *n = t->data.h;
                    ret = node_tex_input;
                    break;
                }
        }
        texlib_aux_dispose_rope(read_spindle.tail);
        read_spindle.tail = t;
        read_spindle.head = t->next;
    } else {
        texlib_aux_dispose_rope(read_spindle.tail);
        read_spindle.tail = NULL;
    }
    return ret;
}

/*tex Open for reading, and make a new one for writing. */

void lmt_cstring_start(void)
{
    lmt_spindle_state.spindle_index++;
    if (lmt_spindle_state.spindle_size == lmt_spindle_state.spindle_index) {
        int size = (lmt_spindle_state.spindle_size + 1) * sizeof(spindle);
        spindle *spindles = lmt_memory_realloc(lmt_spindle_state.spindles, (size_t) size);
        if (spindles) {
            lmt_spindle_state.spindles = spindles;
            texlib_aux_reset_spindle(lmt_spindle_state.spindle_index);
            lmt_spindle_state.spindle_size++;
        } else {
            tex_overflow_error("spindle", size);
        }
    }
}

/*tex Close for reading. */

void lmt_cstring_close(void)
{
    spindle_rope *t;
    spindle_rope *next = read_spindle.head;
    while (next) {
        if (next->kind == string_tex_input && next->data.t) {
            lmt_memory_free(next->data.t);
            next->data.t = NULL;
        }
        t = next;
        next = next->next;
        if (t == read_spindle.tail) {
            read_spindle.tail = NULL;
        }
        texlib_aux_dispose_rope(t);
    }
    read_spindle.head = NULL;
    texlib_aux_dispose_rope(read_spindle.tail);
    read_spindle.tail = NULL;
    read_spindle.complete = 0;
    lmt_spindle_state.spindle_index--;
}

/*tex
    The original was close to the \TEX\ original (even using |cur_val|) but there is no need to have
    that all-in-one loop with radix magic.
*/

static const char *texlib_aux_scan_integer_part(lua_State *L, const char *ss, int *ret, int *radix_ret)
{
    int negative = 0;     /*tex should the answer be negated? */
    int vacuous = 1;      /*tex have no digits appeared? */
    int overflow = 0;
    int c = 0;            /*tex the current character */
    const char *s = ss;   /*tex where we stopped in the string |ss| */
    long long result = 0; /*tex return value */
    while (1) {
        c = *s++;
        switch (c) {
            case ' ':
            case '+':
                break;
            case '-':
                negative = ! negative;
                break;
            case '\'':
                {
                    int d;
                    *radix_ret = 8;
                    c = *s++;
                    while (c) {
                        if ((c >= '0') && (c <= '0' + 7)) {
                            d = c - '0';
                        } else {
                            break;
                        }
                        if (! overflow) {
                            vacuous = 0;
                            result = result * 8 + d;
                            if (result > max_integer) {
                                overflow = 1;
                            }
                        }
                        c = *s++;
                    }
                    goto DONE;
                }
            case '"':
                {
                    int d;
                    *radix_ret = 16;
                    c = *s++;
                    while (c) {
                        if ((c >= '0') && (c <= '0' + 9)) {
                            d = c - '0';
                        } else if ((c <= 'A' + 5) && (c >= 'A')) {
                            d = c - 'A' + 10;
                        } else if ((c <= 'a' + 5) && (c >= 'a')) {
                            /*tex Actually \TEX\ only handles uppercase. */
                            d = c - 'a' + 10;
                        } else {
                            goto DONE;
                        }
                        if (! overflow) {
                            vacuous = 0;
                            result = result * 16 + d;
                            if (result > max_integer) {
                                overflow = 1;
                            }
                        }
                        c = *s++;
                    }
                    goto DONE;
                }
            default:
                {
                    int d;
                    *radix_ret = 10;
                    while (c) {
                        if ((c >= '0') && (c <= '0' + 9)) {
                            d = c - '0';
                        } else {
                            goto DONE;
                        }
                        if (! overflow) {
                            vacuous = 0;
                            result = result * 10 + d;
                            if (result > max_integer) {
                                overflow = 1;
                            }
                        }
                        c = *s++;
                    }
                    goto DONE;
                }
        }
    }
  DONE:
    if (overflow) {
        luaL_error(L, "number too big");
        result = infinity;
    } else if (vacuous) {
        luaL_error(L, "missing number, treated as zero") ;
    }
    if (negative) {
        result = -result;
    }
    *ret = (int) result;
    if (c != ' ' && s > ss) {
        s--;
    }
    return s;
}

/*tex
    This sets |cur_val| to a dimension. We can clean this up a bit like the normal dimen scanner,
    but it's seldom called. Scanning is like in \TEX, with gobbling spaces and such. When no unit
    is given we assume points. When nothing is given we assume zero. Trailing crap is just ignored.
*/

static const char *texlib_aux_scan_dimen_part(lua_State * L, const char *ss, int *ret)
{
    int negative = 0;                               /*tex should the answer be negated? */
    int fraction = 0;                               /*tex numerator of a fraction whose denominator is $2^{16}$ */
    int numerator;
    int denominator;
    scaled special;                                 /*tex an internal dimension */
    int result = 0;
    int radix = 0;                                  /*tex the current radix */
    int remainder = 0;                              /*tex the to be remainder */
    int saved_error = lmt_scanner_state.arithmic_error; /*tex to save |arith_error|  */
    const char *s = NULL;
    if (ss && (*ss == '.' || *ss == ',')) {
        s = ss;
        goto FRACTION;
    } else {
        s = texlib_aux_scan_integer_part(L, ss, &result, &radix);
    }
    if (! (char) *s) {
        /* error, no unit, assume scaled points */
        goto ATTACH_FRACTION;
    }
    if (result < 0) {
        negative = ! negative;
        result = -result;
    }
  FRACTION:
    if ((radix == 0 || radix == 10) && (*s == '.' || *s == ',')) {
        unsigned k = 0;
        unsigned char digits[18];
        s++;
        while (1) {
            int c = *s++;
            if ((c > '0' + 9) || (c < '0')) {
                break;
            } else if (k < 17) {
                digits[k++] = (unsigned char) c - '0';
            }
        }
        fraction = tex_round_decimals_digits(digits, k);
        if (*s != ' ') {
            --s;
        }
    }
    /* the unit can have spaces in front */
/*UNIT: */
    while ((char) *s == ' ') {
        s++;
    }
    /* We dropped the |nd| and |nc| units as well as the |true| prefix. */
    if (! (char) *s) {
        goto ATTACH_FRACTION;
    } else if (strncmp(s, "pt", 2) == 0) {
        s += 2;
        goto ATTACH_FRACTION;
    } else if (strncmp(s, "mm", 2) == 0) {
        s += 2;
        numerator = 7227;
        denominator = 2540;
        goto CONVERSION;
    } else if (strncmp(s, "cm", 2) == 0) {
        s += 2;
        numerator = 7227;
        denominator = 254;
        goto CONVERSION;
    } else if (strncmp(s, "sp", 2) == 0) {
        s += 2;
        goto DONE;
    } else if (strncmp(s, "bp", 2) == 0) {
        s += 2;
        numerator = 7227;
        denominator = 7200;
        goto CONVERSION;
    } else if (strncmp(s, "in", 2) == 0) {
        s += 2;
        numerator = 7227;
        denominator = 100;
        goto CONVERSION;
    } else if (strncmp(s, "dd", 2) == 0) {
        s += 2;
        numerator = 1238;
        denominator = 1157;
        goto CONVERSION;
    } else if (strncmp(s, "cc", 2) == 0) {
        s += 2;
        numerator = 14856;
        denominator = 1157;
        goto CONVERSION;
    } else if (strncmp(s, "pc", 2) == 0) {
        s += 2;
        numerator = 12;
        denominator = 1;
        goto CONVERSION;
    } else if (strncmp(s, "dk", 2) == 0) {
        s += 2;
        numerator = 49838;
        denominator = 7739;
        goto CONVERSION;
    } else if (strncmp(s, "em", 2) == 0) {
        s += 2;
        special = tex_get_font_em_width(cur_font_par);
        goto SPECIAL;
    } else if (strncmp(s, "ex", 2) == 0) {
        s += 2;
        special = tex_get_font_ex_height(cur_font_par);
        goto SPECIAL;
    } else if (strncmp(s, "px", 2) == 0) {
        s += 2;
        special = px_dimen_par;
        goto SPECIAL;
    } else if (strncmp(s, "mu", 2) == 0) {
        s += 2;
        goto ATTACH_FRACTION;
 /* } else if (strncmp(s, "true", 4) == 0) { */
 /*     s += 4;                              */
 /*     goto UNIT;                           */
    } else {
     /* luaL_error(L, "illegal unit of measure (pt inserted)"); */
        goto ATTACH_FRACTION;
    }
  SPECIAL:
    result = tex_nx_plus_y(result, special, tex_xn_over_d_r(special, fraction, 0200000, &remainder));
    goto DONE;
  CONVERSION:
    result = tex_xn_over_d_r(result, numerator, denominator, &remainder);
    fraction = (numerator * fraction + 0200000 * remainder) / denominator;
    result = result + (fraction / 0200000);
    fraction = fraction % 0200000;
  ATTACH_FRACTION:
    if (result >= 040000) {
        lmt_scanner_state.arithmic_error = 1;
    } else {
        result = result * 65536 + fraction;
    }
  DONE:
    if (lmt_scanner_state.arithmic_error || (abs(result) >= 010000000000)) {
        result = max_dimen;
        luaL_error(L, "dimension too large");
    }
    *ret = negative ? - result : result;
    lmt_scanner_state.arithmic_error = saved_error;
    /* only when we want to report junk */
    while ((char) *s == ' ') {
        s++;
    }
    return s;
}

static int texlib_aux_dimen_to_number(lua_State *L, const char *s)
{
    int result = 0;
    const char *d = texlib_aux_scan_dimen_part(L, s, &result);
    if (*d) {
        return luaL_error(L, "conversion failed (trailing junk?)");
    } else {
        return result;
    }
}

static int texlib_aux_integer_to_number(lua_State *L, const char *s)
{
    int result = 0;
    int radix = 10;
    const char *d = texlib_aux_scan_integer_part(L, s, &result, &radix);
    if (*d) {
        return luaL_error(L, "conversion failed (trailing junk?)");
    } else {
        return result;
    }
}

static int texlib_toscaled(lua_State *L)
{
    int sp;
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            sp = lmt_toroundnumber(L, 1);
            break;
        case LUA_TSTRING:
            sp = texlib_aux_dimen_to_number(L, lua_tostring(L, 1));
            break;
        default:
            return luaL_error(L, "string or a number expected");
    }
    lua_pushinteger(L, sp);
    return 1;
}

static int texlib_tonumber(lua_State *L)
{
    int i;
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            i = lmt_toroundnumber(L, 1);
            break;
        case LUA_TSTRING:
            i = texlib_aux_integer_to_number(L, lua_tostring(L, 1));
            break;
        default:
            return luaL_error(L, "string or a number expected");
    }
    lua_pushinteger(L, i);
    return 1;
}

static int texlib_error(lua_State *L)
{
    const char *error = luaL_checkstring(L, 1);
    const char *help = lua_type(L, 2) == LUA_TSTRING ? luaL_checkstring(L, 2) : NULL;
    tex_handle_error(normal_error_type, error, help);
    return 0;
}

/*tex

    The lua interface needs some extra functions. The functions themselves are quite boring, but they
    are handy because otherwise this internal stuff has to be accessed from \CCODE\ directly, where
    lots of the defines are not available.

*/

inline static int texlib_aux_valid_register_index(lua_State *L, int slot, int cmd, int base, int max)
{
    int index = -1;
    switch (lua_type(L, slot)) {
        case LUA_TSTRING:
            {
                size_t len;
                const char *str = lua_tolstring(L, 1, &len);
                int cs = tex_string_locate(str, len, 0);
                if (eq_type(cs) == cmd) {
                    index = eq_value(cs) - base;
                }
            }
            break;
        case LUA_TNUMBER:
            index = lmt_tointeger(L, slot);
            break;
        default:
            luaL_error(L, "string or a number expected");
            break;
    }
    if (index >= 0 && index <= max) {
        return index;
    } else {
        return -1;
    }
}

static int texlib_get_register_index(lua_State *L)
{
    size_t len;
    const char *str = lua_tolstring(L, 1, &len);
    int cs = tex_string_locate(str, len, 0);
    int index = -1;
    switch (eq_type(cs)) {
        case register_toks_cmd      : index = eq_value(cs) - register_toks_base;      break;
        case register_int_cmd       : index = eq_value(cs) - register_int_base;       break;
        case register_attribute_cmd : index = eq_value(cs) - register_attribute_base; break;
        case register_dimen_cmd     : index = eq_value(cs) - register_dimen_base;     break;
        case register_glue_cmd      : index = eq_value(cs) - register_glue_base;      break;
        case register_mu_glue_cmd   : index = eq_value(cs) - register_mu_glue_base;   break;
    }
    if (index >= 0) {
        lua_pushinteger(L, index);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

inline static int texlib_aux_checked_register(lua_State *L, int cmd, int base, int max)
{
    int index = texlib_aux_valid_register_index(L, 1, cmd, base, max);
    if (index >= 0) {
        lua_pushinteger(L, index);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

typedef void     (*setfunc) (int, halfword, int, int);
typedef halfword (*getfunc) (int, int);

int lmt_check_for_flags(lua_State *L, int slot, int *flags, int prefixes, int numeric)
{
    if (global_defs_par) {
        *flags = add_global_flag(*flags);
    }
    if (prefixes) {
        while (1) {
            switch (lua_type(L, slot)) {
                case LUA_TSTRING:
                    {
                        const char *str = lua_tostring(L, slot);
                        if (! str || lua_key_eq(str, macro)) {
                            /*tex  For practical reasons we skip empty strings. */
                            slot += 1;
                        } else if (lua_key_eq(str, global)) {
                            slot += 1;
                            *flags = add_global_flag(*flags);
                        } else if (lua_key_eq(str, frozen)) {
                            slot += 1;
                            *flags = add_frozen_flag(*flags);
                        } else if (lua_key_eq(str, permanent)) {
                            slot += 1;
                            *flags = add_permanent_flag(*flags);
                        } else if (lua_key_eq(str, protected)) {
                            slot += 1;
                            *flags = add_protected_flag(*flags);
                        } else if (lua_key_eq(str, untraced)) {
                            slot += 1;
                            *flags = add_untraced_flag(*flags);
                        } else if (lua_key_eq(str, immutable)) {
                            slot += 1;
                            *flags = add_immutable_flag(*flags);
                        } else if (lua_key_eq(str, overloaded)) {
                            slot += 1;
                            *flags = add_overloaded_flag(*flags);
                        } else if (lua_key_eq(str, value)) {
                            slot += 1;
                            *flags = add_value_flag(*flags);
                        } else if (lua_key_eq(str, conditional) || lua_key_eq(str, condition)) {
                            /* condition will go, conditional stays */
                            slot += 1;
                            *flags = add_conditional_flag(*flags);
                        } else {
                            /*tex When we have this at the start we now can have a csname. */
                            return slot;
                        }
                        break;
                    }
                case LUA_TNUMBER:
                    if (numeric) {
                        *flags |= lua_tointeger(L, slot);
                        slot += 1;
                        break;
                    } else {
                        return slot;
                    }
                case LUA_TNIL:
                    /*tex This is quite convenient if we use some composer. */
                    slot += 1;
                    break;
                default:
                    return slot;
            }
        }
    }
    return slot;
}

int lmt_check_for_level(lua_State *L, int slot, quarterword *level, quarterword defaultlevel)
{
    if (lua_type(L, slot) == LUA_TSTRING) {
        const char *str = lua_tostring(L, slot);
        *level = lua_key_eq(str, global) ? level_one : defaultlevel;
        ++slot;
    } else {
        *level = defaultlevel;
    }
    return slot;
}

/* -1=noindex, 0=register 1=internal */

static int texlib_aux_check_for_index(
    lua_State  *L,
    int         slot,
    const char *what,
    int        *index,
    int         internal_cmd,
    int         register_cmd,
    int         internal_base,
    int         register_base,
    int         max_index
) {
    *index = -1;
    switch (lua_type(L, slot)) {
        case LUA_TSTRING:
            {
                size_t len;
                const char *str = lua_tolstring(L, slot, &len);
                int cs = tex_string_locate(str, len, 0);
                if (eq_type(cs) == internal_cmd) {
                    *index = eq_value(cs) - internal_base;
                    return 1;
                } else if (eq_type(cs) == register_cmd) {
                    *index = eq_value(cs) - register_base;
                    return 0;
                } else {
                    luaL_error(L, "incorrect %s name", what);
                    return -1;
                }
            }
        case LUA_TNUMBER:
            *index = lmt_tointeger(L, slot);
            if (*index >= 0 && *index <= max_index) {
                return 0;
            } else {
                return -1;
            }
        default:
            luaL_error(L, "%s name or valid index expected", what);
            return -1;
    }
}

static int texlib_get(lua_State *L);

/*tex

    We intercept the first string and when it is |global| then we check the second one which can
    also be a string. It is unlikely that one will use |\global| as register name so we don't need
    to check for the number of further arguments. This permits to treat lack of them as a reset.

*/

static int texlib_isdimen(lua_State *L)
{
    return texlib_aux_checked_register(L, register_dimen_cmd, register_dimen_base, max_dimen_register_index);
}

/* [global] name|index integer|dimension|false|nil */

static int texlib_setdimen(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "dimen", &index, internal_dimen_cmd, register_dimen_cmd, internal_dimen_base, register_dimen_base, max_dimen_register_index);
    if (state >= 0) {
        halfword value = 0;
        switch (lua_type(L, slot)) {
            case LUA_TNUMBER:
                value = lmt_toroundnumber(L, slot++);
                break;
            case LUA_TSTRING:
                value = texlib_aux_dimen_to_number(L, lua_tostring(L, slot++));
                break;
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, slot++)) {
                    /*tex The value |true| makes no sense. */
                    return 0;
                }
                break;
            case LUA_TNONE:
            case LUA_TNIL:
                break;
            default:
                luaL_error(L, "unsupported dimen value type");
                break;
        }
        tex_set_tex_dimen_register(index, value, flags, state);
        if (state == 1 && lua_toboolean(L, slot)) {
            tex_update_par_par(internal_dimen_cmd, index);
        }
    }
    return 0;
}

static int texlib_getdimen(lua_State *L)
{
    int index;
    int state = texlib_aux_check_for_index(L, 1, "dimen", &index, internal_dimen_cmd, register_dimen_cmd, internal_dimen_base, register_dimen_base, max_dimen_register_index);
    lua_pushinteger(L, state >= 0 ? tex_get_tex_dimen_register(index, state) : 0);
    return 1;
}

static halfword texlib_aux_make_glue(lua_State *L, int top, int slot)
{
    halfword value = tex_copy_node(zero_glue);
    if (slot <= top) {
        glue_amount(value) = lmt_toroundnumber(L, slot++);
        if (slot <= top) {
            glue_stretch(value) = lmt_toroundnumber(L, slot++);
            if (slot <= top) {
                glue_shrink(value) = lmt_toroundnumber(L, slot++);
                if (slot <= top) {
                    glue_stretch_order(value) = tex_checked_glue_order(lmt_tohalfword(L, slot++));
                    if (slot <= top) {
                        glue_shrink_order(value) = tex_checked_glue_order(lmt_tohalfword(L, slot++));
                    }
                }
            }
        }
    }
    return value;
}

inline static int texlib_aux_push_glue(lua_State* L, halfword g)
{
    if (g) {
        lua_pushinteger(L, glue_amount(g));
        lua_pushinteger(L, glue_stretch(g));
        lua_pushinteger(L, glue_shrink(g));
        lua_pushinteger(L, glue_stretch_order(g));
        lua_pushinteger(L, glue_shrink_order(g));
    } else {
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
    }
    return 5;
}

static halfword texlib_aux_get_glue_spec(lua_State *L, int slot)
{
    halfword value = null;
    switch (lua_type(L, slot + 1)) {
        case LUA_TBOOLEAN:
         // if (lua_toboolean(L, slot + 1)) {
         //     /*tex The value |true| makes no sense. */
         // }
            break;
        case LUA_TNIL:
        case LUA_TNONE:
            break;
        default:
            value = lmt_check_isnode(L, slot + 1);
            if (node_type(value) != glue_spec_node) {
                value = null;
                luaL_error(L, "glue_spec expected");
            }
    }
    return value;
}

static int texlib_isskip(lua_State *L)
{
    return texlib_aux_checked_register(L, register_glue_cmd, register_glue_base, max_glue_register_index);
}

/* [global] name|index gluespec|false|nil */

static int texlib_setskip(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "skip", &index, internal_glue_cmd, register_glue_cmd, internal_glue_base, register_glue_base, max_glue_register_index);
    if (state >= 0) {
         halfword value = texlib_aux_get_glue_spec(L, slot++);
         tex_set_tex_skip_register(index, value, flags, state);
         if (state == 1 && lua_toboolean(L, slot)) {
             tex_update_par_par(internal_glue_cmd, index);
         }
    }
    return 0;
}

static int texlib_getskip(lua_State *L)
{
    int index;
    int state = texlib_aux_check_for_index(L, 1, "skip", &index, internal_glue_cmd, register_glue_cmd, internal_glue_base, register_glue_base, max_glue_register_index);
    halfword value = state >= 0 ? tex_get_tex_skip_register(index, state) : null;
    lmt_push_node_fast(L, tex_copy_node(value ? value : zero_glue));
    return 1;
}

static int texlib_isglue(lua_State *L)
{
    return texlib_aux_checked_register(L, register_glue_cmd, register_glue_base, max_glue_register_index);
}

/* [global] slot [width] [stretch] [shrink] [stretch_order] [shrink_order] */

static int texlib_setglue(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "skip", &index, internal_glue_cmd, register_glue_cmd, internal_glue_base, register_glue_base, max_glue_register_index);
    if (state >= 0) {
        tex_set_tex_skip_register(index, texlib_aux_make_glue(L, lua_gettop(L), slot), flags, state);
    }
    return 0;
}

static int texlib_getglue(lua_State *L)
{
    int index;
    int all = (lua_type(L, 2) == LUA_TBOOLEAN) ? lua_toboolean(L, 2) : 1;
    int state = texlib_aux_check_for_index(L, 1, "skip", &index, internal_glue_cmd, register_glue_cmd, internal_glue_base, register_glue_base, max_glue_register_index);
    halfword value = state >= 0 ? tex_get_tex_skip_register(index, state) : null;
    if (! value) {
        lua_pushinteger(L, 0);
        if (all) {
            /* save the trouble of testing p/m */
            lua_pushinteger(L, 0);
            lua_pushinteger(L, 0);
            return 3;
        } else {
            return 1;
        }
    } else if (all) {
        return texlib_aux_push_glue(L, value);
    } else {
        /* false */
        lua_pushinteger(L, value ? glue_amount(value) : 0);
        return 1;
    }
}

static int texlib_ismuskip(lua_State *L)
{
    return texlib_aux_checked_register(L, register_mu_glue_cmd, register_mu_glue_base, max_mu_glue_register_index);
}

static int texlib_setmuskip(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "muskip", &index, internal_mu_glue_cmd, register_mu_glue_cmd, internal_mu_glue_base, register_mu_glue_base, max_mu_glue_register_index);
    tex_set_tex_mu_skip_register(index, texlib_aux_get_glue_spec(L, slot), flags, state);
    return 0;
}

static int texlib_getmuskip(lua_State *L)
{
    int index;
    int state = texlib_aux_check_for_index(L, 1, "muskip", &index, internal_mu_glue_cmd, register_mu_glue_cmd, internal_mu_glue_base, register_mu_glue_base, max_mu_glue_register_index);
    halfword value = state >= 0 ? tex_get_tex_mu_skip_register(index, state) : null;
    lmt_push_node_fast(L, tex_copy_node(value ? value : zero_glue));
    return 1;
}

static int texlib_ismuglue(lua_State *L)
{
    return texlib_aux_checked_register(L, register_mu_glue_cmd, register_mu_glue_base, max_mu_glue_register_index);
}

static int texlib_setmuglue(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "muskip", &index, internal_mu_glue_cmd, register_mu_glue_cmd, internal_mu_glue_base, register_mu_glue_base, max_mu_glue_register_index);
    halfword value = texlib_aux_make_glue(L, lua_gettop(L), slot);
    if (state >= 0) {
         tex_set_tex_mu_skip_register(index, value, flags, state);
    }
    return 0;
}

static int texlib_getmuglue(lua_State *L)
{
    int index;
    int all = (lua_type(L, 2) == LUA_TBOOLEAN) ? lua_toboolean(L, 2) : 1;
    int state = texlib_aux_check_for_index(L, 1, "muskip", &index, internal_mu_glue_cmd, register_mu_glue_cmd, internal_mu_glue_base, register_mu_glue_base, max_mu_glue_register_index);
    halfword value = state >= 0 ? tex_get_tex_mu_skip_register(index, state) : null;
    if (! value) {
        lua_pushinteger(L, 0);
        return 1;
    } else if (all) {
        return texlib_aux_push_glue(L, value);
    } else {
        /* false */
        lua_pushinteger(L, value ? glue_amount(value) : 0);
        return 1;
    }
}

static int texlib_iscount(lua_State *L)
{
    return texlib_aux_checked_register(L, register_int_cmd, register_int_base, max_int_register_index);
}

static int texlib_setcount(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "count", &index, internal_int_cmd, register_int_cmd, internal_int_base, register_int_base, max_int_register_index);
    if (state >= 0) {
        halfword value = lmt_optinteger(L, slot++, 0);
        tex_set_tex_count_register(index, value, flags, state);
        if (state == 1 && lua_toboolean(L, slot)) {
            tex_update_par_par(internal_int_cmd, index);
        }
    }
    return 0;
}

static int texlib_getcount(lua_State *L)
{
    int index;
    int state = texlib_aux_check_for_index(L, 1, "count", &index, internal_int_cmd, register_int_cmd, internal_int_base, register_int_base, max_int_register_index);
    lua_pushinteger(L, state >= 0 ? tex_get_tex_count_register(index, state) : 0);
    return 1;
}

static int texlib_isattribute(lua_State *L)
{
    return texlib_aux_checked_register(L, register_attribute_cmd, register_attribute_base, max_attribute_register_index);
}

/*tex there are no system set attributes so this is a bit overkill */

static int texlib_setattribute(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "attribute", &index, internal_attribute_cmd, register_attribute_cmd, internal_attribute_base, register_attribute_base, max_attribute_register_index);
    if (state >= 0) {
        halfword value = lmt_optinteger(L, slot++, unused_attribute_value);
        tex_set_tex_attribute_register(index, value, flags, state);
    }
    return 0;
}

static int texlib_getattribute(lua_State *L)
{
    int index;
    int state = texlib_aux_check_for_index(L, 1, "attribute", &index, internal_attribute_cmd, register_attribute_cmd, internal_attribute_base, register_attribute_base, max_attribute_register_index);
    lua_pushinteger(L, state >= 0 ? tex_get_tex_attribute_register(index, state) : 0);
    return 1;
}

/*tex todo: we can avoid memcpy as there is no need to go through the pool */

/* use string_to_toks */

static int texlib_istoks(lua_State *L)
{
    return texlib_aux_checked_register(L, register_toks_cmd, register_toks_base, max_toks_register_index);
}

/* [global] name|integer string|nil */

static int texlib_settoks(lua_State *L)
{
    int flags = 0;
    int index = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "toks", &index, internal_toks_cmd, register_toks_cmd, internal_toks_base, register_toks_base,max_toks_register_index);
    if (state >= 0) {
        lstring value = { .c = NULL, .l = 0 };
        switch (lua_type(L, slot)) {
            case LUA_TSTRING:
                value.c = lua_tolstring(L, slot, &value.l);
                break;
            case LUA_TNIL:
            case LUA_TNONE:
                break;
            default:
                return luaL_error(L, "string or nil expected");
        }
        tex_set_tex_toks_register(index, value, flags, state);
    }
    return 0;
}

/* [global] name|index catcode string */

static int texlib_scantoks(lua_State *L) // TODO
{
    int index = 0;
    int flags = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int state = texlib_aux_check_for_index(L, slot++, "toks", &index, internal_toks_cmd, register_toks_cmd, internal_toks_base, register_toks_base,max_toks_register_index);
    if (state >= 0) {
        lstring value = { .c = NULL, .l = 0 };
        int cattable = lmt_checkinteger(L, slot++);
        switch (lua_type(L, slot)) {
            case LUA_TSTRING:
                value.c = lua_tolstring(L, slot, &value.l);
                break;
            case LUA_TNIL:
            case LUA_TNONE:
                break;
            default:
                return luaL_error(L, "string or nil expected");
        }
        tex_scan_tex_toks_register(index, cattable, value, flags, state);
    }
    return 0;
}

static int texlib_gettoks(lua_State *L)
{
    int index;
    int slot = 1;
    int state = texlib_aux_check_for_index(L, slot++, "toks", &index, internal_toks_cmd, register_toks_cmd, internal_toks_base, register_toks_base, max_toks_register_index);
    if (state >= 0) {
        if (lua_toboolean(L, slot)) {
            lmt_token_register_to_lua(L, state ? toks_parameter(index) : toks_register(index));
        } else {

            strnumber value = tex_get_tex_toks_register(index, state);
            lua_pushstring(L, tex_to_cstring(value));
            tex_flush_str(value);
        }
    } else {
        lua_pushnil(L);
        return 1;
    }
    return 1;
}

static int texlib_getmark(lua_State *L)
{
    if (lua_gettop(L) == 0) {
        lua_pushinteger(L, lmt_mark_state.mark_data.ptr);
        return 1;
    } else if (lua_type(L, 1) == LUA_TSTRING) {
        int mrk = -1;
        const char *s = lua_tostring(L, 1);
        if (lua_key_eq(s, top)) {
            mrk = top_marks_code;
        } else if (lua_key_eq(s, first)) {
            mrk = first_marks_code;
        } else if (lua_key_eq(s, bottom)) {
            mrk = bot_marks_code;
        } else if (lua_key_eq(s, splitfirst)) {
            mrk = split_first_marks_code;
        } else if (lua_key_eq(s, splitbottom)) {
            mrk = split_bot_marks_code;
        } else if (lua_key_eq(s, current)) {
            mrk = current_marks_code;
        }
        if (mrk >= 0) {
            int num = lmt_optinteger(L, 2, 0);
            if (num >= 0 && num <= lmt_mark_state.mark_data.ptr) {
                halfword ptr = tex_get_some_mark(mrk, num);
                if (ptr) {
                    char *str = tex_tokenlist_to_tstring(ptr, 1, NULL, 0, 0, 0, 0);
                    if (str) {
                        lua_pushstring(L, str);
                    } else {
                        lua_pushliteral(L, "");
                    }
                    return 1;
                }
            } else {
                luaL_error(L, "valid mark class expected");
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

int lmt_get_box_id(lua_State *L, int i, int report)
{
    int index = -1;
    switch (lua_type(L, i)) {
        case LUA_TSTRING:
            {
                size_t k = 0;
                const char *s = lua_tolstring(L, i, &k);
                int cs = tex_string_locate(s, k, 0);
                int cmd = eq_type(cs);
                switch (cmd) {
                    case char_given_cmd:
                    case integer_cmd:
                        index = eq_value(cs);
                        break;
                    case register_int_cmd:
                        index = register_int_number(eq_value(cs));
                        break;
                    default:
                        /* we don't accept other commands as it makes no sense */
                        break;
                }
                break;
            }
        case LUA_TNUMBER:
            index = lmt_tointeger(L, i);
        default:
            break;
    }
    if (index >= 0 && index <= max_box_register_index) {
        return index;
    } else {
        if (report) {
            luaL_error(L, "string or a number within range expected");
        }
        return -1;
    }
}

static int texlib_getbox(lua_State *L)
{
    halfword index = lmt_get_box_id(L, 1, 1);
    lmt_node_list_to_lua(L, index >= 0 ? tex_get_tex_box_register(index, 0) : null);
    return 1;
}

static int texlib_splitbox(lua_State *L)
{
    int index = lmt_get_box_id(L, 1, 1);
    if (index >= 0) {
        if (lua_isnumber(L, 2)) {
            int m = packing_additional;
            switch (lua_type(L, 3)) {
                case LUA_TSTRING:
                    {
                        const char *s = lua_tostring(L, 3);
                        if (lua_key_eq(s, exactly)) {
                            m = packing_exactly;
                        } else if (lua_key_eq(s, additional)) {
                            m = packing_additional;
                        }
                        break;
                    }
                case LUA_TNUMBER:
                    {
                        m = lmt_tointeger(L, 3);
                        if (m != packing_exactly && m != packing_additional) {
                            m = packing_exactly;
                            luaL_error(L, "wrong mode in splitbox");
                        }
                        break;
                    }
            }
            lmt_node_list_to_lua(L, tex_vsplit(index, lmt_toroundnumber(L, 2), m));
        } else {
            /* maybe a warning */
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* todo */

static int texlib_isbox(lua_State *L)
{
    lua_pushboolean(L, lmt_get_box_id(L, 1, 0) >= 0);
    return 1;
}

static int texlib_setbox(lua_State *L)
{
    int flags = 0;
    int slot = lmt_check_for_flags(L, 1, &flags, 1, 0);
    int index = lmt_get_box_id(L, slot++, 1);
    if (index >= 0) {
        int n = null;
        switch (lua_type(L, slot)) {
            case LUA_TBOOLEAN:
                n = lua_toboolean(L, slot);
                if (n) {
                    return 0;
                } else {
                    n = null;
                }
                break;
            case LUA_TNIL:
            case LUA_TNONE:
                break;
            default:
                n = lmt_node_list_from_lua(L, slot);
                if (n) {
                    switch (node_type(n)) {
                        case hlist_node:
                        case vlist_node:
                            break;
                        default:
                            return luaL_error(L, "invalid node type %s passed", get_node_name(node_type(n)));
                    }
                }
                break;
        }
        tex_set_tex_box_register(index, n, flags, 0);
    }
    return 0;
}

/* [global] index first second */

static int texlib_setlccode(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int ch1 = lmt_checkinteger(L, slot++);
        if (character_in_range(ch1)) {
            halfword ch2 = lmt_checkhalfword(L, slot++);
            if (character_in_range(ch2)) {
                tex_set_lc_code(ch1, ch2, level);
                if (slot <= top) {
                    halfword ch3 = lmt_checkhalfword(L, slot);
                    if (character_in_range(ch3)) {
                        tex_set_uc_code(ch1, ch3, level);
                    } else {
                        texlib_aux_show_character_error(L, ch3);
                    }
                }
            } else {
                texlib_aux_show_character_error(L, ch2);
            }
        } else {
            texlib_aux_show_character_error(L, ch1);
        }
    }
    return 0;
}

static int texlib_setuccode(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int ch1 = lmt_checkinteger(L, slot++);
        if (character_in_range(ch1)) {
            halfword ch2 = lmt_checkhalfword(L, slot++);
            if (character_in_range(ch2)) {
                tex_set_uc_code(ch1, ch2, level);
                if (slot <= top) {
                    halfword ch3 = lmt_checkhalfword(L, slot);
                    if (character_in_range(ch3)) {
                        tex_set_lc_code(ch1, ch3, level);
                    } else {
                        texlib_aux_show_character_error(L, ch3);
                    }
                }
            } else {
                texlib_aux_show_character_error(L, ch2);
            }
        } else {
            texlib_aux_show_character_error(L, ch1);
        }
    }
    return 0;
}

static int texlib_setsfcode(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int ch = lmt_checkinteger(L, slot++);
        if (character_in_range(ch)) {
            halfword val = lmt_checkhalfword(L, slot);
            if (half_in_range(val)) {
                tex_set_sf_code(ch, val, level);
            } else {
                texlib_aux_show_half_error(L, val);
            }
        } else {
            texlib_aux_show_character_error(L, ch);
        }
    }
    return 0;
}

static int texlib_sethccode(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int ch = lmt_checkinteger(L, slot++);
        if (character_in_range(ch)) {
            halfword val = lmt_checkhalfword(L, slot);
            if (half_in_range(val)) {
                tex_set_hc_code(ch, val, level);
            } else {
                texlib_aux_show_half_error(L, val);
            }
        } else {
            texlib_aux_show_character_error(L, ch);
        }
    }
    return 0;
}

static int texlib_sethmcode(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int ch = lmt_checkinteger(L, slot++);
        if (character_in_range(ch)) {
            halfword val = lmt_checkhalfword(L, slot);
            tex_set_hm_code(ch, val, level);
        } else {
            texlib_aux_show_character_error(L, ch);
        }
    }
    return 0;
}

static int texlib_getlccode(lua_State *L)
{
    int ch = lmt_checkinteger(L, 1);
    if (character_in_range(ch)) {
        lua_pushinteger(L, tex_get_lc_code(ch));
    } else {
        texlib_aux_show_character_error(L, ch);
        lua_pushinteger(L, 0);
    }
    return 1;
}

static int texlib_getuccode(lua_State *L)
{
    int ch = lmt_checkinteger(L, 1);
    if (character_in_range(ch)) {
        lua_pushinteger(L, tex_get_uc_code(ch));
    } else {
        texlib_aux_show_character_error(L, ch);
        lua_pushinteger(L, 0);
    }
    return 1;
}

static int texlib_getsfcode(lua_State *L)
{
    int ch = lmt_checkinteger(L, 1);
    if (character_in_range(ch)) {
        lua_pushinteger(L, tex_get_sf_code(ch));
    } else {
        texlib_aux_show_character_error(L, ch);
        lua_pushinteger(L, 0);
    }
    return 1;
}

static int texlib_gethccode(lua_State *L)
{
    int ch = lmt_checkinteger(L, 1);
    if (character_in_range(ch)) {
        lua_pushinteger(L, tex_get_hc_code(ch));
    } else {
        texlib_aux_show_character_error(L, ch);
        lua_pushinteger(L, 0);
    }
    return 1;
}

static int texlib_gethmcode(lua_State *L)
{
    int ch = lmt_checkinteger(L, 1);
    if (character_in_range(ch)) {
        lua_pushinteger(L, tex_get_hm_code(ch));
    } else {
        texlib_aux_show_character_error(L, ch);
        lua_pushinteger(L, 0);
    }
    return 1;
}

/* [global] [cattable] code value */

static int texlib_setcatcode(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int cattable = ((top - slot + 1) >= 3) ? lmt_checkinteger(L, slot++) : cat_code_table_par;
        int ch = lmt_checkinteger(L, slot++);
        if (character_in_range(ch)) {
            halfword val = lmt_checkhalfword(L, slot);
            if (catcode_in_range(val)) {
                tex_set_cat_code(cattable, ch, val, level);
            } else {
                texlib_aux_show_catcode_error(L, val);
            }
        } else {
            texlib_aux_show_character_error(L, ch);
        }
    }
    return 0;
}

/* [cattable] code */

static int texlib_getcatcode(lua_State *L)
{
    int slot = 1;
    int cattable = (lua_gettop(L) > 1) ? lmt_checkinteger(L, slot++) : cat_code_table_par;
    int ch = lmt_checkinteger(L, slot);
    if (character_in_range(ch)) {
        lua_pushinteger(L, tex_get_cat_code(cattable, ch));
    } else {
        texlib_aux_show_character_error(L, ch);
        lua_pushinteger(L, 12); /* other */
    }
    return 1;
}

/*
    [global] code { c f ch }
    [global] code   c f ch   (a bit easier on memory, counterpart of getter)
*/

static int texlib_setmathcode(lua_State *L)
{
    quarterword level;
    int slot = lmt_check_for_level(L, 1, &level, cur_level);
    int ch = lmt_checkinteger(L, slot++);
    if (character_in_range(ch)) {
        halfword cval, fval, chval;
        switch (lua_type(L, slot)) {
            case LUA_TNUMBER:
                cval = lmt_checkhalfword(L, slot++);
                fval = lmt_checkhalfword(L, slot++);
                chval = lmt_checkhalfword(L, slot);
                break;
            case LUA_TTABLE:
                lua_rawgeti(L, slot, 1);
                cval = lmt_checkhalfword(L, -1);
                lua_rawgeti(L, slot, 2);
                fval = lmt_checkhalfword(L, -1);
                lua_rawgeti(L, slot, 3);
                chval = lmt_checkhalfword(L, -1);
                lua_pop(L, 3);
                break;
            default:
                return luaL_error(L, "number of table expected");
        }
        if (class_in_range(cval)) {
            if (family_in_range(fval)) {
                if (character_in_range(chval)) {
                    mathcodeval m;
                    m.character_value = chval;
                    m.class_value = (short) cval;
                    m.family_value = (short) fval;
                    tex_set_math_code(ch, m, (quarterword) (level));
                } else {
                    texlib_aux_show_character_error(L, chval);
                }
            } else {
                texlib_aux_show_family_error(L, fval);
            }
        } else {
            texlib_aux_show_class_error(L, cval);
        }
    } else {
        texlib_aux_show_character_error(L, ch);
    }
return 0;
}

static int texlib_getmathcode(lua_State* L)
{
    mathcodeval mval = tex_no_math_code();
    int ch = lmt_checkinteger(L, -1);
    if (character_in_range(ch)) {
        mval = tex_get_math_code(ch);
    } else {
        texlib_aux_show_character_error(L, ch);
    }
    lua_createtable(L, 3, 0);
    lua_pushinteger(L, mval.class_value);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L, mval.family_value);
    lua_rawseti(L, -2, 2);
    lua_pushinteger(L, mval.character_value);
    lua_rawseti(L, -2, 3);
    return 1;
}

static int texlib_getmathcodes(lua_State* L)
{
    mathcodeval mval = tex_no_math_code();
    int ch = lmt_checkinteger(L, -1);
    if (character_in_range(ch)) {
        mval = tex_get_math_code(ch);
    } else {
        texlib_aux_show_character_error(L, ch);
    }
    lua_pushinteger(L, mval.class_value);
    lua_pushinteger(L, mval.family_value);
    lua_pushinteger(L, mval.character_value);
    return 3;
}

/*
    [global] code { c f ch }
    [global] code   c f ch   (a bit easier on memory, counterpart of getter)
*/

static int texlib_setdelcode(lua_State* L)
{
    quarterword level;
    int slot = lmt_check_for_level(L, 1, &level, cur_level);
    /* todo: when no integer than do a reset */
    int ch = lmt_checkinteger(L, slot++);
    if (character_in_range(ch)) {
        halfword sfval, scval, lfval, lcval;
        switch (lua_type(L, slot)) {
            case LUA_TNUMBER:
                sfval = lmt_checkhalfword(L, slot++);
                scval = lmt_checkhalfword(L, slot++);
                lfval = lmt_checkhalfword(L, slot++);
                lcval = lmt_checkhalfword(L, slot);
                break;
            case LUA_TTABLE:
                lua_rawgeti(L, slot, 1);
                sfval = lmt_checkhalfword(L, -1);
                lua_rawgeti(L, slot, 2);
                scval = lmt_checkhalfword(L, -1);
                lua_rawgeti(L, slot, 3);
                lfval = lmt_checkhalfword(L, -1);
                lua_rawgeti(L, slot, 4);
                lcval = lmt_checkhalfword(L, -1);
                lua_pop(L, 4);
                break;
            default:
                return luaL_error(L, "number of table expected");
        }
        if (family_in_range(sfval)) {
            if (character_in_range(scval)) {
                if (family_in_range(lfval)) {
                    if (character_in_range(lcval)) {
                        delcodeval d;
                        d.small.class_value = 0;
                        d.small.family_value = (short) sfval;
                        d.small.character_value = scval;
                        d.large.class_value = 0;
                        d.large.family_value = (short) lfval;
                        d.large.character_value = lcval;
                        tex_set_del_code(ch, d, (quarterword) (level));
                    }
                    else {
                        texlib_aux_show_character_error(L, lcval);
                    }
                }
                else {
                    texlib_aux_show_family_error(L, lfval);
                }
            }
            else {
                texlib_aux_show_character_error(L, scval);
            }
        }
        else {
            texlib_aux_show_family_error(L, sfval);
        }
    }
    else {
    texlib_aux_show_character_error(L, ch);
    }
    return 0;
}

static int texlib_getdelcode(lua_State* L)
{
    delcodeval dval = tex_no_del_code();
    int ch = lmt_checkinteger(L, -1);
    if (character_in_range(ch)) {
        dval = tex_get_del_code(ch);
    } else {
        texlib_aux_show_character_error(L, ch);
    }
    if (tex_has_del_code(dval)) {
        lua_createtable(L, 4, 0);
        lua_pushinteger(L, dval.small.family_value);
        lua_rawseti(L, -2, 1);
        lua_pushinteger(L, dval.small.character_value);
        lua_rawseti(L, -2, 2);
        lua_pushinteger(L, dval.large.family_value);
        lua_rawseti(L, -2, 3);
        lua_pushinteger(L, dval.large.character_value);
        lua_rawseti(L, -2, 4);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int texlib_getdelcodes(lua_State* L)
{
    delcodeval dval = tex_no_del_code();
    int ch = lmt_checkinteger(L, -1);
    if (character_in_range(ch)) {
        dval = tex_get_del_code(ch);
    } else {
        texlib_aux_show_character_error(L, ch);
    }
    if (tex_has_del_code(dval)) {
        lua_pushinteger(L, dval.small.family_value);
        lua_pushinteger(L, dval.small.character_value);
        lua_pushinteger(L, dval.large.family_value);
        lua_pushinteger(L, dval.large.character_value);
    } else {
        lua_pushnil(L);
    }
    return 4;
}

static halfword texlib_aux_getdimension(lua_State* L, int index)
{
    switch (lua_type(L, index)) {
    case LUA_TNUMBER:
        return lmt_toroundnumber(L, index);
    case LUA_TSTRING:
        return texlib_aux_dimen_to_number(L, lua_tostring(L, index));
    default:
        luaL_error(L, "string or number expected (dimension)");
        return 0;
    }
}

static halfword texlib_aux_getinteger(lua_State* L, int index)
{
    switch (lua_type(L, index)) {
    case LUA_TNUMBER:
        return lmt_toroundnumber(L, index);
    default:
        luaL_error(L, "number expected (integer)");
        return 0;
    }
}

static halfword texlib_toparshape(lua_State *L, int i)
{
    if (lua_type(L, i) == LUA_TTABLE) {
        halfword n = (halfword) luaL_len(L, i);
        if (n > 0) {
            halfword p = tex_new_specification_node(n, par_shape_code, 0); /* todo: repeat but then not top based */
            lua_push_key(repeat);
            if (lua_rawget(L, -2) == LUA_TBOOLEAN && lua_toboolean(L, -1)) {
                tex_set_specification_option(p, specification_option_repeat);
            }
            lua_pop(L, 1);
            /* fill |p| */
            for (int j = 1; j <= n; j++) {
                halfword indent = 0;
                halfword width = 0;
                if (lua_rawgeti(L, i, j) == LUA_TTABLE) {
                    if (lua_rawgeti(L, -1, 1) == LUA_TNUMBER) {
                        indent = lmt_toroundnumber(L, -1);
                        if (lua_rawgeti(L, -2, 2) == LUA_TNUMBER) {
                            width = lmt_toroundnumber(L, -1);
                        }
                        lua_pop(L, 1);
                    }
                    lua_pop(L, 1);
                }
                lua_pop(L, 1);
                tex_set_specification_indent(p, j, indent);
                tex_set_specification_width(p, j, width);
            }
            return p;
        }
    }
    return null;
}

static int texlib_shiftparshape(lua_State *L)
{
    if (par_shape_par) {
        tex_shift_specification_list(par_shape_par, lmt_tointeger(L, 1), lua_toboolean(L, 2));
    }
    return 0;
}

static int texlib_snapshotpar(lua_State *L)
{
    halfword par = tex_find_par_par(cur_list.head);
    if (par) {
        if (lua_type(L, 1) == LUA_TNUMBER) {
            tex_snapshot_par(par, lmt_tointeger(L, 1));
        }
        lua_pushinteger(L, par_state(par));
        return 1;
    } else {
        return 0;
    }
}

static int texlib_getparstate(lua_State *L)
{
    lua_createtable(L, 0, 7);
    lua_push_integer_at_key(L, hsize, hsize_par);
    lua_push_integer_at_key(L, leftskip, left_skip_par ? glue_amount(left_skip_par) : 0);
    lua_push_integer_at_key(L, rightskip, right_skip_par ? glue_amount(right_skip_par) : 0);
    lua_push_integer_at_key(L, hangindent, hang_indent_par);
    lua_push_integer_at_key(L, hangafter, hang_after_par);
    lua_push_integer_at_key(L, parindent, par_indent_par);
    lua_push_specification_at_key(L, parshape, par_shape_par);
    return 1;
}

static int texlib_set_item(lua_State* L, int index, int prefixes)
{
    int flags = 0;
    int slot = lmt_check_for_flags(L, index, &flags, prefixes, 0);
    size_t sl;
    const char *st = lua_tolstring(L, slot++, &sl);
    if (sl > 0) {
        int cs = tex_string_locate(st, sl, 0);
        if (cs != undefined_control_sequence && has_eq_flag_bits(cs, primitive_flag_bit)) {
            int cmd = eq_type(cs);
            switch (cmd) {
                case internal_int_cmd:
                case register_int_cmd: /* ? */
                    switch (lua_type(L, slot)) {
                        case LUA_TNUMBER:
                            {
                                int n = lmt_tointeger(L, slot++);
                                if (cmd == register_int_cmd) {
                                    tex_word_define(flags, eq_value(cs), n);
                                } else {
                                    tex_assign_internal_int_value(lua_toboolean(L, slot) ? add_frozen_flag(flags) : flags, eq_value(cs), n);
                                }
                                break;
                            }
                        default:
                            luaL_error(L, "number expected");
                            break;
                    }
                    return 1;
                case internal_dimen_cmd:
                case register_dimen_cmd:
                    {
                        halfword n = texlib_aux_getdimension(L, slot);
                        if (cmd == register_dimen_cmd) {
                            tex_word_define(flags, eq_value(cs), n);
                        } else {
                            tex_assign_internal_dimen_value(lua_toboolean(L, slot) ? add_frozen_flag(flags) : flags, eq_value(cs), n);
                        }
                        return 1;
                    }
                case internal_glue_cmd:
                case register_glue_cmd:
                    switch (lua_type(L, slot)) {
                        case LUA_TNUMBER:
                            {
                                int top = lua_gettop(L);
                                halfword value = tex_copy_node(zero_glue);
                                glue_amount(value) = lmt_toroundnumber(L, slot++);
                                if (slot <= top) {
                                    glue_stretch(value) = lmt_toroundnumber(L, slot++);
                                    if (slot <= top) {
                                        glue_shrink(value) = lmt_toroundnumber(L, slot++);
                                        if (slot <= top) {
                                            glue_stretch_order(value) = tex_checked_glue_order(lmt_tohalfword(L, slot++));
                                            if (slot <= top) {
                                                glue_shrink_order(value) = tex_checked_glue_order(lmt_tohalfword(L, slot));
                                            }
                                        }
                                    }
                                }
                                if (cmd == register_glue_cmd) {
                                    tex_word_define(flags, eq_value(cs), value);
                                } else {
                                    tex_assign_internal_skip_value(lua_toboolean(L, slot) ? add_frozen_flag(flags) : flags, eq_value(cs), value);
                                }
                                break;
                            }
                        case LUA_TUSERDATA:
                            {
                                halfword n = lmt_check_isnode(L, slot);
                                if (node_type(n) == glue_spec_node) {
                                    if (cmd == register_glue_cmd) {
                                        tex_word_define(flags, eq_value(cs), n);
                                    } else {
                                        tex_assign_internal_skip_value(lua_toboolean(L, slot) ? add_frozen_flag(flags) : flags, eq_value(cs), n);
                                    }
                                } else {
                                    luaL_error(L, "gluespec node expected");
                                }
                                break;
                            }
                        default:
                            luaL_error(L, "number or node expected");
                            break;
                    }
                    return 1;
                case internal_toks_cmd:
                case register_toks_cmd:
                    switch (lua_type(L, slot)) {
                        case LUA_TSTRING:
                            {
                                int t = lmt_token_list_from_lua(L, slot);
                             // define(flags, eq_value(cs), call_cmd, t); /* was call_cmd */
                                tex_define(flags, eq_value(cs), cmd == internal_toks_cmd ? internal_toks_reference_cmd : register_toks_reference_cmd, t); /* eq_value(cs) and not cs ? */
                                break;
                            }
                        default:
                            luaL_error(L, "string expected");
                            break;
                    }
                    return 1;
                case set_page_property_cmd:
                    /*tex This could be |set_page_property_value| instead. */
                    switch (eq_value(cs)) {
                     // case page_goal_code:
                     // case page_total_code:
                     // case page_vsize_code:
                        case page_depth_code:
                            lmt_page_builder_state.depth = texlib_aux_getdimension(L, slot);
                            break;
                     // case page_stretch_code:
                     // case page_filstretch_code:
                     // case page_fillstretch_code:
                     // case page_filllstretch_code:
                     // case page_shrink_code:
                        case insert_storing_code:
                            lmt_insert_state.storing = texlib_aux_getinteger(L, slot);
                            break;
                     // case dead_cycles_code:
                     // case insert_penalties_code:
                     // case interaction_mode_code:
                        default:
                            return 0;
                    }
                case set_auxiliary_cmd:
                    /*tex This could be |set_aux_value| instead. */
                    switch (eq_value(cs)) {
                        case space_factor_code:
                            cur_list.space_factor = texlib_aux_getinteger(L, slot);
                            return 1;
                        case prev_depth_code:
                            cur_list.prev_depth = texlib_aux_getdimension(L, slot);
                            return 1;
                        case prev_graf_code:
                            cur_list.prev_graf = texlib_aux_getinteger(L, slot);
                            return 1;
                        default:
                            return 0;
                    }
                case set_box_property_cmd:
                    /*tex This could be |set_box_property_value| instead. */
                    return 0;
                case set_specification_cmd:
                    {
                        int chr = internal_specification_number(eq_value(cs));
                        switch (chr) {
                            case par_shape_code:
                                {
                                    halfword p = texlib_toparshape(L, slot);
                                    tex_define(flags, eq_value(cs), specification_reference_cmd, p);
                                   // lua_toboolean(L, slot + 1) ? add_frozen_flag(flags) : flags
                                    if (is_frozen(flags) && cur_mode == hmode) {
                                        tex_update_par_par(specification_reference_cmd, chr);
                                    }
                                    break;
                                }
                        }
                        return 0;
                    }
            }
        }
    }
    return 0;
}

static int texlib_set(lua_State *L)
{
    texlib_set_item(L, 1, 1);
    return 0;
}

static int texlib_newindex(lua_State *L)
{
    if (! texlib_set_item(L, 2, 0)) {
        lua_rawset(L, 1);
    }
    return 0;
}

static int texlib_aux_convert(lua_State *L, int cur_code)
{
    int i = -1;
    switch (cur_code) {
        /* ignored (yet) */
        case insert_progress_code:     /* arg <register int> */
        case lua_code:                 /* arg complex */
        case lua_escape_string_code:   /* arg token list */
     /* case lua_token_string_code: */ /* arg token list */
        case string_code:              /* arg token */
        case cs_string_code:           /* arg token */
        case cs_active_code:           /* arg token */
        case detokenized_code:         /* arg token */
        case meaning_code:             /* arg token */
        case to_mathstyle_code:
            break;
        /* the next fall through, and come from 'official' indices! */
        case font_name_code:           /* arg fontid */
        case font_specification_code:  /* arg fontid */
        case font_identifier_code:     /* arg fontid */
        case number_code:              /* arg int */
        case to_integer_code:          /* arg int */
        case to_hexadecimal_code:      /* arg int */
        case to_scaled_code:           /* arg int */
        case to_sparse_scaled_code:    /* arg int */
        case to_dimension_code:        /* arg int */
        case to_sparse_dimension_code: /* arg int */
        case roman_numeral_code:       /* arg int */
            if (lua_gettop(L) < 1) {
                /* error */
            }
            i = lmt_tointeger(L, 1);
            // fall through
        default:
            /* no backend here */
            if (cur_code < 32) {
                int texstr = tex_the_convert_string(cur_code, i);
                if (texstr) {
                    lua_pushstring(L, tex_to_cstring(texstr));
                    tex_flush_str(texstr);

                 // int allocated = 0;
                 // char *str = tex_makecstring(texstr, &allocated);
                 // lua_pushstring(L, str);
                 // if (allocated) {
                 //     lmt_memory_free(str);
                 // }
                 // tex_flush_str(texstr);
                    return 1; 
                }
            }
            break;
    }
    lua_pushnil(L);
    return 1;
}

static int texlib_aux_scan_internal(lua_State *L, int cmd, int code, int values)
{
    int retval = 1 ;
    int save_cur_val = cur_val;
    int save_cur_val_level = cur_val_level;
    tex_scan_something_simple(cmd, code);
    switch (cur_val_level) {
        case int_val_level:
        case dimen_val_level:
        case attr_val_level:
            lua_pushinteger(L, cur_val);
            break;
        case glue_val_level:
        case mu_val_level:
            switch (values) {
                case 0:
                    lua_pushinteger(L, glue_amount(cur_val));
                    tex_flush_node(cur_val);
                    break;
                case 1:
                    lua_pushinteger(L, glue_amount(cur_val));
                    lua_pushinteger(L, glue_stretch(cur_val));
                    lua_pushinteger(L, glue_shrink(cur_val));
                    lua_pushinteger(L, glue_stretch_order(cur_val));
                    lua_pushinteger(L, glue_shrink_order(cur_val));
                    tex_flush_node(cur_val);
                    retval = 5;
                    break;
                default:
                    lmt_push_node_fast(L, cur_val);
                    break;
            }
            break;
        case list_val_level:
            lmt_push_node_fast(L, cur_val);
            break;
        default:
            {
                int texstr = tex_the_scanned_result();
                char *str = tex_to_cstring(texstr);
                if (str) {
                    lua_pushstring(L, str);
                } else {
                    lua_pushnil(L);
                }
                tex_flush_str(texstr);
            }
            break;
    }
    cur_val = save_cur_val;
    cur_val_level = save_cur_val_level;
    return retval;
}

/*tex
    Todo: complete this one.
*/

static int texlib_aux_someitem(lua_State *L, int code)
{
    switch (code) {
        /* the next two do not actually exist */
     /* case attrexpr_code: */
     /*     break;          */
            /* the expressions do something complicated with arguments, yuck */
        case numexpr_code:
        case dimexpr_code:
        case glueexpr_code:
        case muexpr_code:
        case numexpression_code:
        case dimexpression_code:
            break;
     // case dimen_to_scale_code:
        case numeric_scale_code:
            break;
        case index_of_register_code:
        case index_of_character_code:
            break;
        case last_chk_num_code:
        case last_chk_dim_code:
            break;
            /* these read a glue or muglue, todo */
        case mu_to_glue_code:
        case glue_to_mu_code:
        case glue_stretch_order_code:
        case glue_shrink_order_code:
        case glue_stretch_code:
        case glue_shrink_code:
            break;
            /* these read a fontid and a char, todo */
        case font_id_code:
        case glyph_x_scaled_code:
        case glyph_y_scaled_code:
            /* these read a font, todo */
        case font_spec_id_code:
        case font_spec_scale_code:
        case font_spec_xscale_code:
        case font_spec_yscale_code:
            /* these need a spec, todo */
            break;
        case font_char_wd_code:
        case font_char_ht_code:
        case font_char_dp_code:
        case font_char_ic_code:
        case font_char_ta_code:
            /* these read a char, todo */
            break;
        case font_size_code:
            lua_pushinteger(L, font_size(cur_font_par));
            break;
        case font_math_control_code:
            lua_pushinteger(L, font_mathcontrol(cur_font_par));
            break;
        case font_text_control_code:
            lua_pushinteger(L, font_textcontrol(cur_font_par));
            break;
        case math_scale_code:
            break;
        case math_style_code:
            {
                int style = tex_current_math_style();
                if (style >= 0) {
                    lua_pushinteger(L, style);
                    return 1;
                } else {
                    break;
                }
            }
            /* these read a char, todo */
        case math_main_style_code:
            {
                int style = tex_current_math_main_style();
                if (style >= 0) {
                    lua_pushinteger(L, style);
                    return 1;
                } else {
                    break;
                }
            }
            /* these read a char, todo */
        case math_char_class_code:
        case math_char_fam_code:
        case math_char_slot_code:
            break;
        case last_arguments_code:
            lua_pushinteger(L, lmt_expand_state.arguments);
            return 1;
        case parameter_count_code:
            lua_pushinteger(L, tex_get_parameter_count());
            return 1;
     /* case lua_value_function_code: */
     /*     break; */
        case insert_progress_code:
            break;
            /* these read an integer, todo */
        case left_margin_kern_code:
        case right_margin_kern_code:
            break;
        case par_shape_length_code:
        case par_shape_indent_code:
        case par_shape_dimen_code:
            break;
        case lastpenalty_code:
        case lastkern_code:
        case lastskip_code:
        case lastboundary_code:
        case last_node_type_code:
        case last_node_subtype_code:
        case input_line_no_code:
        case badness_code:
        case overshoot_code:
        case luatex_version_code:
        case luatex_revision_code:
        case current_group_level_code:
        case current_group_type_code:
        case current_if_level_code:
        case current_if_type_code:
        case current_if_branch_code:
            return texlib_aux_scan_internal(L, some_item_cmd, code, -1);
        case last_left_class_code:
            lua_pushinteger(L, lmt_math_state.last_left);
            return 1;
        case last_right_class_code:
            lua_pushinteger(L, lmt_math_state.last_right);
            return 1;
        case last_atom_class_code:
            lua_pushinteger(L, lmt_math_state.last_atom);
            return 1;
        case current_loop_iterator_code:
        case last_loop_iterator_code:
            lua_pushinteger(L, lmt_main_control_state.loop_iterator);
            return 1;
        case current_loop_nesting_code:
            lua_pushinteger(L, lmt_main_control_state.loop_nesting);
            return 1;
        case last_par_context_code:
            lua_pushinteger(L, lmt_main_control_state.last_par_context);
            return 1;
        case last_page_extra_code:
            lua_pushinteger(L, lmt_page_builder_state.last_extra_used);
            return 1;
    }
    lua_pushnil(L);
    return 1;
}

static int texlib_setmath(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 3) {
        quarterword level;
        int slot = lmt_check_for_level(L, 1, &level, cur_level);
        int param = lmt_get_math_parameter(L, slot++, -1);
        int style = lmt_get_math_style(L, slot++, -1);
        if (param < 0 || style < 0) {
            /* invalid spec, just ignore it  */
        } else {
            switch (math_parameter_value_type(param)) {
                case math_int_parameter:
                case math_dimen_parameter:
                case math_style_parameter:
                    tex_def_math_parameter(style, param, (scaled) lmt_optroundnumber(L, slot, 0), level, indirect_math_regular);
                    break;
                case math_muglue_parameter:
                    {
                        halfword p = tex_copy_node(zero_glue);
                        glue_amount(p) = lmt_optroundnumber(L, slot++, 0);
                        glue_stretch(p) = lmt_optroundnumber(L, slot++, 0);
                        glue_shrink(p) = lmt_optroundnumber(L, slot++, 0);
                        glue_stretch_order(p) = tex_checked_glue_order(lmt_optroundnumber(L, slot++, 0));
                        glue_shrink_order(p) = tex_checked_glue_order(lmt_optroundnumber(L, slot, 0));
                        tex_def_math_parameter(style, param, (scaled) p, level, indirect_math_regular);
                        break;
                    }
            }
        }
    }
    return 0;
}

static int texlib_getmath(lua_State *L)
{
    if (lua_gettop(L) == 2) {
        int param = lmt_get_math_parameter(L, 1, -1);
        int style = lmt_get_math_style(L, 2, -1);
        if (param >= 0 && style >= 0) {
            scaled value = tex_get_math_parameter(style, param, NULL);
            if (value != undefined_math_parameter) {
                switch (math_parameter_value_type(param)) {
                    case math_int_parameter:
                    case math_dimen_parameter:
                    case math_style_parameter:
                        lua_pushinteger(L, value);
                        return 1;
                    case math_muglue_parameter:
                        if (value <= thick_mu_skip_code) {
                            value = glue_parameter(value);
                        }
                        lua_pushinteger(L, glue_amount(value));
                        lua_pushinteger(L, glue_stretch(value));
                        lua_pushinteger(L, glue_shrink(value));
                        lua_pushinteger(L, glue_stretch_order(value));
                        lua_pushinteger(L, glue_shrink_order(value));
                        return 5;
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

/*tex

    This one is purely for diagnostic pusposed as normally there is some scaling
    involved related to the current style and such.

*/

static int texlib_getfontname(lua_State *L)
{
    return texlib_aux_convert(L, font_name_code);
}

static int texlib_getfontidentifier(lua_State *L)
{
    return texlib_aux_convert(L, font_identifier_code);
}

static int texlib_getfontoffamily(lua_State *L)
{
    int f = lmt_checkinteger(L, 1);
    int s = lmt_optinteger(L, 2, 0);  /* this should be a multiple of 256 ! */
    lua_pushinteger(L, tex_fam_fnt(f, s));
    return 1;
}

static int texlib_getnumber(lua_State *L)
{
    return texlib_aux_convert(L, number_code); /* check */
}

// static int texlib_getdimension(lua_State *L)
// {
//     return texlib_aux_convert(L, to_dimension_code); /* check */
// }

static int texlib_getromannumeral(lua_State *L)
{
    return texlib_aux_convert(L, roman_numeral_code);
}

static int texlib_get_internal(lua_State *L, int index, int all)
{
    if (lua_type(L, index) == LUA_TSTRING) {
        size_t l;
        const char *s = lua_tolstring(L, index, &l);
        if (l == 0) {
            return 0;
        } else if (lua_key_eq(s, prevdepth)) {
            lua_pushinteger(L, cur_list.prev_depth);
            return 1;
        } else if (lua_key_eq(s, prevgraf)) {
            lua_pushinteger(L, cur_list.prev_graf);
            return 1;
        } else if (lua_key_eq(s, spacefactor)) {
            lua_pushinteger(L, cur_list.space_factor);
            return 1;
        } else {
            /*tex
                We no longer get the info from the primitives hash but use the current
                primitive meaning.
            */ /*
            int ts = maketexlstring(s, l);
            int cs = prim_lookup(ts);
            flush_str(ts);
            if (cs > 0) {
            int cs = string_locate(s, l, 0);
            if (cs != undefined_control_sequence &&  has_eq_flag_bits(cs, primitive_flag_bit)) {
                int cmd = get_prim_eq_type(cs);
                int code = get_prim_equiv(cs);
            */
            int cs = tex_string_locate(s, l, 0);
            if (cs != undefined_control_sequence && has_eq_flag_bits(cs, primitive_flag_bit)) {
                int cmd = eq_type(cs);
                int code = eq_value(cs);
                switch (cmd) {
                    case some_item_cmd:
                        return texlib_aux_someitem(L, code);
                    case convert_cmd:
                        return texlib_aux_convert(L, code);
                    case internal_toks_cmd:
                    case register_toks_cmd:
                    case internal_int_cmd:
                    case register_int_cmd:
                    case internal_attribute_cmd:
                    case register_attribute_cmd:
                    case internal_dimen_cmd:
                    case register_dimen_cmd:
                    case lua_value_cmd:
                    case iterator_value_cmd:
                    case set_auxiliary_cmd:
                    case set_page_property_cmd:
                    case char_given_cmd:
                    case integer_cmd:
                    case dimension_cmd:
                    case gluespec_cmd:
                    case mugluespec_cmd:
                    case mathspec_cmd:
                    case fontspec_cmd:
                        return texlib_aux_scan_internal(L, cmd, code, -1);
                    case internal_glue_cmd:
                    case register_glue_cmd:
                    case internal_mu_glue_cmd:
                    case register_mu_glue_cmd:
                        return texlib_aux_scan_internal(L, cmd, code, all);
                    case set_specification_cmd:
                        return lmt_push_specification(L, specification_parameter(internal_specification_number(code)), all); /* all == countonly */
                    default:
                     /* tex_formatted_warning("tex.get", "ignoring cmd %i: %s\n", cmd, s); */
                        break;
                }
            }
        }
    }
    return 0;
}

static int texlib_get(lua_State *L)
{
    /* stack: key [boolean] */
    int ret = texlib_get_internal(L, 1, (lua_type(L, 2) == LUA_TBOOLEAN) ? lua_toboolean(L, 2) : -1);
    if (ret) {
        return ret;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int texlib_index(lua_State *L)
{
    /* stack: table key */
    int ret = texlib_get_internal(L, 2, -1);
    if (ret) {
        return ret;
    } else {
        lua_rawget(L, 1);
        return 1;
    }
}

static int texlib_getlist(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    if (! s) {
        lua_pushnil(L);
    } else if (lua_key_eq(s, pageinserthead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(page_insert_list_type, NULL));
    } else if (lua_key_eq(s, contributehead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(contribute_list_type, NULL));
    } else if (lua_key_eq(s, pagehead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(page_list_type, NULL));
    } else if (lua_key_eq(s, temphead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(temp_list_type, NULL));
    } else if (lua_key_eq(s, holdhead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(hold_list_type, NULL));
    } else if (lua_key_eq(s, postadjusthead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(post_adjust_list_type, NULL));
    } else if (lua_key_eq(s, preadjusthead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(pre_adjust_list_type, NULL));
    } else if (lua_key_eq(s, postmigratehead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(post_migrate_list_type, NULL));
    } else if (lua_key_eq(s, premigratehead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(pre_migrate_list_type, NULL));
    } else if (lua_key_eq(s, alignhead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(align_list_type, NULL));
    } else if (lua_key_eq(s, pagediscardshead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(page_discards_list_type, NULL));
    } else if (lua_key_eq(s, splitdiscardshead)) {
        lmt_push_node_fast(L, tex_get_special_node_list(split_discards_list_type, NULL));
    } else if (lua_key_eq(s, bestpagebreak)) {
        lmt_push_node_fast(L, lmt_page_builder_state.best_break);
    } else if (lua_key_eq(s, leastpagecost)) {
        lua_pushinteger(L, lmt_page_builder_state.least_cost);
    } else if (lua_key_eq(s, bestsize)) {
        lua_pushinteger(L, lmt_page_builder_state.best_size); /* is pagegoal but can be unset and also persistent */
    } else if (lua_key_eq(s, insertpenalties)) {
        lua_pushinteger(L, lmt_page_builder_state.insert_penalties);
    } else if (lua_key_eq(s, insertheights)) {
        lua_pushinteger(L, lmt_page_builder_state.insert_heights);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* todo: accept direct node too */

static int texlib_setlist(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    if (! s) {
        /* This is silently ignored */
    } else if (lua_key_eq(s, bestsize)) {
      lmt_page_builder_state.best_size = lmt_toscaled(L, 2); /* is pagegoal but can be unset and also persistent */
    } else if (lua_key_eq(s, leastpagecost)) {
        lmt_page_builder_state.least_cost = lmt_tointeger(L, 2);
    } else if (lua_key_eq(s, insertpenalties)) {
        lmt_page_builder_state.insert_penalties = lmt_tointeger(L, 2);
    } else if (lua_key_eq(s, insertheights)) {
        lmt_page_builder_state.insert_heights = lmt_tointeger(L, 2);
    } else {
        halfword n = null;
        if (! lua_isnil(L, 2)) {
            n = lmt_check_isnode(L, 2);
        }
        if (lua_key_eq(s, pageinserthead)) {
            tex_set_special_node_list(page_insert_list_type, n);
        } else if (lua_key_eq(s, contributehead)) {
            tex_set_special_node_list(contribute_list_type, n);
        } else if (lua_key_eq(s, pagehead)) {
            tex_set_special_node_list(page_list_type, n);
        } else if (lua_key_eq(s, temphead)) {
            tex_set_special_node_list(temp_list_type, n);
        } else if (lua_key_eq(s, pagediscardshead)) {
            tex_set_special_node_list(page_discards_list_type, n);
        } else if (lua_key_eq(s, splitdiscardshead)) {
            tex_set_special_node_list(split_discards_list_type, n);
        } else if (lua_key_eq(s, holdhead)) {
            tex_set_special_node_list(hold_list_type, n);
        } else if (lua_key_eq(s, postadjusthead)) {
            tex_set_special_node_list(post_adjust_list_type, n);
        } else if (lua_key_eq(s, preadjusthead)) {
            tex_set_special_node_list(pre_adjust_list_type, n);
        } else if (lua_key_eq(s, postmigratehead)) {
            tex_set_special_node_list(post_migrate_list_type, n);
        } else if (lua_key_eq(s, premigratehead)) {
            tex_set_special_node_list(pre_migrate_list_type, n);
        } else if (lua_key_eq(s, alignhead)) {
            tex_set_special_node_list(align_list_type, n);
        } else if (lua_key_eq(s, bestpagebreak)) {
            lmt_page_builder_state.best_break = n;
        }
    }
    return 0;
}

static void texlib_get_nest_field(lua_State *L, const char *field, list_state_record *r)
{

    if (lua_key_eq(field, mode)) {
        lua_pushinteger(L, r->mode);
    } else if (lua_key_eq(field, head) || lua_key_eq(field, list)) {
        /* we no longer check for special list nodes here so beware of prev-of-head */
        lmt_push_node_fast(L, r->head);
    } else if (lua_key_eq(field, tail)) {
        /* we no longer check for special list nodes here so beware of next-of-tail */
        lmt_push_node_fast(L, r->tail);
    } else if (lua_key_eq(field, delimiter)) {
        lmt_push_node_fast(L, r->delim);
    } else if (lua_key_eq(field, prevgraf)) {
        lua_pushinteger(L, r->prev_graf);
    } else if (lua_key_eq(field, modeline)) {
        lua_pushinteger(L, r->mode_line);
    } else if (lua_key_eq(field, prevdepth)) {
        lua_pushinteger(L, r->prev_depth);
    } else if (lua_key_eq(field, spacefactor)) {
        lua_pushinteger(L, r->space_factor);
    } else if (lua_key_eq(field, noad)) {
        lmt_push_node_fast(L, r->incomplete_noad);
    } else if (lua_key_eq(field, direction)) {
        lmt_push_node_fast(L, r->direction_stack);
    } else if (lua_key_eq(field, mathdir)) {
        lua_pushboolean(L, r->math_dir);
    } else if (lua_key_eq(field, mathstyle)) {
        lua_pushinteger(L, r->math_style);
    } else {
        lua_pushnil(L);
    }
}

static void texlib_set_nest_field(lua_State *L, int n, const char *field, list_state_record *r)
{
    if (lua_key_eq(field, mode)) {
        r->mode = lmt_tointeger(L, n);
    } else if (lua_key_eq(field, head) || lua_key_eq(field, list)) {
        r->head = lmt_check_isnode(L, n);
    } else if (lua_key_eq(field, tail)) {
        r->tail = lmt_check_isnode(L, n);
    } else if (lua_key_eq(field, delimiter)) {
        r->delim = lmt_check_isnode(L, n);
    } else if (lua_key_eq(field, prevgraf)) {
        r->prev_graf = lmt_tointeger(L, n);
    } else if (lua_key_eq(field, modeline)) {
        r->mode_line = lmt_tointeger(L, n);
    } else if (lua_key_eq(field, prevdepth)) {
        r->prev_depth = lmt_toroundnumber(L, n);
    } else if (lua_key_eq(field, spacefactor)) {
        r->space_factor = lmt_toroundnumber(L, n);
    } else if (lua_key_eq(field, noad)) {
        r->incomplete_noad = lmt_check_isnode(L, n);
    } else if (lua_key_eq(field, direction)) {
        r->direction_stack = lmt_check_isnode(L, n);
    } else if (lua_key_eq(field, mathdir)) {
        r->math_dir = lua_toboolean(L, n);
    } else if (lua_key_eq(field, mathstyle)) {
        r->math_style = lmt_tointeger(L, n);
    }
}

static int texlib_aux_nest_getfield(lua_State *L)
{
    list_state_record **rv = lua_touserdata(L, -2);
    list_state_record *r = *rv;
    const char *field = lua_tostring(L, -1);
    texlib_get_nest_field(L, field, r);
    return 1;
}

static int texlib_aux_nest_setfield(lua_State *L)
{
    list_state_record **rv = lua_touserdata(L, -3);
    list_state_record *r = *rv;
    const char *field = lua_tostring(L, -2);
    texlib_set_nest_field(L, -1, field, r);
    return 0;
}

static const struct luaL_Reg texlib_nest_metatable[] = {
    { "__index",    texlib_aux_nest_getfield },
    { "__newindex", texlib_aux_nest_setfield },
    { NULL,         NULL                     },
};

static void texlib_aux_init_nest_lib(lua_State *L)
{
    luaL_newmetatable(L, TEX_NEST_INSTANCE);
    luaL_setfuncs(L, texlib_nest_metatable, 0);
    lua_pop(L, 1);
}

/* getnest(<number>|top|ptr,[fieldname]) */

static int texlib_getnest(lua_State *L)
{
    int p = -1 ;
    int t = lua_gettop(L);
    if (t == 0) {
        p = lmt_nest_state.nest_data.ptr;
    } else {
        switch (lua_type(L, 1)) {
            case LUA_TNUMBER:
                {
                    int ptr = lmt_tointeger(L, 1);
                    if (ptr >= 0 && ptr <= lmt_nest_state.nest_data.ptr) {
                        p = ptr;
                    }
                }
                break;
            case LUA_TSTRING:
                {
                    const char *s = lua_tostring(L, 1);
                    if (lua_key_eq(s, top)) {
                        p = lmt_nest_state.nest_data.ptr;
                    } else if (lua_key_eq(s, ptr)) {
                        lua_pushinteger(L, lmt_nest_state.nest_data.ptr);
                        return 1;
                    }
                }
                break;
        }
    }
    if (p > -1) {
         if (t > 1) {
            const char *field = lua_tostring(L, 2);
            if (field) {
                texlib_get_nest_field(L, field, &lmt_nest_state.nest[p]);
            } else {
                lua_pushnil(L);
            }
        } else {
            list_state_record **nestitem = lua_newuserdatauv(L, sizeof(list_state_record *), 0);
            *nestitem = &lmt_nest_state.nest[p];
            luaL_getmetatable(L, TEX_NEST_INSTANCE);
            lua_setmetatable(L, -2);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* setnest(<number>|top,fieldname,value) */

static int texlib_setnest(lua_State *L)
{
    if (lua_gettop(L) > 2) {
        int p = -1 ;
        switch (lua_type(L, 1)) {
            case LUA_TNUMBER:
                {
                    int ptr = lmt_tointeger(L, 1);
                    if (ptr >= 0 && ptr <= lmt_nest_state.nest_data.ptr) {
                        p = ptr;
                    }
                }
                break;
            case LUA_TSTRING:
                {
                    const char *s = lua_tostring(L, 1);
                    if (lua_key_eq(s, top)) {
                        p = lmt_nest_state.nest_data.ptr;
                    }
                }
                break;
        }
        if (p > -1) {
            const char *field = lua_tostring(L, 2);
            if (field) {
                texlib_set_nest_field(L, 3, field, &lmt_nest_state.nest[p]);
            }
        }
    }
    return 0;
}

static int texlib_round(lua_State *L)
{
 /* lua_pushinteger(L, lmt_roundedfloat((double) lua_tonumber(L, 1))); */
    lua_pushinteger(L, clippedround((double) lua_tonumber(L, 1)));
    return 1;
}

static int texlib_scale(lua_State *L)
{
    double delta = luaL_checknumber(L, 2);
    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            {
                /*tex
                    We could preallocate the table or maybe scale in-place. The
                    new table is at index 3.
                */
                lua_newtable(L);
                lua_pushnil(L);
                while (lua_next(L, 1)) {
                    /*tex We have a numeric value. */
                    lua_pushvalue(L, -2);
                    lua_insert(L, -2);
                    if (lua_type(L, -2) == LUA_TNUMBER) {
                        double m = (double) lua_tonumber(L, -1) * delta;
                        lua_pop(L, 1);
                     /* lua_pushinteger(L, lmt_roundedfloat(m)); */
                        lua_pushinteger(L, clippedround(m));
                    }
                    lua_rawset(L, 3);
                }
            }
            break;
        case LUA_TNUMBER:
         /* lua_pushinteger(L, lmt_roundedfloat((double) lua_tonumber(L, 1) * delta)); */
            lua_pushinteger(L, clippedround((double) lua_tonumber(L, 1) * delta));
            break;
        default:
            lua_pushnil(L);
            break;
    }
    return 1;
}

/*tex
    For compatibility reasons we keep the check for a boolean for a while. For consistency
    we now support flags too: |global cs id|.

*/

static int texlib_definefont(lua_State *L)
{
    size_t l;
    int slot = 1;
    int flags = (lua_isboolean(L, slot) && lua_toboolean(L, slot++)) ? add_global_flag(0) : 0;
    const char *csname = lua_tolstring(L, slot++, &l);
    halfword id = lmt_tohalfword(L, slot++);
    int cs = tex_string_locate(csname, l, 1);
    lmt_check_for_flags(L, slot, &flags, 1, 1);
    tex_define(flags, cs, set_font_cmd, id);
    return 0;
}

static int texlib_hashtokens(lua_State *L)
{
    int cs = 1;
    int nt = 0;
    int nx = 0;
    int all = lua_toboolean(L, 1);
    lua_createtable(L, hash_size, 0);
    /* todo: check active characters as these have three bogus bytes in front */
    if (all) {
        while (cs <= hash_size) {
            strnumber s = cs_text(cs);
            if (s > 0) {
                halfword n = cs_next(cs);
                if (n) {
                    int mt = 0;
                    lua_createtable(L, 2, 0);
                    lua_pushstring(L, tex_to_cstring(s));
                    ++nt;
                    lua_rawseti(L, -2, ++mt);
                    while (n) {
                        s = cs_text(n);
                        if (s) {
                            lua_pushstring(L, tex_to_cstring(s));
                            lua_rawseti(L, -2, ++mt);
                            ++nt;
                            ++nx;
                        }
                        n = cs_next(n);
                    }
                } else {
                    lua_pushstring(L, tex_to_cstring(s));
                    ++nt;
                }
            } else {
                lua_pushboolean(L, 0);
            }
            lua_rawseti(L, -2, cs);
            cs++;
        }
    } else {
        while (cs < hash_size) {
            strnumber s = cs_text(cs);
            if (s > 0) {
                halfword n = cs_next(cs);
                lua_pushstring(L, tex_to_cstring(s));
                lua_rawseti(L, -2, ++nt);
                while (n) {
                    s = cs_text(n);
                    if (s) {
                        lua_pushstring(L, tex_to_cstring(s));
                        lua_rawseti(L, -2, ++nt);
                        ++nx;
                    }
                    n = cs_next(n);
                }
            }
            cs++;
        }
    }
    lua_pushinteger(L, --cs);
    lua_pushinteger(L, nt);
    lua_pushinteger(L, nx);
    return 4;
}

static int texlib_primitives(lua_State *L)
{
    int cs = 0;
    int nt = 0;
    lua_createtable(L, prim_size, 0);
    while (cs < prim_size) {
        strnumber s = get_prim_text(cs);
        if (s > 0 && (get_prim_origin(cs) != no_command)) {
            lua_pushstring(L, tex_to_cstring(s));
            lua_rawseti(L, -2, ++nt);
        }
        cs++;
    }
    return 1;
}

static int texlib_extraprimitives(lua_State *L)
{
    int mask = 0;
    int cs = 0;
    int nt = 0;
    int n = lua_gettop(L);
    if (n == 0) {
        mask = tex_command + etex_command + luatex_command;
    } else {
        for (int i = 1; i <= n; i++) {
            if (lua_type(L, i) == LUA_TSTRING) {
                const char *s = lua_tostring(L, i);
                if (lua_key_eq(s, tex)) {
                    mask |= tex_command;
                } else if (lua_key_eq(s, etex)) {
                    mask |= etex_command;
                } else if (lua_key_eq(s, luatex)) {
                    mask |= luatex_command;
                }
            }
        }
    }
    lua_createtable(L, prim_size, 0);
    while (cs < prim_size) {
        strnumber s = get_prim_text(cs);
        if (s > 0 && (get_prim_origin(cs) & mask)) {
            lua_pushstring(L, tex_to_cstring(s));
            lua_rawseti(L, -2, ++nt);
        }
        cs++;
    }
    return 1;
}

static void texlib_aux_enableprimitive(const char *pre, size_t prel, const char *prm)
{
    strnumber s = tex_maketexstring(prm);
    halfword prm_val = tex_prim_lookup(s); /* todo: no need for tex string */
    tex_flush_str(s);
    if (prm_val != undefined_primitive && get_prim_origin(prm_val) != no_command) {
        char *newprm;
        size_t newlen;
        halfword cmd = get_prim_eq_type(prm_val);
        halfword chr = get_prim_equiv(prm_val);
        if (strncmp(pre, prm, prel) != 0) {
            /* not a prefix */
            newlen = strlen(prm) + prel;
            newprm = (char *) lmt_memory_malloc((size_t) newlen + 1);
            if (newprm) {
                strcpy(newprm, pre);
                strcat(newprm + prel, prm);
            } else {
                tex_overflow_error("primitives", (int) newlen + 1);
            }
        } else {
            newlen = strlen(prm);
            newprm = (char *) lmt_memory_malloc((size_t) newlen + 1);
            if (newprm) {
                strcpy(newprm, prm);
            } else {
                tex_overflow_error("primitives", (int) newlen + 1);
            }
        }
        if (newprm) {
            halfword val = tex_string_locate(newprm, newlen, 1);
            if (val == undefined_control_sequence || eq_type(val) == undefined_cs_cmd) {
                tex_primitive_def(newprm, newlen, (singleword) cmd, chr);
            }
            lmt_memory_free(newprm);
        }
    }
}

static int texlib_enableprimitives(lua_State *L)
{
    if (lua_gettop(L) == 2) {
        size_t lpre;
        const char *pre = luaL_checklstring(L, 1, &lpre);
        switch (lua_type(L, 2)) {
            case LUA_TTABLE:
                {
                    int i = 1;
                    while (1) {
                        if (lua_rawgeti(L, 2, i) == LUA_TSTRING) {
                            const char *prm = lua_tostring(L, 3);
                            texlib_aux_enableprimitive(pre, lpre, prm);
                        } else {
                            lua_pop(L, 1);
                            break;
                        }
                        lua_pop(L, 1);
                        i++;
                    }
                }
                break;
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, 2)) {
                    for (int cs = 0; cs < prim_size; cs++) {
                        strnumber s = get_prim_text(cs);
                        if (s > 0) {
                            char *prm = tex_to_cstring(s);
                            texlib_aux_enableprimitive(pre, lpre, prm);
                        }
                    }
                }
                break;
            default:
                luaL_error(L, "array of names or 'true' expected");
        }
    } else {
        luaL_error(L, "wrong number of arguments");
    }
    return 0;
}

/*tex penalties */

static halfword texlib_topenalties(lua_State *L, int i, quarterword s)
{
    int n = 0;
    lua_pushnil(L);
    while (lua_next(L, i)) {
        n++;
        lua_pop(L, 1);
    }
    if (n > 0) {
        int j = 0;
        halfword p = tex_new_specification_node(n, s, 0); /* todo: repeat */
        lua_pushnil(L);
        while (lua_next(L, i)) {
            j++;
            if (lua_type(L, -1) == LUA_TNUMBER) {
                tex_set_specification_penalty(p, j, lmt_tohalfword(L, -1));
            }
            lua_pop(L, 1);
        }
        return p;
    } else {
        return null;
    }
}

/*tex We should check for proper glue spec nodes ... todo. */

# define get_dimen_par(P,A,B) \
    lua_push_key(A); \
    P = (lua_rawget(L, -2) == LUA_TNUMBER) ? lmt_roundnumber(L, -1) : B; \
    lua_pop(L, 1);

# define get_glue_par(P,A,B) \
    lua_push_key(A); \
    P = (lua_rawget(L, -2) == LUA_TUSERDATA) ? lmt_check_isnode(L, -1) : B; \
    lua_pop(L, 1);

# define get_integer_par(P,A,B) \
    lua_push_key(A); \
    P = (lua_rawget(L, -2) == LUA_TNUMBER) ? lmt_tohalfword(L, -1) : B; \
    lua_pop(L, 1);

# define get_penalties_par(P,A,B,C) \
    lua_push_key(A); \
    P = (lua_rawget(L, -2) == LUA_TTABLE) ? texlib_topenalties(L, lua_gettop(L), C) : B; \
    lua_pop(L, 1);

# define get_shape_par(P,A,B) \
    lua_push_key(A); \
    P = (lua_rawget(L, -2) == LUA_TTABLE) ? texlib_toparshape(L, lua_gettop(L)) : B; \
    lua_pop(L, 1);

/*tex
    The next function needs to be kept in sync with the regular linebreak handler, wrt the special 
    skips. This one can be called from within the callback so then we already have intialized. 
*/


/* par leftinit rightinit leftindent ... leftfill rightfill */

static int texlib_preparelinebreak(lua_State *L)
{
    halfword direct;
    halfword par = lmt_check_isdirectornode(L, 1, &direct);
    if (node_type(par) == par_node) {
        halfword tail = tex_tail_of_node_list(par);
        if (node_type(tail) == glue_node && node_subtype(tail) == par_fill_right_skip_glue) { 
            tex_formatted_warning("linebreak", "list seems already prepared");
        } else { 
            halfword parinit_left_skip_glue = null;
            halfword parinit_right_skip_glue = null;
            halfword parfill_left_skip_glue = null;
            halfword parfill_right_skip_glue = null;
            halfword final_penalty = null;
            tex_line_break_prepare(par, &tail, &parinit_left_skip_glue, &parinit_right_skip_glue, &parfill_left_skip_glue, &parfill_right_skip_glue, &final_penalty);
            lmt_push_directornode(L, par, direct);
            lmt_push_directornode(L, tail, direct);
            lmt_push_directornode(L, parinit_left_skip_glue, direct);
            lmt_push_directornode(L, parinit_right_skip_glue, direct);
            lmt_push_directornode(L, parfill_left_skip_glue , direct);
            lmt_push_directornode(L, parfill_right_skip_glue, direct);
         /* lmt_push_directornode(L, final_penalty, direct); */ /*tex Not that relevant to know. */
            return 6;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int texlib_linebreak(lua_State *L)
{
 // halfword par = lmt_check_isnode(L, 1);
    halfword direct;
    halfword par = lmt_check_isdirectornode(L, 1, &direct);
    if (node_type(par) == par_node) {
        line_break_properties properties;
        halfword tail = par; 
        halfword has_indent = null;
        halfword has_penalty = 0;
        halfword prepared = 0;
        properties.initial_par = par;
        properties.display_math = 0;
        properties.paragraph_dir = par_dir(par);
        properties.parfill_left_skip = null;
        properties.parfill_right_skip = null;
        properties.parinit_left_skip = null;
        properties.parinit_right_skip = null;
        while (tail) { 
            switch (node_type(tail)) { 
                case glue_node:
                    switch (node_subtype(tail)) { 
                        case indent_skip_glue:
                            if (has_indent) { 
                                tex_formatted_warning("linebreak", "duplicate %s glue in tex.linebreak", "indent");
                                goto NOTHING;
                            } else { 
                                has_indent = 1;
                            }
                            break;
                        case par_fill_left_skip_glue:
                            if (properties.parfill_left_skip) { 
                                tex_formatted_warning("linebreak", "duplicate %s glue in tex.linebreak", "leftskip");
                                goto NOTHING;
                            } else {
                                properties.parfill_left_skip = tail;
                            }
                            break;
                        case par_fill_right_skip_glue:
                            if (properties.parfill_right_skip) { 
                                tex_formatted_warning("linebreak", "duplicate %s glue in tex.linebreak", "rightskip");
                                goto NOTHING;
                            } else {
                                properties.parfill_right_skip = tail;
                            }
                            break;
                        case par_init_left_skip_glue:
                            if (properties.parinit_left_skip) { 
                                tex_formatted_warning("linebreak", "duplicate %s glue in tex.linebreak", "leftinit");
                                goto NOTHING;
                            } else {
                                properties.parinit_left_skip = tail;
                            }
                            break;
                        case par_init_right_skip_glue:
                            if (properties.parinit_right_skip) { 
                                tex_formatted_warning("linebreak", "duplicate %s glue in tex.linebreak", "rightinit");
                                goto NOTHING;
                            } else {
                                properties.parinit_right_skip = tail;
                            }
                            break;
                    }
                    break;
                case penalty_node: 
                    if (node_subtype(tail) == line_penalty_subtype && penalty_amount(tail) == infinite_penalty && ! (properties.parfill_left_skip && properties.parfill_right_skip)) { 
                        has_penalty = 1;
                    }
            }
            if (node_next(tail)) {
                tail = node_next(tail);
            } else {
                break;
            }
        }
        { 
            int has_init = properties.parinit_left_skip && properties.parinit_right_skip;
            int has_fill = properties.parfill_left_skip && properties.parfill_right_skip;
            if (lmt_linebreak_state.calling_back) {
                if (has_indent && ! (has_init && has_fill && has_penalty)) {
                    tex_formatted_warning("linebreak", "[ par + leftinit + rightinit + indentglue + ... + penalty + leftfill + righfill ] expected");
                    goto NOTHING;
                } else if (! (has_fill && has_penalty)) {
                    tex_formatted_warning("linebreak", "[ par + indentbox + ... + penalty + leftfill + righfill ] expected");
                    goto NOTHING;
                } else {
                    prepared = 1; 
                }
            } else {
                if (! (has_indent && has_init && has_fill)) {
                    tex_formatted_warning("linebreak", "[ leftinit | rightinit | leftfill | rigthfill ] expected");
                    goto NOTHING;
                } else {
                 // prepared = 0; 
                    prepared = has_init && has_fill; 
                }
            }
        }
        tex_push_nest();
        node_next(temp_head) = par;
        /*tex initialize local parameters */
        if (lua_gettop(L) != 2 || lua_type(L, 2) != LUA_TTABLE) {
            lua_newtable(L);
        }
        lua_push_key(direction);
        if (lua_rawget(L, -2) == LUA_TNUMBER) {
            properties.paragraph_dir = checked_direction_value(lmt_tointeger(L, -1));
        }
        lua_pop(L, 1);
        get_integer_par  (properties.tracing_paragraphs,     tracingparagraphs,    tracing_paragraphs_par);
        get_integer_par  (properties.pretolerance,           pretolerance,         tex_get_par_par(par, par_pre_tolerance_code));
        get_integer_par  (properties.tolerance,              tolerance,            tex_get_par_par(par, par_tolerance_code));
        get_dimen_par    (properties.emergency_stretch,      emergencystretch,     tex_get_par_par(par, par_emergency_stretch_code));
        get_integer_par  (properties.looseness,              looseness,            tex_get_par_par(par, par_looseness_code));
        get_integer_par  (properties.adjust_spacing,         adjustspacing,        tex_get_par_par(par, par_adjust_spacing_code));
        get_integer_par  (properties.protrude_chars,         protrudechars,        tex_get_par_par(par, par_protrude_chars_code));
        get_integer_par  (properties.adj_demerits,           adjdemerits,          tex_get_par_par(par, par_adj_demerits_code));
        get_integer_par  (properties.line_penalty,           linepenalty,          tex_get_par_par(par, par_line_penalty_code));
        get_integer_par  (properties.last_line_fit,          lastlinefit,          tex_get_par_par(par, par_last_line_fit_code));
        get_integer_par  (properties.double_hyphen_demerits, doublehyphendemerits, tex_get_par_par(par, par_double_hyphen_demerits_code));
        get_integer_par  (properties.final_hyphen_demerits,  finalhyphendemerits,  tex_get_par_par(par, par_final_hyphen_demerits_code));
        get_dimen_par    (properties.hsize,                  hsize,                tex_get_par_par(par, par_hsize_code));
        get_glue_par     (properties.left_skip,              leftskip,             tex_get_par_par(par, par_left_skip_code));
        get_glue_par     (properties.right_skip,             rightskip,            tex_get_par_par(par, par_right_skip_code));
        get_dimen_par    (properties.hang_indent,            hangindent,           tex_get_par_par(par, par_hang_indent_code));
        get_integer_par  (properties.hang_after,             hangafter,            tex_get_par_par(par, par_hang_after_code));
        get_integer_par  (properties.inter_line_penalty,     interlinepenalty,     tex_get_par_par(par, par_inter_line_penalty_code));
        get_integer_par  (properties.club_penalty,           clubpenalty,          tex_get_par_par(par, par_club_penalty_code));
        get_integer_par  (properties.widow_penalty,          widowpenalty,         tex_get_par_par(par, par_widow_penalty_code));
        get_integer_par  (properties.display_widow_penalty,  displaywidowpenalty,  tex_get_par_par(par, par_display_widow_penalty_code));
        get_integer_par  (properties.orphan_penalty,         orphanpenalty,        tex_get_par_par(par, par_orphan_penalty_code));
        get_integer_par  (properties.broken_penalty,         brokenpenalty,        tex_get_par_par(par, par_broken_penalty_code));
        get_glue_par     (properties.baseline_skip,          baselineskip,         tex_get_par_par(par, par_baseline_skip_code));
        get_glue_par     (properties.line_skip,              lineskip,             tex_get_par_par(par, par_line_skip_code));
        get_dimen_par    (properties.line_skip_limit,        lineskiplimit,        tex_get_par_par(par, par_line_skip_limit_code));
        get_integer_par  (properties.adjust_spacing,         adjustspacing,        tex_get_par_par(par, par_adjust_spacing_code));
        get_integer_par  (properties.adjust_spacing_step,    adjustspacingstep,    tex_get_par_par(par, par_adjust_spacing_step_code));
        get_integer_par  (properties.adjust_spacing_shrink,  adjustspacingshrink,  tex_get_par_par(par, par_adjust_spacing_shrink_code));
        get_integer_par  (properties.adjust_spacing_stretch, adjustspacingstretch, tex_get_par_par(par, par_adjust_spacing_stretch_code));
        get_integer_par  (properties.hyphenation_mode,       hyphenationmode,      tex_get_par_par(par, par_hyphenation_mode_code));
        get_integer_par  (properties.shaping_penalties_mode, shapingpenaltiesmode, tex_get_par_par(par, par_shaping_penalties_mode_code));
        get_integer_par  (properties.shaping_penalty,        shapingpenalty,       tex_get_par_par(par, par_shaping_penalty_code));
        get_shape_par    (properties.par_shape,              parshape,             tex_get_par_par(par, par_par_shape_code));
        get_penalties_par(properties.inter_line_penalties,   interlinepenalties,   tex_get_par_par(par, par_inter_line_penalties_code), inter_line_penalties_code);
        get_penalties_par(properties.club_penalties,         clubpenalties,        tex_get_par_par(par, par_club_penalties_code), club_penalties_code);
        get_penalties_par(properties.widow_penalties,        widowpenalties,       tex_get_par_par(par, par_widow_penalties_code), widow_penalties_code);
        get_penalties_par(properties.display_widow_penalties,displaywidowpenalties,tex_get_par_par(par, par_display_widow_penalties_code), display_widow_penalties_code);
        get_penalties_par(properties.orphan_penalties,       orphanpenalties,      tex_get_par_par(par, par_orphan_penalties_code), orphan_penalties_code);
        if (! prepared) {
            halfword attr_template = tail;
            halfword final_penalty = tex_new_penalty_node(infinite_penalty, line_penalty_subtype);
            /* */
            get_glue_par(properties.parfill_left_skip,  parfillleftskip,  tex_get_par_par(par, par_par_fill_left_skip_code));
            get_glue_par(properties.parfill_right_skip, parfillrightskip, tex_get_par_par(par, par_par_fill_right_skip_code));
            get_glue_par(properties.parinit_left_skip,  parinitleftskip,  tex_get_par_par(par, par_par_init_left_skip_code));
            get_glue_par(properties.parinit_right_skip, parinitrightskip, tex_get_par_par(par, par_par_init_right_skip_code));
            /* */
            properties.parfill_left_skip = tex_new_glue_node(properties.parfill_left_skip, par_fill_left_skip_glue);
            properties.parfill_right_skip = tex_new_glue_node(properties.parfill_right_skip, par_fill_right_skip_glue);
            tex_attach_attribute_list_copy(final_penalty, attr_template);
            tex_attach_attribute_list_copy(properties.parfill_left_skip, attr_template); 
            tex_attach_attribute_list_copy(properties.parfill_right_skip, attr_template); 
            tex_couple_nodes(tail, final_penalty);
            tex_couple_nodes(final_penalty, properties.parfill_left_skip);
            tex_couple_nodes(properties.parfill_left_skip, properties.parfill_right_skip);
            if (node_next(par)) { /* test can go, also elsewhere */
                 halfword n = node_next(par);
                 while (n) {
                     if (node_type(n) == glue_node && node_subtype(n) == indent_skip_glue) {
                         properties.parinit_left_skip = tex_new_glue_node(properties.parinit_left_skip, par_init_left_skip_glue);
                         properties.parinit_right_skip = tex_new_glue_node(properties.parinit_right_skip, par_init_right_skip_glue);
                         tex_attach_attribute_list_copy(properties.parinit_left_skip, attr_template); // maybe head .. also elsewhere
                         tex_attach_attribute_list_copy(properties.parinit_right_skip, attr_template); // maybe head .. also elsewhere
                         tex_try_couple_nodes(properties.parinit_right_skip, n);
                         tex_try_couple_nodes(properties.parinit_left_skip, properties.parinit_right_skip);
                         tex_try_couple_nodes(par, properties.parinit_left_skip);
                         break;
                     } else {
                         n = node_next(n);
                     }
                 }
             }
        }
        lmt_linebreak_state.last_line_fill = properties.parfill_right_skip; /*tex I need to redo this. */
        tex_do_line_break(&properties);
        {
            halfword fewest_demerits = 0;
            halfword actual_looseness = 0;
            /*tex return the generated list, and its prevdepth */
            tex_get_linebreak_info(&fewest_demerits, &actual_looseness) ;
            lmt_push_directornode(L, node_next(cur_list.head), direct);
            lua_createtable(L, 0, 4);
            /* set_integer_by_key(L, demerits, fewest_demerits); */
            lua_push_key(demerits);
            lua_pushinteger(L, fewest_demerits);
            lua_settable(L, -3);
            /* set_integer_by_key(L, looseness, actual_looseness); */
            lua_push_key(looseness);
            lua_pushinteger(L, actual_looseness);
            lua_settable(L, -3);
            /* set_integer_by_key(L, prevdepth, cur_list.prev_depth); */
            lua_push_key(prevdepth);
            lua_pushinteger(L, cur_list.prev_depth);
            lua_settable(L, -3);
            /* set_integer_by_key(L, prevgraf, cur_list.prev_graf); */
            lua_push_key(prevgraf);
            lua_pushinteger(L, cur_list.prev_graf);
            lua_settable(L, -3);
        }
        tex_pop_nest();
        if (properties.par_shape               != tex_get_par_par(par, par_par_shape_code))               { tex_flush_node(properties.par_shape); }
        if (properties.inter_line_penalties    != tex_get_par_par(par, par_inter_line_penalties_code))    { tex_flush_node(properties.inter_line_penalties); }
        if (properties.club_penalties          != tex_get_par_par(par, par_club_penalties_code))          { tex_flush_node(properties.club_penalties); }
        if (properties.widow_penalties         != tex_get_par_par(par, par_widow_penalties_code))         { tex_flush_node(properties.widow_penalties); }
        if (properties.display_widow_penalties != tex_get_par_par(par, par_display_widow_penalties_code)) { tex_flush_node(properties.display_widow_penalties); }
        if (properties.orphan_penalties        != tex_get_par_par(par, par_orphan_penalties_code))        { tex_flush_node(properties.orphan_penalties); }
        return 2;
    } else { 
        tex_formatted_warning("linebreak", "[ par ... ] expected");
    }
  NOTHING:
    lmt_push_directornode(L, par, direct);
    return 1;
}

static int texlib_resetparagraph(lua_State *L)
{
    (void) L;
    tex_normal_paragraph(reset_par_context);
    return 0;
}

static int texlib_shipout(lua_State *L)
{
    int boxnum = lmt_get_box_id(L, 1, 1);
    if (box_register(boxnum)) {
        tex_flush_node_list(box_register(boxnum));
        box_register(boxnum) = null;
    }
    return 0;
}

static int texlib_badness(lua_State *L)
{
    scaled t = lmt_roundnumber(L, 1);
    scaled s = lmt_roundnumber(L, 2);
    lua_pushinteger(L, tex_badness(t, s));
    return 1;
}

static int texlib_showcontext(lua_State *L)
{
    (void) L;
    tex_show_context();
    return 0;
}

/*tex
    When we pass |true| the page builder will only be invoked in the main vertical list in which
    case |lmt_nest_state.nest_data.ptr == 1| or |cur_list.mode != vmode|.
*/

static int texlib_triggerbuildpage(lua_State *L)
{
    if (lua_toboolean(L, 1) && cur_list.mode != vmode) {
        return 0;
    }
    tex_build_page();
    return 0;
}

static int texlib_getpagestate(lua_State *L)
{
    lua_pushinteger(L, lmt_page_builder_state.contents);
    return 1;
}

static int texlib_getlocallevel(lua_State *L)
{
    lua_pushinteger(L, lmt_main_control_state.local_level);
    return 1;
}

/* input state aka synctex */

static int texlib_setinputstatemode(lua_State *L)
{
    input_file_state.mode = lmt_tohalfword(L, 1);
    return 0;
}
static int texlib_getinputstatemode(lua_State *L)
{
    lua_pushinteger(L, input_file_state.mode);
    return 1;
}

static int texlib_setinputstatefile(lua_State *L)
{
    lmt_input_state.cur_input.state_file = lmt_tointeger(L, 1);
    return 0;
}

static int texlib_getinputstatefile(lua_State *L)
{
    lua_pushinteger(L, lmt_input_state.cur_input.state_file);
    return 1;
}

static int texlib_forceinputstatefile(lua_State *L)
{
    input_file_state.forced_file = lmt_tointeger(L, 1);
    return 0;
}

static int texlib_forceinputstateline(lua_State *L)
{
    input_file_state.forced_line = lmt_tointeger(L, 1);
    return 0;
}

static int texlib_setinputstateline(lua_State *L)
{
    input_file_state.line = lmt_tohalfword(L, 1);
    return 0;
}

static int texlib_getinputstateline(lua_State *L)
{
    lua_pushinteger(L, input_file_state.line);
    return 1;
}

/*tex
    This is experimental and might change. In version 10 we hope to have the final version available.
    It actually took quite a bit of time to understand the implications of mixing lua prints in here.
    The current variant is (so far) the most robust (wrt crashes and side effects).
*/

// # define mode cur_list.mode_field

/*tex
    When we add save levels then we can get crashes when one flushed bad groups due to out of order
    flushing. So we play safe! But still we can have issues so best make sure you're in hmode.
*/

static int texlib_forcehmode(lua_State *L)
{
    if (abs(cur_list.mode) == vmode) {
        if (lua_type(L, 1) == LUA_TBOOLEAN) {
            tex_begin_paragraph(lua_toboolean(L, 1), force_par_begin);
        } else {
            tex_begin_paragraph(1, force_par_begin);
        }
    }
    return 0;
}

/* tex
    The first argument can be a number (of a token register), a macro name or the name of a token
    list. The second argument is optional and when true forces expansion inside a definition. The
    optional third argument can be used to force oing. The return value indicates an error: 0
    means no error, 1 means that a bad register number has been passed, a value of 2 indicated an
    unknown register or macro name, while 3 reports that the macro is not suitable for local
    control because it takes arguments.
*/

static int texlib_runlocal(lua_State *L)
{
 // int obeymode = lua_toboolean(L, 4);
    int obeymode = 1; /* always 1 */
    halfword tok = -1;
    int mac = 0 ;
    switch (lua_type(L, 1)) {
        case LUA_TFUNCTION:
            {
                /* todo: also a variant that calls an already registered function */
                int ref;
                halfword r, t;
                lua_pushvalue(L, 1);
                ref = luaL_ref(L, LUA_REGISTRYINDEX);
                r = tex_get_available_token(token_val(end_local_cmd, 0));
                t = tex_get_available_token(token_val(lua_local_call_cmd, ref));
                token_link(t) = r;
                tex_begin_inserted_list(t);
                if (lmt_token_state.luacstrings > 0) {
                    tex_lua_string_start();
                }
                if (tracing_nesting_par > 2) {
                    tex_local_control_message("entering token scanner via function");
                }
                tex_local_control(obeymode);
                luaL_unref(L, LUA_REGISTRYINDEX, ref);
                return 0;
            }
        case LUA_TNUMBER:
            {
                halfword k = lmt_checkhalfword(L, 1);
                if (k >= 0 && k <= 65535) {
                    tok = toks_register(k);
                    goto TOK;
                } else {
                    tex_local_control_message("invalid token register number");
                    return 0;
                }
            }
        case LUA_TSTRING:
            {
                size_t lname = 0;
                const char *name = lua_tolstring(L, 1, &lname);
                int cs = tex_string_locate(name, lname, 0);
                int cmd = eq_type(cs);
                if (cmd < call_cmd) { // is_call_cmd
                    // todo: use the better register helpers and range checkers
                    switch (cmd) {
                        case register_toks_cmd:
                            tok = toks_register(register_toks_number(eq_value(cs)));
                            goto TOK;
                        case undefined_cs_cmd:
                            tex_local_control_message("undefined macro or token register");
                            return 0;
                        default:
                            /* like cs == case undefined_control_sequence */
                            tex_local_control_message("invalid macro or token register");
                            return 0;
                    }
                } else {
                    halfword ref = eq_value(cs);
                    halfword head = token_link(ref);
                    if (head && get_token_parameters(ref)) {
                        tex_local_control_message("macro takes arguments and is ignored");
                        return 0;
                    } else {
                        tok = cs_token_flag + cs;
                        mac = 1 ;
                        goto TOK;
                    }
                }
            }
        case LUA_TUSERDATA:
            /* no checking yet */
            tok = token_info(lmt_token_code_from_lua(L, 1));
            mac = 1;
            goto TOK;
        default:
            return 0;
    }
  TOK:
    if (tok < 0) {
        /* nothing to do */
    } else if (lmt_input_state.scanner_status != scanner_is_defining || lua_toboolean(L, 2)) {
        // todo: make list
        int grouped = lua_toboolean(L, 3);
        if (grouped) {
            tex_begin_inserted_list(tex_get_available_token(token_val(right_brace_cmd, 0)));
        }
        tex_begin_inserted_list(tex_get_available_token(token_val(end_local_cmd, 0)));
        if (mac) {
            tex_begin_inserted_list(tex_get_available_token(tok));
        } else {
            tex_begin_token_list(tok, local_text);
        }
        if (grouped) {
            tex_begin_inserted_list(tex_get_available_token(token_val(left_brace_cmd, 0)));
        }
        /*tex hm, needed here? */
        if (lmt_token_state.luacstrings > 0) {
            tex_lua_string_start();
        }
        if (tracing_nesting_par > 2) {
            if (mac) {
                tex_local_control_message("entering token scanner via macro");
            } else {
                tex_local_control_message("entering token scanner via register");
            }
        }
        tex_local_control(obeymode);
    } else if (mac) {
        tex_back_input(tok);
    } else {
        halfword h = null;
        halfword t = null;
        halfword r = token_link(tok);
        while (r) {
            t = tex_store_new_token(t, token_info(r));
            if (! h) {
                h = t;
            }
            r = token_link(r);
        }
        tex_begin_inserted_list(h);
    }
    return 0;
}

static int texlib_quitlocal(lua_State *L)
{
    (void) L;
    if (tracing_nesting_par > 2) {
        tex_local_control_message("quitting token scanner");
    }
    tex_end_local_control();
    return 0;
}

/* todo: no tryagain and justincase here */

static int texlib_expandasvalue(lua_State *L) /* mostly like the mp one */
{
    int kind = lmt_tointeger(L, 1);
    halfword tail = null;
    halfword head = lmt_macro_to_tok(L, 2, &tail);
    if (head) {
        switch (kind) {
            case lua_value_none_code:
            case lua_value_dimension_code:
                {
                    halfword value = 0;
                    halfword space = tex_get_available_token(space_token);
                    halfword relax = tex_get_available_token(deep_frozen_relax_token);
                    token_link(tail) = space;
                    token_link(space) = relax;
                    tex_begin_inserted_list(head);
                    lmt_error_state.intercept = 1;
                    lmt_error_state.last_intercept = 0;
                    value = tex_scan_dimen(0, 0, 0, 0, NULL);
                    lmt_error_state.intercept = 0;
                    while (cur_tok != deep_frozen_relax_token) {
                        tex_get_token();
                    }
                    if (! lmt_error_state.last_intercept) {
                        lua_pushinteger(L, value);
                        break;
                    } else if (kind == lua_value_none_code) {
                        head = lmt_macro_to_tok(L, 2, &tail);
                        goto TRYAGAIN;
                    } else {
                        head = lmt_macro_to_tok(L, 2, &tail);
                        goto JUSTINCASE;
                    }
                }
            case lua_value_integer_code:
            case lua_value_cardinal_code:
            case lua_value_boolean_code:
              TRYAGAIN:
                {
                    halfword value = 0;
                    halfword space = tex_get_available_token(space_token);
                    halfword relax = tex_get_available_token(deep_frozen_relax_token);
                    token_link(tail) = space;
                    token_link(space) = relax;
                    tex_begin_inserted_list(head);
                    lmt_error_state.intercept = 1;
                    lmt_error_state.last_intercept = 0;
                    value = tex_scan_int(0, NULL);
                    lmt_error_state.intercept = 0;
                    while (cur_tok != deep_frozen_relax_token) {
                        tex_get_token();
                    }
                    if (lmt_error_state.last_intercept) {
                        head = lmt_macro_to_tok(L, 2, &tail);
                        goto JUSTINCASE;
                    } else if (kind == lua_value_boolean_code) {
                        lua_pushboolean(L, value);
                        break;
                    } else {
                        lua_pushinteger(L, value);
                        break;
                    }
                }
            default:
              JUSTINCASE:
                {
                    int len = 0;
                    const char *str = (const char *) lmt_get_expansion(head, &len);
                    lua_pushlstring(L, str, str ? len : 0); /* len includes \0 */
                    break;
                }
        }
        return 1;
    } else {
        return 0;
    }
}

/* string, expand-in-def, group */

static int texlib_runstring(lua_State *L)
{
    int top = lua_gettop(L);
    if (top > 0) {
        size_t lstr = 0;
        const char *str = NULL;
        int slot = 1;
        halfword ct = lua_type(L, slot) == LUA_TNUMBER ? lmt_tohalfword(L, slot++) : cat_code_table_par;
        if (! tex_valid_catcode_table(ct)) {
            ct = cat_code_table_par;
        }
        str = lua_tolstring(L, slot++, &lstr);
        if (lstr > 0) {
            int obeymode = 1; /* always 1 */
            int expand =  lua_toboolean(L, slot++);
            int grouped = lua_toboolean(L, slot++);
            int ignore = lua_toboolean(L, slot++);
            halfword h = get_reference_token();
            halfword t = h;
            if (grouped) {
             // t = tex_store_new_token(a, left_brace_token + '{');
                t = tex_store_new_token(t, token_val(right_brace_cmd, 0));
            }
            /*tex Options: 1=create (will trigger an error), 2=ignore. */
            tex_parse_str_to_tok(h, &t, ct, str, lstr, ignore ? 2 : 1);
            if (grouped) {
             // t = tex_store_new_token(a, left_brace_token + '}');
                t = tex_store_new_token(t, token_val(left_brace_cmd, 0));
            }
            if (lmt_input_state.scanner_status != scanner_is_defining || expand) {
             // t = tex_store_new_token(t, token_val(end_local_cmd, 0));
                tex_begin_inserted_list(tex_get_available_token(token_val(end_local_cmd, 0)));
                tex_begin_token_list(h, local_text);
                if (lmt_token_state.luacstrings > 0) {
                    tex_lua_string_start();
                }
                if (tracing_nesting_par > 2) {
                    tex_local_control_message("entering token scanner via register");
                }
                tex_local_control(obeymode);
            } else {
                tex_begin_inserted_list(h);
            }
        }
    }
    return 0;
}

/* new, can go into luatex too */

static int texlib_getmathdir(lua_State *L)
{
    lua_pushinteger(L, math_direction_par);
    return 1;
}

static int texlib_setmathdir(lua_State *L)
{
    tex_set_math_dir(lmt_tohalfword(L, 1));
    return 0;
}

static int texlib_getpardir(lua_State *L)
{
    lua_pushinteger(L, par_direction_par);
    return 1;
}

static int texlib_setpardir(lua_State *L)
{
    tex_set_par_dir(lmt_tohalfword(L, 1));
    return 0;
}

static int texlib_gettextdir(lua_State *L)
{
    lua_pushinteger(L, text_direction_par);
    return 1;
}

static int texlib_settextdir(lua_State *L)
{
    tex_set_text_dir(lmt_tohalfword(L, 1));
    return 0;
}

/* Getting the line direction makes no sense, it's just the text direction. */

static int texlib_setlinedir(lua_State *L)
{
    tex_set_line_dir(lmt_tohalfword(L, 1));
    return 0;
}

static int texlib_getboxdir(lua_State *L)
{
    int index = lmt_tointeger(L, 1);
    if (index >= 0 && index <= max_box_register_index) {
        if (box_register(index)) {
            lua_pushinteger(L, box_dir(box_register(index)));
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        texlib_aux_show_box_index_error(L);
    }
    return 0;
}

static int texlib_setboxdir(lua_State *L)
{
    int index = lmt_tointeger(L, 1);
    if (index >= 0 && index <= max_box_register_index) {
        tex_set_box_dir(index, lmt_tosingleword(L, 2));
    } else {
        texlib_aux_show_box_index_error(L);
    }
    return 0;
}

static int texlib_gethelptext(lua_State *L)
{
    if (lmt_error_state.help_text) {
        lua_pushstring(L, lmt_error_state.help_text);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int texlib_setinteraction(lua_State *L)
{
    if (lua_type(L,1) == LUA_TNUMBER) {
        int i = lmt_tointeger(L, 1);
        if (i >= 0 && i <= 3) {
            lmt_error_state.interaction = i;
        }
    }
    return 0;
}

static int texlib_getinteraction(lua_State *L)
{
    lua_pushinteger(L, lmt_error_state.interaction);
    return 1;
}

static int texlib_setglyphdata(lua_State *L)
{
    update_tex_glyph_data(0, lmt_opthalfword(L, 1, unused_attribute_value));
    return 0;
}

static int texlib_getglyphdata(lua_State *L)
{
    lua_pushinteger(L, glyph_data_par);
    return 1;
}

static int texlib_setglyphstate(lua_State *L)
{
    update_tex_glyph_state(0, lmt_opthalfword(L, 1, unused_state_value));
    return 0;
}

static int texlib_getglyphstate(lua_State *L)
{
    lua_pushinteger(L, glyph_state_par);
    return 1;
}

static int texlib_setglyphscript(lua_State *L)
{
    update_tex_glyph_script(0, lmt_opthalfword(L, 1, unused_script_value));
    return 0;
}

static int texlib_getglyphscript(lua_State *L)
{
    lua_pushinteger(L, glyph_script_par);
    return 1;
}

static int texlib_getglyphscales(lua_State *L)
{
    lua_pushinteger(L, glyph_scale_par);
    lua_pushinteger(L, glyph_x_scale_par);
    lua_pushinteger(L, glyph_y_scale_par);
    lua_pushinteger(L, glyph_data_par);
    return 4;
}

static int texlib_fatalerror(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    tex_fatal_error(s);
    return 1;
}

static int texlib_lastnodetype(lua_State *L)
{
    halfword tail = cur_list.tail;
    int t = -1;
    int s = -1;
    if (tail) {
        halfword mode = cur_list.mode;
        if (mode != nomode && tail != contribute_head && node_type(tail) != glyph_node) {
            t = node_type(tail);
            s = node_subtype(tail);
        } else if (mode == vmode && tail == cur_list.head) {
            t = lmt_page_builder_state.last_node_type;
            s = lmt_page_builder_state.last_node_subtype;
        } else if (mode == nomode || tail == cur_list.head) {
            /* already -1 */
        } else {
            t = node_type(tail);
            s = node_subtype(tail);
        }
    }
    if (t >= 0) {
        lua_pushinteger(L, t);
        lua_pushinteger(L, s);
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

/* we can have all defs here */

static int texlib_chardef(lua_State *L)
{
    size_t l;
    const char *s = lua_tolstring(L, 1, &l);
    if (s) {
        int cs = tex_string_locate(s, l, 1);
        int flags = 0;
        lmt_check_for_flags(L, 3, &flags, 1, 0);
        if (tex_define_permitted(cs, flags)) {
            int code = lmt_tointeger(L, 2);
            if (code >= 0 && code <= max_character_code) {
                tex_define(flags, cs, (quarterword) char_given_cmd, code);
            } else {
                tex_formatted_error("lua", "chardef only accepts codes in the range 0-%i", max_character_code);
            }
        }
    }
    return 0;
}

/* todo: same range checks as in texlib_setmathcode */

static int texlib_mathchardef(lua_State *L)
{
    size_t l;
    const char *s = lua_tolstring(L, 1, &l);
    if (s) {
        int cs = tex_string_locate(s, l, 1);
        int flags = 0;
        lmt_check_for_flags(L, 5, &flags, 1, 0);
        if (tex_define_permitted(cs, flags)) {
            mathcodeval m;
            mathdictval d;
            m.class_value = (short) lmt_tointeger(L, 2);
            m.family_value = (short) lmt_tointeger(L, 3);
            m.character_value = lmt_tointeger(L, 4);
            d.properties = lmt_optquarterword(L, 6, 0);
            d.group = lmt_optquarterword(L, 7, 0);
            d.index = lmt_optinteger(L, 8, 0);
            if (class_in_range(m.class_value) && family_in_range(m.family_value) && character_in_range(m.character_value)) {
                tex_define(flags, cs, mathspec_cmd, tex_new_math_dict_spec(d, m, umath_mathcode));
            } else {
                tex_normal_error("lua", "mathchardef needs proper class, family and character codes");
            }
        } else { 
            /* maybe a message */
        }
    }
    return 0;
}

static int texlib_setintegervalue(lua_State *L)
{
    size_t l;
    const char *s = lua_tolstring(L, 1, &l);
    if (s) {
        int cs = tex_string_locate(s, l, 1);
        int flags = 0;
        lmt_check_for_flags(L, 3, &flags, 1, 0);
        if (tex_define_permitted(cs, flags)) {
            int value = lmt_optroundnumber(L, 2, 0);
            if (value >= min_integer && value <= max_integer) {
                tex_define(flags, cs, (quarterword) integer_cmd, value);
            } else {
                tex_formatted_error("lua", "integer only accepts values in the range %i-%i", min_integer, max_integer);
            }
        }
    }
    return 0;
}

static int texlib_setdimensionvalue(lua_State *L)
{
    size_t l;
    const char *s = lua_tolstring(L, 1, &l);
    if (s) {
        int cs = tex_string_locate(s, l, 1);
        int flags = 0;
        lmt_check_for_flags(L, 3, &flags, 1, 0);
        if (tex_define_permitted(cs, flags)) {
            int value = lmt_optroundnumber(L, 2, 0);
            if (value >= min_dimen && value <= max_dimen) {
                tex_define(flags, cs, (quarterword) dimension_cmd, value);
            } else {
                tex_formatted_error("lua", "dimension only accepts values in the range %i-%i", min_dimen, max_dimen);
            }
        }
    }
    return 0;
}

// static int texlib_setgluespecvalue(lua_State *L)
// {
//     return 0;
// }

static int texlib_aux_getvalue(lua_State *L, halfword level, halfword cs)
{
    halfword chr = eq_value(cs);
    if (chr && ! get_token_parameters(chr)) {
        halfword value = 0;
        tex_begin_inserted_list(tex_get_available_token(cs_token_flag + cs));
        if (tex_scan_tex_value(level, &value)) {
            lua_pushinteger(L, value);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int texlib_getintegervalue(lua_State *L) /* todo, now has duplicate in tokenlib */
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t l;
        const char *s = lua_tolstring(L, 1, &l);
        if (l > 0) {
            int cs = tex_string_locate(s, l, 0);
            switch (eq_type(cs)) {
                case integer_cmd:
                    lua_pushinteger(L, eq_value(cs));
                    return 1;
                case call_cmd:
                case protected_call_cmd:
                case semi_protected_call_cmd:
                    return texlib_aux_getvalue(L, int_val_level, cs);
                default:
                    /* twice a lookup but fast enough for now */
                    return texlib_getcount(L);
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int texlib_getdimensionvalue(lua_State *L) /* todo, now has duplicate in tokenlib */
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t l;
        const char *s = lua_tolstring(L, 1, &l);
        if (l > 0) {
            int cs = tex_string_locate(s, l, 0);
            switch (eq_type(cs)) {
                case dimension_cmd:
                    lua_pushinteger(L, eq_value(cs));
                    return 1;
                case call_cmd:
                case protected_call_cmd:
                case semi_protected_call_cmd:
                    return texlib_aux_getvalue(L, dimen_val_level, cs);
                default:
                    /* twice a lookup but fast enough for now */
                    return texlib_getdimen(L);
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

// static int texlib_getgluespecvalue(lua_State *L) /* todo, now has duplicate in tokenlib */
// {
//     return 1;
// }

/*tex
    Negative values are internal and inline. At some point I might do this as with modes and tokens
    although we don't have lookups here.

    In these list we don't really need the predefined keys. 
*/

static int texlib_getmodevalues(lua_State *L)
{
    lua_createtable(L, 4, 1);
    lua_push_key_at_index(L, unset,      nomode);
    lua_push_key_at_index(L, vertical,   vmode);
    lua_push_key_at_index(L, horizontal, hmode);
    lua_push_key_at_index(L, math,       mmode);
    return 1;
}

static int texlib_getmode(lua_State *L)
{
    lua_pushinteger(L, abs(cur_list.mode));
    return 1;
}

static int texlib_getrunstatevalues(lua_State *L)
{
    lua_createtable(L, 2, 1);
    lua_set_string_by_index(L, initializing_state, "initializing");
    lua_set_string_by_index(L, updating_state,     "updating");
    lua_set_string_by_index(L, production_state,   "production");
    return 1;
}

static int texlib_setrunstate(lua_State *L)
{
    int state = lmt_tointeger(L, 1);
    if (state == updating_state || state == production_state) {
        lmt_main_state.run_state = state;
    }
    return 0;
}

static int texlib_gethyphenationvalues(lua_State *L)
{
    lua_createtable(L, 2, 17);
    lua_push_key_at_index(L, normal,            normal_hyphenation_mode);
    lua_push_key_at_index(L, automatic,         automatic_hyphenation_mode);
    lua_push_key_at_index(L, explicit,          explicit_hyphenation_mode);
    lua_push_key_at_index(L, syllable,          syllable_hyphenation_mode);
    lua_push_key_at_index(L, uppercase,         uppercase_hyphenation_mode);
    lua_push_key_at_index(L, compound,          compound_hyphenation_mode);
    lua_push_key_at_index(L, strictstart,       strict_start_hyphenation_mode);
    lua_push_key_at_index(L, strictend,         strict_end_hyphenation_mode);
    lua_push_key_at_index(L, automaticpenalty,  automatic_penalty_hyphenation_mode);
    lua_push_key_at_index(L, explicitpenalty,   explicit_penalty_hyphenation_mode);
    lua_push_key_at_index(L, permitglue,        permit_glue_hyphenation_mode);
    lua_push_key_at_index(L, permitall,         permit_all_hyphenation_mode);
    lua_push_key_at_index(L, permitmathreplace, permit_math_replace_hyphenation_mode);
    lua_push_key_at_index(L, forcecheck,        force_check_hyphenation_mode);
    lua_push_key_at_index(L, lazyligatures,     lazy_ligatures_hyphenation_mode);
    lua_push_key_at_index(L, forcehandler,      force_handler_hyphenation_mode);
    lua_push_key_at_index(L, feedbackcompound,  feedback_compound_hyphenation_mode);
    lua_push_key_at_index(L, ignorebounds,      ignore_bounds_hyphenation_mode);
    lua_push_key_at_index(L, collapse,          collapse_hyphenation_mode);
    return 1;
}

static int texlib_getglyphoptionvalues(lua_State *L)
{
    lua_createtable(L, 3, 7);
    lua_set_string_by_index(L, glyph_option_normal_glyph,         "normal");
    lua_set_string_by_index(L, glyph_option_no_left_ligature,     "noleftligature");
    lua_set_string_by_index(L, glyph_option_no_right_ligature,    "norightligature");
    lua_set_string_by_index(L, glyph_option_no_left_kern,         "noleftkern");
    lua_set_string_by_index(L, glyph_option_no_right_kern,        "norightkern");
    lua_set_string_by_index(L, glyph_option_no_expansion,         "noexpansion");
    lua_set_string_by_index(L, glyph_option_no_protrusion,        "noprotrusion");
    lua_set_string_by_index(L, glyph_option_no_italic_correction, "noitaliccorrection");
    lua_set_string_by_index(L, glyph_option_math_discretionary,   "mathdiscretionary");
    lua_set_string_by_index(L, glyph_option_math_italics_too,     "mathsitalicstoo");
    return 1;
}

static int texlib_getnoadoptionvalues(lua_State *L)
{
    lua_createtable(L, 2, 32);
    lua_push_key_at_index(L, axis,                  noad_option_axis);
    lua_push_key_at_index(L, noaxis,                noad_option_no_axis);
    lua_push_key_at_index(L, exact,                 noad_option_exact);
    lua_push_key_at_index(L, left,                  noad_option_left);
    lua_push_key_at_index(L, middle,                noad_option_middle);
    lua_push_key_at_index(L, right,                 noad_option_right);
    lua_push_key_at_index(L, adapttoleftsize,       noad_option_adapt_to_left_size);
    lua_push_key_at_index(L, adapttorightsize,      noad_option_adapt_to_right_size);
    lua_push_key_at_index(L, nosubscript,           noad_option_no_sub_script);
    lua_push_key_at_index(L, nosuperscript,         noad_option_no_super_script);
    lua_push_key_at_index(L, nosubprescript,        noad_option_no_sub_pre_script);
    lua_push_key_at_index(L, nosuperprescript,      noad_option_no_super_pre_script);
    lua_push_key_at_index(L, noscript,              noad_option_no_script);
    lua_push_key_at_index(L, nooverflow,            noad_option_no_overflow);
    lua_push_key_at_index(L, void,                  noad_option_void);
    lua_push_key_at_index(L, phantom,               noad_option_phantom);
    lua_push_key_at_index(L, openupheight,          noad_option_openup_height);
    lua_push_key_at_index(L, openupdepth,           noad_option_openup_depth);
    lua_push_key_at_index(L, limits,                noad_option_limits);
    lua_push_key_at_index(L, nolimits,              noad_option_no_limits);
    lua_push_key_at_index(L, preferfontthickness,   noad_option_prefer_font_thickness);
    lua_push_key_at_index(L, noruling,              noad_option_no_ruling);
    lua_push_key_at_index(L, shiftedsubscript,      noad_option_shifted_sub_script);
    lua_push_key_at_index(L, shiftedsuperscript,    noad_option_shifted_super_script);
    lua_push_key_at_index(L, shiftedsubprescript,   noad_option_shifted_sub_pre_script);
    lua_push_key_at_index(L, shiftedsuperprescript, noad_option_shifted_super_pre_script);
    lua_push_key_at_index(L, unpacklist,            noad_option_unpack_list);
    lua_push_key_at_index(L, nocheck,               noad_option_no_check);
    lua_push_key_at_index(L, auto,                  noad_option_auto);
    lua_push_key_at_index(L, unrolllist,            noad_option_unroll_list);
    lua_push_key_at_index(L, followedbyspace,       noad_option_followed_by_space);
    lua_push_key_at_index(L, proportional,          noad_option_proportional);
    return 1;
}

static int texlib_getdiscoptionvalues(lua_State *L)
{
    lua_createtable(L, 2, 1);
    lua_set_string_by_index(L, disc_option_normal_word, "normalword");
    lua_set_string_by_index(L, disc_option_pre_word,    "preword");
    lua_set_string_by_index(L, disc_option_post_word,   "postword");
    return 1;
}

static int texlib_getlistanchorvalues(lua_State *L)
{
    lua_createtable(L, 14, 0);
    lua_set_string_by_index(L, left_origin_anchor,    "leftorigin");
    lua_set_string_by_index(L, left_height_anchor,    "leftheight");
    lua_set_string_by_index(L, left_depth_anchor,     "leftdepth");
    lua_set_string_by_index(L, right_origin_anchor,   "rightorigin");
    lua_set_string_by_index(L, right_height_anchor,   "rightheight");
    lua_set_string_by_index(L, right_depth_anchor,    "rightdepth");
    lua_set_string_by_index(L, center_origin_anchor,  "centerorigin");
    lua_set_string_by_index(L, center_height_anchor,  "centerheight");
    lua_set_string_by_index(L, center_depth_anchor,   "centerdepth");
    lua_set_string_by_index(L, halfway_total_anchor,  "halfwaytotal");
    lua_set_string_by_index(L, halfway_height_anchor, "halfwayheight");
    lua_set_string_by_index(L, halfway_depth_anchor,  "halfwaydepth");
    lua_set_string_by_index(L, halfway_left_anchor,   "halfwayleft");
    lua_set_string_by_index(L, halfway_right_anchor,  "halfwayright");
    return 1;
}

static int texlib_getlistsignvalues(lua_State *L)
{
    lua_createtable(L, 0, 2);
    lua_set_string_by_index(L, negate_x_anchor, "negatex");
    lua_set_string_by_index(L, negate_y_anchor, "negatey");
    return 1;
}

static int texlib_getlistgeometryalues(lua_State *L)
{
    lua_createtable(L, 3, 0);
    lua_set_string_by_index(L, offset_geometry,      "offset");
    lua_set_string_by_index(L, orientation_geometry, "orientation");
    lua_set_string_by_index(L, anchor_geometry,      "anchor");
    return 1;
}

static int texlib_getautomigrationvalues(lua_State *L)
{
    lua_createtable(L, 2, 3);
    lua_push_key_at_index(L, mark,   auto_migrate_mark);
    lua_push_key_at_index(L, insert, auto_migrate_insert);
    lua_push_key_at_index(L, adjust, auto_migrate_adjust);
    lua_push_key_at_index(L, pre,    auto_migrate_pre);
    lua_push_key_at_index(L, post,   auto_migrate_post);
    return 1;
}

static int texlib_getflagvalues(lua_State *L)
{
    lua_createtable(L, 2, 15);
    lua_push_key_at_index(L, frozen,      frozen_flag_bit);
    lua_push_key_at_index(L, permanent,   permanent_flag_bit);
    lua_push_key_at_index(L, immutable,   immutable_flag_bit);
    lua_push_key_at_index(L, primitive,   primitive_flag_bit);
    lua_push_key_at_index(L, mutable,     mutable_flag_bit);
    lua_push_key_at_index(L, noaligned,   noaligned_flag_bit);
    lua_push_key_at_index(L, instance,    instance_flag_bit);
    lua_push_key_at_index(L, untraced,    untraced_flag_bit);
    lua_push_key_at_index(L, global,      global_flag_bit);
    lua_push_key_at_index(L, tolerant,    tolerant_flag_bit);
    lua_push_key_at_index(L, protected,   protected_flag_bit);
    lua_push_key_at_index(L, overloaded,  overloaded_flag_bit);
    lua_push_key_at_index(L, aliased,     aliased_flag_bit);
    lua_push_key_at_index(L, immediate,   immediate_flag_bit);
    lua_push_key_at_index(L, conditional, conditional_flag_bit);
    lua_push_key_at_index(L, value,       value_flag_bit);
    return 1;
}

static int texlib_getspecialmathclassvalues(lua_State *L)
{
    lua_createtable(L, 0, 3);
    lua_set_string_by_index(L, math_all_class,   "all");
    lua_set_string_by_index(L, math_begin_class, "begin");
    lua_set_string_by_index(L, math_end_class,   "end");
    return 1;
}

static int texlib_getmathclassoptionvalues(lua_State *L)
{
    lua_createtable(L, 2, 19);
    lua_set_string_by_index(L, no_pre_slack_class_option,                 "nopreslack");
    lua_set_string_by_index(L, no_post_slack_class_option,                "nopostslack");
    lua_set_string_by_index(L, left_top_kern_class_option,                "lefttopkern");
    lua_set_string_by_index(L, right_top_kern_class_option,               "righttopkern");
    lua_set_string_by_index(L, left_bottom_kern_class_option,             "leftbottomkern");
    lua_set_string_by_index(L, right_bottom_kern_class_option,            "rightbottomkern");
    lua_set_string_by_index(L, look_ahead_for_end_class_option,           "lookaheadforend");
    lua_set_string_by_index(L, no_italic_correction_class_option,         "noitaliccorrection");
    lua_set_string_by_index(L, check_ligature_class_option,               "checkligature");
    lua_set_string_by_index(L, check_kern_pair_class_option,              "checkkernpair");
    lua_set_string_by_index(L, check_italic_correction_class_option,      "checkitaliccorrection");
    lua_set_string_by_index(L, flatten_class_option,                      "flatten");
    lua_set_string_by_index(L, omit_penalty_class_option,                 "omitpenalty");
 // lua_set_string_by_index(L, open_fence_class_option,                   "openfence"); 
 // lua_set_string_by_index(L, close_fence_class_option,                  "closefence");
 // lua_set_string_by_index(L, middle_fence_class_option,                 "middlefence");
    lua_set_string_by_index(L, unpack_class_option,                       "unpack");
    lua_set_string_by_index(L, raise_prime_option,                        "raiseprime");
    lua_set_string_by_index(L, carry_over_left_top_kern_class_option,     "carryoverlefttopkern");
    lua_set_string_by_index(L, carry_over_left_bottom_kern_class_option,  "carryoverleftbottomkern");
    lua_set_string_by_index(L, carry_over_right_top_kern_class_option,    "carryoverrighttopkern");
    lua_set_string_by_index(L, carry_over_right_bottom_kern_class_option, "carryoverrightbottomkern");
    lua_set_string_by_index(L, prefer_delimiter_dimensions_class_option,  "preferdelimiterdimensions");
    lua_set_string_by_index(L, auto_inject_class_option,                  "autoinject");
    lua_set_string_by_index(L, remove_italic_correction_class_option,     "removeitaliccorrection");
    lua_set_string_by_index(L, operator_italic_correction_class_option,   "operatoritaliccorrection");
    return 1;
}

static int texlib_getnormalizelinevalues(lua_State *L)
{
    lua_createtable(L, 2, 7);
    lua_set_string_by_index(L, normalize_line_mode,          "normalizeline");
    lua_set_string_by_index(L, parindent_skip_mode,          "parindentskip");
    lua_set_string_by_index(L, swap_hangindent_mode,         "swaphangindent");
    lua_set_string_by_index(L, swap_parshape_mode,           "swapparshape");
    lua_set_string_by_index(L, break_after_dir_mode,         "breakafterdir");
    lua_set_string_by_index(L, remove_margin_kerns_mode,     "removemarginkerns");
    lua_set_string_by_index(L, clip_width_mode,              "clipwidth");
    lua_set_string_by_index(L, flatten_discretionaries_mode, "flattendiscretionaries");
    lua_set_string_by_index(L, discard_zero_tab_skips_mode,  "discardzerotabskips");
    lua_set_string_by_index(L, flatten_h_leaders_mode,       "flattenhleaders");
    return 1;
}

static int texlib_getnormalizeparvalues(lua_State *L)
{
    lua_createtable(L, 2, 0);
    lua_set_string_by_index(L, normalize_par_mode,     "normalizepar");
    lua_set_string_by_index(L, flatten_v_leaders_mode, "flattenvleaders");
    return 1;
}

static int texlib_geterrorvalues(lua_State *L)
{
    lua_createtable(L, 7, 1);
    lua_set_string_by_index(L, normal_error_type,   "normal");
    lua_set_string_by_index(L, back_error_type,     "back");
    lua_set_string_by_index(L, insert_error_type,   "insert");
    lua_set_string_by_index(L, succumb_error_type,  "succumb");
    lua_set_string_by_index(L, eof_error_type,      "eof");
    lua_set_string_by_index(L, condition_error_type,"condition");
    lua_set_string_by_index(L, runaway_error_type,  "runaway");
    lua_set_string_by_index(L, warning_error_type,  "warning");
    return 1;
}

static int texlib_getiovalues(lua_State *L) /* for reporting so we keep spaces */
{
    lua_createtable(L, 5, 1);
    lua_set_string_by_index(L, io_initial_input_code,   "initial");
    lua_set_string_by_index(L, io_lua_input_code,       "lua print");
    lua_set_string_by_index(L, io_token_input_code,     "scan token");
    lua_set_string_by_index(L, io_token_eof_input_code, "scan token eof");
    lua_set_string_by_index(L, io_tex_macro_code,       "tex macro");
    lua_set_string_by_index(L, io_file_input_code,      "file");
    return 1;
}

static int texlib_getfrozenparvalues(lua_State *L)
{
    lua_createtable(L, 2, 20);
    lua_set_string_by_index(L, par_hsize_category,           "hsize");
    lua_set_string_by_index(L, par_skip_category,            "skip");
    lua_set_string_by_index(L, par_hang_category,            "hang");
    lua_set_string_by_index(L, par_indent_category,          "indent");
    lua_set_string_by_index(L, par_par_fill_category,        "parfill");
    lua_set_string_by_index(L, par_adjust_category,          "adjust");
    lua_set_string_by_index(L, par_protrude_category,        "protrude");
    lua_set_string_by_index(L, par_tolerance_category,       "tolerance");
    lua_set_string_by_index(L, par_stretch_category,         "stretch");
    lua_set_string_by_index(L, par_looseness_category,       "looseness");
    lua_set_string_by_index(L, par_last_line_category,       "lastline");
    lua_set_string_by_index(L, par_line_penalty_category,    "linepenalty");
    lua_set_string_by_index(L, par_club_penalty_category,    "clubpenalty");
    lua_set_string_by_index(L, par_widow_penalty_category,   "widowpenalty");
    lua_set_string_by_index(L, par_display_penalty_category, "displaypenalty");
    lua_set_string_by_index(L, par_broken_penalty_category,  "brokenpenalty");
    lua_set_string_by_index(L, par_demerits_category,        "demerits");
    lua_set_string_by_index(L, par_shape_category,           "shape");
    lua_set_string_by_index(L, par_line_category,            "line");
    lua_set_string_by_index(L, par_hyphenation_category,     "hyphenation");
    lua_set_string_by_index(L, par_shaping_penalty_category, "shapingpenalty");
    lua_set_string_by_index(L, par_orphan_penalty_category,  "orphanpenalty");
 /* lua_set_string_by_index(L, par_all_category,             "all"); */
    return 1;
}

static int texlib_getkerneloptionvalues(lua_State *L)
{
    lua_createtable(L, 2, 6);
    lua_set_string_by_index(L, math_kernel_no_italic_correction, "noitaliccorrection");
    lua_set_string_by_index(L, math_kernel_no_left_pair_kern,    "noleftpairkern");    
    lua_set_string_by_index(L, math_kernel_no_right_pair_kern,   "norightpairkern");   
    lua_set_string_by_index(L, math_kernel_auto_discretionary,   "autodiscretionary");
    lua_set_string_by_index(L, math_kernel_full_discretionary,   "fulldiscretionary");
    lua_set_string_by_index(L, math_kernel_ignored_character,    "ignoredcharacter");
    lua_set_string_by_index(L, math_kernel_is_large_operator,    "islargeoperator");
    lua_set_string_by_index(L, math_kernel_has_italic_shape,     "hasitalicshape");
    return 1;
}

static int texlib_getcharactertagvalues(lua_State *L)
{
    lua_createtable(L, 2, 12);
    lua_set_string_by_index(L, no_tag,          "normal");
    lua_set_string_by_index(L, ligatures_tag,   "ligatures");
    lua_set_string_by_index(L, kerns_tag,       "kerns");
    lua_set_string_by_index(L, list_tag,        "list");
    lua_set_string_by_index(L, callback_tag,    "callback");
    lua_set_string_by_index(L, extensible_tag,  "extensible");
    lua_set_string_by_index(L, horizontal_tag,  "horizontal");
    lua_set_string_by_index(L, vertical_tag,    "vertical");
    lua_set_string_by_index(L, extend_last_tag, "extendlast");
    lua_set_string_by_index(L, inner_left_tag,  "innerleft");
    lua_set_string_by_index(L, inner_right_tag, "innerright");
    lua_set_string_by_index(L, italic_tag,      "italic");
    lua_set_string_by_index(L, n_ary_tag,       "nary");
    lua_set_string_by_index(L, radical_tag,     "radical");
    lua_set_string_by_index(L, punctuation_tag, "punctuation");
    return 1;
}

static int texlib_getshapingpenaltiesvalues(lua_State *L)
{
    lua_createtable(L, 2, 2);
    lua_push_key_at_index(L, interlinepenalty, inter_line_penalty_shaping);
    lua_push_key_at_index(L, widowpenalty,     widow_penalty_shaping);
    lua_push_key_at_index(L, clubpenalty,      club_penalty_shaping);
    lua_push_key_at_index(L, brokenpenalty,    broken_penalty_shaping);
    return 1;
}

static int texlib_getprimitiveorigins(lua_State *L)
{
    lua_createtable(L, 2, 1);
    lua_push_key_at_index(L, tex,    tex_command);
    lua_push_key_at_index(L, etex,   etex_command);
    lua_push_key_at_index(L, luatex, luatex_command);
    return 1;
}

static int texlib_getlargestusedmark(lua_State* L)
{
    lua_pushinteger(L, lmt_mark_state.mark_data.ptr);
    return 1;
}

static int texlib_getoutputactive(lua_State* L)
{
    lua_pushboolean(L, lmt_page_builder_state.output_active);
    return 1;
}

/*tex Moved from lmtnodelib to here. */

int lmt_push_info_keys(lua_State *L, value_info *values)
{
    lua_newtable(L);
    for (int i = 0; values[i].name; i++) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, values[i].lua);
        lua_rawseti(L, -2, i);
    }
    return 1;
}

int lmt_push_info_values(lua_State *L, value_info *values)
{
    lua_newtable(L);
    for (int i = 0; values[i].name; i++) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, values[i].lua);
        lua_rawseti(L, -2, values[i].value);
    }
    return 1;
}

static int texlib_getgroupvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.group_code_values);
}

static int texlib_getmathparametervalues(lua_State *L)
{
    return lmt_push_info_keys(L, lmt_interface.math_parameter_values);
}

static int texlib_getmathstylevalues(lua_State* L)
{
    return lmt_push_info_values(L, lmt_interface.math_style_values);
}

static int texlib_getpacktypevalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.pack_type_values);
}

static int texlib_getparcontextvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.par_context_values);
}

static int texlib_getpagecontextvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.page_context_values);
}

static int texlib_getappendlinecontextvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.append_line_context_values);
}

static int texlib_getalignmentcontextvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.alignment_context_values);
}

static int texlib_getparbeginvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.par_begin_values);
}

static int texlib_getparmodevalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.par_mode_values);
}

static int texlib_getmathstylenamevalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.math_style_name_values);
}

static int texlib_getmathvariantvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.math_style_variant_values);
}

// static int texlib_getmathflattenvalues(lua_State *L)
// {
//     lua_createtable(L, 2, 3);
//     lua_set_string_by_index(L, math_flatten_ordinary,    "ord");
//     lua_set_string_by_index(L, math_flatten_binary,      "bin");
//     lua_set_string_by_index(L, math_flatten_relation,    "rel");
//     lua_set_string_by_index(L, math_flatten_punctuation, "punct");
//     lua_set_string_by_index(L, math_flatten_inner,       "inner");
//     return 1;
// }

static int texlib_getdiscstatevalues(lua_State *L)
{
    lua_createtable(L, 4, 1);
    lua_set_string_by_index(L, glyph_discpart_unset,   "unset");
    lua_set_string_by_index(L, glyph_discpart_pre,     "pre");
    lua_set_string_by_index(L, glyph_discpart_post,    "post");
    lua_set_string_by_index(L, glyph_discpart_replace, "replace");
    lua_set_string_by_index(L, glyph_discpart_always,  "always");
    return 1;
}

static int texlib_getmathcontrolvalues(lua_State *L)
{
    lua_createtable(L, 2, 23);
    lua_set_string_by_index(L, math_control_use_font_control,            "usefontcontrol");
    lua_set_string_by_index(L, math_control_over_rule,                   "overrule");
    lua_set_string_by_index(L, math_control_under_rule,                  "underrule");
    lua_set_string_by_index(L, math_control_radical_rule,                "radicalrule");
    lua_set_string_by_index(L, math_control_fraction_rule,               "fractionrule");
    lua_set_string_by_index(L, math_control_accent_skew_half,            "accentskewhalf");
    lua_set_string_by_index(L, math_control_accent_skew_apply,           "accentskewapply");
    lua_set_string_by_index(L, math_control_apply_ordinary_kern_pair,    "applyordinarykernpair");
    lua_set_string_by_index(L, math_control_apply_vertical_italic_kern,  "applyverticalitalickern");
    lua_set_string_by_index(L, math_control_apply_ordinary_italic_kern,  "applyordinaryitalickern");
    lua_set_string_by_index(L, math_control_apply_char_italic_kern,      "applycharitalickern");
    lua_set_string_by_index(L, math_control_rebox_char_italic_kern,      "reboxcharitalickern");
    lua_set_string_by_index(L, math_control_apply_boxed_italic_kern,     "applyboxeditalickern");
    lua_set_string_by_index(L, math_control_staircase_kern,              "staircasekern");
    lua_set_string_by_index(L, math_control_apply_text_italic_kern,      "applytextitalickern");
    lua_set_string_by_index(L, math_control_check_text_italic_kern,      "checktextitalickern");
    lua_set_string_by_index(L, math_control_check_space_italic_kern,     "checkspaceitalickern");
    lua_set_string_by_index(L, math_control_apply_script_italic_kern,    "applyscriptitalickern");
    lua_set_string_by_index(L, math_control_analyze_script_nucleus_char, "analyzescriptnucleuschar");
    lua_set_string_by_index(L, math_control_analyze_script_nucleus_list, "analyzescriptnucleuslist");
    lua_set_string_by_index(L, math_control_analyze_script_nucleus_box,  "analyzescriptnucleusbox");
    lua_set_string_by_index(L, math_control_accent_top_skew_with_offset, "accenttopskewwithoffset");
    lua_set_string_by_index(L, math_control_ignore_kern_dimensions,      "ignorekerndimensions");
    lua_set_string_by_index(L, math_control_ignore_flat_accents,         "ignoreflataccents");
    lua_set_string_by_index(L, math_control_extend_accents,              "extendaccents");
    return 1;
}

static int texlib_gettextcontrolvalues(lua_State *L)
{
    lua_createtable(L, 2, 2);
    lua_set_string_by_index(L, text_control_collapse_hyphens, "collapsehyphens");
    lua_set_string_by_index(L, text_control_base_ligaturing,  "baseligaturing");
    lua_set_string_by_index(L, text_control_base_kerning,     "basekerning");
    lua_set_string_by_index(L, text_control_none_protected,   "noneprotected");
    return 1;
}

/* relatively new */

static int texlib_getinsertdistance(lua_State *L)
{
    return texlib_aux_push_glue(L, tex_get_insert_distance(lmt_tointeger(L, 1)));
}

static int texlib_getinsertmultiplier(lua_State *L)
{
    lua_pushinteger(L, tex_get_insert_multiplier(lmt_tointeger(L, 1)));
    return 1;
}

static int texlib_getinsertlimit(lua_State *L)
{
    tex_set_insert_limit(lmt_tointeger(L, 1), lmt_opthalfword(L, 2, 0));
    return 0;
}

static int texlib_setinsertdistance(lua_State *L)
{
    tex_set_insert_distance(lmt_tointeger(L, 1), texlib_aux_make_glue(L, lua_gettop(L), 2));
    return 0;
}

static int texlib_setinsertmultiplier(lua_State *L)
{
    tex_set_insert_multiplier(lmt_tointeger(L, 1), lmt_tohalfword(L, 2));
    return 0;
}

static int texlib_setinsertlimit(lua_State *L)
{
    lua_pushinteger(L, tex_get_insert_limit(lmt_tointeger(L, 1)));
    return 1;
}

static int texlib_getinsertheight(lua_State *L)
{
    lua_pushinteger(L, tex_get_insert_height(lmt_tointeger(L, 1)));
    return 1;
}

static int texlib_getinsertdepth(lua_State *L)
{
    lua_pushinteger(L, tex_get_insert_depth(lmt_tointeger(L, 1)));
    return 1;
}

static int texlib_getinsertwidth(lua_State *L)
{
    lua_pushinteger(L, tex_get_insert_width(lmt_tointeger(L, 1)));
    return 1;
}

static int texlib_getinsertcontent(lua_State *L)
{
    halfword index = lmt_tointeger(L, 1);
    lmt_node_list_to_lua(L, tex_get_insert_content(index));
    tex_set_insert_content(index, null);
    return 1;
}

static int texlib_setinsertcontent(lua_State *L)
{
    halfword index = lmt_tointeger(L, 1);
    tex_flush_node(tex_get_insert_content(index));
    tex_set_insert_content(index, lmt_node_list_from_lua(L, 2));
    return 0;
}

static int texlib_getlocalbox(lua_State *L)
{
    int location = lmt_tointeger(L, 1);
    if (is_valid_local_box_code(location)) {
        lmt_node_list_to_lua(L, tex_get_local_boxes(location));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int texlib_setlocalbox(lua_State *L)
{
    int location = lmt_tointeger(L, 1);
    if (is_valid_local_box_code(location)) {
        tex_set_local_boxes(lmt_node_list_from_lua(L, 1), location);
    }
    return 0;
}

static int texlib_pushsavelevel(lua_State *L)
{
    (void) L;
    tex_new_save_level(lua_group);
    return 0;
}

static int texlib_popsavelevel(lua_State *L)
{
    (void) L;
 // tex_off_save();
    tex_unsave();
    return 0;
}

/*tex
    When testing all these math finetuning options we needed to typeset the box contents and
    instead of filtering from the log or piping the log to a file, this more ssd friendly
    feature was added. The first argument is a box (id) and the second an optional detail
    directive. This is (currently) the only case where we write to a \LUA\ buffer, but I
    might add variants for a macro and tokenlist at some point (less interesting).
*/

/* till here */

static const struct luaL_Reg texlib_function_list[] = {
    { "write",                      texlib_write                      },
    { "print",                      texlib_print                      },
    { "sprint",                     texlib_sprint                     },
    { "mprint",                     texlib_mprint                     },
    { "tprint",                     texlib_tprint                     },
    { "cprint",                     texlib_cprint                     },
    { "isprintable",                texlib_isprintable                },
    { "pushlocal",                  texlib_pushlocal                  },
    { "poplocal",                   texlib_poplocal                   },
    { "runlocal",                   texlib_runlocal                   },
    { "runstring",                  texlib_runstring                  },
    { "quitlocal",                  texlib_quitlocal                  },
    { "expandasvalue",              texlib_expandasvalue              }, /* experiment */
    { "error",                      texlib_error                      },
    { "set",                        texlib_set                        },
    { "get",                        texlib_get                        },
    { "getregisterindex",           texlib_get_register_index         },
    { "isdimen",                    texlib_isdimen                    },
    { "setdimen",                   texlib_setdimen                   },
    { "getdimen",                   texlib_getdimen                   },
    { "isskip",                     texlib_isskip                     },
    { "setskip",                    texlib_setskip                    },
    { "getskip",                    texlib_getskip                    },
    { "isglue",                     texlib_isglue                     },
    { "setglue",                    texlib_setglue                    },
    { "getglue",                    texlib_getglue                    },
    { "ismuskip",                   texlib_ismuskip                   },
    { "setmuskip",                  texlib_setmuskip                  },
    { "getmuskip",                  texlib_getmuskip                  },
    { "ismuglue",                   texlib_ismuglue                   },
    { "setmuglue",                  texlib_setmuglue                  },
    { "getmuglue",                  texlib_getmuglue                  },
    { "isattribute",                texlib_isattribute                },
    { "setattribute",               texlib_setattribute               },
    { "getattribute",               texlib_getattribute               },
    { "iscount",                    texlib_iscount                    },
    { "setcount",                   texlib_setcount                   },
    { "getcount",                   texlib_getcount                   },
    { "istoks",                     texlib_istoks                     },
    { "settoks",                    texlib_settoks                    },
    { "scantoks",                   texlib_scantoks                   },
    { "gettoks",                    texlib_gettoks                    },
    { "getmark",                    texlib_getmark                    },
    { "isbox",                      texlib_isbox                      },
    { "setbox",                     texlib_setbox                     },
    { "getbox",                     texlib_getbox                     },
    { "splitbox",                   texlib_splitbox                   },
    { "setlist",                    texlib_setlist                    },
    { "getlist",                    texlib_getlist                    },
    { "setnest",                    texlib_setnest                    }, /* only a message */
    { "getnest",                    texlib_getnest                    },
    { "setcatcode",                 texlib_setcatcode                 },
    { "getcatcode",                 texlib_getcatcode                 },
    { "setdelcode",                 texlib_setdelcode                 },
    { "getdelcode",                 texlib_getdelcode                 },
    { "getdelcodes",                texlib_getdelcodes                },
    { "sethccode",                  texlib_sethccode                  },
    { "gethccode",                  texlib_gethccode                  },
    { "sethmcode",                  texlib_sethmcode                  },
    { "gethmcode",                  texlib_gethmcode                  },
    { "setlccode",                  texlib_setlccode                  },
    { "getlccode",                  texlib_getlccode                  },
    { "setmathcode",                texlib_setmathcode                },
    { "getmathcode",                texlib_getmathcode                },
    { "getmathcodes",               texlib_getmathcodes               },
    { "setsfcode",                  texlib_setsfcode                  },
    { "getsfcode",                  texlib_getsfcode                  },
    { "setuccode",                  texlib_setuccode                  },
    { "getuccode",                  texlib_getuccode                  },
    { "round",                      texlib_round                      },
    { "scale",                      texlib_scale                      },
    { "sp",                         texlib_toscaled                   },
    { "toscaled",                   texlib_toscaled                   },
    { "tonumber",                   texlib_tonumber                   },
    { "fontname",                   texlib_getfontname                },
    { "fontidentifier",             texlib_getfontidentifier          },
    { "getfontoffamily",            texlib_getfontoffamily            },
    { "number",                     texlib_getnumber                  },
 // { "dimension",                  texlib_getdimension               },
    { "romannumeral",               texlib_getromannumeral            },
    { "definefont",                 texlib_definefont                 },
    { "hashtokens",                 texlib_hashtokens                 },
    { "primitives",                 texlib_primitives                 },
    { "extraprimitives",            texlib_extraprimitives            },
    { "enableprimitives",           texlib_enableprimitives           },
    { "shipout",                    texlib_shipout                    },
    { "badness",                    texlib_badness                    },
    { "setmath",                    texlib_setmath                    },
    { "getmath",                    texlib_getmath                    },
    { "linebreak",                  texlib_linebreak                  },
    { "preparelinebreak",           texlib_preparelinebreak           },
    { "resetparagraph",             texlib_resetparagraph             },
    { "showcontext",                texlib_showcontext                },
    { "triggerbuildpage",           texlib_triggerbuildpage           },
    { "gethelptext",                texlib_gethelptext                },
    { "getpagestate",               texlib_getpagestate               },
    { "getlocallevel",              texlib_getlocallevel              },
    { "setinputstatemode",          texlib_setinputstatemode          },
    { "getinputstatemode",          texlib_getinputstatemode          },
    { "setinputstatefile",          texlib_setinputstatefile          },
    { "getinputstatefile",          texlib_getinputstatefile          },
    { "forceinputstatefile",        texlib_forceinputstatefile        },
    { "forceinputstateline",        texlib_forceinputstateline        },
    { "setinputstateline",          texlib_setinputstateline          },
    { "getinputstateline",          texlib_getinputstateline          },
    { "forcehmode",                 texlib_forcehmode                 },
    { "gettextdir",                 texlib_gettextdir                 },
    { "settextdir",                 texlib_settextdir                 },
    { "getlinedir",                 texlib_gettextdir                 }, /* we're nice */
    { "setlinedir",                 texlib_setlinedir                 },
    { "getmathdir",                 texlib_getmathdir                 },
    { "setmathdir",                 texlib_setmathdir                 },
    { "getpardir",                  texlib_getpardir                  },
    { "setpardir",                  texlib_setpardir                  },
    { "getboxdir",                  texlib_getboxdir                  },
    { "setboxdir",                  texlib_setboxdir                  },
    { "getinteraction",             texlib_getinteraction             },
    { "setinteraction",             texlib_setinteraction             },
    { "getglyphdata",               texlib_getglyphdata               },
    { "setglyphdata",               texlib_setglyphdata               },
    { "getglyphstate",              texlib_getglyphstate              },
    { "setglyphstate",              texlib_setglyphstate              },
    { "getglyphscript",             texlib_getglyphscript             },
    { "setglyphscript",             texlib_setglyphscript             },
    { "getglyphscales",             texlib_getglyphscales             },
    { "fatalerror",                 texlib_fatalerror                 },
    { "lastnodetype",               texlib_lastnodetype               },
    { "chardef",                    texlib_chardef                    },
    { "mathchardef",                texlib_mathchardef                },
    { "integerdef",                 texlib_setintegervalue            },
    { "setintegervalue",            texlib_setintegervalue            },
    { "getintegervalue",            texlib_getintegervalue            },
    { "dimensiondef",               texlib_setdimensionvalue          },
    { "setdimensionvalue",          texlib_setdimensionvalue          },
    { "getdimensionvalue",          texlib_getdimensionvalue          },
    { "getmode",                    texlib_getmode                    },
    { "getmodevalues",              texlib_getmodevalues              },
    { "getrunstatevalues",          texlib_getrunstatevalues          },
    { "setrunstate",                texlib_setrunstate                },
    { "gethyphenationvalues",       texlib_gethyphenationvalues       },
    { "getglyphoptionvalues",       texlib_getglyphoptionvalues       },
    { "getnoadoptionvalues",        texlib_getnoadoptionvalues        },
    { "getdiscoptionvalues",        texlib_getdiscoptionvalues        },
    { "getlistanchorvalues",        texlib_getlistanchorvalues        },
    { "getlistsignvalues",          texlib_getlistsignvalues          },
    { "getlistgeometryvalues",      texlib_getlistgeometryalues       },
    { "getdiscstatevalues",         texlib_getdiscstatevalues         },
    { "getmathparametervalues",     texlib_getmathparametervalues     },
    { "getmathstylenamevalues",     texlib_getmathstylenamevalues     },
    { "getmathstylevalues",         texlib_getmathstylevalues         },
    { "getmathvariantvalues",       texlib_getmathvariantvalues       },
 /* {"getmathflattenvalues",        texlib_getmathflattenvalues       }, */
    { "getmathcontrolvalues",       texlib_getmathcontrolvalues       },
    { "gettextcontrolvalues",       texlib_gettextcontrolvalues       },
    { "getpacktypevalues",          texlib_getpacktypevalues          },
    { "getgroupvalues",             texlib_getgroupvalues             },
    { "getparcontextvalues",        texlib_getparcontextvalues        },
    { "getpagecontextvalues",       texlib_getpagecontextvalues       },
    { "getappendlinecontextvalues", texlib_getappendlinecontextvalues },
    { "getalignmentcontextvalues",  texlib_getalignmentcontextvalues  },
    { "getparbeginvalues",          texlib_getparbeginvalues          },
    { "getparmodevalues",           texlib_getparmodevalues           },
    { "getautomigrationvalues",     texlib_getautomigrationvalues     },
    { "getflagvalues",              texlib_getflagvalues              },
    { "getmathclassoptionvalues",   texlib_getmathclassoptionvalues   },
    { "getnormalizelinevalues",     texlib_getnormalizelinevalues     },
    { "getnormalizeparvalues",      texlib_getnormalizeparvalues      },
    { "geterrorvalues",             texlib_geterrorvalues             },
    { "getiovalues",                texlib_getiovalues                },
    { "getprimitiveorigins",        texlib_getprimitiveorigins        },
    { "getfrozenparvalues",         texlib_getfrozenparvalues         },
    { "getshapingpenaltiesvalues",  texlib_getshapingpenaltiesvalues  },
    { "getcharactertagvalues",      texlib_getcharactertagvalues      }, 
    { "getkerneloptionvalues",      texlib_getkerneloptionvalues      },
    { "getspecialmathclassvalues",  texlib_getspecialmathclassvalues  },
    { "getlargestusedmark",         texlib_getlargestusedmark         },
    { "getoutputactive",            texlib_getoutputactive            },
    /* experiment (metafun update) */
    { "shiftparshape",              texlib_shiftparshape              },
    { "snapshotpar",                texlib_snapshotpar                },
    { "getparstate",                texlib_getparstate                },
    /* */
    { "getinsertdistance",          texlib_getinsertdistance          },
    { "getinsertmultiplier",        texlib_getinsertmultiplier        },
    { "getinsertlimit",             texlib_getinsertlimit             },
    { "getinsertheight",            texlib_getinsertheight            },
    { "getinsertdepth",             texlib_getinsertdepth             },
    { "getinsertwidth",             texlib_getinsertwidth             },
    { "getinsertcontent",           texlib_getinsertcontent           },
    { "setinsertdistance",          texlib_setinsertdistance          },
    { "setinsertmultiplier",        texlib_setinsertmultiplier        },
    { "setinsertlimit",             texlib_setinsertlimit             },
    { "setinsertcontent",           texlib_setinsertcontent           },
    { "getlocalbox",                texlib_getlocalbox                },
    { "setlocalbox",                texlib_setlocalbox                },
    /* */
    { "pushsavelevel",              texlib_pushsavelevel              },
    { "popsavelevel",               texlib_popsavelevel               },
    /* */
    { NULL,                         NULL                              },
};

# define defineindexers(name) \
    static int texlib_index_##name   (lua_State *L) { lua_remove(L, 1);  return texlib_get##name(L); } \
    static int texlib_newindex_##name(lua_State *L) { lua_remove(L, 1);  return texlib_set##name(L); }

defineindexers(attribute)
defineindexers(skip)
defineindexers(glue)
defineindexers(muskip)
defineindexers(muglue)
defineindexers(dimen)
defineindexers(count)
defineindexers(toks)
defineindexers(box)
defineindexers(sfcode)
defineindexers(lccode)
defineindexers(uccode)
defineindexers(hccode)
defineindexers(hmcode)
defineindexers(catcode)
defineindexers(mathcode)
defineindexers(delcode)
defineindexers(list)
defineindexers(nest)

/*tex
    At some point the |__index| and |__newindex |below will go away so that we no longer get
    interferences when we extedn the |tex| table.
*/

int luaopen_tex(lua_State *L)
{
    texlib_aux_initialize();
    /* */
    lua_newtable(L);
    luaL_setfuncs(L, texlib_function_list, 0);
    lmt_make_table(L, "attribute", TEX_METATABLE_ATTRIBUTE, texlib_index_attribute, texlib_newindex_attribute);
    lmt_make_table(L, "skip",      TEX_METATABLE_SKIP,      texlib_index_skip,      texlib_newindex_skip);
    lmt_make_table(L, "glue",      TEX_METATABLE_GLUE,      texlib_index_glue,      texlib_newindex_glue);
    lmt_make_table(L, "muskip",    TEX_METATABLE_MUSKIP,    texlib_index_muskip,    texlib_newindex_muskip);
    lmt_make_table(L, "muglue",    TEX_METATABLE_MUGLUE,    texlib_index_muglue,    texlib_newindex_muglue);
    lmt_make_table(L, "dimen",     TEX_METATABLE_DIMEN,     texlib_index_dimen,     texlib_newindex_dimen);
    lmt_make_table(L, "count",     TEX_METATABLE_COUNT,     texlib_index_count,     texlib_newindex_count);
    lmt_make_table(L, "toks",      TEX_METATABLE_TOKS,      texlib_index_toks,      texlib_newindex_toks);
    lmt_make_table(L, "box",       TEX_METATABLE_BOX,       texlib_index_box,       texlib_newindex_box);
    lmt_make_table(L, "sfcode",    TEX_METATABLE_SFCODE,    texlib_index_sfcode,    texlib_newindex_sfcode);
    lmt_make_table(L, "lccode",    TEX_METATABLE_LCCODE,    texlib_index_lccode,    texlib_newindex_lccode);
    lmt_make_table(L, "uccode",    TEX_METATABLE_UCCODE,    texlib_index_uccode,    texlib_newindex_uccode);
    lmt_make_table(L, "hccode",    TEX_METATABLE_HCCODE,    texlib_index_hccode,    texlib_newindex_hccode);
    lmt_make_table(L, "hmcode",    TEX_METATABLE_HMCODE,    texlib_index_hmcode,    texlib_newindex_hmcode);
    lmt_make_table(L, "catcode",   TEX_METATABLE_CATCODE,   texlib_index_catcode,   texlib_newindex_catcode);
    lmt_make_table(L, "mathcode",  TEX_METATABLE_MATHCODE,  texlib_index_mathcode,  texlib_newindex_mathcode);
    lmt_make_table(L, "delcode",   TEX_METATABLE_DELCODE,   texlib_index_delcode,   texlib_newindex_delcode);
    lmt_make_table(L, "lists",     TEX_METATABLE_LISTS,     texlib_index_list,      texlib_newindex_list);
    lmt_make_table(L, "nest",      TEX_METATABLE_NEST,      texlib_index_nest,      texlib_newindex_nest);
    texlib_aux_init_nest_lib(L);
    /*tex make the meta entries and fetch it back */
    luaL_newmetatable(L, TEX_METATABLE_TEX);
    lua_pushstring(L, "__index");
    lua_pushcfunction(L, texlib_index);
    lua_settable(L, -3);
    lua_pushstring(L, "__newindex");
    lua_pushcfunction(L, texlib_newindex);
    lua_settable(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}
