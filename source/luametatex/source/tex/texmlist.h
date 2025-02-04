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

typedef enum mlist_to_hlist_contexts { 
    m_to_h_callback = 1,
    m_to_h_cleanup  = 2, 
    m_to_h_pre      = 3, 
    m_to_h_post     = 4, 
    m_to_h_replace  = 5,
    m_to_h_sublist  = 6,
    m_to_h_engine   = 7,
} mlist_to_hlist_contexts;

extern void     tex_mlist_to_hlist_prepare  (void);
extern void     tex_run_mlist_to_hlist      (halfword p, halfword penalties, halfword style, int beginclass, int endclass);
extern halfword tex_mlist_to_hlist          (halfword, int penalties, int mainstyle, int beginclass, int endclass, kernset *kerns, int where);
extern halfword tex_make_extensible         (halfword fnt, halfword chr, scaled target, scaled min_overlap, int horizontal, halfword att, halfword size);
extern halfword tex_new_math_glyph          (halfword fnt, halfword chr);
extern halfword tex_math_spacing_glue       (halfword ltype, halfword rtype, halfword style);
                                            
extern halfword tex_math_font_char_ht       (halfword fnt, halfword chr, halfword style);
extern halfword tex_math_font_char_dp       (halfword fnt, halfword chr, halfword style);                                         
extern void     tex_set_math_text_font      (halfword style, int usefamfont);
                                            
extern scaled   tex_math_parameter_x_scaled (int style, int param);
extern scaled   tex_math_parameter_y_scaled (int style, int param);

# endif
