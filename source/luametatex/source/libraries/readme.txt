Nota bene,

The currently embedded libcerf library might become an optional one as soon as we decide to provide
it as such. It doesn't put a dent in filesize but as it's used rarely (and mostly as complement to
the complex math support) that makes sense. The library was added because some users wanted it as
companion the other math libraries and because TeX is often about math it sort of feels okay. But
it looks like there will never be support for the MSVC compiler. Mojca and I (Hans) adapted the
sources included here to compile out of the box, but that didn't make it back into the original.

The pplib library has a few patches with respect to memory allocation and zip compression so that
we can hook in the minizip and mimalloc alternatives.

The avl and hnj libraries are adapted to Lua(Meta)TeX and might get some more adaptations depending
on our needs. The decnumber library that is also used in mplib is unchanged.

In mimalloc we need to patch init.c: #if defined(_M_X64) || defined(_M_ARM64) to get rid of a link
error as well as in options.c some snprint issue with the mingw64 cross compiler: 

/* HH */ snprintf(tprefix, sizeof(tprefix), "%sthread 0x%x: ", prefix, (unsigned) _mi_thread_id()); /* HH: %z is unknown */

In decNumber.c this got added: 

# include "../../utilities/auxmemory.h"
# define malloc lmt_memory_malloc
# define free   lmt_memory_free

Hans