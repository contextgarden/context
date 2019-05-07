/*
    See license.txt in the root of this project.
*/

# ifndef MAINCONTROL_H
# define MAINCONTROL_H

# define fil_code     0 /* identifies |\hfil| and |\vfil| */
# define fill_code    1 /* identifies |\hfill| and |\vfill| */
# define ss_code      2 /* identifies |\hss| and |\vss| */
# define fil_neg_code 3 /* identifies |\hfilneg} and |\vfilneg| */
# define skip_code    4 /* identifies |\hskip| and |\vskip| */
# define mskip_code   5 /* identifies |\mskip| */

/*tex

    The |prefixed_command| does not have to adjust |a| so that |a mod 4=0|,
    since the following routines test for the |\global| prefix as follows.

*/

# define is_global(a) (a>=4)

# define define(A,B,C) do { \
    if (is_global(a)) \
        geq_define((A),(quarterword)(B),(C)); \
    else \
        eq_define((A),(quarterword)(B),(C)); \
} while (0)

# define word_define(A,B) do { \
    if (is_global(a)) \
        geq_word_define((A),(B)); \
    else \
        eq_word_define((A),(B)); \
} while (0)

# define define_lc_code(A,B) do { \
    if (is_global(a)) \
        set_lc_code((A),(B),level_one); \
    else \
        set_lc_code((A),(B),cur_level); \
} while (0)

# define define_uc_code(A,B) do { \
    if (is_global(a)) \
        set_uc_code((A),(B),level_one); \
    else \
        set_uc_code((A),(B),cur_level); \
} while (0)

# define define_sf_code(A,B) do { \
     if (is_global(a)) \
       set_sf_code((A),(B),level_one); \
     else \
       set_sf_code((A),(B),cur_level); \
   } while (0)

# define define_cat_code(A,B) do { \
     if (is_global(a)) \
       set_cat_code(cat_code_table_par,(A),(B),level_one); \
     else \
       set_cat_code(cat_code_table_par,(A),(B),cur_level); \
   } while (0)

# define define_fam_fnt(A,B,C) do { \
    if (is_global(a)) \
        def_fam_fnt((A),(B),(C),level_one); \
    else \
        def_fam_fnt((A),(B),(C),cur_level); \
} while (0)

# define define_math_param(A,B,C) do { \
    if (is_global(a)) \
        def_math_param((A),(B),(C),level_one); \
    else \
        def_math_param((A),(B),(C),cur_level); \
} while (0)

/*tex The box to be placed into its context: */

/* extern halfword cur_box; */

/*tex

   A |\chardef| creates a control sequence whose |cmd| is |char_given|; a
   |\mathchardef| creates a control sequence whose |cmd| is |math_given|; and the
   corresponding |chr| is the character code or math code. A |\countdef| or
   |\dimendef| or |\skipdef| or |\muskipdef| creates a control sequence whose
   |cmd| is |assign_int| or \dots\ or |assign_mu_glue|, and the corresponding
   |chr| is the |eqtb| location of the internal register in question.

*/

# define char_def_code       0 /*tex |shorthand_def| for |\chardef| */
# define math_char_def_code  1 /*tex |shorthand_def| for |\mathchardef| */
# define xmath_char_def_code 2 /*tex |shorthand_def| for |\Umathchardef| */
# define count_def_code      3 /*tex |shorthand_def| for |\countdef| */
# define attribute_def_code  4 /*tex |shorthand_def| for |\attributedef| */
# define dimen_def_code      5 /*tex |shorthand_def| for |\dimendef| */
# define skip_def_code       6 /*tex |shorthand_def| for |\skipdef| */
# define mu_skip_def_code    7 /*tex |shorthand_def| for |\muskipdef| */
# define toks_def_code       8 /*tex |shorthand_def| for |\toksdef| */
# define umath_char_def_code 9 /*tex |shorthand_def| for |\Umathcharnumdef| */

extern void main_control(void);
extern void normal_paragraph(void);
extern void new_graf(int indented);
extern void end_graf(int);
extern void you_cant(void);
extern void off_save(void);
extern void prefixed_command(void);
extern void box_end(int box_context);

/*tex Assignments from Lua need helpers. */

# define is_int_assign(cmd)     (cmd==assign_int_cmd)
# define is_attr_assign(cmd)    (cmd==assign_attr_cmd)
# define is_dim_assign(cmd)     (cmd==assign_dimen_cmd)
# define is_glue_assign(cmd)    (cmd==assign_glue_cmd)
# define is_mu_glue_assign(cmd) (cmd==assign_mu_glue_cmd)
# define is_toks_assign(cmd)    (cmd==assign_toks_cmd)

# define show_code     0 /*tex |\show| */
# define show_box_code 1 /*tex |\showbox| */
# define show_the_code 2 /*tex |\showthe| */
# define show_lists    3 /*tex |\showlists| */
# define show_groups   4 /*tex |\showgroups| */
# define show_tokens   5 /*tex |\showtokens|, must be odd! */
# define show_ifs      6 /*tex |\showifs| */

# define print_if_line(A) if ((A)!=0) { \
    tprint(" entered on line "); print_int((A)); \
}

# define swap_hang_indent(indentation) \
    ( ((shape_mode_par == 1 || shape_mode_par == 3 || shape_mode_par == -1 || shape_mode_par == -3)) ? negate(indentation) : indentation )

# define swap_parshape_indent(indentation,width) \
    ( ((shape_mode_par == 2 || shape_mode_par == 3 || shape_mode_par == -2 || shape_mode_par == -3)) ? (hsize_par - width - indentation) : indentation )

extern void get_r_token(void);
extern void assign_internal_value(int a, halfword p, int val);
extern void do_assignments(void);

extern void give_err_help(void);

/*tex This procedure gets things started properly. */

extern void initialize(void);

extern void local_control(void);
extern halfword local_scan_box(void);
extern int current_local_level(void);
extern void end_local_control(void);
extern void local_control_message(const char *s);

extern void inject_text_or_line_dir(int d, int check_glue);

# endif
