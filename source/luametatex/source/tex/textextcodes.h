/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXTCODES_H
# define LMT_TEXTCODES_H

/*tex
    For practical reasons we handle the hmcodes here although they are used in 
    math only. We could have used the hc codes as there will be no overlap. 
*/

extern void     tex_set_cat_code               (int h, int n, halfword v, int gl);
extern halfword tex_get_cat_code               (int h, int n);
extern int      tex_valid_catcode_table        (int h);
extern void     tex_unsave_cat_codes           (int h, int gl);
extern void     tex_copy_cat_codes             (int from, int to);
extern void     tex_initialize_cat_codes       (int h);
/*     void     tex_set_cat_code_table_default (int h, int dflt); */
/*     int      tex_get_cat_code_table_default (int h); */

extern void     tex_set_lc_code                (int n, halfword v, int gl);
extern halfword tex_get_lc_code                (int n);
extern void     tex_set_uc_code                (int n, halfword v, int gl);
extern halfword tex_get_uc_code                (int n);
extern void     tex_set_sf_code                (int n, halfword v, int gl);
extern halfword tex_get_sf_code                (int n);
extern void     tex_set_hc_code                (int n, halfword v, int gl);
extern halfword tex_get_hc_code                (int n);
extern void     tex_set_hm_code                (int n, halfword v, int gl);
extern halfword tex_get_hm_code                (int n);
extern void     tex_set_am_code                (int n, halfword v, int gl);
extern halfword tex_get_am_code                (int n);
extern void     tex_set_hj_code                (int l, int n, halfword v, int gl);
extern halfword tex_get_hj_code                (int l, int n);
extern void     tex_initialize_xx_codes        (void);

extern void     tex_hj_codes_from_lc_codes     (int h);

extern void     tex_initialize_text_codes      (void);
extern void     tex_unsave_text_codes          (int grouplevel);

extern void     tex_dump_text_codes            (dumpstream f);
extern void     tex_undump_text_codes          (dumpstream f);

extern void     tex_dump_language_hj_codes     (dumpstream f, int h);
extern void     tex_undump_language_hj_codes   (dumpstream f, int h);

extern void     tex_free_text_codes            (void);

# endif
