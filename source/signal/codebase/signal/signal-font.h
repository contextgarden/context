/*
    See license.txt in the root of this project.
*/

# ifndef SIGNAL_FONT_H
# define SIGNAL_FONT_H

const char * signal_character_get    (int c);
const char * signal_digit_get_top    (int c);
const char * signal_digit_get_bottom (int c);
int          signal_font_supported   (void);

# endif 