/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* --------------------------------------------------------------------- */
/* - Computation of 10^x, table lookup method                          - */
/* - We use the idea of Mr. P.T.P. Tang                                - */
/* --------------------------------------------------------------------- */

double q_ex10(double x)
{
    /* Step 1: Special cases  */
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_ex10);
    } else if ((-q_ext1 < x) && (x < q_ext1)) {
        /* |x| < 2^-54 */
        return x + 1;
    } else if (q_extm < x) {
        return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_ex10); /* overflow */
    } else if (x < q_extn) {
        return 0; /* underflow  */
    } else {
        int j;
        long int n, m;
        double r, r1, r2, q, s, res;
  	    /* Step 2 */
  	    if (x > 0) {
          n = CUTINT((x*q_e10i)+0.5); /* 32/lg10 = 106... */
  	    } else {
          n = CUTINT((x*q_e10i)-0.5); /* round (x) */
        }
  	    j = n % 32;
  	    if (j < 0) {
          j += 32;
        }
  	    m = (n - j) / 32;
  	    r1 = x - n * q_e1l1;
        r2 = -(n * q_e1l2);
  	    /* Step 3 */
        r = r1 + r2;
        q = (((((q_exd[6] * r + q_exd[5]) * r + q_exd[4]) * r + q_exd[3]) * r
          + q_exd[2]) * r + q_exd[1]) * r + q_exd[0];
  	    q = r * q;
        q = r1 + (r2 + q);
  	    /* Step 4 */
  	    s = q_exld[j] + q_extl[j];
  	    res = (q_exld[j] + (q_extl[j] + s * q));
  	    POWER2(res,m);
        return res;
    }
}
