/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_acos(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_acos);
    } else if ((x < -1.0) || (1.0 < x)) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_acos);
    } else if ((-1e-17 < x) && (x < 1e-17)) { // was &
        return q_piha;
    } else if (x < 0) {
        return q_pi + q_atn1(sqrt((1 + x) * (1 - x))/x);
    } else {
        return q_atn1(sqrt((1 + x) * (1 - x))/x);
    }
}