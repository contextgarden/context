/*
    See license.txt in the root of this project.
*/

# ifndef LINEBREAK_H
# define LINEBREAK_H

# define max_hlist_stack 512

typedef struct linebreak_state_info {
    halfword just_box; /*tex the |hlist_node| for the last line of the new paragraph */
    halfword last_line_fill;
    int no_shrink_error_yet;
    int second_pass;
    int final_pass;
    int threshold;
    halfword hlist_stack[max_hlist_stack];
    short hlist_stack_level;
    int max_stretch_ratio;
    int max_shrink_ratio;
    int cur_font_step;
    halfword passive;
    halfword printed_node;
    halfword pass_number;
    scaled active_width[10];  // = { 0 };
    scaled background[10];    // = { 0 };
    scaled break_width[10];   // = { 0 };
    int auto_breaking;
    int internal_pen_inter;
    int internal_pen_broken;
    halfword internal_left_box;
    int internal_left_box_width;
    halfword init_internal_left_box;
    int init_internal_left_box_width;
    halfword internal_right_box;
    int internal_right_box_width;
    scaled disc_width[10]; // = { 0 };
    int minimal_demerits[4];
    int minimum_demerits;
    halfword best_place[4];
    halfword best_pl_line[4];
    halfword easy_line;
    halfword last_special_line;
    scaled first_width;
    scaled second_width;
    scaled first_indent;
    scaled second_indent;
    halfword best_bet;
    int fewest_demerits;
    halfword best_line;
    int actual_looseness;
    int line_diff;
    int do_last_line_fit;
    scaled fill_width[4];
    scaled best_pl_short[4];
    scaled best_pl_glue[4];
} linebreak_state_info;

extern linebreak_state_info linebreak_state;

# define just_box linebreak_state.just_box

extern void line_break(int d, int line_break_context);

# define inf_bad         10000 /*tex infinitely bad value */
# define awful_bad 07777777777 /*tex more than a billion demerits */

extern void initialize_active(void);

extern void ext_do_line_break(
    int paragraph_dir,
    int pretolerance,
    int tracing_paragraphs,
    int tolerance,
    scaled emergency_stretch,
    int looseness,
    int adjust_spacing,
    halfword par_shape_ptr,
    int adj_demerits,
    int protrude_chars,
    int used_line_penalty,
    int last_line_fit,
    int double_hyphen_demerits,
    int final_hyphen_demerits,
    int hang_indent,
    int hsize,
    int hang_after,
    halfword left_skip,
    halfword right_skip,
    halfword inter_line_penalties_ptr,
    int inter_line_penalty,
    int club_penalty,
    halfword club_penalties_ptr,
    halfword widow_penalties_ptr,
    int widow_penalty,
    int broken_penalty,
    halfword final_par_glue
);

extern void get_linebreak_info(int *, int *);
extern halfword find_protchar_left(halfword l, int d);
extern halfword find_protchar_right(halfword l, halfword r);

/*tex

    We can have skipable nodes at the margins during character protrusion. Two
    extra macros are defined for usage in |cp_skippable|.

*/

# define zero_dimensions(a) ( \
    (width((a)) == 0) && \
    (height((a)) == 0) && \
    (depth((a)) == 0) \
)

# define empty_disc(a) ( \
    (vlink_pre_break(a) == null) && \
    (vlink_post_break(a) == null) && \
    (vlink_no_break(a) == null) \
)

# define cp_skipable(a) ( (! is_char_node((a))) && ( \
    ((type((a)) == glue_node) && (glue_is_zero((a)))) \
 ||  (type((a)) == penalty_node) \
 || ((type((a)) == disc_node) && empty_disc(a)) \
 || ((type((a)) == kern_node) && ((width((a)) == 0) || (subtype((a)) == normal))) \
 || ((type((a)) == rule_node) && zero_dimensions(a)) \
 || ((type((a)) == math_node) && (surround((a)) == 0 || (glue_is_zero((a))))) \
 ||  (type((a)) == dir_node) \
 || ((type((a)) == hlist_node) && (list_ptr((a)) == null) && zero_dimensions(a)) \
 ||  (type((a)) == local_par_node) \
 ||  (type((a)) == ins_node) \
 ||  (type((a)) == mark_node) \
 ||  (type((a)) == adjust_node) \
 ||  (type((a)) == boundary_node) \
 ||  (type((a)) == whatsit_node) \
) )

# endif
