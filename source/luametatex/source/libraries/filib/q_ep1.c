/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* --------------------------------------------------------------------- */
/* - Computation of exp(x), table lookup method                        - */
/* - We use the idea of Mr. P.T.P. Tang                                - */
/* - Version without an argument check                                 - */
/* --------------------------------------------------------------------- */

double q_ep1(double x)
{
	/* Step 1: Special case  */
  	if ((-q_ext1 < x) && (x < q_ext1)) {
		/* |x|<2^-54 */
		return x + 1;
	} else if (q_ex2a < x) {
      	return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_ep1);
    } else if (x < q_ex2b) {
	  	return 0; /* underflow */
	} else {
		long int m;
		double r, r1, r2, q, s;
		double res;
    	/* Step 2 */
    	long int n = x > 0 ? CUTINT((x * q_exil) + 0.5) : CUTINT((x * q_exil) - 0.5); /* round (x) */
	    int j = n % 32;
    	if (j < 0) {
			/* We force j>=0  */
    		j += 32;
    	}
		m = (n - j) / 32;
		r1 = x - n * q_exl1;
		r2 = -(n * q_exl2);
		/* Step 3 */
		r = r1 + r2;
		q = (((q_exa[4] * r + q_exa[3]) * r + q_exa[2]) * r + q_exa[1]) * r + q_exa[0];
		q = r * r * q;
		q = r1 + (r2 + q);
		/* Step 4 */
		s = q_exld[j] + q_extl[j];
		res = (q_exld[j] + (q_extl[j] + s * q));
		POWER2(res, m);
		return res;
	}
}