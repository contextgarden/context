/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

input_state_info lmt_input_state = {
    .input_stack      = NULL,
    .input_stack_data = {
        .minimum   = min_stack_size,
        .maximum   = max_stack_size,
        .size      = siz_stack_size,
        .step      = stp_stack_size,
        .allocated = 0,
        .itemsize  = sizeof(in_state_record),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
    .in_stack         = NULL,
    .in_stack_data    = {
        .minimum   = min_in_open,
        .maximum   = max_in_open,
        .size      = siz_in_open,
        .step      = stp_in_open,
        .allocated = 0,
        .itemsize  = sizeof(input_stack_record),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
    .parameter_stack      = NULL,
    .parameter_stack_data = {
        .minimum   = min_parameter_size,
        .maximum   = max_parameter_size,
        .size      = siz_parameter_size,
        .step      = stp_parameter_size,
        .allocated = 0,
        .itemsize  = sizeof(halfword),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
    .cur_input      = { 0 },
    .input_line     = 0,
    .scanner_status = 0,
    .def_ref        = 0,
    .align_state    = 0,
    .base_ptr       = 0,
    .warning_index  = 0,
    .open_files     = 0,
    .padding        = 0,
} ;

input_file_state_info input_file_state = {
    .forced_file = 0,
    .forced_line = 0,
    .mode        = 0,
    .line        = 0,
};

/*tex 
    We play safe and always keep a few batches of parameter slots in reserve so that we 
    are unlikely to overrun.
*/

# define reserved_input_stack_slots  2
# define reserved_in_stack_slots     2
//define reserved_param_stack_slots 32                    
# define reserved_param_stack_slots (2 * max_match_count) 

void tex_initialize_input_state(void)
{
    {
        int size = lmt_input_state.input_stack_data.minimum;
        lmt_input_state.input_stack = aux_allocate_clear_array(sizeof(in_state_record), size, reserved_input_stack_slots);
        if (lmt_input_state.input_stack) {
            lmt_input_state.input_stack_data.allocated = size;
        } else {
            tex_overflow_error("input",  size);
        }
    }
    {
        int size = lmt_input_state.in_stack_data.minimum;
        lmt_input_state.in_stack = aux_allocate_clear_array(sizeof(input_stack_record), size, reserved_in_stack_slots);
        if (lmt_input_state.in_stack) {
            lmt_input_state.in_stack_data.allocated = size;
        } else {
            tex_overflow_error("file", size);
        }
    }
    {
        int size = lmt_input_state.parameter_stack_data.minimum;
        lmt_input_state.parameter_stack = aux_allocate_clear_array(sizeof(halfword), size, reserved_param_stack_slots);
        if (lmt_input_state.parameter_stack) {
            lmt_input_state.parameter_stack_data.allocated = size;
        } else {
            tex_overflow_error("parameter", size);
        }
    }
}

static int tex_aux_room_on_input_stack(void) /* quite similar to save_stack checker so maybe share */
{
    int top = lmt_input_state.input_stack_data.ptr;
    if (top > lmt_input_state.input_stack_data.top) {
        lmt_input_state.input_stack_data.top = top;
        if (top > lmt_input_state.input_stack_data.allocated) {
            in_state_record *tmp = NULL;
            top = lmt_input_state.input_stack_data.allocated + lmt_input_state.input_stack_data.step;
            if (top > lmt_input_state.input_stack_data.size) {
                top = lmt_input_state.input_stack_data.size;
            }
            if (top > lmt_input_state.input_stack_data.allocated) {
                lmt_input_state.input_stack_data.allocated = top;
                tmp = aux_reallocate_array(lmt_input_state.input_stack, sizeof(in_state_record), top, reserved_input_stack_slots);
                lmt_input_state.input_stack = tmp;
            }
            lmt_run_memory_callback("input", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("input", top);
                return 0;
            }
        }
    }
    return 1;
}

static int tex_aux_room_on_in_stack(void) /* quite similar to save_stack checker so maybe share */
{
    int top = lmt_input_state.in_stack_data.ptr;
    if (top > lmt_input_state.in_stack_data.top) {
        lmt_input_state.in_stack_data.top = top;
        if (top > lmt_input_state.in_stack_data.allocated) {
            input_stack_record *tmp = NULL;
            top = lmt_input_state.in_stack_data.allocated + lmt_input_state.in_stack_data.step;
            if (top > lmt_input_state.in_stack_data.size) {
                top = lmt_input_state.in_stack_data.size;
            }
            if (top > lmt_input_state.in_stack_data.allocated) {
                lmt_input_state.in_stack_data.allocated = top;
                tmp = aux_reallocate_array(lmt_input_state.in_stack, sizeof(input_stack_record), top, reserved_in_stack_slots);
                lmt_input_state.in_stack = tmp;
            }
            lmt_run_memory_callback("file", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("file", top);
                return 0;
            }
        }
    }
    return 1;
}

static int tex_aux_room_on_param_stack(void) /* quite similar to save_stack checker so maybe share */
{
    int top = lmt_input_state.parameter_stack_data.ptr;
    if (top > lmt_input_state.parameter_stack_data.top) {
        lmt_input_state.parameter_stack_data.top = top;
        if (top > lmt_input_state.parameter_stack_data.allocated) {
            halfword *tmp =  NULL;
            top = lmt_input_state.parameter_stack_data.allocated + lmt_input_state.parameter_stack_data.step;
            if (top > lmt_input_state.parameter_stack_data.size) {
                top = lmt_input_state.parameter_stack_data.size;
            }
            if (top > lmt_input_state.parameter_stack_data.allocated) {
                lmt_input_state.parameter_stack_data.allocated = top;
                tmp = aux_reallocate_array(lmt_input_state.parameter_stack, sizeof(halfword), top, reserved_param_stack_slots);
                lmt_input_state.parameter_stack = tmp;
            }
            lmt_run_memory_callback("parameter", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("parameter", top);
                return 0;
            }
        }
    }
    return 1;
}

void tex_copy_pstack_to_param_stack(halfword *pstack, int n)
{
    if (tex_aux_room_on_param_stack()) {
        memcpy(&lmt_input_state.parameter_stack[lmt_input_state.parameter_stack_data.ptr], pstack, n * sizeof(halfword));
        lmt_input_state.parameter_stack_data.ptr += n;
    }
}

/*tex

    As elsewhere we keep variables that belong together in a structure: |input_stack|, the first
    unused location of |input_stack| being |input_ptr|, the largest value of |input_ptr| when
    pushing |max_input_stack|, the the \quote {top} input state|cur_input|, the number of lines in
    the buffer, less one, |in_open|, the number of open text files |open_files| (in regular \TEX\
    called |open_parens| because it relates to the way files are reported), the |input_file| and
    the current line number in the current source file |line|. Furthermore some stacks:
    |line_stack|. |source_filename_stack| and |full_source_filename_stack|. The |scanner_status|
    tells if we can a end a subfile now. There is an obscure identifier relevant to non-|normal|
    scanner status |warning_index|. Then there is the often used reference count pointer of token
    list being defined: |def_ref|.

    Here is a procedure that uses |scanner_status| to print a warning message when a subfile has
    ended, and at certain other crucial times. Actually it is only called when we run out of
    token memory. Because memory errors can be of any kind, we normall will not use the \TEX\
    error handler (but we do have a callback).

    Similar code is is us in |texerrors.c| for use with the error callback. Maybe some day that
    will be default.

*/

void tex_show_validity(void)
{
    halfword p = null;
    switch (lmt_input_state.scanner_status) {
        case scanner_is_defining:
            p = lmt_input_state.def_ref;
            break;
        case scanner_is_matching:
        case scanner_is_tolerant:
            p = tex_expand_match_token_head();
            break;
        case scanner_is_aligning:
            p = tex_alignment_hold_token_head();
            break;
        case scanner_is_absorbing:
            p = lmt_input_state.def_ref;
            break;
    }
    if (p) {
        tex_print_ln();
        tex_token_show(p, default_token_show_max > lmt_error_state.line_limits.size - 10 ? lmt_error_state.line_limits.size - 10 : default_token_show_max);
        tex_print_ln();
    }
}

void tex_show_runaway(void)
{
    if (lmt_input_state.scanner_status > scanner_is_skipping) {
        tex_print_nlp();
        switch (lmt_input_state.scanner_status) {
            case scanner_is_defining:
                tex_print_str("We ran into troubles when scanning a definition.");
                break;
            case scanner_is_matching:
                tex_print_str("We ran into troubles scanning an argument.");
                break;
            case scanner_is_tolerant:
                return;
            case scanner_is_aligning:
                tex_print_str("We ran into troubles scanning an alignment preamle.");
                break;
            case scanner_is_absorbing:
                tex_print_str("We ran into troubles absorbing something.");
                break;
            default:
                return;
        }
        tex_print_nlp();
        tex_show_validity();
    }
}

/*tex

    The |param_stack| is an auxiliary array used to hold pointers to the token lists for parameters
    at the current level and subsidiary levels of input. This stack is maintained with convention
    (2), and it grows at a different rate from the others.

    So, the token list pointers for parameters is |param_stack|, the first unused entry in
    |param_stack| is |param_ptr| which is in the range |0 .. param_size + 9|.

    The input routines must also interact with the processing of |\halign| and |\valign|, since the
    appearance of tab marks and |\cr| in certain places is supposed to trigger the beginning of
    special |v_j| template text in the scanner. This magic is accomplished by an |align_state|
    variable that is increased by~1 when a |\char'173| is scanned and decreased by~1 when a |\char
    '175| is scanned. The |align_state| is nonzero during the $u_j$ template, after which it is set
    to zero; the |v_j| template begins when a tab mark or |\cr| occurs at a time that |align_state
    = 0|.

    Thus, the \quote {current input state} can be very complicated indeed; there can be many levels
    and each level can arise in a variety of ways. The |show_context| procedure, which is used by
    \TEX's error-reporting routine to print out the current input state on all levels down to the
    most recent line of characters from an input file, illustrates most of these conventions. The
    global variable |base_ptr| contains the lowest level that was displayed by this procedure.

    The status at each level is indicated by printing two lines, where the first line indicates
    what was read so far and the second line shows what remains to be read. The context is cropped,
    if necessary, so that the first line contains at most |half_error_line| characters, and the
    second contains at most |error_line|. Non-current input levels whose |token_type| is |backed_up|
    are shown only if they have not been fully read.

    When applicable, print the location of the current line. This routine should be changed, if
    necessary, to give the best possible indication of where the current line resides in the input
    file. For example, on some systems it is best to print both a page and line number.

    Because we also have \LUA\ input en output and because error messages and contexts can go
    through \LUA, reporting is a bit different in \LUAMETATEX.

*/

static void tex_aux_print_indent(void)
{
    for (int q = 1; q <= lmt_error_state.context_indent; q++) {
        tex_print_char(' ');
    }
}

static void tex_aux_print_current_input_state(void)
{
    int macro = 0;
    tex_print_str("<");
    if (lmt_input_state.cur_input.state == token_list_state) {
        switch (lmt_input_state.cur_input.token_type) {
            case parameter_text:
                tex_print_str("argument");
                break;
            case template_pre_text:
                tex_print_str("templatepre");
                break;
            case template_post_text:
                tex_print_str("templatepost");
                break;
            case backed_up_text:
                tex_print_str(lmt_input_state.cur_input.loc ? "to be read again" : "recently read");
                break;
            case inserted_text:
                tex_print_str("inserted text");
                break;
            case macro_text:
                tex_print_str("macro");
                macro = lmt_input_state.cur_input.name;
                break;
            case output_text:
                tex_print_str("output");
                break;
            case every_par_text:
                tex_print_str("everypar");
                break;
            case every_math_text:
                tex_print_str("everymath");
                break;
            case every_display_text:
                tex_print_str("everydisplay");
                break;
            case every_hbox_text:
                tex_print_str("everyhbox");
                break;
            case every_vbox_text:
                tex_print_str("everyvbox");
                break;
            case every_math_atom_text:
                tex_print_str("everymathatom");
                break;
            case every_job_text:
                tex_print_str("everyjob");
                break;
            case every_cr_text:
                tex_print_str("everycr");
                break;
            case every_tab_text:
                tex_print_str("everytab");
                break;
            case end_of_group_text:
                tex_print_str("endofgroup");
                break;
            case mark_text:
                tex_print_str("mark");
                break;
            case loop_text:
                tex_print_str("loop");
                break;
            case every_eof_text:
                tex_print_str("everyeof");
                break;
            case every_before_par_text:
                tex_print_str("everybeforepar");
                break;
            case end_paragraph_text:
                tex_print_str("endpar");
                break;
            case write_text:
                tex_print_str("write");
                break;
            case local_text:
                tex_print_str("local");
                break;
            case local_loop_text:
                tex_print_str("localloop");
                break;
            default:
                tex_print_str("unknown");
                break;
        }
    } else {
        switch (lmt_input_state.cur_input.name) {
            case io_initial_input_code:
                tex_print_str("initial input");
                break;
            case io_lua_input_code:
                tex_print_str("lua input");
                break;
            case io_token_input_code:
                tex_print_str("token input");
                break;
            case io_token_eof_input_code:
                tex_print_str("token eof input");
                break;
            case io_tex_macro_code:
            case io_file_input_code:
            default:
                {
                    /* Todo : figure out what the weird line is when we have a premature file end. */
                    tex_print_str("line ");
                    tex_print_int(lmt_input_state.cur_input.index);
                    tex_print_char('.');
                    tex_print_int(lmt_input_state.cur_input.index == lmt_input_state.in_stack_data.ptr ? lmt_input_state.input_line : lmt_input_state.in_stack[lmt_input_state.cur_input.index + 1].line);
                }
                break;
        }
    }
    tex_print_str("> ");
    if (macro) {
        tex_print_cs_checked(macro);
    }
}

/*tex

    Here it is necessary to explain a little trick. We don't want to store a long string that
    corresponds to a token list, because that string might take up lots of memory; and we are
    printing during a time when an error message is being given, so we dare not do anything that
    might overflow one of \TEX's tables. So \quote {pseudoprinting} is the answer: We enter a mode
    of printing that stores characters into a buffer of length |error_line|, where character $k +
    1$ is placed into |trick_buf [k mod error_line]| if |k < trick_count|, otherwise character |k|
    is dropped. Initially we set |tally := 0| and |trick_count := 1000000|; then when we reach the
    point where transition from line 1 to line 2 should occur, we set |first_count := tally| and
    |trick_count := tmax > (error_line, tally + 1 + error_line - half_error_line)|. At the end
    of the pseudoprinting, the values of |first_count|, |tally|, and |trick_count| give us all the
    information we need to print the two lines, and all of the necessary text is in |trick_buf|.

    Namely, let |l| be the length of the descriptive information that appears on the first line.
    The length of the context information gathered for that line is |k = first_count|, and the
    length of the context information gathered for line~2 is $m=\min(|tally|, |trick_count|) - k$.
    If |l + k <= h|, where |h = half_error_line|, we print |trick_buf[0 .. k-1]| after the
    descriptive information on line~1, and set |n := l + k|; here |n| is the length of line~1. If
    |l + k > h|, some cropping is necessary, so we set |n := h| and print |...| followed by
    |trick_buf[(l + k - h + 3) .. k - 1]| where subscripts of |trick_buf| are circular modulo
    |error_line|. The second line consists of |n|~spaces followed by |trick_buf[k .. (k + m - 1)]|,
    unless |n + m > error_line|; in the latter case, further cropping is done. This is easier to
    program than to explain.

    The following code sets up the print routines so that they will gather the desired information.

*/

void tex_set_trick_count(void)
{
    lmt_print_state.first_count = lmt_print_state.tally;
    lmt_print_state.trick_count = lmt_print_state.tally + 1 + lmt_error_state.line_limits.size - lmt_error_state.half_line_limits.size;
    if (lmt_print_state.trick_count < lmt_error_state.line_limits.size) {
        lmt_print_state.trick_count = lmt_error_state.line_limits.size;
    }
}

/*tex

    We don't care too much if we stay a bit too much below the max error_line even if we have more
    room on the line. If length is really an issue then any length is. After all one can set the
    length larger.

*/

static void tex_aux_print_valid_utf8(int q)
{
    int l = lmt_error_state.line_limits.size;
    int c = (int) lmt_print_state.trick_buffer[q % l];
    if (c < 128) {
        tex_print_char(c);
    } else if (c < 194) {
        /* invalid */
    } else if (c < 224) {
        tex_print_char(c);
        tex_print_char(lmt_print_state.trick_buffer[(q + 1) % l]);
    } else if (c < 240) {
        tex_print_char(c);
        tex_print_char(lmt_print_state.trick_buffer[(q + 1) % l]);
        tex_print_char(lmt_print_state.trick_buffer[(q + 2) % l]);
    } else if (c < 245) {
        tex_print_char(c);
        tex_print_char(lmt_print_state.trick_buffer[(q + 1) % l]);
        tex_print_char(lmt_print_state.trick_buffer[(q + 2) % l]);
        tex_print_char(lmt_print_state.trick_buffer[(q + 3) % l]);
    } else {
        /*tex Invalid character! */
    }
}

void tex_show_context(void)
{
    int context_lines = -1; /*tex Number of contexts shown so far, less one: */
    int bottom_line = 0;    /*tex Have we reached the final context to be shown? */
    lmt_input_state.base_ptr = lmt_input_state.input_stack_data.ptr;
    lmt_input_state.input_stack[lmt_input_state.base_ptr] = lmt_input_state.cur_input;
    while (1) {
        /*tex Enter into the context. */
        lmt_input_state.cur_input = lmt_input_state.input_stack[lmt_input_state.base_ptr];
        if ((lmt_input_state.cur_input.state != token_list_state) && (io_file_input(lmt_input_state.cur_input.name) || (lmt_input_state.base_ptr == 0))) {
            bottom_line = 1;
        }
        if ((lmt_input_state.base_ptr == lmt_input_state.input_stack_data.ptr) || bottom_line || (context_lines < error_context_lines_par)) {
            /*tex Display the current context. */
            if ((lmt_input_state.base_ptr == lmt_input_state.input_stack_data.ptr) || (lmt_input_state.cur_input.state != token_list_state) || (lmt_input_state.cur_input.token_type != backed_up_text) || (lmt_input_state.cur_input.loc)) {
                /*tex
                    We omit backed-up token lists that have already been read. Get ready to count
                    characters. We start pseudo printing.

                    This is complex code. When we display a context, we loop over context lines, but
                    actually we're talking of two lines: the discriptive line and the token list or
                    something from the buffer. Then there is that trick buffer stuff. In order to
                    get a better picture I expanded some variable names. Also, the length of the
                    input state line never got registered as there was no pseudo printing used.

                    Because in \LUAMETATEX\ the content can come from \LUA\ we display the state
                    somewhat differently: we also show the input level for line numbers and we tag
                    for instance a macro, just for consistency. The contexts are separated by
                    newlines.
                */
                int skip = 0;
                tex_print_nlp();
                tex_aux_print_current_input_state();
                /*
                    The |pseudo_selector_code| selector value is only set in this context. It makes
                    sure that we end up at the place where the problem happens.
                */
                {
                    int saved_selector = lmt_print_state.selector;
                    lmt_print_state.tally = 0;
                    lmt_print_state.selector = pseudo_selector_code;
                    lmt_print_state.trick_count = 1000000;
                    if (lmt_input_state.cur_input.state == token_list_state) {
                        halfword head = lmt_input_state.cur_input.token_type < macro_text ? lmt_input_state.cur_input.start : token_link(lmt_input_state.cur_input.start);
                        tex_show_token_list(head, lmt_input_state.cur_input.loc, default_token_show_max, 0);
                    } else if (lmt_input_state.cur_input.name == io_lua_input_code) {
                        skip = 1;
                    } else {
                        /*tex Before we pseudo print the line we determine the effective end. */
                        int j = lmt_input_state.cur_input.limit;
                        if (lmt_fileio_state.io_buffer[lmt_input_state.cur_input.limit] != end_line_char_par) {
                            ++j;
                        }
                        if (j > 0) {
                            for (int i = lmt_input_state.cur_input.start; i <= j - 1; i++) {
                                if (i == lmt_input_state.cur_input.loc) {
                                    tex_set_trick_count();
                                }
                                tex_print_char(lmt_fileio_state.io_buffer[i]);
                            }
                        }
                    }
                    lmt_print_state.selector = saved_selector;
                }
                /*tex Print two lines using the tricky pseudoprinted information. */
                if (! skip) {
                    int p; /*tex Starting or ending place in |trick_buf|. */
                    int m; /*tex Context information gathered for line 2. */
                    int n; /*tex Length of line 1. */
                    tex_print_nlp();
                    tex_aux_print_indent();
                    if (lmt_print_state.trick_count == 1000000) {
                        tex_set_trick_count();
                    }
                    /*tex The |set_trick_count| must be performed. */
                    if (lmt_print_state.tally < lmt_print_state.trick_count) {
                        m = lmt_print_state.tally - lmt_print_state.first_count;
                    } else {
                        m = lmt_print_state.trick_count - lmt_print_state.first_count;
                    }
                    if (lmt_print_state.first_count <= lmt_error_state.half_line_limits.size) {
                        p = 0;
                        n = lmt_print_state.first_count;
                    } else {
                        tex_print_str("...");
                        p = lmt_print_state.first_count - lmt_error_state.half_line_limits.size + 3;
                        n = lmt_error_state.half_line_limits.size;
                    }
                    for (int q = p; q <= lmt_print_state.first_count - 1; q++) {
                        tex_aux_print_valid_utf8(q);
                    }
                    /*tex
                        Print |n| spaces to begin line 2. Instead of |n| we use a fixed value of
                        |error_context_indent|.
                    */
                    if (m + n > lmt_error_state.line_limits.size) {
                        p = lmt_print_state.first_count + (lmt_error_state.line_limits.size - n - 3);
                    } else {
                        p = lmt_print_state.first_count + m;
                    }
                    if (lmt_print_state.first_count <= p - 1) {
                        tex_print_nlp();
                        tex_aux_print_indent();
                        for (int q = lmt_print_state.first_count; q <= p - 1; q++) {
                            tex_aux_print_valid_utf8(q);
                        }
                        if (m + n > lmt_error_state.line_limits.size) {
                            tex_print_str(" ...");
                        }
                    }
                }
                ++context_lines;
            }
        } else if (context_lines == error_context_lines_par) {
            tex_print_nlp();
            tex_print_str(" ...");
            tex_print_nlp();
            ++context_lines;
            /*tex Omitted if |error_context_lines_par < 0|. */
        }
        if (bottom_line) {
            break;
        } else {
            --lmt_input_state.base_ptr;
        }
    }
    /*tex Restore the original state. */
    lmt_input_state.cur_input = lmt_input_state.input_stack[lmt_input_state.input_stack_data.ptr];
    tex_print_ln();
    tex_print_nlp();
}

/*tex

    The following subroutines change the input status in commonly needed ways. First comes
    |push_input|, which stores the current state and creates a new level (having, initially, the
    same properties as the old). Enter a new input level, save the old:

*/

inline static void tex_aux_push_input(void)
{
    if (tex_aux_room_on_input_stack()) {
        lmt_input_state.input_stack[lmt_input_state.input_stack_data.ptr] = lmt_input_state.cur_input;
        ++lmt_input_state.input_stack_data.ptr;
    } else {
        tex_overflow_error("input stack size", lmt_input_state.input_stack_data.size);
    }
}

inline static void tex_aux_pop_input(void)
{
    lmt_input_state.cur_input = lmt_input_state.input_stack[--lmt_input_state.input_stack_data.ptr];
}

/*tex

    Here is a procedure that starts a new level of token-list input, given a token list |p| and its
    type |t|. If |t=macro|, the calling routine should set |name| and |loc|.

    I added a few few simple variants because the compiler will then inline the little code involved
    and these are used often.

*/

void tex_begin_token_list(halfword t, quarterword kind)
{
    tex_aux_push_input();
    lmt_input_state.cur_input.state = token_list_state;
    lmt_input_state.cur_input.start = t;
    lmt_input_state.cur_input.token_type = kind;
    if (kind < macro_text) {
        lmt_input_state.cur_input.loc = t;
    } else if (kind == macro_text) {
        /*tex More frequently when processing a document: */
        tex_add_token_reference(t);
        lmt_input_state.cur_input.parameter_start = lmt_input_state.parameter_stack_data.ptr;
    } else {
        /*tex More frequently when making a format: */
        tex_add_token_reference(t);
        /*tex The token list started with a reference count. */
        lmt_input_state.cur_input.loc = token_link(t);
        if (tracing_macros_par > 0) {
            tex_begin_diagnostic();
            switch (kind) {
                case mark_text:
                    tex_print_str("mark");
                    break;
                case loop_text:
                    tex_print_str("loop");
                    break;
                case write_text:
                    tex_print_str("write");
                    break;
                case local_text:
                    tex_print_str("local");
                    break;
                case local_loop_text:
                    tex_print_str("localloop");
                    break;
                case end_paragraph_text:
                    tex_print_str("endpar");
                    break;
                default:
                    /* messy offsets */
                    tex_print_cmd_chr(internal_toks_cmd, kind - output_text + internal_toks_location(output_routine_code));
                    break;
            }
            tex_print_str("->");
            tex_token_show(t, default_token_show_max);
            tex_end_diagnostic();
        }
    }
}

void tex_begin_parameter_list(halfword t)
{
    if (t) {
        tex_aux_push_input();
        lmt_input_state.cur_input.state = token_list_state;
        lmt_input_state.cur_input.start = t;
        lmt_input_state.cur_input.loc = t;
        lmt_input_state.cur_input.token_type = parameter_text;
    } else {
        // can happen 
    }
}

void tex_begin_backed_up_list(halfword t)
{
    if (t) {
        tex_aux_push_input();
        lmt_input_state.cur_input.state = token_list_state;
        lmt_input_state.cur_input.start = t;
        lmt_input_state.cur_input.loc = t;
        lmt_input_state.cur_input.token_type = backed_up_text;
    } else {
        // can happen 
    }
}

void tex_begin_inserted_list(halfword t)
{
 // if (t) {
        tex_aux_push_input();
        lmt_input_state.cur_input.state = token_list_state;
        lmt_input_state.cur_input.start = t;
        lmt_input_state.cur_input.loc = t;
        lmt_input_state.cur_input.token_type = inserted_text;
 // } else {
 //     // never happens
 // }
}

void tex_begin_macro_list(halfword t)
{
 // if (t) {
        tex_aux_push_input();
        lmt_input_state.cur_input.state = token_list_state;
        lmt_input_state.cur_input.start = t;
        tex_add_token_reference(t);
        lmt_input_state.cur_input.token_type = macro_text;
        lmt_input_state.cur_input.parameter_start = lmt_input_state.parameter_stack_data.ptr;
 // } else {
 //     // never happens
 // }
}

/*tex

    When a token list has been fully scanned, the following computations should be done as we leave
    that level of input. The |token_type| tends to be equal to either |backed_up| or |inserted|
    about 2/3 of the time.

*/

void tex_end_token_list(void)
{
    /*tex Leave a token-list input level: */
    switch (lmt_input_state.cur_input.token_type) {
        case parameter_text:
            break;
        case template_pre_text:
            if (lmt_input_state.align_state > 500000) {
                lmt_input_state.align_state = 0;
            } else {
                tex_alignment_interwoven_error(7);
            }
            break;
        case template_post_text:
            break;
        case backed_up_text:
        case inserted_text:
        case end_of_group_text:
     /* case local_text: */
            tex_flush_token_list(lmt_input_state.cur_input.start);
            break;
        case macro_text:
            {
                tex_delete_token_reference(lmt_input_state.cur_input.start);
                if (get_token_preamble(lmt_input_state.cur_input.start)) {
                    /*tex Parameters must be flushed: */
                    int ptr = lmt_input_state.parameter_stack_data.ptr;
                    int start = lmt_input_state.cur_input.parameter_start;
                    while (ptr > start) {
                        --ptr;
                        if (lmt_input_state.parameter_stack[ptr]) {
                            tex_flush_token_list(lmt_input_state.parameter_stack[ptr]);
                        }
                    }
                    lmt_input_state.parameter_stack_data.ptr = start;
                } else { 
                    /*tex We have no arguments but we save very little runtime here. */
                }
                break;
            }
        default:
            /*tex Update the reference count: */
            tex_delete_token_reference(lmt_input_state.cur_input.start);
            break;
    }
    tex_aux_pop_input();
 /* check_interrupt(); */
}

/*tex A special version used in macro expansion. Maybe some day I'll optimize it. */

void tex_cleanup_input_state(void)
{
    while (! lmt_input_state.cur_input.loc && lmt_input_state.cur_input.state == token_list_state) {
        switch (lmt_input_state.cur_input.token_type) {
            case parameter_text:
                break;
            case template_pre_text:
                if (lmt_input_state.align_state > 500000) {
                    lmt_input_state.align_state = 0;
                } else {
                    tex_alignment_interwoven_error(7);
                }
                break;
            case template_post_text:
                break;
            case backed_up_text:
            case inserted_text:
            case end_of_group_text:
         /* case local_text: */
                tex_flush_token_list(lmt_input_state.cur_input.start);
                break;
            case macro_text:
                {
                    int ptr, start;
                    /*tex Using a simple version for no arguments has no gain. */
                    tex_delete_token_reference(lmt_input_state.cur_input.start);
                    /*tex Parameters must be flushed: */
                    ptr = lmt_input_state.parameter_stack_data.ptr;
                    start = lmt_input_state.cur_input.parameter_start;
                    while (ptr > start) {
                        if (lmt_input_state.parameter_stack[--ptr]) {
                            tex_flush_token_list(lmt_input_state.parameter_stack[ptr]);
                        }
                     // halfword p = lmt_input_state.parameter_stack[--ptr];
                     // if (p) {
                     //     if (! token_link(p)) {
                     //         tex_put_available_token(p); /* very little gain on average */
                     //     } else { 
                     //         tex_flush_token_list(p);
                     //     }
                     // }
                    }
                    lmt_input_state.parameter_stack_data.ptr = start;
                    break;
                }
            default:
                /*tex Update the reference count: */
                tex_delete_token_reference(lmt_input_state.cur_input.start);
                break;
        }
        tex_aux_pop_input();
    }
}

/*tex

    Sometimes \TEX\ has read too far and wants to \quote {unscan} what it has seen. The |back_input|
    procedure takes care of this by putting the token just scanned back into the input stream, ready
    to be read again. This procedure can be used only if |cur_tok| represents the token to be
    replaced. Some applications of \TEX\ use this procedure a lot, so it has been slightly optimized
    for speed.

*/

/*tex Undo one token of input: */

void tex_back_input(halfword t)
{
    while ((lmt_input_state.cur_input.state == token_list_state) && (! lmt_input_state.cur_input.loc) && (lmt_input_state.cur_input.token_type != template_post_text)) {
        tex_end_token_list();
    }
    {
        /*tex A token list of length one: */
        halfword p = tex_get_available_token(t);
        if (t < right_brace_limit) {
            if (t < left_brace_limit) {
                --lmt_input_state.align_state;
            } else {
                ++lmt_input_state.align_state;
            }
        }
        /*
        if (token_type == backed_up_text && istate == token_list_state && istart == iloc) {
            token_link(p) = istart;
            istart = p;
            iloc = p;
        } else {
        */
        tex_aux_push_input();
        /*tex This is |back_list(p)|, without procedure overhead: */
        lmt_input_state.cur_input.start = p;
        lmt_input_state.cur_input.loc = p;
        lmt_input_state.cur_input.state = token_list_state;
        lmt_input_state.cur_input.token_type = backed_up_text;
        /* } */
    }
}

/*tex Insert token |p| into \TEX's input: */

void tex_reinsert_token(halfword t)
{
    halfword p = tex_get_available_token(t);
    set_token_link(p, lmt_input_state.cur_input.loc);
    lmt_input_state.cur_input.start = p;
    lmt_input_state.cur_input.loc = p;
    if (t < right_brace_limit) {
        if (t < left_brace_limit) {
            --lmt_input_state.align_state;
        } else {
            ++lmt_input_state.align_state;
        }
    }
}

/*tex Some aftergroup related code: */

void tex_insert_input(halfword h)
{
    if (h) {
        while ((lmt_input_state.cur_input.state == token_list_state) && (! lmt_input_state.cur_input.loc) && (lmt_input_state.cur_input.token_type != template_post_text)) {
            tex_end_token_list();
        }
        if (token_info(h) < right_brace_limit) {
            if (token_info(h) < left_brace_limit) {
                --lmt_input_state.align_state;
            } else {
                ++lmt_input_state.align_state;
            }
        }
        tex_aux_push_input();
        lmt_input_state.cur_input.start = h;
        lmt_input_state.cur_input.loc = h;
        lmt_input_state.cur_input.state = token_list_state;
        lmt_input_state.cur_input.token_type = inserted_text;
    }
}

void tex_append_input(halfword h)
{
    if (h) {
        halfword n = h;
        if (n) {
            while (token_link(n)) {
                n = token_link(n);
            }
            set_token_link(n, lmt_input_state.cur_input.loc);
        } else {
            set_token_link(h, lmt_input_state.cur_input.loc);
        }
        lmt_input_state.cur_input.start = h;
        lmt_input_state.cur_input.loc = h;
    }
}

/*tex

    The |begin_file_reading| procedure starts a new level of input for lines of characters to be
    read from a file, or as an insertion from the terminal. It does not take care of opening the
    file, nor does it set |loc| or |limit| or |line|.

*/

void tex_begin_file_reading(void)
{
    ++lmt_input_state.in_stack_data.ptr;
    if (tex_aux_room_on_in_stack() && tex_room_in_buffer(lmt_fileio_state.io_first)) {
        tex_aux_push_input();
        lmt_input_state.cur_input.index = (short) lmt_input_state.in_stack_data.ptr;
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].full_source_filename = NULL;
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].end_of_file_seen = 0;
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].group = cur_boundary;
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].line = lmt_input_state.input_line;
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].if_ptr = lmt_condition_state.cond_ptr;
        lmt_input_state.cur_input.start = lmt_fileio_state.io_first;
        lmt_input_state.cur_input.state = mid_line_state;
        lmt_input_state.cur_input.name = io_initial_input_code;
        lmt_input_state.cur_input.cattable = default_catcode_table_preset;
        lmt_input_state.cur_input.partial = 0;
        /*tex Prepare terminal input \SYNCTEX\ information. */
        lmt_input_state.cur_input.state_file = 0;
        lmt_input_state.cur_input.state_line = 0;
    }
}

/*tex

    Conversely, the variables must be downdated when such a level of input is finished. What needs
    to be closed depends on what was opened.

*/

void tex_end_file_reading(void)
{
    lmt_fileio_state.io_first = lmt_input_state.cur_input.start;
    lmt_input_state.input_line = lmt_input_state.in_stack[lmt_input_state.cur_input.index].line;
    switch (lmt_input_state.cur_input.name) {
        case io_initial_input_code:
            break;
        case io_lua_input_code:
        case io_token_input_code:
        case io_token_eof_input_code:
            /*tex happens more frequently than reading from file */
            lmt_cstring_close();
            break;
        case io_tex_macro_code:
            break;
        default:
            /*tex A file opened with |\input|, |\read...| is handled by \LUA.  */
            tex_lua_a_close_in();
            if (lmt_input_state.in_stack[lmt_input_state.cur_input.index].full_source_filename) {
                lmt_memory_free(lmt_input_state.in_stack[lmt_input_state.cur_input.index].full_source_filename);
                lmt_input_state.in_stack[lmt_input_state.cur_input.index].full_source_filename = NULL;
            }
            break;
    }
    tex_aux_pop_input();
    --lmt_input_state.in_stack_data.ptr;
}

/*tex

    To get \TEX's whole input mechanism going, we perform the following actions.

*/

void tex_initialize_inputstack(void)
{
    lmt_input_state.input_stack_data.ptr = 0;
    lmt_input_state.input_stack_data.top = 0;
    lmt_input_state.in_stack[0].full_source_filename = NULL;
    lmt_input_state.in_stack_data.ptr = 0;
    lmt_input_state.open_files = 0;
    lmt_fileio_state.io_buffer_data.top = 0;
    lmt_input_state.in_stack[0].group = 0;
    lmt_input_state.in_stack[0].if_ptr = null;
    lmt_input_state.parameter_stack_data.ptr = 0;
    lmt_input_state.parameter_stack_data.top = 0;
    lmt_input_state.scanner_status = scanner_is_normal;
    lmt_input_state.warning_index = null;
    lmt_fileio_state.io_first = 1;
    lmt_input_state.cur_input.state = new_line_state;
    lmt_input_state.cur_input.start = 1;
    lmt_input_state.cur_input.index = 0;
    lmt_input_state.input_line = 0;
    lmt_input_state.cur_input.name = io_initial_input_code;
    lmt_token_state.force_eof = 0;
    lmt_token_state.luacstrings = 0;
    lmt_input_state.cur_input.cattable = default_catcode_table_preset;
    lmt_input_state.cur_input.partial = 0;
    lmt_input_state.align_state = 1000000;
}

/*tex 
    Currently |iotype| can be |io_token_input_code| or |io_token_eof_input_code| but the idea 
    was to get rid of the eof variant. However, it seems that there are still use cases (not 
    in \CONTEXT).
*/

void tex_tex_string_start(int iotype, int cattable)
{
 /* (void) iotype; */ 
    {
        halfword head = tex_scan_general_text(NULL);
        int saved_selector = lmt_print_state.selector;
        lmt_print_state.selector = new_string_selector_code;
        tex_show_token_list(head, null, extreme_token_show_max, 0);
        lmt_print_state.selector = saved_selector;
        tex_flush_token_list(head);
    }
    {
        int len;
        char *str = tex_take_string(&len);
        lmt_cstring_store(str, len, tex_valid_catcode_table(cattable) ? cattable : cat_code_table_par);
        tex_begin_file_reading();
        lmt_input_state.input_line = 0;
        lmt_input_state.cur_input.limit = lmt_input_state.cur_input.start;
        lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
        lmt_input_state.cur_input.name = iotype; /* io_token_input_code; */
        lmt_cstring_start();
    }
}


void tex_lua_string_start(void)
{
    /*tex Set up |cur_file| and a new level of input: */
    tex_begin_file_reading();
    lmt_input_state.input_line = 0;
    lmt_input_state.cur_input.limit = lmt_input_state.cur_input.start;
    /*tex Force line read: */
    lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
    lmt_input_state.cur_input.name = io_lua_input_code;
    lmt_cstring_start();
}

void tex_any_string_start(char* s)
{
    /* via terminal emulator */
    /*
        int len = strlen(s);
        if (len > 0 && room_in_buffer(len + 1)) {
            fileio_state.io_last = fileio_state.io_first;
            strcpy((char *) &fileio_state.io_buffer[fileio_state.io_first], s);
            fileio_state.io_last += len;
            input_state.cur_input.loc = fileio_state.io_first;
            input_state.cur_input.limit = fileio_state.io_last;
            fileio_state.io_first = fileio_state.io_last + 1;
        }
    */
    /* via token input emulator */
    lmt_cstring_store(s, (int) strlen(s), cat_code_table_par);
    tex_begin_file_reading();
    lmt_input_state.input_line = 0;
    lmt_input_state.cur_input.limit = lmt_input_state.cur_input.start;
    lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
    lmt_input_state.cur_input.name = io_token_input_code;
    lmt_cstring_start();
}

/*tex a list without ref count*/

halfword tex_wrapped_token_list(halfword list)
{
    halfword head = tex_store_new_token(null, left_brace_token + '{');
    halfword tail =  head;
    token_link(tail) = token_link(list);
    while (token_link(tail)) {
        tail = token_link(tail);
    }
    tail = tex_store_new_token(tail, right_brace_token + '}');
    return head;
}

const char *tex_current_input_file_name(void)
{
    int level = lmt_input_state.in_stack_data.ptr;
    while (level > 0) {
        const char *s = lmt_input_state.in_stack[level--].full_source_filename;
        if (s) {
            return s;
        }
    }
    /*tex old method */
    level = lmt_input_state.in_stack_data.ptr;
    while (level > 0) {
        int t = lmt_input_state.input_stack[level--].name;
        if (t >= cs_offset_value) {
            return (const char *) str_string(t);
        }
    }
    return NULL;
}
