/*
    See license.txt in the root of this project.
*/

# ifndef LMT_NESTING_H
# define LMT_NESTING_H

typedef struct list_state_record {
    int      mode;
    halfword head;
    halfword tail;
    int      prev_graf;
    int      mode_line;
    halfword prev_depth; // scaled
    halfword space_factor;
    halfword direction_stack;
    int      math_dir;
    int      math_style;
    int      math_scale;
    int      math_main_style;
    halfword delim;
    halfword incomplete_noad;
    halfword math_flatten;
    halfword math_begin;
    halfword math_end;
    halfword math_mode;
} list_state_record;

typedef struct nest_state_info {
    list_state_record *nest;
    memory_data        nest_data;
    int                shown_mode;
    int                padding;
} nest_state_info;

extern nest_state_info lmt_nest_state;

# define cur_list lmt_nest_state.nest[lmt_nest_state.nest_data.ptr] /*tex The \quote {top} semantic state. */
# define cur_mode (abs(cur_list.mode))

extern void        tex_initialize_nest_state (void);
/*     int         tex_room_on_nest_stack    (void); */
extern void        tex_initialize_nesting    (void);
extern void        tex_push_nest             (void);
extern void        tex_pop_nest              (void);
extern void        tex_tail_append           (halfword p);
extern halfword    tex_pop_tail              (void);
extern const char *tex_string_mode           (int m);
extern void        tex_show_activities       (void);
extern int         tex_vmode_nest_index      (void);

/*tex
    When we use a macro instead of a function we need to use an intermediate variable because |_p_|
    can be a functioncall itself (something |new_*|). The gain is a little performance because this
    one is called a lot. The loss is a bit larger binary. There are some more macros sensitive for
    this, like the ones that couple nodes. Also, inlining a function can spoil this game!
*/

/*
# define tail_append(_p_) do { \
    halfword __p__ = _p_ ; \
    tex_couple_nodes(cur_list.tail, __p__); \
    cur_list.tail = __p__; \
} while (0)
*/

/*
# define tail_append tex_tail_append
*/

# endif
