/*
    See license.txt in the root of this project.
*/

# ifndef NESTING_H
# define NESTING_H

# define vmode 1                         /*tex vertical mode */
# define hmode (vmode+max_command_cmd+1) /*tex horizontal mode */
# define mmode (hmode+max_command_cmd+1) /*tex math mode */

# define ignore_depth -65536000 /*tex magic dimension value to mean \quote {ignore me} */

typedef struct list_state_record_ {
    int mode_field;
    halfword head_field;
    halfword tail_field;
    halfword eTeX_aux_field;
    int pg_field;
    int ml_field;
    halfword prev_depth_field;
    halfword space_factor_field;
    halfword incompleat_noad_field;
    halfword dirs_field;
    int math_field;
    int math_style_field;
} list_state_record;

typedef struct nest_state_info {
    list_state_record *nest;
    int nest_ptr;
    int max_nest_stack;
    int shown_mode;
} nest_state_info;

extern nest_state_info nest_state;

# define nest           nest_state.nest
# define nest_ptr       nest_state.nest_ptr
# define max_nest_stack nest_state.max_nest_stack
# define shown_mode     nest_state.shown_mode

# define cur_list nest[nest_ptr] /*tex the \quote {top} semantic state */

extern void push_nest(void);
extern void pop_nest(void);
extern void initialize_nesting(void);

extern void tail_append(halfword p);
extern halfword pop_tail(void);

extern void print_mode(int m);
extern void show_activities(void);

# endif
