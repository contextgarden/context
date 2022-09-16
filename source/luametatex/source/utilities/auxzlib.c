/*
    See license.txt in the root of this project.
*/

# include "auxzlib.h"
# include "auxmemory.h"

void *lmt_zlib_alloc(void *opaque, size_t items, size_t size)
{
    (void) opaque;
    return lmt_memory_malloc((size_t) items * size);
}

void  lmt_zlib_free(void *opaque, void *p)
{
    (void) opaque;
    lmt_memory_free(p);
}
