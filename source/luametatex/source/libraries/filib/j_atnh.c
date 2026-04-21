/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_atnh(interval x)
{
    interval res;
    if ((x.INF > -1) && (x.SUP < 1)) {
        if (x.INF == x.SUP) {
            if (x.INF < 0) {
                if (x.INF > -q_minr) {
                    res.INF = r_pred(x.INF);
                    res.SUP = x.INF;
                } else {
                    res.INF = q_atnh(x.INF);
                    res.SUP = res.INF * q_atnm;
                    res.INF *= q_atnp;
                    if (res.SUP > x.INF) {
                        res.SUP = x.INF;
                    }
                }
            } else {
                if (x.INF < q_minr) {
                    res.INF = x.INF;
                    if (x.INF == 0) {
                        res.SUP = 0;
                    } else {
                        res.SUP = r_succ(x.INF);
                    }
                } else {
                    res.INF = q_atnh(x.INF);
                    res.SUP = res.INF*q_atnp;
                    res.INF *= q_atnm;
                    if (res.INF < x.INF) {
                        res.INF = x.INF;
                    }
                }
            }
        } else {
            if (x.INF < 0) {
                if (x.INF > -q_minr) {
                    res.INF = r_pred(x.INF);
                } else {
                    res.INF = q_atnh(x.INF) * q_atnp;
                }
            } else {
                if (x.INF < q_minr) {
                    /* includes the case x.INF = 0 */
                    res.INF = x.INF;
                } else {
                    res.INF = q_atnh(x.INF) * q_atnm;
                    if (res.INF < x.INF) {
                        res.INF = x.INF;
                    }
                }
            }
            if (x.SUP <= 0) {
                if (x.SUP > -q_minr) {
                    /* includes the case x.SUP = 0 */
                    res.SUP = x.SUP;
                } else {
                    res.SUP = q_atnh(x.SUP) * q_atnm;
                    if (res.SUP > x.SUP) {
                      res.SUP = x.SUP;
                    }
                }
            } else {
                if (x.SUP < q_minr) {
                    res.SUP = r_succ(x.SUP);
                } else {
                    res.SUP = q_atnh(x.SUP)*q_atnp;
                }
            }
        }
    } else {
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_atnh);
    }
    return res;
}

