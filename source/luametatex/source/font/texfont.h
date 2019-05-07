/*
    See license.txt in the root of this project.
*/

# ifndef TEXFONT_H
# define TEXFONT_H

# define null_font 0

/*tex

    Some of these are dumped en block, so they need endianness tests. Well,
    we don't dump anything so we can do without that test.

*/

typedef struct liginfo {
    int type;
    int lig;
    int adj;
} liginfo;

typedef struct kerninfo {
    int sc;
    int adj;
} kerninfo;

/*tex The next record relates to opentype math extensibles. */

typedef struct extinfo {
    struct extinfo *next;
    int glyph;
    int start_overlap;
    int end_overlap;
    int advance;
    int extender;
} extinfo;

/*tex

    We only store what we need for basic ligaturing and kerning, math rendering,
    and par building which includes protrusion and expansion.

*/

typedef struct charinfo {
    scaled width;
    scaled height;
    scaled depth;
    scaled italic;
    /*tex protrusion and expansion */
    int ef;
    int lp;
    int rp;
    /*tex traditional tex ligaturing and kerning */
    liginfo *ligatures;
    kerninfo *kerns;
    /*tex used in ligature and math extensibles (these could be shorts but we live in lua int space anyway). */
    int tag;
    int remainder;
    /*tex opentype math specific  */
    scaled vert_italic;
    scaled top_accent;
    scaled bot_accent;
    extinfo *hor_variants;
    extinfo *vert_variants;
    int top_left_math_kerns;
    int top_right_math_kerns;
    int bottom_right_math_kerns;
    int bottom_left_math_kerns;
    scaled *top_left_math_kern_array;
    scaled *top_right_math_kern_array;
    scaled *bottom_right_math_kern_array;
    scaled *bottom_left_math_kern_array;
} charinfo;

# define char_vert_variants_from_font(f,c) (char_info(f,c)->vert_variants != NULL ? char_info(f,c)->vert_variants : NULL)
# define char_hor_variants_from_font(f,c) (char_info(f,c)->hor_variants != NULL ? char_info(f,c)->hor_variants : NULL)

extern void set_charinfo_hor_variants(charinfo * ci, extinfo * ext);
extern void set_charinfo_vert_variants(charinfo * ci, extinfo * ext);
extern void add_charinfo_vert_variant(charinfo * ci, extinfo * ext);
extern void add_charinfo_hor_variant(charinfo * ci, extinfo * ext);

extern extinfo *new_variant(int glyph, int startconnect, int endconnect, int advance, int repeater);

/*tex

    For a font instance we only store the bits that are used by the engine
    itself. Of course more data can (and normally will be) be kept at the \TEX\
    cq.\ \LUA\ end. The fields preceded by a \type {_} are used for internal
    for housekeeping.

*/

typedef struct texfont {
    /*tex (design)size used in messages */
    int font_size;
    int font_dsize;
    /*tex (file)name used in messages */
    char *font_name;
    /*tex the range of (allocated) characters */
    int font_bc;
    int font_ec;
    /*tex some protection against abuse */
    int font_touched;
    /*tex default to false when MathConstants seen */
    int font_oldmath;
    /*tex expansion */
    int font_max_shrink;
    int font_max_stretch;
    int font_step;
    /*tex special characters, see \TEX book */
    int hyphen_char;
    int skew_char;
    /*tex also special */
    charinfo *left_boundary;
    charinfo *right_boundary;
    /*tex all parameters, although only some are used */
    int font_params;
    scaled *param_base;
    /*tex all math parameters */
    int font_math_params;
    scaled *math_param_base;
    /*tex the (sparse) character (glyph) array */
    sa_tree characters;
    int charinfo_count;
    int charinfo_size;
    charinfo *charinfo;
    /*tex a flag */
    int ligatures_disabled;
} texfont;

typedef struct font_state_info {
    texfont **font_tables;
    int font_bytes;
    int font_arr_max;
    int font_id_maxval;
} font_state_info ;

extern font_state_info font_state;

# define font_size(a)        font_state.font_tables[a]->font_size
# define set_font_size(a,b)  font_size(a) = b
# define font_dsize(a)       font_state.font_tables[a]->font_dsize
# define set_font_dsize(a,b) font_dsize(a) = b

# define font_name(a)        font_state.font_tables[a]->font_name
# define get_font_name(a)    (unsigned char *)font_name(a)
# define set_font_name(f,b)  font_name(f) = b

# define font_reassign(a,b)        { if (a!=NULL) free(a); a = b; }

# define font_bc(a)                font_state.font_tables[a]->font_bc
# define set_font_bc(f,b)          font_bc(f) = b

# define font_ec(a)                font_state.font_tables[a]->font_ec
# define set_font_ec(f,b)          font_ec(f) = b

# define font_touched(a)           font_state.font_tables[a]->font_touched
# define set_font_touched(a)       font_touched(a) = 1

# define font_oldmath(a)           font_state.font_tables[a]->font_oldmath
# define set_font_oldmath(a,b)     font_oldmath(a) = b

# define font_shrink(a)            font_state.font_tables[a]->_font_shrink
# define set_font_shrink(a,b)      font_shrink(a) = b

# define font_stretch(a)           font_state.font_tables[a]->_font_stretch
# define set_font_stretch(a,b)     font_stretch(a) = b

# define font_max_shrink(a)        font_state.font_tables[a]->font_max_shrink
# define set_font_max_shrink(a,b)  font_max_shrink(a) = b

# define font_max_stretch(a)       font_state.font_tables[a]->font_max_stretch
# define set_font_max_stretch(a,b) font_max_stretch(a) = b

# define font_step(a)              font_state.font_tables[a]->font_step
# define set_font_step(a,b)        font_step(a) = b

# define hyphen_char(a)            font_state.font_tables[a]->hyphen_char
# define set_hyphen_char(a,b)      hyphen_char(a) = b

# define skew_char(a)              font_state.font_tables[a]->skew_char
# define set_skew_char(a,b)        skew_char(a) = b

# define left_boundarychar         -1
# define right_boundarychar        -2
# define non_boundarychar          -3

/*tex These are pointers, so: |NULL|  */

# define left_boundary(a)          font_state.font_tables[a]->left_boundary
# define has_left_boundary(a)      (left_boundary(a)!=NULL)
# define set_left_boundary(a,b)    font_reassign(left_boundary(a),b)

# define right_boundary(a)         font_state.font_tables[a]->right_boundary
# define has_right_boundary(a)     (right_boundary(a)!=NULL)
# define set_right_boundary(a,b)   font_reassign(right_boundary(a),b)

# define font_bchar(a)             (right_boundary(a)!=NULL ? right_boundarychar : non_boundarychar)

/*tex Font parameters: */

# define font_params(a)       font_state.font_tables[a]->font_params
# define param_base(a)        font_state.font_tables[a]->param_base
# define font_param(a,b)      font_state.font_tables[a]->param_base[b]

# define font_math_params(a)  font_state.font_tables[a]->font_math_params
# define math_param_base(a)   font_state.font_tables[a]->math_param_base
# define font_math_param(a,b) font_state.font_tables[a]->math_param_base[b]

# define set_font_param(f,n,b) { \
    if (font_params(f)<n) \
        set_font_params(f,n); \
    font_param(f,n) = b; \
}

# define set_font_math_param(f,n,b) { \
    if (font_math_params(f)<n) \
        set_font_math_params(f,n); \
    font_math_param(f,n) = b; \
}

extern void set_font_params(internal_font_number f, int b);
extern void set_font_math_params(internal_font_number f, int b);

/*tex Font parameters are sometimes referred to as |slant(f)|, |space(f)|, etc. */

typedef enum {
    slant_code = 1,
    space_code = 2,
    space_stretch_code = 3,
    space_shrink_code = 4,
    x_height_code = 5,
    quad_code = 6,
    extra_space_code = 7
} font_parameter_codes;

# define slant(f)         font_param(f,slant_code)
# define space(f)         font_param(f,space_code)
# define space_stretch(f) font_param(f,space_stretch_code)
# define space_shrink(f)  font_param(f,space_shrink_code)
# define x_height(f)      font_param(f,x_height_code)
# define quad(f)          font_param(f,quad_code)
# define extra_space(f)   font_param(f,extra_space_code)

/*tex Characters: */

typedef enum {
    top_right_kern = 1,
    bottom_right_kern = 2,
    bottom_left_kern = 3,
    top_left_kern = 4
} font_math_kern_codes;

extern charinfo *get_charinfo(internal_font_number f, int c);
extern int char_exists(internal_font_number f, int c);
extern charinfo *char_info(internal_font_number f, int c);

/*tex

    Here is a quick way to test if a glyph exists, when you are already certain
    the font |f| exists, and that the |c| is a regular glyph id, not one of the
    two special boundary objects.

*/

# define quick_char_exists(f,c) (get_sa_item(font_state.font_tables[f]->characters,c).int_value)

/*tex

    Not all setters and getters need to be public but for consistency we all
    treat them the same.

*/

# define set_charinfo_width(ci,val) ci->width  = val;
# define set_charinfo_height(ci,val) ci->height = val;
# define set_charinfo_depth(ci,val) ci->depth  = val;
# define set_charinfo_italic(ci,val) ci->italic = val;
# define set_charinfo_vert_italic(ci,val) ci->vert_italic = val;
# define set_charinfo_top_accent(ci,val) ci->top_accent = val;
# define set_charinfo_bot_accent(ci,val) ci->bot_accent = val;
# define set_charinfo_tag(ci,val) ci->tag = val;
# define set_charinfo_remainder(ci,val) ci->remainder = val;
# define set_charinfo_ef(ci,val) ci->ef = val;
# define set_charinfo_lp(ci,val) ci->lp = val;
# define set_charinfo_rp(ci,val) ci->rp = val;

# define set_charinfo_ligatures(ci,val) do { free(ci->ligatures); ci->ligatures = val; } while (0)
# define set_charinfo_kerns(ci,val)     do { free(ci->kerns); ci->kerns = val; } while (0)

extern void set_charinfo_extensible(charinfo * ci, int a, int b, int c, int d);
extern void add_charinfo_math_kern(charinfo * ci, int type, scaled ht, scaled krn);
extern int  get_charinfo_math_kerns(charinfo * ci, int id);

# define char_width_from_font(f,c) char_info(f,c)->width
# define char_height_from_font(f,c) char_info(f,c)->height
# define char_depth_from_font(f,c) char_info(f,c)->depth
# define char_italic_from_font(f,c) char_info(f,c)->italic
# define char_vert_italic_from_font(f,c) char_info(f,c)->italic
# define char_ef_from_font(f,c) char_info(f,c)->ef
# define char_lp_from_font(f,c) char_info(f,c)->lp
# define char_rp_from_font(f,c) char_info(f,c)->rp
# define char_top_accent_from_font(f,c) char_info(f,c)->top_accent
# define char_bot_accent_from_font(f,c) char_info(f,c)->bot_accent
# define char_tag_from_font(f,c) char_info(f,c)->tag
# define char_remainder_from_font(f,c) char_info(f,c)->remainder

extern int get_charinfo_extensible(charinfo * ci, int which);

# define set_ligature_item(f,b,c,d) { f.type = b; f.adj = c; f.lig = d; }
# define set_kern_item(f,b,c) { f.adj = b; f.sc = c; }

/* Kerns: the |otherchar| value signals \quote {stop}. */

# define end_kern 0x7FFFFF

# define charinfo_kern(b,c) b->kerns[c]

# define kern_char(b)     (b).adj
# define kern_kern(b)     (b).sc
# define kern_end(b)      ((b).adj == end_kern)
# define kern_disabled(b) ((b).adj > end_kern)

/* Ligatures: the |otherchar| value signals \quote {stop}. */

# define end_ligature 0x7FFFFF

# define charinfo_ligature(b,c) b->ligatures[c]

# define is_valid_ligature(a)   ((a).type != 0)
# define lig_type(a)            ((a).type >> 1)
# define lig_char(a)            (a).adj
# define lig_replacement(a)     (a).lig
# define lig_end(a)             (lig_char(a) == end_ligature)
# define lig_disabled(a)        (lig_char(a) > end_ligature)

/* Remainders and related flags: */

# define EXT_NORMAL 0
# define EXT_REPEAT 1

# define EXT_TOP 0
# define EXT_BOT 1
# define EXT_MID 2
# define EXT_REP 3

/* Tags: */

# define no_tag   0 /*tex vanilla character */
# define lig_tag  1 /*tex character has a ligature/kerning program */
# define list_tag 2 /*tex character has a successor in a charlist */
# define ext_tag  3 /*tex character is extensible */

# define calc_char_width(f,c,ex) \
    ((ex) ? round_xn_over_d(char_width_from_font(f,c),1000+ex,1000) : char_width_from_font(f,c))

# define has_lig(f,b)  (char_exists(f,b) && (char_info(f,b)->ligatures != NULL))
# define has_kern(f,b) (char_exists(f,b) && (char_info(f,b)->kerns != NULL))

int raw_get_kern(internal_font_number f, int lc, int rc);
int get_kern(internal_font_number f, int lc, int rc);
liginfo get_ligature(internal_font_number f, int lc, int rc);

int new_font(void);
int new_font_id(void);

extern void font_malloc_charinfo(internal_font_number f, int num);

int max_font_id(void);
void set_max_font_id(int id);

void create_null_font(void);
void delete_font(int id);

int is_valid_font(int id);

# define set_lpcode_in_font(f,c,i) if (char_exists(f,c)) char_info(f,c)->lp = i;
# define set_rpcode_in_font(f,c,i) if (char_exists(f,c)) char_info(f,c)->rp = i;
# define set_efcode_in_font(f,c,i) if (char_exists(f,c)) char_info(f,c)->ef = i;

extern int read_font_info(char *cnom, scaled s);

extern int  fix_expand_value(internal_font_number f, int e);
extern void set_expand_params(internal_font_number f, int stretch_limit, int shrink_limit, int font_step);

extern void l_set_font_data(void);

# endif
