/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_acsh(interval x)
{
    interval res;
    if (x.INF < 1) {
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_acsh);
    } else if (x.INF == x.SUP) {
        if (x.INF == 1) {
            res.INF = res.SUP = 0;
        } else {
            res.INF = q_acsh(x.INF);
            res.SUP = res.INF * q_acsp;
            res.INF *= q_acsm;
        }
    } else {
        res.INF = q_acsh(x.INF) * q_acsm;
        res.SUP = q_acsh(x.SUP) * q_acsp;
    }
    return res;
}