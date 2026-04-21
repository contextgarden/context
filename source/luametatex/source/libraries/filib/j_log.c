/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_log(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        res.INF = q_log(x.INF);
        if (res.INF >= 0) {
            res.SUP = res.INF * q_logp;
            res.INF *= q_logm;
        } else {
            res.SUP = res.INF * q_logm;
            res.INF *= q_logp;
        }
    } else {
        res.INF = q_log(x.INF);
        if (res.INF >= 0) {
            res.INF *= q_logm;
        } else {
            res.INF *= q_logp;
        }
        res.SUP = q_log(x.SUP);
        if (res.SUP >= 0) {
            res.SUP *= q_logp;
        } else {
            res.SUP *= q_logm;
        }
    }   
    return res;
}