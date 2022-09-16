/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

# include <utilsha.h>

# define SHA256_RESULT_LENGTH (SHA256_STRING_LENGTH-1)
# define SHA384_RESULT_LENGTH (SHA384_STRING_LENGTH-1)
# define SHA512_RESULT_LENGTH (SHA512_STRING_LENGTH-1)

# define sha2_body(SHA_DIGEST_LENGTH, SHA_CALCULATE, CONVERSION, SHA_RESULT_LENGTH) do { \
    if (lua_type(L, 1) == LUA_TSTRING) { \
        uint8_t result[SHA_DIGEST_LENGTH]; \
        size_t size = 0; \
        const char *data = lua_tolstring(L, 1, &size); \
        SHA_CALCULATE(data, size, result, CONVERSION); \
        lua_pushlstring(L, (const char *) result, SHA_RESULT_LENGTH); \
        return 1; \
    } \
    return 0; \
} while (0)

static int sha2lib_256_sum(lua_State *L) { sha2_body(SHA256_DIGEST_LENGTH, sha256_digest, SHA_BYTES, SHA256_DIGEST_LENGTH); }
static int sha2lib_384_sum(lua_State *L) { sha2_body(SHA384_DIGEST_LENGTH, sha384_digest, SHA_BYTES, SHA384_DIGEST_LENGTH); }
static int sha2lib_512_sum(lua_State *L) { sha2_body(SHA512_DIGEST_LENGTH, sha512_digest, SHA_BYTES, SHA512_DIGEST_LENGTH); }
static int sha2lib_256_hex(lua_State *L) { sha2_body(SHA256_STRING_LENGTH, sha256_digest, SHA_LCHEX, SHA256_RESULT_LENGTH); }
static int sha2lib_384_hex(lua_State *L) { sha2_body(SHA384_STRING_LENGTH, sha384_digest, SHA_LCHEX, SHA384_RESULT_LENGTH); }
static int sha2lib_512_hex(lua_State *L) { sha2_body(SHA512_STRING_LENGTH, sha512_digest, SHA_LCHEX, SHA512_RESULT_LENGTH); }
static int sha2lib_256_HEX(lua_State *L) { sha2_body(SHA256_STRING_LENGTH, sha256_digest, SHA_UCHEX, SHA256_RESULT_LENGTH); }
static int sha2lib_384_HEX(lua_State *L) { sha2_body(SHA384_STRING_LENGTH, sha384_digest, SHA_UCHEX, SHA384_RESULT_LENGTH); }
static int sha2lib_512_HEX(lua_State *L) { sha2_body(SHA512_STRING_LENGTH, sha512_digest, SHA_UCHEX, SHA512_RESULT_LENGTH); }

static struct luaL_Reg sha2lib_function_list[] = {
    /*tex We started out with this: */
    { "digest256", sha2lib_256_sum },
    { "digest384", sha2lib_384_sum },
    { "digest512", sha2lib_512_sum },
    /*tex The next is consistent with |md5lib|: */
    { "sum256",    sha2lib_256_sum },
    { "sum384",    sha2lib_384_sum },
    { "sum512",    sha2lib_512_sum },
    { "hex256",    sha2lib_256_hex },
    { "hex384",    sha2lib_384_hex },
    { "hex512",    sha2lib_512_hex },
    { "HEX256",    sha2lib_256_HEX },
    { "HEX384",    sha2lib_384_HEX },
    { "HEX512",    sha2lib_512_HEX },
    { NULL,        NULL            },
};

int luaopen_sha2(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, sha2lib_function_list, 0);
    return 1;
}
