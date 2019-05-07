/*
    See license.txt in the root of this project.
*/

# ifndef POSTLINEBREAK_H
# define POSTLINEBREAK_H

# define append_list(A,B) do { \
    vlink(cur_list.tail_field) = vlink((A)); \
    cur_list.tail_field = (B); \
} while (0)

void ext_post_line_break(
    int paragraph_dir,
    int right_skip,
    int left_skip,
    int protrude_chars,
    halfword par_shape_ptr,
    int adjust_spacing,
    halfword inter_line_penalties_ptr,
    int inter_line_penalty,
    int club_penalty,
    halfword club_penalties_ptr,
    halfword widow_penalties_ptr,
    int widow_penalty,
    int broken_penalty,
    halfword final_par_glue,
    halfword best_bet,
    halfword last_special_line,
    scaled second_width,
    scaled second_indent,
    scaled first_width,
    scaled first_indent,
    halfword best_line
);

# endif
