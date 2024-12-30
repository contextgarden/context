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

/* 

local function get(t,n)
    local min  = 1
    local max = #t
    while min <= max do
        local mid = min + (max - min) // 2
        if t[mid] == n then
            return mid
        elseif t[mid] < n then
            min = mid + 1
        else
            max = mid - 1
        end
    end
    return nil
end

*/

static int tablib_binsearch(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer val = lua_tointeger(L, 2);
        lua_Unsigned min  = 1;
        lua_Unsigned max = lua_rawlen(L, 1);
        while (min <= max) {
            lua_Unsigned mid = min + (max - min) / 2;
            if (lua_rawgeti(L, 1, mid) == LUA_TNUMBER) {
                lua_Integer tmp = lua_tointeger(L, -1); 
                lua_pop(L, 1);
                if (tmp == val) {
                    lua_pushinteger(L, mid);
                    return 1;
                } else if (tmp < val) {
                    min = mid + 1;
                } else {
                    max = mid - 1;
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static const luaL_Reg tablib_function_list[] = {
    { "getkeys",   tablib_keys      },
    { "binsearch", tablib_binsearch },
    { NULL,        NULL             },
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
