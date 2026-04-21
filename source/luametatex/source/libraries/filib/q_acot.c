/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_acot(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_acot);
    } else if ((-1e-17 < x) && (x < 1e-17)) {
        return q_piha;
    } else if (x < 0) {
        return q_pi + q_atn1(1.0 / x);
    } else if (x < 1e10) {
        return q_atn1(1.0 / x);
    } else {
        return 1.0 / x;
    }
}