/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/* ------------------------------------------------------------------- */
/* --- predeccessor of a double value                              --- */
/* ------------------------------------------------------------------- */

double q_pred(double y)
{
    a_diee su;
    su.f=y;
    if (su.ieee.sign == 1) {
        /*  y < 0 */
        if (su.ieee.expo == 2047 && su.ieee.mant0 == 0 && su.ieee.mant1 == 0) {
            su.f = su.f;
        } else if (su.ieee.mant1 == 0xffffffff) {
            su.ieee.mant1 = 0;
            if (su.ieee.mant0 == 1048575) {
                su.ieee.mant0 = 0;
                su.ieee.expo++;
            } else {
                su.ieee.mant0++;
            }
        } else {
          su.ieee.mant1++;
        }
    } else {
        /* y >= 0 */
        if (su.ieee.expo == 2047 && su.ieee.mant0 == 0 && su.ieee.mant1 == 0) {
            su.f=su.f;
        } else if (su.ieee.sign == 0 && su.ieee.expo == 0 && su.ieee.mant0 == 0 && su.ieee.mant1 == 0) {
            su.ieee.sign = 1;
            su.ieee.mant1 = 1;
        } else if (su.ieee.mant1 == 0) {
            su.ieee.mant1 = 0xffffffff;
            if (su.ieee.mant0 == 0) {
                su.ieee.mant0 = 1048575;
                su.ieee.expo--;
            } else {
                su.ieee.mant0--;
            }
        } else {
            su.ieee.mant1--;
        }
    }
    return su.f;
}