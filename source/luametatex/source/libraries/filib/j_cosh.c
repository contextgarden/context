/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_cosh(interval x)
{
    interval res;
    if (x.SUP < 0) {
        if (x.INF == x.SUP) {
            res.INF = q_cosh(x.INF);
            res.SUP = res.INF * q_cshp;
            res.INF *= q_cshm;
        } else {
            res.INF = q_cosh(x.SUP) * q_cshm;
            res.SUP = q_cosh(x.INF) * q_cshp;
        }
        if (res.INF < 1.0) {
          res.INF = 1.0;
        }
    } else if (x.INF > 0) {
        if (x.INF == x.SUP) {
            res.INF = q_cosh(x.INF);
            res.SUP = res.INF * q_cshp;
            res.INF *= q_cshm;
        } else {
            res.INF = q_cosh(x.INF) * q_cshm;
            res.SUP = q_cosh(x.SUP) * q_cshp;
        }
        if (res.INF < 1.0) {
            res.INF = 1.0;
        }
    } else if (-x.INF > x.SUP) {
        res.INF = 1.0;
        res.SUP = q_cosh(x.INF) * q_cshp;
    } else {
        res.INF = 1.0;
        res.SUP = q_cosh(x.SUP) * q_cshp;
    }
    return res;
}