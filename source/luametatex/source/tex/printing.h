/*
    See license.txt in the root of this project.
*/

/* todo: int vs halfword */

# ifndef PRINTING_H
# define PRINTING_H

# define last_file_selector 127 /* was 15 */

/*tex

    Nicer will be to start these with 0 and then use an offset for the write
    registers internally.

*/

typedef enum {
    no_print     = last_file_selector + 1, /*tex |selector| setting that makes data disappear */
    term_only    = last_file_selector + 2, /*tex printing is destined for the terminal only */
    log_only     = last_file_selector + 3, /*tex printing is destined for the transcript file only */
    term_and_log = last_file_selector + 4, /*tex normal |selector| setting */
    pseudo       = last_file_selector + 5, /*tex special |selector| setting for |show_context| */
    new_string   = last_file_selector + 6, /*tex printing is deflected to the string pool */
} selector_settings;

# define sup_error_line 255
# define max_selector new_string /*tex highest selector setting */

typedef struct print_state_info {
    FILE *log_file;
    char *loggable_info;
    int selector;
    int dig[23];
    int tally;
    int term_offset;
    int file_offset;
    int escape_controls;
    int new_string_line;
    unsigned char trick_buf[(sup_error_line + 1)];
    int trick_count;
    int first_count;
    int inhibit_par_tokens;
    int global_old_setting;
    /*tex todo: use the par instead */
    int depth_threshold;                /*tex maximum nesting depth in box displays */
    int breadth_max;                    /*tex maximum number of items shown at the same list level */
    int font_in_short_display;          /*tex an internal font number */
} print_state_info;

extern print_state_info print_state;

# define escape_controls       print_state.escape_controls
# define new_string_line       print_state.new_string_line
# define log_file              print_state.log_file
# define selector              print_state.selector
# define dig                   print_state.dig
# define tally                 print_state.tally
# define term_offset           print_state.term_offset
# define file_offset           print_state.file_offset
# define trick_buf             print_state.trick_buf
# define trick_count           print_state.trick_count
# define first_count           print_state.first_count
# define inhibit_par_tokens    print_state.inhibit_par_tokens
# define global_old_setting    print_state.global_old_setting
# define depth_threshold       print_state.depth_threshold
# define breadth_max           print_state.breadth_max
# define font_in_short_display print_state.font_in_short_display

/*tex

    Macro abbreviations for output to the terminal and to the log file are
    defined here for convenience. Some systems need special conventions for
    terminal output, and it is possible to adhere to those conventions by
    changing |wterm|, |wterm_ln|, and |wterm_cr| in this section.

*/

# define wterm_cr() fprintf(term_out,"\n")
# define wlog_cr()  fprintf(log_file,"\n")

extern void print_ln(void);
extern void print_char(int s);
extern void print(int s);
extern void lprint (lstring *ss);
extern void print_nl(str_number s);
extern void print_nlp(void);
extern void print_banner(void);
extern void log_banner(void);
extern void print_version_banner(void);
extern void print_esc(str_number s);
extern void print_the_digs(unsigned char k);
extern void print_int(int n);
extern void print_two(int n);
extern void print_qhex(int n);
extern void print_roman_int(int n);
extern void print_current_string(void);

# define print_font_name(A) tprint(font_name(A))

extern void print_cs(int p);
extern void sprint_cs(halfword p);
extern void sprint_cs_name(halfword p);
extern void tprint(const char *s);
extern void tprint_nl(const char *s);
extern void tprint_esc(const char *s);

extern void prompt_input(const char *s);

# define single_letter(A) \
    ((str_length(A)==1)|| \
    ((str_length(A)==4)&&*(str_string((A)))>=0xF0)|| \
    ((str_length(A)==3)&&*(str_string((A)))>=0xE0)|| \
    ((str_length(A)==2)&&*(str_string((A)))>=0xC0))

# define is_active_cs(a) \
    (a && str_length(a)>3 && \
    ( *str_string(a)    == 0xEF) && \
    (*(str_string(a)+1) == 0xBF) && \
    (*(str_string(a)+2) == 0xBF))

# define active_cs_value(A) str2uni((str_string((A))+3))

extern void print_glue(scaled d, int order, const char *s);  /*tex prints a glue component */
extern void print_spec(int p, const char *s);                /*tex prints a glue specification */

extern void print_font_identifier(internal_font_number f);
extern void short_display(int p);                            /*tex prints highlights of list |p| */
extern void print_font_and_char(int p);                      /*tex prints |char_node| data */
extern void print_mark(int p);                               /*tex prints token list data in braces */
extern void print_rule_dimen(scaled d);                      /*tex prints dimension in rule node */
extern void show_box(halfword p);
extern void short_display_n(int p, int m);                   /*tex prints highlights of list |p| */

extern void print_csnames(int hstart, int hfinish);

extern void begin_diagnostic(void);
extern void end_diagnostic(int blank_line);

# endif
