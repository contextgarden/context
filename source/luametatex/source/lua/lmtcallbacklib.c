/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    These are the supported callbacks (by name). This list must have the same size and order as the
    array in |luatexcallbackids.h|! We could have kept the names private here and maybe they will
    become that again. On the other hand we can now use them in reports.

*/

callback_state_info lmt_callback_state = {
    .metatable_id = 0,
    .padding      = 0,
    .values       = { 0 },
};

/* todo: use lua keywords instead */

static const char *callbacklib_names[total_callbacks] = {
    "", /*tex empty on purpose */
    "find_log_file",
    "find_format_file",
    "open_data_file",
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
    "glyph_run",
    "pre_linebreak_filter",
    "linebreak_filter",
    "post_linebreak_filter",
    "append_to_vlist_filter",
    "alignment_filter",
    "local_box_filter",
    "packed_vbox_filter",
    "mlist_to_hlist",
    "pre_dump",
    "start_file",
    "stop_file",
    "intercept_tex_error",
    "intercept_lua_error",
    "show_error_message",
    "show_warning_message",
    "hpack_quality",
    "vpack_quality",
    "insert_par",
    "append_line_filter",
    "build_page_insert",
 /* "fire_up_output", */
    "wrapup_run",
    "begin_paragraph",
    "paragraph_context",
 /* "get_math_char", */
    "math_rule",
    "make_extensible",
    "register_extensible",
    "show_whatsit",
    "get_attribute",
    "get_noad_class",
    "get_math_dictionary",
    "show_lua_call",
    "trace_memory",
    "handle_overload",
    "missing_character",
    "process_character",
};

/*tex

    This is the generic callback handler, inspired by the one described in the \LUA\ manual(s). It
    got adapted over time and can also handle some userdata arguments.

*/

static int callbacklib_aux_run(lua_State *L, int id, int special, const char *values, va_list vl, int top, int base)
{
    int narg = 0;
    int nres = 0;
    if (special == 2) {
        /*tex copy the enclosing table */
        lua_pushvalue(L, -2);
    }
    for (narg = 0; *values; narg++) {
        switch (*values++) {
            case callback_boolean_key:
                /*tex A boolean: */
                lua_pushboolean(L, va_arg(vl, int));
                break;
            case callback_charnum_key:
                /*tex A (8 bit) character: */
                {
                    char cs = (char) va_arg(vl, int);
                    lua_pushlstring(L, &cs, 1);
                }
                break;
            case callback_integer_key:
                /*tex An integer: */
                lua_pushinteger(L, va_arg(vl, int));
                break;
            case callback_line_key:
                /*tex A buffer section, with implied start: */
                lua_pushlstring(L, (char *) (lmt_fileio_state.io_buffer + lmt_fileio_state.io_first), (size_t) va_arg(vl, int));
                break;
            case callback_strnumber_key:
                /*tex A \TEX\ string (indicated by an index): */
                {
                    size_t len;
                    const char *s = tex_makeclstring(va_arg(vl, int), &len);
                    lua_pushlstring(L, s, len);
                }
                break;
            case callback_lstring_key:
                /*tex A \LUA\ string: */
                {
                    lstring *lstr = va_arg(vl, lstring *);
                    lua_pushlstring(L, (const char *) lstr->s, lstr->l);
                }
                break;
            case callback_node_key:
                /*tex A \TEX\ node: */
                lmt_push_node_fast(L, va_arg(vl, int));
                break;
            case callback_string_key:
                /*tex A \CCODE\ string: */
                lua_pushstring(L, va_arg(vl, char *));
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
        lmt_lua_state.saved_callback_count++;
        int i = lua_pcall(L, narg, nres, base);
        if (i) {
            /*tex
                We can't be more precise here as it could be called before \TEX\ initialization is
                complete.
            */
            lua_remove(L, top + 2);
            lmt_error(L, "run callback", id, (i == LUA_ERRRUN ? 0 : 1));
            lua_settop(L, top);
            return 0;
        }
    }
    if (nres == 0) {
        return 1;
    }
    nres = -nres;
    while (*values) {
        int t = lua_type(L, nres);
        switch (*values++) {
            case callback_boolean_key:
                switch (t) {
                    case LUA_TBOOLEAN:
                        *va_arg(vl, int *) = lua_toboolean(L, nres);
                        break;
                    case LUA_TNIL:
                        *va_arg(vl, int *) = 0;
                        break;
                    default:
                        return tex_formatted_error("callback", "boolean or nil expected, false or nil, not: %s\n", lua_typename(L, t));
                }
                break;
            /*
            case callback_charnum_key:
                break;
            */
            case callback_integer_key:
                switch (t) {
                    case LUA_TNUMBER:
                        *va_arg(vl, int *) = lmt_tointeger(L, nres);
                        break;
                    default:
                        return tex_formatted_error("callback", "number expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_line_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s && (len > 0)) {
                                int *bufloc = va_arg(vl, int *);
                                int ret = *bufloc;
                                if (tex_room_in_buffer(ret + (int) len)) {
                                    strncpy((char *) (lmt_fileio_state.io_buffer + ret), s, len);
                                    *bufloc += (int) len;
                                    /* while (len--) {  fileio_state.io_buffer[(*bufloc)++] = *s++; } */
                                    while ((*bufloc) - 1 > ret && lmt_fileio_state.io_buffer[(*bufloc) - 1] == ' ') {
                                        (*bufloc)--;
                                    }
                               } else {
                                    return 0;
                               }
                            }
                            /*tex We can assume no more arguments! */
                        }
                        break;
                    case LUA_TNIL:
                        /*tex We assume no more arguments! */
                        return 0;
                    default:
                        return tex_formatted_error("callback", "string or nil expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_strnumber_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s) {
                                *va_arg(vl, int *) = tex_maketexlstring(s, len);
                            } else {
                                /*tex |len| can be zero */
                                *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string expected, not: %s\n", lua_typename(L, t));
               }
                break;
            case callback_lstring_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s && len > 0) {
                                lstring *lsret = lmt_memory_malloc(sizeof(lstring));
                                if (lsret) {
                                    lsret->s = lmt_memory_malloc((unsigned) (len + 1));
                                    if (lsret->s) {
                                        (void) memcpy(lsret->s, s, (len + 1));
                                        lsret->l = len;
                                        *va_arg(vl, lstring **) = lsret;
                                    } else {
                                        *va_arg(vl, int *) = 0;
                                    }
                                } else {
                                    *va_arg(vl, int *) = 0;
                                }
                            } else {
                                /*tex |len| can be zero */
                                *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_node_key:
                switch (t) {
                    case LUA_TUSERDATA:
                        *va_arg(vl, int *) = lmt_check_isnode(L, nres);
                        break;
                    default:
                        *va_arg(vl, int *) = null;
                        break;
                }
                break;
            case callback_string_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s) {
                                char *ss = lmt_memory_malloc((unsigned) (len + 1));
                                if (ss) {
                                    memcpy(ss, s, (len + 1));
                                 }
                                *va_arg(vl, char **) = ss;
                            } else {
                                *va_arg(vl, char **) = NULL;
                             // *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_result_key:
                switch (t) {
                    case LUA_TNIL:
                        *va_arg(vl, int *) = 0;
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, nres) == 0) {
                            *va_arg(vl, int *) = 0;
                            break;
                        } else {
                            return tex_formatted_error("callback", "string, false or nil expected, not: %s\n", lua_typename(L, t));
                        }
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s) {
                                char *ss = lmt_memory_malloc((unsigned) (len + 1));
                                if (ss) {
                                    memcpy(ss, s, (len + 1));
                                    *va_arg(vl, char **) = ss;
                                } else {
                                   *va_arg(vl, char **) = NULL;
                                // *va_arg(vl, int *) = 0;
                                }
                            } else {
                                *va_arg(vl, char **) = NULL;
                             // *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string, false or nil expected, not: %s\n", lua_typename(L, t));
                }
                break;
            default:
                return tex_formatted_error("callback", "invalid value type returned\n");
        }
        nres++;
    }
    return 1;
}

/*tex
    Especially the \IO\ related callbacks are registered once, for instance when a file is opened,
    and (re)used later. These are dealt with here.
*/

int lmt_run_saved_callback_close(lua_State *L, int r)
{
    int ret = 0;
    int stacktop = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, r);
    lua_push_key(close);
    if (lua_rawget(L, -2) == LUA_TFUNCTION) {
        ret = lua_pcall(L, 0, 0, 0);
        if (ret) {
            return tex_formatted_error("lua", "error in close file callback") - 1;
        }
    }
    lua_settop(L, stacktop);
    return ret;
}

int lmt_run_saved_callback_line(lua_State *L, int r, int firstpos)
{
    int ret = -1; /* -1 is error, >= 0 is buffer length */
    int stacktop = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, r);
    lua_push_key(reader);
    if (lua_rawget(L, -2) == LUA_TFUNCTION) {
        lua_pushvalue(L, -2);
        lmt_lua_state.file_callback_count++;
        ret = lua_pcall(L, 1, 1, 0);
        if (ret) {
            ret = tex_formatted_error("lua", "error in read line callback") - 1;
        } else if (lua_type(L, -1) == LUA_TSTRING) {
            size_t len;
            const char *s = lua_tolstring(L, -1, &len);
            if (s && len > 0) {
                while (len >= 1 && s[len-1] == ' ') {
                    len--;
                }
                if (len > 0) {
                    if (tex_room_in_buffer(firstpos + (int) len)) {
                        strncpy((char *) (lmt_fileio_state.io_buffer + firstpos), s, len);
                        ret = firstpos + (int) len;
                    } else {
                        tex_overflow_error("buffer", (int) len);
                        ret = 0;
                    }
                } else {
                    ret = 0;
                }
            } else {
                ret = 0;
            }
        } else {
            ret = -1;
        }
    }
    lua_settop(L, stacktop);
    return ret;
}

/*tex

    Many callbacks have a specific handler, so they don't use the previously mentioned generic one.
    The next bunch of helpers checks for them being set and deals invoking them as well as reporting
    errors.

*/

int lmt_callback_okay(lua_State *L, int i, int *top)
{
    *top = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_callback_state.metatable_id);
    lua_pushcfunction(L, lmt_traceback); /* goes before function */
    if (lua_rawgeti(L, -2, i) == LUA_TFUNCTION) {
        lmt_lua_state.saved_callback_count++;
        return 1;
    } else {
        lua_pop(L, 3);
        return 0;
    }
}

void lmt_callback_error(lua_State *L, int top, int i)
{
    lua_remove(L, top + 2);
    lmt_error(L, "callback error", -1, (i == LUA_ERRRUN ? 0 : 1));
    lua_settop(L, top);
}

int lmt_run_and_save_callback(lua_State *L, int i, const char *values, ...)
{
    int top = 0;
    int ret = 0;
    if (lmt_callback_okay(L, i, &top)) {
        va_list args;
        va_start(args, values);
        ret = callbacklib_aux_run(L, i, 1, values, args, top, top + 2);
        va_end(args);
        if (ret > 0) {
            ret = lua_type(L, -1) == LUA_TTABLE ? luaL_ref(L, LUA_REGISTRYINDEX) : 0;
        }
        lua_settop(L, top);
    }
    return ret;
}

int lmt_run_callback(lua_State *L, int i, const char *values, ...)
{
    int top = 0;
    int ret = 0;
    if (lmt_callback_okay(L, i, &top)) {
        va_list args;
        va_start(args, values);
        ret = callbacklib_aux_run(L, i, 0, values, args, top, top + 2);
        va_end(args);
        lua_settop(L, top);
    }
    return ret;
}

void lmt_destroy_saved_callback(lua_State *L, int i)
{
    luaL_unref(L, LUA_REGISTRYINDEX, i);
}

static int callbacklib_callback_found(const char *s)
{
    if (s) {
        for (int cb = 0; cb < total_callbacks; cb++) {
            if (strcmp(callbacklib_names[cb], s) == 0) {
                return cb;
            }
        }
    }
    return -1;
}

static int callbacklib_callback_register(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    int cb = callbacklib_callback_found(s);
    if (cb >= 0) {
        switch (lua_type(L, 2)) {
            case LUA_TFUNCTION:
                lmt_callback_state.values[cb] = cb;
                break;
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, 2)) {
                    goto BAD; /*tex Only |false| is valid. */
                }
                // fall through
            case LUA_TNIL:
                lmt_callback_state.values[cb] = -1;
                break;
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_callback_state.metatable_id);
        lua_pushvalue(L, 2); /*tex the function or nil */
        lua_rawseti(L, -2, cb);
        lua_rawseti(L, LUA_REGISTRYINDEX, lmt_callback_state.metatable_id);
        lua_pushinteger(L, cb);
        return 1;
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

void lmt_run_memory_callback(const char* what, int success)
{
    lmt_run_callback(lmt_lua_state.lua_instance, trace_memory_callback, "Sb->", what, success);
    fflush(stdout);
}

/*tex

    The \LUA\ library that deals with callbacks has some diagnostic helpers that makes it possible
    to implement a higher level interface.

*/

static int callbacklib_callback_find(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    if (s) {
        int cb = callbacklib_callback_found(s);
        if (cb >= 0) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_callback_state.metatable_id);
            lua_rawgeti(L, -1, cb);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int callbacklib_callback_known(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    lua_pushboolean(L, s && (callbacklib_callback_found(s) >= 0));
    return 1;
}

static int callbacklib_callback_list(lua_State *L)
{
    lua_createtable(L, 0, total_callbacks);
    for (int cb = 1; cb < total_callbacks; cb++) {
        lua_pushstring(L, callbacklib_names[cb]);
        lua_pushboolean(L, lmt_callback_defined(cb));
        lua_rawset(L, -3);
    }
    return 1;
}

/* todo: language function calls */

void lmt_push_callback_usage(lua_State *L)
{
    lua_createtable(L, 0, 9);
    lua_push_integer_at_key(L, saved,    lmt_lua_state.saved_callback_count);
    lua_push_integer_at_key(L, file,     lmt_lua_state.file_callback_count);
    lua_push_integer_at_key(L, direct,   lmt_lua_state.direct_callback_count);
    lua_push_integer_at_key(L, function, lmt_lua_state.function_callback_count);
    lua_push_integer_at_key(L, value,    lmt_lua_state.value_callback_count);
    lua_push_integer_at_key(L, local,    lmt_lua_state.local_callback_count);
    lua_push_integer_at_key(L, bytecode, lmt_lua_state.bytecode_callback_count);
    lua_push_integer_at_key(L, message,  lmt_lua_state.message_callback_count);
    lua_push_integer_at_key(L, count,
        lmt_lua_state.saved_callback_count
      + lmt_lua_state.file_callback_count
      + lmt_lua_state.direct_callback_count
      + lmt_lua_state.function_callback_count
      + lmt_lua_state.value_callback_count
      + lmt_lua_state.local_callback_count
      + lmt_lua_state.bytecode_callback_count
      + lmt_lua_state.message_callback_count
    );
}

static int callbacklib_callback_usage(lua_State *L)
{
    lmt_push_callback_usage(L);
    return 1;
}

static const struct luaL_Reg callbacklib_function_list[] = {
    { "find",     callbacklib_callback_find     },
    { "known",    callbacklib_callback_known    },
    { "register", callbacklib_callback_register },
    { "list",     callbacklib_callback_list     },
    { "usage",    callbacklib_callback_usage    },
    { NULL,       NULL                          },
};

int luaopen_callback(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, callbacklib_function_list, 0);
    lua_newtable(L);
    lmt_callback_state.metatable_id = luaL_ref(L, LUA_REGISTRYINDEX);
    return 1;
}
