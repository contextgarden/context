% This file is part of MetaPost. The MetaPost program is in the public domain.

@ Introduction.

@c
# include "mpconfig.h"
# include "mpmathdouble.h"

@h

@ @c
@<Declarations@>

@ @(mpmathdouble.h@>=
# ifndef MPMATHDOUBLE_H
# define MPMATHDOUBLE_H 1

# include "mp.h"

math_data *mp_initialize_double_math (MP mp);

# endif

@* Math initialization.

First, here are some very important constants.

@d PI                      3.1415926535897932384626433832795028841971
@d fraction_multiplier     4096.0
@d angle_multiplier        16.0

@d coef_bound              ((7.0/3.0)*fraction_multiplier) /* |fraction| approximation to 7/3 */
@d fraction_threshold      0.04096                         /* a |fraction| coefficient less than this is zeroed */
@d half_fraction_threshold (fraction_threshold/2)          /* half of |fraction_threshold| */
@d scaled_threshold        0.000122                        /* a |scaled| coefficient less than this is zeroed */
@d half_scaled_threshold   (scaled_threshold/2)            /* half of |scaled_threshold| */
@d near_zero_angle         (0.0256*angle_multiplier)       /* an angle of about 0.0256 */
@d p_over_v_threshold      0x80000                         /* TODO */
@d equation_threshold      0.001
@d warning_limit           pow(2.0,52.0)                   /* this is a large value that can just be expressed without loss of precision */
@d epsilon                 pow(2.0,-52.0)

@d unity                   1.0
@d two                     2.0
@d three                   3.0
@d half_unit               0.5
@d three_quarter_unit      0.75
@d EL_GORDO                (DBL_MAX/2.0-1.0)  /* the largest value that \MP\ likes. */
@d negative_EL_GORDO       (-EL_GORDO)
@d one_third_EL_GORDO      (EL_GORDO/3.0)

@d fraction_half           (0.5*fraction_multiplier)
@d fraction_one            (1.0*fraction_multiplier)
@d fraction_two            (2.0*fraction_multiplier)
@d fraction_three          (3.0*fraction_multiplier)
@d fraction_four           (4.0*fraction_multiplier)

@d no_crossing             (fraction_one + 1)
@d one_crossing            fraction_one
@d zero_crossing           0

@d one_eighty_deg          (180.0*angle_multiplier)
@d negative_one_eighty_deg (-180.0*angle_multiplier)
@d three_sixty_deg         (360.0*angle_multiplier)
@d odd(A)                  (abs(A)%2==1)

@d two_to_the(A)           (1<<(unsigned)(A))
@d set_cur_cmd(A)          mp->cur_mod_->command = (A)
@d set_cur_mod(A)          mp->cur_mod_->data.n.data.dval = (A)

@ Here are the functions that are static as they are not used elsewhere.

@<Declarations@>=
static int    mp_ab_vs_cd                        (mp_number *a, mp_number *b, mp_number *c, mp_number *d);
static void   mp_allocate_abs                    (MP mp, mp_number *n, mp_number_type t, mp_number *v);
static void   mp_allocate_clone                  (MP mp, mp_number *n, mp_number_type t, mp_number *v);
static void   mp_allocate_double                 (MP mp, mp_number *n, double v);
static void   mp_allocate_number                 (MP mp, mp_number *n, mp_number_type t);
static int    mp_double_ab_vs_cd                 (mp_number *a, mp_number *b, mp_number *c, mp_number *d);
static void   mp_double_abs                      (mp_number *A);
static void   mp_double_crossing_point           (MP mp, mp_number *ret, mp_number *a, mp_number *b, mp_number *c);
static void   mp_double_fraction_to_round_scaled (mp_number *x);
static void   mp_double_m_exp                    (MP mp, mp_number *ret, mp_number *x_orig);
static void   mp_double_m_log                    (MP mp, mp_number *ret, mp_number *x_orig);
static void   mp_double_m_norm_rand              (MP mp, mp_number *ret);
static void   mp_double_m_unif_rand              (MP mp, mp_number *ret, mp_number *x_orig);
static void   mp_double_n_arg                    (MP mp, mp_number *ret, mp_number *x, mp_number *y);
static void   mp_double_number_make_fraction     (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_double_number_make_scaled       (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_double_number_take_fraction     (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_double_number_take_scaled       (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void   mp_double_power_of                 (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void   mp_double_print_number             (MP mp, mp_number *n);
static void   mp_double_pyth_add                 (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void   mp_double_pyth_sub                 (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void   mp_double_scan_fractional_token    (MP mp, int n);
static void   mp_double_scan_numeric_token       (MP mp, int n);
static void   mp_double_set_precision            (MP mp);
static void   mp_double_sin_cos                  (MP mp, mp_number *z_orig, mp_number *n_cos, mp_number *n_sin);
static void   mp_double_slow_add                 (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig);
static void   mp_double_square_rt                (MP mp, mp_number *ret, mp_number *x_orig);
static void   mp_double_velocity                 (MP mp, mp_number *ret, mp_number *st, mp_number *ct, mp_number *sf, mp_number *cf, mp_number *t);
static void   mp_free_double_math                (MP mp);
static void   mp_free_number                     (MP mp, mp_number *n);
static void   mp_init_randoms                    (MP mp, int seed);
static void   mp_number_abs_clone                (mp_number *A, mp_number *B);
static void   mp_number_add                      (mp_number *A, mp_number *B);
static void   mp_number_add_scaled               (mp_number *A, int B); /* also for negative B */
static void   mp_number_angle_to_scaled          (mp_number *A);
static void   mp_number_clone                    (mp_number *A, mp_number *B);
static void   mp_number_divide_int               (mp_number *A, int B);
static void   mp_number_double                   (mp_number *A);
static int    mp_number_equal                    (mp_number *A, mp_number *B);
static void   mp_number_floor                    (mp_number *i);
static void   mp_number_fraction_to_scaled       (mp_number *A);
static int    mp_number_greater                  (mp_number *A, mp_number *B);
static void   mp_number_half                     (mp_number *A);
static int    mp_number_less                     (mp_number *A, mp_number *B);
static void   mp_number_modulo                   (mp_number *a, mp_number *b);
static void   mp_number_multiply_int             (mp_number *A, int B);
static void   mp_number_negate                   (mp_number *A);
static void   mp_number_negated_clone            (mp_number *A, mp_number *B);
static int    mp_number_nonequalabs              (mp_number *A, mp_number *B);
static int    mp_number_odd                      (mp_number *A);
static void   mp_number_scaled_to_angle          (mp_number *A);
static void   mp_number_scaled_to_fraction       (mp_number *A);
static void   mp_number_subtract                 (mp_number *A, mp_number *B);
static void   mp_number_swap                     (mp_number *A, mp_number *B);
static int    mp_number_to_boolean               (mp_number *A);
static double mp_number_to_double                (mp_number *A);
static int    mp_number_to_int                   (mp_number *A);
static int    mp_number_to_scaled                (mp_number *A);
static int    mp_round_unscaled                  (mp_number *x_orig);
static void   mp_set_double_from_addition        (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_double_from_boolean         (mp_number *A, int B);
static void   mp_set_double_from_div             (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_double_from_double          (mp_number *A, double B);
static void   mp_set_double_from_int             (mp_number *A, int B);
static void   mp_set_double_from_int_div         (mp_number *A, mp_number *B, int C);
static void   mp_set_double_from_int_mul         (mp_number *A, mp_number *B, int C);
static void   mp_set_double_from_mul             (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_double_from_of_the_way      (MP mp, mp_number *A, mp_number *t, mp_number *B, mp_number *C);
static void   mp_set_double_from_scaled          (mp_number *A, int B);
static void   mp_set_double_from_subtraction     (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_double_half_from_addition   (mp_number *A, mp_number *B, mp_number *C);
static void   mp_set_double_half_from_subtraction(mp_number *A, mp_number *B, mp_number *C);
static void   mp_wrapup_numeric_token            (MP mp, unsigned char *start, unsigned char *stop);
static char  *mp_double_number_tostring          (MP mp, mp_number *n);

inline double mp_double_make_fraction (double p, double q) { return (p / q) * fraction_multiplier; }
inline double mp_double_take_fraction (double p, double q) { return (p * q) / fraction_multiplier; }
inline double mp_double_make_scaled   (double p, double q) { return  p / q; }

@c
math_data *mp_initialize_double_math(MP mp)
{
    math_data *math = (math_data *) mp_memory_allocate(sizeof(math_data));
    /* alloc */
    math->md_allocate        = mp_allocate_number;
    math->md_free            = mp_free_number;
    math->md_allocate_clone  = mp_allocate_clone;
    math->md_allocate_abs    = mp_allocate_abs;
    math->md_allocate_double = mp_allocate_double;
    /* precission */
    mp_allocate_number(mp, &math->md_precision_default, mp_scaled_type);
    mp_allocate_number(mp, &math->md_precision_max, mp_scaled_type);
    mp_allocate_number(mp, &math->md_precision_min, mp_scaled_type);
    /* here are the constants for |scaled| objects */
    mp_allocate_number(mp, &math->md_epsilon_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_inf_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_negative_inf_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_warning_limit_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_one_third_inf_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_unity_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_two_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_three_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_half_unit_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_three_quarter_unit_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_zero_t, mp_scaled_type);
    /* |fractions| */
    mp_allocate_number(mp, &math->md_arc_tol_k, mp_fraction_type);
    mp_allocate_number(mp, &math->md_fraction_one_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_fraction_half_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_fraction_three_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_fraction_four_t, mp_fraction_type);
    /* |angles| */
    mp_allocate_number(mp, &math->md_three_sixty_deg_t, mp_angle_type);
    mp_allocate_number(mp, &math->md_one_eighty_deg_t, mp_angle_type);
    mp_allocate_number(mp, &math->md_negative_one_eighty_deg_t, mp_angle_type);
    /* various approximations */
    mp_allocate_number(mp, &math->md_one_k, mp_scaled_type);
    mp_allocate_number(mp, &math->md_sqrt_8_e_k, mp_scaled_type);
    mp_allocate_number(mp, &math->md_twelve_ln_2_k, mp_fraction_type);
    mp_allocate_number(mp, &math->md_coef_bound_k, mp_fraction_type);
    mp_allocate_number(mp, &math->md_coef_bound_minus_1, mp_fraction_type);
    mp_allocate_number(mp, &math->md_twelvebits_3, mp_scaled_type);
    mp_allocate_number(mp, &math->md_twentysixbits_sqrt2_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_twentyeightbits_d_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_twentysevenbits_sqrt2_d_t, mp_fraction_type);
    /* thresholds */
    mp_allocate_number(mp, &math->md_fraction_threshold_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_half_fraction_threshold_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_scaled_threshold_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_half_scaled_threshold_t, mp_scaled_type);
    mp_allocate_number(mp, &math->md_near_zero_angle_t, mp_angle_type);
    mp_allocate_number(mp, &math->md_p_over_v_threshold_t, mp_fraction_type);
    mp_allocate_number(mp, &math->md_equation_threshold_t, mp_scaled_type);
    /* initializations */
    math->md_precision_default.data.dval         = 16 * unity;
    math->md_precision_max.data.dval             = 16 * unity;
    math->md_precision_min.data.dval             = 16 * unity;
    math->md_epsilon_t.data.dval                 = epsilon;
    math->md_inf_t.data.dval                     = EL_GORDO;
    math->md_negative_inf_t.data.dval            = negative_EL_GORDO;
    math->md_one_third_inf_t.data.dval           = one_third_EL_GORDO;
    math->md_warning_limit_t.data.dval           = warning_limit;
    math->md_unity_t.data.dval                   = unity;
    math->md_two_t.data.dval                     = two;
    math->md_three_t.data.dval                   = three;
    math->md_half_unit_t.data.dval               = half_unit;
    math->md_three_quarter_unit_t.data.dval      = three_quarter_unit;
    math->md_arc_tol_k.data.dval                 = (unity/4096);                /* quit when change in arc length estimate reaches this */
    math->md_fraction_one_t.data.dval            = fraction_one;
    math->md_fraction_half_t.data.dval           = fraction_half;
    math->md_fraction_three_t.data.dval          = fraction_three;
    math->md_fraction_four_t.data.dval           = fraction_four;
    math->md_three_sixty_deg_t.data.dval         = three_sixty_deg;
    math->md_one_eighty_deg_t.data.dval          = one_eighty_deg;
    math->md_negative_one_eighty_deg_t.data.dval = negative_one_eighty_deg;
    math->md_one_k.data.dval                     = 1.0/64 ;
    math->md_sqrt_8_e_k.data.dval                = 1.71552776992141359295;      /* $2^{16}\sqrt{8/e}\approx 112428.82793$ */
    math->md_twelve_ln_2_k.data.dval             = 8.31776616671934371292 *256; /* $2^{24}\cdot12\ln2\approx139548959.6165$ */
    math->md_coef_bound_k.data.dval              = coef_bound;
    math->md_coef_bound_minus_1.data.dval        = coef_bound - 1/65536.0;
    math->md_twelvebits_3.data.dval              = 1365 / 65536.0;              /* $1365\approx 2^{12}/3$ */
    math->md_twentysixbits_sqrt2_t.data.dval     = 94906266 / 65536.0;          /* $2^{26}\sqrt2\approx94906265.62$ */
    math->md_twentyeightbits_d_t.data.dval       = 35596755 / 65536.0;          /* $2^{28}d\approx35596754.69$ */
    math->md_twentysevenbits_sqrt2_d_t.data.dval = 25170707 / 65536.0;          /* $2^{27}\sqrt2\,d\approx25170706.63$ */
    math->md_fraction_threshold_t.data.dval      = fraction_threshold;
    math->md_half_fraction_threshold_t.data.dval = half_fraction_threshold;
    math->md_scaled_threshold_t.data.dval        = scaled_threshold;
    math->md_half_scaled_threshold_t.data.dval   = half_scaled_threshold;
    math->md_near_zero_angle_t.data.dval         = near_zero_angle;
    math->md_p_over_v_threshold_t.data.dval      = p_over_v_threshold;
    math->md_equation_threshold_t.data.dval      = equation_threshold;
    /* functions */
    math->md_from_int                 = mp_set_double_from_int;
    math->md_from_boolean             = mp_set_double_from_boolean;
    math->md_from_scaled              = mp_set_double_from_scaled;
    math->md_from_double              = mp_set_double_from_double;
    math->md_from_addition            = mp_set_double_from_addition;
    math->md_half_from_addition       = mp_set_double_half_from_addition;
    math->md_from_subtraction         = mp_set_double_from_subtraction;
    math->md_half_from_subtraction    = mp_set_double_half_from_subtraction;
    math->md_from_oftheway            = mp_set_double_from_of_the_way;
    math->md_from_div                 = mp_set_double_from_div;
    math->md_from_mul                 = mp_set_double_from_mul;
    math->md_from_int_div             = mp_set_double_from_int_div;
    math->md_from_int_mul             = mp_set_double_from_int_mul;
    math->md_negate                   = mp_number_negate;
    math->md_add                      = mp_number_add;
    math->md_subtract                 = mp_number_subtract;
    math->md_half                     = mp_number_half;
    math->md_do_double                = mp_number_double;
    math->md_abs                      = mp_double_abs;
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
    math->md_fraction_to_round_scaled = mp_double_fraction_to_round_scaled;
    math->md_make_scaled              = mp_double_number_make_scaled;
    math->md_make_fraction            = mp_double_number_make_fraction;
    math->md_take_fraction            = mp_double_number_take_fraction;
    math->md_take_scaled              = mp_double_number_take_scaled;
    math->md_velocity                 = mp_double_velocity;
    math->md_n_arg                    = mp_double_n_arg;
    math->md_m_log                    = mp_double_m_log;
    math->md_m_exp                    = mp_double_m_exp;
    math->md_m_unif_rand              = mp_double_m_unif_rand;
    math->md_m_norm_rand              = mp_double_m_norm_rand;
    math->md_pyth_add                 = mp_double_pyth_add;
    math->md_pyth_sub                 = mp_double_pyth_sub;
    math->md_power_of                 = mp_double_power_of;
    math->md_fraction_to_scaled       = mp_number_fraction_to_scaled;
    math->md_scaled_to_fraction       = mp_number_scaled_to_fraction;
    math->md_scaled_to_angle          = mp_number_scaled_to_angle;
    math->md_angle_to_scaled          = mp_number_angle_to_scaled;
    math->md_init_randoms             = mp_init_randoms;
    math->md_sin_cos                  = mp_double_sin_cos;
    math->md_slow_add                 = mp_double_slow_add;
    math->md_sqrt                     = mp_double_square_rt;
    math->md_print                    = mp_double_print_number;
    math->md_tostring                 = mp_double_number_tostring;
    math->md_modulo                   = mp_number_modulo;
    math->md_ab_vs_cd                 = mp_ab_vs_cd;
    math->md_crossing_point           = mp_double_crossing_point;
    math->md_scan_numeric             = mp_double_scan_numeric_token;
    math->md_scan_fractional          = mp_double_scan_fractional_token;
    math->md_free_math                = mp_free_double_math;
    math->md_set_precision            = mp_double_set_precision;
    return math;
}

void mp_double_set_precision (MP mp)
{
    (void) mp;
}

void mp_free_double_math (MP mp)
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
    mp_memory_free(mp->math);
}

@ Creating an destroying |mp_number| objects

@ @c
void mp_allocate_number (MP mp, mp_number *n, mp_number_type t)
{
    (void) mp;
    n->data.dval = 0.0;
    n->type = t;
}

@ @c
void mp_allocate_clone (MP mp, mp_number *n, mp_number_type t, mp_number *v)
{
    (void) mp;
    n->type = t;
    n->data.dval = v->data.dval;
}

@ @c
void mp_allocate_abs (MP mp, mp_number *n, mp_number_type t, mp_number *v)
{
    (void) mp;
    n->type = t;
    n->data.dval = fabs(v->data.dval);
}

@ @c
void mp_allocate_double (MP mp, mp_number *n, double v)
{
    (void) mp;
    n->type = mp_scaled_type;
    n->data.dval = v;
}

@ @c
void mp_free_number (MP mp, mp_number *n)
{
    (void) mp;
    n->type = mp_nan_type;
}

@ Here are the low-level functions on |mp_number| items, setters first.

@c
void mp_set_double_from_int(mp_number *A, int B)
{
    A->data.dval = B;
}

void mp_set_double_from_boolean(mp_number *A, int B)
{
    A->data.dval = B;
}

void mp_set_double_from_scaled(mp_number *A, int B)
{
    A->data.dval = B / 65536.0;
}

void mp_set_double_from_double(mp_number *A, double B)
{
    A->data.dval = B;
}

void mp_set_double_from_addition(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.dval = B->data.dval + C->data.dval;
}

void mp_set_double_half_from_addition(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.dval = (B->data.dval + C->data.dval) / 2.0;
}

void mp_set_double_from_subtraction(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.dval = B->data.dval - C->data.dval;
}

void mp_set_double_half_from_subtraction(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.dval = (B->data.dval - C->data.dval) / 2.0;
}

void mp_set_double_from_div(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.dval = B->data.dval / C->data.dval;
}

void mp_set_double_from_mul(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.dval = B->data.dval * C->data.dval;
}

void mp_set_double_from_int_div(mp_number *A, mp_number *B, int C)
{
    A->data.dval = B->data.dval / C;
}

void mp_set_double_from_int_mul(mp_number *A, mp_number *B, int C)
{
    A->data.dval = B->data.dval * C;
}

void mp_set_double_from_of_the_way (MP mp, mp_number *A, mp_number *t, mp_number *B, mp_number *C)
{
    (void) mp;
    A->data.dval = B->data.dval - mp_double_take_fraction(B->data.dval - C->data.dval, t->data.dval);
}

void mp_number_negate(mp_number *A)
{
    A->data.dval = -A->data.dval;
    if (A->data.dval == -0.0) {
        A->data.dval = 0.0;
    }
}

void mp_number_add(mp_number *A, mp_number *B)
{
    A->data.dval = A->data.dval + B->data.dval;
}

void mp_number_subtract(mp_number *A, mp_number *B)
{
    A->data.dval = A->data.dval - B->data.dval;
}

void mp_number_half(mp_number *A)
{
    A->data.dval = A->data.dval / 2.0;
}

void mp_number_double(mp_number *A)
{
    A->data.dval = A->data.dval * 2.0;
}

void mp_number_add_scaled(mp_number *A, int B)
{
    /* also for negative B */
    A->data.dval = A->data.dval + (B / 65536.0);
}

void mp_number_multiply_int(mp_number *A, int B)
{
    A->data.dval = (double)(A->data.dval * B);
}

void mp_number_divide_int(mp_number *A, int B)
{
    A->data.dval = A->data.dval / (double)B;
}

void mp_double_abs(mp_number *A)
{
    A->data.dval = fabs(A->data.dval);
}

void mp_number_clone(mp_number *A, mp_number *B)
{
    A->data.dval = B->data.dval;
}

void mp_number_negated_clone(mp_number *A, mp_number *B)
{
    A->data.dval = -B->data.dval;
    if (A->data.dval == -0.0) {
        A->data.dval = 0.0;
    }
}

void mp_number_abs_clone(mp_number *A, mp_number *B)
{
    A->data.dval = fabs(B->data.dval);
}

void mp_number_swap(mp_number *A, mp_number *B)
{
    double swap_tmp = A->data.dval;
    A->data.dval = B->data.dval;
    B->data.dval = swap_tmp;
}

void mp_number_fraction_to_scaled(mp_number *A)
{
    A->type = mp_scaled_type;
    A->data.dval = A->data.dval / fraction_multiplier;
}

void mp_number_angle_to_scaled(mp_number *A)
{
    A->type = mp_scaled_type;
    A->data.dval = A->data.dval / angle_multiplier;
}

void mp_number_scaled_to_fraction(mp_number *A)
{
    A->type = mp_fraction_type;
    A->data.dval = A->data.dval * fraction_multiplier;
}

void mp_number_scaled_to_angle(mp_number *A)
{
    A->type = mp_angle_type;
    A->data.dval = A->data.dval * angle_multiplier;
}

@ Query functions
@c
int mp_number_to_scaled(mp_number *A)
{
    return (int) lround(A->data.dval * 65536.0);
}

int mp_number_to_int(mp_number *A)
{
    return (int) (A->data.dval);
}

int mp_number_to_boolean(mp_number *A)
{
    return (int) (A->data.dval);
}

double mp_number_to_double(mp_number *A)
{
    return A->data.dval;
}

int mp_number_odd(mp_number *A)
{
    return odd((int) lround(A->data.dval));
}

int mp_number_equal(mp_number *A, mp_number *B)
{
    return A->data.dval == B->data.dval;
}

int mp_number_greater(mp_number *A, mp_number *B)
{
    return A->data.dval > B->data.dval;
}

int mp_number_less(mp_number *A, mp_number *B)
{
    return A->data.dval < B->data.dval;
}

int mp_number_nonequalabs(mp_number *A, mp_number *B)
{
    return fabs(A->data.dval) != fabs(B->data.dval);
}

@ Fixed-point arithmetic is done on {\sl scaled integers} that are multiples of
$2^{-16}$. In other words, a binary point is assumed to be sixteen bit positions
from the right end of a binary computer word.

@ One of \MP's most common operations is the calculation of $\lfloor {a+b\over2}
\rfloor$, the midpoint of two given integers |a| and~|b|. The most decent way to
do this is to write |(a+b)/2|; but on many machines it is more efficient to
calculate |(a+b)>>1|.

Therefore the midpoint operation will always be denoted by |half(a+b)| in this
program. If \MP\ is being implemented with languages that permit binary shifting,
the |half| macro should be changed to make this operation as efficient as
possible. Since some systems have shift operators that can only be trusted to
work on positive numbers, there is also a macro |halfp| that is used only when
the quantity being halved is known to be positive or zero.

@ Here is a procedure analogous to |print_int|. The current version is fairly
stupid, and it is not round-trip safe, but this is good enough for a beta test.

@c
char *mp_double_number_tostring (MP mp, mp_number *n)
{
    static char set[64];
    int l = 0;
    char *ret = mp_memory_allocate(64);
    (void) mp;
    snprintf(set, 64, "%.17g", n->data.dval);
    while (set[l] == ' ') {
        l++;
    }
    strcpy(ret, set+l);
    return ret;
}

@ @c
void mp_double_print_number (MP mp, mp_number *n)
{
    char *str = mp_double_number_tostring(mp, n);
    mp_print_e_str(mp, str);
    mp_memory_free(str);
}

@ Addition is not always checked to make sure that it doesn't overflow, but in
places where overflow isn't too unlikely the |slow_add| routine is used.

@c
void mp_double_slow_add (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig)
{
    double x = x_orig->data.dval;
    double y = y_orig->data.dval;
    if (x >= 0.0) {
        if (y <= EL_GORDO - x) {
            ret->data.dval = x + y;
        } else {
            mp->arith_error = 1;
            ret->data.dval = EL_GORDO;
        }
    } else if (-y <= EL_GORDO + x) {
        ret->data.dval = x + y;
    } else {
        mp->arith_error = 1;
        ret->data.dval = negative_EL_GORDO;
    }
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
void mp_double_number_make_fraction (MP mp, mp_number *ret, mp_number *p, mp_number *q) {
    (void) mp;
    ret->data.dval = mp_double_make_fraction(p->data.dval, q->data.dval);
}

@ The dual of |make_fraction| is |take_fraction|, which multiplies a given
integer~|q| by a fraction~|f|. When the operands are positive, it computes
$p=\lfloor qf/2^{28}+{1\over2}\rfloor$, a symmetric function of |q| and~|f|.

This routine is even more \quote {inner loopy} than |make_fraction|; the present
implementation consumes almost 20\pct! of \MP's computation time during typical
jobs, so a machine-language substitute is advisable. @^inner loop@> @^system
dependencies@>

@c
void mp_double_number_take_fraction (MP mp, mp_number *ret, mp_number *p, mp_number *q) {
   (void) mp;
   ret->data.dval = mp_double_take_fraction(p->data.dval, q->data.dval);
}

@ When we want to multiply something by a |scaled| quantity, we use a scheme
analogous to |take_fraction| but with a different scaling. Given positive
operands, |take_scaled| computes the quantity $p=\lfloor
qf/2^{16}+{1\over2}\rfloor$.

Once again it is a good idea to use a machine-language replacement if possible;
otherwise |take_scaled| will use more than 2\pct! of the running time when the
Computer Modern fonts are being generated. @^inner loop@>

@c
void mp_double_number_take_scaled (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    (void) mp;
    ret->data.dval = p_orig->data.dval * q_orig->data.dval;
}

@ For completeness, there's also |make_scaled|, which computes a quotient as a
|scaled| number instead of as a |fraction|. In other words, the result is
$\lfloor2^{16}p/q+{1\over2}\rfloor$, if the operands are positive. \ (This
procedure is not used especially often, so it is not part of \MP's inner loop.)

@c
void mp_double_number_make_scaled (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    (void) mp;
    ret->data.dval = p_orig->data.dval / q_orig->data.dval;
}

@ @* Scanning numbers in the input.

@ @c
void mp_wrapup_numeric_token (MP mp, unsigned char *start, unsigned char *stop)
{
    double result;
    char *end = (char *) stop;
    errno = 0;
    result = strtod((char *) start, &end);
    if (errno == 0) {
        set_cur_mod(result);
        if (result >= warning_limit) {
            if (internal_value(mp_warning_check_internal).data.dval > 0 && (mp->scanner_status != mp_tex_flushing_state)) {
                char msg[256];
                mp_snprintf(msg, 256, "Number is too large (%g)", result);
                @.Number is too large@>
                mp_error(
                    mp,
                    msg,
                    "Continue and I'll try to cope with that big value; but it might be dangerous."
                    "(Set warningcheck := 0 to suppress this message.)"
                );
            }
        }
    } else if (mp->scanner_status != mp_tex_flushing_state) {
        mp_error(
            mp,
            "Enormous number has been reduced.",
            "I could not handle this number specification probably because it is out of"
            "range."
        );
        @.Enormous number...@>
        set_cur_mod(EL_GORDO);
    }
    set_cur_cmd(mp_numeric_command);
}

@ @c
static void mp_double_aux_find_exponent (MP mp)
{
    if (mp->buffer[mp->cur_input.loc_field] == 'e' || mp->buffer[mp->cur_input.loc_field] == 'E') {
        mp->cur_input.loc_field++;
        if (!(mp->buffer[mp->cur_input.loc_field] == '+'
           || mp->buffer[mp->cur_input.loc_field] == '-'
           || mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class)) {
            mp->cur_input.loc_field--;
            return;
        }
        if (mp->buffer[mp->cur_input.loc_field] == '+'
         || mp->buffer[mp->cur_input.loc_field] == '-') {
            mp->cur_input.loc_field++;
        }
        while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
            mp->cur_input.loc_field++;
        }
    }
}

void mp_double_scan_fractional_token (MP mp, int n) /* n is scaled */
{
    unsigned char *start = &mp->buffer[mp->cur_input.loc_field -1];
    unsigned char *stop;
    (void) n;
    while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
        mp->cur_input.loc_field++;
    }
    mp_double_aux_find_exponent(mp);
    stop = &mp->buffer[mp->cur_input.loc_field-1];
    mp_wrapup_numeric_token(mp, start, stop);
}

@ Input format is the same as for the C language, so we just collect valid bytes
in the buffer, then call |strtod()|. It looks like we have no buffer overflow
check here. (Needs checking!)

@c
void mp_double_scan_numeric_token (MP mp, int n) /* n is scaled */
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
    mp_double_aux_find_exponent(mp);
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
void mp_double_velocity (MP mp, mp_number *ret, mp_number *st, mp_number *ct, mp_number *sf, mp_number *cf, mp_number *t)
{
    double acc, num, denom; /* registers for intermediate calculations */
    (void) mp;
    acc = mp_double_take_fraction(st->data.dval - (sf->data.dval / 16.0), sf->data.dval - (st->data.dval / 16.0));
    acc = mp_double_take_fraction(acc, ct->data.dval - cf->data.dval);
    num = fraction_two + mp_double_take_fraction(acc, sqrt(2)*fraction_one);
    denom = fraction_three
          + mp_double_take_fraction(ct->data.dval, 3*fraction_half*(sqrt(5.0)-1.0))
          + mp_double_take_fraction(cf->data.dval, 3*fraction_half*(3.0-sqrt(5.0)));
    if (t->data.dval != unity) {
        num = mp_double_make_scaled(num, t->data.dval);
    }
    if (num / 4 >= denom) {
        ret->data.dval = fraction_four;
    } else {
        ret->data.dval = mp_double_make_fraction(num, denom);
    }
}

@ The following somewhat different subroutine tests rigorously if $ab$ is greater
than, equal to, or less than~$cd$, given integers $(a,b,c,d)$. In most cases a
quick decision is reached. The result is $+1$, 0, or~$-1$ in the three respective
cases.

@c
int mp_ab_vs_cd (mp_number *a_orig, mp_number *b_orig, mp_number *c_orig, mp_number *d_orig)
{
    return mp_double_ab_vs_cd(a_orig, b_orig, c_orig, d_orig);
}

@ @<Reduce to the case that |a...@>=
if (a < 0) {
    a = -a;
    b = -b;
}
if (c < 0) {
    c = -c;
    d = -d;
}
if (d <= 0) {
    if (b >= 0) {
        if ((a == 0 || b == 0) && (c == 0 || d == 0)) {
            ret->data.dval = 0;
        } else {
            ret->data.dval = 1;
        }
        goto RETURN;
    } if (d == 0) {
        ret->data.dval = (a == 0 ? 0 : -1);
        goto RETURN;
    } else
        q = a;
        a = c;
        c = q;
        q = -b;
        b = -d;
        d = q;
    }
} else if (b <= 0) {
    if (b < 0 && a > 0) {
        ret->data.dval  = -1;
        return;
    } else
        ret->data.dval = (c == 0 ? 0 : -1);
        goto RETURN;
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
static void mp_double_crossing_point (MP mp, mp_number *ret, mp_number *aa, mp_number *bb, mp_number *cc)
{
    double d;                  /* recursive counter */
    double xx, x0, x1, x2;  /* temporary registers for bisection */
    double a = aa->data.dval;
    double b = bb->data.dval;
    double c = cc->data.dval;
    (void) mp;
    if (a < 0.0) {
        ret->data.dval = zero_crossing;
        return;
    }
    if (c >= 0.0) {
        if (b >= 0.0) {
            if (c > 0.0) {
                ret->data.dval = no_crossing;
            } else if ((a == 0.0) && (b == 0.0)) {
                ret->data.dval = no_crossing;
            } else {
                ret->data.dval = one_crossing;
            }
            return;
        }
        if (a == 0.0) {
            ret->data.dval = zero_crossing;
            return;
        }
    } else if ((a == 0.0) && (b <= 0.0)) {
        ret->data.dval = zero_crossing;
        return;
    }
    /* Use bisection to find the crossing point... */
    d = epsilon;
    x0 = a;
    x1 = a - b;
    x2 = b - c;
    do {
        /* not sure why the error correction has to be >= 1E-12 */
        double x = (x1 + x2) / 2 + 1E-12;
        if (x1 - x0 > x0) {
            x2 = x;
            x0 += x0;
            d += d;
        } else {
            xx = x1 + x - x0;
            if (xx > x0) {
                x2 = x;
                x0 += x0;
                d += d;
            } else {
                x0 = x0 - xx;
                if ((x <= x0) && (x + x2 <= x0)) {
                    ret->data.dval = no_crossing;
                    return;
                }
                x1 = x;
                d = d + d + epsilon;
            }
        }
    } while (d < fraction_one);
    ret->data.dval = (d - fraction_one);
}

@ We conclude this set of elementary routines with some simple rounding and
truncation operations.

@ |round_unscaled| rounds a |scaled| and converts it to |int|
@c
int mp_round_unscaled(mp_number *x_orig)
{
    return (int) lround(x_orig->data.dval);
}

@ |number_floor| floors a number

@c
void mp_number_floor(mp_number *i)
{
    i->data.dval = floor(i->data.dval);
}

@ |fraction_to_scaled| rounds a |fraction| and converts it to |scaled|

@c
void mp_double_fraction_to_round_scaled(mp_number *x_orig)
{
    double x = x_orig->data.dval;
    x_orig->type = mp_scaled_type;
    x_orig->data.dval = x/fraction_multiplier;
}

@* Algebraic and transcendental functions. \MP\ computes all of the necessary
special functions from scratch, without relying on |real| arithmetic or system
subroutines for sines, cosines, etc.

@ @c
void mp_double_square_rt (MP mp, mp_number *ret, mp_number *x_orig) /* return, x: scaled */
{
    double x = x_orig->data.dval;
    if (x > 0) {
        ret->data.dval = sqrt(x);
    } else {
        if (x < 0) {
            char msg[256];
            char *xstr = mp_double_number_tostring(mp, x_orig);
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
        ret->data.dval = 0;
    }
}

@ Pythagorean addition $\psqrt{a^2+b^2}$ is implemented by a quick hack

@c
void mp_double_pyth_add (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    double a = fabs(a_orig->data.dval);
    double b = fabs(b_orig->data.dval);
    errno = 0;
    ret->data.dval = sqrt(a*a + b*b);
    if (errno) {
        mp->arith_error = 1;
        ret->data.dval = EL_GORDO;
    }
}

@ Here is a similar algorithm for $\psqrt{a^2-b^2}$. Same quick hack, also.

@c
void mp_double_pyth_sub (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    double a = fabs(a_orig->data.dval);
    double b = fabs(b_orig->data.dval);
    if (a > b) {
        a = sqrt(a*a - b*b);
    } else {
        if (a < b) {
            char msg[256];
            char *astr = mp_double_number_tostring(mp, a_orig);
            char *bstr = mp_double_number_tostring(mp, b_orig);
            mp_snprintf(msg, 256, "Pythagorean subtraction %s+-+%s has been replaced by 0", astr, bstr);
            mp_memory_free(astr);
            mp_memory_free(bstr);
            @.Pythagorean...@>
            mp_error(
                mp,
                msg,
                "Since I don't take square roots of negative numbers, Im zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        }
        a = 0;
    }
    ret->data.dval = a;
}

@ This power one is simple:

@c
void mp_double_power_of (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    errno = 0;
    ret->data.dval = pow(a_orig->data.dval, b_orig->data.dval);
    if (errno) {
        mp->arith_error = 1;
        ret->data.dval = EL_GORDO;
    }
}

@ The subroutines for logarithm and exponential involve two tables. The first is
simple: |two_to_the[k]| equals $2^k$.

@ Here is the routine that calculates $2^8$ times the natural logarithm of a
|scaled| quantity; it is an integer approximation to $2^{24}\ln(x/2^{16})$, when
|x| is a given positive integer.

@c
void mp_double_m_log (MP mp, mp_number *ret, mp_number *x_orig)
{
    if (x_orig->data.dval > 0) {
        ret->data.dval = log(x_orig->data.dval)*256.0;
    } else {
        char msg[256];
        char *xstr = mp_double_number_tostring(mp, x_orig);
        mp_snprintf(msg, 256, "Logarithm of %s has been replaced by 0", xstr);
        mp_memory_free(xstr);
        mp_error(
            mp,
            msg,
            "Since I don't take logs of non-positive numbers, I'm zeroing this one.\n"
            "Proceed, with fingers crossed."
        );
        ret->data.dval = 0;
    }
}

@ Conversely, the exponential routine calculates $\exp(x/2^8)$, when |x| is
|scaled|.

@c
void mp_double_m_exp (MP mp, mp_number *ret, mp_number *x_orig)
{
    errno = 0;
    ret->data.dval = exp(x_orig->data.dval/256.0);
    if (errno) {
        if (x_orig->data.dval > 0) {
            mp->arith_error = 1;
            ret->data.dval = EL_GORDO;
        } else {
            ret->data.dval = 0;
        }
    }
}

@ Given integers |x| and |y|, not both zero, the |n_arg| function returns the
|angle| whose tangent points in the direction $(x,y)$.

@c
void mp_double_n_arg (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig)
{
    if (x_orig->data.dval == 0.0 && y_orig->data.dval == 0.0) {
        mp_error(
            mp,
            "angle(0,0) is taken as zero",
            "The 'angle' between two identical points is undefined. I'm zeroing this one.\n"
            "Proceed, with fingers crossed."
        );
        ret->data.dval = 0;
    } else {
        ret->type = mp_angle_type;
        ret->data.dval = atan2(y_orig->data.dval, x_orig->data.dval) * (180.0 / PI)  * angle_multiplier;
        if (ret->data.dval == -0.0)
        ret->data.dval = 0.0;
    }
}

@ Conversely, the |n_sin_cos| routine takes an |angle| and produces the sine and
cosine of that angle. The results of this routine are stored in global integer
variables |n_sin| and |n_cos|.

@ Given an integer |z| that is $2^{20}$ times an angle $\theta$ in degrees, the
purpose of |n_sin_cos(z)| is to set |x=@t$r\cos\theta$@>| and
|y=@t$r\sin\theta$@>| (approximately), for some rather large number~|r|. The
maximum of |x| and |y| will be between $2^{28}$ and $2^{30}$, so that there will
be hardly any loss of accuracy. Then |x| and~|y| are divided by~|r|.

@ Compute a multiple of the sine and cosine

@c
void mp_double_sin_cos (MP mp, mp_number *z_orig, mp_number *n_cos, mp_number *n_sin)
{
    double rad = (z_orig->data.dval / angle_multiplier); /* still degrees */
    (void) mp;
    if ((rad == 90.0) || (rad == -270)){
        n_cos->data.dval = 0.0;
        n_sin->data.dval = fraction_multiplier;
    } else if ((rad == -90.0) || (rad == 270.0)) {
        n_cos->data.dval = 0.0;
        n_sin->data.dval = -fraction_multiplier;
    } else if ((rad == 180.0) || (rad == -180.0)) {
        n_cos->data.dval = -fraction_multiplier;
        n_sin->data.dval = 0.0;
    } else {
        rad = rad * PI/180.0;
        n_cos->data.dval = cos(rad) * fraction_multiplier;
        n_sin->data.dval = sin(rad) * fraction_multiplier;
    }
}

@ This is the http://www-cs-faculty.stanford.edu/~uno/programs/rng.c with small
cosmetic modifications.

@c
# define KK            100                /* the long lag  */
# define LL            37                 /* the short lag */
# define MM            (1L<<30)           /* the modulus   */
# define mod_diff(x,y) (((x)-(y))&(MM-1)) /* subtraction mod MM */
# define TT            70                 /* guaranteed separation between streams */
# define is_odd(x)     ((x)&1)            /* units bit of x */
# define QUALITY       1009               /* recommended quality level for high-res use */

/* destination, array length (must be at least KK) */

typedef struct mp_double_random_info {
    long  x[KK];
    long  buf[QUALITY];
    long  dummy;
    long  started;
    long *ptr;
} mp_double_random_info;

static mp_double_random_info mp_double_random_data = {
    .dummy   = -1,
    .started = -1,
    .ptr     = &mp_double_random_data.dummy
};

/* the following routines are from exercise 3.6--15 */
/* after calling |mp_aux_ran_start|, get new randoms by, e.g., |x=mp_aux_ran_arr_next()| */

static void mp_double_aux_ran_array(long aa[], int n)
{
    int i, j;
    for (j = 0; j < KK; j++) {
        aa[j] = mp_double_random_data.x[j];
    }
    for (; j < n; j++) {
        aa[j] = mod_diff(aa[j - KK], aa[j - LL]);
    }
    for (i = 0; i < LL; i++, j++) {
        mp_double_random_data.x[i] = mod_diff(aa[j - KK], aa[j - LL]);
    }
    for (; i < KK; i++, j++) {
        mp_double_random_data.x[i] = mod_diff(aa[j - KK], mp_double_random_data.x[i - LL]);
    }
}

/* Do this before using |mp_aux_ran_array|, long seed selector for different streams. */

static void mp_double_aux_ran_start(long seed)
{
    int t, j;
    long x[KK + KK - 1]; /* the preparation buffer */
    long ss = (seed+2) & (MM - 2);
    for (j = 0; j < KK; j++) {
        /* bootstrap the buffer */
        x[j] = ss;
        /* cyclic shift 29 bits */
        ss <<= 1;
        if (ss >= MM) {
            ss -= MM - 2;
        }
    }
    /* make x[1] (and only x[1]) odd */
    x[1]++;
    for (ss = seed & (MM - 1), t = TT - 1; t;) {
        for (j = KK - 1; j > 0; j--) {
            /* "square" */
            x[j + j] = x[j];
            x[j + j - 1] = 0;
        }
        for (j = KK + KK - 2; j >= KK; j--) {
            x[j - (KK -LL)] = mod_diff(x[j - (KK - LL)], x[j]);
            x[j - KK] = mod_diff(x[j - KK], x[j]);
        }
        if (is_odd(ss)) {
            /* "multiply by z" */
            for (j = KK; j>0; j--) {
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
        mp_double_random_data.x[j + KK - LL] = x[j];
    }
    for (;j < KK; j++) {
        mp_double_random_data.x[j - LL] = x[j];
    }
    for (j = 0; j < 10; j++) {
        /* warm things up */
        mp_double_aux_ran_array(x, KK + KK - 1);
    }
    mp_double_random_data.ptr = &mp_double_random_data.started;
}

# define mp_double_aux_ran_arr_next() (*mp_double_random_data.ptr>=0? *mp_double_random_data.ptr++: mp_double_aux_ran_arr_cycle())

static long mp_double_aux_ran_arr_cycle(void)
{
    if (mp_double_random_data.ptr == &mp_double_random_data.dummy) {
        /* the user forgot to initialize */
        mp_double_aux_ran_start(314159L);
    }
    mp_double_aux_ran_array(mp_double_random_data.buf, QUALITY);
    mp_double_random_data.buf[KK] = -1;
    mp_double_random_data.ptr = mp_double_random_data.buf + 1;
    return mp_double_random_data.buf[0];
}

@ To initialize the |randoms| table, we call the following routine.

@c
void mp_init_randoms (MP mp, int seed)
{
    int k = 1;
    int j = abs(seed);
    int f = (int) fraction_one; /* avoid warnings */
    while (j >= f) {
        j = j/2;
    }
    for (int i = 0; i <= 54; i++) {
        int jj = k;
        k = j - k;
        j = jj;
        if (k < 0) {
            k += f;
        }
        mp->randoms[(i * 21) % 55].data.dval = j;
    }
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    /* warm up the array */
    mp_double_aux_ran_start((unsigned long) seed);
}

@ Here |frac| contains what's beyond the |.|.  @c
/*
static double modulus(double left, double right)
{
    double quota = left / right;
    double tmp;
    double frac = modf(quota, &tmp);
    frac *= right;
    return frac;
}
*/

void mp_number_modulo(mp_number *a, mp_number *b)
{
    double tmp;
    a->data.dval = modf((double) a->data.dval / (double) b->data.dval, &tmp) * (double) b->data.dval;
}

@ To consume a random integer for the uniform generator, the program below will
say |next_unif_random|.

@c
static void mp_next_unif_random (MP mp, mp_number *ret)
{
    unsigned long int op = (unsigned) mp_double_aux_ran_arr_next();
    double a = op / (MM * 1.0);
    (void) mp;
    ret->data.dval = a;
}

@ To consume a random fraction, the program below will say |next_random|.

@c
static void mp_next_random (MP mp, mp_number *ret)
{
    if ( mp->j_random==0) {
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
static void mp_double_m_unif_rand (MP mp, mp_number *ret, mp_number *x_orig)
{
    mp_number x, abs_x, u, y; /* |y| is trial value */
    mp_allocate_number(mp, &y, mp_fraction_type);
    mp_allocate_clone(mp, &x, mp_scaled_type, x_orig);
    mp_allocate_abs(mp, &abs_x, mp_scaled_type, &x);
    mp_allocate_number(mp, &u, mp_scaled_type);
    mp_next_unif_random(mp, &u);
    y.data.dval = abs_x.data.dval * u.data.dval;
    mp_free_number(mp, &u);
    if (mp_number_equal(&y, &abs_x)) {
        mp_number_clone(ret, &((math_data *)mp->math)->md_zero_t);
    } else if (mp_number_greater(&x, &((math_data *)mp->math)->md_zero_t)) {
        mp_number_clone(ret, &y);
    } else {
        mp_number_negated_clone(ret, &y);
    }
    mp_free_number(mp, &abs_x);
    mp_free_number(mp, &x);
    mp_free_number(mp, &y);
}

@ Finally, a normal deviate with mean zero and unit standard deviation can
readily be obtained with the ratio method (Algorithm 3.4.1R in {\sl The Art of
Computer Programming}).

@c
static void mp_double_m_norm_rand (MP mp, mp_number *ret)
{
    mp_number abs_x, u, r, la, xa;
    mp_allocate_number(mp, &la, mp_scaled_type);
    mp_allocate_number(mp, &xa, mp_scaled_type);
    mp_allocate_number(mp, &abs_x, mp_scaled_type);
    mp_allocate_number(mp, &u, mp_scaled_type);
    mp_allocate_number(mp, &r, mp_scaled_type);
    do {
        do {
            mp_number v;
            mp_allocate_number(mp, &v, mp_scaled_type);
            mp_next_random(mp, &v);
            mp_number_subtract(&v, &((math_data *)mp->math)->md_fraction_half_t);
            mp_double_number_take_fraction(mp, &xa, &((math_data *)mp->math)->md_sqrt_8_e_k, &v);
            mp_free_number(mp, &v);
            mp_next_random(mp, &u);
            mp_number_clone(&abs_x, &xa);
            mp_double_abs(&abs_x);
        } while (! mp_number_less(&abs_x, &u));
        mp_double_number_make_fraction(mp, &r, &xa, &u);
        mp_number_clone(&xa, &r);
        mp_double_m_log(mp, &la, &u);
        mp_set_double_from_subtraction(&la, &((math_data *)mp->math)->md_twelve_ln_2_k, &la);
    } while (mp_double_ab_vs_cd(&((math_data *)mp->math)->md_one_k, &la, &xa, &xa) < 0);
    mp_number_clone(ret, &xa);
    mp_free_number(mp, &r);
    mp_free_number(mp, &abs_x);
    mp_free_number(mp, &la);
    mp_free_number(mp, &xa);
    mp_free_number(mp, &u);
}

@ The following subroutine is used only in |norm_rand| and tests if $ab$ is
greater than, equal to, or less than~$cd$. The result is $+1$, 0, or~$-1$ in the
three respective cases.

@c
int mp_double_ab_vs_cd (mp_number *a_orig, mp_number *b_orig, mp_number *c_orig, mp_number *d_orig)
{
    double ab = a_orig->data.dval * b_orig->data.dval;
    double cd = c_orig->data.dval * d_orig->data.dval;
    if (ab > cd) {
        return 1;
    } else if (ab < cd) {
        return -1;
    } else {
        return 0;
    }
}
