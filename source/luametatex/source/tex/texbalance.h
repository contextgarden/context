/*
    See license.txt in the root of this project.
*/

# ifndef LMT_BALANCE_H
# define LMT_BALANCE_H

typedef struct balance_state_info {
    halfword     just_box;
    int          no_shrink_error_yet;
    int          threshold;
    halfword     quality;
    int          callback_id;
    scaled       extra_background_stretch;
    scaled       extra_background_shrink;
    halfword     passive;
    halfword     printed_node;
    halfword     serial_number;
    scaled       active_height[n_of_glue_amounts];
    scaled       background[n_of_glue_amounts];
    scaled       break_height[n_of_glue_amounts];
    fitcriterion minimal_demerits;
    halfword     minimum_demerits;
    halfword     easy_page;
    halfword     last_special_page;
    scaled       target_height; 
    scaled       first_height;
    scaled       second_height;
    halfword     first_topskip;
    halfword     second_topskip;
    halfword     first_bottomskip;
    halfword     second_bottomskip;
    halfword     first_options;
    halfword     second_options;
    scaled       emergency_amount;
    halfword     emergency_percentage;
    halfword     emergency_factor;
    scaled       emergency_height_amount;
    halfword     best_bet;
    halfword     fewest_demerits;
    halfword     best_page;
    halfword     actual_looseness;
    halfword     warned;
    int          inserts_found;
    int          total_inserts_found;
    int          total_inserts_checked;
    int          discards_found;
    int          uinserts_found;
    int          n_of_callbacks;
    break_passes passes;
    int          artificial_encountered; 
    int          current_slot_number;   
    halfword     default_fitness_classes;
    int          balancing;
} balance_state_info;

extern balance_state_info lmt_balance_state; /* can be private */

typedef enum balance_quality_states { 
    page_is_overfull  = 0x0200, /*tex We use the same values |par_is_overfull|. */
    page_is_underfull = 0x0400, /*tex We use the same values |par_is_underfull|. */
} balance_quality_states;

typedef enum balance_callback_states {
    balance_callback_nothing    = 0x00,
    balance_callback_try_break  = 0x01,
    balance_callback_skip_zeros = 0x02,
} balance_callback_states;

extern void tex_balance_preset (
    balance_properties *properties
);

extern void tex_balance_reset (
    balance_properties *properties
);

extern void tex_balance (
    balance_properties *properties,
    halfword head
);

extern halfword tex_vbalance (
    halfword n,
    halfword mode,
    halfword trial
);

extern halfword tex_vbalanced (
    halfword n
);

typedef enum balance_insert_options {
    balance_insert_nothing = 0x00,
    balance_insert_descend = 0x01,
} balance_insert_options;

extern halfword tex_vbalanced_insert (
    halfword n,
    halfword i,
    halfword options
);

typedef enum balance_discard_options {
    balance_discard_nothing = 0x00,
    balance_discard_descend = 0x01,
    balance_discard_remove  = 0x02,
} balance_unsert_options;

extern void tex_vbalanced_discard (
    halfword n, 
    halfword options
);

typedef enum balance_deinsert_options {
    balance_deinsert_nothing    = 0x00,
    balance_deinsert_descend    = 0x01,
    balance_deinsert_lineheight = 0x02,
    balance_deinsert_linedepth  = 0x04,
} balance_deinsert_options;

extern void tex_vbalanced_deinsert (
    halfword n,
    halfword options
);

typedef enum balance_reinsert_options {
    balance_reinsert_nothing = 0x00,
    balance_reinsert_descend = 0x01,
} balance_reinsert_options;

extern void tex_vbalanced_reinsert (
    halfword n,
    halfword options
);

// extern halfword tex_get_balance_currentheight (
//     void
// );

# endif
