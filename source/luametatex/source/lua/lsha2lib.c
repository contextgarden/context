/*
    See license.txt in the root of this project.
*/

# include <lua.h>
# include <lauxlib.h>

# include "lsha2lib.h"
# include "../luapplib/util/utilsha.h"

# define sha2_body(SHA_DIGEST_LENGTH, calculate) do { \
    if (lua_type(L,1) == LUA_TSTRING) { \
        uint8_t result[SHA_DIGEST_LENGTH]; \
        size_t size = 0; \
        const char *data = lua_tolstring(L,1,&size); \
        calculate(data,size,result); \
        lua_pushlstring(L,(const char *)result,SHA_DIGEST_LENGTH); \
        return 1; \
    } \
    return 0; \
} while (0)

static int sha2_256(lua_State * L) { sha2_body(SHA256_DIGEST_LENGTH,sha256_digest_from); }
static int sha2_384(lua_State * L) { sha2_body(SHA384_DIGEST_LENGTH,sha384_digest_from); }
static int sha2_512(lua_State * L) { sha2_body(SHA512_DIGEST_LENGTH,sha512_digest_from); }

static struct luaL_Reg sha2lib[] = {
    { "digest256", sha2_256 },
    { "digest384", sha2_384 },
    { "digest512", sha2_512 },
    { NULL,        NULL }
};

int luaopen_sha2(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, sha2lib, 0);
    return 1;
}
