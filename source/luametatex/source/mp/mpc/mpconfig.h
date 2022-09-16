# ifndef MPCONFIG_H
# define MPCONFIG_H

# include <errno.h>
# include <string.h>
# include <float.h>
# include <math.h>
# include <stdlib.h>
# include <stdarg.h>
# include <ctype.h>
# include <sys/stat.h>
# include <time.h>

# ifdef _WIN32

    # include <stdio.h>
    # include <fcntl.h>
    # include <io.h>

# else

    # include <unistd.h>

# endif

# endif
