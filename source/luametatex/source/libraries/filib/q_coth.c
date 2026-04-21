/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_coth(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_coth);
    } else if ((x > -q_ctht) && (x < q_ctht)) {
        return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_coth);
    } else {
        double absx;
        int sgn;
        if (x < 0) {
            sgn = -1;
            absx = -x;
        } else {
            sgn = 1;
            absx = x;
        }
        if (absx > 22.875) {
            return sgn;
        } else if (absx >= q_ln2h) {
            return sgn * (1 + 2/(q_ep1(2 * absx) - 1));
        } else {
            return sgn * (1 + 2/q_epm1(2 * absx));
        }
    }
}