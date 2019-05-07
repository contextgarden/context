/*
    See license.txt in the root of this project.
*/

# ifndef LLANGLIB_H
# define LLANGLIB_H

void load_tex_patterns(int curlang, halfword head);
void load_tex_hyphenation(int curlang, halfword head);

extern halfword new_ligkern(halfword head, halfword tail);
extern halfword handle_ligaturing(halfword head, halfword tail);
extern halfword handle_kerning(halfword head, halfword tail);

# endif
