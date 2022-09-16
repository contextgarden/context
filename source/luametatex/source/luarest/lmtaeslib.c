/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

# include <utilcrypt.h>

// AES_HAS_IV AES_INLINE_IV AES_CONTINUE AES_NULL_PADDING

static const uint8_t nulliv[16] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

typedef size_t aes_coder (
    const void *input,
    size_t      length,
    void       *output,
    const void *key,
    size_t      keylength,
    const void *iv,
    int         flags
);

/* data key [block] [inline] [padding] */ /* key : 16 24 32 */

/* random_bytes is taken from pplib */

static int aeslib_aux_code(lua_State *L, aes_coder code) {
    size_t inputlength = 0;
    const char *input = lua_tolstring(L, 1, &inputlength);
    if (inputlength) {
        size_t keylength = 0;
        const char *key = lua_tolstring(L, 2, &keylength);
        if (keylength == 16 || keylength == 24 || keylength == 32) {
            luaL_Buffer buffer;
            /* always */
            int flags = 0;
            /* the same length as input plus optional 16 from iv */
            char *output = NULL;
            size_t outputlength = 0;
            /* this is optional, iv get copied in aes */
            const uint8_t *iv = NULL;
            switch (lua_type(L, 3)) {
                case LUA_TSTRING:
                    {
                        size_t ivlength = 0;
                        iv = (const uint8_t *) lua_tolstring(L, 3, &ivlength);
                        if (ivlength != 16) {
                            iv = nulliv;
                        }
                        break;
                    }
                case LUA_TBOOLEAN:
                    if (lua_toboolean(L, 3)) {
                        uint8_t randiv[16];
                        random_bytes(randiv, 16);
                        iv = (const uint8_t *) randiv;
                        break;
                    }
                    // fall through
                default:
                    iv = nulliv;
            }
            if (lua_toboolean(L, 4)) {
               flags |= AES_INLINE_IV;
            }
            if (! lua_toboolean(L, 5)) {
               flags |= AES_NULL_PADDING;
            }
            /* always multiples of 16 and we might have the iv too */
            output = luaL_buffinitsize(L, &buffer, inputlength + 32);
            outputlength = code(input, inputlength, output, key, keylength, iv, flags);
            if (outputlength) {
                luaL_pushresultsize(&buffer, outputlength);
                return 1;
            }
        } else {
            luaL_error(L, "aeslib: key of length 16, 24 or 32 expected");
        }
    }
    lua_pushnil(L);
    return 1;
}

static int aeslib_encode(lua_State *L) {
    return aeslib_aux_code(L, &aes_encode_data);
}

static int aeslib_decode(lua_State *L) {
    return aeslib_aux_code(L, &aes_decode_data);
}

static int aeslib_random(lua_State *L) {
    uint8_t iv[32];
    int n = (int) luaL_optinteger(L, 1, 16);
    if (n > 32) {
        n = 32;
    }
    random_bytes(iv, n);
    lua_pushlstring(L, (const char *) iv, n);
    return 1;
}

static struct luaL_Reg aeslib_function_list[] = {
    /*tex We started out with this: */
    { "encode", aeslib_encode },
    { "decode", aeslib_decode },
    { "random", aeslib_random },
    { NULL,     NULL          },
};

int luaopen_aes(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, aeslib_function_list, 0);
    return 1;
}
