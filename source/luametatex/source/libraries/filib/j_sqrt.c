/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_sqrt(interval x)
{
    interval res;
    if (x.INF == x.SUP) {
        if (x.INF == 0) {
            res.INF = res.SUP = 0;
        } else {
            res.INF = q_sqrt(x.INF);
            res.SUP = r_succ(res.INF);
            res.INF = r_pred(res.INF);
        }
    } else {
        if (x.INF == 0) {
            res.INF = 0;
        } else {
            res.INF = r_pred(q_sqrt(x.INF));
        }
        res.SUP = r_succ(q_sqrt(x.SUP));
    }
    return res;
}