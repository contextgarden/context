/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_exp2(double x)
{
    /* Step 1: Special cases  */
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_exp2);
    } else if ((-q_ext1 < x) && (x < q_ext1)) {
        /* |x|<2^-54 */
        return x + 1;
    } else if (1023 < x) {
        return q_abortr1(FI_LIB_OVER_FLOW, &x, fi_lib_exp2);
    } else if (x < -1022) {
    	  return 0;
    } else if (CUTINT(x) == x) {
        /* x is integer */
        double res = 1.0;
        POWER2(res,(long int) x);
        return res;
    } else {
        long int m;
        double r, q, s, res;
        /* Step 2 */
        long int n = x > 0 ? CUTINT((x * 32) + 0.5) : CUTINT((x * 32) - 0.5); /* round */
        int j = n % 32;
        if (j < 0) {
            j += 32; /* force j >= 0 */
        }
        m = (n - j) / 32;
        r = x - n * 0.03125;
        /* Step 3 */
        q = (((((q_exc[6] * r + q_exc[5]) * r + q_exc[4]) * r + q_exc[3]) * r
          + q_exc[2]) * r + q_exc[1]) * r + q_exc[0];
        q = r * q;
        /* Step 4 */
        s = q_exld[j] + q_extl[j];
        res = q_exld[j] + (q_extl[j] + s * q);
        POWER2(res,m);
        return res;
    }
}