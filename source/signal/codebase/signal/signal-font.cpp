/*
    See license.txt in the root of this project.
*/

# include <cstddef>
# include <signal-common.h>

static const char *hans_letters[128] = {
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    /* digits */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    /* */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    /* uppercase */
    "++++++!!++-----++!!+++++", // A
    "+-----!!+++++++++!!+++++", // B
    "+++------+++++++++++++++", // C
    "++++++!!+++++++++!!-----", // D
    "++++++!!---++++++!!+++++", // E
    "++++--!!---++++++!!+++++", // F
    "+++---!!+++++++++!!+++++", // G
    "--++++!!+++---+++!!++++-", // H
    "++--+++++++++++---------", // I
    "+++++++++++++++---------", // J
    "--!!-----!!--++++!!+++++", // K
    "+--------+++++++++++++++", // L
    "-!!+++++++-!!!-+++++++!!", // M
    "++++++++++-----+++++++++", // N
    "++++++++++++++++++++++++", // O
    "++++++!!----+++++!!+++++", // P
    "++++++++!!++++++++++++++", // Q
    "++++++!!--!!+++++!!+++++", // R
    "++++--!!+++++++--!!+++++", // S
    "!!+++------!!!------+++!", // T
    "---+++++++++++++++++++--", // U
    "---!!+++++++++++++++!!--", // V
    "---!!++++++!!!++++++!!--", // W
    "-+++-----+++--+++----+++", // X
    "---+++-----+++-----+++--", // Y
    "++++++!!--+++++++!!--+++", // Z
    /* */
    NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
};

const char * signal_character_get(int c)
{
    return c >= 0 && c <= 127 ? hans_letters[c] : NULL;
}

static const char *hans_digits_top[10] = {
    "------------------------",
    "+-----------------------",
    "-+---------------------+",
    "++---------------------+",
    "-++-------------------++",
    "+++-------------------++",
    "-+++-----------------+++",
    "++++-----------------+++",
    "-++++---------------++++",
    "+++++---------------++++",
}; 

static const char *hans_digits_bottom[10] = {
    "------------------------",
    "------------+-----------",
    "-----------+-+----------",
    "-----------+++----------",
    "----------++-++---------",
    "----------+++++---------",
    "---------+++-+++--------",
    "---------+++++++--------",
    "--------++++-++++-------",
    "--------+++++++++-------",
};

const char * signal_digit_get_top(int c)
{
    return c >= 0 && c <= 9 ? hans_digits_top[c] : NULL;
}

const char * signal_digit_get_bottom(int c)
{
    return c >= 0 && c <= 9 ? hans_digits_bottom[c] : NULL;
}

int signal_font_supported(void)
{
    return signal_configuration->geometry == signal_geometry_circular && signal_configuration->nofleds == 24;
}