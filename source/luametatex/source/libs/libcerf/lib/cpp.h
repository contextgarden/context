/* Library libcerf:
 *   compute complex error functions,
 *   along with Dawson, Faddeeva and Voigt functions
 *
 * File defs.h:
 *   Define CMPLX, NaN, for internal use, for when sources are compiled as C++ code
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

#include <cfloat>
#include <cmath>
#include <limits>

// use std::numeric_limits, since 1./0. and 0./0. fail with some compilers (MS)
#define Inf std::numeric_limits<double>::infinity()
#define NaN std::numeric_limits<double>::quiet_NaN()

// Use C-like complex syntax, since the C syntax is more restrictive
#define cexp(z) std::exp(z)
#define creal(z) std::real(z)
#define cimag(z) std::imag(z)
#define cpolar(r,t) std::polar(r,t)

#define C(a,b) _cerf_cmplx(a,b)

#define FADDEEVA(name) Faddeeva::name
#define FADDEEVA_RE(name) Faddeeva::name

// g++ gets confused between the C and C++ isnan/isinf functions
#define isnan std::isnan
#define isinf std::isinf

// If we are using the gnulib <cmath> (e.g. in the GNU Octave sources),
// gnulib generates a link warning if we use ::floor instead of gnulib::floor.
// This warning is completely innocuous because the only difference between
// gnulib::floor and the system ::floor (and only on ancient OSF systems)
// has to do with floor(-0), which doesn't occur in the usage below, but
// the Octave developers prefer that we silence the warning.
#ifdef GNULIB_NAMESPACE
#  define floor GNULIB_NAMESPACE::floor
#endif
