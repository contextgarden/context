/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_coth(interval x)
{
    interval res;
    if (x.SUP < 0) {
        if (x.INF == x.SUP) {
          res.INF = q_coth(x.INF);
          res.SUP = res.INF * q_cthm;
          res.INF *= q_cthp;
        } else {
          res.INF = q_coth(x.SUP) * q_cthp;
          res.SUP = q_coth(x.INF) * q_cthm;
        }
        if (res.SUP > -1) {
            res.SUP = -1.0;
        }
    } else if (x.INF > 0) {
        if (x.INF == x.SUP) {
            res.INF = q_coth(x.INF);
            res.SUP = res.INF * q_cthp;
            res.INF *= q_cthm;
        } else {
            res.INF = q_coth(x.SUP) * q_cthm;
            res.SUP = q_coth(x.INF) * q_cthp;
        }
        if (res.INF < 1) {
            res.INF = 1.0;
        }
    } else {
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_coth);
    }
    return res;
}
