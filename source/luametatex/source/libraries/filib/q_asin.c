/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_asin(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_asin);
    } else if ((x < -1.0) || (1.0 < x)) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_asin);
    } else if (x == -1) {
        return -q_piha;
    } else if (x == 1) {
        return q_piha;
    } else if ((-q_atnt <= x) && (x <= q_atnt)) {
        return x;
    } else {
        return q_atn1(x / sqrt((1.0 + x) *(1.0 - x)));
    }
}