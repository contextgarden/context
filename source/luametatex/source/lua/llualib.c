/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

# define LOAD_BUF_SIZE 64*1024
# define UINT_MAX32    0xFFFFFFFF

typedef struct {
    unsigned char *buf;
    int size;
    int alloc;
} bytecode;

static bytecode *lua_bytecode_registers = NULL;

void dump_luac_registers(void)
{
    dump_int(lua_state.bytecode_max);
    if (lua_bytecode_registers != NULL) {
        int n = 0;
        int k = 0;
        for (; k <= lua_state.bytecode_max; k++) {
            if (lua_bytecode_registers[k].size != 0)
                n++;
        }
        dump_int(n);
        for (k = 0; k <= lua_state.bytecode_max; k++) {
            bytecode b = lua_bytecode_registers[k];
            if (b.size != 0) {
                dump_int(k);
                dump_int(b.size);
                do_zdump((char *) b.buf, 1, (b.size));
            }
        }
    }
}

void undump_luac_registers(void)
{
    undump_int(lua_state.bytecode_max);
    if (lua_state.bytecode_max >= 0) {
        bytecode b;
        int k, x, n;
        int i = (unsigned) (lua_state.bytecode_max + 1);
        if ((int) (UINT_MAX32 / (int) sizeof(bytecode) + 1) <= i) {
            fatal_error("Corrupt format file");
        }
        lua_bytecode_registers = malloc((unsigned) (i * sizeof(bytecode)));
        lua_state.bytecode_bytes = (unsigned) (i * sizeof(bytecode));
        for (i = 0; i <= lua_state.bytecode_max; i++) {
            lua_bytecode_registers[i].size = 0;
            lua_bytecode_registers[i].buf = NULL;
        }
        undump_int(n);
        for (i = 0; i < n; i++) {
            undump_int(k);
            undump_int(x);
            b.size = x;
            b.buf = malloc((unsigned) b.size);
            lua_state.bytecode_bytes += (unsigned) b.size;
            memset(b.buf, 0, (size_t) b.size);
            do_zundump((char *) b.buf, 1, b.size);
            lua_bytecode_registers[k].size = b.size;
            lua_bytecode_registers[k].alloc = b.size;
            lua_bytecode_registers[k].buf = b.buf;
        }
    }
}

static void bytecode_register_shadow_set(lua_State * L, int k)
{
    /*tex the stack holds the value to be set */
    lua_get_metatablelua(lua_bytecodes_indirect);
    if (lua_istable(L, -1)) {
        lua_pushvalue(L, -2);
        lua_rawseti(L, -2, k);
    }
    lua_pop(L, 1); /*tex pop table or nil */
    lua_pop(L, 1); /*tex pop value */
}

static int bytecode_register_shadow_get(lua_State * L, int k)
{
    /*tex the stack holds the value to be set */
    int ret = 0;
    lua_get_metatablelua(lua_bytecodes_indirect);
    if (lua_istable(L, -1)) {
        lua_rawgeti(L, -1, k);
        if (!lua_isnil(L, -1))
            ret = 1;
        /*tex store the value or nil, deeper down  */
        lua_insert(L, -3);
        /*tex pop the value or nil at top */
        lua_pop(L, 1);
    }
    /*tex pop table or nil */
    lua_pop(L, 1);
    return ret;
}

static int writer(lua_State * L, const void *b, size_t size, void *B)
{
    bytecode *buf = (bytecode *) B;
    (void) L; /*tex for |-Wunused| */
    if ((int) (buf->size + (int) size) > buf->alloc) {
        buf->buf = realloc(buf->buf, (unsigned) (buf->alloc + (int) size + LOAD_BUF_SIZE));
        buf->alloc = buf->alloc + (int) size + LOAD_BUF_SIZE;
    }
    memcpy(buf->buf + buf->size, b, size);
    buf->size += (int) size;
    lua_state.bytecode_bytes += (unsigned) size;
    return 0;
}

static const char *reader(lua_State * L, void *ud, size_t * size)
{
    bytecode *buf = (bytecode *) ud;
    (void) L; /*tex for |-Wunused| */
    *size = (size_t) buf->size;
    return (const char *) buf->buf;
}

static int get_bytecode(lua_State * L)
{
    int k;
    k = (int) luaL_checkinteger(L, -1);
    if (k < 0) {
        lua_pushnil(L);
    } else if (!bytecode_register_shadow_get(L, k)) {
        if (k <= lua_state.bytecode_max && lua_bytecode_registers[k].buf != NULL) {
            if (lua_load(L, reader, (void *) (lua_bytecode_registers + k), "bytecode", NULL)) {
                return luaL_error(L, "bad bytecode register");
            } else {
                lua_pushvalue(L, -1);
                bytecode_register_shadow_set(L, k);
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

void luabytecodecall(int slot)
{
    int i;
    int stacktop = lua_gettop(Luas);
    if (slot < 0 || slot > lua_state.bytecode_max) {
        luaL_error(Luas, "bytecode register out of range");
    } else if (bytecode_register_shadow_get(Luas, slot) || lua_bytecode_registers[slot].buf == NULL) {
        luaL_error(Luas, "undefined bytecode register");
    } else if (lua_load(Luas, reader, (void *) (lua_bytecode_registers + slot),"bytecode", NULL)) {
        luaL_error(Luas, "bytecode register doesn't load well");
    } else {
        /*tex function index */
        int base = lua_gettop(Luas);
        lua_pushinteger(Luas, slot);
        /*tex push traceback function */
        lua_pushcfunction(Luas, lua_traceback);
        /*tex put it under chunk  */
        lua_insert(Luas, base);
        ++lua_state.function_callback_count;
        i = lua_pcall(Luas, 1, 0, base);
        /*tex remove traceback function */
        lua_remove(Luas, base);
        if (i != 0) {
            lua_gc(Luas, LUA_GCCOLLECT, 0);
            luatex_error(Luas, (i == LUA_ERRRUN ? 0 : 1));
        }
    }
    lua_settop(Luas,stacktop);
}

static int set_bytecode(lua_State * L)
{
    int k, ltype;
    unsigned int i;
    int strip = 0;
    int top = lua_gettop(L);
    if (lua_type(L,top) == LUA_TBOOLEAN) {
        strip = lua_toboolean(L,top);
        lua_settop(L,top - 1);
    }
    k = (int) luaL_checkinteger(L, -2);
    i = (unsigned) k + 1;
    if ((int) (UINT_MAX32 / sizeof(bytecode) + 1) < i) {
        luaL_error(L, "value too large");
    }
    if (k < 0) {
        luaL_error(L, "negative values not allowed");
    }
    ltype = lua_type(L, -1);
    if (ltype != LUA_TFUNCTION && ltype != LUA_TNIL) {
        luaL_error(L, "unsupported type");
    }
    if (k > lua_state.bytecode_max) {
        i = (unsigned) (sizeof(bytecode) * ((unsigned) k + 1));
        lua_bytecode_registers = realloc(lua_bytecode_registers, i);
        if (lua_state.bytecode_max == -1) {
            lua_state.bytecode_bytes +=
                (unsigned) (sizeof(bytecode) * (unsigned) (k + 1));
        } else {
            lua_state.bytecode_bytes +=
                (unsigned) (sizeof(bytecode) *
                            (unsigned) (k + 1 - lua_state.bytecode_max));
        }
        for (i = (unsigned) (lua_state.bytecode_max + 1); i <= (unsigned) k; i++) {
            lua_bytecode_registers[i].buf = NULL;
            lua_bytecode_registers[i].size = 0;
        }
        lua_state.bytecode_max = k;
    }
    if (lua_bytecode_registers[k].buf != NULL) {
        free(lua_bytecode_registers[k].buf);
        lua_state.bytecode_bytes -= (unsigned) lua_bytecode_registers[k].size;
        lua_bytecode_registers[k].size = 0;
        lua_bytecode_registers[k].buf = NULL;
        lua_pushnil(L);
        bytecode_register_shadow_set(L, k);
    }
    if (ltype == LUA_TFUNCTION) {
        lua_bytecode_registers[k].buf = malloc(LOAD_BUF_SIZE);
        lua_bytecode_registers[k].alloc = LOAD_BUF_SIZE;
        memset(lua_bytecode_registers[k].buf, 0, LOAD_BUF_SIZE);
        lua_dump(L, writer, (void *) (lua_bytecode_registers + k),strip);
    }
    lua_pop(L, 1);
    return 0;
}

void initialize_functions(int set_size)
{
    if (set_size) {
        get_lua_number("texconfig", "function_size", &lua_state.function_table_size);
        if (lua_state.function_table_size < 0) {
            lua_state.function_table_size = 0;
        }
        lua_createtable(Luas,lua_state.function_table_size,0);
    } else {
        lua_newtable(Luas);
    }
    lua_state.function_table_id = luaL_ref(Luas, LUA_REGISTRYINDEX);
    /* not needed, so unofficial */
    lua_pushstring(Luas,"lua.functions");
    lua_rawgeti(Luas, LUA_REGISTRYINDEX, lua_state.function_table_id);
    lua_settable(Luas,LUA_REGISTRYINDEX);
}

static int get_functions_table(lua_State * L)
{
    if (lua_toboolean(L,lua_gettop(L))) {
        /*tex Beware: this can have side effects when used without care. */
        initialize_functions(1);
    }
    lua_rawgeti(Luas, LUA_REGISTRYINDEX, lua_state.function_table_id);
    return 1;
}

static int new_table(lua_State * L)
{
    int i = (int) luaL_checkinteger(L, 1);
    int h = (int) luaL_checkinteger(L, 2);
    lua_createtable(L,i,h);
    return 1;
}

static int new_index(lua_State * L)
{
    int n = (int) luaL_checkinteger(L, 1);
    int t = lua_gettop(L);
    lua_createtable(L,n,0);
    if (t == 2) {
        int i;
        for (i=1;i<=n;i++) {
            lua_pushvalue(L,2);
            lua_rawseti(L,-2,i);
        }
    }
    return 1;
}

static int get_stack_top(lua_State * L)
{
    lua_pushinteger(L, lua_gettop(L));
    return 1;
}

static int get_runtime(lua_State * L)
{
    lua_pushnumber(L, get_run_time());
    return 1;
}

static int get_currenttime(lua_State * L)
{
    lua_pushnumber(L, get_current_time());
    return 1;
}

static int set_exitcode(lua_State * L)
{
    error_state.defaultexitcode = luaL_checkinteger(L,1);
    return 0;
}

/*tex

The |getpreciseticks()| call returns a number. This number has no meaning in
itself but successive calls can be used to calculate a delta with a previous
call. When the number is fed into |getpreciseseconds(n)| a number is returned
representing seconds.

*/

# ifdef _WIN32

   static int get_preciseticks(lua_State * L)
    {
        LARGE_INTEGER t;
        QueryPerformanceCounter(&t);
        lua_pushnumber(L, (double) t.QuadPart);
        return 1;
    }

    static int get_preciseseconds(lua_State * L)
    {
        LARGE_INTEGER t;
        QueryPerformanceFrequency(&t);
        lua_pushnumber(L, luaL_optnumber(L,1,0)/(double) t.QuadPart);
        return 1;
    }

# else

#   ifdef __MACH__

        /* https://stackoverflow.com/questions/5167269/clock-gettime-alternative-in-mac-os-x */

#       include <mach/mach_time.h>
#       define CLOCK_PROCESS_CPUTIME_ID 1

        static double conversion_factor;

        void clock_inittime()
        {
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);
            conversion_factor = (double)timebase.numer / (double)timebase.denom;
        }

        static int clock_gettime(int clk_id, struct timespec *t)
        {
            uint64_t time;
            (void) clk_id; /* please the compiler */
            time = mach_absolute_time();
            double nseconds = ((double)time * conversion_factor);
            double seconds  = ((double)time * conversion_factor / 1e9);
            t->tv_sec = seconds;
            t->tv_nsec = nseconds;
            return 0;
        }

#   endif

    static int get_preciseticks(lua_State * L)
    {
        struct timespec t;
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);
        lua_pushnumber(L,t.tv_sec*1000000000.0 + t.tv_nsec);
        return 1;
    }

    static int get_preciseseconds(lua_State * L)
    {
        lua_pushnumber(L, ((double) luaL_optnumber(L,1,0))/1000000000.0);
        return 1;
    }

# endif

static int get_startupfile(lua_State * L)
{
    lua_pushstring(L, engine_state.startup_filename);
    return 1;
}

static int get_version(lua_State * L)
{
    lua_pushstring(L, LUA_VERSION);
    return 1;
}

/* */

static const struct luaL_Reg lualib[] = {
    { "newtable",            new_table },
    { "newindex",            new_index },
    { "getstacktop",         get_stack_top },
    { "getruntime",          get_runtime },
    { "getcurrenttime",      get_currenttime },
    { "getpreciseticks",     get_preciseticks },
    { "getpreciseseconds",   get_preciseseconds },
    { "setexitcode",         set_exitcode },
    { "getbytecode",         get_bytecode },
    { "setbytecode",         set_bytecode },
    { "getfunctionstable",   get_functions_table },
    { "get_functions_table", get_functions_table }, /* this will go */
    { "getstartupfile",      get_startupfile },
    { "getversion",          get_version },
    { NULL,                  NULL }
};

static const struct luaL_Reg luaonlylib[] = {
    { "newtable",            new_table },
    { "newindex",            new_index },
    { "getstacktop",         get_stack_top },
    { "getruntime",          get_runtime },
    { "getcurrenttime",      get_currenttime },
    { "getpreciseticks",     get_preciseticks },
    { "getpreciseseconds",   get_preciseseconds },
    { "getstartupfile",      get_startupfile },
    { "getversion",          get_version },
 /* { "setexitcode",         set_exitcode }, */
    { NULL,                  NULL }
};

int luaopen_lua(lua_State * L)
{
    lua_newtable(L);
    if (engine_state.lua_only) {
        luaL_setfuncs(L, luaonlylib, 0);
    } else {
        luaL_setfuncs(L, lualib, 0);
        make_table(L, "bytecode", "tex.bytecode", "getbytecode", "setbytecode");
        lua_newtable(L);
        lua_setfield(L, LUA_REGISTRYINDEX, "lua.bytecodes.indirect");
    }
    lua_pushstring(L, LUA_VERSION);
    lua_setfield(L, -2, "version");
    if (engine_state.startup_filename != NULL) {
        lua_pushstring(L, engine_state.startup_filename);
        lua_setfield(L, -2, "startupfile");
    }
#   ifdef __MACH__
    clock_inittime();
#   endif
    return 1;
}
