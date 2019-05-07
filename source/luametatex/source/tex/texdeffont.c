/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    When the user defines |\font\f|, say, \TEX\ assigns an internal number to the
    user's font |\f|. Adding this number to |font_id_base| gives the |eqtb|
    location of a \quote {frozen} control sequence that will always select the
    font.

    The variable |a| in the following code indicates the global nature of the
    value to be set. It's used in the |define| macro. Here we're never global.

    There's not much scanner code here because the other scanners are defined
    where they make most sense.

*/

void set_cur_font(internal_font_number f)
{
    int a = 0;
    define(cur_font_loc, data_cmd, f);
}

/*tex This prints a scaled real, rounded to five digits. */

static char *scaled_to_string(scaled s)
{
    static char result[16];
    int k = 0;
    /*tex The amount of allowable inaccuracy: */
    scaled delta;
    if (s < 0) {
        /*tex Only print the sign, if negative */
        result[k++] = '-';
        s = -s;
    }
    {
        int l = 0;
        char digs[8] = { 0 };
        int n = s / unity;
        /*tex Process the integer part: */
        do {
            digs[l++] = (char) (n % 10);
            n = n / 10;;
        } while (n > 0);
        while (l > 0) {
            result[k++] = (char) (digs[--l] + '0');
        }
    }
    result[k++] = '.';
    s = 10 * (s % unity) + 5;
    delta = 10;
    do {
        if (delta > unity) {
            /*tex Round the last digit: */
            s = s + 0100000 - 050000;
        }
        result[k++] = (char) ('0' + (s / unity));
        s = 10 * (s % unity);
        delta = delta * 10;
    } while (s > delta);
    result[k] = 0;
    return (char *) result;
}

/*tex

    Because we do fonts in \LUA\ we can decide to drop this one and assume
    a definition using the token scanner. It also avoids the filename (split)
    mess.

*/

void tex_def_font(int a)
{
    /*tex The user's font identifier. */
    halfword u;
    /*tex This runs through existing fonts. */
    internal_font_number f;
    /*tex The name for the frozen font identifier. */
    str_number t, d;
    /*tex Stated `at' size, or negative of scaled magnification. */
    scaled s = -1000;
    char *fn;
    if (fileio_state.job_name == NULL) {
        /*tex Avoid confusing |texput| with the font name. */
        open_log_file();
    }
    get_r_token();
    u = cur_cs;
    if (a >= 4) {
        geq_define(u, set_font_cmd, null_font);
    } else {
        eq_define(u, set_font_cmd, null_font);
    }
    fn = read_file_name(1,NULL,NULL);
    /*tex
        Scan the font size specification.
    */
    fileio_state.name_in_progress = 1;
    if (scan_keyword("at")) {
        /*tex Put the positive 'at' size into |s|. */
        scan_normal_dimen(0);
        s = cur_val;
        if ((s <= 0) || (s >= 01000000000)) {
            char msg[256];
            snprintf(msg, 255, "Improper `at' size (%spt), replaced by 10pt", scaled_to_string(s));
            tex_error(
                msg,
                "I can only handle fonts at positive sizes that are\n"
                "less than 2048pt, so I've changed what you said to 10pt."
            );
            s = 10 * unity;
        }
    } else if (scan_keyword("scaled")) {
        scan_int(0);
        s = -cur_val;
        if ((cur_val <= 0) || (cur_val > 32768)) {
            char msg[256];
            snprintf(msg, 255, "Illegal magnification has been changed to 1000 (%d)", (int) cur_val);
            tex_error(
                msg,
                "The magnification ratio must be between 1 and 32768."
            );
            s = -1000;
        }
    }
    fileio_state.name_in_progress = 0;
    f = read_font_info(fn, s);
    free(fn);
    equiv(u) = f;
    eqtb[font_id_base + f] = eqtb[u];
    /*tex

        This is tricky: when we redefine a string we loose the old one. So this
        will change as it's only used to display the |\fontname| so we can store
        that with the font.

    */
    d = cs_text(font_id_base + f);
    t = (u >= null_cs) ? cs_text(u) : maketexstring("FONT");
    if (!d) {
        /*tex We have a new string. */
        cs_text(font_id_base + f) = t;
    } else if (t == d){
        /*tex There is no change. */
    } else if (str_eq_str(d,t)){
        /*tex We have the same string. */
        flush_str(t);
    } else {
        d = search_string(t);
        if (d && d != t) {
            /*tex We have already such a string. */
            cs_text(font_id_base + f) = d;
            flush_str(t);
        } else {
            /*tex The old value is lost but still in the pool. */
            cs_text(font_id_base + f) = t;
        }
    }
}
