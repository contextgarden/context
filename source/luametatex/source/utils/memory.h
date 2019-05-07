/*
    See license.txt in the root of this project.
*/

# ifndef UTILS_MEMORY_H
# define UTILS_MEMORY_H

/*tex

    Due to web2c inheritances we were not (yet) consistent in using x and non-x
    variants so the few left x variants were inlined. We keep the arrays. This
    also gives less conflicts with the mp library code.

*/

# define mallocarray(type,size)       ((type*)malloc((size+1)*sizeof(type)))
# define reallocarray(ptr,type,size)  ((type*)realloc(ptr,(size+1)*sizeof(type)))
# define callocarray(type,nmemb,size) ((type*)calloc(nmemb+1,(size+1)*sizeof(type)))

# endif
