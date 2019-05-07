/*5:*/
#line 155 "../../../source/texk/web2c/mplibdir/mp.w"


#ifdef DEBUGENVELOPE
static int DEBUGENVELOPECOUNTER= 0;
#define dbg_str(A)   printf("\n--[==[%03d DEBUGENVELOPE ]==] %s",     DEBUGENVELOPECOUNTER++, #A)
#define dbg_n(A)    printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']=%s, ",    DEBUGENVELOPECOUNTER++, #A, number_tostring(A))
#define dbg_in(A)    printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']=%d, ",    DEBUGENVELOPECOUNTER++, #A, (int)(A))
#define dbg_dn(A)    printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']=%.100f, ",DEBUGENVELOPECOUNTER++, #A, (double)(A))
#define dbg_key(A)    printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']= ",    DEBUGENVELOPECOUNTER++, #A)
#define dbg_key_nval(K,V) printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']=%s",    DEBUGENVELOPECOUNTER++, #K,number_tostring(V))
#define dbg_key_ival(K,V) printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']=%d",    DEBUGENVELOPECOUNTER++, #K,(int)(V))
#define dbg_key_dval(K,V) printf("\n--[==[%03d DEBUGENVELOPE ]==] ['%s']=%.100f",  DEBUGENVELOPECOUNTER++, #K,(double)(V))
#define dbg_comment(A)    printf("\n--[==[%03d DEBUGENVELOPE ]==] --[==[%s]==]",   DEBUGENVELOPECOUNTER++, #A)
#define dbg_sp     printf("\n--[==[%03d DEBUGENVELOPE ]==]  ",       DEBUGENVELOPECOUNTER++)
#define dbg_open_t    printf("\n--[==[%03d DEBUGENVELOPE ]==] {",       DEBUGENVELOPECOUNTER++)
#define dbg_close_t    printf("\n--[==[%03d DEBUGENVELOPE ]==] }",       DEBUGENVELOPECOUNTER++)
#define dbg_comma    printf("\n--[==[%03d DEBUGENVELOPE ]==] ,",       DEBUGENVELOPECOUNTER++)
#define dbg_nl     printf("\n--[==[%03d DEBUGENVELOPE ]==] \n",       DEBUGENVELOPECOUNTER++)
#define dbg_CUBIC         dbg_n(p->x_coord); dbg_n(p->y_coord); \
     dbg_n(p->right_x); dbg_n(p->right_y); \
     dbg_n(q->left_x);  dbg_n(q->left_y);  \
     dbg_n(q->x_coord); dbg_n(q->y_coord)
#endif
#define KPATHSEA_DEBUG_H 1
#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <assert.h>
#include <math.h>
#ifdef HAVE_UNISTD_H
#  include <unistd.h>
#endif
#include <time.h>
/* #include <zlib.h> */
/* #include <png.h>  */

#include "mplib.h"
#include "mplibps.h"


#include "mpmp.h"
#include "mppsout.h"


#include "mpmath.h"
#include "mpmathdouble.h"
#include "mpmathdecimal.h"

#include "mpstrings.h"

mp_number dx_ap;
mp_number dy_ap;
mp_number dxin_ap;
mp_number dyin_ap;
mp_number ueps_ap;
boolean is_dxdy,is_dxindyin;


/*:5*//*6:*/
#line 221 "../../../source/texk/web2c/mplibdir/mp.w"

extern const char*COMPILED_CAIRO_VERSION_STRING;
extern const char*cairo_version_string(void);
extern const char*COMPILED_MPFR_VERSION_STRING;
extern const char*mpfr_get_version(void);
extern void*mp_initialize_binary_math(MP mp);
extern int COMPILED__GNU_MP_VERSION;
extern int COMPILED__GNU_MP_VERSION_MINOR;
extern int COMPILED__GNU_MP_VERSION_PATCHLEVEL;
extern const char*const COMPILED_gmp_version;
extern const char*COMPILED_PIXMAN_VERSION_STRING;
extern const char*pixman_version_string(void);
extern void mp_png_backend_initialize(MP mp);
extern void mp_png_backend_free(MP mp);
extern int mp_png_gr_ship_out(void*hh,const char*options,int standalone);
extern int mp_png_ship_out(void*hh,const char*options);
extern void mp_svg_backend_initialize(MP mp);
extern void mp_svg_backend_free(MP mp);
extern int mp_svg_ship_out(mp_edge_object*hh,int prologues);
extern int mp_svg_gr_ship_out(mp_edge_object*hh,int prologues,int standalone);

/*:6*//*7:*/
#line 242 "../../../source/texk/web2c/mplibdir/mp.w"

extern font_number mp_read_font_info(MP mp,char*fname);
#define default_banner "This is MetaPost, Version 2.00"
#define true 1
#define false 0 \

#define set_callback_option(A) do{mp->A= mp_##A; \
if(opt->A!=NULL) mp->A= opt->A; \
}while(0)  \

#define set_lower_limited_value(a,b,c) do{a= c;if(b> c) a= b;}while(0)  \

#define incr(A) (A) = (A) +1
#define decr(A) (A) = (A) -1
#define negate(A) (A) = -(A)
#define double(A) (A) = (A) +(A)
#define odd(A) (abs(A) %2==1)  \

#define long_name mp->cur_input.long_name_field \

#define t_open_out() do{ \
mp->term_out= (mp->open_file) (mp,"terminal","w",mp_filetype_terminal) ; \
mp->err_out= (mp->open_file) (mp,"error","w",mp_filetype_error) ; \
}while(0)
#define t_open_in() do{ \
mp->term_in= (mp->open_file) (mp,"terminal","r",mp_filetype_terminal) ; \
if(mp->command_line!=NULL) { \
mp->last= strlen(mp->command_line) ; \
if(mp->last> (mp->buf_size+1) ) { \
mp_reallocate_buffer(mp,mp->last) ; \
} \
(void) memcpy((void*) mp->buffer,(void*) mp->command_line,mp->last) ; \
xfree(mp->command_line) ; \
}else{ \
mp->last= 0; \
} \
}while(0)  \

#define loc mp->cur_input.loc_field \

#define new_string 0
#define pseudo 2
#define no_print 3
#define term_only 4
#define log_only 5
#define term_and_log 6
#define write_file 7 \

#define mp_print_text(A) mp_print_str(mp,text((A) ) )  \

#define prompt_input(A) do{ \
if(!mp->noninteractive) { \
wake_up_terminal() ; \
mp_print(mp,(A) ) ; \
} \
mp_term_input(mp) ; \
}while(0)  \

#define initialize_print_selector() mp->selector= (mp->interaction==mp_batch_mode?no_print:term_only) ; \

#define check_interrupt {if(mp->interrupt!=0)  \
mp_pause_for_instructions(mp) ;} \

#define inf_t ((math_data*) mp->math) ->inf_t \

#define check_arith() do{ \
if(mp->arith_error)  \
mp_clear_arith(mp) ; \
}while(0)  \

#define arc_tol_k ((math_data*) mp->math) ->arc_tol_k
#define coef_bound_k ((math_data*) mp->math) ->coef_bound_k
#define coef_bound_minus_1 ((math_data*) mp->math) ->coef_bound_minus_1
#define sqrt_8_e_k ((math_data*) mp->math) ->sqrt_8_e_k
#define twelve_ln_2_k ((math_data*) mp->math) ->twelve_ln_2_k
#define twelvebits_3 ((math_data*) mp->math) ->twelvebits_3
#define one_k ((math_data*) mp->math) ->one_k
#define epsilon_t ((math_data*) mp->math) ->epsilon_t
#define unity_t ((math_data*) mp->math) ->unity_t
#define zero_t ((math_data*) mp->math) ->zero_t
#define two_t ((math_data*) mp->math) ->two_t
#define three_t ((math_data*) mp->math) ->three_t
#define half_unit_t ((math_data*) mp->math) ->half_unit_t
#define three_quarter_unit_t ((math_data*) mp->math) ->three_quarter_unit_t
#define twentysixbits_sqrt2_t ((math_data*) mp->math) ->twentysixbits_sqrt2_t
#define twentyeightbits_d_t ((math_data*) mp->math) ->twentyeightbits_d_t
#define twentysevenbits_sqrt2_d_t ((math_data*) mp->math) ->twentysevenbits_sqrt2_d_t
#define warning_limit_t ((math_data*) mp->math) ->warning_limit_t
#define precision_default ((math_data*) mp->math) ->precision_default
#define precision_max ((math_data*) mp->math) ->precision_max
#define precision_min ((math_data*) mp->math) ->precision_min \

#define fraction_one_t ((math_data*) mp->math) ->fraction_one_t
#define fraction_half_t ((math_data*) mp->math) ->fraction_half_t
#define fraction_three_t ((math_data*) mp->math) ->fraction_three_t
#define fraction_four_t ((math_data*) mp->math) ->fraction_four_t \

#define one_eighty_deg_t ((math_data*) mp->math) ->one_eighty_deg_t
#define three_sixty_deg_t ((math_data*) mp->math) ->three_sixty_deg_t \

#define max_quarterword 0x3FFF
#define max_halfword 0xFFFFFFF \

#define qo(A) (A)
#define qi(A) (quarterword) (A)  \

#define xfree(A) do{mp_xfree(A) ;A= NULL;}while(0)
#define xrealloc(P,A,B) mp_xrealloc(mp,P,(size_t) A,B)
#define xmalloc(A,B) mp_xmalloc(mp,(size_t) A,B)
#define xstrdup(A) mp_xstrdup(mp,A)
#define XREALLOC(a,b,c) a= xrealloc(a,(b+1) ,sizeof(c) ) ; \

#define max_num_token_nodes 1000
#define max_num_pair_nodes 1000
#define max_num_knot_nodes 1000
#define max_num_value_nodes 1000
#define max_num_symbolic_nodes 1000 \

#define malloc_node(A) do_alloc_node(mp,(A) )  \

#define max_size_test 0x7FFFFFFF \

#define MP_VOID (mp_node) (1)  \

#define mp_link(A) (A) ->link
#define set_mp_link(A,B) do{ \
mp_node d= (B) ; \
 \
mp_link((A) ) = d; \
}while(0)
#define mp_type(A) (A) ->type
#define mp_name_type(A) (A) ->name_type \

#define add_var_used(a) do{ \
mp->var_used+= (a) ; \
if(mp->var_used> mp->var_used_max) mp->var_used_max= mp->var_used; \
}while(0)  \

#define symbolic_node_size sizeof(mp_node_data)
#define mp_max_command_code mp_stop
#define mp_max_pre_command mp_mpx_break
#define mp_min_command (mp_defined_macro+1)
#define mp_max_statement_command mp_type_name
#define mp_min_primary_command mp_type_name
#define mp_min_suffix_token mp_internal_quantity
#define mp_max_suffix_token mp_numeric_token
#define mp_max_primary_command mp_plus_or_minus
#define mp_min_tertiary_command mp_plus_or_minus
#define mp_max_tertiary_command mp_tertiary_binary
#define mp_min_expression_command mp_left_brace
#define mp_max_expression_command mp_equals
#define mp_min_secondary_command mp_and_command
#define mp_max_secondary_command mp_secondary_binary
#define mp_end_of_statement (cur_cmd() > mp_comma)  \
 \

#define unknown_tag 1
#define unknown_types mp_unknown_boolean:case mp_unknown_string: \
case mp_unknown_pen:case mp_unknown_picture:case mp_unknown_path \

#define mp_min_of mp_substring_of \

#define max_given_internal mp_gtroffmode \

#define digit_class 0
#define period_class 1
#define space_class 2
#define percent_class 3
#define string_class 4
#define right_paren_class 8
#define isolated_classes 5:case 6:case 7:case 8
#define letter_class 9
#define mp_left_bracket_class 17
#define mp_right_bracket_class 18
#define invalid_class 20
#define max_class 20 \

#define semicolon_class 6 \

#define set_text(A) do{ \
FUNCTION_TRACE3("set_text(%p, %p)\n",(A) ,(B) ) ; \
(A) ->text= (B) ; \
}while(0)  \

#define set_eq_type(A,B) do{ \
FUNCTION_TRACE3("set_eq_type(%p, %d)\n",(A) ,(B) ) ; \
(A) ->type= (B) ; \
}while(0)  \

#define set_equiv(A,B) do{ \
FUNCTION_TRACE3("set_equiv(%p, %d)\n",(A) ,(B) ) ; \
(A) ->v.data.node= NULL; \
(A) ->v.data.indep.serial= (B) ; \
}while(0)  \

#define set_equiv_node(A,B) do{ \
FUNCTION_TRACE3("set_equiv_node(%p, %p)\n",(A) ,(B) ) ; \
(A) ->v.data.node= (B) ; \
(A) ->v.data.indep.serial= 0; \
}while(0)  \

#define set_equiv_sym(A,B) do{ \
FUNCTION_TRACE3("set_equiv_sym(%p, %p)\n",(A) ,(B) ) ; \
(A) ->v.data.node= (mp_node) (B) ; \
(A) ->v.data.indep.serial= 0; \
}while(0)  \

#define mp_id_lookup(A,B,C,D) mp_do_id_lookup((A) ,mp->symbols,(B) ,(C) ,(D) )  \

#define token_node_size sizeof(mp_node_data)  \

#define set_value_sym(A,B) do_set_value_sym(mp,(mp_token_node) (A) ,(B) )
#define set_value_number(A,B) do_set_value_number(mp,(mp_token_node) (A) ,(B) )
#define set_value_node(A,B) do_set_value_node(mp,(mp_token_node) (A) ,(B) )
#define set_value_str(A,B) do_set_value_str(mp,(mp_token_node) (A) ,(B) )
#define set_value_knot(A,B) do_set_value_knot(mp,(mp_token_node) A,(B) )  \

#define value_sym_NEW(A) (mp_sym) mp_link(A)
#define set_value_sym_NEW(A,B) set_mp_link(A,(mp_node) B)  \

#define ref_count(A) indep_value(A)
#define set_ref_count(A,B) set_indep_value(A,B)
#define add_mac_ref(A) set_ref_count((A) ,ref_count((A) ) +1)
#define decr_mac_ref(A) set_ref_count((A) ,ref_count((A) ) -1)  \

#define attr_head(A) do_get_attr_head(mp,(mp_value_node) (A) )
#define set_attr_head(A,B) do_set_attr_head(mp,(mp_value_node) (A) ,(mp_node) (B) )  \

#define subscr_head(A) do_get_subscr_head(mp,(mp_value_node) (A) )
#define set_subscr_head(A,B) do_set_subscr_head(mp,(mp_value_node) (A) ,(mp_node) (B) )  \

#define value_node_size sizeof(struct mp_value_node_data)  \

#define mp_free_attr_node(a,b) do{ \
assert((b) ->type==mp_attr_node_type||(b) ->name_type==mp_attr) ; \
mp_free_value_node(a,b) ; \
}while(0)  \

#define collective_subscript (void*) 0
#define subscript(A) ((mp_value_node) (A) ) ->subscript_
#define set_subscript(A,B) do_set_subscript(mp,(mp_value_node) (A) ,B)  \

#define x_part(A) ((mp_pair_node) (A) ) ->x_part_
#define y_part(A) ((mp_pair_node) (A) ) ->y_part_ \

#define pair_node_size sizeof(struct mp_pair_node_data)  \

#define tx_part(A) ((mp_transform_node) (A) ) ->tx_part_
#define ty_part(A) ((mp_transform_node) (A) ) ->ty_part_
#define xx_part(A) ((mp_transform_node) (A) ) ->xx_part_
#define xy_part(A) ((mp_transform_node) (A) ) ->xy_part_
#define yx_part(A) ((mp_transform_node) (A) ) ->yx_part_
#define yy_part(A) ((mp_transform_node) (A) ) ->yy_part_ \

#define transform_node_size sizeof(struct mp_transform_node_data)  \

#define red_part(A) ((mp_color_node) (A) ) ->red_part_
#define green_part(A) ((mp_color_node) (A) ) ->green_part_
#define blue_part(A) ((mp_color_node) (A) ) ->blue_part_ \

#define grey_part(A) red_part(A)  \

#define color_node_size sizeof(struct mp_color_node_data)  \

#define cyan_part(A) ((mp_cmykcolor_node) (A) ) ->cyan_part_
#define magenta_part(A) ((mp_cmykcolor_node) (A) ) ->magenta_part_
#define yellow_part(A) ((mp_cmykcolor_node) (A) ) ->yellow_part_
#define black_part(A) ((mp_cmykcolor_node) (A) ) ->black_part_ \

#define cmykcolor_node_size sizeof(struct mp_cmykcolor_node_data)  \

#define mp_next_knot(A) (A) ->next
#define mp_left_type(A) (A) ->data.types.left_type
#define mp_right_type(A) (A) ->data.types.right_type
#define mp_prev_knot(A) (A) ->data.prev
#define mp_knot_info(A) (A) ->data.info \

#define mp_gr_next_knot(A) (A) ->next \

#define left_curl left_x
#define left_given left_x
#define left_tension left_y
#define right_curl right_x
#define right_given right_x
#define right_tension right_y \

#define mp_originator(A) (A) ->originator \

#define mp_minx mp->bbmin[mp_x_code]
#define mp_maxx mp->bbmax[mp_x_code]
#define mp_miny mp->bbmin[mp_y_code]
#define mp_maxy mp->bbmax[mp_y_code] \

#define one_third_inf_t ((math_data*) mp->math) ->one_third_inf_t \

#define copy_pen(A) mp_make_pen(mp,mp_copy_path(mp,(A) ) ,false)  \

#define pen_is_elliptical(A) ((A) ==mp_next_knot((A) ) )  \

#define set_precision() (((math_data*) (mp->math) ) ->set_precision) (mp)
#define free_math() (((math_data*) (mp->math) ) ->free_math) (mp)
#define scan_numeric_token(A) (((math_data*) (mp->math) ) ->scan_numeric) (mp,A)
#define scan_fractional_token(A) (((math_data*) (mp->math) ) ->scan_fractional) (mp,A)
#define set_number_from_of_the_way(A,t,B,C) (((math_data*) (mp->math) ) ->from_oftheway) (mp,&(A) ,t,B,C)
#define set_number_from_int(A,B) (((math_data*) (mp->math) ) ->from_int) (&(A) ,B)
#define set_number_from_scaled(A,B) (((math_data*) (mp->math) ) ->from_scaled) (&(A) ,B)
#define set_number_from_boolean(A,B) (((math_data*) (mp->math) ) ->from_boolean) (&(A) ,B)
#define set_number_from_double(A,B) (((math_data*) (mp->math) ) ->from_double) (&(A) ,B)
#define set_number_from_addition(A,B,C) (((math_data*) (mp->math) ) ->from_addition) (&(A) ,B,C)
#define set_number_from_substraction(A,B,C) (((math_data*) (mp->math) ) ->from_substraction) (&(A) ,B,C)
#define set_number_from_div(A,B,C) (((math_data*) (mp->math) ) ->from_div) (&(A) ,B,C)
#define set_number_from_mul(A,B,C) (((math_data*) (mp->math) ) ->from_mul) (&(A) ,B,C)
#define number_int_div(A,C) (((math_data*) (mp->math) ) ->from_int_div) (&(A) ,A,C)
#define set_number_from_int_mul(A,B,C) (((math_data*) (mp->math) ) ->from_int_mul) (&(A) ,B,C)  \

#define set_number_to_unity(A) (((math_data*) (mp->math) ) ->clone) (&(A) ,unity_t)
#define set_number_to_zero(A) (((math_data*) (mp->math) ) ->clone) (&(A) ,zero_t)
#define set_number_to_inf(A) (((math_data*) (mp->math) ) ->clone) (&(A) ,inf_t)
#define set_number_to_neg_inf(A) do{set_number_to_inf(A) ;number_negate(A) ;}while(0)  \

#define init_randoms(A) (((math_data*) (mp->math) ) ->init_randoms) (mp,A)
#define print_number(A) (((math_data*) (mp->math) ) ->print) (mp,A)
#define number_tostring(A) (((math_data*) (mp->math) ) ->tostring) (mp,A)
#define make_scaled(R,A,B) (((math_data*) (mp->math) ) ->make_scaled) (mp,&(R) ,A,B)
#define take_scaled(R,A,B) (((math_data*) (mp->math) ) ->take_scaled) (mp,&(R) ,A,B)
#define make_fraction(R,A,B) (((math_data*) (mp->math) ) ->make_fraction) (mp,&(R) ,A,B)
#define take_fraction(R,A,B) (((math_data*) (mp->math) ) ->take_fraction) (mp,&(R) ,A,B)
#define pyth_add(R,A,B) (((math_data*) (mp->math) ) ->pyth_add) (mp,&(R) ,A,B)
#define pyth_sub(R,A,B) (((math_data*) (mp->math) ) ->pyth_sub) (mp,&(R) ,A,B)
#define n_arg(R,A,B) (((math_data*) (mp->math) ) ->n_arg) (mp,&(R) ,A,B)
#define m_log(R,A) (((math_data*) (mp->math) ) ->m_log) (mp,&(R) ,A)
#define m_exp(R,A) (((math_data*) (mp->math) ) ->m_exp) (mp,&(R) ,A)
#define m_unif_rand(R,A) (((math_data*) (mp->math) ) ->m_unif_rand) (mp,&(R) ,A)
#define m_norm_rand(R) (((math_data*) (mp->math) ) ->m_norm_rand) (mp,&(R) )
#define velocity(R,A,B,C,D,E) (((math_data*) (mp->math) ) ->velocity) (mp,&(R) ,A,B,C,D,E)
#define ab_vs_cd(R,A,B,C,D) (((math_data*) (mp->math) ) ->ab_vs_cd) (mp,&(R) ,A,B,C,D)
#define crossing_point(R,A,B,C) (((math_data*) (mp->math) ) ->crossing_point) (mp,&(R) ,A,B,C)
#define n_sin_cos(A,S,C) (((math_data*) (mp->math) ) ->sin_cos) (mp,A,&(S) ,&(C) )
#define square_rt(A,S) (((math_data*) (mp->math) ) ->sqrt) (mp,&(A) ,S)
#define slow_add(R,A,B) (((math_data*) (mp->math) ) ->slow_add) (mp,&(R) ,A,B)
#define round_unscaled(A) (((math_data*) (mp->math) ) ->round_unscaled) (A)
#define floor_scaled(A) (((math_data*) (mp->math) ) ->floor_scaled) (&(A) )
#define fraction_to_round_scaled(A) (((math_data*) (mp->math) ) ->fraction_to_round_scaled) (&(A) )
#define number_to_int(A) (((math_data*) (mp->math) ) ->to_int) (A)
#define number_to_boolean(A) (((math_data*) (mp->math) ) ->to_boolean) (A)
#define number_to_scaled(A) (((math_data*) (mp->math) ) ->to_scaled) (A)
#define number_to_double(A) (((math_data*) (mp->math) ) ->to_double) (A)
#define number_negate(A) (((math_data*) (mp->math) ) ->negate) (&(A) )
#define number_add(A,B) (((math_data*) (mp->math) ) ->add) (&(A) ,B)
#define number_substract(A,B) (((math_data*) (mp->math) ) ->substract) (&(A) ,B)
#define number_half(A) (((math_data*) (mp->math) ) ->half) (&(A) )
#define number_halfp(A) (((math_data*) (mp->math) ) ->halfp) (&(A) )
#define number_double(A) (((math_data*) (mp->math) ) ->do_double) (&(A) )
#define number_add_scaled(A,B) (((math_data*) (mp->math) ) ->add_scaled) (&(A) ,B)
#define number_multiply_int(A,B) (((math_data*) (mp->math) ) ->multiply_int) (&(A) ,B)
#define number_divide_int(A,B) (((math_data*) (mp->math) ) ->divide_int) (&(A) ,B)
#define number_abs(A) (((math_data*) (mp->math) ) ->abs) (&(A) )
#define number_modulo(A,B) (((math_data*) (mp->math) ) ->modulo) (&(A) ,B)
#define number_nonequalabs(A,B) (((math_data*) (mp->math) ) ->nonequalabs) (A,B)
#define number_odd(A) (((math_data*) (mp->math) ) ->odd) (A)
#define number_equal(A,B) (((math_data*) (mp->math) ) ->equal) (A,B)
#define number_greater(A,B) (((math_data*) (mp->math) ) ->greater) (A,B)
#define number_less(A,B) (((math_data*) (mp->math) ) ->less) (A,B)
#define number_clone(A,B) (((math_data*) (mp->math) ) ->clone) (&(A) ,B)
#define number_swap(A,B) (((math_data*) (mp->math) ) ->swap) (&(A) ,&(B) ) ;
#define convert_scaled_to_angle(A) (((math_data*) (mp->math) ) ->scaled_to_angle) (&(A) ) ;
#define convert_angle_to_scaled(A) (((math_data*) (mp->math) ) ->angle_to_scaled) (&(A) ) ;
#define convert_fraction_to_scaled(A) (((math_data*) (mp->math) ) ->fraction_to_scaled) (&(A) ) ;
#define convert_scaled_to_fraction(A) (((math_data*) (mp->math) ) ->scaled_to_fraction) (&(A) ) ; \

#define number_zero(A) number_equal(A,zero_t)
#define number_infinite(A) number_equal(A,inf_t)
#define number_unity(A) number_equal(A,unity_t)
#define number_negative(A) number_less(A,zero_t)
#define number_nonnegative(A) (!number_negative(A) )
#define number_positive(A) number_greater(A,zero_t)
#define number_nonpositive(A) (!number_positive(A) )
#define number_nonzero(A) (!number_zero(A) )
#define number_greaterequal(A,B) (!number_less(A,B) )
#define number_lessequal(A,B) (!number_greater(A,B) )  \

#define mp_path_p(A) (A) ->path_p_
#define mp_pen_p(A) (A) ->pen_p_
#define mp_color_model(A) ((mp_fill_node) (A) ) ->color_model_
#define cyan red
#define grey red
#define magenta green
#define yellow blue
#define mp_pre_script(A) ((mp_fill_node) (A) ) ->pre_script_
#define mp_post_script(A) ((mp_fill_node) (A) ) ->post_script_ \

#define fill_node_size sizeof(struct mp_fill_node_data)  \

#define mp_dash_p(A) ((mp_stroked_node) (A) ) ->dash_p_ \

#define stroked_node_size sizeof(struct mp_stroked_node_data)  \

#define mp_text_p(A) ((mp_text_node) (A) ) ->text_p_
#define mp_font_n(A) ((mp_text_node) (A) ) ->font_n_ \

#define text_node_size sizeof(struct mp_text_node_data)  \

#define has_color(A) (mp_type((A) ) <mp_start_clip_node_type)  \

#define has_pen(A) (mp_type((A) ) <mp_text_node_type)  \

#define is_start_or_stop(A) (mp_type((A) ) >=mp_start_clip_node_type)
#define is_stop(A) (mp_type((A) ) >=mp_stop_clip_node_type)  \

#define start_clip_size sizeof(struct mp_start_clip_node_data)
#define stop_clip_size sizeof(struct mp_stop_clip_node_data)
#define start_bounds_size sizeof(struct mp_start_bounds_node_data)
#define stop_bounds_size sizeof(struct mp_stop_bounds_node_data)  \

#define dash_list(A) (mp_dash_node) (((mp_dash_node) (A) ) ->link)
#define set_dash_list(A,B) ((mp_dash_node) (A) ) ->link= (mp_node) ((B) )  \

#define dash_node_size sizeof(struct mp_dash_node_data)  \

#define bblast(A) ((mp_edge_header_node) (A) ) ->bblast_
#define edge_list(A) ((mp_edge_header_node) (A) ) ->list_ \

#define no_bounds 0
#define bounds_set 1
#define bounds_unset 2
#define obj_tail(A) ((mp_edge_header_node) (A) ) ->obj_tail_
#define edge_ref_count(A) ((mp_edge_header_node) (A) ) ->ref_count_ \

#define edge_header_size sizeof(struct mp_edge_header_node_data)  \

#define add_edge_ref(A) incr(edge_ref_count((A) ) )
#define delete_edge_ref(A) { \
if(edge_ref_count((A) ) ==0)  \
mp_toss_edges(mp,(mp_edge_header_node) (A) ) ; \
else \
decr(edge_ref_count((A) ) ) ; \
} \

#define dash_info(A) ((mp_dash_node) (A) ) ->dash_info_ \

#define zero_off 16384 \

#define fix_by(A) mp_knot_info(c) = mp_knot_info(c) +(A)  \

#define near_zero_angle_k ((math_data*) mp->math) ->near_zero_angle_t \

#define we_found_it { \
number_clone(tt,t) ; \
fraction_to_round_scaled(tt) ; \
goto FOUND; \
} \

#define stack_1(A) mp->bisect_stack[(A) ]
#define stack_2(A) mp->bisect_stack[(A) +1]
#define stack_3(A) mp->bisect_stack[(A) +2]
#define stack_min(A) mp->bisect_stack[(A) +3] \

#define stack_max(A) mp->bisect_stack[(A) +4] \

#define int_packets 20 \

#define u_packet(A) ((A) -5)
#define v_packet(A) ((A) -10)
#define x_packet(A) ((A) -15)
#define y_packet(A) ((A) -20)
#define l_packets (mp->bisect_ptr-int_packets)
#define r_packets mp->bisect_ptr
#define ul_packet u_packet(l_packets)
#define vl_packet v_packet(l_packets)
#define xl_packet x_packet(l_packets)
#define yl_packet y_packet(l_packets)
#define ur_packet u_packet(r_packets)
#define vr_packet v_packet(r_packets)
#define xr_packet x_packet(r_packets)
#define yr_packet y_packet(r_packets)  \

#define u1l stack_1(ul_packet)
#define u2l stack_2(ul_packet)
#define u3l stack_3(ul_packet)
#define v1l stack_1(vl_packet)
#define v2l stack_2(vl_packet)
#define v3l stack_3(vl_packet)
#define x1l stack_1(xl_packet)
#define x2l stack_2(xl_packet)
#define x3l stack_3(xl_packet)
#define y1l stack_1(yl_packet)
#define y2l stack_2(yl_packet)
#define y3l stack_3(yl_packet)
#define u1r stack_1(ur_packet)
#define u2r stack_2(ur_packet)
#define u3r stack_3(ur_packet)
#define v1r stack_1(vr_packet)
#define v2r stack_2(vr_packet)
#define v3r stack_3(vr_packet)
#define x1r stack_1(xr_packet)
#define x2r stack_2(xr_packet)
#define x3r stack_3(xr_packet)
#define y1r stack_1(yr_packet)
#define y2r stack_2(yr_packet)
#define y3r stack_3(yr_packet)  \

#define stack_dx mp->bisect_stack[mp->bisect_ptr]
#define stack_dy mp->bisect_stack[mp->bisect_ptr+1]
#define stack_tol mp->bisect_stack[mp->bisect_ptr+2]
#define stack_uv mp->bisect_stack[mp->bisect_ptr+3]
#define stack_xy mp->bisect_stack[mp->bisect_ptr+4]
#define int_increment (int_packets+int_packets+5)  \

#define set_min_max(A)  \
debug_number(stack_1(A) ) ; \
debug_number(stack_3(A) ) ; \
debug_number(stack_2(A) ) ; \
debug_number(stack_min(A) ) ; \
debug_number(stack_max(A) ) ; \
if(number_negative(stack_1((A) ) ) ) { \
if(number_nonnegative(stack_3((A) ) ) ) { \
if(number_negative(stack_2((A) ) ) )  \
set_number_from_addition(stack_min((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
else \
number_clone(stack_min((A) ) ,stack_1((A) ) ) ; \
set_number_from_addition(stack_max((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
number_add(stack_max((A) ) ,stack_3((A) ) ) ; \
if(number_negative(stack_max((A) ) ) )  \
set_number_to_zero(stack_max((A) ) ) ; \
}else{ \
set_number_from_addition(stack_min((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
number_add(stack_min((A) ) ,stack_3((A) ) ) ; \
if(number_greater(stack_min((A) ) ,stack_1((A) ) ) )  \
number_clone(stack_min((A) ) ,stack_1((A) ) ) ; \
set_number_from_addition(stack_max((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
if(number_negative(stack_max((A) ) ) )  \
set_number_to_zero(stack_max((A) ) ) ; \
} \
}else if(number_nonpositive(stack_3((A) ) ) ) { \
if(number_positive(stack_2((A) ) ) )  \
set_number_from_addition(stack_max((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
else \
number_clone(stack_max((A) ) ,stack_1((A) ) ) ; \
set_number_from_addition(stack_min((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
number_add(stack_min((A) ) ,stack_3((A) ) ) ; \
if(number_positive(stack_min((A) ) ) )  \
set_number_to_zero(stack_min((A) ) ) ; \
}else{ \
set_number_from_addition(stack_max((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
number_add(stack_max((A) ) ,stack_3((A) ) ) ; \
if(number_less(stack_max((A) ) ,stack_1((A) ) ) )  \
number_clone(stack_max((A) ) ,stack_1((A) ) ) ; \
set_number_from_addition(stack_min((A) ) ,stack_1((A) ) ,stack_2((A) ) ) ; \
if(number_positive(stack_min((A) ) ) )  \
set_number_to_zero(stack_min((A) ) ) ; \
} \

#define max_patience 5000 \

#define half(A) ((A) /2)  \

#define indep_scale(A) ((mp_value_node) (A) ) ->data.indep.scale
#define set_indep_scale(A,B) ((mp_value_node) (A) ) ->data.indep.scale= (B)
#define indep_value(A) ((mp_value_node) (A) ) ->data.indep.serial
#define set_indep_value(A,B) ((mp_value_node) (A) ) ->data.indep.serial= (B)  \
 \

#define dep_value(A) ((mp_value_node) (A) ) ->data.n
#define set_dep_value(A,B) do_set_dep_value(mp,(A) ,(B) )
#define dep_info(A) get_dep_info(mp,(A) )
#define set_dep_info(A,B) do{ \
mp_value_node d= (mp_value_node) (B) ; \
FUNCTION_TRACE4("set_dep_info(%p,%p) on %d\n",(A) ,d,__LINE__) ; \
((mp_value_node) (A) ) ->parent_= (mp_node) d; \
}while(0)
#define dep_list(A) ((mp_value_node) (A) ) ->attr_head_
#define set_dep_list(A,B) do{ \
mp_value_node d= (mp_value_node) (B) ; \
FUNCTION_TRACE4("set_dep_list(%p,%p) on %d\n",(A) ,d,__LINE__) ; \
dep_list((A) ) = (mp_node) d; \
}while(0)
#define prev_dep(A) ((mp_value_node) (A) ) ->subscr_head_
#define set_prev_dep(A,B) do{ \
mp_value_node d= (mp_value_node) (B) ; \
FUNCTION_TRACE4("set_prev_dep(%p,%p) on %d\n",(A) ,d,__LINE__) ; \
prev_dep((A) ) = (mp_node) d; \
}while(0)  \

#define independent_needing_fix 0 \

#define fraction_threshold_k ((math_data*) mp->math) ->fraction_threshold_t
#define half_fraction_threshold_k ((math_data*) mp->math) ->half_fraction_threshold_t
#define scaled_threshold_k ((math_data*) mp->math) ->scaled_threshold_t
#define half_scaled_threshold_k ((math_data*) mp->math) ->half_scaled_threshold_t \

#define p_over_v_threshold_k ((math_data*) mp->math) ->p_over_v_threshold_t \

#define independent_being_fixed 1
#define two_to_the(A) (1<<(unsigned) (A) )  \

#define cur_cmd() (unsigned) (mp->cur_mod_->type)
#define set_cur_cmd(A) mp->cur_mod_->type= (A)
#define cur_mod_int() number_to_int(mp->cur_mod_->data.n)
#define cur_mod() number_to_scaled(mp->cur_mod_->data.n)
#define cur_mod_number() mp->cur_mod_->data.n
#define set_cur_mod(A) set_number_from_scaled(mp->cur_mod_->data.n,(A) )
#define set_cur_mod_number(A) number_clone(mp->cur_mod_->data.n,(A) )
#define cur_mod_node() mp->cur_mod_->data.node
#define set_cur_mod_node(A) mp->cur_mod_->data.node= (A)
#define cur_mod_str() mp->cur_mod_->data.str
#define set_cur_mod_str(A) mp->cur_mod_->data.str= (A)
#define cur_sym() mp->cur_mod_->data.sym
#define set_cur_sym(A) mp->cur_mod_->data.sym= (A)
#define cur_sym_mod() mp->cur_mod_->name_type
#define set_cur_sym_mod(A) mp->cur_mod_->name_type= (A)  \

#define show_cur_cmd_mod mp_show_cmd_mod(mp,cur_cmd() ,cur_mod() )  \

#define iindex mp->cur_input.index_field
#define start mp->cur_input.start_field
#define limit mp->cur_input.limit_field
#define name mp->cur_input.name_field \

#define is_term (mp_string) 0
#define is_read (mp_string) 1
#define is_scantok (mp_string) 2
#define max_spec_src is_scantok \

#define terminal_input (name==is_term)
#define cur_file mp->input_file[iindex]
#define line mp->line_stack[iindex]
#define in_ext mp->inext_stack[iindex]
#define in_name mp->iname_stack[iindex]
#define in_area mp->iarea_stack[iindex]
#define absent (mp_string) 1
#define mpx_reading (mp->mpx_name[iindex]> absent)  \

#define mpx_finished 0 \
 \

#define nloc mp->cur_input.nloc_field
#define nstart mp->cur_input.nstart_field \

#define token_type iindex
#define token_state (iindex<=macro)
#define file_state (iindex> macro)
#define param_start limit
#define forever_text 0
#define loop_text 1
#define parameter 2
#define backed_up 3
#define inserted 4
#define macro 5
#define file_bottom 6 \

#define begin_pseudoprint { \
l= mp->tally;mp->tally= 0;mp->selector= pseudo; \
mp->trick_count= 1000000; \
}
#define set_trick_count() { \
mp->first_count= mp->tally; \
mp->trick_count= mp->tally+1+mp->error_line-mp->half_error_line; \
if(mp->trick_count<mp->error_line) mp->trick_count= mp->error_line; \
} \

#define push_input { \
if(mp->input_ptr> mp->max_in_stack) { \
mp->max_in_stack= mp->input_ptr; \
if(mp->input_ptr==mp->stack_size) { \
int l= (mp->stack_size+(mp->stack_size/4) ) ; \
XREALLOC(mp->input_stack,l,in_state_record) ; \
mp->stack_size= l; \
} \
} \
mp->input_stack[mp->input_ptr]= mp->cur_input; \
incr(mp->input_ptr) ; \
} \

#define pop_input { \
decr(mp->input_ptr) ;mp->cur_input= mp->input_stack[mp->input_ptr]; \
} \

#define back_list(A) mp_begin_token_list(mp,(A) ,(quarterword) backed_up)  \

#define normal 0
#define skipping 1
#define flushing 2
#define absorbing 3
#define var_defining 4
#define op_defining 5
#define loop_defining 6 \

#define btex_code 0
#define verbatim_code 1 \

#define get_t_next(a) do{ \
mp_get_next(mp) ; \
if(cur_cmd() <=mp_max_pre_command)  \
mp_t_next(mp) ; \
}while(0)  \

#define start_def 1
#define var_def 2
#define end_def 0
#define start_forever 1
#define start_for 2
#define start_forsuffixes 3
#define end_for 0 \

#define quote 0
#define macro_prefix 1
#define macro_at 2
#define macro_suffix 3 \

#define check_expansion_depth() if(++mp->expand_depth_count>=mp->expand_depth)  \
mp_expansion_depth_error(mp)  \

#define if_line_field(A) ((mp_if_node) (A) ) ->if_line_field_
#define if_code 1
#define fi_code 2
#define else_code 3
#define else_if_code 4 \

#define if_node_size sizeof(struct mp_if_node_data)  \

#define PROGRESSION_FLAG (mp_node) (2)  \
 \

#define copy_pool_segment(A,B,C) { \
A= xmalloc(C+1,sizeof(char) ) ; \
(void) memcpy(A,(char*) (mp->cur_string+B) ,C) ; \
A[C]= 0;} \

#define append_to_name(A) {mp->name_of_file[k++]= (char) xchr(xord((ASCII_code) (A) ) ) ;} \

#define pack_cur_name mp_pack_file_name(mp,mp->cur_name,mp->cur_area,mp->cur_ext)  \

#define cur_exp_value_boolean() number_to_int(mp->cur_exp.data.n)
#define cur_exp_value_number() mp->cur_exp.data.n
#define cur_exp_node() mp->cur_exp.data.node
#define cur_exp_str() mp->cur_exp.data.str
#define cur_exp_knot() mp->cur_exp.data.p \

#define set_cur_exp_value_scaled(A) do{ \
if(cur_exp_str() ) { \
delete_str_ref(cur_exp_str() ) ; \
} \
set_number_from_scaled(mp->cur_exp.data.n,(A) ) ; \
cur_exp_node() = NULL; \
cur_exp_str() = NULL; \
cur_exp_knot() = NULL; \
}while(0)
#define set_cur_exp_value_boolean(A) do{ \
if(cur_exp_str() ) { \
delete_str_ref(cur_exp_str() ) ; \
} \
set_number_from_int(mp->cur_exp.data.n,(A) ) ; \
cur_exp_node() = NULL; \
cur_exp_str() = NULL; \
cur_exp_knot() = NULL; \
}while(0)
#define set_cur_exp_value_number(A) do{ \
if(cur_exp_str() ) { \
delete_str_ref(cur_exp_str() ) ; \
} \
number_clone(mp->cur_exp.data.n,(A) ) ; \
cur_exp_node() = NULL; \
cur_exp_str() = NULL; \
cur_exp_knot() = NULL; \
}while(0)
#define set_cur_exp_node(A) do{ \
if(cur_exp_str() ) { \
delete_str_ref(cur_exp_str() ) ; \
} \
cur_exp_node() = A; \
cur_exp_str() = NULL; \
cur_exp_knot() = NULL; \
set_number_to_zero(mp->cur_exp.data.n) ; \
}while(0)
#define set_cur_exp_str(A) do{ \
if(cur_exp_str() ) { \
delete_str_ref(cur_exp_str() ) ; \
} \
cur_exp_str() = A; \
add_str_ref(cur_exp_str() ) ; \
cur_exp_node() = NULL; \
cur_exp_knot() = NULL; \
set_number_to_zero(mp->cur_exp.data.n) ; \
}while(0)
#define set_cur_exp_knot(A) do{ \
if(cur_exp_str() ) { \
delete_str_ref(cur_exp_str() ) ; \
} \
cur_exp_knot() = A; \
cur_exp_node() = NULL; \
cur_exp_str() = NULL; \
set_number_to_zero(mp->cur_exp.data.n) ; \
}while(0)  \
 \

#define min_tension three_quarter_unit_t \

#define mp_get_boolean(mp) do{ \
mp_get_x_next(mp) ; \
mp_scan_expression(mp) ; \
if(mp->cur_exp.type!=mp_boolean_type) { \
do_boolean_error(mp) ; \
} \
}while(0)  \

#define cur_pic_item mp_link(edge_list(cur_exp_node() ) )
#define pict_color_type(A) ((cur_pic_item!=NULL) && \
((!has_color(cur_pic_item) )  \
|| \
(((mp_color_model(cur_pic_item) ==A)  \
|| \
((mp_color_model(cur_pic_item) ==mp_uninitialized_model) && \
(number_to_scaled(internal_value(mp_default_color_model) ) /number_to_scaled(unity_t) ) ==(A) ) ) ) ) )  \

#define boolean_reset(A) if((A) ) set_cur_exp_value_boolean(mp_true_code) ;else set_cur_exp_value_boolean(mp_false_code)  \

#define type_range(A,B) { \
if((mp->cur_exp.type>=(A) ) &&(mp->cur_exp.type<=(B) ) )  \
set_number_from_boolean(new_expr.data.n,mp_true_code) ; \
else \
set_number_from_boolean(new_expr.data.n,mp_false_code) ; \
mp_flush_cur_exp(mp,new_expr) ; \
mp->cur_exp.type= mp_boolean_type; \
}
#define type_test(A) { \
if(mp->cur_exp.type==(mp_variable_type) (A) )  \
set_number_from_boolean(new_expr.data.n,mp_true_code) ; \
else \
set_number_from_boolean(new_expr.data.n,mp_false_code) ; \
mp_flush_cur_exp(mp,new_expr) ; \
mp->cur_exp.type= mp_boolean_type; \
} \
 \

#define negate_value(A) if(mp_type(A) ==mp_known) { \
set_value_number(A,(value_number(A) ) ) ; \
number_negate(value_number(A) ) ; \
}else{ \
mp_negate_dep_list(mp,(mp_value_node) dep_list((mp_value_node) A) ) ; \
} \

#define mp_floor(a) ((a) >=0?(int) (a) :-(int) (-(a) ) )
#define bezier_error (720*(256*256*16) ) +1
#define mp_sign(v) ((v) > 0?1:((v) <0?-1:0) )
#define mp_out(A) (double) ((A) /16)  \

#define p_nextnext mp_next_knot(mp_next_knot(p) )
#define p_next mp_next_knot(p)  \

#define binary_return {mp_finish_binary(mp,old_p,old_exp) ;return;} \

#define path_trans(A,B) {mp_set_up_known_trans(mp,(A) ) ; \
mp_unstash_cur_exp(mp,(B) ) ; \
mp_do_path_trans(mp,cur_exp_knot() ) ;} \

#define pen_trans(A,B) {mp_set_up_known_trans(mp,(A) ) ; \
mp_unstash_cur_exp(mp,(B) ) ; \
mp_do_pen_trans(mp,cur_exp_knot() ) ;} \

#define equation_threshold_k ((math_data*) mp->math) ->equation_threshold_t \

#define reset_stream(a) do{ \
mp_reset_stream(&(a) ) ; \
if(!ff->f) { \
ff->f= xmalloc(1,1) ; \
(a) .fptr= ff->f; \
}}while(0)  \

#define show_token_code 0
#define show_stats_code 1
#define show_code 2
#define show_var_code 3
#define show_dependencies_code 4 \

#define double_path_code 0
#define contour_code 1
#define also_code 2 \

#define with_mp_pre_script 11
#define with_mp_post_script 13 \

#define make_cp_a_colored_object() do{ \
cp= p; \
while(cp!=NULL) { \
if(has_color(cp) )  \
break; \
cp= mp_link(cp) ; \
} \
}while(0)  \

#define clear_color(A) do{ \
set_number_to_zero(((mp_stroked_node) (A) ) ->cyan) ; \
set_number_to_zero(((mp_stroked_node) (A) ) ->magenta) ; \
set_number_to_zero(((mp_stroked_node) (A) ) ->yellow) ; \
set_number_to_zero(((mp_stroked_node) (A) ) ->black) ; \
mp_color_model((A) ) = mp_uninitialized_model; \
}while(0)  \

#define set_color_val(A,B) do{ \
number_clone(A,(B) ) ; \
if(number_negative(A) )  \
set_number_to_zero(A) ; \
if(number_greater(A,unity_t) )  \
set_number_to_unity(A) ; \
}while(0)  \

#define message_code 0
#define err_message_code 1
#define err_help_code 2
#define filename_template_code 3
#define print_with_leading_zeroes(A,B) do{ \
size_t g= mp->cur_length; \
size_t f= (size_t) (B) ; \
mp_print_int(mp,(A) ) ; \
g= mp->cur_length-g; \
if(f> g) { \
mp->cur_length= mp->cur_length-g; \
while(f> g) { \
mp_print_char(mp,xord('0') ) ; \
decr(f) ; \
}; \
mp_print_int(mp,(A) ) ; \
}; \
f= 0; \
}while(0)  \

#define no_tag 0
#define lig_tag 1
#define list_tag 2
#define ext_tag 3 \

#define stop_flag (128)  \

#define kern_flag (128)
#define skip_byte(A) mp->lig_kern[(A) ].b0
#define next_char(A) mp->lig_kern[(A) ].b1
#define op_byte(A) mp->lig_kern[(A) ].b2
#define rem_byte(A) mp->lig_kern[(A) ].b3 \

#define ext_top(A) mp->exten[(A) ].b0
#define ext_mid(A) mp->exten[(A) ].b1
#define ext_bot(A) mp->exten[(A) ].b2
#define ext_rep(A) mp->exten[(A) ].b3 \

#define slant_code 1
#define space_code 2
#define space_stretch_code 3
#define space_shrink_code 4
#define x_height_code 5
#define quad_code 6
#define extra_space_code 7 \

#define max_tfm_int 32510
#define undefined_label max_tfm_int \

#define char_list_code 0
#define lig_table_code 1
#define extensible_code 2
#define header_byte_code 3
#define font_dimen_code 4 \

#define cancel_skips(A) mp->ll= (A) ; \
do{ \
mp->lll= qo(skip_byte(mp->ll) ) ; \
skip_byte(mp->ll) = stop_flag;mp->ll= (short) (mp->ll-mp->lll) ; \
}while(mp->lll!=0)  \

#define skip_error(A) { \
const char*hlp[]= {"At most 127 lig/kern steps can separate skipto1 from 1::.",NULL}; \
mp_error(mp,"Too far to skip",hlp,true) ; \
 \
cancel_skips((A) ) ; \
} \

#define missing_extensible_punctuation(A)  \
{ \
char msg[256]; \
const char*hlp[]= {"I'm processing `extensible c: t,m,b,r'.",NULL}; \
mp_snprintf(msg,256,"Missing %s has been inserted",(A) ) ; \
mp_back_error(mp,msg,hlp,true) ; \
 \
} \

#define clear_the_list mp_link(mp->temp_head) = mp->inf_val \

#define tfm_warn_threshold_k ((math_data*) mp->math) ->tfm_warn_threshold_t \

#define three_bytes 0100000000 \

#define tfm_out(A) do{ \
unsigned char s= (unsigned char) (A) ; \
(mp->write_binary_file) (mp,mp->tfm_file,(void*) &s,1) ; \
}while(0)  \

#define null_font 0 \

#define char_mp_info(A,B) mp->font_info[mp->char_base[(A) ]+(B) ].qqqq
#define char_width(A,B) mp->font_info[mp->width_base[(A) ]+(B) .b0].sc
#define char_height(A,B) mp->font_info[mp->height_base[(A) ]+(B) .b1].sc
#define char_depth(A,B) mp->font_info[mp->depth_base[(A) ]+(B) .b2].sc
#define ichar_exists(A) ((A) .b0> 0)  \

#define max_integer 0x7FFFFFFF \

#define export_color(q,p)  \
if(mp_color_model(p) ==mp_uninitialized_model) { \
gr_color_model(q) = (unsigned char) (number_to_scaled(internal_value(mp_default_color_model) ) /65536) ; \
gr_cyan_val(q) = 0; \
gr_magenta_val(q) = 0; \
gr_yellow_val(q) = 0; \
gr_black_val(q) = ((gr_color_model(q) ==mp_cmyk_model?number_to_scaled(unity_t) :0) /65536.0) ; \
}else{ \
gr_color_model(q) = (unsigned char) mp_color_model(p) ; \
gr_cyan_val(q) = number_to_double(p->cyan) ; \
gr_magenta_val(q) = number_to_double(p->magenta) ; \
gr_yellow_val(q) = number_to_double(p->yellow) ; \
gr_black_val(q) = number_to_double(p->black) ; \
} \

#define export_scripts(q,p)  \
if(mp_pre_script(p) !=NULL) gr_pre_script(q) = mp_xstrdup(mp,mp_str(mp,mp_pre_script(p) ) ) ; \
if(mp_post_script(p) !=NULL) gr_post_script(q) = mp_xstrdup(mp,mp_str(mp,mp_post_script(p) ) ) ; \


#line 244 "../../../source/texk/web2c/mplibdir/mp.w"
/*10:*/
#line 312 "../../../source/texk/web2c/mplibdir/mp.w"

MP_options*mp_options(void);
MP mp_initialize(MP_options*opt);

/*:10*//*50:*/
#line 975 "../../../source/texk/web2c/mplibdir/mp.w"

static char*mp_find_file(MP mp,const char*fname,const char*fmode,
int ftype);
static void*mp_open_file(MP mp,const char*fname,const char*fmode,
int ftype);
static char*mp_read_ascii_file(MP mp,void*f,size_t*size);
static void mp_read_binary_file(MP mp,void*f,void**d,size_t*size);
static void mp_close_file(MP mp,void*f);
static int mp_eof_file(MP mp,void*f);
static void mp_flush_file(MP mp,void*f);
static void mp_write_ascii_file(MP mp,void*f,const char*s);
static void mp_write_binary_file(MP mp,void*f,void*s,size_t t);
static char*mp_run_script(MP mp,const char*str);
static char*mp_make_text(MP mp,const char*str,int mode);

/*:50*//*75:*/
#line 1382 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_init_terminal(MP mp);

/*:75*//*89:*/
#line 1570 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_visible_char(MP mp,ASCII_code s);

/*:89*//*100:*/
#line 1807 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_dd(MP mp,integer n);

/*:100*//*106:*/
#line 1892 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_err(MP mp,const char*A);

/*:106*//*112:*/
#line 1968 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_get_next(MP mp);
static void mp_term_input(MP mp);
static void mp_show_context(MP mp);
static void mp_begin_file_reading(MP mp);
static void mp_open_log_file(MP mp);
static void mp_clear_for_error_prompt(MP mp);

/*:112*//*126:*/
#line 2115 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_run_editor(MP mp,char*fname,int fline);

/*:126*//*182:*/
#line 3047 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
static void do_set_mp_sym_info(MP mp,mp_node A,halfword B);
static halfword get_mp_sym_info(MP mp,mp_node p);
static void do_set_mp_sym_sym(MP mp,mp_node A,mp_sym B);
static mp_sym get_mp_sym_sym(MP mp,mp_node p);
#endif

/*:182*//*192:*/
#line 3393 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_type(MP mp,quarterword t);

/*:192*//*210:*/
#line 4401 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fix_date_and_time(MP mp);

/*:210*//*211:*/
#line 4409 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_begin_diagnostic(MP mp);
static void mp_end_diagnostic(MP mp,boolean blank_line);
static void mp_print_diagnostic(MP mp,const char*s,const char*t,
boolean nuline);

/*:211*//*219:*/
#line 4608 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
static mp_string do_get_text(MP mp,mp_sym A);
static halfword do_get_eq_type(MP mp,mp_sym A);
static halfword do_get_equiv(MP mp,mp_sym A);
static mp_node do_get_equiv_node(MP mp,mp_sym A);
static mp_sym do_get_equiv_sym(MP mp,mp_sym A);
#endif

/*:219*//*222:*/
#line 4649 "../../../source/texk/web2c/mplibdir/mp.w"

static int comp_symbols_entry(void*p,const void*pa,const void*pb);
static void*copy_symbols_entry(const void*p);
static void*delete_symbols_entry(void*p);


/*:222*//*228:*/
#line 4730 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_sym new_symbols_entry(MP mp,unsigned char*nam,size_t len);

/*:228*//*245:*/
#line 5327 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
static mp_number do_get_value_number(MP mp,mp_token_node A);
static mp_sym do_get_value_sym(MP mp,mp_token_node A);
static mp_node do_get_value_node(MP mp,mp_token_node A);
static mp_string do_get_value_str(MP mp,mp_token_node A);
static mp_knot do_get_value_knot(MP mp,mp_token_node A);
#endif
static void do_set_value_sym(MP mp,mp_token_node A,mp_sym B);
static void do_set_value_number(MP mp,mp_token_node A,mp_number B);
static void do_set_value_node(MP mp,mp_token_node A,mp_node B);
static void do_set_value_str(MP mp,mp_token_node A,mp_string B);
static void do_set_value_knot(MP mp,mp_token_node A,mp_knot B);

/*:245*//*248:*/
#line 5377 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free_token_node(MP mp,mp_node p);

/*:248*//*251:*/
#line 5461 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_show_token_list(MP mp,mp_node p,mp_node q,integer l,
integer null_tally);

/*:251*//*253:*/
#line 5571 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_capsule(MP mp,mp_node p);

/*:253*//*260:*/
#line 5768 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node do_get_subscr_head(MP mp,mp_value_node A);
static mp_node do_get_attr_head(MP mp,mp_value_node A);
static void do_set_attr_head(MP mp,mp_value_node A,mp_node d);
static void do_set_subscr_head(MP mp,mp_value_node A,mp_node d);

/*:260*//*262:*/
#line 5833 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_value_node(MP mp);
#if DEBUG >  1
static void debug_dump_value_node(mp_node x);
#endif

/*:262*//*271:*/
#line 6046 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_free_pair_node(MP mp,mp_node p);

/*:271*//*286:*/
#line 6314 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_variable_name(MP mp,mp_node p);

/*:286*//*291:*/
#line 6708 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_flush_cur_exp(MP mp,mp_value v);

/*:291*//*293:*/
#line 6764 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_flush_below_variable(MP mp,mp_node p);

/*:293*//*309:*/
#line 7219 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pr_path(MP mp,mp_knot h);

/*:309*//*317:*/
#line 7377 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_path(MP mp,mp_knot h,const char*s,boolean nuline);

/*:317*//*319:*/
#line 7390 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_new_knot(MP mp);

/*:319*//*321:*/
#line 7414 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_gr_knot mp_gr_new_knot(MP mp);

/*:321*//*333:*/
#line 7621 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_toss_knot_list(MP mp,mp_knot p);
static void mp_toss_knot(MP mp,mp_knot p);
static void mp_free_knot(MP mp,mp_knot p);

/*:333*//*354:*/
#line 8105 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_reallocate_paths(MP mp,int l);

/*:354*//*356:*/
#line 8137 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_solve_choices(MP mp,mp_knot p,mp_knot q,halfword n);

/*:356*//*366:*/
#line 8477 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_reduce_angle(MP mp,mp_number*a);


/*:366*//*371:*/
#line 8597 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_curl_ratio(MP mp,mp_number*ret,mp_number gamma,mp_number a_tension,
mp_number b_tension);

/*:371*//*377:*/
#line 8713 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_controls(MP mp,mp_knot p,mp_knot q,integer k);

/*:377*//*411:*/
#line 9952 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_solve_rising_cubic(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number x);

/*:411*//*425:*/
#line 10373 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pr_pen(MP mp,mp_knot h);

/*:425*//*429:*/
#line 10431 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_pen(MP mp,mp_knot h,const char*s,boolean nuline);

/*:429*//*440:*/
#line 10611 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_convex_hull(MP mp,mp_knot h);

/*:440*//*446:*/
#line 10702 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_move_knot(MP mp,mp_knot p,mp_knot q);

/*:446*//*475:*/
#line 11447 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_sqrt_det(MP mp,mp_number*ret,mp_number a,mp_number b,mp_number c,mp_number d);

/*:475*//*492:*/
#line 11810 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_flush_dash_list(MP mp,mp_edge_header_node h);
static mp_edge_header_node mp_toss_gr_object(MP mp,mp_node p);
static void mp_toss_edges(MP mp,mp_edge_header_node h);

/*:492*//*498:*/
#line 12007 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_copy_objects(MP mp,mp_node p,mp_node q);

/*:498*//*503:*/
#line 12177 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_edges(MP mp,mp_node h,const char*s,boolean nuline);

/*:503*//*508:*/
#line 12267 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_obj_color(MP mp,mp_node p);

/*:508*//*512:*/
#line 12384 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_dash_offset(MP mp,mp_number*x,mp_dash_node h);

/*:512*//*519:*/
#line 12517 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_x_retrace_error(MP mp);

/*:519*//*540:*/
#line 13016 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_bbox(MP mp,mp_edge_header_node h,boolean top_level);


/*:540*//*559:*/
#line 13527 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_split_cubic(MP mp,mp_knot p,mp_number t);

/*:559*//*561:*/
#line 13560 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_remove_cubic(MP mp,mp_knot p);

/*:561*//*564:*/
#line 13612 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_pen_walk(MP mp,mp_knot w,integer k);

/*:564*//*568:*/
#line 13739 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fin_offset_prep(MP mp,mp_knot p,mp_knot w,mp_number
x0,mp_number x1,mp_number x2,mp_number y0,
mp_number y1,mp_number y2,integer rise,
integer turn_amt);

/*:568*//*575:*/
#line 14111 "../../../source/texk/web2c/mplibdir/mp.w"

static integer mp_get_turn_amt(MP mp,mp_knot w,mp_number dx,
mp_number dy,boolean ccw);

/*:575*//*595:*/
#line 14813 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_insert_knot(MP mp,mp_knot q,mp_number x,mp_number y);

/*:595*//*630:*/
#line 16160 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_new_indep(MP mp,mp_node p);


/*:630*//*633:*/
#line 16232 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node get_dep_info(MP mp,mp_value_node p);

/*:633*//*635:*/
#line 16248 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free_dep_node(MP mp,mp_value_node p);

/*:635*//*639:*/
#line 16273 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_dependency(MP mp,mp_value_node p,quarterword t);

/*:639*//*644:*/
#line 16396 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_p_plus_fq(MP mp,mp_value_node p,mp_number f,
mp_value_node q,mp_variable_type t,
mp_variable_type tt);

/*:644*//*648:*/
#line 16726 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_p_over_v(MP mp,mp_value_node p,mp_number v,quarterword
t0,quarterword t1);

/*:648*//*651:*/
#line 16857 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_val_too_big(MP mp,mp_number x);

/*:651*//*653:*/
#line 16879 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_make_known(MP mp,mp_value_node p,mp_value_node q);

/*:653*//*655:*/
#line 16922 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fix_dependencies(MP mp);

/*:655*//*669:*/
#line 17350 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_ring_delete(MP mp,mp_node p);

/*:669*//*674:*/
#line 17442 "../../../source/texk/web2c/mplibdir/mp.w"

static void exclaim_redundant_equation(MP mp);

/*:674*//*678:*/
#line 17520 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_cmd_mod(MP mp,integer c,integer m);

/*:678*//*688:*/
#line 17683 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_reallocate_input_stack(MP mp,int newsize);

/*:688*//*697:*/
#line 17828 "../../../source/texk/web2c/mplibdir/mp.w"

static integer mp_true_line(MP mp);

/*:697*//*716:*/
#line 18226 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_back_input(MP mp);

/*:716*//*718:*/
#line 18243 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_back_error(MP mp,const char*msg,const char**hlp,boolean deletions_allowed);

/*:718*//*734:*/
#line 18606 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_runaway(MP mp);

/*:734*//*736:*/
#line 18634 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_firm_up_the_line(MP mp);

/*:736*//*739:*/
#line 18823 "../../../source/texk/web2c/mplibdir/mp.w"

static int move_to_next_line(MP mp);

/*:739*//*746:*/
#line 18998 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_t_next(MP mp);
static void mp_start_mpx_input(MP mp);

/*:746*//*758:*/
#line 19266 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_sym(mp_sym sym);

/*:758*//*773:*/
#line 19673 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_primary(MP mp);
static void mp_scan_secondary(MP mp);
static void mp_scan_tertiary(MP mp);
static void mp_scan_expression(MP mp);
static void mp_scan_suffix(MP mp);
static void mp_pass_text(MP mp);
static void mp_conditional(MP mp);
static void mp_start_input(MP mp);
static void mp_begin_iteration(MP mp);
static void mp_resume_iteration(MP mp);
static void mp_stop_iteration(MP mp);

/*:773*//*792:*/
#line 20222 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_get_x_next(MP mp);

/*:792*//*795:*/
#line 20274 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_macro_call(MP mp,mp_node def_ref,mp_node arg_list,
mp_sym macro_name);

/*:795*//*798:*/
#line 20323 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_macro_name(MP mp,mp_node a,mp_sym n);

/*:798*//*800:*/
#line 20347 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_arg(MP mp,mp_node q,integer n,halfword b,
quarterword bb);

/*:800*//*808:*/
#line 20531 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_text_arg(MP mp,mp_sym l_delim,mp_sym r_delim);

/*:808*//*857:*/
#line 21551 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_begin_name(MP mp);
static boolean mp_more_name(MP mp,ASCII_code c);
static void mp_end_name(MP mp);

/*:857*//*868:*/
#line 21724 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_open_mem_name(MP mp);
static boolean mp_open_mem_file(MP mp);

/*:868*//*901:*/
#line 22255 "../../../source/texk/web2c/mplibdir/mp.w"

static int mp_run_make_mpx(MP mp,char*origname,char*mtxname);

/*:901*//*908:*/
#line 22346 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_open_write_file(MP mp,char*s,readf_index n);

/*:908*//*918:*/
#line 22720 "../../../source/texk/web2c/mplibdir/mp.w"

/*927:*/
#line 22942 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_dp(MP mp,quarterword t,mp_value_node p,
quarterword verbosity){
mp_value_node q;
q= (mp_value_node)mp_link(p);
if((dep_info(q)==NULL)||(verbosity> 0))
mp_print_dependency(mp,p,t);
else
mp_print(mp,"linearform");
}


/*:927*/
#line 22721 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*915:*/
#line 22600 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_stash_cur_exp(MP mp){
mp_node p;
mp_variable_type exp_type= mp->cur_exp.type;
switch(exp_type){
case unknown_types:
case mp_transform_type:
case mp_color_type:
case mp_pair_type:
case mp_dependent:
case mp_proto_dependent:
case mp_independent:
case mp_cmykcolor_type:
p= cur_exp_node();
break;

default:
p= mp_get_value_node(mp);
mp_name_type(p)= mp_capsule;
mp_type(p)= mp->cur_exp.type;
set_value_number(p,cur_exp_value_number());
if(cur_exp_str()){
set_value_str(p,cur_exp_str());
}else if(cur_exp_knot()){
set_value_knot(p,cur_exp_knot());
}else if(cur_exp_node()){
set_value_node(p,cur_exp_node());
}
break;
}
mp->cur_exp.type= mp_vacuous;
mp_link(p)= MP_VOID;
return p;
}


/*:915*//*916:*/
#line 22656 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_unstash_cur_exp(MP mp,mp_node p);

/*:916*/
#line 22722 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_print_exp(MP mp,mp_node p,quarterword verbosity);

/*:918*//*929:*/
#line 22973 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_disp_err(MP mp,mp_node p);

/*:929*//*933:*/
#line 23030 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_recycle_value(MP mp,mp_node p);

/*:933*//*936:*/
#line 23336 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_show_transformed_dependency(MP mp,mp_number v,mp_variable_type t,mp_node p);

/*:936*//*962:*/
#line 24884 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_known_pair(MP mp);

/*:962*//*966:*/
#line 25088 "../../../source/texk/web2c/mplibdir/mp.w"

static void do_boolean_error(MP mp);

/*:966*//*979:*/
#line 26142 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_color_part(MP mp,quarterword c);

/*:979*//*984:*/
#line 26257 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_scale_edges(MP mp,mp_number se_sf,mp_edge_header_node se_pic);

/*:984*//*1045:*/
#line 29591 "../../../source/texk/web2c/mplibdir/mp.w"

/*1060:*/
#line 30254 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_type_declaration(MP mp);

/*:1060*//*1086:*/
#line 30927 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_random_seed(MP mp);
/*:1086*//*1095:*/
#line 31021 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_protection(MP mp);

/*:1095*//*1098:*/
#line 31049 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_def_delims(MP mp);

/*:1098*//*1103:*/
#line 31103 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_statement(MP mp);
static void mp_do_interim(MP mp);

/*:1103*//*1105:*/
#line 31130 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_let(MP mp);

/*:1105*//*1113:*/
#line 31291 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_show(MP mp);

/*:1113*//*1115:*/
#line 31310 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_disp_token(MP mp);

/*:1115*//*1119:*/
#line 31392 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_show_token(MP mp);

/*:1119*//*1121:*/
#line 31405 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_show_stats(MP mp);

/*:1121*//*1123:*/
#line 31426 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_disp_var(MP mp,mp_node p);

/*:1123*//*1127:*/
#line 31476 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_show_var(MP mp);

/*:1127*//*1129:*/
#line 31497 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_show_dependencies(MP mp);

/*:1129*//*1131:*/
#line 31526 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_show_whatever(MP mp);

/*:1131*//*1136:*/
#line 31643 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_with_list(MP mp,mp_node p);

/*:1136*//*1138:*/
#line 32014 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_find_edges_var(MP mp,mp_node t);

/*:1138*//*1143:*/
#line 32088 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_start_draw_cmd(MP mp,quarterword sep);

/*:1143*//*1145:*/
#line 32128 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_bounds(MP mp);

/*:1145*//*1147:*/
#line 32189 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_add_to(MP mp);

/*:1147*//*1149:*/
#line 32302 "../../../source/texk/web2c/mplibdir/mp.w"

/*1281:*/
#line 34936 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_ship_out(MP mp,mp_node h);

/*:1281*/
#line 32303 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_do_ship_out(MP mp);

/*:1149*//*1157:*/
#line 32394 "../../../source/texk/web2c/mplibdir/mp.w"

/*1160:*/
#line 32444 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_no_string_err(MP mp,const char*s){
const char*hlp[]= {s,NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Not a string",hlp,true);
;
mp_get_x_next(mp);
}


/*:1160*/
#line 32395 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_do_message(MP mp);

/*:1157*//*1165:*/
#line 32507 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_write(MP mp);

/*:1165*//*1189:*/
#line 33070 "../../../source/texk/web2c/mplibdir/mp.w"

static eight_bits mp_get_code(MP mp);

/*:1189*//*1191:*/
#line 33107 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_tag(MP mp,halfword c,quarterword t,halfword r);

/*:1191*//*1194:*/
#line 33153 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_tfm_command(MP mp);

/*:1194*//*1256:*/
#line 34500 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_mapfile(MP mp);
static void mp_do_mapline(MP mp);

/*:1256*//*1276:*/
#line 34885 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_special(MP mp);

/*:1276*/
#line 29592 "../../../source/texk/web2c/mplibdir/mp.w"



/*:1045*//*1048:*/
#line 29661 "../../../source/texk/web2c/mplibdir/mp.w"

/*1052:*/
#line 29849 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_make_eq(MP mp,mp_node lhs);

/*:1052*/
#line 29662 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_do_equation(MP mp);

/*:1048*//*1050:*/
#line 29702 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_assignment(MP mp);

/*:1050*//*1054:*/
#line 30022 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_try_eq(MP mp,mp_node l,mp_node r);

/*:1054*//*1056:*/
#line 30167 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_scan_declared_variable(MP mp);

/*:1056*//*1068:*/
#line 30459 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_reset_stream(mp_stream*str);
static void mp_free_stream(mp_stream*str);

/*:1068*//*1071:*/
#line 30481 "../../../source/texk/web2c/mplibdir/mp.w"

static void*mplib_open_file(MP mp,const char*fname,const char*fmode,
int ftype);
static int mplib_get_char(void*f,mp_run_data*mplib_data);
static void mplib_unget_char(void*f,mp_run_data*mplib_data,int c);
static char*mplib_read_ascii_file(MP mp,void*ff,size_t*size);
static void mplib_write_ascii_file(MP mp,void*ff,const char*s);
static void mplib_read_binary_file(MP mp,void*ff,void**data,
size_t*size);
static void mplib_write_binary_file(MP mp,void*ff,void*s,size_t size);
static void mplib_close_file(MP mp,void*ff);
static int mplib_eof_file(MP mp,void*ff);
static void mplib_flush_file(MP mp,void*ff);
static void mplib_shipout_backend(MP mp,void*h);

/*:1071*//*1100:*/
#line 31070 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_check_delimiter(MP mp,mp_sym l_delim,mp_sym r_delim);

/*:1100*//*1107:*/
#line 31177 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_new_internal(MP mp);

/*:1107*//*1183:*/
#line 32973 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_tfm_check(MP mp,quarterword m);

/*:1183*//*1246:*/
#line 34360 "../../../source/texk/web2c/mplibdir/mp.w"

static font_number mp_find_font(MP mp,char*f);

/*:1246*//*1250:*/
#line 34414 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_lost_warning(MP mp,font_number f,int k);

/*:1250*//*1252:*/
#line 34438 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_text_box(MP mp,mp_text_node p);

/*:1252*//*1284:*/
#line 35170 "../../../source/texk/web2c/mplibdir/mp.w"

struct mp_edge_object*mp_gr_export(MP mp,mp_edge_header_node h);
mp_edge_header_node mp_gr_import(MP mp,struct mp_edge_object*h);

/*:1284*//*1286:*/
#line 35188 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_shipout_backend(MP mp,void*h);

/*:1286*//*1295:*/
#line 35254 "../../../source/texk/web2c/mplibdir/mp.w"

extern boolean mp_load_preload_file(MP mp);

/*:1295*//*1300:*/
#line 35390 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_close_files_and_terminate(MP mp);

/*:1300*//*1308:*/
#line 35545 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_final_cleanup(MP mp);
static void mp_init_prim(MP mp);
static void mp_init_tab(MP mp);

/*:1308*/
#line 244 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*90:*/
#line 1573 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_ln(MP mp){
switch(mp->selector){
case term_and_log:
wterm_cr;
wlog_cr;
mp->term_offset= 0;
mp->file_offset= 0;
break;
case log_only:
wlog_cr;
mp->file_offset= 0;
break;
case term_only:
wterm_cr;
mp->term_offset= 0;
break;
case no_print:
case pseudo:
case new_string:
break;
default:
mp_fputs("\n",mp->wr_file[(mp->selector-write_file)]);
}
}


/*:90*//*91:*/
#line 1609 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_visible_char(MP mp,ASCII_code s){
switch(mp->selector){
case term_and_log:
wterm_chr(xchr(s));
wlog_chr(xchr(s));
incr(mp->term_offset);
incr(mp->file_offset);
if(mp->term_offset==(unsigned)mp->max_print_line){
wterm_cr;
mp->term_offset= 0;
};
if(mp->file_offset==(unsigned)mp->max_print_line){
wlog_cr;
mp->file_offset= 0;
};
break;
case log_only:
wlog_chr(xchr(s));
incr(mp->file_offset);
if(mp->file_offset==(unsigned)mp->max_print_line)
mp_print_ln(mp);
break;
case term_only:
wterm_chr(xchr(s));
incr(mp->term_offset);
if(mp->term_offset==(unsigned)mp->max_print_line)
mp_print_ln(mp);
break;
case no_print:
break;
case pseudo:
if(mp->tally<mp->trick_count)
mp->trick_buf[mp->tally%mp->error_line]= s;
break;
case new_string:
append_char(s);
break;
default:
{
text_char ss[2]= {0,0};
ss[0]= xchr(s);
mp_fputs((char*)ss,mp->wr_file[(mp->selector-write_file)]);
}
}
incr(mp->tally);
}


/*:91*//*92:*/
#line 1666 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_char(MP mp,ASCII_code k){
if(mp->utf8_mode||mp->selector<pseudo||mp->selector>=write_file){
mp_print_visible_char(mp,k);
}else if(/*83:*/
#line 1523 "../../../source/texk/web2c/mplibdir/mp.w"

(k<' ')||(k==127)

/*:83*/
#line 1670 "../../../source/texk/web2c/mplibdir/mp.w"
){
mp_print(mp,"^^");
if(k<0100){
mp_print_visible_char(mp,(ASCII_code)(k+0100));
}else if(k<0200){
mp_print_visible_char(mp,(ASCII_code)(k-0100));
}else{
int l;
l= (k/16);
mp_print_visible_char(mp,xord(l<10?l+'0':l-10+'a'));
l= (k%16);
mp_print_visible_char(mp,xord(l<10?l+'0':l-10+'a'));
}
}else{
mp_print_visible_char(mp,k);
}
}


/*:92*//*93:*/
#line 1697 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_print(MP mp,const char*ss,size_t len){
if(len==0)
return;
if(mp->selector==new_string){
str_room(len);
memcpy((mp->cur_string+mp->cur_length),ss,len);
mp->cur_length+= len;
}else{
size_t j= 0;
while(j<len){

mp_print_char(mp,(ASCII_code)ss[j]);
j++;
}
}
}


/*:93*//*94:*/
#line 1717 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print(MP mp,const char*ss){
assert(ss!=NULL);
mp_do_print(mp,ss,strlen(ss));
}
void mp_printf(MP mp,const char*ss,...){
va_list ap;
char pval[256];
assert(ss!=NULL);
va_start(ap,ss);
vsnprintf(pval,256,ss,ap);
mp_do_print(mp,pval,strlen(pval));
va_end(ap);
}

void mp_print_str(MP mp,mp_string s){
assert(s!=NULL);
mp_do_print(mp,(const char*)s->str,s->len);
}


/*:94*//*96:*/
#line 1752 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_nl(MP mp,const char*s){
switch(mp->selector){
case term_and_log:
if((mp->term_offset> 0)||(mp->file_offset> 0))
mp_print_ln(mp);
break;
case log_only:
if(mp->file_offset> 0)
mp_print_ln(mp);
break;
case term_only:
if(mp->term_offset> 0)
mp_print_ln(mp);
break;
case no_print:
case pseudo:
case new_string:
break;
}
mp_print(mp,s);
}


/*:96*//*97:*/
#line 1780 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_int(MP mp,integer n){
char s[12];
mp_snprintf(s,12,"%d",(int)n);
mp_print(mp,s);
}
void mp_print_pointer(MP mp,void*n){
char s[12];
mp_snprintf(s,12,"%p",n);
mp_print(mp,s);
}

/*:97*//*152:*/
#line 2567 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_two(MP mp,mp_number x,mp_number y){
mp_print_char(mp,xord('('));
print_number(x);
mp_print_char(mp,xord(','));
print_number(y);
mp_print_char(mp,xord(')'));
}


/*:152*//*193:*/
#line 3396 "../../../source/texk/web2c/mplibdir/mp.w"

static const char*mp_type_string(quarterword t){
const char*s= NULL;
switch(t){
case mp_undefined:
s= "undefined";
break;
case mp_vacuous:
s= "vacuous";
break;
case mp_boolean_type:
s= "boolean";
break;
case mp_unknown_boolean:
s= "unknown boolean";
break;
case mp_string_type:
s= "string";
break;
case mp_unknown_string:
s= "unknown string";
break;
case mp_pen_type:
s= "pen";
break;
case mp_unknown_pen:
s= "unknown pen";
break;
case mp_path_type:
s= "path";
break;
case mp_unknown_path:
s= "unknown path";
break;
case mp_picture_type:
s= "picture";
break;
case mp_unknown_picture:
s= "unknown picture";
break;
case mp_transform_type:
s= "transform";
break;
case mp_color_type:
s= "color";
break;
case mp_cmykcolor_type:
s= "cmykcolor";
break;
case mp_pair_type:
s= "pair";
break;
case mp_known:
s= "known numeric";
break;
case mp_dependent:
s= "dependent";
break;
case mp_proto_dependent:
s= "proto-dependent";
break;
case mp_numeric_type:
s= "numeric";
break;
case mp_independent:
s= "independent";
break;
case mp_token_list:
s= "token list";
break;
case mp_structured:
s= "mp_structured";
break;
case mp_unsuffixed_macro:
s= "unsuffixed macro";
break;
case mp_suffixed_macro:
s= "suffixed macro";
break;
case mp_symbol_node:
s= "symbol node";
break;
case mp_token_node_type:
s= "token node";
break;
case mp_value_node_type:
s= "value node";
break;
case mp_attr_node_type:
s= "attribute node";
break;
case mp_subscr_node_type:
s= "subscript node";
break;
case mp_pair_node_type:
s= "pair node";
break;
case mp_transform_node_type:
s= "transform node";
break;
case mp_color_node_type:
s= "color node";
break;
case mp_cmykcolor_node_type:
s= "cmykcolor node";
break;
case mp_fill_node_type:
s= "fill node";
break;
case mp_stroked_node_type:
s= "stroked node";
break;
case mp_text_node_type:
s= "text node";
break;
case mp_start_clip_node_type:
s= "start clip node";
break;
case mp_start_bounds_node_type:
s= "start bounds node";
break;
case mp_stop_clip_node_type:
s= "stop clip node";
break;
case mp_stop_bounds_node_type:
s= "stop bounds node";
break;
case mp_dash_node_type:
s= "dash node";
break;
case mp_dep_node_type:
s= "dependency node";
break;
case mp_if_node_type:
s= "if node";
break;
case mp_edge_header_node_type:
s= "edge header node";
break;
default:
{
char ss[256];
mp_snprintf(ss,256,"<unknown type %d>",t);
s= strdup(ss);
}
break;
}
return s;
}
void mp_print_type(MP mp,quarterword t){
if(t>=0&&t<=mp_edge_header_node_type)
mp_print(mp,mp_type_string(t));
else
mp_print(mp,"unknown");
}


/*:193*//*212:*/
#line 4415 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_begin_diagnostic(MP mp){
mp->old_setting= mp->selector;
if(number_nonpositive(internal_value(mp_tracing_online))
&&(mp->selector==term_and_log)){
decr(mp->selector);
if(mp->history==mp_spotless)
mp->history= mp_warning_issued;
}
}

void mp_end_diagnostic(MP mp,boolean blank_line){

mp_print_nl(mp,"");
if(blank_line)
mp_print_ln(mp);
mp->selector= mp->old_setting;
}


/*:212*//*214:*/
#line 4444 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_diagnostic(MP mp,const char*s,const char*t,boolean nuline){
mp_begin_diagnostic(mp);
if(nuline)
mp_print_nl(mp,s);
else
mp_print(mp,s);
mp_print(mp," at line ");
mp_print_int(mp,mp_true_line(mp));
mp_print(mp,t);
mp_print_char(mp,xord(':'));
}


/*:214*//*861:*/
#line 21630 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_file_name(MP mp,char*n,char*a,char*e){
boolean must_quote= false;
if(((a!=NULL)&&(strchr(a,' ')!=NULL))||
((n!=NULL)&&(strchr(n,' ')!=NULL))||
((e!=NULL)&&(strchr(e,' ')!=NULL)))
must_quote= true;
if(must_quote)
mp_print_char(mp,(ASCII_code)'"');
mp_print(mp,a);
mp_print(mp,n);
mp_print(mp,e);
if(must_quote)
mp_print_char(mp,(ASCII_code)'"');
}


/*:861*/
#line 245 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*117:*/
#line 2002 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_jump_out(MP mp){
if(mp->internal!=NULL&&mp->history<mp_system_error_stop)
mp_close_files_and_terminate(mp);
longjmp(*(mp->jump_buf),1);
}

/*:117*//*119:*/
#line 2014 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_warn(MP mp,const char*msg){
unsigned saved_selector= mp->selector;
mp_normalize_selector(mp);
mp_print_nl(mp,"Warning: ");
mp_print(mp,msg);
mp_print_ln(mp);
mp->selector= saved_selector;
}

/*:119*//*137:*/
#line 2360 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_fatal_error(MP mp,const char*s){
const char*hlp[]= {s,NULL};
mp_normalize_selector(mp);
if(mp->interaction==mp_error_stop_mode)
mp->interaction= mp_scroll_mode;
if(mp->log_opened)
mp_error(mp,"Emergency stop",hlp,true);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);

}


/*:137*//*140:*/
#line 2382 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_overflow(MP mp,const char*s,integer n){
char msg[256];
const char*hlp[]= {
"If you really absolutely need more capacity,",
"you can ask a wizard to enlarge me.",
NULL};
mp_normalize_selector(mp);
mp_snprintf(msg,256,"MetaPost capacity exceeded, sorry [%s=%d]",s,(int)n);
;
if(mp->interaction==mp_error_stop_mode)
mp->interaction= mp_scroll_mode;
if(mp->log_opened)
mp_error(mp,msg,hlp,true);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}


/*:140*//*142:*/
#line 2413 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_confusion(MP mp,const char*s){
char msg[256];
const char*hlp[]= {
"One of your faux pas seems to have wounded me deeply...",
"in fact, I'm barely conscious. Please fix it and try again.",
NULL};
mp_normalize_selector(mp);
if(mp->history<mp_error_message_issued){
mp_snprintf(msg,256,"This can't happen (%s)",s);
;
hlp[0]= "I'm broken. Please show this to someone who can fix can fix";
hlp[1]= NULL;
}else{
mp_snprintf(msg,256,"I can\'t go on meeting you like this");
;
}
if(mp->interaction==mp_error_stop_mode)
mp->interaction= mp_scroll_mode;
if(mp->log_opened)
mp_error(mp,msg,hlp,true);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}


/*:142*/
#line 246 "../../../source/texk/web2c/mplibdir/mp.w"


/*:7*//*9:*/
#line 281 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
void do_debug_printf(MP mp,const char*prefix,const char*fmt,...);
void do_debug_printf(MP mp,const char*prefix,const char*fmt,...){
va_list ap;
#if 0
va_start(ap,fmt);
if(mp->log_file&&!ferror((FILE*)mp->log_file)){
fputs(prefix,mp->log_file);
vfprintf(mp->log_file,fmt,ap);
}
va_end(ap);
#endif
va_start(ap,fmt);
#if 0
if(mp->term_out&&!ferror((FILE*)mp->term_out)){
#else
if(false){
#endif
fputs(prefix,mp->term_out);
vfprintf(mp->term_out,fmt,ap);
}else{
fputs(prefix,stdout);
vfprintf(stdout,fmt,ap);
}
va_end(ap);
}
#endif

/*:9*//*11:*/
#line 316 "../../../source/texk/web2c/mplibdir/mp.w"

MP_options*mp_options(void){
MP_options*opt;
size_t l= sizeof(MP_options);
opt= malloc(l);
if(opt!=NULL){
memset(opt,0,l);
}
return opt;
}


/*:11*//*13:*/
#line 340 "../../../source/texk/web2c/mplibdir/mp.w"

static MP mp_do_new(jmp_buf*buf){
MP mp= malloc(sizeof(MP_instance));
if(mp==NULL){
xfree(buf);
return NULL;
}
memset(mp,0,sizeof(MP_instance));
mp->jump_buf= buf;
return mp;
}


/*:13*//*14:*/
#line 353 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free(MP mp){
int k;
/*30:*/
#line 746 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->banner);

/*:30*//*67:*/
#line 1191 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->buffer);

/*:67*//*80:*/
#line 1426 "../../../source/texk/web2c/mplibdir/mp.w"

mp_dealloc_strings(mp);

/*:80*//*85:*/
#line 1529 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->trick_buf);

/*:85*//*158:*/
#line 2624 "../../../source/texk/web2c/mplibdir/mp.w"

{
int i;
for(i= 0;i<55;i++){
free_number(mp->randoms[i]);
}
}

/*:158*//*173:*/
#line 2874 "../../../source/texk/web2c/mplibdir/mp.w"

while(mp->value_nodes){
mp_node p= mp->value_nodes;
mp->value_nodes= p->link;
mp_free_node(mp,p,value_node_size);
}
while(mp->symbolic_nodes){
mp_node p= mp->symbolic_nodes;
mp->symbolic_nodes= p->link;
mp_free_node(mp,p,symbolic_node_size);
}
while(mp->pair_nodes){
mp_node p= mp->pair_nodes;
mp->pair_nodes= p->link;
mp_free_node(mp,p,pair_node_size);
}
while(mp->token_nodes){
mp_node p= mp->token_nodes;
mp->token_nodes= p->link;
mp_free_node(mp,p,token_node_size);
}
while(mp->knot_nodes){
mp_knot p= mp->knot_nodes;
mp->knot_nodes= p->next;
mp_free_knot(mp,p);
}

/*:173*//*227:*/
#line 4721 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->symbols!=NULL)
avl_destroy(mp->symbols);
if(mp->frozen_symbols!=NULL)
avl_destroy(mp->frozen_symbols);

/*:227*//*348:*/
#line 7936 "../../../source/texk/web2c/mplibdir/mp.w"

{
int k;
for(k= 0;k<mp->path_size;k++){
free_number(mp->delta_x[k]);
free_number(mp->delta_y[k]);
free_number(mp->delta[k]);
free_number(mp->psi[k]);
}
xfree(mp->delta_x);
xfree(mp->delta_y);
xfree(mp->delta);
xfree(mp->psi);
}

/*:348*//*353:*/
#line 8090 "../../../source/texk/web2c/mplibdir/mp.w"

{
int k;
for(k= 0;k<mp->path_size;k++){
free_number(mp->theta[k]);
free_number(mp->uu[k]);
free_number(mp->vv[k]);
free_number(mp->ww[k]);
}
xfree(mp->theta);
xfree(mp->uu);
xfree(mp->vv);
xfree(mp->ww);
}

/*:353*//*376:*/
#line 8706 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->st);
free_number(mp->ct);
free_number(mp->sf);
free_number(mp->cf);


/*:376*//*393:*/
#line 9323 "../../../source/texk/web2c/mplibdir/mp.w"

{
int i;
for(i= 0;i<=mp_y_code;i++){
free_number(mp->bbmin[i]);
free_number(mp->bbmax[i]);
}
}


/*:393*//*439:*/
#line 10598 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<=7;k++){
free_number(mp->half_cos[k]);
free_number(mp->d_cos[k]);
}


/*:439*//*456:*/
#line 10900 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->cur_x);
free_number(mp->cur_y);

/*:456*//*615:*/
#line 15701 "../../../source/texk/web2c/mplibdir/mp.w"

{
int i;
for(i= 0;i<bistack_size+1;i++){
free_number(mp->bisect_stack[i]);
}
}
xfree(mp->bisect_stack);

/*:615*//*620:*/
#line 15786 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->cur_t);
free_number(mp->cur_tt);
free_number(mp->max_t);

/*:620*//*624:*/
#line 15944 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->delx);
free_number(mp->dely);
free_number(mp->appr_t);
free_number(mp->appr_tt);

/*:624*//*684:*/
#line 17576 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->input_stack);

/*:684*//*691:*/
#line 17712 "../../../source/texk/web2c/mplibdir/mp.w"

{
int l;
for(l= 0;l<=mp->max_in_open;l++){
xfree(mp->inext_stack[l]);
xfree(mp->iname_stack[l]);
xfree(mp->iarea_stack[l]);
}
}
xfree(mp->input_file);
xfree(mp->line_stack);
xfree(mp->inext_stack);
xfree(mp->iname_stack);
xfree(mp->iarea_stack);
xfree(mp->mpx_name);


/*:691*//*696:*/
#line 17818 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->param_stack);

/*:696*//*855:*/
#line 21526 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->cur_area);
xfree(mp->cur_name);
xfree(mp->cur_ext);

/*:855*//*867:*/
#line 21716 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->mem_name);

/*:867*//*881:*/
#line 21920 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->job_name);

/*:881*//*888:*/
#line 22053 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->log_name);

/*:888*//*940:*/
#line 23385 "../../../source/texk/web2c/mplibdir/mp.w"

{
int i;
for(i= 0;i<mp_proto_dependent+1;i++){
free_number(mp->max_c[i]);
}
}

/*:940*//*1076:*/
#line 30749 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_stream(&(mp->run_data.term_in));
mp_free_stream(&(mp->run_data.term_out));
mp_free_stream(&(mp->run_data.log_out));
mp_free_stream(&(mp->run_data.error_out));
mp_free_stream(&(mp->run_data.ship_out));

/*:1076*//*1110:*/
#line 31236 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<=mp->max_internal;k++){
free_number(mp->internal[k].v.data.n);
xfree(internal_name(k));
}
xfree(mp->internal);


/*:1110*//*1181:*/
#line 32931 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->header_byte);
xfree(mp->lig_kern);
if(mp->kern){
int i;
for(i= 0;i<(max_tfm_int+1);i++){
free_number(mp->kern[i]);
}
xfree(mp->kern);
}
if(mp->param){
int i;
for(i= 0;i<(max_tfm_int+1);i++){
free_number(mp->param[i]);
}
xfree(mp->param);
}

/*:1181*//*1211:*/
#line 33607 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->perturbation);

/*:1211*//*1225:*/
#line 33904 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->max_tfm_dimen);


/*:1225*//*1241:*/
#line 34249 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 1;k<=(int)mp->last_fnum;k++){
xfree(mp->font_enc_name[k]);
xfree(mp->font_name[k]);
xfree(mp->font_ps_name[k]);
}
for(k= 0;k<=255;k++){








}

xfree(mp->font_info);
xfree(mp->font_enc_name);
xfree(mp->font_ps_name_fixed);
xfree(mp->font_dsize);
xfree(mp->font_name);
xfree(mp->font_ps_name);
xfree(mp->font_bc);
xfree(mp->font_ec);
xfree(mp->char_base);
xfree(mp->width_base);
xfree(mp->height_base);
xfree(mp->depth_base);
xfree(mp->font_sizes);

/*:1241*//*1269:*/
#line 34823 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->first_file_name);
xfree(mp->last_file_name);

/*:1269*//*1293:*/
#line 35234 "../../../source/texk/web2c/mplibdir/mp.w"

mp_ps_backend_free(mp);
mp_svg_backend_free(mp);
mp_png_backend_free(mp);


/*:1293*//*1302:*/
#line 35411 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<(int)mp->max_read_files;k++){
if(mp->rd_fname[k]!=NULL){
(mp->close_file)(mp,mp->rd_file[k]);
xfree(mp->rd_fname[k]);
}
}
xfree(mp->rd_file);
xfree(mp->rd_fname);
for(k= 0;k<(int)mp->max_write_files;k++){
if(mp->wr_fname[k]!=NULL){
(mp->close_file)(mp,mp->wr_file[k]);
xfree(mp->wr_fname[k]);
}
}
xfree(mp->wr_file);
xfree(mp->wr_fname);


/*:1302*/
#line 356 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp->noninteractive){
/*1077:*/
#line 30756 "../../../source/texk/web2c/mplibdir/mp.w"

xfree(mp->term_out);
xfree(mp->term_in);
xfree(mp->err_out);

/*:1077*/
#line 358 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
xfree(mp->jump_buf);
/*188:*/
#line 3168 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_symbolic_node(mp,mp->spec_head);
mp_free_symbolic_node(mp,mp->temp_head);
mp_free_symbolic_node(mp,mp->hold_head);

/*:188*//*266:*/
#line 5986 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_attr_node(mp,mp->end_attr);

/*:266*//*487:*/
#line 11689 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_node(mp,(mp_node)mp->null_dash,dash_node_size);

/*:487*//*637:*/
#line 16259 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_dep_node(mp,mp->dep_head);

/*:637*//*677:*/
#line 17509 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_symbolic_node(mp,mp->cur_mod_);

/*:677*//*772:*/
#line 19647 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_value_node(mp,mp->bad_vardef);


/*:772*//*913:*/
#line 22450 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->cur_exp.data.n);

/*:913*//*983:*/
#line 26253 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_value_node(mp,mp->temp_val);


/*:983*//*1013:*/
#line 28345 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(mp->txx);
free_number(mp->txy);
free_number(mp->tyx);
free_number(mp->tyy);
free_number(mp->tx);
free_number(mp->ty);


/*:1013*//*1206:*/
#line 33521 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_value_node(mp,mp->inf_val);

/*:1206*//*1220:*/
#line 33803 "../../../source/texk/web2c/mplibdir/mp.w"

mp_free_value_node(mp,mp->zero_val);

/*:1220*/
#line 361 "../../../source/texk/web2c/mplibdir/mp.w"
;
free_math();
xfree(mp);
}


/*:14*//*15:*/
#line 367 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_initialize(MP mp){
/*38:*/
#line 819 "../../../source/texk/web2c/mplibdir/mp.w"

integer i;

/*:38*//*154:*/
#line 2586 "../../../source/texk/web2c/mplibdir/mp.w"

integer k;

/*:154*/
#line 369 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*41:*/
#line 848 "../../../source/texk/web2c/mplibdir/mp.w"

for(i= 0;i<=0377;i++){
xchr(i)= (text_char)i;
}


/*:41*//*42:*/
#line 860 "../../../source/texk/web2c/mplibdir/mp.w"

for(i= 0;i<=255;i++){
xord(xchr(i))= 0177;
}
for(i= 0200;i<=0377;i++){
xord(xchr(i))= (ASCII_code)i;
}
for(i= 0;i<=0176;i++){
xord(xchr(i))= (ASCII_code)i;
}


/*:42*//*204:*/
#line 4162 "../../../source/texk/web2c/mplibdir/mp.w"

mp->int_ptr= max_given_internal;

/*:204*//*216:*/
#line 4488 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= '0';k<='9';k++)
mp->char_class[k]= digit_class;
mp->char_class['.']= period_class;
mp->char_class[' ']= space_class;
mp->char_class['%']= percent_class;
mp->char_class['"']= string_class;
mp->char_class[',']= 5;
mp->char_class[';']= 6;
mp->char_class['(']= 7;
mp->char_class[')']= right_paren_class;
for(k= 'A';k<='Z';k++)
mp->char_class[k]= letter_class;
for(k= 'a';k<='z';k++)
mp->char_class[k]= letter_class;
mp->char_class['_']= letter_class;
mp->char_class['<']= 10;
mp->char_class['=']= 10;
mp->char_class['>']= 10;
mp->char_class[':']= 10;
mp->char_class['|']= 10;
mp->char_class['`']= 11;
mp->char_class['\'']= 11;
mp->char_class['+']= 12;
mp->char_class['-']= 12;
mp->char_class['/']= 13;
mp->char_class['*']= 13;
mp->char_class['\\']= 13;
mp->char_class['!']= 14;
mp->char_class['?']= 14;
mp->char_class['#']= 15;
mp->char_class['&']= 15;
mp->char_class['@']= 15;
mp->char_class['$']= 15;
mp->char_class['^']= 16;
mp->char_class['~']= 16;
mp->char_class['[']= mp_left_bracket_class;
mp->char_class[']']= mp_right_bracket_class;
mp->char_class['{']= 19;
mp->char_class['}']= 19;
for(k= 0;k<' ';k++)
mp->char_class[k]= invalid_class;
mp->char_class['\t']= space_class;
mp->char_class['\f']= space_class;
for(i= 127;i<=255;i++){
mp->char_class[i]= mp->utf8_mode?letter_class:invalid_class;
}

/*:216*//*299:*/
#line 6917 "../../../source/texk/web2c/mplibdir/mp.w"

mp->save_ptr= NULL;

/*:299*//*438:*/
#line 10576 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<=7;k++){
new_fraction(mp->half_cos[k]);
new_fraction(mp->d_cos[k]);
}
number_clone(mp->half_cos[0],fraction_half_t);
number_clone(mp->half_cos[1],twentysixbits_sqrt2_t);
number_clone(mp->half_cos[2],zero_t);
number_clone(mp->d_cos[0],twentyeightbits_d_t);
number_clone(mp->d_cos[1],twentysevenbits_sqrt2_d_t);
number_clone(mp->d_cos[2],zero_t);
for(k= 3;k<=4;k++){
number_clone(mp->half_cos[k],mp->half_cos[4-k]);
number_negate(mp->half_cos[k]);
number_clone(mp->d_cos[k],mp->d_cos[4-k]);
number_negate(mp->d_cos[k]);
}
for(k= 5;k<=7;k++){
number_clone(mp->half_cos[k],mp->half_cos[8-k]);
number_clone(mp->d_cos[k],mp->d_cos[8-k]);
}

/*:438*//*554:*/
#line 13429 "../../../source/texk/web2c/mplibdir/mp.w"

mp->spec_p1= NULL;
mp->spec_p2= NULL;

/*:554*//*643:*/
#line 16369 "../../../source/texk/web2c/mplibdir/mp.w"

mp->fix_needed= false;
mp->watch_coefs= true;

/*:643*//*775:*/
#line 19702 "../../../source/texk/web2c/mplibdir/mp.w"

mp->expand_depth= 10000;

/*:775*//*820:*/
#line 20773 "../../../source/texk/web2c/mplibdir/mp.w"

mp->cond_ptr= NULL;
mp->if_limit= normal;
mp->cur_if= 0;
mp->if_line= 0;

/*:820*//*835:*/
#line 21069 "../../../source/texk/web2c/mplibdir/mp.w"

mp->loop_ptr= NULL;

/*:835*//*854:*/
#line 21521 "../../../source/texk/web2c/mplibdir/mp.w"

mp->cur_name= xstrdup("");
mp->cur_area= xstrdup("");
mp->cur_ext= xstrdup("");

/*:854*//*912:*/
#line 22446 "../../../source/texk/web2c/mplibdir/mp.w"

memset(&mp->cur_exp.data,0,sizeof(mp_value));
new_number(mp->cur_exp.data.n);

/*:912*//*942:*/
#line 23415 "../../../source/texk/web2c/mplibdir/mp.w"

mp->var_flag= 0;

/*:942*//*999:*/
#line 27143 "../../../source/texk/web2c/mplibdir/mp.w"

mp->eof_line= mp_rtsl(mp,"\0",1);
mp->eof_line->refs= MAX_STR_REF;

/*:999*//*1154:*/
#line 32346 "../../../source/texk/web2c/mplibdir/mp.w"

mp->start_sym= NULL;

/*:1154*//*1163:*/
#line 32477 "../../../source/texk/web2c/mplibdir/mp.w"

mp->long_help_seen= false;

/*:1163*//*1182:*/
#line 32949 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<=255;k++){
mp->tfm_width[k]= 0;
mp->tfm_height[k]= 0;
mp->tfm_depth[k]= 0;
mp->tfm_ital_corr[k]= 0;
mp->char_exists[k]= false;
mp->char_tag[k]= no_tag;
mp->char_remainder[k]= 0;
mp->skip_table[k]= undefined_label;
}
memset(mp->header_byte,0,(size_t)mp->header_size);
mp->bc= 255;
mp->ec= 0;
mp->nl= 0;
mp->nk= 0;
mp->ne= 0;
mp->np= 0;
set_internal_from_number(mp_boundary_char,unity_t);
number_negate(internal_value(mp_boundary_char));
mp->bch_label= undefined_label;
mp->label_loc[0]= -1;
mp->label_ptr= 0;

/*:1182*//*1244:*/
#line 34318 "../../../source/texk/web2c/mplibdir/mp.w"

mp->font_dsize[null_font]= 0;
mp->font_bc[null_font]= 1;
mp->font_ec[null_font]= 0;
mp->char_base[null_font]= 0;
mp->width_base[null_font]= 0;
mp->height_base[null_font]= 0;
mp->depth_base[null_font]= 0;
mp->next_fmem= 0;
mp->last_fnum= null_font;
mp->last_ps_fnum= null_font;
{
static char nullfont_name[]= "nullfont";
static char nullfont_psname[]= "";
mp->font_name[null_font]= nullfont_name;
mp->font_ps_name[null_font]= nullfont_psname;
}
mp->font_ps_name_fixed[null_font]= false;
mp->font_enc_name[null_font]= NULL;
mp->font_sizes[null_font]= NULL;

/*:1244*//*1260:*/
#line 34543 "../../../source/texk/web2c/mplibdir/mp.w"

mp->ten_pow[0]= 1;
for(i= 1;i<=9;i++){
mp->ten_pow[i]= 10*mp->ten_pow[i-1];
}


/*:1260*//*1268:*/
#line 34816 "../../../source/texk/web2c/mplibdir/mp.w"

mp->first_file_name= xstrdup("");
mp->last_file_name= xstrdup("");
mp->first_output_code= 32768;
mp->last_output_code= -32768;
mp->total_shipped= 0;

/*:1268*/
#line 370 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

void mp_set_utf8 (MP mp,int b) {
   int i;
   int c = b ? letter_class : invalid_class;
   for (i=127;i<=255;i++) {
       mp->char_class[i] = c;
   }
}

/*:15*//*18:*/
#line 572 "../../../source/texk/web2c/mplibdir/mp.w"

MP mp_initialize(MP_options*opt){
MP mp;
jmp_buf*buf= malloc(sizeof(jmp_buf));
if(buf==NULL||setjmp(*buf)!=0)
return NULL;
mp= mp_do_new(buf);
if(mp==NULL)
return NULL;
mp->userdata= opt->userdata;
mp->noninteractive= opt->noninteractive;
mp->extensions= opt->extensions;
set_callback_option(find_file);
set_callback_option(open_file);
set_callback_option(read_ascii_file);
set_callback_option(read_binary_file);
set_callback_option(close_file);
set_callback_option(eof_file);
set_callback_option(flush_file);
set_callback_option(write_ascii_file);
set_callback_option(write_binary_file);
set_callback_option(shipout_backend);
set_callback_option(run_script);
set_callback_option(make_text);
if(opt->banner&&*(opt->banner)){
mp->banner= xstrdup(opt->banner);
}else{
mp->banner= xstrdup(default_banner);
}
if(opt->command_line&&*(opt->command_line))
mp->command_line= xstrdup(opt->command_line);
if(mp->noninteractive){
/*1073:*/
#line 30724 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp->open_file= mplib_open_file;
mp->close_file= mplib_close_file;
mp->eof_file= mplib_eof_file;
mp->flush_file= mplib_flush_file;
mp->write_ascii_file= mplib_write_ascii_file;
mp->read_ascii_file= mplib_read_ascii_file;
mp->write_binary_file= mplib_write_binary_file;
mp->read_binary_file= mplib_read_binary_file;
mp->shipout_backend= mplib_shipout_backend;
}


/*:1073*/
#line 604 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

t_open_out();
#if DEBUG
setvbuf(stdout,(char*)NULL,_IONBF,0);
setvbuf(mp->term_out,(char*)NULL,_IONBF,0);
#endif
if(opt->math_mode==mp_math_scaled_mode){
mp->math= mp_initialize_scaled_math(mp);
}else if(opt->math_mode==mp_math_decimal_mode){
mp->math= mp_initialize_decimal_math(mp);
}else if(opt->math_mode==mp_math_binary_mode){
mp->math= mp_initialize_binary_math(mp);
}else{
mp->math= mp_initialize_double_math(mp);
}
/*866:*/
#line 21694 "../../../source/texk/web2c/mplibdir/mp.w"

if(!opt->ini_version){
mp->mem_name= xstrdup(opt->mem_name);
if(mp->mem_name){
size_t l= strlen(mp->mem_name);
if(l> 4){
char*test= strstr(mp->mem_name,".mem");
if(test==mp->mem_name+l-4){
*test= 0;
}
}
}
if(mp->mem_name!=NULL){
if(!mp_open_mem_file(mp)){
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}
}
}



/*:866*/
#line 621 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*31:*/
#line 752 "../../../source/texk/web2c/mplibdir/mp.w"

mp->param_size= 4;
mp->max_in_open= 0;
mp->pool_size= 10000;
set_lower_limited_value(mp->error_line,opt->error_line,79);
set_lower_limited_value(mp->half_error_line,opt->half_error_line,50);
if(mp->half_error_line> mp->error_line-15)
mp->half_error_line= mp->error_line-15;
mp->max_print_line= 100;
set_lower_limited_value(mp->max_print_line,opt->max_print_line,79);
mp->halt_on_error= (opt->halt_on_error?true:false);
mp->ini_version= (opt->ini_version?true:false);
mp->utf8_mode= (opt->utf8_mode?true:false);

/*:31*//*54:*/
#line 1022 "../../../source/texk/web2c/mplibdir/mp.w"

mp->print_found_names= (opt->print_found_names> 0?true:false);

/*:54*//*56:*/
#line 1040 "../../../source/texk/web2c/mplibdir/mp.w"

mp->file_line_error_style= (opt->file_line_error_style> 0?true:false);

/*:56*//*66:*/
#line 1187 "../../../source/texk/web2c/mplibdir/mp.w"

mp->buf_size= 200;
mp->buffer= xmalloc((mp->buf_size+1),sizeof(ASCII_code));

/*:66*//*79:*/
#line 1423 "../../../source/texk/web2c/mplibdir/mp.w"

mp_initialize_strings(mp);

/*:79*//*84:*/
#line 1526 "../../../source/texk/web2c/mplibdir/mp.w"

mp->trick_buf= xmalloc((mp->error_line+1),sizeof(ASCII_code));

/*:84*//*105:*/
#line 1881 "../../../source/texk/web2c/mplibdir/mp.w"

mp->interaction= opt->interaction;
if(mp->interaction==mp_unspecified_mode
||mp->interaction> mp_error_stop_mode)
mp->interaction= mp_error_stop_mode;
if(mp->interaction<mp_unspecified_mode)
mp->interaction= mp_batch_mode;

/*:105*//*115:*/
#line 1983 "../../../source/texk/web2c/mplibdir/mp.w"

mp->use_err_help= false;

/*:115*//*125:*/
#line 2112 "../../../source/texk/web2c/mplibdir/mp.w"

set_callback_option(run_editor);

/*:125*//*144:*/
#line 2457 "../../../source/texk/web2c/mplibdir/mp.w"

mp->OK_to_interrupt= true;
mp->finished= false;

/*:144*//*148:*/
#line 2512 "../../../source/texk/web2c/mplibdir/mp.w"

mp->arith_error= false;

/*:148*//*157:*/
#line 2615 "../../../source/texk/web2c/mplibdir/mp.w"

mp->random_seed= opt->random_seed;
{
int i;
for(i= 0;i<55;i++){
new_fraction(mp->randoms[i]);
}
}

/*:157*//*169:*/
#line 2825 "../../../source/texk/web2c/mplibdir/mp.w"

mp->math_mode= opt->math_mode;

/*:169*//*172:*/
#line 2862 "../../../source/texk/web2c/mplibdir/mp.w"

mp->token_nodes= NULL;
mp->num_token_nodes= 0;
mp->pair_nodes= NULL;
mp->num_pair_nodes= 0;
mp->knot_nodes= NULL;
mp->num_knot_nodes= 0;
mp->value_nodes= NULL;
mp->num_value_nodes= 0;
mp->symbolic_nodes= NULL;
mp->num_symbolic_nodes= 0;

/*:172*//*201:*/
#line 4131 "../../../source/texk/web2c/mplibdir/mp.w"

mp->max_internal= 2*max_given_internal;
mp->internal= xmalloc((mp->max_internal+1),sizeof(mp_internal));
memset(mp->internal,0,
(size_t)(mp->max_internal+1)*sizeof(mp_internal));
{
int i;
for(i= 1;i<=mp->max_internal;i++){
new_number(mp->internal[i].v.data.n);
}
for(i= 1;i<=max_given_internal;i++){
set_internal_type(i,mp_known);
}
}
set_internal_type(mp_output_format,mp_string_type);
set_internal_type(mp_output_filename,mp_string_type);
set_internal_type(mp_output_format_options,mp_string_type);
set_internal_type(mp_output_template,mp_string_type);
set_internal_type(mp_number_system,mp_string_type);
set_internal_type(mp_job_name,mp_string_type);
mp->troff_mode= (opt->troff_mode> 0?true:false);

/*:201*//*226:*/
#line 4713 "../../../source/texk/web2c/mplibdir/mp.w"

mp->symbols= avl_create(comp_symbols_entry,
copy_symbols_entry,
delete_symbols_entry,malloc,free,NULL);
mp->frozen_symbols= avl_create(comp_symbols_entry,
copy_symbols_entry,
delete_symbols_entry,malloc,free,NULL);

/*:226*//*614:*/
#line 15692 "../../../source/texk/web2c/mplibdir/mp.w"

mp->bisect_stack= xmalloc((bistack_size+1),sizeof(mp_number));
{
int i;
for(i= 0;i<bistack_size+1;i++){
new_number(mp->bisect_stack[i]);
}
}

/*:614*//*683:*/
#line 17572 "../../../source/texk/web2c/mplibdir/mp.w"

mp->stack_size= 16;
mp->input_stack= xmalloc((mp->stack_size+1),sizeof(in_state_record));

/*:683*//*690:*/
#line 17709 "../../../source/texk/web2c/mplibdir/mp.w"

mp_reallocate_input_stack(mp,file_bottom+4);

/*:690*//*694:*/
#line 17806 "../../../source/texk/web2c/mplibdir/mp.w"

mp->param_stack= xmalloc((mp->param_size+1),sizeof(mp_node));

/*:694*//*879:*/
#line 21891 "../../../source/texk/web2c/mplibdir/mp.w"

mp->job_name= mp_xstrdup(mp,opt->job_name);











if(opt->noninteractive){
if(mp->job_name==NULL)
mp->job_name= mp_xstrdup(mp,mp->mem_name);
}
mp->log_opened= false;

/*:879*//*900:*/
#line 22252 "../../../source/texk/web2c/mplibdir/mp.w"

set_callback_option(run_make_mpx);

/*:900*//*906:*/
#line 22310 "../../../source/texk/web2c/mplibdir/mp.w"

mp->max_read_files= 8;
mp->rd_file= xmalloc((mp->max_read_files+1),sizeof(void*));
mp->rd_fname= xmalloc((mp->max_read_files+1),sizeof(char*));
memset(mp->rd_fname,0,sizeof(char*)*(mp->max_read_files+1));
mp->max_write_files= 8;
mp->wr_file= xmalloc((mp->max_write_files+1),sizeof(void*));
mp->wr_fname= xmalloc((mp->max_write_files+1),sizeof(char*));
memset(mp->wr_fname,0,sizeof(char*)*(mp->max_write_files+1));


/*:906*//*1180:*/
#line 32926 "../../../source/texk/web2c/mplibdir/mp.w"

mp->header_last= 7;
mp->header_size= 128;
mp->header_byte= xmalloc(mp->header_size,sizeof(char));

/*:1180*//*1240:*/
#line 34243 "../../../source/texk/web2c/mplibdir/mp.w"

mp->font_mem_size= 10000;
mp->font_info= xmalloc((mp->font_mem_size+1),sizeof(font_data));
memset(mp->font_info,0,sizeof(font_data)*(mp->font_mem_size+1));
mp->last_fnum= null_font;

/*:1240*//*1292:*/
#line 35229 "../../../source/texk/web2c/mplibdir/mp.w"

mp_ps_backend_initialize(mp);
mp_svg_backend_initialize(mp);
mp_png_backend_initialize(mp);

/*:1292*/
#line 622 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_reallocate_paths(mp,1000);
mp_reallocate_fonts(mp,8);
mp->history= mp_fatal_error_stop;
/*33:*/
#line 781 "../../../source/texk/web2c/mplibdir/mp.w"

mp->bad= 0;

/*:33*//*616:*/
#line 15710 "../../../source/texk/web2c/mplibdir/mp.w"

if(int_packets+(17+2)*int_increment> bistack_size)
mp->bad= 19;

/*:616*/
#line 626 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp->bad> 0){
char ss[256];
mp_snprintf(ss,256,"Ouch---my internal constants have been clobbered!\n"
"---case %i",(int)mp->bad);
mp_fputs((char*)ss,mp->err_out);
;
return mp;
}
mp_do_initialize(mp);
mp_init_tab(mp);
if(opt->math_mode==mp_math_scaled_mode){
set_internal_string(mp_number_system,mp_intern(mp,"scaled"));
}else if(opt->math_mode==mp_math_decimal_mode){
set_internal_string(mp_number_system,mp_intern(mp,"decimal"));
}else if(opt->math_mode==mp_math_binary_mode){
set_internal_string(mp_number_system,mp_intern(mp,"binary"));
}else{
set_internal_string(mp_number_system,mp_intern(mp,"double"));
}
mp_init_prim(mp);
mp_fix_date_and_time(mp);
if(!mp->noninteractive){
/*86:*/
#line 1532 "../../../source/texk/web2c/mplibdir/mp.w"

mp->selector= term_only;
mp->tally= 0;
mp->term_offset= 0;
mp->file_offset= 0;

/*:86*//*95:*/
#line 1744 "../../../source/texk/web2c/mplibdir/mp.w"

wterm(mp->banner);
mp_print_ln(mp);
update_terminal();

/*:95*/
#line 649 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*1310:*/
#line 35566 "../../../source/texk/web2c/mplibdir/mp.w"

{
/*725:*/
#line 18395 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp->input_ptr= 0;
mp->max_in_stack= file_bottom;
mp->in_open= file_bottom;
mp->open_parens= 0;
mp->max_buf_stack= 0;
mp->param_ptr= 0;
mp->max_param_stack= 0;
mp->first= 0;
start= 0;
iindex= file_bottom;
line= 0;
name= is_term;
mp->mpx_name[file_bottom]= absent;
mp->force_eof= false;
if(!mp_init_terminal(mp))
mp_jump_out(mp);
limit= (halfword)mp->last;
mp->first= mp->last+1;

}


/*:725*//*728:*/
#line 18462 "../../../source/texk/web2c/mplibdir/mp.w"

mp->scanner_status= normal;

/*:728*/
#line 35568 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(!mp->ini_version){
if(!mp_load_preload_file(mp)){
mp->history= mp_fatal_error_stop;
return mp;
}
}
/*1311:*/
#line 35579 "../../../source/texk/web2c/mplibdir/mp.w"

mp->buffer[limit]= (ASCII_code)'%';
mp_fix_date_and_time(mp);
if(mp->random_seed==0)
mp->random_seed= (number_to_scaled(internal_value(mp_time))/number_to_scaled(unity_t))+number_to_scaled(internal_value(mp_day));
init_randoms(mp->random_seed);
initialize_print_selector();
mp_normalize_selector(mp);
if(loc<limit)
if(mp->buffer[loc]!='\\')
mp_start_input(mp);

/*:1311*/
#line 35575 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:1310*/
#line 650 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*19:*/
#line 661 "../../../source/texk/web2c/mplibdir/mp.w"

mp_open_log_file(mp);
mp_set_job_id(mp);
mp_init_map_file(mp,mp->troff_mode);
mp->history= mp_spotless;
if(mp->troff_mode){
number_clone(internal_value(mp_gtroffmode),unity_t);
number_clone(internal_value(mp_prologues),unity_t);
}
if(mp->start_sym!=NULL){
set_cur_sym(mp->start_sym);
mp_back_input(mp);
}

/*:19*/
#line 651 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*880:*/
#line 21913 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->job_name!=NULL){
if(internal_string(mp_job_name)!=0)
delete_str_ref(internal_string(mp_job_name));
set_internal_string(mp_job_name,mp_rts(mp,mp->job_name));
}

/*:880*/
#line 652 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp->history= mp_spotless;
}
set_precision();
return mp;
}


/*:18*//*21:*/
#line 682 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_status(MP mp){
return mp->history;
}


/*:21*//*22:*/
#line 688 "../../../source/texk/web2c/mplibdir/mp.w"

boolean mp_finished(MP mp){
return mp->finished;
}



/*:22*//*23:*/
#line 695 "../../../source/texk/web2c/mplibdir/mp.w"

void*mp_userdata(MP mp){
return mp->userdata;
}


/*:23*//*47:*/
#line 950 "../../../source/texk/web2c/mplibdir/mp.w"

static char*mp_find_file(MP mp,const char*fname,const char*fmode,
int ftype){
(void)mp;
if(fmode[0]!='r'||(!access(fname,R_OK))||ftype){
return mp_strdup(fname);
}
return NULL;
}

/*:47*//*48:*/
#line 960 "../../../source/texk/web2c/mplibdir/mp.w"

static char*mp_run_script(MP mp,const char*str){
(void)mp;
return mp_strdup(str);
}

/*:48*//*49:*/
#line 966 "../../../source/texk/web2c/mplibdir/mp.w"

static char*mp_make_text(MP mp,const char*str,int mode){
(void)mp;
return mp_strdup(str);
}

/*:49*//*51:*/
#line 992 "../../../source/texk/web2c/mplibdir/mp.w"

void*mp_open_file(MP mp,const char*fname,const char*fmode,int ftype){
char realmode[3];
(void)mp;
realmode[0]= *fmode;
realmode[1]= 'b';
realmode[2]= 0;
if(ftype==mp_filetype_terminal){
return(fmode[0]=='r'?stdin:stdout);
}else if(ftype==mp_filetype_error){
return stderr;
}else if(fname!=NULL&&(fmode[0]!='r'||(!access(fname,R_OK)))){
return(void*)fopen(fname,realmode);
}
return NULL;
}


/*:51*//*57:*/
#line 1048 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_do_open_file(MP mp,void**f,int ftype,const char*mode){
if(mp->print_found_names||mp->file_line_error_style){
char*s= (mp->find_file)(mp,mp->name_of_file,mode,ftype);
if(s!=NULL){
*f= (mp->open_file)(mp,mp->name_of_file,mode,ftype);
if(mp->print_found_names){
xfree(mp->name_of_file);
mp->name_of_file= xstrdup(s);
}
if((*mode=='r')&&(ftype==mp_filetype_program)){
long_name= xstrdup(s);
}
xfree(s);
}else{
*f= NULL;
}
}else{
*f= (mp->open_file)(mp,mp->name_of_file,mode,ftype);
}
return(*f?true:false);
}

static boolean mp_open_in(MP mp,void**f,int ftype){

return mp_do_open_file(mp,f,ftype,"r");
}

static boolean mp_open_out(MP mp,void**f,int ftype){

return mp_do_open_file(mp,f,ftype,"w");
}


/*:57*//*58:*/
#line 1082 "../../../source/texk/web2c/mplibdir/mp.w"

static char*mp_read_ascii_file(MP mp,void*ff,size_t*size){
int c;
size_t len= 0,lim= 128;
char*s= NULL;
FILE*f= (FILE*)ff;
*size= 0;
(void)mp;
if(f==NULL)
return NULL;
c= fgetc(f);
if(c==EOF)
return NULL;
s= malloc(lim);
if(s==NULL)
return NULL;
while(c!=EOF&&c!='\n'&&c!='\r'){
if((len+1)==lim){
s= realloc(s,(lim+(lim>>2)));
if(s==NULL)
return NULL;
lim+= (lim>>2);
}
s[len++]= (char)c;
c= fgetc(f);
}
if(c=='\r'){
c= fgetc(f);
if(c!=EOF&&c!='\n')
ungetc(c,f);
}
s[len]= 0;
*size= len;
return s;
}


/*:58*//*59:*/
#line 1119 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_write_ascii_file(MP mp,void*f,const char*s){
(void)mp;
if(f!=NULL){
fputs(s,(FILE*)f);
}
}


/*:59*//*60:*/
#line 1128 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_read_binary_file(MP mp,void*f,void**data,size_t*size){
size_t len= 0;
(void)mp;
if(f!=NULL)
len= fread(*data,1,*size,(FILE*)f);
*size= len;
}


/*:60*//*61:*/
#line 1138 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_write_binary_file(MP mp,void*f,void*s,size_t size){
(void)mp;
if(f!=NULL)
(void)fwrite(s,size,1,(FILE*)f);
}


/*:61*//*62:*/
#line 1146 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_close_file(MP mp,void*f){
(void)mp;
if(f!=NULL)
fclose((FILE*)f);
}


/*:62*//*63:*/
#line 1154 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_eof_file(MP mp,void*f){
(void)mp;
if(f!=NULL)
return feof((FILE*)f);
else
return 1;
}


/*:63*//*64:*/
#line 1164 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_flush_file(MP mp,void*f){
(void)mp;
if(f!=NULL)
fflush((FILE*)f);
}


/*:64*//*68:*/
#line 1194 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_reallocate_buffer(MP mp,size_t l){
ASCII_code*buffer;
if(l> max_halfword){
mp_confusion(mp,"buffer size");
}
buffer= xmalloc((l+1),sizeof(ASCII_code));
(void)memcpy(buffer,mp->buffer,(mp->buf_size+1));
xfree(mp->buffer);
mp->buffer= buffer;
mp->buf_size= l;
}


/*:68*//*69:*/
#line 1223 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_input_ln(MP mp,void*f){

char*s;
size_t size= 0;
mp->last= mp->first;
s= (mp->read_ascii_file)(mp,f,&size);
if(s==NULL)
return false;
if(size> 0){
mp->last= mp->first+size;
if(mp->last>=mp->max_buf_stack){
mp->max_buf_stack= mp->last+1;
while(mp->max_buf_stack> mp->buf_size){
mp_reallocate_buffer(mp,(mp->buf_size+(mp->buf_size>>2)));
}
}
(void)memcpy((mp->buffer+mp->first),s,size);
}
free(s);
return true;
}


/*:69*//*74:*/
#line 1349 "../../../source/texk/web2c/mplibdir/mp.w"

boolean mp_init_terminal(MP mp){
t_open_in();
if(mp->last!=0){
loc= 0;
mp->first= 0;
return true;
}
while(1){
if(!mp->noninteractive){
wake_up_terminal();
mp_fputs("**",mp->term_out);
;
update_terminal();
}
if(!mp_input_ln(mp,mp->term_in)){
mp_fputs("\n! End of file on the terminal... why?",mp->term_out);
;
return false;
}
loc= (halfword)mp->first;
while((loc<(int)mp->last)&&(mp->buffer[loc]==' '))
incr(loc);
if(loc<(int)mp->last){
return true;
}
if(!mp->noninteractive){
mp_fputs("Please type the name of your input file.\n",mp->term_out);
}
}
}


/*:74*//*99:*/
#line 1799 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_dd(MP mp,integer n){
n= MPOST_ABS(n)%100;
mp_print_char(mp,xord('0'+(n/10)));
mp_print_char(mp,xord('0'+(n%10)));
}


/*:99*//*101:*/
#line 1825 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_term_input(MP mp){
size_t k;
if(mp->noninteractive){
if(!mp_input_ln(mp,mp->term_in))
longjmp(*(mp->jump_buf),1);
mp->buffer[mp->last]= xord('%');
}else{
update_terminal();
if(!mp_input_ln(mp,mp->term_in)){
mp_fatal_error(mp,"End of file on the terminal!");

}
mp->term_offset= 0;
decr(mp->selector);
if(mp->last!=mp->first){
for(k= mp->first;k<mp->last;k++){
mp_print_char(mp,mp->buffer[k]);
}
}
mp_print_ln(mp);
mp->buffer[mp->last]= xord('%');
incr(mp->selector);
}
}


/*:101*//*107:*/
#line 1895 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_err(MP mp,const char*A){
if(mp->interaction==mp_error_stop_mode)
wake_up_terminal();
if(mp->file_line_error_style&&file_state&&!terminal_input){
mp_print_nl(mp,"");
if(long_name!=NULL){
mp_print(mp,long_name);
}else{
mp_print(mp,mp_str(mp,name));
}
mp_print(mp,":");
mp_print_int(mp,line);
mp_print(mp,": ");
}else{
mp_print_nl(mp,"! ");
}
mp_print(mp,A);

}


/*:107*//*120:*/
#line 2035 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_error(MP mp,const char*msg,const char**hlp,boolean deletions_allowed){
ASCII_code c;
integer s1,s2;
mp_sym s3;
int i= 0;
const char*help_line[6];
unsigned int help_ptr;
const char**cnt= NULL;
mp_print_err(mp,msg);
if(hlp){
cnt= hlp;
while(*cnt){
i++;cnt++;
}
cnt= hlp;
}
help_ptr= i;
while(i> 0){
help_line[--i]= *cnt++;
}
if(mp->history<mp_error_message_issued)
mp->history= mp_error_message_issued;
mp_print_char(mp,xord('.'));
mp_show_context(mp);
if(mp->halt_on_error){
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}
if((!mp->noninteractive)&&(mp->interaction==mp_error_stop_mode)){
/*122:*/
#line 2083 "../../../source/texk/web2c/mplibdir/mp.w"

while(true){
CONTINUE:
mp_clear_for_error_prompt(mp);
prompt_input("? ");
;
if(mp->last==mp->first)
return;
c= mp->buffer[mp->first];
if(c>='a')
c= (ASCII_code)(c+'A'-'a');
/*128:*/
#line 2129 "../../../source/texk/web2c/mplibdir/mp.w"

switch(c){
case'0':
case'1':
case'2':
case'3':
case'4':
case'5':
case'6':
case'7':
case'8':
case'9':
if(deletions_allowed){
/*132:*/
#line 2241 "../../../source/texk/web2c/mplibdir/mp.w"

{
s1= cur_cmd();
s2= cur_mod();
s3= cur_sym();
mp->OK_to_interrupt= false;
if((mp->last> mp->first+1)&&(mp->buffer[mp->first+1]>='0')
&&(mp->buffer[mp->first+1]<='9'))
c= xord(c*10+mp->buffer[mp->first+1]-'0'*11);
else
c= (ASCII_code)(c-'0');
while(c> 0){
mp_get_next(mp);
/*824:*/
#line 20843 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_cmd()==mp_string_token){
delete_str_ref(cur_mod_str());
}

/*:824*/
#line 2254 "../../../source/texk/web2c/mplibdir/mp.w"
;
c--;
};
set_cur_cmd(s1);
set_cur_mod(s2);
set_cur_sym(s3);
mp->OK_to_interrupt= true;
help_ptr= 2;
help_line[1]= "I have just deleted some text, as you asked.";
help_line[0]= "You can now delete more, or insert, or whatever.";
mp_show_context(mp);
goto CONTINUE;
}


/*:132*/
#line 2142 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
break;
case'E':
if(mp->file_ptr> 0){
mp->interaction= mp_scroll_mode;
mp_close_files_and_terminate(mp);
(mp->run_editor)(mp,
mp_str(mp,mp->input_stack[mp->file_ptr].name_field),
mp_true_line(mp));
mp_jump_out(mp);
}
break;
case'H':
/*133:*/
#line 2273 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp->use_err_help){
/*134:*/
#line 2299 "../../../source/texk/web2c/mplibdir/mp.w"

{
size_t j= 0;
while(j<mp->err_help->len){
if(*(mp->err_help->str+j)!='%')
mp_print(mp,(const char*)(mp->err_help->str+j));
else if(j+1==mp->err_help->len)
mp_print_ln(mp);
else if(*(mp->err_help->str+j)!='%')
mp_print_ln(mp);
else{
j++;
mp_print_char(mp,xord('%'));
};
j++;
}
}


/*:134*/
#line 2276 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp->use_err_help= false;
}else{
if(help_ptr==0){
help_ptr= 2;
help_line[1]= "Sorry, I don't know how to help in this situation.";
help_line[0]= "Maybe you should try asking a human?";
}
do{
decr(help_ptr);
mp_print(mp,help_line[help_ptr]);
mp_print_ln(mp);
}while(help_ptr!=0);
};
help_ptr= 4;
help_line[3]= "Sorry, I already gave what help I could...";
help_line[2]= "Maybe you should try asking a human?";
help_line[1]= "An error might have occurred before I noticed any problems.";
help_line[0]= "``If all else fails, read the instructions.''";
goto CONTINUE;
}


/*:133*/
#line 2156 "../../../source/texk/web2c/mplibdir/mp.w"
;

case'I':
/*131:*/
#line 2222 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_begin_file_reading(mp);
if(mp->last> mp->first+1){
loc= (halfword)(mp->first+1);
mp->buffer[mp->first]= xord(' ');
}else{
prompt_input("insert>");
loc= (halfword)mp->first;

}
mp->first= mp->last+1;
mp->cur_input.limit_field= (halfword)mp->last;
return;
}


/*:131*/
#line 2159 "../../../source/texk/web2c/mplibdir/mp.w"
;

case'Q':
case'R':
case'S':
/*130:*/
#line 2191 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp->error_count= 0;
mp_print(mp,"OK, entering ");
switch(c){
case'Q':
mp->interaction= mp_batch_mode;
mp_print(mp,"batchmode");
decr(mp->selector);
break;
case'R':
mp->interaction= mp_nonstop_mode;
mp_print(mp,"nonstopmode");
break;
case'S':
mp->interaction= mp_scroll_mode;
mp_print(mp,"scrollmode");
break;
}
mp_print(mp,"...");
mp_print_ln(mp);
update_terminal();
return;
}


/*:130*/
#line 2164 "../../../source/texk/web2c/mplibdir/mp.w"
;

case'X':
mp->interaction= mp_scroll_mode;
mp_jump_out(mp);
break;
default:
break;
}
/*129:*/
#line 2176 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_print(mp,"Type <return> to proceed, S to scroll future error messages,");
;
mp_print_nl(mp,"R to run without stopping, Q to run quietly,");
mp_print_nl(mp,"I to insert something, ");
if(mp->file_ptr> 0)
mp_print(mp,"E to edit your file,");
if(deletions_allowed)
mp_print_nl(mp,
"1 or ... or 9 to ignore the next 1 to 9 tokens of input,");
mp_print_nl(mp,"H for help, X to quit.");
}


/*:129*/
#line 2173 "../../../source/texk/web2c/mplibdir/mp.w"



/*:128*/
#line 2094 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:122*/
#line 2065 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
incr(mp->error_count);
if(mp->error_count==100){
mp_print_nl(mp,"(That makes 100 errors; please try again.)");
;
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}
/*135:*/
#line 2318 "../../../source/texk/web2c/mplibdir/mp.w"

if(!mp->noninteractive){
if(mp->interaction> mp_batch_mode){
decr(mp->selector);
}
}
if(mp->use_err_help){
mp_print_nl(mp,"");
/*134:*/
#line 2299 "../../../source/texk/web2c/mplibdir/mp.w"

{
size_t j= 0;
while(j<mp->err_help->len){
if(*(mp->err_help->str+j)!='%')
mp_print(mp,(const char*)(mp->err_help->str+j));
else if(j+1==mp->err_help->len)
mp_print_ln(mp);
else if(*(mp->err_help->str+j)!='%')
mp_print_ln(mp);
else{
j++;
mp_print_char(mp,xord('%'));
};
j++;
}
}


/*:134*/
#line 2326 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
while(help_ptr> 0){
decr(help_ptr);
mp_print_nl(mp,help_line[help_ptr]);
};
mp_print_ln(mp);
if(!mp->noninteractive){
if(mp->interaction> mp_batch_mode)
incr(mp->selector);
}
mp_print_ln(mp);
}


/*:135*/
#line 2074 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:120*//*127:*/
#line 2118 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_run_editor(MP mp,char*fname,int fline){
char*s= xmalloc(256,1);
mp_snprintf(s,256,"You want to edit file %s at line %d\n",fname,fline);
wterm_ln(s);

}


/*:127*//*136:*/
#line 2345 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_normalize_selector(MP mp){
if(mp->log_opened)
mp->selector= term_and_log;
else
mp->selector= term_only;
if(mp->job_name==NULL)
mp_open_log_file(mp);
if(mp->interaction==mp_batch_mode)
decr(mp->selector);
}


/*:136*//*145:*/
#line 2466 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pause_for_instructions(MP mp){
const char*hlp[]= {"You rang?",
"Try to insert some instructions for me (e.g.,`I show x'),",
"unless you just want to quit by typing `X'.",
NULL};
if(mp->OK_to_interrupt){
mp->interaction= mp_error_stop_mode;
if((mp->selector==log_only)||(mp->selector==no_print))
incr(mp->selector);
;
mp_error(mp,"Interruption",hlp,false);
mp->interrupt= 0;
}
}


/*:145*//*149:*/
#line 2523 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_clear_arith(MP mp){
const char*hlp[]= {
"Uh, oh. A little while ago one of the quantities that I was",
"computing got too large, so I'm afraid your answers will be",
"somewhat askew. You'll probably have to adopt different",
"tactics next time. But I shall try to carry on anyway.",
NULL};
mp_error(mp,"Arithmetic overflow",hlp,true);
;
mp->arith_error= false;
}


/*:149*//*160:*/
#line 2635 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_new_randoms(MP mp){
int k;
mp_number x;
new_number(x);
for(k= 0;k<=23;k++){
set_number_from_substraction(x,mp->randoms[k],mp->randoms[k+31]);
if(number_negative(x))
number_add(x,fraction_one_t);
number_clone(mp->randoms[k],x);
}
for(k= 24;k<=54;k++){
set_number_from_substraction(x,mp->randoms[k],mp->randoms[k-24]);
if(number_negative(x))
number_add(x,fraction_one_t);
number_clone(mp->randoms[k],x);
}
free_number(x);
mp->j_random= 54;
}

/*:160*//*161:*/
#line 2660 "../../../source/texk/web2c/mplibdir/mp.w"











/*:161*//*162:*/
#line 2682 "../../../source/texk/web2c/mplibdir/mp.w"






























/*:162*//*163:*/
#line 2720 "../../../source/texk/web2c/mplibdir/mp.w"











































/*:163*//*175:*/
#line 2906 "../../../source/texk/web2c/mplibdir/mp.w"

void*do_alloc_node(MP mp,size_t size){
void*p;
p= xmalloc(1,size);
add_var_used(size);
((mp_node)p)->link= NULL;
((mp_node)p)->has_number= 0;
return p;
}


/*:175*//*176:*/
#line 2922 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_xfree(void*x){
if(x!=NULL)
free(x);
}
void*mp_xrealloc(MP mp,void*p,size_t nmem,size_t size){
void*w;
if((max_size_test/size)<nmem){
mp_fputs("Memory size overflow!\n",mp->err_out);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}
w= realloc(p,(nmem*size));
if(w==NULL){
mp_fputs("Out of memory!\n",mp->err_out);
mp->history= mp_system_error_stop;
mp_jump_out(mp);
}
return w;
}
void*mp_xmalloc(MP mp,size_t nmem,size_t size){
void*w;
#if DEBUG
if((max_size_test/size)<nmem){
mp_fputs("Memory size overflow!\n",mp->err_out);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}
#endif
w= malloc(nmem*size);
if(w==NULL){
mp_fputs("Out of memory!\n",mp->err_out);
mp->history= mp_system_error_stop;
mp_jump_out(mp);
}
return w;
}

/*:176*//*181:*/
#line 3012 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
#define mp_sym_info(A)       get_mp_sym_info(mp,(A))
#define set_mp_sym_info(A,B) do_set_mp_sym_info(mp,(A),(B))
#define mp_sym_sym(A)        get_mp_sym_sym(mp,(A))
#define set_mp_sym_sym(A,B)  do_set_mp_sym_sym(mp,(A),(mp_sym)(B))
static void do_set_mp_sym_info(MP mp,mp_node p,halfword v){
FUNCTION_TRACE3("do_set_mp_sym_info(%p,%d)\n",p,v);
assert(p->type==mp_symbol_node);
set_indep_value(p,v);
}
static halfword get_mp_sym_info(MP mp,mp_node p){
FUNCTION_TRACE3("%d = get_mp_sym_info(%p)\n",indep_value(p),p);
assert(p->type==mp_symbol_node);
return indep_value(p);
}
static void do_set_mp_sym_sym(MP mp,mp_node p,mp_sym v){
mp_symbolic_node pp= (mp_symbolic_node)p;
FUNCTION_TRACE3("do_set_mp_sym_sym(%p,%p)\n",pp,v);
assert(pp->type==mp_symbol_node);
pp->data.sym= v;
}
static mp_sym get_mp_sym_sym(MP mp,mp_node p){
mp_symbolic_node pp= (mp_symbolic_node)p;
FUNCTION_TRACE3("%p = get_mp_sym_sym(%p)\n",pp->data.sym,pp);
assert(pp->type==mp_symbol_node);
return pp->data.sym;
}
#else
#define mp_sym_info(A)        indep_value(A)
#define set_mp_sym_info(A,B)  set_indep_value(A, (B))
#define mp_sym_sym(A)        (A)->data.sym
#define set_mp_sym_sym(A,B)  (A)->data.sym =  (mp_sym)(B)
#endif

/*:181*//*183:*/
#line 3060 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_symbolic_node(MP mp){
mp_symbolic_node p;
if(mp->symbolic_nodes){
p= (mp_symbolic_node)mp->symbolic_nodes;
mp->symbolic_nodes= p->link;
mp->num_symbolic_nodes--;
p->link= NULL;
}else{
p= malloc_node(symbolic_node_size);
new_number(p->data.n);
p->has_number= 1;
}
p->type= mp_symbol_node;
p->name_type= mp_normal_sym;
FUNCTION_TRACE2("%p = mp_get_symbolic_node()\n",p);
return(mp_node)p;
}


/*:183*//*184:*/
#line 3086 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_free_node(MP mp,mp_node p,size_t siz){
FUNCTION_TRACE3("mp_free_node(%p,%d)\n",p,(int)siz);
if(!p)return;
mp->var_used-= siz;
if(mp->math_mode> mp_math_double_mode){
if(p->has_number>=1&&is_number(((mp_symbolic_node)p)->data.n)){
free_number(((mp_symbolic_node)p)->data.n);
}
if(p->has_number==2&&is_number(((mp_value_node)p)->subscript_)){
free_number(((mp_value_node)p)->subscript_);
}


if(mp_type(p)==mp_dash_node_type){
free_number(((mp_dash_node)p)->start_x);
free_number(((mp_dash_node)p)->stop_x);
free_number(((mp_dash_node)p)->dash_y);
}
}
xfree(p);
}
void mp_free_symbolic_node(MP mp,mp_node p){
FUNCTION_TRACE2("mp_free_symbolic_node(%p)\n",p);
if(!p)return;
if(mp->num_symbolic_nodes<max_num_symbolic_nodes){
p->link= mp->symbolic_nodes;
mp->symbolic_nodes= p;
mp->num_symbolic_nodes++;
return;
}
mp->var_used-= symbolic_node_size;
xfree(p);
}
void mp_free_value_node(MP mp,mp_node p){
FUNCTION_TRACE2("mp_free_value_node(%p)\n",p);
if(!p)return;
if(mp->num_value_nodes<max_num_value_nodes){
p->link= mp->value_nodes;
mp->value_nodes= p;
mp->num_value_nodes++;
return;
}
mp->var_used-= value_node_size;
assert(p->has_number==2);
if(mp->math_mode> mp_math_double_mode){
free_number(((mp_value_node)p)->data.n);
free_number(((mp_value_node)p)->subscript_);
}
xfree(p);
}


/*:184*//*189:*/
#line 3177 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_flush_node_list(MP mp,mp_node p){
mp_node q;
FUNCTION_TRACE2("mp_flush_node_list(%p)\n",p);
while(p!=NULL){
q= p;
p= p->link;
if(q->type!=mp_symbol_node)
mp_free_token_node(mp,q);
else
mp_free_symbolic_node(mp,q);
}
}


/*:189*//*196:*/
#line 3712 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_op(MP mp,quarterword c){
if(c<=mp_numeric_type){
mp_print_type(mp,c);
}else{
switch(c){
case mp_true_code:
mp_print(mp,"true");
break;
case mp_false_code:
mp_print(mp,"false");
break;
case mp_null_picture_code:
mp_print(mp,"nullpicture");
break;
case mp_null_pen_code:
mp_print(mp,"nullpen");
break;
case mp_read_string_op:
mp_print(mp,"readstring");
break;
case mp_pen_circle:
mp_print(mp,"pencircle");
break;
case mp_normal_deviate:
mp_print(mp,"normaldeviate");
break;
case mp_read_from_op:
mp_print(mp,"readfrom");
break;
case mp_close_from_op:
mp_print(mp,"closefrom");
break;
case mp_odd_op:
mp_print(mp,"odd");
break;
case mp_known_op:
mp_print(mp,"known");
break;
case mp_unknown_op:
mp_print(mp,"unknown");
break;
case mp_not_op:
mp_print(mp,"not");
break;
case mp_decimal:
mp_print(mp,"decimal");
break;
case mp_reverse:
mp_print(mp,"reverse");
break;
case mp_make_path_op:
mp_print(mp,"makepath");
break;
case mp_make_pen_op:
mp_print(mp,"makepen");
break;
case mp_oct_op:
mp_print(mp,"oct");
break;
case mp_hex_op:
mp_print(mp,"hex");
break;
case mp_ASCII_op:
mp_print(mp,"ASCII");
break;
case mp_char_op:
mp_print(mp,"char");
break;
case mp_length_op:
mp_print(mp,"length");
break;
case mp_turning_op:
mp_print(mp,"turningnumber");
break;
case mp_x_part:
mp_print(mp,"xpart");
break;
case mp_y_part:
mp_print(mp,"ypart");
break;
case mp_xx_part:
mp_print(mp,"xxpart");
break;
case mp_xy_part:
mp_print(mp,"xypart");
break;
case mp_yx_part:
mp_print(mp,"yxpart");
break;
case mp_yy_part:
mp_print(mp,"yypart");
break;
case mp_red_part:
mp_print(mp,"redpart");
break;
case mp_green_part:
mp_print(mp,"greenpart");
break;
case mp_blue_part:
mp_print(mp,"bluepart");
break;
case mp_cyan_part:
mp_print(mp,"cyanpart");
break;
case mp_magenta_part:
mp_print(mp,"magentapart");
break;
case mp_yellow_part:
mp_print(mp,"yellowpart");
break;
case mp_black_part:
mp_print(mp,"blackpart");
break;
case mp_grey_part:
mp_print(mp,"greypart");
break;
case mp_color_model_part:
mp_print(mp,"colormodel");
break;
case mp_font_part:
mp_print(mp,"fontpart");
break;
case mp_text_part:
mp_print(mp,"textpart");
break;
case mp_prescript_part:
mp_print(mp,"prescriptpart");
break;
case mp_postscript_part:
mp_print(mp,"postscriptpart");
break;
case mp_path_part:
mp_print(mp,"pathpart");
break;
case mp_pen_part:
mp_print(mp,"penpart");
break;
case mp_dash_part:
mp_print(mp,"dashpart");
break;
case mp_sqrt_op:
mp_print(mp,"sqrt");
break;
case mp_m_exp_op:
mp_print(mp,"mexp");
break;
case mp_m_log_op:
mp_print(mp,"mlog");
break;
case mp_sin_d_op:
mp_print(mp,"sind");
break;
case mp_cos_d_op:
mp_print(mp,"cosd");
break;
case mp_floor_op:
mp_print(mp,"floor");
break;
case mp_uniform_deviate:
mp_print(mp,"uniformdeviate");
break;
case mp_char_exists_op:
mp_print(mp,"charexists");
break;
case mp_font_size:
mp_print(mp,"fontsize");
break;
case mp_ll_corner_op:
mp_print(mp,"llcorner");
break;
case mp_lr_corner_op:
mp_print(mp,"lrcorner");
break;
case mp_ul_corner_op:
mp_print(mp,"ulcorner");
break;
case mp_ur_corner_op:
mp_print(mp,"urcorner");
break;
case mp_arc_length:
mp_print(mp,"arclength");
break;
case mp_angle_op:
mp_print(mp,"angle");
break;
case mp_cycle_op:
mp_print(mp,"cycle");
break;
case mp_filled_op:
mp_print(mp,"filled");
break;
case mp_stroked_op:
mp_print(mp,"stroked");
break;
case mp_textual_op:
mp_print(mp,"textual");
break;
case mp_clipped_op:
mp_print(mp,"clipped");
break;
case mp_bounded_op:
mp_print(mp,"bounded");
break;
case mp_plus:
mp_print_char(mp,xord('+'));
break;
case mp_minus:
mp_print_char(mp,xord('-'));
break;
case mp_times:
mp_print_char(mp,xord('*'));
break;
case mp_over:
mp_print_char(mp,xord('/'));
break;
case mp_pythag_add:
mp_print(mp,"++");
break;
case mp_pythag_sub:
mp_print(mp,"+-+");
break;
case mp_or_op:
mp_print(mp,"or");
break;
case mp_and_op:
mp_print(mp,"and");
break;
case mp_less_than:
mp_print_char(mp,xord('<'));
break;
case mp_less_or_equal:
mp_print(mp,"<=");
break;
case mp_greater_than:
mp_print_char(mp,xord('>'));
break;
case mp_greater_or_equal:
mp_print(mp,">=");
break;
case mp_equal_to:
mp_print_char(mp,xord('='));
break;
case mp_unequal_to:
mp_print(mp,"<>");
break;
case mp_concatenate:
mp_print(mp,"&");
break;
case mp_rotated_by:
mp_print(mp,"rotated");
break;
case mp_slanted_by:
mp_print(mp,"slanted");
break;
case mp_scaled_by:
mp_print(mp,"scaled");
break;
case mp_shifted_by:
mp_print(mp,"shifted");
break;
case mp_transformed_by:
mp_print(mp,"transformed");
break;
case mp_x_scaled:
mp_print(mp,"xscaled");
break;
case mp_y_scaled:
mp_print(mp,"yscaled");
break;
case mp_z_scaled:
mp_print(mp,"zscaled");
break;
case mp_in_font:
mp_print(mp,"infont");
break;
case mp_intersect:
mp_print(mp,"intersectiontimes");
break;
case mp_substring_of:
mp_print(mp,"substring");
break;
case mp_subpath_of:
mp_print(mp,"subpath");
break;
case mp_direction_time_of:
mp_print(mp,"directiontime");
break;
case mp_point_of:
mp_print(mp,"point");
break;
case mp_precontrol_of:
mp_print(mp,"precontrol");
break;
case mp_postcontrol_of:
mp_print(mp,"postcontrol");
break;
case mp_pen_offset_of:
mp_print(mp,"penoffset");
break;
case mp_arc_time_of:
mp_print(mp,"arctime");
break;
case mp_version:
mp_print(mp,"mpversion");
break;
case mp_envelope_of:
mp_print(mp,"envelope");
break;
case mp_boundingpath_of:
mp_print(mp,"boundingpath");
break;
case mp_glyph_infont:
mp_print(mp,"glyph");
break;
default:
mp_print(mp,"..");
break;
}
}
}


/*:196*//*203:*/
#line 4156 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_troff_mode(MP mp){
return mp->troff_mode;
}


/*:203*//*209:*/
#line 4382 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fix_date_and_time(MP mp){
time_t aclock= time((time_t*)0);
struct tm*tmptr= localtime(&aclock);
set_internal_from_number(mp_time,unity_t);
number_multiply_int(internal_value(mp_time),(tmptr->tm_hour*60+tmptr->tm_min));
set_internal_from_number(mp_hour,unity_t);
number_multiply_int(internal_value(mp_hour),(tmptr->tm_hour));
set_internal_from_number(mp_minute,unity_t);
number_multiply_int(internal_value(mp_minute),(tmptr->tm_min));
set_internal_from_number(mp_day,unity_t);
number_multiply_int(internal_value(mp_day),(tmptr->tm_mday));
set_internal_from_number(mp_month,unity_t);
number_multiply_int(internal_value(mp_month),(tmptr->tm_mon+1));
set_internal_from_number(mp_year,unity_t);
number_multiply_int(internal_value(mp_year),(tmptr->tm_year+1900));
}


/*:209*//*218:*/
#line 4573 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
#define text(A)         do_get_text(mp, (A))
#define eq_type(A)      do_get_eq_type(mp, (A))
#define equiv(A)        do_get_equiv(mp, (A))
#define equiv_node(A)   do_get_equiv_node(mp, (A))
#define equiv_sym(A)    do_get_equiv_sym(mp, (A))
static mp_string do_get_text(MP mp,mp_sym A){
FUNCTION_TRACE3("%d = do_get_text(%p)\n",A->text,A);
return A->text;
}
static halfword do_get_eq_type(MP mp,mp_sym A){
FUNCTION_TRACE3("%d = do_get_eq_type(%p)\n",A->type,A);
return A->type;
}
static halfword do_get_equiv(MP mp,mp_sym A){
FUNCTION_TRACE3("%d = do_get_equiv(%p)\n",A->v.data.indep.serial,A);
return A->v.data.indep.serial;
}
static mp_node do_get_equiv_node(MP mp,mp_sym A){
FUNCTION_TRACE3("%p = do_get_equiv_node(%p)\n",A->v.data.node,A);
return A->v.data.node;
}
static mp_sym do_get_equiv_sym(MP mp,mp_sym A){
FUNCTION_TRACE3("%p = do_get_equiv_sym(%p)\n",A->v.data.node,A);
return(mp_sym)A->v.data.node;
}
#else
#define text(A)         (A)->text
#define eq_type(A)      (A)->type
#define equiv(A)        (A)->v.data.indep.serial
#define equiv_node(A)   (A)->v.data.node
#define equiv_sym(A)    (mp_sym)(A)->v.data.node
#endif

/*:218*//*223:*/
#line 4658 "../../../source/texk/web2c/mplibdir/mp.w"

static int comp_symbols_entry(void*p,const void*pa,const void*pb){
const mp_symbol_entry*a= (const mp_symbol_entry*)pa;
const mp_symbol_entry*b= (const mp_symbol_entry*)pb;
(void)p;
if(a->text->len!=b->text->len){
return(a->text->len> b->text->len?1:-1);
}
return strncmp((const char*)a->text->str,(const char*)b->text->str,
a->text->len);
}


/*:223*//*224:*/
#line 4675 "../../../source/texk/web2c/mplibdir/mp.w"

static void*copy_symbols_entry(const void*p){
MP mp;
mp_sym ff;
const mp_symbol_entry*fp;
fp= (const mp_symbol_entry*)p;
mp= (MP)fp->parent;
ff= malloc(sizeof(mp_symbol_entry));
if(ff==NULL)
return NULL;
ff->text= copy_strings_entry(fp->text);
if(ff->text==NULL)
return NULL;
ff->v= fp->v;
ff->type= fp->type;
ff->parent= mp;
new_number(ff->v.data.n);
number_clone(ff->v.data.n,fp->v.data.n);
return ff;
}


/*:224*//*225:*/
#line 4700 "../../../source/texk/web2c/mplibdir/mp.w"

static void*delete_symbols_entry(void*p){
MP mp;
mp_sym ff= (mp_sym)p;
mp= (MP)ff->parent;
free_number(ff->v.data.n);
mp_xfree(ff->text->str);
mp_xfree(ff->text);
mp_xfree(ff);
return NULL;
}


/*:225*//*229:*/
#line 4733 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_sym new_symbols_entry(MP mp,unsigned char*nam,size_t len){
mp_sym ff;
ff= mp_xmalloc(mp,1,sizeof(mp_symbol_entry));
memset(ff,0,sizeof(mp_symbol_entry));
ff->parent= mp;
ff->text= mp_xmalloc(mp,1,sizeof(mp_lstring));
ff->text->str= nam;
ff->text->len= len;
ff->type= mp_tag_token;
ff->v.type= mp_known;
new_number(ff->v.data.n);
FUNCTION_TRACE4("%p = new_symbols_entry(\"%s\",%d)\n",ff,nam,(int)len);
return ff;
}


/*:229*//*233:*/
#line 4781 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_sym mp_do_id_lookup(MP mp,avl_tree symbols,char*j,
size_t l,boolean insert_new){

mp_sym str;
mp->id_lookup_test->text->str= (unsigned char*)j;
mp->id_lookup_test->text->len= l;
str= (mp_sym)avl_find(mp->id_lookup_test,symbols);
if(str==NULL&&insert_new){
unsigned char*nam= (unsigned char*)mp_xstrldup(mp,j,l);
mp_sym s= new_symbols_entry(mp,nam,l);
mp->st_count++;
assert(avl_ins(s,symbols,avl_false)> 0);
str= (mp_sym)avl_find(s,symbols);
delete_symbols_entry(s);
}
return str;
}
static mp_sym mp_frozen_id_lookup(MP mp,char*j,size_t l,
boolean insert_new){

return mp_do_id_lookup(mp,mp->frozen_symbols,j,l,insert_new);
}


/*:233*//*234:*/
#line 4813 "../../../source/texk/web2c/mplibdir/mp.w"

double mp_get_numeric_value(MP mp,const char*s,size_t l){
char*ss= mp_xstrdup(mp,s);
if(ss){
mp_sym sym= mp_id_lookup(mp,ss,l,false);
if(sym!=NULL){
if(mp->loop_ptr!=NULL){
mp_loop_data*s;
s= mp->loop_ptr;
while(s!=NULL&&sym!=s->var)
s= s->link;
if(s!=NULL&&sym==s->var){
mp_xfree(ss);
return number_to_double(s->old_value);
}
}
if(mp_type(sym)==mp_internal_quantity){
halfword qq= equiv(sym);
mp_xfree(ss);
if(internal_type(qq)!=mp_string_type)
return number_to_double(internal_value(qq));
else
return 0;
}
if(sym->v.data.node!=NULL&&mp_type(sym->v.data.node)==mp_known){
mp_xfree(ss);
return number_to_double(sym->v.data.node->data.n);
}
}
}
mp_xfree(ss);
return 0;
}

int mp_get_boolean_value(MP mp,const char*s,size_t l){
char*ss= mp_xstrdup(mp,s);
if(ss){
mp_sym sym= mp_id_lookup(mp,ss,l,false);
if(sym!=NULL){
if(mp_type(sym->v.data.node)==mp_boolean_type){
if(number_to_boolean(sym->v.data.node->data.n)==mp_true_code){
mp_xfree(ss);
return 1;
}
}
}
}
mp_xfree(ss);
return 0;
}

char*mp_get_string_value(MP mp,const char*s,size_t l){
char*ss= mp_xstrdup(mp,s);
if(ss){
mp_sym sym= mp_id_lookup(mp,ss,l,false);
if(sym!=NULL){
if(mp_type(sym->v.data.node)==mp_string_type){
mp_xfree(ss);
return(char*)sym->v.data.node->data.str->str;
}
}
}
mp_xfree(ss);
return NULL;
}

mp_knot mp_get_path_value(MP mp,const char*s,size_t l){
char*ss= mp_xstrdup(mp,s);
if(ss){
mp_sym sym= mp_id_lookup(mp,ss,l,false);
if(sym!=NULL&&sym->v.data.node!=NULL){
if(mp_type(sym->v.data.node)==mp_path_type){
mp_xfree(ss);
return(mp_knot)sym->v.data.node->data.p;
}
}
}
mp_xfree(ss);
return NULL;
}

/*:234*//*236:*/
#line 4906 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_primitive(MP mp,const char*ss,halfword c,halfword o){
char*s= mp_xstrdup(mp,ss);
set_cur_sym(mp_id_lookup(mp,s,strlen(s),true));
mp_xfree(s);
set_eq_type(cur_sym(),c);
set_equiv(cur_sym(),o);
}


/*:236*//*237:*/
#line 4918 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_sym mp_frozen_primitive(MP mp,const char*ss,halfword c,
halfword o){
char*s= mp_xstrdup(mp,ss);
mp_sym str= mp_frozen_id_lookup(mp,s,strlen(ss),true);
mp_xfree(s);
str->type= c;
str->v.data.indep.serial= o;
return str;
}


/*:237*//*238:*/
#line 4934 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_is_frozen(MP mp,mp_sym sym){
mp_sym temp= mp_frozen_id_lookup(mp,(char*)sym->text->str,sym->text->len,false);
if(temp==mp->frozen_inaccessible)
return false;
return(temp==sym);
}


/*:238*//*243:*/
#line 5244 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
#define value_sym(A)    do_get_value_sym(mp,(mp_token_node)(A))

#define value_number(A) ((mp_token_node)(A))->data.n
#define value_node(A)   do_get_value_node(mp,(mp_token_node)(A))
#define value_str(A)    do_get_value_str(mp,(mp_token_node)(A))
#define value_knot(A)   do_get_value_knot(mp,(mp_token_node)(A))
#else
#define value_sym(A)    ((mp_token_node)(A))->data.sym
#define value_number(A) ((mp_token_node)(A))->data.n
#define value_node(A)   ((mp_token_node)(A))->data.node
#define value_str(A)    ((mp_token_node)(A))->data.str
#define value_knot(A)   ((mp_token_node)(A))->data.p
#endif
static void do_set_value_sym(MP mp,mp_token_node A,mp_sym B){
FUNCTION_TRACE3("set_value_sym(%p,%p)\n",(A),(B));
A->data.sym= (B);
}
static void do_set_value_number(MP mp,mp_token_node A,mp_number B){
FUNCTION_TRACE3("set_value(%p,%s)\n",(A),number_tostring(B));
A->data.p= NULL;
A->data.str= NULL;
A->data.node= NULL;
number_clone(A->data.n,B);
}
static void do_set_value_str(MP mp,mp_token_node A,mp_string B){
FUNCTION_TRACE3("set_value_str(%p,%p)\n",(A),(B));
assert(A->type!=mp_structured);
A->data.p= NULL;
A->data.str= (B);
add_str_ref((B));
A->data.node= NULL;
number_clone(A->data.n,zero_t);
}
static void do_set_value_node(MP mp,mp_token_node A,mp_node B){

FUNCTION_TRACE3("set_value_node(%p,%p)\n",A,B);
assert(A->type!=mp_structured);
A->data.p= NULL;
A->data.str= NULL;
A->data.node= B;
number_clone(A->data.n,zero_t);
}
static void do_set_value_knot(MP mp,mp_token_node A,mp_knot B){
FUNCTION_TRACE3("set_value_knot(%p,%p)\n",(A),(B));
assert(A->type!=mp_structured);
A->data.p= (B);
A->data.str= NULL;
A->data.node= NULL;
number_clone(A->data.n,zero_t);
}


/*:243*//*244:*/
#line 5298 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
static mp_sym do_get_value_sym(MP mp,mp_token_node A){

FUNCTION_TRACE3("%p = get_value_sym(%p)\n",A->data.sym,A);
return A->data.sym;
}
static mp_node do_get_value_node(MP mp,mp_token_node A){
assert(A->type!=mp_structured);
FUNCTION_TRACE3("%p = get_value_node(%p)\n",A->data.node,A);
return A->data.node;
}
static mp_string do_get_value_str(MP mp,mp_token_node A){
assert(A->type!=mp_structured);
FUNCTION_TRACE3("%p = get_value_str(%p)\n",A->data.str,A);
return A->data.str;
}
static mp_knot do_get_value_knot(MP mp,mp_token_node A){
assert(A->type!=mp_structured);
FUNCTION_TRACE3("%p = get_value_knot(%p)\n",A->data.p,A);
return A->data.p;
}
static mp_number do_get_value_number(MP mp,mp_token_node A){
assert(A->type!=mp_structured);
FUNCTION_TRACE3("%d = get_value_number(%p)\n",A->data.n.type,A);
return A->data.n;
}
#endif

/*:244*//*246:*/
#line 5342 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_token_node(MP mp){
mp_node p;
if(mp->token_nodes){
p= mp->token_nodes;
mp->token_nodes= p->link;
mp->num_token_nodes--;
p->link= NULL;
}else{
p= malloc_node(token_node_size);
new_number(p->data.n);
p->has_number= 1;
}
p->type= mp_token_node_type;
FUNCTION_TRACE2("%p = mp_get_token_node()\n",p);
return(mp_node)p;
}

/*:246*//*247:*/
#line 5360 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free_token_node(MP mp,mp_node p){
FUNCTION_TRACE2("mp_free_token_node(%p)\n",p);
if(!p)return;
if(mp->num_token_nodes<max_num_token_nodes){
p->link= mp->token_nodes;
mp->token_nodes= p;
mp->num_token_nodes++;
return;
}
mp->var_used-= token_node_size;
if(mp->math_mode> mp_math_double_mode){
free_number(((mp_value_node)p)->data.n);
}
xfree(p);
}

/*:247*//*249:*/
#line 5382 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_num_tok(MP mp,mp_number v){
mp_node p;
p= mp_get_token_node(mp);
set_value_number(p,v);
p->type= mp_known;
p->name_type= mp_token;
FUNCTION_TRACE3("%p = mp_new_num_tok(%p)\n",p,v);
return p;
}


/*:249*//*250:*/
#line 5398 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_flush_token_list(MP mp,mp_node p){
mp_node q;
FUNCTION_TRACE2("mp_flush_token_list(%p)\n",p);
while(p!=NULL){
q= p;
p= mp_link(p);
if(mp_type(q)==mp_symbol_node){
mp_free_symbolic_node(mp,q);
}else{
switch(mp_type(q)){
case mp_vacuous:
case mp_boolean_type:
case mp_known:
break;
case mp_string_type:
delete_str_ref(value_str(q));
break;
case unknown_types:
case mp_pen_type:
case mp_path_type:
case mp_picture_type:
case mp_pair_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_transform_type:
case mp_dependent:
case mp_proto_dependent:
case mp_independent:
mp_recycle_value(mp,q);
break;
default:
mp_confusion(mp,"token");
;
}
mp_free_token_node(mp,q);
}
}
}


/*:250*//*252:*/
#line 5465 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_show_token_list(MP mp,mp_node p,mp_node q,integer l,
integer null_tally){
quarterword cclass,c;
cclass= percent_class;
mp->tally= null_tally;
while((p!=NULL)&&(mp->tally<l)){
if(p==q){
set_trick_count();
}

c= letter_class;
if(mp_type(p)!=mp_symbol_node){

if(mp_name_type(p)==mp_token){
if(mp_type(p)==mp_known){

if(cclass==digit_class)
mp_print_char(mp,xord(' '));
if(number_negative(value_number(p))){
if(cclass==mp_left_bracket_class)
mp_print_char(mp,xord(' '));
mp_print_char(mp,xord('['));
print_number(value_number(p));
mp_print_char(mp,xord(']'));
c= mp_right_bracket_class;
}else{
print_number(value_number(p));
c= digit_class;
}

}else if(mp_type(p)!=mp_string_type){
mp_print(mp," BAD");
}else{
mp_print_char(mp,xord('"'));
mp_print_str(mp,value_str(p));
mp_print_char(mp,xord('"'));
c= string_class;
}
}else if((mp_name_type(p)!=mp_capsule)||(mp_type(p)<mp_vacuous)
||(mp_type(p)> mp_independent)){
mp_print(mp," BAD");
}else{
mp_print_capsule(mp,p);
c= right_paren_class;
}

}else{
if(mp_name_type(p)==mp_expr_sym||
mp_name_type(p)==mp_suffix_sym||mp_name_type(p)==mp_text_sym){
integer r;
r= mp_sym_info(p);
if(mp_name_type(p)==mp_expr_sym){
mp_print(mp,"(EXPR");
}else if(mp_name_type(p)==mp_suffix_sym){
mp_print(mp,"(SUFFIX");
}else{
mp_print(mp,"(TEXT");
}
mp_print_int(mp,r);
mp_print_char(mp,xord(')'));
c= right_paren_class;
}else{
mp_sym sr= mp_sym_sym(p);
if(sr==collective_subscript){

if(cclass==mp_left_bracket_class)
mp_print_char(mp,xord(' '));
mp_print(mp,"[]");
c= mp_right_bracket_class;

}else{
mp_string rr= text(sr);
if(rr==NULL||rr->str==NULL){
mp_print(mp," NONEXISTENT");
}else{

c= (quarterword)mp->char_class[(rr->str[0])];
if(c==cclass){
switch(c){
case letter_class:
mp_print_char(mp,xord('.'));
break;
case isolated_classes:
break;
default:
mp_print_char(mp,xord(' '));
break;
}
}
mp_print_str(mp,rr);

}
}
}
}

cclass= c;
p= mp_link(p);
}
if(p!=NULL)
mp_print(mp," ETC.");
return;
}


/*:252*//*256:*/
#line 5616 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_delete_mac_ref(MP mp,mp_node p){


if(ref_count(p)==0)
mp_flush_token_list(mp,p);
else
decr_mac_ref(p);
}


/*:256*//*257:*/
#line 5630 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_show_macro(MP mp,mp_node p,mp_node q,integer l){
mp_node r;
p= mp_link(p);
while(mp_name_type(p)!=mp_macro_sym){
r= mp_link(p);
mp_link(p)= NULL;
mp_show_token_list(mp,p,NULL,l,0);
mp_link(p)= r;
p= r;
if(l> 0)
l= l-mp->tally;
else
return;
}
;
mp->tally= 0;
switch(mp_sym_info(p)){
case mp_general_macro:
mp_print(mp,"->");
break;

case mp_primary_macro:
case mp_secondary_macro:
case mp_tertiary_macro:
mp_print_char(mp,xord('<'));
mp_print_cmd_mod(mp,mp_param_type,mp_sym_info(p));
mp_print(mp,">->");
break;
case mp_expr_macro:
mp_print(mp,"<expr>->");
break;
case mp_of_macro:
mp_print(mp,"<expr>of<primary>->");
break;
case mp_suffix_macro:
mp_print(mp,"<suffix>->");
break;
case mp_text_macro:
mp_print(mp,"<text>->");
break;
}
mp_show_token_list(mp,mp_link(p),q,l-mp->tally,0);
}


/*:257*//*259:*/
#line 5746 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node do_get_attr_head(MP mp,mp_value_node A){
assert(A->type==mp_structured);
FUNCTION_TRACE3("%p = get_attr_head(%p)\n",A->attr_head_,A);
return A->attr_head_;
}
static mp_node do_get_subscr_head(MP mp,mp_value_node A){
assert(A->type==mp_structured);
FUNCTION_TRACE3("%p = get_subscr_head(%p)\n",A->subscr_head_,A);
return A->subscr_head_;
}
static void do_set_attr_head(MP mp,mp_value_node A,mp_node d){
FUNCTION_TRACE4("set_attr_head(%p,%p) on line %d\n",(A),d,__LINE__);
assert(A->type==mp_structured);
A->attr_head_= d;
}
static void do_set_subscr_head(MP mp,mp_value_node A,mp_node d){
FUNCTION_TRACE4("set_subscr_head(%p,%p) on line %d\n",(A),d,__LINE__);
assert(A->type==mp_structured);
A->subscr_head_= d;
}

/*:259*//*261:*/
#line 5781 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_value_node(MP mp){
mp_value_node p;
if(mp->value_nodes){
p= (mp_value_node)mp->value_nodes;
mp->value_nodes= p->link;
mp->num_value_nodes--;
p->link= NULL;
}else{
p= malloc_node(value_node_size);
new_number(p->data.n);
new_number(p->subscript_);
p->has_number= 2;
}
mp_type(p)= mp_value_node_type;
FUNCTION_TRACE2("%p = mp_get_value_node()\n",p);
return(mp_node)p;
}
#if DEBUG >  1
static void debug_dump_value_node(mp_node x){
mp_value_node qq= (mp_value_node)x;
fprintf(stdout,"\nnode %p:\n",qq);
fprintf(stdout,"  type=%s\n",mp_type_string(qq->type));
fprintf(stdout,"  name_type=%d\n",qq->name_type);
fprintf(stdout,"  link=%p\n",qq->link);
fprintf(stdout,"  data.n=%d\n",qq->data.n.type);
if(is_number(qq->data.n)){
fprintf(stdout,"    data.n.data.val=%d\n",qq->data.n.data.val);
fprintf(stdout,"    data.n.data.dval=%f\n",qq->data.n.data.dval);
}
fprintf(stdout,"  data.str=%p\n",qq->data.str);
if(qq->data.str!=NULL){
fprintf(stdout,"    data.str->len=%d\n",(int)qq->data.str->len);
fprintf(stdout,"    data.str->str=%s\n",qq->data.str->str);
}
fprintf(stdout,"  data.indep.serial=%d\n  data.indep.scale=%d\n",qq->data.indep.serial,
qq->data.indep.scale);
fprintf(stdout,"  data.sym=%p\n",qq->data.sym);
fprintf(stdout,"  data.p=%p\n",qq->data.p);
fprintf(stdout,"  data.node=%p\n",qq->data.node);
fprintf(stdout,"  subscript=%d\n",qq->subscript_.type);
if(is_number(qq->subscript_)){
fprintf(stdout,"    subscript_.data.val=%d\n",qq->subscript_.data.val);
fprintf(stdout,"    subscript_.data.dval=%f\n",qq->subscript_.data.dval);
}
fprintf(stdout,"  hashloc=%p\n",qq->hashloc_);
fprintf(stdout,"  parent=%p\n",qq->parent_);
fprintf(stdout,"  attr_head=%p\n",qq->attr_head_);
fprintf(stdout,"  subscr_head=%p\n\n",qq->subscr_head_);
}
#endif

/*:261*//*263:*/
#line 5929 "../../../source/texk/web2c/mplibdir/mp.w"

#if DEBUG
#define hashloc(A)       do_get_hashloc(mp,(mp_value_node)(A))
#define set_hashloc(A,B) do_set_hashloc (mp,(mp_value_node)A, B)
#define parent(A)        do_get_parent(mp, A)
#define set_parent(A,B)  do_set_parent (mp,(mp_value_node)A, B)
static mp_sym do_get_hashloc(MP mp,mp_value_node A){
assert((A)->type==mp_attr_node_type||(A)->name_type==mp_attr);
return(A)->hashloc_;
}
static void do_set_hashloc(MP mp,mp_value_node A,mp_sym B){
FUNCTION_TRACE4("set_hashloc(%p,%p) on line %d\n",(A),(B),__LINE__);
assert((A)->type==mp_attr_node_type||(A)->name_type==mp_attr);
A->hashloc_= B;
}
static mp_node do_get_parent(MP mp,mp_value_node A){
assert((A)->type==mp_attr_node_type||(A)->name_type==mp_attr);
return(A)->parent_;
}
static void do_set_parent(MP mp,mp_value_node A,mp_node d){
assert((A)->type==mp_attr_node_type||(A)->name_type==mp_attr);
FUNCTION_TRACE4("set_parent(%p,%p) on line %d\n",(A),d,__LINE__);
A->parent_= d;
}
#else
#define hashloc(A)       ((mp_value_node)(A))->hashloc_
#define set_hashloc(A,B) ((mp_value_node)(A))->hashloc_ =  B
#define parent(A)        ((mp_value_node)(A))->parent_
#define set_parent(A,B)  ((mp_value_node)(A))->parent_ =  B
#endif

/*:263*//*264:*/
#line 5966 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_get_attr_node(MP mp){
mp_value_node p= (mp_value_node)mp_get_value_node(mp);
mp_type(p)= mp_attr_node_type;
return p;
}


/*:264*//*267:*/
#line 5994 "../../../source/texk/web2c/mplibdir/mp.w"

static void do_set_subscript(MP mp,mp_value_node A,mp_number B){
FUNCTION_TRACE3("set_subscript(%p,%p)\n",(A),(B));
assert((A)->type==mp_subscr_node_type||(A)->name_type==mp_subscr);
number_clone(A->subscript_,B);
}

/*:267*//*268:*/
#line 6002 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_get_subscr_node(MP mp){
mp_value_node p= (mp_value_node)mp_get_value_node(mp);
mp_type(p)= mp_subscr_node_type;
return p;
}


/*:268*//*270:*/
#line 6030 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_pair_node(MP mp){
mp_node p;
if(mp->pair_nodes){
p= mp->pair_nodes;
mp->pair_nodes= p->link;
mp->num_pair_nodes--;
p->link= NULL;
}else{
p= malloc_node(pair_node_size);
}
mp_type(p)= mp_pair_node_type;
FUNCTION_TRACE2("get_pair_node(): %p\n",p);
return(mp_node)p;
}

/*:270*//*272:*/
#line 6049 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_free_pair_node(MP mp,mp_node p){
FUNCTION_TRACE2("mp_free_pair_node(%p)\n",p);
if(!p)return;
if(mp->num_pair_nodes<max_num_pair_nodes){
p->link= mp->pair_nodes;
mp->pair_nodes= p;
mp->num_pair_nodes++;
return;
}
mp->var_used-= pair_node_size;
xfree(p);
}


/*:272*//*273:*/
#line 6068 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_init_pair_node(MP mp,mp_node p){
mp_node q;
mp_type(p)= mp_pair_type;
q= mp_get_pair_node(mp);
y_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,y_part(q));
mp_name_type(y_part(q))= (quarterword)(mp_y_part_sector);
mp_link(y_part(q))= p;
x_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,x_part(q));
mp_name_type(x_part(q))= (quarterword)(mp_x_part_sector);
mp_link(x_part(q))= p;
set_value_node(p,q);
}


/*:273*//*275:*/
#line 6113 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_transform_node(MP mp){
mp_transform_node p= (mp_transform_node)malloc_node(transform_node_size);
mp_type(p)= mp_transform_node_type;
return(mp_node)p;
}


/*:275*//*276:*/
#line 6121 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_init_transform_node(MP mp,mp_node p){
mp_node q;
mp_type(p)= mp_transform_type;
q= mp_get_transform_node(mp);
yy_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,yy_part(q));
mp_name_type(yy_part(q))= (quarterword)(mp_yy_part_sector);
mp_link(yy_part(q))= p;
yx_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,yx_part(q));
mp_name_type(yx_part(q))= (quarterword)(mp_yx_part_sector);
mp_link(yx_part(q))= p;
xy_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,xy_part(q));
mp_name_type(xy_part(q))= (quarterword)(mp_xy_part_sector);
mp_link(xy_part(q))= p;
xx_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,xx_part(q));
mp_name_type(xx_part(q))= (quarterword)(mp_xx_part_sector);
mp_link(xx_part(q))= p;
ty_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,ty_part(q));
mp_name_type(ty_part(q))= (quarterword)(mp_y_part_sector);
mp_link(ty_part(q))= p;
tx_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,tx_part(q));
mp_name_type(tx_part(q))= (quarterword)(mp_x_part_sector);
mp_link(tx_part(q))= p;
set_value_node(p,q);
}


/*:276*//*278:*/
#line 6176 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_color_node(MP mp){
mp_color_node p= (mp_color_node)malloc_node(color_node_size);
mp_type(p)= mp_color_node_type;
p->link= NULL;
return(mp_node)p;
}


/*:278*//*279:*/
#line 6186 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_init_color_node(MP mp,mp_node p){
mp_node q;
mp_type(p)= mp_color_type;
q= mp_get_color_node(mp);
blue_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,blue_part(q));
mp_name_type(blue_part(q))= (quarterword)(mp_blue_part_sector);
mp_link(blue_part(q))= p;
green_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,green_part(q));
mp_name_type(y_part(q))= (quarterword)(mp_green_part_sector);
mp_link(green_part(q))= p;
red_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,red_part(q));
mp_name_type(red_part(q))= (quarterword)(mp_red_part_sector);
mp_link(red_part(q))= p;
set_value_node(p,q);
}


/*:279*//*281:*/
#line 6227 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_cmykcolor_node(MP mp){
mp_cmykcolor_node p= (mp_cmykcolor_node)malloc_node(cmykcolor_node_size);
mp_type(p)= mp_cmykcolor_node_type;
p->link= NULL;
return(mp_node)p;
}


/*:281*//*282:*/
#line 6237 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_init_cmykcolor_node(MP mp,mp_node p){
mp_node q;
mp_type(p)= mp_cmykcolor_type;
q= mp_get_cmykcolor_node(mp);
black_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,black_part(q));
mp_name_type(black_part(q))= (quarterword)(mp_black_part_sector);
mp_link(black_part(q))= p;
yellow_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,yellow_part(q));
mp_name_type(yellow_part(q))= (quarterword)(mp_yellow_part_sector);
mp_link(yellow_part(q))= p;
magenta_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,magenta_part(q));
mp_name_type(magenta_part(q))= (quarterword)(mp_magenta_part_sector);
mp_link(magenta_part(q))= p;
cyan_part(q)= mp_get_value_node(mp);
mp_new_indep(mp,cyan_part(q));
mp_name_type(cyan_part(q))= (quarterword)(mp_cyan_part_sector);
mp_link(cyan_part(q))= p;
set_value_node(p,q);
}


/*:282*//*284:*/
#line 6271 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_id_transform(MP mp){
mp_node p,q;
p= mp_get_value_node(mp);
mp_name_type(p)= mp_capsule;
set_value_number(p,zero_t);
mp_init_transform_node(mp,p);
q= value_node(p);
mp_type(tx_part(q))= mp_known;
set_value_number(tx_part(q),zero_t);
mp_type(ty_part(q))= mp_known;
set_value_number(ty_part(q),zero_t);
mp_type(xy_part(q))= mp_known;
set_value_number(xy_part(q),zero_t);
mp_type(yx_part(q))= mp_known;
set_value_number(yx_part(q),zero_t);
mp_type(xx_part(q))= mp_known;
set_value_number(xx_part(q),unity_t);
mp_type(yy_part(q))= mp_known;
set_value_number(yy_part(q),unity_t);
return p;
}


/*:284*//*285:*/
#line 6299 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_new_root(MP mp,mp_sym x){
mp_node p;
p= mp_get_value_node(mp);
mp_type(p)= mp_undefined;
mp_name_type(p)= mp_root;
set_value_sym(p,x);
set_equiv_node(x,p);
}


/*:285*//*287:*/
#line 6317 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_variable_name(MP mp,mp_node p){
mp_node q;
mp_node r;
while(mp_name_type(p)>=mp_x_part_sector){
switch(mp_name_type(p)){
case mp_x_part_sector:mp_print(mp,"xpart ");break;
case mp_y_part_sector:mp_print(mp,"ypart ");break;
case mp_xx_part_sector:mp_print(mp,"xxpart ");break;
case mp_xy_part_sector:mp_print(mp,"xypart ");break;
case mp_yx_part_sector:mp_print(mp,"yxpart ");break;
case mp_yy_part_sector:mp_print(mp,"yypart ");break;
case mp_red_part_sector:mp_print(mp,"redpart ");break;
case mp_green_part_sector:mp_print(mp,"greenpart ");break;
case mp_blue_part_sector:mp_print(mp,"bluepart ");break;
case mp_cyan_part_sector:mp_print(mp,"cyanpart ");break;
case mp_magenta_part_sector:mp_print(mp,"magentapart ");break;
case mp_yellow_part_sector:mp_print(mp,"yellowpart ");break;
case mp_black_part_sector:mp_print(mp,"blackpart ");break;
case mp_grey_part_sector:mp_print(mp,"greypart ");break;
case mp_capsule:mp_printf(mp,"%%CAPSULE%p",p);return;break;

default:break;
}
p= mp_link(p);
}
q= NULL;
while(mp_name_type(p)> mp_saved_root){


if(mp_name_type(p)==mp_subscr){
r= mp_new_num_tok(mp,subscript(p));
do{
p= mp_link(p);
}while(mp_name_type(p)!=mp_attr);
}else if(mp_name_type(p)==mp_structured_root){
p= mp_link(p);
goto FOUND;
}else{
if(mp_name_type(p)!=mp_attr)
mp_confusion(mp,"var");
r= mp_get_symbolic_node(mp);
set_mp_sym_sym(r,hashloc(p));
}
set_mp_link(r,q);
q= r;
FOUND:
p= parent((mp_value_node)p);

}



r= mp_get_symbolic_node(mp);
set_mp_sym_sym(r,value_sym(p));
mp_link(r)= q;
if(mp_name_type(p)==mp_saved_root)
mp_print(mp,"(SAVED)");
mp_show_token_list(mp,r,NULL,max_integer,mp->tally);
mp_flush_token_list(mp,r);
}

/*:287*//*288:*/
#line 6382 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_interesting(MP mp,mp_node p){
mp_name_type_type t;
if(number_positive(internal_value(mp_tracing_capsules))){
return true;
}else{
t= mp_name_type(p);
if(t>=mp_x_part_sector&&t!=mp_capsule){
mp_node tt= value_node(mp_link(p));
switch(t){
case mp_x_part_sector:
t= mp_name_type(x_part(tt));
break;
case mp_y_part_sector:
t= mp_name_type(y_part(tt));
break;
case mp_xx_part_sector:
t= mp_name_type(xx_part(tt));
break;
case mp_xy_part_sector:
t= mp_name_type(xy_part(tt));
break;
case mp_yx_part_sector:
t= mp_name_type(yx_part(tt));
break;
case mp_yy_part_sector:
t= mp_name_type(yy_part(tt));
break;
case mp_red_part_sector:
t= mp_name_type(red_part(tt));
break;
case mp_green_part_sector:
t= mp_name_type(green_part(tt));
break;
case mp_blue_part_sector:
t= mp_name_type(blue_part(tt));
break;
case mp_cyan_part_sector:
t= mp_name_type(cyan_part(tt));
break;
case mp_magenta_part_sector:
t= mp_name_type(magenta_part(tt));
break;
case mp_yellow_part_sector:
t= mp_name_type(yellow_part(tt));
break;
case mp_black_part_sector:
t= mp_name_type(black_part(tt));
break;
case mp_grey_part_sector:
t= mp_name_type(grey_part(tt));
break;
default:
break;
}
}
}
return(t!=mp_capsule);
}


/*:288*//*289:*/
#line 6452 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_structure(MP mp,mp_node p){
mp_node q,r= NULL;
mp_sym qq= NULL;
switch(mp_name_type(p)){
case mp_root:
{
qq= value_sym(p);
r= mp_get_value_node(mp);
set_equiv_node(qq,r);
}
break;
case mp_subscr:

{
mp_node q_new;
q= p;
do{
q= mp_link(q);
}while(mp_name_type(q)!=mp_attr);
q= parent((mp_value_node)q);
r= mp->temp_head;
set_mp_link(r,subscr_head(q));
do{
q_new= r;
r= mp_link(r);
}while(r!=p);
r= (mp_node)mp_get_subscr_node(mp);
if(q_new==mp->temp_head){
set_subscr_head(q,r);
}else{
set_mp_link(q_new,r);
}
set_subscript(r,subscript(p));
}

break;
case mp_attr:



{
mp_value_node rr;
q= parent((mp_value_node)p);
r= attr_head(q);
do{
q= r;
r= mp_link(r);
}while(r!=p);
rr= mp_get_attr_node(mp);
r= (mp_node)rr;
set_mp_link(q,(mp_node)rr);
set_hashloc(rr,hashloc(p));
set_parent(rr,parent((mp_value_node)p));
if(hashloc(p)==collective_subscript){
q= mp->temp_head;
set_mp_link(q,subscr_head(parent((mp_value_node)p)));
while(mp_link(q)!=p)
q= mp_link(q);
if(q==mp->temp_head)
set_subscr_head(parent((mp_value_node)p),(mp_node)rr);
else
set_mp_link(q,(mp_node)rr);
}
}

break;
default:
mp_confusion(mp,"struct");
break;
}
set_mp_link(r,mp_link(p));
set_value_sym(r,value_sym(p));
mp_type(r)= mp_structured;
mp_name_type(r)= mp_name_type(p);
set_attr_head(r,p);
mp_name_type(p)= mp_structured_root;
{
mp_value_node qqr= mp_get_attr_node(mp);
set_mp_link(p,(mp_node)qqr);
set_subscr_head(r,(mp_node)qqr);
set_parent(qqr,r);
mp_type(qqr)= mp_undefined;
mp_name_type(qqr)= mp_attr;
set_mp_link(qqr,mp->end_attr);
set_hashloc(qqr,collective_subscript);
}
return r;
}

/*:289*//*290:*/
#line 6556 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_find_variable(MP mp,mp_node t){
mp_node p,q,r,s;
mp_sym p_sym;
mp_node pp,qq,rr,ss;
;
p_sym= mp_sym_sym(t);
t= mp_link(t);
if((eq_type(p_sym)%mp_outer_tag)!=mp_tag_token)
return NULL;
if(equiv_node(p_sym)==NULL)
mp_new_root(mp,p_sym);
p= equiv_node(p_sym);
pp= p;
while(t!=NULL){




if(mp_type(pp)!=mp_structured){
if(mp_type(pp)> mp_structured)
return NULL;
ss= mp_new_structure(mp,pp);
if(p==pp)
p= ss;
pp= ss;
}
if(mp_type(p)!=mp_structured){
p= mp_new_structure(mp,p);
}

if(mp_type(t)!=mp_symbol_node){





mp_number nn,save_subscript;
new_number(nn);
new_number(save_subscript);
number_clone(nn,value_number(t));
pp= mp_link(attr_head(pp));
q= mp_link(attr_head(p));
number_clone(save_subscript,subscript(q));
set_number_to_inf(subscript(q));
s= mp->temp_head;
set_mp_link(s,subscr_head(p));
do{
r= s;
s= mp_link(s);
}while(number_greater(nn,subscript(s)));
if(number_equal(nn,subscript(s))){
p= s;
}else{
mp_value_node p1= mp_get_subscr_node(mp);
if(r==mp->temp_head)
set_subscr_head(p,(mp_node)p1);
else
set_mp_link(r,(mp_node)p1);
set_mp_link(p1,s);
number_clone(subscript(p1),nn);
mp_name_type(p1)= mp_subscr;
mp_type(p1)= mp_undefined;
p= (mp_node)p1;
}
number_clone(subscript(q),save_subscript);
free_number(save_subscript);
free_number(nn);
}else{

mp_sym nn1= mp_sym_sym(t);
ss= attr_head(pp);
do{
rr= ss;
ss= mp_link(ss);
}while(nn1> hashloc(ss));
if(nn1<hashloc(ss)){
qq= (mp_node)mp_get_attr_node(mp);
set_mp_link(rr,qq);
set_mp_link(qq,ss);
set_hashloc(qq,nn1);
mp_name_type(qq)= mp_attr;
mp_type(qq)= mp_undefined;
set_parent((mp_value_node)qq,pp);
ss= qq;
}
if(p==pp){
p= ss;
pp= ss;
}else{
pp= ss;
s= attr_head(p);
do{
r= s;
s= mp_link(s);
}while(nn1> hashloc(s));
if(nn1==hashloc(s)){
p= s;
}else{
q= (mp_node)mp_get_attr_node(mp);
set_mp_link(r,q);
set_mp_link(q,s);
set_hashloc(q,nn1);
mp_name_type(q)= mp_attr;
mp_type(q)= mp_undefined;
set_parent((mp_value_node)q,p);
p= q;
}
}
}
t= mp_link(t);
}
if(mp_type(pp)>=mp_structured){
if(mp_type(pp)==mp_structured)
pp= attr_head(pp);
else
return NULL;
}
if(mp_type(p)==mp_structured)
p= attr_head(p);
if(mp_type(p)==mp_undefined){
if(mp_type(pp)==mp_undefined){
mp_type(pp)= mp_numeric_type;
set_value_number(pp,zero_t);
}
mp_type(p)= mp_type(pp);
set_value_number(p,zero_t);
}
return p;
}


/*:290*//*292:*/
#line 6711 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_flush_variable(MP mp,mp_node p,mp_node t,
boolean discard_suffixes){
mp_node q,r= NULL;
mp_sym n;
while(t!=NULL){
if(mp_type(p)!=mp_structured){
return;
}
n= mp_sym_sym(t);
t= mp_link(t);
if(n==collective_subscript){
q= subscr_head(p);
while(mp_name_type(q)==mp_subscr){
mp_flush_variable(mp,q,t,discard_suffixes);
if(t==NULL){
if(mp_type(q)==mp_structured){
r= q;
}else{
if(r==NULL)
set_subscr_head(p,mp_link(q));
else
set_mp_link(r,mp_link(q));
mp_free_value_node(mp,q);
}
}else{
r= q;
}
q= (r==NULL?subscr_head(p):mp_link(r));
}
}
p= attr_head(p);
do{
p= mp_link(p);
}while(hashloc(p)<n);
if(hashloc(p)!=n){
return;
}
}
if(discard_suffixes){
mp_flush_below_variable(mp,p);
}else{
if(mp_type(p)==mp_structured){
p= attr_head(p);
}
mp_recycle_value(mp,p);
}
}


/*:292*//*294:*/
#line 6767 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_flush_below_variable(MP mp,mp_node p){
mp_node q,r;
FUNCTION_TRACE2("mp_flush_below_variable(%p)\n",p);
if(mp_type(p)!=mp_structured){
mp_recycle_value(mp,p);
}else{
q= subscr_head(p);
while(mp_name_type(q)==mp_subscr){
mp_flush_below_variable(mp,q);
r= q;
q= mp_link(q);
mp_free_value_node(mp,r);
}
r= attr_head(p);
q= mp_link(r);
mp_recycle_value(mp,r);
mp_free_value_node(mp,r);
do{
mp_flush_below_variable(mp,q);
r= q;
q= mp_link(q);
mp_free_value_node(mp,r);
}while(q!=mp->end_attr);
mp_type(p)= mp_undefined;
}
}


/*:294*//*295:*/
#line 6801 "../../../source/texk/web2c/mplibdir/mp.w"

static quarterword mp_und_type(MP mp,mp_node p){
(void)mp;
switch(mp_type(p)){
case mp_vacuous:
return mp_undefined;
case mp_boolean_type:
case mp_unknown_boolean:
return mp_unknown_boolean;
case mp_string_type:
case mp_unknown_string:
return mp_unknown_string;
case mp_pen_type:
case mp_unknown_pen:
return mp_unknown_pen;
case mp_path_type:
case mp_unknown_path:
return mp_unknown_path;
case mp_picture_type:
case mp_unknown_picture:
return mp_unknown_picture;
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
case mp_numeric_type:
return mp_type(p);
case mp_known:
case mp_dependent:
case mp_proto_dependent:
case mp_independent:
return mp_numeric_type;
default:
return 0;
}
return 0;
}


/*:295*//*296:*/
#line 6845 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_clear_symbol(MP mp,mp_sym p,boolean saving){
mp_node q;
FUNCTION_TRACE3("mp_clear_symbol(%p,%d)\n",p,saving);
q= equiv_node(p);
switch(eq_type(p)%mp_outer_tag){
case mp_defined_macro:
case mp_secondary_primary_macro:
case mp_tertiary_secondary_macro:
case mp_expression_tertiary_macro:
if(!saving)
mp_delete_mac_ref(mp,q);
break;
case mp_tag_token:
if(q!=NULL){
if(saving){
mp_name_type(q)= mp_saved_root;
}else{
mp_flush_below_variable(mp,q);
mp_free_value_node(mp,q);
}
}
break;
default:
break;
}
set_equiv(p,mp->frozen_undefined->v.data.indep.serial);
set_eq_type(p,mp->frozen_undefined->type);
}


/*:296*//*300:*/
#line 6921 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_save_boundary(MP mp){
mp_save_data*p;
FUNCTION_TRACE1("mp_save_boundary ()\n");
p= xmalloc(1,sizeof(mp_save_data));
p->type= 0;
p->link= mp->save_ptr;
mp->save_ptr= p;
}


/*:300*//*301:*/
#line 6940 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_save_variable(MP mp,mp_sym q){
mp_save_data*p;
FUNCTION_TRACE2("mp_save_variable (%p)\n",q);
if(mp->save_ptr!=NULL){
p= xmalloc(1,sizeof(mp_save_data));
p->type= mp_normal_sym;
p->link= mp->save_ptr;
p->value.v.data.indep.scale= eq_type(q);
p->value.v.data.indep.serial= equiv(q);
p->value.v.data.node= equiv_node(q);
p->value.v.data.p= (mp_knot)q;
mp->save_ptr= p;
}
mp_clear_symbol(mp,q,(mp->save_ptr!=NULL));
}
static void mp_unsave_variable(MP mp){
mp_sym q= (mp_sym)mp->save_ptr->value.v.data.p;
if(number_positive(internal_value(mp_tracing_restores))){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{restoring ");
mp_print_text(q);
mp_print_char(mp,xord('}'));
mp_end_diagnostic(mp,false);
}
mp_clear_symbol(mp,q,false);
set_eq_type(q,mp->save_ptr->value.v.data.indep.scale);
set_equiv(q,mp->save_ptr->value.v.data.indep.serial);
q->v.data.node= mp->save_ptr->value.v.data.node;
if(eq_type(q)%mp_outer_tag==mp_tag_token){
mp_node pp= q->v.data.node;
if(pp!=NULL)
mp_name_type(pp)= mp_root;
}
}

/*:301*//*302:*/
#line 6980 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_save_internal(MP mp,halfword q){
mp_save_data*p;
FUNCTION_TRACE2("mp_save_internal (%d)\n",q);
if(mp->save_ptr!=NULL){
p= xmalloc(1,sizeof(mp_save_data));
p->type= mp_internal_sym;
p->link= mp->save_ptr;
p->value= mp->internal[q];
p->value.v.data.indep.serial= q;
new_number(p->value.v.data.n);
number_clone(p->value.v.data.n,mp->internal[q].v.data.n);
mp->save_ptr= p;
}
}

static void mp_unsave_internal(MP mp){
halfword q= mp->save_ptr->value.v.data.indep.serial;
mp_internal saved= mp->save_ptr->value;
if(number_positive(internal_value(mp_tracing_restores))){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{restoring ");
mp_print(mp,internal_name(q));
mp_print_char(mp,xord('='));
if(internal_type(q)==mp_known){
print_number(saved.v.data.n);
}else if(internal_type(q)==mp_string_type){
char*s= mp_str(mp,saved.v.data.str);
mp_print(mp,s);
}else{
mp_confusion(mp,"internal_restore");
}
mp_print_char(mp,xord('}'));
mp_end_diagnostic(mp,false);
}
free_number(mp->internal[q].v.data.n);
mp->internal[q]= saved;
}

/*:302*//*303:*/
#line 7023 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_unsave(MP mp){
mp_save_data*p;
FUNCTION_TRACE1("mp_unsave ()\n");
while(mp->save_ptr->type!=0){
if(mp->save_ptr->type==mp_internal_sym){
mp_unsave_internal(mp);
}else{
mp_unsave_variable(mp);
}
p= mp->save_ptr->link;
xfree(mp->save_ptr);
mp->save_ptr= p;
}
p= mp->save_ptr->link;
xfree(mp->save_ptr);
mp->save_ptr= p;
}


/*:303*//*310:*/
#line 7222 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_pr_path(MP mp,mp_knot h){
mp_knot p,q;
p= h;
do{
q= mp_next_knot(p);
if((p==NULL)||(q==NULL)){
mp_print_nl(mp,"???");
return;

}
/*311:*/
#line 7245 "../../../source/texk/web2c/mplibdir/mp.w"

mp_print_two(mp,p->x_coord,p->y_coord);
switch(mp_right_type(p)){
case mp_endpoint:
if(mp_left_type(p)==mp_open)
mp_print(mp,"{open?}");
;
if((mp_left_type(q)!=mp_endpoint)||(q!=h))
q= NULL;
goto DONE1;
break;
case mp_explicit:
/*314:*/
#line 7326 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_print(mp,"..controls ");
mp_print_two(mp,p->right_x,p->right_y);
mp_print(mp," and ");
if(mp_left_type(q)!=mp_explicit){
mp_print(mp,"??");

}else{
mp_print_two(mp,q->left_x,q->left_y);
}
goto DONE1;
}


/*:314*/
#line 7257 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_open:
/*315:*/
#line 7341 "../../../source/texk/web2c/mplibdir/mp.w"

if((mp_left_type(p)!=mp_explicit)&&(mp_left_type(p)!=mp_open)){
mp_print(mp,"{open?}");

}

/*:315*/
#line 7260 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_curl:
case mp_given:
/*316:*/
#line 7350 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_left_type(p)==mp_open)
mp_print(mp,"??");
;
if(mp_right_type(p)==mp_curl){
mp_print(mp,"{curl ");
print_number(p->right_curl);
}else{
mp_number n_sin,n_cos;
new_fraction(n_sin);
new_fraction(n_cos);
n_sin_cos(p->right_given,n_cos,n_sin);
mp_print_char(mp,xord('{'));
print_number(n_cos);
mp_print_char(mp,xord(','));
print_number(n_sin);
free_number(n_sin);
free_number(n_cos);
}
mp_print_char(mp,xord('}'));
}


/*:316*/
#line 7264 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
default:
mp_print(mp,"???");
;
break;
}
if(mp_left_type(q)<=mp_explicit){
mp_print(mp,"..control?");

}else if((!number_equal(p->right_tension,unity_t))||(!number_equal(q->left_tension,unity_t))){
/*313:*/
#line 7304 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number v1;
new_number(v1);
mp_print(mp,"..tension ");
if(number_negative(p->right_tension))
mp_print(mp,"atleast");
number_clone(v1,p->right_tension);
number_abs(v1);
print_number(v1);
if(!number_equal(p->right_tension,q->left_tension)){
mp_print(mp," and ");
if(number_negative(q->left_tension))
mp_print(mp,"atleast");
number_clone(v1,p->left_tension);
number_abs(v1);
print_number(v1);
}
free_number(v1);
}


/*:313*/
#line 7275 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

/*:311*/
#line 7233 "../../../source/texk/web2c/mplibdir/mp.w"
;
DONE1:
p= q;
if(p&&((p!=h)||(mp_left_type(h)!=mp_endpoint))){
/*312:*/
#line 7281 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number n_sin,n_cos;
new_fraction(n_sin);
new_fraction(n_cos);
mp_print_nl(mp," ..");
if(mp_left_type(p)==mp_given){
n_sin_cos(p->left_given,n_cos,n_sin);
mp_print_char(mp,xord('{'));
print_number(n_cos);
mp_print_char(mp,xord(','));
print_number(n_sin);
mp_print_char(mp,xord('}'));
}else if(mp_left_type(p)==mp_curl){
mp_print(mp,"{curl ");
print_number(p->left_curl);
mp_print_char(mp,xord('}'));
}
free_number(n_sin);
free_number(n_cos);
}


/*:312*/
#line 7237 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}while(p!=h);
if(mp_left_type(h)!=mp_endpoint)
mp_print(mp,"cycle");
}


/*:310*//*318:*/
#line 7380 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_path(MP mp,mp_knot h,const char*s,boolean nuline){
mp_print_diagnostic(mp,"Path",s,nuline);
mp_print_ln(mp);
;
mp_pr_path(mp,h);
mp_end_diagnostic(mp,true);
}


/*:318*//*320:*/
#line 7393 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_new_knot(MP mp){
mp_knot q;
if(mp->knot_nodes){
q= mp->knot_nodes;
mp->knot_nodes= q->next;
mp->num_knot_nodes--;
}else{
q= mp_xmalloc(mp,1,sizeof(struct mp_knot_data));
}
memset(q,0,sizeof(struct mp_knot_data));
new_number(q->x_coord);
new_number(q->y_coord);
new_number(q->left_x);
new_number(q->left_y);
new_number(q->right_x);
new_number(q->right_y);
return q;
}


/*:320*//*322:*/
#line 7417 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_gr_knot mp_gr_new_knot(MP mp){
mp_gr_knot q= mp_xmalloc(mp,1,sizeof(struct mp_gr_knot_data));
return q;
}


/*:322*//*323:*/
#line 7426 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_copy_knot(MP mp,mp_knot p){
mp_knot q;
if(mp->knot_nodes){
q= mp->knot_nodes;
mp->knot_nodes= q->next;
mp->num_knot_nodes--;
}else{
q= mp_xmalloc(mp,1,sizeof(struct mp_knot_data));
}
memcpy(q,p,sizeof(struct mp_knot_data));
if(mp->math_mode> mp_math_double_mode){
new_number(q->x_coord);
new_number(q->y_coord);
new_number(q->left_x);
new_number(q->left_y);
new_number(q->right_x);
new_number(q->right_y);
number_clone(q->x_coord,p->x_coord);
number_clone(q->y_coord,p->y_coord);
number_clone(q->left_x,p->left_x);
number_clone(q->left_y,p->left_y);
number_clone(q->right_x,p->right_x);
number_clone(q->right_y,p->right_y);
}
mp_next_knot(q)= NULL;
return q;
}

/*:323*//*324:*/
#line 7457 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_gr_knot mp_export_knot(MP mp,mp_knot p){
mp_gr_knot q;
q= mp_gr_new_knot(mp);
q->x_coord= number_to_double(p->x_coord);
q->y_coord= number_to_double(p->y_coord);
q->left_x= number_to_double(p->left_x);
q->left_y= number_to_double(p->left_y);
q->right_x= number_to_double(p->right_x);
q->right_y= number_to_double(p->right_y);
q->data.types.left_type= mp_left_type(p);
q->data.types.right_type= mp_left_type(p);
q->data.info= mp_knot_info(p);
mp_gr_next_knot(q)= NULL;
return q;
}


/*:324*//*325:*/
#line 7477 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_copy_path(MP mp,mp_knot p){
mp_knot q,pp,qq;
if(p==NULL)
return NULL;
q= mp_copy_knot(mp,p);
qq= q;
pp= mp_next_knot(p);
while(pp!=p){
mp_next_knot(qq)= mp_copy_knot(mp,pp);
qq= mp_next_knot(qq);
pp= mp_next_knot(pp);
}
mp_next_knot(qq)= q;
return q;
}

/*:325*//*326:*/
#line 7497 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_gr_knot mp_export_path(MP mp,mp_knot p){
mp_knot pp;
mp_gr_knot q,qq;
if(p==NULL)
return NULL;
q= mp_export_knot(mp,p);
qq= q;
pp= mp_next_knot(p);
while(pp!=p){
mp_gr_next_knot(qq)= mp_export_knot(mp,pp);
qq= mp_gr_next_knot(qq);
pp= mp_next_knot(pp);
}
mp_gr_next_knot(qq)= q;
return q;
}

/*:326*//*327:*/
#line 7517 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_import_knot(MP mp,mp_gr_knot p){
mp_knot q;
q= mp_new_knot(mp);
set_number_from_double(q->x_coord,p->x_coord);
set_number_from_double(q->y_coord,p->y_coord);
set_number_from_double(q->left_x,p->left_x);
set_number_from_double(q->left_y,p->left_y);
set_number_from_double(q->right_x,p->right_x);
set_number_from_double(q->right_y,p->right_y);
mp_left_type(q)= p->data.types.left_type;
mp_left_type(q)= p->data.types.right_type;
mp_knot_info(q)= p->data.info;
mp_next_knot(q)= NULL;
return q;
}


/*:327*//*328:*/
#line 7538 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_import_path(MP mp,mp_gr_knot p){
mp_gr_knot pp;
mp_knot q,qq;
if(p==NULL)
return NULL;
q= mp_import_knot(mp,p);
qq= q;
pp= mp_gr_next_knot(p);
while(pp!=p){
mp_next_knot(qq)= mp_import_knot(mp,pp);
qq= mp_next_knot(qq);
pp= mp_gr_next_knot(pp);
}
mp_next_knot(qq)= q;
return q;
}


/*:328*//*330:*/
#line 7562 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_gr_knot mp_export_knot_list(MP mp,mp_knot p){
mp_gr_knot q;
if(p==NULL)
return NULL;
q= mp_export_path(mp,p);
return q;
}
static mp_knot mp_import_knot_list(MP mp,mp_gr_knot q){
mp_knot p;
if(q==NULL)
return NULL;
p= mp_import_path(mp,q);
return p;
}

/*:330*//*331:*/
#line 7586 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_htap_ypoc(MP mp,mp_knot p){
mp_knot q,pp,qq,rr;
q= mp_new_knot(mp);
qq= q;
pp= p;
while(1){
mp_right_type(qq)= mp_left_type(pp);
mp_left_type(qq)= mp_right_type(pp);
number_clone(qq->x_coord,pp->x_coord);
number_clone(qq->y_coord,pp->y_coord);
number_clone(qq->right_x,pp->left_x);
number_clone(qq->right_y,pp->left_y);
number_clone(qq->left_x,pp->right_x);
number_clone(qq->left_y,pp->right_y);
mp_originator(qq)= mp_originator(pp);
if(mp_next_knot(pp)==p){
mp_next_knot(q)= qq;
mp->path_tail= pp;
return q;
}
rr= mp_new_knot(mp);
mp_next_knot(rr)= qq;
qq= rr;
pp= mp_next_knot(pp);
}
}


/*:331*//*334:*/
#line 7626 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_free_knot(MP mp,mp_knot q){
free_number(q->x_coord);
free_number(q->y_coord);
free_number(q->left_x);
free_number(q->left_y);
free_number(q->right_x);
free_number(q->right_y);
mp_xfree(q);
}
void mp_toss_knot(MP mp,mp_knot q){
if(mp->num_knot_nodes<max_num_knot_nodes){
q->next= mp->knot_nodes;
mp->knot_nodes= q;
mp->num_knot_nodes++;
return;
}
if(mp->math_mode> mp_math_double_mode){
mp_free_knot(mp,q);
}else{
mp_xfree(q);
}
}
void mp_toss_knot_list(MP mp,mp_knot p){
mp_knot q;
mp_knot r;
if(p==NULL)
return;
q= p;
if(mp->math_mode> mp_math_double_mode){
do{
r= mp_next_knot(q);
mp_toss_knot(mp,q);
q= r;
}while(q!=p);
}else{
do{
r= mp_next_knot(q);
if(mp->num_knot_nodes<max_num_knot_nodes){
q->next= mp->knot_nodes;
mp->knot_nodes= q;
mp->num_knot_nodes++;
}else{
mp_xfree(q);
}
q= r;
}while(q!=p);
}
}


/*:334*//*335:*/
#line 7688 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_make_choices(MP mp,mp_knot knots){
mp_knot h;
mp_knot p,q;
/*349:*/
#line 7951 "../../../source/texk/web2c/mplibdir/mp.w"

int k,n;
mp_knot s,t;

/*:349*/
#line 7692 "../../../source/texk/web2c/mplibdir/mp.w"
;
FUNCTION_TRACE1("make_choices()\n");
check_arith();
if(number_positive(internal_value(mp_tracing_choices)))
mp_print_path(mp,knots,", before choices",true);
/*338:*/
#line 7732 "../../../source/texk/web2c/mplibdir/mp.w"

p= knots;
do{
q= mp_next_knot(p);
if(number_equal(p->x_coord,q->x_coord)&&
number_equal(p->y_coord,q->y_coord)&&
mp_right_type(p)> mp_explicit){
mp_right_type(p)= mp_explicit;
if(mp_left_type(p)==mp_open){
mp_left_type(p)= mp_curl;
set_number_to_unity(p->left_curl);
}
mp_left_type(q)= mp_explicit;
if(mp_right_type(q)==mp_open){
mp_right_type(q)= mp_curl;
set_number_to_unity(q->right_curl);
}
number_clone(p->right_x,p->x_coord);
number_clone(q->left_x,p->x_coord);
number_clone(p->right_y,p->y_coord);
number_clone(q->left_y,p->y_coord);
}
p= q;
}while(p!=knots)

/*:338*/
#line 7697 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*339:*/
#line 7761 "../../../source/texk/web2c/mplibdir/mp.w"

h= knots;
while(1){
if(mp_left_type(h)!=mp_open)
break;
if(mp_right_type(h)!=mp_open)
break;
h= mp_next_knot(h);
if(h==knots){
mp_left_type(h)= mp_end_cycle;
break;
}
}


/*:339*/
#line 7699 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= h;
do{
/*340:*/
#line 7779 "../../../source/texk/web2c/mplibdir/mp.w"

q= mp_next_knot(p);
if(mp_right_type(p)>=mp_given){
while((mp_left_type(q)==mp_open)&&(mp_right_type(q)==mp_open)){
q= mp_next_knot(q);
}
/*346:*/
#line 7916 "../../../source/texk/web2c/mplibdir/mp.w"

/*350:*/
#line 7955 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number sine,cosine;
new_fraction(sine);
new_fraction(cosine);
RESTART:
k= 0;
s= p;
n= mp->path_size;
do{
t= mp_next_knot(s);
set_number_from_substraction(mp->delta_x[k],t->x_coord,s->x_coord);
set_number_from_substraction(mp->delta_y[k],t->y_coord,s->y_coord);
pyth_add(mp->delta[k],mp->delta_x[k],mp->delta_y[k]);
if(k> 0){
mp_number arg1,arg2,r1,r2;
new_number(arg1);
new_number(arg2);
new_fraction(r1);
new_fraction(r2);
make_fraction(r1,mp->delta_y[k-1],mp->delta[k-1]);
number_clone(sine,r1);
make_fraction(r2,mp->delta_x[k-1],mp->delta[k-1]);
number_clone(cosine,r2);
take_fraction(r1,mp->delta_x[k],cosine);
take_fraction(r2,mp->delta_y[k],sine);
set_number_from_addition(arg1,r1,r2);
take_fraction(r1,mp->delta_y[k],cosine);
take_fraction(r2,mp->delta_x[k],sine);
set_number_from_substraction(arg2,r1,r2);
n_arg(mp->psi[k],arg1,arg2);
free_number(r1);
free_number(r2);
free_number(arg1);
free_number(arg2);
}
incr(k);
s= t;
if(k==mp->path_size){
mp_reallocate_paths(mp,mp->path_size+(mp->path_size/4));
goto RESTART;
}
if(s==q)
n= k;
}while(!((k>=n)&&(mp_left_type(s)!=mp_end_cycle)));
if(k==n)
set_number_to_zero(mp->psi[k]);
else
number_clone(mp->psi[k],mp->psi[1]);
free_number(sine);
free_number(cosine);
}


/*:350*/
#line 7918 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*351:*/
#line 8019 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number delx,dely;
new_number(delx);
new_number(dely);
if(mp_left_type(q)==mp_open){
set_number_from_substraction(delx,q->right_x,q->x_coord);
set_number_from_substraction(dely,q->right_y,q->y_coord);
if(number_zero(delx)&&number_zero(dely)){
mp_left_type(q)= mp_curl;
set_number_to_unity(q->left_curl);
}else{
mp_left_type(q)= mp_given;
n_arg(q->left_given,delx,dely);
}
}
if((mp_right_type(p)==mp_open)&&(mp_left_type(p)==mp_explicit)){
set_number_from_substraction(delx,p->x_coord,p->left_x);
set_number_from_substraction(dely,p->y_coord,p->left_y);
if(number_zero(delx)&&number_zero(dely)){
mp_right_type(p)= mp_curl;
set_number_to_unity(p->right_curl);
}else{
mp_right_type(p)= mp_given;
n_arg(p->right_given,delx,dely);
}
}
free_number(delx);
free_number(dely);
}

/*:351*/
#line 7919 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_solve_choices(mp,p,q,n)


/*:346*/
#line 7785 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(mp_right_type(p)==mp_endpoint){
/*341:*/
#line 7794 "../../../source/texk/web2c/mplibdir/mp.w"

{
number_clone(p->right_x,p->x_coord);
number_clone(p->right_y,p->y_coord);
number_clone(q->left_x,q->x_coord);
number_clone(q->left_y,q->y_coord);
}


/*:341*/
#line 7787 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
p= q

/*:340*/
#line 7703 "../../../source/texk/web2c/mplibdir/mp.w"
;
}while(p!=h);
if(number_positive(internal_value(mp_tracing_choices)))
mp_print_path(mp,knots,", after choices",true);
if(mp->arith_error){
/*337:*/
#line 7715 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"The path that I just computed is out of range.",
"So it will probably look funny. Proceed, for a laugh.",
NULL};
mp_back_error(mp,"Some number got too big",hlp,true);
;
mp_get_x_next(mp);
mp->arith_error= false;
}


/*:337*/
#line 7708 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}

/*:335*//*355:*/
#line 8108 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_reallocate_paths(MP mp,int l){
int k;
XREALLOC(mp->delta_x,l,mp_number);
XREALLOC(mp->delta_y,l,mp_number);
XREALLOC(mp->delta,l,mp_number);
XREALLOC(mp->psi,l,mp_number);
XREALLOC(mp->theta,l,mp_number);
XREALLOC(mp->uu,l,mp_number);
XREALLOC(mp->vv,l,mp_number);
XREALLOC(mp->ww,l,mp_number);
for(k= mp->path_size;k<l;k++){
new_number(mp->delta_x[k]);
new_number(mp->delta_y[k]);
new_number(mp->delta[k]);
new_angle(mp->psi[k]);
new_angle(mp->theta[k]);
new_fraction(mp->uu[k]);
new_angle(mp->vv[k]);
new_fraction(mp->ww[k]);
}
mp->path_size= l;
}


/*:355*//*357:*/
#line 8140 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_solve_choices(MP mp,mp_knot p,mp_knot q,halfword n){
int k;
mp_knot r,s,t;
mp_number ff;
new_fraction(ff);
FUNCTION_TRACE2("solve_choices(%d)\n",n);
k= 0;
s= p;
r= 0;
while(1){
t= mp_next_knot(s);
if(k==0){
/*358:*/
#line 8187 "../../../source/texk/web2c/mplibdir/mp.w"

switch(mp_right_type(s)){
case mp_given:
if(mp_left_type(t)==mp_given){
/*380:*/
#line 8827 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number arg1;
mp_number narg;
new_angle(narg);
n_arg(narg,mp->delta_x[0],mp->delta_y[0]);
new_number(arg1);
set_number_from_substraction(arg1,p->right_given,narg);
n_sin_cos(arg1,mp->ct,mp->st);
set_number_from_substraction(arg1,q->left_given,narg);
n_sin_cos(arg1,mp->cf,mp->sf);
number_negate(mp->sf);
mp_set_controls(mp,p,q,0);
free_number(narg);
free_number(arg1);
free_number(ff);
return;
}


/*:380*/
#line 8191 "../../../source/texk/web2c/mplibdir/mp.w"

}else{
/*368:*/
#line 8493 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number narg;
new_angle(narg);
n_arg(narg,mp->delta_x[0],mp->delta_y[0]);
set_number_from_substraction(mp->vv[0],s->right_given,narg);
free_number(narg);
mp_reduce_angle(mp,&mp->vv[0]);
set_number_to_zero(mp->uu[0]);
set_number_to_zero(mp->ww[0]);
}


/*:368*/
#line 8193 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
break;
case mp_curl:
if(mp_left_type(t)==mp_curl){
/*381:*/
#line 8847 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number lt,rt;
mp_right_type(p)= mp_explicit;
mp_left_type(q)= mp_explicit;
new_number(lt);
new_number(rt);
number_clone(lt,q->left_tension);
number_abs(lt);
number_clone(rt,p->right_tension);
number_abs(rt);
if(number_unity(rt)){
mp_number arg2;
new_number(arg2);
if(number_nonnegative(mp->delta_x[0])){
set_number_from_addition(arg2,mp->delta_x[0],epsilon_t);
}else{
set_number_from_substraction(arg2,mp->delta_x[0],epsilon_t);
}
number_int_div(arg2,3);
set_number_from_addition(p->right_x,p->x_coord,arg2);
if(number_nonnegative(mp->delta_y[0])){
set_number_from_addition(arg2,mp->delta_y[0],epsilon_t);
}else{
set_number_from_substraction(arg2,mp->delta_y[0],epsilon_t);
}
number_int_div(arg2,3);
set_number_from_addition(p->right_y,p->y_coord,arg2);
free_number(arg2);
}else{
mp_number arg2,r1;
new_fraction(r1);
new_number(arg2);
number_clone(arg2,rt);
number_multiply_int(arg2,3);
make_fraction(ff,unity_t,arg2);
free_number(arg2);
take_fraction(r1,mp->delta_x[0],ff);
set_number_from_addition(p->right_x,p->x_coord,r1);
take_fraction(r1,mp->delta_y[0],ff);
set_number_from_addition(p->right_y,p->y_coord,r1);
}
if(number_unity(lt)){
mp_number arg2;
new_number(arg2);
if(number_nonnegative(mp->delta_x[0])){
set_number_from_addition(arg2,mp->delta_x[0],epsilon_t);
}else{
set_number_from_substraction(arg2,mp->delta_x[0],epsilon_t);
}
number_int_div(arg2,3);
set_number_from_substraction(q->left_x,q->x_coord,arg2);
if(number_nonnegative(mp->delta_y[0])){
set_number_from_addition(arg2,mp->delta_y[0],epsilon_t);
}else{
set_number_from_substraction(arg2,mp->delta_y[0],epsilon_t);
}
number_int_div(arg2,3);
set_number_from_substraction(q->left_y,q->y_coord,arg2);
free_number(arg2);
}else{
mp_number arg2,r1;
new_fraction(r1);
new_number(arg2);
number_clone(arg2,lt);
number_multiply_int(arg2,3);
make_fraction(ff,unity_t,arg2);
free_number(arg2);
take_fraction(r1,mp->delta_x[0],ff);
set_number_from_substraction(q->left_x,q->x_coord,r1);
take_fraction(r1,mp->delta_y[0],ff);
set_number_from_substraction(q->left_y,q->y_coord,r1);
free_number(r1);
}
free_number(ff);
free_number(lt);
free_number(rt);
return;
}

/*:381*/
#line 8198 "../../../source/texk/web2c/mplibdir/mp.w"

}else{
/*369:*/
#line 8506 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number lt,rt,cc;
new_number(lt);
new_number(rt);
new_number(cc);
number_clone(cc,s->right_curl);
number_clone(lt,t->left_tension);
number_abs(lt);
number_clone(rt,s->right_tension);
number_abs(rt);
if(number_unity(rt)&&number_unity(lt)){
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
number_clone(arg1,cc);
number_double(arg1);
number_add(arg1,unity_t);
number_clone(arg2,cc);
number_add(arg2,two_t);
make_fraction(mp->uu[0],arg1,arg2);
free_number(arg1);
free_number(arg2);
}else{
mp_curl_ratio(mp,&mp->uu[0],cc,rt,lt);
}
take_fraction(mp->vv[0],mp->psi[1],mp->uu[0]);
number_negate(mp->vv[0]);
set_number_to_zero(mp->ww[0]);
free_number(rt);
free_number(lt);
free_number(cc);
}


/*:369*/
#line 8200 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
break;
case mp_open:
set_number_to_zero(mp->uu[0]);
set_number_to_zero(mp->vv[0]);
number_clone(mp->ww[0],fraction_one_t);

break;
}


/*:358*/
#line 8155 "../../../source/texk/web2c/mplibdir/mp.w"

}else{
switch(mp_left_type(s)){
case mp_end_cycle:
case mp_open:
/*360:*/
#line 8228 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number aa,bb,cc,acc;
mp_number dd,ee;
new_fraction(aa);
new_fraction(bb);
new_fraction(cc);
new_fraction(acc);
new_number(dd);
new_number(ee);
/*361:*/
#line 8259 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number absval;
new_number(absval);
number_clone(absval,r->right_tension);
number_abs(absval);
if(number_equal(absval,unity_t)){
number_clone(aa,fraction_half_t);
number_clone(dd,mp->delta[k]);
number_double(dd);
}else{
mp_number arg1,arg2,ret;
new_number(arg2);
new_number(arg1);
number_clone(arg2,r->right_tension);
number_abs(arg2);
number_multiply_int(arg2,3);
number_substract(arg2,unity_t);
make_fraction(aa,unity_t,arg2);
number_clone(arg2,r->right_tension);
number_abs(arg2);
new_fraction(ret);
make_fraction(ret,unity_t,arg2);
set_number_from_substraction(arg1,fraction_three_t,ret);
take_fraction(arg2,mp->delta[k],arg1);
number_clone(dd,arg2);
free_number(ret);
free_number(arg1);
free_number(arg2);
}
number_clone(absval,t->left_tension);
number_abs(absval);
if(number_equal(absval,unity_t)){
number_clone(bb,fraction_half_t);
number_clone(ee,mp->delta[k-1]);
number_double(ee);
}else{
mp_number arg1,arg2,ret;
new_number(arg1);
new_number(arg2);
number_clone(arg2,t->left_tension);
number_abs(arg2);
number_multiply_int(arg2,3);
number_substract(arg2,unity_t);
make_fraction(bb,unity_t,arg2);
number_clone(arg2,t->left_tension);
number_abs(arg2);
new_fraction(ret);
make_fraction(ret,unity_t,arg2);
set_number_from_substraction(arg1,fraction_three_t,ret);
take_fraction(ee,mp->delta[k-1],arg1);
free_number(ret);
free_number(arg1);
free_number(arg2);
}
free_number(absval);
}
{
mp_number r1;
new_number(r1);
take_fraction(r1,mp->uu[k-1],aa);
set_number_from_substraction(cc,fraction_one_t,r1);
free_number(r1);
}

/*:361*/
#line 8240 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*362:*/
#line 8330 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number rt,lt;
mp_number arg2;
new_number(arg2);
number_clone(arg2,dd);
take_fraction(dd,arg2,cc);
new_number(lt);
new_number(rt);
number_clone(lt,s->left_tension);
number_abs(lt);
number_clone(rt,s->right_tension);
number_abs(rt);
if(!number_equal(lt,rt)){
mp_number r1;
new_number(r1);
if(number_less(lt,rt)){
make_fraction(r1,lt,rt);
take_fraction(ff,r1,r1);
number_clone(r1,dd);
take_fraction(dd,r1,ff);
}else{
make_fraction(r1,rt,lt);
take_fraction(ff,r1,r1);
number_clone(r1,ee);
take_fraction(ee,r1,ff);
}
free_number(r1);
}
free_number(rt);
free_number(lt);
set_number_from_addition(arg2,dd,ee);
make_fraction(ff,ee,arg2);
free_number(arg2);
}


/*:362*/
#line 8241 "../../../source/texk/web2c/mplibdir/mp.w"
;
take_fraction(mp->uu[k],ff,bb);
/*363:*/
#line 8375 "../../../source/texk/web2c/mplibdir/mp.w"

take_fraction(acc,mp->psi[k+1],mp->uu[k]);
number_negate(acc);
if(mp_right_type(r)==mp_curl){
mp_number r1,arg2;
new_fraction(r1);
new_number(arg2);
set_number_from_substraction(arg2,fraction_one_t,ff);
take_fraction(r1,mp->psi[1],arg2);
set_number_to_zero(mp->ww[k]);
set_number_from_substraction(mp->vv[k],acc,r1);
free_number(r1);
free_number(arg2);
}else{
mp_number arg1,r1;
new_fraction(r1);
new_number(arg1);
set_number_from_substraction(arg1,fraction_one_t,ff);
make_fraction(ff,arg1,cc);
free_number(arg1);
take_fraction(r1,mp->psi[k],ff);
number_substract(acc,r1);
number_clone(r1,ff);
take_fraction(ff,r1,aa);
take_fraction(r1,mp->vv[k-1],ff);
set_number_from_substraction(mp->vv[k],acc,r1);
if(number_zero(mp->ww[k-1])){
set_number_to_zero(mp->ww[k]);
}else{
take_fraction(mp->ww[k],mp->ww[k-1],ff);
number_negate(mp->ww[k]);
}
free_number(r1);
}


/*:363*/
#line 8243 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp_left_type(s)==mp_end_cycle){
/*364:*/
#line 8423 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number arg2,r1;
new_number(arg2);
new_number(r1);
set_number_to_zero(aa);
number_clone(bb,fraction_one_t);
do{
decr(k);
if(k==0)
k= n;
take_fraction(r1,aa,mp->uu[k]);
set_number_from_substraction(aa,mp->vv[k],r1);
take_fraction(r1,bb,mp->uu[k]);
set_number_from_substraction(bb,mp->ww[k],r1);
}while(k!=n);
set_number_from_substraction(arg2,fraction_one_t,bb);
make_fraction(r1,aa,arg2);
number_clone(aa,r1);
number_clone(mp->theta[n],aa);
number_clone(mp->vv[0],aa);
for(k= 1;k<n;k++){
take_fraction(r1,aa,mp->ww[k]);
number_add(mp->vv[k],r1);
}
free_number(arg2);
free_number(r1);
free_number(aa);
free_number(bb);
free_number(cc);
free_number(acc);
free_number(dd);
free_number(ee);
goto FOUND;
}


/*:364*/
#line 8245 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
free_number(aa);
free_number(bb);
free_number(cc);
free_number(acc);
free_number(dd);
free_number(ee);
}


/*:360*/
#line 8162 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_curl:
/*370:*/
#line 8541 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number lt,rt,cc;
new_number(lt);
new_number(rt);
new_number(cc);
number_clone(cc,s->left_curl);
number_clone(lt,s->left_tension);
number_abs(lt);
number_clone(rt,r->right_tension);
number_abs(rt);
if(number_unity(rt)&&number_unity(lt)){
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
number_clone(arg1,cc);
number_double(arg1);
number_add(arg1,unity_t);
number_clone(arg2,cc);
number_add(arg2,two_t);
make_fraction(ff,arg1,arg2);
free_number(arg1);
free_number(arg2);
}else{
mp_curl_ratio(mp,&ff,cc,lt,rt);
}
{
mp_number arg1,arg2,r1;
new_fraction(r1);
new_fraction(arg1);
new_number(arg2);
take_fraction(arg1,mp->vv[n-1],ff);
take_fraction(r1,ff,mp->uu[n-1]);
set_number_from_substraction(arg2,fraction_one_t,r1);
make_fraction(mp->theta[n],arg1,arg2);
number_negate(mp->theta[n]);
free_number(r1);
free_number(arg1);
free_number(arg2);
}
free_number(rt);
free_number(lt);
free_number(cc);
goto FOUND;
}


/*:370*/
#line 8166 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_given:
/*367:*/
#line 8481 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number narg;
new_angle(narg);
n_arg(narg,mp->delta_x[n-1],mp->delta_y[n-1]);
set_number_from_substraction(mp->theta[n],s->left_given,narg);
free_number(narg);
mp_reduce_angle(mp,&mp->theta[n]);
goto FOUND;
}


/*:367*/
#line 8170 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
}
}
r= s;
s= t;
incr(k);
}
FOUND:
/*373:*/
#line 8659 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1;
new_number(r1);
for(k= n-1;k>=0;k--){
take_fraction(r1,mp->theta[k+1],mp->uu[k]);
set_number_from_substraction(mp->theta[k],mp->vv[k],r1);
}
free_number(r1);
}
s= p;
k= 0;
{
mp_number arg;
new_number(arg);
do{
t= mp_next_knot(s);
n_sin_cos(mp->theta[k],mp->ct,mp->st);
number_clone(arg,mp->psi[k+1]);
number_negate(arg);
number_substract(arg,mp->theta[k+1]);
n_sin_cos(arg,mp->cf,mp->sf);
mp_set_controls(mp,s,t,k);
incr(k);
s= t;
}while(k!=n);
free_number(arg);
}


/*:373*/
#line 8179 "../../../source/texk/web2c/mplibdir/mp.w"
;
free_number(ff);
}


/*:357*//*365:*/
#line 8460 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_reduce_angle(MP mp,mp_number*a){
mp_number abs_a;
FUNCTION_TRACE2("reduce_angle(%f)\n",number_to_double(*a));
new_number(abs_a);
number_clone(abs_a,*a);
number_abs(abs_a);
if(number_greater(abs_a,one_eighty_deg_t)){
if(number_positive(*a)){
number_substract(*a,three_sixty_deg_t);
}else{
number_add(*a,three_sixty_deg_t);
}
}
free_number(abs_a);
}

/*:365*//*372:*/
#line 8601 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_curl_ratio(MP mp,mp_number*ret,mp_number gamma_orig,mp_number a_tension,mp_number b_tension){
mp_number alpha,beta,gamma,num,denom,ff;
mp_number arg1;
new_number(arg1);
new_fraction(alpha);
new_fraction(beta);
new_fraction(gamma);
new_fraction(ff);
new_fraction(denom);
new_fraction(num);
make_fraction(alpha,unity_t,a_tension);
make_fraction(beta,unity_t,b_tension);
number_clone(gamma,gamma_orig);
if(number_lessequal(alpha,beta)){
make_fraction(ff,alpha,beta);
number_clone(arg1,ff);
take_fraction(ff,arg1,arg1);
number_clone(arg1,gamma);
take_fraction(gamma,arg1,ff);
convert_fraction_to_scaled(beta);
take_fraction(denom,gamma,alpha);
number_add(denom,three_t);
}else{
make_fraction(ff,beta,alpha);
number_clone(arg1,ff);
take_fraction(ff,arg1,arg1);
take_fraction(arg1,beta,ff);
convert_fraction_to_scaled(arg1);
number_clone(beta,arg1);
take_fraction(denom,gamma,alpha);
set_number_from_div(arg1,ff,twelvebits_3);
number_add(denom,arg1);
}
number_substract(denom,beta);
set_number_from_substraction(arg1,fraction_three_t,alpha);
take_fraction(num,gamma,arg1);
number_add(num,beta);
number_clone(arg1,denom);
number_double(arg1);
number_double(arg1);
if(number_greaterequal(num,arg1)){
number_clone(*ret,fraction_four_t);
}else{
make_fraction(*ret,num,denom);
}
free_number(alpha);
free_number(beta);
free_number(gamma);
free_number(num);
free_number(denom);
free_number(ff);
free_number(arg1);
}


/*:372*//*378:*/
#line 8716 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_set_controls(MP mp,mp_knot p,mp_knot q,integer k){
mp_number rr,ss;
mp_number lt,rt;
mp_number sine;
mp_number tmp;
mp_number r1,r2;
new_number(tmp);
new_number(lt);
new_number(rt);
new_number(r1);
new_number(r2);
number_clone(lt,q->left_tension);
number_abs(lt);
number_clone(rt,p->right_tension);
number_abs(rt);
new_fraction(sine);
new_fraction(rr);
new_fraction(ss);
velocity(rr,mp->st,mp->ct,mp->sf,mp->cf,rt);
velocity(ss,mp->sf,mp->cf,mp->st,mp->ct,lt);
if(number_negative(p->right_tension)||number_negative(q->left_tension)){
/*379:*/
#line 8779 "../../../source/texk/web2c/mplibdir/mp.w"

if((number_nonnegative(mp->st)&&number_nonnegative(mp->sf))||(number_nonpositive(mp->st)&&number_nonpositive(mp->sf))){
mp_number r1,r2,arg1;
mp_number ab_vs_cd;
new_number(ab_vs_cd);
new_fraction(r1);
new_fraction(r2);
new_number(arg1);
number_clone(arg1,mp->st);
number_abs(arg1);
take_fraction(r1,arg1,mp->cf);
number_clone(arg1,mp->sf);
number_abs(arg1);
take_fraction(r2,arg1,mp->ct);
set_number_from_addition(sine,r1,r2);
if(number_positive(sine)){
set_number_from_addition(arg1,fraction_one_t,unity_t);
number_clone(r1,sine);
take_fraction(sine,r1,arg1);
if(number_negative(p->right_tension)){
number_clone(arg1,mp->sf);
number_abs(arg1);
ab_vs_cd(ab_vs_cd,arg1,fraction_one_t,rr,sine);
if(number_negative(ab_vs_cd)){
number_clone(arg1,mp->sf);
number_abs(arg1);
make_fraction(rr,arg1,sine);
}
}
if(number_negative(q->left_tension)){
number_clone(arg1,mp->st);
number_abs(arg1);
ab_vs_cd(ab_vs_cd,arg1,fraction_one_t,ss,sine);
if(number_negative(ab_vs_cd)){
number_clone(arg1,mp->st);
number_abs(arg1);
make_fraction(ss,arg1,sine);
}
}
}
free_number(arg1);
free_number(r1);
free_number(r2);
free_number(ab_vs_cd);
}

/*:379*/
#line 8739 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
take_fraction(r1,mp->delta_x[k],mp->ct);
take_fraction(r2,mp->delta_y[k],mp->st);
number_substract(r1,r2);
take_fraction(tmp,r1,rr);
set_number_from_addition(p->right_x,p->x_coord,tmp);
take_fraction(r1,mp->delta_y[k],mp->ct);
take_fraction(r2,mp->delta_x[k],mp->st);
number_add(r1,r2);
take_fraction(tmp,r1,rr);
set_number_from_addition(p->right_y,p->y_coord,tmp);
take_fraction(r1,mp->delta_x[k],mp->cf);
take_fraction(r2,mp->delta_y[k],mp->sf);
number_add(r1,r2);
take_fraction(tmp,r1,ss);
set_number_from_substraction(q->left_x,q->x_coord,tmp);
take_fraction(r1,mp->delta_y[k],mp->cf);
take_fraction(r2,mp->delta_x[k],mp->sf);
number_substract(r1,r2);
take_fraction(tmp,r1,ss);
set_number_from_substraction(q->left_y,q->y_coord,tmp);
mp_right_type(p)= mp_explicit;
mp_left_type(q)= mp_explicit;
free_number(tmp);
free_number(r1);
free_number(r2);
free_number(lt);
free_number(rt);
free_number(rr);
free_number(ss);
free_number(sine);
}


/*:378*//*382:*/
#line 8930 "../../../source/texk/web2c/mplibdir/mp.w"

#define TOO_LARGE(a) (fabs((a))> 4096.0)
#define PI 3.1415926535897932384626433832795028841971

static int out_of_range(MP mp,double a)
{
mp_number t;
new_number(t);
set_number_from_double(t,fabs(a));
if(number_greaterequal(t,inf_t)){
free_number(t);
return 1;
}
free_number(t);
return 0;
}

static int mp_link_knotpair(MP mp,mp_knot p,mp_knot q);
static int mp_link_knotpair(MP mp,mp_knot p,mp_knot q)
{
if(p==NULL||q==NULL)return 0;
p->next= q;
set_number_from_double(p->right_tension,1.0);
if(mp_right_type(p)==mp_endpoint){
mp_right_type(p)= mp_open;
}
set_number_from_double(q->left_tension,1.0);
if(mp_left_type(q)==mp_endpoint){
mp_left_type(q)= mp_open;
}
return 1;
}

int mp_close_path_cycle(MP mp,mp_knot p,mp_knot q)
{
return mp_link_knotpair(mp,p,q);
}

int mp_close_path(MP mp,mp_knot q,mp_knot first)
{
if(q==NULL||first==NULL)return 0;
q->next= first;
mp_right_type(q)= mp_endpoint;
set_number_from_double(q->right_tension,1.0);
mp_left_type(first)= mp_endpoint;
set_number_from_double(first->left_tension,1.0);
return 1;
}

mp_knot mp_create_knot(MP mp)
{
mp_knot q= mp_new_knot(mp);
mp_left_type(q)= mp_endpoint;
mp_right_type(q)= mp_endpoint;
return q;
}

int mp_set_knot(MP mp,mp_knot p,double x,double y)
{
if(out_of_range(mp,x))return 0;
if(out_of_range(mp,y))return 0;
if(p==NULL)return 0;
set_number_from_double(p->x_coord,x);
set_number_from_double(p->y_coord,y);
return 1;
}

mp_knot mp_append_knot(MP mp,mp_knot p,double x,double y)
{
mp_knot q= mp_create_knot(mp);
if(q==NULL)return NULL;
if(!mp_set_knot(mp,q,x,y)){
free(q);
return NULL;
}
if(p==NULL)return q;
if(!mp_link_knotpair(mp,p,q)){
free(q);
return NULL;
}
return q;
}

int mp_set_knot_curl(MP mp,mp_knot q,double value){
if(q==NULL)return 0;
if(TOO_LARGE(value))return 0;
mp_right_type(q)= mp_curl;
set_number_from_double(q->right_curl,value);
if(mp_left_type(q)==mp_open){
mp_left_type(q)= mp_curl;
set_number_from_double(q->left_curl,value);
}
return 1;
}

int mp_set_knot_left_curl(MP mp,mp_knot q,double value){
if(q==NULL)return 0;
if(TOO_LARGE(value))return 0;
mp_left_type(q)= mp_curl;
set_number_from_double(q->left_curl,value);
if(mp_right_type(q)==mp_open){
mp_right_type(q)= mp_curl;
set_number_from_double(q->right_curl,value);
}
return 1;
}

int mp_set_knot_right_curl(MP mp,mp_knot q,double value){
if(q==NULL)return 0;
if(TOO_LARGE(value))return 0;
mp_right_type(q)= mp_curl;
set_number_from_double(q->right_curl,value);
if(mp_left_type(q)==mp_open){
mp_left_type(q)= mp_curl;
set_number_from_double(q->left_curl,value);
}
return 1;
}

int mp_set_knotpair_curls(MP mp,mp_knot p,mp_knot q,double t1,double t2){
if(p==NULL||q==NULL)return 0;
if(mp_set_knot_curl(mp,p,t1))
return mp_set_knot_curl(mp,q,t2);
return 0;
}

int mp_set_knotpair_tensions(MP mp,mp_knot p,mp_knot q,double t1,double t2){
if(p==NULL||q==NULL)return 0;
if(TOO_LARGE(t1))return 0;
if(TOO_LARGE(t2))return 0;
if((fabs(t1)<0.75))return 0;
if((fabs(t2)<0.75))return 0;
set_number_from_double(p->right_tension,t1);
set_number_from_double(q->left_tension,t2);
return 1;
}

int mp_set_knot_left_tension(MP mp,mp_knot p,double t1){
if(p==NULL)return 0;
if(TOO_LARGE(t1))return 0;
if((fabs(t1)<0.75))return 0;
set_number_from_double(p->left_tension,t1);
return 1;
}

int mp_set_knot_right_tension(MP mp,mp_knot p,double t1){
if(p==NULL)return 0;
if(TOO_LARGE(t1))return 0;
if((fabs(t1)<0.75))return 0;
set_number_from_double(p->right_tension,t1);
return 1;
}

int mp_set_knotpair_controls(MP mp,mp_knot p,mp_knot q,double x1,double y1,double x2,double y2){
if(p==NULL||q==NULL)return 0;
if(out_of_range(mp,x1))return 0;
if(out_of_range(mp,y1))return 0;
if(out_of_range(mp,x2))return 0;
if(out_of_range(mp,y2))return 0;
mp_right_type(p)= mp_explicit;
set_number_from_double(p->right_x,x1);
set_number_from_double(p->right_y,y1);
mp_left_type(q)= mp_explicit;
set_number_from_double(q->left_x,x2);
set_number_from_double(q->left_y,y2);
return 1;
}

int mp_set_knot_left_control(MP mp,mp_knot p,double x1,double y1){
if(p==NULL)return 0;
if(out_of_range(mp,x1))return 0;
if(out_of_range(mp,y1))return 0;
mp_left_type(p)= mp_explicit;
set_number_from_double(p->left_x,x1);
set_number_from_double(p->left_y,y1);
return 1;
}

int mp_set_knot_right_control(MP mp,mp_knot p,double x1,double y1){
if(p==NULL)return 0;
if(out_of_range(mp,x1))return 0;
if(out_of_range(mp,y1))return 0;
mp_right_type(p)= mp_explicit;
set_number_from_double(p->right_x,x1);
set_number_from_double(p->right_y,y1);
return 1;
}

int mp_set_knot_direction(MP mp,mp_knot q,double x,double y){
double value= 0;
if(q==NULL)return 0;
if(TOO_LARGE(x))return 0;
if(TOO_LARGE(y))return 0;
if(!(x==0&&y==0))
value= atan2(y,x)*(180.0/PI)*16.0;
mp_right_type(q)= mp_given;
set_number_from_double(q->right_curl,value);
if(mp_left_type(q)==mp_open){
mp_left_type(q)= mp_given;
set_number_from_double(q->left_curl,value);
}
return 1;
}

int mp_set_knotpair_directions(MP mp,mp_knot p,mp_knot q,double x1,double y1,double x2,double y2){
if(p==NULL||q==NULL)return 0;
if(mp_set_knot_direction(mp,p,x1,y1))
return mp_set_knot_direction(mp,q,x2,y2);
return 0;
}

/*:382*//*383:*/
#line 9142 "../../../source/texk/web2c/mplibdir/mp.w"

static int path_needs_fixing(mp_knot source);
static int path_needs_fixing(mp_knot source){
mp_knot sourcehead= source;
do{
source= source->next;
}while(source&&source!=sourcehead);
if(!source){
return 1;
}
return 0;
}

int mp_solve_path(MP mp,mp_knot first)
{
int saved_arith_error= mp->arith_error;
jmp_buf*saved_jump_buf= mp->jump_buf;
int retval= 1;
if(first==NULL)return 0;
if(path_needs_fixing(first))return 0;
mp->jump_buf= malloc(sizeof(jmp_buf));
if(mp->jump_buf==NULL||setjmp(*(mp->jump_buf))!=0){
return 0;
}
mp->arith_error= 0;
mp_make_choices(mp,first);
if(mp->arith_error)
retval= 0;
mp->arith_error= saved_arith_error;
free(mp->jump_buf);
mp->jump_buf= saved_jump_buf;
return retval;
}

void mp_free_path(MP mp,mp_knot p){
mp_toss_knot_list(mp,p);
}

/*:383*//*385:*/
#line 9203 "../../../source/texk/web2c/mplibdir/mp.w"

mp_number mp_knot_x_coord(MP mp,mp_knot p){return p->x_coord;}
mp_number mp_knot_y_coord(MP mp,mp_knot p){return p->y_coord;}
mp_number mp_knot_left_x(MP mp,mp_knot p){return p->left_x;}
mp_number mp_knot_left_y(MP mp,mp_knot p){return p->left_y;}
mp_number mp_knot_right_x(MP mp,mp_knot p){return p->right_x;}
mp_number mp_knot_right_y(MP mp,mp_knot p){return p->right_y;}
int mp_knot_right_type(MP mp,mp_knot p){return mp_right_type(p);}
int mp_knot_left_type(MP mp,mp_knot p){return mp_left_type(p);}
mp_knot mp_knot_next(MP mp,mp_knot p){return p->next;}
double mp_number_as_double(MP mp,mp_number n){
return number_to_double(n);
}

/*:385*//*389:*/
#line 9267 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_eval_cubic(MP mp,mp_number*r,mp_knot p,mp_knot q,quarterword c,
mp_number t){
mp_number x1,x2,x3;
new_number(x1);
new_number(x2);
new_number(x3);
if(c==mp_x_code){
set_number_from_of_the_way(x1,t,p->x_coord,p->right_x);
set_number_from_of_the_way(x2,t,p->right_x,q->left_x);
set_number_from_of_the_way(x3,t,q->left_x,q->x_coord);
}else{
set_number_from_of_the_way(x1,t,p->y_coord,p->right_y);
set_number_from_of_the_way(x2,t,p->right_y,q->left_y);
set_number_from_of_the_way(x3,t,q->left_y,q->y_coord);
}
set_number_from_of_the_way(x1,t,x1,x2);
set_number_from_of_the_way(x2,t,x2,x3);
set_number_from_of_the_way(*r,t,x1,x2);
free_number(x1);
free_number(x2);
free_number(x3);
}


/*:389*//*394:*/
#line 9342 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bound_cubic(MP mp,mp_knot p,mp_knot q,quarterword c){
boolean wavy;
mp_number del1,del2,del3,del,dmax;

mp_number t,tt;
mp_number x;
new_number(x);
new_fraction(t);
new_fraction(tt);
if(c==mp_x_code){
number_clone(x,q->x_coord);
}else{
number_clone(x,q->y_coord);
}
new_number(del1);
new_number(del2);
new_number(del3);
new_number(del);
new_number(dmax);
/*395:*/
#line 9398 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_less(x,mp->bbmin[c]))
number_clone(mp->bbmin[c],x);
if(number_greater(x,mp->bbmax[c]))
number_clone(mp->bbmax[c],x)

/*:395*/
#line 9362 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*396:*/
#line 9404 "../../../source/texk/web2c/mplibdir/mp.w"

wavy= true;
if(c==mp_x_code){
if(number_lessequal(mp->bbmin[c],p->right_x))
if(number_lessequal(p->right_x,mp->bbmax[c]))
if(number_lessequal(mp->bbmin[c],q->left_x))
if(number_lessequal(q->left_x,mp->bbmax[c]))
wavy= false;
}else{
if(number_lessequal(mp->bbmin[c],p->right_y))
if(number_lessequal(p->right_y,mp->bbmax[c]))
if(number_lessequal(mp->bbmin[c],q->left_y))
if(number_lessequal(q->left_y,mp->bbmax[c]))
wavy= false;
}


/*:396*/
#line 9364 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(wavy){
if(c==mp_x_code){
set_number_from_substraction(del1,p->right_x,p->x_coord);
set_number_from_substraction(del2,q->left_x,p->right_x);
set_number_from_substraction(del3,q->x_coord,q->left_x);
}else{
set_number_from_substraction(del1,p->right_y,p->y_coord);
set_number_from_substraction(del2,q->left_y,p->right_y);
set_number_from_substraction(del3,q->y_coord,q->left_y);
}
/*397:*/
#line 9424 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_nonzero(del1)){
number_clone(del,del1);
}else if(number_nonzero(del2)){
number_clone(del,del2);
}else{
number_clone(del,del3);
}
if(number_nonzero(del)){
mp_number absval1;
new_number(absval1);
number_clone(dmax,del1);
number_abs(dmax);
number_clone(absval1,del2);
number_abs(absval1);
if(number_greater(absval1,dmax)){
number_clone(dmax,absval1);
}
number_clone(absval1,del3);
number_abs(absval1);
if(number_greater(absval1,dmax)){
number_clone(dmax,absval1);
}
while(number_less(dmax,fraction_half_t)){
number_double(dmax);
number_double(del1);
number_double(del2);
number_double(del3);
}
free_number(absval1);
}

/*:397*/
#line 9376 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(number_negative(del)){
number_negate(del1);
number_negate(del2);
number_negate(del3);
}
crossing_point(t,del1,del2,del3);
if(number_less(t,fraction_one_t)){
/*398:*/
#line 9462 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_eval_cubic(mp,&x,p,q,c,t);
/*395:*/
#line 9398 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_less(x,mp->bbmin[c]))
number_clone(mp->bbmin[c],x);
if(number_greater(x,mp->bbmax[c]))
number_clone(mp->bbmax[c],x)

/*:395*/
#line 9465 "../../../source/texk/web2c/mplibdir/mp.w"
;
set_number_from_of_the_way(del2,t,del2,del3);

if(number_positive(del2))
set_number_to_zero(del2);
{
mp_number arg2,arg3;
new_number(arg2);
new_number(arg3);
number_clone(arg2,del2);
number_negate(arg2);
number_clone(arg3,del3);
number_negate(arg3);
crossing_point(tt,zero_t,arg2,arg3);
free_number(arg2);
free_number(arg3);
}
if(number_less(tt,fraction_one_t)){
/*399:*/
#line 9488 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number arg;
new_number(arg);
set_number_from_of_the_way(arg,t,tt,fraction_one_t);
mp_eval_cubic(mp,&x,p,q,c,arg);
free_number(arg);
/*395:*/
#line 9398 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_less(x,mp->bbmin[c]))
number_clone(mp->bbmin[c],x);
if(number_greater(x,mp->bbmax[c]))
number_clone(mp->bbmax[c],x)

/*:395*/
#line 9495 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:399*/
#line 9483 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}


/*:398*/
#line 9384 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
free_number(del3);
free_number(del2);
free_number(del1);
free_number(del);
free_number(dmax);
free_number(x);
free_number(t);
free_number(tt);
}


/*:394*//*400:*/
#line 9502 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_path_bbox(MP mp,mp_knot h){
mp_knot p,q;
number_clone(mp_minx,h->x_coord);
number_clone(mp_miny,h->y_coord);
number_clone(mp_maxx,mp_minx);
number_clone(mp_maxy,mp_miny);
p= h;
do{
if(mp_right_type(p)==mp_endpoint)
return;
q= mp_next_knot(p);
mp_bound_cubic(mp,p,q,mp_x_code);
mp_bound_cubic(mp,p,q,mp_y_code);
p= q;
}while(p!=h);
}


/*:400*//*403:*/
#line 9589 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_arc_test(MP mp,mp_number*ret,mp_number dx0,mp_number dy0,mp_number dx1,
mp_number dy1,mp_number dx2,mp_number dy2,mp_number v0,
mp_number v02,mp_number v2,mp_number a_goal,mp_number tol_orig){
boolean simple;
mp_number dx01,dy01,dx12,dy12,dx02,dy02;
mp_number v002,v022;
mp_number arc;
mp_number arc1;
mp_number simply;
mp_number tol;
new_number(arc);
new_number(arc1);
new_number(dx01);
new_number(dy01);
new_number(dx12);
new_number(dy12);
new_number(dx02);
new_number(dy02);
new_number(v002);
new_number(v022);
new_number(simply);
new_number(tol);
number_clone(tol,tol_orig);
/*407:*/
#line 9746 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_from_addition(dx01,dx0,dx1);
number_half(dx01);
set_number_from_addition(dx12,dx1,dx2);
number_half(dx12);
set_number_from_addition(dx02,dx01,dx12);
number_half(dx02);
set_number_from_addition(dy01,dy0,dy1);
number_half(dy01);
set_number_from_addition(dy12,dy1,dy2);
number_half(dy12);
set_number_from_addition(dy02,dy01,dy12);
number_half(dy02);

/*:407*/
#line 9614 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*408:*/
#line 9763 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number tmp,arg1,arg2;
new_number(tmp);
new_number(arg1);
new_number(arg2);
set_number_from_addition(arg1,dx0,dx02);
number_half(arg1);
number_add(arg1,dx01);
set_number_from_addition(arg2,dy0,dy02);
number_half(arg2);
number_add(arg2,dy01);
pyth_add(v002,arg1,arg2);

set_number_from_addition(arg1,dx02,dx2);
number_half(arg1);
number_add(arg1,dx12);
set_number_from_addition(arg2,dy02,dy2);
number_half(arg2);
number_add(arg2,dy12);
pyth_add(v022,arg1,arg2);
free_number(arg1);
free_number(arg2);

number_clone(tmp,v02);
number_add_scaled(tmp,2);
number_halfp(tmp);

set_number_from_addition(arc1,v0,tmp);
number_halfp(arc1);
number_substract(arc1,v002);
number_half(arc1);
set_number_from_addition(arc1,v002,arc1);

set_number_from_addition(arc,v2,tmp);
number_halfp(arc);
number_substract(arc,v022);
number_half(arc);
set_number_from_addition(arc,v022,arc);


set_number_to_inf(tmp);
number_substract(tmp,arc1);
if(number_less(arc,tmp)){
free_number(tmp);
number_add(arc,arc1);
}else{
free_number(tmp);
mp->arith_error= true;
if(number_infinite(a_goal)){
set_number_to_inf(*ret);
}else{
set_number_to_unity(*ret);
number_double(*ret);
number_negate(*ret);
}
goto DONE;
}
}


/*:408*/
#line 9616 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*409:*/
#line 9824 "../../../source/texk/web2c/mplibdir/mp.w"

simple= ((number_nonnegative(dx0)&&number_nonnegative(dx1)&&number_nonnegative(dx2))||
(number_nonpositive(dx0)&&number_nonpositive(dx1)&&number_nonpositive(dx2)));
if(simple){
simple= (number_nonnegative(dy0)&&number_nonnegative(dy1)&&number_nonnegative(dy2))||
(number_nonpositive(dy0)&&number_nonpositive(dy1)&&number_nonpositive(dy2));
}
if(!simple){
simple= (number_greaterequal(dx0,dy0)&&number_greaterequal(dx1,dy1)&&number_greaterequal(dx2,dy2))||
(number_lessequal(dx0,dy0)&&number_lessequal(dx1,dy1)&&number_lessequal(dx2,dy2));
if(simple){
mp_number neg_dx0,neg_dx1,neg_dx2;
new_number(neg_dx0);
new_number(neg_dx1);
new_number(neg_dx2);
number_clone(neg_dx0,dx0);
number_clone(neg_dx1,dx1);
number_clone(neg_dx2,dx2);
number_negate(neg_dx0);
number_negate(neg_dx1);
number_negate(neg_dx2);
simple=
(number_greaterequal(neg_dx0,dy0)&&number_greaterequal(neg_dx1,dy1)&&number_greaterequal(neg_dx2,dy2))||
(number_lessequal(neg_dx0,dy0)&&number_lessequal(neg_dx1,dy1)&&number_lessequal(neg_dx2,dy2));
free_number(neg_dx0);
free_number(neg_dx1);
free_number(neg_dx2);
}
}

/*:409*/
#line 9618 "../../../source/texk/web2c/mplibdir/mp.w"
;

set_number_from_addition(simply,v0,v2);
number_halfp(simply);
number_negate(simply);
number_add(simply,arc);
number_substract(simply,v02);
number_abs(simply);

if(simple&&number_lessequal(simply,tol)){
if(number_less(arc,a_goal)){
number_clone(*ret,arc);
}else{
/*410:*/
#line 9892 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number tmp;
mp_number tmp2;
mp_number tmp3;
mp_number tmp4;
mp_number tmp5;
new_number(tmp);
new_number(tmp2);
new_number(tmp3);
new_number(tmp4);
new_number(tmp5);
number_clone(tmp,v02);
number_add_scaled(tmp,2);
number_half(tmp);
number_half(tmp);
if(number_lessequal(a_goal,arc1)){
number_clone(tmp2,v0);
number_halfp(tmp2);
set_number_from_substraction(tmp3,arc1,tmp2);
number_substract(tmp3,tmp);
mp_solve_rising_cubic(mp,&tmp5,tmp2,tmp3,tmp,a_goal);
number_halfp(tmp5);
set_number_to_unity(tmp3);
number_substract(tmp5,tmp3);
number_substract(tmp5,tmp3);
number_clone(*ret,tmp5);
}else{
number_clone(tmp2,v2);
number_halfp(tmp2);
set_number_from_substraction(tmp3,arc,arc1);
number_substract(tmp3,tmp);
number_substract(tmp3,tmp2);
set_number_from_substraction(tmp4,a_goal,arc1);
mp_solve_rising_cubic(mp,&tmp5,tmp,tmp3,tmp2,tmp4);
number_halfp(tmp5);
set_number_to_unity(tmp2);
set_number_to_unity(tmp3);
number_half(tmp2);
number_substract(tmp2,tmp3);
number_substract(tmp2,tmp3);
set_number_from_addition(*ret,tmp2,tmp5);
}
free_number(tmp);
free_number(tmp2);
free_number(tmp3);
free_number(tmp4);
free_number(tmp5);
goto DONE;
}


/*:410*/
#line 9632 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}else{
/*404:*/
#line 9658 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number a_new,a_aux;
mp_number a,b;
mp_number half_v02;
new_number(a_new);
new_number(a_aux);
new_number(half_v02);
/*405:*/
#line 9719 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_to_inf(a_aux);
number_substract(a_aux,a_goal);
if(number_greater(a_goal,a_aux)){
set_number_from_substraction(a_aux,a_goal,a_aux);
set_number_to_inf(a_new);
}else{
set_number_from_addition(a_new,a_goal,a_goal);
set_number_to_zero(a_aux);
}


/*:405*/
#line 9667 "../../../source/texk/web2c/mplibdir/mp.w"
;
{
mp_number halfp_tol;
new_number(halfp_tol);
number_clone(halfp_tol,tol);
number_halfp(halfp_tol);
number_add(tol,halfp_tol);
free_number(halfp_tol);
}
number_clone(half_v02,v02);
number_halfp(half_v02);
new_number(a);
mp_arc_test(mp,&a,dx0,dy0,dx01,dy01,dx02,dy02,
v0,v002,half_v02,a_new,tol);
if(number_negative(a)){
set_number_to_unity(*ret);
number_double(*ret);
number_substract(*ret,a);
number_halfp(*ret);
number_negate(*ret);
}else{
/*406:*/
#line 9735 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_greater(a,a_aux)){
number_substract(a_aux,a);
number_add(a_new,a_aux);
}

/*:406*/
#line 9688 "../../../source/texk/web2c/mplibdir/mp.w"
;
new_number(b);
mp_arc_test(mp,&b,dx02,dy02,dx12,dy12,dx2,dy2,
half_v02,v022,v2,a_new,tol);
if(number_negative(b)){
mp_number tmp;
new_number(tmp);
number_clone(tmp,b);
number_negate(tmp);
number_halfp(tmp);
number_negate(tmp);
number_clone(*ret,tmp);
set_number_to_unity(tmp);
number_halfp(tmp);
number_substract(*ret,tmp);
free_number(tmp);
}else{
set_number_from_substraction(*ret,b,a);
number_half(*ret);
set_number_from_addition(*ret,a,*ret);
}
free_number(b);
}
free_number(half_v02);
free_number(a_aux);
free_number(a_new);
free_number(a);
goto DONE;
}


/*:404*/
#line 9635 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
DONE:
free_number(arc);
free_number(arc1);
free_number(dx01);
free_number(dy01);
free_number(dx12);
free_number(dy12);
free_number(dx02);
free_number(dy02);
free_number(v002);
free_number(v022);
free_number(simply);
free_number(tol);
}


/*:403*//*412:*/
#line 9955 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_solve_rising_cubic(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number x_orig){
mp_number abc;
mp_number a,b,c,x;
mp_number ab,bc,ac;
mp_number t;
mp_number xx;
mp_number neg_x;
if(number_negative(a_orig)||number_negative(c_orig))
mp_confusion(mp,"rising?");
;
new_number(t);
new_number(abc);
new_number(a);
new_number(b);
new_number(c);
new_number(x);
number_clone(a,a_orig);
number_clone(b,b_orig);
number_clone(c,c_orig);
number_clone(x,x_orig);
new_number(ab);
new_number(bc);
new_number(ac);
new_number(xx);
new_number(neg_x);
set_number_from_addition(abc,a,b);
number_add(abc,c);
if(number_nonpositive(x)){
set_number_to_zero(*ret);
}else if(number_greaterequal(x,abc)){
set_number_to_unity(*ret);
}else{
number_clone(t,epsilon_t);
/*414:*/
#line 10039 "../../../source/texk/web2c/mplibdir/mp.w"

while(number_greater(a,one_third_inf_t)||
number_greater(b,one_third_inf_t)||
number_greater(c,one_third_inf_t)){
number_halfp(a);
number_half(b);
number_halfp(c);
number_halfp(x);
}


/*:414*/
#line 9990 "../../../source/texk/web2c/mplibdir/mp.w"
;
do{
number_add(t,t);
/*413:*/
#line 10027 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_from_addition(ab,a,b);
number_half(ab);
set_number_from_addition(bc,b,c);
number_half(bc);
set_number_from_addition(ac,ab,bc);
number_half(ac);

/*:413*/
#line 9993 "../../../source/texk/web2c/mplibdir/mp.w"
;
number_clone(xx,x);
number_substract(xx,a);
number_substract(xx,ab);
number_substract(xx,ac);
number_clone(neg_x,x);
number_negate(neg_x);
if(number_less(xx,neg_x)){
number_double(x);
number_clone(b,ab);
number_clone(c,ac);
}else{
number_add(x,xx);
number_clone(a,ac);
number_clone(b,bc);
number_add(t,epsilon_t);
}
}while(number_less(t,unity_t));
set_number_from_substraction(*ret,t,unity_t);
}
free_number(abc);
free_number(t);
free_number(a);
free_number(b);
free_number(c);
free_number(ab);
free_number(bc);
free_number(ac);
free_number(xx);
free_number(x);
free_number(neg_x);
}


/*:412*//*415:*/
#line 10054 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_arc_test(MP mp,mp_number*ret,mp_number dx0,mp_number dy0,mp_number dx1,
mp_number dy1,mp_number dx2,mp_number dy2,mp_number a_goal){
mp_number v0,v1,v2;
mp_number v02;
new_number(v0);
new_number(v1);
new_number(v2);
pyth_add(v0,dx0,dy0);
pyth_add(v1,dx1,dy1);
pyth_add(v2,dx2,dy2);
if((number_greaterequal(v0,fraction_four_t))||
(number_greaterequal(v1,fraction_four_t))||
(number_greaterequal(v2,fraction_four_t))){
mp->arith_error= true;
if(number_infinite(a_goal)){
set_number_to_inf(*ret);
}else{
set_number_to_unity(*ret);
number_double(*ret);
number_negate(*ret);
}
}else{
mp_number arg1,arg2;
new_number(v02);
new_number(arg1);
new_number(arg2);
set_number_from_addition(arg1,dx0,dx2);
number_half(arg1);
number_add(arg1,dx1);
set_number_from_addition(arg2,dy0,dy2);
number_half(arg2);
number_add(arg2,dy1);
pyth_add(v02,arg1,arg2);
free_number(arg1);
free_number(arg2);
mp_arc_test(mp,ret,dx0,dy0,dx1,dy1,dx2,dy2,v0,v02,v2,a_goal,arc_tol_k);
free_number(v02);
}
free_number(v0);
free_number(v1);
free_number(v2);
}


/*:415*//*416:*/
#line 10101 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_get_arc_length(MP mp,mp_number*ret,mp_knot h){
mp_knot p,q;
mp_number a;
mp_number a_tot;
mp_number arg1,arg2,arg3,arg4,arg5,arg6;
mp_number arcgoal;
p= h;
new_number(a_tot);
new_number(arg1);
new_number(arg2);
new_number(arg3);
new_number(arg4);
new_number(arg5);
new_number(arg6);
new_number(a);
new_number(arcgoal);
set_number_to_inf(arcgoal);
while(mp_right_type(p)!=mp_endpoint){
q= mp_next_knot(p);
set_number_from_substraction(arg1,p->right_x,p->x_coord);
set_number_from_substraction(arg2,p->right_y,p->y_coord);
set_number_from_substraction(arg3,q->left_x,p->right_x);
set_number_from_substraction(arg4,q->left_y,p->right_y);
set_number_from_substraction(arg5,q->x_coord,q->left_x);
set_number_from_substraction(arg6,q->y_coord,q->left_y);
mp_do_arc_test(mp,&a,arg1,arg2,arg3,arg4,arg5,arg6,arcgoal);
slow_add(a_tot,a,a_tot);
if(q==h)
break;
else
p= q;
}
free_number(arcgoal);
free_number(a);
free_number(arg1);
free_number(arg2);
free_number(arg3);
free_number(arg4);
free_number(arg5);
free_number(arg6);
check_arith();
number_clone(*ret,a_tot);
free_number(a_tot);
}


/*:416*//*417:*/
#line 10159 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_get_arc_time(MP mp,mp_number*ret,mp_knot h,mp_number arc0_orig){
mp_knot p,q;
mp_number t_tot;
mp_number t;
mp_number arc,arc0;
mp_number arg1,arg2,arg3,arg4,arg5,arg6;
if(number_negative(arc0_orig)){
/*419:*/
#line 10229 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_left_type(h)==mp_endpoint){
set_number_to_zero(*ret);
}else{
mp_number neg_arc0;
p= mp_htap_ypoc(mp,h);
new_number(neg_arc0);
number_clone(neg_arc0,arc0_orig);
number_negate(neg_arc0);
mp_get_arc_time(mp,ret,p,neg_arc0);
number_negate(*ret);
mp_toss_knot_list(mp,p);
free_number(neg_arc0);
}
check_arith();
return;
}


/*:419*/
#line 10167 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
new_number(t_tot);
new_number(arc0);
number_clone(arc0,arc0_orig);
if(number_infinite(arc0)){
number_add_scaled(arc0,-1);
}
new_number(arc);
number_clone(arc,arc0);
p= h;
new_number(arg1);
new_number(arg2);
new_number(arg3);
new_number(arg4);
new_number(arg5);
new_number(arg6);
new_number(t);
while((mp_right_type(p)!=mp_endpoint)&&number_positive(arc)){
q= mp_next_knot(p);
set_number_from_substraction(arg1,p->right_x,p->x_coord);
set_number_from_substraction(arg2,p->right_y,p->y_coord);
set_number_from_substraction(arg3,q->left_x,p->right_x);
set_number_from_substraction(arg4,q->left_y,p->right_y);
set_number_from_substraction(arg5,q->x_coord,q->left_x);
set_number_from_substraction(arg6,q->y_coord,q->left_y);
mp_do_arc_test(mp,&t,arg1,arg2,arg3,arg4,arg5,arg6,arc);
/*418:*/
#line 10218 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_negative(t)){
number_add(t_tot,t);
number_add(t_tot,two_t);
set_number_to_zero(arc);
}else{
number_add(t_tot,unity_t);
number_substract(arc,t);
}


/*:418*/
#line 10194 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(q==h){
/*420:*/
#line 10249 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_positive(arc)){
mp_number n,n1,d1,v1;
new_number(n);
new_number(n1);
new_number(d1);
new_number(v1);

set_number_from_substraction(d1,arc0,arc);
set_number_from_div(n1,arc,d1);
number_clone(n,n1);
set_number_from_mul(n1,n1,d1);
number_substract(arc,n1);

number_clone(d1,inf_t);
number_clone(v1,n);
number_add(v1,epsilon_t);
set_number_from_div(d1,d1,v1);
if(number_greater(t_tot,d1)){
mp->arith_error= true;
check_arith();
set_number_to_inf(*ret);
free_number(n);
free_number(n1);
free_number(d1);
free_number(v1);
goto RETURN;
}
set_number_from_mul(t_tot,t_tot,v1);
free_number(n);
free_number(n1);
free_number(d1);
free_number(v1);
}

/*:420*/
#line 10198 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
p= q;
}
check_arith();
number_clone(*ret,t_tot);
RETURN:
free_number(t_tot);
free_number(t);
free_number(arc);
free_number(arc0);
free_number(arg1);
free_number(arg2);
free_number(arg3);
free_number(arg4);
free_number(arg5);
free_number(arg6);
}


/*:417*//*422:*/
#line 10315 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_make_pen(MP mp,mp_knot h,boolean need_hull){
mp_knot p,q;
q= h;
do{
p= q;
q= mp_next_knot(q);
mp_prev_knot(q)= p;
}while(q!=h);
if(need_hull){
h= mp_convex_hull(mp,h);
/*424:*/
#line 10363 "../../../source/texk/web2c/mplibdir/mp.w"

if(pen_is_elliptical(h)){
number_clone(h->left_x,h->x_coord);
number_clone(h->left_y,h->y_coord);
number_clone(h->right_x,h->x_coord);
number_clone(h->right_y,h->y_coord);
}

/*:424*/
#line 10326 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
return h;
}


/*:422*//*423:*/
#line 10341 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_get_pen_circle(MP mp,mp_number diam){
mp_knot h;
h= mp_new_knot(mp);
mp_next_knot(h)= h;
mp_prev_knot(h)= h;
mp_originator(h)= mp_program_code;
set_number_to_zero(h->x_coord);
set_number_to_zero(h->y_coord);
number_clone(h->left_x,diam);
set_number_to_zero(h->left_y);
set_number_to_zero(h->right_x);
number_clone(h->right_y,diam);
return h;
}


/*:423*//*426:*/
#line 10376 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_pr_pen(MP mp,mp_knot h){
mp_knot p,q;
if(pen_is_elliptical(h)){
/*428:*/
#line 10403 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number v1;
new_number(v1);
mp_print(mp,"pencircle transformed (");
print_number(h->x_coord);
mp_print_char(mp,xord(','));
print_number(h->y_coord);
mp_print_char(mp,xord(','));
set_number_from_substraction(v1,h->left_x,h->x_coord);
print_number(v1);
mp_print_char(mp,xord(','));
set_number_from_substraction(v1,h->right_x,h->x_coord);
print_number(v1);
mp_print_char(mp,xord(','));
set_number_from_substraction(v1,h->left_y,h->y_coord);
print_number(v1);
mp_print_char(mp,xord(','));
set_number_from_substraction(v1,h->right_y,h->y_coord);
print_number(v1);
mp_print_char(mp,xord(')'));
free_number(v1);
}


/*:428*/
#line 10380 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
p= h;
do{
mp_print_two(mp,p->x_coord,p->y_coord);
mp_print_nl(mp," .. ");
/*427:*/
#line 10394 "../../../source/texk/web2c/mplibdir/mp.w"

q= mp_next_knot(p);
if((q==NULL)||(mp_prev_knot(q)!=p)){
mp_print_nl(mp,"???");
return;

}
p= q

/*:427*/
#line 10387 "../../../source/texk/web2c/mplibdir/mp.w"
;
}while(p!=h);
mp_print(mp,"cycle");
}
}


/*:426*//*430:*/
#line 10434 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_pen(MP mp,mp_knot h,const char*s,boolean nuline){
mp_print_diagnostic(mp,"Pen",s,nuline);
mp_print_ln(mp);
;
mp_pr_pen(mp,h);
mp_end_diagnostic(mp,true);
}


/*:430*//*431:*/
#line 10448 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_make_path(MP mp,mp_knot h){
mp_knot p;
quarterword k;
/*435:*/
#line 10522 "../../../source/texk/web2c/mplibdir/mp.w"

integer kk;


/*:435*/
#line 10452 "../../../source/texk/web2c/mplibdir/mp.w"
;
FUNCTION_TRACE1("make_path()\n");
if(pen_is_elliptical(h)){
FUNCTION_TRACE1("make_path(elliptical)\n");
/*433:*/
#line 10478 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number center_x,center_y;
mp_number width_x,width_y;
mp_number height_x,height_y;
mp_number dx,dy;
new_number(center_x);
new_number(center_y);
new_number(width_x);
new_number(width_y);
new_number(height_x);
new_number(height_y);
new_number(dx);
new_number(dy);
/*434:*/
#line 10514 "../../../source/texk/web2c/mplibdir/mp.w"

number_clone(center_x,h->x_coord);
number_clone(center_y,h->y_coord);
set_number_from_substraction(width_x,h->left_x,center_x);
set_number_from_substraction(width_y,h->left_y,center_y);
set_number_from_substraction(height_x,h->right_x,center_x);
set_number_from_substraction(height_y,h->right_y,center_y);

/*:434*/
#line 10492 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= h;
for(k= 0;k<=7;k++){
/*436:*/
#line 10530 "../../../source/texk/web2c/mplibdir/mp.w"

kk= (k+6)%8;
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,mp->half_cos[k],width_x);
take_fraction(r2,mp->half_cos[kk],height_x);
number_add(r1,r2);
set_number_from_addition(p->x_coord,center_x,r1);
take_fraction(r1,mp->half_cos[k],width_y);
take_fraction(r2,mp->half_cos[kk],height_y);
number_add(r1,r2);
set_number_from_addition(p->y_coord,center_y,r1);
take_fraction(r1,mp->d_cos[kk],width_x);
take_fraction(r2,mp->d_cos[k],height_x);
number_clone(dx,r1);
number_negate(dx);
number_add(dx,r2);
take_fraction(r1,mp->d_cos[kk],width_y);
take_fraction(r2,mp->d_cos[k],height_y);
number_clone(dy,r1);
number_negate(dy);
number_add(dy,r2);
set_number_from_addition(p->right_x,p->x_coord,dx);
set_number_from_addition(p->right_y,p->y_coord,dy);
set_number_from_substraction(p->left_x,p->x_coord,dx);
set_number_from_substraction(p->left_y,p->y_coord,dy);
free_number(r1);
free_number(r2);
}
mp_left_type(p)= mp_explicit;
mp_right_type(p)= mp_explicit;
mp_originator(p)= mp_program_code

/*:436*/
#line 10496 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(k==7)
mp_next_knot(p)= h;
else
mp_next_knot(p)= mp_new_knot(mp);
p= mp_next_knot(p);
}
free_number(dx);
free_number(dy);
free_number(center_x);
free_number(center_y);
free_number(width_x);
free_number(width_y);
free_number(height_x);
free_number(height_y);
}


/*:433*/
#line 10456 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
p= h;
do{
mp_left_type(p)= mp_explicit;
mp_right_type(p)= mp_explicit;
/*432:*/
#line 10469 "../../../source/texk/web2c/mplibdir/mp.w"

number_clone(p->left_x,p->x_coord);
number_clone(p->left_y,p->y_coord);
number_clone(p->right_x,p->x_coord);
number_clone(p->right_y,p->y_coord)


/*:432*/
#line 10462 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= mp_next_knot(p);
}while(p!=h);
}
}


/*:431*//*441:*/
#line 10614 "../../../source/texk/web2c/mplibdir/mp.w"

mp_knot mp_convex_hull(MP mp,mp_knot h){
mp_knot l,r;
mp_knot p,q;
mp_knot s;
mp_number dx,dy;
mp_knot ret;
new_number(dx);
new_number(dy);
if(pen_is_elliptical(h)){
ret= h;
}else{
/*442:*/
#line 10650 "../../../source/texk/web2c/mplibdir/mp.w"

l= h;
p= mp_next_knot(h);
while(p!=h){
if(number_lessequal(p->x_coord,l->x_coord))
if((number_less(p->x_coord,l->x_coord))||
(number_less(p->y_coord,l->y_coord)))
l= p;
p= mp_next_knot(p);
}


/*:442*/
#line 10626 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*443:*/
#line 10662 "../../../source/texk/web2c/mplibdir/mp.w"

r= h;
p= mp_next_knot(h);
while(p!=h){
if(number_greaterequal(p->x_coord,r->x_coord))
if(number_greater(p->x_coord,r->x_coord)||
number_greater(p->y_coord,r->y_coord))
r= p;
p= mp_next_knot(p);
}


/*:443*/
#line 10627 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(l!=r){
s= mp_next_knot(r);
/*444:*/
#line 10674 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ab_vs_cd;
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
new_number(ab_vs_cd);
set_number_from_substraction(dx,r->x_coord,l->x_coord);
set_number_from_substraction(dy,r->y_coord,l->y_coord);
p= mp_next_knot(l);
while(p!=r){
q= mp_next_knot(p);
set_number_from_substraction(arg1,p->y_coord,l->y_coord);
set_number_from_substraction(arg2,p->x_coord,l->x_coord);
ab_vs_cd(ab_vs_cd,dx,arg1,dy,arg2);
if(number_positive(ab_vs_cd))
mp_move_knot(mp,p,r);
p= q;
}
free_number(ab_vs_cd);
free_number(arg1);
free_number(arg2);
}


/*:444*/
#line 10631 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*448:*/
#line 10717 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ab_vs_cd;
mp_number arg1,arg2;
new_number(ab_vs_cd);
new_number(arg1);
new_number(arg2);
p= s;
while(p!=l){
q= mp_next_knot(p);
set_number_from_substraction(arg1,p->y_coord,l->y_coord);
set_number_from_substraction(arg2,p->x_coord,l->x_coord);
ab_vs_cd(ab_vs_cd,dx,arg1,dy,arg2);
if(number_negative(ab_vs_cd))
mp_move_knot(mp,p,l);
p= q;
}
free_number(ab_vs_cd);
free_number(arg1);
free_number(arg2);
}


/*:448*/
#line 10633 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*449:*/
#line 10744 "../../../source/texk/web2c/mplibdir/mp.w"

p= mp_next_knot(l);
while(p!=r){
q= mp_prev_knot(p);
while(number_greater(q->x_coord,p->x_coord))
q= mp_prev_knot(q);
while(number_equal(q->x_coord,p->x_coord)){
if(number_greater(q->y_coord,p->y_coord))
q= mp_prev_knot(q);
else
break;
}
if(q==mp_prev_knot(p)){
p= mp_next_knot(p);
}else{
p= mp_next_knot(p);
mp_move_knot(mp,mp_prev_knot(p),q);
}
}


/*:449*/
#line 10634 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*450:*/
#line 10765 "../../../source/texk/web2c/mplibdir/mp.w"

p= mp_next_knot(r);
while(p!=l){
q= mp_prev_knot(p);
while(number_less(q->x_coord,p->x_coord))
q= mp_prev_knot(q);
while(number_equal(q->x_coord,p->x_coord)){
if(number_less(q->y_coord,p->y_coord))
q= mp_prev_knot(q);
else
break;
}
if(q==mp_prev_knot(p)){
p= mp_next_knot(p);
}else{
p= mp_next_knot(p);
mp_move_knot(mp,mp_prev_knot(p),q);
}
}


/*:450*/
#line 10635 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
if(l!=mp_next_knot(l)){
/*451:*/
#line 10790 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ab_vs_cd;
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
new_number(ab_vs_cd);
p= l;
q= mp_next_knot(l);
while(1){
set_number_from_substraction(dx,q->x_coord,p->x_coord);
set_number_from_substraction(dy,q->y_coord,p->y_coord);
p= q;
q= mp_next_knot(q);
if(p==l)
break;
if(p!=r){
set_number_from_substraction(arg1,q->y_coord,p->y_coord);
set_number_from_substraction(arg2,q->x_coord,p->x_coord);
ab_vs_cd(ab_vs_cd,dx,arg1,dy,arg2);
if(number_nonpositive(ab_vs_cd)){
/*452:*/
#line 10821 "../../../source/texk/web2c/mplibdir/mp.w"

{
s= mp_prev_knot(p);
mp_xfree(p);
mp_next_knot(s)= q;
mp_prev_knot(q)= s;
if(s==l){
p= s;
}else{
p= mp_prev_knot(s);
q= s;
}
}


/*:452*/
#line 10811 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
}
free_number(ab_vs_cd);
free_number(arg1);
free_number(arg2);
}


/*:451*/
#line 10638 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
ret= l;
}
free_number(dx);
free_number(dy);
return ret;
}


/*:441*//*447:*/
#line 10705 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_move_knot(MP mp,mp_knot p,mp_knot q){
(void)mp;
mp_next_knot(mp_prev_knot(p))= mp_next_knot(p);
mp_prev_knot(mp_next_knot(p))= mp_prev_knot(p);
mp_prev_knot(p)= q;
mp_next_knot(p)= mp_next_knot(q);
mp_next_knot(q)= p;
mp_prev_knot(mp_next_knot(p))= p;
}


/*:447*//*453:*/
#line 10840 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_find_offset(MP mp,mp_number x_orig,mp_number y_orig,mp_knot h){
mp_knot p,q;
if(pen_is_elliptical(h)){
mp_fraction xx,yy;
mp_number wx,wy,hx,hy;
mp_fraction d;
new_fraction(xx);
new_fraction(yy);
new_number(wx);
new_number(wy);
new_number(hx);
new_number(hy);
new_fraction(d);
/*457:*/
#line 10904 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_zero(x_orig)&&number_zero(y_orig)){
number_clone(mp->cur_x,h->x_coord);
number_clone(mp->cur_y,h->y_coord);
}else{
mp_number x,y,abs_x,abs_y;
new_number(x);
new_number(y);
new_number(abs_x);
new_number(abs_y);
number_clone(x,x_orig);
number_clone(y,y_orig);
/*458:*/
#line 10953 "../../../source/texk/web2c/mplibdir/mp.w"

{
set_number_from_substraction(wx,h->left_x,h->x_coord);
set_number_from_substraction(wy,h->left_y,h->y_coord);
set_number_from_substraction(hx,h->right_x,h->x_coord);
set_number_from_substraction(hy,h->right_y,h->y_coord);
}


/*:458*/
#line 10916 "../../../source/texk/web2c/mplibdir/mp.w"
;
number_clone(abs_x,x);
number_clone(abs_y,y);
number_abs(abs_x);
number_abs(abs_y);
while(number_less(abs_x,fraction_half_t)&&number_less(abs_y,fraction_half_t)){
number_double(x);
number_double(y);
number_clone(abs_x,x);
number_clone(abs_y,y);
number_abs(abs_x);
number_abs(abs_y);
}
/*459:*/
#line 10962 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1,r2,arg1;
new_number(arg1);
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,x,hy);
number_clone(arg1,hx);
number_negate(arg1);
take_fraction(r2,y,arg1);
number_add(r1,r2);
number_negate(r1);
number_clone(yy,r1);
number_clone(arg1,wy);
number_negate(arg1);
take_fraction(r1,x,arg1);
take_fraction(r2,y,wx);
number_add(r1,r2);
number_clone(xx,r1);
free_number(arg1);
free_number(r1);
free_number(r2);
}
pyth_add(d,xx,yy);
if(number_positive(d)){
mp_number ret;
new_fraction(ret);
make_fraction(ret,xx,d);
number_half(ret);
number_clone(xx,ret);
make_fraction(ret,yy,d);
number_half(ret);
number_clone(yy,ret);
free_number(ret);
}

/*:459*/
#line 10930 "../../../source/texk/web2c/mplibdir/mp.w"
;
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,xx,wx);
take_fraction(r2,yy,hx);
number_add(r1,r2);
set_number_from_addition(mp->cur_x,h->x_coord,r1);
take_fraction(r1,xx,wy);
take_fraction(r2,yy,hy);
number_add(r1,r2);
set_number_from_addition(mp->cur_y,h->y_coord,r1);
free_number(r1);
free_number(r2);
}
free_number(abs_x);
free_number(abs_y);
free_number(x);
free_number(y);
}


/*:457*/
#line 10854 "../../../source/texk/web2c/mplibdir/mp.w"

free_number(xx);
free_number(yy);
free_number(wx);
free_number(wy);
free_number(hx);
free_number(hy);
free_number(d);
}else{
mp_number ab_vs_cd;
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
new_number(ab_vs_cd);
q= h;
do{
p= q;
q= mp_next_knot(q);
set_number_from_substraction(arg1,q->x_coord,p->x_coord);
set_number_from_substraction(arg2,q->y_coord,p->y_coord);
ab_vs_cd(ab_vs_cd,arg1,y_orig,arg2,x_orig);
}while(number_negative(ab_vs_cd));
do{
p= q;
q= mp_next_knot(q);
set_number_from_substraction(arg1,q->x_coord,p->x_coord);
set_number_from_substraction(arg2,q->y_coord,p->y_coord);
ab_vs_cd(ab_vs_cd,arg1,y_orig,arg2,x_orig);
}while(number_positive(ab_vs_cd));
number_clone(mp->cur_x,p->x_coord);
number_clone(mp->cur_y,p->y_coord);
free_number(ab_vs_cd);
free_number(arg1);
free_number(arg2);
}
}


/*:453*//*460:*/
#line 11002 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pen_bbox(MP mp,mp_knot h){
mp_knot p;
if(pen_is_elliptical(h)){
/*461:*/
#line 11028 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number arg1,arg2;
new_number(arg1);
new_fraction(arg2);
number_clone(arg2,fraction_one_t);
mp_find_offset(mp,arg1,arg2,h);
number_clone(mp_maxx,mp->cur_x);
number_clone(mp_minx,h->x_coord);
number_double(mp_minx);
number_substract(mp_minx,mp->cur_x);
number_negate(arg2);
mp_find_offset(mp,arg2,arg1,h);
number_clone(mp_maxy,mp->cur_y);
number_clone(mp_miny,h->y_coord);
number_double(mp_miny);
number_substract(mp_miny,mp->cur_y);
free_number(arg1);
free_number(arg2);
}


/*:461*/
#line 11006 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
number_clone(mp_minx,h->x_coord);
number_clone(mp_maxx,mp_minx);
number_clone(mp_miny,h->y_coord);
number_clone(mp_maxy,mp_miny);
p= mp_next_knot(h);
while(p!=h){
if(number_less(p->x_coord,mp_minx))
number_clone(mp_minx,p->x_coord);
if(number_less(p->y_coord,mp_miny))
number_clone(mp_miny,p->y_coord);
if(number_greater(p->x_coord,mp_maxx))
number_clone(mp_maxx,p->x_coord);
if(number_greater(p->y_coord,mp_maxy))
number_clone(mp_maxy,p->y_coord);
p= mp_next_knot(p);
}
}
}


/*:460*//*467:*/
#line 11207 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_fill_node(MP mp,mp_knot p){
mp_fill_node t= malloc_node(fill_node_size);
mp_type(t)= mp_fill_node_type;
mp_path_p(t)= p;
mp_pen_p(t)= NULL;
new_number(t->red);
new_number(t->green);
new_number(t->blue);
new_number(t->black);
new_number(t->miterlim);
clear_color(t);
mp_color_model(t)= mp_uninitialized_model;
mp_pre_script(t)= NULL;
mp_post_script(t)= NULL;

if(number_greater(internal_value(mp_linejoin),unity_t))
t->ljoin= 2;
else if(number_positive(internal_value(mp_linejoin)))
t->ljoin= 1;
else
t->ljoin= 0;
if(number_less(internal_value(mp_miterlimit),unity_t)){
set_number_to_unity(t->miterlim);
}else{
number_clone(t->miterlim,internal_value(mp_miterlimit));
}
return(mp_node)t;
}

/*:467*//*468:*/
#line 11237 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free_fill_node(MP mp,mp_fill_node p){
mp_toss_knot_list(mp,mp_path_p(p));
if(mp_pen_p(p)!=NULL)
mp_toss_knot_list(mp,mp_pen_p(p));
if(mp_pre_script(p)!=NULL)
delete_str_ref(mp_pre_script(p));
if(mp_post_script(p)!=NULL)
delete_str_ref(mp_post_script(p));
free_number(p->red);
free_number(p->green);
free_number(p->blue);
free_number(p->black);
free_number(p->miterlim);
mp_free_node(mp,(mp_node)p,fill_node_size);
}



/*:468*//*471:*/
#line 11292 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_stroked_node(MP mp,mp_knot p){
mp_stroked_node t= malloc_node(stroked_node_size);
mp_type(t)= mp_stroked_node_type;
mp_path_p(t)= p;
mp_pen_p(t)= NULL;
mp_dash_p(t)= NULL;
new_number(t->dash_scale);
set_number_to_unity(t->dash_scale);
new_number(t->red);
new_number(t->green);
new_number(t->blue);
new_number(t->black);
new_number(t->miterlim);
clear_color(t);
mp_pre_script(t)= NULL;
mp_post_script(t)= NULL;

if(number_greater(internal_value(mp_linejoin),unity_t))
t->ljoin= 2;
else if(number_positive(internal_value(mp_linejoin)))
t->ljoin= 1;
else
t->ljoin= 0;
if(number_less(internal_value(mp_miterlimit),unity_t)){
set_number_to_unity(t->miterlim);
}else{
number_clone(t->miterlim,internal_value(mp_miterlimit));
}
if(number_greater(internal_value(mp_linecap),unity_t))
t->lcap= 2;
else if(number_positive(internal_value(mp_linecap)))
t->lcap= 1;
else
t->lcap= 0;
return(mp_node)t;
}

/*:471*//*472:*/
#line 11330 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_free_stroked_node(MP mp,mp_stroked_node p){
mp_edge_header_node e= NULL;
mp_toss_knot_list(mp,mp_path_p(p));
if(mp_pen_p(p)!=NULL)
mp_toss_knot_list(mp,mp_pen_p(p));
if(mp_pre_script(p)!=NULL)
delete_str_ref(mp_pre_script(p));
if(mp_post_script(p)!=NULL)
delete_str_ref(mp_post_script(p));
e= (mp_edge_header_node)mp_dash_p(p);
free_number(p->dash_scale);
free_number(p->red);
free_number(p->green);
free_number(p->blue);
free_number(p->black);
free_number(p->miterlim);
mp_free_node(mp,(mp_node)p,stroked_node_size);
return e;
}

/*:472*//*474:*/
#line 11360 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_sqrt_det(MP mp,mp_number*ret,mp_number a_orig,mp_number b_orig,mp_number c_orig,mp_number d_orig){
mp_number a,b,c,d;
mp_number maxabs;
unsigned s;
new_number(a);
new_number(b);
new_number(c);
new_number(d);
new_number(maxabs);
number_clone(a,a_orig);
number_clone(b,b_orig);
number_clone(c,c_orig);
number_clone(d,d_orig);

{
mp_number tmp;
new_number(tmp);
number_clone(maxabs,a);
number_abs(maxabs);
number_clone(tmp,b);
number_abs(tmp);
if(number_greater(tmp,maxabs))
number_clone(maxabs,tmp);
number_clone(tmp,c);
number_abs(tmp);
if(number_greater(tmp,maxabs))
number_clone(maxabs,tmp);
number_clone(tmp,d);
number_abs(tmp);
if(number_greater(tmp,maxabs))
number_clone(maxabs,tmp);
free_number(tmp);
}


s= 64;
while((number_less(maxabs,fraction_one_t))&&(s> 1)){
number_double(a);
number_double(b);
number_double(c);
number_double(d);
number_double(maxabs);
s= s/2;
}
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,a,d);
take_fraction(r2,b,c);
number_substract(r1,r2);
number_abs(r1);
square_rt(*ret,r1);
number_multiply_int(*ret,s);
free_number(r1);
free_number(r2);
}
free_number(a);
free_number(b);
free_number(c);
free_number(d);
free_number(maxabs);
}

static void mp_get_pen_scale(MP mp,mp_number*ret,mp_knot p){
if(p==NULL){
set_number_to_zero(*ret);
}else{
mp_number a,b,c,d;
new_number(a);
new_number(b);
new_number(c);
new_number(d);
set_number_from_substraction(a,p->left_x,p->x_coord);
set_number_from_substraction(b,p->right_x,p->x_coord);
set_number_from_substraction(c,p->left_y,p->y_coord);
set_number_from_substraction(d,p->right_y,p->y_coord);
mp_sqrt_det(mp,ret,a,b,c,d);
free_number(a);
free_number(b);
free_number(c);
free_number(d);
}
}


/*:474*//*478:*/
#line 11495 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_text_node(MP mp,char*f,mp_string s){
mp_text_node t= malloc_node(text_node_size);
mp_type(t)= mp_text_node_type;
mp_text_p(t)= s;
add_str_ref(s);
mp_font_n(t)= (halfword)mp_find_font(mp,f);
new_number(t->red);
new_number(t->green);
new_number(t->blue);
new_number(t->black);
new_number(t->width);
new_number(t->height);
new_number(t->depth);
clear_color(t);
mp_pre_script(t)= NULL;
mp_post_script(t)= NULL;
new_number(t->tx);
new_number(t->ty);
new_number(t->txx);
new_number(t->txy);
new_number(t->tyx);
new_number(t->tyy);


set_number_to_unity(t->txx);
set_number_to_unity(t->tyy);
mp_set_text_box(mp,t);
return(mp_node)t;
}

/*:478*//*479:*/
#line 11526 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free_text_node(MP mp,mp_text_node p){

if(mp_pre_script(p)!=NULL)
delete_str_ref(mp_pre_script(p));
if(mp_post_script(p)!=NULL)
delete_str_ref(mp_post_script(p));
free_number(p->red);
free_number(p->green);
free_number(p->blue);
free_number(p->black);
free_number(p->width);
free_number(p->height);
free_number(p->depth);
free_number(p->tx);
free_number(p->ty);
free_number(p->txx);
free_number(p->txy);
free_number(p->tyx);
free_number(p->tyy);
mp_free_node(mp,(mp_node)p,text_node_size);
}

/*:479*//*482:*/
#line 11600 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_bounds_node(MP mp,mp_knot p,quarterword c){

if(c==mp_start_clip_node_type){
mp_start_clip_node t;
t= (mp_start_clip_node)malloc_node(start_clip_size);
t->path_p_= p;
mp_type(t)= c;
t->link= NULL;
return(mp_node)t;
}else if(c==mp_start_bounds_node_type){
mp_start_bounds_node t;
t= (mp_start_bounds_node)malloc_node(start_bounds_size);
t->path_p_= p;
mp_type(t)= c;
t->link= NULL;
return(mp_node)t;
}else if(c==mp_stop_clip_node_type){
mp_stop_clip_node t;
t= (mp_stop_clip_node)malloc_node(stop_clip_size);
mp_type(t)= c;
t->link= NULL;
return(mp_node)t;
}else if(c==mp_stop_bounds_node_type){
mp_stop_bounds_node t;
t= (mp_stop_bounds_node)malloc_node(stop_bounds_size);
mp_type(t)= c;
t->link= NULL;
return(mp_node)t;
}else{
assert(0);
}
return NULL;
}


/*:482*//*483:*/
#line 11636 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_free_start_clip_node(MP mp,mp_start_clip_node p){
mp_toss_knot_list(mp,mp_path_p(p));
mp_free_node(mp,(mp_node)p,start_clip_size);
}
static void mp_free_start_bounds_node(MP mp,mp_start_bounds_node p){
mp_toss_knot_list(mp,mp_path_p(p));
mp_free_node(mp,(mp_node)p,start_bounds_size);
}
static void mp_free_stop_clip_node(MP mp,mp_stop_clip_node p){
mp_free_node(mp,(mp_node)p,stop_clip_size);
}
static void mp_free_stop_bounds_node(MP mp,mp_stop_bounds_node p){
mp_free_node(mp,(mp_node)p,stop_bounds_size);
}


/*:483*//*488:*/
#line 11695 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_dash_node mp_get_dash_node(MP mp){
mp_dash_node p= (mp_dash_node)malloc_node(dash_node_size);
p->has_number= 0;
new_number(p->start_x);
new_number(p->stop_x);
new_number(p->dash_y);
mp_type(p)= mp_dash_node_type;
return p;
}


/*:488*//*490:*/
#line 11753 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_init_bbox(MP mp,mp_edge_header_node h){

(void)mp;
bblast(h)= edge_list(h);
h->bbtype= no_bounds;
set_number_to_inf(h->minx);
set_number_to_inf(h->miny);
set_number_to_neg_inf(h->maxx);
set_number_to_neg_inf(h->maxy);
}


/*:490*//*491:*/
#line 11774 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_get_edge_header_node(MP mp){
mp_edge_header_node p= (mp_edge_header_node)malloc_node(edge_header_size);
mp_type(p)= mp_edge_header_node_type;
new_number(p->start_x);
new_number(p->stop_x);
new_number(p->dash_y);
new_number(p->minx);
new_number(p->miny);
new_number(p->maxx);
new_number(p->maxy);
p->list_= mp_get_token_node(mp);
return p;
}
static void mp_init_edges(MP mp,mp_edge_header_node h){

set_dash_list(h,mp->null_dash);
obj_tail(h)= edge_list(h);
mp_link(edge_list(h))= NULL;
edge_ref_count(h)= 0;
mp_init_bbox(mp,h);
}


/*:491*//*493:*/
#line 11815 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_toss_edges(MP mp,mp_edge_header_node h){
mp_node p,q;
mp_edge_header_node r;
mp_flush_dash_list(mp,h);
q= mp_link(edge_list(h));
while((q!=NULL)){
p= q;
q= mp_link(q);
r= mp_toss_gr_object(mp,p);
if(r!=NULL)
delete_edge_ref(r);
}
free_number(h->start_x);
free_number(h->stop_x);
free_number(h->dash_y);
free_number(h->minx);
free_number(h->miny);
free_number(h->maxx);
free_number(h->maxy);
mp_free_token_node(mp,h->list_);
mp_free_node(mp,(mp_node)h,edge_header_size);
}
void mp_flush_dash_list(MP mp,mp_edge_header_node h){
mp_dash_node p,q;
q= dash_list(h);
while(q!=mp->null_dash){
p= q;
q= (mp_dash_node)mp_link(q);
mp_free_node(mp,(mp_node)p,dash_node_size);
}
set_dash_list(h,mp->null_dash);
}
mp_edge_header_node mp_toss_gr_object(MP mp,mp_node p){

mp_edge_header_node e= NULL;
switch(mp_type(p)){
case mp_fill_node_type:
mp_free_fill_node(mp,(mp_fill_node)p);
break;
case mp_stroked_node_type:
e= mp_free_stroked_node(mp,(mp_stroked_node)p);
break;
case mp_text_node_type:
mp_free_text_node(mp,(mp_text_node)p);
break;
case mp_start_clip_node_type:
mp_free_start_clip_node(mp,(mp_start_clip_node)p);
break;
case mp_start_bounds_node_type:
mp_free_start_bounds_node(mp,(mp_start_bounds_node)p);
break;
case mp_stop_clip_node_type:
mp_free_stop_clip_node(mp,(mp_stop_clip_node)p);
break;
case mp_stop_bounds_node_type:
mp_free_stop_bounds_node(mp,(mp_stop_bounds_node)p);
break;
default:
break;
}
return e;
}


/*:493*//*494:*/
#line 11885 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_private_edges(MP mp,mp_edge_header_node h){

mp_edge_header_node hh;
mp_dash_node p,pp;
assert(mp_type(h)==mp_edge_header_node_type);
if(edge_ref_count(h)==0){
return h;
}else{
decr(edge_ref_count(h));
hh= (mp_edge_header_node)mp_copy_objects(mp,mp_link(edge_list(h)),NULL);
/*495:*/
#line 11907 "../../../source/texk/web2c/mplibdir/mp.w"

pp= (mp_dash_node)hh;
p= dash_list(h);
while((p!=mp->null_dash)){
mp_link(pp)= (mp_node)mp_get_dash_node(mp);
pp= (mp_dash_node)mp_link(pp);
number_clone(pp->start_x,p->start_x);
number_clone(pp->stop_x,p->stop_x);
p= (mp_dash_node)mp_link(p);
}
mp_link(pp)= (mp_node)mp->null_dash;
number_clone(hh->dash_y,h->dash_y)


/*:495*/
#line 11896 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*497:*/
#line 11985 "../../../source/texk/web2c/mplibdir/mp.w"

number_clone(hh->minx,h->minx);
number_clone(hh->miny,h->miny);
number_clone(hh->maxx,h->maxx);
number_clone(hh->maxy,h->maxy);
hh->bbtype= h->bbtype;
p= (mp_dash_node)edge_list(h);
pp= (mp_dash_node)edge_list(hh);
while((p!=(mp_dash_node)bblast(h))){
if(p==NULL)
mp_confusion(mp,"bblast");
;
p= (mp_dash_node)mp_link(p);
pp= (mp_dash_node)mp_link(pp);
}
bblast(hh)= (mp_node)pp

/*:497*/
#line 11898 "../../../source/texk/web2c/mplibdir/mp.w"
;
return hh;
}
}


/*:494*//*496:*/
#line 11923 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_dash_object*mp_export_dashes(MP mp,mp_stroked_node q,mp_number w){
mp_dash_object*d;
mp_dash_node p,h;
mp_number scf;
mp_number dashoff;
double*dashes= NULL;
int num_dashes= 1;
h= (mp_dash_node)mp_dash_p(q);
if(h==NULL||dash_list(h)==mp->null_dash)
return NULL;
new_number(scf);
p= dash_list(h);
mp_get_pen_scale(mp,&scf,mp_pen_p(q));
if(number_zero(scf)){
if(number_zero(w)){
number_clone(scf,q->dash_scale);
}else{
free_number(scf);
return NULL;
}
}else{
mp_number ret;
new_number(ret);
make_scaled(ret,w,scf);
take_scaled(scf,ret,q->dash_scale);
free_number(ret);
}
number_clone(w,scf);
d= xmalloc(1,sizeof(mp_dash_object));
add_var_used(sizeof(mp_dash_object));
set_number_from_addition(mp->null_dash->start_x,p->start_x,h->dash_y);
{
mp_number ret,arg1;
new_number(ret);
new_number(arg1);
new_number(dashoff);
while(p!=mp->null_dash){
dashes= xrealloc(dashes,(num_dashes+2),sizeof(double));
set_number_from_substraction(arg1,p->stop_x,p->start_x);
take_scaled(ret,arg1,scf);
dashes[(num_dashes-1)]= number_to_double(ret);
set_number_from_substraction(arg1,((mp_dash_node)mp_link(p))->start_x,p->stop_x);
take_scaled(ret,arg1,scf);
dashes[(num_dashes)]= number_to_double(ret);
dashes[(num_dashes+1)]= -1.0;
num_dashes+= 2;
p= (mp_dash_node)mp_link(p);
}
d->array= dashes;
mp_dash_offset(mp,&dashoff,h);
take_scaled(ret,dashoff,scf);
d->offset= number_to_double(ret);
free_number(ret);
free_number(arg1);
}
free_number(dashoff);
free_number(scf);
return d;
}


/*:496*//*499:*/
#line 12010 "../../../source/texk/web2c/mplibdir/mp.w"

mp_edge_header_node mp_copy_objects(MP mp,mp_node p,mp_node q){
mp_edge_header_node hh;
mp_node pp;
quarterword k= 0;
hh= mp_get_edge_header_node(mp);
set_dash_list(hh,mp->null_dash);
edge_ref_count(hh)= 0;
pp= edge_list(hh);
while(p!=q){
/*500:*/
#line 12028 "../../../source/texk/web2c/mplibdir/mp.w"

{
switch(mp_type(p)){
case mp_start_clip_node_type:
k= start_clip_size;
break;
case mp_start_bounds_node_type:
k= start_bounds_size;
break;
case mp_fill_node_type:
k= fill_node_size;
break;
case mp_stroked_node_type:
k= stroked_node_size;
break;
case mp_text_node_type:
k= text_node_size;
break;
case mp_stop_clip_node_type:
k= stop_clip_size;
break;
case mp_stop_bounds_node_type:
k= stop_bounds_size;
break;
default:
break;
}
mp_link(pp)= malloc_node((size_t)k);
pp= mp_link(pp);
memcpy(pp,p,(size_t)k);
pp->link= NULL;
/*501:*/
#line 12065 "../../../source/texk/web2c/mplibdir/mp.w"

switch(mp_type(p)){
case mp_start_clip_node_type:
{
mp_start_clip_node tt= (mp_start_clip_node)pp;
mp_start_clip_node t= (mp_start_clip_node)p;
mp_path_p(tt)= mp_copy_path(mp,mp_path_p(t));
}
break;
case mp_start_bounds_node_type:
{
mp_start_bounds_node tt= (mp_start_bounds_node)pp;
mp_start_bounds_node t= (mp_start_bounds_node)p;
mp_path_p(tt)= mp_copy_path(mp,mp_path_p(t));
}
break;
case mp_fill_node_type:
{
mp_fill_node tt= (mp_fill_node)pp;
mp_fill_node t= (mp_fill_node)p;
new_number(tt->red);number_clone(tt->red,t->red);
new_number(tt->green);number_clone(tt->green,t->green);
new_number(tt->blue);number_clone(tt->blue,t->blue);
new_number(tt->black);number_clone(tt->black,t->black);
new_number(tt->miterlim);number_clone(tt->miterlim,t->miterlim);
mp_path_p(tt)= mp_copy_path(mp,mp_path_p(t));
if(mp_pre_script(p)!=NULL)
add_str_ref(mp_pre_script(p));
if(mp_post_script(p)!=NULL)
add_str_ref(mp_post_script(p));
if(mp_pen_p(t)!=NULL)
mp_pen_p(tt)= copy_pen(mp_pen_p(t));
}
break;
case mp_stroked_node_type:
{
mp_stroked_node tt= (mp_stroked_node)pp;
mp_stroked_node t= (mp_stroked_node)p;
new_number(tt->red);number_clone(tt->red,t->red);
new_number(tt->green);number_clone(tt->green,t->green);
new_number(tt->blue);number_clone(tt->blue,t->blue);
new_number(tt->black);number_clone(tt->black,t->black);
new_number(tt->miterlim);number_clone(tt->miterlim,t->miterlim);
new_number(tt->dash_scale);number_clone(tt->dash_scale,t->dash_scale);
if(mp_pre_script(p)!=NULL)
add_str_ref(mp_pre_script(p));
if(mp_post_script(p)!=NULL)
add_str_ref(mp_post_script(p));
mp_path_p(tt)= mp_copy_path(mp,mp_path_p(t));
mp_pen_p(tt)= copy_pen(mp_pen_p(t));
if(mp_dash_p(p)!=NULL)
add_edge_ref(mp_dash_p(pp));
}
break;
case mp_text_node_type:
{
mp_text_node tt= (mp_text_node)pp;
mp_text_node t= (mp_text_node)p;
new_number(tt->red);number_clone(tt->red,t->red);
new_number(tt->green);number_clone(tt->green,t->green);
new_number(tt->blue);number_clone(tt->blue,t->blue);
new_number(tt->black);number_clone(tt->black,t->black);
new_number(tt->width);number_clone(tt->width,t->width);
new_number(tt->height);number_clone(tt->height,t->height);
new_number(tt->depth);number_clone(tt->depth,t->depth);
new_number(tt->tx);number_clone(tt->tx,t->tx);
new_number(tt->ty);number_clone(tt->ty,t->ty);
new_number(tt->txx);number_clone(tt->txx,t->txx);
new_number(tt->tyx);number_clone(tt->tyx,t->tyx);
new_number(tt->txy);number_clone(tt->txy,t->txy);
new_number(tt->tyy);number_clone(tt->tyy,t->tyy);
if(mp_pre_script(p)!=NULL)
add_str_ref(mp_pre_script(p));
if(mp_post_script(p)!=NULL)
add_str_ref(mp_post_script(p));
add_str_ref(mp_text_p(pp));
}
break;
case mp_stop_clip_node_type:
case mp_stop_bounds_node_type:
break;
default:
break;
}


/*:501*/
#line 12060 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= mp_link(p);
}


/*:500*/
#line 12020 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
obj_tail(hh)= pp;
mp_link(pp)= NULL;
return hh;
}


/*:499*//*502:*/
#line 12157 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_skip_1component(MP mp,mp_node p){
integer lev;
lev= 0;
(void)mp;
do{
if(is_start_or_stop(p)){
if(is_stop(p))
decr(lev);
else
incr(lev);
}
p= mp_link(p);
}while(lev!=0);
return p;
}


/*:502*//*504:*/
#line 12180 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_edges(MP mp,mp_node h,const char*s,boolean nuline){
mp_node p;
mp_number scf;
boolean ok_to_dash;
new_number(scf);
mp_print_diagnostic(mp,"Edge structure",s,nuline);
p= edge_list(h);
while(mp_link(p)!=NULL){
p= mp_link(p);
mp_print_ln(mp);
switch(mp_type(p)){
/*505:*/
#line 12207 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_fill_node_type:
mp_print(mp,"Filled contour ");
mp_print_obj_color(mp,p);
mp_print_char(mp,xord(':'));
mp_print_ln(mp);
mp_pr_path(mp,mp_path_p((mp_fill_node)p));
mp_print_ln(mp);
if((mp_pen_p((mp_fill_node)p)!=NULL)){
/*506:*/
#line 12223 "../../../source/texk/web2c/mplibdir/mp.w"

switch(((mp_stroked_node)p)->ljoin){
case 0:
mp_print(mp,"mitered joins limited ");
print_number(((mp_stroked_node)p)->miterlim);
break;
case 1:
mp_print(mp,"round joins");
break;
case 2:
mp_print(mp,"beveled joins");
break;
default:
mp_print(mp,"?? joins");
;
break;
}


/*:506*/
#line 12216 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print(mp," with pen");
mp_print_ln(mp);
mp_pr_pen(mp,mp_pen_p((mp_fill_node)p));
}
break;

/*:505*//*510:*/
#line 12310 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_stroked_node_type:
mp_print(mp,"Filled pen stroke ");
mp_print_obj_color(mp,p);
mp_print_char(mp,xord(':'));
mp_print_ln(mp);
mp_pr_path(mp,mp_path_p((mp_stroked_node)p));
if(mp_dash_p(p)!=NULL){
mp_print_nl(mp,"dashed (");
/*511:*/
#line 12339 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_dash_node ppd,hhd;
ok_to_dash= pen_is_elliptical(mp_pen_p((mp_stroked_node)p));
if(!ok_to_dash)
set_number_to_unity(scf);
else
number_clone(scf,((mp_stroked_node)p)->dash_scale);
hhd= (mp_dash_node)mp_dash_p(p);
ppd= dash_list(hhd);
if((ppd==mp->null_dash)||number_negative(hhd->dash_y)){
mp_print(mp," ??");
}else{
mp_number dashoff;
mp_number ret,arg1;
new_number(ret);
new_number(arg1);
new_number(dashoff);
set_number_from_addition(mp->null_dash->start_x,ppd->start_x,hhd->dash_y);
while(ppd!=mp->null_dash){
mp_print(mp,"on ");
set_number_from_substraction(arg1,ppd->stop_x,ppd->start_x);
take_scaled(ret,arg1,scf);
print_number(ret);
mp_print(mp," off ");
set_number_from_substraction(arg1,((mp_dash_node)mp_link(ppd))->start_x,ppd->stop_x);
take_scaled(ret,arg1,scf);
print_number(ret);
ppd= (mp_dash_node)mp_link(ppd);
if(ppd!=mp->null_dash)
mp_print_char(mp,xord(' '));
}
mp_print(mp,") shifted ");
mp_dash_offset(mp,&dashoff,hhd);
take_scaled(ret,dashoff,scf);
number_negate(ret);
print_number(ret);
free_number(dashoff);
free_number(ret);
free_number(arg1);
if(!ok_to_dash||number_zero(hhd->dash_y))
mp_print(mp," (this will be ignored)");
}
}

/*:511*/
#line 12319 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp_print_ln(mp);
/*507:*/
#line 12244 "../../../source/texk/web2c/mplibdir/mp.w"

switch(((mp_stroked_node)p)->lcap){
case 0:
mp_print(mp,"butt");
break;
case 1:
mp_print(mp,"round");
break;
case 2:
mp_print(mp,"square");
break;
default:
mp_print(mp,"??");
break;

}
mp_print(mp," ends, ");
/*506:*/
#line 12223 "../../../source/texk/web2c/mplibdir/mp.w"

switch(((mp_stroked_node)p)->ljoin){
case 0:
mp_print(mp,"mitered joins limited ");
print_number(((mp_stroked_node)p)->miterlim);
break;
case 1:
mp_print(mp,"round joins");
break;
case 2:
mp_print(mp,"beveled joins");
break;
default:
mp_print(mp,"?? joins");
;
break;
}


/*:506*/
#line 12261 "../../../source/texk/web2c/mplibdir/mp.w"



/*:507*/
#line 12322 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print(mp," with pen");
mp_print_ln(mp);
if(mp_pen_p((mp_stroked_node)p)==NULL){
mp_print(mp,"???");

}else{
mp_pr_pen(mp,mp_pen_p((mp_stroked_node)p));
}
break;

/*:510*//*514:*/
#line 12404 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_text_node_type:
{
mp_text_node p0= (mp_text_node)p;
mp_print_char(mp,xord('"'));
mp_print_str(mp,mp_text_p(p));
mp_print(mp,"\" infont \"");
mp_print(mp,mp->font_name[mp_font_n(p)]);
mp_print_char(mp,xord('"'));
mp_print_ln(mp);
mp_print_obj_color(mp,p);
mp_print(mp,"transformed ");
mp_print_char(mp,xord('('));
print_number(p0->tx);
mp_print_char(mp,xord(','));
print_number(p0->ty);
mp_print_char(mp,xord(','));
print_number(p0->txx);
mp_print_char(mp,xord(','));
print_number(p0->txy);
mp_print_char(mp,xord(','));
print_number(p0->tyx);
mp_print_char(mp,xord(','));
print_number(p0->tyy);
mp_print_char(mp,xord(')'));
}
break;

/*:514*//*515:*/
#line 12432 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_start_clip_node_type:
mp_print(mp,"clipping path:");
mp_print_ln(mp);
mp_pr_path(mp,mp_path_p((mp_start_clip_node)p));
break;
case mp_stop_clip_node_type:
mp_print(mp,"stop clipping");
break;

/*:515*//*516:*/
#line 12442 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_start_bounds_node_type:
mp_print(mp,"setbounds path:");
mp_print_ln(mp);
mp_pr_path(mp,mp_path_p((mp_start_bounds_node)p));
break;
case mp_stop_bounds_node_type:
mp_print(mp,"end of setbounds");
break;

/*:516*/
#line 12192 "../../../source/texk/web2c/mplibdir/mp.w"
;
default:
mp_print(mp,"[unknown object type!]");
break;
}
}
mp_print_nl(mp,"End edges");
if(p!=obj_tail(h))
mp_print(mp,"?");
;
mp_end_diagnostic(mp,true);
free_number(scf);
}


/*:504*//*509:*/
#line 12270 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_obj_color(MP mp,mp_node p){
mp_stroked_node p0= (mp_stroked_node)p;
if(mp_color_model(p)==mp_grey_model){
if(number_positive(p0->grey)){
mp_print(mp,"greyed ");
mp_print_char(mp,xord('('));
print_number(p0->grey);
mp_print_char(mp,xord(')'));
};
}else if(mp_color_model(p)==mp_cmyk_model){
if(number_positive(p0->cyan)||number_positive(p0->magenta)||
number_positive(p0->yellow)||number_positive(p0->black)){
mp_print(mp,"processcolored ");
mp_print_char(mp,xord('('));
print_number(p0->cyan);
mp_print_char(mp,xord(','));
print_number(p0->magenta);
mp_print_char(mp,xord(','));
print_number(p0->yellow);
mp_print_char(mp,xord(','));
print_number(p0->black);
mp_print_char(mp,xord(')'));
};
}else if(mp_color_model(p)==mp_rgb_model){
if(number_positive(p0->red)||number_positive(p0->green)||
number_positive(p0->blue)){
mp_print(mp,"colored ");
mp_print_char(mp,xord('('));
print_number(p0->red);
mp_print_char(mp,xord(','));
print_number(p0->green);
mp_print_char(mp,xord(','));
print_number(p0->blue);
mp_print_char(mp,xord(')'));
};
}
}


/*:509*//*513:*/
#line 12387 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_dash_offset(MP mp,mp_number*x,mp_dash_node h){
if(dash_list(h)==mp->null_dash||number_negative(h->dash_y))
mp_confusion(mp,"dash0");
;
if(number_zero(h->dash_y)){
set_number_to_zero(*x);
}else{
number_clone(*x,(dash_list(h))->start_x);
number_modulo(*x,h->dash_y);
number_negate(*x);
if(number_negative(*x))
number_add(*x,h->dash_y);
}
}


/*:513*//*517:*/
#line 12462 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_make_dashes(MP mp,mp_edge_header_node h){
mp_node p;
mp_node p0;
mp_knot pp,qq,rr;
mp_dash_node d,dd;
mp_number y0;
/*528:*/
#line 12717 "../../../source/texk/web2c/mplibdir/mp.w"

mp_dash_node dln;
mp_edge_header_node hh;
mp_node ds;

/*:528*/
#line 12469 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(dash_list(h)!=mp->null_dash)
return h;
new_number(y0);
p0= NULL;
p= mp_link(edge_list(h));
while(p!=NULL){
if(mp_type(p)!=mp_stroked_node_type){
/*518:*/
#line 12502 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"When you say `dashed p', picture p should not contain any",
"text, filled regions, or clipping paths.  This time it did",
"so I'll just make it a solid line instead.",
NULL};
mp_back_error(mp,"Picture is too complicated to use as a dash pattern",hlp,true);
mp_get_x_next(mp);
goto NOT_FOUND;
}


/*:518*/
#line 12478 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
pp= mp_path_p((mp_stroked_node)p);
if(p0==NULL){
p0= p;
number_clone(y0,pp->y_coord);
}
/*521:*/
#line 12537 "../../../source/texk/web2c/mplibdir/mp.w"

/*523:*/
#line 12623 "../../../source/texk/web2c/mplibdir/mp.w"

if(!number_equal(((mp_stroked_node)p)->red,((mp_stroked_node)p0)->red)||
!number_equal(((mp_stroked_node)p)->black,((mp_stroked_node)p0)->black)||
!number_equal(((mp_stroked_node)p)->green,((mp_stroked_node)p0)->green)||
!number_equal(((mp_stroked_node)p)->blue,((mp_stroked_node)p0)->blue)
){
const char*hlp[]= {
"When you say `dashed p', everything in picture p should",
"be the same color.  I can\'t handle your color changes",
"so I'll just make it a solid line instead.",
NULL};
mp_back_error(mp,"Picture is too complicated to use as a dash pattern",hlp,true);
mp_get_x_next(mp);
goto NOT_FOUND;
}

/*:523*/
#line 12539 "../../../source/texk/web2c/mplibdir/mp.w"
;
rr= pp;
if(mp_next_knot(pp)!=pp){
do{
qq= rr;
rr= mp_next_knot(rr);
/*522:*/
#line 12566 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number x0,x1,x2,x3;
new_number(x0);
new_number(x1);
new_number(x2);
new_number(x3);
number_clone(x0,qq->x_coord);
number_clone(x1,qq->right_x);
number_clone(x2,rr->left_x);
number_clone(x3,rr->x_coord);
if(number_greater(x0,x1)||number_greater(x1,x2)||number_greater(x2,x3)){
if(number_less(x0,x1)||number_less(x1,x2)||number_less(x2,x3)){
mp_number a1,a2,a3,a4;
mp_number test;
new_number(test);
new_number(a1);
new_number(a2);
new_number(a3);
new_number(a4);
set_number_from_substraction(a1,x2,x1);
set_number_from_substraction(a2,x2,x1);
set_number_from_substraction(a3,x1,x0);
set_number_from_substraction(a4,x3,x2);
ab_vs_cd(test,a1,a2,a3,a4);
free_number(a1);
free_number(a2);
free_number(a3);
free_number(a4);
if(number_positive(test)){
mp_x_retrace_error(mp);
free_number(x0);
free_number(x1);
free_number(x2);
free_number(x3);
free_number(test);
goto NOT_FOUND;
}
free_number(test);
}
}
if(number_greater(pp->x_coord,x0)||number_greater(x0,x3)){
if(number_less(pp->x_coord,x0)||number_less(x0,x3)){
mp_x_retrace_error(mp);
free_number(x0);
free_number(x1);
free_number(x2);
free_number(x3);
goto NOT_FOUND;
}
}
free_number(x0);
free_number(x1);
free_number(x2);
free_number(x3);
}

/*:522*/
#line 12546 "../../../source/texk/web2c/mplibdir/mp.w"
;
}while(mp_right_type(rr)!=mp_endpoint);
}
d= (mp_dash_node)mp_get_dash_node(mp);
if(mp_dash_p(p)==NULL)
dash_info(d)= NULL;
else
dash_info(d)= p;
if(number_less(pp->x_coord,rr->x_coord)){
number_clone(d->start_x,pp->x_coord);
number_clone(d->stop_x,rr->x_coord);
}else{
number_clone(d->start_x,rr->x_coord);
number_clone(d->stop_x,pp->x_coord);
}


/*:521*/
#line 12486 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*524:*/
#line 12639 "../../../source/texk/web2c/mplibdir/mp.w"

number_clone(mp->null_dash->start_x,d->stop_x);
dd= (mp_dash_node)h;
while(number_less(((mp_dash_node)mp_link(dd))->start_x,d->stop_x))
dd= (mp_dash_node)mp_link(dd);
if(dd!=(mp_dash_node)h){
if(number_greater(dd->stop_x,d->start_x)){
mp_x_retrace_error(mp);
goto NOT_FOUND;
};
}
mp_link(d)= mp_link(dd);
mp_link(dd)= (mp_node)d

/*:524*/
#line 12487 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= mp_link(p);
}
if(dash_list(h)==mp->null_dash)
goto NOT_FOUND;
/*527:*/
#line 12687 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number hsf;
new_number(hsf);
d= (mp_dash_node)h;
while(mp_link(d)!=(mp_node)mp->null_dash){
ds= dash_info(mp_link(d));
if(ds==NULL){
d= (mp_dash_node)mp_link(d);
}else{
hh= (mp_edge_header_node)mp_dash_p(ds);
number_clone(hsf,((mp_stroked_node)ds)->dash_scale);
if(hh==NULL)
mp_confusion(mp,"dash1");
;
assert(hh);
if(number_zero(((mp_dash_node)hh)->dash_y)){
d= (mp_dash_node)mp_link(d);
}else{
if(dash_list(hh)==NULL)
mp_confusion(mp,"dash1");
;
/*529:*/
#line 12722 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number xoff;
mp_number dashoff;
mp_number r1,r2;
new_number(r1);
new_number(r2);
dln= (mp_dash_node)mp_link(d);
dd= dash_list(hh);
assert(dd);
new_number(xoff);
new_number(dashoff);
mp_dash_offset(mp,&dashoff,(mp_dash_node)hh);
take_scaled(r1,hsf,dd->start_x);
take_scaled(r2,hsf,dashoff);
number_add(r1,r2);
set_number_from_substraction(xoff,dln->start_x,r1);
free_number(dashoff);
take_scaled(r1,hsf,dd->start_x);
take_scaled(r2,hsf,hh->dash_y);
set_number_from_addition(mp->null_dash->start_x,r1,r2);
number_clone(mp->null_dash->stop_x,mp->null_dash->start_x);
/*530:*/
#line 12767 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1;
new_number(r1);
take_scaled(r1,hsf,dd->stop_x);
number_add(r1,xoff);
while(number_less(r1,dln->start_x)){
dd= (mp_dash_node)mp_link(dd);
take_scaled(r1,hsf,dd->stop_x);
number_add(r1,xoff);
}
free_number(r1);
}

/*:530*/
#line 12745 "../../../source/texk/web2c/mplibdir/mp.w"
;
while(number_lessequal(dln->start_x,dln->stop_x)){
/*531:*/
#line 12781 "../../../source/texk/web2c/mplibdir/mp.w"

if(dd==mp->null_dash){
mp_number ret;
new_number(ret);
dd= dash_list(hh);
take_scaled(ret,hsf,hh->dash_y);
number_add(xoff,ret);
free_number(ret);
}

/*:531*/
#line 12747 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*532:*/
#line 12793 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1;
new_number(r1);
take_scaled(r1,hsf,dd->start_x);
number_add(r1,xoff);
if(number_lessequal(r1,dln->stop_x)){
mp_link(d)= (mp_node)mp_get_dash_node(mp);
d= (mp_dash_node)mp_link(d);
mp_link(d)= (mp_node)dln;
take_scaled(r1,hsf,dd->start_x);
number_add(r1,xoff);
if(number_greater(dln->start_x,r1))
number_clone(d->start_x,dln->start_x);
else{
number_clone(d->start_x,r1);
}
take_scaled(r1,hsf,dd->stop_x);
number_add(r1,xoff);
if(number_less(dln->stop_x,r1))
number_clone(d->stop_x,dln->stop_x);
else{
number_clone(d->stop_x,r1);
}
}
free_number(r1);
}

/*:532*/
#line 12749 "../../../source/texk/web2c/mplibdir/mp.w"
;
dd= (mp_dash_node)mp_link(dd);
take_scaled(r1,hsf,dd->start_x);
set_number_from_addition(dln->start_x,xoff,r1);
}
free_number(xoff);
free_number(r1);
free_number(r2);
mp_link(d)= mp_link(dln);
mp_free_node(mp,(mp_node)dln,dash_node_size);
}


/*:529*/
#line 12710 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
}
free_number(hsf);
}

/*:527*/
#line 12492 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*525:*/
#line 12653 "../../../source/texk/web2c/mplibdir/mp.w"

d= dash_list(h);
while((mp_link(d)!=(mp_node)mp->null_dash))
d= (mp_dash_node)mp_link(d);
dd= dash_list(h);
set_number_from_substraction(h->dash_y,d->stop_x,dd->start_x);
{
mp_number absval;
new_number(absval);
number_clone(absval,y0);
number_abs(absval);
if(number_greater(absval,h->dash_y)){
number_clone(h->dash_y,absval);
}else if(d!=dd){
set_dash_list(h,mp_link(dd));
set_number_from_addition(d->stop_x,dd->stop_x,h->dash_y);
mp_free_node(mp,(mp_node)dd,dash_node_size);
}
free_number(absval);
}
/*:525*/
#line 12493 "../../../source/texk/web2c/mplibdir/mp.w"
;
free_number(y0);
return h;
NOT_FOUND:
free_number(y0);
/*526:*/
#line 12678 "../../../source/texk/web2c/mplibdir/mp.w"

mp_flush_dash_list(mp,h);
delete_edge_ref(h);
return NULL

/*:526*/
#line 12498 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:517*//*520:*/
#line 12520 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_x_retrace_error(MP mp){
const char*hlp[]= {
"When you say `dashed p', every path in p should be monotone",
"in x and there must be no overlapping.  This failed",
"so I'll just make it a solid line instead.",
NULL};
mp_back_error(mp,"Picture is too complicated to use as a dash pattern",hlp,true);
mp_get_x_next(mp);
}


/*:520*//*533:*/
#line 12827 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_adjust_bbox(MP mp,mp_edge_header_node h){
if(number_less(mp_minx,h->minx))
number_clone(h->minx,mp_minx);
if(number_less(mp_miny,h->miny))
number_clone(h->miny,mp_miny);
if(number_greater(mp_maxx,h->maxx))
number_clone(h->maxx,mp_maxx);
if(number_greater(mp_maxy,h->maxy))
number_clone(h->maxy,mp_maxy);
}


/*:533*//*534:*/
#line 12844 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_box_ends(MP mp,mp_knot p,mp_knot pp,mp_edge_header_node h){
mp_knot q;
mp_fraction dx,dy;
mp_number d;
mp_number z;
mp_number xx,yy;
integer i;
new_fraction(dx);
new_fraction(dy);
new_number(xx);
new_number(yy);
new_number(z);
new_number(d);
if(mp_right_type(p)!=mp_endpoint){
q= mp_next_knot(p);
while(1){
/*535:*/
#line 12890 "../../../source/texk/web2c/mplibdir/mp.w"

if(q==mp_next_knot(p)){
set_number_from_substraction(dx,p->x_coord,p->right_x);
set_number_from_substraction(dy,p->y_coord,p->right_y);
if(number_zero(dx)&&number_zero(dy)){
set_number_from_substraction(dx,p->x_coord,q->left_x);
set_number_from_substraction(dy,p->y_coord,q->left_y);
}
}else{
set_number_from_substraction(dx,p->x_coord,p->left_x);
set_number_from_substraction(dy,p->y_coord,p->left_y);
if(number_zero(dx)&&number_zero(dy)){
set_number_from_substraction(dx,p->x_coord,q->right_x);
set_number_from_substraction(dy,p->y_coord,q->right_y);
}
}
set_number_from_substraction(dx,p->x_coord,q->x_coord);
set_number_from_substraction(dy,p->y_coord,q->y_coord);


/*:535*/
#line 12862 "../../../source/texk/web2c/mplibdir/mp.w"
;
pyth_add(d,dx,dy);
if(number_positive(d)){
/*536:*/
#line 12910 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number arg1,r;
new_fraction(r);
new_number(arg1);
make_fraction(r,dx,d);
number_clone(dx,r);
make_fraction(r,dy,d);
number_clone(dy,r);
free_number(r);
number_clone(arg1,dy);
number_negate(arg1);
mp_find_offset(mp,arg1,dx,pp);
free_number(arg1);
number_clone(xx,mp->cur_x);
number_clone(yy,mp->cur_y);
}

/*:536*/
#line 12865 "../../../source/texk/web2c/mplibdir/mp.w"
;
for(i= 1;i<=2;i++){
/*537:*/
#line 12928 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1,r2,arg1;
new_number(arg1);
new_fraction(r1);
new_fraction(r2);
mp_find_offset(mp,dx,dy,pp);
set_number_from_substraction(arg1,xx,mp->cur_x);
take_fraction(r1,arg1,dx);
set_number_from_substraction(arg1,yy,mp->cur_y);
take_fraction(r2,arg1,dy);
set_number_from_addition(d,r1,r2);
if((number_negative(d)&&(i==1))||(number_positive(d)&&(i==2)))
mp_confusion(mp,"box_ends");
;
take_fraction(r1,d,dx);
set_number_from_addition(z,p->x_coord,mp->cur_x);
number_add(z,r1);
if(number_less(z,h->minx))
number_clone(h->minx,z);
if(number_greater(z,h->maxx))
number_clone(h->maxx,z);
take_fraction(r1,d,dy);
set_number_from_addition(z,p->y_coord,mp->cur_y);
number_add(z,r1);
if(number_less(z,h->miny))
number_clone(h->miny,z);
if(number_greater(z,h->maxy))
number_clone(h->maxy,z);
free_number(r1);
free_number(r2);
free_number(arg1);
}

/*:537*/
#line 12868 "../../../source/texk/web2c/mplibdir/mp.w"
;
number_negate(dx);
number_negate(dy);
}
}
if(mp_right_type(p)==mp_endpoint){
goto DONE;
}else{
/*538:*/
#line 12962 "../../../source/texk/web2c/mplibdir/mp.w"

do{
q= p;
p= mp_next_knot(p);
}while(mp_right_type(p)!=mp_endpoint)

/*:538*/
#line 12876 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
}
DONE:
free_number(dx);
free_number(dy);
free_number(xx);
free_number(yy);
free_number(z);
free_number(d);
}


/*:534*//*539:*/
#line 12976 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_set_bbox(MP mp,mp_edge_header_node h,boolean top_level){
mp_node p;
integer lev;


switch(h->bbtype){
case no_bounds:
break;
case bounds_set:
if(number_positive(internal_value(mp_true_corners)))
mp_init_bbox(mp,h);
break;
case bounds_unset:
if(number_nonpositive(internal_value(mp_true_corners)))
mp_init_bbox(mp,h);
break;
}

while(mp_link(bblast(h))!=NULL){
p= mp_link(bblast(h));
bblast(h)= p;
switch(mp_type(p)){
case mp_stop_clip_node_type:
if(top_level)
mp_confusion(mp,"bbox");
else
return;
;
break;
/*541:*/
#line 13020 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_fill_node_type:
mp_path_bbox(mp,mp_path_p((mp_fill_node)p));
if(mp_pen_p((mp_fill_node)p)!=NULL){
mp_number x0a,y0a,x1a,y1a;
new_number(x0a);
new_number(y0a);
new_number(x1a);
new_number(y1a);
number_clone(x0a,mp_minx);
number_clone(y0a,mp_miny);
number_clone(x1a,mp_maxx);
number_clone(y1a,mp_maxy);
mp_pen_bbox(mp,mp_pen_p((mp_fill_node)p));
number_add(mp_minx,x0a);
number_add(mp_miny,y0a);
number_add(mp_maxx,x1a);
number_add(mp_maxy,y1a);
free_number(x0a);
free_number(y0a);
free_number(x1a);
free_number(y1a);
}
mp_adjust_bbox(mp,h);
break;

/*:541*//*542:*/
#line 13046 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_start_bounds_node_type:
if(number_positive(internal_value(mp_true_corners))){
h->bbtype= bounds_unset;
}else{
h->bbtype= bounds_set;
mp_path_bbox(mp,mp_path_p((mp_start_bounds_node)p));
mp_adjust_bbox(mp,h);
/*543:*/
#line 13064 "../../../source/texk/web2c/mplibdir/mp.w"

lev= 1;
while(lev!=0){
if(mp_link(p)==NULL)
mp_confusion(mp,"bbox2");
;
assert(mp_link(p));
p= mp_link(p);
if(mp_type(p)==mp_start_bounds_node_type)
incr(lev);
else if(mp_type(p)==mp_stop_bounds_node_type)
decr(lev);
}
bblast(h)= p

/*:543*/
#line 13055 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
break;
case mp_stop_bounds_node_type:
if(number_nonpositive(internal_value(mp_true_corners)))
mp_confusion(mp,"bbox2");
;
break;

/*:542*//*544:*/
#line 13084 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_stroked_node_type:
mp_path_bbox(mp,mp_path_p((mp_stroked_node)p));
{
mp_number x0a,y0a,x1a,y1a;
new_number(x0a);
new_number(y0a);
new_number(x1a);
new_number(y1a);
number_clone(x0a,mp_minx);
number_clone(y0a,mp_miny);
number_clone(x1a,mp_maxx);
number_clone(y1a,mp_maxy);
mp_pen_bbox(mp,mp_pen_p((mp_stroked_node)p));
number_add(mp_minx,x0a);
number_add(mp_miny,y0a);
number_add(mp_maxx,x1a);
number_add(mp_maxy,y1a);
free_number(x0a);
free_number(y0a);
free_number(x1a);
free_number(y1a);
}
mp_adjust_bbox(mp,h);
if((mp_left_type(mp_path_p((mp_stroked_node)p))==mp_endpoint)
&&(((mp_stroked_node)p)->lcap==2))
mp_box_ends(mp,mp_path_p((mp_stroked_node)p),
mp_pen_p((mp_stroked_node)p),h);
break;

/*:544*//*545:*/
#line 13118 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_text_node_type:
{
mp_number x0a,y0a,x1a,y1a,arg1;
mp_text_node p0= (mp_text_node)p;
new_number(x0a);
new_number(x1a);
new_number(y0a);
new_number(y1a);
new_number(arg1);
number_clone(arg1,p0->depth);
number_negate(arg1);
take_scaled(x1a,p0->txx,p0->width);
take_scaled(y0a,p0->txy,arg1);
take_scaled(y1a,p0->txy,p0->height);
number_clone(mp_minx,p0->tx);
number_clone(mp_maxx,mp_minx);
if(number_less(y0a,y1a)){
number_add(mp_minx,y0a);
number_add(mp_maxx,y1a);
}else{
number_add(mp_minx,y1a);
number_add(mp_maxx,y0a);
}
if(number_negative(x1a))
number_add(mp_minx,x1a);
else
number_add(mp_maxx,x1a);
take_scaled(x1a,p0->tyx,p0->width);
number_clone(arg1,p0->depth);
number_negate(arg1);
take_scaled(y0a,p0->tyy,arg1);
take_scaled(y1a,p0->tyy,p0->height);
number_clone(mp_miny,p0->ty);
number_clone(mp_maxy,mp_miny);
if(number_less(y0a,y1a)){
number_add(mp_miny,y0a);
number_add(mp_maxy,y1a);
}else{
number_add(mp_miny,y1a);
number_add(mp_maxy,y0a);
}
if(number_negative(x1a))
number_add(mp_miny,x1a);
else
number_add(mp_maxy,x1a);
mp_adjust_bbox(mp,h);
free_number(x0a);
free_number(y0a);
free_number(x1a);
free_number(y1a);
free_number(arg1);
}
break;

/*:545*//*546:*/
#line 13176 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_start_clip_node_type:
{
mp_number sminx,sminy,smaxx,smaxy;

mp_number x0a,y0a,x1a,y1a;
new_number(x0a);
new_number(y0a);
new_number(x1a);
new_number(y1a);
new_number(sminx);
new_number(sminy);
new_number(smaxx);
new_number(smaxy);
mp_path_bbox(mp,mp_path_p((mp_start_clip_node)p));
number_clone(x0a,mp_minx);
number_clone(y0a,mp_miny);
number_clone(x1a,mp_maxx);
number_clone(y1a,mp_maxy);
number_clone(sminx,h->minx);
number_clone(sminy,h->miny);
number_clone(smaxx,h->maxx);
number_clone(smaxy,h->maxy);
/*547:*/
#line 13219 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_to_inf(h->minx);
set_number_to_inf(h->miny);
set_number_to_neg_inf(h->maxx);
set_number_to_neg_inf(h->maxy);
mp_set_bbox(mp,h,false)


/*:547*/
#line 13200 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*548:*/
#line 13227 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_less(h->minx,x0a))
number_clone(h->minx,x0a);
if(number_less(h->miny,y0a))
number_clone(h->miny,y0a);
if(number_greater(h->maxx,x1a))
number_clone(h->maxx,x1a);
if(number_greater(h->maxy,y1a))
number_clone(h->maxy,y1a);

/*:548*/
#line 13202 "../../../source/texk/web2c/mplibdir/mp.w"
;
number_clone(mp_minx,sminx);
number_clone(mp_miny,sminy);
number_clone(mp_maxx,smaxx);
number_clone(mp_maxy,smaxy);
mp_adjust_bbox(mp,h);
free_number(sminx);
free_number(sminy);
free_number(smaxx);
free_number(smaxy);
free_number(x0a);
free_number(y0a);
free_number(x1a);
free_number(y1a);
}
break;

/*:546*/
#line 13006 "../../../source/texk/web2c/mplibdir/mp.w"
;
default:
break;
}
}
if(!top_level)
mp_confusion(mp,"bbox");
}


/*:539*//*552:*/
#line 13271 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_offset_prep(MP mp,mp_knot c,mp_knot h){
int n;
mp_knot c0,p,q,q0,r,w,ww;
int k_needed;
mp_knot w0;
mp_number dxin,dyin;
int turn_amt;
mp_number max_coef;
mp_number ss;
/*566:*/
#line 13644 "../../../source/texk/web2c/mplibdir/mp.w"

mp_number x0,x1,x2,y0,y1,y2;
mp_number t0,t1,t2;
mp_number du,dv,dx,dy;
mp_number dx0,dy0;
mp_number x0a,x1a,x2a,y0a,y1a,y2a;
mp_number t;
mp_number s;
mp_number dx_m;
mp_number dy_m;
mp_number dxin_m;


/*:566*//*581:*/
#line 14376 "../../../source/texk/web2c/mplibdir/mp.w"

mp_number u0,u1,v0,v1;
int d_sign;

/*:581*/
#line 13281 "../../../source/texk/web2c/mplibdir/mp.w"
;
new_number(max_coef);
new_number(dxin);
new_number(dyin);
new_number(dx0);
new_number(dy0);
new_number(x0);
new_number(y0);
new_number(x1);
new_number(y1);
new_number(x2);
new_number(y2);
new_number(du);
new_number(dv);
new_number(dx);
new_number(dy);
new_number(x0a);
new_number(y0a);
new_number(x1a);
new_number(y1a);
new_number(x2a);
new_number(y2a);
new_number(t0);
new_number(t1);
new_number(t2);
new_number(u0);
new_number(u1);
new_number(v0);
new_number(v1);
new_number(dx_m);
new_number(dy_m);
new_number(dxin_m);
new_number(dx_ap);
new_number(dy_ap);
new_number(dxin_ap);
new_number(dyin_ap);
new_number(ueps_ap);
new_fraction(ss);
new_fraction(s);
new_fraction(t);
/*555:*/
#line 13433 "../../../source/texk/web2c/mplibdir/mp.w"

n= 0;
p= h;
do{
incr(n);
p= mp_next_knot(p);
}while(p!=h)

/*:555*/
#line 13321 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*556:*/
#line 13445 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_knot hn= mp_next_knot(h);
mp_knot hp= mp_prev_knot(h);
set_number_from_substraction(dxin,hn->x_coord,hp->x_coord);
set_number_from_substraction(dyin,hn->y_coord,hp->y_coord);
if(number_zero(dxin)&&number_zero(dyin)){
set_number_from_substraction(dxin,hp->y_coord,h->y_coord);
set_number_from_substraction(dyin,h->x_coord,hp->x_coord);
}
}
w0= h

/*:556*/
#line 13322 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= c;
c0= c;
k_needed= 0;
#ifdef DEBUGENVELOPE
dbg_nl;dbg_str(--[==[BEGIN]==]);dbg_nl;
dbg_str(return{);dbg_nl;
dbg_n(w0->x_coord);
dbg_n(w0->y_coord);
#endif
do{
q= mp_next_knot(p);
#ifdef DEBUGENVELOPE
dbg_nl;dbg_open_t;dbg_str(--[==[begin loop]==]);dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_n(p->right_x);dbg_n(p->right_y);
dbg_n(q->left_x);dbg_n(q->left_y);
dbg_n(q->x_coord);dbg_n(q->y_coord);
dbg_n(w0->x_coord);
dbg_n(w0->y_coord);
#endif
/*563:*/
#line 13588 "../../../source/texk/web2c/mplibdir/mp.w"

#ifdef DEBUGENVELOPE
dbg_comment(Split the cubic between|p|and|q|);dbg_nl;
dbg_key(Split the cubic);dbg_open_t;dbg_nl;
dbg_key_ival(pre info p,mp_knot_info(p));dbg_comma;
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
#endif
mp_knot_info(p)= zero_off+k_needed;
#ifdef DEBUGENVELOPE
dbg_key_ival(post info p,mp_knot_info(p));dbg_close_t;dbg_comma;dbg_nl;
#endif
k_needed= 0;
/*567:*/
#line 13657 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_from_substraction(x0,p->right_x,p->x_coord);
set_number_from_substraction(x2,q->x_coord,q->left_x);
set_number_from_substraction(x1,q->left_x,p->right_x);
set_number_from_substraction(y0,p->right_y,p->y_coord);
set_number_from_substraction(y2,q->y_coord,q->left_y);
set_number_from_substraction(y1,q->left_y,p->right_y);
#ifdef DEBUGENVELOPE
dbg_key(Prepare for derivative computations);dbg_open_t;dbg_nl;
dbg_n(x0);dbg_n(y0);dbg_n(x1);dbg_n(y1);dbg_n(x2);dbg_n(y2);
dbg_close_t;dbg_comma;dbg_nl;
#endif
{
mp_number absval;
new_number(absval);
number_clone(absval,x1);
number_abs(absval);
number_clone(max_coef,x0);
number_abs(max_coef);
if(number_greater(absval,max_coef)){
number_clone(max_coef,absval);
}
number_clone(absval,x2);
number_abs(absval);
if(number_greater(absval,max_coef)){
number_clone(max_coef,absval);
}
number_clone(absval,y0);
number_abs(absval);
if(number_greater(absval,max_coef)){
number_clone(max_coef,absval);
}
number_clone(absval,y1);
number_abs(absval);
if(number_greater(absval,max_coef)){
number_clone(max_coef,absval);
}
number_clone(absval,y2);
number_abs(absval);
if(number_greater(absval,max_coef)){
number_clone(max_coef,absval);
}
if(number_zero(max_coef)){
goto NOT_FOUND;
}
free_number(absval);
}
while(number_less(max_coef,fraction_half_t)){
number_double(max_coef);
number_double(x0);
number_double(x1);
number_double(x2);
number_double(y0);
number_double(y1);
number_double(y2);
}


/*:567*/
#line 13601 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*572:*/
#line 13962 "../../../source/texk/web2c/mplibdir/mp.w"

#ifdef DEBUGENVELOPE
dbg_nl;
dbg_comment(Find the initial direction|(dx,dy)|);dbg_nl;
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
#endif
number_clone(dx_m,zero_t);
number_clone(dy_m,zero_t);
number_clone(dx,x0);
number_clone(dy,y0);
if(number_zero(dx)&&number_zero(dy)){
number_clone(dx,x1);
number_clone(dy,y1);
if(number_zero(dx)&&number_zero(dy)){
number_clone(dx,x2);
number_clone(dy,y2);
}
}
if(p==c){
number_clone(dx0,dx);
number_clone(dy0,dy);
}

#ifdef DEBUGENVELOPE
dbg_nl;dbg_key(mp_dx_dy_approx_t_1);dbg_open_t;dbg_nl;
dbg_n(ueps_ap);
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_n(p->right_x);dbg_n(p->right_y);
dbg_n(q->left_x);dbg_n(q->left_y);
dbg_n(q->x_coord);dbg_n(q->y_coord);
#endif
#ifdef DEBUGENVELOPE
dbg_n(dxin_ap);dbg_n(dyin_ap);
dbg_close_t;dbg_comma;dbg_nl;
#endif
#ifdef DEBUGENVELOPE
dbg_nl;dbg_key(mp_dx_dy_approx_t_0);dbg_open_t;dbg_nl;
dbg_n(ueps_ap);
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_n(p->right_x);dbg_n(p->right_y);
dbg_n(q->left_x);dbg_n(q->left_y);
dbg_n(q->x_coord);dbg_n(q->y_coord);
#endif
#ifdef DEBUGENVELOPE
dbg_close_t;dbg_comma;dbg_nl;
dbg_key(derivatives);dbg_open_t;dbg_nl;
dbg_n(dx_m);dbg_n(dy_m);
dbg_n(dx);dbg_n(dy);dbg_n(dx_ap);dbg_n(dy_ap);dbg_close_t;dbg_comma;dbg_nl;
#endif
#ifdef DEBUGENVELOPE
dbg_key(derivatives after first patch);dbg_open_t;dbg_nl;
dbg_n(dx_m);dbg_n(dy_m);
dbg_n(dx);dbg_n(dy);dbg_n(dx_ap);dbg_n(dy_ap);dbg_close_t;dbg_comma;dbg_nl;
#endif
#ifdef DEBUGENVELOPE
dbg_key(derivatives patched);dbg_open_t;dbg_nl;
dbg_n(dx_m);dbg_n(dy_m);
dbg_n(dx);dbg_n(dy);dbg_n(dx_ap);dbg_n(dy_ap);dbg_close_t;dbg_comma;dbg_nl;
#endif



/*:572*/
#line 13602 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*574:*/
#line 14061 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ab_vs_cd;
new_number(ab_vs_cd);
ab_vs_cd(ab_vs_cd,dy,dxin,dx,dyin);
#ifdef DEBUGENVELOPE
dbg_nl;
dbg_comment(Update|mp_knot_info(p)|);dbg_nl;
dbg_key(mp_get_turn_amt_dx_dy);dbg_open_t;dbg_str(--[==[call mp_get_turn_amt]==]);dbg_nl;
dbg_n(w0->x_coord);dbg_n(w0->y_coord);dbg_n(dx);dbg_n(dy);dbg_in(number_nonnegative(ab_vs_cd));
dbg_n(ab_vs_cd);
#endif
is_dxdy= true;
turn_amt= mp_get_turn_amt(mp,w0,dx,dy,number_nonnegative(ab_vs_cd));
is_dxdy= false;
#ifdef DEBUGENVELOPE
dbg_dn(turn_amt);
dbg_close_t;dbg_comma;
dbg_nl;
#endif
free_number(ab_vs_cd);
#ifdef DEBUGENVELOPE
dbg_key(w0 before walk);dbg_open_t;dbg_nl;
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
dbg_dn(turn_amt);
dbg_close_t;dbg_comma;
#endif
w= mp_pen_walk(mp,w0,turn_amt);
w0= w;
#ifdef DEBUGENVELOPE
dbg_key(w0 after walk);dbg_open_t;dbg_nl;
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
dbg_close_t;dbg_comma;
dbg_open_t;dbg_in(mp_knot_info(p));
#endif
mp_knot_info(p)= mp_knot_info(p)+turn_amt;
#ifdef DEBUGENVELOPE
dbg_in(mp_knot_info(p));dbg_close_t;dbg_comma;
#endif
}

/*:574*/
#line 13605 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*573:*/
#line 14024 "../../../source/texk/web2c/mplibdir/mp.w"

number_clone(dxin,x2);
number_clone(dyin,y2);
if(number_zero(dxin)&&number_zero(dyin)){
number_clone(dxin,x1);
number_clone(dyin,y1);
if(number_zero(dxin)&&number_zero(dyin)){
number_clone(dxin,x0);
number_clone(dyin,y0);
}
}
#ifdef DEBUGENVELOPE
dbg_key(dxin dyin before);dbg_open_t;dbg_nl;
dbg_n(dxin);dbg_n(dyin);
dbg_close_t;dbg_comma;
#endif
#ifdef DEBUGENVELOPE
dbg_key(dxin dyin after);dbg_open_t;dbg_nl;
dbg_n(dxin);dbg_n(dyin);
dbg_close_t;dbg_comma;
#endif

#ifdef DEBUGENVELOPE
dbg_key(dx dy dxin dyin after patch);dbg_open_t;dbg_nl;
dbg_n(dx);dbg_n(dy);dbg_n(dx_ap);dbg_n(dy_ap);
dbg_n(dxin);dbg_n(dyin);dbg_n(dxin_ap);dbg_n(dyin_ap);
dbg_close_t;dbg_comma;
#endif


/*:573*/
#line 13606 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*582:*/
#line 14385 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ab_vs_cd;
mp_number t_ap;
new_number(t_ap);
new_number(ab_vs_cd);
#ifdef DEBUGENVELOPE
dbg_sp;
dbg_key(Decide on the net change in pen offsets and set turn_amt);dbg_open_t;dbg_nl;
#endif
ab_vs_cd(ab_vs_cd,dx,dyin,dxin,dy);
#ifdef DEBUGENVELOPE
dbg_n(ab_vs_cd);dbg_n(dx);dbg_n(dyin);dbg_n(dxin);dbg_n(dy);
#endif

#ifdef DEBUGENVELOPE
dbg_key_nval(ab_vs_cd patched,ab_vs_cd);
dbg_close_t;dbg_comma;dbg_nl;
#endif

if(number_negative(ab_vs_cd))
d_sign= -1;
else if(number_zero(ab_vs_cd))
d_sign= 0;
else
d_sign= 1;
free_number(ab_vs_cd);
free_number(t_ap);
}
if(d_sign==0){
/*583:*/
#line 14461 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ab_vs_cd1,ab_vs_cd2,t;
new_number(ab_vs_cd1);
new_number(ab_vs_cd2);
new_number(t);
set_number_from_substraction(u0,q->x_coord,p->x_coord);
set_number_from_substraction(u1,q->y_coord,p->y_coord);
ab_vs_cd(ab_vs_cd1,dx,u1,u0,dy);
ab_vs_cd(ab_vs_cd2,u0,dyin,dxin,u1);
set_number_from_addition(t,ab_vs_cd1,ab_vs_cd2);
number_half(t);
if(number_negative(t))
d_sign= -1;
else if(number_zero(t))
d_sign= 0;
else
d_sign= 1;
free_number(t);
free_number(ab_vs_cd1);
free_number(ab_vs_cd2);
}

/*:583*/
#line 14415 "../../../source/texk/web2c/mplibdir/mp.w"

}
if(d_sign==0){
if(number_zero(dx)){
if(number_positive(dy))
d_sign= 1;
else
d_sign= -1;
}else{
if(number_positive(dx))
d_sign= 1;
else
d_sign= -1;
}
}
/*584:*/
#line 14490 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1,r2,arg1;
new_number(arg1);
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,x0,y2);
take_fraction(r2,x2,y0);
#ifdef DEBUGENVELOPE
dbg_sp;
dbg_open_t;dbg_dn(d_sign);dbg_close_t;dbg_comma;dbg_nl;
#endif
number_half(r1);
number_half(r2);
set_number_from_substraction(t0,r1,r2);
set_number_from_addition(arg1,y0,y2);
take_fraction(r1,x1,arg1);
set_number_from_addition(arg1,x0,x2);

take_fraction(r2,y1,arg1);
number_half(r1);
number_half(r2);
set_number_from_substraction(t1,r1,r2);
free_number(arg1);
free_number(r1);
free_number(r2);
}
if(number_zero(t0))
set_number_from_scaled(t0,d_sign);
if(number_positive(t0)){
mp_number arg3;
new_number(arg3);
number_clone(arg3,t0);
number_negate(arg3);
crossing_point(t,t0,t1,arg3);
free_number(arg3);
set_number_from_of_the_way(u0,t,x0,x1);
set_number_from_of_the_way(u1,t,x1,x2);
set_number_from_of_the_way(v0,t,y0,y1);
set_number_from_of_the_way(v1,t,y1,y2);
}else{
mp_number arg1;
new_number(arg1);
number_clone(arg1,t0);
number_negate(arg1);
crossing_point(t,arg1,t1,t0);
free_number(arg1);
set_number_from_of_the_way(u0,t,x2,x1);
set_number_from_of_the_way(u1,t,x1,x0);
set_number_from_of_the_way(v0,t,y2,y1);
set_number_from_of_the_way(v1,t,y1,y0);
}
{
mp_number tmp1,tmp2,r1,r2,arg1;
mp_number abs_ss,eps_ss;
new_fraction(r1);
new_fraction(r2);
new_number(arg1);
new_number(tmp1);
new_number(tmp2);
set_number_from_of_the_way(tmp1,t,u0,u1);
set_number_from_of_the_way(tmp2,t,v0,v1);
set_number_from_addition(arg1,x0,x2);
take_fraction(r1,arg1,tmp1);
set_number_from_addition(arg1,y0,y2);
take_fraction(r2,arg1,tmp2);
set_number_from_addition(ss,r1,r2);

#ifdef DEBUGENVELOPE
dbg_key(patch ss before);dbg_open_t;
dbg_n(ss);dbg_close_t;dbg_comma;
#endif
#ifdef DEBUGENVELOPE
dbg_key(patch ss after);dbg_open_t;
dbg_n(ss);dbg_close_t;dbg_comma;
#endif
free_number(abs_ss);
free_number(eps_ss);

free_number(arg1);
free_number(r1);
free_number(r2);
free_number(tmp1);
free_number(tmp2);
}


/*:584*/
#line 14431 "../../../source/texk/web2c/mplibdir/mp.w"
;
#ifdef DEBUGENVELOPE
dbg_nl;
dbg_key(Make|ss|negative if and only if);dbg_open_t;dbg_nl;
dbg_key(mp_get_turn_amt_dxin_dyin);dbg_open_t;dbg_str(--[==[call mp_get_turn_amt]==]);dbg_nl;;
dbg_n(w->x_coord);dbg_n(w->y_coord);dbg_n(dxin);dbg_n(dyin);dbg_in((d_sign> 0));
#endif
is_dxindyin= true;
turn_amt= mp_get_turn_amt(mp,w,dxin,dyin,(d_sign> 0));
is_dxindyin= false;
#ifdef DEBUGENVELOPE
dbg_key_dval(turn_amt 1,turn_amt);dbg_comma;dbg_nl;
dbg_key_nval(ss,ss);dbg_comma;dbg_nl;
dbg_key_ival(d_sign,d_sign);dbg_comma;dbg_nl;
dbg_key_ival(n,n);dbg_comma;dbg_nl;
#endif
if(number_negative(ss))
turn_amt= turn_amt-d_sign*n;
#ifdef DEBUGENVELOPE
dbg_key_dval(turn_amt 2,turn_amt);dbg_comma;dbg_nl;
dbg_close_t;dbg_comma;dbg_nl;
dbg_close_t;dbg_comma;dbg_nl;
#endif


/*:582*/
#line 13607 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*578:*/
#line 14228 "../../../source/texk/web2c/mplibdir/mp.w"

ww= mp_prev_knot(w);
#ifdef DEBUGENVELOPE
dbg_key(Complete the offset splitting process);dbg_open_t;dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_close_t;dbg_comma;dbg_nl;
#endif
/*570:*/
#line 13834 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number abs_du,abs_dv;
new_number(abs_du);
new_number(abs_dv);
#ifdef DEBUGENVELOPE
dbg_key(Compute test coefficients|(t0,t1,t2)|for $d(t)$ versus...);dbg_open_t;dbg_nl;
#endif
set_number_from_substraction(du,ww->x_coord,w->x_coord);
set_number_from_substraction(dv,ww->y_coord,w->y_coord);
number_clone(abs_du,du);
number_abs(abs_du);
number_clone(abs_dv,dv);
number_abs(abs_dv);
#ifdef DEBUGENVELOPE
dbg_CUBIC;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_n(x0);dbg_n(x1);dbg_n(x2);
dbg_n(y0);dbg_n(y1);dbg_n(y2);
dbg_n(abs_du);dbg_n(abs_dv);
dbg_n(du);dbg_n(dv);
dbg_in(number_greaterequal(abs_du,abs_dv));
#endif
if(number_greaterequal(abs_du,abs_dv)){
mp_number r1;
new_fraction(r1);
make_fraction(s,dv,du);
take_fraction(r1,x0,s);
set_number_from_substraction(t0,r1,y0);
take_fraction(r1,x1,s);
set_number_from_substraction(t1,r1,y1);
take_fraction(r1,x2,s);
set_number_from_substraction(t2,r1,y2);
if(number_negative(du)){
number_negate(t0);
number_negate(t1);
number_negate(t2);
}
free_number(r1);
}else{
mp_number r1;
new_fraction(r1);
make_fraction(s,du,dv);
take_fraction(r1,y0,s);
set_number_from_substraction(t0,x0,r1);
take_fraction(r1,y1,s);
set_number_from_substraction(t1,x1,r1);
take_fraction(r1,y2,s);
set_number_from_substraction(t2,x2,r1);
if(number_negative(dv)){
number_negate(t0);
number_negate(t1);
number_negate(t2);
}
free_number(r1);
}
free_number(abs_du);
free_number(abs_dv);
if(number_negative(t0))
set_number_to_zero(t0);
#ifdef DEBUGENVELOPE
dbg_n(t0);dbg_n(t1);dbg_n(t2);
dbg_close_t;dbg_comma;dbg_nl;
#endif
}


/*:570*/
#line 14236 "../../../source/texk/web2c/mplibdir/mp.w"
;
#ifdef DEBUGENVELOPE
dbg_key(after Compute test coeff);dbg_open_t;dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_close_t;dbg_comma;dbg_nl;
#endif
/*580:*/
#line 14332 "../../../source/texk/web2c/mplibdir/mp.w"

#ifdef DEBUGENVELOPE
dbg_key(Find the first|t|where);dbg_open_t;dbg_nl;
#endif
crossing_point(t,t0,t1,t2);
if(turn_amt>=0){
if(number_negative(t2)){
number_clone(t,fraction_one_t);
number_add_scaled(t,1);
}else{
mp_number tmp,arg1,r1;
new_fraction(r1);
new_number(tmp);
new_number(arg1);
set_number_from_of_the_way(u0,t,x0,x1);
set_number_from_of_the_way(u1,t,x1,x2);
set_number_from_of_the_way(tmp,t,u0,u1);
number_clone(arg1,du);
number_negate(arg1);
take_fraction(ss,arg1,tmp);
set_number_from_of_the_way(v0,t,y0,y1);
set_number_from_of_the_way(v1,t,y1,y2);
set_number_from_of_the_way(tmp,t,v0,v1);
number_clone(arg1,dv);
number_negate(arg1);
take_fraction(r1,arg1,tmp);
number_add(ss,r1);
free_number(tmp);
if(number_negative(ss)){
number_clone(t,fraction_one_t);
number_add_scaled(t,1);
}
free_number(arg1);
free_number(r1);
}
}else if(number_greater(t,fraction_one_t)){
number_clone(t,fraction_one_t);
}
#ifdef DEBUGENVELOPE
dbg_n(t);
dbg_close_t;dbg_comma;dbg_nl;
#endif


/*:580*/
#line 14244 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(number_greater(t,fraction_one_t)){
#ifdef DEBUGENVELOPE
dbg_key(t> fraction_one_t);dbg_open_t;dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(x0);dbg_n(x1);dbg_n(x2);
dbg_n(y0);dbg_n(y1);dbg_n(y2);
dbg_close_t;dbg_comma;dbg_nl;
#endif
mp_fin_offset_prep(mp,p,w,x0,x1,x2,y0,y1,y2,1,turn_amt);
}else{
mp_split_cubic(mp,p,t);
r= mp_next_knot(p);
set_number_from_of_the_way(x1a,t,x0,x1);
set_number_from_of_the_way(x1,t,x1,x2);
set_number_from_of_the_way(x2a,t,x1a,x1);
set_number_from_of_the_way(y1a,t,y0,y1);
set_number_from_of_the_way(y1,t,y1,y2);
set_number_from_of_the_way(y2a,t,y1a,y1);
#ifdef DEBUGENVELOPE
dbg_key(t<=fraction_one_t);dbg_open_t;dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_n(t);
dbg_n(r->x_coord);dbg_n(r->y_coord);
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(x0);dbg_n(x1a);dbg_n(x2a);
dbg_n(y0);dbg_n(y1a);dbg_n(y2a);
dbg_close_t;dbg_comma;dbg_nl;
#endif
mp_fin_offset_prep(mp,p,w,x0,x1a,x2a,y0,y1a,y2a,1,0);
number_clone(x0,x2a);
number_clone(y0,y2a);
mp_knot_info(r)= zero_off-1;
if(turn_amt>=0){
mp_number arg1,arg2,arg3;
new_number(arg1);
new_number(arg2);
new_number(arg3);
set_number_from_of_the_way(t1,t,t1,t2);
if(number_positive(t1))
set_number_to_zero(t1);
number_clone(arg2,t1);
number_negate(arg2);
number_clone(arg3,t2);
number_negate(arg3);
crossing_point(t,arg1,arg2,arg3);
free_number(arg1);
free_number(arg2);
free_number(arg3);
if(number_greater(t,fraction_one_t))
number_clone(t,fraction_one_t);
/*579:*/
#line 14310 "../../../source/texk/web2c/mplibdir/mp.w"

mp_split_cubic(mp,r,t);
mp_knot_info(mp_next_knot(r))= zero_off+1;
set_number_from_of_the_way(x1a,t,x1,x2);
set_number_from_of_the_way(x1,t,x0,x1);
set_number_from_of_the_way(x0a,t,x1,x1a);
set_number_from_of_the_way(y1a,t,y1,y2);
set_number_from_of_the_way(y1,t,y0,y1);
set_number_from_of_the_way(y0a,t,y1,y1a);
mp_fin_offset_prep(mp,mp_next_knot(r),w,x0a,x1a,x2,y0a,y1a,y2,1,turn_amt);
number_clone(x2,x0a);
number_clone(y2,y0a)

/*:579*/
#line 14296 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_fin_offset_prep(mp,r,ww,x0,x1,x2,y0,y1,y2,-1,0);
}else{
mp_fin_offset_prep(mp,r,ww,x0,x1,x2,y0,y1,y2,-1,(-1-turn_amt));
}
}
#ifdef DEBUGENVELOPE
dbg_key(end Complete the offset splitting process);dbg_open_t;dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
dbg_in(turn_amt);
dbg_close_t;dbg_comma;dbg_nl;
#endif

/*:578*/
#line 13608 "../../../source/texk/web2c/mplibdir/mp.w"
;
w0= mp_pen_walk(mp,w0,turn_amt)


/*:563*/
#line 13345 "../../../source/texk/web2c/mplibdir/mp.w"
;
#ifdef DEBUGENVELOPE
dbg_key(end Split the cubic between|p|and|q|);dbg_open_t;dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
dbg_close_t;dbg_comma;dbg_nl;
#endif
NOT_FOUND:
/*557:*/
#line 13468 "../../../source/texk/web2c/mplibdir/mp.w"

#ifdef DEBUGENVELOPE
dbg_comment(Advance|p|to node|q|);dbg_nl;
#endif
q0= q;
do{
r= mp_next_knot(p);
if(number_equal(p->x_coord,p->right_x)&&
number_equal(p->y_coord,p->right_y)&&
number_equal(p->x_coord,r->left_x)&&
number_equal(p->y_coord,r->left_y)&&
number_equal(p->x_coord,r->x_coord)&&
number_equal(p->y_coord,r->y_coord)&&
r!=p&&r!=q){
/*558:*/
#line 13492 "../../../source/texk/web2c/mplibdir/mp.w"

{
#ifdef DEBUGENVELOPE
dbg_key(Remove the cubic following p);dbg_open_t;dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_key_ival(pre info p,mp_knot_info(p));dbg_close_t;dbg_comma;dbg_nl;
#endif
k_needed= mp_knot_info(p)-zero_off;
if(r==q){
q= p;
}else{
mp_knot_info(p)= k_needed+mp_knot_info(r);
k_needed= 0;
}
if(r==c){
mp_knot_info(p)= mp_knot_info(c);
c= p;
}
if(r==mp->spec_p1)
mp->spec_p1= p;
if(r==mp->spec_p2)
mp->spec_p2= p;
r= p;
mp_remove_cubic(mp,p);
#ifdef DEBUGENVELOPE
dbg_key(Remove the cubic following p);dbg_open_t;dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_key_ival(post info p,mp_knot_info(p));dbg_close_t;dbg_comma;dbg_nl;
#endif
}


/*:558*/
#line 13483 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
p= r;
}while(p!=q);

if((q!=q0)&&(q!=c||c==c0))
q= mp_next_knot(q)


/*:557*/
#line 13354 "../../../source/texk/web2c/mplibdir/mp.w"
;
#ifdef DEBUGENVELOPE
dbg_n(w0->x_coord);dbg_n(w0->y_coord);
dbg_str(--[==[end loop]==]);dbg_nl;dbg_close_t;dbg_comma;dbg_nl;
#endif
}while(q!=c);
#ifdef DEBUGENVELOPE
dbg_key(Fix the offset change);dbg_open_t;dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_key_ival(info pre,mp_knot_info(p));dbg_comma;dbg_nl;
dbg_n(c->x_coord);dbg_n(c->y_coord);
dbg_key_ival(info pre,mp_knot_info(c));dbg_close_t;dbg_comma;dbg_nl;
#endif
/*577:*/
#line 14201 "../../../source/texk/web2c/mplibdir/mp.w"

mp->spec_offset= mp_knot_info(c)-zero_off;
if(mp_next_knot(c)==c){
mp_knot_info(c)= zero_off+n;
}else{
mp_number ab_vs_cd;
new_number(ab_vs_cd);
fix_by(k_needed);
while(w0!=h){
fix_by(1);
w0= mp_next_knot(w0);
}
while(mp_knot_info(c)<=zero_off-n)
fix_by(n);
while(mp_knot_info(c)> zero_off)
fix_by(-n);
ab_vs_cd(ab_vs_cd,dy0,dxin,dx0,dyin);
if((mp_knot_info(c)!=zero_off)&&number_nonnegative(ab_vs_cd))
fix_by(n);
free_number(ab_vs_cd);
}


/*:577*/
#line 13368 "../../../source/texk/web2c/mplibdir/mp.w"
;
#ifdef DEBUGENVELOPE
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_key_ival(info post,mp_knot_info(p));dbg_comma;dbg_nl;
dbg_n(c->x_coord);dbg_n(c->y_coord);
dbg_key_ival(info post,mp_knot_info(c));
dbg_close_t;
dbg_nl;dbg_str(--[==[END]==]);dbg_nl;
#endif
free_number(ss);
free_number(s);
free_number(dxin);
free_number(dyin);
free_number(dx0);
free_number(dy0);
free_number(x0);
free_number(y0);
free_number(x1);
free_number(y1);
free_number(x2);
free_number(y2);
free_number(max_coef);
free_number(du);
free_number(dv);
free_number(dx);
free_number(dy);
free_number(x0a);
free_number(y0a);
free_number(x1a);
free_number(y1a);
free_number(x2a);
free_number(y2a);
free_number(t0);
free_number(t1);
free_number(t2);
free_number(u0);
free_number(u1);
free_number(v0);
free_number(v1);
free_number(dx_m);
free_number(dy_m);
free_number(dxin_m);
free_number(dx_ap);
free_number(dy_ap);
free_number(dxin_ap);
free_number(dyin_ap);
free_number(ueps_ap);
free_number(t);
return c;
}


/*:552*//*560:*/
#line 13530 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_split_cubic(MP mp,mp_knot p,mp_number t){
mp_number v;
mp_knot q,r;
q= mp_next_knot(p);
r= mp_new_knot(mp);
mp_next_knot(p)= r;
mp_next_knot(r)= q;
mp_originator(r)= mp_program_code;
mp_left_type(r)= mp_explicit;
mp_right_type(r)= mp_explicit;
new_number(v);
set_number_from_of_the_way(v,t,p->right_x,q->left_x);
set_number_from_of_the_way(p->right_x,t,p->x_coord,p->right_x);
set_number_from_of_the_way(q->left_x,t,q->left_x,q->x_coord);
set_number_from_of_the_way(r->left_x,t,p->right_x,v);
set_number_from_of_the_way(r->right_x,t,v,q->left_x);
set_number_from_of_the_way(r->x_coord,t,r->left_x,r->right_x);
set_number_from_of_the_way(v,t,p->right_y,q->left_y);
set_number_from_of_the_way(p->right_y,t,p->y_coord,p->right_y);
set_number_from_of_the_way(q->left_y,t,q->left_y,q->y_coord);
set_number_from_of_the_way(r->left_y,t,p->right_y,v);
set_number_from_of_the_way(r->right_y,t,v,q->left_y);
set_number_from_of_the_way(r->y_coord,t,r->left_y,r->right_y);
free_number(v);
}


/*:560*//*562:*/
#line 13563 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_remove_cubic(MP mp,mp_knot p){
mp_knot q;
(void)mp;
q= mp_next_knot(p);
mp_next_knot(p)= mp_next_knot(q);
number_clone(p->right_x,q->right_x);
number_clone(p->right_y,q->right_y);
mp_xfree(q);
}


/*:562*//*565:*/
#line 13615 "../../../source/texk/web2c/mplibdir/mp.w"

mp_knot mp_pen_walk(MP mp,mp_knot w,integer k){

(void)mp;
while(k> 0){
w= mp_next_knot(w);
decr(k);
}
while(k<0){
w= mp_prev_knot(w);
incr(k);
}
return w;
}


/*:565*//*569:*/
#line 13745 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_fin_offset_prep(MP mp,mp_knot p,mp_knot w,mp_number
x0,mp_number x1,mp_number x2,mp_number y0,mp_number y1,
mp_number y2,integer rise,integer turn_amt){
mp_knot ww;
mp_number du,dv;
mp_number t0,t1,t2;
mp_number t;
mp_number s;
mp_number v;
mp_knot q;
q= mp_next_knot(p);
new_number(du);
new_number(dv);
new_number(v);
new_number(t0);
new_number(t1);
new_number(t2);
new_fraction(s);
new_fraction(t);
#ifdef DEBUGENVELOPE
dbg_key(mp_fin_offset_prep);dbg_open_t;dbg_nl;
#endif
while(1){
if(rise> 0)
ww= mp_next_knot(w);
else
ww= mp_prev_knot(w);
#ifdef DEBUGENVELOPE
dbg_comment(begin iteration);
dbg_open_t;dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_n(x0);dbg_n(x1);dbg_n(x2);
dbg_n(y0);dbg_n(y1);dbg_n(y2);
dbg_in(rise);
#endif
/*570:*/
#line 13834 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number abs_du,abs_dv;
new_number(abs_du);
new_number(abs_dv);
#ifdef DEBUGENVELOPE
dbg_key(Compute test coefficients|(t0,t1,t2)|for $d(t)$ versus...);dbg_open_t;dbg_nl;
#endif
set_number_from_substraction(du,ww->x_coord,w->x_coord);
set_number_from_substraction(dv,ww->y_coord,w->y_coord);
number_clone(abs_du,du);
number_abs(abs_du);
number_clone(abs_dv,dv);
number_abs(abs_dv);
#ifdef DEBUGENVELOPE
dbg_CUBIC;
dbg_n(w->x_coord);dbg_n(w->y_coord);
dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_n(x0);dbg_n(x1);dbg_n(x2);
dbg_n(y0);dbg_n(y1);dbg_n(y2);
dbg_n(abs_du);dbg_n(abs_dv);
dbg_n(du);dbg_n(dv);
dbg_in(number_greaterequal(abs_du,abs_dv));
#endif
if(number_greaterequal(abs_du,abs_dv)){
mp_number r1;
new_fraction(r1);
make_fraction(s,dv,du);
take_fraction(r1,x0,s);
set_number_from_substraction(t0,r1,y0);
take_fraction(r1,x1,s);
set_number_from_substraction(t1,r1,y1);
take_fraction(r1,x2,s);
set_number_from_substraction(t2,r1,y2);
if(number_negative(du)){
number_negate(t0);
number_negate(t1);
number_negate(t2);
}
free_number(r1);
}else{
mp_number r1;
new_fraction(r1);
make_fraction(s,du,dv);
take_fraction(r1,y0,s);
set_number_from_substraction(t0,x0,r1);
take_fraction(r1,y1,s);
set_number_from_substraction(t1,x1,r1);
take_fraction(r1,y2,s);
set_number_from_substraction(t2,x2,r1);
if(number_negative(dv)){
number_negate(t0);
number_negate(t1);
number_negate(t2);
}
free_number(r1);
}
free_number(abs_du);
free_number(abs_dv);
if(number_negative(t0))
set_number_to_zero(t0);
#ifdef DEBUGENVELOPE
dbg_n(t0);dbg_n(t1);dbg_n(t2);
dbg_close_t;dbg_comma;dbg_nl;
#endif
}


/*:570*/
#line 13783 "../../../source/texk/web2c/mplibdir/mp.w"
;
#ifdef DEBUGENVELOPE
dbg_comment(crossing_point);
#endif
crossing_point(t,t0,t1,t2);
#ifdef DEBUGENVELOPE
dbg_n(t);dbg_n(t0);dbg_n(t1);dbg_n(t2);
dbg_in(number_greaterequal(t,fraction_one_t));
dbg_in(turn_amt);
dbg_close_t;dbg_comma;dbg_nl;
#endif
if(number_greaterequal(t,fraction_one_t)){
if(turn_amt> 0)
number_clone(t,fraction_one_t);
else
goto RETURN;
}
#ifdef DEBUGENVELOPE
dbg_comment(Split the cubic at $t$ and split off another cubic if the derivative crosses back);
#endif
/*571:*/
#line 13906 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_split_cubic(mp,p,t);
p= mp_next_knot(p);
mp_knot_info(p)= zero_off+rise;
decr(turn_amt);
set_number_from_of_the_way(v,t,x0,x1);
set_number_from_of_the_way(x1,t,x1,x2);
set_number_from_of_the_way(x0,t,v,x1);
set_number_from_of_the_way(v,t,y0,y1);
set_number_from_of_the_way(y1,t,y1,y2);
set_number_from_of_the_way(y0,t,v,y1);
if(turn_amt<0){
mp_number arg1,arg2,arg3;
new_number(arg1);
new_number(arg2);
new_number(arg3);
set_number_from_of_the_way(t1,t,t1,t2);
if(number_positive(t1))
set_number_to_zero(t1);
number_clone(arg2,t1);
number_negate(arg2);
number_clone(arg3,t2);
number_negate(arg3);
crossing_point(t,arg1,arg2,arg3);
free_number(arg1);
free_number(arg2);
free_number(arg3);
if(number_greater(t,fraction_one_t))
number_clone(t,fraction_one_t);
incr(turn_amt);
if(number_equal(t,fraction_one_t)&&(mp_next_knot(p)!=q)){
mp_knot_info(mp_next_knot(p))= mp_knot_info(mp_next_knot(p))-rise;
}else{
mp_split_cubic(mp,p,t);
mp_knot_info(mp_next_knot(p))= zero_off-rise;
set_number_from_of_the_way(v,t,x1,x2);
set_number_from_of_the_way(x1,t,x0,x1);
set_number_from_of_the_way(x2,t,x1,v);
set_number_from_of_the_way(v,t,y1,y2);
set_number_from_of_the_way(y1,t,y0,y1);
set_number_from_of_the_way(y2,t,y1,v);
}
}
}


/*:571*/
#line 13804 "../../../source/texk/web2c/mplibdir/mp.w"
;
w= ww;
#ifdef DEBUGENVELOPE
dbg_comment(end iteration);
#endif
}
RETURN:
#ifdef DEBUGENVELOPE
dbg_comment(RETURN);
dbg_n(t);
#endif
free_number(s);
free_number(t);
free_number(du);
free_number(dv);
free_number(v);
free_number(t0);
free_number(t1);
free_number(t2);
#ifdef DEBUGENVELOPE
dbg_close_t;dbg_comma;dbg_nl;
#endif
}


/*:569*//*576:*/
#line 14115 "../../../source/texk/web2c/mplibdir/mp.w"

integer mp_get_turn_amt(MP mp,mp_knot w,mp_number dx,mp_number dy,boolean ccw){
mp_knot ww;
integer s;
mp_number t;
mp_number t_ap;
mp_number arg1,arg2;
s= 0;
new_number(arg1);
new_number(arg2);
new_number(t);
new_number(t_ap);
if(ccw){
ww= mp_next_knot(w);
do{
set_number_from_substraction(arg1,ww->x_coord,w->x_coord);
set_number_from_substraction(arg2,ww->y_coord,w->y_coord);
ab_vs_cd(t,dy,arg1,dx,arg2);
#ifdef DEBUGENVELOPE
dbg_sp;
dbg_open_t;dbg_str(--[==[inside mp_get_turn_amt do loop]==]);dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_n(t);dbg_n(dy);dbg_n(arg1);dbg_n(dx);dbg_n(arg2);
dbg_n(t_ap);dbg_n(dy_ap);dbg_n(dx_ap);dbg_n(dyin_ap);dbg_n(dxin_ap);
dbg_close_t;dbg_comma;
dbg_in(number_zero(dx)&&number_zero(arg1)&&number_positive(dy)&&number_positive(arg2)&&is_dxdy);
dbg_in(is_dxdy&&number_zero(dx)&&number_zero(arg1)&&number_negative(dy)&&number_negative(arg2)&&number_positive(dyin_ap));
dbg_in(is_dxindyin&&number_zero(dx)&&number_zero(arg1)&&number_positive(dy)&&number_positive(arg2)&&number_negative(dyin_ap));
dbg_in(number_zero(dy)&&number_zero(arg2)&&number_negative(dx)&&number_negative(arg1));
dbg_in(number_zero(dx)&&number_zero(arg1)&&number_negative(dy)&&number_positive(arg2));
dbg_in(number_zero(dy)&&number_zero(arg2)&&number_positive(dx)&&number_negative(arg1));
dbg_nl;
#endif
if(number_negative(t))
break;
incr(s);
w= ww;
ww= mp_next_knot(ww);
}while(number_positive(t));
}else{
ww= mp_prev_knot(w);
set_number_from_substraction(arg1,w->x_coord,ww->x_coord);
set_number_from_substraction(arg2,w->y_coord,ww->y_coord);
ab_vs_cd(t,dy,arg1,dx,arg2);
#ifdef DEBUGENVELOPE
dbg_sp;
dbg_open_t;dbg_str(--[==[outside mp_get_turn_amt do loop]==]);dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_n(t);dbg_n(dy);dbg_n(arg1);dbg_n(dx);dbg_n(arg2);
dbg_n(t_ap);dbg_n(dy_ap);dbg_n(dx_ap);dbg_n(dyin_ap);dbg_n(dxin_ap);
dbg_close_t;dbg_comma;
dbg_nl;
#endif
while(number_negative(t)){
decr(s);
w= ww;
ww= mp_prev_knot(ww);
set_number_from_substraction(arg1,w->x_coord,ww->x_coord);
set_number_from_substraction(arg2,w->y_coord,ww->y_coord);
ab_vs_cd(t,dy,arg1,dx,arg2);
#ifdef DEBUGENVELOPE
dbg_sp;
dbg_open_t;dbg_str(--[==[inside mp_get_turn_amt do loop for t<0]==]);dbg_nl;
dbg_n(w->x_coord);dbg_n(w->y_coord);dbg_n(ww->x_coord);dbg_n(ww->y_coord);
dbg_n(t);dbg_n(dy);dbg_n(arg1);dbg_n(dx);dbg_n(arg2);
dbg_n(t_ap);dbg_n(dy_ap);dbg_n(dx_ap);
dbg_close_t;dbg_comma;
dbg_nl;
#endif
}
}
free_number(t);
free_number(t_ap);
free_number(arg1);
free_number(arg2);
return s;
}


/*:576*//*585:*/
#line 14580 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_spec(MP mp,mp_knot cur_spec,mp_knot cur_pen,
const char*s){
mp_knot p,q;
mp_knot w;
mp_print_diagnostic(mp,"Envelope spec",s,true);
p= cur_spec;
w= mp_pen_walk(mp,cur_pen,mp->spec_offset);
mp_print_ln(mp);
mp_print_two(mp,cur_spec->x_coord,cur_spec->y_coord);
mp_print(mp," % beginning with offset ");
mp_print_two(mp,w->x_coord,w->y_coord);
do{
while(1){
q= mp_next_knot(p);
/*587:*/
#line 14628 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_print_nl(mp,"   ..controls ");
mp_print_two(mp,p->right_x,p->right_y);
mp_print(mp," and ");
mp_print_two(mp,q->left_x,q->left_y);
mp_print_nl(mp," ..");
mp_print_two(mp,q->x_coord,q->y_coord);
}


/*:587*/
#line 14595 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= q;
if((p==cur_spec)||(mp_knot_info(p)!=zero_off))
break;
}
if(mp_knot_info(p)!=zero_off){
/*586:*/
#line 14609 "../../../source/texk/web2c/mplibdir/mp.w"

{
w= mp_pen_walk(mp,w,(mp_knot_info(p)-zero_off));
mp_print(mp," % ");
#ifdef DEBUGENVELOPE
dbg_nl;dbg_open_t;dbg_str(--[==[START]==]);dbg_nl;
dbg_key(Printing mp_knot_info(p));dbg_open_t;dbg_nl;
dbg_n(p->x_coord);dbg_n(p->y_coord);
dbg_in(mp_knot_info(p));
dbg_close_t;dbg_close_t;dbg_comma;dbg_nl;
dbg_nl;dbg_str(--[==[STOP]==]);dbg_nl;
#endif
if(mp_knot_info(p)> zero_off)
mp_print(mp,"counter");
mp_print(mp,"clockwise to offset ");
mp_print_two(mp,w->x_coord,w->y_coord);
}


/*:586*/
#line 14601 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}while(p!=cur_spec);
mp_print_nl(mp," & cycle");
mp_end_diagnostic(mp,true);
}


/*:585*//*588:*/
#line 14657 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_make_envelope(MP mp,mp_knot c,mp_knot h,quarterword ljoin,
quarterword lcap,mp_number miterlim){
mp_knot p,q,r,q0;
mp_knot w,w0;
halfword k,k0;
mp_number qx,qy;
mp_fraction dxin,dyin,dxout,dyout;
int join_type= 0;
/*592:*/
#line 14783 "../../../source/texk/web2c/mplibdir/mp.w"

mp_number tmp;

/*:592*//*600:*/
#line 14982 "../../../source/texk/web2c/mplibdir/mp.w"

mp_number max_ht;
halfword kk;
mp_knot ww;

/*:600*/
#line 14666 "../../../source/texk/web2c/mplibdir/mp.w"
;
new_number(max_ht);
new_number(tmp);
new_fraction(dxin);
new_fraction(dyin);
new_fraction(dxout);
new_fraction(dyout);
mp->spec_p1= NULL;
mp->spec_p2= NULL;
new_number(qx);
new_number(qy);
/*603:*/
#line 15025 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp_left_type(c)==mp_endpoint){
mp->spec_p1= mp_htap_ypoc(mp,c);
mp->spec_p2= mp->path_tail;
mp_originator(mp->spec_p1)= mp_program_code;
mp_next_knot(mp->spec_p2)= mp_next_knot(mp->spec_p1);
mp_next_knot(mp->spec_p1)= c;
mp_remove_cubic(mp,mp->spec_p1);
c= mp->spec_p1;
if(c!=mp_next_knot(c)){
mp_originator(mp->spec_p2)= mp_program_code;
mp_remove_cubic(mp,mp->spec_p2);
}else{
/*604:*/
#line 15042 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_left_type(c)= mp_explicit;
mp_right_type(c)= mp_explicit;
number_clone(c->left_x,c->x_coord);
number_clone(c->left_y,c->y_coord);
number_clone(c->right_x,c->x_coord);
number_clone(c->right_y,c->y_coord);
}


/*:604*/
#line 15038 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}

/*:603*/
#line 14677 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*589:*/
#line 14725 "../../../source/texk/web2c/mplibdir/mp.w"

c= mp_offset_prep(mp,c,h);
if(number_positive(internal_value(mp_tracing_specs)))
mp_print_spec(mp,c,h,"");
h= mp_pen_walk(mp,h,mp->spec_offset)


/*:589*/
#line 14679 "../../../source/texk/web2c/mplibdir/mp.w"
;
w= h;
p= c;
do{
q= mp_next_knot(p);
q0= q;
number_clone(qx,q->x_coord);
number_clone(qy,q->y_coord);
k= mp_knot_info(q);
k0= k;
w0= w;
if(k!=zero_off){
/*590:*/
#line 14738 "../../../source/texk/web2c/mplibdir/mp.w"

if(k<zero_off){
join_type= 2;
}else{
if((q!=mp->spec_p1)&&(q!=mp->spec_p2))
join_type= ljoin;
else if(lcap==2)
join_type= 3;
else
join_type= 2-lcap;
if((join_type==0)||(join_type==3)){
/*605:*/
#line 15056 "../../../source/texk/web2c/mplibdir/mp.w"

{
set_number_from_substraction(dxin,q->x_coord,q->left_x);
set_number_from_substraction(dyin,q->y_coord,q->left_y);
if(number_zero(dxin)&&number_zero(dyin)){
set_number_from_substraction(dxin,q->x_coord,p->right_x);
set_number_from_substraction(dyin,q->y_coord,p->right_y);
if(number_zero(dxin)&&number_zero(dyin)){
set_number_from_substraction(dxin,q->x_coord,p->x_coord);
set_number_from_substraction(dyin,q->y_coord,p->y_coord);
if(p!=c){
number_add(dxin,w->x_coord);
number_add(dyin,w->y_coord);
}
}
}
pyth_add(tmp,dxin,dyin);
if(number_zero(tmp)){
join_type= 2;
}else{
mp_number r1;
new_fraction(r1);
make_fraction(r1,dxin,tmp);
number_clone(dxin,r1);
make_fraction(r1,dyin,tmp);
number_clone(dyin,r1);
free_number(r1);
/*606:*/
#line 15091 "../../../source/texk/web2c/mplibdir/mp.w"

{
set_number_from_substraction(dxout,q->right_x,q->x_coord);
set_number_from_substraction(dyout,q->right_y,q->y_coord);
if(number_zero(dxout)&&number_zero(dyout)){
r= mp_next_knot(q);
set_number_from_substraction(dxout,r->left_x,q->x_coord);
set_number_from_substraction(dyout,r->left_y,q->y_coord);
if(number_zero(dxout)&&number_zero(dyout)){
set_number_from_substraction(dxout,r->x_coord,q->x_coord);
set_number_from_substraction(dyout,r->y_coord,q->y_coord);
}
}
if(q==c){
number_substract(dxout,h->x_coord);
number_substract(dyout,h->y_coord);
}
pyth_add(tmp,dxout,dyout);
if(number_zero(tmp)){

;












}else{
mp_number r1;
new_fraction(r1);
make_fraction(r1,dxout,tmp);
number_clone(dxout,r1);
make_fraction(r1,dyout,tmp);
number_clone(dyout,r1);
free_number(r1);
}
}


/*:606*/
#line 15083 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}


/*:605*/
#line 14750 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(join_type==0){
/*591:*/
#line 14759 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,dxin,dxout);
take_fraction(r2,dyin,dyout);
number_add(r1,r2);
number_half(r1);
number_add(r1,fraction_half_t);
take_fraction(tmp,miterlim,r1);
if(number_less(tmp,unity_t)){
mp_number ret;
new_number(ret);
take_scaled(ret,miterlim,tmp);
if(number_less(ret,unity_t))
join_type= 2;
free_number(ret);
}
free_number(r1);
free_number(r2);
}


/*:591*/
#line 14753 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
}


/*:590*/
#line 14691 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
/*593:*/
#line 14789 "../../../source/texk/web2c/mplibdir/mp.w"

number_add(p->right_x,w->x_coord);
number_add(p->right_y,w->y_coord);
number_add(q->left_x,w->x_coord);
number_add(q->left_y,w->y_coord);
number_add(q->x_coord,w->x_coord);
number_add(q->y_coord,w->y_coord);
mp_left_type(q)= mp_explicit;
mp_right_type(q)= mp_explicit

/*:593*/
#line 14693 "../../../source/texk/web2c/mplibdir/mp.w"
;
while(k!=zero_off){
/*594:*/
#line 14799 "../../../source/texk/web2c/mplibdir/mp.w"

if(k> zero_off){
w= mp_next_knot(w);
decr(k);
}else{
w= mp_prev_knot(w);
incr(k);
}


/*:594*/
#line 14695 "../../../source/texk/web2c/mplibdir/mp.w"
;
if((join_type==1)||(k==zero_off)){
mp_number xtot,ytot;
new_number(xtot);
new_number(ytot);
set_number_from_addition(xtot,qx,w->x_coord);
set_number_from_addition(ytot,qy,w->y_coord);
q= mp_insert_knot(mp,q,xtot,ytot);
free_number(xtot);
free_number(ytot);
}
}
if(q!=mp_next_knot(p)){
/*597:*/
#line 14840 "../../../source/texk/web2c/mplibdir/mp.w"

{
p= mp_next_knot(p);
if((join_type==0)||(join_type==3)){
if(join_type==0){
/*598:*/
#line 14863 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number det;
mp_number absdet;
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
new_fraction(det);
new_fraction(absdet);
take_fraction(r1,dyout,dxin);
take_fraction(r2,dxout,dyin);
set_number_from_substraction(det,r1,r2);
number_clone(absdet,det);
number_abs(absdet);
if(number_less(absdet,near_zero_angle_k)){
r= NULL;
}else{
mp_number xtot,ytot,xsub,ysub;
new_fraction(xsub);
new_fraction(ysub);
new_number(xtot);
new_number(ytot);
set_number_from_substraction(tmp,q->x_coord,p->x_coord);
take_fraction(r1,tmp,dyout);
set_number_from_substraction(tmp,q->y_coord,p->y_coord);
take_fraction(r2,tmp,dxout);
set_number_from_substraction(tmp,r1,r2);
make_fraction(r1,tmp,det);
number_clone(tmp,r1);
take_fraction(xsub,tmp,dxin);
take_fraction(ysub,tmp,dyin);
set_number_from_addition(xtot,p->x_coord,xsub);
set_number_from_addition(ytot,p->y_coord,ysub);
r= mp_insert_knot(mp,p,xtot,ytot);
free_number(xtot);
free_number(ytot);
free_number(xsub);
free_number(ysub);
}
free_number(r1);
free_number(r2);
free_number(det);
free_number(absdet);
}


/*:598*/
#line 14845 "../../../source/texk/web2c/mplibdir/mp.w"

}else{
/*599:*/
#line 14909 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number ht_x,ht_y;
mp_number ht_x_abs,ht_y_abs;
mp_number xtot,ytot,xsub,ysub;
new_fraction(xsub);
new_fraction(ysub);
new_number(xtot);
new_number(ytot);
new_fraction(ht_x);
new_fraction(ht_y);
new_fraction(ht_x_abs);
new_fraction(ht_y_abs);
set_number_from_substraction(ht_x,w->y_coord,w0->y_coord);
set_number_from_substraction(ht_y,w0->x_coord,w->x_coord);
number_clone(ht_x_abs,ht_x);
number_clone(ht_y_abs,ht_y);
number_abs(ht_x_abs);
number_abs(ht_y_abs);
while(number_less(ht_x_abs,fraction_half_t)&&number_less(ht_y_abs,fraction_half_t)){
number_double(ht_x);
number_double(ht_y);
number_clone(ht_x_abs,ht_x);
number_clone(ht_y_abs,ht_y);
number_abs(ht_x_abs);
number_abs(ht_y_abs);
}
/*601:*/
#line 14990 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_to_zero(max_ht);
kk= zero_off;
ww= w;
while(1){
/*602:*/
#line 15015 "../../../source/texk/web2c/mplibdir/mp.w"

if(kk> k0){
ww= mp_next_knot(ww);
decr(kk);
}else{
ww= mp_prev_knot(ww);
incr(kk);
}


/*:602*/
#line 14995 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(kk==k0)
break;
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
set_number_from_substraction(tmp,ww->x_coord,w0->x_coord);
take_fraction(r1,tmp,ht_x);
set_number_from_substraction(tmp,ww->y_coord,w0->y_coord);
take_fraction(r2,tmp,ht_y);
set_number_from_addition(tmp,r1,r2);
free_number(r1);
free_number(r2);
}
if(number_greater(tmp,max_ht))
number_clone(max_ht,tmp);
}


/*:601*/
#line 14937 "../../../source/texk/web2c/mplibdir/mp.w"
;
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,dxin,ht_x);
take_fraction(r2,dyin,ht_y);
number_add(r1,r2);
make_fraction(tmp,max_ht,r1);
free_number(r1);
free_number(r2);
}
take_fraction(xsub,tmp,dxin);
take_fraction(ysub,tmp,dyin);
set_number_from_addition(xtot,p->x_coord,xsub);
set_number_from_addition(ytot,p->y_coord,ysub);
r= mp_insert_knot(mp,p,xtot,ytot);
assert(r);
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,dxout,ht_x);
take_fraction(r2,dyout,ht_y);
number_add(r1,r2);
make_fraction(tmp,max_ht,r1);
free_number(r1);
free_number(r2);
}
take_fraction(xsub,tmp,dxout);
take_fraction(ysub,tmp,dyout);
set_number_from_addition(xtot,q->x_coord,xsub);
set_number_from_addition(ytot,q->y_coord,ysub);
r= mp_insert_knot(mp,r,xtot,ytot);
free_number(xsub);
free_number(ysub);
free_number(xtot);
free_number(ytot);
free_number(ht_x);
free_number(ht_y);
free_number(ht_x_abs);
free_number(ht_y_abs);
}


/*:599*/
#line 14848 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
if(r!=NULL){
number_clone(r->right_x,r->x_coord);
number_clone(r->right_y,r->y_coord);
}
}
}


/*:597*/
#line 14709 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
p= q;
}while(q0!=c);
free_number(max_ht);
free_number(tmp);
free_number(qx);
free_number(qy);
free_number(dxin);
free_number(dyin);
free_number(dxout);
free_number(dyout);
return c;
}


/*:588*//*596:*/
#line 14816 "../../../source/texk/web2c/mplibdir/mp.w"

mp_knot mp_insert_knot(MP mp,mp_knot q,mp_number x,mp_number y){

mp_knot r;
r= mp_new_knot(mp);
mp_next_knot(r)= mp_next_knot(q);
mp_next_knot(q)= r;
number_clone(r->right_x,q->right_x);
number_clone(r->right_y,q->right_y);
number_clone(r->x_coord,x);
number_clone(r->y_coord,y);
number_clone(q->right_x,q->x_coord);
number_clone(q->right_y,q->y_coord);
number_clone(r->left_x,r->x_coord);
number_clone(r->left_y,r->y_coord);
mp_left_type(r)= mp_explicit;
mp_right_type(r)= mp_explicit;
mp_originator(r)= mp_program_code;
return r;
}


/*:596*//*608:*/
#line 15158 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_find_direction_time(MP mp,mp_number*ret,mp_number x_orig,mp_number y_orig,mp_knot h){
mp_number max;
mp_knot p,q;
mp_number n;
mp_number tt;
mp_number x,y;
mp_number abs_x,abs_y;

mp_number x1,x2,x3,y1,y2,y3;
mp_number phi;
mp_number t;
mp_number ab_vs_cd;
new_number(max);
new_number(x1);
new_number(x2);
new_number(x3);
new_number(y1);
new_number(y2);
new_number(y3);
new_fraction(t);
new_angle(phi);
new_number(ab_vs_cd);
set_number_to_zero(*ret);
new_number(x);
new_number(y);
new_number(abs_x);
new_number(abs_y);
new_number(n);
new_fraction(tt);
number_clone(x,x_orig);
number_clone(y,y_orig);
number_clone(abs_x,x_orig);
number_clone(abs_y,y_orig);
number_abs(abs_x);
number_abs(abs_y);


if(number_less(abs_x,abs_y)){
mp_number r1;
new_fraction(r1);
make_fraction(r1,x,abs_y);
number_clone(x,r1);
free_number(r1);
if(number_positive(y)){
number_clone(y,fraction_one_t);
}else{
number_clone(y,fraction_one_t);
number_negate(y);
}
}else if(number_zero(x)){
goto FREE;
}else{
mp_number r1;
new_fraction(r1);
make_fraction(r1,y,abs_x);
number_clone(y,r1);
free_number(r1);
if(number_positive(x)){
number_clone(x,fraction_one_t);
}else{
number_clone(x,fraction_one_t);
number_negate(x);
}
}

p= h;
while(1){
if(mp_right_type(p)==mp_endpoint)
break;
q= mp_next_knot(p);
/*609:*/
#line 15281 "../../../source/texk/web2c/mplibdir/mp.w"

set_number_to_zero(tt);


{
mp_number absval;
new_number(absval);
set_number_from_substraction(x1,p->right_x,p->x_coord);
set_number_from_substraction(x2,q->left_x,p->right_x);
set_number_from_substraction(x3,q->x_coord,q->left_x);
set_number_from_substraction(y1,p->right_y,p->y_coord);
set_number_from_substraction(y2,q->left_y,p->right_y);
set_number_from_substraction(y3,q->y_coord,q->left_y);
number_clone(absval,x2);
number_abs(absval);
number_clone(max,x1);
number_abs(max);
if(number_greater(absval,max)){
number_clone(max,absval);
}
number_clone(absval,x3);
number_abs(absval);
if(number_greater(absval,max)){
number_clone(max,absval);
}
number_clone(absval,y1);
number_abs(absval);
if(number_greater(absval,max)){
number_clone(max,absval);
}
number_clone(absval,y2);
number_abs(absval);
if(number_greater(absval,max)){
number_clone(max,absval);
}
number_clone(absval,y3);
number_abs(absval);
if(number_greater(absval,max)){
number_clone(max,absval);
}
free_number(absval);
if(number_zero(max))
goto FOUND;
while(number_less(max,fraction_half_t)){
number_double(max);
number_double(x1);
number_double(x2);
number_double(x3);
number_double(y1);
number_double(y2);
number_double(y3);
}
number_clone(t,x1);
{
mp_number r1,r2;
new_fraction(r1);
new_fraction(r2);
take_fraction(r1,x1,x);
take_fraction(r2,y1,y);
set_number_from_addition(x1,r1,r2);
take_fraction(r1,y1,x);
take_fraction(r2,t,y);
set_number_from_substraction(y1,r1,r2);
number_clone(t,x2);
take_fraction(r1,x2,x);
take_fraction(r2,y2,y);
set_number_from_addition(x2,r1,r2);
take_fraction(r1,y2,x);
take_fraction(r2,t,y);
set_number_from_substraction(y2,r1,r2);
number_clone(t,x3);
take_fraction(r1,x3,x);
take_fraction(r2,y3,y);
set_number_from_addition(x3,r1,r2);
take_fraction(r1,y3,x);
take_fraction(r2,t,y);
set_number_from_substraction(y3,r1,r2);
free_number(r1);
free_number(r2);
}
}
if(number_zero(y1))
if(number_zero(x1)||number_positive(x1))
goto FOUND;
if(number_positive(n)){

mp_number theta;
mp_number tmp;
new_angle(theta);
n_arg(theta,x1,y1);
new_angle(tmp);
set_number_from_substraction(tmp,theta,one_eighty_deg_t);

if(number_nonnegative(theta)&&number_nonpositive(phi)&&number_greaterequal(phi,tmp)){
free_number(tmp);
free_number(theta);
goto FOUND;
}
set_number_from_addition(tmp,theta,one_eighty_deg_t);
if(number_nonpositive(theta)&&number_nonnegative(phi)&&number_lessequal(phi,tmp)){
free_number(tmp);
free_number(theta);
goto FOUND;
}
free_number(tmp);
free_number(theta);

if(p==h)
break;
}
if(number_nonzero(x3)||number_nonzero(y3)){
n_arg(phi,x3,y3);
}











if(number_negative(x1))
if(number_negative(x2))
if(number_negative(x3))
goto DONE;
{
ab_vs_cd(ab_vs_cd,y1,y3,y2,y2);
if(number_zero(ab_vs_cd)){


{
ab_vs_cd(ab_vs_cd,y1,y2,zero_t,zero_t);
if(number_negative(ab_vs_cd)){
mp_number tmp,arg2;
new_number(tmp);
new_number(arg2);
set_number_from_substraction(arg2,y1,y2);
make_fraction(t,y1,arg2);
free_number(arg2);
set_number_from_of_the_way(x1,t,x1,x2);
set_number_from_of_the_way(x2,t,x2,x3);
set_number_from_of_the_way(tmp,t,x1,x2);
if(number_zero(tmp)||number_positive(tmp)){
free_number(tmp);
we_found_it;
}
free_number(tmp);
}else if(number_zero(y3)){
if(number_zero(y1)){




{
mp_number arg1,arg2,arg3;
new_number(arg1);
new_number(arg2);
new_number(arg3);
number_clone(arg1,x1);
number_negate(arg1);
number_clone(arg2,x2);
number_negate(arg2);
number_clone(arg3,x3);
number_negate(arg3);
crossing_point(t,arg1,arg2,arg3);
free_number(arg1);
free_number(arg2);
free_number(arg3);
if(number_lessequal(t,fraction_one_t))
we_found_it;
ab_vs_cd(ab_vs_cd,x1,x3,x2,x2);
if(number_nonpositive(ab_vs_cd)){
mp_number arg2;
new_number(arg2);
set_number_from_substraction(arg2,x1,x2);
make_fraction(t,x1,arg2);
free_number(arg2);
we_found_it;
}
}



}else if(number_zero(x3)||number_positive(x3)){
set_number_to_unity(tt);
goto FOUND;
}
}
goto DONE;
}


}
}
if(number_zero(y1)||number_negative(y1)){
if(number_negative(y1)){
number_negate(y1);
number_negate(y2);
number_negate(y3);
}else if(number_positive(y2)){
number_negate(y2);
number_negate(y3);
}
}












crossing_point(t,y1,y2,y3);
if(number_greater(t,fraction_one_t))
goto DONE;
set_number_from_of_the_way(y2,t,y2,y3);
set_number_from_of_the_way(x1,t,x1,x2);
set_number_from_of_the_way(x2,t,x2,x3);
set_number_from_of_the_way(x1,t,x1,x2);
if(number_zero(x1)||number_positive(x1))
we_found_it;
if(number_positive(y2))
set_number_to_zero(y2);
number_clone(tt,t);
{
mp_number arg1,arg2,arg3;
new_number(arg1);
new_number(arg2);
new_number(arg3);
number_clone(arg2,y2);
number_negate(arg2);
number_clone(arg3,y3);
number_negate(arg3);
crossing_point(t,arg1,arg2,arg3);
free_number(arg1);
free_number(arg2);
free_number(arg3);
}
if(number_greater(t,fraction_one_t))
goto DONE;
{
mp_number tmp;
new_number(tmp);
set_number_from_of_the_way(x1,t,x1,x2);
set_number_from_of_the_way(x2,t,x2,x3);
set_number_from_of_the_way(tmp,t,x1,x2);
if(number_nonnegative(tmp)){
free_number(tmp);
set_number_from_of_the_way(t,t,tt,fraction_one_t);
we_found_it;
}
free_number(tmp);
}
DONE:


/*:609*/
#line 15231 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= q;
number_add(n,unity_t);
}
set_number_to_unity(*ret);
number_negate(*ret);
goto FREE;
FOUND:
set_number_from_addition(*ret,n,tt);
goto FREE;
FREE:
free_number(x);
free_number(y);
free_number(abs_x);
free_number(abs_y);

free_number(x1);
free_number(x2);
free_number(x3);
free_number(y1);
free_number(y2);
free_number(y3);
free_number(t);
free_number(phi);
free_number(ab_vs_cd);

free_number(n);
free_number(max);
free_number(tt);
}



/*:608*//*621:*/
#line 15797 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_cubic_intersection(MP mp,mp_knot p,mp_knot pp){
mp_knot q,qq;
mp_number x_two_t;
mp_number x_two_t_low_precision;
mp->time_to_go= max_patience;
set_number_from_scaled(mp->max_t,2);
new_number(x_two_t);
new_number(x_two_t_low_precision);

number_clone(x_two_t,two_t);
number_double(x_two_t);number_double(x_two_t);
set_number_from_double(x_two_t_low_precision,-0.5);
number_add(x_two_t_low_precision,x_two_t);

/*625:*/
#line 15954 "../../../source/texk/web2c/mplibdir/mp.w"

q= mp_next_knot(p);
qq= mp_next_knot(pp);
mp->bisect_ptr= int_packets;
set_number_from_substraction(u1r,p->right_x,p->x_coord);
set_number_from_substraction(u2r,q->left_x,p->right_x);
set_number_from_substraction(u3r,q->x_coord,q->left_x);
set_min_max(ur_packet);
set_number_from_substraction(v1r,p->right_y,p->y_coord);
set_number_from_substraction(v2r,q->left_y,p->right_y);
set_number_from_substraction(v3r,q->y_coord,q->left_y);
set_min_max(vr_packet);
set_number_from_substraction(x1r,pp->right_x,pp->x_coord);
set_number_from_substraction(x2r,qq->left_x,pp->right_x);
set_number_from_substraction(x3r,qq->x_coord,qq->left_x);
set_min_max(xr_packet);
set_number_from_substraction(y1r,pp->right_y,pp->y_coord);
set_number_from_substraction(y2r,qq->left_y,pp->right_y);
set_number_from_substraction(y3r,qq->y_coord,qq->left_y);
set_min_max(yr_packet);
set_number_from_substraction(mp->delx,p->x_coord,pp->x_coord);
set_number_from_substraction(mp->dely,p->y_coord,pp->y_coord);
mp->tol= 0;
mp->uv= r_packets;
mp->xy= r_packets;
mp->three_l= 0;
set_number_from_scaled(mp->cur_t,1);
set_number_from_scaled(mp->cur_tt,1)

/*:625*/
#line 15812 "../../../source/texk/web2c/mplibdir/mp.w"
;
CONTINUE:
while(1){



if(((x_packet(mp->xy))+4)> bistack_size||
((u_packet(mp->uv))+4)> bistack_size||
((y_packet(mp->xy))+4)> bistack_size||
((v_packet(mp->uv))+4)> bistack_size){
set_number_from_scaled(mp->cur_t,1);
set_number_from_scaled(mp->cur_tt,1);
goto NOT_FOUND;
}




if(number_greater(mp->max_t,x_two_t)){
set_number_from_scaled(mp->cur_t,1);
set_number_from_scaled(mp->cur_tt,1);
goto NOT_FOUND;
}

if(number_to_scaled(mp->delx)-mp->tol<=
number_to_scaled(stack_max(x_packet(mp->xy)))-number_to_scaled(stack_min(u_packet(mp->uv))))
if(number_to_scaled(mp->delx)+mp->tol>=
number_to_scaled(stack_min(x_packet(mp->xy)))-number_to_scaled(stack_max(u_packet(mp->uv))))
if(number_to_scaled(mp->dely)-mp->tol<=
number_to_scaled(stack_max(y_packet(mp->xy)))-number_to_scaled(stack_min(v_packet(mp->uv))))
if(number_to_scaled(mp->dely)+mp->tol>=
number_to_scaled(stack_min(y_packet(mp->xy)))-number_to_scaled(stack_max(v_packet(mp->uv)))){
if(number_to_scaled(mp->cur_t)>=number_to_scaled(mp->max_t)){
if(number_equal(mp->max_t,x_two_t)||number_greater(mp->max_t,x_two_t_low_precision)){
number_divide_int(mp->cur_t,1<<2);number_divide_int(mp->cur_tt,1<<2);
set_number_from_scaled(mp->cur_t,((number_to_scaled(mp->cur_t)+1)/2));
set_number_from_scaled(mp->cur_tt,((number_to_scaled(mp->cur_tt)+1)/2));
return;
}
number_double(mp->max_t);
number_clone(mp->appr_t,mp->cur_t);
number_clone(mp->appr_tt,mp->cur_tt);
}
/*626:*/
#line 15985 "../../../source/texk/web2c/mplibdir/mp.w"

number_clone(stack_dx,mp->delx);
number_clone(stack_dy,mp->dely);
set_number_from_scaled(stack_tol,mp->tol);
set_number_from_scaled(stack_uv,mp->uv);
set_number_from_scaled(stack_xy,mp->xy);
mp->bisect_ptr= mp->bisect_ptr+int_increment;
number_double(mp->cur_t);
number_double(mp->cur_tt);
number_clone(u1l,stack_1(u_packet(mp->uv)));
number_clone(u3r,stack_3(u_packet(mp->uv)));
set_number_from_addition(u2l,u1l,stack_2(u_packet(mp->uv)));number_half(u2l);
set_number_from_addition(u2r,u3r,stack_2(u_packet(mp->uv)));number_half(u2r);
set_number_from_addition(u3l,u2l,u2r);number_half(u3l);
number_clone(u1r,u3l);
set_min_max(ul_packet);
set_min_max(ur_packet);
number_clone(v1l,stack_1(v_packet(mp->uv)));
number_clone(v3r,stack_3(v_packet(mp->uv)));
set_number_from_addition(v2l,v1l,stack_2(v_packet(mp->uv)));number_half(v2l);
set_number_from_addition(v2r,v3r,stack_2(v_packet(mp->uv)));number_half(v2r);
set_number_from_addition(v3l,v2l,v2r);number_half(v3l);
number_clone(v1r,v3l);
set_min_max(vl_packet);
set_min_max(vr_packet);
number_clone(x1l,stack_1(x_packet(mp->xy)));
number_clone(x3r,stack_3(x_packet(mp->xy)));
set_number_from_addition(x2l,x1l,stack_2(x_packet(mp->xy)));number_half(x2l);
set_number_from_addition(x2r,x3r,stack_2(x_packet(mp->xy)));number_half(x2r);
set_number_from_addition(x3l,x2l,x2r);number_half(x3l);
number_clone(x1r,x3l);
set_min_max(xl_packet);
set_min_max(xr_packet);
number_clone(y1l,stack_1(y_packet(mp->xy)));
number_clone(y3r,stack_3(y_packet(mp->xy)));
set_number_from_addition(y2l,y1l,stack_2(y_packet(mp->xy)));number_half(y2l);
set_number_from_addition(y2r,y3r,stack_2(y_packet(mp->xy)));number_half(y2r);
set_number_from_addition(y3l,y2l,y2r);number_half(y3l);
number_clone(y1r,y3l);
set_min_max(yl_packet);
set_min_max(yr_packet);
mp->uv= l_packets;
mp->xy= l_packets;
number_double(mp->delx);
number_double(mp->dely);
mp->tol= mp->tol-mp->three_l+(integer)mp->tol_step;
mp->tol+= mp->tol;
mp->three_l= mp->three_l+(integer)mp->tol_step

/*:626*/
#line 15855 "../../../source/texk/web2c/mplibdir/mp.w"
;
goto CONTINUE;
}
if(mp->time_to_go> 0){
decr(mp->time_to_go);
}else{

number_divide_int(mp->appr_t,1<<2);number_divide_int(mp->appr_tt,1<<2);
while(number_less(mp->appr_t,unity_t)){
number_double(mp->appr_t);
number_double(mp->appr_tt);
}
number_clone(mp->cur_t,mp->appr_t);
number_clone(mp->cur_tt,mp->appr_tt);
return;
}
NOT_FOUND:

if(odd(number_to_scaled(mp->cur_tt))){
if(odd(number_to_scaled(mp->cur_t))){

{
set_number_from_scaled(mp->cur_t,half(number_to_scaled(mp->cur_t)));
set_number_from_scaled(mp->cur_tt,half(number_to_scaled(mp->cur_tt)));
if(number_to_scaled(mp->cur_t)==0)
return;
mp->bisect_ptr-= int_increment;
mp->three_l-= (integer)mp->tol_step;
number_clone(mp->delx,stack_dx);
number_clone(mp->dely,stack_dy);
mp->tol= number_to_scaled(stack_tol);
mp->uv= number_to_scaled(stack_uv);
mp->xy= number_to_scaled(stack_xy);
goto NOT_FOUND;
}

}else{
set_number_from_scaled(mp->cur_t,number_to_scaled(mp->cur_t)+1);
number_add(mp->delx,stack_1(u_packet(mp->uv)));
number_add(mp->delx,stack_2(u_packet(mp->uv)));
number_add(mp->delx,stack_3(u_packet(mp->uv)));
number_add(mp->dely,stack_1(v_packet(mp->uv)));
number_add(mp->dely,stack_2(v_packet(mp->uv)));
number_add(mp->dely,stack_3(v_packet(mp->uv)));
mp->uv= mp->uv+int_packets;
set_number_from_scaled(mp->cur_tt,number_to_scaled(mp->cur_tt)-1);
mp->xy= mp->xy-int_packets;
number_add(mp->delx,stack_1(x_packet(mp->xy)));
number_add(mp->delx,stack_2(x_packet(mp->xy)));
number_add(mp->delx,stack_3(x_packet(mp->xy)));
number_add(mp->dely,stack_1(y_packet(mp->xy)));
number_add(mp->dely,stack_2(y_packet(mp->xy)));
number_add(mp->dely,stack_3(y_packet(mp->xy)));
}
}else{
set_number_from_scaled(mp->cur_tt,number_to_scaled(mp->cur_tt)+1);
mp->tol= mp->tol+mp->three_l;
number_substract(mp->delx,stack_1(x_packet(mp->xy)));
number_substract(mp->delx,stack_2(x_packet(mp->xy)));
number_substract(mp->delx,stack_3(x_packet(mp->xy)));
number_substract(mp->dely,stack_1(y_packet(mp->xy)));
number_substract(mp->dely,stack_2(y_packet(mp->xy)));
number_substract(mp->dely,stack_3(y_packet(mp->xy)));
mp->xy= mp->xy+int_packets;
}
}
}


/*:621*//*627:*/
#line 16039 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_path_intersection(MP mp,mp_knot h,mp_knot hh){
mp_knot p,pp;
mp_number n,nn;
/*628:*/
#line 16084 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp_right_type(h)==mp_endpoint){
number_clone(h->right_x,h->x_coord);
number_clone(h->left_x,h->x_coord);
number_clone(h->right_y,h->y_coord);
number_clone(h->left_y,h->y_coord);
mp_right_type(h)= mp_explicit;
}
if(mp_right_type(hh)==mp_endpoint){
number_clone(hh->right_x,hh->x_coord);
number_clone(hh->left_x,hh->x_coord);
number_clone(hh->right_y,hh->y_coord);
number_clone(hh->left_y,hh->y_coord);
mp_right_type(hh)= mp_explicit;
}

/*:628*/
#line 16043 "../../../source/texk/web2c/mplibdir/mp.w"
;
new_number(n);
new_number(nn);
mp->tol_step= 0;
do{
set_number_to_unity(n);
number_negate(n);
p= h;
do{
if(mp_right_type(p)!=mp_endpoint){
set_number_to_unity(nn);
number_negate(nn);
pp= hh;
do{
if(mp_right_type(pp)!=mp_endpoint){
mp_cubic_intersection(mp,p,pp);
if(number_positive(mp->cur_t)){
number_add(mp->cur_t,n);
number_add(mp->cur_tt,nn);
goto DONE;
}
}
number_add(nn,unity_t);
pp= mp_next_knot(pp);
}while(pp!=hh);
}
number_add(n,unity_t);
p= mp_next_knot(p);
}while(p!=h);
mp->tol_step= mp->tol_step+3;
}while(mp->tol_step<=3);
number_clone(mp->cur_t,unity_t);
number_negate(mp->cur_t);
number_clone(mp->cur_tt,unity_t);
number_negate(mp->cur_tt);
DONE:
free_number(n);
free_number(nn);
}


/*:627*//*629:*/
#line 16149 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_new_indep(MP mp,mp_node p){
if(mp->serial_no>=max_integer){
mp_fatal_error(mp,"variable instance identifiers exhausted");
}
mp_type(p)= mp_independent;
mp->serial_no= mp->serial_no+1;
set_indep_scale(p,0);
set_indep_value(p,mp->serial_no);
}

/*:629*//*632:*/
#line 16218 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node get_dep_info(MP mp,mp_value_node p){
mp_node d;
d= p->parent_;
FUNCTION_TRACE3("%p = dep_info(%p)\n",d,p);
return d;
}
static void do_set_dep_value(MP mp,mp_value_node p,mp_number q){
number_clone(p->data.n,q);
FUNCTION_TRACE3("set_dep_value(%p,%d)\n",p,q);
p->attr_head_= NULL;
p->subscr_head_= NULL;
}

/*:632*//*634:*/
#line 16237 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_get_dep_node(MP mp){
mp_value_node p= (mp_value_node)mp_get_value_node(mp);
mp_type(p)= mp_dep_node_type;
return p;
}
static void mp_free_dep_node(MP mp,mp_value_node p){
mp_free_value_node(mp,(mp_node)p);
}


/*:634*//*640:*/
#line 16276 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_dependency(MP mp,mp_value_node p,quarterword t){
mp_number v;
mp_value_node pp;
mp_node q;
pp= p;
new_number(v);
while(true){
number_clone(v,dep_value(p));
number_abs(v);
q= dep_info(p);
if(q==NULL){
if(number_nonzero(v)||(p==pp)){
if(number_positive(dep_value(p)))
if(p!=pp)
mp_print_char(mp,xord('+'));
print_number(dep_value(p));
}
return;
}

if(number_negative(dep_value(p)))
mp_print_char(mp,xord('-'));
else if(p!=pp)
mp_print_char(mp,xord('+'));
if(t==mp_dependent){
fraction_to_round_scaled(v);
}
if(!number_equal(v,unity_t))
print_number(v);

if(mp_type(q)!=mp_independent)
mp_confusion(mp,"dep");
mp_print_variable_name(mp,q);
set_number_from_scaled(v,indep_scale(q));
while(number_positive(v)){
mp_print(mp,"*4");
number_add_scaled(v,-2);
}
p= (mp_value_node)mp_link(p);
}
}



/*:640*//*641:*/
#line 16324 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_max_coef(MP mp,mp_number*x,mp_value_node p){
mp_number(absv);
new_number(absv);
set_number_to_zero(*x);
while(dep_info(p)!=NULL){
number_clone(absv,dep_value(p));
number_abs(absv);
if(number_greater(absv,*x)){
number_clone(*x,absv);
}
p= (mp_value_node)mp_link(p);
}
free_number(absv);
}


/*:641*//*645:*/
#line 16401 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_p_plus_fq(MP mp,mp_value_node p,mp_number f,
mp_value_node q,mp_variable_type t,
mp_variable_type tt){
mp_node pp,qq;
mp_value_node r,s;
mp_number threshold,half_threshold;
mp_number v,vv;
new_number(v);
new_number(vv);
new_number(threshold);
new_number(half_threshold);
if(t==mp_dependent){
number_clone(threshold,fraction_threshold_k);
number_clone(half_threshold,half_fraction_threshold_k);
}else{
number_clone(threshold,scaled_threshold_k);
number_clone(half_threshold,half_scaled_threshold_k);
}
r= (mp_value_node)mp->temp_head;
pp= dep_info(p);
qq= dep_info(q);
while(1){
if(pp==qq){
if(pp==NULL){
break;
}else{


mp_number r1;
mp_number absv;
new_fraction(r1);
new_number(absv);
if(tt==mp_dependent){
take_fraction(r1,f,dep_value(q));
}else{
take_scaled(r1,f,dep_value(q));
}
set_number_from_addition(v,dep_value(p),r1);
free_number(r1);
set_dep_value(p,v);
s= p;
p= (mp_value_node)mp_link(p);
number_clone(absv,v);
number_abs(absv);
if(number_less(absv,threshold)){
mp_free_dep_node(mp,s);
}else{
if(number_greaterequal(absv,coef_bound_k)&&mp->watch_coefs){
mp_type(qq)= independent_needing_fix;


mp->fix_needed= true;
}
set_mp_link(r,(mp_node)s);
r= s;
}
free_number(absv);
pp= dep_info(p);
q= (mp_value_node)mp_link(q);
qq= dep_info(q);
}

}else{
if(pp==NULL)
set_number_to_neg_inf(v);
else if(mp_type(pp)==mp_independent||(mp_type(pp)==independent_needing_fix&&mp->fix_needed))
set_number_from_scaled(v,indep_value(pp));
else
number_clone(v,value_number(pp));
if(qq==NULL)
set_number_to_neg_inf(vv);
else if(mp_type(qq)==mp_independent||(mp_type(qq)==independent_needing_fix&&mp->fix_needed))
set_number_from_scaled(vv,indep_value(qq));
else
number_clone(vv,value_number(qq));
if(number_less(v,vv)){

mp_number absv;
new_number(absv);
{
mp_number r1;
mp_number arg1,arg2;
new_fraction(r1);
new_number(arg1);
new_number(arg2);
number_clone(arg1,f);
number_clone(arg2,dep_value(q));
if(tt==mp_dependent){
take_fraction(r1,arg1,arg2);
}else{
take_scaled(r1,arg1,arg2);
}
number_clone(v,r1);
free_number(r1);
free_number(arg1);
free_number(arg2);
}
number_clone(absv,v);
number_abs(absv);
if(number_greater(absv,half_threshold)){
s= mp_get_dep_node(mp);
set_dep_info(s,qq);
set_dep_value(s,v);
if(number_greaterequal(absv,coef_bound_k)&&mp->watch_coefs){
assert(qq);
mp_type(qq)= independent_needing_fix;
mp->fix_needed= true;
}
set_mp_link(r,(mp_node)s);
r= s;
}
q= (mp_value_node)mp_link(q);
qq= dep_info(q);
free_number(absv);

}else{
set_mp_link(r,(mp_node)p);
r= p;
p= (mp_value_node)mp_link(p);
pp= dep_info(p);
}
}
}
{
mp_number r1;
mp_number arg1,arg2;
new_fraction(r1);
new_number(arg1);
new_number(arg2);
number_clone(arg1,dep_value(q));
number_clone(arg2,f);
if(t==mp_dependent){
take_fraction(r1,arg1,arg2);
}else{
take_scaled(r1,arg1,arg2);
}
slow_add(arg1,dep_value(p),r1);
set_dep_value(p,arg1);
free_number(r1);
free_number(arg1);
free_number(arg2);
}
set_mp_link(r,(mp_node)p);
mp->dep_final= p;
free_number(threshold);
free_number(half_threshold);
free_number(v);
free_number(vv);
return(mp_value_node)mp_link(mp->temp_head);
}


/*:645*//*646:*/
#line 16558 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_p_plus_q(MP mp,mp_value_node p,mp_value_node q,
mp_variable_type t){
mp_node pp,qq;
mp_value_node s;
mp_value_node r;
mp_number threshold;
mp_number v,vv;
new_number(v);
new_number(vv);
new_number(threshold);
if(t==mp_dependent)
number_clone(threshold,fraction_threshold_k);
else
number_clone(threshold,scaled_threshold_k);
r= (mp_value_node)mp->temp_head;
pp= dep_info(p);
qq= dep_info(q);
while(1){
if(pp==qq){
if(pp==NULL){
break;
}else{

mp_number test;
new_number(test);
set_number_from_addition(v,dep_value(p),dep_value(q));
set_dep_value(p,v);
s= p;
p= (mp_value_node)mp_link(p);
pp= dep_info(p);
number_clone(test,v);
number_abs(test);
if(number_less(test,threshold)){
mp_free_dep_node(mp,s);
}else{
if(number_greaterequal(test,coef_bound_k)&&mp->watch_coefs){
mp_type(qq)= independent_needing_fix;


mp->fix_needed= true;
}
set_mp_link(r,(mp_node)s);
r= s;
}
free_number(test);
q= (mp_value_node)mp_link(q);
qq= dep_info(q);
}

}else{
if(pp==NULL)
set_number_to_zero(v);
else if(mp_type(pp)==mp_independent||(mp_type(pp)==independent_needing_fix&&mp->fix_needed))
set_number_from_scaled(v,indep_value(pp));
else
number_clone(v,value_number(pp));
if(qq==NULL)
set_number_to_zero(vv);
else if(mp_type(qq)==mp_independent||(mp_type(qq)==independent_needing_fix&&mp->fix_needed))
set_number_from_scaled(vv,indep_value(qq));
else
number_clone(vv,value_number(qq));
if(number_less(v,vv)){
s= mp_get_dep_node(mp);
set_dep_info(s,qq);
set_dep_value(s,dep_value(q));
q= (mp_value_node)mp_link(q);
qq= dep_info(q);
set_mp_link(r,(mp_node)s);
r= s;
}else{
set_mp_link(r,(mp_node)p);
r= p;
p= (mp_value_node)mp_link(p);
pp= dep_info(p);
}
}
}
{
mp_number r1;
new_number(r1);
slow_add(r1,dep_value(p),dep_value(q));
set_dep_value(p,r1);
free_number(r1);
}
set_mp_link(r,(mp_node)p);
mp->dep_final= p;
free_number(v);
free_number(vv);
free_number(threshold);
return(mp_value_node)mp_link(mp->temp_head);
}

/*:646*//*647:*/
#line 16660 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_p_times_v(MP mp,mp_value_node p,mp_number v,
quarterword t0,quarterword t1,
boolean v_is_scaled){
mp_value_node r,s;
mp_number w;
mp_number threshold;
boolean scaling_down;
new_number(threshold);
new_number(w);
if(t0!=t1)
scaling_down= true;
else
scaling_down= (!v_is_scaled);
if(t1==mp_dependent)
number_clone(threshold,half_fraction_threshold_k);
else
number_clone(threshold,half_scaled_threshold_k);
r= (mp_value_node)mp->temp_head;
while(dep_info(p)!=NULL){
mp_number test;
new_number(test);
if(scaling_down){
take_fraction(w,v,dep_value(p));
}else{
take_scaled(w,v,dep_value(p));
}
number_clone(test,w);
number_abs(test);
if(number_lessequal(test,threshold)){
s= (mp_value_node)mp_link(p);
mp_free_dep_node(mp,p);
p= s;
}else{
if(number_greaterequal(test,coef_bound_k)){
mp->fix_needed= true;
mp_type(dep_info(p))= independent_needing_fix;
}
set_mp_link(r,(mp_node)p);
r= p;
set_dep_value(p,w);
p= (mp_value_node)mp_link(p);
}
free_number(test);
}
set_mp_link(r,(mp_node)p);
{
mp_number r1;
new_number(r1);
if(v_is_scaled){
take_scaled(r1,dep_value(p),v);
}else{
take_fraction(r1,dep_value(p),v);
}
set_dep_value(p,r1);
free_number(r1);
}
free_number(w);
free_number(threshold);
return(mp_value_node)mp_link(mp->temp_head);
}


/*:647*//*649:*/
#line 16733 "../../../source/texk/web2c/mplibdir/mp.w"

mp_value_node mp_p_over_v(MP mp,mp_value_node p,mp_number v_orig,quarterword
t0,quarterword t1){
mp_value_node r,s;
mp_number w;
mp_number threshold;
mp_number v;
boolean scaling_down;
new_number(v);
new_number(w);
new_number(threshold);
number_clone(v,v_orig);
if(t0!=t1)
scaling_down= true;
else
scaling_down= false;
if(t1==mp_dependent)
number_clone(threshold,half_fraction_threshold_k);
else
number_clone(threshold,half_scaled_threshold_k);
r= (mp_value_node)mp->temp_head;
while(dep_info(p)!=NULL){
if(scaling_down){
mp_number x,absv;
new_number(x);
new_number(absv);
number_clone(absv,v);
number_abs(absv);
if(number_less(absv,p_over_v_threshold_k)){
number_clone(x,v);
convert_scaled_to_fraction(x);
make_scaled(w,dep_value(p),x);
}else{
number_clone(x,dep_value(p));
fraction_to_round_scaled(x);
make_scaled(w,x,v);
}
free_number(x);
free_number(absv);
}else{
make_scaled(w,dep_value(p),v);
}
{
mp_number test;
new_number(test);
number_clone(test,w);
number_abs(test);
if(number_lessequal(test,threshold)){
s= (mp_value_node)mp_link(p);
mp_free_dep_node(mp,p);
p= s;
}else{
if(number_greaterequal(test,coef_bound_k)){
mp->fix_needed= true;
mp_type(dep_info(p))= independent_needing_fix;
}
set_mp_link(r,(mp_node)p);
r= p;
set_dep_value(p,w);
p= (mp_value_node)mp_link(p);
}
free_number(test);
}
}
set_mp_link(r,(mp_node)p);
{
mp_number ret;
new_number(ret);
make_scaled(ret,dep_value(p),v);
set_dep_value(p,ret);
free_number(ret);
}
free_number(v);
free_number(w);
free_number(threshold);
return(mp_value_node)mp_link(mp->temp_head);
}


/*:649*//*650:*/
#line 16823 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_p_with_x_becoming_q(MP mp,mp_value_node p,
mp_node x,mp_node q,
quarterword t){
mp_value_node r,s;
integer sx;
s= p;
r= (mp_value_node)mp->temp_head;
sx= indep_value(x);
while(dep_info(s)!=NULL&&indep_value(dep_info(s))> sx){
r= s;
s= (mp_value_node)mp_link(s);
}
if(dep_info(s)==NULL||dep_info(s)!=x){
return p;
}else{
mp_value_node ret;
mp_number v1;
new_number(v1);
set_mp_link(mp->temp_head,(mp_node)p);
set_mp_link(r,mp_link(s));
number_clone(v1,dep_value(s));
mp_free_dep_node(mp,s);
ret= mp_p_plus_fq(mp,(mp_value_node)mp_link(mp->temp_head),v1,
(mp_value_node)q,t,mp_dependent);
free_number(v1);
return ret;
}
}


/*:650*//*652:*/
#line 16860 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_val_too_big(MP mp,mp_number x){
if(number_positive(internal_value(mp_warning_check))){
char msg[256];
const char*hlp[]= {
"The equation I just processed has given some variable a",
"value outside of the safetyp range. Continue and I'll try",
"to cope with that big value; but it might be dangerous.",
"(Set warningcheck:=0 to suppress this message.)",
NULL};
mp_snprintf(msg,256,"Value is too large (%s)",number_tostring(x));
mp_error(mp,msg,hlp,true);
}
}

/*:652*//*654:*/
#line 16882 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_make_known(MP mp,mp_value_node p,mp_value_node q){
mp_variable_type t;
mp_number absp;
new_number(absp);
set_prev_dep(mp_link(q),prev_dep(p));
set_mp_link(prev_dep(p),mp_link(q));
t= mp_type(p);
mp_type(p)= mp_known;
set_value_number(p,dep_value(q));
mp_free_dep_node(mp,q);
number_clone(absp,value_number(p));
number_abs(absp);
if(number_greaterequal(absp,warning_limit_t))
mp_val_too_big(mp,value_number(p));
if((number_positive(internal_value(mp_tracing_equations)))
&&mp_interesting(mp,(mp_node)p)){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"#### ");
mp_print_variable_name(mp,(mp_node)p);
mp_print_char(mp,xord('='));
print_number(value_number(p));
mp_end_diagnostic(mp,false);
}
if(cur_exp_node()==(mp_node)p&&mp->cur_exp.type==t){
mp->cur_exp.type= mp_known;
set_cur_exp_value_number(value_number(p));
mp_free_value_node(mp,(mp_node)p);
}
free_number(absp);
}


/*:654*//*656:*/
#line 16927 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fix_dependencies(MP mp){
mp_value_node p,q,r,s,t;
mp_node x;
r= (mp_value_node)mp_link(mp->dep_head);
s= NULL;
while(r!=mp->dep_head){
t= r;


while(1){
if(t==r){
q= (mp_value_node)dep_list(t);
}else{
q= (mp_value_node)mp_link(r);
}
x= dep_info(q);
if(x==NULL)
break;
if(mp_type(x)<=independent_being_fixed){
if(mp_type(x)<independent_being_fixed){
p= mp_get_dep_node(mp);
set_mp_link(p,(mp_node)s);
s= p;
set_dep_info(s,x);
mp_type(x)= independent_being_fixed;
}
set_dep_value(q,dep_value(q));
number_divide_int(dep_value(q),4);
if(number_zero(dep_value(q))){
set_mp_link(r,mp_link(q));
mp_free_dep_node(mp,q);
q= r;
}
}
r= q;
}

r= (mp_value_node)mp_link(q);
if(q==(mp_value_node)dep_list(t))
mp_make_known(mp,t,q);
}
while(s!=NULL){
p= (mp_value_node)mp_link(s);
x= dep_info(s);
mp_free_dep_node(mp,s);
s= p;
mp_type(x)= mp_independent;
set_indep_scale(x,indep_scale(x)+2);
}
mp->fix_needed= false;
}


/*:656*//*657:*/
#line 16985 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_new_dep(MP mp,mp_node q,mp_variable_type newtype,
mp_value_node p){
mp_node r;
FUNCTION_TRACE4("mp_new_dep(%p,%d,%p)\n",q,newtype,p);
mp_type(q)= newtype;
set_dep_list(q,p);
set_prev_dep(q,(mp_node)mp->dep_head);
r= mp_link(mp->dep_head);
set_mp_link(mp->dep_final,r);
set_prev_dep(r,(mp_node)mp->dep_final);
set_mp_link(mp->dep_head,q);
}


/*:657*//*658:*/
#line 17004 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_const_dependency(MP mp,mp_number v){
mp->dep_final= mp_get_dep_node(mp);
set_dep_value(mp->dep_final,v);
set_dep_info(mp->dep_final,NULL);
FUNCTION_TRACE3("%p = mp_const_dependency(%d)\n",mp->dep_final,number_to_scaled(v));
return mp->dep_final;
}


/*:658*//*659:*/
#line 17027 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_single_dependency(MP mp,mp_node p){
mp_value_node q,rr;
integer m;
m= indep_scale(p);
if(m> 28){
q= mp_const_dependency(mp,zero_t);
}else{
q= mp_get_dep_node(mp);
set_dep_value(q,zero_t);
set_number_from_scaled(dep_value(q),(integer)two_to_the(28-m));
set_dep_info(q,p);
rr= mp_const_dependency(mp,zero_t);
set_mp_link(q,(mp_node)rr);
}
FUNCTION_TRACE3("%p = mp_single_dependency(%p)\n",q,p);
return q;
}


/*:659*//*660:*/
#line 17049 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node mp_copy_dep_list(MP mp,mp_value_node p){
mp_value_node q;
FUNCTION_TRACE2("mp_copy_dep_list(%p)\n",p);
q= mp_get_dep_node(mp);
mp->dep_final= q;
while(1){
set_dep_info(mp->dep_final,dep_info(p));
set_dep_value(mp->dep_final,dep_value(p));
if(dep_info(mp->dep_final)==NULL)
break;
set_mp_link(mp->dep_final,(mp_node)mp_get_dep_node(mp));
mp->dep_final= (mp_value_node)mp_link(mp->dep_final);
p= (mp_value_node)mp_link(p);
}
return q;
}


/*:660*//*661:*/
#line 17078 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node find_node_with_largest_coefficient(MP mp,mp_value_node p,mp_number*v);
static void display_new_dependency(MP mp,mp_value_node p,mp_node x,integer n);
static void change_to_known(MP mp,mp_value_node p,mp_node x,mp_value_node final_node,integer n);
static mp_value_node divide_p_by_minusv_removing_q(MP mp,mp_value_node p,mp_value_node q,
mp_value_node*final_node,mp_number v,quarterword t);
static mp_value_node divide_p_by_2_n(MP mp,mp_value_node p,integer n);
static void mp_linear_eq(MP mp,mp_value_node p,quarterword t){
mp_value_node r;
mp_node x;
integer n;
mp_number v;
mp_value_node prev_r;
mp_value_node final_node;
mp_value_node qq;
new_number(v);
FUNCTION_TRACE3("mp_linear_eq(%p,%d)\n",p,t);
qq= find_node_with_largest_coefficient(mp,p,&v);
x= dep_info(qq);
n= indep_scale(x);
p= divide_p_by_minusv_removing_q(mp,p,qq,&final_node,v,t);
if(number_positive(internal_value(mp_tracing_equations))){
display_new_dependency(mp,p,(mp_node)x,n);
}
prev_r= (mp_value_node)mp->dep_head;
r= (mp_value_node)mp_link(mp->dep_head);
while(r!=mp->dep_head){
mp_value_node s= (mp_value_node)dep_list(r);
mp_value_node q= mp_p_with_x_becoming_q(mp,s,x,(mp_node)p,mp_type(r));
if(dep_info(q)==NULL){
mp_make_known(mp,r,q);
}else{
set_dep_list(r,q);
do{
q= (mp_value_node)mp_link(q);
}while(dep_info(q)!=NULL);
prev_r= q;
}
r= (mp_value_node)mp_link(prev_r);
}
if(n> 0){
p= divide_p_by_2_n(mp,p,n);
}
change_to_known(mp,p,(mp_node)x,final_node,n);
if(mp->fix_needed)
mp_fix_dependencies(mp);
free_number(v);
}


/*:661*//*662:*/
#line 17129 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node find_node_with_largest_coefficient(MP mp,mp_value_node p,mp_number*v){
mp_number vabs;
mp_number rabs;
mp_value_node q= p;
mp_value_node r= (mp_value_node)mp_link(p);
new_number(vabs);
new_number(rabs);
number_clone(*v,dep_value(q));
while(dep_info(r)!=NULL){
number_clone(vabs,*v);
number_abs(vabs);
number_clone(rabs,dep_value(r));
number_abs(rabs);
if(number_greater(rabs,vabs)){
q= r;
number_clone(*v,dep_value(r));
}
r= (mp_value_node)mp_link(r);
}
free_number(vabs);
free_number(rabs);
return q;
}


/*:662*//*663:*/
#line 17159 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node divide_p_by_minusv_removing_q(MP mp,mp_value_node p,mp_value_node q,
mp_value_node*final_node,mp_number v,quarterword t){
mp_value_node r;
mp_value_node s;
s= (mp_value_node)mp->temp_head;
set_mp_link(s,(mp_node)p);
r= p;
do{
if(r==q){
set_mp_link(s,mp_link(r));
mp_free_dep_node(mp,r);
}else{
mp_number w;
mp_number absw;
new_number(w);
new_number(absw);
make_fraction(w,dep_value(r),v);
number_clone(absw,w);
number_abs(absw);
if(number_lessequal(absw,half_fraction_threshold_k)){
set_mp_link(s,mp_link(r));
mp_free_dep_node(mp,r);
}else{
number_negate(w);
set_dep_value(r,w);
s= r;
}
free_number(w);
free_number(absw);
}
r= (mp_value_node)mp_link(s);
}while(dep_info(r)!=NULL);

if(t==mp_proto_dependent){
mp_number ret;
new_number(ret);
make_scaled(ret,dep_value(r),v);
number_negate(ret);
set_dep_value(r,ret);
free_number(ret);
}else if(number_to_scaled(v)!=-number_to_scaled(fraction_one_t)){
mp_number ret;
new_fraction(ret);
make_fraction(ret,dep_value(r),v);
number_negate(ret);
set_dep_value(r,ret);
free_number(ret);
}
*final_node= r;
return(mp_value_node)mp_link(mp->temp_head);
}


/*:663*//*664:*/
#line 17214 "../../../source/texk/web2c/mplibdir/mp.w"

static void display_new_dependency(MP mp,mp_value_node p,mp_node x,integer n){
if(mp_interesting(mp,x)){
int w0;
mp_begin_diagnostic(mp);
mp_print_nl(mp,"## ");
mp_print_variable_name(mp,x);
w0= n;
while(w0> 0){
mp_print(mp,"*4");
w0= w0-2;
}
mp_print_char(mp,xord('='));
mp_print_dependency(mp,p,mp_dependent);
mp_end_diagnostic(mp,false);
}
}

/*:664*//*665:*/
#line 17235 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_value_node divide_p_by_2_n(MP mp,mp_value_node p,integer n){
mp_value_node pp= NULL;
if(n> 0){

mp_value_node r;
mp_value_node s;
mp_number absw;
mp_number w;
new_number(w);
new_number(absw);
s= (mp_value_node)mp->temp_head;
set_mp_link(mp->temp_head,(mp_node)p);
r= p;
do{
if(n> 30){
set_number_to_zero(w);
}else{
number_clone(w,dep_value(r));
number_divide_int(w,two_to_the(n));
}
number_clone(absw,w);
number_abs(absw);
if(number_lessequal(absw,half_fraction_threshold_k)&&(dep_info(r)!=NULL)){
set_mp_link(s,mp_link(r));
mp_free_dep_node(mp,r);
}else{
set_dep_value(r,w);
s= r;
}
r= (mp_value_node)mp_link(s);
}while(dep_info(s)!=NULL);
pp= (mp_value_node)mp_link(mp->temp_head);
free_number(absw);
free_number(w);
}
return pp;
}

/*:665*//*666:*/
#line 17275 "../../../source/texk/web2c/mplibdir/mp.w"

static void change_to_known(MP mp,mp_value_node p,mp_node x,mp_value_node final_node,integer n){
if(dep_info(p)==NULL){
mp_number absx;
new_number(absx);
mp_type(x)= mp_known;
set_value_number(x,dep_value(p));
number_clone(absx,value_number(x));
number_abs(absx);
if(number_greaterequal(absx,warning_limit_t))
mp_val_too_big(mp,value_number(x));
free_number(absx);
mp_free_dep_node(mp,p);
if(cur_exp_node()==x&&mp->cur_exp.type==mp_independent){
set_cur_exp_value_number(value_number(x));
mp->cur_exp.type= mp_known;
mp_free_value_node(mp,x);
}
}else{
mp->dep_final= final_node;
mp_new_dep(mp,x,mp_dependent,p);
if(cur_exp_node()==x&&mp->cur_exp.type==mp_independent){
mp->cur_exp.type= mp_dependent;
}
}
}

/*:666*//*668:*/
#line 17331 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_new_ring_entry(MP mp,mp_node p){
mp_node q;
q= mp_get_value_node(mp);
mp_name_type(q)= mp_capsule;
mp_type(q)= mp_type(p);
if(value_node(p)==NULL)
set_value_node(q,p);
else
set_value_node(q,value_node(p));
set_value_node(p,q);
return q;
}


/*:668*//*670:*/
#line 17353 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_ring_delete(MP mp,mp_node p){
mp_node q;
(void)mp;
q= value_node(p);
if(q!=NULL&&q!=p){
while(value_node(q)!=p)
q= value_node(q);
set_value_node(q,value_node(p));
}
}


/*:670*//*671:*/
#line 17373 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_nonlinear_eq(MP mp,mp_value v,mp_node p,boolean flush_p){
mp_variable_type t;
mp_node q,r;
t= (mp_type(p)-unknown_tag);
q= value_node(p);
if(flush_p)
mp_type(p)= mp_vacuous;
else
p= q;
do{
r= value_node(q);
mp_type(q)= t;
switch(t){
case mp_boolean_type:
set_value_number(q,v.data.n);
break;
case mp_string_type:
set_value_str(q,v.data.str);
add_str_ref(v.data.str);
break;
case mp_pen_type:
set_value_knot(q,copy_pen(v.data.p));
break;
case mp_path_type:
set_value_knot(q,mp_copy_path(mp,v.data.p));
break;
case mp_picture_type:
set_value_node(q,v.data.node);
add_edge_ref(v.data.node);
break;
default:
break;
}
q= r;
}while(q!=p);
}


/*:671*//*672:*/
#line 17415 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_ring_merge(MP mp,mp_node p,mp_node q){
mp_node r;
r= value_node(p);
while(r!=p){
if(r==q){
exclaim_redundant_equation(mp);
return;
};
r= value_node(r);
}
r= value_node(p);
set_value_node(p,value_node(q));
set_value_node(q,r);
}


/*:672*//*673:*/
#line 17432 "../../../source/texk/web2c/mplibdir/mp.w"

static void exclaim_redundant_equation(MP mp){
const char*hlp[]= {
"I already knew that this equation was true.",
"But perhaps no harm has been done; let's continue.",
NULL};
mp_back_error(mp,"Redundant equation",hlp,true);
mp_get_x_next(mp);
}

/*:673*//*679:*/
#line 17523 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_cmd_mod(MP mp,integer c,integer m){
switch(c){
/*240:*/
#line 5052 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_add_to_command:
mp_print(mp,"addto");
break;
case mp_assignment:
mp_print(mp,":=");
break;
case mp_at_least:
mp_print(mp,"atleast");
break;
case mp_bchar_label:
mp_print(mp,"||:");
break;
case mp_begin_group:
mp_print(mp,"begingroup");
break;
case mp_colon:
mp_print(mp,":");
break;
case mp_comma:
mp_print(mp,",");
break;
case mp_controls:
mp_print(mp,"controls");
break;
case mp_curl_command:
mp_print(mp,"curl");
break;
case mp_delimiters:
mp_print(mp,"delimiters");
break;
case mp_double_colon:
mp_print(mp,"::");
break;
case mp_end_group:
mp_print(mp,"endgroup");
break;
case mp_every_job_command:
mp_print(mp,"everyjob");
break;
case mp_exit_test:
mp_print(mp,"exitif");
break;
case mp_expand_after:
mp_print(mp,"expandafter");
break;
case mp_interim_command:
mp_print(mp,"interim");
break;
case mp_left_brace:
mp_print(mp,"{");
break;
case mp_left_bracket:
mp_print(mp,"[");
break;
case mp_let_command:
mp_print(mp,"let");
break;
case mp_new_internal:
mp_print(mp,"newinternal");
break;
case mp_of_token:
mp_print(mp,"of");
break;
case mp_path_join:
mp_print(mp,"..");
break;
case mp_random_seed:
mp_print(mp,"randomseed");
break;
case mp_relax:
mp_print_char(mp,xord('\\'));
break;
case mp_right_brace:
mp_print_char(mp,xord('}'));
break;
case mp_right_bracket:
mp_print_char(mp,xord(']'));
break;
case mp_save_command:
mp_print(mp,"save");
break;
case mp_scan_tokens:
mp_print(mp,"scantokens");
break;
case mp_runscript:
mp_print(mp,"runscript");
break;
case mp_maketext:
mp_print(mp,"maketext");
break;
case mp_semicolon:
mp_print_char(mp,xord(';'));
break;
case mp_ship_out_command:
mp_print(mp,"shipout");
break;
case mp_skip_to:
mp_print(mp,"skipto");
break;
case mp_special_command:
if(m==2)
mp_print(mp,"fontmapline");
else if(m==1)
mp_print(mp,"fontmapfile");
else
mp_print(mp,"special");
break;
case mp_step_token:
mp_print(mp,"step");
break;
case mp_str_op:
mp_print(mp,"str");
break;
case mp_void_op:
mp_print(mp,"void");
break;
case mp_tension:
mp_print(mp,"tension");
break;
case mp_to_token:
mp_print(mp,"to");
break;
case mp_until_token:
mp_print(mp,"until");
break;
case mp_within_token:
mp_print(mp,"within");
break;
case mp_write_command:
mp_print(mp,"write");
break;

/*:240*//*744:*/
#line 18973 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_start_tex:
if(m==btex_code)
mp_print(mp,"btex");
else
mp_print(mp,"verbatimtex");
break;
case mp_etex_marker:
mp_print(mp,"etex");
break;
case mp_mpx_break:
mp_print(mp,"mpxbreak");
break;

/*:744*//*754:*/
#line 19143 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_macro_def:
if(m<=var_def){
if(m==start_def)
mp_print(mp,"def");
else if(m<start_def)
mp_print(mp,"enddef");
else
mp_print(mp,"vardef");
}else if(m==mp_secondary_primary_macro){
mp_print(mp,"primarydef");
}else if(m==mp_tertiary_secondary_macro){
mp_print(mp,"secondarydef");
}else{
mp_print(mp,"tertiarydef");
}
break;
case mp_iteration:
if(m==start_forever)
mp_print(mp,"forever");
else if(m==end_for)
mp_print(mp,"endfor");
else if(m==start_for)
mp_print(mp,"for");
else
mp_print(mp,"forsuffixes");
break;

/*:754*//*762:*/
#line 19314 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_macro_special:
switch(m){
case macro_prefix:
mp_print(mp,"#@");
break;
case macro_at:
mp_print_char(mp,xord('@'));
break;
case macro_suffix:
mp_print(mp,"@#");
break;
default:
mp_print(mp,"quote");
break;
}
break;

/*:762*//*768:*/
#line 19451 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_param_type:
if(m==mp_expr_param)
mp_print(mp,"expr");
else if(m==mp_suffix_param)
mp_print(mp,"suffix");
else if(m==mp_text_param)
mp_print(mp,"text");
else if(m==mp_primary_macro)
mp_print(mp,"primary");
else if(m==mp_secondary_macro)
mp_print(mp,"secondary");
else
mp_print(mp,"tertiary");
break;

/*:768*//*780:*/
#line 19808 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_input:
if(m==0)
mp_print(mp,"input");
else
mp_print(mp,"endinput");
break;

/*:780*//*822:*/
#line 20791 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_if_test:
case mp_fi_or_else:
switch(m){
case if_code:
mp_print(mp,"if");
break;
case fi_code:
mp_print(mp,"fi");
break;
case else_code:
mp_print(mp,"else");
break;
default:
mp_print(mp,"elseif");
break;
}
break;

/*:822*//*968:*/
#line 25319 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_nullary:
case mp_unary:
case mp_primary_binary:
case mp_secondary_binary:
case mp_tertiary_binary:
case mp_expression_binary:
case mp_cycle:
case mp_plus_or_minus:
case mp_slash:
case mp_ampersand:
case mp_equals:
case mp_and_command:
mp_print_op(mp,(quarterword)m);
break;

/*:968*//*1059:*/
#line 30246 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_type_name:
mp_print_type(mp,(quarterword)m);
break;

/*:1059*//*1084:*/
#line 30911 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_stop:
if(cur_mod()==0)
mp_print(mp,"end");
else
mp_print(mp,"dump");
break;

/*:1084*//*1091:*/
#line 30986 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_mode_command:
switch(m){
case mp_batch_mode:
mp_print(mp,"batchmode");
break;
case mp_nonstop_mode:
mp_print(mp,"nonstopmode");
break;
case mp_scroll_mode:
mp_print(mp,"scrollmode");
break;
default:
mp_print(mp,"errorstopmode");
break;
}
break;

/*:1091*//*1094:*/
#line 31013 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_protection_command:
if(m==0)
mp_print(mp,"inner");
else
mp_print(mp,"outer");
break;

/*:1094*//*1112:*/
#line 31266 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_show_command:
switch(m){
case show_token_code:
mp_print(mp,"showtoken");
break;
case show_stats_code:
mp_print(mp,"showstats");
break;
case show_code:
mp_print(mp,"show");
break;
case show_var_code:
mp_print(mp,"showvariable");
break;
default:
mp_print(mp,"showdependencies");
break;
}
break;

/*:1112*//*1118:*/
#line 31353 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_left_delimiter:
case mp_right_delimiter:
if(c==mp_left_delimiter)
mp_print(mp,"left");
else
mp_print(mp,"right");
#if 0
mp_print(mp," delimiter that matches ");
mp_print_text(m);
#else
mp_print(mp," delimiter");
#endif
break;
case mp_tag_token:
if(m==0)
mp_print(mp,"tag");
else
mp_print(mp,"variable");
break;
case mp_defined_macro:
mp_print(mp,"macro:");
break;
case mp_secondary_primary_macro:
case mp_tertiary_secondary_macro:
case mp_expression_tertiary_macro:
mp_print_cmd_mod(mp,mp_macro_def,c);
mp_print(mp,"'d macro:");
mp_print_ln(mp);
mp_show_token_list(mp,mp_link(mp_link(cur_mod_node())),0,1000,0);
break;
case mp_repeat_loop:
mp_print(mp,"[repeat the loop]");
break;
case mp_internal_quantity:
mp_print(mp,internal_name(m));
break;


/*:1118*//*1135:*/
#line 31608 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_thing_to_add:
if(m==contour_code)
mp_print(mp,"contour");
else if(m==double_path_code)
mp_print(mp,"doublepath");
else
mp_print(mp,"also");
break;
case mp_with_option:
if(m==mp_pen_type)
mp_print(mp,"withpen");
else if(m==with_mp_pre_script)
mp_print(mp,"withprescript");
else if(m==with_mp_post_script)
mp_print(mp,"withpostscript");
else if(m==mp_no_model)
mp_print(mp,"withoutcolor");
else if(m==mp_rgb_model)
mp_print(mp,"withrgbcolor");
else if(m==mp_uninitialized_model)
mp_print(mp,"withcolor");
else if(m==mp_cmyk_model)
mp_print(mp,"withcmykcolor");
else if(m==mp_grey_model)
mp_print(mp,"withgreyscale");
else
mp_print(mp,"dashed");
break;

/*:1135*//*1141:*/
#line 32069 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_bounds_command:
if(m==mp_start_clip_node_type)
mp_print(mp,"clip");
else
mp_print(mp,"setbounds");
break;

/*:1141*//*1156:*/
#line 32382 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_message_command:
if(m<err_message_code)
mp_print(mp,"message");
else if(m==err_message_code)
mp_print(mp,"errmessage");
else if(m==filename_template_code)
mp_print(mp,"filenametemplate");
else
mp_print(mp,"errhelp");
break;

/*:1156*//*1188:*/
#line 33049 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_tfm_command:
switch(m){
case char_list_code:
mp_print(mp,"charlist");
break;
case lig_table_code:
mp_print(mp,"ligtable");
break;
case extensible_code:
mp_print(mp,"extensible");
break;
case header_byte_code:
mp_print(mp,"headerbyte");
break;
default:
mp_print(mp,"fontdimen");
break;
}
break;

/*:1188*//*1198:*/
#line 33287 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_lig_kern_token:
switch(m){
case 0:
mp_print(mp,"=:");
break;
case 1:
mp_print(mp,"=:|");
break;
case 2:
mp_print(mp,"|=:");
break;
case 3:
mp_print(mp,"|=:|");
break;
case 5:
mp_print(mp,"=:|>");
break;
case 6:
mp_print(mp,"|=:>");
break;
case 7:
mp_print(mp,"|=:|>");
break;
case 11:
mp_print(mp,"|=:|>>");
break;
default:
mp_print(mp,"kern");
break;
}
break;

/*:1198*/
#line 17526 "../../../source/texk/web2c/mplibdir/mp.w"

default:
mp_print(mp,"[unknown command code!]");
break;
}
}


/*:679*//*680:*/
#line 17539 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_show_cmd_mod(MP mp,integer c,integer m){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{");
mp_print_cmd_mod(mp,c,m);
mp_print_char(mp,xord('}'));
mp_end_diagnostic(mp,false);
}


/*:680*//*689:*/
#line 17686 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_reallocate_input_stack(MP mp,int newsize){
int k;
int n= newsize+1;
XREALLOC(mp->input_file,n,void*);
XREALLOC(mp->line_stack,n,integer);
XREALLOC(mp->inext_stack,n,char*);
XREALLOC(mp->iname_stack,n,char*);
XREALLOC(mp->iarea_stack,n,char*);
XREALLOC(mp->mpx_name,n,mp_string);
for(k= mp->max_in_open;k<=n;k++){
mp->input_file[k]= NULL;
mp->line_stack[k]= 0;
mp->inext_stack[k]= NULL;
mp->iname_stack[k]= NULL;
mp->iarea_stack[k]= NULL;
mp->mpx_name[k]= NULL;
}
mp->max_in_open= newsize;
}


/*:689*//*695:*/
#line 17809 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_check_param_size(MP mp,int k){
while(k>=mp->param_size){
XREALLOC(mp->param_stack,(k+k/4),mp_node);
mp->param_size= k+k/4;
}
}


/*:695*//*698:*/
#line 17831 "../../../source/texk/web2c/mplibdir/mp.w"

integer mp_true_line(MP mp){
int k;
if(file_state&&(name> max_spec_src)){
return line;
}else{
k= mp->input_ptr;
while((k> 0)&&
((mp->input_stack[(k-1)].index_field<file_bottom)||
(mp->input_stack[(k-1)].name_field<=max_spec_src))){
decr(k);
}
return(k> 0?mp->line_stack[(k-1)+file_bottom]:0);
}
}


/*:698*//*700:*/
#line 17866 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_show_context(MP mp){
unsigned old_setting;
/*706:*/
#line 18028 "../../../source/texk/web2c/mplibdir/mp.w"

int i;
integer l;
integer m;
int n;
integer p;
integer q;

/*:706*/
#line 17869 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp->file_ptr= mp->input_ptr;
mp->input_stack[mp->file_ptr]= mp->cur_input;

while(1){
mp->cur_input= mp->input_stack[mp->file_ptr];
/*701:*/
#line 17885 "../../../source/texk/web2c/mplibdir/mp.w"

if((mp->file_ptr==mp->input_ptr)||file_state||
(token_type!=backed_up)||(nloc!=NULL)){

mp->tally= 0;
old_setting= mp->selector;
if(file_state){
/*702:*/
#line 17907 "../../../source/texk/web2c/mplibdir/mp.w"

if(name> max_spec_src){
mp_print_nl(mp,"l.");
mp_print_int(mp,mp_true_line(mp));
}else if(terminal_input){
if(mp->file_ptr==0)
mp_print_nl(mp,"<*>");
else
mp_print_nl(mp,"<insert>");
}else if(name==is_scantok){
mp_print_nl(mp,"<scantokens>");
}else{
mp_print_nl(mp,"<read>");
}
mp_print_char(mp,xord(' '))


/*:702*/
#line 17892 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*709:*/
#line 18089 "../../../source/texk/web2c/mplibdir/mp.w"

begin_pseudoprint;
if(limit> 0){
for(i= start;i<=limit-1;i++){
if(i==loc)
set_trick_count();
mp_print_char(mp,mp->buffer[i]);
}
}

/*:709*/
#line 17893 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
/*703:*/
#line 17927 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(token_type==forever_text){
mp_print_nl(mp,"<forever> ");
}else if(token_type==loop_text){
/*704:*/
#line 17962 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node pp;
mp_print_nl(mp,"<for(");
pp= mp->param_stack[param_start];
if(pp!=NULL){
if(mp_link(pp)==MP_VOID)
mp_print_exp(mp,pp,0);
else
mp_show_token_list(mp,pp,NULL,20,mp->tally);
}
mp_print(mp,")> ");
}


/*:704*/
#line 17932 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(token_type==parameter){
mp_print_nl(mp,"<argument> ");
}else if(token_type==backed_up){
if(nloc==NULL)
mp_print_nl(mp,"<recently read> ");
else
mp_print_nl(mp,"<to be read again> ");
}else if(token_type==inserted){
mp_print_nl(mp,"<inserted text> ");
}else if(token_type==macro){
mp_print_ln(mp);
if(name!=NULL)
mp_print_str(mp,name);
else
/*705:*/
#line 17981 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node pp= mp->param_stack[param_start];
if(pp==NULL){
mp_show_token_list(mp,mp->param_stack[param_start+1],NULL,20,
mp->tally);
}else{
mp_node qq= pp;
while(mp_link(qq)!=NULL)
qq= mp_link(qq);
mp_link(qq)= mp->param_stack[param_start+1];
mp_show_token_list(mp,pp,NULL,20,mp->tally);
mp_link(qq)= NULL;
}
}


/*:705*/
#line 17947 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print(mp,"->");
}else{
mp_print_nl(mp,"?");

}
}


/*:703*/
#line 17895 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*710:*/
#line 18099 "../../../source/texk/web2c/mplibdir/mp.w"

begin_pseudoprint;
if(token_type!=macro)
mp_show_token_list(mp,nstart,nloc,100000,0);
else
mp_show_macro(mp,nstart,nloc,100000)


/*:710*/
#line 17896 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp->selector= old_setting;
/*708:*/
#line 18051 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->trick_count==1000000)
set_trick_count();

if(mp->tally<mp->trick_count)
m= mp->tally-mp->first_count;
else
m= mp->trick_count-mp->first_count;
if(l+mp->first_count<=mp->half_error_line){
p= 0;
n= l+mp->first_count;
}else{
mp_print(mp,"...");
p= l+mp->first_count-mp->half_error_line+3;
n= mp->half_error_line;
}
for(q= p;q<=mp->first_count-1;q++){
mp_print_char(mp,mp->trick_buf[q%mp->error_line]);
}
mp_print_ln(mp);
for(q= 1;q<=n;q++){
mp_print_char(mp,xord(' '));
}
if(m+n<=mp->error_line)
p= mp->first_count+m;
else
p= mp->first_count+(mp->error_line-n-3);
for(q= mp->first_count;q<=p-1;q++){
mp_print_char(mp,mp->trick_buf[q%mp->error_line]);
}
if(m+n> mp->error_line)
mp_print(mp,"...")


/*:708*/
#line 17899 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

/*:701*/
#line 17875 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(file_state)
if((name> max_spec_src)||(mp->file_ptr==0))
break;
decr(mp->file_ptr);
}
mp->cur_input= mp->input_stack[mp->input_ptr];
}


/*:700*//*713:*/
#line 18138 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_begin_token_list(MP mp,mp_node p,quarterword t){
push_input;
nstart= p;
token_type= t;
param_start= mp->param_ptr;
nloc= p;
}


/*:713*//*714:*/
#line 18152 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_end_token_list(MP mp){
mp_node p;
if(token_type>=backed_up){
if(token_type<=inserted){
mp_flush_token_list(mp,nstart);
goto DONE;
}else{
mp_delete_mac_ref(mp,nstart);
}
}
while(mp->param_ptr> param_start){
decr(mp->param_ptr);
p= mp->param_stack[mp->param_ptr];
if(p!=NULL){
if(mp_link(p)==MP_VOID){
mp_recycle_value(mp,p);
mp_free_value_node(mp,p);
}else{
mp_flush_token_list(mp,p);
}
}
}
DONE:
pop_input;
check_interrupt;
}


/*:714*//*715:*/
#line 18185 "../../../source/texk/web2c/mplibdir/mp.w"

/*952:*/
#line 24190 "../../../source/texk/web2c/mplibdir/mp.w"

/*953:*/
#line 24316 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_encapsulate(MP mp,mp_value_node p){
mp_node q= mp_get_value_node(mp);
FUNCTION_TRACE2("mp_encapsulate(%p)\n",p);
mp_name_type(q)= mp_capsule;
mp_new_dep(mp,q,mp->cur_exp.type,p);
set_cur_exp_node(q);
}

/*:953*//*954:*/
#line 24328 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_install(MP mp,mp_node r,mp_node q){
mp_value_node p;
if(mp_type(q)==mp_known){
mp_type(r)= mp_known;
set_value_number(r,value_number(q));
}else if(mp_type(q)==mp_independent){
p= mp_single_dependency(mp,q);
if(p==mp->dep_final){
mp_type(r)= mp_known;
set_value_number(r,zero_t);
mp_free_dep_node(mp,p);
}else{
mp_new_dep(mp,r,mp_dependent,p);
}
}else{
mp_new_dep(mp,r,mp_type(q),
mp_copy_dep_list(mp,(mp_value_node)dep_list((mp_value_node)
q)));
}
}


/*:954*/
#line 24191 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_make_exp_copy(MP mp,mp_node p){
mp_node t;
mp_value_node q;
RESTART:
mp->cur_exp.type= mp_type(p);
switch(mp->cur_exp.type){
case mp_vacuous:
case mp_boolean_type:
case mp_known:
set_cur_exp_value_number(value_number(p));
break;
case unknown_types:
t= mp_new_ring_entry(mp,p);
set_cur_exp_node(t);
break;
case mp_string_type:
set_cur_exp_str(value_str(p));
break;
case mp_picture_type:
set_cur_exp_node(value_node(p));
add_edge_ref(cur_exp_node());
break;
case mp_pen_type:
set_cur_exp_knot(copy_pen(value_knot(p)));
break;
case mp_path_type:
set_cur_exp_knot(mp_copy_path(mp,value_knot(p)));
break;
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:





if(value_node(p)==NULL){
switch(mp_type(p)){
case mp_pair_type:
mp_init_pair_node(mp,p);
break;
case mp_color_type:
mp_init_color_node(mp,p);
break;
case mp_cmykcolor_type:
mp_init_cmykcolor_node(mp,p);
break;
case mp_transform_type:
mp_init_transform_node(mp,p);
break;
default:
break;
}
}
t= mp_get_value_node(mp);
mp_name_type(t)= mp_capsule;
q= (mp_value_node)value_node(p);
switch(mp->cur_exp.type){
case mp_pair_type:
mp_init_pair_node(mp,t);
mp_install(mp,y_part(value_node(t)),y_part(q));
mp_install(mp,x_part(value_node(t)),x_part(q));
break;
case mp_color_type:
mp_init_color_node(mp,t);
mp_install(mp,blue_part(value_node(t)),blue_part(q));
mp_install(mp,green_part(value_node(t)),green_part(q));
mp_install(mp,red_part(value_node(t)),red_part(q));
break;
case mp_cmykcolor_type:
mp_init_cmykcolor_node(mp,t);
mp_install(mp,black_part(value_node(t)),black_part(q));
mp_install(mp,yellow_part(value_node(t)),yellow_part(q));
mp_install(mp,magenta_part(value_node(t)),magenta_part(q));
mp_install(mp,cyan_part(value_node(t)),cyan_part(q));
break;
case mp_transform_type:
mp_init_transform_node(mp,t);
mp_install(mp,yy_part(value_node(t)),yy_part(q));
mp_install(mp,yx_part(value_node(t)),yx_part(q));
mp_install(mp,xy_part(value_node(t)),xy_part(q));
mp_install(mp,xx_part(value_node(t)),xx_part(q));
mp_install(mp,ty_part(value_node(t)),ty_part(q));
mp_install(mp,tx_part(value_node(t)),tx_part(q));
break;
default:
break;
}
set_cur_exp_node(t);
break;
case mp_dependent:
case mp_proto_dependent:
mp_encapsulate(mp,
mp_copy_dep_list(mp,
(mp_value_node)dep_list((mp_value_node)
p)));
break;
case mp_numeric_type:
mp_new_indep(mp,p);
goto RESTART;
break;
case mp_independent:
q= mp_single_dependency(mp,p);
if(q==mp->dep_final){
mp->cur_exp.type= mp_known;
set_cur_exp_value_number(zero_t);
mp_free_dep_node(mp,q);
}else{
mp->cur_exp.type= mp_dependent;
mp_encapsulate(mp,q);
}
break;
default:
mp_confusion(mp,"copy");
;
break;
}
}


/*:952*/
#line 18186 "../../../source/texk/web2c/mplibdir/mp.w"
;
static mp_node mp_cur_tok(MP mp){
mp_node p;
if(cur_sym()==NULL&&(cur_sym_mod()==0||cur_sym_mod()==mp_normal_sym)){
if(cur_cmd()==mp_capsule_token){
mp_number save_exp_num;
mp_value save_exp= mp->cur_exp;
new_number(save_exp_num);
number_clone(save_exp_num,cur_exp_value_number());
mp_make_exp_copy(mp,cur_mod_node());
p= mp_stash_cur_exp(mp);
mp_link(p)= NULL;
mp->cur_exp= save_exp;
number_clone(mp->cur_exp.data.n,save_exp_num);
free_number(save_exp_num);
}else{
p= mp_get_token_node(mp);
mp_name_type(p)= mp_token;
if(cur_cmd()==mp_numeric_token){
set_value_number(p,cur_mod_number());
mp_type(p)= mp_known;
}else{
set_value_str(p,cur_mod_str());
mp_type(p)= mp_string_type;
}
}
}else{
p= mp_get_symbolic_node(mp);
set_mp_sym_sym(p,cur_sym());
mp_name_type(p)= cur_sym_mod();
}
return p;
}


/*:715*//*717:*/
#line 18229 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_back_input(MP mp){
mp_node p;
p= mp_cur_tok(mp);
while(token_state&&(nloc==NULL))
mp_end_token_list(mp);
back_list(p);
}


/*:717*//*719:*/
#line 18246 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_back_error(MP mp,const char*msg,const char**hlp,boolean deletions_allowed){

mp->OK_to_interrupt= false;
mp_back_input(mp);
mp->OK_to_interrupt= true;
mp_error(mp,msg,hlp,deletions_allowed);
}
static void mp_ins_error(MP mp,const char*msg,const char**hlp,boolean deletions_allowed){

mp->OK_to_interrupt= false;
mp_back_input(mp);
token_type= (quarterword)inserted;
mp->OK_to_interrupt= true;
mp_error(mp,msg,hlp,deletions_allowed);
}


/*:719*//*720:*/
#line 18270 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_begin_file_reading(MP mp){
if(mp->in_open==(mp->max_in_open-1))
mp_reallocate_input_stack(mp,(mp->max_in_open+mp->max_in_open/4));
if(mp->first==mp->buf_size)
mp_reallocate_buffer(mp,(mp->buf_size+mp->buf_size/4));
mp->in_open++;
push_input;
iindex= (quarterword)mp->in_open;
if(mp->in_open_max<mp->in_open)
mp->in_open_max= mp->in_open;
mp->mpx_name[iindex]= absent;
start= (halfword)mp->first;
name= is_term;
}


/*:720*//*721:*/
#line 18292 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_end_file_reading(MP mp){
if(mp->reading_preload&&mp->input_ptr==0){
set_cur_sym(mp->frozen_dump);
mp_back_input(mp);
return;
}
if(mp->in_open> iindex){
if((mp->mpx_name[mp->in_open]==absent)||(name<=max_spec_src)){
mp_confusion(mp,"endinput");
;
}else{
(mp->close_file)(mp,mp->input_file[mp->in_open]);
delete_str_ref(mp->mpx_name[mp->in_open]);
decr(mp->in_open);
}
}
mp->first= (size_t)start;
if(iindex!=mp->in_open)
mp_confusion(mp,"endinput");
if(name> max_spec_src){
(mp->close_file)(mp,cur_file);
xfree(in_ext);
xfree(in_name);
xfree(in_area);
}
pop_input;
decr(mp->in_open);
}


/*:721*//*722:*/
#line 18327 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_begin_mpx_reading(MP mp){
if(mp->in_open!=iindex+1){
return false;
}else{
if(mp->mpx_name[mp->in_open]<=absent)
mp_confusion(mp,"mpx");
if(mp->first==mp->buf_size)
mp_reallocate_buffer(mp,(mp->buf_size+(mp->buf_size/4)));
push_input;
iindex= (quarterword)mp->in_open;
start= (halfword)mp->first;
name= mp->mpx_name[mp->in_open];
add_str_ref(name);



mp->last= mp->first;
limit= (halfword)mp->last;

mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
return true;
}
}


/*:722*//*723:*/
#line 18357 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_end_mpx_reading(MP mp){
if(mp->in_open!=iindex)
mp_confusion(mp,"mpx");
;
if(loc<limit){




const char*hlp[]= {
"This file contains picture expressions for btex...etex",
"blocks.  Such files are normally generated automatically",
"but this one seems to be messed up.  I'm going to ignore",
"the rest of this line.",
NULL};
mp_error(mp,"`mpxbreak' must be at the end of a line",hlp,true);
}
mp->first= (size_t)start;
pop_input;
}

/*:723*//*724:*/
#line 18383 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_clear_for_error_prompt(MP mp){
while(file_state&&terminal_input&&(mp->input_ptr> 0)&&(loc==limit))
mp_end_file_reading(mp);
mp_print_ln(mp);
clear_terminal();
}


/*:724*//*729:*/
#line 18470 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_check_outer_validity(MP mp){
mp_node p;
if(mp->scanner_status==normal){
return true;
}else if(mp->scanner_status==tex_flushing){
/*730:*/
#line 18502 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_sym()!=NULL){
return true;
}else{
char msg[256];
const char*hlp[]= {
"The file ended while I was looking for the `etex' to",
"finish this TeX material.  I've inserted `etex' now.",
NULL};
mp_snprintf(msg,256,"TeX mode didn't end; all text was ignored after line %d",(int)mp->warning_line);
set_cur_sym(mp->frozen_etex);
mp_ins_error(mp,msg,hlp,false);
return false;
}


/*:730*/
#line 18477 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
/*731:*/
#line 18518 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_sym()!=NULL){
p= mp_get_symbolic_node(mp);
set_mp_sym_sym(p,cur_sym());
mp_name_type(p)= cur_sym_mod();
back_list(p);
}

/*:731*/
#line 18479 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp->scanner_status> skipping){
/*732:*/
#line 18526 "../../../source/texk/web2c/mplibdir/mp.w"

{
char msg[256];
const char*msg_start= NULL;
const char*hlp[]= {
"I suspect you have forgotten an `enddef',",
"causing me to read past where you wanted me to stop.",
"I'll try to recover; but if the error is serious,",
"you'd better type `E' or `X' now and fix your file.",
NULL};
mp_runaway(mp);
if(cur_sym()==NULL){
msg_start= "File ended while scanning";

}else{
msg_start= "Forbidden token found while scanning";

}
switch(mp->scanner_status){
/*733:*/
#line 18556 "../../../source/texk/web2c/mplibdir/mp.w"

case flushing:
mp_snprintf(msg,256,"%s to the end of the statement",msg_start);
hlp[0]= "A previous error seems to have propagated,";
set_cur_sym(mp->frozen_semicolon);
break;
case absorbing:
mp_snprintf(msg,256,"%s a text argument",msg_start);
hlp[0]= "It seems that a right delimiter was left out,";
if(mp->warning_info==NULL){
set_cur_sym(mp->frozen_end_group);
}else{
set_cur_sym(mp->frozen_right_delimiter);


set_equiv_sym(cur_sym(),mp->warning_info);
}
break;
case var_defining:
{
mp_string s;
int old_setting= mp->selector;
mp->selector= new_string;
mp_print_variable_name(mp,mp->warning_info_node);
s= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"%s the definition of %s",msg_start,s->str);
delete_str_ref(s);
}
set_cur_sym(mp->frozen_end_def);
break;
case op_defining:
{
char*s= mp_str(mp,text(mp->warning_info));
mp_snprintf(msg,256,"%s the definition of %s",msg_start,s);
}
set_cur_sym(mp->frozen_end_def);
break;
case loop_defining:
{
char*s= mp_str(mp,text(mp->warning_info));
mp_snprintf(msg,256,"%s the text of a %s loop",msg_start,s);
}
hlp[0]= "I suspect you have forgotten an `endfor',";
set_cur_sym(mp->frozen_end_for);
break;

/*:733*/
#line 18546 "../../../source/texk/web2c/mplibdir/mp.w"

}
mp_ins_error(mp,msg,hlp,true);
}


/*:732*/
#line 18481 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
char msg[256];
const char*hlp[]= {
"A forbidden `outer' token occurred in skipped text.",
"This kind of error happens when you say `if...' and forget",
"the matching `fi'. I've inserted a `fi'; this might work.",
NULL};
mp_snprintf(msg,256,"Incomplete if; all text was ignored after line %d",(int)mp->warning_line);
;
if(cur_sym()==NULL){
hlp[0]= "The file ended while I was skipping conditional text.";
}
set_cur_sym(mp->frozen_fi);
mp_ins_error(mp,msg,hlp,false);
}
return false;
}
}


/*:729*//*735:*/
#line 18609 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_runaway(MP mp){
if(mp->scanner_status> flushing){
mp_print_nl(mp,"Runaway ");
switch(mp->scanner_status){
case absorbing:
mp_print(mp,"text?");
break;
case var_defining:
case op_defining:
mp_print(mp,"definition?");
break;
case loop_defining:
mp_print(mp,"loop?");
break;
}
mp_print_ln(mp);
mp_show_token_list(mp,mp_link(mp->hold_head),NULL,mp->error_line-10,
0);
}
}


/*:735*//*737:*/
#line 18641 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_get_next(MP mp){

mp_sym cur_sym_;
RESTART:
set_cur_sym(NULL);
set_cur_sym_mod(0);
if(file_state){
int k;
ASCII_code c;
int cclass;




SWITCH:
c= mp->buffer[loc];
incr(loc);
cclass= mp->char_class[c];
switch(cclass){
case digit_class:
scan_numeric_token((c-'0'));
return;
break;
case period_class:
cclass= mp->char_class[mp->buffer[loc]];
if(cclass> period_class){
goto SWITCH;
}else if(cclass<period_class){
scan_fractional_token(0);
return;
}
break;
case space_class:
goto SWITCH;
break;
case percent_class:
if(mp->scanner_status==tex_flushing){
if(loc<limit)
goto SWITCH;
}

switch(move_to_next_line(mp)){
case 1:goto RESTART;break;
case 2:goto COMMON_ENDING;break;
default:break;
}
check_interrupt;
goto SWITCH;
break;
case string_class:
if(mp->scanner_status==tex_flushing){
goto SWITCH;
}else{
if(mp->buffer[loc]=='"'){
set_cur_mod_str(mp_rts(mp,""));
}else{
k= loc;
mp->buffer[limit+1]= xord('"');
do{
incr(loc);
}while(mp->buffer[loc]!='"');
if(loc> limit){




const char*hlp[]= {
"Strings should finish on the same line as they began.",
"I've deleted the partial string; you might want to",
"insert another by typing, e.g., `I\"new string\"'.",
NULL};
loc= limit;
mp_error(mp,"Incomplete string token has been flushed",hlp,false);
goto RESTART;
}
str_room((size_t)(loc-k));
do{
append_char(mp->buffer[k]);
incr(k);
}while(k!=loc);
set_cur_mod_str(mp_make_string(mp));
}
incr(loc);
set_cur_cmd((mp_variable_type)mp_string_token);
return;
}
break;
case isolated_classes:
k= loc-1;
goto FOUND;
break;
case invalid_class:
if(mp->scanner_status==tex_flushing){
goto SWITCH;
}else{




const char*hlp[]= {
"A funny symbol that I can\'t read has just been input.",
"Continue, and I'll forget that it ever happened.",
NULL};
mp_error(mp,"Text line contains an invalid character",hlp,false);
goto RESTART;
}
break;
default:
break;
}
k= loc-1;
while(mp->char_class[mp->buffer[loc]]==cclass)
incr(loc);
FOUND:
set_cur_sym(mp_id_lookup(mp,(char*)(mp->buffer+k),(size_t)(loc-k),true));

}else{



if(nloc!=NULL&&mp_type(nloc)==mp_symbol_node){
int cur_sym_mod_= mp_name_type(nloc);
halfword cur_info= mp_sym_info(nloc);
set_cur_sym(mp_sym_sym(nloc));
set_cur_sym_mod(cur_sym_mod_);
nloc= mp_link(nloc);
if(cur_sym_mod_==mp_expr_sym){
set_cur_cmd((mp_variable_type)mp_capsule_token);
set_cur_mod_node(mp->param_stack[param_start+cur_info]);
set_cur_sym_mod(0);
set_cur_sym(NULL);
return;
}else if(cur_sym_mod_==mp_suffix_sym||cur_sym_mod_==mp_text_sym){
mp_begin_token_list(mp,
mp->param_stack[param_start+cur_info],
(quarterword)parameter);
goto RESTART;
}
}else if(nloc!=NULL){

if(mp_name_type(nloc)==mp_token){
if(mp_type(nloc)==mp_known){
set_cur_mod_number(value_number(nloc));
set_cur_cmd((mp_variable_type)mp_numeric_token);
}else{
set_cur_mod_str(value_str(nloc));
set_cur_cmd((mp_variable_type)mp_string_token);
add_str_ref(cur_mod_str());
}
}else{
set_cur_mod_node(nloc);
set_cur_cmd((mp_variable_type)mp_capsule_token);
}
nloc= mp_link(nloc);
return;
}else{
mp_end_token_list(mp);
goto RESTART;
}
}
COMMON_ENDING:


cur_sym_= cur_sym();
set_cur_cmd(eq_type(cur_sym_));
set_cur_mod(equiv(cur_sym_));
set_cur_mod_node(equiv_node(cur_sym_));
if(cur_cmd()>=mp_outer_tag){
if(mp_check_outer_validity(mp))
set_cur_cmd(cur_cmd()-mp_outer_tag);
else
goto RESTART;
}
}

/*:737*//*740:*/
#line 18826 "../../../source/texk/web2c/mplibdir/mp.w"

static int move_to_next_line(MP mp){
if(name> max_spec_src){





{
incr(line);
mp->first= (size_t)start;
if(!mp->force_eof){
if(mp_input_ln(mp,cur_file))
mp_firm_up_the_line(mp);
else
mp->force_eof= true;
};
if(mp->force_eof){
mp->force_eof= false;
decr(loc);
if(mpx_reading){





const char*hlp[]= {"The file had too few picture expressions for btex...etex",
"blocks.  Such files are normally generated automatically",
"but this one got messed up.  You might want to insert a",
"picture expression now.",
NULL};
mp->mpx_name[iindex]= mpx_finished;
mp_error(mp,"mpx file ended unexpectedly",hlp,false);
set_cur_sym(mp->frozen_mpx_break);
return 2;
}else{
mp_print_char(mp,xord(')'));
decr(mp->open_parens);
update_terminal();
mp_end_file_reading(mp);
if(mp_check_outer_validity(mp))
return 1;
else
return 1;
}
}
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
}


}else{
if(mp->input_ptr> 0){

mp_end_file_reading(mp);

return 1;
}
if(mp->job_name==NULL
&&(mp->selector<log_only||mp->selector>=write_file))
mp_open_log_file(mp);
if(mp->interaction> mp_nonstop_mode){
if(limit==start)
mp_print_nl(mp,"(Please type a command or say `end')");
mp_print_ln(mp);
mp->first= (size_t)start;
prompt_input("*");
limit= (halfword)mp->last;
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
}else{
mp_fatal_error(mp,"*** (job aborted, no legal end found)");


}
}
return 0;
}


/*:740*//*741:*/
#line 18916 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_firm_up_the_line(MP mp){
size_t k;
limit= (halfword)mp->last;
if((!mp->noninteractive)
&&(number_positive(internal_value(mp_pausing)))
&&(mp->interaction> mp_nonstop_mode)){
wake_up_terminal();
mp_print_ln(mp);
if(start<limit){
for(k= (size_t)start;k<(size_t)limit;k++){
mp_print_char(mp,mp->buffer[k]);
}
}
mp->first= (size_t)limit;
prompt_input("=>");
;
if(mp->last> mp->first){
for(k= mp->first;k<mp->last;k++){
mp->buffer[k+(size_t)start-mp->first]= mp->buffer[k];
}
limit= (halfword)((size_t)start+mp->last-mp->first);
}
}
}


/*:741*//*745:*/
#line 18997 "../../../source/texk/web2c/mplibdir/mp.w"

/*:745*//*747:*/
#line 19002 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_t_next(MP mp){
int old_status;
integer old_info;

if((mp->extensions==1)&&(cur_cmd()==mp_start_tex)){
/*789:*/
#line 19997 "../../../source/texk/web2c/mplibdir/mp.w"

{
char*txt= NULL;
char*ptr= NULL;
int slin= line;
int size= 0;
int done= 0;
int mode= round_unscaled(internal_value(mp_texscriptmode));
int verb= cur_mod()==verbatim_code;
int first;

if(loc<=limit&&mp->char_class[mp->buffer[loc]]==space_class){
incr(loc);
}else{

}

first= loc;
while(1){

if(loc<limit-4){
if(mp->buffer[loc]=='e'){
incr(loc);
if(mp->buffer[loc]=='t'){
incr(loc);
if(mp->buffer[loc]=='e'){
incr(loc);
if(mp->buffer[loc]=='x'){

if(first==(loc-3)){

done= 1;
}else if(mp->char_class[mp->buffer[loc-4]]==space_class){

done= 2;
}
if(done){
if((loc+1)<=limit){
quarterword c= mp->char_class[mp->buffer[loc+1]];
if(c!=letter_class){
incr(loc);

break;
}else{

done= 0;
}
}else{

incr(loc);

break;
}
}
}
}
}
}
}

if(loc>=limit){
if(size){
txt= realloc(txt,size+limit-first+1);
}else{
txt= malloc(limit-first+1);
}
(void)memcpy(txt+size,mp->buffer+first,limit-first);
size+= limit-first+1;
if(mode<=0){
txt[size-1]= ' ';
}else if(verb){

txt[size-1]= '\n';
}else if(mode>=2){

txt[size-1]= '\n';
}else{
txt[size-1]= ' ';
}
if(move_to_next_line(mp)){

goto FATAL_ERROR;
}
first= loc;
}else{
incr(loc);
}
}
if(done){

int l= loc-5;
int n= l-first+1;

if(done==2){

l-= 1;
n-= 1;

}
if(size){
txt= realloc(txt,size+n+1);
}else{
txt= malloc(n+1);
}
(void)memcpy(txt+size,mp->buffer+first,n);
size+= n;
if(verb&&mode>=3){

txt[size]= '\0';
ptr= txt;
}else if(mode>=4){

txt[size]= '\0';
ptr= txt;
}else{


while((size> 1)&&(mp->char_class[(ASCII_code)txt[size-1]]==space_class||txt[size-1]=='\n')){
decr(size);
}

txt[size]= '\0';

ptr= txt;
while((size> 1)&&(mp->char_class[(ASCII_code)ptr[0]]==space_class||ptr[0]=='\n')){
incr(ptr);
decr(size);
}
}

{
char*s= mp->make_text(mp,ptr,verb);
/*787:*/
#line 19933 "../../../source/texk/web2c/mplibdir/mp.w"

if(s!=NULL){
int k;
mp_value new_expr;
size_t size= strlen(s);
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_begin_file_reading(mp);
name= is_scantok;
mp->last= mp->first;
k= mp->first+size;
if(k>=mp->max_buf_stack){
while(k>=mp->buf_size){
mp_reallocate_buffer(mp,(mp->buf_size+(mp->buf_size/4)));
}
mp->max_buf_stack= k+1;
}
limit= (halfword)k;
(void)memcpy((mp->buffer+mp->first),s,size);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
mp_flush_cur_exp(mp,new_expr);
}

/*:787*/
#line 20129 "../../../source/texk/web2c/mplibdir/mp.w"

free(s);
}
free(txt);

mp_get_next(mp);
return;
}




FATAL_ERROR:
{

char msg[256];
const char*hlp[]= {"An 'etex' is missing at this input level, nothing gets done.",NULL};
if(slin> 0){
mp_snprintf(msg,256,"No matching 'etex' for '%stex'.",verb?"verbatim":"b");
}else{
mp_snprintf(msg,256,"No matching 'etex' for '%stex' in line %d.",verb?"verbatim":"b",slin);
}
mp_error(mp,msg,hlp,false);
free(txt);
}
}

/*:789*/
#line 19008 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{

while(cur_cmd()<=mp_max_pre_command){
if(cur_cmd()==mp_mpx_break){
if(!file_state||(mp->mpx_name[iindex]==absent)){
/*751:*/
#line 19082 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"I'll ignore this preprocessor command because it",
"doesn't belong here",
NULL};
mp_error(mp,"Misplaced mpxbreak",hlp,true);
}


/*:751*/
#line 19014 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp_end_mpx_reading(mp);
goto TEX_FLUSH;
}
}else if(cur_cmd()==mp_start_tex){
if(token_state||(name<=max_spec_src)){
/*750:*/
#line 19071 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"I'll have to ignore this preprocessor command because it",
"only works when there is a file to preprocess.  You might",
"want to delete everything up to the next `etex`.",
NULL};
mp_error(mp,"You can only use `btex' or `verbatimtex' in a file",hlp,true);
}


/*:750*/
#line 19021 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(mpx_reading){
/*749:*/
#line 19059 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"This file contains picture expressions for btex...etex",
"blocks.  Such files are normally generated automatically",
"but this one seems to be messed up.  I'll just keep going",
"and hope for the best.",
NULL};
mp_error(mp,"An mpx file cannot contain btex or verbatimtex blocks",hlp,true);
}


/*:749*/
#line 19023 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if((cur_mod()!=verbatim_code)&&
(mp->mpx_name[iindex]!=mpx_finished)){
if(!mp_begin_mpx_reading(mp))
mp_start_mpx_input(mp);
}else{
goto TEX_FLUSH;
}
}else{
/*752:*/
#line 19092 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"There is no btex or verbatimtex for this to match",
NULL};
mp_error(mp,"Extra etex will be ignored",hlp,true);
}


/*:752*/
#line 19032 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
goto COMMON_ENDING;
TEX_FLUSH:
/*748:*/
#line 19048 "../../../source/texk/web2c/mplibdir/mp.w"

old_status= mp->scanner_status;
old_info= mp->warning_line;
mp->scanner_status= tex_flushing;
mp->warning_line= line;
do{
mp_get_next(mp);
}while(cur_cmd()!=mp_etex_marker);
mp->scanner_status= old_status;
mp->warning_line= old_info

/*:748*/
#line 19036 "../../../source/texk/web2c/mplibdir/mp.w"
;
COMMON_ENDING:
mp_get_next(mp);
}
}
}


/*:747*//*756:*/
#line 19202 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_scan_toks(MP mp,mp_command_code terminator,
mp_subst_list_item*subst_list,mp_node tail_end,
quarterword suffix_count){
mp_node p;
mp_subst_list_item*q= NULL;
integer balance;
halfword cur_data;
quarterword cur_data_mod= 0;
p= mp->hold_head;
balance= 1;
mp_link(mp->hold_head)= NULL;
while(1){
get_t_next(mp);
cur_data= -1;
if(cur_sym()!=NULL){
/*759:*/
#line 19269 "../../../source/texk/web2c/mplibdir/mp.w"

{
q= subst_list;
while(q!=NULL){
if(q->info==cur_sym()&&q->info_mod==cur_sym_mod()){
cur_data= q->value_data;
cur_data_mod= q->value_mod;
set_cur_cmd((mp_variable_type)mp_relax);
break;
}
q= q->link;
}
}


/*:759*/
#line 19218 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(cur_cmd()==terminator){
/*760:*/
#line 19284 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_mod()> 0){
incr(balance);
}else{
decr(balance);
if(balance==0)
break;
}


/*:760*/
#line 19220 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(cur_cmd()==mp_macro_special){

if(cur_mod()==quote){
get_t_next(mp);
}else if(cur_mod()<=suffix_count){
cur_data= cur_mod()-1;
cur_data_mod= mp_suffix_sym;
}
}
}
if(cur_data!=-1){
mp_node pp= mp_get_symbolic_node(mp);
set_mp_sym_info(pp,cur_data);
mp_name_type(pp)= cur_data_mod;
mp_link(p)= pp;
}else{
mp_link(p)= mp_cur_tok(mp);
}
p= mp_link(p);
}
mp_link(p)= tail_end;
while(subst_list){
q= subst_list->link;
xfree(subst_list);
subst_list= q;
}
return mp_link(mp->hold_head);
}

/*:756*//*757:*/
#line 19251 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_sym(mp_sym sym){
printf("{type = %d, v = {type = %d, data = {indep = {scale = %d, serial = %d}, n = %d, str = %p, sym = %p, node = %p, p = %p}}, text = %p}\n",sym->type,sym->v.type,(int)sym->v.data.indep.scale,(int)sym->v.data.indep.serial,
sym->v.data.n.type,sym->v.data.str,sym->v.data.sym,sym->v.data.node,sym->v.data.p,sym->text);
if(is_number(sym->v.data.n)){
mp_number n= sym->v.data.n;
printf("{data = {dval = %f, val = %d}, type = %d}\n",n.data.dval,n.data.val,n.type);
}
if(sym->text!=NULL){
mp_string t= sym->text;
printf("{str = %p \"%s\", len = %d, refs = %d}\n",t->str,t->str,(int)t->len,t->refs);
}
}

/*:757*//*763:*/
#line 19337 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_get_symbol(MP mp){
RESTART:
get_t_next(mp);
if((cur_sym()==NULL)||mp_is_frozen(mp,cur_sym())){
const char*hlp[]= {
"Sorry: You can\'t redefine a number, string, or expr.",
"I've inserted an inaccessible symbol so that your",
"definition will be completed without mixing me up too badly.",
NULL};
if(cur_sym()!=NULL)
hlp[0]= "Sorry: You can\'t redefine my error-recovery tokens.";
else if(cur_cmd()==mp_string_token)
delete_str_ref(cur_mod_str());
set_cur_sym(mp->frozen_inaccessible);
mp_ins_error(mp,"Missing symbolic token inserted",hlp,true);
;
goto RESTART;
}
}


/*:763*//*764:*/
#line 19363 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_get_clear_symbol(MP mp){
mp_get_symbol(mp);
mp_clear_symbol(mp,cur_sym(),false);
}


/*:764*//*765:*/
#line 19373 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_check_equals(MP mp){
if(cur_cmd()!=mp_equals)
if(cur_cmd()!=mp_assignment){
const char*hlp[]= {
"The next thing in this `def' should have been `=',",
"because I've already looked at the definition heading.",
"But don't worry; I'll pretend that an equals sign",
"was present. Everything from here to `enddef'",
"will be the replacement text of this macro.",
NULL};
mp_back_error(mp,"Missing `=' has been inserted",hlp,true);
;
}
}


/*:765*//*766:*/
#line 19394 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_make_op_def(MP mp){
mp_command_code m;
mp_node q,r;
mp_subst_list_item*qm= NULL,*qn= NULL;
m= cur_mod();
mp_get_symbol(mp);
qm= xmalloc(1,sizeof(mp_subst_list_item));
qm->link= NULL;
qm->info= cur_sym();
qm->info_mod= cur_sym_mod();
qm->value_data= 0;
qm->value_mod= mp_expr_sym;
mp_get_clear_symbol(mp);
mp->warning_info= cur_sym();
mp_get_symbol(mp);
qn= xmalloc(1,sizeof(mp_subst_list_item));
qn->link= qm;
qn->info= cur_sym();
qn->info_mod= cur_sym_mod();
qn->value_data= 1;
qn->value_mod= mp_expr_sym;
get_t_next(mp);
mp_check_equals(mp);
mp->scanner_status= op_defining;
q= mp_get_symbolic_node(mp);
set_ref_count(q,0);
r= mp_get_symbolic_node(mp);
mp_link(q)= r;
set_mp_sym_info(r,mp_general_macro);
mp_name_type(r)= mp_macro_sym;
mp_link(r)= mp_scan_toks(mp,mp_macro_def,qn,NULL,0);
mp->scanner_status= normal;
set_eq_type(mp->warning_info,m);
set_equiv_node(mp->warning_info,q);
mp_get_x_next(mp);
}


/*:766*//*769:*/
#line 19476 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_def(MP mp){
int m;
int n;
int k;
int c;
mp_subst_list_item*r= NULL,*rp= NULL;
mp_node q;
mp_node p;
quarterword sym_type;
mp_sym l_delim,r_delim;
m= cur_mod();
c= mp_general_macro;
mp_link(mp->hold_head)= NULL;
q= mp_get_symbolic_node(mp);
set_ref_count(q,0);
r= NULL;


if(m==start_def){
mp_get_clear_symbol(mp);
mp->warning_info= cur_sym();
get_t_next(mp);
mp->scanner_status= op_defining;
n= 0;
set_eq_type(mp->warning_info,mp_defined_macro);
set_equiv_node(mp->warning_info,q);
}else{
p= mp_scan_declared_variable(mp);
mp_flush_variable(mp,equiv_node(mp_sym_sym(p)),mp_link(p),true);
mp->warning_info_node= mp_find_variable(mp,p);
mp_flush_node_list(mp,p);
if(mp->warning_info_node==NULL){

const char*hlp[]= {
"After `vardef a' you can\'t say `vardef a.b'.",
"So I'll have to discard this definition.",
NULL};
mp_error(mp,"This variable already starts with a macro",hlp,true);
mp->warning_info_node= mp->bad_vardef;
}
mp->scanner_status= var_defining;
n= 2;
if(cur_cmd()==mp_macro_special&&cur_mod()==macro_suffix){
n= 3;
get_t_next(mp);
}
mp_type(mp->warning_info_node)= (quarterword)(mp_unsuffixed_macro-2+n);

set_value_node(mp->warning_info_node,q);
}

k= n;
if(cur_cmd()==mp_left_delimiter){

do{
l_delim= cur_sym();
r_delim= equiv_sym(cur_sym());
get_t_next(mp);
if((cur_cmd()==mp_param_type)&&(cur_mod()==mp_expr_param)){
sym_type= mp_expr_sym;
}else if((cur_cmd()==mp_param_type)&&(cur_mod()==mp_suffix_param)){
sym_type= mp_suffix_sym;
}else if((cur_cmd()==mp_param_type)&&(cur_mod()==mp_text_param)){
sym_type= mp_text_sym;
}else{
const char*hlp[]= {"You should've had `expr' or `suffix' or `text' here.",NULL};
mp_back_error(mp,"Missing parameter type; `expr' will be assumed",hlp,true);
sym_type= mp_expr_sym;
}

do{
mp_link(q)= mp_get_symbolic_node(mp);
q= mp_link(q);
mp_name_type(q)= sym_type;
set_mp_sym_info(q,k);
mp_get_symbol(mp);
rp= xmalloc(1,sizeof(mp_subst_list_item));
rp->link= NULL;
rp->value_data= k;
rp->value_mod= sym_type;
rp->info= cur_sym();
rp->info_mod= cur_sym_mod();
mp_check_param_size(mp,k);
incr(k);
rp->link= r;
r= rp;
get_t_next(mp);
}while(cur_cmd()==mp_comma);

mp_check_delimiter(mp,l_delim,r_delim);
get_t_next(mp);
}while(cur_cmd()==mp_left_delimiter);

}
if(cur_cmd()==mp_param_type){

rp= xmalloc(1,sizeof(mp_subst_list_item));
rp->link= NULL;
rp->value_data= k;
if(cur_mod()==mp_expr_param){
rp->value_mod= mp_expr_sym;
c= mp_expr_macro;
}else if(cur_mod()==mp_suffix_param){
rp->value_mod= mp_suffix_sym;
c= mp_suffix_macro;
}else if(cur_mod()==mp_text_param){
rp->value_mod= mp_text_sym;
c= mp_text_macro;
}else{
c= cur_mod();
rp->value_mod= mp_expr_sym;
}
mp_check_param_size(mp,k);
incr(k);
mp_get_symbol(mp);
rp->info= cur_sym();
rp->info_mod= cur_sym_mod();
rp->link= r;
r= rp;
get_t_next(mp);
if(c==mp_expr_macro){
if(cur_cmd()==mp_of_token){
c= mp_of_macro;
rp= xmalloc(1,sizeof(mp_subst_list_item));
rp->link= NULL;
mp_check_param_size(mp,k);
rp->value_data= k;
rp->value_mod= mp_expr_sym;
mp_get_symbol(mp);
rp->info= cur_sym();
rp->info_mod= cur_sym_mod();
rp->link= r;
r= rp;
get_t_next(mp);
}
}
}
mp_check_equals(mp);
p= mp_get_symbolic_node(mp);
set_mp_sym_info(p,c);
mp_name_type(p)= mp_macro_sym;
mp_link(q)= p;



if(m==start_def){
mp_link(p)= mp_scan_toks(mp,mp_macro_def,r,NULL,(quarterword)n);
}else{
mp_node qq= mp_get_symbolic_node(mp);
set_mp_sym_sym(qq,mp->bg_loc);
mp_link(p)= qq;
p= mp_get_symbolic_node(mp);
set_mp_sym_sym(p,mp->eg_loc);
mp_link(qq)= mp_scan_toks(mp,mp_macro_def,r,p,(quarterword)n);
}
if(mp->warning_info_node==mp->bad_vardef)
mp_flush_token_list(mp,value_node(mp->bad_vardef));
mp->scanner_status= normal;
mp_get_x_next(mp);
}

/*:769*//*776:*/
#line 19714 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_expansion_depth_error(MP mp){
const char*hlp[]= {
"Recursive macro expansion cannot be unlimited because of runtime",
"stack constraints. The limit is 10000 recursion levels in total.",
NULL};
if(mp->interaction==mp_error_stop_mode)
mp->interaction= mp_scroll_mode;
if(mp->log_opened)
mp_error(mp,"Maximum expansion depth reached",hlp,true);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}


/*:776*//*777:*/
#line 19732 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_expand(MP mp){
size_t k;
size_t j;
check_expansion_depth();
if(number_greater(internal_value(mp_tracing_commands),unity_t))
if(cur_cmd()!=mp_defined_macro)
show_cur_cmd_mod;
switch(cur_cmd()){
case mp_if_test:
mp_conditional(mp);
break;
case mp_fi_or_else:
/*832:*/
#line 20990 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_mod()> mp->if_limit){
if(mp->if_limit==if_code){
const char*hlp[]= {"Something was missing here",NULL};
mp_back_input(mp);
set_cur_sym(mp->frozen_colon);
mp_ins_error(mp,"Missing `:' has been inserted",hlp,true);
;
}else{
const char*hlp[]= {"I'm ignoring this; it doesn't match any if.",NULL};
if(cur_mod()==fi_code){
mp_error(mp,"Extra fi",hlp,true);
;
}else if(cur_mod()==else_code){
mp_error(mp,"Extra else",hlp,true);

}else{
mp_error(mp,"Extra elseif",hlp,true);

}
}
}else{
while(cur_mod()!=fi_code)
mp_pass_text(mp);
/*826:*/
#line 20867 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node p= mp->cond_ptr;
mp->if_line= if_line_field(p);
mp->cur_if= mp_name_type(p);
mp->if_limit= mp_type(p);
mp->cond_ptr= mp_link(p);
mp_free_node(mp,p,if_node_size);
}


/*:826*/
#line 21014 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:832*/
#line 19745 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_input:
/*781:*/
#line 19816 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_mod()> 0)
mp->force_eof= true;
else
mp_start_input(mp)


/*:781*/
#line 19748 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_iteration:
if(cur_mod()==end_for){
/*778:*/
#line 19787 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"I'm not currently working on a for loop,",
"so I had better not try to end anything.",
NULL};
mp_error(mp,"Extra `endfor'",hlp,true);
;
}


/*:778*/
#line 19752 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp_begin_iteration(mp);
}
break;
case mp_repeat_loop:
/*782:*/
#line 19827 "../../../source/texk/web2c/mplibdir/mp.w"

{
while(token_state&&(nloc==NULL))
mp_end_token_list(mp);
if(mp->loop_ptr==NULL){
const char*hlp[]= {
"I'm confused; after exiting from a loop, I still seem",
"to want to repeat it. I'll try to forget the problem.",
NULL};
mp_error(mp,"Lost loop",hlp,true);
;
}else{
mp_resume_iteration(mp);
}
}


/*:782*/
#line 19758 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_exit_test:
/*783:*/
#line 19844 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_get_boolean(mp);
if(number_greater(internal_value(mp_tracing_commands),unity_t))
mp_show_cmd_mod(mp,mp_nullary,cur_exp_value_boolean());
if(cur_exp_value_boolean()==mp_true_code){
if(mp->loop_ptr==NULL){
const char*hlp[]= {
"Why say `exitif' when there's nothing to exit from?",
NULL};
if(cur_cmd()==mp_semicolon)
mp_error(mp,"No loop is in progress",hlp,true);
else
mp_back_error(mp,"No loop is in progress",hlp,true);
;
}else{
/*784:*/
#line 19876 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node p= NULL;
do{
if(file_state){
mp_end_file_reading(mp);
}else{
if(token_type<=loop_text)
p= nstart;
mp_end_token_list(mp);
}
}while(p==NULL);
if(p!=mp->loop_ptr->info)
mp_fatal_error(mp,"*** (loop confusion)");
;
mp_stop_iteration(mp);
}


/*:784*/
#line 19860 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}else if(cur_cmd()!=mp_semicolon){
const char*hlp[]= {
"After `exitif <boolean exp>' I expect to see a semicolon.",
"I shall pretend that one was there.",
NULL};
mp_back_error(mp,"Missing `;' has been inserted",hlp,true);
;
}
}


/*:783*/
#line 19761 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_relax:
break;
case mp_expand_after:
/*785:*/
#line 19895 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node p;
get_t_next(mp);
p= mp_cur_tok(mp);
get_t_next(mp);
if(cur_cmd()<mp_min_command)
mp_expand(mp);
else
mp_back_input(mp);
back_list(p);
}


/*:785*/
#line 19766 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_scan_tokens:
/*786:*/
#line 19909 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_get_x_next(mp);
mp_scan_primary(mp);
if(mp->cur_exp.type!=mp_string_type){
mp_value new_expr;
const char*hlp[]= {
"I'm going to flush this expression, since",
"scantokens should be followed by a known string.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Not a string",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
mp_back_input(mp);
if(cur_exp_str()->len> 0)
/*791:*/
#line 20186 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_begin_file_reading(mp);
name= is_scantok;
k= mp->first+(size_t)cur_exp_str()->len;
if(k>=mp->max_buf_stack){
while(k>=mp->buf_size){
mp_reallocate_buffer(mp,(mp->buf_size+(mp->buf_size/4)));
}
mp->max_buf_stack= k+1;
}
j= 0;
limit= (halfword)k;
while(mp->first<(size_t)limit){
mp->buffer[mp->first]= *(cur_exp_str()->str+j);
j++;
incr(mp->first);
}
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
mp_flush_cur_exp(mp,new_expr);
}


/*:791*/
#line 19929 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}

/*:786*/
#line 19769 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_runscript:
/*788:*/
#line 19958 "../../../source/texk/web2c/mplibdir/mp.w"

{

if(mp->extensions==0){
return;
}
mp_get_x_next(mp);
mp_scan_primary(mp);
if(mp->cur_exp.type!=mp_string_type){
mp_value new_expr;
const char*hlp[]= {
"I'm going to flush this expression, since",
"runscript should be followed by a known string.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Not a string",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
mp_back_input(mp);
if(cur_exp_str()->len> 0){
char*s= mp->run_script(mp,(const char*)cur_exp_str()->str);
/*787:*/
#line 19933 "../../../source/texk/web2c/mplibdir/mp.w"

if(s!=NULL){
int k;
mp_value new_expr;
size_t size= strlen(s);
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_begin_file_reading(mp);
name= is_scantok;
mp->last= mp->first;
k= mp->first+size;
if(k>=mp->max_buf_stack){
while(k>=mp->buf_size){
mp_reallocate_buffer(mp,(mp->buf_size+(mp->buf_size/4)));
}
mp->max_buf_stack= k+1;
}
limit= (halfword)k;
(void)memcpy((mp->buffer+mp->first),s,size);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
mp_flush_cur_exp(mp,new_expr);
}

/*:787*/
#line 19983 "../../../source/texk/web2c/mplibdir/mp.w"

free(s);
}
}
}

/*:788*/
#line 19772 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_maketext:
/*790:*/
#line 20156 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp->extensions==0){
return;
}
mp_get_x_next(mp);
mp_scan_primary(mp);
if(mp->cur_exp.type!=mp_string_type){
mp_value new_expr;
const char*hlp[]= {
"I'm going to flush this expression, since",
"maketext should be followed by a known string.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Not a string",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
mp_back_input(mp);
if(cur_exp_str()->len> 0){
char*s= mp->make_text(mp,(const char*)cur_exp_str()->str,0);
/*787:*/
#line 19933 "../../../source/texk/web2c/mplibdir/mp.w"

if(s!=NULL){
int k;
mp_value new_expr;
size_t size= strlen(s);
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_begin_file_reading(mp);
name= is_scantok;
mp->last= mp->first;
k= mp->first+size;
if(k>=mp->max_buf_stack){
while(k>=mp->buf_size){
mp_reallocate_buffer(mp,(mp->buf_size+(mp->buf_size/4)));
}
mp->max_buf_stack= k+1;
}
limit= (halfword)k;
(void)memcpy((mp->buffer+mp->first),s,size);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
mp_flush_cur_exp(mp,new_expr);
}

/*:787*/
#line 20180 "../../../source/texk/web2c/mplibdir/mp.w"

free(s);
}
}
}

/*:790*/
#line 19775 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_defined_macro:
mp_macro_call(mp,cur_mod_node(),NULL,cur_sym());
break;
default:
break;
};
mp->expand_depth_count--;
}


/*:777*//*793:*/
#line 20225 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_get_x_next(MP mp){
mp_node save_exp;
get_t_next(mp);
if(cur_cmd()<mp_min_command){
save_exp= mp_stash_cur_exp(mp);
do{
if(cur_cmd()==mp_defined_macro)
mp_macro_call(mp,cur_mod_node(),NULL,cur_sym());
else
mp_expand(mp);
get_t_next(mp);
}while(cur_cmd()<mp_min_command);
mp_unstash_cur_exp(mp,save_exp);
}
}


/*:793*//*796:*/
#line 20278 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_macro_call(MP mp,mp_node def_ref,mp_node arg_list,mp_sym macro_name){

mp_node r;
mp_node p,q;
integer n;
mp_node tail= 0;
mp_sym l_delim= NULL,r_delim= NULL;
r= mp_link(def_ref);
add_mac_ref(def_ref);
if(arg_list==NULL){
n= 0;
}else{
/*802:*/
#line 20370 "../../../source/texk/web2c/mplibdir/mp.w"

{
n= 1;
tail= arg_list;
while(mp_link(tail)!=NULL){
incr(n);
tail= mp_link(tail);
}
}


/*:802*/
#line 20292 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
if(number_positive(internal_value(mp_tracing_macros))){
/*797:*/
#line 20303 "../../../source/texk/web2c/mplibdir/mp.w"

mp_begin_diagnostic(mp);
mp_print_ln(mp);
mp_print_macro_name(mp,arg_list,macro_name);
if(n==3)
mp_print(mp,"@#");
mp_show_macro(mp,def_ref,NULL,100000);
if(arg_list!=NULL){
n= 0;
p= arg_list;
do{
q= (mp_node)mp_sym_sym(p);
mp_print_arg(mp,q,n,0,0);
incr(n);
p= mp_link(p);
}while(p!=NULL);
}
mp_end_diagnostic(mp,false)


/*:797*/
#line 20295 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
/*803:*/
#line 20381 "../../../source/texk/web2c/mplibdir/mp.w"

set_cur_cmd(mp_comma+1);
while(mp_name_type(r)==mp_expr_sym||
mp_name_type(r)==mp_suffix_sym||mp_name_type(r)==mp_text_sym){
/*804:*/
#line 20423 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_cmd()!=mp_comma){
mp_get_x_next(mp);
if(cur_cmd()!=mp_left_delimiter){
char msg[256];
const char*hlp[]= {
"That macro has more parameters than you thought.",
"I'll continue by pretending that each missing argument",
"is either zero or null.",
NULL};
mp_string sname;
int old_setting= mp->selector;
mp->selector= new_string;
mp_print_macro_name(mp,arg_list,macro_name);
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Missing argument to %s",mp_str(mp,sname));
;
delete_str_ref(sname);
if(mp_name_type(r)==mp_suffix_sym||mp_name_type(r)==mp_text_sym){
set_cur_exp_value_number(zero_t);
mp->cur_exp.type= mp_token_list;
}else{
set_cur_exp_value_number(zero_t);
mp->cur_exp.type= mp_known;
}
mp_back_error(mp,msg,hlp,true);
set_cur_cmd((mp_variable_type)mp_right_delimiter);
goto FOUND;
}
l_delim= cur_sym();
r_delim= equiv_sym(cur_sym());
}
/*807:*/
#line 20514 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp_name_type(r)==mp_text_sym){
mp_scan_text_arg(mp,l_delim,r_delim);
}else{
mp_get_x_next(mp);
if(mp_name_type(r)==mp_suffix_sym)
mp_scan_suffix(mp);
else
mp_scan_expression(mp);
}


/*:807*/
#line 20456 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(cur_cmd()!=mp_comma)
/*805:*/
#line 20463 "../../../source/texk/web2c/mplibdir/mp.w"

if((cur_cmd()!=mp_right_delimiter)||(equiv_sym(cur_sym())!=l_delim)){
if(mp_name_type(mp_link(r))==mp_expr_sym||
mp_name_type(mp_link(r))==mp_suffix_sym||
mp_name_type(mp_link(r))==mp_text_sym){
const char*hlp[]= {
"I've finished reading a macro argument and am about to",
"read another; the arguments weren't delimited correctly.",
"You might want to delete some tokens before continuing.",
NULL};
mp_back_error(mp,"Missing `,' has been inserted",hlp,true);
;
set_cur_cmd((mp_variable_type)mp_comma);
}else{
char msg[256];
const char*hlp[]= {
"I've gotten to the end of the macro parameter list.",
"You might want to delete some tokens before continuing.",
NULL};
mp_snprintf(msg,256,"Missing `%s' has been inserted",mp_str(mp,text(r_delim)));
;
mp_back_error(mp,msg,hlp,true);
}
}

/*:805*/
#line 20458 "../../../source/texk/web2c/mplibdir/mp.w"
;
FOUND:
/*806:*/
#line 20492 "../../../source/texk/web2c/mplibdir/mp.w"

{
p= mp_get_symbolic_node(mp);
if(mp->cur_exp.type==mp_token_list)
set_mp_sym_sym(p,mp->cur_exp.data.node);
else
set_mp_sym_sym(p,mp_stash_cur_exp(mp));
if(number_positive(internal_value(mp_tracing_macros))){
mp_begin_diagnostic(mp);
mp_print_arg(mp,(mp_node)mp_sym_sym(p),n,mp_sym_info(r),mp_name_type(r));
mp_end_diagnostic(mp,false);
}
if(arg_list==NULL){
arg_list= p;
}else{
mp_link(tail)= p;
}
tail= p;
incr(n);
}


/*:806*/
#line 20460 "../../../source/texk/web2c/mplibdir/mp.w"



/*:804*/
#line 20385 "../../../source/texk/web2c/mplibdir/mp.w"
;
r= mp_link(r);
}
if(cur_cmd()==mp_comma){
char msg[256];
const char*hlp[]= {
"I'm going to assume that the comma I just read was a",
"right delimiter, and then I'll begin expanding the macro.",
"You might want to delete some tokens before continuing.",
NULL};
mp_string rname;
int old_setting= mp->selector;
mp->selector= new_string;
mp_print_macro_name(mp,arg_list,macro_name);
rname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Too many arguments to %s; Missing `%s' has been inserted",
mp_str(mp,rname),mp_str(mp,text(r_delim)));
delete_str_ref(rname);
;
;
mp_error(mp,msg,hlp,true);
}
if(mp_sym_info(r)!=mp_general_macro){
/*812:*/
#line 20583 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_sym_info(r)<mp_text_macro){
mp_get_x_next(mp);
if(mp_sym_info(r)!=mp_suffix_macro){
if((cur_cmd()==mp_equals)||(cur_cmd()==mp_assignment))
mp_get_x_next(mp);
}
}
switch(mp_sym_info(r)){
case mp_primary_macro:
mp_scan_primary(mp);
break;
case mp_secondary_macro:
mp_scan_secondary(mp);
break;
case mp_tertiary_macro:
mp_scan_tertiary(mp);
break;
case mp_expr_macro:
mp_scan_expression(mp);
break;
case mp_of_macro:
/*813:*/
#line 20620 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_scan_expression(mp);
p= mp_get_symbolic_node(mp);
set_mp_sym_sym(p,mp_stash_cur_exp(mp));
if(number_positive(internal_value(mp_tracing_macros))){
mp_begin_diagnostic(mp);
mp_print_arg(mp,(mp_node)mp_sym_sym(p),n,0,0);
mp_end_diagnostic(mp,false);
}
if(arg_list==NULL)
arg_list= p;
else
mp_link(tail)= p;
tail= p;
incr(n);
if(cur_cmd()!=mp_of_token){
char msg[256];
mp_string sname;
const char*hlp[]= {
"I've got the first argument; will look now for the other.",
NULL};
int old_setting= mp->selector;
mp->selector= new_string;
mp_print_macro_name(mp,arg_list,macro_name);
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Missing `of' has been inserted for %s",mp_str(mp,sname));
delete_str_ref(sname);
;
mp_back_error(mp,msg,hlp,true);
}
mp_get_x_next(mp);
mp_scan_primary(mp);
}


/*:813*/
#line 20606 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_suffix_macro:
/*814:*/
#line 20657 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(cur_cmd()!=mp_left_delimiter){
l_delim= NULL;
}else{
l_delim= cur_sym();
r_delim= equiv_sym(cur_sym());
mp_get_x_next(mp);
}
mp_scan_suffix(mp);
if(l_delim!=NULL){
if((cur_cmd()!=mp_right_delimiter)||(equiv_sym(cur_sym())!=l_delim)){
char msg[256];
const char*hlp[]= {
"I've gotten to the end of the macro parameter list.",
"You might want to delete some tokens before continuing.",
NULL};
mp_snprintf(msg,256,"Missing `%s' has been inserted",mp_str(mp,text(r_delim)));
;
mp_back_error(mp,msg,hlp,true);
}
mp_get_x_next(mp);
}
}


/*:814*/
#line 20609 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_text_macro:
mp_scan_text_arg(mp,NULL,NULL);
break;
}
mp_back_input(mp);
/*806:*/
#line 20492 "../../../source/texk/web2c/mplibdir/mp.w"

{
p= mp_get_symbolic_node(mp);
if(mp->cur_exp.type==mp_token_list)
set_mp_sym_sym(p,mp->cur_exp.data.node);
else
set_mp_sym_sym(p,mp_stash_cur_exp(mp));
if(number_positive(internal_value(mp_tracing_macros))){
mp_begin_diagnostic(mp);
mp_print_arg(mp,(mp_node)mp_sym_sym(p),n,mp_sym_info(r),mp_name_type(r));
mp_end_diagnostic(mp,false);
}
if(arg_list==NULL){
arg_list= p;
}else{
mp_link(tail)= p;
}
tail= p;
incr(n);
}


/*:806*/
#line 20616 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:812*/
#line 20409 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
r= mp_link(r)


/*:803*/
#line 20298 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*815:*/
#line 20687 "../../../source/texk/web2c/mplibdir/mp.w"

while(token_state&&(nloc==NULL))
mp_end_token_list(mp);
if(mp->param_ptr+n> mp->max_param_stack){
mp->max_param_stack= mp->param_ptr+n;
mp_check_param_size(mp,mp->max_param_stack);

}
mp_begin_token_list(mp,def_ref,(quarterword)macro);
if(macro_name)
name= text(macro_name);
else
name= NULL;
nloc= r;
if(n> 0){
p= arg_list;
do{
mp->param_stack[mp->param_ptr]= (mp_node)mp_sym_sym(p);
incr(mp->param_ptr);
p= mp_link(p);
}while(p!=NULL);
mp_flush_node_list(mp,arg_list);
}

/*:815*/
#line 20299 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:796*//*799:*/
#line 20326 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_macro_name(MP mp,mp_node a,mp_sym n){
mp_node p,q;
if(n!=NULL){
mp_print_text(n);
}else{
p= (mp_node)mp_sym_sym(a);
if(p==NULL){
mp_print_text(mp_sym_sym((mp_node)mp_sym_sym(mp_link(a))));
}else{
q= p;
while(mp_link(q)!=NULL)
q= mp_link(q);
mp_link(q)= (mp_node)mp_sym_sym(mp_link(a));
mp_show_token_list(mp,p,NULL,1000,0);
mp_link(q)= NULL;
}
}
}


/*:799*//*801:*/
#line 20351 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_arg(MP mp,mp_node q,integer n,halfword b,quarterword bb){
if(q&&mp_link(q)==MP_VOID){
mp_print_nl(mp,"(EXPR");
}else{
if((bb<mp_text_sym)&&(b!=mp_text_macro))
mp_print_nl(mp,"(SUFFIX");
else
mp_print_nl(mp,"(TEXT");
}
mp_print_int(mp,n);
mp_print(mp,")<-");
if(q&&mp_link(q)==MP_VOID)
mp_print_exp(mp,q,1);
else
mp_show_token_list(mp,q,NULL,1000,0);
}


/*:801*//*809:*/
#line 20534 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_scan_text_arg(MP mp,mp_sym l_delim,mp_sym r_delim){
integer balance;
mp_node p;
mp->warning_info= l_delim;
mp->scanner_status= absorbing;
p= mp->hold_head;
balance= 1;
mp_link(mp->hold_head)= NULL;
while(1){
get_t_next(mp);
if(l_delim==NULL){
/*811:*/
#line 20571 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp_end_of_statement){
if(balance==1){
break;
}else{
if(cur_cmd()==mp_end_group)
decr(balance);
}
}else if(cur_cmd()==mp_begin_group){
incr(balance);
}

/*:811*/
#line 20546 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
/*810:*/
#line 20559 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_cmd()==mp_right_delimiter){
if(equiv_sym(cur_sym())==l_delim){
decr(balance);
if(balance==0)
break;
}
}else if(cur_cmd()==mp_left_delimiter){
if(equiv_sym(cur_sym())==r_delim)
incr(balance);
}

/*:810*/
#line 20548 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp_link(p)= mp_cur_tok(mp);
p= mp_link(p);
}
set_cur_exp_node(mp_link(mp->hold_head));
mp->cur_exp.type= mp_token_list;
mp->scanner_status= normal;
}


/*:809*//*816:*/
#line 20714 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_stack_argument(MP mp,mp_node p){
if(mp->param_ptr==mp->max_param_stack){
incr(mp->max_param_stack);
mp_check_param_size(mp,mp->max_param_stack);
}
mp->param_stack[mp->param_ptr]= p;
incr(mp->param_ptr);
}


/*:816*//*818:*/
#line 20759 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_get_if_node(MP mp){
mp_if_node p= (mp_if_node)malloc_node(if_node_size);
mp_type(p)= mp_if_node_type;
return(mp_node)p;
}


/*:818*//*823:*/
#line 20818 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_pass_text(MP mp){
integer l= 0;
mp->scanner_status= skipping;
mp->warning_line= mp_true_line(mp);
while(1){
get_t_next(mp);
if(cur_cmd()<=mp_fi_or_else){
if(cur_cmd()<mp_fi_or_else){
incr(l);
}else{
if(l==0)
break;
if(cur_mod()==fi_code)
decr(l);
}
}else{
/*824:*/
#line 20843 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_cmd()==mp_string_token){
delete_str_ref(cur_mod_str());
}

/*:824*/
#line 20836 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
mp->scanner_status= normal;
}


/*:823*//*827:*/
#line 20881 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_change_if_limit(MP mp,quarterword l,mp_node p){
mp_node q;
if(p==mp->cond_ptr){
mp->if_limit= l;
}else{
q= mp->cond_ptr;
while(1){
if(q==NULL)
mp_confusion(mp,"if");
;
assert(q);
if(mp_link(q)==p){
mp_type(q)= l;
return;
}
q= mp_link(q);
}
}
}


/*:827*//*828:*/
#line 20906 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_check_colon(MP mp){
if(cur_cmd()!=mp_colon){
const char*hlp[]= {
"There should've been a colon after the condition.",
"I shall pretend that one was there.",
NULL};
mp_back_error(mp,"Missing `:' has been inserted",hlp,true);
;
}
}


/*:828*//*829:*/
#line 20924 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_conditional(MP mp){
mp_node save_cond_ptr;
int new_if_limit;
mp_node p;
/*825:*/
#line 20853 "../../../source/texk/web2c/mplibdir/mp.w"

{
p= mp_get_if_node(mp);
mp_link(p)= mp->cond_ptr;
mp_type(p)= (quarterword)mp->if_limit;
mp_name_type(p)= mp->cur_if;
if_line_field(p)= mp->if_line;
mp->cond_ptr= p;
mp->if_limit= if_code;
mp->if_line= mp_true_line(mp);
mp->cur_if= if_code;
}


/*:825*/
#line 20929 "../../../source/texk/web2c/mplibdir/mp.w"
;
save_cond_ptr= mp->cond_ptr;
RESWITCH:
mp_get_boolean(mp);
new_if_limit= else_if_code;
if(number_greater(internal_value(mp_tracing_commands),unity_t)){
/*831:*/
#line 20975 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_begin_diagnostic(mp);
if(cur_exp_value_boolean()==mp_true_code)
mp_print(mp,"{true}");
else
mp_print(mp,"{false}");
mp_end_diagnostic(mp,false);
}


/*:831*/
#line 20935 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
FOUND:
mp_check_colon(mp);
if(cur_exp_value_boolean()==mp_true_code){
mp_change_if_limit(mp,(quarterword)new_if_limit,save_cond_ptr);
return;
};
/*830:*/
#line 20965 "../../../source/texk/web2c/mplibdir/mp.w"

while(1){
mp_pass_text(mp);
if(mp->cond_ptr==save_cond_ptr)
goto DONE;
else if(cur_mod()==fi_code)
/*826:*/
#line 20867 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node p= mp->cond_ptr;
mp->if_line= if_line_field(p);
mp->cur_if= mp_name_type(p);
mp->if_limit= mp_type(p);
mp->cond_ptr= mp_link(p);
mp_free_node(mp,p,if_node_size);
}


/*:826*/
#line 20971 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:830*/
#line 20943 "../../../source/texk/web2c/mplibdir/mp.w"
;
DONE:
mp->cur_if= (quarterword)cur_mod();
mp->if_line= mp_true_line(mp);
if(cur_mod()==fi_code){
/*826:*/
#line 20867 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node p= mp->cond_ptr;
mp->if_line= if_line_field(p);
mp->cur_if= mp_name_type(p);
mp->if_limit= mp_type(p);
mp->cond_ptr= mp_link(p);
mp_free_node(mp,p,if_node_size);
}


/*:826*/
#line 20948 "../../../source/texk/web2c/mplibdir/mp.w"

}else if(cur_mod()==else_if_code){
goto RESWITCH;
}else{
set_cur_exp_value_boolean(mp_true_code);
new_if_limit= fi_code;
mp_get_x_next(mp);
goto FOUND;
}
}


/*:829*//*836:*/
#line 21076 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_for(MP mp,const char*s){
char msg[256];
mp_value new_expr;
const char*hlp[]= {"When you say `for x=a step b until c',",
"the initial value `a' and the step size `b'",
"and the final value `c' must have known numeric values.",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);

mp_snprintf(msg,256,"Improper %s has been replaced by 0",s);
;
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}


/*:836*//*837:*/
#line 21104 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_begin_iteration(MP mp){
halfword m;

mp_sym n;
mp_loop_data*s;
mp_subst_list_item*p= NULL;

mp_node q;
m= cur_mod();
n= cur_sym();
s= xmalloc(1,sizeof(mp_loop_data));
s->type= s->list= s->info= s->list_start= NULL;
s->link= NULL;s->var= NULL;
new_number(s->value);new_number(s->old_value);
new_number(s->step_size);
new_number(s->final_value);
if(m==start_forever){
s->type= MP_VOID;
p= NULL;
mp_get_x_next(mp);
}else{
mp_get_symbol(mp);
p= xmalloc(1,sizeof(mp_subst_list_item));
p->link= NULL;
p->info= cur_sym();
s->var= cur_sym();
p->info_mod= cur_sym_mod();
p->value_data= 0;
if(m==start_for){
p->value_mod= mp_expr_sym;
}else{
p->value_mod= mp_suffix_sym;
}
mp_get_x_next(mp);
if(cur_cmd()==mp_within_token){
/*850:*/
#line 21424 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_get_x_next(mp);
mp_scan_expression(mp);
/*851:*/
#line 21440 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->cur_exp.type!=mp_picture_type){
mp_value new_expr;
const char*hlp[]= {"When you say `for x in p', p must be a known picture.",NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
new_expr.data.node= (mp_node)mp_get_edge_header_node(mp);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Improper iteration spec has been replaced by nullpicture",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
mp_init_edges(mp,(mp_edge_header_node)mp->cur_exp.data.node);
mp->cur_exp.type= mp_picture_type;
}

/*:851*/
#line 21428 "../../../source/texk/web2c/mplibdir/mp.w"
;
s->type= mp->cur_exp.data.node;
mp->cur_exp.type= mp_vacuous;
q= mp_link(edge_list(mp->cur_exp.data.node));
if(q!=NULL)
if(is_start_or_stop(q))
if(mp_skip_1component(mp,q)==NULL)
q= mp_link(q);
s->list= q;
}


/*:850*/
#line 21140 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
/*838:*/
#line 21152 "../../../source/texk/web2c/mplibdir/mp.w"

if((cur_cmd()!=mp_equals)&&(cur_cmd()!=mp_assignment)){
const char*hlp[]= {
"The next thing in this loop should have been `=' or `:='.",
"But don't worry; I'll pretend that an equals sign",
"was present, and I'll look for the values next.",
NULL};
mp_back_error(mp,"Missing `=' has been inserted",hlp,true);
;
}

/*:838*/
#line 21142 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*848:*/
#line 21360 "../../../source/texk/web2c/mplibdir/mp.w"

s->type= NULL;
s->list= mp_get_symbolic_node(mp);
s->list_start= s->list;
q= s->list;
do{
mp_get_x_next(mp);
if(m!=start_for){
mp_scan_suffix(mp);
}else{
if(cur_cmd()>=mp_colon)
if(cur_cmd()<=mp_comma)
goto CONTINUE;
mp_scan_expression(mp);
if(cur_cmd()==mp_step_token)
if(q==s->list){
/*849:*/
#line 21392 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp->cur_exp.type!=mp_known)
mp_bad_for(mp,"initial value");
number_clone(s->value,cur_exp_value_number());
number_clone(s->old_value,cur_exp_value_number());
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known)
mp_bad_for(mp,"step size");
number_clone(s->step_size,cur_exp_value_number());
if(cur_cmd()!=mp_until_token){
const char*hlp[]= {
"I assume you meant to say `until' after `step'.",
"So I'll look for the final value and colon next.",
NULL};
mp_back_error(mp,"Missing `until' has been inserted",hlp,true);
;
}
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known)
mp_bad_for(mp,"final value");
number_clone(s->final_value,cur_exp_value_number());
s->type= PROGRESSION_FLAG;
break;
}


/*:849*/
#line 21376 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
set_cur_exp_node(mp_stash_cur_exp(mp));
}
mp_link(q)= mp_get_symbolic_node(mp);
q= mp_link(q);
set_mp_sym_sym(q,mp->cur_exp.data.node);
if(m==start_for)
mp_name_type(q)= mp_expr_sym;
else if(m==start_forsuffixes)
mp_name_type(q)= mp_suffix_sym;
mp->cur_exp.type= mp_vacuous;
CONTINUE:
;
}while(cur_cmd()==mp_comma)

/*:848*/
#line 21143 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
/*839:*/
#line 21163 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_cmd()!=mp_colon){
const char*hlp[]= {
"The next thing in this loop should have been a `:'.",
"So I'll pretend that a colon was present;",
"everything from here to `endfor' will be iterated.",
NULL};
mp_back_error(mp,"Missing `:' has been inserted",hlp,true);
;
}

/*:839*/
#line 21146 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*841:*/
#line 21184 "../../../source/texk/web2c/mplibdir/mp.w"

q= mp_get_symbolic_node(mp);
set_mp_sym_sym(q,mp->frozen_repeat_loop);
mp->scanner_status= loop_defining;
mp->warning_info= n;
s->info= mp_scan_toks(mp,mp_iteration,p,q,0);
mp->scanner_status= normal;
s->link= mp->loop_ptr;
mp->loop_ptr= s

/*:841*/
#line 21147 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_resume_iteration(mp);
}


/*:837*//*843:*/
#line 21201 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_resume_iteration(MP mp){
mp_node p,q;
p= mp->loop_ptr->type;
if(p==PROGRESSION_FLAG){
set_cur_exp_value_number(mp->loop_ptr->value);
if(/*844:*/
#line 21271 "../../../source/texk/web2c/mplibdir/mp.w"

(number_positive(mp->loop_ptr->step_size)&&number_greater(cur_exp_value_number(),mp->loop_ptr->final_value))
||
(number_negative(mp->loop_ptr->step_size)&&number_less(cur_exp_value_number(),mp->loop_ptr->final_value))


/*:844*/
#line 21207 "../../../source/texk/web2c/mplibdir/mp.w"
){
mp_stop_iteration(mp);
return;
}
mp->cur_exp.type= mp_known;
q= mp_stash_cur_exp(mp);
number_clone(mp->loop_ptr->old_value,cur_exp_value_number());
set_number_from_addition(mp->loop_ptr->value,cur_exp_value_number(),mp->loop_ptr->step_size);


if(number_positive(mp->loop_ptr->step_size)&&
number_less(mp->loop_ptr->value,cur_exp_value_number())){
if(number_positive(mp->loop_ptr->final_value)){
number_clone(mp->loop_ptr->value,mp->loop_ptr->final_value);
number_add_scaled(mp->loop_ptr->final_value,-1);
}else{
number_clone(mp->loop_ptr->value,mp->loop_ptr->final_value);
number_add_scaled(mp->loop_ptr->value,1);
}
}else if(number_negative(mp->loop_ptr->step_size)&&
number_greater(mp->loop_ptr->value,cur_exp_value_number())){
if(number_negative(mp->loop_ptr->final_value)){
number_clone(mp->loop_ptr->value,mp->loop_ptr->final_value);
number_add_scaled(mp->loop_ptr->final_value,1);
}else{
number_clone(mp->loop_ptr->value,mp->loop_ptr->final_value);
number_add_scaled(mp->loop_ptr->value,-1);
}
}
}else if(p==NULL){
p= mp->loop_ptr->list;
if(p!=NULL&&p==mp->loop_ptr->list_start){
q= p;
p= mp_link(p);
mp_free_symbolic_node(mp,q);
mp->loop_ptr->list= p;
}
if(p==NULL){
mp_stop_iteration(mp);
return;
}
mp->loop_ptr->list= mp_link(p);
q= (mp_node)mp_sym_sym(p);
if(q)
number_clone(mp->loop_ptr->old_value,q->data.n);
mp_free_symbolic_node(mp,p);
}else if(p==MP_VOID){
mp_begin_token_list(mp,mp->loop_ptr->info,(quarterword)forever_text);
return;
}else{
/*846:*/
#line 21292 "../../../source/texk/web2c/mplibdir/mp.w"

{
q= mp->loop_ptr->list;
if(q==NULL)
goto NOT_FOUND;
if(!is_start_or_stop(q))
q= mp_link(q);
else if(!is_stop(q))
q= mp_skip_1component(mp,q);
else
goto NOT_FOUND;

set_cur_exp_node((mp_node)mp_copy_objects(mp,mp->loop_ptr->list,q));
mp_init_bbox(mp,(mp_edge_header_node)cur_exp_node());
mp->cur_exp.type= mp_picture_type;
mp->loop_ptr->list= q;
q= mp_stash_cur_exp(mp);
}


/*:846*/
#line 21258 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp_begin_token_list(mp,mp->loop_ptr->info,(quarterword)loop_text);
mp_stack_argument(mp,q);
if(number_greater(internal_value(mp_tracing_commands),unity_t)){
/*845:*/
#line 21277 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{loop value=");
;
if((q!=NULL)&&(mp_link(q)==MP_VOID))
mp_print_exp(mp,q,1);
else
mp_show_token_list(mp,q,NULL,50,0);
mp_print_char(mp,xord('}'));
mp_end_diagnostic(mp,false);
}


/*:845*/
#line 21263 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
return;
NOT_FOUND:
mp_stop_iteration(mp);
}


/*:843*//*847:*/
#line 21316 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_stop_iteration(MP mp){
mp_node p,q;
mp_loop_data*tmp;
p= mp->loop_ptr->type;
if(p==PROGRESSION_FLAG){
mp_free_symbolic_node(mp,mp->loop_ptr->list);
}else if(p==NULL){
q= mp->loop_ptr->list;
while(q!=NULL){
p= (mp_node)mp_sym_sym(q);
if(p!=NULL){
if(mp_link(p)==MP_VOID){
mp_recycle_value(mp,p);
mp_free_value_node(mp,p);
}else{
mp_flush_token_list(mp,p);

}
}
p= q;
q= mp_link(q);
mp_free_symbolic_node(mp,p);
}
}else if(p> PROGRESSION_FLAG){
delete_edge_ref(p);
}
tmp= mp->loop_ptr;
mp->loop_ptr= tmp->link;
mp_flush_token_list(mp,tmp->info);
free_number(tmp->value);
free_number(tmp->step_size);
free_number(tmp->final_value);
xfree(tmp);
}


/*:847*//*858:*/
#line 21556 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_begin_name(MP mp){
xfree(mp->cur_name);
xfree(mp->cur_area);
xfree(mp->cur_ext);
mp->area_delimiter= -1;
mp->ext_delimiter= -1;
mp->quoted_filename= false;
}


/*:858*//*859:*/
#line 21570 "../../../source/texk/web2c/mplibdir/mp.w"

#ifndef IS_DIR_SEP
#define IS_DIR_SEP(c) (c=='/' || c=='\\')
#endif
boolean mp_more_name(MP mp,ASCII_code c){
if(c=='"'){
mp->quoted_filename= !mp->quoted_filename;
}else if((c==' '||c=='\t')&&(mp->quoted_filename==false)){
return false;
}else{
if(IS_DIR_SEP(c)){
mp->area_delimiter= (integer)mp->cur_length;
mp->ext_delimiter= -1;
}else if(c=='.'){
mp->ext_delimiter= (integer)mp->cur_length;
}
append_char(c);
}
return true;
}


/*:859*//*860:*/
#line 21600 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_end_name(MP mp){
size_t s= 0;
size_t len;

if(mp->area_delimiter<0){
mp->cur_area= xstrdup("");
}else{
len= (size_t)mp->area_delimiter-s+1;
copy_pool_segment(mp->cur_area,s,len);
s+= len;
}
if(mp->ext_delimiter<0){
mp->cur_ext= xstrdup("");
len= (unsigned)(mp->cur_length-s);
}else{
copy_pool_segment(mp->cur_ext,mp->ext_delimiter,
(mp->cur_length-(size_t)mp->ext_delimiter));
len= (size_t)mp->ext_delimiter-s;
}
copy_pool_segment(mp->cur_name,s,len);
mp_reset_cur_string(mp);
}


/*:860*//*863:*/
#line 21655 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_pack_file_name(MP mp,const char*n,const char*a,const char*e){
integer k;
const char*j;
size_t slen;
k= 0;
assert(n!=NULL);
xfree(mp->name_of_file);
slen= strlen(n)+1;
if(a!=NULL)
slen+= strlen(a);
if(e!=NULL)
slen+= strlen(e);
mp->name_of_file= xmalloc(slen,1);
if(a!=NULL){
for(j= a;*j!='\0';j++){
append_to_name(*j);
}
}
for(j= n;*j!='\0';j++){
append_to_name(*j);
}
if(e!=NULL){
for(j= e;*j!='\0';j++){
append_to_name(*j);
}
}
mp->name_of_file[k]= 0;
}


/*:863*//*869:*/
#line 21728 "../../../source/texk/web2c/mplibdir/mp.w"

boolean mp_open_mem_name(MP mp){
if(mp->mem_name!=NULL){
size_t l= strlen(mp->mem_name);
char*s= xstrdup(mp->mem_name);
if(l> 4){
char*test= strstr(s,".mp");
if(test==NULL||test!=s+l-4){
s= xrealloc(s,l+5,1);
strcat(s,".mp");
}
}else{
s= xrealloc(s,l+5,1);
strcat(s,".mp");
}
s= (mp->find_file)(mp,s,"r",mp_filetype_program);
xfree(mp->name_of_file);
if(s==NULL)
return false;
mp->name_of_file= xstrdup(s);
mp->mem_file= (mp->open_file)(mp,s,"r",mp_filetype_program);
free(s);
if(mp->mem_file)
return true;
}
return false;
}
boolean mp_open_mem_file(MP mp){
if(mp->mem_file!=NULL)
return true;
if(mp_open_mem_name(mp))
return true;
if(mp_xstrcmp(mp->mem_name,"plain")){
wake_up_terminal();
wterm("Sorry, I can\'t find the '");
wterm(mp->mem_name);
wterm("' preload file; will try 'plain'.");
wterm_cr;
;
update_terminal();

xfree(mp->mem_name);
mp->mem_name= xstrdup("plain");
if(mp_open_mem_name(mp))
return true;
}
wake_up_terminal();
wterm_ln("I can't find the 'plain' preload file!\n");

;
return false;
}


/*:869*//*871:*/
#line 21789 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_string mp_make_name_string(MP mp){
int k;
int name_length= (int)strlen(mp->name_of_file);
str_room(name_length);
for(k= 0;k<name_length;k++){
append_char(xord((ASCII_code)mp->name_of_file[k]));
}
return mp_make_string(mp);
}


/*:871*//*872:*/
#line 21818 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_file_name(MP mp){
mp_begin_name(mp);
while(mp->buffer[loc]==' ')
incr(loc);
while(1){
if((mp->buffer[loc]==';')||(mp->buffer[loc]=='%'))
break;
if(!mp_more_name(mp,mp->buffer[loc]))
break;
incr(loc);
}
mp_end_name(mp);
}


/*:872*//*874:*/
#line 21839 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_str_scan_file(MP mp,mp_string s){
size_t p,q;
mp_begin_name(mp);
p= 0;
q= s->len;
while(p<q){
if(!mp_more_name(mp,*(s->str+p)))
break;
incr(p);
}
mp_end_name(mp);
}


/*:874*//*876:*/
#line 21859 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_ptr_scan_file(MP mp,char*s){
char*p,*q;
mp_begin_name(mp);
p= s;
q= p+strlen(s);
while(p<q){
if(!mp_more_name(mp,(ASCII_code)(*p)))
break;
p++;
}
mp_end_name(mp);
}


/*:876*//*883:*/
#line 21932 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_pack_job_name(MP mp,const char*s){
xfree(mp->cur_name);
mp->cur_name= xstrdup(mp->job_name);
xfree(mp->cur_area);
mp->cur_area= xstrdup("");
xfree(mp->cur_ext);
mp->cur_ext= xstrdup(s);
pack_cur_name;
}


/*:883*//*885:*/
#line 21954 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_prompt_file_name(MP mp,const char*s,const char*e){
size_t k;
char*saved_cur_name;
if(mp->interaction==mp_scroll_mode)
wake_up_terminal();
if(strcmp(s,"input file name")==0){
mp_print_err(mp,"I can\'t open file `");

}else{
mp_print_err(mp,"I can\'t write on file `");

}
if(strcmp(s,"file name for output")==0){
mp_print(mp,mp->name_of_file);
}else{
mp_print_file_name(mp,mp->cur_name,mp->cur_area,mp->cur_ext);
}
mp_print(mp,"'.");
if(strcmp(e,"")==0)
mp_show_context(mp);
mp_print_nl(mp,"Please type another ");
mp_print(mp,s);
;
if(mp->noninteractive||mp->interaction<mp_scroll_mode)
mp_fatal_error(mp,"*** (job aborted, file error in nonstop mode)");
;
saved_cur_name= xstrdup(mp->cur_name);
clear_terminal();
prompt_input(": ");
/*886:*/
#line 21996 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_begin_name(mp);
k= mp->first;
while((mp->buffer[k]==' ')&&(k<mp->last))
incr(k);
while(1){
if(k==mp->last)
break;
if(!mp_more_name(mp,mp->buffer[k]))
break;
incr(k);
}
mp_end_name(mp);
}


/*:886*/
#line 21984 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(strcmp(mp->cur_ext,"")==0)
mp->cur_ext= xstrdup(e);
if(strlen(mp->cur_name)==0){
mp->cur_name= saved_cur_name;
}else{
xfree(saved_cur_name);
}
pack_cur_name;
}


/*:885*//*887:*/
#line 22016 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_open_log_file(MP mp){
unsigned old_setting;
int k;
int l;
integer m;
const char*months= "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";

if(mp->log_opened)
return;
old_setting= mp->selector;
if(mp->job_name==NULL){
mp->job_name= xstrdup("mpout");
/*880:*/
#line 21913 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->job_name!=NULL){
if(internal_string(mp_job_name)!=0)
delete_str_ref(internal_string(mp_job_name));
set_internal_string(mp_job_name,mp_rts(mp,mp->job_name));
}

/*:880*/
#line 22029 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp_pack_job_name(mp,".log");
while(!mp_open_out(mp,&mp->log_file,mp_filetype_log)){
/*889:*/
#line 22070 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp->selector= term_only;
mp_prompt_file_name(mp,"transcript file name",".log");
}


/*:889*/
#line 22033 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp->log_name= xstrdup(mp->name_of_file);
mp->selector= log_only;
mp->log_opened= true;
/*890:*/
#line 22077 "../../../source/texk/web2c/mplibdir/mp.w"

{
wlog(mp->banner);
mp_print(mp,"  ");
mp_print_int(mp,round_unscaled(internal_value(mp_day)));
mp_print_char(mp,xord(' '));
m= round_unscaled(internal_value(mp_month));
for(k= 3*m-3;k<3*m;k++){
wlog_chr((unsigned char)months[k]);
}
mp_print_char(mp,xord(' '));
mp_print_int(mp,round_unscaled(internal_value(mp_year)));
mp_print_char(mp,xord(' '));
mp_print_dd(mp,round_unscaled(internal_value(mp_hour)));
mp_print_char(mp,xord(':'));
mp_print_dd(mp,round_unscaled(internal_value(mp_minute)));
}


/*:890*/
#line 22038 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp->input_stack[mp->input_ptr]= mp->cur_input;

if(!mp->noninteractive){
mp_print_nl(mp,"**");
;
l= mp->input_stack[0].limit_field-1;
for(k= 0;k<=l;k++)
mp_print_char(mp,mp->buffer[k]);
mp_print_ln(mp);
}
mp->selector= old_setting+2;
}


/*:887*//*891:*/
#line 22100 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_try_extension(MP mp,const char*ext){
mp_pack_file_name(mp,mp->cur_name,mp->cur_area,ext);
in_name= xstrdup(mp->cur_name);
in_area= xstrdup(mp->cur_area);
in_ext= xstrdup(ext);
if(mp_open_in(mp,&cur_file,mp_filetype_program)){
return true;
}else{
mp_pack_file_name(mp,mp->cur_name,NULL,ext);
return mp_open_in(mp,&cur_file,mp_filetype_program);
}
}


/*:891*//*892:*/
#line 22118 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_start_input(MP mp){
char*fname= NULL;
/*895:*/
#line 22186 "../../../source/texk/web2c/mplibdir/mp.w"

while(token_state&&(nloc==NULL))
mp_end_token_list(mp);
if(token_state){
const char*hlp[]= {
"Sorry...I've converted what follows to tokens,",
"possibly garbaging the name you gave.",
"Please delete the tokens and insert the name again.",
NULL};
mp_error(mp,"File names can't appear within macros",hlp,true);
;
}
if(file_state){
mp_scan_file_name(mp);
}else{
xfree(mp->cur_name);
mp->cur_name= xstrdup("");
xfree(mp->cur_ext);
mp->cur_ext= xstrdup("");
xfree(mp->cur_area);
mp->cur_area= xstrdup("");
}


/*:895*/
#line 22121 "../../../source/texk/web2c/mplibdir/mp.w"
;
while(1){
mp_begin_file_reading(mp);
if(strlen(mp->cur_ext)==0){
if(mp_try_extension(mp,".mp"))
break;
else if(mp_try_extension(mp,""))
break;
else if(mp_try_extension(mp,".mf"))
break;
}else if(mp_try_extension(mp,mp->cur_ext)){
break;
}
mp_end_file_reading(mp);
mp_prompt_file_name(mp,"input file name","");
}
name= mp_make_name_string(mp);
fname= xstrdup(mp->name_of_file);
if(mp->job_name==NULL){
mp->job_name= xstrdup(mp->cur_name);
/*880:*/
#line 21913 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->job_name!=NULL){
if(internal_string(mp_job_name)!=0)
delete_str_ref(internal_string(mp_job_name));
set_internal_string(mp_job_name,mp_rts(mp,mp->job_name));
}

/*:880*/
#line 22141 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
if(!mp->log_opened){
mp_open_log_file(mp);
}

if(((int)mp->term_offset+(int)strlen(fname))> (mp->max_print_line-2))
mp_print_ln(mp);
else if((mp->term_offset> 0)||(mp->file_offset> 0))
mp_print_char(mp,xord(' '));
mp_print_char(mp,xord('('));
incr(mp->open_parens);
mp_print(mp,fname);
xfree(fname);
update_terminal();
/*893:*/
#line 22166 "../../../source/texk/web2c/mplibdir/mp.w"

mp_flush_string(mp,name);
name= mp_rts(mp,mp->cur_name);
xfree(mp->cur_name)


/*:893*/
#line 22156 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*894:*/
#line 22175 "../../../source/texk/web2c/mplibdir/mp.w"

{
line= 1;
(void)mp_input_ln(mp,cur_file);
mp_firm_up_the_line(mp);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
}


/*:894*/
#line 22157 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:892*//*896:*/
#line 22213 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_start_mpx_input(MP mp){
char*origname= NULL;
mp_pack_file_name(mp,in_name,in_area,in_ext);
origname= xstrdup(mp->name_of_file);
mp_pack_file_name(mp,in_name,in_area,".mpx");
if(!(mp->run_make_mpx)(mp,origname,mp->name_of_file))
goto NOT_FOUND;
mp_begin_file_reading(mp);
if(!mp_open_in(mp,&cur_file,mp_filetype_program)){
mp_end_file_reading(mp);
goto NOT_FOUND;
}
name= mp_make_name_string(mp);
mp->mpx_name[iindex]= name;
add_str_ref(name);
/*894:*/
#line 22175 "../../../source/texk/web2c/mplibdir/mp.w"

{
line= 1;
(void)mp_input_ln(mp,cur_file);
mp_firm_up_the_line(mp);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
}


/*:894*/
#line 22229 "../../../source/texk/web2c/mplibdir/mp.w"
;
xfree(origname);
return;
NOT_FOUND:
/*903:*/
#line 22268 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {
"The two files given above are one of your source files",
"and an auxiliary file I need to read to find out what your",
"btex..etex blocks mean. If you don't know why I had trouble,",
"try running it manually through MPtoTeX, TeX, and DVItoMP",
NULL};
if(mp->interaction==mp_error_stop_mode)
wake_up_terminal();
mp_print_nl(mp,">> ");
mp_print(mp,origname);
mp_print_nl(mp,">> ");
mp_print(mp,mp->name_of_file);
xfree(origname);
if(mp->interaction==mp_error_stop_mode)
mp->interaction= mp_scroll_mode;
if(mp->log_opened)
mp_error(mp,"! Unable to read mpx file",hlp,true);
mp->history= mp_fatal_error_stop;
mp_jump_out(mp);
}

/*:903*/
#line 22233 "../../../source/texk/web2c/mplibdir/mp.w"
;
xfree(origname);
}


/*:896*//*902:*/
#line 22259 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_run_make_mpx(MP mp,char*origname,char*mtxname){
(void)mp;
(void)origname;
(void)mtxname;
return false;
}


/*:902*//*907:*/
#line 22325 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_start_read_input(MP mp,char*s,readf_index n){
mp_ptr_scan_file(mp,s);
pack_cur_name;
mp_begin_file_reading(mp);
if(!mp_open_in(mp,&mp->rd_file[n],(int)(mp_filetype_text+n)))
goto NOT_FOUND;
if(!mp_input_ln(mp,mp->rd_file[n])){
(mp->close_file)(mp,mp->rd_file[n]);
goto NOT_FOUND;
}
mp->rd_fname[n]= xstrdup(s);
return true;
NOT_FOUND:
mp_end_file_reading(mp);
return false;
}


/*:907*//*909:*/
#line 22349 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_open_write_file(MP mp,char*s,readf_index n){
mp_ptr_scan_file(mp,s);
pack_cur_name;
while(!mp_open_out(mp,&mp->wr_file[n],(int)(mp_filetype_text+n)))
mp_prompt_file_name(mp,"file name for write output","");
mp->wr_fname[n]= xstrdup(s);
}


/*:909*//*917:*/
#line 22659 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_unstash_cur_exp(MP mp,mp_node p){
mp->cur_exp.type= mp_type(p);
switch(mp->cur_exp.type){
case unknown_types:
case mp_transform_type:
case mp_color_type:
case mp_pair_type:
case mp_dependent:
case mp_proto_dependent:
case mp_independent:
case mp_cmykcolor_type:
set_cur_exp_node(p);
break;
case mp_token_list:
set_cur_exp_node(value_node(p));
mp_free_value_node(mp,p);
break;
case mp_path_type:
case mp_pen_type:
set_cur_exp_knot(value_knot(p));
mp_free_value_node(mp,p);
break;
case mp_string_type:
set_cur_exp_str(value_str(p));
mp_free_value_node(mp,p);
break;
case mp_picture_type:
set_cur_exp_node(value_node(p));
mp_free_value_node(mp,p);
break;
case mp_boolean_type:
case mp_known:
set_cur_exp_value_number(value_number(p));
mp_free_value_node(mp,p);
break;
default:
set_cur_exp_value_number(value_number(p));
if(value_knot(p)){
set_cur_exp_knot(value_knot(p));
}else if(value_node(p)){
set_cur_exp_node(value_node(p));
}else if(value_str(p)){
set_cur_exp_str(value_str(p));
}
mp_free_value_node(mp,p);
break;
}
}


/*:917*//*919:*/
#line 22725 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_exp(MP mp,mp_node p,quarterword verbosity){
boolean restore_cur_exp;
mp_variable_type t;
mp_number vv;
mp_node v= NULL;
new_number(vv);
if(p!=NULL){
restore_cur_exp= false;
}else{
p= mp_stash_cur_exp(mp);
restore_cur_exp= true;
}
t= mp_type(p);
if(t<mp_dependent){
if(t!=mp_vacuous&&t!=mp_known&&value_node(p)!=NULL)
v= value_node(p);
else
number_clone(vv,value_number(p));
}else if(t<mp_independent){
v= (mp_node)dep_list((mp_value_node)p);
}
/*920:*/
#line 22754 "../../../source/texk/web2c/mplibdir/mp.w"

switch(t){
case mp_vacuous:
mp_print(mp,"vacuous");
break;
case mp_boolean_type:
if(number_to_boolean(vv)==mp_true_code)
mp_print(mp,"true");
else
mp_print(mp,"false");
break;
case unknown_types:
case mp_numeric_type:
/*928:*/
#line 22957 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_print_type(mp,t);
if(v!=NULL){
mp_print_char(mp,xord(' '));
while((mp_name_type(v)==mp_capsule)&&(v!=p))
v= value_node(v);
mp_print_variable_name(mp,v);
};
}


/*:928*/
#line 22767 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_string_type:
mp_print_char(mp,xord('"'));
mp_print_str(mp,value_str(p));
mp_print_char(mp,xord('"'));
break;
case mp_pen_type:
case mp_path_type:
case mp_picture_type:
/*926:*/
#line 22915 "../../../source/texk/web2c/mplibdir/mp.w"

if(verbosity<=1){
mp_print_type(mp,t);
}else{
if(mp->selector==term_and_log)
if(number_nonpositive(internal_value(mp_tracing_online))){
mp->selector= term_only;
mp_print_type(mp,t);
mp_print(mp," (see the transcript file)");
mp->selector= term_and_log;
};
switch(t){
case mp_pen_type:
mp_print_pen(mp,value_knot(p),"",false);
break;
case mp_path_type:
mp_print_path(mp,value_knot(p),"",false);
break;
case mp_picture_type:
mp_print_edges(mp,v,"",false);
break;
default:
break;
}
}


/*:926*/
#line 22777 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_transform_type:
if(number_zero(vv)&&v==NULL)
mp_print_type(mp,t);
else
/*923:*/
#line 22848 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node vvv= v;
mp_print_char(mp,xord('('));
assert(vvv);
v= tx_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22854 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= ty_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22857 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= xx_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22860 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= xy_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22863 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= yx_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22866 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= yy_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22869 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(')'));
}


/*:923*/
#line 22783 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_color_type:
if(number_zero(vv)&&v==NULL)
mp_print_type(mp,t);
else
/*924:*/
#line 22874 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node vvv= v;
mp_print_char(mp,xord('('));
assert(vvv);
v= red_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22880 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= green_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22883 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= blue_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22886 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(')'));
}


/*:924*/
#line 22789 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_pair_type:
if(number_zero(vv)&&v==NULL)
mp_print_type(mp,t);
else
/*922:*/
#line 22834 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node vvv= v;
mp_print_char(mp,xord('('));
assert(vvv);
v= x_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22840 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= y_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22843 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(')'));
}


/*:922*/
#line 22795 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_cmykcolor_type:
if(number_zero(vv)&&v==NULL)
mp_print_type(mp,t);
else
/*925:*/
#line 22891 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node vvv= v;
mp_print_char(mp,xord('('));
assert(vvv);
v= cyan_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22897 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= magenta_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22900 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= yellow_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22903 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(','));
v= black_part(vvv);
/*921:*/
#line 22820 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp_type(v)==mp_known)
print_number(value_number(v));
else if(mp_type(v)==mp_independent)
mp_print_variable_name(mp,v);
else
mp_print_dp(mp,mp_type(v),(mp_value_node)dep_list((mp_value_node)v),
verbosity);
}


/*:921*/
#line 22906 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_char(mp,xord(')'));
}


/*:925*/
#line 22801 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_known:
print_number(vv);
break;
case mp_dependent:
case mp_proto_dependent:
mp_print_dp(mp,t,(mp_value_node)v,verbosity);
break;
case mp_independent:
mp_print_variable_name(mp,p);
break;
default:
mp_confusion(mp,"exp");
break;

}


/*:920*/
#line 22747 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(restore_cur_exp)
mp_unstash_cur_exp(mp,p);
free_number(vv);
}


/*:919*//*930:*/
#line 22976 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_disp_err(MP mp,mp_node p){
if(mp->interaction==mp_error_stop_mode)
wake_up_terminal();
mp_print_nl(mp,">> ");
;
mp_print_exp(mp,p,1);
}


/*:930*//*932:*/
#line 22992 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_flush_cur_exp(MP mp,mp_value v){
if(is_number(mp->cur_exp.data.n)){
free_number(mp->cur_exp.data.n);
}
switch(mp->cur_exp.type){
case unknown_types:
case mp_transform_type:
case mp_color_type:
case mp_pair_type:
case mp_dependent:
case mp_proto_dependent:
case mp_independent:
case mp_cmykcolor_type:
mp_recycle_value(mp,cur_exp_node());
mp_free_value_node(mp,cur_exp_node());
break;
case mp_string_type:
delete_str_ref(cur_exp_str());
break;
case mp_pen_type:
case mp_path_type:
mp_toss_knot_list(mp,cur_exp_knot());
break;
case mp_picture_type:
delete_edge_ref(cur_exp_node());
break;
default:
break;
}
mp->cur_exp= v;
mp->cur_exp.type= mp_known;
}


/*:932*//*934:*/
#line 23033 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_recycle_value(MP mp,mp_node p){
mp_variable_type t;
FUNCTION_TRACE2("mp_recycle_value(%p)\n",p);
if(p==NULL||p==MP_VOID)
return;
t= mp_type(p);
switch(t){
case mp_vacuous:
case mp_boolean_type:
case mp_known:
case mp_numeric_type:
break;
case unknown_types:
mp_ring_delete(mp,p);
break;
case mp_string_type:
delete_str_ref(value_str(p));
break;
case mp_path_type:
case mp_pen_type:
mp_toss_knot_list(mp,value_knot(p));
break;
case mp_picture_type:
delete_edge_ref(value_node(p));
break;
case mp_cmykcolor_type:
if(value_node(p)!=NULL){
mp_recycle_value(mp,cyan_part(value_node(p)));
mp_recycle_value(mp,magenta_part(value_node(p)));
mp_recycle_value(mp,yellow_part(value_node(p)));
mp_recycle_value(mp,black_part(value_node(p)));
mp_free_value_node(mp,cyan_part(value_node(p)));
mp_free_value_node(mp,magenta_part(value_node(p)));
mp_free_value_node(mp,black_part(value_node(p)));
mp_free_value_node(mp,yellow_part(value_node(p)));
mp_free_node(mp,value_node(p),cmykcolor_node_size);
}
break;
case mp_pair_type:
if(value_node(p)!=NULL){
mp_recycle_value(mp,x_part(value_node(p)));
mp_recycle_value(mp,y_part(value_node(p)));
mp_free_value_node(mp,x_part(value_node(p)));
mp_free_value_node(mp,y_part(value_node(p)));
mp_free_pair_node(mp,value_node(p));
}
break;
case mp_color_type:
if(value_node(p)!=NULL){
mp_recycle_value(mp,red_part(value_node(p)));
mp_recycle_value(mp,green_part(value_node(p)));
mp_recycle_value(mp,blue_part(value_node(p)));
mp_free_value_node(mp,red_part(value_node(p)));
mp_free_value_node(mp,green_part(value_node(p)));
mp_free_value_node(mp,blue_part(value_node(p)));
mp_free_node(mp,value_node(p),color_node_size);
}
break;
case mp_transform_type:
if(value_node(p)!=NULL){
mp_recycle_value(mp,tx_part(value_node(p)));
mp_recycle_value(mp,ty_part(value_node(p)));
mp_recycle_value(mp,xx_part(value_node(p)));
mp_recycle_value(mp,xy_part(value_node(p)));
mp_recycle_value(mp,yx_part(value_node(p)));
mp_recycle_value(mp,yy_part(value_node(p)));
mp_free_value_node(mp,tx_part(value_node(p)));
mp_free_value_node(mp,ty_part(value_node(p)));
mp_free_value_node(mp,xx_part(value_node(p)));
mp_free_value_node(mp,xy_part(value_node(p)));
mp_free_value_node(mp,yx_part(value_node(p)));
mp_free_value_node(mp,yy_part(value_node(p)));
mp_free_node(mp,value_node(p),transform_node_size);
}
break;
case mp_dependent:
case mp_proto_dependent:

{
mp_value_node qq= (mp_value_node)dep_list((mp_value_node)p);
while(dep_info(qq)!=NULL)
qq= (mp_value_node)mp_link(qq);
set_mp_link(prev_dep((mp_value_node)p),mp_link(qq));
set_prev_dep(mp_link(qq),prev_dep((mp_value_node)p));
set_mp_link(qq,NULL);
mp_flush_node_list(mp,(mp_node)dep_list((mp_value_node)p));
}
break;
case mp_independent:
/*935:*/
#line 23168 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_value_node q,r,s;
mp_node pp;
mp_number v;
mp_number test;
new_number(test);
new_number(v);
if(t<mp_dependent)
number_clone(v,value_number(p));
set_number_to_zero(mp->max_c[mp_dependent]);
set_number_to_zero(mp->max_c[mp_proto_dependent]);
mp->max_link[mp_dependent]= NULL;
mp->max_link[mp_proto_dependent]= NULL;
q= (mp_value_node)mp_link(mp->dep_head);
while(q!=mp->dep_head){
s= (mp_value_node)mp->temp_head;
set_mp_link(s,dep_list(q));
while(1){
r= (mp_value_node)mp_link(s);
if(dep_info(r)==NULL)
break;
if(dep_info(r)!=p){
s= r;
}else{
t= mp_type(q);
if(mp_link(s)==dep_list(q)){
set_dep_list(q,mp_link(r));
}
set_mp_link(s,mp_link(r));
set_dep_info(r,(mp_node)q);
number_clone(test,dep_value(r));
number_abs(test);
if(number_greater(test,mp->max_c[t])){

if(number_positive(mp->max_c[t])){
set_mp_link(mp->max_ptr[t],(mp_node)mp->max_link[t]);
mp->max_link[t]= mp->max_ptr[t];
}
number_clone(mp->max_c[t],test);
mp->max_ptr[t]= r;
}else{
set_mp_link(r,(mp_node)mp->max_link[t]);
mp->max_link[t]= r;
}
}
}
q= (mp_value_node)mp_link(r);
}
if(number_positive(mp->max_c[mp_dependent])||number_positive(mp->max_c[mp_proto_dependent])){



mp_number test,ret;
new_number(ret);
new_number(test);
number_clone(test,mp->max_c[mp_dependent]);
number_divide_int(test,4096);
if(number_greaterequal(test,mp->max_c[mp_proto_dependent]))
t= mp_dependent;
else
t= mp_proto_dependent;











s= mp->max_ptr[t];
pp= (mp_node)dep_info(s);
number_clone(v,dep_value(s));
if(t==mp_dependent){
set_dep_value(s,fraction_one_t);
}else{
set_dep_value(s,unity_t);
}
number_negate(dep_value(s));
r= (mp_value_node)dep_list((mp_value_node)pp);
set_mp_link(s,(mp_node)r);
while(dep_info(r)!=NULL)
r= (mp_value_node)mp_link(r);
q= (mp_value_node)mp_link(r);
set_mp_link(r,NULL);
set_prev_dep(q,prev_dep((mp_value_node)pp));
set_mp_link(prev_dep((mp_value_node)pp),(mp_node)q);
mp_new_indep(mp,pp);
if(cur_exp_node()==pp&&mp->cur_exp.type==t)
mp->cur_exp.type= mp_independent;
if(number_positive(internal_value(mp_tracing_equations))){

if(mp_interesting(mp,p)){
mp_begin_diagnostic(mp);
mp_show_transformed_dependency(mp,v,t,p);
mp_print_dependency(mp,s,t);
mp_end_diagnostic(mp,false);
}
}

t= (quarterword)(mp_dependent+mp_proto_dependent-t);
if(number_positive(mp->max_c[t])){

set_mp_link(mp->max_ptr[t],(mp_node)mp->max_link[t]);
mp->max_link[t]= mp->max_ptr[t];
}


if(t!=mp_dependent){

for(t= mp_dependent;t<=mp_proto_dependent;t= t+1){
r= mp->max_link[t];
while(r!=NULL){
q= (mp_value_node)dep_info(r);
number_clone(test,v);
number_negate(test);
make_fraction(ret,dep_value(r),test);
set_dep_list(q,mp_p_plus_fq(mp,(mp_value_node)dep_list(q),ret,s,t,mp_dependent));
if(dep_list(q)==(mp_node)mp->dep_final)
mp_make_known(mp,q,mp->dep_final);
q= r;
r= (mp_value_node)mp_link(r);
mp_free_dep_node(mp,q);
}
}
}else{

for(t= mp_dependent;t<=mp_proto_dependent;t= t+1){
r= mp->max_link[t];
while(r!=NULL){
q= (mp_value_node)dep_info(r);
if(t==mp_dependent){
if(cur_exp_node()==(mp_node)q&&mp->cur_exp.type==mp_dependent)
mp->cur_exp.type= mp_proto_dependent;
set_dep_list(q,mp_p_over_v(mp,(mp_value_node)dep_list(q),
unity_t,mp_dependent,
mp_proto_dependent));
mp_type(q)= mp_proto_dependent;
fraction_to_round_scaled(dep_value(r));
}
number_clone(test,v);
number_negate(test);
make_scaled(ret,dep_value(r),test);
set_dep_list(q,mp_p_plus_fq(mp,(mp_value_node)dep_list(q),
ret,s,
mp_proto_dependent,
mp_proto_dependent));
if(dep_list(q)==(mp_node)mp->dep_final)
mp_make_known(mp,q,mp->dep_final);
q= r;
r= (mp_value_node)mp_link(r);
mp_free_dep_node(mp,q);
}
}
}
mp_flush_node_list(mp,(mp_node)s);
if(mp->fix_needed)
mp_fix_dependencies(mp);
check_arith();
free_number(ret);
}
free_number(v);
free_number(test);
}

/*:935*/
#line 23123 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_token_list:
case mp_structured:
mp_confusion(mp,"recycle");
break;
case mp_unsuffixed_macro:
case mp_suffixed_macro:
mp_delete_mac_ref(mp,value_node(p));
break;
default:
break;
}
mp_type(p)= mp_undefined;
}

/*:934*//*937:*/
#line 23339 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_show_transformed_dependency(MP mp,mp_number v,mp_variable_type t,mp_node p)
{
mp_number vv;
new_number(vv);
mp_print_nl(mp,"### ");
if(number_positive(v))
mp_print_char(mp,xord('-'));
if(t==mp_dependent){
number_clone(vv,mp->max_c[mp_dependent]);
fraction_to_round_scaled(vv);
}else{
number_clone(vv,mp->max_c[mp_proto_dependent]);
}
if(!number_equal(vv,unity_t)){
print_number(vv);
}
mp_print_variable_name(mp,p);
while(indep_scale(p)> 0){
mp_print(mp,"*4");
set_indep_scale(p,indep_scale(p)-2);
}
if(t==mp_dependent)
mp_print_char(mp,xord('='));
else
mp_print(mp," = ");
free_number(vv);
}


/*:937*//*945:*/
#line 23874 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_exp(MP mp,const char*s){
char msg[256];
int save_flag;
const char*hlp[]= {
"I'm afraid I need some sort of value in order to continue,",
"so I've tentatively inserted `0'. You may want to",
"delete this zero and insert something else;",
"see Chapter 27 of The METAFONTbook for an example.",
NULL};
;
{
mp_string cm;
int old_selector= mp->selector;
mp->selector= new_string;
mp_print_cmd_mod(mp,cur_cmd(),cur_mod());
mp->selector= old_selector;
cm= mp_make_string(mp);
mp_snprintf(msg,256,"%s expression can't begin with `%s'",s,mp_str(mp,cm));
delete_str_ref(cm);
}
mp_back_input(mp);
set_cur_sym(NULL);
set_cur_cmd((mp_variable_type)mp_numeric_token);
set_cur_mod_number(zero_t);
mp_ins_error(mp,msg,hlp,true);
save_flag= mp->var_flag;
mp->var_flag= 0;
mp_get_x_next(mp);
mp->var_flag= save_flag;
}


/*:945*//*946:*/
#line 23910 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_stash_in(MP mp,mp_node p){
mp_value_node q;
mp_type(p)= mp->cur_exp.type;
if(mp->cur_exp.type==mp_known){
set_value_number(p,cur_exp_value_number());
}else{
if(mp->cur_exp.type==mp_independent){





q= mp_single_dependency(mp,cur_exp_node());
if(q==mp->dep_final){
mp_type(p)= mp_known;
set_value_number(p,zero_t);
mp_free_dep_node(mp,q);
}else{
mp_new_dep(mp,p,mp_dependent,q);
}
mp_recycle_value(mp,cur_exp_node());
mp_free_value_node(mp,cur_exp_node());
}else{
set_dep_list((mp_value_node)p,
dep_list((mp_value_node)cur_exp_node()));
set_prev_dep((mp_value_node)p,
prev_dep((mp_value_node)cur_exp_node()));
set_mp_link(prev_dep((mp_value_node)p),p);
mp_free_dep_node(mp,(mp_value_node)cur_exp_node());
}
}
mp->cur_exp.type= mp_vacuous;
}

/*:946*//*949:*/
#line 24125 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_back_expr(MP mp){
mp_node p;
p= mp_stash_cur_exp(mp);
mp_link(p)= NULL;
back_list(p);
}


/*:949*//*950:*/
#line 24136 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_subscript(MP mp){
mp_value new_expr;
const char*hlp[]= {
"A bracketed subscript must have a known numeric value;",
"unfortunately, what I found was the value that appears just",
"above this error message. So I'll try a zero subscript.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_error(mp,"Improper subscript has been replaced by zero",hlp,true);
;
mp_flush_cur_exp(mp,new_expr);
}


/*:950*//*951:*/
#line 24170 "../../../source/texk/web2c/mplibdir/mp.w"

static char*mp_obliterated(MP mp,mp_node q){
char msg[256];
mp_string sname;
int old_setting= mp->selector;
mp->selector= new_string;
mp_show_token_list(mp,q,NULL,1000,0);
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Variable %s has been obliterated",mp_str(mp,sname));
;
delete_str_ref(sname);
return xstrdup(msg);
}


/*:951*//*957:*/
#line 24455 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_binary_mac(MP mp,mp_node p,mp_node c,mp_sym n){
mp_node q,r;
q= mp_get_symbolic_node(mp);
r= mp_get_symbolic_node(mp);
mp_link(q)= r;
set_mp_sym_sym(q,p);
set_mp_sym_sym(r,mp_stash_cur_exp(mp));
mp_macro_call(mp,c,q,n);
}


/*:957*//*961:*/
#line 24864 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_knot mp_pair_to_knot(MP mp){
mp_knot q;
q= mp_new_knot(mp);
mp_left_type(q)= mp_endpoint;
mp_right_type(q)= mp_endpoint;
mp_originator(q)= mp_metapost_user;
mp_next_knot(q)= q;
mp_known_pair(mp);
number_clone(q->x_coord,mp->cur_x);
number_clone(q->y_coord,mp->cur_y);
return q;
}


/*:961*//*963:*/
#line 24887 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_known_pair(MP mp){
mp_value new_expr;
mp_node p;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(mp->cur_exp.type!=mp_pair_type){
const char*hlp[]= {
"I need x and y numbers for this part of the path.",
"The value I found (see above) was no good;",
"so I'll try to keep going by using zero instead.",
"(Chapter 27 of The METAFONTbook explains that",
"you might want to type `I ??""?' now.)",
NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Undefined coordinates have been replaced by (0,0)",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
set_number_to_zero(mp->cur_x);
set_number_to_zero(mp->cur_y);
}else{
p= value_node(cur_exp_node());


if(mp_type(x_part(p))==mp_known){
number_clone(mp->cur_x,value_number(x_part(p)));
}else{
const char*hlp[]= {
"I need a `known' x value for this part of the path.",
"The value I found (see above) was no good;",
"so I'll try to keep going by using zero instead.",
"(Chapter 27 of The METAFONTbook explains that",
"you might want to type `I ??""?' now.)",
NULL};
mp_disp_err(mp,x_part(p));
mp_back_error(mp,"Undefined x coordinate has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_recycle_value(mp,x_part(p));
set_number_to_zero(mp->cur_x);
}
if(mp_type(y_part(p))==mp_known){
number_clone(mp->cur_y,value_number(y_part(p)));
}else{
const char*hlp[]= {
"I need a `known' y value for this part of the path.",
"The value I found (see above) was no good;",
"so I'll try to keep going by using zero instead.",
"(Chapter 27 of The METAFONTbook explains that",
"you might want to type `I ??""?' now.)",
NULL};
mp_disp_err(mp,y_part(p));
mp_back_error(mp,"Undefined y coordinate has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_recycle_value(mp,y_part(p));
set_number_to_zero(mp->cur_y);
}
mp_flush_cur_exp(mp,new_expr);
}
}

/*:963*//*964:*/
#line 24957 "../../../source/texk/web2c/mplibdir/mp.w"

static quarterword mp_scan_direction(MP mp){
int t;
mp_get_x_next(mp);
if(cur_cmd()==mp_curl_command){

mp_get_x_next(mp);
mp_scan_expression(mp);
if((mp->cur_exp.type!=mp_known)||(number_negative(cur_exp_value_number()))){
mp_value new_expr;
const char*hlp[]= {"A curl must be a known, nonnegative number.",NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_to_unity(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Improper curl has been replaced by 1",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
t= mp_curl;

}else{

mp_scan_expression(mp);
if(mp->cur_exp.type> mp_pair_type){

mp_number xx;
new_number(xx);
if(mp->cur_exp.type!=mp_known){
mp_value new_expr;
const char*hlp[]= {
"I need a `known' x value for this part of the path.",
"The value I found (see above) was no good;",
"so I'll try to keep going by using zero instead.",
"(Chapter 27 of The METAFONTbook explains that",
"you might want to type `I ??""?' now.)",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Undefined x coordinate has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
number_clone(xx,cur_exp_value_number());
if(cur_cmd()!=mp_comma){
const char*hlp[]= {
"I've got the x coordinate of a path direction;",
"will look for the y coordinate next.",
NULL};
mp_back_error(mp,"Missing `,' has been inserted",hlp,true);
}
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known){
mp_value new_expr;
const char*hlp[]= {
"I need a `known' y value for this part of the path.",
"The value I found (see above) was no good;",
"so I'll try to keep going by using zero instead.",
"(Chapter 27 of The METAFONTbook explains that",
"you might want to type `I ??""?' now.)",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Undefined y coordinate has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
number_clone(mp->cur_y,cur_exp_value_number());
number_clone(mp->cur_x,xx);
free_number(xx);

}else{
mp_known_pair(mp);
}
if(number_zero(mp->cur_x)&&number_zero(mp->cur_y))
t= mp_open;
else{
mp_number narg;
new_angle(narg);
n_arg(narg,mp->cur_x,mp->cur_y);
t= mp_given;
set_cur_exp_value_number(narg);
free_number(narg);
}
}
if(cur_cmd()!=mp_right_brace){
const char*hlp[]= {
"I've scanned a direction spec for part of a path,",
"so a right brace should have come next.",
"I shall pretend that one was there.",
NULL};
mp_back_error(mp,"Missing `}' has been inserted",hlp,true);
}
mp_get_x_next(mp);
return(quarterword)t;
}


/*:964*//*969:*/
#line 25337 "../../../source/texk/web2c/mplibdir/mp.w"

/*970:*/
#line 25392 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_finish_read(MP mp){
size_t k;
str_room(((int)mp->last-(int)start));
for(k= (size_t)start;k<mp->last;k++){
append_char(mp->buffer[k]);
}
mp_end_file_reading(mp);
mp->cur_exp.type= mp_string_type;
set_cur_exp_str(mp_make_string(mp));
}


/*:970*/
#line 25338 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_do_nullary(MP mp,quarterword c){
check_arith();
if(number_greater(internal_value(mp_tracing_commands),two_t))
mp_show_cmd_mod(mp,mp_nullary,c);
switch(c){
case mp_true_code:
case mp_false_code:
mp->cur_exp.type= mp_boolean_type;
set_cur_exp_value_boolean(c);
break;
case mp_null_picture_code:
mp->cur_exp.type= mp_picture_type;
set_cur_exp_node((mp_node)mp_get_edge_header_node(mp));
mp_init_edges(mp,(mp_edge_header_node)cur_exp_node());
break;
case mp_null_pen_code:
mp->cur_exp.type= mp_pen_type;
set_cur_exp_knot(mp_get_pen_circle(mp,zero_t));
break;
case mp_normal_deviate:
{
mp_number r;
new_number(r);

m_norm_rand(r);
mp->cur_exp.type= mp_known;
set_cur_exp_value_number(r);
free_number(r);
}
break;
case mp_pen_circle:
mp->cur_exp.type= mp_pen_type;
set_cur_exp_knot(mp_get_pen_circle(mp,unity_t));
break;
case mp_version:
mp->cur_exp.type= mp_string_type;
set_cur_exp_str(mp_intern(mp,metapost_version));
break;
case mp_read_string_op:

if(mp->noninteractive||mp->interaction<=mp_nonstop_mode)
mp_fatal_error(mp,"*** (cannot readstring in nonstop modes)");
mp_begin_file_reading(mp);
name= is_read;
limit= start;
prompt_input("");
mp_finish_read(mp);
break;
}
check_arith();
}


/*:969*//*971:*/
#line 25442 "../../../source/texk/web2c/mplibdir/mp.w"

/*972:*/
#line 25949 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_nice_pair(MP mp,mp_node p,quarterword t){
(void)mp;
if(t==mp_pair_type){
p= value_node(p);
if(mp_type(x_part(p))==mp_known)
if(mp_type(y_part(p))==mp_known)
return true;
}
return false;
}


/*:972*//*973:*/
#line 25965 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_nice_color_or_pair(MP mp,mp_node p,quarterword t){
mp_node q;
(void)mp;
switch(t){
case mp_pair_type:
q= value_node(p);
if(mp_type(x_part(q))==mp_known)
if(mp_type(y_part(q))==mp_known)
return true;
break;
case mp_color_type:
q= value_node(p);
if(mp_type(red_part(q))==mp_known)
if(mp_type(green_part(q))==mp_known)
if(mp_type(blue_part(q))==mp_known)
return true;
break;
case mp_cmykcolor_type:
q= value_node(p);
if(mp_type(cyan_part(q))==mp_known)
if(mp_type(magenta_part(q))==mp_known)
if(mp_type(yellow_part(q))==mp_known)
if(mp_type(black_part(q))==mp_known)
return true;
break;
}
return false;
}


/*:973*//*974:*/
#line 25996 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_print_known_or_unknown_type(MP mp,quarterword t,mp_node v){
mp_print_char(mp,xord('('));
if(t> mp_known)
mp_print(mp,"unknown numeric");
else{
if((t==mp_pair_type)||(t==mp_color_type)||(t==mp_cmykcolor_type))
if(!mp_nice_color_or_pair(mp,v,t))
mp_print(mp,"unknown ");
mp_print_type(mp,t);
}
mp_print_char(mp,xord(')'));
}


/*:974*//*975:*/
#line 26011 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_unary(MP mp,quarterword c){
char msg[256];
mp_string sname;
int old_setting= mp->selector;
const char*hlp[]= {
"I'm afraid I don't know how to apply that operation to that",
"particular type. Continue, and I'll simply return the",
"argument (shown above) as the result of the operation.",
NULL};
mp->selector= new_string;
mp_print_op(mp,c);
mp_print_known_or_unknown_type(mp,mp->cur_exp.type,cur_exp_node());
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Not implemented: %s",mp_str(mp,sname));
delete_str_ref(sname);
mp_disp_err(mp,NULL);
mp_back_error(mp,msg,hlp,true);
;
mp_get_x_next(mp);
}



/*:975*//*976:*/
#line 26040 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_negate_dep_list(MP mp,mp_value_node p){
(void)mp;
while(1){
number_negate(dep_value(p));
if(dep_info(p)==NULL)
return;
p= (mp_value_node)mp_link(p);
}
}


/*:976*//*977:*/
#line 26068 "../../../source/texk/web2c/mplibdir/mp.w"

static void negate_cur_expr(MP mp){
mp_node p,q,r;
switch(mp->cur_exp.type){
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
case mp_independent:
q= cur_exp_node();
mp_make_exp_copy(mp,q);
if(mp->cur_exp.type==mp_dependent){
mp_negate_dep_list(mp,(mp_value_node)dep_list((mp_value_node)
cur_exp_node()));
}else if(mp->cur_exp.type<=mp_pair_type){

p= value_node(cur_exp_node());
switch(mp->cur_exp.type){
case mp_pair_type:
r= x_part(p);
negate_value(r);
r= y_part(p);
negate_value(r);
break;
case mp_color_type:
r= red_part(p);
negate_value(r);
r= green_part(p);
negate_value(r);
r= blue_part(p);
negate_value(r);
break;
case mp_cmykcolor_type:
r= cyan_part(p);
negate_value(r);
r= magenta_part(p);
negate_value(r);
r= yellow_part(p);
negate_value(r);
r= black_part(p);
negate_value(r);
break;
default:
break;
}
}
mp_recycle_value(mp,q);
mp_free_value_node(mp,q);
break;
case mp_dependent:
case mp_proto_dependent:
mp_negate_dep_list(mp,(mp_value_node)dep_list((mp_value_node)
cur_exp_node()));
break;
case mp_known:
if(is_number(cur_exp_value_number()))
number_negate(cur_exp_value_number());
break;
default:
mp_bad_unary(mp,mp_minus);
break;
}
}

/*:977*//*978:*/
#line 26134 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pair_to_path(MP mp){
set_cur_exp_knot(mp_pair_to_knot(mp));
mp->cur_exp.type= mp_path_type;
}



/*:978*//*981:*/
#line 26190 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_take_part(MP mp,quarterword c){
mp_node p;
p= value_node(cur_exp_node());
set_value_node(mp->temp_val,p);
mp_type(mp->temp_val)= mp->cur_exp.type;
mp_link(p)= mp->temp_val;
mp_free_value_node(mp,cur_exp_node());
switch(c){
case mp_x_part:
if(mp->cur_exp.type==mp_pair_type)
mp_make_exp_copy(mp,x_part(p));
else
mp_make_exp_copy(mp,tx_part(p));
break;
case mp_y_part:
if(mp->cur_exp.type==mp_pair_type)
mp_make_exp_copy(mp,y_part(p));
else
mp_make_exp_copy(mp,ty_part(p));
break;
case mp_xx_part:
mp_make_exp_copy(mp,xx_part(p));
break;
case mp_xy_part:
mp_make_exp_copy(mp,xy_part(p));
break;
case mp_yx_part:
mp_make_exp_copy(mp,yx_part(p));
break;
case mp_yy_part:
mp_make_exp_copy(mp,yy_part(p));
break;
case mp_red_part:
mp_make_exp_copy(mp,red_part(p));
break;
case mp_green_part:
mp_make_exp_copy(mp,green_part(p));
break;
case mp_blue_part:
mp_make_exp_copy(mp,blue_part(p));
break;
case mp_cyan_part:
mp_make_exp_copy(mp,cyan_part(p));
break;
case mp_magenta_part:
mp_make_exp_copy(mp,magenta_part(p));
break;
case mp_yellow_part:
mp_make_exp_copy(mp,yellow_part(p));
break;
case mp_black_part:
mp_make_exp_copy(mp,black_part(p));
break;
}
mp_recycle_value(mp,mp->temp_val);
}


/*:981*//*985:*/
#line 26260 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_take_pict_part(MP mp,quarterword c){
mp_node p;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
p= mp_link(edge_list(cur_exp_node()));
if(p!=NULL){
switch(c){
case mp_x_part:
case mp_y_part:
case mp_xx_part:
case mp_xy_part:
case mp_yx_part:
case mp_yy_part:
if(mp_type(p)==mp_text_node_type){
mp_text_node p0= (mp_text_node)p;
switch(c){
case mp_x_part:
number_clone(new_expr.data.n,p0->tx);
break;
case mp_y_part:
number_clone(new_expr.data.n,p0->ty);
break;
case mp_xx_part:
number_clone(new_expr.data.n,p0->txx);
break;
case mp_xy_part:
number_clone(new_expr.data.n,p0->txy);
break;
case mp_yx_part:
number_clone(new_expr.data.n,p0->tyx);
break;
case mp_yy_part:
number_clone(new_expr.data.n,p0->tyy);
break;
}
mp_flush_cur_exp(mp,new_expr);
}else
goto NOT_FOUND;
break;
case mp_red_part:
case mp_green_part:
case mp_blue_part:
if(has_color(p)){
switch(c){
case mp_red_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->red);
break;
case mp_green_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->green);
break;
case mp_blue_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->blue);
break;
}
mp_flush_cur_exp(mp,new_expr);
}else
goto NOT_FOUND;
break;
case mp_cyan_part:
case mp_magenta_part:
case mp_yellow_part:
case mp_black_part:
if(has_color(p)){
if(mp_color_model(p)==mp_uninitialized_model&&c==mp_black_part){
set_number_to_unity(new_expr.data.n);
}else{
switch(c){
case mp_cyan_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->cyan);
break;
case mp_magenta_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->magenta);
break;
case mp_yellow_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->yellow);
break;
case mp_black_part:
number_clone(new_expr.data.n,((mp_stroked_node)p)->black);
break;
}
}
mp_flush_cur_exp(mp,new_expr);
}else
goto NOT_FOUND;
break;
case mp_grey_part:
if(has_color(p)){
number_clone(new_expr.data.n,((mp_stroked_node)p)->grey);
mp_flush_cur_exp(mp,new_expr);
}else
goto NOT_FOUND;
break;
case mp_color_model_part:
if(has_color(p)){
if(mp_color_model(p)==mp_uninitialized_model){
number_clone(new_expr.data.n,internal_value(mp_default_color_model));
}else{
number_clone(new_expr.data.n,unity_t);
number_multiply_int(new_expr.data.n,mp_color_model(p));
}
mp_flush_cur_exp(mp,new_expr);
}else
goto NOT_FOUND;
break;
case mp_text_part:
if(mp_type(p)!=mp_text_node_type)
goto NOT_FOUND;
else{
new_expr.data.str= mp_text_p(p);
add_str_ref(new_expr.data.str);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_string_type;
};
break;
case mp_prescript_part:
if(!has_color(p)){
goto NOT_FOUND;
}else{
if(mp_pre_script(p)){
new_expr.data.str= mp_pre_script(p);
add_str_ref(new_expr.data.str);
}else{
new_expr.data.str= mp_rts(mp,"");
}
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_string_type;
};
break;
case mp_postscript_part:
if(!has_color(p)){
goto NOT_FOUND;
}else{
if(mp_post_script(p)){
new_expr.data.str= mp_post_script(p);
add_str_ref(new_expr.data.str);
}else{
new_expr.data.str= mp_rts(mp,"");
}
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_string_type;
};
break;
case mp_font_part:
if(mp_type(p)!=mp_text_node_type)
goto NOT_FOUND;
else{
new_expr.data.str= mp_rts(mp,mp->font_name[mp_font_n(p)]);
add_str_ref(new_expr.data.str);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_string_type;
};
break;
case mp_path_part:
if(mp_type(p)==mp_text_node_type){
goto NOT_FOUND;
}else if(is_stop(p)){
mp_confusion(mp,"pict");
}else{
new_expr.data.node= NULL;
switch(mp_type(p)){
case mp_fill_node_type:
new_expr.data.p= mp_copy_path(mp,mp_path_p((mp_fill_node)p));
break;
case mp_stroked_node_type:
new_expr.data.p= mp_copy_path(mp,mp_path_p((mp_stroked_node)p));
break;
case mp_start_bounds_node_type:
new_expr.data.p= mp_copy_path(mp,mp_path_p((mp_start_bounds_node)p));
break;
case mp_start_clip_node_type:
new_expr.data.p= mp_copy_path(mp,mp_path_p((mp_start_clip_node)p));
break;
default:
assert(0);
break;
}
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_path_type;
}
break;
case mp_pen_part:
if(!has_pen(p)){
goto NOT_FOUND;
}else{
switch(mp_type(p)){
case mp_fill_node_type:
if(mp_pen_p((mp_fill_node)p)==NULL)
goto NOT_FOUND;
else{
new_expr.data.p= copy_pen(mp_pen_p((mp_fill_node)p));
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_pen_type;
}
break;
case mp_stroked_node_type:
if(mp_pen_p((mp_stroked_node)p)==NULL)
goto NOT_FOUND;
else{
new_expr.data.p= copy_pen(mp_pen_p((mp_stroked_node)p));
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_pen_type;
}
break;
default:
assert(0);
break;
}
}
break;
case mp_dash_part:
if(mp_type(p)!=mp_stroked_node_type){
goto NOT_FOUND;
}else{
if(mp_dash_p(p)==NULL){
goto NOT_FOUND;
}else{
add_edge_ref(mp_dash_p(p));
new_expr.data.node= (mp_node)mp_scale_edges(mp,((mp_stroked_node)p)->dash_scale,
(mp_edge_header_node)mp_dash_p(p));
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_picture_type;
}
}
break;
}
return;
};
NOT_FOUND:

switch(c){
case mp_text_part:
case mp_font_part:
case mp_prescript_part:
case mp_postscript_part:
new_expr.data.str= mp_rts(mp,"");
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_string_type;
break;
case mp_path_part:
new_expr.data.p= mp_new_knot(mp);
mp_flush_cur_exp(mp,new_expr);
mp_left_type(cur_exp_knot())= mp_endpoint;
mp_right_type(cur_exp_knot())= mp_endpoint;
mp_next_knot(cur_exp_knot())= cur_exp_knot();
set_number_to_zero(cur_exp_knot()->x_coord);
set_number_to_zero(cur_exp_knot()->y_coord);
mp_originator(cur_exp_knot())= mp_metapost_user;
mp->cur_exp.type= mp_path_type;
break;
case mp_pen_part:
new_expr.data.p= mp_get_pen_circle(mp,zero_t);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_pen_type;
break;
case mp_dash_part:
new_expr.data.node= (mp_node)mp_get_edge_header_node(mp);
mp_flush_cur_exp(mp,new_expr);
mp_init_edges(mp,(mp_edge_header_node)cur_exp_node());
mp->cur_exp.type= mp_picture_type;
break;
default:
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
break;
}
}

/*:985*//*986:*/
#line 26529 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_str_to_num(MP mp,quarterword c){
integer n;
ASCII_code m;
unsigned k;
int b;
boolean bad_char;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(c==mp_ASCII_op){
if(cur_exp_str()->len==0)
n= -1;
else
n= cur_exp_str()->str[0];
}else{
if(c==mp_oct_op)
b= 8;
else
b= 16;
n= 0;
bad_char= false;
for(k= 0;k<cur_exp_str()->len;k++){
m= (ASCII_code)(*(cur_exp_str()->str+k));
if((m>='0')&&(m<='9'))
m= (ASCII_code)(m-'0');
else if((m>='A')&&(m<='F'))
m= (ASCII_code)(m-'A'+10);
else if((m>='a')&&(m<='f'))
m= (ASCII_code)(m-'a'+10);
else{
bad_char= true;
m= 0;
};
if((int)m>=b){
bad_char= true;
m= 0;
};
if(n<32768/b)
n= n*b+m;
else
n= 32767;
}

if(bad_char){
const char*hlp[]= {"I zeroed out characters that weren't hex digits.",NULL};
if(c==mp_oct_op){
hlp[0]= "I zeroed out characters that weren't in the range 0..7.";
}
mp_disp_err(mp,NULL);
mp_back_error(mp,"String contains illegal digits",hlp,true);
mp_get_x_next(mp);
}
if((n> 4095)){
if(number_positive(internal_value(mp_warning_check))){
char msg[256];
const char*hlp[]= {
"I have trouble with numbers greater than 4095; watch out.",
"(Set warningcheck:=0 to suppress this message.)",
NULL};
mp_snprintf(msg,256,"Number too large (%d)",(int)n);
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
}
}
number_clone(new_expr.data.n,unity_t);
number_multiply_int(new_expr.data.n,n);
mp_flush_cur_exp(mp,new_expr);
}

/*:986*//*987:*/
#line 26600 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_path_length(MP mp,mp_number*n){
mp_knot p;
set_number_to_zero(*n);
p= cur_exp_knot();
if(mp_left_type(p)==mp_endpoint){
number_substract(*n,unity_t);
}
do{
p= mp_next_knot(p);
number_add(*n,unity_t);
}while(p!=cur_exp_knot());
}


/*:987*//*988:*/
#line 26615 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pict_length(MP mp,mp_number*n){

mp_node p;
set_number_to_zero(*n);
p= mp_link(edge_list(cur_exp_node()));
if(p!=NULL){
if(is_start_or_stop(p))
if(mp_skip_1component(mp,p)==NULL)
p= mp_link(p);
while(p!=NULL){
if(!is_start_or_stop(p))
p= mp_link(p);
else if(!is_stop(p))
p= mp_skip_1component(mp,p);
else
return;
number_add(*n,unity_t);
}
}
}


/*:988*//*989:*/
#line 26641 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_an_angle(MP mp,mp_number*ret,mp_number xpar,mp_number ypar){
set_number_to_zero(*ret);
if((!(number_zero(xpar)&&number_zero(ypar)))){
n_arg(*ret,xpar,ypar);
}
}


/*:989*//*990:*/
#line 26660 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bezier_slope(MP mp,mp_number*ret,mp_number AX,mp_number AY,mp_number BX,
mp_number BY,mp_number CX,mp_number CY,mp_number DX,
mp_number DY);

/*:990*//*992:*/
#line 26772 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_turn_cycles(MP mp,mp_number*turns,mp_knot c){
mp_angle res,ang;
mp_knot p;
mp_number xp,yp;
mp_number x,y;
mp_number arg1,arg2;
mp_angle in_angle,out_angle;
mp_angle seven_twenty_deg_t,neg_one_eighty_deg_t;
unsigned old_setting;
set_number_to_zero(*turns);
new_number(arg1);
new_number(arg2);
new_number(xp);
new_number(yp);
new_number(x);
new_number(y);
new_angle(in_angle);
new_angle(out_angle);
new_angle(ang);
new_angle(res);
new_angle(seven_twenty_deg_t);
new_angle(neg_one_eighty_deg_t);
number_clone(seven_twenty_deg_t,three_sixty_deg_t);
number_double(seven_twenty_deg_t);
number_clone(neg_one_eighty_deg_t,one_eighty_deg_t);
number_negate(neg_one_eighty_deg_t);
p= c;
old_setting= mp->selector;
mp->selector= term_only;
if(number_greater(internal_value(mp_tracing_commands),unity_t)){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"");
mp_end_diagnostic(mp,false);
}
do{
number_clone(xp,p_next->x_coord);
number_clone(yp,p_next->y_coord);
mp_bezier_slope(mp,&ang,p->x_coord,p->y_coord,p->right_x,p->right_y,
p_next->left_x,p_next->left_y,xp,yp);
if(number_greater(ang,seven_twenty_deg_t)){
mp_error(mp,"Strange path",NULL,true);
mp->selector= old_setting;
set_number_to_zero(*turns);
goto DONE;
}
number_add(res,ang);
if(number_greater(res,one_eighty_deg_t)){
number_substract(res,three_sixty_deg_t);
number_add(*turns,unity_t);
}
if(number_lessequal(res,neg_one_eighty_deg_t)){
number_add(res,three_sixty_deg_t);
number_substract(*turns,unity_t);
}

number_clone(x,p_next->left_x);
number_clone(y,p_next->left_y);
if(number_equal(xp,x)&&number_equal(yp,y)){
number_clone(x,p->right_x);
number_clone(y,p->right_y);
}
if(number_equal(xp,x)&&number_equal(yp,y)){
number_clone(x,p->x_coord);
number_clone(y,p->y_coord);
}
set_number_from_substraction(arg1,xp,x);
set_number_from_substraction(arg2,yp,y);
mp_an_angle(mp,&in_angle,arg1,arg2);

number_clone(x,p_next->right_x);
number_clone(y,p_next->right_y);
if(number_equal(xp,x)&&number_equal(yp,y)){
number_clone(x,p_nextnext->left_x);
number_clone(y,p_nextnext->left_y);
}
if(number_equal(xp,x)&&number_equal(yp,y)){
number_clone(x,p_nextnext->x_coord);
number_clone(y,p_nextnext->y_coord);
}
set_number_from_substraction(arg1,x,xp);
set_number_from_substraction(arg2,y,yp);
mp_an_angle(mp,&out_angle,arg1,arg2);
set_number_from_substraction(ang,out_angle,in_angle);
mp_reduce_angle(mp,&ang);
if(number_nonzero(ang)){
number_add(res,ang);
if(number_greaterequal(res,one_eighty_deg_t)){
number_substract(res,three_sixty_deg_t);
number_add(*turns,unity_t);
}
if(number_lessequal(res,neg_one_eighty_deg_t)){
number_add(res,three_sixty_deg_t);
number_substract(*turns,unity_t);
}
}
p= mp_next_knot(p);
}while(p!=c);
mp->selector= old_setting;
DONE:
free_number(xp);
free_number(yp);
free_number(x);
free_number(y);
free_number(seven_twenty_deg_t);
free_number(neg_one_eighty_deg_t);
free_number(in_angle);
free_number(out_angle);
free_number(ang);
free_number(res);
free_number(arg1);
free_number(arg2);
}

/*:992*//*993:*/
#line 26886 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_turn_cycles_wrapper(MP mp,mp_number*ret,mp_knot c){
if(mp_next_knot(c)==c){

set_number_to_unity(*ret);
}else{
mp_turn_cycles(mp,ret,c);
}
}

/*:993*//*994:*/
#line 26896 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_test_known(MP mp,quarterword c){
int b;
mp_node p;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
b= mp_false_code;
switch(mp->cur_exp.type){
case mp_vacuous:
case mp_boolean_type:
case mp_string_type:
case mp_pen_type:
case mp_path_type:
case mp_picture_type:
case mp_known:
b= mp_true_code;
break;
case mp_transform_type:
p= value_node(cur_exp_node());
if(mp_type(tx_part(p))!=mp_known)
break;
if(mp_type(ty_part(p))!=mp_known)
break;
if(mp_type(xx_part(p))!=mp_known)
break;
if(mp_type(xy_part(p))!=mp_known)
break;
if(mp_type(yx_part(p))!=mp_known)
break;
if(mp_type(yy_part(p))!=mp_known)
break;
b= mp_true_code;
break;
case mp_color_type:
p= value_node(cur_exp_node());
if(mp_type(red_part(p))!=mp_known)
break;
if(mp_type(green_part(p))!=mp_known)
break;
if(mp_type(blue_part(p))!=mp_known)
break;
b= mp_true_code;
break;
case mp_cmykcolor_type:
p= value_node(cur_exp_node());
if(mp_type(cyan_part(p))!=mp_known)
break;
if(mp_type(magenta_part(p))!=mp_known)
break;
if(mp_type(yellow_part(p))!=mp_known)
break;
if(mp_type(black_part(p))!=mp_known)
break;
b= mp_true_code;
break;
case mp_pair_type:
p= value_node(cur_exp_node());
if(mp_type(x_part(p))!=mp_known)
break;
if(mp_type(y_part(p))!=mp_known)
break;
b= mp_true_code;
break;
default:
break;
}
if(c==mp_known_op){
set_number_from_boolean(new_expr.data.n,b);
}else{
if(b==mp_true_code){
set_number_from_boolean(new_expr.data.n,mp_false_code);
}else{
set_number_from_boolean(new_expr.data.n,mp_true_code);
}
}
mp_flush_cur_exp(mp,new_expr);
cur_exp_node()= NULL;
mp->cur_exp.type= mp_boolean_type;
}

/*:994*//*995:*/
#line 26980 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_pair_value(MP mp,mp_number x,mp_number y){
mp_node p;
mp_value new_expr;
mp_number x1,y1;
new_number(x1);
new_number(y1);
number_clone(x1,x);
number_clone(y1,y);
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
p= mp_get_value_node(mp);
new_expr.type= mp_type(p);
new_expr.data.node= p;
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_pair_type;
mp_name_type(p)= mp_capsule;
mp_init_pair_node(mp,p);
p= value_node(p);
mp_type(x_part(p))= mp_known;
set_value_number(x_part(p),x1);
mp_type(y_part(p))= mp_known;
set_value_number(y_part(p),y1);
free_number(x1);
free_number(y1);
}


/*:995*//*996:*/
#line 27012 "../../../source/texk/web2c/mplibdir/mp.w"

static boolean mp_get_cur_bbox(MP mp){
switch(mp->cur_exp.type){
case mp_picture_type:
{
mp_edge_header_node p0= (mp_edge_header_node)cur_exp_node();
mp_set_bbox(mp,p0,true);
if(number_greater(p0->minx,p0->maxx)){
set_number_to_zero(mp_minx);
set_number_to_zero(mp_maxx);
set_number_to_zero(mp_miny);
set_number_to_zero(mp_maxy);
}else{
number_clone(mp_minx,p0->minx);
number_clone(mp_maxx,p0->maxx);
number_clone(mp_miny,p0->miny);
number_clone(mp_maxy,p0->maxy);
}
}
break;
case mp_path_type:
mp_path_bbox(mp,cur_exp_knot());
break;
case mp_pen_type:
mp_pen_bbox(mp,cur_exp_knot());
break;
default:
return false;
}
return true;
}


/*:996*//*997:*/
#line 27048 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_read_or_close(MP mp,quarterword c){
mp_value new_expr;
readf_index n,n0;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);




{
char*fn;
n= mp->read_files;
n0= mp->read_files;
fn= mp_xstrdup(mp,mp_str(mp,cur_exp_str()));
while(mp_xstrcmp(fn,mp->rd_fname[n])!=0){
if(n> 0){
decr(n);
}else if(c==mp_close_from_op){
goto CLOSE_FILE;
}else{
if(n0==mp->read_files){
if(mp->read_files<mp->max_read_files){
incr(mp->read_files);
}else{
void**rd_file;
char**rd_fname;
readf_index l,k;
l= mp->max_read_files+(mp->max_read_files/4);
rd_file= xmalloc((l+1),sizeof(void*));
rd_fname= xmalloc((l+1),sizeof(char*));
for(k= 0;k<=l;k++){
if(k<=mp->max_read_files){
rd_file[k]= mp->rd_file[k];
rd_fname[k]= mp->rd_fname[k];
}else{
rd_file[k]= 0;
rd_fname[k]= NULL;
}
}
xfree(mp->rd_file);
xfree(mp->rd_fname);
mp->max_read_files= l;
mp->rd_file= rd_file;
mp->rd_fname= rd_fname;
}
}
n= n0;
if(mp_start_read_input(mp,fn,n))
goto FOUND;
else
goto NOT_FOUND;
}
if(mp->rd_fname[n]==NULL){
n0= n;
}
}
if(c==mp_close_from_op){
(mp->close_file)(mp,mp->rd_file[n]);
goto NOT_FOUND;
}
}
mp_begin_file_reading(mp);
name= is_read;
if(mp_input_ln(mp,mp->rd_file[n]))
goto FOUND;
mp_end_file_reading(mp);
NOT_FOUND:

xfree(mp->rd_fname[n]);
mp->rd_fname[n]= NULL;
if(n==mp->read_files-1)
mp->read_files= n;
if(c==mp_close_from_op)
goto CLOSE_FILE;
new_expr.data.str= mp->eof_line;
add_str_ref(new_expr.data.str);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_string_type;
return;
CLOSE_FILE:
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_vacuous;
return;
FOUND:
mp_flush_cur_exp(mp,new_expr);
mp_finish_read(mp);
}

/*:997*/
#line 25443 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_do_unary(MP mp,quarterword c){
mp_node p;
mp_value new_expr;
check_arith();
if(number_greater(internal_value(mp_tracing_commands),two_t)){

mp_begin_diagnostic(mp);
mp_print_nl(mp,"{");
mp_print_op(mp,c);
mp_print_char(mp,xord('('));
mp_print_exp(mp,NULL,0);
mp_print(mp,")}");
mp_end_diagnostic(mp,false);
}
switch(c){
case mp_plus:
if(mp->cur_exp.type<mp_color_type)
mp_bad_unary(mp,mp_plus);
break;
case mp_minus:
negate_cur_expr(mp);
break;
case mp_not_op:
if(mp->cur_exp.type!=mp_boolean_type){
mp_bad_unary(mp,mp_not_op);
}else{
halfword bb;
if(cur_exp_value_boolean()==mp_true_code)
bb= mp_false_code;
else
bb= mp_true_code;
set_cur_exp_value_boolean(bb);
}
break;
case mp_sqrt_op:
case mp_m_exp_op:
case mp_m_log_op:
case mp_sin_d_op:
case mp_cos_d_op:
case mp_floor_op:
case mp_uniform_deviate:
case mp_odd_op:
case mp_char_exists_op:
if(mp->cur_exp.type!=mp_known){
mp_bad_unary(mp,c);
}else{
switch(c){
case mp_sqrt_op:
{
mp_number r1;
new_number(r1);
square_rt(r1,cur_exp_value_number());
set_cur_exp_value_number(r1);
free_number(r1);
}
break;
case mp_m_exp_op:
{
mp_number r1;
new_number(r1);
m_exp(r1,cur_exp_value_number());
set_cur_exp_value_number(r1);
free_number(r1);
}
break;
case mp_m_log_op:
{
mp_number r1;
new_number(r1);
m_log(r1,cur_exp_value_number());
set_cur_exp_value_number(r1);
free_number(r1);
}
break;
case mp_sin_d_op:
case mp_cos_d_op:
{
mp_number n_sin,n_cos,arg1,arg2;
new_number(arg1);
new_number(arg2);
new_fraction(n_sin);
new_fraction(n_cos);
number_clone(arg1,cur_exp_value_number());
number_clone(arg2,unity_t);
number_multiply_int(arg2,360);
number_modulo(arg1,arg2);
convert_scaled_to_angle(arg1);
n_sin_cos(arg1,n_cos,n_sin);
if(c==mp_sin_d_op){
fraction_to_round_scaled(n_sin);
set_cur_exp_value_number(n_sin);
}else{
fraction_to_round_scaled(n_cos);
set_cur_exp_value_number(n_cos);
}
free_number(arg1);
free_number(arg2);
free_number(n_sin);
free_number(n_cos);
}
break;
case mp_floor_op:
{
mp_number vvx;
new_number(vvx);
number_clone(vvx,cur_exp_value_number());
floor_scaled(vvx);
set_cur_exp_value_number(vvx);
free_number(vvx);
}
break;
case mp_uniform_deviate:
{
mp_number vvx;
new_number(vvx);

m_unif_rand(vvx,cur_exp_value_number());
set_cur_exp_value_number(vvx);
free_number(vvx);
}
break;
case mp_odd_op:
{
integer vvx= odd(round_unscaled(cur_exp_value_number()));
boolean_reset(vvx);
mp->cur_exp.type= mp_boolean_type;
}
break;
case mp_char_exists_op:

set_cur_exp_value_scaled(round_unscaled(cur_exp_value_number())%256);
if(number_negative(cur_exp_value_number())){
halfword vv= number_to_scaled(cur_exp_value_number());
set_cur_exp_value_scaled(vv+256);
}
boolean_reset(mp->char_exists[number_to_scaled(cur_exp_value_number())]);
mp->cur_exp.type= mp_boolean_type;
break;
}
}
break;
case mp_angle_op:
if(mp_nice_pair(mp,cur_exp_node(),mp->cur_exp.type)){
mp_number narg;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
new_angle(narg);
p= value_node(cur_exp_node());
n_arg(narg,value_number(x_part(p)),value_number(y_part(p)));
number_clone(new_expr.data.n,narg);
convert_angle_to_scaled(new_expr.data.n);
free_number(narg);
mp_flush_cur_exp(mp,new_expr);
}else{
mp_bad_unary(mp,mp_angle_op);
}
break;
case mp_x_part:
case mp_y_part:
if((mp->cur_exp.type==mp_pair_type)
||(mp->cur_exp.type==mp_transform_type))
mp_take_part(mp,c);
else if(mp->cur_exp.type==mp_picture_type)
mp_take_pict_part(mp,c);
else
mp_bad_unary(mp,c);
break;
case mp_xx_part:
case mp_xy_part:
case mp_yx_part:
case mp_yy_part:
if(mp->cur_exp.type==mp_transform_type)
mp_take_part(mp,c);
else if(mp->cur_exp.type==mp_picture_type)
mp_take_pict_part(mp,c);
else
mp_bad_unary(mp,c);
break;
case mp_red_part:
case mp_green_part:
case mp_blue_part:
if(mp->cur_exp.type==mp_color_type)
mp_take_part(mp,c);
else if(mp->cur_exp.type==mp_picture_type){
if pict_color_type
(mp_rgb_model)mp_take_pict_part(mp,c);
else
mp_bad_color_part(mp,c);
}else
mp_bad_unary(mp,c);
break;
case mp_cyan_part:
case mp_magenta_part:
case mp_yellow_part:
case mp_black_part:
if(mp->cur_exp.type==mp_cmykcolor_type)
mp_take_part(mp,c);
else if(mp->cur_exp.type==mp_picture_type){
if pict_color_type
(mp_cmyk_model)mp_take_pict_part(mp,c);
else
mp_bad_color_part(mp,c);
}else
mp_bad_unary(mp,c);
break;
case mp_grey_part:
if(mp->cur_exp.type==mp_known);
else if(mp->cur_exp.type==mp_picture_type){
if pict_color_type
(mp_grey_model)mp_take_pict_part(mp,c);
else
mp_bad_color_part(mp,c);
}else
mp_bad_unary(mp,c);
break;
case mp_color_model_part:
if(mp->cur_exp.type==mp_picture_type)
mp_take_pict_part(mp,c);
else
mp_bad_unary(mp,c);
break;
case mp_font_part:
case mp_text_part:
case mp_path_part:
case mp_pen_part:
case mp_dash_part:
case mp_prescript_part:
case mp_postscript_part:
if(mp->cur_exp.type==mp_picture_type)
mp_take_pict_part(mp,c);
else
mp_bad_unary(mp,c);
break;
case mp_char_op:
if(mp->cur_exp.type!=mp_known){
mp_bad_unary(mp,mp_char_op);
}else{
int vv= round_unscaled(cur_exp_value_number())%256;
set_cur_exp_value_scaled(vv);
mp->cur_exp.type= mp_string_type;
if(number_negative(cur_exp_value_number())){
vv= number_to_scaled(cur_exp_value_number())+256;
set_cur_exp_value_scaled(vv);
}
{
unsigned char ss[2];
ss[0]= (unsigned char)number_to_scaled(cur_exp_value_number());
ss[1]= '\0';
set_cur_exp_str(mp_rtsl(mp,(char*)ss,1));
}
}
break;
case mp_decimal:
if(mp->cur_exp.type!=mp_known){
mp_bad_unary(mp,mp_decimal);
}else{
mp->old_setting= mp->selector;
mp->selector= new_string;
print_number(cur_exp_value_number());
set_cur_exp_str(mp_make_string(mp));
mp->selector= mp->old_setting;
mp->cur_exp.type= mp_string_type;
}
break;
case mp_oct_op:
case mp_hex_op:
case mp_ASCII_op:
if(mp->cur_exp.type!=mp_string_type)
mp_bad_unary(mp,c);
else
mp_str_to_num(mp,c);
break;
case mp_font_size:
if(mp->cur_exp.type!=mp_string_type){
mp_bad_unary(mp,mp_font_size);
}else{



memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_from_scaled(new_expr.data.n,
(mp->font_dsize[mp_find_font(mp,mp_str(mp,cur_exp_str()))]+8)/16);
mp_flush_cur_exp(mp,new_expr);
}
break;
case mp_length_op:


switch(mp->cur_exp.type){
case mp_string_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
number_clone(new_expr.data.n,unity_t);
number_multiply_int(new_expr.data.n,cur_exp_str()->len);
mp_flush_cur_exp(mp,new_expr);
break;
case mp_path_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_path_length(mp,&new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
break;
case mp_known:
set_cur_exp_value_number(cur_exp_value_number());
number_abs(cur_exp_value_number());
break;
case mp_picture_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_pict_length(mp,&new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
break;
default:
if(mp_nice_pair(mp,cur_exp_node(),mp->cur_exp.type)){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
pyth_add(new_expr.data.n,value_number(x_part(value_node(cur_exp_node()))),
value_number(y_part(value_node(cur_exp_node()))));
mp_flush_cur_exp(mp,new_expr);
}else
mp_bad_unary(mp,c);
break;
}
break;
case mp_turning_op:
if(mp->cur_exp.type==mp_pair_type){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}else if(mp->cur_exp.type!=mp_path_type){
mp_bad_unary(mp,mp_turning_op);
}else if(mp_left_type(cur_exp_knot())==mp_endpoint){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
new_expr.data.p= NULL;
mp_flush_cur_exp(mp,new_expr);
}else{
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_turn_cycles_wrapper(mp,&new_expr.data.n,cur_exp_knot());
mp_flush_cur_exp(mp,new_expr);
}
break;
case mp_boolean_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_range(mp_boolean_type,mp_unknown_boolean);
break;
case mp_string_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_range(mp_string_type,mp_unknown_string);
break;
case mp_pen_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_range(mp_pen_type,mp_unknown_pen);
break;
case mp_path_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_range(mp_path_type,mp_unknown_path);
break;
case mp_picture_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_range(mp_picture_type,mp_unknown_picture);
break;
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_test(c);
break;
case mp_numeric_type:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
type_range(mp_known,mp_independent);
break;
case mp_known_op:
case mp_unknown_op:
mp_test_known(mp,c);
break;
case mp_cycle_op:
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(mp->cur_exp.type!=mp_path_type)
set_number_from_boolean(new_expr.data.n,mp_false_code);
else if(mp_left_type(cur_exp_knot())!=mp_endpoint)
set_number_from_boolean(new_expr.data.n,mp_true_code);
else
set_number_from_boolean(new_expr.data.n,mp_false_code);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_boolean_type;
break;
case mp_arc_length:
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if(mp->cur_exp.type!=mp_path_type){
mp_bad_unary(mp,mp_arc_length);
}else{
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_arc_length(mp,&new_expr.data.n,cur_exp_knot());
mp_flush_cur_exp(mp,new_expr);
}
break;
case mp_filled_op:
case mp_stroked_op:
case mp_textual_op:
case mp_clipped_op:
case mp_bounded_op:



memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(mp->cur_exp.type!=mp_picture_type){
set_number_from_boolean(new_expr.data.n,mp_false_code);
}else if(mp_link(edge_list(cur_exp_node()))==NULL){
set_number_from_boolean(new_expr.data.n,mp_false_code);
}else if(mp_type(mp_link(edge_list(cur_exp_node())))==
(mp_variable_type)(c+mp_fill_node_type-mp_filled_op)){
set_number_from_boolean(new_expr.data.n,mp_true_code);
}else{
set_number_from_boolean(new_expr.data.n,mp_false_code);
}
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_boolean_type;
break;
case mp_make_pen_op:
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if(mp->cur_exp.type!=mp_path_type)
mp_bad_unary(mp,mp_make_pen_op);
else{
mp->cur_exp.type= mp_pen_type;
set_cur_exp_knot(mp_make_pen(mp,cur_exp_knot(),true));
}
break;
case mp_make_path_op:
if(mp->cur_exp.type!=mp_pen_type){
mp_bad_unary(mp,mp_make_path_op);
}else{
mp->cur_exp.type= mp_path_type;
mp_make_path(mp,cur_exp_knot());
}
break;
case mp_reverse:
if(mp->cur_exp.type==mp_path_type){
mp_knot pk= mp_htap_ypoc(mp,cur_exp_knot());
if(mp_right_type(pk)==mp_endpoint)
pk= mp_next_knot(pk);
mp_toss_knot_list(mp,cur_exp_knot());
set_cur_exp_knot(pk);
}else if(mp->cur_exp.type==mp_pair_type){
mp_pair_to_path(mp);
}else{
mp_bad_unary(mp,mp_reverse);
}
break;
case mp_ll_corner_op:
if(!mp_get_cur_bbox(mp))
mp_bad_unary(mp,mp_ll_corner_op);
else
mp_pair_value(mp,mp_minx,mp_miny);
break;
case mp_lr_corner_op:
if(!mp_get_cur_bbox(mp))
mp_bad_unary(mp,mp_lr_corner_op);
else
mp_pair_value(mp,mp_maxx,mp_miny);
break;
case mp_ul_corner_op:
if(!mp_get_cur_bbox(mp))
mp_bad_unary(mp,mp_ul_corner_op);
else
mp_pair_value(mp,mp_minx,mp_maxy);
break;
case mp_ur_corner_op:
if(!mp_get_cur_bbox(mp))
mp_bad_unary(mp,mp_ur_corner_op);
else
mp_pair_value(mp,mp_maxx,mp_maxy);
break;
case mp_read_from_op:
case mp_close_from_op:
if(mp->cur_exp.type!=mp_string_type)
mp_bad_unary(mp,c);
else
mp_do_read_or_close(mp,c);
break;

}
check_arith();
}


/*:971*//*980:*/
#line 26145 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_color_part(MP mp,quarterword c){
mp_node p;
mp_value new_expr;
char msg[256];
int old_setting;
mp_string sname;
const char*hlp[]= {
"You can only ask for the redpart, greenpart, bluepart of a rgb object,",
"the cyanpart, magentapart, yellowpart or blackpart of a cmyk object, ",
"or the greypart of a grey object. No mixing and matching, please.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
p= mp_link(edge_list(cur_exp_node()));
mp_disp_err(mp,NULL);
old_setting= mp->selector;
mp->selector= new_string;
mp_print_op(mp,c);
sname= mp_make_string(mp);
mp->selector= old_setting;
;
if(mp_color_model(p)==mp_grey_model)
mp_snprintf(msg,256,"Wrong picture color model: %s of grey object",mp_str(mp,sname));
else if(mp_color_model(p)==mp_cmyk_model)
mp_snprintf(msg,256,"Wrong picture color model: %s of cmyk object",mp_str(mp,sname));
else if(mp_color_model(p)==mp_rgb_model)
mp_snprintf(msg,256,"Wrong picture color model: %s of rgb object",mp_str(mp,sname));
else if(mp_color_model(p)==mp_no_model)
mp_snprintf(msg,256,"Wrong picture color model: %s of marking object",mp_str(mp,sname));
else
mp_snprintf(msg,256,"Wrong picture color model: %s of defaulted object",mp_str(mp,sname));
delete_str_ref(sname);
mp_error(mp,msg,hlp,true);
if(c==mp_black_part)
number_clone(new_expr.data.n,unity_t);
else
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}


/*:980*//*991:*/
#line 26665 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bezier_slope(MP mp,mp_number*ret,mp_number AX,mp_number AY,mp_number BX,
mp_number BY,mp_number CX,mp_number CY,mp_number DX,
mp_number DY){
double a,b,c;
mp_number deltax,deltay;
double ax,ay,bx,by,cx,cy,dx,dy;
mp_number xi,xo,xm;
double res= 0;
ax= number_to_double(AX);
ay= number_to_double(AY);
bx= number_to_double(BX);
by= number_to_double(BY);
cx= number_to_double(CX);
cy= number_to_double(CY);
dx= number_to_double(DX);
dy= number_to_double(DY);
new_number(deltax);
new_number(deltay);
set_number_from_substraction(deltax,BX,AX);
set_number_from_substraction(deltay,BY,AY);
if(number_zero(deltax)&&number_zero(deltay)){
set_number_from_substraction(deltax,CX,AX);
set_number_from_substraction(deltay,CY,AY);
}
if(number_zero(deltax)&&number_zero(deltay)){
set_number_from_substraction(deltax,DX,AX);
set_number_from_substraction(deltay,DY,AY);
}
new_number(xi);
new_number(xm);
new_number(xo);
mp_an_angle(mp,&xi,deltax,deltay);
set_number_from_substraction(deltax,CX,BX);
set_number_from_substraction(deltay,CY,BY);
mp_an_angle(mp,&xm,deltax,deltay);
set_number_from_substraction(deltax,DX,CX);
set_number_from_substraction(deltay,DY,CY);
if(number_zero(deltax)&&number_zero(deltay)){
set_number_from_substraction(deltax,DX,BX);
set_number_from_substraction(deltay,DY,BY);
}
if(number_zero(deltax)&&number_zero(deltay)){
set_number_from_substraction(deltax,DX,AX);
set_number_from_substraction(deltay,DY,AY);
}
mp_an_angle(mp,&xo,deltax,deltay);
a= (bx-ax)*(cy-by)-(cx-bx)*(by-ay);
b= (bx-ax)*(dy-cy)-(by-ay)*(dx-cx);;
c= (cx-bx)*(dy-cy)-(dx-cx)*(cy-by);
if((a==0)&&(c==0)){
res= (b==0?0:(mp_out(number_to_double(xo))-mp_out(number_to_double(xi))));
}else if((a==0)||(c==0)){
if((mp_sign(b)==mp_sign(a))||(mp_sign(b)==mp_sign(c))){
res= mp_out(number_to_double(xo))-mp_out(number_to_double(xi));
if(res<-180.0)
res+= 360.0;
else if(res> 180.0)
res-= 360.0;
}else{
res= mp_out(number_to_double(xo))-mp_out(number_to_double(xi));
}
}else if((mp_sign(a)*mp_sign(c))<0){
res= mp_out(number_to_double(xo))-mp_out(number_to_double(xi));
if(res<-180.0)
res+= 360.0;
else if(res> 180.0)
res-= 360.0;
}else{
if(mp_sign(a)==mp_sign(b)){
res= mp_out(number_to_double(xo))-mp_out(number_to_double(xi));
if(res<-180.0)
res+= 360.0;
else if(res> 180.0)
res-= 360.0;
}else{
if((b*b)==(4*a*c)){
res= (double)bezier_error;
}else if((b*b)<(4*a*c)){
res= mp_out(number_to_double(xo))-mp_out(number_to_double(xi));
if(res<=0.0&&res> -180.0)
res+= 360.0;
else if(res>=0.0&&res<180.0)
res-= 360.0;
}else{
res= mp_out(number_to_double(xo))-mp_out(number_to_double(xi));
if(res<-180.0)
res+= 360.0;
else if(res> 180.0)
res-= 360.0;
}
}
}
free_number(deltax);
free_number(deltay);
free_number(xi);
free_number(xo);
free_number(xm);
set_number_from_double(*ret,res);
convert_scaled_to_angle(*ret);
}


/*:991*//*1000:*/
#line 27161 "../../../source/texk/web2c/mplibdir/mp.w"

/*1001:*/
#line 27762 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bad_binary(MP mp,mp_node p,quarterword c){
char msg[256];
mp_string sname;
int old_setting= mp->selector;
const char*hlp[]= {
"I'm afraid I don't know how to apply that operation to that",
"combination of types. Continue, and I'll return the second",
"argument (see above) as the result of the operation.",
NULL};
mp->selector= new_string;
if(c>=mp_min_of)
mp_print_op(mp,c);
mp_print_known_or_unknown_type(mp,mp_type(p),p);
if(c>=mp_min_of)
mp_print(mp,"of");
else
mp_print_op(mp,c);
mp_print_known_or_unknown_type(mp,mp->cur_exp.type,cur_exp_node());
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Not implemented: %s",mp_str(mp,sname));
;
delete_str_ref(sname);
mp_disp_err(mp,p);
mp_disp_err(mp,NULL);
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
static void mp_bad_envelope_pen(MP mp){
const char*hlp[]= {
"I'm afraid I don't know how to apply that operation to that",
"combination of types. Continue, and I'll return the second",
"argument (see above) as the result of the operation.",
NULL};
mp_disp_err(mp,NULL);
mp_disp_err(mp,NULL);
mp_back_error(mp,"Not implemented: envelope(elliptical pen)of(path)",hlp,true);
;
mp_get_x_next(mp);
}

/*:1001*//*1002:*/
#line 27804 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_tarnished(MP mp,mp_node p){
mp_node q;
mp_node r;
(void)mp;
q= value_node(p);
switch(mp_type(p)){
case mp_pair_type:
r= x_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= y_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
break;
case mp_color_type:
r= red_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= green_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= blue_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
break;
case mp_cmykcolor_type:
r= cyan_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= magenta_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= yellow_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= black_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
break;
case mp_transform_type:
r= tx_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= ty_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= xx_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= xy_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= yx_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
r= yy_part(q);
if(mp_type(r)==mp_independent)
return MP_VOID;
break;
default:
break;
}
return NULL;
}

/*:1002*//*1003:*/
#line 27881 "../../../source/texk/web2c/mplibdir/mp.w"

/*1004:*/
#line 27993 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_dep_finish(MP mp,mp_value_node v,mp_value_node q,
quarterword t){
mp_value_node p;
if(q==NULL)
p= (mp_value_node)cur_exp_node();
else
p= q;
set_dep_list(p,v);
mp_type(p)= t;
if(dep_info(v)==NULL){
mp_number vv;
new_number(vv);
number_clone(vv,value_number(v));
if(q==NULL){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
number_clone(new_expr.data.n,vv);
mp_flush_cur_exp(mp,new_expr);
}else{
mp_recycle_value(mp,(mp_node)p);
mp_type(q)= mp_known;
set_value_number(q,vv);
}
free_number(vv);
}else if(q==NULL){
mp->cur_exp.type= t;
}
if(mp->fix_needed)
mp_fix_dependencies(mp);
}

/*:1004*/
#line 27882 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_add_or_subtract(MP mp,mp_node p,mp_node q,quarterword c){
mp_variable_type s,t;
mp_value_node r;
mp_value_node v= NULL;
mp_number vv;
new_number(vv);
if(q==NULL){
t= mp->cur_exp.type;
if(t<mp_dependent)
number_clone(vv,cur_exp_value_number());
else
v= (mp_value_node)dep_list((mp_value_node)cur_exp_node());
}else{
t= mp_type(q);
if(t<mp_dependent)
number_clone(vv,value_number(q));
else
v= (mp_value_node)dep_list((mp_value_node)q);
}
if(t==mp_known){
mp_value_node qq= (mp_value_node)q;
if(c==mp_minus)
number_negate(vv);
if(mp_type(p)==mp_known){
slow_add(vv,value_number(p),vv);
if(q==NULL)
set_cur_exp_value_number(vv);
else
set_value_number(q,vv);
free_number(vv);
return;
}

r= (mp_value_node)dep_list((mp_value_node)p);
while(dep_info(r)!=NULL)
r= (mp_value_node)mp_link(r);
slow_add(vv,dep_value(r),vv);
set_dep_value(r,vv);
if(qq==NULL){
qq= mp_get_dep_node(mp);
set_cur_exp_node((mp_node)qq);
mp->cur_exp.type= mp_type(p);
mp_name_type(qq)= mp_capsule;

}
set_dep_list(qq,dep_list((mp_value_node)p));
mp_type(qq)= mp_type(p);
set_prev_dep(qq,prev_dep((mp_value_node)p));
mp_link(prev_dep((mp_value_node)p))= (mp_node)qq;
mp_type(p)= mp_known;
}else{
if(c==mp_minus)
mp_negate_dep_list(mp,v);




if(mp_type(p)==mp_known){

while(dep_info(v)!=NULL){
v= (mp_value_node)mp_link(v);
}
slow_add(vv,value_number(p),dep_value(v));
set_dep_value(v,vv);
}else{
s= mp_type(p);
r= (mp_value_node)dep_list((mp_value_node)p);
if(t==mp_dependent){
if(s==mp_dependent){
mp_number ret1,ret2;
new_fraction(ret1);
new_fraction(ret2);
mp_max_coef(mp,&ret1,r);
mp_max_coef(mp,&ret2,v);
number_add(ret1,ret2);
free_number(ret2);
if(number_less(ret1,coef_bound_k)){
v= mp_p_plus_q(mp,v,r,mp_dependent);
free_number(ret1);
goto DONE;
}
free_number(ret1);
}
t= mp_proto_dependent;
v= mp_p_over_v(mp,v,unity_t,mp_dependent,mp_proto_dependent);
}
if(s==mp_proto_dependent)
v= mp_p_plus_q(mp,v,r,mp_proto_dependent);
else
v= mp_p_plus_fq(mp,v,unity_t,r,mp_proto_dependent,mp_dependent);
DONE:

if(q!=NULL){
mp_dep_finish(mp,v,(mp_value_node)q,t);
}else{
mp->cur_exp.type= t;
mp_dep_finish(mp,v,NULL,t);
}
}
}
free_number(vv);
}


/*:1003*//*1005:*/
#line 28026 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_dep_mult(MP mp,mp_value_node p,mp_number v,boolean v_is_scaled){
mp_value_node q;
quarterword s,t;
if(p==NULL){
q= (mp_value_node)cur_exp_node();
}else if(mp_type(p)!=mp_known){
q= p;
}else{
{
mp_number r1,arg1;
new_number(arg1);
number_clone(arg1,dep_value(p));
if(v_is_scaled){
new_number(r1);
take_scaled(r1,arg1,v);
}else{
new_fraction(r1);
take_fraction(r1,arg1,v);
}
set_dep_value(p,r1);
free_number(r1);
free_number(arg1);
}
return;
}
t= mp_type(q);
q= (mp_value_node)dep_list(q);
s= t;
if(t==mp_dependent){
if(v_is_scaled){
mp_number ab_vs_cd;
mp_number arg1,arg2;
new_number(ab_vs_cd);
new_number(arg2);
new_fraction(arg1);
mp_max_coef(mp,&arg1,q);
number_clone(arg2,v);
number_abs(arg2);
ab_vs_cd(ab_vs_cd,arg1,arg2,coef_bound_minus_1,unity_t);
free_number(arg1);
free_number(arg2);
if(number_nonnegative(ab_vs_cd)){
t= mp_proto_dependent;
}
free_number(ab_vs_cd);
}
}
q= mp_p_times_v(mp,q,v,s,t,v_is_scaled);
mp_dep_finish(mp,q,p,t);
}


/*:1005*//*1008:*/
#line 28159 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_hard_times(MP mp,mp_node p){
mp_value_node q;
mp_value_node pp;
mp_node r;
mp_number v;
new_number(v);
if(mp_type(p)<=mp_pair_type){
q= (mp_value_node)mp_stash_cur_exp(mp);
mp_unstash_cur_exp(mp,p);
p= (mp_node)q;
}
pp= (mp_value_node)p;
if(mp->cur_exp.type==mp_pair_type){
r= x_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
r= y_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
}else if(mp->cur_exp.type==mp_color_type){
r= red_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
r= green_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
r= blue_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
}else if(mp->cur_exp.type==mp_cmykcolor_type){
r= cyan_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
r= yellow_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
r= magenta_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
r= black_part(value_node(cur_exp_node()));
number_clone(v,value_number(r));
mp_new_dep(mp,r,mp_type(pp),
mp_copy_dep_list(mp,(mp_value_node)dep_list(pp)));
mp_dep_mult(mp,(mp_value_node)r,v,true);
}
free_number(v);
}

/*:1008*//*1009:*/
#line 28224 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_dep_div(MP mp,mp_value_node p,mp_number v){
mp_value_node q;
quarterword s,t;
if(p==NULL)
q= (mp_value_node)cur_exp_node();
else if(mp_type(p)!=mp_known)
q= p;
else{
mp_number ret;
new_number(ret);
make_scaled(ret,value_number(p),v);
set_value_number(p,ret);
free_number(ret);
return;
}
t= mp_type(q);
q= (mp_value_node)dep_list(q);
s= t;
if(t==mp_dependent){
mp_number ab_vs_cd;
mp_number arg1,arg2;
new_number(ab_vs_cd);
new_number(arg2);
new_fraction(arg1);
mp_max_coef(mp,&arg1,q);
number_clone(arg2,v);
number_abs(arg2);
ab_vs_cd(ab_vs_cd,arg1,unity_t,coef_bound_minus_1,arg2);
free_number(arg1);
free_number(arg2);
if(number_nonnegative(ab_vs_cd)){
t= mp_proto_dependent;
}
free_number(ab_vs_cd);
}
q= mp_p_over_v(mp,q,v,s,t);
mp_dep_finish(mp,q,p,t);
}

/*:1009*//*1010:*/
#line 28273 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_up_trans(MP mp,quarterword c){
mp_node p,q,r;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
if((c!=mp_transformed_by)||(mp->cur_exp.type!=mp_transform_type)){

const char*hlp[]= {
"The expression shown above has the wrong type,",
"so I can\'t transform anything using it.",
"Proceed, and I'll omit the transformation.",
NULL};
p= mp_stash_cur_exp(mp);
set_cur_exp_node(mp_id_transform(mp));
mp->cur_exp.type= mp_transform_type;
q= value_node(cur_exp_node());
switch(c){
/*1014:*/
#line 28354 "../../../source/texk/web2c/mplibdir/mp.w"

case mp_rotated_by:
if(mp_type(p)==mp_known)
/*1015:*/
#line 28400 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number n_sin,n_cos,arg1,arg2;
new_number(arg1);
new_number(arg2);
new_fraction(n_sin);
new_fraction(n_cos);
number_clone(arg2,unity_t);
number_clone(arg1,value_number(p));
number_multiply_int(arg2,360);
number_modulo(arg1,arg2);
convert_scaled_to_angle(arg1);
n_sin_cos(arg1,n_cos,n_sin);
fraction_to_round_scaled(n_sin);
fraction_to_round_scaled(n_cos);
set_value_number(xx_part(q),n_cos);
set_value_number(yx_part(q),n_sin);
set_value_number(xy_part(q),value_number(yx_part(q)));
number_negate(value_number(xy_part(q)));
set_value_number(yy_part(q),value_number(xx_part(q)));
free_number(arg1);
free_number(arg2);
free_number(n_sin);
free_number(n_cos);
goto DONE;
}


/*:1015*/
#line 28357 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_slanted_by:
if(mp_type(p)> mp_pair_type){
mp_install(mp,xy_part(q),p);
goto DONE;
}
break;
case mp_scaled_by:
if(mp_type(p)> mp_pair_type){
mp_install(mp,xx_part(q),p);
mp_install(mp,yy_part(q),p);
goto DONE;
}
break;
case mp_shifted_by:
if(mp_type(p)==mp_pair_type){
r= value_node(p);
mp_install(mp,tx_part(q),x_part(r));
mp_install(mp,ty_part(q),y_part(r));
goto DONE;
}
break;
case mp_x_scaled:
if(mp_type(p)> mp_pair_type){
mp_install(mp,xx_part(q),p);
goto DONE;
}
break;
case mp_y_scaled:
if(mp_type(p)> mp_pair_type){
mp_install(mp,yy_part(q),p);
goto DONE;
}
break;
case mp_z_scaled:
if(mp_type(p)==mp_pair_type)
/*1016:*/
#line 28428 "../../../source/texk/web2c/mplibdir/mp.w"

{
r= value_node(p);
mp_install(mp,xx_part(q),x_part(r));
mp_install(mp,yy_part(q),x_part(r));
mp_install(mp,yx_part(q),y_part(r));
if(mp_type(y_part(r))==mp_known){
set_value_number(y_part(r),value_number(y_part(r)));
number_negate(value_number(y_part(r)));
}else{
mp_negate_dep_list(mp,(mp_value_node)dep_list((mp_value_node)
y_part(r)));
}
mp_install(mp,xy_part(q),y_part(r));
goto DONE;
}


/*:1016*/
#line 28394 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_transformed_by:
break;


/*:1014*/
#line 28292 "../../../source/texk/web2c/mplibdir/mp.w"
;
};
mp_disp_err(mp,p);
mp_back_error(mp,"Improper transformation argument",hlp,true);
mp_get_x_next(mp);
DONE:
mp_recycle_value(mp,p);
mp_free_value_node(mp,p);

}


q= value_node(cur_exp_node());
if(mp_type(tx_part(q))!=mp_known)
return;
if(mp_type(ty_part(q))!=mp_known)
return;
if(mp_type(xx_part(q))!=mp_known)
return;
if(mp_type(xy_part(q))!=mp_known)
return;
if(mp_type(yx_part(q))!=mp_known)
return;
if(mp_type(yy_part(q))!=mp_known)
return;
number_clone(mp->txx,value_number(xx_part(q)));
number_clone(mp->txy,value_number(xy_part(q)));
number_clone(mp->tyx,value_number(yx_part(q)));
number_clone(mp->tyy,value_number(yy_part(q)));
number_clone(mp->tx,value_number(tx_part(q)));
number_clone(mp->ty,value_number(ty_part(q)));
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}


/*:1010*//*1017:*/
#line 28449 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_up_known_trans(MP mp,quarterword c){
mp_set_up_trans(mp,c);
if(mp->cur_exp.type!=mp_known){
mp_value new_expr;
const char*hlp[]= {
"I'm unable to apply a partially specified transformation",
"except to a fully known pair or transform.",
"Proceed, and I'll omit the transformation.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Transform components aren't all known",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
set_number_to_unity(mp->txx);
set_number_to_zero(mp->txy);
set_number_to_zero(mp->tyx);
set_number_to_unity(mp->tyy);
set_number_to_zero(mp->tx);
set_number_to_zero(mp->ty);
}
}


/*:1017*//*1018:*/
#line 28479 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_number_trans(MP mp,mp_number*p,mp_number*q){
mp_number r1,r2,v;
new_number(r1);
new_number(r2);
new_number(v);
take_scaled(r1,*p,mp->txx);
take_scaled(r2,*q,mp->txy);
number_add(r1,r2);
set_number_from_addition(v,r1,mp->tx);
take_scaled(r1,*p,mp->tyx);
take_scaled(r2,*q,mp->tyy);
number_add(r1,r2);
set_number_from_addition(*q,r1,mp->ty);
number_clone(*p,v);
free_number(r1);
free_number(r2);
free_number(v);
}


/*:1018*//*1019:*/
#line 28509 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_path_trans(MP mp,mp_knot p){
mp_knot q;
q= p;
do{
if(mp_left_type(q)!=mp_endpoint)
mp_number_trans(mp,&q->left_x,&q->left_y);
mp_number_trans(mp,&q->x_coord,&q->y_coord);
if(mp_right_type(q)!=mp_endpoint)
mp_number_trans(mp,&q->right_x,&q->right_y);
q= mp_next_knot(q);
}while(q!=p);
}


/*:1019*//*1020:*/
#line 28531 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_pen_trans(MP mp,mp_knot p){
mp_knot q;
if(pen_is_elliptical(p)){
mp_number_trans(mp,&p->left_x,&p->left_y);
mp_number_trans(mp,&p->right_x,&p->right_y);
}
q= p;
do{
mp_number_trans(mp,&q->x_coord,&q->y_coord);
q= mp_next_knot(q);
}while(q!=p);
}


/*:1020*//*1021:*/
#line 28555 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_edge_header_node mp_edges_trans(MP mp,mp_edge_header_node h){
mp_node q;
mp_dash_node r,s;
mp_number sx,sy;
mp_number sqdet;
mp_number sgndet;
h= mp_private_edges(mp,h);
new_number(sx);
new_number(sy);
new_number(sqdet);
new_number(sgndet);
mp_sqrt_det(mp,&sqdet,mp->txx,mp->txy,mp->tyx,mp->tyy);
ab_vs_cd(sgndet,mp->txx,mp->tyy,mp->txy,mp->tyx);
if(dash_list(h)!=mp->null_dash){
/*1022:*/
#line 28601 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_nonzero(mp->txy)||number_nonzero(mp->tyx)||
number_nonzero(mp->ty)||number_nonequalabs(mp->txx,mp->tyy)){
mp_flush_dash_list(mp,h);
}else{
mp_number abs_tyy,ret;
new_number(abs_tyy);
if(number_negative(mp->txx)){
/*1023:*/
#line 28622 "../../../source/texk/web2c/mplibdir/mp.w"

{
r= dash_list(h);
set_dash_list(h,mp->null_dash);
while(r!=mp->null_dash){
s= r;
r= (mp_dash_node)mp_link(r);
number_swap(s->start_x,s->stop_x);
mp_link(s)= (mp_node)dash_list(h);
set_dash_list(h,s);
}
}


/*:1023*/
#line 28609 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
/*1024:*/
#line 28636 "../../../source/texk/web2c/mplibdir/mp.w"

r= dash_list(h);
{
mp_number arg1;
new_number(arg1);
while(r!=mp->null_dash){
take_scaled(arg1,r->start_x,mp->txx);
set_number_from_addition(r->start_x,arg1,mp->tx);
take_scaled(arg1,r->stop_x,mp->txx);
set_number_from_addition(r->stop_x,arg1,mp->tx);
r= (mp_dash_node)mp_link(r);
}
free_number(arg1);
}


/*:1024*/
#line 28611 "../../../source/texk/web2c/mplibdir/mp.w"
;
number_clone(abs_tyy,mp->tyy);
number_abs(abs_tyy);
new_number(ret);
take_scaled(ret,h->dash_y,abs_tyy);
number_clone(h->dash_y,ret);
free_number(ret);
free_number(abs_tyy);
}


/*:1022*/
#line 28570 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
/*1025:*/
#line 28652 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_zero(mp->txx)&&number_zero(mp->tyy)){
/*1026:*/
#line 28666 "../../../source/texk/web2c/mplibdir/mp.w"

{
number_swap(h->minx,h->miny);
number_swap(h->maxx,h->maxy);
}


/*:1026*/
#line 28654 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(number_nonzero(mp->txy)||number_nonzero(mp->tyx)){
mp_init_bbox(mp,h);
goto DONE1;
}
if(number_lessequal(h->minx,h->maxx)){
/*1027:*/
#line 28676 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number tot,ret;
new_number(tot);
new_number(ret);
set_number_from_addition(tot,mp->txx,mp->txy);
take_scaled(ret,h->minx,tot);
set_number_from_addition(h->minx,ret,mp->tx);
take_scaled(ret,h->maxx,tot);
set_number_from_addition(h->maxx,ret,mp->tx);

set_number_from_addition(tot,mp->tyx,mp->tyy);
take_scaled(ret,h->miny,tot);
set_number_from_addition(h->miny,ret,mp->ty);
take_scaled(ret,h->maxy,tot);
set_number_from_addition(h->maxy,ret,mp->ty);

set_number_from_addition(tot,mp->txx,mp->txy);
if(number_negative(tot)){
number_swap(h->minx,h->maxx);
}
set_number_from_addition(tot,mp->tyx,mp->tyy);
if(number_negative(tot)){
number_swap(h->miny,h->maxy);
}
free_number(ret);
free_number(tot);
}


/*:1027*/
#line 28661 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
DONE1:


/*:1025*/
#line 28573 "../../../source/texk/web2c/mplibdir/mp.w"
;
q= mp_link(edge_list(h));
while(q!=NULL){
/*1028:*/
#line 28709 "../../../source/texk/web2c/mplibdir/mp.w"

switch(mp_type(q)){
case mp_fill_node_type:
{
mp_fill_node qq= (mp_fill_node)q;
mp_do_path_trans(mp,mp_path_p(qq));
/*1029:*/
#line 28751 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp_pen_p(qq)!=NULL){
number_clone(sx,mp->tx);
number_clone(sy,mp->ty);
set_number_to_zero(mp->tx);
set_number_to_zero(mp->ty);
mp_do_pen_trans(mp,mp_pen_p(qq));
if(number_nonzero(sqdet)
&&((mp_type(q)==mp_stroked_node_type)&&(mp_dash_p(q)!=NULL))){
mp_number ret;
new_number(ret);
take_scaled(ret,((mp_stroked_node)q)->dash_scale,sqdet);
number_clone(((mp_stroked_node)q)->dash_scale,ret);
free_number(ret);
}
if(!pen_is_elliptical(mp_pen_p(qq)))
if(number_negative(sgndet))
mp_pen_p(qq)= mp_make_pen(mp,mp_copy_path(mp,mp_pen_p(qq)),true);

number_clone(mp->tx,sx);
number_clone(mp->ty,sy);
}

/*:1029*/
#line 28715 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
break;
case mp_stroked_node_type:
{
mp_stroked_node qq= (mp_stroked_node)q;
mp_do_path_trans(mp,mp_path_p(qq));
/*1029:*/
#line 28751 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp_pen_p(qq)!=NULL){
number_clone(sx,mp->tx);
number_clone(sy,mp->ty);
set_number_to_zero(mp->tx);
set_number_to_zero(mp->ty);
mp_do_pen_trans(mp,mp_pen_p(qq));
if(number_nonzero(sqdet)
&&((mp_type(q)==mp_stroked_node_type)&&(mp_dash_p(q)!=NULL))){
mp_number ret;
new_number(ret);
take_scaled(ret,((mp_stroked_node)q)->dash_scale,sqdet);
number_clone(((mp_stroked_node)q)->dash_scale,ret);
free_number(ret);
}
if(!pen_is_elliptical(mp_pen_p(qq)))
if(number_negative(sgndet))
mp_pen_p(qq)= mp_make_pen(mp,mp_copy_path(mp,mp_pen_p(qq)),true);

number_clone(mp->tx,sx);
number_clone(mp->ty,sy);
}

/*:1029*/
#line 28722 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
break;
case mp_start_clip_node_type:
mp_do_path_trans(mp,mp_path_p((mp_start_clip_node)q));
break;
case mp_start_bounds_node_type:
mp_do_path_trans(mp,mp_path_p((mp_start_bounds_node)q));
break;
case mp_text_node_type:
/*1030:*/
#line 28774 "../../../source/texk/web2c/mplibdir/mp.w"

mp_number_trans(mp,&((mp_text_node)q)->tx,&((mp_text_node)q)->ty);
number_clone(sx,mp->tx);
number_clone(sy,mp->ty);
set_number_to_zero(mp->tx);
set_number_to_zero(mp->ty);
mp_number_trans(mp,&((mp_text_node)q)->txx,&((mp_text_node)q)->tyx);
mp_number_trans(mp,&((mp_text_node)q)->txy,&((mp_text_node)q)->tyy);
number_clone(mp->tx,sx);
number_clone(mp->ty,sy)

/*:1030*/
#line 28732 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case mp_stop_clip_node_type:
case mp_stop_bounds_node_type:
break;
default:
break;
}


/*:1028*/
#line 28576 "../../../source/texk/web2c/mplibdir/mp.w"
;
q= mp_link(q);
}
free_number(sx);
free_number(sy);
free_number(sqdet);
free_number(sgndet);
return h;
}
static void mp_do_edges_trans(MP mp,mp_node p,quarterword c){
mp_set_up_known_trans(mp,c);
set_value_node(p,(mp_node)mp_edges_trans(mp,(mp_edge_header_node)value_node(p)));
mp_unstash_cur_exp(mp,p);
}
static mp_edge_header_node mp_scale_edges(MP mp,mp_number se_sf,mp_edge_header_node se_pic){
number_clone(mp->txx,se_sf);
number_clone(mp->tyy,se_sf);
set_number_to_zero(mp->txy);
set_number_to_zero(mp->tyx);
set_number_to_zero(mp->tx);
set_number_to_zero(mp->ty);
return mp_edges_trans(mp,se_pic);
}


/*:1021*//*1031:*/
#line 28788 "../../../source/texk/web2c/mplibdir/mp.w"

/*1033:*/
#line 28833 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bilin1(MP mp,mp_node p,mp_number t,mp_node q,
mp_number u,mp_number delta_orig){
mp_number delta;
new_number(delta);
number_clone(delta,delta_orig);
if(!number_equal(t,unity_t)){
mp_dep_mult(mp,(mp_value_node)p,t,true);
}
if(number_nonzero(u)){
if(mp_type(q)==mp_known){
mp_number tmp;
new_number(tmp);
take_scaled(tmp,value_number(q),u);
number_add(delta,tmp);
free_number(tmp);
}else{

if(mp_type(p)!=mp_proto_dependent){
if(mp_type(p)==mp_known){
mp_new_dep(mp,p,mp_type(p),mp_const_dependency(mp,value_number(p)));
}else{
set_dep_list((mp_value_node)p,
mp_p_times_v(mp,
(mp_value_node)dep_list((mp_value_node)
p),unity_t,
mp_dependent,mp_proto_dependent,true));
}
mp_type(p)= mp_proto_dependent;
}
set_dep_list((mp_value_node)p,
mp_p_plus_fq(mp,
(mp_value_node)dep_list((mp_value_node)p),u,
(mp_value_node)dep_list((mp_value_node)q),
mp_proto_dependent,mp_type(q)));
}
}
if(mp_type(p)==mp_known){
set_value_number(p,value_number(p));
number_add(value_number(p),delta);
}else{
mp_number tmp;
mp_value_node r;
new_number(tmp);
r= (mp_value_node)dep_list((mp_value_node)p);
while(dep_info(r)!=NULL)
r= (mp_value_node)mp_link(r);
number_clone(tmp,value_number(r));
number_add(delta,tmp);
if(r!=(mp_value_node)dep_list((mp_value_node)p))
set_value_number(r,delta);
else{
mp_recycle_value(mp,p);
mp_type(p)= mp_known;
set_value_number(p,delta);
}
free_number(tmp);
}
if(mp->fix_needed)
mp_fix_dependencies(mp);
free_number(delta);
}


/*:1033*//*1035:*/
#line 28929 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_add_mult_dep(MP mp,mp_value_node p,mp_number v,mp_node r){
if(mp_type(r)==mp_known){
mp_number ret;
new_number(ret);
take_scaled(ret,value_number(r),v);
set_dep_value(mp->dep_final,dep_value(mp->dep_final));
number_add(dep_value(mp->dep_final),ret);
free_number(ret);
}else{
set_dep_list(p,
mp_p_plus_fq(mp,(mp_value_node)dep_list(p),v,
(mp_value_node)dep_list((mp_value_node)r),
mp_proto_dependent,mp_type(r)));
if(mp->fix_needed)
mp_fix_dependencies(mp);
}
}


/*:1035*//*1036:*/
#line 28956 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bilin2(MP mp,mp_node p,mp_node t,mp_number v,
mp_node u,mp_node q){
mp_number vv;
new_number(vv);
number_clone(vv,value_number(p));
mp_new_dep(mp,p,mp_proto_dependent,mp_const_dependency(mp,zero_t));
if(number_nonzero(vv)){
mp_add_mult_dep(mp,(mp_value_node)p,vv,t);
}
if(number_nonzero(v)){
mp_number arg1;
new_number(arg1);
number_clone(arg1,v);
mp_add_mult_dep(mp,(mp_value_node)p,arg1,u);
free_number(arg1);
}
if(q!=NULL)
mp_add_mult_dep(mp,(mp_value_node)p,unity_t,q);
if(dep_list((mp_value_node)p)==(mp_node)mp->dep_final){
number_clone(vv,dep_value(mp->dep_final));
mp_recycle_value(mp,p);
mp_type(p)= mp_known;
set_value_number(p,vv);
}
free_number(vv);
}


/*:1036*//*1038:*/
#line 29002 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_bilin3(MP mp,mp_node p,mp_number t,
mp_number v,mp_number u,mp_number delta_orig){
mp_number delta;
mp_number tmp;
new_number(tmp);
new_number(delta);
number_clone(delta,delta_orig);
if(!number_equal(t,unity_t)){
take_scaled(tmp,value_number(p),t);
}else{
number_clone(tmp,value_number(p));
}
number_add(delta,tmp);
if(number_nonzero(u)){
mp_number ret;
new_number(ret);
take_scaled(ret,v,u);
set_value_number(p,delta);
number_add(value_number(p),ret);
free_number(ret);
}else
set_value_number(p,delta);
free_number(tmp);
free_number(delta);
}


/*:1038*/
#line 28789 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_big_trans(MP mp,mp_node p,quarterword c){
mp_node q,r,pp,qq;
q= value_node(p);
if(mp_type(q)==mp_pair_node_type){
if(mp_type(x_part(q))!=mp_known||
mp_type(y_part(q))!=mp_known){
/*1032:*/
#line 28812 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_set_up_known_trans(mp,c);
mp_make_exp_copy(mp,p);
r= value_node(cur_exp_node());
if(mp->cur_exp.type==mp_transform_type){
mp_bilin1(mp,yy_part(r),mp->tyy,xy_part(q),mp->tyx,zero_t);
mp_bilin1(mp,yx_part(r),mp->tyy,xx_part(q),mp->tyx,zero_t);
mp_bilin1(mp,xy_part(r),mp->txx,yy_part(q),mp->txy,zero_t);
mp_bilin1(mp,xx_part(r),mp->txx,yx_part(q),mp->txy,zero_t);
}
mp_bilin1(mp,y_part(r),mp->tyy,x_part(q),mp->tyx,mp->ty);
mp_bilin1(mp,x_part(r),mp->txx,y_part(q),mp->txy,mp->tx);
return;
}


/*:1032*/
#line 28796 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}else{
if(mp_type(tx_part(q))!=mp_known||
mp_type(ty_part(q))!=mp_known||
mp_type(xx_part(q))!=mp_known||
mp_type(xy_part(q))!=mp_known||
mp_type(yx_part(q))!=mp_known||
mp_type(yy_part(q))!=mp_known){
/*1032:*/
#line 28812 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_set_up_known_trans(mp,c);
mp_make_exp_copy(mp,p);
r= value_node(cur_exp_node());
if(mp->cur_exp.type==mp_transform_type){
mp_bilin1(mp,yy_part(r),mp->tyy,xy_part(q),mp->tyx,zero_t);
mp_bilin1(mp,yx_part(r),mp->tyy,xx_part(q),mp->tyx,zero_t);
mp_bilin1(mp,xy_part(r),mp->txx,yy_part(q),mp->txy,zero_t);
mp_bilin1(mp,xx_part(r),mp->txx,yx_part(q),mp->txy,zero_t);
}
mp_bilin1(mp,y_part(r),mp->tyy,x_part(q),mp->tyx,mp->ty);
mp_bilin1(mp,x_part(r),mp->txx,y_part(q),mp->txy,mp->tx);
return;
}


/*:1032*/
#line 28805 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
/*1034:*/
#line 28897 "../../../source/texk/web2c/mplibdir/mp.w"

mp_set_up_trans(mp,c);
if(mp->cur_exp.type==mp_known){
/*1037:*/
#line 28985 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_make_exp_copy(mp,p);
r= value_node(cur_exp_node());
if(mp->cur_exp.type==mp_transform_type){
mp_bilin3(mp,yy_part(r),mp->tyy,value_number(xy_part(q)),mp->tyx,zero_t);
mp_bilin3(mp,yx_part(r),mp->tyy,value_number(xx_part(q)),mp->tyx,zero_t);
mp_bilin3(mp,xy_part(r),mp->txx,value_number(yy_part(q)),mp->txy,zero_t);
mp_bilin3(mp,xx_part(r),mp->txx,value_number(yx_part(q)),mp->txy,zero_t);
}
mp_bilin3(mp,y_part(r),mp->tyy,value_number(x_part(q)),mp->tyx,mp->ty);
mp_bilin3(mp,x_part(r),mp->txx,value_number(y_part(q)),mp->txy,mp->tx);
}


/*:1037*/
#line 28900 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
pp= mp_stash_cur_exp(mp);
qq= value_node(pp);
mp_make_exp_copy(mp,p);
r= value_node(cur_exp_node());
if(mp->cur_exp.type==mp_transform_type){
mp_bilin2(mp,yy_part(r),yy_part(qq),value_number(xy_part(q)),
yx_part(qq),NULL);
mp_bilin2(mp,yx_part(r),yy_part(qq),value_number(xx_part(q)),
yx_part(qq),NULL);
mp_bilin2(mp,xy_part(r),xx_part(qq),value_number(yy_part(q)),
xy_part(qq),NULL);
mp_bilin2(mp,xx_part(r),xx_part(qq),value_number(yx_part(q)),
xy_part(qq),NULL);
}
mp_bilin2(mp,y_part(r),yy_part(qq),value_number(x_part(q)),
yx_part(qq),y_part(qq));
mp_bilin2(mp,x_part(r),xx_part(qq),value_number(y_part(q)),
xy_part(qq),x_part(qq));
mp_recycle_value(mp,pp);
mp_free_value_node(mp,pp);
}


/*:1034*/
#line 28808 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:1031*//*1039:*/
#line 29030 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_chop_path(MP mp,mp_node p){
mp_knot q;
mp_knot pp,qq,rr,ss;
mp_number a,b;
mp_number l;
boolean reversed;
new_number(a);
new_number(b);
new_number(l);
mp_path_length(mp,&l);
number_clone(a,value_number(x_part(p)));
number_clone(b,value_number(y_part(p)));
if(number_lessequal(a,b)){
reversed= false;
}else{
reversed= true;
number_swap(a,b);
}

if(number_negative(a)){
if(mp_left_type(cur_exp_knot())==mp_endpoint){
set_number_to_zero(a);
if(number_negative(b))
set_number_to_zero(b);
}else{
do{
number_add(a,l);
number_add(b,l);
}while(number_negative(a));
}
}
if(number_greater(b,l)){
if(mp_left_type(cur_exp_knot())==mp_endpoint){
number_clone(b,l);
if(number_greater(a,l))
number_clone(a,l);
}else{
while(number_greaterequal(a,l)){
number_substract(a,l);
number_substract(b,l);
}
}
}

q= cur_exp_knot();
while(number_greaterequal(a,unity_t)){
q= mp_next_knot(q);
number_substract(a,unity_t);
number_substract(b,unity_t);
}
if(number_equal(b,a)){

if(number_positive(a)){
mp_number arg1;
new_number(arg1);
number_clone(arg1,a);
convert_scaled_to_fraction(arg1);
mp_split_cubic(mp,q,arg1);
free_number(arg1);
q= mp_next_knot(q);
}
pp= mp_copy_knot(mp,q);
qq= pp;

}else{

pp= mp_copy_knot(mp,q);
qq= pp;
do{
q= mp_next_knot(q);
rr= qq;
qq= mp_copy_knot(mp,q);
mp_next_knot(rr)= qq;
number_substract(b,unity_t);
}while(number_positive(b));
if(number_positive(a)){
mp_number arg1;
new_number(arg1);
ss= pp;
number_clone(arg1,a);
convert_scaled_to_fraction(arg1);
mp_split_cubic(mp,ss,arg1);
free_number(arg1);
pp= mp_next_knot(ss);
mp_toss_knot(mp,ss);
if(rr==ss){
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
set_number_from_substraction(arg1,unity_t,a);
number_clone(arg2,b);
make_scaled(b,arg2,arg1);
free_number(arg1);
free_number(arg2);
rr= pp;
}
}
if(number_negative(b)){
mp_number arg1;
new_number(arg1);
set_number_from_addition(arg1,b,unity_t);
convert_scaled_to_fraction(arg1);
mp_split_cubic(mp,rr,arg1);
free_number(arg1);
mp_toss_knot(mp,qq);
qq= mp_next_knot(rr);
}

}
mp_left_type(pp)= mp_endpoint;
mp_right_type(qq)= mp_endpoint;
mp_next_knot(qq)= pp;
mp_toss_knot_list(mp,cur_exp_knot());
if(reversed){
set_cur_exp_knot(mp_next_knot(mp_htap_ypoc(mp,pp)));
mp_toss_knot_list(mp,pp);
}else{
set_cur_exp_knot(pp);
}
free_number(l);
free_number(a);
free_number(b);
}


/*:1039*//*1040:*/
#line 29156 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_up_offset(MP mp,mp_node p){
mp_find_offset(mp,value_number(x_part(p)),value_number(y_part(p)),
cur_exp_knot());
mp_pair_value(mp,mp->cur_x,mp->cur_y);
}
static void mp_set_up_direction_time(MP mp,mp_node p){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_find_direction_time(mp,&new_expr.data.n,value_number(x_part(p)),
value_number(y_part(p)),
cur_exp_knot());
mp_flush_cur_exp(mp,new_expr);
}
static void mp_set_up_envelope(MP mp,mp_node p){
unsigned char ljoin,lcap;
mp_number miterlim;
mp_knot q= mp_copy_path(mp,cur_exp_knot());
new_number(miterlim);

if(pen_is_elliptical(value_knot(p))){
mp_bad_envelope_pen(mp);
set_cur_exp_knot(q);
mp->cur_exp.type= mp_path_type;
return;
}
if(number_greater(internal_value(mp_linejoin),unity_t))
ljoin= 2;
else if(number_positive(internal_value(mp_linejoin)))
ljoin= 1;
else
ljoin= 0;
if(number_greater(internal_value(mp_linecap),unity_t))
lcap= 2;
else if(number_positive(internal_value(mp_linecap)))
lcap= 1;
else
lcap= 0;
if(number_less(internal_value(mp_miterlimit),unity_t))
set_number_to_unity(miterlim);
else
number_clone(miterlim,internal_value(mp_miterlimit));
set_cur_exp_knot(mp_make_envelope
(mp,q,value_knot(p),ljoin,lcap,miterlim));
mp->cur_exp.type= mp_path_type;
}
static void mp_set_up_boundingpath(MP mp,mp_node p){
unsigned char ljoin,lcap;
mp_number miterlim;
mp_knot q= mp_copy_path(mp,cur_exp_knot());
mp_knot pen;
mp_knot qq;

new_number(miterlim);
pen= (value_knot(p));



if(pen_is_elliptical(value_knot(p))){
mp_knot kp,kq;
pen= copy_pen(value_knot(p));
mp_make_path(mp,pen);
kq= pen;
do{
kp= kq;
kq= mp_next_knot(kq);
mp_prev_knot(kq)= kp;
}while(kq!=pen);
mp_close_path_cycle(mp,kp,pen);
}
if(number_greater(internal_value(mp_linejoin),unity_t))
ljoin= 2;
else if(number_positive(internal_value(mp_linejoin)))
ljoin= 1;
else
ljoin= 0;
if(number_greater(internal_value(mp_linecap),unity_t))
lcap= 2;
else if(number_positive(internal_value(mp_linecap)))
lcap= 1;
else
lcap= 0;
if(number_less(internal_value(mp_miterlimit),unity_t))
set_number_to_unity(miterlim);
else
number_clone(miterlim,internal_value(mp_miterlimit));
qq= mp_make_envelope(mp,q,pen,ljoin,lcap,miterlim);
set_cur_exp_knot(qq);
mp->cur_exp.type= mp_path_type;
if(!mp_get_cur_bbox(mp)){
mp_bad_binary(mp,p,mp_boundingpath_of);
set_cur_exp_knot(q);
mp->cur_exp.type= mp_path_type;
return;
}
else{
mp_knot ll,lr,ur,ul;
ll= mp_new_knot(mp);
lr= mp_new_knot(mp);
ur= mp_new_knot(mp);
ul= mp_new_knot(mp);
if(ll==NULL||lr==NULL||ur==NULL||ul==NULL){
mp_bad_binary(mp,p,mp_boundingpath_of);
set_cur_exp_knot(q);
mp->cur_exp.type= mp_path_type;
return;
}
mp_left_type(ll)= mp_endpoint;
mp_right_type(ll)= mp_endpoint;
mp_originator(ll)= mp_program_code;
number_clone(ll->x_coord,mp_minx);
number_clone(ll->y_coord,mp_miny);

mp_originator(lr)= mp_program_code;
number_clone(lr->x_coord,mp_maxx);
number_clone(lr->y_coord,mp_miny);

mp_originator(ur)= mp_program_code;
number_clone(ur->x_coord,mp_maxx);
number_clone(ur->y_coord,mp_maxy);

mp_originator(ul)= mp_program_code;
number_clone(ul->x_coord,mp_minx);
number_clone(ul->y_coord,mp_maxy);

mp_next_knot(ll)= lr;
mp_next_knot(lr)= ur;
mp_next_knot(ur)= ul;

mp_close_path_cycle(mp,ul,ll);
mp_make_path(mp,ll);
mp->cur_exp.type= mp_path_type;
set_cur_exp_knot(ll);
mp_free_path(mp,qq);

}
}




/*:1040*//*1041:*/
#line 29301 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_set_up_glyph_infont(MP mp,mp_node p){
mp_edge_object*h= NULL;
mp_ps_font*f= NULL;
char*n= mp_str(mp,cur_exp_str());
f= mp_ps_font_parse(mp,(int)mp_find_font(mp,n));
if(f!=NULL){
if(mp_type(p)==mp_known){
int v= round_unscaled(value_number(p));
if(v<0||v> 255){
char msg[256];
mp_snprintf(msg,256,"glyph index too high (%d)",v);
mp_error(mp,msg,NULL,true);
}else{
h= mp_ps_font_charstring(mp,f,v);
}
}else{
n= mp_str(mp,value_str(p));
h= mp_ps_do_font_charstring(mp,f,n);
}
mp_ps_font_free(mp,f);
}
if(h!=NULL){
set_cur_exp_node((mp_node)mp_gr_import(mp,h));
}else{
set_cur_exp_node((mp_node)mp_get_edge_header_node(mp));
mp_init_edges(mp,(mp_edge_header_node)cur_exp_node());
}
mp->cur_exp.type= mp_picture_type;
}


/*:1041*//*1042:*/
#line 29333 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_find_point(MP mp,mp_number v_orig,quarterword c){
mp_knot p;
mp_number n;
mp_number v;
new_number(v);
new_number(n);
number_clone(v,v_orig);
p= cur_exp_knot();
if(mp_left_type(p)==mp_endpoint){
set_number_to_unity(n);
number_negate(n);
}else{
set_number_to_zero(n);
}
do{
p= mp_next_knot(p);
number_add(n,unity_t);
}while(p!=cur_exp_knot());
if(number_zero(n)){
set_number_to_zero(v);
}else if(number_negative(v)){
if(mp_left_type(p)==mp_endpoint){
set_number_to_zero(v);
}else{


number_negate(v);
number_add_scaled(v,-1);
number_modulo(v,n);
number_negate(v);
number_add_scaled(v,-1);
number_add(v,n);
}
}else if(number_greater(v,n)){
if(mp_left_type(p)==mp_endpoint)
number_clone(v,n);
else
number_modulo(v,n);
}
p= cur_exp_knot();
while(number_greaterequal(v,unity_t)){
p= mp_next_knot(p);
number_substract(v,unity_t);
}
if(number_nonzero(v)){

convert_scaled_to_fraction(v);
mp_split_cubic(mp,p,v);
p= mp_next_knot(p);
}

switch(c){
case mp_point_of:
mp_pair_value(mp,p->x_coord,p->y_coord);
break;
case mp_precontrol_of:
if(mp_left_type(p)==mp_endpoint)
mp_pair_value(mp,p->x_coord,p->y_coord);
else
mp_pair_value(mp,p->left_x,p->left_y);
break;
case mp_postcontrol_of:
if(mp_right_type(p)==mp_endpoint)
mp_pair_value(mp,p->x_coord,p->y_coord);
else
mp_pair_value(mp,p->right_x,p->right_y);
break;
}
free_number(v);
free_number(n);
}

/*:1042*//*1043:*/
#line 29409 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_infont(MP mp,mp_node p){
mp_edge_header_node q;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
q= mp_get_edge_header_node(mp);
mp_init_edges(mp,q);
add_str_ref(cur_exp_str());
mp_link(obj_tail(q))=
mp_new_text_node(mp,mp_str(mp,cur_exp_str()),value_str(p));
obj_tail(q)= mp_link(obj_tail(q));
mp_free_value_node(mp,p);
new_expr.data.node= (mp_node)q;
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_picture_type;
}


/*:1043*/
#line 27162 "../../../source/texk/web2c/mplibdir/mp.w"
;
static void mp_finish_binary(MP mp,mp_node old_p,mp_node old_exp){
check_arith();

if(old_p!=NULL){
mp_recycle_value(mp,old_p);
mp_free_value_node(mp,old_p);
}
if(old_exp!=NULL){
mp_recycle_value(mp,old_exp);
mp_free_value_node(mp,old_exp);
}
}
static void mp_do_binary(MP mp,mp_node p,integer c){
mp_node q,r,rr;
mp_node old_p,old_exp;
mp_value new_expr;
check_arith();
if(number_greater(internal_value(mp_tracing_commands),two_t)){

mp_begin_diagnostic(mp);
mp_print_nl(mp,"{(");
mp_print_exp(mp,p,0);
mp_print_char(mp,xord(')'));
mp_print_op(mp,(quarterword)c);
mp_print_char(mp,xord('('));
mp_print_exp(mp,NULL,0);
mp_print(mp,")}");
mp_end_diagnostic(mp,false);
}




switch(mp_type(p)){
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
old_p= mp_tarnished(mp,p);
break;
case mp_independent:
old_p= MP_VOID;
break;
default:
old_p= NULL;
break;
}
if(old_p!=NULL){
q= mp_stash_cur_exp(mp);
old_p= p;
mp_make_exp_copy(mp,old_p);
p= mp_stash_cur_exp(mp);
mp_unstash_cur_exp(mp,q);
}


switch(mp->cur_exp.type){
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
old_exp= mp_tarnished(mp,cur_exp_node());
break;
case mp_independent:
old_exp= MP_VOID;
break;
default:
old_exp= NULL;
break;
}
if(old_exp!=NULL){
old_exp= cur_exp_node();
mp_make_exp_copy(mp,old_exp);
}

switch(c){
case mp_plus:
case mp_minus:

if((mp->cur_exp.type<mp_color_type)||(mp_type(p)<mp_color_type)){
mp_bad_binary(mp,p,(quarterword)c);
}else{
quarterword cc= (quarterword)c;
if((mp->cur_exp.type> mp_pair_type)&&(mp_type(p)> mp_pair_type)){
mp_add_or_subtract(mp,p,NULL,cc);
}else{
if(mp->cur_exp.type!=mp_type(p)){
mp_bad_binary(mp,p,cc);
}else{
q= value_node(p);
r= value_node(cur_exp_node());
switch(mp->cur_exp.type){
case mp_pair_type:
mp_add_or_subtract(mp,x_part(q),x_part(r),cc);
mp_add_or_subtract(mp,y_part(q),y_part(r),cc);
break;
case mp_color_type:
mp_add_or_subtract(mp,red_part(q),red_part(r),cc);
mp_add_or_subtract(mp,green_part(q),green_part(r),cc);
mp_add_or_subtract(mp,blue_part(q),blue_part(r),cc);
break;
case mp_cmykcolor_type:
mp_add_or_subtract(mp,cyan_part(q),cyan_part(r),cc);
mp_add_or_subtract(mp,magenta_part(q),magenta_part(r),cc);
mp_add_or_subtract(mp,yellow_part(q),yellow_part(r),cc);
mp_add_or_subtract(mp,black_part(q),black_part(r),cc);
break;
case mp_transform_type:
mp_add_or_subtract(mp,tx_part(q),tx_part(r),cc);
mp_add_or_subtract(mp,ty_part(q),ty_part(r),cc);
mp_add_or_subtract(mp,xx_part(q),xx_part(r),cc);
mp_add_or_subtract(mp,xy_part(q),xy_part(r),cc);
mp_add_or_subtract(mp,yx_part(q),yx_part(r),cc);
mp_add_or_subtract(mp,yy_part(q),yy_part(r),cc);
break;
default:
break;
}
}
}
}
break;
case mp_less_than:
case mp_less_or_equal:
case mp_greater_than:
case mp_greater_or_equal:
case mp_equal_to:
case mp_unequal_to:
check_arith();
if((mp->cur_exp.type> mp_pair_type)&&(mp_type(p)> mp_pair_type)){
mp_add_or_subtract(mp,p,NULL,mp_minus);
}else if(mp->cur_exp.type!=mp_type(p)){
mp_bad_binary(mp,p,(quarterword)c);
goto DONE;
}else if(mp->cur_exp.type==mp_string_type){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_from_scaled(new_expr.data.n,mp_str_vs_str(mp,value_str(p),cur_exp_str()));
mp_flush_cur_exp(mp,new_expr);
}else if((mp->cur_exp.type==mp_unknown_string)||
(mp->cur_exp.type==mp_unknown_boolean)){




q= value_node(cur_exp_node());
while((q!=cur_exp_node())&&(q!=p))
q= value_node(q);
if(q==p){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_cur_exp_node(NULL);
mp_flush_cur_exp(mp,new_expr);
}

}else if((mp->cur_exp.type<=mp_pair_type)
&&(mp->cur_exp.type>=mp_transform_type)){



quarterword part_type;
q= value_node(p);
r= value_node(cur_exp_node());
part_type= 0;
switch(mp->cur_exp.type){
case mp_pair_type:
while(part_type==0){
rr= x_part(r);
part_type= mp_x_part;
mp_add_or_subtract(mp,x_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= y_part(r);
part_type= mp_y_part;
mp_add_or_subtract(mp,y_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
}
mp_take_part(mp,part_type);
break;
case mp_color_type:
while(part_type==0){
rr= red_part(r);
part_type= mp_red_part;
mp_add_or_subtract(mp,red_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= green_part(r);
part_type= mp_green_part;
mp_add_or_subtract(mp,green_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= blue_part(r);
part_type= mp_blue_part;
mp_add_or_subtract(mp,blue_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
}
mp_take_part(mp,part_type);
break;
case mp_cmykcolor_type:
while(part_type==0){
rr= cyan_part(r);
part_type= mp_cyan_part;
mp_add_or_subtract(mp,cyan_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= magenta_part(r);
part_type= mp_magenta_part;
mp_add_or_subtract(mp,magenta_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= yellow_part(r);
part_type= mp_yellow_part;
mp_add_or_subtract(mp,yellow_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= black_part(r);
part_type= mp_black_part;
mp_add_or_subtract(mp,black_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
}
mp_take_part(mp,part_type);
break;
case mp_transform_type:
while(part_type==0){
rr= tx_part(r);
part_type= mp_x_part;
mp_add_or_subtract(mp,tx_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= ty_part(r);
part_type= mp_y_part;
mp_add_or_subtract(mp,ty_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= xx_part(r);
part_type= mp_xx_part;
mp_add_or_subtract(mp,xx_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= xy_part(r);
part_type= mp_xy_part;
mp_add_or_subtract(mp,xy_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= yx_part(r);
part_type= mp_yx_part;
mp_add_or_subtract(mp,yx_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
rr= yy_part(r);
part_type= mp_yy_part;
mp_add_or_subtract(mp,yy_part(q),rr,mp_minus);
if(mp_type(rr)!=mp_known||!number_zero(value_number(rr)))
break;
}
mp_take_part(mp,part_type);
break;
default:
assert(0);
break;
}

}else if(mp->cur_exp.type==mp_boolean_type){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_from_boolean(new_expr.data.n,number_to_scaled(cur_exp_value_number())-
number_to_scaled(value_number(p)));
mp_flush_cur_exp(mp,new_expr);
}else{
mp_bad_binary(mp,p,(quarterword)c);
goto DONE;
}

if(mp->cur_exp.type!=mp_known){
const char*hlp[]= {
"Oh dear. I can\'t decide if the expression above is positive,",
"negative, or zero. So this comparison test won't be `true'.",
NULL};
if(mp->cur_exp.type<mp_known){
mp_disp_err(mp,p);
hlp[0]= "The quantities shown above have not been equated.";
hlp[1]= NULL;
}
mp_disp_err(mp,NULL);
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_from_boolean(new_expr.data.n,mp_false_code);
mp_back_error(mp,"Unknown relation will be considered false",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
switch(c){
case mp_less_than:
boolean_reset(number_negative(cur_exp_value_number()));
break;
case mp_less_or_equal:
boolean_reset(number_nonpositive(cur_exp_value_number()));
break;
case mp_greater_than:
boolean_reset(number_positive(cur_exp_value_number()));
break;
case mp_greater_or_equal:
boolean_reset(number_nonnegative(cur_exp_value_number()));
break;
case mp_equal_to:
boolean_reset(number_zero(cur_exp_value_number()));
break;
case mp_unequal_to:
boolean_reset(number_nonzero(cur_exp_value_number()));
break;
};
}
mp->cur_exp.type= mp_boolean_type;
DONE:
mp->arith_error= false;
break;
case mp_and_op:
case mp_or_op:

if((mp_type(p)!=mp_boolean_type)||(mp->cur_exp.type!=mp_boolean_type))
mp_bad_binary(mp,p,(quarterword)c);
else if(number_to_boolean(p->data.n)==c+mp_false_code-mp_and_op){
set_cur_exp_value_boolean(number_to_boolean(p->data.n));
}
break;
case mp_times:
if((mp->cur_exp.type<mp_color_type)||(mp_type(p)<mp_color_type)){
mp_bad_binary(mp,p,mp_times);
}else if((mp->cur_exp.type==mp_known)||(mp_type(p)==mp_known)){

mp_number vv;
new_fraction(vv);
if(mp_type(p)==mp_known){
number_clone(vv,value_number(p));
mp_free_value_node(mp,p);
}else{
number_clone(vv,cur_exp_value_number());
mp_unstash_cur_exp(mp,p);
}
if(mp->cur_exp.type==mp_known){
mp_number ret;
new_number(ret);
take_scaled(ret,cur_exp_value_number(),vv);
set_cur_exp_value_number(ret);
free_number(ret);
}else if(mp->cur_exp.type==mp_pair_type){
mp_dep_mult(mp,(mp_value_node)x_part(value_node(cur_exp_node())),vv,true);
mp_dep_mult(mp,(mp_value_node)y_part(value_node(cur_exp_node())),vv,true);
}else if(mp->cur_exp.type==mp_color_type){
mp_dep_mult(mp,(mp_value_node)red_part(value_node(cur_exp_node())),vv,true);
mp_dep_mult(mp,(mp_value_node)green_part(value_node(cur_exp_node())),vv,true);
mp_dep_mult(mp,(mp_value_node)blue_part(value_node(cur_exp_node())),vv,true);
}else if(mp->cur_exp.type==mp_cmykcolor_type){
mp_dep_mult(mp,(mp_value_node)cyan_part(value_node(cur_exp_node())),vv,true);
mp_dep_mult(mp,(mp_value_node)magenta_part(value_node(cur_exp_node())),vv,true);
mp_dep_mult(mp,(mp_value_node)yellow_part(value_node(cur_exp_node())),vv,true);
mp_dep_mult(mp,(mp_value_node)black_part(value_node(cur_exp_node())),vv,true);
}else{
mp_dep_mult(mp,NULL,vv,true);
}
free_number(vv);
binary_return;

}else if((mp_nice_color_or_pair(mp,p,mp_type(p))
&&(mp->cur_exp.type> mp_pair_type))
||(mp_nice_color_or_pair(mp,cur_exp_node(),mp->cur_exp.type)
&&(mp_type(p)> mp_pair_type))){
mp_hard_times(mp,p);
binary_return;
}else{
mp_bad_binary(mp,p,mp_times);
}
break;
case mp_over:
if((mp->cur_exp.type!=mp_known)||(mp_type(p)<mp_color_type)){
mp_bad_binary(mp,p,mp_over);
}else{
mp_number v_n;
new_number(v_n);
number_clone(v_n,cur_exp_value_number());
mp_unstash_cur_exp(mp,p);
if(number_zero(v_n)){

const char*hlp[]= {
"You're trying to divide the quantity shown above the error",
"message by zero. I'm going to divide it by one instead.",
NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Division by zero",hlp,true);
mp_get_x_next(mp);

}else{
if(mp->cur_exp.type==mp_known){
mp_number ret;
new_number(ret);
make_scaled(ret,cur_exp_value_number(),v_n);
set_cur_exp_value_number(ret);
free_number(ret);
}else if(mp->cur_exp.type==mp_pair_type){
mp_dep_div(mp,(mp_value_node)x_part(value_node(cur_exp_node())),
v_n);
mp_dep_div(mp,(mp_value_node)y_part(value_node(cur_exp_node())),
v_n);
}else if(mp->cur_exp.type==mp_color_type){
mp_dep_div(mp,
(mp_value_node)red_part(value_node(cur_exp_node())),
v_n);
mp_dep_div(mp,
(mp_value_node)green_part(value_node(cur_exp_node())),
v_n);
mp_dep_div(mp,
(mp_value_node)blue_part(value_node(cur_exp_node())),
v_n);
}else if(mp->cur_exp.type==mp_cmykcolor_type){
mp_dep_div(mp,
(mp_value_node)cyan_part(value_node(cur_exp_node())),
v_n);
mp_dep_div(mp,(mp_value_node)
magenta_part(value_node(cur_exp_node())),v_n);
mp_dep_div(mp,(mp_value_node)
yellow_part(value_node(cur_exp_node())),v_n);
mp_dep_div(mp,
(mp_value_node)black_part(value_node(cur_exp_node())),
v_n);
}else{
mp_dep_div(mp,NULL,v_n);
}
}
free_number(v_n);
binary_return;
}
break;
case mp_pythag_add:
case mp_pythag_sub:
if((mp->cur_exp.type==mp_known)&&(mp_type(p)==mp_known)){
mp_number r;
new_number(r);
if(c==mp_pythag_add){
pyth_add(r,value_number(p),cur_exp_value_number());
}else{
pyth_sub(r,value_number(p),cur_exp_value_number());
}
set_cur_exp_value_number(r);
free_number(r);
}else
mp_bad_binary(mp,p,(quarterword)c);
break;
case mp_rotated_by:
case mp_slanted_by:
case mp_scaled_by:
case mp_shifted_by:
case mp_transformed_by:
case mp_x_scaled:
case mp_y_scaled:
case mp_z_scaled:


if(mp_type(p)==mp_path_type){
path_trans((quarterword)c,p);
binary_return;
}else if(mp_type(p)==mp_pen_type){
pen_trans((quarterword)c,p);
set_cur_exp_knot(mp_convex_hull(mp,cur_exp_knot()));

binary_return;
}else if((mp_type(p)==mp_pair_type)||(mp_type(p)==mp_transform_type)){
mp_big_trans(mp,p,(quarterword)c);
}else if(mp_type(p)==mp_picture_type){
mp_do_edges_trans(mp,p,(quarterword)c);
binary_return;
}else{
mp_bad_binary(mp,p,(quarterword)c);
}
break;
case mp_concatenate:
if((mp->cur_exp.type==mp_string_type)&&(mp_type(p)==mp_string_type)){
mp_string str= mp_cat(mp,value_str(p),cur_exp_str());
delete_str_ref(cur_exp_str());
set_cur_exp_str(str);
}else
mp_bad_binary(mp,p,mp_concatenate);
break;
case mp_substring_of:
if(mp_nice_pair(mp,p,mp_type(p))&&(mp->cur_exp.type==mp_string_type)){
mp_string str= mp_chop_string(mp,
cur_exp_str(),
round_unscaled(value_number(x_part(value_node(p)))),
round_unscaled(value_number(y_part(value_node(p)))));
delete_str_ref(cur_exp_str());
set_cur_exp_str(str);
}else
mp_bad_binary(mp,p,mp_substring_of);
break;
case mp_subpath_of:
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if(mp_nice_pair(mp,p,mp_type(p))&&(mp->cur_exp.type==mp_path_type))
mp_chop_path(mp,value_node(p));
else
mp_bad_binary(mp,p,mp_subpath_of);
break;
case mp_point_of:
case mp_precontrol_of:
case mp_postcontrol_of:
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if((mp->cur_exp.type==mp_path_type)&&(mp_type(p)==mp_known))
mp_find_point(mp,value_number(p),(quarterword)c);
else
mp_bad_binary(mp,p,(quarterword)c);
break;
case mp_pen_offset_of:
if((mp->cur_exp.type==mp_pen_type)&&mp_nice_pair(mp,p,mp_type(p)))
mp_set_up_offset(mp,value_node(p));
else
mp_bad_binary(mp,p,mp_pen_offset_of);
break;
case mp_direction_time_of:
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if((mp->cur_exp.type==mp_path_type)&&mp_nice_pair(mp,p,mp_type(p)))
mp_set_up_direction_time(mp,value_node(p));
else
mp_bad_binary(mp,p,mp_direction_time_of);
break;
case mp_envelope_of:
if((mp_type(p)!=mp_pen_type)||(mp->cur_exp.type!=mp_path_type))
mp_bad_binary(mp,p,mp_envelope_of);
else
mp_set_up_envelope(mp,p);
break;
case mp_boundingpath_of:
if((mp_type(p)!=mp_pen_type)||(mp->cur_exp.type!=mp_path_type))
mp_bad_binary(mp,p,mp_boundingpath_of);
else
mp_set_up_boundingpath(mp,p);
break;
case mp_glyph_infont:
if((mp_type(p)!=mp_string_type&&
mp_type(p)!=mp_known)||(mp->cur_exp.type!=mp_string_type))
mp_bad_binary(mp,p,mp_glyph_infont);
else
mp_set_up_glyph_infont(mp,p);
break;
case mp_arc_time_of:
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if((mp->cur_exp.type==mp_path_type)&&(mp_type(p)==mp_known)){
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_arc_time(mp,&new_expr.data.n,cur_exp_knot(),value_number(p));
mp_flush_cur_exp(mp,new_expr);
}else{
mp_bad_binary(mp,p,(quarterword)c);
}
break;
case mp_intersect:
if(mp_type(p)==mp_pair_type){
q= mp_stash_cur_exp(mp);
mp_unstash_cur_exp(mp,p);
mp_pair_to_path(mp);
p= mp_stash_cur_exp(mp);
mp_unstash_cur_exp(mp,q);
}
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if((mp->cur_exp.type==mp_path_type)&&(mp_type(p)==mp_path_type)){
mp_number arg1,arg2;
new_number(arg1);
new_number(arg2);
mp_path_intersection(mp,value_knot(p),cur_exp_knot());
number_clone(arg1,mp->cur_t);
number_clone(arg2,mp->cur_tt);
mp_pair_value(mp,arg1,arg2);
free_number(arg1);
free_number(arg2);
}else{
mp_bad_binary(mp,p,mp_intersect);
}
break;
case mp_in_font:
if((mp->cur_exp.type!=mp_string_type)||mp_type(p)!=mp_string_type){
mp_bad_binary(mp,p,mp_in_font);
}else{
mp_do_infont(mp,p);
binary_return;
}
break;
}
mp_recycle_value(mp,p);
mp_free_value_node(mp,p);
mp_finish_binary(mp,old_p,old_exp);
}


/*:1000*//*1006:*/
#line 28083 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_frac_mult(MP mp,mp_number n,mp_number d){

mp_node old_exp;
mp_number v;
new_fraction(v);
if(number_greater(internal_value(mp_tracing_commands),two_t)){
/*1007:*/
#line 28143 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{(");
print_number(n);
mp_print_char(mp,xord('/'));
print_number(d);
mp_print(mp,")*(");
mp_print_exp(mp,NULL,0);
mp_print(mp,")}");
mp_end_diagnostic(mp,false);
}


/*:1007*/
#line 28090 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
switch(mp->cur_exp.type){
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
old_exp= mp_tarnished(mp,cur_exp_node());
break;
case mp_independent:
old_exp= MP_VOID;
break;
default:
old_exp= NULL;
break;
}
if(old_exp!=NULL){
old_exp= cur_exp_node();
mp_make_exp_copy(mp,old_exp);
}
make_fraction(v,n,d);
if(mp->cur_exp.type==mp_known){
mp_number r1,arg1;
new_fraction(r1);
new_number(arg1);
number_clone(arg1,cur_exp_value_number());
take_fraction(r1,arg1,v);
set_cur_exp_value_number(r1);
free_number(r1);
free_number(arg1);
}else if(mp->cur_exp.type==mp_pair_type){
mp_dep_mult(mp,(mp_value_node)x_part(value_node(cur_exp_node())),v,false);
mp_dep_mult(mp,(mp_value_node)y_part(value_node(cur_exp_node())),v,false);
}else if(mp->cur_exp.type==mp_color_type){
mp_dep_mult(mp,(mp_value_node)red_part(value_node(cur_exp_node())),v,false);
mp_dep_mult(mp,(mp_value_node)green_part(value_node(cur_exp_node())),v,false);
mp_dep_mult(mp,(mp_value_node)blue_part(value_node(cur_exp_node())),v,false);
}else if(mp->cur_exp.type==mp_cmykcolor_type){
mp_dep_mult(mp,(mp_value_node)cyan_part(value_node(cur_exp_node())),v,false);
mp_dep_mult(mp,(mp_value_node)magenta_part(value_node(cur_exp_node())),v,false);
mp_dep_mult(mp,(mp_value_node)yellow_part(value_node(cur_exp_node())),v,false);
mp_dep_mult(mp,(mp_value_node)black_part(value_node(cur_exp_node())),v,false);
}else{
mp_dep_mult(mp,NULL,v,false);
}
if(old_exp!=NULL){
mp_recycle_value(mp,old_exp);
mp_free_value_node(mp,old_exp);
}
free_number(v);
}


/*:1006*//*1044:*/
#line 29452 "../../../source/texk/web2c/mplibdir/mp.w"

static void worry_about_bad_statement(MP mp);
static void flush_unparsable_junk_after_statement(MP mp);
void mp_do_statement(MP mp){
mp->cur_exp.type= mp_vacuous;
mp_get_x_next(mp);
if(cur_cmd()> mp_max_primary_command){
worry_about_bad_statement(mp);
}else if(cur_cmd()> mp_max_statement_command){



mp_value new_expr;
mp->var_flag= mp_assignment;
mp_scan_expression(mp);
if(cur_cmd()<mp_end_group){
if(cur_cmd()==mp_equals)
mp_do_equation(mp);
else if(cur_cmd()==mp_assignment)
mp_do_assignment(mp);
else if(mp->cur_exp.type==mp_string_type){

if(number_positive(internal_value(mp_tracing_titles))){
mp_print_nl(mp,"");
mp_print_str(mp,cur_exp_str());
update_terminal();
}
}else if(mp->cur_exp.type!=mp_vacuous){
const char*hlp[]= {
"I couldn't find an `=' or `:=' after the",
"expression that is shown above this error message,",
"so I guess I'll just ignore it and carry on.",
NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Isolated expression",hlp,true);
mp_get_x_next(mp);
}
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_vacuous;
}
}else{





if(number_positive(internal_value(mp_tracing_commands)))
show_cur_cmd_mod;
switch(cur_cmd()){
case mp_type_name:
mp_do_type_declaration(mp);
break;
case mp_macro_def:
if(cur_mod()> var_def)
mp_make_op_def(mp);
else if(cur_mod()> end_def)
mp_scan_def(mp);
break;
case mp_random_seed:
mp_do_random_seed(mp);
break;
case mp_mode_command:
mp_print_ln(mp);
mp->interaction= cur_mod();
initialize_print_selector();
if(mp->log_opened)
mp->selector= mp->selector+2;
mp_get_x_next(mp);
break;
case mp_protection_command:
mp_do_protection(mp);
break;
case mp_delimiters:
mp_def_delims(mp);
break;
case mp_save_command:
do{
mp_get_symbol(mp);
mp_save_variable(mp,cur_sym());
mp_get_x_next(mp);
}while(cur_cmd()==mp_comma);
break;
case mp_interim_command:
mp_do_interim(mp);
break;
case mp_let_command:
mp_do_let(mp);
break;
case mp_new_internal:
mp_do_new_internal(mp);
break;
case mp_show_command:
mp_do_show_whatever(mp);
break;
case mp_add_to_command:
mp_do_add_to(mp);
break;
case mp_bounds_command:
mp_do_bounds(mp);
break;
case mp_ship_out_command:
mp_do_ship_out(mp);
break;
case mp_every_job_command:
mp_get_symbol(mp);
mp->start_sym= cur_sym();
mp_get_x_next(mp);
break;
case mp_message_command:
mp_do_message(mp);
break;
case mp_write_command:
mp_do_write(mp);
break;
case mp_tfm_command:
mp_do_tfm_command(mp);
break;
case mp_special_command:
if(cur_mod()==0)
mp_do_special(mp);
else if(cur_mod()==1)
mp_do_mapfile(mp);
else
mp_do_mapline(mp);
break;
default:
break;
}
mp->cur_exp.type= mp_vacuous;
}
if(cur_cmd()<mp_semicolon)
flush_unparsable_junk_after_statement(mp);
mp->error_count= 0;
}


/*:1044*//*1046:*/
#line 29599 "../../../source/texk/web2c/mplibdir/mp.w"

static void worry_about_bad_statement(MP mp){
if(cur_cmd()<mp_semicolon){
char msg[256];
mp_string sname;
int old_setting= mp->selector;
const char*hlp[]= {
"I was looking for the beginning of a new statement.",
"If you just proceed without changing anything, I'll ignore",
"everything up to the next `;'. Please insert a semicolon",
"now in front of anything that you don't want me to delete.",
"(See Chapter 27 of The METAFONTbook for an example.)",
NULL};
mp->selector= new_string;
mp_print_cmd_mod(mp,cur_cmd(),cur_mod());
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"A statement can't begin with `%s'",mp_str(mp,sname));
delete_str_ref(sname);
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
}


/*:1046*//*1047:*/
#line 29628 "../../../source/texk/web2c/mplibdir/mp.w"

static void flush_unparsable_junk_after_statement(MP mp)
{
const char*hlp[]= {
"I've just read as much of that statement as I could fathom,",
"so a semicolon should have been next. It's very puzzling...",
"but I'll try to get myself back together, by ignoring",
"everything up to the next `;'. Please insert a semicolon",
"now in front of anything that you don't want me to delete.",
"(See Chapter 27 of The METAFONTbook for an example.)",
NULL};
mp_back_error(mp,"Extra tokens will be flushed",hlp,true);
mp->scanner_status= flushing;
do{
get_t_next(mp);
if(cur_cmd()==mp_string_token){
delete_str_ref(cur_mod_str());
}
}while(!mp_end_of_statement);
mp->scanner_status= normal;
}



/*:1047*//*1049:*/
#line 29665 "../../../source/texk/web2c/mplibdir/mp.w"

static void trace_equation(MP mp,mp_node lhs){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{(");
mp_print_exp(mp,lhs,0);
mp_print(mp,")=(");
mp_print_exp(mp,NULL,0);
mp_print(mp,")}");
mp_end_diagnostic(mp,false);
}
void mp_do_equation(MP mp){
mp_node lhs;
lhs= mp_stash_cur_exp(mp);
mp_get_x_next(mp);
mp->var_flag= mp_assignment;
mp_scan_expression(mp);
if(cur_cmd()==mp_equals)
mp_do_equation(mp);
else if(cur_cmd()==mp_assignment)
mp_do_assignment(mp);
if(number_greater(internal_value(mp_tracing_commands),two_t)){
trace_equation(mp,lhs);
}
if(mp->cur_exp.type==mp_unknown_path){
if(mp_type(lhs)==mp_pair_type){
mp_node p;
p= mp_stash_cur_exp(mp);
mp_unstash_cur_exp(mp,lhs);
lhs= p;
}
}
mp_make_eq(mp,lhs);
}


/*:1049*//*1051:*/
#line 29705 "../../../source/texk/web2c/mplibdir/mp.w"

static void bad_lhs(MP mp){
const char*hlp[]= {
"I didn't find a variable name at the left of the `:=',",
"so I'm going to pretend that you said `=' instead.",
NULL};
mp_disp_err(mp,NULL);
mp_error(mp,"Improper `:=' will be changed to `='",hlp,true);
mp_do_equation(mp);
}
static void bad_internal_assignment(MP mp,mp_node lhs){
char msg[256];
const char*hlp[]= {
"I can\'t set this internal quantity to anything but a known",
"numeric value, so I'll have to ignore this assignment.",
NULL};
mp_disp_err(mp,NULL);
if(internal_type(mp_sym_info(lhs))==mp_known){
mp_snprintf(msg,256,"Internal quantity `%s' must receive a known numeric value",
internal_name(mp_sym_info(lhs)));
}else{
mp_snprintf(msg,256,"Internal quantity `%s' must receive a known string",
internal_name(mp_sym_info(lhs)));
hlp[1]= "string, so I'll have to ignore this assignment.";
}
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
static void forbidden_internal_assignment(MP mp,mp_node lhs){
char msg[256];
const char*hlp[]= {
"I can\'t set this internal quantity to anything just yet",
"(it is read-only), so I'll have to ignore this assignment.",
NULL};
mp_snprintf(msg,256,"Internal quantity `%s' is read-only",
internal_name(mp_sym_info(lhs)));
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
static void bad_internal_assignment_precision(MP mp,mp_node lhs,mp_number min,mp_number max){
char msg[256];
char s[256];
const char*hlp[]= {
"Precision values are limited by the current numbersystem.",
NULL,
NULL};
mp_snprintf(msg,256,"Bad '%s' has been ignored",internal_name(mp_sym_info(lhs)));
mp_snprintf(s,256,"Currently I am using '%s'; the allowed precision range is [%s,%s].",
mp_str(mp,internal_string(mp_number_system)),number_tostring(min),number_tostring(max));
hlp[1]= s;
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
static void bad_expression_assignment(MP mp,mp_node lhs){
const char*hlp[]= {
"It seems you did a nasty thing---probably by accident,",
"but nevertheless you nearly hornswoggled me...",
"While I was evaluating the right-hand side of this",
"command, something happened, and the left-hand side",
"is no longer a variable! So I won't change anything.",
NULL};
char*msg= mp_obliterated(mp,lhs);
mp_back_error(mp,msg,hlp,true);
free(msg);
mp_get_x_next(mp);
}
static void trace_assignment(MP mp,mp_node lhs){
mp_begin_diagnostic(mp);
mp_print_nl(mp,"{");
if(mp_name_type(lhs)==mp_internal_sym)
mp_print(mp,internal_name(mp_sym_info(lhs)));
else
mp_show_token_list(mp,lhs,NULL,1000,0);
mp_print(mp,":=");
mp_print_exp(mp,NULL,0);
mp_print_char(mp,xord('}'));
mp_end_diagnostic(mp,false);
}
void mp_do_assignment(MP mp){
if(mp->cur_exp.type!=mp_token_list){
bad_lhs(mp);
}else{
mp_node lhs;
lhs= cur_exp_node();
mp->cur_exp.type= mp_vacuous;
mp_get_x_next(mp);
mp->var_flag= mp_assignment;
mp_scan_expression(mp);
if(cur_cmd()==mp_equals)
mp_do_equation(mp);
else if(cur_cmd()==mp_assignment)
mp_do_assignment(mp);
if(number_greater(internal_value(mp_tracing_commands),two_t)){
trace_assignment(mp,lhs);
}
if(mp_name_type(lhs)==mp_internal_sym){

if((mp->cur_exp.type==mp_known||mp->cur_exp.type==mp_string_type)
&&(internal_type(mp_sym_info(lhs))==mp->cur_exp.type)){
if(mp_sym_info(lhs)==mp_number_system){
forbidden_internal_assignment(mp,lhs);
}else if(mp_sym_info(lhs)==mp_number_precision){
if(!(mp->cur_exp.type==mp_known&&
(!number_less(cur_exp_value_number(),precision_min))&&
(!number_greater(cur_exp_value_number(),precision_max))
)){
bad_internal_assignment_precision(mp,lhs,precision_min,precision_max);
}else{
set_internal_from_cur_exp(mp_sym_info(lhs));
set_precision();
}
}else{
set_internal_from_cur_exp(mp_sym_info(lhs));
}
}else{
bad_internal_assignment(mp,lhs);
}
}else{

mp_node p;
mp_node q;
p= mp_find_variable(mp,lhs);
if(p!=NULL){
q= mp_stash_cur_exp(mp);
mp->cur_exp.type= mp_und_type(mp,p);
mp_recycle_value(mp,p);
mp_type(p)= mp->cur_exp.type;
set_value_number(p,zero_t);
mp_make_exp_copy(mp,p);
p= mp_stash_cur_exp(mp);
mp_unstash_cur_exp(mp,q);
mp_make_eq(mp,p);
}else{
bad_expression_assignment(mp,lhs);
}
}
mp_flush_node_list(mp,lhs);
}
}


/*:1051*//*1053:*/
#line 29853 "../../../source/texk/web2c/mplibdir/mp.w"

static void announce_bad_equation(MP mp,mp_node lhs){
char msg[256];
const char*hlp[]= {
"I'm sorry, but I don't know how to make such things equal.",
"(See the two expressions just above the error message.)",
NULL};
mp_snprintf(msg,256,"Equation cannot be performed (%s=%s)",
(mp_type(lhs)<=mp_pair_type?mp_type_string(mp_type(lhs)):"numeric"),
(mp->cur_exp.type<=mp_pair_type?mp_type_string(mp->cur_exp.type):"numeric"));
mp_disp_err(mp,lhs);
mp_disp_err(mp,NULL);
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}
static void exclaim_inconsistent_equation(MP mp){
const char*hlp[]= {
"The equation I just read contradicts what was said before.",
"But don't worry; continue and I'll just ignore it.",
NULL};
mp_back_error(mp,"Inconsistent equation",hlp,true);
mp_get_x_next(mp);
}
static void exclaim_redundant_or_inconsistent_equation(MP mp){
const char*hlp[]= {
"An equation between already-known quantities can't help.",
"But don't worry; continue and I'll just ignore it.",
NULL};
mp_back_error(mp,"Redundant or inconsistent equation",hlp,true);
mp_get_x_next(mp);
}
static void report_redundant_or_inconsistent_equation(MP mp,mp_node lhs,mp_number v){
if(mp->cur_exp.type<=mp_string_type){
if(mp->cur_exp.type==mp_string_type){
if(mp_str_vs_str(mp,value_str(lhs),cur_exp_str())!=0){
exclaim_inconsistent_equation(mp);
}else{
exclaim_redundant_equation(mp);
}
}else if(!number_equal(v,cur_exp_value_number())){
exclaim_inconsistent_equation(mp);
}else{
exclaim_redundant_equation(mp);
}
}else{
exclaim_redundant_or_inconsistent_equation(mp);
}
}

void mp_make_eq(MP mp,mp_node lhs){
mp_value new_expr;
mp_variable_type t;
mp_number v;
memset(&new_expr,0,sizeof(mp_value));
new_number(v);
RESTART:
t= mp_type(lhs);
if(t<=mp_pair_type)
number_clone(v,value_number(lhs));


switch(t){
case mp_boolean_type:
case mp_string_type:
case mp_pen_type:
case mp_path_type:
case mp_picture_type:
if(mp->cur_exp.type==t+unknown_tag){
new_number(new_expr.data.n);
if(t==mp_boolean_type){
number_clone(new_expr.data.n,v);
}else if(t==mp_string_type){
new_expr.data.str= value_str(lhs);
}else if(t==mp_picture_type){
new_expr.data.node= value_node(lhs);
}else{
new_expr.data.p= value_knot(lhs);
}
mp_nonlinear_eq(mp,new_expr,cur_exp_node(),false);
mp_unstash_cur_exp(mp,cur_exp_node());
}else if(mp->cur_exp.type==t){
report_redundant_or_inconsistent_equation(mp,lhs,v);
}else{
announce_bad_equation(mp,lhs);
}
break;
case unknown_types:
if(mp->cur_exp.type==t-unknown_tag){
mp_nonlinear_eq(mp,mp->cur_exp,lhs,true);
}else if(mp->cur_exp.type==t){
mp_ring_merge(mp,lhs,cur_exp_node());
}else if(mp->cur_exp.type==mp_pair_type){
if(t==mp_unknown_path){
mp_pair_to_path(mp);
goto RESTART;
}
}else{
announce_bad_equation(mp,lhs);
}
break;
case mp_transform_type:
case mp_color_type:
case mp_cmykcolor_type:
case mp_pair_type:
if(mp->cur_exp.type==t){

mp_node q= value_node(cur_exp_node());
mp_node p= value_node(lhs);
switch(t){
case mp_transform_type:
mp_try_eq(mp,yy_part(p),yy_part(q));
mp_try_eq(mp,yx_part(p),yx_part(q));
mp_try_eq(mp,xy_part(p),xy_part(q));
mp_try_eq(mp,xx_part(p),xx_part(q));
mp_try_eq(mp,ty_part(p),ty_part(q));
mp_try_eq(mp,tx_part(p),tx_part(q));
break;
case mp_color_type:
mp_try_eq(mp,blue_part(p),blue_part(q));
mp_try_eq(mp,green_part(p),green_part(q));
mp_try_eq(mp,red_part(p),red_part(q));
break;
case mp_cmykcolor_type:
mp_try_eq(mp,black_part(p),black_part(q));
mp_try_eq(mp,yellow_part(p),yellow_part(q));
mp_try_eq(mp,magenta_part(p),magenta_part(q));
mp_try_eq(mp,cyan_part(p),cyan_part(q));
break;
case mp_pair_type:
mp_try_eq(mp,y_part(p),y_part(q));
mp_try_eq(mp,x_part(p),x_part(q));
break;
default:
break;
}
}else{
announce_bad_equation(mp,lhs);
}
break;
case mp_known:
case mp_dependent:
case mp_proto_dependent:
case mp_independent:
if(mp->cur_exp.type>=mp_known){
mp_try_eq(mp,lhs,NULL);
}else{
announce_bad_equation(mp,lhs);
}
break;
case mp_vacuous:
announce_bad_equation(mp,lhs);
break;
default:
announce_bad_equation(mp,lhs);
break;
}
check_arith();
mp_recycle_value(mp,lhs);
free_number(v);
mp_free_value_node(mp,lhs);
}

/*:1053*//*1055:*/
#line 30028 "../../../source/texk/web2c/mplibdir/mp.w"

static void deal_with_redundant_or_inconsistent_equation(MP mp,mp_value_node p,mp_node r){
mp_number absp;
new_number(absp);
number_clone(absp,value_number(p));
number_abs(absp);
if(number_greater(absp,equation_threshold_k)){
char msg[256];
const char*hlp[]= {
"The equation I just read contradicts what was said before.",
"But don't worry; continue and I'll just ignore it.",
NULL};
mp_snprintf(msg,256,"Inconsistent equation (off by %s)",number_tostring(value_number(p)));
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}else if(r==NULL){
exclaim_redundant_equation(mp);
}
free_number(absp);
mp_free_dep_node(mp,p);
}

void mp_try_eq(MP mp,mp_node l,mp_node r){
mp_value_node p;
mp_variable_type t;
mp_value_node q;
mp_value_node pp;
mp_variable_type tt;
boolean copied;


t= mp_type(l);
if(t==mp_known){
mp_number arg1;
new_number(arg1);
number_clone(arg1,value_number(l));
number_negate(arg1);
t= mp_dependent;
p= mp_const_dependency(mp,arg1);
q= p;
free_number(arg1);
}else if(t==mp_independent){
t= mp_dependent;
p= mp_single_dependency(mp,l);
number_negate(dep_value(p));
q= mp->dep_final;
}else{
mp_value_node ll= (mp_value_node)l;
p= (mp_value_node)dep_list(ll);
q= p;
while(1){
number_negate(dep_value(q));
if(dep_info(q)==NULL)
break;
q= (mp_value_node)mp_link(q);
}
mp_link(prev_dep(ll))= mp_link(q);
set_prev_dep((mp_value_node)mp_link(q),prev_dep(ll));
mp_type(ll)= mp_known;
}


if(r==NULL){
if(mp->cur_exp.type==mp_known){
number_add(value_number(q),cur_exp_value_number());
goto DONE1;
}else{
tt= mp->cur_exp.type;
if(tt==mp_independent)
pp= mp_single_dependency(mp,cur_exp_node());
else
pp= (mp_value_node)dep_list((mp_value_node)cur_exp_node());
}
}else{
if(mp_type(r)==mp_known){
number_add(dep_value(q),value_number(r));
goto DONE1;
}else{
tt= mp_type(r);
if(tt==mp_independent)
pp= mp_single_dependency(mp,r);
else
pp= (mp_value_node)dep_list((mp_value_node)r);
}
}
if(tt!=mp_independent){
copied= false;
}else{
copied= true;
tt= mp_dependent;
}

mp->watch_coefs= false;
if(t==tt){
p= mp_p_plus_q(mp,p,pp,(quarterword)t);
}else if(t==mp_proto_dependent){
p= mp_p_plus_fq(mp,p,unity_t,pp,mp_proto_dependent,mp_dependent);
}else{
mp_number x;
new_number(x);
q= p;
while(dep_info(q)!=NULL){
number_clone(x,dep_value(q));
fraction_to_round_scaled(x);
set_dep_value(q,x);
q= (mp_value_node)mp_link(q);
}
free_number(x);
t= mp_proto_dependent;
p= mp_p_plus_q(mp,p,pp,(quarterword)t);
}
mp->watch_coefs= true;

if(copied)
mp_flush_node_list(mp,(mp_node)pp);
DONE1:

if(dep_info(p)==NULL){
deal_with_redundant_or_inconsistent_equation(mp,p,r);
}else{
mp_linear_eq(mp,p,(quarterword)t);
if(r==NULL&&mp->cur_exp.type!=mp_known){
if(mp_type(cur_exp_node())==mp_known){
mp_node pp= cur_exp_node();
set_cur_exp_value_number(value_number(pp));
mp->cur_exp.type= mp_known;
mp_free_value_node(mp,pp);
}
}
}
}

/*:1055*//*1057:*/
#line 30170 "../../../source/texk/web2c/mplibdir/mp.w"

mp_node mp_scan_declared_variable(MP mp){
mp_sym x;
mp_node h,t;
mp_get_symbol(mp);
x= cur_sym();
if(cur_cmd()!=mp_tag_token)
mp_clear_symbol(mp,x,false);
h= mp_get_symbolic_node(mp);
set_mp_sym_sym(h,x);
t= h;
while(1){
mp_get_x_next(mp);
if(cur_sym()==NULL)
break;
if(cur_cmd()!=mp_tag_token){
if(cur_cmd()!=mp_internal_quantity){
if(cur_cmd()==mp_left_bracket){



mp_sym ll= cur_sym();
mp_get_x_next(mp);
if(cur_cmd()==mp_right_bracket){
set_cur_sym(collective_subscript);
}else{
mp_back_input(mp);
set_cur_sym(ll);
set_cur_cmd((mp_variable_type)mp_left_bracket);
break;
}
}else{
break;
}
}
}
mp_link(t)= mp_get_symbolic_node(mp);
t= mp_link(t);
set_mp_sym_sym(t,cur_sym());
mp_name_type(t)= cur_sym_mod();
}
if((eq_type(x)%mp_outer_tag)!=mp_tag_token)
mp_clear_symbol(mp,x,false);
if(equiv_node(x)==NULL)
mp_new_root(mp,x);
return h;
}


/*:1057*//*1061:*/
#line 30257 "../../../source/texk/web2c/mplibdir/mp.w"

static void flush_spurious_symbols_after_declared_variable(MP mp);
void mp_do_type_declaration(MP mp){
integer t;
mp_node p;
mp_node q;
if(cur_mod()>=mp_transform_type)
t= (quarterword)cur_mod();
else
t= (quarterword)(cur_mod()+unknown_tag);
do{
p= mp_scan_declared_variable(mp);
mp_flush_variable(mp,equiv_node(mp_sym_sym(p)),mp_link(p),false);
q= mp_find_variable(mp,p);
if(q!=NULL){
mp_type(q)= t;
set_value_number(q,zero_t);
}else{
const char*hlp[]= {
"You can't use, e.g., `numeric foo[]' after `vardef foo'.",
"Proceed, and I'll ignore the illegal redeclaration.",
NULL};
mp_back_error(mp,"Declared variable conflicts with previous vardef",hlp,true);
mp_get_x_next(mp);
}
mp_flush_node_list(mp,p);
if(cur_cmd()<mp_comma){
flush_spurious_symbols_after_declared_variable(mp);
}
}while(!mp_end_of_statement);
}


/*:1061*//*1062:*/
#line 30291 "../../../source/texk/web2c/mplibdir/mp.w"

static void flush_spurious_symbols_after_declared_variable(MP mp)
{
const char*hlp[]= {
"Variables in declarations must consist entirely of",
"names and collective subscripts, e.g., `x[]a'.",
"Are you trying to use a reserved word in a variable name?",
"I'm going to discard the junk I found here,",
"up to the next comma or the end of the declaration.",
NULL};
if(cur_cmd()==mp_numeric_token)
hlp[2]= "Explicit subscripts like `x15a' aren't permitted.";
mp_back_error(mp,"Illegal suffix of declared variable will be flushed",hlp,true);
mp_get_x_next(mp);
mp->scanner_status= flushing;
do{
get_t_next(mp);
/*824:*/
#line 20843 "../../../source/texk/web2c/mplibdir/mp.w"

if(cur_cmd()==mp_string_token){
delete_str_ref(cur_mod_str());
}

/*:824*/
#line 30308 "../../../source/texk/web2c/mplibdir/mp.w"
;
}while(cur_cmd()<mp_comma);
mp->scanner_status= normal;
}


/*:1062*//*1063:*/
#line 30319 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_main_control(MP mp){
do{
mp_do_statement(mp);
if(cur_cmd()==mp_end_group){
mp_value new_expr;
const char*hlp[]= {
"I'm not currently working on a `begingroup',",
"so I had better not try to end anything.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_error(mp,"Extra `endgroup'",hlp,true);
mp_flush_cur_exp(mp,new_expr);
}
}while(cur_cmd()!=mp_stop);
}
int mp_run(MP mp){
if(mp->history<mp_fatal_error_stop){
xfree(mp->jump_buf);
mp->jump_buf= malloc(sizeof(jmp_buf));
if(mp->jump_buf==NULL||setjmp(*(mp->jump_buf))!=0)
return mp->history;
mp_main_control(mp);
mp_final_cleanup(mp);
mp_close_files_and_terminate(mp);
}
return mp->history;
}


/*:1063*//*1064:*/
#line 30356 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_set_internal(MP mp,char*n,char*v,int isstring){
size_t l= strlen(n);
char err[256];
const char*errid= NULL;
if(l> 0){
mp_sym p= mp_id_lookup(mp,n,l,false);
if(p==NULL){
errid= "variable does not exist";
}else{
if(eq_type(p)==mp_internal_quantity){
if((internal_type(equiv(p))==mp_string_type)&&(isstring)){
set_internal_string(equiv(p),mp_rts(mp,v));
}else if((internal_type(equiv(p))==mp_known)&&(!isstring)){
int test= atoi(v);
if(test> 16383&&mp->math_mode==mp_math_scaled_mode){
errid= "value is too large";
}else if(test<-16383&&mp->math_mode==mp_math_scaled_mode){
errid= "value is too small";
}else{
set_internal_from_number(equiv(p),unity_t);
number_multiply_int(internal_value(equiv(p)),test);
}
}else{
errid= "value has the wrong type";
}
}else{
errid= "variable is not an internal";
}
}
}
if(errid!=NULL){
if(isstring){
mp_snprintf(err,256,"%s=\"%s\": %s, assignment ignored.",n,v,errid);
}else{
mp_snprintf(err,256,"%s=%d: %s, assignment ignored.",n,atoi(v),
errid);
}
mp_warn(mp,err);
}
}


/*:1064*//*1067:*/
#line 30446 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_reset_stream(mp_stream*str){
xfree(str->data);
str->cur= NULL;
str->size= 0;
str->used= 0;
}
static void mp_free_stream(mp_stream*str){
xfree(str->fptr);
mp_reset_stream(str);
}


/*:1067*//*1072:*/
#line 30505 "../../../source/texk/web2c/mplibdir/mp.w"

static void*mplib_open_file(MP mp,const char*fname,const char*fmode,
int ftype){
File*ff= xmalloc(1,sizeof(File));
mp_run_data*run= mp_rundata(mp);
ff->f= NULL;
if(ftype==mp_filetype_terminal){
if(fmode[0]=='r'){
if(!ff->f){
ff->f= xmalloc(1,1);
run->term_in.fptr= ff->f;
}
}else{
reset_stream(run->term_out);
}
}else if(ftype==mp_filetype_error){
reset_stream(run->error_out);
}else if(ftype==mp_filetype_log){
reset_stream(run->log_out);
}else if(ftype==mp_filetype_postscript){
mp_free_stream(&(run->ship_out));
ff->f= xmalloc(1,1);
run->ship_out.fptr= ff->f;
}else if(ftype==mp_filetype_bitmap){
mp_free_stream(&(run->ship_out));
ff->f= xmalloc(1,1);
run->ship_out.fptr= ff->f;
}else{
char realmode[3];
char*f= (mp->find_file)(mp,fname,fmode,ftype);
if(f==NULL)
return NULL;
realmode[0]= *fmode;
realmode[1]= 'b';
realmode[2]= 0;
ff->f= fopen(f,realmode);
free(f);
if((fmode[0]=='r')&&(ff->f==NULL)){
free(ff);
return NULL;
}
}
return ff;
}
static int mplib_get_char(void*f,mp_run_data*run){
int c;
if(f==run->term_in.fptr&&run->term_in.data!=NULL){
if(run->term_in.size==0){
if(run->term_in.cur!=NULL){
run->term_in.cur= NULL;
}else{
xfree(run->term_in.data);
}
c= EOF;
}else{
run->term_in.size--;
c= *(run->term_in.cur)++;
}
}else{
c= fgetc(f);
}
return c;
}
static void mplib_unget_char(void*f,mp_run_data*run,int c){
if(f==run->term_in.fptr&&run->term_in.cur!=NULL){
run->term_in.size++;
run->term_in.cur--;
}else{
ungetc(c,f);
}
}
static char*mplib_read_ascii_file(MP mp,void*ff,size_t*size){
char*s= NULL;
if(ff!=NULL){
int c;
size_t len= 0,lim= 128;
mp_run_data*run= mp_rundata(mp);
FILE*f= ((File*)ff)->f;
if(f==NULL)
return NULL;
*size= 0;
c= mplib_get_char(f,run);
if(c==EOF)
return NULL;
s= malloc(lim);
if(s==NULL)
return NULL;
while(c!=EOF&&c!='\n'&&c!='\r'){
if(len>=(lim-1)){
s= xrealloc(s,(lim+(lim>>2)),1);
if(s==NULL)
return NULL;
lim+= (lim>>2);
}
s[len++]= (char)c;
c= mplib_get_char(f,run);
}
if(c=='\r'){
c= mplib_get_char(f,run);
if(c!=EOF&&c!='\n')
mplib_unget_char(f,run,c);
}
s[len]= 0;
*size= len;
}
return s;
}
static void mp_append_string(MP mp,mp_stream*a,const char*b){
size_t l= strlen(b)+1;
if((a->used+l)>=a->size){
a->size+= 256+(a->size)/5+l;
a->data= xrealloc(a->data,a->size,1);
}
memcpy(a->data+a->used,b,l);
a->used+= (l-1);
}
static void mp_append_data(MP mp,mp_stream*a,void*b,size_t l){
if((a->used+l)>=a->size){
a->size+= 256+(a->size)/5+l;
a->data= xrealloc(a->data,a->size,1);
}
memcpy(a->data+a->used,b,l);
a->used+= l;
}
static void mplib_write_ascii_file(MP mp,void*ff,const char*s){
if(ff!=NULL){
void*f= ((File*)ff)->f;
mp_run_data*run= mp_rundata(mp);
if(f!=NULL){
if(f==run->term_out.fptr){
mp_append_string(mp,&(run->term_out),s);
}else if(f==run->error_out.fptr){
mp_append_string(mp,&(run->error_out),s);
}else if(f==run->log_out.fptr){
mp_append_string(mp,&(run->log_out),s);
}else if(f==run->ship_out.fptr){
mp_append_string(mp,&(run->ship_out),s);
}else{
fprintf((FILE*)f,"%s",s);
}
}
}
}
static void mplib_read_binary_file(MP mp,void*ff,void**data,size_t*size){
(void)mp;
if(ff!=NULL){
size_t len= 0;
FILE*f= ((File*)ff)->f;
if(f!=NULL)
len= fread(*data,1,*size,f);
*size= len;
}
}
static void mplib_write_binary_file(MP mp,void*ff,void*s,size_t size){
(void)mp;
if(ff!=NULL){
void*f= ((File*)ff)->f;
mp_run_data*run= mp_rundata(mp);
if(f!=NULL){
if(f==run->ship_out.fptr){
mp_append_data(mp,&(run->ship_out),s,size);
}else{
(void)fwrite(s,size,1,f);
}
}
}
}
static void mplib_close_file(MP mp,void*ff){
if(ff!=NULL){
mp_run_data*run= mp_rundata(mp);
void*f= ((File*)ff)->f;
if(f!=NULL){
if(f!=run->term_out.fptr
&&f!=run->error_out.fptr
&&f!=run->log_out.fptr
&&f!=run->ship_out.fptr&&f!=run->term_in.fptr){
fclose(f);
}
}
free(ff);
}
}
static int mplib_eof_file(MP mp,void*ff){
if(ff!=NULL){
mp_run_data*run= mp_rundata(mp);
FILE*f= ((File*)ff)->f;
if(f==NULL)
return 1;
if(f==run->term_in.fptr&&run->term_in.data!=NULL){
return(run->term_in.size==0);
}
return feof(f);
}
return 1;
}
static void mplib_flush_file(MP mp,void*ff){
(void)mp;
(void)ff;
return;
}
static void mplib_shipout_backend(MP mp,void*voidh){
mp_edge_header_node h= (mp_edge_header_node)voidh;
mp_edge_object*hh= mp_gr_export(mp,h);
if(hh){
mp_run_data*run= mp_rundata(mp);
if(run->edges==NULL){
run->edges= hh;
}else{
mp_edge_object*p= run->edges;
while(p->next!=NULL){
p= p->next;
}
p->next= hh;
}
}
}


/*:1072*//*1075:*/
#line 30743 "../../../source/texk/web2c/mplibdir/mp.w"

mp_run_data*mp_rundata(MP mp){
return&(mp->run_data);
}


/*:1075*//*1079:*/
#line 30806 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_execute(MP mp,char*s,size_t l){
mp_reset_stream(&(mp->run_data.term_out));
mp_reset_stream(&(mp->run_data.log_out));
mp_reset_stream(&(mp->run_data.error_out));
mp_reset_stream(&(mp->run_data.ship_out));
if(mp->finished){
return mp->history;
}else if(!mp->noninteractive){
mp->history= mp_fatal_error_stop;
return mp->history;
}
if(mp->history<mp_fatal_error_stop){
xfree(mp->jump_buf);
mp->jump_buf= malloc(sizeof(jmp_buf));
if(mp->jump_buf==NULL||setjmp(*(mp->jump_buf))!=0){
return mp->history;
}
if(s==NULL){
mp_final_cleanup(mp);
mp_close_files_and_terminate(mp);
return mp->history;
}
mp->tally= 0;
mp->term_offset= 0;
mp->file_offset= 0;



if(mp->run_data.term_in.data)
xfree(mp->run_data.term_in.data);
mp->run_data.term_in.data= xstrdup(s);
mp->run_data.term_in.cur= mp->run_data.term_in.data;
mp->run_data.term_in.size= l;
if(mp->run_state==0){
mp->selector= term_only;
/*1078:*/
#line 30761 "../../../source/texk/web2c/mplibdir/mp.w"

/*86:*/
#line 1532 "../../../source/texk/web2c/mplibdir/mp.w"

mp->selector= term_only;
mp->tally= 0;
mp->term_offset= 0;
mp->file_offset= 0;

/*:86*//*95:*/
#line 1744 "../../../source/texk/web2c/mplibdir/mp.w"

wterm(mp->banner);
mp_print_ln(mp);
update_terminal();

/*:95*/
#line 30762 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp->input_ptr= 0;
mp->max_in_stack= file_bottom;
mp->in_open= file_bottom;
mp->open_parens= 0;
mp->max_buf_stack= 0;
mp->param_ptr= 0;
mp->max_param_stack= 0;
start= loc= 0;
iindex= file_bottom;
nloc= nstart= NULL;
mp->first= 0;
line= 0;
name= is_term;
mp->mpx_name[file_bottom]= absent;
mp->force_eof= false;
t_open_in();
mp->scanner_status= normal;
if(!mp->ini_version){
if(!mp_load_preload_file(mp)){
mp->history= mp_fatal_error_stop;
return mp->history;
}
}
mp_fix_date_and_time(mp);
if(mp->random_seed==0)
mp->random_seed=
(number_to_scaled(internal_value(mp_time))/number_to_scaled(unity_t))+number_to_scaled(internal_value(mp_day));
init_randoms(mp->random_seed);
initialize_print_selector();
mp_open_log_file(mp);
mp_set_job_id(mp);
mp_init_map_file(mp,mp->troff_mode);
mp->history= mp_spotless;
if(mp->troff_mode){
number_clone(internal_value(mp_gtroffmode),unity_t);
number_clone(internal_value(mp_prologues),unity_t);
}
/*880:*/
#line 21913 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->job_name!=NULL){
if(internal_string(mp_job_name)!=0)
delete_str_ref(internal_string(mp_job_name));
set_internal_string(mp_job_name,mp_rts(mp,mp->job_name));
}

/*:880*/
#line 30800 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp->start_sym!=NULL){
set_cur_sym(mp->start_sym);
mp_back_input(mp);
}

/*:1078*/
#line 30842 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
mp->run_state= 1;
(void)mp_input_ln(mp,mp->term_in);
mp_firm_up_the_line(mp);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
do{
mp_do_statement(mp);
}while(cur_cmd()!=mp_stop);
mp_final_cleanup(mp);
mp_close_files_and_terminate(mp);
}
return mp->history;
}


/*:1079*//*1080:*/
#line 30861 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_finish(MP mp){
int history= 0;
if(mp->finished||mp->history>=mp_fatal_error_stop){
history= mp->history;
mp_free(mp);
return history;
}
xfree(mp->jump_buf);
mp->jump_buf= malloc(sizeof(jmp_buf));
if(mp->jump_buf==NULL||setjmp(*(mp->jump_buf))!=0){
history= mp->history;
}else{
history= mp->history;
mp_final_cleanup(mp);
}
mp_close_files_and_terminate(mp);
mp_free(mp);
return history;
}


/*:1080*//*1081:*/
#line 30884 "../../../source/texk/web2c/mplibdir/mp.w"

char*mp_metapost_version(void){
return mp_strdup(metapost_version);
}
void mp_show_library_versions(void){
/*
fprintf(stdout,"Compiled with cairo %s; using %s\n",COMPILED_CAIRO_VERSION_STRING,cairo_version_string());
fprintf(stdout,"Compiled with pixman %s; using %s\n",COMPILED_PIXMAN_VERSION_STRING,pixman_version_string());
fprintf(stdout,"Compiled with libpng %s; using %s\n",PNG_LIBPNG_VER_STRING,png_libpng_ver);
fprintf(stdout,"Compiled with zlib %s; using %s\n",ZLIB_VERSION,zlibVersion());
fprintf(stdout,"Compiled with mpfr %s; using %s\n",COMPILED_MPFR_VERSION_STRING,mpfr_get_version());
fprintf(stdout,"Compiled with gmp %d.%d.%d; using %s\n\n",COMPILED__GNU_MP_VERSION,COMPILED__GNU_MP_VERSION_MINOR,COMPILED__GNU_MP_VERSION_PATCHLEVEL,COMPILED_gmp_version);
*/
}

/*:1081*//*1087:*/
#line 30929 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_random_seed(MP mp){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
if(cur_cmd()!=mp_assignment){
const char*hlp[]= {"Always say `randomseed:=<numeric expression>'.",NULL};
mp_back_error(mp,"Missing `:=' has been inserted",hlp,true);
;
};
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known){
const char*hlp[]= {
"Your expression was too random for me to handle,",
"so I won't change the random seed just now.",
NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Unknown value will be ignored",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
/*1088:*/
#line 30958 "../../../source/texk/web2c/mplibdir/mp.w"

{
init_randoms(number_to_scaled(cur_exp_value_number()));
if(mp->selector>=log_only&&mp->selector<write_file){
mp->old_setting= mp->selector;
mp->selector= log_only;
mp_print_nl(mp,"{randomseed:=");
print_number(cur_exp_value_number());
mp_print_char(mp,xord('}'));
mp_print_nl(mp,"");
mp->selector= mp->old_setting;
}
}


/*:1088*/
#line 30953 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}


/*:1087*//*1096:*/
#line 31024 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_protection(MP mp){
int m;
halfword t;
m= cur_mod();
do{
mp_get_symbol(mp);
t= eq_type(cur_sym());
if(m==0){
if(t>=mp_outer_tag)
set_eq_type(cur_sym(),(t-mp_outer_tag));
}else if(t<mp_outer_tag){
set_eq_type(cur_sym(),(t+mp_outer_tag));
}
mp_get_x_next(mp);
}while(cur_cmd()==mp_comma);
}


/*:1096*//*1099:*/
#line 31052 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_def_delims(MP mp){
mp_sym l_delim,r_delim;
mp_get_clear_symbol(mp);
l_delim= cur_sym();
mp_get_clear_symbol(mp);
r_delim= cur_sym();
set_eq_type(l_delim,mp_left_delimiter);
set_equiv_sym(l_delim,r_delim);
set_eq_type(r_delim,mp_right_delimiter);
set_equiv_sym(r_delim,l_delim);
mp_get_x_next(mp);
}


/*:1099*//*1101:*/
#line 31073 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_check_delimiter(MP mp,mp_sym l_delim,mp_sym r_delim){
if(cur_cmd()==mp_right_delimiter)
if(equiv_sym(cur_sym())==l_delim)
return;
if(cur_sym()!=r_delim){
char msg[256];
const char*hlp[]= {
"I found no right delimiter to match a left one. So I've",
"put one in, behind the scenes; this may fix the problem.",
NULL};
mp_snprintf(msg,256,"Missing `%s' has been inserted",mp_str(mp,text(r_delim)));
;
mp_back_error(mp,msg,hlp,true);
}else{
char msg[256];
const char*hlp[]= {
"Strange: This token has lost its former meaning!",
"I'll read it as a right delimiter this time;",
"but watch out, I'll probably miss it later.",
NULL};
mp_snprintf(msg,256,"The token `%s' is no longer a right delimiter",mp_str(mp,text(r_delim)));
;
mp_error(mp,msg,hlp,true);
}
}


/*:1101*//*1104:*/
#line 31107 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_interim(MP mp){
mp_get_x_next(mp);
if(cur_cmd()!=mp_internal_quantity){
char msg[256];
const char*hlp[]= {
"Something like `tracingonline' should follow `interim'.",
NULL};
mp_snprintf(msg,256,"The token `%s' isn't an internal quantity",
(cur_sym()==NULL?"(%CAPSULE)":mp_str(mp,text(cur_sym()))));
;
mp_back_error(mp,msg,hlp,true);
}else{
mp_save_internal(mp,cur_mod());
mp_back_input(mp);
}
mp_do_statement(mp);
}


/*:1104*//*1106:*/
#line 31133 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_let(MP mp){
mp_sym l;
mp_get_symbol(mp);
l= cur_sym();
mp_get_x_next(mp);
if(cur_cmd()!=mp_equals&&cur_cmd()!=mp_assignment){
const char*hlp[]= {
"You should have said `let symbol = something'.",
"But don't worry; I'll pretend that an equals sign",
"was present. The next token I read will be `something'.",
NULL};
mp_back_error(mp,"Missing `=' has been inserted",hlp,true);
;
}
mp_get_symbol(mp);
switch(cur_cmd()){
case mp_defined_macro:
case mp_secondary_primary_macro:
case mp_tertiary_secondary_macro:
case mp_expression_tertiary_macro:
add_mac_ref(cur_mod_node());
break;
default:
break;
}
mp_clear_symbol(mp,l,false);
set_eq_type(l,cur_cmd());
if(cur_cmd()==mp_tag_token)
set_equiv(l,0);
else if(cur_cmd()==mp_defined_macro||
cur_cmd()==mp_secondary_primary_macro||
cur_cmd()==mp_tertiary_secondary_macro||
cur_cmd()==mp_expression_tertiary_macro)
set_equiv_node(l,cur_mod_node());
else if(cur_cmd()==mp_left_delimiter||
cur_cmd()==mp_right_delimiter)
set_equiv_sym(l,equiv_sym(cur_sym()));
else
set_equiv(l,cur_mod());
mp_get_x_next(mp);
}


/*:1106*//*1109:*/
#line 31183 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_grow_internals(MP mp,int l){
mp_internal*internal;
int k;
if(l> max_halfword){
mp_confusion(mp,"out of memory space");
}
internal= xmalloc((l+1),sizeof(mp_internal));
for(k= 0;k<=l;k++){
if(k<=mp->max_internal){
memcpy(internal+k,mp->internal+k,sizeof(mp_internal));
}else{
memset(internal+k,0,sizeof(mp_internal));
new_number(((mp_internal*)(internal+k))->v.data.n);
}
}
xfree(mp->internal);
mp->internal= internal;
mp->max_internal= l;
}
void mp_do_new_internal(MP mp){
int the_type= mp_known;
mp_get_x_next(mp);
if(cur_cmd()==mp_type_name&&cur_mod()==mp_string_type){
the_type= mp_string_type;
}else{
if(!(cur_cmd()==mp_type_name&&cur_mod()==mp_numeric_type)){
mp_back_input(mp);
}
}
do{
if(mp->int_ptr==mp->max_internal){
mp_grow_internals(mp,(mp->max_internal+(mp->max_internal/4)));
}
mp_get_clear_symbol(mp);
incr(mp->int_ptr);
set_eq_type(cur_sym(),mp_internal_quantity);
set_equiv(cur_sym(),mp->int_ptr);
if(internal_name(mp->int_ptr)!=NULL)
xfree(internal_name(mp->int_ptr));
set_internal_name(mp->int_ptr,
mp_xstrdup(mp,mp_str(mp,text(cur_sym()))));
if(the_type==mp_string_type){
set_internal_string(mp->int_ptr,mp_rts(mp,""));
}else{
set_number_to_zero(internal_value(mp->int_ptr));
}
set_internal_type(mp->int_ptr,the_type);
mp_get_x_next(mp);
}while(cur_cmd()==mp_comma);
}


/*:1109*//*1114:*/
#line 31294 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_show(MP mp){
mp_value new_expr;
do{
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
mp_scan_expression(mp);
mp_print_nl(mp,">> ");
;
mp_print_exp(mp,NULL,2);
mp_flush_cur_exp(mp,new_expr);
}while(cur_cmd()==mp_comma);
}


/*:1114*//*1116:*/
#line 31313 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_disp_token(MP mp){
mp_print_nl(mp,"> ");
;
if(cur_sym()==NULL){
/*1117:*/
#line 31334 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(cur_cmd()==mp_numeric_token){
print_number(cur_mod_number());
}else if(cur_cmd()==mp_capsule_token){
mp_print_capsule(mp,cur_mod_node());
}else{
mp_print_char(mp,xord('"'));
mp_print_str(mp,cur_mod_str());
mp_print_char(mp,xord('"'));
delete_str_ref(cur_mod_str());
}
}


/*:1117*/
#line 31318 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp_print_text(cur_sym());
mp_print_char(mp,xord('='));
if(eq_type(cur_sym())>=mp_outer_tag)
mp_print(mp,"(outer) ");
mp_print_cmd_mod(mp,cur_cmd(),cur_mod());
if(cur_cmd()==mp_defined_macro){
mp_print_ln(mp);
mp_show_macro(mp,cur_mod_node(),NULL,100000);
}

}
}


/*:1116*//*1120:*/
#line 31395 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_show_token(MP mp){
do{
get_t_next(mp);
mp_disp_token(mp);
mp_get_x_next(mp);
}while(cur_cmd()==mp_comma);
}


/*:1120*//*1122:*/
#line 31408 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_show_stats(MP mp){
mp_print_nl(mp,"Memory usage ");
;
mp_print_int(mp,(integer)mp->var_used);
mp_print_ln(mp);
mp_print_nl(mp,"String usage ");
mp_print_int(mp,(int)mp->strs_in_use);
mp_print_char(mp,xord('&'));
mp_print_int(mp,(int)mp->pool_in_use);
mp_print_ln(mp);
mp_get_x_next(mp);
}


/*:1122*//*1124:*/
#line 31429 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_disp_var(MP mp,mp_node p){
mp_node q;
int n;
if(mp_type(p)==mp_structured){
/*1125:*/
#line 31446 "../../../source/texk/web2c/mplibdir/mp.w"

{
q= attr_head(p);
do{
mp_disp_var(mp,q);
q= mp_link(q);
}while(q!=mp->end_attr);
q= subscr_head(p);
while(mp_name_type(q)==mp_subscr){
mp_disp_var(mp,q);
q= mp_link(q);
}
}


/*:1125*/
#line 31434 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(mp_type(p)>=mp_unsuffixed_macro){
/*1126:*/
#line 31461 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_print_nl(mp,"");
mp_print_variable_name(mp,p);
if(mp_type(p)> mp_unsuffixed_macro)
mp_print(mp,"@#");
mp_print(mp,"=macro:");
if((int)mp->file_offset>=mp->max_print_line-20)
n= 5;
else
n= mp->max_print_line-(int)mp->file_offset-15;
mp_show_macro(mp,value_node(p),NULL,n);
}


/*:1126*/
#line 31436 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else if(mp_type(p)!=mp_undefined){
mp_print_nl(mp,"");
mp_print_variable_name(mp,p);
mp_print_char(mp,xord('='));
mp_print_exp(mp,p,0);
}
}


/*:1124*//*1128:*/
#line 31479 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_show_var(MP mp){
do{
get_t_next(mp);
if(cur_sym()!=NULL)
if(cur_sym_mod()==0)
if(cur_cmd()==mp_tag_token)
if(cur_mod()!=0||cur_mod_node()!=NULL){
mp_disp_var(mp,cur_mod_node());
goto DONE;
}
mp_disp_token(mp);
DONE:
mp_get_x_next(mp);
}while(cur_cmd()==mp_comma);
}


/*:1128*//*1130:*/
#line 31500 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_show_dependencies(MP mp){
mp_value_node p;
p= (mp_value_node)mp_link(mp->dep_head);
while(p!=mp->dep_head){
if(mp_interesting(mp,(mp_node)p)){
mp_print_nl(mp,"");
mp_print_variable_name(mp,(mp_node)p);
if(mp_type(p)==mp_dependent)
mp_print_char(mp,xord('='));
else
mp_print(mp," = ");
mp_print_dependency(mp,(mp_value_node)dep_list(p),mp_type(p));
}
p= (mp_value_node)dep_list(p);
while(dep_info(p)!=NULL)
p= (mp_value_node)mp_link(p);
p= (mp_value_node)mp_link(p);
}
mp_get_x_next(mp);
}


/*:1130*//*1132:*/
#line 31529 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_show_whatever(MP mp){
if(mp->interaction==mp_error_stop_mode)
wake_up_terminal();
switch(cur_mod()){
case show_token_code:
mp_do_show_token(mp);
break;
case show_stats_code:
mp_do_show_stats(mp);
break;
case show_code:
mp_do_show(mp);
break;
case show_var_code:
mp_do_show_var(mp);
break;
case show_dependencies_code:
mp_do_show_dependencies(mp);
break;
}
if(number_positive(internal_value(mp_showstopping))){
const char*hlp[]= {
"This isn't an error message; I'm just showing something.",
NULL};
if(mp->interaction<mp_error_stop_mode){
hlp[0]= NULL;
decr(mp->error_count);
}
if(cur_cmd()==mp_semicolon){
mp_error(mp,"OK",hlp,true);
}else{
mp_back_error(mp,"OK",hlp,true);
mp_get_x_next(mp);
}
;
}
}


/*:1132*//*1137:*/
#line 31674 "../../../source/texk/web2c/mplibdir/mp.w"

static int is_invalid_with_list(MP mp,mp_variable_type t){
return((t==with_mp_pre_script)&&(mp->cur_exp.type!=mp_string_type))||
((t==with_mp_post_script)&&(mp->cur_exp.type!=mp_string_type))||
((t==(mp_variable_type)mp_uninitialized_model)&&
((mp->cur_exp.type!=mp_cmykcolor_type)
&&(mp->cur_exp.type!=mp_color_type)
&&(mp->cur_exp.type!=mp_known)
&&(mp->cur_exp.type!=mp_boolean_type)))||((t==(mp_variable_type)mp_cmyk_model)
&&(mp->cur_exp.type!=
mp_cmykcolor_type))
||((t==(mp_variable_type)mp_rgb_model)&&(mp->cur_exp.type!=mp_color_type))
||((t==(mp_variable_type)mp_grey_model)&&(mp->cur_exp.type!=mp_known))
||((t==(mp_variable_type)mp_pen_type)&&(mp->cur_exp.type!=t))
||((t==(mp_variable_type)mp_picture_type)&&(mp->cur_exp.type!=t));
}
static void complain_invalid_with_list(MP mp,mp_variable_type t){

mp_value new_expr;
const char*hlp[]= {
"Next time say `withpen <known pen expression>';",
"I'll ignore the bad `with' clause and look for another.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
if(t==with_mp_pre_script)
hlp[0]= "Next time say `withprescript <known string expression>';";
else if(t==with_mp_post_script)
hlp[0]= "Next time say `withpostscript <known string expression>';";
else if(t==mp_picture_type)
hlp[0]= "Next time say `dashed <known picture expression>';";
else if(t==(mp_variable_type)mp_uninitialized_model)
hlp[0]= "Next time say `withcolor <known color expression>';";
else if(t==(mp_variable_type)mp_rgb_model)
hlp[0]= "Next time say `withrgbcolor <known color expression>';";
else if(t==(mp_variable_type)mp_cmyk_model)
hlp[0]= "Next time say `withcmykcolor <known cmykcolor expression>';";
else if(t==(mp_variable_type)mp_grey_model)
hlp[0]= "Next time say `withgreyscale <known numeric expression>';";;
mp_back_error(mp,"Improper type",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}

void mp_scan_with_list(MP mp,mp_node p){
mp_variable_type t;
mp_node q;
mp_node cp,pp,dp,ap,bp;

cp= MP_VOID;
pp= MP_VOID;
dp= MP_VOID;
ap= MP_VOID;
bp= MP_VOID;
while(cur_cmd()==mp_with_option){

t= (mp_variable_type)cur_mod();
mp_get_x_next(mp);
if(t!=(mp_variable_type)mp_no_model)
mp_scan_expression(mp);
if(is_invalid_with_list(mp,t)){
complain_invalid_with_list(mp,t);
continue;
}
if(t==(mp_variable_type)mp_uninitialized_model){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(cp==MP_VOID)
make_cp_a_colored_object();
if(cp!=NULL){

if(mp->cur_exp.type==mp_color_type){

mp_stroked_node cp0= (mp_stroked_node)cp;
q= value_node(cur_exp_node());
clear_color(cp0);
mp_color_model(cp)= mp_rgb_model;
set_color_val(cp0->red,value_number(red_part(q)));
set_color_val(cp0->green,value_number(green_part(q)));
set_color_val(cp0->blue,value_number(blue_part(q)));
}else if(mp->cur_exp.type==mp_cmykcolor_type){

mp_stroked_node cp0= (mp_stroked_node)cp;
q= value_node(cur_exp_node());
set_color_val(cp0->cyan,value_number(cyan_part(q)));
set_color_val(cp0->magenta,value_number(magenta_part(q)));
set_color_val(cp0->yellow,value_number(yellow_part(q)));
set_color_val(cp0->black,value_number(black_part(q)));
mp_color_model(cp)= mp_cmyk_model;
}else if(mp->cur_exp.type==mp_known){

mp_number qq;
mp_stroked_node cp0= (mp_stroked_node)cp;
new_number(qq);
number_clone(qq,cur_exp_value_number());
clear_color(cp);
mp_color_model(cp)= mp_grey_model;
set_color_val(cp0->grey,qq);
free_number(qq);
}else if(cur_exp_value_boolean()==mp_false_code){

clear_color(cp);
mp_color_model(cp)= mp_no_model;
}else if(cur_exp_value_boolean()==mp_true_code){

clear_color(cp);
mp_color_model(cp)= mp_uninitialized_model;
}
}
mp_flush_cur_exp(mp,new_expr);
}else if(t==(mp_variable_type)mp_rgb_model){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(cp==MP_VOID)
make_cp_a_colored_object();
if(cp!=NULL){

mp_stroked_node cp0= (mp_stroked_node)cp;
q= value_node(cur_exp_node());
clear_color(cp0);
mp_color_model(cp)= mp_rgb_model;
set_color_val(cp0->red,value_number(red_part(q)));
set_color_val(cp0->green,value_number(green_part(q)));
set_color_val(cp0->blue,value_number(blue_part(q)));
}
mp_flush_cur_exp(mp,new_expr);
}else if(t==(mp_variable_type)mp_cmyk_model){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(cp==MP_VOID)
make_cp_a_colored_object();
if(cp!=NULL){

mp_stroked_node cp0= (mp_stroked_node)cp;
q= value_node(cur_exp_node());
set_color_val(cp0->cyan,value_number(cyan_part(q)));
set_color_val(cp0->magenta,value_number(magenta_part(q)));
set_color_val(cp0->yellow,value_number(yellow_part(q)));
set_color_val(cp0->black,value_number(black_part(q)));
mp_color_model(cp)= mp_cmyk_model;
}
mp_flush_cur_exp(mp,new_expr);
}else if(t==(mp_variable_type)mp_grey_model){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
if(cp==MP_VOID)
make_cp_a_colored_object();
if(cp!=NULL){

mp_number qq;
mp_stroked_node cp0= (mp_stroked_node)cp;
new_number(qq);
number_clone(qq,cur_exp_value_number());
clear_color(cp);
mp_color_model(cp)= mp_grey_model;
set_color_val(cp0->grey,qq);
free_number(qq);
}
mp_flush_cur_exp(mp,new_expr);
}else if(t==(mp_variable_type)mp_no_model){
if(cp==MP_VOID)
make_cp_a_colored_object();
if(cp!=NULL){

clear_color(cp);
mp_color_model(cp)= mp_no_model;
}
}else if(t==mp_pen_type){
if(pp==MP_VOID){

pp= p;
while(pp!=NULL){
if(has_pen(pp))
break;
pp= mp_link(pp);
}
}

if(pp!=NULL){
switch(mp_type(pp)){
case mp_fill_node_type:
if(mp_pen_p((mp_fill_node)pp)!=NULL)
mp_toss_knot_list(mp,mp_pen_p((mp_fill_node)pp));
mp_pen_p((mp_fill_node)pp)= cur_exp_knot();
break;
case mp_stroked_node_type:
if(mp_pen_p((mp_stroked_node)pp)!=NULL)
mp_toss_knot_list(mp,mp_pen_p((mp_stroked_node)pp));
mp_pen_p((mp_stroked_node)pp)= cur_exp_knot();
break;
default:
assert(0);
break;
}
mp->cur_exp.type= mp_vacuous;
}
}else if(t==with_mp_pre_script){
if(cur_exp_str()->len){
if(ap==MP_VOID)
ap= p;
while((ap!=NULL)&&(!has_color(ap)))
ap= mp_link(ap);
if(ap!=NULL){
if(mp_pre_script(ap)!=NULL){
unsigned old_setting;
mp_string s;
s= mp_pre_script(ap);
old_setting= mp->selector;
mp->selector= new_string;
str_room(mp_pre_script(ap)->len+cur_exp_str()->len+2);
mp_print_str(mp,cur_exp_str());
append_char(13);
mp_print_str(mp,mp_pre_script(ap));
mp_pre_script(ap)= mp_make_string(mp);
delete_str_ref(s);
mp->selector= old_setting;
}else{
mp_pre_script(ap)= cur_exp_str();
}
add_str_ref(mp_pre_script(ap));
mp->cur_exp.type= mp_vacuous;
}
}
}else if(t==with_mp_post_script){
if(cur_exp_str()->len){
if(bp==MP_VOID)
bp= p;
while((bp!=NULL)&&(!has_color(bp)))
bp= mp_link(bp);
if(bp!=NULL){
if(mp_post_script(bp)!=NULL){
unsigned old_setting;
mp_string s;
s= mp_post_script(bp);
old_setting= mp->selector;
mp->selector= new_string;
str_room(mp_post_script(bp)->len+cur_exp_str()->len+2);
mp_print_str(mp,mp_post_script(bp));
append_char(13);
mp_print_str(mp,cur_exp_str());
mp_post_script(bp)= mp_make_string(mp);
delete_str_ref(s);
mp->selector= old_setting;
}else{
mp_post_script(bp)= cur_exp_str();
}
add_str_ref(mp_post_script(bp));
mp->cur_exp.type= mp_vacuous;
}
}
}else{
if(dp==MP_VOID){

dp= p;
while(dp!=NULL){
if(mp_type(dp)==mp_stroked_node_type)
break;
dp= mp_link(dp);
}
}
if(dp!=NULL){
if(mp_dash_p(dp)!=NULL)
delete_edge_ref(mp_dash_p(dp));
mp_dash_p(dp)= (mp_node)mp_make_dashes(mp,(mp_edge_header_node)cur_exp_node());
set_number_to_unity(((mp_stroked_node)dp)->dash_scale);
mp->cur_exp.type= mp_vacuous;
}
}
}


if(cp> MP_VOID){

q= mp_link(cp);
while(q!=NULL){
if(has_color(q)){
mp_stroked_node q0= (mp_stroked_node)q;
mp_stroked_node cp0= (mp_stroked_node)cp;
number_clone(q0->red,cp0->red);
number_clone(q0->green,cp0->green);
number_clone(q0->blue,cp0->blue);
number_clone(q0->black,cp0->black);
mp_color_model(q)= mp_color_model(cp);
}
q= mp_link(q);
}
}
if(pp> MP_VOID){

q= mp_link(pp);
while(q!=NULL){
if(has_pen(q)){
switch(mp_type(q)){
case mp_fill_node_type:
if(mp_pen_p((mp_fill_node)q)!=NULL)
mp_toss_knot_list(mp,mp_pen_p((mp_fill_node)q));
mp_pen_p((mp_fill_node)q)= copy_pen(mp_pen_p((mp_fill_node)pp));
break;
case mp_stroked_node_type:
if(mp_pen_p((mp_stroked_node)q)!=NULL)
mp_toss_knot_list(mp,mp_pen_p((mp_stroked_node)q));
mp_pen_p((mp_stroked_node)q)=
copy_pen(mp_pen_p((mp_stroked_node)pp));
break;
default:
assert(0);
break;
}
}
q= mp_link(q);
}
}
if(dp> MP_VOID){

q= mp_link(dp);
while(q!=NULL){
if(mp_type(q)==mp_stroked_node_type){
if(mp_dash_p(q)!=NULL)
delete_edge_ref(mp_dash_p(q));
mp_dash_p(q)= mp_dash_p(dp);
set_number_to_unity(((mp_stroked_node)q)->dash_scale);
if(mp_dash_p(q)!=NULL)
add_edge_ref(mp_dash_p(q));
}
q= mp_link(q);
}
}
}


/*:1137*//*1139:*/
#line 32017 "../../../source/texk/web2c/mplibdir/mp.w"

mp_edge_header_node mp_find_edges_var(MP mp,mp_node t){
mp_node p;
mp_edge_header_node cur_edges;
p= mp_find_variable(mp,t);
cur_edges= NULL;
if(p==NULL){
const char*hlp[]= {
"It seems you did a nasty thing---probably by accident,",
"but nevertheless you nearly hornswoggled me...",
"While I was evaluating the right-hand side of this",
"command, something happened, and the left-hand side",
"is no longer a variable! So I won't change anything.",
NULL};
char*msg= mp_obliterated(mp,t);
mp_back_error(mp,msg,hlp,true);
free(msg);
mp_get_x_next(mp);
}else if(mp_type(p)!=mp_picture_type){
char msg[256];
mp_string sname;
int old_setting= mp->selector;
const char*hlp[]= {
"I was looking for a \"known\" picture variable.",
"So I'll not change anything just now.",
NULL};
mp->selector= new_string;
mp_show_token_list(mp,t,NULL,1000,0);
sname= mp_make_string(mp);
mp->selector= old_setting;
mp_snprintf(msg,256,"Variable %s is the wrong type(%s)",
mp_str(mp,sname),mp_type_string(mp_type(p)));
;
delete_str_ref(sname);
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}else{
set_value_node(p,(mp_node)mp_private_edges(mp,(mp_edge_header_node)value_node(p)));
cur_edges= (mp_edge_header_node)value_node(p);
}
mp_flush_node_list(mp,t);
return cur_edges;
}


/*:1139*//*1144:*/
#line 32091 "../../../source/texk/web2c/mplibdir/mp.w"

mp_node mp_start_draw_cmd(MP mp,quarterword sep){
mp_node lhv;
quarterword add_type= 0;
lhv= NULL;
mp_get_x_next(mp);
mp->var_flag= sep;
mp_scan_primary(mp);
if(mp->cur_exp.type!=mp_token_list){

mp_value new_expr;
const char*hlp[]= {
"At this point I needed to see the name of a picture variable.",
"(Or perhaps you have indeed presented me with one; I might",
"have missed it, if it wasn't followed by the proper token.)",
"So I'll not change anything just now.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Not a suitable variable",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
lhv= cur_exp_node();
add_type= (quarterword)cur_mod();
mp->cur_exp.type= mp_vacuous;
mp_get_x_next(mp);
mp_scan_expression(mp);
}
mp->last_add_type= add_type;
return lhv;
}

/*:1144*//*1146:*/
#line 32131 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_bounds(MP mp){
mp_node lhv;
mp_edge_header_node lhe;
mp_node p;
integer m;
m= cur_mod();
lhv= mp_start_draw_cmd(mp,mp_to_token);
if(lhv!=NULL){
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
lhe= mp_find_edges_var(mp,lhv);
if(lhe==NULL){
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}else if(mp->cur_exp.type!=mp_path_type){
const char*hlp[]= {
"This expression should have specified a known path.",
"So I'll not change anything just now.",
NULL};
mp_disp_err(mp,NULL);
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Improper `clip'",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else if(mp_left_type(cur_exp_knot())==mp_endpoint){

const char*hlp[]= {
"That contour should have ended with `..cycle' or `&cycle'.",
"So I'll not change anything just now.",
NULL};
mp_back_error(mp,"Not a cycle",hlp,true);
mp_get_x_next(mp);
}else{

p= mp_new_bounds_node(mp,cur_exp_knot(),(quarterword)m);
mp_link(p)= mp_link(edge_list(lhe));
mp_link(edge_list(lhe))= p;
if(obj_tail(lhe)==edge_list(lhe))
obj_tail(lhe)= p;
if(m==mp_start_clip_node_type){
p= mp_new_bounds_node(mp,NULL,mp_stop_clip_node_type);
}else if(m==mp_start_bounds_node_type){
p= mp_new_bounds_node(mp,NULL,mp_stop_bounds_node_type);
}
mp_link(obj_tail(lhe))= p;
obj_tail(lhe)= p;
mp_init_bbox(mp,lhe);
}
}
}


/*:1146*//*1148:*/
#line 32192 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_add_to(MP mp){
mp_node lhv;
mp_edge_header_node lhe;
mp_node p;
mp_edge_header_node e;
quarterword add_type;
lhv= mp_start_draw_cmd(mp,mp_thing_to_add);
add_type= mp->last_add_type;
if(lhv!=NULL){
if(add_type==also_code){




p= NULL;
e= NULL;
if(mp->cur_exp.type!=mp_picture_type){
mp_value new_expr;
const char*hlp[]= {
"This expression should have specified a known picture.",
"So I'll not change anything just now.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Improper `addto'",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else{
e= mp_private_edges(mp,(mp_edge_header_node)cur_exp_node());
mp->cur_exp.type= mp_vacuous;
p= mp_link(edge_list(e));
}

}else{




e= NULL;
p= NULL;
if(mp->cur_exp.type==mp_pair_type)
mp_pair_to_path(mp);
if(mp->cur_exp.type!=mp_path_type){
mp_value new_expr;
const char*hlp[]= {
"This expression should have specified a known path.",
"So I'll not change anything just now.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Improper `addto'",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}else if(add_type==contour_code){
if(mp_left_type(cur_exp_knot())==mp_endpoint){

const char*hlp[]= {
"That contour should have ended with `..cycle' or `&cycle'.",
"So I'll not change anything just now.",
NULL};
mp_back_error(mp,"Not a cycle",hlp,true);
mp_get_x_next(mp);

}else{
p= mp_new_fill_node(mp,cur_exp_knot());
mp->cur_exp.type= mp_vacuous;
}
}else{
p= mp_new_stroked_node(mp,cur_exp_knot());
mp->cur_exp.type= mp_vacuous;
}

}
mp_scan_with_list(mp,p);

lhe= mp_find_edges_var(mp,lhv);
if(lhe==NULL){
if((e==NULL)&&(p!=NULL))
e= mp_toss_gr_object(mp,p);
if(e!=NULL)
delete_edge_ref(e);
}else if(add_type==also_code){
if(e!=NULL){

if(mp_link(edge_list(e))!=NULL){
mp_link(obj_tail(lhe))= mp_link(edge_list(e));
obj_tail(lhe)= obj_tail(e);
obj_tail(e)= edge_list(e);
mp_link(edge_list(e))= NULL;
mp_flush_dash_list(mp,lhe);
}
mp_toss_edges(mp,e);
}
}else if(p!=NULL){
mp_link(obj_tail(lhe))= p;
obj_tail(lhe)= p;
if(add_type==double_path_code){
if(mp_pen_p((mp_stroked_node)p)==NULL){
mp_pen_p((mp_stroked_node)p)= mp_get_pen_circle(mp,zero_t);
}
}
}
}
}

/*:1148*//*1150:*/
#line 32306 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_ship_out(MP mp){
integer c;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_picture_type){
/*1151:*/
#line 32328 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {"I can only output known pictures.",NULL};
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Not a known picture",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}


/*:1151*/
#line 32315 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
c= round_unscaled(internal_value(mp_char_code))%256;
if(c<0)
c= c+256;
/*1185:*/
#line 33011 "../../../source/texk/web2c/mplibdir/mp.w"

if(c<mp->bc)
mp->bc= (eight_bits)c;
if(c> mp->ec)
mp->ec= (eight_bits)c;
mp->char_exists[c]= true;
mp_free_value_node(mp,mp->tfm_width[c]);
mp->tfm_width[c]= mp_tfm_check(mp,mp_char_wd);
mp_free_value_node(mp,mp->tfm_height[c]);
mp->tfm_height[c]= mp_tfm_check(mp,mp_char_ht);
mp_free_value_node(mp,mp->tfm_depth[c]);
mp->tfm_depth[c]= mp_tfm_check(mp,mp_char_dp);
mp_free_value_node(mp,mp->tfm_ital_corr[c]);
mp->tfm_ital_corr[c]= mp_tfm_check(mp,mp_char_ic)


/*:1185*/
#line 32320 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_ship_out(mp,cur_exp_node());
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}
}


/*:1150*//*1158:*/
#line 32399 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_message(MP mp){
int m;
mp_value new_expr;
m= cur_mod();
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_string_type)
mp_no_string_err(mp,"A message should be a known string expression.");
else{
switch(m){
case message_code:
mp_print_nl(mp,"");
mp_print_str(mp,cur_exp_str());
break;
case err_message_code:
/*1164:*/
#line 32480 "../../../source/texk/web2c/mplibdir/mp.w"

{
char msg[256];
mp_snprintf(msg,256,"%s",mp_str(mp,cur_exp_str()));
if(mp->err_help!=NULL){
mp->use_err_help= true;
mp_back_error(mp,msg,NULL,true);
}else if(mp->long_help_seen){
const char*hlp[]= {"(That was another `errmessage'.)",NULL};
mp_back_error(mp,msg,hlp,true);
}else{
const char*hlp[]= {
"This error message was generated by an `errmessage'",
"command, so I can\'t give any explicit help.",
"Pretend that you're Miss Marple: Examine all clues,",
"and deduce the truth by inspired guesses.",
NULL};

if(mp->interaction<mp_error_stop_mode)
mp->long_help_seen= true;
mp_back_error(mp,msg,hlp,true);
}
mp_get_x_next(mp);
mp->use_err_help= false;
}


/*:1164*/
#line 32417 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case err_help_code:
/*1161:*/
#line 32457 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp->err_help!=NULL)
delete_str_ref(mp->err_help);
if(cur_exp_str()->len==0)
mp->err_help= NULL;
else{
mp->err_help= cur_exp_str();
add_str_ref(mp->err_help);
}
}


/*:1161*/
#line 32420 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case filename_template_code:
/*1159:*/
#line 32432 "../../../source/texk/web2c/mplibdir/mp.w"

{
delete_str_ref(internal_string(mp_output_template));
if(cur_exp_str()->len==0){
set_internal_string(mp_output_template,mp_rts(mp,"%j.%c"));
}else{
set_internal_string(mp_output_template,cur_exp_str());
add_str_ref(internal_string(mp_output_template));
}
}


/*:1159*/
#line 32423 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
}
}
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}


/*:1158*//*1166:*/
#line 32510 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_write(MP mp){
mp_string t;
write_index n,n0;
unsigned old_setting;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_string_type){
mp_no_string_err(mp,
"The text to be written should be a known string expression");
}else if(cur_cmd()!=mp_to_token){
const char*hlp[]= {"A write command should end with `to <filename>'",NULL};
mp_back_error(mp,"Missing `to' clause",hlp,true);
mp_get_x_next(mp);
}else{
t= cur_exp_str();
mp->cur_exp.type= mp_vacuous;
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_string_type)
mp_no_string_err(mp,
"I can\'t write to that file name.  It isn't a known string");
else{
/*1167:*/
#line 32545 "../../../source/texk/web2c/mplibdir/mp.w"

{
/*1168:*/
#line 32561 "../../../source/texk/web2c/mplibdir/mp.w"

{
char*fn= mp_str(mp,cur_exp_str());
n= mp->write_files;
n0= mp->write_files;
while(mp_xstrcmp(fn,mp->wr_fname[n])!=0){
if(n==0){
if(n0==mp->write_files){
if(mp->write_files<mp->max_write_files){
incr(mp->write_files);
}else{
void**wr_file;
char**wr_fname;
write_index l,k;
l= mp->max_write_files+(mp->max_write_files/4);
wr_file= xmalloc((l+1),sizeof(void*));
wr_fname= xmalloc((l+1),sizeof(char*));
for(k= 0;k<=l;k++){
if(k<=mp->max_write_files){
wr_file[k]= mp->wr_file[k];
wr_fname[k]= mp->wr_fname[k];
}else{
wr_file[k]= 0;
wr_fname[k]= NULL;
}
}
xfree(mp->wr_file);
xfree(mp->wr_fname);
mp->max_write_files= l;
mp->wr_file= wr_file;
mp->wr_fname= wr_fname;
}
}
n= n0;
mp_open_write_file(mp,fn,n);
}else{
decr(n);
if(mp->wr_fname[n]==NULL)
n0= n;
}
}
}


/*:1168*/
#line 32548 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp_str_vs_str(mp,t,mp->eof_line)==0){
/*1169:*/
#line 32605 "../../../source/texk/web2c/mplibdir/mp.w"

{
(mp->close_file)(mp,mp->wr_file[n]);
xfree(mp->wr_fname[n]);
if(n==mp->write_files-1)
mp->write_files= n;
}


/*:1169*/
#line 32550 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
old_setting= mp->selector;
mp->selector= n+write_file;
mp_print_str(mp,t);
mp_print_ln(mp);
mp->selector= old_setting;
}
}


/*:1167*/
#line 32536 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

}
set_number_to_zero(new_expr.data.n);
mp_flush_cur_exp(mp,new_expr);
}


/*:1166*//*1184:*/
#line 32976 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_tfm_check(MP mp,quarterword m){
mp_number absm;
mp_node p= mp_get_value_node(mp);
new_number(absm);
number_clone(absm,internal_value(m));
number_abs(absm);
if(number_greaterequal(absm,fraction_half_t)){
char msg[256];
const char*hlp[]= {
"Font metric dimensions must be less than 2048pt.",
NULL};
mp_snprintf(msg,256,"Enormous %s has been reduced",internal_name(m));




;
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
if(number_positive(internal_value(m))){
set_value_number(p,fraction_half_t);
number_add_scaled(value_number(p),-1);
}else{
set_value_number(p,fraction_half_t);
number_negate(value_number(p));
number_add_scaled(value_number(p),1);
}
}else{
set_value_number(p,internal_value(m));
}
free_number(absm);
return p;
}

/*:1184*//*1190:*/
#line 33073 "../../../source/texk/web2c/mplibdir/mp.w"

eight_bits mp_get_code(MP mp){
integer c;
mp_value new_expr;
const char*hlp[]= {
"I was looking for a number between 0 and 255, or for a",
"string of length 1. Didn't find it; will use 0 instead.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type==mp_known){
c= round_unscaled(cur_exp_value_number());
if(c>=0)
if(c<256)
return(eight_bits)c;
}else if(mp->cur_exp.type==mp_string_type){
if(cur_exp_str()->len==1){
c= (integer)(*(cur_exp_str()->str));
return(eight_bits)c;
}
}
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Invalid code has been replaced by 0",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
c= 0;
return(eight_bits)c;
}


/*:1190*//*1192:*/
#line 33110 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_set_tag(MP mp,halfword c,quarterword t,halfword r){
if(mp->char_tag[c]==no_tag){
mp->char_tag[c]= t;
mp->char_remainder[c]= r;
if(t==lig_tag){
mp->label_ptr++;
mp->label_loc[mp->label_ptr]= (short)r;
mp->label_char[mp->label_ptr]= (eight_bits)c;
}
}else{
/*1193:*/
#line 33126 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*xtra= NULL;
char msg[256];
const char*hlp[]= {
"It's not legal to label a character more than once.",
"So I'll not change anything just now.",
NULL};
switch(mp->char_tag[c]){
case lig_tag:xtra= "in a ligtable";break;
case list_tag:xtra= "in a charlist";break;
case ext_tag:xtra= "extensible";break;
default:xtra= "";break;
}
if((c> ' ')&&(c<127)){
mp_snprintf(msg,256,"Character %c is already %s",xord(c),xtra);
}else if(c==256){
mp_snprintf(msg,256,"Character || is already %s",xtra);
}else{
mp_snprintf(msg,256,"Character code %d is already %s",c,xtra);
}
;
mp_back_error(mp,msg,hlp,true);
mp_get_x_next(mp);
}


/*:1193*/
#line 33121 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}


/*:1192*//*1195:*/
#line 33156 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_tfm_command(MP mp){
int c,cc;
int k;
int j;
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
switch(cur_mod()){
case char_list_code:
c= mp_get_code(mp);

while(cur_cmd()==mp_colon){
cc= mp_get_code(mp);
mp_set_tag(mp,c,list_tag,cc);
c= cc;
};
break;
case lig_table_code:
if(mp->lig_kern==NULL)
mp->lig_kern= xmalloc((max_tfm_int+1),sizeof(four_quarters));
if(mp->kern==NULL){
int i;
mp->kern= xmalloc((max_tfm_int+1),sizeof(mp_number));
for(i= 0;i<(max_tfm_int+1);i++)
new_number(mp->kern[i]);
}
/*1196:*/
#line 33228 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp->lk_started= false;
CONTINUE:
mp_get_x_next(mp);
if((cur_cmd()==mp_skip_to)&&mp->lk_started)
/*1199:*/
#line 33342 "../../../source/texk/web2c/mplibdir/mp.w"

{
c= mp_get_code(mp);
if(mp->nl-mp->skip_table[c]> 128){
skip_error(mp->skip_table[c]);
mp->skip_table[c]= (short)undefined_label;
}
if(mp->skip_table[c]==undefined_label)
skip_byte(mp->nl-1)= qi(0);
else
skip_byte(mp->nl-1)= qi(mp->nl-mp->skip_table[c]-1);
mp->skip_table[c]= (short)(mp->nl-1);
goto DONE;
}


/*:1199*/
#line 33234 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(cur_cmd()==mp_bchar_label){
c= 256;
set_cur_cmd((mp_variable_type)mp_colon);
}else{
mp_back_input(mp);
c= mp_get_code(mp);
};
if((cur_cmd()==mp_colon)||(cur_cmd()==mp_double_colon)){
/*1200:*/
#line 33358 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(cur_cmd()==mp_colon){
if(c==256)
mp->bch_label= mp->nl;
else
mp_set_tag(mp,c,lig_tag,mp->nl);
}else if(mp->skip_table[c]<undefined_label){
mp->ll= mp->skip_table[c];
mp->skip_table[c]= undefined_label;
do{
mp->lll= qo(skip_byte(mp->ll));
if(mp->nl-mp->ll> 128){
skip_error(mp->ll);
goto CONTINUE;
}
skip_byte(mp->ll)= qi(mp->nl-mp->ll-1);
mp->ll= (short)(mp->ll-mp->lll);
}while(mp->lll!=0);
}
goto CONTINUE;
}


/*:1200*/
#line 33243 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
if(cur_cmd()==mp_lig_kern_token){
/*1201:*/
#line 33382 "../../../source/texk/web2c/mplibdir/mp.w"

{
next_char(mp->nl)= qi(c);
skip_byte(mp->nl)= qi(0);
if(cur_mod()<128){
op_byte(mp->nl)= qi(cur_mod());
rem_byte(mp->nl)= qi(mp_get_code(mp));
}else{
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known){
const char*hlp[]= {
"The amount of kern should be a known numeric value.",
"I'm zeroing this one. Proceed, with fingers crossed.",
NULL};
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Improper kern",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
number_clone(mp->kern[mp->nk],cur_exp_value_number());
k= 0;
while(!number_equal(mp->kern[k],cur_exp_value_number()))
incr(k);
if(k==mp->nk){
if(mp->nk==max_tfm_int)
mp_fatal_error(mp,"too many TFM kerns");
mp->nk++;
}
op_byte(mp->nl)= qi(kern_flag+(k/256));
rem_byte(mp->nl)= qi((k%256));
}
mp->lk_started= true;
}


/*:1201*/
#line 33246 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
const char*hlp[]= {"I was looking for `=:' or `kern' here.",NULL};
mp_back_error(mp,"Illegal ligtable step",hlp,true);
;
next_char(mp->nl)= qi(0);
op_byte(mp->nl)= qi(0);
rem_byte(mp->nl)= qi(0);
skip_byte(mp->nl)= stop_flag+1;
}
if(mp->nl==max_tfm_int)
mp_fatal_error(mp,"ligtable too large");
mp->nl++;
if(cur_cmd()==mp_comma)
goto CONTINUE;
if(skip_byte(mp->nl-1)<stop_flag)
skip_byte(mp->nl-1)= stop_flag;
}
DONE:

/*:1196*/
#line 33183 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case extensible_code:
/*1202:*/
#line 33429 "../../../source/texk/web2c/mplibdir/mp.w"

{
if(mp->ne==256)
mp_fatal_error(mp,"too many extensible recipies");
c= mp_get_code(mp);
mp_set_tag(mp,c,ext_tag,mp->ne);
if(cur_cmd()!=mp_colon)
missing_extensible_punctuation(":");
ext_top(mp->ne)= qi(mp_get_code(mp));
if(cur_cmd()!=mp_comma)
missing_extensible_punctuation(",");
ext_mid(mp->ne)= qi(mp_get_code(mp));
if(cur_cmd()!=mp_comma)
missing_extensible_punctuation(",");
ext_bot(mp->ne)= qi(mp_get_code(mp));
if(cur_cmd()!=mp_comma)
missing_extensible_punctuation(",");
ext_rep(mp->ne)= qi(mp_get_code(mp));
mp->ne++;
}


/*:1202*/
#line 33186 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
case header_byte_code:
case font_dimen_code:
c= cur_mod();
mp_get_x_next(mp);
mp_scan_expression(mp);
if((mp->cur_exp.type!=mp_known)||number_less(cur_exp_value_number(),half_unit_t)){
const char*hlp[]= {
"I was looking for a known, positive number.",
"For safety's sake I'll ignore the present command.",
NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Improper location",hlp,true);
;
mp_get_x_next(mp);
}else{
j= round_unscaled(cur_exp_value_number());
if(cur_cmd()!=mp_colon){
const char*hlp[]= {
"A colon should follow a headerbyte or fontinfo location.",
NULL};
mp_back_error(mp,"Missing `:' has been inserted",hlp,true);
;
}
if(c==header_byte_code){
/*1203:*/
#line 33456 "../../../source/texk/web2c/mplibdir/mp.w"

j--;
if(mp->header_last<j){
mp->header_last= j;
}
do{
if(j>=mp->header_size){
size_t l= (size_t)(mp->header_size+(mp->header_size/4));
char*t= xmalloc(l,1);
memset(t,0,l);
(void)memcpy(t,mp->header_byte,(size_t)mp->header_size);
xfree(mp->header_byte);
mp->header_byte= t;
mp->header_size= (int)l;
}
mp->header_byte[j]= (char)mp_get_code(mp);
if(mp->header_last<j){
incr(mp->header_last);
}
incr(j);
}while(cur_cmd()==mp_comma)

/*:1203*/
#line 33212 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
if(mp->param==NULL){
int i;
mp->param= xmalloc((max_tfm_int+1),sizeof(mp_number));
for(i= 0;i<(max_tfm_int+1);i++)
new_number(mp->param[i]);
}
/*1204:*/
#line 33478 "../../../source/texk/web2c/mplibdir/mp.w"

do{
if(j> max_tfm_int)
mp_fatal_error(mp,"too many fontdimens");
while(j> mp->np){
mp->np++;
set_number_to_zero(mp->param[mp->np]);
};
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known){
const char*hlp[]= {"I'm zeroing this one. Proceed, with fingers crossed.",NULL};
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Improper font parameter",hlp,true);
;
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
number_clone(mp->param[j],cur_exp_value_number());
incr(j);
}while(cur_cmd()==mp_comma)

/*:1204*/
#line 33220 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
}
break;
}
}


/*:1195*//*1207:*/
#line 33539 "../../../source/texk/web2c/mplibdir/mp.w"

static mp_node mp_sort_in(MP mp,mp_number v){
mp_node p,q,r;
p= mp->temp_head;
while(1){
q= mp_link(p);
if(number_lessequal(v,value_number(q)))
break;
p= q;
}
if(number_less(v,value_number(q))){
r= mp_get_value_node(mp);
set_value_number(r,v);
mp_link(r)= q;
mp_link(p)= r;
}
return mp_link(p);
}


/*:1207*//*1208:*/
#line 33570 "../../../source/texk/web2c/mplibdir/mp.w"

static integer mp_min_cover(MP mp,mp_number d){
mp_node p;
mp_number l;
mp_number test;
integer m;
m= 0;
new_number(l);
new_number(test);
p= mp_link(mp->temp_head);
set_number_to_inf(mp->perturbation);
while(p!=mp->inf_val){
incr(m);
number_clone(l,value_number(p));
do{
p= mp_link(p);
set_number_from_addition(test,l,d);
}while(number_lessequal(value_number(p),test));

set_number_from_substraction(test,value_number(p),l);
if(number_less(test,mp->perturbation)){
number_clone(mp->perturbation,test);
}
}
free_number(test);
free_number(l);
return m;
}


/*:1208*//*1212:*/
#line 33616 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_threshold(MP mp,mp_number*ret,integer m){
mp_number d,arg1;
new_number(d);
new_number(arg1);
mp->excess= mp_min_cover(mp,zero_t)-m;
if(mp->excess<=0){
number_clone(*ret,zero_t);
}else{
do{
number_clone(d,mp->perturbation);
set_number_from_addition(arg1,d,d);
}while(mp_min_cover(mp,arg1)> m);
while(mp_min_cover(mp,d)> m){
number_clone(d,mp->perturbation);
}
number_clone(*ret,d);
}
free_number(d);
free_number(arg1);
}


/*:1212*//*1213:*/
#line 33646 "../../../source/texk/web2c/mplibdir/mp.w"

static integer mp_skimp(MP mp,integer m){
mp_number d;
mp_node p,q,r;
mp_number l;
mp_number v;
mp_number l_d;
new_number(d);
mp_threshold(mp,&d,m);
new_number(l);
new_number(l_d);
new_number(v);
set_number_to_zero(mp->perturbation);
q= mp->temp_head;
m= 0;
p= mp_link(mp->temp_head);
while(p!=mp->inf_val){
incr(m);
number_clone(l,value_number(p));
set_indep_value(p,m);
set_number_from_addition(l_d,l,d);
if(number_lessequal(value_number(mp_link(p)),l_d)){
/*1214:*/
#line 33681 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_number test;
new_number(test);
do{
p= mp_link(p);
set_indep_value(p,m);
decr(mp->excess);
if(mp->excess==0){
number_clone(l_d,l);
set_number_to_zero(d);
}
}while(number_lessequal(value_number(mp_link(p)),l_d));
set_number_from_substraction(test,value_number(p),l);
number_halfp(test);
set_number_from_addition(v,l,test);
set_number_from_substraction(test,value_number(p),v);
if(number_greater(test,mp->perturbation))
number_clone(mp->perturbation,test);
r= q;
do{
r= mp_link(r);
set_value_number(r,v);
}while(r!=p);
mp_link(q)= p;
free_number(test);
}


/*:1214*/
#line 33668 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
q= p;
p= mp_link(p);
}
free_number(l_d);
free_number(d);
free_number(l);
free_number(v);
return m;
}


/*:1213*//*1215:*/
#line 33713 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_tfm_warning(MP mp,quarterword m){
mp_print_nl(mp,"(some ");
mp_print(mp,internal_name(m));



;
mp_print(mp," values had to be adjusted by as much as ");
print_number(mp->perturbation);
mp_print(mp,"pt)");
}


/*:1215*//*1221:*/
#line 33819 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fix_design_size(MP mp){
mp_number d;
new_number(d);
number_clone(d,internal_value(mp_design_size));
if(number_less(d,unity_t)||number_greaterequal(d,fraction_half_t)){
if(!number_zero(d))
mp_print_nl(mp,"(illegal design size has been changed to 128pt)");
;
set_number_from_scaled(d,040000000);
number_clone(internal_value(mp_design_size),d);
}
if(mp->header_byte[4]==0&&mp->header_byte[5]==0&&
mp->header_byte[6]==0&&mp->header_byte[7]==0){
integer dd= number_to_scaled(d);
mp->header_byte[4]= (char)(dd/04000000);
mp->header_byte[5]= (char)((dd/4096)%256);
mp->header_byte[6]= (char)((dd/16)%256);
mp->header_byte[7]= (char)((dd%16)*16);
}

{
mp_number secondpart;
new_number(secondpart);
number_clone(secondpart,internal_value(mp_design_size));
number_clone(mp->max_tfm_dimen,secondpart);
number_divide_int(secondpart,010000000);
number_multiply_int(mp->max_tfm_dimen,16);
number_add_scaled(mp->max_tfm_dimen,-1);
number_substract(mp->max_tfm_dimen,secondpart);
free_number(secondpart);
}
if(number_greaterequal(mp->max_tfm_dimen,fraction_half_t)){
number_clone(mp->max_tfm_dimen,fraction_half_t);
number_add_scaled(mp->max_tfm_dimen,-1);
}
free_number(d);
}


/*:1221*//*1222:*/
#line 33863 "../../../source/texk/web2c/mplibdir/mp.w"

static integer mp_dimen_out(MP mp,mp_number x_orig){
integer ret;
mp_number abs_x;
mp_number x;
new_number(abs_x);
new_number(x);
number_clone(x,x_orig);
number_clone(abs_x,x_orig);
number_abs(abs_x);
if(number_greater(abs_x,mp->max_tfm_dimen)){
incr(mp->tfm_changed);
if(number_positive(x))
number_clone(x,mp->max_tfm_dimen);
else{
number_clone(x,mp->max_tfm_dimen);
number_negate(x);
}
}
{
mp_number arg1;
new_number(arg1);
number_clone(arg1,x);
number_multiply_int(arg1,16);
make_scaled(x,arg1,internal_value(mp_design_size));
free_number(arg1);
}
free_number(abs_x);
ret= number_to_scaled(x);
free_number(x);
return ret;
}


/*:1222*//*1226:*/
#line 33913 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_fix_check_sum(MP mp){
eight_bits k;
eight_bits B1,B2,B3,B4;
integer x;
if(mp->header_byte[0]==0&&mp->header_byte[1]==0&&
mp->header_byte[2]==0&&mp->header_byte[3]==0){
/*1227:*/
#line 33930 "../../../source/texk/web2c/mplibdir/mp.w"

B1= mp->bc;
B2= mp->ec;
B3= mp->bc;
B4= mp->ec;
mp->tfm_changed= 0;
for(k= mp->bc;k<=mp->ec;k++){
if(mp->char_exists[k]){
x= mp_dimen_out(mp,value_number(mp->tfm_width[k]))+(k+4)*020000000;
B1= (eight_bits)((B1+B1+x)%255);
B2= (eight_bits)((B2+B2+x)%253);
B3= (eight_bits)((B3+B3+x)%251);
B4= (eight_bits)((B4+B4+x)%247);
}
if(k==mp->ec)
break;
}


/*:1227*/
#line 33920 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp->header_byte[0]= (char)B1;
mp->header_byte[1]= (char)B2;
mp->header_byte[2]= (char)B3;
mp->header_byte[3]= (char)B4;
return;
}
}


/*:1226*//*1228:*/
#line 33957 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_tfm_two(MP mp,integer x){
tfm_out(x/256);
tfm_out(x%256);
}
static void mp_tfm_four(MP mp,integer x){
if(x>=0)
tfm_out(x/three_bytes);
else{
x= x+010000000000;
x= x+010000000000;
tfm_out((x/three_bytes)+128);
};
x= x%three_bytes;
tfm_out(x/number_to_scaled(unity_t));
x= x%number_to_scaled(unity_t);
tfm_out(x/0400);
tfm_out(x%0400);
}
static void mp_tfm_qqqq(MP mp,four_quarters x){
tfm_out(qo(x.b0));
tfm_out(qo(x.b1));
tfm_out(qo(x.b2));
tfm_out(qo(x.b3));
}


/*:1228*//*1242:*/
#line 34281 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_reallocate_fonts(MP mp,font_number l){
font_number f;
XREALLOC(mp->font_enc_name,l,char*);
XREALLOC(mp->font_ps_name_fixed,l,boolean);
XREALLOC(mp->font_dsize,l,integer);
XREALLOC(mp->font_name,l,char*);
XREALLOC(mp->font_ps_name,l,char*);
XREALLOC(mp->font_bc,l,eight_bits);
XREALLOC(mp->font_ec,l,eight_bits);
XREALLOC(mp->char_base,l,int);
XREALLOC(mp->width_base,l,int);
XREALLOC(mp->height_base,l,int);
XREALLOC(mp->depth_base,l,int);
XREALLOC(mp->font_sizes,l,mp_node);
for(f= (mp->last_fnum+1);f<=l;f++){
mp->font_enc_name[f]= NULL;
mp->font_ps_name_fixed[f]= false;
mp->font_name[f]= NULL;
mp->font_ps_name[f]= NULL;
mp->font_sizes[f]= NULL;
}
mp->font_max= l;
}


/*:1242*//*1247:*/
#line 34363 "../../../source/texk/web2c/mplibdir/mp.w"

font_number mp_find_font(MP mp,char*f){
font_number n;
for(n= 0;n<=mp->last_fnum;n++){
if(mp_xstrcmp(f,mp->font_name[n])==0){
return n;
}
}
n= mp_read_font_info(mp,f);
return n;
}


/*:1247*//*1248:*/
#line 34379 "../../../source/texk/web2c/mplibdir/mp.w"

double mp_get_char_dimension(MP mp,char*fname,int c,int t){
unsigned n;
four_quarters cc;
font_number f= 0;
double w= -1.0;
for(n= 0;n<=mp->last_fnum;n++){
if(mp_xstrcmp(fname,mp->font_name[n])==0){
f= n;
break;
}
}
if(f==0)
return 0.0;
cc= char_mp_info(f,c);
if(!ichar_exists(cc))
return 0.0;
if(t=='w')
w= (double)char_width(f,cc);
else if(t=='h')
w= (double)char_height(f,cc);
else if(t=='d')
w= (double)char_depth(f,cc);
return w/655.35*(72.27/72);
}


/*:1248*//*1251:*/
#line 34417 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_lost_warning(MP mp,font_number f,int k){
if(number_positive(internal_value(mp_tracing_lost_chars))){
mp_begin_diagnostic(mp);
if(mp->selector==log_only)
incr(mp->selector);
mp_print_nl(mp,"Missing character: There is no ");
;
mp_print_int(mp,k);
mp_print(mp," in font ");
mp_print(mp,mp->font_name[f]);
mp_print_char(mp,xord('!'));
mp_end_diagnostic(mp,false);
}
}


/*:1251*//*1253:*/
#line 34441 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_set_text_box(MP mp,mp_text_node p){
font_number f;
ASCII_code bc,ec;
size_t k,kk;
four_quarters cc;
mp_number h,d;
new_number(h);
new_number(d);
set_number_to_zero(p->width);
set_number_to_neg_inf(p->height);
set_number_to_neg_inf(p->depth);
f= (font_number)mp_font_n(p);
bc= mp->font_bc[f];
ec= mp->font_ec[f];
kk= mp_text_p(p)->len;
k= 0;
while(k<kk){
/*1254:*/
#line 34467 "../../../source/texk/web2c/mplibdir/mp.w"

{
if((*(mp_text_p(p)->str+k)<bc)||(*(mp_text_p(p)->str+k)> ec)){
mp_lost_warning(mp,f,*(mp_text_p(p)->str+k));
}else{
cc= char_mp_info(f,*(mp_text_p(p)->str+k));
if(!ichar_exists(cc)){
mp_lost_warning(mp,f,*(mp_text_p(p)->str+k));
}else{
set_number_from_scaled(p->width,number_to_scaled(p->width)+char_width(f,cc));
set_number_from_scaled(h,char_height(f,cc));
set_number_from_scaled(d,char_depth(f,cc));
if(number_greater(h,p->height))
number_clone(p->height,h);
if(number_greater(d,p->depth))
number_clone(p->depth,d);
}
}
incr(k);
}


/*:1254*/
#line 34459 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
/*1255:*/
#line 34492 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_to_scaled(p->height)<-number_to_scaled(p->depth)){
set_number_to_zero(p->height);
set_number_to_zero(p->depth);
}

/*:1255*/
#line 34461 "../../../source/texk/web2c/mplibdir/mp.w"
;
free_number(h);
free_number(d);
}


/*:1253*//*1257:*/
#line 34504 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_do_mapfile(MP mp){
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_string_type){
/*1258:*/
#line 34525 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {"Only known strings can be map files or map lines.",NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Unsuitable expression",hlp,true);
mp_get_x_next(mp);
}


/*:1258*/
#line 34509 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp_map_file(mp,cur_exp_str());
}
}
static void mp_do_mapline(MP mp){
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_string_type){
/*1258:*/
#line 34525 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {"Only known strings can be map files or map lines.",NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Unsuitable expression",hlp,true);
mp_get_x_next(mp);
}


/*:1258*/
#line 34518 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp_map_line(mp,cur_exp_str());
}
}


/*:1257*//*1263:*/
#line 34568 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_append_to_template(MP mp,integer ff,integer c,boolean rounding){
if(internal_type(c)==mp_string_type){
char*ss= mp_str(mp,internal_string(c));
mp_print(mp,ss);
}else if(internal_type(c)==mp_known){
if(rounding){
int cc= round_unscaled(internal_value(c));
print_with_leading_zeroes(cc,ff);
}else{
print_number(internal_value(c));
}
}
}
char*mp_set_output_file_name(MP mp,integer c){
char*ss= NULL;
char*nn= NULL;
unsigned old_setting;
size_t i;
integer f;
str_room(1024);
if(mp->job_name==NULL)
mp_open_log_file(mp);
if(internal_string(mp_output_template)==NULL){
char*s;
if(c<0)
s= xstrdup(".ps");
else
/*1264:*/
#line 34775 "../../../source/texk/web2c/mplibdir/mp.w"

{
s= xmalloc(12,1);
mp_snprintf(s,12,".%i",(int)c);
s[7]= '\0';
}


/*:1264*/
#line 34596 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_pack_job_name(mp,s);
free(s);
ss= xstrdup(mp->name_of_file);
}else{
mp_string s,n,ftemplate;
mp_number saved_char_code;
new_number(saved_char_code);
number_clone(saved_char_code,internal_value(mp_char_code));
set_internal_from_number(mp_char_code,unity_t);
number_multiply_int(internal_value(mp_char_code),c);
if(internal_string(mp_job_name)==NULL){
if(mp->job_name==NULL){
mp->job_name= xstrdup("mpout");
}
/*880:*/
#line 21913 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->job_name!=NULL){
if(internal_string(mp_job_name)!=0)
delete_str_ref(internal_string(mp_job_name));
set_internal_string(mp_job_name,mp_rts(mp,mp->job_name));
}

/*:880*/
#line 34611 "../../../source/texk/web2c/mplibdir/mp.w"
;
}
old_setting= mp->selector;
mp->selector= new_string;
i= 0;
n= mp_rts(mp,"");
ftemplate= internal_string(mp_output_template);
while(i<ftemplate->len){
f= 0;
if(*(ftemplate->str+i)=='%'){
CONTINUE:
incr(i);
if(i<ftemplate->len){
switch(*(ftemplate->str+i)){
case'j':
mp_append_to_template(mp,f,mp_job_name,true);
break;
case'c':
if(number_negative(internal_value(mp_char_code))){
mp_print(mp,"ps");
}else{
mp_append_to_template(mp,f,mp_char_code,true);
}
break;
case'o':
mp_append_to_template(mp,f,mp_output_format,true);
break;
case'd':
mp_append_to_template(mp,f,mp_day,true);
break;
case'm':
mp_append_to_template(mp,f,mp_month,true);
break;
case'y':
mp_append_to_template(mp,f,mp_year,true);
break;
case'H':
mp_append_to_template(mp,f,mp_hour,true);
break;
case'M':
mp_append_to_template(mp,f,mp_minute,true);
break;
case'{':
{

size_t l= 0;
size_t frst= i+1;
while(i<ftemplate->len){
i++;
if(*(ftemplate->str+i)=='}')
break;
l++;
}
if(l> 0){
mp_sym p=
mp_id_lookup(mp,(char*)(ftemplate->str+frst),l,false);
char*id= xmalloc((l+1),1);
(void)memcpy(id,(char*)(ftemplate->str+frst),(size_t)l);
*(id+l)= '\0';
if(p==NULL){
char err[256];
mp_snprintf(err,256,
"requested identifier (%s) in outputtemplate not found.",
id);
mp_warn(mp,err);
}else{
if(eq_type(p)==mp_internal_quantity){
if(equiv(p)==mp_output_template){
char err[256];
mp_snprintf(err,256,
"The appearance of outputtemplate inside outputtemplate is ignored.");
mp_warn(mp,err);
}else{
mp_append_to_template(mp,f,equiv(p),false);
}
}else{
char err[256];
mp_snprintf(err,256,
"requested identifier (%s) in outputtemplate is not an internal.",
id);
mp_warn(mp,err);
}
}
free(id);
}
}
break;
case'0':
case'1':
case'2':
case'3':
case'4':
case'5':
case'6':
case'7':
case'8':
case'9':
if((f<10))
f= (f*10)+ftemplate->str[i]-'0';
goto CONTINUE;
break;
case'%':
mp_print_char(mp,'%');
break;
default:
{
char err[256];
mp_snprintf(err,256,
"requested format (%c) in outputtemplate is unknown.",
*(ftemplate->str+i));
mp_warn(mp,err);
}
mp_print_char(mp,*(ftemplate->str+i));
}
}
}else{
if(*(ftemplate->str+i)=='.')
if(n->len==0)
n= mp_make_string(mp);
mp_print_char(mp,*(ftemplate->str+i));
};
incr(i);
}
s= mp_make_string(mp);
number_clone(internal_value(mp_char_code),saved_char_code);
free_number(saved_char_code);
mp->selector= old_setting;
if(n->len==0){
n= s;
s= mp_rts(mp,"");
}
ss= mp_str(mp,s);
nn= mp_str(mp,n);
mp_pack_file_name(mp,nn,"",ss);
delete_str_ref(n);
delete_str_ref(s);
}
return ss;
}
char*mp_get_output_file_name(MP mp){
char*f;
char*saved_name;
saved_name= xstrdup(mp->name_of_file);
(void)mp_set_output_file_name(mp,round_unscaled(internal_value(mp_char_code)));
f= xstrdup(mp->name_of_file);
mp_pack_file_name(mp,saved_name,NULL,NULL);
free(saved_name);
return f;
}
void mp_open_output_file(MP mp){
char*ss;
int c;
c= round_unscaled(internal_value(mp_char_code));
ss= mp_set_output_file_name(mp,c);
while(!mp_open_out(mp,(void*)&mp->output_file,mp_filetype_postscript))
mp_prompt_file_name(mp,"file name for output",ss);
mp_store_true_output_filename(mp,c);
}


/*:1263*//*1266:*/
#line 34792 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_store_true_output_filename(MP mp,int c)
{
if((c<mp->first_output_code)&&(mp->first_output_code>=0)){
mp->first_output_code= c;
xfree(mp->first_file_name);
mp->first_file_name= xstrdup(mp->name_of_file);
}
if(c>=mp->last_output_code){
mp->last_output_code= c;
xfree(mp->last_file_name);
mp->last_file_name= xstrdup(mp->name_of_file);
}
set_internal_string(mp_output_filename,mp_rts(mp,mp->name_of_file));
}

/*:1266*//*1274:*/
#line 34872 "../../../source/texk/web2c/mplibdir/mp.w"

boolean mp_has_font_size(MP mp,font_number f){
return(mp->font_sizes[f]!=NULL);
}


/*:1274*//*1277:*/
#line 34888 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_do_special(MP mp){
mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_string_type){
/*1278:*/
#line 34902 "../../../source/texk/web2c/mplibdir/mp.w"

{
const char*hlp[]= {"Only known strings are allowed for output as specials.",NULL};
mp_disp_err(mp,NULL);
mp_back_error(mp,"Unsuitable expression",hlp,true);
mp_get_x_next(mp);
}


/*:1278*/
#line 34893 "../../../source/texk/web2c/mplibdir/mp.w"
;
}else{
mp_link(mp->last_pending)= mp_stash_cur_exp(mp);
mp->last_pending= mp_link(mp->last_pending);
mp_link(mp->last_pending)= NULL;
}
}


/*:1277*//*1282:*/
#line 34960 "../../../source/texk/web2c/mplibdir/mp.w"

struct mp_edge_object*mp_gr_export(MP mp,mp_edge_header_node h){
mp_node p;
integer t;
integer c;
mp_number d_width;
mp_edge_object*hh;
mp_graphic_object*hq;
mp_text_object*tt;
mp_fill_object*tf;
mp_stroked_object*ts;
mp_clip_object*tc;
mp_bounds_object*tb;
mp_graphic_object*hp= NULL;
mp_set_bbox(mp,h,true);
hh= xmalloc(1,sizeof(mp_edge_object));
hh->body= NULL;
hh->next= NULL;
hh->parent= mp;
hh->minx= number_to_double(h->minx);
hh->minx= (fabs(hh->minx)<0.00001?0:hh->minx);
hh->miny= number_to_double(h->miny);
hh->miny= (fabs(hh->miny)<0.00001?0:hh->miny);
hh->maxx= number_to_double(h->maxx);
hh->maxx= (fabs(hh->maxx)<0.00001?0:hh->maxx);
hh->maxy= number_to_double(h->maxy);
hh->maxy= (fabs(hh->maxy)<0.00001?0:hh->maxy);
hh->filename= mp_get_output_file_name(mp);
c= round_unscaled(internal_value(mp_char_code));
hh->charcode= c;
hh->width= number_to_double(internal_value(mp_char_wd));
hh->height= number_to_double(internal_value(mp_char_ht));
hh->depth= number_to_double(internal_value(mp_char_dp));
hh->ital_corr= number_to_double(internal_value(mp_char_ic));
/*1280:*/
#line 34916 "../../../source/texk/web2c/mplibdir/mp.w"

p= mp_link(mp->spec_head);
while(p!=NULL){
mp_special_object*tp;
tp= (mp_special_object*)mp_new_graphic_object(mp,mp_special_code);
gr_pre_script(tp)= mp_xstrdup(mp,mp_str(mp,value_str(p)));
if(hh->body==NULL)
hh->body= (mp_graphic_object*)tp;
else
gr_link(hp)= (mp_graphic_object*)tp;
hp= (mp_graphic_object*)tp;
p= mp_link(p);
}
mp_flush_token_list(mp,mp_link(mp->spec_head));
mp_link(mp->spec_head)= NULL;
mp->last_pending= mp->spec_head

/*:1280*/
#line 34994 "../../../source/texk/web2c/mplibdir/mp.w"
;
p= mp_link(edge_list(h));
while(p!=NULL){
hq= mp_new_graphic_object(mp,(int)((mp_type(p)-mp_fill_node_type)+1));
switch(mp_type(p)){
case mp_fill_node_type:
{
mp_fill_node p0= (mp_fill_node)p;
tf= (mp_fill_object*)hq;
gr_pen_p(tf)= mp_export_knot_list(mp,mp_pen_p(p0));
new_number(d_width);
mp_get_pen_scale(mp,&d_width,mp_pen_p(p0));
free_number(d_width);
if((mp_pen_p(p0)==NULL)||pen_is_elliptical(mp_pen_p(p0))){
gr_path_p(tf)= mp_export_knot_list(mp,mp_path_p(p0));
}else{
mp_knot pc,pp;
pc= mp_copy_path(mp,mp_path_p(p0));
pp= mp_make_envelope(mp,pc,mp_pen_p(p0),p0->ljoin,0,p0->miterlim);
gr_path_p(tf)= mp_export_knot_list(mp,pp);
mp_toss_knot_list(mp,pp);
pc= mp_htap_ypoc(mp,mp_path_p(p0));
pp= mp_make_envelope(mp,pc,mp_pen_p((mp_fill_node)p),p0->ljoin,0,p0->miterlim);
gr_htap_p(tf)= mp_export_knot_list(mp,pp);
mp_toss_knot_list(mp,pp);
}
export_color(tf,p0);
export_scripts(tf,p);
gr_ljoin_val(tf)= p0->ljoin;
gr_miterlim_val(tf)= number_to_double(p0->miterlim);
}
break;
case mp_stroked_node_type:
{
mp_stroked_node p0= (mp_stroked_node)p;
ts= (mp_stroked_object*)hq;
gr_pen_p(ts)= mp_export_knot_list(mp,mp_pen_p(p0));
new_number(d_width);
mp_get_pen_scale(mp,&d_width,mp_pen_p(p0));
if(pen_is_elliptical(mp_pen_p(p0))){
gr_path_p(ts)= mp_export_knot_list(mp,mp_path_p(p0));
}else{
mp_knot pc;
pc= mp_copy_path(mp,mp_path_p(p0));
t= p0->lcap;
if(mp_left_type(pc)!=mp_endpoint){
mp_left_type(mp_insert_knot(mp,pc,pc->x_coord,pc->y_coord))= mp_endpoint;
mp_right_type(pc)= mp_endpoint;
pc= mp_next_knot(pc);
t= 1;
}
pc=
mp_make_envelope(mp,pc,mp_pen_p(p0),
p0->ljoin,(quarterword)t,
p0->miterlim);
gr_path_p(ts)= mp_export_knot_list(mp,pc);
mp_toss_knot_list(mp,pc);
}
export_color(ts,p0);
export_scripts(ts,p);
gr_ljoin_val(ts)= p0->ljoin;
gr_miterlim_val(ts)= number_to_double(p0->miterlim);
gr_lcap_val(ts)= p0->lcap;
gr_dash_p(ts)= mp_export_dashes(mp,p0,d_width);
free_number(d_width);
}
break;
case mp_text_node_type:
{
mp_text_node p0= (mp_text_node)p;
tt= (mp_text_object*)hq;
gr_text_p(tt)= mp_xstrldup(mp,mp_str(mp,mp_text_p(p)),mp_text_p(p)->len);
gr_text_l(tt)= (size_t)mp_text_p(p)->len;
gr_font_n(tt)= (unsigned int)mp_font_n(p);
gr_font_name(tt)= mp_xstrdup(mp,mp->font_name[mp_font_n(p)]);
gr_font_dsize(tt)= mp->font_dsize[mp_font_n(p)]/65536.0;
export_color(tt,p0);
export_scripts(tt,p);
gr_width_val(tt)= number_to_double(p0->width);
gr_height_val(tt)= number_to_double(p0->height);
gr_depth_val(tt)= number_to_double(p0->depth);
gr_tx_val(tt)= number_to_double(p0->tx);
gr_ty_val(tt)= number_to_double(p0->ty);
gr_txx_val(tt)= number_to_double(p0->txx);
gr_txy_val(tt)= number_to_double(p0->txy);
gr_tyx_val(tt)= number_to_double(p0->tyx);
gr_tyy_val(tt)= number_to_double(p0->tyy);
}
break;
case mp_start_clip_node_type:
tc= (mp_clip_object*)hq;
gr_path_p(tc)=
mp_export_knot_list(mp,mp_path_p((mp_start_clip_node)p));
break;
case mp_start_bounds_node_type:
tb= (mp_bounds_object*)hq;
gr_path_p(tb)=
mp_export_knot_list(mp,mp_path_p((mp_start_bounds_node)p));
break;
case mp_stop_clip_node_type:
case mp_stop_bounds_node_type:

break;
default:
break;
}
if(hh->body==NULL)
hh->body= hq;
else
gr_link(hp)= hq;
hp= hq;
p= mp_link(p);
}
return hh;
}


/*:1282*//*1283:*/
#line 35115 "../../../source/texk/web2c/mplibdir/mp.w"

mp_edge_header_node mp_gr_import(MP mp,struct mp_edge_object*hh){
mp_edge_header_node h;
mp_node ph,pn,pt;
mp_graphic_object*p;
h= mp_get_edge_header_node(mp);
mp_init_edges(mp,h);
ph= edge_list(h);
pt= ph;
p= hh->body;
set_number_from_double(h->minx,hh->minx);
set_number_from_double(h->miny,hh->miny);
set_number_from_double(h->maxx,hh->maxx);
set_number_from_double(h->maxy,hh->maxy);
while(p!=NULL){
switch(gr_type(p)){
case mp_fill_code:
if(gr_pen_p((mp_fill_object*)p)==NULL){
mp_number turns;
new_number(turns);
pn= mp_new_fill_node(mp,NULL);
mp_path_p((mp_fill_node)pn)=
mp_import_knot_list(mp,gr_path_p((mp_fill_object*)p));
mp_color_model(pn)= mp_grey_model;
mp_turn_cycles(mp,&turns,mp_path_p((mp_fill_node)pn));
if(number_negative(turns)){
set_number_to_unity(((mp_fill_node)pn)->grey);
mp_link(pt)= pn;
pt= mp_link(pt);
}else{
set_number_to_zero(((mp_fill_node)pn)->grey);
mp_link(pn)= mp_link(ph);
mp_link(ph)= pn;
if(ph==pt)
pt= pn;
}
free_number(turns);
}
break;
case mp_stroked_code:
case mp_text_code:
case mp_start_clip_code:
case mp_stop_clip_code:
case mp_start_bounds_code:
case mp_stop_bounds_code:
case mp_special_code:
break;
}
p= p->next;
}
mp_gr_toss_objects(hh);
return h;
}


/*:1283*//*1285:*/
#line 35176 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_ship_out(MP mp,mp_node h){
int c;
c= round_unscaled(internal_value(mp_char_code));
/*1270:*/
#line 34827 "../../../source/texk/web2c/mplibdir/mp.w"

if((int)mp->term_offset> mp->max_print_line-6)
mp_print_ln(mp);
else if((mp->term_offset> 0)||(mp->file_offset> 0))
mp_print_char(mp,xord(' '));
mp_print_char(mp,xord('['));
if(c>=0)
mp_print_int(mp,c)


/*:1270*/
#line 35180 "../../../source/texk/web2c/mplibdir/mp.w"
;
(mp->shipout_backend)(mp,h);
/*1271:*/
#line 34837 "../../../source/texk/web2c/mplibdir/mp.w"

mp_print_char(mp,xord(']'));
update_terminal();
incr(mp->total_shipped)


/*:1271*/
#line 35182 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(number_positive(internal_value(mp_tracing_output)))
mp_print_edges(mp,h," (just shipped out)",true);
}


/*:1285*//*1287:*/
#line 35192 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_shipout_backend(MP mp,void*voidh){
char*s;
mp_edge_object*hh;
mp_edge_header_node h= (mp_edge_header_node)voidh;
hh= mp_gr_export(mp,h);
s= NULL;
if(internal_string(mp_output_format)!=NULL)
s= mp_str(mp,internal_string(mp_output_format));
if(s&&strcmp(s,"svg")==0){
(void)mp_svg_gr_ship_out(hh,
(number_to_scaled(internal_value(mp_prologues))/65536),false);
}else if(s&&strcmp(s,"png")==0){
(void)mp_png_gr_ship_out(hh,(const char*)((internal_string(mp_output_format_options))->str),false);
}else{
(void)mp_gr_ship_out(hh,
(number_to_scaled(internal_value(mp_prologues))/65536),
(number_to_scaled(internal_value(mp_procset))/65536),false);
}
mp_gr_toss_objects(hh);
}


/*:1287*//*1296:*/
#line 35262 "../../../source/texk/web2c/mplibdir/mp.w"

boolean mp_load_preload_file(MP mp){
size_t k;
in_state_record old_state;
integer old_in_open= mp->in_open;
void*old_cur_file= cur_file;
char*fname= xstrdup(mp->name_of_file);
size_t l= strlen(fname);
old_state= mp->cur_input;
str_room(l);
for(k= 0;k<l;k++){
append_char(*(fname+k));
}
name= mp_make_string(mp);
if(!mp->log_opened){
mp_open_log_file(mp);
}

if(((int)mp->term_offset+(int)strlen(fname))> (mp->max_print_line-2))
mp_print_ln(mp);
else if((mp->term_offset> 0)||(mp->file_offset> 0))
mp_print_char(mp,xord(' '));
mp_print_char(mp,xord('('));
incr(mp->open_parens);
mp_print(mp,fname);
update_terminal();
{
line= 1;
start= loc= limit+(mp->noninteractive?0:1);
cur_file= mp->mem_file;
(void)mp_input_ln(mp,cur_file);
mp_firm_up_the_line(mp);
mp->buffer[limit]= xord('%');
mp->first= (size_t)(limit+1);
loc= start;
}
mp->reading_preload= true;
do{
mp_do_statement(mp);
}while(!(cur_cmd()==mp_stop));
mp->reading_preload= false;
mp_primitive(mp,"dump",mp_relax,0);
while(mp->input_ptr> 0){
if(token_state)
mp_end_token_list(mp);
else
mp_end_file_reading(mp);
}
while(mp->loop_ptr!=NULL)
mp_stop_iteration(mp);
while(mp->open_parens> 0){
mp_print(mp," )");
decr(mp->open_parens);
};
while(mp->cond_ptr!=NULL){
mp_print_nl(mp,"(dump occurred when ");
;
mp_print_cmd_mod(mp,mp_fi_or_else,mp->cur_if);

if(mp->if_line!=0){
mp_print(mp," on line ");
mp_print_int(mp,mp->if_line);
}
mp_print(mp," was incomplete)");
mp->if_line= if_line_field(mp->cond_ptr);
mp->cur_if= mp_name_type(mp->cond_ptr);
mp->cond_ptr= mp_link(mp->cond_ptr);
}


cur_file= old_cur_file;
mp->cur_input= old_state;
mp->in_open= old_in_open;
return true;
}


/*:1296*//*1297:*/
#line 35347 "../../../source/texk/web2c/mplibdir/mp.w"

/*943:*/
#line 23445 "../../../source/texk/web2c/mplibdir/mp.w"

static void check_for_mediation(MP mp);
void mp_scan_primary(MP mp){
mp_command_code my_var_flag;
my_var_flag= mp->var_flag;
mp->var_flag= 0;
RESTART:
check_arith();

if(mp->interrupt!=0){
if(mp->OK_to_interrupt){
mp_back_input(mp);
check_interrupt;
mp_get_x_next(mp);
}
}
switch(cur_cmd()){
case mp_left_delimiter:
{

mp_node p,q,r;
mp_sym l_delim,r_delim;
l_delim= cur_sym();
r_delim= equiv_sym(cur_sym());
mp_get_x_next(mp);
mp_scan_expression(mp);
if((cur_cmd()==mp_comma)&&(mp->cur_exp.type>=mp_known)){



p= mp_stash_cur_exp(mp);
mp_get_x_next(mp);
mp_scan_expression(mp);

if(mp->cur_exp.type<mp_known){
const char*hlp[]= {
"I've started to scan a pair `(a,b)' or a color `(a,b,c)';",
"but after finding a nice `a' I found a `b' that isn't",
"of numeric type. So I've changed that part to zero.",
"(The b that I didn't like appears above the error message.)",
NULL};
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
mp_disp_err(mp,NULL);
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Nonnumeric ypart has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}

q= mp_get_value_node(mp);
mp_name_type(q)= mp_capsule;
if(cur_cmd()==mp_comma){
mp_init_color_node(mp,q);
r= value_node(q);
mp_stash_in(mp,y_part(r));
mp_unstash_cur_exp(mp,p);
mp_stash_in(mp,x_part(r));

mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type<mp_known){
mp_value new_expr;
const char*hlp[]= {
"I've just scanned a color `(a,b,c)' or cmykcolor(a,b,c,d); but the `c'",
"isn't of numeric type. So I've changed that part to zero.",
"(The c that I didn't like appears above the error message.)",
NULL};
memset(&new_expr,0,sizeof(mp_value));
mp_disp_err(mp,NULL);
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Nonnumeric third part has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
mp_stash_in(mp,blue_part(r));

if(cur_cmd()==mp_comma){
mp_node t;
mp_init_cmykcolor_node(mp,q);
t= value_node(q);
mp_type(cyan_part(t))= mp_type(red_part(r));
set_value_number(cyan_part(t),value_number(red_part(r)));
mp_type(magenta_part(t))= mp_type(green_part(r));
set_value_number(magenta_part(t),value_number(green_part(r)));
mp_type(yellow_part(t))= mp_type(blue_part(r));
set_value_number(yellow_part(t),value_number(blue_part(r)));

if(((mp_type(cyan_part(t)))!=mp_independent)&&((mp_type(cyan_part(t)))!=mp_known)){

set_dep_list(cyan_part(t),dep_list((mp_value_node)red_part(r)));
set_prev_dep(cyan_part(t),prev_dep((mp_value_node)red_part(r)));
set_mp_link(prev_dep(cyan_part(t)),(mp_node)cyan_part(t));
}
if(((mp_type(magenta_part(t)))!=mp_independent)&&((mp_type(magenta_part(t)))!=mp_known)){

set_dep_list(magenta_part(t),dep_list((mp_value_node)green_part(r)));
set_prev_dep(magenta_part(t),prev_dep((mp_value_node)green_part(r)));
set_mp_link(prev_dep(magenta_part(t)),(mp_node)magenta_part(t));
}
if(((mp_type(yellow_part(t)))!=mp_independent)&&((mp_type(yellow_part(t)))!=mp_known)){

set_dep_list(yellow_part(t),dep_list((mp_value_node)blue_part(r)));
set_prev_dep(yellow_part(t),prev_dep((mp_value_node)blue_part(r)));
set_mp_link(prev_dep(yellow_part(t)),(mp_node)yellow_part(t));
}
mp_recycle_value(mp,r);
r= t;

mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type<mp_known){
const char*hlp[]= {
"I've just scanned a cmykcolor `(c,m,y,k)'; but the `k' isn't",
"of numeric type. So I've changed that part to zero.",
"(The k that I didn't like appears above the error message.)",
NULL};
mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,"Nonnumeric blackpart has been replaced by 0",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
mp_stash_in(mp,black_part(r));
}
}else{
mp_init_pair_node(mp,q);
r= value_node(q);
mp_stash_in(mp,y_part(r));
mp_unstash_cur_exp(mp,p);
mp_stash_in(mp,x_part(r));
}
mp_check_delimiter(mp,l_delim,r_delim);
mp->cur_exp.type= mp_type(q);
set_cur_exp_node(q);

}else{
mp_check_delimiter(mp,l_delim,r_delim);
}
}
break;
case mp_begin_group:




{
integer group_line;
group_line= mp_true_line(mp);
if(number_positive(internal_value(mp_tracing_commands)))
show_cur_cmd_mod;
mp_save_boundary(mp);
do{
mp_do_statement(mp);
}while(cur_cmd()==mp_semicolon);
if(cur_cmd()!=mp_end_group){
char msg[256];
const char*hlp[]= {
"I saw a `begingroup' back there that hasn't been matched",
"by `endgroup'. So I've inserted `endgroup' now.",
NULL};
mp_snprintf(msg,256,"A group begun on line %d never ended",(int)group_line);
mp_back_error(mp,msg,hlp,true);
set_cur_cmd((mp_variable_type)mp_end_group);
}
mp_unsave(mp);

if(number_positive(internal_value(mp_tracing_commands)))
show_cur_cmd_mod;
}
break;
case mp_string_token:

mp->cur_exp.type= mp_string_type;
set_cur_exp_str(cur_mod_str());
break;
case mp_numeric_token:
{









mp_number num,denom;
new_number(num);
new_number(denom);
set_cur_exp_value_number(cur_mod_number());
mp->cur_exp.type= mp_known;
mp_get_x_next(mp);
if(cur_cmd()!=mp_slash){
set_number_to_zero(num);
set_number_to_zero(denom);
}else{
mp_get_x_next(mp);
if(cur_cmd()!=mp_numeric_token){
mp_back_input(mp);
set_cur_cmd((mp_variable_type)mp_slash);
set_cur_mod(mp_over);
set_cur_sym(mp->frozen_slash);
free_number(num);
free_number(denom);
goto DONE;
}
number_clone(num,cur_exp_value_number());
number_clone(denom,cur_mod_number());
if(number_zero(denom)){

const char*hlp[]= {"I'll pretend that you meant to divide by 1.",NULL};
mp_error(mp,"Division by zero",hlp,true);
}else{
mp_number ret;
new_number(ret);
make_scaled(ret,num,denom);
set_cur_exp_value_number(ret);
free_number(ret);
}
check_arith();
mp_get_x_next(mp);
}
if(cur_cmd()>=mp_min_primary_command){
if(cur_cmd()<mp_numeric_token){
mp_node p;
mp_number absnum,absdenom;
new_number(absnum);
new_number(absdenom);
p= mp_stash_cur_exp(mp);
mp_scan_primary(mp);
number_clone(absnum,num);
number_abs(absnum);
number_clone(absdenom,denom);
number_abs(absdenom);
if(number_greaterequal(absnum,absdenom)||(mp->cur_exp.type<mp_color_type)){
mp_do_binary(mp,p,mp_times);
}else{
mp_frac_mult(mp,num,denom);
mp_free_value_node(mp,p);
}
free_number(absnum);
free_number(absdenom);
}
}
free_number(num);
free_number(denom);
goto DONE;
}
break;
case mp_nullary:

mp_do_nullary(mp,(quarterword)cur_mod());
break;
case mp_unary:
case mp_type_name:
case mp_cycle:
case mp_plus_or_minus:
{

quarterword c;
c= (quarterword)cur_mod();
mp_get_x_next(mp);
mp_scan_primary(mp);
mp_do_unary(mp,c);
goto DONE;
}
break;
case mp_primary_binary:
{

mp_node p;
quarterword c;
c= (quarterword)cur_mod();
mp_get_x_next(mp);
mp_scan_expression(mp);
if(cur_cmd()!=mp_of_token){
char msg[256];
mp_string sname;
const char*hlp[]= {
"I've got the first argument; will look now for the other.",
NULL};
int old_setting= mp->selector;
mp->selector= new_string;
mp_print_cmd_mod(mp,mp_primary_binary,c);
mp->selector= old_setting;
sname= mp_make_string(mp);
mp_snprintf(msg,256,"Missing `of' has been inserted for %s",mp_str(mp,sname));
delete_str_ref(sname);
mp_back_error(mp,msg,hlp,true);
}
p= mp_stash_cur_exp(mp);
mp_get_x_next(mp);
mp_scan_primary(mp);
mp_do_binary(mp,p,c);
goto DONE;
}
break;
case mp_str_op:

mp_get_x_next(mp);
mp_scan_suffix(mp);
mp->old_setting= mp->selector;
mp->selector= new_string;
mp_show_token_list(mp,cur_exp_node(),NULL,100000,0);
mp_flush_token_list(mp,cur_exp_node());
set_cur_exp_str(mp_make_string(mp));
mp->selector= mp->old_setting;
mp->cur_exp.type= mp_string_type;
goto DONE;
break;
case mp_void_op:
{

mp_value new_expr;
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_get_x_next(mp);
mp_scan_suffix(mp);
if(cur_exp_node()==NULL){
set_number_from_boolean(new_expr.data.n,mp_true_code);
}else{
set_number_from_boolean(new_expr.data.n,mp_false_code);
}
mp_flush_cur_exp(mp,new_expr);
cur_exp_node()= NULL;
mp->cur_exp.type= mp_boolean_type;
goto DONE;
}
break;
case mp_internal_quantity:





{
halfword qq= cur_mod();
if(my_var_flag==mp_assignment){
mp_get_x_next(mp);
if(cur_cmd()==mp_assignment){
set_cur_exp_node(mp_get_symbolic_node(mp));
set_mp_sym_info(cur_exp_node(),qq);
mp_name_type(cur_exp_node())= mp_internal_sym;
mp->cur_exp.type= mp_token_list;
goto DONE;
}
mp_back_input(mp);
}
if(internal_type(qq)==mp_string_type){
set_cur_exp_str(internal_string(qq));
}else{
set_cur_exp_value_number(internal_value(qq));
}
mp->cur_exp.type= internal_type(qq);
}
break;
case mp_capsule_token:
mp_make_exp_copy(mp,cur_mod_node());
break;
case mp_tag_token:
/*948:*/
#line 23964 "../../../source/texk/web2c/mplibdir/mp.w"

{
mp_node p,q;
mp_node t;
mp_node pre_head,post_head,tail;
quarterword tt;
mp_node macro_ref= 0;
pre_head= mp_get_symbolic_node(mp);
tail= pre_head;
post_head= NULL;
tt= mp_vacuous;
while(1){
t= mp_cur_tok(mp);
mp_link(tail)= t;
if(tt!=mp_undefined){





mp_sym qq;
p= mp_link(pre_head);
qq= mp_sym_sym(p);
tt= mp_undefined;
if(eq_type(qq)%mp_outer_tag==mp_tag_token){
q= equiv_node(qq);
if(q==NULL)
goto DONE2;
while(1){
p= mp_link(p);
if(p==NULL){
tt= mp_type(q);
goto DONE2;
}
if(mp_type(q)!=mp_structured)
goto DONE2;
q= mp_link(attr_head(q));
if(mp_type(p)==mp_symbol_node){
do{
q= mp_link(q);
}while(!(hashloc(q)>=mp_sym_sym(p)));
if(hashloc(q)> mp_sym_sym(p))
goto DONE2;
}
}
}
DONE2:

if(tt>=mp_unsuffixed_macro){


mp_link(tail)= NULL;
if(tt> mp_unsuffixed_macro){
post_head= mp_get_symbolic_node(mp);
tail= post_head;
mp_link(tail)= t;
tt= mp_undefined;
macro_ref= value_node(q);
add_mac_ref(macro_ref);
}else{



p= mp_get_symbolic_node(mp);
set_mp_sym_sym(pre_head,mp_link(pre_head));
mp_link(pre_head)= p;
set_mp_sym_sym(p,t);
mp_macro_call(mp,value_node(q),pre_head,NULL);
mp_get_x_next(mp);
goto RESTART;
}
}
}
mp_get_x_next(mp);
tail= t;
if(cur_cmd()==mp_left_bracket){

mp_get_x_next(mp);
mp_scan_expression(mp);
if(cur_cmd()!=mp_right_bracket){





mp_back_input(mp);
mp_back_expr(mp);
set_cur_cmd((mp_variable_type)mp_left_bracket);
set_cur_mod_number(zero_t);
set_cur_sym(mp->frozen_left_bracket);

}else{
if(mp->cur_exp.type!=mp_known)
mp_bad_subscript(mp);
set_cur_cmd((mp_variable_type)mp_numeric_token);
set_cur_mod_number(cur_exp_value_number());
set_cur_sym(NULL);
}
}
if(cur_cmd()> mp_max_suffix_token)
break;
if(cur_cmd()<mp_min_suffix_token)
break;
}





if(post_head!=NULL){




mp_back_input(mp);
p= mp_get_symbolic_node(mp);
q= mp_link(post_head);
set_mp_sym_sym(pre_head,mp_link(pre_head));
mp_link(pre_head)= post_head;
set_mp_sym_sym(post_head,q);
mp_link(post_head)= p;
set_mp_sym_sym(p,mp_link(q));
mp_link(q)= NULL;
mp_macro_call(mp,macro_ref,pre_head,NULL);
decr_mac_ref(macro_ref);
mp_get_x_next(mp);
goto RESTART;
}
q= mp_link(pre_head);
mp_free_symbolic_node(mp,pre_head);
if(cur_cmd()==my_var_flag){
mp->cur_exp.type= mp_token_list;
set_cur_exp_node(q);
goto DONE;
}
p= mp_find_variable(mp,q);
if(p!=NULL){
mp_make_exp_copy(mp,p);
}else{
mp_value new_expr;
const char*hlp[]= {
"While I was evaluating the suffix of this variable,",
"something was redefined, and it's no longer a variable!",
"In order to get back on my feet, I've inserted `0' instead.",
NULL};
char*msg= mp_obliterated(mp,q);
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
set_number_to_zero(new_expr.data.n);
mp_back_error(mp,msg,hlp,true);
free(msg);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
mp_flush_node_list(mp,q);
goto DONE;
}


/*:948*/
#line 23811 "../../../source/texk/web2c/mplibdir/mp.w"
;
break;
default:
mp_bad_exp(mp,"A primary");
goto RESTART;
break;
}
mp_get_x_next(mp);
DONE:
check_for_mediation(mp);
}

/*:943*//*944:*/
#line 23827 "../../../source/texk/web2c/mplibdir/mp.w"

static void check_for_mediation(MP mp){
mp_node p,q,r;
if(cur_cmd()==mp_left_bracket){
if(mp->cur_exp.type>=mp_known){

p= mp_stash_cur_exp(mp);
mp_get_x_next(mp);
mp_scan_expression(mp);
if(cur_cmd()!=mp_comma){





mp_back_input(mp);
mp_back_expr(mp);
set_cur_cmd((mp_variable_type)mp_left_bracket);
set_cur_mod_number(zero_t);
set_cur_sym(mp->frozen_left_bracket);
mp_unstash_cur_exp(mp,p);
}else{
q= mp_stash_cur_exp(mp);
mp_get_x_next(mp);
mp_scan_expression(mp);
if(cur_cmd()!=mp_right_bracket){
const char*hlp[]= {
"I've scanned an expression of the form `a[b,c',",
"so a right bracket should have come next.",
"I shall pretend that one was there.",
NULL};
mp_back_error(mp,"Missing `]' has been inserted",hlp,true);
}
r= mp_stash_cur_exp(mp);
mp_make_exp_copy(mp,q);
mp_do_binary(mp,r,mp_minus);
mp_do_binary(mp,p,mp_times);
mp_do_binary(mp,q,mp_plus);
mp_get_x_next(mp);
}
}
}
}


/*:944*//*955:*/
#line 24354 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_suffix(MP mp){
mp_node h,t;
mp_node p;
h= mp_get_symbolic_node(mp);
t= h;
while(1){
if(cur_cmd()==mp_left_bracket){

mp_get_x_next(mp);
mp_scan_expression(mp);
if(mp->cur_exp.type!=mp_known)
mp_bad_subscript(mp);
if(cur_cmd()!=mp_right_bracket){
const char*hlp[]= {
"I've seen a `[' and a subscript value, in a suffix,",
"so a right bracket should have come next.",
"I shall pretend that one was there.",
NULL};
mp_back_error(mp,"Missing `]' has been inserted",hlp,true);
}
set_cur_cmd((mp_variable_type)mp_numeric_token);
set_cur_mod_number(cur_exp_value_number());

}
if(cur_cmd()==mp_numeric_token){
mp_number arg1;
new_number(arg1);
number_clone(arg1,cur_mod_number());
p= mp_new_num_tok(mp,arg1);
free_number(arg1);
}else if((cur_cmd()==mp_tag_token)||(cur_cmd()==mp_internal_quantity)){
p= mp_get_symbolic_node(mp);
set_mp_sym_sym(p,cur_sym());
mp_name_type(p)= cur_sym_mod();
}else{
break;
}
mp_link(t)= p;
t= p;
mp_get_x_next(mp);
}
set_cur_exp_node(mp_link(h));
mp_free_symbolic_node(mp,h);
mp->cur_exp.type= mp_token_list;
}

/*:955*//*956:*/
#line 24413 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_secondary(MP mp){
mp_node p;
halfword c,d;
mp_node cc= NULL;
mp_sym mac_name= NULL;
RESTART:
if((cur_cmd()<mp_min_primary_command)||
(cur_cmd()> mp_max_primary_command))
mp_bad_exp(mp,"A secondary");
;
mp_scan_primary(mp);
CONTINUE:
if(cur_cmd()<=mp_max_secondary_command&&
cur_cmd()>=mp_min_secondary_command){
p= mp_stash_cur_exp(mp);
d= cur_cmd();
c= cur_mod();
if(d==mp_secondary_primary_macro){
cc= cur_mod_node();
mac_name= cur_sym();
add_mac_ref(cc);
}
mp_get_x_next(mp);
mp_scan_primary(mp);
if(d!=mp_secondary_primary_macro){
mp_do_binary(mp,p,c);
}else{
mp_back_input(mp);
mp_binary_mac(mp,p,cc,mac_name);
decr_mac_ref(cc);
mp_get_x_next(mp);
goto RESTART;
}
goto CONTINUE;
}
}


/*:956*//*958:*/
#line 24469 "../../../source/texk/web2c/mplibdir/mp.w"

static void mp_scan_tertiary(MP mp){
mp_node p;
halfword c,d;
mp_node cc= NULL;
mp_sym mac_name= NULL;
RESTART:
if((cur_cmd()<mp_min_primary_command)||
(cur_cmd()> mp_max_primary_command))
mp_bad_exp(mp,"A tertiary");
;
mp_scan_secondary(mp);
CONTINUE:
if(cur_cmd()<=mp_max_tertiary_command){
if(cur_cmd()>=mp_min_tertiary_command){
p= mp_stash_cur_exp(mp);
c= cur_mod();
d= cur_cmd();
if(d==mp_tertiary_secondary_macro){
cc= cur_mod_node();
mac_name= cur_sym();
add_mac_ref(cc);
}
mp_get_x_next(mp);
mp_scan_secondary(mp);
if(d!=mp_tertiary_secondary_macro){
mp_do_binary(mp,p,c);
}else{
mp_back_input(mp);
mp_binary_mac(mp,p,cc,mac_name);
decr_mac_ref(cc);
mp_get_x_next(mp);
goto RESTART;
}
goto CONTINUE;
}
}
}


/*:958*//*959:*/
#line 24513 "../../../source/texk/web2c/mplibdir/mp.w"

static int mp_scan_path(MP mp);
static void mp_scan_expression(MP mp){
int my_var_flag;
my_var_flag= mp->var_flag;
check_expansion_depth();
RESTART:
if((cur_cmd()<mp_min_primary_command)||
(cur_cmd()> mp_max_primary_command))
mp_bad_exp(mp,"An");
;
mp_scan_tertiary(mp);
CONTINUE:
if(cur_cmd()<=mp_max_expression_command){
if(cur_cmd()>=mp_min_expression_command){
if((cur_cmd()!=mp_equals)||(my_var_flag!=mp_assignment)){
mp_node p;
mp_node cc= NULL;
halfword c;
halfword d;
mp_sym mac_name;
mac_name= NULL;
p= mp_stash_cur_exp(mp);
d= cur_cmd();
c= cur_mod();
if(d==mp_expression_tertiary_macro){
cc= cur_mod_node();
mac_name= cur_sym();
add_mac_ref(cc);
}
if((d<mp_ampersand)||((d==mp_ampersand)&&
((mp_type(p)==mp_pair_type)
||(mp_type(p)==mp_path_type)))){


mp_unstash_cur_exp(mp,p);
if(!mp_scan_path(mp)){
mp->expand_depth_count--;
return;
}
}else{
mp_get_x_next(mp);
mp_scan_tertiary(mp);
if(d!=mp_expression_tertiary_macro){
mp_do_binary(mp,p,c);
}else{
mp_back_input(mp);
mp_binary_mac(mp,p,cc,mac_name);
decr_mac_ref(cc);
mp_get_x_next(mp);
goto RESTART;
}
}
goto CONTINUE;
}
}
}
mp->expand_depth_count--;
}


/*:959*//*960:*/
#line 24579 "../../../source/texk/web2c/mplibdir/mp.w"

static void force_valid_tension_setting(MP mp){
if((mp->cur_exp.type!=mp_known)||number_less(cur_exp_value_number(),min_tension)){
mp_value new_expr;
const char*hlp[]= {
"The expression above should have been a number >=3/4.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
number_clone(new_expr.data.n,unity_t);
mp_back_error(mp,"Improper tension has been set to 1",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
}
}
static int mp_scan_path(MP mp){
mp_knot path_p,path_q,r;
mp_knot pp,qq;
halfword d;
boolean cycle_hit;
mp_number x,y;
int t;
t= 0;
cycle_hit= false;


if(mp->cur_exp.type==mp_pair_type)
path_p= mp_pair_to_knot(mp);
else if(mp->cur_exp.type==mp_path_type)
path_p= cur_exp_knot();
else
return 0;
path_q= path_p;
while(mp_next_knot(path_q)!=path_p)
path_q= mp_next_knot(path_q);
if(mp_left_type(path_p)!=mp_endpoint){
r= mp_copy_knot(mp,path_p);
mp_next_knot(path_q)= r;
path_q= r;
}
mp_left_type(path_p)= mp_open;
mp_right_type(path_q)= mp_open;

new_number(y);
new_number(x);

CONTINUE_PATH:




if(cur_cmd()==mp_left_brace){





t= mp_scan_direction(mp);
if(t!=mp_open){
mp_right_type(path_q)= (unsigned short)t;
number_clone(path_q->right_given,cur_exp_value_number());
if(mp_left_type(path_q)==mp_open){
mp_left_type(path_q)= (unsigned short)t;
number_clone(path_q->left_given,cur_exp_value_number());
}
}
}
d= cur_cmd();
if(d==mp_path_join){

mp_get_x_next(mp);
if(cur_cmd()==mp_tension){

mp_get_x_next(mp);
set_number_from_scaled(y,cur_cmd());
if(cur_cmd()==mp_at_least)
mp_get_x_next(mp);
mp_scan_primary(mp);
force_valid_tension_setting(mp);
if(number_to_scaled(y)==mp_at_least){
if(is_number(cur_exp_value_number()))
number_negate(cur_exp_value_number());
}
number_clone(path_q->right_tension,cur_exp_value_number());
if(cur_cmd()==mp_and_command){
mp_get_x_next(mp);
set_number_from_scaled(y,cur_cmd());
if(cur_cmd()==mp_at_least)
mp_get_x_next(mp);
mp_scan_primary(mp);
force_valid_tension_setting(mp);
if(number_to_scaled(y)==mp_at_least){
if(is_number(cur_exp_value_number()))
number_negate(cur_exp_value_number());
}
}
number_clone(y,cur_exp_value_number());

}else if(cur_cmd()==mp_controls){

mp_right_type(path_q)= mp_explicit;
t= mp_explicit;
mp_get_x_next(mp);
mp_scan_primary(mp);
mp_known_pair(mp);
number_clone(path_q->right_x,mp->cur_x);
number_clone(path_q->right_y,mp->cur_y);
if(cur_cmd()!=mp_and_command){
number_clone(x,path_q->right_x);
number_clone(y,path_q->right_y);
}else{
mp_get_x_next(mp);
mp_scan_primary(mp);
mp_known_pair(mp);
number_clone(x,mp->cur_x);
number_clone(y,mp->cur_y);
}

}else{
set_number_to_unity(path_q->right_tension);
set_number_to_unity(y);
mp_back_input(mp);
goto DONE;
};
if(cur_cmd()!=mp_path_join){
const char*hlp[]= {"A path join command should end with two dots.",NULL};
mp_back_error(mp,"Missing `..' has been inserted",hlp,true);
}
DONE:
;
}else if(d!=mp_ampersand){
goto FINISH_PATH;
}
mp_get_x_next(mp);
if(cur_cmd()==mp_left_brace){





t= mp_scan_direction(mp);
if(mp_right_type(path_q)!=mp_explicit)
number_clone(x,cur_exp_value_number());
else
t= mp_explicit;

}else if(mp_right_type(path_q)!=mp_explicit){
t= mp_open;
set_number_to_zero(x);
}

if(cur_cmd()==mp_cycle){




cycle_hit= true;
mp_get_x_next(mp);
pp= path_p;
qq= path_p;
if(d==mp_ampersand){
if(path_p==path_q){
d= mp_path_join;
set_number_to_unity(path_q->right_tension);
set_number_to_unity(y);
}
}
}else{
mp_scan_tertiary(mp);


if(mp->cur_exp.type!=mp_path_type)
pp= mp_pair_to_knot(mp);
else
pp= cur_exp_knot();
qq= pp;
while(mp_next_knot(qq)!=pp)
qq= mp_next_knot(qq);
if(mp_left_type(pp)!=mp_endpoint){
r= mp_copy_knot(mp,pp);
mp_next_knot(qq)= r;
qq= r;
}
mp_left_type(pp)= mp_open;
mp_right_type(qq)= mp_open;
}


if(d==mp_ampersand){
if(!(number_equal(path_q->x_coord,pp->x_coord))||
!(number_equal(path_q->y_coord,pp->y_coord))){
const char*hlp[]= {
"When you join paths `p&q', the ending point of p",
"must be exactly equal to the starting point of q.",
"So I'm going to pretend that you said `p..q' instead.",
NULL};
mp_back_error(mp,"Paths don't touch; `&' will be changed to `..'",hlp,true);
;
mp_get_x_next(mp);
d= mp_path_join;
set_number_to_unity(path_q->right_tension);
set_number_to_unity(y);
}
}

if(mp_right_type(pp)==mp_open){
if((t==mp_curl)||(t==mp_given)){
mp_right_type(pp)= (unsigned short)t;
number_clone(pp->right_given,x);
}
}
if(d==mp_ampersand){

if(mp_left_type(path_q)==mp_open)
if(mp_right_type(path_q)==mp_open){
mp_left_type(path_q)= mp_curl;
set_number_to_unity(path_q->left_curl);
}
if(mp_right_type(pp)==mp_open)
if(t==mp_open){
mp_right_type(pp)= mp_curl;
set_number_to_unity(pp->right_curl);
}
mp_right_type(path_q)= mp_right_type(pp);
mp_next_knot(path_q)= mp_next_knot(pp);
number_clone(path_q->right_x,pp->right_x);
number_clone(path_q->right_y,pp->right_y);
mp_xfree(pp);
if(qq==pp)
qq= path_q;

}else{

if(mp_right_type(path_q)==mp_open){
if((mp_left_type(path_q)==mp_curl)||(mp_left_type(path_q)==mp_given)){
mp_right_type(path_q)= mp_left_type(path_q);
number_clone(path_q->right_given,path_q->left_given);
}
}

mp_next_knot(path_q)= pp;
number_clone(pp->left_y,y);
if(t!=mp_open){
number_clone(pp->left_x,x);
mp_left_type(pp)= (unsigned short)t;
};
}
path_q= qq;

if(cur_cmd()>=mp_min_expression_command)
if(cur_cmd()<=mp_ampersand)
if(!cycle_hit)
goto CONTINUE_PATH;
FINISH_PATH:

if(cycle_hit){
if(d==mp_ampersand)
path_p= path_q;
}else{
mp_left_type(path_p)= mp_endpoint;
if(mp_right_type(path_p)==mp_open){
mp_right_type(path_p)= mp_curl;
set_number_to_unity(path_p->right_curl);
}
mp_right_type(path_q)= mp_endpoint;
if(mp_left_type(path_q)==mp_open){
mp_left_type(path_q)= mp_curl;
set_number_to_unity(path_q->left_curl);
}
mp_next_knot(path_q)= path_p;
}
mp_make_choices(mp,path_p);
mp->cur_exp.type= mp_path_type;
set_cur_exp_knot(path_p);

free_number(x);
free_number(y);
return 1;
}


/*:960*//*965:*/
#line 25071 "../../../source/texk/web2c/mplibdir/mp.w"

static void do_boolean_error(MP mp){
mp_value new_expr;
const char*hlp[]= {
"The expression shown above should have had a definite",
"true-or-false value. I'm changing it to `false'.",
NULL};
memset(&new_expr,0,sizeof(mp_value));
new_number(new_expr.data.n);
mp_disp_err(mp,NULL);
set_number_from_boolean(new_expr.data.n,mp_false_code);
mp_back_error(mp,"Undefined condition will be treated as `false'",hlp,true);
mp_get_x_next(mp);
mp_flush_cur_exp(mp,new_expr);
mp->cur_exp.type= mp_boolean_type;
}

/*:965*/
#line 35348 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*254:*/
#line 5574 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_print_capsule(MP mp,mp_node p){
mp_print_char(mp,xord('('));
mp_print_exp(mp,p,0);
mp_print_char(mp,xord(')'));
}


/*:254*/
#line 35349 "../../../source/texk/web2c/mplibdir/mp.w"



/*:1297*//*1299:*/
#line 35360 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_close_files_and_terminate(MP mp){
integer k;
integer LH;
int lk_offset;
mp_node p;
if(mp->finished)
return;
/*1301:*/
#line 35393 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->rd_fname!=NULL){
for(k= 0;k<(int)mp->read_files;k++){
if(mp->rd_fname[k]!=NULL){
(mp->close_file)(mp,mp->rd_file[k]);
xfree(mp->rd_fname[k]);
}
}
}
if(mp->wr_fname!=NULL){
for(k= 0;k<(int)mp->write_files;k++){
if(mp->wr_fname[k]!=NULL){
(mp->close_file)(mp,mp->wr_file[k]);
xfree(mp->wr_fname[k]);
}
}
}

/*:1301*/
#line 35368 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(number_positive(internal_value(mp_tracing_stats)))
/*1304:*/
#line 35450 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->log_opened){
char s[128];
wlog_ln(" ");
wlog_ln("Here is how much of MetaPost's memory you used:");
;
mp_snprintf(s,128," %i string%s using %i character%s",
(int)mp->max_strs_used,(mp->max_strs_used!=1?"s":""),
(int)mp->max_pl_used,(mp->max_pl_used!=1?"s":""));
wlog_ln(s);
mp_snprintf(s,128," %i bytes of node memory",(int)mp->var_used_max);
wlog_ln(s);
mp_snprintf(s,128," %i symbolic tokens",(int)mp->st_count);
wlog_ln(s);
mp_snprintf(s,128,
" %ii,%in,%ip,%ib,%if stack positions out of %ii,%in,%ip,%ib,%if",
(int)mp->max_in_stack,(int)mp->int_ptr,
(int)mp->max_param_stack,(int)mp->max_buf_stack+1,
(int)mp->in_open_max-file_bottom,(int)mp->stack_size,
(int)mp->max_internal,(int)mp->param_size,(int)mp->buf_size,
(int)mp->max_in_open-file_bottom);
wlog_ln(s);
}

/*:1304*/
#line 35370 "../../../source/texk/web2c/mplibdir/mp.w"
;
wake_up_terminal();
/*1303:*/
#line 35436 "../../../source/texk/web2c/mplibdir/mp.w"

if(number_positive(internal_value(mp_fontmaking))){
/*1216:*/
#line 33738 "../../../source/texk/web2c/mplibdir/mp.w"

clear_the_list;
for(k= mp->bc;k<=mp->ec;k++){
if(mp->char_exists[k])
mp->tfm_width[k]= mp_sort_in(mp,value_number(mp->tfm_width[k]));
}
mp->nw= (short)(mp_skimp(mp,255)+1);
mp->dimen_head[1]= mp_link(mp->temp_head);
if(number_greaterequal(mp->perturbation,tfm_warn_threshold_k))
mp_tfm_warning(mp,mp_char_wd)


/*:1216*/
#line 35438 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_fix_design_size(mp);
mp_fix_check_sum(mp);
/*1218:*/
#line 33757 "../../../source/texk/web2c/mplibdir/mp.w"

clear_the_list;
for(k= mp->bc;k<=mp->ec;k++){
if(mp->char_exists[k]){
if(number_zero(value_number(mp->tfm_height[k])))
mp->tfm_height[k]= mp->zero_val;
else
mp->tfm_height[k]= mp_sort_in(mp,value_number(mp->tfm_height[k]));
}
}
mp->nh= (short)(mp_skimp(mp,15)+1);
mp->dimen_head[2]= mp_link(mp->temp_head);
if(number_greaterequal(mp->perturbation,tfm_warn_threshold_k))
mp_tfm_warning(mp,mp_char_ht);
clear_the_list;
for(k= mp->bc;k<=mp->ec;k++){
if(mp->char_exists[k]){
if(number_zero(value_number(mp->tfm_depth[k])))
mp->tfm_depth[k]= mp->zero_val;
else
mp->tfm_depth[k]= mp_sort_in(mp,value_number(mp->tfm_depth[k]));
}
}
mp->nd= (short)(mp_skimp(mp,15)+1);
mp->dimen_head[3]= mp_link(mp->temp_head);
if(number_greaterequal(mp->perturbation,tfm_warn_threshold_k))
mp_tfm_warning(mp,mp_char_dp);
clear_the_list;
for(k= mp->bc;k<=mp->ec;k++){
if(mp->char_exists[k]){
if(number_zero(value_number(mp->tfm_ital_corr[k])))
mp->tfm_ital_corr[k]= mp->zero_val;
else
mp->tfm_ital_corr[k]= mp_sort_in(mp,value_number(mp->tfm_ital_corr[k]));
}
}
mp->ni= (short)(mp_skimp(mp,63)+1);
mp->dimen_head[4]= mp_link(mp->temp_head);
if(number_greaterequal(mp->perturbation,tfm_warn_threshold_k))
mp_tfm_warning(mp,mp_char_ic)


/*:1218*/
#line 35441 "../../../source/texk/web2c/mplibdir/mp.w"
;
set_number_to_zero(internal_value(mp_fontmaking));
/*1229:*/
#line 33984 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->job_name==NULL)
mp_open_log_file(mp);
mp_pack_job_name(mp,".tfm");
while(!mp_open_out(mp,&mp->tfm_file,mp_filetype_metrics))
mp_prompt_file_name(mp,"file name for font metrics",".tfm");
mp->metric_file_name= xstrdup(mp->name_of_file);
/*1230:*/
#line 34008 "../../../source/texk/web2c/mplibdir/mp.w"

k= mp->header_last;
LH= (k+4)/4;
if(mp->bc> mp->ec)
mp->bc= 1;
/*1232:*/
#line 34064 "../../../source/texk/web2c/mplibdir/mp.w"

mp->bchar= round_unscaled(internal_value(mp_boundary_char));
if((mp->bchar<0)||(mp->bchar> 255)){
mp->bchar= -1;
mp->lk_started= false;
lk_offset= 0;
}else{
mp->lk_started= true;
lk_offset= 1;
}
/*1233:*/
#line 34083 "../../../source/texk/web2c/mplibdir/mp.w"

k= mp->label_ptr;
if(mp->label_loc[k]+lk_offset> 255){
lk_offset= 0;
mp->lk_started= false;
do{
mp->char_remainder[mp->label_char[k]]= lk_offset;
while(mp->label_loc[k-1]==mp->label_loc[k]){
decr(k);
mp->char_remainder[mp->label_char[k]]= lk_offset;
}
incr(lk_offset);
decr(k);
}while(!(lk_offset+mp->label_loc[k]<256));

}
if(lk_offset> 0){
while(k> 0){
mp->char_remainder[mp->label_char[k]]
= mp->char_remainder[mp->label_char[k]]+lk_offset;
decr(k);
}
}

/*:1233*/
#line 34074 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp->bch_label<undefined_label){
skip_byte(mp->nl)= qi(255);
next_char(mp->nl)= qi(0);
op_byte(mp->nl)= qi(((mp->bch_label+lk_offset)/256));
rem_byte(mp->nl)= qi(((mp->bch_label+lk_offset)%256));
mp->nl++;
}

/*:1232*/
#line 34014 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_tfm_two(mp,
6+LH+(mp->ec-mp->bc+1)+mp->nw+mp->nh+mp->nd+mp->ni+
mp->nl+lk_offset+mp->nk+mp->ne+mp->np);

mp_tfm_two(mp,LH);
mp_tfm_two(mp,mp->bc);
mp_tfm_two(mp,mp->ec);
mp_tfm_two(mp,mp->nw);
mp_tfm_two(mp,mp->nh);
mp_tfm_two(mp,mp->nd);
mp_tfm_two(mp,mp->ni);
mp_tfm_two(mp,mp->nl+lk_offset);
mp_tfm_two(mp,mp->nk);
mp_tfm_two(mp,mp->ne);
mp_tfm_two(mp,mp->np);
for(k= 0;k<4*LH;k++){
tfm_out(mp->header_byte[k]);
}


/*:1230*/
#line 33991 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*1231:*/
#line 34035 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= mp->bc;k<=mp->ec;k++){
if(!mp->char_exists[k]){
mp_tfm_four(mp,0);
}else{
tfm_out(indep_value(mp->tfm_width[k]));
tfm_out((indep_value(mp->tfm_height[k]))*16+indep_value(mp->tfm_depth[k]));
tfm_out((indep_value(mp->tfm_ital_corr[k]))*4+mp->char_tag[k]);
tfm_out(mp->char_remainder[k]);
};
}
mp->tfm_changed= 0;
for(k= 1;k<=4;k++){
mp_tfm_four(mp,0);
p= mp->dimen_head[k];
while(p!=mp->inf_val){
mp_tfm_four(mp,mp_dimen_out(mp,value_number(p)));
p= mp_link(p);
}
}


/*:1231*/
#line 33993 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*1234:*/
#line 34107 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<=255;k++){
if(mp->skip_table[k]<undefined_label){
mp_print_nl(mp,"(local label ");
mp_print_int(mp,k);
mp_print(mp,":: was missing)");
;
cancel_skips(mp->skip_table[k]);
}
}
if(mp->lk_started){
tfm_out(255);
tfm_out(mp->bchar);
mp_tfm_two(mp,0);
}else{
for(k= 1;k<=lk_offset;k++){
mp->ll= mp->label_loc[mp->label_ptr];
if(mp->bchar<0){
tfm_out(254);
tfm_out(0);
}else{
tfm_out(255);
tfm_out(mp->bchar);
};
mp_tfm_two(mp,mp->ll+lk_offset);
do{
mp->label_ptr--;
}while(!(mp->label_loc[mp->label_ptr]<mp->ll));
}
}
for(k= 0;k<mp->nl;k++)
mp_tfm_qqqq(mp,mp->lig_kern[k]);
{
mp_number arg;
new_number(arg);
for(k= 0;k<mp->nk;k++){
number_clone(arg,mp->kern[k]);
mp_tfm_four(mp,mp_dimen_out(mp,arg));
}
free_number(arg);
}

/*:1234*/
#line 33994 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*1235:*/
#line 34149 "../../../source/texk/web2c/mplibdir/mp.w"

for(k= 0;k<mp->ne;k++)
mp_tfm_qqqq(mp,mp->exten[k]);
{
mp_number arg;
new_number(arg);
for(k= 1;k<=mp->np;k++){
if(k==1){
number_clone(arg,mp->param[1]);
number_abs(arg);
if(number_less(arg,fraction_half_t)){
mp_tfm_four(mp,number_to_scaled(mp->param[1])*16);
}else{
incr(mp->tfm_changed);
if(number_positive(mp->param[1]))
mp_tfm_four(mp,max_integer);
else
mp_tfm_four(mp,-max_integer);
}
}else{
number_clone(arg,mp->param[k]);
mp_tfm_four(mp,mp_dimen_out(mp,arg));
}
}
free_number(arg);
}
if(mp->tfm_changed> 0){
if(mp->tfm_changed==1){
mp_print_nl(mp,"(a font metric dimension");

}else{
mp_print_nl(mp,"(");
mp_print_int(mp,mp->tfm_changed);
;
mp_print(mp," font metric dimensions");
}
mp_print(mp," had to be decreased)");
}

/*:1235*/
#line 33995 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(number_positive(internal_value(mp_tracing_stats)))
/*1236:*/
#line 34188 "../../../source/texk/web2c/mplibdir/mp.w"

{
char s[200];
wlog_ln(" ");
if(mp->bch_label<undefined_label)
mp->nl--;
mp_snprintf(s,128,
"(You used %iw,%ih,%id,%ii,%il,%ik,%ie,%ip metric file positions)",
mp->nw,mp->nh,mp->nd,mp->ni,mp->nl,mp->nk,mp->ne,mp->np);
wlog_ln(s);
}


/*:1236*/
#line 33997 "../../../source/texk/web2c/mplibdir/mp.w"
;
mp_print_nl(mp,"Font metrics written on ");
mp_print(mp,mp->metric_file_name);
mp_print_char(mp,xord('.'));
;
(mp->close_file)(mp,mp->tfm_file)


/*:1229*/
#line 35443 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

/*:1303*/
#line 35372 "../../../source/texk/web2c/mplibdir/mp.w"
;
/*1272:*/
#line 34843 "../../../source/texk/web2c/mplibdir/mp.w"

if(mp->total_shipped> 0){
mp_print_nl(mp,"");
mp_print_int(mp,mp->total_shipped);
if(mp->noninteractive){
mp_print(mp," figure");
if(mp->total_shipped> 1)
mp_print_char(mp,xord('s'));
mp_print(mp," created.");
}else{
mp_print(mp," output file");
if(mp->total_shipped> 1)
mp_print_char(mp,xord('s'));
mp_print(mp," written: ");
mp_print(mp,mp->first_file_name);
if(mp->total_shipped> 1){
if(31+strlen(mp->first_file_name)+
strlen(mp->last_file_name)> (unsigned)mp->max_print_line)
mp_print_ln(mp);
mp_print(mp," .. ");
mp_print(mp,mp->last_file_name);
}
mp_print_nl(mp,"");
}
}

/*:1272*/
#line 35373 "../../../source/texk/web2c/mplibdir/mp.w"
;
if(mp->log_opened&&!mp->noninteractive){
wlog_cr;
(mp->close_file)(mp,mp->log_file);
mp->selector= mp->selector-2;
if(mp->selector==term_only){
mp_print_nl(mp,"Transcript written on ");
;
mp_print(mp,mp->log_name);
mp_print_char(mp,xord('.'));
}
}
mp_print_ln(mp);
mp->finished= true;
}


/*:1299*//*1306:*/
#line 35482 "../../../source/texk/web2c/mplibdir/mp.w"

int mp_memory_usage(MP mp){
return(int)mp->var_used;
}
int mp_hash_usage(MP mp){
return(int)mp->st_count;
}
int mp_param_usage(MP mp){
return(int)mp->max_param_stack;
}
int mp_open_usage(MP mp){
return(int)mp->max_in_stack;
}


/*:1306*//*1307:*/
#line 35500 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_final_cleanup(MP mp){


if(mp->job_name==NULL)
mp_open_log_file(mp);
while(mp->input_ptr> 0){
if(token_state)
mp_end_token_list(mp);
else
mp_end_file_reading(mp);
}
while(mp->loop_ptr!=NULL)
mp_stop_iteration(mp);
while(mp->open_parens> 0){
mp_print(mp," )");
decr(mp->open_parens);
};
while(mp->cond_ptr!=NULL){
mp_print_nl(mp,"(end occurred when ");
;
mp_print_cmd_mod(mp,mp_fi_or_else,mp->cur_if);

if(mp->if_line!=0){
mp_print(mp," on line ");
mp_print_int(mp,mp->if_line);
}
mp_print(mp," was incomplete)");
mp->if_line= if_line_field(mp->cond_ptr);
mp->cur_if= mp_name_type(mp->cond_ptr);
mp->cond_ptr= mp_link(mp->cond_ptr);
}
if(mp->history!=mp_spotless)
if(((mp->history==mp_warning_issued)
||(mp->interaction<mp_error_stop_mode)))
if(mp->selector==term_and_log){
mp->selector= term_only;
mp_print_nl(mp,
"(see the transcript file for additional information)");
;
mp->selector= term_and_log;
}
}


/*:1307*//*1309:*/
#line 35550 "../../../source/texk/web2c/mplibdir/mp.w"

void mp_init_prim(MP mp){
/*205:*/
#line 4170 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"tracingtitles",mp_internal_quantity,mp_tracing_titles);
;
mp_primitive(mp,"tracingequations",mp_internal_quantity,mp_tracing_equations);
;
mp_primitive(mp,"tracingcapsules",mp_internal_quantity,mp_tracing_capsules);
;
mp_primitive(mp,"tracingchoices",mp_internal_quantity,mp_tracing_choices);
;
mp_primitive(mp,"tracingspecs",mp_internal_quantity,mp_tracing_specs);
;
mp_primitive(mp,"tracingcommands",mp_internal_quantity,mp_tracing_commands);
;
mp_primitive(mp,"tracingrestores",mp_internal_quantity,mp_tracing_restores);
;
mp_primitive(mp,"tracingmacros",mp_internal_quantity,mp_tracing_macros);
;
mp_primitive(mp,"tracingoutput",mp_internal_quantity,mp_tracing_output);
;
mp_primitive(mp,"tracingstats",mp_internal_quantity,mp_tracing_stats);
;
mp_primitive(mp,"tracinglostchars",mp_internal_quantity,mp_tracing_lost_chars);
;
mp_primitive(mp,"tracingonline",mp_internal_quantity,mp_tracing_online);
;
mp_primitive(mp,"year",mp_internal_quantity,mp_year);
;
mp_primitive(mp,"month",mp_internal_quantity,mp_month);
;
mp_primitive(mp,"day",mp_internal_quantity,mp_day);
;
mp_primitive(mp,"time",mp_internal_quantity,mp_time);
;
mp_primitive(mp,"hour",mp_internal_quantity,mp_hour);
;
mp_primitive(mp,"minute",mp_internal_quantity,mp_minute);
;
mp_primitive(mp,"charcode",mp_internal_quantity,mp_char_code);
;
mp_primitive(mp,"charext",mp_internal_quantity,mp_char_ext);
;
mp_primitive(mp,"charwd",mp_internal_quantity,mp_char_wd);
;
mp_primitive(mp,"charht",mp_internal_quantity,mp_char_ht);
;
mp_primitive(mp,"chardp",mp_internal_quantity,mp_char_dp);
;
mp_primitive(mp,"charic",mp_internal_quantity,mp_char_ic);
;
mp_primitive(mp,"designsize",mp_internal_quantity,mp_design_size);
;
mp_primitive(mp,"pausing",mp_internal_quantity,mp_pausing);
;
mp_primitive(mp,"showstopping",mp_internal_quantity,mp_showstopping);
;
mp_primitive(mp,"fontmaking",mp_internal_quantity,mp_fontmaking);
;
mp_primitive(mp,"texscriptmode",mp_internal_quantity,mp_texscriptmode);
;
mp_primitive(mp,"linejoin",mp_internal_quantity,mp_linejoin);
;
mp_primitive(mp,"linecap",mp_internal_quantity,mp_linecap);
;
mp_primitive(mp,"miterlimit",mp_internal_quantity,mp_miterlimit);
;
mp_primitive(mp,"warningcheck",mp_internal_quantity,mp_warning_check);
;
mp_primitive(mp,"boundarychar",mp_internal_quantity,mp_boundary_char);
;
mp_primitive(mp,"prologues",mp_internal_quantity,mp_prologues);
;
mp_primitive(mp,"truecorners",mp_internal_quantity,mp_true_corners);
;
mp_primitive(mp,"mpprocset",mp_internal_quantity,mp_procset);
;
mp_primitive(mp,"troffmode",mp_internal_quantity,mp_gtroffmode);
;
mp_primitive(mp,"defaultcolormodel",mp_internal_quantity,mp_default_color_model);
;
mp_primitive(mp,"restoreclipcolor",mp_internal_quantity,mp_restore_clip_color);
;
mp_primitive(mp,"outputtemplate",mp_internal_quantity,mp_output_template);
;
mp_primitive(mp,"outputfilename",mp_internal_quantity,mp_output_filename);
;
mp_primitive(mp,"numbersystem",mp_internal_quantity,mp_number_system);
;
mp_primitive(mp,"numberprecision",mp_internal_quantity,mp_number_precision);
;
mp_primitive(mp,"outputformat",mp_internal_quantity,mp_output_format);
;
mp_primitive(mp,"outputformatoptions",mp_internal_quantity,mp_output_format_options);
;
mp_primitive(mp,"jobname",mp_internal_quantity,mp_job_name);

mp_primitive(mp,"hppp",mp_internal_quantity,mp_hppp);
;
mp_primitive(mp,"vppp",mp_internal_quantity,mp_vppp);
;


/*:205*//*239:*/
#line 4947 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"..",mp_path_join,0);
;
mp_primitive(mp,"[",mp_left_bracket,0);
mp->frozen_left_bracket= mp_frozen_primitive(mp,"[",mp_left_bracket,0);
;
mp_primitive(mp,"]",mp_right_bracket,0);
;
mp_primitive(mp,"}",mp_right_brace,0);
;
mp_primitive(mp,"{",mp_left_brace,0);
;
mp_primitive(mp,":",mp_colon,0);
mp->frozen_colon= mp_frozen_primitive(mp,":",mp_colon,0);
;
mp_primitive(mp,"::",mp_double_colon,0);
;
mp_primitive(mp,"||:",mp_bchar_label,0);
;
mp_primitive(mp,":=",mp_assignment,0);
;
mp_primitive(mp,",",mp_comma,0);
;
mp_primitive(mp,";",mp_semicolon,0);
mp->frozen_semicolon= mp_frozen_primitive(mp,";",mp_semicolon,0);
;
mp_primitive(mp,"\\",mp_relax,0);
;
mp_primitive(mp,"addto",mp_add_to_command,0);
;
mp_primitive(mp,"atleast",mp_at_least,0);
;
mp_primitive(mp,"begingroup",mp_begin_group,0);
mp->bg_loc= cur_sym();
;
mp_primitive(mp,"controls",mp_controls,0);
;
mp_primitive(mp,"curl",mp_curl_command,0);
;
mp_primitive(mp,"delimiters",mp_delimiters,0);
;
mp_primitive(mp,"endgroup",mp_end_group,0);
mp->eg_loc= cur_sym();
mp->frozen_end_group= mp_frozen_primitive(mp,"endgroup",mp_end_group,0);
;
mp_primitive(mp,"everyjob",mp_every_job_command,0);
;
mp_primitive(mp,"exitif",mp_exit_test,0);
;
mp_primitive(mp,"expandafter",mp_expand_after,0);
;
mp_primitive(mp,"interim",mp_interim_command,0);
;
mp_primitive(mp,"let",mp_let_command,0);
;
mp_primitive(mp,"newinternal",mp_new_internal,0);
;
mp_primitive(mp,"of",mp_of_token,0);
;
mp_primitive(mp,"randomseed",mp_random_seed,0);
;
mp_primitive(mp,"save",mp_save_command,0);
;
mp_primitive(mp,"scantokens",mp_scan_tokens,0);
;

mp_primitive(mp,"runscript",mp_runscript,0);
;
mp_primitive(mp,"maketext",mp_maketext,0);
;

mp_primitive(mp,"shipout",mp_ship_out_command,0);
;
mp_primitive(mp,"skipto",mp_skip_to,0);
;
mp_primitive(mp,"special",mp_special_command,0);
;
mp_primitive(mp,"fontmapfile",mp_special_command,1);
;
mp_primitive(mp,"fontmapline",mp_special_command,2);
;
mp_primitive(mp,"step",mp_step_token,0);
;
mp_primitive(mp,"str",mp_str_op,0);
;
mp_primitive(mp,"void",mp_void_op,0);
;
mp_primitive(mp,"tension",mp_tension,0);
;
mp_primitive(mp,"to",mp_to_token,0);
;
mp_primitive(mp,"until",mp_until_token,0);
;
mp_primitive(mp,"within",mp_within_token,0);
;
mp_primitive(mp,"write",mp_write_command,0);



/*:239*//*743:*/
#line 18960 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"btex",mp_start_tex,btex_code);
;
mp_primitive(mp,"verbatimtex",mp_start_tex,verbatim_code);
;
mp_primitive(mp,"etex",mp_etex_marker,0);
mp->frozen_etex= mp_frozen_primitive(mp,"etex",mp_etex_marker,0);
;
mp_primitive(mp,"mpxbreak",mp_mpx_break,0);
mp->frozen_mpx_break= mp_frozen_primitive(mp,"mpxbreak",mp_mpx_break,0);



/*:743*//*753:*/
#line 19118 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"def",mp_macro_def,start_def);
;
mp_primitive(mp,"vardef",mp_macro_def,var_def);
;
mp_primitive(mp,"primarydef",mp_macro_def,mp_secondary_primary_macro);
;
mp_primitive(mp,"secondarydef",mp_macro_def,mp_tertiary_secondary_macro);
;
mp_primitive(mp,"tertiarydef",mp_macro_def,mp_expression_tertiary_macro);
;
mp_primitive(mp,"enddef",mp_macro_def,end_def);
mp->frozen_end_def= mp_frozen_primitive(mp,"enddef",mp_macro_def,end_def);
;
mp_primitive(mp,"for",mp_iteration,start_for);
;
mp_primitive(mp,"forsuffixes",mp_iteration,start_forsuffixes);
;
mp_primitive(mp,"forever",mp_iteration,start_forever);
;
mp_primitive(mp,"endfor",mp_iteration,end_for);
mp->frozen_end_for= mp_frozen_primitive(mp,"endfor",mp_iteration,end_for);



/*:753*//*761:*/
#line 19303 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"quote",mp_macro_special,quote);
;
mp_primitive(mp,"#@",mp_macro_special,macro_prefix);
;
mp_primitive(mp,"@",mp_macro_special,macro_at);
;
mp_primitive(mp,"@#",mp_macro_special,macro_suffix);



/*:761*//*767:*/
#line 19436 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"expr",mp_param_type,mp_expr_param);
;
mp_primitive(mp,"suffix",mp_param_type,mp_suffix_param);
;
mp_primitive(mp,"text",mp_param_type,mp_text_param);
;
mp_primitive(mp,"primary",mp_param_type,mp_primary_macro);
;
mp_primitive(mp,"secondary",mp_param_type,mp_secondary_macro);
;
mp_primitive(mp,"tertiary",mp_param_type,mp_tertiary_macro);



/*:767*//*779:*/
#line 19801 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"input",mp_input,0);
;
mp_primitive(mp,"endinput",mp_input,1);



/*:779*//*821:*/
#line 20779 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"if",mp_if_test,if_code);
;
mp_primitive(mp,"fi",mp_fi_or_else,fi_code);
mp->frozen_fi= mp_frozen_primitive(mp,"fi",mp_fi_or_else,fi_code);
;
mp_primitive(mp,"else",mp_fi_or_else,else_code);
;
mp_primitive(mp,"elseif",mp_fi_or_else,else_if_code);



/*:821*//*967:*/
#line 25109 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"true",mp_nullary,mp_true_code);
;
mp_primitive(mp,"false",mp_nullary,mp_false_code);
;
mp_primitive(mp,"nullpicture",mp_nullary,mp_null_picture_code);
;
mp_primitive(mp,"nullpen",mp_nullary,mp_null_pen_code);
;
mp_primitive(mp,"readstring",mp_nullary,mp_read_string_op);
;
mp_primitive(mp,"pencircle",mp_nullary,mp_pen_circle);
;
mp_primitive(mp,"normaldeviate",mp_nullary,mp_normal_deviate);
;
mp_primitive(mp,"readfrom",mp_unary,mp_read_from_op);
;
mp_primitive(mp,"closefrom",mp_unary,mp_close_from_op);
;
mp_primitive(mp,"odd",mp_unary,mp_odd_op);
;
mp_primitive(mp,"known",mp_unary,mp_known_op);
;
mp_primitive(mp,"unknown",mp_unary,mp_unknown_op);
;
mp_primitive(mp,"not",mp_unary,mp_not_op);
;
mp_primitive(mp,"decimal",mp_unary,mp_decimal);
;
mp_primitive(mp,"reverse",mp_unary,mp_reverse);
;
mp_primitive(mp,"makepath",mp_unary,mp_make_path_op);
;
mp_primitive(mp,"makepen",mp_unary,mp_make_pen_op);
;
mp_primitive(mp,"oct",mp_unary,mp_oct_op);
;
mp_primitive(mp,"hex",mp_unary,mp_hex_op);
;
mp_primitive(mp,"ASCII",mp_unary,mp_ASCII_op);
;
mp_primitive(mp,"char",mp_unary,mp_char_op);
;
mp_primitive(mp,"length",mp_unary,mp_length_op);
;
mp_primitive(mp,"turningnumber",mp_unary,mp_turning_op);
;
mp_primitive(mp,"xpart",mp_unary,mp_x_part);
;
mp_primitive(mp,"ypart",mp_unary,mp_y_part);
;
mp_primitive(mp,"xxpart",mp_unary,mp_xx_part);
;
mp_primitive(mp,"xypart",mp_unary,mp_xy_part);
;
mp_primitive(mp,"yxpart",mp_unary,mp_yx_part);
;
mp_primitive(mp,"yypart",mp_unary,mp_yy_part);
;
mp_primitive(mp,"redpart",mp_unary,mp_red_part);
;
mp_primitive(mp,"greenpart",mp_unary,mp_green_part);
;
mp_primitive(mp,"bluepart",mp_unary,mp_blue_part);
;
mp_primitive(mp,"cyanpart",mp_unary,mp_cyan_part);
;
mp_primitive(mp,"magentapart",mp_unary,mp_magenta_part);
;
mp_primitive(mp,"yellowpart",mp_unary,mp_yellow_part);
;
mp_primitive(mp,"blackpart",mp_unary,mp_black_part);
;
mp_primitive(mp,"greypart",mp_unary,mp_grey_part);
;
mp_primitive(mp,"colormodel",mp_unary,mp_color_model_part);
;
mp_primitive(mp,"fontpart",mp_unary,mp_font_part);
;
mp_primitive(mp,"textpart",mp_unary,mp_text_part);
;
mp_primitive(mp,"prescriptpart",mp_unary,mp_prescript_part);
;
mp_primitive(mp,"postscriptpart",mp_unary,mp_postscript_part);
;
mp_primitive(mp,"pathpart",mp_unary,mp_path_part);
;
mp_primitive(mp,"penpart",mp_unary,mp_pen_part);
;
mp_primitive(mp,"dashpart",mp_unary,mp_dash_part);
;
mp_primitive(mp,"sqrt",mp_unary,mp_sqrt_op);
;
mp_primitive(mp,"mexp",mp_unary,mp_m_exp_op);
;
mp_primitive(mp,"mlog",mp_unary,mp_m_log_op);
;
mp_primitive(mp,"sind",mp_unary,mp_sin_d_op);
;
mp_primitive(mp,"cosd",mp_unary,mp_cos_d_op);
;
mp_primitive(mp,"floor",mp_unary,mp_floor_op);
;
mp_primitive(mp,"uniformdeviate",mp_unary,mp_uniform_deviate);
;
mp_primitive(mp,"charexists",mp_unary,mp_char_exists_op);
;
mp_primitive(mp,"fontsize",mp_unary,mp_font_size);
;
mp_primitive(mp,"llcorner",mp_unary,mp_ll_corner_op);
;
mp_primitive(mp,"lrcorner",mp_unary,mp_lr_corner_op);
;
mp_primitive(mp,"ulcorner",mp_unary,mp_ul_corner_op);
;
mp_primitive(mp,"urcorner",mp_unary,mp_ur_corner_op);
;
mp_primitive(mp,"arclength",mp_unary,mp_arc_length);
;
mp_primitive(mp,"angle",mp_unary,mp_angle_op);
;
mp_primitive(mp,"cycle",mp_cycle,mp_cycle_op);
;
mp_primitive(mp,"stroked",mp_unary,mp_stroked_op);
;
mp_primitive(mp,"filled",mp_unary,mp_filled_op);
;
mp_primitive(mp,"textual",mp_unary,mp_textual_op);
;
mp_primitive(mp,"clipped",mp_unary,mp_clipped_op);
;
mp_primitive(mp,"bounded",mp_unary,mp_bounded_op);
;
mp_primitive(mp,"+",mp_plus_or_minus,mp_plus);
;
mp_primitive(mp,"-",mp_plus_or_minus,mp_minus);
;
mp_primitive(mp,"*",mp_secondary_binary,mp_times);
;
mp_primitive(mp,"/",mp_slash,mp_over);
mp->frozen_slash= mp_frozen_primitive(mp,"/",mp_slash,mp_over);
;
mp_primitive(mp,"++",mp_tertiary_binary,mp_pythag_add);
;
mp_primitive(mp,"+-+",mp_tertiary_binary,mp_pythag_sub);
;
mp_primitive(mp,"or",mp_tertiary_binary,mp_or_op);
;
mp_primitive(mp,"and",mp_and_command,mp_and_op);
;
mp_primitive(mp,"<",mp_expression_binary,mp_less_than);
;
mp_primitive(mp,"<=",mp_expression_binary,mp_less_or_equal);
;
mp_primitive(mp,">",mp_expression_binary,mp_greater_than);
;
mp_primitive(mp,">=",mp_expression_binary,mp_greater_or_equal);
;
mp_primitive(mp,"=",mp_equals,mp_equal_to);
;
mp_primitive(mp,"<>",mp_expression_binary,mp_unequal_to);
;
mp_primitive(mp,"substring",mp_primary_binary,mp_substring_of);
;
mp_primitive(mp,"subpath",mp_primary_binary,mp_subpath_of);
;
mp_primitive(mp,"directiontime",mp_primary_binary,mp_direction_time_of);
;
mp_primitive(mp,"point",mp_primary_binary,mp_point_of);
;
mp_primitive(mp,"precontrol",mp_primary_binary,mp_precontrol_of);
;
mp_primitive(mp,"postcontrol",mp_primary_binary,mp_postcontrol_of);
;
mp_primitive(mp,"penoffset",mp_primary_binary,mp_pen_offset_of);
;
mp_primitive(mp,"arctime",mp_primary_binary,mp_arc_time_of);
;
mp_primitive(mp,"mpversion",mp_nullary,mp_version);
;
mp_primitive(mp,"&",mp_ampersand,mp_concatenate);
;
mp_primitive(mp,"rotated",mp_secondary_binary,mp_rotated_by);
;
mp_primitive(mp,"slanted",mp_secondary_binary,mp_slanted_by);
;
mp_primitive(mp,"scaled",mp_secondary_binary,mp_scaled_by);
;
mp_primitive(mp,"shifted",mp_secondary_binary,mp_shifted_by);
;
mp_primitive(mp,"transformed",mp_secondary_binary,mp_transformed_by);
;
mp_primitive(mp,"xscaled",mp_secondary_binary,mp_x_scaled);
;
mp_primitive(mp,"yscaled",mp_secondary_binary,mp_y_scaled);
;
mp_primitive(mp,"zscaled",mp_secondary_binary,mp_z_scaled);
;
mp_primitive(mp,"infont",mp_secondary_binary,mp_in_font);
;
mp_primitive(mp,"intersectiontimes",mp_tertiary_binary,mp_intersect);
;
mp_primitive(mp,"envelope",mp_primary_binary,mp_envelope_of);
;
mp_primitive(mp,"boundingpath",mp_primary_binary,mp_boundingpath_of);
;
mp_primitive(mp,"glyph",mp_primary_binary,mp_glyph_infont);



/*:967*//*1058:*/
#line 30221 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"numeric",mp_type_name,mp_numeric_type);
;
mp_primitive(mp,"string",mp_type_name,mp_string_type);
;
mp_primitive(mp,"boolean",mp_type_name,mp_boolean_type);
;
mp_primitive(mp,"path",mp_type_name,mp_path_type);
;
mp_primitive(mp,"pen",mp_type_name,mp_pen_type);
;
mp_primitive(mp,"picture",mp_type_name,mp_picture_type);
;
mp_primitive(mp,"transform",mp_type_name,mp_transform_type);
;
mp_primitive(mp,"color",mp_type_name,mp_color_type);
;
mp_primitive(mp,"rgbcolor",mp_type_name,mp_color_type);
;
mp_primitive(mp,"cmykcolor",mp_type_name,mp_cmykcolor_type);
;
mp_primitive(mp,"pair",mp_type_name,mp_pair_type);



/*:1058*//*1083:*/
#line 30903 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"end",mp_stop,0);
;
mp_primitive(mp,"dump",mp_stop,1);
mp->frozen_dump= mp_frozen_primitive(mp,"dump",mp_stop,1);



/*:1083*//*1090:*/
#line 30975 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"batchmode",mp_mode_command,mp_batch_mode);
;
mp_primitive(mp,"nonstopmode",mp_mode_command,mp_nonstop_mode);
;
mp_primitive(mp,"scrollmode",mp_mode_command,mp_scroll_mode);
;
mp_primitive(mp,"errorstopmode",mp_mode_command,mp_error_stop_mode);



/*:1090*//*1093:*/
#line 31006 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"inner",mp_protection_command,0);
;
mp_primitive(mp,"outer",mp_protection_command,1);



/*:1093*//*1111:*/
#line 31253 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"showtoken",mp_show_command,show_token_code);
;
mp_primitive(mp,"showstats",mp_show_command,show_stats_code);
;
mp_primitive(mp,"show",mp_show_command,show_code);
;
mp_primitive(mp,"showvariable",mp_show_command,show_var_code);
;
mp_primitive(mp,"showdependencies",mp_show_command,show_dependencies_code);



/*:1111*//*1134:*/
#line 31580 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"doublepath",mp_thing_to_add,double_path_code);
;
mp_primitive(mp,"contour",mp_thing_to_add,contour_code);
;
mp_primitive(mp,"also",mp_thing_to_add,also_code);
;
mp_primitive(mp,"withpen",mp_with_option,mp_pen_type);
;
mp_primitive(mp,"dashed",mp_with_option,mp_picture_type);
;
mp_primitive(mp,"withprescript",mp_with_option,with_mp_pre_script);
;
mp_primitive(mp,"withpostscript",mp_with_option,with_mp_post_script);
;
mp_primitive(mp,"withoutcolor",mp_with_option,mp_no_model);
;
mp_primitive(mp,"withgreyscale",mp_with_option,mp_grey_model);
;
mp_primitive(mp,"withcolor",mp_with_option,mp_uninitialized_model);


mp_primitive(mp,"withrgbcolor",mp_with_option,mp_rgb_model);
;
mp_primitive(mp,"withcmykcolor",mp_with_option,mp_cmyk_model);



/*:1134*//*1140:*/
#line 32062 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"clip",mp_bounds_command,mp_start_clip_node_type);
;
mp_primitive(mp,"setbounds",mp_bounds_command,mp_start_bounds_node_type);



/*:1140*//*1155:*/
#line 32371 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"message",mp_message_command,message_code);
;
mp_primitive(mp,"errmessage",mp_message_command,err_message_code);
;
mp_primitive(mp,"errhelp",mp_message_command,err_help_code);
;
mp_primitive(mp,"filenametemplate",mp_message_command,filename_template_code);



/*:1155*//*1187:*/
#line 33036 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"charlist",mp_tfm_command,char_list_code);
;
mp_primitive(mp,"ligtable",mp_tfm_command,lig_table_code);
;
mp_primitive(mp,"extensible",mp_tfm_command,extensible_code);
;
mp_primitive(mp,"headerbyte",mp_tfm_command,header_byte_code);
;
mp_primitive(mp,"fontdimen",mp_tfm_command,font_dimen_code);



/*:1187*//*1197:*/
#line 33266 "../../../source/texk/web2c/mplibdir/mp.w"

mp_primitive(mp,"=:",mp_lig_kern_token,0);
;
mp_primitive(mp,"=:|",mp_lig_kern_token,1);
;
mp_primitive(mp,"=:|>",mp_lig_kern_token,5);
;
mp_primitive(mp,"|=:",mp_lig_kern_token,2);
;
mp_primitive(mp,"|=:>",mp_lig_kern_token,6);
;
mp_primitive(mp,"|=:|",mp_lig_kern_token,3);
;
mp_primitive(mp,"|=:|>",mp_lig_kern_token,7);
;
mp_primitive(mp,"|=:|>>",mp_lig_kern_token,11);
;
mp_primitive(mp,"kern",mp_lig_kern_token,mp_kern_flag);



/*:1197*/
#line 35552 "../../../source/texk/web2c/mplibdir/mp.w"
;
}

void mp_init_tab(MP mp){
/*187:*/
#line 3162 "../../../source/texk/web2c/mplibdir/mp.w"

mp->spec_head= mp_get_symbolic_node(mp);
mp->last_pending= mp->spec_head;
mp->temp_head= mp_get_symbolic_node(mp);
mp->hold_head= mp_get_symbolic_node(mp);

/*:187*//*207:*/
#line 4293 "../../../source/texk/web2c/mplibdir/mp.w"

set_internal_from_number(mp_default_color_model,unity_t);
number_multiply_int(internal_value(mp_default_color_model),mp_rgb_model);
number_clone(internal_value(mp_restore_clip_color),unity_t);
number_clone(internal_value(mp_hppp),unity_t);
number_clone(internal_value(mp_vppp),unity_t);
set_internal_string(mp_output_template,mp_intern(mp,"%j.%c"));
set_internal_string(mp_output_filename,mp_intern(mp,""));
set_internal_string(mp_output_format,mp_intern(mp,"eps"));
set_internal_string(mp_output_format_options,mp_intern(mp,""));
set_internal_string(mp_number_system,mp_intern(mp,"scaled"));
set_internal_from_number(mp_number_precision,precision_default);
set_internal_from_number(mp_texscriptmode,unity_t);
#if DEBUG
number_clone(internal_value(mp_tracing_titles),three_t);
number_clone(internal_value(mp_tracing_equations),three_t);
number_clone(internal_value(mp_tracing_capsules),three_t);
number_clone(internal_value(mp_tracing_choices),three_t);
number_clone(internal_value(mp_tracing_specs),three_t);
number_clone(internal_value(mp_tracing_commands),three_t);
number_clone(internal_value(mp_tracing_restores),three_t);
number_clone(internal_value(mp_tracing_macros),three_t);
number_clone(internal_value(mp_tracing_output),three_t);
number_clone(internal_value(mp_tracing_stats),three_t);
number_clone(internal_value(mp_tracing_lost_chars),three_t);
number_clone(internal_value(mp_tracing_online),three_t);
#endif

/*:207*//*208:*/
#line 4324 "../../../source/texk/web2c/mplibdir/mp.w"

set_internal_name(mp_tracing_titles,xstrdup("tracingtitles"));
set_internal_name(mp_tracing_equations,xstrdup("tracingequations"));
set_internal_name(mp_tracing_capsules,xstrdup("tracingcapsules"));
set_internal_name(mp_tracing_choices,xstrdup("tracingchoices"));
set_internal_name(mp_tracing_specs,xstrdup("tracingspecs"));
set_internal_name(mp_tracing_commands,xstrdup("tracingcommands"));
set_internal_name(mp_tracing_restores,xstrdup("tracingrestores"));
set_internal_name(mp_tracing_macros,xstrdup("tracingmacros"));
set_internal_name(mp_tracing_output,xstrdup("tracingoutput"));
set_internal_name(mp_tracing_stats,xstrdup("tracingstats"));
set_internal_name(mp_tracing_lost_chars,xstrdup("tracinglostchars"));
set_internal_name(mp_tracing_online,xstrdup("tracingonline"));
set_internal_name(mp_year,xstrdup("year"));
set_internal_name(mp_month,xstrdup("month"));
set_internal_name(mp_day,xstrdup("day"));
set_internal_name(mp_time,xstrdup("time"));
set_internal_name(mp_hour,xstrdup("hour"));
set_internal_name(mp_minute,xstrdup("minute"));
set_internal_name(mp_char_code,xstrdup("charcode"));
set_internal_name(mp_char_ext,xstrdup("charext"));
set_internal_name(mp_char_wd,xstrdup("charwd"));
set_internal_name(mp_char_ht,xstrdup("charht"));
set_internal_name(mp_char_dp,xstrdup("chardp"));
set_internal_name(mp_char_ic,xstrdup("charic"));
set_internal_name(mp_design_size,xstrdup("designsize"));
set_internal_name(mp_pausing,xstrdup("pausing"));
set_internal_name(mp_showstopping,xstrdup("showstopping"));
set_internal_name(mp_fontmaking,xstrdup("fontmaking"));
set_internal_name(mp_texscriptmode,xstrdup("texscriptmode"));
set_internal_name(mp_linejoin,xstrdup("linejoin"));
set_internal_name(mp_linecap,xstrdup("linecap"));
set_internal_name(mp_miterlimit,xstrdup("miterlimit"));
set_internal_name(mp_warning_check,xstrdup("warningcheck"));
set_internal_name(mp_boundary_char,xstrdup("boundarychar"));
set_internal_name(mp_prologues,xstrdup("prologues"));
set_internal_name(mp_true_corners,xstrdup("truecorners"));
set_internal_name(mp_default_color_model,xstrdup("defaultcolormodel"));
set_internal_name(mp_procset,xstrdup("mpprocset"));
set_internal_name(mp_gtroffmode,xstrdup("troffmode"));
set_internal_name(mp_restore_clip_color,xstrdup("restoreclipcolor"));
set_internal_name(mp_output_template,xstrdup("outputtemplate"));
set_internal_name(mp_output_filename,xstrdup("outputfilename"));
set_internal_name(mp_output_format,xstrdup("outputformat"));
set_internal_name(mp_output_format_options,xstrdup("outputformatoptions"));
set_internal_name(mp_job_name,xstrdup("jobname"));
set_internal_name(mp_number_system,xstrdup("numbersystem"));
set_internal_name(mp_number_precision,xstrdup("numberprecision"));
set_internal_name(mp_hppp,xstrdup("hppp"));
set_internal_name(mp_vppp,xstrdup("vppp"));

/*:208*//*231:*/
#line 4757 "../../../source/texk/web2c/mplibdir/mp.w"

mp->id_lookup_test= new_symbols_entry(mp,NULL,0);

/*:231*//*232:*/
#line 4764 "../../../source/texk/web2c/mplibdir/mp.w"

mp->st_count= 0;
mp->frozen_bad_vardef= mp_frozen_primitive(mp,"a bad variable",mp_tag_token,0);
mp->frozen_right_delimiter= mp_frozen_primitive(mp,")",mp_right_delimiter,0);
mp->frozen_inaccessible= mp_frozen_primitive(mp," INACCESSIBLE",mp_tag_token,0);
mp->frozen_undefined= mp_frozen_primitive(mp," UNDEFINED",mp_tag_token,0);

/*:232*//*265:*/
#line 5981 "../../../source/texk/web2c/mplibdir/mp.w"

mp->end_attr= (mp_node)mp_get_attr_node(mp);
set_hashloc(mp->end_attr,(mp_sym)-1);
set_parent((mp_value_node)mp->end_attr,NULL);

/*:265*//*375:*/
#line 8700 "../../../source/texk/web2c/mplibdir/mp.w"

new_fraction(mp->st);
new_fraction(mp->ct);
new_fraction(mp->sf);
new_fraction(mp->cf);

/*:375*//*392:*/
#line 9314 "../../../source/texk/web2c/mplibdir/mp.w"

{
int i;
for(i= 0;i<=mp_y_code;i++){
new_number(mp->bbmin[i]);
new_number(mp->bbmax[i]);
}
}

/*:392*//*455:*/
#line 10896 "../../../source/texk/web2c/mplibdir/mp.w"

new_number(mp->cur_x);
new_number(mp->cur_y);

/*:455*//*486:*/
#line 11686 "../../../source/texk/web2c/mplibdir/mp.w"

mp->null_dash= mp_get_dash_node(mp);

/*:486*//*619:*/
#line 15781 "../../../source/texk/web2c/mplibdir/mp.w"

new_number(mp->cur_t);
new_number(mp->cur_tt);
new_number(mp->max_t);

/*:619*//*623:*/
#line 15938 "../../../source/texk/web2c/mplibdir/mp.w"

new_number(mp->delx);
new_number(mp->dely);
new_number(mp->appr_t);
new_number(mp->appr_tt);

/*:623*//*636:*/
#line 16251 "../../../source/texk/web2c/mplibdir/mp.w"

mp->serial_no= 0;
mp->dep_head= mp_get_dep_node(mp);
set_mp_link(mp->dep_head,(mp_node)mp->dep_head);
set_prev_dep(mp->dep_head,(mp_node)mp->dep_head);
set_dep_info(mp->dep_head,NULL);
set_dep_list(mp->dep_head,NULL);

/*:636*//*676:*/
#line 17506 "../../../source/texk/web2c/mplibdir/mp.w"

mp->cur_mod_= mp_get_symbolic_node(mp);

/*:676*//*771:*/
#line 19642 "../../../source/texk/web2c/mplibdir/mp.w"

mp->bad_vardef= mp_get_value_node(mp);
mp_name_type(mp->bad_vardef)= mp_root;
set_value_sym(mp->bad_vardef,mp->frozen_bad_vardef);

/*:771*//*842:*/
#line 21194 "../../../source/texk/web2c/mplibdir/mp.w"

mp->frozen_repeat_loop=
mp_frozen_primitive(mp," ENDFOR",mp_repeat_loop+mp_outer_tag,0);

/*:842*//*939:*/
#line 23377 "../../../source/texk/web2c/mplibdir/mp.w"

{
int i;
for(i= 0;i<mp_proto_dependent+1;i++){
new_number(mp->max_c[i]);
}
}

/*:939*//*982:*/
#line 26249 "../../../source/texk/web2c/mplibdir/mp.w"

mp->temp_val= mp_get_value_node(mp);
mp_name_type(mp->temp_val)= mp_capsule;

/*:982*//*1012:*/
#line 28337 "../../../source/texk/web2c/mplibdir/mp.w"

new_number(mp->txx);
new_number(mp->txy);
new_number(mp->tyx);
new_number(mp->tyy);
new_number(mp->tx);
new_number(mp->ty);

/*:1012*//*1205:*/
#line 33517 "../../../source/texk/web2c/mplibdir/mp.w"

mp->inf_val= mp_get_value_node(mp);
set_value_number(mp->inf_val,fraction_four_t);

/*:1205*//*1210:*/
#line 33604 "../../../source/texk/web2c/mplibdir/mp.w"

new_number(mp->perturbation);

/*:1210*//*1219:*/
#line 33799 "../../../source/texk/web2c/mplibdir/mp.w"

mp->zero_val= mp_get_value_node(mp);
set_value_number(mp->zero_val,zero_t);

/*:1219*//*1224:*/
#line 33901 "../../../source/texk/web2c/mplibdir/mp.w"

new_number(mp->max_tfm_dimen);

/*:1224*/
#line 35556 "../../../source/texk/web2c/mplibdir/mp.w"
;
}


/*:1309*/
