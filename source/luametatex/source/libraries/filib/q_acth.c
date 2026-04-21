/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_acth(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_acth);
    } else {
        double absx = x < 0 ? -x : x;
        if (absx <= 1.0) {
            return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_acth);
        } else {
            double res = 0.5 * q_l1p1(2.0 / (absx - 1.0));
            return x != absx ? -res : res;
        }
    }
}