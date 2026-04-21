/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_asnh(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF < 0) {
            if (x.INF > -q_minr) {
                res.INF = x.INF;
                res.SUP = r_succ(x.INF);
            } else {
                res.INF = q_asnh(x.INF);
                res.SUP = res.INF * q_asnm;
                res.INF *= q_asnp;
                if (res.INF < x.INF) {
                    res.INF = x.INF;
                }
            } 
        } else if (x.INF < q_minr) {
            res.SUP = x.INF;
            if (x.INF == 0) {
                res.INF = 0;
            } else {
                res.INF = r_pred(x.INF);
            }
        } else {
            res.INF = q_asnh(x.INF);
            res.SUP = res.INF * q_asnp;
            res.INF *= q_asnm;
            if (res.SUP > x.INF) {
                res.SUP = x.INF;
            }
        }
    } else {
        if (x.INF <= 0) {
            if (x.INF > -q_minr) {
                /* includes the case x.INF = 0 */
                res.INF = x.INF;
            } else {
                res.INF = q_asnh(x.INF) * q_asnp;
                if (res.INF < x.INF) {
                    res.INF = x.INF;
                }
            }          
        } else if (x.INF < q_minr) {
            res.INF = r_pred(x.INF);
        } else {
            res.INF = q_asnh(x.INF) * q_asnm;
        }
        if (x.SUP < 0) {
            if (x.SUP > -q_minr) {
                res.SUP = r_succ(x.SUP);
            } else {
                res.SUP = q_asnh(x.SUP) * q_asnm;
            }
        } else if (x.SUP < q_minr) {
             /* includes the case x.SUP = 0 */
            res.SUP = x.SUP;
        } else {
            res.SUP = q_asnh(x.SUP) * q_asnp;
            if (res.SUP > x.SUP) {
                res.SUP = x.SUP;
            }
        }
    }   
    return res;
}