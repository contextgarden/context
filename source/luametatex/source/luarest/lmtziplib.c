/*
    See license.txt in the root of this project.
*/

# define ZLIB_CONST 1

# include "luametatex.h"

/*tex

    This is a rather minimalistic interface to zlib. We can wrap around it and need some specific
    file overhead anyway. Also, we never needed all that stream stuff.

*/

# define ziplib_in_char_ptr   const unsigned char *
# define ziplib_out_char_ptr  unsigned char *

# define ziplib_buffer_size 16*1024

static int ziplib_aux_compress(
    lua_State  *L,
    const char *data,
    int         size,
    int         level,
    int         method,
    int         window,
    int         memory,
    int         strategy,
    int         buffersize
)
{
    int state;
    z_stream zipstream;
    zipstream.zalloc = &lmt_zlib_alloc; /* Z_NULL */
    zipstream.zfree = &lmt_zlib_free; /* Z_NULL */
    zipstream.next_out = Z_NULL;
    zipstream.avail_out = 0;
    zipstream.next_in = Z_NULL;
    zipstream.avail_in = 0;
    state = deflateInit2(&zipstream, level, method, window, memory, strategy);
    if (state == Z_OK) {
        luaL_Buffer buffer;
        luaL_buffinit(L, &buffer);
        zipstream.next_in = (ziplib_in_char_ptr) data;
        zipstream.avail_in = size;
        while (1) {
            zipstream.next_out = (ziplib_out_char_ptr) luaL_prepbuffsize(&buffer, buffersize);
            zipstream.avail_out = buffersize;
            state = deflate(&zipstream, Z_FINISH);
            if (state != Z_OK && state != Z_STREAM_END) {
                lua_pushnil(L);
                break;
            } else {
                luaL_addsize(&buffer, buffersize - zipstream.avail_out);
                if (zipstream.avail_out != 0) {
                    luaL_pushresult(&buffer);
                    break;
                }
            }
        }
        deflateEnd(&zipstream);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int ziplib_compress(lua_State *L)
{
    const char *data = luaL_checkstring(L, 1);
    int size = (int) lua_rawlen(L, 1);
    int level = lmt_optinteger(L, 2, Z_DEFAULT_COMPRESSION);
    int method = lmt_optinteger(L, 3, Z_DEFLATED);
    int window = lmt_optinteger(L, 4, 15);
    int memory = lmt_optinteger(L, 5, 8);
    int strategy = lmt_optinteger(L, 6, Z_DEFAULT_STRATEGY);
    return ziplib_aux_compress(L, data, size, level, method, window, memory, strategy, ziplib_buffer_size);
}

static int ziplib_compresssize(lua_State *L)
{
    const char *data = luaL_checkstring(L, 1);
    int size = (int) lua_rawlen(L, 1);
    int level = lmt_optinteger(L, 2, Z_DEFAULT_COMPRESSION);
    int buffersize = lmt_optinteger(L, 3, ziplib_buffer_size);
    int window = lmt_optinteger(L, 4, 15); /* like decompresssize */
    return ziplib_aux_compress(L, data, size, level, Z_DEFLATED, window, 8, Z_DEFAULT_STRATEGY, buffersize);
}

static int ziplib_decompress(lua_State *L)
{
    const char *data = luaL_checkstring(L, 1);
    int size = (int) lua_rawlen(L, 1);
    int window = lmt_optinteger(L, 2, 15);
    int state;
    z_stream zipstream;
    zipstream.zalloc = &lmt_zlib_alloc; /* Z_NULL */
    zipstream.zfree = &lmt_zlib_free; /* Z_NULL */
    zipstream.next_out = Z_NULL;
    zipstream.avail_out = 0;
    zipstream.next_in = Z_NULL;
    zipstream.avail_in = 0;
    state = inflateInit2(&zipstream, window);
    if (state == Z_OK) {
        luaL_Buffer buffer;
        luaL_buffinit(L, &buffer);
        zipstream.next_in = (ziplib_in_char_ptr) data;
        zipstream.avail_in = size;
        while (1) {
            zipstream.next_out = (ziplib_out_char_ptr) luaL_prepbuffsize(&buffer, ziplib_buffer_size);
            zipstream.avail_out = ziplib_buffer_size;
            state = inflate(&zipstream, Z_NO_FLUSH);
            luaL_addsize(&buffer, ziplib_buffer_size - zipstream.avail_out);
            if (state == Z_STREAM_END) {
                luaL_pushresult(&buffer);
                break;
            } else if (state != Z_OK) {
                lua_pushnil(L);
                break;
            } else if (zipstream.avail_out == 0) {
                continue;
            } else if (zipstream.avail_in == 0) {
                luaL_pushresult(&buffer);
                break;
            }
        }
        inflateEnd(&zipstream);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int ziplib_decompresssize(lua_State *L)
{
    const char *data = luaL_checkstring(L, 1);
    int size = (int) lua_rawlen(L, 1);
    int targetsize = lmt_tointeger(L, 2);
    int window = lmt_optinteger(L, 3, 15);
    int state;
    z_stream zipstream;
    zipstream.zalloc = &lmt_zlib_alloc; /* Z_NULL */
    zipstream.zfree = &lmt_zlib_free; /* Z_NULL */
    zipstream.next_out = Z_NULL;
    zipstream.avail_out = 0;
    zipstream.next_in = Z_NULL;
    zipstream.avail_in = 0;
    state = inflateInit2(&zipstream, window);
    if (state == Z_OK) {
        luaL_Buffer buffer;
        zipstream.next_in = (ziplib_in_char_ptr) data;
        zipstream.avail_in = size;
        zipstream.next_out = (ziplib_out_char_ptr) luaL_buffinitsize(L, &buffer, (lua_Integer) targetsize + 100);
        zipstream.avail_out = targetsize + 100;
        state = inflate(&zipstream, Z_NO_FLUSH); /* maybe Z_FINISH buffer large enough */
        if (state != Z_OK && state != Z_STREAM_END) {
            lua_pushnil(L);
        } else if (zipstream.avail_in == 0) {
            luaL_pushresultsize(&buffer, targetsize);
        } else {
            lua_pushnil(L);
        }
        inflateEnd(&zipstream);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int ziplib_adler32(lua_State *L)
{
    int checksum = lmt_optinteger(L, 2, 0);
    size_t buffersize = 0;
    const char *buffer = lua_tolstring(L, 1, &buffersize);
    checksum = adler32(checksum, (ziplib_in_char_ptr) buffer, (unsigned int) buffersize);
    lua_pushinteger(L, checksum);
    return 1;
}

static int ziplib_crc32(lua_State *L)
{
    int checksum = lmt_optinteger(L, 2, 0);
    size_t buffersize = 0;
    const char *buffer = lua_tolstring(L, 1, &buffersize);
    checksum = crc32(checksum, (ziplib_in_char_ptr) buffer, (unsigned int) buffersize);
    lua_pushinteger(L, checksum);
    return 1;
}

static struct luaL_Reg ziplib_function_list[] = {
    { "compress",       ziplib_compress       },
    { "compresssize",   ziplib_compresssize   },
    { "decompress",     ziplib_decompress     },
    { "decompresssize", ziplib_decompresssize },
    { "adler32",        ziplib_adler32        },
    { "crc32",          ziplib_crc32          },
    { NULL,             NULL                  },
};

int luaopen_xzip(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, ziplib_function_list, 0);
    return 1;
}

