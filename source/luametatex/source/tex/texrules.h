/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXRULES_H
# define LMT_TEXRULES_H

typedef enum rule_types {
    h_rule_type = 0,
    v_rule_type = 1,
    m_rule_type = 2,
} rule_types;

extern halfword tex_aux_scan_rule_spec        (rule_types t, halfword s);
extern void     tex_aux_run_vrule             (void);
extern void     tex_aux_run_hrule             (void);
extern void     tex_aux_run_mrule             (void);

extern void     tex_aux_check_text_strut_rule (halfword rule, halfword style);
extern void     tex_aux_check_math_strut_rule (halfword rule, halfword style);

extern halfword tex_get_rule_font             (halfword n, halfword style);
extern halfword tex_get_rule_family           (halfword n);
extern void     tex_set_rule_font             (halfword n, halfword fnt);
extern void     tex_set_rule_family           (halfword n, halfword fam);

# endif
