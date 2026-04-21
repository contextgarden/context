/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_acsh(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_acsh);
    } else if (x < 1) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_acsh);
    } else if (x < 1.025) {
        return q_l1p1(x - 1 + sqrt((x - 1) * (x + 1)));
    } else if (x > 1e150) {
        return q_l2 + q_log1(x);
    } else {
        return q_log1(x + sqrt((x - 1) * (x + 1)));
    }
}