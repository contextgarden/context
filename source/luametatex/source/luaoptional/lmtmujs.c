/*
    See license.txt in the root of this project.
*/

/*tex
    The \CLANGUAGE\ interface looks quite a bit like the \LUA\ interface. This module will only
    provide print-to-tex functions and no other interfacing. It really makes no sense to provide
    more. An interesting lightweight interface could map onto \LUA\ calls but there is no gain
    either. Consider it an experiment that might attract kids to \TEX, just because \JAVASCRIPT\
    looks familiar. We have only one instance. Of course we could use some userdata object but I
    don't think it is worth the effort and one would like to be persistent across calls. (We used
    to have multiple \LUA\ instances which made no sense either.)

    url: https://mujs.com/index.html

    Keep in mind: we don't have a \JAVASCRIPT\ interoreter embedded because this is just a small
    minimal interface to code that {\em can} be loaded at runtime, if present at all.

*/

# include "luametatex.h"
# include "lmtoptional.h"

typedef struct js_State js_State;

typedef void (*js_CFunction) (js_State *J);
typedef void (*js_Report)    (js_State *J, const char *message);
typedef void (*js_Finalize)  (js_State *J, void *p);

typedef enum js_states {
	JS_STRICT = 1,
} js_states;

typedef enum js_properties {
	JS_READONLY = 1,
	JS_DONTENUM = 2,
	JS_DONTCONF = 4,
} js_properties;

/*tex A couple of status variables: */

typedef struct mujslib_state_info {

    js_State *instance;
    int       initialized;
    int       find_file_id;
    int       open_file_id;
    int       close_file_id;
    int       read_file_id;
    int       seek_file_id;
    int       console_id;
    int       padding;

    struct js_State * (*js_newstate) (
        void  *alloc,
        void  *actx,
        int    flags
    );

    void (*js_freestate) (
        js_State *J
    );

    void (*js_setreport) (
        js_State  *J,
        js_Report  report
    );

    int (*js_dostring) (
        js_State   *J,
        const char *source
    );

    void (*js_newcfunction) (
        js_State     *J,
        js_CFunction  fun,
        const char   *name,
        int           length
    );

    void (*js_newuserdata) (
        js_State    *J,
        const char  *tag,
        void        *data,
        js_Finalize finalize
    );

    void (*js_newcconstructor) (
        js_State     *J,
        js_CFunction  fun,
        js_CFunction  con,
        const char   *name,
        int           length
    );

    int (*js_dofile) (
        js_State   *J,
        const char *filename
    );

    void (*js_currentfunction) (
        js_State *J
    );

    void         (*js_getglobal)     (js_State *J, const char *name                   );
    void         (*js_setglobal)     (js_State *J, const char *name                   );
    void         (*js_defglobal)     (js_State *J, const char *name, int atts         );

    void         (*js_getproperty)   (js_State *J, int idx, const char *name          );
    void         (*js_setproperty)   (js_State *J, int idx, const char *name          );
    void         (*js_defproperty)   (js_State *J, int idx, const char *name, int atts);

    void         (*js_pushundefined) (js_State *J                                     );
    void         (*js_pushnull)      (js_State *J                                     );
    void         (*js_pushnumber)    (js_State *J, double v                           );
    void         (*js_pushstring)    (js_State *J, const char *v                      );

    const char * (*js_tostring)      (js_State *J, int idx                            );
    int          (*js_tointeger)     (js_State *J, int idx                            );
    void       * (*js_touserdata)    (js_State *J, int idx, const char *tag           );

    int          (*js_isnumber)      (js_State *J, int idx                            );
    int          (*js_isstring)      (js_State *J, int idx                            );
    int          (*js_isundefined)   (js_State *J, int idx                            );

} mujslib_state_info;

static mujslib_state_info mujslib_state = {

    .initialized         = 0,
    .instance            = NULL,
    .find_file_id        = 0,
    .open_file_id        = 0,
    .close_file_id       = 0,
    .read_file_id        = 0,
    .seek_file_id        = 0,
    .console_id          = 0,
    .padding             = 0,

    .js_newstate         = NULL,
    .js_freestate        = NULL,
    .js_setreport        = NULL,
    .js_dostring         = NULL,
    .js_newcfunction     = NULL,
    .js_newuserdata      = NULL,
    .js_newcconstructor  = NULL,
    .js_dofile           = NULL,
    .js_currentfunction  = NULL,

    .js_getglobal        = NULL,
    .js_setglobal        = NULL,
    .js_defglobal        = NULL,

    .js_getproperty      = NULL,
    .js_setproperty      = NULL,
    .js_defproperty      = NULL,

    .js_pushundefined    = NULL,
    .js_pushnull         = NULL,
    .js_pushnumber       = NULL,
    .js_pushstring       = NULL,

    .js_tostring         = NULL,
    .js_tointeger        = NULL,
    .js_touserdata       = NULL,

    .js_isnumber         = NULL,
    .js_isstring         = NULL,
    .js_isundefined      = NULL,

};

/*tex A few callbacks: */

static int mujslib_register_function(lua_State * L, int old_id)
{
    if (! (lua_isfunction(L, -1) || lua_isnil(L, -1))) {
        return 0;
    } else {
        lua_pushvalue(L, -1);
        if (old_id) {
            luaL_unref(L, LUA_REGISTRYINDEX, old_id);
        }
        return luaL_ref(L, LUA_REGISTRYINDEX);
    }
}

static int mujslib_set_find_file(lua_State *L)
{
    mujslib_state.find_file_id = mujslib_register_function(L, mujslib_state.find_file_id);
    return 0;
}

static int mujslib_set_open_file(lua_State *L)
{
    mujslib_state.open_file_id = mujslib_register_function(L, mujslib_state.open_file_id);
    return 0;
}

static int mujslib_set_close_file(lua_State *L)
{
    mujslib_state.close_file_id = mujslib_register_function(L, mujslib_state.close_file_id);
    return 0;
}

static int mujslib_set_read_file(lua_State *L)
{
    mujslib_state.read_file_id = mujslib_register_function(L, mujslib_state.read_file_id);
    return 0;
}

static int mujslib_set_seek_file(lua_State *L)
{
    mujslib_state.seek_file_id = mujslib_register_function(L, mujslib_state.seek_file_id);
    return 0;
}

static int mujslib_set_console(lua_State *L)
{
    mujslib_state.console_id = mujslib_register_function(L, mujslib_state.console_id);
    return 0;
}

static char *mujslib_find_file(const char *fname, const char *fmode)
{
    if (mujslib_state.find_file_id) {
        lua_State *L = lmt_lua_state.lua_instance; /* todo: pass */
        lua_rawgeti(L, LUA_REGISTRYINDEX, mujslib_state.find_file_id);
        lua_pushstring(L, fname);
        lua_pushstring(L, fmode);
        if (lua_pcall(L, 2, 1, 0)) {
            tex_formatted_warning("mujs", "find file: %s\n", lua_tostring(L, -1));
        } else {
            char *s = NULL;
            const char *x = lua_tostring(L, -1);
            if (x) {
                s = strdup(x);
            }
            lua_pop(L, 1);
            return s;
        }
    } else {
        tex_normal_warning("mujs", "missing callback: find file");
    }
    return NULL;
}

/*tex A few helpers: */

static void mujslib_aux_texcprint(js_State *J, int ispartial)
{
    int c = default_catcode_table_preset;
    int i = 0;
    if (mujslib_state.js_isnumber(J, 1)) {
        if (mujslib_state.js_isnumber(J, 2) || mujslib_state.js_isstring(J, 2)) {
            c = mujslib_state.js_tointeger(J, 1);
            i = 2;
        } else {
            i = 1;
        }
    } else if (mujslib_state.js_isstring(J, 1)) {
        i = 1;
    }
    if (i) {
        const char *s = mujslib_state.js_tostring(J, i);
        if (s) {
            lmt_cstring_print(c, s, ispartial);
        }
    } else {
        tex_normal_warning("mujs", "invalid argument(s) for printing to tex");
    }
	mujslib_state.js_pushundefined(J); /* needed ? */
}

static void mujslib_aux_texprint(js_State *J)
{
    mujslib_aux_texcprint(J, 0); /* full line */
}

static void mujslib_aux_texsprint(js_State *J)
{
    mujslib_aux_texcprint(J, 1); /* partial line */
}

static void mujslib_aux_feedback(js_State *J, const char *category, const char *message)
{
    if (message) {
        if (mujslib_state.console_id) {
            lua_State *L = lmt_lua_state.lua_instance;
            lua_rawgeti(L, LUA_REGISTRYINDEX, mujslib_state.console_id);
            lua_pushstring(L, category);
            lua_pushstring(L, message);
            if (lua_pcall(L, 2, 0, 0)) {
                tex_formatted_warning("mujs", "console: %s\n", lua_tostring(L, -1));
            }
        } else {
            tex_print_message(message);
        }
    }
	mujslib_state.js_pushundefined(J);
}

static void mujslib_aux_console(js_State *J)
{
    mujslib_aux_feedback(J, "console", mujslib_state.js_tostring(J, 1));
}

static void mujslib_aux_report(js_State *J, const char *s)
{
    mujslib_aux_feedback(J, "report", s);
}

/*tex
    The interfaces: for loading files a finder callback is mandate so that
    we keep control over what gets read from where.
*/

static int mujslib_execute(lua_State *L)
{
    if (mujslib_state.instance) {
	    const char *s = lua_tostring(L, 1);
        if (s) {
           mujslib_state.js_dostring(mujslib_state.instance, s);
        }
    }
    return 0;
}

static int mujslib_dofile(lua_State *L)
{
    if (mujslib_state.instance) {
	    const char *name = lua_tostring(L, 1);
        if (name) {
            char *found = mujslib_find_file(name, "rb");
            if (found) {
               mujslib_state.js_dofile(mujslib_state.instance, found);
            }
            free(found);
        }
    } else {
        tex_normal_warning("mujs", "missing callback: find file");
    }
    return 0;
}

static void mujslib_start(void)
{
    if (mujslib_state.instance) {
        mujslib_state.js_freestate(mujslib_state.instance);
    }
    mujslib_state.instance = mujslib_state.js_newstate(NULL, NULL, JS_STRICT);
    if (mujslib_state.instance) {
        mujslib_state.js_newcfunction(mujslib_state.instance, mujslib_aux_texprint, "texprint", 2);
        mujslib_state.js_setglobal   (mujslib_state.instance, "texprint");
        mujslib_state.js_newcfunction(mujslib_state.instance, mujslib_aux_texsprint, "texsprint", 2);
        mujslib_state.js_setglobal   (mujslib_state.instance, "texsprint");
        mujslib_state.js_newcfunction(mujslib_state.instance, mujslib_aux_console, "console", 1);
        mujslib_state.js_setglobal   (mujslib_state.instance, "console");
        mujslib_state.js_setreport   (mujslib_state.instance, mujslib_aux_report);
    }
}

static int mujslib_reset(lua_State *L)
{
    if (mujslib_state.initialized) {
        mujslib_start();
    }
    lua_pushboolean(L, mujslib_state.initialized && mujslib_state.instance);
    return 1;
}

/*tex
    File handling: we go via the \LUA\ interface so that we have control
    over what happens. Another benefit is that we don't need memory
    management when fetching data from files.
*/

static void mujslib_file_finalize(js_State *J, void *p)
{
    int *id = p;
    (void) J;
    if (*id) {
        lua_State *L = lmt_lua_state.lua_instance;
        int top = lua_gettop(L);
        lua_rawgeti(L, LUA_REGISTRYINDEX, mujslib_state.close_file_id);
        lua_pushinteger(L, *id);
        if (lua_pcall(L, 1, 0, 0)) {
            tex_formatted_warning("mujs", "close file: %s\n", lua_tostring(L, -1));
        }
        lua_settop(L,top);
    }
}

static void mujslib_file_close(js_State *J)
{
    if (mujslib_state.instance) {
        if (mujslib_state.close_file_id) {
    	    int *id = mujslib_state.js_touserdata(J, 0, "File");
            if (*id) {
                mujslib_file_finalize(J, id);
            }
        } else {
            tex_normal_warning("mujs", "missing callback: close file");
        }
    }
	mujslib_state.js_pushundefined(J);
}

static void mujslib_file_read(js_State *J)
{
    if (mujslib_state.instance) {
        if (mujslib_state.read_file_id) {
            int *id = mujslib_state.js_touserdata(J, 0, "File");
            if (*id) {
                lua_State *L = lmt_lua_state.lua_instance;
                int top = lua_gettop(L);
                int n = 1;
                lua_rawgeti(L, LUA_REGISTRYINDEX, mujslib_state.read_file_id);
                lua_pushinteger(L, *id);
                if (mujslib_state.js_isstring(J, 1)) {
                    const char *how = mujslib_state.js_tostring(J, 1);
                    if (how) {
                        lua_pushstring(L, how);
                        n = 2;
                    }
                } else if (mujslib_state.js_isnumber(J, 1)) {
                    int how = mujslib_state.js_tointeger(J, 1);
                    if (how) {
                        lua_pushinteger(L, how);
                        n = 2;
                    }
                }
                if (lua_pcall(L, n, 1, 0)) {
                    tex_formatted_warning("mujs", "close file: %s\n", lua_tostring(L, -1));
                } else {
                    const char *result = strdup(lua_tostring(L, -1));
                    if (result) {
            	        mujslib_state.js_pushstring(J, result);
                        lua_settop(L, top);
                        return;
                    }
                }
                lua_settop(L, top);
            }
        } else {
            tex_normal_warning("mujs", "missing callback: read file");
        }
    }
	mujslib_state.js_pushundefined(J);
}

static void mujslib_file_seek(js_State *J)
{
    if (mujslib_state.instance) {
        if (mujslib_state.seek_file_id) {
            int *id = mujslib_state.js_touserdata(J, 0, "File");
            if (*id) {
                lua_State *L = lmt_lua_state.lua_instance;
                int top = lua_gettop(L);
                int n = 2;
                lua_rawgeti(L, LUA_REGISTRYINDEX, mujslib_state.seek_file_id);
                lua_pushinteger(L, *id);
                /* no checking here */
                lua_pushstring(L, mujslib_state.js_tostring(J, 1));
                if (mujslib_state.js_isnumber(J, 2)) {
                    lua_pushinteger(L, mujslib_state.js_tointeger(J, 2));
                    n = 3;
                }
                if (lua_pcall(L, n, 1, 0)) {
                    tex_formatted_warning("mujs", "seek file: %s\n", lua_tostring(L, -1));
                } else if (lua_type(L, -1) == LUA_TNUMBER) {
         	        mujslib_state.js_pushnumber(J, lua_tonumber(L, -1));
                    lua_settop(L, top);
                    return;
                }
                lua_settop(L, top);
            }
        } else {
            tex_normal_warning("mujs", "missing callback: seek file");
        }
    }
	mujslib_state.js_pushundefined(J);
}

static void mujslib_file_new(js_State *J)
{
    if (mujslib_state.instance) {
        if (mujslib_state.open_file_id) {
    	    const char *name = mujslib_state.js_tostring(J, 1);
            if (name) {
                lua_State *L = lmt_lua_state.lua_instance;
                int top = lua_gettop(L);
                lua_rawgeti(L, LUA_REGISTRYINDEX, mujslib_state.open_file_id);
                lua_pushstring(L, name);
                if (lua_pcall(L, 1, 1, 0)) {
                    tex_formatted_warning("mujs", "open file: %s\n", lua_tostring(L, -1));
                } else {
                    int *id = malloc(sizeof(int));
                    if (id) {
                        *((int*) id) = (int) lua_tointeger(L, -1);
                        lua_settop(L, top);
                        if (id) {
	                        mujslib_state.js_currentfunction(J);
	                        mujslib_state.js_getproperty(J, -1, "prototype");
	                        mujslib_state.js_newuserdata(J, "File", id, mujslib_file_finalize);
                            return;
                        }
                    }
                }
                lua_settop(L, top);
            }
        } else {
            tex_normal_warning("mujs", "missing callback: open file");
        }
    }
 	mujslib_state.js_pushnull(J);
}

/* Setting things up. */

static void mujslib_file_initialize(js_State *J)
{
	mujslib_state.js_getglobal(J, "Object");
	mujslib_state.js_getproperty(J, -1, "prototype");
	mujslib_state.js_newuserdata(J, "File", stdin, NULL);
	{
		mujslib_state.js_newcfunction(J, mujslib_file_read, "File.prototype.read", 0);
		mujslib_state.js_defproperty(J, -2, "read", JS_DONTENUM);
		mujslib_state.js_newcfunction(J, mujslib_file_seek, "File.prototype.seek", 0);
		mujslib_state.js_defproperty(J, -2, "seek", JS_DONTENUM);
		mujslib_state.js_newcfunction(J, mujslib_file_close, "File.prototype.close", 0);
		mujslib_state.js_defproperty(J, -2, "close", JS_DONTENUM);
	}
	mujslib_state.js_newcconstructor(J, mujslib_file_new, mujslib_file_new, "File", 1);
	mujslib_state.js_defglobal(J, "File", JS_DONTENUM);
}

static int mujslib_initialize(lua_State *L)
{
    if (! mujslib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            mujslib_state.js_newstate        = lmt_library_find(lib, "js_newstate");
            mujslib_state.js_freestate       = lmt_library_find(lib, "js_freestate");
            mujslib_state.js_setreport       = lmt_library_find(lib, "js_setreport");

            mujslib_state.js_newcfunction    = lmt_library_find(lib, "js_newcfunction");
            mujslib_state.js_newuserdata     = lmt_library_find(lib, "js_newuserdata");
            mujslib_state.js_newcconstructor = lmt_library_find(lib, "js_newcconstructor");

            mujslib_state.js_pushundefined   = lmt_library_find(lib, "js_pushundefined");
            mujslib_state.js_pushnull        = lmt_library_find(lib, "js_pushnull");
            mujslib_state.js_pushnumber      = lmt_library_find(lib, "js_pushnumber");
            mujslib_state.js_pushstring      = lmt_library_find(lib, "js_pushstring");

            mujslib_state.js_dostring        = lmt_library_find(lib, "js_dostring");
            mujslib_state.js_dofile          = lmt_library_find(lib, "js_dofile");

            mujslib_state.js_tostring        = lmt_library_find(lib, "js_tostring");
            mujslib_state.js_tointeger       = lmt_library_find(lib, "js_tointeger");
            mujslib_state.js_touserdata      = lmt_library_find(lib, "js_touserdata");

            mujslib_state.js_getglobal       = lmt_library_find(lib, "js_getglobal");
            mujslib_state.js_setglobal       = lmt_library_find(lib, "js_setglobal");
            mujslib_state.js_defglobal       = lmt_library_find(lib, "js_defglobal");

            mujslib_state.js_getproperty     = lmt_library_find(lib, "js_getproperty");
            mujslib_state.js_setproperty     = lmt_library_find(lib, "js_setproperty");
            mujslib_state.js_defproperty     = lmt_library_find(lib, "js_defproperty");

            mujslib_state.js_isstring        = lmt_library_find(lib, "js_isstring");
            mujslib_state.js_isnumber        = lmt_library_find(lib, "js_isnumber");
            mujslib_state.js_isundefined     = lmt_library_find(lib, "js_isundefined");

            mujslib_state.js_currentfunction = lmt_library_find(lib, "js_currentfunction");

            mujslib_state.initialized = lmt_library_okay(lib);

            mujslib_start();

            mujslib_file_initialize(mujslib_state.instance);
        }
    }
    lua_pushboolean(L, mujslib_state.initialized && mujslib_state.instance);
    return 1;
}

static struct luaL_Reg mujslib_function_list[] = {
    { "initialize",   mujslib_initialize     }, /* mandate */
    { "reset",        mujslib_reset          },
    { "execute",      mujslib_execute        },
    { "dofile",       mujslib_dofile         },
    { "setfindfile",  mujslib_set_find_file  }, /* mandate */
    { "setopenfile",  mujslib_set_open_file  }, /* mandate */
    { "setclosefile", mujslib_set_close_file }, /* mandate */
    { "setreadfile",  mujslib_set_read_file  }, /* mandate */
    { "setseekfile",  mujslib_set_seek_file  },
    { "setconsole",   mujslib_set_console    },
    { NULL,           NULL                   },
};

int luaopen_mujs(lua_State *L)
{
    lmt_library_register(L, "mujs", mujslib_function_list);
    return 0;
}
