/*1:*/
#line 22 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "mpmathbinary.h"
#define ROUND(a) floor((a)+0.5)
#define ROUNDING MPFR_RNDN
#define E_STRING "2.7182818284590452353602874713526624977572470936999595749669676277240766303535"
#define PI_STRING "3.1415926535897932384626433832795028841971693993751058209749445923078164062862"
#define fraction_multiplier 4096
#define angle_multiplier 16 \

#define mpfr_negative_p(a) (mpfr_sgn((a) ) <0)
#define mpfr_positive_p(a) (mpfr_sgn((a) ) > 0)
#define checkZero(dec) if(mpfr_zero_p(dec) &&mpfr_negative_p(dec) ) { \
mpfr_set_zero(dec,1) ; \
} \

#define unity 1
#define two 2
#define three 3
#define four 4
#define half_unit 0.5
#define three_quarter_unit 0.75
#define coef_bound ((7.0/3.0) *fraction_multiplier)
#define fraction_threshold 0.04096
#define half_fraction_threshold (fraction_threshold/2)
#define scaled_threshold 0.000122
#define half_scaled_threshold (scaled_threshold/2)
#define near_zero_angle (0.0256*angle_multiplier)
#define p_over_v_threshold 0x80000
#define equation_threshold 0.001
#define tfm_warn_threshold 0.0625
#define warning_limit pow(2.0,52.0)
#define epsilon "1E-52"
#define epsilonf pow(2.0,-52.0)
#define EL_GORDO "1E1000000"
#define one_third_EL_GORDO (EL_GORDO/3.0)  \

#define MAX_PRECISION 1000.0
#define DEF_PRECISION 34.0 \

#define odd(A) (abs(A) %2==1)  \

#define halfp(A) (integer) ((unsigned) (A) >>1)  \

#define set_cur_cmd(A) mp->cur_mod_->type= (A)
#define set_cur_mod(A) mpfr_set((mpfr_ptr) (mp->cur_mod_->data.n.data.num) ,A,ROUNDING)  \

#define too_precise(a) (a> precision_bits)
#define fraction_half (fraction_multiplier/2)
#define fraction_one (1*fraction_multiplier)
#define fraction_two (2*fraction_multiplier)
#define fraction_three (3*fraction_multiplier)
#define fraction_four (4*fraction_multiplier)  \

#define no_crossing {mpfr_set(ret->data.num,fraction_one_plus_mpfr_t,ROUNDING) ;goto RETURN;}
#define one_crossing {mpfr_set(ret->data.num,fraction_one_mpfr_t,ROUNDING) ;goto RETURN;}
#define zero_crossing {mpfr_set(ret->data.num,zero,ROUNDING) ;goto RETURN;} \


#line 30 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"


/*:1*//*2:*/
#line 32 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

/*5:*/
#line 71 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

#define DEBUG 0
static void mp_binary_scan_fractional_token(MP mp,int n);
static void mp_binary_scan_numeric_token(MP mp,int n);
static void mp_binary_ab_vs_cd(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);
static void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);
static void mp_binary_crossing_point(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c);
static void mp_binary_number_modulo(mp_number*a,mp_number b);
static void mp_binary_print_number(MP mp,mp_number n);
static char*mp_binary_number_tostring(MP mp,mp_number n);
static void mp_binary_slow_add(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig);
static void mp_binary_square_rt(MP mp,mp_number*ret,mp_number x_orig);
static void mp_binary_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin);
static void mp_init_randoms(MP mp,int seed);
static void mp_number_angle_to_scaled(mp_number*A);
static void mp_number_fraction_to_scaled(mp_number*A);
static void mp_number_scaled_to_fraction(mp_number*A);
static void mp_number_scaled_to_angle(mp_number*A);
static void mp_binary_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig);
static void mp_binary_m_norm_rand(MP mp,mp_number*ret);
static void mp_binary_m_exp(MP mp,mp_number*ret,mp_number x_orig);
static void mp_binary_m_log(MP mp,mp_number*ret,mp_number x_orig);
static void mp_binary_pyth_sub(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_binary_pyth_add(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_binary_n_arg(MP mp,mp_number*ret,mp_number x,mp_number y);
static void mp_binary_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,mp_number cf,mp_number t);
static void mp_set_binary_from_int(mp_number*A,int B);
static void mp_set_binary_from_boolean(mp_number*A,int B);
static void mp_set_binary_from_scaled(mp_number*A,int B);
static void mp_set_binary_from_addition(mp_number*A,mp_number B,mp_number C);
static void mp_set_binary_from_substraction(mp_number*A,mp_number B,mp_number C);
static void mp_set_binary_from_div(mp_number*A,mp_number B,mp_number C);
static void mp_set_binary_from_mul(mp_number*A,mp_number B,mp_number C);
static void mp_set_binary_from_int_div(mp_number*A,mp_number B,int C);
static void mp_set_binary_from_int_mul(mp_number*A,mp_number B,int C);
static void mp_set_binary_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C);
static void mp_number_negate(mp_number*A);
static void mp_number_add(mp_number*A,mp_number B);
static void mp_number_substract(mp_number*A,mp_number B);
static void mp_number_half(mp_number*A);
static void mp_number_halfp(mp_number*A);
static void mp_number_double(mp_number*A);
static void mp_number_add_scaled(mp_number*A,int B);
static void mp_number_multiply_int(mp_number*A,int B);
static void mp_number_divide_int(mp_number*A,int B);
static void mp_binary_abs(mp_number*A);
static void mp_number_clone(mp_number*A,mp_number B);
static void mp_number_swap(mp_number*A,mp_number*B);
static int mp_round_unscaled(mp_number x_orig);
static int mp_number_to_int(mp_number A);
static int mp_number_to_scaled(mp_number A);
static int mp_number_to_boolean(mp_number A);
static double mp_number_to_double(mp_number A);
static int mp_number_odd(mp_number A);
static int mp_number_equal(mp_number A,mp_number B);
static int mp_number_greater(mp_number A,mp_number B);
static int mp_number_less(mp_number A,mp_number B);
static int mp_number_nonequalabs(mp_number A,mp_number B);
static void mp_number_floor(mp_number*i);
static void mp_binary_fraction_to_round_scaled(mp_number*x);
static void mp_binary_number_make_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_binary_number_make_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_binary_number_take_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_binary_number_take_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_new_number(MP mp,mp_number*n,mp_number_type t);
static void mp_free_number(MP mp,mp_number*n);
static void mp_set_binary_from_double(mp_number*A,double B);
static void mp_free_binary_math(MP mp);
static void mp_binary_set_precision(MP mp);
static void mp_check_mpfr_t(MP mp,mpfr_t dec);
static int binary_number_check(mpfr_t dec);
static char*mp_binnumber_tostring(mpfr_t n);
static void init_binary_constants(void);
static void free_binary_constants(void);
static mpfr_prec_t precision_digits_to_bits(double i);
static double precision_bits_to_digits(mpfr_prec_t i);

/*:5*//*9:*/
#line 224 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static mpfr_t zero;
static mpfr_t one;
static mpfr_t minusone;
static mpfr_t two_mpfr_t;
static mpfr_t three_mpfr_t;
static mpfr_t four_mpfr_t;
static mpfr_t fraction_multiplier_mpfr_t;
static mpfr_t angle_multiplier_mpfr_t;
static mpfr_t fraction_one_mpfr_t;
static mpfr_t fraction_one_plus_mpfr_t;
static mpfr_t PI_mpfr_t;
static mpfr_t epsilon_mpfr_t;
static mpfr_t EL_GORDO_mpfr_t;
static boolean initialized= false;


/*:9*//*25:*/
#line 840 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_make_fraction(MP mp,mpfr_t ret,mpfr_t p,mpfr_t q);

/*:25*//*27:*/
#line 862 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_take_fraction(MP mp,mpfr_t ret,mpfr_t p,mpfr_t q);

/*:27*//*31:*/
#line 903 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_wrapup_numeric_token(MP mp,unsigned char*start,unsigned char*stop);

/*:31*/
#line 33 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;

/*:2*//*6:*/
#line 156 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

int binary_number_check(mpfr_t dec)
{
int test= false;
if(!mpfr_number_p(dec)){
test= true;
if(mpfr_inf_p(dec)){
mpfr_set(dec,EL_GORDO_mpfr_t,ROUNDING);
if(mpfr_negative_p(dec)){
mpfr_neg(dec,dec,ROUNDING);
}
}else{
mpfr_set_zero(dec,1);
}
}
checkZero(dec);
return test;
}
void mp_check_mpfr_t(MP mp,mpfr_t dec)
{
mp->arith_error= binary_number_check(dec);
}




/*:6*//*7:*/
#line 184 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static double precision_bits;
mpfr_prec_t precision_digits_to_bits(double i)
{
return i/log10(2);
}
double precision_bits_to_digits(mpfr_prec_t d)
{
return d*log10(2);
}


/*:7*//*10:*/
#line 241 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void init_binary_constants(void){
if(!initialized){
mpfr_inits2(precision_bits,one,minusone,zero,two_mpfr_t,three_mpfr_t,four_mpfr_t,fraction_multiplier_mpfr_t,
fraction_one_mpfr_t,fraction_one_plus_mpfr_t,angle_multiplier_mpfr_t,PI_mpfr_t,
epsilon_mpfr_t,EL_GORDO_mpfr_t,(mpfr_ptr)0);
mpfr_set_si(one,1,ROUNDING);
mpfr_set_si(minusone,-1,ROUNDING);
mpfr_set_si(zero,0,ROUNDING);
mpfr_set_si(two_mpfr_t,two,ROUNDING);
mpfr_set_si(three_mpfr_t,three,ROUNDING);
mpfr_set_si(four_mpfr_t,four,ROUNDING);
mpfr_set_si(fraction_multiplier_mpfr_t,fraction_multiplier,ROUNDING);
mpfr_set_si(fraction_one_mpfr_t,fraction_one,ROUNDING);
mpfr_set_si(fraction_one_plus_mpfr_t,(fraction_one+1),ROUNDING);
mpfr_set_si(angle_multiplier_mpfr_t,angle_multiplier,ROUNDING);
mpfr_set_str(PI_mpfr_t,PI_STRING,10,ROUNDING);
mpfr_set_str(epsilon_mpfr_t,epsilon,10,ROUNDING);
mpfr_set_str(EL_GORDO_mpfr_t,EL_GORDO,10,ROUNDING);
initialized= true;
}
}
void free_binary_constants(void){





}

/*:10*//*11:*/
#line 278 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void*mp_initialize_binary_math(MP mp){
math_data*math= (math_data*)mp_xmalloc(mp,1,sizeof(math_data));
precision_bits= precision_digits_to_bits(MAX_PRECISION);
init_binary_constants();

math->allocate= mp_new_number;
math->free= mp_free_number;
mp_new_number(mp,&math->precision_default,mp_scaled_type);
mpfr_set_d(math->precision_default.data.num,DEF_PRECISION,ROUNDING);
mp_new_number(mp,&math->precision_max,mp_scaled_type);
mpfr_set_d(math->precision_max.data.num,MAX_PRECISION,ROUNDING);
mp_new_number(mp,&math->precision_min,mp_scaled_type);

mpfr_set_d(math->precision_min.data.num,2.0,ROUNDING);

mp_new_number(mp,&math->epsilon_t,mp_scaled_type);
mpfr_set(math->epsilon_t.data.num,epsilon_mpfr_t,ROUNDING);
mp_new_number(mp,&math->inf_t,mp_scaled_type);
mpfr_set(math->inf_t.data.num,EL_GORDO_mpfr_t,ROUNDING);
mp_new_number(mp,&math->warning_limit_t,mp_scaled_type);
mpfr_set_d(math->warning_limit_t.data.num,warning_limit,ROUNDING);
mp_new_number(mp,&math->one_third_inf_t,mp_scaled_type);
mpfr_div(math->one_third_inf_t.data.num,math->inf_t.data.num,three_mpfr_t,ROUNDING);
mp_new_number(mp,&math->unity_t,mp_scaled_type);
mpfr_set(math->unity_t.data.num,one,ROUNDING);
mp_new_number(mp,&math->two_t,mp_scaled_type);
mpfr_set_si(math->two_t.data.num,two,ROUNDING);
mp_new_number(mp,&math->three_t,mp_scaled_type);
mpfr_set_si(math->three_t.data.num,three,ROUNDING);
mp_new_number(mp,&math->half_unit_t,mp_scaled_type);
mpfr_set_d(math->half_unit_t.data.num,half_unit,ROUNDING);
mp_new_number(mp,&math->three_quarter_unit_t,mp_scaled_type);
mpfr_set_d(math->three_quarter_unit_t.data.num,three_quarter_unit,ROUNDING);
mp_new_number(mp,&math->zero_t,mp_scaled_type);
mpfr_set_zero(math->zero_t.data.num,1);

mp_new_number(mp,&math->arc_tol_k,mp_fraction_type);
{
mpfr_div_si(math->arc_tol_k.data.num,one,4096,ROUNDING);

}
mp_new_number(mp,&math->fraction_one_t,mp_fraction_type);
mpfr_set_si(math->fraction_one_t.data.num,fraction_one,ROUNDING);
mp_new_number(mp,&math->fraction_half_t,mp_fraction_type);
mpfr_set_si(math->fraction_half_t.data.num,fraction_half,ROUNDING);
mp_new_number(mp,&math->fraction_three_t,mp_fraction_type);
mpfr_set_si(math->fraction_three_t.data.num,fraction_three,ROUNDING);
mp_new_number(mp,&math->fraction_four_t,mp_fraction_type);
mpfr_set_si(math->fraction_four_t.data.num,fraction_four,ROUNDING);

mp_new_number(mp,&math->three_sixty_deg_t,mp_angle_type);
mpfr_set_si(math->three_sixty_deg_t.data.num,360*angle_multiplier,ROUNDING);
mp_new_number(mp,&math->one_eighty_deg_t,mp_angle_type);
mpfr_set_si(math->one_eighty_deg_t.data.num,180*angle_multiplier,ROUNDING);

mp_new_number(mp,&math->one_k,mp_scaled_type);
mpfr_set_d(math->one_k.data.num,1.0/64,ROUNDING);
mp_new_number(mp,&math->sqrt_8_e_k,mp_scaled_type);
{
mpfr_set_d(math->sqrt_8_e_k.data.num,112428.82793/65536.0,ROUNDING);

}
mp_new_number(mp,&math->twelve_ln_2_k,mp_fraction_type);
{
mpfr_set_d(math->twelve_ln_2_k.data.num,139548959.6165/65536.0,ROUNDING);

}
mp_new_number(mp,&math->coef_bound_k,mp_fraction_type);
mpfr_set_d(math->coef_bound_k.data.num,coef_bound,ROUNDING);
mp_new_number(mp,&math->coef_bound_minus_1,mp_fraction_type);
mpfr_set_d(math->coef_bound_minus_1.data.num,coef_bound-1/65536.0,ROUNDING);
mp_new_number(mp,&math->twelvebits_3,mp_scaled_type);
{
mpfr_set_d(math->twelvebits_3.data.num,1365/65536.0,ROUNDING);

}
mp_new_number(mp,&math->twentysixbits_sqrt2_t,mp_fraction_type);
{
mpfr_set_d(math->twentysixbits_sqrt2_t.data.num,94906265.62/65536.0,ROUNDING);

}
mp_new_number(mp,&math->twentyeightbits_d_t,mp_fraction_type);
{
mpfr_set_d(math->twentyeightbits_d_t.data.num,35596754.69/65536.0,ROUNDING);

}
mp_new_number(mp,&math->twentysevenbits_sqrt2_d_t,mp_fraction_type);
{
mpfr_set_d(math->twentysevenbits_sqrt2_d_t.data.num,25170706.63/65536.0,ROUNDING);

}

mp_new_number(mp,&math->fraction_threshold_t,mp_fraction_type);
mpfr_set_d(math->fraction_threshold_t.data.num,fraction_threshold,ROUNDING);
mp_new_number(mp,&math->half_fraction_threshold_t,mp_fraction_type);
mpfr_set_d(math->half_fraction_threshold_t.data.num,half_fraction_threshold,ROUNDING);
mp_new_number(mp,&math->scaled_threshold_t,mp_scaled_type);
mpfr_set_d(math->scaled_threshold_t.data.num,scaled_threshold,ROUNDING);
mp_new_number(mp,&math->half_scaled_threshold_t,mp_scaled_type);
mpfr_set_d(math->half_scaled_threshold_t.data.num,half_scaled_threshold,ROUNDING);
mp_new_number(mp,&math->near_zero_angle_t,mp_angle_type);
mpfr_set_d(math->near_zero_angle_t.data.num,near_zero_angle,ROUNDING);
mp_new_number(mp,&math->p_over_v_threshold_t,mp_fraction_type);
mpfr_set_d(math->p_over_v_threshold_t.data.num,p_over_v_threshold,ROUNDING);
mp_new_number(mp,&math->equation_threshold_t,mp_scaled_type);
mpfr_set_d(math->equation_threshold_t.data.num,equation_threshold,ROUNDING);
mp_new_number(mp,&math->tfm_warn_threshold_t,mp_scaled_type);
mpfr_set_d(math->tfm_warn_threshold_t.data.num,tfm_warn_threshold,ROUNDING);

math->from_int= mp_set_binary_from_int;
math->from_boolean= mp_set_binary_from_boolean;
math->from_scaled= mp_set_binary_from_scaled;
math->from_double= mp_set_binary_from_double;
math->from_addition= mp_set_binary_from_addition;
math->from_substraction= mp_set_binary_from_substraction;
math->from_oftheway= mp_set_binary_from_of_the_way;
math->from_div= mp_set_binary_from_div;
math->from_mul= mp_set_binary_from_mul;
math->from_int_div= mp_set_binary_from_int_div;
math->from_int_mul= mp_set_binary_from_int_mul;
math->negate= mp_number_negate;
math->add= mp_number_add;
math->substract= mp_number_substract;
math->half= mp_number_half;
math->halfp= mp_number_halfp;
math->do_double= mp_number_double;
math->abs= mp_binary_abs;
math->clone= mp_number_clone;
math->swap= mp_number_swap;
math->add_scaled= mp_number_add_scaled;
math->multiply_int= mp_number_multiply_int;
math->divide_int= mp_number_divide_int;
math->to_boolean= mp_number_to_boolean;
math->to_scaled= mp_number_to_scaled;
math->to_double= mp_number_to_double;
math->to_int= mp_number_to_int;
math->odd= mp_number_odd;
math->equal= mp_number_equal;
math->less= mp_number_less;
math->greater= mp_number_greater;
math->nonequalabs= mp_number_nonequalabs;
math->round_unscaled= mp_round_unscaled;
math->floor_scaled= mp_number_floor;
math->fraction_to_round_scaled= mp_binary_fraction_to_round_scaled;
math->make_scaled= mp_binary_number_make_scaled;
math->make_fraction= mp_binary_number_make_fraction;
math->take_fraction= mp_binary_number_take_fraction;
math->take_scaled= mp_binary_number_take_scaled;
math->velocity= mp_binary_velocity;
math->n_arg= mp_binary_n_arg;
math->m_log= mp_binary_m_log;
math->m_exp= mp_binary_m_exp;
math->m_unif_rand= mp_binary_m_unif_rand;
math->m_norm_rand= mp_binary_m_norm_rand;
math->pyth_add= mp_binary_pyth_add;
math->pyth_sub= mp_binary_pyth_sub;
math->fraction_to_scaled= mp_number_fraction_to_scaled;
math->scaled_to_fraction= mp_number_scaled_to_fraction;
math->scaled_to_angle= mp_number_scaled_to_angle;
math->angle_to_scaled= mp_number_angle_to_scaled;
math->init_randoms= mp_init_randoms;
math->sin_cos= mp_binary_sin_cos;
math->slow_add= mp_binary_slow_add;
math->sqrt= mp_binary_square_rt;
math->print= mp_binary_print_number;
math->tostring= mp_binary_number_tostring;
math->modulo= mp_binary_number_modulo;
math->ab_vs_cd= mp_ab_vs_cd;
math->crossing_point= mp_binary_crossing_point;
math->scan_numeric= mp_binary_scan_numeric_token;
math->scan_fractional= mp_binary_scan_fractional_token;
math->free_math= mp_free_binary_math;
math->set_precision= mp_binary_set_precision;
return(void*)math;
}

void mp_binary_set_precision(MP mp){
double d= mpfr_get_d(internal_value(mp_number_precision).data.num,ROUNDING);
precision_bits= precision_digits_to_bits(d);
}

void mp_free_binary_math(MP mp){
free_number(((math_data*)mp->math)->three_sixty_deg_t);
free_number(((math_data*)mp->math)->one_eighty_deg_t);
free_number(((math_data*)mp->math)->fraction_one_t);
free_number(((math_data*)mp->math)->zero_t);
free_number(((math_data*)mp->math)->half_unit_t);
free_number(((math_data*)mp->math)->three_quarter_unit_t);
free_number(((math_data*)mp->math)->unity_t);
free_number(((math_data*)mp->math)->two_t);
free_number(((math_data*)mp->math)->three_t);
free_number(((math_data*)mp->math)->one_third_inf_t);
free_number(((math_data*)mp->math)->inf_t);
free_number(((math_data*)mp->math)->warning_limit_t);
free_number(((math_data*)mp->math)->one_k);
free_number(((math_data*)mp->math)->sqrt_8_e_k);
free_number(((math_data*)mp->math)->twelve_ln_2_k);
free_number(((math_data*)mp->math)->coef_bound_k);
free_number(((math_data*)mp->math)->coef_bound_minus_1);
free_number(((math_data*)mp->math)->fraction_threshold_t);
free_number(((math_data*)mp->math)->half_fraction_threshold_t);
free_number(((math_data*)mp->math)->scaled_threshold_t);
free_number(((math_data*)mp->math)->half_scaled_threshold_t);
free_number(((math_data*)mp->math)->near_zero_angle_t);
free_number(((math_data*)mp->math)->p_over_v_threshold_t);
free_number(((math_data*)mp->math)->equation_threshold_t);
free_number(((math_data*)mp->math)->tfm_warn_threshold_t);
free_binary_constants();
free(mp->math);
}

/*:11*//*13:*/
#line 492 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_new_number(MP mp,mp_number*n,mp_number_type t){
(void)mp;
n->data.num= mp_xmalloc(mp,1,sizeof(mpfr_t));
mpfr_init2((mpfr_ptr)(n->data.num),precision_bits);
mpfr_set_zero((mpfr_ptr)(n->data.num),1);
n->type= t;
}

/*:13*//*14:*/
#line 503 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_free_number(MP mp,mp_number*n){
(void)mp;
if(n->data.num){
mpfr_clear(n->data.num);
n->data.num= NULL;
}
n->type= mp_nan_type;
}

/*:14*//*15:*/
#line 515 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_set_binary_from_int(mp_number*A,int B){
mpfr_set_si(A->data.num,B,ROUNDING);
}
void mp_set_binary_from_boolean(mp_number*A,int B){
mpfr_set_si(A->data.num,B,ROUNDING);
}
void mp_set_binary_from_scaled(mp_number*A,int B){
mpfr_set_si(A->data.num,B,ROUNDING);
mpfr_div_si(A->data.num,A->data.num,65536,ROUNDING);
}
void mp_set_binary_from_double(mp_number*A,double B){
mpfr_set_d(A->data.num,B,ROUNDING);
}
void mp_set_binary_from_addition(mp_number*A,mp_number B,mp_number C){
mpfr_add(A->data.num,B.data.num,C.data.num,ROUNDING);
}
void mp_set_binary_from_substraction(mp_number*A,mp_number B,mp_number C){
mpfr_sub(A->data.num,B.data.num,C.data.num,ROUNDING);
}
void mp_set_binary_from_div(mp_number*A,mp_number B,mp_number C){
mpfr_div(A->data.num,B.data.num,C.data.num,ROUNDING);
}
void mp_set_binary_from_mul(mp_number*A,mp_number B,mp_number C){
mpfr_mul(A->data.num,B.data.num,C.data.num,ROUNDING);
}
void mp_set_binary_from_int_div(mp_number*A,mp_number B,int C){
mpfr_div_si(A->data.num,B.data.num,C,ROUNDING);
}
void mp_set_binary_from_int_mul(mp_number*A,mp_number B,int C){
mpfr_mul_si(A->data.num,B.data.num,C,ROUNDING);
}
void mp_set_binary_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C){
mpfr_t c,r1;
mpfr_init2(c,precision_bits);
mpfr_init2(r1,precision_bits);
mpfr_sub(c,B.data.num,C.data.num,ROUNDING);
mp_binary_take_fraction(mp,r1,c,t.data.num);
mpfr_sub(A->data.num,B.data.num,r1,ROUNDING);
mpfr_clear(c);
mpfr_clear(r1);
mp_check_mpfr_t(mp,A->data.num);
}
void mp_number_negate(mp_number*A){
mpfr_neg(A->data.num,A->data.num,ROUNDING);
checkZero((mpfr_ptr)A->data.num);
}
void mp_number_add(mp_number*A,mp_number B){
mpfr_add(A->data.num,A->data.num,B.data.num,ROUNDING);
}
void mp_number_substract(mp_number*A,mp_number B){
mpfr_sub(A->data.num,A->data.num,B.data.num,ROUNDING);
}
void mp_number_half(mp_number*A){
mpfr_div_si(A->data.num,A->data.num,2,ROUNDING);
}
void mp_number_halfp(mp_number*A){
mpfr_div_si(A->data.num,A->data.num,2,ROUNDING);
}
void mp_number_double(mp_number*A){
mpfr_mul_si(A->data.num,A->data.num,2,ROUNDING);
}
void mp_number_add_scaled(mp_number*A,int B){
mpfr_add_d(A->data.num,A->data.num,B/65536.0,ROUNDING);
}
void mp_number_multiply_int(mp_number*A,int B){
mpfr_mul_si(A->data.num,A->data.num,B,ROUNDING);
}
void mp_number_divide_int(mp_number*A,int B){
mpfr_div_si(A->data.num,A->data.num,B,ROUNDING);
}
void mp_binary_abs(mp_number*A){
mpfr_abs(A->data.num,A->data.num,ROUNDING);
}
void mp_number_clone(mp_number*A,mp_number B){
mpfr_prec_round(A->data.num,precision_bits,ROUNDING);
mpfr_set(A->data.num,(mpfr_ptr)B.data.num,ROUNDING);
}
void mp_number_swap(mp_number*A,mp_number*B){
mpfr_swap(A->data.num,B->data.num);
}
void mp_number_fraction_to_scaled(mp_number*A){
A->type= mp_scaled_type;
mpfr_div(A->data.num,A->data.num,fraction_multiplier_mpfr_t,ROUNDING);
}
void mp_number_angle_to_scaled(mp_number*A){
A->type= mp_scaled_type;
mpfr_div(A->data.num,A->data.num,angle_multiplier_mpfr_t,ROUNDING);
}
void mp_number_scaled_to_fraction(mp_number*A){
A->type= mp_fraction_type;
mpfr_mul(A->data.num,A->data.num,fraction_multiplier_mpfr_t,ROUNDING);
}
void mp_number_scaled_to_angle(mp_number*A){
A->type= mp_angle_type;
mpfr_mul(A->data.num,A->data.num,angle_multiplier_mpfr_t,ROUNDING);
}


/*:15*//*17:*/
#line 620 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

int mp_number_to_scaled(mp_number A){
double v= mpfr_get_d(A.data.num,ROUNDING);
return(int)(v*65536.0);
}

/*:17*//*18:*/
#line 630 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

int mp_number_to_int(mp_number A){
int32_t result= 0;
if(mpfr_fits_sint_p(A.data.num,ROUNDING)){
result= mpfr_get_si(A.data.num,ROUNDING);
}
return result;
}
int mp_number_to_boolean(mp_number A){
int32_t result= 0;
if(mpfr_fits_sint_p(A.data.num,ROUNDING)){
result= mpfr_get_si(A.data.num,ROUNDING);
}
return result;
}
double mp_number_to_double(mp_number A){
double res= 0.0;
if(mpfr_number_p(A.data.num)){
res= mpfr_get_d(A.data.num,ROUNDING);
}
return res;
}
int mp_number_odd(mp_number A){
return odd(mp_number_to_int(A));
}
int mp_number_equal(mp_number A,mp_number B){
return mpfr_equal_p(A.data.num,B.data.num);
}
int mp_number_greater(mp_number A,mp_number B){
return mpfr_greater_p(A.data.num,B.data.num);
}
int mp_number_less(mp_number A,mp_number B){
return mpfr_less_p(A.data.num,B.data.num);
}
int mp_number_nonequalabs(mp_number A,mp_number B){
return!(mpfr_cmpabs(A.data.num,B.data.num)==0);
}

/*:18*//*21:*/
#line 690 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

char*mp_binnumber_tostring(mpfr_t n){
char*str= NULL,*buffer= NULL;
mpfr_exp_t exp= 0;
int neg= 0;
if((str= mpfr_get_str(NULL,&exp,10,0,n,ROUNDING))> 0){
int numprecdigits= precision_bits_to_digits(precision_bits);
if(*str=='-'){
neg= 1;
}
while(strlen(str)> 0&&*(str+strlen(str)-1)=='0'){
*(str+strlen(str)-1)= '\0';
}
buffer= malloc(strlen(str)+13+numprecdigits+1);





if(buffer){
int i= 0,j= 0;
if(neg){
buffer[i++]= '-';
j= 1;
}
if(strlen(str+j)==0){
buffer[i++]= '0';
}else{

if(exp<=numprecdigits&&exp> -6){
if(exp> 0){
buffer[i++]= str[j++];
while(--exp> 0){
buffer[i++]= (str[j]?str[j++]:'0');
}
if(str[j]){
buffer[i++]= '.';
while(str[j]){
buffer[i++]= str[j++];
}
}
}else{
int absexp;
buffer[i++]= '0';
buffer[i++]= '.';
absexp= -exp;
while(absexp--> 0){
buffer[i++]= '0';
}
while(str[j]){
buffer[i++]= str[j++];
}
}
}else{
buffer[i++]= str[j++];
if(str[j]){
buffer[i++]= '.';
while(str[j]){
buffer[i++]= str[j++];
}
}
{
char msg[256];
int k= 0;
mp_snprintf(msg,256,"%s%d",(exp> 0?"+":""),(int)(exp> 0?(exp-1):(exp-1)));
buffer[i++]= 'E';
while(msg[k]){
buffer[i++]= msg[k++];
}
}
}
}
buffer[i++]= '\0';
}
mpfr_free_str(str);
}
return buffer;
}
char*mp_binary_number_tostring(MP mp,mp_number n){
return mp_binnumber_tostring(n.data.num);
}


/*:21*//*22:*/
#line 773 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_print_number(MP mp,mp_number n){
char*str= mp_binary_number_tostring(mp,n);
mp_print(mp,str);
free(str);
}




/*:22*//*23:*/
#line 787 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_slow_add(MP mp,mp_number*ret,mp_number A,mp_number B){
mpfr_add(ret->data.num,A.data.num,B.data.num,ROUNDING);
}

/*:23*//*24:*/
#line 830 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_make_fraction(MP mp,mpfr_t ret,mpfr_t p,mpfr_t q){
mpfr_div(ret,p,q,ROUNDING);
mp_check_mpfr_t(mp,ret);
mpfr_mul(ret,ret,fraction_multiplier_mpfr_t,ROUNDING);
}
void mp_binary_number_make_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
mp_binary_make_fraction(mp,ret->data.num,p.data.num,q.data.num);
}

/*:24*//*26:*/
#line 853 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_take_fraction(MP mp,mpfr_t ret,mpfr_t p,mpfr_t q){
mpfr_mul(ret,p,q,ROUNDING);
mpfr_div(ret,ret,fraction_multiplier_mpfr_t,ROUNDING);
}
void mp_binary_number_take_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
mp_binary_take_fraction(mp,ret->data.num,p.data.num,q.data.num);
}

/*:26*//*28:*/
#line 875 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_number_take_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
mpfr_mul(ret->data.num,p_orig.data.num,q_orig.data.num,ROUNDING);
}


/*:28*//*29:*/
#line 887 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_number_make_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
mpfr_div(ret->data.num,p_orig.data.num,q_orig.data.num,ROUNDING);
mp_check_mpfr_t(mp,ret->data.num);
}

/*:29*//*38:*/
#line 914 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_wrapup_numeric_token(MP mp,unsigned char*start,unsigned char*stop){
int invalid= 0;
mpfr_t result;
size_t l= stop-start+1;
unsigned long lp,lpbit;
char*buf= mp_xmalloc(mp,l+1,1);
char*bufp= buf;
buf[l]= '\0';
mpfr_init2(result,precision_bits);
(void)strncpy(buf,(const char*)start,l);
invalid= mpfr_set_str(result,buf,10,ROUNDING);

lp= (unsigned long)l;

if((*bufp=='-')||(*bufp=='+')||(*bufp=='0')||(*bufp=='.')){lp--;bufp++;}

lp= strchr(bufp,'.')?lp-1:lp;

bufp= buf+l-1;
while(*bufp=='0'){bufp--;lp= (((lp==0)||(lp==1))?1:lp-1);}

lp= lp> 0?lp:1;

lpbit= (unsigned long)ceil(lp/log10(2)+1);
free(buf);
bufp= NULL;
if(invalid==0){
set_cur_mod(result);

if(too_precise(lpbit)){
if(mpfr_positive_p((mpfr_ptr)(internal_value(mp_warning_check).data.num))&&
(mp->scanner_status!=tex_flushing)){
char msg[256];
const char*hlp[]= {"Continue and I'll try to cope",
"with that value; but it might be dangerous.",
"(Set warningcheck:=0 to suppress this message.)",
NULL};
mp_snprintf(msg,256,"Required precision is too high (%d vs. numberprecision = %f, required precision=%d bits vs internal precision=%f bits)",(unsigned int)lp,mpfr_get_d(internal_value(mp_number_precision).data.num,ROUNDING),(int)lpbit,precision_bits);
;
mp_error(mp,msg,hlp,true);
}
}
}else if(mp->scanner_status!=tex_flushing){
const char*hlp[]= {"I could not handle this number specification",
"probably because it is out of range. Error:",
"",
NULL};
hlp[2]= strerror(errno);
mp_error(mp,"Enormous number has been reduced.",hlp,false);
;
set_cur_mod((mpfr_ptr)(((math_data*)(mp->math))->inf_t.data.num));
}
set_cur_cmd((mp_variable_type)mp_numeric_token);
mpfr_clear(result);
}

/*:38*//*39:*/
#line 971 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void find_exponent(MP mp){
if(mp->buffer[mp->cur_input.loc_field]=='e'||
mp->buffer[mp->cur_input.loc_field]=='E'){
mp->cur_input.loc_field++;
if(!(mp->buffer[mp->cur_input.loc_field]=='+'||
mp->buffer[mp->cur_input.loc_field]=='-'||
mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class)){
mp->cur_input.loc_field--;
return;
}
if(mp->buffer[mp->cur_input.loc_field]=='+'||
mp->buffer[mp->cur_input.loc_field]=='-'){
mp->cur_input.loc_field++;
}
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
mp->cur_input.loc_field++;
}
}
}
void mp_binary_scan_fractional_token(MP mp,int n){
unsigned char*start= &mp->buffer[mp->cur_input.loc_field-1];
unsigned char*stop;
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
mp->cur_input.loc_field++;
}
find_exponent(mp);
stop= &mp->buffer[mp->cur_input.loc_field-1];
mp_wrapup_numeric_token(mp,start,stop);
}


/*:39*//*40:*/
#line 1005 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_scan_numeric_token(MP mp,int n){
unsigned char*start= &mp->buffer[mp->cur_input.loc_field-1];
unsigned char*stop;
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
mp->cur_input.loc_field++;
}
if(mp->buffer[mp->cur_input.loc_field]=='.'&&
mp->buffer[mp->cur_input.loc_field+1]!='.'){
mp->cur_input.loc_field++;
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
mp->cur_input.loc_field++;
}
}
find_exponent(mp);
stop= &mp->buffer[mp->cur_input.loc_field-1];
mp_wrapup_numeric_token(mp,start,stop);
}

/*:40*//*42:*/
#line 1058 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,
mp_number cf,mp_number t){
mpfr_t acc,num,denom;
mpfr_t r1,r2;
mpfr_t arg1,arg2;
mpfr_t i16,fone,fhalf,ftwo,sqrtfive;
mpfr_inits2(precision_bits,acc,num,denom,r1,r2,arg1,arg2,i16,fone,fhalf,ftwo,sqrtfive,(mpfr_ptr)0);
mpfr_set_si(i16,16,ROUNDING);
mpfr_set_si(fone,fraction_one,ROUNDING);
mpfr_set_si(fhalf,fraction_half,ROUNDING);
mpfr_set_si(ftwo,fraction_two,ROUNDING);
mpfr_set_si(sqrtfive,5,ROUNDING);
mpfr_sqrt(sqrtfive,sqrtfive,ROUNDING);
mpfr_div(arg1,sf.data.num,i16,ROUNDING);
mpfr_sub(arg1,st.data.num,arg1,ROUNDING);
mpfr_div(arg2,st.data.num,i16,ROUNDING);
mpfr_sub(arg2,sf.data.num,arg2,ROUNDING);
mp_binary_take_fraction(mp,acc,arg1,arg2);

mpfr_set(arg1,acc,ROUNDING);
mpfr_sub(arg2,ct.data.num,cf.data.num,ROUNDING);
mp_binary_take_fraction(mp,acc,arg1,arg2);

mpfr_sqrt(arg1,two_mpfr_t,ROUNDING);
mpfr_mul(arg1,arg1,fone,ROUNDING);
mp_binary_take_fraction(mp,r1,acc,arg1);
mpfr_add(num,ftwo,r1,ROUNDING);

mpfr_sub(arg1,sqrtfive,one,ROUNDING);
mpfr_mul(arg1,arg1,fhalf,ROUNDING);
mpfr_mul(arg1,arg1,three_mpfr_t,ROUNDING);

mpfr_sub(arg2,three_mpfr_t,sqrtfive,ROUNDING);
mpfr_mul(arg2,arg2,fhalf,ROUNDING);
mpfr_mul(arg2,arg2,three_mpfr_t,ROUNDING);
mp_binary_take_fraction(mp,r1,ct.data.num,arg1);
mp_binary_take_fraction(mp,r2,cf.data.num,arg2);

mpfr_set_si(denom,fraction_three,ROUNDING);
mpfr_add(denom,denom,r1,ROUNDING);
mpfr_add(denom,denom,r2,ROUNDING);

if(!mpfr_equal_p(t.data.num,one)){
mpfr_div(num,num,t.data.num,ROUNDING);
}
mpfr_set(r2,num,ROUNDING);
mpfr_div(r2,r2,four_mpfr_t,ROUNDING);
if(mpfr_less_p(denom,r2)){
mpfr_set_si(ret->data.num,fraction_four,ROUNDING);
}else{
mp_binary_make_fraction(mp,ret->data.num,num,denom);
}
mpfr_clears(acc,num,denom,r1,r2,arg1,arg2,i16,fone,fhalf,ftwo,sqrtfive,(mpfr_ptr)0);
mp_check_mpfr_t(mp,ret->data.num);
}


/*:42*//*43:*/
#line 1121 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
mpfr_t q,r,test;
mpfr_t a,b,c,d;
int cmp= 0;
(void)mp;
mpfr_inits2(precision_bits,q,r,test,a,b,c,d,(mpfr_ptr)0);
mpfr_set(a,(mpfr_ptr)a_orig.data.num,ROUNDING);
mpfr_set(b,(mpfr_ptr)b_orig.data.num,ROUNDING);
mpfr_set(c,(mpfr_ptr)c_orig.data.num,ROUNDING);
mpfr_set(d,(mpfr_ptr)d_orig.data.num,ROUNDING);

mpfr_mul(q,a,b,ROUNDING);
mpfr_mul(r,c,d,ROUNDING);
cmp= mpfr_cmp(q,r);
if(cmp==0){
mpfr_set(ret->data.num,zero,ROUNDING);
goto RETURN;
}
if(cmp> 0){
mpfr_set(ret->data.num,one,ROUNDING);
goto RETURN;
}
if(cmp<0){
mpfr_set(ret->data.num,minusone,ROUNDING);
goto RETURN;
}


/*44:*/
#line 1194 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

if(mpfr_negative_p(a)){
mpfr_neg(a,a,ROUNDING);
mpfr_neg(b,b,ROUNDING);
}
if(mpfr_negative_p(c)){
mpfr_neg(c,c,ROUNDING);
mpfr_neg(d,d,ROUNDING);
}
if(!mpfr_positive_p(d)){
if(!mpfr_negative_p(b)){
if((mpfr_zero_p(a)||mpfr_zero_p(b))&&(mpfr_zero_p(c)||mpfr_zero_p(d)))
mpfr_set(ret->data.num,zero,ROUNDING);
else
mpfr_set(ret->data.num,one,ROUNDING);
goto RETURN;
}
if(mpfr_zero_p(d)){
if(mpfr_zero_p(a))
mpfr_set(ret->data.num,zero,ROUNDING);
else
mpfr_set(ret->data.num,minusone,ROUNDING);
goto RETURN;
}
mpfr_set(q,a,ROUNDING);
mpfr_set(a,c,ROUNDING);
mpfr_set(c,q,ROUNDING);
mpfr_neg(q,b,ROUNDING);
mpfr_neg(b,d,ROUNDING);
mpfr_set(d,q,ROUNDING);
}else if(!mpfr_positive_p(b)){
if(mpfr_negative_p(b)&&mpfr_positive_p(a)){
mpfr_set(ret->data.num,minusone,ROUNDING);
goto RETURN;
}
if(mpfr_zero_p(c))
mpfr_set(ret->data.num,zero,ROUNDING);
else
mpfr_set(ret->data.num,minusone,ROUNDING);
goto RETURN;
}

/*:44*/
#line 1150 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;
while(1){
mpfr_div(q,a,d,ROUNDING);
mpfr_div(r,c,b,ROUNDING);
cmp= mpfr_cmp(q,r);
if(cmp){
if(cmp> 1){
mpfr_set(ret->data.num,one,ROUNDING);
}else{
mpfr_set(ret->data.num,minusone,ROUNDING);
}
goto RETURN;
}
mpfr_remainder(q,a,d,ROUNDING);
mpfr_remainder(r,c,b,ROUNDING);
if(mpfr_zero_p(r)){
if(mpfr_zero_p(q)){
mpfr_set(ret->data.num,zero,ROUNDING);
}else{
mpfr_set(ret->data.num,one,ROUNDING);
}
goto RETURN;
}
if(mpfr_zero_p(q)){
mpfr_set(ret->data.num,minusone,ROUNDING);
goto RETURN;
}
mpfr_set(a,b,ROUNDING);
mpfr_set(b,q,ROUNDING);
mpfr_set(c,d,ROUNDING);
mpfr_set(d,r,ROUNDING);
}
RETURN:
#if DEBUG
fprintf(stdout,"\n%f = ab_vs_cd(%f,%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(a_orig),mp_number_to_double(b_orig),
mp_number_to_double(c_orig),mp_number_to_double(d_orig));
#endif
mp_check_mpfr_t(mp,ret->data.num);
mpfr_clears(q,r,test,a,b,c,d,(mpfr_ptr)0);
return;
}


/*:43*//*45:*/
#line 1269 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_binary_crossing_point(MP mp,mp_number*ret,mp_number aa,mp_number bb,mp_number cc){
mpfr_t a,b,c;
double d;
mpfr_t x,xx,x0,x1,x2;
mpfr_t scratch;
mpfr_inits2(precision_bits,a,b,c,x,xx,x0,x1,x2,scratch,(mpfr_ptr)0);
mpfr_set(a,(mpfr_ptr)aa.data.num,ROUNDING);
mpfr_set(b,(mpfr_ptr)bb.data.num,ROUNDING);
mpfr_set(c,(mpfr_ptr)cc.data.num,ROUNDING);
if(mpfr_negative_p(a))
zero_crossing;
if(!mpfr_negative_p(c)){
if(!mpfr_negative_p(b)){
if(mpfr_positive_p(c)){
no_crossing;
}else if(mpfr_zero_p(a)&&mpfr_zero_p(b)){
no_crossing;
}else{
one_crossing;
}
}
if(mpfr_zero_p(a))
zero_crossing;
}else if(mpfr_zero_p(a)){
if(!mpfr_positive_p(b))
zero_crossing;
}


d= epsilonf;
mpfr_set(x0,a,ROUNDING);
mpfr_sub(x1,a,b,ROUNDING);
mpfr_sub(x2,b,c,ROUNDING);
do{

mpfr_add(x,x1,x2,ROUNDING);
mpfr_div(x,x,two_mpfr_t,ROUNDING);
mpfr_add_d(x,x,1E-12,ROUNDING);
mpfr_sub(scratch,x1,x0,ROUNDING);
if(mpfr_greater_p(scratch,x0)){
mpfr_set(x2,x,ROUNDING);
mpfr_add(x0,x0,x0,ROUNDING);
d+= d;
}else{
mpfr_add(xx,scratch,x,ROUNDING);
if(mpfr_greater_p(xx,x0)){
mpfr_set(x2,x,ROUNDING);
mpfr_add(x0,x0,x0,ROUNDING);
d+= d;
}else{
mpfr_sub(x0,x0,xx,ROUNDING);
if(!mpfr_greater_p(x,x0)){
mpfr_add(scratch,x,x2,ROUNDING);
if(!mpfr_greater_p(scratch,x0))
no_crossing;
}
mpfr_set(x1,x,ROUNDING);
d= d+d+epsilonf;
}
}
}while(d<fraction_one);
mpfr_set_d(scratch,d,ROUNDING);
mpfr_sub(ret->data.num,scratch,fraction_one_mpfr_t,ROUNDING);
RETURN:
#if DEBUG
fprintf(stdout,"\n%f = crossing_point(%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(aa),mp_number_to_double(bb),mp_number_to_double(cc));
#endif
mpfr_clears(a,b,c,x,xx,x0,x1,x2,scratch,(mpfr_ptr)0);
mp_check_mpfr_t(mp,ret->data.num);
return;
}


/*:45*//*47:*/
#line 1349 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

int mp_round_unscaled(mp_number x_orig){
double xx= mp_number_to_double(x_orig);
int x= (int)ROUND(xx);
return x;
}

/*:47*//*48:*/
#line 1358 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_number_floor(mp_number*i){
mpfr_rint_floor(i->data.num,i->data.num,MPFR_RNDD);
}

/*:48*//*49:*/
#line 1364 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_fraction_to_round_scaled(mp_number*x_orig){
x_orig->type= mp_scaled_type;
mpfr_div(x_orig->data.num,x_orig->data.num,fraction_multiplier_mpfr_t,ROUNDING);
}



/*:49*//*51:*/
#line 1378 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_square_rt(MP mp,mp_number*ret,mp_number x_orig){
if(!mpfr_positive_p((mpfr_ptr)x_orig.data.num)){
/*52:*/
#line 1389 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

{
if(mpfr_negative_p((mpfr_ptr)x_orig.data.num)){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*xstr= mp_binary_number_tostring(mp,x_orig);
mp_snprintf(msg,256,"Square root of %s has been replaced by 0",xstr);
free(xstr);
;
mp_error(mp,msg,hlp,true);
}
mpfr_set_zero(ret->data.num,1);
return;
}


/*:52*/
#line 1381 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;
}else{
mpfr_sqrt(ret->data.num,x_orig.data.num,ROUNDING);
}
mp_check_mpfr_t(mp,ret->data.num);
}


/*:51*//*53:*/
#line 1410 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_pyth_add(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
mpfr_t a,b,asq,bsq;
mpfr_inits2(precision_bits,a,b,asq,bsq,(mpfr_ptr)0);
mpfr_set(a,(mpfr_ptr)a_orig.data.num,ROUNDING);
mpfr_set(b,(mpfr_ptr)b_orig.data.num,ROUNDING);
mpfr_mul(asq,a,a,ROUNDING);
mpfr_mul(bsq,b,b,ROUNDING);
mpfr_add(a,asq,bsq,ROUNDING);
mpfr_sqrt(ret->data.num,a,ROUNDING);
mp_check_mpfr_t(mp,ret->data.num);
mpfr_clears(a,b,asq,bsq,(mpfr_ptr)0);
}

/*:53*//*54:*/
#line 1426 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_pyth_sub(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
mpfr_t a,b,asq,bsq;
mpfr_inits2(precision_bits,a,b,asq,bsq,(mpfr_ptr)0);
mpfr_set(a,(mpfr_ptr)a_orig.data.num,ROUNDING);
mpfr_set(b,(mpfr_ptr)b_orig.data.num,ROUNDING);
if(!mpfr_greater_p(a,b)){
/*55:*/
#line 1445 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

{
if(mpfr_less_p(a,b)){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*astr= mp_binary_number_tostring(mp,a_orig);
char*bstr= mp_binary_number_tostring(mp,b_orig);
mp_snprintf(msg,256,"Pythagorean subtraction %s+-+%s has been replaced by 0",astr,bstr);
free(astr);
free(bstr);
;
mp_error(mp,msg,hlp,true);
}
mpfr_set_zero(a,1);
}


/*:55*/
#line 1433 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;
}else{
mpfr_mul(asq,a,a,ROUNDING);
mpfr_mul(bsq,b,b,ROUNDING);
mpfr_sub(a,asq,bsq,ROUNDING);
mpfr_sqrt(a,a,ROUNDING);
}
mpfr_set(ret->data.num,a,ROUNDING);
mp_check_mpfr_t(mp,ret->data.num);
}


/*:54*//*56:*/
#line 1468 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_m_log(MP mp,mp_number*ret,mp_number x_orig){
if(!mpfr_positive_p((mpfr_ptr)x_orig.data.num)){
/*57:*/
#line 1480 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

{
char msg[256];
const char*hlp[]= {
"Since I don't take logs of non-positive numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*xstr= mp_binary_number_tostring(mp,x_orig);
mp_snprintf(msg,256,"Logarithm of %s has been replaced by 0",xstr);
free(xstr);
;
mp_error(mp,msg,hlp,true);
mpfr_set_zero(ret->data.num,1);
}


/*:57*/
#line 1471 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;
}else{
mpfr_log(ret->data.num,x_orig.data.num,ROUNDING);
mp_check_mpfr_t(mp,ret->data.num);
mpfr_mul_si(ret->data.num,ret->data.num,256,ROUNDING);
}
mp_check_mpfr_t(mp,ret->data.num);
}

/*:56*//*58:*/
#line 1499 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_m_exp(MP mp,mp_number*ret,mp_number x_orig){
mpfr_t temp;
mpfr_init2(temp,precision_bits);
mpfr_div_si(temp,x_orig.data.num,256,ROUNDING);
mpfr_exp(ret->data.num,temp,ROUNDING);
mp_check_mpfr_t(mp,ret->data.num);
mpfr_clear(temp);
}


/*:58*//*59:*/
#line 1513 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_n_arg(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig){
if(mpfr_zero_p((mpfr_ptr)x_orig.data.num)&&mpfr_zero_p((mpfr_ptr)y_orig.data.num)){
/*60:*/
#line 1536 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

{
const char*hlp[]= {
"The `angle' between two identical points is undefined.",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_error(mp,"angle(0,0) is taken as zero",hlp,true);
;
mpfr_set_zero(ret->data.num,1);
}


/*:60*/
#line 1516 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;
}else{
mpfr_t atan2val,oneeighty_angle;
mpfr_init2(atan2val,precision_bits);
mpfr_init2(oneeighty_angle,precision_bits);
ret->type= mp_angle_type;
mpfr_set_si(oneeighty_angle,180*angle_multiplier,ROUNDING);
mpfr_div(oneeighty_angle,oneeighty_angle,PI_mpfr_t,ROUNDING);
checkZero((mpfr_ptr)y_orig.data.num);
checkZero((mpfr_ptr)x_orig.data.num);
mpfr_atan2(atan2val,y_orig.data.num,x_orig.data.num,ROUNDING);
mpfr_mul(ret->data.num,atan2val,oneeighty_angle,ROUNDING);
checkZero((mpfr_ptr)ret->data.num);
mpfr_clear(atan2val);
mpfr_clear(oneeighty_angle);
}
mp_check_mpfr_t(mp,ret->data.num);
}


/*:59*//*62:*/
#line 1554 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin){
mpfr_t rad;
mpfr_t one_eighty;
mpfr_init2(rad,precision_bits);
mpfr_init2(one_eighty,precision_bits);
mpfr_set_si(one_eighty,180*16,ROUNDING);
mpfr_mul(rad,z_orig.data.num,PI_mpfr_t,ROUNDING);
mpfr_div(rad,rad,one_eighty,ROUNDING);

mpfr_sin(n_sin->data.num,rad,ROUNDING);
mpfr_cos(n_cos->data.num,rad,ROUNDING);

mpfr_mul(n_cos->data.num,n_cos->data.num,fraction_multiplier_mpfr_t,ROUNDING);
mpfr_mul(n_sin->data.num,n_sin->data.num,fraction_multiplier_mpfr_t,ROUNDING);
mp_check_mpfr_t(mp,n_cos->data.num);
mp_check_mpfr_t(mp,n_sin->data.num);
mpfr_clear(rad);
mpfr_clear(one_eighty);
}

/*:62*//*63:*/
#line 1578 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

#define KK 100
#define LL  37
#define MM (1L<<30)
#define mod_diff(x,y) (((x)-(y))&(MM-1))

static long ran_x[KK];

static void ran_array(long aa[],int n)


{
register int i,j;
for(j= 0;j<KK;j++)aa[j]= ran_x[j];
for(;j<n;j++)aa[j]= mod_diff(aa[j-KK],aa[j-LL]);
for(i= 0;i<LL;i++,j++)ran_x[i]= mod_diff(aa[j-KK],aa[j-LL]);
for(;i<KK;i++,j++)ran_x[i]= mod_diff(aa[j-KK],ran_x[i-LL]);
}




#define QUALITY 1009
static long ran_arr_buf[QUALITY];
static long ran_arr_dummy= -1,ran_arr_started= -1;
static long*ran_arr_ptr= &ran_arr_dummy;

#define TT  70
#define is_odd(x)  ((x)&1)

static void ran_start(long seed)

{
register int t,j;
long x[KK+KK-1];
register long ss= (seed+2)&(MM-2);
for(j= 0;j<KK;j++){
x[j]= ss;
ss<<= 1;if(ss>=MM)ss-= MM-2;
}
x[1]++;
for(ss= seed&(MM-1),t= TT-1;t;){
for(j= KK-1;j> 0;j--)x[j+j]= x[j],x[j+j-1]= 0;
for(j= KK+KK-2;j>=KK;j--)
x[j-(KK-LL)]= mod_diff(x[j-(KK-LL)],x[j]),
x[j-KK]= mod_diff(x[j-KK],x[j]);
if(is_odd(ss)){
for(j= KK;j> 0;j--)x[j]= x[j-1];
x[0]= x[KK];
x[LL]= mod_diff(x[LL],x[KK]);
}
if(ss)ss>>= 1;else t--;
}
for(j= 0;j<LL;j++)ran_x[j+KK-LL]= x[j];
for(;j<KK;j++)ran_x[j-LL]= x[j];
for(j= 0;j<10;j++)ran_array(x,KK+KK-1);
ran_arr_ptr= &ran_arr_started;
}

#define ran_arr_next() (*ran_arr_ptr>=0? *ran_arr_ptr++: ran_arr_cycle())
static long ran_arr_cycle(void)
{
if(ran_arr_ptr==&ran_arr_dummy)
ran_start(314159L);
ran_array(ran_arr_buf,QUALITY);
ran_arr_buf[KK]= -1;
ran_arr_ptr= ran_arr_buf+1;
return ran_arr_buf[0];
}




/*:63*//*64:*/
#line 1653 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_init_randoms(MP mp,int seed){
int j,jj,k;
int i;
j= abs(seed);
while(j>=fraction_one){
j= j/2;
}
k= 1;
for(i= 0;i<=54;i++){
jj= k;
k= j-k;
j= jj;
if(k<0)
k+= fraction_one;
mpfr_set_si(mp->randoms[(i*21)%55].data.num,j,ROUNDING);
}
mp_new_randoms(mp);
mp_new_randoms(mp);
mp_new_randoms(mp);

ran_start((unsigned long)seed);

}

/*:64*//*65:*/
#line 1678 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void mp_binary_number_modulo(mp_number*a,mp_number b){
mpfr_remainder(a->data.num,a->data.num,b.data.num,ROUNDING);
}

/*:65*//*66:*/
#line 1685 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_next_unif_random(MP mp,mp_number*ret){
mp_number rop;
unsigned long int op;
float flt_op;
(void)mp;
mp_new_number(mp,&rop,mp_scaled_type);
op= (unsigned)ran_arr_next();
flt_op= op/(MM*1.0);
mpfr_set_d((mpfr_ptr)(rop.data.num),flt_op,ROUNDING);
mp_number_clone(ret,rop);
free_number(rop);
}



/*:66*//*67:*/
#line 1703 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_next_random(MP mp,mp_number*ret){
if(mp->j_random==0)
mp_new_randoms(mp);
else
mp->j_random= mp->j_random-1;
mp_number_clone(ret,mp->randoms[mp->j_random]);
}

/*:67*//*68:*/
#line 1719 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_binary_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig){
mp_number y;
mp_number x,abs_x;
mp_number u;
char*r;mpfr_exp_t e;
new_fraction(y);
new_number(x);
new_number(abs_x);
new_number(u);
mp_number_clone(&x,x_orig);
mp_number_clone(&abs_x,x);
mp_binary_abs(&abs_x);
mp_next_unif_random(mp,&u);
mpfr_mul(y.data.num,abs_x.data.num,u.data.num,ROUNDING);
free_number(u);
if(mp_number_equal(y,abs_x)){
mp_number_clone(ret,((math_data*)mp->math)->zero_t);
}else if(mp_number_greater(x,((math_data*)mp->math)->zero_t)){
mp_number_clone(ret,y);
}else{
mp_number_clone(ret,y);
mp_number_negate(ret);
}
r= mpfr_get_str(NULL,
&e,
10,
0,
ret->data.num,
ROUNDING
);
mpfr_free_str(r);
free_number(abs_x);
free_number(x);
free_number(y);
}



/*:68*//*69:*/
#line 1762 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_binary_m_norm_rand(MP mp,mp_number*ret){
mp_number ab_vs_cd;
mp_number abs_x;
mp_number u;
mp_number r;
mp_number la,xa;
new_number(ab_vs_cd);
new_number(la);
new_number(xa);
new_number(abs_x);
new_number(u);
new_number(r);

do{
do{
mp_number v;
new_number(v);
mp_next_random(mp,&v);
mp_number_substract(&v,((math_data*)mp->math)->fraction_half_t);
mp_binary_number_take_fraction(mp,&xa,((math_data*)mp->math)->sqrt_8_e_k,v);
free_number(v);
mp_next_random(mp,&u);
mp_number_clone(&abs_x,xa);
mp_binary_abs(&abs_x);
}while(!mp_number_less(abs_x,u));
mp_binary_number_make_fraction(mp,&r,xa,u);
mp_number_clone(&xa,r);
mp_binary_m_log(mp,&la,u);
mp_set_binary_from_substraction(&la,((math_data*)mp->math)->twelve_ln_2_k,la);
mp_binary_ab_vs_cd(mp,&ab_vs_cd,((math_data*)mp->math)->one_k,la,xa,xa);
}while(mp_number_less(ab_vs_cd,((math_data*)mp->math)->zero_t));
mp_number_clone(ret,xa);
free_number(ab_vs_cd);
free_number(r);
free_number(abs_x);
free_number(la);
free_number(xa);
free_number(u);
}



/*:69*//*70:*/
#line 1809 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

static void mp_binary_ab_vs_cd(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
mpfr_t a,b,c,d;
mpfr_t ab,cd;

int cmp= 0;
(void)mp;
mpfr_inits2(precision_bits,a,b,c,d,ab,cd,(mpfr_ptr)0);
mpfr_set(a,(mpfr_ptr)a_orig.data.num,ROUNDING);
mpfr_set(b,(mpfr_ptr)b_orig.data.num,ROUNDING);
mpfr_set(c,(mpfr_ptr)c_orig.data.num,ROUNDING);
mpfr_set(d,(mpfr_ptr)d_orig.data.num,ROUNDING);

mpfr_mul(ab,a,b,ROUNDING);
mpfr_mul(cd,c,d,ROUNDING);

mpfr_set(ret->data.num,zero,ROUNDING);
cmp= mpfr_cmp(ab,cd);
if(cmp){
if(cmp> 0)
mpfr_set(ret->data.num,one,ROUNDING);
else
mpfr_set(ret->data.num,minusone,ROUNDING);
}
mp_check_mpfr_t(mp,ret->data.num);
mpfr_clears(a,b,c,d,ab,cd,(mpfr_ptr)0);
return;
}

/*:70*/
