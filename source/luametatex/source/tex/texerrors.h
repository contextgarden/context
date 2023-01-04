/*
    See license.txt in the root of this project.
*/

# ifndef LMT_ERRORS_H
# define LMT_ERRORS_H

/*tex

    The global variable |interaction| has four settings, representing increasing amounts of user
    interaction:

*/

# define print_buffer_size 512 /*tex Watch out for alignment! Only used here. */

typedef enum interaction_levels {
    batch_mode,      /*tex omits all stops and omits terminal output */
    nonstop_mode,    /*tex omits all stops */
    scroll_mode,     /*tex omits error stops */
    error_stop_mode, /*tex stops at every opportunity to interact */
} interaction_levels;

# define last_interaction_level error_stop_mode

typedef struct error_state_info {
    char        *last_error;
    char        *last_lua_error;
    char        *last_warning_tag;
    char        *last_warning;
    char        *last_error_context;
    char        *help_text;         /*tex helps for the next |error| */
 /* char         print_buffer[print_buffer_size]; */
    int          intercept;         /*tex intercept error state */
    int          last_intercept;    /*tex error state number / dimen scanner */
    int          interaction;       /*tex current level of interaction */
    int          default_exit_code; /*tex the exit code can be overloaded */
    int          set_box_allowed;
    int          history;
    int          error_count;
    int          saved_selector;
    int          in_error;
    int          long_help_seen;
    int          context_indent;
    int          padding;
    limits_data  line_limits;       /*tex these might go some day */
    limits_data  half_line_limits;  /*tex these might go some day */
} error_state_info;

extern error_state_info lmt_error_state;

typedef enum error_states {
    spotless,             /*tex |history| value when nothing has been amiss yet */
    warning_issued,       /*tex |history| value when |begin_diagnostic| has been called */
    error_message_issued, /*tex |history| value when |error| has been called */
    fatal_error_stop,     /*tex |history| value when termination was premature */
} error_states;

extern void tex_initialize_errors (void);
extern void tex_fixup_selector    (int log_opened);
extern void tex_fatal_error       (const char *helpinfo);
extern void tex_overflow_error    (const char *s, int n);
extern int  tex_confusion         (const char *s);
extern int  tex_normal_error      (const char *t, const char *p);
extern void tex_normal_warning    (const char *t, const char *p);
extern int  tex_formatted_error   (const char *t, const char *fmt, ...);
extern void tex_formatted_warning (const char *t, const char *fmt, ...);
extern void tex_emergency_message (const char *t, const char *fmt, ...);
extern int  tex_emergency_exit    (void);
extern int  tex_normal_exit       (void);

/*tex A bit more detail. */

# define error_string_clobbered(n)   "[clobbered "   LMT_TOSTRING(n) "]"
# define error_string_bad(n)         "[bad "         LMT_TOSTRING(n) "]"
# define error_string_impossible(n)  "[impossible "  LMT_TOSTRING(n) "]"
# define error_string_nonexistent(n) "[nonexistent " LMT_TOSTRING(n) "]"

/*tex
*
    We now have a template based error handler instead of more dan a dozen specific ones that took
    an error type, a different set of variables, and the helptext. The template uses the (usual)
    percent driven directives:

    \starttabulate
    \NC \type {s} \NC string \NC \NR
    \NC \type {c} \NC char \NC \NR
    \NC \type {q} \NC 'string' \NC \NR
    \NC \type {i} \NC integer \NC \NR
    \NC \type {e} \NC escape char \NC \NR
    \NC \type {C} \NC cmd chr \NC \NR
    \NC \type {E} \NC escaped string \NC \NR
    \NC \type {S} \NC cs \NC \NR
    \NC \type {T} \NC texstring \NC \NR
    \stoptabulate

    A placeholder starts with a percent sign. A double percent sign will print one. The last very
    argument is the error message (or |NULL|). We flush on a per character basis but that happens
    anyway and error messages are not really a bottleneck.

 */

typedef enum error_types {
    normal_error_type,
    back_error_type,
    insert_error_type,
    succumb_error_type, /* fatal error_type */
    eof_error_type,
    condition_error_type,
    runaway_error_type,
    warning_error_type,
} error_types;

extern void tex_handle_error              (error_types type, const char *format, ...);
extern void tex_handle_error_message_only (const char *message);

# endif
