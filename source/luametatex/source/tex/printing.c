/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

# define wlog(A)  fputc(A,log_file)
# define wterm(A) fputc(A,term_out)

print_state_info print_state = { NULL, NULL, 0, { 0 }, 0, 0, 0, 0, 0, "", 0, 0, 0, 0, 0, 0, 0 };

/*tex

    Messages that are sent to a user's terminal and to the transcript-log file
    are produced by several |print| procedures. These procedures will direct
    their output to a variety of places, based on the setting of the global
    variable |selector|, which has the following possible values:

    \startitemize

    \startitem
        |term_and_log|, the normal setting, prints on the terminal and on the
        transcript file.
    \stopitem

    \startitem
        |log_only|, prints only on the transcript file.
    \stopitem

    \startitem
        |term_only|, prints only on the terminal.
    \stopitem

    \startitem
        |no_print|, doesn't print at all. This is used only in rare cases before
        the transcript file is open.
    \stopitem

    \startitem
        |pseudo|, puts output into a cyclic buffer that is used by the
        |show_context| routine; when we get to that routine we shall discuss the
        reasoning behind this curious mode.
    \stopitem

    \startitem
        |new_string|, appends the output to the current string in the string pool.
    \stopitem

    \startitem
        0 to 15, prints on one of the sixteen files for |\write| output.
    \stopitem

    \stopitemize

    The symbolic names |term_and_log|, etc., have been assigned numeric codes
    that satisfy the convenient relations |no_print + 1 = term_only|, |no_print +
    2 = log_only|, |term_only + 2 = log_only + 1 = term_and_log|.

    Three additional global variables, |tally| and |term_offset| and
    |file_offset|, record the number of characters that have been printed since
    they were most recently cleared to zero. We use |tally| to record the length
    of (possibly very long) stretches of printing; |term_offset| and
    |file_offset|, on the other hand, keep track of how many characters have
    appeared so far on the current line that has been output to the terminal or
    to the transcript file, respectively.

    The state structure collects: |new_string_line| and |escape_controls|, the
    transcript handle of a \TEX\ session: |log_file|, the target of a message:
    |selector|, the digits in a number being output |dig[23]|, the number of
    characters recently printed |tally|, the number of characters on the current
    terminal line |term_offset|, the number of characters on the current file
    line |file_offset|, the circular buffer for pseudoprinting |trick_buf|, the
    threshold for pseudoprinting (explained later) |trick_count|, another
    variable for pseudoprinting |first_count|, a blocker for minor adjustments to
    |show_token_list| namely |inhibit_par_tokens|.

To end a line of text output, we call |print_ln|:

*/

void print_ln(void)
{
    switch (selector) {
        case no_print:
            break;
        case term_only:
            wterm_cr();
            term_offset = 0;
            break;
        case log_only:
            wlog_cr();
            file_offset = 0;
            break;
        case term_and_log:
            wterm_cr();
            wlog_cr();
            term_offset = 0;
            file_offset = 0;
            break;
        case pseudo:
            break;
        case new_string:
            if (new_string_line > 0)
                print_char(new_string_line);
            break;
        default:
            break;
    }
    /*tex |tally| is not affected */
}

/*tex

    The |print_char| procedure sends one byte to the desired destination. All
    printing comes through |print_ln| or |print_char|, except for the case of
    |tprint| (see below).

    The checking of the line length is an inheritance from previous engines and
    we dropped it here. It doesn't make much sense nowadays. The same is true for
    escaping.

*/

void print_char(int s)
{
    if (s < 0 || s > 255) {
        /*tex So how about utf here ...? */
        formatted_warning("print","weird character %i",s);
        return;
    }
    if (s == new_line_char_par) {
        if (selector < pseudo) {
            print_ln();
            return;
        }
    }
    switch (selector) {
        case no_print:
            break;
        case term_only:
            wterm(s);
            incr(term_offset);
            break;
        case log_only:
            wlog(s);
            incr(file_offset);
            break;
        case term_and_log:
            wterm(s);
            wlog(s);
            incr(term_offset);
            incr(file_offset);
            break;
        case pseudo:
            if (tally < trick_count)
                trick_buf[tally % main_state.error_line] = (unsigned char) s;
            break;
        case new_string:
            append_char(s);
            break;
        default:
            break;
    }
    incr(tally);
}

/*tex

    An entire string is output by calling |print|. Note that if we are outputting
    the single standard \ASCII\ character |c|, we could call |print("c")|, since
    |"c"=99| is the number of a single-character string, as explained above. But
    |print_char("c")| is quicker, so \TEX\ goes directly to the |print_char|
    routine when it knows that this is safe. (The present implementation assumes
    that it is always safe to print a visible \ASCII\ character.)

    The first 256 entries above the 17th unicode plane are used for a special
    trick: when \TEX\ has to print items in that range, it will instead print the
    character that results from substracting 0x110000 from that value. This
    allows byte-oriented output to things like |\specials|.

*/

void print(int s)
{
    if (s >= string_pool_state.str_ptr) {
        normal_warning("print","bad string pointer");
        return;
    } else if (s < STRING_OFFSET) {
        if (s < 0) {
            normal_warning("print","bad string offset");
        } else {
            /*tex We're not sure about this so it's disabled for now! */
            /*
            if ((selector > pseudo)) {
                / *tex internal strings are not expanded * /
                print_char(s);
                return;
            }
            */
            if (s == new_line_char_par) {
                if (selector < pseudo) {
                    print_ln();
                    return;
                }
            }
            if (s <= 0x7F) {
                print_char(s);
            } else if (s <= 0x7FF) {
                print_char(0xC0 + (s / 0x40));
                print_char(0x80 + (s % 0x40));
            } else if (s <= 0xFFFF) {
                print_char(0xE0 + (s / 0x1000));
                print_char(0x80 + ((s % 0x1000) / 0x40));
                print_char(0x80 + ((s % 0x1000) % 0x40));
            } else if (s >= 0x110000) {
                int c = s - 0x110000;
                if (c >= 256) {
                    formatted_warning("print", "bad raw byte to print (c=%d), skipped",c);
                } else {
                    print_char(c);
                }
            } else {
                print_char(0xF0 + (s / 0x40000));
                print_char(0x80 + ((s % 0x40000) / 0x1000));
                print_char(0x80 + (((s % 0x40000) % 0x1000) / 0x40));
                print_char(0x80 + (((s % 0x40000) % 0x1000) % 0x40));
            }
        }
        return;
    }
    if (selector == new_string) {
        append_string(str_string(s), (unsigned) str_length(s));
        return;
    }
    lprint(&str_lstring(s));
}

void lprint(lstring *ss) {
    /*tex current character code position */
    unsigned char *j = ss->s;
    unsigned char *l = j + ss->l;
    while (j < l) {
        /*tex We don't bother checking the last two bytes explicitly */
        /* 0x110000 in utf=8: 0xF4 0x90 0x80 0x80 */
        if ((j < l - 4) && (*j == 0xF4) && (*(j + 1) == 0x90)) {
            int c = (*(j + 2) - 128) * 64 + (*(j + 3) - 128);
            print_char(c);
            j = j + 4;
        } else {
            print_char(*j);
            incr(j);
        }
    }
}

/*tex

    The procedure |print_nl| is like |print|, but it makes sure that the string
    appears at the beginning of a new line.


    Move to the beginning of the next line.

*/

void print_nlp(void)
{
    if (new_string_line > 0) {
        print_char(new_string_line);
    } else if (((term_offset > 0) && (odd(selector))) ||
               ((file_offset > 0) && (selector >= log_only))) {
        print_ln();
    }
}

/*tex Prints string |s| at beginning of the next line. */

void print_nl(str_number s)
{
    print_nlp();
    print(s);
}

/*tex

    The |char *| versions of the same procedures. |tprint| is different because
    it uses buffering, which works well because most of the output actually comes
    through |tprint|.

*/

/*
# define replacenewlines(sss,newlinechar) do { \
    char *newstr = strdup(sss); \
    char *s; \
    for (s=newstr;*s;s++) { \
        if (*s == newlinechar) { \
            *s = '\n'; \
        } \
    } \
    sss = newstr; \
    free(newstr); \
} while (0)
*/

void tprint(const char *sss)
{
    int dolog = 0;
    int doterm = 0;
    switch (selector) {
        case no_print:
            return;
            break;
        case term_only:
            doterm = 1;
            break;
        case log_only:
            dolog = 1;
            break;
        case term_and_log:
            dolog = 1;
            doterm = 1;
            break;
        case pseudo:
            while (*sss) {
                if (tally < trick_count) {
                    trick_buf[tally % main_state.error_line] = (unsigned char) *sss++;
                    tally++;
                } else {
                    return;
                }
            }
            return;
            break;
        case new_string:
            append_string((const unsigned char *)sss, (unsigned) strlen(sss));
            return;
            break;
        default:
            break;
    }
    if (! fileio_state.log_opened) {
        dolog = 0;
    }
    if (dolog || doterm) {
        /*tex This |newlinechar| hackery is more or less obsolete in luametatex. */
        /*
        int newlinechar = engine_state.lua_only  ? 10 : new_line_char_par;
        int newline = (newlinechar != '\n') && (strchr(sss,newlinechar) != NULL);
        if (newline) {
            replacenewlines(sss,newlinechar);
        }
        */
        int len = strlen(sss);
        if (len > 0) {
            int newline = sss[len-1] == '\n';
            if (dolog) {
                fputs(sss, log_file);
                if (newline) {
                    file_offset = 0;
                } else {
                    file_offset += len;
                }
            }
            if (doterm) {
                fputs(sss, term_out);
                if (newline) {
                    term_offset = 0;
                } else {
                    term_offset += len;
                }
            }
        }
    }
}

void tprint_nl(const char *s)
{
    print_nlp();
    tprint(s);
}

/*tex

    Here is the very first thing that \TEX\ prints: a headline that identifies
    the version number and format package. The |term_offset| variable is
    temporarily incorrect, but the discrepancy is not serious since we assume
    that the banner and format identifier together will occupy at most
    |max_print_line| character positions. Well, we dropped that check in this
    variant.

*/

void print_banner(void)
{
    int callback_id = callback_defined(start_run_callback);
    if (callback_id == 0) {
        fprintf(term_out, "%s ", engine_state.luatex_banner);
        if (dump_state.format_ident > 0) {
            print(dump_state.format_ident);
        }
        print_ln();
    } else if (callback_id > 0) {
        run_callback(callback_id, "->");
    }
}

void log_banner(void)
{
    const char *months[] = { "   ",
        "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
    };
    unsigned month = (unsigned) month_par;
    if (month > 12)
        month = 0;
    fprintf(log_file, "%s", engine_state.luatex_banner);
    print_char(' ');
    print(dump_state.format_ident);
    print_char(' ');
    print_char(' ');
    print_int(day_par);
    print_char(' ');
    fprintf(log_file, "%s", months[month]);
    print_char(' ');
    print_int(year_par);
    print_char(' ');
    print_two(time_par / 60);
    print_char(':');
    print_two(time_par % 60);
}

void print_version_banner(void)
{
    fprintf(term_out, "%s", engine_state.luatex_banner);
}

/*tex

    The procedure |print_esc| prints a string that is preceded by the user's
    escape character (which is usually a backslash).

*/

void print_esc(str_number s)
{
    /*tex Set variable |c| to the current escape character: */
    int c = escape_char_par;
    if (c >= 0 && c < 0x110000)
        print(c);
    print(s);
}

/*tex This prints escape character, then |s|. */

void tprint_esc(const char *s)
{
    /*tex Set variable |c| to the current escape character: */
    int c = escape_char_par;
    if (c >= 0 && c < 0x110000)
        print(c);
    tprint(s);
}

/*tex An array of digits in the range |0..15| is printed by |print_the_digs|. */

void print_the_digs(unsigned char k)
{
    /*tex prints |dig[k-1]|$\,\ldots\,$|dig[0]| */
    while (k-- > 0) {
        if (dig[k] < 10)
            print_char('0' + dig[k]);
        else
            print_char('A' - 10 + dig[k]);
    }
}

/*tex

    The following procedure, which prints out the decimal representation of a
    given integer |n|, has been written carefully so that it works properly if
    |n=0| or if |(-n)| would cause overflow. It does not apply |mod| or |div| to
    negative arguments, since such operations are not implemented consistently by
    all \PASCAL\ compilers.

*/

void print_int(int n)
{
    /*tex index to current digit; we assume that $|n|<10^{23}$ */
    int k = 0;
    if (n < 0) {
        print_char('-');
        if (n > -100000000) {
            n = -n;
        } else {
            /*tex |m| is used to negate |n| in possibly dangerous cases */
            int m = -1 - n;
            n = m / 10;
            m = (m % 10) + 1;
            k = 1;
            if (m < 10)
                dig[0] = (int) m;
            else {
                dig[0] = 0;
                incr(n);
            }
        }
    }
    do {
        dig[k] = (int) (n % 10);
        n = n / 10;
        incr(k);
    } while (n != 0);
    print_the_digs((unsigned char) k);
}

/*tex

    Here is a trivial procedure to print two digits; it is usually called with a
    parameter in the range |0 <= n <= 99|.

*/

void print_two(int n)
{
    n = abs(n) % 100;
    print_char('0' + (n / 10));
    print_char('0' + (n % 10));
}

/*tex

    Hexadecimal printing of nonnegative integers is accomplished by |print_hex|.

*/

void print_qhex(int n)
{
    /*tex index to current digit; we assume that $0\L n<16^{22}$ */
    int k = 0 ;
    print_char('"');
    do {
        dig[k] = n % 16;
        n = n / 16;
        incr(k);
    } while (n != 0);
    print_the_digs((unsigned char) k);
}

/*tex

    Roman numerals are produced by the |print_roman_int| routine. Readers who
    like puzzles might enjoy trying to figure out how this tricky code works;
    therefore no explanation will be given. Notice that 1990 yields |mcmxc|, not
    |mxm|.

*/

void print_roman_int(int n)
{
    char mystery[] = "m2d5c2l5x2v5i";
    char *j = (char *) mystery;
    int v = 1000;
    while (1) {
        while (n >= v) {
            print_char(*j);
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
                print_char(*k);
                n = n + u;
            } else {
                j = j + 2;
                v = v / (*(j - 1) - '0');
            }
        }
    }
}

/*tex

    The |print| subroutine will not print a string that is still being created.
    The following procedure will.

*/

void print_current_string(void)
{
    /*tex points to current character code */
    unsigned j = 0;
    while (j < cur_length)
        print_char(cur_string[j++]);
}

/*tex

    The procedure |print_cs| prints the name of a control sequence, given a
    pointer to its address in |eqtb|. A space is printed after the name unless it
    is a single nonletter or an active character. This procedure might be invoked
    with invalid data, so it is \quote {extra robust}. The individual characters
    must be printed one at a time using |print|, since they may be unprintable.

*/

void print_cs(int p)
{
    str_number t = cs_text(p);
    if (p < hash_base) {
        if (p == null_cs) {
            tprint_esc("csname");
            tprint_esc("endcsname");
            print_char(' ');
        } else {
            tprint_esc("IMPOSSIBLE.");
        }
    } else if ((p >= undefined_control_sequence) && ((p <= eqtb_size) || p > eqtb_size + hash_state.hash_extra)) {
        tprint_esc("IMPOSSIBLE.");
    } else if (t >= string_pool_state.str_ptr) {
        tprint_esc("NONEXISTENT.");
    } else if (is_active_cs(t)) {
        print(active_cs_value(t));
    } else {
        print_esc(t);
        if (single_letter(t)) {
            if (get_cat_code(cat_code_table_par, str2uni(str_string(t))) == letter_cmd)
                print_char(' ');
        } else {
            print_char(' ');
        }
    }
}

/*tex

    Here is a similar procedure; it avoids the error checks, and it never prints
    a space after the control sequence.

*/

void sprint_cs(halfword p)
{
    if (p == null_cs) {
        tprint_esc("csname");
        tprint_esc("endcsname");
    } else {
        str_number t = cs_text(p);
        if (is_active_cs(t))
            print(active_cs_value(t));
        else
            print_esc(t);
    }
}

void sprint_cs_name(halfword p)
{
    if (p != null_cs) {
        str_number t = cs_text(p);
        if (is_active_cs(t))
            print(active_cs_value(t));
        else
            print(t);
    }
}

/*tex This procedure is never called when |interaction < scroll_mode|. */

void prompt_input(const char *s)
{
    int callback_id = callback_defined(terminal_input_callback);
    if (callback_id > 0) {
        (void) run_callback(callback_id, "S->l",s,(iobuffer + iofirst));
    } else {
        wake_up_terminal();
        tprint(s);
        term_input();
    }
}

/*tex

    Then there is a subroutine that prints glue stretch and shrink, possibly
    followed by the name of finite units:

*/

void print_glue(scaled d, int order, const char *s)
{
    print_scaled(d);
    if ((order < normal) || (order > filll)) {
        tprint("foul");
    } else if (order > normal) {
        tprint("fi");
        while (order > sfi) {
            print_char('l');
            decr(order);
        }
    } else if (s != NULL) {
        tprint(s);
    }
}

/*tex The next subroutine prints a whole glue specification. */

void print_spec(int p, const char *s)
{
    if (p < 0) {
        print_char('*');
    } else {
        print_scaled(width(p));
        if (s != NULL)
            tprint(s);
        if (stretch(p) != 0) {
            tprint(" plus ");
            print_glue(stretch(p), stretch_order(p), s);
        }
        if (shrink(p) != 0) {
            tprint(" minus ");
            print_glue(shrink(p), shrink_order(p), s);
        }
    }
}

/*tex

    We can reinforce our knowledge of the data structures just introduced by
    considering two procedures that display a list in symbolic form. The first of
    these, called |short_display|, is used in \quotation {overfull box} messages
    to give the top-level description of a list. The other one, called
    |show_node_list|, prints a detailed description of exactly what is in the
    data structure.

    The philosophy of |short_display| is to ignore the fine points about exactly
    what is inside boxes, except that ligatures and discretionary breaks are
    expanded. As a result, |short_display| is a recursive procedure, but the
    recursion is never more than one level deep.

    A global variable |font_in_short_display| keeps track of the font code that
    is assumed to be present when |short_display| begins; deviations from this
    font will be printed.

    Boxes, rules, inserts, whatsits, marks, and things in general that are sort
    of \quote {complicated} are indicated only by printing |[]|.

    We print a bit more than original \TEX. A value of 0 or 1 or any large value
    will behave the same as before. The reason for this extension is that a
    |name| not always makes sense.

    \starttyping
    0   \foo xyz
    1   \foo (bar)
    2   <bar> xyz
    3   <bar @ ..> xyz
    4   <id>
    5   <id: bar>
    6   <id: bar @ ..> xyz
    \stoptyping

*/

void print_font_identifier(internal_font_number f)
{
    str_number fonttext = font_id_text(f);
    if (tracing_fonts_par >= 2 && tracing_fonts_par <= 6) {
        /*tex |< >| is less likely to clash with text parenthesis */
        tprint("<");
        if (tracing_fonts_par >= 2 && tracing_fonts_par <= 3) {
            print_font_name(f);
            if (tracing_fonts_par >= 3 || font_size(f) != font_dsize(f)) {
                tprint(" @ ");
                print_scaled(font_size(f));
                tprint("pt");
            }
        } else if (tracing_fonts_par >= 4 && tracing_fonts_par <= 6) {
            print_int(f);
            if (tracing_fonts_par >= 5) {
                tprint(": ");
                print_font_name(f);
                if (tracing_fonts_par >= 6 || font_size(f) != font_dsize(f)) {
                    tprint(" @ ");
                    print_scaled(font_size(f));
                    tprint("pt");
                }
            }
        }
        print_char('>');
    } else {
        /*tex old method, inherited from pdftex  */
        if (fonttext > 0) {
            print_esc(fonttext);
        } else {
            tprint_esc("FONT");
            print_int(f);
        }
        if (tracing_fonts_par > 0) {
            tprint(" (");
            print_font_name(f);
            if (font_size(f) != font_dsize(f)) {
                tprint("@");
                print_scaled(font_size(f));
                tprint("pt");
            }
            print_char(')');
        }
    }
}

/*tex This prints highlights of list |p|. */

void short_display(int p)
{
    while (p != null) {
        if (is_char_node(p)) {
            if (lig_ptr(p) != null) {
                short_display(lig_ptr(p));
            } else {
                if (font(p) != font_in_short_display) {
                    if (!is_valid_font(font(p)))
                        print_char('*');
                    else
                        print_font_identifier(font(p));
                    print_char(' ');
                    font_in_short_display = font(p);
                }
                print(character(p));
            }
        } else {
            /*tex Print a short indication of the contents of node |p| */
            print_short_node_contents(p);
        }
        p = vlink(p);
    }
}

/*tex

    The |show_node_list| routine requires some auxiliary subroutines: one to
    print a font-and-character combination, one to print a token list without its
    reference count, and one to print a rule dimension.

    This prints |char_node| data.

*/

void print_font_and_char(int p)
{
    if (!is_valid_font(font(p)))
        print_char('*');
    else
        print_font_identifier(font(p));
    print_char(' ');
    print(character(p));
}

/*tex This prints token list data in braces. */

void print_mark(int p)
{
    print_char('{');
    if ((p < (int) fixed_memory_state.fix_mem_min) || (p > (int) fixed_memory_state.fix_mem_end)) {
        tprint_esc("CLOBBERED.");
    } else {
        show_token_list(token_link(p), null, 10000); /* so no longer max_print_line - 10 */
    }
    print_char('}');
}

/*tex This prints dimensions of a rule node. */

void print_rule_dimen(scaled d)
{
    if (is_running(d))
        print_char('*');
    else
        print_scaled(d);
}

/*tex

    Since boxes can be inside of boxes, |show_node_list| is inherently recursive,
    up to a given maximum number of levels. The history of nesting is indicated
    by the current string, which will be printed at the beginning of each line;
    the length of this string, namely |cur_length|, is the depth of nesting.

    A global variable called |depth_threshold| is used to record the maximum
    depth of nesting for which |show_node_list| will show information. If we have
    |depth_threshold = 0|, for example, only the top level information will be
    given and no sublists will be traversed. Another global variable, called
    |breadth_max|, tells the maximum number of items to show at each level;
    |breadth_max| had better be positive, or you won't see anything.

    The maximum nesting depth in box displays is kept in |depth_threshold| and
    the maximum number of items shown at the same list level in |breadth_max|.

    The recursive machinery is started by calling |show_box|. Assign the values
    |depth_threshold := show_box_depth| and |breadth_max := show_box_breadth|

*/

void show_box(halfword p)
{
    depth_threshold = show_box_depth_par;
    breadth_max = show_box_breadth_par;
    if (breadth_max <= 0)
        breadth_max = 5;
    /*tex the show starts at |p| */
    show_node_list(p);
    print_ln();
}

/*tex Helper for debugging purposes. It prints highlights of list |p|. */

void short_display_n(int p, int m)
{
    if (p) {
        int i = 0;
        font_in_short_display = null_font;
        while (p) {
            if (is_char_node(p)) {
                if (p <= max_halfword) {
                    if (font(p) != font_in_short_display) {
                        if (!is_valid_font(font(p)))
                            print_char('*');
                        else
                            print_font_identifier(font(p));
                        print_char(' ');
                        font_in_short_display = font(p);
                    }
                    print(character(p));
                }
            } else {
                if ( (type(p) == glue_node) ||
                     (type(p) == disc_node) ||
                     (type(p) == penalty_node) ||
                    ((type(p) == kern_node) && (subtype(p) == explicit_kern ||
                                                subtype(p) == italic_kern   ))) {
                    incr(i);
                }
                if (i >= m) {
                    return;
                } else if (type(p) == disc_node) {
                    print_char('|');
                    short_display(vlink(pre_break(p)));
                    print_char('|');
                    short_display(vlink(post_break(p)));
                    print_char('|');
                } else {
                    /*tex Print a short indication of the contents of node |p| */
                    print_short_node_contents(p);
                }
            }
            p = vlink(p);
            if (!p)
                return;
        }
        update_terminal();
    }
}

/*tex

    When debugging a macro package, it can be useful to see the exact control
    sequence names in the format file. For example, if ten new csnames appear,
    it's nice to know what they are, to help pinpoint where they came from. (This
    isn't a truly \quote {basic} printing procedure, but that's a convenient
    module in which to put it.)

*/

void print_csnames(int hstart, int hfinish)
{
    int h;
    fprintf(stderr, "fmtdebug:csnames from %d to %d:", (int) hstart, (int) hfinish);
    for (h = hstart; h <= hfinish; h++) {
        if (cs_text(h) > 0) {
            /*tex We have anything at this position. */
            unsigned char *c = str_string(cs_text(h));
            unsigned char *l = c + str_length(cs_text(h));
            while (c < l) {
                /*tex Print the characters. */
                fputc(*c++, stderr);
            }
            fprintf(stderr, "|");
        }
    }
}

/*tex

    \TEX\ is occasionally supposed to print diagnostic information that goes only
    into the transcript file, unless |tracing_online| is positive. Here are two
    routines that adjust the destination of print commands:

*/

void begin_diagnostic(void)
{
    global_old_setting = selector;
    if ((tracing_online_par <= 0) && (selector == term_and_log)) {
        decr(selector);
        if (error_state.history == spotless)
            error_state.history = warning_issued;
    }
}

/*tex Restore proper conditions after tracing. */

void end_diagnostic(int blank_line)
{
    tprint_nl("");
    if (blank_line)
        print_ln();
    selector = global_old_setting;
}
