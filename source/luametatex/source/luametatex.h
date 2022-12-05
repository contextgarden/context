/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LUAMETATEX_H
# define LMT_LUAMETATEX_H

/*tex

    The \LUATEX\ project started in 2005 with an experiments by Hartmut and me: adding the \LUA\
    Scripting language (that I knew from the \SCITE\ editor) to \PDFTEX. When we came to the
    conclusion that a more tight integration made sense Taco did the impressive conversion from
    \PASCAL\ |WEB\ to \CWEB. This happened in the perspective of the Oriental \TEX\ project, that
    has as objective high quality Arabic typesetting. The way to achieve that was opening up the
    font machinery and access to the paragraph building. It was an intense development period,
    with Taco doing the coding, Hans exploring possibilities and extending \CONTEXT, and Idris
    making fonts and testing. Taco and I discussed, compiled, accepted and rejected ideas. These
    were interesting times! Over the years that we had used \TEX\ we could finally explore what we
    had been talking about for years (long trips to user group meetings are good for that). We
    ame to the first version(s) of \LUATEX\ with \CONTEXT\ \MKIV\ providing a testbed and as we
    progressed we ended up with something we liked a lot.

    After half a decade, where in the meantime Taco also had turned MetaPost into a library, we
    had a version that had proved itself well. The following years, with Taco having less time
    available, I started loking at the code. Some more got added to the Lua interfaces. Math got
    split code paths and some new primitives were introduced. Luigi started taking care of managing
    the code base so that I could cross compile for \MSWINDOWS. He also deals with the libraries
    that were used and integration in \TEXLIVE\ and maintains the (by now stable) \METAPOST\ code
    base.

    After a while it became clear that users other than \CONTEXT\ wanted the program to stay as it
    was and not introduce features or improve interfaces in ways that demanded a change in used
    \LUA\ code. So, after a decade of development the official stable release took place. We already
    had a split between stable (normally the \TEXLIVE\ release) and experimental (that we used for
    development). However, in practice experimental versions were seen as real releases and we got
    complaints that something could be broken (which actually is natural for an experimental
    version). So, this split model didn't work out well in practice: you cannot explore and
    experiment when you cannot play with yet unfinished code.

    So at some point I decided that the best approach to a follow up, one not interfering with
    usage of a stable \LUATEX, would be a more drastic split: the idea of \LUAMETATEX\ took shape.
    This code base is the result of that. For whatever bad was introduced in \LUAMETATEX, and maybe
    already before that in \LUATEX), you can blame me (Hans) and not Taco: Luigi consistently added
    (hh) to the \LUATEX\ svn entries when that was feasible, so one can check where I messed up.
    In the end all this work can be considered a co-product and the \CONTEXT\ (dev) community was
    instrumental in this as well.

    There are some fundamental changes: there is no backend but maybe I'll introduce a framework
    for that at some point because the impact on performance has been quite noticeable (although
    it has been compensated in the meantime). There is no support for \LUAJIT, because it doesn't
    keep up with \LUA. Also, there is no support for \FFI, because that project is orphaned, but
    there are other ways. Some more is delegated to \LUA, but also some more has been added to \TEX.

    Over the 15 years that it took to go from the first version of \LUATEX\ in 2005 to the first
    release of \LUAMETATEX\ in 2020 (although intermediate versions have always been good enough
    to be used in production with \CONTEXT) I've written numerous articles in user group journals
    as well as several presentations each year on progress and features. There are also wrapups
    available in the \CONTEXT\ distribution that shed some light on how the developments
    progress(ed). In the end it's all a work of many. There are no commercial interrests and
    everything is done out of love for TeX and in free time, so take that into account when you
    bark about code or documentation.

    The \LUAMETATEX\ code base is maintained by Hans Hagen and Wolfgang Schuster (code, programming,
    etc) with help from Mojca Miklavec (distribution, compile farm, etc) and Alan Braslau (testing,
    feedback, etc). Of course with get help from all those \CONTEXT\ users who are always very
    willing to test.

    We start with the version numbers. While \LUATEX\ operates in the 100 range, the \LUAMETATEX\
    engine takes the 200 range. Revisions range from 00 upto 99 and the dates \unknown\ depend on
    the mood. The |2.05.00| version with the development id |20200229| was more or less the first
    official version, in the sense that most of the things on my initial todo list were done. It's
    a kind of virtual date as it happens to be a leapyear. As with LuaTeX the .10 version will be
    the first 'stable' one, released somewhere around the ConTeXt 2021 meeting.

    2.08.18 : around TeXLive 2021 code freeze (so a bit of a reference version)
    2.09.35 : near the end of 2021 (so close to the 2.10 release date)
    2.09.55 : in July 2022 (the official release of the new math engine)
    2.10.00 : a few days before the ctx 2022 meeting (starting September 19)
    2.10.01 : mid October 2022 

    At some point the \CONTEXT\ group will be responsible for guaranteeing that the official version
    is what comes with \CONTEXT\ and that long term support and stabilty is guaranteed and that no 
    feature creep or messing up happens. We'll see. 

*/

# include "tex/textypes.h"

# define luametatex_version          210
# define luametatex_revision         04
# define luametatex_version_string   "2.10.04"
# define luametatex_development_id   20221202

# define luametatex_name_camelcase   "LuaMetaTeX"
# define luametatex_name_lowercase   "luametatex"
# define luametatex_copyright_holder "Taco Hoekwater, Hans Hagen & Wolfgang Schuster"
# define luametatex_bug_address      "dev-context@ntg.nl"
# define luametatex_support_address  "context@ntg.nl"

/*tex

    One difference with \LUATEX\ is that we keep global variables that kind of belong together in
    structures. This also has the advantage that we have more specific access (via a namespace) and
    don't use that many macros (that can conflict later on).

*/

typedef struct version_state_info {
    int         version;
    int         revision;
    const char *verbose;
    const char *banner;
    const char *compiler;
 // const char *libc;
    int         developmentid;
    int         formatid;
    const char *copyright;
} version_state_info;

extern version_state_info lmt_version_state;

/*tex

    This is actually the main headere file. Of course we could split it up and be more explicit in
    other files but this is simple and just works. There is of course some overhead in loading
    headers that are not used, but because compilation is simple and fast I don't care.

*/

# include <stdarg.h>
# include <string.h>
# include <math.h>
# include <stdlib.h>
# include <errno.h>
# include <float.h>
# include <locale.h>
# include <ctype.h>
# include <stdint.h>
# include <stdio.h>
# include <time.h>
# include <signal.h>
# include <sys/stat.h>

# ifdef _WIN32
    # include <windows.h>
    # include <winerror.h>
    # include <fcntl.h>
    # include <io.h>
# else
    # include <unistd.h>
    # include <sys/time.h>
# endif

/*tex

    We use stock \LUA\ where we only adapt the bytecode format flag so that we can use intermediate
    \LUA\ versions without crashes due to different bytecode. Here are some constants that have to
    be set:

    \starttyping
    # define LUAI_HASHLIMIT    6
    # define LUA_USE_JUMPTABLE 0
    # define LUA_BUILD_AS_DLL  0
    # define LUA_CORE          0
    \stoptyping

    Earlier versions of \LUA\ an definitely \LUAJIT\ needed the |LUAI_HASHLIMIT| setting to be
    adapted in order not to loose performance. This flag is no longer in \LUA\ version 5.4+.

*/

# include "lua.h"
# include "lauxlib.h"

# define LUA_VERSION_STRING ("Lua " LUA_VERSION_MAJOR "." LUA_VERSION_MINOR "." LUA_VERSION_RELEASE)

/*tex

    The code in \LUAMETATEX\ is a follow up on \LUATEX\ which is itself a follow up on \PDFTEX\
    (and parts of \ALEPH). The original \PASCAL\ code has been converted \CCODE. Substantial amounts
    of code were added over a decade. Stepwise artifacts have been removed (for instance originating
    in the transations from \PASCAL, or from integration in the infrastructure), parts of code has
    been rewritten. As much as possible we keep the old naming intact (so that most of the \TEX\
    documentation applies. However, as we now assume \CCODE, some things have changed. Among the
    changes are handling datatypes and certain checks. For instance, when |null| is used this is
    now always assumed to be |0|, so a zero test is also valid. Old side effects of zero nodes for
    zero gluespecs are gone because these have been reimplemented. Of course we keep |NULL| as
    abstraction for unset pointers. This way it's clear when we have a \CCODE\ pointer or a \TEX\
    managed one (where |null| or |0| means no node or token).

    As with all \TEX\ engines, \LUATEX\ started out with the \PASCAL\ version of \TEX\ and as
    mentioned we started with \PDFTEX. The first thing that was done (by Taco) was to create a
    permanent \CCODE\ base instead of \PASCAL. In the process, some macros and library interfacing
    wrappers were moved to the \LUATEX\ code base. Sometimes \PASCAL\ and \CCODE\ don't map well
    end intermediate functions were used for that. Over time some artifacts that resulted from
    automatic conversions from one to the other has been removed.

    In the next stage of \LUATEX\ development, we went a but further and tried to get rid of more
    dependencies. Among the rationales for this is that we depend on \LUA, and whatever works for
    the \LUA\ codebase (which is quite portable) should also work for \LUATEX. But there are always
    some overloads because (especially in \LUATEX\ where one can use \KPSE) the integration in a
    \TEX\ ecosystem expects some behaviour with respect to files and running subprocesses and such.
    In \LUAMETATEX\ there is less of that because \CONTEXT\ does more of that itself.

    So, one of the biggest complications was the dependency on the \WEBC\ helpers and file system
    interface. However, because that was already kind of isolated, it could be removed. If needed
    we can always bring back \KPSE\ as an external library. In the process there can be some side
    effects but in the end it gives a cleaner codebase and less depedencies. We suddenly don't need
    all kind of tweaks to get the program compiled.

    The \TEX\ memory model is based on packing data in memory words, but that concept is somewhat
    fluid as in the past we had 16 byte processors too. However, we now mostly think in 32 bit and
    internally \LUATEX\ will pack most of its node data in a multiples of 64 bits (called words). On
    the one hand there is more memory involved but on the other hand it suits the architectures
    well. In \LUAMETATEX\ we target 64 bit machines, but still provide binaries for 32 bit
    architectures. The endianness related code has been dropped, simply because already for decades,
    format files are not shared between platforms either.

    Because \TEX\ efficiently implements its own memory management of nodes, the address of a node
    is actually a number. Numbers like are sometimes indicates as |pointer|, but can also be called
    |halfword|. Dimensions also fit into half a word and are called |scaled| but again we see them
    being called |halfword|. What term is used depends a bit on the location and also on the
    original code. For now we keep this mix but maybe some day we will normalize this. I did look
    into more dynamic loading (only using the main memory numeric address pointers because that is
    fast and efficient) but it makes the code more complex and probably hit performance badly. But
    I keep an eye on it.

    When we have halfwords representing pointers (into the main memory array) we indicate an unset
    pointer as |null| (lowercase). But, because the usage of |null| and |0| was kind of mixed and
    inconstent the |null| is only used to indicate zeroing a halfword encoded pointer. It will
    always remain |0|.

    We could reshuffle a lot more and normalize defines and enums but for now we stick to the way
    it's done in order to divert not too much from the ancestors. However, in due time it can
    evolve. Some constants used in \TEX\ the program now have a prefix |namespace_| or suffix
    |_code| or |_cmd| in order not to clash with other usage. Some of these are in files like
    |texcommands.h| and |texequivalents.h| but others end up in other |.h| files. This might change
    but in the end it's not that important. Consider the spread a side effect of the still present
    ideas of literate programming.

    Some of the modules put data into the structures that could have been kept private but for now
    I decided to be a bit consistent. However, of course there are still quite some private
    variables left.

*/

/*tex This is not used (yet) as I don't expect much from it, but \LUA\ has some of it. */

# if defined(__GNUC__)
#   define lmt_likely(x)   (__builtin_expect(((x) != 0), 1))
#   define lmt_unlikely(x) (__builtin_expect(((x) != 0), 0))
# else
#   define lmt_likely(x)   (x)
#   define lmt_unlikely(x) (x)
# endif

# include "utilities/auxarithmetic.h"
# include "utilities/auxmemory.h"
# include "utilities/auxzlib.h"

# include "tex/texmainbody.h"

# include "lua/lmtinterface.h"
# include "lua/lmtlibrary.h"
# include "lua/lmttexiolib.h"

# include "utilities/auxsystem.h"
# include "utilities/auxsparsearray.h"
# include "utilities/auxunistring.h"
# include "utilities/auxfile.h"

# include "libraries/hnj/hnjhyphen.h"

# include "tex/texexpand.h"
# include "tex/texmarks.h"
# include "tex/texconditional.h"
# include "tex/textextcodes.h"
# include "tex/texmathcodes.h"
# include "tex/texalign.h"
# include "tex/texrules.h"
/*        "tex/texdirections.h" */
# include "tex/texerrors.h"
# include "tex/texinputstack.h"
# include "tex/texstringpool.h"
# include "tex/textoken.h"
# include "tex/texprinting.h"
# include "tex/texfileio.h"
# include "tex/texarithmetic.h"
# include "tex/texnesting.h"
# include "tex/texadjust.h"
# include "tex/texinserts.h"
# include "tex/texlocalboxes.h"
# include "tex/texpackaging.h"
# include "tex/texscanning.h"
# include "tex/texbuildpage.h"
# include "tex/texmaincontrol.h"
# include "tex/texdumpdata.h"
# include "tex/texmainbody.h"
# include "tex/texnodes.h"
# include "tex/texdirections.h"
# include "tex/texlinebreak.h"
# include "tex/texmath.h"
# include "tex/texmlist.h"
# include "tex/texcommands.h"
# include "tex/texprimitive.h"
# include "tex/texequivalents.h"
# include "tex/texfont.h"
# include "tex/texlanguage.h"

# include "lua/lmtcallbacklib.h"
# include "lua/lmttokenlib.h"
# include "lua/lmtnodelib.h"
# include "lua/lmtlanguagelib.h"
# include "lua/lmtfontlib.h"
# include "lua/lmtlualib.h"
# include "lua/lmtluaclib.h"
# include "lua/lmttexlib.h"
# include "lua/lmtenginelib.h"

/*tex

    We use proper warnings, error messages, and confusion reporting instead of:

    \starttyping
    # ifdef HAVE_ASSERT_H
    #    include <assert.h>
    # else
    #    define assert(expr)
    # endif
    \stoptyping

    In fact, we don't use assert at all in \LUAMETATEX\ because if we need it we should do a decent
    test and report an issue. In the \TEXLIVE\ eco system there can be assignments and function
    calls in asserts which can disappear in case of e.g. compiling with msvc, so the above define
    is even wrong!

*/

// # ifndef _WIN32
//
//     /* We don't want these use |foo_s| instead of |foo| messages. This will move. */
//
//     # define _CRT_SECURE_NO_WARNINGS
//
// # endif

# endif
