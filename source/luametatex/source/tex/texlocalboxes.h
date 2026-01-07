/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LOCALBOXES_H
# define LMT_LOCALBOXES_H

/*tex Todo: determine when to update (grouping, copying) or when to replace. */

extern halfword   tex_get_local_boxes             (halfword location);
extern void       tex_set_local_boxes             (halfword b, halfword location);
extern halfword   tex_use_local_boxes             (halfword p, halfword location);
extern void       tex_update_local_boxes          (halfword b, halfword index, halfword location);
extern void       tex_replace_local_boxes         (halfword par, halfword b, halfword index, halfword location);
extern void       tex_reset_local_boxes           (halfword index, halfword location);
extern void       tex_reset_local_box             (halfword location); 

extern void       tex_add_local_boxes             (halfword p);
extern void       tex_scan_local_boxes_keys       (quarterword *options, halfword *index);
extern halfword   tex_valid_box_index             (halfword n);

/*tex Helpers, just in case we decide to be more sparse. */

extern scaled     tex_get_local_left_width        (halfword p);
extern scaled     tex_get_local_right_width       (halfword p);

extern void       tex_set_local_left_width        (halfword p, scaled width);
extern void       tex_set_local_right_width       (halfword p, scaled width);

extern halfword   tex_get_local_interline_penalty (halfword p);
extern halfword   tex_get_local_broken_penalty    (halfword p);
extern halfword   tex_get_local_tolerance         (halfword p);
extern halfword   tex_get_local_pre_tolerance     (halfword p);
extern scaled     tex_get_local_hang_indent       (halfword p);
extern halfword   tex_get_local_hang_after        (halfword p);

extern void       tex_set_local_interline_penalty (halfword p, halfword penalty);
extern void       tex_set_local_broken_penalty    (halfword p, halfword penalty);
extern void       tex_set_local_tolerance         (halfword p, halfword tolerance);
extern void       tex_set_local_pre_tolerance     (halfword p, halfword tolerance);
extern void       tex_set_local_hang_indent       (halfword p, halfword amount);
extern void       tex_set_local_hang_after        (halfword p, halfword amount);

extern void       tex_aux_scan_local_box          (int code);
extern void       tex_aux_finish_local_box        (void);

extern int        tex_show_localbox_record        (void);

# endif