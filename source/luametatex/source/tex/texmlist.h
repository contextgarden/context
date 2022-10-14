/*
    See license.txt in the root of this project.
*/

# ifndef LMT_MLIST_H
# define LMT_MLIST_H

typedef struct kernset {
    scaled   topright;
    scaled   bottomright;
    scaled   topleft;
    scaled   bottomleft;
    scaled   height;
    scaled   depth;
    scaled   toptotal;
    scaled   bottomtotal;
    halfword dimensions;
    halfword font;
    halfword character; 
    halfword padding;
} kernset; 

extern void     tex_run_mlist_to_hlist (halfword p, halfword penalties, halfword style, int beginclass, int endclass);
extern halfword tex_mlist_to_hlist     (halfword, int penalties, int mainstyle, int beginclass, int endclass, kernset *kerns);
extern halfword tex_make_extensible    (halfword fnt, halfword chr, scaled target, scaled min_overlap, int horizontal, halfword att, halfword size);
extern halfword tex_new_math_glyph     (halfword fnt, halfword chr);
extern halfword tex_math_spacing_glue  (halfword ltype, halfword rtype, halfword style);

extern halfword tex_math_font_char_ht  (halfword fnt, halfword chr, halfword style);
extern halfword tex_math_font_char_dp  (halfword fnt, halfword chr, halfword style);

extern void     tex_set_math_text_font (halfword style, int usefamfont);

# endif
