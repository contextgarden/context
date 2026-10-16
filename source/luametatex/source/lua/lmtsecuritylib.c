/*
    See license.txt in the root of this project.
*/

# include <luametatex.h>

static inline int security_target_okay(int target)
{
    return target >= security_generic && target <= security_client;
}

static void securitylib_initialize(lua_State *L)
{
    (void) L;
    for (int i = 0; i < n_of_security_targets; i++) {
        lmt_lua_state.security_checkers[i] = LUA_NOREF;
        lmt_lua_state.security_states  [i] = security_state_unset;
    }
}

static int securitylib_setchecker(lua_State *L)
{
    int target = lmt_tointeger(L, 1);
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        int freeze = ! lua_toboolean(L, 3);
        lua_settop(L, 2);
        if (! security_target_okay(target)) {
            return luaL_error(L, "first argument must be a valid target");
        } else if (lmt_lua_state.security_states[target] == security_state_frozen) {
            return luaL_error(L, "security checker for target %d is frozen and cannot be (re)set", target);
        } else {
            lmt_lua_state.security_checkers[target] = luaL_ref(L, LUA_REGISTRYINDEX);
            lmt_lua_state.security_states  [target] = freeze ? security_state_frozen : security_state_set;
            return 0;
        }
    } else {
        return luaL_error(L, "second argument must be a function");
    }
}

bool lmt_valid_target(lua_State *L, int target, const char *str, int action)
{
    if (! str) {
        return false;
    } else if (! security_target_okay(target)) {
        return false;
    } else {
        int  reference = lmt_lua_state.security_checkers[target];
        bool valid     = true;
        bool generic   = false;
        if (reference == LUA_NOREF) {
            reference = lmt_lua_state.security_checkers[security_generic];
            generic   = reference != LUA_NOREF;
        }
        if (reference != LUA_NOREF) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, reference);
            if (generic) {
                 /* call fn(target,str) -> boolean */
                lua_pushinteger(L, target);
            } else {
                 /* call fn(str) -> boolean */
            }
            lua_pushstring(L, str);
            lua_pushinteger(L, action);
            lua_call(L, generic ? 3 : 2, 1);
            valid = lua_toboolean(L, -1);
            lua_pop(L, 1);
        }
        return valid;
    }
}

static int securitylib_checked(lua_State *L)
{
    int         target = lmt_tointeger(L, 1);
    const char *str    = lmt_checkstring(L, 2);
    int         action = lmt_optinteger(L, 3, 0);
    lua_pushboolean(L, lmt_valid_target(L, target, str, action));
    return 1;
}

void lmt_disable_debug(lua_State *L, int complete)
{
    if (complete) {
        lua_pushnil(L);
        lua_setglobal(L, "debug");
        lua_getfield(L, LUA_REGISTRYINDEX, LUA_LOADED_TABLE);
        if (lua_istable(L, -1)) {
            lua_pushnil(L);
            lua_setfield(L, -2, "debug");
        }
        /* pop package.loaded: */
    } else if (lua_getglobal(L, "debug") == LUA_TTABLE) {
        lua_pushnil(L); lua_setfield(L, -2, "debug"       );
        lua_pushnil(L); lua_setfield(L, -2, "getuservalue");
        lua_pushnil(L); lua_setfield(L, -2, "gethook"     );
     /* lua_pushnil(L); lua_setfield(L, -2, "getinfo"     ); */ /* so we can profile */
        lua_pushnil(L); lua_setfield(L, -2, "getlocal"    );
        lua_pushnil(L); lua_setfield(L, -2, "getregistry" );
        lua_pushnil(L); lua_setfield(L, -2, "getmetatable");
        lua_pushnil(L); lua_setfield(L, -2, "getupvalue"  );
        lua_pushnil(L); lua_setfield(L, -2, "upvaluejoin" );
        lua_pushnil(L); lua_setfield(L, -2, "upvalueid"   );
        lua_pushnil(L); lua_setfield(L, -2, "setuservalue");
     /* lua_pushnil(L); lua_setfield(L, -2, "sethook"     ); */ /* so we can profile */
        lua_pushnil(L); lua_setfield(L, -2, "setlocal"    );
        lua_pushnil(L); lua_setfield(L, -2, "setmetatable");
        lua_pushnil(L); lua_setfield(L, -2, "setupvalue"  );
     /* lua_pushnil(L); lua_setfield(L, -2, "traceback"   ); */ /* harmless */
        /* pop debug: */
    }
    lua_pop(L, 1);
}

static int securitylib_resetdebug(lua_State *L)
{
    lmt_disable_debug(L, 1);
    return 0;
}

static int securitylib_gettargets(lua_State *L)
{
    lua_createtable(L, 7, 1);
    lua_set_string_by_index(L, security_generic,    "generic");
    lua_set_string_by_index(L, security_readable,   "readable");
    lua_set_string_by_index(L, security_writeable,  "writeable");
    lua_set_string_by_index(L, security_executable, "executable");
    lua_set_string_by_index(L, security_library,    "library");
    lua_set_string_by_index(L, security_loadable,   "loadable");
    lua_set_string_by_index(L, security_launchable, "launchable");
    lua_set_string_by_index(L, security_client,     "client");
    return 1;
}

static int securitylib_getactions(lua_State *L)
{
    lua_createtable(L, 17, 1);
    lua_set_string_by_index(L, security_generic_action,   "generic");
    lua_set_string_by_index(L, security_remove_directory, "remove directory");
    lua_set_string_by_index(L, security_change_directory, "change directory");
    lua_set_string_by_index(L, security_create_directory, "create directory");
    lua_set_string_by_index(L, security_remove_file,      "remove file");
    lua_set_string_by_index(L, security_rename_file,      "rename file");
    lua_set_string_by_index(L, security_open_file,        "open file");
    lua_set_string_by_index(L, security_open_pipe,        "open pipe");
    lua_set_string_by_index(L, security_open_process,     "open process");
    lua_set_string_by_index(L, security_link_object,      "link object");
    lua_set_string_by_index(L, security_touch_object,     "touch object");
    lua_set_string_by_index(L, security_load_script_file, "load script file");
    lua_set_string_by_index(L, security_set_executable,   "set executable");
    lua_set_string_by_index(L, security_run_executable,   "run executable");
    lua_set_string_by_index(L, security_load_library,     "load library");
    lua_set_string_by_index(L, security_open_database,    "open database");
    lua_set_string_by_index(L, security_launch_command,   "launch command");
    lua_set_string_by_index(L, security_http_request,     "http request");
    return 1;
}

static const struct luaL_Reg securitylib_function_list[] = {
    { "setchecker", securitylib_setchecker },
    { "checked",    securitylib_checked    },
    { "resetdebug", securitylib_resetdebug },
    { "gettargets", securitylib_gettargets },
    { "getactions", securitylib_getactions },
    { NULL,         NULL                   }
};

int luaopen_security(lua_State *L)
{
    securitylib_initialize(L);
    luaL_newlib(L, securitylib_function_list);
    return 1;
}