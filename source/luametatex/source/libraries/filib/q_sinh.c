/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_sinh(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_sinh);
    } else {
        int sgn;
        double absx;
        if (x < 0) {
            sgn = -1;
            absx = -x;
        } else {
            sgn = 1;
            absx = x;
        }
        if (absx > q_ex2a) {
            return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_sinh);
        } else if (absx < 2.5783798e-8) {
            return x;
        } else if (absx >= 0.662)  {
            double h = q_ep1(absx);
            return sgn * 0.5 *(h - 1.0/h);
        } else {
            double h = q_epm1(absx);
            return sgn * 0.5 *(h + h/(h + 1.0));
        }
    }
}