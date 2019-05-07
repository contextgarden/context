/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex These are for |show_activities|: */

# define page_goal page_so_far[0]

/*tex

    \TEX\ is typically in the midst of building many lists at once. For example,
    when a math formula is being processed, \TEX\ is in math mode and working on
    an mlist; this formula has temporarily interrupted \TEX\ from being in
    horizontal mode and building the hlist of a paragraph; and this paragraph has
    temporarily interrupted \TEX\ from being in vertical mode and building the
    vlist for the next page of a document. Similarly, when a |\vbox| occurs
    inside of an |\hbox|, \TEX\ is temporarily interrupted from working in
    restricted horizontal mode, and it enters internal vertical mode. The \quote
    {semantic nest} is a stack that keeps track of what lists and modes are
    currently suspended.

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

    The mode is temporarily set to zero while processing |\write| texts in the
    |ship_out| routine.

    Numeric values are assigned to |vmode|, |hmode|, and |mmode| so that \TEX's
    \quote {big semantic switch} can select the appropriate thing to do by
    computing the value |abs(mode) + cur_cmd|, where |mode| is the current mode
    and |cur_cmd| is the current command code.

*/

static const char *string_mode(int m)
{
    if (m > 0) {
        switch (m / (max_command_cmd + 1)) {
            case 0:
                return "vertical mode";
                break;
            case 1:
                return "horizontal mode";
                break;
            case 2:
                return "display math mode";
                break;
            default:
                break;
        }
    } else if (m == 0) {
        return "no mode";
    } else {
        switch ((-m) / (max_command_cmd + 1)) {
            case 0:
                return "internal vertical mode";
                break;
            case 1:
                return "restricted horizontal mode";
                break;
            case 2:
                return "math mode";
                break;
            default:
                break;
        }
    }
    return "unknown mode";
}

void print_mode(int m)
{
    tprint(string_mode(m));
}

/*tex

    The state of affairs at any semantic level can be represented by five values:

    \startitemize
        \startitem
            |mode| is the number representing the semantic mode, as just explained.
        \stopitem
        \startitem
            |head| is a |pointer| to a list head for the list being built;
            |link(head)| therefore points to the first element of the list, or to
            |null| if the list is empty.
        \stopitem
        \startitem
            |tail| is a |pointer| to the final node of the list being built; thus,
            |tail=head| if and only if the list is empty.
        \stopitem
        \startitem
            |prev_graf| is the number of lines of the current paragraph that have
            already been put into the present vertical list.
        \stopitem
        \startitem
            |aux| is an auxiliary |memory_word| that gives further information that
            is needed to characterize the situation.
        \stopitem
    \stopitemize

    In vertical mode, |aux| is also known as |prev_depth|; it is the scaled value
    representing the depth of the previous box, for use in baseline calculations,
    or it is |<= -1000pt| if the next box on the vertical list is to be exempt
    from baseline calculations. In horizontal mode, |aux| is also known as
    |space_factor|; it holds the current space factor used in spacing
    calculations. In math mode, |aux| is also known as |incompleat_noad|; if not
    |null|, it points to a record that represents the numerator of a generalized
    fraction for which the denominator is currently being formed in the current
    list.

    There is also a sixth quantity, |mode_line|, which correlates the semantic
    nest with the user's input; |mode_line| contains the source line number at
    which the current level of nesting was entered. The negative of this line
    number is the |mode_line| at the level of the user's output routine.

    A seventh quantity, |eTeX_aux|, is used by the extended features eTeX. In
    math mode it is known as |delim_ptr| and points to the most recent
    |fence_noad| of a |math_left_group|.

    In horizontal mode, the |prev_graf| field is used for initial language data.

    The semantic nest is an array called |nest| that holds the |mode|, |head|,
    |tail|, |prev_graf|, |aux|, and |mode_line| values for all semantic levels
    below the currently active one. Information about the currently active level
    is kept in the global quantities |mode|, |head|, |tail|, |prev_graf|, |aux|,
    and |mode_line|, which live in a struct that is ready to be pushed onto
    |nest| if necessary.

    The math field is used by various bits and pieces in |texmath.w|

    This implementation of \TEX\ uses two different conventions for representing
    sequential stacks.

    \startitemize[n]

        \startitem
            If there is frequent access to the top entry, and if the stack is
            essentially never empty, then the top entry is kept in a global variable
            (even better would be a machine register), and the other entries appear
            in the array |stack[0 .. (ptr-1)]|. The semantic stack is handled this
            way.
        \stopitem

        \startitem
            If there is infrequent top access, the entire stack contents are in the
            array |stack[0 .. (ptr-1)]|. For example, the |save_stack| is treated
            this way, as we have seen.
        \stopitem

    \stopitemize

    In |nest_ptr| we have the first unused location of |nest|, and
    |max_nest_stack| has the maximum of |nest_ptr| when pushing. In |shown_mode|
    we store the most recent mode shown by |\tracingcommands| and with
    |save_tail| we can examine whether we have an auto kern before a glue.

*/

nest_state_info nest_state;

/*tex

    We will see later that the vertical list at the bottom semantic level is
    split into two parts; the \quote {current page} runs from |page_head| to
    |page_tail|, and the \quote {contribution list} runs from |contrib_head| to
    |tail| of semantic level zero. The idea is that contributions are first
    formed in vertical mode, then \quote {contributed} to the current page
    (during which time the page|-|breaking decisions are made). For now, we don't
    need to know any more details about the page-building process.

*/

void initialize_nesting(void)
{
    nest_ptr = 0;
    max_nest_stack = 0;
    shown_mode = 0;
    cur_list.mode_field = vmode;
    cur_list.head_field = contrib_head;
    cur_list.tail_field = contrib_head;
    cur_list.eTeX_aux_field = null;
    cur_list.prev_depth_field = ignore_depth;
    cur_list.space_factor_field = 1000;
    cur_list.incompleat_noad_field = null;
    cur_list.ml_field = 0;
    cur_list.pg_field = 0;
    cur_list.dirs_field = null;
    init_math_fields();
}

/*tex Here is a common way to make the current list grow: */

void tail_append(halfword p)
{
    couple_nodes(cur_list.tail_field, p);
    cur_list.tail_field = p;
}

halfword pop_tail(void)
{
    if (cur_list.tail_field != cur_list.head_field) {
        halfword n;
        halfword r = cur_list.tail_field;
        if (vlink(alink(cur_list.tail_field)) == cur_list.tail_field) {
            n = alink(cur_list.tail_field);
        } else {
            n = cur_list.head_field;
            while (vlink(n) != cur_list.tail_field)
                n = vlink(n);
        }
        cur_list.tail_field = n;
        alink(r) = null;
        vlink(n) = null;
        return r;
    } else {
        return null;
    }
}

/*tex

    When \TEX's work on one level is interrupted, the state is saved by calling
    |push_nest|. This routine changes |head| and |tail| so that a new (empty)
    list is begun; it does not change |mode| or |aux|.

*/

void push_nest(void)
{
    if (nest_ptr > max_nest_stack) {
        max_nest_stack = nest_ptr;
        if (nest_ptr == main_state.nest_size)
            overflow("semantic nest size", (unsigned) main_state.nest_size);
    }
    incr(nest_ptr);
    cur_list.mode_field = nest[nest_ptr - 1].mode_field;
    cur_list.head_field = new_node(temp_node, 0);
    cur_list.tail_field = cur_list.head_field;
    cur_list.eTeX_aux_field = null;
    cur_list.ml_field = input_line;
    cur_list.pg_field = 0;
    cur_list.dirs_field = null;
    cur_list.prev_depth_field = nest[nest_ptr - 1].prev_depth_field;
    cur_list.space_factor_field = nest[nest_ptr - 1].space_factor_field;
    cur_list.incompleat_noad_field = nest[nest_ptr - 1].incompleat_noad_field;
    init_math_fields();
}

/*tex

    Conversely, when \TEX\ is finished on the current level, the former state is
    restored by calling |pop_nest|. This routine will never be called at the
    lowest semantic level, nor will it be called unless |head| is a node that
    should be returned to free memory.

*/

void pop_nest(void)
{
    flush_node(cur_list.head_field);
    decr(nest_ptr);
}

/*tex Here is a procedure that displays what \TEX\ is working on, at all levels. */

void show_activities(void)
{
    /*tex Index into |nest|: */
    int p;
    /*tex For showing the current page: */
    halfword q, r;
    tprint_nl("");
    print_ln();
    for (p = nest_ptr; p >= 0; p--) {
        int m = nest[p].mode_field;
        tprint_nl("### ");
        print_mode(m);
        tprint(" entered at line ");
        print_int(abs(nest[p].ml_field));
        if (nest[p].ml_field < 0)
            tprint(" (\\output routine)");
        if (p == 0) {
            /*tex Show the status of the current page */
            if (page_head != page_tail) {
                tprint_nl("### current page:");
                if (output_active)
                    tprint(" (held over for next output)");
                show_box(vlink(page_head));
                if (page_contents > null) {
                    tprint_nl("total height ");
                    print_totals();
                    tprint_nl(" goal height ");
                    print_scaled(page_goal);
                    r = vlink(page_ins_head);
                    while (r != page_ins_head) {
                        int t = subtype(r);
                        print_ln();
                        tprint_esc("insert");
                        print_int(t);
                        tprint(" adds ");
                        if (count(t) == 1000)
                            t = height(r);
                        else
                            t = x_over_n(height(r), 1000) * count(t);
                        print_scaled(t);
                        if (type(r) == split_up_node) {
                            q = page_head;
                            t = 0;
                            do {
                                q = vlink(q);
                                if ((type(q) == ins_node)
                                    && (subtype(q) == subtype(r)))
                                    incr(t);
                            } while (q != broken_ins(r));
                            tprint(", #");
                            print_int(t);
                            tprint(" might split");
                        }
                        r = vlink(r);
                    }
                }
            }
            if (vlink(contrib_head) != null)
                tprint_nl("### recent contributions:");
        }
        show_box(vlink(nest[p].head_field));
        /*tex Show the auxiliary field, |a|. */
        switch (abs(m) / (max_command_cmd + 1)) {
            case 0:
                tprint_nl("prevdepth ");
                if (nest[p].prev_depth_field <= ignore_depth)
                    tprint("ignored");
                else
                    print_scaled(nest[p].prev_depth_field);
                if (nest[p].pg_field != 0) {
                    tprint(", prevgraf ");
                    print_int(nest[p].pg_field);
                    if (nest[p].pg_field != 1)
                        tprint(" lines");
                    else
                        tprint(" line");
                }
                break;
            case 1:
                tprint_nl("spacefactor ");
                print_int(nest[p].space_factor_field);
                break;
            case 2:
                if (nest[p].incompleat_noad_field != null) {
                    tprint("this will be denominator of:");
                    show_box(nest[p].incompleat_noad_field);
                }
                break;
        }
    }
}
