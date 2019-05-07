/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

static int get_fontid(void)
{
    if (font_state.font_tables == NULL || font_state.font_tables[0] == NULL) {
        create_null_font();
    }
    return new_font();
}

static int tex_current_font(lua_State * L)
{
    int i = luaL_optinteger(L, 1, 0);
    if (i > 0) {
        if (is_valid_font(i)) {
            set_cur_font(i);
            return 0;
        } else {
            luaL_error(L, "expected a valid font id");
            return 2;
        }
    } else {
        lua_pushinteger(L, cur_font_par);
        return 1;
    }
}

static int tex_max_font(lua_State * L)
{
    lua_pushinteger(L, max_font_id());
    return 1;
}

static int setfont(lua_State * L)
{
    int t = lua_gettop(L);
    int i = luaL_checkinteger(L,1);
    if (i) {
        luaL_checktype(L, t, LUA_TTABLE);
        if (is_valid_font(i)) {
            if (! (font_touched(i))) {
                font_from_lua(L, i);
            } else {
                luaL_error(L, "that font has been accessed already, changing it is forbidden");
            }
        } else {
            luaL_error(L, "that integer id is not a valid font");
        }
    }
    return 0;
}

static int addcharacters(lua_State * L)
{
    int t = lua_gettop(L);
    int i = luaL_checkinteger(L,1);
    if (i) {
        luaL_checktype(L, t, LUA_TTABLE);
        if (is_valid_font(i)) {
            characters_from_lua(L, i);
        } else {
            luaL_error(L, "that integer id is not a valid font");
        }
    }
    return 0;
}

/*tex |font.define(id,table)| or |font.define(table)| */

static int deffont(lua_State * L)
{
    int i = 0;
    int t = lua_gettop(L);
    if (t == 2) {
        i = lua_tointeger(L,1);
        if ((i <= 0) || ! is_valid_font(i)) {
            lua_pop(L, 1);
            luaL_error(L, "font creation failed, invalid id passed");
        }
    } else if (t == 1) {
        i = get_fontid();
    } else {
        luaL_error(L, "font creation failed, no table passed");
        return 0;
    }
    luaL_checktype(L, -1, LUA_TTABLE);
    if (font_from_lua(L, i)) {
        lua_pushinteger(L, i);
        return 1;
    } else {
        lua_pop(L, 1);
        delete_font(i);
        luaL_error(L, "font creation failed, error in table");
    }
    return 0;
}

/*tex

    This returns the expected (!) next |fontid|, a first arg |true| will keep the
    id.

*/

static int nextfontid(lua_State * L)
{
    int b = ((lua_gettop(L) == 1) && lua_toboolean(L,1));
    int i = get_fontid();
    lua_pushinteger(L, i);
    if (b == 0) {
        delete_font(i);
    }
    return 1;
}

static int getfontid(lua_State * L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t ff;
        const char *s = lua_tolstring(L, 1, &ff);
        int cs = string_lookup(s, ff);
        int f = -1;
        if (cs == undefined_control_sequence || cs == undefined_cs_cmd || eq_type(cs) != set_font_cmd) {
            lua_pushstring(L, "not a valid font csname");
        } else {
            f = equiv(cs);
        }
        lua_pushinteger(L, f);
    } else {
        luaL_error(L, "expected font csname string as argument");
    }
    return 1;
}

static const struct luaL_Reg fontlib[] = {
    { "current",       tex_current_font },
    { "max",           tex_max_font },
    { "setfont",       setfont },
    { "addcharacters", addcharacters },
    { "define",        deffont },
    { "nextid",        nextfontid },
    { "id",            getfontid },
    { NULL,            NULL }
};

int luaopen_font(lua_State * L)
{
    lua_newtable(L);
    luaL_setfuncs(L, fontlib, 0);
    return 1;
}
