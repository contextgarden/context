/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

int callback_set[total_callbacks] = { 0 };

/*tex

    See also callback_callback_type in luatexcallbackids.h: they must have the
    same order !

*/

static const char *const callbacknames[] = {
    "", /*tex empty on purpose */
    "find_write_file",
    "find_data_file",
    "find_format_file",
    "open_data_file",
    "read_data_file",
    "show_error_hook",
    "process_jobname",
    "start_run",
    "stop_run",
    "define_font",
    "pre_output_filter",
    "buildpage_filter",
    "hpack_filter",
    "vpack_filter",
    "hyphenate",
    "ligaturing",
    "kerning",
    "pre_linebreak_filter",
    "linebreak_filter",
    "post_linebreak_filter",
    "append_to_vlist_filter",
    "mlist_to_hlist",
    "pre_dump",
    "start_file",
    "stop_file",
    "show_error_message",
    "show_lua_error_hook",
    "show_warning_message",
    "hpack_quality",
    "vpack_quality",
    "insert_local_par",
    "contribute_filter",
    "build_page_insert",
    "wrapup_run",
    "new_graf",
    "make_extensible",
    "show_whatsit",
    "terminal_input",
    NULL
};

/*tex The global index of the callback metatable: */

static int callback_callbacks_id = 0;

int l_pack_type_index       [PACK_TYPE_SIZE] ;
int l_group_code_index      [GROUP_CODE_SIZE];
int l_local_par_index       [LOCAL_PAR_SIZE];
int l_math_style_name_index [MATH_STYLE_NAME_SIZE];

void get_lua_boolean(const char *table, const char *name, int * target)
{
    int stacktop = lua_gettop(Luas);
    luaL_checkstack(Luas, 2, "out of stack space");
    lua_getglobal(Luas, table);
    if (lua_istable(Luas, -1)) {
        int t;
        lua_getfield(Luas, -1, name);
        t = lua_type(Luas, -1);
        if (t == LUA_TBOOLEAN) {
            *target = (int) (lua_toboolean(Luas, -1));
        } else if (t == LUA_TNUMBER) {
            *target = (lua_tointeger(Luas, -1) == 0 ? 0 : 1);
        }
    }
    lua_settop(Luas, stacktop);
    return;
}

void get_lua_number(const char *table, const char *name, int *target)
{
    int stacktop = lua_gettop(Luas);
    luaL_checkstack(Luas, 2, "out of stack space");
    lua_getglobal(Luas, table);
    if (lua_istable(Luas, -1)) {
        lua_getfield(Luas, -1, name);
        if (lua_type(Luas, -1) == LUA_TNUMBER) {
            *target = (int) lua_roundnumber(Luas, -1); /* was lua_tointeger */
        }
    }
    lua_settop(Luas, stacktop);
    return;
}

void get_lua_string(const char *table, const char *name, char **target)
{
    int stacktop = lua_gettop(Luas);
    luaL_checkstack(Luas, 2, "out of stack space");
    lua_getglobal(Luas, table);
    if (lua_type(Luas, -1) == LUA_TTABLE) {
        lua_getfield(Luas, -1, name);
        if (lua_type(Luas, -1) == LUA_TSTRING) {
            *target = strdup(lua_tostring(Luas, -1));
        }
    }
    lua_settop(Luas, stacktop);
    return;
}

/*tex Till here. */

# define CALLBACK_BOOLEAN   'b'
# define CALLBACK_INTEGER   'd'
# define CALLBACK_LINE      'l'
# define CALLBACK_STRNUMBER 's'
# define CALLBACK_STRING    'S'
# define CALLBACK_RESULT    'R' /*tex a string but nil is also ok */
# define CALLBACK_CHARNUM   'c'
# define CALLBACK_LSTRING   'L'
# define CALLBACK_NODE      'N'
# define CALLBACK_DIR       'D'

/* most common: "->" "S->R" "S->" */

/* better use local variables */

static int do_run_callback(int special, const char *values, va_list vl, int top, int base)
{
    int ret;
    size_t len;
    int narg, nres;
    const char *s;
    lstring *lstr;
    char cs;
    int *bufloc;
    char *ss = NULL;
    int retval = 0;
    if (special == 2) {
        /*tex copy the enclosing table */
        luaL_checkstack(Luas, 1, "out of stack space");
        lua_pushvalue(Luas, -2);
    }
    ss = strchr(values, '>');
    luaL_checkstack(Luas, (int) (ss - values + 1), "out of stack space");
    ss = NULL;
    for (narg = 0; *values; narg++) {
        switch (*values++) {
            case CALLBACK_CHARNUM:
                /*tex an ascii char! */
                cs = (char) va_arg(vl, int);
                lua_pushlstring(Luas, &cs, 1);
                break;
            case CALLBACK_STRING:
                /*tex a \CCODE\ string */
                s = va_arg(vl, char *);
                lua_pushstring(Luas, s);
                break;
            case CALLBACK_LSTRING:
                /*tex a \LUA\ string */
                lstr = va_arg(vl, lstring *);
                lua_pushlstring(Luas, (const char *)lstr->s, lstr->l);
                break;
            case CALLBACK_INTEGER:
                /*tex int */
                lua_pushinteger(Luas, va_arg(vl, int));
                break;
            case CALLBACK_STRNUMBER:
                /*tex \TEX\ string */
                s = makeclstring(va_arg(vl, int), &len);
                lua_pushlstring(Luas, s, len);
                break;
            case CALLBACK_BOOLEAN:
                /*tex boolean */
                lua_pushboolean(Luas, va_arg(vl, int));
                break;
            case CALLBACK_LINE:
                /*tex a buffer section, with implied start */
                lua_pushlstring(Luas, (char *) (iobuffer + iofirst), (size_t) va_arg(vl, int));
                break;
            case CALLBACK_NODE:
                lua_nodelib_push_fast(Luas, va_arg(vl, int));
                break;
            case CALLBACK_DIR:
                lua_pushinteger(Luas, va_arg(vl, int));
                break;
            case '-':
                narg--;
                break;
            case '>':
                goto ENDARGS;
            default:
                ;
        }
    }
  ENDARGS:
    nres = (int) strlen(values);
    if (special == 1) {
        nres++;
    } else if (special == 2) {
        narg++;
    }
    {
        int i = lua_pcall(Luas, narg, nres, base);
        if (i != 0) {
            /*tex
                Can't be more precise here, could be called before TeX
                initialization is complete.
            */
            lua_remove(Luas, top+2);
            luatex_error(Luas, (i == LUA_ERRRUN ? 0 : 1));
            lua_settop(Luas, top);
            /*
            if (!fileio_state.log_opened) {
                fprintf(stderr, "error in callback: %s\n", lua_tostring(Luas, -1));
                error();
            } else {
                lua_gc(Luas, LUA_GCCOLLECT, 0);
                luatex_error(Luas, (i == LUA_ERRRUN ? 0 : 1));
            }
            */
            return 0;
        }
    }
    if (nres == 0) {
        return 1;
    }
    nres = -nres;
    while (*values) {
        int b;
        halfword p;
        int t = lua_type(Luas, nres);
        switch (*values++) {
            case CALLBACK_BOOLEAN:
                if (t == LUA_TNIL) {
                    b = 0;
                } else if (t != LUA_TBOOLEAN) {
                    fprintf(stderr, "callback should return a boolean, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                } else {
                    b = lua_toboolean(Luas, nres);
                }
                *va_arg(vl, int *) = (int) b;
                break;
            case CALLBACK_INTEGER:
                if (t != LUA_TNUMBER) {
                    fprintf(stderr, "callback should return a number, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                }
                b = lua_tointeger(Luas, nres);
                *va_arg(vl, int *) = b;
                break;
            case CALLBACK_LINE:
                /*tex A \TEX\ line ... happens frequently when we have a plug-in */
                if (t == LUA_TNIL) {
                    bufloc = 0;
                    /*tex We assume no more arguments! */
                    goto EXIT;
                } else if (t == LUA_TSTRING) {
                    s = lua_tolstring(Luas, nres, &len);
                    if (s == NULL) {    /* |len| can be zero */
                        bufloc = 0;
                    } else if (len == 0) {
                        bufloc = 0;
                    } else {
                        bufloc = va_arg(vl, int *);
                        ret = *bufloc;
                        check_buffer_overflow(ret + (int) len);
                        strncpy((char *) (iobuffer + ret), s, len);
                        *bufloc += (int) len;
                        /* while (len--) {  iobuffer[(*bufloc)++] = *s++; } */
                        while ((*bufloc) - 1 > ret && iobuffer[(*bufloc) - 1] == ' ')
                            (*bufloc)--;
                    }
                    /*tex We can assume no more arguments! */
                    /* goto EXIT; */
                } else {
                    fprintf(stderr, "callback should return a string, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                }
                break;
            case CALLBACK_STRNUMBER:
                /*tex A \TEX\ string */
                if (t != LUA_TSTRING) {
                    fprintf(stderr, "callback should return a string, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                }
                s = lua_tolstring(Luas, nres, &len);
                if (s == NULL) {
                    /*tex |len| can be zero */
                    *va_arg(vl, int *) = 0;
                } else {
                    *va_arg(vl, int *) = maketexlstring(s, len);
                }
                break;
            case CALLBACK_STRING:
                /*tex \CCODE\ string aka buffer */
                if (t != LUA_TSTRING) {
                    fprintf(stderr, "callback should return a string, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                }
                s = lua_tolstring(Luas, nres, &len);
                if (s == NULL) {
                    /*tex |len| can be zero */
                    *va_arg(vl, int *) = 0;
                } else {
                    ss = malloc((unsigned) (len + 1));
                    (void) memcpy(ss, s, (len + 1));
                    *va_arg(vl, char **) = ss;
                }
                break;
            case CALLBACK_RESULT:
                /*tex \CCODE\ string aka buffer */
                if (t == LUA_TNIL) {
                    *va_arg(vl, int *) = 0;
                } else if (t == LUA_TBOOLEAN) {
                    b = lua_toboolean(Luas, nres);
                    if (b == 0) {
                        *va_arg(vl, int *) = 0;
                    } else {
                        fprintf(stderr, "callback should return a string, false or nil, not: %s\n", lua_typename(Luas, t));
                        goto EXIT;
                    }
                } else if (t != LUA_TSTRING) {
                    fprintf(stderr, "callback should return a string, false or nil, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                } else {
                    s = lua_tolstring(Luas, nres, &len);
                    if (s == NULL) {
                        /*tex |len| can be zero */
                        *va_arg(vl, int *) = 0;
                    } else {
                        ss = malloc((unsigned) (len + 1));
                        (void) memcpy(ss, s, (len + 1));
                        *va_arg(vl, char **) = ss;
                    }
                }
                break;
            case CALLBACK_LSTRING:
                /*tex A \LUA\ string */
                if (t != LUA_TSTRING) {
                    fprintf(stderr, "callback should return a string, not: %s\n", lua_typename(Luas, t));
                    goto EXIT;
                }
                s = lua_tolstring(Luas, nres, &len);
                if (s == NULL) {
                    /*tex |len| can be zero */
                    *va_arg(vl, int *) = 0;
                } else {
                    lstring *lsret = malloc(sizeof(lstring));
                    lsret->s = malloc((unsigned) (len + 1));
                    (void) memcpy(lsret->s, s, (len + 1));
                    lsret->l = len;
                    *va_arg(vl, lstring **) = lsret;
                }
                break;
            case CALLBACK_NODE:
                if (t == LUA_TNIL) {
                    p = null;
                } else {
                    p = *check_isnode(Luas,nres);
                }
                *va_arg(vl, int *) = p;
                break;
            default:
                fprintf(stdout, "callback returned an invalid value type");
                goto EXIT;
        }
        nres++;
    }
    retval = 1;
  EXIT:
    return retval;
}

int run_saved_callback(int r, int name, const char *values, ...)
{
    va_list args;
    int ret = 0;
    int stacktop = lua_gettop(Luas);
    va_start(args, values);
    luaL_checkstack(Luas, 2, "out of stack space");
    lua_rawgeti(Luas, LUA_REGISTRYINDEX, r);
    lua_push_string_by_index(Luas,name);
    lua_pushcfunction(Luas, lua_traceback); /* goes before function */
    lua_rawget(Luas, -3);
    if (lua_isfunction(Luas, -2)) {
        lua_state.saved_callback_count++;
        ret = do_run_callback(2, values, args, stacktop, stacktop+2);
    }
    va_end(args);
    lua_settop(Luas, stacktop);
    return ret;
}

/* -1 is error, >= 0 is buffer length */

int run_saved_callback_line(int r, int firstpos)
{
    int ret = -1;
    int stacktop = lua_gettop(Luas);
    luaL_checkstack(Luas, 2, "out of stack space");
    lua_rawgeti(Luas, LUA_REGISTRYINDEX, r);
    lua_push_string_by_index(Luas,lua_key_index(reader));
    lua_rawget(Luas, -2);
    if (lua_isfunction(Luas, -1)) {
        lua_state.saved_callback_count++;
        lua_pushvalue(Luas, -2);
        ret = lua_pcall(Luas, 1, 1, 0);
        if (ret) {
            fprintf(stderr, "error in read line callback");
            exit(EXIT_FAILURE);
            return -1;
        }
        if (lua_type(Luas, -1) == LUA_TSTRING) {
            size_t len;
            const char *s = lua_tolstring(Luas, -1, &len);
            if (s == NULL || len == 0) {
                ret = 0;
            } else {
                ret = firstpos;
                check_buffer_overflow(ret + (int) len);
                strncpy((char *) (iobuffer + ret), s, len);
                ret += len;
                while (ret - 1 > firstpos && iobuffer[ret - 1] == ' ')
                    ret--;
            }
        } else {
            /* we're done */
            ret = -1;
        }
    } else {
        /* ignore other values */
    }
    lua_settop(Luas, stacktop);
    return ret;
}

int callback_okay(lua_State * L, int i)
{
    int top = lua_gettop(L);
    luaL_checkstack(L, 3, "out of stack space");
    lua_rawgeti(L, LUA_REGISTRYINDEX, callback_callbacks_id);
    lua_pushcfunction(Luas, lua_traceback); /* goes before function */
    lua_rawgeti(L, -2, i);
    if (lua_isfunction(L, -1)) {
        lua_state.callback_count++;
        return top;
    } else {
        lua_pop(L,3);
        return 0;
    }
}

void callback_error(lua_State * L, int top, int i)
{
    lua_remove(L, top+2);
    luatex_error(L, (i == LUA_ERRRUN ? 0 : 1));
    lua_settop(L, top);
}

int run_and_save_callback(int i, const char *values, ...)
{
    int top;
    if ((top = callback_okay(Luas, i))) {
        int ret = 0;
        va_list args;
        va_start(args, values);
        ret = do_run_callback(1, values, args, top, top+2);
        va_end(args);
        if (ret > 0) {
            ret = luaL_ref(Luas, LUA_REGISTRYINDEX);
        }
        lua_settop(Luas, top);
        return ret;
    } else {
        return 0;
    }
}

int run_callback(int i, const char *values, ...)
{
    int top;
    if ((top = callback_okay(Luas, i))) {
        int ret;
        va_list args;
        va_start(args, values);
        ret = do_run_callback(0, values, args, top, top+2);
        va_end(args);
        lua_settop(Luas, top);
        return ret;
    } else {
        return 0;
    }
}

void destroy_saved_callback(int i)
{
    luaL_unref(Luas, LUA_REGISTRYINDEX, i);
}

static int callback_register(lua_State * L)
{
    int t1 = lua_type(L,1);
    int t2 = lua_type(L,2);
    if (t1 != LUA_TSTRING) {
        lua_pushnil(L);
        lua_pushstring(L, "Invalid arguments to callback.register, first argument must be string.");
        return 2;
    } else if ((t2 != LUA_TFUNCTION) && (t2 != LUA_TNIL) && ((t2 != LUA_TBOOLEAN) && (lua_toboolean(L, 2) == 0))) {
        lua_pushnil(L);
        lua_pushstring(L, "Invalid arguments to callback.register.");
        return 2;
    } else {
        int cb;
        const char *s = lua_tostring(L, 1);
        for (cb = 0; cb < total_callbacks; cb++) {
            if (strcmp(callbacknames[cb], s) == 0)
                break;
        }
        if (cb == total_callbacks) {
            lua_pushnil(L);
            lua_pushstring(L, "No such callback exists.");
            return 2;
        } else {
            if (t2 == LUA_TFUNCTION) {
                callback_set[cb] = cb;
            } else if (t2 == LUA_TBOOLEAN) {
                callback_set[cb] = -1;
            } else {
                callback_set[cb] = 0;
            }
            luaL_checkstack(L, 2, "out of stack space");
            lua_rawgeti(L, LUA_REGISTRYINDEX, callback_callbacks_id);
            lua_pushvalue(L, 2); /*tex the function or nil */
            lua_rawseti(L, -2, cb);
            lua_rawseti(L, LUA_REGISTRYINDEX, callback_callbacks_id);
            lua_pushinteger(L, cb);
            return 1;
        }
    }
}

static int callback_find(lua_State * L)
{
    int cb;
    const char *s;
    if (lua_type(L, 1) != LUA_TSTRING) {
        lua_pushnil(L);
        lua_pushstring(L, "Invalid arguments to callback.find.");
        return 2;
    }
    s = lua_tostring(L, 1);
    for (cb = 0; cb < total_callbacks; cb++) {
        if (strcmp(callbacknames[cb], s) == 0)
            break;
    }
    if (cb == total_callbacks) {
        lua_pushnil(L);
        lua_pushstring(L, "No such callback exists.");
        return 2;
    }
    luaL_checkstack(L, 2, "out of stack space");
    lua_rawgeti(L, LUA_REGISTRYINDEX, callback_callbacks_id);
    lua_rawgeti(L, -1, cb);
    return 1;
}

static int callback_listf(lua_State * L)
{
    int i;
    luaL_checkstack(L, 3, "out of stack space");
    lua_newtable(L);
    for (i = 1; callbacknames[i]; i++) {
        lua_pushstring(L, callbacknames[i]);
        if (callback_defined(i)) {
            lua_pushboolean(L, 1);
        } else {
            lua_pushboolean(L, 0);
        }
        lua_rawset(L, -3);
    }
    return 1;
}

static const struct luaL_Reg callbacklib[] = {
    { "find",     callback_find },
    { "register", callback_register },
    { "list",     callback_listf },
    { NULL,       NULL }
};

int luaopen_callback(lua_State * L)
{
    lua_newtable(L);
    luaL_setfuncs(L, callbacklib, 0);
    lua_newtable(L);
    callback_callbacks_id = luaL_ref(L, LUA_REGISTRYINDEX);
    return 1;
}
