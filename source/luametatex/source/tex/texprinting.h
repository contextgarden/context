/*
    See license.txt in the root of this project.
*/

# ifndef LMT_PRINTING_H
# define LMT_PRINTING_H

typedef enum selector_settings {
    no_print_selector_code,             /*tex |selector| setting that makes data disappear */
    terminal_selector_code,             /*tex printing is destined for the terminal only */
    logfile_selector_code,              /*tex printing is destined for the transcript file only */
    terminal_and_logfile_selector_code, /*tex normal |selector| setting */
    pseudo_selector_code,               /*tex special |selector| setting for |show_context| */
    new_string_selector_code,           /*tex printing is deflected to the string pool */
    luabuffer_selector_code,
} selector_settings;

typedef struct print_state_info {
    FILE          *logfile;
    char          *loggable_info;
    int            selector;
    int            terminal_offset;
    int            logfile_offset;
    int            new_string_line;
    int            tally;
    unsigned char  trick_buffer[max_error_line + 1]; /* padded */
    int            trick_count;
    int            first_count;
    int            saved_selector;
    int            font_in_short_display; /*tex an internal font number */
    FILE          *saved_logfile;
    int            saved_logfile_offset;
} print_state_info;

extern print_state_info lmt_print_state;

typedef enum spec_units {
    no_unit,
    pt_unit,
    mu_unit,
} spec_units;

/*tex
    Some of these can go away because we stepwise implement usage of |tex_print_format| instead of
    a multitude of specific calls. It's one of these thing I do when I'm bored.

    todo : check tex_print_ln
    todo : check tex_print_nl
    todo : check tex_print_str_nl

*/

extern void tex_print_ln               (void);   /* always forces a newline */
extern void tex_print_char             (int s);
extern void tex_print_tex_str          (int s);
extern void tex_print_tex_str_esc      (strnumber s);
extern void tex_print_nlp              (void);   /* flushes a line if we're doing one */
extern void tex_print_banner           (void);
extern void tex_print_log_banner       (void);
extern void tex_print_version_banner   (void);
////// void tex_print_digits           (const unsigned char *digits, int k);
extern void tex_print_int              (int n);
extern void tex_print_hex              (int n);
extern void tex_print_uhex             (int n);
extern void tex_print_qhex             (int n);
extern void tex_print_roman_int        (int n);
extern void tex_print_current_string   (void);
extern void tex_print_cs_checked       (halfword p);                    /*tex Also does the |IMPOSSIBLE| etc. */
extern void tex_print_cs               (halfword p);                    /*tex Only does the undefined case. */
extern void tex_print_cs_name          (halfword p);                    /*tex Only prints known ones. */
extern void tex_print_str              (const char *s);
extern void tex_print_str_esc          (const char *s);
extern void tex_print_dimension        (scaled d, int unit);            /*tex prints a dimension with pt */
extern void tex_print_sparse_dimension (scaled d, int unit);            /*tex prints a dimension with pt */
extern void tex_print_unit             (int unit);                      /*tex prints a glue component */
extern void tex_print_glue             (scaled d, int order, int unit); /*tex prints a glue component */
extern void tex_print_spec             (int p, int unit);               /*tex prints a glue specification */
extern void tex_print_fontspec         (int p);
extern void tex_print_mathspec         (int p);
extern void tex_print_font_identifier  (halfword f);
extern void tex_print_font_specifier   (halfword e);                    /*tex this is an eq table entry */
extern void tex_print_font             (halfword f);
extern void tex_print_char_identifier  (halfword c);
extern void tex_print_token_list       (const char *s, halfword p);     /*tex prints token list data in braces */
extern void tex_print_rule_dimen       (scaled d);                      /*tex prints dimension in rule node */
extern void tex_print_group            (int e);
extern void tex_print_format           (const char *format, ...);       /*tex similar to the one we use for errors */
extern void tex_begin_diagnostic       (void);
extern void tex_print_levels           (void);
extern void tex_end_diagnostic         (void);
extern void tex_show_box               (halfword p);
extern void tex_short_display          (halfword p);                    /*tex prints highlights of list |p| */
                                       
extern void tex_print_message          (const char *s);


/*
# define single_letter(A) \
    ((str_length(A)==1)|| \
    ((str_length(A)==4)&&*(str_string(A))>=0xF0)|| \
    ((str_length(A)==3)&&*(str_string(A))>=0xE0)|| \
    ((str_length(A)==2)&&*(str_string(A))>=0xC0))

# define is_active_cs(a) \
    (a && str_length(a)>3 && \
    ( *str_string(a)    == 0xEF) && \
    (*(str_string(a)+1) == 0xBF) && \
    (*(str_string(a)+2) == 0xBF))

*/

inline static int tex_single_letter(strnumber s)
{
    return (
          (str_length(s) == 1)
     || ( (str_length(s) == 4) && *(str_string(s) ) >= 0xF0)
     || ( (str_length(s) == 3) && *(str_string(s) ) >= 0xE0)
     || ( (str_length(s) == 2) && *(str_string(s) ) >= 0xC0)
    );
}

inline static int tex_is_active_cs(strnumber s)
{
    if (s && str_length(s) > 3) {
        const unsigned char *ss = str_string(s);
        return (ss[0] == 0xEF) && (ss[1] == 0xBF) && (ss[2] == 0xBF);
    } else {
        return 0;
    }
}
# define active_cs_value(A) aux_str2uni((str_string((A))+3))

# endif
