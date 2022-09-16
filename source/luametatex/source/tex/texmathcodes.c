/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    We support the traditional math codes as well as larger ones suitable for \UNICODE\ input and
    fonts.

*/

/*tex the |0xFFFFFFFF| is a flag value. */

# define MATHCODESTACK   8
# define MATHCODEDEFAULT 0xFFFFFFFF
# define MATHCODEACTIVE  0xFFFFFFFE

/*tex Delcodes are also went larger. */

# define DELCODESTACK   4
# define DELCODEDEFAULT 0xFFFFFFFF

typedef struct mathcode_state_info {
    sa_tree mathcode_head;
    sa_tree delcode_head;
} mathcode_state_info;

static mathcode_state_info lmt_mathcode_state = {
    .mathcode_head = NULL,
    .delcode_head  = NULL,
};

/*tex

    We now get lots of helpers for definitions and printing. The storage model that we use is
    different because we can have many more so we need to be sparse. Therefore we use trees.

*/

# define print_hex_digit_one(A) do { \
    if ((A) >= 10) { \
        tex_print_char('A' + (A) - 10); \
    } else { \
        tex_print_char('0' + (A)); \
    } \
} while (0)

# define print_hex_digit_two(A) do { \
    print_hex_digit_one((A) / 16); \
    print_hex_digit_one((A) % 16); \
} while (0)

# define print_hex_digit_four(A) do { \
    print_hex_digit_two((A) / 256); \
    print_hex_digit_two((A) % 256); \
} while (0)

# define print_hex_digit_six(A) do { \
    print_hex_digit_two( (A) / 65536); \
    print_hex_digit_two(((A) % 65536) / 256); \
    print_hex_digit_two( (A)          % 256); \
} while (0)

/* 0xFFFFF is plenty for math */

mathcodeval tex_mathchar_from_integer(int value, int extcode)
{
    mathcodeval mval;
    if (extcode == tex_mathcode) {
        mval.class_value = math_old_class_part(value);
        mval.family_value = math_old_family_part(value);
        mval.character_value = math_old_character_part(value);
    } else {
        mval.class_value = math_class_part(value);
        mval.family_value = math_family_part(value);
        mval.character_value = math_character_part(value);
    }
    return mval;
}

mathcodeval tex_mathchar_from_spec(int value)
{
    mathcodeval mval = { 0, 0, 0 };
    if (value) {
        mval.class_value = math_spec_class(value);
        mval.family_value = math_spec_family(value);
        mval.character_value = math_spec_character(value);
    }
    return mval;
}

void tex_show_mathcode_value(mathcodeval mval, int extcode)
{
    tex_print_char('"');
    if (extcode == tex_mathcode) {
        print_hex_digit_one(math_old_class_mask(mval.class_value));
        print_hex_digit_one(math_old_family_mask(mval.family_value));
        print_hex_digit_two(math_old_character_mask(mval.character_value));
    } else {
        print_hex_digit_two(mval.class_value);
        tex_print_char('"');
        print_hex_digit_two(mval.family_value);
        tex_print_char('"');
        print_hex_digit_six(mval.character_value);
    }
}

static void tex_aux_show_mathcode(int n)
{
    mathcodeval mval = tex_get_math_code(n);
    tex_print_str_esc("Umathcode");
    tex_print_int(n);
    tex_print_char('=');
    tex_show_mathcode_value(mval, umath_mathcode);
}

static void tex_aux_unsave_mathcode(int level)
{
    if (lmt_mathcode_state.mathcode_head->stack) {
        while (lmt_mathcode_state.mathcode_head->sa_stack_ptr > 0 && abs(lmt_mathcode_state.mathcode_head->stack[lmt_mathcode_state.mathcode_head->sa_stack_ptr].level) >= level) {
            sa_stack_item item = lmt_mathcode_state.mathcode_head->stack[lmt_mathcode_state.mathcode_head->sa_stack_ptr];
            if (item.level > 0) {
                sa_rawset_item_4(lmt_mathcode_state.mathcode_head, item.code, item.value_1);
                if (tracing_restores_par > 1) {
                    tex_begin_diagnostic();
                    tex_print_str("{restoring ");
                    tex_aux_show_mathcode(item.code);
                    tex_print_char('}');
                    tex_end_diagnostic();
                }
            }
            (lmt_mathcode_state.mathcode_head->sa_stack_ptr)--;
        }
    }
}

mathcodeval tex_no_math_code(void)
{
    return (mathcodeval) { 0, 0, 0 };
}

void tex_set_math_code(int n, mathcodeval v, int level)
{
    sa_tree_item item;
    if (v.class_value == active_math_class_value && v.family_value == 0 && v.character_value == 0) {
        item.uint_value = MATHCODEACTIVE;
    } else if (v.class_value == 0 && v.family_value == 0) {
        /*tex This is rather safe because we don't decide on it. */
        item.uint_value = MATHCODEDEFAULT;
    } else {
        item.math_code_value.class_value = v.class_value;
        item.math_code_value.family_value = v.family_value;
        item.math_code_value.character_value = v.character_value;
    }
    sa_set_item_4(lmt_mathcode_state.mathcode_head, n, item, level);
    if (tracing_assigns_par > 1) {
        tex_begin_diagnostic();
        tex_print_str("{assigning ");
        tex_aux_show_mathcode(n);
        tex_print_char('}');
        tex_end_diagnostic();
    }
}

mathcodeval tex_get_math_code(int n)
{
    sa_tree_item item = sa_get_item_4(lmt_mathcode_state.mathcode_head, n);
    mathcodeval m = { 0, 0, 0 };
    if (item.uint_value == MATHCODEDEFAULT) {
        m.character_value = n;
    } else if (item.uint_value == MATHCODEACTIVE) {
        m.class_value = active_math_class_value;
    } else if (item.math_code_value.class_value == active_math_class_value) {
        m.class_value = active_math_class_value;
        m.character_value = n;
    } else {
        m.class_value = (short) item.math_code_value.class_value;
        m.family_value = (short) item.math_code_value.family_value;
        m.character_value = item.math_code_value.character_value;
    }
    return m;
}

int tex_get_math_code_number(int n) /* should be unsigned */
{
    mathcodeval d = tex_get_math_code(n);
    return math_packed_character(d.class_value, d.family_value, d.character_value);
}

static void tex_aux_initialize_mathcode(void)
{
    lmt_mathcode_state.mathcode_head = sa_new_tree(MATHCODESTACK, 4, (sa_tree_item) { .uint_value = MATHCODEDEFAULT });
}

static void tex_aux_dump_mathcode(dumpstream f)
{
    sa_dump_tree(f, lmt_mathcode_state.mathcode_head);
}

static void tex_aux_undump_mathcode(dumpstream f)
{
    lmt_mathcode_state.mathcode_head = sa_undump_tree(f);
}

static void tex_aux_show_delcode(int n)
{
    delcodeval dval = tex_get_del_code(n);
    tex_print_str_esc("Udelcode");
    tex_print_int(n);
    tex_print_char('=');
    if (tex_has_del_code(dval)) {
        tex_print_char('"');
        print_hex_digit_two(dval.small.family_value);
        print_hex_digit_six(dval.small.character_value);
    } else {
        tex_print_str("-1");
    }
}

static void tex_aux_unsave_delcode(int level)
{
    if (lmt_mathcode_state.delcode_head->stack) {
        while (lmt_mathcode_state.delcode_head->sa_stack_ptr > 0 && abs(lmt_mathcode_state.delcode_head->stack[lmt_mathcode_state.delcode_head->sa_stack_ptr].level) >= level) {
            sa_stack_item item = lmt_mathcode_state.delcode_head->stack[lmt_mathcode_state.delcode_head->sa_stack_ptr];
            if (item.level > 0) {
                sa_rawset_item_8(lmt_mathcode_state.delcode_head, item.code, item.value_1, item.value_2);
                if (tracing_restores_par > 1) {
                    tex_begin_diagnostic();
                    tex_print_str("{restoring ");
                    tex_aux_show_delcode(item.code);
                    tex_print_char('}');
                    tex_end_diagnostic();
                }
            }
            (lmt_mathcode_state.delcode_head->sa_stack_ptr)--;
        }
    }
}

void tex_set_del_code(int n, delcodeval v, int level)
{
    sa_tree_item v1, v2; /* seldom all zero */
    v1.math_code_value.class_value = v.small.class_value;
    v1.math_code_value.family_value = v.small.family_value;
    v1.math_code_value.character_value = v.small.character_value;
    v2.math_code_value.class_value = v.large.class_value;
    v2.math_code_value.family_value = v.large.family_value;
    v2.math_code_value.character_value = v.large.character_value;
    /*tex Always global! */
    sa_set_item_8(lmt_mathcode_state.delcode_head, n, v1, v2, level);
    if (tracing_assigns_par > 1) {
        tex_begin_diagnostic();
        tex_print_str("{assigning ");
        tex_aux_show_delcode(n);
        tex_print_char('}');
        tex_end_diagnostic();
    }
}

int tex_has_del_code(delcodeval d)
{
    return d.small.family_value >= 0;
}

delcodeval tex_no_del_code(void)
{
    return (delcodeval) { { 0, -1, 0 }, { 0, 0, 0} };
}

delcodeval tex_get_del_code(int n)
{
    sa_tree_item v2;
    sa_tree_item v1 = sa_get_item_8(lmt_mathcode_state.delcode_head, n, &v2);
    delcodeval d = { { 0, -1, 0 }, { 0, 0, 0} };
    if (v1.uint_value != DELCODEDEFAULT) {
        d.small.class_value = (short) v1.math_code_value.class_value;
        d.small.family_value = (short) v1.math_code_value.family_value;
        d.small.character_value = v1.math_code_value.character_value;
        d.large.class_value = (short) v2.math_code_value.class_value;
        d.large.family_value = (short) v2.math_code_value.family_value;
        d.large.character_value = v2.math_code_value.character_value;
    }
    return d;
}

/*tex  This really only works for old-style delcodes! */

int tex_get_del_code_number(int n)
{
    delcodeval d = tex_get_del_code(n);
    if (tex_has_del_code(d)) {
        return ((d.small.family_value * 256  + d.small.character_value) * 4096 +
                (d.large.family_value * 256) + d.large.character_value);
    } else {
        return -1;
    }
}

static void tex_aux_initialize_delcode(void)
{
    lmt_mathcode_state.delcode_head = sa_new_tree(DELCODESTACK, 8, (sa_tree_item) { .uint_value = DELCODEDEFAULT });
}

static void tex_aux_dump_delcode(dumpstream f)
{
    sa_dump_tree(f, lmt_mathcode_state.delcode_head);
}

static void tex_aux_undump_delcode(dumpstream f)
{
    lmt_mathcode_state.delcode_head = sa_undump_tree(f);
}

void tex_unsave_math_codes(int grouplevel)
{
    tex_aux_unsave_mathcode(grouplevel);
    tex_aux_unsave_delcode(grouplevel);
}

void tex_initialize_math_codes(void)
{
    tex_aux_initialize_mathcode();
    tex_aux_initialize_delcode();
    /*tex This might become optional: */
    tex_set_default_math_codes();
    tex_set_del_code('.', (delcodeval) { { 0, 0, 0, }, { 0, 0, 0 } }, level_one);
}

void tex_free_math_codes(void)
{
    sa_destroy_tree(lmt_mathcode_state.mathcode_head);
    sa_destroy_tree(lmt_mathcode_state.delcode_head);
}

void tex_dump_math_codes(dumpstream f)
{
    tex_aux_dump_mathcode(f);
    tex_aux_dump_delcode(f);
}

void tex_undump_math_codes(dumpstream f)
{
    tex_aux_undump_mathcode(f);
    tex_aux_undump_delcode(f);
}
