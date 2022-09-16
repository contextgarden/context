/*
    See license.txt in the root of this project.
*/

# ifndef LMT_BUILDPAGE_H
# define LMT_BUILDPAGE_H

/*tex

    The state of |page_contents| is indicated by two special values.

*/

typedef enum  contribution_codes {
    contribute_nothing,
    contribute_insert,  /*tex An insert node has been contributed, but no boxes. */
    contribute_box,     /*tex A box has been contributed. */
    contribute_rule,    /*tex A rule has been contributed. */
} contribution_codes;

typedef struct page_builder_state_info {
    halfword page_tail;  /*tex The final node on the current page. */
    int      contents;   /*tex What is on the current page so far? */
    scaled   max_depth;  /*tex The maximum box depth on page being built. */
    halfword best_break; /*tex Break here to get the best page known so far. */
    int      least_cost; /*tex The score for this currently best page. */
    scaled   best_size;  /*tex Its |page_goal| so it can go away. */
    scaled   goal; 
    scaled   vsize; 
    scaled   total; 
    scaled   depth; 
    union { 
        scaled page_so_far[6];    /*tex The height and glue of the current page. */
        struct {
            scaled initial; 
            scaled stretch;      
            scaled filstretch;   
            scaled fillstretch;  
            scaled filllstretch; 
            scaled shrink;           
        };
    };
    int      insert_penalties;  /*tex The sum of the penalties for held-over insertions. */
    halfword insert_heights;
    halfword last_glue;         /*tex Used to implement |\lastskip|. */
    halfword last_penalty;      /*tex Used to implement |\lastpenalty|. */
    scaled   last_kern;         /*tex Used to implement |\lastkern|. */
    int      last_extra_used;
    halfword last_boundary;
    int      last_node_type;    /*tex Used to implement |\lastnodetype|. */
    int      last_node_subtype; /*tex Used to implement |\lastnodesubtype|. */
    int      output_active;
    int      dead_cycles;
    int      current_state;
} page_builder_state_info;

extern page_builder_state_info lmt_page_builder_state;

typedef enum page_property_states { 
    page_initial_state,    /* we need an offset and are aligned anyway */
    page_stretch_state,
    page_filstretch_state,
    page_fillstretch_state,
    page_filllstretch_state,
    page_shrink_state,
} page_property_states;

# define page_state_offset(c) (c - page_stretch_code + page_stretch_state)

/*tex

    The data structure definitions here use the fact that the |height| field
    appears in the fourth word of a box node.

*/

extern void tex_initialize_buildpage (void);
extern void tex_initialize_pagestate (void);
extern void tex_build_page           (void);
extern void tex_resume_after_output  (void);
extern void tex_print_page_totals    (void);

/*tex The tail of the contribution list: */

# define contribute_tail lmt_nest_state.nest[0].tail

# define page_goal         lmt_page_builder_state.goal         /*tex The desired height of information on page being built. */
# define page_vsize        lmt_page_builder_state.vsize
# define page_total        lmt_page_builder_state.total        /*tex The height of the current page. */
# define page_depth        lmt_page_builder_state.depth        /*tex The depth of the current page. */

//# define page_stretch      lmt_page_builder_state.page_so_far[page_stretch_state]
//# define page_filstretch   lmt_page_builder_state.page_so_far[page_filstretch_state]
//# define page_fillstretch  lmt_page_builder_state.page_so_far[page_fillstretch_state]
//# define page_filllstretch lmt_page_builder_state.page_so_far[page_filllstretch_state]
//# define page_shrink       lmt_page_builder_state.page_so_far[page_shrink_state]    

# define page_stretch      lmt_page_builder_state.stretch
# define page_filstretch   lmt_page_builder_state.filstretch
# define page_fillstretch  lmt_page_builder_state.fillstretch
# define page_filllstretch lmt_page_builder_state.filllstretch
# define page_shrink       lmt_page_builder_state.shrink    

# endif
