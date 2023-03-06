/*

    See license.txt in the root of this project.

    This is a replacement for lfs, a file system manipulation library from the Kepler project. I
    started from the lfs.c file from luatex because we need to keep a similar interface. That
    file mentioned:

    Copyright Kepler Project 2003 - 2017 (http://keplerproject.github.io/luafilesystem)

    The original library offers the following functions:

        lfs.attributes(filepath [, attributename | attributetable])
        lfs.chdir(path)
        lfs.currentdir()
        lfs.dir(path)
        lfs.link(old, new[, symlink])
     -- lfs.lock(fh, mode)
     -- lfs.lock_dir(path)
        lfs.mkdir(path)
        lfs.rmdir(path)
     -- lfs.setmode(filepath, mode)
        lfs.symlinkattributes(filepath [, attributename])
        lfs.touch(filepath [, atime [, mtime]])
     -- lfs.unlock(fh)

    We have additional code in other modules and the code was already adapted a little. In the
    meantime the code looks quite different.

    Because \TEX| is multi-platform we try to provide a consistent interface. So, for instance
    blocksize and inode number are not relevant for us, nor are user and group ids. The lock
    functions have been removed as they serve no purpose in a \TEX\ system and devices make no
    sense either. The iterator could be improved. I also fixed some anomalities. Permissions are
    not useful either.

*/

# include "../lua/lmtinterface.h"
# include "../utilities/auxmemory.h"
# include "../utilities/auxfile.h"

# ifndef R_OK
# define F_OK 0x0
# define W_OK 0x2
# define R_OK 0x4
# endif

# define DIR_METATABLE "file.directory"

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

// # ifndef _LARGEFILE64_SOURCE
    # define _LARGEFILE64_SOURCE 1
// # endif

# include <errno.h>
# include <stdio.h>
# include <string.h>
# include <stdlib.h>
# include <time.h>
# include <sys/stat.h>

// # ifdef _MSC_VER
//     # ifndef MAX_PATH
//         # define MAX_PATH 256
//     # endif
// # endif

# ifdef _WIN32

    # include <direct.h>
    # include <windows.h>
    # include <io.h>
    # include <sys/locking.h>
    # include <sys/utime.h>
    # include <fcntl.h>

    # define MY_MAXPATHLEN MAX_PATH

# else

    /* the next one is sensitive for c99 */

    # include <unistd.h>
    # include <dirent.h>
    # include <fcntl.h>
    # include <sys/types.h>
    # include <utime.h>
    # include <sys/param.h>

    # define MY_MAXPATHLEN MAXPATHLEN

# endif

/* This has to go to the h file. See luainit.c where it's also needed. */

# ifdef _WIN32

    # ifndef S_ISDIR
        # define S_ISDIR(mode) (mode & _S_IFDIR)
    # endif

    # ifndef S_ISREG
        # define S_ISREG(mode) (mode & _S_IFREG)
    # endif

    # ifndef S_ISLNK
        # define S_ISLNK(mode) (0)
    # endif

    # ifndef S_ISSUB
        # define S_ISSUB(mode) (file_data.attrib & _A_SUBDIR)
    # endif

    # define info_struct  struct _stati64
    # define utime_struct struct __utimbuf64

    # define exec_mode_flag  _S_IEXEC

    /*
        There is a difference between msvc and mingw wrt the daylight saving time correction being
        applied toy the times. I couldn't figure it out and don't want to waste more time on it.
    */

    typedef struct dir_data {
        intptr_t handle;
        int      closed;
        char     pattern[MY_MAXPATHLEN+1];
    } dir_data;

    static int get_stat(const char *s, info_struct *i)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wstati64(w, i);
        lmt_memory_free(w);
        return r;
    }

    static int mk_dir(const char *s)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wmkdir(w);
        lmt_memory_free(w);
        return r;
    }

    static int ch_dir(const char *s)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wchdir(w);
        lmt_memory_free(w);
        return r;
    }

    static int rm_dir(const char *s)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wrmdir(w);
        lmt_memory_free(w);
        return r;
    }

 // # if defined(__MINGW64__) || defined(__MINGW32__)
 //     extern int CreateSymbolicLinkW(LPCWSTR lpSymlinkFileName, LPCWSTR lpTargetFileName, DWORD dwFlags);
 // # endif 

    static int mk_symlink(const char *t, const char *f)
    {
        LPWSTR wt = aux_utf8_to_wide(t);
        LPWSTR wf = aux_utf8_to_wide(f);
        int r = CreateSymbolicLinkW((LPCWSTR) t, (LPCWSTR) f, 0x2) != 0;
        lmt_memory_free(wt);
        lmt_memory_free(wf);
        return r;
    }

    static int mk_link(const char *t, const char *f)
    {
        LPWSTR wt = aux_utf8_to_wide(t);
        LPWSTR wf = aux_utf8_to_wide(f);
        int r = CreateSymbolicLinkW((LPCWSTR) t, (LPCWSTR) f, 0x3) != 0;
        lmt_memory_free(wt);
        lmt_memory_free(wf);
        return r;
    }

    static int ch_to_exec(const char *s, int n)
    {
        LPWSTR w = aux_utf8_to_wide(s);
        int r = _wchmod(w, n);
        lmt_memory_free(w);
        return r;
    }

 // # ifdef _MSC_VER
 //
 //     static int set_utime(const char *s, utime_struct *b)
 //     {
 //         LPWSTR w = utf8_to_wide(s);
 //         HANDLE h = CreateFileW(w, GENERIC_WRITE, FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
 //         int r = -1;
 //         lmt_memory_free(w);
 //         if (h != INVALID_HANDLE_VALUE) {
 //             r = SetFileTime(h, (const struct _FILETIME *) b, (const struct _FILETIME *) b, (const struct _FILETIME *) b);
 //             CloseHandle(h);
 //         }
 //         return r;
 //     }
 //
 // # else

        static int set_utime(const char *s, utime_struct *b)
        {
            LPWSTR w = aux_utf8_to_wide(s);
            int r = _wutime64(w, b);
            lmt_memory_free(w);
            return r;
        }

 // # endif

# else

    # define info_struct     struct stat
    # define utime_struct    struct utimbuf

    typedef struct dir_data {
        DIR  *handle;
        int   closed;
        char  pattern[MY_MAXPATHLEN+1];
    } dir_data;

    # define get_stat        stat
    # define mk_dir(p)       (mkdir((p), S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH))
    # define ch_dir          chdir
    # define get_cwd         getcwd
    # define rm_dir          rmdir
    # define mk_symlink(f,t) (symlink(f,t) != -1)
    # define mk_link(f,t)    (link(f,t) != -1)
    # define ch_to_exec(f,n) (chmod(f,n))
    # define exec_mode_flag  S_IXUSR | S_IXGRP | S_IXOTH
    # define set_utime(f,b)  utime(f,b)

# endif

# include <lua.h>
# include <lauxlib.h>
# include <lualib.h>

/*
    This function changes the current directory.

    success = chdir(name)
*/

static int filelib_chdir(lua_State *L) {
    if (lua_type(L, 1) == LUA_TSTRING) {
        lua_pushboolean(L, ! ch_dir(luaL_checkstring(L, 1)));
    } else {
        lua_pushboolean(L, 0);
    }
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
            wpath = temp;
            if (! wpath) {
                lua_pushboolean(L, 0);
                break;
            } else if (_wgetcwd(wpath, size)) {
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
            path = lmt_memory_realloc(path, size);
            if (! path) {
                lua_pushboolean(L,0);
                break;
            }
            if (get_cwd(path, size)) {
                lua_pushstring(L, path);
                break;
            }
            if (errno != ERANGE) {
                lua_pushboolean(L,0);
                break;
            }
            size *= 2;
        }
        lmt_memory_free(path);
        return 1;
    }

# endif

/*
    This functions create a link:

    success = link(target,name,[true=symbolic])
    success = symlink(target,name)
*/

static int filelib_link(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING && lua_type(L, 2) == LUA_TSTRING) {
        const char *oldpath = lua_tostring(L, 1);
        const char *newpath = lua_tostring(L, 2);
        lua_pushboolean(L, lua_toboolean(L, 3) ? mk_symlink(oldpath, newpath) : mk_link(oldpath, newpath));
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int filelib_symlink(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING && lua_type(L, 2) == LUA_TSTRING) {
        const char *oldpath = lua_tostring(L, 1);
        const char *newpath = lua_tostring(L, 2);
        lua_pushboolean(L, mk_symlink(oldpath, newpath));
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

/*
    This function creates a directory.

    success = mkdir(name)
*/

static int filelib_mkdir(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        lua_pushboolean(L, mk_dir(lua_tostring(L, 1)) != -1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

/*
    This function removes a directory (non-recursive).

    success = mkdir(name)
*/

static int filelib_rmdir(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        lua_pushboolean(L, rm_dir(luaL_checkstring(L, 1)) != -1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

/*
    The directory iterator returns multiple values:

    for name, mode, size, mtime in dir(path) do ... end

    For practical reasons we keep the metatable the same.

*/

# ifdef _WIN32

    inline static int push_entry(lua_State *L, struct _wfinddata_t file_data, int details)
    {
        char *s = aux_utf8_from_wide(file_data.name);
        lua_pushstring(L, s);
        lmt_memory_free(s);
        if (S_ISSUB(file_data.attrib)) {
            lua_push_key(directory);
        } else {
            lua_push_key(file);
        }
        if (details) {
            lua_pushinteger(L, file_data.size);
            lua_pushinteger(L, file_data.time_write);
            return 4;
        } else {
            return 2;
        }
    }

    static int filelib_aux_dir_iterator(lua_State *L)
    {
        struct _wfinddata_t file_data;
        int details = 1;
        dir_data *d = (dir_data *) luaL_checkudata(L, 1, DIR_METATABLE);
        lua_getiuservalue(L, 1, 1);
        details = lua_toboolean(L, -1);
        lua_pop(L, 1);
        luaL_argcheck(L, d->closed == 0, 1, "closed directory");
        if (d->handle == 0L) {
            /* first entry */
            LPWSTR s = aux_utf8_to_wide(d->pattern);
            if ((d->handle = _wfindfirst(s, &file_data)) == -1L) {
                d->closed = 1;
                lmt_memory_free(s);
                return 0;
            } else {
                lmt_memory_free(s);
                return push_entry(L, file_data, details);
            }
        } else if (_wfindnext(d->handle, &file_data) == -1L) {
            /* no more entries */
         /* lmt_memory_free(d->handle); */ /* is done for us */
            _findclose(d->handle);
            d->closed = 1;
            return 0;
        } else {
            /* successive entries */
            return push_entry(L, file_data, details);
        }
    }

    static int filelib_aux_dir_close(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, 1);
        if (!d->closed && d->handle) {
            _findclose(d->handle);
        }
        d->closed = 1;
        return 0;
    }

    static int filelib_dir(lua_State *L)
    {
        const char *path = luaL_checkstring(L, 1);
        int detail = lua_type(L, 2) == LUA_TBOOLEAN ? lua_toboolean(L, 2) : 1;
        dir_data *d ;
        lua_pushcfunction(L, filelib_aux_dir_iterator);
        d = (dir_data *) lua_newuserdatauv(L, sizeof(dir_data), 1);
        lua_pushboolean(L, detail);
        lua_setiuservalue(L, -2, 1);
        luaL_getmetatable(L, DIR_METATABLE);
        lua_setmetatable(L, -2);
        d->closed = 0;
        d->handle = 0L;
        if (path && strlen(path) > MY_MAXPATHLEN-2) {
            luaL_error(L, "path too long: %s", path);
        } else {
            sprintf(d->pattern, "%s/*", path ? path : "."); /* brrr */
        }
        return 2;
    }

# else

    /*tex

        On unix we cannot get the size and time in one go without interference. Also, not all file
        systems return this field. So eventually we might not do this on unix and revert to the
        slower method at the lua end when DT_DIR is undefined. After a report from the mailing
        list about symbolic link issues this is what Taco and I came up with. The |_less| variant
        is mainly there because in \UNIX\ we then can avoid a costly |stat| when we don't need the
        details (only a symlink demands such a |stat|).

    */

    static int filelib_aux_dir_iterator(lua_State *L)
    {
        struct dirent *entry;
        dir_data *d;
        int details = 1;
        lua_pushcfunction(L, filelib_aux_dir_iterator);
        d = (dir_data *) luaL_checkudata(L, 1, DIR_METATABLE);
        lua_getiuservalue(L, 1, 1);
        details = lua_toboolean(L, -1);
        lua_pop(L, 1);
        luaL_argcheck(L, d->closed == 0, 1, "closed directory");
        entry = readdir (d->handle);
        if (entry) {
            lua_pushstring(L, entry->d_name);
# ifdef _DIRENT_HAVE_D_TYPE
            if (! details) {
                if (entry->d_type == DT_DIR) {
                    lua_push_key(directory);
                    return 2;
                } else if (entry->d_type == DT_REG) {
                    lua_push_key(file);
                    return 2;
                }
            }
# endif
            /*tex We can have a symlink and/or we need the details an dfor both we need to |get_stat|. */
            {
                info_struct info;
                char file_path[2*MY_MAXPATHLEN];
                snprintf(file_path, 2*MY_MAXPATHLEN, "%s/%s", d->pattern, entry->d_name);
                if (! get_stat(file_path, &info)) {
                    if (S_ISDIR(info.st_mode)) {
                        lua_push_key(directory);
                    } else if (S_ISREG(info.st_mode) || S_ISLNK(info.st_mode)) {
                        lua_push_key(file);
                    } else {
                        lua_pushnil(L);
                        return 2;
                    }
                    if (details) {
                        lua_pushinteger(L, info.st_size);
                        lua_pushinteger(L, info.st_mtime);
                        return 4;
                    }
                } else {
                    lua_pushnil(L);
                }
                return 2;
            }
        } else {
            closedir(d->handle);
            d->closed = 1;
            return 0;
        }
    }

    static int filelib_aux_dir_close(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, 1);
        if (!d->closed && d->handle) {
            closedir(d->handle);
        }
        d->closed = 1;
        return 0;
    }

    static int filelib_dir(lua_State *L)
    {
        const char *path = luaL_checkstring(L, 1);
        dir_data *d;
        lua_pushcfunction(L, filelib_aux_dir_iterator);
        d = (dir_data *) lua_newuserdatauv(L, sizeof(dir_data), 1);
        lua_pushboolean(L, lua_type(L, 2) == LUA_TBOOLEAN ? lua_toboolean(L, 2) : 1);
        lua_setiuservalue(L, -2, 1);
        luaL_getmetatable(L, DIR_METATABLE);
        lua_setmetatable(L, -2);
        d->closed = 0;
        d->handle = opendir(path ? path : ".");
        if (! d->handle) {
            luaL_error(L, "cannot open %s: %s", path, strerror(errno));
        }
        snprintf(d->pattern, MY_MAXPATHLEN, "%s", path ? path : ".");
        return 2;
    }

# endif

static int dir_create_meta(lua_State *L)
{
    luaL_newmetatable(L, DIR_METATABLE);
    lua_newtable(L);
    lua_pushcfunction(L, filelib_aux_dir_iterator);
    lua_setfield(L, -2, "next");
    lua_pushcfunction(L, filelib_aux_dir_close);
    lua_setfield(L, -2, "close");
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, filelib_aux_dir_close);
    lua_setfield(L, -2, "__gc");
    return 1;
}

# define mode2string(mode) \
    ((S_ISREG(mode)) ? "file" : ((S_ISDIR(mode)) ? "directory" : ((S_ISLNK(mode)) ? "link" : "other")))

/* We keep this for a while: will change to { r, w, x hash }  */

# ifdef _WIN32

    static const char *perm2string(unsigned short mode)
    {
        static char perms[10] = "---------";
        /* persistent change hence the for loop */
        for (int i = 0; i < 9; i++) {
            perms[i]='-';
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
        /* persistent change hence the for loop */
        for (int i = 0; i < 9; i++) {
            perms[i]='-';
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
    if (lua_type(L, 1) == LUA_TSTRING) {
        const char *file = luaL_checkstring(L, 1);
        utime_struct utb, *buf;
        if (lua_gettop(L) == 1) {
            buf = NULL;
        } else {
            utb.actime = (time_t) luaL_optinteger(L, 2, 0);
            utb.modtime = (time_t) luaL_optinteger(L, 3, utb.actime);
            buf = &utb;
        }
        lua_pushboolean(L, set_utime(file, buf) != -1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static void push_st_mode (lua_State *L, info_struct *info) { lua_pushstring (L,  mode2string (info->st_mode)); } /* inode protection mode */
static void push_st_size (lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_size);  } /* file size, in bytes */
static void push_st_mtime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_mtime); } /* time of last data modification */
static void push_st_atime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_atime); } /* time of last access */
static void push_st_ctime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_ctime); } /* time of last file status change */
static void push_st_perm (lua_State *L, info_struct *info) { lua_pushstring (L,  perm2string (info->st_mode)); } /* permissions string */
static void push_st_nlink(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_nlink); } /* number of hard links to the file */

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
        if (get_stat(file, &info)) {
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

# define is_whatever(L,IS_OK,okay) do { \
    if (lua_type(L, 1) == LUA_TSTRING) { \
        info_struct info; \
        const char *name = lua_tostring(L, 1); \
        if (get_stat(name, &info)) { \
            lua_pushboolean(L, 0); \
        } else { \
            lua_pushboolean(L, okay && ! access(name, IS_OK)); \
        } \
    } else { \
        lua_pushboolean(L, 0); \
    } \
    return 1; \
} while(1)

static int filelib_isdir          (lua_State *L) { is_whatever(L, F_OK,(S_ISDIR(info.st_mode))); }
static int filelib_isreadabledir  (lua_State *L) { is_whatever(L, R_OK,(S_ISDIR(info.st_mode))); }
static int filelib_iswriteabledir (lua_State *L) { is_whatever(L, W_OK,(S_ISDIR(info.st_mode))); }

static int filelib_isfile         (lua_State *L) { is_whatever(L, F_OK,(S_ISREG(info.st_mode) || S_ISLNK(info.st_mode))); }
static int filelib_isreadablefile (lua_State *L) { is_whatever(L, R_OK,(S_ISREG(info.st_mode) || S_ISLNK(info.st_mode))); }
static int filelib_iswriteablefile(lua_State *L) { is_whatever(L, W_OK,(S_ISREG(info.st_mode) || S_ISLNK(info.st_mode))); }

static int filelib_setexecutable(lua_State *L)
{
    int ok = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        info_struct info;
        const char *name = lua_tostring(L, 1);
        if (! get_stat(name, &info) && S_ISREG(info.st_mode)) {
            if (ch_to_exec(name, info.st_mode | exec_mode_flag)) {
                /* the setting failed */
            } else {
                ok = 1;
            }
        } else {
            /* not a valid file */
        }
    }
    lua_pushboolean(L, ok);
    return 1;
}

/*
    Push the symlink target to the top of the stack. Assumes the file name is at position 1 of the
    stack. Returns 1 if successful (with the target on top of the stack), 0 on failure (with stack
    unchanged, and errno set).

    link("name")          : table
    link("name","target") : targetname
*/

static int filelib_symlinktarget(lua_State *L)
{
    const char *file = aux_utf8_readlink(luaL_checkstring(L, 1));
    if (file) {
        lua_pushstring(L, file);
    } else { 
        lua_pushnil(L);
    }
    return 1;
}

static const struct luaL_Reg filelib_function_list[] = {
    { "attributes",        filelib_attributes        },
    { "chdir",             filelib_chdir             },
    { "currentdir",        filelib_currentdir        },
    { "dir",               filelib_dir               },
    { "mkdir",             filelib_mkdir             },
    { "rmdir",             filelib_rmdir             },
    { "touch",             filelib_touch             },
    /* */
    { "link",              filelib_link              },
    { "symlink",           filelib_symlink           },
    { "setexecutable",     filelib_setexecutable     },
    { "symlinktarget",     filelib_symlinktarget     }, 
    /* */
    { "isdir",             filelib_isdir             },
    { "isfile",            filelib_isfile            },
    { "iswriteabledir",    filelib_iswriteabledir    },
    { "iswriteablefile",   filelib_iswriteablefile   },
    { "isreadabledir",     filelib_isreadabledir     },
    { "isreadablefile",    filelib_isreadablefile    },
    /* */
    { NULL,                NULL                      },
};

int luaopen_filelib(lua_State *L) {
    dir_create_meta(L);
    luaL_newlib(L,filelib_function_list);
    return 1;
}
