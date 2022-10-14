/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

# include <string.h>

/*tex

    When something anomalous is detected, \TEX\ typically does something like this (in \PASCAL\
    lingua):

    \starttyping
    print_err("Something anomalous has been detected");
    help(
        "This is the first line of my offer to help.\n"
        "This is the second line. I'm trying to\n"
        "explain the best way for you to proceed."
    );
    error();
    \stoptyping

    A two-line help message would be given using |help2|, etc.; these informal helps should use
    simple vocabulary that complements the words used in the official error message that was
    printed. (Outside the U.S.A., the help messages should preferably be translated into the local
    vernacular. Each line of help is at most 60 characters long, in the present implementation, so
    that |max_print_line| will not be exceeded.)

    The |print_err| procedure supplies a |!| before the official message, and makes sure that the
    terminal is awake if a stop is going to occur. The |error| procedure supplies a |.| after the
    official message, then it shows the location of the error; and if |interaction =
    error_stop_mode|, it also enters into a dialog with the user, during which time the help message
    may be printed.

*/

error_state_info lmt_error_state = {
    .last_error         = NULL,
    .last_lua_error     = NULL,
    .last_warning_tag   = NULL,
    .last_warning       = NULL,
    .last_error_context = NULL,
    .help_text          = NULL,
    .print_buffer       = "",
    .intercept          = 0,
    .last_intercept     = 0,
    .interaction        = 0,
    .default_exit_code  = 0,
    .set_box_allowed    = 0,
    .history            = 0,
    .error_count        = 0,
    .err_old_setting    = 0,
    .in_error           = 0,
    .long_help_seen     = 0,
    .context_indent     = 4,
    .padding            = 0,
    .line_limits = {
        .maximum = max_error_line,
        .minimum = min_error_line,
        .size    = min_error_line,
        .top     = 0,
    },
    .half_line_limits = {
        .maximum = max_half_error_line,
        .minimum = min_half_error_line,
        .size    = min_half_error_line,
        .top     = 0,
    },
} ;

/*tex
    Because a |text_can| can be assembled we make a copy. There are not many cases where this is
    really needed but there are seldom errors anyway so we can neglect this duplication of data.
*/

inline static void tex_aux_update_help_text(const char* str)
{
    if (lmt_error_state.help_text) {
        lmt_memory_free(lmt_error_state.help_text);
        lmt_error_state.help_text = NULL;
    }
    if (str) {
        lmt_error_state.help_text = lmt_memory_strdup(str);
    }
}

/*tex

    The previously defines structure collects all relevant variables: the current level of
    interaction: |interaction|, states like |last_error|, |last_lua_error|, |last_warning_tag|,
    |last_warning_str| and |last_error_context|, and temporary variables like |err_old_setting| and
    |in_error|.

    This is a variant on |show_runaway| that is used when we delegate error handling to a \LUA\
    callback. (Maybe some day that will be default.)

*/

static void tex_aux_set_last_error_context(void)
{
    int saved_selector = lmt_print_state.selector;
    int saved_new_line_char = new_line_char_par;
    int saved_new_string_line = lmt_print_state.new_string_line;
    lmt_print_state.selector = new_string_selector_code;
    new_line_char_par = 10;
    lmt_print_state.new_string_line = 10;
    tex_show_validity();
    tex_show_context();
    lmt_memory_free(lmt_error_state.last_error_context);
    lmt_error_state.last_error_context = tex_take_string(NULL);
    lmt_print_state.selector = saved_selector;
    new_line_char_par = saved_new_line_char;
    lmt_print_state.new_string_line = saved_new_string_line;
}

static void tex_aux_flush_error(void)
{
    if (lmt_error_state.in_error) {
        lmt_print_state.selector = lmt_error_state.err_old_setting;
        lmt_memory_free(lmt_error_state.last_error);
        lmt_error_state.last_error = tex_take_string(NULL);
        if (lmt_error_state.last_error) {
            int callback_id = lmt_callback_defined(show_error_message_callback);
            if (callback_id > 0) {
                lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "->");
            } else {
                tex_print_str(lmt_error_state.last_error);
            }
        }
        lmt_error_state.in_error = 0;
    }
}

static int tex_aux_error_callback_set(void)
{
    int callback_id = lmt_callback_defined(show_error_message_callback);
    return lmt_lua_state.lua_instance && callback_id > 0 ? callback_id : 0;
}

static void tex_aux_start_error(void)
{
    if (tex_aux_error_callback_set()) {
        lmt_error_state.err_old_setting = lmt_print_state.selector;
        lmt_print_state.selector = new_string_selector_code;
        lmt_error_state.in_error = 1 ;
        lmt_memory_free(lmt_error_state.last_error);
        lmt_error_state.last_error = NULL;
    } else {
        tex_print_nlp();
        tex_print_str("! ");
    }
}

/*tex

    \TEX\ is careful not to call |error| when the print |selector| setting might be unusual. The
    only possible values of |selector| at the time of error messages are:

    \startitemize
        \startitem |no_print|:     |interaction=batch_mode| and |log_file| not yet open; \stopitem
        \startitem |term_only|:    |interaction>batch_mode| and |log_file| not yet open; \stopitem
        \startitem |log_only|:     |interaction=batch_mode| and |log_file| is open;      \stopitem
        \startitem |term_and_log|: |interaction>batch_mode| and |log_file| is open.      \stopitem
    \stopitemize

*/

void tex_fixup_selector(int logopened)
{
    if (lmt_error_state.interaction == batch_mode) {
        lmt_print_state.selector = logopened ? logfile_selector_code : no_print_selector_code ;
    } else {
        lmt_print_state.selector = logopened ? terminal_and_logfile_selector_code : terminal_selector_code;
    }
}

/*tex

    The variable |history| records the worst level of error that has been detected. It has four
    possible values: |spotless|, |warning_issued|, |error_message_issued|, and |fatal_error_stop|.

    Another variable, |error_count|, is increased by one when an |error| occurs without an
    interactive dialog, and it is reset to zero at the end of every paragraph. If |error_count|
    reaches 100, \TEX\ decides that there is no point in continuing further.

    The value of |history| is initially |fatal_error_stop|, but it will be changed to |spotless|
    if \TEX\ survives the initialization process.

*/

void tex_initialize_errors(void)
{
    lmt_error_state.interaction = error_stop_mode;
    lmt_error_state.set_box_allowed = 1;
    if (lmt_error_state.half_line_limits.size > lmt_error_state.line_limits.size) {
        lmt_error_state.half_line_limits.size = lmt_error_state.line_limits.size/2;
    }
    if (lmt_error_state.half_line_limits.size <= 30) {
        lmt_error_state.half_line_limits.size = 31;
    } else if (lmt_error_state.half_line_limits.size >= (lmt_error_state.line_limits.size - 15)) {
        lmt_error_state.half_line_limits.size = lmt_error_state.line_limits.size - 16;
    }
}

/*tex

    It is possible for |error| to be called recursively if some error arises when |get_token| is
    being used to delete a token, and/or if some fatal error occurs while \TEX\ is trying to fix
    a non-fatal one. But such recursion is never more than two levels deep.

    Individual lines of help are recorded in the string |help_text|. There can be embedded
    newlines.

    The |jump_out| procedure just cuts across all active procedure levels and exits the program.
    It is used when there is no recovery from a particular error. The exit code can be overloaded.

    We don't close the lua state because we then have to collect lots of garbage and it really
    slows doen the run. It's not needed anyway, as we exit.

*/

static int tex_aux_final_exit(int code)
{
    exit(code);
    return 0; /* unreachable */
}

int tex_normal_exit(void)
{
    tex_terminal_update();
 /* lua_close(lua_state.lua_instance); */
    lmt_main_state.ready_already = output_disabled_state;
    if (lmt_error_state.history != spotless && lmt_error_state.history != warning_issued) {
        return tex_aux_final_exit(EXIT_FAILURE);
    } else {
        return tex_aux_final_exit(lmt_error_state.default_exit_code);
    }
}

static void tex_aux_jump_out(void)
{
    tex_close_files_and_terminate(1);
    tex_normal_exit();
}

/*tex

    This completes the job of error reporting, that is, in good old \TEX. But in \LUATEX\ it
    doesn't make sense to suport this model of error handling, also because one cannot backtrack
    over \LUA\ actions, so it would be a cheat. But we can keep the modes.

*/

static void tex_aux_error(int type)
{
    int callback_id = lmt_callback_defined(intercept_tex_error_callback);
    tex_aux_flush_error();
    if (lmt_error_state.history < error_message_issued && type !=  warning_error_type) {
        lmt_error_state.history = error_message_issued;
    }
    if (lmt_lua_state.lua_instance && callback_id > 0) {
        tex_aux_set_last_error_context();
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->d", lmt_error_state.interaction, type, &lmt_error_state.interaction);
        lmt_error_state.error_count = 0;
        tex_terminal_update();
        switch (lmt_error_state.interaction) {
            case batch_mode: /* Q */
                --lmt_print_state.selector;
                return;
            case nonstop_mode: /* R */
                return;
            case scroll_mode: /* S */
                return;
            case error_stop_mode: /* carry on */
                break;
            default: /* exit */
                lmt_error_state.interaction = scroll_mode;
                if (type != warning_error_type) {
                    tex_aux_jump_out();
                }
                break;
        }
    } else {
        tex_print_char('.');
        tex_show_context();
    }
    if (type != warning_error_type) {
        ++lmt_error_state.error_count;
        if (lmt_error_state.error_count == 100) {
            tex_print_message("That makes 100 errors; please try again.");
            lmt_error_state.history = fatal_error_stop;
            tex_aux_jump_out();
        }
    }
    /*tex
        We assume that the callback handles the log file too. Otherwise we put the help message in
        the log file.
    */
    if (callback_id == 0) {
        if (lmt_error_state.interaction > batch_mode) {
            /*tex Avoid terminal output: */
            --lmt_print_state.selector;
        }
        tex_print_nlp();
        if (lmt_error_state.help_text) {
            tex_print_str(lmt_error_state.help_text);
            tex_print_nlp();
        }
        if (lmt_error_state.interaction > batch_mode) {
            /*tex Re-enable terminal output: */
            ++lmt_print_state.selector;
        }
    }
    tex_print_ln();
}

/*tex

    In anomalous cases, the print selector might be in an unknown state; the following subroutine
    is called to fix things just enough to keep running a bit longer.

*/

static void tex_aux_normalize_selector(void)
{
    if (lmt_fileio_state.log_opened) {
        lmt_print_state.selector = terminal_and_logfile_selector_code;
    } else {
        lmt_print_state.selector = terminal_selector_code;
    }
    if (! lmt_fileio_state.job_name) {
        tex_open_log_file();
    }
    if (lmt_error_state.interaction == batch_mode) {
        /*tex It becomes no or terminal. */
        --lmt_print_state.selector;
    }
}

/*tex The following procedure prints \TEX's last words before dying: */

static void tex_aux_succumb_error(void)
{
    if (lmt_error_state.interaction == error_stop_mode) {
        /*tex No more interaction: */
        lmt_error_state.interaction = scroll_mode;
    }
    if (lmt_fileio_state.log_opened) {
        tex_aux_error(succumb_error_type);
    }
    lmt_error_state.history = fatal_error_stop;
    /*tex Irrecoverable error: */
    tex_aux_jump_out();
}

/*tex This prints |s|, and that's it. */

void tex_fatal_error(const char *helpinfo)
{
    tex_aux_normalize_selector();
    tex_handle_error(
        succumb_error_type,
        "Emergency stop",
        helpinfo
    );
}

/*tex Here is the most dreaded error message. We stop due to finiteness. */

void tex_overflow_error(const char *s, int n)
{
    tex_aux_normalize_selector();
    tex_handle_error(
        succumb_error_type,
        "TeX capacity exceeded, sorry [%s=%i]",
        s, n,
        "If you really absolutely need more capacity, you can ask a wizard to enlarge me."
    );
}

/*tex

    The program might sometime run completely amok, at which point there is no choice but to stop.
    If no previous error has been detected, that's bad news; a message is printed that is really
    intended for the \TEX\ maintenance person instead of the user (unless the user has been
    particularly diabolical). The index entries for \quotation {this can't happen} may help to
    pinpoint the problem.

*/

int tex_confusion(const char *s)
{
    /*tex A consistency check violated; |s| tells where: */
    tex_aux_normalize_selector();
    if (lmt_error_state.history < error_message_issued) {
        tex_handle_error(
            succumb_error_type,
            "This can't happen (%s)",
            s,
            "I'm broken. Please show this to someone who can fix me."
        );
    } else {
        tex_handle_error(
            succumb_error_type,
            "I can't go on meeting you like this",
            "One of your faux pas seems to have wounded me deeply ... in fact, I'm barely\n"
            "conscious. Please fix it and try again."
        );
    }
    return 0;
}

/*tex

    When the program is interrupted we just quit. Here is the hook to deal with it.

*/

void aux_quit_the_program(void) /*tex No |tex_| prefix here! */
{
    tex_handle_error(
        succumb_error_type,
        "Forced stop",
        NULL
    );
}

/*tex

    The |back_error| routine is used when we want to replace an offending token just before issuing
    an error message. This routine, like |back_input|, requires that |cur_tok| has been set. We
    disable interrupts during the call of |back_input| so that the help message won't be lost.

*/

static void tex_aux_back_error(void)
{
    tex_back_input(cur_tok);
    tex_aux_error(back_error_type);
}

/*tex Back up one inserted token and call |error|. */

static void tex_aux_insert_error(void)
{
    tex_back_input(cur_tok);
    lmt_input_state.cur_input.token_type = inserted_text;
    tex_aux_error(insert_error_type);
}

int tex_normal_error(const char *t, const char *p)
{
   if (lmt_engine_state.lua_only) {
        /*tex Normally ending up here means that we call the wrong error function. */
        tex_emergency_message(t, p);
    } else {
        tex_aux_normalize_selector();
        if (! tex_aux_error_callback_set()) {
            tex_print_nlp();
            tex_print_str("! ");
        }
        tex_print_str("error");
        if (t) {
            tex_print_format(" (%s)", t);
        }
        tex_print_str(": ");
        if (p) {
            tex_print_str(p);
        }
        lmt_error_state.history = fatal_error_stop;
        tex_print_str("\n");
    }
    return tex_aux_final_exit(EXIT_FAILURE);
}

void tex_normal_warning(const char *t, const char *p)
{
    if (strcmp(t, "lua") == 0) {
        int callback_id = lmt_callback_defined(intercept_lua_error_callback);
        int saved_new_line_char = new_line_char_par;
        new_line_char_par = 10;
        if (lmt_lua_state.lua_instance && callback_id) {
            (void) lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "->");
            /* error(); */
        } else {
            tex_handle_error(
                normal_error_type,
                p ? p : "unspecified lua error",
                "The lua interpreter ran into a problem, so the remainder of this lua chunk will\n"
                "be ignored."
            );
        }
        new_line_char_par = saved_new_line_char;
    } else {
        int callback_id = lmt_callback_defined(show_warning_message_callback);
        if (callback_id > 0) {
            /*tex Free the last ones, */
            lmt_memory_free(lmt_error_state.last_warning);
            lmt_memory_free(lmt_error_state.last_warning_tag);
            lmt_error_state.last_warning = lmt_memory_strdup(p);
            lmt_error_state.last_warning_tag = lmt_memory_strdup(t);
            lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "->");
        } else {
            tex_print_ln();
            tex_print_str("warning");
            if (t) {
                tex_print_format(" (%s)", t);
            }
            tex_print_str(": ");
            if (p) {
                tex_print_str(p);
            }
            tex_print_ln();
        }
        if (lmt_error_state.history == spotless) {
            lmt_error_state.history = warning_issued;
        }
    }
}

int tex_formatted_error(const char *t, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(lmt_error_state.print_buffer, print_buffer_size, fmt, args);
    return tex_normal_error(t, lmt_error_state.print_buffer);
    /*
    va_end(args);
    return 0;
    */
}

void tex_formatted_warning(const char *t, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(lmt_error_state.print_buffer, print_buffer_size, fmt, args);
    tex_normal_warning(t, lmt_error_state.print_buffer);
    va_end(args);
}

void tex_emergency_message(const char *t, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(lmt_error_state.print_buffer, print_buffer_size, fmt, args);
    fprintf(stdout,"%s : %s\n",t,lmt_error_state.print_buffer);
    va_end(args);
}

int tex_emergency_exit(void)
{
    return tex_aux_final_exit(EXIT_FAILURE);
}

/*tex A prelude to more abstraction and maybe using sprint etc.*/

static void tex_aux_do_handle_error_type(
    int type
) {
    switch (type) {
        case normal_error_type:
        case eof_error_type:
        case condition_error_type:
        case runaway_error_type:
        case warning_error_type:
            tex_aux_error(type);
            break;
        case back_error_type:
            tex_aux_back_error();
            break;
        case insert_error_type:
            tex_aux_insert_error();
            break;
        case succumb_error_type:
            tex_aux_succumb_error();
            break;
    }
}

void tex_handle_error_message_only(
    const char *message
)
{
    tex_aux_start_error();
    tex_print_str(message);
    if (tex_aux_error_callback_set()) {
        lmt_error_state.in_error = 0;
        lmt_memory_free(lmt_error_state.last_error);
        lmt_error_state.last_error = lmt_memory_strdup(message);
    }
}

/*tex

    We had about 15 specific tuned message handlers as a prelude to a general template based one
    and that one has arrived (we also have a print one, beginning 2021 only partially applied as
    I'm undecided). We can now call a translation callback where we remap similar to how we do it
    in ConTeXt but I;'m nor that sure if users really need it. The english is probably the least
    problematic part of an error so first I will perfect the tracing bit.

    Todo: a translation callback: |str, 1 => str|, or not.

*/

extern void tex_handle_error(error_types type, const char *format, ...)
{
    const char *str = NULL;
    va_list args;
    va_start(args, format); /* hm, weird, no number */
    tex_aux_start_error();
    tex_print_format_args(format, args);
    tex_aux_update_help_text(str);
    tex_aux_do_handle_error_type(type);
    va_end(args);
}
