/* Library libcerf:
 *   Compute complex error functions, based on a new implementation of
 *   Faddeeva's w_of_z. Also provide Dawson and Voigt functions.
 *
 * File width.c:
 *   Computate voigt_hwhm, using Newton's iteration.
 *
 * Copyright:
 *   (C) 2018 Forschungszentrum Jülich GmbH
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
 *   Joachim Wuttke, Forschungszentrum Jülich, 2018
 *
 * Website:
 *   http://apps.jcns.fz-juelich.de/libcerf
 *
 * Revision history:
 *   ../CHANGELOG
 *
 * Man pages:
 *   voigt_fwhm(3)
 */

/*

    This file is patched by Hans Hagen for usage in LuaMetaTeX where we don't want to exit on an 
    error so we intercept it. 

*/

#include "cerf.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

double dvoigt(double x, double sigma, double gamma, double v0)
{
    return voigt(x, sigma, gamma)/v0 - .5;
}

double voigt_hwhm(double sigma, double gamma, int *error)
{
    *error = 0;
    if (sigma == 0 && gamma == 0) {
        return 0;
    } else if (isnan(sigma) || isnan(gamma)) {        
        *error = 1; 
        return 0; // return NAN;
    } else {
        // start from an excellent approximation [Olivero & Longbothum, J Quant Spec Rad Transf 1977]:
        const double eps = 1e-14;
        const double hwhm0 = .5*(1.06868*gamma+sqrt(0.86743*gamma*gamma+4*2*log(2)*sigma*sigma));
        const double del = eps*hwhm0;
        double ret = hwhm0;
        const double v0 = voigt(0, sigma, gamma);
        for (int i=0; i<300; ++i) {
            double val = dvoigt(ret, sigma, gamma, v0);
            if (fabs(val) < 1e-15) {
                return ret;
            } else {
                double step = -del/(dvoigt(ret+del, sigma, gamma, v0)/val-1);
                double nxt = ret + step;
                if (nxt < ret/3) {
                    *error = 2; // fprintf(stderr, "voigt_fwhm terminated because of huge deviation from 1st approx\n");
                    nxt = ret/3;
                } else if (nxt > 2*ret) {
                    *error = 2; // fprintf(stderr, "voigt_fwhm terminated because of huge deviation from 1st approx\n");
                    nxt = 2*ret;
                }
                if (fabs(ret-nxt) < del) {
                    return nxt;
                } else { 
                    ret = nxt;
                }
            }
        }
        *error = 3; // fprintf(stderr, "voigt_fwhm failed: Newton's iteration did not converge with sigma = %f and gamma = %f\n", sigma, gamma);  exit(-1);
        return 0;
    }
}
