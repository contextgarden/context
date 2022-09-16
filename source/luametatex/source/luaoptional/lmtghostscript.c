/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

# define GS_ARG_ENCODING_UTF8 1

typedef struct gslib_state_info {

    int         initialized;
    int         padding;
    luaL_Buffer outbuffer;
    luaL_Buffer errbuffer;

    int (*gsapi_new_instance) (
        void **pinstance,
        void  *caller_handle
    );

    void (*gsapi_delete_instance) (
        void * instance
    );

    int (*gsapi_set_arg_encoding) (
        void *instance,
        int   encoding
    );

    int (*gsapi_init_with_args) (
        void        *instance,
        int          argc,
        const char **argv
    );

    int (*gsapi_set_stdio) (
        void *instance,
        int (*stdin_fn )(void *caller_handle, char       *buf, int len),
        int (*stdout_fn)(void *caller_handle, const char *str, int len),
        int (*stderr_fn)(void *caller_handle, const char *str, int len)
    );

    /*
    int (*gsapi_run_string_begin)       (void *instance, int user_errors, int *pexit_code);
    int (*gsapi_run_string_continue)    (void *instance, const char *str, unsigned int length, int user_errors, int *pexit_code);
    int (*gsapi_run_string_end)         (void *instance, int user_errors, int *pexit_code);
    int (*gsapi_run_string_with_length) (void *instance, const char *str, unsigned int length, int user_errors, int *pexit_code);
    int (*gsapi_run_string)             (void *instance, const char *str, int user_errors, int *pexit_code);
    int (*gsapi_run_file)               (void *instance, const char *file_name, int user_errors, int *pexit_code);
    int (*gsapi_exit)                   (void *instance);
    */

} gslib_state_info;

static gslib_state_info gslib_state = {

    .initialized                  = 0,
    .padding                      = 0,
 /* .outbuffer                    = NULL, */
 /* .errbuffer                    = NULL, */

    .gsapi_new_instance           = NULL,
    .gsapi_delete_instance        = NULL,
    .gsapi_set_arg_encoding       = NULL,
    .gsapi_init_with_args         = NULL,
    .gsapi_set_stdio              = NULL,

};

static int gslib_initialize(lua_State * L)
{
    if (! gslib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            gslib_state.gsapi_new_instance     = lmt_library_find(lib, "gsapi_new_instance");
            gslib_state.gsapi_delete_instance  = lmt_library_find(lib, "gsapi_delete_instance");
            gslib_state.gsapi_set_arg_encoding = lmt_library_find(lib, "gsapi_set_arg_encoding");
            gslib_state.gsapi_init_with_args   = lmt_library_find(lib, "gsapi_init_with_args");
            gslib_state.gsapi_set_stdio        = lmt_library_find(lib, "gsapi_set_stdio");

            gslib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, gslib_state.initialized);
    return 1;
}

/* We could have a callback for stdout and error. */

static int gslib_stdout(void * caller_handle, const char *str, int len)
{
    (void)caller_handle;
    luaL_addlstring(&gslib_state.outbuffer, str, len);
    return len;
}

static int gslib_stderr(void * caller_handle, const char *str, int len)
{
    (void)caller_handle;
    luaL_addlstring(&gslib_state.errbuffer, str, len);
    return len;
}

static int gslib_execute(lua_State * L)
{
    if (gslib_state.initialized) {
        if (lua_type(L, 1) == LUA_TTABLE) {
            size_t n = (int) lua_rawlen(L, 1);
            if (n > 0) {
                void *instance = NULL;
                int result = gslib_state.gsapi_new_instance(&instance, NULL);
                if (result >= 0) {
                    /*tex
                        Strings are not yet garbage colected. We add some slack. Here MSVC wants
                        |char**| and gcc wants |const char**| i.e.\ doesn't like a castso we just
                        accept the less annoying MSVC warning.
                    */
                    const char** arguments = malloc((n + 2) * sizeof(char*));
                    if (arguments) {
                        int m = 1;
                        /*tex This is a kind of dummy. */
                        arguments[0] = "ghostscript";
                        luaL_buffinit(L, &gslib_state.outbuffer);
                        luaL_buffinit(L, &gslib_state.errbuffer);
                        gslib_state.gsapi_set_stdio(instance, NULL, &gslib_stdout, &gslib_stderr);
                        for (size_t i = 1; i <= n; i++) {
                            lua_rawgeti(L, 1, i);
                            switch (lua_type(L, -1)) {
                            case LUA_TSTRING:
                            case LUA_TNUMBER:
                            {
                                size_t l = 0;
                                const char *s = lua_tolstring(L, -1, &l);
                                if (l > 0) {
                                    arguments[m] = s;
                                    m += 1;
                                }
                            }
                            break;
                            }
                            lua_pop(L, 1);
                        }
                        arguments[m] = NULL;
                        result = gslib_state.gsapi_set_arg_encoding(instance, GS_ARG_ENCODING_UTF8);
                        result = gslib_state.gsapi_init_with_args(instance, m, arguments);
                        gslib_state.gsapi_delete_instance(instance);
                        /* Nothing done with the array cells! No gc done yet anyway. */
                        free((void *) arguments);
                        lua_pushboolean(L, result >= 0);
                        luaL_pushresult(&gslib_state.outbuffer);
                        luaL_pushresult(&gslib_state.errbuffer);
                        return 3;
                    }
                }
            }
        }
    }
    return 0;
}

static struct luaL_Reg gslib_function_list[] = {
    { "initialize", gslib_initialize },
    { "execute",    gslib_execute    },
    { NULL,         NULL             },
};

int luaopen_ghostscript(lua_State * L)
{
    lmt_library_register(L, "ghostscript", gslib_function_list);
    return 0;
}
