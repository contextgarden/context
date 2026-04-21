/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

void printup(double x)
{  
    if (x == (double) CUTINT(x)) {
        printf("%23.15e",x);
    } else if (fabs(x) > (1e17 - 1) * 1e27) {
        printf("%23.15e",q_succ(q_succ(x)));
    } else {
        printf("%24.15e",q_succ(x));
    }
}

void printdown(double x)
{
    if (x == (double) CUTINT(x)) {
        printf("%23.15e",x);
    } else if (fabs(x) > (1e17 - 1) * 1e27) {
        printf("%24.15e",q_pred(q_pred(x)));
    } else {
        printf("%23.15e",q_pred(x));
    }
}

void printInterval(interval x)
{ 
    printf("[");
    printdown(x.INF);
    printf(",");
    printup(x.SUP);
    printf(" ]");
}