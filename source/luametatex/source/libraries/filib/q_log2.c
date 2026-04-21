/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_log2(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_log2);
    } else {
        return q_log(x) * q_l2i;
    }
}