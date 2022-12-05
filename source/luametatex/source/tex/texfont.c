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

/*tex 
    Finally the base mode ligaturing and kerning code has also been made more consistent with the 
    rest: abstraction, more tight equality testing, helpers, merged some experiments, etc. It will 
    probably evolve a bit more; not that we use basemode frequently in \CONTEXT. Keep in mind that 
    it is not that hard to mess up the list when using \LUA\ but we do little checking here. 

    From now on base mode ligaturing and kerning will only be applied when |text_font_control| 
    have the |text_control_base_ligaturing| and |text_control_base_kerning| bits set. 
*/

inline static halfword tex_aux_discretionary_node(halfword target, int location)
{
    switch (location) {
        case pre_break_code : return disc_pre_break_node(target); 
        case post_break_code: return disc_post_break_node(target);
        case no_break_code  : return disc_no_break_node(target);  
        default             : return null;     
    }
}

inline static int tex_aux_same_font_properties(halfword a, halfword b) // also in kern 
{
    return node_type(a) == glyph_node && node_type(b) == glyph_node 
     && glyph_font(a)    == glyph_font(b)
     && glyph_x_scale(a) == glyph_x_scale(b)
     && glyph_y_scale(a) == glyph_y_scale(b)
     && glyph_scale(a)   == glyph_scale(b);
}

inline static int tex_aux_apply_base_kerning(halfword n)
{
    if (glyph_protected(n)) {
        return 0;
    } else {
        halfword f = glyph_font(n);
        if (f >= 0 && f <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[f]) { 
            return has_font_text_control(f, text_control_base_kerning);
        } else {
            return 0;
        }
    }
}

inline static int tex_aux_apply_base_ligaturing(halfword n)
{
    if (glyph_protected(n)) {
        return 0;
    } else {
        halfword f = glyph_font(n);
        if (f >= 0 && f <= lmt_font_state.font_data.ptr && lmt_font_state.fonts[f]) { 
            return has_font_text_control(f, text_control_base_ligaturing);
        } else {
            return 0;
        }
    }
}

/* */

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

void tex_set_charinfo_extensible_recipe(charinfo *ci, extinfo *ext)
{
    if (ci->math) {
        extinfo *list = ci->math->extensible_recipe;
        if (list) {
            while (list) {
                extinfo *c = list->next;
                lmt_memory_free(list);
                list = c;
            }
        }
        ci->math->extensible_recipe = ext;
    }
}

void tex_set_font_parameters(halfword f, int index)
{
    int i = font_parameter_count(f);
    if (index > i) {
        /*tex If really needed this can be a calloc. */
        int size = (index + 2) * (int) sizeof(int);
        int *list = lmt_memory_realloc(font_parameter_base(f), (size_t) size);
        if (list) {
            lmt_font_state.font_data.allocated += (index - i + 1) * (int) sizeof(scaled);
            font_parameter_base(f) = list;
            font_parameter_count(f) = index;
            while (i < index) {
                font_parameter(f, ++i) = 0;
            }
        } else {
            tex_overflow_error("font", size);
        }
    }
}

/*tex Most stuff is zero: */

int tex_new_font(void)
{
    int size = sizeof(charinfo);
    charinfo *ci = lmt_memory_calloc(1, (size_t) size);
    if (ci) {
        texfont *tf = NULL;
        size = sizeof(texfont);
        tf = lmt_memory_calloc(1, (size_t) size);
        if (tf) {
            sa_tree_item sa_value = { 0 };
            int id = tex_new_font_id();
            lmt_font_state.font_data.allocated += size;
            lmt_font_state.fonts[id] = tf;
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
            for (int i = 0; i <= 7; i++) {
                tex_set_font_parameter(id, i, 0);
            }
            /*tex character info zero is reserved for |notdef|. The stack size 1, default item value 0. */
            tf->characters = sa_new_tree(1, 4, sa_value);
            tf->chardata = ci;
            tf->chardata_size = 1;
            return id;
        }
    }
    tex_overflow_error("font", size);
    return 0;
}

void tex_font_malloc_charinfo(halfword f, int index)
{
    int glyph = lmt_font_state.fonts[f]->chardata_size;
    int size = (glyph + index) * sizeof(charinfo);
    charinfo *data = lmt_memory_realloc(lmt_font_state.fonts[f]->chardata , (size_t) size);
    if (data) {
        lmt_font_state.font_data.allocated += index * sizeof(charinfo);
        lmt_font_state.fonts[f]->chardata = data;
        memset(&data[glyph], 0, (size_t) index * sizeof(charinfo));
        lmt_font_state.fonts[f]->chardata_size += index;
    } else {
        tex_overflow_error("font", size);
    }
}

void tex_char_malloc_mathinfo(charinfo *ci)
{
    int size = sizeof(mathinfo);
    mathinfo *mi = lmt_memory_calloc(1, (size_t) size);
    if (mi) {
        mi->extensible_recipe = NULL;
        /* */
        mi->top_left_math_kern_array = NULL;
        mi->top_right_math_kern_array = NULL;
        mi->bottom_right_math_kern_array = NULL;
        mi->bottom_left_math_kern_array = NULL;
        /* zero annyway: */
        mi->top_left_kern = 0;
        mi->top_right_kern = 0;
        mi->bottom_left_kern = 0;
        mi->bottom_right_kern = 0;
        /* */
        mi->left_margin = 0;
        mi->right_margin = 0;
        mi->top_margin = 0;
        mi->bottom_margin = 0;
        /* */
        mi->top_overshoot = INT_MIN;
        mi->bottom_overshoot = INT_MIN;
        if (ci->math) {
            /*tex This seldom or probably never happens. */
            tex_set_charinfo_extensible_recipe(ci, NULL);
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

inline int aux_find_charinfo_id(halfword f, int c) 
{
    sa_tree_item item; 
    sa_get_item_4(lmt_font_state.fonts[f]->characters, c, &item);
    return (int) item.int_value;
}

charinfo *tex_get_charinfo(halfword f, int c)
{
    if (proper_char_index(f, c)) {
        sa_tree_item item; 
        sa_get_item_4(lmt_font_state.fonts[f]->characters, c, &item);
        int glyph = (int) item.int_value;
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
        return &(lmt_font_state.fonts[f]->chardata[(int) aux_find_charinfo_id(f, c)]);
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
        return (int) aux_find_charinfo_id(f, c);
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
        if (s && proper_char_index(f, s) && aux_find_charinfo_id(f, s)) {
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
    int id = aux_find_charinfo_id(f, c);
    texfont *tf = lmt_font_state.fonts[f];
    if (id) { 
        /* */
        if (direction) { 
            charinfo *ci = &tf->chardata[id];
            int m = ci->math->mirror;
            if (m && proper_char_index(f, m)) {
                int mid = aux_find_charinfo_id(f, m);
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
                        id = aux_find_charinfo_id(f, s);
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

void tex_append_charinfo_extensible_recipe(charinfo *ci, int glyph, int startconnect, int endconnect, int advance, int extender)
{
    if (ci->math) {
        int size = sizeof(extinfo);
        extinfo *ext = lmt_memory_malloc((size_t) size);
        if (ext) {
            extinfo *lst = ci->math->extensible_recipe;
            ext->next = NULL;
            ext->glyph = glyph;
            ext->start_overlap = startconnect;
            ext->end_overlap = endconnect;
            ext->advance = advance;
            ext->extender = extender;
            if (lst) {
                while (lst->next) {
                    lst = lst->next;
                }
                lst->next = ext;
            } else {
                ci->math->extensible_recipe = ext;
            }
        } else {
            tex_overflow_error("font", size);
        }
    }
}

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

    \starttyping
    void tex_set_charinfo_extensible(charinfo *ci, int top, int bottom, int middle, int extender)
    {
        if (ci->math) {
            extinfo *ext;
            tex_set_charinfo_extensible_recipe(ci, NULL);
            if (bottom == 0 && top == 0 && middle == 0 && extender != 0) {
                ext = tex_new_charinfo_extensible_step(extender, 0, 0, 0, math_extension_normal);
                tex_add_charinfo_extensible_step(ci, ext);
                ext = tex_new_charinfo_extensible_step(extender, 0, 0, 0, math_extension_repeat);
                tex_add_charinfo_extensible_step(ci, ext);
            } else {
                if (bottom) {
                    ext = tex_new_charinfo_extensible_step(bottom, 0, 0, 0, math_extension_normal);
                    tex_add_charinfo_extensible_step(ci, ext);
                }
                if (extender) {
                    ext = tex_new_charinfo_extensible_step(extender, 0, 0, 0, math_extension_repeat);
                    tex_add_charinfo_extensible_step(ci, ext);
                }
                if (middle) {
                    ext = tex_new_charinfo_extensible_step(middle, 0, 0, 0, math_extension_normal);
                    tex_add_charinfo_extensible_step(ci, ext);
                    if (extender) {
                        ext = tex_new_charinfo_extensible_step(extender, 0, 0, 0, math_extension_repeat);
                        tex_add_charinfo_extensible_step(ci, ext);
                    }
                }
                if (top) {
                    ext = tex_new_charinfo_extensible_step(top, 0, 0, 0, math_extension_normal);
                    tex_add_charinfo_extensible_step(ci, ext);
                }
            }
        }
    }
    \stoptyping
*/

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
            if (tex_char_exists(f, i)) {
                charinfo *co = tex_aux_char_info(f, i);
                set_charinfo_kerns(co, NULL);
                set_charinfo_ligatures(co, NULL);
                if (co->math) {
                    tex_set_charinfo_extensible_recipe(co, NULL);
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

/*tex This returns the multiple of |font_step(f)| that is nearest to |e|. */

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

static void tex_aux_discretionary_append(halfword target, int location, halfword n)
{
    halfword node = tex_aux_discretionary_node(target, location);
    if (node_tail(node)) { 
        tex_couple_nodes(node_tail(node), n);
    } else { 
        node_head(node) = n;
    }
    node_tail(node) = n;
}

static void tex_aux_discretionary_prepend(halfword target, int location, halfword n)
{
    halfword node = tex_aux_discretionary_node(target, location);
    if (node_head(node)) { 
        tex_couple_nodes(n, node_head(node));
    } else {
        node_tail(node) = n;
    } 
    node_head(node) = n;
}

static void tex_aux_nesting_prepend_list(halfword target, int location, halfword n) /* n is prepended to target */
{
    halfword node = tex_aux_discretionary_node(target, location);
    halfword copy = tex_copy_node_list(n, null);
    halfword tail = tex_tail_of_node_list(copy);
    if (node_head(node)) {
        tex_couple_nodes(tail, node_head(node));
    } else { 
        node_tail(node) = tail;
    }
    node_head(node) = copy;
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
    if (! left || ! right) {
        return 0;
    } else if (node_type(left) != glyph_node || node_type(right) != glyph_node) {
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
    In principle we only support simple ligatures, i.e.\ |move_after|, |keep_right| and |keep_left|
    are zero. At some point we might even drop special ones, including those with boundaries because 
    the likelyhood of encountering these in the \OPENTYPE\ arena is close to zero. 
*/

static int tex_aux_try_ligature(halfword *first, halfword second, halfword *nextone)
{
    halfword current = *first;
    halfword slot;
    halfword type = tex_valid_ligature(current, second, &slot);
    if (type >= 0) {
        int move_after = (type & 0x0C) >> 2;
        int keep_right = (type & 0x01) != 0;
        int keep_left  = (type & 0x02) != 0;
        halfword next = node_next(second);
        if (keep_left && keep_right) {
            halfword ligature = tex_copy_node(current);
            glyph_character(ligature) = slot; 
            tex_couple_nodes(*first, ligature);
            tex_couple_nodes(ligature, second);
            if (nextone) {
                *nextone = second;
            }
        } else if (keep_right) { 
            glyph_character(*first) = slot; 
            if (nextone) {
                *nextone = second;
            }
        } else if (keep_left) { 
            glyph_character(second) = slot; 
            if (nextone) {
                *nextone = second;
            }
        } else { 
            glyph_character(*first) = slot; 
            tex_uncouple_node(second);
            tex_flush_node(second);
            tex_try_couple_nodes(*first, next);
            if (nextone) {
                *nextone = *first;
            }
        }
        /* untested */
        if (nextone) {
            while (move_after-- > 0 && *nextone) {
                *nextone = node_next(*nextone);
            }
        }
        return 1;
    } else {
        return 0;
    }
}

static void tex_aux_handle_ligature_list(halfword target, int location)
{
    halfword node = tex_aux_discretionary_node(target, location);
    halfword head = node_head(node);
    halfword tail = node_tail(node);
    if (head && head != tail) {
        halfword current = head;
        while (node_next(current)) {
            halfword next = node_next(current);
            int ishead = current == head;
            halfword nextone = next;
            if (tex_aux_same_font_properties(current, next) && tex_aux_try_ligature(&current, next, &nextone)) {
                if (ishead) {
                    head = current;
                    node_head(node) = current;
                }
                current = nextone;
            } else { 
                current = next;
            }
        }
        node_tail(node) = current;
    }
}

static void tex_aux_handle_ligature_pair(halfword target, int location)
{
    halfword node = tex_aux_discretionary_node(target, location);
    halfword head = node_head(node);
    halfword tail = node_tail(node);
    if (head && head != tail) {
        halfword previous = node_prev(tail);
        int ishead = previous == head;
        if (tex_aux_same_font_properties(previous, tail) && tex_aux_try_ligature(&previous, tail, NULL)) {
            if (ishead) {
                head = previous;
                node_head(node) = previous;
            }
            node_tail(node) = previous;
        }
    }
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

    Todo: check this boundary mess (check for subtype too). 
    Todo: maybe get rid of weird ligatures, turn boundary into space and such.

*/

static halfword tex_aux_handle_ligature_word(halfword current)
{
    halfword right = null;
    halfword last = null; /* cf LuaTeX patch, an ancient border case buglet. */
    if (node_type(current) == boundary_node) {
        halfword previous = node_prev(current);
        halfword next = node_next(current);
        /*tex There is no need to uncouple |cur|, it is freed. */
        tex_flush_node(current);
        if (next) {
            tex_couple_nodes(previous, next);
            if (node_type(next) != glyph_node) {
                return previous;
            } else {
                current = next;
            }
        } else {
            node_next(previous) = next;
            return previous;
        }
    } else if (node_type(current) == glyph_node && font_has_left_boundary(glyph_font(current))) {
        halfword previous = node_prev(current);
        halfword glyph = tex_new_glyph_node(glyph_unset_subtype, glyph_font(current), left_boundary_char, current);
        tex_couple_nodes(previous, glyph);
        tex_couple_nodes(glyph, current);
        current = glyph;
    }
    if (node_type(current) == glyph_node && font_has_right_boundary(glyph_font(current))) {
        right = tex_new_glyph_node(glyph_unset_subtype, glyph_font(current), right_boundary_char, current);
    }
 // tex_print_node_list(current, "GOING",max_integer, max_integer);
    while (1) {
        halfword currenttype = node_type(current);
        /*tex A glyph followed by \unknown */
        if (currenttype == glyph_node) {
            if (tex_aux_apply_base_ligaturing(current)) {
                halfword forward = node_next(current);
                if (forward) {
                    halfword forwardtype = node_type(forward);
                    if (forwardtype == glyph_node) {
                        if (! tex_aux_apply_base_ligaturing(forward)) {
                          //  break;
                        } else if (! tex_aux_same_font_properties(current, forward)) {
                          //  break;
                        } else { 
                            halfword nextone = current; 
                            if (tex_aux_try_ligature(&current, forward, &nextone)) {
                                current = nextone; 
                                continue;
                            }
                        }
                    } else if (forwardtype == disc_node) {
                        /*tex a glyph followed by a disc */
                        halfword pre = disc_pre_break_head(forward);
                        halfword replace = disc_no_break_head(forward);
                        halfword next;
                        /*tex Check on: |a{b?}{?}{?}| and |a+b=>B| : |{B?}{?}{a?}| */
                        /*tex Check on: |a{?}{?}{b?}| and |a+b=>B| : |{a?}{?}{B?}| */
                        if (tex_aux_found_ligature(current, pre) || tex_aux_found_ligature(current, replace)) {
                            /*tex Move |cur| from before disc to skipped part */
                            halfword previous = node_prev(current);
                            tex_uncouple_node(current);
                            tex_couple_nodes(previous, forward);
                            tex_aux_discretionary_prepend(forward, no_break_code, current);
                            tex_aux_discretionary_prepend(forward, pre_break_code, tex_copy_node(current));
                            /*tex As we have removed cur, we need to start again. */
                            current = previous;
                        }
                        /*tex Check on: |a{?}{?}{}b| and |a+b=>B| : |{a?}{?b}{B}|. */
                        next = node_next(forward);
                        if (! replace && tex_aux_found_ligature(current, next)) {
                            /*tex Move |cur| from before |disc| to |no_break| part. */
                            halfword previous = node_prev(current);
                            halfword tail = node_next(next);
                            tex_uncouple_node(current);
                            tex_couple_nodes(previous, forward);
                            tex_aux_discretionary_prepend(forward, pre_break_code, tex_copy_node(current));
                            /*tex Move next from after disc to |no_break| part. */
                            tex_uncouple_node(next);
                            tex_try_couple_nodes(forward, tail);
                            /*tex We {\em know} this works. */
                            tex_couple_nodes(current, next);
                            /*tex Make sure the list is correct. */
                            tex_aux_discretionary_append(forward, post_break_code, tex_copy_node(next));
                            /*tex As we have removed cur, we need to start again. */
                            current = previous;
                        }
                        /*tex We are finished with the |pre_break|. */
                        tex_aux_handle_ligature_list(forward, pre_break_code);
                    } else if (forwardtype == boundary_node) {
                        halfword next = node_next(forward);
                        tex_try_couple_nodes(current, next);
                        tex_flush_node(forward);
                        if (right) {
                            /*tex Shame, didn't need it. */
                            tex_flush_node(right);
                            /*tex No need to reset |right|, we're going to leave the loop anyway. */
                        }
                        break;
                    } else if (right) {
                        tex_couple_nodes(current, right);
                        tex_couple_nodes(right, forward);
                        right = null;
                        continue;
                    } else {
                        break;
                    }
                } else {
                    /*tex The last character of a paragraph. */
                    if (right) {
                        /*tex |par| prohibits the use of |couple_nodes| here. */
                        tex_try_couple_nodes(current, right);
                        right = null;
                        continue;
                    } else {
                        break;
                    }
                }
                /*tex A discretionary followed by \unknown */
            }
        } else if (currenttype == disc_node) {
            /*tex If |{?}{x}{?}| or |{?}{?}{y}| then: */
            if (disc_no_break_head(current) || disc_post_break_head(current)) {
                /*tex Is this nesting okay (and needed)? */
                halfword forward;
                if (disc_post_break_head(current)) {
                    tex_aux_handle_ligature_list(current, post_break_code);
                }
                if (disc_no_break_head(current)) {
                    tex_aux_handle_ligature_list(current, no_break_code);
                }
                forward = node_next(current);
                while (forward && node_type(forward) == glyph_node && tex_aux_apply_base_ligaturing(forward)) {
                    halfword replace = disc_no_break_tail(current);
                    halfword post = disc_post_break_tail(current);
                    if (tex_aux_found_ligature(replace, forward) || tex_aux_found_ligature(post, forward)) {
                        tex_try_couple_nodes(current, node_next(forward));
                        tex_uncouple_node(forward);
                        tex_aux_discretionary_append(current, no_break_code, tex_copy_node(forward));
                        tex_aux_handle_ligature_pair(current, no_break_code);
                        tex_aux_handle_ligature_pair(current, post_break_code);
                        forward = node_next(current);
                    } else {
                        break;
                    }
                }
                if (forward && node_type(forward) == disc_node) {
                    /*tex This only deals with simple pre-only discretionaries and a following glyph. */
                    halfword next = node_next(forward);
                    if (next
                        && ! disc_no_break_head(forward)
                        && ! disc_post_break_head(forward)
                        && node_type(next) == glyph_node
                        && tex_aux_apply_base_ligaturing(next)
                        && ((disc_post_break_tail(current) && tex_aux_found_ligature(disc_post_break_tail(current), next)) ||
                            (disc_no_break_tail  (current) && tex_aux_found_ligature(disc_no_break_tail  (current), next)))) {
                        halfword last = node_next(next);
                        tex_uncouple_node(next);
                        tex_try_couple_nodes(forward, last);
                        /*tex Just a hidden flag, used for (base mode) experiments. */
                        if (hyphenation_permitted(hyphenation_mode_par, lazy_ligatures_hyphenation_mode)) {
                            /*tex f-f-i -> f-fi */
                            tex_aux_discretionary_append(current, no_break_code, tex_copy_node(next));
                            tex_aux_handle_ligature_pair(current,no_break_code);
                            tex_aux_discretionary_append(current, post_break_code, next);
                            tex_aux_handle_ligature_pair(current,post_break_code);
                            tex_try_couple_nodes(node_prev(forward), node_next(forward));
                            tex_flush_node(forward);
                        } else {
                            /*tex f-f-i -> ff-i : |{a-}{b}{AB} {-}{c}{}| => |{AB-}{c}{ABc}| */
                            tex_aux_discretionary_append(forward, post_break_code, tex_copy_node(next));
                            if (disc_no_break_head(current)) {
                                tex_aux_nesting_prepend_list(forward, no_break_code, disc_no_break_head(current));
                                tex_aux_discretionary_append(forward, no_break_code, next);
                                tex_aux_handle_ligature_pair(forward, no_break_code);
                                tex_aux_nesting_prepend_list(forward, pre_break_code, disc_no_break_head(current));
                            }
                            tex_try_couple_nodes(node_prev(current), node_next(current));
                            tex_flush_node(current);
                            current = forward;
                        }
                    }
                }
            }
        } else {
            /*tex We have glyph nor disc. */
            return last;
        }
        /*tex Goto the next node, where |\par| allows |node_next(cur)| to be NULL. */
        last = current;
        current = node_next(current);
    }
    return current;
}

/*tex The return value is the new tail, head should be a dummy: */

halfword tex_handle_ligaturing(halfword head, halfword tail)
{
    if (node_next(head)) {
        /*tex A trick to allow explicit |node == null| tests. */
        halfword save_tail = null;
        halfword current, previous;
        if (tail) {
            save_tail = node_next(tail);
            node_next(tail) = null;
        }
        previous = head;
        current = node_next(previous);
        while (current) {
            switch(node_type(current)) {
                case glyph_node:
                    if (tex_aux_apply_base_ligaturing(current)) {
                        current = tex_aux_handle_ligature_word(current);
                    }
                    break;
                case disc_node: 
                case boundary_node:
                    current = tex_aux_handle_ligature_word(current);
                    break;
            }
            previous = current;
            if (current) {
                current = node_next(current);
            }
        }
        if (! previous) {
            previous = tex_tail_of_node_list(head);
        }
        tex_try_couple_nodes(previous, save_tail);
        return previous;
    } else {
        return tail;
    }
}

/*tex Kerning starts here: */

static halfword tex_aux_add_kern_before(halfword left, halfword right)
{
    if (tex_aux_same_font_properties(left, right) &&
            ! tex_has_glyph_option(left, glyph_option_no_right_kern) &&
            ! tex_has_glyph_option(right, glyph_option_no_left_kern) &&
            tex_has_kern(glyph_font(left), glyph_character(left))
        ) {
        scaled k = tex_raw_get_kern(glyph_font(left), glyph_character(left), glyph_character(right));
        if (k) {
            scaled kern = tex_new_kern_node(k, font_kern_subtype);
            halfword previous = node_prev(right);
            tex_couple_nodes(previous, kern);
            tex_couple_nodes(kern, right);
            tex_attach_attribute_list_copy(kern, left);
            return kern;
        }
    }
    return null;
}

static halfword tex_aux_add_kern_after(halfword left, halfword right, halfword after)
{
    if (tex_aux_same_font_properties(left, right) &&
            ! tex_has_glyph_option(left, glyph_option_no_right_kern) &&
            ! tex_has_glyph_option(right, glyph_option_no_left_kern) &&
            tex_has_kern(glyph_font(left), glyph_character(left))
        ) {
        scaled k = tex_raw_get_kern(glyph_font(left), glyph_character(left), glyph_character(right));
        if (k) {
            scaled kern = tex_new_kern_node(k, font_kern_subtype);
            halfword next = node_next(after);
            tex_couple_nodes(after, kern);
            tex_try_couple_nodes(kern, next);
            tex_attach_attribute_list_copy(kern, after);
            return kern;
        }
    }
    return null;
}

static halfword tex_aux_do_handle_kerning(halfword root, halfword init_left, halfword init_right);

static void tex_aux_handle_discretionary_kerning(halfword target, int location, halfword left, halfword right)
{
    halfword node = tex_aux_discretionary_node(target, location);
    if (node_head(node)) {
        halfword kern = tex_aux_do_handle_kerning(node_head(node), left, right);
        if (kern) { 
            node_head(node) = kern;
            node_tail(node) = tex_tail_of_node_list(node_head(node));
        }
    }
}

static halfword tex_aux_do_handle_kerning(halfword root, halfword init_left, halfword init_right)
{
 // halfword head = node_next(root); // todo: get rid of this one 
    halfword head = root; // todo: get rid of this one 
    halfword current = head;
    halfword initial = null;
    if (current) {
        halfword left = null;
        if (node_type(current) == glyph_node && tex_aux_apply_base_kerning(current)) {
            if (init_left) {
                halfword kern = tex_aux_add_kern_before(init_left, current);
                if (current == head) {
                    initial = kern; 
                }
            }
            left = current;
        }
        current = node_next(current);
        while (current) {
            halfword currenttype = node_type(current);
            if (currenttype == glyph_node) { 
                if (tex_aux_apply_base_kerning(current)) {
                    if (left) {
                        tex_aux_add_kern_before(left, current);
                        if (glyph_character(left) < 0) {
                            halfword previous = node_prev(left);
                            tex_couple_nodes(previous, current);
                            tex_flush_node(left);
                        }
                    }
                    left = current;
                } else { 
                    left = null;
                }
            } else {
                if (currenttype == disc_node) {
                    halfword next = node_next(current);
                    halfword right = node_type(next) == glyph_node && tex_aux_apply_base_kerning(next) ? next : null;
                    tex_aux_handle_discretionary_kerning(current, pre_break_code, left, null);
                    tex_aux_handle_discretionary_kerning(current, post_break_code, null, right);
                    tex_aux_handle_discretionary_kerning(current, no_break_code, left, right);
                }
                if (left) {
                    if (glyph_character(left) < 0) { /* boundary ? */
                        halfword previous = node_prev(left);
                        tex_couple_nodes(previous, current);
                        tex_flush_node(left);
                    }
                    left = null;
                }
            }
            current = node_next(current);
        }
        if (left) {
            if (init_right) {
                tex_aux_add_kern_after(left, init_right, left);
            }
            if (glyph_character(left) < 0) {
                halfword previous = node_prev(left);
                halfword next = node_next(left);
                if (next) {
                    tex_couple_nodes(previous, next);
                    node_tail(root) = next;
                } else if (previous != root) {
                    node_next(previous) = null;
                    node_tail(root) = previous;
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
    return initial; 
}

halfword tex_handle_kerning(halfword head, halfword tail)
{
    halfword save_link = null;
    if (tail) {
        save_link = node_next(tail);
        node_next(tail) = null;
        node_tail(head) = tail;
        tex_aux_do_handle_kerning(node_next(head), null, null); /*tex There is no need to check initial here. */
        tail = node_tail(head);
        if (tex_valid_node(save_link)) {
            /* no need for check */
            tex_try_couple_nodes(tail, save_link);
        }
    } else {
        node_tail(head) = null;
        tex_aux_do_handle_kerning(node_next(head), null, null); /*tex There is no need to check initial here. */
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
                // what if disc at start 
                tex_handle_ligaturing(head, null);
            }
            callback_id = lmt_callback_defined(kerning_callback);
            if (callback_id) {
                head = tex_aux_run_lua_ligkern_callback(lmt_lua_state.lua_instance, head, group, direction, callback_id);
            } else {
                halfword kern = tex_aux_do_handle_kerning(head, null, null);
                if (kern) { 
                    head = kern; 
                }
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
        /*tex Here |a| determines if we define global or not. */
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

scaled tex_char_cf_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->compression;
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
    return (tex_aux_char_info(f, c)->tag & tag) == tag;
}

void tex_char_reset_tag_from_font(halfword f, halfword c, halfword tag)
{
    charinfo *ci = tex_aux_char_info(f, c);
    ci->tag = ci->tag & ~(tag);
}

halfword tex_char_tag_from_font(halfword f, halfword c)
{
    return tex_aux_char_info(f, c)->tag;
}

int tex_char_checked_tag(halfword tag)
{ 
    return tag & (horizontal_tag | vertical_tag | extend_last_tag | italic_tag | n_ary_tag | radical_tag | punctuation_tag);
}

halfword tex_char_next_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->next : -1;
}

halfword tex_char_extensible_italic_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->extensible_italic : INT_MIN;
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

extinfo *tex_char_extensible_recipe_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->extensible_recipe : NULL;
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

scaled tex_char_inner_x_offset_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->inner_x_offset : 0;
}

scaled tex_char_inner_y_offset_from_font(halfword f, halfword c)
{
    charinfo *ci = tex_aux_char_info(f, c);
    return ci->math ? ci->math->inner_y_offset : 0;
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
    scaled ht = ci->height;
    scaled dp = ci->depth;
    return tex_aux_glyph_y_scaled(g, (ht > 0 ? ht : 0) + (dp > 0 ? dp : 0)); /* so not progression */
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

void tex_set_cfcode_in_font(halfword f, halfword c, halfword i) {
    charinfo *ci = tex_aux_char_info(f, c);
    if (ci) {
        ci->compression = i;
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

