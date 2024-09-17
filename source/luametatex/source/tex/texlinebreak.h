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

// typedef enum fitness_value {
//     very_loose_fit,       /*tex lines stretching more than their stretchability */
//     loose_fit,
//     almost_loose_fit,     /*tex lines stretching 0.5 to 1.0 of their stretchability */
//     barely_loose_fit,
//     decent_fit,           /*tex for all other lines */
//     barely_tight_fit,
//     almost_tight_fit,     /*tex lines shrinking 0.5 to 1.0 of their shrinkability */
//     tight_fit,
//     very_tight_fit,
//     n_of_finess_values,   /* also padding */
// } fitness_value;

/*tex

    Some of the next variables can now be local but I don't want to divert too much from the
    orginal, so for now we keep them in the info variable.

*/

typedef halfword fitcriterion[n_of_fitness_values] ;

typedef struct break_passes { 
    int n_of_break_calls;
    int n_of_first_passes;
    int n_of_second_passes;
    int n_of_final_passes;
    int n_of_specification_passes;
    int n_of_sub_passes;
    int n_of_left_twins; 
    int n_of_right_twins; 
} break_passes;

typedef struct linebreak_state_info {
    /*tex the |hlist_node| for the last line of the new paragraph */
    halfword     just_box;
    halfword     last_line_fill;
    int          no_shrink_error_yet;
    int          threshold;
    halfword     quality;
    int          callback_id; 
    int          obey_hyphenation;
    int          force_check_hyphenation;
    halfword     adjust_spacing;
    halfword     adjust_spacing_step;
    halfword     adjust_spacing_shrink;
    halfword     adjust_spacing_stretch;
    halfword     current_font_step;
    scaled       extra_background_stretch;
    halfword     passive;
    halfword     printed_node;
    halfword     serial_number;
    scaled       active_width[n_of_glue_amounts];
    scaled       background[n_of_glue_amounts];
    scaled       break_width[n_of_glue_amounts];
    scaled       disc_width[n_of_glue_amounts];
    scaled       fill_width[4];
    halfword     internal_interline_penalty;
    halfword     internal_broken_penalty;
    halfword     internal_left_box;
    scaled       internal_left_box_width;
    halfword     internal_left_box_init;       /* hm: |_init| */
    scaled       internal_left_box_width_init; /* hm: |_init| */
    halfword     internal_right_box;
    scaled       internal_right_box_width;
    scaled       internal_middle_box;
    fitcriterion minimal_demerits;
    halfword     minimum_demerits;
    halfword     easy_line;
    halfword     last_special_line;
    scaled       first_width;
    scaled       second_width;
    scaled       first_indent;
    scaled       second_indent;
    scaled       emergency_amount;
    halfword     emergency_percentage;
    scaled       emergency_width_amount;
    halfword     emergency_width_extra;
    scaled       emergency_left_amount;
    halfword     emergency_left_extra;
    scaled       emergency_right_amount;
    halfword     emergency_right_extra;
    halfword     best_bet;
    halfword     fewest_demerits;
    halfword     best_line;
    halfword     actual_looseness;
    halfword     line_difference;
    int          do_last_line_fit;
    halfword     dir_ptr;
    halfword     warned;
    halfword     calling_back;
    int          saved_threshold;   /*tex Saves the value outside inline math. */
    int          global_threshold;  /*tex Saves the value outside local par states. */
    int          checked_expansion; 
    int          line_break_dir;
    break_passes passes[n_of_par_context_codes];
    int          n_of_left_twins;
    int          n_of_right_twins;
    int          n_of_double_twins;
    halfword     internal_par_node;
    halfword     emergency_left_skip;
    halfword     emergency_right_skip;
    int          artificial_encountered; 
    halfword     inject_after_par;
} linebreak_state_info;

extern linebreak_state_info lmt_linebreak_state;

typedef enum linebreak_quality_states { 
    par_has_glyph    = 0x0001, 
    par_has_disc     = 0x0002, 
    par_has_math     = 0x0004,
    par_has_space    = 0x0008,
    par_has_glue     = 0x0010,
    par_has_uleader  = 0x0020,
    par_has_optional = 0x0100,
    par_is_overfull  = 0x0200,
    par_is_underfull = 0x0400,
} linebreak_quality_states;

# define paragraph_has_text(state)     ((state & par_has_glyph) || (state & par_has_disc))
# define paragraph_has_math(state)     (state & par_has_math)
# define paragraph_has_glue(state)     (state & par_has_glue)
# define paragraph_has_optional(state) (state & par_has_optional)

extern void tex_line_break_prepare (
    halfword par, 
    halfword *tail, 
    halfword *parinit_left_skip_glue,
    halfword *parinit_right_skip_glue,
    halfword *parfill_left_skip_glue,
    halfword *parfill_right_skip_glue,
    halfword *final_line_penalty
);

extern void tex_check_fitness_demerits(
    halfword fitnessdemerits
);

extern halfword tex_default_fitness_demerits(
    void
);

extern void tex_line_break (
    int group_context,
    int par_context,
    int display_math 
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

extern halfword tex_wipe_margin_kerns(
    halfword head
);

/*tex

    We can have skipable nodes at the margins during character protrusion. Two extra functions are
    defined for usage in |cp_skippable|.

*/

static inline int tex_zero_box_dimensions(halfword a)
{
    return box_width(a) == 0 && box_height(a) == 0 && box_depth(a) == 0;
}

static inline int tex_zero_rule_dimensions(halfword a)
{
    return rule_width(a) == 0 && rule_height(a) == 0 && rule_depth(a) == 0;
}

static inline int tex_empty_disc(halfword a)
{
    return (! disc_pre_break_head(a)) && (! disc_post_break_head(a)) && (! disc_no_break_head(a));
}

static inline int tex_protrusion_skipable(halfword a)
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

static inline void tex_append_list(halfword head, halfword tail)
{
    tex_couple_nodes(cur_list.tail, node_next(head));
    cur_list.tail = tail;
}

extern void tex_get_line_content_range(
    halfword  head, 
    halfword  tail, 
    halfword *first, 
    halfword *last
); 
# endif
