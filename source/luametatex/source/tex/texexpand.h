/*
    See license.txt in the root of this project.
*/

# ifndef LMT_EXPAND_H
# define LMT_EXPAND_H

typedef struct expand_state_info {
    limits_data limits;
    int         depth;
    int         cs_name_level;
    int         arguments;
    halfword    match_token_head;
    int         padding;
} expand_state_info ;

extern expand_state_info lmt_expand_state ;

/* we can also have a get_x_token_ignore_spaces */

extern void     tex_initialize_expansion    (void);
extern void     tex_cleanup_expansion       (void);

extern halfword tex_expand_match_token_head (void);
extern void     tex_expand_current_token    (void);
extern halfword tex_get_x_token             (void); /* very texie names */
extern void     tex_x_token                 (void); /* very texie names */
extern void     tex_insert_relax_and_cur_cs (void);

extern halfword tex_create_csname           (void);
extern int      tex_is_valid_csname         (void);

extern int      tex_get_parameter_count     (void);

# endif
