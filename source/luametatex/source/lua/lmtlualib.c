/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Some code here originates from the beginning of \LUATEX\ developmentm like the bytecode
    registers. They provide a way to store (compiled) \LUA\ code in the format file. In the
    meantime there are plenty of ways to use \LUA\ code in the frontend so an interface at the
    \TEX\ end makes no longer much sense.

    This module also provides some statistics and control options. Keep in mind that the engine
    also can act as a \LUA\ engine, so some of that property is reflected in the code.

*/

# define LOAD_BUF_SIZE 64*1024
# define UINT_MAX32    0xFFFFFFFF

# define LUA_FUNCTIONS          "lua.functions"
# define LUA_BYTECODES          "lua.bytecodes"
# define LUA_BYTECODES_INDIRECT "lua.bytecodes.indirect"

typedef struct bytecode {
    unsigned char *buf;
    int            size;
    int            alloc;
} bytecode;

static bytecode *lmt_bytecode_registers = NULL;

void lmt_dump_registers(dumpstream f)
{
    dump_int(f, lmt_lua_state.version_number);
    dump_int(f, lmt_lua_state.release_number);
    dump_int(f, lmt_lua_state.integer_size);
    dump_int(f, lmt_lua_state.bytecode_max);
    if (lmt_bytecode_registers) {
        int n = 0;
        for (int k = 0; k <= lmt_lua_state.bytecode_max; k++) {
            if (lmt_bytecode_registers[k].size != 0) {
                n++;
            }
        }
        dump_int(f, n);
        for (int k = 0; k <= lmt_lua_state.bytecode_max; k++) {
            bytecode b = lmt_bytecode_registers[k];
            if (b.size != 0) {
                dump_int(f, k);
                dump_int(f, b.size);
                dump_items(f, (char *) b.buf, 1, b.size);
            }
        }
    }
}

void lmt_undump_registers(dumpstream f)
{
    int version_number = 0;
    int release_number = 0;
    int integer_size = 0;
    undump_int(f, version_number);
    if (version_number != lmt_lua_state.version_number) {
        tex_fatal_undump_error("mismatching Lua version number");
    }
    undump_int(f, release_number);
    if (release_number != lmt_lua_state.release_number) {
        tex_fatal_undump_error("mismatching Lua release number");
    }
    undump_int(f, integer_size);
    if (integer_size != lmt_lua_state.integer_size) {
        tex_fatal_undump_error("different integer size");
    }
    undump_int(f, lmt_lua_state.bytecode_max);
    if (lmt_lua_state.bytecode_max < 0) {
        tex_fatal_undump_error("not enough memory for undumping bytecodes"); /* old */
    } else {
        size_t s = (lmt_lua_state.bytecode_max + 1) * sizeof(bytecode);
        int n = (int) s;
        lmt_bytecode_registers = (bytecode *) lmt_memory_malloc(s);
        if (lmt_bytecode_registers) {
            lmt_lua_state.bytecode_bytes = n;
            for (int j = 0; j <= lmt_lua_state.bytecode_max; j++) {
                lmt_bytecode_registers[j].buf = NULL;
                lmt_bytecode_registers[j].size = 0;
                lmt_bytecode_registers[j].alloc = 0;
            }
            undump_int(f, n);
            for (int j = 0; j < n; j++) {
                unsigned char *buffer;
                int slot, size;
                undump_int(f, slot);
                undump_int(f, size);
                buffer = (unsigned char *) lmt_memory_malloc((unsigned) size);
                if (buffer) {
                    memset(buffer, 0, (size_t) size);
                    undump_items(f, buffer, 1, size);
                    lmt_bytecode_registers[slot].buf = buffer;
                    lmt_bytecode_registers[slot].size = size;
                    lmt_bytecode_registers[slot].alloc = size;
                    lmt_lua_state.bytecode_bytes += size;
                } else {
                    tex_fatal_undump_error("not enough memory for undumping bytecodes");
                }
            }
        }
    }
}

static void lualib_aux_bytecode_register_shadow_set(lua_State *L, int k)
{
    /*tex the stack holds the value to be set */
    luaL_getmetatable(L, LUA_BYTECODES_INDIRECT);
    if (lua_istable(L, -1)) {
        lua_pushvalue(L, -2);
        lua_rawseti(L, -2, k);
    }
    lua_pop(L, 2); /*tex pop table or nil and value */
}

static int lualib_aux_bytecode_register_shadow_get(lua_State *L, int k)
{
    /*tex the stack holds the value to be set */
    int ret = 0;
    luaL_getmetatable(L, LUA_BYTECODES_INDIRECT);
    if (lua_istable(L, -1)) {
        if (lua_rawgeti(L, -1, k) != LUA_TNIL) {
            ret = 1;
        }
        /*tex store the value or nil, deeper down  */
        lua_insert(L, -3);
        /*tex pop the value or nil at top */
        lua_pop(L, 1);
    }
    /*tex pop table or nil */
    lua_pop(L, 1);
    return ret;
}

static int lualib_aux_writer(lua_State *L, const void *b, size_t size, void *B)
{
    bytecode *buf = (bytecode *) B;
    (void) L;
    if ((int) (buf->size + (int) size) > buf->alloc) {
        unsigned newalloc = (unsigned) (buf->alloc + (int) size + LOAD_BUF_SIZE);
        unsigned char *bb = lmt_memory_realloc(buf->buf, newalloc);
        if (bb) {
            buf->buf = bb;
            buf->alloc = newalloc;
        } else {
            return luaL_error(L, "something went wrong with handling bytecodes");
        }
    }
    memcpy(buf->buf + buf->size, b, size);
    buf->size += (int) size;
    lmt_lua_state.bytecode_bytes += (unsigned) size;
    return 0;
}

static const char *lualib_aux_reader(lua_State *L, void *ud, size_t *size)
{
    bytecode *buf = (bytecode *) ud;
    (void) L;
    *size = (size_t) buf->size;
    return (const char *) buf->buf;
}

static int lualib_valid_bytecode(lua_State *L, int slot)
{
    if (slot < 0 || slot > lmt_lua_state.bytecode_max) {
        return luaL_error(L, "bytecode register out of range");
    } else if (lualib_aux_bytecode_register_shadow_get(L, slot) || ! lmt_bytecode_registers[slot].buf) {
        return luaL_error(L, "undefined bytecode register");
    } else if (lua_load(L, lualib_aux_reader, (void *) (lmt_bytecode_registers + slot), "bytecode", NULL)) {
        return luaL_error(L, "bytecode register doesn't load well");
    } else {
        return 1;
    }
}

static int lualib_get_bytecode(lua_State *L)
{
    int slot = lmt_checkinteger(L, 1);
    if (lualib_valid_bytecode(L, slot)) {
        lua_pushvalue(L, -1);
        lualib_aux_bytecode_register_shadow_set(L, slot);
        return 1;
    } else {
        return 0;
    }
}

static int lmt_handle_bytecode_call(lua_State *L, int slot)
{
    int stacktop = lua_gettop(L);
    int error = 1;
    if (lualib_valid_bytecode(L, slot)) {
        /*tex function index */
        lua_pushinteger(L, slot);
        /*tex push traceback function */
        lua_pushcfunction(L, lmt_traceback);
        /*tex put it under chunk  */
        lua_insert(L, stacktop);
        ++lmt_lua_state.bytecode_callback_count;
        error = lua_pcall(L, 1, 0, stacktop);
        /*tex remove traceback function */
        lua_remove(L, stacktop);
        if (error) {
            lua_gc(L, LUA_GCCOLLECT, 0);
            lmt_error(L, "bytecode call", slot, (error == LUA_ERRRUN ? 0 : 1));
        }
    }
    lua_settop(L, stacktop);
    return ! error;
}

void lmt_bytecode_call(int slot)
{
    lmt_handle_bytecode_call(lmt_lua_state.lua_instance, slot);
}

/*tex
    We don't report an error so this this permits a loop over the bytecode array.
*/

static int lualib_call_bytecode(lua_State *L)
{
    int k = lmt_checkinteger(L, -1);
    if (k >= 0 && ! lualib_aux_bytecode_register_shadow_get(L, k)) {
        if (k <= lmt_lua_state.bytecode_max && lmt_bytecode_registers[k].buf) {
            lmt_handle_bytecode_call(L, k);
            /* We can have a function pushed! */
        } else {
            k = -1;
        }
    } else {
        k = -1;
    }
    lua_pushboolean(L, k != -1);
    /*tex At most 1. */
    return 1;
}

static int lualib_set_bytecode(lua_State *L)
{
    int k = lmt_checkinteger(L, 1);
    int i = k + 1;
    if ((k < 0) || (k > max_bytecode_index)) {
        return luaL_error(L, "bytecode register out of range");
    } else {
        int ltype = lua_type(L, 2);
        int strip = lua_toboolean(L, 3);
        if (ltype != LUA_TFUNCTION && ltype != LUA_TNIL) {
            return luaL_error(L, "bytecode register should be a function or nil");
        } else {
            /*tex Later calls expect the function at the top of the stack. */
            lua_settop(L, 2);
            if (k > lmt_lua_state.bytecode_max) {
                bytecode *r = lmt_memory_realloc(lmt_bytecode_registers, (size_t) i * sizeof(bytecode));
                if (r) {
                    lmt_bytecode_registers = r;
                    lmt_lua_state.bytecode_bytes += ((int) sizeof(bytecode) * (k + 1 - (lmt_lua_state.bytecode_max > 0 ? lmt_lua_state.bytecode_max : 0)));
                    for (unsigned j = (unsigned) (lmt_lua_state.bytecode_max + 1); j <= (unsigned) k; j++) {
                        lmt_bytecode_registers[j].buf = NULL;
                        lmt_bytecode_registers[j].size = 0;
                        lmt_bytecode_registers[j].alloc = 0;
                    }
                    lmt_lua_state.bytecode_max = k;
                } else {
                    return luaL_error(L, "bytecode register exceeded memory");
                }
            }
            if (lmt_bytecode_registers[k].buf) {
                lmt_memory_free(lmt_bytecode_registers[k].buf);
                lmt_lua_state.bytecode_bytes -= lmt_bytecode_registers[k].size;
                lmt_bytecode_registers[k].size = 0;
                lmt_bytecode_registers[k].buf = NULL;
                lua_pushnil(L);
                lualib_aux_bytecode_register_shadow_set(L, k);
            }
            if (ltype == LUA_TFUNCTION) {
                lmt_bytecode_registers[k].buf = lmt_memory_calloc(1, LOAD_BUF_SIZE);
                if (lmt_bytecode_registers[k].buf) {
                    lmt_bytecode_registers[k].alloc = LOAD_BUF_SIZE;
                 // memset(lua_bytecode_registers[k].buf, 0, LOAD_BUF_SIZE);
                    lua_dump(L, lualib_aux_writer, (void *) (lmt_bytecode_registers + k), strip);
                } else {
                    return luaL_error(L, "bytecode register exceeded memory");
                }
            }
            lua_pop(L, 1);
        }
    }
    return 0;
}

void lmt_initialize_functions(int set_size)
{
    lua_State *L = lmt_lua_state.lua_instance;
    if (set_size) {
        tex_engine_get_config_number("functionsize", &lmt_lua_state.function_table_size);
        if (lmt_lua_state.function_table_size < 0) {
            lmt_lua_state.function_table_size = 0;
        }
        lua_createtable(L, lmt_lua_state.function_table_size, 0);
    } else {
        lua_newtable(L);
    }
    lmt_lua_state.function_table_id = luaL_ref(L, LUA_REGISTRYINDEX);
    /* not needed, so unofficial */
    lua_pushstring(L, LUA_FUNCTIONS);
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_lua_state.function_table_id);
    lua_settable(L, LUA_REGISTRYINDEX);
}

static int lualib_get_functions_table(lua_State *L)
{
    if (lua_toboolean(L, lua_gettop(L))) {
        /*tex Beware: this can have side effects when used without care. */
        lmt_initialize_functions(1);
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_lua_state.function_table_id);
    return 1;
}

static int lualib_new_table(lua_State *L)
{
    int i = lmt_checkinteger(L, 1);
    int h = lmt_checkinteger(L, 2);
    lua_createtable(L, i < 0 ? 0 : i, h < 0 ? 0 : h);
    return 1;
}

static int lualib_new_index(lua_State *L)
{
    int n = lmt_checkinteger(L, 1);
    int t = lua_gettop(L);
    lua_createtable(L, n < 0 ? 0 : n, 0);
    if (t == 2) {
        for (lua_Integer i = 1; i <= n; i++) {
            lua_pushvalue(L, 2);
            lua_rawseti(L, -2, i);
        }
    }
    return 1;
}

static int lualib_get_stack_top(lua_State *L)
{
    lua_pushinteger(L, lua_gettop(L));
    return 1;
}

static int lualib_get_runtime(lua_State *L)
{
    lua_pushnumber(L, aux_get_run_time());
    return 1;
}

static int lualib_get_currenttime(lua_State *L)
{
    lua_pushnumber(L, aux_get_current_time());
    return 1;
}

static int lualib_set_exitcode(lua_State *L)
{
    lmt_error_state.default_exit_code = lmt_checkinteger(L, 1);
    return 0;
}

static int lualib_get_exitcode(lua_State *L)
{
    lua_pushinteger(L, lmt_error_state.default_exit_code);
    return 1;
}

/*tex

    The |getpreciseticks()| call returns a number. This number has no meaning in itself but
    successive calls can be used to calculate a delta with a previous call. When the number is fed
    into |getpreciseseconds(n)| a number is returned representing seconds.

*/

# ifdef _WIN32

#   define clock_inittime()

    static int lualib_get_preciseticks(lua_State *L)
    {
        LARGE_INTEGER t;
        QueryPerformanceCounter(&t);
        lua_pushnumber(L, (double) t.QuadPart);
        return 1;
    }

    static int lualib_get_preciseseconds(lua_State *L)
    {
        LARGE_INTEGER t;
        QueryPerformanceFrequency(&t);
        lua_pushnumber(L, luaL_optnumber(L, 1, 0) / (double) t.QuadPart);
        return 1;
    }

# else

#   if (defined(__MACH__) && ! defined(CLOCK_PROCESS_CPUTIME_ID))

        /* https://stackoverflow.com/questions/5167269/clock-gettime-alternative-in-mac-os-x */

#       include <mach/mach_time.h>
#       define CLOCK_PROCESS_CPUTIME_ID 1

        static double conversion_factor;

        static void clock_inittime()
        {
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);
            conversion_factor = (double)timebase.numer / (double)timebase.denom;
        }

        static int clock_gettime(int clk_id, struct timespec *t)
        {
            uint64_t time;
            double nseconds, seconds;
            (void) clk_id; /* please the compiler */
            time = mach_absolute_time();
            nseconds = ((double)time * conversion_factor);
            seconds  = ((double)time * conversion_factor / 1e9);
            t->tv_sec = seconds;
            t->tv_nsec = nseconds;
            return 0;
        }

#   else

#       define clock_inittime()

#   endif

    static int lualib_get_preciseticks(lua_State *L)
    {
        struct timespec t;
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);
        lua_pushnumber(L, t.tv_sec*1000000000.0 + t.tv_nsec);
        return 1;
    }

    static int lualib_get_preciseseconds(lua_State *L)
    {
        lua_pushnumber(L, ((double) luaL_optnumber(L, 1, 0)) / 1000000000.0);
        return 1;
    }

# endif

static int lualib_get_startupfile(lua_State *L)
{
    lua_pushstring(L, lmt_engine_state.startup_filename);
    return 1;
}

static int lualib_get_version(lua_State *L)
{
    lua_pushstring(L, LUA_VERSION);
    return 1;
}

/* obsolete:
static int lualib_get_hashchars(lua_State *L)
{
    lua_pushinteger(L, 1 << LUAI_HASHLIMIT);
    return 1;
}
*/

/*
static int lualib_get_doing_the(lua_State *L)
{
    lua_pushboolean(L, lua_state.doing_the);
    return 1;
}
*/

/* This makes the (already old and rusty) profiler 2.5 times faster. */

/*
static lua_State *getthread (lua_State *L, int *arg) {
    if (lua_isthread(L, 1)) {
        *arg = 1;
        return lua_tothread(L, 1);
    } else {
       *arg = 0;
       return L;
    }
}

static int lualib_get_debug_info(lua_State *L) {
    lua_Debug ar;
    int arg;
    lua_State *L1 = getthread(L, &arg);
    if (lua_getstack(L1, 2, &ar) && lua_getinfo(L1, "nS", &ar)) {
        ....
    }
    return 0;
}
*/

/*
static int lualib_get_debug_info(lua_State *L) {
    if (! lua_isthread(L, 1)) {
        lua_Debug ar;
        if (lua_getstack(L, 2, &ar) && lua_getinfo(L, "nS", &ar)) {
            lua_pushstring(L, ar.short_src);
            lua_pushinteger(L, ar.linedefined);
            if (ar.name) {
                lua_pushstring(L, ar.name);
            } else if (! strcmp(ar.what, "C")) {
                lua_pushliteral(L, "<anonymous>");
            } else if (ar.namewhat) {
                lua_pushstring(L, ar.namewhat);
            } else if (ar.what) {
                lua_pushstring(L, ar.what);
            } else {
                lua_pushliteral(L, "<unknown>");
            }
            return 3;
        }
    }
    return 0;
}
*/

/*tex
    I can make it faster if needed but then I need to patch the two lua modules (add some simple
    helpers) which for now doesn't make much sense. This is an undocumented feature.
*/

static int lualib_get_debug_info(lua_State *L) {
    if (! lua_isthread(L, 1)) {
        lua_Debug ar;
        if (lua_getstack(L, 2, &ar) && lua_getinfo(L, "nS", &ar)) {
            lua_pushstring(L, ar.name ? ar.name : (ar.namewhat ? ar.namewhat : (ar.what ? ar.what : "<unknown>")));
            lua_pushstring(L, ar.short_src);
            lua_pushinteger(L, ar.linedefined);
            return 3;
        }
    }
    return 0;
}

/* */

static const struct luaL_Reg lualib_function_list[] = {
    { "newtable",            lualib_new_table           },
    { "newindex",            lualib_new_index           },
    { "getstacktop",         lualib_get_stack_top       },
    { "getruntime",          lualib_get_runtime         },
    { "getcurrenttime",      lualib_get_currenttime     },
    { "getpreciseticks",     lualib_get_preciseticks    },
    { "getpreciseseconds",   lualib_get_preciseseconds  },
    { "getbytecode",         lualib_get_bytecode        },
    { "setbytecode",         lualib_set_bytecode        },
    { "callbytecode",        lualib_call_bytecode       },
    { "getfunctionstable",   lualib_get_functions_table },
    { "getstartupfile",      lualib_get_startupfile     },
    { "getversion",          lualib_get_version         },
 /* { "gethashchars",        lualib_get_hashchars       }, */
    { "setexitcode",         lualib_set_exitcode        },
    { "getexitcode",         lualib_get_exitcode        },
 /* { "doingthe",            lualib_get_doing_the       }, */
    { "getdebuginfo",        lualib_get_debug_info      },
    { NULL,                  NULL                       },
};

static const struct luaL_Reg lualib_function_list_only[] = {
    { "newtable",            lualib_new_table          },
    { "newindex",            lualib_new_index          },
    { "getstacktop",         lualib_get_stack_top      },
    { "getruntime",          lualib_get_runtime        },
    { "getcurrenttime",      lualib_get_currenttime    },
    { "getpreciseticks",     lualib_get_preciseticks   },
    { "getpreciseseconds",   lualib_get_preciseseconds },
    { "getstartupfile",      lualib_get_startupfile    },
    { "getversion",          lualib_get_version        },
 /* { "gethashchars",        lualib_get_hashchars      }, */
    { "setexitcode",         lualib_set_exitcode       },
    { "getexitcode",         lualib_get_exitcode       },
    { NULL,                  NULL                      },
};

static int lualib_index_bytecode(lua_State *L)
{
    lua_remove(L, 1);
    return lualib_get_bytecode(L);
}

static int lualib_newindex_bytecode(lua_State *L)
{
    lua_remove(L, 1);
    return lualib_set_bytecode(L);
}

int luaopen_lua(lua_State *L)
{
    lua_newtable(L);
    if (lmt_engine_state.lua_only) {
        luaL_setfuncs(L, lualib_function_list_only, 0);
    } else {
        luaL_setfuncs(L, lualib_function_list, 0);
        lmt_make_table(L, "bytecode", LUA_BYTECODES, lualib_index_bytecode, lualib_newindex_bytecode);
        lua_newtable(L);
        lua_setfield(L, LUA_REGISTRYINDEX, LUA_BYTECODES_INDIRECT);
    }
    lua_pushstring(L, LUA_VERSION);
    lua_setfield(L, -2, "version");
    if (lmt_engine_state.startup_filename) {
        lua_pushstring(L, lmt_engine_state.startup_filename);
        lua_setfield(L, -2, "startupfile");
    }
    clock_inittime();
    return 1;
}
