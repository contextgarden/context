/* Library libcerf:
 *   Compute complex error functions, based on a new implementation of
 *   Faddeeva's w_of_z. Also provide Dawson and Voigt functions.
 *
 * File err_fcts.c:
 *   Computate Dawson, Voigt, and several error functions,
 *   based on erfcx, im_w_of_x, w_of_z as implemented in separate files.
 *
 *   Given w(z), the error functions are mostly straightforward
 *   to compute, except for certain regions where we have to
 *   switch to Taylor expansions to avoid cancellation errors
 *   [e.g. near the origin for erf(z)].
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
 *   cerf(3), dawson(3), voigt(3)
 */

#include "cerf.h"
#include <math.h>
#include "defs.h" // defines _cerf_cmplx, NaN, C, cexp, ...

const double spi2 = 0.8862269254527580136490837416705725913990; // sqrt(pi)/2
const double s2pi = 2.5066282746310005024157652848110; // sqrt(2*pi)
const double pi   = 3.141592653589793238462643383279503;

/******************************************************************************/
/*  Simple wrappers: cerfcx, cerfi, erfi, dawson                              */
/******************************************************************************/

_cerf_cmplx cerfcx(_cerf_cmplx z)
{
    // Compute erfcx(z) = exp(z^2) erfc(z),
    // the complex underflow-compensated complementary error function,
    // trivially related to Faddeeva's w_of_z.

    return w_of_z(C(-cimag(z), creal(z)));
}

_cerf_cmplx cerfi(_cerf_cmplx z)
{
    // Compute erfi(z) = -i erf(iz),
    // the rotated complex error function.

    _cerf_cmplx e = cerf(C(-cimag(z),creal(z)));
    return C(cimag(e), -creal(e));
}

double erfi(double x)
{
    // Compute erfi(x) = -i erf(ix),
    // the imaginary error function.

    return x*x > 720 ? (x > 0 ? Inf : -Inf) : exp(x*x) * im_w_of_x(x);
}

double dawson(double x)
{

    // Compute dawson(x) = sqrt(pi)/2 * exp(-x^2) * erfi(x),
    // Dawson's integral for a real argument.

    return spi2 * im_w_of_x(x);
}

double re_w_of_z( double x, double y )
{
    return creal( w_of_z( C(x,y) ) );
}

double im_w_of_z( double x, double y )
{
    return cimag( w_of_z( C(x,y) ) );
}

/******************************************************************************/
/*  voigt                                                                     */
/******************************************************************************/

double voigt( double x, double sigma, double gamma )
{
    // Joachim Wuttke, January 2013.

    // Compute Voigt's convolution of a Gaussian
    //    G(x,sigma) = 1/sqrt(2*pi)/|sigma| * exp(-x^2/2/sigma^2)
    // and a Lorentzian
    //    L(x,gamma) = |gamma| / pi / ( x^2 + gamma^2 ),
    // namely
    //    voigt(x,sigma,gamma) =
    //          \int_{-infty}^{infty} dx' G(x',sigma) L(x-x',gamma)
    // using the relation
    //    voigt(x,sigma,gamma) = Re{ w(z) } / sqrt(2*pi) / |sigma|
    // with
    //    z = (x+i*|gamma|) / sqrt(2) / |sigma|.

    // Reference: Abramowitz&Stegun (1964), formula (7.4.13).

    double gam = gamma < 0 ? -gamma : gamma;
    double sig = sigma < 0 ? -sigma : sigma;

    if ( gam==0 ) {
        if ( sig==0 ) {
            // It's kind of a delta function
            return x ? 0 : Inf;
        } else {
            // It's a pure Gaussian
            return exp( -x*x/2/(sig*sig) ) / s2pi / sig;
        }
    } else {
        if ( sig==0 ) {
            // It's a pure Lorentzian
            return gam / pi / (x*x + gam*gam);
        } else {
            // Regular case, both parameters are nonzero
            _cerf_cmplx z = complex_mul_cr(C(x, gam), 1. / sqrt(2) / sig);
            return creal( w_of_z(z) ) / s2pi / sig;
            // TODO: correct and activate the following:
//            double w = sqrt(gam*gam+sig*sig); // to work in reduced units
//            _cerf_cmplx z = C(x/w,gam/w) / sqrt(2) / (sig/w);
//            return creal( w_of_z(z) ) / s2pi / (sig/w);
        }
    }
}

/******************************************************************************/
/*  cerf                                                                      */
/******************************************************************************/

_cerf_cmplx cerf(_cerf_cmplx z)
{

    // Steven G. Johnson, October 2012.

    // Compute erf(z), the complex error function,
    // using w_of_z except for certain regions.

    double x = creal(z), y = cimag(z);

    if (y == 0)
        return C(erf(x), y); // preserve sign of 0
    if (x == 0) // handle separately for speed & handling of y = Inf or NaN
        return C(x, // preserve sign of 0
                 /* handle y -> Inf limit manually, since
                    exp(y^2) -> Inf but Im[w(y)] -> 0, so
                    IEEE will give us a NaN when it should be Inf */
                 y*y > 720 ? (y > 0 ? Inf : -Inf)
                 : exp(y*y) * im_w_of_x(y));

    double mRe_z2 = (y - x) * (x + y); // Re(-z^2), being careful of overflow
    double mIm_z2 = -2*x*y; // Im(-z^2)
    if (mRe_z2 < -750) // underflow
        return (x >= 0 ? C(1.0, 0.0) : C(-1.0, 0.0));;

    /* Handle positive and negative x via different formulas,
       using the mirror symmetries of w, to avoid overflow/underflow
       problems from multiplying exponentially large and small quantities. */
    if (x >= 0) {
        if (x < 8e-2) {
            if (fabs(y) < 1e-2)
                goto taylor;
            else if (fabs(mIm_z2) < 5e-3 && x < 5e-3)
                goto taylor_erfi;
        }
        /* don't use complex exp function, since that will produce spurious NaN
           values when multiplying w in an overflow situation. */
        return complex_sub_rc(1.0, complex_mul_rc(exp(mRe_z2), complex_mul_cc(C(cos(mIm_z2), sin(mIm_z2)), w_of_z(C(-y, x)))));
    }
    else { // x < 0
        if (x > -8e-2) { // duplicate from above to avoid fabs(x) call
            if (fabs(y) < 1e-2)
                goto taylor;
            else if (fabs(mIm_z2) < 5e-3 && x > -5e-3)
                goto taylor_erfi;
        }
        else if (isnan(x))
            return C(NaN, y == 0 ? 0 : NaN);
        /* don't use complex exp function, since that will produce spurious NaN
           values when multiplying w in an overflow situation. */
        return complex_add_rc(-1.0, complex_mul_rc(exp(mRe_z2), complex_mul_cc(C(cos(mIm_z2), sin(mIm_z2)), w_of_z(C(y, -x)))));

    }

    // Use Taylor series for small |z|, to avoid cancellation inaccuracy
    //   erf(z) = 2/sqrt(pi) * z * (1 - z^2/3 + z^4/10 - z^6/42 + z^8/216 + ...)
taylor:
    {
        _cerf_cmplx mz2 = C(mRe_z2, mIm_z2); // -z^2
        return
            complex_mul_cc(z,   complex_add_rc(1.1283791670955125739,
            complex_mul_cc(mz2, complex_add_rc(0.37612638903183752464,
            complex_mul_cc(mz2, complex_add_rc(0.11283791670955125739,
            complex_mul_cc(mz2, complex_add_rc(0.026866170645131251760,
            complex_mul_cr(mz2,                0.0052239776254421878422)))))))));


    }

    /* for small |x| and small |xy|,
       use Taylor series to avoid cancellation inaccuracy:
       erf(x+iy) = erf(iy)
       + 2*exp(y^2)/sqrt(pi) *
       [ x * (1 - x^2 * (1+2y^2)/3 + x^4 * (3+12y^2+4y^4)/30 + ...
       - i * x^2 * y * (1 - x^2 * (3+2y^2)/6 + ...) ]
       where:
       erf(iy) = exp(y^2) * Im[w(y)]
    */
taylor_erfi:
    {
        double x2 = x*x, y2 = y*y;
        double expy2 = exp(y2);
        return C
            (expy2 * x * (1.1283791670955125739
                          - x2 * (0.37612638903183752464
                                  + 0.75225277806367504925*y2)
                          + x2*x2 * (0.11283791670955125739
                                     + y2 * (0.45135166683820502956
                                             + 0.15045055561273500986*y2))),
             expy2 * (im_w_of_x(y)
                      - x2*y * (1.1283791670955125739
                                - x2 * (0.56418958354775628695
                                        + 0.37612638903183752464*y2))));
    }
} // cerf

/******************************************************************************/
/*  cerfc                                                                     */
/******************************************************************************/

_cerf_cmplx cerfc(_cerf_cmplx z)
{
    // Steven G. Johnson, October 2012.

    // Compute erfc(z) = 1 - erf(z), the complex complementary error function,
    // using w_of_z except for certain regions.

    double x = creal(z), y = cimag(z);

    if (x == 0.)
        return C(1,
                 /* handle y -> Inf limit manually, since
                    exp(y^2) -> Inf but Im[w(y)] -> 0, so
                    IEEE will give us a NaN when it should be Inf */
                 y*y > 720 ? (y > 0 ? -Inf : Inf)
                 : -exp(y*y) * im_w_of_x(y));
    if (y == 0.) {
        if (x*x > 750) // underflow
            return C(x >= 0 ? 0.0 : 2.0,
                     -y); // preserve sign of 0
        return C(x >= 0 ? exp(-x*x) * erfcx(x)
                 : 2. - exp(-x*x) * erfcx(-x),
                 -y); // preserve sign of zero
    }

    double mRe_z2 = (y - x) * (x + y); // Re(-z^2), being careful of overflow
    double mIm_z2 = -2*x*y; // Im(-z^2)
    if (mRe_z2 < -750) // underflow
        return C((x >= 0 ? 0.0 : 2.0), 0.0);

    if (x >= 0)
        return cexp(complex_mul_cc(C(mRe_z2, mIm_z2), w_of_z(C(-y,x))));
    else
        return complex_sub_rc(2.0, complex_mul_cc(cexp(C(mRe_z2, mIm_z2)), w_of_z(C(y, -x))));
} // cerfc

/******************************************************************************/
/*  cdawson                                                                   */
/******************************************************************************/

_cerf_cmplx cdawson(_cerf_cmplx z)
{

    // Steven G. Johnson, October 2012.

    // Compute Dawson(z) = sqrt(pi)/2  *  exp(-z^2) * erfi(z),
    // Dawson's integral for a complex argument,
    // using w_of_z except for certain regions.

    double x = creal(z), y = cimag(z);

    // handle axes separately for speed & proper handling of x or y = Inf or NaN
    if (y == 0)
        return C(spi2 * im_w_of_x(x),
                 -y); // preserve sign of 0
    if (x == 0) {
        double y2 = y*y;
        if (y2 < 2.5e-5) { // Taylor expansion
            return C(x, // preserve sign of 0
                     y * (1.
                          + y2 * (0.6666666666666666666666666666666666666667
                                  + y2 * 0.26666666666666666666666666666666666667)));
        }
        return C(x, // preserve sign of 0
                 spi2 * (y >= 0
                         ? exp(y2) - erfcx(y)
                         : erfcx(-y) - exp(y2)));
    }

    double mRe_z2 = (y - x) * (x + y); // Re(-z^2), being careful of overflow
    double mIm_z2 = -2*x*y; // Im(-z^2)
    _cerf_cmplx mz2 = C(mRe_z2, mIm_z2); // -z^2

    /* Handle positive and negative x via different formulas,
       using the mirror symmetries of w, to avoid overflow/underflow
       problems from multiplying exponentially large and small quantities. */
    if (y >= 0) {
        if (y < 5e-3) {
            if (fabs(x) < 5e-3)
                goto taylor;
            else if (fabs(mIm_z2) < 5e-3)
                goto taylor_realaxis;
        }
        _cerf_cmplx res = complex_sub_cc(cexp(mz2), w_of_z(z));
        return complex_mul_rc(spi2, C(-cimag(res), creal(res)));
    }
    else { // y < 0
        if (y > -5e-3) { // duplicate from above to avoid fabs(x) call
            if (fabs(x) < 5e-3)
                goto taylor;
            else if (fabs(mIm_z2) < 5e-3)
                goto taylor_realaxis;
        }
        else if (isnan(y))
            return C(x == 0 ? 0 : NaN, NaN);
        {
            _cerf_cmplx res = complex_sub_cc(w_of_z(complex_neg(z)), cexp(mz2));
            return complex_mul_rc(spi2, C(-cimag(res), creal(res)));
        }
    }

    // Use Taylor series for small |z|, to avoid cancellation inaccuracy
    //     dawson(z) = z - 2/3 z^3 + 4/15 z^5 + ...
taylor:
    return complex_mul_cc(z, complex_add_rc(1.,
        complex_mul_cc(mz2, complex_add_rc(0.6666666666666666666666666666666666666667,
            complex_mul_cr(mz2, 0.2666666666666666666666666666666666666667)))));
    /* for small |y| and small |xy|,
       use Taylor series to avoid cancellation inaccuracy:
       dawson(x + iy)
       = D + y^2 (D + x - 2Dx^2)
       + y^4 (D/2 + 5x/6 - 2Dx^2 - x^3/3 + 2Dx^4/3)
       + iy [ (1-2Dx) + 2/3 y^2 (1 - 3Dx - x^2 + 2Dx^3)
       + y^4/15 (4 - 15Dx - 9x^2 + 20Dx^3 + 2x^4 - 4Dx^5) ] + ...
       where D = dawson(x)

       However, for large |x|, 2Dx -> 1 which gives cancellation problems in
       this series (many of the leading terms cancel).  So, for large |x|,
       we need to substitute a continued-fraction expansion for D.

       dawson(x) = 0.5 / (x-0.5/(x-1/(x-1.5/(x-2/(x-2.5/(x...))))))

       The 6 terms shown here seems to be the minimum needed to be
       accurate as soon as the simpler Taylor expansion above starts
       breaking down.  Using this 6-term expansion, factoring out the
       denominator, and simplifying with Maple, we obtain:

       Re dawson(x + iy) * (-15 + 90x^2 - 60x^4 + 8x^6) / x
       = 33 - 28x^2 + 4x^4 + y^2 (18 - 4x^2) + 4 y^4
       Im dawson(x + iy) * (-15 + 90x^2 - 60x^4 + 8x^6) / y
       = -15 + 24x^2 - 4x^4 + 2/3 y^2 (6x^2 - 15) - 4 y^4

       Finally, for |x| > 5e7, we can use a simpler 1-term continued-fraction
       expansion for the real part, and a 2-term expansion for the imaginary
       part.  (This avoids overflow problems for huge |x|.)  This yields:

       Re dawson(x + iy) = [1 + y^2 (1 + y^2/2 - (xy)^2/3)] / (2x)
       Im dawson(x + iy) = y [ -1 - 2/3 y^2 + y^4/15 (2x^2 - 4) ] / (2x^2 - 1)

    */
taylor_realaxis:
    {
        double x2 = x*x;
        if (x2 > 1600) { // |x| > 40
            double y2 = y*y;
            if (x2 > 25e14) {// |x| > 5e7
                double xy2 = (x*y)*(x*y);
                return C((0.5 + y2 * (0.5 + 0.25*y2
                                      - 0.16666666666666666667*xy2)) / x,
                         y * (-1 + y2 * (-0.66666666666666666667
                                         + 0.13333333333333333333*xy2
                                         - 0.26666666666666666667*y2))
                         / (2*x2 - 1));
            }
            return complex_mul_rc((1. / (-15 + x2 * (90 + x2 * (-60 + 8 * x2)))),
                C(x * (33 + x2 * (-28 + 4 * x2)
                    + +y2 * (18 - 4 * x2 + 4 * y2)),
                    +y * (-15 + x2 * (24 - 4 * x2)
                        + +y2 * (4 * x2 - 10 - 4 * y2))));
        }
        else {
            double D = spi2 * im_w_of_x(x);
            double y2 = y*y;
            return C
                (D + y2 * (D + x - 2*D*x2)
                 + y2*y2 * (D * (0.5 - x2 * (2 - 0.66666666666666666667*x2))
                            + x * (0.83333333333333333333
                                   - 0.33333333333333333333 * x2)),
                 y * (1 - 2*D*x
                      + y2 * 0.66666666666666666667 * (1 - x2 - D*x * (3 - 2*x2))
                      + y2*y2 * (0.26666666666666666667 -
                                 x2 * (0.6 - 0.13333333333333333333 * x2)
                                 - D*x * (1 - x2 * (1.3333333333333333333
                                                    - 0.26666666666666666667 * x2)))));
        }
    }
} // cdawson
