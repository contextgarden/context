/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_tanh(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_tanh);
    } else if ((-1e-10 < x) && (x < 1e-10)) {
        return x;
    } else {
        return 1.0 / q_cth1(x);
    }
}