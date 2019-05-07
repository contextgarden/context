/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

# define LANG_METATABLE "luatex.lang"

# define check_islang(L,b) (struct tex_language **)luaL_checkudata(L,b,LANG_METATABLE)

static int lang_new(lua_State * L)
{
    struct tex_language **lang;
    if (lua_gettop(L) == 0) {
        lang = lua_newuserdata(L, sizeof(struct tex_language *));
        *lang = new_language(-1);
        if (!*lang) {
            return luaL_error(L, "lang.new(): no room for a new language");
        }
    } else {
        int lualang;
        lang = lua_newuserdata(L, sizeof(struct tex_language *));
        lualang = lua_tointeger(L, 1);
        *lang = get_language(lualang);
        if (!*lang) {
            return luaL_error(L, "lang.new(%d): undefined language", lualang);
        }
    }
    luaL_getmetatable(L, LANG_METATABLE);
    lua_setmetatable(L, -2);
    return 1;
}

static int lang_id(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    lua_pushinteger(L, (*lang_ptr)->id);
    return 1;
}

static int lang_patterns(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TSTRING) {
            return luaL_error(L, "lang.patterns(): argument should be a string");
        }
        load_patterns(*lang_ptr, (const unsigned char *) lua_tostring(L, 2));
        return 0;
    } else {
        if ((*lang_ptr)->patterns != NULL) {
            lua_pushstring(L, (char *) hnj_serialize((*lang_ptr)->patterns));
        } else {
            lua_pushnil(L);
        }
        return 1;
    }
}

static int lang_clear_patterns(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    clear_patterns(*lang_ptr);
    return 0;
}

static int lang_hyphenation(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TSTRING) {
            return luaL_error(L, "lang.hyphenation(): argument should be a string");
        }
        load_hyphenation(*lang_ptr, (const unsigned char *) lua_tostring(L, 2));
        return 0;
    } else {
        if ((*lang_ptr)->exceptions != 0) {
            lua_pushstring(L, exception_strings(*lang_ptr));
        } else {
            lua_pushnil(L);
        }
        return 1;
    }
}

static int lang_pre_hyphen_char(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TNUMBER) {
            return luaL_error(L, "lang.prehyphenchar(): argument should be a character number");
        }
        (*lang_ptr)->pre_hyphen_char = (int) lua_tointeger(L, 2);
        return 0;
    } else {
        lua_pushinteger(L, (*lang_ptr)->pre_hyphen_char);
        return 1;
    }
}

static int lang_post_hyphen_char(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TNUMBER) {
            return luaL_error(L, "lang.posthyphenchar(): argument should be a character number");
        }
        (*lang_ptr)->post_hyphen_char = (int) lua_tointeger(L, 2);
        return 0;
    } else {
        lua_pushinteger(L, (*lang_ptr)->post_hyphen_char);
        return 1;
    }
}

static int lang_pre_exhyphen_char(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TNUMBER) {
            return luaL_error(L, "lang.preexhyphenchar(): argument should be a character number");
        }
        (*lang_ptr)->pre_exhyphen_char = (int) lua_tointeger(L, 2);
        return 0;
    } else {
        lua_pushinteger(L, (*lang_ptr)->pre_exhyphen_char);
        return 1;
    }
}

static int lang_sethjcode(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_type(L, 2) != LUA_TNUMBER) {
        return luaL_error(L, "lang.sethjcode(): argument should be a character number");
    } else {
        int i = (int) lua_tointeger(L, 2) ;
        if (lua_type(L, 3) == LUA_TNUMBER) {
            set_hj_code((*lang_ptr)->id,i,(int) lua_tointeger(L, 3),-1);
        } else {
            set_hj_code((*lang_ptr)->id,i,i,-1);
        }
    }
    return 0;
}

static int lang_gethjcode(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_type(L, 2) != LUA_TNUMBER) {
        return luaL_error(L, "lang.gethjcode(): argument should be a character number");
    } else {
        lua_pushinteger(L, get_hj_code((*lang_ptr)->id,lua_tointeger(L, 2)));
    }
    return 1;
}

static int lang_post_exhyphen_char(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TNUMBER) {
            return luaL_error(L, "lang.postexhyphenchar(): argument should be a character number");
        }
        (*lang_ptr)->post_exhyphen_char = (int) lua_tointeger(L, 2);
        return 0;
    } else {
        lua_pushinteger(L, (*lang_ptr)->post_exhyphen_char);
        return 1;
    }
}

static int lang_hyphenation_min(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    if (lua_gettop(L) != 1) {
        if (lua_type(L, 2) != LUA_TNUMBER) {
            return luaL_error(L, "lang.hyphenationmin(): argument should be a number");
        }
        (*lang_ptr)->hyphenation_min = (int) lua_tointeger(L, 2);
        return 0;
    } else {
        lua_pushinteger(L, (*lang_ptr)->hyphenation_min);
        return 1;
    }
}

static int lang_clear_hyphenation(lua_State * L)
{
    struct tex_language **lang_ptr;
    lang_ptr = check_islang(L, 1);
    clear_hyphenation(*lang_ptr);
    return 0;
}

static int do_lang_clean(lua_State * L)
{
    char *cleaned;
    if (lua_type(L, 1) == LUA_TSTRING) {
        (void) clean_hyphenation(cur_lang_par, lua_tostring(L, 1), &cleaned);
    } else {
        struct tex_language **lang_ptr;
        lang_ptr = check_islang(L, 1);
        if (lang_ptr == NULL) {
            return luaL_error(L, "lang.clean(): first argument should be a string or language");
        } else if (lua_type(L, 2) != LUA_TSTRING) {
            return luaL_error(L, "lang.clean(): second argument should be a string");
        } else {
            (void) clean_hyphenation((*lang_ptr)->id,lua_tostring(L, 2), &cleaned);
        }
    }
    lua_pushstring(L, cleaned);
    return 1;
}

/*
static int do_lang_hyphenate(lua_State * L)
{
    halfword *h, *t, tt;
    h = check_isnode(L, 1);
    if (lua_isuserdata(L, 2)) {
        t = check_isnode(L, 2);
        tt = *t;
        lua_pop(L, 1);
    } else {
        tt = *h;
        while (vlink(tt))
            tt = vlink(tt);
    }
    hnj_hyphenation(*h, tt);
    lua_pushboolean(L, 1);
    return 1;
}
*/

static int do_lang_hyphenate(lua_State * L)
{
    halfword t = null;
    halfword h = *check_isnode(L, 1);
    if (lua_isuserdata(L, 2)) {
        t = *check_isnode(L, 2);
    }
    if (!t) {
        t = h;
        while (vlink(t)) {
            t = vlink(t);
        }
    }
    hnj_hyphenation(h, t);
    lua_nodelib_push_fast(L, h);
    lua_nodelib_push_fast(L, t);
    lua_pushboolean(L, 1);
    return 3;
}

static int lang_has_language(lua_State * L)
{
    halfword h = *check_isnode(L, 1);
    while (h) {
        if (type(h) == glyph_node && char_lang(h) > 0) {
            lua_pushboolean(L,1);
            return 1;
        }
        h = vlink(h);
    }
    lua_pushboolean(L,0);
    return 1;
}

static const struct luaL_Reg langlib_d[] = {
    { "clear_patterns",    lang_clear_patterns },
    { "clear_hyphenation", lang_clear_hyphenation },
    { "patterns",          lang_patterns },
    { "hyphenation",       lang_hyphenation },
    { "prehyphenchar",     lang_pre_hyphen_char },
    { "posthyphenchar",    lang_post_hyphen_char },
    { "preexhyphenchar",   lang_pre_exhyphen_char },
    { "postexhyphenchar",  lang_post_exhyphen_char },
    { "hyphenationmin",    lang_hyphenation_min },
    { "sethjcode",         lang_sethjcode },
    { "gethjcode",         lang_gethjcode },
    { "id",                lang_id },
    { NULL,                NULL }
};

static const struct luaL_Reg langlib[] = {
    { "clear_patterns",    lang_clear_patterns },
    { "clear_hyphenation", lang_clear_hyphenation },
    { "patterns",          lang_patterns },
    { "hyphenation",       lang_hyphenation },
    { "prehyphenchar",     lang_pre_hyphen_char },
    { "posthyphenchar",    lang_post_hyphen_char },
    { "preexhyphenchar",   lang_pre_exhyphen_char },
    { "postexhyphenchar",  lang_post_exhyphen_char },
    { "hyphenationmin",    lang_hyphenation_min },
    { "sethjcode",         lang_sethjcode },
    { "gethjcode",         lang_gethjcode },
    { "id",                lang_id },
    { "clean",             do_lang_clean },
    { "has_language",      lang_has_language },
    { "hyphenate",         do_lang_hyphenate },
    { "new",               lang_new },
    { NULL,                NULL }
};

int luaopen_lang(lua_State * L)
{
    luaL_newmetatable(L, LANG_METATABLE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, langlib_d, 0);
    lua_newtable(L);
    luaL_setfuncs(L, langlib, 0);
    return 1;
}
