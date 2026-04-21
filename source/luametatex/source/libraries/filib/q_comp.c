/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* ------------------------------------------------------------------- */
/* --- utilities                                                   --- */
/* ------------------------------------------------------------------- */

double q_comp(int s, double m, int e)
{
    a_diee su;
    if (! ((s == 1) || (s == -1))) {
        m = s;
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_comp);
    } else if ((e < -1023) || (e > 1024)) {
        m = e;
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_comp);
    } else if ((m < 0) || (m >= 2)) {
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_comp);
    } else if ((e != -1023) && (m < 1)) {
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_comp);
    } else {
        if (e == -1023) {
            m += 1; /* hidden-bit */
        }
        su.f = m;
        su.ieee.sign = s == 1 ? 0 : 1;
        su.ieee.expo = e + 1023;
        return su.f;
    }
}

double q_cmps(double m, int e)
{
    a_diee su;
    if ((e < -1023) || (e > 1024)) {
        m = e;
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_cmps);
    }
    if ((m <= -2) || (m >= 2)) {
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_cmps);
    }
    if ((e != -1023) && (m < 1) && (m > -1)) {
        return q_abortr1(FI_LIB_INV_ARG, &m, fi_lib_cmps);
    }
    if (e == -1023) {
        if (m >= 0) {
            m += 1;
        } else {
            m -= 1;
        }
    }
    su.f = m;
    su.ieee.expo = e + 1023;
    return su.f;
}

int q_sign(double x)
{
    a_diee su;
    su.f = x;
    return su.ieee.sign == 0 ? 1 : -1;
}

double q_mant(double x)
{
    a_diee su;
    su.f = x;
    su.ieee.sign = 0;
    su.ieee.expo = 1023;
    if ((-q_minr < x) && (x < q_minr)) {
      su.f -= 1; /* no hidden-bit */
    }
    return su.f;
}

double q_mnts(double x)
{
    a_diee su;
    su.f = x;
    su.ieee.expo = 1023;
    if ((0 <= x) && (x < q_minr)) {
        su.f -= 1; /* no hidden-bit */
    }
    if ((-q_minr < x) && (x < 0)) {
        su.f += 1; /* no hidden-bit */
    }
    return su.f;
}

int q_expo(double x)
{
    a_diee su;
    su.f = x;
    return su.ieee.expo - 1023;
}