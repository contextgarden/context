/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex These are for |show_activities|: */

# define page_goal lmt_page_builder_state.goal

/*tex

    \TEX\ is typically in the midst of building many lists at once. For example, when a math formula
    is being processed, \TEX\ is in math mode and working on an mlist; this formula has temporarily
    interrupted \TEX\ from being in horizontal mode and building the hlist of a paragraph; and this
    paragraph has temporarily interrupted \TEX\ from being in vertical mode and building the vlist
    for the next page of a document. Similarly, when a |\vbox| occurs inside of an |\hbox|, \TEX\ is
    temporarily interrupted from working in restricted horizontal mode, and it enters internal
    vertical mode. The \quote {semantic nest} is a stack that keeps track of what lists and modes
    are currently suspended.

    At each level of processing we are in one of six modes:

    \startitemize[n]
        \startitem
            |vmode| stands for vertical mode (the page builder);
        \stopitem
        \startitem
            |hmode| stands for horizontal mode (the paragraph builder);
        \stopitem
        \startitem
            |mmode| stands for displayed formula mode;
        \stopitem
        \startitem
            |-vmode| stands for internal vertical mode (e.g., in a |\vbox|);
        \stopitem
        \startitem
            |-hmode| stands for restricted horizontal mode (e.g., in an |\hbox|);
        \stopitem
        \startitem
            |-mmode| stands for math formula mode (not displayed).
        \stopitem
    \stopitemize

    The mode is temporarily set to zero while processing |\write| texts in the |ship_out| routine.

    Numeric values are assigned to |vmode|, |hmode|, and |mmode| so that \TEX's \quote {big semantic
    switch} can select the appropriate thing to do by computing the value |abs(mode) + cur_cmd|,
    where |mode| is the current mode and |cur_cmd| is the current command code.

    Per end December 2022 we no longer use the larg emode numbers that also encode the command at 
    hand. That code is in the archive. 

*/

const char *tex_string_mode(int m)
{
    switch (m) {
        case nomode          : return "no mode";
        case vmode           : return "vertical mode";
        case hmode           : return "horizontal mode";
        case mmode           : return "display math mode";
        case internal_vmode  : return "internal vertical mode";
        case restricted_hmode: return "restricted horizontal mode";
        case inline_mmode    : return "inline math mode";
        default              : return "unknown mode";
    }
}

/*tex

    The state of affairs at any semantic level can be represented by five values:

    \startitemize
        \startitem
            |mode| is the number representing the semantic mode, as just explained.
        \stopitem
        \startitem
            |head| is a |pointer| to a list head for the list being built; |link(head)| therefore
            points to the first element of the list, or to |null| if the list is empty.
        \stopitem
        \startitem
            |tail| is a |pointer| to the final node of the list being built; thus, |tail=head| if
            and only if the list is empty.
        \stopitem
        \startitem
            |prev_graf| is the number of lines of the current paragraph that have already been put
            into the present vertical list.
        \stopitem
        \startitem
            |aux| is an auxiliary |memoryword| that gives further information that is needed to
            characterize the situation.
        \stopitem
    \stopitemize

    In vertical mode, |aux| is also known as |prev_depth|; it is the scaled value representing the
    depth of the previous box, for use in baseline calculations, or it is |<= -1000pt| if the next
    box on the vertical list is to be exempt from baseline calculations. In horizontal mode, |aux|
    is also known as |space_factor|; it holds the current space factor used in spacing calculations.
    In math mode, |aux| is also known as |incompleat_noad|; if not |null|, it points to a record
    that represents the numerator of a generalized fraction for which the denominator is currently
    being formed in the current list.

    There is also a sixth quantity, |mode_line|, which correlates the semantic nest with the
    user's input; |mode_line| contains the source line number at which the current level of nesting
    was entered. The negative of this line number is the |mode_line| at the level of the user's
    output routine.

    A seventh quantity, |eTeX_aux|, is used by the extended features eTeX. In math mode it is known
    as |delim_ptr| and points to the most recent |fence_noad| of a |math_left_group|.

    In horizontal mode, the |prev_graf| field is used for initial language data.

    The semantic nest is an array called |nest| that holds the |mode|, |head|, |tail|, |prev_graf|,
    |aux|, and |mode_line| values for all semantic levels below the currently active one.
    Information about the currently active level is kept in the global quantities |mode|, |head|,
    |tail|, |prev_graf|, |aux|, and |mode_line|, which live in a struct that is ready to be pushed
    onto |nest| if necessary.

    The math field is used by various bits and pieces in |texmath.w|

    This implementation of \TEX\ uses two different conventions for representing sequential stacks.

    \startitemize[n]

        \startitem
            If there is frequent access to the top entry, and if the stack is essentially never
            empty, then the top entry is kept in a global variable (even better would be a machine
            register), and the other entries appear in the array |stack[0 .. (ptr-1)]|. The semantic
            stack is handled this way.
        \stopitem

        \startitem
            If there is infrequent top access, the entire stack contents are in the array |stack[0
            .. (ptr - 1)]|. For example, the |save_stack| is treated this way, as we have seen.
        \stopitem

    \stopitemize

    In |nest_ptr| we have the first unused location of |nest|, and |max_nest_stack| has the maximum
    of |nest_ptr| when pushing. In |shown_mode| we store the most recent mode shown by
    |\tracingcommands| and with |save_tail| we can examine whether we have an auto kern before a
    glue.

*/

nest_state_info lmt_nest_state = {
    .nest       = NULL,
    .nest_data  = {
        .minimum   = min_nest_size,
        .maximum   = max_nest_size,
        .size      = siz_nest_size,
        .step      = stp_nest_size,
        .allocated = 0,
        .itemsize  = sizeof(list_state_record),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
    .shown_mode = 0,
    .math_mode  = 0,
};

/*tex

    We will see later that the vertical list at the bottom semantic level is split into two parts;
    the \quote {current page} runs from |page_head| to |page_tail|, and the \quote {contribution
    list} runs from |contribute_head| to |tail| of semantic level zero. The idea is that contributions
    are first formed in vertical mode, then \quote {contributed} to the current page (during which
    time the page|-|breaking decisions are made). For now, we don't need to know any more details
    about the page-building process.

*/

# define reserved_nest_slots 0

void tex_initialize_nest_state(void)
{
    int size = lmt_nest_state.nest_data.minimum;
    lmt_nest_state.nest = aux_allocate_clear_array(sizeof(list_state_record), size, reserved_nest_slots);
    if (lmt_nest_state.nest) {
        lmt_nest_state.nest_data.allocated = size;
    } else {
        tex_overflow_error("nest",  size);
    }
}

static int tex_aux_room_on_nest_stack(void) /* quite similar to save_stack checker so maybe share */
{
    int top = lmt_nest_state.nest_data.ptr;
    if (top > lmt_nest_state.nest_data.top) {
        lmt_nest_state.nest_data.top = top;
        if (top > lmt_nest_state.nest_data.allocated) {
            list_state_record *tmp = NULL;
            top = lmt_nest_state.nest_data.allocated + lmt_nest_state.nest_data.step;
            if (top > lmt_nest_state.nest_data.size) {
                top = lmt_nest_state.nest_data.size;
            }
            if (top > lmt_nest_state.nest_data.allocated) {
                lmt_nest_state.nest_data.allocated = top;
                tmp = aux_reallocate_array(lmt_nest_state.nest, sizeof(list_state_record), top, reserved_nest_slots);
                lmt_nest_state.nest = tmp;
            }
            lmt_run_memory_callback("nest", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("nest", top);
                return 0;
            }
        }
    }
    return 1;
}

void tex_initialize_nesting(void)
{
    lmt_nest_state.nest_data.ptr = 0;
    lmt_nest_state.nest_data.top = 0;
 // lmt_nest_state.shown_mode = 0;
 // lmt_nest_state.math_mode = 0;
    cur_list.mode = vmode;
    cur_list.head = contribute_head;
    cur_list.tail = contribute_head;
    cur_list.delimiter = null;
    cur_list.prev_graf = 0;
    cur_list.mode_line = 0;
    cur_list.prev_depth = ignore_depth; /*tex |ignore_depth_criterium_par| is not yet available! */
    cur_list.space_factor = default_space_factor;
    cur_list.incomplete_noad = null;
    cur_list.direction_stack = null;
    cur_list.math_dir = 0;
    cur_list.math_style = -1;
    cur_list.math_flatten = 1;
    cur_list.math_begin = unset_noad_class;
    cur_list.math_end = unset_noad_class;
    cur_list.math_mode = 0;
}

halfword tex_pop_tail(void)
{
    if (cur_list.tail != cur_list.head) {
        halfword r = cur_list.tail;
        halfword n = node_prev(r);
        if (node_next(n) != r) {
            n = cur_list.head;
            while (node_next(n) != r) {
                n = node_next(n);
            }
        }
        cur_list.tail = n;
        node_prev(r) = null;
        node_next(n) = null;
        return r;
    } else {
        return null;
    }
}

/*tex

    When \TEX's work on one level is interrupted, the state is saved by calling |push_nest|. This
    routine changes |head| and |tail| so that a new (empty) list is begun; it does not change
    |mode| or |aux|.

*/

void tex_push_nest(void)
{
    list_state_record *top = &lmt_nest_state.nest[lmt_nest_state.nest_data.ptr];
    lmt_nest_state.nest_data.ptr += 1;
 // lmt_nest_state.shown_mode = 0; // needs checking 
    lmt_nest_state.math_mode = 0;
    if (tex_aux_room_on_nest_stack()) {
        cur_list.mode = top->mode;
        cur_list.head = tex_new_temp_node();
        cur_list.tail = cur_list.head;
        cur_list.delimiter = null;
        cur_list.prev_graf = 0;
        cur_list.mode_line = lmt_input_state.input_line;
        cur_list.prev_depth = top->prev_depth;
        cur_list.space_factor = top->space_factor;
        cur_list.incomplete_noad = top->incomplete_noad;
        cur_list.direction_stack = null;
        cur_list.math_dir = 0;
        cur_list.math_style = -1;
        cur_list.math_flatten = 1;
        cur_list.math_begin = unset_noad_class;
        cur_list.math_end = unset_noad_class;
     // cur_list.math_begin = top->math_begin;
     // cur_list.math_end = top->math_end;
        cur_list.math_mode = 0;
    } else {
        tex_overflow_error("semantic nest size", lmt_nest_state.nest_data.size);
    }
}

/*tex

    Conversely, when \TEX\ is finished on the current level, the former state is restored by
    calling |pop_nest|. This routine will never be called at the lowest semantic level, nor will
    it be called unless |head| is a node that should be returned to free memory.

*/

void tex_pop_nest(void)
{
    if (cur_list.head) {
        /* tex_free_node(cur_list.head, temp_node_size); */ /* looks fragile */
        tex_flush_node(cur_list.head);
        /*tex Just to be sure, in case we access from \LUA: */
     // cur_list.head = null;
     // cur_list.tail = null;
    }
    --lmt_nest_state.nest_data.ptr;
}

/*tex Here is a procedure that displays what \TEX\ is working on, at all levels. */

void tex_show_activities(void)
{
    tex_print_nlp();
    for (int p = lmt_nest_state.nest_data.ptr; p >= 0; p--) {
        list_state_record n = lmt_nest_state.nest[p];
        tex_print_format("%l[%M entered at line %i%s]", n.mode, abs(n.mode_line), n.mode_line < 0 ? " (output routine)" : ""); // %L
        if (p == 0) {
            /*tex Show the status of the current page */
            if (page_head != lmt_page_builder_state.page_tail) {
                tex_print_format("%l[current page:%s]", lmt_page_builder_state.output_active ? " (held over for next output)" : "");
                tex_show_box(node_next(page_head));
                if (lmt_page_builder_state.contents != contribute_nothing) {
                    halfword r;
                    tex_print_format("%l[total height %P, goal height %D]",
                        page_total, page_stretch, page_filstretch, page_fillstretch, page_filllstretch, page_shrink,
                        page_goal, pt_unit
                    );
                    r = node_next(page_insert_head);
                    while (r != page_insert_head) {
                        halfword index = insert_index(r);
                        halfword multiplier = tex_get_insert_multiplier(index);
                        halfword size = multiplier == 1000 ? insert_total_height(r) : tex_x_over_n(insert_total_height(r), 1000) * multiplier;
                        if (node_type(r) == split_node && node_subtype(r) == insert_split_subtype) {
                            halfword q = page_head;
                            halfword n = 0;
                            do {
                                q = node_next(q);
                                if (node_type(q) == insert_node && split_insert_index(q) == insert_index(r)) {
                                    ++n;
                                }
                            } while (q != split_broken_insert(r));
                            tex_print_format("%l[insert %i adds %D, might split to %i]", index, size, pt_unit, n);
                        } else {
                            tex_print_format("%l[insert %i adds %D]", index, size, pt_unit);
                        }
                        r = node_next(r);
                    }
                }
            }
            if (node_next(contribute_head)) {
                tex_print_format("%l[recent contributions:]");
            }
        }
        tex_print_format("%l[begin list]");
        tex_show_box(node_next(n.head));
        tex_print_format("%l[end list]");
        /*tex Show the auxiliary field, |a|. */
        switch (n.mode) {
            case vmode:
            case internal_vmode:
                {
                    if (n.prev_depth <= ignore_depth_criterium_par) {
                        tex_print_format("%l[prevdepth ignored");
                    } else {
                        tex_print_format("%l[prevdepth %D", n.prev_depth, pt_unit);
                    }
                    if (n.prev_graf != 0) {
                        tex_print_format(", prevgraf %i line%s", n.prev_graf, n.prev_graf == 1 ? "" : "s");
                    }
                    tex_print_char(']');
                    break;
                }
            case mmode:
            case inline_mmode:
                {
                    if (n.incomplete_noad) {
                        tex_print_format("%l[this will be denominator of:]");
                        tex_print_format("%l[begin list]");
                        tex_show_box(n.incomplete_noad);
                        tex_print_format("%l[end list]");
                    }
                    break;
                }
        }
    }
}

int tex_vmode_nest_index(void)
{
    int p = lmt_nest_state.nest_data.ptr; /* index into |nest| */
    while (! is_v_mode(lmt_nest_state.nest[p].mode)) {
        --p;
    }
    return p;
}

void tex_tail_append(halfword p)
{
    node_next(cur_list.tail) = p;
    node_prev(p) = cur_list.tail;
    cur_list.tail = p;
}

void tex_tail_append_list(halfword p)
{
    node_next(cur_list.tail) = p;
    node_prev(p) = cur_list.tail;
    cur_list.tail = tex_tail_of_node_list(p);
}
