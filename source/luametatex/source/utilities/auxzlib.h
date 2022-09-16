/*
    See license.txt in the root of this project.
*/

/*tex

    This module deals with the memory allocation that plugs in the zipper. Although we could just
    use the defaule malloc, it's nicer to use the replacement, when it is enabled. A previous
    version had th eoption to choose between zlib and miniz but in 2021 we switched to the later
    so the former is now in the attic.

*/

# ifndef LMT_UTILITIES_ZLIB_H
# define LMT_UTILITIES_ZLIB_H

# include "../libraries/miniz/miniz.h"

/*tex These plug in the lua library as well as pplib's flate hander. */

extern void *lmt_zlib_alloc (void *opaque, size_t items, size_t size);
extern void  lmt_zlib_free  (void *opaque, void *p);

# endif
