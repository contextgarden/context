/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

static int tablib_keys(lua_State *L)
{
    int category = 0; // 0=unknown 1=string 2=number 3=mixed
    lua_settop(L, 1);
    lua_createtable(L, 0, 0);
    if (lua_type(L, 1) == LUA_TTABLE) {
        int index = 0;
        lua_pushnil(L);
        while (lua_next(L, -3)) {
            int tkey = lua_type(L, -2); /* key at -2, value at -1 */
            if (category != 3) {
                if (category == 1) {
                    if (tkey != LUA_TSTRING) {
                         category = 3;
                    }
                } else if (category == 2) {
                    if (tkey != LUA_TNUMBER) {
                        category = 3;
                    }
                } else {
                    if (tkey == LUA_TSTRING) {
                        category = 1;
                    } else if (tkey == LUA_TNUMBER) {
                        category = 2;
                    } else {
                        category = 3;
                    }
                }
            }
            lua_pushvalue(L, -2);
            lua_rawseti(L, 2, ++index);
            lua_pop(L, 1); /* key kept for next iteration */
        }
    }
    lua_pushinteger(L, category);
    return 2; 
}

static const luaL_Reg tablib_function_list[] = {
    { "getkeys", tablib_keys },
    { NULL,      NULL        },
};

int luaextend_table(lua_State * L)
{
    lua_getglobal(L, "table");
    for (const luaL_Reg *lib = tablib_function_list; lib->name; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);
    return 1;
}
