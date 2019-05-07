/*1:*/
#line 21 "../../../source/texk/web2c/mplibdir/mpmath.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "mpmath.h"
#define coef_bound 04525252525
#define fraction_threshold 2685
#define half_fraction_threshold 1342
#define scaled_threshold 8
#define half_scaled_threshold 4
#define near_zero_angle 26844
#define p_over_v_threshold 0x80000
#define equation_threshold 64
#define tfm_warn_threshold 4096 \
 \

#define unity 0x10000
#define two (2*unity)
#define three (3*unity)
#define half_unit (unity/2)
#define three_quarter_unit (3*(unity/4) )  \

#define EL_GORDO 0x7fffffff
#define one_third_EL_GORDO 05252525252 \

#define halfp(A) (integer) ((unsigned) (A) >>1)  \

#define TWEXP31 2147483648.0
#define TWEXP28 268435456.0
#define TWEXP16 65536.0
#define TWEXP_16 (1.0/65536.0)
#define TWEXP_28 (1.0/268435456.0)  \
 \

#define set_cur_cmd(A) mp->cur_mod_->type= (A)
#define set_cur_mod(A) mp->cur_mod_->data.n.data.val= (A)  \

#define fraction_half 01000000000
#define fraction_one 02000000000
#define fraction_two 04000000000
#define fraction_three 06000000000
#define fraction_four 010000000000 \

#define no_crossing {ret->data.val= fraction_one+1;return;}
#define one_crossing {ret->data.val= fraction_one;return;}
#define zero_crossing {ret->data.val= 0;return;} \

#define two_to_the(A) (1<<(unsigned) (A) )  \

#define negate_x 1
#define negate_y 2
#define switch_x_and_y 4
#define first_octant 1
#define second_octant (first_octant+switch_x_and_y)
#define third_octant (first_octant+switch_x_and_y+negate_x)
#define fourth_octant (first_octant+negate_x)
#define fifth_octant (first_octant+negate_x+negate_y)
#define sixth_octant (first_octant+switch_x_and_y+negate_x+negate_y)
#define seventh_octant (first_octant+switch_x_and_y+negate_y)
#define eighth_octant (first_octant+negate_y)  \

#define forty_five_deg 0264000000
#define ninety_deg 0550000000
#define one_eighty_deg 01320000000
#define three_sixty_deg 02640000000 \

#define odd(A) (abs(A) %2==1)  \


#line 28 "../../../source/texk/web2c/mplibdir/mpmath.w"


/*:1*//*2:*/
#line 30 "../../../source/texk/web2c/mplibdir/mpmath.w"

/*5:*/
#line 45 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_scan_fractional_token(MP mp,int n);
static void mp_scan_numeric_token(MP mp,int n);
static void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);
static void mp_crossing_point(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c);
static void mp_number_modulo(mp_number*a,mp_number b);
static void mp_print_number(MP mp,mp_number n);
static char*mp_number_tostring(MP mp,mp_number n);
static void mp_slow_add(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig);
static void mp_square_rt(MP mp,mp_number*ret,mp_number x_orig);
static void mp_n_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin);
static void mp_init_randoms(MP mp,int seed);
static void mp_number_angle_to_scaled(mp_number*A);
static void mp_number_fraction_to_scaled(mp_number*A);
static void mp_number_scaled_to_fraction(mp_number*A);
static void mp_number_scaled_to_angle(mp_number*A);
static void mp_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig);
static void mp_m_norm_rand(MP mp,mp_number*ret);
static void mp_m_exp(MP mp,mp_number*ret,mp_number x_orig);
static void mp_m_log(MP mp,mp_number*ret,mp_number x_orig);
static void mp_pyth_sub(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_n_arg(MP mp,mp_number*ret,mp_number x,mp_number y);
static void mp_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,mp_number cf,mp_number t);
static void mp_set_number_from_int(mp_number*A,int B);
static void mp_set_number_from_boolean(mp_number*A,int B);
static void mp_set_number_from_scaled(mp_number*A,int B);
static void mp_set_number_from_boolean(mp_number*A,int B);
static void mp_set_number_from_addition(mp_number*A,mp_number B,mp_number C);
static void mp_set_number_from_substraction(mp_number*A,mp_number B,mp_number C);
static void mp_set_number_from_div(mp_number*A,mp_number B,mp_number C);
static void mp_set_number_from_mul(mp_number*A,mp_number B,mp_number C);
static void mp_set_number_from_int_div(mp_number*A,mp_number B,int C);
static void mp_set_number_from_int_mul(mp_number*A,mp_number B,int C);
static void mp_set_number_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C);
static void mp_number_negate(mp_number*A);
static void mp_number_add(mp_number*A,mp_number B);
static void mp_number_substract(mp_number*A,mp_number B);
static void mp_number_half(mp_number*A);
static void mp_number_halfp(mp_number*A);
static void mp_number_double(mp_number*A);
static void mp_number_add_scaled(mp_number*A,int B);
static void mp_number_multiply_int(mp_number*A,int B);
static void mp_number_divide_int(mp_number*A,int B);
static void mp_number_abs(mp_number*A);
static void mp_number_clone(mp_number*A,mp_number B);
static void mp_number_swap(mp_number*A,mp_number*B);
static int mp_round_unscaled(mp_number x_orig);
static int mp_number_to_scaled(mp_number A);
static int mp_number_to_boolean(mp_number A);
static int mp_number_to_int(mp_number A);
static int mp_number_odd(mp_number A);
static int mp_number_equal(mp_number A,mp_number B);
static int mp_number_greater(mp_number A,mp_number B);
static int mp_number_less(mp_number A,mp_number B);
static int mp_number_nonequalabs(mp_number A,mp_number B);
static void mp_number_floor(mp_number*i);
static void mp_fraction_to_round_scaled(mp_number*x);
static void mp_number_make_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_number_make_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_number_take_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_number_take_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_new_number(MP mp,mp_number*n,mp_number_type t);
static void mp_free_number(MP mp,mp_number*n);
static void mp_free_scaled_math(MP mp);
static void mp_scaled_set_precision(MP mp);

/*:5*//*15:*/
#line 511 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_print_scaled(MP mp,int s);
static char*mp_string_scaled(MP mp,int s);

/*:15*//*22:*/
#line 734 "../../../source/texk/web2c/mplibdir/mpmath.w"

static integer mp_take_scaled(MP mp,integer q,int f);

/*:22*//*26:*/
#line 819 "../../../source/texk/web2c/mplibdir/mpmath.w"

static int mp_round_decimals(MP mp,unsigned char*b,quarterword k);

/*:26*//*28:*/
#line 842 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_wrapup_numeric_token(MP mp,int n,int f);

/*:28*//*50:*/
#line 1378 "../../../source/texk/web2c/mplibdir/mpmath.w"

static const integer spec_log[29]= {0,
93032640,38612034,17922280,8662214,4261238,2113709,
1052693,525315,262400,131136,65552,32772,16385,
8192,4096,2048,1024,512,256,128,64,32,16,8,4,2,1,1
};


/*:50*//*56:*/
#line 1514 "../../../source/texk/web2c/mplibdir/mpmath.w"

static const int spec_atan[27]= {0,27855475,14718068,7471121,3750058,
1876857,938658,469357,234682,117342,58671,29335,14668,7334,3667,
1833,917,458,229,115,57,29,14,7,4,2,1
};


/*:56*/
#line 31 "../../../source/texk/web2c/mplibdir/mpmath.w"
;

/*:2*//*7:*/
#line 132 "../../../source/texk/web2c/mplibdir/mpmath.w"

void*mp_initialize_scaled_math(MP mp){
math_data*math= (math_data*)mp_xmalloc(mp,1,sizeof(math_data));

math->allocate= mp_new_number;
math->free= mp_free_number;
mp_new_number(mp,&math->precision_default,mp_scaled_type);
math->precision_default.data.val= unity*10;
mp_new_number(mp,&math->precision_max,mp_scaled_type);
math->precision_max.data.val= unity*10;
mp_new_number(mp,&math->precision_min,mp_scaled_type);
math->precision_min.data.val= unity*10;

mp_new_number(mp,&math->epsilon_t,mp_scaled_type);
math->epsilon_t.data.val= 1;
mp_new_number(mp,&math->inf_t,mp_scaled_type);
math->inf_t.data.val= EL_GORDO;
mp_new_number(mp,&math->warning_limit_t,mp_scaled_type);
math->warning_limit_t.data.val= fraction_one;
mp_new_number(mp,&math->one_third_inf_t,mp_scaled_type);
math->one_third_inf_t.data.val= one_third_EL_GORDO;
mp_new_number(mp,&math->unity_t,mp_scaled_type);
math->unity_t.data.val= unity;
mp_new_number(mp,&math->two_t,mp_scaled_type);
math->two_t.data.val= two;
mp_new_number(mp,&math->three_t,mp_scaled_type);
math->three_t.data.val= three;
mp_new_number(mp,&math->half_unit_t,mp_scaled_type);
math->half_unit_t.data.val= half_unit;
mp_new_number(mp,&math->three_quarter_unit_t,mp_scaled_type);
math->three_quarter_unit_t.data.val= three_quarter_unit;
mp_new_number(mp,&math->zero_t,mp_scaled_type);

mp_new_number(mp,&math->arc_tol_k,mp_fraction_type);
math->arc_tol_k.data.val= (unity/4096);
mp_new_number(mp,&math->fraction_one_t,mp_fraction_type);
math->fraction_one_t.data.val= fraction_one;
mp_new_number(mp,&math->fraction_half_t,mp_fraction_type);
math->fraction_half_t.data.val= fraction_half;
mp_new_number(mp,&math->fraction_three_t,mp_fraction_type);
math->fraction_three_t.data.val= fraction_three;
mp_new_number(mp,&math->fraction_four_t,mp_fraction_type);
math->fraction_four_t.data.val= fraction_four;

mp_new_number(mp,&math->three_sixty_deg_t,mp_angle_type);
math->three_sixty_deg_t.data.val= three_sixty_deg;
mp_new_number(mp,&math->one_eighty_deg_t,mp_angle_type);
math->one_eighty_deg_t.data.val= one_eighty_deg;

mp_new_number(mp,&math->one_k,mp_scaled_type);
math->one_k.data.val= 1024;
mp_new_number(mp,&math->sqrt_8_e_k,mp_scaled_type);
math->sqrt_8_e_k.data.val= 112429;
mp_new_number(mp,&math->twelve_ln_2_k,mp_fraction_type);
math->twelve_ln_2_k.data.val= 139548960;
mp_new_number(mp,&math->coef_bound_k,mp_fraction_type);
math->coef_bound_k.data.val= coef_bound;
mp_new_number(mp,&math->coef_bound_minus_1,mp_fraction_type);
math->coef_bound_minus_1.data.val= coef_bound-1;
mp_new_number(mp,&math->twelvebits_3,mp_scaled_type);
math->twelvebits_3.data.val= 1365;
mp_new_number(mp,&math->twentysixbits_sqrt2_t,mp_fraction_type);
math->twentysixbits_sqrt2_t.data.val= 94906266;
mp_new_number(mp,&math->twentyeightbits_d_t,mp_fraction_type);
math->twentyeightbits_d_t.data.val= 35596755;
mp_new_number(mp,&math->twentysevenbits_sqrt2_d_t,mp_fraction_type);
math->twentysevenbits_sqrt2_d_t.data.val= 25170707;

mp_new_number(mp,&math->fraction_threshold_t,mp_fraction_type);
math->fraction_threshold_t.data.val= fraction_threshold;
mp_new_number(mp,&math->half_fraction_threshold_t,mp_fraction_type);
math->half_fraction_threshold_t.data.val= half_fraction_threshold;
mp_new_number(mp,&math->scaled_threshold_t,mp_scaled_type);
math->scaled_threshold_t.data.val= scaled_threshold;
mp_new_number(mp,&math->half_scaled_threshold_t,mp_scaled_type);
math->half_scaled_threshold_t.data.val= half_scaled_threshold;
mp_new_number(mp,&math->near_zero_angle_t,mp_angle_type);
math->near_zero_angle_t.data.val= near_zero_angle;
mp_new_number(mp,&math->p_over_v_threshold_t,mp_fraction_type);
math->p_over_v_threshold_t.data.val= p_over_v_threshold;
mp_new_number(mp,&math->equation_threshold_t,mp_scaled_type);
math->equation_threshold_t.data.val= equation_threshold;
mp_new_number(mp,&math->tfm_warn_threshold_t,mp_scaled_type);
math->tfm_warn_threshold_t.data.val= tfm_warn_threshold;

math->from_int= mp_set_number_from_int;
math->from_boolean= mp_set_number_from_boolean;
math->from_scaled= mp_set_number_from_scaled;
math->from_double= mp_set_number_from_double;
math->from_addition= mp_set_number_from_addition;
math->from_substraction= mp_set_number_from_substraction;
math->from_oftheway= mp_set_number_from_of_the_way;
math->from_div= mp_set_number_from_div;
math->from_mul= mp_set_number_from_mul;
math->from_int_div= mp_set_number_from_int_div;
math->from_int_mul= mp_set_number_from_int_mul;
math->negate= mp_number_negate;
math->add= mp_number_add;
math->substract= mp_number_substract;
math->half= mp_number_half;
math->halfp= mp_number_halfp;
math->do_double= mp_number_double;
math->abs= mp_number_abs;
math->clone= mp_number_clone;
math->swap= mp_number_swap;
math->add_scaled= mp_number_add_scaled;
math->multiply_int= mp_number_multiply_int;
math->divide_int= mp_number_divide_int;
math->to_int= mp_number_to_int;
math->to_boolean= mp_number_to_boolean;
math->to_scaled= mp_number_to_scaled;
math->to_double= mp_number_to_double;
math->odd= mp_number_odd;
math->equal= mp_number_equal;
math->less= mp_number_less;
math->greater= mp_number_greater;
math->nonequalabs= mp_number_nonequalabs;
math->round_unscaled= mp_round_unscaled;
math->floor_scaled= mp_number_floor;
math->fraction_to_round_scaled= mp_fraction_to_round_scaled;
math->make_scaled= mp_number_make_scaled;
math->make_fraction= mp_number_make_fraction;
math->take_fraction= mp_number_take_fraction;
math->take_scaled= mp_number_take_scaled;
math->velocity= mp_velocity;
math->n_arg= mp_n_arg;
math->m_log= mp_m_log;
math->m_exp= mp_m_exp;
math->m_unif_rand= mp_m_unif_rand;
math->m_norm_rand= mp_m_norm_rand;
math->pyth_add= mp_pyth_add;
math->pyth_sub= mp_pyth_sub;
math->fraction_to_scaled= mp_number_fraction_to_scaled;
math->scaled_to_fraction= mp_number_scaled_to_fraction;
math->scaled_to_angle= mp_number_scaled_to_angle;
math->angle_to_scaled= mp_number_angle_to_scaled;
math->init_randoms= mp_init_randoms;
math->sin_cos= mp_n_sin_cos;
math->slow_add= mp_slow_add;
math->sqrt= mp_square_rt;
math->print= mp_print_number;
math->tostring= mp_number_tostring;
math->modulo= mp_number_modulo;
math->ab_vs_cd= mp_ab_vs_cd;
math->crossing_point= mp_crossing_point;
math->scan_numeric= mp_scan_numeric_token;
math->scan_fractional= mp_scan_fractional_token;
math->free_math= mp_free_scaled_math;
math->set_precision= mp_scaled_set_precision;
return(void*)math;
}

void mp_scaled_set_precision(MP mp){
}

void mp_free_scaled_math(MP mp){
free_number(((math_data*)mp->math)->epsilon_t);
free_number(((math_data*)mp->math)->inf_t);
free_number(((math_data*)mp->math)->arc_tol_k);
free_number(((math_data*)mp->math)->three_sixty_deg_t);
free_number(((math_data*)mp->math)->one_eighty_deg_t);
free_number(((math_data*)mp->math)->fraction_one_t);
free_number(((math_data*)mp->math)->fraction_half_t);
free_number(((math_data*)mp->math)->fraction_three_t);
free_number(((math_data*)mp->math)->fraction_four_t);
free_number(((math_data*)mp->math)->zero_t);
free_number(((math_data*)mp->math)->half_unit_t);
free_number(((math_data*)mp->math)->three_quarter_unit_t);
free_number(((math_data*)mp->math)->unity_t);
free_number(((math_data*)mp->math)->two_t);
free_number(((math_data*)mp->math)->three_t);
free_number(((math_data*)mp->math)->one_third_inf_t);
free_number(((math_data*)mp->math)->warning_limit_t);
free_number(((math_data*)mp->math)->one_k);
free_number(((math_data*)mp->math)->sqrt_8_e_k);
free_number(((math_data*)mp->math)->twelve_ln_2_k);
free_number(((math_data*)mp->math)->coef_bound_k);
free_number(((math_data*)mp->math)->coef_bound_minus_1);
free_number(((math_data*)mp->math)->twelvebits_3);
free_number(((math_data*)mp->math)->twentysixbits_sqrt2_t);
free_number(((math_data*)mp->math)->twentyeightbits_d_t);
free_number(((math_data*)mp->math)->twentysevenbits_sqrt2_d_t);
free_number(((math_data*)mp->math)->fraction_threshold_t);
free_number(((math_data*)mp->math)->half_fraction_threshold_t);
free_number(((math_data*)mp->math)->scaled_threshold_t);
free_number(((math_data*)mp->math)->half_scaled_threshold_t);
free_number(((math_data*)mp->math)->near_zero_angle_t);
free_number(((math_data*)mp->math)->p_over_v_threshold_t);
free_number(((math_data*)mp->math)->equation_threshold_t);
free_number(((math_data*)mp->math)->tfm_warn_threshold_t);
free(mp->math);
}

/*:7*//*9:*/
#line 327 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_new_number(MP mp,mp_number*n,mp_number_type t){
(void)mp;
n->data.val= 0;
n->type= t;
}

/*:9*//*10:*/
#line 335 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_free_number(MP mp,mp_number*n){
(void)mp;
n->type= mp_nan_type;
}

/*:10*//*11:*/
#line 343 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_set_number_from_int(mp_number*A,int B){
A->data.val= B;
}
void mp_set_number_from_boolean(mp_number*A,int B){
A->data.val= B;
}
void mp_set_number_from_scaled(mp_number*A,int B){
A->data.val= B;
}
void mp_set_number_from_double(mp_number*A,double B){
A->data.val= (int)(B*65536.0);
}
void mp_set_number_from_addition(mp_number*A,mp_number B,mp_number C){
A->data.val= B.data.val+C.data.val;
}
void mp_set_number_from_substraction(mp_number*A,mp_number B,mp_number C){
A->data.val= B.data.val-C.data.val;
}
void mp_set_number_from_div(mp_number*A,mp_number B,mp_number C){
A->data.val= B.data.val/C.data.val;
}
void mp_set_number_from_mul(mp_number*A,mp_number B,mp_number C){
A->data.val= B.data.val*C.data.val;
}
void mp_set_number_from_int_div(mp_number*A,mp_number B,int C){
A->data.val= B.data.val/C;
}
void mp_set_number_from_int_mul(mp_number*A,mp_number B,int C){
A->data.val= B.data.val*C;
}
void mp_set_number_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C){
A->data.val= B.data.val-mp_take_fraction(mp,(B.data.val-C.data.val),t.data.val);
}
void mp_number_negate(mp_number*A){
A->data.val= -A->data.val;
}
void mp_number_add(mp_number*A,mp_number B){
A->data.val= A->data.val+B.data.val;
}
void mp_number_substract(mp_number*A,mp_number B){
A->data.val= A->data.val-B.data.val;
}
void mp_number_half(mp_number*A){
A->data.val= A->data.val/2;
}
void mp_number_halfp(mp_number*A){
A->data.val= (A->data.val>>1);
}
void mp_number_double(mp_number*A){
A->data.val= A->data.val+A->data.val;
}
void mp_number_add_scaled(mp_number*A,int B){
A->data.val= A->data.val+B;
}
void mp_number_multiply_int(mp_number*A,int B){
A->data.val= B*A->data.val;
}
void mp_number_divide_int(mp_number*A,int B){
A->data.val= A->data.val/B;
}
void mp_number_abs(mp_number*A){
A->data.val= abs(A->data.val);
}
void mp_number_clone(mp_number*A,mp_number B){
A->data.val= B.data.val;
}
void mp_number_swap(mp_number*A,mp_number*B){
int swap_tmp= A->data.val;
A->data.val= B->data.val;
B->data.val= swap_tmp;
}
void mp_number_fraction_to_scaled(mp_number*A){
A->type= mp_scaled_type;
A->data.val= A->data.val/4096;
}
void mp_number_angle_to_scaled(mp_number*A){
A->type= mp_scaled_type;
if(A->data.val>=0){
A->data.val= (A->data.val+8)/16;
}else{
A->data.val= -((-A->data.val+8)/16);
}
}
void mp_number_scaled_to_fraction(mp_number*A){
A->type= mp_fraction_type;
A->data.val= A->data.val*4096;
}
void mp_number_scaled_to_angle(mp_number*A){
A->type= mp_angle_type;
A->data.val= A->data.val*16;
}


/*:11*//*12:*/
#line 439 "../../../source/texk/web2c/mplibdir/mpmath.w"

int mp_number_to_int(mp_number A){
return A.data.val;
}
int mp_number_to_scaled(mp_number A){
return A.data.val;
}
int mp_number_to_boolean(mp_number A){
return A.data.val;
}
double mp_number_to_double(mp_number A){
return(A.data.val/65536.0);
}
int mp_number_odd(mp_number A){
return odd(A.data.val);
}
int mp_number_equal(mp_number A,mp_number B){
return(A.data.val==B.data.val);
}
int mp_number_greater(mp_number A,mp_number B){
return(A.data.val> B.data.val);
}
int mp_number_less(mp_number A,mp_number B){
return(A.data.val<B.data.val);
}
int mp_number_nonequalabs(mp_number A,mp_number B){
return(!(abs(A.data.val)==abs(B.data.val)));
}

/*:12*//*16:*/
#line 515 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_print_scaled(MP mp,int s){
int delta;
if(s<0){
mp_print_char(mp,xord('-'));
s= -s;
}
mp_print_int(mp,s/unity);
s= 10*(s%unity)+5;
if(s!=5){
delta= 10;
mp_print_char(mp,xord('.'));
do{
if(delta> unity)
s= s+0100000-(delta/2);
mp_print_char(mp,xord('0'+(s/unity)));
s= 10*(s%unity);
delta= delta*10;
}while(s> delta);
}
}

static char*mp_string_scaled(MP mp,int s){
static char scaled_string[32];
int delta;
int i= 0;
if(s<0){
scaled_string[i++]= xord('-');
s= -s;
}

mp_snprintf((scaled_string+i),12,"%d",(int)(s/unity));
while(*(scaled_string+i))i++;

s= 10*(s%unity)+5;
if(s!=5){
delta= 10;
scaled_string[i++]= xord('.');
do{
if(delta> unity)
s= s+0100000-(delta/2);
scaled_string[i++]= xord('0'+(s/unity));
s= 10*(s%unity);
delta= delta*10;
}while(s> delta);
}
scaled_string[i]= '\0';
return scaled_string;
}

/*:16*//*17:*/
#line 569 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_slow_add(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig){
integer x,y;
x= x_orig.data.val;
y= y_orig.data.val;
if(x>=0){
if(y<=EL_GORDO-x){
ret->data.val= x+y;
}else{
mp->arith_error= true;
ret->data.val= EL_GORDO;
}
}else if(-y<=EL_GORDO+x){
ret->data.val= x+y;
}else{
mp->arith_error= true;
ret->data.val= -EL_GORDO;
}
}

/*:17*//*19:*/
#line 636 "../../../source/texk/web2c/mplibdir/mpmath.w"

static integer mp_make_fraction(MP mp,integer p,integer q){
integer i;
if(q==0)
mp_confusion(mp,"/");

{
register double d;
d= TWEXP28*(double)p/(double)q;
if((p^q)>=0){
d+= 0.5;
if(d>=TWEXP31){
mp->arith_error= true;
i= EL_GORDO;
goto RETURN;
}
i= (integer)d;
if(d==(double)i&&(((q> 0?-q:q)&077777)
*(((i&037777)<<1)-1)&04000)!=0)
--i;
}else{
d-= 0.5;
if(d<=-TWEXP31){
mp->arith_error= true;
i= -EL_GORDO;
goto RETURN;
}
i= (integer)d;
if(d==(double)i&&(((q> 0?q:-q)&077777)
*(((i&037777)<<1)+1)&04000)!=0)
++i;
}
}
RETURN:
return i;
}
void mp_number_make_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
ret->data.val= mp_make_fraction(mp,p.data.val,q.data.val);
}


/*:19*//*21:*/
#line 691 "../../../source/texk/web2c/mplibdir/mpmath.w"

integer mp_take_fraction(MP mp,integer p,int q){
register double d;
register integer i;
d= (double)p*(double)q*TWEXP_28;
if((p^q)>=0){
d+= 0.5;
if(d>=TWEXP31){
if(d!=TWEXP31||(((p&077777)*(q&077777))&040000)==0)
mp->arith_error= true;
return EL_GORDO;
}
i= (integer)d;
if(d==(double)i&&(((p&077777)*(q&077777))&040000)!=0)
--i;
}else{
d-= 0.5;
if(d<=-TWEXP31){
if(d!=-TWEXP31||((-(p&077777)*(q&077777))&040000)==0)
mp->arith_error= true;
return-EL_GORDO;
}
i= (integer)d;
if(d==(double)i&&((-(p&077777)*(q&077777))&040000)!=0)
++i;
}
return i;
}
void mp_number_take_fraction(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
ret->data.val= mp_take_fraction(mp,p_orig.data.val,q_orig.data.val);
}


/*:21*//*23:*/
#line 737 "../../../source/texk/web2c/mplibdir/mpmath.w"

static integer mp_take_scaled(MP mp,integer p,int q){
register double d;
register integer i;
d= (double)p*(double)q*TWEXP_16;
if((p^q)>=0){
d+= 0.5;
if(d>=TWEXP31){
if(d!=TWEXP31||(((p&077777)*(q&077777))&040000)==0)
mp->arith_error= true;
return EL_GORDO;
}
i= (integer)d;
if(d==(double)i&&(((p&077777)*(q&077777))&040000)!=0)
--i;
}else{
d-= 0.5;
if(d<=-TWEXP31){
if(d!=-TWEXP31||((-(p&077777)*(q&077777))&040000)==0)
mp->arith_error= true;
return-EL_GORDO;
}
i= (integer)d;
if(d==(double)i&&((-(p&077777)*(q&077777))&040000)!=0)
++i;
}
return i;
}
void mp_number_take_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
ret->data.val= mp_take_scaled(mp,p_orig.data.val,q_orig.data.val);
}


/*:23*//*25:*/
#line 780 "../../../source/texk/web2c/mplibdir/mpmath.w"

int mp_make_scaled(MP mp,integer p,integer q){
register integer i;
if(q==0)
mp_confusion(mp,"/");
{
register double d;
d= TWEXP16*(double)p/(double)q;
if((p^q)>=0){
d+= 0.5;
if(d>=TWEXP31){
mp->arith_error= true;
return EL_GORDO;
}
i= (integer)d;
if(d==(double)i&&(((q> 0?-q:q)&077777)
*(((i&037777)<<1)-1)&04000)!=0)
--i;
}else{
d-= 0.5;
if(d<=-TWEXP31){
mp->arith_error= true;
return-EL_GORDO;
}
i= (integer)d;
if(d==(double)i&&(((q> 0?q:-q)&077777)
*(((i&037777)<<1)+1)&04000)!=0)
++i;
}
}
return i;
}
void mp_number_make_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
ret->data.val= mp_make_scaled(mp,p_orig.data.val,q_orig.data.val);
}

/*:25*//*27:*/
#line 822 "../../../source/texk/web2c/mplibdir/mpmath.w"

static int mp_round_decimals(MP mp,unsigned char*b,quarterword k){

unsigned a= 0;
int l= 0;
(void)mp;
for(l= k-1;l>=0;l--){
if(l<16)
a= (a+(unsigned)(*(b+l)-'0')*two)/10;
}
return(int)halfp(a+1);
}

/*:27*//*29:*/
#line 845 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_wrapup_numeric_token(MP mp,int n,int f){
int mod;
if(n<32768){
mod= (n*unity+f);
set_cur_mod(mod);
if(mod>=fraction_one){
if(internal_value(mp_warning_check).data.val> 0&&
(mp->scanner_status!=tex_flushing)){
char msg[256];
const char*hlp[]= {"It is at least 4096. Continue and I'll try to cope",
"with that big value; but it might be dangerous.",
"(Set warningcheck:=0 to suppress this message.)",
NULL};
mp_snprintf(msg,256,"Number is too large (%s)",mp_string_scaled(mp,mod));
;
mp_error(mp,msg,hlp,true);
}
}
}else if(mp->scanner_status!=tex_flushing){
const char*hlp[]= {"I can\'t handle numbers bigger than 32767.99998;",
"so I've changed your constant to that maximum amount.",
NULL};
mp_error(mp,"Enormous number has been reduced",hlp,false);
;
set_cur_mod(EL_GORDO);
}
set_cur_cmd((mp_variable_type)mp_numeric_token);
}

/*:29*//*30:*/
#line 875 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_scan_fractional_token(MP mp,int n){
int f;
int k= 0;
do{
k++;
mp->cur_input.loc_field++;
}while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class);
f= mp_round_decimals(mp,(unsigned char*)(mp->buffer+mp->cur_input.loc_field-k),(quarterword)k);
if(f==unity){
n++;
f= 0;
}
mp_wrapup_numeric_token(mp,n,f);
}


/*:30*//*31:*/
#line 892 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_scan_numeric_token(MP mp,int n){
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
if(n<32768)
n= 10*n+mp->buffer[mp->cur_input.loc_field]-'0';
mp->cur_input.loc_field++;
}
if(!(mp->buffer[mp->cur_input.loc_field]=='.'&&
mp->char_class[mp->buffer[mp->cur_input.loc_field+1]]==digit_class)){
mp_wrapup_numeric_token(mp,n,0);
}else{
mp->cur_input.loc_field++;
mp_scan_fractional_token(mp,n);
}
}

/*:31*//*33:*/
#line 943 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,
mp_number cf,mp_number t){
integer acc,num,denom;
acc= mp_take_fraction(mp,st.data.val-(sf.data.val/16),sf.data.val-(st.data.val/16));
acc= mp_take_fraction(mp,acc,ct.data.val-cf.data.val);
num= fraction_two+mp_take_fraction(mp,acc,379625062);

denom=
fraction_three+mp_take_fraction(mp,ct.data.val,
497706707)+mp_take_fraction(mp,cf.data.val,
307599661);


if(t.data.val!=unity)
num= mp_make_scaled(mp,num,t.data.val);
if(num/4>=denom){
ret->data.val= fraction_four;
}else{
ret->data.val= mp_make_fraction(mp,num,denom);
}

}


/*:33*//*34:*/
#line 973 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
integer q,r;
integer a,b,c,d;
(void)mp;
a= a_orig.data.val;
b= b_orig.data.val;
c= c_orig.data.val;
d= d_orig.data.val;
/*35:*/
#line 1008 "../../../source/texk/web2c/mplibdir/mpmath.w"

if(a<0){
a= -a;
b= -b;
}
if(c<0){
c= -c;
d= -d;
}
if(d<=0){
if(b>=0){
if((a==0||b==0)&&(c==0||d==0))
ret->data.val= 0;
else
ret->data.val= 1;
return;
}
if(d==0){
ret->data.val= (a==0?0:-1);
return;
}
q= a;
a= c;
c= q;
q= -b;
b= -d;
d= q;
}else if(b<=0){
if(b<0&&a> 0){
ret->data.val= -1;
return;
}
ret->data.val= (c==0?0:-1);
return;
}

/*:35*/
#line 982 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
while(1){
q= a/d;
r= c/b;
if(q!=r){
ret->data.val= (q> r?1:-1);
return;
}
q= a%d;
r= c%b;
if(r==0){
ret->data.val= (q?1:0);
return;
}
if(q==0){
ret->data.val= -1;
return;
}
a= b;
b= q;
c= d;
d= r;
}
}


/*:34*//*36:*/
#line 1077 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_crossing_point(MP mp,mp_number*ret,mp_number aa,mp_number bb,mp_number cc){
integer a,b,c;
integer d;
integer x,xx,x0,x1,x2;
a= aa.data.val;
b= bb.data.val;
c= cc.data.val;
if(a<0)
zero_crossing;
if(c>=0){
if(b>=0){
if(c> 0){
no_crossing;
}else if((a==0)&&(b==0)){
no_crossing;
}else{
one_crossing;
}
}
if(a==0)
zero_crossing;
}else if(a==0){
if(b<=0)
zero_crossing;
}


d= 1;
x0= a;
x1= a-b;
x2= b-c;
do{
x= (x1+x2)/2;
if(x1-x0> x0){
x2= x;
x0+= x0;
d+= d;
}else{
xx= x1+x-x0;
if(xx> x0){
x2= x;
x0+= x0;
d+= d;
}else{
x0= x0-xx;
if(x<=x0){
if(x+x2<=x0)
no_crossing;
}
x1= x;
d= d+d+1;
}
}
}while(d<fraction_one);
ret->data.val= (d-fraction_one);
}


/*:36*//*38:*/
#line 1141 "../../../source/texk/web2c/mplibdir/mpmath.w"

int mp_round_unscaled(mp_number x_orig){
int x= x_orig.data.val;
if(x>=32768){
return 1+((x-32768)/65536);
}else if(x>=-32768){
return 0;
}else{
return-(1+((-(x+1)-32768)/65536));
}
}

/*:38*//*39:*/
#line 1155 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_number_floor(mp_number*i){
i->data.val= i->data.val&-65536;
}

/*:39*//*40:*/
#line 1161 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_fraction_to_round_scaled(mp_number*x_orig){
int x= x_orig->data.val;
x_orig->type= mp_scaled_type;
x_orig->data.val= (x>=2048?1+((x-2048)/4096):(x>=-2048?0:-(1+((-(x+1)-2048)/4096))));
}



/*:40*//*42:*/
#line 1182 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_square_rt(MP mp,mp_number*ret,mp_number x_orig){
integer x;
quarterword k;
integer y;
integer q;
x= x_orig.data.val;
if(x<=0){
/*43:*/
#line 1213 "../../../source/texk/web2c/mplibdir/mpmath.w"

{
if(x<0){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_snprintf(msg,256,"Square root of %s has been replaced by 0",mp_string_scaled(mp,x));
;
mp_error(mp,msg,hlp,true);
}
ret->data.val= 0;
return;
}


/*:43*/
#line 1190 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}else{
k= 23;
q= 2;
while(x<fraction_two){
k--;
x= x+x+x+x;
}
if(x<fraction_four)
y= 0;
else{
x= x-fraction_four;
y= 1;
}
do{
/*44:*/
#line 1230 "../../../source/texk/web2c/mplibdir/mpmath.w"

x+= x;
y+= y;
if(x>=fraction_four){
x= x-fraction_four;
y++;
};
x+= x;
y= y+y-q;
q+= q;
if(x>=fraction_four){
x= x-fraction_four;
y++;
};
if(y> (int)q){
y-= q;
q+= 2;
}else if(y<=0){
q-= 2;
y+= q;
};
k--

/*:44*/
#line 1206 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}while(k!=0);
ret->data.val= (int)(halfp(q));
}
}


/*:42*//*45:*/
#line 1261 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_pyth_add(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
int a,b;
int r;
boolean big;
a= abs(a_orig.data.val);
b= abs(b_orig.data.val);
if(a<b){
r= b;
b= a;
a= r;
};
if(b> 0){
if(a<fraction_two){
big= false;
}else{
a= a/4;
b= b/4;
big= true;
};
/*46:*/
#line 1298 "../../../source/texk/web2c/mplibdir/mpmath.w"

while(1){
r= mp_make_fraction(mp,b,a);
r= mp_take_fraction(mp,r,r);
if(r==0)
break;
r= mp_make_fraction(mp,r,fraction_four+r);
a= a+mp_take_fraction(mp,a+a,r);
b= mp_take_fraction(mp,b,r);
}


/*:46*/
#line 1281 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
if(big){
if(a<fraction_two){
a= a+a+a+a;
}else{
mp->arith_error= true;
a= EL_GORDO;
};
}
}
ret->data.val= a;
}


/*:45*//*47:*/
#line 1313 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_pyth_sub(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
int a,b;
int r;
boolean big;
a= abs(a_orig.data.val);
b= abs(b_orig.data.val);
if(a<=b){
/*49:*/
#line 1350 "../../../source/texk/web2c/mplibdir/mpmath.w"

{
if(a<b){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*astr= strdup(mp_string_scaled(mp,a));
assert(astr);
mp_snprintf(msg,256,"Pythagorean subtraction %s+-+%s has been replaced by 0",astr,mp_string_scaled(mp,b));
free(astr);
;
mp_error(mp,msg,hlp,true);
}
a= 0;
}


/*:49*/
#line 1321 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}else{
if(a<fraction_four){
big= false;
}else{
a= (integer)halfp(a);
b= (integer)halfp(b);
big= true;
}
/*48:*/
#line 1338 "../../../source/texk/web2c/mplibdir/mpmath.w"

while(1){
r= mp_make_fraction(mp,b,a);
r= mp_take_fraction(mp,r,r);
if(r==0)
break;
r= mp_make_fraction(mp,r,fraction_four-r);
a= a-mp_take_fraction(mp,a+a,r);
b= mp_take_fraction(mp,b,r);
}


/*:48*/
#line 1330 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
if(big)
a*= 2;
}
ret->data.val= a;
}


/*:47*//*51:*/
#line 1400 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_m_log(MP mp,mp_number*ret,mp_number x_orig){
int x;
integer y,z;
integer k;
x= x_orig.data.val;
if(x<=0){
/*53:*/
#line 1439 "../../../source/texk/web2c/mplibdir/mpmath.w"

{
char msg[256];
const char*hlp[]= {
"Since I don't take logs of non-positive numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_snprintf(msg,256,"Logarithm of %s has been replaced by 0",mp_string_scaled(mp,x));
;
mp_error(mp,msg,hlp,true);
ret->data.val= 0;
}


/*:53*/
#line 1407 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}else{
y= 1302456956+4-100;
z= 27595+6553600;
while(x<fraction_four){
x= 2*x;
y-= 93032639;
z-= 48782;
}
y= y+(z/unity);
k= 2;
while(x> fraction_four+4){
/*52:*/
#line 1427 "../../../source/texk/web2c/mplibdir/mpmath.w"

{
z= ((x-1)/two_to_the(k))+1;
while(x<fraction_four+z){
z= halfp(z+1);
k++;
};
y+= spec_log[k];
x-= z;
}


/*:52*/
#line 1420 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}
ret->data.val= (y/8);
}
}


/*:51*//*54:*/
#line 1457 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_m_exp(MP mp,mp_number*ret,mp_number x_orig){
quarterword k;
integer y,z;
int x;
x= x_orig.data.val;
if(x> 174436200){

mp->arith_error= true;
ret->data.val= EL_GORDO;
}else if(x<-197694359){

ret->data.val= 0;
}else{
if(x<=0){
z= -8*x;
y= 04000000;
}else{
if(x<=127919879){
z= 1023359037-8*x;

}else{
z= 8*(174436200-x);
}
y= EL_GORDO;
}
/*55:*/
#line 1500 "../../../source/texk/web2c/mplibdir/mpmath.w"

k= 1;
while(z> 0){
while(z>=spec_log[k]){
z-= spec_log[k];
y= y-1-((y-two_to_the(k-1))/two_to_the(k));
}
k++;
}

/*:55*/
#line 1483 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
if(x<=127919879)
ret->data.val= ((y+8)/16);
else
ret->data.val= y;
}
}


/*:54*//*57:*/
#line 1544 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_n_arg(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig){
integer z;
integer t;
quarterword k;
int octant;
integer x,y;
x= x_orig.data.val;
y= y_orig.data.val;
if(x>=0){
octant= first_octant;
}else{
x= -x;
octant= first_octant+negate_x;
}
if(y<0){
y= -y;
octant= octant+negate_y;
}
if(x<y){
t= y;
y= x;
x= t;
octant= octant+switch_x_and_y;
}
if(x==0){
/*58:*/
#line 1579 "../../../source/texk/web2c/mplibdir/mpmath.w"

{
const char*hlp[]= {
"The `angle' between two identical points is undefined.",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_error(mp,"angle(0,0) is taken as zero",hlp,true);
;
ret->data.val= 0;
}


/*:58*/
#line 1570 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}else{
ret->type= mp_angle_type;
/*60:*/
#line 1624 "../../../source/texk/web2c/mplibdir/mpmath.w"

while(x>=fraction_two){
x= halfp(x);
y= halfp(y);
}
z= 0;
if(y> 0){
while(x<fraction_one){
x+= x;
y+= y;
};
/*61:*/
#line 1653 "../../../source/texk/web2c/mplibdir/mpmath.w"

k= 0;
do{
y+= y;
k++;
if(y> x){
z= z+spec_atan[k];
t= x;
x= x+(y/two_to_the(k+k));
y= y-t;
};
}while(k!=15);
do{
y+= y;
k++;
if(y> x){
z= z+spec_atan[k];
y= y-x;
};
}while(k!=26)

/*:61*/
#line 1635 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}

/*:60*/
#line 1573 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
/*59:*/
#line 1591 "../../../source/texk/web2c/mplibdir/mpmath.w"

switch(octant){
case first_octant:
ret->data.val= z;
break;
case second_octant:
ret->data.val= (ninety_deg-z);
break;
case third_octant:
ret->data.val= (ninety_deg+z);
break;
case fourth_octant:
ret->data.val= (one_eighty_deg-z);
break;
case fifth_octant:
ret->data.val= (z-one_eighty_deg);
break;
case sixth_octant:
ret->data.val= (-z-ninety_deg);
break;
case seventh_octant:
ret->data.val= (z-ninety_deg);
break;
case eighth_octant:
ret->data.val= (-z);
break;
}


/*:59*/
#line 1574 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
}
}


/*:57*//*64:*/
#line 1694 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_n_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin){
quarterword k;
int q;
integer x,y,t;
int z;
mp_number x_n,y_n,ret;
new_number(ret);
new_number(x_n);
new_number(y_n);
z= z_orig.data.val;
while(z<0)
z= z+three_sixty_deg;
z= z%three_sixty_deg;
q= z/forty_five_deg;
z= z%forty_five_deg;
x= fraction_one;
y= x;
if(!odd(q))
z= forty_five_deg-z;
/*66:*/
#line 1771 "../../../source/texk/web2c/mplibdir/mpmath.w"

k= 1;
while(z> 0){
if(z>=spec_atan[k]){
z= z-spec_atan[k];
t= x;
x= t+y/two_to_the(k);
y= y-t/two_to_the(k);
}
k++;
}
if(y<0)
y= 0


/*:66*/
#line 1714 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
/*65:*/
#line 1729 "../../../source/texk/web2c/mplibdir/mpmath.w"

switch(q){
case 0:
break;
case 1:
t= x;
x= y;
y= t;
break;
case 2:
t= x;
x= -y;
y= t;
break;
case 3:
x= -x;
break;
case 4:
x= -x;
y= -y;
break;
case 5:
t= x;
x= -y;
y= -t;
break;
case 6:
t= x;
x= y;
y= -t;
break;
case 7:
y= -y;
break;
}


/*:65*/
#line 1715 "../../../source/texk/web2c/mplibdir/mpmath.w"
;
x_n.data.val= x;
y_n.data.val= y;
mp_pyth_add(mp,&ret,x_n,y_n);
n_cos->data.val= mp_make_fraction(mp,x,ret.data.val);
n_sin->data.val= mp_make_fraction(mp,y,ret.data.val);
free_number(ret);
free_number(x_n);
free_number(y_n);
}


/*:64*//*67:*/
#line 1788 "../../../source/texk/web2c/mplibdir/mpmath.w"

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
mp->randoms[(i*21)%55].data.val= j;
}
mp_new_randoms(mp);
mp_new_randoms(mp);
mp_new_randoms(mp);
}


/*:67*//*68:*/
#line 1811 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_print_number(MP mp,mp_number n){
mp_print_scaled(mp,n.data.val);
}


/*:68*//*69:*/
#line 1817 "../../../source/texk/web2c/mplibdir/mpmath.w"

char*mp_number_tostring(MP mp,mp_number n){
return mp_string_scaled(mp,n.data.val);
}

/*:69*//*70:*/
#line 1822 "../../../source/texk/web2c/mplibdir/mpmath.w"

void mp_number_modulo(mp_number*a,mp_number b){
a->data.val= a->data.val%b.data.val;
}





/*:70*//*71:*/
#line 1833 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_next_random(MP mp,mp_number*ret){
if(mp->j_random==0)
mp_new_randoms(mp);
else
mp->j_random= mp->j_random-1;
mp_number_clone(ret,mp->randoms[mp->j_random]);
}


/*:71*//*72:*/
#line 1850 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig){
mp_number y;
mp_number x,abs_x;
mp_number u;
new_fraction(y);
new_number(x);
new_number(abs_x);
new_number(u);
mp_number_clone(&x,x_orig);
mp_number_clone(&abs_x,x);
mp_number_abs(&abs_x);
mp_next_random(mp,&u);

mp_number_take_fraction(mp,&y,abs_x,u);
free_number(u);
if(mp_number_equal(y,abs_x)){

mp_number_clone(ret,((math_data*)mp->math)->zero_t);
}else if(mp_number_greater(x,((math_data*)mp->math)->zero_t)){
mp_number_clone(ret,y);
}else{
mp_number_clone(ret,y);
mp_number_negate(ret);
}
free_number(abs_x);
free_number(x);
free_number(y);
}




/*:72*//*73:*/
#line 1887 "../../../source/texk/web2c/mplibdir/mpmath.w"

static void mp_m_norm_rand(MP mp,mp_number*ret){
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
mp_number_take_fraction(mp,&xa,((math_data*)mp->math)->sqrt_8_e_k,v);
free_number(v);
mp_next_random(mp,&u);
mp_number_clone(&abs_x,xa);
mp_number_abs(&abs_x);
}while(!mp_number_less(abs_x,u));
mp_number_make_fraction(mp,&r,xa,u);
mp_number_clone(&xa,r);
mp_m_log(mp,&la,u);
mp_set_number_from_substraction(&la,((math_data*)mp->math)->twelve_ln_2_k,la);
mp_ab_vs_cd(mp,&ab_vs_cd,((math_data*)mp->math)->one_k,la,xa,xa);
}while(mp_number_less(ab_vs_cd,((math_data*)mp->math)->zero_t));
mp_number_clone(ret,xa);
free_number(ab_vs_cd);
free_number(r);
free_number(abs_x);
free_number(la);
free_number(xa);
free_number(u);
}/*:73*/
