/*
    See license.txt in the root of this project.
*/

# ifndef EXTENSIONS_H
# define EXTENSIONS_H

/*tex

    Extensions also relates to \ETEX\ extensions, not only whatits based
    extensions. We have only one (generic) whatsit now.

*/

# define FOPEN_R_MODE    "r"
# define FOPEN_W_MODE    "wb"
# define FOPEN_RBIN_MODE "rb"
# define FOPEN_WBIN_MODE "wb"

/*tex

    The |\pagediscards| and |\splitdiscards| commands share the command code
    |un_vbox| with |\unvbox| and |\unvcopy|, they are distinguished by their
    |chr_code| values |last_box_code| and |vsplit_code|. These |chr_code| values
    are larger than |box_code| and |copy_code|.

*/

extern void expand_macros_in_tokenlist(halfword p);
extern void new_whatsit(halfword s);

extern void print_group(int e);
extern void group_trace(int e);
extern void group_warning(void);
extern void if_warning(void);
extern void file_warning(void);

# define get_tex_dimen_register(j) dimen(j)
# define get_tex_skip_register(j) skip(j)
# define get_tex_mu_skip_register(j) mu_skip(j)
# define get_tex_count_register(j) count(j)
# define get_tex_attribute_register(j) attribute(j)
# define get_tex_box_register(j) box(j)

extern int set_tex_dimen_register(int j, scaled v);
extern int set_tex_skip_register(int j, halfword v);
extern int set_tex_mu_skip_register(int j, halfword v);
extern int set_tex_count_register(int j, scaled v);
extern int set_tex_box_register(int j, scaled v);
extern int set_tex_attribute_register(int j, scaled v);
extern int get_tex_toks_register(int l);
extern int set_tex_toks_register(int j, lstring s);
extern int scan_tex_toks_register(int j, int c, lstring s);

#endif
