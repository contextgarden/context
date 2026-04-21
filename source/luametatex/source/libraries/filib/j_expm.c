/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_expm(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF < 0) {
            if (x.INF > -q_minr) {
                res.INF = x.INF;
                res.SUP = r_succ(x.INF);
            } else {
                res.INF = q_expm(x.INF);
                res.SUP = res.INF * q_exmm;
                res.INF *= q_exmp;
            } 
        } else if (x.INF < q_minr) {
            res.INF = x.INF;
            if (x.INF == 0) {
                res.SUP = 0;
            } else {
                res.SUP = r_succ(x.INF);
            }
       } else {
            res.INF = q_expm(x.INF);
            res.SUP = res.INF * q_exmp;
            res.INF *= q_exmm;
        }
    } else {
        if (x.INF <= 0) {
            if (x.INF > -q_minr) {
                res.INF = x.INF;                 /* includes case x.INF=0 */
            } else {
                res.INF = q_expm(x.INF) * q_exmp;
            }
        } else if (x.INF < q_minr) {
            res.INF = x.INF;
        } else {
            res.INF = q_expm(x.INF) * q_exmm;
        }
        if (x.SUP < 0) {
            if (x.SUP > -q_minr) {
                res.SUP = r_succ(x.SUP);
            } else {
                res.SUP = q_expm(x.SUP) * q_exmm;
            }
        } else if (x.SUP < q_minr) {
            res.SUP = r_succ(x.SUP);
        } else {
            res.SUP = q_expm(x.SUP) * q_exmp;
        }
    }   
    if (res.INF < -1.0) {
      res.INF = -1.0;
    }
    return res;
}
