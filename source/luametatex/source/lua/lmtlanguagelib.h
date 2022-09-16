/*
    See license.txt in the root of this project.
*/

# ifndef LLANGUAGELIB_H
# define LLANGUAGELIB_H

extern void lmt_initialize_languages (void);

extern int  lmt_handle_word (
    tex_language *lang,
    const char   *original,
    const char   *word,
    int           length,
    halfword      first,
    halfword      last,
    char        **replacement
);

# endif
