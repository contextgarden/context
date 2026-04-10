/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex 

    This module contains experimental code, used in \CONTEXT\ (exclusively) and it is not part
    of the game. The functionality might change and even disappear. So we don't document it apart
    from usage in \CONTEXT. In spite of what one might expect, the gain in using \CCODE\ instead
    of \LUA\ is not always what one expects, also because many features of \CONTEXT\ seldom kick
    in. Many \LUAMETATEX\ features only make sense in \CONTEXT, and the following definitely fit 
    into that category. 

*/

/*tex 
    Maybe we should just assume a flattened list so that we don't need a nested call. 
*/

typedef struct profiling_specification {
    /* specification */
    scaled    maximum;
    scaled    step;
    scaled    margin;
    int       method; 
    /* state */
    scaledwhd whd;
    scaled    position;
    scaled    width;
    halfword  parent;
} profiling_specification;

static void helperlib_aux_resetprofile(profiling_specification *profile)
{
    memset(profile, 0, sizeof(profiling_specification));
}

static void helperlib_aux_getprofile(lua_State *L, profiling_specification *profile, halfword current)
{
    while (current) { 
        switch (node_type(current)) {
            case glyph_node:
                profile->whd.wd = tex_glyph_width(current);
                profile->whd.ht = tex_glyph_height(current);
                profile->whd.dp = tex_glyph_depth(current);
                break;
            case kern_node:
                profile->whd.wd = kern_amount(current);
                profile->whd.ht = 0;
                profile->whd.dp = 0;
                break;
            case disc_node:
                if (disc_no_break_head(current)) { 
                    helperlib_aux_getprofile(L, profile, disc_no_break_head(current));
                } else { 
                    profile->whd.wd = 0; // not needed
                    profile->whd.ht = 0; // not needed
                    profile->whd.dp = 0; // not needed
                }
                goto DONE;
            case glue_node:
                profile->whd.wd = tex_effective_glue(profile->parent, current);
                if (is_leader(current)) { 
                    halfword leader = glue_leader_ptr(current);
                    if (leader) {
                        /* can be a helper */
                        switch (node_type(leader)) {
                            case hlist_node:
                            case vlist_node:
                                profile->whd.ht = box_height(leader);
                                profile->whd.dp = box_depth(leader);
                                break;
                            case rule_node:
                                if (node_subtype(leader) == strut_rule_code) {
                                    profile->whd.ht = 0;
                                    profile->whd.dp = 0;
                                } else { 
                                    profile->whd.ht = rule_height(leader);
                                    profile->whd.dp = rule_depth(leader);
                                }
                                break;
                            case glyph_node:
                                profile->whd.ht = tex_glyph_height(leader);
                                profile->whd.dp = tex_glyph_depth(leader);
                                break;
                            default: 
                                profile->whd.ht = 0;
                                profile->whd.dp = 0;
                                break;
                        }
                    } else {
                        profile->whd.ht = 0;
                        profile->whd.dp = 0;
                    }
                } else {
                    profile->whd.ht = 0;
                    profile->whd.dp = 0;
                }
                break;
            case hlist_node:
                profile->whd.wd = box_width(current);
                if (box_options(current) & box_option_no_profiling) {
                    profile->whd.ht = 0;
                    profile->whd.dp = 0;
                } else {
                    profile->whd.ht = box_height(current) - box_shift_amount(current);
                    profile->whd.dp = box_depth(current) + box_shift_amount(current);
                 }
                break;
            case vlist_node:
                profile->whd.wd = box_width(current);
                profile->whd.ht = box_height(current) - box_shift_amount(current);
                profile->whd.dp = box_depth(current) + box_shift_amount(current);
                break;
            case rule_node:
                profile->whd.wd = rule_width(current);
                if (node_subtype(current) == strut_rule_code) {
                    profile->whd.ht = 0;
                    profile->whd.dp = 0;
                } else { 
                    profile->whd.ht = rule_height(current);
                    profile->whd.dp = rule_depth(current);
                }
                break;
            case math_node:
                if (tex_math_glue_is_zero(current) || tex_ignore_math_skip(current)) {
                    profile->whd.wd = math_surround(current);
                } else {
                    profile->whd.wd = tex_effective_glue(profile->parent, current);
                }
                profile->whd.ht = 0;
                profile->whd.dp = 0;
                break;
            default: 
                profile->whd.ht = 0; // not needed
                profile->whd.wd = 0; // not needed
                profile->whd.dp = 0; // not needed
                goto DONE;
        }
        profile->position = profile->width;
        profile->width = profile->position + profile->whd.wd;
        {
         // scaled p = lround((double) (profile->position - profile->margin) / profile->step);
         // scaled w = lround((double) (profile->width + profile->margin) / profile->step);
            scaled p = lfloor((double) (profile->position - profile->margin)/profile->step + 0.5);
            scaled w = lfloor((double) (profile->width    + profile->margin)/profile->step - 0.5);
            if (p < 0) {
                p = 0;
            }
            if (w < 0) {
                w = 0;
            } 
            if (p > w) {
                scaled t = w; 
                w = p; 
                p = t; 
            }
            if (w > profile->maximum) {
                for (int i = profile->maximum + 1; i <= w + 1; i++) {
                    lua_pushinteger(L, 0);
                    lua_rawseti(L, -2, i);
                }
                profile->maximum = w;
            }
            for (int i = p; i <= w; i++) {
                /*tex some inefficient horror: it would be nice to have a direct integer fetch. */
                scaled what = 0;
                lua_rawgeti(L, -1, i);
                what = lmt_toscaled(L, -1);
                lua_pop(L, 1);
                if (profile->method == 1) { 
                    if (profile->whd.dp > what) {
                        lua_pushinteger(L, profile->whd.dp);
                        lua_rawseti(L, -2, i);
                    }
                } else { 
                    if (profile->whd.ht > what) {
                        lua_pushinteger(L, profile->whd.ht);
                        lua_rawseti(L, -2, i);
                    }
                }
            }
        }
      DONE:
        current = node_next(current);
    }
    profile->whd.wd = 0; // not needed
    profile->whd.ht = 0; // not needed
    profile->whd.dp = 0; // not needed
}

static int helperlib_getprofile(lua_State *L) 
{
    halfword line = lmt_check_isdirect(L, 1);
    halfword list = lmt_check_isdirect(L, 2);
    if (line && list && lua_gettop(L) == 3 && lua_type(L, 3) == LUA_TTABLE) {
        profiling_specification profile;
        helperlib_aux_resetprofile(&profile);
        set_numeric_field_by_index(profile.step, step, 0);
        set_numeric_field_by_index(profile.margin, margin, 0);
        set_numeric_field_by_index(profile.maximum, maximum, 0);
        set_numeric_field_by_index(profile.method, method, 0);
        if (profile.step > 0 && profile.margin > 0 && profile.maximum > 0) {
            profile.parent = line;
            lua_createtable(L, profile.maximum + 2, 1);
            for (int i = 0; i <= profile.maximum + 2; i++) {
                lua_pushinteger(L, 0);
                lua_rawseti(L, -2, i);
            }
            helperlib_aux_getprofile(L, &profile, list);
            lua_pushinteger(L, profile.maximum);
            return 2;
        }
    }
    lua_pushnil(L);
    lua_pushnil(L);
    return 2;
}

/* */

typedef int (*snapping_action) (halfword, halfword, snapping_specification*);

static int helperlib_aux_snap(lua_State *L, snapping_action action)
{
    halfword first = lmt_check_isdirect(L, 1);
    halfword last = lmt_check_isdirect(L, 2);
    if (first && lua_gettop(L) == 3 && lua_type(L, 3) == LUA_TTABLE) {
        snapping_specification snap; 
        tex_snapping_reset(&snap);
        set_numeric_field_by_index(snap.method, method, 0);
        if (tex_snapping_needed(&snap)) {
            set_numeric_field_by_index(snap.height, height, 0);
            set_numeric_field_by_index(snap.depth, depth, 0);
            set_numeric_field_by_index(snap.top, top, 0);
            set_numeric_field_by_index(snap.bottom, bottom, 0);
            return action(first, last, &snap);
        }
    }
    return 0;
}

static int helperlib_snaplist(lua_State *L)
{
    lua_pushboolean(L, helperlib_aux_snap(L, &tex_snapping_content));
    return 1;
}

static int helperlib_snapindeed(lua_State *L)
{
    lua_pushboolean(L, helperlib_aux_snap(L, &tex_snapping_indeed));
    return 1;
}

/* */

/* The table is at index 2! */

static halfword helperlib_aux_mathprocessed(lua_State *L, 
    halfword id, halfword start, halfword n, halfword parent, 
    int *done, halfword *newstart, halfword *newinitial
)
{
    lua_rawgeti(L, 2, id);
    if (lua_type(L, -1) == LUA_TFUNCTION) { 
        int top = lua_gettop(L);
        lua_pushinteger(L, start);
        lua_pushvalue(L, -1);
        lua_pushinteger(L, n);
        lua_pushinteger(L, parent);
        lua_call(L, 4, 3);
        *done = lua_toboolean(L, -1);
        *newstart = lmt_opthalfword(L, -2, 0);
        *newinitial = lmt_opthalfword(L, -2, 0);
        lua_settop(L, top - 1);
        return 1;
    } else {
        lua_pop(L, 1);
        return 0;
    }
}

static halfword helperlib_aux_mathprocess(lua_State *L, halfword start, halfword n, halfword parent)
{
    halfword initial = start;
    n = n < 0 ? 0 : n + 1;
    while (start) { 
        halfword noad = null;
        halfword id   = node_type(start);
        int done; halfword newstart, newinitial;

        /* todo: add tracing option trace(start,id,n) */

//        if trace_processing then
//            if id == noad_code then
//                report_processing("%w%S, class %a",n*2,nutstring(start),classes[getsubtype(start)])
//            elseif id == mathchar_code then
//                local char, font, fam = getcharspec(start)
//                report_processing("%w%S, family %a, font %a, char %a, shape %c",n*2,nutstring(start),fam,font,char,char)
//            else
//                report_processing("%w%S",n*2,nutstring(start))
//            end
//        end

        if (helperlib_aux_mathprocessed(L, id, start, n, parent, &done, &newstart, &newinitial)) {
            if (newinitial) { 
               initial = newinitial; // temp hack .. we will make all return head
                if (newstart) {
                    start = newstart;
                } else {
                    goto DONE;
                }
            } else {
                if (newstart) {
                    start = newstart;
                }
            }
        } else { 
            switch (id) { 
                case simple_noad:
                case radical_noad:
                case accent_noad:
                    noad = noad_nucleus(start);   if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = noad_supscr(start);    if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = noad_subscr(start);    if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = noad_supprescr(start); if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = noad_subprescr(start); if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = noad_prime(start);     if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    switch (id) {
                        case simple_noad:
                            break;
                        case radical_noad:
                            noad = radical_left_delimiter(start);   if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            noad = radical_right_delimiter(start);  if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            noad = radical_top_delimiter(start);    if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            noad = radical_bottom_delimiter(start); if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            noad = radical_degree(start);           if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            break;
                        case accent_noad:
                            noad = accent_top_character(start);     if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            noad = accent_middle_character(start);  if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            noad = accent_bottom_character(start);  if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                            break;
                    }
                    break;
                case math_char_node:
                case math_text_char_node:
                case delimiter_node:
                    goto DONE;
                case sub_box_node:
                case sub_mlist_node:
                    noad = math_kernel_list(start);           if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    break;
                case fraction_noad:
                    noad = fraction_numerator(start);         if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = fraction_denominator(start);       if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = fraction_left_delimiter(start);    if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = fraction_middle_delimiter(start);  if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = fraction_right_delimiter(start);   if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    break;
                case fence_noad:
                    noad = fence_delimiter(start);            if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = fence_delimiter_top(start);        if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = fence_delimiter_bottom(start);     if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    break;
                case choice_node:
                    noad = choice_display_mlist(start);       if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = choice_text_mlist(start);          if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = choice_script_mlist(start);        if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    noad = choice_script_script_mlist(start); if (noad) { helperlib_aux_mathprocess(L, noad, n, start); }
                    break;
            }
        }
        start = node_next(start);
    } 
 DONE:
   return parent ? 0 : initial; // only first level -- for now
}

static int helperlib_mathprocess(lua_State *L)
{
    halfword start = lmt_check_isdirect(L, 1);
    if (start && lua_type(L, 2) == LUA_TTABLE) { 
        halfword initial = helperlib_aux_mathprocess(L, start, -1, null);
        if (initial) { 
            lua_pushinteger(L, initial);
            return 1;
        } 
    }
    lua_pushnil(L);
    return 1;
}

static int helperlib_mathnested(lua_State *L)
{
    halfword current = lmt_check_isdirect(L, 1);
    if (current && lua_type(L, 2) == LUA_TTABLE) { 
        halfword n = lmt_optinteger(L, 3, -1);
        halfword id = node_type(current);
        halfword noad; 
        switch (id) { 
            case simple_noad:
            case radical_noad:
            case accent_noad:
                noad = noad_nucleus(current);   if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = noad_supscr(current);    if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = noad_subscr(current);    if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = noad_supprescr(current); if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = noad_subprescr(current); if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = noad_prime(current);     if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                switch (id) {
                    case simple_noad:
                        break;
                    case radical_noad:
                        noad = radical_left_delimiter(current);   if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        noad = radical_right_delimiter(current);  if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        noad = radical_top_delimiter(current);    if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        noad = radical_bottom_delimiter(current); if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        noad = radical_degree(current);           if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        break;
                    case accent_noad:
                        noad = accent_top_character(current);     if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        noad = accent_middle_character(current);  if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        noad = accent_bottom_character(current);  if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                        break;
                }
                break;
            case math_char_node:
            case math_text_char_node:
            case delimiter_node:
                break;
            case sub_box_node:
            case sub_mlist_node:
                noad = math_kernel_list(current);           if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                break;
            case fraction_noad:
                noad = fraction_numerator(current);         if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = fraction_denominator(current);       if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = fraction_left_delimiter(current);    if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = fraction_middle_delimiter(current);  if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = fraction_right_delimiter(current);   if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                break;
            case fence_noad:
                noad = fence_delimiter(current);            if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = fence_delimiter_top(current);        if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = fence_delimiter_bottom(current);     if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                break;
            case choice_node:
                noad = choice_display_mlist(current);       if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = choice_text_mlist(current);          if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = choice_script_mlist(current);        if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                noad = choice_script_script_mlist(current); if (noad) { helperlib_aux_mathprocess(L, noad, n, current); }
                break;
        }
    }
    return 0;
}

static void helperlib_aux_mathstep(lua_State *L, halfword start, halfword n, halfword parent)
{
    int top = lua_gettop(L);
    lua_pushinteger(L, start);
    lua_pushinteger(L, n);
    lua_pushinteger(L, parent);
    lua_call(L, 3, 0);
    lua_settop(L, top - 1);
}

static int helperlib_mathstep(lua_State *L)
{
    halfword current = lmt_check_isdirect(L, 1);
    if (current && lua_type(L, 2) == LUA_TFUNCTION) { 
        halfword n = lmt_optinteger(L, 3, -1);
        halfword id = lmt_optinteger(L, 4, node_type(current));
        halfword noad; 
        switch (id) { 
            case simple_noad:
            case radical_noad:
            case accent_noad:
                noad = noad_nucleus(current);   if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = noad_supscr(current);    if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = noad_subscr(current);    if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = noad_supprescr(current); if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = noad_subprescr(current); if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = noad_prime(current);     if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                switch (id) {
                    case simple_noad:
                        break;
                    case radical_noad:
                        noad = radical_left_delimiter(current);   if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        noad = radical_right_delimiter(current);  if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        noad = radical_top_delimiter(current);    if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        noad = radical_bottom_delimiter(current); if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        noad = radical_degree(current);           if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        break;
                    case accent_noad:
                        noad = accent_top_character(current);     if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        noad = accent_middle_character(current);  if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        noad = accent_bottom_character(current);  if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                        break;
                }
                break;
            case math_char_node:
            case math_text_char_node:
            case delimiter_node:
                break;
            case sub_box_node:
            case sub_mlist_node:
                noad = math_kernel_list(current);           if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                break;
            case fraction_noad:
                noad = fraction_numerator(current);         if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = fraction_denominator(current);       if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = fraction_left_delimiter(current);    if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = fraction_middle_delimiter(current);  if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = fraction_right_delimiter(current);   if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                break;
            case fence_noad:
                noad = fence_delimiter(current);            if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = fence_delimiter_top(current);        if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = fence_delimiter_bottom(current);     if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                break;
            case choice_node:
                noad = choice_display_mlist(current);       if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = choice_text_mlist(current);          if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = choice_script_mlist(current);        if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                noad = choice_script_script_mlist(current); if (noad) { helperlib_aux_mathstep(L, noad, n, current); }
                break;
        }
    }
    return 0;
}

/* */

static int helperlib_aux_nil(lua_State *L)
{
    lua_pushnil(L);
    return 1;
}

static int helperlib_aux_next_horizontal(lua_State *L)
{
    halfword t;
    halfword l = null;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t) {
        switch (node_type(t)) {
            case glyph_node:
                goto FOUND;
            case disc_node:
                if (disc_no_break_head(t)) {
                    goto FOUND;
                } else { 
                    break;
                }
            case rule_node:
                if (rule_width(t) > 0) {
                    goto FOUND;
                } else { 
                    break;
                }
            case glue_node:
                l = glue_leader_ptr(t);
                if (l) {
                    goto FOUND;
                } else if (glue_amount(t) || glue_stretch(t) || glue_shrink(t)) {
                    goto FOUND;
                } else {
                    break;
                }
            case kern_node:
                if (kern_amount(t)) {
                    goto FOUND;
                } else { 
                    break;
                }
            case math_node:
                if (tex_math_glue_is_zero(t) || tex_ignore_math_skip(t)) {
                    if (math_surround(t)) {
                        goto FOUND;
                    }
                } else if (math_amount(t) || math_stretch(t) || math_shrink(t)) {
                    goto FOUND;
                }              
                break;
            case dir_node:
                goto FOUND;
            case whatsit_node:
                goto FOUND;
            case hlist_node:
            case vlist_node:
                l = box_list(t);
                if (l) { 
                    goto FOUND;
                } else if (box_width(t)) {
                    goto FOUND;
                } else { 
                    break;
                }
            default: 
                /* nothing relevant */
                break;
        }
        t = node_next(t);
    }
    lua_pushnil(L);
    return 1;
  FOUND:
    lua_pushinteger(L, t);
    lua_pushinteger(L, node_type(t));
    lua_pushinteger(L, node_subtype(t));
    if (l) {
        lua_pushinteger(L, l);
        return 4;
    } else {
        return 3;
    }
}

static int helperlib_traversehorizontal(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, helperlib_aux_nil, 0);
        return 1;
    } else {
     // halfword n = nodelib_valid_direct_from_index(L, 1);
        halfword n = lmt_check_isdirect(L, 1);
        if (n) {
            lua_pushcclosure(L, helperlib_aux_next_horizontal, 0);
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, helperlib_aux_nil, 0);
            return 1;
        }
    }
}

static int helperlib_aux_next_vertical(lua_State *L)
{
    halfword t;
    halfword l = null;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t) {
        switch (node_type(t)) {
            case rule_node:
                if ((rule_height(t) + rule_depth(t)) > 0) {
                    goto FOUND;
                } else { 
                    break;
                }
            case kern_node:
                if (kern_amount(t)) {
                    goto FOUND;
                } else { 
                    break;
                }
            case glue_node:
                l = glue_leader_ptr(t);
                if (l) {
                    goto FOUND;
                } else if (glue_amount(t) || glue_stretch(t) || glue_shrink(t)) {
                    goto FOUND;
                } else {
                    break;
                }
            case whatsit_node:
                goto FOUND;
            case hlist_node:
            case vlist_node:
                l = box_list(t);
                if (l) { 
                    goto FOUND;
                } else if (box_height(t) + box_depth(t)) {
                    goto FOUND;
                } else { 
                    break;
                }
            default: 
                /* nothing relevant */
                break;
        }
        t = node_next(t);
    }
    lua_pushnil(L);
    return 1;
  FOUND:
    lua_pushinteger(L, t);
    lua_pushinteger(L, node_type(t));
    lua_pushinteger(L, node_subtype(t));
    if (l) {
        lua_pushinteger(L, l);
        return 4;
    } else {
        return 3;
    }
}

static int helperlib_traversevertical(lua_State *L)
{
    if (lua_isnil(L, 1)) {
        lua_pushcclosure(L, helperlib_aux_nil, 0);
        return 1;
    } else {
     // halfword n = nodelib_valid_direct_from_index(L, 1);
        halfword n = lmt_check_isdirect(L, 1);
        if (n) {
            lua_pushcclosure(L, helperlib_aux_next_vertical, 0);
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, helperlib_aux_nil, 0);
            return 1;
        }
    }
}

/* */

static int helperlib_aux_next_char_method(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t) { 
        if (node_type(t) == glyph_node && ! glyph_protected(t)) {
            lua_rawgeti(L, lua_upvalueindex(1), glyph_character(t));
            if (lua_type(L, -1) != LUA_TNIL) {
                lua_pop(L, 1);
                break;
            }
            lua_pop(L, 1);
        }
        t = node_next(t);
    }
    if (t) {
        /* 3 has method, 4 gets node, so we need to swap: node, method, char, font */ /* how ? */
        lua_pushinteger(L, t);
        lua_rawgeti(L, lua_upvalueindex(1), glyph_character(t));
     // lua_rotate(L, 3, 2); 
        lua_pushinteger(L, glyph_character(t));
        lua_pushinteger(L, glyph_font(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int helperlib_traversecharmethod(lua_State *L)
{
    if (lua_isnil(L, 1) || lua_type(L, 2) != LUA_TTABLE) {
        lua_pushcclosure(L, helperlib_aux_nil, 0);
        return 1;
    } else {
        halfword n = lmt_check_isdirect(L, 1);
        if (n) {
            lua_pushvalue(L, 2);
            lua_pushcclosure(L, helperlib_aux_next_char_method, 1);
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, helperlib_aux_nil, 0);
            return 1;
        }
    }
}

static int helperlib_aux_next_glyph_method(lua_State *L)
{
    halfword t;
    if (lua_isnil(L, 2)) {
        t = lmt_tohalfword(L, 1) ;
        lua_settop(L, 1);
    } else {
        t = lmt_tohalfword(L, 2) ;
        t = node_next(t);
        lua_settop(L, 2);
    }
    while (t) { 
        if (node_type(t) == glyph_node) {
            lua_rawgeti(L, lua_upvalueindex(1), glyph_character(t));
            if (lua_type(L, -1) != LUA_TNIL) {
                lua_pop(L, 1);
                break;
            }
            lua_pop(L, 1);
        }
        t = node_next(t);
    }
    if (t) {
        /* 3 has method, 4 gets node, so we need to swap: node, method, char, font */ /* how ? */
        lua_pushinteger(L, t);
        lua_rawgeti(L, lua_upvalueindex(1), glyph_character(t));
     // lua_rotate(L, 3, 2); 
        lua_pushinteger(L, glyph_character(t));
        lua_pushinteger(L, glyph_font(t));
        return 4;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int helperlib_traverseglyphmethod(lua_State *L)
{
    if (lua_isnil(L, 1) || lua_type(L, 2) != LUA_TTABLE) {
        lua_pushcclosure(L, helperlib_aux_nil, 0);
        return 1;
    } else {
        halfword n = lmt_check_isdirect(L, 1);
        if (n) {
            lua_pushvalue(L, 2);
            lua_pushcclosure(L, helperlib_aux_next_glyph_method, 1);
            lua_pushinteger(L, n);
            lua_pushnil(L);
            return 3;
        } else {
            lua_pushcclosure(L, helperlib_aux_nil, 0);
            return 1;
        }
    }
}

// traverseattr
// traverseattrmethod

/* */

// static size_t helperlib_aux_f_3_3(double n, char *s)
// {
//     if (fmod(n, 1) == 0) {
//         /* this is really needed in order to get integers */
//         return snprintf(s, 8, "%i", (int) n);
//     } else {
//         int i = snprintf(s, 8, "%0.3f", n) ;
//         int l = i - 1;
//         while (l > 1) {
//             if (s[l - 1] == '.') {
//                 break;
//             } else if (s[l] == '0') {
//                 --i;
//             } else {
//                 break;
//             }
//             l--;
//         }
//         return i;
//     }
// }
// 
// // static size_t helperlib_aux_f_3_3(double n, char *s)
// // {
// //     int i = snprintf(s, 8, "%0.3f", n) ;
// //     int l = i - 1;
// //     while (l >= 0) {
// //         if (s[l] == '.') {
// //             --i;
// //             break;
// //         } else if (s[l] == '0') {
// //             --i;
// //         } else {
// //             break;
// //         }
// //         l--;
// //     }
// //     if (i <= 0) {
// //         s[0] = '0';
// //         s[1] = '\0';
// //         return 1;
// //     } else {
// //         return i;
// //     }
// // }
// 
// static size_t helperlib_aux_f_3(lua_State *L, int slot, char *s)
// {
//     double n = lua_tonumber(L, slot);
//     if (n <= 0.0) {
//         s[0] = '0';
//         s[1] = '\0';
//         return 1;
//     } else if (n >= 1.0) {
//         s[0] = '1';
//         s[1] = '\0';
//         return 1;
//     } else { 
//         return helperlib_aux_f_3_3(n, s);
//     }
// }
// 
// static int helperlib_pdf_gray(lua_State *L)
// {
//     double s = lua_tonumber(L, 1);
//     if (s <= 0.0) {
//         lua_pushlstring(L, "0 g 0 G", 7);
//     } else if (s >= 1.0) {
//         lua_pushlstring(L, "1 g 1 G", 7);
//     } else { 
//         luaL_Buffer buffer;
//         char ss[10];
//         size_t sl = helperlib_aux_f_3_3(s, ss);
//         luaL_buffinitsize(L, &buffer, 20);
//         luaL_addlstring(&buffer, (const char *) &ss, sl);
//         luaL_addlstring(&buffer," g ", 4);
//         luaL_addlstring(&buffer, (const char *) &ss, sl);
//         luaL_addlstring(&buffer," G", 3);
//         luaL_pushresult(&buffer);
//     }
//     return 1;
// }
// 
// static int helperlib_pdf_rgb(lua_State *L)
// {
//     luaL_Buffer buffer;
//     char rs[10];
//     char gs[10];
//     char bs[10];
//     size_t rl = helperlib_aux_f_3(L, 1, rs);
//     size_t gl = helperlib_aux_f_3(L, 2, gs);
//     size_t bl = helperlib_aux_f_3(L, 3, bs);
//     luaL_buffinitsize(L, &buffer, 60);
//     luaL_addlstring(&buffer, (const char *) &rs, rl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &gs, gl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &bs, bl);
//     luaL_addlstring(&buffer," rg ", 4);
//     luaL_addlstring(&buffer, (const char *) &rs, rl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &gs, gl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &bs, bl);
//     luaL_addlstring(&buffer," RG", 3);
//     luaL_pushresult(&buffer);
//     return 1;
// }
// 
// static int helperlib_pdf_cmyk(lua_State *L)
// {
//     luaL_Buffer buffer;
//     char cs[10];
//     char ms[10];
//     char ys[10];
//     char ks[10];
//     size_t cl = helperlib_aux_f_3(L, 1, cs);
//     size_t ml = helperlib_aux_f_3(L, 2, ms);
//     size_t yl = helperlib_aux_f_3(L, 3, ys);
//     size_t kl = helperlib_aux_f_3(L, 4, ks);
//     luaL_buffinitsize(L, &buffer, 80);
//     luaL_addlstring(&buffer, (const char *) &cs, cl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &ms, ml);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &ys, yl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &ks, kl);
//     luaL_addlstring(&buffer," k ", 4);
//     luaL_addlstring(&buffer, (const char *) &cs, cl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &ms, ml);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &ys, yl);
//     luaL_addlstring(&buffer," ", 1);
//     luaL_addlstring(&buffer, (const char *) &ks, kl);
//     luaL_addlstring(&buffer," K", 3);
//     luaL_pushresult(&buffer);
//     return 1;
// }

/* */

static struct luaL_Reg helperlib_function_list[] = {
    /* */
    { "getprofile",          helperlib_getprofile          },
    /* */
    { "snaplist",            helperlib_snaplist            },
    { "snapindeed",          helperlib_snapindeed          },
    /* */
    { "mathprocess",         helperlib_mathprocess         },
    { "mathnested",          helperlib_mathnested          },
    { "mathstep",            helperlib_mathstep            },
    /* */
    { "traversehorizontal",  helperlib_traversehorizontal  },
    { "traversevertical",    helperlib_traversevertical    },
    /* */
    { "traversecharmethod",  helperlib_traversecharmethod  },
    { "traverseglyphmethod", helperlib_traverseglyphmethod },
    /* */
 // { "pdfgray",             helperlib_pdf_gray            },
 // { "pdfrgb",              helperlib_pdf_rgb             },
 // { "pdfcmyk",             helperlib_pdf_cmyk            },
    /* */
    { NULL,                  NULL                          },
};

int luaopen_helper(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, helperlib_function_list, 0);
    return 1;
}
