/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_sqr(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_sqr);
    } else if ((x < -q_sqra) || (x > q_sqra)) {
        return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_sqr);
    } else {
        return x * x;
    }
}