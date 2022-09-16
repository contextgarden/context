/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_FILE_H
# define LMT_UTILITIES_FILE_H

/*tex

    We have to deal with wide characters on windows when it comes to filenames. The same is true for
    the commandline and environment variables. Basically we go from utf8 to wide and back.

    \starttyping
    libraries/zlib/crc32.c          : fopen -> minimalistic, goes via lua anyway
    libraries/zlib/trees.c          : fopen -> minimalistic, goes via lua anyway
    libraries/zlib/zutil.h          : fopen -> minimalistic, goes via lua anyway

    lua/llualib.c                   : fopen -> utf8_fopen
    lua/lenginelib.c                : fopen -> utf8_fopen

    luacore/lua54/src/lauxlib.c     : fopen -> see below
    luacore/lua54/src/liolib.c      : fopen -> see below
    luacore/lua54/src/loadlib.c     : fopen -> see below

    luaffi/call.c                   : fopen -> not used

    mp/mpw/mp.w                     : fopen -> overloaded by callback

    libraries/pplib/ppload.c        : fopen -> will be abstraction (next pplib)

    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used
    libraries/pplib/util/utiliof.c  : fopen -> not used

    tex/texfileio.c     12:         : fopen -> utf8_fopen
    \stoptyping

    Furthermore:

    \starttyping
    - system commands (execute) : done
    - popen                     : done

    - lua rename                : done
    - lua remove                : done

    - command line argv         : done
    - lua setenv                : done
    - lua getenv                : done

    - lfs attributes            : done
    - lfs chdir                 : done
    - lfs currentdir            : done
    - lfs dir                   : done
    - lfs mkdir                 : done
    - lfs rmdir                 : done
    - lfs touch                 : done
    - lfs link                  : done
    - lfs symlink               : done
    - lfs setexecutable         : done (needs testing)
    - lfs isdir                 : done
    - lfs isfile                : done
    - lfs iswriteabledir        : done
    - lfs iswriteablefile       : done
    - lfs isreadabledir         : done
    - lfs isreadablefile        : done
    \stoptyping

    Kind of tricky because quite some code (indirectness):

    \starttyping
    - lua load                  : via overload ?
    - lua dofile                : via overload -> loadstring
    - lua require               : via overload ?
    \stoptyping

    So: do we patch lua (fopen) or just copy? We can actually assume flat ascii files for libraries
    and such so there is no real need unless we load job related files.

    I will probably reshuffle some code and maybe more some more here; once I'm sure all works out
    well.

*/

# ifdef _WIN32

    # include <windows.h>
    # include <ctype.h>
    # include <stdio.h>

    extern LPWSTR  aux_utf8_to_wide    (const char *utf8str);
    extern char   *aux_utf8_from_wide  (LPWSTR widestr);

    extern FILE   *aux_utf8_fopen      (const char *path, const char *mode);
    extern FILE   *aux_utf8_popen      (const char *path, const char *mode);
    extern int     aux_utf8_system     (const char *cmd);
    extern int     aux_utf8_remove     (const char *name);
    extern int     aux_utf8_rename     (const char *oldname, const char *newname);
    extern int     aux_utf8_setargv    (char * **av, char **argv, int argc);
    extern char   *aux_utf8_getownpath (const char *file);

# else

    # define       aux_utf8_fopen      fopen
    # define       aux_utf8_popen      popen
    # define       aux_utf8_system     system
    # define       aux_utf8_remove     remove
    # define       aux_utf8_rename     rename

    extern int     aux_utf8_setargv    (char * **av, char **argv, int argc);
    extern char   *aux_utf8_getownpath (const char *file);

    # include <libgen.h>

# endif

# ifdef _WIN32

    extern char *aux_basename (const char *name);
    extern char *aux_dirname  (const char *name);

# else

    # define aux_basename basename
    # define aux_dirname  dirname

# endif

extern int aux_is_readable (const char *filename);

/*tex

    We support unix and windows. In fact, we could stick to |/| only. When
    scanning filenames entered in \TEX\ we can actually enforce a |/| as
    convention.

*/

# ifndef IS_DIR_SEP
    # ifdef _WIN32
        # define IS_DIR_SEP(ch) ((ch) == '/' || (ch) == '\\')
    # else
        # define IS_DIR_SEP(ch) ((ch) == '/')
    # endif
# endif

# ifndef R_OK
    # define F_OK 0x0
    # define W_OK 0x2
    # define R_OK 0x4
# endif

# ifndef S_ISREG
    # define S_ISREG(mode) (mode & _S_IFREG)
# endif

# endif
