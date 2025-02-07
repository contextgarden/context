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
        .extra     = 0, 
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
        tex_overflow_error("nest", size);
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
# if 1
    lmt_nest_state.shown_mode = 0;
    lmt_nest_state.math_mode = 0;
    cur_list.mode = vmode;
    cur_list.head = contribute_head;
    cur_list.tail = contribute_head;
    cur_list.delimiter = null;
    cur_list.prev_graf = 0;
    cur_list.mode_line = 0;
    cur_list.prev_depth = ignore_depth; /*tex |ignore_depth_criterion_par| is not yet available! */
    cur_list.space_factor = default_space_factor;
    cur_list.incomplete_noad = null;
    cur_list.direction_stack = null;
    cur_list.math_dir = 0;
    cur_list.math_style = -1;
    cur_list.math_main_style = -1;
    cur_list.math_parent_style = -1;
    cur_list.math_flatten = 1;
    cur_list.math_begin = unset_noad_class;
    cur_list.math_end = unset_noad_class;
    cur_list.math_mode = 0;
    cur_list.options = 0;
# else 
    cur_list = (list_state_record) {
        .mode              = vmode,
        .head              = contribute_head,
        .tail              = contribute_head,
        .delimiter         = null,
        .prev_graf         = 0,
        .mode_line         = 0,
        .prev_depth        = ignore_depth, /*tex |ignore_depth_criterion_par| is not yet available! */
        .space_factor      = default_space_factor,
        .incomplete_noad   = null,
        .direction_stack   = null,
        .math_dir          = 0,
        .math_style        = -1,
        .math_main_style   = -1,
        .math_parent_style = -1,
        .math_flatten      = 1,
        .math_begin        = unset_noad_class,
        .math_end          = unset_noad_class,
        .math_mode         = 0,
        .options           = 0,
    };
# endif 
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
# if 1
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
            cur_list.math_main_style = top->math_main_style;
            cur_list.math_parent_style = top->math_parent_style;
            cur_list.math_flatten = 1;
            cur_list.math_begin = unset_noad_class;
            cur_list.math_end = unset_noad_class;
         // cur_list.math_begin = top->math_begin;
         // cur_list.math_end = top->math_end;
            cur_list.math_mode = 0;
            cur_list.options = 0;
# else
            cur_list = (list_state_record) {
                .mode              = top->mode,
                .head              = null,
                .tail              = null,
                .delimiter         = null,
                .prev_graf         = 0,
                .mode_line         = lmt_input_state.input_line,
                .prev_depth        = top->prev_depth,
                .space_factor      = top->space_factor,
                .incomplete_noad   = top->incomplete_noad,
                .direction_stack   = null,
                .math_dir          = 0,
                .math_style        = -1,
                .math_main_style   = top->math_main_style,
                .math_parent_style = top->math_parent_style,
                .math_flatten      = 1,
                .math_begin        = unset_noad_class,
                .math_end          = unset_noad_class,
             // .math_begin        = top->math_begin,
             // .math_end          = top->math_end,
                .math_mode         = 0,
                .options           = 0,
            };
            cur_list.head = tex_new_temp_node(),
            cur_list.tail = cur_list.head;
# endif

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
                    tex_print_format("%l[total height %P, goal height %p]",
                        page_total, page_stretch, page_filstretch, page_fillstretch, page_filllstretch, page_shrink,
                        page_goal
                    );
                    r = node_next(page_insert_head);
                    while (r != page_insert_head) {
                        halfword index = insert_index(r);
                        halfword multiplier = tex_get_insert_multiplier(index);
                        halfword size = multiplier == scaling_factor ? insert_total_height(r) : tex_x_over_n(insert_total_height(r), scaling_factor) * multiplier;
                        if (node_type(r) == split_node && node_subtype(r) == insert_split_subtype) {
                            halfword q = page_head;
                            halfword n = 0;
                            do {
                                q = node_next(q);
                                if (node_type(q) == insert_node && split_insert_index(q) == insert_index(r)) {
                                    ++n;
                                }
                            } while (q != split_broken_insert(r));
                            tex_print_format("%l[insert %i adds %p, might split to %i]", index, size, n);
                        } else {
                            tex_print_format("%l[insert %i adds %p]", index, size);
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
                    if (n.prev_depth <= ignore_depth_criterion_par) {
                        tex_print_format("%l[prevdepth ignored");
                    } else {
                        tex_print_format("%l[prevdepth %p", n.prev_depth);
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

void tex_tail_prepend(halfword n) 
{
    tex_couple_nodes(node_prev(cur_list.tail), n);
    tex_couple_nodes(n, cur_list.tail);
    if (cur_list.tail == cur_list.head) {
        cur_list.head = n;
    }
}

void tex_tail_append(halfword p)
{
    node_next(cur_list.tail) = p;
    node_prev(p) = cur_list.tail;
    cur_list.tail = p;
}

/*tex

    In the end this is nicer than the ugly look back and set extensible properties on a last node, 
    although that is a bit more generic. So we're back at an old \MKIV\ feature that looks ahead 
    but this time selective and therefore currently only for a few math node types. Math has a 
    synchronization issue: we can do the same with a node list handler but then we need to plug 
    into |mlist_to_hlist| which is nto pretty either.  Eventually I might do that anyway and then 
    this will disappear. This more \quote {immediate} approach also has the benefit that we can 
    cleanup immediately. (It could be used a bit like runtime captures in \LUA.)

*/

halfword tex_tail_fetch_callback(void)
{
    halfword tail = cur_list.tail;
    if (node_type(tail) == boundary_node && node_subtype(tail) == lua_boundary) { 
        cur_list.tail = node_prev(tail);
        node_next(cur_list.tail) = null;
        node_prev(tail) = null;
        node_next(tail) = null;
        return tail;
    } else {
        return null;
    }
}

halfword tex_tail_apply_callback(halfword p, halfword c)
{
    if (p && c) { 
        int callback_id = lmt_callback_defined(tail_append_callback);
        if (callback_id > 0) {
            lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "Ndd->N", p, boundary_data(c), boundary_reserved(c), &p);
        }
        tex_flush_node(c);
    }
    return p;
}

void tex_tail_append_list(halfword p)
{
    if (p) { 
        node_next(cur_list.tail) = p;
        node_prev(p) = cur_list.tail;
        cur_list.tail = tex_tail_of_node_list(p);
    }
}

void tex_tail_append_callback(halfword p)
{
    halfword c = tex_tail_fetch_callback();
    if (c) { 
        p = tex_tail_apply_callback(p, c);
    }
    tex_tail_append_list(p);
}

/*tex 
    This is an experiment. We reserve slot 0 for special purposes. 
*/


/* 
    todo: stack so that we can nest 
    todo: handle prev_depth 
    todo: less fields needed, so actually we can have a 'register' or maybe even use a box 
    todo: check if at the outer level 
*/

/* 
    contribute_head : nest[0].head : temp node 
    contribute_tail : nest[0].tail 
*/

mvl_state_info lmt_mvl_state = {
    .mvl       = NULL,
    .mvl_data  = {
        .minimum   = min_mvl_size,
        .maximum   = max_mvl_size,
        .size      = memory_data_unset,
        .step      = stp_mvl_size,
        .allocated = 0,
        .itemsize  = sizeof(list_state_record),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
        .extra     = 0, 
    },
};

static void tex_aux_reset_mvl(int i) 
{
    lmt_mvl_state.mvl[i] = (list_state_record) {
        .mode              = vmode,
        .head              = null,
        .tail              = null,
        .delimiter         = null,
        .prev_graf         = 0,
        .mode_line         = 0,
        .prev_depth        = ignore_depth,   
        .space_factor      = default_space_factor,
        .incomplete_noad   = null,
        .direction_stack   = null,
        .math_dir          = 0,
        .math_style        = -1,
        .math_main_style   = -1,
        .math_parent_style = -1,
        .math_flatten      = 1,
        .math_begin        = unset_noad_class,
        .math_end          = unset_noad_class,
        .options           = 0,
    };
}

# define reserved_mvl_slots 0

void tex_initialize_mvl_state(void)
{
    list_state_record *tmp = aux_allocate_clear_array(sizeof(list_state_record), lmt_mvl_state.mvl_data.minimum, 1);
    if (tmp) {
        lmt_mvl_state.mvl = tmp;
        lmt_mvl_state.mvl_data.allocated = lmt_mvl_state.mvl_data.minimum;
        lmt_mvl_state.mvl_data.top = lmt_mvl_state.mvl_data.minimum;
        lmt_mvl_state.mvl_data.ptr = 0;
    } else {
        tex_overflow_error("mvl", lmt_mvl_state.mvl_data.minimum);
    }
    tex_aux_reset_mvl(0);
    lmt_mvl_state.slot = 0;
}

static int tex_valid_mvl_id(halfword n)
{ 
 // if (lmt_nest_state.nest_data.ptr > 0) {
 //     tex_handle_error(
 //         normal_error_type,
 //         "An mlv command can only be used at the outer level.",
 //         "You cannot use an mlv command inside a box."
 //     );
 // } else 
    if (n <= lmt_mvl_state.mvl_data.ptr) {
        return 1;
    } else if (n < lmt_mvl_state.mvl_data.top) {
        lmt_mvl_state.mvl_data.ptr = n;
        return 1;
    } else if (n < lmt_mvl_state.mvl_data.maximum && lmt_mvl_state.mvl_data.top < lmt_mvl_state.mvl_data.maximum) {
        list_state_record *tmp = NULL;
        int top = n + lmt_mvl_state.mvl_data.step;
        if (top > lmt_mvl_state.mvl_data.maximum) {
            top = lmt_mvl_state.mvl_data.maximum;
        }
        tmp = aux_reallocate_array(lmt_mvl_state.mvl, sizeof(list_state_record), top, 1); // 1 slack reserved_mvl_slots
        if (tmp) {
            size_t extra = ((size_t) top - lmt_mvl_state.mvl_data.top) * sizeof(list_state_record);
            memset(&tmp[lmt_mvl_state.mvl_data.top + 1], 0, extra);
            lmt_mvl_state.mvl = tmp;
            lmt_mvl_state.mvl_data.allocated = top;
            lmt_mvl_state.mvl_data.top = top;
            lmt_mvl_state.mvl_data.ptr = n;
            return 1;
        }
    }
    tex_overflow_error("mvl", lmt_mvl_state.mvl_data.maximum);
    return 0;
}

void tex_start_mvl(void)
{
    halfword index = 0; 
    halfword options = 0;
    halfword prevdepth = max_dimen;
    while (1) {
        switch (tex_scan_character("iopIOP", 0, 1, 0)) {
            case 'i': case 'I':
                if (tex_scan_mandate_keyword("index", 1)) {
                    index = tex_scan_integer(0, NULL, NULL);
                }
                break;
            case 'o': case 'O':
                if (tex_scan_mandate_keyword("options", 1)) {
                    options = tex_scan_integer(0, NULL, NULL);
                }
                break;
            case 'p': case 'P':
                if (tex_scan_mandate_keyword("prevdepth", 1)) {
                    prevdepth = tex_scan_dimension(0, 0, 0, 0, NULL, NULL);
                }
                break;
            default:
                goto DONE;
        }
    }
  DONE:
    if (! index) { 
        index = tex_scan_integer(0, NULL, NULL);
    }
    if (lmt_mvl_state.slot) {
        /*tex We're already collecting. */
    } else if (index <= 0) {
        /*tex We have an invalid id. */
    } else if (! tex_valid_mvl_id(index)) {
        /*tex We're in trouble. */
    } else { 
        /*tex We're can start collecting. */
        list_state_record *mvl = &lmt_mvl_state.mvl[index];
        int start = ! mvl->head;
        if (options & mvl_ignore_prev_depth) { 
            prevdepth = ignore_depth_criterion_par;
        } else if (options & mvl_no_prev_depth) { 
            prevdepth = 0;
        } else if (prevdepth == max_dimen) { 
            prevdepth = lmt_mvl_state.mvl[index].prev_depth;
        }
        if (tracing_mvl_par) { 
            tex_begin_diagnostic();
            tex_print_format("[mvl: index %i, options %x, prevdepth %p, %s]", index, options, prevdepth, start ? "start" : "restart");
            tex_end_diagnostic();
        }
        if (start) { 
            mvl->head = tex_new_temp_node();
            mvl->tail = mvl->head;
        }
        mvl->options = options;
        lmt_mvl_state.mvl[0].prev_depth = lmt_nest_state.nest[0].prev_depth;
        lmt_nest_state.nest[0].prev_depth = prevdepth;
        lmt_mvl_state.slot = index;
    }
}

void tex_stop_mvl(void)
{
    halfword index = lmt_mvl_state.slot;
    if (index) {
        list_state_record *mvl = &lmt_mvl_state.mvl[index];
        int something = mvl->tail != mvl->head;
        if (tracing_mvl_par) { 
            tex_begin_diagnostic();
            tex_print_format("[mvl: index %i, options %x, stop with%s contributions]", index, mvl->options, something ? "" : "out");
            tex_end_diagnostic();
        }
        if (something && (mvl->options & mvl_discard_bottom)) {
            halfword last = mvl->tail;
            while (last) {
                if (non_discardable(last)) {
                    break;
                } else if (node_type(last) == kern_node && ! (node_subtype(last) == explicit_kern_subtype)) {
                    break;
                } else { 
                    halfword preceding = node_prev(last);
                    node_next(preceding) = null;
                    tex_flush_node(last);
                    mvl->tail = preceding;
                    if (mvl->head == preceding) { 
                        break;
                    } else {
                        last = preceding;
                    }
                }
            }
        }
        mvl->prev_depth = lmt_nest_state.nest[0].prev_depth;
        lmt_nest_state.nest[0].prev_depth = mvl->prev_depth;
        lmt_mvl_state.slot = 0;
    }
}

# define page_callback 1

halfword tex_flush_mvl(halfword index)
{
 // halfword index = tex_scan_integer(0, NULL);
    if (lmt_mvl_state.slot) { 
        /*tex We're collecting. */
        return null; 
    } else if (! tex_valid_mvl_id(index)) {
        /*tex We're in trouble. */
        return null;
    } else if (! lmt_mvl_state.mvl[index].tail || lmt_mvl_state.mvl[index].tail == lmt_mvl_state.mvl[index].head) {
        /*tex We collected nothing or are invalid. */
        return null;
    } else { 
        /*tex We collected something. */
        halfword head = node_next(lmt_mvl_state.mvl[index].head);
        tex_flush_node(lmt_mvl_state.mvl[index].head);
        tex_aux_reset_mvl(index);
        if (tracing_mvl_par) { 
            tex_begin_diagnostic();
            tex_print_format("[mvl: index %i, %s]", index, "flush");
            tex_end_diagnostic();
        }
        node_prev(head) = null;
# if page_callback
        return tex_vpack(head, 0, packing_additional, max_dimension, 0, holding_none_option, NULL);
# else 
        if (head) {
            return tex_filtered_vpack(head, 0, packing_additional, max_dimension, 0, 0, 0, node_attr(head), 0, 0, NULL);
        } else {
            return tex_vpack(head, 0, packing_additional, max_dimension, 0, holding_none_option, NULL);
        }
# endif
    }
}

int tex_appended_mvl(halfword context, halfword boundary)
{
    if (! lmt_mvl_state.slot) {
        /*tex We're not collecting. */
        return 0;
    } else { 
# if page_callback
        if (! lmt_page_builder_state.output_active) {
            lmt_page_filter_callback(context, boundary);
        } 
# endif 
        if (node_next(contribute_head) && ! lmt_page_builder_state.output_active) {
            halfword first = node_next(contribute_head); 
            int assign = lmt_mvl_state.mvl[lmt_mvl_state.slot].tail == lmt_mvl_state.mvl[lmt_mvl_state.slot].head;
            if (assign && (lmt_mvl_state.mvl[lmt_mvl_state.slot].options & mvl_discard_top)) {
                while (first) {
                    if (non_discardable(first)) {
                        break;
                    } else if (node_type(first) == kern_node && ! (node_subtype(first) == explicit_kern_subtype)) {
                        break;
                    } else { 
                        halfword following = node_next(first);
                        node_prev(following) = null;
                        tex_flush_node(first);
                        first = following;
                    }
                }
            }
            if (contribute_head != contribute_tail && first) {
                if (tracing_mvl_par) { 
                    tex_begin_diagnostic();
                    tex_print_format("[mvl: index %i, %s]", lmt_mvl_state.slot, assign ? "assign" : "append");
                    tex_end_diagnostic();
                }
                if (assign) { 
                    node_next(lmt_mvl_state.mvl[lmt_mvl_state.slot].head) = first;
                    /* what with prev */
                } else { 
                    tex_couple_nodes(lmt_mvl_state.mvl[lmt_mvl_state.slot].tail, first);
                }
                lmt_mvl_state.mvl[lmt_mvl_state.slot].tail = contribute_tail;
            }
            node_next(contribute_head) = null;
            contribute_tail = contribute_head;
        }
        return 1;
    }
}

int tex_current_mvl(halfword *head, halfword *tail)
{
    if (lmt_mvl_state.slot == 0) { 
        if (head && tail) {
            *head = node_next(page_head);
            *tail = lmt_page_builder_state.page_tail;
        }
        return 0; 
    } else if (lmt_mvl_state.slot > 0) {
        if (head && tail) {
            *head = lmt_mvl_state.mvl[lmt_mvl_state.slot].head;
            *tail = lmt_mvl_state.mvl[lmt_mvl_state.slot].tail;
        }
        return lmt_mvl_state.slot; 
    } else { 
        if (head && tail) {
            *head = null;
            *tail = null;
        }
        return 0;
    } 
}
