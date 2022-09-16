/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

# if defined (_WIN32)
#   define MKDIR(a,b) mkdir(a)
# else
#   define MKDIR(a,b) mkdir(a,b)
# endif

/*tex

    An attempt to figure out the basic platform, does not care about niceties like version numbers
    yet, and ignores platforms where \LUATEX\ is unlikely to successfully compile without major
    porting effort (amiga,mac,os2,vms). We dropped solaris, cygwin, hpux, iris, sysv, dos, djgpp
    etc. Basically we have either a windows or some kind of unix brand.

*/

# ifdef _WIN32
#   define OSLIB_PLATTYPE "windows"
#   define OSLIB_PLATNAME "windows"
# else
#   include <sys/param.h>
#   include <sys/utsname.h>
#   if defined(__linux__) || defined (__gnu_linux__)
#     define OSLIB_PLATNAME "linux"
#   elif defined(__MACH__) && defined(__APPLE__)
#     define OSLIB_PLATNAME "macosx"
#   elif defined(__FreeBSD__)
#     define OSLIB_PLATNAME "freebsd"
#   elif defined(__OpenBSD__)
#     define OSLIB_PLATNAME "openbsd"
#   elif defined(__BSD__)
#     define OSLIB_PLATNAME "bsd"
#   elif defined(__GNU__)
#     define OSLIB_PLATNAME "gnu"
#   else
#     define OSLIB_PLATNAME "generic"
#   endif
#   define OSLIB_PLATTYPE "unix"
# endif

/*tex

    There could be more platforms that don't have these two, but win32 and sunos are for sure.
    |gettimeofday()| for win32 is using an alternative definition

*/

# ifndef _WIN32
#   include <sys/time.h>  /*tex for |gettimeofday()| */
#   include <sys/times.h> /*tex for |times()| */
#   include <sys/wait.h>
# endif

static int oslib_sleep(lua_State *L)
{
    lua_Number interval = luaL_checknumber(L, 1);
    lua_Number units = luaL_optnumber(L, 2, 1);
# ifdef _WIN32
    Sleep((DWORD) (1e3 * interval / units));
# else                           /* assumes posix or bsd */
    usleep((unsigned) (1e6 * interval / units));
# endif
    return 0;
}

# ifdef _WIN32

    # define _UTSNAME_LENGTH 65

    /*tex Structure describing the system and machine. */

    typedef struct utsname {
        char sysname [_UTSNAME_LENGTH];
        char nodename[_UTSNAME_LENGTH];
        char release [_UTSNAME_LENGTH];
        char version [_UTSNAME_LENGTH];
        char machine [_UTSNAME_LENGTH];
    } utsname;

    /*tex Get name and information about current kernel. */

    /*tex

        \starttabulate[|T|r|]
        \NC Windows 10                \NC 10.0 \NC \NR
        \NC Windows Server 2016       \NC 10.0 \NC \NR
        \NC Windows 8.1               \NC  6.3 \NC \NR
        \NC Windows Server 2012 R2    \NC  6.3 \NC \NR
        \NC Windows 8                 \NC  6.2 \NC \NR
        \NC Windows Server 2012       \NC  6.2 \NC \NR
        \NC Windows 7                 \NC  6.1 \NC \NR
        \NC Windows Server 2008 R2    \NC  6.1 \NC \NR
        \NC Windows Server 2008       \NC  6.0 \NC \NR
        \NC Windows Vista             \NC  6.0 \NC \NR
        \NC Windows Server 2003 R2    \NC  5.2 \NC \NR
        \NC Windows Server 2003       \NC  5.2 \NC \NR
        \NC Windows XP 64-Bit Edition \NC  5.2 \NC \NR
        \NC Windows XP                \NC  5.1 \NC \NR
        \NC Windows 2000              \NC  5.0 \NC \NR
        \stoptabulate

    */

    static int uname(struct utsname *uts)
    {
        OSVERSIONINFO osver;
        SYSTEM_INFO sysinfo;
        DWORD sLength;
        memset(uts, 0, sizeof(*uts));
        osver.dwOSVersionInfoSize = sizeof(osver);
        GetVersionEx(&osver);
        GetSystemInfo(&sysinfo);
        strcpy(uts->sysname, "Windows");
        sprintf(uts->version, "%ld.%02ld", osver.dwMajorVersion, osver.dwMinorVersion);
        if (osver.szCSDVersion[0] != '\0' && (strlen(osver.szCSDVersion) + strlen(uts->version) + 1) < sizeof(uts->version)) {
            strcat(uts->version, " ");
            strcat(uts->version, osver.szCSDVersion);
        }
        sprintf(uts->release, "build %ld", osver.dwBuildNumber & 0xFFFF);
        switch (sysinfo.wProcessorArchitecture) {
            case PROCESSOR_ARCHITECTURE_AMD64:
                strcpy(uts->machine, "x86_64");
                break;
# ifdef PROCESSOR_ARCHITECTURE_ARM64
            case PROCESSOR_ARCHITECTURE_ARM64:
                strcpy(uts->machine, "arm64");
                break;
# endif
            case PROCESSOR_ARCHITECTURE_INTEL:
                strcpy(uts->machine, "i386");
                break;
            default:
                strcpy(uts->machine, "unknown");
                break;
        }
        sLength = sizeof(uts->nodename) - 1;
        GetComputerName(uts->nodename, &sLength);
        return 0;
    }

# endif

static int oslib_uname(lua_State *L)
{
    struct utsname uts;
    if (uname(&uts) >= 0) {
        lua_createtable(L,0,5);
        lua_pushstring(L, uts.sysname);
        lua_setfield(L, -2, "sysname");
        lua_pushstring(L, uts.machine);
        lua_setfield(L, -2, "machine");
        lua_pushstring(L, uts.release);
        lua_setfield(L, -2, "release");
        lua_pushstring(L, uts.version);
        lua_setfield(L, -2, "version");
        lua_pushstring(L, uts.nodename);
        lua_setfield(L, -2, "nodename");
    } else {
        lua_pushnil(L);
    }
    return 1;
}

# if defined(_MSC_VER) || defined(_MSC_EXTENSIONS)
    # define DELTA_EPOCH_IN_MICROSECS  11644473600000000Ui64
# else
    # define DELTA_EPOCH_IN_MICROSECS  11644473600000000ULL
# endif

# ifdef _WIN32

    # ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
        # define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x04
    # endif

    static int oslib_gettimeofday(lua_State *L)
    {
        FILETIME ft;
        __int64 tmpres = 0;
        GetSystemTimeAsFileTime(&ft);
        tmpres |= ft.dwHighDateTime;
        tmpres <<= 32;
        tmpres |= ft.dwLowDateTime;
        tmpres /= 10;
        /*tex Convert file time to unix epoch: */
        tmpres -= DELTA_EPOCH_IN_MICROSECS;
        /*tex Float: */
        lua_pushnumber(L, (double) tmpres / 1000000.0);
        return 1;
    }

    static int oslib_enableansi(lua_State *L)
    {
        HANDLE handle = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD mode = 0;
        int done = 0;
        if (GetConsoleMode(handle, &mode)) {
            mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            if (SetConsoleMode(handle, mode)) {
                done = 1;
            } else {
                /* bad */
            }
        }
        lua_pushboolean(L, done);
        return 1;
    }

# else

    static int oslib_gettimeofday(lua_State *L)
    {
        double v;
        struct timeval tv;
        gettimeofday(&tv, NULL);
        v = (double) tv.tv_sec + (double) tv.tv_usec / 1000000.0;
        /*tex Float: */
        lua_pushnumber(L, v);
        return 1;
    }

    static int oslib_enableansi(lua_State *L)
    {
        lua_pushboolean(L, 1);
        return 1;
    }

# endif

/*tex Historically we have a different os.execute than Lua! */

static int oslib_execute(lua_State *L)
{
    const char *cmd = luaL_optstring(L, 1, NULL);
    if (cmd) {
        lua_pushinteger(L, aux_utf8_system(cmd) || lmt_error_state.default_exit_code);
    } else {
        lua_pushinteger(L, 0);
    }
    return 1;
}

# ifdef _WIN32

    static int oslib_remove (lua_State *L)
    {
        const char *filename = luaL_checkstring(L, 1);
        return luaL_fileresult(L, aux_utf8_remove(filename) == 0, filename);
    }

    static int oslib_rename (lua_State *L)
    {
        const char *fromname = luaL_checkstring(L, 1);
        const char *toname = luaL_checkstring(L, 2);
        return luaL_fileresult(L, aux_utf8_rename(fromname, toname) == 0, NULL);
    }

    static int oslib_getcodepage(lua_State *L)
    {
        lua_pushinteger(L, (int) GetOEMCP());
        lua_pushinteger(L, (int) GetACP());
        return 2;
    }

    /*
    static int oslib_getenv(lua_State *L) {
        LPWSTR wkey = utf8_to_wide(luaL_checkstring(L, 1));
        char * val = wide_to_utf8(_wgetenv(wkey));
        lmt_memory_free(wkey);
        lua_pushstring(L, val);
        lmt_memory_free(val);
        return 1;
    }
    */

    static int oslib_getenv(lua_State *L)
    {
        const char *key = luaL_checkstring(L, 1);
        char* val = NULL;
        if (key) {
            size_t wlen = 0;
            LPWSTR wkey = aux_utf8_to_wide(key);
            _wgetenv_s(&wlen, NULL, 0, wkey);
            if (wlen) {
                LPWSTR wval = (LPWSTR) lmt_memory_malloc(wlen * sizeof(WCHAR));
                if (!_wgetenv_s(&wlen, wval, wlen, wkey)) {
                    val = aux_utf8_from_wide(wval);
                }
            }
        }
        if (val) {
            lua_pushstring(L, val);
        } else {
            lua_pushnil(L);
        }
        return 1;
    }

    static int oslib_setenv(lua_State *L)
    {
        const char *key = luaL_optstring(L, 1, NULL);
        if (key) {
            LPWSTR wkey = aux_utf8_to_wide(key);
            const char *val = luaL_optstring(L, 2, NULL);
            if (val) {
                LPWSTR wval = aux_utf8_to_wide(val);
                if (_wputenv_s(wkey, wval)) {
                    return luaL_error(L, "unable to change environment");
                }
                lmt_memory_free(wval);
            } else {
                if (_wputenv_s(wkey, NULL)) {
                    return luaL_error(L, "unable to change environment");
                }
            }
            lmt_memory_free(wkey);
        }
        lua_pushboolean(L, 1);
        return 1;
    }

# else

    static int oslib_getcodepage(lua_State *L)
    {
        lua_pushboolean(L,0);
        lua_pushboolean(L,0);
        return 2;
    }

    static int oslib_setenv(lua_State *L)
    {
        const char *key = luaL_optstring(L, 1, NULL);
        if (key) {
            const char *val = luaL_optstring(L, 2, NULL);
            if (val) {
                char *value = lmt_memory_malloc((unsigned) (strlen(key) + strlen(val) + 2));
                sprintf(value, "%s=%s", key, val);
                if (putenv(value)) {
                 /* lmt_memory_free(value); */ /* valgrind reports some issue otherwise */
                    return luaL_error(L, "unable to change environment");
                } else {
                 /* lmt_memory_free(value); */ /* valgrind reports some issue otherwise */
                }
            } else {
                (void) unsetenv(key);
            }
        }
        lua_pushboolean(L, 1);
        return 1;
    }

# endif

static const luaL_Reg oslib_function_list[] = {
    { "sleep",        oslib_sleep        },
    { "uname",        oslib_uname        },
    { "gettimeofday", oslib_gettimeofday },
    { "setenv",       oslib_setenv       },
    { "execute",      oslib_execute      },
# ifdef _WIN32
    { "rename",       oslib_rename       },
    { "remove",       oslib_remove       },
    { "getenv",       oslib_getenv       },
# endif
    { "enableansi",   oslib_enableansi   },
    { "getcodepage",  oslib_getcodepage  },
    { NULL,           NULL               },
};


/*tex
    The |environ| variable is depricated on windows so it made sense to just drop this old \LUATEX\
    feature.
*/

# ifndef _WIN32
    extern char **environ;
# else
    # define environ _environ
# endif

int luaextend_os(lua_State *L)
{
    /*tex We locate the library: */
    lua_getglobal(L, "os");
    /*tex A few constant strings: */
    lua_pushliteral(L, OSLIB_PLATTYPE);
    lua_setfield(L, -2, "type");
    lua_pushliteral(L, OSLIB_PLATNAME);
    lua_setfield(L, -2, "name");
    /*tex The extra functions: */
    for (const luaL_Reg *lib = oslib_function_list; lib->name; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    /*tex Environment variables: */
    if (0) {
        char **envpointer = environ; /*tex Provided by the standard library. */
        if (envpointer) {
            lua_pushstring(L, "env");
            lua_newtable(L);
            while (*envpointer) {
                /* TODO: perhaps a memory leak here  */
                char *envitem = lmt_memory_strdup(*envpointer);
                char *envitem_orig = envitem;
                char *envkey = envitem;
                while (*envitem != '=') {
                    envitem++;
                }
                *envitem = 0;
                envitem++;
                lua_pushstring(L, envkey);
                lua_pushstring(L, envitem);
                lua_rawset(L, -3);
                envpointer++;
                lmt_memory_free(envitem_orig);
            }
            lua_rawset(L, -3);
        }
    }
    /*tex Done. */
    lua_pop(L, 1);
    return 1;
}
