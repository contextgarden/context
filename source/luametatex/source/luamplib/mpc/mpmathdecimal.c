/*1:*/
#line 22 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "mpmathdecimal.h"
#define ROUND(a) floor((a)+0.5)
#define E_STRING "2.7182818284590452353602874713526624977572470936999595749669676277240766303535"
#define PI_STRING "3.1415926535897932384626433832795028841971693993751058209749445923078164062862"
#define fraction_multiplier 4096
#define angle_multiplier 16 \

#define decNumberIsPositive(A) !(decNumberIsZero(A) ||decNumberIsNegative(A) )  \

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
#define epsilon "1E-52"
#define epsilonf pow(2.0,-52.0)
#define EL_GORDO "1E1000000"
#define warning_limit "1E1000000"
#define DECPRECISION_DEFAULT 34 \

#define odd(A) (abs(A) %2==1)  \

#define halfp(A) (integer) ((unsigned) (A) >>1)  \

#define set_cur_cmd(A) mp->cur_mod_->type= (A)
#define set_cur_mod(A) decNumberCopy((decNumber*) (mp->cur_mod_->data.n.data.num) ,&A)  \

#define too_precise(a) (a==(DEC_Inexact+DEC_Rounded) )
#define too_large(a) (a&DEC_Overflow)
#define fraction_half (fraction_multiplier/2)
#define fraction_one (1*fraction_multiplier)
#define fraction_two (2*fraction_multiplier)
#define fraction_three (3*fraction_multiplier)
#define fraction_four (4*fraction_multiplier)  \

#define no_crossing {decNumberCopy(ret->data.num,&fraction_one_plus_decNumber) ;goto RETURN;}
#define one_crossing {decNumberCopy(ret->data.num,&fraction_one_decNumber) ;goto RETURN;}
#define zero_crossing {decNumberCopy(ret->data.num,&zero) ;goto RETURN;} \

#define PRECALC_FACTORIALS_CACHESIZE 50 \


#line 30 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"


/*:1*//*2:*/
#line 32 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

/*5:*/
#line 56 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

#define DEBUG 0
static void mp_decimal_scan_fractional_token(MP mp,int n);
static void mp_decimal_scan_numeric_token(MP mp,int n);
static void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);

static void mp_decimal_crossing_point(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c);
static void mp_decimal_number_modulo(mp_number*a,mp_number b);
static void mp_decimal_print_number(MP mp,mp_number n);
static char*mp_decimal_number_tostring(MP mp,mp_number n);
static void mp_decimal_slow_add(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig);
static void mp_decimal_square_rt(MP mp,mp_number*ret,mp_number x_orig);
static void mp_decimal_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin);
static void mp_init_randoms(MP mp,int seed);
static void mp_number_angle_to_scaled(mp_number*A);
static void mp_number_fraction_to_scaled(mp_number*A);
static void mp_number_scaled_to_fraction(mp_number*A);
static void mp_number_scaled_to_angle(mp_number*A);
static void mp_decimal_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig);
static void mp_decimal_m_norm_rand(MP mp,mp_number*ret);
static void mp_decimal_m_exp(MP mp,mp_number*ret,mp_number x_orig);
static void mp_decimal_m_log(MP mp,mp_number*ret,mp_number x_orig);
static void mp_decimal_pyth_sub(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_decimal_pyth_add(MP mp,mp_number*r,mp_number a,mp_number b);
static void mp_decimal_n_arg(MP mp,mp_number*ret,mp_number x,mp_number y);
static void mp_decimal_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,mp_number cf,mp_number t);
static void mp_set_decimal_from_int(mp_number*A,int B);
static void mp_set_decimal_from_boolean(mp_number*A,int B);
static void mp_set_decimal_from_scaled(mp_number*A,int B);
static void mp_set_decimal_from_addition(mp_number*A,mp_number B,mp_number C);
static void mp_set_decimal_from_substraction(mp_number*A,mp_number B,mp_number C);
static void mp_set_decimal_from_div(mp_number*A,mp_number B,mp_number C);
static void mp_set_decimal_from_mul(mp_number*A,mp_number B,mp_number C);
static void mp_set_decimal_from_int_div(mp_number*A,mp_number B,int C);
static void mp_set_decimal_from_int_mul(mp_number*A,mp_number B,int C);
static void mp_set_decimal_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C);
static void mp_number_negate(mp_number*A);
static void mp_number_add(mp_number*A,mp_number B);
static void mp_number_substract(mp_number*A,mp_number B);
static void mp_number_half(mp_number*A);
static void mp_number_halfp(mp_number*A);
static void mp_number_double(mp_number*A);
static void mp_number_add_scaled(mp_number*A,int B);
static void mp_number_multiply_int(mp_number*A,int B);
static void mp_number_divide_int(mp_number*A,int B);
static void mp_decimal_abs(mp_number*A);
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
static void mp_decimal_fraction_to_round_scaled(mp_number*x);
static void mp_decimal_number_make_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_decimal_number_make_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_decimal_number_take_fraction(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_decimal_number_take_scaled(MP mp,mp_number*r,mp_number p,mp_number q);
static void mp_new_number(MP mp,mp_number*n,mp_number_type t);
static void mp_free_number(MP mp,mp_number*n);
static void mp_set_decimal_from_double(mp_number*A,double B);
static void mp_free_decimal_math(MP mp);
static void mp_decimal_set_precision(MP mp);
static void mp_check_decNumber(MP mp,decNumber*dec,decContext*context);
static int decNumber_check(decNumber*dec,decContext*context);
static char*mp_decnumber_tostring(decNumber*n);

/*:5*//*10:*/
#line 355 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static decNumber zero;
static decNumber one;
static decNumber minusone;
static decNumber two_decNumber;
static decNumber three_decNumber;
static decNumber four_decNumber;
static decNumber fraction_multiplier_decNumber;
static decNumber angle_multiplier_decNumber;
static decNumber fraction_one_decNumber;
static decNumber fraction_one_plus_decNumber;
static decNumber PI_decNumber;
static decNumber epsilon_decNumber;
static decNumber EL_GORDO_decNumber;
static decNumber**factorials= NULL;
static int last_cached_factorial= 0;
static boolean initialized= false;
/*:10*//*25:*/
#line 948 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_make_fraction(MP mp,decNumber*ret,decNumber*p,decNumber*q);

/*:25*//*27:*/
#line 970 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_take_fraction(MP mp,decNumber*ret,decNumber*p,decNumber*q);

/*:27*//*31:*/
#line 1011 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void mp_wrapup_numeric_token(MP mp,unsigned char*start,unsigned char*stop);

/*:31*/
#line 33 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"
;

/*:2*//*6:*/
#line 132 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

int decNumber_check(decNumber*dec,decContext*context)
{
int test= false;
if(context->status&DEC_Overflow){
test= true;
context->status&= ~DEC_Overflow;
}
if(context->status&DEC_Underflow){
test= true;
context->status&= ~DEC_Underflow;
}
if(context->status&DEC_Errors){

test= true;
decNumberZero(dec);
}
context->status= 0;
if(decNumberIsSpecial(dec)){
test= true;
if(decNumberIsInfinite(dec)){
if(decNumberIsNegative(dec)){
decNumberCopyNegate(dec,&EL_GORDO_decNumber);
}else{
decNumberCopy(dec,&EL_GORDO_decNumber);
}
}else{
decNumberZero(dec);
}
}
if(decNumberIsZero(dec)&&decNumberIsNegative(dec)){
decNumberZero(dec);
}
return test;
}
void mp_check_decNumber(MP mp,decNumber*dec,decContext*context)
{
mp->arith_error= decNumber_check(dec,context);
}




/*:6*//*7:*/
#line 180 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static decContext set;
static decContext limitedset;
static void checkZero(decNumber*ret){
if(decNumberIsZero(ret)&&decNumberIsNegative(ret))
decNumberZero(ret);
}
static int decNumberLess(decNumber*a,decNumber*b){
decNumber comp;
decNumberCompare(&comp,a,b,&set);
return decNumberIsNegative(&comp);
}
static int decNumberGreater(decNumber*a,decNumber*b){
decNumber comp;
decNumberCompare(&comp,a,b,&set);
return decNumberIsPositive(&comp);
}
static void decNumberFromDouble(decNumber*A,double B){
char buf[1000];
char*c;
snprintf(buf,1000,"%-650.325lf",B);
c= buf;
while(*c++){
if(*c==' '){
*c= '\0';
break;
}
}
decNumberFromString(A,buf,&set);
}
static double decNumberToDouble(decNumber*A){
char*buffer= malloc(A->digits+14);
double res= 0.0;
assert(buffer);
decNumberToString(A,buffer);
if(sscanf(buffer,"%lf",&res)){
free(buffer);
return res;
}else{
free(buffer);

return 0.0;
}
}
/*:7*//*8:*/
#line 247 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void decNumberAtan(decNumber*result,decNumber*x_orig,decContext*set)
{
decNumber x,f,g,mx2,term;
int i;
decNumberCopy(&x,x_orig);
if(decNumberIsZero(&x)){
decNumberCopy(result,&x);
return;
}
for(i= 0;i<2;i++){
decNumber y;
decNumberMultiply(&y,&x,&x,set);
decNumberAdd(&y,&y,&one,set);
decNumberSquareRoot(&y,&y,set);
decNumberSubtract(&y,&y,&one,set);
decNumberDivide(&x,&y,&x,set);
if(decNumberIsZero(&x)){
decNumberCopy(result,&x);
return;
}
}
decNumberCopy(&f,&x);
decNumberCopy(&g,&one);
decNumberCopy(&term,&x);
decNumberCopy(result,&x);
decNumberMultiply(&mx2,&x,&x,set);
decNumberMinus(&mx2,&mx2,set);
for(i= 0;i<2*set->digits;i++){
decNumberMultiply(&f,&f,&mx2,set);
decNumberAdd(&g,&g,&two_decNumber,set);
decNumberDivide(&term,&f,&g,set);
decNumberAdd(result,result,&term,set);
}
decNumberAdd(result,result,result,set);
decNumberAdd(result,result,result,set);
return;
}
static void decNumberAtan2(decNumber*result,decNumber*y,decNumber*x,decContext*set)
{
decNumber temp;
if(!decNumberIsInfinite(x)&&!decNumberIsZero(y)
&&!decNumberIsInfinite(y)&&!decNumberIsZero(x)){
decNumberDivide(&temp,y,x,set);
decNumberAtan(result,&temp,set);


if(decNumberIsNegative(x)){
if(decNumberIsNegative(y)){
decNumberSubtract(result,result,&PI_decNumber,set);
}else{
decNumberAdd(result,result,&PI_decNumber,set);
}
}
return;
}
if(decNumberIsInfinite(y)&&decNumberIsInfinite(x)){

decNumberDivide(result,&PI_decNumber,&four_decNumber,set);
if(decNumberIsNegative(x)){
decNumber a;
decNumberFromDouble(&a,3.0);
decNumberMultiply(result,result,&a,set);
}
}else if(!decNumberIsZero(y)&&!decNumberIsInfinite(x)){

decNumberDivide(result,&PI_decNumber,&two_decNumber,set);
}else{
if(decNumberIsNegative(x)){
decNumberCopy(result,&PI_decNumber);
}else{
decNumberZero(result);
}
}

if(decNumberIsNegative(y)){
decNumberMinus(result,result,set);
}
}

/*:8*//*11:*/
#line 372 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void*mp_initialize_decimal_math(MP mp){
math_data*math= (math_data*)mp_xmalloc(mp,1,sizeof(math_data));

decContextDefault(&set,DEC_INIT_BASE);
set.traps= 0;
decContextDefault(&limitedset,DEC_INIT_BASE);
limitedset.traps= 0;
limitedset.emax= 999999;
limitedset.emin= -999999;
set.digits= DECPRECISION_DEFAULT;
limitedset.digits= DECPRECISION_DEFAULT;
if(!initialized){
initialized= true;
decNumberFromInt32(&one,1);
decNumberFromInt32(&minusone,-1);
decNumberFromInt32(&zero,0);
decNumberFromInt32(&two_decNumber,two);
decNumberFromInt32(&three_decNumber,three);
decNumberFromInt32(&four_decNumber,four);
decNumberFromInt32(&fraction_multiplier_decNumber,fraction_multiplier);
decNumberFromInt32(&fraction_one_decNumber,fraction_one);
decNumberFromInt32(&fraction_one_plus_decNumber,(fraction_one+1));
decNumberFromInt32(&angle_multiplier_decNumber,angle_multiplier);
decNumberFromString(&PI_decNumber,PI_STRING,&set);
decNumberFromString(&epsilon_decNumber,epsilon,&set);
decNumberFromString(&EL_GORDO_decNumber,EL_GORDO,&set);
factorials= (decNumber**)mp_xmalloc(mp,PRECALC_FACTORIALS_CACHESIZE,sizeof(decNumber*));
factorials[0]= (decNumber*)mp_xmalloc(mp,1,sizeof(decNumber));
decNumberCopy(factorials[0],&one);
}


math->allocate= mp_new_number;
math->free= mp_free_number;
mp_new_number(mp,&math->precision_default,mp_scaled_type);
decNumberFromInt32(math->precision_default.data.num,DECPRECISION_DEFAULT);
mp_new_number(mp,&math->precision_max,mp_scaled_type);
decNumberFromInt32(math->precision_max.data.num,DECNUMDIGITS);
mp_new_number(mp,&math->precision_min,mp_scaled_type);
decNumberFromInt32(math->precision_min.data.num,2);

mp_new_number(mp,&math->epsilon_t,mp_scaled_type);
decNumberCopy(math->epsilon_t.data.num,&epsilon_decNumber);
mp_new_number(mp,&math->inf_t,mp_scaled_type);
decNumberCopy(math->inf_t.data.num,&EL_GORDO_decNumber);
mp_new_number(mp,&math->warning_limit_t,mp_scaled_type);
decNumberFromString(math->warning_limit_t.data.num,warning_limit,&set);
mp_new_number(mp,&math->one_third_inf_t,mp_scaled_type);
decNumberDivide(math->one_third_inf_t.data.num,math->inf_t.data.num,&three_decNumber,&set);
mp_new_number(mp,&math->unity_t,mp_scaled_type);
decNumberCopy(math->unity_t.data.num,&one);
mp_new_number(mp,&math->two_t,mp_scaled_type);
decNumberFromInt32(math->two_t.data.num,two);
mp_new_number(mp,&math->three_t,mp_scaled_type);
decNumberFromInt32(math->three_t.data.num,three);
mp_new_number(mp,&math->half_unit_t,mp_scaled_type);
decNumberFromString(math->half_unit_t.data.num,"0.5",&set);
mp_new_number(mp,&math->three_quarter_unit_t,mp_scaled_type);
decNumberFromString(math->three_quarter_unit_t.data.num,"0.75",&set);
mp_new_number(mp,&math->zero_t,mp_scaled_type);
decNumberZero(math->zero_t.data.num);

mp_new_number(mp,&math->arc_tol_k,mp_fraction_type);
{
decNumber fourzeroninesix;
decNumberFromInt32(&fourzeroninesix,4096);
decNumberDivide(math->arc_tol_k.data.num,&one,&fourzeroninesix,&set);

}
mp_new_number(mp,&math->fraction_one_t,mp_fraction_type);
decNumberFromInt32(math->fraction_one_t.data.num,fraction_one);
mp_new_number(mp,&math->fraction_half_t,mp_fraction_type);
decNumberFromInt32(math->fraction_half_t.data.num,fraction_half);
mp_new_number(mp,&math->fraction_three_t,mp_fraction_type);
decNumberFromInt32(math->fraction_three_t.data.num,fraction_three);
mp_new_number(mp,&math->fraction_four_t,mp_fraction_type);
decNumberFromInt32(math->fraction_four_t.data.num,fraction_four);

mp_new_number(mp,&math->three_sixty_deg_t,mp_angle_type);
decNumberFromInt32(math->three_sixty_deg_t.data.num,360*angle_multiplier);
mp_new_number(mp,&math->one_eighty_deg_t,mp_angle_type);
decNumberFromInt32(math->one_eighty_deg_t.data.num,180*angle_multiplier);

mp_new_number(mp,&math->one_k,mp_scaled_type);
decNumberFromDouble(math->one_k.data.num,1.0/64);
mp_new_number(mp,&math->sqrt_8_e_k,mp_scaled_type);
{
decNumberFromDouble(math->sqrt_8_e_k.data.num,112428.82793/65536.0);

}
mp_new_number(mp,&math->twelve_ln_2_k,mp_fraction_type);
{
decNumberFromDouble(math->twelve_ln_2_k.data.num,139548959.6165/65536.0);

}
mp_new_number(mp,&math->coef_bound_k,mp_fraction_type);
decNumberFromDouble(math->coef_bound_k.data.num,coef_bound);
mp_new_number(mp,&math->coef_bound_minus_1,mp_fraction_type);
decNumberFromDouble(math->coef_bound_minus_1.data.num,coef_bound-1/65536.0);
mp_new_number(mp,&math->twelvebits_3,mp_scaled_type);
{
decNumberFromDouble(math->twelvebits_3.data.num,1365/65536.0);

}
mp_new_number(mp,&math->twentysixbits_sqrt2_t,mp_fraction_type);
{
decNumberFromDouble(math->twentysixbits_sqrt2_t.data.num,94906265.62/65536.0);

}
mp_new_number(mp,&math->twentyeightbits_d_t,mp_fraction_type);
{
decNumberFromDouble(math->twentyeightbits_d_t.data.num,35596754.69/65536.0);

}
mp_new_number(mp,&math->twentysevenbits_sqrt2_d_t,mp_fraction_type);
{
decNumberFromDouble(math->twentysevenbits_sqrt2_d_t.data.num,25170706.63/65536.0);

}

mp_new_number(mp,&math->fraction_threshold_t,mp_fraction_type);
decNumberFromDouble(math->fraction_threshold_t.data.num,fraction_threshold);
mp_new_number(mp,&math->half_fraction_threshold_t,mp_fraction_type);
decNumberFromDouble(math->half_fraction_threshold_t.data.num,half_fraction_threshold);
mp_new_number(mp,&math->scaled_threshold_t,mp_scaled_type);
decNumberFromDouble(math->scaled_threshold_t.data.num,scaled_threshold);
mp_new_number(mp,&math->half_scaled_threshold_t,mp_scaled_type);
decNumberFromDouble(math->half_scaled_threshold_t.data.num,half_scaled_threshold);
mp_new_number(mp,&math->near_zero_angle_t,mp_angle_type);
decNumberFromDouble(math->near_zero_angle_t.data.num,near_zero_angle);
mp_new_number(mp,&math->p_over_v_threshold_t,mp_fraction_type);
decNumberFromDouble(math->p_over_v_threshold_t.data.num,p_over_v_threshold);
mp_new_number(mp,&math->equation_threshold_t,mp_scaled_type);
decNumberFromDouble(math->equation_threshold_t.data.num,equation_threshold);
mp_new_number(mp,&math->tfm_warn_threshold_t,mp_scaled_type);
decNumberFromDouble(math->tfm_warn_threshold_t.data.num,tfm_warn_threshold);

math->from_int= mp_set_decimal_from_int;
math->from_boolean= mp_set_decimal_from_boolean;
math->from_scaled= mp_set_decimal_from_scaled;
math->from_double= mp_set_decimal_from_double;
math->from_addition= mp_set_decimal_from_addition;
math->from_substraction= mp_set_decimal_from_substraction;
math->from_oftheway= mp_set_decimal_from_of_the_way;
math->from_div= mp_set_decimal_from_div;
math->from_mul= mp_set_decimal_from_mul;
math->from_int_div= mp_set_decimal_from_int_div;
math->from_int_mul= mp_set_decimal_from_int_mul;
math->negate= mp_number_negate;
math->add= mp_number_add;
math->substract= mp_number_substract;
math->half= mp_number_half;
math->halfp= mp_number_halfp;
math->do_double= mp_number_double;
math->abs= mp_decimal_abs;
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
math->fraction_to_round_scaled= mp_decimal_fraction_to_round_scaled;
math->make_scaled= mp_decimal_number_make_scaled;
math->make_fraction= mp_decimal_number_make_fraction;
math->take_fraction= mp_decimal_number_take_fraction;
math->take_scaled= mp_decimal_number_take_scaled;
math->velocity= mp_decimal_velocity;
math->n_arg= mp_decimal_n_arg;
math->m_log= mp_decimal_m_log;
math->m_exp= mp_decimal_m_exp;
math->m_unif_rand= mp_decimal_m_unif_rand;
math->m_norm_rand= mp_decimal_m_norm_rand;
math->pyth_add= mp_decimal_pyth_add;
math->pyth_sub= mp_decimal_pyth_sub;
math->fraction_to_scaled= mp_number_fraction_to_scaled;
math->scaled_to_fraction= mp_number_scaled_to_fraction;
math->scaled_to_angle= mp_number_scaled_to_angle;
math->angle_to_scaled= mp_number_angle_to_scaled;
math->init_randoms= mp_init_randoms;
math->sin_cos= mp_decimal_sin_cos;
math->slow_add= mp_decimal_slow_add;
math->sqrt= mp_decimal_square_rt;
math->print= mp_decimal_print_number;
math->tostring= mp_decimal_number_tostring;
math->modulo= mp_decimal_number_modulo;
math->ab_vs_cd= mp_ab_vs_cd;
math->crossing_point= mp_decimal_crossing_point;
math->scan_numeric= mp_decimal_scan_numeric_token;
math->scan_fractional= mp_decimal_scan_fractional_token;
math->free_math= mp_free_decimal_math;
math->set_precision= mp_decimal_set_precision;
return(void*)math;
}

void mp_decimal_set_precision(MP mp){
int i;
i= decNumberToInt32((decNumber*)internal_value(mp_number_precision).data.num,&set);
set.digits= i;
limitedset.digits= i;
}

void mp_free_decimal_math(MP mp){
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

/*:11*//*13:*/
#line 620 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_new_number(MP mp,mp_number*n,mp_number_type t){
(void)mp;
n->data.num= mp_xmalloc(mp,1,sizeof(decNumber));
decNumberZero(n->data.num);
n->type= t;
}

/*:13*//*14:*/
#line 630 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_free_number(MP mp,mp_number*n){
(void)mp;
free(n->data.num);
n->data.num= NULL;
n->type= mp_nan_type;
}

/*:14*//*15:*/
#line 640 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_set_decimal_from_int(mp_number*A,int B){
decNumberFromInt32(A->data.num,B);
}
void mp_set_decimal_from_boolean(mp_number*A,int B){
decNumberFromInt32(A->data.num,B);
}
void mp_set_decimal_from_scaled(mp_number*A,int B){
decNumber c;
decNumberFromInt32(&c,65536);
decNumberFromInt32(A->data.num,B);
decNumberDivide(A->data.num,A->data.num,&c,&set);
}
void mp_set_decimal_from_double(mp_number*A,double B){
decNumberFromDouble(A->data.num,B);
}
void mp_set_decimal_from_addition(mp_number*A,mp_number B,mp_number C){
decNumberAdd(A->data.num,B.data.num,C.data.num,&set);
}
void mp_set_decimal_from_substraction(mp_number*A,mp_number B,mp_number C){
decNumberSubtract(A->data.num,B.data.num,C.data.num,&set);
}
void mp_set_decimal_from_div(mp_number*A,mp_number B,mp_number C){
decNumberDivide(A->data.num,B.data.num,C.data.num,&set);
}
void mp_set_decimal_from_mul(mp_number*A,mp_number B,mp_number C){
decNumberMultiply(A->data.num,B.data.num,C.data.num,&set);
}
void mp_set_decimal_from_int_div(mp_number*A,mp_number B,int C){
decNumber c;
decNumberFromInt32(&c,C);
decNumberDivide(A->data.num,B.data.num,&c,&set);
}
void mp_set_decimal_from_int_mul(mp_number*A,mp_number B,int C){
decNumber c;
decNumberFromInt32(&c,C);
decNumberMultiply(A->data.num,B.data.num,&c,&set);
}
void mp_set_decimal_from_of_the_way(MP mp,mp_number*A,mp_number t,mp_number B,mp_number C){
decNumber c;
decNumber r1;
decNumberSubtract(&c,B.data.num,C.data.num,&set);
mp_decimal_take_fraction(mp,&r1,&c,t.data.num);
decNumberSubtract(A->data.num,B.data.num,&r1,&set);
mp_check_decNumber(mp,A->data.num,&set);
}
void mp_number_negate(mp_number*A){
decNumberCopyNegate(A->data.num,A->data.num);
checkZero(A->data.num);
}
void mp_number_add(mp_number*A,mp_number B){
decNumberAdd(A->data.num,A->data.num,B.data.num,&set);
}
void mp_number_substract(mp_number*A,mp_number B){
decNumberSubtract(A->data.num,A->data.num,B.data.num,&set);
}
void mp_number_half(mp_number*A){
decNumber c;
decNumberFromInt32(&c,2);
decNumberDivide(A->data.num,A->data.num,&c,&set);
}
void mp_number_halfp(mp_number*A){
decNumber c;
decNumberFromInt32(&c,2);
decNumberDivide(A->data.num,A->data.num,&c,&set);
}
void mp_number_double(mp_number*A){
decNumber c;
decNumberFromInt32(&c,2);
decNumberMultiply(A->data.num,A->data.num,&c,&set);
}
void mp_number_add_scaled(mp_number*A,int B){
decNumber b,c;
decNumberFromInt32(&c,65536);
decNumberFromInt32(&b,B);
decNumberDivide(&b,&b,&c,&set);
decNumberAdd(A->data.num,A->data.num,&b,&set);
}
void mp_number_multiply_int(mp_number*A,int B){
decNumber b;
decNumberFromInt32(&b,B);
decNumberMultiply(A->data.num,A->data.num,&b,&set);
}
void mp_number_divide_int(mp_number*A,int B){
decNumber b;
decNumberFromInt32(&b,B);
decNumberDivide(A->data.num,A->data.num,&b,&set);
}
void mp_decimal_abs(mp_number*A){
decNumberAbs(A->data.num,A->data.num,&set);
}
void mp_number_clone(mp_number*A,mp_number B){
decNumberCopy(A->data.num,B.data.num);
}
void mp_number_swap(mp_number*A,mp_number*B){
decNumber swap_tmp;
decNumberCopy(&swap_tmp,A->data.num);
decNumberCopy(A->data.num,B->data.num);
decNumberCopy(B->data.num,&swap_tmp);
}
void mp_number_fraction_to_scaled(mp_number*A){
A->type= mp_scaled_type;
decNumberDivide(A->data.num,A->data.num,&fraction_multiplier_decNumber,&set);
}
void mp_number_angle_to_scaled(mp_number*A){
A->type= mp_scaled_type;
decNumberDivide(A->data.num,A->data.num,&angle_multiplier_decNumber,&set);
}
void mp_number_scaled_to_fraction(mp_number*A){
A->type= mp_fraction_type;
decNumberMultiply(A->data.num,A->data.num,&fraction_multiplier_decNumber,&set);
}
void mp_number_scaled_to_angle(mp_number*A){
A->type= mp_angle_type;
decNumberMultiply(A->data.num,A->data.num,&angle_multiplier_decNumber,&set);
}


/*:15*//*17:*/
#line 764 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

int mp_number_to_scaled(mp_number A){
int32_t result;
decNumber corrected;
decNumberFromInt32(&corrected,65536);
decNumberMultiply(&corrected,&corrected,A.data.num,&set);
decNumberReduce(&corrected,&corrected,&set);
result= (int)floor(decNumberToDouble(&corrected)+0.5);
return result;
}

/*:17*//*18:*/
#line 779 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

int mp_number_to_int(mp_number A){
int32_t result;
set.status= 0;
result= decNumberToInt32(A.data.num,&set);
if(set.status==DEC_Invalid_operation){
set.status= 0;

return 0;
}else{
return result;
}
}
int mp_number_to_boolean(mp_number A){
uint32_t result;
set.status= 0;
result= decNumberToUInt32(A.data.num,&set);
if(set.status==DEC_Invalid_operation){
set.status= 0;

return mp_false_code;
}else{
return result;
}
}
double mp_number_to_double(mp_number A){
char*buffer= malloc(((decNumber*)A.data.num)->digits+14);
double res= 0.0;
assert(buffer);
decNumberToString(A.data.num,buffer);
if(sscanf(buffer,"%lf",&res)){
free(buffer);
return res;
}else{
free(buffer);

return 0.0;
}
}
int mp_number_odd(mp_number A){
return odd(mp_number_to_int(A));
}
int mp_number_equal(mp_number A,mp_number B){
decNumber res;
decNumberCompare(&res,A.data.num,B.data.num,&set);
return decNumberIsZero(&res);
}
int mp_number_greater(mp_number A,mp_number B){
decNumber res;
decNumberCompare(&res,A.data.num,B.data.num,&set);
return decNumberIsPositive(&res);
}
int mp_number_less(mp_number A,mp_number B){
decNumber res;
decNumberCompare(&res,A.data.num,B.data.num,&set);
return decNumberIsNegative(&res);
}
int mp_number_nonequalabs(mp_number A,mp_number B){
decNumber res,a,b;
decNumberCopyAbs(&a,A.data.num);
decNumberCopyAbs(&b,B.data.num);
decNumberCompare(&res,&a,&b,&set);
return!decNumberIsZero(&res);
}

/*:18*//*21:*/
#line 866 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

char*mp_decnumber_tostring(decNumber*n){
decNumber corrected;
char*buffer= malloc(((decNumber*)n)->digits+14);
assert(buffer);
decNumberCopy(&corrected,n);
decNumberTrim(&corrected);
decNumberToString(&corrected,buffer);
return buffer;
}
char*mp_decimal_number_tostring(MP mp,mp_number n){
return mp_decnumber_tostring(n.data.num);
}


/*:21*//*22:*/
#line 881 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_print_number(MP mp,mp_number n){
char*str= mp_decimal_number_tostring(mp,n);
mp_print(mp,str);
free(str);
}




/*:22*//*23:*/
#line 895 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_slow_add(MP mp,mp_number*ret,mp_number A,mp_number B){
decNumberAdd(ret->data.num,A.data.num,B.data.num,&set);
}

/*:23*//*24:*/
#line 938 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_make_fraction(MP mp,decNumber*ret,decNumber*p,decNumber*q){
decNumberDivide(ret,p,q,&set);
mp_check_decNumber(mp,ret,&set);
decNumberMultiply(ret,ret,&fraction_multiplier_decNumber,&set);
}
void mp_decimal_number_make_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
mp_decimal_make_fraction(mp,ret->data.num,p.data.num,q.data.num);
}

/*:24*//*26:*/
#line 961 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_take_fraction(MP mp,decNumber*ret,decNumber*p,decNumber*q){
decNumberMultiply(ret,p,q,&set);
decNumberDivide(ret,ret,&fraction_multiplier_decNumber,&set);
}
void mp_decimal_number_take_fraction(MP mp,mp_number*ret,mp_number p,mp_number q){
mp_decimal_take_fraction(mp,ret->data.num,p.data.num,q.data.num);
}

/*:26*//*28:*/
#line 983 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_number_take_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
decNumberMultiply(ret->data.num,p_orig.data.num,q_orig.data.num,&set);
}


/*:28*//*29:*/
#line 995 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_number_make_scaled(MP mp,mp_number*ret,mp_number p_orig,mp_number q_orig){
decNumberDivide(ret->data.num,p_orig.data.num,q_orig.data.num,&set);
mp_check_decNumber(mp,ret->data.num,&set);
}

/*:29*//*32:*/
#line 1017 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_wrapup_numeric_token(MP mp,unsigned char*start,unsigned char*stop){
decNumber result;
size_t l= stop-start+1;
char*buf= mp_xmalloc(mp,l+1,1);
buf[l]= '\0';
(void)strncpy(buf,(const char*)start,l);
set.status= 0;
decNumberFromString(&result,buf,&set);
free(buf);
if(set.status==0){
set_cur_mod(result);
}else if(mp->scanner_status!=tex_flushing){
if(too_large(set.status)){
const char*hlp[]= {"I could not handle this number specification",
"because it is out of range.",
NULL};
decNumber_check(&result,&set);
set_cur_mod(result);
mp_error(mp,"Enormous number has been reduced",hlp,false);
}else if(too_precise(set.status)){
set_cur_mod(result);
if(decNumberIsPositive((decNumber*)internal_value(mp_warning_check).data.num)&&
(mp->scanner_status!=tex_flushing)){
char msg[256];
const char*hlp[]= {"Continue and I'll round the value until it fits the current numberprecision",
"(Set warningcheck:=0 to suppress this message.)",
NULL};
mp_snprintf(msg,256,"Number is too precise (numberprecision = %d)",set.digits);
mp_error(mp,msg,hlp,true);
}
}else{
const char*hlp[]= {"I could not handle this number specification",
"Error:",
"",
NULL};
hlp[2]= decContextStatusToString(&set);
mp_error(mp,"Erroneous number specification changed to zero",hlp,false);
decNumberZero(&result);
set_cur_mod(result);
}
}
set_cur_cmd((mp_variable_type)mp_numeric_token);
}

/*:32*//*33:*/
#line 1062 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

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
void mp_decimal_scan_fractional_token(MP mp,int n){
unsigned char*start= &mp->buffer[mp->cur_input.loc_field-1];
unsigned char*stop;
while(mp->char_class[mp->buffer[mp->cur_input.loc_field]]==digit_class){
mp->cur_input.loc_field++;
}
find_exponent(mp);
stop= &mp->buffer[mp->cur_input.loc_field-1];
mp_wrapup_numeric_token(mp,start,stop);
}


/*:33*//*34:*/
#line 1096 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_scan_numeric_token(MP mp,int n){
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

/*:34*//*36:*/
#line 1149 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_velocity(MP mp,mp_number*ret,mp_number st,mp_number ct,mp_number sf,
mp_number cf,mp_number t){
decNumber acc,num,denom;
decNumber r1,r2;
decNumber arg1,arg2;
decNumber i16,fone,fhalf,ftwo,sqrtfive;
decNumberFromInt32(&i16,16);
decNumberFromInt32(&fone,fraction_one);
decNumberFromInt32(&fhalf,fraction_half);
decNumberFromInt32(&ftwo,fraction_two);
decNumberFromInt32(&sqrtfive,5);
decNumberSquareRoot(&sqrtfive,&sqrtfive,&set);


decNumberDivide(&arg1,sf.data.num,&i16,&set);
decNumberSubtract(&arg1,st.data.num,&arg1,&set);
decNumberDivide(&arg2,st.data.num,&i16,&set);
decNumberSubtract(&arg2,sf.data.num,&arg2,&set);
mp_decimal_take_fraction(mp,&acc,&arg1,&arg2);

decNumberCopy(&arg1,&acc);
decNumberSubtract(&arg2,ct.data.num,cf.data.num,&set);
mp_decimal_take_fraction(mp,&acc,&arg1,&arg2);

decNumberSquareRoot(&arg1,&two_decNumber,&set);
decNumberMultiply(&arg1,&arg1,&fone,&set);
mp_decimal_take_fraction(mp,&r1,&acc,&arg1);
decNumberAdd(&num,&ftwo,&r1,&set);

decNumberSubtract(&arg1,&sqrtfive,&one,&set);
decNumberMultiply(&arg1,&arg1,&fhalf,&set);
decNumberMultiply(&arg1,&arg1,&three_decNumber,&set);

decNumberSubtract(&arg2,&three_decNumber,&sqrtfive,&set);
decNumberMultiply(&arg2,&arg2,&fhalf,&set);
decNumberMultiply(&arg2,&arg2,&three_decNumber,&set);
mp_decimal_take_fraction(mp,&r1,ct.data.num,&arg1);
mp_decimal_take_fraction(mp,&r2,cf.data.num,&arg2);

decNumberFromInt32(&denom,fraction_three);
decNumberAdd(&denom,&denom,&r1,&set);
decNumberAdd(&denom,&denom,&r2,&set);

decNumberCompare(&arg1,t.data.num,&one,&set);
if(!decNumberIsZero(&arg1)){
decNumberDivide(&num,&num,t.data.num,&set);
}
decNumberCopy(&r2,&num);
decNumberDivide(&r2,&r2,&four_decNumber,&set);
if(decNumberLess(&denom,&r2)){
decNumberFromInt32(ret->data.num,fraction_four);
}else{
mp_decimal_make_fraction(mp,ret->data.num,&num,&denom);
}
#if DEBUG
fprintf(stdout,"\n%f = velocity(%f,%f,%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(st),mp_number_to_double(ct),
mp_number_to_double(sf),mp_number_to_double(cf),
mp_number_to_double(t));
#endif
mp_check_decNumber(mp,ret->data.num,&set);
}


/*:36*//*37:*/
#line 1219 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_ab_vs_cd(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
decNumber q,r,test;
decNumber a,b,c,d;
decNumber ab,cd;
(void)mp;
decNumberCopy(&a,(decNumber*)a_orig.data.num);
decNumberCopy(&b,(decNumber*)b_orig.data.num);
decNumberCopy(&c,(decNumber*)c_orig.data.num);
decNumberCopy(&d,(decNumber*)d_orig.data.num);

decNumberMultiply(&ab,(decNumber*)a_orig.data.num,(decNumber*)b_orig.data.num,&set);
decNumberMultiply(&cd,(decNumber*)c_orig.data.num,(decNumber*)d_orig.data.num,&set);
decNumberCompare(ret->data.num,&ab,&cd,&set);
mp_check_decNumber(mp,ret->data.num,&set);
if(1> 0)
return;


/*38:*/
#line 1281 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

if(decNumberIsNegative(&a)){
decNumberCopyNegate(&a,&a);
decNumberCopyNegate(&b,&b);
}
if(decNumberIsNegative(&c)){
decNumberCopyNegate(&c,&c);
decNumberCopyNegate(&d,&d);
}
if(!decNumberIsPositive(&d)){
if(!decNumberIsNegative(&b)){
if((decNumberIsZero(&a)||decNumberIsZero(&b))&&(decNumberIsZero(&c)||decNumberIsZero(&d)))
decNumberCopy(ret->data.num,&zero);
else
decNumberCopy(ret->data.num,&one);
goto RETURN;
}
if(decNumberIsZero(&d)){
if(decNumberIsZero(&a))
decNumberCopy(ret->data.num,&zero);
else
decNumberCopy(ret->data.num,&minusone);
goto RETURN;
}
decNumberCopy(&q,&a);
decNumberCopy(&a,&c);
decNumberCopy(&c,&q);
decNumberCopyNegate(&q,&b);
decNumberCopyNegate(&b,&d);
decNumberCopy(&d,&q);
}else if(!decNumberIsPositive(&b)){
if(decNumberIsNegative(&b)&&decNumberIsPositive(&a)){
decNumberCopy(ret->data.num,&minusone);
goto RETURN;
}
if(decNumberIsZero(&c))
decNumberCopy(ret->data.num,&zero);
else
decNumberCopy(ret->data.num,&minusone);
goto RETURN;
}

/*:38*/
#line 1238 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"
;
while(1){
decNumberDivide(&q,&a,&d,&set);
decNumberDivide(&r,&c,&b,&set);
decNumberCompare(&test,&q,&r,&set);
if(!decNumberIsZero(&test)){
if(decNumberIsPositive(&test)){
decNumberCopy(ret->data.num,&one);
}else{
decNumberCopy(ret->data.num,&minusone);
}
goto RETURN;
}
decNumberRemainder(&q,&a,&d,&set);
decNumberRemainder(&r,&c,&b,&set);
if(decNumberIsZero(&r)){
if(decNumberIsZero(&q)){
decNumberCopy(ret->data.num,&zero);
}else{
decNumberCopy(ret->data.num,&one);
}
goto RETURN;
}
if(decNumberIsZero(&q)){
decNumberCopy(ret->data.num,&minusone);
goto RETURN;
}
decNumberCopy(&a,&b);
decNumberCopy(&b,&q);
decNumberCopy(&c,&d);
decNumberCopy(&d,&r);
}
RETURN:
#if DEBUG
fprintf(stdout,"\n%f = ab_vs_cd(%f,%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(a_orig),mp_number_to_double(b_orig),
mp_number_to_double(c_orig),mp_number_to_double(d_orig));
#endif
mp_check_decNumber(mp,ret->data.num,&set);
return;
}


/*:37*//*39:*/
#line 1356 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void mp_decimal_crossing_point(MP mp,mp_number*ret,mp_number aa,mp_number bb,mp_number cc){
decNumber a,b,c;
double d;
decNumber x,xx,x0,x1,x2;
decNumber scratch,scratch2;
decNumberCopy(&a,(decNumber*)aa.data.num);
decNumberCopy(&b,(decNumber*)bb.data.num);
decNumberCopy(&c,(decNumber*)cc.data.num);
if(decNumberIsNegative(&a))
zero_crossing;
if(!decNumberIsNegative(&c)){
if(!decNumberIsNegative(&b)){
if(decNumberIsPositive(&c)){
no_crossing;
}else if(decNumberIsZero(&a)&&decNumberIsZero(&b)){
no_crossing;
}else{
one_crossing;
}
}
if(decNumberIsZero(&a))
zero_crossing;
}else if(decNumberIsZero(&a)){
if(!decNumberIsPositive(&b))
zero_crossing;
}


d= epsilonf;
decNumberCopy(&x0,&a);
decNumberSubtract(&x1,&a,&b,&set);
decNumberSubtract(&x2,&b,&c,&set);

decNumberFromDouble(&scratch2,1E-12);
do{
decNumberAdd(&x,&x1,&x2,&set);
decNumberDivide(&x,&x,&two_decNumber,&set);
decNumberAdd(&x,&x,&scratch2,&set);
decNumberSubtract(&scratch,&x1,&x0,&set);
if(decNumberGreater(&scratch,&x0)){
decNumberCopy(&x2,&x);
decNumberAdd(&x0,&x0,&x0,&set);
d+= d;
}else{
decNumberAdd(&xx,&scratch,&x,&set);
if(decNumberGreater(&xx,&x0)){
decNumberCopy(&x2,&x);
decNumberAdd(&x0,&x0,&x0,&set);
d+= d;
}else{
decNumberSubtract(&x0,&x0,&xx,&set);
if(!decNumberGreater(&x,&x0)){
decNumberAdd(&scratch,&x,&x2,&set);
if(!decNumberGreater(&scratch,&x0))
no_crossing;
}
decNumberCopy(&x1,&x);
d= d+d+epsilonf;
}
}
}while(d<fraction_one);
decNumberFromDouble(&scratch,d);
decNumberSubtract(ret->data.num,&scratch,&fraction_one_decNumber,&set);
RETURN:
#if DEBUG
fprintf(stdout,"\n%f = crossing_point(%f,%f,%f)",mp_number_to_double(*ret),
mp_number_to_double(aa),mp_number_to_double(bb),mp_number_to_double(cc));
#endif
mp_check_decNumber(mp,ret->data.num,&set);
return;
}


/*:39*//*41:*/
#line 1435 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

int mp_round_unscaled(mp_number x_orig){
double xx= mp_number_to_double(x_orig);
int x= (int)ROUND(xx);
return x;
}

/*:41*//*42:*/
#line 1444 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_number_floor(mp_number*i){
int round= set.round;
set.round= DEC_ROUND_FLOOR;
decNumberToIntegralValue(i->data.num,i->data.num,&set);
set.round= round;
}

/*:42*//*43:*/
#line 1453 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_fraction_to_round_scaled(mp_number*x_orig){
x_orig->type= mp_scaled_type;
decNumberDivide(x_orig->data.num,x_orig->data.num,&fraction_multiplier_decNumber,&set);
}



/*:43*//*45:*/
#line 1467 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_square_rt(MP mp,mp_number*ret,mp_number x_orig){
decNumber x;
decNumberCopy(&x,x_orig.data.num);
if(!decNumberIsPositive(&x)){
/*46:*/
#line 1480 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

{
if(decNumberIsNegative(&x)){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*xstr= mp_decimal_number_tostring(mp,x_orig);
mp_snprintf(msg,256,"Square root of %s has been replaced by 0",xstr);
free(xstr);
;
mp_error(mp,msg,hlp,true);
}
decNumberZero(ret->data.num);
return;
}


/*:46*/
#line 1472 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"
;
}else{
decNumberSquareRoot(ret->data.num,&x,&set);
}
mp_check_decNumber(mp,ret->data.num,&set);
}


/*:45*//*47:*/
#line 1501 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_pyth_add(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
decNumber a,b;
decNumber asq,bsq;
decNumberCopyAbs(&a,a_orig.data.num);
decNumberCopyAbs(&b,b_orig.data.num);
decNumberMultiply(&asq,&a,&a,&set);
decNumberMultiply(&bsq,&b,&b,&set);
decNumberAdd(&a,&asq,&bsq,&set);
decNumberSquareRoot(ret->data.num,&a,&set);




mp_check_decNumber(mp,ret->data.num,&set);
}

/*:47*//*48:*/
#line 1520 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_pyth_sub(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig){
decNumber a,b;
decNumberCopyAbs(&a,a_orig.data.num);
decNumberCopyAbs(&b,b_orig.data.num);
if(!decNumberGreater(&a,&b)){
/*49:*/
#line 1539 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

{
if(decNumberLess(&a,&b)){
char msg[256];
const char*hlp[]= {
"Since I don't take square roots of negative numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*astr= mp_decimal_number_tostring(mp,a_orig);
char*bstr= mp_decimal_number_tostring(mp,b_orig);
mp_snprintf(msg,256,"Pythagorean subtraction %s+-+%s has been replaced by 0",astr,bstr);
free(astr);
free(bstr);
;
mp_error(mp,msg,hlp,true);
}
decNumberZero(&a);
}


/*:49*/
#line 1526 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"
;
}else{
decNumber asq,bsq;
decNumberMultiply(&asq,&a,&a,&set);
decNumberMultiply(&bsq,&b,&b,&set);
decNumberSubtract(&a,&asq,&bsq,&set);
decNumberSquareRoot(&a,&a,&set);
}
decNumberCopy(ret->data.num,&a);
mp_check_decNumber(mp,ret->data.num,&set);
}


/*:48*//*50:*/
#line 1562 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_m_log(MP mp,mp_number*ret,mp_number x_orig){
if(!decNumberIsPositive((decNumber*)x_orig.data.num)){
/*51:*/
#line 1576 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

{
char msg[256];
const char*hlp[]= {
"Since I don't take logs of non-positive numbers,",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
char*xstr= mp_decimal_number_tostring(mp,x_orig);
mp_snprintf(msg,256,"Logarithm of %s has been replaced by 0",xstr);
free(xstr);
;
mp_error(mp,msg,hlp,true);
decNumberZero(ret->data.num);
}


/*:51*/
#line 1565 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"
;
}else{
decNumber twofivesix;
decNumberFromInt32(&twofivesix,256);
decNumberLn(ret->data.num,x_orig.data.num,&limitedset);
mp_check_decNumber(mp,ret->data.num,&limitedset);
decNumberMultiply(ret->data.num,ret->data.num,&twofivesix,&set);
}
mp_check_decNumber(mp,ret->data.num,&set);
}

/*:50*//*52:*/
#line 1595 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_m_exp(MP mp,mp_number*ret,mp_number x_orig){
decNumber temp,twofivesix;
decNumberFromInt32(&twofivesix,256);
decNumberDivide(&temp,x_orig.data.num,&twofivesix,&set);
limitedset.status= 0;
decNumberExp(ret->data.num,&temp,&limitedset);
if(limitedset.status&DEC_Clamped){
if(decNumberIsPositive((decNumber*)x_orig.data.num)){
mp->arith_error= true;
decNumberCopy(ret->data.num,&EL_GORDO_decNumber);
}else{
decNumberZero(ret->data.num);
}
}
mp_check_decNumber(mp,ret->data.num,&limitedset);
limitedset.status= 0;
}


/*:52*//*53:*/
#line 1618 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_n_arg(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig){
if(decNumberIsZero((decNumber*)x_orig.data.num)&&decNumberIsZero((decNumber*)y_orig.data.num)){
/*54:*/
#line 1644 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

{
const char*hlp[]= {
"The `angle' between two identical points is undefined.",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_error(mp,"angle(0,0) is taken as zero",hlp,true);
;
decNumberZero(ret->data.num);
}


/*:54*/
#line 1621 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"
;
}else{
decNumber atan2val,oneeighty_angle;
ret->type= mp_angle_type;
decNumberFromInt32(&oneeighty_angle,180*angle_multiplier);
decNumberDivide(&oneeighty_angle,&oneeighty_angle,&PI_decNumber,&set);
checkZero(y_orig.data.num);
checkZero(x_orig.data.num);
decNumberAtan2(&atan2val,y_orig.data.num,x_orig.data.num,&set);
#if DEBUG
fprintf(stdout,"\n%g = atan2(%g,%g)",decNumberToDouble(&atan2val),mp_number_to_double(x_orig),mp_number_to_double(y_orig));
#endif
decNumberMultiply(ret->data.num,&atan2val,&oneeighty_angle,&set);
checkZero(ret->data.num);
#if DEBUG
fprintf(stdout,"\nn_arg(%g,%g,%g)",mp_number_to_double(*ret),
mp_number_to_double(x_orig),mp_number_to_double(y_orig));
#endif
}
mp_check_decNumber(mp,ret->data.num,&set);
}


/*:53*//*55:*/
#line 1665 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void sinecosine(decNumber*theangle,decNumber*c,decNumber*s)
{
int n,i,prec;
decNumber p,pxa,fac,cc;
decNumber n1,n2,p1;
decNumberZero(c);
decNumberZero(s);
prec= (set.digits/2);
if(prec<DECPRECISION_DEFAULT)prec= DECPRECISION_DEFAULT;
for(n= 0;n<prec;n++)
{
decNumberFromInt32(&p1,n);
decNumberFromInt32(&n1,2*n);
decNumberPower(&p,&minusone,&p1,&limitedset);
if(n==0){
decNumberCopy(&pxa,&one);
}else{
decNumberPower(&pxa,theangle,&n1,&limitedset);
}

if(2*n<last_cached_factorial){
decNumberCopy(&fac,factorials[2*n]);
}else{
decNumberCopy(&fac,factorials[last_cached_factorial]);
for(i= last_cached_factorial+1;i<=2*n;i++){
decNumberFromInt32(&cc,i);
decNumberMultiply(&fac,&fac,&cc,&set);
if(i<PRECALC_FACTORIALS_CACHESIZE){
factorials[i]= malloc(sizeof(decNumber));
decNumberCopy(factorials[i],&fac);
last_cached_factorial= i;
}
}
}

decNumberDivide(&pxa,&pxa,&fac,&set);
decNumberMultiply(&pxa,&pxa,&p,&set);
decNumberAdd(s,s,&pxa,&set);

decNumberFromInt32(&n2,2*n+1);
decNumberMultiply(&fac,&fac,&n2,&set);
decNumberPower(&pxa,theangle,&n2,&limitedset);
decNumberDivide(&pxa,&pxa,&fac,&set);
decNumberMultiply(&pxa,&pxa,&p,&set);
decNumberAdd(c,c,&pxa,&set);

}
}

/*:55*//*56:*/
#line 1716 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_sin_cos(MP mp,mp_number z_orig,mp_number*n_cos,mp_number*n_sin){
decNumber rad;
double tmp;
decNumber one_eighty;
tmp= mp_number_to_double(z_orig)/16.0;

#if DEBUG
fprintf(stdout,"\nsin_cos(%f)",mp_number_to_double(z_orig));
#endif
#if 0
if(decNumberIsNegative(&rad)){
while(decNumberLess(&rad,&PI_decNumber))
decNumberAdd(&rad,&rad,&PI_decNumber,&set);
}else{
while(decNumberGreater(&rad,&PI_decNumber))
decNumberSubtract(&rad,&rad,&PI_decNumber,&set);
}
#endif
if((tmp==90.0)||(tmp==-270)){
decNumberZero(n_cos->data.num);
decNumberCopy(n_sin->data.num,&fraction_multiplier_decNumber);
}else if((tmp==-90.0)||(tmp==270.0)){
decNumberZero(n_cos->data.num);
decNumberCopyNegate(n_sin->data.num,&fraction_multiplier_decNumber);
}else if((tmp==180.0)||(tmp==-180.0)){
decNumberCopyNegate(n_cos->data.num,&fraction_multiplier_decNumber);
decNumberZero(n_sin->data.num);
}else{
decNumberFromInt32(&one_eighty,180*16);
decNumberMultiply(&rad,z_orig.data.num,&PI_decNumber,&set);
decNumberDivide(&rad,&rad,&one_eighty,&set);
sinecosine(&rad,n_sin->data.num,n_cos->data.num);
decNumberMultiply(n_cos->data.num,n_cos->data.num,&fraction_multiplier_decNumber,&set);
decNumberMultiply(n_sin->data.num,n_sin->data.num,&fraction_multiplier_decNumber,&set);
}
#if DEBUG
fprintf(stdout,"\nsin_cos(%f,%f,%f)",decNumberToDouble(&rad),
mp_number_to_double(*n_cos),mp_number_to_double(*n_sin));
#endif
mp_check_decNumber(mp,n_cos->data.num,&set);
mp_check_decNumber(mp,n_sin->data.num,&set);
}

/*:56*//*57:*/
#line 1763 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

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



/*:57*//*58:*/
#line 1837 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

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
decNumberFromInt32(mp->randoms[(i*21)%55].data.num,j);
}
mp_new_randoms(mp);
mp_new_randoms(mp);
mp_new_randoms(mp);

ran_start((unsigned long)seed);

}

/*:58*//*59:*/
#line 1862 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

void mp_decimal_number_modulo(mp_number*a,mp_number b){
decNumberRemainder(a->data.num,a->data.num,b.data.num,&set);
}


/*:59*//*60:*/
#line 1870 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void mp_next_unif_random(MP mp,mp_number*ret){
decNumber a;
decNumber b;
unsigned long int op;
(void)mp;
op= (unsigned)ran_arr_next();
decNumberFromInt32(&a,op);
decNumberFromInt32(&b,MM);
decNumberDivide(&a,&a,&b,&set);
decNumberCopy(ret->data.num,&a);
mp_check_decNumber(mp,ret->data.num,&set);
}


/*:60*//*61:*/
#line 1887 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void mp_next_random(MP mp,mp_number*ret){
if(mp->j_random==0)
mp_new_randoms(mp);
else
mp->j_random= mp->j_random-1;
mp_number_clone(ret,mp->randoms[mp->j_random]);
}


/*:61*//*62:*/
#line 1904 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void mp_decimal_m_unif_rand(MP mp,mp_number*ret,mp_number x_orig){
mp_number y;
mp_number x,abs_x;
mp_number u;
new_fraction(y);
new_number(x);
new_number(abs_x);
new_number(u);
mp_number_clone(&x,x_orig);
mp_number_clone(&abs_x,x);
mp_decimal_abs(&abs_x);
mp_next_unif_random(mp,&u);
decNumberMultiply(y.data.num,abs_x.data.num,u.data.num,&set);
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



/*:62*//*63:*/
#line 1938 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"

static void mp_decimal_m_norm_rand(MP mp,mp_number*ret){
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
mp_decimal_number_take_fraction(mp,&xa,((math_data*)mp->math)->sqrt_8_e_k,v);
free_number(v);
mp_next_random(mp,&u);
mp_number_clone(&abs_x,xa);
mp_decimal_abs(&abs_x);
}while(!mp_number_less(abs_x,u));
mp_decimal_number_make_fraction(mp,&r,xa,u);
mp_number_clone(&xa,r);
mp_decimal_m_log(mp,&la,u);
mp_set_decimal_from_substraction(&la,((math_data*)mp->math)->twelve_ln_2_k,la);
mp_ab_vs_cd(mp,&ab_vs_cd,((math_data*)mp->math)->one_k,la,xa,xa);
}while(mp_number_less(ab_vs_cd,((math_data*)mp->math)->zero_t));
mp_number_clone(ret,xa);
free_number(ab_vs_cd);
free_number(r);
free_number(abs_x);
free_number(la);
free_number(xa);
free_number(u);
}




/*:63*//*64:*/
#line 1988 "../../../source/texk/web2c/mplibdir/mpmathdecimal.w"























/*:64*/
