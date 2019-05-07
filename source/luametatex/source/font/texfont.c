/*
    See license.txt in the root of this project.
*/

/*tex

    Here is the main font API implementation for the original pascal parts. Stuff
    to watch out for:

    \startitemize

        \startitem
            Knuth had a |null_character| that was used when a character could not
            be found by the |fetch()| routine, to signal an error. This has been
            deleted, but it may mean that the output of luatex is incompatible
            with TeX after |fetch()| has detected an error condition.
        \stopitem

        \startitem
            Knuth also had a |font_glue()| optimization. This has been removed
            because it was a bit of dirty programming and it also was problematic
            |if 0 != null|.
        \stopitem

    \stopitemize

*/

# include "luatex-common.h"

# define proper_char_index(c) (c<=font_ec(f) && c>=font_bc(f))
# define do_realloc(a,b,d)    a = realloc(a,(unsigned)((unsigned)(b)*sizeof(d)))

# define font_table_step 16

font_state_info font_state = { NULL, 0, 0, 0 } ;

static void grow_font_table(int id)
{
    if (id >= font_state.font_arr_max) {
        int j = font_table_step;
        font_state.font_bytes += (int) (((id + font_table_step - font_state.font_arr_max) * (int) sizeof(texfont *)));
        font_state.font_tables = realloc(font_state.font_tables, (unsigned) (((unsigned) id + font_table_step) * sizeof(texfont *)));
        while (j--) {
            font_state.font_tables[id + j] = NULL;
        }
        font_state.font_arr_max = id + font_table_step;
    }
}

int new_font_id(void)
{
    int i;
    for (i = 0; i < font_state.font_arr_max; i++) {
        if (font_state.font_tables[i] == NULL) {
            break;
        }
    }
    if (i >= font_state.font_arr_max)
        grow_font_table(i);
    if (i > font_state.font_id_maxval)
        font_state.font_id_maxval = i;
    return i;
}

int max_font_id(void)
{
    return font_state.font_id_maxval;
}

void set_max_font_id(int i)
{
    font_state.font_id_maxval = i;
}

void set_charinfo_vert_variants(charinfo * ci, extinfo * ext)
{
    extinfo *c, *lst;
    if (ci->vert_variants != NULL) {
        lst = ci->vert_variants;
        while (lst != NULL) {
            c = lst->next;
            free(lst);
            lst = c;
        }
    }
    ci->vert_variants = ext;
}

void set_charinfo_hor_variants(charinfo * ci, extinfo * ext)
{
    extinfo *c, *lst;
    if (ci->hor_variants != NULL) {
        lst = ci->hor_variants;
        while (lst != NULL) {
            c = lst->next;
            free(lst);
            lst = c;
        }
    }
    ci->hor_variants = ext;
}

int new_font(void)
{
    int k;
    charinfo *ci;
    sa_tree_item sa_value = { 0 };
    int id = new_font_id();
    font_state.font_bytes += (int) sizeof(texfont);
    /*tex Most stuff is zero */
    font_state.font_tables[id] = calloc(1, sizeof(texfont));
    font_state.font_tables[id]->font_name = NULL;
    font_state.font_tables[id]->left_boundary = NULL;
    font_state.font_tables[id]->right_boundary = NULL;
    font_state.font_tables[id]->param_base = NULL;
    font_state.font_tables[id]->math_param_base = NULL;
    /*tex |ec = 0| */
    set_font_bc(id, 1);
    set_hyphen_char(id, '-');
    set_skew_char(id, -1);
    /*tex allocate eight values including 0 */
    set_font_params(id, 7);
    for (k = 0; k <= 7; k++) {
        set_font_param(id, k, 0);
    }
    /*tex character info zero is reserved for |notdef|. The stack size 1, default item value 0. */
    font_state.font_tables[id]->characters = new_sa_tree(1, 1, sa_value);
    ci = calloc(1, sizeof(charinfo));
    font_state.font_tables[id]->charinfo = ci;
    font_state.font_tables[id]->charinfo_size = 1;
    return id;
}

void font_malloc_charinfo(internal_font_number f, int num)
{
    int glyph = font_state.font_tables[f]->charinfo_size;
    font_state.font_bytes += (int) (num * (int) sizeof(charinfo));
    do_realloc(font_state.font_tables[f]->charinfo, (unsigned) (glyph + num), charinfo);
    memset(&(font_state.font_tables[f]->charinfo[glyph]), 0, (size_t) (num * (int) sizeof(charinfo)));
    font_state.font_tables[f]->charinfo_size += num;
}

# define find_charinfo_id(f,c) (get_sa_item(font_state.font_tables[f]->characters,c).int_value)

charinfo *get_charinfo(internal_font_number f, int c)
{
    if (proper_char_index(c)) {
        int glyph = get_sa_item(font_state.font_tables[f]->characters, c).int_value;
        if (!glyph) {
            sa_tree_item sa_value = { 0 };
            int tglyph = ++font_state.font_tables[f]->charinfo_count;
            if (tglyph >= font_state.font_tables[f]->charinfo_size) {
                font_malloc_charinfo(f, 256);
            }
            font_state.font_tables[f]->charinfo[tglyph].ef = 1000;
            sa_value.int_value = tglyph;
            /*tex 1 means global */
            set_sa_item(font_state.font_tables[f]->characters, c, sa_value, 1);
            glyph = tglyph;
        }
        return &(font_state.font_tables[f]->charinfo[glyph]);
    } else if (c == left_boundarychar) {
        if (left_boundary(f) == NULL) {
            charinfo *ci = calloc(1, sizeof(charinfo));
            font_state.font_bytes += (int) sizeof(charinfo);
            set_left_boundary(f, ci);
        }
        return left_boundary(f);
    } else if (c == right_boundarychar) {
        if (right_boundary(f) == NULL) {
            charinfo *ci = calloc(1, sizeof(charinfo));
            font_state.font_bytes += (int) sizeof(charinfo);
            set_right_boundary(f, ci);
        }
        return right_boundary(f);
    } else {
        return &(font_state.font_tables[f]->charinfo[0]);
    }
}

charinfo *char_info(internal_font_number f, int c)
{
    if (f > font_state.font_id_maxval) {
        return 0;
    } else if (proper_char_index(c)) {
        int glyph = (int) find_charinfo_id(f, c);
        return &(font_state.font_tables[f]->charinfo[glyph]);
    } else if (c == left_boundarychar && left_boundary(f) != NULL) {
        return left_boundary(f);
    } else if (c == right_boundarychar && right_boundary(f) != NULL) {
        return right_boundary(f);
    } else {
        return &(font_state.font_tables[f]->charinfo[0]);
    }
}

int char_exists(internal_font_number f, int c)
{
    if (f > font_state.font_id_maxval) {
        return 0;
    } else if (proper_char_index(c)) {
        return (int) find_charinfo_id(f, c);
    } else if ((c == left_boundarychar) && has_left_boundary(f)) {
        return 1;
    } else if ((c == right_boundarychar) && has_right_boundary(f)) {
        return 1;
    } else {
        return 0;
    }
}

extinfo *new_variant(int glyph, int startconnect, int endconnect, int advance, int repeater)
{
    extinfo *ext;
    ext = malloc(sizeof(extinfo));
    ext->next = NULL;
    ext->glyph = glyph;
    ext->start_overlap = startconnect;
    ext->end_overlap = endconnect;
    ext->advance = advance;
    ext->extender = repeater;
    return ext;
}

void add_charinfo_vert_variant(charinfo * ci, extinfo * ext)
{
    if (ci->vert_variants == NULL) {
        ci->vert_variants = ext;
    } else {
        extinfo *lst = ci->vert_variants;
        while (lst->next != NULL)
            lst = lst->next;
        lst->next = ext;
    }

}

void add_charinfo_hor_variant(charinfo * ci, extinfo * ext)
{
    if (ci->hor_variants == NULL) {
        ci->hor_variants = ext;
    } else {
        extinfo *lst = ci->hor_variants;
        while (lst->next != NULL)
            lst = lst->next;
        lst->next = ext;
    }

}

/*tex

    Note that many more small things like this are implemented as macros in the
    header file.

*/

int get_charinfo_math_kerns(charinfo * ci, int id)
{
    /*tex All callers check for |result>0|. */
    int k = 0;
    if (id == top_left_kern) {
        k = ci->top_left_math_kerns;
    } else if (id == bottom_left_kern) {
        k = ci->bottom_left_math_kerns;
    } else if (id == top_right_kern) {
        k = ci->top_right_math_kerns;
    } else if (id == bottom_right_kern) {
        k = ci->bottom_right_math_kerns;
    } else {
        confusion("get_charinfo_math_kerns");
    }
    return k;
}

void add_charinfo_math_kern(charinfo * ci, int id, scaled ht, scaled krn)
{
    int k;
    if (id == top_left_kern) {
        k = ci->top_left_math_kerns;
        do_realloc(ci->top_left_math_kern_array, ((k + 1) * 2), sizeof(scaled));
        ci->top_left_math_kern_array[(2 * (k))] = ht;
        ci->top_left_math_kern_array[((2 * (k)) + 1)] = krn;
        ci->top_left_math_kerns++;
    } else if (id == bottom_left_kern) {
        k = ci->bottom_left_math_kerns;
        do_realloc(ci->bottom_left_math_kern_array, ((k + 1) * 2), sizeof(scaled));
        ci->bottom_left_math_kern_array[(2 * (k))] = ht;
        ci->bottom_left_math_kern_array[(2 * (k)) + 1] = krn;
        ci->bottom_left_math_kerns++;
    } else if (id == top_right_kern) {
        k = ci->top_right_math_kerns;
        do_realloc(ci->top_right_math_kern_array, ((k + 1) * 2), sizeof(scaled));
        ci->top_right_math_kern_array[(2 * (k))] = ht;
        ci->top_right_math_kern_array[(2 * (k)) + 1] = krn;
        ci->top_right_math_kerns++;
    } else if (id == bottom_right_kern) {
        k = ci->bottom_right_math_kerns;
        do_realloc(ci->bottom_right_math_kern_array, ((k + 1) * 2), sizeof(scaled));
        ci->bottom_right_math_kern_array[(2 * (k))] = ht;
        ci->bottom_right_math_kern_array[(2 * (k)) + 1] = krn;
        ci->bottom_right_math_kerns++;
    } else {
        confusion("add_charinfo_math_kern");
    }
}

/*tex

    In \TEX, extensibles were fairly simple things. This function squeezes a
    \TFM\ extensible into the vertical extender structures. |advance==0| is a
    special case for \TFM\ fonts, because finding the proper advance width during
    tfm reading can be tricky.

    A small complication arises if |rep| is the only non-zero: it needs to be
    doubled as a non-repeatable to avoid mayhem.

*/

void set_charinfo_extensible(charinfo * ci, int top, int bot, int mid, int rep)
{
    extinfo *ext;
    /*tex Clear old data: */
    set_charinfo_vert_variants(ci, NULL);
    if (bot == 0 && top == 0 && mid == 0 && rep != 0) {
        ext = new_variant(rep, 0, 0, 0, EXT_NORMAL);
        add_charinfo_vert_variant(ci, ext);
        ext = new_variant(rep, 0, 0, 0, EXT_REPEAT);
        add_charinfo_vert_variant(ci, ext);
    } else {
        if (bot != 0) {
            ext = new_variant(bot, 0, 0, 0, EXT_NORMAL);
            add_charinfo_vert_variant(ci, ext);
        }
        if (rep != 0) {
            ext = new_variant(rep, 0, 0, 0, EXT_REPEAT);
            add_charinfo_vert_variant(ci, ext);
        }
        if (mid != 0) {
            ext = new_variant(mid, 0, 0, 0, EXT_NORMAL);
            add_charinfo_vert_variant(ci, ext);
            if (rep != 0) {
                ext = new_variant(rep, 0, 0, 0, EXT_REPEAT);
                add_charinfo_vert_variant(ci, ext);
            }
        }
        if (top != 0) {
            ext = new_variant(top, 0, 0, 0, EXT_NORMAL);
            add_charinfo_vert_variant(ci, ext);
        }
    }
}

/*tex

    Note that many more simple things like this are implemented as macros in the
    header file.

*/

void set_font_params(internal_font_number f, int b)
{
    int i = font_params(f);
    if (i != b) {
        font_state.font_bytes += (int) ((b - (int) font_params(f) + 1) * (int) sizeof(scaled));
        do_realloc(param_base(f), (b + 2), int);
        font_params(f) = b;
        if (b > i) {
            while (i < b) {
                i++;
                set_font_param(f, i, 0);
            }
        }
    }
}

void set_font_math_params(internal_font_number f, int b)
{
    int i = font_math_params(f);
    if (i != b) {
        font_state.font_bytes += ((b - (int) font_math_params(f) + 1) * (int) sizeof(scaled));
        do_realloc(math_param_base(f), (b + 2), int);
        font_math_params(f) = b;
        if (b > i) {
            while (i < b) {
                i++;
                set_font_math_param(f, i, undefined_math_parameter);
            }
        }
    }
}

void delete_font(int f)
{
    if (font_state.font_tables[f] != NULL) {
        int i;
        charinfo *co;
        set_font_name(f, NULL);
        set_left_boundary(f, NULL);
        set_right_boundary(f, NULL);
        for (i = font_bc(f); i <= font_ec(f); i++) {
            if (quick_char_exists(f, i)) {
                co = char_info(f, i);
                set_charinfo_ligatures(co, NULL);
                set_charinfo_kerns(co, NULL);
                set_charinfo_vert_variants(co, NULL);
                set_charinfo_hor_variants(co, NULL);
            }
        }
        /*tex free |notdef| */
        free(font_state.font_tables[f]->charinfo);
        destroy_sa_tree(font_state.font_tables[f]->characters);
        free(param_base(f));
        if (math_param_base(f) != NULL)
            free(math_param_base(f));
        free(font_state.font_tables[f]);
        font_state.font_tables[f] = NULL;
        if (font_state.font_id_maxval == f) {
            font_state.font_id_maxval--;
        }
    }
}

void create_null_font(void)
{
    int i = new_font();
    set_font_name(i, strdup("nullfont"));
    set_font_touched(i);
}

int is_valid_font(int id)
{
    if (id >= 0 && id <= font_state.font_id_maxval && font_state.font_tables[id] != NULL) {
        return 1;
    } else {
        return 0;
    }
}

/*tex

    Here come some subroutines to deal with expanded fonts. Returning 1 means
    that they are identical.

*/

liginfo get_ligature(internal_font_number f, int lc, int rc)
{
    liginfo t = { 0, 0, 0 };
    /*
    t.lig = 0;
    t.type = 0;
    t.adj = 0;
    */
    if (lc == non_boundarychar || rc == non_boundarychar || (!has_lig(f, lc))) {
        return t;
    } else {
        int k = 0;
        charinfo *co = char_info(f, lc);
        while (1) {
            liginfo u = charinfo_ligature(co, k);
            if (lig_end(u)) {
                break;
            } else if (lig_char(u) == rc) {
                return lig_disabled(u) ? t : u;
            }
            k++;
        }
        return t;
    }
}

int raw_get_kern(internal_font_number f, int lc, int rc)
{
    if (lc != non_boundarychar && rc != non_boundarychar) {
        int k = 0;
        charinfo *co = char_info(f, lc);
        while (1) {
            kerninfo u = charinfo_kern(co, k);
            if (kern_end(u)) {
                break;
            } else if (kern_char(u) == rc) {
                return kern_disabled(u) ? 0 : kern_kern(u);
            }
            k++;
        }
    }
    return 0;
}

int get_kern(internal_font_number f, int lc, int rc)
{
    if (lc == non_boundarychar || rc == non_boundarychar || (!has_kern(f, lc))) {
        return 0;
    } else {
        return raw_get_kern(f, lc, rc);
    }
}

/*tex

    This returns the multiple of |font_step(f)| that is nearest to |e|.

*/

int fix_expand_value(internal_font_number f, int e)
{
    int max_expand;
    int neg;
    if (e == 0) {
        return 0;
    } else if (e < 0) {
        e = -e;
        neg = 1;
        max_expand = font_max_shrink(f);
    } else {
        neg = 0;
        max_expand = font_max_stretch(f);
    }
    if (e > max_expand) {
        e = max_expand;
    } else {
        int step = font_step(f);
        if (e % step > 0) {
            e = step * round_xn_over_d(e, 1, step);
        }
    }
    return neg ? -e : e;
}

void set_expand_params(internal_font_number f, int stretch_limit, int shrink_limit, int font_step)
{
    set_font_step(f, font_step);
    set_font_max_shrink(f, shrink_limit);
    set_font_max_stretch(f, stretch_limit);
}

int read_font_info(char *cnom, scaled s)
{
    int callback_id = callback_defined(define_font_callback);
    if (callback_id > 0) {
        char *cnam = strdup(cnom);
        int f = new_font();
        callback_id = run_and_save_callback(callback_id, "Sdd->", cnam, s, f);
        free(cnam);
        if (callback_id > 0) {
            int t;
            luaL_checkstack(Luas, 1, "out of stack space");
            lua_rawgeti(Luas, LUA_REGISTRYINDEX, callback_id);
            t = lua_type(Luas, -1);
            if (t == LUA_TTABLE) {
                font_from_lua(Luas, f);
                destroy_saved_callback(callback_id);
                return f;
            } else if (t == LUA_TNUMBER) {
                int r = (int) lua_tointeger(Luas, -1);
                destroy_saved_callback(callback_id);
                delete_font(f);
                lua_pop(Luas, 1);
                return r;
            } else {
                lua_pop(Luas, 1);
                delete_font(f);
            }
        }
    }
    if (suppress_fontnotfound_error_par == 0) {
        normal_warning("fonts","no font has been read, you need to enable or fix the callback");
    }
    return 0;
}
