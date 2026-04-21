/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

double q_rtrg(double x, long int k)
{
    a_diee r1, r2;
    if ((-512 < k) && (k < 512)) {
        r2.f = x - k *(q_pih[0] + q_pih[1]);
        return q_r2tr(r2.f,k);
    } else {
        double h;
        r1.f = x - k*q_pih[0];
        h = k * q_pih[1];
        r2.f = r1.f - h;
        if (r1.ieee.expo == r2.ieee.expo ) {
            return r1.f - ( ((((k * q_pih[6] + k * q_pih[5]) + k * q_pih[4])
               + k * q_pih[3]) + k * q_pih[2]) + h );
        } else {
            return q_r2tr(r2.f,k);
        }
    }
}

double q_r2tr(double r, long int k)
{
    double h;
    a_diee r1, r2;
    r2.f = r;
    h = k * q_pih[2];
    r1.f = r2.f - h;
    if (r1.ieee.expo == r2.ieee.expo) {
        return r2.f - ((((k * q_pih[6] + k * q_pih[5]) + k * q_pih[4]) + k * q_pih[3]) + h);
    } else {
        h = k*q_pih[3];
        r2.f = r1.f-h;
        if (r1.ieee.expo == r2.ieee.expo) {
            return r1.f - ( ((k * q_pih[6] + k * q_pih[5]) + k * q_pih[4]) + h);
        } else {
            h = k*q_pih[4];
            r1.f = r2.f-h;
            if (r1.ieee.expo == r2.ieee.expo) {
                return r2.f - ( (k * q_pih[6] + k * q_pih[5]) + h);
            } else {
                h = k * q_pih[5];
                r2.f = r1.f - h;
                if (r1.ieee.expo == r2.ieee.expo ) {
                    return r1.f - (k*q_pih[6] + h);
                } else {
                    return r2.f - k*q_pih[6];
                }
            }
        }
    }
}