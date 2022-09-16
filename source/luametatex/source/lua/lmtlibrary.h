/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LLIBRARY_H
# define LMT_LLIBRARY_H

/*tex

    The normal \LUA\ library loader uses the same calls as below. After loading the initializer is
    looked up and called but here we use that method for locating more functions.

    -- anonymous cast: void(*)(void)

*/

/* Do we need LoadLibraryW here or are we never utf/wide? */

/* void : dlclose(lib) | string: dlerror() */

typedef void (*lmt_library_function);

# ifdef _WIN32

    # include <windows.h>

    typedef struct lmt_library {
        HMODULE lib;
        int     okay;
        int     padding;
    } lmt_library;

    # define lmt_library_open_indeed(filename)   LoadLibraryExA(filename, NULL, 0)
    # define lmt_library_close_indeed(lib)       FreeLibrary((HMODULE) lib)
    # define lmt_library_find_indeed(lib,source) (void *) GetProcAddress((HMODULE) lib, source)

# else

    # include <dlfcn.h>

    typedef struct lmt_library {
        void *lib;
        int   okay;
        int   padding;
    } lmt_library;

    # define lmt_library_open_indeed(filename)   dlopen(filename, RTLD_NOW | RTLD_LOCAL)
    # define lmt_library_close_indeed(lib)       dlclose(lib)
    # define lmt_library_find_indeed(lib,source) (void *) dlsym(lib, source)

# endif

extern void                 lmt_library_register   (lua_State *L, const char *name, luaL_Reg functions[]);
extern void                 lmt_library_initialize (lua_State *L);

extern lmt_library          lmt_library_load       (const char *filename);
extern lmt_library_function lmt_library_find       (lmt_library lib, const char *source);
extern int                  lmt_library_okay       (lmt_library lib);

# endif
