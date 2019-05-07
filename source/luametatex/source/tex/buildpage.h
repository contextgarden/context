/*
    See license.txt in the root of this project.
*/

# ifndef BUILDPAGE_H
# define BUILDPAGE_H

# define inserts_only 1          /*tex |page_contents| when an insert node has been contributed, but no boxes */
# define box_there    2          /*tex |page_contents| when a box or rule has been contributed */

typedef struct page_builder_state_info {
    halfword page_tail;       /*tex the final node on the current page */
    int page_contents;        /*tex what is on the current page so far? */
    scaled page_max_depth;    /*tex maximum box depth on page being built */
    halfword best_page_break; /*tex break here to get the best page known so far */
    int least_page_cost;      /*tex the score for this currently best page */
    scaled best_size;         /*tex its |page_goal| */
    /* */
    scaled page_so_far[8];    /*tex height and glue of the current page */
    halfword last_glue;       /*tex used to implement |\lastskip| */
    int last_penalty;         /*tex used to implement |\lastpenalty| */
    scaled last_kern;         /*tex used to implement |\lastkern| */
    int last_node_type;       /*tex used to implement |\lastnodetype| */
    int insert_penalties;     /*tex sum of the penalties for held-over insertions */
    int output_active;
} page_builder_state_info;

extern page_builder_state_info page_builder_state;

# define page_tail        page_builder_state.page_tail
# define page_contents    page_builder_state.page_contents
# define page_max_depth   page_builder_state.page_max_depth
# define best_page_break  page_builder_state.best_page_break
# define least_page_cost  page_builder_state.least_page_cost
# define best_size        page_builder_state.best_size

# define page_so_far      page_builder_state.page_so_far
# define last_glue        page_builder_state.last_glue
# define last_penalty     page_builder_state.last_penalty
# define last_kern        page_builder_state.last_kern
# define last_node_type   page_builder_state.last_node_type
# define insert_penalties page_builder_state.insert_penalties

# define output_active    page_builder_state.output_active

/*tex

    The data structure definitions here use the fact that the |height| field
    appears in the fourth word of a box node.

*/

# define broken_ptr(A) vlink((A)+2)    /*tex an insertion for this class will break here if anywhere */
# define broken_ins(A) vinfo((A)+2)    /*tex this insertion might break at |broken_ptr| */
# define last_ins_ptr(A) vlink((A)+3)  /*tex the most recent insertion for this |subtype| */
# define best_ins_ptr(A) vinfo((A)+3)  /*tex the optimum most recent insertion */

# define page_goal page_so_far[0]      /*tex desired height of information on page being built */
# define page_total page_so_far[1]     /*tex height of the current page */
# define page_shrink page_so_far[6]    /*tex shrinkability of the current page */
# define page_depth page_so_far[7]     /*tex depth of the current page */

extern void initialize_buildpage(void);
extern void build_page(void);
extern void resume_after_output(void);

extern void print_totals(void);

/*tex The tail of the contribution list: */

# define contrib_tail nest[0].tail_field

#endif
