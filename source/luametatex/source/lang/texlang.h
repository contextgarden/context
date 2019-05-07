/*
    See license.txt in the root of this project.
*/

# ifndef TEXLANG_H
# define TEXLANG_H

# define MAX_WORD_LEN      8192  /*tex We had 65536 but that is over the top. */
# define MAX_TEX_LANGUAGES 8192  /*tex We had 16384 but even 8K is more than there are languages. */

typedef struct _lang_variables {
    int pre_hyphen_char;
    int post_hyphen_char;
    int pre_exhyphen_char;
    int post_exhyphen_char;
} lang_variables;

/*tex this is used in: */

# include "lang/hyphen.h"

struct tex_language {
    HyphenDict *patterns;
    int exceptions;
    int id;
    int pre_hyphen_char;
    int post_hyphen_char;
    int pre_exhyphen_char;
    int post_exhyphen_char;
    int hyphenation_min;
};

extern struct tex_language *new_language(int n);
extern struct tex_language *get_language(int n);
extern void load_patterns(struct tex_language *lang, const unsigned char *buf);
extern void load_hyphenation(struct tex_language *lang, const unsigned char *buf);
extern int hyphenate_string(struct tex_language *lang, char *w, char **ret);

extern void new_hyphenation(halfword h, halfword t);
extern void clear_patterns(struct tex_language *lang);
extern void clear_hyphenation(struct tex_language *lang);
extern const char *clean_hyphenation(int id, const char *buffer, char **cleaned);
extern void hnj_hyphenation(halfword head, halfword tail);

extern void set_pre_hyphen_char(int lan, int val);
extern void set_post_hyphen_char(int lan, int val);
extern int get_pre_hyphen_char(int lan);
extern int get_post_hyphen_char(int lan);

extern void set_pre_exhyphen_char(int lan, int val);
extern void set_post_exhyphen_char(int lan, int val);
extern int get_pre_exhyphen_char(int lan);
extern int get_post_exhyphen_char(int lan);

extern void set_hyphenation_min(int lan, int val);
extern int get_hyphenation_min(int lan);

extern void dump_language_data(void);
extern void undump_language_data(void);
extern char *exception_strings(struct tex_language *lang);

extern void new_hyph_exceptions(void);
extern void new_patterns(void);
extern void new_pre_hyphen_char(void);
extern void new_post_hyphen_char(void);
extern void new_pre_exhyphen_char(void);
extern void new_post_exhyphen_char(void);
extern void new_hyphenation_min(void);
extern void new_hj_code(void);

extern void set_disc_field(halfword f, halfword t);
extern halfword insert_syllable_discretionary(halfword t, lang_variables * lan);

# endif
