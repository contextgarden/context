/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_exp2(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF < -1022) {
            res.INF = 0.0;
            res.SUP = q_minr;
        } else if (CUTINT(x.INF) == x.INF) {
          res.INF = res.SUP = q_exp2(x.INF);
        } else {
          res.INF = q_exp2(x.INF);
          res.SUP = res.INF * q_e2ep;
          res.INF *= q_e2em;
        }
    } else {
        if (x.INF < -1022) {
            res.INF = 0.0;
        } else if (CUTINT(x.INF) == x.INF) {
            res.INF = q_exp2(x.INF);
        } else {
            res.INF = q_exp2(x.INF) * q_e2em;
        }
        if (x.SUP < -1022) {
            res.SUP = q_minr;
        } else if (CUTINT(x.SUP) == x.SUP) {
            res.SUP = q_exp2(x.SUP);
        } else {
            res.SUP = q_exp2(x.SUP) * q_e2ep;
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
    return res;
}