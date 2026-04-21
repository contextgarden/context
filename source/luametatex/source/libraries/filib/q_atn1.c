/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_atn1(double x)
{
    double absx = x < 0 ? -x : x;
    if (absx <= q_atnt) {
        return x;
    } else {
        double ym, y, ysq, res;
        int ind, sgn;
        if (absx < 8) {
            sgn = 1;
            ym = 0;
        } else {
            sgn = -1;
            ym = q_piha;
            absx = 1 / absx;
        }
        ind = 0;
        while (absx >= q_atnb[ind+1]) {
            ind += 1;
        }
        y = (absx - q_atnc[ind]) / (1 + absx * q_atnc[ind]);
        ysq = y * y;
        res = (y + y * (ysq * (((((q_atnd[5] * ysq + q_atnd[4])
            * ysq + q_atnd[3]) * ysq + q_atnd[2])
            * ysq + q_atnd[1]) * ysq + q_atnd[0]))) + q_atna[ind];
        res = res * sgn + ym;
        return x < 0 ? -res : res;
    }
}