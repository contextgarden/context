/*********************************************************************/
/*                                                                   */
/* I reformatted the code a bit to get rid of some (indentation)     */
/* related warnings. Because I have to adapt error messaging to suit */
/* the Lua (and mp) interfacing I will also assume a modern compiler */
/* so the prototyping will go away anyway (was needed around 2005).  */
/* It is anyway nice and clean code. All errors introduced in doing  */
/* this are of course mine. (Hans Hagen)                             */
/*                                                                   */
/* -- fixed & into &&                                                */
/* -- prototypes removed                                             */
/* -- use return values iun some helpers                             */
/* -- flatten conditions (and indent for readability)                */
/* -- try to figure out little endian differently                    */
/* -- replace error reporting and adding a callback option           */
/* -- use a more symbolic approach when doing so                     */
/* -- collapsed top comment lines in files to save bytes             */
/* 																	 */
/* Going over the code is actually a nice way to see what happens    */
/* with these intervals.      										 */
/* 																	 */
/* I kept the relavant comments and such. I made a few functions     */
/* static and did s little cleanup but kept all the logic.           */
/*                                                                   */
/*********************************************************************/

# ifndef FILIB_H
# define FILIB_H

/*********************************************************************/
/*                                                                   */
/*   fi_lib  --- A fast interval library (Version 1.2)               */
/*                                                                   */
/*  Authors:                                                         */
/*  --------                                                         */
/*  Werner Hofschuster, Walter Kraemer                               */
/*  Wissenschaftliches Rechnen/Softwaretechnologie                   */
/*  Universitaet Wuppertal, Germany                                  */
/*                                                                   */
/*  Copyright:                                                       */
/*  ----------                                                       */
/*  Copyright (C) 1997-2000 Institut fuer Wissenschaftliches Rechnen */
/*                          und Mathematische Modellbildung (IWRMM)  */
/*                                           and                     */
/*                          Institut fuer Angewandte Mathematik      */
/*                          Universitaet Karlsruhe, Germany          */
/*            (C) 2000-2005 Wiss. Rechnen/Softwaretechnologie        */
/*                          Universitaet Wuppertal, Germany          */
/*                                                                   */
/*  This library is free software; you can redistribute it and/or    */
/*  modify it under the terms of the GNU Library General Public      */
/*  License as published by the Free Software Foundation; either     */
/*  version 2 of the License, or (at your option) any later version. */
/*                                                                   */
/*  This library is distributed in the hope that it will be useful,  */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of   */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.             */
/*  See the GNU Library General Public License for more details.     */
/*                                                                   */
/*  You should have received a copy of the GNU Library General Public*/
/*  License along with this library; if not, write to the Free       */
/*  Foundation, Inc., 59 Temple Place, Suite 330, Boston,            */
/*  MA  02111-1307  USA                                              */
/*                                                                   */
/*********************************************************************/

# include <stdio.h>
# include <math.h>
# include <float.h>

/*********************************************************************/
/*                    CONFIGURE FI_LIB.H here !!!                    */
/*********************************************************************/

// #define INTEL 1   /* Version for PC ("little endian") must have 1,*/
//                   /* otherwise ("big endian") 0                   */

# if defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__)
    # if (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
        # define FI_LIB_USEDENDIAN 1
    # else
        # define FI_LIB_USEDENDIAN 0
    # endif
# elif defined(BYTE_ORDER) && defined(LITTLE_ENDIAN)
    # if (BYTE_ORDER == LITTLE_ENDIAN)
        # define FI_LIB_USEDENDIAN 1
    # else
        # define FI_LIB_USEDENDIAN 0
    # endif
# else
    /* we assume little endian */
    # define FI_LIB_USEDENDIAN 2
# endif

/*********************************************************************/
/*                     end of configuring section                    */
/*********************************************************************/

/*********************************************************************/
/* Interval data type                                                */
/*********************************************************************/

typedef struct interval {
	double INF;
	double SUP;
} interval ;

/*********************************************************************/
/* preprocessing (global changes)                                    */
/*********************************************************************/

# define r_succ(params) q_succ(params)
# define r_pred(params) q_pred(params)

/*********************************************************************/
/* replacement for function ldexp from math.h (libm.a)               */
/*********************************************************************/

/* only for normalised numbers ! */

# define POWER2(x,k) {if (x!=0) {a_diee *test=(a_diee *) &x; test->ieee.expo+=k;}}

/*********************************************************************/
/* replacement for function frexp from math.h (libm.a)               */
/*********************************************************************/

/* only for normalised numbers ! */

# define FREXPO(x,k) {if (x!=0) {a_diee *test=(a_diee *) &x; k=test->ieee.expo;} else k=0;}

/*********************************************************************/
/* first 24 bits of a double value ( cut / round )                   */
/*********************************************************************/

# define CUT24(x) (float)(x)

/*********************************************************************/
/* assignment double -> long int                                     */
/*********************************************************************/

# define CUTINT(x) (int)(x)

/*********************************************************************/
/* data type union to access sign, mantisse, exponent                */
/*********************************************************************/

typedef union {
	double f;
	struct {
// # if INTEL
# if (FI_LIB_USEDENDIAN > 0)
		unsigned int mant1 :32;
		unsigned int mant0 :20;
		unsigned int expo  :11;
		unsigned int sign  : 1;
# else
		unsigned int sign  : 1;
		unsigned int expo  :11;
		unsigned int mant0 :20;
		unsigned int mant1 :32;
# endif
	} ieee;
} a_diee;

/*********************************************************************/
/* NAN (not a number) test                                           */
/*********************************************************************/

# define NANTEST(x) ((x!=x))

/*********************************************************************/
/* error handling                                                    */
/*********************************************************************/

typedef enum fi_lib_exit_codes {
    FI_LIB_INV_ARG   = 1, /* error handling: invalid argument */
    FI_LIB_OVER_FLOW = 2, /* error handling: overflow         */
    FI_LIB_DIV_ZERO  = 3, /* error handling: division by zero */
} fi_lib_exit_codes;

/*********************************************************************/
/* constants for the elementary functions                            */
/*********************************************************************/

extern double q_ln2h;
extern double q_l10i;
extern double q_l2i;
extern double q_l10;
extern double q_l2;
extern double q_p2h;
extern double q_p2mh;
extern double q_mine;
extern double q_minr;
extern double q_pi;
extern double q_piha;
extern double q_pih[7];
extern double q_pi2i;
extern double q_pi2p[3];
extern double q_sqra;
extern double q_ctht;

extern double q_ext1;
extern double q_ext2;
extern double q_ex2a;
extern double q_ex2b;
extern double q_ex2c;
extern double q_ext3;
extern double q_ext4;
extern double q_ext5;
extern double q_extm;
extern double q_extn;
extern double q_exil;
extern double q_exl1;
extern double q_exl2;
extern double q_e10i;
extern double q_e1l1;
extern double q_e1l2;
extern double q_exa[5];
extern double q_exb[9];
extern double q_exc[7];
extern double q_exd[7];
extern double q_exld[32];
extern double q_extl[32];

extern double q_exem;
extern double q_exep;
extern double q_exmm;
extern double q_exmp;

extern double q_snhm;
extern double q_snhp;
extern double q_cshm;
extern double q_cshp;
extern double q_cthm;
extern double q_cthp;
extern double q_tnhm;
extern double q_tnhp;

extern double q_lgt1;
extern double q_lgt2;
extern double q_lgt3;
extern double q_lgt4;
extern double q_lgt5;
extern double q_lgt6;
extern double q_lgb[2];
extern double q_lgc[4];
extern double q_lgld[129];
extern double q_lgtl[129];

extern double q_logm;
extern double q_logp;
extern double q_lgpm;
extern double q_lgpp;
extern double q_sqtm;
extern double q_sqtp;

extern double q_atna[7];
extern double q_atnb[8];
extern double q_atnc[7];
extern double q_atnd[6];
extern double q_atnt;

extern double q_asnm;
extern double q_asnp;
extern double q_acsm;
extern double q_acsp;
extern double q_actm;
extern double q_actp;
extern double q_atnm;
extern double q_atnp;

extern double q_csnm;
extern double q_csnp;
extern double q_ccsm;
extern double q_ccsp;
extern double q_cctm;
extern double q_cctp;
extern double q_ctnm;
extern double q_ctnp;

extern double q_sinc[6];
extern double q_sins[6];
extern double q_sint[5];

extern double q_sinm;
extern double q_sinp;
extern double q_cosm;
extern double q_cosp;
extern double q_cotm;
extern double q_cotp;
extern double q_tanm;
extern double q_tanp;

extern double q_lg2m;
extern double q_lg2p;
extern double q_l10m;
extern double q_l10p;
extern double q_e2em;
extern double q_e2ep;
extern double q_e10m;
extern double q_e10p;

extern double q_at3i;

extern double q_erfm;
extern double q_erfp;
extern double q_efcm;
extern double q_efcp;
extern double q_expz[28];
extern double q_epA2[5];
extern double q_eqA2[5];
extern double q_epB1[7];
extern double q_eqB1[7];
extern double q_epB2[6];
extern double q_eqB2[7];
extern double q_epB3[5];
extern double q_eqB3[5];
extern double q_erft[7];

/*********************************************************************/
/* prototypes for interval arithmetic (basic operations)             */
/*********************************************************************/

double   q_min  (double x,double y);
double   q_max  (double x,double y);
double   q_abs  (double x);
interval j_abs  (interval x);
interval add_ii (interval x, interval y);
interval add_di (double x, interval y);
interval add_id (interval x, double y);
interval sub_ii (interval x, interval y);
interval sub_id (interval x, double y);
interval sub_di (double x, interval y);
interval eq_ii  (interval y);
interval eq_id  (double y);
interval mul_ii (interval x, interval y);
interval mul_id (interval x, double y);
interval mul_di (double x, interval y);
interval div_ii (interval x, interval y);
interval div_di (double x, interval y);
interval div_id (interval x, double y);
int      in_di  (double x, interval y);
int      in_ii  (interval x, interval y);
int      ieq_ii (interval x, interval y); // eq
int      is_ii  (interval x, interval y); // lt
int      ig_ii  (interval x, interval y); // gt
int      ise_ii (interval x, interval y); // le
int      ige_ii (interval x, interval y); // ge
int      dis_ii (interval x, interval y);
double   q_mid  (interval x);
interval hull   (interval x, interval y);
interval intsec (interval x, interval y);
double   q_diam (interval x);

//define ieq_ii ieq_ii
# define ilt_ii is_ii
# define igt_ii ig_ii
# define ile_ii ise_ii
//define ige_ii ige_ii

/*********************************************************************/
/* functions for internal use only                                   */
/*********************************************************************/

double   q_abortr1    (int n, double *x, int fctn);
interval q_abortr2    (int n, double *x1, double *x2, int fctn);
double   q_abortnan   (int n, double *x, int fctn);
double   q_abortdivd  (int n, double *x);
interval q_abortdivi  (int n, double *x1, double *x2);

int      q_usedendian (void);    /* added to the error messages file */
void     q_usehandler (void *f); /* added to the error messages file */

double   q_ep1        (double x);
double   q_epm1       (double x);
double   q_cth1       (double x);
double   q_log1       (double x);
double   q_l1p1       (double x);
double   q_atn1       (double x);
double   q_sin1       (double x, long int k);
double   q_cos1       (double x, long int k);
double   q_rtrg       (double x, long int k);
double   q_r2tr       (double r, long int k);

/*********************************************************************/
/* functions for IO                                                  */
/*********************************************************************/

double   scandown      (void);
double   scanup        (void);
interval scanInterval  (void);

void     printdown     (double x);
void     printup       (double x);
void     printInterval (interval x);

/*********************************************************************/
/* library functions                                                 */
/*********************************************************************/

double   q_sqr  (double x);
double   q_sqrt (double x);
double   q_exp  (double x);
double   q_expm (double x);
double   q_sinh (double x);
double   q_cosh (double x);
double   q_coth (double x);
double   q_tanh (double x);
double   q_log  (double x);
double   q_lg1p (double x);
double   q_asnh (double x);
double   q_acsh (double x);
double   q_acth (double x);
double   q_atnh (double x);
double   q_asin (double x);
double   q_acos (double x);
double   q_acot (double x);
double   q_atan (double x);
double   q_sin  (double x);
double   q_cos  (double x);
double   q_cot  (double x);
double   q_tan  (double x);
double   q_exp2 (double x);
double   q_ex10 (double x);
double   q_log2 (double x);
double   q_lg10 (double x);
double   q_erf  (double x);
double   q_erfc (double x);

double   q_pred (double x);
double   q_succ (double x);
double   q_comp (int s, double m, int e);
double   q_cmps (double m, int e);
int      q_sign (double x);
double   q_mant (double x);
double   q_mnts (double x);
int      q_expo (double x);

interval j_exp  (interval x);
interval j_expm (interval x);
interval j_sinh (interval x);
interval j_cosh (interval x);
interval j_coth (interval x);
interval j_tanh (interval x);
interval j_log  (interval x);
interval j_lg1p (interval x);
interval j_sqrt (interval x);
interval j_sqr  (interval x);
interval j_asnh (interval x);
interval j_acsh (interval x);
interval j_acth (interval x);
interval j_atnh (interval x);
interval j_asin (interval x);
interval j_acos (interval x);
interval j_acot (interval x);
interval j_atan (interval x);
interval j_sin  (interval x);
interval j_cos  (interval x);
interval j_cot  (interval x);
interval j_tan  (interval x);
interval j_exp2 (interval x);
interval j_ex10 (interval x);
interval j_log2 (interval x);
interval j_lg10 (interval x);
interval j_erf  (interval x);
interval j_erfc (interval x);

/*
    We have abstracted the message function references and in the process catched a
    few 'errors'. (HH)
*/

typedef enum fi_lib_functions {
    fi_lib_acos,
    fi_lib_acot,
    fi_lib_acsh,
    fi_lib_acth,
    fi_lib_asin,
    fi_lib_asnh,
    fi_lib_atan,
    fi_lib_atnh,
    fi_lib_cmps,
    fi_lib_comp,
    fi_lib_cos,
    fi_lib_cos1,
    fi_lib_cosh,
    fi_lib_cot,
    fi_lib_coth,
    fi_lib_ep1,
    fi_lib_epm1,
    fi_lib_erf,
    fi_lib_erfc,
    fi_lib_ex10,
    fi_lib_exp,
    fi_lib_exp2,
    fi_lib_expm,
    fi_lib_l1p1,
    fi_lib_lg10,
    fi_lib_lg1p,
    fi_lib_log,
    fi_lib_log1,
    fi_lib_log2,
    fi_lib_sin,
    fi_lib_sin1,
    fi_lib_sinh,
    fi_lib_sqr,
    fi_lib_sqrt,
    fi_lib_tan,
    fi_lib_tanh,
    /* */
    fi_lib_div_id,
    /* */
    fi_lib_last,
} fi_lib_functions;

typedef enum fi_lib_errors {
    fi_lib_error_nan,
    fi_lib_error_overflow_double,
    fi_lib_error_overflow_interval,
    fi_lib_error_invalid_double,
    fi_lib_error_invalid_interval,
    fi_lib_error_zero_division_double,
    fi_lib_error_zero_division_interval,
} fi_lib_errors;

# endif
