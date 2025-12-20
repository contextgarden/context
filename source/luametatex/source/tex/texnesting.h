/*
    See license.txt in the root of this project.
*/

# ifndef LMT_NESTING_H
# define LMT_NESTING_H

/* 
    Todo: make this record 6*4 smaller, not all are halfwords, although padding might then make us
    end up with the same size. We also end up with plenty of casts elsewhere. 
*/

typedef struct list_state_record {
    int      mode;                 // singleword 
    halfword head;                 
    halfword tail;                 
    int      prev_graf;            
    int      mode_line;            
    halfword prev_depth;           // scaled
    halfword space_factor;         
    halfword direction_stack;      
    int      math_dir;             // singleword 
    int      math_style;           // singleword 
    int      math_main_style;      // singleword 
    int      math_parent_style;    // singleword 
    int      math_scale;           
    halfword math_flatten;         // singleword 
    halfword math_begin;           // singleword 
    halfword math_end;             // singleword 
    halfword math_mode;            // singleword 
    halfword delimiter;            // todo: get rid of these and use the stack 
    halfword incomplete_noad;      // todo: get rid of these and use the stack 
    int      options; 
} list_state_record;

typedef struct nest_state_info {
    list_state_record *nest;
    memory_data        nest_data;
    int                shown_mode; // singleword
    int                math_mode;  // singleword
 // halfword           cur_list;   // todo: set when we push pop (more direct access)
 // halfword           cur_mode;   // todo: set when we push pop (more direct access)
} nest_state_info;

extern nest_state_info lmt_nest_state;

# define cur_list lmt_nest_state.nest[lmt_nest_state.nest_data.ptr] /*tex The \quote {top} semantic state. */
# define cur_mode (abs(cur_list.mode))

extern void        tex_initialize_nest_state (void);
/*     int         tex_room_on_nest_stack    (void); */
extern void        tex_initialize_nesting    (void);
extern void        tex_push_nest             (void);
extern void        tex_pop_nest              (void);
extern void        tex_tail_prepend          (halfword p);
extern void        tex_tail_append           (halfword p);
extern void        tex_tail_append_list      (halfword p);
extern void        tex_tail_append_callback  (halfword p);
extern halfword    tex_tail_fetch_callback   (void);
extern halfword    tex_tail_apply_callback   (halfword p, halfword c);
extern halfword    tex_pop_tail              (void);
extern const char *tex_string_mode           (int m);
extern void        tex_show_activities       (void);
extern int         tex_vmode_nest_index      (void);

/*tex
    When we use a macro instead of a function we need to use an intermediate variable because |_p_|
    can be a function call itself (something |new_*|). The gain is a little performance because this
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

typedef enum mvl_options {
    mvl_ignore_prev_depth = 0x0001,
    mvl_no_prev_depth     = 0x0002,
    mvl_discard_top       = 0x0004, 
    mvl_discard_bottom    = 0x0008, 
} mvl_options;

typedef struct mvl_state_info {
    list_state_record *mvl;
    memory_data        mvl_data;
    halfword           slot;
} mvl_state_info;

extern mvl_state_info  lmt_mvl_state;

extern void     tex_initialize_mvl_state (void);
extern void     tex_start_mvl            (void); /* includes scanning */
extern void     tex_stop_mvl             (void);
extern halfword tex_flush_mvl            (halfword n);
extern int      tex_appended_mvl         (halfword context, halfword boundary);
extern int      tex_current_mvl          (halfword *head, halfword *tail);

# endif
