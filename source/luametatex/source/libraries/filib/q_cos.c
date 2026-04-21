/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_cos(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_cos);
    } else if ((x < -q_sint[2]) || (x > q_sint[2])) {
        /* abs. argument too big */
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_cos);
    } else {
        /* Argument reduction */
        double ysq;
        long int m, n;
        double y = x * q_pi2i;
        long int k = y > 0 ? CUTINT(y + 0.5) : CUTINT(y - 0.5);
        y = q_rtrg(x, k);
        n = (k + 1) % 4;
        if (n < 0) {
            n += 4;
        }
        m = n % 2;
        /* Approximation */
        ysq = y * y;
        if (m == 0) {
            /* Approximation sine-function, scheme of Horner */
            if ((-q_sint[3] < y) && (y < q_sint[3])) {
                return n == 0 ? y : -y;
            } else {
                double q = ysq * (((((((q_sins[5] * ysq) + q_sins[4])
                         * ysq + q_sins[3]) * ysq + q_sins[2])
                         * ysq + q_sins[1]) * ysq) + q_sins[0]);
                double res = y + y *q;
                return n == 0 ? res : - res;
            }
        } else {
            /* Approximation cosine-function, scheme of Horner */
            double q = ysq * ysq * (((((((q_sinc[5] * ysq) + q_sinc[4])
                     * ysq + q_sinc[3]) *ysq + q_sinc[2]) * ysq + q_sinc[1]) * ysq) + q_sinc[0]);
            double res;
            if (ysq >= q_sint[0]) {
                res = 0.625 + (0.375 - (0.5 * ysq) + q);
            } else if (ysq >= q_sint[1]) {
                res = 0.8125 + ((0.1875 - (0.5 * ysq)) + q);
            } else {
                res = 1.0 - (0.5 * ysq - q);
            }
            return n == 3 ? -res : res;
        }
    }
}