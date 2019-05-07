/*
    See license.txt in the root of this project.
*/

# include <stdlib.h>
# include <string.h>

# include <lua.h>
# include <lauxlib.h>

# include "lflatelib.h"

# include "../libs/libdeflate/lib/unaligned.h"
# include "../libs/libdeflate/lib/zlib_constants.h"
# include "../libs/libdeflate/libdeflate.h"

/*
    LIBDEFLATE_SUCCESS            = 0
    LIBDEFLATE_BAD_DATA           = 1
    LIBDEFLATE_SHORT_OUTPUT       = 2
    LIBDEFLATE_INSUFFICIENT_SPACE = 3
*/

static int compress(lua_State * L, int method)
{
    int rate = luaL_optinteger(L,2,3);
    if (rate > 0) {
        size_t sourcesize = 0;
        size_t resultsize = 0;
        const char *source = lua_tolstring(L,1,&sourcesize);
        size_t targetsize = sourcesize + ZLIB_MIN_OVERHEAD ;
        char *target = malloc(targetsize);
        struct libdeflate_compressor *compressor = libdeflate_alloc_compressor(rate > 12 ? 12 : rate);
        switch (method) {
            case 1 :
                resultsize = libdeflate_deflate_compress((void *)compressor,source,sourcesize,target,targetsize);
                break;
            case 2 :
                resultsize = libdeflate_zlib_compress   ((void *)compressor,source,sourcesize,target,targetsize);
                break;
            case 3 :
                resultsize = libdeflate_gzip_compress   ((void *)compressor,source,sourcesize,target,targetsize);
                break;
        }
        if (resultsize > 0) {
            lua_pushlstring(L,target,resultsize);
        } else {
            lua_pushboolean(L,0);
        }
        free(target);
        libdeflate_free_compressor(compressor);
    } else {
        lua_pushboolean(L,0);
    }
    return 1;
}

static int decompress(lua_State * L, int method)
{
    size_t sourcesize = 0;
    size_t resultsize = 0;
    const char *source = lua_tolstring(L,1,&sourcesize);
    size_t targetsize = lua_tointeger(L,2);
    char *target = malloc(targetsize);
    struct libdeflate_decompressor *decompressor = libdeflate_alloc_decompressor();
    int result = 0;
    switch (method) {
        case 1 :
            result = libdeflate_deflate_decompress((void *)decompressor,source,sourcesize,target,targetsize,&resultsize);
            break;
        case 2 :
            result = libdeflate_zlib_decompress   ((void *)decompressor,source,sourcesize,target,targetsize,&resultsize);
            break;
        case 3 :
            result = libdeflate_gzip_decompress   ((void *)decompressor,source,sourcesize,target,targetsize,&resultsize);
            break;
    }
    if (result == LIBDEFLATE_SUCCESS) {
        lua_pushlstring(L,target,resultsize);
        result = 1;
    } else {
        lua_pushboolean(L,0);
        lua_pushinteger(L,result);
        result = 2;
    }
    free(target);
    libdeflate_free_decompressor(decompressor);
    return result;
}

static int update(lua_State * L, int method)
{
    int checksum = luaL_optinteger(L,2,0);
    size_t buffersize = 0;
    const char *buffer = lua_tolstring(L,1,&buffersize);
    switch (method) {
        case 1 :
            checksum = libdeflate_adler32(checksum,buffer,buffersize);
            break;
        case 2 :
            checksum = libdeflate_crc32(checksum,buffer,buffersize);
            break;
    }
    lua_pushinteger(L,checksum);
    return 1;
}

static int flate_compress  (lua_State * L) { return compress(L,1); }
static int zip_compress    (lua_State * L) { return compress(L,2); }
static int gz_compress     (lua_State * L) { return compress(L,3); }

static int flate_decompress(lua_State * L) { return decompress(L,1); }
static int zip_decompress  (lua_State * L) { return decompress(L,2); }
static int gz_decompress   (lua_State * L) { return decompress(L,3); }

static int update_adler32  (lua_State * L) { return update(L,1) ; }
static int update_crc32    (lua_State * L) { return update(L,2) ; }

static struct luaL_Reg flatelib[] = {
    { "flate_compress",   flate_compress },
    { "flate_decompress", flate_decompress },
    { "zip_compress",     zip_compress },
    { "zip_decompress",   zip_decompress },
    { "gz_compress",      gz_compress },
    { "gz_decompress",    gz_decompress },
    { "update_adler32",   update_adler32 },
    { "update_crc32",     update_crc32 },
    { NULL,               NULL }
};

int luaopen_flate(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, flatelib, 0);
    return 1;
}
