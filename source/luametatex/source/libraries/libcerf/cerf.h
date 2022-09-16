/* Library libcerf:
 *   Compute complex error functions, based on a new implementation of
 *   Faddeeva's w_of_z. Also provide Dawson and Voigt functions.
 *
 * File cerf.h:
 *   Declare exported functions.
 *
 * Copyright:
 *   (C) 2012 Massachusetts Institute of Technology
 *   (C) 2013 Forschungszentrum Jülich GmbH
 *
 * Licence:
 *   Permission is hereby granted, free of charge, to any person obtaining
 *   a copy of this software and associated documentation files (the
 *   "Software"), to deal in the Software without restriction, including
 *   without limitation the rights to use, copy, modify, merge, publish,
 *   distribute, sublicense, and/or sell copies of the Software, and to
 *   permit persons to whom the Software is furnished to do so, subject to
 *   the following conditions:
 *
 *   The above copyright notice and this permission notice shall be
 *   included in all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 *   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 *   LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 *   OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 *   WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Authors:
 *   Steven G. Johnson, Massachusetts Institute of Technology, 2012, core author
 *   Joachim Wuttke, Forschungszentrum Jülich, 2013, package maintainer
 *
 * Website:
 *   http://apps.jcns.fz-juelich.de/libcerf
 *
 * Revision history:
 *   ../CHANGELOG
 *
 * Man pages:
 *   w_of_z(3), dawson(3), voigt(3), cerf(3), erfcx(3), erfi(3)
 */

 /*

    This file is patched by Mojca Miklavec and Hans Hagen for usage in LuaMetaTeX where we use
    only C and also want to compile with the Microsoft compiler. So, when updating this library
    one has to check for changes. Not that we expect many as this is a rather stable library.

    In the other files there are a few macros used that deal with the multiplication and addition
    of complex and real numbers. Of course the original code is kept as-is.

 */

# ifndef __CERF_H
#   define __CERF_H

# include <complex.h>

# if (_MSC_VER)
    # define _cerf_cmplx _Dcomplex
# else
    typedef double _Complex _cerf_cmplx;
# endif

# define EXPORT

extern _cerf_cmplx w_of_z                (_cerf_cmplx z);                          /* compute w(z) = exp(-z^2) erfc(-iz), Faddeeva's scaled complex error function */
extern double      im_w_of_x             (double x);                               /* special case Im[w(x)] of real x */
extern double      re_w_of_z             (double x, double y);                     
extern double      im_w_of_z             (double x, double y);                     
                                                                                   
extern _cerf_cmplx cerf                  (_cerf_cmplx z);                          /* compute erf(z), the error function of complex arguments */
extern _cerf_cmplx cerfc                 (_cerf_cmplx z);                          /* compute erfc(z) = 1 - erf(z), the complementary error function */
                                                                                   
extern _cerf_cmplx cerfcx                (_cerf_cmplx z);                          /* compute erfcx(z) = exp(z^2) erfc(z), an underflow-compensated version of erfc */
extern double      erfcx                 (double x);                               /* special case for real x */
                                                                                   
extern _cerf_cmplx cerfi                 (_cerf_cmplx z);                          /* compute erfi(z) = -i erf(iz), the imaginary error function */
extern double      erfi                  (double x);                               /* special case for real x */
                                                                                   
extern _cerf_cmplx cdawson               (_cerf_cmplx z);                          /* compute dawson(z) = sqrt(pi)/2 * exp(-z^2) * erfi(z), Dawson's integral */
extern double      dawson                (double x);                               /* special case for real x */

extern double      voigt                 (double x, double sigma, double gamma);   /* compute voigt(x,...), the convolution of a Gaussian and a Lorentzian */
extern double      voigt_hwhm            (double sigma, double gamma, int *error); /* compute the full width at half maximum of the Voigt function */

extern double      cerf_experimental_imw (double x, double y);
extern double      cerf_experimental_rew (double x, double y);

#endif
