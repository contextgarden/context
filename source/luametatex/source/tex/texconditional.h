/*
    See license.txt in the root of this project.
*/

# ifndef LMT_CONDITIONAL_H
# define LMT_CONDITIONAL_H

/*tex

    The next list should be in sync with |if_branch_mapping| at the top of the |c| file with the
    same name. The next ones also go on the condition stack so we need to retain this order and
    organization.

    There is a catch here: the codes of the |if_test_cmd|, |fi_or_else_cmd| and |or_else_cmd| are
    all in this enumeration. This has to do with the history of not always checking for the cmd
    code in the fast skipping branches. We could change that but not now.

    Well, in the end I combined |if_test_cmd|, |fi_or_else_cmd| and |or_else_cmd| because they use
    the same chr range anyway and it also simplifies some of the testing (especially after some
    more robust cmd/chr checking was added, and after that the |fi_or_else_cmd| and |or_else_cmd|
    were combined. The main motivation is that we can have a more consistent \LUA\ token interface
    end. It is debatable as we divert from the original, but we already did that by introducing
    more conditionals, |\orelse| and the generic |\ifconditional| that also demandeed all kind of
    adaptations. Sorry. The comments are mostly the same, including references to the older cmd
    codes (pre 2.07 there used to be some switch/case statements in places but these were flattened).

    Btw, the |\unless| prefix is kept out of this because it relates to expansion and prefixes are
    separate anyway. It would make the code less pretty.

    One reason for a split in cmd codes is performance but we didn't loose on the change.

*/

typedef enum if_test_codes {
    /*tex These are private chr codes: */

    no_if_code,             /*tex We're not in a condition. */
    if_code,                /*tex We have a condition. */

    /*tex These are public chr codes: */

    fi_code,                /*tex |\fi| */
    else_code,              /*tex |\else| */
    or_code,                /*tex |\or| */
    or_else_code,           /*tex |\orelse| */
    or_unless_code,         /*tex |\orunless| */

    /*tex 
        Here come the \if... codes. Some are just there to minimize tracing and are not faster, 
        like |\ifzerodim| (we can use |\ifcase| instead but not with |\unless|). 
    */

    if_char_code,           /*tex |\if| */
    if_cat_code,            /*tex |\ifcat| */
    if_int_code,            /*tex |\ifnum| */
    if_abs_int_code,        /*tex |\ifabsnum| */ 
    if_zero_int_code,       /*tex |\ifzeronum|*/
    if_dim_code,            /*tex |\ifdim| */
    if_abs_dim_code,        /*tex |\ifabsdim| */
    if_zero_dim_code,       /*tex |\ifzerodim| */
    if_odd_code,            /*tex |\ifodd| */
    if_vmode_code,          /*tex |\ifvmode| */
    if_hmode_code,          /*tex |\ifhmode| */
    if_mmode_code,          /*tex |\ifmmode| */
    if_inner_code,          /*tex |\ifinner| */
    if_void_code,           /*tex |\ifvoid| */
    if_hbox_code,           /*tex |\ifhbox| */
    if_vbox_code,           /*tex |\ifvbox| */
    if_tok_code,            /*tex |\iftok| */
    if_cstok_code,          /*tex |\ifcstok| */
    if_x_code,              /*tex |\ifx| */
    if_true_code,           /*tex |\iftrue| */
    if_false_code,          /*tex |\iffalse| */
    if_chk_int_code,        /*tex |\ifchknum| */
    if_val_int_code,        /*tex |\ifcmpnum| */
    if_cmp_int_code,        /*tex |\ifcmpnum| */
    if_chk_dim_code,        /*tex |\ifchkdim| */
    if_val_dim_code,        /*tex |\ifchkdim| */
    if_cmp_dim_code,        /*tex |\ifcmpdim| */
    if_case_code,           /*tex |\ifcase| */
    if_def_code,            /*tex |\ifdefined| */
    if_cs_code,             /*tex |\ifcsname| */
    if_in_csname_code,      /*tex |\ifincsname| */
    if_font_char_code,      /*tex |\iffontchar| */
    if_condition_code,      /*tex |\ifcondition| */
    if_flags_code,          /*tex |\ifflags| */
    if_empty_cmd_code,      /*tex |\ifempty| */
    if_relax_cmd_code,      /*tex |\ifrelax| */
    if_boolean_code,        /*tex |\ifboolean| */
    if_numexpression_code,  /*tex |\ifnumexpression| */
    if_dimexpression_code,  /*tex |\ifdimexpression| */
    if_math_parameter_code, /*tex |\ifmathparameter| */
    if_math_style_code,     /*tex |\ifmathstyle| */
    if_arguments_code,      /*tex |\ifarguments| */
    if_parameters_code,     /*tex |\ifparameters| */
    if_parameter_code,      /*tex |\ifparameter| */
    if_has_tok_code,        /*tex |\ifhastok| */
    if_has_toks_code,       /*tex |\ifhastoks| */
    if_has_xtoks_code,      /*tex |\ifhasxtoks| */
    if_has_char_code,       /*tex |\ifhaschar| */
    if_insert_code,         /*tex |\ifinsert| */
 // if_bitwise_and_code,    /*tex |\ifbitwiseand| */
} if_test_codes;

# define first_if_test_code fi_code
# define last_if_test_code  if_insert_code
//define last_if_test_code  if_bitwise_and_code

# define first_real_if_test_code if_char_code
# define last_real_if_test_code  if_insert_code
//define last_real_if_test_code  if_bitwise_and_code

typedef struct condition_state_info {
    halfword  cond_ptr;       /*tex top of the condition stack */
    int       cur_if;         /*tex type of conditional being worked on */
    int       cur_unless;
    int       if_step;
    int       if_unless;
    int       if_limit;       /*tex upper bound on |fi_or_else| codes */
    int       if_line;        /*tex line where that conditional began */
    int       skip_line;      /*tex skipping began here */
    halfword  chk_num;
    scaled    chk_dim;
    halfword  if_nesting;
    halfword  padding;
} condition_state_info ;

extern condition_state_info lmt_condition_state;

extern void tex_conditional_if         (halfword code, int unless);
extern void tex_conditional_fi_or_else (void);
extern void tex_conditional_unless     (void);
extern void tex_show_ifs               (void);
/*     void tex_conditional_after_fi   (void); */

# endif
