/*

    See license.txt in the root of this project.

    In \LUATEX\ we use the lfs library from the kepler project and we started from that one. In
    the meantime all the code has been replaced, we added some more and made sure it works well
    on msvs, posix and cross compilation. The original library offers the following functions
    and we try to remain compatible with these as users might expect them.

        lfs.attributes(filepath [, attributename | attributetable])
        lfs.chdir(path)
        lfs.currentdir()
        lfs.dir(path)
        lfs.link(old, new[, symlink])
        lfs.mkdir(path)
        lfs.rmdir(path)
        lfs.symlinkattributes(filepath [, attributename])
        lfs.touch(filepath [, atime [, mtime]])

    Because \TEX| is multi-platform we try to provide a consistent interface. So, for instance
    block size and inode number are not relevant for us, nor are user and group ids. The lock
    functions have been removed as they serve no purpose in a \TEX\ system and devices make no
    sense either. The iterator could be improved. I also fixed some abnormalities. Permissions
    are not useful either. As this is a bit hairy we occasionally come back to it, and in 2026
    did some checking with codex (luna max) and gemini flash and as a result updated some calls
    to libraries as we can assume to run on modern versions of the operating systems as well as
    use recent iterations of C. Double (tripple) checking this definitely made sense.

    We might move some more file(system) related code here.

    % sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
    % RAMMap.exe -Es   (EmptyStandbyList)
    % RAMMap.exe -Et   (EmptySystemWorkingSet)

*/

# include "luametatex.h"

/* Standard access mode constants */

# ifndef R_OK

    enum {
        F_OK = 0,
        W_OK = 2,
        R_OK = 4
    };

# endif

# ifndef _WIN32
    # ifndef _FILE_OFFSET_BITS
        # define _FILE_OFFSET_BITS 64
    # endif
# endif

# ifdef _WIN32
    # ifndef WINVER
        # define WINVER       0x0601
        # undef  _WIN32_WINNT
        # define _WIN32_WINNT 0x0601
    # endif
# endif

# define _LARGEFILE64_SOURCE 1

# include <errno.h>
# include <stdio.h>
# include <string.h>
# include <stdlib.h>
# include <time.h>
# include <sys/stat.h>

/*tex 
    See |lmtinterface.h| for |DIR_HANDLE_INSTANCE|. here it's not really needed to have a high 
    performance lookup but we are consistent so let's have it. We seldom have more than a few 
    tens of thousands iterations. 
*/

# ifdef _WIN32

    # include <direct.h>
    # include <windows.h>
    # include <io.h>
    # include <fileapi.h>
    # include <sys/locking.h>
    # include <sys/utime.h>
    # include <fcntl.h>

# else

    # include <unistd.h>
    # include <dirent.h>
    # include <fcntl.h>
    # include <sys/types.h>
    # include <utime.h>
    # include <sys/param.h>

# endif

/*tex
    After the included these can be known:
*/

# if defined(PATH_MAX)
    # define MY_MAXPATHLEN PATH_MAX
# elif defined(MAXPATHLEN)
    # define MY_MAXPATHLEN MAXPATHLEN
# else
    # define MY_MAXPATHLEN 255
# endif

# ifdef _WIN32

    # ifndef FIND_FIRST_EX_LARGE_FETCH
        # define FIND_FIRST_EX_LARGE_FETCH 0x02
    # endif

    # ifndef mode_t
        typedef unsigned short mode_t;
    # endif

    static inline int win_S_ISDIR(mode_t mode) { return (mode & _S_IFDIR) != 0; }
    static inline int win_S_ISREG(mode_t mode) { return (mode & _S_IFREG) != 0; }
    static inline int win_S_ISLNK(mode_t mode) { (void) mode; return 0; }

    # ifndef S_ISDIR
        # define S_ISDIR(mode) win_S_ISDIR(mode)
    # endif

    # ifndef S_ISREG
        # define S_ISREG(mode) win_S_ISREG(mode)
    # endif

    # ifndef S_ISLNK
        # define S_ISLNK(mode) win_S_ISLNK(mode)
    # endif

    typedef struct _stati64    info_struct;
    typedef struct __utimbuf64 utime_struct;

    static const int exec_mode_flag = _S_IEXEC;

    static inline int get_stat(const char *s, info_struct *i)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wstati64(w, i);
        lmt_memory_free(w);
        return r == 0;
    }

    static inline int mk_dir(const char *s)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wmkdir(w);
        lmt_memory_free(w);
        return r == 0;
    }

    static inline int ch_dir(const char *s)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wchdir(w);
        lmt_memory_free(w);
        return r == 0;
    }

    static inline int rm_dir(const char *s)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wrmdir(w);
        lmt_memory_free(w);
        return r == 0;
    }

    /* POSIX symlink(target, linkpath) -> Symbolic Link */

    static inline int mk_symlink(const char *t, const char *f)
    {
        LPWSTR wt = aux_utf8_to_wide(t);
        LPWSTR wf = aux_utf8_to_wide(f);
        int r = 0;
        if (wt && wf) {
            DWORD flags = 0x2; /* SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE */
            DWORD attr  = GetFileAttributesW(wt);
            if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY)) {
                flags |= 0x1;  /* SYMBOLIC_LINK_FLAG_DIRECTORY */
            }
            /* Win32 takes (NewLink, ExistingTarget, Flags) */
            r = CreateSymbolicLinkW(wf, wt, flags) != 0;
            if (! r && GetLastError() == ERROR_INVALID_PARAMETER && (flags & 0x2)) {
                r = CreateSymbolicLinkW(wf, wt, flags & ~0x2) != 0;
            }
        }
        lmt_memory_free(wt);
        lmt_memory_free(wf);
        return r;
    }
    
    /* POSIX link(target, linkpath) -> Hard Link */

    static inline int mk_link(const char *t, const char *f)
    {
        LPWSTR wt = aux_utf8_to_wide(t);
        LPWSTR wf = aux_utf8_to_wide(f);
        int r = (wt && wf) ? (CreateHardLinkW(wf, wt, NULL) != 0) : 0;
        lmt_memory_free(wt);
        lmt_memory_free(wf);
        return r;
    }

    static inline int ch_to_exec(const char *s, mode_t n)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wchmod(w, n);
        lmt_memory_free(w);
        return r == 0;
    }

    static inline int set_utime(const char *s, utime_struct *b)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wutime64(w, b);
        /* if the file doesn't exist, we create an empty file and retry updating timestamps */
        if (r != 0 && errno == ENOENT) {
            FILE *f = _wfopen(w, L"ab");
            if (f) {
                fclose(f);
                r = _wutime64(w, b);
            }
        }
        lmt_memory_free(w);
        return r == 0;
    }

# else

    /* POSIX */

    typedef struct stat   info_struct;
    typedef struct utimbuf utime_struct;

    static const mode_t exec_mode_flag = (S_IXUSR | S_IXGRP | S_IXOTH);

    static inline int get_stat(const char *s, info_struct *i)
    {
        return stat(s, i) == 0;
    }

    static inline int mk_dir(const char *s)
    {
        return mkdir(s, S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH) == 0;
    }

    static inline int ch_dir(const char *s)
    {
        return chdir(s) == 0;
    }

    static inline int rm_dir(const char *s)
    {
        return rmdir(s) == 0;
    }

    static inline int mk_symlink(const char *target, const char *linkpath)
    {
        return symlink(target, linkpath) == 0;
    }

    static inline int mk_link(const char *target, const char *linkpath)
    {
        return link(target, linkpath) == 0;
    }

    static inline int ch_to_exec(const char *s, mode_t mode)
    {
        return chmod(s, mode) == 0;
    }

 // static inline int set_utime(const char *s, utime_struct *b)
 // {
 //     return utime(s, b) == 0;
 // }

    static inline int set_utime(const char *s, utime_struct *b)
    {
        int r = utime(s, b);
        if (r != 0 && errno == ENOENT) {
            FILE *f = fopen(s, "ab");
            if (f) {
                fclose(f);
                r = utime(s, b);
            }
        }
        return r == 0;
    }

# endif

# include <lua.h>
# include <lauxlib.h>
# include <lualib.h>

/*
    This function changes the current directory.

    success = chdir(name)
*/

static int filelib_chdir(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char * name = lua_tostring(L, 1);
        okay = (name && lmt_valid_target(L, security_readable, name, security_change_directory)) ? ch_dir(name) : 0;
    }
    lua_pushboolean(L, okay);
    return 1;
}

/*
    This function returns the current directory or false.

    name = currentdir()
*/

# ifdef _WIN32

    static int filelib_currentdir(lua_State *L)
    {
        LPWSTR wpath = NULL;
        int size = 256;
        while (1) {
            LPWSTR temp = lmt_memory_realloc(wpath, size * sizeof(WCHAR));
            if (! temp) {
                lmt_memory_free(wpath);
                lua_pushboolean(L, 0);
                return 1;
            }
            wpath = temp;
            if (_wgetcwd(wpath, size)) {
                char *path = aux_utf8_from_wide(wpath);
                lua_pushstring(L, path);
                lmt_memory_free(path);
                break;
            } else if (errno != ERANGE) {
                lua_pushboolean(L, 0);
                break;
            } else {
                size *= 2;
            }
        }
        lmt_memory_free(wpath);
        return 1;
    }

# else

    static int filelib_currentdir(lua_State *L)
    {
        char *path = NULL;
        size_t size = MY_MAXPATHLEN;
        while (1) {
            char *temp = lmt_memory_realloc(path, size);
            if (! temp) {
                if (path) {
                    lmt_memory_free(path); /* Free original buffer if realloc fails */
                }
                lua_pushboolean(L, 0);
                return 1;
            }
            path = temp;
            if (getcwd(path, size)) {
                lua_pushstring(L, path);
                lmt_memory_free(path); /* Clean up allocated buffer before returning */
                return 1;
            }

            if (errno != ERANGE) {
                lmt_memory_free(path);
                lua_pushboolean(L, 0);
                return 1;
            }
            size *= 2;
        }
    }

# endif

/*
    This functions create a link:

    success = link(target,name,[true=symbolic])
    success = symlink(target,name)
*/

static int filelib_link(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING && lua_type(L, 2) == LUA_TSTRING) {
        const char *oldpath = lua_tostring(L, 1);
        const char *newpath = lua_tostring(L, 2);
        if (oldpath && newpath && lmt_valid_target(L, security_writeable, newpath, security_link_object)) {
            okay = lua_toboolean(L, 3) ? mk_symlink(oldpath, newpath) : mk_link(oldpath, newpath);
        }
    }
    lua_pushboolean(L, okay);
    return 1;
}

static int filelib_symlink(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING && lua_type(L, 2) == LUA_TSTRING) {
        const char *oldpath = lua_tostring(L, 1);
        const char *newpath = lua_tostring(L, 2);
        if (oldpath && newpath && lmt_valid_target(L, security_writeable, newpath, security_link_object)) {
            okay = mk_symlink(oldpath, newpath);
        }
    }
    lua_pushboolean(L, okay);
    return 1;
}

/*
    This function creates a directory.

    success = mkdir(name)
*/

static int filelib_mkdir(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char * name = lua_tostring(L, 1);
        okay = (name && lmt_valid_target(L, security_writeable, name, security_create_directory)) ? mk_dir(name) : 0;
    }
    lua_pushboolean(L, okay);
    return 1;
}

/*
    This function removes a directory (non-recursive).

    success = rmdir(name)
*/

static int filelib_rmdir(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char * name = lua_tostring(L, 1);
        okay = (name && lmt_valid_target(L, security_writeable, name, security_remove_directory)) ? rm_dir(name) : 0;
    }
    lua_pushboolean(L, okay);
    return 1;
}

static int filelib_moreweird(lua_State *L)
{
    static const char *weird = "~`!#$%^&*()={}[]:;\"'|<>,?\n\r\t";
    const char *str = lua_tostring(L, 1);
    lua_pushboolean(L, str ? str[0] == '.' || strpbrk(str, weird) != NULL : 1);
    return 1;
}

static int filelib_lessweird(lua_State *L)
{
    static const char *weird = "~`#$%^&*:;\"\'|<>,?\n\r\t";
    const char *str = lua_tostring(L, 1);
    lua_pushboolean(L, str ? str[0] == '.' || strpbrk(str, weird) != NULL : 1);
    return 1;
}

/*tex

    It happens that one can run into complaints about generating the \CONTEXT\ file databases,
    often by non \CONTEXT\ users. The arguments are kind of weird and make little sense when
    you consider what goes on. Also, it doesn't concern the normal distibution but a large
    setup like texlive. Here is a break down. The numbers are on a wsl subsystem so on a bare
    metal setup we have even less of an issue. In the \CONTEXT\ distribution we're talking about
    neglectable times, when disk I/O is cached, second digits after the comma.

    A 2026 tl setup has 241.000 files on about 17,600 directories and an |mtxrun --generate|
    takes 2.75 seconds (cached I/O on WSL) or 7.36 seconds (uncached disk I/O) and according
    to Gemini that is \quotation {an exceptionally strong result}.

    When we run |mktexlsr| after that, it needs 0.700 seconds to complete the job. It just
    lists the files and directories and where |mtxrun| prepares the dabase for lookups, that
    is delegated to kpse when \CONTEXT\ is not used. Also, serializing and compiling to
    bytecode add overhead. Actually, the 2 more seconds are used for that. We're using a 2018
    laptop (windows 11 with wsl) when testing this. Both the \LUA\ and plain text files that
    contain the information are quite large.

    When we do a cold run, that is: uncached disk I/O, a |mktexlsr| needs over 5 seconds which
    isn't nothing either. Now here is the thing. Say that we update texlive. If after an update
    we first run |mtxrun| than that one will will populate the cache, in our case we talk of
    directories and attributes. A later |mktexlsr| will benefit from that! If we first run
    |mktexlsr| that one does the heavy lifting and |mtxrun| might benefit. Order matters here
    and that is never taken into account when I read complaints. In fact, not running
    |mtxrun --generate| and delaying that actually makes it worse. If \CONTEXT, because it
    comes early in the alphabet is done first it is always the loser!

    A similar argument can be held for making formats. This also involves lookups and files
    and again caching plays a role here. Seeing what format generation does (logging) can give
    the impression of it being slow, and the few seconds needed then gain attention, while a
    hidden generation of other formats taking minutes seems to give the impression of speed.

    In the end, and this is the bottom line here, it all depends on order and caching, and the
    code involved in the scanning is not really the problem: it's efficient and fast. Messing
    with it, assuming an improvement, is asking for problems and obsuring the facts. It also
    sort of demonstrates ignorance. But then, reading about performance issues in \TEX\ and
    its ecosystem are often kind of weird (and off).

    As a side note: there are reasons why, right from the start of \LUATEX, and even in the
    former \PDFTEX\ times, in the \CONTEXT\ runners we found ways to optimize file lookups:
    there was time that pre-ssd disk access really forced us to get around the multi-second
    engine file lookups on large distributions. It actually is why we started with the
    minimal ones.

    The iterator provides the name, status and optionally (when we want detail) attributes.

*/

# ifdef _WIN32

    # include <windows.h>
    # include <fileapi.h>

    typedef struct dir_data {
        HANDLE           handle;
        int              closed;
        int              details;
        WIN32_FIND_DATAW fd;
        wchar_t          pattern[MY_MAXPATHLEN + 5];
    } dir_data;

    static inline void push_utf8_filename(lua_State *L, const wchar_t *wstr)
    {
        char utf8buf[MY_MAXPATHLEN * 4];
        /* WideCharToMultiByte returns 0 on failure (e.g. buffer overflow or bad UTF-16) */
        int len = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, utf8buf, sizeof(utf8buf), NULL, NULL);
        if (len > 1) {
            lua_pushlstring(L, utf8buf, (size_t) (len - 1));
        } else {
            lua_pushliteral(L, "");
        }
    }

    static inline int push_entry(lua_State *L, const WIN32_FIND_DATAW *fd, int details)
    {
        push_utf8_filename(L, fd->cFileName);
        if (fd->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            lua_push_key(directory);
        } else {
            lua_push_key(file);
        }
        if (details) {
            /* convert FILETIME to 64-bit Unix epoch time */
            ULARGE_INTEGER ull;
            ull.LowPart  = fd->ftLastWriteTime.dwLowDateTime;
            ull.HighPart = fd->ftLastWriteTime.dwHighDateTime;
            /* the magic number is 100 nanoseconds between 1601 and 1970 */
            lua_Integer mtime = ull.QuadPart >= 116444736000000000ULL
                ? (lua_Integer) ((ull.QuadPart - 116444736000000000ULL) / 10000000ULL)
                : 0;
            lua_Integer size = ((lua_Integer)fd->nFileSizeHigh << 32) | fd->nFileSizeLow;
            lua_pushinteger(L, size);
            lua_pushinteger(L, mtime);
            return 4;
        } else {
            return 2;
        }
    }

    static int filelib_aux_dir_next(lua_State *L, dir_data *d)
    {
        if (! d || d->closed) {
            return 0;
        }
        if (d->handle == INVALID_HANDLE_VALUE) {
            /* first entry */
            d->handle = FindFirstFileExW(
                d->pattern,
                FindExInfoBasic, /* skips short 8.3 filename retrieval */
                &d->fd,
                FindExSearchNameMatch,
                NULL,
                FIND_FIRST_EX_LARGE_FETCH /* instead of 0, is faster in a network or usb */
            );
            if (d->handle == INVALID_HANDLE_VALUE) {
                d->closed = 1;
                return 0;
            }
        } else {
            if (! FindNextFileW(d->handle, &d->fd)) {
                FindClose(d->handle);
                d->handle = INVALID_HANDLE_VALUE;
                d->closed = 1;
                return 0;
            }
        }
        while (d->fd.cFileName[0] == L'.' &&
              (d->fd.cFileName[1] == L'\0' || (d->fd.cFileName[1] == L'.' && d->fd.cFileName[2] == L'\0')))
        {
            if (! FindNextFileW(d->handle, &d->fd)) {
                FindClose(d->handle);
                d->handle = INVALID_HANDLE_VALUE;
                d->closed = 1;
                return 0;
            }
        }
        return push_entry(L, &d->fd, d->details);
    }

    static inline dir_data *filelib_aux_valid_dir(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, 1);
        if (d) {
            if (lua_getmetatable(L, 1))    {
                lua_get_metatablelua(dir_handle_instance);
                if (! lua_rawequal(L, -1, -2)) {
                   d = NULL;
                }
                lua_pop(L, 2);
            } else {
               d = NULL;
            }
        }
        return d;
    }

    static int filelib_aux_dir_iterator(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, lua_upvalueindex(1));
        return filelib_aux_dir_next(L, d);
    }

    static int filelib_aux_dir_method(lua_State *L)
    {
        dir_data *d = (dir_data *) luaL_checkudata(L, 1, DIR_HANDLE_INSTANCE);
     /* dir_data *d = filelib_aux_valid_dir(L); */ /* faster */
        return d ? filelib_aux_dir_next(L, d) : 0;
    }

    static int filelib_aux_dir_close(lua_State *L)
    {
        dir_data *d = (dir_data *) luaL_checkudata(L, 1, DIR_HANDLE_INSTANCE);
     /* dir_data *d = filelib_aux_valid_dir(L); */ /* faster */
        if (d && ! d->closed && d->handle != INVALID_HANDLE_VALUE) {
            FindClose(d->handle);
            d->handle = INVALID_HANDLE_VALUE;
        }
        if (d) {
            d->closed = 1;
        }
        return 0;
    }

    static int filelib_dir(lua_State *L)
    {
        const char *path = luaL_checkstring(L, 1);
        int details = (lua_type(L, 2) == LUA_TBOOLEAN) ? lua_toboolean(L, 2) : 1;
        if (! path || path[0] == '\0') {
            path = ".";
        }
        dir_data *d = (dir_data *) lua_newuserdatauv(L, sizeof(dir_data), 0);
        lua_get_metatablelua(dir_handle_instance);
        lua_setmetatable(L, -2);
        d->closed  = 0;
        d->details = details;
        d->handle  = INVALID_HANDLE_VALUE;
        /* Convert path to wide string */
        int len = MultiByteToWideChar(CP_UTF8, 0, path, -1, d->pattern, MY_MAXPATHLEN);
        if (len <= 0) {
            luaL_error(L, "path conversion failed or too long: %s", path);
            return 0;
        }
        /* Trim trailing slashes (except for root like "C:\" or "\") */
        while (len > 2 && (d->pattern[len - 2] == L'/' || d->pattern[len - 2] == L'\\') && d->pattern[len - 3] != L':') {
            len--;
        }
        d->pattern[len - 1] = L'\0';
        /* Validate directory existence and type (matches POSIX opendir check) */
        DWORD attr = GetFileAttributesW(d->pattern);
        if (attr == INVALID_FILE_ATTRIBUTES || ! (attr & FILE_ATTRIBUTE_DIRECTORY)) {
            luaL_error(L, "cannot open %s: %s", path, (attr == INVALID_FILE_ATTRIBUTES) ? "no such directory" : "not a directory");
            return 0;
        }
        /* Append "\*" for FindFirstFileExW */
        d->pattern[len - 1] = L'\\';
        d->pattern[len]     = L'*';
        d->pattern[len + 1] = L'\0';
        lua_pushvalue(L, -1);
        lua_pushcclosure(L, filelib_aux_dir_iterator, 1);
        lua_insert(L, -2);
        return 2;
    }

# else

    /* POSIX & Linux */
    # include <unistd.h>
    # include <dirent.h>
    # include <fcntl.h>
    # include <sys/types.h>

    /* for apple: : at some point we will drop it */
    # if defined(AT_FDCWD) && defined(AT_SYMLINK_NOFOLLOW)
        # define HAVE_FSTATAT 1
    # else
        # define HAVE_FSTATAT 0
    # endif

    /* for solaris: at some point we will drop it */
    # ifndef _XOPEN_SOURCE
        # define _XOPEN_SOURCE 700
    # endif
    # if ! defined(dirfd) && defined(__sun)
        # define dirfd(dirp) ((dirp)->dd_fd)
    # endif

    typedef struct dir_data {
        DIR *handle;
        int  closed;
        int  details;
    # if HAVE_FSTATAT
        int  dfd;
    # else
        char path[MY_MAXPATHLEN]; /* Only allocated on older OS/SDK targets */
    # endif
    } dir_data;

    static int filelib_aux_dir_next(lua_State *L, dir_data *d)
    {
        struct dirent *entry;
        if (! d || d->closed) {
            return 0;
        }
        while ((entry = readdir(d->handle)) != NULL) {
            if (entry->d_name[0] == '.' &&
               (entry->d_name[1] == '\0' || (entry->d_name[1] == '.' && entry->d_name[2] == '\0'))) {
                continue;
            }
            break;
        }
        if (! entry) {
            closedir(d->handle);
            d->closed = 1;
            d->handle = NULL;
        # if HAVE_FSTATAT
            d->dfd    = -1;
        # endif
            return 0;
        }
        lua_pushstring(L, entry->d_name);
        # ifdef _DIRENT_HAVE_D_TYPE
            if (! d->details) {
                if (entry->d_type == DT_DIR) {
                    lua_push_key(directory);
                    return 2;
                } else if (entry->d_type == DT_REG) {
                    lua_push_key(file);
                    return 2;
                }
            }
        # endif
        info_struct info;
        int stat_res;
    # if HAVE_FSTATAT
        stat_res = fstatat(d->dfd, entry->d_name, &info, 0);
        if (stat_res != 0) {
            /* target fails (e.g. broken link), inspect link itself */
            stat_res = fstatat(d->dfd, entry->d_name, &info, AT_SYMLINK_NOFOLLOW);
        }
    # else
        char pathbuf[MY_MAXPATHLEN];
        snprintf(pathbuf, sizeof(pathbuf), "%s/%s", d->path, entry->d_name);
        stat_res = stat(pathbuf, &info);
        if (stat_res != 0) {
            stat_res = lstat(pathbuf, &info);
        }
    # endif
        if (stat_res == 0) {
            if (S_ISDIR(info.st_mode)) {
                lua_push_key(directory);
            } else {
                lua_push_key(file);
            }
            if (d->details) {
                lua_pushinteger(L, (lua_Integer) info.st_size);
                lua_pushinteger(L, (lua_Integer) info.st_mtime);
                return 4;
            }
        } else {
            lua_pushnil(L);
        }
        return 2;
    }

    static inline dir_data *filelib_aux_valid_dir(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, 1);
        if (d) { 
            if (lua_getmetatable(L, 1)) {
                lua_get_metatablelua(dir_handle_instance);
                if (! lua_rawequal(L, -1, -2)) {
                   d = NULL;
                }
                lua_pop(L, 2);
            } else {
               d = NULL;
            }
        }
        return d;
    }

    static int filelib_aux_dir_iterator(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, lua_upvalueindex(1));
        return filelib_aux_dir_next(L, d);
    }

    static int filelib_aux_dir_method(lua_State *L)
    {
        dir_data *d = (dir_data *) luaL_checkudata(L, 1, DIR_HANDLE_INSTANCE);
     /* dir_data *d = filelib_aux_valid_dir(L); */ /* faster */
        return d ? filelib_aux_dir_next(L, d) : 0;
    }

    static int filelib_aux_dir_close(lua_State *L)
    {
        dir_data *d = (dir_data *) luaL_checkudata(L, 1, DIR_HANDLE_INSTANCE);
     /* dir_data *d = filelib_aux_valid_dir(L); */ /* faster */
        if (d && ! d->closed && d->handle) {
            closedir(d->handle);
        }
        if (d) {
            d->closed = 1;
            d->handle = NULL;
    # if HAVE_FSTATAT
            d->dfd    = -1;
    # endif
        }
        return 0;
    }

    static int filelib_dir(lua_State *L)
    {
        const char *path = luaL_checkstring(L, 1);
        int details = (lua_type(L, 2) == LUA_TBOOLEAN) ? lua_toboolean(L, 2) : 1;
        dir_data *d = (dir_data *) lua_newuserdatauv(L, sizeof(dir_data), 0);
        lua_get_metatablelua(dir_handle_instance);
        lua_setmetatable(L, -2);
        d->closed  = 0;
        d->details = details;
        const char *target_path = path ? path : ".";
    # if ! HAVE_FSTATAT
        strncpy(d->path, target_path, MY_MAXPATHLEN - 1);
        d->path[MY_MAXPATHLEN - 1] = '\0';
    # endif
        d->handle = opendir(target_path);
        if (! d->handle) {
            luaL_error(L, "cannot open %s: %s", path, strerror(errno));
        }
    # if HAVE_FSTATAT
        d->dfd = dirfd(d->handle);
    # endif
        lua_pushvalue(L, -1);
        lua_pushcclosure(L, filelib_aux_dir_iterator, 1);
        lua_insert(L, -2);
        return 2;
    }

# endif

static int dir_create_metatable(lua_State *L)
{
    luaL_newmetatable(L, DIR_HANDLE_INSTANCE);
    lua_newtable(L);
    lua_pushcfunction(L, filelib_aux_dir_method);
    lua_setfield(L, -2, "next");
    lua_pushcfunction(L, filelib_aux_dir_close);
    lua_setfield(L, -2, "close");
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, filelib_aux_dir_close);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    return 1;
}

static inline const char *mode2string(mode_t mode)
{
    if (S_ISREG(mode)) {
        return "file";
    } else if (S_ISDIR(mode)) {
        return "directory";
    } else if (S_ISLNK(mode)) {
        return "link";
    } else {
        return "other";
    }
}

# ifdef _WIN32

    static const char *perm2string(unsigned short mode)
    {
        static char perms[10] = "---------";
        for (int i = 0; i < 9; i++) {
            perms[i] = '-';
        }
        if (mode & _S_IREAD)  { perms[0] = 'r'; perms[3] = 'r'; perms[6] = 'r'; }
        if (mode & _S_IWRITE) { perms[1] = 'w'; perms[4] = 'w'; perms[7] = 'w'; }
        if (mode & _S_IEXEC)  { perms[2] = 'x'; perms[5] = 'x'; perms[8] = 'x'; }
        return perms;
    }

# else

    static const char *perm2string(mode_t mode)
    {
        static char perms[10] = "---------";
        for (int i = 0; i < 9; i++) {
            perms[i] = '-';
        }
        if (mode & S_IRUSR) perms[0] = 'r';
        if (mode & S_IWUSR) perms[1] = 'w';
        if (mode & S_IXUSR) perms[2] = 'x';
        if (mode & S_IRGRP) perms[3] = 'r';
        if (mode & S_IWGRP) perms[4] = 'w';
        if (mode & S_IXGRP) perms[5] = 'x';
        if (mode & S_IROTH) perms[6] = 'r';
        if (mode & S_IWOTH) perms[7] = 'w';
        if (mode & S_IXOTH) perms[8] = 'x';
        return perms;
    }

# endif

/*
    The next one sets access time and modification values for a file:

    utime(filename)                    : current, current
    utime(filename,acess)              : access, access
    utime(filename,acess,modification) : access, modification
*/

static int filelib_touch(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char *name = luaL_checkstring(L, 1);
        utime_struct utb, *buf;
        if (lua_gettop(L) == 1) {
            buf = NULL;
        } else {
            utb.actime  = (time_t) luaL_optinteger(L, 2, 0);
            utb.modtime = (time_t) luaL_optinteger(L, 3, utb.actime);
            buf = &utb;
        }
        okay = (name && lmt_valid_target(L, security_writeable, name, security_touch_object)) ? set_utime(name, buf) : 0;
    }
    lua_pushboolean(L, okay);
    return 1;
}

static void push_st_mode (lua_State *L, info_struct *info) { lua_pushstring (L,  mode2string (info->st_mode)); }
static void push_st_size (lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_size);  }
static void push_st_mtime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_mtime); }
static void push_st_atime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_atime); }
static void push_st_ctime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_ctime); }
static void push_st_perm (lua_State *L, info_struct *info) { lua_pushstring (L,  perm2string (info->st_mode)); }
static void push_st_nlink(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_nlink); }

typedef void (*push_info_struct_function) (lua_State *L, info_struct *info);

struct file_stat_members {
    const char                *name;
    push_info_struct_function  push;
};

static struct file_stat_members members[] = {
    { "mode",         push_st_mode  },
    { "size",         push_st_size  },
    { "modification", push_st_mtime },
    { "access",       push_st_atime },
    { "change",       push_st_ctime },
    { "permissions",  push_st_perm  },
    { "nlink",        push_st_nlink },
    { NULL,           NULL          },
};

/*
    Get file or symbolic link information. Returns a table or nil.
*/

static int filelib_attributes(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        info_struct info;
        const char *file = luaL_checkstring(L, 1);
        if (! get_stat(file, &info)) {
            /* bad news */
        } else if (lua_isstring(L, 2)) {
            const char *member = lua_tostring(L, 2);
            for (int i = 0; members[i].name; i++) {
                if (strcmp(members[i].name, member) == 0) {
                    members[i].push(L, &info);
                    return 1;
                }
            }
        } else {
            lua_settop(L, 2);
            if (! lua_istable(L, 2)) {
                lua_createtable(L, 0, 6);
            }
            for (int i = 0; members[i].name; i++) {
                lua_pushstring(L, members[i].name);
                members[i].push(L, &info);
                lua_rawset(L, -3);
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

# ifdef _WIN32

    static inline int filelib_check_path_type(lua_State *L, int access_mode, int check_dir)
    {
        int okay = 0;
        if (lua_type(L, 1) == LUA_TSTRING) {
            const char *name = lua_tostring(L, 1);
            LPWSTR w = aux_utf8_to_wide(name);
            if (w) {
                info_struct info;
                /* perform a single stat call on the wide path */
                if (_wstati64(w, &info) == 0) {
                    int match = check_dir ? win_S_ISDIR(info.st_mode) : (win_S_ISREG(info.st_mode) || win_S_ISLNK(info.st_mode));
                    if (match) {
                        /* derive permission checks directly from st_mode or run _waccess on the existing wide string */
                        if (access_mode == F_OK) {
                            okay = 1;
                        } else if (access_mode == R_OK) {
                            okay = (info.st_mode & _S_IREAD) != 0;
                        } else if (access_mode == W_OK) {
                            okay = (info.st_mode & _S_IWRITE) != 0;
                        }
                    }
                }
                lmt_memory_free(w);
            }
        }
        lua_pushboolean(L, okay);
        return 1;
    }

# else

    static inline int filelib_check_path_type(lua_State *L, int access_mode, int check_dir)
    {
        int okay = 0;
        if (lua_type(L, 1) == LUA_TSTRING) {
            info_struct info;
            const char *name = lua_tostring(L, 1);
            if (get_stat(name, &info)) {
                int match = check_dir ? S_ISDIR(info.st_mode) : (S_ISREG(info.st_mode) || S_ISLNK(info.st_mode));
                okay = match && (access(name, access_mode) == 0);
            }
        }
        lua_pushboolean(L, okay);
        return 1;
    }

# endif

static int filelib_isdir          (lua_State *L) { return filelib_check_path_type(L, F_OK, 1); }
static int filelib_isreadabledir  (lua_State *L) { return filelib_check_path_type(L, R_OK, 1); }
static int filelib_iswriteabledir (lua_State *L) { return filelib_check_path_type(L, W_OK, 1); }

static int filelib_isfile         (lua_State *L) { return filelib_check_path_type(L, F_OK, 0); }
static int filelib_isreadablefile (lua_State *L) { return filelib_check_path_type(L, R_OK, 0); }
static int filelib_iswriteablefile(lua_State *L) { return filelib_check_path_type(L, W_OK, 0); }

static int filelib_setexecutable(lua_State *L)
{
    int okay = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char *name = lua_tostring(L, 1);
        if (name && lmt_valid_target(L, security_writeable, name, security_set_executable)) {
            info_struct info;
            if (get_stat(name, &info) && S_ISREG(info.st_mode)) {
                okay = ch_to_exec(name, info.st_mode | exec_mode_flag);
            }
        }
    }
    lua_pushboolean(L, okay);
    return 1;
}

static int filelib_symlinktarget(lua_State *L)
{
    char *file = aux_utf8_readlink(luaL_checkstring(L, 1));
    if (file) {
        lua_pushstring(L, file);
        lmt_memory_free(file);
    } else { 
        lua_pushnil(L);
    }
    return 1;
}

static int filelib_expandpath(lua_State *L)
{
    char *file = aux_utf8_expandpath(luaL_checkstring(L, 1));
    if (file) {
        lua_pushstring(L, file);
        lmt_memory_free(file);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int filelib_canonicalize(lua_State *L)
{
    char *file = aux_utf8_canonicalize(luaL_checkstring(L, 1));
    if (file) {
        lua_pushstring(L, file);
        lmt_memory_free(file);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex

    We also need to overload |loadfile| and |dofile|. We could do this only for windows but we
    might add something here so let's just always do it. We also need to handle the package
    loader. So, here are variants on the \LUA\ functions.

    We can actually decide to plug in our own error message handler. Of course we use the helpers
    we already made before (proven wide name handling in windows). We have to deal with the bom
    (okay) as well as the shebang line (unix specific so we might drop that). Contrary to Lua
    here we do that in the buffer. Because not all helpers in the original are public the error
    handling is inline.

    We deliberately don't implement stdin support but we need to handle the shebang line even if
    it makes makes little sense because otherwise some tikz files can't be loaded. The reason why
    we offer the option to block it (|--blockshebang| and/or a setter) us that it permits us to
    identify these issues.

*/

int filelib_loadfilex(
    lua_State  *L,
    const char *filename,
    const char *mode
)
{
    FILE *f = NULL;
    if (filename == NULL) {
        lua_pushliteral(L, "invalid filename (null)");
        return LUA_ERRFILE;
    }
    if (! lmt_valid_target(L, security_loadable, filename, security_load_script_file)) {
        lua_pushfstring(L, "file '%s' is not accessible", filename);
        return LUA_ERRFILE;
    }
# if defined (_WIN32)
    wchar_t *wfilename = aux_utf8_to_wide(filename);
    if (wfilename) {
        f = _wfopen(wfilename, L"rb");
        lmt_memory_free(wfilename);
    }
# else
    f = fopen(filename, "rb");
# endif
    if (f == NULL) {
        lua_pushfstring(L, "file '%s' is not found or unreadable", filename);
        return LUA_ERRFILE;
    }
    char *buffer = NULL;
    size_t bytes = 0;
    /* we need to get the size */
    long size = 0;
    if (fseek(f, 0, SEEK_END) == 0) {
        size = ftell(f);
        fseek(f, 0, SEEK_SET);
    }
    if (size < 0) {
        fclose(f);
        lua_pushfstring(L, "file '%s' can't be accessed (seek)", filename);
        return LUA_ERRFILE;
    }
    buffer = lmt_memory_malloc(size > 0 ? size : 1);
    if (! buffer) {
        fclose(f);
        lua_pushfstring(L, "there is not enough memory to load file '%s'", filename);
        return LUA_ERRMEM;
    }
    if (size > 0) {
        bytes = fread(buffer, 1, size, f);
    }
    fclose(f);
    char *chunkname = NULL;
    if (filename[0] == '=' || filename[0] == '@') {
        chunkname = lmt_memory_strdup(filename);
    } else {
        chunkname = lmt_memory_malloc(strlen(filename) + 2);
        sprintf(chunkname, "@%s", filename);
    }
    /* deal with the BOM and shebang as in skipcomment in lauxlib.c */
    const char *data = buffer;
    /* kind of skipBOM lauxlib.c, here in the buffer */
    if (bytes >= 3 && (unsigned char) data[0] == 0xEF && (unsigned char) data[1] == 0xBB && (unsigned char) data[2] == 0xBF) {
        data += 3;
        bytes -= 3;
    }
    /* kind of skipcomment in lauxlib.c, here in the buffer */
    int status = LUA_ERRFILE;
    if (bytes > 0 && data[0] == '#') {
        if (lmt_engine_state.permit_shebang == load_shebang_enabled) {
            /* we need to retain the '\n' for proper line numbering */
            while (bytes > 0 && data[0] != '\n') {
                data++;
                bytes--;
            }
        } else {
            lua_pushfstring(L, "unexpected shebang line found in file '%s'", filename);
            goto DONE;
        }
    }
    /* */
    status = luaL_loadbufferx(L, data, bytes, chunkname, mode);
  DONE:
    lmt_memory_free(buffer);
    lmt_memory_free(chunkname);
    return status;
}

static int filelib_setloadshebang(lua_State *L)
{
    if (lmt_engine_state.permit_shebang != load_shebang_blocked) {
        int permission = lmt_tointeger(L, 1);
        switch (permission) {
            case load_shebang_disabled:
            case load_shebang_enabled:
            case load_shebang_blocked:
                lmt_engine_state.permit_shebang = permission;
                break;
            default:
                /* error, silently recover */
                break;
        }
    }
    return 0;
}

static int filelib_loadfile(lua_State *L)
{
    const char *filename = luaL_optstring(L, 1, NULL);
    const char *mode     = luaL_optstring(L, 2, NULL);
    int status = filelib_loadfilex(L, filename, mode);
    if (status == LUA_OK) {
        return 1; /* function */
    } else {
        lua_pushnil(L);
        lua_insert(L, -2); /* nil, error_message */
        return 2;
    }
}

static int filelib_dofile(lua_State *L)
{
    const char *filename = luaL_optstring(L, 1, NULL);
    if (lmt_unlikely(filelib_loadfilex(L, filename, "bt") != LUA_OK)) {
        return lua_error(L);
    } else {
        lua_replace(L, 1);
        lua_settop(L, 1);
        lua_call(L, 0, LUA_MULTRET);
        return lua_gettop(L);
    }
}

static const char *filelib_searchpath(
    lua_State  *L,
    const char *name,
    const char *path,
    const char *sep,
    const char *dirsep
)
{
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    if (*sep != '\0' && strchr(name, *sep) != NULL) {
        name = luaL_gsub(L, name, sep, dirsep);
    }
    while (*path != '\0') {
     // const char *sub = strchr(path, '?');
     // if (sub != NULL) {
     //     luaL_addlstring(&b, path, sub - path);
     //     luaL_addstring(&b, name);
     //     path = sub + 1;
     // }
     // const char *next = strchr(path, ';');
     // if (next == NULL) {
     //     luaL_addstring(&b, path);
     //     path = ""; /* ends the loop on the next iteration */
     // } else {
     //     luaL_addlstring(&b, path, next - path);
     //     path = next + 1; /* jumps past the semicolon */
     // }
        const char *next = strchr(path, ';');
        size_t templen = next ? (size_t) (next - path) : strlen(path);
        const char *sub = memchr(path, '?', templen);
        if (sub != NULL) {
            luaL_addlstring(&b, path, sub - path);
            luaL_addstring(&b, name);
            luaL_addlstring(&b, sub + 1, (path + templen) - (sub + 1));
        } else {
            luaL_addlstring(&b, path, templen);
        }
        path += templen;
        if (*path == ';') {
            path++;
        }
        /* */
        luaL_pushresult(&b);
        const char *filename = lua_tostring(L, -1);
# if defined(_WIN32)
        wchar_t *wfilename = aux_utf8_to_wide(filename);
        if (wfilename) {
            FILE *f = _wfopen(wfilename, L"r");
            lmt_memory_free(wfilename);
            if (f) {
                fclose(f);
                return filename; /* file path left at top of stack */
            }
        }
# else
        FILE *f = fopen(filename, "r");
        if (f) {
            fclose(f);
            return filename;
        }
# endif
        lua_pop(L, 1); /* next path */
        luaL_buffinit(L, &b);
    }
    lua_pushfstring(L, "no file '%s'", name);
    return NULL;
}

static int filelib_package_searcher_file(lua_State *L)
{
    const char *name = luaL_checkstring(L, 1);
    lua_getfield(L, lua_upvalueindex(1), "path");
    if (! lua_isstring(L, -1)) {
        lua_pushfstring(L, "no 'package.path'");
        return 1;
    } else {
        const char *filename = filelib_searchpath(L, name, lua_tostring(L, -1), ".", "/");
        if (filename == NULL) {
            return 1; /* error message */
        } else if (filelib_loadfilex(L, filename, "bt") == LUA_OK) {
            lua_pushstring(L, filename);
            return 2; /* chunk and filename */
        } else {
            return luaL_error(L, "error loading module '%s' from file '%s':\n\t%s", name, filename, lua_tostring(L, -1));
        }
    }
}

/* */

static const struct luaL_Reg filelib_function_list[] = {
    { "attributes",      filelib_attributes        },
    { "currentdir",      filelib_currentdir        },
    { "dir",             filelib_dir               },
    { "chdir",           filelib_chdir             }, /* security : readable */
    { "mkdir",           filelib_mkdir             }, /* security : writeable */
    { "rmdir",           filelib_rmdir             }, /* security : writeable */
    { "touch",           filelib_touch             }, /* security : writeable */
    { "expandpath",      filelib_expandpath        },
    { "canonicalize",    filelib_canonicalize      },
    /* */
    { "link",            filelib_link              }, /* security : writeable */
    { "symlink",         filelib_symlink           }, /* security : writeable */
    { "setexecutable",   filelib_setexecutable     }, /* security : writeable */
    { "symlinktarget",   filelib_symlinktarget     },
    /* */
    { "isdir",           filelib_isdir             },
    { "isfile",          filelib_isfile            },
    { "iswriteabledir",  filelib_iswriteabledir    }, /* security */
    { "iswriteablefile", filelib_iswriteablefile   }, /* security */
    { "isreadabledir",   filelib_isreadabledir     }, /* security */
    { "isreadablefile",  filelib_isreadablefile    }, /* security */
    /* */
    { "lessweird",       filelib_lessweird         },
    { "moreweird",       filelib_moreweird         },
    /* */
    { "setloadshebang",  filelib_setloadshebang    },
    /* */
    { NULL,              NULL                      },
};

int luaopen_filelib(lua_State *L)
{
    /* */
    lua_pushcfunction(L, filelib_loadfile);
    lua_setglobal(L, "loadfile");                     /* security: loadable */
    /* */
    lua_pushcfunction(L, filelib_dofile);
    lua_setglobal(L, "dofile");                       /* security: loadable */
    /* */
    lua_getglobal(L, "package");
    if (lua_istable(L, -1)) {
        lua_getfield(L, -1, "searchers");             /* security: loadable */
        if (lua_istable(L, -1)) {
            lua_pushvalue(L, -2);
            lua_pushcclosure(L, filelib_package_searcher_file, 1);
            lua_rawseti(L, -2, 2);
        }
        lua_pop(L, 1); // searchers
    }
    lua_pop(L, 1); // package
    /* */
    dir_create_metatable(L);
    luaL_newlib(L, filelib_function_list);
    return 1;
}
