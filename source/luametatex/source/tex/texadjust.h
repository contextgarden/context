/*
    See license.txt in the root of this project.
*/

/*tex More will move here. */

# ifndef LMT_ADJUST_H
# define LMT_ADJUST_H

extern void     tex_initialize_adjust    (void);
extern void     tex_cleanup_adjust       (void);
                                         
extern void     tex_run_vadjust          (void);
extern void     tex_set_vadjust          (halfword target);
extern void     tex_finish_vadjust_group (void);
                                         
extern int      tex_valid_adjust_index   (halfword n);
                                         
extern void     tex_inject_adjust_list   (halfword list, int context, int obeyoptions, halfword nextnode, const line_break_properties *properties);
                                         
extern void     tex_adjust_passon        (halfword box, halfword adjust);
extern void     tex_adjust_attach        (halfword box, halfword adjust);

extern halfword tex_prepend_adjust_list  (halfword head, halfword tail, halfword adjust, const char *detail);
extern halfword tex_append_adjust_list   (halfword head, halfword tail, halfword adjust, const char *detail);

extern halfword tex_flush_adjust_append  (halfword adjust, halfword tail);
extern halfword tex_flush_adjust_prepend (halfword adjust, halfword tail);

extern void     tex_show_adjust_group    (void);
extern int      tex_show_adjust_record   (void);

# endif