/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_ex10(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if ((x.INF >= 0) && (x.INF <= 22) && (CUTINT(x.INF) == x.INF)) {
            res.INF = q_ex10(x.INF);
            res.SUP = res.INF;
        } else if (x.INF <= q_extn) {
            res.INF = 0.0;
            res.SUP = q_minr;
        } else {
          res.INF = q_ex10(x.INF);
          res.SUP = res.INF * q_e10p;
          res.INF *= q_e10m;
        }
    } else {
        if (x.INF <= q_extn) {
            res.INF = 0.0;
        } else if ((CUTINT(x.INF) == x.INF) && (x.INF >= 0) && (x.INF <= 22)) {
            res.INF = q_ex10(x.INF);
        } else {
            res.INF = q_ex10(x.INF) * q_e10m;
        }
        if (x.SUP <= q_extn) {
            res.SUP = q_minr;
        } else if ((CUTINT(x.SUP) == x.SUP) && (x.SUP >= 0) && (x.SUP <= 22)) {
            res.SUP = q_ex10(x.SUP);
        } else {
            res.SUP = q_ex10(x.SUP) * q_e10p;
        }
    }   
    if (res.INF < 0.0) {
        res.INF = 0.0;
    }
    if ((x.SUP <= 0.0) && (res.SUP > 1.0)) {
        res.SUP = 1.0;
    }
    if ((x.INF >= 0.0) && (res.INF < 1.0)) {
        res.INF = 1.0;
    }
    return res ;
}