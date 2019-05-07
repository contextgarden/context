/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

lua_state_info lua_state;

typedef struct LoadS {
    char *s;
    size_t size;
} LoadS;

void make_table(lua_State * L, const char *tab, const char *mttab, const char *getfunc, const char *setfunc)
{
    lua_pushstring(L, tab);           /*tex |[{<tex>},"dimen"]| */
    lua_newtable(L);                  /*tex |[{<tex>},"dimen",{}]| */
    lua_settable(L, -3);              /*tex |[{<tex>}]| */
    lua_pushstring(L, tab);           /*tex |[{<tex>},"dimen"]| */
    lua_gettable(L, -2);              /*tex |[{<tex>},{<dimen>}]| */
    luaL_newmetatable(L, mttab);      /*tex |[{<tex>},{<dimen>},{<dimen_m>}]| */
    lua_pushstring(L, "__index");     /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__index"]| */
    lua_pushstring(L, getfunc);       /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__index","getdimen"]| */
    lua_gettable(L, -5);              /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__index",<tex.getdimen>]| */
    lua_settable(L, -3);              /*tex |[{<tex>},{<dimen>},{<dimen_m>}]| */
    lua_pushstring(L, "__newindex");  /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__newindex"]| */
    lua_pushstring(L, setfunc);       /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__newindex","setdimen"]| */
    lua_gettable(L, -5);              /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__newindex",<tex.setdimen>]| */
    lua_settable(L, -3);              /*tex |[{<tex>},{<dimen>},{<dimen_m>}]| */
    lua_setmetatable(L, -2);          /*tex |[{<tex>},{<dimen>}]| : assign the metatable */
    lua_pop(L, 1);                    /*tex |[{<tex>}]| : clean the stack */
}

static const char *getS(lua_State * L, void *ud, size_t * size)
{
    LoadS *ls = (LoadS *) ud;
    (void) L;
    if (ls->size > 0) {
        *size = ls->size;
        ls->size = 0;
        return ls->s;
    } else {
        return NULL;
    }
}

static void *my_luaalloc(void *ud, void *ptr, size_t osize, size_t nsize)
{
    void *ret = NULL;
    (void) ud;
    if (nsize == 0) {
        free(ptr);
    } else {
        ret = realloc(ptr, nsize);
    }
    lua_state.used_bytes += (int) (nsize - osize);
    return ret;
}

static int my_luapanic(lua_State * L)
{
    (void) L;
    fprintf(stderr, "panic: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1));
    return 0;
}

void luafunctioncall(int slot)
{
    int i ;
    int stacktop = lua_gettop(Luas);
    lua_rawgeti(Luas, LUA_REGISTRYINDEX, lua_state.function_table_id);
    lua_pushcfunction(Luas, lua_traceback);
    lua_rawgeti(Luas, -2, slot);
    if (lua_isfunction(Luas,-2)) {
        /*tex function index */
        lua_pushinteger(Luas, slot);
        ++lua_state.function_callback_count;
        i = lua_pcall(Luas, 1, 0, stacktop+2);
        if (i != 0) {
            lua_remove(Luas, stacktop+2);
            luatex_error(Luas, (i == LUA_ERRRUN ? 0 : 1));
        }
    }
    lua_settop(Luas,stacktop);
}

static const luaL_Reg lualibs[] = {
    { "_G",        luaopen_base },
    { "package",   luaopen_package },
    { "table",     luaopen_table },
    { "io",        luaopen_io },
    { "os",        luaopen_os },
    { "string",    luaopen_string },
    { "math",      luaopen_math },
    { "debug",     luaopen_debug },
    { "lpeg",      luaopen_lpeg },
    { "utf8",      luaopen_utf8 },
    { "coroutine", luaopen_coroutine },
    { "ffi",       luaopen_ffi },
    { NULL,        NULL }
};

static const luaL_Reg extralibs[] = {
    { "md5",      luaopen_md5 },
    { "sha2",     luaopen_sha2 },
    { "basexx",   luaopen_basexx },
    { "flate",    luaopen_flate },
    { "lfs",      luaopen_filelib }, /* for practical reasons we keep this namespace */
    { "fio",      luaopen_fio },
    { "sio",      luaopen_sio },
    { "gzip",     luaopen_gzip },
    { "zlib",     luaopen_zlib },
    { "xmath",    luaopen_xmath },
    { "xcomplex", luaopen_xcomplex },
    { NULL,       NULL }
};

static const luaL_Reg socketlibs[] = {
    { "socket", luaopen_socket_core },
    { "mime",   luaopen_mime_core },
    { NULL,     NULL }
};

static const luaL_Reg morelibs[] = {
    { "lua",      luaopen_lua },
    { "status",   luaopen_stats },
    { "texio",    luaopen_texio },
    { NULL,       NULL }
};

static const luaL_Reg texlibs[] = {
    { "tex",      luaopen_tex },
    { "token",    luaopen_token },
    { "node",     luaopen_node },
    { "callback", luaopen_callback },
    { "font",     luaopen_font },
    { "lang",     luaopen_lang },
    { NULL,       NULL }
};

static const luaL_Reg mplibs[] = {
    { "mplib", luaopen_mplib },
    { NULL,    NULL }
};

static const luaL_Reg pdflibs[] = {
    { "pdfe",       luaopen_pdfe },
    { "pdfdecode",  luaopen_pdfdecode },
    { "pngdecode",  luaopen_pngdecode },
    { "pdfscanner", luaopen_pdfscanner },
    { NULL,         NULL }
};

static void luaopen_liblist(lua_State * L, const luaL_Reg *lib)
{
    for (; lib->func; lib++) {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_setglobal(L,lib->name);
    }
}

void initialize_lua(void)
{
    lua_State *L = lua_newstate(my_luaalloc, NULL);
    if (L == NULL) {
        fprintf(stderr, "Can't create the Lua state.\n");
        return;
    }
    /*tex By default we use the generational garbage collector. */
# ifdef _WIN32
    lua_gc(L, LUA_GCGEN, 0, 0);
# endif
    /* */
    lua_state.bytecode_max = -1;
    lua_state.bytecode_bytes = 0;
    /* */
    lua_atpanic(L, &my_luapanic);
    /*tex This initializes all the 'simple' libraries: */
    luaopen_liblist(L,lualibs);
    /*tex This initializes all the 'extra' libraries: */
    luaopen_liblist(L,extralibs);
    /*tex These are special: we extend them. */
    luaextend_os(L);
    luaextend_string(L);
    /*tex Loading the socket library is a bit odd (old stuff). */
    luaopen_liblist(L,socketlibs);
    /*tex This initializes the 'tex' related libraries that have some luaonly functionality */
    luaopen_liblist(L,morelibs);
    /*tex This initializes the 'tex' related libraries. */
    if (! engine_state.lua_only) {
        luaopen_liblist(L,texlibs);
    }
    /*tex This initializes the 'metapost' related libraries. */
    luaopen_liblist(L,mplibs);
    /*tex This initializes the 'pdf' related libraries. */
    luaopen_liblist(L,pdflibs);
    /*tex We're nearly done! In this table we're going to put some info: */
    lua_createtable(L, 0, 0);
    lua_setglobal(L, "texconfig");
    Luas = L;
}

int lua_traceback(lua_State * L)
{
    lua_getglobal(L, "debug");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return 1;
    }
    lua_getfield(L, -1, "traceback");
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return 1;
    }
    /*tex pass error message */
    lua_pushvalue(L, 1);
    /*tex skip this function and traceback */
    lua_pushinteger(L, 2);
    /*tex call |debug.traceback| */
    lua_call(L, 2, 1);
    return 1;
}

void luatokencall(int p)
{
    LoadS ls;
    int l = 0;
//    char *s = tokenlist_to_cstring(p, 1, &l);
//    ls.s = s;
    ls.s = tokenlist_to_tstring(p, 1, &l);
    ls.size = (size_t) l;
    if (ls.size > 0) {
        int top = lua_gettop(Luas);
        int i;
        lua_pushcfunction(Luas, lua_traceback);
        i = lua_load(Luas, getS, &ls, "=[\\directlua]",NULL);
//        free(s);
        if (i != 0) {
            luatex_error(Luas, (i == LUA_ERRSYNTAX ? 0 : 1));
        } else {
            lua_checkstack(Luas, 1);
            ++lua_state.direct_callback_count;
            i = lua_pcall(Luas, 0, 0, top+1);
            if (i != 0) {
                lua_remove(Luas, top+1);
                luatex_error(Luas, (i == LUA_ERRRUN ? 0 : 1));
            }
        }
        lua_settop(Luas,top);
    }
}

void luatex_error(lua_State * L, int is_fatal)
{
    const_lstring luaerr;
    char *err = NULL;
    if (lua_type(L, -1) == LUA_TSTRING) {
        luaerr.s = lua_tolstring(L, -1, &luaerr.l);
        /*tex Free the last one. */
        err = (char *) malloc((unsigned) (luaerr.l + 1));
        snprintf(err, (luaerr.l + 1), "%s", luaerr.s);
        /*tex What if we have several .. not freed? */
        error_state.last_lua_error = err;
    }
    if (is_fatal > 0) {
        /*
            Normally a memory error from lua. The pool may overflow during the
            |maketexlstring()|, but we are crashing anyway so we may as well
            abort on the pool size
        */
        normal_error("lua",err);
        /*tex This is never reached. */
        lua_close(L);
    } else {
        normal_warning("lua",err);
    }
}
