/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/* # define BASEXX_PDF 1 */

# include <utiliof.h>
# include <utilbasexx.h>
# include <utillzw.h>

/*tex

    First I had a mix of own code and LHF code (base64 and base85) but in the end I decided to reuse
    some of pplibs code. Performance is ok, although we can speed up the base16 coders. When needed,
    we can have a few more bur normally pure \LUA\ is quite ok for our purpose.

*/

# define encode_nl(L) \
    (lua_type(L, 2) == LUA_TNUMBER) ? (lmt_tointeger(L, 2)) : ( (lua_isboolean(L, 2)) ? 80 : 0 )

# define lua_iof_push(L,out) \
    lua_pushlstring(L,(const char *) out->buf, iof_size(out))

static int basexxlib_encode_16(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = 2 * l;
    size_t nl = encode_nl(L);
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    if (nl) {
        base16_encode_ln(inp, out, 0, nl);
    } else {
        base16_encode(inp, out);
    }
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static int basexxlib_decode_16(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = l / 2;
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    base16_decode(inp, out);
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static int basexxlib_encode_64(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = 4 * l;
    size_t nl = encode_nl(L);
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    if (nl) {
        base64_encode_ln(inp,out,0,nl);
    } else {
        base64_encode(inp,out);
    }
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int basexxlib_decode_64(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = l;
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    base64_decode(inp, out);
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static int basexxlib_encode_85(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = 5 * l;
    size_t nl = encode_nl(L);
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    if (nl) {
        base85_encode_ln(inp, out, 0, 80);
    } else {
        base85_encode(inp, out);
    }
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int basexxlib_decode_85(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = l;
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    base85_decode(inp, out);
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static int basexxlib_encode_RL(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = 2 * l;
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    runlength_encode(inp, out);
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static int basexxlib_decode_RL(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = 2 * l;
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    runlength_decode(inp, out);
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static int basexxlib_encode_LZW(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = 2 * l;
    char *t = lmt_memory_malloc(n);
    int flags = lmt_optinteger(L, 2, LZW_ENCODER_DEFAULTS);
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_string_writer(t, n);
    lzw_encode(inp, out, flags);
    lua_pushlstring(L, t, iof_size(out));
    lmt_memory_free(t);
    return 1;
}

static int basexxlib_decode_LZW(lua_State *L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L, 1, &l);
    size_t n = 2 * l;
    iof *inp = iof_filter_string_reader(s, l);
    iof *out = iof_filter_buffer_writer(n);
    int flags = lmt_optinteger(L, 2, LZW_DECODER_DEFAULTS);
    lzw_decode(inp, out, flags);
    lua_iof_push(L, out);
    iof_close(out);
    return 1;
}

static struct luaL_Reg basexxlib_function_list[] = {
    { "encode16",  basexxlib_encode_16  },
    { "decode16",  basexxlib_decode_16  },
    { "encode64",  basexxlib_encode_64  },
    { "decode64",  basexxlib_decode_64  },
    { "encode85",  basexxlib_encode_85  },
    { "decode85",  basexxlib_decode_85  },
    { "encodeRL",  basexxlib_encode_RL  },
    { "decodeRL",  basexxlib_decode_RL  },
    { "encodeLZW", basexxlib_encode_LZW },
    { "decodeLZW", basexxlib_decode_LZW },
    { NULL,        NULL                 },
};

int luaopen_basexx(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, basexxlib_function_list, 0);
    return 1;
}
