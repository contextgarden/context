/*
    See license.txt in the root of this project.
*/

# include <stdlib.h>

# include "luametatex.h"
# include "lmtoptional.h"

# define LZ4F_VERSION 100  /* used to check for an incompatible API breaking change */

typedef struct lz4lib_state_info {

    int initialized;
    int padding;

    int      (*LZ4_compressBound)               (int inputSize);
    int      (*LZ4_compress_fast)               (const char *src, char *dst, int srcSize, int dstCapacity, int acceleration);
    int      (*LZ4_decompress_safe)             (const char *src, char *dst, int compressedSize, int dstCapacity);
    size_t   (*LZ4F_compressFrameBound)         (size_t srcSize, void *);
    size_t   (*LZ4F_compressFrame)              (void *dstBuffer, size_t dstCapacity, const void* srcBuffer, size_t srcSize, void *);
    unsigned (*LZ4F_isError)                    (int code);
    int      (*LZ4F_createDecompressionContext) (void **dctxPtr, unsigned version);
    int      (*LZ4F_freeDecompressionContext)   (void *dctx);
    size_t   (*LZ4F_decompress)                 (void *dctx, void *dstBuffer, size_t *dstSizePtr, const void *srcBuffer, size_t *srcSizePtr, void *);

} lz4lib_state_info;

static lz4lib_state_info lz4lib_state = {

    .initialized = 0,
    .padding     = 0,

    .LZ4_compressBound               = NULL,
    .LZ4_compress_fast               = NULL,
    .LZ4_decompress_safe             = NULL,
    .LZ4F_compressFrameBound         = NULL,
    .LZ4F_compressFrame              = NULL,
    .LZ4F_isError                    = NULL,
    .LZ4F_createDecompressionContext = NULL,
    .LZ4F_freeDecompressionContext   = NULL,
    .LZ4F_decompress                 = NULL,

};

static int lz4lib_compress(lua_State *L)
{
    if (lz4lib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        lua_Integer acceleration = luaL_optinteger(L, 2, 1);
        size_t targetsize = lz4lib_state.LZ4_compressBound((int) sourcesize);
        luaL_Buffer buffer;
        char *target = luaL_buffinitsize(L, &buffer, targetsize);
        int result = lz4lib_state.LZ4_compress_fast(source, target, (int) sourcesize, (int) targetsize, (int) acceleration);
        if (result > 0) {
            luaL_pushresultsize(&buffer, result);
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

/*

    There is no info about the target size so we don't provide a decompress function. Either use
    the frame variant or save and restore the targetsize,

    static int lz4lib_decompress(lua_State *L)
    {
        lua_pushnil(L);
        return 1;
    }

*/

static int lz4lib_decompresssize(lua_State *L)
{
    if (lz4lib_state.initialized) {
        size_t sourcesize = 0;
        size_t targetsize = luaL_checkinteger(L, 2);
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        if (source && targetsize > 0) {
            luaL_Buffer buffer;
            char *target = luaL_buffinitsize(L, &buffer, targetsize);
            int result = lz4lib_state.LZ4_decompress_safe(source, target, (int) sourcesize, (int) targetsize);
            if (result > 0) {
                luaL_pushresultsize(&buffer, result);
            } else {
                lua_pushnil(L);
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int lz4lib_framecompress(lua_State *L)
{
    if (lz4lib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        luaL_Buffer buffer;
        size_t targetsize = lz4lib_state.LZ4F_compressFrameBound(sourcesize, NULL);
        char *target = luaL_buffinitsize(L, &buffer, targetsize);
        size_t result = lz4lib_state.LZ4F_compressFrame(target, targetsize, source, sourcesize, NULL);
        luaL_pushresultsize(&buffer, result);
    }
    return 1;
}

static int lz4lib_framedecompress(lua_State *L)
{
    if (lz4lib_state.initialized) {
        size_t sourcesize = 0;
        const char *source = luaL_checklstring(L, 1, &sourcesize);
        if (source) {
            void *context = NULL;
            int errorcode = lz4lib_state.LZ4F_createDecompressionContext(&context, LZ4F_VERSION);
            if (lz4lib_state.LZ4F_isError(errorcode)) {
                lua_pushnil(L);
            } else {
                luaL_Buffer buffer;
                luaL_buffinit(L, &buffer);
                while (1) {
                    size_t targetsize = 0xFFFF;
                    char *target = luaL_prepbuffsize(&buffer, targetsize);
                    size_t consumed = sourcesize;
                    size_t errorcode = lz4lib_state.LZ4F_decompress(context, target, &targetsize, source, &consumed, NULL);
                    if (lz4lib_state.LZ4F_isError((int) errorcode)) {
                        lua_pushnil(L);
                        break;
                    } else if (targetsize == 0) {
                        luaL_pushresult(&buffer);
                        break;
                    } else {
                        luaL_addsize(&buffer, targetsize);
                        sourcesize -= consumed;
                        source += consumed;
                    }
                }
            }
            if (context) {
                lz4lib_state.LZ4F_freeDecompressionContext(context);
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int lz4lib_initialize(lua_State *L)
{
    if (! lz4lib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            lz4lib_state.LZ4_compressBound               = lmt_library_find(lib, "LZ4_compressBound");
            lz4lib_state.LZ4_compress_fast               = lmt_library_find(lib, "LZ4_compress_fast");
            lz4lib_state.LZ4_decompress_safe             = lmt_library_find(lib, "LZ4_decompress_safe");
            lz4lib_state.LZ4F_compressFrameBound         = lmt_library_find(lib, "LZ4F_compressFrameBound");
            lz4lib_state.LZ4F_compressFrame              = lmt_library_find(lib, "LZ4F_compressFrame");
            lz4lib_state.LZ4F_isError                    = lmt_library_find(lib, "LZ4F_isError");
            lz4lib_state.LZ4F_createDecompressionContext = lmt_library_find(lib, "LZ4F_createDecompressionContext");
            lz4lib_state.LZ4F_freeDecompressionContext   = lmt_library_find(lib, "LZ4F_freeDecompressionContext");
            lz4lib_state.LZ4F_decompress                 = lmt_library_find(lib, "LZ4F_decompress");

            lz4lib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, lz4lib_state.initialized);
    return 1;
}

static struct luaL_Reg lz4lib_function_list[] = {
    { "initialize",      lz4lib_initialize      },
    { "compress",        lz4lib_compress        },
 /* { "decompress",      lz4lib_decompress      }, */
    { "decompresssize",  lz4lib_decompresssize  },
    { "framecompress",   lz4lib_framecompress   },
    { "framedecompress", lz4lib_framedecompress },
    { NULL,              NULL                   },
};

int luaopen_lz4(lua_State * L)
{
    lmt_library_register(L, "lz4", lz4lib_function_list);
    return 0;
}
