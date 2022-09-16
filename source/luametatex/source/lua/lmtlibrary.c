/*
    See license.txt in the root of this project.
*/


/*tex

    There is not much here. We only implement a mechanism for storing optional libraries. The
    engine is self contained and doesn't depend on large and complex libraries. One can (try to)
    load libraries at runtime. The optional ones that come with the engine end up in the
    |optional| namespace.

*/

# include "luametatex.h"

void lmt_library_initialize(lua_State *L)
{
    lua_getglobal(L,"optional");
    if (! lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_setglobal(L, "optional");
    } else {
        lua_pop(L, 1);
    }
}

void lmt_library_register(lua_State *L, const char *name, luaL_Reg functions[])
{
    lmt_library_initialize(L);
    lua_getglobal(L, "optional");
    lua_pushstring(L, name);
    lua_newtable(L);
    luaL_setfuncs(L, functions, 0);
    lua_rawset(L, -3);
    lua_pop(L, 1);
}

lmt_library lmt_library_load(const char *filename)
{
    lmt_library lib = { .lib = NULL };
    if (filename && strlen(filename)) {
        lib.lib = lmt_library_open_indeed(filename);
        lib.okay = lib.lib != NULL;
        if (! lib.okay) {
            tex_formatted_error("lmt library", "unable to load '%s', quitting\n", filename);
        }
    }
    return lib;
}

lmt_library_function lmt_library_find(lmt_library lib, const char *source)
{
    if (lib.lib && lib.okay) {
        lmt_library_function target = lmt_library_find_indeed(lib.lib, source);
        if (target) {
            return target;
        } else {
            lib.okay = 0;
            tex_formatted_error("lmt library", "unable to locate '%s', quitting\n", source);
        }
    }
    return NULL;
}

int lmt_library_okay(lmt_library lib)
{
    return lib.lib && lib.okay;
};

/* experiment */

int librarylib_load(lua_State *L)
{
    /* So we permit it in mtxrun (for now, when we test). */
    if (lmt_engine_state.lua_only || lmt_engine_state.permit_loadlib) {
        const char *filename = lua_tostring(L, 1);
        const char *openname = lua_tostring(L, 2);
        if (filename && openname) {
            lmt_library lib = lmt_library_load(filename);
            if (lmt_library_okay(lib)) {
                lua_CFunction target = lmt_library_find_indeed(lib.lib, openname);
                if (target) {
                    lua_pushcfunction(L, target);
                    lua_pushstring(L, filename);
                    return 2;
                }
            }
        }
    } else {
        tex_formatted_error("lmt library", "loading is not permitted, quitting\n");
    }
    return 0;
};

static struct luaL_Reg librarylib_function_list[] = {
    { "load", librarylib_load },
    { NULL,   NULL            },
};

int luaopen_library(lua_State * L)
{
    lmt_library_register(L, "library", librarylib_function_list);
    return 0;
}
