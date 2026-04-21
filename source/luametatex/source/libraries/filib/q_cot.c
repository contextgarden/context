/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_cot(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_cot);
    } else if ((x < -q_sint[2]) || (x > q_sint[2])) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_cot); /* too big */
    } else if ((x > -q_minr) && (x < q_minr)) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_cot); /* reduction */
    } else {
        long int m, n;
        double ysq, q, s, c;
        double y = x * q_pi2i;
        long int k = y > 0 ? CUTINT(y + 0.5) : CUTINT(y - 0.5);
        y = q_rtrg(x,k);
        n = k % 4;
        if (n < 0) {
          n += 4;
        }
        m = n % 2;
        /* approximate */
        ysq = y * y;
        /* computate sine */
        if ((-q_sint[3] < y) && (y < q_sint[3])) {
            s = n == 0 ? y : -y;
        } else {
            q = ysq * (((((((q_sins[5] * ysq) + q_sins[4])
              * ysq + q_sins[3]) * ysq + q_sins[2]) * ysq + q_sins[1]) * ysq) + q_sins[0]);
            s = y + y * q;
            if (n != 0) {
               s = -s;
            }
        }
        /* computate cosine */
        q = ysq * ysq * (((((((q_sinc[5] * ysq) + q_sinc[4])
          * ysq + q_sinc[3]) * ysq + q_sinc[2]) * ysq + q_sinc[1]) * ysq) + q_sinc[0]);
        if (ysq >= q_sint[0]) {
            c = 0.625 + (0.375 - (0.5 * ysq) + q);
        } else if (ysq >= q_sint[1]) {
            c = 0.8125 + ((0.1875 - (0.5 * ysq)) + q);
        } else {
            c = 1.0 - (0.5 * ysq - q);
        }
        if (n == 2) {
            c = -c;
        }
        /* computate cotangens */
        return m == 0 ? c / s : s / c;
    }
}