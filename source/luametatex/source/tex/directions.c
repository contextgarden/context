/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

dir_state_info dir_state;

/*tex

    The next two are used by |postlinebreak.c|; they could be macros.

*/

halfword do_push_dir_node(halfword p, halfword a)
{
    halfword n = copy_node(a);
    vlink(n) = p;
    return n;
}

halfword do_pop_dir_node(halfword p)
{
    halfword n = vlink(p);
    flush_node(p);
    return n;
}

void initialize_directions(void)
{
    /*tex There is no need to do anything here at the moment. */
}

halfword new_dir(int subtype, int direction)
{
    halfword p = new_node(dir_node, subtype);
    dir_dir(p) = direction;
    dir_level(p) = cur_level;
    return p;
}

void update_text_dir_ptr(int val)
{
    if (dir_level(text_dir_ptr) == cur_level) {
        /*tex update */
        dir_dir(text_dir_ptr) = val;
    } else {
        /*tex addition */
        halfword text_dir_tmp = new_dir(normal_dir,val);
        vlink(text_dir_tmp) = text_dir_ptr;
        text_dir_ptr = text_dir_tmp;
    }
}

# define valid_dir(d) ((d>=0) && (d<=3))

/*tex We could make these macros. */

static void set_text_or_line_dir(int d, int check_glue)
{
    inject_text_or_line_dir(d,check_glue);
    eq_word_define(int_base + text_direction_code, d);
    eq_word_define(int_base + no_local_dirs_code, no_local_dirs_par + 1);
}

void set_math_dir(int d)
{
    if (valid_dir(d)) {
        eq_word_define(int_base + math_direction_code, d);
    }
}

void set_par_dir(int d)
{
    if (valid_dir(d)) {
        eq_word_define(int_base + par_direction_code, d);
    }
}

void set_text_dir(int d)
{
    if (valid_dir(d)) {
        set_text_or_line_dir(d,0);
    }
}

void set_line_dir(int d)
{
    if (valid_dir(d)) {
        set_text_or_line_dir(d,1);
    }
}

void set_box_dir(int b, int d)
{
    if (valid_dir(d)) {
        box_dir(box(b)) = (quarterword) d;
    }
}
