/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

interval j_tan(interval x)
{
    interval res;
    if ((x.INF < -q_sint[2]) || (x.SUP > q_sint[2])) {
        res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_tan);  /* abs. argument too big */
    } else if (x.INF == x.SUP) {
        if ((x.INF >= -q_sint[4]) && (x.INF < 0)) {
            res.INF = r_pred(x.INF);
            res.SUP = x.INF;
        } else if ((x.INF >= 0) && (x.INF <= q_sint[4])) {
            res.INF = x.INF;
            if (x.INF == 0) {
                res.SUP = 0;
            } else {
                res.SUP = r_succ(x.INF);
            }
        } else {
            res.INF = q_tan(x.INF);
            if (res.INF < 0) {
                res.SUP = res.INF * q_tanm;
                res.INF *= q_tanp;
            } else {
                res.SUP = res.INF * q_tanp;
                res.INF *= q_tanm;
            }
        }
    } else {
        double h1, h2;
        long int k1, k2, q1;
        /* x is not a point interval */
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
        if ((k1 == k2) || ((q1 == 1) && (k1 == k2 - 1))) { // was &
            if ((-q_sint[4] < x.INF) && (x.INF < 0)) {
                res.INF = r_pred(x.INF);
            } else if ((0 <= x.INF) && (x.INF < q_sint[4])) {
                res.INF = x.INF;
            } else {
              res.INF = q_tan(x.INF);
              if (res.INF >= 0) {
                  res.INF *= q_tanm;
              } else {
                  res.INF *= q_tanp;
              }
            }
            if ((-q_sint[4] < x.SUP) && (x.SUP <= 0)) {
                res.SUP = x.SUP;
            } else if ((0 < x.SUP) && (x.SUP < q_sint[4])) {
                res.SUP = r_succ(x.SUP);
            } else {
                res.SUP = q_tan(x.SUP);
                if (res.SUP >= 0) {
                    res.SUP *= q_tanp;
                } else {
                    res.SUP *= q_tanm;
                }
            }
        } else {
          res = q_abortr2(FI_LIB_INV_ARG, &x.INF, &x.SUP, fi_lib_tan);
        }
    }
    return res;
}