/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    When something anomalous is detected, \TEX\ typically does something like
    this (in \PASCAL\ lingua):

    \starttyping
    print_err("Something anomalous has been detected");
    help(
        "This is the first line of my offer to help.\n"
        "This is the second line. I'm trying to\n"
        "explain the best way for you to proceed."
    );
    error;
    \stoptyping

    A two-line help message would be given using |help2|, etc.; these informal
    helps should use simple vocabulary that complements the words used in the
    official error message that was printed. (Outside the U.S.A., the help
    messages should preferably be translated into the local vernacular. Each line
    of help is at most 60 characters long, in the present implementation, so that
    |max_print_line| will not be exceeded.)

    The |print_err| procedure supplies a |!| before the official message, and
    makes sure that the terminal is awake if a stop is going to occur. The
    |error| procedure supplies a |.| after the official message, then it shows
    the location of the error; and if |interaction = error_stop_mode|, it also
    enters into a dialog with the user, during which time the help message may be
    printed.

*/

error_state_info error_state = { NULL, NULL, NULL, NULL, NULL, NULL, "", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } ;

/*tex

    The previously defines structure collectx all relevant variables: the current
    level of interaction: |interaction|, states like |last_error|,
    |last_lua_error|, |last_warning_tag|, |last_warning_str| and
    |last_error_context|, and temporary variables like |err_old_setting| and
    |in_error|.

*/

static void set_last_error_context(void)
{
    str_number str;
    int sel = selector;
    int saved_new_line_char;
    int saved_new_string_line;
    selector = new_string;
    saved_new_line_char = new_line_char_par;
    saved_new_string_line = new_string_line;
    new_line_char_par = 10;
    new_string_line = 10;
    show_context();
    free(error_state.last_error_context);
    str = make_string();
    error_state.last_error_context = makecstring(str);
    flush_str(str);
    selector = sel;
    new_line_char_par = saved_new_line_char;
    new_string_line = saved_new_string_line;
    return;
}

void flush_err(void)
{
    if (error_state.in_error) {
        str_number s_error;
        char *s = NULL;
        int callback_id ;
        selector = error_state.err_old_setting;
        str_room(1);
        s_error = make_string();
        s = makecstring(s_error);
        flush_str(s_error);
        if (error_state.interaction == error_stop_mode) {
            wake_up_terminal();
        }
        free(error_state.last_error);
        error_state.last_error = (char *) malloc((unsigned) (strlen(s) + 1));
        strcpy(error_state.last_error,s);
        callback_id = callback_defined(show_error_message_callback);
        if (callback_id > 0) {
            run_callback(callback_id, "->");
        } else {
            tprint(s);
        }
        error_state.in_error = 0 ;
    }
}

void print_err(const char *s)
{
    int callback_id = callback_defined(show_error_message_callback);
    if (error_state.interaction == error_stop_mode) {
        wake_up_terminal();
    }
    if (callback_id > 0) {
        error_state.err_old_setting = selector;
        selector = new_string;
        error_state.in_error = 1 ;
    }
    tprint_nl("! ");
    tprint(s);
    if (callback_id <= 0) {
        free(error_state.last_error);
        error_state.last_error = (char *) malloc((unsigned) (strlen(s) + 1));
        strcpy(error_state.last_error,s);
    }
}

/*tex

    \TEX\ is careful not to call |error| when the print |selector| setting might
    be unusual. The only possible values of |selector| at the time of error
    messages are:

    \startitemize
        \startitem
            |no_print| (when |interaction=batch_mode| and |log_file| not yet open);
        \stopitem
        \startitem
            |term_only| (when |interaction>batch_mode| and |log_file| not yet open);
        \stopitem
        \startitem
            |log_only| (when |interaction=batch_mode| and |log_file| is open);
        \stopitem
        \startitem
            |term_and_log| (when |interaction>batch_mode| and |log_file| is open).
        \stopitem
    \stopitemize

*/

void fixup_selector(int logopened)
{
    if (error_state.interaction == batch_mode)
        selector = no_print;
    else
        selector = term_only;
    if (logopened)
        selector = selector + 2;
}

/*tex

    A variable |deletions_allowed| is set |0| if the |get_next| routine is
    active when |error| is called; this ensures that |get_next| and related
    routines like |get_token| will never be called recursively. A similar
    interlock is provided by |set_box_allowed|.

    The variable |history| records the worst level of error that has been
    detected. It has four possible values: |spotless|, |warning_issued|,
    |error_message_issued|, and |fatal_error_stop|.

    Another variable, |error_count|, is increased by one when an |error| occurs
    without an interactive dialog, and it is reset to zero at the end of every
    paragraph. If |error_count| reaches 100, \TEX\ decides that there is no point
    in continuing further.

    Interrupt related variables are |interrupt| and |OK_to_interrupt|.

    The value of |history| is initially |fatal_error_stop|, but it will be
    changed to |spotless| if \TEX\ survives the initialization process.

*/

void initialize_errors(void)
{
    error_state.interaction = error_stop_mode;
    error_state.deletions_allowed = 1;
    error_state.set_box_allowed = 1;
    error_state.OK_to_interrupt = 1;
}

/*tex

    It is possible for |error| to be called recursively if some error arises when
    |get_token| is being used to delete a token, and/or if some fatal error
    occurs while \TEX\ is trying to fix a non-fatal one. But such recursion is
    never more than two levels deep.

    Individual lines of help are recorded in the string |help_text|. There can be
    embedded newlines.

    The |jump_out| procedure just cuts across all active procedure levels and
    exits the program. It is used when there is no recovery from a particular
    error. The exit code can be overloaded.

*/

__attribute__ ((noreturn))
void do_final_end(void)
{
    update_terminal();
    main_state.ready_already = 0;
    lua_close(Luas);
    if ((error_state.history != spotless) && (error_state.history != warning_issued))
        exit(EXIT_FAILURE);
    else
        exit(error_state.defaultexitcode);
}

__attribute__ ((noreturn))
void jump_out(void)
{
    close_files_and_terminate();
    do_final_end();
}

/*tex This completes the job of error reporting: */

void error(void)
{
    int callback_id;
    /*tex Used to save global variables when deleting tokens: */
    flush_err();
    if (error_state.history < error_message_issued)
        error_state.history = error_message_issued;
    callback_id = callback_defined(show_error_hook_callback);
    if (callback_id > 0) {
        set_last_error_context();
        run_callback(callback_id, "->");
    } else {
        print_char('.');
        show_context();
    }
    if (error_state.interaction == error_stop_mode) {
        /*tex What the user types :*/
        unsigned char c;
        /*tex Get user's advice and |return|. */
        while (1) {
          CONTINUE:
            clear_for_error_prompt();
            prompt_input("? ");
            if (iolast == iofirst)
                return;
            c = iobuffer[iofirst];
            if (c >= 'a')
                c = c + 'A' - 'a';
            switch (c) {
                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8': case '9':
                    if (error_state.deletions_allowed) {
                        /*tex
                            Delete |0| tokens and |goto continue|. We allow
                            deletion of up to 99 tokens at a time.
                        */
                        int s1 = cur_tok;
                        int s2 = cur_cmd;
                        int s3 = cur_chr;
                        int s4 = align_state;
                        align_state = 1000000;
                        error_state.OK_to_interrupt = 0;
                        if ((iolast > iofirst + 1) && (iobuffer[iofirst + 1] >= '0') && (iobuffer[iofirst + 1] <= '9'))
                            c = c * 10 + iobuffer[iofirst + 1] - '0' * 11;
                        else
                            c = c - '0';
                        while (c > 0) {
                            /*tex One-level recursive call of |error| is possible. */
                            get_token();
                            decr(c);
                        }
                        cur_tok = s1;
                        cur_cmd = s2;
                        cur_chr = s3;
                        align_state = s4;
                        error_state.OK_to_interrupt = 1;
                        help(
                            "I have just deleted some text, as you asked.\n"
                            "You can now delete more, or insert, or whatever."
                        );
                        show_context();
                        goto CONTINUE;
                    }
                    break;
                case 'H':
                    /*tex Print the help information and |goto continue| */
                    if (error_state.use_err_help) {
                        give_err_help();
                    } else {
                        if (error_state.help_text == NULL) {
                            help(
                                "Sorry, I don't know how to help in this situation.\n"
                                "Maybe you should try asking a human?"
                            );
                        }
                        if (error_state.help_text != NULL) {
                            tprint_nl(error_state.help_text);
                        }
                        help(
                            "Sorry, I already gave what help I could...\n"
                            "Maybe you should try asking a human?\n"
                            "An error might have occurred before I noticed any problems.\n"
                            "``If all else fails, read the instructions.''"
                        );
                        goto CONTINUE;
                    }
                    break;
                case 'I':
                    /*tex

                        Introduce new material from the terminal and |return|. When
                        the following code is executed, |buffer[(first+1) .. (last-1)]|
                        may contain the material inserted by the user; otherwise
                        another prompt will be given. In order to understand this
                        part of the program fully, you need to be familiar with
                        \TEX's input stacks.

                        We enter a new syntactic level for terminal input:

                    */
                    begin_file_reading();
                    /*tex
                        Now |state=mid_line|, so an initial blank space will count as
                        a blank.
                    */
                    if (iolast > iofirst + 1) {
                        iloc = iofirst + 1;
                        iobuffer[iofirst] = ' ';
                    } else {
                        prompt_input("insert>");
                        iloc = iofirst;
                    }
                    iofirst = iolast;
                    /*tex No |end_line_char| ends this line. */
                    ilimit = iolast - 1;
                    return;
                    break;
                case 'Q':
                case 'R':
                case 'S':
                    /*tex

                        Change the interaction level and |return|. Here the author of
                        \TEX\ apologizes for making use of the numerical relation
                        between |Q|, |R|, |S|, and the desired interaction
                        settings |batch_mode|, |nonstop_mode|, |scroll_mode|.

                    */
                    error_state.error_count = 0;
                    error_state.interaction = batch_mode + c - 'Q';
                    tprint("OK, entering ");
                    switch (c) {
                        case 'Q':
                            tprint_esc("batchmode");
                            decr(selector);
                            break;
                        case 'R':
                            tprint_esc("nonstopmode");
                            break;
                        case 'S':
                            tprint_esc("scrollmode");
                            break;
                    }
                    tprint("...");
                    print_ln();
                    update_terminal();
                    return;
                    break;
                case 'X':
                    error_state.interaction = scroll_mode;
                    jump_out();
                    break;
                default:
                    break;
                }
            if (!error_state.use_err_help) {
                /* Print the menu of available options */
                tprint("Type <return> to proceed, S to scroll future error messages, ");
                tprint_nl("R to run without stopping, Q to run quietly, ");
                tprint_nl("I to insert something, ");
                if (error_state.deletions_allowed)
                    tprint_nl("1 or ... or 9 to ignore the next 1 to 9 tokens of input, ");
                tprint_nl("H for help, X to quit.");
            }
            error_state.use_err_help = 0;
        }

    }
    incr(error_state.error_count);
    if (error_state.error_count == 100) {
        tprint_nl("(That makes 100 errors; please try again.)");
        error_state.history = fatal_error_stop;
        jump_out();
    }
    /*tex Put help message on the transcript file. */
    if (error_state.interaction > batch_mode) {
        /*tex Avoid terminal output: */
        decr(selector);
    }
    if (error_state.use_err_help) {
        print_ln();
        give_err_help();
    } else if (error_state.help_text != NULL) {
        tprint_nl(error_state.help_text);
    }
    print_ln();
    if (error_state.interaction > batch_mode) {
        /*tex Re-enable terminal output: */
        incr(selector);
    }
    print_ln();
}

/*tex

    A dozen or so error messages end with a parenthesized integer, so we save a
    teeny bit of program space by declaring the following procedure:

*/

void int_error(int n)
{
    tprint(" (");
    print_int(n);
    print_char(')');
    error();
}

/*tex

    In anomalous cases, the print selector might be in an unknown state; the
    following subroutine is called to fix things just enough to keep running a
    bit longer.

*/

void normalize_selector(void)
{
    if (fileio_state.log_opened) {
        selector = term_and_log;
    } else {
        selector = term_only;
    }
    if (fileio_state.job_name == NULL) {
        open_log_file();
    }
    if (error_state.interaction == batch_mode) {
        decr(selector);
    }
}

/*tex The following procedure prints \TEX's last words before dying: */

void succumb(void)
{
    if (error_state.interaction == error_stop_mode) {
        /*tex No more interaction: */
        error_state.interaction = scroll_mode;
    }
    if (fileio_state.log_opened) {
        error();
    }
    error_state.history = fatal_error_stop;
    /*tex Irrecoverable error: */
    jump_out();
}

/*tex This prints |s|, and that's it. */

void fatal_error(const char *s)
{
    normalize_selector();
    print_err("Emergency stop");
    help(s);
    succumb();
}

/*tex Here is the most dreaded error message. We stop due to finiteness. */

void overflow(const char *s, unsigned int n)
{
    normalize_selector();
    print_err("TeX capacity exceeded, sorry [");
    tprint(s);
    print_char('=');
    print_int((int) n);
    print_char(']');
    if (out_of_memory()) {
        print_err("Sorry, I ran out of memory.");
        print_ln();
        exit(EXIT_FAILURE);
    }
    help(
        "If you really absolutely need more capacity,\n"
        "you can ask a wizard to enlarge me."
    );
    succumb();
}

/*tex

    The program might sometime run completely amok, at which point there is no
    choice but to stop. If no previous error has been detected, that's bad news;
    a message is printed that is really intended for the \TEX\ maintenance person
    instead of the user (unless the user has been particularly diabolical). The
    index entries for \quotation {this can't happen} may help to pinpoint the
    problem.

*/

void confusion(const char *s)
{
    /*tex A consistency check violated; |s| tells where: */
    normalize_selector();
    if (error_state.history < error_message_issued) {
        print_err("This can't happen (");
        tprint(s);
        print_char(')');
        help(
            "I'm broken. Please show this to someone who can fix"
        );
    } else {
        print_err("I can't go on meeting you like this");
        help(
            "One of your faux pas seems to have wounded me deeply...\n"
            "in fact, I'm barely conscious. Please fix it and try again."
        );
    }
    succumb();
}

/*tex

    Users occasionally want to interrupt \TEX\ while it's running. If the runtime
    system allows this, one can implement a routine that sets the global variable
    |interrupt| to some nonzero value when such an interrupt is signalled.
    Otherwise there is probably at least a way to make |interrupt| nonzero using
    the debugger.

*/

void check_interrupt(void)
{
    if (error_state.interrupt != 0)
        pause_for_instructions();
}

/*tex

    When an interrupt has been detected, the program goes into its highest
    interaction level and lets the user have nearly the full flexibility of the
    |error| routine. \TEX\ checks for interrupts only at times when it is safe to
    do this.

*/

void pause_for_instructions(void)
{
    if (error_state.OK_to_interrupt) {
        error_state.interaction = error_stop_mode;
        if ((selector == log_only) || (selector == no_print))
            incr(selector);
        print_err("Interruption");
        help(
            "You rang?\n"
            "Try to insert some instructions for me (e.g.,`I\\showlists'),\n"
            "unless you just want to quit by typing `X'."
        );
        error_state.deletions_allowed = 0;
        error();
        error_state.deletions_allowed = 1;
        error_state.interrupt = 0;
    }
}

void tex_error(const char *msg, const char *hlp)
{
    print_err(msg);
    error_state.help_text = hlp;
    error();
}

/*tex

    The |back_error| routine is used when we want to replace an offending token
    just before issuing an error message. This routine, like |back_input|,
    requires that |cur_tok| has been set. We disable interrupts during the call
    of |back_input| so that the help message won't be lost.

*/

void back_error(void)
{
    error_state.OK_to_interrupt = 0;
    back_input();
    error_state.OK_to_interrupt = 1;
    error();
}

/*tex Back up one inserted token and call |error|. */

void ins_error(void)
{
    error_state.OK_to_interrupt = 0;
    back_input();
    token_type = inserted;
    error_state.OK_to_interrupt = 1;
    error();
}

/*tex

    When \TEX\ wants to typeset a character that doesn't exist, the character
    node is not created; thus the output routine can assume that characters exist
    when it sees them. The following procedure prints a warning message unless
    the user has suppressed it.

*/

void char_warning(internal_font_number f, int c)
{
    if (tracing_lost_chars_par > 0) {
        /*tex saved value of |tracing_online| */
        int old_setting = tracing_online_par;
        /*tex index to current digit; we assume that $0\L n<16^{22}$ */
        int k = 0;
        if (tracing_lost_chars_par > 1)
            tracing_online_par = 1;
        begin_diagnostic();
        tprint_nl("Missing character: There is no ");
        print(c);
        tprint(" (U+");
        if (c < 16)
            print_char('0');
        if (c < 256)
            print_char('0');
        if (c < 4096)
            print_char('0');
        do {
            dig[k] = c % 16;
            c = c / 16;
            incr(k);
        } while (c != 0);
        print_the_digs((unsigned char) k);
        tprint(") in font ");
        print_font_name(f);
        print_char('!');
        end_diagnostic(0);
        tracing_online_par = old_setting;
    }
}

void normal_error(const char *t, const char *p)
{
    normalize_selector();
    if (error_state.interaction == error_stop_mode) {
        wake_up_terminal();
    }
    tprint_nl("! ");
    tprint("error: ");
    if (t != NULL) {
        tprint(" (");
        tprint(t);
        tprint(")");
    }
    tprint(": ");
    if (p != NULL)
        tprint(p);
    error_state.history = fatal_error_stop;
    exit(EXIT_FAILURE);
}

void normal_warning(const char *t, const char *p)
{
    int report_id ;
    if (strcmp(t,"lua") == 0) {
        int saved_new_line_char;
        saved_new_line_char = new_line_char_par;
        new_line_char_par = 10;
        report_id = callback_defined(show_lua_error_hook_callback);
        if (report_id == 0) {
            if (p == NULL) {
                tprint("unspecified lua error");
            } else {
                tprint(p);
            }
            help(
                "The lua interpreter ran into a problem, so the\n"
                "remainder of this lua chunk will be ignored."
            );
        } else {
            (void) run_callback(report_id, "->");
        }
        error();
        new_line_char_par = saved_new_line_char;
    } else {
        report_id = callback_defined(show_warning_message_callback);
        if (report_id > 0) {
            /*tex Free the last ones, */
            free(error_state.last_warning_str);
            free(error_state.last_warning_tag);
            error_state.last_warning_str = (char *) malloc(strlen(p) + 1);
            error_state.last_warning_tag = (char *) malloc(strlen(t) + 1);
            strcpy(error_state.last_warning_str,p);
            strcpy(error_state.last_warning_tag,t);
            run_callback(report_id, "->");
        } else {
            print_ln();
            tprint("warning ");
            if (t != NULL) {
                tprint(" (");
                tprint(t);
                tprint(")");
            }
            tprint(": ");
            if (p != NULL)
                tprint(p);
            print_ln();
        }
        if (error_state.history == spotless)
            error_state.history = warning_issued;
    }
}

__attribute__ ((format(printf,2,3)))
void formatted_error(const char *t, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(error_state.print_buf, print_buffer_size, fmt, args);
    normal_error(t,error_state.print_buf);
    va_end(args);
}

__attribute__ ((format(printf,2,3)))
void formatted_warning(const char *t, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(error_state.print_buf, print_buffer_size, fmt, args);
    normal_warning(t,error_state.print_buf);
    va_end(args);
}

__attribute__ ((format(printf,2,3)))
void emergency_message(const char *t, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(error_state.print_buf, print_buffer_size, fmt, args);
    fprintf(stdout,"%s : %s\n",t,error_state.print_buf);
    va_end(args);
}
