/*
    See license.txt in the root of this project.
*/

/*tex

    In |lmtlualib| we introduced more precise timer support but there we stored the data in \LUA's
    64 bit integers. Here we use userdata. Again we delay division; see the other code for similar
    trickery. I will test this and when it's not more convenient (or used) we will not use it.
*/

# include <luametatex.h>
# include <stdint.h>
# include <stdbool.h>

/*
    In practice there is no real differenc unless we go into the millions. But it is anice example
    anyway so we keep it.

    1 = fastest
    2 = fast
    0 = regular

*/

# define timer_mt_method 1

typedef struct timer {
    uint64_t start;
    uint64_t total;
    uint32_t timing;
    uint32_t padding;
    uint64_t offset;
} timer;

# if defined(_WIN32) || defined(_WIN64)

    # include <windows.h>

    inline static uint64_t get_ticks(void)
    {
        LARGE_INTEGER counter;
        QueryPerformanceCounter(&counter);
        return (uint64_t) counter.QuadPart;
    }

    inline static double ticks_to_seconds(uint64_t ticks)
    {
        LARGE_INTEGER freq;
        QueryPerformanceFrequency(&freq);
        return ((double) ticks) / (double) freq.QuadPart;
    }

    inline static double ticks_to_milli_seconds(uint64_t ticks)
    {
        LARGE_INTEGER freq;
        QueryPerformanceFrequency(&freq);
        return ((double) ticks * 1000.0) / (double) freq.QuadPart;
    }

    inline static double ticks_to_micro_seconds(uint64_t ticks)
    {
        LARGE_INTEGER freq;
        QueryPerformanceFrequency(&freq);
        return ((double) ticks * 1000000.0) / (double) freq.QuadPart;
    }

# elif defined(__APPLE__)

    # include <mach/mach_time.h>

    inline static uint64_t get_ticks(void)
    {
        return mach_absolute_time();
    }

    inline static double ticks_to_seconds(uint64_t ticks)
    {
        static mach_timebase_info_data_t timebase;
        if (timebase.denom == 0) {
            mach_timebase_info(&timebase);
        }
        return ((double) ticks * timebase.numer / timebase.denom) / 1000000000.0;
    }

    inline static double ticks_to_milli_seconds(uint64_t ticks)
    {
        static mach_timebase_info_data_t timebase;
        if (timebase.denom == 0) {
            mach_timebase_info(&timebase);
        }
        return ((double) ticks * timebase.numer / timebase.denom) / 1000000.0;
    }

    inline static double ticks_to_micro_seconds(uint64_t ticks)
    {
        static mach_timebase_info_data_t timebase;
        if (timebase.denom == 0) {
            mach_timebase_info(&timebase);
        }
        return ((double) ticks * timebase.numer / timebase.denom) / 1000.0;
    }

# else /* POSIX */

    # include <time.h>

    inline static uint64_t get_ticks(void)
    {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        return ((uint64_t) ts.tv_sec * 1000000000ULL) + (uint64_t) ts.tv_nsec;
    }

    inline static double ticks_to_seconds(uint64_t ticks)
    {
        return (double) ticks / 1000000000.0;
    }

    inline static double ticks_to_milli_seconds(uint64_t ticks)
    {
        return (double) ticks / 1000000.0;
    }

    inline static double ticks_to_micro_seconds(uint64_t ticks)
    {
        return (double) ticks / 1000.0;
    }

# endif

# if timer_mt_method == 1

    static const void * G_TIMER_METATABLE_PTR = NULL;

    static inline timer * timerlib_aux_valid(lua_State *L, int i)
    {
        timer * t = lua_touserdata(L, i);
        if (t && lua_getmetatable(L, i)) {
            /* compare the stack top's raw C pointer directly against the cached pointer */
            if (lua_topointer(L, -1) != G_TIMER_METATABLE_PTR) {
                t = NULL;
            }
            lua_pop(L, 1); /* only 1 pop required */
        }
        return t;
    }

    static int timerlib_new(lua_State *L)
    {
        timer *t = lua_newuserdatauv(L, sizeof(timer), 0);
        if (t) {
            luaL_getmetatable(L, TIMER_METATABLE_INSTANCE);
            lua_setmetatable(L, -2);
            memset(t, 0, sizeof(timer));
        } else {
            tex_formatted_error("process lib", "out of memory");
            lua_pushnil(L);
        }
        return 1;
    }

# elif timer_mt_method == 2

    static inline timer * timerlib_aux_valid(lua_State *L, int i)
    {
        timer * t = lua_touserdata(L, i);
        if (t && lua_getmetatable(L, i)) {
            /* upvalue 1 holds the metatable directly */
            lua_pushvalue(L, lua_upvalueindex(1));
            if (! lua_rawequal(L, -1, -2)) {
                t = NULL;
            }
            lua_pop(L, 2);
        }
        return t;
    }

    static int timerlib_new(lua_State *L)
    {
        timer *t = lua_newuserdatauv(L, sizeof(timer), 0);
        if (t) {
            lua_pushvalue(L, lua_upvalueindex(1));
            lua_setmetatable(L, -2);
            memset(t, 0, sizeof(timer));
        } else {
            tex_formatted_error("process lib", "out of memory");
            lua_pushnil(L); /* never seen as we abort */
        }
        return 1;
    }

# else

    static inline timer * timerlib_aux_valid(lua_State *L, int i)
    {
        timer *t = lua_touserdata(L, i);
        if (t && lua_getmetatable(L, i)) {
            lua_get_metatablelua(timer_instance);
            if (! lua_rawequal(L, -1, -2)) {
                t = NULL;
            }
            lua_pop(L, 2);
        }
        return t;
    }

    static int timerlib_new(lua_State *L)
    {
        timer *t = lua_newuserdatauv(L, sizeof(timer), 0);
        if (t) {
            lua_get_metatablelua(timer_instance);
            lua_setmetatable(L, -2);
            memset(t, 0, sizeof(timer));
        } else {
            tex_formatted_error("process lib", "out of memory");
            lua_pushnil(L); /* never seen as we abort */
        }
        return 1;
    }

# endif

static int timerlib_start(lua_State *L)
{
   timer *t = timerlib_aux_valid(L, 1);
    if (t && ! t->timing) {
        t->start   = get_ticks();
        t->timing += 1;
        if (lua_toboolean(L, 2)) {
            t->total = 0;
        }
    }
    return 0;
}

static int timerlib_stop(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        if (t->timing == 1) {
            uint64_t stop = get_ticks();
            t->total  += (stop - t->start);
            t->timing  = 0;
            t->start   = 0;
        } else if (t->timing) {
            t->timing -= 1;
        }
    }
    return 0;
}

static int timerlib_reset(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        memset(t, 0, sizeof(timer));
    }
    return 0;
}

static int timerlib_setoffset(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t && t->start) {
        t->offset = lmt_optunsigned(L, 2, 0) * (get_ticks() - t->start);
    }
    return 0;
}

static int timerlib_istiming(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        lua_pushboolean(L, t->timing);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int timerlib_current(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        uint64_t total = t->total;
        if (t->timing) {
            total += (get_ticks() - t->start);
        }
        lua_pushnumber(L, ticks_to_seconds(total - t->offset));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int timerlib_elapsed(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        lua_pushnumber(L, ticks_to_seconds(t->total - t->offset));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int timerlib_elapsed_ms(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        lua_pushnumber(L, ticks_to_milli_seconds(t->total - t->offset));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int timerlib_elapsed_us(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        lua_pushnumber(L, ticks_to_micro_seconds(t->total - t->offset));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int timerlib_tostring(lua_State *L)
{
    timer *t = timerlib_aux_valid(L, 1);
    if (t) {
        lua_pushfstring(L, "<timer %p : %d>", t, t->timing);
        return 1;
    } else {
        return 0;
    }
}

/*tex
    The normal sleep function rounds and/or snap so on windows we only have some 15 ms
    accuracy. Each operating system has its interferences unless one goes for the more
    high resolution timers.
*/

# if defined(_WIN32) || defined(_WIN64)

    # include <windows.h>

    # ifndef CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
        # define CREATE_WAITABLE_TIMER_HIGH_RESOLUTION 0x00000002 /* older mingw */
    # endif

    inline static void timerlib_aux_sleep(uint32_t ms)
    {
        HANDLE hTimer = CreateWaitableTimerExW(
            NULL,
            NULL,
            TIMER_ALL_ACCESS | CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
            TIMER_ALL_ACCESS
        );
        if (hTimer) {
            /* a negative number is a relative time in 100-ns intervals */
            LARGE_INTEGER liDueTime;
            liDueTime.QuadPart = -(int64_t) ms * 10000LL;
            if (SetWaitableTimerEx(hTimer, &liDueTime, 0, NULL, NULL, NULL, 0)) {
                WaitForSingleObject(hTimer, INFINITE);
            } else {
                Sleep(ms);
            }
            CloseHandle(hTimer);
        } else {
            /* older windows, not that we use them */
            Sleep(ms);
        }
    }

# elif defined(__linux__)

    # include <time.h>
    # include <sys/prctl.h>

    inline static void timerlib_aux_sleep(uint32_t ms)
    {
        # ifdef PR_SET_TIMERSLACK
            prctl(PR_SET_TIMERSLACK, 1UL, 0, 0, 0); /* no auto-rounding */
        # endif
        struct timespec ts;
        ts.tv_sec  = ms / 1000;
        ts.tv_nsec = (ms % 1000) * 1000000UL;
        clock_nanosleep(CLOCK_MONOTONIC, 0, &ts, NULL); /* avoid NTP interference */
    }

# elif defined(__APPLE__)

    # include <time.h>

    inline static void timerlib_aux_sleep(uint32_t ms)
    {
        struct timespec ts;
        ts.tv_sec  = ms / 1000;
        ts.tv_nsec = (ms % 1000) * 1000000UL;
        nanosleep(&ts, NULL);
    }

# else /* POSIX */

    # include <unistd.h>

    inline static void timerlib_aux_sleep(uint32_t ms)
    {
        usleep(ms * 1000);
    }

# endif

static int timerlib_sleepms(lua_State *L)
{
    timerlib_aux_sleep((uint32_t) lua_tointeger(L, 1));
    return 0;
}

static const struct luaL_Reg timerlib_function_list[] = {
    /* management */
    { "new",       timerlib_new        },
    { "start",     timerlib_start      },
    { "stop",      timerlib_stop       },
    { "reset",     timerlib_reset      },
    { "setoffset", timerlib_setoffset  },
    { "istiming",  timerlib_istiming   },
    { "current",   timerlib_current    },
    { "elapsed",   timerlib_elapsed    },
    { "elapsedms", timerlib_elapsed_ms },
    { "elapsedus", timerlib_elapsed_us },
    { "elapsedμs", timerlib_elapsed_us }, /* easter egg */
    { "tostring",  timerlib_tostring   },
    /* */
    { "sleepms",   timerlib_sleepms    },
    /* */
    { NULL,        NULL                },
};

# if timer_mt_method == 1

    int luaopen_timer(lua_State *L)
    {
        luaL_newmetatable(L, TIMER_METATABLE_INSTANCE);

        G_TIMER_METATABLE_PTR = lua_topointer(L, -1);

        lua_newtable(L);
        luaL_setfuncs(L, timerlib_function_list, 0);

        lua_pushliteral(L, "__index");
        lua_pushvalue(L, -2);
        lua_settable(L, -3);

        lua_pushliteral(L, "__tostring");
        lua_pushliteral(L, "tostring");
        lua_gettable(L, -3);
        lua_settable(L, -3);

        lua_pushliteral(L, "__name");
        lua_pushliteral(L, "timer");
        lua_settable(L, -3);

        return 1;
    }

# elif timer_mt_method == 2

    int luaopen_timer(lua_State *L)
    {
        luaL_newmetatable(L, TIMER_METATABLE_INSTANCE);
        lua_newtable(L);
        lua_pushvalue(L, -2);
        luaL_setfuncs(L, timerlib_function_list, 1); /* upvalue 1 */

        lua_pushliteral(L, "__index");
        lua_pushvalue(L, -2);
        lua_settable(L, -4);

        lua_pushliteral(L, "__tostring");
        lua_pushliteral(L, "tostring");
        lua_gettable(L, -3);
        lua_settable(L, -4);

        lua_pushliteral(L, "__name");
        lua_pushliteral(L, "timer");
        lua_settable(L, -4);

        lua_remove(L, -2); /* remove metatable */ /* no need to store it */
        return 1;
    }

# else

    int luaopen_timer(lua_State *L)
    {
        luaL_newmetatable(L, TIMER_METATABLE_INSTANCE);
        lua_newtable(L);
        luaL_setfuncs(L, timerlib_function_list, 0);

        lua_pushliteral(L, "__index");
        lua_pushvalue(L, -2);
        lua_settable(L, -3);

        lua_pushliteral(L, "__tostring");
        lua_pushliteral(L, "tostring");
        lua_gettable(L, -3);
        lua_settable(L, -3);

        lua_pushliteral(L, "__name");
        lua_pushliteral(L, "timer");
        lua_settable(L, -3);

        return 1;
    }

# endif