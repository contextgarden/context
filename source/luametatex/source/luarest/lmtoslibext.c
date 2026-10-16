/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

# if defined (_WIN32)
#   define MKDIR(a,b) mkdir(a)
# else
#   define MKDIR(a,b) mkdir(a,b)
# endif

# ifndef _WIN32
    extern char **environ;
# else
    # define environ _environ
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

static int oslib_gettypevalues(lua_State *L)
{
    lua_createtable(L, 2, 0);
    lua_set_string_by_index(L, 1, "windows");
    lua_set_string_by_index(L, 2, "unix");
    return 1;
}

static int oslib_getnamevalues(lua_State *L)
{
    lua_createtable(L, 7, 0);
    lua_set_string_by_index(L, 1, "windows");
    lua_set_string_by_index(L, 2, "linux");
    lua_set_string_by_index(L, 3, "macosx");
    lua_set_string_by_index(L, 4, "freebsd");
    lua_set_string_by_index(L, 5, "bsd");
    lua_set_string_by_index(L, 6, "gnu");
    lua_set_string_by_index(L, 7, "generic");
    return 1;
}

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
        GetSystemInfo(&sysinfo);
        strcpy(uts->sysname, "Windows");
        /*tex When |GetVersionEx| becomes obsolete the version and release fields will be set to "". */
     // if (0) {
     //     GetVersionEx(&osver);
     //     sprintf(uts->version, "%ld.%02ld", osver.dwMajorVersion, osver.dwMinorVersion);
     //     if (osver.szCSDVersion[0] != '\0' && (strlen(osver.szCSDVersion) + strlen(uts->version) + 1) < sizeof(uts->version)) {
     //         strcat(uts->version, " ");
     //         strcat(uts->version, osver.szCSDVersion);
     //     }
     //     sprintf(uts->release, "build %ld", osver.dwBuildNumber & 0xFFFF);
     // } else { 
            /*tex I can't motivate myself to figure this out. */
            strcpy(uts->version, "");
            strcpy(uts->release, "");
     // }
        /*tex So far for the fragile and actually not that relevant part of |uts|. */
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

static int oslib_getunamefields(lua_State *L)
{
    lua_createtable(L, 5, 0);
    lua_set_string_by_index(L, 1, "sysname");
    lua_set_string_by_index(L, 2, "machine");
    lua_set_string_by_index(L, 3, "release");
    lua_set_string_by_index(L, 4, "version");
    lua_set_string_by_index(L, 5, "nodename");
    return 1;
}

static int oslib_uname(lua_State *L)
{
    struct utsname uts;
    if (uname(&uts) >= 0) { /* always true */
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
        # define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
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

# endif

# ifdef _WIN32

    static int oslib_enableansi(lua_State *L)
    {
        int done = 0;
        HANDLE out_handle = GetStdHandle(STD_OUTPUT_HANDLE);
        HANDLE err_handle = GetStdHandle(STD_ERROR_HANDLE);
        if (out_handle != INVALID_HANDLE_VALUE && out_handle != NULL) {
            DWORD mode = 0;
            if (GetConsoleMode(out_handle, &mode)) {
                SetConsoleMode(out_handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
                done = 1;
            }
        }
        if (err_handle != INVALID_HANDLE_VALUE && err_handle != NULL) {
            DWORD mode = 0;
            if (GetConsoleMode(err_handle, &mode)) {
                SetConsoleMode(err_handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
                done = 1;
            }
        }
        lua_pushboolean(L, done);
        return 1;
    }

# else

    static int oslib_enableansi(lua_State *L)
    {
        lua_pushboolean(L, 1);
        return 1;
    }

# endif

/*tex Historically we have a different os.execute than Lua! */

static int oslib_execute(lua_State *L)
{
    const char *cmd = lmt_optstring(L, 1, NULL);
    int okay = 0;
    if (cmd && lmt_valid_target(L, security_executable, cmd, security_run_executable)) {
        okay = aux_utf8_system(cmd) || lmt_error_state.default_exit_code;
    }
    lua_pushinteger(L, okay);
    return 1;
}

static int oslib_remove(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    return luaL_fileresult(L, lmt_valid_target(L, security_writeable, filename, security_remove_file) ? aux_utf8_remove(filename) == 0 : 0, filename);
}

static int oslib_rename(lua_State *L)
{
    const char *fromname = luaL_checkstring(L, 1);
    const char *toname   = luaL_checkstring(L, 2);
    return luaL_fileresult(L, lmt_valid_target(L, security_writeable, toname, security_rename_file) ? aux_utf8_rename(fromname, toname) == 0 : 0, NULL);
}

# ifdef _WIN32

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
        char *val = NULL;
        if (key) {
            size_t wlen = 0;
            LPWSTR wkey = aux_utf8_to_wide(key);
            _wgetenv_s(&wlen, NULL, 0, wkey);
            if (wlen) {
                LPWSTR wval = (LPWSTR) lmt_memory_malloc(wlen * sizeof(WCHAR));
                if (! _wgetenv_s(&wlen, wval, wlen, wkey)) {
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
            const char *val = luaL_optstring(L, 2, NULL);
            LPWSTR wkey = aux_utf8_to_wide(key);
            LPWSTR wval = aux_utf8_to_wide(val ? val : "");
            int bad = _wputenv_s(wkey, wval); 
            lmt_memory_free(wval);
            lmt_memory_free(wkey);
            if (bad) {
                return luaL_error(L, "unable to change environment");
            }
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

/*tex

    This makes no sense in the perspective of \LUAMETATEX\ where it can interfere with
    multi-lingual rendering. We mostly communicate in English anyway. Elsewhere we force
    the C locale.

*/

static int oslib_setlocale(lua_State *L)
{
    (void) L;
    return 0;
}

/*tex

    This one is not that important but cheap to implement, we assume some sanity check
    at the \LUA\ end. For instance, we can go to a website or url.

*/

# if defined(_WIN32) || defined(_WIN64)
    # include <shellapi.h>
# else
    # include <spawn.h>
    # include <sys/wait.h>
# endif

# define max_command_length 2048

typedef enum {
    launcher_state_success,
    launcher_state_blocked,
    launcher_state_no_command,
    launcher_state_bad_command,
    launcher_state_long_command,
    launcher_state_not_found,
    launcher_state_failure,
    launcher_state_unsupported
} launcher_states;

static int oslib_aux_valid_launch(const char *cmd, size_t len)
{
    if (! cmd || len == 0) {
        return launcher_state_no_command;
    } else if (len >= max_command_length) {
        return launcher_state_long_command;
    } else {
        for (size_t i = 0; i < len; i++) {
            unsigned char c = (unsigned char) cmd[i];
            if (c <= 32 || c >= 127) {
                return launcher_state_bad_command;
            }
        }
        return launcher_state_success;
    }
}

# if defined(_WIN32) || defined(_WIN64)

    /*tex Not really spawn but kind of. */

    static int oslib_aux_spawn_process(const char *executable, const char * cmd)
    {
        INT_PTR result = (INT_PTR) ShellExecuteA(NULL, executable, cmd, NULL, NULL, SW_SHOWNORMAL);
        if (result > 32) {
            return launcher_state_success;
        } else {
            return (result == SE_ERR_FNF || result == SE_ERR_PNF)
               ? launcher_state_not_found : launcher_state_failure;
        }
    }

# else

    /*tex

        This variant intercepts errors in case of an indirect. As I tested the posix variant
        in WSL, after consulting Gemini instead of a redirect to wslview after a failure some
        magic commands (installation) did that automatically so we keep things simple and don't
        rely on a shell.

    */ /*

    static int oslib_aux_spawn_process(const char *executable, const char * cmd)
    {
        char buffer[max_command_length * 2];
        snprintf(buffer, sizeof(buffer), "%s \"%s\" > /dev/null 2>&1 &", executable, cmd);
        char *const argv[] = {
            (char *) "/bin/sh",
            (char *) "-c",
            buffer,
            NULL
        };
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        pid_t pid;
        int status = posix_spawnp(&pid, "/bin/sh", &actions, NULL, argv, environ);
        posix_spawn_file_actions_destroy(&actions);
        if (status != 0) {
            return (status == ENOENT) ? launcher_state_not_found : launcher_state_failure;
        }
        int exit_code;
        waitpid(pid, &exit_code, 0);
        return (WIFEXITED(exit_code) && WEXITSTATUS(exit_code) == 0)
            ? launcher_state_success
            : launcher_state_failure;
    }

    */

    static int oslib_aux_spawn_process(const char *executable, const char * cmd)
    {
        char *const argv[] = {
            (char *) (uintptr_t) executable,
            (char *) (uintptr_t) cmd,
            NULL
        };
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        int dev_null = open("/dev/null", O_WRONLY);
        if (dev_null >= 0) {
            posix_spawn_file_actions_adddup2(&actions, dev_null, STDOUT_FILENO);
            posix_spawn_file_actions_adddup2(&actions, dev_null, STDERR_FILENO);
            posix_spawn_file_actions_addclose(&actions, dev_null);
        }
        pid_t pid;
        int status = posix_spawnp(&pid, executable, &actions, NULL, argv, environ);
        posix_spawn_file_actions_destroy(&actions);
        if (dev_null >= 0) {
            close(dev_null);
        }
        if (status != 0) {
            return (status == ENOENT) ? launcher_state_not_found : launcher_state_failure;
        }
        return launcher_state_success;
    }

# endif

static int oslib_launch(lua_State *L)
{
    size_t      len    = 0;
    const char *cmd    = luaL_checklstring(L, 1, &len);
    int         status = oslib_aux_valid_launch(cmd, len);

    if (status == launcher_state_success && ! lmt_valid_target(L, security_launchable, cmd, security_launch_command)) {
        status = launcher_state_blocked;
    }
    if (status == launcher_state_success) {
        # if defined(_WIN32) || defined(_WIN64)
            status = oslib_aux_spawn_process("open", cmd);
        # elif defined(__APPLE__)
            status = oslib_aux_spawn_process("open", cmd);
        # elif defined(__unix__) || defined(__linux__)
            status = oslib_aux_spawn_process("xdg-open", cmd);
         // /* WSL Fallback 1: wslview */
         // if (status != launcher_state_success) {
         //     status = oslib_aux_spawn_process("wslview", cmd);
         // }
         // /* WSL Fallback 2: Direct Windows command interop */
         // if (status != launcher_state_success) {
         //     status = oslib_aux_spawn_process("cmd.exe /c start", cmd);
         // }
        # else
            status = launcher_state_unsupported;
        # endif
    }
    lua_pushinteger(L, status);
    return 1;
}

static const luaL_Reg oslib_function_list[] = {
    { "sleep",          oslib_sleep          },
    { "uname",          oslib_uname          },
    { "gettimeofday",   oslib_gettimeofday   },
    { "setenv",         oslib_setenv         }, /* security : todo */
    { "execute",        oslib_execute        }, /* security : todo */
    { "launch",         oslib_launch         }, /* security : todo */
    { "rename",         oslib_rename         }, /* security : writeable */
    { "remove",         oslib_remove         }, /* security : writeable */
    { "setlocale",      oslib_setlocale      },
# ifdef _WIN32
    { "getenv",         oslib_getenv         },
# endif
    { "enableansi",     oslib_enableansi     },
    { "getcodepage",    oslib_getcodepage    },
    { "getnamevalues",  oslib_getnamevalues  },
    { "gettypevalues",  oslib_gettypevalues  },
    { "getunamefields", oslib_getunamefields },
    /* */
    { NULL,             NULL                 },
};

/*tex
    The |environ| variable is deprecated on windows so it made sense to just drop this old \LUATEX\
    feature.
*/

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
