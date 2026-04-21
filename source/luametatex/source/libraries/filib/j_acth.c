/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_acth(interval x)
{
    interval res;
    if (x.SUP < -1) {
        if (x.INF == x.SUP)  {
            res.INF = q_acth(x.INF);
            res.SUP = res.INF * q_actm;
            res.INF *= q_actp;
        } else {
            res.INF = q_acth(x.SUP) * q_actp;
            res.SUP = q_acth(x.INF) * q_actm;
        }
    } else if (x.INF > 1) {
        if (x.INF == x.SUP) {
            res.INF = q_acth(x.INF);
            res.SUP = res.INF * q_actp;
            res.INF *= q_actm;
        } else  {
            res.INF = q_acth(x.SUP) * q_actm;
            res.SUP = q_acth(x.INF) * q_actp;
        }
    } else {
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_acth);
    }
    return res;
}