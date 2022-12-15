/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    A control sequence that has been |\def|'ed by the user is expanded by \TEX's |macro_call|
    procedure.

    Before we get into the details of |macro_call|, however, let's consider the treatment of
    primitives like |\topmark|, since they are essentially macros without parameters. The token
    lists for such marks are kept in five global arrays of pointers; we refer to the individual
    entries of these arrays by symbolic macros |top_mark|, etc. The value of |top_mark (x)|, etc.
    is either |null| or a pointer to the reference count of a token list.

    The variable |biggest_used_mark| is an aid to try and keep the code somehwat efficient without
    too much extra work: it registers the highest mark class ever instantiated by the user, so the
    loops in |fire_up| and |vsplit| do not have to traverse the full range |0 .. biggest_mark|.

    Watch out: zero is always valid and the good old single mark!

*/

mark_state_info lmt_mark_state = {
    .data      = NULL,
    .min_used  = -1,
    .max_used  = -1,
    .mark_data = {
        .minimum   = min_mark_size,
        .maximum   = max_mark_size,
        .size      = memory_data_unset,
        .step      = stp_mark_size,
        .allocated = 0,
        .itemsize  = sizeof(mark_record),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
};

void tex_initialize_marks(void)
{
    /* allocated: minimum + 1 */
    lmt_mark_state.data = aux_allocate_clear_array(sizeof(mark_record), lmt_mark_state.mark_data.minimum, 1);
    if (lmt_mark_state.data) {
        lmt_mark_state.mark_data.allocated = sizeof(mark_record) * lmt_mark_state.mark_data.minimum;
        lmt_mark_state.mark_data.top = lmt_mark_state.mark_data.minimum;
    }
}

void tex_reset_mark(halfword m)
{
    if (m >= lmt_mark_state.mark_data.top) {
       int step = lmt_mark_state.mark_data.step;
       int size = lmt_mark_state.mark_data.top;
       /* regular stepwise bump */
       while (m >= size) {
           size += step;
       }
       /* last resort */
       if (size > lmt_mark_state.mark_data.maximum) {
           size = m;
       }
       if (size <= lmt_mark_state.mark_data.maximum) {
           mark_record *tmp = aux_reallocate_array(lmt_mark_state.data, sizeof(mark_record), size, 1);
           if (tmp) {
               lmt_mark_state.data = tmp;
               memset(&lmt_mark_state.data[lmt_mark_state.mark_data.top], 0, sizeof(mark_record) * (size - lmt_mark_state.mark_data.top));
               lmt_mark_state.mark_data.top = size;
               lmt_mark_state.mark_data.allocated = sizeof(mark_record) * size;
           } else {
               tex_overflow_error("marks", size);
           }
        } else {
            tex_overflow_error("marks", lmt_mark_state.mark_data.maximum);
       }
    }
    if (m > lmt_mark_state.mark_data.ptr) {
        lmt_mark_state.mark_data.ptr = m;
    }
    tex_wipe_mark(m);
}

halfword tex_get_mark(halfword m, halfword s)
{
    if (s >= 0 && s <= last_unique_mark_code) {
        return lmt_mark_state.data[m][s];
    } else {
        return null;
    }
}

void tex_set_mark(halfword m, halfword s, halfword v)
{
    if (s >= 0 && s <= last_unique_mark_code) {
        if (lmt_mark_state.data[m][s]) {
            tex_delete_token_reference(lmt_mark_state.data[m][s]);
        }
        if (v) {
            tex_add_token_reference(v);
        }
        lmt_mark_state.data[m][s] = v;
    }
}

int tex_valid_mark(halfword m) {
    if (m >= lmt_mark_state.mark_data.top) {
        tex_reset_mark(m);
    }
    return m < lmt_mark_state.mark_data.top;
}

halfword tex_new_mark(quarterword subtype, halfword index, halfword ptr)
{
    halfword mark = tex_new_node(mark_node, subtype);
    mark_index(mark) = index;
    mark_ptr(mark) = ptr;
    if (lmt_mark_state.min_used < 0) {
        lmt_mark_state.min_used = index;
        lmt_mark_state.max_used = index;
    } else {
        if (index < lmt_mark_state.min_used) {
            lmt_mark_state.min_used = index;
        }
        if (index > lmt_mark_state.max_used) {
            lmt_mark_state.max_used = index;
        }
    }
    tex_set_mark(index, current_marks_code, ptr);
    return mark;
}

static void tex_aux_print_mark(const char *s, halfword t)
{
    if (t) {
        tex_print_token_list(s, token_link(t));
    }
}

void tex_show_marks()
{
    if (tracing_marks_par > 0 && lmt_mark_state.min_used >= 0) {
        tex_begin_diagnostic();
        for (halfword m = lmt_mark_state.min_used; m <= lmt_mark_state.max_used; m++) {
            if (tex_has_mark(m)) {
                tex_print_format("[mark: class %i, page state]",m);
                tex_aux_print_mark("top",         tex_get_mark(m, top_marks_code));
                tex_aux_print_mark("first",       tex_get_mark(m, first_marks_code));
                tex_aux_print_mark("bot",         tex_get_mark(m, bot_marks_code));
                tex_aux_print_mark("split first", tex_get_mark(m, split_first_marks_code));
                tex_aux_print_mark("split bot",   tex_get_mark(m, split_bot_marks_code));
                tex_aux_print_mark("current",     tex_get_mark(m, current_marks_code));
            }
        }
        tex_end_diagnostic();
    }
}

void tex_update_top_marks()
{
    if (lmt_mark_state.min_used >= 0) {
        for (halfword m = lmt_mark_state.min_used; m <= lmt_mark_state.max_used; m++) {
            halfword bot = tex_get_mark(m, bot_marks_code);
            if (bot) {
                tex_set_mark(m, top_marks_code, bot);
                if (tracing_marks_par > 1) {
                    tex_begin_diagnostic();
                    tex_print_format("[mark: class %i, top becomes bot]", m);
                    tex_aux_print_mark(NULL, bot);
                    tex_end_diagnostic();
                }
                tex_delete_mark(m, first_marks_code);
            }
        }
    }
}

void tex_update_first_and_bot_mark(halfword n)
{
    halfword index = mark_index(n);
    halfword ptr = mark_ptr(n);
    if (node_subtype(n) == reset_mark_value_code) {
        /*tex Work in progress. */
        if (tracing_marks_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[mark: index %i, reset]", index);
            tex_end_diagnostic();
        }
        tex_reset_mark(index);
    } else {
        /*tex Update the values of |first_mark| and |bot_mark|. */
        halfword first = tex_get_mark(index, first_marks_code);
        if (! first) {
            tex_set_mark(index, first_marks_code, ptr);
            if (tracing_marks_par > 1) {
                tex_begin_diagnostic();
                tex_print_format("[mark: index %i, first becomes mark]", index);
                tex_aux_print_mark(NULL, ptr);
                tex_end_diagnostic();
            }
        }
        tex_set_mark(index, bot_marks_code, ptr);
        if (tracing_marks_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[mark: index %i, bot becomes mark]", index);
            tex_aux_print_mark(NULL, ptr);
            tex_end_diagnostic();
        }
    }
}

void tex_update_first_marks(void)
{
    if (lmt_mark_state.min_used >= 0) {
        for (halfword m = lmt_mark_state.min_used; m <= lmt_mark_state.max_used; m++) {
            halfword top = tex_get_mark(m, top_marks_code);
            halfword first = tex_get_mark(m, first_marks_code);
            if (top && ! first) {
                tex_set_mark(m, first_marks_code, top);
                if (tracing_marks_par > 1) {
                    tex_begin_diagnostic();
                    tex_print_format("[mark: class %i, first becomes top]", m);
                    tex_aux_print_mark(NULL, top);
                    tex_end_diagnostic();
                }
            }
        }
    }
}

void tex_update_split_mark(halfword n)
{
    halfword index = mark_index(n);
    halfword ptr = mark_ptr(n);
    if (node_subtype(n) == reset_mark_value_code) {
        tex_reset_mark(index);
    } else {
        if (tex_get_mark(index, split_first_marks_code)) {
            tex_set_mark(index, split_bot_marks_code, ptr);
            if (tracing_marks_par > 1) {
                tex_begin_diagnostic();
                tex_print_format("[mark: index %i, split bot becomes mark]", index);
                tex_aux_print_mark(NULL, tex_get_mark(index, split_bot_marks_code));
                tex_end_diagnostic();
            }
        } else {
            tex_set_mark(index, split_first_marks_code, ptr);
            tex_set_mark(index, split_bot_marks_code, ptr);
            if (tracing_marks_par > 1) {
                tex_begin_diagnostic();
                tex_print_format("[mark: index %i, split first becomes mark]", index);
                tex_aux_print_mark(NULL, tex_get_mark(index, split_first_marks_code));
                tex_print_format("[mark: index %i, split bot becomes split first]", index);
                tex_aux_print_mark(NULL, tex_get_mark(index, split_bot_marks_code));
                tex_end_diagnostic();
            }
        }
    }
}


void tex_delete_mark(halfword m, int what)
{
    switch (what) {
        case top_mark_code        : what = top_marks_code;
        case first_mark_code      : what = first_marks_code;
        case bot_mark_code        : what = bot_marks_code;
        case split_first_mark_code: what = split_first_marks_code;
        case split_bot_mark_code  : what = split_bot_marks_code;
    }
    tex_set_mark(m, what, null);
}

halfword tex_get_some_mark(halfword chr, halfword val)
{
    switch (chr) {
        case top_mark_code        : val = top_marks_code;
        case first_mark_code      : val = first_marks_code;
        case bot_mark_code        : val = bot_marks_code;
        case split_first_mark_code: val = split_first_marks_code;
        case split_bot_mark_code  : val = split_bot_marks_code;
    }
    return tex_get_mark(val, chr);
}

void tex_wipe_mark(halfword m)
{
    for (int what = 0; what <= last_unique_mark_code; what++) {
        tex_set_mark(m, what, null);
    }
}

int tex_has_mark(halfword m)
{
    for (int what = 0; what <= last_unique_mark_code; what++) {
        if (lmt_mark_state.data[m][what]) {
            return 1;
        }
    }
    return 0;
}

/*tex

    The |make_mark| procedure has been renamed, because if the current chr code is 1, then the
    actual command was |\clearmarks|, which did not generate a mark node but instead destroyed the
    current mark related tokenlists. We now have proper reset nodes.

*/

void tex_run_mark(void)
{
    halfword index = 0;
    halfword code = cur_chr;
    switch (code) {
        case set_marks_code:
        case clear_marks_code:
        case flush_marks_code:
            index = tex_scan_mark_number();
            break;
    }
    if (tex_valid_mark(index)) {
        quarterword subtype = set_mark_value_code;
        halfword ptr = null;
        switch (code) {
            case set_marks_code:
            case set_mark_code:
                ptr = tex_scan_toks_expand(0, NULL, 0);
                break;
            case clear_marks_code:
                tex_wipe_mark(index);
                return;
            case flush_marks_code:
                subtype = reset_mark_value_code;
                break;
        }
        tex_tail_append(tex_new_mark(subtype, index, ptr));
    } else {
        /* error already issued */
    }
}
