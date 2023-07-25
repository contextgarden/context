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

typedef enum page_property_states { 
    page_unused_state,
    page_initial_state, 
    page_stretch_state,
    page_fistretch_state,
    page_filstretch_state,
    page_fillstretch_state,
    page_filllstretch_state,
    page_shrink_state,
} page_property_states;

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
    scaled   excess;
    scaled   padding; 
    scaled   last_height;
    scaled   last_depth;
    union { 
        /*tex The upcoming height and glue of the current page. */
        scaled page_so_far[8];
        struct {
            scaled unused; 
            scaled initial;       
            scaled stretch;       
            scaled fistretch;     
            scaled filstretch;    
            scaled fillstretch;   
            scaled filllstretch;  
            scaled shrink;           
        };
    };
    union { 
        /*tex The effective height and glue of the current page. */
        scaled page_last_so_far[8];    
        struct {
            scaled last_unused; 
            scaled last_initial; 
            scaled last_stretch;       
            scaled last_fistretch;     
            scaled last_filstretch;    
            scaled last_fillstretch;   
            scaled last_filllstretch;  
            scaled last_shrink;           
        };
    };
    int      insert_penalties;  /*tex The sum of the penalties for held-over insertions. */
    halfword insert_heights;
    halfword last_glue;         /*tex Used to implement |\lastskip|. */
    halfword last_penalty;      /*tex Used to implement |\lastpenalty|. */
    scaled   last_kern;         /*tex Used to implement |\lastkern|. */
    halfword last_boundary;
    int      last_extra_used;
    int      last_node_type;    /*tex Used to implement |\lastnodetype|. */
    int      last_node_subtype; /*tex Used to implement |\lastnodesubtype|. */
    int      output_active;
    int      dead_cycles;
    int      current_state;
} page_builder_state_info;

extern page_builder_state_info lmt_page_builder_state;

//define page_state_offset(c) (c - page_stretch_code + page_stretch_state)

extern void tex_initialize_buildpage (void);
extern void tex_initialize_pagestate (void);
extern void tex_build_page           (void);
extern void tex_resume_after_output  (void);
extern void tex_additional_page_skip (void);

# define contribute_tail        lmt_nest_state.nest[0].tail        /*tex The tail of the contribution list. */

# define page_goal              lmt_page_builder_state.goal        /*tex The desired height of information on page being built. */
# define page_vsize             lmt_page_builder_state.vsize
# define page_total             lmt_page_builder_state.total       /*tex The height of the current page. */
# define page_depth             lmt_page_builder_state.depth       /*tex The depth of the current page. */
# define page_excess            lmt_page_builder_state.excess
# define page_last_height       lmt_page_builder_state.last_height /*tex The height so far. */
# define page_last_depth        lmt_page_builder_state.last_depth  /*tex The depth so far. */
                                
# define page_stretch           lmt_page_builder_state.stretch
# define page_fistretch         lmt_page_builder_state.fistretch    
# define page_filstretch        lmt_page_builder_state.filstretch
# define page_fillstretch       lmt_page_builder_state.fillstretch
# define page_filllstretch      lmt_page_builder_state.filllstretch
# define page_shrink            lmt_page_builder_state.shrink    

# define page_last_stretch      lmt_page_builder_state.last_stretch
# define page_last_fistretch    lmt_page_builder_state.last_fistretch    
# define page_last_filstretch   lmt_page_builder_state.last_filstretch
# define page_last_fillstretch  lmt_page_builder_state.last_fillstretch
# define page_last_filllstretch lmt_page_builder_state.last_filllstretch
# define page_last_shrink       lmt_page_builder_state.last_shrink    

# endif
