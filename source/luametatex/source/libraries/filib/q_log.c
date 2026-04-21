/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* --------------------------------------------------------------------- */
/* - Computation of log(x), table lookup method                        - */
/* - We use the idea of Mr. P.T.P. Tang                                - */
/* --------------------------------------------------------------------- */

static double q_p1lg(int m, double fg, double fk, double y) /* range 1 */
{
    /* Step 1 */
    int j = CUTINT((fg - 1.0) * 128); /* floor */
    double l_lead  = m * q_lgld[128] + q_lgld[j];
    double l_trail = m * q_lgtl[128] + q_lgtl[j];
    /* Step 2: Approximation  */
    double u = (fk + fk) / (y + fg);
    double v = u * u;
    double q = u * v * (q_lgb[0] + v * q_lgb[1]);
    /* Step 3 */
    return l_lead + (u + (q + l_trail));
}

static double q_p2lg(double fk) /* range 2 */
  {  
     /* Step 1 */
     double g = 1 / (2 + fk);
     double u = 2 * fk * g;
     double v = u * u;
     /* Step 2 */
     double q = u * v * (q_lgc[0] + v * (q_lgc[1] + v * (q_lgc[2] + v * q_lgc[3])));
     /* Step 3 */
     double u1 = CUT24(u);  /* u1 = 24 leading bits of u  */
     double f1 = CUT24(fk); /* f1 = 24 leading bits of fk */
     double f2 = fk - f1;
     double u2 = ((2 * (fk - u1) -u1 * f1) - u1 * f2) * g;
     /* Step 4 */
     return u1 + (u2 + q);
  }

double q_log(double x)
{  
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_log);
    } else if (x < q_minr) {
        /* only positive normalised arguments */
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_log);
    } else if (x == 1) {
        return 0.0;
    } else if ((q_lgt1 < x) && (x < q_lgt2)) {
        return q_p2lg(x - 1);
    } else if (x <= DBL_MAX) {
        int m;
        double fg, fk, y;
        FREXPO(x,m); 
        m -= 1023;
        y = x;
        POWER2(y,-m);
        fg = CUTINT(128 * y + 0.5); /* exp2(+7) = 128       */
        fg = 0.0078125 * fg;        /* exp2(-7) = 0.0078125 */
        fk = y - fg;
        return q_p1lg(m, fg, fk, y);
    } else {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_log);
    }
}

/* --------------------------------------------------------------------- */
/* - Computation of log1p(x)=log(1+x), table lookup method             - */
/* --------------------------------------------------------------------- */

double q_lg1p(double x)
{  
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_lg1p);
    } else if (x <= -1) {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_lg1p);
    } else if (x == 0) {
        return x;
    } else if ((-q_lgt5 < x) && (x < q_lgt5)) {
        return x; /* res=(8*x-ldexp(1.0,-1074))*0.125; */
    } else if ((q_lgt3 < x) && (x < q_lgt4)) {
        return q_p2lg(x);
    } else if (x <= DBL_MAX) {
        int m;
        double fg, fk, h;
        double t = q_lgt6;
        double y = x < t ? 1 + x : x;
        FREXPO(y,m);
        m -= 1023;
        POWER2(y,-m);
        fg = CUTINT(128* y + 0.5); /* exp2(+7) = 128       */
        fg = 0.0078125 * fg;       /* exp2(-7) = 0.0078125 */
        if (m <= -2) {
          fk = y - fg;
        } else if ((-1 <= m) && (m <= 52)) {
            fk = 1.0;
            POWER2(fk,-m);
            h = x;
            POWER2(h,-m); 
            fk = (fk - fg) + h;
        } else {
            fk = 1.0;
            POWER2(fk,-m);
            h = x;
            POWER2(h,-m);
            fk = (h - fg) + fk;
        }
        return q_p1lg(m, fg, fk, y);
    } else {
        return q_abortr1(FI_LIB_INV_ARG, &x, fi_lib_lg1p);
    }
}