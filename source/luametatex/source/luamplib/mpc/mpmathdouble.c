/*1:*/
#line 22 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "mpmathdouble.h"
#define ROUND(a) floor((a)+0.5)
#define PI 3.1415926535897932384626433832795028841971
#define fraction_multiplier 4096.0
#define angle_multiplier 16.0 \

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
#define epsilon pow(2.0,-52.0)  \

#define unity 1.0
#define two 2.0
#define three 3.0
#define half_unit 0.5
#define three_quarter_unit 0.75 \

#define EL_GORDO (DBL_MAX/2.0-1.0)
#define one_third_EL_GORDO (EL_GORDO/3.0)  \

#define halfp(A) (integer) ((unsigned) (A) >>1)  \

#define set_cur_cmd(A) mp->cur_mod_->type= (A)
#define set_cur_mod(A) mp->cur_mod_->data.n.data.dval= (A)  \

#define fraction_half (0.5*fraction_multiplier)
#define fraction_one (1.0*fraction_multiplier)
#define fraction_two (2.0*fraction_multiplier)
#define fraction_three (3.0*fraction_multiplier)
#define fraction_four (4.0*fraction_multiplier)  \

#define no_crossing {ret->data.dval= fraction_one+1;goto RETURN;}
#define one_crossing {ret->data.dval= fraction_one;goto RETURN;}
#define zero_crossing {ret->data.dval= 0;goto RETURN;} \

#define two_to_the(A) (1<<(unsigned) (A) )  \

#define one_eighty_deg (180.0*angle_multiplier)
#define three_sixty_deg (360.0*angle_multiplier)  \

#define odd(A) (abs(A) %2==1)  \


#line 30 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"


/*:1*//*2:*/
#line 32 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

/*5:*/
#line 53 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_double_scan_fractional_token(MP mp,int n);
static void mp_double_scan_numeric_token(MP mp,int n);
static void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);
static void mp_double_ab_vs_cd(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);
static void mp_double_crossing_point(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c);
static void mp_number_modulo(mp_number*a,mp_number b);
static void mp_double_print_number(MP mp,mp_number n);
static char*mp_double_number_tostring(MP mp,mp_number n);
static void mp_double_slow_add(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig);
static void mp_double_square_rt(MP mp,mp_number*ret,mp_number x_orig);
static void mp_double_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin);
static void mp_init_randoms(MP mp,int seed);
static void mp_number_angle_to_scaled(mp_number*A);
static void mp_number_fraction_to_scaled(mp_number*A);
static void mp_number_scaled_to_fraction(mp_number*A);
static void mp_number_scaled_to_angle(mp_number*A);
static void mp_double_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig);
static void mp_double_m_norm_rand(MP mp,mp_number*ret);
static void mp_double_m_exp(MP mp,mp_number*ret,mp_number x_orig);
static void mp_double_m_log(MP mp,mp_number*ret,mp_number x_orig);
static void mp_double_pyth_sub(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_double_pyth_add(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_double_n_arg(MP mp,mp_number*ret,mp_number x,mp_number y);
static void mp_double_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,mp_number cf,mp_number t);
static void mp_set_double_from_int(mp_number*A,int B);
static void mp_set_double_from_boolean(mp_number*A,int B);
static void mp_set_double_from_scaled(mp_number*A,int B);
static void mp_set_double_from_addition(mp_number*A,mp_number B,mp_number C);
static void mp_set_double_from_substraction(mp_number*A,mp_number B,mp_number C);
static void mp_set_double_from_div(mp_number*A,mp_number B,mp_number C);
static void mp_set_double_from_mul(mp_number*A,mp_number B,mp_number C);
static void mp_set_double_from_int_div(mp_number*A,mp_number B,int C);
static void mp_set_double_from_int_mul(mp_number*A,mp_number B,int C);
static void mp_set_double_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C);
static void mp_number_negate(mp_number*A);
static void mp_number_add(mp_number*A,mp_number B);
static void mp_number_substract(mp_number*A,mp_number B);
static void mp_number_half(mp_number*A);
static void mp_number_halfp(mp_number*A);
static void mp_number_double(mp_number*A);
static void mp_number_add_scaled(mp_number*A,int B);
static void mp_number_multiply_int(mp_number*A,int B);
static void mp_number_divide_int(mp_number*A,int B);
static void mp_double_abs(mp_number*A);
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
static void mp_double_fraction_to_round_scaled(mp_number*x);
static void mp_double_number_make_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_double_number_make_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_double_number_take_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_double_number_take_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_new_number(MP mp,mp_number*n,mp_number_type t);
static void mp_free_number(MP mp,mp_number*n);
static void mp_set_double_from_double(mp_number*A,double B);
static void mp_free_double_math(MP mp);
static void mp_double_set_precision(MP mp);

/*:5*//*19:*/
#line 590 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

double mp_double_make_fraction(MP mp,double p,double q);

/*:19*//*21:*/
#line 611 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

double mp_double_take_fraction(MP mp,double p,double q);

/*:21*//*24:*/
#line 644 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

double mp_double_make_scaled(MP mp,double p,double q);


/*:24*//*26:*/
#line 658 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_wrapup_numeric_token(MP mp,unsigned char*start,unsigned char*stop);

/*:26*/
#line 33 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"
;

/*:2*//*7:*/
#line 141 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void*mp_initialize_double_math(MP mp){
math_data*math= (math_data*)mp_xmalloc(mp,1,sizeof(math_data));

math->allocate= mp_new_number;
math->free= mp_free_number;
mp_new_number(mp,&math->precision_default,mp_scaled_type);
math->precision_default.data.dval= 16*unity;
mp_new_number(mp,&math->precision_max,mp_scaled_type);
math->precision_max.data.dval= 16*unity;
mp_new_number(mp,&math->precision_min,mp_scaled_type);
math->precision_min.data.dval= 16*unity;

mp_new_number(mp,&math->epsilon_t,mp_scaled_type);
math->epsilon_t.data.dval= epsilon;
mp_new_number(mp,&math->inf_t,mp_scaled_type);
math->inf_t.data.dval= EL_GORDO;
mp_new_number(mp,&math->warning_limit_t,mp_scaled_type);
math->warning_limit_t.data.dval= warning_limit;
mp_new_number(mp,&math->one_third_inf_t,mp_scaled_type);
math->one_third_inf_t.data.dval= one_third_EL_GORDO;
mp_new_number(mp,&math->unity_t,mp_scaled_type);
math->unity_t.data.dval= unity;
mp_new_number(mp,&math->two_t,mp_scaled_type);
math->two_t.data.dval= two;
mp_new_number(mp,&math->three_t,mp_scaled_type);
math->three_t.data.dval= three;
mp_new_number(mp,&math->half_unit_t,mp_scaled_type);
math->half_unit_t.data.dval= half_unit;
mp_new_number(mp,&math->three_quarter_unit_t,mp_scaled_type);
math->three_quarter_unit_t.data.dval= three_quarter_unit;
mp_new_number(mp,&math->zero_t,mp_scaled_type);

mp_new_number(mp,&math->arc_tol_k,mp_fraction_type);
math->arc_tol_k.data.dval= (unity/4096);
mp_new_number(mp,&math->fraction_one_t,mp_fraction_type);
math->fraction_one_t.data.dval= fraction_one;
mp_new_number(mp,&math->fraction_half_t,mp_fraction_type);
math->fraction_half_t.data.dval= fraction_half;
mp_new_number(mp,&math->fraction_three_t,mp_fraction_type);
math->fraction_three_t.data.dval= fraction_three;
mp_new_number(mp,&math->fraction_four_t,mp_fraction_type);
math->fraction_four_t.data.dval= fraction_four;

mp_new_number(mp,&math->three_sixty_deg_t,mp_angle_type);
math->three_sixty_deg_t.data.dval= three_sixty_deg;
mp_new_number(mp,&math->one_eighty_deg_t,mp_angle_type);
math->one_eighty_deg_t.data.dval= one_eighty_deg;

mp_new_number(mp,&math->one_k,mp_scaled_type);
math->one_k.data.dval= 1.0/64;
mp_new_number(mp,&math->sqrt_8_e_k,mp_scaled_type);
math->sqrt_8_e_k.data.dval= 1.71552776992141359295;
mp_new_number(mp,&math->twelve_ln_2_k,mp_fraction_type);
math->twelve_ln_2_k.data.dval= 8.31776616671934371292*256;
mp_new_number(mp,&math->coef_bound_k,mp_fraction_type);
math->coef_bound_k.data.dval= coef_bound;
mp_new_number(mp,&math->coef_bound_minus_1,mp_fraction_type);
math->coef_bound_minus_1.data.dval= coef_bound-1/65536.0;
mp_new_number(mp,&math->twelvebits_3,mp_scaled_type);
math->twelvebits_3.data.dval= 1365/65536.0;
mp_new_number(mp,&math->twentysixbits_sqrt2_t,mp_fraction_type);
math->twentysixbits_sqrt2_t.data.dval= 94906266/65536.0;
mp_new_number(mp,&math->twentyeightbits_d_t,mp_fraction_type);
math->twentyeightbits_d_t.data.dval= 35596755/65536.0;
mp_new_number(mp,&math->twentysevenbits_sqrt2_d_t,mp_fraction_type);
math->twentysevenbits_sqrt2_d_t.data.dval= 25170707/65536.0;

mp_new_number(mp,&math->fraction_threshold_t,mp_fraction_type);
math->fraction_threshold_t.data.dval= fraction_threshold;
mp_new_number(mp,&math->half_fraction_threshold_t,mp_fraction_type);
math->half_fraction_threshold_t.data.dval= half_fraction_threshold;
mp_new_number(mp,&math->scaled_threshold_t,mp_scaled_type);
math->scaled_threshold_t.data.dval= scaled_threshold;
mp_new_number(mp,&math->half_scaled_threshold_t,mp_scaled_type);
math->half_scaled_threshold_t.data.dval= half_scaled_threshold;
mp_new_number(mp,&math->near_zero_angle_t,mp_angle_type);
math->near_zero_angle_t.data.dval= near_zero_angle;
mp_new_number(mp,&math->p_over_v_threshold_t,mp_fraction_type);
math->p_over_v_threshold_t.data.dval= p_over_v_threshold;
mp_new_number(mp,&math->equation_threshold_t,mp_scaled_type);
math->equation_threshold_t.data.dval= equation_threshold;
mp_new_number(mp,&math->tfm_warn_threshold_t,mp_scaled_type);
math->tfm_warn_threshold_t.data.dval= tfm_warn_threshold;

math->from_int= mp_set_double_from_int;
math->from_boolean= mp_set_double_from_boolean;
math->from_scaled= mp_set_double_from_scaled;
math->from_double= mp_set_double_from_double;
math->from_addition= mp_set_double_from_addition;
math->from_substraction= mp_set_double_from_substraction;
math->from_oftheway= mp_set_double_from_of_the_way;
math->from_div= mp_set_double_from_div;
math->from_mul= mp_set_double_from_mul;
math->from_int_div= mp_set_double_from_int_div;
math->from_int_mul= mp_set_double_from_int_mul;
math->negate= mp_number_negate;
math->add= mp_number_add;
math->substract= mp_number_substract;
math->half= mp_number_half;
math->halfp= mp_number_halfp;
math->do_double= mp_number_double;
math->abs= mp_double_abs;
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
math->fraction_to_round_scaled= mp_double_fraction_to_round_scaled;
math->make_scaled= mp_double_number_make_scaled;
math->make_fraction= mp_double_number_make_fraction;
math->take_fraction= mp_double_number_take_fraction;
math->take_scaled= mp_double_number_take_scaled;
math->velocity= mp_double_velocity;
math->n_arg= mp_double_n_arg;
math->m_log= mp_double_m_log;
math->m_exp= mp_double_m_exp;
math->m_unif_rand= mp_double_m_unif_rand;
math->m_norm_rand= mp_double_m_norm_rand;
math->pyth_add= mp_double_pyth_add;
math->pyth_sub= mp_double_pyth_sub;
math->fraction_to_scaled= mp_number_fraction_to_scaled;
math->scaled_to_fraction= mp_number_scaled_to_fraction;
math->scaled_to_angle= mp_number_scaled_to_angle;
math->angle_to_scaled= mp_number_angle_to_scaled;
math->init_randoms= mp_init_randoms;
math->sin_cos= mp_double_sin_cos;
math->slow_add= mp_double_slow_add;
math->sqrt= mp_double_square_rt;
math->print= mp_double_print_number;
math->tostring= mp_double_number_tostring;
math->modulo= mp_number_modulo;
math->ab_vs_cd= mp_ab_vs_cd;
math->crossing_point= mp_double_crossing_point;
math->scan_numeric= mp_double_scan_numeric_token;
math->scan_fractional= mp_double_scan_fractional_token;
math->free_math= mp_free_double_math;
math->set_precision= mp_double_set_precision;
return(void*)math;
}

void mp_double_set_precision(MP mp){
}

void mp_free_double_math(MP mp){
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
free(mp->math);
}

/*:7*//*9:*/
#line 327 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_new_number(MP mp,mp_number*n,mp_number_type t){
(void)mp;
n->data.dval= 0.0;
n->type= t;
}

/*:9*//*10:*/
#line 336 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_free_number(MP mp,mp_number*n){
(void)mp;
n->type= mp_nan_type;
}

/*:10*//*11:*/
#line 344 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_set_double_from_int(mp_number*A,int B){
A->data.dval= B;
}
void mp_set_double_from_boolean(mp_number*A,int B){
A->data.dval= B;
}
void mp_set_double_from_scaled(mp_number*A,int B){
A->data.dval= B/65536.0;
}
void mp_set_double_from_double(mp_number*A,double B){
A->data.dval= B;
}
void mp_set_double_from_addition(mp_number*A,mp_number B,mp_number C){
A->data.dval= B.data.dval+C.data.dval;
}
void mp_set_double_from_substraction(mp_number*A,mp_number B,mp_number C){
A->data.dval= B.data.dval-C.data.dval;
}
void mp_set_double_from_div(mp_number*A,mp_number B,mp_number C){
A->data.dval= B.data.dval/C.data.dval;
}
void mp_set_double_from_mul(mp_number*A,mp_number B,mp_number C){
A->data.dval= B.data.dval*C.data.dval;
}
void mp_set_double_from_int_div(mp_number*A,mp_number B,int C){
A->data.dval= B.data.dval/C;
}
void mp_set_double_from_int_mul(mp_number*A,mp_number B,int C){
A->data.dval= B.data.dval*C;
}
void mp_set_double_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C){
A->data.dval= B.data.dval-mp_double_take_fraction(mp,(B.data.dval-C.data.dval),t.data.dval);
}
void mp_number_negate(mp_number*A){
A->data.dval= -A->data.dval;
if(A->data.dval==-0.0)
A->data.dval= 0.0;
}
void mp_number_add(mp_number*A,mp_number B){
A->data.dval= A->data.dval+B.data.dval;
}
void mp_number_substract(mp_number*A,mp_number B){
A->data.dval= A->data.dval-B.data.dval;
}
void mp_number_half(mp_number*A){
A->data.dval= A->data.dval/2.0;
}
void mp_number_halfp(mp_number*A){
A->data.dval= (A->data.dval/2.0);
}
void mp_number_double(mp_number*A){
A->data.dval= A->data.dval*2.0;
}
void mp_number_add_scaled(mp_number*A,int B){
A->data.dval= A->data.dval+(B/65536.0);
}
void mp_number_multiply_int(mp_number*A,int B){
A->data.dval= (double)(A->data.dval*B);
}
void mp_number_divide_int(mp_number*A,int B){
A->data.dval= A->data.dval/(double)B;
}
void mp_double_abs(mp_number*A){
A->data.dval= fabs(A->data.dval);
}
void mp_number_clone(mp_number*A,mp_number B){
A->data.dval= B.data.dval;
}
void mp_number_swap(mp_number*A,mp_number*B){
double swap_tmp= A->data.dval;
A->data.dval= B->data.dval;
B->data.dval= swap_tmp;
}
void mp_number_fraction_to_scaled(mp_number*A){
A->type= mp_scaled_type;
A->data.dval= A->data.dval/fraction_multiplier;
}
void mp_number_angle_to_scaled(mp_number*A){
A->type= mp_scaled_type;
A->data.dval= A->data.dval/angle_multiplier;
}
void mp_number_scaled_to_fraction(mp_number*A){
A->type= mp_fraction_type;
A->data.dval= A->data.dval*fraction_multiplier;
}
void mp_number_scaled_to_angle(mp_number*A){
A->type= mp_angle_type;
A->data.dval= A->data.dval*angle_multiplier;
}


/*:11*//*12:*/
#line 438 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

int mp_number_to_scaled(mp_number A){
return(int)ROUND(A.data.dval*65536.0);
}
int mp_number_to_int(mp_number A){
return(int)(A.data.dval);
}
int mp_number_to_boolean(mp_number A){
return(int)(A.data.dval);
}
double mp_number_to_double(mp_number A){
return A.data.dval;
}
int mp_number_odd(mp_number A){
return odd((int)ROUND(A.data.dval*65536.0));
}
int mp_number_equal(mp_number A,mp_number B){
return(A.data.dval==B.data.dval);
}
int mp_number_greater(mp_number A,mp_number B){
return(A.data.dval> B.data.dval);
}
int mp_number_less(mp_number A,mp_number B){
return(A.data.dval<B.data.dval);
}
int mp_number_nonequalabs(mp_number A,mp_number B){
return(!(fabs(A.data.dval)==fabs(B.data.dval)));
}

/*:12*//*15:*/
#line 498 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

char*mp_double_number_tostring(MP mp,mp_number n){
static char set[64];
int l= 0;
char*ret= mp_xmalloc(mp,64,1);
snprintf(set,64,"%.17g",n.data.dval);
while(set[l]==' ')l++;
strcpy(ret,set+l);
return ret;
}


/*:15*//*16:*/
#line 510 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_print_number(MP mp,mp_number n){
char*str= mp_double_number_tostring(mp,n);
mp_print(mp,str);
free(str);
}




/*:16*//*17:*/
#line 524 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_slow_add(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig){
double x,y;
x= x_orig.data.dval;
y= y_orig.data.dval;
if(x>=0){
if(y<=EL_GORDO-x){
ret->data.dval= x+y;
}else{
mp->arith_error= true;
ret->data.dval= EL_GORDO;
}
}else if(-y<=EL_GORDO+x){
ret->data.dval= x+y;
}else{
mp->arith_error= true;
ret->data.dval= -EL_GORDO;
}
}

/*:17*//*18:*/
#line 582 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

double mp_double_make_fraction(MP mp,double p,double q){
return((p/q)*fraction_multiplier);
}
void mp_double_number_make_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
ret->data.dval= mp_double_make_fraction(mp,p.data.dval,q.data.dval);
}

/*:18*//*20:*/
#line 603 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

double mp_double_take_fraction(MP mp,double p,double q){
return((p*q)/fraction_multiplier);
}
void mp_double_number_take_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
ret->data.dval= mp_double_take_fraction(mp,p.data.dval,q.data.dval);
}

/*:20*//*22:*/
#line 624 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_number_take_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
ret->data.dval= p_orig.data.dval*q_orig.data.dval;
}


/*:22*//*23:*/
#line 636 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

double mp_double_make_scaled(MP mp,double p,double q){
return p/q;
}
void mp_double_number_make_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
ret->data.dval= p_orig.data.dval/q_orig.data.dval;
}

/*:23*//*27:*/
#line 661 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_wrapup_numeric_token(MP mp,unsigned char*start,unsigned char*stop){
double result;
char*end= (char*)stop;
errno= 0;
result= strtod((char*)start,&end);
if(errno==0){
set_cur_mod(result);
if(result>=warning_limit){
if(internal_value(mp_warning_check).data.dval> 0&&
(mp->scanner_status!=tex_flushing)){
char msg[256];
const char*hlp[]= {"Continue and I'll try to cope",
"with that big value; but it might be dangerous.",
"(Set warningcheck:=0 to suppress this message.)",
NULL};
mp_snprintf(msg,256,"Number is too large (%g)",result);
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
set_cur_mod(EL_GORDO);
}
set_cur_cmd((mp_variable_type)mp_numeric_token);
}

/*:27*//*28:*/
#line 695 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

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
void mp_double_scan_fractional_token(MP mp,int n){
unsigned char*start= &mp->buffer[mp->cur_input.loc_field-1];
unsigned char*stop;
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
mp->cur_input.loc_field++;
}
find_exponent(mp);
stop= &mp->buffer[mp->cur_input.loc_field-1];
mp_wrapup_numeric_token(mp,start,stop);
}


/*:28*//*29:*/
#line 730 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_scan_numeric_token(MP mp,int n){
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

/*:29*//*31:*/
#line 783 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,
mp_number cf,mp_number t){
double acc,num,denom;
acc= mp_double_take_fraction(mp,st.data.dval-(sf.data.dval/16.0),
sf.data.dval-(st.data.dval/16.0));
acc= mp_double_take_fraction(mp,acc,ct.data.dval-cf.data.dval);
num= fraction_two+mp_double_take_fraction(mp,acc,sqrt(2)*fraction_one);
denom=
fraction_three+mp_double_take_fraction(mp,ct.data.dval,3*fraction_half*(sqrt(5.0)-1.0))
+mp_double_take_fraction(mp,cf.data.dval,3*fraction_half*(3.0-sqrt(5.0)));
if(t.data.dval!=unity)
num= mp_double_make_scaled(mp,num,t.data.dval);
if(num/4>=denom){
ret->data.dval= fraction_four;
}else{
ret->data.dval= mp_double_make_fraction(mp,num,denom);
}
#if DEBUG
fprintf(stdout,"\n%f = velocity(%f,%f,%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(st),mp_number_to_double(ct),
mp_number_to_double(sf),mp_number_to_double(cf),
mp_number_to_double(t));
#endif
}


/*:31*//*32:*/
#line 815 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
integer q,r;
integer a,b,c,d;
(void)mp;

mp_double_ab_vs_cd(mp,ret,a_orig,b_orig,c_orig,d_orig);
if(1> 0)
return;

a= a_orig.data.dval;
b= b_orig.data.dval;
c= c_orig.data.dval;
d= d_orig.data.dval;
/*33:*/
#line 862 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

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
ret->data.dval= 0;
else
ret->data.dval= 1;
goto RETURN;
}
if(d==0){
ret->data.dval= (a==0?0:-1);
goto RETURN;
}
q= a;
a= c;
c= q;
q= -b;
b= -d;
d= q;
}else if(b<=0){
if(b<0&&a> 0){
ret->data.dval= -1;
return;
}
ret->data.dval= (c==0?0:-1);
goto RETURN;
}

/*:33*/
#line 829 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"
;
while(1){
q= a/d;
r= c/b;
if(q!=r){
ret->data.dval= (q> r?1:-1);
goto RETURN;
}
q= a%d;
r= c%b;
if(r==0){
ret->data.dval= (q?1:0);
goto RETURN;
}
if(q==0){
ret->data.dval= -1;
goto RETURN;
}
a= b;
b= q;
c= d;
d= r;
}
RETURN:
#if DEBUG
fprintf(stdout,"\n%f = ab_vs_cd(%f,%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(a_orig),mp_number_to_double(b_orig),
mp_number_to_double(c_orig),mp_number_to_double(d_orig));
#endif
return;
}


/*:32*//*34:*/
#line 931 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_double_crossing_point(MP mp,mp_number*ret,mp_number aa,mp_number bb,mp_number cc){
double a,b,c;
double d;
double x,xx,x0,x1,x2;
a= aa.data.dval;
b= bb.data.dval;
c= cc.data.dval;
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


d= epsilon;
x0= a;
x1= a-b;
x2= b-c;
do{

x= (x1+x2)/2+1E-12;
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
d= d+d+epsilon;
}
}
}while(d<fraction_one);
ret->data.dval= (d-fraction_one);
RETURN:
#if DEBUG
fprintf(stdout,"\n%f = crossing_point(%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(aa),mp_number_to_double(bb),mp_number_to_double(cc));
#endif
return;
}


/*:34*//*36:*/
#line 1002 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

int mp_round_unscaled(mp_number x_orig){
int x= (int)ROUND(x_orig.data.dval);
return x;
}

/*:36*//*37:*/
#line 1010 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_number_floor(mp_number*i){
i->data.dval= floor(i->data.dval);
}

/*:37*//*38:*/
#line 1016 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_fraction_to_round_scaled(mp_number*x_orig){
double x= x_orig->data.dval;
x_orig->type= mp_scaled_type;
x_orig->data.dval= x/fraction_multiplier;
}



/*:38*//*40:*/
#line 1031 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_square_rt(MP mp,mp_number*ret,mp_number x_orig){
double x;
x= x_orig.data.dval;
if(x<=0){
/*41:*/
#line 1043 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

{
if(x<0){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*xstr= mp_double_number_tostring(mp,x_orig);
mp_snprintf(msg,256,"Square root of %s has been replaced by 0",xstr);
free(xstr);
;
mp_error(mp,msg,hlp,true);
}
ret->data.dval= 0;
return;
}


/*:41*/
#line 1036 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"
;
}else{
ret->data.dval= sqrt(x);
}
}


/*:40*//*42:*/
#line 1064 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_pyth_add(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
double a,b;
a= fabs(a_orig.data.dval);
b= fabs(b_orig.data.dval);
errno= 0;
ret->data.dval= sqrt(a*a+b*b);
if(errno){
mp->arith_error= true;
ret->data.dval= EL_GORDO;
}
}


/*:42*//*43:*/
#line 1080 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_pyth_sub(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
double a,b;
a= fabs(a_orig.data.dval);
b= fabs(b_orig.data.dval);
if(a<=b){
/*44:*/
#line 1094 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

{
if(a<b){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*astr= mp_double_number_tostring(mp,a_orig);
char*bstr= mp_double_number_tostring(mp,b_orig);
mp_snprintf(msg,256,"Pythagorean subtraction %s+-+%s has been replaced by 0",astr,bstr);
free(astr);
free(bstr);
;
mp_error(mp,msg,hlp,true);
}
a= 0;
}


/*:44*/
#line 1086 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"
;
}else{
a= sqrt(a*a-b*b);
}
ret->data.dval= a;
}


/*:43*//*46:*/
#line 1123 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_m_log(MP mp,mp_number*ret,mp_number x_orig){
if(x_orig.data.dval<=0){
/*47:*/
#line 1132 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

{
char msg[256];
const char*hlp[]= {
"Since I don't take logs of non-positive numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*xstr= mp_double_number_tostring(mp,x_orig);
mp_snprintf(msg,256,"Logarithm of %s has been replaced by 0",xstr);
free(xstr);
;
mp_error(mp,msg,hlp,true);
ret->data.dval= 0;
}


/*:47*/
#line 1126 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"
;
}else{
ret->data.dval= log(x_orig.data.dval)*256.0;
}
}

/*:46*//*48:*/
#line 1151 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_m_exp(MP mp,mp_number*ret,mp_number x_orig){
errno= 0;
ret->data.dval= exp(x_orig.data.dval/256.0);
if(errno){
if(x_orig.data.dval> 0){
mp->arith_error= true;
ret->data.dval= EL_GORDO;
}else{
ret->data.dval= 0;
}
}
}


/*:48*//*49:*/
#line 1169 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_n_arg(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig){
if(x_orig.data.dval==0.0&&y_orig.data.dval==0.0){
/*50:*/
#line 1186 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

{
const char*hlp[]= {
"The `angle' between two identical points is undefined.",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_error(mp,"angle(0,0) is taken as zero",hlp,true);
;
ret->data.dval= 0;
}


/*:50*/
#line 1172 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"
;
}else{
ret->type= mp_angle_type;
ret->data.dval= atan2(y_orig.data.dval,x_orig.data.dval)*(180.0/PI)*angle_multiplier;
if(ret->data.dval==-0.0)
ret->data.dval= 0.0;
#if DEBUG
fprintf(stdout,"\nn_arg(%g,%g,%g)",mp_number_to_double(*ret),
mp_number_to_double(x_orig),mp_number_to_double(y_orig));
#endif
}
}


/*:49*//*53:*/
#line 1216 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin){
double rad;
rad= (z_orig.data.dval/angle_multiplier);
if((rad==90.0)||(rad==-270)){
n_cos->data.dval= 0.0;
n_sin->data.dval= fraction_multiplier;
}else if((rad==-90.0)||(rad==270.0)){
n_cos->data.dval= 0.0;
n_sin->data.dval= -fraction_multiplier;
}else if((rad==180.0)||(rad==-180.0)){
n_cos->data.dval= -fraction_multiplier;
n_sin->data.dval= 0.0;
}else{
rad= rad*PI/180.0;
n_cos->data.dval= cos(rad)*fraction_multiplier;
n_sin->data.dval= sin(rad)*fraction_multiplier;
}
#if DEBUG
fprintf(stdout,"\nsin_cos(%f,%f,%f)",mp_number_to_double(z_orig),
mp_number_to_double(*n_cos),mp_number_to_double(*n_sin));
#endif
}

/*:53*//*54:*/
#line 1243 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

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



/*:54*//*55:*/
#line 1317 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

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
mp->randoms[(i*21)%55].data.dval= j;
}
mp_new_randoms(mp);
mp_new_randoms(mp);
mp_new_randoms(mp);

ran_start((unsigned long)seed);


}

/*:55*//*56:*/
#line 1343 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static double modulus(double left,double right);
double modulus(double left,double right){
double quota= left/right;
double frac,tmp;
frac= modf(quota,&tmp);

frac*= right;
return frac;
}
void mp_number_modulo(mp_number*a,mp_number b){
a->data.dval= modulus(a->data.dval,b.data.dval);
}



/*:56*//*57:*/
#line 1361 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_next_unif_random(MP mp,mp_number*ret){
double a;
unsigned long int op;
(void)mp;
op= (unsigned)ran_arr_next();
a= op/(MM*1.0);
ret->data.dval= a;
}



/*:57*//*58:*/
#line 1375 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_next_random(MP mp,mp_number*ret){
if(mp->j_random==0)
mp_new_randoms(mp);
else
mp->j_random= mp->j_random-1;
mp_number_clone(ret,mp->randoms[mp->j_random]);
}


/*:58*//*59:*/
#line 1392 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_double_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig){
mp_number y;
mp_number x,abs_x;
mp_number u;
new_fraction(y);
new_number(x);
new_number(abs_x);
new_number(u);
mp_number_clone(&x,x_orig);
mp_number_clone(&abs_x,x);
mp_double_abs(&abs_x);
mp_next_unif_random(mp,&u);
y.data.dval= abs_x.data.dval*u.data.dval;
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



/*:59*//*60:*/
#line 1426 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

static void mp_double_m_norm_rand(MP mp,mp_number*ret){
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
mp_double_number_take_fraction(mp,&xa,((math_data*)mp->math)->sqrt_8_e_k,v);
free_number(v);
mp_next_random(mp,&u);
mp_number_clone(&abs_x,xa);
mp_double_abs(&abs_x);
}while(!mp_number_less(abs_x,u));
mp_double_number_make_fraction(mp,&r,xa,u);
mp_number_clone(&xa,r);
mp_double_m_log(mp,&la,u);
mp_set_double_from_substraction(&la,((math_data*)mp->math)->twelve_ln_2_k,la);
mp_double_ab_vs_cd(mp,&ab_vs_cd,((math_data*)mp->math)->one_k,la,xa,xa);
}while(mp_number_less(ab_vs_cd,((math_data*)mp->math)->zero_t));
mp_number_clone(ret,xa);
free_number(ab_vs_cd);
free_number(r);
free_number(abs_x);
free_number(la);
free_number(xa);
free_number(u);
}




/*:60*//*61:*/
#line 1474 "../../../source/texk/web2c/mplibdir/mpmathdouble.w"

void mp_double_ab_vs_cd(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
double ab,cd;
(void)mp;
ret->data.dval= 0;
ab= a_orig.data.dval*b_orig.data.dval;
cd= c_orig.data.dval*d_orig.data.dval;
if(ab> cd)
ret->data.dval= 1;
else if(ab<cd)
ret->data.dval= -1;
return;
}
/*:61*/
