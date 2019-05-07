/*
    See license.txt in the root of this project.
*/

# ifndef SCANNING_H
# define SCANNING_H

typedef enum {
    int_val_level = 0, /*tex integer values */
    attr_val_level,    /*tex integer values */
    dimen_val_level,   /*tex dimension values */
    glue_val_level,    /*tex glue specifications */
    mu_val_level,      /*tex math glue specifications */
    dir_val_level,     /*tex directions */
    ident_val_level,   /*tex font identifier */
    tok_val_level,     /*tex token lists */
} value_level_code;

extern void scan_left_brace(void);
extern void scan_optional_equals(void);

typedef struct scanner_state_info {
    int cur_val;           /*tex value returned by numeric scanners */
    int cur_val_level;     /*tex the level of this value */
    int cur_order;
    halfword cur_box;      /*tex The box to be placed into its context: */
    int cur_val1;          /*tex delcodes are sometimes 51 digits */
    int cur_radix;         /*tex We need to (re)store the radix in nested expansion. */
    /* */
    scaled tex_remainder;
    int arith_error;
    /* */
    int cur_cmd;           /*tex current command set by |get_next| */
    halfword cur_chr;      /*tex operand of current command */
    halfword cur_cs;       /*tex control sequence found here, zero if none found */
    halfword cur_tok;      /*tex packed representative of |cur_cmd| and |cur_chr| */
    /* might move */
    halfword last_cs_name; /*tex For |\csname| and |\ifcsname|: */
} scanner_state_info;

extern scanner_state_info scanner_state;

# define cur_val       scanner_state.cur_val
# define cur_val_level scanner_state.cur_val_level
# define cur_order     scanner_state.cur_order
# define cur_box       scanner_state.cur_box
# define cur_val1      scanner_state.cur_val1
# define cur_radix     scanner_state.cur_radix
# define cur_cmd       scanner_state.cur_cmd
# define cur_chr       scanner_state.cur_chr
# define cur_cs        scanner_state.cur_cs
# define cur_tok       scanner_state.cur_tok
# define last_cs_name  scanner_state.last_cs_name

extern void scan_something_simple(halfword cmd, halfword subitem);
extern void scan_something_internal(int level, int negative);

extern void scan_limited_int(int max, const char *name);

extern void negate_cur_val(int delete_glue);

# define scan_register_num()         scan_limited_int(65535,       "register code")
# define scan_mark_num()             scan_limited_int(65535,       "marks code")
# define scan_char_num()             scan_limited_int(biggest_char,"character code")
# define scan_four_bit_int()         scan_limited_int(15,          NULL)
# define scan_math_family_int()      scan_limited_int(255,         "math family")
# define scan_real_fifteen_bit_int() scan_limited_int(32767,       "mathchar")
# define scan_big_fifteen_bit_int()  scan_limited_int(0x7FFFFFF,   "extended mathchar")
# define scan_twenty_seven_bit_int() scan_limited_int(0777777777,  "delimiter code")

extern void scan_fifteen_bit_int(void);
extern void scan_fifty_one_bit_int(void);

# define octal_token             (other_token + '\'') /*tex apostrophe, indicates an octal constant */
# define hex_token               (other_token + '"')  /*tex double quote, indicates a hex constant */
# define alpha_token             (other_token + '`')  /*tex reverse apostrophe, precedes alpha constants */
# define point_token             (other_token + '.')  /*tex decimal point */
# define comma_token             (other_token + ',')  /*tex decimal comma */
# define plus_token              (other_token + '+')
# define minus_token             (other_token + '-')
# define slash_token             (other_token + '/')
# define star_token              (other_token + '*')
# define colon_token             (other_token + ':')
# define equal_token             (other_token + '=')
# define escape_token            (other_token + '\\')
# define left_parent_token       (other_token + '(')
# define right_parent_token      (other_token + ')')
# define continental_point_token (other_token + ',')  /*tex decimal point, Eurostyle */
# define zero_token              (other_token + '0')  /*tex zero, the smallest digit */
# define nine_token              (other_token + '9')  /*tex zero, the smallest digit */
# define A_token                 (letter_token+ 'A')  /*tex the smallest special hex digit */
# define other_A_token           (other_token + 'A')  /*tex special hex digit of type |other_char| */

# define infinity 017777777777  /*tex the largest positive value that \TEX\ knows */

extern void scan_int(int optional_equal);

# define scan_normal_dimen(optional_equal) scan_dimen(0,0,0,optional_equal)
# define scan_normal_glue(optional_equal) scan_glue(glue_val_level,optional_equal)
# define scan_mu_glue(optional_equal) scan_glue(mu_val_level,optional_equal)

extern void scan_dimen(int mu, int inf, int shortcut, int optional_equal);
extern void scan_glue(int level, int optional_equal);

extern halfword the_toks(void);
extern str_number the_scanned_result(void);
extern void set_font_dimen(void);
extern void get_font_dimen(void);

# define default_rule 26214 /*tex 0.4pt */

extern halfword scan_rule_spec(void);

extern void scan_font_ident(void);
extern void scan_general_text(void);
extern void get_x_or_protected(void);
extern halfword scan_toks(int macrodef, int xpand, int left_brace_found);

extern int fract(int x, int n, int d, int max_answer);

# endif
