/* Library libcerf:
 *   compute complex error functions,
 *   along with Dawson, Faddeeva and Voigt functions
 *
 * File defs.h:
 *   Language-dependent includes.
 *
 * Copyright:
 *   (C) 2012 Massachusetts Institute of Technology
 *   (C) 2013 Forschungszentrum Jülich GmbH
 *
 * Licence:
 *   MIT Licence.
 *   See ../COPYING
 *
 * Authors:
 *   Steven G. Johnson, Massachusetts Institute of Technology, 2012, core author
 *   Joachim Wuttke, Forschungszentrum Jülich, 2013, package maintainer
 *
 * Website:
 *   http://apps.jcns.fz-juelich.de/libcerf
 */

/*

    This file is patched by Mojca Miklavec and Hans Hagen for usage in LuaMetaTeX where we use
    only C and also want to compile with the Microsoft compiler. So, when updating this library
    one has to check for changes. Not that we expect many as this is a rather stable library.

    In the other files there are a few macros used that deal with the multiplication and addition
    of complex and real nmbers. Of course the original code is kept as-is.

*/

# ifndef __CERF_C_H
#   define __CERF_C_H

# define _GNU_SOURCE // enable GNU libc NAN extension if possible

/*
    Constructing complex numbers like 0+i*NaN is problematic in C99
    without the C11 CMPLX macro, because 0.+I*NAN may give NaN+i*NAN if
    I is a complex (rather than imaginary) constant.  For some reason,
    however, it works fine in (pre-4.7) gcc if I define Inf and NaN as
    1/0 and 0/0 (and only if I compile with optimization -O1 or more),
    but not if I use the INFINITY or NAN macros.
*/

/*
    __builtin_complex was introduced in gcc 4.7, but the C11 CMPLX
    macro may not be defined unless we are using a recent (2012) version
    of glibc and compile with -std=c11... note that icc lies about being
    gcc and probably doesn't have this builtin(?), so exclude icc
    explicitly.
*/

# if (_MSC_VER)
    # define C(a,b) _Cbuild((double)(a), (double)(b))
    # define Inf    INFINITY
    # define NaN    NAN
# else
    # define C(a,b) ((a) + I*(b))
    # define Inf    (1./0.)
    # define NaN    (0./0.)
# endif

# include <complex.h>

# if (_MSC_VER)

    # define _cerf_cmplx _Dcomplex

    static _Dcomplex complex_neg   (_Dcomplex x)              { return _Cmulcr(x, -1.0); }
    static _Dcomplex complex_add_cc(_Dcomplex x, _Dcomplex y) { return _Cbuild(creal(x) + creal(y), cimag(x) + cimag(y)); }
    static _Dcomplex complex_add_rc(double    x, _Dcomplex y) { return _Cbuild(x + creal(y), x + cimag(y)); }
    static _Dcomplex complex_sub_cc(_Dcomplex x, _Dcomplex y) { return _Cbuild(creal(x) - creal(y), cimag(x) - cimag(y)); }
    static _Dcomplex complex_sub_rc(double    x, _Dcomplex y) { return _Cbuild(x - creal(y), x - cimag(y)); }
    static _Dcomplex complex_mul_cc(_Dcomplex x, _Dcomplex y) { return _Cmulcc((y), (x)); }
    static _Dcomplex complex_mul_rc(double    x, _Dcomplex y) { return _Cmulcr((y), (x)); }
    static _Dcomplex complex_mul_cr(_Dcomplex x, double    y) { return _Cmulcr((x), (y)); }

# else

    typedef double _Complex _cerf_cmplx;

    # define complex_neg(x)       (-x)
    # define complex_add_cc(x,y)  (x+y)
    # define complex_add_rc(x,y)  (x+y)
    # define complex_sub_cc(x,y)  (x-y)
    # define complex_sub_rc(x,y)  (x-y)
    # define complex_mul_cc(x,y)  (x*y)
    # define complex_mul_rc(x,y)  (x*y)
    # define complex_mul_cr(x,y)  (x*y)

# endif

# endif
