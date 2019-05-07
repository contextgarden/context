/*
    See license.txt in the root of this project.
*/

# ifndef MLIST_H
# define MLIST_H 1

extern void run_mlist_to_hlist(halfword, int, int);
extern void mlist_to_hlist(halfword, int, int);
extern void fixup_math_parameters(int fam_id, int size_id, int f, int lvl);

extern scaled get_math_quad_style(int a);
extern scaled get_math_quad_size(int a);

extern halfword make_extensible(internal_font_number fnt, halfword chr, scaled v, scaled min_overlap, int horizontal, halfword att);

# endif
