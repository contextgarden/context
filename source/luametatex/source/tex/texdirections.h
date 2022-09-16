/*
    See license.txt in the root of this project.
*/

# ifndef LMT_DIRECTIONS_H
# define LMT_DIRECTIONS_H

/*tex

    Originally we had quarterwords but some compiler versions then keep complaining about
    comparisons always being true (something enumeration not being integer or so). Interesting it
    all worked well and suddenly gcc on openbsd complained. So, in the end I decided to just make
    these fields halfwords too. It leaves room for growth ... who knows what is needed some day.

    Actually, as we have only two subtypes now, I have considered:

    \starttyping
    0 = begin l2r   2 = end l2r
    1 = begin r2l   3 = end r2l
    \stoptyping

    in which case a regular direction node becomes smaller (no dir_dir any more). But, it come with
    a change at the \LUA\ end too, so it's a no-go in the end.

    For the moment we keep some geometry values here but these might move to their own file when
    there is more to it.

*/

# include "luametatex.h"

typedef struct dir_state_info {
    halfword text_dir_ptr;
    /* alignment */
    int      padding;
} dir_state_info;

extern dir_state_info lmt_dir_state;

typedef enum direction_codes {
    direction_unknown = 0xFF,
    direction_l2r     = 0,
    direction_r2l     = 1
} direction_codes;

# define direction_def_value   direction_l2r
# define direction_min_value   direction_l2r
# define direction_max_value   direction_r2l

# define geometry_def_value    0
# define geometry_min_value    0
# define geometry_max_value    0xFF

# define orientation_def_value 0
# define orientation_min_value 0
# define orientation_max_value 0x0FFF

# define anchor_def_value      0
# define anchor_min_value      0
# define anchor_max_value      0x0FFF

# define orientationonly(t)   (t & 0x000F)

# define valid_direction(d)   ((d >= direction_min_value)   && (d <= direction_max_value))
# define valid_geometry(g)    ((g >= geometry_min_value)    && (g <= geometry_max_value))
# define valid_orientation(o) ((o >= orientation_min_value) && (o <= orientation_max_value))
# define valid_anchor(a)      ((a >= anchor_min_value)      && (a <= anchor_max_value))

# define checked_direction_value(d)   (valid_direction(d)   ? d : direction_def_value)
# define checked_geometry_value(g)    (valid_geometry(g)    ? g : geometry_def_value)
# define checked_orientation_value(o) (valid_orientation(o) ? o : orientation_def_value)
# define checked_anchor_value(a)      (valid_anchor(a)      ? a : anchor_def_value)

# define check_direction_value(d) \
    if (! valid_direction(d)) { \
        d = direction_def_value; \
    }

/* will become texgeometry.h|c and dir also in geometry */

inline static void tex_check_box_geometry(halfword n)
{
    if (box_x_offset(n) || box_y_offset(n)) {
        tex_set_box_geometry(n, offset_geometry);
    } else {
        tex_unset_box_geometry(n, offset_geometry);
    }
    if (box_w_offset(n) || box_h_offset(n) || box_d_offset(n) || box_orientation(n)) {
        tex_set_box_geometry(n, orientation_geometry);
    } else {
        tex_unset_box_geometry(n, orientation_geometry);
    }
    if (box_anchor(n) || box_source_anchor(n) || box_target_anchor(n)) {
        tex_set_box_geometry(n, anchor_geometry);
    } else {
        tex_unset_box_geometry(n, anchor_geometry);
    }
}

inline static void tex_set_box_direction(halfword b, halfword v)
{
    box_dir(b) = (singleword) checked_direction_value(v);
}

extern void     tex_initialize_directions (void);
extern void     tex_cleanup_directions    (void);
extern halfword tex_new_dir               (quarterword subtype, halfword direction);
extern void     tex_push_text_dir_ptr     (halfword val);
extern void     tex_pop_text_dir_ptr      (void);
extern void     tex_set_text_dir          (halfword d);
extern void     tex_set_math_dir          (halfword d);
extern void     tex_set_line_dir          (halfword d);
extern void     tex_set_par_dir           (halfword d);
extern void     tex_set_box_dir           (halfword b, singleword d);

# define swap_hang_indent(dir,indentation)           (dir == dir_righttoleft && normalize_line_mode_permitted(normalize_line_mode_par, swap_hangindent_mode) ? (                  - indentation) : indentation)
# define swap_parshape_indent(dir,indentation,width) (dir == dir_righttoleft && normalize_line_mode_permitted(normalize_line_mode_par, swap_parshape_mode)   ? (hsize_par - width - indentation) : indentation)

extern halfword tex_update_dir_state     (halfword p, halfword initial);
extern halfword tex_sanitize_dir_state   (halfword first, halfword last, halfword initial);
extern halfword tex_complement_dir_state (halfword tail);

# endif
