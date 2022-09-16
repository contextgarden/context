% This file is part of MetaPost. The MetaPost program is in the public domain.

@ Introduction.

@c
# include "mpconfig.h"
# include "mpmathdecimal.h"

# define  DECNUMDIGITS 1000
# include "decNumber.h"

@h

@ @c
@<Declarations@>

@ @(mpmathdecimal.h@>=
# ifndef MPMATHDECIMAL_H
# define MPMATHDECIMAL_H 1

# include "mp.h"

math_data *mp_initialize_decimal_math (MP mp);

# endif

@* Math initialization.

First, here are some very important constants.

@d E_STRING                "2.7182818284590452353602874713526624977572470936999595749669676277240766303535"
@d PI_STRING               "3.1415926535897932384626433832795028841971693993751058209749445923078164062862"
@d fraction_multiplier     4096
@d angle_multiplier        16

@d unity                   1
@d two                     2
@d three                   3
@d four                    4
@d half_unit               0.5
@d three_quarter_unit      0.75
@d coef_bound              ((7.0/3.0)*fraction_multiplier) /* |fraction| approximation to 7/3 */
@d fraction_threshold      0.04096                         /* a |fraction| coefficient less than this is zeroed */
@d half_fraction_threshold (fraction_threshold/2)          /* half of |fraction_threshold| */
@d scaled_threshold        0.000122                        /* a |scaled| coefficient less than this is zeroed */
@d half_scaled_threshold   (scaled_threshold/2)            /* half of |scaled_threshold| */
@d near_zero_angle         (0.0256*angle_multiplier)       /* an angle of about 0.0256 */
@d p_over_v_threshold      0x80000                         /* TODO */
@d equation_threshold      0.001
@d epsilon                 pow(2.0,-173.0)                 /* almost "1E-52" */
@d epsilonf                pow(2.0,-52.0)
@d EL_GORDO                "1E1000000"                     /* the largest value that \MP\ likes. */
@d negative_EL_GORDO       "-1E1000000"                    /* the largest value that \MP\ likes. */
@d warning_limit           "1E1000000"                     /* this is a large value that can just be expressed without loss of precision */

@d DECPRECISION_DEFAULT    34
@d FACTORIALS_CACHESIZE    50

@d too_precise(a)          (a == (DEC_Inexact+DEC_Rounded))
@d too_large(a)            (a & DEC_Overflow)

@d fraction_half           (fraction_multiplier/2)
@d fraction_one            (1*fraction_multiplier)
@d fraction_two            (2*fraction_multiplier)
@d fraction_three          (3*fraction_multiplier)
@d fraction_four           (4*fraction_multiplier)

@d no_crossing             mp_decimal_data.fraction_one_plus_decNumber
@d one_crossing            mp_decimal_data.fraction_one_decNumber
@d zero_crossing           mp_decimal_data.zero

@d odd(A)                  (abs(A) % 2 == 1)
@d set_cur_cmd(A)          mp->cur_mod_->type = (A)
@d set_cur_mod(A)          decNumberCopy((decNumber *) (mp->cur_mod_->data.n.data.num), A)

@ This one saves some typing and also looks better:

@d decNumberIsPositive(A)  (! (decNumberIsZero(A) || decNumberIsNegative(A)))

@ Here are the functions that are static as they are not used elsewhere.

@<Declarations@>=
static int    mp_ab_vs_cd                         (mp_number *a, mp_number *b, mp_number *c, mp_number *d);
static void   mp_allocate_abs                     (MP mp, mp_number *n, mp_number_type t, mp_number *v);
static void   mp_allocate_clone                   (MP mp, mp_number *n, mp_number_type t, mp_number *v);
static void   mp_allocate_double                  (MP mp, mp_number *n, double v);
static void   mp_allocate_number                  (MP mp, mp_number *n, mp_number_type t);
static void   mp_decnumber_check                  (MP mp, decNumber *dec, decContext *context);
static void   mp_decimal_abs                      (mp_number *A);
static void   mp_decimal_crossing_point           (MP mp, mp_number *ret, mp_number *a, mp_number *b, mp_number *c);
static void   mp_decimal_fraction_to_round_scaled (mp_number *x);
static void   mp_decimal_m_exp                    (MP mp, mp_number *ret, mp_number *x_orig);
static void   mp_decimal_m_log                    (MP mp, mp_number *ret, mp_number *x_orig);
static void   mp_decimal_m_norm_rand              (MP mp, mp_number *ret);
static void   mp_decimal_m_unif_rand              (MP mp, mp_number *ret, mp_number *x_orig);
void          mp_decimal_make_fraction            (MP mp, decNumber *ret, decNumber *p, decNumber *q);
static void   mp_decimal_n_arg                    (MP mp, mp_number *ret, mp_number *x, mp_number *y);
static void   mp_decimal_number_make_fraction     (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_decimal_number_make_scaled       (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_decimal_number_modulo            (mp_number *a, mp_number *b);
static void   mp_decimal_number_take_fraction     (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_decimal_number_take_scaled       (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_decimal_power_of                 (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void   mp_decimal_print_number             (MP mp, mp_number *n);
static void   mp_decimal_pyth_add                 (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void   mp_decimal_pyth_sub                 (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void   mp_decimal_scan_fractional_token    (MP mp, int n);
static void   mp_decimal_scan_numeric_token       (MP mp, int n);
static void   mp_decimal_set_precision            (MP mp);
static void   mp_decimal_sin_cos                  (MP mp, mp_number *z_orig, mp_number *n_cos, mp_number *n_sin);
static void   mp_decimal_slow_add                 (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig);
static void   mp_decimal_square_rt                (MP mp, mp_number *ret, mp_number *x_orig);
void          mp_decimal_take_fraction            (MP mp, decNumber *ret, decNumber *p, decNumber *q);
static void   mp_decimal_velocity                 (MP mp, mp_number *ret, mp_number *st, mp_number *ct, mp_number *sf,  mp_number *cf, mp_number *t);
static void   mp_free_decimal_math                (MP mp);
static void   mp_free_number                      (MP mp, mp_number *n);
static void   mp_init_randoms                     (MP mp, int seed);
static void   mp_number_abs_clone                 (mp_number *A, mp_number *B);
static void   mp_number_add                       (mp_number *A, mp_number *B);
static void   mp_number_add_scaled                (mp_number *A, int B); /* also for negative B */
static void   mp_number_angle_to_scaled           (mp_number *A);
static void   mp_number_clone                     (mp_number *A, mp_number *B);
static void   mp_number_divide_int                (mp_number *A, int B);
static void   mp_number_double                    (mp_number *A);
static int    mp_number_equal                     (mp_number *A, mp_number *B);
static void   mp_number_floor                     (mp_number *i);
static void   mp_number_fraction_to_scaled        (mp_number *A);
static int    mp_number_greater                   (mp_number *A, mp_number *B);
static void   mp_number_half                      (mp_number *A);
static int    mp_number_less                      (mp_number *A, mp_number *B);
static void   mp_number_multiply_int              (mp_number *A, int B);
static void   mp_number_negate                    (mp_number *A);
static void   mp_number_negated_clone             (mp_number *A, mp_number *B);
static int    mp_number_nonequalabs               (mp_number *A, mp_number *B);
static int    mp_number_odd                       (mp_number *A);
static void   mp_number_scaled_to_angle           (mp_number *A);
static void   mp_number_scaled_to_fraction        (mp_number *A);
static void   mp_number_subtract                  (mp_number *A, mp_number *B);
static void   mp_number_swap                      (mp_number *A, mp_number *B);
static int    mp_number_to_boolean                (mp_number *A);
static double mp_number_to_double                 (mp_number *A);
static int    mp_number_to_int                    (mp_number *A);
static int    mp_number_to_scaled                 (mp_number *A);
static int    mp_round_unscaled                   (mp_number *x_orig);
static void   mp_set_decimal_from_addition        (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_decimal_from_boolean         (mp_number *A, int B);
static void   mp_set_decimal_from_div             (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_decimal_from_double          (mp_number *A, double B);
static void   mp_set_decimal_from_int             (mp_number *A, int B);
static void   mp_set_decimal_from_int_div         (mp_number *A, mp_number *B, int C);
static void   mp_set_decimal_from_int_mul         (mp_number *A, mp_number *B, int C);
static void   mp_set_decimal_from_mul             (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_decimal_from_of_the_way      (MP mp, mp_number *A, mp_number *t, mp_number *B, mp_number *C);
static void   mp_set_decimal_from_scaled          (mp_number *A, int B);
static void   mp_set_decimal_from_subtraction     (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_decimal_half_from_addition   (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_decimal_half_from_subtraction(mp_number *A, mp_number *B, mp_number *C);
static void   mp_wrapup_numeric_token             (MP mp, unsigned char *start, unsigned char *stop);
static char  *mp_decimal_number_tostring          (MP mp, mp_number *n);
static char  *mp_decnumber_tostring               (decNumber *n);

@ We do not want special numbers as return values for functions, so:

@c
void mp_decnumber_check(MP mp, decNumber *dec, decContext *context)
{
    int test = 0;
    (void) mp;
    if (context->status & DEC_Overflow) {
        test = 1;
        context->status &= ~DEC_Overflow;
    }
    if (context->status & DEC_Underflow) {
        test = 1;
        context->status &= ~DEC_Underflow;
    }
    if (context->status & DEC_Errors) {
        test = 1;
        decNumberZero(dec);
    }
    context->status = 0;
    if (decNumberIsSpecial(dec)) {
        test = 1;
        if (decNumberIsInfinite(dec)) {
            if (decNumberIsNegative(dec)) {
                decNumberCopyNegate(dec, &mp_decimal_data.EL_GORDO_decNumber);
            } else {
                decNumberCopy(dec, &mp_decimal_data.EL_GORDO_decNumber);
            }
        } else {
            /* Nan */
            decNumberZero(dec);
        }
    }
    if (decNumberIsZero(dec) && decNumberIsNegative(dec)) {
        decNumberZero(dec);
    }
    mp->arith_error = test;
}

@<Declarations@>=
typedef struct mp_decimal_info {
    decContext  set;
    decContext  limitedset;
    decNumber   zero;
    decNumber   one;
    decNumber   minusone;
    decNumber   two_decNumber;
    decNumber   three_decNumber;
    decNumber   four_decNumber;
    decNumber   fraction_multiplier_decNumber;
    decNumber   angle_multiplier_decNumber;
    decNumber   fraction_one_decNumber;
    decNumber   fraction_one_plus_decNumber;
    decNumber   PI_decNumber;
    decNumber   epsilon_decNumber;
    decNumber   EL_GORDO_decNumber;
    decNumber   negative_EL_GORDO_decNumber;
    decNumber **factorials;
    int         last_cached_factorial;
    int         initialized;
} mp_decimal_info;

mp_decimal_info mp_decimal_data = {
    .factorials            = NULL,
    .last_cached_factorial = 0,
    .initialized           = 0,
};

static void checkZero(decNumber *ret)
{
    if (decNumberIsZero(ret) && decNumberIsNegative(ret)) {
        decNumberZero(ret);
    }
}

static int decNumberLess(decNumber *a, decNumber *b)
{
    decNumber comp;
    decNumberCompare(&comp, a, b, &mp_decimal_data.set);
    return decNumberIsNegative(&comp);
}

static int decNumberGreater(decNumber *a, decNumber *b)
{
    decNumber comp;
    decNumberCompare(&comp, a, b, &mp_decimal_data.set);
    return decNumberIsPositive(&comp);
}

static void decNumberFromDouble(decNumber *A, double B)
{
    char buffer[1000];
    char *c = buffer;
    snprintf(buffer, 1000, "%-650.325lf", B);
    while (*c++) {
        if (*c == ' ') {
            *c = '\0';
            break;
        }
    }
    decNumberFromString(A, buffer, &mp_decimal_data.set);
}

static double decNumberToDouble(decNumber *A)
{
    char *buffer = mp_memory_allocate(A->digits + 14);
    double res = 0.0;
    decNumberToString(A, buffer);
    if (sscanf(buffer, "%lf", &res)) {
        mp_memory_free(buffer);
        return res;
    } else {
        mp_memory_free(buffer);
        /* |mp->arith_error = 1;| */
        return 0.0;
    }
}

@ Borrowed code from libdfp:

$$ \arctan(x) = x - \frac {x^3}{3} + \frac {x^5{5} - \frac {x^7}{7} + \ldots$$

This power series works well, if $x$ is close to zero ($|x|<0.5$). If x is
larger, the series converges too slowly, so in order to get a smaller x, we apply
the identity

$$ \arctan(x) = 2 \arctan \left (\frac {\sqrt{1 + x^2}-1} {x} \right) $$

twice. The first application gives us a new $x$ with $x < 1$. The second
application gives us a new x with $x < 0.4142136$. For that $x$, we use the power
series and multiply the result by four.

@c
static void decNumberAtan(decNumber *result, decNumber *x_orig, decContext *localset)
{
    decNumber x;
    decNumberCopy(&x, x_orig);
    if (decNumberIsZero(&x)) {
        decNumberCopy(result, &x);
    } else {
        decNumber f, g, mx2, term;
        for (int i = 0; i<2; i++) {
            decNumber y;
            decNumberMultiply(&y, &x, &x, localset);                   /* $ y = x^2     $ */
            decNumberAdd(&y, &y, &mp_decimal_data.one, localset);      /* $ y = y + 1   $ */
            decNumberSquareRoot(&y, &y, localset);                     /* $ y = sqrt(y) $ */
            decNumberSubtract(&y, &y, &mp_decimal_data.one, localset); /* $ y = y - 1   $ */
            decNumberDivide(&x, &y, &x, localset);                     /* $ x = y / x   $ */
            if (decNumberIsZero(&x)) {
                decNumberCopy(result, &x);
                return;
            }
        }
        decNumberCopy(&f, &x);                     /* $ f(0) =  x   $ */
        decNumberCopy(&g, &mp_decimal_data.one);   /* $ g(0) =  1   $ */
        decNumberCopy(&term, &x);                  /* $ term =  x   $ */
        decNumberCopy(result, &x);                 /* $ sum  =  x   $ */
        decNumberMultiply(&mx2, &x, &x, localset); /* $ mx2  =  x^2 $ */
        decNumberMinus (&mx2, &mx2, localset);     /* $ mx2  = -x^2 $ */
        for (int i = 0; i < 2 * localset->digits; i++) {
            decNumberMultiply(&f, &f, &mx2, localset);
            decNumberAdd(&g, &g, &mp_decimal_data.two_decNumber, localset);
            decNumberDivide(&term, &f, &g, localset);
            decNumberAdd(result, result, &term, localset);
        }
        decNumberAdd(result, result, result, localset);
        decNumberAdd(result, result, result, localset);
    }
}

static void decNumberAtan2(decNumber *result, decNumber *y, decNumber *x, decContext *localset)
{
    if (! decNumberIsInfinite(x) && ! decNumberIsZero(y) && ! decNumberIsInfinite(y) && ! decNumberIsZero(x)) {
        decNumber temp;
        decNumberDivide(&temp, y, x, localset);
        decNumberAtan(result, &temp, localset);
        /*
            decNumberAtan doesn't quite return the values in the ranges we
            want for x < 0. So we need to do some correction
        */
        if (decNumberIsNegative(x)) {
            if (decNumberIsNegative(y)) {
                decNumberSubtract(result, result, &mp_decimal_data.PI_decNumber, localset);
            } else {
                decNumberAdd(result, result, &mp_decimal_data.PI_decNumber, localset);
            }
        }
    } else {
        if (decNumberIsInfinite(y) && decNumberIsInfinite(x)) {
            /* If x and y are both inf, the result depends on the sign of x */
            decNumberDivide(result, &mp_decimal_data.PI_decNumber, &mp_decimal_data.four_decNumber, localset);
            if (decNumberIsNegative(x) ) {
                decNumber a;
                decNumberFromDouble(&a, 3.0);
                decNumberMultiply(result, result, &a, localset);
            }
        } else if (!decNumberIsZero(y) && !decNumberIsInfinite(x) ) {
            /* If y is non-zero and x is non-inf, the result is +-pi/2 */
            decNumberDivide(result, &mp_decimal_data.PI_decNumber, &mp_decimal_data.two_decNumber, localset);
        } else {
            /* Otherwise it is +0 if x is positive, +pi if x is neg */
            if (decNumberIsNegative(x)) {
                decNumberCopy(result, &mp_decimal_data.PI_decNumber);
            } else {
                decNumberZero(result);
            }
        }
        /* Atan2 will be negative if y < 0 */
        if (decNumberIsNegative(y)) {
            decNumberMinus(result, result, localset);
        }
    }
}

@ @c
math_data *mp_initialize_decimal_math (MP mp)
{
    math_data *math = (math_data *) mp_memory_allocate(sizeof(math_data));
    decContextDefault(&mp_decimal_data.set, DEC_INIT_BASE);        /* initialize */
    mp_decimal_data.set.traps = 0;                                 /* no traps, thank you */
    decContextDefault(&mp_decimal_data.limitedset, DEC_INIT_BASE); /* initialize */
    mp_decimal_data.limitedset.traps = 0;                          /* no traps, thank you */
    mp_decimal_data.limitedset.emax = 999999;
    mp_decimal_data.limitedset.emin = -999999;
    mp_decimal_data.set.digits = DECPRECISION_DEFAULT;
    mp_decimal_data.limitedset.digits = DECPRECISION_DEFAULT;
    if (! mp_decimal_data.initialized) {
        mp_decimal_data.initialized = 1 ;
        decNumberFromInt32(&mp_decimal_data.one, 1);
        decNumberFromInt32(&mp_decimal_data.minusone, -1);
        decNumberFromInt32(&mp_decimal_data.zero, 0);
        decNumberFromInt32(&mp_decimal_data.two_decNumber, two);
        decNumberFromInt32(&mp_decimal_data.three_decNumber, three);
        decNumberFromInt32(&mp_decimal_data.four_decNumber, four);
        decNumberFromInt32(&mp_decimal_data.fraction_multiplier_decNumber, fraction_multiplier);
        decNumberFromInt32(&mp_decimal_data.fraction_one_decNumber, fraction_one);
        decNumberFromInt32(&mp_decimal_data.fraction_one_plus_decNumber, (fraction_one+1));
        decNumberFromInt32(&mp_decimal_data.angle_multiplier_decNumber, angle_multiplier);
        decNumberFromString(&mp_decimal_data.PI_decNumber, PI_STRING, &mp_decimal_data.set);
        decNumberFromDouble(&mp_decimal_data.epsilon_decNumber, epsilon);
        decNumberFromString(&mp_decimal_data.EL_GORDO_decNumber, EL_GORDO, &mp_decimal_data.set);
        decNumberFromString(&mp_decimal_data.negative_EL_GORDO_decNumber, negative_EL_GORDO, &mp_decimal_data.set);
        mp_decimal_data.factorials = (decNumber **) mp_memory_allocate(FACTORIALS_CACHESIZE * sizeof(decNumber *));
        mp_decimal_data.factorials[0] = (decNumber *) mp_memory_allocate(sizeof(decNumber));
        decNumberCopy(mp_decimal_data.factorials[0], &mp_decimal_data.one);
    }
    math->md_allocate        = mp_allocate_number;
    math->md_free            = mp_free_number;
    math->md_allocate_clone  = mp_allocate_clone;
    math->md_allocate_abs    = mp_allocate_abs;
    math->md_allocate_double = mp_allocate_double;
    mp_allocate_number(mp, &math->md_precision_default, mp_scaled_type);
    decNumberFromInt32(     math->md_precision_default.data.num, DECPRECISION_DEFAULT);
    mp_allocate_number(mp, &math->md_precision_max, mp_scaled_type);
    decNumberFromInt32(     math->md_precision_max.data.num, DECNUMDIGITS);
    mp_allocate_number(mp, &math->md_precision_min, mp_scaled_type);
    decNumberFromInt32(     math->md_precision_min.data.num, 2);
    /* here are the constants for scaled objects */
    mp_allocate_number(mp, &math->md_epsilon_t, mp_scaled_type);
    decNumberCopy(          math->md_epsilon_t.data.num, &mp_decimal_data.epsilon_decNumber);
    mp_allocate_number(mp, &math->md_inf_t, mp_scaled_type);
    decNumberCopy(          math->md_inf_t.data.num, &mp_decimal_data.EL_GORDO_decNumber);
    mp_allocate_number(mp, &math->md_negative_inf_t, mp_scaled_type);
    decNumberCopy(          math->md_negative_inf_t.data.num, &mp_decimal_data.negative_EL_GORDO_decNumber);
    mp_allocate_number(mp, &math->md_warning_limit_t, mp_scaled_type);
    decNumberFromString(    math->md_warning_limit_t.data.num, warning_limit, &mp_decimal_data.set);
    mp_allocate_number(mp, &math->md_one_third_inf_t, mp_scaled_type);
    decNumberDivide(        math->md_one_third_inf_t.data.num, math->md_inf_t.data.num, &mp_decimal_data.three_decNumber, &mp_decimal_data.set);
    mp_allocate_number(mp, &math->md_unity_t, mp_scaled_type);
    decNumberCopy(          math->md_unity_t.data.num, &mp_decimal_data.one);
    mp_allocate_number(mp, &math->md_two_t, mp_scaled_type);
    decNumberFromInt32(     math->md_two_t.data.num, two);
    mp_allocate_number(mp, &math->md_three_t, mp_scaled_type);
    decNumberFromInt32(     math->md_three_t.data.num, three);
    mp_allocate_number(mp, &math->md_half_unit_t, mp_scaled_type);
    decNumberFromString(    math->md_half_unit_t.data.num, "0.5", &mp_decimal_data.set);
    mp_allocate_number(mp, &math->md_three_quarter_unit_t, mp_scaled_type);
    decNumberFromString(    math->md_three_quarter_unit_t.data.num, "0.75", &mp_decimal_data.set);
    mp_allocate_number(mp, &math->md_zero_t, mp_scaled_type);
    decNumberZero(          math->md_zero_t.data.num);
    /* fractions */
    {
        decNumber fourzeroninesix;
        decNumberFromInt32(&fourzeroninesix, 4096);
        mp_allocate_number(mp, &math->md_arc_tol_k, mp_fraction_type);
        decNumberDivide(        math->md_arc_tol_k.data.num, &mp_decimal_data.one, &fourzeroninesix, &mp_decimal_data.set);         /* quit when change in arc length estimate reaches this */
    }
    mp_allocate_number(mp, &math->md_fraction_one_t, mp_fraction_type);
    decNumberFromInt32(     math->md_fraction_one_t.data.num, fraction_one);
    mp_allocate_number(mp, &math->md_fraction_half_t, mp_fraction_type);
    decNumberFromInt32(     math->md_fraction_half_t.data.num, fraction_half);
    mp_allocate_number(mp, &math->md_fraction_three_t, mp_fraction_type);
    decNumberFromInt32(     math->md_fraction_three_t.data.num, fraction_three);
    mp_allocate_number(mp, &math->md_fraction_four_t, mp_fraction_type);
    decNumberFromInt32(     math->md_fraction_four_t.data.num, fraction_four);
    /* angles */
    mp_allocate_number(mp, &math->md_three_sixty_deg_t, mp_angle_type);
    decNumberFromInt32(     math->md_three_sixty_deg_t.data.num, 360  * angle_multiplier);
    mp_allocate_number(mp, &math->md_one_eighty_deg_t, mp_angle_type);
    decNumberFromInt32(     math->md_one_eighty_deg_t.data.num, 180 * angle_multiplier);
    mp_allocate_number(mp, &math->md_negative_one_eighty_deg_t, mp_angle_type);
    decNumberFromInt32(     math->md_negative_one_eighty_deg_t.data.num, -180 * angle_multiplier);
    /* various approximations */
    mp_allocate_number(mp, &math->md_one_k, mp_scaled_type);
    decNumberFromDouble(    math->md_one_k.data.num, 1.0/64);
    mp_allocate_number(mp, &math->md_sqrt_8_e_k, mp_scaled_type);
    decNumberFromDouble(    math->md_sqrt_8_e_k.data.num, 112428.82793 / 65536.0);               /* $2^{16}\sqrt{8/e}\approx 112428.82793$ */
    mp_allocate_number(mp, &math->md_twelve_ln_2_k, mp_fraction_type);
    decNumberFromDouble(    math->md_twelve_ln_2_k.data.num, 139548959.6165 / 65536.0);          /* $2^{24}\cdot12\ln2\approx139548959.6165$ */
    mp_allocate_number(mp, &math->md_coef_bound_k, mp_fraction_type);
    decNumberFromDouble(    math->md_coef_bound_k.data.num,coef_bound);
    mp_allocate_number(mp, &math->md_coef_bound_minus_1, mp_fraction_type);
    decNumberFromDouble(    math->md_coef_bound_minus_1.data.num,coef_bound - 1 / 65536.0);
    mp_allocate_number(mp, &math->md_twelvebits_3, mp_scaled_type);
    decNumberFromDouble(    math->md_twelvebits_3.data.num, 1365 / 65536.0);                     /* $1365\approx 2^{12}/3$ */
    mp_allocate_number(mp, &math->md_twentysixbits_sqrt2_t, mp_fraction_type);
    decNumberFromDouble(    math->md_twentysixbits_sqrt2_t.data.num, 94906265.62 / 65536.0);     /* $2^{26}\sqrt2\approx94906265.62$ */
    mp_allocate_number(mp, &math->md_twentyeightbits_d_t, mp_fraction_type);
    decNumberFromDouble(    math->md_twentyeightbits_d_t.data.num, 35596754.69 / 65536.0);       /* $2^{28}d\approx35596754.69$ */
    mp_allocate_number(mp, &math->md_twentysevenbits_sqrt2_d_t, mp_fraction_type);
    decNumberFromDouble(    math->md_twentysevenbits_sqrt2_d_t.data.num, 25170706.63 / 65536.0); /* $2^{27}\sqrt2\,d\approx25170706.63$ */
    /* thresholds */
    mp_allocate_number(mp, &math->md_fraction_threshold_t, mp_fraction_type);
    decNumberFromDouble(    math->md_fraction_threshold_t.data.num, fraction_threshold);
    mp_allocate_number(mp, &math->md_half_fraction_threshold_t, mp_fraction_type);
    decNumberFromDouble(    math->md_half_fraction_threshold_t.data.num, half_fraction_threshold);
    mp_allocate_number(mp, &math->md_scaled_threshold_t, mp_scaled_type);
    decNumberFromDouble(    math->md_scaled_threshold_t.data.num, scaled_threshold);
    mp_allocate_number(mp, &math->md_half_scaled_threshold_t, mp_scaled_type);
    decNumberFromDouble(    math->md_half_scaled_threshold_t.data.num, half_scaled_threshold);
    mp_allocate_number(mp, &math->md_near_zero_angle_t, mp_angle_type);
    decNumberFromDouble(    math->md_near_zero_angle_t.data.num, near_zero_angle);
    mp_allocate_number(mp, &math->md_p_over_v_threshold_t, mp_fraction_type);
    decNumberFromDouble(    math->md_p_over_v_threshold_t.data.num, p_over_v_threshold);
    mp_allocate_number(mp, &math->md_equation_threshold_t, mp_scaled_type);
    decNumberFromDouble(    math->md_equation_threshold_t.data.num, equation_threshold);
    /* functions */
    math->md_from_int                 = mp_set_decimal_from_int;
    math->md_from_boolean             = mp_set_decimal_from_boolean;
    math->md_from_scaled              = mp_set_decimal_from_scaled;
    math->md_from_double              = mp_set_decimal_from_double;
    math->md_from_addition            = mp_set_decimal_from_addition;
    math->md_half_from_addition       = mp_set_decimal_half_from_addition;
    math->md_from_subtraction         = mp_set_decimal_from_subtraction;
    math->md_half_from_subtraction    = mp_set_decimal_half_from_subtraction;
    math->md_from_oftheway            = mp_set_decimal_from_of_the_way;
    math->md_from_div                 = mp_set_decimal_from_div;
    math->md_from_mul                 = mp_set_decimal_from_mul;
    math->md_from_int_div             = mp_set_decimal_from_int_div;
    math->md_from_int_mul             = mp_set_decimal_from_int_mul;
    math->md_negate                   = mp_number_negate;
    math->md_add                      = mp_number_add;
    math->md_subtract                 = mp_number_subtract;
    math->md_half                     = mp_number_half;
    math->md_do_double                = mp_number_double;
    math->md_abs                      = mp_decimal_abs;
    math->md_clone                    = mp_number_clone;
    math->md_negated_clone            = mp_number_negated_clone;
    math->md_abs_clone                = mp_number_abs_clone;
    math->md_swap                     = mp_number_swap;
    math->md_add_scaled               = mp_number_add_scaled;
    math->md_multiply_int             = mp_number_multiply_int;
    math->md_divide_int               = mp_number_divide_int;
    math->md_to_boolean               = mp_number_to_boolean;
    math->md_to_scaled                = mp_number_to_scaled;
    math->md_to_double                = mp_number_to_double;
    math->md_to_int                   = mp_number_to_int;
    math->md_odd                      = mp_number_odd;
    math->md_equal                    = mp_number_equal;
    math->md_less                     = mp_number_less;
    math->md_greater                  = mp_number_greater;
    math->md_nonequalabs              = mp_number_nonequalabs;
    math->md_round_unscaled           = mp_round_unscaled;
    math->md_floor_scaled             = mp_number_floor;
    math->md_fraction_to_round_scaled = mp_decimal_fraction_to_round_scaled;
    math->md_make_scaled              = mp_decimal_number_make_scaled;
    math->md_make_fraction            = mp_decimal_number_make_fraction;
    math->md_take_fraction            = mp_decimal_number_take_fraction;
    math->md_take_scaled              = mp_decimal_number_take_scaled;
    math->md_velocity                 = mp_decimal_velocity;
    math->md_n_arg                    = mp_decimal_n_arg;
    math->md_m_log                    = mp_decimal_m_log;
    math->md_m_exp                    = mp_decimal_m_exp;
    math->md_m_unif_rand              = mp_decimal_m_unif_rand;
    math->md_m_norm_rand              = mp_decimal_m_norm_rand;
    math->md_pyth_add                 = mp_decimal_pyth_add;
    math->md_pyth_sub                 = mp_decimal_pyth_sub;
    math->md_power_of                 = mp_decimal_power_of;
    math->md_fraction_to_scaled       = mp_number_fraction_to_scaled;
    math->md_scaled_to_fraction       = mp_number_scaled_to_fraction;
    math->md_scaled_to_angle          = mp_number_scaled_to_angle;
    math->md_angle_to_scaled          = mp_number_angle_to_scaled;
    math->md_init_randoms             = mp_init_randoms;
    math->md_sin_cos                  = mp_decimal_sin_cos;
    math->md_slow_add                 = mp_decimal_slow_add;
    math->md_sqrt                     = mp_decimal_square_rt;
    math->md_print                    = mp_decimal_print_number;
    math->md_tostring                 = mp_decimal_number_tostring;
    math->md_modulo                   = mp_decimal_number_modulo;
    math->md_ab_vs_cd                 = mp_ab_vs_cd;
    math->md_crossing_point           = mp_decimal_crossing_point;
    math->md_scan_numeric             = mp_decimal_scan_numeric_token;
    math->md_scan_fractional          = mp_decimal_scan_fractional_token;
    math->md_free_math                = mp_free_decimal_math;
    math->md_set_precision            = mp_decimal_set_precision;
    return math;
}

void mp_decimal_set_precision (MP mp)
{
    int i = decNumberToInt32((decNumber *) internal_value(mp_number_precision_internal).data.num, &mp_decimal_data.set);
    mp_decimal_data.set.digits = i;
    mp_decimal_data.limitedset.digits = i;
}

void mp_free_decimal_math (MP mp)
{
    mp_free_number(mp, &(mp->math->md_three_sixty_deg_t));
    mp_free_number(mp, &(mp->math->md_one_eighty_deg_t));
    mp_free_number(mp, &(mp->math->md_negative_one_eighty_deg_t));
    mp_free_number(mp, &(mp->math->md_fraction_one_t));
    mp_free_number(mp, &(mp->math->md_zero_t));
    mp_free_number(mp, &(mp->math->md_half_unit_t));
    mp_free_number(mp, &(mp->math->md_three_quarter_unit_t));
    mp_free_number(mp, &(mp->math->md_unity_t));
    mp_free_number(mp, &(mp->math->md_two_t));
    mp_free_number(mp, &(mp->math->md_three_t));
    mp_free_number(mp, &(mp->math->md_one_third_inf_t));
    mp_free_number(mp, &(mp->math->md_inf_t));
    mp_free_number(mp, &(mp->math->md_negative_inf_t));
    mp_free_number(mp, &(mp->math->md_warning_limit_t));
    mp_free_number(mp, &(mp->math->md_one_k));
    mp_free_number(mp, &(mp->math->md_sqrt_8_e_k));
    mp_free_number(mp, &(mp->math->md_twelve_ln_2_k));
    mp_free_number(mp, &(mp->math->md_coef_bound_k));
    mp_free_number(mp, &(mp->math->md_coef_bound_minus_1));
    mp_free_number(mp, &(mp->math->md_fraction_threshold_t));
    mp_free_number(mp, &(mp->math->md_half_fraction_threshold_t));
    mp_free_number(mp, &(mp->math->md_scaled_threshold_t));
    mp_free_number(mp, &(mp->math->md_half_scaled_threshold_t));
    mp_free_number(mp, &(mp->math->md_near_zero_angle_t));
    mp_free_number(mp, &(mp->math->md_p_over_v_threshold_t));
    mp_free_number(mp, &(mp->math->md_equation_threshold_t));
    /*
        For sake of speed, we accept this memory leak:

        for (i = 0; i <= mp_decimal_data.last_cached_factorial; i++) {
            mp_memory_free(mp_decimal_data.factorials[i]);
        }
        mp_memory_free(mp_decimal_data.factorials);
    */
    mp_memory_free(mp->math);
}

@ Creating and destruction of |mp_number| objects. Let's hope that mimalloc keeps
a pool for these.

@ @c
void mp_allocate_number (MP mp, mp_number *n, mp_number_type t)
{
    (void) mp;
    n->data.num = mp_memory_allocate(sizeof(decNumber));
    n->type = t;
    decNumberZero(n->data.num);
}

@ @c
void mp_allocate_clone (MP mp, mp_number *n, mp_number_type t, mp_number *v)
{
    (void) mp;
    n->data.num = mp_memory_allocate(sizeof(decNumber));
    n->type = t;
    decNumberZero(n->data.num);
    decNumberCopy(n->data.num, v->data.num);
}

@ @c
void mp_allocate_abs (MP mp, mp_number *n, mp_number_type t, mp_number *v)
{
    (void) mp;
    n->data.num = mp_memory_allocate(sizeof(decNumber));
    n->type = t;
    decNumberZero(n->data.num); /* not needed */
    decNumberAbs(n->data.num, v->data.num, &mp_decimal_data.set);
}

void mp_allocate_double (MP mp, mp_number *n, double v)
{
    (void) mp;
    n->data.num = mp_memory_allocate(sizeof(decNumber));
    n->type = mp_scaled_type;
    decNumberZero(n->data.num); /* not needed */
    decNumberFromDouble(n->data.num, v);
}

@ @c
void mp_free_number (MP mp, mp_number *n)
{
    (void) mp;
    if (n->data.num) {
        mp_memory_free(n->data.num);
        n->data.num = NULL;
        n->type = mp_nan_type;
    }
}

@ Here are the low-level functions on |mp_number| items, setters first.

@c
void mp_set_decimal_from_int(mp_number *A, int B)
{
    decNumberFromInt32(A->data.num, B);
}

void mp_set_decimal_from_boolean(mp_number *A, int B)
{
    decNumberFromInt32(A->data.num, B);
}

void mp_set_decimal_from_scaled(mp_number *A, int B)
{
    decNumber c;
    decNumberFromInt32(&c, 65536);
    decNumberFromInt32(A->data.num,B);
    decNumberDivide(A->data.num, A->data.num, &c, &mp_decimal_data.set);
}

void mp_set_decimal_from_double(mp_number *A, double B)
{
    decNumberFromDouble(A->data.num, B);
}

void mp_set_decimal_from_addition(mp_number *A, mp_number *B, mp_number *C)
{
    decNumberAdd(A->data.num, B->data.num, C->data.num, &mp_decimal_data.set);
}

void mp_set_decimal_half_from_addition(mp_number *A, mp_number *B, mp_number *C)
{
    decNumber c;
    decNumberAdd(A->data.num, B->data.num, C->data.num, &mp_decimal_data.set);
    decNumberFromInt32(&c, 2);
    decNumberDivide(A->data.num, A->data.num, &c, &mp_decimal_data.set);
}

void mp_set_decimal_from_subtraction(mp_number *A, mp_number *B, mp_number *C)
{
    decNumberSubtract(A->data.num, B->data.num, C->data.num, &mp_decimal_data.set);
}

void mp_set_decimal_half_from_subtraction(mp_number *A, mp_number *B, mp_number *C)
{
    decNumber c;
    decNumberSubtract(A->data.num, B->data.num, C->data.num, &mp_decimal_data.set);
    decNumberFromInt32(&c, 2);
    decNumberDivide(A->data.num, A->data.num, &c, &mp_decimal_data.set);
}

void mp_set_decimal_from_div(mp_number *A, mp_number *B, mp_number *C)
{
    decNumberDivide(A->data.num, B->data.num, C->data.num, &mp_decimal_data.set);
}

void mp_set_decimal_from_mul(mp_number *A, mp_number *B, mp_number *C)
{
    decNumberMultiply(A->data.num, B->data.num, C->data.num, &mp_decimal_data.set);
}

void mp_set_decimal_from_int_div(mp_number *A, mp_number *B, int C)
{
    decNumber c;
    decNumberFromInt32(&c, C);
    decNumberDivide(A->data.num, B->data.num, &c, &mp_decimal_data.set);
}

void mp_set_decimal_from_int_mul(mp_number *A, mp_number *B, int C)
{
    decNumber c;
    decNumberFromInt32(&c, C);
    decNumberMultiply(A->data.num, B->data.num, &c, &mp_decimal_data.set);
}

void mp_set_decimal_from_of_the_way (MP mp, mp_number *A, mp_number *t, mp_number *B, mp_number *C)
{
    decNumber c;
    decNumber r1;
    decNumberSubtract(&c, B->data.num, C->data.num, &mp_decimal_data.set);
    mp_decimal_take_fraction(mp, &r1, &c, t->data.num);
    decNumberSubtract(A->data.num, B->data.num, &r1, &mp_decimal_data.set);
    mp_decnumber_check(mp, A->data.num, &mp_decimal_data.set);
}

void mp_number_negate(mp_number *A)
{
    decNumberCopyNegate(A->data.num, A->data.num);
    checkZero(A->data.num);
}

void mp_number_add(mp_number *A, mp_number *B)
{
    decNumberAdd(A->data.num, A->data.num, B->data.num, &mp_decimal_data.set);
}

void mp_number_subtract(mp_number *A, mp_number *B)
{
    decNumberSubtract(A->data.num, A->data.num, B->data.num, &mp_decimal_data.set);
}

void mp_number_half(mp_number *A)
{
    decNumber c;
    decNumberFromInt32(&c, 2);
    decNumberDivide(A->data.num, A->data.num, &c, &mp_decimal_data.set);
}

void mp_number_double(mp_number *A)
{
    decNumber c;
    decNumberFromInt32(&c, 2);
    decNumberMultiply(A->data.num, A->data.num, &c, &mp_decimal_data.set);
}

void mp_number_add_scaled(mp_number *A, int B)
{
    decNumber b, c;
    decNumberFromInt32(&c, 65536);
    decNumberFromInt32(&b, B);
    decNumberDivide(&b, &b, &c, &mp_decimal_data.set);
    decNumberAdd(A->data.num, A->data.num, &b, &mp_decimal_data.set);
}

void mp_number_multiply_int(mp_number *A, int B)
{
    decNumber b;
    decNumberFromInt32(&b, B);
    decNumberMultiply(A->data.num, A->data.num, &b, &mp_decimal_data.set);
}

void mp_number_divide_int(mp_number *A, int B)
{
    decNumber b;
    decNumberFromInt32(&b, B);
    decNumberDivide(A->data.num, A->data.num, &b, &mp_decimal_data.set);
}

void mp_decimal_abs(mp_number *A)
{
    decNumberAbs(A->data.num, A->data.num, &mp_decimal_data.set);
}

void mp_number_clone(mp_number *A, mp_number *B)
{
    decNumberCopy(A->data.num, B->data.num);
}

void mp_number_negated_clone(mp_number *A, mp_number *B)
{
    decNumberCopyNegate(A->data.num, B->data.num);
    checkZero(A->data.num);
}

void mp_number_abs_clone(mp_number *A, mp_number *B)
{
    decNumberAbs(A->data.num, B->data.num, &mp_decimal_data.set);
}

void mp_number_swap(mp_number *A, mp_number *B)
{
    decNumber swap_tmp;
    decNumberCopy(&swap_tmp,   A->data.num);
    decNumberCopy(A->data.num, B->data.num);
    decNumberCopy(B->data.num, &swap_tmp);
}

void mp_number_fraction_to_scaled(mp_number *A)
{
    A->type = mp_scaled_type;
    decNumberDivide(A->data.num, A->data.num, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
}

void mp_number_angle_to_scaled(mp_number *A)
{
    A->type = mp_scaled_type;
    decNumberDivide(A->data.num, A->data.num, &mp_decimal_data.angle_multiplier_decNumber, &mp_decimal_data.set);
}

void mp_number_scaled_to_fraction(mp_number *A)
{
    A->type = mp_fraction_type;
    decNumberMultiply(A->data.num, A->data.num, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
}

void mp_number_scaled_to_angle(mp_number *A)
{
    A->type = mp_angle_type;
    decNumberMultiply(A->data.num, A->data.num, &mp_decimal_data.angle_multiplier_decNumber, &mp_decimal_data.set);
}

@* Query functions.

@ Convert a number to a scaled value. |decNumberToInt32| is not able to make this
conversion properly, so instead we are using |decNumberToDouble| and a typecast.
Bad!

@c
int mp_number_to_scaled(mp_number *A)
{
    int32_t result;
    decNumber corrected;
    decNumberFromInt32(&corrected, 65536);
    decNumberMultiply(&corrected, &corrected, A->data.num, &mp_decimal_data.set);
    decNumberReduce(&corrected, &corrected, &mp_decimal_data.set);
    result = (int) floor(decNumberToDouble(&corrected) + 0.5);
    return result;
}

@ @c
int mp_number_to_int(mp_number *A)
{
    int32_t result;
    mp_decimal_data.set.status = 0;
    result = decNumberToInt32(A->data.num, &mp_decimal_data.set);
    if (mp_decimal_data.set.status == DEC_Invalid_operation) {
        mp_decimal_data.set.status = 0;
        /* |mp->arith_error = 1;| */
        return 0;
    } else {
        return result;
    }
}

int mp_number_to_boolean(mp_number *A)
{
    uint32_t result;
    mp_decimal_data.set.status = 0;
    result = decNumberToUInt32(A->data.num, &mp_decimal_data.set);
    if (mp_decimal_data.set.status == DEC_Invalid_operation) {
        mp_decimal_data.set.status = 0;
        /* |mp->arith_error = 1;| */
        return mp_false_operation;
    } else {
        return result ;
    }
}

double mp_number_to_double(mp_number *A)
{
    char *buffer = mp_memory_allocate((size_t) ((decNumber *) A->data.num)->digits + 14);
    double res = 0.0;
    decNumberToString(A->data.num, buffer);
    if (sscanf(buffer, "%lf", &res)) {
        mp_memory_free(buffer);
        return res;
    } else {
        mp_memory_free(buffer);
        /* |mp->arith_error = 1;| */
        return 0.0;
    }
}

int mp_number_odd(mp_number *A)
{
    decNumber r1, r2;
    decNumberAbs(&r1, A->data.num, &mp_decimal_data.set);
    decNumberRemainder(&r2, &r1, &mp_decimal_data.two_decNumber, &mp_decimal_data.set);
    decNumberCompare(&r1, &r2, &mp_decimal_data.one, &mp_decimal_data.set);
    return decNumberIsZero(&r1);
}

int mp_number_equal(mp_number *A, mp_number *B)
{
    decNumber res;
    decNumberCompare(&res, A->data.num, B->data.num, &mp_decimal_data.set);
    return decNumberIsZero(&res);
}

int mp_number_greater(mp_number *A, mp_number *B)
{
    decNumber res;
    decNumberCompare(&res, A->data.num, B->data.num, &mp_decimal_data.set);
    return decNumberIsPositive(&res);
}

int mp_number_less(mp_number *A, mp_number *B)
{
    decNumber res;
    decNumberCompare(&res, A->data.num, B->data.num, &mp_decimal_data.set);
    return decNumberIsNegative(&res);
}

int mp_number_nonequalabs(mp_number *A, mp_number *B)
{
    decNumber res, a, b;
    decNumberCopyAbs(&a, A->data.num);
    decNumberCopyAbs(&b, B->data.num);
    decNumberCompare(&res, &a, &b, &mp_decimal_data.set);
    return ! decNumberIsZero(&res);
}

@ Fixed-point arithmetic is done on {\sl scaled integers} that are multiples of
$2^{-16}$. In other words, a binary point is assumed to be sixteen bit positions
from the right end of a binary computer word.

@ One of \MP's most common operations is the calculation of
$\lfloor{a+b\over2}\rfloor$, the midpoint of two given integers |a| and~|b|. The
most decent way to do this is to write |(a+b)/2|; but on many machines it is
more efficient to calculate |(a+b)>>1|.

Therefore the midpoint operation will always be denoted by |half(a+b)| in this
program. If \MP\ is being implemented with languages that permit binary shifting,
the |half| macro should be changed to make this operation as efficient as
possible. Since some systems have shift operators that can only be trusted to
work on positive numbers, there is also a macro |halfp| that is used only when
the quantity being halved is known to be positive or zero.

@ Here is a procedure analogous to |print_int|. The current version is fairly
stupid, and it is not round-trip safe, but this is good enough for a beta test.

@c
char *mp_decnumber_tostring(decNumber *n)
{
    decNumber corrected;
    char *buffer = mp_memory_allocate((size_t) ((decNumber *) n)->digits + 14);
    decNumberCopy(&corrected, n);
    decNumberTrim(&corrected);
    decNumberToString(&corrected, buffer);
    return buffer;
}

char *mp_decimal_number_tostring (MP mp, mp_number *n)
{
    (void) mp;
    return mp_decnumber_tostring(n->data.num);
}

@ @c
void mp_decimal_print_number (MP mp, mp_number *n)
{
    char *str = mp_decnumber_tostring(n->data.num);
    mp_print_e_str(mp, str);
    mp_memory_free(str);
}

@ Addition is not always checked to make sure that it doesn't overflow, but in
places where overflow isn't too unlikely the |slow_add| routine is used.

@c
void mp_decimal_slow_add (MP mp, mp_number *ret, mp_number *A, mp_number *B)
{
    (void) mp;
    decNumberAdd(ret->data.num, A->data.num, B->data.num, &mp_decimal_data.set);
}

@ The |make_fraction| routine produces the |fraction| equivalent of |p/q|, given
integers |p| and~|q|; it computes the integer
$f=\lfloor2^{28}p/q+{1\over2}\rfloor$, when $p$ and $q$ are positive. If |p| and
|q| are both of the same scaled type |t|, the \quote {type relation}
|make_fraction(t,t)=fraction| is valid; and it's also possible to use the
subroutine \quote {backwards,} using the relation |make_fraction(t,fraction)=t|
between scaled types.

If the result would have magnitude $2^{31}$ or more, |make_fraction| sets
|arith_error:=true|. Most of \MP's internal computations have been designed to
avoid this sort of error.

If this subroutine were programmed in assembly language on a typical machine, we
could simply compute |(@t$2^{28}$@>*p)div q|, since a double-precision product
can often be input to a fixed-point division instruction. But when we are
restricted to int-eger arithmetic it is necessary either to resort to
multiple-precision maneuvering or to use a simple but slow iteration. The
multiple-precision technique would be about three times faster than the code
adopted here, but it would be comparatively long and tricky, involving about
sixteen additional multiplications and divisions.

This operation is part of \MP's \quote {inner loop}; indeed, it will consume nearly
10\pct! of the running time (exclusive of input and output) if the code below is
left unchanged. A machine-dependent recoding will therefore make \MP\ run faster.
The present implementation is highly portable, but slow; it avoids multiplication
and division except in the initial stage. System wizards should be careful to
replace it with a routine that is guaranteed to produce identical results in all
cases. @^system dependencies@>

As noted below, a few more routines should also be replaced by machine-dependent
code, for efficiency. But when a procedure is not part of the \quote {inner loop,}
such changes aren't advisable; simplicity and robustness are preferable to
trickery, unless the cost is too high. @^inner loop@>

@c
void mp_decimal_make_fraction (MP mp, decNumber *ret, decNumber *p, decNumber *q)
{
    decNumberDivide(ret, p, q, &mp_decimal_data.set);
    mp_decnumber_check(mp, ret, &mp_decimal_data.set);
    decNumberMultiply(ret, ret, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
}

void mp_decimal_number_make_fraction (MP mp, mp_number *ret, mp_number *p, mp_number *q)
{
    mp_decimal_make_fraction(mp, ret->data.num, p->data.num, q->data.num);
}

@ The dual of |make_fraction| is |take_fraction|, which multiplies a given
integer~|q| by a fraction~|f|. When the operands are positive, it computes
$p=\lfloor qf/2^{28}+{1\over2}\rfloor$, a symmetric function of |q| and~|f|.

This routine is even more \quote {inner loopy} than |make_fraction|; the present
implementation consumes almost 20\pct! of \MP's computation time during typical
jobs, so a machine-language substitute is advisable. @^inner loop@> @^system
dependencies@>

@c
void mp_decimal_take_fraction (MP mp, decNumber *ret, decNumber *p, decNumber *q)
{
    (void) mp;
    decNumberMultiply(ret, p, q, &mp_decimal_data.set);
    decNumberDivide(ret, ret, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
}

void mp_decimal_number_take_fraction (MP mp, mp_number *ret, mp_number *p, mp_number *q)
{
    mp_decimal_take_fraction(mp, ret->data.num, p->data.num, q->data.num);
}

@ When we want to multiply something by a |scaled| quantity, we use a scheme
analogous to |take_fraction| but with a different scaling. Given positive
operands, |take_scaled| computes the quantity $p=\lfloor
qf/2^{16}+{1\over2}\rfloor$.

Once again it is a good idea to use a machine-language replacement if possible;
otherwise |take_scaled| will use more than 2\pct! of the running time when the
Computer Modern fonts are being generated. @^inner loop@>

@c
void mp_decimal_number_take_scaled (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    (void) mp;
    decNumberMultiply(ret->data.num, p_orig->data.num, q_orig->data.num, &mp_decimal_data.set);
}

@ For completeness, there's also |make_scaled|, which computes a quotient as a
|scaled| number instead of as a |fraction|. In other words, the result is
$\lfloor2^{16}p/q+{1\over2}\rfloor$, if the operands are positive. \ (This
procedure is not used especially often, so it is not part of \MP's inner loop.)

@c
void mp_decimal_number_make_scaled (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    decNumberDivide(ret->data.num, p_orig->data.num, q_orig->data.num, &mp_decimal_data.set);
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ @* Scanning numbers in the input.

The definitions below are temporarily here

@ @c
void mp_wrapup_numeric_token (MP mp, unsigned char *start, unsigned char *stop)
{
    decNumber result;
    size_t l = stop-start+1;
    char *buf = mp_memory_allocate(l + 1);
    buf[l] = '\0';
    (void) strncpy(buf, (const char *) start, l);
    mp_decimal_data.set.status = 0;
    decNumberFromString(&result,buf, &mp_decimal_data.set);
    mp_memory_free(buf);
    if (mp_decimal_data.set.status == 0) {
        set_cur_mod(&result);
    } else if (mp->scanner_status != mp_tex_flushing_state) {
        if (too_large(mp_decimal_data.set.status)) {
            mp_decnumber_check(mp, &result, &mp_decimal_data.set);
            set_cur_mod(&result);
            mp_error(
                mp,
                "Enormous number has been reduced",
                "I could not handle this number specification because it is out of range."
            );
        } else if (too_precise(mp_decimal_data.set.status)) {
            set_cur_mod(&result);
            if (decNumberIsPositive((decNumber *) internal_value(mp_warning_check_internal).data.num) && (mp->scanner_status != mp_tex_flushing_state)) {
                char msg[256];
                mp_snprintf (msg, 256, "Number is too precise (numberprecision = %d)", mp_decimal_data.set.digits);
                mp_error(
                    mp,
                    msg,
                    "Continue and I'll round the value until it fits the current numberprecision\n"
                    "(Set warningcheck:=0 to suppress this message.)"
                );
            }
        } else {
            /* this also captures underflow */
            mp_error(
                mp,
                "Erroneous number specification changed to zero",
                "I could not handle this number specification"
            );
            decNumberZero(&result);
            set_cur_mod(&result);
        }
    }
    set_cur_cmd((mp_variable_type) mp_numeric_command);
}

@ @c
static void find_exponent (MP mp)
{
    if (mp->buffer[mp->cur_input.loc_field] == 'e'
     || mp->buffer[mp->cur_input.loc_field] == 'E') {
        mp->cur_input.loc_field++;
        if (! (mp->buffer[mp->cur_input.loc_field] == '+'
            || mp->buffer[mp->cur_input.loc_field] == '-'
            || mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class)) {
            mp->cur_input.loc_field--;
            return;
        }
        if (mp->buffer[mp->cur_input.loc_field] == '+' ||
            mp->buffer[mp->cur_input.loc_field] == '-') {
            mp->cur_input.loc_field++;
        }
        while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
            mp->cur_input.loc_field++;
        }
    }
}

void mp_decimal_scan_fractional_token (MP mp, int n)
{
    unsigned char *start = &mp->buffer[mp->cur_input.loc_field -1];
    unsigned char *stop;
    (void) n;
    while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
        mp->cur_input.loc_field++;
    }
    find_exponent(mp);
    stop = &mp->buffer[mp->cur_input.loc_field-1];
    mp_wrapup_numeric_token(mp, start, stop);
}

@ We just have to collect bytes.

@c
void mp_decimal_scan_numeric_token (MP mp, int n)
{
    unsigned char *start = &mp->buffer[mp->cur_input.loc_field -1];
    unsigned char *stop;
    (void) n;
    while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
        mp->cur_input.loc_field++;
    }
    if (mp->buffer[mp->cur_input.loc_field] == '.' && mp->buffer[mp->cur_input.loc_field+1] != '.') {
        mp->cur_input.loc_field++;
        while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
            mp->cur_input.loc_field++;
        }
    }
    find_exponent(mp);
    stop = &mp->buffer[mp->cur_input.loc_field-1];
    mp_wrapup_numeric_token(mp, start, stop);
}

@ The |scaled| quantities in \MP\ programs are generally supposed to be less than
$2^{12}$ in absolute value, so \MP\ does much of its internal arithmetic with
28~significant bits of precision. A |fraction| denotes a scaled integer whose
binary point is assumed to be 28 bit positions from the right.

@ Here is a typical example of how the routines above can be used. It computes
the function $${1\over3\tau}f(\theta,\phi)=
{\tau^{-1}\bigl(2+\sqrt2\,(\sin\theta-{1\over16}\sin\phi)
(\sin\phi-{1\over16}\sin\theta)(\cos\theta-\cos\phi)\bigr)\over
3\,\bigl(1+{1\over2}(\sqrt5-1)\cos\theta+{1\over2}(3-\sqrt5\,)\cos\phi\bigr)},$$
where $\tau$ is a |scaled| \quote {tension} parameter. This is \MP's magic fudge
factor for placing the first control point of a curve that starts at an angle
$\theta$ and ends at an angle $\phi$ from the straight path. (Actually, if the
stated quantity exceeds 4, \MP\ reduces it to~4.)

The trigonometric quantity to be multiplied by $\sqrt2$ is less than $\sqrt2$.
(It's a sum of eight terms whose absolute values can be bounded using relations
such as $\sin\theta\cos\theta|1\over2|$.) Thus the numerator is positive; and
since the tension $\tau$ is constrained to be at least $3\over4$, the numerator
is less than $16\over3$. The denominator is nonnegative and at most~6.

The angles $\theta$ and $\phi$ are given implicitly in terms of |fraction|
arguments |st|, |ct|, |sf|, and |cf|, representing $\sin\theta$, $\cos\theta$,
$\sin\phi$, and $\cos\phi$, respectively.

@c
void mp_decimal_velocity (MP mp, mp_number *ret, mp_number *st, mp_number *ct, mp_number *sf, mp_number *cf, mp_number *t)
{
    decNumber acc, num, denom; /* registers for intermediate calculations */
    decNumber r1, r2;
    decNumber arg1, arg2;
    decNumber i16, fone, fhalf, ftwo, sqrtfive;
    decNumberFromInt32(&i16, 16);
    decNumberFromInt32(&fone, fraction_one);
    decNumberFromInt32(&fhalf, fraction_half);
    decNumberFromInt32(&ftwo, fraction_two);
    decNumberFromInt32(&sqrtfive, 5);
    decNumberSquareRoot(&sqrtfive, &sqrtfive, &mp_decimal_data.set);

    decNumberDivide(&arg1, sf->data.num, &i16, &mp_decimal_data.set);   /* arg1 = sf / 16*/
    decNumberSubtract(&arg1, st->data.num,&arg1, &mp_decimal_data.set); /* arg1 = st - arg1*/
    decNumberDivide(&arg2, st->data.num, &i16, &mp_decimal_data.set);   /* arg2 = st / 16*/
    decNumberSubtract(&arg2, sf->data.num,&arg2, &mp_decimal_data.set); /* arg2 = sf - arg2*/
    mp_decimal_take_fraction(mp, &acc, &arg1, &arg2);                   /* acc = (arg1 * arg2) / fmul*/

    decNumberCopy(&arg1, &acc);
    decNumberSubtract(&arg2, ct->data.num, cf->data.num, &mp_decimal_data.set); /* arg2 = ct - cf*/
    mp_decimal_take_fraction(mp, &acc, &arg1, &arg2);                           /* acc = (arg1 * arg2 ) / fmul*/

    decNumberSquareRoot(&arg1, &mp_decimal_data.two_decNumber, &mp_decimal_data.set); /* arg1 = $\sqrt{2}$*/
    decNumberMultiply(&arg1, &arg1, &fone, &mp_decimal_data.set);                     /* arg1 = arg1 * fmul*/
    mp_decimal_take_fraction(mp, &r1, &acc, &arg1);                                   /* r1 = (acc * arg1) / fmul*/
    decNumberAdd(&num, &ftwo, &r1, &mp_decimal_data.set);                             /* num = ftwo + r1*/

    decNumberSubtract(&arg1,&sqrtfive, &mp_decimal_data.one, &mp_decimal_data.set);        /* arg1 = $\sqrt{5}$ - 1*/
    decNumberMultiply(&arg1,&arg1,&fhalf, &mp_decimal_data.set);                           /* arg1 = arg1 * fmul/2*/
    decNumberMultiply(&arg1,&arg1,&mp_decimal_data.three_decNumber, &mp_decimal_data.set); /* arg1 = arg1 * 3*/

    decNumberSubtract(&arg2,&mp_decimal_data.three_decNumber, &sqrtfive, &mp_decimal_data.set); /* arg2 = 3 - $\sqrt{5}$*/
    decNumberMultiply(&arg2,&arg2, &fhalf, &mp_decimal_data.set);                               /* arg2 = arg2 * fmul/2*/
    decNumberMultiply(&arg2,&arg2, &mp_decimal_data.three_decNumber, &mp_decimal_data.set);     /* arg2 = arg2 * 3*/
    mp_decimal_take_fraction(mp, &r1, ct->data.num, &arg1) ;                                    /* r1 = (ct * arg1) / fmul*/
    mp_decimal_take_fraction(mp, &r2, cf->data.num, &arg2);                                     /* r2 = (cf * arg2) / fmul*/

    decNumberFromInt32(&denom, fraction_three);              /* denom = 3fmul*/
    decNumberAdd(&denom, &denom, &r1, &mp_decimal_data.set); /* denom = denom + r1*/
    decNumberAdd(&denom, &denom, &r2, &mp_decimal_data.set); /* denom = denom + r1*/

    decNumberCompare(&arg1, t->data.num, &mp_decimal_data.one, &mp_decimal_data.set);
    if (! decNumberIsZero(&arg1)) { /* t != r1*/
        decNumberDivide(&num, &num, t->data.num, &mp_decimal_data.set); /* num = num / t */
    }
    decNumberCopy(&r2, &num); /* r2 = num / 4*/
    decNumberDivide(&r2, &r2, &mp_decimal_data.four_decNumber, &mp_decimal_data.set);
    if (decNumberLess(&denom, &r2)) {
        decNumberFromInt32(ret->data.num, fraction_four); /* num/4 >= denom => denom < num/4*/
    } else {
        mp_decimal_make_fraction(mp, ret->data.num, &num, &denom);
    }
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ The following somewhat different subroutine tests rigorously if $ab$ is greater
than, equal to, or less than~$cd$, given integers $(a,b,c,d)$. In most cases a
quick decision is reached. The result is $+1$, 0, or~$-1$ in the three respective
cases.

@c
int mp_ab_vs_cd (mp_number *a_orig, mp_number *b_orig, mp_number *c_orig, mp_number *d_orig)
{
    decNumber a, b, c, d;
    decNumber ab, cd;
    decNumberCopy(&a, (decNumber *) a_orig->data.num);
    decNumberCopy(&b, (decNumber *) b_orig->data.num);
    decNumberCopy(&c, (decNumber *) c_orig->data.num);
    decNumberCopy(&d, (decNumber *) d_orig->data.num);
    decNumberMultiply(&ab, (decNumber *) a_orig->data.num, (decNumber *)b_orig->data.num, &mp_decimal_data.set);
    decNumberMultiply(&cd, (decNumber *) c_orig->data.num, (decNumber *)d_orig->data.num, &mp_decimal_data.set);
    if (decNumberLess(&ab, &cd)) {
        return -1;
    } else if (decNumberGreater(&ab, &cd)) {
        return 1;
    } else {
        return 0;
    }
}

@ Now here's a subroutine that's handy for all sorts of path computations: Given
a quadratic polynomial $B(a,b,c;t)$, the |crossing_point| function returns the
unique |fraction| value |t| between 0 and~1 at which $B(a,b,c;t)$ changes from
positive to negative, or returns |t=fraction_one+1| if no such value exists. If
|a<0| (so that $B(a,b,c;t)$ is already negative at |t=0|), |crossing_point|
returns the value zero.

The general bisection method is quite simple when $n=2$, hence |crossing_point|
does not take much time. At each stage in the recursion we have a subinterval
defined by |l| and~|j| such that $B(a,b,c;2^{-l}(j+t))=B(x_0,x_1,x_2;t)$, and we
want to \quote {zero in} on the subinterval where $x_0\G0$ and $\min(x_1,x_2)<0$.

It is convenient for purposes of calculation to combine the values of |l| and~|j|
in a single variable $d=2^l+j$, because the operation of bisection then
corresponds simply to doubling $d$ and possibly adding~1. Furthermore it proves
to be convenient to modify our previous conventions for bisection slightly,
maintaining the variables $X_0=2^lx_0$, $X_1=2^l(x_0-x_1)$, and
$X_2=2^l(x_1-x_2)$. With these variables the conditions $x_0\ge0$ and
$\min(x_1,x_2)<0$ are equivalent to $\max(X_1,X_1+X_2)>X_0\ge0$.

The following code maintains the invariant relations
$0\L|x0|<\max(|x1|,|x1|+|x2|)$, $\vert|x1|\vert<2^{30}$, $\vert|x2|\vert<2^{30}$;
it has been constructed in such a way that no arithmetic overflow will occur if
the inputs satisfy $a<2^{30}$, $\vert a-b\vert<2^{30}$, and $\vert
b-c\vert<2^{30}$.

@c
static void mp_decimal_crossing_point (MP mp, mp_number *ret, mp_number *aa, mp_number *bb, mp_number *cc)
{
    decNumber a, b, c;
    double d; /* recursive counter */
    decNumber x, xx, x0, x1, x2; /* temporary registers for bisection */
    decNumber scratch, scratch2;
    decNumberCopy(&a, (decNumber *) aa->data.num);
    decNumberCopy(&b, (decNumber *) bb->data.num);
    decNumberCopy(&c, (decNumber *) cc->data.num);
    if (decNumberIsNegative(&a)) {
        decNumberCopy(ret->data.num, &zero_crossing);
        goto RETURN;
    }
    if (! decNumberIsNegative(&c)) {
        if (! decNumberIsNegative(&b)) {
            if (decNumberIsPositive(&c)) {
                decNumberCopy(ret->data.num, &no_crossing);
            } else if (decNumberIsZero(&a) && decNumberIsZero(&b)) {
                decNumberCopy(ret->data.num, &no_crossing);
            } else {
                decNumberCopy(ret->data.num, &one_crossing);
            }
            goto RETURN;
        }
        if (decNumberIsZero(&a)) {
            decNumberCopy(ret->data.num, &zero_crossing);
            goto RETURN;
        }
    } else if (decNumberIsZero(&a) && ! decNumberIsPositive(&b)) {
        decNumberCopy(ret->data.num, &zero_crossing);
        goto RETURN;
    }
    /* Use bisection to find the crossing point... */
    d = epsilonf;
    decNumberCopy(&x0, &a);
    decNumberSubtract(&x1, &a, &b, &mp_decimal_data.set);
    decNumberSubtract(&x2, &b, &c, &mp_decimal_data.set);
    /* not sure why the error correction has to be >= 1E-12 */
    decNumberFromDouble(&scratch2, 1E-12);
    do {
        decNumberAdd(&x, &x1, &x2, &mp_decimal_data.set);
        decNumberDivide(&x, &x, &mp_decimal_data.two_decNumber, &mp_decimal_data.set);
        decNumberAdd(&x, &x, &scratch2, &mp_decimal_data.set);
        decNumberSubtract(&scratch, &x1, &x0, &mp_decimal_data.set);
        if (decNumberGreater(&scratch, &x0)) {
            decNumberCopy(&x2, &x);
            decNumberAdd(&x0, &x0, &x0, &mp_decimal_data.set);
            d += d;
        } else {
            decNumberAdd(&xx, &scratch, &x, &mp_decimal_data.set);
            if (decNumberGreater(&xx,&x0)) {
                decNumberCopy(&x2,&x);
                decNumberAdd(&x0, &x0, &x0, &mp_decimal_data.set);
                d += d;
            } else {
                decNumberSubtract(&x0, &x0, &xx, &mp_decimal_data.set);
                if (! decNumberGreater(&x,&x0)) {
                    decNumberAdd(&scratch, &x, &x2, &mp_decimal_data.set);
                    if (! decNumberGreater(&scratch, &x0)) {
                        decNumberCopy(ret->data.num, &no_crossing);
                        goto RETURN;
                    }
                }
                decNumberCopy(&x1,&x);
                d = d + d + epsilonf;
            }
        }
    } while (d < fraction_one);
    decNumberFromDouble(&scratch, d);
    decNumberSubtract(ret->data.num,&scratch, &mp_decimal_data.fraction_one_decNumber, &mp_decimal_data.set);
  RETURN:
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ We conclude this set of elementary routines with some simple rounding and
truncation operations.

@ |round_unscaled| rounds a |scaled| and converts it to |int|

@c
int mp_round_unscaled(mp_number *x_orig)
{
    return (int) lround(mp_number_to_double(x_orig));
}

@ |number_floor| floors a number

@c
void mp_number_floor(mp_number *i)
{
    int round = mp_decimal_data.set.round;
    mp_decimal_data.set.round = DEC_ROUND_FLOOR;
    decNumberToIntegralValue(i->data.num, i->data.num, &mp_decimal_data.set);
    mp_decimal_data.set.round = round;
}

@ |fraction_to_scaled| rounds a |fraction| and converts it to |scaled|

@c
void mp_decimal_fraction_to_round_scaled(mp_number *x_orig)
{
    x_orig->type = mp_scaled_type;
    decNumberDivide(x_orig->data.num, x_orig->data.num, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
}

@* Algebraic and transcendental functions. \MP\ computes all of the necessary
special functions from scratch, without relying on |real| arithmetic or system
subroutines for sines, cosines, etc.

@ @c
void mp_decimal_square_rt (MP mp, mp_number *ret, mp_number *x_orig)
{
    decNumber x;
    decNumberCopy(&x, x_orig->data.num);
    if (! decNumberIsPositive(&x)) {
        if (decNumberIsNegative(&x)) {
            char msg[256];
            char *xstr = mp_decimal_number_tostring(mp, x_orig);
            mp_snprintf(msg, 256, "Square root of %s has been replaced by 0", xstr);
            mp_memory_free(xstr);
            @.Square root...replaced by 0@>
            mp_error(
                mp,
                msg,
                "Since I don't take square roots of negative numbers, I'm zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        }
        decNumberZero(ret->data.num);
    } else {
        decNumberSquareRoot(ret->data.num, &x, &mp_decimal_data.set);
    }
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ Pythagorean addition $\psqrt{a^2+b^2}$ is implemented by a quick hack

@c
void mp_decimal_pyth_add (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    decNumber a, b;
    decNumber asq, bsq;
    decNumberCopyAbs(&a, a_orig->data.num);
    decNumberCopyAbs(&b, b_orig->data.num);
    decNumberMultiply(&asq, &a, &a, &mp_decimal_data.set);
    decNumberMultiply(&bsq, &b, &b, &mp_decimal_data.set);
    decNumberAdd(&a, &asq, &bsq, &mp_decimal_data.set);
    decNumberSquareRoot(ret->data.num, &a, &mp_decimal_data.set);
    /*
    if (set.status != 0) {
      mp->arith_error = 1;
      decNumberCopy(ret->data.num, &mp_decimal_data.EL_GORDO_decNumber);
    }
    */
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ Here is a similar algorithm for $\psqrt{a^2-b^2}$. Same quick hack, also.

@c
void mp_decimal_pyth_sub (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    decNumber a, b;
    decNumberCopyAbs(&a, a_orig->data.num);
    decNumberCopyAbs(&b, b_orig->data.num);
    if (! decNumberGreater(&a, &b)) {
        if (decNumberLess(&a, &b)) {
            char msg[256];
            char *astr = mp_decimal_number_tostring(mp, a_orig);
            char *bstr = mp_decimal_number_tostring(mp, b_orig);
            mp_snprintf(msg, 256, "Pythagorean subtraction %s+-+%s has been replaced by 0", astr, bstr);
            mp_memory_free(astr);
            mp_memory_free(bstr);
            @.Pythagorean...@>
            mp_error(
                mp,
                msg,
                "Since I don't take square roots of negative numbers, I'm zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        }
        decNumberZero(&a);
    } else {
        decNumber asq, bsq;
        decNumberMultiply(&asq, &a, &a, &mp_decimal_data.set);
        decNumberMultiply(&bsq, &b, &b, &mp_decimal_data.set);
        decNumberSubtract(&a, &asq, &bsq, &mp_decimal_data.set);
        decNumberSquareRoot(&a, &a, &mp_decimal_data.set);
    }
    decNumberCopy(ret->data.num, &a);
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ Power $a^b}$:

@c
void mp_decimal_power_of (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    decNumberPower(ret->data.num, a_orig->data.num, b_orig->data.num, &mp_decimal_data.set);
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ Here is the routine that calculates $2^8$ times the natural logarithm of a
|scaled| quantity;

@c
void mp_decimal_m_log (MP mp, mp_number *ret, mp_number *x_orig)
{
    if (! decNumberIsPositive((decNumber *) x_orig->data.num)) {
        char msg[256];
        char *xstr = mp_decimal_number_tostring(mp, x_orig);
        mp_snprintf(msg, 256, "Logarithm of %s has been replaced by 0", xstr);
        mp_memory_free(xstr);
        @.Logarithm...replaced by 0@>
        mp_error(
            mp,
            msg,
            "Since I don't take logs of non-positive numbers, I'm zeroing this one.\n"
            "Proceed, with fingers crossed."
        );
        decNumberZero(ret->data.num);
    } else {
        decNumber twofivesix;
        decNumberFromInt32(&twofivesix, 256);
        decNumberLn(ret->data.num, x_orig->data.num, &mp_decimal_data.limitedset);
        mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.limitedset);
        decNumberMultiply(ret->data.num, ret->data.num, &twofivesix, &mp_decimal_data.set);
    }
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ Conversely, the exponential routine calculates $\exp(x/2^8)$, when |x| is
|scaled|.

@c
void mp_decimal_m_exp (MP mp, mp_number *ret, mp_number *x_orig)
{
    decNumber temp, twofivesix;
    decNumberFromInt32(&twofivesix, 256);
    decNumberDivide(&temp, x_orig->data.num, &twofivesix, &mp_decimal_data.set);
    mp_decimal_data.limitedset.status = 0;
    decNumberExp(ret->data.num, &temp, &mp_decimal_data.limitedset);
    if (mp_decimal_data.limitedset.status & DEC_Clamped) {
        if (decNumberIsPositive((decNumber *) x_orig->data.num)) {
            mp->arith_error = 1;
            decNumberCopy(ret->data.num, &mp_decimal_data.EL_GORDO_decNumber);
        } else {
            decNumberZero(ret->data.num);
        }
    }
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.limitedset);
    mp_decimal_data.limitedset.status = 0;
}

@ Given integers |x| and |y|, not both zero, the |n_arg| function returns the
|angle| whose tangent points in the direction $(x,y)$.

@c
void mp_decimal_n_arg (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig)
{
    if (decNumberIsZero((decNumber *) x_orig->data.num) && decNumberIsZero((decNumber *) y_orig->data.num)) {
        mp_error(
            mp,
            "angle(0,0) is taken as zero",
            "The 'angle' between two identical points is undefined. I'm zeroing this one.\n"
            "Proceed, with fingers crossed."
        );
        @.angle(0,0)...zero@>
        decNumberZero(ret->data.num);
    } else {
        decNumber atan2val, oneeighty_angle;
        ret->type = mp_angle_type;
        decNumberFromInt32(&oneeighty_angle, 180 * angle_multiplier);
        decNumberDivide(&oneeighty_angle, &oneeighty_angle, &mp_decimal_data.PI_decNumber, &mp_decimal_data.set);
        checkZero(y_orig->data.num);
        checkZero(x_orig->data.num);
        decNumberAtan2(&atan2val, y_orig->data.num, x_orig->data.num, &mp_decimal_data.set);
        decNumberMultiply(ret->data.num,&atan2val, &oneeighty_angle, &mp_decimal_data.set);
        checkZero(ret->data.num);
    }
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ Conversely, the |n_sin_cos| routine takes an |angle| and produces the sine and
cosine of that angle. The results of this routine are stored in global integer
variables |n_sin| and |n_cos|.

First, we need a decNumber function that calculates sines and cosines using the
Taylor series. This function is fairly optimized.

@c
static void sinecosine(decNumber *theangle, decNumber *c, decNumber *s)
{
    int prec = mp_decimal_data.set.digits/2;
    decNumber p, pxa, fac, cc;
    decNumber n1, n2, p1;
    decNumberZero(c);
    decNumberZero(s);
    if (prec < DECPRECISION_DEFAULT) {
        prec = DECPRECISION_DEFAULT;
    }
    for (int n = 0; n < prec; n++) {
        decNumberFromInt32(&p1, n);
        decNumberFromInt32(&n1, 2*n);
        decNumberPower(&p,  &mp_decimal_data.minusone, &p1, &mp_decimal_data.limitedset);
        if (n == 0) {
            decNumberCopy(&pxa, &mp_decimal_data.one);
        } else {
            decNumberPower(&pxa, theangle, &n1, &mp_decimal_data.limitedset);
        }
        if (2*n < mp_decimal_data.last_cached_factorial) {
            decNumberCopy(&fac,mp_decimal_data.factorials[2*n]);
        } else {
            decNumberCopy(&fac,mp_decimal_data.factorials[mp_decimal_data.last_cached_factorial]);
            for (int i = mp_decimal_data.last_cached_factorial+1; i <= 2*n; i++) {
                decNumberFromInt32(&cc, i);
                decNumberMultiply (&fac, &fac, &cc, &mp_decimal_data.set);
                if (i < FACTORIALS_CACHESIZE) {
                    mp_decimal_data.factorials[i] = mp_memory_allocate(sizeof(decNumber));
                    decNumberCopy(mp_decimal_data.factorials[i], &fac);
                    mp_decimal_data.last_cached_factorial = i;
                }
            }
        }
        decNumberDivide(&pxa, &pxa, &fac, &mp_decimal_data.set);
        decNumberMultiply(&pxa, &pxa, &p, &mp_decimal_data.set);
        decNumberAdd(s, s, &pxa, &mp_decimal_data.set);
        decNumberFromInt32(&n2, 2*n+1);
        decNumberMultiply(&fac, &fac, &n2, &mp_decimal_data.set); /* fac = fac * (2*n+1)*/
        decNumberPower(&pxa, theangle, &n2, &mp_decimal_data.limitedset);
        decNumberDivide(&pxa, &pxa, &fac, &mp_decimal_data.set);
        decNumberMultiply(&pxa, &pxa, &p, &mp_decimal_data.set);
        decNumberAdd(c, c, &pxa, &mp_decimal_data.set);
    }
}

@ Calculate sines and cosines.

@c
void mp_decimal_sin_cos (MP mp, mp_number *z_orig, mp_number *n_cos, mp_number *n_sin)
{
    decNumber rad;
    decNumber one_eighty;
    double tmp = mp_number_to_double(z_orig)/16.0;
    if ((tmp == 90.0)||(tmp == -270)){
        decNumberZero(n_cos->data.num);
        decNumberCopy(n_sin->data.num, &mp_decimal_data.fraction_multiplier_decNumber);
    } else if ((tmp == -90.0)||(tmp == 270.0)) {
        decNumberZero(n_cos->data.num);
        decNumberCopyNegate(n_sin->data.num, &mp_decimal_data.fraction_multiplier_decNumber);
    } else if ((tmp == 180.0) || (tmp == -180.0)) {
        decNumberCopyNegate(n_cos->data.num, &mp_decimal_data.fraction_multiplier_decNumber);
        decNumberZero(n_sin->data.num);
    } else {
        decNumberFromInt32(&one_eighty, 180 * 16);
        decNumberMultiply(&rad, z_orig->data.num, &mp_decimal_data.PI_decNumber, &mp_decimal_data.set);
        decNumberDivide(&rad, &rad, &one_eighty, &mp_decimal_data.set);
        sinecosine(&rad, n_sin->data.num, n_cos->data.num);
        decNumberMultiply(n_cos->data.num, n_cos->data.num, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
        decNumberMultiply(n_sin->data.num, n_sin->data.num, &mp_decimal_data.fraction_multiplier_decNumber, &mp_decimal_data.set);
    }
    mp_decnumber_check(mp, n_cos->data.num, &mp_decimal_data.set);
    mp_decnumber_check(mp, n_sin->data.num, &mp_decimal_data.set);
}

@ This is the {\tt http://www-cs-faculty.stanford.edu/~uno/programs/rng.c}
with  small cosmetic modifications.

@c
# define KK            100                /* the long lag  */
# define LL            37                 /* the short lag */
# define MM            (1L<<30)           /* the modulus   */
# define mod_diff(x,y) (((x)-(y))&(MM-1)) /* subtraction mod MM */
# define QUALITY       1009               /* recommended quality level for high-res use */
# define TT            70                 /* guaranteed separation between streams */
# define is_odd(x)     ((x)&1)            /* units bit of x */

typedef struct mp_decimal_random_info {
    long  x[KK];
    long  buf[QUALITY];
    long  dummy;
    long  started;
    long *ptr;
} mp_decimal_random_info;

mp_decimal_random_info mp_decimal_random_data = {
    .dummy   = -1,
    .started = -1,
    .ptr     = &mp_decimal_random_data.dummy
};

/* put n new random numbers in aa */
/* long aa[] destination */
/* int n     array length (must be at least KK) */

static void ran_array(long aa[],int n)
{
    int i, j;
    for (j = 0; j < KK;j++) {
        aa[j] = mp_decimal_random_data.x[j];
    }
    for (; j < n; j++) {
        aa[j] = mod_diff(aa[j - KK], aa[j - LL]);
    }
    for (i = 0; i < LL ; i++, j++) {
        mp_decimal_random_data.x[i] = mod_diff(aa[j - KK], aa[j - LL]);
    }
    for (;i < KK; i++, j++) {
        mp_decimal_random_data.x[i] = mod_diff(aa[j - KK], mp_decimal_random_data.x[i - LL]);
    }
}

/*
    the following routines are from exercise 3.6--15L after calling |ran_start|,
    get new randoms by, e.g., "|x=ran_arr_next()|"

    Do this before using |ran_array|, |long seed| selector for different
    streams.
*/

static void ran_start(long seed)
{
    int t, j;
    long x[KK+KK-1]; /* the preparation buffer */
    long ss=(seed+2)&(MM-2);
    for (j = 0; j < KK; j++) {
        /* bootstrap the buffer */
        x[j] = ss;
        ss <<= 1;
        if (ss >= MM) {
            /* cyclic shift 29 bits */
            ss -= MM - 2;
        }
    }
    /* make x[1] (and only x[1]) odd */
    x[1]++;
    for (ss = seed & (MM-1), t = TT - 1; t;) {
        for (j = KK - 1; j > 0; j--) {
            /* square */
            x[j + j] = x[j];
            x[j + j - 1] = 0;
        }
        for (j = KK + KK - 2; j >= KK; j--) {
            x[j - (KK - LL)] = mod_diff(x[j - (KK - LL)], x[j]);
            x[j - KK] = mod_diff(x[j - KK], x[j]);
        }
        if (is_odd(ss)) {
            /* "multiply by z" */
            for (j = KK; j > 0; j--) {
                x[j] = x[j-1];
            }
            x[0] = x[KK];
            /* shift the buffer cyclically */
            x[LL] = mod_diff(x[LL], x[KK]);
        }
        if (ss) {
            ss >>= 1;
        } else {
            t--;
        }
    }
    for (j = 0; j < LL; j++) {
        mp_decimal_random_data.x[j + KK -LL] = x[j];
    }
    for (; j < KK; j++) {
        mp_decimal_random_data.x[j - LL] = x[j];
    }
    for (j = 0; j < 10; j++) {
        /* warm things up */
        ran_array(x, KK + KK - 1);
    }
    mp_decimal_random_data.ptr = &mp_decimal_random_data.started;
}

# define ran_arr_next() (*mp_decimal_random_data.ptr>=0? *mp_decimal_random_data.ptr++: ran_arr_cycle())

static long ran_arr_cycle(void)
{
    if (mp_decimal_random_data.ptr == &mp_decimal_random_data.dummy) {
        /* the user forgot to initialize */
        ran_start(314159L);
    }
    ran_array(mp_decimal_random_data.buf, QUALITY);
    mp_decimal_random_data.buf[KK] = -1;
    mp_decimal_random_data.ptr = mp_decimal_random_data.buf + 1;
    return mp_decimal_random_data.buf[0];
}

@ To initialize the |randoms| table, we call the following routine.

@c
void mp_init_randoms (MP mp, int seed)
{
    int k = 1; /* more or less random integers */
    int j = abs(seed);
    while (j >= fraction_one) {
        j = j/2;
    }
    for (int i = 0; i <= 54; i++) {
        int jj = k;
        k = j - k;
        j = jj;
        if (k < 0) {
            k += fraction_one;
        }
        decNumberFromInt32(mp->randoms[(i * 21) % 55].data.num, j);
    }
    /* \quote {warm up} the array */
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    ran_start((unsigned long) seed);
}

@ @c
void mp_decimal_number_modulo(mp_number *a, mp_number *b)
{
    decNumberRemainder(a->data.num, a->data.num, b->data.num, &mp_decimal_data.set);
}

@ To consume a random integer for the uniform generator, the program below will
say |next_unif_random|.

@c
static void mp_next_unif_random (MP mp, mp_number *ret)
{
    decNumber a;
    decNumber b;
    unsigned long int op = (unsigned)ran_arr_next();
    (void) mp;
    decNumberFromInt32(&a, op);
    decNumberFromInt32(&b, MM);
    decNumberDivide(&a, &a, &b, &mp_decimal_data.set); /* a = a/b */
    decNumberCopy(ret->data.num, &a);
    mp_decnumber_check(mp, ret->data.num, &mp_decimal_data.set);
}

@ To consume a random fraction, the program below will say |next_random|.

@c
static void mp_next_random (MP mp, mp_number *ret)
{
    if (mp->j_random == 0) {
        mp_new_randoms(mp);
    } else {
        mp->j_random = mp->j_random-1;
    }
    mp_number_clone(ret, &(mp->randoms[mp->j_random]));
}

@ To produce a uniform random number in the range |0<=u<x| or |0>=u>x| or
|0=u=x|, given a |scaled| value~|x|, we proceed as shown here.

Note that the call of |take_fraction| will produce the values 0 and~|x| with
about half the probability that it will produce any other particular values
between 0 and~|x|, because it rounds its answers.

@c
static void mp_decimal_m_unif_rand (MP mp, mp_number *ret, mp_number *x_orig)
{
    mp_number x, abs_x, u, y; /* |y| is trial value */
    mp_allocate_number(mp, &y, mp_fraction_type);
    mp_allocate_clone(mp, &x, mp_scaled_type, x_orig);
    mp_allocate_abs(mp, &abs_x, mp_scaled_type, &x);
    mp_allocate_number(mp, &u, mp_scaled_type);
    mp_next_unif_random(mp, &u);
    decNumberMultiply(y.data.num, abs_x.data.num, u.data.num, &mp_decimal_data.set);
    if (mp_number_equal(&y, &abs_x)) {
        mp_number_clone(ret, &((math_data *)mp->math)->md_zero_t);
    } else if (mp_number_greater(&x, &((math_data *)mp->math)->md_zero_t)) {
        mp_number_clone(ret, &y);
    } else {
        mp_number_negated_clone(ret, &y);
    }
    mp_free_number(mp, &x);
    mp_free_number(mp, &abs_x);
    mp_free_number(mp, &y);
    mp_free_number(mp, &u);
}

@ Finally, a normal deviate with mean zero and unit standard deviation can
readily be obtained with the ratio method (Algorithm 3.4.1R in {\sl The Art of
Computer Programming}).

@c
static void mp_decimal_m_norm_rand (MP mp, mp_number *ret)
{
    mp_number abs_x, u, r, la, xa;
    mp_allocate_number(mp, &la, mp_scaled_type);
    mp_allocate_number(mp, &xa, mp_scaled_type);
    mp_allocate_number(mp, &abs_x, mp_scaled_type);
    mp_allocate_number(mp, &u, mp_scaled_type);
    mp_allocate_number(mp, &r, mp_scaled_type);
    do {
        do {
            mp_number v; /* maybe move outside loop */
            mp_allocate_number(mp, &v, mp_scaled_type);
            mp_next_random(mp, &v);
            mp_number_subtract(&v, &((math_data *)mp->math)->md_fraction_half_t);
            mp_decimal_number_take_fraction(mp, &xa, &((math_data *)mp->math)->md_sqrt_8_e_k, &v);
            mp_free_number(mp, &v);
            mp_next_random(mp, &u);
            mp_number_clone(&abs_x, &xa);
            mp_decimal_abs(&abs_x);
        } while (! mp_number_less(&abs_x, &u));
        mp_decimal_number_make_fraction(mp, &r, &xa, &u);
        mp_number_clone(&xa, &r);
        mp_decimal_m_log(mp, &la, &u);
        mp_set_decimal_from_subtraction(&la, &((math_data *)mp->math)->md_twelve_ln_2_k, &la);
    } while (mp_ab_vs_cd(&((math_data *)mp->math)->md_one_k, &la, &xa, &xa) < 0);
    mp_number_clone(ret, &xa);
    mp_free_number(mp, &r);
    mp_free_number(mp, &abs_x);
    mp_free_number(mp, &la);
    mp_free_number(mp, &xa);
    mp_free_number(mp, &u);
}
