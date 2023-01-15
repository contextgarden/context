/*
    See license.txt in the root of this project.
*/

/*tex More will move here. */

# ifndef LMT_ADJUST_H
# define LMT_ADJUST_H

typedef enum saved_adjust_items {
    saved_adjust_item_location,
    saved_adjust_item_options,
    saved_adjust_item_index,
    saved_adjust_item_attr_list,
    saved_adjust_item_depth_before,
    saved_adjust_item_depth_after,
    saved_adjust_item_target,
    saved_adjust_n_of_items,
} saved_adjust_items;

extern void     tex_initialize_adjust    (void);
extern void     tex_cleanup_adjust       (void);
                                         
extern void     tex_run_vadjust          (void);
extern void     tex_set_vadjust          (halfword target);
extern void     tex_finish_vadjust_group (void);
                                         
extern int      tex_valid_adjust_index   (halfword n);
                                         
extern void     tex_inject_adjust_list   (halfword list, int obeyoptions, halfword nextnode, const line_break_properties *properties);
                                         
extern void     tex_adjust_passon        (halfword box, halfword adjust);
extern void     tex_adjust_attach        (halfword box, halfword adjust);

extern halfword tex_prepend_adjust_list  (halfword head, halfword tail, halfword adjust, const char *detail);
extern halfword tex_append_adjust_list   (halfword head, halfword tail, halfword adjust, const char *detail);

extern halfword tex_flush_adjust_append  (halfword adjust, halfword tail);
extern halfword tex_flush_adjust_prepend (halfword adjust, halfword tail);

# endif