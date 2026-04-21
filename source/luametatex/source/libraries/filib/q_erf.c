/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/***********************************************************************/  
/* Stand: 18.04.2000                                                   */
/* Autor: cand.math.oec Stefan Traub, IAM, Universitaet Karlsruhe (TH) */    
/***********************************************************************/

/* ------------------------------------------------------------------- */
/* ----           the function q_expx2 = e^(- x^2)              ------ */
/* ------------------------------------------------------------------- */

static double q_expx2(double x)
{
    double m, res;
    long int z;
    if (x < 0.0) {
        x = -x;
    }
    z = CUTINT(x);
    m = x - z;
    if (m > 0.5) {
       z = z + 1;
       m = m - 1; /* m <= 0.5 and x = z + m */
    }
    res = q_expz[z] * q_exp(-(z+z)*m) * q_exp(-m*m);
    return z == 27 ? res * q_exp2(-64) : res;
}

/* ------------------------------------------------------------------- */
/* ----                    the function q_erf                   ------ */
/* ------------------------------------------------------------------- */

double q_erf(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_erf);
    } else if (x == q_erft[0]) {
        return 0.0;
    } else if (x < q_erft[0]) {
        return -q_erf(-x);
    } else if (x < q_erft[1]) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_erf); /* underflow */
    } else if (x < q_erft[2]) {
        return x * q_epA2[0];
    } else if (x < q_erft[3]) {
        double x2 = x * x;
        double p = (((q_epA2[4] * x2 + q_epA2[3]) * x2 + q_epA2[2]) * x2 + q_epA2[1]) * x2 + q_epA2[0];
        double q = (((q_eqA2[4] * x2 + q_eqA2[3]) * x2 + q_eqA2[2]) * x2 + q_eqA2[1]) * x2 + q_eqA2[0];
        return x * (p / q);
	  } else if (x < q_erft[4]) {
        double p = (((((q_epB1[6] * x + q_epB1[5]) * x + q_epB1[4]) * x + q_epB1[3]) * x + q_epB1[2]) * x + q_epB1[1]) * x + q_epB1[0];
        double q = (((((q_eqB1[6] * x + q_eqB1[5]) * x + q_eqB1[4]) * x + q_eqB1[3]) * x + q_eqB1[2]) * x + q_eqB1[1]) * x + q_eqB1[0];
        return 1.0 - (q_expx2(x) * (p / q));
    } else if (x < q_erft[5]) {
        double p = ((((q_epB2[5] * x + q_epB2[4]) * x + q_epB2[3]) * x + q_epB2[2]) * x + q_epB2[1]) * x + q_epB2[0];
        double q = (((((q_eqB2[6]* x + q_eqB2[5]) * x + q_eqB2[4]) * x + q_eqB2[3]) * x + q_eqB2[2]) * x + q_eqB2[1])*x+q_eqB2[0];
        return 1.0 - (q_expx2(x) * (p / q));
    } else {
        return 1.0;
  	}
}

/* ------------------------------------------------------------------- */
/* ----                   the function q_erfc                   ------ */
/* ------------------------------------------------------------------- */

double q_erfc(double x)
{
    if NANTEST(x) {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_erfc);
    } else if (x < -q_erft[1]) {
        return 1.0 + q_erf(-x);
    } else if (x < q_erft[1]) {
        return 1.0;
    } else if (x < q_erft[2]) {
        return 1.0 - (x * q_epA2[0]);
    } else if (x < q_erft[3]) {
        double x2 = x * x;
        double p = (((q_epA2[4] * x2 + q_epA2[3]) * x2 + q_epA2[2]) * x2 + q_epA2[1]) * x2 + q_epA2[0];
        double q = (((q_eqA2[4] * x2 + q_eqA2[3]) * x2 + q_eqA2[2]) * x2 + q_eqA2[1]) * x2 + q_eqA2[0];
        return 1.0 - (x * (p / q));
	  } else if (x < q_erft[4]) {
        double p = (((((q_epB1[6] * x + q_epB1[5]) * x + q_epB1[4]) * x + q_epB1[3]) * x + q_epB1[2]) * x + q_epB1[1]) * x + q_epB1[0];
        double q = (((((q_eqB1[6] * x + q_eqB1[5]) * x + q_eqB1[4]) * x + q_eqB1[3]) * x + q_eqB1[2]) * x + q_eqB1[1]) * x + q_eqB1[0];
        return q_expx2(x) * (p / q);
    } else if (x < q_erft[5]) {
        double p =  ((((q_epB2[5] * x + q_epB2[4]) * x + q_epB2[3]) * x + q_epB2[2]) * x + q_epB2[1]) * x + q_epB2[0];
        double q = (((((q_eqB2[6] * x + q_eqB2[5]) * x + q_eqB2[4]) * x + q_eqB2[3]) * x + q_eqB2[2]) * x + q_eqB2[1]) * x + q_eqB2[0];
        return q_expx2(x) * (p / q);
    } else if (x < q_erft[6]) {
        double x2 = x * x;
        double p = (((q_epB3[4] / x2 + q_epB3[3]) / x2 + q_epB3[2]) / x2 + q_epB3[1]) / x2 + q_epB3[0];
        double q = (((q_eqB3[4] / x2 + q_eqB3[3]) / x2 + q_eqB3[2]) / x2 + q_eqB3[1]) / x2 + q_eqB3[0];
        return (q_expx2(x) * p) / (x * q);
    } else {
        return q_abortnan(FI_LIB_INV_ARG, &x, fi_lib_erfc); /* underflow */
	  }
}
