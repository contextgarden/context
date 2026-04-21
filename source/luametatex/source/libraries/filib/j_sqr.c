/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_sqr(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF == 0) {
            res.INF = res.SUP = 0;
        } else {
            res.INF = q_sqr(x.INF);
            res.SUP = r_succ(res.INF);
            res.INF = r_pred(res.INF);
        }
    } else if NANTEST(x.INF) {
        res.INF = q_abortnan(FI_LIB_INV_ARG, &x.INF, fi_lib_sqr);
        res.SUP = 0;
    } else if NANTEST(x.SUP) {
        res.SUP = q_abortnan(FI_LIB_INV_ARG, &x.SUP, fi_lib_sqr);
        res.INF = 0;
    } else if ((x.INF < -q_sqra) || (x.SUP > q_sqra)) {
        res = q_abortr2(FI_LIB_OVER_FLOW, &x.INF, &x.SUP, fi_lib_sqr);
    } else if (x.INF == 0) {
        res.INF = 0;
        res.SUP = r_succ(x.SUP * x.SUP);
    } else if (x.INF > 0) {
        res.INF = r_pred(x.INF * x.INF);
        res.SUP = r_succ(x.SUP * x.SUP);
    } else if (x.SUP == 0) {
        res.INF = 0;
        res.SUP = r_succ(x.INF * x.INF);
    } else if (x.SUP < 0) {
        res.INF = r_pred(x.SUP * x.SUP);
        res.SUP = r_succ(x.INF * x.INF);
    } else if (-x.INF > x.SUP) {
        res.INF = 0;
        res.SUP = r_succ(x.INF * x.INF);
    } else {
        res.INF = 0;
        res.SUP = r_succ(x.SUP * x.SUP);
    }
    return res;
}