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
    halfword       last_par_trigger;
    halfword       last_par_context;
    halfword       loop_iterator;
    halfword       loop_nesting;
    halfword       loop_stack_head;
    halfword       loop_stack_tail; 
    halfword       quit_loop;
    halfword       padding;
} main_control_state_info;

extern main_control_state_info lmt_main_control_state;

extern void     tex_initialize_variables            (void);
extern int      tex_main_control                    (void);

extern void     tex_normal_paragraph                (int context);
extern void     tex_begin_paragraph                 (int doindent, int context);
extern void     tex_end_paragraph                   (int group, int context);
extern int      tex_wrapped_up_paragraph            (int context, int final);

extern void     tex_insert_paragraph_token          (void);

extern int      tex_in_privileged_mode              (void);
extern void     tex_you_cant_error                  (const char *helpinfo);

extern void     tex_off_save                        (void);

extern halfword tex_local_scan_box                  (void);
extern void     tex_box_end                         (int boxcontext, halfword boxnode, scaled shift, halfword mainclass, halfword slot, halfword callback);

extern void     tex_get_r_token                     (void);

extern void     tex_begin_local_control             (void);
extern void     tex_end_local_control               (void);
extern void     tex_local_control                   (int obeymode);
extern void     tex_local_control_message           (const char *s);
extern void     tex_page_boundary_message           (const char *s, halfword boundary);

extern void     tex_inject_text_or_line_dir         (int d, int check_glue);

extern void     tex_handle_assignments              (void); /*tex Used in math. */

extern void     tex_assign_internal_integer_value   (int a, halfword p, int val);
extern void     tex_assign_internal_attribute_value (int a, halfword p, int val);
extern void     tex_assign_internal_posit_value     (int a, halfword p, int val);
extern void     tex_assign_internal_dimension_value (int a, halfword p, int val);
extern void     tex_assign_internal_skip_value      (int a, halfword p, int val);
extern void     tex_assign_internal_unit_value      (int a, halfword p, int val);

extern void     tex_aux_lua_call                    (halfword cmd, halfword chr);

extern halfword tex_nested_loop_iterator            (void);
extern halfword tex_previous_loop_iterator          (void);
extern halfword tex_expand_parameter                (halfword tok, halfword *tail);
extern halfword tex_expand_iterator                 (halfword tok);

extern void     tex_show_discretionary_group        (void);
extern int      tex_show_discretionary_record       (void);

inline int valid_parameter_reference(int r) 
{
    switch (r) {
        case I_token_l: case I_token_o: // iterator
        case P_token_l: case P_token_o: // parent iterator
        case G_token_l: case G_token_o: // grandparent iterator
        case H_token_l: case H_token_o: // hash escape
        case L_token_l: case L_token_o: // newline escape (\n)
     // case N_token_l: case N_token_o: // no break space
        case Q_token_l: case Q_token_o: // double quote
        case R_token_l: case R_token_o: // return escape (\r)
        case S_token_l: case S_token_o: // space escape
        case T_token_l: case T_token_o: // tab escape (\t)
        case X_token_l: case X_token_o: // backslash escape
     // case Z_token_l: case Z_token_o: // zero width space
            return token_chr(r);
        default:
            return 0;
    }
}

inline int valid_iterator_reference(int r) 
{
    switch (r) {
        case I_token_l: case I_token_o: // iterator
        case P_token_l: case P_token_o: // parent iterator
        case G_token_l: case G_token_o: // grandparent iterator
            return token_chr(r);
        default:
            return 0;
    }
}

# endif
