/*
    See license.txt in the root of this project.
*/

/*tex

    Here is the main font API implementation for the original pascal parts. Stuff to watch out for:

    \startitemize

        \startitem
            Knuth had a |null_character| that was used when a character could not be found by the
            |fetch()| routine, to signal an error. This has been deleted, but it may mean that the
            output of luatex is incompatible with TeX after |fetch()| has detected an error
            condition.
        \stopitem

        \startitem
            Knuth also had a |font_glue()| optimization. This has been removed because it was a bit
            of dirty programming and it also was problematic |if 0 != null|.
        \stopitem

    \stopitemize

*/

# include "luametatex.h"

# define proper_char_index(f, c) (c >= font_first_character(f) && c <= font_last_character(f))

inline static scaled tex_aux_font_x_scaled(scaled v)
{
    return v ? scaledround(0.000001 * (glyph_scale_par ? glyph_scale_par : 1000) * (glyph_x_scale_par ? glyph_x_scale_par : 1000) * v) : 0;
}

inline static scaled tex_aux_font_y_scaled(scaled v)
{
    return v ? scaledround(0.000001 * (glyph_scale_par ? glyph_scale_par : 1000) * (glyph_y_scale_par ? glyph_y_scale_par : 1000) * v) : 0;
}

inline static scaled tex_aux_glyph_x_scaled(halfword g, scaled v)
{
    return v ? scaledround(0.000001 * (glyph_scale(g) ? glyph_scale(g) : 1000) * (glyph_x_scale(g) ? glyph_x_scale(g) : 1000) * v) : 0;
}

inline static scaled tex_aux_glyph_y_scaled(halfword g, scaled v)
{
    return v ? scaledround(0.000001 * (glyph_scale(g) ? glyph_scale(g) : 1000) * (glyph_y_scale(g) ? glyph_y_scale(g) : 1000) * v) : 0;
}

font_state_info lmt_font_state = {
    .fonts          = NULL,
    .adjust_stretch = 0,
    .adjust_shrink  = 0,
    .adjust_step    = 0,
    .padding        = 0,
    .font_data      = {
        .minimum   = min_font_size,
        .maximum   = max_font_size,
        .size      = memory_data_unset,
        .step      = stp_font_size,
        .allocated = 0,
        .itemsize  = 1,
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
};

/*tex
    There can be holes in the font id range. And \unknown\ nullfont is special! Contrary
    to other places, here we don't reallocate an array of records but one of pointers.
*/

void tex_initialize_fonts(void)
{
    texfont **tmp = aux_allocate_clear_array(sizeof(texfont *), lmt_font_state.font_data.minimum, 0);
    if (tmp) {
        for (int i = 0; i < lmt_font_state.font_data.minimum; i++) {
            tmp[i] = NULL;
        }
        lmt_font_state.fonts = tmp;
        lmt_font_state.font_data.allocated += lmt_font_state.font_data.minimum * sizeof(texfont *);
        lmt_font_state.font_data.top = lmt_font_state.font_data.minimum;
        lmt_font_state.font_data.ptr = -1; /* we need to end up with id zero first */
        tex_create_null_font();
    } else {
        tex_overflow_error("fonts", lmt_font_state.font_data.minimum);
    }
}

/*tex If a slot is not used .. so be it. We want sequential numbers. */

int tex_new_font_id(void)
{
    if (lmt_font_state.font_data.ptr < lmt_font_state.font_data.top) {
        ++lmt_font_state.font_data.ptr;
        return lmt_font_state.font_data.ptr;
    } else if (lmt_font_state.font_data.top < lmt_font_state.font_data.maximum) {
        texfont **tmp ;
        int top = lmt_font_state.font_data.top + lmt_font_state.font_data.step;
        if (top > lmt_font_state.font_data.maximum) {
            top = lmt_font_state.font_data.maximum;
        }
        tmp = aux_reallocate_array(lmt_font_state.fonts, sizeof(texfont *), top, 0);
        if (tmp) {
            for (int i = lmt_font_state.font_data.top + 1; i < top; i++) {
                tmp[i] = NULL;
            }
            lmt_font_state.fonts = tmp;
            lmt_font_state.font_data.allocated += ((size_t) top - lmt_font_state.font_data.top) * sizeof(texfont *);
            lmt_font_state.font_data.top = top;
            lmt_font_state.font_data.ptr += 1;
            return lmt_font_state.font_data.ptr;
        }
    }
    tex_overflow_error("fonts", lmt_font_state.font_data.maximum);
    return 0;
}

int tex_get_font_max_id(void)
{
    return lmt_font_state.font_data.ptr;
}

void tex_dump_font_data(dumpstream f) {
    dump_int(f, lmt_font_state.font_data.ptr);
}

void tex_undump_font_data(dumpstream f) {
    int x;
    undump_int(f, x);
    lmt_font_state.font_data.ptr = 0;
}

void tex_set_charinfo_vertical_parts(charinfo *ci, extinfo *ext)
{
    if (ci->math) {
        if (ci->math->vertical_parts) {
            extinfo *lst = ci->math->vertical_parts;
            while (lst) {
                extinfo *c = lst->next;
                lmt_memory_free(lst);
                lst = c;
            }
        }
        ci->math->vertical_parts = ext;
    }
}

void tex_set_charinfo_horizontal_parts(charinfo *ci, extinfo *ext)
{
    if (ci->math) {
        if (ci->math->horizontal_parts) {
            extinfo *lst = ci->math->horizontal_parts;
            while (lst) {
                extinfo *c = lst->next;
                lmt_memory_free(lst);
                lst = c;
            }
        }
        ci->math->horizontal_parts = ext;
    }
}

void tex_set_font_parameters(halfword f, int b)
{
    int i = font_parameter_count(f);
    if (b > i) {
        /*tex If really needed this can be a calloc. */
        int s = (b + 2) * (int) sizeof(int);
        int *a = lmt_memory_realloc(font_parameter_base(f), (size_t) s);
        if (a) {
            lmt_font_state.font_data.allocated += (b - i + 1) * (int) sizeof(scaled);
            font_parameter_base(f) = a;
            font_parameter_count(f) = b;
            while (i < b) {
                font_parameter(f, ++i) = 0;
            }
        } else {
            tex_overflow_error("font", s);
        }
    }
}

/*tex Most stuff is zero: */

int tex_new_font(void)
{
    int size = sizeof(charinfo);
    charinfo *ci = lmt_memory_calloc(1, (size_t) size);
    if (ci) {
        texfont *t = NULL;
        size = sizeof(texfont);
        t = lmt_memory_calloc(1, (size_t) size);
        if (t) {
            sa_tree_item sa_value = { 0 };
            int id = tex_new_font_id();
            lmt_font_state.font_data.allocated += size;
            lmt_font_state.fonts[id] = t;
            set_font_name(id, NULL);
            set_font_original(id, NULL);
            set_font_left_boundary(id, NULL);
            set_font_right_boundary(id, NULL);
            set_font_parameter_base(id, NULL);
            set_font_math_parameter_base(id, NULL);
            /*tex |ec = 0| */
            set_font_first_character(id, 1);
            set_font_hyphen_char(id, '-');
            set_font_skew_char(id, -1);
            /*tex allocate eight values including 0 */
            tex_set_font_parameters(id, 7);
            for (int k = 0; k <= 7; k++) {
                tex_set_font_parameter(id, k, 0);
            }
            /*tex character info zero is reserved for |notdef|. The stack size 1, default item value 0. */
            t->characters = sa_new_tree(1, 4, sa_value);
            t->chardata = ci;
            t->chardata_size = 1;
            return id;
        }
    }
    tex_overflow_error("font", size);
    return 0;
}

void tex_font_malloc_charinfo(halfword f, int num)
{
    int glyph = lmt_font_state.fonts[f]->chardata_size;
    int size = (glyph + num) * sizeof(charinfo);
    charinfo *data = lmt_memory_realloc(lmt_font_state.fonts[f]->chardata , (size_t) size);
    if (data) {
        lmt_font_state.font_data.allocated += num * sizeof(charinfo);
        lmt_font_state.fonts[f]->chardata = data;
        memset(&data[glyph], 0, (size_t) num * sizeof(charinfo));
        lmt_font_state.fonts[f]->chardata_size += num;
    } else {
        tex_overflow_error("font", size);
    }
}

void tex_char_malloc_mathinfo(charinfo *ci)
{
    int size = sizeof(mathinfo);
    mathinfo *mi = lmt_memory_calloc(1, (size_t) size);
    if (mi) {
        mi->horizontal_parts = NULL;
        mi->vertical_parts = NULL;
        mi->top_left_math_kern_array = NULL;
        mi->top_right_math_kern_array = NULL;
        mi->bottom_right_math_kern_array = NULL;
        mi->bottom_left_math_kern_array = NULL;
        /* zero annyway: */
        mi->top_left_kern = 0;
        mi->top_right_kern = 0;
        mi->bottom_left_kern = 0;
        mi->bottom_right_kern = 0;
        mi->left_margin = 0;
        mi->right_margin = 0;
        mi->top_margin = 0;
        mi->bottom_margin = 0;
        /* */
        mi->top_overshoot = INT_MIN;
        mi->bottom_overshoot = INT_MIN;
        if (ci->math) {
            /*tex This seldom or probably never happens. */
            tex_set_charinfo_vertical_parts(ci, NULL);
            tex_set_charinfo_horizontal_parts(ci, NULL);
            set_charinfo_top_left_math_kern_array(ci, NULL);
            set_charinfo_top_right_math_kern_array(ci, NULL);
            set_charinfo_bottom_right_math_kern_array(ci, NULL);
            set_charinfo_bottom_left_math_kern_array(ci, NULL);
            lmt_memory_free(ci->math);
        } else {
            lmt_font_state.font_data.allocated += size;
        }
        ci->math = mi;
    } else {
        tex_overflow_error("font", size);
    }
}

# define find_charinfo_id(f,c) (sa_get_item_4(lmt_font_state.fonts[f]->characters,c).int_value)

charinfo *tex_get_charinfo(halfword f, int c)
{
    if (proper_char_index(f, c)) {
        int glyph = sa_get_item_4(lmt_font_state.fonts[f]->characters, c).int_value;
        if (! glyph) {
            sa_tree_item sa_value = { 0 };
            int tglyph = ++lmt_font_state.fonts[f]->chardata_count;
            if (tglyph >= lmt_font_state.fonts[f]->chardata_size) {
                tex_font_malloc_charinfo(f, 256);
            }
            lmt_font_state.fonts[f]->chardata[tglyph].expansion = 1000;
            sa_value.int_value = tglyph;
            /*tex 1 means global */
            sa_set_item_4(lmt_font_state.fonts[f]->characters, c, sa_value, 1);
            glyph = tglyph;
        }
        return &(lmt_font_state.fonts[f]->chardata[glyph]);
    } else if (c == left_boundary_char) {
        if (! font_has_left_boundary(f)) {
            int size = sizeof(charinfo);
            charinfo *ci = lmt_memory_calloc(1, (size_t) size);
            if (ci) {
                lmt_font_state.font_data.allocated += size;
                set_font_left_boundary(f, ci);
            } else {
                tex_overflow_error("font", size);
            }
        }
        return font_left_boundary(f);
    } else if (c == right_boundary_char) {
        if (! font_has_right_boundary(f)) {
            int size = sizeof(charinfo);
            charinfo *ci = lmt_memory_calloc(1, (size_t) size);
            if (ci) {
                lmt_font_state.font_data.allocated += size;
                set_font_right_boundary(f, ci);
            } else {
                tex_overflow_error("font", size);
            }
        }
        return font_right_boundary(f);
    } else {
        return &(lmt_font_state.fonts[f]->chardata[0]);
    }
}

static charinfo *tex_aux_char_info(halfword f, int c)
{
    if (f > lmt_font_state.font_data.ptr) {
        return NULL;
    } else if (proper_char_index(f, c)) {
        return &(lmt_font_state.fonts[f]->chardata[(int) find_charinfo_id(f, c)]);
    } else if (c == left_boundary_char) {
        if (font_left_boundary(f)) {
            return font_left_boundary(f);
        }
    } else if (c == right_boundary_char) {
        if (font_right_boundary(f)) {
            return font_right_boundary(f);
        }
    }
    return &(lmt_font_state.fonts[f]->chardata[0]);
}

void tex_char_process(halfword f, int c) 
{
    if (tex_char_has_tag_from_font(f, c, callback_tag)) { 
        int callback_id = lmt_callback_defined(process_character_callback);
        if (callback_id > 0) {
            lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->", f, c);
        }
        tex_char_reset_tag_from_font(f, c, callback_tag);
    }
}

int tex_char_exists(halfword f, int c)
{
    if (f > lmt_font_state.font_data.ptr) {
        return 0;
    } else if (proper_char_index(f, c)) {
        return (int) find_charinfo_id(f, c);
    } else if (c == left_boundary_char) {
        if (font_has_left_boundary(f)) {
            return 1;
        }
    } else if (c == right_boundary_char) {
        if (font_has_right_boundary(f)) {
            return 1;
        }
    }
    return 0;
}

/*

static int check_math_char(halfword f, int c, int size)
{
    int callback_id = lmt_callback_defined(get_math_char_callback);
    if (callback_id > 0) {
        halfword s = c;
        lmt_run_callback(lua_state.lua_instance, callback_id, "ddd->d", f, c, size, &s);
        if (s && proper_char_index(f, s) && find_charinfo_id(f, s)) {
            return s;
        }
    }
    return c;
}
*/

int tex_math_char_exists(halfword f, int c, int size)
{
    (void) size;
    return (f > 0 && f <= lmt_font_state.font_data.ptr && proper_char_index(f, c));
}

/*tex
    There is a bit overhead due to first fetching but we don't need to check again, so that saves
    a little.
*/

int tex_get_math_char(halfword f, int c, int size, scaled *scale, int direction)
{
    int id = find_charinfo_id(f, c);
    texfont *tf = lmt_font_state.fonts[f];
    if (id) { 
        /* */
        if (direction) { 
            charinfo *ci = &tf->chardata[id];
            int m = ci->math->mirror;
            if (m && proper_char_index(f, m)) {
                int mid = find_charinfo_id(f, m);
                if (mid) { 
                    id = mid;
                    c = m;
                }
            }
        }
        /* */
        if (size && tf->compactmath) {
            for (int i=1;i<=size;i++) {
                charinfo *ci = &tf->chardata[id];
                if (ci->math) {
                    int s = ci->math->smaller;
                    if (s && proper_char_index(f, s)) {
                        id = find_charinfo_id(f, s);
                        if (id) {
                            /* todo: trace */
                            c = s;
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }
        }
    }
    if (scale) {
        *scale = tex_get_math_font_scale(f, size);
        if (! *scale) {
            *scale = 1000;
        }
    }
    return c;
}

extinfo *tex_new_charinfo_part(int glyph, int startconnect, int endconnect, int advance, int extender)
{
    int size = sizeof(extinfo);
    extinfo *ext = lmt_memory_malloc((size_t) size);
    if (ext) {
        ext->next = NULL;
        ext->glyph = glyph;
        ext->start_overlap = startconnect;
        ext->end_overlap = endconnect;
        ext->advance = advance;
        ext->extender = extender;
    } else {
        tex_overflow_error("font", size);
    }
    return ext;
}

void tex_add_charinfo_vertical_part(charinfo *ci, extinfo *ext)
{
    if (ci->math) {
        if (ci->math->vertical_parts) {
            extinfo *lst = ci->math->vertical_parts;
            while (lst->next)
                lst = lst->next;
            lst->next = ext;
        } else {
            ci->math->vertical_parts = ext;
        }
    }
}

void tex_add_charinfo_horizontal_part(charinfo *ci, extinfo *ext)
{
    if (ci->math) {
        if (ci->math->horizontal_parts) {
            extinfo *lst = ci->math->horizontal_parts;
            while (lst->next) {
                lst = lst->next;
            }
            lst->next = ext;
        } else {
            ci->math->horizontal_parts = ext;
        }
    }
}

/*tex

    Note that many more small things like this are implemented as macros in the header file.

*/

int tex_get_charinfo_math_kerns(charinfo *ci, int id)
{
    /*tex All callers check for |result > 0|. */
    if (ci->math) {
        switch (id) {
            case top_left_kern:
                return ci->math->top_left_math_kerns;
            case bottom_left_kern:
                return ci->math->bottom_left_math_kerns;
            case top_right_kern:
                return ci->math->top_right_math_kerns;
            case bottom_right_kern:
                return ci->math->bottom_right_math_kerns;
            default:
                tex_confusion("weird math kern");
                break;
        }
    }
    return 0;
}

void tex_add_charinfo_math_kern(charinfo *ci, int id, scaled ht, scaled krn)
{
    if (ci->math) {
        int k = 0;
        int s = 0;
        scaled *a = NULL;
        switch (id) {
            case top_right_kern:
                {
                    k = ci->math->top_right_math_kerns;
                    s = 2 * (k + 1) * (int) sizeof(scaled);
                    a = lmt_memory_realloc(ci->math->top_right_math_kern_array, (size_t) s);
                    if (a) {
                        ci->math->top_right_math_kern_array = a;
                        ci->math->top_right_math_kerns++;
                    }
                    break;
                }
            case bottom_right_kern:
                {
                    k = ci->math->bottom_right_math_kerns;
                    s = 2 * (k + 1) * (int) sizeof(scaled);
                    a = lmt_memory_realloc(ci->math->bottom_right_math_kern_array, (size_t) s);
                    if (a) {
                        ci->math->bottom_right_math_kern_array = a;
                        ci->math->bottom_right_math_kerns++;
                    }
                    break;
                }
            case bottom_left_kern:
                {
                    k = ci->math->bottom_left_math_kerns;
                    s = 2 * (k + 1) * (int) sizeof(scaled);
                    a = lmt_memory_realloc(ci->math->bottom_left_math_kern_array, (size_t) s);
                    if (a) {
                        ci->math->bottom_left_math_kern_array = a;
                        ci->math->bottom_left_math_kerns++;
                    }
                    break;
                }
            case top_left_kern:
                {
                    k = ci->math->top_left_math_kerns;
                    s = 2 * (k + 1) * (int) sizeof(scaled);
                    a = lmt_memory_realloc(ci->math->top_left_math_kern_array, (size_t) s);
                    if (a) {
                        ci->math->top_left_math_kern_array = a;
                        ci->math->top_left_math_kerns++;
                    }
                    break;
                }
            default:
                tex_confusion("add math kern");
                return;
        }
        if (a) {
            a[2 * k] = ht;
            a[(2 * k) + 1] = krn;
        } else {
            tex_overflow_error("font", s);
        }
    }
}

/*tex

    In \TEX, extensibles were fairly simple things. This function squeezes a \TFM\ extensible into
    the vertical extender structures. |advance == 0| is a special case for \TFM\ fonts, because
    finding the proper advance width during \TFM\ reading can be tricky.

    A small complication arises if |rep| is the only non-zero: it needs to be doubled as a
    non-repeatable to avoid mayhem.

*/

void tex_set_charinfo_extensible(charinfo *ci, int top, int bottom, int middle, int extender)
{
    if (ci->math) {
        extinfo *ext;
        /*tex Clear old data: */
        tex_set_charinfo_vertical_parts(ci, NULL);
        if (bottom == 0 && top == 0 && middle == 0 && extender != 0) {
            ext = tex_new_charinfo_part(extender, 0, 0, 0, math_extension_normal);
            tex_add_charinfo_vertical_part(ci, ext);
            ext = tex_new_charinfo_part(extender, 0, 0, 0, math_extension_repeat);
            tex_add_charinfo_vertical_part(ci, ext);
        } else {
            if (bottom) {
                ext = tex_new_charinfo_part(bottom, 0, 0, 0, math_extension_normal);
                tex_add_charinfo_vertical_part(ci, ext);
            }
            if (extender) {
                ext = tex_new_charinfo_part(extender, 0, 0, 0, math_extension_repeat);
                tex_add_charinfo_vertical_part(ci, ext);
            }
            if (middle) {
                ext = tex_new_charinfo_part(middle, 0, 0, 0, math_extension_normal);
                tex_add_charinfo_vertical_part(ci, ext);
                if (extender) {
                    ext = tex_new_charinfo_part(extender, 0, 0, 0, math_extension_repeat);
                    tex_add_charinfo_vertical_part(ci, ext);
                }
            }
            if (top) {
                ext = tex_new_charinfo_part(top, 0, 0, 0, math_extension_normal);
                tex_add_charinfo_vertical_part(ci, ext);
            }
        }
    }
}

/*tex why not just preallocate for all math otf parameters */

void tex_set_font_math_parameters(halfword f, int b)
{
    int i = font_math_parameter_count(f);
    if (i < b) {
        size_t size = ((size_t) b + 2) * sizeof(scaled);
        scaled *data = lmt_memory_realloc(font_math_parameter_base(f), size);
        if (data) {
            lmt_font_state.font_data.allocated += (int) (((size_t) b - i + 1) * sizeof(scaled));
            font_math_parameter_base(f) = data;
            font_math_parameter_count(f) = b;
            while (i < b) {
                ++i; /* in macro, make the next a function */
             // set_font_math_parameter(f, i, undefined_math_parameter);
                font_math_parameter(f, i) = undefined_math_parameter;
            }
        } else {
            tex_overflow_error("font", (int) size);
        }
    }
}

void tex_delete_font(int f)
{
    if (lmt_font_state.fonts[f]) {
        tex_set_font_name(f, NULL);
        tex_set_font_original(f, NULL);
        set_font_left_boundary(f, NULL);
        set_font_right_boundary(f, NULL);
        for (int i = font_first_character(f); i <= font_last_character(f); i++) {
            if (quick_char_exists(f, i)) {
                charinfo *co = tex_aux_char_info(f, i);
                set_charinfo_kerns(co, NULL);
                set_charinfo_ligatures(co, NULL);
                if (co->math) {
                    tex_set_charinfo_vertical_parts(co, NULL);
                    tex_set_charinfo_horizontal_parts(co, NULL);
                    set_charinfo_top_left_math_kern_array(co, NULL);
                    set_charinfo_top_right_math_kern_array(co, NULL);
                    set_charinfo_bottom_right_math_kern_array(co, NULL);
                    set_charinfo_bottom_left_math_kern_array(co, NULL);
                    set_charinfo_math(co, NULL);
                }
            }
        }
        /*tex free |notdef| */
        lmt_memory_free(lmt_font_state.fonts[f]->chardata);
        sa_destroy_tree(lmt_font_state.fonts[f]->characters);
        lmt_memory_free(font_parameter_base(f));
        if (font_math_parameter_base(f)) {
            lmt_memory_free(font_math_parameter_base(f));
        }
        lmt_memory_free(lmt_font_state.fonts[f]);
        lmt_font_state.fonts[f] = NULL;
        if (lmt_font_state.font_data.ptr == f) {
            lmt_font_state.font_data.ptr--;
        }
    }
}

void tex_create_null_font(void)
{
    int id = tex_new_font();
    tex_set_font_name(id, "nullfont");
    tex_set_font_original(id, "nullfont");
}

int tex_is_valid_font(halfword f)
{
    return (f >= 0 && f <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[f]);
}

int tex_checked_font(halfword f)
{
    return (f >= 0 && f <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[f]) ? f : null_font;
}

halfword tex_get_font_identifier(halfword fontspec)
{
    if (fontspec) {
        halfword fnt = font_spec_identifier(fontspec);
        if ((fnt >= 0 && fnt <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[fnt])) {
            return fnt;
        }
    }
    return null_font;
}

/*tex

    Here come some subroutines to deal with expanded fonts. Returning 1 means that they are
    identical.

*/

ligatureinfo tex_get_ligature(halfword f, int lc, int rc)
{
    ligatureinfo t = { 0, 0, 0, 0 };
    if (lc != non_boundary_char && rc != non_boundary_char && tex_has_ligature(f, lc)) {
        int k = 0;
        charinfo *co = tex_aux_char_info(f, lc);
        while (1) {
            ligatureinfo u = charinfo_ligature(co, k);
            if (ligature_end(u)) {
                break;
            } else if (ligature_char(u) == rc) {
                return ligature_disabled(u) ? t : u;
            }
            k++;
        }
    }
    return t;
}

int tex_raw_get_kern(halfword f, int lc, int rc)
{
    if (lc != non_boundary_char && rc != non_boundary_char) {
        int k = 0;
        charinfo *co = tex_aux_char_info(f, lc);
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

int tex_get_kern(halfword f, int lc, int rc)
{
    if (lc == non_boundary_char || rc == non_boundary_char || (! tex_has_kern(f, lc))) {
        return 0;
    } else {
        return tex_raw_get_kern(f, lc, rc);
    }
}

scaled tex_valid_kern(halfword left, halfword right)
{
    if (node_type(left) == glyph_node && node_type(right) == glyph_node) {
        halfword fl = glyph_font(left);
        halfword fr = glyph_font(right);
        halfword cl = glyph_character(left);
        halfword cr = glyph_character(right);
        if (fl == fr && cl != non_boundary_char && cr != non_boundary_char && tex_has_kern(fl, cl) && ! tex_has_glyph_option(left, glyph_option_no_right_kern) && ! tex_has_glyph_option(right, glyph_option_no_left_kern)) {
            return tex_raw_get_kern(fl, cl, cr);
        }
    }
    return 0;
}

/*tex

    Experiment:

*/

halfword tex_checked_font_adjust(halfword adjust_spacing, halfword adjust_spacing_step, halfword adjust_spacing_shrink, halfword adjust_spacing_stretch)
{
    if (adjust_spacing >= adjust_spacing_full) {
        if (adjust_spacing_step > 0) {
            lmt_font_state.adjust_step = adjust_spacing_step;
            lmt_font_state.adjust_shrink = adjust_spacing_shrink;
            lmt_font_state.adjust_stretch = adjust_spacing_stretch;
            if (lmt_font_state.adjust_step > 100) {
                lmt_font_state.adjust_step = 100;
            }
            if (lmt_font_state.adjust_shrink < 0) {
                lmt_font_state.adjust_shrink = 0;
            } else if (lmt_font_state.adjust_shrink > 500) {
                lmt_font_state.adjust_shrink = 500;
            }
            if (lmt_font_state.adjust_stretch < 0) {
                lmt_font_state.adjust_stretch = 0;
            } else if (lmt_font_state.adjust_stretch > 1000) {
                lmt_font_state.adjust_stretch = 1000;
            }
            return adjust_spacing;
        }
    } else {
        adjust_spacing = adjust_spacing_off;
    }
    lmt_font_state.adjust_step = 0;
    lmt_font_state.adjust_shrink = 0;
    lmt_font_state.adjust_stretch = 0;
    return adjust_spacing;
}

/*tex

    This returns the multiple of |font_step(f)| that is nearest to |e|.

*/

int tex_fix_expand_value(halfword f, int e)
{
    int max_expand, neg;
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
            e = step * tex_round_xn_over_d(e, 1, step);
        }
    }
    return neg ? -e : e;
}

int tex_read_font_info(char *cnom, scaled s)
{
    int callback_id = lmt_callback_defined(define_font_callback);
    if (callback_id > 0) {
        int f = 0;
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "Sd->d", cnom, s, &f);
        if (tex_is_valid_font(f)) {
            tex_set_font_original(f, (char *) cnom);
            return f;
        } else {
            return 0;
        }
    } else {
        tex_normal_warning("fonts","no font has been read, you need to enable or fix the callback");
        return 0;
    }
}

/*tex Abstraction: */

halfword tex_get_font_parameter(halfword f, halfword code) /* todo: math */
{
    if (font_parameter_count(f) < code) {
        tex_set_font_parameters(f, code);
    }
    return font_parameter(f, code);
}

void tex_set_font_parameter(halfword f, halfword code, scaled v)
{
    if (font_parameter_count(f) < code) {
        tex_set_font_parameters(f, code);
    }
    font_parameter(f, code) = v;
}

scaled tex_get_font_slant           (halfword f) { return font_parameter(f, slant_code);         }
scaled tex_get_font_space           (halfword f) { return font_parameter(f, space_code);         }
scaled tex_get_font_space_stretch   (halfword f) { return font_parameter(f, space_stretch_code); }
scaled tex_get_font_space_shrink    (halfword f) { return font_parameter(f, space_shrink_code);  }
scaled tex_get_font_ex_height       (halfword f) { return font_parameter(f, ex_height_code);     }
scaled tex_get_font_em_width        (halfword f) { return font_parameter(f, em_width_code);      }
scaled tex_get_font_extra_space     (halfword f) { return font_parameter(f, extra_space_code);   }

scaled tex_get_scaled_slant         (halfword f) { return                       font_parameter(f, slant_code);          }
scaled tex_get_scaled_space         (halfword f) { return tex_aux_font_x_scaled(font_parameter(f, space_code));         }
scaled tex_get_scaled_space_stretch (halfword f) { return tex_aux_font_x_scaled(font_parameter(f, space_stretch_code)); }
scaled tex_get_scaled_space_shrink  (halfword f) { return tex_aux_font_x_scaled(font_parameter(f, space_shrink_code));  }
scaled tex_get_scaled_ex_height     (halfword f) { return tex_aux_font_y_scaled(font_parameter(f, ex_height_code));     }
scaled tex_get_scaled_em_width      (halfword f) { return tex_aux_font_x_scaled(font_parameter(f, em_width_code));      }
scaled tex_get_scaled_extra_space   (halfword f) { return tex_aux_font_x_scaled(font_parameter(f, extra_space_code));   }

scaled tex_font_x_scaled            (scaled v) { return tex_aux_font_x_scaled(v); }
scaled tex_font_y_scaled            (scaled v) { return tex_aux_font_y_scaled(v); }

halfword tex_get_scaled_parameter(halfword f, halfword code) /* todo: math */
{
    if (font_parameter_count(f) < code) {
        tex_set_font_parameters(f, code);
    }
    switch (code) {
        case slant_code:
            return font_parameter(f, code);
        case ex_height_code:
            return tex_aux_font_y_scaled(font_parameter(f, code));
        default:
            return tex_aux_font_x_scaled(font_parameter(f, code));
    }
}

void tex_set_scaled_parameter(halfword f, halfword code, scaled v)
{
    if (font_parameter_count(f) < code) {
        tex_set_font_parameters(f, code);
    }
    font_parameter(f, code) = tex_aux_font_x_scaled(v);
}

halfword tex_get_scaled_glue(halfword f)
{
    halfword p = tex_new_glue_node(zero_glue, space_skip_glue);
    glue_amount(p) = tex_aux_font_x_scaled(font_parameter(f, space_code));
    glue_stretch(p) = tex_aux_font_x_scaled(font_parameter(f, space_stretch_code));
    glue_shrink(p) = tex_aux_font_x_scaled(font_parameter(f, space_shrink_code));
    glue_font(p) = f;
    return p;
}

halfword tex_get_scaled_parameter_glue(quarterword p, quarterword s)
{
    halfword n = tex_new_glue_node(zero_glue, s);
    halfword g = glue_parameter(p);
 // if (g) {
 //     memcpy((void *) (node_memory_state.nodes + n + 2), (void *) (node_memory_state.nodes + g + 2), (glue_spec_size - 2) * (sizeof(memoryword)));
 // }
    glue_amount(n) = tex_aux_font_x_scaled(glue_amount(g));
    glue_stretch(n) = tex_aux_font_x_scaled(glue_stretch(g));
    glue_shrink(n) = tex_aux_font_x_scaled(glue_shrink(g));
    return n;
}

halfword tex_get_parameter_glue(quarterword p, quarterword s)
{
    halfword n = tex_new_glue_node(zero_glue, s);
    halfword g = glue_parameter(p);
    if (g) {
        memcpy((void *) (lmt_node_memory_state.nodes + n + 2), (void *) (lmt_node_memory_state.nodes + g + 2), (glue_spec_size - 2) * (sizeof(memoryword)));
    }
    return n;
}

/*tex Ligaturing starts here */

static void tex_aux_nesting_append(halfword nest1, halfword newn)
{
    halfword tail = node_tail(nest1);
    tex_couple_nodes(tail ? tail : nest1, newn);
    node_tail(nest1) = newn;
}

static void tex_aux_nesting_prepend(halfword nest1, halfword newn)
{
    halfword head = node_next(nest1);
    tex_couple_nodes(nest1, newn);
    if (head) {
        tex_couple_nodes(newn, head);
    } else {
        node_tail(nest1) = newn;
    }
}

static void tex_aux_nesting_prepend_list(halfword nest1, halfword newn)
{
    halfword head = node_next(nest1);
    halfword tail = tex_tail_of_node_list(newn);
    tex_couple_nodes(nest1, newn);
    if (head) {
        tex_couple_nodes(tail, head);
    } else {
        node_tail(nest1) = tail;
    }
}

int tex_valid_ligature(halfword left, halfword right, int *slot)
{
    if (node_type(left) != glyph_node) {
        return -1;
    } else if (glyph_font(left) != glyph_font(right)) {
        return -1;
    } else if (tex_has_glyph_option(left, glyph_option_no_right_ligature) || tex_has_glyph_option(right, glyph_option_no_left_ligature)) {
        return -1;
    } else {
        ligatureinfo lig = tex_get_ligature(glyph_font(left), glyph_character(left), glyph_character(right));
        if (ligature_is_valid(lig)) {
            *slot = ligature_replacement(lig);
            return ligature_type(lig);
        } else {
            return -1;
        }
    }
}

static int tex_aux_found_ligature(halfword left, halfword right)
{
    if (node_type(left) != glyph_node) {
        return 0;
    } else if (glyph_font(left) != glyph_font(right)) {
        return 0;
    } else if (tex_has_glyph_option(left, glyph_option_no_right_ligature) || tex_has_glyph_option(right, glyph_option_no_left_ligature)) {
        return 0;
    } else {
        return ligature_is_valid(tex_get_ligature(glyph_font(left), glyph_character(left), glyph_character(right)));
    }
}

/*tex
    We could be more efficient and reuse the possibly later removed node but it takes more code and
    we don't have that many ligatures anyway.
*/

static int tex_aux_try_ligature(halfword *first, halfword forward)
{
    halfword cur = *first;
    if (glyph_scale(cur) == glyph_scale(forward) && glyph_x_scale(cur) == glyph_x_scale(forward) && glyph_y_scale(cur) == glyph_y_scale(forward)) {
        halfword slot;
        halfword type = tex_valid_ligature(cur, forward, &slot);
        if (type >= 0) {
            int move_after = (type & 0x0C) >> 2;
            int keep_right = (type & 0x01) != 0;
            int keep_left = (type & 0x02) != 0;
            halfword parent = (glyph_character(cur) >= 0) ? cur : ((glyph_character(forward) >= 0) ? forward : null);
            halfword ligature = tex_new_glyph_node(glyph_ligature_subtype, glyph_font(cur), slot, parent);
            if (keep_left) {
                tex_couple_nodes(cur, ligature);
                if (move_after) {
                    move_after--;
                    cur = ligature;
                }
            } else {
                halfword prev = node_prev(cur);
                tex_uncouple_node(cur);
                tex_flush_node(cur);
                tex_couple_nodes(prev, ligature);
                cur = ligature;
            }
            if (keep_right) {
                tex_couple_nodes(ligature, forward);
                if (move_after) {
                    move_after--;
                    cur = forward;
                }
            } else {
                halfword next = node_next(forward);
                tex_uncouple_node(forward);
                tex_flush_node(forward);
                if (next) {
                    tex_couple_nodes(ligature, next);
                }
            }
            *first = cur;
            return 1;
        }
    }
    return 0;
}

/*tex

    There shouldn't be any ligatures here - we only add them at the end of |xxx_break| in a |DISC-1
    - DISC-2| situation and we stop processing |DISC-1| (we continue with |DISC-1|'s |post_| and
    |no_break|.

*/

static halfword tex_aux_handle_ligature_nesting(halfword root, halfword cur)
{
    if (cur) {
        while (node_next(cur)) {
            halfword fwd = node_next(cur);
            if (node_type(cur) == glyph_node && node_type(fwd) == glyph_node && glyph_font(cur) == glyph_font(fwd) && tex_aux_try_ligature(&cur, fwd)) {
                continue;
            }
            cur = node_next(cur);
        }
        node_tail(root) = cur;
    }
    return root;
}

/*tex

    In \LUATEX\ we have a chained variant of discretionaries (init and select) but that never really
    works out ok. It was there for basemode to be compatible with original \TEX\ but it was also means
    for border cases that in practice never occur. A least no \CONTEXT\ user ever complained about
    ligatures and hyphenation of these border cases. Keep in mind that in node mode (which we normally
    use) the select discs never showed up anyway. Another reason for dropping these discretionaries is
    that by not using them we get more predictable (or at least easier) handling of node lists that do
    have (any kind of) discretionaries. It is still on my agenda to look into nested discretionaries
    i.e. discs nodes in disc fields but it might never result in useable code.

    Remark: there is now a patch for \LUATEX\ that fixes some long pending issue with select discs but
    still it's kind of fuzzy. It also complicates the par builder in a way that I don't really want
    (at least in \CONTEXT). It was anyway a good reason for removing traces of these special disc nodes
    in \LUAMETATEX.

*/

static halfword tex_aux_handle_ligature_word(halfword cur)
{
    halfword right = null;
    if (node_type(cur) == boundary_node) {
        halfword prev = node_prev(cur);
        halfword fwd = node_next(cur);
        /*tex There is no need to uncouple |cur|, it is freed. */
        tex_flush_node(cur);
        if (fwd) {
            tex_couple_nodes(prev, fwd);
            if (node_type(fwd) != glyph_node) {
                return prev;
            } else {
                cur = fwd;
            }
        } else {
            node_next(prev) = fwd;
            return prev;
        }
    } else if (font_has_left_boundary(glyph_font(cur))) {
        halfword prev = node_prev(cur);
        halfword p = tex_new_glyph_node(glyph_unset_subtype, glyph_font(cur), left_boundary_char, cur);
        tex_couple_nodes(prev, p);
        tex_couple_nodes(p, cur);
        cur = p;
    }
    if (font_has_right_boundary(glyph_font(cur))) {
        right = tex_new_glyph_node(glyph_unset_subtype, glyph_font(cur), right_boundary_char, cur);
    }
    /* todo: switch */
    while (1) {
        halfword t = node_type(cur);
        /*tex A glyph followed by \unknown */
        if (t == glyph_node) {
            halfword fwd = node_next(cur);
            if (fwd) {
                t = node_type(fwd);
                if (t == glyph_node) {
                    /*tex a glyph followed by a glyph */
                    if (glyph_font(cur) != glyph_font(fwd)) {
                        break;
                    } else if (tex_aux_try_ligature(&cur, fwd)) {
                        continue;
                    }
                } else if (t == disc_node) {
                    /*tex a glyph followed by a disc */
                    halfword pre = disc_pre_break_head(fwd);
                    halfword nob = disc_no_break_head(fwd);
                    halfword next, tail;
                    /*tex Check on: |a{b?}{?}{?}| and |a+b=>B| : |{B?}{?}{a?}| */
                    /*tex Check on: |a{?}{?}{b?}| and |a+b=>B| : |{a?}{?}{B?}| */
                    if ((pre && node_type(pre) == glyph_node && tex_aux_found_ligature(cur, pre))
                     || (nob && node_type(nob) == glyph_node && tex_aux_found_ligature(cur, nob))) {
                        /*tex Move |cur| from before disc to skipped part */
                        halfword prev = node_prev(cur);
                        tex_uncouple_node(cur);
                        tex_couple_nodes(prev, fwd);
                        tex_aux_nesting_prepend(disc_no_break(fwd), cur);
                        /*tex Now ligature the |pre_break|. */
                        tex_aux_nesting_prepend(disc_pre_break(fwd), tex_copy_node(cur));
                        /*tex As we have removed cur, we need to start again. */
                        cur = prev;
                    }
                    /*tex Check on: |a{?}{?}{}b| and |a+b=>B| : |{a?}{?b}{B}|. */
                    next = node_next(fwd);
                    if ((! nob) && next && node_type(next) == glyph_node && tex_aux_found_ligature(cur, next)) {
                        /*tex Move |cur| from before |disc| to |no_break| part. */
                        halfword prev = node_prev(cur);
                        tex_uncouple_node(cur);
                        tex_couple_nodes(prev, fwd);
                        /*tex We {\em know} it's empty. */
                        tex_couple_nodes(disc_no_break(fwd), cur);
                        /*tex Now copy |cur| the |pre_break|. */
                        tex_aux_nesting_prepend(disc_pre_break(fwd), tex_copy_node(cur));
                        /*tex Move next from after disc to |no_break| part. */
                        tail = node_next(next);
                        tex_uncouple_node(next);
                        tex_try_couple_nodes(fwd, tail);
                        /*tex We {\em know} this works. */
                        tex_couple_nodes(cur, next);
                        /*tex Make sure the list is correct. */
                        disc_no_break_tail(fwd) = next;
                        /*tex Now copy next to the |post_break|. */
                        tex_aux_nesting_append(disc_post_break(fwd), tex_copy_node(next));
                        /*tex As we have removed cur, we need to start again. */
                        cur = prev;
                    }
                    /*tex We are finished with the |pre_break|. */
                    tex_aux_handle_ligature_nesting(disc_pre_break(fwd), disc_pre_break_head(fwd));
                } else if (t == boundary_node) {
                    halfword next = node_next(fwd);
                    tex_try_couple_nodes(cur, next);
                    tex_flush_node(fwd);
                    if (right) {
                        /*tex Shame, didn't need it. */
                        tex_flush_node(right);
                        /*tex No need to reset |right|, we're going to leave the loop anyway. */
                    }
                    break;
                } else if (right) {
                    tex_couple_nodes(cur, right);
                    tex_couple_nodes(right, fwd);
                    right = null;
                    continue;
                } else {
                    break;
                }
            } else {
                /*tex The last character of a paragraph. */
                if (right) {
                    /*tex |par| prohibits the use of |couple_nodes| here. */
                    tex_try_couple_nodes(cur, right);
                    right = null;
                    continue;
                } else {
                    break;
                }
            }
            /*tex A discretionary followed by \unknown */
        } else if (t == disc_node) {
            /*tex If |{?}{x}{?}| or |{?}{?}{y}| then: */
            if (disc_no_break_head(cur) || disc_post_break_head(cur)) {
                halfword fwd;
                if (disc_post_break_head(cur)) {
                    tex_aux_handle_ligature_nesting(disc_post_break(cur), disc_post_break_head(cur));
                }
                if (disc_no_break_head(cur)) {
                    tex_aux_handle_ligature_nesting(disc_no_break(cur), disc_no_break_head(cur));
                }
                fwd = node_next(cur);
                while (fwd) {
                    if (node_type(fwd) == glyph_node) {
                        halfword nob = disc_no_break_tail(cur);
                        halfword pst = disc_post_break_tail(cur);
                        if ((! nob || ! tex_aux_found_ligature(nob, fwd)) && (! pst || ! tex_aux_found_ligature(pst, fwd))) {
                            break;
                        } else {
                            halfword next = node_next(fwd);
                            tex_aux_nesting_append(disc_no_break(cur), tex_copy_node(fwd));
                            tex_aux_handle_ligature_nesting(disc_no_break(cur), nob);
                            tex_uncouple_node(fwd);
                            tex_try_couple_nodes(cur, next);
                            tex_aux_nesting_append(disc_post_break(cur), fwd);
                            tex_aux_handle_ligature_nesting(disc_post_break(cur), pst);
                            fwd = node_next(cur);
                        }
                    } else {
                        break;
                    }
                }
                if (fwd && node_type(fwd) == disc_node) {
                    /*tex This only deals with simple pre-only discretionaries and a following glyph. */
                    halfword next = node_next(fwd);
                    if (next
                        && ! disc_no_break_head(fwd)
                        && ! disc_post_break_head(fwd)
                        && node_type(next) == glyph_node
                        && ((disc_post_break_tail(cur) && tex_aux_found_ligature(disc_post_break_tail(cur), next)) ||
                            (disc_no_break_tail  (cur) && tex_aux_found_ligature(disc_no_break_tail  (cur), next)))) {
                        halfword last = node_next(next);
                        tex_uncouple_node(next);
                        tex_try_couple_nodes(fwd, last);
                        /*tex Just a hidden flag, used for (base mode) experiments. */
                        if (hyphenation_permitted(hyphenation_mode_par, lazy_ligatures_hyphenation_mode)) {
                            /*tex f-f-i -> f-fi */
                            halfword tail = disc_no_break_tail(cur);
                            tex_aux_nesting_append(disc_no_break(cur), tex_copy_node(next));
                            tex_aux_handle_ligature_nesting(disc_no_break(cur), tail);
                            tail = disc_post_break_tail(cur);
                            tex_aux_nesting_append(disc_post_break(cur), next);
                            tex_aux_handle_ligature_nesting(disc_post_break(cur), tail);
                            tex_try_couple_nodes(node_prev(fwd), node_next(fwd));
                            tex_flush_node(fwd);
                        } else {
                            /*tex f-f-i -> ff-i : |{a-}{b}{AB} {-}{c}{}| => |{AB-}{c}{ABc}| */
                            tex_aux_nesting_append(disc_post_break(fwd), tex_copy_node(next));
                            if (disc_no_break_head(cur)) {
                                halfword tail;
                                tex_aux_nesting_prepend_list(disc_no_break(fwd), tex_copy_node_list(disc_no_break_head(cur), null));
                                tail = disc_no_break_tail(fwd);
                                tex_aux_nesting_append(disc_no_break(fwd), next);
                                tex_aux_handle_ligature_nesting(disc_no_break(fwd), tail);
                                tex_aux_nesting_prepend_list(disc_pre_break(fwd), tex_copy_node_list(disc_no_break_head(cur), null));
                            }
                            tex_try_couple_nodes(node_prev(cur), node_next(cur));
                            tex_flush_node(cur);
                            cur = fwd;
                        }
                    }
                }
            }
        } else {
            /*tex We have glyph nor disc. */
            return cur;
        }
        /*tex Goto the next node, where |\par| allows |node_next(cur)| to be NULL. */
        cur = node_next(cur);
    }
    return cur;
}


/*tex The return value is the new tail, head should be a dummy: */

halfword tex_handle_ligaturing(halfword head, halfword tail)
{
    if (node_next(head)) {
        /*tex A trick to allow explicit |node == null| tests. */
        halfword save_tail = null;
        halfword cur, prev;
        if (tail) {
            save_tail = node_next(tail);
            node_next(tail) = null;
        }
        prev = head;
        cur = node_next(prev);
        while (cur) {
            if (node_type(cur) == glyph_node || node_type(cur) == boundary_node) {
                cur = tex_aux_handle_ligature_word(cur);
            }
            prev = cur;
            cur = node_next(cur);
        }
        if (! prev) {
            prev = tail;
        }
        tex_try_couple_nodes(prev, save_tail);
     // if (tail) {
     // }
        return prev;
    } else {
        return tail;
    }
}

/*tex Kerning starts here: */

static void tex_aux_add_kern_before(halfword left, halfword right)
{
    if (
            glyph_font(left) == glyph_font(right) &&
            glyph_scale(left) == glyph_scale(right) &&
            glyph_x_scale(left) == glyph_x_scale(right) &&
            glyph_y_scale(left) == glyph_y_scale(right) &&
            ! tex_has_glyph_option(left, glyph_option_no_right_kern) &&
            ! tex_has_glyph_option(right, glyph_option_no_left_kern) &&
            tex_has_kern(glyph_font(left), glyph_character(left))
        ) {
        scaled k = tex_raw_get_kern(glyph_font(left), glyph_character(left), glyph_character(right));
        if (k) {
            scaled kern = tex_new_kern_node(k, font_kern_subtype);
            halfword prev = node_prev(right);
            tex_couple_nodes(prev, kern);
            tex_couple_nodes(kern, right);
            tex_attach_attribute_list_copy(kern, left);
        }
    }
}

static void tex_aux_add_kern_after(halfword left, halfword right, halfword aft)
{
    if (
            glyph_font(left) == glyph_font(right) &&
            glyph_scale(left) == glyph_scale(right) &&
            glyph_x_scale(left) == glyph_x_scale(right) &&
            glyph_y_scale(left) == glyph_y_scale(right) &&
            ! tex_has_glyph_option(left, glyph_option_no_right_kern) &&
            ! tex_has_glyph_option(right, glyph_option_no_left_kern) &&
            tex_has_kern(glyph_font(left), glyph_character(left))
        ) {
        scaled k = tex_raw_get_kern(glyph_font(left), glyph_character(left), glyph_character(right));
        if (k) {
            scaled kern = tex_new_kern_node(k, font_kern_subtype);
            halfword next = node_next(aft);
            tex_couple_nodes(aft, kern);
            tex_try_couple_nodes(kern, next);
            tex_attach_attribute_list_copy(kern, aft);
        }
    }
}

static void tex_aux_do_handle_kerning(halfword root, halfword init_left, halfword init_right)
{
    halfword cur = node_next(root);
    if (cur) {
        halfword left = null;
        if (node_type(cur) == glyph_node) {
            if (init_left) {
                tex_aux_add_kern_before(init_left, cur);
            }
            left = cur;
        }
        cur = node_next(cur);
        while (cur) {
            halfword t = node_type(cur);
            if (t == glyph_node) {
                if (left) {
                    tex_aux_add_kern_before(left, cur);
                    if (glyph_character(left) < 0) {
                        halfword prev = node_prev(left);
                        tex_couple_nodes(prev, cur);
                        tex_flush_node(left);
                    }
                }
                left = cur;
            } else {
                if (t == disc_node) {
                    halfword right = node_type(node_next(cur)) == glyph_node ? node_next(cur) : null;
                    tex_aux_do_handle_kerning(disc_pre_break(cur), left, null);
                    if (disc_pre_break_head(cur)) {
                        disc_pre_break_tail(cur) = tex_tail_of_node_list(disc_pre_break_head(cur));
                    }
                    tex_aux_do_handle_kerning(disc_post_break(cur), null, right);
                    if (disc_post_break_head(cur)) {
                        disc_post_break_tail(cur) = tex_tail_of_node_list(disc_post_break_head(cur));
                    }
                    tex_aux_do_handle_kerning(disc_no_break(cur), left, right);
                    if (disc_no_break_head(cur)) {
                        disc_no_break_tail(cur) = tex_tail_of_node_list(disc_no_break_head(cur));
                    }
                }
                if (left) {
                    if (glyph_character(left) < 0) {
                        halfword prev = node_prev(left);
                        tex_couple_nodes(prev, cur);
                        tex_flush_node(left);
                    }
                    left = null;
                }
            }
            cur = node_next(cur);
        }
        if (left) {
            if (init_right) {
                tex_aux_add_kern_after(left, init_right, left);
            }
            if (glyph_character(left) < 0) {
                halfword prev = node_prev(left);
                halfword next = node_next(left);
                if (next) {
                    tex_couple_nodes(prev, next);
                    node_tail(root) = next;
                } else if (prev != root) {
                    node_next(prev) = null;
                    node_tail(root) = prev;
                } else {
                    node_next(root) = null;
                    node_tail(root) = null;
                }
                tex_flush_node(left);
            }
        }
    } else if (init_left && init_right ) {
        tex_aux_add_kern_after(init_left, init_right, root);
        node_tail(root) = node_next(root);
    }
}

halfword tex_handle_kerning(halfword head, halfword tail)
{
    halfword save_link = null;
    if (tail) {
        save_link = node_next(tail);
        node_next(tail) = null;
        node_tail(head) = tail;
        tex_aux_do_handle_kerning(head, null, null);
        tail = node_tail(head);
        if (tex_valid_node(save_link)) {
            /* no need for check */
            tex_try_couple_nodes(tail, save_link);
        }
    } else {
        node_tail(head) = null;
        tex_aux_do_handle_kerning(head, null, null);
    }
    return tail;
}

/*tex The ligaturing and kerning \LUA\ interface: */

static halfword tex_aux_run_lua_ligkern_callback(lua_State *L, halfword head, halfword group, halfword direction, int callback_id)
{
    int top = 0;
    if (lmt_callback_okay(L, callback_id, &top)) {
        int i;
        lmt_node_list_to_lua(L, head);
        lmt_push_group_code(L, group);
        lua_pushinteger(L, direction);
        i = lmt_callback_call(L, 3, 1, top);
        if (i) {
            lmt_callback_error(L, top, i);
        } else {
            head = lmt_node_list_from_lua(L, -1);
            lmt_callback_wrapup(L, top);
        }
    }
    return head;
}

halfword tex_handle_glyphrun(halfword head, halfword group, halfword direction)
{
    if (head) {
        int callback_id = lmt_callback_defined(glyph_run_callback);
        if (callback_id) {
            return tex_aux_run_lua_ligkern_callback(lmt_lua_state.lua_instance, head, group, direction, callback_id);
        } else {
            callback_id = lmt_callback_defined(ligaturing_callback);
            if (callback_id) {
                head = tex_aux_run_lua_ligkern_callback(lmt_lua_state.lua_instance, head, group, direction, callback_id);
            } else {
                tex_handle_ligaturing(head, null);
            }
            callback_id = lmt_callback_defined(kerning_callback);
            if (callback_id) {
                head = tex_aux_run_lua_ligkern_callback(lmt_lua_state.lua_instance, head, group, direction, callback_id);
            } else {
                halfword nest = tex_new_node(nesting_node, unset_nesting_code);
                tex_couple_nodes(nest, head);
                tex_aux_do_handle_kerning(nest, null, null);
                head = node_next(nest);
                node_prev(head) = null;
                node_next(nest) = null;
                tex_flush_node(nest);
            }
        }
    }
    return head;
}

/*tex

    When the user defines |\font\f|, say, \TEX\ assigns an internal number to the user's font |\f|.
    Adding this number to |font_id_base| gives the |eqtb| location of a \quote {frozen} control
    sequence that will always select the
    font.

    The variable |a| in the following code indicates the global nature of the value to be set. It's
    used in the |define| macro. Here we're never global.

    There's not much scanner code here because the other scanners are defined where they make most
    sense.

*/

void tex_set_cur_font(halfword g, halfword f)
{
    update_tex_font(g, f);
}

/*tex

    Because we do fonts in \LUA\ we can decide to drop this one and assume a definition using the
    token scanner. It also avoids the filename (split) mess.

*/

int tex_tex_def_font(int a)
{
    if (! lmt_fileio_state.job_name) {
        /*tex Avoid confusing |texput| with the font name. */
        tex_open_log_file();
    }
    tex_get_r_token();
    if (tex_define_permitted(cur_cs, a)) {
        /*tex The user's font identifier. */
        halfword u = cur_cs;
        /*tex This runs through existing fonts. */
        halfword f;
        /*tex Stated 'at' size, or negative of scaled magnification. */
        scaled s = -1000;
        char *fn;
        /*tex Here |a| detemines if we define global or not. */
        if (is_global(a)) {
            update_tex_font_global(u, null_font);
        } else {
            update_tex_font_local(u, null_font);
        }
        fn = tex_read_file_name(1, NULL, NULL);
        /*tex Scan the font size specification. */
        lmt_fileio_state.name_in_progress = 1;
        if (tex_scan_keyword("at")) {
            /*tex Put the positive 'at' size into |s|. */
            s = tex_scan_dimen(0, 0, 0, 0, NULL);
            if ((s <= 0) || (s >= 01000000000)) {
                tex_handle_error(
                    normal_error_type,
                    "Improper 'at' size (%D), replaced by 10pt",
                    s,
                    pt_unit,
                    "I can only handle fonts at positive sizes that are less than 2048pt, so I've\n"
                    "changed what you said to 10pt." 
                );
                s = 10 * unity;
            }
        } else if (tex_scan_keyword("scaled")) {
            s = tex_scan_int(0, NULL);
            if ((s <= 0) || (s > 32768)) {
                tex_handle_error(
                    normal_error_type,
                    "Illegal magnification has been changed to 1000 (%i)",
                    s,
                    "The magnification ratio must be between 1 and 32768."
                );
                s = -1000;
            } else {
                s = -s;
            }
        }
        lmt_fileio_state.name_in_progress = 0;
        f = tex_read_font_info(fn, s);
        eq_value(u) = f;
        lmt_memory_free(fn);
        return 1;
    } else {
        return 0;
    }
}

/*tex

    When \TEX\ wants to typeset a character that doesn't exist, the character node is not created;
    thus the output routine can assume that characters exist when it sees them. The following
    procedure prints a warning message unless the user has suppressed it.

*/

void tex_char_warning(halfword f, int c)
{
    if (tracing_lost_chars_par > 0) {
        /*tex saved value of |tracing_online| */
        int old_setting = tracing_online_par;
        /*tex index to current digit; we assume that $0\L n<16^{22}$ */
        if (tracing_lost_chars_par > 1) {
            tracing_online_par = 1;
        }
        tex_begin_diagnostic();
        tex_print_format("[font: missing character, character %c (%U), font '%s']", c, c, font_name(f));
        tex_end_diagnostic();
        tracing_online_par = old_setting;
    }
}

/* Getters. */

scaled tex_char_width_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->width;
}

scaled tex_char_height_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->height;
}

scaled tex_char_depth_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->depth;
}

scaled tex_char_total_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->height + ci->depth;
}

scaled tex_char_italic_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->italic;
}


// scaled tex_char_options_from_font(halfword f, halfword c)
// {
//     charinfo *ci = tex_aux_char_info(f, c);
//     return ci->math ? ci->math->options : 0;
// }
//
// int tex_char_has_option_from_font(halfword f, halfword c, int option)
// {
//     charinfo *ci = tex_aux_char_info(f, c);
//     return ci->math ? math_font_option(ci->math->options, option) : 0;
// }

scaledwhd tex_char_whd_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return (scaledwhd) {
        .wd = ci->width,
        .ht = ci->height,
        .dp = ci->depth,
        .ic = ci->italic
    };
}

scaled tex_char_ef_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->expansion;
}

scaled tex_char_lp_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->leftprotrusion;
}

scaled tex_char_rp_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->rightprotrusion;
}

halfword tex_char_has_tag_from_font(halfword f, halfword c, halfword tag)
{
    return (charinfo_tag(tex_aux_char_info(f, c)->tagrem) & tag) == tag;
}

void tex_char_reset_tag_from_font(halfword f, halfword c, halfword tag)
{
    charinfo *ci = tex_aux_char_info(f, c);
 // tag = charinfo_tag(ci->tagrem) & ~(tag | charinfo_tag(ci->tagrem));
    tag = charinfo_tag(ci->tagrem) & ~(tag);
    ci->tagrem = charinfo_tagrem(tag,charinfo_rem(ci->tagrem));
    
}

halfword tex_char_tag_from_font(halfword f, halfword c)
{
    return charinfo_tag(tex_aux_char_info(f, c)->tagrem);
}

halfword tex_char_remainder_from_font(halfword f, halfword c)
{
    return charinfo_rem(tex_aux_char_info(f, c)->tagrem);
}

halfword tex_char_vertical_italic_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->vertical_italic : INT_MIN;
}

halfword tex_char_unchecked_top_anchor_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->top_anchor : INT_MIN;
}

halfword tex_char_top_anchor_from_font(halfword f, halfword c)
{
    scaled n = tex_char_unchecked_top_anchor_from_font(f, c);
    return n == INT_MIN ? 0 : n;
}

halfword tex_char_unchecked_bottom_anchor_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->bottom_anchor : INT_MIN;
}

halfword tex_char_bottom_anchor_from_font(halfword f, halfword c)
{
    scaled n = tex_char_unchecked_bottom_anchor_from_font(f, c);
    return n == INT_MIN ? 0 : n;
}

halfword tex_char_flat_accent_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->flat_accent : INT_MIN;
}

scaled tex_char_top_left_kern_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->top_left_kern : 0;
}

scaled tex_char_top_right_kern_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->top_right_kern : 0;
}

scaled tex_char_bottom_left_kern_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->bottom_left_kern : 0;
}

scaled tex_char_bottom_right_kern_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->bottom_right_kern : 0;
}

extinfo *tex_char_vertical_parts_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->vertical_parts : NULL;
}

extinfo *tex_char_horizontal_parts_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->horizontal_parts : NULL;
}

scaled tex_char_left_margin_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->left_margin : 0;
}

scaled tex_char_right_margin_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->right_margin : 0;
}

scaled tex_char_top_margin_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->top_margin : 0;
}

scaled tex_char_bottom_margin_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->bottom_margin : 0;
}

scaled tex_char_top_overshoot_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->top_overshoot : 0;
}

scaled tex_char_bottom_overshoot_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->bottom_overshoot : 0;
}

/* Nodes */

scaled tex_char_width_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return tex_aux_glyph_x_scaled(g, ci->width);
}

scaled tex_char_height_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return tex_aux_glyph_y_scaled(g, ci->height);
}

scaled tex_char_depth_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return tex_aux_glyph_y_scaled(g, ci->depth);
}

scaled tex_char_total_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return tex_aux_glyph_y_scaled(g, ci->height + ci->depth);
}

scaled tex_char_italic_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return tex_aux_glyph_x_scaled(g, ci->italic);
}

// halfword tex_char_options_from_glyph(halfword g)
// {
//     charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
//     return ci->math ? ci->math->options : 0;
// }

// int tex_char_has_option_from_glyph(halfword g, int t)
// {
//     if (node_type(g) == glyph_node) {
//         charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
//         return ci->math ? math_font_option(ci->math->options, t) : 0;
//     } else {
//         return 0;
//     }
// }

scaledwhd tex_char_whd_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return (scaledwhd) {
        .wd = tex_aux_glyph_x_scaled(g, ci->width),
        .ht = tex_aux_glyph_y_scaled(g, ci->height),
        .dp = tex_aux_glyph_y_scaled(g, ci->depth),
        .ic = tex_aux_glyph_x_scaled(g, ci->italic)
    };
}

scaled tex_char_width_italic_from_glyph(halfword g)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    return tex_aux_glyph_x_scaled(g, ci->width + ci->italic);
}

/* More */

scaled tex_calculated_char_width(halfword f, halfword c, halfword ex)
{
    scaled wd = tex_aux_char_info(f, c)->width;
    return ex ? tex_round_xn_over_d(wd, 1000 + ex, 1000) : wd;
}

scaled tex_calculated_glyph_width(halfword g, halfword ex)
{
    charinfo *ci = tex_aux_char_info(glyph_font(g), glyph_character(g));
    scaled wd = tex_aux_glyph_x_scaled(g, ci->width);
    return ex ? tex_round_xn_over_d(wd, 1000 + ex, 1000) : wd;
}

/* Checkers: */

int tex_has_ligature(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci ? ci->ligatures != NULL : 0;
}

int tex_has_kern(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci ? ci->kerns != NULL : 0;
}

int tex_char_has_math(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci ? ci->math != NULL : 0;
}

/* Setters: */

void tex_set_lpcode_in_font(halfword f, halfword c, halfword i)
{
    charinfo *ci = tex_aux_char_info(f, c);
    if (ci) {
        ci->leftprotrusion = i;
    }
}

void tex_set_rpcode_in_font(halfword f, halfword c, halfword i)
{
    charinfo *ci = tex_aux_char_info(f, c);
    if (ci) {
        ci->rightprotrusion = i;
    }
}

void tex_set_efcode_in_font(halfword f, halfword c, halfword i) {
    charinfo *ci = tex_aux_char_info(f, c);
    if (ci) {
        ci->expansion = i;
    }
}

void tex_set_font_name(halfword f, const char *s)
{
    if (font_name(f)) {
        lmt_memory_free(font_name(f));
    }
    set_font_name(f, s ? lmt_memory_strdup(s) : NULL);
}

void tex_set_font_original(halfword f, const char *s)
{
    if (font_original(f)) {
        lmt_memory_free(font_original(f));
    }
    set_font_original(f, s ? lmt_memory_strdup(s) : NULL);
}

scaled tex_get_math_font_scale(halfword f, halfword size)
{
    scaled scale = 1000;
    switch (size) {
        case 2: scale = lmt_font_state.fonts[f]->mathscales[2] ? lmt_font_state.fonts[f]->mathscales[2] : glyph_scriptscript_scale_par; break;
        case 1: scale = lmt_font_state.fonts[f]->mathscales[1] ? lmt_font_state.fonts[f]->mathscales[1] : glyph_script_scale_par;       break;
        case 0: scale = lmt_font_state.fonts[f]->mathscales[0] ? lmt_font_state.fonts[f]->mathscales[0] : glyph_text_scale_par;         break;
    }
    return scale ? scale : 1000;
}

/*tex
    Experiment.
*/

void tex_run_font_spec(void)
{
    update_tex_font_identifier(font_spec_identifier(cur_chr));
    if (font_spec_scale(cur_chr) != unused_scale_value) {
        update_tex_glyph_scale(font_spec_scale(cur_chr));
    }
    if (font_spec_x_scale(cur_chr) != unused_scale_value) {
        update_tex_glyph_x_scale(font_spec_x_scale(cur_chr));
    }
    if (font_spec_y_scale(cur_chr) != unused_scale_value) {
        update_tex_glyph_y_scale(font_spec_y_scale(cur_chr));
    }
}

