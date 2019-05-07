/*
    See license.txt in the root of this project.
*/

# ifndef CONDITIONAL_H
# define CONDITIONAL_H

/*tex The amount added for the |\unless| prefix: */

# define unless_code 64

typedef enum {
    if_char_code       =  0, /*tex |\if| */
    if_cat_code        =  1, /*tex |\ifcat| */
    if_abs_int_code    =  2, /*tex |\ifabsnum| */
    if_int_code        =  3, /*tex |\ifnum| */
    if_abs_dim_code    =  4, /*tex |\ifabsdim| */
    if_dim_code        =  5, /*tex |\ifdim| */
    if_odd_code        =  6, /*tex |\ifodd| */
    if_vmode_code      =  7, /*tex |\ifvmode| */
    if_hmode_code      =  8, /*tex |\ifhmode| */
    if_mmode_code      =  9, /*tex |\ifmmode| */
    if_inner_code      = 10, /*tex |\ifinner| */
    if_void_code       = 11, /*tex |\ifvoid| */
    if_hbox_code       = 12, /*tex |\ifhbox| */
    if_vbox_code       = 13, /*tex |\ifvbox| */
    if_tok_code        = 14, /*tex |\ifx| */
    if_x_code          = 15, /*tex |\ifx| */
    if_true_code       = 16, /*tex |\iftrue| */
    if_false_code      = 17, /*tex |\iffalse| */
    if_chk_int_code    = 18, /*tex |\ifchknum| */
    if_val_int_code    = 19, /*tex |\ifcmpnum| */
    if_cmp_int_code    = 20, /*tex |\ifcmpnum| */
    if_chk_dim_code    = 21, /*tex |\ifchkdim| */
    if_val_dim_code    = 22, /*tex |\ifchkdim| */
    if_cmp_dim_code    = 23, /*tex |\ifcmpdim| */
    if_case_code       = 24, /*tex |\ifcase| */
    if_def_code        = 25, /*tex |\ifdefined| */
    if_cs_code         = 26, /*tex |\ifcsname| */
    if_in_csname_code  = 27, /*tex |\ifincsname| */
    if_font_char_code  = 28, /*tex |\iffontchar| */
    if_condition_code  = 29, /*tex |\ifcondition| */
    if_eof_code        = 30, /*tex |\ifeof| */
 // if_primitive_code  = 31, /*tex |\ifprimitive| */
} if_type_codes;

# define if_limit_subtype(A) subtype((A)+1)
# define if_limit_type(A) type((A)+1)
# define if_line_field(A) vlink((A)+1)

typedef enum {
    if_code   = 1, /*tex |\if...| */
    fi_code   = 2, /*tex |\fi|    */
    else_code = 3, /*tex |\else|  */
    or_code   = 4, /*tex |\or|    */
} else_type_codes;

typedef struct condition_state_info {
    halfword cond_ptr;       /*tex top of the condition stack */
    int if_limit;            /*tex upper bound on |fi_or_else| codes */
    int cur_if;              /*tex type of conditional being worked on */
    int if_line;             /*tex line where that conditional began */
    int skip_line;           /*tex skipping began here */
    halfword last_tested_cs;
    halfword *if_stack;      /*tex initial |cond_ptr| */
} condition_state_info ;

extern condition_state_info condition_state ;

# define cond_ptr       condition_state.cond_ptr
# define if_limit       condition_state.if_limit
# define cur_if         condition_state.cur_if
# define if_line        condition_state.if_line
# define skip_line      condition_state.skip_line
# define last_tested_cs condition_state.last_tested_cs
# define if_stack       condition_state.if_stack

extern void pass_text(void);
extern void push_condition_stack(void);
extern void pop_condition_stack(void);
extern void change_if_limit(int l, halfword p);

extern void conditional(void);

# endif
