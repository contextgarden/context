/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_acos(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        res.INF = q_acos(x.INF);
        res.SUP = res.INF * q_ccsp;
        res.INF *= q_ccsm;
    } else {
        res.INF = q_acos(x.SUP) * q_ccsm;
        res.SUP = q_acos(x.INF) * q_ccsp;
    }   
    return res;
}