/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

typedef struct bitset {
    int           max;
    int           padding;
    unsigned char set[1];
} bitset;

static bitset *bitsetlib_aux_check_is_valid(lua_State *L, int n)
{
    bitset *o = (bitset *) lua_touserdata(L, n);
    if (o && lua_getmetatable(L, n)) {
        lua_get_metatablelua(bitset_instance);
        if (! lua_rawequal(L, -1, -2)) {
            o = NULL;
        }
        lua_pop(L, 2);
        if (o) {
            return o;
        }
    }
    tex_normal_warning("bitset lib", "lua <bitset> expected");
    return NULL;
}

static int bitsetlib_new(lua_State *L)
{
    int max = lmt_optinteger(L, 1, 64);
    bitset *b = lua_newuserdatauv(L, sizeof(bitset) + (max + 1) / 8, 0);
    if (b) {
        luaL_setmetatable(L, BITSET_METATABLE_INSTANCE);
        b->max = max;
        memset(&(b->set[0]), 0, (max + 1) / 8);
        return 1;
    } else {
        return 0;
    }
}

static int bitsetlib_tostring(lua_State *L) {
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        lua_pushfstring(L, "<bitset %p : %d>", b->set, b->max);
        return 1;
    } else {
        return 0;
    }
}

static int bitsetlib_set(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        int i = lmt_tointeger(L, 2);
        if (i > 0 && i <= b->max) {
            b->set[i/8] += 1 << (i % 8); // |
        }
    }
    return 0;
}

static int bitsetlib_reset(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        int i = lmt_tointeger(L, 2);
        if (i > 0 && i <= b->max) {
            b->set[i/8] &= ~(1 << (i % 8));
        }
    }
    return 0;
}

static int bitsetlib_get(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        int i = lmt_tointeger(L, 2);
        if (i > 0 && i <= b->max) {
            lua_pushboolean(L, (b->set[i/8] & (1 << (i % 8))) != 0);
            return 1;
        }
    }
    return 0;
}

static int bitsetlib_wipe(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        memset(&(b->set[0]), 0, (b->max + 1) / 8);
    }
    return 0;
}

static int bitsetlib_aux_nil(lua_State *L)
{
    lua_pushnil(L);
    return 1;
}

static int bitsetlib_aux_next(lua_State *L)
{
    bitset *b = (bitset *) lua_touserdata(L, lua_upvalueindex(1));
    int how = lmt_tointeger(L, lua_upvalueindex(2));
    int ind = lmt_tointeger(L, lua_upvalueindex(3));
    while (ind <= b->max) {
        int val = (b->set[ind/8] & (1 << (ind % 8))) != 0;
        switch (how) {
            case 2:
                if (val) {
                    ind += 1;
                    continue;
                }
                break;
            case 1:
                if (! val) {
                    ind += 1;
                    continue;
                }
                break;
        }
        lua_pushinteger(L, (lua_Integer) ind + 1);
        lua_replace(L, lua_upvalueindex(3));
        lua_pushinteger(L, ind);
        if (how) {
            return 1;
        } else {
            lua_pushboolean(L, val);
            return 2;

        }
    }
    return 0;
}

static int bitsetlib_traverse(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        int how = lua_type(L, 2) == LUA_TBOOLEAN ? (lua_toboolean(L, 2) ? 1 : 2) : 0;
        lua_settop(L, 1);
        lua_pushinteger(L, how);
        lua_pushinteger(L, 1);
        lua_pushcclosure(L, bitsetlib_aux_next, 3);
    } else {
        lua_pushcclosure(L, bitsetlib_aux_nil, 0);
    }
    return 1;
}

static int bitsetlib_asstring(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        luaL_Buffer buffer;
        int step = lmt_optinteger(L, 2, b->max + 1);
        int n = 0;
        luaL_buffinitsize(L, &buffer, b->max + b->max / step);
        for (int i = 1; i <= b->max; i++) {
            int val = (b->set[i/8] & (1 << (i % 8))) != 0;
            if (n >= step) {
                luaL_addchar(&buffer, ' ');
                n = 1;
            } else {
                n++;
            }
            luaL_addchar(&buffer, val ? '1' : '0');
        }
        luaL_pushresult(&buffer);
        return 1;
    } else {
        return 0;
    }
}

static int bitsetlib_totable(lua_State *L)
{
    bitset *b = bitsetlib_aux_check_is_valid(L, 1);
    if (b) {
        lua_createtable(L, b->max, 0);
        for (int i = 1; i <= b->max; i++) {
            lua_pushboolean(L, (b->set[i/8] & (1 << (i % 8))) != 0);
            lua_rawseti(L, -2, i);
        }
        return 1;
    } else {
        return 0;
    }
}

static const struct luaL_Reg bitsetlib_instance[] = {
    { "__tostring", bitsetlib_tostring },
    { "__index",    bitsetlib_get      },
    { "__newindex", bitsetlib_set      },
 // { "__bor",      bitsetlib_bor      },
 // { "__band",     bitsetlib_band     },
 // { "__bxor",     bitsetlib_bxor     },
    { NULL,         NULL               },
};

static const luaL_Reg bitsetlib_function_list[] = {
    { "new",      bitsetlib_new      },
    { "set",      bitsetlib_set      },
    { "reset",    bitsetlib_reset    },
    { "get",      bitsetlib_get      },
    { "wipe",     bitsetlib_wipe     },
    { "asstring", bitsetlib_asstring },
    { "totable",  bitsetlib_totable  },
    { "traverse", bitsetlib_traverse },
    { NULL,       NULL               },
};

int luaopen_bitset(lua_State *L)
{
    luaL_newmetatable(L, BITSET_METATABLE_INSTANCE);
    luaL_setfuncs(L, bitsetlib_instance, 0);
    lua_newtable(L);
    luaL_setfuncs(L, bitsetlib_function_list, 0);
    return 1;
}
