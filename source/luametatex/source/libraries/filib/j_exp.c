/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_exp(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF == 0) {
            res.INF = res.SUP = 1.0;
        } else if (x.INF <= q_mine) {
          res.INF = 0.0;
          res.SUP = q_minr;
        } else {
          res.INF = q_exp(x.INF);
          res.SUP = res.INF * q_exep;
          res.INF *= q_exem;
        }
    } else {
        if (x.INF <= q_mine) {
            res.INF = 0.0;
        } else {
            res.INF = q_exp(x.INF) * q_exem;
        }
        if (x.SUP <= q_mine) {
            res.SUP = q_minr;
        } else {
            res.SUP = q_exp(x.SUP) * q_exep;
        }
    }
    if (res.INF < 0.0) {
        res.INF = 0.0;
    }
    if ((x.SUP <= 0.0) && (res.SUP>1.0)) {
        res.SUP = 1.0;
    }
    if ((x.INF >= 0.0) && (res.INF<1.0)) {
        res.INF = 1.0;
    }
    return res;
}