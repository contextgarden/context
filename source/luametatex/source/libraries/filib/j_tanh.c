/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_tanh(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF < 0) {
            if (x.INF > -q_minr) {
                res.INF = x.INF;
                res.SUP = r_succ(x.INF);
            } else {
                res.INF = q_tanh(x.INF);
                res.SUP = res.INF * q_tnhm;
                res.INF *= q_tnhp;
                if (res.INF < x.INF) {
                    res.INF = x.INF;
                }
            }
        } else {
            if (x.INF < q_minr) {
                res.SUP = x.INF;
                if (x.INF == 0) {
                    res.INF = 0;
                } else {
                    res.INF = r_pred(x.INF);
                }
            } else {
                res.INF = q_tanh(x.INF);
                res.SUP = res.INF * q_tnhp;
                res.INF *= q_tnhm;
                if (res.SUP > x.INF) {
                    res.SUP = x.INF;
                }
            }
        }
    } else {
        if (x.INF <= 0) {
            if (x.INF > -q_minr) {
                /* includes the case x.INF=0 */
                res.INF = x.INF;
            } else {
                res.INF = q_tanh(x.INF) * q_tnhp;
                if (res.INF < x.INF) {
                    res.INF = x.INF;
                }
            }
        } else {
           /* now x.INF>0 */
            if (x.INF < q_minr) {
                res.INF = r_pred(x.INF);
            } else {
                res.INF = q_tanh(x.INF) * q_tnhm;
            }
        }
        if (x.SUP < 0) {
            if (x.SUP > -q_minr) {
                res.SUP = r_succ(x.SUP);
            } else {
                res.SUP = q_tanh(x.SUP) * q_tnhm;
            }
        } else {
            /* now x.SUP >= 0 */
            if (x.SUP < q_minr) {
                /* includes the case x.SUP=0 */
                res.SUP = x.SUP;
            } else {
                res.SUP = q_tanh(x.SUP) * q_tnhp;
                if (res.SUP > x.SUP) {
                    res.SUP = x.SUP;
                }
            }
        }
    }
    if (res.SUP > 1.0) {
        res.SUP = 1.0;
    }
    if (res.INF < -1.0) {
        res.INF = -1.0;
    }
    return res;
}
