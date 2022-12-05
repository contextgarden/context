/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

print_state_info lmt_print_state = {
     .logfile               = NULL,
     .loggable_info         = NULL,
     .selector              = 0,
     .tally                 = 0,
     .terminal_offset       = 0,
     .logfile_offset        = 0,
     .new_string_line       = 0,
     .trick_buffer          = { 0 },
     .trick_count           = 0,
     .first_count           = 0,
     .saved_selector        = 0,
     .font_in_short_display = 0,
     .saved_logfile         = NULL,
     .saved_logfile_offset  = 0,
};

/*tex

    During the development of \LUAMETATEX\ reporting has been stepwise upgraded, for instance with more
    abstract print functions and a formatter. Much more detail is shown and additional tracing options
    have been added (like for marks, inserts, adjust, math, etc.). The format of the traditonal messages
    was mostly kept (sometimes under paramameter control using a higher tracing value) but after reading
    the nth ridiculous comment about logging in \LUATEX\ related to \CONTEXT\ I decided that it no
    longer made sense to offer compatibility because it will never satisfy everyone and we want to move
    on, so per spring 2022 we will see even further normalization and log compatility options get (are)
    dropped. If there are inconsistencies left, assume they will be dealt with. It's all about being able
    to recognize what gets logged. If someone longs for the old reporting, there are plenty alternative
    engines available.

    [where: ...] : all kind of tracing
    {...}        : more traditional tex tracing
    <...>        : if tracing (maybe)

*/

/*tex

    Messages that are sent to a user's terminal and to the transcript-log file are produced by
    several |print| procedures. These procedures will direct their output to a variety of places,
    based on the setting of the global variable |selector|, which has the following possible values:

    \startitemize

    \startitem
        |term_and_log|, the normal setting, prints on the terminal and on the transcript file.
    \stopitem

    \startitem
        |log_only|, prints only on the transcript file.
    \stopitem

    \startitem
        |term_only|, prints only on the terminal.
    \stopitem

    \startitem
        |no_print|, doesn't print at all. This is used only in rare cases before the transcript
        file is open.
    \stopitem

    \startitem
        |pseudo|, puts output into a cyclic buffer that is used by the |show_context| routine; when
        we get to that routine we shall discuss the reasoning behind this curious mode.
    \stopitem

    \startitem
        |new_string|, appends the output to the current string in the string pool.
    \stopitem

    \startitem
        0 to 15, prints on one of the sixteen files for |\write| output.
    \stopitem

    \stopitemize

    The symbolic names |term_and_log|, etc., have been assigned numeric codes that satisfy the
    convenient relations |no_print + 1 = term_only|, |no_print + 2 = log_only|, |term_only + 2 =
    log_only + 1 = term_and_log|.

    Three additional global variables, |tally| and |term_offset| and |file_offset|, record the
    number of characters that have been printed since they were most recently cleared to zero. We
    use |tally| to record the length of (possibly very long) stretches of printing; |term_offset|
    and |file_offset|, on the other hand, keep track of how many characters have appeared so far on
    the current line that has been output to the terminal or to the transcript file, respectively.

    The state structure collects: |new_string_line| and |escape_controls|, the transcript handle of
    a \TEX\ session: |log_file|, the target of a message: |selector|, the digits in a number being
    output |dig[23]|, the number of characters recently printed |tally|, the number of characters
    on the current terminal line |term_offset|, the number of characters on the current file line
    |file_offset|, the circular buffer for pseudoprinting |trick_buf|, the threshold for
    pseudoprinting (explained later) |trick_count|, another variable for pseudoprinting
    |first_count|, a blocker for minor adjustments to |show_token_list| namely |inhibit_par_tokens|.

    To end a line of text output, we call |print_ln|:

*/

void tex_print_ln(void)
{
    switch (lmt_print_state.selector) {
        case no_print_selector_code:
            break;
        case terminal_selector_code:
            fputc('\n', stdout);
            lmt_print_state.terminal_offset = 0;
            break;
        case logfile_selector_code:
            fputc('\n', lmt_print_state.logfile);
            lmt_print_state.logfile_offset = 0;
            break;
        case terminal_and_logfile_selector_code:
            fputc('\n', stdout);
            fputc('\n', lmt_print_state.logfile);
            lmt_print_state.terminal_offset = 0;
            lmt_print_state.logfile_offset = 0;
            break;
        case pseudo_selector_code:
            break;
        case new_string_selector_code:
            if (lmt_print_state.new_string_line > 0) {
                tex_print_char(lmt_print_state.new_string_line);
            }
            break;
        case luabuffer_selector_code:
            lmt_newline_to_buffer();
            break;
        default:
            break;
    }
    /*tex |tally| is not affected */
}


/*tex

    The |print_char| procedure sends one byte to the desired destination. All printing comes through
    |print_ln| or |print_char|, except for the case of |print_str| (see below).

    The checking of the line length is an inheritance from previous engines and we dropped it here.
    It doesn't make much sense nowadays. The same is true for escaping.

    Incrementing the tally ... only needed in pseudo mode :

*/

void tex_print_char(int s)
{
    if (s < 0 || s > 255) {
        tex_formatted_warning("print", "weird character %i", s);
    } else {
        switch (lmt_print_state.selector) {
            case no_print_selector_code:
                break;
            case terminal_selector_code:
                if (s == new_line_char_par) { 
                    fputc('\n', stdout);
                    lmt_print_state.terminal_offset = 0;
                } else { 
                    fputc(s, stdout);
                    ++lmt_print_state.terminal_offset;
                }
                break;
            case logfile_selector_code:
                if (s == new_line_char_par) { 
                    fputc('\n', lmt_print_state.logfile);
                    lmt_print_state.logfile_offset = 0;
                } else {
                    fputc(s, lmt_print_state.logfile);
                    ++lmt_print_state.logfile_offset;
                }
                break;
            case terminal_and_logfile_selector_code:
                if (s == new_line_char_par) { 
                    fputc('\n', stdout);
                    fputc('\n', lmt_print_state.logfile);
                    lmt_print_state.terminal_offset = 0;
                    lmt_print_state.logfile_offset = 0;
                } else { 
                    fputc(s, stdout);
                    fputc(s, lmt_print_state.logfile);
                    ++lmt_print_state.terminal_offset;
                    ++lmt_print_state.logfile_offset;
                }
                break;
            case pseudo_selector_code:
                if (lmt_print_state.tally < lmt_print_state.trick_count) {
                    lmt_print_state.trick_buffer[lmt_print_state.tally % lmt_error_state.line_limits.size] = (unsigned char) s;
                }
                ++lmt_print_state.tally;
                break;
            case new_string_selector_code:
                tex_append_char((unsigned char) s);
                break;
            case luabuffer_selector_code:
                lmt_char_to_buffer((char) s);
                break;
            default:
                break;
        }
    }
}

/*tex

    An entire string is output by calling |print|. Note that if we are outputting the single
    standard \ASCII\ character |c|, we could call |print("c")|, since |"c" = 99| is the number of a
    single-character string, as explained above. But |print_char("c")| is quicker, so \TEX\ goes
    directly to the |print_char| routine when it knows that this is safe. (The present
    implementation assumes that it is always safe to print a visible \ASCII\ character.)

    The first 256 entries above the 17th unicode plane are used for a special trick: when \TEX\ has
    to print items in that range, it will instead print the character that results from substracting
    0x110000 from that value. This allows byte-oriented output to things like |\specials|. We dropped 
    this feature because it was never used (we used it as part of experiments with \LUATEX). The old 
    code branches can be found in the repository. 

*/

static void tex_aux_uprint(int s)
{
    /*tex We're not sure about this so it's disabled for now! */
    /*
    if ((print_state.selector > pseudo_selector_code)) {
        / *tex internal strings are not expanded * /
        print_char(s);
        return;
    }
    */
    if (s == new_line_char_par && lmt_print_state.selector < pseudo_selector_code) {
        tex_print_ln();
        return;
    } else if (s <= 0x7F) {
        tex_print_char(s);
    } else if (s <= 0x7FF) {
        tex_print_char(0xC0 + (s / 0x40));
        tex_print_char(0x80 + (s % 0x40));
    } else if (s <= 0xFFFF) {
        tex_print_char(0xE0 + (s / 0x1000));
        tex_print_char(0x80 + ((s % 0x1000) / 0x40));
        tex_print_char(0x80 + ((s % 0x1000) % 0x40));
    } else {
        tex_print_char(0xF0 + (s / 0x40000));
        tex_print_char(0x80 + ((s % 0x40000) / 0x1000));
        tex_print_char(0x80 + (((s % 0x40000) % 0x1000) / 0x40));
        tex_print_char(0x80 + (((s % 0x40000) % 0x1000) % 0x40));
    }
}

void tex_print_tex_str(int s)
{
    if (s >= lmt_string_pool_state.string_pool_data.ptr) {
        tex_normal_warning("print", "bad string pointer");
    } else if (s < cs_offset_value) {
        if (s < 0) {
            tex_normal_warning("print", "bad string offset");
        } else {
            tex_aux_uprint(s);
        }
    } else if (lmt_print_state.selector == new_string_selector_code) {
        tex_append_string(str_string(s), (unsigned) str_length(s));
    } else {
        unsigned char *j = str_string(s);
        for (unsigned i = 0; i < str_length(s); i++) {
            tex_print_char(j[i]);
        }
    }
}

/*tex

    The procedure |print_nl| is like |print|, but it makes sure that the string appears at the
    beginning of a new line.

*/

void tex_print_nlp(void)
{
    if (lmt_print_state.new_string_line > 0) {
        tex_print_char(lmt_print_state.new_string_line);
    } else {
        switch (lmt_print_state.selector) {
             case terminal_selector_code:
                 if (lmt_print_state.terminal_offset > 0) {
                     fputc('\n', stdout);
                     lmt_print_state.terminal_offset = 0;
                 }
                 break;
             case logfile_selector_code:
                 if (lmt_print_state.logfile_offset > 0) {
                     fputc('\n', lmt_print_state.logfile);
                     lmt_print_state.logfile_offset = 0;
                 }
                 break;
             case terminal_and_logfile_selector_code:
                 if (lmt_print_state.terminal_offset > 0) {
                     fputc('\n', stdout);
                     lmt_print_state.terminal_offset = 0;
                 }
                 if (lmt_print_state.logfile_offset > 0) {
                     fputc('\n', lmt_print_state.logfile);
                     lmt_print_state.logfile_offset = 0;
                 }
                 break;
             case luabuffer_selector_code:
                 lmt_newline_to_buffer();
                 break;
        }
    }
}

/*tex

    The |char *| versions of the same procedures. |print_str| is different because it uses
    buffering, which works well because most of the output actually comes through |print_str|.

*/

void tex_print_str(const char *s)
{
    int logfile = 0;
    int terminal = 0;
    switch (lmt_print_state.selector) {
        case no_print_selector_code:
            return;
        case terminal_selector_code:
            terminal = 1;
            break;
        case logfile_selector_code:
            logfile = 1;
            break;
        case terminal_and_logfile_selector_code:
            logfile = 1;
            terminal = 1;
            break;
        case pseudo_selector_code:
            while ((*s) && (lmt_print_state.tally < lmt_print_state.trick_count)) {
                lmt_print_state.trick_buffer[lmt_print_state.tally % lmt_error_state.line_limits.size] = (unsigned char) *s++;
                lmt_print_state.tally++;
            }
            return;
        case new_string_selector_code:
            tex_append_string((const unsigned char *) s, (unsigned) strlen(s));
            return;
        case luabuffer_selector_code:
            lmt_string_to_buffer(s);
            return;
        default:
            break;
    }
    if (terminal || logfile) {
        int len = (int) strlen(s);
        if (logfile && ! lmt_fileio_state.log_opened) {
            logfile = 0;
        }
        if (len > 0) {
            int newline = s[len-1] == '\n';
            if (logfile) {
                fputs(s, lmt_print_state.logfile);
                if (newline) {
                    lmt_print_state.logfile_offset = 0;
                } else {
                    lmt_print_state.logfile_offset += len;
                }
            }
            if (terminal) {
                fputs(s, stdout);
                if (newline) {
                    lmt_print_state.terminal_offset = 0;
                } else {
                    lmt_print_state.terminal_offset += len;
                }
            }
        }
    }
}

/*tex

    Here is the very first thing that \TEX\ prints: a headline that identifies the version number
    and format package. The |term_offset| variable is temporarily incorrect, but the discrepancy is
    not serious since we assume that the banner and format identifier together will occupy at most
    |max_print_line| character positions. Well, we dropped that check in this variant.

    Maybe we should drop printing the format identifier.

*/

void tex_print_banner(void)
{
    fprintf(
        stdout,
        "%s %s\n",
        lmt_engine_state.luatex_banner,
        lmt_engine_state.dump_name
    );
}

void tex_print_log_banner(void)
{
    fprintf(
        lmt_print_state.logfile,
        "engine: %s, format id: %s, time stamp: %d-%d-%d %d:%d, startup file: %s, job name: %s",
        lmt_engine_state.luatex_banner,
        lmt_engine_state.dump_name,
        year_par, month_par > 12 ? 0 : month_par, day_par, time_par / 60, time_par % 60,
        lmt_engine_state.startup_filename ? lmt_engine_state.startup_filename : "-",
        lmt_engine_state.startup_jobname ? lmt_engine_state.startup_jobname : "-"
    );
}

void tex_print_version_banner(void)
{
    fputs(lmt_engine_state.luatex_banner, stdout);
}

/*tex

    The procedure |print_esc| prints a string that is preceded by the user's escape character
    (which is usually a backslash).

*/

void tex_print_tex_str_esc(strnumber s)
{
    /*tex Set variable |c| to the current escape character: */
    int c = escape_char_par;
    if (c >= 0) {
        tex_print_tex_str(c);
    }
    if (s) {
        tex_print_tex_str(s);
    }
}

/*tex This prints escape character, then |s|. */

void tex_print_str_esc(const char *s)
{
    /*tex Set variable |c| to the current escape character: */
    int c = escape_char_par;
    if (c >= 0) {
        tex_print_tex_str(c);
    }
    if (s) {
        tex_print_str(s);
    }
}

/*tex

    The following procedure, which prints out the decimal representation of a given integer |n|,
    has been written carefully so that it works properly if |n = 0| or if |(-n)| would cause
    overflow. It does not apply |mod| or |div| to negative arguments, since such operations are not
    implemented consistently by all \PASCAL\ compilers.

*/

void tex_print_int(int n)
{
    /*tex In the end a 0..9 fast path works out best; using |sprintf| is slower. */
    if (n < 0) {
        tex_print_char('-');
        n = -n; 
    }
    if (n >= 0 && n <= 9) { 
        tex_print_char('0' + n);
    } else if (n >= 0 && n <= 99) { 
        tex_print_char('0' + n/10);
        tex_print_char('0' + n%10);
    } else { 
        int k = 0;
        unsigned char digits[24];
//        if (n < 0) {
//            tex_print_char('-');
//            n = -n; 
//        }
        do {
            digits[k] = '0' + (unsigned char) (n % 10);
            n = n / 10;
            ++k;
        } while (n != 0);
        while (k-- > 0) {
            tex_print_char(digits[k]);
        }
    }
}

/*tex

    Conversely, here is a procedure analogous to |print_int|. If the output of this procedure is
    subsequently read by \TEX\ and converted by the |round_decimals| routine above, it turns out
    that the original value will be reproduced exactly; the \quote {simplest} such decimal number
    is output, but there is always at least one digit following the decimal point.

    The invariant relation in the |repeat| loop is that a sequence of decimal digits yet to be
    printed will yield the original number if and only if they form a fraction~$f$ in the range $s
    - \delta \L10 \cdot 2^{16} f < s$. We can stop if and only if $f = 0$ satisfies this condition;
    the loop will terminate before $s$ can possibly become zero.

    The next one prints a scaled real, rounded to five digits.

*/

void tex_print_dimension(scaled s, int unit)
{
    if (s == 0) {
        tex_print_str("0.0"); /* really .. just 0 is not ok for some applications */
    } else {
        /*tex The amount of allowable inaccuracy: */
        scaled delta = 10;
        char buffer[20] = { 0 } ;
        int i = 0;
        if (s < 0) {
            /*tex Print the sign, if negative. */
            tex_print_char('-');
            s = -s;
        }
        /*tex Print the integer part. */
        tex_print_int(s / unity);
        buffer[i++] = '.';
        s = 10 * (s % unity) + 5;
        do {
            if (delta > unity) {
                /*tex Round the last digit. */
                s = s + 0100000 - 50000;
            }
            buffer[i++] = (unsigned char) ('0' + (s / unity));
            s = 10 * (s % unity);
            delta *= 10;
        } while (s > delta);
     // buffer[i++] = '\0';
        tex_print_str(buffer);
    }
    if (unit != no_unit) {
        tex_print_unit(unit);
    }
}

void tex_print_sparse_dimension(scaled s, int unit)
{
    if (s == 0) {
        tex_print_char('0');
    } else if (s == unity) {
        tex_print_char('1');
    } else {
        /*tex The amount of allowable inaccuracy: */
        scaled delta = 10;
        char buffer[20];
        int i = 0;
        if (s < 0) {
            /*tex Print the sign, if negative. */
            tex_print_char('-');
            /*tex So we trust it here while in printing int we mess around. */
            s = -s; 
        }
        /*tex Print the integer part. */
        tex_print_int(s / unity);
        s = 10 * (s % unity) + 5;
        do {
            if (delta > unity) {
                /*tex Round the last digit. */
                s = s + 0100000 - 50000;
            }
            buffer[i++] = (unsigned char) ('0' + (s / unity));
            s = 10 * (s % unity);
            delta *= 10;
        } while (s > delta);
        if (i == 1 && buffer[i-1] == '0') {
            /* no need */
        } else { 
            buffer[i++] = '\0';
            tex_print_char('.');
            tex_print_str(buffer);
        }
    }
    if (unit != no_unit) {
        tex_print_unit(unit);
    }
}

/*tex

    Hexadecimal printing of nonnegative integers is accomplished by |print_hex|. We have a few 
    variants. Because we have bitsets that can give upto |0xFFFFFFFF| we treat the given integer
    as an unsigned. 
*/

void tex_print_hex(int sn)
{
    unsigned int n = (unsigned int) sn;
    int k = 0;
    unsigned char digits[24];
    do {
        unsigned char d = (unsigned char) (n % 16);
        if (d < 10) {
            digits[k] = '0' + d;
        } else {
            digits[k] = 'A' - 10 + d;
        }
        n = n / 16;
        ++k;
    } while (n != 0);
    while (k-- > 0) {
        tex_print_char(digits[k]);
    }
}

void tex_print_qhex(int n)
{
    tex_print_char('"');
    tex_print_hex(n);
}

void tex_print_uhex(int n)
{
    tex_print_str("U+");
    if (n < 16) {
        tex_print_char('0');
    }
    if (n < 256) {
        tex_print_char('0');
    }
    if (n < 4096) {
        tex_print_char('0');
    }
    tex_print_hex(n);
}

/*tex

    Roman numerals are produced by the |print_roman_int| routine. Readers who like puzzles might
    enjoy trying to figure out how this tricky code works; therefore no explanation will be given.
    Notice that 1990 yields |mcmxc|, not |mxm|.

*/

void tex_print_roman_int(int n)
{
    char mystery[] = "m2d5c2l5x2v5i";
    char *j = (char *) mystery;
    int v = 1000;
    while (1) {
        while (n >= v) {
            tex_print_char(*j);
            n = n - v;
        }
        if (n <= 0) {
            /*tex nonpositive input produces no output */
            return;
        } else {
            char *k = j + 2;
            int u = v / (*(k - 1) - '0');
            if (*(k - 1) == '2') {
                k = k + 2;
                u = u / (*(k - 1) - '0');
            }
            if (n + u >= v) {
                tex_print_char(*k);
                n = n + u;
            } else {
                j = j + 2;
                v = v / (*(j - 1) - '0');
            }
        }
    }
}

/*tex

    The |print| subroutine will not print a string that is still being created. The following
    procedure will.

*/

void tex_print_current_string(void)
{
    for (int j = 0; j < lmt_string_pool_state.string_temp_top; j++) {
        tex_print_char(lmt_string_pool_state.string_temp[j++]);
    }
}

/*tex

    The procedure |print_cs| prints the name of a control sequence, given a pointer to its address
    in |eqtb|. A space is printed after the name unless it is a single nonletter or an active
    character. This procedure might be invoked with invalid data, so it is \quote {extra robust}.
    The individual characters must be printed one at a time using |print|, since they may be
    unprintable.

*/

void tex_print_cs_checked(halfword p)
{
    switch (tex_cs_state(p)) {
        case cs_no_error:
            {
                strnumber t = cs_text(p);
                if (t < 0 || t >= lmt_string_pool_state.string_pool_data.ptr) {
                    tex_print_str(error_string_nonexistent(13));
                } else if (tex_is_active_cs(t)) {
                    tex_print_tex_str(active_cs_value(t));
                } else {
                    tex_print_tex_str_esc(t);
                    if (! tex_single_letter(t) || (tex_get_cat_code(cat_code_table_par, aux_str2uni(str_string(t))) == letter_cmd)) {
                        tex_print_char(' ');
                    }
                }
            }
            break;
        case cs_null_error:
            tex_print_str_esc("csname");
            tex_print_str_esc("endcsname");
            tex_print_char(' ');
            break;
        case cs_below_base_error:
            tex_print_str(error_string_impossible(11));
            break;
        case cs_undefined_error:
            tex_print_str_esc("undefined");
            tex_print_char(' ');
            break;
        case cs_out_of_range_error:
            tex_print_str(error_string_impossible(12));
            break;
    } 
}

/*tex

    Here is a similar procedure; it avoids the error checks, and it never prints a space after the
    control sequence. The other one doesn't even print the bogus cs.

*/

void tex_print_cs(halfword p)
{
    if (p == null_cs) {
        tex_print_str_esc("csname");
        tex_print_str_esc("endcsname");
    } else {
        strnumber t = cs_text(p);
        if (tex_is_active_cs(t)) {
            tex_print_tex_str(active_cs_value(t));
        } else {
            tex_print_tex_str_esc(t);
        }
    }
}

void tex_print_cs_name(halfword p)
{
    if (p != null_cs) {
        strnumber t = cs_text(p);
        if (tex_is_active_cs(t)) {
            tex_print_tex_str(active_cs_value(t));
        } else {
            tex_print_tex_str(t);
        }
    }
}

/*tex

    Then there is a subroutine that prints glue stretch and shrink, possibly followed by the name
    of finite units:

*/

void tex_print_glue(scaled d, int order, int unit)
{
    tex_print_dimension(d, no_unit);
    if ((order < normal_glue_order) || (order > filll_glue_order)) {
        tex_print_str("foul");
    } else if (order > normal_glue_order) {
        tex_print_str("fi");
        while (order > fi_glue_order) {
            tex_print_char('l');
            --order;
        }
    } else {
        tex_print_unit(unit);
    }
}

/*tex The next subroutine prints a whole glue specification. */

void tex_print_unit(int unit)
{
    if (unit != no_unit) {
        tex_print_str(unit == pt_unit ? "pt" : "mu");
    }
}

void tex_print_spec(int p, int unit)
{
    if (p < 0) {
        tex_print_char('*');
    } else if (p == 0) {
        tex_print_dimension(0, unit);
    } else {
        tex_print_dimension(glue_amount(p), unit);
        if (glue_stretch(p)) {
            tex_print_str(" plus ");
            tex_print_glue(glue_stretch(p), glue_stretch_order(p), unit);
        }
        if (glue_shrink(p)) {
            tex_print_str(" minus ");
            tex_print_glue(glue_shrink(p), glue_shrink_order(p), unit);
        }
    }
}

void tex_print_fontspec(int p)
{
    tex_print_int(font_spec_identifier(p));
    if (font_spec_scale(p) != unused_scale_value) {
        tex_print_str(" scale ");
        tex_print_int(font_spec_scale(p));
    }
    if (font_spec_x_scale(p) != unused_scale_value) {
        tex_print_str(" xscale ");
        tex_print_int(font_spec_x_scale(p));
    }
    if (font_spec_y_scale(p) != unused_scale_value) {
        tex_print_str(" yscale ");
        tex_print_int(font_spec_y_scale(p));
    }
}

/*tex Math characters: */

void tex_print_mathspec(int p)
{
    if (p) {
        mathcodeval m = tex_get_math_spec(p);
        tex_show_mathcode_value(m, node_subtype(p));
    } else {
        tex_print_str("[invalid mathspec]");
    }
}

/*tex

    We can reinforce our knowledge of the data structures just introduced by considering two
    procedures that display a list in symbolic form. The first of these, called |short_display|, is
    used in \quotation {overfull box} messages to give the top-level description of a list. The
    other one, called |show_node_list|, prints a detailed description of exactly what is in the
    data structure.

    The philosophy of |short_display| is to ignore the fine points about exactly what is inside
    boxes, except that ligatures and discretionary breaks are expanded. As a result,
    |short_display| is a recursive procedure, but the recursion is never more than one level deep.

    A global variable |font_in_short_display| keeps track of the font code that is assumed to be
    present when |short_display| begins; deviations from this font will be printed.

    Boxes, rules, inserts, whatsits, marks, and things in general that are sort of \quote
    {complicated} are indicated only by printing |[]|.

    We print a bit more than original \TEX. A value of 0 or 1 or any large value will behave the
    same as before. The reason for this extension is that a |name| not always makes sense.

    \starttyping
    0   \foo xyz
    1   \foo (bar)
    2   <bar> xyz
    3   <bar @ ..> xyz
    4   <id>
    5   <id: bar>
    6   <id: bar @ ..> xyz
    \stoptyping

    This is no longer the case: we now always print a full specification. The |\tracingfonts|
    register will be dropped. 

*/

void tex_print_char_identifier(halfword c) // todo: use string_print_format
{
    if (c <= 0x10FFFF) {
        char b[10];
        if ( (c >= 0x00E000 && c <= 0x00F8FF) || (c >= 0x0F0000 && c <= 0x0FFFFF) ||
             (c >= 0x100000 && c <= 0x10FFFF) || (c >= 0x00D800 && c <= 0x00DFFF) ) {
            sprintf(b, "0x%06X", c);
            tex_print_str(b);
        } else {
            sprintf(b, "U+%06X", c);
            tex_print_str(b);
            tex_print_char(' ');
            tex_print_tex_str(c);
        }
    }
}

void tex_print_font_identifier(halfword f)
{
    /*tex |< >| is less likely to clash with text parenthesis */
    if (tex_is_valid_font(f)) {
     // switch (tracing_fonts_par) {
     //    case 0:
     //    case 1:
     //        if (font_original(f)) {
     //            tex_print_format(font_original(f));
     //        } else {
     //            tex_print_format("font: %i", f);
     //        }
     //        if (tracing_fonts_par == 0) {
     //            break;
     //        } else if (font_size(f) == font_design_size(f)) {
     //            tex_print_format(" (%s)", font_name(f));
     //        } else {
     //            tex_print_format(" (%s @ %D)", font_name(f), font_size(f), pt_unit);
     //        }
     //        break;
     //    case 2:
     //        tex_print_format("<%s>", font_name(f));
     //        break;
     //    case 3:
     //        tex_print_format("<%s @ %D>", font_name(f), font_size(f), pt_unit);
     //        break;
     //    case 4:
     //        tex_print_format("<%i>", f);
     //        break;
     //    case 5:
     //        tex_print_format("<%i: %s>", f, font_name(f));
     //        break;
     // /* case 6: */
     //    default:
                tex_print_format("<%i: %s @ %D>", f, font_name(f), font_size(f), pt_unit);
     //         break;
     // }
    } else {
        tex_print_str("<*>");
    }
}

void tex_print_font_specifier(halfword e)
{
    if (e && tex_is_valid_font(font_spec_identifier(e))) {
        tex_print_format("<%i: %i %i %i>", font_spec_identifier(e), font_spec_scale(e), font_spec_x_scale(e), font_spec_y_scale(e));
    } else {
        tex_print_str("<*>");
    }
}

void tex_print_font(halfword f)
{
    if (! f) {
        tex_print_str("nullfont");
    } else if (tex_is_valid_font(f)) {
        tex_print_str(font_name(f));
     /* if (font_size(f) != font_design_size(f)) { */
            /*tex
                Nowadays this check for designsize is rather meaningless so we could as well
                always enter this branch. We can even make this while blob a callback.
            */
            tex_print_format(" at %D", font_size(f), pt_unit);
     /* } */
    } else {
        tex_print_str("nofont");
    }
}

/*tex This prints highlights of list |p|. */

void tex_short_display(halfword p)
{
    tex_print_levels();
    if (p) {
        tex_print_short_node_contents(p);
    } else {
        tex_print_str("empty list");
    }
}

/*tex This prints token list data in braces. */

void tex_print_token_list(const char *s, halfword p)
{
    tex_print_levels();
    tex_print_str("..");
    if (s) {
        tex_print_str(s);
        tex_print_char(' ');
    }
    tex_print_char('{');
    if ((p >= 0) && (p <= (int) lmt_token_memory_state.tokens_data.top)) {
        tex_show_token_list(p, null, default_token_show_max, 0);
    } else {
        tex_print_str(error_string_clobbered(21));
    }
    tex_print_char('}');
}

/*tex This prints dimensions of a rule node. */

void tex_print_rule_dimen(scaled d)
{
    if (d == null_flag) {
        tex_print_char('*');
    } else {
        tex_print_dimension(d, pt_unit);
    }
}

/*tex

    Since boxes can be inside of boxes, |show_node_list| is inherently recursive, up to a given
    maximum number of levels. The history of nesting is indicated by the current string, which
    will be printed at the beginning of each line; the length of this string, namely |cur_length|,
    is the depth of nesting.

    A global variable called |depth_threshold| is used to record the maximum depth of nesting for
    which |show_node_list| will show information. If we have |depth_threshold = 0|, for example,
    only the top level information will be given and no sublists will be traversed. Another global
    variable, called |breadth_max|, tells the maximum number of items to show at each level;
    |breadth_max| had better be positive, or you won't see anything.

    The maximum nesting depth in box displays is kept in |depth_threshold| and the maximum number
    of items shown at the same list level in |breadth_max|.

    The recursive machinery is started by calling |show_box|. Assign the values |depth_threshold :=
    show_box_depth| and |breadth_max := show_box_breadth|

*/

void tex_show_box(halfword p)
{
    /*tex the show starts at |p| */
    tex_show_node_list(p, show_box_depth_par, show_box_breadth_par);
    tex_print_ln();
}

/*tex

    \TEX\ is occasionally supposed to print diagnostic information that goes only into the
    transcript file, unless |tracing_online| is positive. Here are two routines that adjust the
    destination of print commands:

*/

void tex_begin_diagnostic(void)
{
    lmt_print_state.saved_selector = lmt_print_state.selector;
    if ((tracing_online_par <= 0) && (lmt_print_state.selector == terminal_and_logfile_selector_code)) {
        lmt_print_state.selector = logfile_selector_code;
        if (lmt_error_state.history == spotless) {
            lmt_error_state.history = warning_issued;
        }
    }
    tex_print_levels();
}

/*tex Restore proper conditions after tracing. */

void tex_end_diagnostic(void)
{
    tex_print_nlp();
    lmt_print_state.selector = lmt_print_state.saved_selector;
}

static void tex_print_padding(void)
{
    switch (lmt_print_state.selector) {
        case terminal_selector_code:
            if (! odd(lmt_print_state.terminal_offset)) {
                tex_print_char(' ');
            }
            break;
        case logfile_selector_code:
        case terminal_and_logfile_selector_code:
            if (! odd(lmt_print_state.logfile_offset)) {
                tex_print_char(' ');
            }
            break;
        case luabuffer_selector_code:
            break;
    }
}

void tex_print_levels(void)
{
    int l0 = tracing_levels_par;
    tex_print_nlp();
    if (l0 > 0) {
        int l1 = (l0 & 0x01) == tracing_levels_group;
        int l2 = (l0 & 0x02) == tracing_levels_input;
        int l4 = (l0 & 0x04) == tracing_levels_catcodes;
        if (l1) {
            tex_print_int(cur_level);
            tex_print_char(':');
        }
        if (l2) {
            tex_print_int(lmt_input_state.input_stack_data.ptr);
            tex_print_char(':');
        }
        if (l4) {
            tex_print_int(cat_code_table_par);
            tex_print_char(':');
        }
        if (l1 || l2 || l4) {
            tex_print_char(' ');
        }
        tex_print_padding();
    }
}

/* maybe %GROUP% where we scan upto [UPPER][%], so %G and %GR are also is ok

    shared with error messages, so at some point we will merge:

    %c   int       char
    %s  *char      string
    %q  *char      'string'
    %i   int       integer
    %e             backslash (tex escape)
    %C   int int   symbolic representation of cmd chr
    %E  *char      \cs
    %S   int       tex cs string
    %M   int       mode
    %T   int       tex string
    %%             percent

    specific for print (I need to identify the rest)

 !  %U   int       unicode
 !  %D   int       dimension

 !  %B   int       badness
 !  %G   int       group

 !  %L   int      (if) linenumber

*/

const char *tex_print_format_args(const char *format, va_list args)
{
    while (1) {
        int chr = *format++;
        switch (chr) {
            case '\0':
                return va_arg(args, char *);
            case '%':
                {
                    chr = *format++;
                    switch (chr) {
                        case '\0':
                            return va_arg(args, char *);
                        case 'c':
                            tex_print_char(va_arg(args, int));
                            break;
                        case 'e':
                            tex_print_str_esc(NULL);
                            break;
                        case 'i':
                            tex_print_int(va_arg(args, int));
                            break;
                        case 'l':
                            tex_print_levels();
                            break;
                        case 'n':
                            tex_print_extended_subtype(null, (quarterword) va_arg(args, int));
                            break;
                        case 'm':
                            tex_print_cs_checked(va_arg(args, int));
                            break;
                        case 's':
                            tex_print_str(va_arg(args, char *));
                            break;
                        case 'q':
                            tex_print_char('\'');
                            tex_print_str(va_arg(args, char *));
                            tex_print_char('\'');
                            break;
                        case 'x':
                            tex_print_qhex(va_arg(args, int));
                            break;
                        /*
                        case 'u':
                            tex_print_unit(va_arg(args, int));
                            break;
                        */
                        case 'B': /* badness */
                            {
                                scaled b = va_arg(args, halfword);
                                if (b == awful_bad) {
                                    tex_print_char('*');
                                } else {
                                    tex_print_int(b);
                                }
                                break;
                            }
                        case 'C':
                            {
                                int cmd = va_arg(args, int);
                                int val = va_arg(args, int);
                                tex_print_cmd_chr((singleword) cmd, val); /* inlining doesn't work */
                                break;
                            }
                        case 'D': /* dimension */
                            {
                                scaled s = va_arg(args, scaled);
                                int u = va_arg(args, int);
                                tex_print_dimension(s, u);
                                break;
                            }
                        case 'E':
                            tex_print_str_esc(va_arg(args, char *));
                            break;
                        case 'G':
                            {
                                halfword g = va_arg(args, int);
                                tex_print_group(g);
                                break;
                            }
                        case 'F':
                            {
                                halfword i = va_arg(args, int);
                                tex_print_font_identifier(i);
                                break;
                            }
                        case 'L':
                            {
                                /* typically used for if line */
                                halfword line = va_arg(args, int);
                                if (line) {
                                    tex_print_str(" entered on line ");
                                    tex_print_int(line);
                                }
                                break;
                            }
                        case 'M':
                            {
                                halfword mode = va_arg(args, int);
                                tex_print_str(tex_string_mode(mode));
                                break;
                            }
                        case 'P':
                            {
                                scaled total = va_arg(args, int);
                                scaled stretch = va_arg(args, int);
                                scaled filstretch = va_arg(args, int);
                                scaled fillstretch = va_arg(args, int);
                                scaled filllstretch = va_arg(args, int);
                                scaled shrink= va_arg(args, int);
                                tex_print_dimension(total, pt_unit);
                                if (stretch) {
                                    tex_print_str(" plus ");
                                    tex_print_dimension(stretch, pt_unit);
                                } else if (filstretch) {
                                    tex_print_str(" plus ");
                                    tex_print_dimension(filstretch, no_unit);
                                    tex_print_str(" fil");
                                } else if (fillstretch) {
                                    tex_print_str(" plus ");
                                    tex_print_dimension(fillstretch, no_unit);
                                    tex_print_str(" fill");
                                } else if (filllstretch) {
                                    tex_print_str(" plus ");
                                    tex_print_dimension(fillstretch, no_unit);
                                    tex_print_str(" filll");
                                }
                                if (shrink) {
                                    tex_print_str(" minus ");
                                    tex_print_dimension(shrink, pt_unit);
                                }
                                break;
                            }
                        case 'Q':
                            {
                                scaled s = va_arg(args, scaled);
                                int u = va_arg(args, int);
                                tex_print_spec(s, u);
                                break;
                            }
                        case 'R':
                            {
                                halfword d = va_arg(args, int);
                                tex_print_rule_dimen(d);
                                break;
                            }
                        case 'S':
                            {
                                halfword cs = va_arg(args, int);
                                tex_print_cs(cs);
                                break;
                            }
                        case 'T':
                            {
                                strnumber s = va_arg(args, int);
                                tex_print_tex_str(s);
                                break;
                            }
                        case 'U':
                            {
                                halfword c = va_arg(args, int);
                                tex_print_uhex(c);
                                break;
                            }
                        case '%':
                            tex_print_char('%');
                            break;
                     // case '[':
                     //     tex_begin_diagnostic();
                     //     tex_print_char('[');
                     //     break;
                     // case ']':
                     //     tex_print_char(']');
                     //     tex_end_diagnostic();
                     //     break;
                        default:
                            /* ignore bad one */
                            break;
                    }
                }
                break;
            default:
                tex_print_char(chr); /* todo: utf */
                break;
        }
    }
}

void tex_print_format(const char *format, ...)
{
    va_list args;
    va_start(args, format); /* hm, weird, no number */
    tex_print_format_args(format, args);
    va_end(args);
}

/*tex

    Group codes were introduced in \ETEX\ but have been extended in the meantime in \LUATEX\ and
    later again in \LUAMETATEX. We might have (even) more granularity in the future.

    Todo: combine this with an array of struct(id,name,lua) ... a rainy day + stack of new cd's job.

*/

void tex_print_group(int e)
{
    int line = tex_saved_line_at_level();
    tex_print_str(lmt_interface.group_code_values[cur_group].name);
    if (cur_group != bottom_level_group) {
        tex_print_str(" group");
        if (line) {
            tex_print_str(e ? " entered at line " : " at line ");
            tex_print_int(line);
        }
    }
}

void tex_print_message(const char *s)
{
    tex_print_nlp();
    tex_print_char('(');
    tex_print_str(s);
    tex_print_char(')');
    tex_print_nlp();
}
