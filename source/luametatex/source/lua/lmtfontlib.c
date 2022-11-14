/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    There is not that much font related code because much is delegated to \LUA. We're actually back
    to original \TEX, where only dimensions matter, plus some basic information about constructing
    (base mode) ligatures and (base mode) kerning. Also, we need to store some math specific
    properties of glyphs so that the math machinery can do its work.

    Compared to traditional \TEX\ the most impressive extension is the amount of new math parameters.
    There are also some new concepts, like staircase kerns. In the typesetting related code this is
    reflected in dedicated code paths.

    The code is different from the code in \LUATEX. Because we don't have a backend built in, we need
    to store less. Also, there are quite some optimizations so that large fonts consume less memory.
    After all, we have whatever is available already in \LUA\ tables. The engine only needs a few
    dimensions to work with, plus some ligature and kern information for old school fonts, and when
    applicable some additional data that relates to math. So, for instance, we no longer allocate
    memory when we have no math.

    We start with some tables to which we might do more with this data and add more entries at some
    point. We are prepared.

 */


void lmt_fontlib_initialize(void) {
    /* nothing */
}

static int valid_math_parameter(lua_State *L, int narg) {
    const char *s = lua_tostring(L, narg);
    if (s) {
        for (int i = 1; lmt_interface.math_font_parameter_values[i].name; i++) {
            if (lmt_interface.math_font_parameter_values[i].name == s) {
                return i;
            }
        }
    }
    return -1;
}

/*
    Most of these special ligature indicators have never been used by fonts but they are part of
    \TEX's legacy so of course we keep them around!

*/

static const char *lmt_ligature_type_strings[] = {
    "=:", "=:|", "|=:", "|=:|", "", "=:|>", "|=:>", "|=:|>", "", "", "", "|=:|>>", NULL
};

static int fontlib_aux_count_hash_items(lua_State *L)
{
    int n = 0;
    if (lua_type(L, -1) == LUA_TTABLE) {
        lua_pushnil(L);
        while (lua_next(L, -2)) {
            n++;
            lua_pop(L, 1);
        }
    }
    return n;
}

/*tex

    These macros set a field in the font or character records. Watch how we make a copy of a string!

*/

# define set_numeric_field_by_index(target,name,dflt) \
    lua_push_key(name); \
    target = (lua_rawget(L, -2) == LUA_TNUMBER) ? lmt_roundnumber(L, -1) : dflt ; \
    lua_pop(L, 1);

# define set_boolean_field_by_index(target,name,dflt) \
    lua_push_key(name); \
    target = (lua_rawget(L, -2) == LUA_TBOOLEAN) ? lua_toboolean(L, -1) : dflt ; \
    lua_pop(L, 1);

# define set_string_field_by_index(target,name) \
    lua_push_key(name); \
    target = (lua_rawget(L, -2) == LUA_TSTRING) ? lua_tostring(L, -1) : NULL ; \
    lua_pop(L, 1);

# define set_any_field_by_index(target,name) \
    lua_push_key(name); \
    target = (lua_rawget(L, -2) != LUA_TNIL); \
    lua_pop(L, 1);

/*tex

    Font parameters can be set by number or by name. There are seven basic \TEX\ parameters in text
    mode but in  math mode there can be numerous.

*/

static void fontlib_aux_read_lua_parameters(lua_State *L, int f)
{
    lua_push_key(parameters);
    if (lua_rawget(L, -2) == LUA_TTABLE) {
        /*tex We determine the the number of parameters in the |max(nofintegerkeys(L), 7)|. */
        int maxindex = 7;
        lua_pushnil(L);
        while (lua_next(L, -2)) {
            if (lua_type(L, -2) == LUA_TNUMBER) {
                int i = (int) lua_tointeger(L, -2);
                if (i > maxindex) {
                    maxindex = i;
                }
            }
            lua_pop(L, 1);
        }
        /*tex
            We enlarge the parameter array. The first zeven values are already initialized to zero
            when the font structure is allocated.
        */
        if (maxindex > 7) {
            tex_set_font_parameters(f, maxindex);
        }
        /*tex
            First we pick up the numeric entries. The values set with keys can later overload
            these. It's there for old times sake, because numeric parameters are gone.
        */
        for (int i = 1; i <= maxindex; i++) {
            if (lua_rawgeti(L, -1, i) == LUA_TNUMBER) {
                halfword value = lmt_roundnumber(L, -1);
                tex_set_font_parameter(f, i, value);
            }
            lua_pop(L, 1);
        }
        lua_pushnil(L);
        while (lua_next(L, -2)) {
            halfword value = lua_type(L, -1) == LUA_TNUMBER ? lmt_roundnumber(L, -1) : 0;
            switch (lua_type(L, -2)) {
                case LUA_TSTRING:
                    {
                        /* These can overload the already set-by-index values. */
                        const char *s = lua_tostring(L, -2);
                        if (lua_key_eq(s, slant)) {
                            tex_set_font_parameter(f, slant_code, value);
                        } else if (lua_key_eq(s, space)) {
                            tex_set_font_parameter(f, space_code, value);
                        } else if (lua_key_eq(s, spacestretch)) {
                            tex_set_font_parameter(f, space_stretch_code, value);
                        } else if (lua_key_eq(s, spaceshrink)) {
                            tex_set_font_parameter(f, space_shrink_code, value);
                        } else if (lua_key_eq(s, xheight)) {
                            tex_set_font_parameter(f, ex_height_code, value);
                        } else if (lua_key_eq(s, quad)) {
                            tex_set_font_parameter(f, em_width_code, value);
                        } else if (lua_key_eq(s, extraspace)) {
                            tex_set_font_parameter(f, extra_space_code, value);
                        }
                    }
                    break;
                case LUA_TNUMBER:
                    {
                        /* Math fonts can have more than 7. */
                        int index = (int) lua_tointeger(L, -2);
                        if (index >= 8) {
                            tex_set_font_parameter(f, index, value);
                        }
                    }
                    break;
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);

}

static void fontlib_aux_read_lua_math_parameters(lua_State *L, int f)
{
    lua_push_key(MathConstants);
    if (lua_rawget(L, -2) == LUA_TTABLE) {
        lua_pushnil(L);
        while (lua_next(L, -2)) {
            int n = (int) lmt_roundnumber(L, -1);
            int i = 0;
            switch (lua_type(L, -2)) {
                case LUA_TSTRING:
                    i = valid_math_parameter(L, -2);
                    break;
                case LUA_TNUMBER:
                    i = (int) lua_tointeger(L, -2);
                    break;
            }
            if (i > 0) {
             // set_font_math_parameter(f, i, n);
                tex_set_font_math_parameters(f, i);
             // if (n > undefined_math_parameter || i < - undefined_math_parameter) {
             //     n = undefined_math_parameter;
             // }
                font_math_parameter(f, i) = n;
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

/*tex

    Math kerns are tables that specify a staircase. There are upto four such lists, one for each
    corner. Here is a complete example:

    \starttyping
    mathkerns = {
        bottom_left  = { { height = 420, kern = 80  }, { height = 520, kern = 4   } },
        bottom_right = { { height = 0,   kern = 48  } },
        top_left     = { { height = 620, kern = 0   }, { height = 720, kern = -80 } },
        top_right    = { { height = 676, kern = 115 }, { height = 776, kern = 45  } },
    }
    \stoptyping

*/

static void fontlib_aux_store_math_kerns(lua_State *L, int index, charinfo *co, int id)
{
    lua_push_key_by_index(index);
    if (lua_rawget(L, -2) == LUA_TTABLE) {
        lua_Integer k = lua_rawlen(L, -1);
        if (k > 0) {
            for (lua_Integer l = 1; l <= k; l++) {
                if (lua_rawgeti(L, -1, l) == LUA_TTABLE) {
                    scaled ht, krn;
                    set_numeric_field_by_index(ht, height, 0);
                    set_numeric_field_by_index(krn, kern, 0);
                    if (krn || ht) {
                        tex_add_charinfo_math_kern(co, id, ht, krn);
                    }
                }
                lua_pop(L, 1);
            }
        }
    }
    lua_pop(L, 1);
}

static void fontlib_aux_font_char_from_lua(lua_State *L, halfword f, int i, int has_math)
{
    if (lua_istable(L, -1)) {
        /*tex We need an intermediate veriable: */
        int target; 
        const char *starget;
        charinfo *co = tex_get_charinfo(f, i);
        set_numeric_field_by_index(target, tag, 0);
        set_charinfo_tag(co, target ? tex_char_checked_tag(target) : 0);
        set_any_field_by_index(target, callback);
        set_charinfo_tag(co, target ? callback_tag : 0);
        set_numeric_field_by_index(target, width, 0);
        set_charinfo_width(co, target);
        set_numeric_field_by_index(target, height, 0);
        set_charinfo_height(co, target);
        set_numeric_field_by_index(target, depth, 0);
        set_charinfo_depth(co, target);
        set_numeric_field_by_index(target, italic, 0);
        set_charinfo_italic(co, target);
        set_numeric_field_by_index(target, expansion, 1000);
        set_charinfo_expansion(co, target);
        set_numeric_field_by_index(target, compression, target);
        set_charinfo_compression(co, target);
        set_numeric_field_by_index(target, leftprotrusion, 0);
        set_charinfo_leftprotrusion(co, target);
        set_numeric_field_by_index(target, rightprotrusion, 0);
        set_charinfo_rightprotrusion(co, target);
        if (has_math) {
            tex_char_malloc_mathinfo(co);
            set_numeric_field_by_index(target, smaller, 0);
            set_charinfo_smaller(co, target);
            set_numeric_field_by_index(target, mirror, 0);
            set_charinfo_mirror(co, target);
            set_numeric_field_by_index(target, flataccent, INT_MIN);
            set_charinfo_flat_accent(co, target);
            /* */
            set_numeric_field_by_index(target, topleft, 0);
            set_charinfo_top_left_kern(co, target);
            set_numeric_field_by_index(target, topright, 0);
            set_charinfo_top_right_kern(co, target);
            set_numeric_field_by_index(target, bottomright, 0);
            set_charinfo_bottom_right_kern(co, target);
            set_numeric_field_by_index(target, bottomleft, 0);
            set_charinfo_bottom_left_kern(co, target);
            /* */
            set_numeric_field_by_index(target, leftmargin, 0);
            set_charinfo_left_margin(co, target);
            set_numeric_field_by_index(target, rightmargin, 0);
            set_charinfo_right_margin(co, target);
            set_numeric_field_by_index(target, topmargin, 0);
            set_charinfo_top_margin(co, target);
            set_numeric_field_by_index(target, bottommargin, 0);
            set_charinfo_bottom_margin(co, target);
            /* */
            set_numeric_field_by_index(target, topovershoot, 0);
            set_charinfo_top_overshoot(co, target);
            set_numeric_field_by_index(target, bottomovershoot, 0);
            set_charinfo_bottom_overshoot(co, target);
            /* */
            set_numeric_field_by_index(target, topanchor, INT_MIN);
            set_charinfo_top_anchor(co, target);
            set_numeric_field_by_index(target, bottomanchor, INT_MIN);
            set_charinfo_bottom_anchor(co, target);
            /* */
            set_string_field_by_index(starget, innerlocation);
            if (lua_key_eq(starget, left)) {
                set_charinfo_tag(co, inner_left_tag);
            } else if (lua_key_eq(starget, right)) {
                set_charinfo_tag(co, inner_right_tag);
            } 
            set_numeric_field_by_index(target, innerxoffset, INT_MIN);
            set_charinfo_inner_x_offset(co, target);
            set_numeric_field_by_index(target, inneryoffset, INT_MIN);
            set_charinfo_inner_y_offset(co, target);
            /* */
            set_numeric_field_by_index(target, next, -1);
            if (target >= 0) {
                set_charinfo_tag(co, list_tag);
                set_charinfo_next(co, target);
            }
            set_boolean_field_by_index(target, extensible, 0);
            if (target) {
                set_charinfo_tag(co, extend_last_tag);
            } 
            lua_push_key(parts);
            if (lua_rawget(L, -2) == LUA_TTABLE) {
                set_charinfo_tag(co, extensible_tag);
                tex_set_charinfo_extensible_recipe(co, NULL);
                for (lua_Integer k = 1; ; k++) {
                    if (lua_rawgeti(L, -1, k) == LUA_TTABLE) {
                        int glyph, startconnect, endconnect, advance, extender;
                        set_numeric_field_by_index(glyph, glyph, 0);
                        set_numeric_field_by_index(extender, extender, 0);
                        set_numeric_field_by_index(startconnect, start, 0);
                        set_numeric_field_by_index(endconnect, end, 0);
                        set_numeric_field_by_index(advance, advance, 0);
                        tex_append_charinfo_extensible_recipe(co, glyph, startconnect, endconnect, advance, extender);
                        lua_pop(L, 1);
                    } else {
                        lua_pop(L, 1);
                        break;
                    }
                }
                lua_pop(L, 1);
                set_numeric_field_by_index(target, partsitalic, 0);
                set_charinfo_extensible_italic(co, target);
                set_string_field_by_index(starget, partsorientation);
                if (lua_key_eq(starget, horizontal)) {
                    set_charinfo_tag(co, horizontal_tag);
                } else if (lua_key_eq(starget, vertical)) {
                    set_charinfo_tag(co, vertical_tag);
                } 
            } else {
                lua_pop(L, 1);
            }
            lua_push_key(mathkerns);
            if (lua_rawget(L, -2) == LUA_TTABLE) {
                fontlib_aux_store_math_kerns(L, lua_key_index(topleft), co, top_left_kern);
                fontlib_aux_store_math_kerns(L, lua_key_index(topright), co, top_right_kern);
                fontlib_aux_store_math_kerns(L, lua_key_index(bottomright), co, bottom_right_kern);
                fontlib_aux_store_math_kerns(L, lua_key_index(bottomleft), co, bottom_left_kern);
            }
            lua_pop(L, 1);
        }
        /*tex Maybe some kerns: */
        lua_push_key(kerns);
        if (lua_rawget(L, -2) == LUA_TTABLE) {
            int count = fontlib_aux_count_hash_items(L);
            if (count > 0) {
                /*tex The kerns table is still on stack. */
                kerninfo *ckerns = lmt_memory_calloc((size_t) count + 1, sizeof(kerninfo));
                if (ckerns) {
                    int ctr = 0;
                    set_charinfo_tag(co, kerns_tag);
                    /*tex Traverse the hash. */
                    lua_pushnil(L);
                    while (lua_next(L, -2)) {
                        int k = non_boundary_char;
                        switch (lua_type(L, -2)) {
                            case LUA_TNUMBER:
                                /*tex Adjacent char: */
                                k = (int) lua_tointeger(L, -2);
                                if (k < 0) {
                                    k = non_boundary_char;
                                }
                                break;
                            case LUA_TSTRING:
                                {
                                    const char *s = lua_tostring(L, -2);
                                    if (lua_key_eq(s, rightboundary)) {
                                        k = right_boundary_char;
                                        if (! font_has_right_boundary(f)) {
                                            set_font_right_boundary(f, tex_get_charinfo(f, right_boundary_char));
                                        }
                                    }
                                }
                                break;
                        }
                        target = lmt_roundnumber(L, -1);
                        if (k != non_boundary_char) {
                            set_kern_item(ckerns[ctr], k, target);
                            ctr++;
                        } else {
                            tex_formatted_warning("font", "lua-loaded font %s char U+%X has an invalid kern field", font_name(f), (int) i);
                        }
                        lua_pop(L, 1);
                    }
                    /*tex A guard against empty tables. */
                    if (ctr > 0) {
                        set_kern_item(ckerns[ctr], end_kern, 0);
                        set_charinfo_kerns(co, ckerns);
                    } else {
                        tex_formatted_warning("font", "lua-loaded font %s char U+%X has an invalid kerns field", font_name(f), (int) i);
                    }
                } else {
                    tex_overflow_error("font", (count + 1) * sizeof(kerninfo));
                }
            }
        }
        lua_pop(L, 1);
        /*tex Sometimes ligatures: */
        lua_push_key(ligatures);
        if (lua_rawget(L, -2) == LUA_TTABLE) {
            int count = fontlib_aux_count_hash_items(L);
            if (count > 0) {
                /*tex The ligatures table still on stack. */
                ligatureinfo *cligs = lmt_memory_calloc((size_t) count + 1, sizeof(ligatureinfo));
                if (cligs) {
                    int ctr = 0;
                    set_charinfo_tag(co, ligatures_tag);
                    /*tex Traverse the hash. */
                    lua_pushnil(L);
                    while (lua_next(L, -2)) {
                        int k = non_boundary_char;
                        int r = -1;
                        switch (lua_type(L, -2)) {
                            case LUA_TNUMBER:
                                /*tex Adjacent char: */
                                k = (int) lua_tointeger(L, -2);
                                if (k < 0) {
                                    k = non_boundary_char;
                                }
                                break;
                            case LUA_TSTRING:
                                {
                                    const char *s = lua_tostring(L, -2);
                                    if (lua_key_eq(s, rightboundary)) {
                                        k = right_boundary_char;
                                        if (! font_has_right_boundary(f)) {
                                            set_font_right_boundary(f, tex_get_charinfo(f, right_boundary_char));
                                        }
                                    }
                                }
                                break;
                        }
                        if (lua_istable(L, -1)) {
                            /*tex Ligature: */
                            set_numeric_field_by_index(r, char, -1);
                        }
                        if (r != -1 && k != non_boundary_char) {
                            int ligtarget = 0;
                            lua_push_key(type);
                            switch (lua_rawget(L, -2)) {
                                case LUA_TNUMBER:
                                    ligtarget = lmt_tointeger(L, -1);
                                    break;
                                case LUA_TSTRING:
                                    {
                                        const char *value = lua_tostring(L, -1);
                                        int index = 0;
                                        while (lmt_ligature_type_strings[index]) {
                                            if (strcmp(lmt_ligature_type_strings[index], value) == 0) {
                                                ligtarget = index;
                                                break;
                                            } else {
                                                index++;
                                            }
                                        }
                                    }
                                    break;
                                default:
                                    break;
                            }
                            lua_pop(L, 1);
                            set_ligature_item(cligs[ctr], (ligtarget * 2) + 1, k, r);
                            ctr++;
                        } else {
                            tex_formatted_warning("font", "lua-loaded font %s char U+%X has an invalid ligature field", font_name(f), (int) i);
                        }
                        /*tex The iterator value: */
                        lua_pop(L, 1);
                    }
                    /*tex A guard against empty tables. */
                    if (ctr > 0) {
                        set_ligature_item(cligs[ctr], 0, end_of_ligature_code, 0);
                        set_charinfo_ligatures(co, cligs);
                    } else {
                        tex_formatted_warning("font", "lua-loaded font %s char U+%X has an invalid ligatures field", font_name(f), (int) i);
                    }
                } else {
                    tex_overflow_error("font", (count + 1) * sizeof(ligatureinfo));
                }
            }
        }
        lua_pop(L, 1);
    }
}

/*tex

    The caller has to fix the state of the lua stack when there is an error!

*/

static int lmt_font_from_lua(lua_State *L, int f)
{
    /*tex The table is at stack |index -1| */
    const char *nstr ;
    set_string_field_by_index(nstr, name);
    tex_set_font_name(f, nstr);
    if (nstr) {
        const char *ostr = NULL;
        int no_math = 0;
        int j;
        set_string_field_by_index(ostr, original);
        tex_set_font_original(f, ostr ? ostr : nstr);
        set_numeric_field_by_index(j, designsize, 655360);
        set_font_design_size(f, j);
        set_numeric_field_by_index(j, size, font_design_size(f));
        set_font_size(f, j);
        set_boolean_field_by_index(j, compactmath, 0);
        set_font_compactmath(f, j);
        set_numeric_field_by_index(j, mathcontrol, 0);
        set_font_mathcontrol(f, j);
        set_numeric_field_by_index(j, textcontrol, 0);
        set_font_textcontrol(f, j);
        set_numeric_field_by_index(j, textscale, 0);
        set_font_textsize(f, j);
        set_numeric_field_by_index(j, scriptscale, 0);
        set_font_scriptsize(f, j);
        set_numeric_field_by_index(j, scriptscriptscale, 0);
        set_font_scriptscriptsize(f, j);
        set_numeric_field_by_index(j, hyphenchar, default_hyphen_char_par);
        set_font_hyphen_char(f, j);
        set_numeric_field_by_index(j, skewchar, default_skew_char_par);
        set_font_skew_char(f, j);
        set_boolean_field_by_index(no_math, nomath, 0);
        fontlib_aux_read_lua_parameters(L, f);
        if (! no_math) {
            fontlib_aux_read_lua_math_parameters(L, f);
        }
        /*tex The characters. */
        lua_push_key(characters);
        if (lua_rawget(L, -2) == LUA_TTABLE) {
            /*tex Find the array size values; |num| holds the number of characters to add. */
            int num = 0;
            int last = 0;
            int first = -1;
            /*tex The first key: */
            lua_pushnil(L);
            while (lua_next(L, -2)) {
                if (lua_isnumber(L, -2)) {
                    int i = (int) lua_tointeger(L, -2);
                    if (i >= 0 && lua_istable(L, -1)) {
                        num++;
                        if (i > last) {
                            last = i;
                        }
                        if (first < 0) {
                            first = i;
                        }
                        if (first >= 0 && i < first) {
                            first = i;
                        }
                    }
                }
                lua_pop(L, 1);
            }
            if (num > 0) {
                int fstep = 0;
                tex_font_malloc_charinfo(f, num);
                set_font_first_character(f, first);
                set_font_last_character(f, last);
                /*tex The first key: */
                lua_pushnil(L);
                while (lua_next(L, -2)) {
                    switch (lua_type(L, -2)) {
                        case LUA_TNUMBER:
                            {
                                int i = lmt_tointeger(L, -2);
                                if (i >= 0) {
                                    fontlib_aux_font_char_from_lua(L, f, i, ! no_math);
                                }
                            }
                            break;
                        case LUA_TSTRING:
                            {
                                const char *b = lua_tostring(L, -2);
                                if (lua_key_eq(b, leftboundary)) {
                                    fontlib_aux_font_char_from_lua(L, f, left_boundary_char, ! no_math);
                                } else if (lua_key_eq(b, rightboundary)) {
                                    fontlib_aux_font_char_from_lua(L, f, right_boundary_char, ! no_math);
                                }
                            }
                            break;
                    }
                    lua_pop(L, 1);
                }
                lua_pop(L, 1);
                /*tex

                    Handle font expansion last: We permits virtual fonts to use expansion as one
                    can always turn it off.

                */
                set_numeric_field_by_index(fstep, step, 0);
                if (fstep > 0) {
                    int fstretch = 0;
                    int fshrink = 0;
                    if (fstep > 100) {
                        fstep = 100;
                    }
                    set_numeric_field_by_index(fshrink, shrink, 0);
                    set_numeric_field_by_index(fstretch, stretch, 0);
                    if (fshrink < 0) {
                        fshrink = 0;
                    } else if (fshrink > 500) {
                        fshrink = 500;
                    }
                    fshrink -= (fshrink % fstep);
                    if (fshrink < 0) {
                        fshrink = 0;
                    }
                    if (fstretch < 0) {
                        fstretch = 0;
                    } else if (fstretch > 1000) {
                        fstretch = 1000;
                    }
                    fstretch -= (fstretch % fstep);
                    if (fstretch < 0) {
                        fstretch = 0;
                    }
                    set_font_step(f, fstep);
                    set_font_max_stretch(f, fstretch);
                    set_font_max_shrink(f, fshrink);
                }
            } else {
                tex_formatted_warning("font", "lua-loaded font '%d' with name '%s' has no characters", f, font_name(f));
            }
        } else {
            tex_formatted_warning("font", "lua-loaded font '%d' with name '%s' has no character table", f, font_name(f));
        }
        return 1;
    } else {
        return tex_formatted_error("font", "lua-loaded font '%d' has no name!", f);
    }
}

static int lmt_characters_from_lua(lua_State *L, int f)
{
    int no_math;
    /*tex Speedup: */
    set_boolean_field_by_index(no_math, nomath, 0);
    /*tex The characters: */
    lua_push_key(characters);
    if (lua_rawget(L, -2) == LUA_TTABLE) {
        /*tex Find the array size values; |num| has the amount. */
        int num = 0;
        int todo = 0;
        int bc = font_first_character(f);
        int ec = font_last_character(f);
        /*tex First key: */
        lua_pushnil(L);
        while (lua_next(L, -2)) {
            if (lua_isnumber(L, -2)) {
                int i = lmt_tointeger(L, -2);
                if (i >= 0 && lua_istable(L, -1)) {
                    todo++;
                    if (! tex_char_exists(f, i)) {
                        num++;
                        if (i > ec) {
                            ec = i;
                        }
                        if (bc < 0) {
                            bc = i;
                        }
                        if (bc >= 0 && i < bc) {
                            bc = i;
                        }
                    }
                }
            }
            lua_pop(L, 1);
        }
        if (todo > 0) {
            tex_font_malloc_charinfo(f, num);
            set_font_first_character(f, bc);
            set_font_last_character(f, ec);
            /*tex First key: */
            lua_pushnil(L);
            while (lua_next(L, -2)) {
                if (lua_type(L, -2) == LUA_TNUMBER) {
                    int i = lmt_tointeger(L, -2);
                    if (i >= 0) {
                        if (tex_char_exists(f, i)) {
                            charinfo *co = tex_get_charinfo(f, i);
                            set_charinfo_ligatures(co, NULL);
                            set_charinfo_kerns(co, NULL);
                            set_charinfo_math(co, NULL);
                            tex_set_charinfo_extensible_recipe(co, NULL);
                        }
                        fontlib_aux_font_char_from_lua(L, f, i, ! no_math);
                    }
                }
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
    }
    return 1;
}

/*tex

   The font library has helpers for defining the font and setting or getting the current font.
   Internally fonts are represented by font identifiers: numbers. The zero value represents the
   predefined |nullfont| instance. The only way to load a font in \LUAMETATEX\ is to use \LUA.

*/

static int fontlib_current(lua_State *L)
{
    int i = lmt_optinteger(L, 1, 0);
    if (i > 0) {
        if (tex_is_valid_font(i)) {
            tex_set_cur_font(0, i);
        } else {
            luaL_error(L, "expected a valid font id");
        }
    }
    lua_pushinteger(L, cur_font_par);
    return 1;
}

static int fontlib_max(lua_State *L)
{
    lua_pushinteger(L, tex_get_font_max_id());
    return 1;
}

static int fontlib_setfont(lua_State *L)
{
    int i = lmt_checkinteger(L, 1);
    if (i) {
        luaL_checktype(L, 2, LUA_TTABLE);
        if (! tex_is_valid_font(i)) {
            return luaL_error(L, "font with id %d is not a valid font", i);
        } else {
            lua_settop(L, 2);
            lmt_font_from_lua(L, i);
        }
    }
    return 0;
}

static int fontlib_addcharacters(lua_State *L)
{
    int i = lmt_checkinteger(L, 1);
    if (i) {
        luaL_checktype(L, 2, LUA_TTABLE);
        if (tex_is_valid_font(i)) {
            lua_settop(L, 2);
            lmt_characters_from_lua(L, i);
        } else {
            return luaL_error(L, "invalid font id %d passed", i);
        }
    }
    return 0;
}

/*tex |font.define(table)| */

static int fontlib_define(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        int i = lmt_optinteger(L, 2, 0);
        if (! i) {
            i = tex_new_font();
        } else if (! tex_is_valid_font(i)) {
            return luaL_error(L, "invalid font id %d passed", i);
        }
        lua_settop(L, 1);
        if (lmt_font_from_lua(L, i)) {
            lua_pushinteger(L, i);
            return 1;
        } else {
            lua_pop(L, 1);
            tex_delete_font(i);
            return luaL_error(L, "font creation failed, error in table");
        }
    } else {
        return 0;
    }
}

static int fontlib_id(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t l;
        const char *s = lua_tolstring(L, 1, &l);
        int cs = tex_string_locate(s, l, 0);
        int f = -1;
        if (cs == undefined_control_sequence || cs == undefined_cs_cmd || eq_type(cs) != set_font_cmd) {
            lua_pushliteral(L, "not a valid font csname");
        } else {
            f = eq_value(cs);
        }
        lua_pushinteger(L, f);
        return 1;
    } else {
        return luaL_error(L, "expected font csname string as argument");
    }
}

/*tex

    This returns the expected (!) next |fontid|, a first arg |true| will keep the id. This not
    really robust as of course fonts can be defined in the meantime! In principle |define| could
    handle that but then I also need to add similar functionality to \LUATEX.

*/

static int fontlib_nextid(lua_State *L)
{
    int keep = lua_toboolean(L, 1);
    int id = tex_new_font();
    lua_pushinteger(L, id);
    if (! keep) {
        tex_delete_font(id);
    }
    return 1;
}

/*tex

    These are not really that useful but can be used to (for instance) mess with the nullfont
    parameters that occasionally are used as defaults. We don't increase the font parameter array
    when the upper bound is larger than the initial size. You can forget about that kind of abuse
    in \LUAMETATEX.

*/

static int fontlib_aux_valid_fontdimen(lua_State *L, halfword *fnt, halfword *n)
{
    *fnt = lmt_tohalfword(L, 1);
    *n = lmt_tohalfword(L, 2);
    if (*n > 0 && *n <= font_parameter_count(*fnt)) {
        return 1;
    } else {
        return luaL_error(L, "font with id %i has only %d fontdimens", fnt, n);
    }
}

static int fontlib_setfontdimen(lua_State *L)
{
    halfword fnt, n;
    if (fontlib_aux_valid_fontdimen(L, &fnt, &n)) {
        tex_set_font_parameter(fnt, n, lmt_tohalfword(L, 3));
    }
    return 0;
}

static int fontlib_getfontdimen(lua_State *L)
{
    halfword fnt, n;
    if (fontlib_aux_valid_fontdimen(L, &fnt, &n)) {
        lua_pushinteger(L, font_parameter(fnt, n));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fontlib_getmathspec(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        halfword cs = tex_string_locate(name, lname, 0);
        if (eq_type(cs) == mathspec_cmd) {
            halfword ms = eq_value(cs);
            if (ms) {
                mathcodeval m = tex_get_math_spec(ms);
                lua_pushinteger(L, m.class_value);
                lua_pushinteger(L, m.family_value);
                lua_pushinteger(L, m.character_value);
                return 3;
            }
        }
    }
    return 0;
}

static int fontlib_getfontspec(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        halfword cs = tex_string_locate(name, lname, 0);
        if (eq_type(cs) == fontspec_cmd) {
            halfword fs = eq_value(cs);
            if (fs) {
                lua_pushinteger(L, font_spec_identifier(fs));
                lua_pushinteger(L, font_spec_scale(fs));
                lua_pushinteger(L, font_spec_x_scale(fs));
                lua_pushinteger(L, font_spec_y_scale(fs));
                return 4;
            }
        }
    }
    return 0;
}

static int fontlib_getmathindex(lua_State *L) {
    halfword index = -1; 
    switch (lua_type(L, 1)) { 
        case LUA_TSTRING:
            index = valid_math_parameter(L, 1);
            break;
        case LUA_TNUMBER:
            index = lmt_tointeger(L, 1);
            break;
    }
    if (index > 0 && index < math_parameter_last_code) { 
        lua_pushinteger(L, index);
        lua_pushboolean(L, index >= math_parameter_first_engine_code); /* true == engine */
    } else { 
        lua_pushinteger(L, 0);
        lua_pushboolean(L, 0);
    }
    return 2;
}

static const struct luaL_Reg fontlib_function_list[] = {
    { "current",       fontlib_current       },
    { "max",           fontlib_max           },
    { "setfont",       fontlib_setfont       },
    { "addcharacters", fontlib_addcharacters },
    { "define",        fontlib_define        },
    { "nextid",        fontlib_nextid        },
    { "id",            fontlib_id            },
    { "getfontdimen",  fontlib_getfontdimen  },
    { "setfontdimen",  fontlib_setfontdimen  },
    { "getfontspec",   fontlib_getfontspec   },
    { "getmathspec",   fontlib_getmathspec   },
    { "getmathindex",  fontlib_getmathindex  },
    { NULL,            NULL                  },
};

int luaopen_font(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, fontlib_function_list, 0);
    return 1;
}
