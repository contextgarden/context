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
     .nesting_depth         = 0,
};

/*tex

    During the development of \LUAMETATEX\ reporting has been stepwise upgraded, for instance with more
    abstract print functions and a formatter. Much more detail is shown and additional tracing options
    have been added (like for marks, inserts, adjust, math, etc.). The format of the traditonal messages
    was mostly kept (sometimes under paramameter control using a higher tracing value) but after reading
    the nth ridiculous comment about logging in \LUATEX\ related to \CONTEXT\ I decided that it no
    longer made sense to offer compatibility because it will never satisfy everyone and we want to move
    on, so per spring 2022 we will see even further normalization and log compatibility options get (are)
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
    |file_offset|, the circular buffer for pseudo printing |trick_buf|, the threshold for
    pseudo printing (explained later) |trick_count|, another variable for pseudo printing
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

    First a few helpers. Pseudo printing only happens when we have an error message and have
    to collect a few lines in a way that works well with excessively long token lists that
    the get serialized. The two helpers are non-critical but nevertheless optimized i.e.
    we don't go char-by-char when we have a string.

*/

static inline void tex_aux_print_pseudo_string(const unsigned char *s, size_t len)
{
    size_t buf_size = (size_t)lmt_error_state.line_limits.size;
    if (buf_size > 0 && lmt_print_state.tally < lmt_print_state.trick_count) {
        size_t avail = (size_t)(lmt_print_state.trick_count - lmt_print_state.tally);
        size_t to_copy = (len < avail) ? len : avail;
        if (to_copy > 0) {
            /* Check if the chunk wraps around the circular buffer boundary */
            size_t offset = (size_t)(lmt_print_state.tally % buf_size);
            if (offset + to_copy <= buf_size) {
                memcpy(&lmt_print_state.trick_buffer[offset], s, to_copy);
            } else {
                size_t first_part = buf_size - offset;
                memcpy(&lmt_print_state.trick_buffer[offset], s, first_part);
                memcpy(&lmt_print_state.trick_buffer[0], s + first_part, to_copy - first_part);
            }
        }
    }
    lmt_print_state.tally += (int) len;
}

static inline void tex_aux_print_pseudo_char(unsigned char c)
{
    int k = lmt_print_state.tally++;
    size_t buf_size = (size_t)lmt_error_state.line_limits.size;
    if (k < lmt_print_state.trick_count && buf_size > 0) {
        lmt_print_state.trick_buffer[k % buf_size] = c;
    }
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
 // s = s < 0 ? 0 : (s > 255 ? 255 : s);
    if lmt_unlikely(s < 0 || s > 255) {
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
             // if (lmt_print_state.tally < lmt_print_state.trick_count) {
             //     lmt_print_state.trick_buffer[lmt_print_state.tally % lmt_error_state.line_limits.size] = (unsigned char) s;
             // }
             // ++lmt_print_state.tally;
                tex_aux_print_pseudo_char((unsigned char) s);
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

/* no_print terminal | logfile | terminal_and_logfile | pseudo | new_string | luabuffer */

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
    } else {
        aux_uni2str_callback((unsigned) s, &tex_print_char);
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
        tex_append_string(str_getstr(s), str_getlen(s));
    } else {
        lstring_string j = str_getstr(s);
        for (lstring_length i = 0; i < str_getlen(s); i++) {
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

void tex_print_str_len(const char *s, int len)
{
    if (len <= 0 || ! s) {
        return;
    }
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
         // while (len-- && (lmt_print_state.tally < lmt_print_state.trick_count)) {
         //     lmt_print_state.trick_buffer[lmt_print_state.tally % lmt_error_state.line_limits.size] = (unsigned char) *s++;
         //     lmt_print_state.tally++;
         // }
            tex_aux_print_pseudo_string((const unsigned char *) s, (size_t) len);
            return;
        case new_string_selector_code:
            tex_append_string((const unsigned char *) s, (unsigned) len);
            return;
        case luabuffer_selector_code:
            lmt_string_to_buffer_len(s, len);
            return;
        default:
            return;
    }
    if (terminal || logfile) {
        if (logfile && ! lmt_fileio_state.log_opened) {
            logfile = 0;
        }
        int newline = (s[len-1] == '\n');
        if (logfile) {
            fwrite(s, 1, len, lmt_print_state.logfile);
            if (newline) {
                lmt_print_state.logfile_offset = 0;
            } else {
                lmt_print_state.logfile_offset += len;
            }
        }
        if (terminal) {
            fwrite(s, 1, len, stdout);
            if (newline) {
                lmt_print_state.terminal_offset = 0;
            } else {
                lmt_print_state.terminal_offset += len;
            }
        }
    }
}

void tex_print_str(const char *s)
{
    if (s) {
        tex_print_str_len(s, (int) strlen(s));
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

static inline void tex_print_tex_str_esc(strnumber s)
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

static inline void tex_print_str_esc(const char *s)
{
    /*tex Set variable |c| to the current escape character: */
    int c = escape_char_par;
    if (c >= 0) {
        tex_print_tex_str(c);
    }
    if (s && s[0]) {
        tex_print_str(s);
    }
}

/*tex

    The following procedure, which prints out the decimal representation of a given integer |n|,
    has been written carefully so that it works properly if |n = 0| or if |(-n)| would cause
    overflow. It does not apply |mod| or |div| to negative arguments, since such operations are not
    implemented consistently by all \PASCAL\ compilers.

*/

# if 0

    void tex_print_int(int n)
    {
        if (n < 0) {
            tex_print_char('-');
            n = -n;
        }
        if (n >= 0 && n <= 9) {
            tex_print_char('0' + n);
        } else if (n >= 0 && n <= 99) {
            tex_print_char('0' + n / 10);
            tex_print_char('0' + n % 10);
        } else {
            int k = 0;
            unsigned char digits[24];
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

# else

    static const char DIGIT_PAIRS[] =
        "00010203040506070809"
        "10111213141516171819"
        "20212223242526272829"
        "30313233343536373839"
        "40414243444546474849"
        "50515253545556575859"
        "60616263646566676869"
        "70717273747576777879"
        "80818283848586878889"
        "90919293949596979899";

    void tex_print_int(int n)
    {
        // Max size for 32-bit int: 1 byte sign + 10 digits = 11 bytes.
        // 16 bytes provides a safe, 16-byte aligned stack allocation.
        char buf[16];
        char *p = buf + sizeof(buf);
        // Cast to unsigned int safely handling INT_MIN (-2147483648)
        unsigned int val = (n < 0) ? (0u - (unsigned int)n) : (unsigned int)n;
        // Process 2 digits at a time
        while (val >= 100) {
            unsigned int q = val / 100;
            unsigned int rem = val - (q * 100);
            val = q;
            p -= 2;
            memcpy(p, &DIGIT_PAIRS[rem * 2], 2);
        }
        // Remaining 1 or 2 digits (< 100)
        if (val < 10) {
            *(--p) = (char)('0' + val);
        } else {
            p -= 2;
            memcpy(p, &DIGIT_PAIRS[val * 2], 2);
        }
        // Prepend sign
        if (n < 0) {
            *(--p) = '-';
        }
        // Pass exact pointer and calculated string length
        tex_print_str_len(p, (int) ((buf + sizeof(buf)) - p));
    }

# endif

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

    todo: time these two variants

*/

# if 0

    void tex_print_dimension(scaled s, int unit)
    {
        if (s == 0) {
            tex_print_str_len("0.0", 3); /* really .. just 0 is not ok for some applications */
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
                    /*tex Round the last digit, so: |s + 32768 - 50000| it is. */
                    s = s + 0x8000 - 50000;
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

# else

    # ifndef UNITY
        # define UNITY 65536
    # endif

    static void tex_aux_print_scaled(scaled s, int unit, int is_sparse)
    {
        // Fast path 1: 0.0 vs 0
        if (s == 0) {
            if (unit == no_unit) {
                if (is_sparse) { tex_print_char('0'); } else { tex_print_str_len("0.0", 3); }
            } else if (unit == pt_unit) {
                tex_print_str_len(is_sparse ? "0pt" : "0.0pt", is_sparse ? 3 : 5);
            } else {
                tex_print_str_len(is_sparse ? "0mu" : "0.0mu", is_sparse ? 3 : 5);
            }
            return;
        }
        // Fast path 2: sparse 1pt
        if (is_sparse && s == UNITY) {
            if (unit == no_unit) {
                if (is_sparse) { tex_print_char('1'); } else { tex_print_str_len("1.0", 3); }
            } else if (unit == pt_unit) {
                tex_print_str_len(is_sparse ? "1pt" : "1.0pt", is_sparse ? 3 : 5);
            } else {
                tex_print_str_len(is_sparse ? "1mu" : "1.0mu", is_sparse ? 3 : 5);
            }
            return;
        }
        // 1. Handle sign safely
        int is_negative = 0;
        unsigned int u_s;
        if (s < 0) {
            is_negative = 1;
         // u_s = -((unsigned int) s);
            u_s = 0u -((unsigned int) s); // for ms
        } else {
            u_s = (unsigned int) s;
        }
        // Stack buffer for entire dimension output .. plenty
        char buf[64];
        char *p = buf;
        if (is_negative) {
            *p++ = '-';
        }
        // 2. Format integer part into buffer
        unsigned int int_part = u_s / UNITY;
        unsigned int frac_part = u_s % UNITY;
        // Fast inline base-10 formatting for integer part
        if (int_part == 0) {
            *p++ = '0';
        } else {
            char int_buf[16];
            char *ip = &int_buf[sizeof(int_buf) - 1];
            *ip = '\0';
            while (int_part > 0) {
                *(--ip) = (char) ('0' + (int_part % 10));
                int_part /= 10;
            }
            size_t len = strlen(ip);
            memcpy(p, ip, len);
            p += len;
        }
        // 3. Format fractional part using TeX allowable inaccuracy loop
        char frac_buf[20];
        int frac_len = 0;
        scaled delta = 10;
        scaled work_s = (scaled) (10 * frac_part + 5);
        do {
            if (delta > UNITY) {
                // Round the last digit: s + 32768 - 50000 (0x8000 = 32768)
                work_s += 0x8000 - 50000;
            }
            frac_buf[frac_len++] = (char)('0' + (work_s / UNITY));
            work_s = 10 * (work_s % UNITY);
            delta *= 10;
        } while (work_s > delta);
        // 4. Apply sparse mode rules vs standard dimension rules
        if (is_sparse && frac_len == 1 && frac_buf[0] == '0') {
            // Skip writing decimal point for trailing zero in sparse mode (e.g., "5.0" -> "5")
        } else {
            *p++ = '.';
            memcpy(p, frac_buf, frac_len);
            p += frac_len;
        }
        if (unit != no_unit) {
            const char *u = (unit == pt_unit) ? "pt" : "mu";
            memcpy(p, u, 2);
            p += 2;
        }
        tex_print_str_len(buf, (int)(p - buf));
    }

    void tex_print_dimension(scaled s, int unit)
    {
        tex_aux_print_scaled(s, unit, 0);
    }

    void tex_print_sparse_dimension(scaled s, int unit)
    {
        tex_aux_print_scaled(s, unit, 1);
    }

# endif

/*tex
    Till we start using this more extensively this one will not be used often.
*/

static void tex_aux_print_posit(halfword s, int texlike)
{
    if (s == 0) {
        tex_print_char('0');
        return;
    }
    double n = tex_posit_to_double(s);
    if (n == 1.0) {
        tex_print_char('1');
        return;
    }
    if (n == -1.0) {
        tex_print_str_len("-1", 2);
        return;
    }
    if (fmod(n, 1.0) == 0.0 && n >= min_integer && n <= max_integer) {
        tex_print_int((int)n);
        return;
    }
    char buf[128];
    int len = snprintf(buf, sizeof(buf), texlike ? "%.5f" : "%.9f", n);
    if (len > 0 && len < (int) sizeof(buf)) {
        while (len > 0 && buf[len - 1] == '0') {
            len--;
        }
        if (len > 0 && buf[len - 1] == '.') {
            len--;
        }
        tex_print_str_len(buf, len);
    }
}

void tex_print_posit  (halfword s) { tex_aux_print_posit(s, 0); }
void tex_print_posit_5(halfword s) { tex_aux_print_posit(s, 1); }

/*tex

    Hexadecimal printing of nonnegative integers is accomplished by |print_hex|. We have a few
    variants. Because we have bitsets that can give upto |0xFFFFFFFF| we treat the given integer
    as an unsigned.
*/

# if 0

    void tex_print_hex(long long sn)
    {
        if (sn == 0) {
            tex_print_char('0');
        } else {
            unsigned long long n = 0;
            int k = 0;
            unsigned char digits[24];
            if (sn < 0) {
                tex_print_char('-');
                n = (unsigned long long) -sn;
            } else {
                n = (unsigned long long) sn;
            }
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
    }

    static void tex_print_qhex(long long n)
    {
        tex_print_char('"');
        tex_print_hex(n);
    }

    static void tex_print_uhex(long long n)
    {
        tex_print_str_len("U+", 2);
        /* todo: loop */
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

    static void tex_print_xhex(long long n)
    {
        tex_print_char('"');
        /* todo: loop */
        if (n < 0xF) {
            tex_print_char('0');
        }
        if (n < 0xFF) {
            tex_print_char('0');
        }
        if (n < 0xFFF) {
            tex_print_char('0');
        }
        if (n < 0xFFFF) {
            tex_print_char('0');
        }
        if (n < 0xFFFFF) {
            tex_print_char('0');
        }
        if (n < 0xFFFFFF) {
            tex_print_char('0');
        }
        if (n < 0xFFFFFFF) {
            tex_print_char('0');
        }
        tex_print_hex(n);
    }

# else

    static inline void tex_aux_print_hex_engine(long long sn, int min_digits, const char *prefix, const char *suffix)
    {
        char buf[64];
        char *p = &buf[sizeof(buf) - 1];
        *p = '\0';
        // 1. Append suffix if present (e.g. closing quote '"')
        if (suffix) {
            size_t len = strlen(suffix);
            p -= len;
            memcpy(p, suffix, len);
        }
        // 2. Safe unsigned conversion (handles LLONG_MIN correctly)
        unsigned long long val;
        int is_negative = 0;
        if (sn < 0) {
            is_negative = 1;
         // val = -((unsigned long long) sn);
            val = 0ul -((unsigned long long) sn); // for ms
        } else {
            val = (unsigned long long) sn;
        }
        // 3. Extract hex digits backwards
        static const char hex_digits[] = "0123456789ABCDEF";
        int digits = 0;
        do {
            *(--p) = hex_digits[val & 0xF];
            val >>= 4;
            digits++;
        } while (val > 0);
        // 4. Apply minimum zero padding (if requested)
        while (digits < min_digits) {
            *(--p) = '0';
            digits++;
        }
        // 5. Prepend negative sign if needed
        if (is_negative) {
            *(--p) = '-';
        }
        // 6. Prepend prefix if present (e.g. opening quote '"' or "U+")
        if (prefix) {
            size_t len = strlen(prefix);
            p -= len;
            memcpy(p, prefix, len);
        }
        // Single multiplexer dispatch
        tex_print_str_len(p, (int) (&buf[sizeof(buf) - 1] - p));
    }

    void tex_print_hex(long long n)
    {
        tex_aux_print_hex_engine(n, 1, NULL, NULL);
    }

    static void tex_print_qhex(long long n)
    {
        tex_aux_print_hex_engine(n, 1, "\"", "\"");
    }

    static void tex_print_uhex(long long n)
    {
        tex_aux_print_hex_engine(n, 4, "U+", NULL);
    }

    static void tex_print_xhex(long long n)
    {
        tex_aux_print_hex_engine(n, 8, "\"", "\"");
    }

# endif

void tex_print_char_identifier(halfword c)
{
    if (c > 0x10FFFF) {
        return;
    } else if ((c >= 0x00E000 && c <= 0x00F8FF) ||
        (c >= 0x0F0000 && c <= 0x0FFFFF) ||
        (c >= 0x100000 && c <= 0x10FFFF) ||
        (c >= 0x00D800 && c <= 0x00DFFF))
    {
        // Formats as 6 hex digits with "0x" prefix (e.g., "0x00E000")
        tex_aux_print_hex_engine(c, 6, "0x", NULL);
    } else {
        // Formats as 6 hex digits with "U+" prefix (e.g., "U+000041")
        tex_aux_print_hex_engine(c, 6, "U+", NULL);
        tex_print_char(' ');
        tex_print_tex_str(c);
    }
}

/*tex

    Roman numerals are produced by the |print_roman_int| routine. Readers who like puzzles might
    enjoy trying to figure out how this tricky code works; therefore no explanation will be given.
    Notice that 1990 yields |mcmxc|, not |mxm|.

    When staring at this one once again, I wondered what Gemini would come up with so I asked and
    got this:

    \startquotation
    The beauty of \quotation {m2d5c2l5x2v5i} lies in how the string encodes both the divisors and
    the subtractive lookahead offsets:

    Letters: The Roman symbols m, d, c, l, x, v, i.

    Numbers: 2 and 5

    The factor to divide $v$ by to get to the next lower symbol!

    \startlines
       $1000 \div 2 = 500$ (d)
       $ 500 \div 5 = 100$ (c)
       $ 100 \div 2 =  50$ (l)
       $  50 \div 5 =  10$ (x)
       $  10 \div 2 =   5$ (v)
       $   5 \div 5 =   1$ (i)
    \stoplines

    When checking whether to write a subtractive pair (like iv for 4 or ix for 9), the algorithm
    inspects whether $n + u \ge v$, where $u$ is calculated by stepping forward in the mystery
    string to peek at the appropriate power-of-10 unit (c, x, or i).

    It's a masterclass in squeezing complex formatting logic into minimal instruction space!
    \stopquotation

    Indeed. After that I did a bit of research (actually we already have a variant in the regular
    \CONTEXT\ converter but that assumes \UNICODE) and chat a bit and ended up with the next more
    regular \ASCII\ variant (there has also been solutions using _ and ^ but for \TEX\ that sounds
    like a bad idea). Of course that means that we're not compatible but whem macro writers expect
    thousands of repeated \type {m}'s, well they can have it. I've seen some (in modern code)
    examples where that actually happens and it's an oversight, waste of tokens and string space,
    etc. but maybe a price a macro writer wants to pay for this \type {\romannumeral} obsession. I
    wonder if someone ever notices this variant.

*/

static void tex_print_knuth_roman(int n)
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

    A parenthetical wrapper that delegates sub-4000 chunks to Knuth's algorithm: for 4000 and
    above we process in groups of 1000 using nested parentheses. We stay faithful to Knuth and
    use his clever solution. Anyone using romannumerals for more than 4000 pages should rethink
    the design anyway.

*/

void tex_print_roman_int(int n, int numerical)
{
    if (n == 0) {
        /*tex
            The romans had no zero and \TEX\ doesn't output something when we're zero or
            below. Some macro writers abuse that fact.
        */
    } else if (n < 4000 || ! numerical) {
        tex_print_knuth_roman(n);
    } else {
        unsigned int multiplier = 1;
        int depth = 0;
        while (n / multiplier >= 1000) {
            multiplier *= 1000;
            depth++;
        }
        while (multiplier > 0) {
            int chunk = (int)(n / multiplier);
            n %= multiplier;
            if (chunk > 0) {
                /*tex opening parentheses for high-order groups */
                for (int i = 0; i < depth; i++) {
                    tex_print_char('(');
                }
                /*tex chunk (1–999) using Knuth's routine */
                tex_print_knuth_roman(chunk);
                /*tex closing parentheses */
                for (int i = 0; i < depth; i++) {
                    tex_print_char(')');
                }
            }
            multiplier /= 1000;
            depth--;
        }
    }
}

/*tex

    Group codes were introduced in \ETEX\ but have been extended in the meantime in \LUATEX\ and
    later again in \LUAMETATEX. We might have (even) more granularity in the future.

    Todo: combine this with an array of struct(id,name,lua) ... a rainy day + stack of new cd's job.

*/

/*tex
    We have at most 4 pairs, in math choices, but let's be nice and check anyway.
*/

static inline void tex_print_group_count(int n)
{
    if (n > 0) {
        static const char group_pairs[] = "{}{}{}{}";
        while (n >= 4) {
            tex_print_str_len(group_pairs, 8);
            n -= 4;
        }
        if (n > 0) {
            tex_print_str_len(group_pairs, n * 2);
        }
    }
}

static inline void tex_print_group(int e)
{
    int line = tex_saved_line_at_level();
    tex_print_str(lmt_interface.group_code_values[cur_group].name);
    if (cur_group != bottom_level_group) {
        tex_print_str_len(" group", 6);
        if (line) {
            if (e) {
                tex_print_str_len(" entered at line ", 17);
            } else {
                tex_print_str_len(" at line ", 9);
            }
            tex_print_int(line);
        }
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
                    tex_print_tex_str(tex_active_cs_value(t));
                } else {
                    tex_print_tex_str_esc(t);
                    if (! tex_single_letter(t) || (tex_get_cat_code(cat_code_table_par, aux_str2uni(str_getstr(t))) == letter_cmd)) {
                        tex_print_char(' ');
                    }
                }
            }
            break;
        case cs_null_error:
            tex_print_format("%ecsname%eendcsname");
            break;
        case cs_below_base_error:
            tex_print_str(error_string_impossible(11));
            break;
        case cs_undefined_error:
            tex_print_format("%eundefined");
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
        tex_print_format("%ecsname%eendcsname"); /* no space */
    } else {
        strnumber t = cs_text(p);
        if (tex_is_active_cs(t)) {
            tex_print_tex_str(tex_active_cs_value(t));
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
            tex_print_tex_str(tex_active_cs_value(t));
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
    if (order == normal_glue_order) { /* 0 */
        tex_print_dimension(d, unit);
    } else {
        tex_print_dimension(d, no_unit);
        switch (order) {
            case fi_glue_order    : tex_print_str_len("fi",    2); break;
            case fil_glue_order   : tex_print_str_len("fil",   3); break;
            case fill_glue_order  : tex_print_str_len("fill",  4); break;
            case filll_glue_order : tex_print_str_len("filll", 5); break;
            default               : tex_print_str_len("foul",  4); break;
        }
    }
}

void tex_print_glue_set(halfword p)
{
    double g = (double) (box_glue_set(p));
    if ((g != 0.0) && (box_glue_sign(p) != normal_glue_sign)) {
        tex_print_str_len(", glue set ", 11); // This was |glue set|.
        if (box_glue_sign(p) == shrinking_glue_sign) {
            tex_print_str_len("- ", 2);
        }
        if (g > 20000.0 || g < -20000.0) {
            if (g > 0.0) {
                tex_print_char('>');
            } else {
                tex_print_str_len("< -", 3);
            }
            tex_print_glue(20000 * unity, box_glue_order(p), no_unit);
        } else {
            tex_print_glue((scaled) glueround(unity *g), box_glue_order(p), no_unit);
        }
    }
}

/*tex The next subroutine prints a whole glue specification. */

void tex_print_unit(int unit)
{
    if (unit != no_unit) {
        tex_print_str_len(unit == pt_unit ? "pt" : "mu", 2);
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
        /* todo */
        if (glue_stretch(p)) {
            tex_print_str_len(" plus ", 6);
            tex_print_glue(glue_stretch(p), glue_stretch_order(p), unit);
        }
        if (glue_shrink(p)) {
            tex_print_str_len(" minus ", 7);
            tex_print_glue(glue_shrink(p), glue_shrink_order(p), unit);
        }
    }
}

static void tex_print_gluespec(
        scaled total,
        scaled stretch,
        scaled fistretch,
        scaled filstretch,
        scaled fillstretch,
        scaled filllstretch,
        scaled shrink,
        int    unit
)
{
    tex_print_dimension(total, unit);
    if (stretch) {
        tex_print_str_len(" plus ", 6);
        tex_print_dimension(stretch, unit);
    } else if (fistretch) {
        tex_print_str_len(" plus ", 6);
        tex_print_dimension(fistretch, no_unit);
        tex_print_str_len(" fi", 3);
    } else if (filstretch) {
        tex_print_str_len(" plus ", 6);
        tex_print_dimension(filstretch, no_unit);
        tex_print_str_len(" fil", 4);
    } else if (fillstretch) {
        tex_print_str_len(" plus ", 6);
        tex_print_dimension(fillstretch, no_unit);
        tex_print_str_len(" fill", 5);
    } else if (filllstretch) {
        tex_print_str_len(" plus ", 6);
        tex_print_dimension(filllstretch, no_unit);
        tex_print_str_len(" filll", 6);
    }
    if (shrink) {
        tex_print_str_len(" minus ", 7);
        tex_print_dimension(shrink, unit);
    }
}

void tex_print_fontspec(int p)
{
    tex_print_int(font_spec_identifier(p));
    if (font_spec_scale(p) != unused_scale_value) {
        tex_print_format(" scale %i", font_spec_scale(p));
    }
    if (font_spec_x_scale(p) != unused_scale_value) {
        tex_print_format(" xscale %i", font_spec_x_scale(p));
    }
    if (font_spec_y_scale(p) != unused_scale_value) {
        tex_print_format(" yscale %i", font_spec_y_scale(p));
    }
    if (font_spec_slant(p)) {
        tex_print_format(" slant %i", font_spec_slant(p));
    }
    if (font_spec_weight(p)) {
        tex_print_format(" weight %i", font_spec_weight(p));
    }
}

/*tex Math characters: */

void tex_print_mathspec(int p)
{
    if (p) {
        mathcodeval m = tex_get_math_spec(p);
        tex_show_mathcode_value(m, node_subtype(p));
    } else {
        tex_print_str_len("[invalid mathspec]", 18);
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

void tex_print_font_identifier(halfword f)
{
    /*tex |< >| is less likely to clash with text parenthesis */
    if (f < 0) {
        f = cur_font_par; /* bonus */
    }
    if (tex_is_valid_font(f)) {
        tex_print_format("<%i: %s @ %p>", f, font_name(f), font_size(f));
    } else {
        tex_print_str_len("<*>", 3);
    }
}

void tex_print_font_specifier(halfword e)
{
    if (e && tex_is_valid_font(font_spec_identifier(e))) {
        tex_print_format("<%i: %i %i %i %i %i>", font_spec_identifier(e), font_spec_scale(e), font_spec_x_scale(e), font_spec_y_scale(e), font_spec_slant(e), font_spec_weight(e));
    } else {
        tex_print_str_len("<*>", 3);
    }
}

void tex_print_font(halfword f)
{
    if (f < 0) {
        f = cur_font_par; /* bonus */
    }
    if (! f) {
        tex_print_str_len("nullfont", 8);
    } else if (tex_is_valid_font(f)) {
        tex_print_str(font_name(f));
     /* if (font_size(f) != font_design_size(f)) { */
            /*tex
                Nowadays this check for design size is rather meaningless so we could as well
                always enter this branch. We can even make this while blob a callback.
            */
            tex_print_format(" at %p", font_size(f));
     /* } */
    } else {
        tex_print_str_len("nofont", 6);
    }
}

/*tex This prints highlights of list |p|. */

void tex_short_display(halfword p)
{
 // tex_print_levels();
    if (p) {
        tex_print_short_node_contents(p);
    } else {
        tex_print_str_len("[empty list]", 12);
    }
}

/*tex This prints token list data in braces. */

void tex_print_token_list(const char *s, halfword p)
{
 /* tex_print_format("%l%.%s {",nesting,s) */
    tex_print_levels();
    tex_print_str_len("..", 2);
    if (s) {
        tex_print_str(s);
        tex_print_char(' ');
    }
    tex_print_char('{');
    if ((p >= 0) && (p <= (int) lmt_token_memory_state.tokens_data.top)) {
        tex_show_token_list(p, 0, 0);
    } else {
        tex_print_str(error_string_clobbered(21));
    }
    tex_print_char('}');
}

/*tex This prints dimensions of a rule node. */

static inline void tex_print_rule_dimension(scaled d)
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
    only the top level information will be given and no sub-lists will be traversed. Another global
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
 // tex_print_levels();
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
            if (! odd_int(lmt_print_state.terminal_offset)) {
                tex_print_char(' ');
            }
            break;
        case logfile_selector_code:
        case terminal_and_logfile_selector_code:
            if (! odd_int(lmt_print_state.logfile_offset)) {
                tex_print_char(' ');
            }
            break;
        case luabuffer_selector_code:
            break;
    }
}

static void tex_print_nesting(int n)
{
    static const char periods[32+1] = "................................";
    while (n > 0) {
        int chunk = (n > 32) ? 32 : n;
        tex_print_str_len(periods, chunk);
        n -= chunk;
    }
}

void tex_print_levels(void)
{
    int l0 = tracing_levels_par;
    tex_print_nlp();
    if (l0 > 0) {
        int l1 = (l0 & tracing_levels_group   ) == tracing_levels_group;
        int l2 = (l0 & tracing_levels_input   ) == tracing_levels_input;
        int l4 = (l0 & tracing_levels_catcodes) == tracing_levels_catcodes;
        if (l1 && l2) {
            if (l4) {
                tex_print_format("%i:%i:%i ", cur_level, lmt_input_state.input_stack_data.ptr, cat_code_table_par);
                return;
            } else {
                /*tex This is the default in context: */
                tex_print_format("%i:%i: ", cur_level, lmt_input_state.input_stack_data.ptr);
                return;
            }
        }
        if (l1) {
            tex_print_format("%i:", cur_level);
        }
        if (l2) {
            tex_print_format("%i:", lmt_input_state.input_stack_data.ptr);
        }
        if (l4) {
            tex_print_format("%i:", cat_code_table_par);
        }
        if (l1 || l2 || l4) {
            tex_print_char(' ');
        }
        tex_print_padding();
    }
}

/*tex

    We have these formatting keys:

    \starttyping
    %c   int            char
    %d   int            detail (node)
    %e                  backslash (tex escape)
    %h  *char           error help
    %i   int            integer
    %l                  levels
    %n   int            extended subtype
    %m   int            cs checked (macro)
    %p   int            dimension with pt unit
    %q  *char          'string'
    %s  *char           string
    %u   int            utf character
    %x   int            quoted hex

    %B   int            badness
    %C   int int        symbolic representation of cmd chr
    %D   int int        dimension plus unit
    %E  *char           \cs
    %F   int            font identifier
    %G   int            group
    %L   int            (if) linenumber
    %M   int            mode
    %N   int            node name
    %O   int int int    glue component
    %P   7 int          glue spec
    %Q   int            glue node
    %R   int            rule dimensions
    %S   int            tex cs string
    %T   int            tex string
    %U   int            unicode
    %X   int            unicode

    %#   int            group count : n*{}

    %2   int            direction

    %%                  percent
    \stoptyping

    Using a variant that collects stripes between formatters is faster: so that is what we do now,
    and  we gained over 30\percent which is nice on extreme tracing.

*/

inline const char *tex_print_format_args(const char *format, va_list args)
{
    const char *start = format;
    while (1) {
        int chr = *format++;
        switch (chr) {
            case '\0':
                if (format - 1 > start) {
                    tex_print_str_len(start, (int) (format - 1 - start));
                }
                return NULL;
            case '%':
                /*tex We need to flush preceding literal characters. */
                if (format - 1 > start) {
                    tex_print_str_len(start, (int) (format - 1 - start));
                }
                chr = *format++;
                switch (chr) {
                    case '\0':
                        return NULL;
                    case 'c':
                        {
                            int chr = va_arg(args, int);
                            tex_aux_uprint(chr);
                            break;
                        }
                    case 'd': /* detail */
                        {
                            tex_print_str(tex_aux_subtype_str(va_arg(args, int)));
                            break;
                        }
                    case 'e':
                        {
                            tex_print_str_esc("");
                            break;
                        }
                    case 'h':
                        {
                            /*tex Optional help info gets returned and comes last. */
                            return va_arg(args, const char *);
                        }
                    case 'i':
                        {
                            tex_print_int(va_arg(args, int));
                            break;
                        }
                    case 'l':
                        {
                            tex_print_levels();
                            break;
                        }
                    case 'n':
                        {
                            quarterword subtype = (quarterword) va_arg(args, int);
                            tex_print_extended_subtype(null, subtype);
                            break;
                        }
                    case 'm':
                        {
                            tex_print_cs_checked(va_arg(args, int));
                            break;
                        }
                    case 'p':
                        {
                            tex_print_dimension((scaled) va_arg(args, int), pt_unit);
                            break;
                        }
                    case 'q':
                        {
                            const char *str = va_arg(args, const char *);
                            tex_print_char('\'');
                            if (str) {
                                tex_print_str_len(str, (int) strlen(str));
                            }
                            tex_print_char('\'');
                            break;
                        }
                    case 's':
                        {
                            const char *str = va_arg(args, const char *);
                            if (str) {
                                tex_print_str_len(str, (int) strlen(str));
                            }
                            break;
                        }
                    case 'u':
                        tex_aux_uprint(va_arg(args, int));
                        break;
                    case 'x':
                        {
                            int value = va_arg(args, int);
                            tex_print_qhex(value);
                            break;
                        }
                    case 'B': /* badness */
                        {
                            scaled badness = va_arg(args, int);
                            if (badness == awful_bad) {
                                tex_print_char('*');
                            } else {
                                tex_print_int(badness);
                            }
                            break;
                        }
                    case 'C':
                        {
                            int cmd = va_arg(args, int);
                            int val = va_arg(args, int);
                            tex_print_cmd_chr((singleword) cmd, val);
                            break;
                        }
                    case 'D': /* dimension */
                        {
                            scaled amount = va_arg(args, int);
                            int    unit   = va_arg(args, int);
                            tex_print_dimension(amount, unit);
                            break;
                        }
                    case 'E':
                        {
                            tex_print_str_esc(va_arg(args, const char *));
                            break;
                        }
                    case 'F':
                        {
                            halfword id = va_arg(args, int);
                            tex_print_font_identifier(id);
                            break;
                        }
                    case 'G':
                        {
                            tex_print_group(va_arg(args, int));
                            break;
                        }
                    case 'L':
                        {
                            halfword line = va_arg(args, int);
                            if (line) {
                                tex_print_str_len(" entered on line ", 17);
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
                    case 'N':
                        {
                            halfword node = va_arg(args, int);
                            if (node) {
                                tex_print_str(lmt_interface.node_data[node_type(node)].name);
                            }
                            break;
                        }
                    case 'O':
                        {
                            scaled   s = va_arg(args, int);
                            halfword o = va_arg(args, int);
                            int      u = va_arg(args, int);
                            tex_print_glue(s, o, u);
                            break;
                        }
                    case 'P':
                        {
                            scaled total        = va_arg(args, int);
                            scaled stretch      = va_arg(args, int);
                            scaled fistretch    = va_arg(args, int);
                            scaled filstretch   = va_arg(args, int);
                            scaled fillstretch  = va_arg(args, int);
                            scaled filllstretch = va_arg(args, int);
                            scaled shrink       = va_arg(args, int);
                            tex_print_gluespec(total, stretch, fistretch, filstretch,
                                fillstretch, filllstretch, shrink, pt_unit);
                            break;
                        }
                    case 'Q':
                        {
                            scaled glue = va_arg(args, int);
                            int    unit = va_arg(args, int);
                            tex_print_spec(glue, unit);
                            break;
                        }
                    case 'R':
                        {
                            halfword rule = va_arg(args, int);
                            tex_print_rule_dimension(rule);
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
                            halfword chr = va_arg(args, int);
                            tex_print_uhex(chr);
                            break;
                        }
                    case 'X':
                        {
                            halfword chr = va_arg(args, int);
                            tex_print_xhex(chr);
                            break;
                        }
                    case '2':
                        {
                            halfword direction = va_arg(args, int);
                            switch (direction) {
                                case direction_l2r : tex_print_str_len("l2r",   3); break;
                                case direction_r2l : tex_print_str_len("r2l",   3); break;
                                default            : tex_print_str_len("unset", 5); break;
                            }
                            break;
                        }
                    case '#':
                        {
                            halfword groups = va_arg(args, int);
                            tex_print_group_count(groups);
                            break;
                        }
                    case '%':
                        {
                            tex_print_char('%');
                            break;
                        }
                    case '.':
                        {
                            int n = va_arg(args, int);
                            tex_print_nesting(n);
                            break;
                        }
                    default:
                        /* ignore bad one */
                        break;
                }
                /*tex Reset start after processing argument specifier. */
                start = format;
                break;
            case '\n':
            case '\r':
                /*tex Flush the literal string up to newline before dealing with the newline. */
                if (format - 1 > start) {
                    tex_print_str_len(start, (int) (format - 1 - start));
                }
                tex_print_nlp();
                start = format;
                break;
            default:
                /*tex We just advance. */
                break;
        }
    }
}

void tex_print_format(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    tex_print_format_args(format, args);
    va_end(args);
}

void tex_print_message(const char *s)
{
    tex_print_format("\n(%s)\n", s);
}
