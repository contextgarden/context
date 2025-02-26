/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXDISCRETIONARIES_H
# define LMT_TEXDISCRETIONARIES_H

extern halfword tex_new_disc_node           (quarterword subtype);
extern void     tex_set_disc_field          (halfword target, halfword location, halfword source);
extern void     tex_check_disc_field        (halfword target);
extern void     tex_set_discpart            (halfword d, halfword h, halfword t, halfword code);
extern halfword tex_flatten_discretionaries (halfword head, int *count, int nest);
extern void     tex_soften_hyphens          (halfword head, int *found, int *replaced);

void            tex_run_discretionary       (void);
void            tex_finish_discretionary    (void);

# endif
