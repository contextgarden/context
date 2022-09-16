/*
    See license.txt in the root of this project.
*/

# include <stdlib.h>

# include "luametatex.h"

# define lzo_output_length(n)  (n + n / 16 + 64 + 64) /* we add 64 instead of 3 */

# define LZO_E_OK 0

typedef struct lzolib_state_info {

    int initialized;
    int padding;

    int (*lzo1x_1_compress)      (const char *source, size_t sourcesize, char *target, size_t *targetsize, void *wrkmem);
    int (*lzo1x_decompress_safe) (const char *source, size_t sourcesize, char *target, size_t *targetsize, void *wrkmem);

} lzolib_state_info;

static lzolib_state_info lzolib_state = {

    .initialized           = 0,
    .padding               = 0,

    .lzo1x_1_compress      = NULL,
    .lzo1x_decompress_safe = NULL,

};

static int lzolib_compress(lua_State *L)
{
    if (lzolib_state.initialized) {
        char *wrkmem = lmt_memory_malloc(16384 + 32); /* we some plenty of slack, normally 2 seemss enough */
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        luaL_Buffer buffer;
        size_t targetsize = lzo_output_length(sourcesize);
        char *target = luaL_buffinitsize(L, &buffer, targetsize);
        int result = lzolib_state.lzo1x_1_compress(source, sourcesize, target, &targetsize, wrkmem);
        if (result == LZO_E_OK) {
            luaL_pushresultsize(&buffer, targetsize);
        } else {
            lua_pushnil(L);
        }
        lmt_memory_free(wrkmem);
        return 1;
    } else {
        return 0;
    }
}

static int lzolib_decompresssize(lua_State *L)
{
    if (lzolib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        size_t targetsize = luaL_checkinteger(L, 2);
        if (source && targetsize > 0) {
            luaL_Buffer buffer;
            char *target = luaL_buffinitsize(L, &buffer, targetsize);
            int result = lzolib_state.lzo1x_decompress_safe(source, sourcesize, target, &targetsize, NULL);
            if (result == LZO_E_OK) {
                luaL_pushresultsize(&buffer, targetsize);
            } else {
                lua_pushnil(L);
            }
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int lzolib_initialize(lua_State *L)
{
    if (! lzolib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            lzolib_state.lzo1x_1_compress      = lmt_library_find(lib, "lzo1x_1_compress");
            lzolib_state.lzo1x_decompress_safe = lmt_library_find(lib, "lzo1x_decompress_safe");

            lzolib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, lzolib_state.initialized);
    return 1;
}

static struct luaL_Reg lzolib_function_list[] = {
    { "initialize",     lzolib_initialize     },
    { "compress",       lzolib_compress       },
    { "decompresssize", lzolib_decompresssize },
    { NULL,             NULL                  },
};

int luaopen_lzo(lua_State * L)
{
    lmt_library_register(L, "lzo", lzolib_function_list);
    return 0;
}
