/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

# define detokenized_line() (line_catcode_table==NO_CAT_TABLE)

# define the_cat_code(b) ( \
    (line_catcode_table == DEFAULT_CAT_TABLE) ? \
        get_cat_code(cat_code_table_par,b) \
    : ( (line_catcode_table > -0xFF) ? \
        get_cat_code(line_catcode_table,b) \
    : ( \
        - line_catcode_table - 0xFF \
    ) ) \
)

/*tex

    The \TEX\ system does nearly all of its own memory allocation, so that it can
    readily be transported into environments that do not have automatic
    facilities for strings, garbage collection, etc., and so that it can be in
    control of what error messages the user receives. The dynamic storage
    requirements of \TEX\ are handled by providing two large arrays called
    |fixmem| and |varmem| in which consecutive blocks of words are used as nodes
    by the \TEX\ routines.

    Pointer variables are indices into this array, or into another array called
    |eqtb| that will be explained later. A pointer variable might also be a
    special flag that lies outside the bounds of |mem|, so we allow pointers to
    assume any |halfword| value. The minimum halfword value represents a null
    pointer. \TEX\ does not assume that |mem[null]| exists.

    Locations in |fixmem| are used for storing one-word records; a conventional
    |AVAIL| stack is used for allocation in this array.

    One can make an argument to switch to standard \CCODE\ allocation but the
    current approach is very efficient in memory usage and performence so we stay
    with it.

*/

/*tex

    The big dynamic storage area is names |fixmem| where the smallest location
    of one|-|word memory in use is |fix_mem_min| and the largest location of
    one|-|word memory in use is |fix_mem_max|.

    The |dyn_used| variable keep strack of how much memory is in use. The head of
    the list of available one|-|word nodes is registered in |avail|. The last
    one-|word node used in |mem| is |fix_mem_end|.

    All these variables are packed in the structure |fixed_memory_state|:

*/

fixed_memory_state_info fixed_memory_state = { NULL, 0, 0, 0, 0, 0, 100000 };

/*tex

    Token data has its own memory space. Again we have some state variables:
    |temp_token_head| is the head of a (temporary) list of some kind as are
    |hold_token_head| and |omit_template|. A permanently empty list is available
    in |null_list| and the head of the token list built by |scan_keyword| is
    registered in |backup_head|.

    All these variables are packed in the structure |token_data|:

*/

token_data_info token_data;

void initialize_tokens(void)
{
    halfword p;
    fixed_memory_state.avail = null;
    fixed_memory_state.fix_mem_end = 0;
    fast_get_avail(p);
    temp_token_head = p;
    set_token_info(temp_token_head, 0);
    fast_get_avail(p);
    hold_token_head = p;
    set_token_info(hold_token_head, 0);
    fast_get_avail(p);
    omit_template = p;
    set_token_info(omit_template, 0);
    fast_get_avail(p);
    null_list = p;
    set_token_info(null_list, 0);
    fast_get_avail(p);
    backup_head = p;
    set_token_info(backup_head, 0);
    fixed_memory_state.dyn_used = 0;
    in_lua_escape = 0;
}

/*tex

    The function |get_avail| returns a pointer to a new one-word node whose
    |link| field is |null| (which is just 0). However, \TEX\ will halt if there
    is no more room left.

    If the available-space list is empty, i.e., if |avail = null|, we try first
    to increase |fix_mem_end|. If that cannot be done, i.e., if |fix_mem_end =
    fix_mem_max|, we try to reallocate array |fixmem|. If, that doesn't work, we
    have to quit.

    Remark: we can have a pool of chunks where we get from or just allocate per
    token (as we have lots of them that is slow). But then format loading becomes
    much slower as we need to recreate the linked list. A no go. In todays terms
    \TEX\ memory usage is low anyway.

*/

# define fixmemcast(a) (smemory_word *)(a)

halfword get_avail(void)
{
    /*tex Get top location in the |avail| stack. */
    halfword p = fixed_memory_state.avail;
    if (p) {
        /*tex Pop it off. */
        fixed_memory_state.avail = token_link(fixed_memory_state.avail);
    } else if (fixed_memory_state.fix_mem_end < fixed_memory_state.fix_mem_max) {
        /*tex Go into virgin territory. */
        incr(fixed_memory_state.fix_mem_end);
        p = fixed_memory_state.fix_mem_end;
    } else {
        /*tex The big dynamic storage area. */
        smemory_word *new_fixmem;
        unsigned t = (fixed_memory_state.fix_mem_max / 5);
        new_fixmem = fixmemcast(realloc(fixed_memory_state.fixmem, sizeof(smemory_word) * (fixed_memory_state.fix_mem_max + t + 1)));
        if (new_fixmem == NULL) {
            /*tex If memory is exhausted, display possible runaway text. */
            runaway();
            overflow("token memory size", fixed_memory_state.fix_mem_max);
        } else {
            fixed_memory_state.fixmem = new_fixmem;
        }
        memset((void *)(fixed_memory_state.fixmem + fixed_memory_state.fix_mem_max + 1), 0, t * sizeof(smemory_word));
        fixed_memory_state.fix_mem_max += t;
        p = ++fixed_memory_state.fix_mem_end;
    }
    /*tex Provide an oft-desired initialization of the new node. */
    token_link(p) = null;
    /*tex Maintain statistics. */
    incr(fixed_memory_state.dyn_used);
    return (halfword) p;
}

/*tex

    The procedure |flush_list(p)| frees an entire linked list of one-word nodes
    that starts at position |p|. It makes list of single|-|word nodes available:

*/

void flush_list(halfword p)
{
    if (p) {
        halfword r = p;
        halfword q;
        do {
            q = r;
            r = token_link(r);
            decr(fixed_memory_state.dyn_used);
        } while (r);
        /*tex Now |q| is the last node on the list. */
        token_link(q) = fixed_memory_state.avail;
        fixed_memory_state.avail = p;
    }
}

/*tex

    A \TEX\ token is either a character or a control sequence, and it is
    represented internally in one of two ways: (1)~A character whose ASCII code
    number is |c| and whose command code is |m| is represented as the number
    $2^{21}m+c$; the command code is in the range |1 <= m <= 14|. (2)~A control
    sequence whose |eqtb| address is |p| is represented as the number
    |cs_token_flag+p|. Here |cs_token_flag = t =| $2^{25}-1$ is larger than
    $2^{21}m+c$, yet it is small enough that |cs_token_flag + p < max_halfword|;
    thus, a token fits comfortably in a halfword.

    A token |t| represents a |left_brace| command if and only if |t <
    left_brace_limit|; it represents a |right_brace| command if and only if we
    have |left_brace_limit <= t <right_brace_limit|; and it represents a |match|
    or |end_match| command if and only if |match_token <= t <= end_match_token|.
    The following definitions take care of these token-oriented constants and a
    few others.

    A token list is a singly linked list of one-word nodes in |mem|, where each
    word contains a token and a link. Macro definitions, output-routine
    definitions, marks, |\write| texts, and a few other things are remembered
    by \TEX\ in the form of token lists, usually preceded by a node with a
    reference count in its |token_ref_count| field. The token stored in location
    |p| is called |info(p)|.

    Three special commands appear in the token lists of macro definitions. When
    |m = match|, it means that \TEX\ should scan a parameter for the current macro;
    when |m = end_match|, it means that parameter matching should end and \TEX\
    should start reading the macro text; and when |m = out_param|, it means that
    \TEX\ should insert parameter number |c| into the text at this point.

    The enclosing |\char'173| and |\char'175| characters of a macro
    definition are omitted, but the final right brace of an output routine is
    included at the end of its token list.

    Here is an example macro definition that illustrates these conventions. After
    \TEX\ processes the text

    \starttyping
    \def\mac a#1#2 \b {#1\-a ##1#2 \#2\}
    \stoptyping

    the definition of |\mac| is represented as a token list containing

    \starttyping
    (reference count) letter a match # match # spacer \b end_match
    out_param1 \- letter a spacer, mac_param # other_char 1
    out_param2 spacer out_param 2
    \stoptyping

    The procedure |scan_toks| builds such token lists, and |macro_call| does the
    parameter matching.

    Examples such as |\def\m{\def\m{a} b}| explain why reference counts would be
    needed even if \TeX\ had no |\let| operation: When the token list for |\m| is
    being read, the redefinition of |\m| changes the |eqtb| entry before the
    token list has been fully consumed, so we dare not simply destroy a token
    list when its control sequence is being redefined.

    If the parameter-matching part of a definition ends with |#{}|, the
    corresponding token list will have |{| just before the |end_match| and
    also at the very end. The first |{| is used to delimit the parameter; the
    second one keeps the first from disappearing.

    The |print_meaning| subroutine displays |cur_cmd| and |cur_chr| in symbolic
    form, including the expansion of a macro or mark.

*/

void print_meaning(void)
{
    /*tex

    This would make sense but some macro packages don't like it:

    \starttyping
    if (cur_cmd == math_given_cmd) {
        cur_cmd = xmath_given_cmd ;
    }
    \stoptyping

    */
    print_cmd_chr((quarterword) cur_cmd, cur_chr);
    if (cur_cmd >= call_cmd) {
        print_char(':');
        print_ln();
        token_show(cur_chr);
    } else if ((cur_cmd == top_bot_mark_cmd) && (cur_chr < marks_code)) {
        /*tex Show the meaning of a mark node. */
        print_char(':');
        print_ln();
        switch (cur_chr) {
            case first_mark_code:
                token_show(first_mark(0));
                break;
            case bot_mark_code:
                token_show(bot_mark(0));
                break;
            case split_first_mark_code:
                token_show(split_first_mark(0));
                break;
            case split_bot_mark_code:
                token_show(split_bot_mark(0));
                break;
            default:
                token_show(top_mark(0));
                break;
        }
    }
}

/*tex

    The procedure |show_token_list|, which prints a symbolic form of the token
    list that starts at a given node |p|, illustrates these conventions. The
    token list being displayed should not begin with a reference count. However,
    the procedure is intended to be robust, so that if the memory links are awry
    or if |p| is not really a pointer to a token list, nothing catastrophic will
    happen.

    An additional parameter |q| is also given; this parameter is either null or
    it points to a node in the token list where a certain magic computation takes
    place that will be explained later. Basically, |q| is non-null when we are
    printing the two-line context information at the time of an error message;
    |q| marks the place corresponding to where the second line should begin.

    For example, if |p| points to the node containing the first |a| in the token
    list above, then |show_token_list| will print the string

    \starttyping
    a#1#2 \b ->#1-a ##1#2 #2
    \stoptyping

    and if |q| points to the node containing the second |a|, the magic
    computation will be performed just before the second |a| is printed.

    The generation will stop, and |\ETC.| will be printed, if the length of
    printing exceeds a given limit~|l|. Anomalous entries are printed in the form
    of control sequences that are not followed by a blank space, e.g., |\BAD.|;
    this cannot be confused with actual control sequences because a real control
    sequence named |BAD| would come out |\BAD |.

*/

# define not_so_bad(p) \
switch (m) { \
    case assign_int_cmd: \
    case assign_dimen_cmd: \
    case assign_toks_cmd: \
        break; \
    case node_cmd: \
        p("[internal node pointer]"); \
        break; \
    case lua_call_cmd: \
        p("[internal lua function call]"); \
        break; \
    case lua_expandable_call_cmd: \
        p("[internal expandable lua function call]"); \
        break; \
    case lua_local_call_cmd: \
        p("[internal local lua function call]"); \
        break; \
    default: \
        p("BAD"); \
        break; \
}

void show_token_list(int p, int q, int l)
{
    /*tex character used in a |match| */
    unsigned char match_chr = '#';
    /*tex the highest parameter number, as an \ASCII\ digit */
    unsigned char n = '0';
    tally = 0;
    if (l < 0)
        l = 0x3FFFFFFF;
    while ((p) && (tally < l)) {
        if (p == q) {
            /*tex Do magic computation. */
            set_trick_count();
        }
        /*tex Display token |p|, and |return| if there are problems. */
        if ((p < (int) fixed_memory_state.fix_mem_min) || (p > (int) fixed_memory_state.fix_mem_end)) {
            tprint_esc("CLOBBERED.");
            return;
        } else if (token_info(p) >= cs_token_flag) {
            if (!((inhibit_par_tokens) && (token_info(p) == par_token)))
                print_cs(token_info(p) - cs_token_flag);
        } else {
            int m = token_cmd(token_info(p));
            int c = token_chr(token_info(p));
            if (token_info(p) < 0) {
                tprint_esc("BAD");
            } else {
                /*
                    Display the token (|m|,|c|). The procedure usually \quote
                    {learns} the character code used for macro parameters by
                    seeing one in a |match| command before it runs into any
                    |out_param| commands.

                */
                switch (m) {
                    case left_brace_cmd:
                    case right_brace_cmd:
                    case math_shift_cmd:
                    case tab_mark_cmd:
                    case sup_mark_cmd:
                    case sub_mark_cmd:
                    case spacer_cmd:
                    case letter_cmd:
                    case other_char_cmd:
                        print(c);
                        break;
                    case mac_param_cmd:
                        if (!in_lua_escape && (expand_state.is_in_csname == 0))
                            print(c);
                        print(c);
                        break;
                    case out_param_cmd:
                        print(match_chr);
                        if (c <= 9) {
                            print_char(c + '0');
                        } else {
                            print_char('!');
                            return;
                        }
                        break;
                    case match_cmd:
                        match_chr = c;
                        print(c);
                        incr(n);
                        print_char(n);
                        if (n > '9')
                            return;
                        break;
                    case end_match_cmd:
                        if (c == 0)
                            tprint("->");
                        break;
                    default:
                        not_so_bad(tprint);
                        break;
                }
            }
        }
        p = token_link(p);
    }
    if (p) {
        tprint_esc("ETC.");
    }
}

/*
# define do_buffer_to_unichar(a,b) do { \
    a = (halfword)str2uni(iobuffer+b); \
    b += utf8_size(a); \
} while (0)
*/

# define do_buffer_to_unichar(a,b) do { \
    a = (unsigned) ((const unsigned char) *(iobuffer+b)); \
    if (a <= 0x80) { \
        b += 1; \
    } else { \
        a = (halfword)str2uni(iobuffer+b); \
        b += utf8_size(a); \
    } \
} while (0)

/*tex

    Here's the way we sometimes want to display a token list, given a pointer to
    its reference count; the pointer may be null.

*/

void token_show(halfword p)
{
    if (p) {
        show_token_list(token_link(p), null, 10000000);
    }
}

/*tex

    The next function, |delete_token_ref|, is called when a pointer to a token
    list's reference count is being removed. This means that the token list
    should disappear if the reference count was |null|, otherwise the count
    should be decreased by one.

    Variable |p| points to the reference count of a token list that is losing one
    reference.

*/

void delete_token_ref(halfword p)
{
    if (token_ref_count(p) == 0)
        flush_list(p);
    else
        decr(token_ref_count(p));
}

int get_char_cat_code(int curchr)
{
    return the_cat_code(curchr);
}

static void invalid_character_error(void)
{
    error_state.deletions_allowed = 0;
    tex_error(
        "Text line contains an invalid character",
        "A funny symbol that I can't read has just been input.\n"
        "Continue, and I'll forget that it ever happened."
    );
    error_state.deletions_allowed = 1;
}

static int process_sup_mark(void);

static int scan_control_sequence(void);

typedef enum {
    next_line_ok,
    next_line_return,
    next_line_restart
} next_line_retval;

static next_line_retval next_line(void);

/*tex

    In case you are getting bored, here is a slightly less trivial routine: Given
    a string of lowercase letters, like |pt| or |plus| or |width|,
    the |scan_keyword| routine checks to see whether the next tokens of input
    match this string. The match must be exact, except that uppercase letters
    will match their lowercase counterparts; uppercase equivalents are determined
    by subtracting |"a" - "A"|, rather than using the |uc_code| table, since \TEX\
    uses this routine only for its own limited set of keywords.

    If a match is found, the characters are effectively removed from the input
    and |true| is returned. Otherwise |false| is returned, and the input is left
    essentially unchanged (except for the fact that some macros may have been
    expanded, etc.).

    The |scan_keyword| function is a little inefficient in the sense that when there
    is no match, it will push back what got read so far. So there is tokan allocation,
    pushing a level etc involved. Keep in mind that expansion happens here so what gets
    pushing back is not always literally pushing back what we started with.

*/

/* we could return the first found character */

int scan_keyword(const char *s)
{
    if (strlen(s) > 0) {
        /*tex tail of the backup list */
        halfword p = backup_head;
        /*tex new node being added to the token list via |store_new_token| */
        halfword q;
        /*tex index into |str_pool| */
     // const char *k = s;
        halfword save_cur_cs = cur_cs;
        token_link(p) = null;
     // while (*k) {
        while (*s) {
            /*tex Recursion is possible here! */
            get_x_token();
         // if ((cur_cs == 0) && ((cur_chr == *k) || (cur_chr == *k - 'a' + 'A'))) {
            if ((cur_cs == 0) && ((cur_chr == *s) || (cur_chr == *s - 'a' + 'A'))) {
                store_new_token(cur_tok);
         //     k++;
                s++;
            } else if ((cur_cmd != spacer_cmd) || (p != backup_head)) {
                back_input();
                if (p != backup_head) {
                    begin_token_list(token_link(backup_head), backed_up);
                }
                cur_cs = save_cur_cs;
                return 0;
            }
        }
        if (token_link(backup_head) != null)
            flush_list(token_link(backup_head));
        cur_cs = save_cur_cs;
        return 1;
    } else {
        /*tex but not with newtokenlib zero keyword simply doesn't match  */
        return 0 ;
    }
}

int scan_keyword_case_sensitive(const char *s)
{
    if (strlen(s) > 0) {
        halfword p = backup_head;
        halfword q;
     // const char *k = s;
        halfword save_cur_cs = cur_cs;
        token_link(p) = null;
     // while (*k) {
        while (*s) {
            get_x_token();
         // if ((cur_cs == 0) && (cur_chr == *k)) {
            if ((cur_cs == 0) && (cur_chr == *s)) {
                store_new_token(cur_tok);
             // k++;
                s++;
            } else if ((cur_cmd != spacer_cmd) || (p != backup_head)) {
                back_input();
                if (p != backup_head) {
                    begin_token_list(token_link(backup_head), backed_up);
                }
                cur_cs = save_cur_cs;
                return 0;
            }
        }
        if (token_link(backup_head) != null)
            flush_list(token_link(backup_head));
        cur_cs = save_cur_cs;
        return 1;
    } else {
        return 0 ;
    }
}

/*tex

    We can not return |undefined_control_sequence| under some conditions (inside
    |shift_case|, for example). This needs thinking.

*/

halfword active_to_cs(int curchr, int force)
{
    halfword curcs;
    int nncs = no_new_control_sequence;
    if (force) {
        no_new_control_sequence = 0;
    }
    if (curchr > 0) {
        /*tex This is not that efficient: we can make a helper that doesn't use an alloc. */
        char *b = (char *) uni2str((unsigned) curchr);
        char *utfbytes = malloc(8);
        utfbytes = strcpy(utfbytes, "\xEF\xBF\xBF");
        utfbytes = strcat(utfbytes, b);
        free(b);
        curcs = string_lookup(utfbytes, utf8_size(curchr)+3);
        free(utfbytes);
    } else {
        /*tex 0xFFFF ... why not 3 ? */
        curcs = string_lookup("\xEF\xBF\xBF", 4);
    }
    no_new_control_sequence = nncs;
    return curcs;
}

/*tex

    Maybe this function should listen to |\escapechar| but we can do without.
    Seldom called anyway.

*/

static char *cs_to_string(halfword p)
{
    const char *s;
    int k = 0;
    static char ret[256] = { 0 };
    if (p == 0 || p == null_cs) {
        /* use memcpy instead, non critital */
        s = "\\csname\\endcsname";
        while (*s) {
            ret[k++] = *s++;
        }
        ret[k] = 0;
    } else {
        str_number txt = cs_text(p);
        char *sh = makecstring(txt);
        s = sh;
        if (is_active_cs(txt)) {
            s = s + 3;
            while (*s) {
                ret[k++] = *s++;
            }
            ret[k] = 0;
        } else {
            ret[k++] = '\\';
            while (*s) {
                ret[k++] = *s++;
            }
            ret[k] = 0;
        }
        free(sh);
    }
    return (char *) ret;
}

/*tex This is sort of a hack. */

static char *cmd_chr_to_string(int cmd, int chr)
{
    char *s;
    str_number str;
    int sel = selector;
    selector = new_string;
    print_cmd_chr((quarterword) cmd, chr);
    str = make_string();
    s = makecstring(str);
    selector = sel;
    flush_str(str);
    return s;
}

/*tex

    The heart of \TEX's input mechanism is the |get_next| procedure, which we
    shall develop in the next few sections of the program. Perhaps we shouldn't
    actually call it the \quote {heart}, however, because it really acts as \TEX's
    eyes and mouth, reading the source files and gobbling them up. And it also
    helps \TEX\ to regurgitate stored token lists that are to be processed again.

    The main duty of |get_next| is to input one token and to set |cur_cmd| and
    |cur_chr| to that token's command code and modifier. Furthermore, if the
    input token is a control sequence, the |eqtb| location of that control
    sequence is stored in |cur_cs|; otherwise |cur_cs| is set to zero.

    Underlying this simple description is a certain amount of complexity because
    of all the cases that need to be handled. However, the inner loop of
    |get_next| is reasonably short and fast.

    When |get_next| is asked to get the next token of a |\read| line, it sets
    |cur_cmd = cur_chr = cur_cs = 0| in the case that no more tokens appear on
    that line. (There might not be any tokens at all, if the |end_line_char| has
    |ignore| as its catcode.)

    The value of |par_loc| is the |eqtb| address of |\par|. This quantity is
    needed because a blank line of input is supposed to be exactly equivalent to
    the appearance of |\par|; we must set |cur_cs := par_loc| when detecting a
    blank line.

    Parts |get_next| are executed more often than any other instructions of \TEX.
    The global variable |force_eof| is normally |false|; it is set |true| by an
    |\endinput| command. |luacstrings| is the number of lua print statements
    waiting to be input, it is changed by |luatokencall|.

    If the user has set the |pausing| parameter to some positive value, and if
    nonstop mode has not been selected, each line of input is displayed on the
    terminal and the transcript file, followed by |=>|. \TEX\ waits for a
    response. If the response is simply |carriage_return|, the line is accepted
    as it stands, otherwise the line typed is used instead of the line in the
    file.

*/

void firm_up_the_line(void)
{
    ilimit = iolast;
    if ((pausing_par > 0) && (error_state.interaction > nonstop_mode)) {
        int k;
        wake_up_terminal();
        print_ln();
        if (istart < ilimit) {
            for (k = istart; k <= ilimit - 1; k++)
                print_char(iobuffer[k]);
        }
        iofirst = ilimit;
        prompt_input("=>");
        if (iolast > iofirst) {
            /*tex Move line down in buffer. */
            for (k = iofirst; k < +iolast - 1; k++)
                iobuffer[k + istart - iofirst] = iobuffer[k];
            ilimit = istart + iolast - iofirst;
        }
    }
}

/*tex

    Before getting into |get_next|, let's consider the subroutine that is called
    when an |\outer| control sequence has been scanned or when the end of a
    file has been reached. These two cases are distinguished by |cur_cs|, which
    is zero at the end of a file.

*/

void check_outer_validity(void)
{
    if (suppress_outer_error_par) {
        return;
    } else if (scanner_status != normal) {
        /*tex points to inserted token list */
        halfword p;
        /*tex auxiliary pointer */
        halfword q;
        error_state.deletions_allowed = 0;
        /*tex

            Back up an outer control sequence so that it can be reread. An
            outer control sequence that occurs in a |\read| will not be
            reread, since the error recovery for |\read| is not very powerful.

        */
        if (cur_cs != 0) {
            if ((istate == token_list) || (iname < 1) || (iname > 17)) {
                p = get_avail();
                token_info(p) = cs_token_flag + cur_cs;
                /*tex prepare to read the control sequence again */
                begin_token_list(p, backed_up);
            }
            /*tex replace it by a space */
            cur_cmd = spacer_cmd;
            cur_chr = ' ';
        }
        if (scanner_status > skipping) {
            const char *errhlp =
                "I suspect you have forgotten a `}', causing me\n"
                "to read past where you wanted me to stop.\n"
                "I'll try to recover; but if the error is serious,\n"
                "you'd better type `E' or `X' now and fix your file."
            ;
            char errmsg[318];
            const char *startmsg;
            const char *scannermsg;
            /*tex

                Tell the user what has run away and try to recover Print a
                definition, argument, or preamble.

            */
            runaway();
            if (cur_cs == 0) {
                startmsg = "File ended";
            } else {
                cur_cs = 0;
                startmsg = "Forbidden control sequence found";
            }
            /*tex

                Print either |definition| or |use| or |preamble| or |text|, and
                insert tokens that should lead to recovery. The recovery
                procedure can't be fully understood without knowing more about
                the \TEX\ routines that should be aborted, but we can sketch the
                ideas here: For a runaway definition we will insert a right
                brace; for a runaway preamble, we will insert a special |\cr|
                token and a right brace; and for a runaway argument, we will set
                |long_state| to |outer_call| and insert |\par|.

            */
            p = get_avail();
            switch (scanner_status) {
                case defining:
                    scannermsg = "definition";
                    token_info(p) = right_brace_token + '}';
                    break;
                case matching:
                    scannermsg = "use";
                    token_info(p) = par_token;
                    expand_state.long_state = outer_call_cmd;
                    break;
                case aligning:
                    scannermsg = "preamble";
                    token_info(p) = right_brace_token + '}';
                    q = p;
                    p = get_avail();
                    token_link(p) = q;
                    token_info(p) = cs_token_flag + frozen_cr;
                    align_state = -1000000;
                    break;
                case absorbing:
                    scannermsg = "text";
                    token_info(p) = right_brace_token + '}';
                    break;
                default:
                    scannermsg = "unknown";
                    break;
            }
            begin_token_list(p, inserted);
            snprintf(errmsg, 318, "%s while scanning %s of %s", startmsg, scannermsg, cs_to_string(warning_index));
            tex_error(
                errmsg,
                errhlp
            );
        } else {
            char errmsg[256];
            int cserror = 0;
            char *ss;
            if (cur_cs != 0) {
                cserror = 1;
                cur_cs = 0;
            }
            ss = cmd_chr_to_string(if_test_cmd, cur_if);
            snprintf(errmsg, 255, "Incomplete %s; all text was ignored after line %d", ss, (int) skip_line);
            free(ss);
            /*tex Incomplete |\if...| */
            cur_tok = cs_token_flag + frozen_fi;
            /*tex back up one inserted token and call |error|. */
            {
                error_state.OK_to_interrupt = 0;
                back_input();
                token_type = inserted;
                error_state.OK_to_interrupt = 1;
                if (cserror) {
                    tex_error(
                        errmsg,
                        "A forbidden control sequence occurred in skipped text.\n"
                        "This kind of error happens when you say `\\if...' and forget\n"
                        "the matching `\\fi'. I've inserted a `\\fi'; this might work."
                    );
                } else {
                    tex_error(
                        errmsg,
                        "The file ended while I was skipping conditional text.\n"
                        "This kind of error happens when you say `\\if...' and forget\n"
                        "the matching `\\fi'. I've inserted a `\\fi'; this might work."
                    );
                }
            }
        }
        error_state.deletions_allowed = 1;
    }
}

/*tex

    The other variant gives less clutter in tracing cache usage when profiling
    and for some files (like the manual) also a bit of a speedup. Splitting the
    switch which gives 10 times less Bim in vallgrind! See the \LUATEX\ source
    for that code.

    The big switch changes the state if necessary, and |goto switch| if the
    current character should be ignored, or |goto reswitch| if the current
    character changes to another.

    The n-way switch accomplishes the scanning quickly, assuming that a decent
    \CCODE\ compiler has translated the code. Note that the numeric values for
    |mid_line|, |skip_blanks|, and |new_line| are spaced apart from each other by
    |max_char_code+1|, so we can add a character's command code to the state to
    get a single number that characterizes both.

    Remark: checking performance indicated that this switch was the cause of many
    branch prediction errors but changing it to:

    \starttyping
    c = istate + cur_cmd;
    if (c == (mid_line + letter_cmd) || c == (mid_line + other_char_cmd)) {
        return 1;
    } else if (c >= new_line) {
        switch (c) {
        }
    } else if (c >= skip_blanks) {
        switch (c) {
        }
    } else if (c >= mid_line) {
        switch (c) {
        }
    } else {
        istate = mid_line;
        return 1;
    }
    \stoptyping

    This gives as many prediction errors. So, we can indeed assume that the
    compiler does the right job, or that there is simply no other way.

    When a line is finished a space is emited. When a character of type |spacer|
    gets through, its character code is changed to |\ =040|. This means that the
    \ASCII\ codes for tab and space, and for the space inserted at the end of a
    line, will be treated alike when macro parameters are being matched. We do
    this since such characters are indistinguishable on most computer terminal
    displays.

*/

/*

    c = istate + cur_cmd;
    if (c == (mid_line + letter_cmd) || c == (mid_line + other_char_cmd)) {
        return 1;
    } else if (c >= new_line) {
        ....
    }

*/

static int get_next_file(void)
{
  SWITCH:
    if (iloc <= ilimit) {
        /*tex current line not yet finished */
        do_buffer_to_unichar(cur_chr, iloc);
      RESWITCH:
        if (detokenized_line()) {
            /* happens seldom */
            cur_cmd = (cur_chr == ' ' ? 10 : 12);
        } else {
            cur_cmd = the_cat_code(cur_chr);
        }
        switch (istate + cur_cmd) {
            case mid_line + ignore_cmd:
            case skip_blanks + ignore_cmd:
            case new_line + ignore_cmd:
            case skip_blanks + spacer_cmd:
            case new_line + spacer_cmd:
                /*tex Cases where character is ignored. */
                goto SWITCH;
                break;
            case mid_line + escape_cmd:
            case new_line + escape_cmd:
            case skip_blanks + escape_cmd:
                /*tex Scan a control sequence. */
                istate = (unsigned char) scan_control_sequence();
                if (! suppress_outer_error_par && cur_cmd >= outer_call_cmd)
                    check_outer_validity();
                break;
            case mid_line + active_char_cmd:
            case new_line + active_char_cmd:
            case skip_blanks + active_char_cmd:
                /*tex Process an active-character.  */
                cur_cs = active_to_cs(cur_chr, 0);
                cur_cmd = eq_type(cur_cs);
                cur_chr = equiv(cur_cs);
                istate = mid_line;
                if (! suppress_outer_error_par && cur_cmd >= outer_call_cmd)
                    check_outer_validity();
                break;
            case mid_line + sup_mark_cmd:
            case new_line + sup_mark_cmd:
            case skip_blanks + sup_mark_cmd:
                /*tex If this |sup_mark| starts. */
                if (process_sup_mark())
                    goto RESWITCH;
                else
                    istate = mid_line;
                break;
            case mid_line + invalid_char_cmd:
            case new_line + invalid_char_cmd:
            case skip_blanks + invalid_char_cmd:
                /*tex Decry the invalid character and |goto restart|. */
                invalid_character_error();
                /*tex Because state may be |token_list| now: */
                return 0;
                break;
            case mid_line + spacer_cmd:
                /*tex Enter |skip_blanks| state, emit a space. */
                istate = skip_blanks;
                cur_chr = ' ';
                break;
            case mid_line + car_ret_cmd:
                /*tex Finish the line. */
                iloc = ilimit + 1;
                cur_cmd = spacer_cmd;
                cur_chr = ' ';
                break;
            case skip_blanks + car_ret_cmd:
            case mid_line + comment_cmd:
            case new_line + comment_cmd:
            case skip_blanks + comment_cmd:
                /*tex Finish line, |goto switch|; */
                iloc = ilimit + 1;
                goto SWITCH;
                break;
            case new_line + car_ret_cmd:
                /*tex Finish line, emit a |\par|; */
                iloc = ilimit + 1;
                cur_cs = par_loc;
                cur_cmd = eq_type(cur_cs);
                cur_chr = equiv(cur_cs);
                if (! suppress_outer_error_par && cur_cmd >= outer_call_cmd)
                    check_outer_validity();
                break;
            case skip_blanks + left_brace_cmd:
            case new_line + left_brace_cmd:
                istate = mid_line;
                /*tex Fall through. */
                align_state++;
                break;
            case mid_line + left_brace_cmd:
                align_state++;
                break;
            case skip_blanks + right_brace_cmd:
            case new_line + right_brace_cmd:
                istate = mid_line;
                /*tex Fall through. */
                align_state--;
                break;
            case mid_line + right_brace_cmd:
                align_state--;
                break;
            case mid_line + math_shift_cmd:
            case mid_line + tab_mark_cmd:
            case mid_line + mac_param_cmd:
            case mid_line + sub_mark_cmd:
            case mid_line + letter_cmd:
            case mid_line + other_char_cmd:
                break;
            /*
            case skip_blanks + math_shift_cmd:
            case skip_blanks + tab_mark_cmd:
            case skip_blanks + mac_param_cmd:
            case skip_blanks + sub_mark_cmd:
            case skip_blanks + letter_cmd:
            case skip_blanks + other_char_cmd:
            case new_line    + math_shift_cmd:
            case new_line    + tab_mark_cmd:
            case new_line    + mac_param_cmd:
            case new_line    + sub_mark_cmd:
            case new_line    + letter_cmd:
            case new_line    + other_char_cmd:
            */
            default:
                istate = mid_line;
                break;
        }
    } else {
        if (iname != 21) {
            istate = new_line;
        }
        /*tex

           Move to next line of file, or |goto restart| if there is no next line,
           or |return| if a |\read| line has finished.

        */
        do {
            next_line_retval r = next_line();
            if (r == next_line_return) {
                return 1;
            } else if (r == next_line_restart) {
                return 0;
            }
        } while (0);
        check_interrupt();
        goto SWITCH;
    }
    return 1;
}

/*tex

    Notice that a code like |^^8| becomes |x| if not followed by a hex digit.
    We only support a limited set:

    \starttyping
    ^^^^^^XXXXXX
    ^^^^XXXXXX
    ^^XX ^^<char>
    \stoptyping

*/

# define is_hex(a) ((a>='0'&&a<='9')||(a>='a'&&a<='f'))

# define add_nybble(c) \
    if (c<='9') { \
        cur_chr=(cur_chr<<4)+c-'0'; \
    } else { \
        cur_chr=(cur_chr<<4)+c-'a'+10; \
    }

# define set_nybble(c) \
    if (c<='9') { \
        cur_chr=c-'0'; \
    } else { \
        cur_chr=c-'a'+10; \
    }

# define one_hex_to_cur_chr(c1) \
    set_nybble(c1);

# define two_hex_to_cur_chr(c1,c2) \
    set_nybble(c1); \
    add_nybble(c2);

# define four_hex_to_cur_chr(c1,c2,c3,c4) \
    two_hex_to_cur_chr(c1,c2); \
    add_nybble(c3); \
    add_nybble(c4);

# define six_hex_to_cur_chr(c1,c2,c3,c4,c5,c6) \
    four_hex_to_cur_chr(c1,c2,c3,c4); \
    add_nybble(c5); \
    add_nybble(c6);

static int process_sup_mark(void)
{
    if (cur_chr == iobuffer[iloc]) {
        if (iloc < ilimit) {
            if ((cur_chr == iobuffer[iloc + 1]) && (cur_chr == iobuffer[iloc + 2])) {
                if ((cur_chr == iobuffer[iloc + 3]) && (cur_chr == iobuffer[iloc + 4])) {
                    /*tex |^^^^^^XXXXXX| */
                    if ((iloc + 10) <= ilimit) {
                        int c1 = iobuffer[iloc +  5];
                        int c2 = iobuffer[iloc +  6];
                        int c3 = iobuffer[iloc +  7];
                        int c4 = iobuffer[iloc +  8];
                        int c5 = iobuffer[iloc +  9];
                        int c6 = iobuffer[iloc + 10];
                        if (is_hex(c1) && is_hex(c2) && is_hex(c3) &&
                            is_hex(c4) && is_hex(c5) && is_hex(c6)) {
                            iloc = iloc + 11;
                            six_hex_to_cur_chr(c1,c2,c3,c4,c5,c6);
                            return 1;
                        } else {
                            tex_error(
                                "^^^^^^ needs six hex digits",
                                NULL
                            );
                        }
                    } else {
                        tex_error(
                            "^^^^^^ needs six hex digits, end of input",
                            NULL
                        );
                    }
                } else {
                    /*tex |^^^^XXXX| */
                    if ((iloc + 6) <= ilimit) {
                        int c1 = iobuffer[iloc + 3];
                        int c2 = iobuffer[iloc + 4];
                        int c3 = iobuffer[iloc + 5];
                        int c4 = iobuffer[iloc + 6];
                        if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4)) {
                            iloc = iloc + 7;
                            four_hex_to_cur_chr(c1,c2,c3,c4);
                            return 1;
                        } else {
                            tex_error(
                                "^^^^ needs four hex digits",
                                NULL
                            );
                        }
                    } else {
                        tex_error(
                            "^^^^ needs four hex digits, end of input",
                            NULL
                        );
                    }
                }
            } else {
                /*tex |^^XX| */
                if ((iloc + 2) <= ilimit) {
                    int c1 = iobuffer[iloc + 1];
                    int c2 = iobuffer[iloc + 2];
                    if (is_hex(c1) && is_hex(c2)) {
                        iloc = iloc + 3;
                        two_hex_to_cur_chr(c1,c2);
                        return 1;
                    }
                }
                /*tex Go on, no error, good old \TEX . */
            }
        }
        /*tex The rest. */
        {
            int c1 = iobuffer[iloc + 1];
            if (c1 < 0200) {
                iloc = iloc + 2;
                if (is_hex(c1) && (iloc <= ilimit)) {
                    int c2 = iobuffer[iloc];
                    if (is_hex(c2)) {
                        incr(iloc);
                        two_hex_to_cur_chr(c1,c2);
                        return 1;
                    }
                }
                cur_chr = (c1 < 0100 ? c1 + 0100 : c1 - 0100);
                return 1;
            }
        }
    }
    return 0;
}

/*tex

    Control sequence names are scanned only when they appear in some line of a
    file. Once they have been scanned the first time, their |eqtb| location
    serves as a unique identification, so \TEX\ doesn't need to refer to the
    original name any more except when it prints the equivalent in symbolic form.

    The program that scans a control sequence has been written carefully in order
    to avoid the blowups that might otherwise occur if a malicious user tried
    something like |\catcode'15 = 0|. The algorithm might look at
    |buffer[ilimit + 1]|, but it never looks at |buffer[ilimit + 2]|.

    If expanded characters like |^^A| or |^^df| appear in or just following a
    control sequence name, they are converted to single characters in the buffer
    and the process is repeated, slowly but surely.

*/

static int check_expanded_code(int *kk);

static int scan_control_sequence(void)
{
    int retval = mid_line;
    if (iloc > ilimit) {
        /*tex |state| is irrelevant in this case. */
        cur_cs = null_cs;
    } else {
        /*tex |cat_code(cur_chr)|, usually: */
        int cat;
        while (1) {
            int k = iloc;
            do_buffer_to_unichar(cur_chr, k);
            cat = the_cat_code(cur_chr);
            if (cat != letter_cmd || k > ilimit) {
                retval = (cat == spacer_cmd ? skip_blanks : mid_line);
                /*tex If an expanded \unknown */
                if (cat == sup_mark_cmd && check_expanded_code(&k))
                    continue;
            } else {
                retval = skip_blanks;
                do {
                    do_buffer_to_unichar(cur_chr, k);
                    cat = the_cat_code(cur_chr);
                } while (cat == letter_cmd && k <= ilimit);
                /*tex If an expanded \unknown */
                if (cat == sup_mark_cmd && check_expanded_code(&k)) {
                    continue;
                } else if (cat != letter_cmd) {
                    /*tex Backtrack one character which can be \UTF. */
                    if (cur_chr <= 0x7F) {
                        k -= 1; /* in most cases */
                    } else if (cur_chr > 0xFFFF) {
                        k -= 4;
                    } else if (cur_chr > 0x7FF) {
                        k -= 3;
                    } else /* if (cur_chr > 0x7F) */ {
                        k -= 2;
                    }
                    /*tex Now |k| points to first nonletter. */
                }
            }
            cur_cs = id_lookup(iloc, k - iloc);
            iloc = k;
            break;
        }
    }
    cur_cmd = eq_type(cur_cs);
    cur_chr = equiv(cur_cs);
    return retval;
}

/*tex

    Whenever we reach the following piece of code, we will have |cur_chr =
    buffer[k - 1]| and |k <= ilimit + 1| and |cat = get_cat_code(cat_code_table,
    cur_chr)|. If an expanded code like |^^A| or |^^df| appears in |buffer[(k -
    1) .. (k + 1)]| or |buffer[(k - 1) .. (k + 2)]|, we will store the
    corresponding code in |buffer[k - 1]| and shift the rest of the buffer left
    two or three places.

*/

static int check_expanded_code(int *kk)
{
    int k = *kk;
    if (iobuffer[k] == cur_chr && k < ilimit) {
        int d = 1;
        int l;
        if ((cur_chr == iobuffer[k + 1]) && (cur_chr == iobuffer[k + 2])) {
            if ((cur_chr == iobuffer[k + 3]) && (cur_chr == iobuffer[k + 4])) {
                if ((k + 10) <= ilimit) {
                    int c1 = iobuffer[k + 6 - 1];
                    int c2 = iobuffer[k + 6    ];
                    int c3 = iobuffer[k + 6 + 1];
                    int c4 = iobuffer[k + 6 + 2];
                    int c5 = iobuffer[k + 6 + 3];
                    int c6 = iobuffer[k + 6 + 4];
                    if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4) && is_hex(c5) && is_hex(c6)) {
                        d = 6;
                        six_hex_to_cur_chr(c1,c2,c3,c4,c5,c6);
                    } else {
                        tex_error(
                            "^^^^^^ needs six hex digits",
                            NULL
                        );
                    }
                } else {
                    tex_error(
                        "^^^^^^ needs six hex digits, end of input",
                        NULL
                    );
                }
            } else {
                if ((k + 6) <= ilimit) {
                    int c1 = iobuffer[k + 4 - 1];
                    int c2 = iobuffer[k + 4    ];
                    int c3 = iobuffer[k + 4 + 1];
                    int c4 = iobuffer[k + 4 + 2];
                    if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4)) {
                        d = 4;
                        four_hex_to_cur_chr(c1,c2,c3,c4);
                    } else {
                        tex_error(
                            "^^^^ needs four hex digits",
                            NULL
                        );
                    }
                } else {
                    tex_error(
                        "^^^^ needs four hex digits, end of input",
                        NULL
                    );
                }
            }
        } else {
            int c1 = iobuffer[k + 1];
            if (c1 < 0200) {
                d = 1;
                if (is_hex(c1) && (k + 2) <= ilimit) {
                    int c2 = iobuffer[k + 2];
                    if (is_hex(c2)) {
                        d = 2;
                        two_hex_to_cur_chr(c1,c2);
                    } else {
                        cur_chr = (c1 < 0100 ? c1 + 0100 : c1 - 0100);
                    }
                } else {
                    cur_chr = (c1 < 0100 ? c1 + 0100 : c1 - 0100);
                }
            }
        }
        if (d > 2)
            d = 2 * d - 1;
        else
            d++;
        if (cur_chr <= 0x7F) {
            iobuffer[k - 1] = (unsigned char) cur_chr;
        } else if (cur_chr <= 0x7FF) {
            iobuffer[k - 1] = (unsigned char) (0xC0 + cur_chr / 0x40);
            k++;
            d--;
            iobuffer[k - 1] = (unsigned char) (0x80 + cur_chr % 0x40);
        } else if (cur_chr <= 0xFFFF) {
            iobuffer[k - 1] = (unsigned char) (0xE0 + cur_chr / 0x1000);
            k++;
            d--;
            iobuffer[k - 1] = (unsigned char) (0x80 + (cur_chr % 0x1000) / 0x40);
            k++;
            d--;
            iobuffer[k - 1] = (unsigned char) (0x80 + (cur_chr % 0x1000) % 0x40);
        } else {
            iobuffer[k - 1] = (unsigned char) (0xF0 + cur_chr / 0x40000);
            k++;
            d--;
            iobuffer[k - 1] = (unsigned char) (0x80 + (cur_chr % 0x40000) / 0x1000);
            k++;
            d--;
            iobuffer[k - 1] = (unsigned char) (0x80 + ((cur_chr % 0x40000) % 0x1000) / 0x40);
            k++;
            d--;
            iobuffer[k - 1] = (unsigned char) (0x80 + ((cur_chr % 0x40000) % 0x1000) % 0x40);
        }
        l = k;
        ilimit = ilimit - d;
        while (l <= ilimit) {
            iobuffer[l] = iobuffer[l + d];
            l++;
        }
        *kk = k;
        return 1;
    }
    return 0;
}

/*tex

    All of the easy branches of |get_next| have now been taken care of. There is
    one more branch.

*/

static next_line_retval next_line(void)
{
    /*tex A way to end a pseudo file without trailing space: */
    if (iname > 17) {
        /*tex

            Read next line of file into |buffer|, or |goto restart| if the file
            has ended.

        */
        int inhibit_eol = 0;
        incr(input_line);
        iofirst = istart;
        if (!force_eof) {
            if (iname <= 20) {
                if (pseudo_input()) {
                    /*tex Not end of file; set |ilimit|. */
                    firm_up_the_line();
                    line_catcode_table = DEFAULT_CAT_TABLE;
                    if ((iname == 19) && (pseudo_lines(pseudo_files) == null))
                        inhibit_eol = 1;
                } else if ((every_eof_par != null) && !eof_seen[iindex]) {
                    ilimit = iofirst - 1;
                    /*tex Fake one empty line. */
                    eof_seen[iindex] = 1;
                    if (iname != 19)
                        begin_token_list(every_eof_par, every_eof_text);
                    return next_line_restart;
                } else {
                    force_eof = 1;
                }
            } else if (iname == 21) {
                halfword n = null;
              //  int t = luacstring_input(&n);
int cattable, partial, finalline;
                int t = luacstring_input(&n,&cattable,&partial,&finalline);
                switch (t) {
                    case 0:
                        force_eof = 1;
                        break;
                    case 1:
                        /*tex string */
                        firm_up_the_line();
line_catcode_table = (short) cattable;
line_partial = (signed char) partial;
                     //   line_catcode_table = (short) luacstring_cattable();
                     //   line_partial = (signed char) luacstring_partial();
                     //   if (luacstring_final_line() || line_partial || line_catcode_table == NO_CAT_TABLE)
                        if (finalline || partial || cattable == NO_CAT_TABLE)
                            inhibit_eol = 1;
                        if (!line_partial)
                            istate = new_line;
                        break;
                    case 2:
                        /*tex token */
                        cur_tok = n;
                        back_input();
                        /*tex Needs checking. */
                        return next_line_restart;
                        break;
                    case 3:
                        /*tex node */
                        if (n < biggest_char) {
                            /*tex |0x10FFFF == 1114111| */
                            cur_tok = token_val(node_cmd, n);
                            back_input();
                            /*tex Needs checking. */
                            return next_line_restart;
                        } else {
                            normal_warning("nodes","unable to store reference from lua in tex");
                            force_eof = 1;
                        }
                        break;
                    default:
                        force_eof = 1;
                        break;
                }
            } else if (lua_input_ln(cur_file, 0)) {
                /*tex Not end of file, set |ilimit|. */
                firm_up_the_line();
                line_catcode_table = DEFAULT_CAT_TABLE;
            } else if ((every_eof_par != null) && (!eof_seen[iindex])) {
                ilimit = iofirst - 1;
                /* tex Fake one empty line. */
                eof_seen[iindex] = 1;
                begin_token_list(every_eof_par, every_eof_text);
                return next_line_restart;
            } else {
                force_eof = 1;
            }
        }
        if (force_eof) {
            if (tracing_nesting_par > 0)
                if ((grp_stack[in_open] != cur_boundary) || (if_stack[in_open] != cond_ptr))
                    if (!((iname == 19) || (iname == 21))) {
                        /*tex Give warning for some unfinished groups and/or conditionals. */
                        file_warning();
                    }
            if ((iname > 21) || (iname == 20)) {
                report_stop_file();
                decr(open_parens);
            }
            force_eof = 0;
            /*tex \LUA\ input or |\scantextokens| */
            if (iname == 21 || iname == 19) {
                end_file_reading();
            } else {
                end_file_reading();
                if (! suppress_outer_error_par)
                    check_outer_validity();
            }
            return next_line_restart;
        } else {
            if (inhibit_eol || end_line_char_inactive)
                ilimit--;
            else
                iobuffer[ilimit] = (unsigned char) end_line_char_par;
            iofirst = ilimit + 1;
            iloc = istart;
            /*tex We're ready to read. */
        }
    } else if (!terminal_input) {
        /*tex |\read| line has ended */
        cur_cmd = 0;
        cur_chr = 0;
        return next_line_return;
    } else if (input_ptr > 0) {
        /*tex Text was inserted during error recovery. */
        end_file_reading();
        /*tex Resume previous level. */
        return next_line_restart;
    } else {
        if (selector < log_only)
            open_log_file();
        if (error_state.interaction > nonstop_mode) {
            if (end_line_char_inactive)
                ilimit++;
            if (ilimit == istart) {
                /*tex Previous line was empty. */
                tprint_nl("(Please type a command or say `\\end')");
            }
            print_ln();
            iofirst = istart;
            /*tex Input on-line into |buffer| */
            prompt_input("*");
            ilimit = iolast;
            if (end_line_char_inactive)
                ilimit--;
            else
                iobuffer[ilimit] = (unsigned char) end_line_char_par;
            iofirst = ilimit + 1;
            iloc = istart;
        } else {
            /*tex

                Nonstop mode, which is intended for overnight batch processing,
                never waits for on-line input.

            */
            fatal_error("*** (job aborted, no legal \\end found)");
        }
    }
    return next_line_ok;
}

/*tex

    Let's consider now what happens when |get_next| is looking at a token list.

*/

static int get_next_tokenlist(void)
{
    halfword t = token_info(iloc);
    /*tex Move to next. */
    iloc = token_link(iloc);
    if (t >= cs_token_flag) {
        /*tex A control sequence token */
        cur_cs = t - cs_token_flag;
        cur_cmd = eq_type(cur_cs);
        if (cur_cmd >= outer_call_cmd) {
            /*tex This branch is seldom entered. */
            if (cur_cmd == dont_expand_cmd) {
                /*tex

                    Get the next token, suppressing expansion. The present point
                    in the program is reached only when the |expand| routine has
                    inserted a special marker into the input. In this special
                    case, |token_info(iloc)| is known to be a control sequence
                    token, and |token_link(iloc)=null|.

                */
                cur_cs = token_info(iloc) - cs_token_flag;
                iloc = null;
                cur_cmd = eq_type(cur_cs);
                if (cur_cmd > max_command_cmd) {
                    cur_cmd = relax_cmd;
                    cur_chr = no_expand_flag;
                    return 1;
                }
            } else if (! suppress_outer_error_par) {
                check_outer_validity();
            }
        }
        cur_chr = equiv(cur_cs);
    } else {
        cur_cmd = token_cmd(t);
        cur_chr = token_chr(t);
        switch (cur_cmd) {
            case left_brace_cmd:
                align_state++;
                break;
            case right_brace_cmd:
                align_state--;
                break;
            case out_param_cmd:
                /*tex Insert macro parameter and |goto restart|. */
                begin_token_list(param_stack[param_start + cur_chr - 1], parameter);
                return 0;
                break;
        }
    }
    return 1;
}

/*tex

    Now we're ready to take the plunge into |get_next| itself. Parts of this
    routine are executed more often than any other instructions of \TEX.

    This sets |cur_cmd|, |cur_chr|, |cur_cs| to next token:

*/

void get_next(void)
{
  RESTART:
    cur_cs = 0;
    if (istate != token_list) {
        /*tex Input from external file, |goto restart| if no input found. */
        if (!get_next_file()) {
            goto RESTART;
        }
    } else if (iloc == null) {
        end_token_list();
        /*tex List exhausted, resume previous level. */
        goto RESTART;
    } else if (!get_next_tokenlist()) {
        /*tex Parameter needs to be expanded. */
        goto RESTART;
    } else if ((align_state == 0) && (cur_cmd == tab_mark_cmd || cur_cmd == car_ret_cmd)) {
        /*tex If an alignment entry has just ended, take appropriate action. */
        insert_vj_template();
        goto RESTART;
    }
}

/*tex

    Since |get_next| is used so frequently in \TEX, it is convenient to define
    three related procedures that do a little more:

    \startitemize
        \startitem
            |get_token| not only sets |cur_cmd| and |cur_chr|, it also sets
            |cur_tok|, a packed halfword version of the current token.
        \stopitem
        \startitem
            |get_x_token|, meaning \quote {get an expanded token}, is like
            |get_token|, but if the current token turns out to be a user-defined
            control sequence (i.e., a macro call), or a conditional, or something
            like |\topmark| or |\expandafter| or |\csname|, it is eliminated from
            the input by beginning the expansion of the macro or the evaluation
            of the conditional.
        \stopitem
        \startitem
            |x_token| is like |get_x_token| except that it assumes that
            |get_next| has already been called.
        \stopitem
    \stopitemize

    In fact, these three procedures account for almost every use of |get_next|.
    No new control sequences will be defined except during a call of |get_token|,
    or when |\csname| compresses a token list, because |no_new_control_sequence|
    is always |true| at other times.

    This sets |cur_cmd|, |cur_chr|, |cur_tok|:

*/

void get_token(void)
{
    no_new_control_sequence = 0;
    get_next();
    no_new_control_sequence = 1;
    if (cur_cs == 0)
        cur_tok = token_val(cur_cmd, cur_chr);
    else
        cur_tok = cs_token_flag + cur_cs;
}

/*tex This changes the string |s| to a token list. */

halfword string_to_toks(const char *ss)
{
    const char *s = ss;
    const char *se = ss + strlen(s);
    /*tex tail of the token list */
    halfword p = temp_token_head;
    /*tex new node being added to the token list via |store_new_token| */
    set_token_link(p, null);
    while (s < se) {
        halfword q;
        halfword t = (halfword) str2uni((const unsigned char *) s);
        s += utf8_size(t);
        if (t == ' ')
            t = space_token;
        else
            t = other_token + t;
        fast_store_new_token(t);
    }
    return token_link(temp_token_head);
}

/*tex

    The token lists for macros and for other things like |\mark| and |\output|
    and |\write| are produced by a procedure called |scan_toks|.

    Before we get into the details of |scan_toks|, let's consider a much simpler
    task, that of converting the current string into a token list. The |str_toks|
    function does this; it classifies spaces as type |spacer| and everything else
    as type |other_char|.

    The token list created by |str_toks| begins at |link(temp_token_head)| and
    ends at the value |p| that is returned. If |p = temp_token_head|, the list is
    empty.

    |lua_str_toks| is almost identical, but it also escapes the three symbols
    that |lua| considers special while scanning a literal string.

    This changes the string |str_pool[b .. pool_ptr]| to a token list:

*/

halfword lua_str_toks(lstring b)
{
    /*tex index into string */
    unsigned char *k = (unsigned char *) b.s;
    /*tex tail of the token list */
    halfword p = temp_token_head;
    set_token_link(p, null);
    while (k < (unsigned char *) b.s + b.l) {
        /*tex new node being added to the token list via |store_new_token| */
        halfword q;
        /*tex token being appended */
        halfword t = str2uni(k);
        k += utf8_size(t);
        if (t == ' ') {
            t = space_token;
        } else {
            if ((t == '\\') || (t == '"') || (t == '\'') || (t == 10) || (t == 13)) {
                fast_store_new_token(escape_token);
            }
            if (t == 10) {
                t = 'n';
            } else if (t == 13) {
                t = 'r';
            }
            t += other_token;
        }
        fast_store_new_token(t);
    }
    return p;
}

/*tex

    Incidentally, the main reason for wanting |str_toks| is the function
    |the_toks|, which has similar input/output characteristics.

    This changes the string |str_pool[b .. pool_ptr]| to a token list:

*/

halfword str_toks(lstring s)
{
    /*tex index into string */
    unsigned char *k = s.s;
    unsigned char *l = k + s.l;
    /*tex tail of the token list */
    halfword p = temp_token_head;
    set_token_link(p, null);
    while (k < l) {
        /*tex new node being added to the token list via |store_new_token| */
        halfword q;
        /*tex token being appended */
        halfword t = str2uni(k);
        if (t == ' ') {
            k += 1;
            t = space_token;
        } else {
            k += utf8_size(t);
            t = other_token + t;
        }
        fast_store_new_token(t);
    }
    return p;
}

/*tex

    Most of the converter is similar to the one I made for macro so at some point
    I can make a helper; also todo: there is no need to go through the pool.

*/

/*tex Change the string |str_pool[b..pool_ptr]| to a token list. */

halfword str_scan_toks(int ct, lstring s)
{
    /*tex index into string */
    unsigned char *k = s.s;
    unsigned char *l = k + s.l;
    /*tex tail of the token list */
    halfword p = temp_token_head;
    set_token_link(p, null);
    while (k < l) {
        int cc;
        /*tex new node being added to the token list via |store_new_token| */
        halfword q;
        /*tex token being appended */
        halfword t = str2uni(k);
        k += utf8_size(t);
        cc = get_cat_code(ct,t);
        if (cc == 0) {
            /*tex We have a potential control sequence so we check for it. */
            int _lname = 0 ;
            int _s = 0 ;
            int _c = 0 ;
            halfword _cs = null ;
            unsigned char *_name  = k ;
            while (k < l) {
                t = (halfword) str2uni((const unsigned char *) k);
                _s = utf8_size(t);
                _c = get_cat_code(ct,t);
                if (_c == 11) {
                    k += _s ;
                    _lname += _s ;
                } else if (_c == 10) {
                    /*tex We ignore a trailing space like normal scanning does. */
                    k += _s ;
                    break ;
                } else {
                    break ;
                }
            }
            if (_s > 0) {
                /*tex We have a potential |\cs|. */
                _cs = string_lookup((const char *) _name, _lname);
                if (_cs == undefined_control_sequence) {
                    /*tex Let's play safe and backtrack. */
                    t += cc * (1<<21);
                    k = _name ;
                } else {
                    t = cs_token_flag + _cs;
                }
            } else {
                /*tex
                    Just a character with some meaning, so |\unknown| becomes
                    effectively |\unknown| assuming that |\\| has some useful
                    meaning of course.
                */
                t += cc * (1<<21);
                k = _name ;
            }
        } else {
            /*tex
                Whatever token, so for instance $x^2$ just works given a \TEX\
                catcode regime.
            */
            t += cc * (1<<21);
        }
        fast_store_new_token(t);
    }
    return p;
}

/*tex

    Here's part of the |expand| subroutine that we are now ready to complete:

*/

void ins_the_toks(void)
{
    (void) the_toks();
    ins_list(token_link(temp_token_head));
}

# define set_toks_register(n,t,g) do { \
    int a = (g > 0) ? 4 : 0; \
    halfword ref; \
    fast_get_avail(ref); \
    set_token_ref_count(ref, 0); \
    set_token_link(ref, token_link(t)); \
    define(n + toks_base, call_cmd, ref); \
} while (0)

/*tex Here p and q are used scratch variables. */

# define append_copied_toks_list(s,t) do { \
    p = temp_token_head; \
    set_token_link(p, null); \
    while (s) { \
        fast_store_new_token(token_info(s)); \
        s = token_link(s); \
    } \
    while (t) { \
        fast_store_new_token(token_info(t)); \
        t = token_link(t); \
    } \
   } while (0)


/*tex

   \starttabulate[|T||T||]
   \NC 0 \NC \type {toksapp}   \NC 1 \NC \type {etoksapp} \NC \NR
   \NC 2 \NC \type {tokspre}   \NC 3 \NC \type {etokspre} \NC \NR
   \NC 4 \NC \type {gtoksapp}  \NC 5 \NC \type {xtoksapp} \NC \NR
   \NC 6 \NC \type {gtokspre}  \NC 7 \NC \type {xtokspre} \NC \NR
   \stoptabulate

*/

void combine_the_toks(int how)
{
    halfword source = null;
    halfword target = null;
    halfword append = (how == 0) || (how == 1) || (how == 4) || (how == 5);
    halfword expand = odd(how);
    halfword global = how > 3;
    halfword nt, ns, q; /* q is used in helper macros */
    get_x_token();
    /*tex The target. */
    if (cur_cmd == assign_toks_cmd) {
        /*tex Check range. */
        nt = equiv(cur_cs) - toks_base;
    } else {
        back_input();
        scan_register_num();
        nt = cur_val;
    }
    /*tex The source. */
    do {
        get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd == left_brace_cmd) {
        scan_toks(0,expand,1);
        source = def_ref;
        /*tex The action. */
        if (source != null) {
            target = toks(nt);
            if (target == null) {
                set_toks_register(nt,source,global);
                token_link(source) = null;
            } else {
                halfword s = token_link(source);
                if (s != null) {
                    halfword t = token_link(target);
                    if (t == null) {
                        /*tex Can this happen? */
                        set_token_link(target, s);
                        token_link(source) = null;
                    } else if (append) {
                        /*tex Append. */
                        if (token_ref_count(target) == 0) {
                            halfword p = t;
                            while (token_link(p) != null) {
                                p = token_link(p);
                            }
                            /*
                            while (s != null) {
                                fast_store_new_token(token_info(s));
                                s = token_link(s);
                            }
                            */
                            token_link(p) = s;
                            token_link(source) = null;
                        } else {
                            halfword p;
                            token_ref_count(target)--;
                            append_copied_toks_list(t,s);
                            set_toks_register(nt,temp_token_head,global);
                        }
                    } else {
                        /* prepend */
                        if (token_ref_count(target) == 0) {
                            /*
                            h = null;
                            p = null ;
                            while (s != null) {
                                fast_store_new_token(token_info(s));
                                if (h == null) {
                                    h = p;
                                }
                                s = token_link(s);
                            }
                            set_token_link(p,t);
                            set_token_link(target,h);
                            */
                            halfword p = s;
                            while (token_link(p) != null) {
                                p = token_link(p);
                            }
                            token_link(source) = null;
                            set_token_link(p,t);
                            set_token_link(target,s);
                        } else {
                            halfword p;
                            token_ref_count(target)--;
                            append_copied_toks_list(s,t);
                            set_toks_register(nt,temp_token_head,global);
                        }
                    }
                } else {
                }
            }
            flush_list(source);
        }
    } else {
        if (cur_cmd == assign_toks_cmd) {
            ns = equiv(cur_cs) - toks_base;
            /*tex Check range. */
        } else {
            scan_register_num();
            ns = cur_val;
        }
        /*tex The action. */
        source = toks(ns);
        if (source != null) {
            target = toks(nt);
            if (target == null) {
                /*tex The assign. */
                token_ref_count(source)++;
                equiv(toks_base+nt) = source;
                return;
            } else {
                halfword s = token_link(source);
                halfword t = token_link(target);
                if (append) {
                    /*tex Append. */
                    if (token_ref_count(target) == 0) {
                        halfword p = t;
                        while (token_link(p) != null) {
                            p = token_link(p);
                        }
                        while (s != null) {
                            fast_store_new_token(token_info(s));
                            s = token_link(s);
                        }
                    } else {
                        halfword p;
                        token_ref_count(target)--;
                        append_copied_toks_list(t,s);
                        set_toks_register(nt,temp_token_head,global);
                    }
                } else {
                    /*tex Prepend. */
                    if (token_ref_count(target) == 0) {
                        halfword h = null;
                        halfword p = null;
                        while (s != null) {
                            fast_store_new_token(token_info(s));
                            if (h == null) {
                                h = p;
                            }
                            s = token_link(s);
                        }
                        set_token_link(p,t);
                        set_token_link(target,h);
                    } else {
                        halfword p;
                        token_ref_count(target)--;
                        append_copied_toks_list(s,t);
                        set_toks_register(nt,temp_token_head,global);
                    }
                }
            }
        }
    }
}

/*tex

    This routine, used in the next one, prints the job name, possibly modified by
    the |process_jobname| callback.

*/

static void print_job_name(void)
{
    if (fileio_state.job_name != NULL) {
        /*tex \CCODE\ strings for jobname before and after processing. */
        char *s = fileio_state.job_name;
        int callback_id = callback_defined(process_jobname_callback);
        if (callback_id > 0) {
            char *ss;
            int lua_retval = run_callback(callback_id, "S->S", s, &ss);
            if (lua_retval && ss != NULL) {
                s = ss;
            }
        }
        tprint(s);
    }
}

/*tex

    The procedure |conv_toks| uses |str_toks| to insert the token list for
    |convert| functions into the scanner; |\outer| control sequences are
    allowed to follow |\string| and |\meaning|.

*/

# define push_selector { \
    old_setting = selector; \
    selector = new_string; \
}

# define pop_selector { \
    selector = old_setting; \
}

/*tex Codes not really needed but cleaner when testing */

void conv_toks(void)
{
    /*tex holds |selector| setting */
    int old_setting;
    /*tex desired type of conversion */
    int c = cur_chr;
    /*tex the result */
    str_number str;
    /*tex Scan the argument for command |c|. */
    switch (c) {
        case number_code:
            {
                scan_int(0);
                push_selector;
                print_int(cur_val);
                pop_selector;
            }
            break;
        case lua_function_code:
            {
                scan_int(0);
                if (cur_val <= 0) {
                    normal_error("luafunction", "invalid number");
                } else {
                    str_number u = save_cur_string();
                    luacstrings = 0;
                    luafunctioncall(cur_val);
                    restore_cur_string(u);
                    if (luacstrings > 0)
                        lua_string_start();
                }
                return;
            }
            break;
        case lua_bytecode_code:
            {
                scan_int(0);
                if (cur_val < 0 || cur_val > 65535) {
                    normal_error("luabytecode", "invalid number");
                } else {
                    str_number u = save_cur_string();
                    luacstrings = 0;
                    luabytecodecall(cur_val);
                    restore_cur_string(u);
                    if (luacstrings > 0)
                        lua_string_start();
                }
                return;
            }
            break;
        case lua_code:
            {
                str_number s;
                str_number u = save_cur_string();
                int save_scanner_status = scanner_status;
                halfword save_def_ref = def_ref;
                halfword save_warning_index = warning_index;
                scan_toks(0, 1, 0);
                s = def_ref;
                warning_index = save_warning_index;
                def_ref = save_def_ref;
                scanner_status = save_scanner_status;
                luacstrings = 0;
                luatokencall(s);
                delete_token_ref(s);
                restore_cur_string(u);
                if (luacstrings > 0)
                    lua_string_start();
                /*tex No further action. */
                return;
            }
            break;
        case expanded_code:
            {
                int save_scanner_status = scanner_status;
                halfword save_warning_index = warning_index;
                halfword save_def_ref = def_ref;
                str_number u = save_cur_string();
                scan_toks(0, 1, 0);
                warning_index = save_warning_index;
                scanner_status = save_scanner_status;
                ins_list(token_link(def_ref));
                def_ref = save_def_ref;
                restore_cur_string(u);
                /*tex No further action. */
                return;
            }
            break;
        case immediate_assignment_code:
        case immediate_assigned_code:
            {
                /*tex

                    This is on-the-road-to-bachotex brain-wave but it needs a bit
                    more testing. A first variant did more in sequence till a relax
                    of spacer was seen (like do_assignments). It permits for instance
                    setting counters in full expansion.

                */
                int save_scanner_status = scanner_status;
                halfword save_warning_index = warning_index;
                halfword save_def_ref = def_ref;
                str_number u = save_cur_string();
                do {
                    get_x_token();
                } while ((cur_cmd == spacer_cmd) || (cur_cmd == relax_cmd));
                if (c == immediate_assignment_code) {
                    /*tex one-step do_assignment */
                    if (cur_cmd > max_non_prefixed_command) {
                        error_state.set_box_allowed = 0;
                        prefixed_command();
                        error_state.set_box_allowed = 1;
                    }
                    /*tex done */
                } else {
                    /*tex pseudo token list do_assignment */
                    if (cur_cmd == left_brace_cmd) {
                        while (1) {
                            do {
                                get_x_token();
                            } while ((cur_cmd == spacer_cmd) || (cur_cmd == relax_cmd));
                            if (cur_cmd == right_brace_cmd) {
                                break;
                            } else {
                                error_state.set_box_allowed = 0;
                                prefixed_command();
                                error_state.set_box_allowed = 1;
                            }
                        }
                    }
                    /*tex done */
                }
                warning_index = save_warning_index;
                scanner_status = save_scanner_status;
                def_ref = save_def_ref;
                restore_cur_string(u);
                return;
            }
            break;
        case math_style_code:
            {
                push_selector;
                print_math_style();
                pop_selector;
            }
            break;
        case string_code:
            {
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                get_token();
                scanner_status = save_scanner_status;
                push_selector;
                if (cur_cs != 0)
                    sprint_cs(cur_cs);
                else
                    print(cur_chr);
                pop_selector;
            }
            break;
        case cs_string_code:
            {
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                get_token();
                scanner_status = save_scanner_status;
                push_selector;
                if (cur_cs != 0)
                    sprint_cs_name(cur_cs);
                else
                    print(cur_chr);
                pop_selector;
            }
            break;
        case roman_numeral_code:
            {
                scan_int(0);
                push_selector;
                print_roman_int(cur_val);
                pop_selector;
            }
            break;
        case meaning_code:
            {
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                get_token();
                scanner_status = save_scanner_status;
                push_selector;
                print_meaning();
                pop_selector;
            }
            break;
        case uchar_code:
            {
                scan_char_num();
                push_selector;
                print(cur_val);
                pop_selector;
            }
            break;
        case lua_escape_string_code:
            {
                lstring escstr;
                int l = 0;
                int e = in_lua_escape;
                int save_scanner_status = scanner_status;
                halfword save_def_ref = def_ref;
                halfword save_warning_index = warning_index;
                scan_toks(0, 1, 0);
                in_lua_escape = 1;
                escstr.s = (unsigned char *) tokenlist_to_cstring(def_ref, 0, &l);
                escstr.l = (unsigned) l;
                in_lua_escape = e;
                delete_token_ref(def_ref);
                def_ref = save_def_ref;
                warning_index = save_warning_index;
                scanner_status = save_scanner_status;
                (void) lua_str_toks(escstr);
                ins_list(token_link(temp_token_head));
                free(escstr.s);
                return;
            }
            break;
        case font_id_code:
            {
                scan_font_ident();
                push_selector;
                print_int(cur_val);
                pop_selector;
            }
            break;
        case font_name_code:
            {
                scan_font_ident();
                push_selector;
                append_string((unsigned char *) font_name(cur_val),(unsigned) strlen(font_name(cur_val)));
                if (font_size(cur_val) != font_dsize(cur_val)) {
                    tprint(" at ");
                    print_scaled(font_size(cur_val));
                    tprint("pt");
                }
                pop_selector;
            }
            break;
        case left_margin_kern_code:
            {
                halfword p;
                scan_int(0);
                if ((box(cur_val) == null) || (type(box(cur_val)) != hlist_node))
                    normal_error("marginkern", "a non-empty hbox expected");
                push_selector;
                p = list_ptr(box(cur_val));
                while ((p != null) && (type(p) == glue_node)) {
                    p = vlink(p);
                }
                if ((p != null) && (type(p) == margin_kern_node) && (subtype(p) == left_side))
                    print_scaled(width(p));
                else
                    print_char('0');
                tprint("pt");
                pop_selector;
            }
            break;
        case right_margin_kern_code:
            {
                halfword p, q;
                scan_int(0);
                if ((box(cur_val) == null) || (type(box(cur_val)) != hlist_node))
                    normal_error("marginkern", "a non-empty hbox expected");
                push_selector;
                p = list_ptr(box(cur_val));
                if (p != null) {
                    p = tail_of_list(p);
                    /*tex

                        There can be a leftskip, rightskip, penalty and yes, also a
                        disc node with a nesting node that points to glue spec ...
                        and we don't want to analyze that messy lot.

                    */
                    while ((p != null) && (type(p) == glue_node)) {
                        p = alink(p);
                    }
                    if ((p != null) && ! ((type(p) == margin_kern_node) && (subtype(p) == right_side))) {
                        if (type(p) == disc_node) {
                            q = alink(p);
                            if ((q != null) && ((type(q) == margin_kern_node) && (subtype(q) == right_side))) {
                                p = q;
                            } else {
                                /*tex

                                    Officially we should look in the replace but
                                    currently protrusion doesn't work anyway with
                                    |foo\discretionary{}{}{bar-} | (no following
                                    char) so we don't need it now.
                                */
                            }
                        }
                    }
                }
                if ((p != null) && (type(p) == margin_kern_node) && (subtype(p) == right_side))
                    print_scaled(width(p));
                else
                    print_char('0');
                tprint("pt");
                pop_selector;
            }
            break;
        case math_char_class_code:
            {
                mathcodeval mval;
                scan_int(0);
                mval = get_math_code(cur_val);
                push_selector;
                print_int(mval.class_value);
                pop_selector;
            }
            break;
        case math_char_fam_code:
            {
                mathcodeval mval;
                scan_int(0);
                mval = get_math_code(cur_val);
                push_selector;
                print_int(mval.family_value);
                pop_selector;
            }
            break;
        case math_char_slot_code:
            {
                mathcodeval mval;
                scan_int(0);
                mval = get_math_code(cur_val);
                push_selector;
                print_int(mval.character_value);
                pop_selector;
            }
            break;
        case insert_ht_code:
            {
                int i;
                halfword p;
                scan_register_num();
                push_selector;
                i = cur_val;
                p = page_ins_head;
                while (i >= subtype(vlink(p)))
                    p = vlink(p);
                if (subtype(p) == i)
                    print_scaled(height(p));
                else
                    print_char('0');
                tprint("pt");
                pop_selector;
            }
            break;
        case job_name_code:
            {
                if (fileio_state.job_name == NULL)
                    open_log_file();
                push_selector;
                print_job_name();
                pop_selector;
            }
            break;
        case format_name_code:
            {
                if (fileio_state.job_name == NULL)
                    open_log_file();
                push_selector;
                print(dump_state.format_name);
                pop_selector;
            }
            break;
        case luatex_banner_code:
            {
                push_selector;
                tprint(engine_state.luatex_banner);
                pop_selector;
            }
            break;
        case luatex_revision_code:
            {
                push_selector;
                print(version_state.revision);
                pop_selector;
            }
            break;
        case etex_code:
            {
                push_selector;
                tprint(eTeX_version_string);
                pop_selector;
            }
            break;
        case eTeX_revision_code:
            {
                push_selector;
                tprint(eTeX_revision);
                pop_selector;
            }
            break;
        /*
        case font_identifier_code:
            confusion("convert");
            break;
        */
        default:
            confusion("convert");
            break;
    }
    str = make_string();
    (void) str_toks(str_lstring(str));
    flush_str(str);
    ins_list(token_link(temp_token_head));
}

/*tex
    The boolean |in_lua_escape| is keeping track of the lua string escape state.
*/


str_number the_convert_string(halfword c, int i)
{
    int old_setting = selector;
    str_number ret = 0;
    int done = 1 ;
    selector = new_string;
    switch (c) {
        case number_code:
            print_int(i);
            break;
     /* case lua_function_code: */
     /* case lua_code: */
     /* case expanded_code: */
        case math_style_code:
            print_math_style();
            break;
     /* case string_code: */
     /* case cs_string_code: */
        case roman_numeral_code:
            print_roman_int(i);
            break;
     /* case meaning_code: */
        case uchar_code:
            print(i);
            break;
     /* lua_escape_string_code: */
        case font_id_code:
            print_int(i);
            break;
        case font_name_code:
            append_string((unsigned char *) font_name(i),(unsigned) strlen(font_name(i)));
            if (font_size(i) != font_dsize(i)) {
                tprint(" at ");
                print_scaled(font_size(i));
                tprint("pt");
            }
            break;
     /* left_margin_kern_code: */
     /* right_margin_kern_code: */
     /* math_char_class_code: */
     /* math_char_fam_code: */
     /* math_char_slot_code: */
     /* insert_ht_code: */
        case job_name_code:
            print_job_name();
            break;
        case format_name_code:
            print(dump_state.format_name);
            break;
        case luatex_banner_code:
            tprint(engine_state.luatex_banner);
            break;
        case luatex_revision_code:
            print(version_state.revision);
            break;
        case etex_code:
            tprint(eTeX_version_string);
            break;
        case eTeX_revision_code:
            tprint(eTeX_revision);
            break;
        case font_identifier_code:
            print_font_identifier(i);
            break;
        default:
            done = 0;
            break;
    }
    if (done) {
        ret = make_string();
    }
    selector = old_setting;
    return ret;
}

/*tex

    Another way to create a token list is via the |\read| command. The sixteen
    files potentially usable for reading appear in the following global
    variables. The value of |read_open[n]| will be |closed| if stream number |n|
    has not been opened or if it has been fully read; |just_open| if an
    |\openin| but not a \|\read| has been done; and |normal| if it is open
    and ready to read the next line.

    The arrays |read_file| and |read_open| keep track of the state if the read
    channels.

*/

void initialize_read(void)
{
    int k;
    for (k = 0; k <= 16; k++)
        read_open[k] = closed;
}

/*tex

    The |read_toks| procedure constructs a token list like that for any macro
    definition, and makes |cur_val| point to it. Parameter |r| points to the
    control sequence that will receive this token list.

*/

void read_toks(int n, halfword r, halfword j)
{
    /*tex tail of the token list */
    halfword p;
    /*tex new node being added to the token list via |store_new_token| */
    halfword q;
    /*tex saved value of |align_state| */
    int s;
    /*tex stream number */
    int m;
    scanner_status = defining;
    warning_index = r;
    fast_get_avail(p);
    def_ref = p;
    set_token_ref_count(def_ref, 0);
    /*tex the reference count */
 /* p = def_ref; */
    store_new_token(end_match_token);
    if ((n < 0) || (n > 15))
        m = 16;
    else
        m = n;
    s = align_state;
    /*tex disable tab marks, etc. */
    align_state = 1000000;
    do {
        /*tex Input and store tokens from the next line of the file. */
        begin_file_reading();
        iname = m + 1;
        if (read_open[m] == closed) {
            /*tex

                Input for |\read| from the terminal. We input on-line into the
                |buffer| array, prompting the user explicitly if |n>=0|. The
                value of |n| is set negative so that additional prompts will not
                be given in the case of multi-line input.

            */
            if (error_state.interaction > nonstop_mode) {
                if (n < 0) {
                    prompt_input("");
                } else {
                    wake_up_terminal();
                    print_ln();
                    sprint_cs(r);
                    prompt_input(" =");
                    n = -1;
                }
            } else {
                fatal_error
                    ("*** (cannot \\read from terminal in nonstop modes)");
            }
        } else if (read_open[m] == just_open) {
            /*tex

                Input the first line of |read_file[m]|. The first line of a file
                must be treated specially, since |lua_input_ln| must be told not
                to start with |get|.

            */
            if (lua_input_ln(read_file[m], (m + 1))) {
                read_open[m] = normal;
            } else {
                lua_a_close_in(read_file[m], (m + 1));
                read_open[m] = closed;
            }
        } else {
            /*tex

                Input the next line of |read_file[m]|. An empty line is appended
                at the end of a |read_file|.

            */
            if (!lua_input_ln(read_file[m], (m + 1))) {
                lua_a_close_in(read_file[m], (m + 1));
                read_open[m] = closed;
                if (align_state != 1000000) {
                    runaway();
                    print_err("File ended within \\read");
                    help(
                        "This \\read has unbalanced braces."
                    );
                    align_state = 1000000;
                    error();
                }
            }
        }
        ilimit = iolast;
        if (end_line_char_inactive)
            decr(ilimit);
        else
            iobuffer[ilimit] = (unsigned char) end_line_char_par;
        iofirst = ilimit + 1;
        iloc = istart;
        istate = new_line;
        /*tex Handle |\readline| and |goto done|. */
        if (j == 1) {
            while (iloc <= ilimit) {
                /*tex Current line not yet finished. */
                do_buffer_to_unichar(cur_chr, iloc);
                if (cur_chr == ' ')
                    cur_tok = space_token;
                else
                    cur_tok = cur_chr + other_token;
                store_new_token(cur_tok);
            }
        } else {
            while (1) {
                get_token();
                if (cur_tok == 0) {
                    /*tex |cur_cmd=cur_chr=0| will occur at the end of the line. */
                    break;
                } else if (align_state < 1000000) {
                    /*tex Unmatched right brace aborts the line. */
                    do {
                        get_token();
                    } while (cur_tok != 0);
                    align_state = 1000000;
                    break;
                }
                store_new_token(cur_tok);
            }
        }
        end_file_reading();
    } while (align_state != 1000000);
    cur_val = def_ref;
    scanner_status = normal;
    align_state = s;
}

/*tex Return a string from tokens list: */

str_number tokens_to_string(halfword p)
{
    int old_setting;
    if (selector == new_string)
        normal_error("tokens","tokens_to_string() called while selector = new_string");
    old_setting = selector;
    selector = new_string;
    show_token_list(token_link(p), null, -1);
    selector = old_setting;
    return make_string();
}

/*tex

    Values like 512 and 128 also work ok. There is not much to gain in
    optimization here.

*/

/*       alloci_default 1024 */
/*       alloci_step     256 */
# define alloci_default  256
# define alloci_step    2048 /* likely a large directlua */

# define make_room(a) \
    if ((unsigned)i+a+1>alloci) { \
        ret = realloc(ret,(alloci+alloci_step)); \
        alloci = alloci + alloci_step; \
    }

# define append_i_byte(a) ret[i++] = (char)(a)

# define Print_char(a) make_room(1); append_i_byte(a)

/* todo: use macro from unistring */

# define Print_uchar(s) { \
    make_room(4); \
    if (s<=0x7F) { \
        append_i_byte(s); \
    } else if (s<=0x7FF) { \
        append_i_byte(0xC0 + (s / 0x40)); \
        append_i_byte(0x80 + (s % 0x40)); \
    } else if (s<=0xFFFF) { \
        append_i_byte(0xE0 + (s / 0x1000)); \
        append_i_byte(0x80 + ((s % 0x1000) / 0x40)); \
        append_i_byte(0x80 + ((s % 0x1000) % 0x40)); \
    } else if (s>=0x110000) { \
        append_i_byte(s-0x11000); \
    } else { \
        append_i_byte(0xF0 + (s / 0x40000)); \
        append_i_byte(0x80 + ((s % 0x40000) / 0x1000)); \
        append_i_byte(0x80 + (((s % 0x40000) % 0x1000) / 0x40)); \
        append_i_byte(0x80 + (((s % 0x40000) % 0x1000) % 0x40)); \
    } \
}

# define Print_esc(b) { \
    const char *v = b; \
    if (e > 0 && e < STRING_OFFSET) { \
        Print_uchar (e); \
    } \
    make_room(strlen(v)); \
    while (*v) { append_i_byte(*v); v++; } \
}

# define Print_str(b) { \
    const char *v = b; \
    make_room(strlen(v)); \
    while (*v) { append_i_byte(*v); v++; } \
}

# define is_cat_letter(a) \
    (the_cat_code(str2uni(str_string((a)))) == 11)

/*tex

    The actual token conversion in this function is now functionally equivalent
    to |show_token_list|, except that it always prints the whole token list.

*/

char *tokenlist_to_cstring(int pp, int inhibit_par, int *siz)
{
    if (pp) {
        int i = 0;
        unsigned alloci = alloci_default;
        char *ret = malloc(alloci);
        int p = token_link(pp);       /*tex Skip refcount. */;
        if (p) {
            int e = escape_char_par;  /*tex The serialization of the escape, normally a backlash. */
            int match_chr = '#';      /*tex Changes according to |match_cmd|. */
            int n = '0';              /*tex The character after |#|, so |#0| upto |#9| */
            while (p) {
                if (p < (int) fixed_memory_state.fix_mem_min || p > (int) fixed_memory_state.fix_mem_end) {
                    Print_esc("CLOBBERED.");
                    break;
                } else {
                    int infop = token_info(p);
                    if (infop < cs_token_flag && infop >= 0) {
                        int m = token_cmd(infop);
                        int c = token_chr(infop);
                        switch (m) {
                            case left_brace_cmd:
                            case right_brace_cmd:
                            case math_shift_cmd:
                            case tab_mark_cmd:
                            case sup_mark_cmd:
                            case sub_mark_cmd:
                            case spacer_cmd:
                            case letter_cmd:
                            case other_char_cmd:
                                Print_uchar(c);
                                break;
                            case mac_param_cmd:
                                if (!in_lua_escape && (expand_state.is_in_csname == 0))
                                    Print_uchar(c);
                                Print_uchar(c);
                                break;
                            case out_param_cmd:
                                Print_uchar(match_chr);
                                if (c <= 9) {
                                    Print_char(c + '0');
                                } else {
                                    Print_char('!');
                                    goto EXIT;
                                }
                                break;
                            case match_cmd:
                                match_chr = c;
                                Print_uchar(c);
                                n++;
                                Print_char(n);
                                if (n > '9')
                                    goto EXIT;
                                break;
                            case end_match_cmd:
                                if (c == 0) {
                                    Print_char('-');
                                    Print_char('>');
                                }
                                break;
                            default:
                                not_so_bad(Print_esc);
                                break;
                        }
                    } else if (infop < 0) {
                        Print_esc("BAD");
                    } else if (!(inhibit_par && infop == par_token)) {
                        int q = infop - cs_token_flag;
                        if (q < hash_base) {
                            if (q == null_cs) {
                                Print_esc("csname");
                                Print_esc("endcsname");
                            } else {
                                Print_esc("IMPOSSIBLE.");
                            }
                        } else if ((q >= undefined_control_sequence) && ((q <= eqtb_size) || (q > eqtb_size + hash_state.hash_extra))) {
                            Print_esc("IMPOSSIBLE.");
                        } else if ((cs_text(q) < 0) || (cs_text(q) >= string_pool_state.str_ptr)) {
                            Print_esc("NONEXISTENT.");
                        } else {
                            str_number txt = cs_text(q);
                            char *sh = makecstring(txt);
                            char *s = sh;
                            if (is_active_cs(txt)) {
                                s = s + 3;
                                while (*s) {
                                    Print_char(*s);
                                    s++;
                                }
                            } else {
                                if (e>=0 && e<0x110000) {
                                    Print_uchar(e);
                                }
                                while (*s) {
                                    Print_char(*s);
                                    s++;
                                }
                                if ((!single_letter(txt)) || is_cat_letter(txt)) {
                                    Print_char(' ');
                                }
                            }
                            free(sh);
                        }
                    }
                    p = token_link(p);
                }
            }
        }
      EXIT:
        ret[i] = '\0';
        if (siz != NULL) {
            *siz = i;
        }
        return ret;
    } else {
        if (siz != NULL) {
            *siz = 0;
        }
        return NULL;
    }
}

/*
    Reuse might matter a bit on small machines, but beware, the above is used for patterns and the
    next only for csnames and such. It will go away when ot useful. On the manual we're talking of
    more than a million allocations. We can check for a large value and realloc to a smaller one
    or we can make a nice wrapper that does that.
*/

char *_ret = NULL;
unsigned _alloci = 0;

char *tokenlist_to_tstring(int pp, int inhibit_par, int *siz)
{
    if (pp) {
        int i = 0;

unsigned alloci = _alloci;
char *ret = _ret;
int p = token_link(pp);

        if (p) {
            int e = escape_char_par;  /*tex The serialization of the escape, normally a backlash. */
            int match_chr = '#';      /*tex Changes according to |match_cmd|. */
            int n = '0';              /*tex The character after |#|, so |#0| upto |#9| */

if (alloci > alloci_default) {
 // printf("reduce %i: %s\n",alloci,ret); /* most likely a large directlua */
    free(ret);
    alloci = 0;
}
if (!alloci) {
 // printf("allocate %i\n",alloci_default);
    ret = malloc(alloci_default);
    alloci = alloci_default;
}

            while (p) {
                if (p < (int) fixed_memory_state.fix_mem_min || p > (int) fixed_memory_state.fix_mem_end) {
                    Print_esc("CLOBBERED.");
                    break;
                } else {
                    int infop = token_info(p);
                    if (infop < cs_token_flag && infop >= 0) {
                        int m = token_cmd(infop);
                        int c = token_chr(infop);
                        switch (m) {
                            case left_brace_cmd:
                            case right_brace_cmd:
                            case math_shift_cmd:
                            case tab_mark_cmd:
                            case sup_mark_cmd:
                            case sub_mark_cmd:
                            case spacer_cmd:
                            case letter_cmd:
                            case other_char_cmd:
                                Print_uchar(c);
                                break;
                            case mac_param_cmd:
                                if (!in_lua_escape && (expand_state.is_in_csname == 0))
                                    Print_uchar(c);
                                Print_uchar(c);
                                break;
                            case out_param_cmd:
                                Print_uchar(match_chr);
                                if (c <= 9) {
                                    Print_char(c + '0');
                                } else {
                                    Print_char('!');
                                    goto EXIT;
                                }
                                break;
                            case match_cmd:
                                match_chr = c;
                                Print_uchar(c);
                                n++;
                                Print_char(n);
                                if (n > '9')
                                    goto EXIT;
                                break;
                            case end_match_cmd:
                                if (c == 0) {
                                    Print_char('-');
                                    Print_char('>');
                                }
                                break;
                            default:
                                not_so_bad(Print_esc);
                                break;
                        }
                    } else if (infop < 0) {
                        Print_esc("BAD");
                    } else if (!(inhibit_par && infop == par_token)) {
                        int q = infop - cs_token_flag;
                        if (q < hash_base) {
                            if (q == null_cs) {
                                Print_esc("csname");
                                Print_esc("endcsname");
                            } else {
                                Print_esc("IMPOSSIBLE.");
                            }
                        } else if ((q >= undefined_control_sequence) && ((q <= eqtb_size) || (q > eqtb_size + hash_state.hash_extra))) {
                            Print_esc("IMPOSSIBLE.");
                        } else if ((cs_text(q) < 0) || (cs_text(q) >= string_pool_state.str_ptr)) {
                            Print_esc("NONEXISTENT.");
                        } else {
                            str_number txt = cs_text(q);
                            char *sh = makecstring(txt);
                            char *s = sh;
                            if (is_active_cs(txt)) {
                                s = s + 3;
                                while (*s) {
                                    Print_char(*s);
                                    s++;
                                }
                            } else {
                                if (e>=0 && e<0x110000) {
                                    Print_uchar(e);
                                }
                                while (*s) {
                                    Print_char(*s);
                                    s++;
                                }
                                if ((!single_letter(txt)) || is_cat_letter(txt)) {
                                    Print_char(' ');
                                }
                            }
                            free(sh);
                        }
                    }
                    p = token_link(p);
                }
            }
        }
      EXIT:
        ret[i] = '\0';
        if (siz != NULL) {
            *siz = i;
        }

_alloci = alloci;
_ret = ret;

        return ret;
    } else {
        if (siz != NULL) {
            *siz = 0;
        }
        return NULL;
    }
}

/* todo: like the above */

char *tokenlist_to_xstring(int pp, int inhibit_par, int *siz)
{
    if (pp == null) {
        if (siz != NULL)
            *siz = 0;
        return NULL;
    } else {
        /*tex Skip refcount. */
        int p = token_link(pp);
        unsigned alloci = alloci_default;
        char *ret = malloc(alloci);
        int i = 0;
        if (p) {
            int match_chr = '#';
            int n = '0';
            int skip = 1;
            int e = escape_char_par;
            while (p) {
                if (p < (int) fixed_memory_state.fix_mem_min || p > (int) fixed_memory_state.fix_mem_end) {
                    /*tex Nothing done. */
                    break;
                } else {
                    int infop = token_info(p);
                    if (infop >= cs_token_flag) {
                        if (!(inhibit_par && infop == par_token)) {
                            int q = infop - cs_token_flag;
                            if (q < hash_base) {
                                /*tex Nothing done. */
                            } else if ((q >= undefined_control_sequence) && ((q <= eqtb_size) || (q > eqtb_size + hash_state.hash_extra))) {
                                /*tex Nothing done. */
                            } else if ((cs_text(q) < 0) || (cs_text(q) >= string_pool_state.str_ptr)) {
                                /*tex Nothing done. */
                            } else if (!skip) {
                                str_number txt = cs_text(q);
                                char *sh = makecstring(txt);
                                char *s = sh;
                                if (is_active_cs(txt)) {
                                    s = s + 3;
                                    while (*s) {
                                        Print_char(*s);
                                        s++;
                                    }
                                } else {
                                    if (e>=0 && e<0x110000) Print_uchar(e);
                                    while (*s) {
                                        Print_char(*s);
                                        s++;
                                    }
                                    if ((!single_letter(txt)) || is_cat_letter(txt)) {
                                        Print_char(' ');
                                    }
                                }
                                free(sh);
                            }
                        }
                    } else if (infop < 0) {
                        /*tex Nothing done. */
                    } else {
                        int m = token_cmd(infop);
                        int c = token_chr(infop);
                        switch (m) {
                            case left_brace_cmd:
                            case right_brace_cmd:
                            case math_shift_cmd:
                            case tab_mark_cmd:
                            case sup_mark_cmd:
                            case sub_mark_cmd:
                            case spacer_cmd:
                            case letter_cmd:
                            case other_char_cmd:
                                if (!skip) {
                                    Print_uchar(c);
                                }
                                break;
                           case mac_param_cmd:
                                if (!skip) {
                                    if (!in_lua_escape && (expand_state.is_in_csname == 0))
                                        Print_uchar(c);
                                    Print_uchar(c);
                                }
                                break;
                            case out_param_cmd:
                                if (!skip) {
                                    Print_uchar(match_chr);
                                }
                                if (c <= 9) {
                                    if (!skip) {
                                        Print_char(c + '0');
                                    }
                                } else {
                                    /*tex Nothing done. */
                                    goto EXIT;
                                }
                                break;
                            case match_cmd:
                                match_chr = c;
                                if (!skip) {
                                    Print_uchar(c);
                                }
                                n++;
                                if (!skip) {
                                    Print_char(n);
                                }
                                if (n > '9')
                                    goto EXIT;
                                break;
                            case end_match_cmd:
                                if (c == 0) {
                                    if (!skip) {
                                        Print_char('-');
                                        Print_char('>');
                                    }
                                    i = 0;
                                    skip = 0 ;
                                }
                                break;
                            default:
                                /*tex Nothing done. */
                                break;
                        }
                    }
                    p = token_link(p);
                }
            }
        }
      EXIT:
        ret[i] = '\0';
        if (siz != NULL)
            *siz = i;
        return ret;
    }
}
