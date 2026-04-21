/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_lg10(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        res.INF = q_lg10(x.INF);
        if (res.INF >= 0) {
            res.SUP = res.INF * q_l10p;
            res.INF *= q_l10m;
        } else {
            res.SUP = res.INF * q_l10m;
            res.INF *= q_l10p;
        }
    } else {
        res.INF = q_lg10(x.INF);
        if (res.INF >= 0) {
            res.INF *= q_l10m;
        } else {
            res.INF *= q_l10p;
        }
        res.SUP = q_lg10(x.SUP);
        if (res.SUP >= 0) {
            res.SUP *= q_l10p;
        } else {
            res.SUP *= q_l10m;
        }
    }   
    return res;
}