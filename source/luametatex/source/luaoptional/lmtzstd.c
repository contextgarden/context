/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

# define ZSTD_DEFAULTCLEVEL 3

typedef struct zstdlib_state_info {

    int initialized;
    int padding;

    size_t      (*ZSTD_compressBound)           (size_t srcSize);
    size_t      (*ZSTD_getFrameContentSize)     (const void *, size_t);
    size_t      (*ZSTD_compress)                (void *dst, size_t dstCapacity, const void *src, size_t srcSize, int compressionLevel);
    size_t      (*ZSTD_decompress)              (void *dst, size_t dstCapacity, const void *src, size_t compressedSize);
 /* int         (*ZSTD_minCLevel)               (void);        */
 /* int         (*ZSTD_maxCLevel)               (void);        */
 /* unsigned    (*ZSTD_isError)                 (size_t code); */
 /* const char *(*ZSTD_getErrorName)            (size_t code); */

} zstdlib_state_info;

static zstdlib_state_info zstdlib_state = {

    .initialized              = 0,
    .padding                  = 0,

    .ZSTD_compressBound       = NULL,
    .ZSTD_getFrameContentSize = NULL,
    .ZSTD_compress            = NULL,
    .ZSTD_decompress          = NULL,
 /* .ZSTD_minCLevel           = NULL, */
 /* .ZSTD_maxCLevel           = NULL, */
 /* .ZSTD_isError             = NULL, */
 /* .ZSTD_getErrorName        = NULL, */

};

static int zstdlib_compress(lua_State *L)
{
    if (zstdlib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        int level = lmt_optinteger(L, 2, ZSTD_DEFAULTCLEVEL);
        size_t targetsize = zstdlib_state.ZSTD_compressBound(sourcesize);
        luaL_Buffer buffer;
        char *target = luaL_buffinitsize(L, &buffer, targetsize);
        size_t result = zstdlib_state.ZSTD_compress(target, targetsize, source, sourcesize, level);
        if (result > 0) {
            luaL_pushresultsize(&buffer, result);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int zstdlib_decompress(lua_State *L)
{
    if (zstdlib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        size_t targetsize = zstdlib_state.ZSTD_getFrameContentSize(source, sourcesize);
        luaL_Buffer buffer;
        char *target = luaL_buffinitsize(L, &buffer, targetsize);
        size_t result = zstdlib_state.ZSTD_decompress(target, targetsize, source, sourcesize);
        if (result > 0) {
            luaL_pushresultsize(&buffer, result);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int zstdlib_initialize(lua_State *L)
{
    if (! zstdlib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            zstdlib_state.ZSTD_compressBound       = lmt_library_find(lib, "ZSTD_compressBound");
            zstdlib_state.ZSTD_getFrameContentSize = lmt_library_find(lib, "ZSTD_getFrameContentSize");
            zstdlib_state.ZSTD_compress            = lmt_library_find(lib, "ZSTD_compress");
            zstdlib_state.ZSTD_decompress          = lmt_library_find(lib, "ZSTD_decompress");
         /* zstdlib_state.ZSTD_minCLevel           = lmt_library_find(lib, "ZSTD_minCLevel"); */
         /* zstdlib_state.ZSTD_maxCLevel           = lmt_library_find(lib, "ZSTD_maxCLevel"); */
         /* zstdlib_state.ZSTD_isError             = lmt_library_find(lib, "ZSTD_isError"); */
         /* zstdlib_state.ZSTD_getErrorName        = lmt_library_find(lib, "ZSTD_getErrorName"); */

            zstdlib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, zstdlib_state.initialized);
    return 1;
}

static struct luaL_Reg zstdlib_function_list[] = {
    { "initialize", zstdlib_initialize },
    { "compress",   zstdlib_compress   },
    { "decompress", zstdlib_decompress },
    { NULL,         NULL               },
};

int luaopen_zstd(lua_State * L)
{
    lmt_library_register(L, "zstd", zstdlib_function_list);
    return 0;
}
