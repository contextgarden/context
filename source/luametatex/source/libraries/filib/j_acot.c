/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_acot(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        res.INF = q_acot(x.INF);
        res.SUP = res.INF * q_cctp;
        res.INF *= q_cctm;
    } else {
        res.INF = q_acot(x.SUP) * q_cctm;
        res.SUP = q_acot(x.INF) * q_cctp;
    }   
    return res;
}