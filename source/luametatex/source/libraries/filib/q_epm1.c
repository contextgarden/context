/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* --------------------------------------------------------------------- */
/* - Computation of exp(x)-1, table lookup method                      - */
/* - We use the idea of Mr. P.T.P. Tang                                - */
/* --------------------------------------------------------------------- */

static double q_p1e1(double x) /* range 1 */
{
    long int m;
    double r, r1, r2, q, s;
    double res;
    /* Step 1 */
    long int n = x > 0 ? CUTINT((x * q_exil) + 0.5) : CUTINT((x * q_exil) - 0.5); /* round (x) */
    int j = n % 32;
    if (j < 0) {
        /* We force n2 >= 0 */
        j += 32;
    }
    m = (n - j) / 32;
    r1 = x - n * q_exl1;
    r2 = -(n * q_exl2);
    /* Step 2 */
    r = r1 + r2;
    q = (((q_exa[4] * r + q_exa[3]) * r + q_exa[2]) * r + q_exa[1]) * r + q_exa[0];
    q = r * r * q;
    q = r1 + (r2 + q);
    /* Step 3 */
    s = q_exld[j] + q_extl[j];
    if (m >= 53) {
        if (m < 1023) {
            res = 1.0;
            POWER2(res,-m);
        } else {
            res = 0.0;
        }
	      res = (q_exld[j] + (s * q + (q_extl[j] - res)));
    	  POWER2(res,m);
	  } else if (m <= -8) {
  	     res = (q_exld[j] + (s * q + q_extl[j]));
  	     POWER2(res,m);
  	     res -= 1;
    } else {
	      res = 1.0;
	      POWER2(res,-m); 
	      res = ((q_exld[j] - res) + (q_exld[j] * q + q_extl[j] * (1 + q)));
	      POWER2(res,m);
    }
    return res;
}

static double q_p2e1(double x) /* range 2 */
{
    /* Step 1 */
    double u = (double) (CUT24(x));
    double v = x - u;
    double y = u * u * 0.5;
    double z = v * (x + u) * 0.5;
    /* Step 2 */
    double q = (((((((q_exb[8] * x + q_exb[7]) * x + q_exb[6]) * x + q_exb[5])
	           * x + q_exb[4]) * x + q_exb[3]) * x + q_exb[2]) * x + q_exb[1]) * x + q_exb[0];
    q = x * x * x * q;
    /* Step 3 (somewhat curious parentheses here) */
    if (y >= 7.8125e-3) { /* = 2^-7 */
        return (u + y) + (q + (v + z));
    } else {
        return x + (y + (q + z));
    }
}

double q_epm1(double x)
{ 
    double fabsx = x < 0 ? -x : x;
    if (fabsx < q_ext1) {
        return (q_p2h * x + fabsx) * q_p2mh;
    } else if (q_ex2a < x) {
    	  return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_epm1);
  	} else if (x < q_ext3) {
  		  return -1.0 + q_p2mh;
    } else if (x == 0) {
		    return x;
    } else if ((q_ext4 < x) && (x < q_ext5)) {
        return q_p2e1(x);
    } else {
        return q_p1e1(x);
	  }
}