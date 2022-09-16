% This file is part of MetaPost. The MetaPost program is in the public domain.

@ Introduction.

@c
# include "mpconfig.h"
# include "mpmath.h"
# include "mpstrings.h"
@h

@ @c
@<Declarations@>

@ @(mpmath.h@>=
# ifndef MPMATH_H
# define MPMATH_H 1

# include "mp.h" /* internal header */

math_data *mp_initialize_scaled_math (MP mp);

# endif

@* Math initialization.

@ Here are the functions that are static as they are not used elsewhere

@<Declarations@>=
static int     mp_ab_vs_cd                        (mp_number *a, mp_number *b, mp_number *c, mp_number *d);
static void    mp_allocate_abs                    (MP mp, mp_number *n, mp_number_type t, mp_number *B);
static void    mp_allocate_clone                  (MP mp, mp_number *n, mp_number_type t, mp_number *B);
static void    mp_allocate_double                 (MP mp, mp_number *n, double v);
static void    mp_allocate_number                 (MP mp, mp_number *n, mp_number_type t);
static void    mp_crossing_point                  (MP mp, mp_number *ret, mp_number *a, mp_number *b, mp_number *c);
static void    mp_fraction_to_round_scaled        (mp_number *x);
static void    mp_free_number                     (MP mp, mp_number *n);
static void    mp_free_scaled_math                (MP mp);
static void    mp_init_randoms                    (MP mp, int seed);
static void    mp_m_exp                           (MP mp, mp_number *ret, mp_number *x_orig);
static void    mp_m_log                           (MP mp, mp_number *ret, mp_number *x_orig);
static void    mp_m_norm_rand                     (MP mp, mp_number *ret);
static void    mp_m_unif_rand                     (MP mp, mp_number *ret, mp_number *x_orig);
static int     mp_make_scaled                     (MP mp, int p, int q);
static void    mp_n_arg                           (MP mp, mp_number *ret, mp_number *x, mp_number *y);
static void    mp_n_sin_cos                       (MP mp, mp_number *z_orig, mp_number *n_cos, mp_number *n_sin);
static void    mp_number_abs                      (mp_number *A);
static void    mp_number_abs_clone                (mp_number *A, mp_number *B);
static void    mp_number_add                      (mp_number *A, mp_number *B);
static void    mp_number_add_scaled               (mp_number *A, int B); /* also for negative B */
static void    mp_number_angle_to_scaled          (mp_number *A);
static void    mp_number_clone                    (mp_number *A, mp_number *B);
static void    mp_number_divide_int               (mp_number *A, int B);
static void    mp_number_double                   (mp_number *A);
static int     mp_number_equal                    (mp_number *A, mp_number *B);
static void    mp_number_floor                    (mp_number *i);
static void    mp_number_fraction_to_scaled       (mp_number *A);
static int     mp_number_greater                  (mp_number *A, mp_number *B);
static void    mp_number_half                     (mp_number *A);
static int     mp_number_less                     (mp_number *A, mp_number *B);
static void    mp_number_make_fraction            (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void    mp_number_make_scaled              (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void    mp_number_modulo                   (mp_number *a, mp_number *b);
static void    mp_number_multiply_int             (mp_number *A, int B);
static void    mp_number_negate                   (mp_number *A);
static void    mp_number_negated_clone            (mp_number *A, mp_number *B);
static int     mp_number_nonequalabs              (mp_number *A, mp_number *B);
static int     mp_number_odd                      (mp_number *A);
static void    mp_number_scaled_to_angle          (mp_number *A);
static void    mp_number_scaled_to_fraction       (mp_number *A);
static void    mp_number_subtract                 (mp_number *A, mp_number *B);
static void    mp_number_swap                     (mp_number *A, mp_number *B);
static void    mp_number_take_fraction            (MP mp, mp_number *r, mp_number *p, mp_number *q);
static void    mp_number_take_scaled              (MP mp, mp_number *r, mp_number *p, mp_number *q);
static int     mp_number_to_boolean               (mp_number *A);
static double  mp_number_to_double                (mp_number *A);
static int     mp_number_to_int                   (mp_number *A);
static int     mp_number_to_scaled                (mp_number *A);
static void    mp_power_of                        (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void    mp_print_number                    (MP mp, mp_number *n);
static void    mp_pyth_add                        (MP mp, mp_number *r, mp_number *a, mp_number *b);
static void    mp_pyth_sub                        (MP mp, mp_number *r, mp_number *a, mp_number *b);
static int     mp_round_decimals                  (MP mp, unsigned char *b, int k);
static int     mp_round_unscaled                  (mp_number *x_orig);
static void    mp_scaled_set_precision            (MP mp);
static void    mp_scan_fractional_token           (MP mp, int n);
static void    mp_scan_numeric_token              (MP mp, int n);
static void    mp_set_number_from_addition        (mp_number *A, mp_number *B, mp_number *C);
static void    mp_set_number_from_boolean         (mp_number *A, int B);
static void    mp_set_number_from_div             (mp_number *A, mp_number *B, mp_number *C);
static void    mp_set_number_from_double          (mp_number *A, double B);
static void    mp_set_number_from_int             (mp_number *A, int B);
static void    mp_set_number_from_int_div         (mp_number *A, mp_number *B, int C);
static void    mp_set_number_from_int_mul         (mp_number *A, mp_number *B, int C);
static void    mp_set_number_from_mul             (mp_number *A, mp_number *B, mp_number *C);
static void    mp_set_number_from_of_the_way      (MP mp, mp_number *A, mp_number *t, mp_number *B, mp_number *C);
static void    mp_set_number_from_scaled          (mp_number *A, int B);
static void    mp_set_number_from_subtraction     (mp_number *A, mp_number *B, mp_number *C);
static void    mp_set_number_half_from_addition   (mp_number *A, mp_number *B, mp_number *C);
static void    mp_set_number_half_from_subtraction(mp_number *A, mp_number *B, mp_number *C);
static void    mp_slow_add                        (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig);
static void    mp_square_rt                       (MP mp, mp_number *ret, mp_number *x_orig);
static int     mp_take_fraction                   (MP mp, int q, int f);
static int     mp_take_scaled                     (MP mp, int q, int f);
static void    mp_velocity                        (MP mp, mp_number *ret, mp_number *st, mp_number *ct, mp_number *sf, mp_number *cf, mp_number *t);
static void    mp_wrapup_numeric_token            (MP mp, int n, int f);
static char   *mp_number_tostring                 (MP mp, mp_number *n);
static char   *mp_string_scaled                   (MP mp, int s);

@
@d coef_bound               04525252525 /* |fraction| approximation to 7/3 */
@d fraction_threshold       2685        /* a |fraction| coefficient less than this is zeroed */
@d half_fraction_threshold  1342        /* half of |fraction_threshold| */
@d scaled_threshold         8           /* a |scaled| coefficient less than this is zeroed */
@d half_scaled_threshold    4           /* half of |scaled_threshold| */
@d near_zero_angle          26844
@d p_over_v_threshold       0x80000
@d equation_threshold       64

@ Fixed-point arithmetic is done on {\sl scaled integers} that are multiples of
$2^{-16}$. In other words, a binary point is assumed to be sixteen bit positions
from the right end of a binary computer word.

@d unity                    0x10000       /* $2^{16}$, represents 1.00000 */
@d two                      (2*unity)     /* $2^{17}$, represents 2.00000 */
@d three                    (3*unity)     /* $2^{17}+2^{16}$, represents 3.00000 */
@d half_unit                (unity/2)     /* $2^{15}$, represents 0.50000 */
@d three_quarter_unit       (3*(unity/4)) /* $3\cdot2^{14}$, represents 0.75000 */
@d EL_GORDO                 0x7fffffff    /* $2^{31}-1$, the largest value that \MP\ likes */
@d negative_EL_GORDO        (-EL_GORDO)
@d one_third_EL_GORDO       05252525252

@ We need these preprocessor values

@d TWEXP31                  2147483648.0
@d TWEXP28                  268435456.0
@d TWEXP16                  65536.0
@d TWEXP_16                 (1.0/65536.0)
@d TWEXP_28                 (1.0/268435456.0)

@d no_crossing              (fraction_one + 1)
@d one_crossing             fraction_one
@d zero_crossing            0

@ The |scaled| quantities in \MP\ programs are generally supposed to be less than
$2^{12}$ in absolute value, so \MP\ does much of its internal arithmetic with
28~significant bits of precision. A |fraction| denotes a scaled integer whose
binary point is assumed to be 28 bit positions from the right.

@d fraction_half            0x08000000 /* $2^{27}$,       represents 0.50000000  01000000000 */
@d fraction_one             0x10000000 /* $2^{28}$,       represents 1.00000000  02000000000 */
@d fraction_two             0x20000000 /* $2^{29}$,       represents 2.00000000  04000000000 */
@d fraction_three           0x30000000 /* $3\cdot2^{28}$, represents 3.00000000  06000000000 */
@d fraction_four            0x40000000 /* $2^{30}$,       represents 4.00000000 010000000000 */

@ Octants are represented in a \quote {Gray code,} since that turns out to be
computationally simplest.

@d negate_x                 1
@d negate_y                 2
@d switch_x_and_y           4
@d first_octant             1
@d second_octant            (first_octant + switch_x_and_y)
@d third_octant             (first_octant + switch_x_and_y + negate_x)
@d fourth_octant            (first_octant                  + negate_x)
@d fifth_octant             (first_octant                  + negate_x + negate_y)
@d sixth_octant             (first_octant + switch_x_and_y + negate_x + negate_y)
@d seventh_octant           (first_octant + switch_x_and_y + negate_y)
@d eighth_octant            (first_octant                  + negate_y)

@d forty_five_deg           0x02D00000 /* $ 45\cdot2^{20}$, represents $ 45^\circ$ 0264000000  */
@d ninety_deg               0x05A00000 /* $ 90\cdot2^{20}$, represents $ 90^\circ$ 0550000000  */
@d one_eighty_deg           0x0B400000 /* $180\cdot2^{20}$, represents $180^\circ$ 01320000000 */
@d negative_one_eighty_deg -0x0B400000 /* $180\cdot2^{20}$, represents $180^\circ$             */
@d three_sixty_deg          0x16800000 /* $360\cdot2^{20}$, represents $360^\circ$ 02640000000 */

@d odd(A)                  (abs(A)%2==1)
@d two_to_the(A)           (1<<(unsigned)(A))

@d set_cur_cmd(A)          mp->cur_mod_->command = (A)
@d set_cur_mod(A)          mp->cur_mod_->data.n.data.val = (A)

@ @c
math_data *mp_initialize_scaled_math(MP mp)
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
    math->md_precision_default.data.val         = unity * 10;
    math->md_precision_max.data.val             = unity * 10;
    math->md_precision_min.data.val             = unity * 10;
    math->md_epsilon_t.data.val                 = 1;
    math->md_inf_t.data.val                     = EL_GORDO;
    math->md_negative_inf_t.data.val            = negative_EL_GORDO;
    math->md_one_third_inf_t.data.val           = one_third_EL_GORDO;
    math->md_warning_limit_t.data.val           = fraction_one;
    math->md_unity_t.data.val                   = unity;
    math->md_two_t.data.val                     = two;
    math->md_three_t.data.val                   = three;
    math->md_half_unit_t.data.val               = half_unit;
    math->md_three_quarter_unit_t.data.val      = three_quarter_unit;
    math->md_arc_tol_k.data.val                 = (unity/4096);
    math->md_fraction_one_t.data.val            = fraction_one;
    math->md_fraction_half_t.data.val           = fraction_half;
    math->md_fraction_three_t.data.val          = fraction_three;
    math->md_fraction_four_t.data.val           = fraction_four;
    math->md_three_sixty_deg_t.data.val         = three_sixty_deg;
    math->md_one_eighty_deg_t.data.val          = one_eighty_deg;
    math->md_negative_one_eighty_deg_t.data.val = negative_one_eighty_deg;
    math->md_one_k.data.val                     = 1024;
    math->md_sqrt_8_e_k.data.val                = 112429;         /* $2^{16}\sqrt{8/e}\approx 112428.82793$ */
    math->md_twelve_ln_2_k.data.val             = 139548960;      /* $2^{24}\cdot12\ln2\approx139548959.6165$ */
    math->md_coef_bound_k.data.val              = coef_bound;
    math->md_coef_bound_minus_1.data.val        = coef_bound - 1;
    math->md_twelvebits_3.data.val              = 1365;           /* $1365\approx 2^{12}/3$ */
    math->md_twentysixbits_sqrt2_t.data.val     = 94906266;       /* $2^{26}\sqrt2\approx94906265.62$ */
    math->md_twentyeightbits_d_t.data.val       = 35596755;       /* $2^{28}d\approx35596754.69$ */
    math->md_twentysevenbits_sqrt2_d_t.data.val = 25170707;       /* $2^{27}\sqrt2\,d\approx25170706.63$ */
    math->md_fraction_threshold_t.data.val      = fraction_threshold;
    math->md_half_fraction_threshold_t.data.val = half_fraction_threshold;
    math->md_scaled_threshold_t.data.val        = scaled_threshold;
    math->md_half_scaled_threshold_t.data.val   = half_scaled_threshold;
    math->md_near_zero_angle_t.data.val         = near_zero_angle;
    math->md_p_over_v_threshold_t.data.val      = p_over_v_threshold;
    math->md_equation_threshold_t.data.val      = equation_threshold;
    /* functions */
    math->md_from_int                 = mp_set_number_from_int;
    math->md_from_boolean             = mp_set_number_from_boolean;
    math->md_from_scaled              = mp_set_number_from_scaled;
    math->md_from_double              = mp_set_number_from_double;
    math->md_from_addition            = mp_set_number_from_addition;
    math->md_half_from_addition       = mp_set_number_half_from_addition;
    math->md_from_subtraction         = mp_set_number_from_subtraction;
    math->md_half_from_subtraction    = mp_set_number_half_from_subtraction;
    math->md_from_oftheway            = mp_set_number_from_of_the_way;
    math->md_from_div                 = mp_set_number_from_div;
    math->md_from_mul                 = mp_set_number_from_mul;
    math->md_from_int_div             = mp_set_number_from_int_div;
    math->md_from_int_mul             = mp_set_number_from_int_mul;
    math->md_negate                   = mp_number_negate;
    math->md_add                      = mp_number_add;
    math->md_subtract                 = mp_number_subtract;
    math->md_half                     = mp_number_half;
    math->md_do_double                = mp_number_double;
    math->md_abs                      = mp_number_abs;
    math->md_clone                    = mp_number_clone;
    math->md_negated_clone            = mp_number_negated_clone;
    math->md_abs_clone                = mp_number_abs_clone;
    math->md_swap                     = mp_number_swap;
    math->md_add_scaled               = mp_number_add_scaled;
    math->md_multiply_int             = mp_number_multiply_int;
    math->md_divide_int               = mp_number_divide_int;
    math->md_to_int                   = mp_number_to_int;
    math->md_to_boolean               = mp_number_to_boolean;
    math->md_to_scaled                = mp_number_to_scaled;
    math->md_to_double                = mp_number_to_double;
    math->md_odd                      = mp_number_odd;
    math->md_equal                    = mp_number_equal;
    math->md_less                     = mp_number_less;
    math->md_greater                  = mp_number_greater;
    math->md_nonequalabs              = mp_number_nonequalabs;
    math->md_round_unscaled           = mp_round_unscaled;
    math->md_floor_scaled             = mp_number_floor;
    math->md_fraction_to_round_scaled = mp_fraction_to_round_scaled;
    math->md_make_scaled              = mp_number_make_scaled;
    math->md_make_fraction            = mp_number_make_fraction;
    math->md_take_fraction            = mp_number_take_fraction;
    math->md_take_scaled              = mp_number_take_scaled;
    math->md_velocity                 = mp_velocity;
    math->md_n_arg                    = mp_n_arg;
    math->md_m_log                    = mp_m_log;
    math->md_m_exp                    = mp_m_exp;
    math->md_m_unif_rand              = mp_m_unif_rand;
    math->md_m_norm_rand              = mp_m_norm_rand;
    math->md_pyth_add                 = mp_pyth_add;
    math->md_pyth_sub                 = mp_pyth_sub;
    math->md_power_of                 = mp_power_of;
    math->md_fraction_to_scaled       = mp_number_fraction_to_scaled;
    math->md_scaled_to_fraction       = mp_number_scaled_to_fraction;
    math->md_scaled_to_angle          = mp_number_scaled_to_angle;
    math->md_angle_to_scaled          = mp_number_angle_to_scaled;
    math->md_init_randoms             = mp_init_randoms;
    math->md_sin_cos                  = mp_n_sin_cos;
    math->md_slow_add                 = mp_slow_add;
    math->md_sqrt                     = mp_square_rt;
    math->md_print                    = mp_print_number;
    math->md_tostring                 = mp_number_tostring;
    math->md_modulo                   = mp_number_modulo;
    math->md_ab_vs_cd                 = mp_ab_vs_cd;
    math->md_crossing_point           = mp_crossing_point;
    math->md_scan_numeric             = mp_scan_numeric_token;
    math->md_scan_fractional          = mp_scan_fractional_token;
    math->md_free_math                = mp_free_scaled_math;
    math->md_set_precision            = mp_scaled_set_precision;
    return math;
}

void mp_scaled_set_precision (MP mp)
{
    (void) mp;
}

void mp_free_scaled_math (MP mp)
{
    mp_free_number(mp, &(mp->math->md_epsilon_t));
    mp_free_number(mp, &(mp->math->md_inf_t));
    mp_free_number(mp, &(mp->math->md_negative_inf_t));
    mp_free_number(mp, &(mp->math->md_arc_tol_k));
    mp_free_number(mp, &(mp->math->md_three_sixty_deg_t));
    mp_free_number(mp, &(mp->math->md_one_eighty_deg_t));
    mp_free_number(mp, &(mp->math->md_negative_one_eighty_deg_t));
    mp_free_number(mp, &(mp->math->md_fraction_one_t));
    mp_free_number(mp, &(mp->math->md_fraction_half_t));
    mp_free_number(mp, &(mp->math->md_fraction_three_t));
    mp_free_number(mp, &(mp->math->md_fraction_four_t));
    mp_free_number(mp, &(mp->math->md_zero_t));
    mp_free_number(mp, &(mp->math->md_half_unit_t));
    mp_free_number(mp, &(mp->math->md_three_quarter_unit_t));
    mp_free_number(mp, &(mp->math->md_unity_t));
    mp_free_number(mp, &(mp->math->md_two_t));
    mp_free_number(mp, &(mp->math->md_three_t));
    mp_free_number(mp, &(mp->math->md_one_third_inf_t));
    mp_free_number(mp, &(mp->math->md_warning_limit_t));
    mp_free_number(mp, &(mp->math->md_one_k));
    mp_free_number(mp, &(mp->math->md_sqrt_8_e_k));
    mp_free_number(mp, &(mp->math->md_twelve_ln_2_k));
    mp_free_number(mp, &(mp->math->md_coef_bound_k));
    mp_free_number(mp, &(mp->math->md_coef_bound_minus_1));
    mp_free_number(mp, &(mp->math->md_twelvebits_3));
    mp_free_number(mp, &(mp->math->md_twentysixbits_sqrt2_t));
    mp_free_number(mp, &(mp->math->md_twentyeightbits_d_t));
    mp_free_number(mp, &(mp->math->md_twentysevenbits_sqrt2_d_t));
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
    n->data.val = 0;
    n->type = t;
}

void mp_allocate_clone (MP mp, mp_number *n, mp_number_type t, mp_number *v)
{
    (void) mp;
    n->type = t;
    n->data.val = v->data.val;
}

void mp_allocate_abs (MP mp, mp_number *n, mp_number_type t, mp_number *v)
{
    (void) mp;
    n->type = t;
    n->data.val = abs(v->data.val);
}

void mp_allocate_double (MP mp, mp_number *n, double v)
{
    (void) mp;
    n->type = mp_scaled_type;
    n->data.val = (int) (v * 65536.0);
}

void mp_free_number (MP mp, mp_number *n)
{
    (void) mp;
    n->type = mp_nan_type;
}

@ Here are the low-level functions on |mp_number| items, setters first.

@ @c
void mp_set_number_from_int(mp_number *A, int B)
{
    A->data.val = B * 65536;
}

void mp_set_number_from_boolean(mp_number *A, int B)
{
    A->data.val = B;
}

void mp_set_number_from_scaled(mp_number *A, int B)
{
    A->data.val = B;
}

void mp_set_number_from_double(mp_number *A, double B)
{
    A->data.val = (int) (B * 65536.0);
}

void mp_set_number_from_addition(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.val = B->data.val + C->data.val;
}

void mp_set_number_half_from_addition(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.val = (B->data.val + C->data.val) / 2;
}

void mp_set_number_from_subtraction(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.val = B->data.val - C->data.val;
}

void mp_set_number_half_from_subtraction(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.val = (B->data.val - C->data.val) / 2;
}

void mp_set_number_from_div(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.val = B->data.val / C->data.val;
}

void mp_set_number_from_mul(mp_number *A, mp_number *B, mp_number *C)
{
    A->data.val = B->data.val * C->data.val;
}

void mp_set_number_from_int_div(mp_number *A, mp_number *B, int C)
{
    A->data.val = B->data.val / C;
}

void mp_set_number_from_int_mul(mp_number *A, mp_number *B, int C)
{
    A->data.val = B->data.val * C;
}

void mp_set_number_from_of_the_way (MP mp, mp_number *A, mp_number *t, mp_number *B, mp_number *C)
{
    (void) mp;
    A->data.val = B->data.val - mp_take_fraction(mp, (B->data.val - C->data.val), t->data.val);
}

void mp_number_negate(mp_number *A)
{
    A->data.val = -A->data.val;
}

void mp_number_add(mp_number *A, mp_number *B)
{
    A->data.val = A->data.val + B->data.val;
}

void mp_number_subtract(mp_number *A, mp_number *B)
{
    A->data.val = A->data.val - B->data.val;
}

void mp_number_half(mp_number *A)
{
    A->data.val = A->data.val / 2;
}

void mp_number_double(mp_number *A)
{
    A->data.val = A->data.val + A->data.val;
}

void mp_number_add_scaled(mp_number *A, int B)
{
    /* also for negative B */
    A->data.val = A->data.val + B;
}

void mp_number_multiply_int(mp_number *A, int B)
{
    A->data.val = B * A->data.val;
}

void mp_number_divide_int(mp_number *A, int B)
{
    A->data.val = A->data.val / B;
}

void mp_number_abs(mp_number *A)
{
    A->data.val = abs(A->data.val);
}

void mp_number_clone(mp_number *A, mp_number *B)
{
    A->data.val = B->data.val;
}

void mp_number_negated_clone(mp_number *A, mp_number *B)
{
    A->data.val = -B->data.val;
}

void mp_number_abs_clone(mp_number *A, mp_number *B)
{
    A->data.val = abs(B->data.val);
}

void mp_number_swap(mp_number *A, mp_number *B)
{
    int swap_tmp = A->data.val;
    A->data.val = B->data.val;
    B->data.val = swap_tmp;
}

void mp_number_fraction_to_scaled(mp_number *A)
{
    A->type = mp_scaled_type;
    A->data.val = A->data.val / 4096;
}

void mp_number_angle_to_scaled(mp_number *A)
{
    A->type = mp_scaled_type;
    if (A->data.val >= 0) {
        A->data.val = (A->data.val + 8) / 16;
    } else {
        A->data.val = -((-A->data.val + 8) / 16);
    }
}

void mp_number_scaled_to_fraction(mp_number *A)
{
    A->type = mp_fraction_type;
    A->data.val = A->data.val * 4096;
}

void mp_number_scaled_to_angle(mp_number *A)
{
    A->type = mp_angle_type;
    A->data.val = A->data.val * 16;
}

@ Query functions

@c
int mp_number_to_int(mp_number *A)
{
    return A->data.val;
}

int mp_number_to_scaled(mp_number *A)
{
    return A->data.val;
}

int mp_number_to_boolean(mp_number *A)
{
    return A->data.val;
}

double mp_number_to_double(mp_number *A)
{
    return A->data.val / 65536.0;
}

int mp_number_odd(mp_number *A)
{
    return odd(mp_round_unscaled(A));
}

int mp_number_equal(mp_number *A, mp_number *B) {
    return A->data.val == B->data.val;
}

int mp_number_greater(mp_number *A, mp_number *B)
{
    return A->data.val > B->data.val;
}

int mp_number_less(mp_number *A, mp_number *B)
{
    return A->data.val < B->data.val;
}

int mp_number_nonequalabs(mp_number *A, mp_number *B)
{
    return abs(A->data.val) != abs(B->data.val);
}

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

@ Here is a procedure analogous to |print_int|. If the output of this procedure
is subsequently read by \MP\ and converted by the |round_decimals| routine above,
it turns out that the original value will be reproduced exactly. A decimal point
is printed only if the value is not an integer. If there is more than one way to
print the result with the optimum number of digits following the decimal point,
the closest possible value is given.

The invariant relation in the |repeat| loop is that a sequence of decimal
digits yet to be printed will yield the original number if and only if they form
a fraction~$f$ in the range $s-\delta\L10\cdot2^{16}f<s$. We can stop if and only
if $f=0$ satisfies this condition; the loop will terminate before $s$ can
possibly become zero. We round to five digits

@ @c
static char *mp_string_scaled (MP mp, int s)
{
    (void) mp;
    static char scaled_string[32];
    int i = 0;
    if (s < 0) {
        scaled_string[i++] = '-';
        s = -s;
    }
    /* print the integer part */
    mp_snprintf ((scaled_string+i), 12, "%d", (int) (s / unity));
    while (*(scaled_string+i)) {
        i++;
    }
    s = 10 * (s % unity) + 5;
    if (s != 5) {
        /* amount of allowable inaccuracy, scaled */
        int delta = 10;
        scaled_string[i++] = '.';
        do {
            /* round the final digit */
            if (delta > unity) {
                s = s + 0100000 - (delta / 2);
            }
            scaled_string[i++] = '0' + (s / unity);
            s = 10 * (s % unity);
            delta = delta * 10;
        } while (s > delta);
    }
    scaled_string[i] = '\0';
    return scaled_string;
}

@ Addition is not always checked to make sure that it doesn't overflow, but in
places where overflow isn't too unlikely the |slow_add| routine is used.

@c
void mp_slow_add (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig)
{
    int x = x_orig->data.val;
    int y = y_orig->data.val;
    if (x >= 0) {
        if (y <= EL_GORDO - x) {
            ret->data.val = x + y;
        } else {
            mp->arith_error = 1;
            ret->data.val =  EL_GORDO;
        }
    } else if (-y <= EL_GORDO + x) {
        ret->data.val = x + y;
    } else {
        mp->arith_error = 1;
        ret->data.val = negative_EL_GORDO;
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

@ @c
static int mp_make_fraction (MP mp, int p, int q)
{
    if (q == 0) {
        mp_confusion (mp, "division by zero");
        @:this can't happen /}{\quad \./@>
        return 0;
    } else {
        double d = TWEXP28 * (double) p / (double) q;
        if ((p ^ q) >= 0) {
            d += 0.5;
            if (d >= TWEXP31) {
                mp->arith_error = 1;
                return EL_GORDO;
            } else {
                int i = (int) d;
                if (d == (double) i && (((q > 0 ? -q : q) & 077777) * (((i & 037777) << 1) - 1) & 04000) != 0) {
                    --i;
                }
                return i;
            }
        } else {
            d -= 0.5;
            if (d <= -TWEXP31) {
                mp->arith_error = 1;
                return -negative_EL_GORDO;
            } else {
                int i = (int) d;
                if (d == (double) i && (((q > 0 ? q : -q) & 077777) * (((i & 037777) << 1) + 1) & 04000) != 0) {
                    ++i;
                }
                return i;
            }
        }
    }
}

void mp_number_make_fraction (MP mp, mp_number *ret, mp_number *p, mp_number *q)
{
    ret->data.val = mp_make_fraction (mp, p->data.val, q->data.val);
}

@ The dual of |make_fraction| is |take_fraction|, which multiplies a given
integer~|q| by a fraction~|f|. When the operands are positive, it computes
$p=\lfloor qf/2^{28}+{1\over2}\rfloor$, a symmetric function of |q| and~|f|.

This routine is even more \quote {inner loopy} than |make_fraction|; the present
implementation consumes almost 20\pct! of \MP's computation time during typical
jobs, so a machine-language substitute is advisable. @^inner loop@> @^system
dependencies@>

@ Here |q| is the fraction. @c
int mp_take_fraction (MP mp, int p, int q)
{
    double d = (double) p *(double) q *TWEXP_28;
    if ((p ^ q) >= 0) {
        d += 0.5;
        if (d >= TWEXP31) {
            if (d != TWEXP31 || (((p & 077777) * (q & 077777)) & 040000) == 0) {
                mp->arith_error = 1;
            }
            return EL_GORDO;
        } else {
            int i = (int) d;
            if (d == (double) i && (((p & 077777) * (q & 077777)) & 040000) != 0) {
                --i;
            }
            return i;
        }
    } else {
        d -= 0.5;
        if (d <= -TWEXP31) {
            if (d != -TWEXP31 || ((-(p & 077777) * (q & 077777)) & 040000) == 0) {
                mp->arith_error = 1;
            }
            return -negative_EL_GORDO;
        } else {
            int i = (int) d;
            if (d == (double) i && ((-(p & 077777) * (q & 077777)) & 040000) != 0) {
                ++i;
            }
            return i;
        }
    }
}

void mp_number_take_fraction (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    ret->data.val = mp_take_fraction (mp, p_orig->data.val, q_orig->data.val);
}

@ When we want to multiply something by a |scaled| quantity, we use a scheme
analogous to |take_fraction| but with a different scaling. Given positive
operands, |take_scaled| computes the quantity $p=\lfloor
qf/2^{16}+{1\over2}\rfloor$.

Once again it is a good idea to use a machine-language replacement if possible;
otherwise |take_scaled| will use more than 2\pct! of the running time when the
Computer Modern fonts are being generated. @^inner loop@>

@ @c
static int mp_take_scaled (MP mp, int p, int q)
{ /* q = scaled */
    double d = (double) p *(double) q *TWEXP_16;
    if ((p ^ q) >= 0) {
        d += 0.5;
        if (d >= TWEXP31) {
            if (d != TWEXP31 || (((p & 077777) * (q & 077777)) & 040000) == 0) {
                mp->arith_error = 1;
            }
            return EL_GORDO;
        } else {
            int i = (int) d;
            if (d == (double) i && (((p & 077777) * (q & 077777)) & 040000) != 0) {
                --i;
            }
            return i;
        }
    } else {
        d -= 0.5;
        if (d <= -TWEXP31) {
            if (d != -TWEXP31 || ((-(p & 077777) * (q & 077777)) & 040000) == 0) {
                mp->arith_error = 1;
            }
            return -negative_EL_GORDO;
        } else {
            int i = (int) d;
            if (d == (double) i && ((-(p & 077777) * (q & 077777)) & 040000) != 0) {
                ++i;
            }
            return i;
        }
    }
}

void mp_number_take_scaled (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    ret->data.val = mp_take_scaled(mp, p_orig->data.val, q_orig->data.val);
}

@ For completeness, there's also |make_scaled|, which computes a quotient as a
|scaled| number instead of as a |fraction|. In other words, the result is
$\lfloor2^{16}p/q+{1\over2}\rfloor$, if the operands are positive. \ (This
procedure is not used especially often, so it is not part of \MP's inner loop.)

@ @c
int mp_make_scaled (MP mp, int p, int q)
{
    if (q == 0) {
        mp_confusion (mp, "division by zero");
        @:this can't happen /}{\quad \./@>
        return 0;
    } else {
        double d = TWEXP16 * (double) p / (double) q;
        if ((p ^ q) >= 0) {
            d += 0.5;
            if (d >= TWEXP31) {
                mp->arith_error = 1;
                return EL_GORDO;
            } else {
                int i = (int) d;
                if (d == (double) i && (((q > 0 ? -q : q) & 077777) * (((i & 037777) << 1) - 1) & 04000) != 0) {
                    --i;
                }
                return i;
            }
        } else {
            d -= 0.5;
            if (d <= -TWEXP31) {
                mp->arith_error = 1;
                return -negative_EL_GORDO;
            } else {
                int i = (int) d;
                if (d == (double) i && (((q > 0 ? q : -q) & 077777) * (((i & 037777) << 1) + 1) & 04000) != 0) {
                    ++i;
                }
                return i;
            }
        }
    }
}

void mp_number_make_scaled (MP mp, mp_number *ret, mp_number *p_orig, mp_number *q_orig)
{
    ret->data.val = mp_make_scaled(mp, p_orig->data.val, q_orig->data.val);
}

@ The following function is used to create a scaled integer from a given decimal
fraction $(.d_0d_1\ldots d_{k-1})$, where |0<=k<=17|.

@ This converts a decimal fraction.
@c
static int mp_round_decimals (MP mp, unsigned char *b, int k)
{
    unsigned a = 0; /* the accumulator */
    int l = 0;
    (void) mp; /* Will be needed later */
    for (l = k-1; l >= 0; l-- ) {
        if (l<16) {
            /* digits for |k>=17| cannot affect the result */
            a = (a + (unsigned) (*(b+l) - '0') * two) / 10;
        }
    }
    return (int) (a + 1)/2;
}

@ @* Scanning numbers in the input.

@ We no longer have these character mapping so we can just as well do the next
without class checking. Also because signs are hard checked.

@ @c
static void mp_wrapup_numeric_token (MP mp, int n, int f)
{
    if (n < 32768) {
        int mod = (n * unity + f); /* scaled */
        set_cur_mod(mod);
        if (mod >= fraction_one) {
            if (internal_value(mp_warning_check_internal).data.val > 0 && (mp->scanner_status != mp_tex_flushing_state)) {
                char msg[256];
                mp_snprintf(msg, 256, "Number is too large (%s)", mp_string_scaled(mp,mod));
                @.Number is too large@>
                mp_error(
                    mp,
                    msg,
                    "It is at least 4096. Continue and I'll try to cope with that big value;\n"
                    "but it might be dangerous. (Set warningcheck:=0 to suppress this message.)"
                );
            }
        }
    } else if (mp->scanner_status != mp_tex_flushing_state) {
        mp_error(
            mp,
            "Enormous number has been reduced",
            "I can\'t handle numbers bigger than 32767.99998; so I've changed your constant\n"
            "to that maximum amount."
        );
        @.Enormous number...@>
        set_cur_mod(EL_GORDO);
    }
    set_cur_cmd(mp_numeric_command);
}

@ @c
void mp_scan_fractional_token (MP mp, int n)
{ /* n: scaled */
    int f; /* scaled */
    int k = 0;
    do {
        k++;
        mp->cur_input.loc_field++;
    } while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class);
    f = mp_round_decimals(mp, (unsigned char *)(mp->buffer+mp->cur_input.loc_field-k), (int) k);
    if (f == unity) {
        n++;
        f = 0;
    }
    mp_wrapup_numeric_token(mp, n, f);
}


@ @c
void mp_scan_numeric_token (MP mp, int n)
{
    while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
        if (n < 32768) {
            n = 10 * n + mp->buffer[mp->cur_input.loc_field] - '0';
        }
        mp->cur_input.loc_field++;
    }
    if (! (mp->buffer[mp->cur_input.loc_field] == '.' && mp->char_class[mp->buffer[mp->cur_input.loc_field + 1]] == mp_digit_class)) {
        mp_wrapup_numeric_token(mp, n, 0);
    } else {
        mp->cur_input.loc_field++;
        mp_scan_fractional_token(mp, n);
    }
}

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
is less than $16\over3$. The denominator is nonnegative and at most~6. Hence the
fixed-point calculations below are guaranteed to stay within the bounds of a
32-bit computer word.

The angles $\theta$ and $\phi$ are given implicitly in terms of |fraction|
arguments |st|, |ct|, |sf|, and |cf|, representing $\sin\theta$, $\cos\theta$,
$\sin\phi$, and $\cos\phi$, respectively.

@c
void mp_velocity (MP mp, mp_number *ret, mp_number *st, mp_number *ct, mp_number *sf, mp_number *cf, mp_number *t)
{
    int acc, num, denom; /* registers for intermediate calculations */
    acc = mp_take_fraction(mp, st->data.val - (sf->data.val / 16), sf->data.val - (st->data.val / 16));
    acc = mp_take_fraction(mp, acc, ct->data.val - cf->data.val);
    num = fraction_two + mp_take_fraction(mp, acc, 379625062);
    /*
        $2^{28}\sqrt2\approx379625062.497$
    */
    denom = fraction_three + mp_take_fraction(mp, ct->data.val, 497706707) + mp_take_fraction (mp, cf->data.val, 307599661);
    /*
        $3\cdot2^{27}\cdot(\sqrt5-1)\approx497706706.78$ and
        $3\cdot2^{27}\cdot(3-\sqrt5\,)\approx307599661.22$
    */
    if (t->data.val != unity) {
        /* |make_scaled(fraction,scaled)=fraction| */
        num = mp_make_scaled (mp, num, t->data.val);
    }
    if (num / 4 >= denom) {
        ret->data.val = fraction_four;
    } else {
        ret->data.val = mp_make_fraction(mp, num, denom);
    }
    /* |printf ("num,denom=%f,%f -=> %f\n", num/65536.0, denom/65536.0, ret.data.val/65536.0);| */
}

@ The following somewhat different subroutine tests rigorously if $ab$ is greater
than, equal to, or less than~$cd$, given integers $(a,b,c,d)$. In most cases a
quick decision is reached. The result is $+1$, 0, or~$-1$ in the three respective
cases.

@c
static int mp_ab_vs_cd (mp_number *a_orig, mp_number *b_orig, mp_number *c_orig, mp_number *d_orig)
{
    int a = a_orig->data.val;
    int b = b_orig->data.val;
    int c = c_orig->data.val;
    int d = d_orig->data.val;
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
                return 0;
            } else {
                return 1;
            }
        } else if (d == 0) {
            return a == 0 ? 0 : -1;
        } else {
            int q = a;
            a = c;
            c = q;
            q = -b;
            b = -d;
            d = q;
        }
    } else if (b <= 0) {
        if (b < 0 && a > 0) {
            return -1;
        } else {
            return c == 0 ? 0 : -1;
        }
    }
    while (1) {
        int q = a / d;
        int r = c / b;
        if (q != r) {
            return q > r ? 1 : -1;
        } else {
            q = a % d;
            r = c % b;
            if (r == 0) {
                return q ? 1 : 0;
            } else if (q == 0) {
                return -1;
            } else {
                a = b;
                b = q;
                c = d;
                d = r;
            }
        }
    }
    /* now |a>d>0| and |c>b>0| */
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
static void mp_crossing_point (MP mp, mp_number *ret, mp_number *aa, mp_number *bb, mp_number *cc)
{
    int x, xx, x0, x1, x2; /* temporary registers for bisection */
    int a = aa->data.val;
    int b = bb->data.val;
    int c = cc->data.val;
    int d;                 /* recursive counter */
    (void) mp;
    if (a < 0) {
        ret->data.val = zero_crossing;
        return;
    } else if (c >= 0) {
        if (b >= 0) {
            if (c > 0) {
                ret->data.val = no_crossing;
            } else if ((a == 0) && (b == 0)) {
                ret->data.val = no_crossing;
            } else {
                ret->data.val = one_crossing;
            }
            return;
        } else if (a == 0) {
            ret->data.val = zero_crossing;
            return;
        }
    } else if (a == 0) {
        if (b <= 0) {
            ret->data.val = zero_crossing;
            return;
        }
    }
    /* Use bisection to find the crossing point... */
    d = 1;
    x0 = a;
    x1 = a - b;
    x2 = b - c;
    do {
        x = (x1 + x2) / 2;
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
                    ret->data.val = no_crossing;
                    return;
                } else {
                    x1 = x;
                    d = d + d + 1;
                }
            }
        }
    } while (d < fraction_one);
    ret->data.val = d - fraction_one;
}

@ We conclude this set of elementary routines with some simple rounding and
truncation operations.

@ |round_unscaled| rounds a |scaled| and converts it to |int|
@c
int mp_round_unscaled(mp_number *x_orig)
{
    int x = x_orig->data.val;
    if (x >= 32768) {
        return 1 + ((x-32768) / 65536);
    } else if (x >= -32768) {
        return 0;
    } else {
        return -(1+((-(x+1)-32768) / 65536));
    }
}

@ |number_floor| floors a |scaled|

@c
void mp_number_floor(mp_number *i)
{
    i->data.val = i->data.val&-65536;
}

@ |fraction_to_scaled| rounds a |fraction| and converts it to |scaled|
@c
void mp_fraction_to_round_scaled(mp_number *x_orig)
{
    int x = x_orig->data.val;
    x_orig->type = mp_scaled_type;
    x_orig->data.val = (x>=2048 ? 1+((x-2048) / 4096)  : ( x>=-2048 ? 0 : -(1+((-(x+1)-2048) / 4096))));
}

@* Algebraic and transcendental functions. \MP\ computes all of the necessary
special functions from scratch, without relying on |real| arithmetic or system
subroutines for sines, cosines, etc.

@ To get the square root of a |scaled| number |x|, we want to calculate
$s=\lfloor 2^8\!\sqrt x +{1\over2}\rfloor$. If $x>0$, this is the unique integer
such that $2^{16}x-s\L s^2<2^{16}x+s$. The following subroutine determines $s$ by
an iterative method that maintains the invariant relations $x=2^{46-2k}x_0\bmod
2^{30}$, $0<y=\lfloor 2^{16-2k}x_0\rfloor -s^2+s\L q=2s$, where $x_0$ is the
initial value of $x$. The value of~$y$ might, however, be zero at the start of
the first iteration.

@c
void mp_square_rt (MP mp, mp_number *ret, mp_number *x_orig)
{
    int x = x_orig->data.val;
    if (x <= 0) {
        if (x < 0) {
            char msg[256];
            mp_snprintf(msg, 256, "Square root of %s has been replaced by 0", mp_string_scaled(mp, x));
            @.Square root...replaced by 0@>
            mp_error(
                mp,
                msg,
                "Since I don't take square roots of negative numbers, I'm zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        }
        ret->data.val = 0;
    } else {
        int k = 23; /* iteration control counter */
        int y;
        int q = 2;
        while (x < fraction_two) {  /* i.e., |while x<@t$2^{29}$@>|\unskip */
            k--;
            x = x + x + x + x;
        }
        if (x < fraction_four)
            y = 0;
        else {
            x = x - fraction_four;
            y = 1;
        }
        do {
            @<Decrease |k| by 1, maintaining the invariant relations between |x|, |y|, and~|q|@>
        } while (k != 0);
        ret->data.val = (int) (q/2);
    }
}

@ @<Decrease |k| by 1, maintaining...@>=
x += x;
y += y;
if (x >= fraction_four) {
    /* note that |fraction_four=@t$2^{30}$@>| */
    x = x - fraction_four;
    y++;
};
x += x;
y = y + y - q;
q += q;
if (x >= fraction_four) {
    x = x - fraction_four;
    y++;
};
if (y > (int) q) {
    y -= q;
    q += 2;
} else if (y <= 0) {
    q -= 2;
    y += q;
};
k--;

@ Pythagorean addition $\psqrt{a^2+b^2}$ is implemented by an elegant iterative
scheme due to Cleve Moler and Donald Morrison [{\sl IBM Journal @^Moler, Cleve
Barry@> @^Morrison, Donald Ross@> of Research and Development \bf27} (1983),
577--581]. It modifies |a| and~|b| in such a way that their Pythagorean sum
remains invariant, while the smaller argument decreases.

@c
void mp_pyth_add (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    int a = abs(a_orig->data.val);
    int b = abs(b_orig->data.val);
    if (a < b) {
        int r = b;
        b = a;
        a = r;
    }
    /* now |0<=b<=a| */
    if (b > 0) {
        int big;  /* is the result dangerously near $2^{31}$? */
        if (a < fraction_two) {
            big = 0;
        } else {
            a = a / 4;
            b = b / 4;
            big = 1;
        }
        /* we reduced the precision to avoid arithmetic overflow */
        @<Replace |a| by an approximation to $\psqrt{a^2+b^2}$@>
        if (big) {
            if (a < fraction_two) {
                a = a + a + a + a;
            } else {
                mp->arith_error = 1;
                a = EL_GORDO;
            }
        }
    }
    ret->data.val = a;
}

@ The key idea here is to reflect the vector $(a,b)$ about the line through
$(a,b/2)$.

@<Replace |a| by an approximation to $\psqrt{a^2+b^2}$@>=
while (1) {
    int r = mp_make_fraction(mp, b, a);
    r = mp_take_fraction(mp, r, r);
    /* now $r\approx b^2/a^2$ */
    if (r == 0) {
        break;
    } else {
        r = mp_make_fraction(mp, r, fraction_four + r);
        a = a + mp_take_fraction(mp, a + a, r);
        b = mp_take_fraction(mp, b, r);
    }
}

@ Here is a similar algorithm for $\psqrt{a^2-b^2}$. It converges slowly when $b$
is near $a$, but otherwise it works fine.

@c
void mp_pyth_sub (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    int a = abs(a_orig->data.val);
    int b = abs(b_orig->data.val);
    if (a <= b) {
        @<Handle erroneous |pyth_sub| and set |a:=0|@>
    } else {
        int big;  /* is the result dangerously near $2^{31}$? */
        if (a < fraction_four) {
            big = 0;
        } else {
            a = (int) a/2;
            b = (int) b/2;
            big = 1;
        }
        @<Replace |a| by an approximation to $\psqrt{a^2-b^2}$@>
        if (big) {
            a *= 2;
        }
    }
    ret->data.val = a;
}

@ @<Replace |a| by an approximation to $\psqrt{a^2-b^2}$@>=
while (1) {
    int r = mp_make_fraction(mp, b, a);
    r = mp_take_fraction(mp, r, r);
    /* now $r\approx b^2/a^2$ */
    if (r == 0) {
        break;
    } else {
        r = mp_make_fraction(mp, r, fraction_four - r);
        a = a - mp_take_fraction(mp, a + a, r);
        b = mp_take_fraction(mp, b, r);
    }
}

@ @<Handle erroneous |pyth_sub| and set |a:=0|@>=
if (a < b) {
    char msg[256];
    char *astr = mp_strdup(mp_string_scaled(mp, a));
    mp_snprintf(msg, 256, "Pythagorean subtraction %s+-+%s has been replaced by 0", astr, mp_string_scaled(mp, b));
    mp_memory_free(astr);
    @.Pythagorean...@>
    mp_error(
        mp,
        msg,
        "Since I don't take square roots of negative numbers, I'm zeroing this one.\n"
        "Proceed, with fingers crossed."
    );
}
a = 0;

@ For the moment we just abuse doubles here.

@c
void mp_power_of (MP mp, mp_number *ret, mp_number *a_orig, mp_number *b_orig)
{
    double p = pow(mp_number_to_double(a_orig), mp_number_to_double(b_orig));
    long r = lround(p * 65536.0);
    if (r > 0) {
        if (r >= EL_GORDO) {
            mp->arith_error = 1;
            r = EL_GORDO;
        }
    } else if (r < 0) {
        if (r <= - EL_GORDO) {
            mp->arith_error = 1;
            r = - EL_GORDO;
        }
    }
    ret->data.val = r;
}

@ The subroutines for logarithm and exponential involve two tables. The first is
simple: |two_to_the[k]| equals $2^k$. The second involves a bit more calculation,
which the author claims to have done correctly: |mp_m_spec_log[k]| is $2^{27}$ times
$\ln\bigl(1/(1-2^{-k})\bigr)= 2^{-k}+{1\over2}2^{-2k}+{1\over3}2^{-3k}+\cdots\,$,
rounded to the nearest integer.

@<Declarations@>=
static const int mp_m_spec_log[29] = {
    0, 93032640, 38612034, 17922280, 8662214, 4261238, 2113709, 1052693, 525315,
    262400, 131136, 65552, 32772, 16385, 8192, 4096, 2048, 1024, 512, 256, 128,
    64, 32, 16, 8, 4, 2, 1, 1
};

@ Here is the routine that calculates $2^8$ times the natural logarithm of a
|scaled| quantity; it is an integer approximation to $2^{24}\ln(x/2^{16})$, when
|x| is a given positive integer.

The method is based on exercise 1.2.2--25 in {\sl The Art of Computer
Programming}: During the main iteration we have $1\L 2^{-30}x<1/(1-2^{1-k})$,
and the logarithm of $2^{30}x$ remains to be added to an accumulator register
called~$y$. Three auxiliary bits of accuracy are retained in~$y$ during the
calculation, and sixteen auxiliary bits to extend |y| are kept in~|z| during the
initial argument reduction. (We add $100\cdot2^{16}=6553600$ to~|z| and subtract
100 from~|y| so that |z| will not become negative; also, the actual amount
subtracted from~|y| is~96, not~100, because we want to add~4 for rounding before
the final division by~8.)

@c
void mp_m_log (MP mp, mp_number *ret, mp_number *x_orig)
{
    int x = x_orig->data.val;
    if (x <= 0) {
        @<Handle non-positive logarithm@>
    } else {
        int k = 2;                    /* iteration counter, starts at 2 */
        int y = 1302456956 + 4 - 100; /* $14\times2^{27}\ln2\approx1302456956.421063$ */
        int z = 27595 + 6553600;      /* and $2^{16}\times .421063\approx 27595$ */
        /* $2^{27}\ln2\approx 93032639.74436163$ and $2^{16}\times.74436163\approx 48782$ */
        while (x < fraction_four) {
            x = 2*x;
            y -= 93032639;
            z -= 48782;
        }
        y = y + (z / unity);
        while (x > fraction_four + 4) {
            @<Increase |k| until |x| can be multiplied by a factor of $2^{-k}$, and adjust $y$ accordingly@>
        }
        ret->data.val = (y / 8);
    }
}

@ @<Increase |k| until |x| can...@>=
{
    z = ((x - 1) / two_to_the (k)) + 1; /* $z=\lceil x/2^k\rceil$ */
    while (x < fraction_four + z) {
        z = (z + 1)/2;
        k++;
    };
    y += mp_m_spec_log[k];
    x -= z;
}

@ @<Handle non-positive logarithm@>=
{
    char msg[256];
    mp_snprintf(msg, 256, "Logarithm of %s has been replaced by 0", mp_string_scaled(mp, x));
    @.Logarithm...replaced by 0@>
    mp_error(
        mp,
        msg,
        "Since I don't take logs of non-positive numbers, I'm zeroing this one.\n"
        "Proceed, with fingers crossed."
    );
    ret->data.val = 0;
}

@ Conversely, the exponential routine calculates $\exp(x/2^8)$, when |x| is
|scaled|. The result is an integer approximation to $2^{16}\exp(x/2^{24})$, when
|x| is regarded as an integer.

@c
void mp_m_exp (MP mp, mp_number *ret, mp_number *x_orig)
{
    int y, z;  /* auxiliary registers */
    int x = x_orig->data.val;
    if (x > 174436200) {
        /* $2^{24}\ln((2^{31}-1)/2^{16})\approx 174436199.51$ */
        mp->arith_error = 1;
        ret->data.val = EL_GORDO;
    } else if (x < -197694359) {
        /* $2^{24}\ln(2^{-1}/2^{16})\approx-197694359.45$ */
        ret->data.val = 0;
    } else {
        if (x <= 0) {
            z = -8 * x;
            y = 04000000; /* $y=2^{20}$ */
        } else {
            if (x <= 127919879) {
                z = 1023359037 - 8 * x;
                /* $2^{27}\ln((2^{31}-1)/2^{20})\approx 1023359037.125$ */
            } else {
                /* |z| is always nonnegative */
                z = 8 * (174436200 - x);
            }
            y = EL_GORDO;
        }
        @<Multiply |y| by $\exp(-z/2^{27})$@>
        if (x <= 127919879) {
            ret->data.val = ((y + 8) / 16);
        } else {
            ret->data.val = y;
        }
    }
}

@ The idea here is that subtracting |mp_m_spec_log[k]| from |z| corresponds to
multiplying |y| by $1-2^{-k}$.

A subtle point (which had to be checked) was that if $x=127919879$, the value
of~|y| will decrease so that |y+8| doesn't overflow. In fact, $z$ will be 5 in
this case, and |y| will decrease by~64 when |k=25| and by~16 when |k=27|.

@<Multiply |y| by...@>=
{
    int k = 1; /* loop control index */
    while (z > 0) {
        while (z >= mp_m_spec_log[k]) {
            z -= mp_m_spec_log[k];
            y = y - 1 - ((y - two_to_the(k - 1)) / two_to_the(k));
        }
        k++;
    }
}

@ The trigonometric subroutines use an auxiliary table such that |spec_atan[k]|
contains an approximation to the |angle| whose tangent is~$1/2^k$.
$\arctan2^{-k}$ times $2^{20}\cdot180/\pi$

@<Declarations@>=
static const int mp_m_spec_atan[27] = {
    0, 27855475, 14718068, 7471121, 3750058, 1876857, 938658, 469357, 234682,
    117342, 58671, 29335, 14668, 7334, 3667, 1833, 917, 458, 229, 115, 57, 29,
    14, 7, 4, 2, 1
};


@ Given integers |x| and |y|, not both zero, the |n_arg| function returns the
|angle| whose tangent points in the direction $(x,y)$. This subroutine first
determines the correct octant, then solves the problem for |0<=y<=x|, then
converts the result appropriately to return an answer in the range
|-one_eighty_deg<=@t$\theta$@><=one_eighty_deg|. (The answer is |+one_eighty_deg|
if |y=0| and |x<0|, but an answer of |-one_eighty_deg| is possible if, for
example, |y=-1| and $x=-2^{30}$.)

@c
void mp_n_arg (MP mp, mp_number *ret, mp_number *x_orig, mp_number *y_orig)
{
    int z;      /* auxiliary register */
    int t;      /* temporary storage */
    int k;      /* loop counter */
    int octant; /* octant code */
    int x = x_orig->data.val;
    int y = y_orig->data.val;
    if (x >= 0) {
        octant = first_octant;
    } else {
        x = -x;
        octant = first_octant + negate_x;
    }
    if (y < 0) {
        y = -y;
        octant = octant + negate_y;
    }
    if (x < y) {
        t = y;
        y = x;
        x = t;
        octant = octant + switch_x_and_y;
    }
    if (x == 0) {
        mp_error(
            mp,
            "angle(0,0) is taken as zero",
            "The 'angle' between two identical points is undefined. I'm zeroing this one.\n"
            "Proceed, with fingers crossed."
        );
        @.angle(0,0)...zero@>
        ret->data.val = 0;
    } else {
        ret->type = mp_angle_type;
        @<Set variable |z| to the arg of $(x,y)$@>
        @<Return an appropriate answer based on |z| and |octant|@>
    }
}

@ @<Return an appropriate answer...@>=
switch (octant) {
    case first_octant:   ret->data.val =  z;                  break;
    case second_octant:  ret->data.val = -z + ninety_deg;     break;
    case third_octant:   ret->data.val =  z + ninety_deg;     break;
    case fourth_octant:  ret->data.val = -z + one_eighty_deg; break;
    case fifth_octant:   ret->data.val =  z - one_eighty_deg; break;
    case sixth_octant:   ret->data.val = -z - ninety_deg;     break;
    case seventh_octant: ret->data.val =  z - ninety_deg;     break;
    case eighth_octant:  ret->data.val = -z;                  break;
}

@ At this point we have |x>=y>=0|, and |x>0|. The numbers are scaled up or down
until $2^{28}\L x<2^{29}$, so that accurate fixed-point calculations will be
made.

@<Set variable |z| to the arg...@>=
while (x >= fraction_two) {
    x = x/2;
    y = y/2;
}
z = 0;
if (y > 0) {
    while (x < fraction_one) {
        x += x;
        y += y;
    };
    @<Increase |z| to the arg of $(x,y)$@>
}

@ During the calculations of this section, variables |x| and~|y| represent actual
coordinates $(x,2^{-k}y)$. We will maintain the condition |x>=y|, so that the
tangent will be at most $2^{-k}$. If $x<2y$, the tangent is greater than
$2^{-k-1}$. The transformation $(a,b)\mapsto(a+b\tan\phi,b-a\tan\phi)$ replaces
$(a,b)$ by coordinates whose angle has decreased by~$\phi$; in the special case
$a=x$, $b=2^{-k}y$, and $\tan\phi=2^{-k-1}$, this operation reduces to the
particularly simple iteration shown here. [Cf.~John E. Meggitt, @^Meggitt, John
E.@> {\sl IBM Journal of Research and Development \bf6} (1962), 210--226.]

The initial value of |x| will be multiplied by at most
$(1+{1\over2})(1+{1\over8})(1+{1\over32})\cdots\approx 1.7584$; hence there is no
chance of integer overflow.

@<Increase |z|...@>=
k = 0;
do {
    y += y;
    k++;
    if (y > x) {
        z = z + mp_m_spec_atan[k];
        t = x;
        x = x + (y / two_to_the(k + k));
        y = y - t;
    };
} while (k != 15);
do {
    y += y;
    k++;
    if (y > x) {
        z = z + mp_m_spec_atan[k];
        y = y - x;
    };
} while (k != 26);

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
void mp_n_sin_cos (MP mp, mp_number *z_orig, mp_number *n_cos, mp_number *n_sin)
{
    int k;                    /* loop control variable */
    int q;                    /* specifies the quadrant */
    int x, y, t;              /* temporary registers */
    int z = z_orig->data.val; /* scaled */
    mp_number x_n, y_n, ret;
    mp_allocate_number(mp, &ret, mp_scaled_type);
    mp_allocate_number(mp, &x_n, mp_scaled_type);
    mp_allocate_number(mp, &y_n, mp_scaled_type);
    while (z < 0) {
        z = z + three_sixty_deg;
    }
    z = z % three_sixty_deg;
    /* now |0<=z<three_sixty_deg| */
    q = z / forty_five_deg;
    z = z % forty_five_deg;
    x = fraction_one;
    y = x;
    if (! odd(q)) {
        z = forty_five_deg - z;
    }
    @<Subtract angle |z| from |(x,y)|@>
    @<Convert |(x,y)| to the octant determined by~|q|@>
    x_n.data.val = x;
    y_n.data.val = y;
    mp_pyth_add(mp, &ret, &x_n, &y_n);
    n_cos->data.val = mp_make_fraction(mp, x, ret.data.val);
    n_sin->data.val = mp_make_fraction(mp, y, ret.data.val);
    mp_free_number(mp, &ret);
    mp_free_number(mp, &x_n);
    mp_free_number(mp, &y_n);
}

@ In this case the octants are numbered sequentially.

@<Convert |(x,...@>=
switch (q) {
    case 0:                        break;
    case 1: t = x; x =  y; y =  t; break;
    case 2: t = x; x = -y; y =  t; break;
    case 3:        x = -x;         break;
    case 4:        x = -x; y = -y; break;
    case 5: t = x; x = -y; y = -t; break;
    case 6: t = x; x =  y; y = -t; break;
    case 7:                y = -y; break;
}

@ The main iteration of |n_sin_cos| is similar to that of |n_arg| but
applied in reverse. The values of |mp_m_spec_atan[k]| decrease slowly enough
that this loop is guaranteed to terminate before the (nonexistent) value
|mp_m_spec_atan[27]| would be required.

@<Subtract angle |z|...@>=
k = 1;
while (z > 0) {
    if (z >= mp_m_spec_atan[k]) {
        z = z - mp_m_spec_atan[k];
        t = x;
        x = t + y / two_to_the(k);
        y = y - t / two_to_the(k);
    }
    k++;
}
if (y < 0) {
    /* this precaution may never be needed */
    y = 0;
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
        mp->randoms[(i * 21) % 55].data.val = j;
    }
    /* \quote {warm up} the array */
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    mp_new_randoms(mp);
}

@ @c
void mp_print_number (MP mp, mp_number *n)
{
    mp_print_e_str(mp, mp_string_scaled(mp, n->data.val));
}

@ @c
char *mp_number_tostring (MP mp, mp_number *n)
{
    return mp_string_scaled(mp, n->data.val);
}

@ @c
void mp_number_modulo(mp_number *a, mp_number *b)
{
    a->data.val = a->data.val % b->data.val;
}

@ To consume a random fraction, the program below will say |next_random|.

@c
static void mp_next_random (MP mp, mp_number *ret)
{
    if ( mp->j_random == 0) {
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
static void mp_m_unif_rand (MP mp, mp_number *ret, mp_number *x_orig)
{
    mp_number x, abs_x, u, y; /* |y| is trial value */
    mp_allocate_number(mp, &y, mp_fraction_type);
    mp_allocate_clone(mp, &x, mp_scaled_type, x_orig);
    mp_allocate_abs(mp, &abs_x, mp_scaled_type, &x);
    mp_allocate_number(mp, &u, mp_scaled_type);
    mp_next_random(mp, &u);
    /*|take_fraction (y, abs_x, u);|*/
    mp_number_take_fraction(mp, &y, &abs_x, &u);
    if (mp_number_equal(&y, &abs_x)) {
        /*|set_number_to_zero(*ret);|*/
        mp_number_clone(ret, &((math_data *)mp->math)->md_zero_t);
    } else if (mp_number_greater(&x, &((math_data *)mp->math)->md_zero_t)) {
        mp_number_clone(ret, &y);
    } else {
        mp_number_clone(ret, &y);
        mp_number_negate(ret);
    }
    mp_free_number(mp, &y);
    mp_free_number(mp, &abs_x);
    mp_free_number(mp, &x);
    mp_free_number(mp, &u);
}

@ Finally, a normal deviate with mean zero and unit standard deviation can
readily be obtained with the ratio method (Algorithm 3.4.1R in {\sl The Art of
Computer Programming}).

@c
static void mp_m_norm_rand (MP mp, mp_number *ret)
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
            mp_number_take_fraction(mp, &xa, &((math_data *)mp->math)->md_sqrt_8_e_k, &v);
            mp_free_number(mp, &v);
            mp_next_random(mp, &u);
            mp_number_clone(&abs_x, &xa);
            mp_number_abs(&abs_x);
        } while (! mp_number_less(&abs_x, &u));
        mp_number_make_fraction(mp, &r, &xa, &u);
        mp_number_clone(&xa, &r);
        mp_m_log(mp, &la, &u);
        mp_set_number_from_subtraction(&la, &((math_data *)mp->math)->md_twelve_ln_2_k, &la);
    } while (mp_ab_vs_cd(&((math_data *)mp->math)->md_one_k, &la, &xa, &xa) < 0);
    mp_number_clone(ret, &xa);
    mp_free_number(mp, &r);
    mp_free_number(mp, &abs_x);
    mp_free_number(mp, &la);
    mp_free_number(mp, &xa);
    mp_free_number(mp, &u);
}
