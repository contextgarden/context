/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

# define mode mode_par
# define tail tail_par
# define head head_par

/*tex

    The program above includes a bunch of \quote {hooks} that allow further
    capabilities to be added without upsetting \TEX's basic structure. Most of
    these hooks are concerned with \quote {whatsit} nodes, which are intended to be
    used for special purposes; whenever a new extension to \TEX\ involves a new
    kind of whatsit node, a corresponding change needs to be made to the routines
    below that deal with such nodes, but it will usually be unnecessary to make
    many changes to the other parts of this program.

    In order to demonstrate how extensions can be made, we shall treat |\write|,
    |\openout|, |\closeout|, |\immediate|, and |\special| as if they were
    extensions. These commands are actually primitives of \TEX, and they should
    appear in all implementations of the system; but let's try to imagine that
    they aren't. Then the program below illustrates how a person could add them.

    Sometimes, of course, an extension will require changes to \TEX\ itself; no
    system of hooks could be complete enough for all conceivable extensions. The
    features associated with |\write| are almost all confined to the following
    paragraphs, but there are small parts of the |print_ln| and |print_char|
    procedures that were introduced specifically to |\write| characters.
    Furthermore one of the token lists recognized by the scanner is a
    |write_text|; and there are a few other miscellaneous places where we have
    already provided for some aspect of |\write|. The goal of a \TeX\ extender
    should be to minimize alterations to the standard parts of the program, and
    to avoid them completely if possible. He or she should also be quite sure
    that there's no easy way to accomplish the desired goals with the standard
    features that \TEX\ already has. \quote {Think thrice before extending},
    because that may save a lot of work, and it will also keep incompatible
    extensions of \TEX\ from proliferating.

    First let's consider the format of whatsit nodes that are used to represent
    the data associated with |\write| and its relatives. Recall that a whatsit
    has |type=whatsit_node|, and the |subtype| is supposed to distinguish
    different kinds of whatsits. Each node occupies two or more words; the exact
    number is immaterial, as long as it is readily determined from the |subtype|
    or other data.

    We shall introduce five |subtype| values here, corresponding to the control
    sequences |\openout|, |\write|, |\closeout|, and |\special|. The second word
    of I/O whatsits has a |write_stream| field that identifies the write-stream
    number (0 to 15, or 16 for out-of-range and positive, or 17 for out-of-range
    and negative). In the case of |\write| and |\special|, there is also a field
    that points to the reference count of a token list that should be sent. In
    the case of |\openout|, we need three words and three auxiliary subfields to
    hold the string numbers for name, area, and extension.

    Extensions might introduce new command codes; but it's best to use
    |extension| with a modifier, whenever possible, so that |main_control| stays
    the same.

    The sixteen possible |\write| streams are represented by the |write_file|
    array. The |j|th file is open if and only if |write_open[j]=true|. The last
    two streams are special; |write_open[16]| represents a stream number greater
    than 15, while |write_open[17]| represents a negative stream number, and both
    of these variables are always |false|.

    Writing to files is delegated to \LUA, so we have no write channels.

    To write a token list, we must run it through \TEX's scanner, expanding
    macros and |\the| and |\number|, etc. This might cause runaways, if a
    delimited macro parameter isn't matched, and runaways would be extremely
    confusing since we are calling on \TEX's scanner in the middle of a
    |\shipout| command. Therefore we will put a dummy control sequence as a
    \quote {stopper}, right after the token list. This control sequence is
    artificially defined to be |\outer|.

    The presence of |\immediate| causes the |do_extension| procedure to descend
    to one level of recursion. Nothing happens unless |\immediate| is followed by
    |\openout|, |\write|, or |\closeout|.

    Here is a subroutine that creates a whatsit node having a given |subtype| and
    a given number of words. It initializes only the first word of the whatsit,
    and appends it to the current list.

*/

void new_whatsit(halfword s)
{
    halfword p = new_node(whatsit_node, s);
    couple_nodes(tail, p);
    tail = p;
}

/*tex

    The final line of this routine is slightly subtle; at least, the author
    didn't think about it until getting burnt! There is a used-up token list on
    the stack, namely the one that contained |end_write_token|. (We insert this
    artificial |\endwrite| to prevent runaways, as explained above.) If it
    were not removed, and if there were numerous writes on a single page, the
    stack would overflow.

*/

void expand_macros_in_tokenlist(halfword p)
{
    int old_mode;
    halfword q = get_avail();
    halfword r = get_avail();
    token_info(q) = right_brace_token + '}';
    token_link(q) = r;
    token_info(r) = end_write_token;
    begin_token_list(q, inserted);
    begin_token_list(p, write_text);
    q = get_avail();
    token_info(q) = left_brace_token + '{';
    begin_token_list(q, inserted);
    /*tex Now we're ready to scan |{<token list>}| |\endwrite|. */
    old_mode = mode;
    mode = 0;
    /*tex Disable |\prevdepth|, |\spacefactor|, |\lastskip|, |\prevgraf|. */
    cur_cs = 0; /* was write_loc i.e. eq of \write */
    /*tex Expand macros, etc. */
    q = scan_toks(0, 1, 0);
    get_token();
    if (cur_tok != end_write_token) {
        /*tex Recover from an unbalanced write command */
        tex_error(
            "Unbalanced token list expansion",
            "On this page there's a token list expansion with fewer real\n"
            "{'s than }'s. I can't handle that very well; good luck."
        );
        do {
            get_token();
        } while (cur_tok != end_write_token);
    }
    mode = old_mode;
    /*tex Conserve stack space. */
    end_token_list();
}

/*tex

    The \ETEX\ features available in extended mode are grouped into two
    categories: (1)~Some of them are permanently enabled and have no semantic
    effect as long as none of the additional primitives are executed. (2)~The
    remaining \ETEX\ features are optional and can be individually enabled and
    disabled. For each optional feature there is an \ETEX\ state variable named
    |\...state|; the feature is enabled, resp.\ disabled by assigning a
    positive, resp.\ non-positive value to that integer.

    In order to handle |\everyeof| we need an array |eof_seen| of boolean
    variables.

    The |print_group| procedure prints the current level of grouping and the name
    corresponding to |cur_group|.

*/

void print_group(int e)
{
    switch (cur_group) {
        case bottom_level:
            tprint("bottom level");
            return;
            break;
        case simple_group:
        case semi_simple_group:
            if (cur_group == semi_simple_group)
                tprint("semi ");
            tprint("simple");
            break;;
        case hbox_group:
        case adjusted_hbox_group:
            if (cur_group == adjusted_hbox_group)
                tprint("adjusted ");
            tprint("hbox");
            break;
        case vbox_group:
            tprint("vbox");
            break;
        case vtop_group:
            tprint("vtop");
            break;
        case align_group:
        case no_align_group:
            if (cur_group == no_align_group)
                tprint("no ");
            tprint("align");
            break;
        case output_group:
            tprint("output");
            break;
        case disc_group:
            tprint("disc");
            break;
        case insert_group:
            tprint("insert");
            break;
        case vcenter_group:
            tprint("vcenter");
            break;
        case math_group:
        case math_choice_group:
        case math_shift_group:
        case math_left_group:
            tprint("math");
            if (cur_group == math_choice_group)
                tprint(" choice");
            else if (cur_group == math_shift_group)
                tprint(" shift");
            else if (cur_group == math_left_group)
                tprint(" left");
            break;
    }
    tprint(" group (level ");
    print_int(cur_level);
    print_char(')');
    if (saved_value(-1) != 0) {
        /*tex |saved_line| */
        if (e)
            tprint(" entered at line ");
        else
            tprint(" at line ");
        print_int(saved_value(-1));
    }
}

/*tex

    The |group_trace| procedure is called when a new level of grouping begins
    (|e=false|) or ends (|e=truetrue|) with |saved_value(-1)| containing the line
    number.

*/

void group_trace(int e)
{
    begin_diagnostic();
    print_char('{');
    if (e)
        tprint("leaving ");
    else
        tprint("entering ");
    print_group(e);
    print_char('}');
    end_diagnostic(0);
}

/*tex

    A group entered (or a conditional started) in one file may end in a different
    file. Such slight anomalies, although perfectly legitimate, may cause errors
    that are difficult to locate. In order to be able to give a warning message
    when such anomalies occur, \ETEX\ uses the |grp_stack| and |if_stack| arrays
    to record the initial |cur_boundary| and |cond_ptr| values for each input
    file.

    When a group ends that was apparently entered in a different input file, the
    |group_warning| procedure is invoked in order to update the |grp_stack|. If
    moreover |\tracingnesting| is positive we want to give a warning message. The
    situation is, however, somewhat complicated by two facts: (1)~There may be
    |grp_stack| elements without a corresponding |\input| file or |\scantokens|
    pseudo file (e.g., error insertions from the terminal); and (2)~the relevant
    information is recorded in the |name_field| of the |input_stack| only loosely
    synchronized with the |in_open| variable indexing |grp_stack|.

*/

void group_warning(void)
{
    /*tex do we need a warning? */
    int w = 0;
    /*tex index into |grp_stack| */
    int i = in_open;
    base_ptr = input_ptr;
    /*tex store current state */
    input_stack[base_ptr] = cur_input;
    while ((grp_stack[i] == cur_boundary) && (i > 0)) {
        /*tex

            Set variable |w| to indicate if this case should be reported. This
            code scans the input stack in order to determine the type of the
            current input file.

        */
        if (tracing_nesting_par > 0) {
            while ((input_stack[base_ptr].state_field == token_list) || (input_stack[base_ptr].index_field > i))
                decr(base_ptr);
            if (input_stack[base_ptr].name_field > 17)
                w = 1;
        }
        grp_stack[i] = save_value(save_ptr);
        decr(i);
    }
    if (w) {
        tprint_nl("Warning: end of ");
        print_group(1);
        tprint(" of a different file");
        print_ln();
        if (tracing_nesting_par > 1)
            show_context();
        if (error_state.history == spotless)
            error_state.history = warning_issued;
    }
}

/*tex

    When a conditional ends that was apparently started in a different input
    file, the |if_warning| procedure is invoked in order to update the
    |if_stack|. If moreover |\tracingnesting| is positive we want to give a
    warning message (with the same complications as above).

*/

void if_warning(void)
{
    /*tex Do we need a warning? */
    int w = 0;
    int i = in_open;
    base_ptr = input_ptr;
    /*tex Store current state. */
    input_stack[base_ptr] = cur_input;
    while (if_stack[i] == cond_ptr) {
        /*tex Set variable |w| to. */
        if (tracing_nesting_par > 0) {
            while ((input_stack[base_ptr].state_field == token_list) || (input_stack[base_ptr].index_field > i))
                decr(base_ptr);
            if (input_stack[base_ptr].name_field > 17)
                w = 1;
        }
        if_stack[i] = vlink(cond_ptr);
        decr(i);
    }
    if (w) {
        tprint_nl("Warning: end of ");
        print_cmd_chr(if_test_cmd, cur_if);
        print_if_line(if_line);
        tprint(" of a different file");
        print_ln();
        if (tracing_nesting_par > 1)
            show_context();
        if (error_state.history == spotless)
            error_state.history = warning_issued;
    }
}

/*tex

    Conversely, the |file_warning| procedure is invoked when a file ends and some
    groups entered or conditionals started while reading from that file are still
    incomplete.

*/

void file_warning(void)
{
    /*tex saved value of |save_ptr| or |cond_ptr| */
    halfword p = save_ptr;
    /*tex saved value of |cur_level| or |if_limit| */
    int l = cur_level;
    /*tex saved value of |cur_group| or |cur_if| */
    int c = cur_group;
    /*tex saved value of |if_line| */
    int i;
    save_ptr = cur_boundary;
    while (grp_stack[in_open] != save_ptr) {
        decr(cur_level);
        tprint_nl("Warning: end of file when ");
        print_group(1);
        tprint(" is incomplete");
        cur_group = save_level(save_ptr);
        save_ptr = save_value(save_ptr);
    }
    save_ptr = p;
    cur_level = (quarterword) l;
    /*tex Restore old values. */
    cur_group = (group_code) c;
    p = cond_ptr;
    l = if_limit;
    c = cur_if;
    i = if_line;
    while (if_stack[in_open] != cond_ptr) {
        tprint_nl("Warning: end of file when ");
        print_cmd_chr(if_test_cmd, cur_if);
        if (if_limit == fi_code)
            tprint_esc("else");
        print_if_line(if_line);
        tprint(" is incomplete");
        if_line = if_line_field(cond_ptr);
        cur_if = if_limit_subtype(cond_ptr);
        if_limit = if_limit_type(cond_ptr);
        cond_ptr = vlink(cond_ptr);
    }
    /*tex restore old values */
    cond_ptr = p;
    if_limit = l;
    cur_if = c;
    if_line = i;
    print_ln();
    if (tracing_nesting_par > 1)
        show_context();
    if (error_state.history == spotless)
        error_state.history = warning_issued;
}

/*tex

    The lua interface needs some extra functions. The functions themselves are
    quite boring, but they are handy because otherwise this internal stuff has to
    be accessed from \CCODE\ directly, where lots of the defines are not available.

*/

int set_tex_dimen_register(int j, scaled v)
{
    int a;
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    word_define(j + scaled_base, v);
    return 0;
}

int set_tex_skip_register(int j, halfword v)
{
    int a;
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    if (type(v) != glue_spec_node)
        return 1;
    word_define(j + skip_base, v);
    return 0;
}

int set_tex_mu_skip_register(int j, halfword v)
{
    int a;
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    if (type(v) != glue_spec_node)
        return 1;
    word_define(j + mu_skip_base, v);
    return 0;
}

int set_tex_count_register(int j, scaled v)
{
    int a;
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    word_define(j + count_base, v);
    return 0;
}

int set_tex_box_register(int j, scaled v)
{
    int a;
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    define(j + box_base, box_ref_cmd, v);
    return 0;
}

int set_tex_attribute_register(int j, scaled v)
{
    int a;
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    if (j > max_used_attr)
        max_used_attr = j;
    disable_attr_cache;
    word_define(j + attribute_base, v);
    return 0;
}

int get_tex_toks_register(int j)
{
    str_number s = get_nullstr();
    if (toks(j)) {
        s = tokens_to_string(toks(j));
    }
    return s;
}

int set_tex_toks_register(int j, lstring s)
{
    int a;
    halfword ref = get_avail();
    (void) str_toks(s);
    set_token_ref_count(ref, 0);
    set_token_link(ref, token_link(temp_token_head));
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    define(j + toks_base, call_cmd, ref);
    return 0;
}

int scan_tex_toks_register(int j, int c, lstring s)
{
    int a;
    halfword ref = get_avail();
    str_scan_toks(c,s);
    set_token_ref_count(ref, 0);
    set_token_link(ref, token_link(temp_token_head));
    if (global_defs_par > 0)
        a = 4;
    else
        a = 0;
    define(j + toks_base, call_cmd, ref);
    return 0;
}
