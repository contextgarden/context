/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* ------------------------------------------------------------------- */
/* --- utilities                                                   --- */
/* ------------------------------------------------------------------- */

double q_abs(double x)
{
    a_diee y;
    y.f = x;
    y.ieee.sign = 0;
    x = y.f;
    return x;
}

interval j_abs(interval x)
{
    interval res;
    if (x.INF < 0) {
        if (x.SUP >= 0) {
            res.INF = 0;
            res.SUP = -x.INF > x.SUP ? -x.INF : x.SUP;
        } else {
            res.INF = -x.SUP;
            res.SUP = -x.INF;
        }
    } else {
        res.INF = x.INF;
        res.SUP = x.SUP;
    }
    return res;
}

double q_min(double x, double y)
{
    return x < y ? x : y;
}

double q_max(double x, double y)
{
    return x > y ? x : y;
}

double q_mid(interval x) 
{
    return 0.5 * (x.INF + x.SUP);
}

/* ------------------------------------------------------------------- */
/* --- assignment                                                  --- */
/* ------------------------------------------------------------------- */

interval eq_ii(interval y)
{
    interval res;
    res.INF = y.INF;
    res.SUP = y.SUP;
    return res;
}

/* ------------------------------------------------------------------- */

interval eq_id(double y)
{
    interval res;
    res.INF = y;
    res.SUP = y;
    return res;
}

/* ------------------------------------------------------------------- */
/* --- functions for addition                                      --- */
/* ------------------------------------------------------------------- */

interval add_ii(interval x, interval y)
{
    interval res;
    res.INF = x.INF == -y.INF ? 0 : q_pred(x.INF + y.INF);
    res.SUP = x.SUP == -y.SUP ? 0 : q_succ(x.SUP + y.SUP);
    return res;
}

/* ------------------------------------------------------------------- */

interval add_id(interval x, double y)
{
    interval res;
    res.INF = x.INF == -y ? 0 : q_pred(x.INF + y);
    res.SUP = x.SUP == -y ? 0 : q_succ(x.SUP + y);
    return res;
}

/* ------------------------------------------------------------------- */

interval add_di(double x, interval y)
{
    interval res;
    res.INF = x == -y.INF ? 0 : q_pred(x + y.INF);
    res.SUP = x == -y.SUP ? 0 : q_succ(x + y.SUP);
    return res;
}

/* ------------------------------------------------------------------- */
/* --- functions for subtraction                                   --- */
/* ------------------------------------------------------------------- */

interval sub_ii(interval x, interval y)
{
    interval res;
    res.INF = x.INF == y.SUP ? 0 : q_pred(x.INF - y.SUP);
    res.SUP = x.SUP == y.INF ? 0 : q_succ(x.SUP - y.INF);
    return res;
}

/* ------------------------------------------------------------------- */

interval sub_id(interval x, double y)
{
    interval res;
    res.INF = x.INF == y ? 0 : q_pred(x.INF - y);
    res.SUP = x.SUP == y ? 0 : q_succ(x.SUP - y);
    return res;
}

/* ------------------------------------------------------------------- */

interval sub_di(double x, interval y)
{
    interval res;
    res.INF = x == y.SUP ? 0 : q_pred(x-y.SUP);
    res.SUP = x == y.INF ? 0 : q_succ(x-y.INF);
    return res;
}

/* ------------------------------------------------------------------- */
/* --- functions for multiplication                                --- */
/* ------------------------------------------------------------------- */

interval mul_ii(interval x, interval y)                                  /*  [x] * [y]                */
{
    interval res;
    double h;
    if (x.INF >= 0) {                                                    /*  0 <= [x]                 */
        if (y.INF >= 0) {                                                /*  0 <= [y]                 */
            h = x.INF * y.INF; res.INF = (h     == 0) ? 0 : q_pred(h);
        } else {                                                         /*  [y] <= 0  or  0 \in [y]  */
            h = x.SUP * y.INF; res.INF = (x.SUP == 0) ? 0 : q_pred(h);
        }
        if (y.SUP <= 0) {                                                /*  [y] <= 0                 */
            h = x.INF * y.SUP; res.SUP = (h     == 0) ? 0 : q_succ(h);
        } else {                                                         /*  0 <= [y]  or  0 \in [y]  */
            h = x.SUP * y.SUP; res.SUP = (x.SUP == 0) ? 0 : q_succ(h);
        }
    } else if (x.SUP <= 0) {                                             /*  [x] <= 0                 */
        if (y.SUP <= 0) {                                                /*  [y] <= 0                 */
            h = x.SUP * y.SUP; res.INF = (h     == 0) ? 0 : q_pred(h);
        } else {                                                         /*  0 <= [y]  or  0 \in [y]  */
            res.INF = q_pred(x.INF * y.SUP);
        }
        if (y.INF >= 0) {                                                /*  0 <= [y]                 */
            h = x.SUP * y.INF; res.SUP = (h     == 0) ? 0 : q_succ(h);
        } else {                                                         /*  [y] <= 0  or  0 \in [y]  */
            res.SUP = q_succ(x.INF * y.INF);
        }
    } else {                                                             /*  0 \in [x]                */
        if (y.INF >= 0) {                                                /*  0 <= [y]                 */
            res.INF = q_pred(x.INF * y.SUP);
            res.SUP = q_succ(x.SUP * y.SUP);
        } else if (y.SUP <= 0) {                                         /*  [y] <= 0                 */
            res.INF = q_pred(x.SUP * y.INF);
            res.SUP = q_succ(x.INF * y.INF);
        } else {                                                         /*  0 \in [x], 0 \in [y]     */
            res.INF = q_pred(q_min(x.INF * y.SUP, x.SUP * y.INF) );
            res.SUP = q_succ(q_max(x.INF * y.INF, x.SUP * y.SUP) );
        }
  }
  return res;
}

/* ------------------------------------------------------------------- */

interval mul_id(interval x, double y)
{
    interval res;
    double h;
    if (y > 0) {
        h = x.INF * y; res.INF = ((h == 0) && (x.INF >= 0)) ? 0 : q_pred(h);
        h = x.SUP * y; res.SUP = ((h == 0) && (x.SUP <= 0)) ? 0 : q_succ(h);
    } else if (y < 0) {
        h = x.SUP * y; res.INF = ((h == 0) && (x.SUP <= 0)) ? 0 : q_pred(h);
        h = x.INF * y; res.SUP = ((h == 0) && (x.INF >= 0)) ? 0 : q_succ(h);
    } else {
        res.INF = 0;
        res.SUP = 0;
    }
    return res;
}

/* ------------------------------------------------------------------- */

interval mul_di(double y, interval x)
{
    interval res;
    double h;
    if (y > 0) {
      h = x.INF * y; res.INF = ((h == 0) && (x.INF >= 0)) ? 0 : q_pred(h);
      h = x.SUP * y; res.SUP = ((h == 0) && (x.SUP <= 0)) ? 0 : q_succ(h);
    } else if (y < 0) {
      h = x.SUP * y; res.INF = ((h == 0) && (x.SUP <= 0)) ? 0 : q_pred(h);
      h = x.INF * y; res.SUP = ((h == 0) && (x.INF >= 0)) ? 0 : q_succ(h);
    } else {
      res.INF = 0;
      res.SUP = 0;
    }
    return res;
}

/* ------------------------------------------------------------------- */
/* --- functions for division                                      --- */
/* ------------------------------------------------------------------- */

interval div_ii(interval x,interval y)
{
    interval res;
    double h;
    if (y.INF > 0) {
        if (x.INF >= 0) {
            h = x.INF / y.SUP;
            res.INF = ((h == 0) ? 0 : q_pred(h));
        } else {
            res.INF = q_pred(x.INF / y.INF);
        }
        if (x.SUP <= 0) {
            h = x.SUP / y.SUP;
            res.SUP = ((h == 0) ? 0 : q_succ(h));
        } else {
            res.SUP = q_succ(x.SUP / y.INF);
        }
    } else if (y.SUP < 0) {
        if (x.SUP <= 0) {
            h = x.SUP / y.INF;
            res.INF = ((h == 0) ? 0 : q_pred(h));
        } else {
            res.INF = q_pred(x.SUP / y.SUP);
        }
        if (x.INF >= 0) {
            h = x.INF / y.INF;
            res.SUP = ((h == 0) ? 0 : q_succ(h));
        } else {
            res.SUP = q_succ(x.INF/y.SUP);
        }
    } else {
        q_abortdivi(FI_LIB_DIV_ZERO, &y.INF, &y.SUP);
        res.INF = res.SUP = 0.0;
    }
    return res;
}

/* ------------------------------------------------------------------- */

interval div_di(double x, interval y)
{
    interval xi;
    xi.INF = x;
    xi.SUP = x;
    return div_ii(xi, y);
}

/* ------------------------------------------------------------------- */

interval div_id(interval x, double y)
{
    interval res;
    double h;
    if (y > 0) {
        h = x.INF / y; res.INF = ((h == 0) && (x.INF >= 0)) ? 0 : q_pred(h);
        h = x.SUP / y; res.SUP = ((h == 0) && (x.SUP <= 0)) ? 0 : q_succ(h);
    } else if (y < 0) {
        h = x.SUP / y; res.INF = ((h == 0) && (x.SUP <= 0)) ? 0 : q_pred(h);
        h = x.INF / y; res.SUP = ((h == 0) && (x.INF >= 0)) ? 0 : q_succ(h);
    } else {
        q_abortdivd(FI_LIB_DIV_ZERO, &y);
        res.INF = res.SUP = 0.0;
    }
    return res;
}

/* ------------------------------------------------------------------- */
/* --- logical operations                                          --- */
/* ------------------------------------------------------------------- */

int in_di(double x, interval y)
{ 
    return (y.INF <= x && x <= y.SUP) ? 1 : 0;
}

int in_ii(interval x, interval y)
{ 
    return (y.INF < x.INF && x.SUP < y.SUP) ? 1 : 0;
}

int ieq_ii(interval x, interval y)
{ 
    return (x.INF == y.INF && x.SUP == y.SUP) ? 1 : 0;
}

int is_ii(interval x, interval y)
{ 
    return (x.INF < y.INF && x.SUP < y.SUP) ? 1 : 0;
}

int ig_ii(interval x, interval y)
{ 
    return (x.INF > y.INF && x.SUP > y.SUP) ? 1 : 0;
}

int ise_ii(interval x, interval y)
{ 
    return (x.INF <= y.INF && x.SUP <= y.SUP) ? 1 : 0;
}

int ige_ii(interval x, interval y)
{ 
    return (x.INF >= y.INF && x.SUP >= y.SUP) ? 1 : 0;
}

int dis_ii(interval x, interval y)
{ 
    return (x.SUP < y.INF || y.SUP < x.INF) ? 1 : 0;
}

/* ------------------------------------------------------------------- */
/* --- convex hull, intersection, diam                             --- */
/* ------------------------------------------------------------------- */

interval hull(interval x, interval y) 
{
    interval res;
    res.INF = (x.INF <= y.INF) ? x.INF : y.INF;
    res.SUP = (x.SUP >= y.SUP) ? x.SUP : y.SUP;
    return res;
}

interval intsec(interval x, interval y)
{
    interval res;
    res.INF = (x.INF >= y.INF) ? x.INF : y.INF;
    res.SUP = (x.SUP <= y.SUP) ? x.SUP : y.SUP;
    return res;
}

double q_diam(interval x) 
{
    return (x.INF == x.SUP) ? 0 : q_succ(x.SUP - x.INF);
}