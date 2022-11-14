/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXFONT_H
# define LMT_TEXFONT_H

# include "tex/textypes.h"

/*tex

    In the \WEBC\ infrastructrure there is code that deals with endianness of the machine but in
    \LUAMETATEX\ we don't need this. In \LUATEX\ sharing the format file was already dropped, simply
    because we can also store \LUA\ bytecode in the format. In the other engines font data can end
    up in the format file and that in turn then also can be endian dependent. But in \LUAMETATEX\
    we no longer stored font data, and that is yet another reason why there is no endian related
    code here.

    The ligature and kern structures are for traditional \TEX\ fonts, thise that are handles by the
    built in reference handlers. Although \OPENTYPE\ is more versatile, we should not forget that
    for many (latin) scripts these so called base fonts are quite adequate and efficient. We could
    of course implement base support in \LUA\ but although \LUAMETATEX\ can delegate a lot, we also
    keep the reference implementation available: it is well documented, was for a long time the best
    one could get and doesn't take that much code. So, here come the basic structures:

*/

typedef struct ligatureinfo {
    int type;
    int ligature;
    int adjacent;
    /* alignment */
    int padding;
} ligatureinfo;

typedef struct kerninfo {
    int kern;
    int adjacent;
} kerninfo;

/*tex

    In \LUAMETATEX, at runtime, after a font is loaded via a callback, we only store the little
    information that is needed for basic ligature building and kerning, math rendering (like
    extensibles), and par building which includes protrusion and expansion. We don't need anything
    related to the backend because outpout is delegated to \LUA.

    The most extensive data structures are those related to \OPENTYPE\ math. When passing a font we
    can save memory by using the |hasmath| directive. In \LUAMETATEX\ we can then have a different
    |struct| with 15 fields less than in \LUATEX\ which, combined with other savings, saves some 60
    bytes. The disadvantage is that accessors of those fields also need to act upon that flag, which
    involves more testing. However, because in practice math font access is not that prominent so
    the gain outweights this potential performance hit. For an average \CJK\ font with 5000
    characters we saves 300000 bytes. Because a complete Latin font with various features also can
    have thousands of glyphs, it can save some memory there too. It's changes like this that give
    \LUAMETATEX\ a much smaller memory footprint than its predecessor.

    The next record relates to math extensibles. It is good to realize that traditional \TEX\ fonts
    are handled differently in the math subengine than \OPENTYPE\ math fonts. However, we use the
    more extensive \OPENTYPE\ structure for both type of fonts.

*/

typedef struct extinfo {
    struct extinfo *next;
    int             glyph;
    int             start_overlap;
    int             end_overlap;
    int             advance;
    int             extender;
    /* alignment */
    int             padding;
} extinfo;

/*tex 
    We have dedicated fields for hparts and vparts and their italics. Only avery few fonts actually
    set the italic on the extensible which is why the engine can use the regular italic, which in 
    that case is then the last in the variant list because that is where we put the recipe. Keep in
    mind that in an \OPENTYPE\ fonts we have a base glyph that has a variant list and part recipe 
    while in the engine (in good \TEX\ tradition) we chain the variants (with the next field)) so by 
    the time we arrive at the last one we look at the (h,v) italic there. No fonts (so far) have a 
    horizontal extensible with a set italic correction. 
    
    Actually, because the specification is rather explicit about glyphs only having horizontal or
    vertical extensibles we now have collapsed the two categories into one.
*/

typedef struct mathinfo {
    /*tex
       Optional code points for next smaller in size, right2left and flat accent glyphs.
    */
    halfword  smaller;     
    halfword  mirror;      
    halfword  flat_accent; 
    halfword  next;
    /*tex 
        The top anchor is provides by the font and is also known as topaccent while the bottom 
        anchor is one set by (in our case) \CONTEXT.  
    */
    scaled    top_anchor;              
    scaled    bottom_anchor;           
    /*tex 
        A set of pointers to variable size arrays which is why we also have the number of slots 
        stored. 
    */
    int       top_left_math_kerns;        
    int       top_right_math_kerns;       
    int       bottom_right_math_kerns;    
    int       bottom_left_math_kerns;     
    scaled   *top_left_math_kern_array;    
    scaled   *top_right_math_kern_array;
    scaled   *bottom_right_math_kern_array;
    scaled   *bottom_left_math_kern_array;
    /*tex 
        Here come the extensible recipes. Because we haven't seen both in one glyph we can share 
        the pointer and put a h/v flag in the tag field. For the moment we keep them both because
        we might want to play with a two dimensional extensible some day. 
    */
    extinfo  *extensible_recipe;        
    scaled    extensible_italic;         
    /*tex These are for specific (script) anchoring. */
    scaled    top_left_kern;
    scaled    bottom_left_kern;
    scaled    top_right_kern;
    scaled    bottom_right_kern;
    /*tex These four are used in accents. */
    scaled    left_margin;
    scaled    right_margin;
    scaled    top_margin;
    scaled    bottom_margin;
    /*tex As are the following. */
    scaled    top_overshoot;
    scaled    bottom_overshoot;
    /*tex These are for degrees in radicals. */
    scaled    inner_x_offset; 
    scaled    inner_y_offset; 
} mathinfo;

typedef struct charinfo {
    /*tex
        This is what \TEX\ uses when it calculates the dimensions needed for building boxes and
        breaking paragraphs into lines. The italic correction is part of that as it has a primitive
        that needs the value.
    */
    scaled        width;
    scaled        height;
    scaled        depth;
    scaled        italic;
    /*tex
        The next three variables relate to expansion and protrusion, properties introduced in the
        \PDFTEX\ engine. Handling of protrusion and expansion is the only features that we inherit
        from this important extension to traditional \TEX. 

        We can make the next four into a a pointer which saves on large fonts and only a subset 
        of characters has protrusion or expansion, if used at all. That way we delegate some memory 
        consumption to usage (of course allocated blobs also have overhead).  
    */
    scaled        expansion;    
    scaled        compression;
    scaled        leftprotrusion;
    scaled        rightprotrusion;
    /*tex
        The tag and remainder are used in a \TFM\ file for signaling ligatures. They are also used 
        for math extensions in traditional \TEX\ fonts. We used to pack the tag and remainder
        in an integer: 2 bits is enough for the tag (but we get some more) and the remainder (aka 
        next) fits in 21 bits. So we had |tagrem| for quite a while. 

        But we now use a 32 bit tag field and use proper next field that has been moved to the math 
        blob so that we can have a compression field here without padding. 
    */
    halfword      tag; 
    /*tex
        Traditional \TEX\ fonts use these two lists for ligature building and inter-character
        kerning and these are now optional (via pointers). By also using an indirect structure for
        math data we save quite a bit of memory when we have no math font.

        We could combine math and ligatures and save two slots but then we cannot have a hybrid base
        font so ... not now. 
    */
    kerninfo     *kerns;
    mathinfo     *math;       
    ligatureinfo *ligatures;  
} charinfo;

/*
    An option is to make this a pointer to a structure but then we also waste a slot. When we 
    never support it in math then we can actually go smaller: 
    
    charinfo: 8 * 4 : width height depth italic tag *[text or math] *kerns padding 
    textinfo: 4 * 4 : expansion leftprotrusion rightprotrusion *ligatures
    mathinfo: 2 * 4 : next padding ... n * 4 

    But ... given the amount of fields that \CONTEXT\ adds to the basic character data anyway 
    there is no real reason to spend much time in saving some bytes here.  

*/

/*tex
    We can just abuse the token setters and getters here.
*/

//define charinfo_tag    token_cmd
//define charinfo_rem    token_chr
//define charinfo_tagrem token_val

/*tex

    For a font instance we only store the bits that are used by the engine itself. Of course more
    data can (and normally will be) be kept at the \TEX\ cq.\ \LUA\ end.

    We could store a scale (/1000) and avoid copying a font but then we also need to multiply
    width, height, etc. when queried (extra overhead). A bit tricky is then dealing with (virtual)
    commands. It is not that big a deal in \CONTEXT\ so I might actually add this feature but only
    very few documents use many font instances so in the end the gain is neglectable (we only save
    some memory). Also, we then need to adapt the math processing quite a bit which is always kind
    of tricky.

    Again, compared to \LUATEX\ there is less data stored here because we don't need to control the
    backend. Of course in \CONTEXT\ we keep plenty of data at the \LUA\ end, but we did that already
    anyway.

*/

typedef struct texfont {
    /*tex the range of (allocated) characters */
    int         first_character;
    int         last_character;
    /*tex the (sparse) character (glyph) array */
    sa_tree     characters;
    charinfo   *chardata;
    int         chardata_count;
    int         chardata_size;
    /*tex properties used in messages */
    int         size;
    int         design_size;
    char       *name;
    char       *original;
    /*tex for experimental new thingies */
    int         compactmath;
    /*tex this controls the engine */
    int         mathcontrol;
    int         textcontrol;
    /*tex expansion */
    int         max_shrink;
    int         max_stretch;
    int         step;
    /*tex special characters, see \TEX book */
    int         hyphen_char;
    int         skew_char;
    /*tex all parameters, although only some are used */
    int         parameter_count;
    scaled     *parameter_base;
    /*tex also special */
    charinfo   *left_boundary;
    charinfo   *right_boundary;
    /*tex all math parameters */
    scaled     *math_parameter_base;
    int         math_parameter_count;
    /* zero is alignment */
    int         mathscales[3];
} texfont;

/*tex

    Instead of global variables we store some properties that are shared between the different components
    in a dedicated struct.

*/

typedef struct font_state_info {
    texfont     **fonts;
    halfword      adjust_stretch;
    halfword      adjust_shrink;
    halfword      adjust_step;
    int           padding;
    memory_data   font_data;
} font_state_info ;

extern font_state_info lmt_font_state;

# define font_size(a)                   lmt_font_state.fonts[a]->size
# define font_name(a)                   lmt_font_state.fonts[a]->name
# define font_original(a)               lmt_font_state.fonts[a]->original
# define font_design_size(a)            lmt_font_state.fonts[a]->design_size
# define font_first_character(a)        lmt_font_state.fonts[a]->first_character
# define font_last_character(a)         lmt_font_state.fonts[a]->last_character
# define font_compactmath(a)            lmt_font_state.fonts[a]->compactmath
# define font_mathcontrol(a)            lmt_font_state.fonts[a]->mathcontrol
# define font_textcontrol(a)            lmt_font_state.fonts[a]->textcontrol
# define font_hyphen_char(a)            lmt_font_state.fonts[a]->hyphen_char
# define font_skew_char(a)              lmt_font_state.fonts[a]->skew_char
# define font_max_shrink(a)             (lmt_font_state.adjust_step > 0 ? lmt_font_state.adjust_shrink  : lmt_font_state.fonts[a]->max_shrink)
# define font_max_stretch(a)            (lmt_font_state.adjust_step > 0 ? lmt_font_state.adjust_stretch : lmt_font_state.fonts[a]->max_stretch)
# define font_step(a)                   (lmt_font_state.adjust_step > 0 ? lmt_font_state.adjust_step    : lmt_font_state.fonts[a]->step)
# define font_mathscale(a,b)            lmt_font_state.fonts[a]->mathscales[b]

# define set_font_size(a,b)             lmt_font_state.fonts[a]->size = b
# define set_font_name(a,b)             lmt_font_state.fonts[a]->name = b
# define set_font_original(a,b)         lmt_font_state.fonts[a]->original = b
# define set_font_design_size(a,b)      lmt_font_state.fonts[a]->design_size = b
# define set_font_first_character(a,b)  lmt_font_state.fonts[a]->first_character = b
# define set_font_last_character(a,b)   lmt_font_state.fonts[a]->last_character = b
# define set_font_compactmath(a,b)      lmt_font_state.fonts[a]->compactmath = b
# define set_font_mathcontrol(a,b)      lmt_font_state.fonts[a]->mathcontrol = b
# define set_font_textcontrol(a,b)      lmt_font_state.fonts[a]->textcontrol = b
# define set_font_hyphen_char(a,b)      lmt_font_state.fonts[a]->hyphen_char = b
# define set_font_skew_char(a,b)        lmt_font_state.fonts[a]->skew_char = b
# define set_font_max_shrink(a,b)       lmt_font_state.fonts[a]->max_shrink = b
# define set_font_max_stretch(a,b)      lmt_font_state.fonts[a]->max_stretch = b
# define set_font_step(a,b)             lmt_font_state.fonts[a]->step = b

# define set_font_textsize(a,b)         lmt_font_state.fonts[a]->mathscales[0] = b
# define set_font_scriptsize(a,b)       lmt_font_state.fonts[a]->mathscales[1] = b
# define set_font_scriptscriptsize(a,b) lmt_font_state.fonts[a]->mathscales[2] = b

/*tex
    These are bound to a font. There might be a few more in the future. An example is collapsing
    hyphens. One can do that using (in context speak) tlig feature but actually it is some very
    \TEX\ thing, that happened to be implemented using ligatures. In \LUAMETATEX\ it's also a bit
    special because, although it is not really dependent on a language, hyphen handling in \TEX\
    is very present in the hyphenator (also sequences of them). So, naturally it moved there. But
    users who don't want it can disable it per font.
*/

typedef enum text_control_codes {
    text_control_collapse_hyphens = 0x00001,
} text_control_codes;

# define has_font_text_control(f,c)  ((font_textcontrol(f) & c) == c)

/*tex
    These are special codes that are used in the traditional ligature builder. In \OPENTYPE\
    fonts we don't see these. Maybe this will be dropped at some point. 
*/

typedef enum boundarychar_codes {
    left_boundary_char  = -1,
    right_boundary_char = -2,
    non_boundary_char   = -3,
} boundarychar_codes;

# define font_left_boundary(a)        lmt_font_state.fonts[a]->left_boundary
# define font_right_boundary(a)       lmt_font_state.fonts[a]->right_boundary

# define font_has_left_boundary(a)    (font_left_boundary(a))
# define font_has_right_boundary(a)   (font_right_boundary(a))

# define set_font_left_boundary(a,b)  { if (font_left_boundary(a))  { lmt_memory_free(font_left_boundary(a));  } font_left_boundary(a)  = b; }
# define set_font_right_boundary(a,b) { if (font_right_boundary(a)) { lmt_memory_free(font_right_boundary(a)); } font_right_boundary(a) = b; }

/*tex
    The math engine can benefit from these properties. For instance we use them for optimizing 
    the positioning of the degree in a (left) radical. These properties are not stored in the 
    tag (for a short while we had a variable).
*/

/*tex
    In traditional \TEX\ there are just over a handful of font specific parameters for text fonts
    and some more in math fonts. Actually, these parameters were stored in a way that permitted
    adding  more at runtime, something that made no real sense, but can be abused for creeating
    more dimensions than the 256 that traditional \TEX\ provides.
*/

# define font_parameter_count(a)           lmt_font_state.fonts[a]->parameter_count
# define font_parameter_base(a)            lmt_font_state.fonts[a]->parameter_base
# define font_parameter(a,b)               lmt_font_state.fonts[a]->parameter_base[b]

# define font_math_parameter_count(a)      lmt_font_state.fonts[a]->math_parameter_count
# define font_math_parameter_base(a)       lmt_font_state.fonts[a]->math_parameter_base
# define font_math_parameter(a,b)          lmt_font_state.fonts[a]->math_parameter_base[b]

# define set_font_parameter_base(a,b)      lmt_font_state.fonts[a]->parameter_base = b;
# define set_font_math_parameter_base(a,b) lmt_font_state.fonts[a]->math_parameter_base = b;

/*tex
    These font parameters could be adapted at runtime but one should really wonder if that is such
    a good idea nowadays.
 */

//define set_font_parameter(f,n,b)         { if (font_parameter_count(f)      < n) { tex_set_font_parameters(f, n);      } font_parameter(f, n)      = b; }
// # define set_font_math_parameter(f,n,b)    { if (font_math_parameter_count(f) < n) { tex_set_font_math_parameters(f, n); } font_math_parameter(f, n) = b; }

extern void tex_set_font_parameters      (halfword f, int b);
extern void tex_set_font_math_parameters (halfword f, int b);
extern int  tex_get_font_max_id          (void);
extern int  tex_get_font_max_id          (void);

extern halfword tex_checked_font_adjust (
    halfword adjust_spacing,
    halfword adjust_spacing_step,
    halfword adjust_spacing_shrink,
    halfword adjust_spacing_stretch
);

/*tex
    Font parameters are sometimes referred to as |slant(f)|, |space(f)|, etc. These numbers are
    also the font dimen numbers.
*/

typedef enum font_parameter_codes {
    slant_code = 1,
    space_code,
    space_stretch_code,
    space_shrink_code,
    ex_height_code,
    em_width_code,
    extra_space_code,
} font_parameter_codes;

extern scaled   tex_get_font_slant            (halfword f);
extern scaled   tex_get_font_space            (halfword f);
extern scaled   tex_get_font_space_stretch    (halfword f);
extern scaled   tex_get_font_space_shrink     (halfword f);
extern scaled   tex_get_font_ex_height        (halfword f);
extern scaled   tex_get_font_em_width         (halfword f);
extern scaled   tex_get_font_extra_space      (halfword f);
extern scaled   tex_get_font_parameter        (halfword f, halfword code);
extern void     tex_set_font_parameter        (halfword f, halfword code, scaled v);
                
extern scaled   tex_get_scaled_slant          (halfword f);
extern scaled   tex_get_scaled_space          (halfword f);
extern scaled   tex_get_scaled_space_stretch  (halfword f);
extern scaled   tex_get_scaled_space_shrink   (halfword f);
extern scaled   tex_get_scaled_ex_height      (halfword f);
extern scaled   tex_get_scaled_em_width       (halfword f);
extern scaled   tex_get_scaled_extra_space    (halfword f);
extern scaled   tex_get_scaled_parameter      (halfword f, halfword code);
extern void     tex_set_scaled_parameter      (halfword f, halfword code, scaled v);

extern halfword tex_get_scaled_glue           (halfword f);
extern halfword tex_get_scaled_parameter_glue (quarterword p, quarterword s);
extern halfword tex_get_parameter_glue        (quarterword p, quarterword s);

extern halfword tex_get_font_identifier       (halfword fs);

/*tex
    The \OPENTYPE\ math fonts have four edges and reference points for kerns. Here we go:
*/

typedef enum font_math_kern_codes {
    top_right_kern = 1,
    bottom_right_kern,
    bottom_left_kern,
    top_left_kern,
} font_math_kern_codes;

extern charinfo *tex_get_charinfo     (halfword f, int c);
extern int       tex_char_exists      (halfword f, int c);
extern void      tex_char_process     (halfword f, int c);
extern int       tex_math_char_exists (halfword f, int c, int size);
extern int       tex_get_math_char    (halfword f, int c, int size, scaled *scale, int direction);

/*tex 
    These used to be small integers, bit 22 upto 31, but now we have a 32 bit set. We actually don't 
    really need the granularity but by having these flags we can actually add a bit of control, like 
    having kerns but still blocking them. The numbers here are no longer reflective of what a tfm 
    file provides. We assume tfm files to be converted anyway. 

    Not all are needed but at least we now can keep some state. We can actually use them to something
    if we really want to (like when we runt tests). However, that is a rather drastic measure for 
    shared fonts. Tracing is another application and at some point it will be used for this. 
*/

typedef enum char_tag_codes {
    no_tag          = 0x0000, /*tex vanilla character */
    ligatures_tag   = 0x0001, /*tex character has a ligature program, not used */ 
    kerns_tag       = 0x0002, /*tex character has a kerning program, not used */ 
    list_tag        = 0x0004, /*tex character has a successor in a charlist */  
    callback_tag    = 0x0010,
    extensible_tag  = 0x0020, /*tex character is extensible, we can unset it in order to block */
    horizontal_tag  = 0x0040, /*tex horizontal extensible */
    vertical_tag    = 0x0080, /*tex vertical extensible */
    extend_last_tag = 0x0100, /*tex auto scale last variant */
    inner_left_tag  = 0x0200, /*tex anchoring */
    inner_right_tag = 0x0400, /*tex anchoring */
    italic_tag      = 0x0800, 
    n_ary_tag       = 0x1000, 
    radical_tag     = 0x2000, 
    punctuation_tag = 0x4000, 
} char_tag_codes;

/*tex
    These low level setters are not publis and used in helpers. They might become functions
    when I feel the need.
*/

# define set_charinfo_width(ci,val)                        ci->width  = val;
# define set_charinfo_height(ci,val)                       ci->height = val;
# define set_charinfo_depth(ci,val)                        ci->depth  = val;
# define set_charinfo_italic(ci,val)                       ci->italic = val;
# define set_charinfo_expansion(ci,val)                    ci->expansion = val;
# define set_charinfo_compression(ci,val)                  ci->compression = val;
# define set_charinfo_leftprotrusion(ci,val)               ci->leftprotrusion = val;
# define set_charinfo_rightprotrusion(ci,val)              ci->rightprotrusion = val;

# define set_charinfo_tag(ci,val)                          ci->tag |= val;
# define set_charinfo_next(ci,val)                         if (ci->math) { ci->math->next = val; }

# define has_charinfo_tag(ci,p)                            (ci->tag) & (p) == (p)) 
# define get_charinfo_tag(ci)                              ci->tag

# define set_charinfo_ligatures(ci,val)                    { lmt_memory_free(ci->ligatures); ci->ligatures = val; }
# define set_charinfo_kerns(ci,val)                        { lmt_memory_free(ci->kerns);     ci->kerns     = val; }
# define set_charinfo_math(ci,val)                         { lmt_memory_free(ci->math);      ci->math      = val; }

# define set_charinfo_top_left_math_kern_array(ci,val)     if (ci->math) { lmt_memory_free(ci->math->top_left_math_kern_array);     ci->math->top_left_math_kern_array = val; }
# define set_charinfo_top_right_math_kern_array(ci,val)    if (ci->math) { lmt_memory_free(ci->math->top_right_math_kern_array);    ci->math->top_left_math_kern_array = val; }
# define set_charinfo_bottom_right_math_kern_array(ci,val) if (ci->math) { lmt_memory_free(ci->math->bottom_right_math_kern_array); ci->math->top_left_math_kern_array = val; }
# define set_charinfo_bottom_left_math_kern_array(ci,val)  if (ci->math) { lmt_memory_free(ci->math->bottom_left_math_kern_array);  ci->math->top_left_math_kern_array = val; }

//define set_charinfo_options(ci,val)                      if (ci->math) { ci->math->options = val; }

# define set_ligature_item(f,b,c,d)                        { f.type = b; f.adjacent = c; f.ligature = d; }
# define set_kern_item(f,b,c)                              { f.adjacent = b; f.kern = c; }

# define set_charinfo_left_margin(ci,val)                  if (ci->math) { ci->math->left_margin = val; }
# define set_charinfo_right_margin(ci,val)                 if (ci->math) { ci->math->right_margin = val; }
# define set_charinfo_top_margin(ci,val)                   if (ci->math) { ci->math->top_margin = val; }
# define set_charinfo_bottom_margin(ci,val)                if (ci->math) { ci->math->bottom_margin = val; }

# define set_charinfo_smaller(ci,val)                      if (ci->math) { ci->math->smaller = val; }
# define set_charinfo_mirror(ci,val)                       if (ci->math) { ci->math->mirror = val; }
# define set_charinfo_extensible_italic(ci,val)            if (ci->math) { ci->math->extensible_italic = val; }
# define set_charinfo_top_anchor(ci,val)                   if (ci->math) { ci->math->top_anchor = val; }
# define set_charinfo_bottom_anchor(ci,val)                if (ci->math) { ci->math->bottom_anchor = val; }
# define set_charinfo_flat_accent(ci,val)                  if (ci->math) { ci->math->flat_accent = val; }

# define set_charinfo_inner_x_offset(ci,val)               if (ci->math) { ci->math->inner_x_offset = val; }
# define set_charinfo_inner_y_offset(ci,val)               if (ci->math) { ci->math->inner_y_offset = val; }

# define set_charinfo_top_left_kern(ci,val)                if (ci->math) { ci->math->top_left_kern = val; }
# define set_charinfo_top_right_kern(ci,val)               if (ci->math) { ci->math->top_right_kern = val; }
# define set_charinfo_bottom_left_kern(ci,val)             if (ci->math) { ci->math->bottom_left_kern = val; }
# define set_charinfo_bottom_right_kern(ci,val)            if (ci->math) { ci->math->bottom_right_kern = val; }

# define set_charinfo_top_overshoot(ci,val)                if (ci->math) { ci->math->top_overshoot = val; }
# define set_charinfo_bottom_overshoot(ci,val)             if (ci->math) { ci->math->bottom_overshoot = val; }

/*tex Setters: */

void             tex_set_lpcode_in_font                 (halfword f, halfword c, halfword i);
void             tex_set_rpcode_in_font                 (halfword f, halfword c, halfword i);
void             tex_set_efcode_in_font                 (halfword f, halfword c, halfword i);
void             tex_set_cfcode_in_font                 (halfword f, halfword c, halfword i);

extern void      tex_add_charinfo_math_kern             (charinfo *ci, int type, scaled ht, scaled krn);
extern int       tex_get_charinfo_math_kerns            (charinfo *ci, int id);
extern void      tex_set_charinfo_extensible_recipe     (charinfo *ci, extinfo *ext);
extern void      tex_append_charinfo_extensible_recipe  (charinfo *ci, int glyph, int startconnect, int endconnect, int advance, int repeater);

/*tex Checkers: */

int              tex_char_has_math                      (halfword f, halfword c);
int              tex_has_ligature                       (halfword f, halfword c);
int              tex_has_kern                           (halfword f, halfword c);

/*tex Getters: */

# define MATH_KERN_NOT_FOUND 0x7FFFFFFF

extern scaled    tex_font_x_scaled                      (scaled v);
extern scaled    tex_font_y_scaled                      (scaled v);

extern scaled    tex_char_width_from_font               (halfword f, halfword c); /* math + maincontrol */
extern scaled    tex_char_height_from_font              (halfword f, halfword c); /* math + maincontrol */
extern scaled    tex_char_depth_from_font               (halfword f, halfword c); /* math + maincontrol */
extern scaled    tex_char_total_from_font               (halfword f, halfword c); /* math */
extern scaledwhd tex_char_whd_from_font                 (halfword f, halfword c); /* math + maincontrol */
extern scaled    tex_char_italic_from_font              (halfword f, halfword c); /* math + maincontrol */
extern scaled    tex_char_ef_from_font                  (halfword f, halfword c); /* packaging + maincontrol */
extern scaled    tex_char_cf_from_font                  (halfword f, halfword c); /* packaging + maincontrol */
extern scaled    tex_char_lp_from_font                  (halfword f, halfword c); /* packaging + maincontrol */
extern scaled    tex_char_rp_from_font                  (halfword f, halfword c); /* packaging + maincontrol */
extern halfword  tex_char_tag_from_font                 (halfword f, halfword c); /* math */
extern halfword  tex_char_next_from_font                (halfword f, halfword c); /* math */
extern halfword  tex_char_has_tag_from_font             (halfword f, halfword c, halfword tag); 
extern void      tex_char_reset_tag_from_font           (halfword f, halfword c, halfword tag); 
extern int       tex_char_checked_tag                   (halfword tag);
extern scaled    tex_char_inner_x_offset_from_font      (halfword f, halfword c);
extern scaled    tex_char_inner_y_offset_from_font      (halfword f, halfword c);
extern scaled    tex_char_top_left_kern_from_font       (halfword f, halfword c); /* math */
extern scaled    tex_char_top_right_kern_from_font      (halfword f, halfword c); /* math */
extern scaled    tex_char_bottom_left_kern_from_font    (halfword f, halfword c); /* math */
extern scaled    tex_char_bottom_right_kern_from_font   (halfword f, halfword c); /* math */
extern halfword  tex_char_extensible_italic_from_font   (halfword f, halfword c);
extern halfword  tex_char_flat_accent_from_font         (halfword f, halfword c);
extern halfword  tex_char_top_anchor_from_font          (halfword f, halfword c);
extern halfword  tex_char_bottom_anchor_from_font       (halfword f, halfword c);
extern scaled    tex_char_left_margin_from_font         (halfword f, halfword c);
extern scaled    tex_char_right_margin_from_font        (halfword f, halfword c);
extern scaled    tex_char_top_margin_from_font          (halfword f, halfword c);
extern scaled    tex_char_bottom_margin_from_font       (halfword f, halfword c);
extern scaled    tex_char_top_overshoot_from_font       (halfword f, halfword c);
extern scaled    tex_char_bottom_overshoot_from_font    (halfword f, halfword c);
extern scaled    tex_char_inner_x_offset_from_font      (halfword f, halfword c);
extern scaled    tex_char_inner_y_offset_from_font      (halfword f, halfword c);
extern extinfo  *tex_char_extensible_recipe_from_font   (halfword f, halfword c);

extern halfword  tex_char_unchecked_top_anchor_from_font    (halfword f, halfword c);
extern halfword  tex_char_unchecked_bottom_anchor_from_font (halfword f, halfword c);

extern scaled    tex_char_width_from_glyph              (halfword g); /* x/y scaled */
extern scaled    tex_char_height_from_glyph             (halfword g); /* x/y scaled */
extern scaled    tex_char_depth_from_glyph              (halfword g); /* x/y scaled */
extern scaled    tex_char_total_from_glyph              (halfword g); /* x/y scaled */
extern scaled    tex_char_italic_from_glyph             (halfword g); /* x/y scaled */
extern scaled    tex_char_width_italic_from_glyph       (halfword g); /* x/y scaled */
extern scaledwhd tex_char_whd_from_glyph                (halfword g); /* x/y scaled */
                                                       
extern int       tex_valid_kern                         (halfword left, halfword right);            /* returns kern */
extern int       tex_valid_ligature                     (halfword left, halfword right, int *slot); /* returns type */
                                                       
extern scaled    tex_calculated_char_width              (halfword f, halfword c, halfword ex);
extern scaled    tex_calculated_glyph_width             (halfword g, halfword ex); /* scale */

/*tex
    Kerns: the |otherchar| value signals \quote {stop}. These are not really public and only
    to be used in the helpers. But we keep them as reference.
*/

# define end_kern            0x7FFFFF

# define charinfo_kern(b,c)  b->kerns[c]

# define kern_char(b)       (b).adjacent
# define kern_kern(b)       (b).kern
# define kern_end(b)        ((b).adjacent == end_kern)
# define kern_disabled(b)   ((b).adjacent > end_kern)

/*tex
    Ligatures: the |otherchar| value signals \quote {stop}. These are not really public and only
    to be used in the helpers. But we keep them as reference.
*/

# define end_of_ligature_code    0x7FFFFF

# define charinfo_ligature(b,c)  b->ligatures[c]

# define ligature_is_valid(a)    ((a).type != 0)
# define ligature_type(a)        ((a).type >> 1)
# define ligature_char(a)        (a).adjacent
# define ligature_replacement(a) (a).ligature
# define ligature_end(a)         ((a).adjacent == end_of_ligature_code)
# define ligature_disabled(a)    ((a).adjacent > end_of_ligature_code)

/*tex Extension specific: */

typedef enum math_extension_modes {
    math_extension_normal,
    math_extension_repeat,
} math_extension_modes;

/*tex Expansion and protrusion: */

typedef enum adjust_spacing_modes {
    adjust_spacing_off,
    adjust_spacing_unused,
    adjust_spacing_full,
    adjust_spacing_font,
} adjust_spacing_modes;

typedef enum protrude_chars_modes {
    protrude_chars_off,
    protrude_chars_unused,
    protrude_chars_normal,
    protrude_chars_advanced,
} protrude_chars_modes;

/*
typedef enum math_extension_locations {
    extension_top,
    extension_bottom,
    extension_middle,
    extension_repeat,
} math_extension_locations;
*/

extern halfword      tex_checked_font          (halfword f);
extern int           tex_is_valid_font         (halfword f);
extern int           tex_raw_get_kern          (halfword f, int lc, int rc);
extern int           tex_get_kern              (halfword f, int lc, int rc);
extern ligatureinfo  tex_get_ligature          (halfword f, int lc, int rc);
extern int           tex_new_font              (void);
extern int           tex_new_font_id           (void);
extern void          tex_font_malloc_charinfo  (halfword f, int num);
extern void          tex_char_malloc_mathinfo  (charinfo *ci);
extern void          tex_dump_font_data        (dumpstream f);
extern void          tex_undump_font_data      (dumpstream f);
extern void          tex_create_null_font      (void);
extern void          tex_delete_font           (int id);
extern int           tex_read_font_info        (char *cnom, scaled s);
extern int           tex_fix_expand_value      (halfword f, int e);

extern halfword      tex_handle_glyphrun       (halfword head, halfword group, halfword direction);
extern halfword      tex_handle_ligaturing     (halfword head, halfword tail);
extern halfword      tex_handle_kerning        (halfword head, halfword tail);

extern void          tex_set_cur_font          (halfword g, halfword f);
extern int           tex_tex_def_font          (int a);

extern void          tex_char_warning          (halfword f, int c);

extern void          tex_initialize_fonts      (void);

extern void          tex_set_font_name         (halfword f, const char *s);
extern void          tex_set_font_original     (halfword f, const char *s);

extern scaled        tex_get_math_font_scale   (halfword f, halfword size);

extern void          tex_run_font_spec         (void);

# endif
