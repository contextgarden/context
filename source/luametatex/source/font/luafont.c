/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

static const char *ligature_type_strings[] = {
    "=:", "=:|", "|=:", "|=:|", "", "=:|>", "|=:>", "|=:|>", "", "", "", "|=:|>>", NULL
};

/*tex We might do more with this data. */

typedef struct _math_info {
    int id;
    const char *name;
    int lua;
} math_info;

math_info math_parameter_data[] = {
    { 0,                                        NULL, 0 },
    { ScriptPercentScaleDown,                   NULL, 0 },
    { ScriptScriptPercentScaleDown,             NULL, 0 },
    { DelimitedSubFormulaMinHeight,             NULL, 0 },
    { DisplayOperatorMinHeight,                 NULL, 0 },
    { MathLeading,                              NULL, 0 },
    { AxisHeight,                               NULL, 0 },
    { AccentBaseHeight,                         NULL, 0 },
    { FlattenedAccentBaseHeight,                NULL, 0 },
    { SubscriptShiftDown,                       NULL, 0 },
    { SubscriptTopMax,                          NULL, 0 },
    { SubscriptBaselineDropMin,                 NULL, 0 },
    { SuperscriptShiftUp,                       NULL, 0 },
    { SuperscriptShiftUpCramped,                NULL, 0 },
    { SuperscriptBottomMin,                     NULL, 0 },
    { SuperscriptBaselineDropMax,               NULL, 0 },
    { SubSuperscriptGapMin,                     NULL, 0 },
    { SuperscriptBottomMaxWithSubscript,        NULL, 0 },
    { SpaceAfterScript,                         NULL, 0 },
    { UpperLimitGapMin,                         NULL, 0 },
    { UpperLimitBaselineRiseMin,                NULL, 0 },
    { LowerLimitGapMin,                         NULL, 0 },
    { LowerLimitBaselineDropMin,                NULL, 0 },
    { StackTopShiftUp,                          NULL, 0 },
    { StackTopDisplayStyleShiftUp,              NULL, 0 },
    { StackBottomShiftDown,                     NULL, 0 },
    { StackBottomDisplayStyleShiftDown,         NULL, 0 },
    { StackGapMin,                              NULL, 0 },
    { StackDisplayStyleGapMin,                  NULL, 0 },
    { StretchStackTopShiftUp,                   NULL, 0 },
    { StretchStackBottomShiftDown,              NULL, 0 },
    { StretchStackGapAboveMin,                  NULL, 0 },
    { StretchStackGapBelowMin,                  NULL, 0 },
    { FractionNumeratorShiftUp,                 NULL, 0 },
    { FractionNumeratorDisplayStyleShiftUp,     NULL, 0 },
    { FractionDenominatorShiftDown,             NULL, 0 },
    { FractionDenominatorDisplayStyleShiftDown, NULL, 0 },
    { FractionNumeratorGapMin,                  NULL, 0 },
    { FractionNumeratorDisplayStyleGapMin,      NULL, 0 },
    { FractionRuleThickness,                    NULL, 0 },
    { FractionDenominatorGapMin,                NULL, 0 },
    { FractionDenominatorDisplayStyleGapMin,    NULL, 0 },
    { SkewedFractionHorizontalGap,              NULL, 0 },
    { SkewedFractionVerticalGap,                NULL, 0 },
    { OverbarVerticalGap,                       NULL, 0 },
    { OverbarRuleThickness,                     NULL, 0 },
    { OverbarExtraAscender,                     NULL, 0 },
    { UnderbarVerticalGap,                      NULL, 0 },
    { UnderbarRuleThickness,                    NULL, 0 },
    { UnderbarExtraDescender,                   NULL, 0 },
    { RadicalVerticalGap,                       NULL, 0 },
    { RadicalDisplayStyleVerticalGap,           NULL, 0 },
    { RadicalRuleThickness,                     NULL, 0 },
    { RadicalExtraAscender,                     NULL, 0 },
    { RadicalKernBeforeDegree,                  NULL, 0 },
    { RadicalKernAfterDegree,                   NULL, 0 },
    { RadicalDegreeBottomRaisePercent,          NULL, 0 },
    { MinConnectorOverlap,                      NULL, 0 },
    { SubscriptShiftDownWithSuperscript,        NULL, 0 },
    { FractionDelimiterSize,                    NULL, 0 },
    { FractionDelimiterDisplayStyleSize,        NULL, 0 },
    { NoLimitSubFactor,                         NULL, 0 },
    { NoLimitSupFactor,                         NULL, 0 },
    { -1,                                       NULL, 0 },
};

# define init_math_key(n) \
    math_parameter_data[n].lua  = luaS_##n##_index; \
    math_parameter_data[n].name = luaS_##n##_ptr;

void l_set_font_data(void) {
    init_math_key(ScriptPercentScaleDown);
    init_math_key(ScriptScriptPercentScaleDown);
    init_math_key(DelimitedSubFormulaMinHeight);
    init_math_key(DisplayOperatorMinHeight);
    init_math_key(MathLeading);
    init_math_key(AxisHeight);
    init_math_key(AccentBaseHeight);
    init_math_key(FlattenedAccentBaseHeight);
    init_math_key(SubscriptShiftDown);
    init_math_key(SubscriptTopMax);
    init_math_key(SubscriptBaselineDropMin);
    init_math_key(SuperscriptShiftUp);
    init_math_key(SuperscriptShiftUpCramped);
    init_math_key(SuperscriptBottomMin);
    init_math_key(SuperscriptBaselineDropMax);
    init_math_key(SubSuperscriptGapMin);
    init_math_key(SuperscriptBottomMaxWithSubscript);
    init_math_key(SpaceAfterScript);
    init_math_key(UpperLimitGapMin);
    init_math_key(UpperLimitBaselineRiseMin);
    init_math_key(LowerLimitGapMin);
    init_math_key(LowerLimitBaselineDropMin);
    init_math_key(StackTopShiftUp);
    init_math_key(StackTopDisplayStyleShiftUp);
    init_math_key(StackBottomShiftDown);
    init_math_key(StackBottomDisplayStyleShiftDown);
    init_math_key(StackGapMin);
    init_math_key(StackDisplayStyleGapMin);
    init_math_key(StretchStackTopShiftUp);
    init_math_key(StretchStackBottomShiftDown);
    init_math_key(StretchStackGapAboveMin);
    init_math_key(StretchStackGapBelowMin);
    init_math_key(FractionNumeratorShiftUp);
    init_math_key(FractionNumeratorDisplayStyleShiftUp);
    init_math_key(FractionDenominatorShiftDown);
    init_math_key(FractionDenominatorDisplayStyleShiftDown);
    init_math_key(FractionNumeratorGapMin);
    init_math_key(FractionNumeratorDisplayStyleGapMin);
    init_math_key(FractionRuleThickness);
    init_math_key(FractionDenominatorGapMin);
    init_math_key(FractionDenominatorDisplayStyleGapMin);
    init_math_key(SkewedFractionHorizontalGap);
    init_math_key(SkewedFractionVerticalGap);
    init_math_key(OverbarVerticalGap);
    init_math_key(OverbarRuleThickness);
    init_math_key(OverbarExtraAscender);
    init_math_key(UnderbarVerticalGap);
    init_math_key(UnderbarRuleThickness);
    init_math_key(UnderbarExtraDescender);
    init_math_key(RadicalVerticalGap);
    init_math_key(RadicalDisplayStyleVerticalGap);
    init_math_key(RadicalRuleThickness);
    init_math_key(RadicalExtraAscender);
    init_math_key(RadicalKernBeforeDegree);
    init_math_key(RadicalKernAfterDegree);
    init_math_key(RadicalDegreeBottomRaisePercent);
    init_math_key(MinConnectorOverlap);
    init_math_key(SubscriptShiftDownWithSuperscript);
    init_math_key(FractionDelimiterSize);
    init_math_key(FractionDelimiterDisplayStyleSize);
    init_math_key(NoLimitSubFactor);
    init_math_key(NoLimitSupFactor);
}

static int valid_math_parameter(lua_State *L, int narg) {
    const char *s = lua_tostring(L, narg);
    if (s != NULL) {
        int i;
        for (i = 1; math_parameter_data[i].lua != 0; i++) {
            if (math_parameter_data[i].name == s) {
                return i;
            }
        }
    }
    return -1;
}

# define count_hash_items(name,n) \
    n = 0; \
    lua_key_rawgeti(name); \
    if (lua_type(L, -1) == LUA_TTABLE) { \
        lua_pushnil(L); \
        while (lua_next(L, -2) != 0) { \
            n++; \
            lua_pop(L, 1); \
        } \
    } \
    if (n) { \
        /*tex Keep the table on stack. */ \
    } else{ \
        lua_pop(L, 1); \
    }

# define set_numeric_field_by_index(target,name,dflt) \
    lua_key_rawgeti(name); \
    target = (lua_type(L, -1) == LUA_TNUMBER) ? lua_roundnumber(L, -1) : dflt ; \
    lua_pop(L, 1);

# define set_boolean_field_by_index(target,name,dflt) \
    lua_key_rawgeti(name); \
    target = (lua_type(L, -1) == LUA_TBOOLEAN) ? lua_toboolean(L, -1) : dflt ; \
    lua_pop(L, 1);

/* used once */

# define set_string_field_by_index(target,name) \
    lua_key_rawgeti(name); \
    target = (lua_type(L,-1) == LUA_TSTRING) ? strdup(lua_tostring(L, -1)) : NULL ; \
    lua_pop(L, 1);

/* used once */

# define set_enum_field_by_index(target,name,dflt,values) do { \
    lua_key_rawgeti(name); \
    target = lua_type(L,-1); \
    if (target == LUA_TNUMBER) { \
        target = (int) lua_tointeger(L, -1); \
    } else if (target == LUA_TSTRING) { \
        const char *value = lua_tostring(L, -1); \
        int index = 0; \
        target = dflt; \
        while (values[index] != NULL) { \
            if (strcmp(values[index],value) == 0) { \
                target = index; \
                break; \
            } \
            index++; \
        } \
    } \
    lua_pop(L, 1); \
} while (0)

static void read_lua_parameters(lua_State * L, int f)
{
    lua_key_rawgeti(parameters);
    if (lua_istable(L, -1)) {
        /*tex The number of parameters is the |max(IntegerKeys(L)),7)| */
        int i;
        int n = 7;
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            if (lua_type(L, -2) == LUA_TNUMBER) {
                i = (int) lua_tointeger(L, -2);
                if (i > n)
                    n = i;
            }
            lua_pop(L, 1);
        }
        if (n > 7) {
            set_font_params(f, n);
        }
        /*tex Sometimes it is handy to have all integer keys: */
        for (i = 1; i <= 7; i++) {
            lua_rawgeti(L, -1, i);
            if (lua_type(L, -1) == LUA_TNUMBER) {
                n = lua_roundnumber(L, -1);
                set_font_param(f, i, n);
            }
            lua_pop(L, 1);
        }
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            int t = lua_type(L,-2);
            if (t == LUA_TNUMBER) {
                int i = (int) lua_tointeger(L, -2);
                if (i >= 8) {
                    if (lua_type(L,-1) == LUA_TNUMBER) {
                        n = lua_roundnumber(L, -1);
                    } else {
                        n = 0;
                    }
                    set_font_param(f, i, n);
                }
            } else if (t == LUA_TSTRING) {
                const char *s = lua_tostring(L, -2);
                if (lua_type(L,-1) == LUA_TNUMBER) {
                    n = lua_roundnumber(L, -1);
                } else {
                    n = 0;
                }
                if (lua_key_eq(s, slant)) {
                    set_font_param(f, slant_code, n);
                } else if (lua_key_eq(s, space)) {
                    set_font_param(f, space_code, n);
                } else if (lua_key_eq(s, space_stretch)) {
                    set_font_param(f, space_stretch_code, n);
                } else if (lua_key_eq(s, space_shrink)) {
                    set_font_param(f, space_shrink_code, n);
                } else if (lua_key_eq(s, x_height)) {
                    set_font_param(f, x_height_code, n);
                } else if (lua_key_eq(s, quad)) {
                    set_font_param(f, quad_code, n);
                } else if (lua_key_eq(s, extra_space)) {
                    set_font_param(f, extra_space_code, n);
                }
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);

}

static void read_lua_math_parameters(lua_State * L, int f)
{
    lua_key_rawgeti(MathConstants);
    if (lua_istable(L, -1)) {
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            int n = (int) lua_roundnumber(L, -1);
            int t = lua_type(L,-2);
            int i = 0;
            if (t == LUA_TNUMBER) {
                i = (int) lua_tointeger(L, -2);
            } else if (t == LUA_TSTRING) {
                i = valid_math_parameter(L, -2);
            }
            if (i > 0) {
                set_font_math_param(f, i, n);
            }
            lua_pop(L, 1);
        }
        set_font_oldmath(f,0);
    } else {
        set_font_oldmath(f,1);
    }
    lua_pop(L, 1);
}

static void store_math_kerns(lua_State * L, int index, charinfo * co, int id)
{
    int k;
    lua_key_direct_rawgeti(index);
    if (lua_istable(L, -1) && ((k = (int) lua_rawlen(L, -1)) > 0)) {
        scaled ht, krn;
        int l;
        for (l = 0; l < k; l++) {
            lua_rawgeti(L, -1, (l + 1));
            if (lua_istable(L, -1)) {
                set_numeric_field_by_index(ht, height, min_infinity);
                set_numeric_field_by_index(krn, kern, min_infinity);
                if (krn > min_infinity && ht > min_infinity) {
                    add_charinfo_math_kern(co, id, ht, krn);
                }
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

static void font_char_from_lua(lua_State * L, internal_font_number f, int i, int has_math)
{
    if (lua_istable(L, -1)) {
        int k, r, t, lt;
        /*tex We need an intermediate veriable: */
        scaled j;
        /*tex The number of ligature table items: */
        int nl = 0;
        /*tex The number of kern table items: */
        int nk = 0;
        charinfo *co = get_charinfo(f, i);
        set_charinfo_tag(co, 0);
        set_numeric_field_by_index(j,width,0);
        set_charinfo_width(co, j);
        set_numeric_field_by_index(j,height,0);
        set_charinfo_height(co, j);
        set_numeric_field_by_index(j,depth,0);
        set_charinfo_depth(co, j);
        set_numeric_field_by_index(j,italic,0);
        set_charinfo_italic(co, j);
        set_numeric_field_by_index(j,vert_italic,0);
        set_charinfo_vert_italic(co, j);
        set_numeric_field_by_index(j,expansion_factor,1000);
        set_charinfo_ef(co, j);
        set_numeric_field_by_index(j,left_protruding,0);
        set_charinfo_lp(co, j);
        set_numeric_field_by_index(j,right_protruding,0);
        set_charinfo_rp(co, j);
        if (has_math) {
            set_numeric_field_by_index(j,top_accent,INT_MIN);
            set_charinfo_top_accent(co, j);
            set_numeric_field_by_index(j,bot_accent,INT_MIN);
            set_charinfo_bot_accent(co, j);
            set_numeric_field_by_index(k,next,-1);
            if (k >= 0) {
                set_charinfo_tag(co, list_tag);
                set_charinfo_remainder(co, k);
            }
            lua_key_rawgeti(extensible);
            if (lua_istable(L, -1)) {
                int top, bot, mid, rep;
                set_numeric_field_by_index(top,top,0);
                set_numeric_field_by_index(bot,bot,0);
                set_numeric_field_by_index(mid,mid,0);
                set_numeric_field_by_index(rep,rep,0);
                if (top != 0 || bot != 0 || mid != 0 || rep != 0) {
                    set_charinfo_tag(co, ext_tag);
                    set_charinfo_extensible(co, top, bot, mid, rep);
                } else {
                    formatted_warning("font", "lua-loaded font %s char U+%X has an invalid extensible field", font_name(f), (int) i);
                }
            }
            lua_pop(L, 1);
            lua_key_rawgeti(horiz_variants);
            if (lua_istable(L, -1)) {
                int glyph, startconnect, endconnect, advance, extender;
                extinfo *h;
                set_charinfo_tag(co, ext_tag);
                set_charinfo_hor_variants(co, NULL);
                for (k = 1;; k++) {
                    lua_rawgeti(L, -1, k);
                    if (lua_istable(L, -1)) {
                        set_numeric_field_by_index(glyph,glyph,0);
                        set_numeric_field_by_index(extender,extender,0);
                        set_numeric_field_by_index(startconnect,start,0);
                        set_numeric_field_by_index(endconnect,end,0);
                        set_numeric_field_by_index(advance,advance,0);
                        h = new_variant(glyph, startconnect, endconnect, advance, extender);
                        add_charinfo_hor_variant(co, h);
                        lua_pop(L, 1);
                    } else {
                        lua_pop(L, 1);
                        break;
                    }
                }
            }
            lua_pop(L, 1);
            lua_key_rawgeti(vert_variants);
            if (lua_istable(L, -1)) {
                int glyph, startconnect, endconnect, advance, extender;
                extinfo *h;
                set_charinfo_tag(co, ext_tag);
                set_charinfo_vert_variants(co, NULL);
                for (k = 1;; k++) {
                    lua_rawgeti(L, -1, k);
                    if (lua_istable(L, -1)) {
                        set_numeric_field_by_index(glyph,glyph,0);
                        set_numeric_field_by_index(extender,extender,0);
                        set_numeric_field_by_index(startconnect,start,0);
                        set_numeric_field_by_index(endconnect,end,0);
                        set_numeric_field_by_index(advance,advance,0);
                        h = new_variant(glyph, startconnect, endconnect, advance, extender);
                        add_charinfo_vert_variant(co, h);
                        lua_pop(L, 1);
                    } else {
                        lua_pop(L, 1);
                        break;
                    }
                }
            }
            lua_pop(L, 1);
            /*tex
                Here is a complete example:

                \starttyping
                mathkern = {
                     bottom_left  = { { height = 420, kern = 80  }, { height = 520, kern = 4   } },
                     bottom_right = { { height = 0,   kern = 48  } },
                     top_left     = { { height = 620, kern = 0   }, { height = 720, kern = -80 } },
                     top_right    = { { height = 676, kern = 115 }, { height = 776, kern = 45  } },
                }
                \stoptyping

            */
            lua_key_rawgeti(mathkern);
            if (lua_istable(L, -1)) {
                store_math_kerns(L,lua_key_index(top_left), co, top_left_kern);
                store_math_kerns(L,lua_key_index(top_right), co, top_right_kern);
                store_math_kerns(L,lua_key_index(bottom_right), co, bottom_right_kern);
                store_math_kerns(L,lua_key_index(bottom_left), co, bottom_left_kern);
            }
            lua_pop(L, 1);
        }
        /*tex end of |has_math| */
        count_hash_items(kerns,nk);
        if (nk > 0) {
            /*tex The kerns table is still on stack. */
            kerninfo *ckerns = calloc((unsigned) (nk + 1), sizeof(kerninfo));
            int ctr = 0;
            /*tex Traverse the hash. */
            lua_pushnil(L);
            while (lua_next(L, -2) != 0) {
                k = non_boundarychar;
                lt = lua_type(L,-2);
                if (lt == LUA_TNUMBER) {
                    /*tex Adjacent char: */
                    k = (int) lua_tointeger(L, -2);
                    if (k < 0)
                        k = non_boundarychar;
                } else if (lt == LUA_TSTRING) {
                    const char *s = lua_tostring(L, -2);
                    if (lua_key_eq(s, right_boundary)) {
                        k = right_boundarychar;
                        if (!has_right_boundary(f))
                            set_right_boundary(f, get_charinfo(f, right_boundarychar));
                    }
                }
                j = lua_roundnumber(L, -1);
                if (k != non_boundarychar) {
                    set_kern_item(ckerns[ctr], k, j);
                    ctr++;
                } else {
                    formatted_warning("font", "lua-loaded font %s char U+%X has an invalid kern field", font_name(f), (int) i);
                }
                lua_pop(L, 1);
            }
            /*tex A guard against empty tables. */
            if (ctr > 0) {
                set_kern_item(ckerns[ctr], end_kern, 0);
                set_charinfo_kerns(co, ckerns);
            } else {
                formatted_warning("font", "lua-loaded font %s char U+%X has an invalid kerns field", font_name(f), (int) i);
            }
            lua_pop(L, 1); /*tex Do we pop enough: key and table? */
        }
        /*tex The ligatures. */
        count_hash_items(ligatures,nl);
        if (nl > 0) {
            /*tex The ligatures table still on stack. */
            liginfo *cligs = calloc((unsigned) (nl + 1), sizeof(liginfo));
            int ctr = 0;
            /*tex Traverse the hash. */
            lua_pushnil(L);
            while (lua_next(L, -2) != 0) {
                k = non_boundarychar;
                lt = lua_type(L,-2);
                if (lt == LUA_TNUMBER) {
                    /*tex Adjacent char: */
                    k = (int) lua_tointeger(L, -2);
                    if (k < 0) {
                        k = non_boundarychar;
                    }
                } else if (lt == LUA_TSTRING) {
                    const char *s = lua_tostring(L, -2);
                    if (lua_key_eq(s, right_boundary)) {
                        k = right_boundarychar;
                        if (!has_right_boundary(f))
                            set_right_boundary(f, get_charinfo(f, right_boundarychar));
                    }
                }
                r = -1;
                if (lua_istable(L, -1)) {
                    /*tex Ligature: */
                    set_numeric_field_by_index(r,char,-1);
                }
                if (r != -1 && k != non_boundarychar) {
                    set_enum_field_by_index(t,type,0,ligature_type_strings);
                    set_ligature_item(cligs[ctr], (char) ((t * 2) + 1), k, r);
                    ctr++;
                } else {
                    formatted_warning("font", "lua-loaded font %s char U+%X has an invalid ligature field", font_name(f), (int) i);
                }
                /*tex The iterator value: */
                lua_pop(L, 1);
            }
            /*tex A guard against empty tables. */
            if (ctr > 0) {
                set_ligature_item(cligs[ctr], 0, end_ligature, 0);
                set_charinfo_ligatures(co, cligs);
            } else {
                formatted_warning("font", "lua-loaded font %s char U+%X has an invalid ligatures field", font_name(f), (int) i);
            }
            /*tex The ligatures table. */
            lua_pop(L, 1); /*tex Do we pop enough: key and table? */
        }
    }
}

/*tex

    The caller has to fix the state of the lua stack when there is an error!

*/

int font_from_lua(lua_State * L, int f)
{
    /*tex The table is at stack |index -1| */
    char *s ;
    set_string_field_by_index(s,name);
    set_font_name(f,s);
    if (s == NULL) {
        formatted_error("font","lua-loaded font '%d' has no name!", f);
        return 0;
    } else {
        int no_math, j;
        set_numeric_field_by_index(j,designsize,655360);
        set_font_dsize(f,j);
        set_numeric_field_by_index(j,size,font_dsize(f));
        set_font_size(f,j);
        set_boolean_field_by_index(j,oldmath,0);
        set_font_oldmath(f,j);
        set_numeric_field_by_index(j,hyphenchar,default_hyphen_char_par);
        set_hyphen_char(f,j);
        set_numeric_field_by_index(j,skewchar,default_skew_char_par);
        set_skew_char(f,j);
        set_boolean_field_by_index(no_math,nomath,0);
        read_lua_parameters(L, f);
        if (!no_math) {
            read_lua_math_parameters(L, f);
            set_boolean_field_by_index(j,oldmath,0);
            set_font_oldmath(f,j);
        } else {
            set_font_oldmath(f,1);
        }
        /*tex The characters. */
        lua_key_rawgeti(characters);
        if (lua_istable(L, -1)) {
            /*tex Find the array size values; |num| holds the number of characters to add. */
            int num = 0;
            int ec = 0;
            int bc = -1;
            int i;
            /*tex The first key: */
            lua_pushnil(L);
            while (lua_next(L, -2) != 0) {
                if (lua_isnumber(L, -2)) {
                    i = (int) lua_tointeger(L, -2);
                    if (i >= 0) {
                        if (lua_istable(L, -1)) {
                            num++;
                            if (i > ec)
                                ec = i;
                            if (bc < 0)
                                bc = i;
                            if (bc >= 0 && i < bc)
                                bc = i;
                        }
                    }
                }
                lua_pop(L, 1);
            }
            if (bc != -1) {
                int fstep, fstretch, fshrink, lt;
                font_malloc_charinfo(f, num);
                set_font_bc(f, bc);
                set_font_ec(f, ec);
                /*tex The first key: */
                lua_pushnil(L);
                while (lua_next(L, -2) != 0) {
                    lt = lua_type(L,-2);
                    if (lt == LUA_TNUMBER) {
                        i = (int) lua_tointeger(L, -2);
                        if (i >= 0) {
                            font_char_from_lua(L, f, i, !no_math);
                        }
                    } else if (lt == LUA_TSTRING) {
                        const char *ss1 = lua_tostring(L, -2);
                        if (lua_key_eq(ss1, left_boundary)) {
                            font_char_from_lua(L, f, left_boundarychar, !no_math);
                        } else if (lua_key_eq(ss1, right_boundary)) {
                            font_char_from_lua(L, f, right_boundarychar, !no_math);
                        }
                    }
                    lua_pop(L, 1);
                }
                lua_pop(L, 1);
                /*tex

                    Handle font expansion last: We permits virtual fonts to use
                    expansion as one can always turn it off.

                */
                set_numeric_field_by_index(fstep,step,0);
                if (fstep < 0)
                    fstep = 0;
                if (fstep > 100)
                    fstep = 100;
                if (fstep != 0) {
                    set_numeric_field_by_index(fshrink,shrink,0);
                    set_numeric_field_by_index(fstretch,stretch,0);
                    if (fshrink < 0)
                        fshrink = 0;
                    if (fshrink > 500)
                        fshrink = 500;
                    fshrink -= (fshrink % fstep);
                    if (fshrink < 0)
                        fshrink = 0;
                    if (fstretch < 0)
                        fstretch = 0;
                    if (fstretch > 1000)
                        fstretch = 1000;
                    fstretch -= (fstretch % fstep);
                    if (fstretch < 0)
                        fstretch = 0;
                    set_expand_params(f, fstretch, fshrink, fstep);
                }

            } else {
                formatted_warning("font","lua-loaded font '%d' with name '%s' has no characters", f, font_name(f));
            }
        } else {
            formatted_warning("font","lua-loaded font '%d' with name '%s' has no character table", f, font_name(f));
        }
        return 1;
    }
}

int characters_from_lua(lua_State * L, int f)
{
    int i, lt;
    int no_math;
    /*tex Speedup: */
    set_boolean_field_by_index(no_math,nomath,0);
    /*tex The characters. */
    lua_key_rawgeti(characters);
    if (lua_istable(L, -1)) {
        /*tex Find the array size values; |num| has the amount. */
        int num = 0;
        int todo = 0;
        int bc = font_bc(f);
        int ec = font_ec(f);
        /*tex First key: */
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            if (lua_isnumber(L, -2)) {
                i = (int) lua_tointeger(L, -2);
                if (i >= 0) {
                    if (lua_istable(L, -1)) {
                        todo++;
                        if (! quick_char_exists(f,i)) {
                            num++;
                            if (i > ec)
                                ec = i;
                            if (bc < 0)
                                bc = i;
                            if (bc >= 0 && i < bc)
                                bc = i;
                        }
                    }
                }
            }
            lua_pop(L, 1);
        }
        if (todo > 0) {
            font_malloc_charinfo(f, num);
            set_font_bc(f, bc);
            set_font_ec(f, ec);
            /*tex First key: */
            lua_pushnil(L);
            while (lua_next(L, -2) != 0) {
                lt = lua_type(L,-2);
                if (lt == LUA_TNUMBER) {
                    i = (int) lua_tointeger(L, -2);
                    if (i >= 0) {
                        if (quick_char_exists(f,i)) {
                            charinfo *co = char_info(f, i);
                            set_charinfo_ligatures(co, NULL);
                            set_charinfo_kerns(co, NULL);
                            set_charinfo_vert_variants(co, NULL);
                            set_charinfo_hor_variants(co, NULL);
                        }
                        font_char_from_lua(L, f, i, !no_math);
                    }
                }
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
    }
    return 1;
}

/*tex Ligaturing starts here */

static void nesting_append(halfword nest1, halfword newn)
{
    halfword tail = tlink(nest1);
    if (tail == null) {
        couple_nodes(nest1, newn);
    } else {
        couple_nodes(tail, newn);
    }
    tlink(nest1) = newn;
}

static void nesting_prepend(halfword nest1, halfword newn)
{
    halfword head = vlink(nest1);
    couple_nodes(nest1, newn);
    if (head == null) {
        tlink(nest1) = newn;
    } else {
        couple_nodes(newn, head);
    }
}

static void nesting_prepend_list(halfword nest1, halfword newn)
{
    halfword head = vlink(nest1);
    couple_nodes(nest1, newn);
    if (head == null) {
        tlink(nest1) = tail_of_list(newn);
    } else {
        halfword tail = tail_of_list(newn);
        couple_nodes(tail, head);
    }
}

static int test_ligature(liginfo * lig, halfword left, halfword right)
{
    if (type(left) != glyph_node) {
        return 0;
    } else if (font(left) != font(right)) {
        return 0;
    } else if (is_ghost(left) || is_ghost(right)) {
        return 0;
    } else {
        *lig = get_ligature(font(left), character(left), character(right));
        if (is_valid_ligature(*lig)) {
            return 1;
        } else {
            return 0;
        }
    }
}

static int try_ligature(halfword * frst, halfword fwd)
{
    halfword cur = *frst;
    liginfo lig;
    if (test_ligature(&lig, cur, fwd)) {
        int move_after = (lig_type(lig) & 0x0C) >> 2;
        int keep_right = ((lig_type(lig) & 0x01) != 0);
        int keep_left = ((lig_type(lig) & 0x02) != 0);
        halfword newgl = raw_glyph();
        font(newgl) = font(cur);
        character(newgl) = lig_replacement(lig);
        set_is_ligature(newgl);
        /*tex
            Below might not be correct in contrived border case. but we use it
            only for debugging.
        */
        if (character(cur) < 0) {
            set_is_leftboundary(newgl);
        }
        if (character(fwd) < 0) {
            set_is_rightboundary(newgl);
        }
        if (character(cur) < 0) {
            if (character(fwd) < 0) {
                build_attribute_list(newgl);
            } else {
                add_node_attr_ref(node_attr(fwd));
                node_attr(newgl) = node_attr(fwd);
            }
        } else {
            add_node_attr_ref(node_attr(cur));
            node_attr(newgl) = node_attr(cur);
        }
        /*tex
            Maybe if this ligature is consists of another ligature we should add
            it's |lig_ptr| to the new glyphs |lig_ptr| (and cleanup the no longer
            needed node). This has a very low priority, so low that it might
            never happen.
        */
        /*tex Left side: */
        if (keep_left) {
            halfword new_first = copy_node(cur);
            lig_ptr(newgl) = new_first;
            couple_nodes(cur, newgl);
            if (move_after) {
                move_after--;
                cur = newgl;
            }
        } else {
            halfword prev = alink(cur);
            uncouple_node(cur);
            lig_ptr(newgl) = cur;
            couple_nodes(prev, newgl);
            cur = newgl;        /* as cur has disappeared */
        }
        /*tex Right side: */
        if (keep_right) {
            halfword new_second = copy_node(fwd);
            /*tex This is correct, because we {\em know} |lig_ptr| points to {\em one} node. */
            couple_nodes(lig_ptr(newgl), new_second);
            couple_nodes(newgl, fwd);
            if (move_after) {
                move_after--;
                cur = fwd;
            }
        } else {
            halfword next = vlink(fwd);
            uncouple_node(fwd);
            /*tex This works because we {\em know} |lig_ptr| points to {\em one} node. */
            couple_nodes(lig_ptr(newgl), fwd);
            if (next != null) {
                couple_nodes(newgl, next);
            }
        }
        /*tex Check and return. */
        *frst = cur;
        return 1;
    }
    return 0;
}

/*tex

    There shouldn't be any ligatures here - we only add them at the end of
    |xxx_break| in a \.{DISC-1 - DISC-2} situation and we stop processing
    \.{DISC-1} (we continue with \.{DISC-1}'s |post_| and |no_break|.

*/

static halfword handle_lig_nest(halfword root, halfword cur)
{
    if (cur) {
        while (vlink(cur) != null) {
            halfword fwd = vlink(cur);
            if (type(cur) == glyph_node && type(fwd) == glyph_node &&
                    font(cur) == font(fwd) && try_ligature(&cur, fwd)) {
                continue;
            }
            cur = vlink(cur);
        }
        tlink(root) = cur;
    }
    return root;
}

static halfword handle_lig_word(halfword cur)
{
    halfword right = null;
    if (type(cur) == boundary_node) {
        halfword prev = alink(cur);
        halfword fwd = vlink(cur);
        /*tex There is no need to uncouple |cur|, it is freed. */
        flush_node(cur);
        if (fwd == null) {
            vlink(prev) = fwd;
            return prev;
        } else {
            couple_nodes(prev, fwd);
            if (type(fwd) != glyph_node) {
                return prev;
            } else {
                cur = fwd;
            }
        }
    } else if (has_left_boundary(font(cur))) {
        halfword prev = alink(cur);
        halfword p = new_glyph(font(cur), left_boundarychar, glyph_data(cur));
        couple_nodes(prev, p);
        couple_nodes(p, cur);
        cur = p;
    }
    if (has_right_boundary(font(cur))) {
        right = new_glyph(font(cur), right_boundarychar, glyph_data(cur));
    }
    while (1) {
        /*tex A glyph followed by \unknown */
        if (type(cur) == glyph_node) {
            halfword fwd = vlink(cur);
            if (fwd == null) {
                /*tex The last character of a paragraph. */
                if (right == null) {
                    break;
                } else {
                    /*tex |par| prohibits the use of |couple_nodes| here. */
                    try_couple_nodes(cur, right);
                    right = null;
                    continue;
                }
            }
            if (type(fwd) == glyph_node) {
                /*tex a glyph followed by a glyph */
                if (font(cur) != font(fwd)) {
                    break;
                } else if (try_ligature(&cur, fwd)) {
                    continue;
                }
            } else if (type(fwd) == disc_node) {
                /*tex a glyph followed by a disc */
                halfword pre = vlink_pre_break(fwd);
                halfword nob = vlink_no_break(fwd);
                halfword next, tail;
                liginfo lig;
                /*tex Check on: |a{b?}{?}{?}| and |a+b=>B| : |{B?}{?}{a?}| */
                /*tex Check on: |a{?}{?}{b?}| and |a+b=>B| : |{a?}{?}{B?}| */
                if ((pre != null && type(pre) == glyph_node && test_ligature(&lig, cur, pre))
                       || (nob != null && type(nob) == glyph_node && test_ligature(&lig, cur, nob))) {
                    /*tex Move |cur| from before disc to skipped part */
                    halfword prev = alink(cur);
                    uncouple_node(cur);
                    couple_nodes(prev, fwd);
                    nesting_prepend(no_break(fwd), cur);
                    /*tex Now ligature the |pre_break|. */
                    nesting_prepend(pre_break(fwd), copy_node(cur));
                    /*tex As we have removed cur, we need to start again. */
                    cur = prev;
                }
                /*tex Check on: |a{?}{?}{}b| and |a+b=>B| : |{a?}{?b}{B}|. */
                next = vlink(fwd);
                if (nob == null && next != null && type(next) == glyph_node && test_ligature(&lig, cur, next)) {
                    /*tex Move |cur| from before |disc| to |no_break| part. */
                    halfword prev = alink(cur);
                    uncouple_node(cur);
                    couple_nodes(prev, fwd);
                    /*tex We {\em know} it's empty. */
                    couple_nodes(no_break(fwd), cur);
                    /*tex Now copy |cur| the |pre_break|. */
                    nesting_prepend(pre_break(fwd), copy_node(cur));
                    /*tex Move next from after disc to |no_break| part. */
                    tail = vlink(next);
                    uncouple_node(next);
                    try_couple_nodes(fwd, tail);
                    /*tex We {\em know} this works. */
                    couple_nodes(cur, next);
                    /*tex Make sure the list is correct. */
                    tlink(no_break(fwd)) = next;
                    /*tex Now copy next to the |post_break|. */
                    nesting_append(post_break(fwd), copy_node(next));
                    /*tex As we have removed cur, we need to start again. */
                    cur = prev;
                }
                /*tex We are finished with the |pre_break|. */
                handle_lig_nest(pre_break(fwd), vlink_pre_break(fwd));
            } else if (type(fwd) == boundary_node) {
                halfword next = vlink(fwd);
                try_couple_nodes(cur, next);
                flush_node(fwd);
                if (right != null) {
                    /*tex Shame, didn't need it. */
                    flush_node(right);
                    /*tex No need to reset |right|, we're going to leave the loop anyway. */
                }
                break;
            } else {
                /*tex Is something unknown. */
                if (right == null) {
                    break;
                } else {
                    couple_nodes(cur, right);
                    couple_nodes(right, fwd);
                    right = null;
                    continue;
                }
            }
            /*tex A discretionary followed by \unknown */
        } else if (type(cur) == disc_node) {
            /*tex If |{?}{x}{?}| or |{?}{?}{y}| then: */
            if (vlink_no_break(cur) != null || vlink_post_break(cur) != null) {
                halfword prev = 0;
                halfword fwd;
                liginfo lig;
                if (subtype(cur) == select_disc) {
                    prev = alink(cur);
                    if (vlink_post_break(cur) != null)
                        handle_lig_nest(post_break(prev), vlink_post_break(prev));
                    if (vlink_no_break(cur) != null)
                        handle_lig_nest(no_break(prev), vlink_no_break(prev));
                }
                if (vlink_post_break(cur) != null)
                    handle_lig_nest(post_break(cur), vlink_post_break(cur));
                if (vlink_no_break(cur) != null)
                    handle_lig_nest(no_break(cur), vlink_no_break(cur));
                while ((fwd = vlink(cur)) != null) {
                    halfword nob, pst, next;
                    if (type(fwd) != glyph_node) {
                        break;
                    } else if (subtype(cur) != select_disc) {
                        nob = tlink_no_break(cur);
                        pst = tlink_post_break(cur);
                        if ((nob == null || !test_ligature(&lig, nob, fwd)) &&
                            (pst == null || !test_ligature(&lig, pst, fwd))) {
                            break;
                        } else {
                            nesting_append(no_break(cur), copy_node(fwd));
                            handle_lig_nest(no_break(cur), nob);
                        }
                    } else {
                        int dobreak = 0;
                        nob = tlink_no_break(prev);
                        pst = tlink_post_break(prev);
                        if ((nob == null || !test_ligature(&lig, nob, fwd)) &&
                            (pst == null || !test_ligature(&lig, pst, fwd)))
                            dobreak = 1;
                        if (!dobreak) {
                            nesting_append(no_break(prev), copy_node(fwd));
                            handle_lig_nest(no_break(prev), nob);
                            nesting_append(post_break(prev), copy_node(fwd));
                            handle_lig_nest(post_break(prev), pst);
                        }
                        dobreak = 0;
                        nob = tlink_no_break(cur);
                        pst = tlink_post_break(cur);
                        if ((nob == null || !test_ligature(&lig, nob, fwd)) &&
                            (pst == null || !test_ligature(&lig, pst, fwd)))
                            dobreak = 1;
                        if (!dobreak) {
                            nesting_append(no_break(cur), copy_node(fwd));
                            handle_lig_nest(no_break(cur), nob);
                        }
                        if (dobreak)
                            break;
                    }
                    next = vlink(fwd);
                    uncouple_node(fwd);
                    try_couple_nodes(cur, next);
                    nesting_append(post_break(cur), fwd);
                    handle_lig_nest(post_break(cur), pst);
                }
                if (fwd != null && type(fwd) == disc_node) {
                        halfword next = vlink(fwd);
                        if (vlink_no_break(fwd) == null
                            && vlink_post_break(fwd) == null
                            && next != null
                            && type(next) == glyph_node
                            && ((tlink_post_break(cur) != null && test_ligature(&lig, tlink_post_break(cur), next)) ||
                                (tlink_no_break  (cur) != null && test_ligature(&lig, tlink_no_break  (cur), next)))) {
                        /*tex Building an |init_disc| followed by a |select_disc|: |{a-}{b}{AB} {-}{}{} c| */
                        halfword last1 = vlink(next), tail;
                        uncouple_node(next);
                        try_couple_nodes(fwd, last1);
                        /*tex |{a-}{b}{AB} {-}{c}{}| */
                        nesting_append(post_break(fwd), copy_node(next));
                        /*tex |{a-}{b}{AB} {-}{c}{-}| */
                        if (vlink_no_break(cur) != null) {
                            nesting_prepend(no_break(fwd), copy_node(vlink_pre_break(fwd)));
                        }
                        /*tex |{a-}{b}{AB} {b-}{c}{-}| */
                        if (vlink_post_break(cur) != null)
                            nesting_prepend_list(pre_break(fwd), copy_node_list(vlink_post_break(cur)));
                        /*tex |{a-}{b}{AB} {b-}{c}{AB-}| */
                        if (vlink_no_break(cur) != null) {
                            nesting_prepend_list(no_break(fwd), copy_node_list(vlink_no_break(cur)));
                        }
                        /*tex |{a-}{b}{ABC} {b-}{c}{AB-}| */
                        tail = tlink_no_break(cur);
                        nesting_append(no_break(cur), copy_node(next));
                        handle_lig_nest(no_break(cur), tail);
                        /*tex |{a-}{BC}{ABC} {b-}{c}{AB-}| */
                        tail = tlink_post_break(cur);
                        nesting_append(post_break(cur), next);
                        handle_lig_nest(post_break(cur), tail);
                        /*tex Set the subtypes: */
                        subtype(cur) = init_disc;
                        subtype(fwd) = select_disc;
                    }
                }
            }
        } else {
            /*tex We have glyph nor disc. */
            return cur;
        }
        /*tex Goto the next node, where |\par| allows |vlink(cur)| to be NULL. */
        cur = vlink(cur);
    }
    return cur;
}

/*tex The return value is the new tail, head should be a dummy: */

halfword handle_ligaturing(halfword head, halfword tail)
{
    if (vlink(head) == null) {
        return tail;
    } else {
        /*tex A trick to allow explicit |node==null| tests. */
        halfword save_tail1 = null;
        halfword cur, prev;
        if (tail != null) {
            save_tail1 = vlink(tail);
            vlink(tail) = null;
        }
        if (fix_node_lists) {
            fix_node_list(head);
        }
        prev = head;
        cur = vlink(prev);
        while (cur != null) {
            if (type(cur) == glyph_node || (type(cur) == boundary_node)) {
                cur = handle_lig_word(cur);
            }
            prev = cur;
            cur = vlink(cur);
        }
        if (prev == null) {
            prev = tail;
        }
        if (tail != null) {
            try_couple_nodes(prev, save_tail1);
        }
        return prev;
    }
}

/*tex Kerning starts here: */

static void add_kern_before(halfword left, halfword right)
{
    if ((!is_rightghost(right)) &&
        font(left) == font(right) && has_kern(font(left), character(left))) {
        int k = raw_get_kern(font(left), character(left), character(right));
        if (k != 0) {
            halfword kern = new_kern(k);
            halfword prev = alink(right);
            couple_nodes(prev, kern);
            couple_nodes(kern, right);
            /*tex Update the attribute list (inherit from left): */
            delete_attribute_ref(node_attr(kern)); /* not needed */
            add_node_attr_ref(node_attr(left));
            node_attr(kern) = node_attr(left);
        }
    }
}

static void add_kern_after(halfword left, halfword right, halfword aft)
{
    if ((!is_rightghost(right)) &&
        font(left) == font(right) && has_kern(font(left), character(left))) {
        int k = raw_get_kern(font(left), character(left), character(right));
        if (k != 0) {
            halfword kern = new_kern(k);
            halfword next = vlink(aft);
            couple_nodes(aft, kern);
            try_couple_nodes(kern, next);
            /*tex Update the attribute list (inherit from left == aft): */
            delete_attribute_ref(node_attr(kern)); /* not needed */
            add_node_attr_ref(node_attr(aft));
            node_attr(kern) = node_attr(aft);
        }
    }
}

static void do_handle_kerning(halfword root, halfword init_left, halfword init_right)
{
    halfword cur = vlink(root);
    if (cur == null) {
        if (init_left != null && init_right != null) {
            add_kern_after(init_left, init_right, root);
            tlink(root) = vlink(root);
        }
    } else {
        halfword left = null;
        if (type(cur) == glyph_node) {
            set_is_glyph(cur);
            if (init_left != null)
                add_kern_before(init_left, cur);
            left = cur;
        }
        while ((cur = vlink(cur)) != null) {
            if (type(cur) == glyph_node) {
                set_is_glyph(cur);
                if (left != null) {
                    add_kern_before(left, cur);
                    if (character(left) < 0 || is_ghost(left)) {
                        halfword prev = alink(left);
                        couple_nodes(prev, cur);
                        flush_node(left);
                    }
                }
                left = cur;
            } else {
                if (type(cur) == disc_node) {
                    halfword right = type(vlink(cur)) == glyph_node ? vlink(cur) : null;
                    do_handle_kerning(pre_break(cur), left, null);
                    if (vlink_pre_break(cur) != null)
                        tlink_pre_break(cur) = tail_of_list(vlink_pre_break(cur));
                    do_handle_kerning(post_break(cur), null, right);
                    if (vlink_post_break(cur) != null)
                        tlink_post_break(cur) = tail_of_list(vlink_post_break(cur));
                    do_handle_kerning(no_break(cur), left, right);
                    if (vlink_no_break(cur) != null)
                        tlink_no_break(cur) = tail_of_list(vlink_no_break(cur));
                }
                if (left != null) {
                    if (character(left) < 0 || is_ghost(left)) {
                        halfword prev = alink(left);
                        couple_nodes(prev, cur);
                        flush_node(left);
                    }
                    left = null;
                }
            }
        }
        if (left) {
            if (init_right != null)
                add_kern_after(left, init_right, left);
            if (character(left) < 0 || is_ghost(left)) {
                halfword prev = alink(left);
                halfword next = vlink(left);
                if (next != null) {
                    couple_nodes(prev, next);
                    tlink(root) = next;
                } else if (prev != root) {
                    vlink(prev) = null;
                    tlink(root) = prev;
                } else {
                    vlink(root) = null;
                    tlink(root) = null;
                }
                flush_node(left);
            }
        }
    }
}

halfword handle_kerning(halfword head, halfword tail)
{
    halfword save_link = null;
    if (tail) {
        save_link = vlink(tail);
        vlink(tail) = null;
        tlink(head) = tail;
        do_handle_kerning(head, null, null);
        tail = tlink(head);
        if (valid_node(save_link)) {
            try_couple_nodes(tail, save_link);
        }
    } else {
        tlink(head) = null;
        do_handle_kerning(head, null, null);
    }
    return tail;
}

/*tex The ligaturing and kerning \LUA\ interface: */

static halfword run_lua_ligkern_callback(halfword head, halfword tail, int callback_id)
{
    int top;
    if ((top = callback_okay(Luas, callback_id))) {
        int i;
        nodelist_to_lua(Luas, head);
        nodelist_to_lua(Luas, tail);
        i = callback_call(Luas,2,0,top);
        if (i != 0) {
            callback_error(Luas,top,i);
        } else {
            if (fix_node_lists) {
                fix_node_list(head);
            }
            callback_wrapup(Luas,top);
        }
    }
    return tail;
}

halfword new_ligkern(halfword head, halfword tail)
{
    if (vlink(head)) {
        int callback_id = callback_defined(ligaturing_callback);
        if (callback_id > 0) {
            tail = run_lua_ligkern_callback(head, tail, callback_id);
            if (!tail) {
                tail = tail_of_list(head);
            }
        } else if (callback_id == 0) {
            tail = handle_ligaturing(head, tail);
        } else {
            /* -1 : disable */
        }
        callback_id = callback_defined(kerning_callback);
        if (callback_id > 0) {
            tail = run_lua_ligkern_callback(head, tail, callback_id);
            if (!tail) {
                tail = tail_of_list(head);
            }
        } else if (callback_id == 0) {
            halfword nest1 = new_node(nesting_node, 1);
            halfword cur = vlink(head);
            halfword aft = vlink(tail);
            couple_nodes(nest1, cur);
            tlink(nest1) = tail;
            vlink(tail) = null;
            do_handle_kerning(nest1, null, null);
            couple_nodes(head, vlink(nest1));
            tail = tlink(nest1);
            try_couple_nodes(tail, aft);
            flush_node(nest1);
        } else {
            /* -1 : disable */
        }
    }
    return tail;
}
