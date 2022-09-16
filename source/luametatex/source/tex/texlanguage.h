/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXLANG_H
# define LMT_TEXLANG_H

/*tex We resolve the properties beforehand and store them in a struct. */

typedef struct language_state_info {
    struct tex_language **languages;
    memory_data           language_data;
    lua_Integer           handler_table_id;
    int                   handler_count;
} language_state_info;

extern language_state_info lmt_language_state;

typedef struct lang_variables {
    halfword pre_hyphen_char;
    halfword post_hyphen_char;
    halfword pre_exhyphen_char;
    halfword post_exhyphen_char;
} lang_variables;

/*tex This is used in: */

typedef struct tex_language {
    halfword        pre_hyphen_char;
    halfword        post_hyphen_char;
    halfword        pre_exhyphen_char;
    halfword        post_exhyphen_char;
    halfword        hyphenation_min;
    halfword        id;
    hjn_dictionary *patterns;
    int             exceptions;
    int             wordhandler;
    sa_tree         hjcode_head;
} tex_language;

extern tex_language *tex_new_language           (halfword n);
extern tex_language *tex_get_language           (halfword n);
/*     void          tex_free_languages         (void); */

extern void          tex_load_patterns          (struct tex_language *lang, const unsigned char *buf);
extern void          tex_load_hyphenation       (struct tex_language *lang, const unsigned char *buf);

extern void          tex_handle_hyphenation     (halfword h, halfword t);
extern void          tex_clear_patterns         (struct tex_language *lang);
extern void          tex_clear_hyphenation      (struct tex_language *lang);
extern const char   *tex_clean_hyphenation      (halfword id, const char *buffer, char **cleaned);

extern void          tex_hyphenate_list         (halfword head, halfword tail);
extern int           tex_collapse_list          (halfword head, halfword c1, halfword c2, halfword c3);

extern void          tex_set_pre_hyphen_char    (halfword lan, halfword val);
extern void          tex_set_post_hyphen_char   (halfword lan, halfword val);
extern halfword      tex_get_pre_hyphen_char    (halfword lan);
extern halfword      tex_get_post_hyphen_char   (halfword lan);

extern void          tex_set_pre_exhyphen_char  (halfword lan, halfword val);
extern void          tex_set_post_exhyphen_char (halfword lan, halfword val);
extern halfword      tex_get_pre_exhyphen_char  (halfword lan);
extern halfword      tex_get_post_exhyphen_char (halfword lan);

extern void          tex_set_hyphenation_min    (halfword lan, halfword val);
extern halfword      tex_get_hyphenation_min    (halfword lan);

extern void          tex_dump_language_data     (dumpstream f);
extern void          tex_undump_language_data   (dumpstream f);

/*     char         *tex_get_exception_strings  (struct tex_language *lang); */

extern void          tex_load_tex_patterns      (halfword curlang, halfword head);
extern void          tex_load_tex_hyphenation   (halfword curlang, halfword head);

extern void          tex_initialize_languages   (void);
extern int           tex_is_valid_language      (halfword n);

extern halfword      tex_glyph_to_discretionary (halfword glyph, quarterword code, int keepkern);

/*
void tex_hnj_hyphen_hyphenate(
    HyphenDict     *dict,
    halfword        first,
    halfword        last,
    int             size,
    halfword        left,
    halfword        right,
    lang_variables *lan
);
*/

# endif
