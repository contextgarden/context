/*
    See license.txt in the root of this project.
*/

# ifndef LUATEX_COMMON_H
#  define LUATEX_COMMON_H

/*tex

    The next number is updated when we sync with luatex. It has no real meaning in
    luametatex. As that is a deliberate action we code the number here. The source
    code is part of the context distribution so it can be in any repository.

*/

# define luatex_development_id 7079

/*tex

    As with all \TEX\ engines, \LUATEX\ started out with the \PASCAL\ version of
    \TEX\ (actually \PDFTEX). The first thing that was done (by Taco) was to
    create a permanent \CCODE\ base instead of \PASCAL. In the process, some
    macros and library interfacing wrappers were moved to the \LUATEX\ code base.
    For instance, because we are in the \CCODE\ domain, we don't really need
    mappings from functions in the \PASCAL\ domain to \CCODE.

    In the next stage of \LUATEX\ development, we went a but further and tried to
    get rid of more dependencies. Among the rationales for this is that we depend
    on \LUA, and whatever works for the \LUA\ codebase (which is quite portable)
    should also work for \LUATEX.

    The biggest complication there is the dependency on the \WEBC\ helpers and
    file system interface. However, this was already isolated to some extend. The
    idea is to first completely decouple this and then as option bring back that
    relation via the \KPSE\ \LUA\ module that can be loaded on demand. In the
    process there can be some side effects but in the end it gives a cleaner
    codebase.

    The \TEX\ memory model is based on packing data in memory words, but that
    concept is somewhat fluid as in the past we had 16 byte processors too.
    However, we now mostly think in 32 bit and internally \LUATEX\ will pack most
    of its node data in a multiples of 64 bits (called words).

    Because \TEX\ implements efficiently its own memory management of nodes, the
    address of a node is actually a number. Numbers like are sometimes indicates
    as |pointer|, but can also be called |halfword|. Dimensions also fit into
    half a word and are called |scaled| but again we see them being called
    |halfword|. What term is used depends a bit on the location and also on the
    original code. For now we keep this mix but maybe some day we will normalize
    this.

    When we have halfwords representing pointers (into the main memory array) we
    indicate an unset pointer as |null| (lowercase).

    We could reshuffle a lot more and normalize defined and enums but for now we
    stick to the way it's done in order to divert not too much from the
    ancestors. However, in due time it can evolve.

*/

/*tex

    The next include(s) are rather normal. Actually we have lots of common includes
    here now (mostly originating in the previosu code base), so that I get a picture
    of what is needed. We might move some to the separate modules but for now I
    like to keep the overview.

*/

# include <stdarg.h>
# include <string.h>
# include <math.h>
# include <stdlib.h>
# include <errno.h>
# include <float.h>
# include <locale.h>

/*tex

    We use proper warnings, error messages, and confusion reporting instead of:

    \starttyping
    # ifdef HAVE_ASSERT_H
    # include <assert.h>
    # else
    # define assert(expr)
    # endif
    \stoptyping

*/

/*tex

    We're coming from \PASCAL\ which has a boolean type, while in \CCODE\ an |int| is
    used. However, as we often have callbacks and and a connection with the \LUA\ end
    using |boolean|, |true| and |false| is often somewhat inconstent. For that reason
    we now use |int| instead. It also prevents interference with a different definition
    of |boolean|, something that we can into a few times in the past with external code.

    There were not that many explicit booleans used anyway so better be consistent in
    using integers than have an inconsistent mix.

*/

# undef boolean
# undef true
# undef false

# include <ctype.h>
# include <stdint.h>

/*tex

    We support unix and windows. In fact, we could stick to |/| only. When
    scanning filenames entered in \TEX\ we can actually enforce a |/| as
    convention. So we take a define from |#include <kpathsea/c-pathch.h>|:

    We assume and therefore enforce at least Windows 7. Inside \TEX\ one can just
    use forward slashes always.
*/

# ifdef WINVER
# undef WINVER
# endif

# ifdef _WIN32_WINNT
# undef _WIN32_WINNT
# endif

# define WINVER       0x0601
# define _WIN32_WINNT 0x0601

# ifndef IS_DIR_SEP
#   ifdef _WIN32
#     define IS_DIR_SEP(ch) ((ch) == '/' || (ch) == '\\')
#   else
#     define IS_DIR_SEP(ch) ((ch) == '/')
#   endif
# endif

/*tex Data type related macros: */

# ifdef _WIN32
    typedef __int64 integer64;
# else
    typedef int64_t integer64;
# endif

/* whatever */

# ifdef _WIN32
#   define inline __inline
# endif

# include <stdio.h>

# ifdef _WIN32
# define boolean
# endif

# ifdef _WIN32
#   define WIN32_LEAN_AND_MEAN
#   include <windows.h>
#   include <winerror.h>
#   include <fcntl.h>
#   include <io.h>
# else
#   include <unistd.h>
# endif

# include <time.h>    /*tex Provides |struct tm|. */
# include <signal.h>  /*tex Catch interrupts. */

# ifndef _WIN32
#   include <sys/time.h>
# endif

# include <sys/stat.h>
# include <libgen.h>

# if !defined (unix) && !defined (__unix__) && defined (__STDC__) && !defined (unlink)
#   define unlink remove
# endif

# define likely(x)   __builtin_expect(!!(x), 1)
# define unlikely(x) __builtin_expect(!!(x), 0)

/* # define LUAI_HASHLIMIT    6 */
/* # define LUA_USE_JUMPTABLE 0 */
/* # define LUA_BUILD_AS_DLL    */
/* # define LUA_CORE            */

# include "lua.h"
# include "lauxlib.h"

/*tex A couple of identifiers: */

# define My_Name "LuaMetaTeX"
# define my_name "luametatex"

# define COPYRIGHT_HOLDER "Taco Hoekwater"
# define BUG_ADDRESS      "dev-luatex@ntg.nl"
# define SUPPORT_ADDRESS  "context@ntg.nl"

# define LUA_VERSION_STRING ("Lua " LUA_VERSION_MAJOR "." LUA_VERSION_MINOR "." LUA_VERSION_RELEASE)

/*tex We never update this so they are constants: */

# define eTeX_version_string "2.2"  /*tex The current \ETEX\ version. */
# define eTeX_version         2     /*tex For |\eTeXversion|. */
# define eTeX_minor_version     2   /*tex For |\eTeXminorversion|. */
# define eTeX_revision        ".2"  /*tex For |\eTeXrevision|. */

typedef struct version_state_info {
    int         version;
    int         revision;
    const char *verbose;
} version_state_info;

extern version_state_info version_state;

/*tex

    This is somewhat fuzzy as we used longinteger in a few places where actually
    a normal integer was meant. (Kind of harmless btw.)

*/

typedef off_t longinteger;

/*tex

    Somehow this one needs to be defined for some platforms (only):

*/

# ifndef _WIN32
extern char **environ;
# endif

/*tex

    Originally \TEX\ was a monolithic program: one source got compiled. As a
    consequence the global variables were seen by all functional components.
    When the codebase was split, there were still all these global variables
    and common helper functions so this is why we include lots of h files
    in each component now. Compilation is fast so we don't worry too much
    about it. After all, header files are skipped when already loaded.

*/

# include "utils/arithmetic.h"
# include "utils/memory.h"

# include "tex/mainbody.h"

# include "libs/zlib/zlib-src/zlib.h"

# include "lua/luatex-api.h"

# include "utils/system.h"
# include "utils/managed-sa.h"
# include "utils/unistring.h"

# include "font/texfont.h"

# include "lang/texlang.h"

# include "tex/memoryword.h"
# include "tex/expand.h"
# include "tex/conditional.h"
# include "tex/textcodes.h"
# include "tex/mathcodes.h"
# include "tex/align.h"
# include "tex/directions.h"
# include "tex/errors.h"
# include "tex/inputstack.h"
# include "tex/stringpool.h"
# include "tex/textoken.h"
# include "tex/printing.h"
# include "tex/texfileio.h"
# include "tex/arithmetic.h"
# include "tex/nesting.h"
# include "tex/packaging.h"
# include "tex/postlinebreak.h"
# include "tex/scanning.h"
# include "tex/buildpage.h"
# include "tex/maincontrol.h"
# include "tex/dumpdata.h"
# include "tex/mainbody.h"
# include "tex/texnodes.h"
# include "tex/extensions.h"
# include "tex/linebreak.h"
# include "tex/texmath.h"
# include "tex/mlist.h"
# include "tex/commands.h"
# include "tex/primitive.h"
# include "tex/equivalents.h"
# include "tex/texdeffont.h"

# include "lua/lcallbacklib.h"
# include "lua/luanode.h"

# include "font/luafont.h"

# include "lua/llanglib.h"
# include "lua/ltokenlib.h"
# include "lua/lnodelib.h"
# include "lua/llualib.h"
# include "lua/ltexlib.h"
# include "lua/ltexiolib.h"
# include "lua/luastuff.h"
# include "lua/luainit.h"

#endif
