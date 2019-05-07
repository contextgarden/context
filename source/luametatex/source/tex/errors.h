/*
    See license.txt in the root of this project.
*/

# ifndef ERRORS_H
# define ERRORS_H

/*tex

    The global variable |interaction| has four settings, representing increasing
    amounts of user interaction:

*/

# ifndef errno
extern int errno;
# endif

# define print_buffer_size  1024

typedef enum {
    batch_mode = 0,           /*tex omits all stops and omits terminal output */
    nonstop_mode = 1,         /*tex omits all stops */
    scroll_mode = 2,          /*tex omits error stops */
    error_stop_mode = 3,      /*tex stops at every opportunity to interact */
} interaction_settings;

typedef struct error_state_info {
    char *last_error;
    char *last_lua_error;
    char *last_warning_tag;
    char *last_warning_str;
    char *last_error_context;
    const char *help_text;     /*tex helps for the next |error| */
    /* */
    char print_buf[print_buffer_size];
    /* */
    int intercept;             /*tex intercept error state */
    int last_intercept;        /*tex error state number / dimen scanner */
    int interaction;           /*tex current level of interaction */
    int interactionoption;     /*tex set from command line */
    int defaultexitcode;       /*tex the exit code can be overloaded */
    int deletions_allowed;
    int set_box_allowed;
    int history;
    int error_count;
    int interrupt;
    int OK_to_interrupt;
    int use_err_help;          /*tex should the |err_help| list be shown? */
    int err_old_setting;
    int in_error;
} error_state_info;

extern error_state_info error_state;

typedef enum {
    spotless = 0,             /*tex |history| value when nothing has been amiss yet */
    warning_issued = 1,       /*tex |history| value when |begin_diagnostic| has been called */
    error_message_issued = 2, /*tex |history| value when |error| has been called */
    fatal_error_stop = 3,     /*tex |history| value when termination was premature */
} error_states;

/*tex these macros are just temporary, until everything is in C */

# define help(A) error_state.help_text = A;

extern void initialize_errors(void);
extern void print_err(const char *s);
extern void fixup_selector(int log_opened);

extern void do_final_end(void);
extern void jump_out(void);
extern void error(void);
extern void int_error(int n);
extern void normalize_selector(void);
extern void succumb(void);
extern void fatal_error(const char *s);
extern void overflow(const char *s, unsigned int n);
extern void confusion(const char *s);
extern void check_interrupt(void);
extern void pause_for_instructions(void);

extern void tex_error(const char *msg, const char *hlp);
extern void normal_error(const char *t, const char *p);
extern void normal_warning(const char *t, const char *p);
extern void formatted_error(const char *t, const char *fmt, ...);
extern void formatted_warning(const char *t, const char *fmt, ...);
extern void emergency_message(const char *t, const char *fmt, ...);

extern void back_error(void);
extern void ins_error(void);
extern void flush_err(void);

extern void char_warning(internal_font_number f, int c);

# endif
