/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex 

    TODO: Check |[get|set]field| for recent (new) fields.
    TODO: Maybe we can lock glue nodes so that a calback can't mess with them. 

*/

/*tex

    We come now to what is probably the most interesting algorithm of \TEX: the mechanism for
    choosing the \quote {best possible} breakpoints that yield the individual lines of a paragraph.
    \TEX's line-breaking algorithm takes a given horizontal list and converts it to a sequence of
    boxes that are appended to the current vertical list. In the course of doing this, it creates
    a special data structure containing three kinds of records that are not used elsewhere in
    \TEX. Such nodes are created while a paragraph is being processed, and they are destroyed
    afterwards; thus, the other parts of \TEX\ do not need to know anything about how line-breaking
    is done.

    The method used here is based on an approach devised by Michael F. Plass and the author in 1977,
    subsequently generalized and improved by the same two people in 1980. A detailed discussion
    appears in {\sl SOFTWARE---Practice \AM\ Experience \bf11} (1981), 1119--1184, where it is
    shown that the line-breaking problem can be regarded as a special case of the problem of
    computing the shortest path in an acyclic network. The cited paper includes numerous examples
    and describes the history of line breaking as it has been practiced by printers through the
    ages. The present implementation adds two new ideas to the algorithm of 1980: Memory space
    requirements are considerably reduced by using smaller records for inactive nodes than for
    active ones, and arithmetic overflow is avoided by using \quote {delta distances} instead of
    keeping track of the total distance from the beginning of the paragraph to the current point.

    The |line_break| procedure should be invoked only in horizontal mode; it leaves that mode and
    places its output into the current vlist of the enclosing vertical mode (or internal vertical
    mode). There is one explicit parameter: |d| is true for partial paragraphs preceding display
    math mode; in this case the amount of additional penalty inserted before the final line is
    |display_widow_penalty| instead of |widow_penalty|.

    There are also a number of implicit parameters: The hlist to be broken starts at |node_next
    (head)|, and it is nonempty. The value of |prev_graf| in the enclosing semantic level tells
    where the paragraph should begin in the sequence of line numbers, in case hanging indentation
    or |\parshape| are in use; |prev_graf| is zero unless this paragraph is being continued after a
    displayed formula. Other implicit parameters, such as the |par_shape_ptr| and various penalties
    to use for hyphenation, etc., appear in |eqtb|.

    After |line_break| has acted, it will have updated the current vlist and the value of
    |prev_graf|. Furthermore, the global variable |just_box| will point to the final box created
    by |line_break|, so that the width of this line can be ascertained when it is necessary to
    decide whether to use |above_display_skip| or |above_display_short_skip| before a displayed
    formula.

    We have an additional parameter |\parfillleftskip| and below we cheat a bit. We add two glue
    nodes so that the par builder will work the same and doesn't need to be adapted, but when we're
    done we move the leftbound node to the beginning of the (last) line.

    Todo: change some variable names to more meaningful ones so that the code is easier to
    understand. (Remark for myself: the lua variant that i use for playing around occasionally is
    not in sync with the code here!)

    I played a bit with prerolling: make a copy, run the par builder, afterwards collect the
    result in a box that then can be consulted: wd, ht, dp, quality, hyphens, and especially
    shape fitting (which was the reason, because |\hangafter| assumes lines and esp with math a
    line is somewhat unpredictable so we get bad fitting). In the end we decided that it was kind
    of useless because of the unlikely usage scenario. But I might pick up on it. Of course it can
    be done in \LUA\ but we don't want the associated performance hit (management overhead) and
    dealing with (progressive) solutions oscillating is also an issue.

*/

typedef enum linebreak_states {
    linebreak_no_pass, 
    linebreak_first_pass,
    linebreak_second_pass,   
    linebreak_final_pass,          
    linebreak_specification_pass,
} linebreak_states;

linebreak_state_info lmt_linebreak_state = {
    .just_box                     = 0,
    .last_line_fill               = 0,
    .no_shrink_error_yet          = 0,
    .callback_id                  = 0, 
    .threshold                    = 0,
    .adjust_spacing               = 0,
    .adjust_spacing_step          = 0,
    .adjust_spacing_shrink        = 0,
    .adjust_spacing_stretch       = 0,
    .current_font_step            = 0,
    .passive                      = 0,
    .printed_node                 = 0,
    .serial_number                = 0,
    .active_width                 = { 0 },
    .background                   = { 0 },
    .break_width                  = { 0 },
    .internal_interline_penalty   = 0,
    .internal_broken_penalty      = 0,
    .internal_left_box            = null,
    .internal_left_box_width      = 0,
    .internal_left_box_init       = 0,
    .internal_left_box_width_init = 0,
    .internal_right_box           = null,
    .internal_right_box_width     = 0,
    .internal_middle_box          = null,
    .disc_width                   = { 0 },
    .minimal_demerits             = { 0 },
    .minimum_demerits             = 0,
    .easy_line                    = 0,
    .last_special_line            = 0,
    .first_width                  = 0,
    .second_width                 = 0,
    .first_indent                 = 0,
    .second_indent                = 0,
    .best_bet                     = 0,
    .fewest_demerits              = 0,
    .best_line                    = 0,
    .actual_looseness             = 0,
    .line_difference              = 0,
    .do_last_line_fit             = 0,
    .fill_width                   = { 0 },
    .dir_ptr                      = 0,
    .warned                       = 0,
    .calling_back                 = 0,
    .saved_threshold              = 0,
    .global_threshold             = 0,
    .line_break_dir               = 0,
    .checked_expansion            = -1,
    .passes                       = { { 0, 0, 0, 0 } },
    .n_of_left_twins              = 0,
    .n_of_right_twins             = 0,
    .n_of_double_twins            = 0,
    .internal_par_node            = null,
};

/*tex
    We could use a bit larger array and glue_orders where normal starts at 0 so we then need a larger
    array. Let's not do that now.
*/

typedef enum fill_orders {
    fi_order    = 0,
    fil_order   = 1,
    fill_order  = 2,
    filll_order = 3,
} fill_orders;

/*tex

    The |just_box| variable has the |hlist_node| for the last line of the new paragraph. In it's
    complete form, |line_break| is a rather lengthy procedure --- sort of a small world unto itself
    --- we must build it up little by little. Below you see only the general outline. The main task
    performed here is to move the list from |head| to |temp_head| and go into the enclosing semantic
    level. We also append the |\parfillskip| glue to the end of the paragraph, removing a space (or
    other glue node) if it was there, since spaces usually precede blank lines and instances of
    |$$|. The |par_fill_skip| is preceded by an infinite penalty, so it will never be considered as
    a potential breakpoint.

 */

void tex_line_break_prepare(
    halfword par,
    halfword *tail,
    halfword *parinit_left_skip_glue,
    halfword *parinit_right_skip_glue,
    halfword *parfill_left_skip_glue,
    halfword *parfill_right_skip_glue,
    halfword *final_line_penalty
)
{
    /* too much testing of next .. it needs checking anyway */
    if (node_type(par) == par_node) { /* maybe check for h|v subtype */
        if (tracing_linebreak_lists) {
            tex_begin_diagnostic();
            tex_print_format("[linebreak: prepare, before]");
            tex_show_box(par);
            tex_end_diagnostic();
        }
        *tail = *tail ? *tail : tex_tail_of_node_list(par);
        *final_line_penalty = tex_new_penalty_node(infinite_penalty, line_penalty_subtype);
        *parfill_left_skip_glue = tex_new_glue_node(tex_get_par_par(par, par_par_fill_left_skip_code), par_fill_left_skip_glue);
        *parfill_right_skip_glue = tex_new_glue_node(tex_get_par_par(par, par_par_fill_right_skip_code), par_fill_right_skip_glue);
        *parinit_left_skip_glue = null;
        *parinit_right_skip_glue = null;
        if (par != *tail && node_type(*tail) == glue_node && ! tex_is_par_init_glue(*tail)) {
            halfword prev = node_prev(*tail);
            node_next(prev) = null;
            tex_flush_node(*tail);
            *tail = prev;
        }
        tex_attach_attribute_list_copy(*final_line_penalty, par);
        tex_attach_attribute_list_copy(*parfill_left_skip_glue, par);
        tex_attach_attribute_list_copy(*parfill_right_skip_glue, par);
        tex_try_couple_nodes(*tail, *final_line_penalty);
        tex_try_couple_nodes(*final_line_penalty, *parfill_left_skip_glue);
        tex_try_couple_nodes(*parfill_left_skip_glue, *parfill_right_skip_glue);
        *tail = *parfill_right_skip_glue;
        if (node_next(par)) {
            halfword p = par;
            halfword n = node_next(par);
            while (node_next(p) && node_type(node_next(p)) == dir_node) {
                p = node_next(p);
            }
            while (n) {
                if (node_type(n) == glue_node && node_subtype(n) == indent_skip_glue) {
                    *parinit_left_skip_glue = tex_new_glue_node(tex_get_par_par(par, par_par_init_left_skip_code), par_init_left_skip_glue);
                    *parinit_right_skip_glue = tex_new_glue_node(tex_get_par_par(par, par_par_init_right_skip_code), par_init_right_skip_glue);
                    tex_attach_attribute_list_copy(*parinit_left_skip_glue, par);
                    tex_attach_attribute_list_copy(*parinit_right_skip_glue, par);
                    tex_try_couple_nodes(*parinit_right_skip_glue, n);
                    tex_try_couple_nodes(*parinit_left_skip_glue, *parinit_right_skip_glue);
                 // tex_try_couple_nodes(par, *parinit_left_skip_glue);
                    tex_try_couple_nodes(p, *parinit_left_skip_glue);
                    break;
                } else {
                    n = node_next(n); /* sort of weird and tricky */
                }
            }
        }
        if (tracing_linebreak_lists) {
            tex_begin_diagnostic();
            tex_print_format("[linebreak: prepare, after]");
            tex_show_box(par);
            tex_end_diagnostic();
        }
    }
}

void tex_line_break(int group_context, int par_context, int display_math)
{
    halfword head = node_next(cur_list.head);
    /*tex There should be a local par node at the beginning! */
    if (node_type(head) == par_node) { /* maybe check for h|v subtype */
        /*tex We need this for over- or underfull box messages. */
        halfword tail = cur_list.tail;
        lmt_packaging_state.pack_begin_line = cur_list.mode_line;
        node_prev(head) = null;
        /*tex Hyphenate, driven by callback or fallback to normal \TEX. */
        if (tex_list_has_glyph(head)) {
            tex_handle_hyphenation(head, tail);
            head = tex_handle_glyphrun(head, group_context, par_dir(head));
            tail = tex_tail_of_node_list(head);
            tex_try_couple_nodes(cur_list.head, head);
            cur_list.tail = tail;
        }
        /*tex We remove (only one) trailing glue node, when present. */
     // if (head != tail && node_type(tail) == glue_node && ! tex_is_par_init_glue(tail)) {
     //     halfword prev = node_prev(tail);
     //     node_next(prev) = null;
     //     tex_flush_node(tail);
     //     cur_list.tail = prev;
     // }
        node_next(temp_head) = head;
        /*tex There should be a local par node at the beginning! */
        if (node_type(head) == par_node) { /* maybe check for h|v subtype */
            /*tex
                The tail thing is a bit weird here as it's not the tail. One day I will look into
                this. One complication is that we have the normal break routing or a callback that
                replaces it but that callback can call the normal routine itself with specific
                parameters set.
            */
            halfword start_of_par;
            halfword par = head;
            halfword parinit_left_skip_glue = null;
            halfword parinit_right_skip_glue = null;
            halfword parfill_left_skip_glue = null;
            halfword parfill_right_skip_glue = null;
            halfword final_line_penalty = null;
            tex_line_break_prepare(par, &tail, &parinit_left_skip_glue, &parinit_right_skip_glue, &parfill_left_skip_glue, &parfill_right_skip_glue, &final_line_penalty);
            cur_list.tail = tail;
            /*tex
                We start with a prepared list. If you mess with that the linebreak routine might not
                work well especially if the pointers are messed up. So be it.
            */
            lmt_node_filter_callback(pre_linebreak_filter_callback, group_context, temp_head, &(cur_list.tail));
            /*tex
                We assume that the list is still okay.
            */
            lmt_linebreak_state.last_line_fill = cur_list.tail;
            tex_pop_nest();
            start_of_par = cur_list.tail;
            lmt_linebreak_state.calling_back = 1;
            if (lmt_linebreak_callback(temp_head, display_math, &(cur_list.tail))) {
                /*tex
                    When we end up here we have a prepared list so we need to make sure that when
                    the callback usaes that list with the built in break routine we don't do that
                    twice. One should work on copies! Afterwards we need to find the correct value
                    for the |just_box|.
                */
                halfword box_search = cur_list.tail;
                lmt_linebreak_state.just_box  = null;
                if (box_search) {
                    do {
                        if (node_type(box_search) == hlist_node) {
                           lmt_linebreak_state.just_box = box_search;
                        }
                        box_search = node_next(box_search);
                    } while (box_search);
                }
                if (! lmt_linebreak_state.just_box) {
                    tex_handle_error(
                        succumb_error_type,
                        "Invalid linebreak_filter",
                        "A linebreaking routine should return a non-empty list of nodes and at least one\n"
                        "of those has to be a \\hbox. Sorry, I cannot recover from this."
                    );
                }
            } else {
                line_break_properties properties = {
                    .initial_par             = par,
                    .group_context           = group_context,
                    .par_context             = par_context,
                    .tracing_paragraphs      = tracing_paragraphs_par,
                    .tracing_fitness         = tracing_fitness_par,
                    .tracing_passes          = tracing_passes_par,
                    .paragraph_dir           = par_dir(par),
                    .parfill_left_skip       = parfill_left_skip_glue,
                    .parfill_right_skip      = parfill_right_skip_glue,
                    .parinit_left_skip       = parinit_left_skip_glue,
                    .parinit_right_skip      = parinit_right_skip_glue,
                    .tolerance               = tex_get_par_par(par, par_tolerance_code),
                    .emergency_stretch       = tex_get_par_par(par, par_emergency_stretch_code),
                    .emergency_original      = 0, /*tex This one is set afterwards. */
                    .looseness               = tex_get_par_par(par, par_looseness_code),
                    .adjust_spacing          = tex_get_par_par(par, par_adjust_spacing_code),
                    .protrude_chars          = tex_get_par_par(par, par_protrude_chars_code),
                    .adj_demerits            = tex_get_par_par(par, par_adj_demerits_code),
                    .line_penalty            = tex_get_par_par(par, par_line_penalty_code),
                    .last_line_fit           = tex_get_par_par(par, par_last_line_fit_code),
                    .double_hyphen_demerits  = tex_get_par_par(par, par_double_hyphen_demerits_code),
                    .final_hyphen_demerits   = tex_get_par_par(par, par_final_hyphen_demerits_code),
                    .hsize                   = tex_get_par_par(par, par_hsize_code),
                    .left_skip               = tex_get_par_par(par, par_left_skip_code),
                    .right_skip              = tex_get_par_par(par, par_right_skip_code),
                    .emergency_left_skip     = tex_get_par_par(par, par_emergency_left_skip_code),
                    .emergency_right_skip    = tex_get_par_par(par, par_emergency_right_skip_code),
                    .pretolerance            = tex_get_par_par(par, par_pre_tolerance_code),
                    .hang_indent             = tex_get_par_par(par, par_hang_indent_code),
                    .hang_after              = tex_get_par_par(par, par_hang_after_code),
                    .par_shape               = tex_get_par_par(par, par_par_shape_code),
                    .inter_line_penalty      = tex_get_par_par(par, par_inter_line_penalty_code),
                    .inter_line_penalties    = tex_get_par_par(par, par_inter_line_penalties_code),
                    .club_penalty            = tex_get_par_par(par, par_club_penalty_code),
                    .club_penalties          = tex_get_par_par(par, par_club_penalties_code),
                    .widow_penalty           = tex_get_par_par(par, par_widow_penalty_code),
                    .widow_penalties         = tex_get_par_par(par, par_widow_penalties_code),
                    .display_widow_penalty   = tex_get_par_par(par, par_display_widow_penalty_code),
                    .display_widow_penalties = tex_get_par_par(par, par_display_widow_penalties_code),
                    .broken_penalties        = tex_get_par_par(par, par_broken_penalties_code),
                    .orphan_penalty          = tex_get_par_par(par, par_orphan_penalty_code),
                    .toddler_penalty         = tex_get_par_par(par, par_toddler_penalty_code),
                    .left_twin_demerits      = tex_get_par_par(par, par_left_twin_demerits_code),
                    .right_twin_demerits     = tex_get_par_par(par, par_right_twin_demerits_code),
                    .single_line_penalty     = tex_get_par_par(par, par_single_line_penalty_code),
                    .hyphen_penalty          = tex_get_par_par(par, par_hyphen_penalty_code),
                    .ex_hyphen_penalty       = tex_get_par_par(par, par_ex_hyphen_penalty_code),
                    .orphan_penalties        = tex_get_par_par(par, par_orphan_penalties_code),
                    .fitness_demerits        = tex_get_par_par(par, par_fitness_demerits_code),
                    .broken_penalty          = tex_get_par_par(par, par_broken_penalty_code),
                    .baseline_skip           = tex_get_par_par(par, par_baseline_skip_code),
                    .line_skip               = tex_get_par_par(par, par_line_skip_code),
                    .line_skip_limit         = tex_get_par_par(par, par_line_skip_limit_code),
                    .adjust_spacing_step     = tex_get_par_par(par, par_adjust_spacing_step_code),
                    .adjust_spacing_shrink   = tex_get_par_par(par, par_adjust_spacing_shrink_code),
                    .adjust_spacing_stretch  = tex_get_par_par(par, par_adjust_spacing_stretch_code),
                    .hyphenation_mode        = tex_get_par_par(par, par_hyphenation_mode_code),
                    .shaping_penalties_mode  = tex_get_par_par(par, par_shaping_penalties_mode_code),
                    .shaping_penalty         = tex_get_par_par(par, par_shaping_penalty_code),
                    .emergency_extra_stretch = tex_get_par_par(par, par_emergency_extra_stretch_code),
                    .par_passes              = line_break_passes_par > 0 ? tex_get_par_par(par, par_par_passes_code) : 0,
                    .line_break_checks       = tex_get_par_par(par, par_line_break_checks_code),
                    .extra_hyphen_penalty    = 0,
                    .line_break_optional     = line_break_optional_par, /* hm, why different than above */
                    .math_penalty_factor     = 0,
                };
             /* properties.emergency_original = properties.emergency_stretch; */
                tex_do_line_break(&properties);
                /*tex
                    We assume that the list is still okay when we do some post line break stuff.
                */
            }
            lmt_linebreak_state.calling_back = 0;
            lmt_node_filter_callback(post_linebreak_filter_callback, group_context, start_of_par, &(cur_list.tail));
            lmt_packaging_state.pack_begin_line = 0;
            return;
        }
    }
    tex_confusion("missing local par node");
}

/*tex

    Glue nodes in a horizontal list that is being paragraphed are not supposed to include \quote
    {infinite} shrinkability; that is why the algorithm maintains four registers for stretching but
    only one for shrinking. If the user tries to introduce infinite shrinkability, the shrinkability
    will be reset to finite and an error message will be issued. A boolean variable
    |no_shrink_error_yet| prevents this error message from appearing more than once per paragraph.

    Beware, this does an in-place fix to the glue (which can be a register!). As we store glues a
    bit different we do a different fix here.

*/

static scaled tex_aux_checked_shrink(halfword p)
{
    if (glue_shrink(p) && glue_shrink_order(p) != normal_glue_order) {
        if (lmt_linebreak_state.no_shrink_error_yet) {
            lmt_linebreak_state.no_shrink_error_yet = 0;
            tex_handle_error(
                normal_error_type,
                "Infinite glue shrinkage found in a paragraph",
                "The paragraph just ended includes some glue that has infinite shrinkability,\n"
                "e.g., '\\hskip 0pt minus 1fil'. Such glue doesn't belong there---it allows a\n"
                "paragraph of any length to fit on one line. But it's safe to proceed, since the\n"
                "offensive shrinkability has been made finite."
            );
        }
        glue_shrink_order(p) = normal_glue_order;
    }
    return glue_shrink(p);
}

/*tex

    A pointer variable |cur_p| runs through the given horizontal list as we look for breakpoints.
    This variable is global, since it is used both by |line_break| and by its subprocedure
    |try_break|.

    Another global variable called |threshold| is used to determine the feasibility of individual
    lines: breakpoints are feasible if there is a way to reach them without creating lines whose
    badness exceeds |threshold|. (The badness is compared to |threshold| before penalties are
    added, so that penalty values do not affect the feasibility of breakpoints, except that no
    break is allowed when the penalty is 10000 or more.) If |threshold| is 10000 or more, all
    legal breaks are considered feasible, since the |badness| function specified above never
    returns a value greater than~10000.

    Up to three passes might be made through the paragraph in an attempt to find at least one set
    of feasible breakpoints. On the first pass, we have |threshold = pretolerance| and |second_pass
    = final_pass = false|. If this pass fails to find a feasible solution, |threshold| is set to
    |tolerance|, |second_pass| is set |true|, and an attempt is made to hyphenate as many words as
    possible. If that fails too, we add |emergency_stretch| to the background stretchability and
    set |final_pass = true|.

    |second_pass| is this our second attempt to break this paragraph and |final_path| our final
    attempt to break this paragraph while |threshold| is the maximum badness on feasible lines.

    The maximum fill level for |hlist_stack|. Maybe good if larger than |2 * max_quarterword|, so
    that box nesting level would overflow first. The stack for |find_protchar_left()| and
    |find_protchar_right()|; |hlist_stack_level| is the fill level for |hlist_stack|

*/

# define max_hlist_stack 512

/* We can optimize this when we have a global setting. */

static inline int  tex_has_glyph_expansion(halfword a) 
{ 
    return 
        ! ((glyph_options(a) & glyph_option_no_expansion) == glyph_option_no_expansion) 
        && has_font_text_control(glyph_font(a), text_control_expansion);
}

/*tex

    Search left to right from list head |l|, returns 1st non-skipable item:

*/

static halfword tex_aux_find_protchar_left(halfword l, int d)
{
    int done = 0 ;
    halfword initial = l;
    while (node_next(l) && node_type(l) == hlist_node && tex_zero_box_dimensions(l) && ! box_list(l)) {
        /*tex For paragraph start with |\parindent = 0pt| or any empty hbox. */
        l = node_next(l);
        done = 1 ;
    }
    if (! done && node_type(l) == par_node) { /* maybe check for h|v subtype */
        l = node_next(l);
        done = 1 ;
    }
    if (! done && d) {
        while (node_next(l) && ! (node_type(l) == glyph_node || non_discardable(l))) {
            /*tex standard discardables at line break, \TEX book, p 95 */
            l = node_next(l);
        }
    }
    if (node_type(l) != glyph_node) {
        halfword t;
        int run = 1;
        halfword hlist_stack[max_hlist_stack];
        int hlist_stack_level = 0;
        do {
            t = l;
            while (run && node_type(l) == hlist_node && box_list(l)) {
                if (hlist_stack_level >= max_hlist_stack) {
                 /* return tex_normal_error("push_node", "stack overflow"); */
                    return initial;
                } else {
                    hlist_stack[hlist_stack_level++] = l;
                }
                l = box_list(l);
            }
            while (run && tex_protrusion_skipable(l)) {
                while (! node_next(l) && hlist_stack_level > 0) {
                    /*tex Don't visit this node again. */
                    if (hlist_stack_level <= 0) {
                        /*tex This can point to some bug. */
                     /* return tex_normal_error("pop_node", "stack underflow (internal error)"); */
                        return initial;
                    } else {
                        l = hlist_stack[--hlist_stack_level];
                    }
                    run = 0;
                }
                if (node_next(l) && node_type(l) == boundary_node && node_subtype(l) == protrusion_boundary && (boundary_data(l) == protrusion_skip_next || boundary_data(l) == protrusion_skip_both)) {
                    /*tex Skip next node. */
                    l = node_next(l);
                }
                if (node_next(l)) {
                    l = node_next(l);
                } else if (hlist_stack_level == 0) {
                    run = 0;
                }
            }
        } while (t != l);
    }
    return l;
}

/*tex

    Search right to left from list tail |r| to head |l|, returns 1st non-skipable item.

*/

static halfword tex_aux_find_protchar_right(halfword l, halfword r)
{
    if (r) {
        halfword t;
        int run = 1;
        halfword initial = r;
        halfword hlist_stack[max_hlist_stack];
        int hlist_stack_level = 0;
        do {
            t = r;
            while (run && node_type(r) == hlist_node && box_list(r)) {
                if (hlist_stack_level >= max_hlist_stack) {
                 /* tex_normal_error("push_node", "stack overflow"); */
                    return initial;
                } else {
                    hlist_stack[hlist_stack_level++] = l;
                }
                if (hlist_stack_level >= max_hlist_stack) {
                 /* tex_normal_error("push_node", "stack overflow"); */
                    return initial;
                } else {
                    hlist_stack[hlist_stack_level++] = r;
                }
                l = box_list(r);
                r = l;
                while (node_next(r)) {
                    halfword s = r;
                    r = node_next(r);
                    node_prev(r) = s;
                }
            }
            while (run && tex_protrusion_skipable(r)) {
                while (r == l && hlist_stack_level > 0) {
                    /*tex Don't visit this node again. */
                    if (hlist_stack_level <= 0) {
                        /*tex This can point to some bug. */
                        /* return tex_normal_error("pop_node", "stack underflow (internal error)"); */
                        return initial;
                    } else {
                        r = hlist_stack[--hlist_stack_level];
                    }

                    if (hlist_stack_level <= 0) {
                        /*tex This can point to some bug. */
                     /* return tex_normal_error("pop_node", "stack underflow (internal error)"); */
                        return initial;
                    } else {
                        l = hlist_stack[--hlist_stack_level];
                    }
                }
                if ((r != l) && r) {
                    if (node_prev(r) && node_type(r) == boundary_node && node_subtype(r) == protrusion_boundary && (boundary_data(r) == protrusion_skip_previous || boundary_data(r) == protrusion_skip_both)) {
                        /*tex Skip next node. */
                        r = node_prev(r);
                    }
                    if (node_prev(r)) {
                        r = node_prev(r);
                    } else {
                        /*tex This is the input: |\leavevmode \penalty -10000 \penalty -10000| */
                        run = 0;
                    }
                } else if (r == l && hlist_stack_level == 0) {
                    run = 0;
                }
            }
        } while (t != r);
    }
    return r;
}

/*tex

    The algorithm essentially determines the best possible way to achieve each feasible combination
    of position, line, and fitness. Thus, it answers questions like, \quotation {What is the best
    way to break the opening part of the paragraph so that the fourth line is a tight line ending at
    such-and-such a place?} However, the fact that all lines are to be the same length after a
    certain point makes it possible to regard all sufficiently large line numbers as equivalent, when
    the looseness parameter is zero, and this makes it possible for the algorithm to save space and
    time.

    An \quote {active node} and a \quote {passive node} are created in |mem| for each feasible
    breakpoint that needs to be considered. Active nodes are three words long and passive nodes
    are two words long. We need active nodes only for breakpoints near the place in the
    paragraph that is currently being examined, so they are recycled within a comparatively short
    time after they are created.

    An active node for a given breakpoint contains six fields:

    \startitemize[n]

        \startitem
            |vlink| points to the next node in the list of active nodes; the last active node has
            |vlink=active|.
        \stopitem

        \startitem
            |break_node| points to the passive node associated with this breakpoint.
        \stopitem

        \startitem
            |line_number| is the number of the line that follows this breakpoint.
        \stopitem

        \startitem
            |fitness| is the fitness classification of the line ending at this breakpoint.
        \stopitem

        \startitem
            |type| is either |hyphenated_node| or |unhyphenated_node|, depending on whether this
            breakpoint is a |disc_node|.
        \stopitem

        \startitem
            |total_demerits| is the minimum possible sum of demerits over all lines leading from
            the beginning of the paragraph to this breakpoint.
        \stopitem

    \stopitemize

    The value of |node_next(active)| points to the first active node on a vlinked list of all currently
    active nodes. This list is in order by |line_number|, except that nodes with |line_number >
    easy_line| may be in any order relative to each other.

*/

# define default_fit 0

void tex_initialize_active(void)
{
    node_type(active_head) = hyphenated_node;
    active_line_number(active_head) = max_halfword;
    /*tex
        The |subtype| is actually the |fitness|. It is set with |new_node| to one of the fitness
        values.
    */
    active_fitness(active_head) = default_fit;
}

/*tex

    The passive node for a given breakpoint contains eight fields:

    \startitemize

        \startitem
            |vlink| points to the passive node created just before this one, if any, otherwise it
            is |null|.
        \stopitem

        \startitem
            |cur_break| points to the position of this breakpoint in the horizontal list for the
            paragraph being broken.
        \stopitem

        \startitem
            |prev_break| points to the passive node that should precede this one in an optimal path
            to this breakpoint.
        \stopitem

        \startitem
            |serial| is equal to |n| if this passive node is the |n|th one created during the
            current pass. (This field is used only when printing out detailed statistics about the
            line-breaking calculations.)
        \stopitem

        \startitem
            |passive_interline_penalty| holds the current |localinterlinepenalty|
        \stopitem

        \startitem
            |passive_broken_penalty| holds the current |localbrokenpenalty|
        \stopitem

    \stopitemize

    There is a global variable called |passive| that points to the most recently created passive
    node. Another global variable, |printed_node|, is used to help print out the paragraph when
    detailed information about the line-breaking computation is being displayed.

    The most recent node on passive list, the most recent node that has been printed, and the number
    of passive nodes allocated on this pass, is registered in the passive field.

    The active list also contains \quote {delta} nodes that help the algorithm compute the badness
    of individual lines. Such nodes appear only between two active nodes, and they have |type =
    delta_node|. If |p| and |r| are active nodes and if |q| is a delta node between them, so that
    |vlink (p) = q| and |vlink (q) = r|, then |q| tells the space difference between lines in the
    horizontal list that start after breakpoint |p| and lines that start after breakpoint |r|. In
    other words, if we know the length of the line that starts after |p| and ends at our current
    position, then the corresponding length of the line that starts after |r| is obtained by adding
    the amounts in node~|q|. A delta node contains seven scaled numbers, since it must record the
    net change in glue stretchability with respect to all orders of infinity. The natural width
    difference appears in |mem[q+1].sc|; the stretch differences in units of pt, sfi, fil, fill,
    and filll appear in |mem[q + 2 .. q + 6].sc|; and the shrink difference appears in |mem[q +
    7].sc|. The |subtype| field of a delta node is not used.

    {\em NB: Actually, we have more fields now.}

    As the algorithm runs, it maintains a set of seven delta-like registers for the length of the
    line following the first active breakpoint to the current position in the given hlist. When it
    makes a pass through the active list, it also maintains a similar set of seven registers for
    the length following the active breakpoint of current interest. A third set holds the length
    of an empty line (namely, the sum of |\leftskip| and |\rightskip|); and a fourth set is used
    to create new delta nodes.

    When we pass a delta node we want to do operations like:

    \starttyping
    for k := 1 to 7 do
        cur_active_width[k] := cur_active_width[k] + mem[q+k].sc|};
    \stoptyping

    and we want to do this without the overhead of |for| loops so we use update macros.

    |active_width| is he distance from first active node to~|cur_p|, |background| the length of an
    \quote {empty} line, and |break_width| the length being computed after current break.

    We make |auto_breaking| accessible out of |line_break|.

    Let's state the principles of the delta nodes more precisely and concisely, so that the
    following programs will be less obscure. For each legal breakpoint~|p| in the paragraph, we
    define two quantities $\alpha(p)$ and $\beta(p)$ such that the length of material in a line
    from breakpoint~|p| to breakpoint~|q| is $\gamma+\beta(q)-\alpha(p)$, for some fixed $\gamma$.
    Intuitively, $\alpha(p)$ and $\beta(q)$ are the total length of material from the beginning
    of the paragraph to a point after a break at |p| and to a point before a break at |q|; and
    $\gamma$ is the width of an empty line, namely the length contributed by |\leftskip| and
    |\rightskip|.

    Suppose, for example, that the paragraph consists entirely of alternating boxes and glue
    skips; let the boxes have widths $x_1\ldots x_n$ and let the skips have widths $y_1\ldots
    y_n$, so that the paragraph can be represented by $x_1y_1\ldots x_ny_n$. Let $p_i$ be the
    legal breakpoint at $y_i$; then $\alpha(p_i) = x_1 + y_1 + \cdots + x_i + y_i$, and $\beta
    (p_i) = x_1 + y_1 + \cdots + x_i$. To check this, note that the length of material from
    $p_2$ to $p_5$, say, is $\gamma + x_3 + y_3 + x_4 + y_4 + x_5 = \gamma + \beta (p_5) -
    \alpha (p_2)$.

    The quantities $\alpha$, $\beta$, $\gamma$ involve glue stretchability and shrinkability as
    well as a natural width. If we were to compute $\alpha(p)$ and $\beta(p)$ for each |p|, we
    would need multiple precision arithmetic, and the multiprecise numbers would have to be kept
    in the active nodes. \TeX\ avoids this problem by working entirely with relative differences
    or \quote {deltas}. Suppose, for example, that the active list contains $a_1\,\delta_1\,a_2\,
    \delta_2\,a_3$, where the |a|'s are active breakpoints and the $\delta$'s are delta nodes.
    Then $\delta_1 = \alpha(a_1) - \alpha(a_2)$ and $\delta_2 = \alpha(a_2) - \alpha(a_3)$. If the
    line breaking algorithm is currently positioned at some other breakpoint |p|, the |active_width|
    array contains the value $\gamma  +\beta(p) - \alpha(a_1)$. If we are scanning through the list
    of active nodes and considering a tentative line that runs from $a_2$ to~|p|, say, the
    |cur_active_width| array will contain the value $\gamma + \beta(p) - \alpha(a_2)$. Thus, when we
    move from $a_2$ to $a_3$, we want to add $\alpha(a_2) - \alpha(a_3)$ to |cur_active_width|; and
    this is just $\delta_2$, which appears in the active list between $a_2$ and $a_3$. The
    |background| array contains $\gamma$. The |break_width| array will be used to calculate values
    of new delta nodes when the active list is being updated.

    The heart of the line-breaking procedure is |try_break|, a subroutine that tests if the current
    breakpoint |cur_p| is feasible, by running through the active list to see what lines of text
    can be made from active nodes to~|cur_p|. If feasible breaks are possible, new break nodes are
    created. If |cur_p| is too far from an active node, that node is deactivated.

    The parameter |pi| to |try_break| is the penalty associated with a break at |cur_p|; we have
    |pi = eject_penalty| if the break is forced, and |pi = inf_penalty| if the break is illegal.

    The other parameter, |break_type|, is set to |hyphenated_node| or |unhyphenated_node|, depending
    on whether or not the current break is at a |disc_node|. The end of a paragraph is also regarded
    as |hyphenated_node|; this case is distinguishable by the condition |cur_p = null|.

    \startlines
    |internal_interline_penalty|   running |\localinterlinepenalty|
    |internal_broken_penalty|      running |\localbrokenpenalty|
    |internal_left_box|            running |\localleftbox|
    |internal_left_box_width|      running |\localleftbox|
    |init_internal_left_box|       running |\localleftbox|
    |init_internal_left_box_width| running |\localleftbox| width
    |internal_right_box|           running |\localrightbox|
    |internal_right_box_width|     running |\localrightbox| width
    |disc_width|                   the length of discretionary material preceding a break
    \stoplines

    As we consider various ways to end a line at |cur_p|, in a given line number class, we keep
    track of the best total demerits known, in an array with one entry for each of the fitness
    classifications. For example, |minimal_demerits [tight_fit]| contains the fewest total
    demerits of feasible line breaks ending at |cur_p| with a |tight_fit| line; |best_place
    [tight_fit]| points to the passive node for the break before |cur_p| that achieves such an
    optimum; and |best_pl_line[tight_fit]| is the |line_number| field in the active node
    corresponding to |best_place [tight_fit]|. When no feasible break sequence is known, the
    |minimal_demerits| entries will be equal to |awful_bad|, which is $2^{30}-1$. Another variable,
    |minimum_demerits|, keeps track of the smallest value in the |minimal_demerits| array.

    The length of lines depends on whether the user has specified |\parshape| or |\hangindent|. If
    |par_shape_ptr| is not null, it points to a $(2n+1)$-word record in |mem|, where the |vinfo|
    in the first word contains the value of |n|, and the other $2n$ words contain the left margins
    and line lengths for the first |n| lines of the paragraph; the specifications for line |n|
    apply to all subsequent lines. If |par_shape_ptr = null|, the shape of the paragraph depends on
    the value of |n = hang_after|; if |n >= 0|, hanging indentation takes place on lines |n + 1|,
    |n + 2|, \dots, otherwise it takes place on lines 1, \dots, $\vert n\vert$. When hanging
    indentation is active, the left margin is |hang_indent|, if |hang_indent >= 0|, else it is 0;
    the line length is $|hsize|-\vert|hang_indent|\vert$. The normal setting is |par_shape_ptr =
    null|, |hang_after = 1|, and |hang_indent = 0|. Note that if |hang_indent = 0|, the value of
    |hang_after| is irrelevant.

    Some more variables and remarks:

    line numbers |> easy_line| are equivalent in break nodes

    line numbers |> last_special_line| all have the same width

    |first_width| is the width of all lines |<= last_special_line|, if no |\parshape| has been
    specified

    |second_width| is the width of all lines |> last_special_line|

    |first_indent| is the left margin to go with |first_width|

    |second_indent| s the left margin to go with |second_width|

    |best_bet| indicated the passive node and its predecessors

    |fewest_demerits| are the demerits associated with |best_bet|

    |best_line| is the line number following the last line of the new paragraph

    |actual_looseness| is the difference between |line_number (best_bet)| and the optimum
    |best_line|

    |line_diff| is the difference between the current line number and the optimum |best_line|

    \TEX\ makes use of the fact that |hlist_node|, |vlist_node|, |rule_node|, |insert_node|,
    |mark_node|, |adjust_node|, |disc_node|, |whatsit_node|, and |math_node| are at the low end of
    the type codes, by permitting a break at glue in a list if and only if the |type| of the
    previous node is less  than |math_node|. Furthermore, a node is discarded after a break if its
    type is |math_node| or~more.

*/

static void tex_aux_clean_up_the_memory(void)
{
    halfword q = node_next(active_head);
    while (q != active_head) {
        halfword p = node_next(q);
     // tex_free_node(q, get_node_size(node_type(q))); // less overhead & testing
        tex_flush_node(q);
        q = p;
    }
    q = lmt_linebreak_state.passive;
    while (q) {
        halfword p = node_next(q);
     // tex_free_node(q, get_node_size(node_type(q))); // less overhead & testing
        tex_flush_node(q);
        q = p;
    }
}

/*tex
    Instead of macros we use inline functions. Nowadays compilers generate code that is quite
    similar as when we use macros (and sometimes even better).
*/

inline static void tex_aux_add_disc_source_to_target(halfword adjust_spacing, scaled target[], const scaled source[])
{
    target[total_advance_amount] += source[total_advance_amount];
    if (adjust_spacing) {
        target[font_stretch_amount] += source[font_stretch_amount];
        target[font_shrink_amount]  += source[font_shrink_amount];
    }
}

inline static void tex_aux_sub_disc_target_from_source(halfword adjust_spacing, scaled target[], const scaled source[])
{
    target[total_advance_amount] -= source[total_advance_amount];
    if (adjust_spacing) {
        target[font_stretch_amount] -= source[font_stretch_amount];
        target[font_shrink_amount]  -= source[font_shrink_amount];
    }
}

inline static void tex_aux_reset_disc_target(halfword adjust_spacing, scaled *target)
{
    target[total_advance_amount] = 0;
    if (adjust_spacing) {
        target[font_stretch_amount] = 0;
        target[font_shrink_amount]  = 0;
    }
}

/* A memcopy for the whole array is probably more efficient. */

inline static void tex_aux_set_target_to_source(halfword adjust_spacing, scaled target[], const scaled source[])
{
 // memcpy(&target[total_glue_amount], &source[total_glue_amount], font_shrink_amount * sizeof(halfword));
    for (int i = total_advance_amount; i <= total_shrink_amount; i++) {
        target[i] = source[i];
    }
    if (adjust_spacing) {
        target[font_stretch_amount] = source[font_stretch_amount];
        target[font_shrink_amount]  = source[font_shrink_amount];
    }
}

/*
    These delta nodes use an offset and as a result we waste half of the memory words. So, by not
    using an offset but just named fields, we can save 4 memory words (32 bytes) per delta node. So,
    instead of this:

    \starttyping
    inline void add_to_target_from_delta(halfword adjust_spacing, scaled *target, halfword delta)
    {
        for (int i = total_glue_amount; i <= total_shrink_amount; i++) {
            target[i] += delta_field(delta, i);
        }
        if (adjust_spacing) {
            target[font_stretch_amount] += delta_field(delta, font_stretch_amount);
            target[font_shrink_amount]  += delta_field(delta, font_shrink_amount);
        }
    }
    \stoptyping

    We use the more verbose variants and let the compiler optimize the lot.

*/

inline static void tex_aux_add_to_target_from_delta(halfword adjust_spacing, scaled target[], halfword delta)
{
    target[total_advance_amount] += delta_field_total_glue(delta);
    target[total_stretch_amount] += delta_field_total_stretch(delta);
    target[total_fi_amount]      += delta_field_total_fi_amount(delta);
    target[total_fil_amount]     += delta_field_total_fil_amount(delta);
    target[total_fill_amount]    += delta_field_total_fill_amount(delta);
    target[total_filll_amount]   += delta_field_total_filll_amount(delta);
    target[total_shrink_amount]  += delta_field_total_shrink(delta);
    if (adjust_spacing) {
        target[font_stretch_amount] += delta_field_font_stretch(delta);
        target[font_shrink_amount]  += delta_field_font_shrink(delta);
    }
}

inline static void tex_aux_sub_delta_from_target(halfword adjust_spacing, scaled target[], halfword delta)
{
    target[total_advance_amount] -= delta_field_total_glue(delta);
    target[total_stretch_amount] -= delta_field_total_stretch(delta);
    target[total_fi_amount]      -= delta_field_total_fi_amount(delta);
    target[total_fil_amount]     -= delta_field_total_fil_amount(delta);
    target[total_fill_amount]    -= delta_field_total_fill_amount(delta);
    target[total_filll_amount]   -= delta_field_total_filll_amount(delta);
    target[total_shrink_amount]  -= delta_field_total_shrink(delta);
    if (adjust_spacing) {
        target[font_stretch_amount] -= delta_field_font_stretch(delta);
        target[font_shrink_amount]  -= delta_field_font_shrink(delta);
    }
}

inline static void tex_aux_add_to_delta_from_delta(halfword adjust_spacing, halfword target, halfword source)
{
    delta_field_total_glue(target)         += delta_field_total_glue(source);
    delta_field_total_stretch(target)      += delta_field_total_stretch(source);
    delta_field_total_fi_amount(target)    += delta_field_total_fi_amount(source);
    delta_field_total_fil_amount(target)   += delta_field_total_fil_amount(source);
    delta_field_total_fill_amount(target)  += delta_field_total_fill_amount(source);
    delta_field_total_filll_amount(target) += delta_field_total_filll_amount(source);
    delta_field_total_shrink(target)       += delta_field_total_shrink(source);
    if (adjust_spacing) {
        delta_field_font_stretch(target) += delta_field_font_stretch(source);
        delta_field_font_shrink(target)  += delta_field_font_shrink(source);
    }
}

inline static void tex_aux_set_delta_from_difference(halfword adjust_spacing, halfword delta, const scaled source_1[], const scaled source_2[])
{
    delta_field_total_glue(delta)         = (source_1[total_advance_amount] - source_2[total_advance_amount]);
    delta_field_total_stretch(delta)      = (source_1[total_stretch_amount] - source_2[total_stretch_amount]);
    delta_field_total_fi_amount(delta)    = (source_1[total_fi_amount]      - source_2[total_fi_amount]);
    delta_field_total_fil_amount(delta)   = (source_1[total_fil_amount]     - source_2[total_fil_amount]);
    delta_field_total_fill_amount(delta)  = (source_1[total_fill_amount]    - source_2[total_fill_amount]);
    delta_field_total_filll_amount(delta) = (source_1[total_filll_amount]   - source_2[total_filll_amount]);
    delta_field_total_shrink(delta)       = (source_1[total_shrink_amount]  - source_2[total_shrink_amount]);
    if (adjust_spacing) {
        delta_field_font_stretch(delta) = (source_1[font_stretch_amount] - source_2[font_stretch_amount]);
        delta_field_font_shrink(delta)  = (source_1[font_shrink_amount]  - source_2[font_shrink_amount]);
    }
}

inline static void tex_aux_add_delta_from_difference(halfword adjust_spacing, halfword delta, const scaled source_1[], const scaled source_2[])
{
    delta_field_total_glue(delta)         += (source_1[total_advance_amount] - source_2[total_advance_amount]);
    delta_field_total_stretch(delta)      += (source_1[total_stretch_amount] - source_2[total_stretch_amount]);
    delta_field_total_fi_amount(delta)    += (source_1[total_fi_amount]      - source_2[total_fi_amount]);
    delta_field_total_fil_amount(delta)   += (source_1[total_fil_amount]     - source_2[total_fil_amount]);
    delta_field_total_fill_amount(delta)  += (source_1[total_fill_amount]    - source_2[total_fill_amount]);
    delta_field_total_filll_amount(delta) += (source_1[total_filll_amount]   - source_2[total_filll_amount]);
    delta_field_total_shrink(delta)       += (source_1[total_shrink_amount]  - source_2[total_shrink_amount]);
    if (adjust_spacing) {
        delta_field_font_stretch(delta) += (source_1[font_stretch_amount] - source_2[font_stretch_amount]);
        delta_field_font_shrink(delta)  += (source_1[font_shrink_amount]  - source_2[font_shrink_amount]);
    }
}

/*tex

    This function is used to add the width of a list of nodes (from a discretionary) to one of the
    width arrays. Replacement texts and discretionary texts are supposed to contain only character
    nodes, kern nodes, and box or rule nodes.

    From now on we just ignore \quite {invalid} nodes. If any such node influences the width, so be
    it.

    \starttyping
    static void bad_node_in_disc_error(halfword p)
    {
        tex_formatted_error(
            "linebreak",
            "invalid node with type %s found in discretionary",
            node_data[node_type(p)].name
        );
    }
    \stoptyping
*/

static void tex_aux_add_to_widths(halfword s, int adjust_spacing, int adjust_spacing_step, scaled widths[])
{
    /* todo only check_expand_pars once per font (or don't check) */
    while (s) {
        switch (node_type(s)) {
            case glyph_node:
                widths[total_advance_amount] += tex_glyph_width(s);
                if (adjust_spacing && adjust_spacing_step > 0 && tex_has_glyph_expansion(s)) {
                    lmt_packaging_state.previous_char_ptr = s;
                    widths[font_stretch_amount] += tex_char_stretch(s);
                    widths[font_shrink_amount] += tex_char_shrink(s);
                };
                break;
            case hlist_node:
            case vlist_node:
                widths[total_advance_amount] += box_width(s);
                break;
            case rule_node:
                widths[total_advance_amount] += rule_width(s);
                break;
            case glue_node:
                widths[total_advance_amount] += glue_amount(s);
                widths[total_stretch_amount + glue_stretch_order(s)] += glue_stretch(s);
                widths[total_shrink_amount] += glue_shrink(s);
                break;
            case kern_node:
                widths[total_advance_amount] += kern_amount(s);
                if (adjust_spacing == adjust_spacing_full && node_subtype(s) == font_kern_subtype) {
                    halfword n = node_prev(s);
                    if (n && node_type(n) == glyph_node && ! tex_has_glyph_option(node_next(s), glyph_option_no_expansion)) {
                        widths[font_stretch_amount] += tex_kern_stretch(s);
                        widths[font_shrink_amount] += tex_kern_shrink(s);
                    }
                }
                break;
            case disc_node:
                break;
            default:
             /* bad_node_in_disc_error(s); */
                break;
        }
        s = node_next(s);
    }
}

/*tex

    This function is used to substract the width of a list of nodes (from a discretionary) from one
    of the width arrays. It is used only once, but deserves it own function because of orthogonality
    with the |add_to_widths| function.

*/

static void tex_aux_sub_from_widths(halfword s, int adjust_spacing, int adjust_spacing_step, scaled widths[])
{
    while (s) {
        /*tex Subtract the width of node |s| from |break_width|; */
        switch (node_type(s)) {
            case glyph_node:
                widths[total_advance_amount] -= tex_glyph_width(s);
                if (adjust_spacing && adjust_spacing_step > 0 && tex_has_glyph_expansion(s)) {
                    lmt_packaging_state.previous_char_ptr = s;
                    widths[font_stretch_amount] -= tex_char_stretch(s);
                    widths[font_shrink_amount] -= tex_char_shrink(s);
                }
                break;
            case hlist_node:
            case vlist_node:
                widths[total_advance_amount] -= box_width(s);
                break;
            case rule_node:
                widths[total_advance_amount] -= rule_width(s);
                break;
            case glue_node:
                widths[total_advance_amount] -= glue_amount(s);
                widths[total_stretch_amount + glue_stretch_order(s)] -= glue_stretch(s);
                widths[total_shrink_amount] -= glue_shrink(s);
                break;
            case kern_node:
                widths[total_advance_amount] -= kern_amount(s);
                if (adjust_spacing == adjust_spacing_full && node_subtype(s) == font_kern_subtype) {
                    halfword n = node_prev(s);
                    if (n && node_type(n) == glyph_node && ! tex_has_glyph_option(node_next(s), glyph_option_no_expansion)) {
                        widths[font_stretch_amount] -= tex_kern_stretch(s);
                        widths[font_shrink_amount] -= tex_kern_shrink(s);
                    }
                }
                break;
            case disc_node:
                break;
            default:
             /* bad_node_in_disc_error(s); */
                break;
        }
        s = node_next(s);
    }
}

/*tex

    When we insert a new active node for a break at |cur_p|, suppose this new node is to be placed
    just before active node |a|; then we essentially want to insert $\delta\,|cur_p|\,\delta ^
    \prime$ before |a|, where $\delta = \alpha (a) - \alpha (|cur_p|)$ and $\delta ^ \prime =
    \alpha (|cur_p|) - \alpha (a)$ in the notation explained above. The |cur_active_width| array
    now holds $\gamma + \beta (|cur_p|) - \alpha (a)$; so $\delta$ can be obtained by subtracting
    |cur_active_width| from the quantity $\gamma + \beta (|cur_p|) - \alpha (|cur_p|)$. The latter
    quantity can be regarded as the length of a line from |cur_p| to |cur_p|; we call it the
    |break_width| at |cur_p|.

    The |break_width| is usually negative, since it consists of the background (which is normally
    zero) minus the width of nodes following~|cur_p| that are eliminated after a break. If, for
    example, node |cur_p| is a glue node, the width of this glue is subtracted from the background;
    and we also look ahead to eliminate all subsequent glue and penalty and kern and math nodes,
    subtracting their widths as well.

    Kern nodes do not disappear at a line break unless they are |explicit|.

*/

static void tex_aux_compute_break_width(int break_type, int adjust_spacing, int adjust_spacing_step, halfword p)
{
    /*tex

        Glue and other whitespace to be skipped after a break; used if unhyphenated, or |post_break
        = null|.

    */
    halfword s = p;
    if (p) {
        switch (break_type) {
            case hyphenated_node:
            case delta_node:
            case passive_node:
                /*tex

                    Compute the discretionary |break_width| values. When |p| is a discretionary
                    break, the length of a line \quotation {from |p| to |p|} has to be defined
                    properly so that the other calculations work out. Suppose that the pre-break
                    text at |p| has length $l_0$, the post-break text has length $l_1$, and the
                    replacement text has length |l|. Suppose also that |q| is the node following
                    the replacement text. Then length of a line from |p| to |q| will be computed as
                    $\gamma + \beta (q) - \alpha (|p|)$, where $\beta (q) = \beta (|p|) - l_0 + l$.
                    The actual length will be the background plus $l_1$, so the length from |p| to
                    |p| should be $\gamma + l_0 + l_1 - l$. If the post-break text of the
                    discretionary is empty, a break may also discard~|q|; in that unusual case we
                    subtract the length of~|q| and any other nodes that will be discarded after the
                    discretionary break.

                    The value of $l_0$ need not be computed, since |line_break| will put it into the
                    global variable |disc_width| before calling |try_break|. In case of nested
                    discretionaries, we always follow the no-break path, as we are talking about the
                    breaking on {\it this} position.

                */
                tex_aux_sub_from_widths(disc_no_break_head(p), adjust_spacing, adjust_spacing_step, lmt_linebreak_state.break_width);
                tex_aux_add_to_widths(disc_post_break_head(p), adjust_spacing, adjust_spacing_step, lmt_linebreak_state.break_width);
                tex_aux_add_disc_source_to_target(adjust_spacing, lmt_linebreak_state.break_width, lmt_linebreak_state.disc_width);
                if (disc_post_break_head(p)) {
                    s = null;
                } else {
                    /*tex no |post_break|: skip any whitespace following */
                    s = node_next(p);
                }
                break;
        }
    }
    while (s) {
        switch (node_type(s)) {
            case glue_node:
                /*tex Subtract glue from |break_width|; */
                lmt_linebreak_state.break_width[total_advance_amount] -= glue_amount(s);
                lmt_linebreak_state.break_width[total_stretch_amount + glue_stretch_order(s)] -= glue_stretch(s);
                lmt_linebreak_state.break_width[total_shrink_amount] -= glue_shrink(s);
                break;
            case penalty_node:
                break;
            case kern_node:
                if (node_subtype(s) == explicit_kern_subtype || node_subtype(s) == italic_kern_subtype) {
                    lmt_linebreak_state.break_width[total_advance_amount] -= kern_amount(s);
                    break;
                } else {
                    return;
                }
            case math_node:
                if (tex_math_glue_is_zero(s)) {
                    lmt_linebreak_state.break_width[total_advance_amount] -= math_surround(s);
                } else {
                    lmt_linebreak_state.break_width[total_advance_amount] -= math_amount(s);
                    lmt_linebreak_state.break_width[total_stretch_amount + math_stretch_order(s)] -= math_stretch(s);
                    lmt_linebreak_state.break_width[total_shrink_amount] -= math_shrink(s);
                }
                break;
            default:
                return;
        };
        s = node_next(s);
    }
}

static void tex_aux_line_break_callback_initialize(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->", initialize_line_break_context, checks);
}

static void tex_aux_line_break_callback_start(int callback_id, halfword checks, int pass, int classes, int decent)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddddd->", start_line_break_context, checks, pass, classes, decent);
}

static void tex_aux_line_break_callback_stop(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->", stop_line_break_context, checks);
}

static void tex_aux_line_break_callback_collect(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->", collect_line_break_context, checks);
}

static void tex_aux_line_break_callback_line(int callback_id, halfword checks, int line)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddNddddd->", line_line_break_context, checks,
        lmt_linebreak_state.just_box, lmt_packaging_state.last_badness,  lmt_packaging_state.last_overshoot,
        lmt_packaging_state.total_shrink[normal_glue_order], lmt_packaging_state.total_stretch[normal_glue_order], line
    );
}

static void tex_aux_line_break_callback_delete(halfword active, halfword passive, int callback_id, halfword checks)
{
    (void) active;
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->", delete_line_break_context, checks, passive_serial(passive));
}

static void tex_aux_line_break_callback_wrapup(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->", wrapup_line_break_context, checks);
}

static void tex_aux_line_break_callback_check(halfword active, halfword passive, int callback_id, halfword checks, int pass, halfword *demerits)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dddddddddNddd->r", report_line_break_context, 
        checks,
        pass,
        passive_serial(passive),
        passive_prev_break(passive) ? passive_serial(passive_prev_break(passive)) : 0,
        active_line_number(active) - 1,
        node_type(active),
        active_fitness(active) + 1, /* we offset the class */
        active_total_demerits(active), /* demerits */
        passive_cur_break(passive),
        active_short(active),
        active_glue(active),
        active_line_width(active),
        demerits /* optionally changed */
    );
}

static void tex_aux_line_break_callback_list(halfword passive, int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddd->", list_line_break_context, checks, 
        passive_serial(passive)
    );
}

static void tex_aux_print_break_node(halfword active, halfword passive)
{
    /*tex Print a symbolic description of the new break node. */
    tex_print_format(
        "%l[break: serial %i, line %i.%i,%s demerits %i, ",
        passive_serial(passive),
        active_line_number(active) - 1,
        active_fitness(active),
        node_type(active) == hyphenated_node ? " hyphenated, " : "",
        active_total_demerits(active)
    );
    if (lmt_linebreak_state.do_last_line_fit) {
        /*tex Print additional data in the new active node. */
        tex_print_format(
            " short %p, %s %p, ",
            active_short(active),
            passive_cur_break(passive) ? "glue" : "active",
            active_glue(active)
        );
    }
    tex_print_format(
        "previous %i]",
        passive_prev_break(passive) ? passive_serial(passive_prev_break(passive)) : null
    );
}

static const char *tex_aux_node_name(halfword current)
{
    if (current) {
        /*tex This could be more generic helper. */
        switch (node_type(current)) {
            case penalty_node : return "penalty";
            case disc_node    : return "discretionary";
            case kern_node    : return "kern";
            case glue_node    : return "glue"; /* in traditional tex "" */
            default           : return "math";
        }
    } else {
        return "par";
    }
}

static void tex_aux_print_feasible_break(halfword current, halfword breakpoint, halfword badness, halfword penalty, halfword d, halfword artificial_demerits)
{
    /*tex Print a symbolic description of this feasible break. */
    if (lmt_linebreak_state.printed_node != current) {
        /*tex Print the list between |printed_node| and |cur_p|, then set |printed_node := cur_p|. */
        tex_print_nlp();
        if (current) {
            halfword save_link = node_next(current);
            node_next(current) = null;
            tex_short_display(node_next(lmt_linebreak_state.printed_node));
            node_next(current) = save_link;
        } else {
            tex_short_display(node_next(lmt_linebreak_state.printed_node));
        }
        lmt_linebreak_state.printed_node = current;
    }
    tex_print_format(
        "%l[break: feasible, trigger %s, serial %i, badness %B, penalty %i, demerits %B]",
        tex_aux_node_name(current),
        active_break_node(breakpoint) ? passive_serial(active_break_node(breakpoint)) : 0,
        badness,
        penalty,
        artificial_demerits ? awful_bad : d
    );
}

/*tex We implement this one later on. */

/*
    The only reason why we still have line_break_dir is because we have some experimental protrusion
    trickery depending on it.
*/

static void tex_aux_post_line_break(const line_break_properties *properties, halfword line_break_dir, int callback_id, halfword checks, int state);

/*tex

    The next subroutine is used to compute the badness of glue, when a total |t| is supposed to be
    made from amounts that sum to~|s|. According to {\em The \TEX book}, the badness of this
    situation is $100(t/s)^3$; however, badness is simply a heuristic, so we need not squeeze out
    the last drop of accuracy when computing it. All we really want is an approximation that has
    similar properties.

    The actual method used to compute the badness is easier to read from the program than to
    describe in words. It produces an integer value that is a reasonably close approximation to
    $100(t/s)^3$, and all implementations of \TEX\ should use precisely this method. Any badness of
    $2^{13}$ or more is treated as infinitely bad, and represented by 10000.

    It is not difficult to prove that |badness (t + 1, s) >= badness (t, s) >= badness (t, s + 1)|
    The badness function defined here is capable of computing at most 1095 distinct values, but
    that is plenty.

    A core aspect of the linebreak algorithm is the calculation of badness. The formula currently
    used has evolved with the tex versions before Don Knuth settled on this approach. And I (HH)
    admit that I see no real reason to change something here. The only possible extension could
    be changing the hardcoded |loose_criterion| of 99 and |decent_criterion| of 12. These could
    become parameters instead. When looking at the code you will notice a loop that runs from
    |very_loose_fit| to |tight_fit| with the following four steps:

    \starttyping
    very_loose_fit  loose_fit  decent_fit  tight_fit
    \stoptyping

    where we have only |loose_fit| and |decent_fit| with associated criteria later on. So, as an
    experiment I decided to add two steps in between.

    \starttyping
    very_loose_fit  semi_loose_fit  loose_fit  decent_fit  semi_tight_fit  tight_fit
    \stoptyping

    Watch how we keep the assymetrical nature of this sequence: there is basicaly one tight
    step less than loose steps. Adding these steps took hardly any code so it was a cheap
    experiment. However, the result is not that spectacular: I'm pretty sure that users will
    not be able to choose consistently what result looks better, but who knows. For the moment
    I keep it, if only to be able to discuss it as useless extension. Configuring the value s
    is done with |\linebreakcriterion| which gets split into 4 parts (2 bytes per criterion).

    It is probably hard to explain to users what a different setting does and although one can
    force different output in narrow raggedright text it would probbably enough to just make

    the |decent_criterion| configureable. Anyway, because we're talking heuristics and pretty
    good estimates from Don Knuth here, it would be pretentious to suggest that I really did
    research this fuzzy topic (if it was worth the effort at all).

    Here |large_width_excess| is 110.32996pt while |small_stretchability| equals 25.38295pt.

*/

/*tex
    Around 2023-05-24 Mikael Sundqvist and I did numerous tests with the badness function below in
    comparison with the variant mentioned in Digital Typography (DEK) and we observed that indeed
    both functions behave pretty close (emulations with lua, mathematica etc). In practice one can
    get different badness values (especially low numbers). We ran some test on documents and on
    hundreds of pages one can get a few different decisions. The main reason for looking into this
    was that we were exploring a bit more visual approach to deciding on what penalties to use in
    the math inter-atom spacing in \CONTEXT\ (where we use a more granular class model). In the end
    the magic criteria became even more magic (and impressive). BTW, indeed we could get these 1095
    different badness cases with as maximum calculated one 8189.
*/

halfword tex_badness(scaled t, scaled s)
{
    /*tex Approximation to $\alpha t/s$, where $\alpha^3 \approx 100 \cdot 2^{18}$ */

    if (t == 0) {
        return 0;
    } else if (s <= 0) {
        return infinite_bad;
    } else {
        /*tex $297^3 = 99.94 \times 2^{18}$ */
        if (t <= large_width_excess) {
            t = (t * 297) / s;  /* clipping by integer division */
        } else if (s >= small_stretchability) {
            t = t / (s / 297);  /* clipping by integer division */
        } else {
            /*tex
                When we end up here |t| is pretty large so we can as well save a test and return
                immediately. (HH & MS: we tested this while cheating a bit because this function
                is seldom entered with values that make us end up here.)
            */
            return infinite_bad;
        }
        if (t > 1290) {
            /*tex As $1290^3 < 2^{31} < 1291^3$ we catch an overflow here. */ /* actually badness 8189 */
            return infinite_bad;
        } else {
            /*tex 297*297*297 == 26198073 / 100 => 261981 */
            /*tex This is $t^3 / 2^{18}$, rounded to the nearest integer */
         // return (t * t * t + 0400000) / 01000000; /* 0400000/01000000 == 1/2 */
         // return (t * t * t + 0x20000) /  0x40000;
            return (t * t * t +  131072) /   262144;
        }
    }
}

/*tex 

    Todo: 
    
    -- Checking will be done at defnition time. 
    -- No need for extra demerist when alll are zero 

*/

void tex_check_fitness_demerits(halfword fitnessdemerits)
{
    if (! fitnessdemerits) {
        tex_normal_error("linebreak", "unknown fitnessdemerits");
        return;
    }
    halfword max = tex_get_specification_count(fitnessdemerits);
    halfword med = 0;
    if (max >= n_of_fitness_values) {
        tex_normal_error("linebreak", "too many fitnessdemerits");
        return;
    }
    if (max < 3) {
        tex_normal_error("linebreak", "less than three fitnessdemerits");
        return;
    }
    for (med = 1; med <= max; (med)++) {
        if (tex_get_specification_fitness(fitnessdemerits, med) == 0) {
            break;
        }
    }
    if ((med <= 1) || (med == max)) {
        tex_normal_error("linebreak", "invalid decent slot in fitnessdemerits");
        return;
    }
    tex_set_specification_decent(fitnessdemerits, med);
    for (halfword c = 1; c <= max; c++) {
        if (tex_get_specification_demerits_u(fitnessdemerits, c) || tex_get_specification_demerits_d(fitnessdemerits, c)) {
            tex_set_specification_option(fitnessdemerits, specification_option_values);
            break;
        }
    }
}

inline static halfword tex_max_fitness(halfword fitnessdemerits)
{
    return tex_get_specification_count(fitnessdemerits);
}

inline static halfword tex_med_fitness(halfword fitnessdemerits)
{
    return tex_get_specification_decent(fitnessdemerits);
}

inline static halfword tex_get_demerits(const line_break_properties *properties, halfword start, halfword stop)
{
    halfword fitnessdemerits = properties->fitness_demerits;
    if (tex_has_specification_option(fitnessdemerits, specification_option_values)) { 
        /*tex We go from inbetween (zero based) to indices, so we add one. */
        halfword max = tex_get_specification_count(fitnessdemerits);
        halfword demerits = 0;
        if (start > stop) {
            for (halfword c = stop; c >= start; c--) {
                if (c + 1 <= max) {
                    demerits += tex_get_specification_demerits_u(fitnessdemerits, c + 1);
                }
            }
        } else { 
            for (halfword c = start; c <= stop; c++) {
                if (c + 1 <= max) {
                    demerits += tex_get_specification_demerits_d(fitnessdemerits, c + 1);
                }
            }
        }
        return demerits; 
    } else { 
        return properties->adj_demerits;
    }
}

/*tex 
    Watch out: here we map from indices to inbetween (zero based) categories. 
*/

inline static halfword tex_normalized_loose_badness(halfword b, halfword fitnessdemerits)
{
    halfword med = tex_get_specification_decent(fitnessdemerits);
    for (halfword c = med - 1; c >= 1; c--) {
        if (b <= tex_get_specification_fitness(fitnessdemerits, c)) {
            return c;
        }
    }
    return 0;
}

inline static halfword tex_normalized_tight_badness(halfword b, halfword fitnessdemerits) 
{
    halfword max = tex_get_specification_count(fitnessdemerits);
    halfword med = tex_get_specification_decent(fitnessdemerits);
    for (halfword c = med + 1; c <= max; c++) {
        if (b <= tex_get_specification_fitness(fitnessdemerits, c)) {
            return c - 2;
        }
    }
    return max - 1;
}

halfword tex_default_fitness_demerits(void) {
    halfword n = tex_new_specification_node(5, fitness_demerits_code, 0);
    tex_set_specification_fitness(n, 1, 99);
    tex_set_specification_fitness(n, 2, 12);
    tex_set_specification_fitness(n, 3, 0);
    tex_set_specification_fitness(n, 4, 12);
    tex_set_specification_fitness(n, 5, 99);
    tex_check_fitness_demerits(n);
    return n;
}

static void tex_check_protrusion_shortfall(halfword breakpoint, halfword first, halfword current, halfword *shortfall)
{
    // if (line_break_dir == dir_righttoleft) {
    //     /*tex Not now, we need to keep more track. */
    // } else {
        halfword other = null;
        halfword left = active_break_node(breakpoint) ? passive_cur_break(active_break_node(breakpoint)) : first;
        if (current) {
            other = node_prev(current);
            if (node_next(other) != current) {
                tex_normal_error("linebreak", "the node list is messed up");
            }
        }
        /*tex

            The last characters (hyphenation character) if these two list should always be
            the same anyway, so we just look at |pre_break|. Let's look at the right margin
            first.

        */
        if (current && node_type(current) == disc_node && disc_pre_break_head(current)) {
            /*tex
                A |disc_node| with non-empty |pre_break|, protrude the last char of
                |pre_break|:
            */
            other = disc_pre_break_tail(current);
        } else {
            other = tex_aux_find_protchar_right(left, other);
        }
        if (other && node_type(other) == glyph_node) {
            *shortfall += tex_char_protrusion(other, right_margin_kern_subtype);
        }
        /*tex now the left margin */
        if (left && node_type(left) == disc_node && disc_post_break_head(left)) {
            /*tex The first char could be a disc! Protrude the first char. */
            other = disc_post_break_head(left);
        } else {
            other = tex_aux_find_protchar_left(left, 1);
        }
        if (other && node_type(other) == glyph_node) {
            *shortfall += tex_char_protrusion(other, left_margin_kern_subtype);
        }
    // }
}

static void tex_aux_set_quality(halfword active, halfword passive, scaled shrt, scaled glue, scaled width)
{
    halfword quality = 0;
    halfword deficiency = 0;
    active_short(active) = shrt;
    active_glue(active) = glue;
    active_line_width(active) = width;
    if (shrt < 0) {
        shrt = -shrt;
        if (shrt > glue) {
            quality = par_is_overfull;
            deficiency = shrt - glue;
        }
    } else if (shrt > 0) {
        if (shrt > glue) {
            quality = par_is_underfull;
            deficiency = shrt - glue;
        }
    }
    passive_quality(passive) = quality;
    passive_deficiency(passive) = deficiency;
    passive_demerits(passive) = active_total_demerits(active);
    active_quality(active) = quality;
    active_deficiency(active) = deficiency;
 }

/*tex

    The twin detection is a follow up on a discussion between Dedier Verna, Mikael Sundqvist and 
    Hans Hagen. We have been playing with features like this in ConTeXt when we extended the par 
    builder but that uses a callback that is meant for tracing (read: articles that we write on 
    this topic). When Dedier wondered if it could be an engine feature we pickup up this thread. 

    In a 2024 article for the TUG meeting Dedier describes some performance measurements with 
    his (lisp based) framework but we already know that the par builder is not that critical 
    in the whole picture. Here we distinguish between a left and right edge twin (repeated word) 
    and we also look into discretionaries because we can assume that more complex opentype 
    features can give more complex discretionaries than a single hyphen. One can condider a 
    configurable size of comparison. 

    Using a Lua approach is quite flexible and permits nice tracing but, as said, it abuses a 
    callback that, due to the many different invocations is not the best candidate for this. We
    could add another callback but that is overkill. Instead, part of the Lua code has been turned
    into a native feature so that we can do both: native twin checking as well as tracing of the 
    break routine (which we need for testing par passes) but also exploring more features using 
    that callback. 
    
    The reference implementation is still done in Lua where we then also have twin tracing. In 
    principle that one is fast enough. The native C implementation works sligthly different but 
    is still based on the Lua code. We also have some constraints, like the maximum size of a 
    snippet.  

    In both cases (Lua and C) the overhead is rather small because we only look at a small set
    of breakpoints. In Lua we gain performance by caching, in C by limiting the snippet. We 
    can squeeze out some more performance if needed by immediately comparing the second snippet 
    with the first one. Contrary to the Lua variant, the C implementation checks for a glyph 
    option being set. Because it has to fit in the rest we carry the |\lefttwindemerits| and 
    |\righttwindemerits| in the par node and also can set it in the (optional extra) par passes. 

    Maybe (as in the \LUA) variant, also support |twinslimit|. 

*/

static int tex_aux_get_before(halfword breakpoint, int snippet[])
{
    halfword current = null;
    int count = 0;
    halfword font = 0;
    quarterword prop = 0; 
    switch (node_type(breakpoint)) { 
        case glue_node: 
            {
                current = node_prev(breakpoint);
                if (node_type(current) == glyph_node && tex_has_glyph_option(current, glyph_option_check_twin)) { 
                    font = glyph_font(current);
                    prop = glyph_control(current);
                    snippet[count++] = font;
                    snippet[count++] = glyph_character(current);
                    if (count == max_twin_snippet) { 
                        return 0; 
                    }
                    current = node_prev(current);
                } else {
                    return 0;
                }
            }
            break;
        case disc_node:
            {
                current = breakpoint;
                halfword r = disc_pre_break_tail(current);
                while (r) {
                    if (node_type(r) == glyph_node) {
                        if (! tex_has_glyph_option(r, glyph_option_check_twin)) { 
                            return 0;
                        } else if (! font) {
                            font = glyph_font(r);
                            prop = glyph_control(r);
                            snippet[count++] = font;
                        }
                        snippet[count++] = glyph_character(r);
                        if (count == max_twin_snippet) { 
                            return 0; 
                        }
                    }
                    r = node_prev(r);
                }
                current = node_prev(current);
            }
            break;
        default:
            return 0;
    }
    if (current && font) {
        while (current) {
            switch (node_type(current)) { 
                case glyph_node:
                    if (! tex_has_glyph_option(current, glyph_option_check_twin)) { 
                        return 0;
                    } else if (glyph_font(current) == font) {
                        snippet[count++] = glyph_character(current);
                        if (count == max_twin_snippet) { 
                            return 0; 
                        } else { 
                            break;
                        }
                        break;
                    } else {
                        return 0;
                    }
                case disc_node:
                    {
                        halfword r = disc_no_break_tail(current);
                        while (r) {
                            switch (node_type(r)) { 
                                case glyph_node:
                                    if (! tex_has_glyph_option(r, glyph_option_check_twin)) { 
                                        return 0;
                                    } else if (glyph_font(r) == font) {
                                        snippet[count++] = glyph_character(r);
                                        if (count == max_twin_snippet) { 
                                         // return count; 
                                            return 0; 
                                        } else { 
                                            break;
                                        }
                                    } else { 
                                        return 0;
                                    }
                                case kern_node: 
                                    if (node_subtype(r) == font_kern_subtype) {
                                        break;
                                    } else { 
                                        return 0;
                                    }
                                default:
                                    return 0;
                            }
                            r = node_prev(r);
                        }
                        break;
                    }
                case kern_node: 
                    if (node_subtype(current) == font_kern_subtype) {
                        break;
                    } else {
                        return 0;
                    } 
                case glue_node: 
                    { 
                        halfword prev = node_prev(current);
                        if (prev && ((node_type(prev) == glyph_node && tex_has_glyph_option(prev, glyph_option_check_twin)) || node_type(prev) == disc_node)) {
                            /* Just a test for an article, we need a field in the glyph node if we go this route. */
                            if (count > 1 && prop && has_character_control(prop, ignore_twin_character_control_code)) { 
                                for (int i = 2; i < count; i++) {
                                    snippet[i-1] = snippet[i];
                                }
                                --count; 
                            }
                            return count; 
                        }
                    }
                    return 0; 
                default: 
                    return 0;
            }
            current = node_prev(current);
        }
    }
    return 0;
}

static int tex_aux_get_after(halfword breakpoint, int snippet[])
{
    halfword current = null;
    int count = 0;
    halfword font = 0;
    quarterword prop = 0;
    switch (node_type(breakpoint)) { 
        case glue_node: 
            {
                current = node_next(breakpoint);
                if (node_type(current) == glyph_node && tex_has_glyph_option(current, glyph_option_check_twin)) { 
                    font = glyph_font(current);
                    prop = glyph_control(current);
                    snippet[count++] = font;
                    snippet[count++] = glyph_character(current);
                    if (count == max_twin_snippet) { 
                        return 0;
                    }
                    current = node_next(current);
                } else {
                    return 0;
                }
            }
            break;
        case disc_node:
            {
                current = breakpoint;
                halfword r = disc_post_break_head(current);
                while (r) {
                    if (node_type(r) == glyph_node) {
                        if (! tex_has_glyph_option(r, glyph_option_check_twin)) { 
                            return 0;
                        } else if (! font) {
                            font = glyph_font(r);
                            prop = glyph_control(r);
                            snippet[count++] = font;
                        }
                        snippet[count++] = glyph_character(r);
                        if (count == max_twin_snippet) { 
                            return 0;
                        }
                    }
                    r = node_next(r);
                }
                current = node_next(current);
            }
            break;
        default:
            return 0;
    }
    if (current && font) {
        while (current) {
            switch (node_type(current)) { 
                case glyph_node:
                    if (! tex_has_glyph_option(current, glyph_option_check_twin)) { 
                        return 0;
                    } else if (glyph_font(current) == font) {
                        snippet[count++] = glyph_character(current);
                        if (count == max_twin_snippet) { 
                            return 0;
                        } else { 
                            prop = glyph_control(current);
                            break;
                        }
                        break;
                    } else {
                        return 0;
                    }
                case disc_node:
                    {
                        halfword r = disc_no_break_head(current);
                        while (r) {
                            switch (node_type(r)) { 
                                case glyph_node:
                                    if (! tex_has_glyph_option(r, glyph_option_check_twin)) { 
                                        return 0;
                                    } else if (glyph_font(r) == font) {
                                        snippet[count++] = glyph_character(r);
                                        if (count == max_twin_snippet) { 
                                            return 0;
                                        } else { 
                                            prop = glyph_control(r);
                                            break;
                                        }
                                    } else { 
                                        return 0;
                                    }
                                case kern_node: 
                                    if (node_subtype(r) == font_kern_subtype) {
                                        break;
                                    } else { 
                                        return 0;
                                    }
                                default:
                                    return 0;
                            }
                            r = node_next(r);
                        }
                        break;
                    }
                case kern_node: 
                    if (node_subtype(current) == font_kern_subtype) {
                        break;
                    } else {
                        return 0;
                    } 
                case glue_node: 
                    { 
                        halfword next = node_prev(current);
                        if (next && ((node_type(next) == glyph_node && tex_has_glyph_option(next, glyph_option_check_twin)) || node_type(next) == disc_node)) {
                            /* Just a test for an article, we need a field in the glyph node if we go this route. */
                            if (count > 1 && has_character_control(prop, ignore_twin_character_control_code)) { 
                                --count;
                            }
                            return count; 
                        }
                    }
                    return 0; 
                default: 
                    return 0;
            }
            current = node_next(current);
        }
    }
    return 0;
}

static int tex_aux_same_snippet(int snippetone[], int snippettwo[], int nsone, int nstwo)
{
    if (nsone > 0 && nsone == nstwo) { 
        for (int i = 0; i < nsone; i++) {
            if (snippetone[i] != snippettwo[i]) { 
                return 0;
            }
        }
        return 1; 
    } else {
        return 0;
    }
}

/* */

static scaled tex_aux_try_break(
    const line_break_properties *properties,
    halfword penalty,
    halfword break_type,
    halfword first_p,
    halfword cur_p,
    int callback_id,
    halfword checks,
    int pass,
    int artificial
)
{
    /*tex stays a step behind |r| */
    halfword previous = active_head;
    /*tex a step behind |prev_r|, if |type(prev_r) = delta_node| */
    halfword before_previous = null;
    /*tex distance from current active node */
    scaled current_active_width[n_of_glue_amounts] = { 0 };
    /*tex
        These status arrays are global to the main loop and will be initialized as we go.
    */
    halfword best_place      [n_of_fitness_values] = { 0 };
    halfword best_place_line [n_of_fitness_values] = { 0 };
    scaled   best_place_short[n_of_fitness_values] = { 0 };
    scaled   best_place_glue [n_of_fitness_values] = { 0 };
    /*tex badness of test line */
    halfword badness = 0;
    /*tex demerits of test line */
    int demerits = 0;
    /*tex glue stretch or shrink of test line, adjustment for last line */
    scaled glue = 0;
    /*tex used in badness calculations */
    scaled shortfall = 0;
    /*tex maximum line number in current equivalence class of lines */
    halfword old_line = 0;
    /*tex have we found a feasible break at |cur_p|? */
    bool no_break_yet = true;
    /*tex should node |r| remain in the active list? */
    int current_stays_active;
    /*tex possible fitness class of test line */
    halfword fit_class;
    /*tex has |d| been forced to zero? */
    int artificial_demerits;
    /*tex the current line will be justified to this width */
    scaled line_width = 0;
    /*tex line number of current active node */
    halfword line = 0;
    /* */
    int twins = properties->left_twin_demerits > 0 || properties->right_twin_demerits > 0;
    /*tex
        We have added an extra category, just as experiment. In practice there is very little
        to gain here as it becomes kind of fuzzy and DEK values are quite okay.
    */
    /*tex Make sure that |pi| is in the proper range; */
    if (penalty >= infinite_penalty) {
        /*tex this breakpoint is inhibited by infinite penalty */
        return shortfall;
    } else if (penalty <= -infinite_penalty) {
        /*tex this breakpoint will be forced */
        penalty = eject_penalty; /* bad name here */
    }
    /*tex Consider a demerit for two lines with stretch/shrink based on expansion. */
    tex_aux_set_target_to_source(properties->adjust_spacing, current_active_width, lmt_linebreak_state.active_width);
    while (1) {
        /*tex Here |r| runs through the active list: */
        halfword current = node_next(previous);
        /*tex

            If node |r| is of type |delta_node|, update |cur_active_width|, set |prev_r| and
            |prev_prev_r|, then |goto continue|. The following code uses the fact that |type
            (active) <> delta_node|.

        */
        if (node_type(current) == delta_node) {
            tex_aux_add_to_target_from_delta(properties->adjust_spacing, current_active_width, current);
            before_previous = previous;
            previous = current;
            continue;
        } else {
            /*tex We have an |unhyphenated_node| or |hyphenated_node|. */
        }
        /*tex

            If a line number class has ended, create new active nodes for the best feasible breaks
            in that class; then |return| if |r = active|, otherwise compute the new |line_width|.

            The first part of the following code is part of \TEX's inner loop, so we don't want to
            waste any time. The current active node, namely node |r|, contains the line number that
            will be considered next. At the end of the list we have arranged the data structure so
            that |r = active| and |line_number (active) > old_l|.

        */
        line = active_line_number(current);
        if (line > old_line) {
            /*tex Now we are no longer in the inner loop (well ...). */
            if ((lmt_linebreak_state.minimum_demerits < awful_bad) && ((old_line != lmt_linebreak_state.easy_line) || (current == active_head))) {
                int s_before[max_twin_snippet];
                int s_after[max_twin_snippet];
                int n_before = -1;
                int n_after = -1;
                /*tex

                    Create new active nodes for the best feasible breaks just found. It is not
                    necessary to create new active nodes having |minimal_demerits| greater than
                    |linebreak_state.minimum_demerits + abs (adj_demerits)|, since such active
                    nodes will never be chosen in the final paragraph breaks. This observation
                    allows us to omit a substantial number of feasible breakpoints from further
                    consideration.

                */
                if (line > lmt_linebreak_state.easy_line) {
                    line_width = lmt_linebreak_state.second_width;
                } else if (line > lmt_linebreak_state.last_special_line) {
                    line_width = lmt_linebreak_state.second_width;
                } else if (properties->par_shape) {
                    line_width = tex_get_specification_width(properties->par_shape, line);
                } else {
                    line_width = lmt_linebreak_state.first_width;
                }
                if (no_break_yet) {
                    no_break_yet = false;
                    if (lmt_linebreak_state.emergency_percentage) {
                        scaled stretch = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_percentage, scaling_factor);
                        lmt_linebreak_state.background[total_stretch_amount] -= lmt_linebreak_state.emergency_amount;
                        lmt_linebreak_state.background[total_stretch_amount] += stretch;
                        lmt_linebreak_state.emergency_amount = stretch;
                    }
                    if (lmt_linebreak_state.emergency_width_extra) {
                        scaled extra = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_width_extra, scaling_factor);
                        lmt_linebreak_state.background[total_advance_amount] -= lmt_linebreak_state.emergency_width_amount;
                        lmt_linebreak_state.background[total_advance_amount] += extra;
                        lmt_linebreak_state.emergency_width_amount = extra;
                    }  
                    if (lmt_linebreak_state.emergency_left_extra) {
                        scaled extra = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_left_extra, scaling_factor);
                        lmt_linebreak_state.background[total_advance_amount] -= lmt_linebreak_state.emergency_left_amount;
                        lmt_linebreak_state.background[total_advance_amount] += extra;
                        lmt_linebreak_state.emergency_left_amount = extra;
                    }  
                    if (lmt_linebreak_state.emergency_right_extra) {
                        scaled extra = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_right_extra, scaling_factor);
                        lmt_linebreak_state.background[total_advance_amount] -= lmt_linebreak_state.emergency_right_amount;
                        lmt_linebreak_state.background[total_advance_amount] += extra;
                        lmt_linebreak_state.emergency_right_amount = extra;
                    }    
                    tex_aux_set_target_to_source(properties->adjust_spacing, lmt_linebreak_state.break_width, lmt_linebreak_state.background);
                    tex_aux_compute_break_width(break_type, properties->adjust_spacing, properties->adjust_spacing_step, cur_p);
                }
                /*tex

                    Insert a delta node to prepare for breaks at |cur_p|. We use the fact that
                    |type (active) <> delta_node|.

                */
                if (node_type(previous) == delta_node) {
                    /*tex modify an existing delta node */
                    tex_aux_add_delta_from_difference(properties->adjust_spacing, previous, lmt_linebreak_state.break_width, current_active_width);
                } else if (previous == active_head) {
                    /*tex no delta node needed at the beginning */
                    tex_aux_set_target_to_source(properties->adjust_spacing, lmt_linebreak_state.active_width, lmt_linebreak_state.break_width);
                } else {
                    halfword q = tex_new_node(delta_node, (quarterword) default_fit); /* here */
                    node_next(q) = current;
                    tex_aux_set_delta_from_difference(properties->adjust_spacing, q, lmt_linebreak_state.break_width, current_active_width);
                    node_next(previous) = q;
                    before_previous = previous;
                    previous = q;
                }
                if (abs(properties->adj_demerits) >= awful_bad - lmt_linebreak_state.minimum_demerits) {
                    lmt_linebreak_state.minimum_demerits = awful_bad - 1;
                } else {
                    lmt_linebreak_state.minimum_demerits += abs(properties->adj_demerits);
                }
                for (halfword fit_class = default_fit; fit_class <= tex_max_fitness(properties->fitness_demerits); fit_class++) {
                    if (lmt_linebreak_state.minimal_demerits[fit_class] <= lmt_linebreak_state.minimum_demerits) {
                        /*tex

                            Insert a new active node from |best_place [fit_class]| to |cur_p|. When
                            we create an active node, we also create the corresponding passive node.
                            In the passive node we also keep track of the subparagraph penalties.

                        */
                        halfword passive = tex_new_node(passive_node, (quarterword) fit_class);
                        halfword active = tex_new_node((quarterword) break_type, (quarterword) fit_class);
                        halfword prev_break = best_place[fit_class];
                        /*tex Initialize the passive node: */
                        passive_cur_break(passive) = cur_p;
                        passive_serial(passive) = ++lmt_linebreak_state.serial_number;
                        passive_prev_break(passive) = prev_break;
                        passive_interline_penalty(passive) = lmt_linebreak_state.internal_interline_penalty;
                        passive_broken_penalty(passive) = lmt_linebreak_state.internal_broken_penalty;
                        passive_par_node(passive) = lmt_linebreak_state.internal_par_node;
                        passive_last_left_box(passive) = lmt_linebreak_state.internal_left_box;
                        passive_last_left_box_width(passive) = lmt_linebreak_state.internal_left_box_width;
                        if (prev_break) {
                            passive_left_box(passive) = passive_last_left_box(prev_break);
                            passive_left_box_width(passive) = passive_last_left_box_width(prev_break);
                        } else {
                            passive_left_box(passive) = lmt_linebreak_state.internal_left_box_init;
                            passive_left_box_width(passive) = lmt_linebreak_state.internal_left_box_width_init;
                        }
                        passive_right_box(passive) = lmt_linebreak_state.internal_right_box;
                        passive_right_box_width(passive) = lmt_linebreak_state.internal_right_box_width;
                        passive_middle_box(passive) = lmt_linebreak_state.internal_middle_box;
                        /*tex Initialize the active node: */
                        active_break_node(active) = passive;
                        active_line_number(active) = best_place_line[fit_class] + 1;
                        active_total_demerits(active) = lmt_linebreak_state.minimal_demerits[fit_class];
                        /*tex Store additional data in the new active node. */
                        tex_aux_set_quality(active, passive, best_place_short[fit_class], best_place_glue[fit_class], line_width);
                        /*tex Append the passive node. */
                        node_next(passive) = lmt_linebreak_state.passive;
                        lmt_linebreak_state.passive = passive;
                        /*tex Append the active node. */
                        node_next(active) = current;
                        node_next(previous) = active;
                        previous = active;
                        /*tex                            
                            Because we have a loop it can be that we have the same |cur_p| a few 
                            times but it happens not that often. Nevertheless we do cache its 
                            before and after snippets. 
                            
                            We could check the second snippet immediately but the savings can be 
                            neglected as we seldom enter this branch. It also measn two helpers 
                            with the checking on also having to track the size. Messy and ugly 
                            code for no gain so we just grab the whole second snippet and then 
                            compare fast.

                            Maybe take the largest demerits when we have two? Needs some discussion. 
                        */ 
                        if (twins && cur_p && prev_break && passive_cur_break(prev_break)) {
                            int count = 0;
                            int snippet[max_twin_snippet];
                            if (properties->right_twin_demerits) {
                                if (n_before < 0) {
                                    n_before = tex_aux_get_before(cur_p, s_before);
                                }
                                if (n_before) { 
                                    int n = tex_aux_get_before(passive_cur_break(prev_break), snippet);
                                    if (tex_aux_same_snippet(s_before, snippet, n_before, n)) {
                                        if (properties->tracing_paragraphs > 1) {
                                            tex_begin_diagnostic();
                                            tex_print_format("[linebreak: bumping demerits %i by right twin demerits %i]", active_total_demerits(active), properties->right_twin_demerits);
                                            tex_end_diagnostic();
                                        }
                                        active_total_demerits(active) += properties->right_twin_demerits;
                                        ++lmt_linebreak_state.n_of_right_twins;
                                        ++count;
                                    } 
                                }
                            }
                            if (properties->left_twin_demerits) {
                                if (n_after < 0) {
                                    n_after = tex_aux_get_after(cur_p, s_after);
                                }
                                if (n_after) { 
                                    int n = tex_aux_get_after(passive_cur_break(prev_break), snippet);
                                    if (tex_aux_same_snippet(s_after, snippet, n_after, n)) {
                                        if (properties->tracing_paragraphs > 1) {
                                            tex_begin_diagnostic();
                                            tex_print_format("[linebreak: bumping demerits %i by left twin demerits %i]", active_total_demerits(active), properties->left_twin_demerits);
                                            tex_end_diagnostic();
                                        }
                                        active_total_demerits(active) += properties->left_twin_demerits;
                                        ++lmt_linebreak_state.n_of_left_twins;
                                        ++count;
                                    }
                                }
                            }
                            if (count > 1) { 
                                ++lmt_linebreak_state.n_of_double_twins;
                            }
                        }
                        /* */
                        if (callback_id) {
                            halfword demerits = active_total_demerits(active);
                            tex_aux_line_break_callback_check(active, passive, callback_id, checks, pass, &demerits);
                            active_total_demerits(active) = demerits;
                        }
                        if (properties->tracing_paragraphs > 0) {
                            tex_begin_diagnostic();
                            tex_aux_print_break_node(active, passive);
                            tex_end_diagnostic();
                        }
                    }
                    lmt_linebreak_state.minimal_demerits[fit_class] = awful_bad;
                }
                lmt_linebreak_state.minimum_demerits = awful_bad;
                /*tex

                    Insert a delta node to prepare for the next active node. When the following
                    code is performed, we will have just inserted at least one active node before
                    |r|, so |type (prev_r) <> delta_node|.

                */
                if (current != active_head) {
                    halfword delta = tex_new_node(delta_node, (quarterword) default_fit); /* here */
                    node_next(delta) = current;
                    tex_aux_set_delta_from_difference(properties->adjust_spacing, delta, current_active_width, lmt_linebreak_state.break_width);
                    node_next(previous) = delta;
                    before_previous = previous;
                    previous = delta;
                }
            }
            /*tex

                Quit on an active node, otherwise compute the new line width. When we come to the
                following code, we have just encountered the first active node~|r| whose
                |line_number| field contains |l|. Thus we want to compute the length of the
                $l\mskip1mu$th line of the current paragraph. Furthermore, we want to set |old_l|
                to the last number in the class of line numbers equivalent to~|l|.

            */

/* line_width already has been calculated */
            if (line > lmt_linebreak_state.easy_line) {
                old_line = max_halfword - 1;
                line_width = lmt_linebreak_state.second_width;
            } else {
                old_line = line;
                if (line > lmt_linebreak_state.last_special_line) {
                    line_width = lmt_linebreak_state.second_width;
                } else if (properties->par_shape) {
                    line_width = tex_get_specification_width(properties->par_shape, line);
                } else {
                    line_width = lmt_linebreak_state.first_width;
                }
            }
            if (current == active_head) {
                shortfall = line_width - current_active_width[total_advance_amount];
                return shortfall;
            }
        }
        /*tex

            If a line number class has ended, create new active nodes for the best feasible breaks
            in that class; then |return| if |r = active|, otherwise compute the new |line_width|.

            Consider the demerits for a line from |r| to |cur_p|; deactivate node |r| if it should
            no longer be active; then |goto continue| if a line from |r| to |cur_p| is infeasible,
            otherwise record a new feasible break.

        */
        artificial_demerits = 0;
        shortfall = line_width - current_active_width[total_advance_amount];
        if (active_break_node(current)) {
            shortfall -= passive_last_left_box_width(active_break_node(current));
        } else {
            shortfall -= lmt_linebreak_state.internal_left_box_width_init;
        }
        shortfall -= lmt_linebreak_state.internal_right_box_width;
        if (properties->protrude_chars) {
            tex_check_protrusion_shortfall(current, first_p, cur_p, &shortfall);
        }
        /*tex
            The only reason why we have a shared ratio is that we need to calculate the shortfall
            for a line with mixed fonts. However in \LUAMETATEX\ we can mix and have no instances
            so ... The division by 2 comes from \PDFTEX\ where it isn't explained but it seems to 
            work ok. Removing gives more overfull boxes and a different value gives different 
            results.
        */
        if (shortfall > 0) {
            halfword total_stretch = current_active_width[font_stretch_amount];
            if (total_stretch > 0) {
                if (total_stretch > shortfall) {
                    shortfall  = total_stretch / 2;
                } else {
                    shortfall -= total_stretch;
                }
            }
        } else if (shortfall < 0) {
            halfword total_shrink = current_active_width[font_shrink_amount];
            if (total_shrink > 0) {
                if (total_shrink > -shortfall) {
                    shortfall  = - total_shrink / 2;
                } else {
                    shortfall += total_shrink;
                }
            }
        }
        if (shortfall > 0) {
            /*tex

                Set the value of |b| to the badness for stretching the line, and compute the
                corresponding |fit_class|. When a line must stretch, the available stretchability
                can be found in the subarray |cur_active_width [2 .. 6]|, in units of points, sfi,
                fil, fill and filll.

                The present section is part of \TEX's inner loop, and it is most often performed
                when the badness is infinite; therefore it is worth while to make a quick test for
                large width excess and small stretchability, before calling the |badness| subroutine.

            */
            if (current_active_width[total_fi_amount]   || current_active_width[total_fil_amount] ||
                current_active_width[total_fill_amount] || current_active_width[total_filll_amount]) {
                if (lmt_linebreak_state.do_last_line_fit) {
                    if (! cur_p) {
                        /*tex

                            The last line of a paragraph. Perform computations for last line and
                            |goto found|. Here we compute the adjustment |g| and badness |b| for a
                            line from |r| to the end of the paragraph. When any of the criteria for
                            adjustment is violated we fall through to the normal algorithm. The last
                            line must be too short, and have infinite stretch entirely due to
                            |par_fill_skip|.

                        */
                        if (active_short(current) == 0 || active_glue(current) <= 0) {
                            /*tex

                                Previous line was neither stretched nor shrunk, or was infinitely
                                bad.

                            */
                            goto NOT_FOUND;
                        }
                        if (current_active_width[total_fi_amount]   != lmt_linebreak_state.fill_width[fi_order]   || current_active_width[total_fil_amount]   != lmt_linebreak_state.fill_width[fil_order] ||
                            current_active_width[total_fill_amount] != lmt_linebreak_state.fill_width[fill_order] || current_active_width[total_filll_amount] != lmt_linebreak_state.fill_width[filll_order]) {
                            /*tex
                                Infinite stretch of this line not entirely due to |par_fill_skip|.
                            */
                            goto NOT_FOUND;
                        }
                        if (active_short(current) > 0) {
                            glue = current_active_width[total_stretch_amount];
                        } else {
                            glue = current_active_width[total_shrink_amount];
                        }
                        if (glue <= 0) {
                            /*tex No finite stretch and no shrink. */
                            goto NOT_FOUND;
                        }
                        lmt_scanner_state.arithmic_error = 0;
                        glue = tex_fract(glue, active_short(current), active_glue(current), max_dimension);
                        if (properties->last_line_fit < 1000) {
                            glue = tex_fract(glue, properties->last_line_fit, 1000, max_dimension);
                        }
                        if (lmt_scanner_state.arithmic_error) {
                            glue = (active_short(current) > 0) ? max_dimension : -max_dimension;
                        }
                        if (glue > 0) {
                            /*tex

                                Set the value of |b| to the badness of the last line for stretching,
                                compute the corresponding |fit_class, and |goto found|. These
                                badness computations are rather similar to those of the standard
                                algorithm, with the adjustment amount |g| replacing the |shortfall|.

                            */
                            if (glue > shortfall) {
                                glue = shortfall;
                            }
                            if (glue > large_width_excess && (current_active_width[total_stretch_amount] < small_stretchability)) {
                                badness = infinite_bad;
                                fit_class = default_fit; /* here */
                            } else {
                                badness = tex_badness(glue, current_active_width[total_stretch_amount]);
                                fit_class = tex_normalized_loose_badness(badness, properties->fitness_demerits);
                            }
                            goto FOUND;
                        } else if (glue < 0) {
                            /*tex

                                Set the value of |b| to the badness of the last line for shrinking,
                                compute the corresponding |fit_class, and |goto found||.

                            */
                            if (-glue > current_active_width[total_shrink_amount]) {
                                glue = -current_active_width[total_shrink_amount];
                            }
                            badness = tex_badness(-glue, current_active_width[total_shrink_amount]);
                            fit_class = tex_normalized_tight_badness(badness, properties->fitness_demerits);
                            goto FOUND;
                        }
                    }
                  NOT_FOUND:
                    shortfall = 0;
                }
                badness = 0;
                /*tex Infinite stretch. */
                fit_class = tex_get_specification_decent(properties->fitness_demerits) - 1;
            } else if (shortfall > large_width_excess && current_active_width[total_stretch_amount] < small_stretchability) {
                badness = infinite_bad;
                fit_class = default_fit; /* here */
            } else {
                badness = tex_badness(shortfall, current_active_width[total_stretch_amount]);
                fit_class = tex_normalized_loose_badness(badness, properties->fitness_demerits);
            }
        } else {
            /*tex

                Set the value of |b| to the badness for shrinking the line, and compute the
                corresponding |fit_class|. Shrinkability is never infinite in a paragraph; we
                can shrink the line from |r| to |cur_p| by at most |cur_active_width
                [total_shrink_amount]|.

            */
            if (-shortfall > current_active_width[total_shrink_amount]) {
                badness = infinite_bad + 1;
            } else {
                badness = tex_badness(-shortfall, current_active_width[total_shrink_amount]);
        }
            fit_class = tex_normalized_tight_badness(badness, properties->fitness_demerits);
        }
        if (1) { // lmt_linebreak_state.do_last_line_fit) {
            /*tex Adjust the additional data for last line; */
            if (! cur_p) {
                shortfall = 0;
                glue = 0;
            } else if (shortfall > 0) {
                glue = current_active_width[total_stretch_amount];
            } else if (shortfall < 0) {
                glue = current_active_width[total_shrink_amount];
            } else {
                glue = 0;
            }
        } else {
            /* Can we get here at all? */
        }
      FOUND:
        if ((badness > infinite_bad) || (penalty == eject_penalty)) {
            /*tex

                Prepare to deactivate node~|r|, and |goto deactivate| unless there is a reason to
                consider lines of text from |r| to |cur_p|. During the final pass, we dare not
                lose all active nodes, lest we lose touch with the line breaks already found. The
                code shown here makes sure that such a catastrophe does not happen, by permitting
                overfull boxes as a last resort. This particular part of \TEX\ was a source of
                several subtle bugs before the correct program logic was finally discovered; readers
                who seek to improve \TEX\ should therefore think thrice before daring to make any
                changes here. 
                
                This last remark applies to HH & MS and it also makes par passes (1 & 2) hard to act 
                compatible because we lack a criterium. 

            */
            if (artificial && (lmt_linebreak_state.minimum_demerits == awful_bad) && (node_next(current) == active_head) && (previous == active_head)) {
                /*tex Set demerits zero, this break is forced. */
                artificial_demerits = 1;
            } else if (badness > lmt_linebreak_state.threshold) {
                goto DEACTIVATE;
            }
            current_stays_active = 0;
        } else {
            previous = current;
            if (badness > lmt_linebreak_state.threshold) {
                continue;
            } else {
                current_stays_active = 1;
            }
        }
        /*tex

            Record a new feasible break. When we get to this part of the code, the line from |r| to
            |cur_p| is feasible, its badness is~|b|, and its fitness classification is |fit_class|.
            We don't want to make an active node for this break yet, but we will compute the total
            demerits and record them in the |minimal_demerits| array, if such a break is the current
            champion among all ways to get to |cur_p| in a given line-number class and fitness class.

        */
        if (artificial_demerits) {
            demerits = 0;
        } else {
            /*tex Compute the demerits, |d|, from |r| to |cur_p|. */
            int fit_current = (halfword) active_fitness(current);
            int distance = abs(fit_class - fit_current);
            demerits = properties->line_penalty + badness;
            if (abs(demerits) >= infinite_bad) {
                demerits = extremely_deplorable;
            } else {
                demerits = demerits * demerits;
            }
            if (penalty) {
                if (penalty > 0) {
                    demerits += (penalty * penalty);
                } else if (penalty > eject_penalty) {
                    demerits -= (penalty * penalty);
                }
            }
            /*tex
                If we have a hyphen penalty of 50 and add 5000 to the demerits in case of double
                hyphens, we do that only once, so for triple we get:  

                \starttyping 
                xxxxxxxxxxxxx- @ xxxxxxxxxxxxxxxx  (d + 2500)
                xxxxxxxxxxxxx- @ xxxxxxxxxxxxxxxx  (d + 2500) + 5000
                xxxxxxxxxxxxx- @ xxxxxxxxxxxxxxxx  (d + 2500) + 5000
                \stoptyping 

                We considered an array or a multiplier but when one has more than two in a row it 
                is already quite penalized and one has to go very tolerant and stretch so then the 
                solution space gets better and the threesome likely goes away. 
            */
            if (break_type == hyphenated_node && node_type(current) == hyphenated_node) {
                if (cur_p) {
                    demerits += properties->double_hyphen_demerits;
                } else {
                    demerits += properties->final_hyphen_demerits;
                }
            }
            /*tex
                Here |fitness| is just the subtype, so we could have put the cast in the macro
                instead: |#define fitness (n) ((halfword) (subtype (n))|. We need to cast because
                some compilers (versions or whatever) get confused by the type of (unsigned) integer
                used.
            */
            if (distance > 0) {
                demerits += tex_get_demerits(properties, fit_current, fit_class);
            }
        }
        if (properties->tracing_paragraphs > 0) {
         // tex_begin_diagnostic();
            tex_aux_print_feasible_break(cur_p, current, badness, penalty, demerits, artificial_demerits);
         // tex_end_diagnostic();
        }
        /*tex This is the minimum total demerits from the beginning to |cur_p| via |r|. */
        demerits += active_total_demerits(current);
        if (demerits <= lmt_linebreak_state.minimal_demerits[fit_class]) {
            lmt_linebreak_state.minimal_demerits[fit_class] = demerits;
            best_place[fit_class] = active_break_node(current);
            best_place_line[fit_class] = line;
            /*tex
                Store additional data for this feasible break. For each feasible break we record
                the shortfall and glue stretch or shrink (or adjustment). Contrary to \ETEX\ we
                do this always, also when we have no last line fit set.
            */
            best_place_short[fit_class] = shortfall;
            best_place_glue[fit_class] = glue;
            if (demerits < lmt_linebreak_state.minimum_demerits) {
                lmt_linebreak_state.minimum_demerits = demerits;
            }
        }
        /*tex Record a new feasible break. */
        if (current_stays_active) {
            /*tex |prev_r| has been set to |r|. */
            continue;
        }
      DEACTIVATE:
        /*tex

            Deactivate node |r|. When an active node disappears, we must delete an adjacent delta
            node if the active node was at the beginning or the end of the active list, or if it
            was surrounded by delta nodes. We also must preserve the property that |cur_active_width|
            represents the length of material from |vlink (prev_r)| to~|cur_p|.

        */
        node_next(previous) = node_next(current);
        if (callback_id) {
             tex_aux_line_break_callback_delete(current, active_break_node(current), callback_id, checks);
        }
        tex_flush_node(current);
        if (previous == active_head) {
            /*tex

                Update the active widths, since the first active node has been deleted. The following
                code uses the fact that |type (active) <> delta_node|. If the active list has just
                become empty, we do not need to update the |active_width| array, since it will be
                initialized when an active node is next inserted.

            */
            current = node_next(active_head);
            if (node_type(current) == delta_node) {
                tex_aux_add_to_target_from_delta(properties->adjust_spacing, lmt_linebreak_state.active_width, current);
                tex_aux_set_target_to_source(properties->adjust_spacing, current_active_width, lmt_linebreak_state.active_width);
                node_next(active_head) = node_next(current);
                tex_flush_node(current);
            }
        } else if (node_type(previous) == delta_node) {
            current = node_next(previous);
            if (current == active_head) {
                tex_aux_sub_delta_from_target(properties->adjust_spacing, current_active_width, previous);
                node_next(before_previous) = active_head;
                tex_flush_node(previous);
                previous = before_previous;
            } else if (node_type(current) == delta_node) {
                tex_aux_add_to_target_from_delta(properties->adjust_spacing, current_active_width, current);
                tex_aux_add_to_delta_from_delta(properties->adjust_spacing, previous, current);
                node_next(previous) = node_next(current);
                tex_flush_node(current);
            }
        }
    }
    return shortfall;
}

static halfword tex_aux_inject_orphan_penalty(halfword current, halfword amount, int orphaned)
{
    halfword previous = node_prev(current);
    if (previous && node_type(previous) != penalty_node) {
        halfword penalty = tex_new_penalty_node(amount, orphan_penalty_subtype);
        tex_couple_nodes(previous, penalty);
        tex_couple_nodes(penalty, current);
        if (orphaned) {
            tex_add_penalty_option(penalty, penalty_option_orphaned);
        }
        return previous;
    } else {
        return current;
    }
}

static halfword tex_aux_inject_toddler_penalty(halfword current, halfword amount, int toddlered)
{
    halfword previous = node_prev(current);
    if (previous && node_type(previous) != penalty_node) {
        halfword penalty = tex_new_penalty_node(amount, toddler_penalty_subtype);
        tex_couple_nodes(previous, penalty);
        tex_couple_nodes(penalty, current);
        if (toddlered) {
            tex_add_penalty_option(penalty, penalty_option_toddlered);
        }
        return previous;
    } else {
        return current;
    }
}

inline static int tex_aux_valid_glue_break(halfword p)
{
    halfword prv = node_prev(p);
    return (prv && prv != temp_head && (node_type(prv) == glyph_node || precedes_break(prv) || precedes_kern(prv) || precedes_dir(prv)));
}

inline static halfword tex_aux_upcoming_math_penalty(halfword p, halfword factor) {
    halfword n = node_next(p);
    if (n && node_type(n) == math_node && node_subtype(n) == begin_inline_math) { 
        return factor ? tex_xn_over_d(math_penalty(n), factor, scaling_factor) : math_penalty(n);
    } else { 
        return 0;
    }
}

/*tex

    I played a bit with a height driven hanging indentation. One can store |cur_p| in the active
    node and progressively calculate the height + depth and then act on that but in the end
    interline space, adjustsm etc. also have to be taken into account and that all happens later
    so in the end it makes no sense. There are valdi reasons why \TEX\ can't do some things
    reliable: user demands are unpredictable.

*/

/*tex

    Here we pickup the line number from |prev_graf| which relates to display math inside a
    paragraph. A display formula is then considered to span three lines. Of course this also
    assume a constant baseline distance with lines heigths not exceeding that amount. It also
    assumes that the shape and hang are not reset. We check the prevgraf for a large value
    because when we're close to |max_integer| we can wrap around due to addition beyond that
    and negative values has side effects (see musings-sideffects) but it's optional so that we
    can actually use these side effects.

*/

# define max_prev_graf (max_integer/2)

inline static int tex_aux_short_math(halfword m) {
    return m && node_subtype(m) == begin_inline_math && math_penalty(m) > 0 && tex_has_math_option(m, math_option_short);
}

inline static void tex_aux_adapt_short_math_penalty(halfword m, halfword p1, halfword p2, int orphaned) {
    if (p1 > math_penalty(m)) {
        math_penalty(m) = p1;
        if (orphaned) {
            tex_add_math_option(m, math_option_orphaned);
        }
    }
    if (p2 > math_penalty(m)) {
        math_penalty(m) = p2;
        if (orphaned) {
            tex_add_math_option(m, math_option_orphaned);
        }
    }
}

inline static halfword tex_aux_backtrack_over_math(halfword m)
{
    if (node_subtype(m) == end_inline_math) {
        do {
            m = node_prev(m);
        } while (m && node_type(m) != math_node);
    }
    return m;
}

inline static int tex_aux_emergency(const line_break_properties *properties)
{
    if (properties->emergency_stretch > 0) {
        return 1;
    } else if (properties->emergency_extra_stretch > 0) {
        return 1;
    } else if (! (tex_glue_is_zero(properties->emergency_left_skip) && glue_stretch_order(properties->emergency_left_skip) == normal_glue_order && glue_shrink_order(properties->emergency_left_skip) == normal_glue_order)) {
        return 1;
    } else if (! (tex_glue_is_zero(properties->emergency_right_skip) && glue_stretch_order(properties->emergency_right_skip) == normal_glue_order && glue_shrink_order(properties->emergency_right_skip) == normal_glue_order)) {
        return 1;
    } else {
        return 0;
    }
}

inline static int tex_aux_emergency_skip(halfword s)
{
    return ! tex_glue_is_zero(s) && glue_stretch_order(s) == normal_glue_order && glue_shrink_order(s) == normal_glue_order;
}

static scaled tex_check_linebreak_quality(scaled shortfall, scaled *overfull, scaled *underfull, halfword *verdict, halfword *classified)
{
    halfword active = active_break_node(lmt_linebreak_state.best_bet);
    halfword passive = passive_prev_break(active);
    int result = 1;
    /* last line ... */
    switch (active_quality(active)) {
        case par_is_overfull:
            *overfull = active_deficiency(active);
            *underfull = 0;
            break;
        case par_is_underfull:
            *overfull = 0;
            *underfull = active_deficiency(active);
            break;
        default:
            *overfull = 0;
            *underfull = 0;
            break;
    }
    *verdict = active_total_demerits(active);
    *classified |= (1 << active_fitness(active));
    /* previous lines */
    if (passive) { 
        while (passive) {
            switch (passive_quality(passive)) {
                case par_is_overfull:
                    if (passive_deficiency(passive) > *overfull) {
                        *overfull = passive_deficiency(passive);
                    }
                    break;
                case par_is_underfull:
                    if (passive_deficiency(passive) > *underfull) {
                        *underfull = passive_deficiency(passive);
                    }
                    break;
                default: 
                    /* not in tex */
                    break;
            }
            // *classified |= classification[node_subtype(q)];
            *classified |= (1 << node_subtype(passive));
            if (passive_demerits(passive) > *verdict) {
                *verdict = passive_demerits(passive);
            }
            passive = passive_prev_break(passive);
        }
    } else { 
        /*tex 
            Likely a single overfull line, but is this always okay? When the tolerance is too 
            low an emergency pass is needed then but in our case we want to enter par passes. We
            might need an option to disable this branch when we go for par passes only in order
            to be compatible with regular TeX.
        */
        if (passive_demerits(active) > *verdict) {
            *verdict = passive_demerits(active);
            result = 2;
        }
        if (-shortfall > *overfull) {
            *overfull = -shortfall; 
            result = 2;
        }
    }
    if (*verdict > infinite_bad) {
        *verdict = infinite_bad;
    }
    return result;
}

static void tex_aux_quality_callback(
    int callback_id, halfword par, 
    int id, int pass, int subpass, int subpasses, int state, 
    halfword overfull, halfword underfull, halfword verdict, halfword classified
)
{
    lmt_run_callback(
        lmt_lua_state.lua_instance, callback_id, "Ndddddddddd->N", 
        par, id, pass, subpass, subpasses, state, 
        overfull, underfull, verdict, classified,
        lmt_packaging_state.pack_begin_line,
        &lmt_linebreak_state.inject_after_par
    );
}

/*
    The orphan penalty injection is something new. It works backward so the first penalty in
    the list is injected first. If there is a penalty before a space we skip that space and
    also skip a penalty in the list.
*/

static void tex_aux_remove_special_penalties(const line_break_properties *properties)
{
    halfword current = node_prev(properties->parfill_right_skip);
    while (current) {
        switch (node_type(current)) {
            case glue_node:
            case penalty_node:
                current = node_prev(current);
                break;
            default:
                goto CHECK;
        }
    }
  CHECK:
    while (current) {
        halfword prev = node_prev(current);
        switch (node_type(current)) {
            case penalty_node:
                switch (node_subtype(current)) { 
                    case orphan_penalty_subtype:
                        if (tex_has_penalty_option(current, penalty_option_orphaned)) { 
                            tex_try_couple_nodes(prev, node_next(current));
                            tex_flush_node(current);
                        }
                        break;
                    case toddler_penalty_subtype:
                        if (tex_has_penalty_option(current, penalty_option_toddlered)) { 
                            tex_try_couple_nodes(prev, node_next(current));
                            tex_flush_node(current);
                        }
                        break;
                }
                break;
            case math_node:
                 current = tex_aux_backtrack_over_math(current);
                 if (tex_aux_short_math(current)) {
                     if (tex_has_math_option(current, math_option_orphaned)) {
                        math_penalty(current) = 0;
                        tex_remove_math_option(current, math_option_orphaned);
                     }
                 }
                return;
            case disc_node:
                if (tex_has_disc_option(current, disc_option_orphaned)) {
                    disc_orphaned(current) = 0;
                    tex_remove_disc_option(current, disc_option_orphaned);
                }
                break;
        }
        current = prev;
    }
}

static void tex_aux_apply_special_penalties(const line_break_properties *properties, halfword current, int state)
{
    (void) properties; 
    if (paragraph_has_math(state)) { 
        halfword factor = properties->math_penalty_factor;
        if (factor) {
            while (current) {
                switch (node_type(current)) {
                    case penalty_node:
                        switch (node_subtype(current)) { 
                            case math_pre_penalty_subtype:
                            case math_post_penalty_subtype: 
                                if (penalty_amount(current)) { 
                                    penalty_amount(current) = tex_xn_over_d(penalty_amount(current), factor, scaling_factor);
                                }
                                break;
                        }
                        break;
                    case math_node: 
                        if (math_penalty(current)) { 
                            math_penalty(current) = tex_xn_over_d(math_penalty(current), factor, scaling_factor);
                        }
                        break;
                }
                current = node_next(current);
            }
        }
    }
}

/*tex 
    We could act upon a callback if needed. We could also have a flag in the hc property 
    but then we also need to carry that in glyph options (glyph_option_text or so). One could 
    also argue for uppercase only in which case we shopuld have a uppercase flag in the glyph 
    state. 

    An alternative is to delay this till we check a break and add to the demerits as we do with
    twins but this is also a bit of a demo of how to do this. 
*/

static void tex_aux_set_toddler_penalties(const line_break_properties *properties, int toddlered)
{
    if (properties->toddler_penalty) {
        halfword current = node_next(properties->parinit_left_skip);
        int count = -1;
        while (current) {
            switch (node_type(current)) {
                case glue_node:
                    switch (node_subtype(current)) { 
                        case space_skip_glue:
                        case xspace_skip_glue:
                        case zero_space_skip_glue:
                            if (count == 1) {
                                /* we have a glue + one glyph + glue */
                                halfword nxt = node_next(current);
                                if (nxt && node_type(nxt) == glyph_node && glyph_node_is_text(nxt) && tex_has_glyph_option(nxt, glyph_option_check_toddler)) {
                                     /* we have a glue + one glyph + glue + glyph */
                                    current = tex_aux_inject_toddler_penalty(current, properties->toddler_penalty, toddlered);
                                }
                            } else { 
                                count = 0;
                            }
                            break;
                        default: 
                            --count; 
                            break;
                    }
                    break;
                case glyph_node:
                    if (count >= 0 && glyph_node_is_text(current) && tex_has_glyph_option(current, glyph_option_check_toddler)) { 
                        ++count;
                    }
                    break;
                default:
                    --count; 
            }
            current = node_next(current);
        }
    }
}

static void tex_aux_set_orphan_penalties(const line_break_properties *properties, int orphaned)
{
    if (properties->orphan_penalties || properties->orphan_penalty || short_inline_orphan_penalty_par) {
        halfword current = node_prev(properties->parfill_right_skip);
        if (current) {
            /*tex Skip over trailing glue and penalties. */
            while (current) {
                switch (node_type(current)) {
                    case glue_node:
                    case penalty_node:
                        current = node_prev(current);
                        break;
                    default:
                        goto INJECT;
                }
            }
          INJECT:
            if (properties->orphan_penalties) {
                /*tex
                    Inject specified penalties before spaces. When we see a math node with a penalty
                    set then we take the max and jump over a (preceding) skip. Maybe at some point
                    the |short_inline_orphan_penalty_par| value will also move into the par state.
                */
                int n = specification_count(properties->orphan_penalties);
                if (n > 0) {
                    int skip = 0;
                    halfword i = 0;
                    while (current) {
                        switch (node_type(current)) {
                            case glue_node:
                                switch (node_subtype(current)) {
                                    case space_skip_glue:
                                    case xspace_skip_glue:
                                    case zero_space_skip_glue:
                                        if (skip) {
                                            skip = 0;
                                        } else {
                                            current = tex_aux_inject_orphan_penalty(current, tex_get_specification_penalty(properties->orphan_penalties, ++i), 0);
                                        }
                                        if (i == n) {
                                            return;
                                        } else {
                                            break;
                                        }
                                }
                                break;
                            case math_node:
                                current = tex_aux_backtrack_over_math(current);
                                if (tex_aux_short_math(current)) {
                                    halfword p = tex_get_specification_penalty(properties->orphan_penalties, ++i);
                                    tex_aux_adapt_short_math_penalty(current, short_inline_orphan_penalty_par, p, 0);
                                    if (i == n) {
                                        return;
                                    } else {
                                        skip = 1;
                                    }
                                } else {
                                    return;
                                }
                                break;
                            case disc_node:
                                skip = 0;
                                if (i < n) {
                                    disc_orphaned(current) = tex_get_specification_penalty(properties->orphan_penalties, i + 1);
                                    if (orphaned) {
                                        tex_add_disc_option(current, disc_option_orphaned);
                                    }
                                }
                                break;
                            default:
                                skip = 0;
                                break;
                        }
                        current = node_prev(current);
                    }
                }
            } else if (properties->orphan_penalty) {
                /*tex
                    We inject a penalty before the space but we need to intercept the math penalty
                    that actually is set on the math mode.  If no math orphan penalty is set of when
                    we have wider math then we assume it's okay. We don't want interference in math
                    penalties.

                */
                while (current) {
                    switch (node_type(current)) {
                        case glue_node:
                            switch (node_subtype(current)) {
                                case space_skip_glue:
                                case xspace_skip_glue:
                                case zero_space_skip_glue:
                                    tex_aux_inject_orphan_penalty(current, properties->orphan_penalty, orphaned);
                                    return;
                                default:
                                    /* maybe we should always quit here */
                                    break;
                            }
                            break;
                        case penalty_node:
                            if (node_subtype(current) == orphan_penalty_subtype) {
                                return;
                            }
                            break;
                        case math_node:
                            current = tex_aux_backtrack_over_math(current);
                            if (tex_aux_short_math(current)) {
                                tex_aux_adapt_short_math_penalty(current, short_inline_orphan_penalty_par, properties->orphan_penalty, orphaned);
                            }
                            return;
                        case disc_node:
                            /*
                                This is (or has been) actually an old \CONTEXT\ feature doen in \LUA,
                                so what should we do here: set the penalty and quit or maybe run till we
                                hit a non glyph, disc or font kern? Hyphens already get penalties. So,
                                we do nothong.
                            */
                            disc_orphaned(current) = properties->orphan_penalty;
                            if (orphaned) {
                                tex_add_disc_option(current, disc_option_orphaned);
                            }
                            break;
                    }
                    current = node_prev(current);
                }
            } else if (short_inline_orphan_penalty_par) {
                /*tex
                    Short formulas at the end of a line are normally not followed by something other
                    than punctuation. In practice one can set this penalty to e.g. a relatively low
                    200 to get the desired effect. We definitely quit on a space and take for granted
                    what comes before we see the formula.
                */
                while (current) {
                    switch (node_type(current)) {
                        case glue_node:
                            switch (node_subtype(current)) {
                                case space_skip_glue:
                                case xspace_skip_glue:
                                case zero_space_skip_glue:
                                    return;
                            }
                            break;
                        case math_node:
                            current = tex_aux_backtrack_over_math(current);
                            if (tex_aux_short_math(current)) {
                                tex_aux_adapt_short_math_penalty(current, short_inline_orphan_penalty_par, 0, 0);
                            }
                            return;

                    }
                    current = node_prev(current);
                }
            }
        }
    }
}

inline static int tex_aux_has_expansion(void) /* could be part of this identify pass over the list */
{
    if (lmt_linebreak_state.checked_expansion == -1) {
        halfword current = node_next(temp_head);
        while (current) {
            if (node_type(current) == glyph_node && has_font_text_control(glyph_font(current), text_control_expansion)) {
                lmt_linebreak_state.checked_expansion = 1;
                break;
            } else {
                current = node_next(current);
            }
        }
        lmt_linebreak_state.checked_expansion = 0;
    }
    return lmt_linebreak_state.checked_expansion;
}

inline static void tex_aux_set_initial_active(const line_break_properties *properties)
{
    halfword initial = tex_new_node(unhyphenated_node, (quarterword) tex_get_specification_decent(properties->fitness_demerits) - 1);
    node_next(initial) = active_head;
    active_break_node(initial) = null;
    active_line_number(initial) = cur_list.prev_graf + 1;
    active_total_demerits(initial) = 0; // default
    active_short(initial) = 0;          // default
    active_glue(initial) = 0;           // default
    active_line_width(initial) = 0;     // default
    node_next(active_head) = initial;
}

inline static void tex_aux_set_local_par_state(halfword current)
{
    if (current && node_type(current) == par_node) {
        switch (node_subtype(current)) {
            case vmode_par_par_subtype:
            case hmode_par_par_subtype:
                /*tex We'd better be at the start here. */
                node_prev(current) = temp_head;
            break;
        }
        /* */
        lmt_linebreak_state.internal_interline_penalty = tex_get_local_interline_penalty(current);
        lmt_linebreak_state.internal_broken_penalty = tex_get_local_broken_penalty(current);
        lmt_linebreak_state.internal_par_node = current;
        /* */
        lmt_linebreak_state.internal_left_box_init = par_box_left(current);
        lmt_linebreak_state.internal_left_box_width_init = tex_get_local_left_width(current);
        lmt_linebreak_state.internal_right_box = par_box_right(current);
        lmt_linebreak_state.internal_right_box_width = tex_get_local_right_width(current);
        lmt_linebreak_state.internal_middle_box = par_box_middle(current);
    } else {
        lmt_linebreak_state.internal_interline_penalty = 0;
        lmt_linebreak_state.internal_broken_penalty = 0;
        lmt_linebreak_state.internal_par_node = null;
        lmt_linebreak_state.internal_left_box_init = null;
        lmt_linebreak_state.internal_left_box_width_init = 0;
        lmt_linebreak_state.internal_right_box = null;
        lmt_linebreak_state.internal_right_box_width = 0;
        lmt_linebreak_state.internal_middle_box = null;
    }
    lmt_linebreak_state.internal_left_box = lmt_linebreak_state.internal_left_box_init;
    lmt_linebreak_state.internal_left_box_width = lmt_linebreak_state.internal_left_box_width_init;
}

inline static void tex_aux_set_adjust_spacing(line_break_properties *properties)
{
    if (properties->adjust_spacing) {
        lmt_linebreak_state.adjust_spacing = properties->adjust_spacing;
        if (properties->adjust_spacing_step > 0) {
            lmt_linebreak_state.adjust_spacing_step = properties->adjust_spacing_step;
//            lmt_linebreak_state.adjust_spacing_shrink = -properties->adjust_spacing_shrink; /* watch the sign */
            lmt_linebreak_state.adjust_spacing_shrink = properties->adjust_spacing_shrink;
            lmt_linebreak_state.adjust_spacing_stretch = properties->adjust_spacing_stretch;
        } else {
            lmt_linebreak_state.adjust_spacing_step = 0;
            lmt_linebreak_state.adjust_spacing_shrink = 0;
            lmt_linebreak_state.adjust_spacing_stretch = 0;
        }
        properties->adjust_spacing = tex_checked_font_adjust(
            properties->adjust_spacing,
            lmt_linebreak_state.adjust_spacing_step,
            lmt_linebreak_state.adjust_spacing_shrink,
            lmt_linebreak_state.adjust_spacing_stretch
        );
    } else {
        lmt_linebreak_state.adjust_spacing_step = 0;
        lmt_linebreak_state.adjust_spacing_shrink = 0;
        lmt_linebreak_state.adjust_spacing_stretch = 0;
        properties->adjust_spacing = adjust_spacing_off;
    }
    lmt_linebreak_state.current_font_step = -1;
}

inline static void tex_aux_set_looseness(const line_break_properties *properties)
{
    lmt_linebreak_state.actual_looseness = 0;
    if (properties->looseness == 0) {
        lmt_linebreak_state.easy_line = lmt_linebreak_state.last_special_line;
    } else {
        lmt_linebreak_state.easy_line = max_halfword;
    }
}

static int tex_aux_set_sub_pass_parameters(
    line_break_properties *properties, 
    halfword               passes, 
    int                    subpass, 
    halfword               first, 
    int                    details,
    halfword               features, 
    halfword               overfull, 
    halfword               underfull, 
    halfword               verdict, 
    halfword               classified, 
    halfword               threshold, 
    halfword               demerits, 
    halfword               classes    
) {
    int success = 0;
    halfword okay = tex_get_passes_okay(passes, subpass);
    /*tex 
        One of the more important properties: 
    */
    if (okay & passes_tolerance_okay) { 
        properties->tolerance = tex_get_passes_tolerance(passes, subpass);
    }
    lmt_linebreak_state.threshold = properties->tolerance;
    lmt_linebreak_state.global_threshold = lmt_linebreak_state.threshold;
    /*tex 
        The basics: tolerance, hyphenation and emergencystretch.
    */
    if (okay & passes_basics_okay) { 
        if (okay & passes_hyphenation_okay) { 
            lmt_linebreak_state.force_check_hyphenation = tex_get_passes_hyphenation(passes, subpass) > 0 ? 1 : 0;
        }
        if (okay & passes_emergencypercentage_okay) { 
            lmt_linebreak_state.emergency_percentage = tex_get_passes_emergencypercentage(passes, subpass);
        }
        if (okay & passes_emergencywidthextra_okay) { 
            lmt_linebreak_state.emergency_width_extra = tex_get_passes_emergencywidthextra(passes, subpass);
        }
        if (okay & passes_emergencyleftextra_okay) { 
            lmt_linebreak_state.emergency_left_extra = tex_get_passes_emergencyleftextra(passes, subpass);
        }
        if (okay & passes_emergencyleftextra_okay) { 
            lmt_linebreak_state.emergency_right_extra = tex_get_passes_emergencyrightextra(passes, subpass);
        }
    }
    /*tex 
        We also need to handle the current document emergency stretch. 
    */
    if (okay & passes_emergencystretch_okay) { 
        halfword v = tex_get_passes_emergencystretch(passes, subpass);
        if (v) {
            properties->emergency_stretch = v;
            properties->emergency_original = v; /* ! */
        } else { 
            properties->emergency_stretch = properties->emergency_original;
        }
    } else { 
        properties->emergency_stretch = properties->emergency_original;
    }
    if (okay & passes_emergencyfactor_okay) { 
        halfword v = tex_get_passes_emergencyfactor(passes, subpass);
        if (v >= 0) {
            properties->emergency_stretch = tex_xn_over_d(properties->emergency_original, v, scaling_factor);
        }
    }
    lmt_linebreak_state.background[total_stretch_amount] -= lmt_linebreak_state.extra_background_stretch;
    lmt_linebreak_state.extra_background_stretch = properties->emergency_stretch;
    lmt_linebreak_state.background[total_stretch_amount] += properties->emergency_stretch;
    /*tex 
        The additional settings, they are seldom set so we try to avoid this branch: 
    */
    if (okay & passes_additional_okay) { 
        if (okay & passes_linepenalty_okay) { 
            properties->line_penalty = tex_get_passes_linepenalty(passes, subpass);
        }
        if (okay & passes_orphanpenalty_okay) { 
            properties->orphan_penalty = tex_get_passes_orphanpenalty(passes, subpass);
        }
        if (okay & passes_toddlerpenalty_okay) { 
            properties->toddler_penalty = tex_get_passes_toddlerpenalty(passes, subpass);
        }
        if (okay & passes_lefttwindemerits_okay) { 
            properties->left_twin_demerits = tex_get_passes_lefttwindemerits(passes, subpass);
        }
        if (okay & passes_righttwindemerits_okay) { 
            properties->right_twin_demerits = tex_get_passes_righttwindemerits(passes, subpass);
        }
        if (okay & passes_extrahyphenpenalty_okay) { 
            properties->extra_hyphen_penalty = tex_get_passes_extrahyphenpenalty(passes, subpass);
        }
        if (okay & passes_doublehyphendemerits_okay) { 
            properties->double_hyphen_demerits = tex_get_passes_doublehyphendemerits(passes, subpass);
        }
        if (okay & passes_finalhyphendemerits_okay) { 
            properties->final_hyphen_demerits = tex_get_passes_finalhyphendemerits(passes, subpass);
        }
        if (okay & passes_adjdemerits_okay) { 
            properties->adj_demerits = tex_get_passes_adjdemerits(passes, subpass);
        }
        if (okay & passes_fitnessdemerits_okay) { 
            properties->fitness_demerits = tex_get_passes_fitnessdemerits(passes, subpass);
        }
        if (okay & passes_linebreakchecks_okay) { 
            properties->line_break_checks = tex_get_passes_linebreakchecks(passes, subpass);
        }
        if (okay & passes_linebreakoptional_okay) {
            properties->line_break_optional = tex_get_passes_linebreakoptional(passes, subpass);
        }
    }
    /*tex 
        This one is kind of special (the values are checked in maincontrol): 
    */
    if (okay & passes_mathpenaltyfactor_okay) { 
        properties->math_penalty_factor = tex_get_passes_mathpenaltyfactor(passes, subpass);
    }
    /*tex 
        Expansion (aka hz): 
    */
    if (okay & passes_expansion_okay) { 
        if (okay & passes_adjustspacingstep_okay) { 
            properties->adjust_spacing_step = tex_get_passes_adjustspacingstep(passes, subpass);
        }
        if (okay & passes_adjustspacingshrink_okay) { 
            properties->adjust_spacing_shrink = tex_get_passes_adjustspacingshrink(passes, subpass);
        }
        if (okay & passes_adjustspacingstretch_okay) { 
            properties->adjust_spacing_stretch = tex_get_passes_adjustspacingstretch(passes, subpass);
        }
        if (okay & passes_adjustspacing_okay) { 
            properties->adjust_spacing = tex_get_passes_adjustspacing(passes, subpass);
        }
    }
    tex_aux_set_adjust_spacing(properties);
    /*tex 
        Callbacks: 0=quit, 1=once, 2=repeat
    */
    if (okay & passes_callback_okay) { 
        halfword callback = tex_get_passes_callback(passes, subpass);
        halfword id = passes_identifier(passes);
        int repeat = 0;
        success = lmt_par_pass_callback(
            first,
            properties, id, subpass, callback, features,
            overfull, underfull, verdict, classified,
            threshold, demerits, classes, &repeat
        );
        if (repeat) {
            subpass -= 1;
        }
    } else {
        success = 1;
    }
    /*tex
        We need to handle some special penalties:
    */
    tex_aux_remove_special_penalties(properties);
    /* todo : set plural in par pass */
    if (okay & passes_orphanpenalty_okay) { 
        tex_aux_set_orphan_penalties(properties, 1);
    }
    if (okay & passes_toddlerpenalty_okay) { 
        tex_aux_set_toddler_penalties(properties, 1);
    }
    /* */
    if (details) {

        # define is_okay(a) ((okay & a) == a ? ">" : " ")

        tex_begin_diagnostic();
        tex_print_format("[linebreak: values used in subpass %i]\n", subpass);
        tex_print_str("  --------------------------------\n");
        tex_print_format("  use criteria          %s\n", subpass >= passes_first_final(passes) ? "true" : "false");
        if (features & passes_test_set) {
            tex_print_str("  --------------------------------\n");
            if (features & passes_if_text)              { tex_print_format("  if text              true\n"); }
            if (features & passes_if_math)              { tex_print_format("  if math              true\n"); }
            if (features & passes_if_glue)              { tex_print_format("  if glue              true\n"); }
            if (features & passes_if_adjust_spacing)    { tex_print_format("  if adjust spacing    true\n"); }
            if (features & passes_if_emergency_stretch) { tex_print_format("  if emergency stretch true\n"); }
            if (features & passes_unless_math)          { tex_print_format("  unless math          true\n"); }
        }
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s threshold            %p\n", is_okay(passes_threshold_okay),            tex_get_passes_threshold(passes, subpass));
        tex_print_format("%s demerits             %i\n", is_okay(passes_demerits_okay),             tex_get_passes_demerits(passes, subpass));
        tex_print_format("%s classes              %X\n", is_okay(passes_classes_okay),              tex_get_passes_classes(passes, subpass));
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s tolerance            %i\n", is_okay(passes_tolerance_okay),            properties->tolerance);
        tex_print_format("%s hyphenation          %i\n", is_okay(passes_hyphenation_okay),          lmt_linebreak_state.force_check_hyphenation);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s fitnessdemerits      %i",   is_okay(passes_fitnessdemerits_okay),      tex_get_specification_count(properties->fitness_demerits));
        if (tex_get_specification_count(properties->fitness_demerits) > 0) {
            for (halfword c = 1; c <= tex_get_specification_count(properties->fitness_demerits); c++) { 
                tex_print_format(" [%i %i %i]", 
                    tex_get_specification_fitness   (properties->fitness_demerits, c),
                    tex_get_specification_demerits_u(properties->fitness_demerits, c),
                    tex_get_specification_demerits_d(properties->fitness_demerits, c)
                );
            }
        }
        tex_print_str("\n");
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s emergencystretch     %p\n", is_okay(passes_emergencystretch_okay),     properties->emergency_stretch);
        tex_print_format("%s emergencyfactor      %i\n", is_okay(passes_emergencyfactor_okay),      tex_get_passes_emergencyfactor(passes, subpass));
        tex_print_format("%s emergencystretch     %p\n", is_okay(passes_emergencystretch_okay),     tex_get_passes_emergencystretch(passes, subpass));
        tex_print_format("%s emergencyperentage   %i\n", is_okay(passes_emergencypercentage_okay),  tex_get_passes_emergencypercentage(passes, subpass));
        tex_print_format("%s emergencyleftextra   %i\n", is_okay(passes_emergencyleftextra_okay),   tex_get_passes_emergencyleftextra(passes, subpass));
        tex_print_format("%s emergencyrightextra  %i\n", is_okay(passes_emergencyrightextra_okay),  tex_get_passes_emergencyrightextra(passes, subpass));
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s mathpenaltyfactor    %i\n", is_okay(passes_mathpenaltyfactor_okay),    properties->math_penalty_factor);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s adjustspacing        %i\n", is_okay(passes_adjustspacing_okay),        properties->adjust_spacing);
        tex_print_format("%s adjustspacingstep    %i\n", is_okay(passes_adjustspacingstep_okay),    properties->adjust_spacing_step);
        tex_print_format("%s adjustspacingshrink  %i\n", is_okay(passes_adjustspacingshrink_okay),  properties->adjust_spacing_shrink);
        tex_print_format("%s adjustspacingstretch %i\n", is_okay(passes_adjustspacingstretch_okay), properties->adjust_spacing_stretch);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s adjdemerits          %i\n", is_okay(passes_adjdemerits_okay),          properties->adj_demerits);
        tex_print_format("%s doublehyphendemerits %i\n", is_okay(passes_doublehyphendemerits_okay), properties->double_hyphen_demerits);
        tex_print_format("%s finalhyphendemerits  %i\n", is_okay(passes_finalhyphendemerits_okay),  properties->final_hyphen_demerits);
        tex_print_format("%s lefttwindemerits     %i\n", is_okay(passes_lefttwindemerits_okay),     properties->left_twin_demerits);
        tex_print_format("%s righttwindemerits    %i\n", is_okay(passes_righttwindemerits_okay),    properties->right_twin_demerits);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s linepenalty          %i\n", is_okay(passes_linepenalty_okay),          properties->line_penalty);
        tex_print_format("%s extrahyphenpenalty   %i\n", is_okay(passes_extrahyphenpenalty_okay),   properties->extra_hyphen_penalty);
        tex_print_format("%s orphanpenalty        %i\n", is_okay(passes_orphanpenalty_okay),        properties->orphan_penalty);
        tex_print_format("%s toddlerpenalty       %i\n", is_okay(passes_toddlerpenalty_okay),       properties->toddler_penalty);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s linebreakchecks      %i\n", is_okay(passes_linebreakchecks_okay),      properties->line_break_checks);
        tex_print_format("%s linebreakoptional    %i\n", is_okay(passes_linebreakoptional_okay),    properties->line_break_optional);
        tex_print_str("  --------------------------------\n");
        tex_end_diagnostic();
    }
    return success;
}

static void tex_aux_skip_message(halfword passes, int subpass, int nofsubpasses, const char *str)
{
    tex_begin_diagnostic();
    tex_print_format("[linebreak: id %i, subpass %i of %i, skip %s]\n",
        passes_identifier(passes), subpass, nofsubpasses, str
    );
    tex_end_diagnostic();
}

inline static int tex_aux_next_subpass(const line_break_properties *properties, halfword passes, int subpass, int nofsubpasses, halfword state, int tracing)
{
    while (++subpass <= nofsubpasses) {
        halfword features = tex_get_passes_features(passes, subpass);
        if (features & passes_test_set) {
            if (features & passes_if_text) {
                if (! paragraph_has_text(state)) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "no text");
                    }
                    continue;
                }
            } 
            if (features & passes_if_math) {
                if (! paragraph_has_math(state)) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "no math");
                    }
                    continue;
                }
            } 
            if (features & passes_unless_math) {
                if (paragraph_has_math(state)) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "do math");
                    }
                    continue;
                }
            } 
            if (features & passes_if_glue) {
                if (! paragraph_has_glue(state)) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "no glue");
                    }
                    continue;
                }
            } 
            if (features & passes_if_adjust_spacing && tex_aux_has_expansion()) {
                if (! paragraph_has_text(state) || ! tex_get_passes_adjustspacing(passes, subpass)) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "adjust spacing");
                    }
                    continue;
                }
            } 
            if (features & passes_if_emergency_stretch) {
                if (! ( (properties->emergency_original || tex_get_passes_emergencystretch(passes, subpass)) && tex_get_passes_emergencyfactor(passes, subpass) ) ) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "emergcy stretch");
                    }
                    continue;
                }
            }
        }
        return subpass;
    }
    return nofsubpasses + 1;
}

inline static int tex_aux_check_sub_pass(line_break_properties *properties, halfword state, scaled shortfall, halfword passes, int subpass, int nofsubpasses, halfword first)
{
    scaled overfull = 0;
    scaled underfull = 0;
    halfword verdict = 0;
    halfword classified = 0;
    int tracing = properties->tracing_paragraphs > 0 || properties->tracing_passes > 0;
    int result = tex_check_linebreak_quality(shortfall, &overfull, &underfull, &verdict, &classified);
    if (result) {
        if (tracing && result > 1) {
            tex_begin_diagnostic();
            tex_print_format("[linebreak: id %i, subpass %i of %i, overfull %p, verdict %i, special case, entering subpasses]\n",
                passes_identifier(passes), subpass, nofsubpasses, overfull, verdict 
            );
            tex_end_diagnostic();
        }
        while (subpass < nofsubpasses) {
            subpass = tex_aux_next_subpass(properties, passes, subpass, nofsubpasses, state, tracing);
            if (subpass > nofsubpasses) {
                return subpass;
            } else {
                halfword features = tex_get_passes_features(passes, subpass);
                if (features & passes_quit_pass) {
                    return -1;
                } else if (features & passes_skip_pass) {
                    continue;
                } else {
                    scaled threshold = tex_get_passes_threshold(passes, subpass);
                    halfword demerits = tex_get_passes_demerits(passes, subpass);
                    halfword classes = tex_get_passes_classes(passes, subpass);
                    int callback = features & passes_callback_set;
                    int success = 0;
                    int details = properties->tracing_passes > 1;
                    int retry = callback ? 1 : overfull > threshold || verdict > demerits || (classes && (classes & classified) != 0);
                    if (tracing) {
                        int id = passes_identifier(passes);
                        tex_begin_diagnostic();
                        if (callback) {
                            tex_print_format("[linebreak: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, classified %x, %s]\n",
                                id, subpass, nofsubpasses, overfull, underfull, verdict, classified, "callback"
                            );
                        } else {
                            const char *action = retry ? "retry" : "skipped";
                            if (id < 0) {
                                id = -id; /* nicer for our purpose */
                            }
                            if (threshold == max_dimension) {
                                if (demerits == max_dimension) {
                                    tex_print_format("[linebreak: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, classified, action
                                    );
                                } else {
                                    tex_print_format("[linebreak: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, demerits %i, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, demerits, classified, action
                                    );
                                }
                            } else {
                                if (demerits == max_dimension) {
                                    tex_print_format("[linebreak: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, threshold %p, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, threshold, classified, action
                                    );
                                } else {
                                    tex_print_format("[linebreak: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, threshold %p, demerits %i, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, threshold, demerits, classified, action
                                    );
                                }
                            }
                        }
                    }
                    if (retry) {
                        success = tex_aux_set_sub_pass_parameters(
                            properties, passes, subpass, first, 
                            details, 
                            features, overfull, underfull, verdict, classified, threshold, demerits, classes
                        );
                    }
                    if (tracing) {
                        tex_end_diagnostic();
                    }
                    if (success) {
                        return subpass;
                    }
                }
            }
        }
    } else {
        /*tex We have a few hits in our test files. */
    }
    return 0;
}

/*tex

    To access the first node of paragraph as the first active node has |break_node = null|.

    Determine legal breaks: As we move through the hlist, we need to keep the |active_width| array
    up to date, so that the badness of individual lines is readily calculated by |try_break|. It
    is convenient to use the short name |active_width [1]| for the component of active width that
    represents real width as opposed to glue.

    Advance |cur_p| to the node following the present string of characters. The code that passes
    over the characters of words in a paragraph is part of \TEX's inner loop, so it has been
    streamlined for speed. We use the fact that |\parfillskip| glue appears at the end of each
    paragraph; it is therefore unnecessary to check if |vlink (cur_p) = null| when |cur_p| is a
    character node.

    Advance |cur_p| to the node following the present string of characters. The code that passes
    over the characters of words in a paragraph is part of \TEX's inner loop, so it has been
    streamlined for speed. We use the fact that |\parfillskip| glue appears at the end of each
    paragraph; it is therefore unnecessary to check if |vlink (cur_p) = null| when |cur_p| is
    a character node. (This is no longer true because we've split the hyphenation and font
    processing steps.)

    The code below is in the meantime a mix between good old \TEX, \ETEX\ (last line) , \OMEGA\
    (local boxes but redone), \PDFTEX\ (expansion and protrusion), \LUATEX\ and quite a bit of
    \LUAMETATEX. But the principles remain the same.

*/

inline static void tex_aux_wipe_optionals(const line_break_properties *properties, halfword current, int state)
{
    if (paragraph_has_optional(state)) {
     // printf("WIPING OPTIONALS\n");
        while (current) {
            if (node_type(current) == boundary_node && node_subtype(current) == optional_boundary) {
                if (properties->line_break_optional) {
                    if (! boundary_data(current)) {
                     // printf("END KEEPING\n");
                        current = node_next(current);
                        continue;
                    } else if ((boundary_data(current) & properties->line_break_optional) == properties->line_break_optional) {
                     // printf("BEGIN KEEPING\n");
                        current = node_next(current);
                        continue;
                    }
                }
                {
                    halfword first = current;
                 // printf("BEGIN WIPING\n");
                    while (1) {
                        current = node_next(current);
                        if (! current) {
                            return;
                        } else if (node_type(current) == boundary_node && node_subtype(current) == optional_boundary && ! boundary_data(current) ) {
                         // printf("END WIPING\n");
                            halfword prev = node_prev(first);
                            halfword next = node_next(current);
                            halfword wiped = first;
                            node_next(current) = null;
                            tex_try_couple_nodes(prev, next);
                            tex_flush_node_list(wiped);
                            current = prev;
                            break;
                        }
                    }
                }
            }
            current = node_next(current);
        }
    }
}

static void tex_aux_show_threshold(const char *what, halfword value) 
{
    tex_begin_diagnostic();
    tex_print_format("[linebreak: %s threshold %i]", what, value);
    tex_end_diagnostic();
}

/*tex
    In most cases (90\percent\ or more) we have only one pass so then it makes sense to just use 
    that pass and accept some redundant stat echecking later on. 
*/

/*

inline static halfword tex_aux_analyze_list(halfword current)
{
    halfword state = 0;
    while (current) {
        switch (node_type(current)) {
            case glyph_node:
                state |= par_has_glyph;
                break;
            case glue_node:
                switch (node_subtype(current)) {
                    case space_skip_glue:
                    case xspace_skip_glue:
                    case zero_space_skip_glue:
                        state |= par_has_space;
                        break;
                    case u_leaders:
                        state |= par_has_uleader;
                        break;
                }
                state |= par_has_glue; // todo: only when stretch or shrink
                break;
            case disc_node:
                state |= par_has_disc;
                break;
            case math_node:
                if (! (tex_math_glue_is_zero(current) || tex_ignore_math_skip(current))) {
                    state |= par_has_glue; // todo: only when stretch or shrink
                }
                state |= par_has_math;
                break;
            case boundary_node:
                if (node_subtype(current) == optional_boundary) {
                    state |= par_has_optional;
                }
                break;
        }
        current = node_next(current);
    }
    return state;
}
*/

inline static halfword tex_aux_break_list(const line_break_properties *properties, halfword pass, halfword current, halfword first, halfword *state, int artificial)
{
    halfword callback_id = lmt_linebreak_state.callback_id;
    halfword checks = properties->line_break_checks;
    while (current && (node_next(active_head) != active_head)) { /* we check the cycle */
        switch (node_type(current)) {
            case glyph_node:
                /* why ex here and not in add/sub disc glyphs */
                lmt_linebreak_state.active_width[total_advance_amount] += tex_glyph_width(current);
                if (properties->adjust_spacing && properties->adjust_spacing_step > 0 && tex_has_glyph_expansion(current)) {
                    lmt_packaging_state.previous_char_ptr = current;
                    lmt_linebreak_state.active_width[font_stretch_amount] += tex_char_stretch(current);
                    lmt_linebreak_state.active_width[font_shrink_amount] += tex_char_shrink(current);
                }
                *state |= par_has_glyph;
                break;
            case hlist_node:
            case vlist_node:
                lmt_linebreak_state.active_width[total_advance_amount] += box_width(current);
                break;
            case rule_node:
                lmt_linebreak_state.active_width[total_advance_amount] += rule_width(current);
                break;
            case dir_node:
                /*tex Adjust the dir stack for the |line_break| routine. */
                lmt_linebreak_state.line_break_dir = tex_update_dir_state(current, properties->paragraph_dir);
                break;
            case par_node:
                /*tex Advance past a |par| node. */
                switch (node_subtype(current)) {
                    case vmode_par_par_subtype:
                    case hmode_par_par_subtype:
                        break;
                    case local_box_par_subtype:
                        break;
                    case parameter_par_subtype:
                        {
                            halfword t = pass == linebreak_first_pass ? tex_get_local_pre_tolerance(current) : tex_get_local_tolerance(current);
                            if (t == 0) {
                                t = lmt_linebreak_state.global_threshold;
                                if (properties->tracing_paragraphs > 1) {
                                    tex_aux_show_threshold("global", t);
                                }
                            } else { 
                                if (properties->tracing_paragraphs > 1) {
                                    tex_aux_show_threshold("local", t);
                                }
                            }
                            lmt_linebreak_state.threshold = t;
                            lmt_linebreak_state.internal_interline_penalty = tex_get_local_interline_penalty(current);
                            lmt_linebreak_state.internal_broken_penalty = tex_get_local_broken_penalty(current);
                            lmt_linebreak_state.internal_par_node = current;
                            break;
                        }
                    case local_break_par_subtype:
                        /*tex 
                            This is an experiment. We might at some point use more trickery with 
                            these nodes. 
                        */
                        tex_aux_try_break(properties, -100000, unhyphenated_node, first, current, callback_id, checks, pass, artificial);
                        break;
                }
                lmt_linebreak_state.internal_left_box = par_box_left(current);
                lmt_linebreak_state.internal_left_box_width = tex_get_local_left_width(current);
                lmt_linebreak_state.internal_right_box = par_box_right(current);
                lmt_linebreak_state.internal_right_box_width = tex_get_local_right_width(current);
                lmt_linebreak_state.internal_middle_box = par_box_middle(current);
                break;
            case glue_node:
                /*tex

                    If node |cur_p| is a legal breakpoint, call |try_break|; then update the
                    active widths by including the glue in |glue_ptr(cur_p)|.

                    When node |cur_p| is a glue node, we look at the previous to see whether
                    or not a breakpoint is legal at |cur_p|, as explained above.

                    We only break after certain nodes (see texnodes.h), a font related kern
                    and a dir node when |\breakafterdirmode = 1|.

                */
                if (tex_has_glue_option(current, glue_option_no_auto_break)) {
                    /*tex Glue in math is not a valid breakpoint, unless we permit it. */
                } else if (tex_is_par_init_glue(current)) {
                    /*tex Of course we don't break here. */
                } else if (tex_aux_valid_glue_break(current)) {
                    tex_aux_try_break(properties, tex_aux_upcoming_math_penalty(current, properties->math_penalty_factor), unhyphenated_node, first, current, callback_id, checks, pass, artificial);
                }
                lmt_linebreak_state.active_width[total_advance_amount] += glue_amount(current);
                lmt_linebreak_state.active_width[total_stretch_amount + glue_stretch_order(current)] += glue_stretch(current);
                lmt_linebreak_state.active_width[total_shrink_amount] += tex_aux_checked_shrink(current);
                switch (node_subtype(current)) {
                    case space_skip_glue:
                    case xspace_skip_glue:
                    case zero_space_skip_glue:
                        *state |= par_has_space;
                        break;
                    case u_leaders:
                        *state |= par_has_uleader;
                        break;
                }
                *state |= par_has_glue; /* todo: only when stretch or shrink */
                break;
            case kern_node:
                switch (node_subtype(current)) {
                    case explicit_kern_subtype:
                    case italic_kern_subtype:
                    case right_correction_kern_subtype:
                        {
                            /*tex There used to be a |! is_char_node(node_next(cur_p))| test here. */
                            /*tex We catch |\emph{test} $\hat{x}$| aka |test\kern5pt\hskip10pt$\hat{x}$|. */
                            halfword nxt = node_next(current);
                            if (nxt && node_type(nxt) == glue_node && ! tex_aux_upcoming_math_penalty(nxt, properties->math_penalty_factor) && ! tex_has_glue_option(nxt, glue_option_no_auto_break)) {
                                tex_aux_try_break(properties, 0, unhyphenated_node, first, current, callback_id, checks, pass, artificial);
                            }
                        }
                        break;
                 // case left_correction_kern_subtype:
                 //     break;
                    case font_kern_subtype:
                        if (properties->adjust_spacing == adjust_spacing_full) {
                            lmt_linebreak_state.active_width[font_stretch_amount] += tex_kern_stretch(current);
                            lmt_linebreak_state.active_width[font_shrink_amount] += tex_kern_shrink(current);
                        }
                        break;
                }
                lmt_linebreak_state.active_width[total_advance_amount] += kern_amount(current);
                break;
            case disc_node:
                /*tex

                    Try to break after a discretionary fragment, then |goto done5|. The
                    following code knows that discretionary texts contain only character
                    nodes, kern nodes, box nodes, and rule nodes. This branch differs a bit
                    from older engines because in \LUATEX\ we already have hyphenated the list.
                    This means that we need to skip automatic disc nodes. Or better, we need
                    to treat discretionaries and explicit hyphens always, even in the first
                    pass.

                    We used to have |init_disc| followed by |select disc| variants where the
                    |select_disc|s were handled by the leading |init_disc|. The question is: should
                    we bother about select nodes? Knuth indicates in the original source that only
                    a very few cases need hyphenation so the exceptional case of >2 char ligatures
                    having hyphenation points in between is rare. We'd better have proper compound
                    word handling. Keep in mind that these (old) init and select subtypes always
                    came in isolated pairs and that they only were meant for the simple (enforced)
                    hyphenation discretionaries.

                    Therefore, this feature has been dropped from \LUAMETATEX. It not only makes
                    the code simpler, it also avoids having code on board for border cases that
                    even when dealt with are suboptimal. It's better to have nothing that something
                    fuzzy. It also makes dealing with (intermediate) node lists easier. If I want
                    something like this it should be okay for any situation.

                */
                {
                    halfword replace = disc_no_break_head(current);
                    if (lmt_linebreak_state.force_check_hyphenation || (node_subtype(current) != syllable_discretionary_code)) {
                        halfword actual_penalty = disc_penalty(current) + disc_orphaned(current) + properties->extra_hyphen_penalty;
                        halfword pre = disc_pre_break_head(current);
                        tex_aux_reset_disc_target(properties->adjust_spacing, lmt_linebreak_state.disc_width);
                        if (pre) {
                            /*tex
                                After \OPENTYPE\ processing we can have long snippets in a disc node
                                and as a result we can have trailing disc nodes which also means that
                                we can have a replacement that is shorter than a pre snippet so then
                                we need bypass the pre checking. It also catches the case where we
                                have a pre and replace but no post that then can result in an empty
                                line when we have a final disc.

                                Another more realistic example of required control is when we use
                                discretionaries for optional content, where we actually might want to
                                favour either the replacement or the prepost pair. We're still talking
                                or rare situations (that showed up in test loops that triggered these
                                border cases).
                            */
                            if (replace && node_subtype(current) != mathematics_discretionary_code) {
                                if (tex_has_disc_option(current, disc_option_prefer_break) || tex_has_disc_option(current, disc_option_prefer_nobreak)) {
                                    /*tex
                                        Maybe we need some more (subtype) checking but first I need a
                                        better (less border) use case. In this border case we forget
                                        about expansion.

                                        We likely default to |prefer_nobreak| so by testing |prefer_break|
                                        first we let that one take control.
                                    */
                                    switch (node_type(node_next(current))) {
                                        case glue_node:
                                        case penalty_node:
                                        case boundary_node:
                                            {
                                                /*tex
                                                    Lets assume that when |wd == wp| we actually
                                                    want the pre text (and a possible empty post).
                                                */
                                                scaled wpre = tex_natural_hsize(pre, NULL);
                                                scaled wreplace = tex_natural_hsize(replace, NULL);
                                                if (tex_has_disc_option(current, disc_option_prefer_break)) {
                                                    halfword post = disc_post_break_head(current);
                                                    scaled wpost = post ? tex_natural_hsize(post, NULL) : 0;
                                                    if (wpost > 0) {
                                                        if (properties->tracing_paragraphs > 1) {
                                                            tex_begin_diagnostic();
                                                            tex_print_format("[linebreak: favour final prepost over replace, widths %p %p]", wpre + wpost, wreplace);
                                                            tex_short_display(node_next(temp_head));
                                                            tex_end_diagnostic();
                                                        }
                                                    } else {
                                                        goto REPLACEONLY;
                                                    }
                                                } else {
                                                    if (wreplace < wpre) {
                                                        if (properties->tracing_paragraphs > 1) {
                                                            tex_begin_diagnostic();
                                                            tex_print_format("[linebreak: favour final replace over pre, widths %p %p]", wreplace, wpre);
                                                            tex_short_display(node_next(temp_head));
                                                            tex_end_diagnostic();
                                                        }
                                                        goto REPLACEONLY;
                                                    }
                                                }
                                            }
                                    }
                                }
                            }
                            tex_aux_add_to_widths(pre, properties->adjust_spacing, properties->adjust_spacing_step, lmt_linebreak_state.disc_width);
                            tex_aux_add_disc_source_to_target(properties->adjust_spacing, lmt_linebreak_state.active_width, lmt_linebreak_state.disc_width);
                            tex_aux_try_break(properties, actual_penalty, hyphenated_node, first, current, callback_id, checks, pass, artificial);
                            tex_aux_sub_disc_target_from_source(properties->adjust_spacing, lmt_linebreak_state.active_width, lmt_linebreak_state.disc_width);
                        } else {
                            /*tex trivial pre-break */
                            tex_aux_try_break(properties, actual_penalty, hyphenated_node, first, current, callback_id, checks, pass, artificial);
                        }
                    }
                  REPLACEONLY:
                    if (replace) {
                        tex_aux_add_to_widths(replace, properties->adjust_spacing, properties->adjust_spacing_step, lmt_linebreak_state.active_width);
                    }
                    *state |= par_has_disc;
                    break;
                }
            case penalty_node:
                {
                    halfword penalty = penalty_amount(current);
                    switch (node_subtype(current)) { 
                        /* maybe more */
                        case math_pre_penalty_subtype:
                        case math_post_penalty_subtype:
                            if (properties->math_penalty_factor) {
                                penalty = tex_xn_over_d(penalty, properties->math_penalty_factor, scaling_factor);
                            }
                            break;
                    } 
                    tex_aux_try_break(properties, penalty, unhyphenated_node, first, current, callback_id, checks, pass, artificial);
                    break;
                }
            case math_node:
                {
                    /*tex
                        There used to a ! is_char_node(node_next(cur_p)) test here but I'm
                        not sure whay that is.
                    */
                    switch (node_subtype(current)) {
                        case begin_inline_math:
                            lmt_linebreak_state.saved_threshold = lmt_linebreak_state.threshold;
                            if (pass == linebreak_first_pass) {
                                if (math_pre_tolerance(current)) {
                                    lmt_linebreak_state.threshold = math_pre_tolerance(current);
                                }
                            } else {
                                if (math_tolerance(current)) {
                                    lmt_linebreak_state.threshold = math_tolerance(current);
                                }
                            }
                            if (properties->tracing_paragraphs > 1) {
                                tex_aux_show_threshold("math", lmt_linebreak_state.threshold);
                            }
                            break;
                        case end_inline_math:
                            /*tex 
                                We also store the restore value in the end node but we can 
                                actually change the tolerance mid paragraph so that value might 
                                be wrong, which is why we save the old threshold and use that.
                            */
                            lmt_linebreak_state.threshold = lmt_linebreak_state.saved_threshold;
                            if (properties->tracing_paragraphs > 1) {
                                tex_aux_show_threshold("text", lmt_linebreak_state.threshold);
                            }
                            break;
                    }
                    // lmt_linebreak_state.auto_breaking = finishing;
                    if (tex_math_glue_is_zero(current) || tex_ignore_math_skip(current)) {
                        /*tex
                            When we end up here we assume |\mathsurround| but we only check for
                            a break when we're ending math. Maybe this is something we need to
                            open up. The math specific penalty only kicks in when we break.
                        */
                        switch (node_subtype(current)) {
                            case begin_inline_math:
                                /*tex This one is a lookahead penalty and handled in glue. */
                                break;
                            case end_inline_math:
                                {
                                    halfword penalty = math_penalty(current);
                                    if (node_type(node_next(current)) == glue_node) {
                                        if (properties->math_penalty_factor) {
                                            penalty = tex_xn_over_d(penalty, properties->math_penalty_factor, scaling_factor);
                                        }
                                        tex_aux_try_break(properties, penalty, unhyphenated_node, first, current, callback_id, checks, pass, artificial);
                                    }
                                }
                                break;
                        }
                        lmt_linebreak_state.active_width[total_advance_amount] += math_surround(current);
                    } else {
                        /*tex
                            This one does quite some testing, is that still needed?
                        */
                        switch (node_subtype(current)) {
                            case begin_inline_math:
                                /*tex This one is a lookahead penalty and handled in glue. */
                                break;
                            case end_inline_math:
                                {
                                    halfword penalty = math_penalty(current);
                                    if (tex_aux_valid_glue_break(current)) {
                                        if (properties->math_penalty_factor) {
                                            penalty = tex_xn_over_d(penalty, properties->math_penalty_factor, scaling_factor);
                                        }
                                        tex_aux_try_break(properties, penalty, unhyphenated_node, first, current, callback_id, checks, pass, artificial);
                                    }
                                }
                                break;
                        }
                        lmt_linebreak_state.active_width[total_advance_amount] += math_amount(current);
                        lmt_linebreak_state.active_width[total_stretch_amount + math_stretch_order(current)] += math_stretch(current);
                        lmt_linebreak_state.active_width[total_shrink_amount] += tex_aux_checked_shrink(current);
                        *state |= par_has_glue; /* todo: only when stretch or shrink */
                    }
                    *state |= par_has_math;
                    break;
                }
            case boundary_node:
                if (node_subtype(current) == optional_boundary) {
                    *state |= par_has_optional;
                    if (properties->line_break_optional) {
                        if (! boundary_data(current)) {
                         // printf("END PROCESS OPTIONAL\n");
                            break;
                        } else if ((boundary_data(current) & properties->line_break_optional) == properties->line_break_optional) {
                            /* use this optional */
                         // printf("BEGIN PROCESS OPTIONAL\n");
                            break;
                        }
                    }
                 // printf("BEGIN IGNORE OPTIONAL\n");
                    while (1) {
                        current = node_next(current);
                        if (! current) {
                            /* actually this is an error */
                            return null;
                        } else if (node_type(current) == boundary_node && node_subtype(current) == optional_boundary && ! boundary_data(current)) {
                         // printf("END IGNORE OPTIONAL\n");
                            break;
                        }
                    }
                }
                break;
            case whatsit_node:
            case mark_node:
            case insert_node:
            case adjust_node:
                /*tex Advance past these nodes in the |line_break| loop. */
                break;
            default:
                tex_formatted_error("parbuilder", "weird node %d in paragraph", node_type(current));
        }
        current = node_next(current);
    }
    return current;
}

static void tex_aux_report_fitness_demerits(const line_break_properties *properties, int pass, int subpass)
{
    tex_begin_diagnostic();
    tex_print_format("[linebreak: fitnessdemerits, pass %i, subpass %i]\n", pass, subpass);
    for (halfword c = 1; c <= tex_get_specification_count(properties->fitness_demerits); c++) { 
        tex_print_format("%l  %i : %i %i %i\n", c,
            tex_get_specification_fitness   (properties->fitness_demerits, c),
            tex_get_specification_demerits_u(properties->fitness_demerits, c),
            tex_get_specification_demerits_d(properties->fitness_demerits, c)
        );
    }
    tex_end_diagnostic();
}

static void tex_aux_fix_prev_graf(void)
{
    /*tex Fix a buglet that probably is a feature. */
    if ((cur_list.prev_graf > max_prev_graf || cur_list.prev_graf < 0) && normalize_par_mode_option(limit_prev_graf_mode)) {
        tex_formatted_warning("tex", "clipping prev_graf %i to %i", cur_list.prev_graf, max_prev_graf);
        cur_list.prev_graf = max_prev_graf;
    }
}

/*tex
    We compute the values of |easy_line| and the other local variables relating to line length when
    the |line_break| procedure is initializing itself.
*/

static void tex_aux_set_indentation(const line_break_properties *properties)
{
    if (properties->par_shape) {
        int n = specification_count(properties->par_shape);
        if (n > 0) {
            if (specification_repeat(properties->par_shape)) {
                lmt_linebreak_state.last_special_line = max_halfword;
            } else {
                lmt_linebreak_state.last_special_line = n - 1;
            }
            lmt_linebreak_state.second_indent = tex_get_specification_indent(properties->par_shape, n);
            lmt_linebreak_state.second_width = tex_get_specification_width(properties->par_shape, n);
            lmt_linebreak_state.second_indent = swap_parshape_indent(properties->paragraph_dir, lmt_linebreak_state.second_indent, lmt_linebreak_state.second_width);
        } else {
            lmt_linebreak_state.last_special_line = 0;
            lmt_linebreak_state.second_width = properties->hsize;
            lmt_linebreak_state.second_indent = 0;
        }
    } else if (properties->hang_indent == 0) {
        lmt_linebreak_state.last_special_line = 0;
        lmt_linebreak_state.second_width = properties->hsize;
        lmt_linebreak_state.second_indent = 0;
    } else {
        halfword used_hang_indent = swap_hang_indent(properties->paragraph_dir, properties->hang_indent);
        /*tex

            Set line length parameters in preparation for hanging indentation. We compute the
            values of |easy_line| and the other local variables relating to line length when the
            |line_break| procedure is initializing itself.

        */
        lmt_linebreak_state.last_special_line = abs(properties->hang_after);
        if (properties->hang_after < 0) {
            lmt_linebreak_state.first_width = properties->hsize - abs(used_hang_indent);
            if (used_hang_indent >= 0) {
                lmt_linebreak_state.first_indent = used_hang_indent;
            } else {
                lmt_linebreak_state.first_indent = 0;
            }
            lmt_linebreak_state.second_width = properties->hsize;
            lmt_linebreak_state.second_indent = 0;
        } else {
            lmt_linebreak_state.first_width = properties->hsize;
            lmt_linebreak_state.first_indent = 0;
            lmt_linebreak_state.second_width = properties->hsize - abs(used_hang_indent);
            if (used_hang_indent >= 0) {
                lmt_linebreak_state.second_indent = used_hang_indent;
            } else {
                lmt_linebreak_state.second_indent = 0;
            }
        }
    }
}

/*tex

    Check for special treatment of last line of paragraph. The new algorithm for the last line
    requires that the stretchability |par_fill_skip| is infinite and the stretchability of
    |left_skip| plus |right_skip| is finite.

*/

static void tex_aux_set_last_line_fit(const line_break_properties *properties)
{
    lmt_linebreak_state.do_last_line_fit = 0;
    if (properties->last_line_fit > 0) {
        halfword q = lmt_linebreak_state.last_line_fill;
        if (glue_stretch(q) > 0 && glue_stretch_order(q) > normal_glue_order) {
            if (lmt_linebreak_state.background[total_fi_amount] == 0 && lmt_linebreak_state.background[total_fil_amount] == 0 &&
                lmt_linebreak_state.background[total_fill_amount] == 0 && lmt_linebreak_state.background[total_filll_amount] == 0) {
                lmt_linebreak_state.do_last_line_fit = 1;
                lmt_linebreak_state.fill_width[fi_order] = 0;
                lmt_linebreak_state.fill_width[fil_order] = 0;
                lmt_linebreak_state.fill_width[fill_order] = 0;
                lmt_linebreak_state.fill_width[filll_order] = 0;
                lmt_linebreak_state.fill_width[glue_stretch_order(q) - fi_glue_order] = glue_stretch(q);
            }
        }
    }
}

static void tex_aux_apply_last_line_fit(void)
{
    if (lmt_linebreak_state.do_last_line_fit) {
        /*tex
            Adjust the final line of the paragraph; here we either reset |do_last_line_fit| or
            adjust the |par_fill_skip| glue.
        */
        if (active_short(lmt_linebreak_state.best_bet) == 0) {
            lmt_linebreak_state.do_last_line_fit = 0;
        } else {
            glue_amount(lmt_linebreak_state.last_line_fill) += (active_short(lmt_linebreak_state.best_bet) - active_glue(lmt_linebreak_state.best_bet));
            glue_stretch(lmt_linebreak_state.last_line_fill) = 0;
        }
    }
}

static void tex_aux_set_both_skips(const line_break_properties *properties)
{
    halfword l = properties->left_skip;
    halfword r = properties->right_skip;
    lmt_linebreak_state.background[total_advance_amount] = glue_amount(l) + glue_amount(r);
    lmt_linebreak_state.background[total_stretch_amount] = 0;
    lmt_linebreak_state.background[total_fi_amount] = 0;
    lmt_linebreak_state.background[total_fil_amount] = 0;
    lmt_linebreak_state.background[total_fill_amount] = 0;
    lmt_linebreak_state.background[total_filll_amount] = 0;
    lmt_linebreak_state.background[total_stretch_amount + glue_stretch_order(l)] = glue_stretch(l);
    lmt_linebreak_state.background[total_stretch_amount + glue_stretch_order(r)] += glue_stretch(r);
    lmt_linebreak_state.background[total_shrink_amount] = tex_aux_checked_shrink(l) + tex_aux_checked_shrink(r);
}

static void tex_aux_set_adjust_spacing_state(void)
{
    lmt_linebreak_state.background[font_stretch_amount] = 0;
    lmt_linebreak_state.background[font_shrink_amount] = 0;
    lmt_linebreak_state.current_font_step = -1;
    lmt_packaging_state.previous_char_ptr = null;
}

static void tex_aux_set_extra_stretch(line_break_properties *properties)
{
    halfword el = properties->emergency_left_skip;
    halfword er = properties->emergency_right_skip;
    lmt_linebreak_state.background[total_stretch_amount] += properties->emergency_extra_stretch;
    if (tex_aux_emergency_skip(el)) {
        lmt_linebreak_state.emergency_left_skip = tex_copy_node(properties->left_skip);
        properties->left_skip = lmt_linebreak_state.emergency_left_skip;
        glue_amount(properties->left_skip) += glue_amount(el);
        glue_stretch(properties->left_skip) += glue_stretch(el);
        glue_shrink(properties->left_skip) += glue_shrink(el);
        lmt_linebreak_state.background[total_advance_amount] += glue_amount(el);
        lmt_linebreak_state.background[total_stretch_amount] += glue_stretch(el);
        lmt_linebreak_state.background[total_shrink_amount] += glue_shrink(el);
    }
    if (tex_aux_emergency_skip(er)) {
        lmt_linebreak_state.emergency_right_skip = tex_copy_node(properties->right_skip);
        properties->right_skip = lmt_linebreak_state.emergency_right_skip;
        glue_amount(properties->right_skip) += glue_amount(er);
        glue_stretch(properties->right_skip) += glue_stretch(er);
        glue_shrink(properties->right_skip) += glue_shrink(er);
        lmt_linebreak_state.background[total_advance_amount] += glue_amount(er);
        lmt_linebreak_state.background[total_stretch_amount] += glue_stretch(er);
        lmt_linebreak_state.background[total_shrink_amount] += glue_shrink(er);
    }
}

static int tex_aux_quit_linebreak(const line_break_properties *properties, int pass)
{
    /*tex Find an active node with fewest demerits. */
    if (properties->looseness == 0) {
        return 1;
    } else {
        /*tex

            Find the best active node for the desired looseness. The adjustment for a
            desired looseness is a slightly more complicated version of the loop just
            considered. Note that if a paragraph is broken into segments by displayed
            equations, each segment will be subject to the looseness calculation,
            independently of the other segments.

        */
        halfword r = node_next(active_head); // can be local
        lmt_linebreak_state.actual_looseness = 0;
        do {
            if (node_type(r) != delta_node) {
                lmt_linebreak_state.line_difference = active_line_number(r) - lmt_linebreak_state.best_line;
                if (((lmt_linebreak_state.line_difference < lmt_linebreak_state.actual_looseness) && (properties->looseness <= lmt_linebreak_state.line_difference))
                    || ((lmt_linebreak_state.line_difference > lmt_linebreak_state.actual_looseness) && (properties->looseness >= lmt_linebreak_state.line_difference))) {
                    lmt_linebreak_state.best_bet = r;
                    lmt_linebreak_state.actual_looseness = lmt_linebreak_state.line_difference;
                    lmt_linebreak_state.fewest_demerits = active_total_demerits(r);
                } else if ((lmt_linebreak_state.line_difference == lmt_linebreak_state.actual_looseness) && (active_total_demerits(r) < lmt_linebreak_state.fewest_demerits)) {
                    lmt_linebreak_state.best_bet = r;
                    lmt_linebreak_state.fewest_demerits = active_total_demerits(r);
                }
            }
            r = node_next(r);
        } while (r != active_head);
        lmt_linebreak_state.best_line = active_line_number(lmt_linebreak_state.best_bet);
        /*tex Find the best active node for the desired looseness. */
        if ((lmt_linebreak_state.actual_looseness == properties->looseness) || pass >= linebreak_final_pass) {
            /* maybe trace */
            return 1;
        } else {
            return 0;
        }
    }
}

static void tex_aux_find_best_bet(void)
{
    halfword r = node_next(active_head);
    lmt_linebreak_state.fewest_demerits = awful_bad;
    do {
        if ((node_type(r) != delta_node) && (active_total_demerits(r) < lmt_linebreak_state.fewest_demerits)) {
            lmt_linebreak_state.fewest_demerits = active_total_demerits(r);
            lmt_linebreak_state.best_bet = r;
        }
        r = node_next(r);
    } while (r != active_head);
    lmt_linebreak_state.best_line = active_line_number(lmt_linebreak_state.best_bet);
}

void tex_do_line_break(line_break_properties *properties)
{
 // halfword passes = line_break_passes_par > 0 ? properties->par_passes : 0; /* We could test this earlier. */
    halfword passes = properties->par_passes;
    int subpasses = passes ? tex_get_specification_count(passes) : 0;
    int subpass = -2;
    int pass = linebreak_no_pass; 
    halfword first = node_next(temp_head);
    int state = 0;
    lmt_linebreak_state.passes[properties->par_context].n_of_break_calls++;
    /*tex 
        We do some preparations first. This concern the node list that we are going to break into
        lines. 
    */
    tex_aux_fix_prev_graf();
    /*tex 
        Next we check properties. These mostly come from the initial par node. 
    */
    properties->emergency_original = properties->emergency_stretch;
    /*tex 
        We start with all kind of initializations. By wrapping in a record we don't need to pass 
        them around.
    */
    lmt_linebreak_state.force_check_hyphenation = hyphenation_permitted(properties->hyphenation_mode, force_check_hyphenation_mode);
    lmt_linebreak_state.callback_id = properties->line_break_checks ? lmt_callback_defined(line_break_callback) : 0;
    lmt_linebreak_state.fewest_demerits = 0;
    lmt_linebreak_state.checked_expansion = -1;
    lmt_linebreak_state.no_shrink_error_yet = 1;
    lmt_linebreak_state.minimum_demerits = awful_bad;
    lmt_linebreak_state.extra_background_stretch = 0;
    lmt_linebreak_state.emergency_left_skip = null;
    lmt_linebreak_state.emergency_right_skip = null;
    lmt_linebreak_state.emergency_amount = 0;
    lmt_linebreak_state.emergency_percentage = 0;
    lmt_linebreak_state.emergency_width_amount = 0;
    lmt_linebreak_state.emergency_width_extra = 0;
    lmt_linebreak_state.emergency_left_amount = 0;
    lmt_linebreak_state.emergency_left_extra = 0;
    lmt_linebreak_state.emergency_right_amount = 0;
    lmt_linebreak_state.emergency_right_extra = 0;
    for (int i = default_fit; i <= tex_max_fitness(properties->fitness_demerits); i++) {
        lmt_linebreak_state.minimal_demerits[i] = awful_bad;
    }
    lmt_linebreak_state.line_break_dir = properties->paragraph_dir;
    if (lmt_linebreak_state.dir_ptr) {
        tex_flush_node_list(lmt_linebreak_state.dir_ptr);
        lmt_linebreak_state.dir_ptr = null;
    }
    /*tex 
        This is a bit terrible hack butif we want to inject something it has to be done after we
        are done with the left and right protrusion as we are redetecing in the post line break 
        routine too. 
    */
    if (lmt_linebreak_state.inject_after_par) { 
        /*tex This should not happen. */
        tex_flush_node(lmt_linebreak_state.inject_after_par);
    }
    lmt_linebreak_state.inject_after_par = null;
    /* */
    tex_aux_set_adjust_spacing(properties);
    tex_aux_set_orphan_penalties(properties, 0);
    tex_aux_set_toddler_penalties(properties, 0);
    tex_aux_set_indentation(properties);
    tex_aux_set_looseness(properties);
    tex_aux_set_both_skips(properties);
    tex_aux_set_adjust_spacing_state();
    tex_aux_set_last_line_fit(properties);
    /*tex 
        Here we start doing the real work: find optimal breakpoints. We have an initial pass 
        (pretolerance), when needed a second one (tolerance) and when we're still not done we 
        do a third pass when emergency stretch is set. However, in \LUAMETATEX\ we can also 
        have additional so called par passes replacing that one. 

        first pass  : pretolerance without hyphenation 
        second pass : tolerance with hyphenation 
        final pass  : tolerance with hyphenation and emergencystretch and looseness
    */
    lmt_linebreak_state.threshold = properties->pretolerance;
    if (properties->tracing_paragraphs > 1) {
        tex_begin_diagnostic();
        tex_print_str("[linebreak: original]");
        tex_short_display(first);
        tex_end_diagnostic();
    }
    if (subpasses) {
        pass = linebreak_specification_pass; 
        lmt_linebreak_state.threshold = properties->pretolerance; /* or tolerance */
        if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
            if (specification_presets(passes)) { 
                tex_begin_diagnostic();
                tex_print_str("[linebreak: specification presets]");
                tex_end_diagnostic();
            }
        }
        if (specification_presets(passes)) { 
            subpass = 1;
        }
    } else if (properties->pretolerance >= 0) {
        pass = linebreak_first_pass;    
        lmt_linebreak_state.threshold = properties->pretolerance;
    } else {
        pass = linebreak_second_pass;    
        lmt_linebreak_state.threshold = properties->tolerance;
    }
    lmt_linebreak_state.global_threshold = lmt_linebreak_state.threshold;
    if (lmt_linebreak_state.callback_id) {
        tex_aux_line_break_callback_initialize(lmt_linebreak_state.callback_id, properties->line_break_checks);
    }
    /*tex 
        The main loop starts here. We set |current| to the start if the paragraph and the break 
        routine returns either |null| or some place in the list that needs attention. 
    */
 /* state = tex_aux_analyze_list(first); */
    while (1) {
        halfword current = first; 
        int artificial = 0;
        switch (pass) { 
            case linebreak_no_pass:
                goto DONE;
            case linebreak_first_pass:
                if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
                    tex_begin_diagnostic();
                    tex_print_format("[linebreak: first pass, used tolerance %i]", lmt_linebreak_state.threshold);
                    // tex_end_diagnostic();
                }
                lmt_linebreak_state.passes[properties->par_context].n_of_first_passes++;
                break;
            case linebreak_second_pass:
                if (tex_aux_emergency(properties)) { 
                    lmt_linebreak_state.passes[properties->par_context].n_of_second_passes++;
                    if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
                        tex_begin_diagnostic();
                        tex_print_format("[linebreak: second pass, used tolerance %i]", lmt_linebreak_state.threshold);
                        // tex_end_diagnostic();
                    }
                    lmt_linebreak_state.force_check_hyphenation = 1;
                    break;
                } else { 
                    pass = linebreak_final_pass;
                    /* fall through */
                }
            case linebreak_final_pass:
                lmt_linebreak_state.passes[properties->par_context].n_of_final_passes++;
                if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
                    tex_begin_diagnostic();
                    tex_print_format("[linebreak: final pass, used tolerance %i, used emergency stretch %p]", lmt_linebreak_state.threshold, properties->emergency_stretch);
                    // tex_end_diagnostic();
                }
                lmt_linebreak_state.force_check_hyphenation = 1;
                lmt_linebreak_state.background[total_stretch_amount] += properties->emergency_stretch;
                tex_aux_set_extra_stretch(properties);
                break;
            case linebreak_specification_pass:
                if (specification_presets(passes)) {
                    if (subpass <= passes_first_final(passes)) { 
                        tex_aux_set_sub_pass_parameters(
                            properties, passes, subpass,
                            first,
                            properties->tracing_passes > 1,
                            tex_get_passes_features(passes,subpass), 
                            0, 0, 0, 0, 0, 0, 0 
                        );
                        lmt_linebreak_state.passes[properties->par_context].n_of_specification_passes++;
                    }
                } else {
                    switch (subpass) { 
                        case -2:
                            lmt_linebreak_state.threshold = properties->pretolerance;
                            lmt_linebreak_state.force_check_hyphenation = 0;
                            subpass = -1;
                            break;                     
                        case -1: 
                            lmt_linebreak_state.threshold = properties->tolerance;
                            lmt_linebreak_state.force_check_hyphenation = 1;
                            subpass = 0;
                            break;                     
                        default: 
                            lmt_linebreak_state.force_check_hyphenation = 1;
                            break;
                    }
                }
                if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
                    tex_begin_diagnostic();
                    tex_print_format("[linebreak: specification subpass %i]\n", subpass);
                }
                lmt_linebreak_state.passes[properties->par_context].n_of_sub_passes++;
                break;
        }
        lmt_linebreak_state.saved_threshold = 0;
        if (lmt_linebreak_state.threshold > infinite_bad) {
            lmt_linebreak_state.threshold = infinite_bad; /* we can move this check to where threshold is set */
        }
        lmt_linebreak_state.global_threshold = lmt_linebreak_state.threshold;
        if (properties->tracing_fitness && properties->fitness_demerits) {
            tex_aux_report_fitness_demerits(properties, pass, subpass);
        }
        if (lmt_linebreak_state.callback_id) {
            tex_aux_line_break_callback_start(lmt_linebreak_state.callback_id, properties->line_break_checks, pass,
                tex_max_fitness(properties->fitness_demerits), tex_med_fitness(properties->fitness_demerits));
        }
        /*tex
            Create an active breakpoint representing the beginning of the paragraph. After
            doing this we have created a cycle.
        */
        tex_aux_set_initial_active(properties);
        /*tex
            We now initialize the arrays that will be used in the calculations. We start fresh 
            each pass.
        */

        {
            halfword line = 1;
            scaled line_width;
            if (line > lmt_linebreak_state.easy_line) {
                line_width = lmt_linebreak_state.second_width;
            } else if (line > lmt_linebreak_state.last_special_line) {
                line_width = lmt_linebreak_state.second_width;
            } else if (properties->par_shape) {
                line_width = tex_get_specification_width(properties->par_shape, line);
            } else {
                line_width = lmt_linebreak_state.first_width;
            }
            lmt_linebreak_state.background[total_stretch_amount] -= lmt_linebreak_state.emergency_amount;
            if (lmt_linebreak_state.emergency_percentage) {
                scaled stretch = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_percentage, scaling_factor);
                lmt_linebreak_state.background[total_stretch_amount] += stretch;
                lmt_linebreak_state.emergency_amount = stretch;
            } else { 
                lmt_linebreak_state.emergency_amount = 0;
            }
            lmt_linebreak_state.background[total_advance_amount] -= lmt_linebreak_state.emergency_width_amount;
            if (lmt_linebreak_state.emergency_width_extra) {
                scaled extra = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_width_extra, scaling_factor);
                lmt_linebreak_state.background[total_advance_amount] += extra;
                lmt_linebreak_state.emergency_width_amount = extra;
            } else { 
                lmt_linebreak_state.emergency_width_amount = 0;
            }

            lmt_linebreak_state.background[total_advance_amount] -= lmt_linebreak_state.emergency_left_amount;
            if (lmt_linebreak_state.emergency_left_extra) {
                scaled extra = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_left_extra, scaling_factor);
                lmt_linebreak_state.background[total_advance_amount] += extra;
                lmt_linebreak_state.emergency_left_amount = extra;
            } else { 
                lmt_linebreak_state.emergency_left_amount = 0;
            }
            lmt_linebreak_state.background[total_advance_amount] -= lmt_linebreak_state.emergency_right_amount;
            if (lmt_linebreak_state.emergency_right_extra) {
                scaled extra = tex_xn_over_d(line_width, lmt_linebreak_state.emergency_right_extra, scaling_factor);
                lmt_linebreak_state.background[total_advance_amount] += extra;
                lmt_linebreak_state.emergency_right_amount = extra;
            } else { 
                lmt_linebreak_state.emergency_right_amount = 0;
            }
        }
        tex_aux_set_target_to_source(properties->adjust_spacing, lmt_linebreak_state.active_width, lmt_linebreak_state.background);
        lmt_linebreak_state.passive = null;
        lmt_linebreak_state.printed_node = temp_head;
        lmt_linebreak_state.serial_number = 0;
        lmt_print_state.font_in_short_display = null_font;
        lmt_packaging_state.previous_char_ptr = null;
        /*tex
            We have local boxes and (later) some possible mid paragraph overloads that we need to
            initialize.
        */
        tex_aux_set_local_par_state(current);
        /*tex

            As we move through the hlist, we need to keep the |active_width| array up to date, so 
            that the badness of individual lines is readily calculated by |try_break|. It is 
            convenient to use the short name |active_width [1]| for the component of active width 
            that represents real width as opposed to glue.

        */
        switch (pass) { 
            case linebreak_final_pass:
                artificial = 1;
                break;
            case linebreak_specification_pass:
                artificial = (subpass >= passes_first_final(passes)) || (subpass == subpasses);
                break;
            default:
                artificial = 0;
                break;
        }
        current = tex_aux_break_list(properties, pass, current, first, &state, artificial);
        if (! current) {
            /*tex

                Try the final line break at the end of the paragraph, and |goto done| if the desired
                breakpoints have been found.

                The forced line break at the paragraph's end will reduce the list of breakpoints so
                that all active nodes represent breaks at |cur_p = null|. On the first pass, we
                insist on finding an active node that has the correct \quote {looseness.} On the
                final pass, there will be at least one active node, and we will match the desired
                looseness as well as we can.

                The global variable |best_bet| will be set to the active node for the best way to
                break the paragraph, and a few other variables are used to help determine what is
                best.

            */
            scaled shortfall = tex_aux_try_break(properties, eject_penalty, hyphenated_node, first, current, lmt_linebreak_state.callback_id, properties->line_break_checks, pass, artificial);
            if (node_next(active_head) != active_head) { 
                /*tex Find an active node with fewest demerits. */
                tex_aux_find_best_bet();
                if (pass == linebreak_specification_pass) {
                    /*tex This is where sub passes differ: we do a check. */
                    if (subpass < 0) {
                        goto HERE;
                    } else if (subpass < passes_first_final(passes)) {
                        goto DONE;
                    } else if (subpass < subpasses) {
                        int found = tex_aux_check_sub_pass(properties, state, shortfall, passes, subpass, subpasses, first);
                        if (found > 0) {
                            subpass = found;
                            goto HERE;
                        } else if (found < 0) {
                            goto DONE;
                        }
                    } else {
                        /* continue */
                    }
                }
                if (tex_aux_quit_linebreak(properties, pass)) {
                    goto DONE;
                }
            }
        }
        if (subpass <= passes_first_final(passes)) { 
            ++subpass;
        }
      HERE:     
        if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
            tex_end_diagnostic(); // see above
        }
        /*tex Clean up the memory by removing the break nodes. */
        tex_aux_clean_up_the_memory();
        switch (pass) { 
            case linebreak_no_pass:
                /* just to be sure */
                goto DONE;
            case linebreak_first_pass:
                lmt_linebreak_state.threshold = properties->tolerance;
                lmt_linebreak_state.global_threshold = lmt_linebreak_state.threshold;
                pass = linebreak_second_pass;    
                break;
            case linebreak_second_pass:
                pass = linebreak_final_pass;
                break;
            case linebreak_final_pass:
                pass = linebreak_no_pass;
                break;
            case linebreak_specification_pass:
                break;
        }
        if (lmt_linebreak_state.callback_id) {
            tex_aux_line_break_callback_stop(lmt_linebreak_state.callback_id, properties->line_break_checks);
        }
    }
    goto INDEED;
  DONE:
    if (properties->tracing_paragraphs > 0 || properties->tracing_passes > 0) {
        tex_end_diagnostic(); // see above
    }
  INDEED:
    tex_aux_apply_last_line_fit();
    tex_aux_wipe_optionals(properties, first, state);
    tex_aux_apply_special_penalties(properties, first, state);
    tex_flush_node_list(lmt_linebreak_state.dir_ptr);
    lmt_linebreak_state.dir_ptr = null;
    {
        int callback_id = lmt_callback_defined(linebreak_quality_callback);
        if (callback_id) {
            halfword overfull = 0;
            halfword underfull = 0;
            halfword verdict = 0;
            halfword classified = 0;
            tex_check_linebreak_quality(0, &overfull, &underfull, &verdict, &classified);
            tex_aux_quality_callback(callback_id, first, 
                passes ? passes_identifier(passes) : 0, pass, subpass, subpasses, state,
                overfull, underfull, verdict, classified
            );
        }
    }
    /*tex
        Break the paragraph at the chosen breakpoints. Once the best sequence of breakpoints has been 
        found (hurray), we call on the procedure |post_line_break| to finish the remainder of the 
        work. By introducing this subprocedure, we are able to keep |line_break| from getting 
        extremely long. The first thing |ext_post_line_break| does is reset |dir_ptr|.
        
        Here we still have a temp node as head. 
    */
    tex_aux_post_line_break(properties, lmt_linebreak_state.line_break_dir, lmt_linebreak_state.callback_id, properties->line_break_checks, state);
    /*tex 
        Clean up memory by removing the break nodes (maybe: |tex_flush_node_list(cur_p)|). 
    */
    if (lmt_linebreak_state.emergency_left_skip) { 
        tex_flush_node(lmt_linebreak_state.emergency_left_skip);
     // lmt_linebreak_state.emergency_left_skip = null;
    }
    if (lmt_linebreak_state.emergency_right_skip) {
        tex_flush_node(lmt_linebreak_state.emergency_right_skip);
     // lmt_linebreak_state.emergency_right_skip = null;
    }
    tex_aux_clean_up_the_memory();
    if (lmt_linebreak_state.callback_id) {
        tex_aux_line_break_callback_wrapup(lmt_linebreak_state.callback_id, properties->line_break_checks);
    }
}

void tex_get_linebreak_info(int *f, int *a)
{
    *f = lmt_linebreak_state.fewest_demerits;
    *a = lmt_linebreak_state.actual_looseness;
}

/*tex

    So far we have gotten a little way into the |line_break| routine, having covered its important
    |try_break| subroutine. Now let's consider the rest of the process.

    The main loop of |line_break| traverses the given hlist, starting at |vlink (temp_head)|, and
    calls |try_break| at each legal breakpoint. A variable called |auto_breaking| is set to true
    except within math formulas, since glue nodes are not legal breakpoints when they appear in
    formulas.

    The current node of interest in the hlist is pointed to by |cur_p|. Another variable, |prev_p|,
    is usually one step behind |cur_p|, but the real meaning of |prev_p| is this: If |type (cur_p)
    = glue_node| then |cur_p| is a legal breakpoint if and only if |auto_breaking| is true and
    |prev_p| does not point to a glue node, penalty node, explicit kern node, or math node.

    The total number of lines that will be set by |post_line_break| is |best_line - prev_graf - 1|.
    The last breakpoint is specified by |break_node (best_bet)|, and this passive node points to
    the other breakpoints via the |prev_break| links. The finishing-up phase starts by linking the
    relevant passive nodes in forward order, changing |prev_break| to |next_break|. (The
    |next_break| fields actually reside in the same memory space as the |prev_break| fields did,
    but we give them a new name because of their new significance.) Then the lines are justified,
    one by one.

    The |post_line_break| must also keep an dir stack, so that it can output end direction
    instructions at the ends of lines and begin direction instructions at the beginnings of lines.

*/

/*tex The new name for |prev_break| after links are reversed: */

# define passive_next_break passive_prev_break

/*tex The |int|s are actually |halfword|s or |scaled|s. */

void tex_get_line_content_range(halfword head, halfword tail, halfword *first, halfword *last) 
{ 
    halfword current = head;
    *first = head;
    *last = tail;
    while (current) {
        if (node_type(current) == glue_node) {
            switch (node_subtype(current)) {
                case left_skip_glue:
                case par_fill_left_skip_glue:
                case par_init_left_skip_glue:
                case indent_skip_glue:
                case left_hang_skip_glue:
                    *first = current;
                    current = node_next(current);
                    break;
                default:
                    current = null;
                    break;
            }
        } else {
            current = null;
        }
    }
    current = tail;
    while (current) {
        if (node_type(current) == glue_node) {
            switch (node_subtype(current)) {
                case right_skip_glue:
                case par_fill_right_skip_glue:
                case par_init_right_skip_glue:
                case right_hang_skip_glue:
                    *last = current;
                    current = node_prev(current);
                    break;
                default:
                    current = null;
                    break;
            }
        } else {
            current = null;
        }
    }
}

static void tex_aux_trace_penalty(const char *what, int line, int index, halfword penalty, halfword total)
{
    if (tracing_penalties_par > 0) {
        tex_begin_diagnostic();
        tex_print_format("[linebreak: %s penalty, line %i, index %i, delta %i, total %i]", what, line, index, penalty, total);
        tex_end_diagnostic();
    }
}

static void tex_aux_post_line_break(const line_break_properties *properties, halfword line_break_dir, int callback_id, halfword checks, int state)
{
    /*tex temporary registers for list manipulation */
    halfword q, r;
    halfword ls = null;
    halfword rs = null;
    /*tex was a break at glue? */
    int glue_break;
    /*tex are we in some shape */
    int shaping = 0;
    /*tex was the current break at a discretionary node? */
    int disc_break;
    /*tex and did it have a nonempty post-break part? */
    int post_disc_break;
    /*tex width of line number |cur_line| */
    scaled cur_width;
    /*tex left margin of line number |cur_line| */
    scaled cur_indent;
    /*tex |cur_p| will become the first breakpoint; */
    halfword cur_p = null;
    /*tex the current line number being justified */
    halfword cur_line;
    /*tex this saves calculations: */
    int last_line = 0;
    int first_line = 0;
    int math_nesting = 0;
    int math_attr = null;
    /*tex the current direction: */
    lmt_linebreak_state.dir_ptr = cur_list.direction_stack;
    /*tex
        Reverse the links of the relevant passive nodes, setting |cur_p| to the first breakpoint.
        The job of reversing links in a list is conveniently regarded as the job of taking items
        off one stack and putting them on another. In this case we take them off a stack pointed
        to by |q| and having |prev_break| fields; we put them on a stack pointed to by |cur_p|
        and having |next_break| fields. Node |r| is the passive node being moved from stack to
        stack.
    */
    if (callback_id) {
        tex_aux_line_break_callback_collect(callback_id, checks);
    }
    q = active_break_node(lmt_linebreak_state.best_bet);
    do {
        r = q;
        q = passive_prev_break(q);
        passive_next_break(r) = cur_p;
        cur_p = r;
    } while (q);
    if (callback_id) {
        halfword p = cur_p;
        while (p) {
            tex_aux_line_break_callback_list(p, callback_id, checks);
            p = passive_next_break(p);
        }
    }
    /*tex Temporary: */
    if (properties->tracing_passes > 0) {
        halfword passive = cur_p;
        tex_begin_diagnostic();
        tex_print_str("[linebreak: (class demerits deficiency)");
        while (passive) {
            tex_print_format(" (%i %i %p)", (1 << node_subtype(passive)), passive_demerits(passive), passive_deficiency(passive));
            passive = passive_prev_break(passive);
        }
        tex_print_str("]");
        tex_end_diagnostic();
    }
    /*tex |prevgraf + 1| */
    cur_line = cur_list.prev_graf + 1;
    do {
        /*tex
            Justify the line ending at breakpoint |cur_p|, and append it to the current vertical
            list, together with associated penalties and other insertions.

            The current line to be justified appears in a horizontal list starting at |vlink
            (temp_head)| and ending at |cur_break (cur_p)|. If |cur_break (cur_p)| is a glue node,
            we reset the glue to equal the |right_skip| glue; otherwise we append the |right_skip|
            glue at the right. If |cur_break (cur_p)| is a discretionary node, we modify the list
            so that the discretionary break is compulsory, and we set |disc_break| to |true|. We
            also append the |left_skip| glue at the left of the line, unless it is zero.
        */
        /*tex
            We want to get rid of it.
        */
        halfword cur_disc = null;
        /*tex
            Local left and right boxes come from \OMEGA\ but have been adapted and extended.
        */
        halfword leftbox = null;
        halfword rightbox = null;
        halfword middlebox = null;
        if (lmt_linebreak_state.dir_ptr) {
            /*tex Insert dir nodes at the beginning of the current line. */
            for (halfword q = lmt_linebreak_state.dir_ptr; q; q = node_next(q)) {
                halfword tmp = tex_new_dir(normal_dir_subtype, dir_direction(q));
                halfword nxt = node_next(temp_head);
                tex_attach_attribute_list_copy(tmp, nxt ? nxt : temp_head);
                tex_couple_nodes(temp_head, tmp);
                /*tex |\break\par| */
                tex_try_couple_nodes(tmp, nxt);
            }
            tex_flush_node_list(lmt_linebreak_state.dir_ptr);
            lmt_linebreak_state.dir_ptr = null;
        }
        /*tex
            Modify the end of the line to reflect the nature of the break and to include
            |\rightskip|; also set the proper value of |disc_break|. At the end of the following
            code, |q| will point to the final node on the list about to be justified. In the
            meanwhile |r| will point to the node we will use to insert end-of-line stuff after.
            |q == null| means we use the final position of |r|.
        */
        /*tex begin mathskip code */
        q = temp_head;
        while (q) {
            switch (node_type(q)) {
                case glyph_node:
                    goto DONE;
                case hlist_node:
                    if (node_subtype(q) == indent_list) {
                        break;
                    } else {
                        goto DONE;
                    }
                case glue_node:
                    if (tex_is_par_init_glue(q)) {
                        break;
                    } else {
                        goto DONE;
                    }
                case kern_node:
                    if (node_subtype(q) == explicit_kern_subtype || node_subtype(q) == italic_kern_subtype) {
                        break;
                    } else {
                        goto DONE;
                    }
                case math_node:
                    math_surround(q) = 0;
                    tex_reset_math_glue_to_zero(q);
                    goto DONE;
                default:
                    if (non_discardable(q)) {
                        goto DONE;
                    } else {
                        break;
                    }
            }
            q = node_next(q);
        }
      DONE:
        /*tex end mathskip code */
        r = passive_cur_break(cur_p);
        q = null;
        disc_break = 0;
        post_disc_break = 0;
        glue_break = 0;
        if (r) {
            switch (node_type(r)) {
                case glue_node:
                    tex_copy_glue_values(r, properties->right_skip);
                    node_subtype(r) = right_skip_glue;
                    glue_break = 1;
                    /*tex |q| refers to the last node of the line */
                    q = r;
                    rs = q;
                    r = node_prev(r);
                    /*tex |r| refers to the node after which the dir nodes should be closed */
                    break;
                case disc_node:
                    {
                        halfword prv = node_prev(r);
                        halfword nxt = node_next(r);
                        halfword h = disc_no_break_head(r);
                        if (h) {
                            tex_flush_node_list(h);
                            disc_no_break_head(r) = null;
                            disc_no_break_tail(r) = null;
                        }
                        h = disc_pre_break_head(r);
                        if (h) {
                            halfword t = disc_pre_break_tail(r);
                            tex_set_discpart(r, h, t, glyph_discpart_pre);
                            tex_couple_nodes(prv, h);
                            tex_couple_nodes(t, r);
                            disc_pre_break_head(r) = null;
                            disc_pre_break_tail(r) = null;
                        }
                        h = disc_post_break_head(r);
                        if (h) {
                            halfword t = disc_post_break_tail(r);
                            tex_set_discpart(r, h, t, glyph_discpart_post);
                            tex_couple_nodes(r, h);
                            tex_couple_nodes(t, nxt);
                            disc_post_break_head(r) = null;
                            disc_post_break_tail(r) = null;
                            post_disc_break = 1;
                        }
                        cur_disc = r;
                        disc_break = 1;
                    }
                    break;
                case kern_node:
                    if (node_subtype(r) != right_correction_kern_subtype && node_subtype(r) != left_correction_kern_subtype) {
                        kern_amount(r) = 0;
                    }
                    break;
                case math_node :
                    math_surround(r) = 0;
                    tex_reset_math_glue_to_zero(r);
                    break;
            }
        } else {
            /*tex Again a tail run ... maybe combine. */
         // for (r = temp_head; node_next(r); r = node_next(r));
            r = tex_tail_of_node_list(temp_head);
            /*tex Now we're at the end. */
            if (r == properties->parfill_right_skip) {
                /*tex This should almost always be true... */
                q = r;
                /*tex |q| refers to the last node of the line (and paragraph) */
                r = node_prev(r);
            }
            /*tex |r| refers to the node after which the dir nodes should be closed */
        }
        /*tex Adjust the dir stack based on dir nodes in this line. */
        line_break_dir = tex_sanitize_dir_state(node_next(temp_head), passive_cur_break(cur_p), properties->paragraph_dir);
        /*tex Insert dir nodes at the end of the current line. */
        r = tex_complement_dir_state(r);
        /*tex
            Modify the end of the line to reflect the nature of the break and to include |\rightskip|;
            also set the proper value of |disc_break|; Also put the |\leftskip| glue at the left and
            detach this line.

            The following code begins with |q| at the end of the list to be justified. It ends with
            |q| at the beginning of that list, and with |node_next(temp_head)| pointing to the remainder
            of the paragraph, if any.

            Now [q] refers to the last node on the line and therefore the rightmost breakpoint. The
            only exception is the case of a discretionary break with non-empty |pre_break|, then
            |q| s been changed to the last node of the |pre_break| list. If the par ends with a
            |\break| command, the last line is utterly empty. That is the case of |q == temp_head|.

            This code needs to be cleaned up as we now have protrusion and boxes at the edges to
            deal with. Old hybrid code.
        */
        leftbox = tex_use_local_boxes(passive_left_box(cur_p), local_left_box_code);
        rightbox = tex_use_local_boxes(passive_right_box(cur_p), local_right_box_code);
        middlebox = tex_use_local_boxes(passive_middle_box(cur_p), local_middle_box_code);
        /*tex
            First we append the right box. It is part of the content so inside the skips.
        */
        if (rightbox) {
             halfword nxt = node_next(r);
             tex_couple_nodes(r, rightbox);
             tex_try_couple_nodes(rightbox, nxt);
             r = rightbox;
        }
        if (middlebox) {
             /*tex
                These middle boxes might become more advanced as we can process them by a pass over
                the line so that we retain the spot but then, we also loose that with left and right,
                so why bother. It would also complicate uniqueness.
             */
             halfword nxt = node_next(r);
             tex_couple_nodes(r, middlebox);
             tex_try_couple_nodes(middlebox, nxt);
             r = middlebox;
        }
        if (! q) {
            q = r;
        }
        if (q != temp_head && properties->protrude_chars) {
            if (line_break_dir == dir_righttoleft && properties->protrude_chars == protrude_chars_advanced) {
                halfword p = q;
                halfword l = null;
                /*tex Backtrack over the last zero glues and dirs. */
                while (p) {
                    switch (node_type(p)) {
                        case dir_node:
                            if (node_subtype(p) != cancel_dir_subtype) {
                                goto DONE1;
                            } else {
                                break;
                            }
                        case glue_node:
                            if (glue_amount(p)) {
                                goto DONE3;
                            } else {
                                break;
                            }
                        case glyph_node:
                            goto DONE1;
                        default:
                            goto DONE3;
                    }
                    p = node_prev(p);
                }
              DONE1:
                /*tex When |p| is non zero we have something. */
                while (p) {
                    switch (node_type(p)) {
                        case glyph_node:
                            l = p ;
                            break;
                        case glue_node:
                            if (glue_amount(p)) {
                                l = null;
                            }
                            break;
                        case dir_node:
                            if (dir_direction(p) != dir_righttoleft) {
                                goto DONE3;
                            } else {
                                goto DONE2;
                            }
                        case par_node:
                            goto DONE2;
                        case temp_node:
                            /*tex Go on. */
                            break;
                        default:
                            l = null;
                            break;
                    }
                    p = node_prev(p);
                }
              DONE2:
                /*tex Time for action. */
                if (l && p) {
                    scaled w = tex_char_protrusion(l, right_margin_kern_subtype);
                    halfword k = tex_new_kern_node(-w, right_margin_kern_subtype);
                    tex_attach_attribute_list_copy(k, l);
                    tex_couple_nodes(p, k);
                    tex_couple_nodes(k, l);
// printf("\nHERE 3\n");
                }
            } else {
                scaled w = 0;
                halfword p, ptmp;
                if (disc_break && (node_type(q) == glyph_node || node_type(q) != disc_node)) {
                    /*tex |q| is reset to the last node of |pre_break| */
                    p = q;
                } else {
                    /*tex get |node_next(p) = q| */
                    p = node_prev(q);
                }
                ptmp = p;
                p = tex_aux_find_protchar_right(node_next(temp_head), p);
                w = tex_char_protrusion(p, right_margin_kern_subtype);
                if (w && lmt_packaging_state.last_rightmost_char) {
                    /*tex we have found a marginal kern, append it after |ptmp| */
                    halfword k = tex_new_kern_node(-w, right_margin_kern_subtype);
                    tex_attach_attribute_list_copy(k, p);
                    tex_try_couple_nodes(k, node_next(ptmp));
                    tex_couple_nodes(ptmp, k);
// printf("\nHERE 4\n");
                    if (ptmp == q) {
                        q = node_next(q);
                    }
                }
            }
        }
      DONE3:
        /*tex
            If |q| was not a breakpoint at glue and has been reset to |rightskip| then we append
            |rightskip| after |q| now?
        */
        if (glue_break) {
            /*tex A rightskip has already been added. Maybe check it! */
            rs = q;
        } else {
            /*tex We add one, even when zero. */
            rs = tex_new_glue_node(properties->right_skip ? properties->right_skip : zero_glue, right_skip_glue);
            tex_attach_attribute_list_copy(rs, q); /* or next of it? or q */
            tex_try_couple_nodes(rs, node_next(q));
            tex_couple_nodes(q, rs);
            q = rs;
        }
        /*tex
            More preparations.
        */
        r = node_next(q);
        node_next(q) = null;
        q = node_next(temp_head);
        tex_try_couple_nodes(temp_head, r);
        /*tex
            Now we prepend the left box. It is part of the content so inside the skips.
        */
        if (leftbox) {
             halfword nxt = node_next(q);
             tex_couple_nodes(leftbox, q);
             q = leftbox;
             if (nxt && (cur_line == cur_list.prev_graf + 1) && (node_type(nxt) == hlist_node) && ! box_list(nxt)) {
                 /* what is special about an empty hbox, needs checking */
                 q = node_next(q);
                 tex_try_couple_nodes(leftbox, node_next(nxt));
                 tex_try_couple_nodes(nxt, leftbox);
             }
        }
        /*tex
            At this point |q| is the leftmost node; all discardable nodes have been discarded.
        */
        if (properties->protrude_chars) {
            if (line_break_dir == dir_righttoleft && properties->protrude_chars == protrude_chars_advanced) {
                halfword p = tex_aux_find_protchar_left(q, 0);
                halfword w = tex_char_protrusion(p, left_margin_kern_subtype);
                if (w && lmt_packaging_state.last_leftmost_char) {
                    halfword k = tex_new_kern_node(-w, left_margin_kern_subtype);
                    tex_attach_attribute_list_copy(k, p);
                    tex_couple_nodes(k, q);
                    q = k;
                }
            } else {
                halfword p = tex_aux_find_protchar_left(q, 0);
                halfword w = tex_char_protrusion(p, left_margin_kern_subtype);
                if (w && lmt_packaging_state.last_leftmost_char) {
                    halfword k = tex_new_kern_node(-w, left_margin_kern_subtype);
                    tex_attach_attribute_list_copy(k, p);
if (node_type(q) == par_node) { 
    tex_couple_nodes(k, node_next(q));
    tex_couple_nodes(q, k);
//  printf("\nHERE 1\n");
} else { 
// printf("\nHERE 2\n");
                    tex_couple_nodes(k, q);
                    q = k;
}
                }
            }
        }
        /*tex
            Fix a possible mess up.
        */
        if (node_type(q) == par_node ) { 
            if (! tex_is_start_of_par_node(q)) {
                node_subtype(q) = hmode_par_par_subtype;
            }
            if (lmt_linebreak_state.inject_after_par) { 
                tex_couple_nodes(lmt_linebreak_state.inject_after_par, node_next(q));
                tex_couple_nodes(q, lmt_linebreak_state.inject_after_par);
                lmt_linebreak_state.inject_after_par = null; 
            }
        }
        /*tex
            Put the |\leftskip| glue at the left and detach this line. Call the packaging
            subroutine, setting |just_box| to the justified box. Now|q| points to the hlist that
            represents the current line of the paragraph. We need to compute the appropriate line
            width, pack the line into a box of this size, and shift the box by the appropriate
            amount of indentation. In \LUAMETATEX\ we always add the leftskip.
        */
        ls = tex_new_glue_node(properties->left_skip, left_skip_glue);
        tex_attach_attribute_list_copy(ls, q);
        tex_couple_nodes(ls, q);
        q = ls;
        /*tex
            We have these |par| nodes that, when we have callbacks, kind of polute the list. Let's
            get rid of them now. We could have done this in previous loops but for the sake of
            clearity we do it here. That way we keep the existing code as it is in older engines.
            Okay, I might collapse it eventually. This is code that has been prototyped using \LUA.
        */
        if (cur_line > lmt_linebreak_state.last_special_line) { //  && (! (properties->par_shape && specification_repeat(properties->par_shape)))) {
            cur_width = lmt_linebreak_state.second_width;
            cur_indent = lmt_linebreak_state.second_indent;
        } else if (properties->par_shape) {
            if (specification_count(properties->par_shape)) {
                cur_indent = tex_get_specification_indent(properties->par_shape, cur_line);
                cur_width = tex_get_specification_width(properties->par_shape, cur_line);
                cur_indent = swap_parshape_indent(properties->paragraph_dir, cur_indent, cur_width);
            } else {
                cur_width = lmt_linebreak_state.first_width;
                cur_indent = lmt_linebreak_state.first_indent;
            }
        } else {
            cur_width = lmt_linebreak_state.first_width;
            cur_indent = lmt_linebreak_state.first_indent;
        }
        /*tex
            When we have a left hang, the width is the (hsize-hang) and there is a shift if hang
            applied. The overall linewidth is hsize. When we vbox the result, we get a box with
            width hsize.

            When we have a right hang, the width is the (hsize-hang) and therefore we end up with
            a box that is less that the hsize. When we vbox the result, we get a box with width
            hsize minus the hang, so definitely not consistent with the previous case.

            In both cases we can consider the hang to be at the edge, simply because the whole lot
            gets packaged and then shift gets applied. Although, for practical reasons we could
            decide to put it after the left and before the right skips, which actually opens up
            some options.

            Anyway, after a period of nasty heuristics we can now do a better job because we still
            have the information that we started with.

        */
        first_line = rs && (cur_line == 1) && properties->parinit_left_skip && properties->parinit_right_skip;
        last_line = ls && (cur_line + 1 == lmt_linebreak_state.best_line) && properties->parfill_left_skip && properties->parfill_right_skip;
        if (first_line) {
            halfword n = node_next(properties->parinit_left_skip);
            while (n) {
                if (n == properties->parinit_right_skip) {
                    tex_couple_nodes(node_prev(n), node_next(n));
                    tex_couple_nodes(node_prev(rs), n);
                    tex_couple_nodes(n, rs);
                    break;
                } else {
                    n = node_next(n);
                }
            }
            if (! n && normalize_line_mode_par) {
                /*tex For the moment: */
                tex_normal_warning("tex", "right parinit skip is gone");
            }
        }
        if (last_line) {
            halfword n = node_prev(properties->parfill_right_skip);
            while (n) {
                if (n == properties->parfill_left_skip) {
                    tex_couple_nodes(node_prev(n), node_next(n));
                    tex_couple_nodes(n, node_next(ls));
                    tex_couple_nodes(ls, n);
                    break;
                } else {
                    n = node_prev(n);
                }
            }
            if (! n && normalize_line_mode_par) {
                /*tex For the moment: */
                tex_normal_warning("tex", "left parfill skip is gone");
            }
            if (first_line && node_next(properties->parfill_right_skip) == properties->parinit_right_skip) {
                halfword p = node_prev(properties->parfill_right_skip);
                halfword n = node_next(properties->parinit_right_skip);
                tex_couple_nodes(p, properties->parinit_right_skip);
                tex_couple_nodes(properties->parfill_right_skip, n);
                tex_couple_nodes(properties->parinit_right_skip, properties->parfill_right_skip);
            }
        }
        if (lmt_linebreak_state.emergency_left_amount) {
            if (ls) {
                glue_amount(ls) += lmt_linebreak_state.emergency_left_amount;
            } else { 
                /* error */
            }
        } 
        if (lmt_linebreak_state.emergency_right_amount) {
            if (rs) {
                glue_amount(rs) += lmt_linebreak_state.emergency_right_amount;
            } else { 
                /* error */
            }
        } 
        /*tex Some housekeeping. */
        lmt_packaging_state.post_adjust_tail = post_adjust_head;
        lmt_packaging_state.pre_adjust_tail = pre_adjust_head;
        lmt_packaging_state.post_migrate_tail = post_migrate_head;
        lmt_packaging_state.pre_migrate_tail = pre_migrate_head;
        /*tex A bonus feature. */
        if (normalize_line_mode_option(flatten_discretionaries_mode)) {
            int count = 0;
            q = tex_flatten_discretionaries(q, &count, 0); /* there is no need to nest */
            cur_disc = null;
            if (properties->tracing_paragraphs > 1) {
                tex_begin_diagnostic();
                tex_print_format("[linebreak: flatten, line %i, count %i]", cur_line, count);
                tex_end_diagnostic();
            }
        }
        /*tex Finally we pack the lot. */
        shaping = 0;
        if (normalize_line_mode_option(normalize_line_mode)) {
            halfword head = q;
            halfword tail = rs ? rs : head;
            halfword lefthang = 0;
            halfword righthang = 0;
            // we already have the tail somewhere
            while (node_next(tail)) {
                tail = node_next(tail);
            }
            if (properties->par_shape) {
                int n = specification_count(properties->par_shape);
                if (n > 0) {
                    if (specification_repeat(properties->par_shape)) {
                        n = cur_line;
                    } else {
                        n = cur_line > n ? n : cur_line;
                    }
                    lefthang = tex_get_specification_indent(properties->par_shape, n);
                    righthang = properties->hsize - lefthang - tex_get_specification_width(properties->par_shape, n);
                 // lefthang = swap_parshape_indent(paragraph_dir, lefthang, width); // or so
                }
            } else if (properties->hang_after) {
                if (properties->hang_after > 0 && cur_line > properties->hang_after) {
                    if (properties->hang_indent < 0) {
                        righthang = -properties->hang_indent;
                    }
                    if (properties->hang_indent > 0) {
                        lefthang = properties->hang_indent;
                    }
                } else if (properties->hang_after < 0 && cur_line <= -properties->hang_after) {
                    if (properties->hang_indent < 0) {
                        righthang = -properties->hang_indent;
                    }
                    if (properties->hang_indent > 0) {
                        lefthang = properties->hang_indent;
                    }
                }
            }
            shaping = (lefthang || righthang);
            lmt_linebreak_state.just_box = tex_hpack(head, cur_width, properties->adjust_spacing ? packing_linebreak : packing_exactly, (singleword) properties->paragraph_dir, holding_none_option, box_limit_line);
         // attach_attribute_list_copy(linebreak_state.just_box, properties->initial_par);
            if (node_type(tail) != glue_node || node_subtype(tail) != right_skip_glue) {
                halfword rs = tex_new_glue_node((properties->right_skip ? properties->right_skip : zero_glue), right_skip_glue);
                tex_attach_attribute_list_copy(rs, tail);
                tex_try_couple_nodes(rs, node_next(q));
                tex_couple_nodes(tail, rs);
                tail = rs;
            }
            {
                halfword lh = tex_new_glue_node(zero_glue, left_hang_skip_glue);
                halfword rh = tex_new_glue_node(zero_glue, right_hang_skip_glue);
                glue_amount(lh) = lefthang;
                glue_amount(rh) = righthang;
                tex_attach_attribute_list_copy(lh, head);
                tex_attach_attribute_list_copy(rh, tail);
                tex_try_couple_nodes(lh, head);
                tex_try_couple_nodes(tail, rh);
                head = lh;
                tail = rh;
            }
            /*tex
                This is kind of special. Instead of using |cur_width| also on an overfull box as well
                as shifts, we want \quote {real} dimensions. A disadvantage is that we need to adapt
                analyzers that assume this correction not being there (unpack and repack). So we have
                a flag to control it.
            */
            if (normalize_line_mode_option(clip_width_mode)) {
                if (lmt_packaging_state.last_overshoot) {
                    halfword g = tex_new_glue_node(zero_glue, correction_skip_glue);
                    glue_amount(g) =  -lmt_packaging_state.last_overshoot;
                    tex_attach_attribute_list_copy(g, rs);
                    tex_try_couple_nodes(node_prev(rs), g);
                    tex_try_couple_nodes(g, rs);
                }
                box_width(lmt_linebreak_state.just_box) = properties->hsize;
            }
            if (paragraph_has_math(state) && normalize_line_mode_option(balance_inline_math_mode)) {
                halfword current = head; 
                int begin_needed = 0;
                int end_needed = 0;
                int inmath = 0;
                while (current && current != tail) { 
                    if (node_type(current) == math_node) {
                        switch (node_subtype(current)) { 
                            case begin_inline_math:
                                inmath = 1;
                                math_attr = current;
                                break;
                            case end_inline_math:
                                if (inmath) {
                                    inmath = 0;
                                } else { 
                                    begin_needed = 1; 
                                }
                                math_nesting = 0;
                                break;
                            default: 
                                /* error */
                                break;
                        }
                    }
                    current = node_next(current);
                }
                if (inmath) {
                    end_needed = 1;
                    math_nesting = 1;
                } else if (math_nesting) {
                    if (! last_line) { 
                        begin_needed = 1;
                    }
                    end_needed = 1;
                }
                if (begin_needed || end_needed) { 
                    halfword first = null;
                    halfword last = null; 
                    tex_get_line_content_range(head, tail, &first, &last);
                    if (begin_needed && first) {
                        halfword m = tex_new_node(math_node, begin_broken_math);
                        tex_attach_attribute_list_copy(m, math_attr);
                        tex_try_couple_nodes(m, node_next(first));
                        tex_couple_nodes(first, m);
                    }
                    if (end_needed && last) {
                        halfword m = tex_new_node(math_node, end_broken_math);
                        tex_attach_attribute_list_copy(m, math_attr);
                        tex_try_couple_nodes(node_prev(last), m);
                        tex_couple_nodes(m, last);
                    }
                }
            }
            box_list(lmt_linebreak_state.just_box) = head;
            q = head;
            /*tex So only callback when we normalize. */
            if (leftbox || rightbox || middlebox) {
                halfword linebox = lmt_linebreak_state.just_box;
                lmt_local_box_callback(
                    linebox, leftbox, rightbox, middlebox, cur_line,
                    tex_effective_glue(linebox, properties->left_skip),
                    tex_effective_glue(linebox, properties->right_skip),
                    lefthang, righthang, cur_indent,
                    (first_line && properties->parinit_left_skip) ? tex_effective_glue(linebox, properties->parinit_left_skip) : null,
                    (first_line && properties->parinit_right_skip) ? tex_effective_glue(linebox, properties->parinit_right_skip) : null,
                    (last_line && properties->parfill_left_skip) ? tex_effective_glue(linebox, properties->parfill_left_skip) : null,
                    (last_line && properties->parfill_right_skip) ? tex_effective_glue(linebox, properties->parfill_right_skip) : null,
                    lmt_packaging_state.last_overshoot
                );
            }
        } else {
            /*tex Here we can have a right skip way to the right due to an overshoot! */
            lmt_linebreak_state.just_box = tex_hpack(q, cur_width, properties->adjust_spacing ? packing_linebreak : packing_exactly, (singleword) properties->paragraph_dir, holding_none_option, box_limit_line);
         // attach_attribute_list_copy(linebreak_state.just_box, properties->initial_par);
            box_shift_amount(lmt_linebreak_state.just_box) = cur_indent;
        }
// if (passive_par_node(cur_p)) {
// }
        /*tex Call the packaging subroutine, setting |just_box| to the justified box. */
        if (has_box_package_state(lmt_linebreak_state.just_box, package_u_leader_found) && ! has_box_package_state(lmt_linebreak_state.just_box, package_u_leader_delayed)) {
            tex_flatten_leaders(lmt_linebreak_state.just_box, cur_group, 0, "post linebreak", 1);
        }
        node_subtype(lmt_linebreak_state.just_box) = line_list;
        if (callback_id) {
            tex_aux_line_break_callback_line(callback_id, checks, cur_line);
        }
        /*tex Pending content (callback). */
        if (node_next(contribute_head)) {
            if (! lmt_page_builder_state.output_active) {
                lmt_append_line_filter_callback(pre_box_append_line_context, 0);
            }
        }
        /* Pre-adjust content (no callback). */
        if (pre_adjust_head != lmt_packaging_state.pre_adjust_tail) {
            tex_inject_adjust_list(pre_adjust_head, 1, lmt_linebreak_state.just_box, properties);
        }
        lmt_packaging_state.pre_adjust_tail = null;
        /* Pre-migrate content (callback). */
        if (pre_migrate_head != lmt_packaging_state.pre_migrate_tail) {
            tex_append_list(pre_migrate_head, lmt_packaging_state.pre_migrate_tail);
            if (! lmt_page_builder_state.output_active) {
                lmt_append_line_filter_callback(pre_migrate_append_line_context, 0);
            }
        }
        lmt_packaging_state.pre_migrate_tail = null;
        if (cur_line == 1 && lmt_linebreak_state.best_line == 2 && properties->single_line_penalty) {
        // if (cur_line == 1 && lmt_linebreak_state.best_line == 2 && single_line_penalty_par) {
            halfword r = tex_new_penalty_node(properties->single_line_penalty, single_line_penalty_subtype);
        //  halfword r = tex_new_penalty_node(single_line_penalty_par, single_line_penalty_subtype);
            tex_couple_nodes(cur_list.tail, r);
            cur_list.tail = r;
        }
        /* Line content (callback). */
        tex_append_to_vlist(lmt_linebreak_state.just_box, lua_key_index(post_linebreak), properties);
        if (! lmt_page_builder_state.output_active) {
            /* Here we could use the par specific baselineskip and lineskip. */
            lmt_append_line_filter_callback(box_append_line_context, 0);
        }
        /* Post-migrate content (callback). */
        if (post_migrate_head != lmt_packaging_state.post_migrate_tail) {
            tex_append_list(post_migrate_head, lmt_packaging_state.post_migrate_tail);
            if (! lmt_page_builder_state.output_active) {
                lmt_append_line_filter_callback(post_migrate_append_line_context, 0);
            }
        }
        lmt_packaging_state.post_migrate_tail = null;
        /* Post-adjust content (callback). */
        if (post_adjust_head != lmt_packaging_state.post_adjust_tail) {
            tex_inject_adjust_list(post_adjust_head, 1, null, properties);
        }
        if (lmt_packaging_state.except) { 
            box_exdepth(lmt_linebreak_state.just_box) = lmt_packaging_state.except; 
        }
        lmt_packaging_state.post_adjust_tail = null;
        lmt_packaging_state.except = 0;
        /*tex
            Append the new box to the current vertical list, followed by the list of special nodes
            taken out of the box by the packager. Append a penalty node, if a nonzero penalty is
            appropriate. Penalties between the lines of a paragraph come from club and widow lines,
            from the |inter_line_penalty| parameter, and from lines that end at discretionary breaks.
            Breaking between lines of a two-line paragraph gets both club-line and widow-line
            penalties. The local variable |pen| will be set to the sum of all relevant penalties for
            the current line, except that the final line is never penalized.
        */
        if (cur_line + 1 != lmt_linebreak_state.best_line) {
            /*tex
                When we end up here we have multiple lines so we need to add penalties between them
                according to (several) specifications.
            */
            halfword pen = 0;
            halfword nep = 0;
            halfword spm = properties->shaping_penalties_mode;
            halfword option = 0;
            halfword penclub = 0;
            halfword penwidow = 0;
            halfword nepclub = 0;
            halfword nepwidow = 0;
            int largest = 0;
            if (! spm) {
                shaping = 0;
            }
            if (tracing_penalties_par > 0) {
                tex_begin_diagnostic();
                tex_print_format("[linebreak: penalty, line %i, best line %i, prevgraf %i, mode %x (i=%i c=%i w=%i b=%i)]",
                    cur_line, lmt_linebreak_state.best_line, cur_list.prev_graf, spm,
                    is_shaping_penalties_mode(spm, inter_line_penalty_shaping),
                    is_shaping_penalties_mode(spm, club_penalty_shaping),
                    is_shaping_penalties_mode(spm, widow_penalty_shaping),
                    is_shaping_penalties_mode(spm, broken_penalty_shaping)
                );
                tex_end_diagnostic();
            }
            if (! (shaping && is_shaping_penalties_mode(spm, inter_line_penalty_shaping))) {
                halfword penalty;
                if (passive_interline_penalty(cur_p)) {
                    penalty = passive_interline_penalty(cur_p);
                } else { 
                    halfword specification = properties->inter_line_penalties;
                    if (specification) {
                        r = cur_line;
                        if (r > specification_count(specification)) {
                            r = specification_count(specification);
                        } else if (r < 1) {
                            r = 1;
                        }
                        penalty = tex_get_specification_penalty(specification, r);
                    } else {
                        penalty = properties->inter_line_penalty;
                    }
                }
                if (penalty) {
                    pen += penalty;
                    nep += penalty;
                    tex_aux_trace_penalty("interline", cur_line, r, penalty, pen);
                }
            }
            if (! (shaping && is_shaping_penalties_mode(spm, club_penalty_shaping))) {
                halfword penalty, nepalty;
                halfword specification = properties->club_penalties;
                halfword index = 0;
                if (specification) {
                    index = cur_line - cur_list.prev_graf;
                    if (index > specification_count(specification)) {
                        index = specification_count(specification);
                    } else if (index < 1) {
                        index = 1;
                    }
                    penalty = tex_get_specification_penalty(specification, index);
                    if (specification_double(specification)) { 
                        nepalty = tex_get_specification_nepalty(specification, index);
                        option |= penalty_option_double;
                    } else { 
                        nepalty = penalty;
                    }
                    if (specification_largest(specification)) { 
                        penclub = penalty;
                        nepclub = nepalty;
                        largest |= 1;
                    }
                } else if (cur_line == cur_list.prev_graf + 1) {
                    /*tex prevgraf */
                    penalty = properties->club_penalty;
                    nepalty = penalty;
                } else {
                    penalty = 0;
                    nepalty = 0;
                }
                if (nepalty) {
                    nep += nepalty;
                    tex_aux_trace_penalty("club l", cur_line, index, nepalty, nep);
                    if (nep >= infinite_penalty) {
                        option |= penalty_option_clubbed;
                    }
                    option |= penalty_option_club;
                }
                if (penalty) {
                    pen += penalty;
                    tex_aux_trace_penalty("club r", cur_line, index, penalty, pen);
                    if (pen >= infinite_penalty) {
                        option |= penalty_option_clubbed;
                    }
                    option |= penalty_option_club;
                }
            }
            if (! (shaping && is_shaping_penalties_mode(spm, widow_penalty_shaping))) {
                halfword penalty, nepalty;
                halfword specification = properties->par_context == math_par_context ? properties->display_widow_penalties : properties->widow_penalties;
                int index = 0;
                if (specification) {
                    index = lmt_linebreak_state.best_line - cur_line - 1;
                    if (index > specification_count(specification)) {
                        index = specification_count(specification);
                    } else if (index < 1) {
                        index = 1;
                    }
                    penalty = tex_get_specification_penalty(specification, index);
                    if (specification_double(specification)) { 
                        nepalty = tex_get_specification_nepalty(specification, index);
                        option |= penalty_option_double;
                    } else { 
                        nepalty = penalty;
                    }
                    if (specification_largest(specification)) { 
                        penwidow = penalty;
                        nepwidow = nepalty;
                        largest |= 2;
                    }
                    } else if (cur_line + 2 == lmt_linebreak_state.best_line) {
                    penalty = properties->par_context == math_par_context ? properties->display_widow_penalty : properties->widow_penalty;
                    nepalty = penalty;
                } else {
                    penalty = 0;
                    nepalty = 0;
                }
                if (nepalty) {
                    nep += nepalty;
                    tex_aux_trace_penalty("widow l", cur_line, index, nepalty, nep);
                    if (nep >= infinite_penalty) {
                        option |= penalty_option_widowed;
                    }
                    option |= penalty_option_widow;
                }
                if (penalty) {
                    pen += penalty;
                    tex_aux_trace_penalty("widow r", cur_line, index, penalty, pen);
                    if (pen >= infinite_penalty) {
                        option |= penalty_option_widowed;
                    }
                    option |= penalty_option_widow;
                }
            }
            if (disc_break && ! (shaping && is_shaping_penalties_mode(spm, broken_penalty_shaping))) {
                halfword penalty, nepalty;
                halfword index = 0;
                if (passive_broken_penalty(cur_p)) {
                    penalty = passive_broken_penalty(cur_p);
                    nepalty = penalty; 
                } else { 
                    halfword specification = properties->broken_penalties;
                    if (specification) {
                        index = 1;
                        penalty = tex_get_specification_penalty(specification, index);
                        if (specification_double(specification)) { 
                            nepalty = tex_get_specification_nepalty(specification, index);
                            option |= penalty_option_double;
                        } else { 
                            nepalty = penalty;
                        }
                    } else {  
                        penalty = properties->broken_penalty;
                        nepalty = penalty;
                    }
                }
                if (nepalty) {
                    nep += nepalty;
                    tex_aux_trace_penalty("broken l", cur_line, index, nepalty, nep);
                    option |= penalty_option_broken;
                }
                if (penalty) {
                    pen += penalty;
                    tex_aux_trace_penalty("broken r", cur_line, index, penalty, pen);
                    option |= penalty_option_broken;
                }
            }
            if (shaping && ! pen) {
                pen = properties->shaping_penalty;
                nep = pen;
                if (pen) {
                    tex_aux_trace_penalty("shaping", cur_line, 0, pen, pen);
                    option |= penalty_option_shaping;
                }
            }
            if (pen || nep) {
                /* experiment: both largest flags have to be set */
                if (largest == 3) { 
                    if (penclub > penwidow) { 
                        pen -= penwidow;
                        tex_aux_trace_penalty("discard widow r", cur_line, 0, -penwidow, pen);
                    } else if (penclub < penwidow) {
                        pen -= penclub;
                        tex_aux_trace_penalty("discard club r", cur_line, 0, -penclub, pen);
                    }
                    if (nepclub > nepwidow) { 
                        nep -= nepwidow;
                        tex_aux_trace_penalty("discard window l", cur_line, 0, -nepwidow, nep);
                    } else if (nepclub < nepwidow) {
                        nep -= nepclub;
                        tex_aux_trace_penalty("discard club l", cur_line, 0, -nepclub, nep);
                    }
                }
                /* */
                r = tex_new_penalty_node(pen, linebreak_penalty_subtype);
                penalty_tnuoma(r) = nep;
                tex_add_penalty_option(r, option);
                tex_couple_nodes(cur_list.tail, r);
                cur_list.tail = r;
            }
        }
        /*tex
            Append a penalty node, if a nonzero penalty is appropriate. Justify the line ending at
            breakpoint |cur_p|, and append it to the current vertical list, together with associated
            penalties and other insertions.
        */
        ++cur_line;
        cur_p = passive_next_break(cur_p);
        if (cur_p && ! post_disc_break) {
            /*tex
                Prune unwanted nodes at the beginning of the next line. Glue and penalty and kern
                and math nodes are deleted at the beginning of a line, except in the anomalous case
                that the node to be deleted is actually one of the chosen breakpoints. Otherwise
                the pruning done here is designed to match the lookahead computation in
                |try_break|, where the |break_width| values are computed for non-discretionary
                breakpoints.
            */
            r = temp_head;
            /*tex
                Normally we have a matching math open and math close node but when we cross a line
                the open node is removed, including any glue or penalties following it. This is
                however not that nice for callbacks that rely on symmetry. Of course this only
                counts for one liners, as we can still have only a begin or end node on a line. The
                end_of_math lua helper is made robust against this although there you should be
                aware of the fact that one can end up in the middle of math in callbacks that don't
                work on whole paragraphs, but at least this branch makes sure that some proper
                analysis is possible. (todo: check if math glyphs have the subtype marked done).
            */
            /*tex Suboptimal but not critical. Todo.*/
            while (1) {
                q = node_next(r);
                if (node_type(q) == math_node) {
                    if (node_subtype(q) == begin_inline_math) {
                        /*tex We keep it for tracing. */
                        break;
                    } else {
                        /*tex begin mathskip code */
                        math_surround(q) = 0 ;
                        tex_reset_math_glue_to_zero(q);
                        /*tex end mathskip code */
                    }
                }
                if (q == passive_cur_break(cur_p)) {
                    break;
                } else if (node_type(q) == glyph_node) {
                    break;
                } else if (node_type(q) == glue_node && (node_subtype(q) == par_fill_left_skip_glue || node_subtype(q) == par_init_left_skip_glue)) {
                    /*tex Keep it. Can be tricky after a |\break| with no follow up (loops). */
                    break;
                } else if (node_type(q) == par_node && node_subtype(q) == local_box_par_subtype) {
                    /*tex Weird, in the middle somewhere .. these local penalties do this. */
                    break; /* if not we leak, so maybe this needs more testing */
                } else if (non_discardable(q)) {
                    break;
                } else if (node_type(q) == kern_node && ! (node_subtype(q) == explicit_kern_subtype || node_subtype(q) == italic_kern_subtype)) {
                    break;
                }
                r = q;
            }
            if (r != temp_head) {
                node_next(r) = null;
                tex_flush_node_list(node_next(temp_head));
                tex_try_couple_nodes(temp_head, q);
            }
        }
        if (cur_disc) {
            tex_try_couple_nodes(node_prev(cur_disc),node_next(cur_disc));
            tex_flush_node(cur_disc);
        }
        /* We can clean up the par nodes. */
    } while (cur_p);
    if (cur_line != lmt_linebreak_state.best_line) {
        tex_begin_diagnostic();
        tex_print_format("[linebreak: dubious situation, current line %i is not best line %i]", cur_line, lmt_linebreak_state.best_line);
        tex_end_diagnostic();
        cur_line = lmt_linebreak_state.best_line;
    //  tex_confusion("line breaking 1");
    } else if (node_next(temp_head)) {
        tex_confusion("line breaking 2");
    }
    /*tex |prevgraf| etc */
    cur_list.prev_graf = lmt_linebreak_state.best_line - 1;
    cur_list.direction_stack = lmt_linebreak_state.dir_ptr;
    lmt_linebreak_state.dir_ptr = null;
}

halfword tex_wipe_margin_kerns(halfword head)
{
    /*tex We assume that head is a temp node or at least can be skipped (for now). */
    halfword tail = head;
    while (1) {
        halfword next = node_next(tail);
        if (next) {
            if (node_type(next) == kern_node && (node_subtype(next) == left_margin_kern_subtype || node_subtype(next) == right_margin_kern_subtype)) {
                tex_try_couple_nodes(tail, node_next(next));
                tex_flush_node(next);
            } else {
                tail = next;
            }
        } else {
            return tail;
        }
    }
}
