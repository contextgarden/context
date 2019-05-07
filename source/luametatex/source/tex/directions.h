/*
    See license.txt in the root of this project.
*/

# ifndef DIRECTIONS_H
# define DIRECTIONS_H

# define direction_def_value 0
# define direction_min_value 0
# define direction_max_value 1

# define direction_unknown   0xFFFF

# define orientation_def_value 0
# define orientation_min_value 0
# define orientation_max_value 0xFFF

# define orientationonly(t) (t&0xF)
# define boxhasoffset(t)    (t&0x1000)
# define setboxoffset(t)    t=t|0x1000;

# define valid_direction(d)   ((d >= direction_min_value) && (d <= direction_max_value))
# define valid_orientation(t) ((t >= orientation_min_value) && (t <= orientation_max_value))

# define checked_direction_value(d)   (valid_direction(d) ? d : direction_def_value)
# define checked_orientation_value(t) (valid_orientation(t) ? t : orientation_def_value)

# define check_direction_value(d) \
    if (! valid_direction(d)) \
        d = direction_def_value;

# define check_orientation_value(t) \
    if (! valid_orientation(t)) \
        t = orientation_def_value;

#define check_box_offsets(n) \
    if (box_x_offset(n) != 0 || box_y_offset(n) != 0) { \
        box_orientation(n) = (quarterword) (box_orientation(n) | 0x1000); \
    } else { \
        box_orientation(n) = (quarterword) (box_orientation(n) & 0x0FFF); \
    }

# define push_dir(p,a) { \
    halfword dir_tmp = new_dir(normal_dir,(a)); \
    vlink(dir_tmp) = p; \
    p = dir_tmp; \
}

# define push_dir_node(p,a) { \
    halfword dir_tmp = copy_node((a)); \
    vlink(dir_tmp) = p; \
    p = dir_tmp; \
}

# define pop_dir_node(p) { \
    halfword dir_tmp = p; \
    p = vlink(dir_tmp); \
    flush_node(dir_tmp); \
}

typedef struct dir_state_info {
    halfword dir_ptr;
    halfword text_dir_ptr;
} dir_state_info;

extern dir_state_info dir_state;

# define dir_ptr      dir_state.dir_ptr
# define text_dir_ptr dir_state.text_dir_ptr

extern void initialize_directions(void);
extern halfword new_dir(int subtype, int direction);

/* extern void scan_direction(void); */

extern halfword do_push_dir_node(halfword p, halfword a);
extern halfword do_pop_dir_node(halfword p);

extern void update_text_dir_ptr(int val);

extern void set_text_dir(int d);
extern void set_math_dir(int d);
extern void set_line_dir(int d);
extern void set_par_dir(int d);
extern void set_box_dir(int b, int d);

# endif
