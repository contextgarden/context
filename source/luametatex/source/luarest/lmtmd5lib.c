/*
    See license.txt in the root of this project.
*/

# include <ctype.h>

# include <utilmd5.h>
# include <utiliof.h>
# include <utilbasexx.h>

# include "luametatex.h"

/*
# define wrapped_md5(message,len,output) md5_digest(message,len,(unsigned char *) output, 0)

static int md5lib_sum(lua_State *L)
{
    char buf[16];
    size_t l;
    const char *message = luaL_checklstring(L, 1, &l);
    wrapped_md5(message, l, buf);
    lua_pushlstring(L, buf, 16L);
    return 1;
}

static int md5lib_hex(lua_State *L)
{
    char buf[16];
    char hex[32];
    iof *inp = iof_filter_string_reader(buf, 16);
    iof *out = iof_filter_string_writer(hex, 32);
    size_t l;
    const char *message = luaL_checklstring(L, 1, &l);
    wrapped_md5(message, l, buf);
    base16_encode_lc(inp, out);
    lua_pushlstring(L, hex, iof_size(out));
    iof_free(inp);
    iof_free(out);
    return 1;
}

static int md5lib_HEX(lua_State *L)
{
    char buf[16];
    char hex[32];
    iof *inp = iof_filter_string_reader(buf, 16);
    iof *out = iof_filter_string_writer(hex, 32);
    size_t l;
    const char *message = luaL_checklstring(L, 1, &l);
    wrapped_md5(message, l, buf);
    base16_encode_uc(inp, out);
    lua_pushlstring(L, hex, iof_size(out));
    iof_free(inp);
    iof_free(out);
    return 1;
}
*/

# define MD5_RESULT_LENGTH (MD5_STRING_LENGTH-1)

# define md5_body(MD5_LENGTH, CONVERSION, RESULT_LENGTH) do { \
    if (lua_type(L, 1) == LUA_TSTRING) { \
        uint8_t result[MD5_LENGTH]; \
        size_t size = 0; \
        const char *data = lua_tolstring(L, 1, &size); \
        md5_digest(data, size, (unsigned char *) result, CONVERSION); \
        lua_pushlstring(L, (const char *) result, RESULT_LENGTH); \
        return 1; \
    } \
    return 0; \
} while (0)

static int md5lib_sum(lua_State *L) { md5_body(MD5_DIGEST_LENGTH, MD5_BYTES, MD5_DIGEST_LENGTH); }
static int md5lib_hex(lua_State *L) { md5_body(MD5_STRING_LENGTH, MD5_LCHEX, MD5_RESULT_LENGTH); }
static int md5lib_HEX(lua_State *L) { md5_body(MD5_STRING_LENGTH, MD5_UCHEX, MD5_RESULT_LENGTH); }

static struct luaL_Reg md5lib_function_list[] = {
    { "sum", md5lib_sum },
    { "hex", md5lib_hex },
    { "HEX", md5lib_HEX },
    { NULL,  NULL       },
};

int luaopen_md5(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, md5lib_function_list, 0);
    return 1;
}
