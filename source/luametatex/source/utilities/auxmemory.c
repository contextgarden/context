/*
    See license.txt in the root of this project.
*/

# include "auxmemory.h"

void *aux_allocate_array(int recordsize, int size, int reserved)
{
    return lmt_memory_malloc(recordsize * ((size_t) size + reserved + 1));
}

void *aux_reallocate_array(void *p, int recordsize, int size, int reserved)
{
    return lmt_memory_realloc(p, recordsize * ((size_t) size + reserved + 1));
}

void *aux_allocate_clear_array(int recordsize, int size, int reserved)
{
    return lmt_memory_calloc((size_t) size + reserved + 1, recordsize);
}

void aux_deallocate_array(void *p)
{
    lmt_memory_free(p);
}
