/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

# if defined(_WIN32) || defined(__NT__)
#   define MKDIR(a,b) mkdir(a)
# else
#   define MKDIR(a,b) mkdir(a,b)
# endif

/*tex

    An attempt to figure out the basic platform, does not care about niceties
    like version numbers yet, and ignores platforms where \LUATEX\ is unlikely to
    successfully compile without major prorting effort (amiga,mac,os2,vms).

    We drop solaris, cygwin, hpux, iris, sysv, dos, djgpp etc. Basically we have
    either a windows or some kind of unix brand.

*/

# if defined(_WIN32)
#   define OS_PLATTYPE "windows"
#   define OS_PLATNAME "windows"
# else
#   include <sys/param.h>
#   include <sys/utsname.h>
#   if defined(__linux__) || defined (__gnu_linux__)
#     define OS_PLATNAME "linux"
#   elif defined(__MACH__) && defined(__APPLE__)
#     define OS_PLATNAME "macosx"
#   elif defined(__FreeBSD__)
#     define OS_PLATNAME "freebsd"
#   elif defined(__OpenBSD__)
#     define OS_PLATNAME "openbsd"
#   elif defined(__BSD__)
#     define OS_PLATNAME "bsd"
#   elif defined(__GNU__)
#     define OS_PLATNAME "gnu"
#   else
#     define OS_PLATNAME "generic"
#   endif
#   define OS_PLATTYPE "unix"
# endif

/*tex

    There could be more platforms that don't have these two, but win32 and sunos
    are for sure. |gettimeofday()| for win32 is using an alternative definition

*/

# ifndef _WIN32
#   include <sys/time.h>  /*tex for |gettimeofday()| */
#   include <sys/times.h> /*tex for |times()| */
#   include <sys/wait.h>
# endif

static int os_setenv(lua_State * L)
{
    const char *key = luaL_optstring(L, 1, NULL);
    if (key) {
        const char *val = luaL_optstring(L, 2, NULL);
        if (val) {
            char *value = malloc((unsigned) (strlen(key) + strlen(val) + 2));
            sprintf(value, "%s=%s", key, val);
            if (putenv(value)) {
                return luaL_error(L, "unable to change environment");
            }
        } else {
# ifdef _WIN32
            char *value = malloc(strlen(key) + 2);
            sprintf(value, "%s=", key);
            if (putenv(value)) {
                return luaL_error(L, "unable to change environment");
            }
# else
            (void) unsetenv(key);
# endif
        }
    }
    lua_pushboolean(L, 1);
    return 1;
}

static void find_env(lua_State * L)
{
    char **envpointer = environ; /* When is this one set? */
    lua_getglobal(L, "os");
    if (envpointer != NULL && lua_istable(L, -1)) {
        char *envitem, *envitem_orig, *envkey;
        luaL_checkstack(L, 2, "out of stack space");
        lua_pushstring(L, "env");
        lua_newtable(L);
        while (*envpointer) {
            /* TODO: perhaps a memory leak here  */
            luaL_checkstack(L, 2, "out of stack space");
            envitem = strdup(*envpointer);
            envitem_orig = envitem;
            envkey = envitem;
            while (*envitem != '=') {
                envitem++;
            }
            *envitem = 0;
            envitem++;
            lua_pushstring(L, envkey);
            lua_pushstring(L, envitem);
            lua_rawset(L, -3);
            envpointer++;
            free(envitem_orig);
        }
        lua_rawset(L, -3);
    }
    lua_pop(L, 1);
}

static int ex_sleep(lua_State * L)
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

struct utsname {
    char sysname[_UTSNAME_LENGTH];
    char nodename[_UTSNAME_LENGTH];
    char release[_UTSNAME_LENGTH];
    char version[_UTSNAME_LENGTH];
    char machine[_UTSNAME_LENGTH];
};

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
    enum { WinNT, Win95, Win98, WinUnknown };
    OSVERSIONINFO osver;
    SYSTEM_INFO sysinfo;
    DWORD sLength;
    DWORD os = WinUnknown;
    memset(uts, 0, sizeof(*uts));
    osver.dwOSVersionInfoSize = sizeof(osver);
    GetVersionEx(&osver);
    GetSystemInfo(&sysinfo);
    switch (osver.dwPlatformId) {
        case VER_PLATFORM_WIN32_NT:
            if (osver.dwMajorVersion == 4)
                strcpy(uts->sysname, "Windows NT 4");
            else if (osver.dwMajorVersion <= 3)
                strcpy(uts->sysname, "Windows NT 3");
            else if (osver.dwMajorVersion == 5) {
                if (osver.dwMinorVersion == 0)
                    strcpy(uts->sysname, "Windows 2000");
                else if (osver.dwMinorVersion == 1)
                    strcpy(uts->sysname, "Windows XP");
                else if (osver.dwMinorVersion == 2)
                    strcpy(uts->sysname, "Windows XP 64-Bit");
            } else if (osver.dwMajorVersion == 6) {
                if (osver.dwMinorVersion == 0)
                    strcpy(uts->sysname, "Windows Vista");
                else if (osver.dwMinorVersion == 1)
                    strcpy(uts->sysname, "Windows 7");
                else if (osver.dwMinorVersion == 2)
                    strcpy(uts->sysname, "Windows 8");
                else if (osver.dwMinorVersion == 3)
                    strcpy(uts->sysname, "Windows 8.1");
            } else if (osver.dwMajorVersion == 10) {
                    strcpy(uts->sysname, "Windows 10");
            }
            os = WinNT;
            break;
        case VER_PLATFORM_WIN32_WINDOWS:
            if ((osver.dwMajorVersion > 4) || ((osver.dwMajorVersion == 4) && (osver.dwMinorVersion > 0))) {
                if (osver.dwMinorVersion >= 90)
                    strcpy(uts->sysname, "Windows ME");
                else
                    strcpy(uts->sysname, "Windows 98");
                os = Win98;
            } else {
                strcpy(uts->sysname, "Windows 95");
                os = Win95;
            }
            break;
        case VER_PLATFORM_WIN32s:
            /* Windows 3.x */
            strcpy(uts->sysname, "Windows");
            break;
        default:
            strcpy(uts->sysname, "Windows");
            break;
    }
    sprintf(uts->version, "%ld.%02ld", osver.dwMajorVersion, osver.dwMinorVersion);
    if (osver.szCSDVersion[0] != '\0' && (strlen(osver.szCSDVersion) + strlen(uts->version) + 1) < sizeof(uts->version)) {
        strcat(uts->version, " ");
        strcat(uts->version, osver.szCSDVersion);
    }
    sprintf(uts->release, "build %ld", osver.dwBuildNumber & 0xFFFF);
    switch (sysinfo.wProcessorArchitecture) {
        case PROCESSOR_ARCHITECTURE_PPC:
            strcpy(uts->machine, "ppc");   /* obsolete */
            break;
        case PROCESSOR_ARCHITECTURE_ALPHA:
            strcpy(uts->machine, "alpha"); /* obsolete */
            break;
        case PROCESSOR_ARCHITECTURE_MIPS:
            strcpy(uts->machine, "mips");  /* obsolete */
            break;
        case PROCESSOR_ARCHITECTURE_INTEL:
            /*tex
                |dwProcessorType| is only valid in |Win95| and |Win98| and |WinME|
                |wProcessorLevel| is only valid in |WinNT|
             */
            switch (os) {
                case Win95:
                case Win98:
                    switch (sysinfo.dwProcessorType) {
                        case PROCESSOR_INTEL_386:
                        case PROCESSOR_INTEL_486:
                        case PROCESSOR_INTEL_PENTIUM:
                            sprintf(uts->machine, "i%ld", sysinfo.dwProcessorType);
                            break;
                        default:
                            strcpy(uts->machine, "i386");
                            break;
                        }
                        break;
                    case WinNT:
                        sprintf(uts->machine, "i%d86", sysinfo.wProcessorLevel);
                        break;
                    default:
                        strcpy(uts->machine, "unknown");
                        break;
                }
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

static int ex_uname(lua_State * L)
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
#   define DELTA_EPOCH_IN_MICROSECS  11644473600000000Ui64
# else
#   define DELTA_EPOCH_IN_MICROSECS  11644473600000000ULL
# endif

# ifndef _WIN32

    static int os_gettimeofday(lua_State * L)
    {
        double v;
        struct timeval tv;
        gettimeofday(&tv, NULL);
        v = (double) tv.tv_sec + (double) tv.tv_usec / 1000000.0;
        /*tex Float: */
        lua_pushnumber(L, v);
        return 1;
    }

# else

    static int os_gettimeofday(lua_State * L)
    {
        double v;
        FILETIME ft;
        integer64 tmpres = 0;
        GetSystemTimeAsFileTime(&ft);
        tmpres |= ft.dwHighDateTime;
        tmpres <<= 32;
        tmpres |= ft.dwLowDateTime;
        tmpres /= 10;
        /*tex Convert file time to unix epoch: */
        tmpres -= DELTA_EPOCH_IN_MICROSECS;
        v = (double) tmpres / 1000000.0;
        /*tex Float: */
        lua_pushnumber(L, v);
        return 1;
    }

# endif

static int os_execute(lua_State * L)
{
    const char *cmd = luaL_optstring(L, 1, NULL);
    if (cmd == NULL) {
        lua_pushinteger(L, 0);
    } else {
        lua_pushinteger(L, system(cmd));
    }
    return 1;
}

int luaextend_os(lua_State * L)
{
    find_env(L);
    lua_getglobal(L, "os");
    lua_pushcfunction(L, ex_sleep);
    lua_setfield(L, -2, "sleep");
    lua_pushliteral(L, OS_PLATTYPE);
    lua_setfield(L, -2, "type");
    lua_pushliteral(L, OS_PLATNAME);
    lua_setfield(L, -2, "name");
    lua_pushcfunction(L, ex_uname);
    lua_setfield(L, -2, "uname");
    lua_pushcfunction(L, os_gettimeofday);
    lua_setfield(L, -2, "gettimeofday");
    lua_pushcfunction(L, os_setenv);
    lua_setfield(L, -2, "setenv");
    lua_pushcfunction(L, os_execute);
    lua_setfield(L, -2, "execute");
    lua_pop(L, 1);
    return 1;
}
