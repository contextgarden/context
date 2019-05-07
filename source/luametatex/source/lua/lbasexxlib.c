/*
    See license.txt in the root of this project.
*/

# include <stdlib.h>

# include <lua.h>
# include <lauxlib.h>

/* # define BASEXX_PDF 1 */

# include "lbasexxlib.h"
# include "../luapplib/util/utiliof.h"
# include "../luapplib/util/utilbasexx.h"
# include "../luapplib/util/utillzw.h"

/*tex

    First I had a mix of own code and LHF code (base64 and base85) but in the
    end I decided to reuse some of pplibs code. Performance is ok, although we
    can speed up the base16 coders.

    When needed, we can have a few more bur normally pure \LUA\ is quite ok
    for our purpose.

*/

# define encode_nl(L) \
    (lua_type(L,2) == LUA_TNUMBER) ? (lua_tointeger(L,2)) : ( (lua_isboolean(L,2)) ? 80 : 0 )

# define lua_iof_push(L,out) \
    lua_pushlstring(L,(const char *) out->buf, iof_size(out))

static int encode_16(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    int n = 2 * l;
    int nl = encode_nl(L);
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    if (nl) {
        base16_encode_ln(inp,out,0,nl);
    } else {
        base16_encode(inp,out);
    }
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int decode_16(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    int n = l / 2;
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    base16_decode(inp,out);
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int encode_64(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    int n = 4 * l;
    int nl = encode_nl(L);
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

static int decode_64(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    int n = l;
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    base64_decode(inp,out);
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int encode_85(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = 5 * l;
    int nl = encode_nl(L);
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    if (nl) {
        base85_encode_ln(inp,out,0,80);
    } else {
        base85_encode(inp,out);
    }
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int decode_85(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = l;
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    base85_decode(inp,out);
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int encode_RL(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = 2 * l;
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    runlength_encode(inp,out);
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int decode_RL(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = 2 * l;
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    runlength_decode(inp,out);
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static int encode_LZW(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = 2 * l;
    char *t = malloc(n);
    int flags = luaL_optinteger(L, 2, LZW_ENCODER_DEFAULTS);
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_string_writer(t,n);
    lzw_encode(inp,out,flags);
    lua_pushlstring(L,t,iof_size(out));
    free(t);
    return 1;
}

static int decode_LZW(lua_State * L)
{
    size_t l;
    const unsigned char *s = (const unsigned char*) luaL_checklstring(L,1,&l);
    size_t n = 2 * l;
    iof *inp = iof_filter_string_reader(s,l);
    iof *out = iof_filter_buffer_writer(n);
    int flags = luaL_optinteger(L, 2, LZW_DECODER_DEFAULTS);
    lzw_decode(inp,out,flags);
    lua_iof_push(L,out);
    iof_close(out);
    return 1;
}

static struct luaL_Reg basexxlib[] = {
    { "encode16",  encode_16 },
    { "decode16",  decode_16 },
    { "encode64",  encode_64 },
    { "decode64",  decode_64 },
    { "encode85",  encode_85 },
    { "decode85",  decode_85 },
    { "encodeRL",  encode_RL },
    { "decodeRL",  decode_RL },
    { "encodeLZW", encode_LZW },
    { "decodeLZW", decode_LZW },
    { NULL,        NULL }
};

int luaopen_basexx(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, basexxlib, 0);
    return 1;
}
