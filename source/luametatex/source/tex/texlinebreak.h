/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LINEBREAK_H
# define LMT_LINEBREAK_H

// # define max_hlist_stack 1024 /*tex This should be more than enough for sane usage. */


/*tex

    When looking for optimal line breaks, \TEX\ creates a \quote {break node} for each break that
    is {\em feasible}, in the sense that there is a way to end a line at the given place without
    requiring any line to stretch more than a given tolerance. A break node is characterized by
    three things: the position of the break (which is a pointer to a |glue_node|, |math_node|,
    |penalty_node|, or |disc_node|); the ordinal number of the line that will follow this breakpoint;
    and the fitness classification of the line that has just ended, i.e., |tight_fit|, |decent_fit|,
    |loose_fit|, or |very_loose_fit|.

    Todo: 0..0.25 / 0.25-0.50 / 0.50-0.75 / 0.75-1.00

    TeX by Topic gives a good explanation of the way lines are broken.

    veryloose stretch badness >= 100
    loose     stretch badness >= 13
    decent            badness <= 12
    tight     shrink  badness >= 13

    adjacent  delta two lines > 1 : visually incompatible

    if badness of any line > pretolerance : second pass
    if pretolerance < 0                   : first pass is skipped
    if badness of any line > tolerance    : third pass (with emergencystretch)

    in lua(meta)tex: always hypnehenated lists (in regular tex second pass+)

    badness of 800 : stretch ratio 2

    One day I will play with a pluggedin badness calculation but there os some performance impact 
    there as well as danger to overflow (unless we go double or very long integers). 

*/

typedef enum fitness_value {
    very_loose_fit, /*tex lines stretching more than their stretchability */
    loose_fit,      /*tex lines stretching 0.5 to 1.0 of their stretchability */
    semi_loose_fit,
    decent_fit,     /*tex for all other lines */
    semi_tight_fit,
    tight_fit,      /*tex lines shrinking 0.5 to 1.0 of their shrinkability */
    n_of_finess_values
} fitness_value;

/*tex

    Some of the next variables can now be local but I don't want to divert too much from the
    orginal, so for now we keep them in the info variable.

*/

typedef struct linebreak_state_info {
    /*tex the |hlist_node| for the last line of the new paragraph */
    halfword just_box;
    halfword last_line_fill;
    int      no_shrink_error_yet;
    int      second_pass;
    int      final_pass;
    int      threshold;
    halfword adjust_spacing;
    halfword adjust_spacing_step;
    halfword adjust_spacing_shrink;
    halfword adjust_spacing_stretch;
    int      max_stretch_ratio;
    int      max_shrink_ratio;
    halfword current_font_step;
    halfword passive;
    halfword printed_node;
    halfword pass_number;
 /* int      auto_breaking; */ /* is gone */
 /* int      math_level;    */ /* was never used */
    scaled   active_width[10];
    scaled   background[10];
    scaled   break_width[10];
    scaled   disc_width[10];
    scaled   fill_width[4];
    halfword internal_penalty_interline;
    halfword internal_penalty_broken;
    halfword internal_left_box;
    scaled   internal_left_box_width;
    halfword init_internal_left_box;
    scaled   init_internal_left_box_width;
    halfword internal_right_box;
    scaled   internal_right_box_width;
    scaled   internal_middle_box;
    halfword minimal_demerits[n_of_finess_values];
    halfword minimum_demerits;
    halfword easy_line;
    halfword last_special_line;
    scaled   first_width;
    scaled   second_width;
    scaled   first_indent;
    scaled   second_indent;
    halfword best_bet;
    halfword fewest_demerits;
    halfword best_line;
    halfword actual_looseness;
    halfword line_difference;
    int      do_last_line_fit;
    halfword dir_ptr;
    halfword warned;
    halfword calling_back;
} linebreak_state_info;

extern linebreak_state_info lmt_linebreak_state;

void tex_line_break_prepare (
    halfword par, 
    halfword *tail, 
    halfword *parinit_left_skip_glue,
    halfword *parinit_right_skip_glue,
    halfword *parfill_left_skip_glue,
    halfword *parfill_right_skip_glue,
    halfword *final_penalty
);

extern void tex_line_break (
    int d, 
    int line_break_context
);

extern void tex_initialize_active (
    void
);

extern void tex_get_linebreak_info (
    int *f, 
    int *a
);

extern void tex_do_line_break (
    line_break_properties *properties
);


/*tex

    We can have skipable nodes at the margins during character protrusion. Two extra functions are
    defined for usage in |cp_skippable|.

*/

inline static int tex_zero_box_dimensions(halfword a)
{
    return box_width(a) == 0 && box_height(a) == 0 && box_depth(a) == 0;
}

inline static int tex_zero_rule_dimensions(halfword a)
{
    return rule_width(a) == 0 && rule_height(a) == 0 && rule_depth(a) == 0;
}

inline static int tex_empty_disc(halfword a)
{
    return (! disc_pre_break_head(a)) && (! disc_post_break_head(a)) && (! disc_no_break_head(a));
}

inline static int tex_protrusion_skipable(halfword a)
{
    if (a) {
        switch (node_type(a)) {
            case glyph_node:
                return 0;
            case glue_node:
                return tex_glue_is_zero(a);
            case disc_node:
                return tex_empty_disc(a);
            case kern_node:
                return (kern_amount(a) == 0) || (node_subtype(a) == font_kern_subtype);
            case rule_node:
                return tex_zero_rule_dimensions(a);
            case math_node:
                return (math_surround(a) == 0) || tex_math_glue_is_zero(a);
            case hlist_node:
                return (! box_list(a)) && tex_zero_box_dimensions(a);
            case penalty_node:
            case dir_node:
            case par_node:
            case insert_node:
            case mark_node:
            case adjust_node:
            case boundary_node:
            case whatsit_node:
                return 1;
        }
    }
    return 0;
 }

inline static void tex_append_list(halfword head, halfword tail)
{
    tex_couple_nodes(cur_list.tail, node_next(head));
    cur_list.tail = tail;
}

# endif
