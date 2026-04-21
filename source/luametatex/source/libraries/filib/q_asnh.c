/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_asnh(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_asnh);
    } else if ((x > -2.5e-8) && (x < 2.5e-8)) {
        return x;
    } else {
        int neg;
        double res;
        if (x < 0) {
            x = -x;
            neg = 1;
        } else {
            neg = 0;
        }
        if (x > 1e150) {
            res = q_l2 + q_log1(x);
        } else if (x >= 1.25) {
            /* old: x>=0.03125 */
            res = q_log1(x + sqrt(x * x + 1));
        } else {
            double h = 1 / x;
            res = q_l1p1(x + x/(sqrt(1 + h * h) + h));
        }
        return neg ? -res : res;
    }
}