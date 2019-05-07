# ifndef MPLIB_CONFIG_H
# define MPLIB_CONFIG_H

# ifdef _WIN32
# ifndef WIN32
# define WIN32 _WIN32
# endif
# endif

# include <errno.h>
# include <string.h>
# include <math.h>
# include <stdlib.h>
# include <ctype.h>
# include <sys/stat.h>

/* todo: see luainit.c stat */

# ifdef _WIN32
# include <stdio.h>
# include <fcntl.h>
# include <io.h>
# else
# include <unistd.h>
# endif

# undef xstrdup
# define xstrdup  strdup

# define DBL_MAX 1e+37
// # define R_OK 0x4

# undef boolean

# undef true
# undef false

typedef int boolean ;

# define true 1
# define false 0

# ifdef HAVE_ASSERT_H
# include <assert.h>
# else
# define assert(expr)
# endif

typedef const char * const_string ;

typedef off_t longinteger;

# endif
