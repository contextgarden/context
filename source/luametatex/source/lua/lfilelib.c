/*

    See license.txt in the root of this project.

    This is a replacement for lfs, a file system manipulation library from the
    Kepler project. I started from the lfs.c file from luatex because we need to
    keep a similar interface. That file mentioned:

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

    We have additional code in other modules and the code was already adapted a
    little.

    Because \TEX| is multi-platform we try to provide a consistent interface. So,
    for instance blocksize and inode number are not relevant for us, nor are user
    and group ids. The lock functions have been removed as they serve no purpose
    in a \TEX\ system and devices make no sense either. The iterator could be
    improved. I also fixed some anomalities. Permissions are not useful either.

*/

# ifndef _WIN32
#   ifndef _AIX
#     define _FILE_OFFSET_BITS 64
#   else
#     define _LARGE_FILES 1 /* AIX */
#   endif
# endif

# ifdef WINVER
# undef WINVER
# endif

# ifdef _WIN32_WINNT
# undef _WIN32_WINNT
# endif

// 0x0601 Windows 7+

# define WINVER       0x0601
# define _WIN32_WINNT 0x0601

# define _LARGEFILE64_SOURCE

# include <errno.h>
# include <stdio.h>
# include <string.h>
# include <stdlib.h>
# include <time.h>
# include <sys/stat.h>

# ifdef _WIN32
#   include <direct.h>
#   include <windows.h>
#   include <io.h>
#   include <sys/locking.h>
#   include <sys/utime.h>
#   include <fcntl.h>
#   define MY_MAXPATHLEN MAX_PATH
# else
/* the next one is sensitive for c99 */
#   include <unistd.h>
#   include <dirent.h>
#   include <stdio.h>
#   include <fcntl.h>
#   include <sys/types.h>
#   include <utime.h>
#   include <sys/param.h>
#   define MY_MAXPATHLEN MAXPATHLEN
# endif

# ifdef _WIN32
#   ifndef S_ISDIR
#     define S_ISDIR(mode) (mode&_S_IFDIR)
#   endif
#   ifndef S_ISREG
#     define S_ISREG(mode) (mode&_S_IFREG)
#   endif
#   ifndef S_ISLNK
#     define S_ISLNK(mode) (0)
#   endif
#   ifndef S_ISSUB
#     define S_ISSUB(mode) (file_data.attrib & _A_SUBDIR)
#   endif
#   define info_struct     struct _stati64
#   define get_stat        _stati64
#   define mk_dir(p)       (_mkdir(p))
#   define ch_dir(p)       (_chdir(p))
#   define get_cwd(d,s)    (_getcwd(d,s))
#   define rm_dir(p)       (_rmdir(p))
#   define mk_symlink(f,t) (CreateSymbolicLinkA(t,f,0x2) != 0)
#   define mk_link(f,t)    (CreateSymbolicLinkA(t,f,0x3) != 0)
#   define ch_to_exec(f,n) (_chmod(f,n))
#   define exec_mode_flag  _S_IEXEC
# else
#   define info_struct     struct stat
#   define get_stat        stat
#   define mk_dir(p)       (mkdir((p), S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH))
#   define ch_dir          chdir
#   define get_cwd         getcwd
#   define rm_dir          rmdir
#   define mk_symlink(f,t) (symlink(f,t) != -1)
#   define mk_link(f,t)    (link(f,t) != -1)
#   define ch_to_exec(f,n) (chmod(f,n))
#   define exec_mode_flag  S_IXUSR
# endif

# include <lua.h>
# include <lauxlib.h>
# include <lualib.h>

# include "lfilelib.h"

# ifdef _WIN32

    typedef struct dir_data {
        intptr_t handle;
        int closed;
        char pattern[MY_MAXPATHLEN+1];
    } dir_data;

# else

    typedef struct dir_data {
        DIR *handle;
        int closed;
        char pattern[MY_MAXPATHLEN+1];
    } dir_data;

# endif

/*
    This function changes the current directory.

    success = chdir(name)
*/

static int change_dir(lua_State *L) {
    lua_pushboolean(L, ! ch_dir(luaL_checkstring(L, 1)));
    return 1;
}

/*
    This function returns the current directory or false.

    name = currentdir()
*/

static int get_currentdir(lua_State *L)
{
    char *path = NULL;
    size_t size = MY_MAXPATHLEN;
    while (1) {
        path = realloc(path, size);
        if (! path) {
            lua_pushboolean(L,0);
            break;
        }
        if (get_cwd(path, size) != NULL) {
            lua_pushstring(L, path);
            break;
        }
        if (errno != ERANGE) {
            lua_pushboolean(L,0);
            break;
        }
        size *= 2;
    }
    free(path);
    return 1;
}

/*
    This functions create a link:

    success = link(target,name,[true=symbolic])
    success = symlink(target,name)
*/

static int make_link(lua_State *L)
{
    const char *oldpath = luaL_checkstring(L, 1);
    const char *newpath = luaL_checkstring(L, 2);
    lua_pushboolean(L, lua_toboolean(L,3) ? mk_symlink(oldpath,newpath) : mk_link(oldpath,newpath));
    return 1;
}

static int make_symlink(lua_State *L)
{
    const char *oldpath = luaL_checkstring(L, 1);
    const char *newpath = luaL_checkstring(L, 2);
    lua_pushboolean(L, mk_symlink(oldpath,newpath));
    return 1;
}


/*
    This function creates a directory.

    success = mkdir(name)
*/

static int make_dir(lua_State *L)
{
    lua_pushboolean(L, (mk_dir(luaL_checkstring(L, 1)) != -1));
    return 1;
}

/*
    This function removes a directory (non-recursive).

    success = mkdir(name)
*/

static int remove_dir(lua_State *L)
{
    lua_pushboolean(L, (rm_dir(luaL_checkstring(L, 1)) != -1));
    return 1;
}

/*
    The directory iterator returns multiple values:

    for name, mode, size, mtime in dir(path) do ... end

    For practical reasons we keep the metatable the same.

*/

# define DIR_METATABLE "directory metatable"

# ifdef _WIN32

#   define push_entry(L,file_data) do { \
        lua_pushstring(L, file_data.name); \
        if (S_ISSUB(file_data.attrib)) { \
            lua_pushstring(L,"directory"); \
        } else { \
            lua_pushstring(L,"file"); \
        } \
        lua_pushinteger(L,file_data.size); \
        lua_pushinteger(L,file_data.time_write); \
    } while (0)

    static int dir_iter(lua_State *L)
    {
        struct _finddata_t file_data;
        dir_data *d = (dir_data *) luaL_checkudata(L, 1, DIR_METATABLE);
        luaL_argcheck(L, d->closed == 0, 1, "closed directory");
        if (d->handle == 0L) {
            /* first entry */
            if ((d->handle = _findfirst(d->pattern, &file_data)) == -1L) {
                d->closed = 1;
                return 0;
            } else {
                push_entry(L,file_data);
                return 4;
            }
        } else if (_findnext(d->handle, &file_data) == -1L) {
            /* no more entries */
            _findclose(d->handle);
            d->closed = 1;
            return 0;
        } else {
            /* successive entries */
            push_entry(L,file_data);
            return 4;
        }
    }

    static int dir_close(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, 1);
        if (!d->closed && d->handle) {
            _findclose(d->handle);
        }
        d->closed = 1;
        return 0;
    }

    static int dir_iter_factory(lua_State *L)
    {
        const char *path = luaL_checkstring(L, 1);
        dir_data *d ;
        lua_pushcfunction(L, dir_iter);
        d = (dir_data *) lua_newuserdata(L, sizeof(dir_data));
        luaL_getmetatable(L, DIR_METATABLE);
        lua_setmetatable(L, -2);
        d->closed = 0;
        d->handle = 0L;
        if (strlen(path) > MY_MAXPATHLEN-2) {
            luaL_error(L, "path too long: %s", path);
        } else {
            sprintf(d->pattern, "%s/*", path); /* brrr */
        }
        return 2;
    }

# else

    /*tex

        On unix we cannot get the size and time in one go without interference. Also,
        not all filesystems return this field. So eventually we might not do this on
        unix and revert to the slower method at the lua end when DT_DIR is undefined.

    */

    static int dir_iter(lua_State *L)
    {
        struct dirent *entry;
        dir_data *d = (dir_data *)luaL_checkudata(L, 1, DIR_METATABLE);
        luaL_argcheck(L, d->closed == 0, 1, "closed directory");
        if ((entry = readdir(d->handle)) != NULL) {
            info_struct info;
            char file_path[2*MY_MAXPATHLEN];
            lua_pushstring(L, entry->d_name);
            if (entry->d_type == DT_UNKNOWN) {    /* DT_UNKNOWN == 0 */
                lua_pushnil(L);
            } else if (entry->d_type == DT_DIR) { /* DT_DIR == 4 */
                lua_pushstring(L,"directory");
            } else {                              /* DT_REG == 8 */
                lua_pushstring(L,"file");
            }
            snprintf(file_path, 2*MY_MAXPATHLEN, "%s/%s", d->pattern, entry->d_name);
            if (!get_stat(file_path, &info)) {
                lua_pushinteger(L,info.st_size);
                lua_pushinteger(L,info.st_mtime);
                return 4;
            } else {
                return 2;
            }
        } else {
            closedir(d->handle);
            d->closed = 1;
            return 0;
        }
    }

    static int dir_close(lua_State *L)
    {
        dir_data *d = (dir_data *) lua_touserdata(L, 1);
        if (!d->closed && d->handle) {
            closedir(d->handle);
        }
        d->closed = 1;
        return 0;
    }

    static int dir_iter_factory(lua_State *L)
    {
        const char *path = luaL_checkstring(L, 1);
        dir_data *d ;
        lua_pushcfunction(L, dir_iter);
        d = (dir_data *) lua_newuserdata(L, sizeof(dir_data));
        luaL_getmetatable(L, DIR_METATABLE);
        lua_setmetatable(L, -2);
        d->closed = 0;
        d->handle = opendir(path);
        if (d->handle == NULL) {
            luaL_error(L, "cannot open %s: %s", path, strerror(errno));
        }
        snprintf(d->pattern, MY_MAXPATHLEN, "%s", path);
        return 2;
    }

# endif

static int dir_create_meta(lua_State *L)
{
    luaL_newmetatable(L, DIR_METATABLE);
    lua_newtable(L);
    lua_pushcfunction(L, dir_iter);
    lua_setfield(L, -2, "next");
    lua_pushcfunction(L, dir_close);
    lua_setfield(L, -2, "close");
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, dir_close);
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
        int i = 0; for (;i<9;i++) perms[i]='-';
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
        int i = 0; for (;i<9;i++) perms[i]='-';
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

    utime(filename)                   : current, current
    utime(filename,acess)             : access, access
    utime(filename,acess,modifcation) : access, modufication
*/

static int touch_file(lua_State *L)
{
    const char *file = luaL_checkstring(L, 1);
    struct utimbuf utb, *buf;
    if (lua_gettop(L) == 1) {
        buf = NULL;
    } else {
        utb.actime = (time_t) luaL_optnumber(L, 2, 0);
        utb.modtime = (time_t) luaL_optinteger(L, 3, utb.actime);
        buf = &utb;
    }
    lua_pushboolean(L,(utime(file, buf) != -1));
    return 1;
}

static void push_st_mode (lua_State *L, info_struct *info) { lua_pushstring (L,  mode2string (info->st_mode)); } /* inode protection mode */
static void push_st_size (lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_size);  } /* file size, in bytes */
static void push_st_mtime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_mtime); } /* time of last data modification */
static void push_st_atime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_atime); } /* time of last access */
static void push_st_ctime(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_ctime); } /* time of last file status change */
static void push_st_perm (lua_State *L, info_struct *info) { lua_pushstring (L,  perm2string (info->st_mode)); } /* permssions string */
static void push_st_nlink(lua_State *L, info_struct *info) { lua_pushinteger(L, (lua_Integer) info->st_nlink); } /* number of hard links to the file */

typedef void (*_push_function) (lua_State *L, info_struct *info);

struct _stat_members {
    const char *name;
    _push_function push;
};

static struct _stat_members members[] = {
    { "mode",         push_st_mode },
    { "size",         push_st_size },
    { "modification", push_st_mtime },
    { "access",       push_st_atime },
    { "change",       push_st_ctime },
    { "permissions",  push_st_perm },
    { "nlink",        push_st_nlink },
    { NULL,           NULL }
};

/*
    Get file or symbolic link information. Returns a table or nil.
*/

static int get_attributes(lua_State *L)
{
    info_struct info;
    const char *file = luaL_checkstring(L, 1);
    int i;
    if (get_stat(file, &info)) {
        lua_pushnil(L);
        return 1;
    } else if (lua_isstring(L, 2)) {
        const char *member = lua_tostring(L, 2);
        for (i = 0; members[i].name; i++) {
            if (strcmp(members[i].name, member) == 0) {
                members[i].push(L, &info);
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        lua_settop(L, 2);
        if (!lua_istable(L, 2)) {
            lua_createtable(L,0,6);
        }
        for (i = 0; members[i].name; i++) {
            lua_pushstring(L, members[i].name);
            members[i].push(L, &info);
            lua_rawset(L, -3);
        }
        return 1;
    }
}

# define is_whatever(L,IS_OK,okay) do { \
    info_struct info; \
    const char *name = luaL_checkstring(L, 1); \
    if (get_stat(name, &info)) { \
        lua_pushboolean(L,0); \
    } else { \
        lua_pushboolean(L,okay && ! access(name,IS_OK)); \
    } \
    return 1; \
} while(1)

static int is_dir           (lua_State *L) { is_whatever(L,F_OK,(S_ISDIR(info.st_mode))); }
static int is_readable_dir  (lua_State *L) { is_whatever(L,R_OK,(S_ISDIR(info.st_mode))); }
static int is_writeable_dir (lua_State *L) { is_whatever(L,W_OK,(S_ISDIR(info.st_mode))); }

static int is_file          (lua_State *L) { is_whatever(L,F_OK,(S_ISREG(info.st_mode) || S_ISLNK(info.st_mode))); } /* Really LNK here? */
static int is_readable_file (lua_State *L) { is_whatever(L,R_OK,(S_ISREG(info.st_mode) || S_ISLNK(info.st_mode))); } /* Really LNK here? */
static int is_writeable_file(lua_State *L) { is_whatever(L,W_OK,(S_ISREG(info.st_mode) || S_ISLNK(info.st_mode))); } /* Really LNK here? */

static int set_executable(lua_State *L)
{
    info_struct info;
    const char *name = luaL_checkstring(L, 1);
    int ok = 0;
    if (! get_stat(name, &info)) {
        if (S_ISREG(info.st_mode)) {
            ch_to_exec(name,info.st_mode | exec_mode_flag);
            if (! get_stat(name, &info)) {
                ok = info.st_mode & exec_mode_flag;
            }
        }
    }
    lua_pushboolean(L,ok);
    return 1;
}

/*
    Push the symlink target to the top of the stack. Assumes the file name is at
    position 1 of the stack. Returns 1 if successful (with the target on top of
    the stack), 0 on failure (with stack unchanged, and errno set).

    link("name")          : table
    link("name","target") : targetname
*/

// # ifdef _WIN32
//
//     static int get_link_attributes(lua_State *L)
//     {
//         lua_pushnil(L);
//         return 1;
//     }
//
// # else
//
//     static int push_link_target(lua_State *L)
//     {
//         const char *file = luaL_checkstring(L, 1);
//         char *target = NULL;
//         int tsize, size = 256; /* size = initial buffer capacity */
//         while (1) {
//             target = realloc(target, size);
//             if (! target) {
//                 return 0;
//             }
//             tsize = readlink(file, target, size);
//             if (tsize < 0) {
//                 /* error */
//                 free(target);
//                 return 0;
//             }
//             if (tsize < size) {
//                 break;
//             }
//             /* possibly truncated readlink() result, double size and retry */
//             size *= 2;
//         }
//         target[tsize] = '\0';
//         lua_pushlstring(L, target, tsize);
//         free(target);
//         return 1;
//     }
//
//     static int get_link_attributes(lua_State *L)
//     {
//         if (lua_isstring(L, 2) && (strcmp(lua_tostring(L, 2), "target") == 0)) {
//             if (! push_link_target(L)) {
//                 lua_pushnil(L);
//             }
//         } else {
//             int ret = get_attributes(L);
//             if (ret == 1 && lua_type(L, -1) == LUA_TTABLE) {
//                 if (push_link_target(L)) {
//                     lua_setfield(L, -2, "target");
//                 }
//             } else {
//                 lua_pushnil(L);
//             }
//         }
//         return 1;
//     }
//
// # endif

static const struct luaL_Reg fslib[] = {
    { "attributes",        get_attributes },
    { "chdir",             change_dir },
    { "currentdir",        get_currentdir },
    { "dir",               dir_iter_factory },
    { "mkdir",             make_dir },
    { "rmdir",             remove_dir },
    { "touch",             touch_file },
    /* */
    { "link",              make_link },
    { "symlink",           make_symlink },
    { "setexecutable",     set_executable },
 /* { "symlinkattributes", get_link_attributes }, */
    /* */
    { "isdir",             is_dir },
    { "isfile",            is_file },
    { "iswriteabledir",    is_writeable_dir },
    { "iswriteablefile",   is_writeable_file },
    { "isreadabledir",     is_readable_dir },
    { "isreadablefile",    is_readable_file },
    /* */
    { NULL,                NULL },
};

int luaopen_filelib(lua_State *L) {
    dir_create_meta(L);
    luaL_newlib(L,fslib);
    return 1;
}
