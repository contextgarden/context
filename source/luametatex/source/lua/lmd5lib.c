/*
    See license.txt in the root of this project.
*/

# include "lmd5lib.h"
# include "../luapplib/util/utilmd5.h"
# include "../luapplib/util/utiliof.h"
# include "../luapplib/util/utilbasexx.h"

# include <lua.h>
# include <lauxlib.h>

# define wrapped_md5(message,len,output) md5_digest_from(message,len,(unsigned char *) output)

static int md5_sum(lua_State *L)
{
    char buf[16];
    size_t l;
    const char *message = luaL_checklstring(L, 1, &l);
    wrapped_md5(message, l, buf);
    lua_pushlstring(L, buf, 16L);
    return 1;
}

static int md5_hex(lua_State *L)
{
    char buf[16];
    char hex[32];
    iof *inp = iof_filter_string_reader(buf,16);
    iof *out = iof_filter_string_writer(hex,32);
    size_t l;
    const char *message = luaL_checklstring(L, 1, &l);
    wrapped_md5(message, l, buf);
    base16_encode_lc(inp,out);
    lua_pushlstring(L,hex,iof_size(out));
    return 1;
}

static int md5_HEX(lua_State *L)
{
    char buf[16];
    char hex[32];
    iof *inp = iof_filter_string_reader(buf,16);
    iof *out = iof_filter_string_writer(hex,32);
    size_t l;
    const char *message = luaL_checklstring(L, 1, &l);
    wrapped_md5(message, l, buf);
    base16_encode_uc(inp,out);
    lua_pushlstring(L,hex,iof_size(out));
    return 1;
}

static struct luaL_Reg md5lib[] = {
    { "sum", md5_sum },
    { "hex", md5_hex },
    { "HEX", md5_HEX },
    { NULL,  NULL }
};

int luaopen_md5(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, md5lib, 0);
    return 1;
}
