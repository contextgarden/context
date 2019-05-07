/*
    See license.txt in the root of this project.
*/

# ifndef UTILS_ARITHMETIC_H
# define UTILS_ARITHMETIC_H

# undef abs
# undef floor
# undef fabs

# define decr(x)   --(x)
# define incr(x)   ++(x)
# define abs(x)    ((int)(x) >= 0 ? (int)(x) : (int)-(x))
# define chr(x)    (x)
# define ord(x)    (x)
# define odd(x)    ((x) & 1)
# define zround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : ((r>=0.0) ? (int)(r+0.5) : ((int)(r-0.5)))))
# define round(x)  zround ((double) (x))
# define trunc(x)  ((int) (x))
# define floor(x)  ((int)floor((double)(x)))
# define input     stdin
# define output    stdout
# define nil       NULL
# define halfp(i)  ((i) >> 1)
# define fabs(x)   ((x) >= 0.0 ? (x) : -(x))

# endif
