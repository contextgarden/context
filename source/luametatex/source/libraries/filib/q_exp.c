/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* --------------------------------------------------------------------- */
/* - Computation of exp(x), table lookup method                        - */
/* - We use the idea of Mr. P.T.P. Tang                                - */
/* --------------------------------------------------------------------- */

double q_exp(double x)
{
	/* Step 1: Special cases  */
	if NANTEST(x) {
		return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_exp);
	} else if ((-q_ext1 < x) && (x < q_ext1)) {
		/* |x|<2^-54 */
		return x + 1;
 	} else if (q_ex2a < x) {
		return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_exp);
	} else if (x < q_mine) {
		/* underflow */
		return 0;
	} else {
		long int m;
		double r, r1, r2, q, s, res;
		/* Step 2 */
		long int n = x > 0 ? CUTINT((x * q_exil) + 0.5) : CUTINT((x * q_exil) - 0.5); /* round (x) */
		int j = n % 32;
		if (j < 0) {
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
	    POWER2(res,m);
	    return res;
	}
}