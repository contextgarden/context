/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_tan(double x)
{
    /* Special cases */
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_tan);
    } else if ((x < -q_sint[2]) || (x > q_sint[2])) {
        /* abs. argument too big */
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_tan);
    } else if (x == 0) {
        /* Argument reduction */
        return 0.0;
    } else {
        long int m, n, k;
        double y = x * q_pi2i;
        if (y > 0) {
            k = CUTINT(y + 0.5);
        } else {
            k = CUTINT(y - 0.5);
        }
        y = q_rtrg(x,k);
        n = k % 4;
        if (n < 0) {
            n += 4;
        }
        m = n % 2;
        /* Approximation */
        if ((-q_sint[4] < y) && (y < q_sint[4])) {
            if (m == 0) {
                return y;
            } else {
                return -1/y;
            }
        } else {
            double ysq, q, s, c;
            ysq = y * y;
            /* Computation sine */
            q = ysq*(((((((q_sins[5] * ysq) + q_sins[4])
              * ysq + q_sins[3]) * ysq + q_sins[2]) * ysq + q_sins[1]) * ysq) + q_sins[0]);
          /*
            if (n == 0) {
                s = y + y * q;
            } else {
                s = -(y + y * q);
            }
          */
            s = y + y * q;
            /* Computation cosine */
            q = ysq * ysq * (((((((q_sinc[5] * ysq) + q_sinc[4])
              * ysq + q_sinc[3]) * ysq + q_sinc[2]) * ysq + q_sinc[1]) * ysq) + q_sinc[0]);
            if (ysq >= q_sint[0]) {
                 c = 0.625 + (0.375 - (0.5 * ysq) + q);
            } else if (ysq >= q_sint[1]) {
                 c = 0.8125 + ((0.1875 - (0.5 * ysq)) + q);
            } else {
                 c = 1.0 - (0.5 * ysq - q);
            }
          /*
            if (n == 3) {
                c = -c;
            }
          */
           /* Computation tangens */
            if (m == 0) {
                return s / c;
            } else {
                return -c / s;
            }
        }
    }
}