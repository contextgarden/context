/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_cot(interval x)
{
    interval res;
    if ((x.INF < -q_sint[2]) || (x.SUP > q_sint[2])) {
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_cot); /* too big */
    } else if (x.INF == x.SUP) {
        res.INF = q_cot(x.INF);
        if (res.INF < 0) {
            res.SUP = res.INF * q_cotm;
            res.INF *= q_cotp;
        } else {
            res.SUP = res.INF * q_cotp;
            res.INF *= q_cotm;
        }
    } else if (((x.INF <= 0) && (x.SUP >= 0)) || ((x.SUP < 0) && (x.SUP > -q_minr)) || ((x.INF > 0) && (x.INF < q_minr))) {
        /* Singularitaet */ /* was wrong: two times & instead of && */
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_cot);
    } else {
        double h1, h2;
        long int k1, k2, q1;
        h1 = x.INF * q_pi2i;
        k1 = CUTINT(h1);
        if (k1 < 0) {
            q1 = (k1 - 1) % 2;
        } else {
            q1 = k1 % 2;
        }
        if (q1 < 0) {
          q1 += 2;
        }
        h2 = x.SUP * q_pi2i;
        k2 = CUTINT(h2);
        if ((k1 == k2) || ((q1 == 0) && (k1 == k2 - 1))) {
            res.INF = q_cot(x.SUP);
            if (res.INF >= 0) {
                res.INF *= q_cotm;
            } else {
                res.INF *= q_cotp;
            }
            res.SUP = q_cot(x.INF);
            if (res.SUP >= 0) {
                res.SUP *= q_cotp;
            } else {
                res.SUP *= q_cotm;
            }
        } else {
            res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_cot);
        }
    }
    return res;
}