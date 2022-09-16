/*
    See license.txt in the root of this project.
*/

# ifndef LMT_INSERTS_H
# define LMT_INSERTS_H

typedef struct insert_record {
    halfword limit;
    halfword multiplier;
    halfword distance;
    halfword content;
    halfword initialized;
    halfword options;
    halfword penalty;
    halfword maxdepth;
} insert_record;

typedef enum insert_modes {
    unset_insert_mode,
    index_insert_mode,
    class_insert_mode,
} insert_modes;

typedef enum insert_class_options {
    insert_option_storing  = 0x1,
    insert_option_penalty  = 0x2,
    insert_option_maxdepth = 0x4,
} insert_class_options;

typedef enum insert_storage_actions {
    insert_storage_ignore,
    insert_storage_delay,
    insert_storage_inject,
} insert_storage_actions;

typedef enum saved_insert_items {
    saved_insert_item_index = 0,
    saved_insert_n_of_items = 1,
} saved_insert_items;

typedef struct insert_state_info {
    insert_record *inserts;
    memory_data    insert_data;
    int            mode;
    halfword       storing;
    halfword       head;
    halfword       tail;
} insert_state_info;

extern insert_state_info lmt_insert_state;

# define has_insert_option(a,b)   (lmt_insert_state.mode == class_insert_mode && (lmt_insert_state.inserts[a].options & b) == b)
# define set_insert_option(a,b)   (lmt_insert_state.inserts[a].options |= b)
# define unset_insert_option(a,b) (lmt_insert_state.inserts[a].options & ~(b))

extern scaled   tex_get_insert_limit      (halfword i);
extern halfword tex_get_insert_multiplier (halfword i);
extern halfword tex_get_insert_penalty    (halfword i);
extern halfword tex_get_insert_distance   (halfword i);
extern halfword tex_get_insert_maxdepth   (halfword i);
extern scaled   tex_get_insert_height     (halfword i);
extern scaled   tex_get_insert_depth      (halfword i);
extern scaled   tex_get_insert_width      (halfword i);
extern halfword tex_get_insert_content    (halfword i);
extern halfword tex_get_insert_storage    (halfword i);

extern void     tex_set_insert_limit      (halfword i, scaled v);
extern void     tex_set_insert_multiplier (halfword i, halfword v);
extern void     tex_set_insert_penalty    (halfword i, halfword v);
extern void     tex_set_insert_distance   (halfword i, halfword v);
extern void     tex_set_insert_maxdepth   (halfword i, halfword v);
extern void     tex_set_insert_height     (halfword i, scaled v);
extern void     tex_set_insert_depth      (halfword i, scaled v);
extern void     tex_set_insert_width      (halfword i, scaled v);
extern void     tex_set_insert_content    (halfword i, halfword v);
extern void     tex_set_insert_storage    (halfword i, halfword v);

extern void     tex_wipe_insert           (halfword i);

extern void     tex_initialize_inserts    (void);
extern int      tex_valid_insert_id       (halfword n);
extern void     tex_dump_insert_data      (dumpstream f);
extern void     tex_undump_insert_data    (dumpstream f);

extern halfword lmt_get_insert_distance   (halfword i, int slot); /* callback */

extern halfword tex_get_insert_progress   (halfword i);

extern void     tex_insert_store          (halfword i, halfword n);
extern void     tex_insert_restore        (halfword n);
extern int      tex_insert_stored         (void);

extern halfword tex_scan_insert_index     (void);
extern void     tex_set_insert_mode       (halfword mode);
extern int      tex_insert_is_void        (halfword i);

extern void     tex_run_insert            (void);
extern void     tex_finish_insert_group   (void);

# endif
