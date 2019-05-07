/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

typedef void (*texio_printer) (const char *);

# define loggable_info print_state.loggable_info

static int get_selector_value(lua_State * L, int i, int *l)
{
    if (lua_type(L,i) == LUA_TSTRING) {
        const char *s = lua_tostring(L, i);
        if (lua_key_eq(s,term_and_log)) {
            *l = term_and_log;
        } else if (lua_key_eq(s,log)) {
            *l = log_only;
        } else if (lua_key_eq(s,term)) {
            *l = term_only;
        } else {
            *l = term_and_log;
        }
        return 1;
    } else {
        luaL_error(L, "first argument is not 'term and log', 'term' or 'log'");
        return 0;
    }
}

static int do_texio_print(lua_State * L, texio_printer printfunction)
{
    /*tex We silently ignore bogus calls. */
    int n = lua_gettop(L);
    if (n > 0) {
        const char *s;
        int i = 1;
        int save_selector = selector;
        if (n > 1 && get_selector_value(L, i, &selector)) {
            i++;
        }
        if (selector == term_and_log || selector == log_only || selector == term_only) {
            for (; i <= n; i++) {
                if (lua_isstring(L, i)) { /* or number */
                    s = lua_tostring(L, i);
                    printfunction(s);
                } else {
                    luaL_error(L, "argument is not a string");
                }
            }
        }
        selector = save_selector;
    }
    return 0;
}

static void do_texio_ini_print(lua_State * L, const char *extra)
{
    const char *s;
    int i = 1;
    int l = term_and_log;
    int n = lua_gettop(L);
    if (n > 1 && get_selector_value(L, i, &l)) {
        i++;
    }
    for (; i <= n; i++) {
        if (lua_isstring(L, i)) { /* or number */
            s = lua_tostring(L, i);
            if (l == term_and_log || l == term_only)
                fprintf(stdout, "%s%s", extra, s);
            if (l == term_and_log || l == log_only) {
                if (loggable_info == NULL) {
                    loggable_info = strdup(s);
                } else {
                    char *v = (char*) malloc(strlen(loggable_info) + strlen(extra) + strlen(s) + 1);
                    sprintf(v,"%s%s%s",loggable_info,extra,s);
                    free(loggable_info);
                    loggable_info = v;
                }
            }
        }
    }
}

static int texio_print(lua_State * L)
{
    if (main_state.ready_already != 314159 || fileio_state.job_name == NULL) {
        do_texio_ini_print(L, "");
        return 0;
    }
    return do_texio_print(L, tprint);
}

static int texio_printnl(lua_State * L)
{
    if (main_state.ready_already != 314159 || fileio_state.job_name == NULL) {
        do_texio_ini_print(L, "\n");
        return 0;
    }
    return do_texio_print(L, tprint_nl);
}

/*tex At the point this function is called, the selector is log_only. */

void flush_loggable_info(void)
{
    if (loggable_info != NULL) {
        fprintf(log_file, "%s\n", loggable_info);
        free(loggable_info);
        loggable_info = NULL;
    }
}

static int texio_setescape(lua_State * L)
{
    if (lua_type(L, 1) == LUA_TBOOLEAN) {
        escape_controls = lua_toboolean(L,1);
    } else {
        escape_controls = lua_tointeger(L,1);
    }
    return 0 ;
}

static int texio_closeinput(lua_State * L)
{
    (void) (L);
    if (iindex > 0) {
        end_token_list();
        end_file_reading();
    }
    return 0 ;
}

static const struct luaL_Reg texiolib[] = {
    { "write",      texio_print },
    { "write_nl",   texio_printnl },
    { "setescape",  texio_setescape },
    { "closeinput", texio_closeinput },
    { NULL,         NULL }
};

static const struct luaL_Reg onlytexiolib[] = {
    { "write",      texio_print },
    { "write_nl",   texio_printnl },
    { NULL,         NULL }
};

int luaopen_texio(lua_State * L)
{
    lua_newtable(L);
    luaL_setfuncs(L, engine_state.lua_only ? onlytexiolib : texiolib, 0);
    return 1;
}
