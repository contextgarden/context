/*
    See license.txt in the root of this project.
*/

/*
    Some operating systems come with |allocarray| so we use more verbose names. We cannot define
    them because on some bsd/apple platforms |CLANG| cannot resolve them.

*/

# ifndef LMT_UTILITIES_MEMORY_H
# define LMT_UTILITIES_MEMORY_H

/*tex
    This is an experiment. The impact of using an alternative allocator on native Windows makes a
    native version some 5% faster than a cross compiled one. Otherwise the cross compiled version
    outperforms the native one a bit. In \TEX\ and \METAPOST\ we already do something like this
    but there we don't reclaim memory.

*/

# include <stdlib.h>
# include <string.h>

# if defined(LUAMETATEX_USE_MIMALLOC)
    # include "libraries/mimalloc/include/mimalloc.h"
    # define lmt_memory_malloc  mi_malloc
    # define lmt_memory_calloc  mi_calloc
    # define lmt_memory_realloc mi_realloc
    # define lmt_memory_free    mi_free
    # define lmt_memory_strdup  mi_strdup

 // # include "libraries/mimalloc/include/mimalloc-override.h"

# else
    # define lmt_memory_malloc  malloc
    # define lmt_memory_calloc  calloc
    # define lmt_memory_realloc realloc
    # define lmt_memory_free    free
    # define lmt_memory_strdup  strdup
# endif

# define lmt_generic_malloc  malloc
# define lmt_generic_calloc  calloc
# define lmt_generic_realloc realloc
# define lmt_generic_free    free
# define lmt_generic_strdup  strdup

extern void *aux_allocate_array       (int recordsize, int size, int reserved);
extern void *aux_reallocate_array     (void *p, int recordsize, int size, int reserved);
extern void *aux_allocate_clear_array (int recordsize, int size, int reserved);
extern void  aux_deallocate_array     (void *p);

# endif
