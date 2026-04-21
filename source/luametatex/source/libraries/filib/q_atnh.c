/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_atnh(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_atnh);
    } else if ((x <= -1.0) || (1.0 <= x)) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_atnh);
    } else {
        double absx = x < 0 ? -x : x;
        double res;
        if (absx >= q_at3i) {
            res = 0.5 * q_log1((1 + absx) / (1 - absx));
        } else {
            res = 0.5 * q_l1p1((2 * absx) / (1 - absx));
        }
        return x < 0 ? -res : res;
    }
}