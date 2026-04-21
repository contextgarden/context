/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_cosh(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_cosh);
    } else if ((x >= -q_ex2c) && (x <= q_ex2c)) {
        return 0.5 * (q_ep1(x) + q_ep1(-x));
    } else if ((x >= -q_ex2a) && (x <= q_ex2a)) {
        return (0.5 * q_exp(x)) + (0.5 * q_exp(-x));
    } else {
        return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_cosh);
    }
}