/*
    See license.txt in the root of this project.
*/

# ifndef LMT_MAINCONTROL_H
# define LMT_MAINCONTROL_H

/*tex

    To handle the execution state of |main_control|'s eternal loop, an extra global variable is
    used, along with a macro to define its values.

*/

typedef enum control_states {
    goto_next_state,
    goto_skip_token_state,
    goto_return_state,
} control_states;

typedef struct main_control_state_info {
    control_states control_state;
    int            local_level;
    halfword       after_token;
    halfword       after_tokens;
    halfword       last_par_context;
    halfword       loop_iterator;
    halfword       loop_nesting;
    halfword       quit_loop;
} main_control_state_info;

typedef enum saved_discretionary_items {
    saved_discretionary_item_component = 0,
    saved_discretionary_n_of_items     = 1,
} saved_discretionary_items;

extern main_control_state_info lmt_main_control_state;

extern void     tex_initialize_variables            (void);
extern int      tex_main_control                    (void);

extern void     tex_normal_paragraph                (int context);
extern void     tex_begin_paragraph                 (int doindent, int context);
extern void     tex_end_paragraph                   (int group, int context);
extern int      tex_wrapped_up_paragraph            (int context);

extern void     tex_insert_paragraph_token          (void);

extern int      tex_in_privileged_mode              (void);
extern void     tex_you_cant_error                  (const char *helpinfo);

extern void     tex_off_save                        (void);

extern halfword tex_local_scan_box                  (void);
extern void     tex_box_end                         (int boxcontext, halfword boxnode, scaled shift, halfword mainclass);

extern void     tex_get_r_token                     (void);

extern void     tex_begin_local_control             (void);
extern void     tex_end_local_control               (void);
extern void     tex_local_control                   (int obeymode);
extern void     tex_local_control_message           (const char *s);
extern void     tex_page_boundary_message           (const char *s, halfword boundary);

extern void     tex_inject_text_or_line_dir         (int d, int check_glue);

extern void     tex_run_prefixed_command            (void);

extern void     tex_handle_assignments              (void); /*tex Used in math. */

extern void     tex_assign_internal_int_value       (int a, halfword p, int val);
extern void     tex_assign_internal_attribute_value (int a, halfword p, int val);
extern void     tex_assign_internal_dimen_value     (int a, halfword p, int val);
extern void     tex_assign_internal_skip_value      (int a, halfword p, int val);

# endif
