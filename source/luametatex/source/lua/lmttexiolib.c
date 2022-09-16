/*
    See license.txt in the root of this project.
*/

/*tex

    This is a small module that deals with logging. We inherit from \TEX\ the dualistic model
    of console (terminal) and log file. One can write to one of them or both at the same time.
    We also inherit most of the logic that deals with going to a new line but we don't have the
    escaping with |^^| any longer: we live in \UNICODE\ times now. Because \TEX\ itself often
    outputs single characters and/or small strings, the console actually can have some real
    impact on performance: updating the display, rendering with complex fonts, intercepting
    \ANSI\ control sequences, scrolling, etc.

*/

# include "luametatex.h"

FILE *lmt_valid_file(lua_State *L) {
    luaL_Stream *p = (luaL_Stream *) lua_touserdata(L, 1);
    if (p && lua_getmetatable(L, 1)) {
        luaL_getmetatable(L, LUA_FILEHANDLE);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        return (p && (p)->closef) ? p->f : NULL;
    }
    return NULL;
}

typedef void (*texio_printer) (const char *);

inline static int texiolib_aux_get_selector_value(lua_State *L, int i, int *l, int dflt)
{
    switch (lua_type(L, i)) {
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L, i);
                if (lua_key_eq(s, logfile)) {
                    *l = logfile_selector_code;
                } else if (lua_key_eq(s, terminal)) {
                    *l = terminal_selector_code;
                } else if (lua_key_eq(s, terminal_and_logfile)) {
                    *l = terminal_and_logfile_selector_code;
                } else {
                    *l = dflt;
                }
                return 1;
            }
        case LUA_TNUMBER:
            {
                int n = lmt_tointeger(L, i);
                *l = n >= terminal_selector_code && n <= terminal_and_logfile_selector_code ? n : dflt;
                return 1;
            }
        default:
            return luaL_error(L, "(first) argument is not 'terminal_and_logfile', 'terminal' or 'logfile'");
    }
}

static void texiolib_aux_print(lua_State *L, int n, texio_printer printfunction, const char *dflt)
{
    int i = 1;
    int saved_selector = lmt_print_state.selector;
    if (n > 1 && texiolib_aux_get_selector_value(L, i, &lmt_print_state.selector, terminal_selector_code)) {
        i++;
    }
    switch (lmt_print_state.selector) {
        case terminal_and_logfile_selector_code:
        case logfile_selector_code:
        case terminal_selector_code:
            if (i <= n) {
                do {
                    switch (lua_type(L, i)) {
                        case LUA_TNIL:
                            break;
                        case LUA_TBOOLEAN:
                        case LUA_TNUMBER:
                        case LUA_TSTRING:
                            printfunction(lua_tostring(L, i));
                            break;
                        default:
                            luaL_error(L, "argument is not a string, number or boolean");
                    }
                    i++;
                } while (i <= n);
            } else if (dflt) {
                printfunction(dflt);
            }
        break;
    }
    lmt_print_state.selector = saved_selector;
}

static void texiolib_aux_print_selector(lua_State *L, int n, texio_printer printfunction, const char *dflt)
{
    int saved_selector = lmt_print_state.selector;
    texiolib_aux_get_selector_value(L, 1, &lmt_print_state.selector, no_print_selector_code);
    switch (lmt_print_state.selector) {
        case terminal_and_logfile_selector_code:
        case logfile_selector_code:
        case terminal_selector_code:
            {
                if (n > 1) {
                    for (int i = 2; i <= n; i++) {
                        switch (lua_type(L, i)) {
                            case LUA_TNIL:
                                break;
                            case LUA_TBOOLEAN:
                            case LUA_TNUMBER:
                            case LUA_TSTRING:
                                printfunction(lua_tostring(L, i));
                                break;
                            default:
                                luaL_error(L, "argument is not a string, number or boolean");
                        }
                    };
                } else if (dflt) {
                    printfunction(dflt);
                }
                break;
            }
    }
    lmt_print_state.selector = saved_selector;
}

static void texiolib_aux_print_stdout(lua_State *L, const char *extra)
{
    int i = 1;
    int l = terminal_and_logfile_selector_code;
    int n = lua_gettop(L);
    if (n > 1 && texiolib_aux_get_selector_value(L, i, &l, terminal_selector_code)) {
        i++;
    }
    for (; i <= n; i++) {
        if (lua_isstring(L, i)) { /* or number */
            const char *s = lua_tostring(L, i);
            if (l == terminal_and_logfile_selector_code || l == terminal_selector_code) {
                fputs(extra, stdout);
                fputs(s, stdout);
            }
            if (l == terminal_and_logfile_selector_code || l == logfile_selector_code) {
                if (lmt_print_state.loggable_info) {
                    char *v = (char*) lmt_memory_malloc(strlen(lmt_print_state.loggable_info) + strlen(extra) + strlen(s) + 1);
                    if (v) {
                        sprintf(v, "%s%s%s", lmt_print_state.loggable_info, extra, s);
                    }
                    lmt_memory_free(lmt_print_state.loggable_info);
                    lmt_print_state.loggable_info = v;
                } else {
                    lmt_print_state.loggable_info = lmt_memory_strdup(s);
                }
            }
        }
    }
}

static void texiolib_aux_print_nlp_str(const char *s)
{
    tex_print_nlp();
    tex_print_str(s);
}

static int texiolib_write(lua_State *L)
{
    if (lmt_main_state.ready_already == output_disabled_state || ! lmt_fileio_state.job_name) {
        texiolib_aux_print_stdout(L, "");
    } else {
        int n = lua_gettop(L);
        if (n > 0) {
            texiolib_aux_print(L, n, tex_print_str, NULL);
        } else {
            /*tex We silently ignore bogus calls. */
        }
    }
    return 0;
}


static int texiolib_write_nl(lua_State *L)
{
    if (lmt_main_state.ready_already == output_disabled_state || ! lmt_fileio_state.job_name) {
        texiolib_aux_print_stdout(L, "\n");
    } else {
        int n = lua_gettop(L);
        if (n > 0) {
            texiolib_aux_print(L, n, texiolib_aux_print_nlp_str, "\n");
        } else {
            /*tex We silently ignore bogus calls. */
        }
    }
    return 0;
}

static int texiolib_write_selector(lua_State *L)
{
    if (lmt_main_state.ready_already == output_disabled_state || ! lmt_fileio_state.job_name) {
        texiolib_aux_print_stdout(L, "");
    } else {
        int n = lua_gettop(L);
        if (n > 1) {
            texiolib_aux_print_selector(L, n, tex_print_str, NULL);
        } else {
            /*tex We silently ignore bogus calls. */
        }
    }
    return 0;
}


static int texiolib_write_selector_nl(lua_State *L)
{
    if (lmt_main_state.ready_already == output_disabled_state || ! lmt_fileio_state.job_name) {
        texiolib_aux_print_stdout(L, "\n");
    } else {
        int n = lua_gettop(L);
        if (n > 1) {
            texiolib_aux_print_selector(L, n, texiolib_aux_print_nlp_str, "");
        } else {
            /*tex We silently ignore bogus calls. */
        }
    }
    return 0;
}

static int texiolib_write_selector_lf(lua_State *L)
{
    if (lmt_main_state.ready_already == output_disabled_state || ! lmt_fileio_state.job_name) {
        texiolib_aux_print_stdout(L, "\n");
    } else {
        int n = lua_gettop(L);
        if (n >= 1) {
            texiolib_aux_print_selector(L, n, texiolib_aux_print_nlp_str, "");
        } else {
            /*tex We silently ignore bogus calls. */
        }
    }
    return 0;
}

/*tex At the point this function is called, the selector is log_only. */

static int texiolib_closeinput(lua_State *L)
{
    (void) (L);
    if (lmt_input_state.cur_input.index > 0) {
        tex_end_token_list();
        tex_end_file_reading();
    }
    return 0 ;
}

/*tex
    This is a private hack, handy for testing runtime math font patches in lfg files with a bit of
    low level tracing. Setting the logfile is already handles by a callback so we don't support
    string argument here because we'd end up in that callback which then returns the same logfile
    name as we already had.
*/

static int texiolib_setlogfile(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        /* If not writeable then all goes into the void. */
        if (! lmt_print_state.logfile) {
            lmt_print_state.saved_logfile = lmt_print_state.logfile;
            lmt_print_state.saved_logfile_offset = lmt_print_state.logfile_offset;

        }
        lmt_print_state.logfile = f;
        lmt_print_state.logfile_offset = 0;
    } else if (lmt_print_state.logfile) {
        lmt_print_state.logfile = lmt_print_state.saved_logfile;
        lmt_print_state.logfile_offset = lmt_print_state.saved_logfile_offset;
    }
    return 0;
}

static const struct luaL_Reg texiolib_function_list[] = {
    { "write",           texiolib_write             },
    { "writenl",         texiolib_write_nl          },
    { "write_nl",        texiolib_write_nl          }, /* depricated */
    { "writeselector",   texiolib_write_selector    },
    { "writeselectornl", texiolib_write_selector_nl },
    { "writeselectorlf", texiolib_write_selector_lf },
    { "closeinput",      texiolib_closeinput        },
    { "setlogfile",      texiolib_setlogfile        },
    { NULL,              NULL                       },
};

static const struct luaL_Reg texiolib_function_list_only[] = {
    { "write",           texiolib_write             },
    { "writenl",         texiolib_write_nl          },
    { "write_nl",        texiolib_write_nl          }, /* depricated */
    { "writeselector",   texiolib_write_selector    },
    { "writeselectornl", texiolib_write_selector_nl },
    { "writeselectorlf", texiolib_write_selector_lf },
    { NULL,              NULL                       },
};

int luaopen_texio(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, lmt_engine_state.lua_only ? texiolib_function_list_only : texiolib_function_list, 0);
    return 1;
}
