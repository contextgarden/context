/* Library libcerf:
 *   compute complex error functions,
 *   along with Dawson, Faddeeva and Voigt functions
 *
 * File c.h:
 *   Define CMPLX, NaN, for internal use, for when sources are compiled as C code.
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

#define _GNU_SOURCE // enable GNU libc NAN extension if possible

/* Constructing complex numbers like 0+i*NaN is problematic in C99
   without the C11 CMPLX macro, because 0.+I*NAN may give NaN+i*NAN if
   I is a complex (rather than imaginary) constant.  For some reason,
   however, it works fine in (pre-4.7) gcc if I define Inf and NaN as
   1/0 and 0/0 (and only if I compile with optimization -O1 or more),
   but not if I use the INFINITY or NAN macros. */

/* __builtin_complex was introduced in gcc 4.7, but the C11 CMPLX macro
   may not be defined unless we are using a recent (2012) version of
   glibc and compile with -std=c11... note that icc lies about being
   gcc and probably doesn't have this builtin(?), so exclude icc explicitly */

#if !defined(CMPLX) && \
    ( __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 7)) && \
    !(defined(__ICC) || defined(__INTEL_COMPILER))
#  define CMPLX(a,b) __builtin_complex((double) (a), (double) (b))
#endif

#ifdef CMPLX // C11
#  define C(a,b) CMPLX(a,b)
#  define Inf INFINITY // C99 infinity
#  ifdef NAN // GNU libc extension
#    define NaN NAN
#  else
#    define NaN (0./0.) // NaN
#  endif
#else
#  define C(a,b) ((a) + I*(b))
#  define Inf (1./0.)
#  define NaN (0./0.)
#endif
