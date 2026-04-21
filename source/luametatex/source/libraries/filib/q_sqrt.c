/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_sqrt(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_sqrt);
    } else if (x < 0) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_sqrt);
    } else {
        return sqrt(x);
    }
}