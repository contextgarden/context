/*
    See license.txt in the root of this project.
*/

/*tex

    The code here has to deal with traditional \TEX\ fonts as well as the more modern \OPENTYPE\
    fonts. In \TEX\ fonts the spacing between and construction of glyphs is determined by font
    parameters, kerns, italic correction and linked lists of glyphs that make extensibles. In
    \OPENTYPE\ fonts kerns are replaced by so called staircase kerns, italics are used differently
    and extensibles are made from other glyphs, as in traditional \TEX\ fonts.

    In traditional \TEX\ the italic correction is added to the width of the glyph. This is part of
    the engine design and this is also reflected in the width metric of the font. In \OPENTYPE\ math
    this is different. There the italic correction had more explicit usage. The 1.7 spec says:

    \startitemize

    \startitem
        {\em italic correction:} When a run of slanted characters is followed by a straight
        character (such as an operator or a delimiter), the italics correction of the last glyph is
        added to its advance width.

        When positioning limits on an N-ary operator (e.g., integral sign), the horizontal position
        of the upper limit is moved to the right by half the italics correction, while the position
        of the lower limit is moved to the left by the same distance. Comment HH: this is is only
        true when we have a real italic integral where the top part stick out right and the bottom
        part left. So, that's only 'one' n-ary operator.

        When positioning superscripts and subscripts, their default horizontal positions are also
        different by the amount of the italics correction of the preceding glyph.
    \stopitem

    \startitem
        {\em math kerning:} Set the default horizontal position for the superscript as shifted
        relative to the position of the subscript by the italics correction of the base glyph.
    \stopitem

    \stopitemize

    Before this was specified we had to gamble a bit and assume that cambria was the font
    benchmark and trust our eyes (and msword) for the logic. I must admit that I have been
    fighting these italics in fonts (and the heuristics that \LUAMETATEX\ provided) right from the
    start (for instance by using \LUA\ based postprocessing) but by now we know more and have more
    fonts to test with. More fonts are handy because not all fonts are alike when it comes to
    italics. Axis are another area of concern, as it looks like \OPENTYPE\ math fonts often already
    apply that shift.

    Now, one can think of cheating. Say that we add the italic correction to the widths and then
    make the italic correction zero for all these shapes except those that have a slope, in which
    case we negate tot correction. Unfortunately that doesn't work well because the traditional
    code path {\em assumes} the too narrow shape: it doesn't compensate subscripts. Also, keep in
    mind that in for instance Pagella (etc), at least in the pre 2022 versions, even upright
    characters have italic corrections! It looks like they are used as kerns in a way similar to
    staircase kerns. So, here, when we add the correction we incorrectly flag it as italic but we
    have no way to distinguish them from regular kerns. When the gyre fonts never get corrected
    we're stick with the two code paths forever.

    Blocking italic correction via the glyph options is supported (not yet for other constructs
    but that might happen). All this italic stuff makes the source a bit messy. Maybe the other
    things will be controlled via a noad option.

    The above description is no longer accurate but we keep it for historic reasons. We now
    follow a reverse approach: we just assume \OPENTYPE\ but also expect the needed features to
    be enabled explicitly. That means that for instance \quote {out of the box} the engine will
    not apply italic correction.

    In 2021-2022 Mikael Sundqvist and I (Hans Hagen) spent about a year investigating how we could
    improve the rendering of math. Quite a bit of research went into that and we decided to get rid 
    of some old font code and concentrate on the \OPENTYPE\ fonts, although we found some flaws and 
    inconsistencies in them. The solution was to assume a Cambria alike font and adapt the other 
    fonts runtime using so called goodie files that are part of the \CONTEXT\ font loading code. 
    That way we could enforce some consistency and compentate for e.g. problematic  dimensions like
    widths and italic corrections as well as bad top accents and values of font parameters that 
    interfered with what we had in mind. We added plenty extra ones as well as extra kern options. 
    Combined with a more rich model for inter atom spacing we could improve the look and feel a lot. 

    When the engine got updated a couple of options came and went. An example of this is delimiter 
    options. For instance we tracked if a delimiter was actually changes and could then react to that 
    wrt italic corrections. In the new approach we no longer handle that because assume decent fonts 
    or at least tweaked ones (read: \CONTEXT\ font goodies being applied). So in the end those extra
    delimiter options got removed or were just handled by the noad options. The code is still in the 
    repository. Also some options related to tracing injected kerns became defaults because we had 
    them always turned on. 

*/

/* 

    There is a persistent issue with operators and italic correction. For n_ary ones the italic 
    correction is used for positioning scripts above or below (shifted horizontally) or 
    at the right top and bottom (also shifted horizontally). That assumes a proper width that 
    doesn't need italic correction itself. On the other hand, in the case of arbitrary characters 
    that want to be operators the italic correction can be part of th ewidth (take the |f| as 
    example). Now, the most problematic one is the integral and especially in Latin Modern where 
    it is very slanted. In \CONTEXT\ we use the left operator feature to deal with all this. 

    We considered a special class for operators where italic correction is used for positioning 
    but in the end we rejected that. We now: 

    \startitemize
    \startitem 
        asume properly bounded characters (sum, product, integral) and most are upright anyway
    \stopitem 
    \startitem  
        top and bottom scripts are centered 
    \stopitem 
    \startitem 
        right and left scripts are bound tight to the edge 
    \stopitem 
    \startitem  
        italic correction can be completely ignored 
    \stopitem 
    \startitem  
        top and bottom anchors (set up in the goodie) control optional displacements 
    \stopitem 
    \startitem  
        top right and top left kerns (set up in the goodie) control optional displacements 
    \stopitem 
    \stopitemize

    We already did the kerns for some fonts using information in the goodie file, and now we 
    also use the top and bottom anchors. In fact, the only real exception is Latin Modern, so 
    instead of messing up the code with exceptions and tricky controls we now have a few lines 
    in (basically) one goodie file. 

    An class option can be set to add italic corrections to operators so in the case of the 
    integral, where it is used for positioning, it can then be used to calculate anchors, but 
    that is then done in the goodie file. Keep in mind that these anchors are an engine feature.

    For most math fonts all works out of the box, only fonts with highly asymetrical integral 
    signs are touched by this, but fonts like that likely need tweaks anyway. 

    For the record: the specificaton only talks about possible application so we can basically do 
    as we like. All works fine for Cambria and the \TEX\ community didn't make sure that better 
    features were added (like anchors) for their shapes. 

    In the end, from the perspective of ConTeXt, the italics code can completely go away which 
    means that we also no longer have to stare at somewhat fuzzy code originating in dealing 
    with italics. It depends on how well our latest heuristic tweaks work out. 

*/

# include "luametatex.h"

/*tex

    We have some more function calls and local so we have replace |cur_style| by |style| where that
    makes sense. The same is true for some local variables. This makes it a bit easier to
    distinguish with the more global variables stored in state structures.

    It's a stepwise process ... occasionally I visit this file and change the short variable names
    to more verbose. There is also relatively new scaling code that needs checking.

*/

static void tex_aux_append_hkern_to_box_list (halfword q, scaled delta, halfword subtype, const char *trace);
static void tex_aux_prepend_hkern_to_box_list(halfword q, scaled delta, halfword subtype, const char *trace);

/*tex

    \LUAMETATEX\ makes a bunch of extensions cf.\ the |MATH| table in \OPENTYPE, but some of the
    |MathConstants| values have no matching usage in \LUAMETATEX\ right now.

    \startitemize

        \startitem
            |ScriptPercentScaleDown| |ScriptScriptPercentScaleDown|: These should be handled by the
            macro package, on the engine side there are three separate fonts.
        \stopitem

        \startitem
            |DelimitedSubFormulaMinHeight|: This is perhaps related to word's natural math input?
            We have no idea what to do about it.
        \stopitem

        \startitem
            |MathLeading|: \LUAMETATEX\ does not currently handle multi line displays, and the
            parameter does not seem to make much sense elsewhere.
        \stopitem

        \startitem
            |FlattenedAccentBaseHeight|: This is based on the |flac| |GSUB| feature. It would not
            be hard to support that, but proper math accent placements cf.\ |MATH| needs support
            for |MathTopAccentAttachment| table to be implemented first. We actually do support 
            it in \LUAMETATEX. 
        \stopitem

    \stopitemize

    Old-style fonts do not define the |radical_rule|. This allows |make_radical| to select the
    backward compatibility code, but it also means that we can't raise an error here.

    Occasionally I visit this file and make some variables more verbose.

    In the meantime some experimental and obsolete code has been removed but it can be found in 
    the development repository if really needed. It makes no sense to keep code around that has 
    been replaced or improved otherwise. Some code we keep commented for a while before it is 
    flushed out. 

*/

typedef struct scriptdata {
    halfword node;   
    halfword fnt;  
    halfword chr;  
    halfword box;
    scaled   kern; 
    scaled   slack;
    int      shifted;
    int      padding;
} scriptdata;

typedef struct delimiterextremes {
    scaled tfont;
    scaled tchar;
    scaled bfont;
    scaled bchar;
    scaled height;
    scaled depth;
} delimiterextremes; 

typedef enum limits_modes {
    limits_unknown_mode,    
    limits_vertical_mode,   // limits 
    limits_horizontal_mode, // no limits 
} limits_modes;

inline static void tex_math_wipe_kerns(kernset *kerns) {
    if (kerns) { 
        kerns->topright = 0;
        kerns->topleft = 0;
        kerns->bottomright = 0;
        kerns->bottomleft = 0;
        kerns->height = 0;
        kerns->depth = 0;
        kerns->toptotal = 0;
        kerns->bottomtotal = 0;
        kerns->dimensions = 0;
        kerns->font = null_font;
        kerns->character = 0;
        kerns->padding = 0;
    }
}

inline static void tex_math_copy_kerns(kernset *kerns, kernset *parent) {
    if (kerns && parent) { 
        kerns->topright = parent->topright;
        kerns->topleft = parent->topleft;
        kerns->bottomright = parent->bottomright;
        kerns->bottomleft = parent->bottomleft;
        kerns->height = parent->height;
        kerns->depth = parent->depth;
        kerns->toptotal = parent->toptotal;
        kerns->bottomtotal = parent->bottomtotal;
        kerns->dimensions = parent->dimensions;
        kerns->font = parent->font;
        kerns->character = parent->character;
    }
}

/*tex
    When the style changes, the following piece of program computes associated information:
*/

inline static halfword tex_aux_set_style_to_size(halfword style)
{
    switch (style) {
        case script_style:
        case cramped_script_style:
            return script_size;
        case script_script_style:
        case cramped_script_script_style:
            return script_script_size;
        default:
            return text_size;
    }
}

inline static void tex_aux_set_current_math_scale(halfword scale)
{
    glyph_scale_par = scale;   
    lmt_math_state.scale = glyph_scale_par;    
}

inline static void tex_aux_set_current_math_size(halfword style)
{
    lmt_math_state.size = tex_aux_set_style_to_size(style);
}

inline static void tex_aux_make_style(halfword current, halfword *current_style, halfword *current_mu)
{ 
    halfword style = node_subtype(current);
    switch (style) {
        case scaled_math_style:
            tex_aux_set_current_math_scale(style_scale(current));   
            break;
        default:
            if (is_valid_math_style(style)) {
                if (current_style) { 
                    *current_style = style;
                }
                tex_aux_set_current_math_size(style);
                if (current_mu) { 
                    *current_mu = scaledround((double) tex_get_math_quad_style(style) / 18.0);
                }
            }
            break;
    }
}

void tex_set_math_text_font(halfword style, int usetextfont)
{
     halfword size = tex_aux_set_style_to_size(style);
     halfword font = tex_fam_fnt(cur_fam_par, size);
     halfword scale = tex_get_math_font_scale(font, size);
     switch (usetextfont) {
         case math_atom_text_font_option:
             scale = scaledround((double) scale * (double) lmt_font_state.fonts[font]->size / (double) lmt_font_state.fonts[cur_font_par]->size);
             break;
         case math_atom_math_font_option:
             update_tex_font(0, font);
             break;
     }
     update_tex_glyph_scale(scale);
}

static halfword tex_aux_math_penalty_what(int pre, halfword cls, halfword pre_code, halfword post_code)
{
    halfword value = count_parameter(pre ? (pre_code + cls) : (post_code + cls));
    if (value == infinite_penalty) {
        unsigned parent = (unsigned) count_parameter(first_math_parent_code + cls);
        cls = pre ? ((parent >> 8) & 0xFF) : (parent & 0xFF);
        if (! valid_math_class_code(cls)) {
            return infinite_penalty;
        }
        value = count_parameter(pre ? (pre_code + cls) : (post_code + cls));
    }
    return value;
}

static halfword tex_aux_math_penalty(int main_style, int pre, halfword cls)
{
    switch (main_style) {
        case display_style:
        case cramped_display_style:
            {    
                halfword value = tex_aux_math_penalty_what(pre, cls, first_math_display_pre_penalty_code, first_math_display_post_penalty_code);
                if (value != infinite_penalty) {
                    return value;
                } else { 
                    break;
                }
            }
    }
    return tex_aux_math_penalty_what(pre, cls, first_math_pre_penalty_code, first_math_post_penalty_code);
}

inline static scaled limited_scaled(long l) {
    if (l > max_dimen) {
        return max_dimen;
    } else if (l < -max_dimen) {
        return -max_dimen;
    } else {
        return (scaled) l;
    }
}

inline static scaled limited_rounded(double d) {
    long l = scaledround(d);
    if (l > max_dimen) {
        return max_dimen;
    } else if (l < -max_dimen) {
        return -max_dimen;
    } else {
        return (scaled) l;
    }
}

inline static int tex_aux_math_engine_control(halfword fnt, halfword control)
{
 // if (fnt && (math_font_control_par & math_control_use_font_control) == math_control_use_font_control) {
    if (fnt && (font_mathcontrol(fnt) & math_control_use_font_control) == math_control_use_font_control) {
        /*tex 
            This is only for old fonts and it might go away eventually. Not all control options relate to 
            a font.
        */
        return (font_mathcontrol(fnt) & control) == control;
    }
    return (math_font_control_par & control) == control;
}

/*

    Todo: When we pass explicit dimensions (keyword driven) we use a different helper so that, if
    needed we can add debug messages. These values {\em are} scaled according to the glyph scaling
    so basically they are relative measures. Maybe we need an extra parameter to control this.

*/

inline static scaled tex_aux_math_glyph_scale(scaled v)
{
    return v ? scaledround(0.001 * glyph_scale_par * v) : 0;
}

inline static scaled tex_aux_math_x_scaled(scaled v, int style)
{
    scaled scale = tex_get_math_parameter(style, math_parameter_x_scale, NULL);
    return v ? limited_rounded(0.000000001 * glyph_scale_par * glyph_x_scale_par * v * scale) : 0;
}

inline static scaled tex_aux_math_given_x_scaled(scaled v)
{
    return v;
}

/* used for math_operator_size */

inline static scaled tex_aux_math_y_scaled(scaled v, int style)
{
    scaled scale = tex_get_math_parameter(style, math_parameter_y_scale, NULL);
    return v ? limited_rounded(0.000000001 * glyph_scale_par * glyph_y_scale_par * v * scale) : 0;
}

inline static scaled tex_aux_math_given_y_scaled(scaled v)
{
    return v;
}

inline static scaled tex_aux_math_axis(halfword size)
{
    scaled a = tex_math_axis_size(size); /* already scaled to size and x_scale */
    return a ? limited_rounded(0.000001 * glyph_scale_par * glyph_y_scale_par * a) : 0;
}

inline static scaled tex_aux_math_x_size_scaled(halfword f, scaled v, halfword size)
{
    return v ? limited_rounded(0.000000001 * tex_get_math_font_scale(f, size) * glyph_scale_par * glyph_x_scale_par * v) : 0;
}

inline static scaled tex_aux_math_y_size_scaled(halfword f, scaled v, halfword size)
{
    return v ? limited_rounded(0.000000001 * tex_get_math_font_scale(f, size) * glyph_scale_par * glyph_y_scale_par * v) : 0;
}

halfword tex_math_font_char_ht(halfword fnt, halfword chr, halfword style)
{
    return tex_aux_math_y_size_scaled(fnt, tex_char_height_from_font(fnt, chr), tex_aux_set_style_to_size(style));
}

halfword tex_math_font_char_dp(halfword fnt, halfword chr, halfword style)
{
    return tex_aux_math_y_size_scaled(fnt, tex_char_depth_from_font(fnt, chr), tex_aux_set_style_to_size(style));
}

inline static halfword tex_aux_new_math_glyph(halfword fnt, halfword chr, quarterword subtype) {
    halfword scale = 1000;
    halfword glyph = tex_new_glyph_node(subtype, fnt, tex_get_math_char(fnt, chr, lmt_math_state.size, &scale, math_direction_par), null); /* todo: data */;
    set_glyph_options(glyph, glyph_options_par);
    glyph_scale(glyph) = tex_aux_math_glyph_scale(scale);
    glyph_x_scale(glyph) = glyph_x_scale_par;
    glyph_y_scale(glyph) = glyph_y_scale_par;
    glyph_protected(glyph) = glyph_protected_math_code;
    return glyph;
}

halfword tex_new_math_glyph(halfword fnt, halfword chr) {
    return tex_aux_new_math_glyph(fnt, chr, 0);
}

static void tex_aux_trace_kerns(halfword kern, const char *what, const char *detail)
{
    if (tracing_math_par >= 2) {
        tex_begin_diagnostic();
        tex_print_format("[math: %s, %s, amount %D]", what, detail, kern_amount(kern), pt_unit);
        tex_end_diagnostic();
    }
}

static halfword tex_aux_math_insert_font_kern(halfword current, scaled amount, halfword template, const char *trace)
{
    /*tex Maybe |math_font_kern|, also to prevent expansion. */
    halfword kern = tex_new_kern_node(amount, font_kern_subtype);
    tex_attach_attribute_list_copy(kern, template ? template : current);
    if (node_next(current)) {
        tex_couple_nodes(kern, node_next(current));
    }
    tex_couple_nodes(current, kern);
    tex_aux_trace_kerns(kern, "adding font kern", trace);
    return kern; 
}

static halfword tex_aux_math_insert_italic_kern(halfword current, scaled amount, halfword template, const char *trace)
{
    /*tex Maybe |math_italic_kern|. */
    halfword kern = tex_new_kern_node(amount, italic_kern_subtype);
    tex_attach_attribute_list_copy(kern, template ? template : current);
    if (node_next(current)) {
        tex_couple_nodes(kern, node_next(current));
    }
    tex_couple_nodes(current, kern);
    tex_aux_trace_kerns(kern, "adding italic kern", trace);
    return kern;
}

static int tex_aux_math_followed_by_italic_kern(halfword current, const char *trace)
{
    if (current) {
        halfword next = node_next(current);
        if (next && node_type(next) == kern_node && node_subtype(next) == italic_kern_subtype) {
            tex_aux_trace_kerns(next, "ignoring italic kern", trace);
            return 1;
        }
    }
    return 0;
}

inline static int tex_aux_checked_left_kern_fnt_chr(halfword fnt, halfword chr, halfword state, halfword subtype)
{
    halfword top = 0;
    halfword bot = 0;
    halfword hastop = (state & prime_script_state) || (state & post_super_script_state);
    halfword hasbot = state & post_sub_script_state;
    if (hastop && tex_math_has_class_option(subtype, left_top_kern_class_option)) {
        top = tex_char_top_left_kern_from_font(fnt, chr);
    }
    if (hasbot && tex_math_has_class_option(subtype, left_bottom_kern_class_option)) {
        bot = tex_char_bottom_left_kern_from_font(fnt, chr);
    }
    if (hastop && hasbot) {
        return top > bot ? top : bot;
    } else if (hastop) {
        return top;
    } else {
        return bot;
    }
}

inline static int tex_aux_checked_left_kern(halfword list, halfword state, halfword subtype)
{
    if (list && node_type(list) == glyph_node) { 
        return tex_aux_checked_left_kern_fnt_chr(glyph_font(list), glyph_character(list), state, subtype);
    } else {
        return 0;
    }
}

inline static int tex_aux_checked_right_kern_fnt_chr(halfword fnt, halfword chr, halfword state, halfword subtype)
{
    halfword top = 0;
    halfword bot = 0;
    halfword hastop = state & pre_super_script_state;
    halfword hasbot = state & pre_sub_script_state;
    if (hastop && tex_math_has_class_option(subtype, right_top_kern_class_option)) {
        top = tex_char_top_right_kern_from_font(fnt, chr);
    }
    if (hasbot && tex_math_has_class_option(subtype, right_bottom_kern_class_option)) {
        bot = tex_char_bottom_right_kern_from_font(fnt, chr);
    }
    if (hastop && hasbot) {
        return top < bot ? bot : top;
    } else if (hastop) {
        return top;
    } else {
        return bot;
    }
}

inline static int tex_aux_checked_right_kern(halfword list, halfword state, halfword subtype)
{
    if (list && node_type(list) == glyph_node) { 
        return tex_aux_checked_right_kern_fnt_chr(glyph_font(list), glyph_character(list), state, subtype);
    } else {
        return 0;
    }
}

static scaled tex_aux_check_rule_thickness(halfword target, int size, halfword *fam, halfword control, halfword param)
{
    halfword family = noad_family(target);
    if (family != unused_math_family) {
        halfword font = tex_fam_fnt(family, size);
        if (tex_aux_math_engine_control(font, control)) {
            scaled thickness = tex_get_font_math_parameter(font, size, param);
            if (thickness != undefined_math_parameter) {
                *fam = family;
                return thickness;
            }
        }
    }
    return undefined_math_parameter;
}

/*tex Fake character */

static halfword tex_aux_fake_nucleus(quarterword cls)
{
    halfword n = tex_new_node(simple_noad, cls);
    halfword q = tex_new_node(math_char_node, 0);
    set_noad_classes(n, cls);
    noad_nucleus(n) = q;
    math_kernel_node_set_option(q, math_kernel_ignored_character);
    return n;
}

/*tex For tracing purposes we add a kern instead of just adapting the width. */

static void tex_aux_fake_delimiter(halfword result)
{
    halfword amount = tex_aux_math_given_x_scaled(null_delimiter_space_par);
    if (amount) {
        box_width(result) = amount;
        box_list(result) = tex_new_kern_node(amount, horizontal_math_kern_subtype);
        tex_attach_attribute_list_copy(box_list(result), result);
    }
}

/*tex 
    A variant on a suggestion on the list based on analysis by Ulrik Vieth it in the mean 
    adapted. We keep these 500 and 2 because then we can use similar values. 
*/

static scaled tex_aux_get_delimiter_height(scaled height, scaled depth, int axis, int size, int style)
{
    scaled delta1 = height + depth;
    scaled delta2 = depth;
    scaled delta3 = 0;
    halfword percent = tex_get_math_parameter_default(style, math_parameter_delimiter_percent, 0);
    scaled shortfall = tex_get_math_y_parameter_default(style, math_parameter_delimiter_shortfall, 0);
    if (axis) {
        delta2 += tex_aux_math_axis(size);
    }
    delta1 -= delta2;
    if (delta2 > delta1) {
        /*tex |delta1| is max distance from axis */
        delta1 = delta2;
    }
    delta3 = scaledround((delta1 / 500.0) * delimiter_factor_par * (percent / 100.0));
    delta2 = 2 * delta1 - delimiter_shortfall_par - shortfall;
    return (delta3 < delta2) ? delta2 : delta3;
}

/*tex

    In order to convert mlists to hlists, i.e., noads to nodes, we need several subroutines that
    are conveniently dealt with now.

    Let us first introduce the macros that make it easy to get at the parameters and other font
    information. A size code, which is a multiple of 256, is added to a family number to get an
    index into the table of internal font numbers for each combination of family and size. (Be
    alert: size codes get larger as the type gets smaller.) In the meantime we use different
    maxima and packing as in \LUATEX.

*/

static const char *tex_aux_math_size_string(int s)
{
    switch (s) {
        case script_script_size: return "scriptscriptfont";
        case script_size:        return "scriptfont";
        default:                 return "textfont";
    }
}

/*tex Here is a simple routine that creates a flat copy of a nucleus. */

static halfword tex_aux_math_clone(halfword n)
{
    if (n) {
        halfword result = tex_new_node(node_type(n), 0);
        tex_attach_attribute_list_copy(result, n);
        tex_math_copy_char_data(result, n, 0);
        return result;
    } else {
        return null;
    }
}

/*tex
    A helper used in void or phantom situations. We replace the content by a rule so that we still
    have some content (handy for tracing).
*/

static halfword tex_aux_make_list_phantom(halfword source, int nowidth, halfword att)
{
    halfword target = null;
    switch (node_type(source)) {
        case hlist_node:
            target = tex_new_node(hlist_node, node_subtype(source));
            break;
        case vlist_node:
            target = tex_new_node(vlist_node, node_subtype(source));
            break;
    }
    if (target) {
        halfword rule = tex_new_rule_node(empty_rule_subtype);
        tex_attach_attribute_list_attribute(target, att);
        tex_attach_attribute_list_attribute(rule, att);
        rule_width(rule) = nowidth ? 0 : box_width(source);
        rule_height(rule) = box_height(source);
        rule_depth(rule) = box_depth(source);
        box_dir(target) = dir_lefttoright ;
        box_height(target) = rule_height(rule);
        box_depth(target) = rule_depth(rule);
        box_width(target) = rule_width(rule);
        box_shift_amount(target) = box_shift_amount(source);
        box_list(target) = rule;
        tex_flush_node_list(source);
        return target;
    } else {
        return source;
    }
}

/*tex

    Here is a function that returns a pointer to a rule node having a given thickness |t|. The rule
    will extend horizontally to the boundary of the vlist that eventually contains it.

*/

static halfword tex_aux_fraction_rule(scaled width, scaled height, halfword att, quarterword ruletype, halfword size, halfword fam)
{
    halfword rule = null;
    int callback_id = lmt_callback_defined(math_rule_callback);
    if (callback_id > 0) {
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddddN->N", math_rules_mode_par ? ruletype : normal_rule_subtype, tex_fam_fnt(fam, size), width, height, att, &rule);
        if (rule && node_type(rule) != hlist_node) {
            rule = tex_hpack(rule, 0, packing_additional, direction_unknown, holding_none_option);
            node_subtype(rule) = math_rule_list;
            tex_attach_attribute_list_attribute(rule, att);
         }
    }
    if (! rule) {
        if (math_rules_mode_par) {
            rule = tex_new_rule_node(ruletype);
            rule_data(rule) = tex_fam_fnt(fam, size);
        } else {
            rule = tex_new_rule_node(normal_rule_subtype);
        }
        rule_height(rule) = height;
        rule_depth(rule) = 0;
        tex_attach_attribute_list_attribute(rule, att);
    }
    return rule;
}

/*tex

    The |overbar| function returns a pointer to a vlist box that consists of a given box |b|, above
    which has been placed a kern of height |k| under a fraction rule of thickness |t| under
    additional space of height |ht|.

*/

static halfword tex_aux_overbar(halfword box, scaled gap, scaled height, scaled krn, halfword att, quarterword index, halfword size, halfword fam)
{
    halfword rule = tex_aux_fraction_rule(box_width(box), height, att, index, size, fam);
    if (gap) {
        halfword kern = tex_new_kern_node(gap, vertical_math_kern_subtype);
        tex_attach_attribute_list_attribute(kern, att);
        tex_couple_nodes(kern, box);
        tex_couple_nodes(rule, kern);
    } else {
        tex_couple_nodes(rule, box);
    }
    if (krn) {
        halfword kern = tex_new_kern_node(krn, vertical_math_kern_subtype);
        tex_attach_attribute_list_attribute(kern, att);
        tex_couple_nodes(kern, rule);
        rule = kern;
    }
    rule = tex_vpack(rule, 0, packing_additional, max_dimen, (singleword) math_direction_par, holding_none_option);
    tex_attach_attribute_list_attribute(rule, att);
    return rule;
}

static halfword tex_aux_underbar(halfword box, scaled gap, scaled height, scaled krn, halfword att, quarterword index, halfword size, halfword fam)
{
    halfword rule = tex_aux_fraction_rule(box_width(box), height, att, index, size, fam);
    if (gap) {
        halfword kern = tex_new_kern_node(gap, vertical_math_kern_subtype);
        tex_attach_attribute_list_attribute(kern, att);
        tex_couple_nodes(box, kern);
        tex_couple_nodes(kern, rule);
    } else {
        tex_couple_nodes(box, rule);
    }
    if (krn) {
        halfword kern = tex_new_kern_node(krn, vertical_math_kern_subtype);
        tex_attach_attribute_list_attribute(kern, att);
        tex_couple_nodes(rule, kern);
    }
    rule = tex_vpack(box, 0, packing_additional, max_dimen, (singleword) math_direction_par, holding_none_option);
    tex_attach_attribute_list_attribute(rule, att);
    /* */
    box_depth(rule) = box_total(rule) + krn - box_height(box);
    box_height(rule) = box_height(box);
    /* */
    return rule;
}

/*tex

    Here is a subroutine that creates a new box, whose list contains a single character, and whose
    width includes the italic correction for that character. The height or depth of the box will be
    negative, if the height or depth of the character is negative. Thus, this routine may deliver a
    slightly different result than |hpack| would produce.

    The oldmath font flag can be used for cases where we pass a new school math constants (aka
    parameters) table but have a (virtual) font assembled that uses old school type one fonts. In
    that case we have a diffeent code path for:

    \startitemize
        \startitem rule thickness \stopitem
        \startitem accent skew \stopitem
        \startitem italic correction (normal width assumes it to be added) \stopitem
        \startitem kerning \stopitem
        \startitem delimiter construction \stopitem
        \startitem accent placement \stopitem
    \stopitemize

    We keep this as reference but oldmath handling has been replaces by options that determine code
    paths. We actually assuem that \OPENTRYPE fonts are used anyway. The flag is gone. 

    In the traditional case an italic kern is always added and the |ic| variable is then passed
    to the caller. For a while we had an option to add the correction to the width but now we
    have the control options. So these are the options:

    - traditional: insert a kern and pass that correction.
    - opentype   : traditional_math_char_italic_width: add to width
    -            : traditional_math_char_italic_pass : pass ic

    Adding a kern in traditional mode is a mode driven option, not a font one.

*/

static halfword tex_aux_char_box(halfword fnt, int chr, halfword att, scaled *ic, quarterword subtype, scaled target, int style)
{
    /*tex The new box and its character node. */
    halfword glyph = tex_aux_new_math_glyph(fnt, chr, subtype);
    halfword box = tex_new_null_box_node(hlist_node, math_char_list);
    scaledwhd whd = tex_char_whd_from_glyph(glyph);
    tex_attach_attribute_list_attribute(glyph, att);
    tex_attach_attribute_list_attribute(box, att);
    box_width(box) = whd.wd;
    box_height(box) = whd.ht;
    box_depth(box) = whd.dp;
    box_list(box) = glyph;
    if (tex_has_glyph_option(glyph, glyph_option_no_italic_correction)) {
        whd.ic = 0;
    }
    if (whd.ic) {
        if (ic) {
            *ic = whd.ic; /* also in open type? needs checking */
        }
        if (tex_aux_math_engine_control(fnt, math_control_apply_char_italic_kern)) {
            tex_aux_math_insert_italic_kern(glyph, whd.ic, glyph, "box");
            box_width(box) += whd.ic;
        } else {
            return box;
        }
    } else if (ic) {
        *ic = 0;
    }
    if (target && whd.wd > 0 && whd.wd < target && tex_aux_math_engine_control(fnt, math_control_extend_accents) && tex_char_has_tag_from_font(fnt, chr, extend_last_tag)) {
        scaled margin = tex_get_math_x_parameter_default(style, math_parameter_accent_extend_margin, 0);
        scaled amount = target - 2 * margin;
        if (amount > 0) { 
            glyph_x_scale(glyph) = lround((double) glyph_x_scale(glyph) * amount/whd.wd);
            glyph_x_offset(glyph) = (whd.wd - amount)/2;
        }
    }
    return box;
}

/*tex 
    There is no need to deal with an italic correction here. If there is one in an extensible we 
    have a real weird font! So in this version we don't end up with a redicoulous amount of hlists
    in a horizontal extensible with is nicer when we trace. Actualy, the only extensibles that are
    italic are integrals and these are not in traditional fonts. 

    We only got a warning with Lucida that has italic correction on the begin and end glyphs of 
    integrals and it looks real bad it we add that, so now we don't even warn any more and just 
    ignore it. 
*/

static scaled tex_aux_stack_char_into_box(halfword box, halfword fnt, int chr, quarterword subtype, int horiziontal)
{
    halfword glyph = tex_aux_new_math_glyph(fnt, chr, subtype);
    scaledwhd whd = tex_char_whd_from_glyph(glyph);
    halfword list = box_list(box);
    tex_attach_attribute_list_attribute(glyph, get_attribute_list(box));
    if (horiziontal) {
        if (list) {
            tex_couple_nodes(tex_tail_of_node_list(list), glyph);
        } else {
            box_list(box) = glyph;
        }
        if (box_height(box) < whd.ht) {
            box_height(box) = whd.ht;
        }
        if (box_depth(box) < whd.dp) {
            box_depth(box) = whd.dp;
        }
     // if (whd.ic) { 
     //     tex_print_message("italic correction found in horizontal delimiter parts, needs checking"); 
     // }
        return whd.wd;
    } else { 
        halfword boxed = tex_new_null_box_node(hlist_node, math_char_list);
        tex_attach_attribute_list_attribute(boxed, get_attribute_list(box));
        box_width(boxed) = whd.wd;
        box_height(boxed) = whd.ht;
        box_depth(boxed) = whd.dp;
        box_list(boxed) = glyph;
        tex_try_couple_nodes(boxed, list);
        box_list(box) = boxed;
     // box_height(b) = box_height(boxed);
        if (box_width(box) < whd.wd) {
            box_width(box) = whd.wd;
        }
     // if (whd.ic) { 
     //     tex_print_message("italic correction found in vertical delimiter parts, needs checking");
     // }
        return whd.ht + whd.dp;
    }
}

static void tex_aux_stack_glue_into_box(halfword box, scaled min, scaled max) {
    halfword glue = tex_new_glue_node(zero_glue, user_skip_glue); /* todo: subtype, correction_skip_glue? */
    glue_amount(glue) = min;
    glue_stretch(glue) = max - min;
    tex_add_glue_option(glue, glue_option_no_auto_break);
    tex_attach_attribute_list_copy(glue, box);
    if (node_type(box) == vlist_node) {
        tex_try_couple_nodes(glue, box_list(box));
        box_list(box) = glue;
    } else {
        halfword list = box_list(box);
        if (list) {
            tex_couple_nodes(tex_tail_of_node_list(list), glue);
        } else {
            box_list(box) = glue;
        }
    }
}

/*tex

    \TEX's most important routine for dealing with formulas is called |mlist_to_hlist|. After a
    formula has been scanned and represented as an mlist, this routine converts it to an hlist that
    can be placed into a box or incorporated into the text of a paragraph. The explicit parameter
    |cur_mlist| points to the first node or noad in the given mlist (and it might be |null|). The
    parameter |penalties| is |true| if penalty nodes for potential line breaks are to be inserted
    into the resulting hlist, the parameter |cur_style| is a style code. After |mlist_to_hlist| has
    acted, |vlink (temp_head)| points to the translated hlist.

    Since mlists can be inside mlists, the procedure is recursive. And since this is not part of
    \TEX's inner loop, the program has been written in a manner that stresses compactness over
    efficiency. (This is no longer always true in \LUAMETATEX.)

*/

static halfword tex_aux_top_extensible_from_box(halfword e)
{
    if (node_type(e) == vlist_node && node_subtype(e) == math_v_extensible_list) {
        e = box_list(e);
        while (e) { 
            if (node_type(e) == hlist_node && box_list(e) && node_type(box_list(e)) == glyph_node) { 
                return box_list(e); /* hit is first */
            } else {
                e = node_next(e);
            }
        }
    }
    return null;
}

static halfword tex_aux_bottom_extensible_from_box(halfword e)
{
    halfword g = null;
    if (node_type(e) == vlist_node && node_subtype(e) == math_v_extensible_list) {
        e = box_list(e);
        while (e) { 
            if (node_type(e) == hlist_node && box_list(e) && node_type(box_list(e)) == glyph_node) { 
                g = box_list(e); /* last so far */
            }
            e = node_next(e);
        }
    }
    return g; /* hit is last */
}

static halfword tex_aux_get_delimiter_box(halfword fnt, halfword chr, scaled target, scaled minoverlap, int horizontal, halfword att)
{
    halfword size = lmt_math_state.size;
    int callback_id = lmt_callback_defined(make_extensible_callback);
    if (callback_id > 0) {
        /*tex
            This call is not optimized as it hardly makes sense to use it ... special
            and a bit of feature creep too.
        */
        halfword boxed = null;
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddddbNd->N", fnt, chr, target, minoverlap, horizontal, att, size, &boxed);
        if (boxed) {
            switch (node_type(boxed)) {
                case hlist_node:
                case vlist_node:
                    return boxed;
                default:
                    tex_formatted_error("fonts", "invalid extensible character %i created for font %i, [h|v]list expected", chr, fnt);
                    break;
            }
        }
    }
    return tex_make_extensible(fnt, chr, target, minoverlap, horizontal, att, size);
}

halfword tex_make_extensible(halfword fnt, halfword chr, scaled target, scaled minoverlap, int horizontal, halfword att, halfword size)
{
    /*tex natural (maximum) size of the stack */
    scaled max_natural = 0;
    /*tex amount of possible shrink in the stack */
    scaled max_shrink = 0;
    scaled overlap;
    /*tex a temporary counter number of extensible pieces */
    int pieces = 0;
    /*tex new box */
    halfword box = tex_new_null_box_node(horizontal ? hlist_node : vlist_node, horizontal ? math_h_extensible_list : math_v_extensible_list);
    /*tex number of times to repeat each repeatable item in |ext| */
    int with_extenders = -1;
    int n_of_extenders = 0;
    int n_of_normal = 0;
    extinfo *extensible = tex_char_extensible_recipe_from_font(fnt, chr);
    if (minoverlap < 0) {
        minoverlap = 0;
    }
    tex_attach_attribute_list_attribute(box, att);
    for (extinfo *e = extensible; e; e = e->next) {
        if (! tex_char_exists(fnt, e->glyph)) {
            tex_handle_error(
                normal_error_type,
                "Extension part doesn't exist.",
                "Each glyph part in an extensible item should exist in the font. I will give up\n"
                "trying to find a suitable size for now. Fix your font!"
            );
            tex_aux_fake_delimiter(box);
            return box;
        } else {
            if (e->extender == math_extension_repeat) {
                n_of_extenders++;
            } else {
                n_of_normal++;
            }
            /*tex 
                No negative overlaps or advances are allowed. Watch out, we patch the glyph data at
                the \TEX\ end here. 
            */
            if (e->start_overlap < 0 || e->end_overlap < 0 || e->advance < 0) {
                tex_handle_error(
                    normal_error_type,
                    "Extensible recipe has negative fields.",
                    "All measurements in extensible items should be positive. To get around this\n"
                    "problem, I have changed the font metrics. Fix your font!"
                );
                if (e->start_overlap < 0) {
                    e->start_overlap = 0;
                }
                if (e->end_overlap < 0) {
                    e->end_overlap = 0;
                }
                if (e->advance < 0) {
                    e->advance = 0;
                }
            }
        }
    }
    if (n_of_normal == 0) {
        tex_handle_error(
            normal_error_type,
            "Extensible recipe has no fixed parts.",
            "Each extensible recipe should have at least one non-repeatable part. To get\n"
            "around this problem, I have changed the first part to be non-repeatable. Fix your\n"
            "font!"
        );
        if (extensible) { /* get rid of warning */
            extensible->extender = 0;
        }
        n_of_normal = 1;
        n_of_extenders--;
    }
    /*tex

        In the meantime the Microsoft Typography website has a good description of the process: 

        \startitemize
            \startitem
                Assemble all parts with all extenders removed and with connections overlapping by 
                the maximum amount. This gives the smallest possible result.
            \stopitem 
            \startitem
                Determine how much extra width/height can be obtained from all existing connections
                between neighboring parts by using minimal overlaps. If that is enough to achieve 
                the size goal, extend each connection equally by changing overlaps of connectors to
                finish the job.
            \stopitem 
            \startitem
                If all connections have been extended to the minimum overlap and further growth is 
                needed, add one of each extender, and repeat the process from the first step.
            \stopitem 
        \stopitemize 

        Original comment: |ext| holds a linked list of numerous items that may or may not be 
        repeatable. For the total height, we have to figure out how many items are needed to create
        a stack of at least |v|. The next |while| loop does that. It has two goals: it finds out
        the natural height |b_max| of the all the parts needed to reach at least |v|, and it sets
        |with_extenders| to the number of times each of the repeatable items in |ext| has to be 
        repeated to reach that height.

        It's an example figure it out once, write the solution, test it well and then never look 
        back code. 
    */
    while (max_natural < target && n_of_extenders > 0) {
        overlap = 0;
        max_natural = 0;
        with_extenders++;
        if (horizontal) {
            for (extinfo *e = extensible; e; e = e->next) {
                if (e->extender == 0) {
                    scaled initial = tex_aux_math_x_size_scaled(fnt, e->start_overlap, size);
                    scaled advance = tex_aux_math_x_size_scaled(fnt, e->advance, size);
                    if (minoverlap < initial) {
                        initial = minoverlap;
                    }
                    if (overlap < initial) {
                        initial = overlap;
                    }
                 // if (advance == 0) {
                 //     /*tex for tfm fonts (so no need for scaling) */
                 //     advance = tex_aux_math_x_size_scaled(fnt, tex_char_width_from_font(fnt, e->glyph), size); /* todo: combine */
                        if (advance <= 0) {
                            tex_formatted_error("fonts", "bad horizontal extensible character %i in font %i", chr, fnt);
                        }
                 // }
                    max_natural += advance - initial;
                    overlap = tex_aux_math_x_size_scaled(fnt, e->end_overlap, size);
                } else {
                    pieces = with_extenders;
                    while (pieces > 0) {
                        scaled initial = tex_aux_math_x_size_scaled(fnt, e->start_overlap, size);
                        scaled advance = tex_aux_math_x_size_scaled(fnt, e->advance, size);
                        if (minoverlap < initial) {
                            initial = minoverlap;
                        }
                        if (overlap < initial) {
                            initial = overlap;
                        }
                     // if (advance == 0) {
                     //     /*tex for tfm fonts (so no need for scaling) */
                     //     advance = tex_aux_math_x_size_scaled(fnt, tex_char_width_from_font(fnt, e->glyph), size); /* todo: combine */
                            if (advance <= 0) {
                                tex_formatted_error("fonts", "bad horizontal extensible character %i in font %i", chr, fnt);
                            }
                     // }
                        max_natural += advance - initial;
                        overlap = tex_aux_math_x_size_scaled(fnt, e->end_overlap, size);
                        pieces--;
                    }
                }
            }
        } else {
            for (extinfo *e = extensible; e; e = e->next) {
                if (e->extender == 0) {
                    scaled initial = tex_aux_math_y_size_scaled(fnt, e->start_overlap, size);
                    scaled advance = tex_aux_math_y_size_scaled(fnt, e->advance, size);
                    if (minoverlap < initial) {
                        initial = minoverlap;
                    }
                    if (overlap < initial) {
                        initial = overlap;
                    }
                 // if (advance == 0) {
                 //     advance = tex_aux_math_y_size_scaled(fnt, tex_char_total_from_font(fnt, e->glyph), size); /* todo: combine */
                        if (advance <= 0) {
                            tex_formatted_error("fonts", "bad vertical extensible character %i in font %i", chr, fnt);
                        }
                 // }
                    max_natural += advance - initial;
                    overlap = tex_aux_math_y_size_scaled(fnt, e->end_overlap, size);
                } else {
                    pieces = with_extenders;
                    while (pieces > 0) {
                        scaled initial = tex_aux_math_y_size_scaled(fnt, e->start_overlap, size);
                        scaled advance = tex_aux_math_y_size_scaled(fnt, e->advance, size);
                        if (minoverlap < initial) {
                            initial = minoverlap;
                        }
                        if (overlap < initial) {
                            initial = overlap;
                        }
                     // if (advance == 0) {
                     //     advance = tex_aux_math_y_size_scaled(fnt, tex_char_total_from_font(fnt, e->glyph), size); /* todo: combine */
                            if (advance <= 0) {
                                tex_formatted_error("fonts", "bad vertical extensible character %i in font %i", chr, fnt);
                            }
                     // }
                        max_natural += advance - initial;
                        overlap = tex_aux_math_y_size_scaled(fnt, e->end_overlap, size);
                        pieces--;
                    }
                }
            }
        }
    }
    /*tex
        Assemble box using |with_extenders| copies of each extender, with appropriate glue wherever
        an overlap occurs.
    */
    overlap = 0;
    max_natural = 0;
    max_shrink = 0;
    for (extinfo *e = extensible; e; e = e->next) {
        if (e->extender == 0) {
            scaled progress;
            scaled initial = horizontal ? tex_aux_math_x_size_scaled(fnt, e->start_overlap, size) : tex_aux_math_y_size_scaled(fnt, e->start_overlap, size);
            if (overlap < initial) {
                initial = overlap;
            }
            progress = initial;
            if (minoverlap < initial) {
                initial = minoverlap;
            }
            if (progress > 0) {
                tex_aux_stack_glue_into_box(box, -progress, -initial);
                max_shrink += (-initial) - (-progress);
                max_natural -= progress;
            }
            max_natural += tex_aux_stack_char_into_box(box, fnt, e->glyph, glyph_math_extensible_subtype, horizontal);
            overlap = horizontal ? tex_aux_math_x_size_scaled(fnt, e->end_overlap, size) : tex_aux_math_y_size_scaled(fnt, e->end_overlap, size);
            pieces--;
        } else {
            pieces = with_extenders;
            while (pieces > 0) {
                scaled progress;
                scaled initial = horizontal ? tex_aux_math_x_size_scaled(fnt, e->start_overlap, size) : tex_aux_math_y_size_scaled(fnt, e->start_overlap, size);
                if (overlap < initial) {
                    initial = overlap;
                }
                progress = initial;
                if (minoverlap < initial) {
                    initial = minoverlap;
                }
                if (progress > 0) {
                    tex_aux_stack_glue_into_box(box, -progress, -initial);
                    max_shrink += (-initial) - (-progress);
                    max_natural -= progress;
                }
                max_natural += tex_aux_stack_char_into_box(box, fnt, e->glyph, glyph_math_extensible_subtype, horizontal);
                overlap = horizontal ? tex_aux_math_x_size_scaled(fnt, e->end_overlap, size) : tex_aux_math_y_size_scaled(fnt, e->end_overlap, size);
                pieces--;
            }
        }
    }
    /*tex Set glue so as to stretch the connections if needed. */
    if (target > max_natural && max_shrink > 0) {
     // if (1) {
     //     halfword b;
     //     if (horizontal) {
     //         b = tex_hpack(box_list(box), target, packing_exactly, (singleword) math_direction_par, holding_none_option);
     //     } else {
     //         b = tex_vpack(box_list(box), target, packing_exactly, max_dimen, (singleword) math_direction_par, holding_none_option);
     //     }
     //     box_glue_order(box) = box_glue_order(b);
     //     box_glue_sign(box) = box_glue_sign(b);
     //     box_glue_set(box) = box_glue_set(b);
     //     box_list(b) = null;
     //     tex_flush_node(b);
     //     max_natural = target;
     // } else {
            scaled delta = target - max_natural;
            /*tex Don't stretch more than |s_max|. */
            if (delta > max_shrink) {
                if (tracing_math_par >= 1) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: extensible clipped, target %D, natural %D, shrink %D, clip %D]",
                        target, pt_unit, max_natural, pt_unit, max_shrink, pt_unit, delta - max_shrink, pt_unit
                    );
                    tex_end_diagnostic();
                }
                delta = max_shrink;
            }
            box_glue_order(box) = normal_glue_order;
            box_glue_sign(box) = stretching_glue_sign;
            box_glue_set(box) = (glueratio) (delta / (glueratio) max_shrink);
            max_natural += delta;
     // }
    }
    if (horizontal) {
        box_width(box) = max_natural;
        node_subtype(box) = math_h_extensible_list;
    } else {
        box_height(box) = max_natural;
        node_subtype(box) = math_v_extensible_list;
    }
    return box;
}

/*tex

    The |var_delimiter| function, which finds or constructs a sufficiently large delimiter, is the
    most interesting of the auxiliary functions that currently concern us. Given a pointer |d| to a
    delimiter field in some noad, together with a size code |s| and a vertical distance |v|, this
    function returns a pointer to a box that contains the smallest variant of |d| whose height plus
    depth is |v| or more. (And if no variant is large enough, it returns the largest available
    variant.) In particular, this routine will construct arbitrarily large delimiters from
    extensible components, if |d| leads to such characters.

    The value returned is a box whose |shift_amount| has been set so that the box is vertically
    centered with respect to the axis in the given size. If a built-up symbol is returned, the
    height of the box before shifting will be the height of its topmost component.

*/

static halfword register_extensible(halfword fnt, halfword chr, int size, halfword result, halfword att)
{
    int callback_id = lmt_callback_defined(register_extensible_callback);
    if (callback_id > 0) {
        halfword b = null;
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dddN->N", fnt, chr, size, result, &b);
        if (b) {
            switch (node_type(b)) {
                case hlist_node:
                case vlist_node:
                    tex_attach_attribute_list_attribute(b, att);
                    return b;
                default:
                    tex_formatted_error("fonts", "invalid extensible character %U registered for font %F, [h|v]list expected", chr, fnt);
                    break;
            }
        }
    }
    return result;
}

/*tex
     A first version passed the first and last glyph around but then we need to maintain a copy because
     we can register a composed delimiter which can result in a flush of these nodes. 
*/

static halfword tex_aux_make_delimiter(halfword target, halfword delimiter, int size, scaled targetsize, int flat, int style, int shift, int *stack, scaled *delta, scaled tolerance, int nooverflow, delimiterextremes *extremes, scaled move)
{
    /*tex the box that will be constructed */
    halfword result = null;
    /*tex best-so-far and tentative font codes */
    halfword fnt = null_font;
    /*tex best-so-far and tentative character codes */
    int chr = 0;
    int nxtchr = 0;
    /*tex are we trying the large variant? */
    int large_attempt = 0;
    int do_parts = 0;
    /*tex to save the current attribute list */
    halfword att = null;
    if (extremes) { 
        extremes->tfont = null_font;
        extremes->bfont = null_font; 
        extremes->tchar = 0;
        extremes->bchar = 0;
        extremes->height = 0;
        extremes->depth = 0;
    }
    if (delimiter && ! delimiter_small_family(delimiter) && ! delimiter_small_character(delimiter)
                  && ! delimiter_large_family(delimiter) && ! delimiter_large_character(delimiter)) {
        halfword result = tex_new_null_box_node(hlist_node, math_v_delimiter_list);
        tex_attach_attribute_list_copy(result, delimiter);
        if (! flat) {
            tex_aux_fake_delimiter(result);
        }
        tex_flush_node(delimiter); /* no, we can assign later on ... better a fatal error here */
        return result;
    }
    if (delimiter) {
        /*tex largest height-plus-depth so far */
        scaled besttarget = 0;
        /*tex |z| runs through font family members */
        int curfam = delimiter_small_family(delimiter);
        int curchr = 0;
        int count = 0;
        int prvfnt = null_font;
        int prvchr = 0;
        nxtchr = delimiter_small_character(delimiter);
        while (1) {
            /*tex
                The search process is complicated slightly by the facts that some of the characters
                might not be present in some of the fonts, and they might not be probed in increasing
                order of height. When we run out of sizes (variants) and end up at an extensible 
                pointer (parts) we quit the loop. 
            */
            if (curfam || nxtchr) {
                halfword curfnt = tex_fam_fnt(curfam, size);
                if (curfnt != null_font) {
                    curchr = nxtchr;
                  CONTINUE:
                    count++;
                    if (tex_char_exists(curfnt, curchr)) {
                        scaled total = flat ? tex_aux_math_x_size_scaled(curfnt, tex_char_width_from_font(curfnt, curchr), size): tex_aux_math_y_size_scaled(curfnt, tex_char_total_from_font(curfnt, curchr), size);
                        if (nooverflow && total >= targetsize) {
                            if (total > targetsize && prvfnt != null_font) {
                                fnt = prvfnt;
                                chr = prvchr;
                            } else { 
                                fnt = curfnt;
                                chr = curchr;
                            }
                            besttarget = total;
                            goto FOUND;
                        } else if (total >= besttarget) {
                            prvfnt = curfnt;
                            prvchr = curchr;
                            fnt = curfnt;
                            chr = curchr;
                            besttarget = total;
                            if (total >= (targetsize - tolerance)) {
                                goto FOUND;
                            }
                        }
                        if (tex_char_has_tag_from_font(curfnt, curchr, extensible_tag)) {
                            fnt = curfnt;
                            chr = curchr;
                            do_parts = 1;
                            goto FOUND;
                        } else if (count > 1000) {
                            tex_formatted_warning("fonts", "endless loop in extensible character %U of font %F", curchr, curfnt);
                            goto FOUND;
                        } else if (tex_char_has_tag_from_font(curfnt, curchr, list_tag)) {
                            prvfnt = curfnt;
                            prvchr = curchr;
                            curchr = tex_char_next_from_font(curfnt, curchr);
                            goto CONTINUE;
                        }
                    }
                }
            }
            if (large_attempt) {
                /*tex There were none large enough. */
                goto FOUND;
            } else {
                large_attempt = 1;
                curfam = delimiter_large_family(delimiter);
                nxtchr = delimiter_large_character(delimiter);
            }
        }
    }
  FOUND:
    if (delimiter) {
        /*tex
            The builder below sets the list if needed and we dereference later because otherwise
            the list gets flushed before it can be reused.
        */
        att = get_attribute_list(delimiter);
        wipe_attribute_list_only(delimiter);
        tex_flush_node(delimiter);
    }
    if (fnt != null_font) {
        /*tex
            When the following code is executed, |do_parts| will be true if a built-up symbol is
            supposed to be returned.
        */
        extinfo *ext = do_parts ? tex_char_extensible_recipe_from_font(fnt, chr) : NULL;
        if (ext) {
            scaled minoverlap = flat ? tex_get_math_x_parameter_default(style, math_parameter_connector_overlap_min, 0) : tex_get_math_y_parameter_default(style, math_parameter_connector_overlap_min, 0);;
            result = tex_aux_get_delimiter_box(fnt, chr, targetsize, minoverlap, flat, att);
            if (delta) {
                /*tex Not yet done: horizontal italics. */
                if (tex_aux_math_engine_control(fnt, math_control_apply_vertical_italic_kern)) {
                    *delta = tex_aux_math_x_size_scaled(fnt, tex_char_extensible_italic_from_font(fnt, nxtchr), size);
                } else {
                    *delta = tex_aux_math_x_size_scaled(fnt, tex_char_italic_from_font(fnt, nxtchr), size);
                }
            }
            if (stack) {
                *stack = 1 ;
            }
            if (! flat && extremes) { 
                 halfword first = tex_aux_top_extensible_from_box(result);
                 halfword last = tex_aux_bottom_extensible_from_box(result);
                 extremes->tfont = glyph_font(first);
                 extremes->tchar = glyph_character(first);
                 extremes->bfont = glyph_font(last);
                 extremes->bchar = glyph_character(last);
                 extremes->height = box_height(result); 
                 extremes->depth = box_depth(result);
            }
        } else {
            /*tex
                Here italic is added to width in traditional fonts which makes the delimiter get
                the real width. An \OPENTYPE\ font already has the right width. There is one case
                where |delta| (ic) gets subtracted but only for a traditional font. In that case
                the traditional width (which is fake width + italic) becomes less and the delta is
                added. See (**).
            */
            result = tex_aux_char_box(fnt, chr, att, delta, glyph_math_delimiter_subtype, flat ? targetsize : 0, style);
            if (stack) {
                *stack = 0 ;
            }
            if (! flat && extremes) { 
                 extremes->tfont = fnt;
                 extremes->tchar = chr;
                 extremes->bfont = fnt;
                 extremes->bchar = chr;
                 extremes->height = box_height(result); 
                 extremes->depth = box_depth(result);
            }
        }
    } else {
        /*tex This can be an empty one as is often the case with fractions! */
        result = tex_new_null_box_node(hlist_node, flat ? math_h_delimiter_list : math_v_delimiter_list);
        tex_attach_attribute_list_attribute(result, att);
        /*tex Use this width if no delimiter was found. */
        if (! flat) {
            tex_aux_fake_delimiter(result);
        }
        if (delta) {
            *delta = 0;
        }
        if (stack) {
            *stack = 0 ;
        }
    }
    if (do_parts) {
        if (has_noad_option_phantom(target) || has_noad_option_void(target)) {
            result = tex_aux_make_list_phantom(result, has_noad_option_void(target), att);
        } else {
            result = register_extensible(fnt, chr, size, result, att);
        }
    }
    if (! flat) {
        /*tex 
            We have a vertical variant. Case 1 deals with the fact that fonts can lie about their
            dimensions which happens in tfm files where there are a limited number of heights and 
            depths. However, that doesn't work out well when we want to anchor script later on in 
            a more sophisticated way. Most \OPENTYPE\ fonts have proper heights and depth but there 
            are some that don't. Problems can show up when we use kerns (as \CONTEXT\ does via 
            goodie files) and the relevant class option has been enabled. In order to deal with the 
            problematic fonts we can disable this via a font option. The natural height and depth 
            are communicated via extremes and kerns. 
            
            For fonts that have their shapes positioned properly around their axis case 1 doesn't 
            interfere but could as well be skipped. These shapes can also be used directly in 
            the input if needed (basically case 1 then becomes case 4).  
        */
        switch (shift) { 
            case 0:
                box_shift_amount(result) = tex_half_scaled(box_height(result) - box_depth(result));
                break;
            case 1:
                box_shift_amount(result) = tex_half_scaled(box_height(result) - box_depth(result));
                box_shift_amount(result) -= tex_aux_math_axis(size);
                break;
            case 2: 
                box_shift_amount(result) = move;
                break;
        }
        if (do_parts && extremes && extremes->height) {
            extremes->height -= box_shift_amount(result);
            extremes->depth += box_shift_amount(result);
        }
    }
    /* This needs checking in case the ref was changed. */
    delete_attribute_reference(att);
    if ((node_type(result) == hlist_node || node_type(result) == vlist_node) && node_subtype(result) == unknown_list) {
        node_subtype(result) = flat ? math_h_delimiter_list : math_v_delimiter_list;
    }
    return result;
}

/*tex

    The next subroutine is much simpler; it is used for numerators and denominators of fractions as
    well as for displayed operators and their limits above and below. It takes a given box~|b| and
    changes it so that the new box is centered in a box of width~|w|. The centering is done by
    putting |\hss| glue at the left and right of the list inside |b|, then packaging the new box;
    thus, the actual box might not really be centered, if it already contains infinite glue.

    The given box might contain a single character whose italic correction has been added to the
    width of the box; in this case a compensating kern is inserted. Actually, we now check for
    the last glyph.

*/

static halfword tex_aux_rebox(halfword box, scaled width, halfword size)
{
    (void) size;
    if (box_width(box) != width && box_list(box)) {
        /*tex temporary registers for list manipulation */
        halfword head = box_list(box);
        quarterword subtype = node_subtype(box);
        halfword att = get_attribute_list(box);
        /*tex When the next two are not seen we can wipe att so we reserve by bump! */
        add_attribute_reference(att);
        if (node_type(box) == vlist_node) {
            box = tex_hpack(box, 0, packing_additional, direction_unknown, holding_none_option);
            node_subtype(box) = subtype;
            tex_attach_attribute_list_attribute(box, att);
            head = box_list(box);
        } else if (head && node_type(head) == glyph_node && ! node_next(head)) {
            /*tex
                This hack is for traditional fonts so with a proper opentype font we don't end up
                here (because then the width is unchanged). However controls can cheat so there is
                no explicit check for an opentype situation here.
            */
            if (tex_aux_math_engine_control(glyph_font(head), math_control_rebox_char_italic_kern)) {
                scaled boxwidth = box_width(box);
                scaled chrwidth = tex_char_width_from_glyph(head);
                if (boxwidth != chrwidth) {
                    /*tex
                        This is typical old font stuff. Maybe first check if we can just
                        remove a trailing kern. Also, why not just adapt the box width.
                    */
                    halfword kern = tex_new_kern_node(boxwidth - chrwidth, italic_kern_subtype); /* horizontal_math_kern */
                    tex_attach_attribute_list_attribute(kern, att);
                    tex_couple_nodes(head, kern);
                }
            }
        }
        box_list(box) = null;
        tex_flush_node(box);
        { 
            halfword left = tex_new_glue_node(filll_glue, user_skip_glue); /* todo: subtype, correction_skip_glue? */
            halfword right = tex_new_glue_node(filll_glue, user_skip_glue); /* todo: subtype, correction_skip_glue? */
            tex_add_glue_option(left, glue_option_no_auto_break);
            tex_add_glue_option(right, glue_option_no_auto_break);
            tex_attach_attribute_list_attribute(left, att);
            tex_attach_attribute_list_attribute(right, att);
            tex_couple_nodes(left, head);
            tex_couple_nodes(tex_tail_of_node_list(head), right);
            box = tex_hpack(left, width, packing_exactly, direction_unknown, holding_none_option);
            tex_attach_attribute_list_attribute(box, att);
            node_subtype(box) = subtype;
        }
        /*tex As we bumped we now need to unbump the ref counter! */
        delete_attribute_reference(att);
    } else {
        box_width(box) = width;
    }
    return box;
}

/*tex

    Here is a subroutine that creates a new glue specification from another one that is expressed
    in |mu|, given the value of the math unit.

*/

inline static scaled tex_aux_mu_mult(scaled a, scaled n, scaled f)
{
    return tex_multiply_and_add(n, a, tex_xn_over_d(a, f, unity), max_dimen);
}

inline static void tex_aux_calculate_glue(scaled m, scaled *f, scaled *n)
{
    /*tex fraction part of |m| */
    *f = 0;
    /*tex integer part of |m| */
    *n = tex_x_over_n_r(m, unity, f);
    /*tex the new glue specification */
    if (f < 0) {
        --n;
        f += unity;
    }
}

static halfword tex_aux_math_muglue(halfword g, quarterword subtype, scaled m, halfword detail, int style)
{
    scaled f, n;
    halfword glue = tex_new_node(glue_node, subtype);
    tex_aux_calculate_glue(m, &f, &n);
    /* convert |mu| to |pt| */
    glue_amount(glue) = tex_aux_mu_mult(tex_aux_math_x_scaled(glue_amount(g), style), n, f);
    if (math_glue_stretch_enabled) {
        scaled stretch = tex_aux_math_x_scaled(glue_stretch(g), style);
        glue_stretch_order(glue) = glue_stretch_order(g);
        glue_stretch(glue) = (glue_stretch_order(glue) == normal_glue_order) ? tex_aux_mu_mult(stretch, n, f) : stretch;
    }
    if (math_glue_shrink_enabled) {
        scaled shrink = tex_aux_math_x_scaled(glue_shrink(g), style);
        glue_shrink_order(glue) = glue_shrink_order(g);
        glue_shrink(glue) = (glue_shrink_order(glue) == normal_glue_order) ? tex_aux_mu_mult(shrink, n, f) : shrink;
    }
    glue_font(glue) = detail;
    tex_add_glue_option(glue, glue_option_no_auto_break);
    return glue;
}

static halfword tex_aux_math_glue(halfword g, quarterword subtype, halfword detail)
{
    halfword glue = tex_new_glue_node(g, subtype);
    if (! math_glue_stretch_enabled) {
        glue_stretch_order(glue) = 0;
        glue_stretch(glue) = 0;
    }
    if (! math_glue_shrink_enabled) {
        glue_shrink_order(glue) = 0;
        glue_shrink(glue) = 0;
    }
    glue_font(glue) = detail;
    tex_add_glue_option(glue, glue_option_no_auto_break);
    return glue;
}

static halfword tex_aux_math_dimen(halfword g, quarterword subtype, halfword detail)
{
    halfword glue = tex_new_glue_node(null, subtype);
    glue_amount(glue) = g;
    glue_font(glue) = detail;
    tex_add_glue_option(glue, glue_option_no_auto_break);
    return glue;
}

static void tex_aux_math_glue_to_glue(halfword p, scaled m, int style)
{
    scaled f, n;
    tex_aux_calculate_glue(m, &f, &n);
    /*tex convert |mu| to |pt| */
    glue_amount(p) = tex_aux_mu_mult(tex_aux_math_x_scaled(glue_amount(p), style), n, f);
    if (! math_glue_stretch_enabled) {
        glue_stretch_order(p) = 0;
        glue_stretch(p) = 0;
    } else if (glue_stretch_order(p) == normal_glue_order) {
        glue_stretch(p) = tex_aux_mu_mult(tex_aux_math_x_scaled(glue_stretch(p), style), n, f);
    }
    if (! math_glue_shrink_enabled) {
        glue_shrink_order(p) = 0;
        glue_shrink(p) = 0;
    } else if (glue_shrink_order(p) == normal_glue_order) {
        glue_shrink(p) = tex_aux_mu_mult(tex_aux_math_x_scaled(glue_shrink(p), style), n, f);
    }
    /*tex Okay, we could have had a special subtype but we're stuck with this now. */
    node_subtype(p) = inter_math_skip_glue;
    tex_add_glue_option(p, glue_option_no_auto_break);
}

/*tex

    The |math_kern| subroutine removes |mu_glue| from a kern node, given the value of the math
    unit.

*/

static void tex_aux_make_kern(halfword current, scaled mu, int style)
{
    if (node_subtype(current) == explicit_math_kern_subtype) {
        scaled f, n;
        tex_aux_calculate_glue(mu, &f, &n);
        kern_amount(current) = tex_aux_mu_mult(tex_aux_math_x_scaled(glue_amount(current), style), n, f);
        node_subtype(current) = explicit_kern_subtype;
    }
}

/*tex

    Conditional math glue (|\nonscript|) results in a |glue_node| pointing to |zero_glue|, with
    |subtype(q)=cond_math_glue|; in such a case the node following will be eliminated if it is a
    glue or kern node and if the current size is different from |text_size|.

    Unconditional math glue (|\muskip|) is converted to normal glue by multiplying the dimensions
    by |current_mu|.

*/

static void tex_aux_make_glue(halfword current, scaled mu, int style)
{
    switch (node_subtype(current)) {
        case mu_glue:
            tex_aux_math_glue_to_glue(current, mu, style);
            break;
        case conditional_math_glue:
            if (lmt_math_state.size != text_size) {
                halfword p = node_next(current);
                if (p) {
                    switch (node_type(p)) {
                        case glue_node:
                        case kern_node:
                            if (node_next(p)) {
                                tex_couple_nodes(current, node_next(p));
                                node_next(p) = null;
                            } else {
                                node_next(current) = null;
                            }
                            tex_flush_node_list(p);
                            break;
                    }
                }
            }
            break;
        case rulebased_math_glue:
            break;
    }
}

/*tex

    The |mlist_to_hlist| operation is actually called a lot when we have a math intense document,
    because it is also called nested. Here we have the main runner, called in the main loop;
    watch the callback.

*/

inline static int tex_aux_is_math_penalty(halfword n)
{
    return node_type(n) == penalty_node && (node_subtype(n) == math_pre_penalty_subtype || node_subtype(n) == math_post_penalty_subtype);
}

void tex_run_mlist_to_hlist(halfword mlist, halfword penalties, halfword style, int beginclass, int endclass)
{
    if (mlist) {
        int saved_level = lmt_math_state.level;
        int callback_id = lmt_callback_defined(mlist_to_hlist_callback);
        lmt_math_state.level = 0;
        if (! valid_math_class_code(beginclass)) {
            beginclass = unset_noad_class;
        }
        if (! valid_math_class_code(endclass)) {
            endclass = unset_noad_class;
        }
        math_begin_class_par = unset_noad_class;
        math_end_class_par = unset_noad_class;
        /* not on the stack ... yet */
        if (tracing_math_par >= 1) {
            tex_begin_diagnostic();
            switch (style) {
                case display_style:
                    tex_print_str("> \\displaymath=");
                    break;
                case text_style:
                    tex_print_str("> \\inlinemath=");
                    break;
                default:
                    tex_print_str("> \\math=");
                    break;
            }
            tex_show_box(mlist);
            tex_end_diagnostic();
        }
        tex_finalize_math_parameters();
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                node_prev(mlist) = null ;
                lmt_node_list_to_lua(L, mlist);
                lmt_push_math_style_name(L, style);
                lua_pushboolean(L, penalties);
                lua_pushinteger(L, beginclass);
                lua_pushinteger(L, endclass);
                lua_pushinteger(L, lmt_math_state.level);
                i = lmt_callback_call(L, 6, 1, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                    node_next(temp_head) = null;
                } else {
                    halfword a = lmt_node_list_from_lua(L, -1);
                    /* node_prev(node_next(a)) = null; */
                    node_next(temp_head) = a;
                    lmt_callback_wrapup(L, top);
                }
            } else {
                 node_next(temp_head) = null;
            }
        } else if (callback_id == 0) {
             node_next(temp_head) = tex_mlist_to_hlist(mlist, penalties, style, beginclass, endclass, NULL);
        } else {
             node_next(temp_head) = null;
        }
        if (penalties) { // && tex_in_main_math_style(style)  
            /*tex This makes no sense in display math not in script styles. */
            switch (style) {
                case text_style:        
                case cramped_text_style:        
                    if (math_forward_penalties_par) {
                        halfword n = tex_get_specification_count(math_forward_penalties_par);
                        if (n > 0) {
                            halfword h = node_next(temp_head);
                            halfword i = 1;
                            while (h && i <= n) {
                                if (tex_aux_is_math_penalty(h)) {
                                    penalty_amount(h) += tex_get_specification_penalty(math_forward_penalties_par, i);
                                    ++i;
                                }
                                h = node_next(h);
                            }
                        }
                    }
                    if (math_backward_penalties_par) {
                        halfword n = tex_get_specification_count(math_backward_penalties_par);
                        if (n > 0) {
                            halfword t = tex_tail_of_node_list(node_next(temp_head));
                            halfword i = 1;
                            while (t && i <= n) {
                                if (tex_aux_is_math_penalty(t)) {
                                    penalty_amount(t) += tex_get_specification_penalty(math_backward_penalties_par, i);
                                    ++i;
                                }
                                t = node_prev(t);
                            }
                        }
                    }
                    break;
            }
            if (node_next(temp_head) && math_threshold_par) {
                scaledwhd siz = tex_natural_hsizes(node_next(temp_head), null, 0.0, 0, 0);
                if  (siz.wd < glue_amount(math_threshold_par)) {
                    halfword box = tex_new_node(hlist_node, unknown_list);
                    tex_attach_attribute_list_copy(box, node_next(temp_head));
                    box_width(box) = siz.wd;
                    box_height(box) = siz.ht;
                    box_depth(box) = siz.dp;
                    box_list(box) = node_next(temp_head);
                    node_next(temp_head) = box;
                    if (glue_stretch(math_threshold_par) || glue_shrink(math_threshold_par)) {
                        halfword glue = tex_new_glue_node(math_threshold_par, u_leaders);
                        tex_add_glue_option(glue, glue_option_no_auto_break);
                        tex_attach_attribute_list_copy(glue, box);
                        glue_amount(glue) = siz.wd;
                        glue_leader_ptr(glue) = box;
                        node_next(temp_head) = glue;
                    } else {
                        node_next(temp_head) = box;
                    }
                    if (tracing_math_par >= 2) {
                        tex_begin_diagnostic();
                        tex_print_format("[math: boxing inline, threshold %D, width %D, height %D, depth %D]",
                            glue_amount(math_threshold_par), pt_unit, // todo: stretch and shrink
                            siz.wd, pt_unit, siz.ht, pt_unit, siz.dp, pt_unit
                        );
                        tex_end_diagnostic();
                    }
                }
            }
            /* 
                At the outer level we check for discretionaries. Maybe only when we are in text or display? 
            */
            {
                halfword current = temp_head;
                while (current) { 
                    /*tex Maybe |math_discretionary_code| but I need to check the impact on \CONTEXT\ first. */
                    if (node_type(current) == glyph_node && tex_has_glyph_option(current, glyph_option_math_discretionary)) {
                        if (tracing_math_par >= 2) {
                            tex_begin_diagnostic();
                            tex_print_format("[math: promoting glyph with character %U to discretionary]", glyph_character(current));
                            tex_end_diagnostic();
                        }
                        current = tex_glyph_to_discretionary(current, mathematics_discretionary_code, tex_has_glyph_option(current, glyph_option_math_italics_too));
                    }
                    current = node_next(current);
                }
            }
        }
        lmt_math_state.level = saved_level;
    } else {
        node_next(temp_head) = null;
    }
}

/*tex

    The recursion in |mlist_to_hlist| is due primarily to a subroutine called |clean_box| that puts
    a given noad field into a box using a given math style; |mlist_to_hlist| can call |clean_box|,
    which can call |mlist_to_hlist|.

    The box returned by |clean_box| is clean in the sense that its |shift_amount| is zero.

*/

inline static void tex_aux_remove_italic_after_first_glyph(halfword box)
{
    halfword list = box_list(box);
    if (list && node_type(list) == glyph_node) {
        halfword next = node_next(list);
        /*todo:  check for italic property */
        if (next && ! node_next(next) && node_type(next) == kern_node && node_subtype(next) == italic_kern_subtype) {
            /*tex Unneeded italic correction. */
            box_width(box) -= kern_amount(next);
            tex_flush_node(next);
            node_next(list) = null;
        }
    }
}

static halfword tex_aux_clean_box(halfword n, int main_style, int style, quarterword subtype, int keepitalic, kernset *kerns)
{
    /*tex beginning of a list to be boxed */
    halfword list;
    /*tex box to be returned */
    halfword result;
    /*tex beginning of mlist to be translated */
    halfword mlist = null;
    switch (node_type(n)) {
        case math_char_node:
            mlist = tex_new_node(simple_noad, ordinary_noad_subtype);
            noad_nucleus(mlist) = tex_aux_math_clone(n);
            tex_attach_attribute_list_copy(mlist, n);
            break;
        case sub_box_node:
            list = kernel_math_list(n);
            goto FOUND;
        case sub_mlist_node:
            mlist = kernel_math_list(n);
            break;
        default:
            list = tex_new_null_box_node(hlist_node, math_list_list);
            tex_attach_attribute_list_copy(list, n);
            goto FOUND;
    }
    /*tex This might add some italic correction. */
    list = tex_mlist_to_hlist(mlist, 0, main_style, unset_noad_class, unset_noad_class, kerns);
    /*tex recursive call */
    tex_aux_set_current_math_size(style); /* persists after call */
  FOUND:
    if (! list || node_type(list) == glyph_node) {
        result = tex_hpack(list, 0, packing_additional, direction_unknown, holding_none_option);
        tex_attach_attribute_list_copy(result, list);
    } else if (! node_next(list) && (node_type(list) == hlist_node || node_type(list) == vlist_node) && (box_shift_amount(list) == 0)) {
        /*tex It's already clean. */
        result = list;
    } else {
        result = tex_hpack(list, 0, packing_additional, direction_unknown, holding_none_option);
        tex_attach_attribute_list_copy(result, list);
    }
    node_subtype(result) = subtype;
    if (! keepitalic) {
        tex_aux_remove_italic_after_first_glyph(result);
    }
    return result;
}

/*tex

    It is convenient to have a procedure that converts a |math_char| field to an unpacked form. The
    |fetch| routine sets |cur_f| and |cur_c| to the font code and character code of a given noad
    field. It also takes care of issuing error messages for nonexistent characters; in such cases,
    |char_exists (cur_f, cur_c)| will be |false| after |fetch| has acted, and the field will also
    have been reset to |null|. The outputs of |fetch| are placed in global variables so that we can
    access them any time we want. We add a bit more detail about the location of the issue than
    standard \TEX\ does.

    The |cur_f| and |cur_c| variables are now locals and we keep the (opentype) state otherwise.

*/

static int tex_aux_fetch(halfword n, const char *where, halfword *f, halfword *c) /* todo: also pass size */
{
    if (node_type(n) == glyph_node) {
        *f = glyph_font(n);
        *c = glyph_character(n);
        if (tex_char_exists(*f, *c)) {
            return 1;
        } else {
            tex_char_warning(*f, *c);
            return 0;
        }
    } else {
        *f = tex_fam_fnt(kernel_math_family(n), lmt_math_state.size);
        *c = kernel_math_character(n);
        if (math_kernel_node_has_option(n, math_kernel_ignored_character)) {
            return 1;
        } else if (*f == null_font) {
            tex_handle_error(
                normal_error_type,
                "\\%s%i is undefined in %s, font id %i, character %i)",
                tex_aux_math_size_string(lmt_math_state.size), kernel_math_family(n), where, *f, *c,
                "Somewhere in the math formula just ended, you used the stated character from an\n"
                "undefined font family. For example, plain TeX doesn't allow \\it or \\sl in\n"
                "subscripts. Proceed, and I'll try to forget that I needed that character."
            );
            return 0;
        } else if (tex_math_char_exists(*f, *c, lmt_math_state.size)) {
            return 1;
        } else {
            tex_char_warning(*f, *c);
            return 0;
        }
    }
}

/*tex

    We need to do a lot of different things, so |mlist_to_hlist| makes two passes over the given
    mlist.

    The first pass does most of the processing: It removes |mu| spacing from glue, it recursively
    evaluates all subsidiary mlists so that only the top-level mlist remains to be handled, it puts
    fractions and square roots and such things into boxes, it attaches subscripts and superscripts,
    and it computes the overall height and depth of the top-level mlist so that the size of
    delimiters for a |fence_noad| will be known. The hlist resulting from each noad is recorded in
    that noad's |new_hlist| field, an integer field that replaces the |nucleus| or |thickness|.

    The second pass eliminates all noads and inserts the correct glue and penalties between nodes.

*/

static void tex_aux_assign_new_hlist(halfword target, halfword hlist)
{
    switch (node_type(target)) {
        case fraction_noad:
            kernel_math_list(fraction_numerator(target)) = null;
            kernel_math_list(fraction_denominator(target)) = null;
            tex_flush_node(fraction_numerator(target));
            tex_flush_node(fraction_denominator(target));
            fraction_numerator(target) = null;
            fraction_denominator(target) = null;
            break;
        case radical_noad:
        case simple_noad:
        case accent_noad:
            if (noad_nucleus(target)) {
                kernel_math_list(noad_nucleus(target)) = null;
                tex_flush_node(noad_nucleus(target));
                noad_nucleus(target) = null;
            }
            break;
    }
    noad_new_hlist(target) = hlist;
}

/*tex

    Most of the actual construction work of |mlist_to_hlist| is done by procedures with names like
    |make_fraction|, |make_radical|, etc. To illustrate the general setup of such procedures, let's
    begin with a couple of simple ones.

*/

static void tex_aux_make_over(halfword target, halfword style, halfword size, halfword fam)
{
    /*tex

        No rule adaption yet, maybe it will never be implemented because overbars should be proper
        extensibles. The order is: kern, rule, gap, content.

    */
    halfword result;
    scaled thickness = tex_get_math_y_parameter_checked(style, math_parameter_overbar_rule);
    scaled vgap = tex_get_math_y_parameter_checked(style, math_parameter_overbar_vgap);
    scaled kern = tex_get_math_y_parameter_checked(style, math_parameter_overbar_kern);
    {
        halfword t = tex_aux_check_rule_thickness(target, size, &fam, math_control_over_rule, OverbarRuleThickness);
        if (t != undefined_math_parameter) {
            thickness = t;
        }
    }
    result = tex_aux_overbar(
        tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_over_line_variant), style, math_nucleus_list, 0, NULL),
        vgap, thickness, kern,
        get_attribute_list(noad_nucleus(target)), math_over_rule_subtype, size, fam
    );
    node_subtype(result) = math_over_list;
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
}

static void tex_aux_make_under(halfword target, halfword style, halfword size, halfword fam)
{
    /*tex

        No rule adaption yet, maybe never as underbars should be proper extensibles. Here |x| is
        the head, and |p| the tail but we keep the original names. The order is: content, gap,
        rule, kern.

    */
    halfword result;
    scaled thickness = tex_get_math_y_parameter_checked(style, math_parameter_underbar_rule);
    scaled vgap = tex_get_math_y_parameter_checked(style, math_parameter_underbar_vgap);
    scaled kern = tex_get_math_y_parameter_checked(style, math_parameter_underbar_kern);
    {
        halfword t = tex_aux_check_rule_thickness(target, size, &fam, math_control_under_rule, UnderbarRuleThickness);
        if (t != undefined_math_parameter) {
            thickness = t;
        }
    }
    result = tex_aux_underbar(
        tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_under_line_variant), style, math_nucleus_list, 0, NULL),
        vgap, thickness, kern,
        get_attribute_list(noad_nucleus(target)), math_under_rule_subtype, size, fam
    );
    node_subtype(result) = math_over_list;
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
}

/*tex

    In \LUAMETATEX\ we also permit |\vcenter| in text mode but there we use another function than
    the one below.

 */

static void tex_aux_make_vcenter(halfword target, halfword style, halfword size)
{
    halfword box = kernel_math_list(noad_nucleus(target));
    if (node_type(box) != vlist_node) {
        box = tex_aux_clean_box(noad_nucleus(target), style, style, math_list_list, 0, NULL); // todo: math_vcenter_list
        kernel_math_list(noad_nucleus(target)) = box;
        node_type(noad_nucleus(target)) = sub_box_node;
    }
    {
        scaled total = box_total(box);
        scaled axis = has_box_axis(box, no_math_axis) ? 0 : tex_aux_math_axis(size);
        box_height(box) = axis + tex_half_scaled(total);
        box_depth(box) = total - box_height(box);
    }
}

/*tex

    According to the rules in the |DVI| file specifications, we ensure alignment between a square
    root sign and the rule above its nucleus by assuming that the baseline of the square-root
    symbol is the same as the bottom of the rule. The height of the square-root symbol will be the
    thickness of the rule, and the depth of the square-root symbol should exceed or equal the
    height-plus-depth of the nucleus plus a certain minimum clearance~|psi|. The symbol will be
    placed so that the actual clearance is |psi| plus half the excess.

*/

static void tex_aux_make_hextension(halfword target, int style, int size)
{
    int stack = 0;
    scaled radicalwidth = tex_aux_math_given_x_scaled(noad_width(target));
    halfword extensible = radical_left_delimiter(target);
    halfword delimiter = tex_aux_make_delimiter(target, extensible, size, radicalwidth, 1, style, 1, &stack, NULL, 0, has_noad_option_nooverflow(target), NULL, 0);
    halfword delimiterwidth = box_width(delimiter);
    if (! stack && radicalwidth && (radicalwidth != delimiterwidth)) {
        if (has_noad_option_middle(target)) {
            scaled delta = tex_half_scaled(radicalwidth - delimiterwidth);
            if (delta) {
                halfword kern = tex_new_kern_node(delta, horizontal_math_kern_subtype);
                tex_attach_attribute_list_copy(kern, target);
                tex_couple_nodes(kern, delimiter);
                delimiter = kern;
            }
            delimiterwidth = radicalwidth;
        } else if (has_noad_option_exact(target)) {
            delimiterwidth = radicalwidth;
        }
    }
    delimiter = tex_hpack(delimiter, 0, packing_additional, direction_unknown, holding_none_option);
    box_width(delimiter) = delimiterwidth;
    tex_attach_attribute_list_copy(delimiter, target);
    kernel_math_list(noad_nucleus(target)) = delimiter;
    radical_left_delimiter(target) = null;
    radical_right_delimiter(target) = null;
}

static void tex_aux_preroll_root_radical(halfword target, int style, int size)
{
    (void) size;
    noad_new_hlist(target) = tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_radical_variant), style, math_nucleus_list, 0, NULL);
}

static halfword tex_aux_link_radical(halfword nucleus, halfword delimiter, halfword companion, halfword rightdelimiter)
{
    if (companion) {
        tex_couple_nodes(delimiter, nucleus);
        tex_couple_nodes(nucleus, companion);
        return delimiter;
    } else if (rightdelimiter) {  
        tex_couple_nodes(nucleus, delimiter);
        return nucleus; 
    } else {
        tex_couple_nodes(delimiter, nucleus);
        return delimiter;
    }
}

static void tex_aux_assign_radical(halfword target, halfword radical)
{
    halfword result = tex_hpack(radical, 0, packing_additional, direction_unknown, holding_none_option);
    node_subtype(result) = math_radical_list;
    tex_attach_attribute_list_copy(result, target);
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
    radical_left_delimiter(target) = null;
    radical_right_delimiter(target) = null;
}

static void tex_aux_set_radical_kerns(delimiterextremes *extremes, kernset *kerns)
{
    if (kerns && extremes->tfont) { 
        if (tex_math_has_class_option(radical_noad_subtype, carry_over_left_top_kern_class_option)) {  
            kerns->topleft = tex_char_top_left_kern_from_font(extremes->tfont, extremes->tchar);
        }
        if (tex_math_has_class_option(radical_noad_subtype, carry_over_left_bottom_kern_class_option)) {  
            kerns->bottomleft = tex_char_bottom_left_kern_from_font(extremes->bfont, extremes->bchar);
        }
        if (tex_math_has_class_option(radical_noad_subtype, carry_over_right_top_kern_class_option)) {  
            kerns->topright = tex_char_top_right_kern_from_font(extremes->tfont, extremes->tchar);
        }
        if (tex_math_has_class_option(radical_noad_subtype, carry_over_right_bottom_kern_class_option)) {  
            kerns->bottomright = tex_char_bottom_right_kern_from_font(extremes->bfont, extremes->bchar);
        }
        if (tex_math_has_class_option(radical_noad_subtype, prefer_delimiter_dimensions_class_option)) {  
            kerns->height = extremes->height;
            kerns->depth = extremes->depth;
            kerns->dimensions = 1;
            kerns->font = extremes->tfont;
        }
    }
}

static void tex_aux_make_root_radical(halfword target, int style, int size, kernset *kerns)
{
    halfword nucleus = noad_new_hlist(target);
    scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_radical_vgap);
    scaled theta = tex_get_math_y_parameter(style, math_parameter_radical_rule);
    scaled kern = tex_get_math_y_parameter_checked(style, math_parameter_radical_kern);
    scaled fam = delimiter_small_family(radical_left_delimiter(target));
    halfword leftdelimiter = radical_left_delimiter(target);
    halfword rightdelimiter = radical_right_delimiter(target);
    halfword delimiter = leftdelimiter ? leftdelimiter : rightdelimiter;
    halfword companion = leftdelimiter ? rightdelimiter : null;
    halfword radical = null;
    delimiterextremes extremes = { .tfont = null_font, .tchar = 0, .bfont = null_font, .bchar = 0, .height = 0, .depth = 0 };
    scaled innerx = INT_MIN;
    scaled innery = INT_MIN;
    noad_new_hlist(target) = null;
    /*tex
        We can take the rule width from the fam/style of the delimiter or use the most recent math
        parameters value.
    */
    {
        halfword t = tex_aux_check_rule_thickness(target, size, &fam, math_control_radical_rule, RadicalRuleThickness);
        if (t != undefined_math_parameter) {
            theta = t;
        }
    }
    { 
        halfword weird = theta == undefined_math_parameter;
        if (weird) { 
            /*tex What do we have here. Why not issue an error */
            theta = tex_get_math_y_parameter_checked(style, math_parameter_fraction_rule); /* a bit weird this one */
        }
        delimiter = tex_aux_make_delimiter(target, delimiter, size, box_total(nucleus) + clearance + theta, 0, style, 1, NULL, NULL, 0, has_noad_option_nooverflow(target), &extremes, 0);
        if (radical_degree(target)) { 
            if (tex_char_has_tag_from_font(extremes.bfont, extremes.bchar, inner_left_tag)) { 
                innerx = tex_char_inner_x_offset_from_font(extremes.bfont, extremes.bchar);
                innery = tex_char_inner_y_offset_from_font(extremes.bfont, extremes.bchar);
            } else if (tex_char_has_tag_from_font(extremes.tfont, extremes.tchar, inner_left_tag)) { 
                innerx = tex_char_inner_x_offset_from_font(extremes.tfont, extremes.tchar);
                innery = tex_char_inner_y_offset_from_font(extremes.tfont, extremes.tchar);
            }
        }
        if (companion) {
            /*tex For now we assume symmetry and same height and depth! */
            companion = tex_aux_make_delimiter(target, companion, size, box_total(nucleus) + clearance + theta, 0, style, 1, NULL, NULL, 0, has_noad_option_nooverflow(target), &extremes, 0);
        }
        if (weird) {
            /*tex
                If |y| is a composite then set |theta| to the height of its top character, else set it
                to the height of |y|. Really? 
            */
            halfword list = box_list(delimiter);
            if (list && (node_type(list) == hlist_node)) {
                /*tex possible composite */
                halfword glyph = box_list(list);
                if (glyph && node_type(glyph) == glyph_node) {
                    /*tex top character */
                    theta = tex_char_height_from_glyph(glyph);
                } else {
                    theta = box_height(delimiter);
                }
            } else {
                theta = box_height(delimiter);
            }
        }
    }
    /* */
    tex_aux_set_radical_kerns(&extremes, kerns);
    /*
        Radicals in traditional fonts have their shape below the baseline which makes them unuseable
        as stand alone characters but here we compensate for that fact. Opentype fonts derived from
        traditional \TEX\ fonts can also be like that and it goed unnoticed until one accesses the
        shape as character directly. Normally that gets corrected in the font when this has become
        clear.
    */
    {
        halfword delta = (box_total(delimiter) - theta) - (box_total(nucleus) + clearance);
        if (delta > 0) {
            /*tex increase the actual clearance */
            clearance += tex_half_scaled(delta);
        }
        box_shift_amount(delimiter) = (box_height(delimiter) - theta) - (box_height(nucleus) + clearance);
        if (companion) { 
            box_shift_amount(companion) = (box_height(companion) - theta) - (box_height(nucleus) + clearance);
        }
    }
    if (node_type(delimiter) == vlist_node && node_subtype(delimiter) == math_v_delimiter_list) {
        halfword before = tex_get_math_x_parameter_default(style, math_parameter_radical_extensible_before, 0); 
        tex_aux_prepend_hkern_to_box_list(nucleus, before, horizontal_math_kern_subtype, "bad delimiter");
    }
    if (node_type(companion) == vlist_node && node_subtype(companion) == math_v_delimiter_list) {
        halfword after = tex_get_math_x_parameter_default(style, math_parameter_radical_extensible_after, 0); 
        tex_aux_append_hkern_to_box_list(nucleus, after, horizontal_math_kern_subtype, "bad delimiter");
    }
    {
        halfword total = box_total(delimiter);
        halfword list = tex_aux_overbar(nucleus, clearance, theta, kern, get_attribute_list(delimiter), math_radical_rule_subtype, size, fam);
        radical = tex_aux_link_radical(list, delimiter, companion, rightdelimiter);
        if (radical_degree(target)) {
            halfword degree = tex_aux_clean_box(radical_degree(target), script_script_style, style, math_degree_list, 0, NULL);
            scaled width = box_width(degree);
            tex_attach_attribute_list_copy(degree, radical_degree(target));
            if (width) {
                scaled before = tex_get_math_x_parameter_checked(style, math_parameter_radical_degree_before);
                scaled after = tex_get_math_x_parameter_checked(style, math_parameter_radical_degree_after);
                scaled raise = tex_get_math_parameter_checked(style, math_parameter_radical_degree_raise);
                if (innerx != INT_MIN) { 
                    tex_aux_append_hkern_to_box_list(degree, innerx, horizontal_math_kern_subtype, "bad degree");
                    width += innerx;
                }
                if (-after > width) {
                    before += -after - width;
                }
                if (after) {
                    halfword kern = tex_new_kern_node(after, horizontal_math_kern_subtype);
                    tex_attach_attribute_list_copy(kern, radical_degree(target));
                    tex_couple_nodes(kern, radical);
                    nucleus = kern;
                } else {
                    nucleus = radical;
                }
                if (innery != INT_MIN) { 
                    box_shift_amount(degree) = - innery + box_depth(radical) + box_shift_amount(radical);
                } else {
                    box_shift_amount(degree) = - (tex_xn_over_d(total, raise, 100) - box_depth(radical) - box_shift_amount(radical));
                }
                tex_couple_nodes(degree, nucleus);
                if (before) {
                    halfword kern = tex_new_kern_node(before, horizontal_math_kern_subtype);
                    tex_attach_attribute_list_copy(kern, radical_degree(target));
                    tex_couple_nodes(kern, degree);
                    radical = kern;
                } else {
                    radical = degree;
                }
            } else {
                tex_flush_node(degree);
            }
            /*tex for |\Uroot.. {<list>} {}|: */
            kernel_math_list(radical_degree(target)) = null;
            tex_flush_node(radical_degree(target));
            radical_degree(target) = null;
        }
    }
    tex_aux_assign_radical(target, radical);
}

/*tex 
    This is pretty much the same as the above when the |norule| option is set. But by splitting this 
    variant off we can enhance it more cleanly. 
*/

static void tex_aux_make_delimited_radical(halfword target, int style, int size, kernset *kerns)
{
    halfword nucleus = noad_new_hlist(target);
 /* scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_radical_vgap); */
    halfword leftdelimiter = radical_left_delimiter(target);
    halfword rightdelimiter = radical_right_delimiter(target);
    halfword delimiter = leftdelimiter ? leftdelimiter : rightdelimiter;
    halfword companion = leftdelimiter ? rightdelimiter : null;
    halfword radical = null;
    halfword depth = has_noad_option_exact(target) ? radical_depth(target) : (box_depth(nucleus) + radical_depth(target));
    halfword height = has_noad_option_exact(target) ? radical_height(target) : (box_height(nucleus) + radical_height(target));
    halfword total = height + depth;
    delimiterextremes extremes = { .tfont = null_font, .tchar = 0, .bfont = null_font, .bchar = 0, .height = 0, .depth = 0 };
    noad_new_hlist(target) = null;
    size += radical_size(target);
    if (size < text_size) { 
        size = text_size;
    } else if (size > script_script_size) {
        size = script_script_size;
    }
    delimiter = tex_aux_make_delimiter(target, delimiter, size, total, 0, style, 2, NULL, NULL, 0, has_noad_option_nooverflow(target), &extremes, depth);
    if (companion) {
        /*tex For now we assume symmetry and same height and depth! */
        companion = tex_aux_make_delimiter(target, companion, size, total, 0, style, 2, NULL, NULL, 0, has_noad_option_nooverflow(target), &extremes, depth);
    }
    tex_aux_set_radical_kerns(&extremes, kerns);
    radical = tex_aux_link_radical(nucleus, delimiter, companion, rightdelimiter);
    tex_aux_assign_radical(target, radical);
}

/*tex Construct a vlist box: */

static halfword tex_aux_wrapup_over_under_delimiter(halfword target, halfword x, halfword y, scaled shift_up, scaled shift_down, quarterword st)
{
    halfword box = tex_new_null_box_node(vlist_node, st);
    scaled delta = (shift_up - box_depth(x)) - (box_height(y) - shift_down);
    box_height(box) = shift_up + box_height(x);
    box_depth(box) = box_depth(y) + shift_down;
    tex_attach_attribute_list_copy(box, target);
    if (delta) {
        halfword kern = tex_new_kern_node(delta, vertical_math_kern_subtype);
        tex_attach_attribute_list_copy(kern, target);
        tex_couple_nodes(x, kern);
        tex_couple_nodes(kern, y);
    } else {
        tex_couple_nodes(x, y);
    }
    box_list(box) = x;
    return box;
}

/*tex When |exact| use radicalwidth (|y| is delimiter). */

inline static halfword tex_aux_check_radical(halfword target, int stack, halfword r, halfword t)
{
    if (! stack && (box_width(r) >= box_width(t))) {
        scaled width = tex_aux_math_given_x_scaled(noad_width(target));
        if (width) {
            scaled delta = width - box_width(r);
            if (delta) {
                if (has_noad_option_left(target)) {
                    halfword kern = tex_new_kern_node(delta, horizontal_math_kern_subtype);
                    tex_attach_attribute_list_copy(kern, target);
                    tex_couple_nodes(kern, r);
                } else if (has_noad_option_middle(target)) {
                    halfword kern = tex_new_kern_node(tex_half_scaled(delta), horizontal_math_kern_subtype);
                    tex_attach_attribute_list_copy(kern, target);
                    tex_couple_nodes(kern, r);
                } else if (has_noad_option_right(target)) {
                    /*tex also kind of exact compared to vertical */
                } else {
                    return r;
                }
                r = tex_hpack(r, 0, packing_additional, direction_unknown, holding_none_option);
                box_width(r) = noad_width(target);
                tex_attach_attribute_list_copy(r, target);
            }
        }
    }
    return r;
}

inline static void tex_aux_fixup_radical_width(halfword target, halfword x, halfword y)
{
    if (box_width(y) >= box_width(x)) {
        if (noad_width(target)) {
            box_shift_amount(x) += tex_half_scaled(box_width(y) - box_width(x)) ;
        }
        box_width(x) = box_width(y);
    } else {
        if (noad_width(target)) {
            box_shift_amount(y) += tex_half_scaled(box_width(x) - box_width(y)) ;
        }
        box_width(y) = box_width(x);
    }
}

inline static halfword tex_aux_get_radical_width(halfword target, halfword p)
{
    return noad_width(target) ? noad_width(target) : box_width(p);
}

/*tex

    This has the |nucleus| box |x| as a limit above an extensible delimiter |y|.

*/

static void tex_aux_make_over_delimiter(halfword target, int style, int size)
{
    halfword result;
    scaled delta;
    int stack;
    scaled shift = tex_get_math_y_parameter_checked(style, math_parameter_over_delimiter_bgap);
    scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_over_delimiter_vgap);
    halfword content = tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_over_delimiter_variant), style, math_nucleus_list, 0, NULL);
    scaled width = tex_aux_get_radical_width(target, content);
    halfword over_delimiter = fraction_left_delimiter(target);
    halfword delimiter = tex_aux_make_delimiter(target, over_delimiter, size, width, 1, style, 1, &stack, NULL, 0, has_noad_option_nooverflow(target), NULL, 0);
    fraction_left_delimiter(target) = null;
    delimiter = tex_aux_check_radical(target, stack, delimiter, content);
    tex_aux_fixup_radical_width(target, content, delimiter);
    delta = clearance - (shift - box_depth(content) - box_height(delimiter));
    if (delta > 0) {
        shift += delta;
    }
    result = tex_aux_wrapup_over_under_delimiter(target, content, delimiter, shift, 0, math_over_delimiter_list);
    box_width(result) = box_width(content);
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
}

/*tex
    This has the extensible delimiter |x| as a limit below |nucleus| box |y|.
*/

static void tex_aux_make_under_delimiter(halfword target, int style, int size)
{
    halfword result;
    scaled delta;
    int stack;
    scaled shift = tex_get_math_y_parameter_checked(style, math_parameter_under_delimiter_bgap);
    scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_under_delimiter_vgap);
    halfword content = tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_under_delimiter_variant), style, math_nucleus_list, 0, NULL);
    scaled width = tex_aux_get_radical_width(target, content);
    halfword under_delimiter = fraction_left_delimiter(target);
    halfword delimiter = tex_aux_make_delimiter(target, under_delimiter, size, width, 1, style, 1, &stack, NULL, 0, has_noad_option_nooverflow(target), NULL, 0);
    fraction_left_delimiter(target) = null;
    delimiter = tex_aux_check_radical(target, stack, delimiter, content);
    tex_aux_fixup_radical_width(target, delimiter, content);
    delta = clearance - (- box_depth(delimiter) - (box_height(content) - shift));
    if (delta > 0) {
        shift += delta;
    }
    result = tex_aux_wrapup_over_under_delimiter(target, delimiter, content, 0, shift, math_under_delimiter_list);
    box_width(result) = box_width(content);
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
}

/*tex
    This has the extensible delimiter |x| as a limit above |nucleus| box |y|.
*/

static void tex_aux_make_delimiter_over(halfword target, int style, int size)
{
    halfword result;
    scaled actual;
    int stack;
    scaled shift = tex_get_math_y_parameter_checked(style, math_parameter_over_delimiter_bgap);
    scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_over_delimiter_vgap);
    halfword content = tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_delimiter_over_variant), style, math_nucleus_list, 0, NULL);
    scaled width = tex_aux_get_radical_width(target, content);
    halfword over_delimiter = fraction_left_delimiter(target);
    halfword delimiter = tex_aux_make_delimiter(target, over_delimiter, size + (size == script_script_size ? 0 : 1), width, 1, style, 1, &stack, NULL, 0, has_noad_option_nooverflow(over_delimiter), NULL, 0);
    fraction_left_delimiter(target) = null;
    delimiter = tex_aux_check_radical(target, stack, delimiter, content);
    tex_aux_fixup_radical_width(target, delimiter, content);
    shift -= box_total(delimiter);
    actual = shift - box_height(content);
    if (actual < clearance) {
        shift += (clearance - actual);
    }
    result = tex_aux_wrapup_over_under_delimiter(target, delimiter, content, shift, 0, math_over_delimiter_list);
    box_width(result) = box_width(delimiter);
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
}

/*tex
    This has the extensible delimiter |y| as a limit below a |nucleus| box |x|.
*/

static void tex_aux_make_delimiter_under(halfword target, int style, int size)
{
    halfword result;
    scaled actual;
    int stack;
    scaled shift = tex_get_math_y_parameter_checked(style, math_parameter_under_delimiter_bgap);
    scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_under_delimiter_vgap);
    halfword content = tex_aux_clean_box(noad_nucleus(target), tex_math_style_variant(style, math_parameter_delimiter_under_variant), style, math_nucleus_list, 0, NULL);
    scaled width = tex_aux_get_radical_width(target, content);
    halfword under_delimiter = fraction_left_delimiter(target);
    halfword delimiter = tex_aux_make_delimiter(target, under_delimiter, size + (size == script_script_size ? 0 : 1), width, 1, style, 1, &stack, NULL, 0, has_noad_option_nooverflow(under_delimiter), NULL, 0);
    fraction_left_delimiter(target) = null;
    delimiter = tex_aux_check_radical(target, stack, delimiter, content);
    tex_aux_fixup_radical_width(target, content, delimiter);
    shift -= box_total(delimiter);
    actual = shift - box_depth(content);
    if (actual < clearance) {
       shift += (clearance - actual);
    }
    result = tex_aux_wrapup_over_under_delimiter(target, content, delimiter, 0, shift, math_under_delimiter_list);
    /*tex This also equals |width(y)|: */
    box_width(result) = box_width(delimiter);
    kernel_math_list(noad_nucleus(target)) = result;
    node_type(noad_nucleus(target)) = sub_box_node;
}

static void tex_aux_make_radical(halfword target, int style, int size, kernset *kerns)
{
    switch (node_subtype(target)) {
        case under_delimiter_radical_subtype:
            tex_aux_make_under_delimiter(target, style, size);
            break;
        case over_delimiter_radical_subtype:
            tex_aux_make_over_delimiter(target, style, size);
            break;
        case delimiter_under_radical_subtype:
            tex_aux_make_delimiter_under(target, style, size);
            break;
        case delimiter_over_radical_subtype:
            tex_aux_make_delimiter_over(target, style, size);
            break;
        case delimited_radical_subtype:
            tex_aux_make_delimited_radical(target, style, size, kerns);
            break;
        case h_extensible_radical_subtype:
            tex_aux_make_hextension(target, style, size);
            break;
        default:
            tex_aux_make_root_radical(target, style, size, kerns);
            break;
    }
    if (noad_source(target)) {
        halfword result = kernel_math_list(noad_nucleus(target));
        if (result) {
            box_source_anchor(result) = noad_source(target);
            tex_set_box_geometry(result, anchor_geometry);
        }
    }
}

static void tex_aux_preroll_radical(halfword target, int style, int size)
{
    switch (node_subtype(target)) {
        case under_delimiter_radical_subtype:
        case over_delimiter_radical_subtype:
        case delimiter_under_radical_subtype:
        case delimiter_over_radical_subtype:
        case h_extensible_radical_subtype:
            break;
        default:
            tex_aux_preroll_root_radical(target, style, size);
            break;
    }
}

/*tex

    Slants are not considered when placing accents in math mode. The accenter is centered over the
    accentee, and the accent width is treated as zero with respect to the size of the final box.

*/

typedef enum math_accent_location_codes {
    top_accent_code     = 1,
    bot_accent_code     = 2,
    overlay_accent_code = 4,
    stretch_accent_code = 8,
} math_accent_location_codes;

static int tex_aux_compute_accent_skew(halfword target, int flags, scaled *skew, halfword size)
{
    /*tex will be true if a top-accent is placed in |s| */
    int absolute = 0;
    switch (node_type(noad_nucleus(target))) {
        case math_char_node:
            {
                halfword chr = null;
                halfword fnt = null;
                tex_aux_fetch(noad_nucleus(target), "accent", &fnt, &chr);
                if (tex_aux_math_engine_control(fnt, math_control_accent_skew_apply)) {
                    /*tex
                        There is no bot_accent so let's assume that the shift also applies
                        to bottom and overlay accents.
                    */
                    *skew = tex_char_unchecked_top_anchor_from_font(fnt, chr);
                    if (*skew != INT_MIN) {
                        *skew = tex_aux_math_x_size_scaled(fnt, *skew, size);
                        absolute = 1;
                    } else {
                        *skew = 0;
                    }
                } else if (flags & top_accent_code) {
                    *skew = tex_aux_math_x_size_scaled(fnt, tex_get_kern(fnt, chr, font_skew_char(fnt)), size);
                } else {
                    *skew = 0;
                }
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: accent skew, font %i, chr %x, skew %D, absolute %i]", fnt, chr, *skew, pt_unit, absolute);
                    tex_end_diagnostic();
                }
                break;
            }
        case sub_mlist_node:
            {
                /*tex
                    If |nucleus(q)| is a |sub_mlist_node| composed of an |accent_noad| we:

                    \startitemize
                    \startitem
                        use the positioning of the nucleus of that noad, recursing until
                    \stopitem
                    \startitem
                        the inner most |accent_noad|. This way multiple stacked accents are
                    \stopitem
                    \startitem
                        aligned to the inner most one.
                    \stopitem
                    \stoptitemize

                    The vlink test was added in version 1.06, so that we only consider a lone noad:

                    $
                        \Umathaccent bottom 0 0 "023DF {   \Umathaccent fixed 0 0 "00302 { m } r } \quad
                        \Umathaccent bottom 0 0 "023DF { l \Umathaccent fixed 0 0 "00302 { m } r } \quad
                        \Umathaccent bottom 0 0 "023DF { l \Umathaccent fixed 0 0 "00302 { m }   } \quad
                        \Umathaccent bottom 0 0 "023DF {   \Umathaccent fixed 0 0 "00302 { m }   } \quad
                        \Umathaccent bottom 0 0 "023DF { l                                      r }
                    $

                */
                halfword p = kernel_math_list(noad_nucleus(target));
                if (p && ! node_next(p)) {
                    switch (node_type(p)) {
                        case accent_noad:
                            absolute = tex_aux_compute_accent_skew(p, flags, skew, size);
                            break;
                        case simple_noad:
                            if (! noad_has_following_scripts(p)) {
                                absolute = tex_aux_compute_accent_skew(p, flags, skew, size);
                            }
                            break;
                    }
                }
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: accent skew, absolute %i]", absolute);
                    tex_end_diagnostic();
                }
                break;
            }
    }
    return absolute;
}

static void tex_aux_do_make_math_accent(halfword target, halfword accentfnt, halfword accentchr, int flags, int style, int size, scaled *accenttotal)
{
    /*tex The width and height (without scripts) of base character: */
    scaled baseheight = 0;
 // scaled basedepth = 0;
    scaled basewidth = 0;
    scaled usedwidth = 0;
    /*tex The space to remove between accent and base: */
    scaled delta = 0;
    scaled overshoot = 0;
    extinfo *extended = NULL;
    halfword attrlist = node_attr(target);
    scaled fraction = accent_fraction(target) > 0 ? accent_fraction(target) : 1000;
    scaled skew = 0;
    scaled offset = 0;
    halfword accent = null;
    halfword base = null;
    halfword result = null;
    halfword nucleus = noad_nucleus(target);
    halfword stretch = (flags & stretch_accent_code) == stretch_accent_code;
    halfword basefnt = null_font;
    halfword basechr = 0;
    /*tex
        Compute the amount of skew, or set |skew| to an alignment point. This will be true if a
        top-accent has been determined.
    */
    int absolute = tex_aux_compute_accent_skew(target, flags, &skew, size);
    {
        halfword usedstyle;
        if (flags & top_accent_code) {
            usedstyle = tex_math_style_variant(style, math_parameter_top_accent_variant);
        } else if (flags & bot_accent_code) {
            usedstyle = tex_math_style_variant(style, math_parameter_bottom_accent_variant);
        } else {
            usedstyle = tex_math_style_variant(style, math_parameter_overlay_accent_variant);
        }
        /*tex Beware: this adds italic correction because it feeds into mlist_to_hlist */
        base = tex_aux_clean_box(noad_nucleus(target), usedstyle, style, math_nucleus_list, 1, NULL); /* keep italic */
        basewidth = box_width(base);
        baseheight = box_height(base);
     // basedepth = box_depth(base);
    }
    if (base) {
        halfword list = box_list(base);
        if (list && node_type(list) == glyph_node) {
            basefnt = glyph_font(list);
            basechr = glyph_character(list);
        }
    }
    if (stretch && absolute && (flags & top_accent_code) && tex_aux_math_engine_control(accentfnt, math_control_accent_top_skew_with_offset)) {
        /*tex 
            This assumes a font that has been tuned for it. We used a privately made font (will be
            in the \CONTEXT\ distribution) RalphSmithsFormalScript.otf (derived from the type one 
            font) for experimenting with top accents and these parameters. The idea is to have a 
            decent accent on the very slanted top (of e.g. A) that sticks out a little at the right 
            edge but still use glyphs with a proper boundingbox, so no messing around with italic 
            correction. Eventually this might become a more advanced (general) mechanism. Watch the 
            formula for calculating the used width. 
        */
        if (base && basefnt && basechr) { 
            offset = tex_char_top_overshoot_from_font(basefnt, basechr);
            offset = offset == INT_MIN ? 0 : tex_aux_math_x_size_scaled(basefnt, offset, size);
        }
        usedwidth = 2 * ((skew < (basewidth - skew) ? skew : (basewidth - skew)) + offset);
    } else if (! absolute && tex_aux_math_engine_control(accentfnt, math_control_accent_skew_half)) {
        skew = tex_half_scaled(basewidth);
        absolute = 1;
        usedwidth = basewidth;
    } else { 
        usedwidth = basewidth;
    }
    /*tex
        Todo: |w = w - loffset - roffset| but then we also need to add a few
        kerns so no hurry with that one.
    */
    if (stretch && (tex_char_width_from_font(accentfnt, accentchr) < usedwidth)) {
        /*tex Switch to a larger accent if available and appropriate */
        scaled target = 0; 
        if (flags & overlay_accent_code) { 
            target = baseheight;
        } else {
            target += usedwidth;
            if (base && basefnt && basechr) { 
                target += tex_aux_math_x_size_scaled(basefnt, tex_char_right_margin_from_font(basefnt, basechr), size);
                target += tex_aux_math_x_size_scaled(basefnt, tex_char_left_margin_from_font(basefnt, basechr), size);
            }
        }
        if (fraction > 0) {
            target = tex_xn_over_d(target, fraction, 1000);
        }
        while (1) {
            if (tex_char_has_tag_from_font(accentfnt, accentchr, extensible_tag)) {
                extended = tex_char_extensible_recipe_from_font(accentfnt, accentchr);
            }
            if (extended) {
                /*tex
                    This is a bit weird for an overlay but anyway, here we don't need a factor as
                    we don't step.
                */
                halfword overlap = tex_get_math_x_parameter_checked(style, math_parameter_connector_overlap_min);
                accent = tex_aux_get_delimiter_box(accentfnt, accentchr, usedwidth, overlap, 1, attrlist);
                accent = register_extensible(accentfnt, accentchr, size, accent, attrlist);
                break;
            } else if (! tex_char_has_tag_from_font(accentfnt, accentchr, list_tag)) {
                break;
            } else {
                halfword next = tex_char_next_from_font(accentfnt, accentchr);
                if (! tex_char_exists(accentfnt, next)) {
                    break;
                } else if (flags & overlay_accent_code) {
                    if (tex_aux_math_y_size_scaled(accentfnt, tex_char_height_from_font(accentfnt, next), size) > target) {
                        break;
                    }
                } else {
                    if (tex_aux_math_x_size_scaled(accentfnt, tex_char_width_from_font(accentfnt, next), size) > target) {
                        break;
                    }
                }
                accentchr = next;
            }
        }
        /*tex
            So here we then need to package the offsets.
        */
    }
    if (! accent) {
        /*tex Italic gets added to width for traditional fonts (no italic anyway): */
        accent = tex_aux_char_box(accentfnt, accentchr, attrlist, NULL, glyph_math_accent_subtype, basewidth, style); // usedwidth 
    }
    if (flags & top_accent_code) {
        scaled b = tex_get_math_y_parameter(style, math_parameter_accent_base_height);
        scaled u = tex_get_math_y_parameter(style, stretch ? math_parameter_flattened_accent_top_shift_up : math_parameter_accent_top_shift_up);
        if (! tex_aux_math_engine_control(accentfnt, math_control_ignore_flat_accents)) {
            scaled f = tex_get_math_y_parameter(style, math_parameter_flattened_accent_base_height);
            if (f != undefined_math_parameter && baseheight > f) {
                halfword flatchr = tex_char_flat_accent_from_font(accentfnt, accentchr);
                if (flatchr != INT_MIN && flatchr != accentchr) {
                    tex_flush_node(accent);
                    accent = tex_aux_char_box(accentfnt, flatchr, attrlist, NULL, glyph_math_accent_subtype, usedwidth, style);
                    if (tracing_math_par >= 2) {
                        tex_begin_diagnostic();
                        tex_print_format("[math: flattening accent, old %x, new %x]", accentchr, flatchr);
                        tex_end_diagnostic();
                    }
                    accentchr = flatchr;
                }
            }
        }
        if (b != undefined_math_parameter) {
            /* not okay */
            delta = baseheight < b ? baseheight : b;
        }
        if (u != undefined_math_parameter) {
            delta -= u;
        }
    } else if (flags & bot_accent_code) {
     // scaled b = tex_get_math_y_parameter(style, math_parameter_accent_base_depth, 0);
     // scaled f = tex_get_math_y_parameter(style, math_parameter_flattened_accent_base_depth, 0);
        scaled l = tex_get_math_y_parameter(style, stretch ? math_parameter_flattened_accent_bottom_shift_down : math_parameter_accent_bottom_shift_down);
     // if (b != undefined_math_parameter) {
         // /* not okay */
         // delta = basedepth < b ? basedepth : b;
     // }
        if (l != undefined_math_parameter) {
            delta += l;
        }
    } else { /* if (flags & overlay_accent_code) { */
        /*tex Center the accent vertically around base: */
        delta = tex_half_scaled(box_total(accent) + box_total(base));
    }
    if (accenttotal) {
        *accenttotal = box_total(accent);
    }
    if (node_type(nucleus) != math_char_node) {
        /*tex We have a molecule, not a simple atom. */
    } else if (noad_has_following_scripts(target)) {
        /*tex Swap the scripts: */
        tex_flush_node_list(base);
        base = tex_new_node(simple_noad, ordinary_noad_subtype);
        tex_attach_attribute_list_copy(base, nucleus);
        noad_nucleus(base) = tex_aux_math_clone(nucleus);
        /* we no longer move the outer scripts to the inner noad */
        node_type(nucleus) = sub_mlist_node;
        kernel_math_list(nucleus) = base;
        base = tex_aux_clean_box(nucleus, style, style, math_nucleus_list, 1, NULL); /* keep italic */
        delta = delta + box_height(base) - baseheight;
        baseheight = box_height(base);
    }
    /*tex The top accents of both characters are aligned. */
    {
        halfword accentwidth = box_width(accent);
        if (absolute) {
            scaled anchor = 0;
            if (extended) {
                /*tex If the accent is extensible just take the center. */
                anchor = tex_half_scaled(accentwidth);
            } else {
                anchor = tex_char_unchecked_top_anchor_from_font(accentfnt, accentchr); /* no bot accent key */
                if (anchor != INT_MIN) {
                    anchor = tex_aux_math_y_size_scaled(accentfnt, anchor, size); /* why y and not x */
                } else {
                    /*tex just take the center */
                    anchor = tex_half_scaled(accentwidth);
                }
            }
            if (math_direction_par == dir_righttoleft) {
               skew += anchor - accentwidth;
            } else {
               skew -= anchor;
            }
        } else if (accentwidth == 0) {
            skew += basewidth;
        } else if (math_direction_par == dir_righttoleft) {
            skew += accentwidth; /* ok? */
        } else {
            skew += tex_half_scaled(basewidth - accentwidth);
        }
        box_shift_amount(accent) = skew;
        box_width(accent) = 0; /* in gyre zero anyway */
        if (accentwidth) { 
            overshoot = accentwidth + skew - basewidth;
        }
        if (overshoot < 0) {
            overshoot = 0;
        }
    }
    if (flags & (top_accent_code)) {
        accent_top_overshoot(target) = overshoot;
    }
    if (flags & (bot_accent_code)) {
        accent_bot_overshoot(target) = overshoot;
    }
    if (flags & (top_accent_code | overlay_accent_code)) {
        if (delta) {
            halfword kern = tex_new_kern_node(-delta, vertical_math_kern_subtype);
            tex_attach_attribute_list_copy(kern, target);
            tex_couple_nodes(accent, kern);
            tex_couple_nodes(kern, base);
        } else {
            tex_couple_nodes(accent, base);
        }
        result = accent;
    } else {
        tex_couple_nodes(base, accent);
        result = base;
    }
    result = tex_vpack(result, 0, packing_additional, max_dimen, (singleword) math_direction_par, holding_none_option);
    tex_attach_attribute_list_copy(result, target);
    node_subtype(result) = math_accent_list;
    box_width(result) = box_width(base); // basewidth
    delta = baseheight - box_height(result);
    if (flags & (top_accent_code | overlay_accent_code)) {
        if (delta > 0) {
            /*tex make the height of box |y| equal to |h| */
            halfword kern = tex_new_kern_node(delta, vertical_math_kern_subtype);
            tex_attach_attribute_list_copy(kern, target);
            tex_try_couple_nodes(kern, box_list(result));
            box_list(result) = kern;
            box_height(result) = baseheight;
        }
    } else {
        box_shift_amount(result) = - delta;
    }
    box_width(result) += overshoot;
    kernel_math_list(nucleus) = result;
    node_type(nucleus) = sub_box_node;
}

static void tex_aux_make_accent(halfword target, int style, int size, kernset *kerns)
{
    int topstretch = 0; /* ! (node_subtype(q) % 2); */
    int botstretch = 0; /* ! (node_subtype(q) / 2); */
    halfword fnt = null;
    halfword chr = null;
    /*tex
        We don't do some div and mod magic on the subtype here: we just check it:
    */
    switch (node_subtype(target)) {
        case bothflexible_accent_subtype: topstretch = 1; botstretch = 1; break;
        case fixedtop_accent_subtype    : botstretch = 1; break;
        case fixedbottom_accent_subtype : topstretch = 1; break;
        case fixedboth_accent_subtype   : break;
    }
    /*tex
        There is some inefficiency here as we calculate the width of the nuclues upto three times.
        Maybe I need to have a look at that some day.
    */
    if (accent_top_character(target)) {
        if (tex_aux_fetch(accent_top_character(target), "top accent", &fnt, &chr)) {
            tex_aux_do_make_math_accent(target, fnt, chr, top_accent_code | (topstretch ? stretch_accent_code : 0), style, size, &(kerns->toptotal));
        }
        tex_flush_node(accent_top_character(target));
        accent_top_character(target) = null;
    }
    if (accent_bottom_character(target)) {
        if (tex_aux_fetch(accent_bottom_character(target), "bottom accent", &fnt, &chr)) {
            tex_aux_do_make_math_accent(target, fnt, chr, bot_accent_code | (botstretch ? stretch_accent_code : 0), style, size, &(kerns->bottomtotal));
        }
        tex_flush_node(accent_bottom_character(target));
        accent_bottom_character(target) = null;
    }
    if (accent_middle_character(target)) {
        if (tex_aux_fetch(accent_middle_character(target), "overlay accent", &fnt, &chr)) {
            tex_aux_do_make_math_accent(target, fnt, chr, overlay_accent_code | stretch_accent_code, style, size, NULL);
        }
        tex_flush_node(accent_middle_character(target));
        accent_middle_character(target) = null;
    }
    if (noad_source(target)) {
        halfword result = kernel_math_list(noad_nucleus(target));
        if (result) {
            box_source_anchor(result) = noad_source(target);
            tex_set_box_geometry(result, anchor_geometry);
        }
    }
}

/*tex

    The |make_fraction| procedure is a bit different because it sets |new_hlist (q)| directly rather
    than making a sub-box.

    Kerns are probably never zero so no need to be lean here. Actually they are likely to
    be the same. By the time we make the rule we already dealt with all these clearance
    issues, so we're sort of ahead of what happens in a callback wrt thickness.

    This rather large function has been split up in pieces which is a bit more readable but also gives
    a much bigger binary (probably due to inlining the helpers).  

*/ 

/*tex
    Create equal-width boxes |x| and |z| for the numerator and denominator. After this one is 
    called we compute the default amounts |shift_up| and |shift_down| by which they are displaced 
    from the baseline.
*/

static void tex_aux_wrap_fraction_parts(halfword target, int style, int size, halfword *numerator, halfword *denominator, int check)
{
    if (noad_style(target) == unused_math_style) {
        *numerator = tex_aux_clean_box(fraction_numerator(target), tex_math_style_variant(style, math_parameter_numerator_variant), style, math_numerator_list, 0, NULL);
        *denominator = tex_aux_clean_box(fraction_denominator(target), tex_math_style_variant(style, math_parameter_denominator_variant), style, math_denominator_list, 0, NULL);
    } else {
        *numerator = tex_aux_clean_box(fraction_numerator(target), noad_style(target), style, math_numerator_list, 0, NULL);
        *denominator = tex_aux_clean_box(fraction_denominator(target), noad_style(target), style, math_denominator_list, 0, NULL);
    }
    if (check) {
        if (box_width(*numerator) < box_width(*denominator)) {
            *numerator = tex_aux_rebox(*numerator, box_width(*denominator), size);
        } else {
            *denominator = tex_aux_rebox(*denominator, box_width(*numerator), size);
        }
    }
}

/*tex
    Put the fraction into a box with its delimiters, and make |new_hlist(q)| point to it.
*/

static void tex_aux_wrap_fraction_result(halfword target, int style, int size, halfword fraction, kernset *kerns)
{
    halfword result = null;
    halfword left_delimiter = fraction_left_delimiter(target);
    halfword right_delimiter = fraction_right_delimiter(target);
    if (left_delimiter || right_delimiter) {
        halfword left = null;
        halfword right = null;
        halfword delta = tex_get_math_y_parameter(style, math_parameter_fraction_del_size);
        delimiterextremes extremes = { .tfont = null_font, .tchar = 0, .bfont = null_font, .bchar = 0, .height = 0, .depth = 0 };
        if (delta == undefined_math_parameter) {
            delta = tex_aux_get_delimiter_height(box_height(fraction), box_depth(fraction), 1, size, style);
        }
        /*tex Watch out: there can be empty delimiter boxes but with width. */
        left = tex_aux_make_delimiter(target, left_delimiter, size, delta, 0, style, 1, NULL, NULL, 0, has_noad_option_nooverflow(target), NULL, 0);
        right = tex_aux_make_delimiter(target, right_delimiter, size, delta, 0, style, 1, NULL, NULL, 0, has_noad_option_nooverflow(target), &extremes, 0);
        if (kerns && extremes.tfont) { 
            if (tex_math_has_class_option(fraction_noad_subtype, carry_over_left_top_kern_class_option)) {  
                kerns->topleft = tex_char_top_left_kern_from_font(extremes.tfont, extremes.tchar);
            }
            if (tex_math_has_class_option(fraction_noad_subtype, carry_over_left_bottom_kern_class_option)) {  
                kerns->bottomleft = tex_char_bottom_left_kern_from_font(extremes.bfont, extremes.bchar);
            }
            if (tex_math_has_class_option(fraction_noad_subtype, carry_over_right_top_kern_class_option)) {  
                kerns->topright = tex_char_top_right_kern_from_font(extremes.tfont, extremes.tchar);
            }
            if (tex_math_has_class_option(fraction_noad_subtype, carry_over_right_bottom_kern_class_option)) {  
                kerns->bottomright = tex_char_bottom_right_kern_from_font(extremes.bfont, extremes.bchar);
            }
            if (tex_math_has_class_option(fraction_noad_subtype, prefer_delimiter_dimensions_class_option)) {  
                kerns->height = extremes.height;
                kerns->depth = extremes.depth;
                kerns->dimensions = 1;
                kerns->font = extremes.tfont;
            }
        }
     /* tex_aux_normalize_delimiters(left, right); */
        tex_couple_nodes(left, fraction);
        tex_couple_nodes(fraction, right);
        fraction = left;
    }
    result = tex_hpack(fraction, 0, packing_additional, direction_unknown, holding_none_option);
    /*tex There can also be a nested one: */
    node_subtype(result) = math_fraction_list;
    tex_aux_assign_new_hlist(target, result);
    if (noad_source(target)) {
        box_source_anchor(result) = noad_source(target);
     // box_anchor(result) = left_origin_anchor;
        tex_set_box_geometry(result, anchor_geometry);
    }
}

/*tex
    The numerator and denominator must be separated by a certain minimum clearance, called |clr| in 
    the following program. The difference between |clr| and the actual clearance is |2 * delta|.

    In the case of a fraction line, the minimum clearance depends on the actual thickness of the 
    line but we've moved that elsewhere. This gap vs up/down is kindo f weird anyway. 
*/

static void tex_aux_calculate_fraction_shifts(halfword target, int style, int size, scaled *shift_up, scaled *shift_down, int up, int down)
{
    (void) size;
    *shift_up = tex_get_math_y_parameter_checked(style, up);
    *shift_down = tex_get_math_y_parameter_checked(style, down);
    *shift_up = tex_round_xn_over_d(*shift_up, fraction_v_factor(target), 1000);
    *shift_down = tex_round_xn_over_d(*shift_down, fraction_v_factor(target), 1000);
}

static void tex_aux_calculate_fraction_shifts_stack(halfword target, int style, int size, halfword numerator, halfword denominator, scaled *shift_up, scaled *shift_down, scaled *delta)
{
    scaled clearance = tex_get_math_y_parameter_checked(style, math_parameter_stack_vgap);
    tex_aux_calculate_fraction_shifts(target, style, size, shift_up, shift_down, math_parameter_stack_num_up, math_parameter_stack_denom_down);
    *delta = tex_half_scaled(clearance - ((*shift_up - box_depth(numerator)) - (box_height(denominator) - *shift_down)));
    if (*delta > 0) {
        *shift_up += *delta;
        *shift_down += *delta;
    }
}

static void tex_aux_calculate_fraction_shifts_normal(halfword target, int style, int size, halfword numerator, halfword denominator, scaled *shift_up, scaled *shift_down, scaled *delta)
{
    scaled axis = tex_aux_math_axis(size);
    scaled numerator_clearance = tex_get_math_y_parameter_checked(style, math_parameter_fraction_num_vgap);
    scaled denominator_clearance = tex_get_math_y_parameter_checked(style, math_parameter_fraction_denom_vgap);
    scaled delta_up = 0;
    scaled delta_down = 0;
    tex_aux_calculate_fraction_shifts(target, style, size, shift_up, shift_down, math_parameter_fraction_num_up, math_parameter_fraction_denom_down);
    /* hm, delta is only set when we have a middle delimiter ... needs checking .. i should write this from scratch */
    *delta = tex_half_scaled(tex_aux_math_given_y_scaled(fraction_rule_thickness(target)));
    delta_up = numerator_clearance - ((*shift_up   - box_depth(numerator) ) - (axis + *delta));
    delta_down = denominator_clearance - ((*shift_down - box_height(denominator)) + (axis - *delta));
    if (delta_up > 0) {
        *shift_up += delta_up;
    }
    if (delta_down > 0) {
        *shift_down += delta_down;
    }
}

static scaled tex_aux_check_fraction_rule(halfword target, int style, int size, int fractiontype, halfword *usedfam)
{
    scaled preferfont = has_noad_option_preferfontthickness(target);
    halfword fam = math_rules_fam_par;
    (void) style;
    /*tex
        We can take the rule width from an explicitly set fam, even if a fraction itself has no
        character, otherwise we just use the math parameter.
    */
    if (preferfont) {
        /*tex Forced by option or command. */
    } else if (fractiontype == above_fraction_subtype) {
        /*tex Bypassed by command. */
        preferfont = 0;
        if (has_noad_option_proportional(target)) {            
            /* We replaced the non |exact| code path by this one: */
            scaled text = tex_get_math_y_parameter_checked(text_style, math_parameter_fraction_rule);
            scaled here = tex_get_math_y_parameter_checked(style, math_parameter_fraction_rule);
            fraction_rule_thickness(target) = tex_ext_xn_over_d(fraction_rule_thickness(target), here, text);
        }
    } else if (fraction_rule_thickness(target)) {
        /*tex Controlled by optional parameter. */
        preferfont = 1;
    }
    if (preferfont) {
        halfword t = tex_aux_check_rule_thickness(target, size, &fam, math_control_fraction_rule, FractionRuleThickness);
        if (t != undefined_math_parameter) {
            fraction_rule_thickness(target) = t;
        }
    }
    if (fraction_rule_thickness(target) == preset_rule_thickness) {
        fraction_rule_thickness(target) = tex_get_math_y_parameter_checked(style, math_parameter_fraction_rule); 
    }
    if (usedfam) {
        *usedfam = fam;
    }
    return tex_aux_math_given_y_scaled(fraction_rule_thickness(target));
}

static void tex_aux_compensate_fraction_rule(halfword target, halfword fraction, halfword separator, scaled thickness)
{
    (void) target;
    if (box_total(separator) != thickness) {
        scaled half = tex_half_scaled(box_total(separator) - thickness);
        box_height(fraction) += half;
        box_depth(fraction) += half;
    }
}

static void tex_aux_apply_fraction_shifts(halfword fraction, halfword numerator, halfword denominator, scaled shift_up, scaled shift_down)
{
    box_height(fraction) = shift_up + box_height(numerator);
    box_depth(fraction) = box_depth(denominator) + shift_down;
    box_width(fraction) = box_width(numerator);
}

/*tex
    We construct a vlist box for the fraction, according to |shift_up| and |shift_down|. Maybe in 
    the meantime it is nicer to just calculate the fraction instead of messing with the height and
    depth explicitly (the old approach). 
*/

static halfword tex_aux_assemble_fraction(halfword target, int style, int size, halfword numerator, halfword denominator, halfword separator, scaled delta, scaled shift_up, scaled shift_down)
{
    (void) target;
    (void) style;
    if (separator) {
        scaled axis = tex_aux_math_axis(size);
        halfword after = tex_new_kern_node((axis - delta) - (box_height(denominator) - shift_down), vertical_math_kern_subtype);
        halfword before = tex_new_kern_node((shift_up - box_depth(numerator)) - (axis + delta), vertical_math_kern_subtype);
        tex_attach_attribute_list_copy(after, target);
        tex_attach_attribute_list_copy(before, target);
        tex_couple_nodes(separator, after);
        tex_couple_nodes(after, denominator);
        tex_couple_nodes(before, separator);
        tex_couple_nodes(numerator, before);
    } else { 
        halfword between = tex_new_kern_node((shift_up - box_depth(numerator)) - (box_height(denominator) - shift_down), vertical_math_kern_subtype);
        tex_attach_attribute_list_copy(between, target);
        tex_couple_nodes(between, denominator);
        tex_couple_nodes(numerator, between);
    }
    return numerator;
}

static halfword tex_aux_make_skewed_fraction(halfword target, int style, int size, kernset *kerns)
{
    halfword middle = null;
    halfword fraction = null;
    halfword numerator = null;
    halfword denominator = null;
    scaled delta = 0;
    halfword middle_delimiter = fraction_middle_delimiter(target);
    scaled maxheight = 0;
    scaled maxdepth = 0;
    scaled ngap = 0;
    scaled dgap = 0;
    scaled hgap = 0;
    delimiterextremes extremes = { .tfont = null_font, .tchar = 0, .bfont = null_font, .bchar = 0, .height = 0, .depth = 0 };
    scaled tolerance = tex_get_math_y_parameter_default(style, math_parameter_skewed_delimiter_tolerance, 0);
    scaled shift_up = tex_get_math_y_parameter_checked(style, math_parameter_skewed_fraction_vgap);
    scaled shift_down = tex_round_xn_over_d(shift_up, fraction_v_factor(target), 1000);
    (void) kerns;
    shift_up = shift_down; /*tex The |shift_up| value might change later. */
    tex_aux_wrap_fraction_parts(target, style, size, &numerator, &denominator, 0);
    /*tex 
        Here we don't share code because we're going horizontal.
    */
    if (! has_noad_option_noaxis(target)) {
        shift_up += tex_half_scaled(tex_aux_math_axis(size));
    }
    /*tex
        Construct a hlist box for the fraction, according to |hgap| and |vgap|.
    */
    hgap = tex_get_math_x_parameter_checked(style, math_parameter_skewed_fraction_hgap);
    hgap = tex_round_xn_over_d(hgap, fraction_h_factor(target), 1000);
    {
        scaled ht = box_height(numerator) + shift_up;
        scaled dp = box_depth(numerator) - shift_up;
        if (dp < 0) {
            dp = 0;
        }
        if (ht < 0) {
            ht = 0;
        }
        if (ht > maxheight) {
            maxheight = ht;
        }
        if (dp > maxdepth) {
            maxdepth = dp;
        }
    }
    {
        scaled ht = box_height(denominator) - shift_down;
        scaled dp = box_depth(denominator) + shift_down;
        if (dp < 0) {
            dp = 0;
        }
        if (ht < 0) {
            ht = 0;
        }
        if (ht > maxheight) {
            maxheight = ht;
        }
        if (dp > maxdepth) {
            maxdepth = dp;
        }
    }
    box_shift_amount(numerator) = -shift_up;
    box_shift_amount(denominator) = shift_down;
    delta = maxheight + maxdepth;
    middle = tex_aux_make_delimiter(target, middle_delimiter, size, delta, 0, style, 1, NULL, NULL, tolerance, has_noad_option_nooverflow(target), &extremes, 0);
    fraction = tex_new_null_box_node(hlist_node, math_fraction_list);
    tex_attach_attribute_list_copy(fraction, target);
    box_width(fraction) = box_width(numerator) + box_width(denominator) + box_width(middle) - hgap;
    hgap = -tex_half_scaled(hgap);
    box_height(fraction) = box_height(middle) > maxheight ? box_height(middle) : maxheight;
    box_depth(fraction) = box_depth(middle) > maxdepth ? box_depth(middle) : maxdepth;
    ngap = hgap; 
    dgap = hgap; 
    if (tex_math_has_class_option(fraction_noad_subtype, carry_over_left_top_kern_class_option)) {  
        ngap += tex_char_top_left_kern_from_font(extremes.tfont, extremes.tchar);
    }
    if (tex_math_has_class_option(fraction_noad_subtype, carry_over_right_bottom_kern_class_option)) {  
        dgap += tex_char_bottom_right_kern_from_font(extremes.tfont, extremes.tchar);
    }
    if (ngap || dgap) {
        // todo: only add when non zero 
        halfword nkern = tex_new_kern_node(ngap, horizontal_math_kern_subtype);
        halfword dkern = tex_new_kern_node(dgap, horizontal_math_kern_subtype);
        tex_attach_attribute_list_copy(nkern, target);
        tex_attach_attribute_list_copy(dkern, target);
        tex_couple_nodes(numerator, nkern);
        tex_couple_nodes(nkern, middle);
        tex_couple_nodes(middle, dkern);
        tex_couple_nodes(dkern, denominator);
    } else {
        tex_couple_nodes(numerator, middle);
        tex_couple_nodes(middle, denominator);
    }
    box_list(fraction) = numerator;     
    return fraction;
}

static halfword tex_aux_make_stretched_fraction(halfword target, int style, int size, kernset *kerns)
{
    halfword middle = null;
    halfword numerator = null;
    halfword denominator = null;
    scaled shift_up = 0;
    scaled shift_down = 0;
    scaled delta = 0;
    halfword middle_delimiter = fraction_middle_delimiter(target);
    halfword thickness = tex_aux_check_fraction_rule(target, style, size, stretched_fraction_subtype, NULL);
    halfword fraction = tex_new_null_box_node(vlist_node, math_fraction_list);
    (void) kerns;
    tex_attach_attribute_list_copy(fraction, target);
    tex_aux_wrap_fraction_parts(target, style, size, &numerator, &denominator, 1);
    tex_aux_calculate_fraction_shifts_normal(target, style, size, numerator, denominator, &shift_up, &shift_down, &delta);
    tex_aux_apply_fraction_shifts(fraction, numerator, denominator, shift_up, shift_down);
    middle = tex_aux_make_delimiter(target, middle_delimiter, size, box_width(fraction), 1, style, 0, NULL, NULL, 0, 0, NULL, 0);
    if (box_width(middle) < box_width(fraction)) {
        /*tex It's always in the details: */
        scaled delta = (box_width(fraction) - box_width(middle)) / 2;
        tex_aux_prepend_hkern_to_box_list(middle, delta, horizontal_math_kern_subtype, "bad delimiter");
        tex_aux_append_hkern_to_box_list(middle, delta, horizontal_math_kern_subtype, "bad delimiter");
        box_width(middle) = box_width(fraction);
    }
    tex_aux_compensate_fraction_rule(target, fraction, middle, thickness);
    box_list(fraction) = tex_aux_assemble_fraction(target, style, size, numerator, denominator, middle, delta, shift_up, shift_down);
    return fraction;
}

static halfword tex_aux_make_ruled_fraction(halfword target, int style, int size, kernset *kerns, int fractiontype)
{
    halfword numerator = null;
    halfword denominator = null;
    scaled shift_up = 0;
    scaled shift_down = 0;
    scaled delta = 0;
    halfword fam = 0;
    halfword thickness = tex_aux_check_fraction_rule(target, style, size, fractiontype, &fam);
    halfword fraction = tex_new_null_box_node(vlist_node, math_fraction_list);
    halfword rule = null;
    (void) kerns;
    tex_attach_attribute_list_copy(fraction, target);
    tex_aux_wrap_fraction_parts(target, style, size, &numerator, &denominator, 1);
    if (fraction_rule_thickness(target) == 0) {
        tex_aux_calculate_fraction_shifts_stack(target, style, size, numerator, denominator, &shift_up, &shift_down, &delta);
    } else {
        tex_aux_calculate_fraction_shifts_normal(target, style, size, numerator, denominator, &shift_up, &shift_down, &delta);
    }
    tex_aux_apply_fraction_shifts(fraction, numerator, denominator, shift_up, shift_down);
    if (fractiontype != atop_fraction_subtype) {
        rule = tex_aux_fraction_rule(box_width(fraction), thickness, get_attribute_list(target), math_fraction_rule_subtype, size, fam);
        tex_aux_compensate_fraction_rule(target, fraction, rule, thickness);
    }
    box_list(fraction) = tex_aux_assemble_fraction(target, style, size, numerator, denominator, rule, delta, shift_up, shift_down);
    return fraction;
}

/*tex 
    We intercept bad nodes created at the \LUA\ end but only partially. The fraction handler is
    quite complex and uses a lot of parameters. You shouldn't mess with \TEX. 
*/

static void tex_aux_make_fraction(halfword target, int style, int size, kernset *kerns)
{
    quarterword fractiontype = node_subtype(target);
    halfword fraction = null;
  TRYAGAIN:
    switch (fractiontype) { 
        case over_fraction_subtype: 
        case atop_fraction_subtype: 
        case above_fraction_subtype: 
            tex_flush_node_list(fraction_middle_delimiter(target));
            fraction_middle_delimiter(target) = null;
            fraction = tex_aux_make_ruled_fraction(target, style, size, kerns, fractiontype);
            break;
        case skewed_fraction_subtype: 
            fraction_rule_thickness(target) = 0;
            fraction = tex_aux_make_skewed_fraction(target, style, size, kerns);
            break;
        case stretched_fraction_subtype: 
            fraction = tex_aux_make_stretched_fraction(target, style, size, kerns);
            break;
        default: 
            fractiontype = atop_fraction_subtype;
            goto TRYAGAIN;
    }
    tex_aux_wrap_fraction_result(target, style, size, fraction, kerns);
    fraction_left_delimiter(target) = null;
    fraction_middle_delimiter(target) = null;
    fraction_right_delimiter(target) = null;
}

/*tex

    If the nucleus of an |op_noad| is a single character, it is to be centered vertically with
    respect to the axis, after first being enlarged (via a character list in the font) if we are in
    display style. The normal convention for placing displayed limits is to put them above and
    below the operator in display style.

    The italic correction is removed from the character if there is a subscript and the limits are
    not being displayed. The |make_op| routine returns the value that should be used as an offset
    between subscript and superscript.

    After |make_op| has acted, |subtype(q)| will be |limits| if and only if the limits have been
    set above and below the operator. In that case, |new_hlist(q)| will already contain the desired
    final box.

    In display mode we also handle the nolimits scripts here because we have an option to tweak the
    placement with |\mathnolimitsmode| in displaymode. So, when we have neither |\limits| or
    |\nolimits| in text mode we fall through and scripts are dealt with later.

*/

static void tex_aux_make_scripts (
    halfword  target,
    halfword  kernel,
    scaled    italic,
    int       style,
    scaled    supshift,
    scaled    subshift,
    scaled    supdrop,
    kernset  *kerns
);

static halfword tex_aux_check_nucleus_complexity (
    halfword  target,
    scaled   *delta,
    halfword  style,
    halfword  size,
    kernset  *kerns
);

/*
    For easy configuration ... fonts are somewhat inconsistent and the values for italic correction 
    run from 30 to 60\% of the width.
*/

static void tex_aux_get_shifts(int mode, int style, scaled delta, scaled *top, scaled *bot)
{
    switch (mode) {
        case 0:
            /*tex full bottom correction */
            *top = 0;
            *bot = -delta;
            break;
        case 1:
            /*tex |MathConstants| driven */
            *top =  tex_round_xn_over_d(delta, tex_get_math_parameter_default(style, math_parameter_nolimit_sup_factor, 0), 1000);
            *bot = -tex_round_xn_over_d(delta, tex_get_math_parameter_default(style, math_parameter_nolimit_sub_factor, 0), 1000);
            break ;
        case 2:
            /*tex no correction */
            *top = 0;
            *bot = 0;
            break ;
        case 3:
            /*tex half bottom correction */
            *top =  0;
            *bot = -tex_half_scaled(delta);
            break;
        case 4:
            /*tex half bottom and top correction */
            *top =  tex_half_scaled(delta);
            *bot = -tex_half_scaled(delta);
            break;
        default :
            /*tex above 15: for quickly testing values */
            *top =  0;
            *bot = (mode > 15) ? -tex_round_xn_over_d(delta, mode, 1000) : 0;
            break;
    }
}

static scaled tex_aux_op_no_limits(halfword target, int style, int size, int italic, kernset *kerns, int forceitalics)
{
    kernset localkerns ;
    halfword kernel;
    (void) size; 
    (void) forceitalics; 
    if (kerns) { 
        tex_math_copy_kerns(&localkerns, kerns);
    } else { 
        tex_math_wipe_kerns(&localkerns);
    }
    kernel = tex_aux_check_nucleus_complexity(target, NULL, style, lmt_math_state.size, &localkerns);
    if (noad_has_scripts(target)) {
        scaled topshift = 0; /*tex Normally this would be: | delta|. */
        scaled botshift = 0; /*tex Normally this would be: |-delta|. */
        if (localkerns.topright || localkerns.bottomright) {
            italic = 0;
        }
        tex_aux_get_shifts(math_nolimits_mode_par, style, italic, &topshift, &botshift);
        tex_aux_make_scripts(target, kernel, 0, style, topshift, botshift, 0, &localkerns);
    } else {
        tex_aux_assign_new_hlist(target, kernel);
    }
    // italic = 0;
    return 0; 
}

static scaled tex_aux_op_do_limits(halfword target, int style, int size, int italic, kernset *kerns, int forceitalics)
{
    halfword nucleus = noad_nucleus(target);
    halfword superscript = tex_aux_clean_box(noad_supscr(target), tex_math_style_variant(style, math_parameter_superscript_variant), style, math_sup_list, 0, NULL);
    halfword kernel = tex_aux_clean_box(nucleus, style, style, math_nucleus_list, forceitalics, NULL);
    halfword subscript = tex_aux_clean_box(noad_subscr(target), tex_math_style_variant(style, math_parameter_subscript_variant), style, math_sub_list, 0, NULL);
    halfword result = tex_new_null_box_node(vlist_node, math_modifier_list);
    (void) kerns;
    tex_attach_attribute_list_copy(result, target);
    if (nucleus) {
        // todo: get rid of redundant italic calculation ... it is still a mess .. maybe use noad_italic .. then this whole branch can go 
        switch (node_type(nucleus)) {
            case sub_mlist_node:
            case sub_box_node:
                {
                    halfword n = kernel_math_list(nucleus);
                    if (! n) {
                        /* kind of special */
                    } else if (node_type(n) == hlist_node) {
                        /*tex just a not scaled char */
                        n = box_list(n);
                        while (n) {
                            if (node_type(n) == glyph_node && ! tex_has_glyph_option(n, glyph_option_no_italic_correction)) {
                                if (tex_aux_math_engine_control(glyph_font(n), math_control_apply_boxed_italic_kern)) {
                                    italic = tex_aux_math_x_size_scaled(glyph_font(n), tex_char_italic_from_font(glyph_font(n), glyph_character(n)), size);
                                }
                            }
                            n = node_next(n);
                        }
                    } else {
                        /*tex This might need checking. */
                        while (n) {
                            if (node_type(n) == fence_noad && noad_italic(n) > italic) {
                                /*tex we can have dummies, the period ones */
                                italic = tex_aux_math_given_x_scaled(noad_italic(n));
                            }
                            n = node_next(n);
                        }
                    }
                    break;
                }
            case math_char_node:
                {
                    halfword fnt = tex_fam_fnt(kernel_math_family(nucleus), size);
                    halfword chr = kernel_math_character(nucleus);
                    italic = tex_aux_math_x_size_scaled(fnt, tex_char_italic_from_font(fnt, chr), size);
                    break;
                }
        }
    }
    /*tex We're still doing limits. */
    if (noad_supscr(target) || noad_subscr(target)) {
        scaled supwidth = box_width(superscript);
        scaled boxwidth = box_width(kernel);
        scaled subwidth = box_width(subscript);
        scaled halfitalic = tex_half_scaled(italic);
        halfword topshift = halfitalic;
        halfword bottomshift = halfitalic; 
        if (kerns && ! halfitalic) { 
            halfword fnt = kerns->font;
            halfword chr = kerns->character;
            if (fnt && chr) { 
                scaled t = tex_aux_math_x_size_scaled(fnt, tex_char_top_anchor_from_font(fnt, chr), size);
                scaled b = tex_aux_math_x_size_scaled(fnt, tex_char_bottom_anchor_from_font(fnt, chr), size);
                if (t) { 
                    topshift = t - boxwidth;
                }
                if (b) {    
                    bottomshift = boxwidth - b;
                }
            }
        }
        box_width(result) = boxwidth;
        if (supwidth > boxwidth) {
            boxwidth = supwidth;
        }
        if (subwidth > boxwidth) {
            boxwidth = subwidth;
        }
        box_width(result) = boxwidth;
        superscript = tex_aux_rebox(superscript, boxwidth, size);
        kernel = tex_aux_rebox(kernel, boxwidth, size);
        subscript = tex_aux_rebox(subscript, boxwidth, size);
        /*tex This is only (visually) ok for integrals, but other operators have no italic anyway. */
        box_shift_amount(superscript) = topshift;
        box_shift_amount(subscript) = -bottomshift;
        if (math_limits_mode_par >= 1) {
            /*tex
                This option enforces the real dimensions and avoids longer limits to stick out
                which is a traditional \TEX\ feature. It's handy to have this for testing. Nicer
                would be to also adapt the width of the wrapped scripts but these are reboxed
                with centering so we keep that as it is.
            */
            if (supwidth + topshift > boxwidth) {
                box_width(result) += supwidth + topshift - boxwidth;
            }
            if (subwidth + bottomshift > boxwidth) {
                box_x_offset(result) = subwidth + bottomshift - boxwidth;
                box_width(result) += box_x_offset(result);
                tex_set_box_geometry(result, offset_geometry);
            }
        } else {
            /*tex We keep the possible left and/or right overshoot of limits. */
        }
        /*tex Here the target |v| is still empty but we do set the height and depth. */
        box_height(result) = box_height(kernel);
        box_depth(result) = box_depth(kernel);
    } else { 
        box_width(result) = box_width(kernel);
        box_height(result) = box_height(kernel);
        box_depth(result) = box_depth(kernel);
    }
    /*tex

        Attach the limits to |y| and adjust |height(v)|, |depth(v)| to account for
        their presence.

        We use |shift_up| and |shift_down| in the following program for the amount of
        glue between the displayed operator |y| and its limits |x| and |z|.

        The vlist inside box |v| will consist of |x| followed by |y| followed by |z|,
        with kern nodes for the spaces between and around them; |b| is baseline and |v|
        is the minumum gap.

    */
    if (noad_supscr(target)) { 
        scaled bgap = tex_get_math_y_parameter_checked(style, math_parameter_limit_above_bgap);
        scaled vgap = tex_get_math_y_parameter_checked(style, math_parameter_limit_above_vgap);
        scaled vkern = tex_get_math_y_parameter_checked(style, math_parameter_limit_above_kern);
        scaled vshift = bgap - box_depth(superscript);
        if (vshift < vgap) {
            vshift = vgap;
        }
        if (vshift) {
            halfword kern = tex_new_kern_node(vshift, vertical_math_kern_subtype);
            tex_attach_attribute_list_copy(kern, target);
            tex_couple_nodes(kern, kernel);
            tex_couple_nodes(superscript, kern);
        } else {
            tex_couple_nodes(kernel, superscript);
        }
        if (vkern) {
            halfword kern = tex_new_kern_node(vkern, vertical_math_kern_subtype);
            tex_attach_attribute_list_copy(kern, target);
            tex_couple_nodes(kern, superscript);
            box_list(result) = kern;
        } else {
            box_list(result) = superscript;
        }
        box_height(result) += vkern + box_total(superscript) + vshift;
    } else {
        box_list(superscript) = null;
        tex_flush_node(superscript);
        box_list(result) = kernel;
    }
    if (noad_subscr(target)) {
        scaled bgap = tex_get_math_y_parameter_checked(style, math_parameter_limit_below_bgap);
        scaled vgap = tex_get_math_y_parameter_checked(style, math_parameter_limit_below_vgap);
        scaled vkern = tex_get_math_y_parameter_checked(style, math_parameter_limit_below_kern);
        scaled vshift = bgap - box_height(subscript);
        if (vshift < vgap) {
            vshift = vgap;
        }
        if (vshift) {
            halfword kern = tex_new_kern_node(vshift, vertical_math_kern_subtype);
            tex_attach_attribute_list_copy(kern, target);
            tex_couple_nodes(kernel, kern);
            tex_couple_nodes(kern, subscript);
        } else {
            tex_couple_nodes(kernel, subscript);
        }
        if (vkern) {
            halfword kern = tex_new_kern_node(vkern, vertical_math_kern_subtype);
            tex_attach_attribute_list_copy(kern, target);
            tex_couple_nodes(subscript, kern);
        }
        box_depth(result) += vkern + box_total(subscript) + vshift;
    } else {
        box_list(subscript) = null;
        tex_flush_node(subscript);
    }
    if (noad_subscr(target)) {
        kernel_math_list(noad_subscr(target)) = null;
        tex_flush_node(noad_subscr(target));
        noad_subscr(target) = null;
    }
    if (noad_supscr(target)) {
        kernel_math_list(noad_supscr(target)) = null;
        tex_flush_node(noad_supscr(target));
        noad_supscr(target) = null;
    }
    tex_aux_assign_new_hlist(target, result);
 // italic = 0;
    return 0;
}

/*tex 
    The adapt to left or right is sort of fuzzy and might disappear in future versions. After all, 
    we have more fance fence support now. 
*/

static scaled tex_aux_op_wrapup(halfword target, int style, int size, int italic, kernset *kerns, int forceitalics)
{
    halfword box;
    int shiftaxis = 0;
    halfword chr = null;
    halfword fnt = null;
    halfword autoleft = null;
    halfword autoright = null;
    halfword autosize = has_noad_option_auto(target);
    scaled openupheight = has_noad_option_openupheight(target) ? noad_height(target) : 0;
    scaled openupdepth = has_noad_option_openupdepth(target) ? noad_depth(target) : 0;
    (void) kerns;
    if (has_noad_option_adapttoleft(target) && node_prev(target)) {
        autoleft = node_prev(target);
        if (node_type(autoleft) != simple_noad) {
            autoleft = null;
        } else {
            autoleft = noad_new_hlist(autoleft);
        }
    }
    if (has_noad_option_adapttoright(target) && node_next(target)) {
        /* doesn't always work well */
        autoright = noad_nucleus(node_next(target));
    }
    tex_aux_fetch(noad_nucleus(target), "operator", &fnt, &chr);
    /*tex Nicer is actually to just test for |display_style|. */
    if ((style < text_style) || autoleft || autoright || autosize) {
        /*tex Try to make it larger in displaystyle. */
        scaled opsize = tex_get_math_parameter(style, math_parameter_operator_size, NULL);
        if ((autoleft || autoright || autosize) && (opsize == undefined_math_parameter)) {
            opsize = 0;
        }
        if (opsize != undefined_math_parameter) {
            /*tex Creating a temporary delimiter is the cleanest way. */
            halfword y = tex_new_node(delimiter_node, 0);
            tex_attach_attribute_list_copy(y, noad_nucleus(target));
            delimiter_small_family(y) = kernel_math_family(noad_nucleus(target));
            delimiter_small_character(y) = kernel_math_character(noad_nucleus(target));
            opsize = tex_aux_math_y_scaled(opsize, style);
            if (autoright) {
                /*tex We look ahead and preroll, |autoright| is a noad. */
                scaledwhd siz = tex_natural_hsizes(autoright, null, 0.0, 0, 0);
                scaled total = siz.ht + siz.dp;
                if (total > opsize) {
                    opsize = total;
                }
            }
            if (autoleft && box_total(autoleft) > opsize) {
                /*tex We look back and check, |autoleft| is a box. */
                opsize = box_total(autoleft);
            }
            /* we need to check for overflow here */
            opsize += limited_scaled(openupheight);
            opsize += openupdepth;
            box = tex_aux_make_delimiter(target, y, text_size, opsize, 0, style, ! has_noad_option_noaxis(target), NULL, &italic, 0, has_noad_option_nooverflow(target), NULL, 0);
        } else {
            /*tex
                Where was the weird + 1 coming from? It tweaks the comparison. Anyway, because we
                do a lookup we don't need to scale the |total| and |opsize|. We have a safeguard
                against endless loops.
            */
            opsize = tex_char_total_from_font(fnt, chr) + openupheight + openupdepth + 1;
            /*
            if (opsize) {
                opsize = tex_aux_math_y_style_scaled(fnt, opsize, size); // we compare unscaled
            }
            */
            while (tex_char_has_tag_from_font(fnt, chr, list_tag) && tex_char_total_from_font(fnt, chr) < opsize) {
                halfword next = tex_char_next_from_font(fnt, chr);
                if (chr != next && tex_char_exists(fnt, next)) {
                    chr = next;
                    kernel_math_character(noad_nucleus(target)) = chr;
                } else {
                    break;
                }
            }
            if (math_kernel_node_has_option(noad_nucleus(target), math_kernel_no_italic_correction) && ! forceitalics) {
                italic = 0;
            } else { 
                italic = tex_aux_math_x_size_scaled(fnt, tex_char_italic_from_font(fnt, chr), size);
            }
            box = tex_aux_clean_box(noad_nucleus(target), style, style, math_nucleus_list, 0, NULL);
            shiftaxis = 1;
        }
    } else {
        /*tex Non display style. */
        italic = tex_aux_math_x_size_scaled(fnt, tex_char_italic_from_font(fnt, chr), size);
        box = tex_aux_clean_box(noad_nucleus(target), style, style, math_nucleus_list, 0, NULL);
        box_height(box) += openupheight;
        box_depth(box) += openupdepth;
        shiftaxis = 1;
    }
    if (shiftaxis) {
        /*tex center vertically */
        box_shift_amount(box) = tex_half_scaled(box_height(box) - box_depth(box)) - tex_aux_math_axis(size);
    }
    if ((node_type(box) == hlist_node) && (openupheight || openupdepth)) {
        box_shift_amount(box) -= openupheight/2;
        box_shift_amount(box) += openupdepth/2;
    }
    if (forceitalics && italic && box_list(box)) { 
        /*tex 
            This features is provided in case one abuses operators in weird ways and expects italic 
            correction to be part of the width. Maybe it should be an kernel option so that it can 
            be controlled locally. Now here we enter fuzzy specification teritory. For n-ary 
            operators we are supposed to use the italic correction for placements of vertical and 
            horizontal scripts (limits an nolimits) but when we patch the width that gets messy (we
            now need to need to backtrack twice times half the correction). The bad news is that 
            there is no way to see if we have a n-ary unless we add a new class and only for the 
            lone slanted integrals in lm. So, instead we just zero the correction now. After all, 
            we can use a fence instead for these n-ary's. Actually there are probably not that many 
            slanted operators, so it' smore about using a letter as such. So, |italiic *= 2| became 
            |italic = 0|. 
        */
        tex_aux_math_insert_italic_kern(tex_tail_of_node_list(box_list(box)), italic, noad_nucleus(target), "operator");
        box_width(box) += italic;
        italic = 0;
    }
    node_type(noad_nucleus(target)) = sub_box_node;
    kernel_math_list(noad_nucleus(target)) = box;
    return italic;
}

static scaled tex_aux_make_op(halfword target, int style, int size, int italic, int limits_mode, kernset *kerns)
{
    int forceitalics = node_subtype(target) == operator_noad_subtype && tex_math_has_class_option(operator_noad_subtype, operator_italic_correction_class_option);
    if (limits_mode == limits_horizontal_mode) {
        /*tex We enforce this and it can't be overruled! */
    } else if (! has_noad_option_limits(target) && ! has_noad_option_nolimits(target) && (style == display_style || style == cramped_display_style)) {
        limits_mode = limits_vertical_mode;
        noad_options(target) |= noad_option_limits; /* so we can track it */
    } else if (has_noad_option_nolimits(target)) { 
        limits_mode = limits_horizontal_mode;
    } else if (has_noad_option_limits(target)) { 
        limits_mode = limits_vertical_mode;
    }
    if (node_type(noad_nucleus(target)) == math_char_node) {
        italic = tex_aux_op_wrapup(target, style, size, italic, kerns, forceitalics);
    }
    switch (limits_mode) {
        case limits_horizontal_mode: 
            /*tex
                We end up here when there is an explicit directive or when we're in displaymode without
                an explicit directive. If in text mode we want to have this mode driven placement tweak
                we need to use the |\nolimits| directive. Beware: that mode might be changed to a font
                property or option itself.
            */
            return tex_aux_op_no_limits(target, style, size, italic, kerns, forceitalics); /* italic becomes zero */
        case limits_vertical_mode:
            /*tex

                We end up here when we have a limits directive or when that property is set because
                we're in displaymode. The following program builds a vlist box |v| for displayed limits. 
                The width of the box is not affected by the fact that the limits may be skewed.
            */
            return tex_aux_op_do_limits(target, style, size, italic, kerns, forceitalics); /* italic becomes zero */
        default:
            /*tex
                We end up here when we're not in displaymode and don't have a (no)limits directive. 
                When called the wrong way we loose the nucleus. 
            */
            return italic; /* italic is retained, happens very seldom */
    }
}

/*tex

    A ligature found in a math formula does not create a ligature, because there is no question of
    hyphenation afterwards; the ligature will simply be stored in an ordinary |glyph_node|, after
    residing in an |ord_noad|.

    The |type| is converted to |math_text_char| here if we would not want to apply an italic
    correction to the current character unless it belongs to a math font (i.e., a font with
    |space=0|).

    No boundary characters enter into these ligatures.

*/

// $ \mathord {a}  $ : ord -> nucleus -> mathchar 
// $ \mathord {ab} $ : ord -> nucleus -> submlist -> ord + ord 

/*tex 
    Have there ever been math fonts with kerns and ligatures? If so it had to be between characters
    within the same font. Maybe this was meant for composed charaters? And the 256 limits of the 
    number of characters didn't help either. This is why we take the freedom to do things a bit 
    different.

    We don't have other kerns in opentype math fonts. There are however these staircase kerns that 
    are dealt with elsewhere. But for new math fonts we do need to add italic correction occasionally
    and staircase kerns only happen with scripts. 

    We could add support for ligatures but we don't need those anyway so it's a waste of time and 
    bytes. 

    The ord checker kicks in after every ord but we can consider a special version where we handle 
    |sub_list_node| noads.  And we could maybe check on sloped shapes but then we for sure end up 
    in a mess we don't want. 

*/

static halfword tex_aux_check_ord(halfword current, halfword size, halfword next)
{
    if (! noad_has_following_scripts(current)) { 
        halfword nucleus = noad_nucleus(current); 
        switch (node_type(nucleus)) { 
        case sub_mlist_node: 
            { 
             // I'm not that motivated for this and it should be an engine option anyway then.
             //
             // halfword head = math_list(nucleus);
             // halfword tail = tex_tail_of_node_list(head);
             // // doesn't work 
             // if (node_type(head) == simple_noad && node_prev(current) ) {
             //     if (node_type(node_prev(current)) == simple_noad) {
             //         head = tex_aux_check_ord(node_prev(current), size, head);
             //         math_list(nucleus) = head;
             //     }
             // }
             // // works 
             // if (node_type(tail) == simple_noad && node_next(current) ) {
             //     tex_aux_check_ord(tail, size, node_next(current));
             // }
                break;
            }
        case math_char_node: 
            {
                halfword curchr = null;
                halfword curfnt = null;
                if (! next) { 
                    next = node_next(current);
                }
                tex_aux_fetch(nucleus, "ordinal", &curfnt, &curchr);
                if (curfnt && curchr) {
                    halfword kern = 0;
                    halfword italic = 0;
                    if (next) {
                        halfword nxtnucleus = noad_nucleus(next); 
                        halfword nxtfnt = null;
                        halfword nxtchr = null;
                        if (node_type(nxtnucleus) == math_char_node && kernel_math_family(nucleus) == kernel_math_family(nxtnucleus)) {
                            tex_aux_fetch(nxtnucleus, "ordinal", &nxtfnt, &nxtchr);
                            if (nxtfnt && nxtchr) {
                                halfword mainclass = node_subtype(current);
                                /* todo: ligatures */
                                if (tex_aux_math_engine_control(curfnt, math_control_apply_ordinary_kern_pair)) {
                                    if (math_kernel_node_has_option(nucleus, math_kernel_no_right_pair_kern) || math_kernel_node_has_option(nxtnucleus, math_kernel_no_left_pair_kern)) {
                                        /* ignore */
                                    } else if (tex_math_has_class_option(mainclass, check_italic_correction_class_option)) {
                                        /* ignore */
                                    } else if (tex_aux_math_engine_control(curfnt, math_control_apply_ordinary_italic_kern)) { 
                                        kern = tex_aux_math_x_size_scaled(curfnt, tex_get_kern(curfnt, curchr, nxtchr), size);
                                    }
                                }
                                if (tex_aux_math_engine_control(curfnt, math_control_apply_ordinary_italic_kern)) {
                                    if (math_kernel_node_has_option(nucleus, math_kernel_no_italic_correction)) {
                                        /* ignore */
                                    } else if (tex_math_has_class_option(mainclass, check_kern_pair_class_option)) {
                                        /* ignore */
                                    } else if (tex_aux_math_engine_control(curfnt, math_control_apply_ordinary_italic_kern)) { 
                                        italic = tex_aux_math_x_size_scaled(curfnt, tex_char_italic_from_font(curfnt, curchr), size);
                                    }
                                }
                            }
                        }
                    }
                    if (kern) {
                        current = tex_aux_math_insert_font_kern(current, kern, current, "ord");
                    }
                    if (italic) {
                        // todo : after last unless upright but then we need to signal
                        current = tex_aux_math_insert_italic_kern(current, italic, current, "ord");
                    }
                }
            }
            break;
        }
    }
    return current;
}

static halfword tex_aux_prepend_hkern_to_new_hlist(halfword box, scaled delta, halfword subtype, const char *trace)
{
    halfword list = noad_new_hlist(box);
    halfword kern = tex_new_kern_node(delta, (quarterword) subtype);
    tex_attach_attribute_list_copy(kern, box);
    if (list) {
        tex_couple_nodes(kern, list);
    }
    list = kern;
    noad_new_hlist(box) = list;
    tex_aux_trace_kerns(kern, "adding kern", trace);
    return list;
}

static void tex_aux_append_hkern_to_box_list(halfword box, scaled delta, halfword subtype, const char *trace)
{
    halfword list = box_list(box);
    halfword kern = tex_new_kern_node(delta, (quarterword) subtype);
    tex_attach_attribute_list_copy(kern, box);
    if (list) {
        tex_couple_nodes(tex_tail_of_node_list(list), kern);
    } else {
        list = kern;
    }
    box_list(box) = list;
    box_width(box) += delta;
    tex_aux_trace_kerns(kern, "adding kern", trace);
}

static void tex_aux_prepend_hkern_to_box_list(halfword box, scaled delta, halfword subtype, const char *trace)
{
    halfword list = box_list(box);
    halfword kern = tex_new_kern_node(delta, (quarterword) subtype);
    tex_attach_attribute_list_copy(kern, box);
    if (list) {
        tex_couple_nodes(kern, list);
    }
    list = kern;
    box_list(box) = list;
    box_width(box) += delta;
    tex_aux_trace_kerns(kern, "adding kern", trace);
}

/*tex

    The purpose of |make_scripts (q, it)| is to attach the subscript and/or superscript of noad |q|
    to the list that starts at |new_hlist (q)|, given that subscript and superscript aren't both
    empty. The superscript will be horizontally shifted over |delta1|, the subscript over |delta2|.

    We set |shift_down| and |shift_up| to the minimum amounts to shift the baseline of subscripts
    and superscripts based on the given nucleus.

    Note: We need to look at a character but also at the first one in a sub list and there we
    ignore leading kerns and glue. Elsewhere is code that removes kerns assuming that is italic
    correction. The heuristics are unreliable for the new fonts so eventualy there will be an
    option to ignore such corrections. (We now actually have that level of control.)

    Instead of a few mode parameters we now control this via the control options bitset. In this 
    case we cheat a bit as there is no relationship with a font (the first |null| parameter that 
    gets passed here). In the archive we can find all the variants. 

*/

static halfword tex_aux_analyze_script(halfword init, scriptdata *data)
{
    if (init) {
        switch (node_type(init)) {
            case math_char_node :
                if (tex_aux_math_engine_control(null, math_control_analyze_script_nucleus_char)) {
                    if (tex_aux_fetch(init, "script char", &(data->fnt), &(data->chr))) {
                        return init;
                    } else {
                        goto NOTHING;
                    }
                } else {
                    break;
                }
            case sub_mlist_node:
                if (tex_aux_math_engine_control(null, math_control_analyze_script_nucleus_list)) {
                    init = kernel_math_list(init);
                    while (init) {
                        switch (node_type(init)) {
                            case kern_node:
                            case glue_node:
                                init = node_next(init);
                                break;
                            case simple_noad:
                                {
                                    init = noad_nucleus(init);
                                    if (node_type(init) != math_char_node) {
                                        return null;
                                    } else if (tex_aux_fetch(init, "script list", &(data->fnt), &(data->chr))) {
                                        return init;
                                    } else {
                                        goto NOTHING;
                                    }
                                }
                            default:
                                goto NOTHING;
                        }
                    }
                }
                break;
            case sub_box_node:
                if (tex_aux_math_engine_control(null, math_control_analyze_script_nucleus_box)) {
                    init = kernel_math_list(init);
                    if (init && node_type(init) == hlist_node) {
                        init = box_list(init);
                    }
                    while (init) {
                        switch (node_type(init)) {
                            case kern_node:
                            case glue_node:
                                init = node_next(init);
                                break;
                            case glyph_node:
                                if (tex_aux_fetch(init, "script box", &(data->fnt), &(data->chr))) {
                                    return init;
                                } else {
                                    goto NOTHING;
                                }
                            default:
                                goto NOTHING;
                        }
                    }
                }
                break;
        }
    }
  NOTHING:
    data->fnt = null;
    data->chr = null;
    return null;
}

/*tex

    These prescripts are kind of special. For instance, should top and bottom scripts be aligned?
    When there is are two top or two bottom, should we then just use the maxima? Watch out, the 
    implementation changed wrt \LUATEX. 

*/

static void tex_aux_get_math_sup_shifts(halfword target, halfword sup, halfword style, scaled *shift_up)
{
    if (has_noad_option_fixed_super_or_sub_script(target) || has_noad_option_fixed_super_and_sub_script(target)) { 
        *shift_up = tex_get_math_y_parameter_checked(style, math_parameter_superscript_shift_up);
    } else { 
        scaled clr = tex_get_math_y_parameter_checked(style, math_parameter_superscript_shift_up);
        scaled bot = tex_get_math_y_parameter_checked(style, math_parameter_superscript_bottom_min);
        if (*shift_up < clr) {
            *shift_up = clr;
        }
        clr = box_depth(sup) + bot;
        if (*shift_up < clr) {
            *shift_up = clr;
        }
    }
}

static void tex_aux_get_math_sub_shifts(halfword target, halfword sub, halfword style, scaled *shift_down)
{
    if (has_noad_option_fixed_super_or_sub_script(target)) { 
        *shift_down = tex_get_math_y_parameter_checked(style, math_parameter_subscript_shift_down);
    } else if (has_noad_option_fixed_super_and_sub_script(target)) { 
        *shift_down = tex_get_math_y_parameter_checked(style, math_parameter_subscript_superscript_shift_down);
    } else { 
        scaled clr = tex_get_math_y_parameter_checked(style, math_parameter_subscript_shift_down);
        scaled top = tex_get_math_y_parameter_checked(style, math_parameter_subscript_top_max);
        if (*shift_down < clr) {
            *shift_down = clr;
        }
        clr = box_height(sub) - top;
        if (*shift_down < clr) {
            *shift_down = clr;
        }
    }
}

static void tex_aux_get_math_sup_sub_shifts(halfword target, halfword sup, halfword sub, halfword style, scaled *shift_up, scaled *shift_down)
{
    if (has_noad_option_fixed_super_or_sub_script(target)) { 
        *shift_down = tex_get_math_y_parameter_checked(style, math_parameter_subscript_shift_down);
    } else if (has_noad_option_fixed_super_and_sub_script(target)) { 
        *shift_down = tex_get_math_y_parameter_checked(style, math_parameter_subscript_superscript_shift_down);
    } else { 
        scaled clr = tex_get_math_y_parameter_checked(style, math_parameter_subscript_superscript_shift_down);
        scaled gap = tex_get_math_y_parameter_checked(style, math_parameter_subscript_superscript_vgap);
        scaled bot = tex_get_math_y_parameter_checked(style, math_parameter_superscript_subscript_bottom_max);
        if (*shift_down < clr) {
            *shift_down = clr;
        }
        clr = gap - ((*shift_up - box_depth(sup)) - (box_height(sub) - *shift_down));
        if (clr > 0) {
            *shift_down += clr;
            clr = bot - (*shift_up - box_depth(sup));
            if (clr > 0) {
                *shift_up += clr;
                *shift_down -= clr;
            }
        }
    }
}

static halfword tex_aux_combine_script(halfword target, halfword width, halfword pre, halfword post, halfword *k1, halfword *k2)
{
    *k1 = tex_new_kern_node(-(width + box_width(pre)), horizontal_math_kern_subtype);
    *k2 = tex_new_kern_node(width, horizontal_math_kern_subtype);
    tex_couple_nodes(*k1, pre);
    tex_couple_nodes(pre, *k2);
    if (post) {
        tex_couple_nodes(*k2, post);
    }
    post = tex_hpack(*k1, 0, packing_additional, direction_unknown, holding_none_option);
    tex_attach_attribute_list_copy(*k1, target);
    tex_attach_attribute_list_copy(*k2, target);
    tex_attach_attribute_list_copy(post, target);
    node_subtype(post) = math_pre_post_list;
    return post;
}

 /*tex

    The following steps are involved:

    We look at the subscript character (_i) or first character in a list (_{ij}). We look at the
    superscript character (^i) or first character in a list (^{ij}).

    Construct a superscript box |x|. The bottom of a superscript should never descend below the
    baseline plus one-fourth of the x-height.

    Construct a sub/superscript combination box |x|, with the superscript offset by |delta|. When
    both subscript and superscript are present, the subscript must be separated from the superscript
    by at least four times |preset_rule_thickness|. If this condition would be violated, the
    subscript    moves down, after which both subscript and superscript move up so that the bottom
    of the superscript is at least as high as the baseline plus four-fifths of the x-height.

    Now the horizontal shift for the superscript; the superscript is also to be shifted by |delta1|
    (the italic correction).

    Construct a subscript box |x| when there is no superscript. When there is a subscript without
    a superscript, the top of the subscript should not exceed the baseline plus four-fifths of the
    x-height.

    We start with some helpers that deal with the staircase kerns in \OPENTYPE\ math.

*/

/*tex

    This function tries to find the kern needed for proper cut-ins. The left side doesn't move, but
    the right side does, so the first order of business is to create a staggered fence line on the
    left side of the right character.

    If the fonts for the left and right bits of a mathkern are not both new-style fonts, then return
    a sentinel value meaning: please use old-style italic correction placement

    This code is way to complex as it evolved stepwise and we wanted to keep the post scripts code
    more or less the same. but ... I'll redo it.

*/

static scaled tex_aux_math_kern_at(halfword fnt, int chr, int side, int value)
{
    /*tex We know that the character exists. */
    charinfo *ci = tex_get_charinfo(fnt, chr);
    if (ci->math) {
        scaled *kerns_heights;
        int n_of_kerns = tex_get_charinfo_math_kerns(ci, side);
        if (n_of_kerns == 0) {
            switch (side) {
                case top_left_kern:
                    return tex_char_top_left_kern_from_font(fnt, chr);
                case bottom_left_kern:
                    return tex_char_bottom_left_kern_from_font(fnt, chr);
                case top_right_kern:
                    return tex_char_top_right_kern_from_font(fnt, chr);
                case bottom_right_kern:
                    return tex_char_bottom_right_kern_from_font(fnt, chr);
                default:
                    return 0;
            }
        } else {
            switch (side) {
                case top_left_kern:
                    kerns_heights = ci->math->top_left_math_kern_array;
                    break;
                case bottom_left_kern:
                    kerns_heights = ci->math->bottom_left_math_kern_array;
                    break;
                case top_right_kern:
                    kerns_heights = ci->math->top_right_math_kern_array;
                    break;
                case bottom_right_kern:
                    kerns_heights = ci->math->bottom_right_math_kern_array;
                    break;
                default:
                    /*tex Not reached: */
                    kerns_heights = NULL;
                    return tex_confusion("math kern at");
            }
        }
        if (value < kerns_heights[0]) {
            return kerns_heights[1];
        } else {
            scaled kern = 0;
            for (int i = 0; i < n_of_kerns; i++) {
                scaled height = kerns_heights[i * 2];
                kern = kerns_heights[(i * 2) + 1];
                if (height > value) {
                    return kern;
                }
            }
            return kern;
        }
    } else {
        return 0;
    }
}

inline static scaled tex_aux_max_left_kern_value(scaled *kerns, int n)
{
    if (kerns && n > 0) {
        scaled kern = 0;
        for (int i = 0; i < n; i++) {
            scaled value = kerns[(i * 2) + 1];
            if (value < kern) {
                kern = value;
            }
        }
        return -kern;
    } else {
        return 0;
    }
}

static scaled tex_aux_math_left_kern(halfword fnt, int chr)
{
    charinfo *ci = tex_get_charinfo(fnt, chr);
    if (ci->math) {
        scaled top = 0;
        scaled bot = 0;
        { 
            scaled *a = ci->math->top_left_math_kern_array;
            halfword n = a ? tex_get_charinfo_math_kerns(ci, top_left_kern) : 0;
            if (n) { 
                top = tex_aux_max_left_kern_value(a, n);
            } else { 
                top = tex_char_top_left_kern_from_font(fnt, chr);
            }
        }
        { 
            scaled *a = ci->math->bottom_left_math_kern_array;
            halfword n = a ? tex_get_charinfo_math_kerns(ci, bottom_left_kern) : 0;
            if (n) { 
                bot = tex_aux_max_left_kern_value(a, n);
            } else { 
                bot = tex_char_bottom_left_kern_from_font(fnt, chr);
            }
        }
        return top > bot ? top : bot;
    } else {
        return 0;
    }
}

/*

inline static scaled tex_aux_max_right_kern_value(scaled *kerns, int n)
{
    if (kerns && n > 0) {
        scaled kern = 0;
        for (int i = 0; i < n; i++) {
            scaled value = kerns[(i * 2) + 1];
            if (value > kern) {
                kern = value;
            }
        }
        return kern;
    } else {
        return 0;
    }
}

static scaled tex_aux_math_right_kern(halfword fnt, int chr)
{
    charinfo *ci = tex_get_charinfo(fnt, chr);
    if (ci->math) {
        scaled top = 0;
        scaled bot = 0;
        { 
            scaled *a = ci->math->top_right_math_kern_array;
            halfword n = a ? tex_get_charinfo_math_kerns(ci, top_right_kern) : 0;
            if (n) { 
                top = tex_aux_max_right_kern_value(a, n);
            } else { 
                top = tex_char_top_right_kern_from_font(fnt, chr);
            }
        }
        { 
            scaled *a = ci->math->bottom_right_math_kern_array;
            halfword n = a ? tex_get_charinfo_math_kerns(ci, bottom_right_kern) : 0;
            if (n) { 
                bot = tex_aux_max_right_kern_value(a, n);
            } else { 
                bot = tex_char_bottom_right_kern_from_font(fnt, chr);
            }
        }
        return top > bot ? top : bot;
    } else {
        return 0;
    }
}
*/

static scaled tex_aux_find_math_kern(halfword l_f, int l_c, halfword r_f, int r_c, int cmd, scaled shift, int *found)
{
    if (tex_aux_math_engine_control(l_f, math_control_staircase_kern) &&
        tex_aux_math_engine_control(r_f, math_control_staircase_kern) &&
     /* tex_aux_has_opentype_metrics(l_f) && tex_aux_has_opentype_metrics(r_f) && */
        tex_char_exists(l_f, l_c) && tex_char_exists(r_f, r_c)) {
        scaled krn_l = 0;
        scaled krn_r = 0;
        scaled krn = 0;
        switch (cmd) {
            case superscript_cmd:
                /*tex bottom of superscript */
                {
                    scaled corr_height_top = tex_char_height_from_font(l_f, l_c);
                    scaled corr_height_bot = -tex_char_depth_from_font(r_f, r_c) + shift;
                    krn_l = tex_aux_math_kern_at(l_f, l_c, top_right_kern, corr_height_top);
                    krn_r = tex_aux_math_kern_at(r_f, r_c, bottom_left_kern, corr_height_top);
                    krn = krn_l + krn_r;
                    krn_l = tex_aux_math_kern_at(l_f, l_c, top_right_kern, corr_height_bot);
                    krn_r = tex_aux_math_kern_at(r_f, r_c, bottom_left_kern, corr_height_bot);
                }
                break;
            case subscript_cmd:
                /*tex top of subscript */
                {
                    scaled corr_height_top = tex_char_height_from_font(r_f, r_c) - shift;
                    scaled corr_height_bot = -tex_char_depth_from_font(l_f, l_c);
                    krn_l = tex_aux_math_kern_at(l_f, l_c, bottom_right_kern, corr_height_top);
                    krn_r = tex_aux_math_kern_at(r_f, r_c, top_left_kern, corr_height_top);
                    krn = krn_l + krn_r;
                    krn_l = tex_aux_math_kern_at(l_f, l_c, bottom_right_kern, corr_height_bot);
                    krn_r = tex_aux_math_kern_at(r_f, r_c, top_left_kern, corr_height_bot);
                }
                break;
            default:
                return tex_confusion("find math kern");
        }
        *found = 1;
        if ((krn_l + krn_r) < krn) {
            krn = krn_l + krn_r;
        }
        return krn ? tex_aux_math_x_size_scaled(l_f, krn, lmt_math_state.size) : 0;
    } else {
        return MATH_KERN_NOT_FOUND;
    }
}

static int tex_aux_get_sup_kern(halfword kernel, scriptdata *sup, scaled shift_up, scaled supshift, scaled *supkern, kernset *kerns)
{
    int found = 0;
    *supkern = MATH_KERN_NOT_FOUND;
    if (sup->node) {
        *supkern = tex_aux_find_math_kern(glyph_font(kernel), glyph_character(kernel), sup->fnt, sup->chr, superscript_cmd, shift_up, &found);
        if (*supkern == MATH_KERN_NOT_FOUND) {
            *supkern = supshift;
        } else {
            if (*supkern) {
                tex_aux_trace_kerns(*supkern, "superscript kern", "regular");
            }
            *supkern += supshift;
        }
        return found;
    }
    if (kerns && kerns->topright) {
        *supkern = kerns->topright; 
        if (*supkern == MATH_KERN_NOT_FOUND) {
            *supkern = supshift;
        } else {
            if (*supkern) {
                tex_aux_trace_kerns(*supkern, "superscript kern", "kernset top right");
            }
            *supkern += supshift;
        }
        return found;
    }
    *supkern = supshift;
    return found;
}

static int tex_aux_get_sub_kern(halfword kernel, scriptdata *sub, scaled shift_down, scaled subshift, scaled *subkern, kernset *kerns)
{
    int found = 0;
    *subkern = MATH_KERN_NOT_FOUND;
    if (sub->node) {
        *subkern = tex_aux_find_math_kern(glyph_font(kernel), glyph_character(kernel), sub->fnt, sub->chr, subscript_cmd, shift_down, &found);
        if (*subkern == MATH_KERN_NOT_FOUND) {
            *subkern = subshift;
        } else {
            if (*subkern) {
                tex_aux_trace_kerns(*subkern, "subscript kern", "regular");
            }
            *subkern += subshift;
        }
        return found;
    }
    if (kerns && kerns->bottomright) {
        *subkern = kerns->bottomright; 
        if (*subkern == MATH_KERN_NOT_FOUND) {
            *subkern = subshift;
        } else {
            if (*subkern) {
                tex_aux_trace_kerns(*subkern, "superscript kern", "kernset bottom right");
            }
            *subkern += subshift;
        }
        return found;
    }
    *subkern = subshift;
    return found;
}

/*tex

    The code is quite ugly because these staircase kerns can only be calculated when we know the
    heights and depths but when we pack the pre/post scripts we already relatiev position them so
    we need to manipulate kerns. I need to figure out why we have slight rounding errors in the
    realignments of prescripts. Anyway, because prescripts are not really part of \TEX\ we have
    some freedom in dealing with them.

    This code is now a bit too complex due to some (probably by now) redundant analysis so at some
    point I will rewrite it. Anyway, normally we don't end up in the next one because italic 
    correction already has been dealt with and thereby is zerood. In fact, if we end up here I need 
    to check why! 

*/

inline static scaled tex_aux_insert_italic_now(halfword target, halfword kernel, scaled italic)
{
    switch (node_type(noad_nucleus(target))) {
        case math_char_node:
        case math_text_char_node:
            {
                halfword fam = kernel_math_family(noad_nucleus(target));
                if (fam != unused_math_family) {
                    halfword fnt = tex_fam_fnt(fam, lmt_math_state.size);
                    if (! tex_aux_math_engine_control(fnt, math_control_apply_script_italic_kern)) {
                        /*tex We ignore the correction. */
                        italic = 0;
                    } else if (noad_subscr(target)) {
                        /*tex We will add the correction before the superscripts and/or primes. */
                    } else { 
                        /*tex We can add the correction the kernel and then forget about it. */
                        tex_aux_math_insert_italic_kern(kernel, italic, noad_nucleus(target), "scripts");
                        italic = 0;
                    }
                } else {
                    /*tex We have a weird case, so we ignore the correction. */
                    italic = 0;
                }
            }
            break;
    }
    return italic;
}

inline static int tex_aux_raise_prime_composed(halfword target)
{
    int mainclass = -1 ; 
    /* maybe also mainclass */
    switch (node_type(target)) {
        case simple_noad: 
            mainclass = node_subtype(target);
            break;
        case radical_noad:
            mainclass = radical_noad_subtype;
            break;
        case fraction_noad:
            mainclass = fraction_noad_subtype;
            break;
        case accent_noad:
            mainclass = accent_noad_subtype; 
            break;
        case fence_noad:
            /* we could be more granular and do open / close nut for now assume symmetry */
            mainclass = fenced_noad_subtype;                
            break;
    }
    return mainclass >= 0 ? tex_math_has_class_option(mainclass, raise_prime_option) : 0;                
}

static halfword tex_aux_shift_to_kern(halfword target, halfword box, scaled shift)
{
    halfword result; 
    if (box_source_anchor(box)) { 
        halfword kern = tex_new_kern_node(shift, vertical_math_kern_subtype);
        tex_attach_attribute_list_copy(kern, target);
        tex_couple_nodes(kern, box);
        result = tex_vpack(kern, 0, packing_additional, max_dimen, (singleword) math_direction_par, holding_none_option);
        tex_attach_attribute_list_copy(result, target);
        node_subtype(result) = math_scripts_list;
        box_shift_amount(result) = shift;
    } else { 
        box_shift_amount(box) = shift;
        result = box;
    }
    return result;
}

static void tex_aux_make_scripts(halfword target, halfword kernel, scaled italic, int style, scaled supshift, scaled subshift, scaled supdrop, kernset *kerns)
{
    halfword result = null;
    halfword preresult = null;
    scaled prekern = 0;
    scaled primekern = 0;
    scaled shift_up = 0;
    scaled shift_down = 0;
    scaled prime_up = 0;
    scriptdata postsubdata = { .node = null, .fnt = null_font, .chr = 0, .box = null, .kern = null, .slack = 0, .shifted = 0 };
    scriptdata postsupdata = { .node = null, .fnt = null_font, .chr = 0, .box = null, .kern = null, .slack = 0, .shifted = 0 }; 
    scriptdata presubdata  = { .node = null, .fnt = null_font, .chr = 0, .box = null, .kern = null, .slack = 0, .shifted = 0 };
    scriptdata presupdata  = { .node = null, .fnt = null_font, .chr = 0, .box = null, .kern = null, .slack = 0, .shifted = 0 };
    scriptdata primedata   = { .node = null, .fnt = null_font, .chr = 0, .box = null, .kern = null, .slack = 0, .shifted = 0 };
    halfword maxleftkern = 0;
 // halfword maxrightkern = 0;
    scaled leftslack = 0;
    scaled rightslack = 0;
    scaledwhd kernelsize = { .wd = 0, .ht = 0, .dp = 0, .ic = 0 };
 // scaled primewidth = 0;
    scaled topovershoot = 0;
    scaled botovershoot = 0;
    int italicmultiplier = 1; /* This was a hard coded 2 so it needs more checking! */
    int splitscripts = 0;
    quarterword primestate = prime_unknown_location;
    /*tex 
        This features was added when MS and I found that the Latin Modern (and other) fonts have 
        rather badly configured script (calligraphic) shapes. There is no provision for proper 
        anchoring subscripts and superscripts can overlap with for instance wide accents especially 
        when there is not much granularity in them. For that we now register the overshoot of 
        accents and compensate for them here.

        One assumption is that the shape is somewhat italic and that an overshoot makes it even 
        more so. The two factors default to zero, so it only works when the right parameters are 
        set.  

        It's a mess. By adding more and more and also trying to be a bit like old \TEX\ we now have 
        too many kerns. 

    */
    if (node_type(target) == accent_noad) {
        scaled top = tex_get_math_parameter_default(style, math_parameter_accent_top_overshoot, 0);
        scaled bot = tex_get_math_parameter_default(style, math_parameter_accent_bottom_overshoot, 0);
        topovershoot = scaledround(accent_top_overshoot(target) * top / 100.0);
        botovershoot = scaledround(accent_top_overshoot(target) * bot / 100.0);
    }
    /*tex
        So this is somewhat weird. We pass the kernel and also some italic and then act upon the 
        target again. This is a bit messy side effect of the transition from old to new fonts. We
        also have to make sure that we don't add the correction too soon, that is, before the 
        subscript. 
    */
    if (italic) {
        italic = tex_aux_insert_italic_now(target, kernel, italic);
    }
    /*tex 
        In some cases we need to split the scripts, for instance when we have fenced material that 
        can get split over lines. 
    */
    if (node_type(target) == simple_noad) { 
        switch (node_subtype(target)) { 
            case fenced_noad_subtype: 
                splitscripts = tex_math_has_class_option(fenced_noad_subtype, unpack_class_option);
                break;
            case ghost_noad_subtype: 
                splitscripts = has_noad_option_unpacklist(target);
                break;
        }
    }
    /*tex 
        When we have a single character we need to deal with kerning based on staircase kerns, but 
        we also can have explicit kerns defined with single characters, which is more a \CONTEXT\
        feature as it is not in \OPENTYPE\ fonts.
    */
    tex_aux_assign_new_hlist(target, kernel);
    kernelsize = tex_natural_hsizes(kernel, null, 0.0, 0, 0);
    if (kerns && kerns->dimensions) { 
        if (tex_aux_math_engine_control(kerns->font, math_control_ignore_kern_dimensions)) {
            /* hack for bad xits fence depth */
        } else { 
            if (kerns->height) {
                kernelsize.ht = kerns->height;
            }
            if (kerns->depth) {
                kernelsize.dp = kerns->depth;
            }
        }
    }
    switch (node_type(kernel)) {
        case glyph_node:
            postsubdata.node = tex_aux_analyze_script(noad_subscr(target), &postsubdata);
            postsupdata.node = tex_aux_analyze_script(noad_supscr(target), &postsupdata);
            primedata.node = tex_aux_analyze_script(noad_prime(target), &primedata);
            maxleftkern = tex_aux_math_left_kern(glyph_font(kernel), glyph_character(kernel));
         // maxrightkern = tex_aux_math_right_kern(glyph_font(kernel), glyph_character(kernel));
            prime_up = 0; 
            shift_up = 0; 
            shift_down = 0;
            break;            
        default:
            /*tex Used for optimizing accents. */
            kernelsize.ht -= supdrop; 
            /*tex These parameters are only applied in an assembly (and often some 0.5 .. 1.5 pt on 12pt). */
            prime_up = kernelsize.ht - tex_get_math_y_parameter_default(style, math_parameter_prime_shift_drop, 0);
            shift_up = kernelsize.ht - tex_get_math_y_parameter_checked(style, math_parameter_superscript_shift_drop);
            shift_down = kernelsize.dp + tex_get_math_y_parameter_checked(style, math_parameter_subscript_shift_drop);
            break;
    }
    /*tex
        Next we're doing some analysis, needed because of all these parameters than control horizontal and vertical
        spacing. We start with primes.  
    */
    if (noad_prime(target)) {
        /* todo extra */
        scaled shift = tex_get_math_y_parameter_default(style, math_parameter_prime_shift_up, 0);
        scaled raise = tex_get_math_y_parameter_default(style, tex_aux_raise_prime_composed(target) ? math_parameter_prime_raise_composed : math_parameter_prime_raise, 0);
        scaled distance = tex_get_math_x_parameter_default(style, math_parameter_prime_space_after, 0);
     // scaled width = tex_get_math_x_parameter_default(style, math_parameter_prime_width, 0);
        primedata.box = tex_aux_clean_box(noad_prime(target), (has_noad_option_nosupscript(target) ? style : tex_math_style_variant(style, math_parameter_prime_variant)), style, math_sup_list, 0, NULL);
        box_shift_amount(primedata.box) -= prime_up ? prime_up : shift;
        box_shift_amount(primedata.box) -= scaledround(box_height(primedata.box) * raise / 100.0);
        kernel_math_list(noad_prime(target)) = null;
        tex_flush_node(noad_prime(target));
        noad_prime(target) = null;
        if (noad_supscr(target)) {
            primestate = prime_at_end_location;
        } else if (noad_subscr(target)) {
            primestate = prime_above_sub_location;
        } else {
            primestate = prime_at_begin_location;
        }
        if (distance) {
            tex_aux_append_hkern_to_box_list(primedata.box, distance, horizontal_math_kern_subtype, "prime distance");
        }
        primedata.slack = distance;
        switch (primestate) {
            /* [prime] [super/sub] */
            case prime_at_begin_location:
                {
                    /* supshift ? */
                    tex_aux_get_sup_kern(kernel, &primedata, shift_up, supshift, &primekern, kerns);
                    if (italic) {
                        /* why no injection */
                        primekern += italic;
                        italic = 0;
                    }
                }
                break;
            /* [prime/sub] [super] */
            case prime_above_sub_location:
                {
                    /* supshift ? */
                    tex_aux_get_sup_kern(kernel, &primedata, shift_up, supshift, &primekern, kerns);
                    if (italic) {
                        /* why no injection */
                        primekern += italic;
                        italic = 0;
                    }
                     if (primekern) {
                         tex_aux_prepend_hkern_to_box_list(primedata.box, primekern, math_shape_kern_subtype, "prime kern");
                         /* now width added */
                         primekern = 0; /* added */
                     }
                }
                break;
            /* [super/sub] [prime] */
            case prime_at_end_location:
                {
                    primekern = 0;
                }
                break;
        }
    }
    /*tex 
        Each of the scripts gets treated. Traditionally a super and subscript are looked and and 
        vercially spaced out together which in turn results in the staricase kerns needing that 
        information. Prescripts we handle differently: they are always aligned, so there the 
        maximum kern wins. 
    */
    postsupdata.shifted = noad_supscr(target) && has_noad_option_shiftedsupscript(target);
    postsubdata.shifted = noad_subscr(target) && has_noad_option_shiftedsubscript(target);
    presupdata.shifted = noad_supprescr(target) && has_noad_option_shiftedsupprescript(target);
    presubdata.shifted = noad_subprescr(target) && has_noad_option_shiftedsubprescript(target);
    /* 
        When we have a shifted super or subscript (stored in the prescripts) we don't need to kern
        the super and subscripts. What to do with the shifts?  
    */
    if (noad_supscr(target)) {
        halfword extra = tex_get_math_y_parameter_checked(style, math_parameter_extra_superscript_shift);
        postsupdata.slack = tex_get_math_x_parameter_checked(style, math_parameter_extra_superscript_space);
        postsupdata.slack += tex_get_math_x_parameter_checked(style, math_parameter_space_after_script);
        postsupdata.box = tex_aux_clean_box(noad_supscr(target), (has_noad_option_nosupscript(target) ? style : tex_math_style_variant(style, math_parameter_superscript_variant)), style, math_sup_list, 0, NULL);
        if (extra) {
            box_height(postsupdata.box) += extra;
            box_shift_amount(postsupdata.box) -= extra;
        }
        if (postsupdata.slack) {
            tex_aux_append_hkern_to_box_list(postsupdata.box, postsupdata.slack, horizontal_math_kern_subtype, "post sup slack");
        }
        kernel_math_list(noad_supscr(target)) = null;
        tex_flush_node(noad_supscr(target));
        noad_supscr(target) = null;
    }
    if (noad_subscr(target)) {
        halfword extra = tex_get_math_y_parameter_checked(style, math_parameter_extra_subscript_shift);
        postsubdata.slack = tex_get_math_x_parameter_checked(style, math_parameter_extra_subscript_space);
        postsubdata.slack += tex_get_math_x_parameter_checked(style, math_parameter_space_after_script);
        postsubdata.box = tex_aux_clean_box(noad_subscr(target), (has_noad_option_nosubscript(target) ? style : tex_math_style_variant(style, math_parameter_subscript_variant)), style, math_sub_list, 0, NULL);
        if (extra) {
            box_depth(postsubdata.box) += extra;
            box_shift_amount(postsubdata.box) += extra;
        }
        if (postsubdata.slack) {
            tex_aux_append_hkern_to_box_list(postsubdata.box, postsubdata.slack, horizontal_math_kern_subtype, "post sub slack");
        }
        kernel_math_list(noad_subscr(target)) = null;
        tex_flush_node(noad_subscr(target));
        noad_subscr(target) = null;
    }
    if (noad_supprescr(target)) {
        halfword extra = tex_get_math_y_parameter_checked(style, math_parameter_extra_superprescript_shift);
        presupdata.slack = tex_get_math_x_parameter_checked(style, math_parameter_extra_superprescript_space);
        presupdata.slack += tex_get_math_x_parameter_default(style, math_parameter_space_before_script, 0);
        presupdata.box = tex_aux_clean_box(noad_supprescr(target), (has_noad_option_nosupprescript(target) ? style : tex_math_style_variant(style, math_parameter_superscript_variant)), style, math_sup_list, 0, NULL);
        if (maxleftkern) {
            tex_aux_append_hkern_to_box_list(presupdata.box, maxleftkern, math_shape_kern_subtype, "max left shape");
        }
        if (extra) {
            box_height(presupdata.box) += extra;
            box_shift_amount(presupdata.box) -= extra;
        }
        if (presupdata.slack) {
            tex_aux_prepend_hkern_to_box_list(presupdata.box, presupdata.slack, horizontal_math_kern_subtype, "pre sup slack");
        }
        kernel_math_list(noad_supprescr(target)) = null;
        tex_flush_node(noad_supprescr(target));
        noad_supprescr(target) = null;
    }
    if (noad_subprescr(target)) {
        halfword extra = tex_get_math_y_parameter_checked(style, math_parameter_extra_subprescript_shift);
        presubdata.slack = tex_get_math_x_parameter_checked(style, math_parameter_extra_subprescript_space);
        presubdata.slack += tex_get_math_x_parameter_default(style, math_parameter_space_before_script, 0);
        presubdata.box = tex_aux_clean_box(noad_subprescr(target), (has_noad_option_nosubprescript(target) ? style : tex_math_style_variant(style, math_parameter_subscript_variant)), style, math_sub_list, 0, NULL);
        if (maxleftkern) {
            tex_aux_append_hkern_to_box_list(presubdata.box, maxleftkern, math_shape_kern_subtype, "max left shape");
        }
        if (extra) {
            box_depth(presubdata.box) += extra;
            box_shift_amount(presubdata.box) += extra;
        }
        if (presubdata.slack) {
            tex_aux_prepend_hkern_to_box_list(presubdata.box, presubdata.slack, horizontal_math_kern_subtype, "pre sub slack");
        }
        kernel_math_list(noad_subprescr(target)) = null;
        tex_flush_node(noad_subprescr(target));
        noad_subprescr(target) = null;
    }
    /*tex 
        When we're here, the kerns are in the boxes. We now register the state of scripts in the 
        noad for (optional) later usage. 
    */
    if (presupdata.box) {
        noad_script_state(target) |= pre_super_script_state;
    }
    if (presubdata.box) {
        noad_script_state(target) |= pre_sub_script_state;
    }
    if (postsupdata.box) {
        noad_script_state(target) |= post_super_script_state;
    }
    if (postsubdata.box) {
        noad_script_state(target) |= post_sub_script_state;
    }
    if (primedata.box) {
        noad_script_state(target) |= prime_script_state;
    }
    /* */
    if (primestate == prime_above_sub_location) {
        rightslack = box_width(primedata.box) > box_width(postsubdata.box) ? primedata.slack : postsubdata.slack;
    } else if (postsupdata.box) {
        if (postsubdata.box) {
            /* todo: take deltas */
            rightslack = box_width(postsupdata.box) > box_width(postsubdata.box) ? postsupdata.slack : postsubdata.slack;
        } else {
            rightslack = postsupdata.slack;
        }
    } else if (postsubdata.box) {
        rightslack = postsubdata.slack;
    }

    if (primestate == prime_above_sub_location) {
        halfword list = noad_new_hlist(target);
        if (list) {
            /*tex We want to keep the size for tracing! */
            halfword overshoot = box_width(primedata.box) - box_width(postsubdata.box);
            halfword primebox = tex_hpack(primedata.box, 0, packing_additional, direction_unknown, holding_none_option);
            tex_attach_attribute_list_copy(primebox, primedata.box);
            box_width(primebox) = 0; 
            tex_couple_nodes(tex_tail_of_node_list(list), primebox);
            primedata.box = null; 
            if (overshoot > 0) { 
                tex_aux_append_hkern_to_box_list(postsubdata.box, overshoot, math_shape_kern_subtype, "prime overshoot kern");
            }
        } else {
            list = primedata.box;
        }
        noad_new_hlist(target) = list;
    }

    if (presupdata.box) {
        if (presubdata.box) {
            /* todo: take deltas */
            leftslack = box_width(presupdata.box) > box_width(presubdata.box) ? presupdata.slack : presubdata.slack;
        } else {
            leftslack = presupdata.slack;
        }
    } else if (presubdata.box) {
        leftslack = presubdata.slack;
    }
    switch (primestate) {
        case prime_at_begin_location:
            kernelsize.wd += box_width(primedata.box);
            break;
        case prime_above_sub_location:
            /* only excess */
            break;
    }
    if (postsupdata.box || postsubdata.box) {
        /*tex
            The post scripts determine the shifts. An option can be to use the max of pre/post.
        */
        scaled supkern = 0;
        scaled subkern = 0;
        if (! splitscripts) {
            if (presupdata.box) {
                prekern = box_width(presupdata.box);
                postsupdata.box = tex_aux_combine_script(target, kernelsize.wd, presupdata.box, postsupdata.box, &presupdata.kern, &postsupdata.kern);
                presupdata.box = null;
            }
            if (presubdata.box) {
                // test: what with negative extra kerns and what with a negative width
                if (box_width(presubdata.box) > prekern) {
                    prekern = box_width(presubdata.box);
                }
                postsubdata.box = tex_aux_combine_script(target, kernelsize.wd, presubdata.box, postsubdata.box, &presubdata.kern, &postsubdata.kern);
                presubdata.box = null;
            }
        }
        /*tex 
            We want to retain the kern because it is a visual thing but it could be an option to 
            only add the excess over the shift. We're talking tiny here. 

            We could be clever and deal with combinations of shifted but lets play safe and let
            the user worry about it. The sub index always wins. 
        */
        if (postsubdata.box && postsupdata.shifted) {
            halfword shift = tex_get_math_x_parameter_checked(style, math_parameter_subscript_shift_distance);
            halfword amount = box_width(postsupdata.box) + shift;
            tex_aux_prepend_hkern_to_box_list(postsubdata.box, amount, horizontal_math_kern_subtype, "post shifted");
        } else if (postsupdata.box && postsubdata.shifted) {
            halfword shift = tex_get_math_x_parameter_checked(style, math_parameter_superscript_shift_distance);
            halfword amount = box_width(postsubdata.box) + shift;
            tex_aux_prepend_hkern_to_box_list(postsupdata.box, amount, horizontal_math_kern_subtype, "post shifted");
        }
        if (presubdata.box && presupdata.shifted) {
            halfword shift = tex_get_math_x_parameter_checked(style, math_parameter_subprescript_shift_distance);
            halfword amount = box_width(presupdata.box) + shift;
            tex_aux_append_hkern_to_box_list(presubdata.box, amount, horizontal_math_kern_subtype, "pre shifted");
        } else if (presupdata.box && presubdata.shifted) {
            halfword shift = tex_get_math_x_parameter_checked(style, math_parameter_superprescript_shift_distance);
            halfword amount = box_width(presubdata.box) + shift;
            tex_aux_append_hkern_to_box_list(presupdata.box, amount, horizontal_math_kern_subtype, "pre shifted");
        }
        /* */
        if (postsupdata.box) {
            /* Do we still want to chain these sups or should we combine it? */
            tex_aux_get_math_sup_shifts(target, postsupdata.box, style, &shift_up); /* maybe only in else branch */
            if (postsubdata.box) {
                tex_aux_get_math_sup_sub_shifts(target, postsupdata.box, postsubdata.box, style, &shift_up, &shift_down);
                tex_aux_get_sup_kern(kernel, &postsupdata, shift_up, supshift, &supkern, kerns);
                tex_aux_get_sub_kern(kernel, &postsubdata, shift_down, subshift, &subkern, kerns);
                if (primestate == prime_at_begin_location) {
                    primekern += supkern ;
                    subkern = 0;
                    supkern = 0;
                } else { 
                    if (supkern) {
                        tex_aux_prepend_hkern_to_box_list(postsupdata.box, supkern, math_shape_kern_subtype, "post sup shape");
                    }
                    if (subkern) {
                        tex_aux_prepend_hkern_to_box_list(postsubdata.box, subkern, math_shape_kern_subtype, "post sub shape");
                    }
                }
                if (italic) {
                    tex_aux_prepend_hkern_to_box_list(postsupdata.box, italic, italic_kern_subtype, "italic");
                }
                if (presubdata.kern) {
                    kern_amount(presubdata.kern) += -subkern;
                    kern_amount(postsubdata.kern) += subkern;
                }
                if (presupdata.kern) {
                    /* italic needs checking */
                    kern_amount(presupdata.kern) += -supkern - italicmultiplier * italic;
                    kern_amount(postsupdata.kern) += supkern + italicmultiplier * italic;
                }
                {
                    halfword kern = tex_new_kern_node((shift_up - box_depth(postsupdata.box)) - (box_height(postsubdata.box) - shift_down), vertical_math_kern_subtype);
                    tex_attach_attribute_list_copy(kern, target);
                    tex_couple_nodes(postsupdata.box, kern);
                    tex_couple_nodes(kern, postsubdata.box);
                    result = tex_vpack(postsupdata.box, 0, packing_additional, max_dimen, (singleword) math_direction_par, holding_none_option);
                    tex_attach_attribute_list_copy(result, target);
                    node_subtype(result) = math_scripts_list;
                    box_shift_amount(result) = shift_down;
                }
            } else {
                tex_aux_get_sup_kern(kernel, &postsupdata, shift_up, supshift, &supkern, kerns);
                if (primestate == prime_at_begin_location) {
                    primekern += supkern ;
                    supkern = 0;
                } else if (supkern) {
                    tex_aux_prepend_hkern_to_box_list(postsupdata.box, supkern, math_shape_kern_subtype, "post sup shape");
                }
                result = tex_aux_shift_to_kern(target, postsupdata.box, -shift_up);
                if (presupdata.kern) {
                    kern_amount(presupdata.kern) += -supkern - subkern - italicmultiplier * italic;
                    kern_amount(postsupdata.kern) += supkern + subkern + italicmultiplier * italic;
                }
            }
        } else {
            tex_aux_get_math_sub_shifts(target, postsubdata.box, style, &shift_down);
            tex_aux_get_sub_kern(kernel, &postsubdata, shift_down, subshift, &subkern, kerns);
            if (primestate == prime_at_begin_location) {
                subkern = 0;
            } else if (subkern) {
                tex_aux_prepend_hkern_to_box_list(postsubdata.box, subkern, math_shape_kern_subtype, "post sub shape");
            }
            result = tex_aux_shift_to_kern(target, postsubdata.box, shift_down);
            if (presubdata.kern) {
                kern_amount(presubdata.kern) += -subkern;
                kern_amount(postsubdata.kern) += subkern;
            }
        }
        /* */
        if (! splitscripts) {
            if (topovershoot) {
                /* todo: tracing */
                if (noad_script_state(target) & pre_super_script_state) {
                    kern_amount(postsubdata.kern) -= topovershoot;
                    kern_amount(postsupdata.kern) -= topovershoot;
                }
                if (noad_script_state(target) & post_sub_script_state) {
                    kern_amount(presupdata.kern) += topovershoot;
                }
            }
            if (botovershoot) { 
                /* todo: tracing, yet untested */
                if (noad_script_state(target) & pre_sub_script_state) {
                    kern_amount(presubdata.kern) -= botovershoot;
                    kern_amount(presupdata.kern) -= botovershoot;
                }
                if (noad_script_state(target) & post_sub_script_state) {
                    kern_amount(presubdata.kern) += botovershoot;
                }
            }
            goto PICKUP;
        }
    }
    if (presubdata.box) {
        if (presupdata.box) {
            /* Do we still want to chain these sups or should we combine it? */
            tex_aux_get_math_sup_shifts(target, presupdata.box, style, &shift_up);
            tex_aux_get_math_sup_sub_shifts(target, presupdata.box, presubdata.box, style, &shift_up, &shift_down);
            prekern = box_width(presupdata.box);
            // test: what with negative extra kerns and what with a negative width
            if (! splitscripts) {
                if (box_width(presubdata.box) > prekern) {
                    prekern = box_width(presubdata.box);
                }
                presupdata.box = tex_aux_combine_script(target, kernelsize.wd, presupdata.box, null, &presupdata.kern, &postsupdata.kern);
                presubdata.box = tex_aux_combine_script(target, kernelsize.wd, presubdata.box, null, &presubdata.kern, &postsubdata.kern);
            }
            {
                halfword k = tex_new_kern_node((shift_up - box_depth(presupdata.box)) - (box_height(presubdata.box) - shift_down), vertical_math_kern_subtype);
                tex_attach_attribute_list_copy(k, target);
                tex_couple_nodes(presupdata.box, k);
                tex_couple_nodes(k, presubdata.box);
                preresult = tex_vpack(presupdata.box, 0, packing_additional, max_dimen, (singleword) math_direction_par, holding_none_option);
                tex_attach_attribute_list_copy(preresult, target);
                node_subtype(preresult) = math_scripts_list;
                box_shift_amount(preresult) = shift_down;
            }
        } else {
            tex_aux_get_math_sub_shifts(target, presubdata.box, style, &shift_down);
            if (! splitscripts) {
                prekern = box_width(presubdata.box);
                presubdata.box = tex_aux_combine_script(target, kernelsize.wd, presubdata.box, null, &presubdata.kern, &postsubdata.kern);
            }
            box_shift_amount(presubdata.box) = shift_down;
            preresult = presubdata.box;
        }
    } else if (presupdata.box) {
        tex_aux_get_math_sup_shifts(target, presupdata.box, style, &shift_up);
        if (! splitscripts) {
            prekern = box_width(presupdata.box);
            presupdata.box = tex_aux_combine_script(target, kernelsize.wd, presupdata.box, null, &presupdata.kern, &postsupdata.kern);
        }
        box_shift_amount(presupdata.box) = -shift_up;
        preresult = presupdata.box;
    }
  PICKUP:
    if (primestate == prime_at_begin_location) {
        halfword list = noad_new_hlist(target);
        if (primekern) {
            tex_aux_prepend_hkern_to_box_list(primedata.box, primekern, math_shape_kern_subtype, "prime");
        }
        if (list) {
            tex_couple_nodes(tex_tail_of_node_list(list), primedata.box);
        } else {
            list = primedata.box;
        }
        noad_new_hlist(target) = list;
    }
    if (splitscripts) {
        halfword list = noad_new_hlist(target);
        if (preresult) {
            if (list) {
                tex_couple_nodes(preresult, list);
            }
            list = preresult;
        }
        if (result) {
            if (list) {
                tex_couple_nodes(tex_tail_of_node_list(list), result);
            } else {
                list = result;
            }
        }
        noad_new_hlist(target) = list;
    } else {
        if (preresult) {
            result = preresult;
        }
        if (prekern) {
            /* must become horizontal kern */
            halfword list = tex_aux_prepend_hkern_to_new_hlist(target, prekern, horizontal_math_kern_subtype, "pre compensation");
            tex_couple_nodes(tex_tail_of_node_list(list), result);
        } else if (noad_new_hlist(target)) {
            tex_couple_nodes(tex_tail_of_node_list(noad_new_hlist(target)), result);
        } else {
            noad_new_hlist(target) = result;
        }
    }
    if (primestate == prime_at_end_location) {
        tex_couple_nodes(tex_tail_of_node_list(result), primedata.box);
        rightslack = primedata.slack;
    }
    if (math_slack_mode_par > 0) {
        noad_left_slack(target) = leftslack;
        noad_right_slack(target) = rightslack;
        if (tracing_math_par >= 2) {
            tex_begin_diagnostic();
            tex_print_format("[math: script slack, left %D, right %D]", leftslack, pt_unit, rightslack, pt_unit);
            tex_end_diagnostic();
        }
    }
}

/*tex

    The |make_left_right| function constructs a left or right delimiter of the required size and
    returns the value |open_noad| or |close_noad|. The |left_noad_side| and |right_noad_side| will
    both be based on the original |style|, so they will have consistent sizes.

*/

// inline static int tex_aux_is_extensible(halfword result)
// {
//     if (result) {
//         switch (node_type(result)) { 
//             case hlist_node:
//             case vlist_node:
//                 switch (node_subtype(result)) { 
//                     case math_h_delimiter_list:
//                     case math_v_delimiter_list:
//                         return 1;
//                 }
//         }
//     }
//     return 0;
// }

static halfword tex_aux_make_left_right(halfword target, int style, scaled max_d, scaled max_h, int size, delimiterextremes *extremes)
{
    halfword tmp;
    scaled ic = 0;
    int stack = 0;
    halfword mainclass = get_noad_main_class(target);
    halfword leftclass = get_noad_left_class(target);
    halfword rightclass = get_noad_right_class(target);
    scaled height = tex_aux_math_given_y_scaled(noad_height(target));
    scaled depth = tex_aux_math_given_y_scaled(noad_depth(target));
    int leftoperator = node_type(target) == fence_noad && node_subtype(target) == left_operator_side;
    max_h += fence_top_overshoot(target);
    max_d += fence_bottom_overshoot(target);
    if (extremes) { 
        extremes->tfont = null_font;
        extremes->bfont = null_font;
        extremes->tchar = 0;
        extremes->tchar = 0;
        extremes->height = 0;
        extremes->depth = 0;
    }
    tex_aux_set_current_math_size(style);
    if (height || depth || has_noad_option_exact(target)) {
        halfword lst;
        scaled delta = height + depth;
        tmp = tex_aux_make_delimiter(target, fence_delimiter_list(target), size, delta, 0, style, 0, &stack, &ic, 0, has_noad_option_nooverflow(target), extremes, 0);
        /* do extremes here */
        noad_italic(target) = ic;
        /*tex
            Beware, a stacked delimiter has a shift but no corrected height/depth (yet).
        */
/* or do we need has_noad_option_check(target) */
if (! stack && has_noad_option_exact(target)) {
    if (extremes && extremes->height < height) {
        height = extremes->height;
    }
    if (extremes && extremes->depth < depth) {
        depth = extremes->depth;
    }
}
        if (stack) {
            box_shift_amount(tmp) = depth;
        }
        if (has_noad_option_exact(target)) {
            height = box_height(tmp) - box_shift_amount(tmp);
            depth = box_depth(tmp) + box_shift_amount(tmp);
        }
        if (has_noad_option_axis(target)) {
         // if (has_noad_option_noaxis(target) && tex_aux_is_extensible(tmp)) {
            if (has_noad_option_noaxis(target) && stack) {
                /*tex A sort of special case: see sized integrals in ctx examples. */
            } else { 
                halfword axis = tex_aux_math_axis(size);
                height += axis;
                depth -= axis;
                box_shift_amount(tmp) -= axis;
            }
        }
        lst = tex_new_node(hlist_node, 0);
        tex_attach_attribute_list_copy(lst, target);
        box_dir(lst) = dir_lefttoright ;
        box_height(lst) = height;
        box_depth(lst) = depth;
        box_width(lst) = box_width(tmp);
        box_list(lst) = tmp;
        tmp = lst;
    } else {
        int axis = ! has_noad_option_noaxis(target);
        scaled delta = 0;
        if (leftoperator && has_noad_option_auto(target)) {
             /*tex Todo: option for skipping this. */
             if (style < text_style) {
                 scaled s = scaledround((double) tex_get_math_parameter(style, math_parameter_operator_size, NULL));
                 if (s > max_h + max_d) {
                     max_h = scaledround(s / 2.0);
                     max_d = max_h;
                     delta = max_h + max_d; 
                 }
             }
        }
        if (! delta) { 
            delta = tex_aux_get_delimiter_height(max_h, max_d, axis, size, style); // todo: pass scaled axis
        }
        tmp = tex_aux_make_delimiter(target, fence_delimiter_list(target), size, delta, 0, style, axis, &stack, &ic, 0, has_noad_option_nooverflow(target), extremes, 0);
    }
    /* delimiter is wiped */
    noad_height(target) = height;
    noad_depth(target) = depth;
    fence_delimiter_list(target) = null;
    noad_italic(target) = ic;
    /* */
    if (noad_source(target)) {
        box_source_anchor(tmp) = noad_source(target);
     // box_anchor(tmp) = left_origin_anchor;
        tex_set_box_geometry(tmp, anchor_geometry);
    }
    /* */
    if (leftoperator) {
        halfword s = tex_new_node(sub_box_node, 0);
        kernset kerns;
        tex_math_wipe_kerns(&kerns);
        tex_flush_node_list(noad_supscr(target));
        tex_flush_node_list(noad_subscr(target));
        tex_flush_node_list(noad_nucleus(target));
        if (kernel_math_list(fence_delimiter_top(target))) {
            noad_supscr(target) = fence_delimiter_top(target);
            fence_delimiter_top(target) = null;
        }
        if (kernel_math_list(fence_delimiter_bottom(target))) {
            noad_subscr(target) = fence_delimiter_bottom(target);
            fence_delimiter_bottom(target) = null;
        }
        kernel_math_list(s) = tmp;
        noad_nucleus(target) = s;
        /* maybe elsewhere as the above case */
        if (extremes && extremes->tfont) { 
            if (tex_math_has_class_option(fenced_noad_subtype, carry_over_right_top_kern_class_option)) {  
                kerns.topright = tex_char_top_right_kern_from_font(extremes->tfont, extremes->tchar);
            }
            if (tex_math_has_class_option(fenced_noad_subtype, carry_over_right_bottom_kern_class_option)) {  
                kerns.bottomright = tex_char_bottom_right_kern_from_font(extremes->bfont, extremes->bchar);
            }
            if (tex_math_has_class_option(fenced_noad_subtype, prefer_delimiter_dimensions_class_option)) {  
                kerns.height = extremes->height;
                kerns.depth = extremes->depth;
                kerns.dimensions = 1;
                kerns.font = extremes->tfont;
                kerns.character = extremes->tchar;
            }
        }
        /* returns italic, so maybe noad_italic(target) = ... */
        tex_aux_make_op(target, style, size, ic, limits_unknown_mode, &kerns);
        /* otherwise a leak: */
        kernel_math_list(s) = null;
        tex_flush_node(s);
    } else {
        tex_aux_assign_new_hlist(target, tmp);
    }
    /* */
    switch (node_subtype(target)) {
        case left_fence_side:
            if (leftclass != unset_noad_class) {
                return leftclass; 
            } else if (mainclass != unset_noad_class) {
                return mainclass;
            } else { 
                return open_noad_subtype;
            }
        case middle_fence_side:
            if (mainclass != unset_noad_class) {
                return mainclass;
            } else { 
                return middle_noad_subtype;
            }
        case right_fence_side:
            if (rightclass != unset_noad_class) {
                return rightclass; 
            } else if (mainclass != unset_noad_class) {
                return mainclass;
            } else { 
                return close_noad_subtype;
            }
        case left_operator_side:
            if (leftclass != unset_noad_class) {
                return leftclass; 
            } else if (mainclass != unset_noad_class) {
                return mainclass;
            } else { 
                return operator_noad_subtype;
            }
        default:
            if (mainclass != unset_noad_class) {
                return mainclass;
            } else { 
                /*tex So one can best set the class! */
                return ordinary_noad_subtype;
            }
    }
}

inline static int tex_aux_fallback_math_spacing_class(halfword style, halfword class)
{
    unsigned parent = (unsigned) count_parameter(first_math_class_code + class);
    switch (style) {
        case display_style:       case cramped_display_style:       return (parent >> 24) & 0xFF;
        case text_style:          case cramped_text_style:          return (parent >> 16) & 0xFF;
        case script_style:        case cramped_script_style:        return (parent >>  8) & 0xFF;
        case script_script_style: case cramped_script_script_style: return (parent >>  0) & 0xFF;
        default:                                                    return 0;
    }
}

static halfword tex_aux_math_spacing_glue(halfword ltype, halfword rtype, halfword style, scaled mmu)
{
    halfword c = tex_to_math_spacing_parameter(ltype, rtype);
    halfword s = c;
    for (int i = 1; i <= 2; i++) {
        if (s >= 0) {
            halfword d = 0;
            halfword x = tex_get_math_parameter(style, s, &d);
            if (x) {
                switch (d) {
                    case no_val_level:
                        break;
                    case dimen_val_level:
                        if (x) {
                            x = tex_aux_math_dimen(x, inter_math_skip_glue, c);
                            if (tracing_math_par >= 2) {
                                tex_begin_diagnostic();
                                tex_print_format("[math: inter atom kern, left %n, right %n, resolved %i, amount %D]", ltype, rtype, s, kern_amount(x), pt_unit);
                                tex_end_diagnostic();
                            }
                            return x;
                        }
                        goto NONE;
                    case glue_val_level:
                        if (! tex_glue_is_zero(x)) {
                            x = tex_aux_math_glue(x, inter_math_skip_glue, c);
                            if (tracing_math_par >= 2) {
                                tex_begin_diagnostic();
                                tex_print_format("[math: inter atom glue, left %n, right %n, resolved %i, amount %P]", ltype, rtype, s, glue_amount(x), glue_stretch(x), NULL, NULL, NULL, glue_shrink(x));
                                tex_end_diagnostic();
                            }
                            return x;
                        }
                        goto NONE;
                    case mu_val_level:
                        if (! tex_math_glue_is_zero(x)) {
                            x = tex_aux_math_muglue(x, inter_math_skip_glue, mmu, c, style);
                            if (tracing_math_par >= 2) {
                                tex_begin_diagnostic();
                                tex_print_format("[math: inter atom (mu) glue, left %n, right %n, resolved %i, amount %P]", ltype, rtype, s, glue_amount(x), glue_stretch(x), NULL, NULL, NULL, glue_shrink(x));
                                tex_end_diagnostic();
                            }
                            return x;
                        }
                        goto NONE;
                    default:
                        if (tracing_math_par >= 2) {
                            tex_begin_diagnostic();
                            tex_print_format("[math: inter atom (mu) glue, left %n, right %n, resolved %i, unset]", ltype, rtype, s);
                            tex_end_diagnostic();
                        }
                        goto NONE;
                }
            }
            /* try again */
            {
                halfword lparent = tex_aux_fallback_math_spacing_class(style, ltype);
                halfword rparent = tex_aux_fallback_math_spacing_class(style, rtype);
                /*tex Let's try the parents (one level). */
                if (lparent != ltype || rparent != rtype) {
                    s = tex_to_math_spacing_parameter(lparent, rtype);
                    if (tex_has_math_parameter(style, s)) {
                        goto FOUND;
                    }
                    s = tex_to_math_spacing_parameter(ltype, rparent);
                    if (tex_has_math_parameter(style, s)) {
                        goto FOUND;
                    }
                    s = tex_to_math_spacing_parameter(lparent, rparent);
                    if (tex_has_math_parameter(style, s)) {
                        goto FOUND;
                    }
                }
                /*tex We fall back on the |all| classes. */
                s = tex_to_math_spacing_parameter(ltype, math_all_class);
                if (tex_has_math_parameter(style, s)) {
                    goto FOUND;
                }
                s = tex_to_math_spacing_parameter(math_all_class, rtype);
                if (tex_has_math_parameter(style, s)) {
                    goto FOUND;
                }
                s = tex_to_math_spacing_parameter(lparent, math_all_class);
                if (tex_has_math_parameter(style, s)) {
                    goto FOUND;
                }
                s = tex_to_math_spacing_parameter(math_all_class, rparent);
                if (tex_has_math_parameter(style, s)) {
                    goto FOUND;
                }
                /*tex Now we're lost. */
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: inter atom fallback, left %n, right %n, left parent %n, right parent %n, not resolved]", ltype, rtype, lparent, rparent);
                    tex_end_diagnostic();
                }
                goto NONE;
             FOUND:
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: inter atom fallback, left %n, right %n, left parent %n, right parent %n, resolved %i]", ltype, rtype, lparent, rparent, s);
                    tex_end_diagnostic();
                }
            }
        } else {
         /* tex_confusion("math atom spacing"); */
            goto NONE;
        }
    }
  NONE:
    if (math_spacing_mode_par && c >= 0) {
        if (math_spacing_mode_par == 1 && (ltype == math_begin_class || rtype == math_end_class)) { 
            return null;
        } else {
            return tex_aux_math_dimen(0, inter_math_skip_glue, c);
        }
    } else {
        return null;
    }
}

inline static int tex_aux_fallback_math_ruling_class(halfword style, halfword class)
{
    unsigned parent = (unsigned) count_parameter(first_math_atom_code + class);
    switch (style) {
        case display_style:       case cramped_display_style:       return (parent >> 24) & 0xFF;
        case text_style:          case cramped_text_style:          return (parent >> 16) & 0xFF;
        case script_style:        case cramped_script_style:        return (parent >>  8) & 0xFF;
        case script_script_style: case cramped_script_script_style: return (parent >>  0) & 0xFF;
        default:                                                    return 0;
    }
}

static halfword tex_aux_math_ruling(halfword ltype, halfword rtype, halfword style)
{
    halfword c = tex_to_math_rules_parameter(ltype, rtype);
    halfword s = c;
    for (int i = 1; i <= 2; i++) {
        if (s >= 0) {
            halfword x = tex_get_math_parameter(style, s, NULL);
            if (x != MATHPARAMDEFAULT) {
                return x;
            } else {
                halfword lparent = tex_aux_fallback_math_ruling_class(style, ltype);
                halfword rparent = tex_aux_fallback_math_ruling_class(style, rtype);
                if (lparent != ltype || rparent != rtype) {
                    s = tex_to_math_rules_parameter(lparent, rparent);
                } else {
                    return MATHPARAMDEFAULT;
                }
            }
        } else {
            return MATHPARAMDEFAULT;
        }
    }
    return MATHPARAMDEFAULT;
}

halfword tex_math_spacing_glue(halfword ltype, halfword rtype, halfword style)
{
    halfword mu = tex_get_math_quad_size_scaled(lmt_math_state.size);
    halfword sg = tex_aux_math_spacing_glue(ltype, rtype, style, mu);
    if (node_type(sg) == glue_node) {
        tex_add_glue_option(sg, glue_option_no_auto_break);
    }
    return sg;
}

/*tex

    This is a bit complex function and it can beter be merged into the caller and be more specific
    there. The delta parameter can have a value already. When it keeps it value the caller can add
    is as italic correction. However, when we have no scripts we do it here.

*/

static halfword tex_aux_check_nucleus_complexity(halfword target, scaled *italic, halfword style, halfword size, kernset *kerns)
{
    halfword nucleus = noad_nucleus(target);
    if (nucleus) {
        if (italic) {
            *italic = 0;
        }
        switch (node_type(nucleus)) {
            case math_char_node:
            case math_text_char_node:
                {
                    halfword chr = null;
                    halfword fnt = null;
                    if (tex_aux_fetch(nucleus, "(text) char", &fnt, &chr)) {
                        /*tex We make a math glyph from an ordinary one. */
                        halfword glyph;
                        quarterword subtype = 0;
                        switch (node_subtype(nucleus)) {
                            case ordinary_noad_subtype:    subtype = glyph_math_ordinary_subtype;    break;
                            case operator_noad_subtype:    subtype = glyph_math_operator_subtype;    break;
                            case binary_noad_subtype:      subtype = glyph_math_binary_subtype;      break;
                            case relation_noad_subtype:    subtype = glyph_math_relation_subtype;    break;
                            case open_noad_subtype:        subtype = glyph_math_open_subtype;        break;
                            case close_noad_subtype:       subtype = glyph_math_close_subtype;       break;
                            case punctuation_noad_subtype: subtype = glyph_math_punctuation_subtype; break;
                            case variable_noad_subtype:    subtype = glyph_math_variable_subtype;    break;
                            case active_noad_subtype:      subtype = glyph_math_active_subtype;      break;
                            case inner_noad_subtype:       subtype = glyph_math_inner_subtype;       break;
                            case over_noad_subtype:        subtype = glyph_math_over_subtype;        break;
                            case under_noad_subtype:       subtype = glyph_math_under_subtype;       break;
                            case fraction_noad_subtype:    subtype = glyph_math_fraction_subtype;    break;
                            case radical_noad_subtype:     subtype = glyph_math_radical_subtype;     break;
                            case middle_noad_subtype:      subtype = glyph_math_middle_subtype;      break;
                            case accent_noad_subtype:      subtype = glyph_math_accent_subtype;      break;
                            case fenced_noad_subtype:      subtype = glyph_math_fenced_subtype;      break;
                            case ghost_noad_subtype:       subtype = glyph_math_ghost_subtype;       break;
                            default:
                                if (node_subtype(nucleus) < math_begin_class) {
                                    /*tex
                                        So at least we can recongize them and have some slack for
                                        new ones below this boundary. Nicer would be to be in range
                                        but then we have to ditch the normal glyph subtypes. Maybe
                                        we should move all classes above this edge.
                                    */
                                    subtype = glyph_math_extra_subtype + node_subtype(nucleus);
                                }
                                break;

                        }
                        glyph = tex_aux_new_math_glyph(fnt, chr, subtype);
                        tex_attach_attribute_list_copy(glyph, nucleus);
                        if (node_type(nucleus) == math_char_node) {
                            glyph_properties(glyph) = kernel_math_properties(nucleus);
                            glyph_group(glyph) = kernel_math_group(nucleus);
                            glyph_index(glyph) = kernel_math_index(nucleus);
                            if (math_kernel_node_has_option(nucleus, math_kernel_auto_discretionary)) { 
                                tex_add_glyph_option(glyph, glyph_option_math_discretionary);
                            }
                            if (math_kernel_node_has_option(nucleus, math_kernel_full_discretionary)) { 
                                tex_add_glyph_option(glyph, glyph_option_math_italics_too);
                            }
                        }
                        /*tex
                            Do we have a correction at all? In opentype fonts we normally set the
                            delta to zero.
                        */
                        if (math_kernel_node_has_option(nucleus, math_kernel_no_italic_correction)) {
                            /*tex
                               This node is flagged not to have italic correction.
                            */
                        } else if (tex_aux_math_followed_by_italic_kern(target, "complexity")) {
                            /*tex
                               For some reason there is (already) an explicit italic correction so we
                               don't add more here. I need a use case.
                            */
                        } else if (tex_aux_math_engine_control(fnt, math_control_apply_text_italic_kern)) {
                            /*tex
                                This is a bit messy and needs a more fundamental cleanup giving the
                                kind of control that we want.
                            */
                            if (italic) {
                                *italic = tex_aux_math_x_size_scaled(fnt, tex_char_italic_from_font(fnt, chr), size);
                                if (*italic) {
                                    if (node_type(nucleus) == math_text_char_node) {
                                        if (tex_aux_math_engine_control(fnt, math_control_check_text_italic_kern)) {
                                            /*tex
                                                We add no italic correction in mid-word of (opentype)
                                                text font. This is kind of fragile so it might go away
                                                or become an option.
                                            */
                                            if (chr == letter_cmd) {
                                                *italic = 0;
                                            }
                                        }
                                        if (tex_aux_math_engine_control(fnt, math_control_check_space_italic_kern)) {
                                            /*tex
                                                We're now in the traditional branch. it is a bit weird
                                                test based on space being present in an old school math
                                                font. For now we keep this.
                                            */
                                            if (tex_get_font_space(fnt)) {
                                                /*tex
                                                    We add no italic correction in mid-word (traditional)
                                                    text font. In the case of a math font, the correction
                                                    became part of the width.
                                                */
                                                *italic = 0;
                                            }
                                        }
                                    }
                                    if (*italic && ! noad_has_following_scripts(target)) {
                                        /*tex
                                            Here we add a correction but then also have to make sure that it
                                            doesn't happen later on so we zero |delta| afterwards. The call
                                            handles the one script only case (maybe delegate the next too).
                                        */
                                        tex_aux_math_insert_italic_kern(glyph, *italic, nucleus, "check");
                                        *italic = 0;
                                    }
                                }
                            }
                        }
                        return glyph;
                    } else {
                        return tex_new_node(hlist_node, unknown_list);
                    }
                }
            case sub_box_node:
                return kernel_math_list(nucleus);
            case sub_mlist_node:
                {
                    halfword list = kernel_math_list(nucleus);
                    halfword package = null;
                    halfword fenced = node_type(target) == simple_noad && node_subtype(target) == fenced_noad_subtype;
                    halfword last = fenced ? tex_tail_of_node_list(list) : null;
                    int unpack = tex_math_has_class_option(node_subtype(target), unpack_class_option) || has_noad_option_unpacklist(target);
                    halfword result = tex_mlist_to_hlist(list, unpack, style, unset_noad_class, unset_noad_class, kerns); /*tex Here we're nesting. */
                    tex_aux_set_current_math_size(style);
                    package = tex_hpack(result, 0, packing_additional, direction_unknown, holding_none_option);
                    if (fenced) {
                        node_subtype(package) = math_fence_list;
                        if (list && node_type(list) == fence_noad && noad_analyzed(list) != unset_noad_class) {
                            set_noad_left_class(target, noad_analyzed(list));
                        }
                        if (last && node_type(last) == fence_noad && noad_analyzed(last) != unset_noad_class) {
                            set_noad_right_class(target, noad_analyzed(last));
                        }
                    } else if (unpack) {
                        node_subtype(package) = math_list_list;
                    } else if (noad_class_main(target) == unset_noad_class) {
                        node_subtype(package) = math_pack_list;
                    } else {
                        node_subtype(package) = 0x100 + noad_class_main(target);
                    }
                    tex_attach_attribute_list_copy(package, nucleus);
                    return package;
                }
            case hlist_node:
                /* really */
                break;
            default:
                tex_confusion("check nucleus complexity");
        }
    } else {
        tex_normal_warning("math", "recovering from missing nucleus, best check it out");
        noad_nucleus(target) = tex_aux_fake_nucleus(ghost_noad_subtype);
    }
    return tex_new_node(hlist_node, unknown_list);
}

/*tex
    The main reason for keeping the node is that original \TEX\ has no prev links but we do have 
    these in \LUATEX. But it is anyway okay to keep this a signal. 
*/

static halfword tex_aux_make_choice(halfword current, halfword style)
{
    halfword prv = node_prev(current);
    halfword nxt = node_next(current); 
    halfword signal = tex_new_node(style_node, former_choice_math_style);
    /*tex We replace choice by signal encoded in a style noad, it is no longer a cast! */
    tex_try_couple_nodes(prv, signal);
    tex_try_couple_nodes(signal, nxt);
    switch (node_subtype(current)) { 
        case normal_choice_subtype:
            {
                halfword choice = null;
                switch (style) {
                    case display_style:
                    case cramped_display_style:
                        choice = choice_display_mlist(current);
                        choice_display_mlist(current) = null;
                        break;
                    case text_style:
                    case cramped_text_style:
                        choice = choice_text_mlist(current);
                        choice_text_mlist(current) = null;
                        break;
                    case script_style:
                    case cramped_script_style:
                        choice = choice_script_mlist(current);
                        choice_script_mlist(current) = null;
                        break;
                    case script_script_style:
                    case cramped_script_script_style:
                        choice = choice_script_script_mlist(current);
                        choice_script_script_mlist(current) = null;
                        break;
                }
                /*tex We inject the choice list after the signal. */
                if (choice) {
                    tex_couple_nodes(signal, choice);
                    tex_try_couple_nodes(tex_tail_of_node_list(choice), nxt);
                }
            }
            break;
        case discretionary_choice_subtype:
            {
                halfword disc = tex_new_disc_node(normal_discretionary_code);
                halfword pre = choice_pre_break(current);
                halfword post = choice_post_break(current);
                halfword replace = choice_no_break(current);
                choice_pre_break(current) = null;
                choice_post_break(current) = null;
                choice_no_break(current) = null;
                if (pre) { 
                    pre = tex_mlist_to_hlist(pre, 0, style, unset_noad_class, unset_noad_class, NULL);
                    tex_set_disc_field(disc, pre_break_code, pre);
                }
                if (post) { 
                    post = tex_mlist_to_hlist(post, 0, style, unset_noad_class, unset_noad_class, NULL);
                    tex_set_disc_field(disc, post_break_code, post);
                }
                if (replace) { 
                    replace = tex_mlist_to_hlist(replace, 0, style, unset_noad_class, unset_noad_class, NULL);
                    tex_set_disc_field(disc, no_break_code, replace);
                }
                disc_class(disc) = choice_class(current);
                disc = tex_math_make_disc(disc);
                tex_couple_nodes(signal, disc);
                tex_try_couple_nodes(disc, nxt);
            }
            break;
    }
    /*tex We flush the old choice node */
    tex_flush_node(current);
    return signal;
}

/*tex
    This is just a \quote {fixer}. Todo: prepend the top and/or bottom to the super/subscript,
    but we also need to hpack then. Problem: how to determine the slack here? However, slack
    is less important because we normally have binding right text here.
*/

static int tex_aux_make_fenced(halfword current, halfword current_style, halfword size, noad_classes *fenceclasses)
{
    halfword nucleus = noad_nucleus(current);
    (void) current_style;
    (void) size;
    if (nucleus) {
        halfword list = kernel_math_list(nucleus);
        if (list && node_type(list) == fence_noad && node_subtype(list) == left_operator_side) {
            /* maybe use this more: */
            fenceclasses->main = noad_class_main(list);
            fenceclasses->left = noad_class_left(list);
            fenceclasses->right = noad_class_right(list);
            if (noad_supscr(current) && ! kernel_math_list(fence_delimiter_top(list))) {
                halfword n = tex_new_node(simple_noad, ordinary_noad_subtype);
                node_subtype(n) = math_char_node;
                noad_nucleus(n) = noad_supscr(current);
                kernel_math_list(fence_delimiter_top(list)) = n;
                noad_supscr(current) = null;
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_str("[math: promoting supscript to top delimiter]");
                    tex_end_diagnostic();
                }
            }
            if (noad_subscr(current) && ! kernel_math_list(fence_delimiter_bottom(list))) {
                halfword n = tex_new_node(simple_noad, ordinary_noad_subtype);
                node_subtype(n) = math_char_node;
                noad_nucleus(n) = noad_subscr(current);
                kernel_math_list(fence_delimiter_bottom(list)) = n;
                noad_subscr(current) = null;
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_str("[math: promoting subscript to bottom delimiter]");
                    tex_end_diagnostic();
                }
            }
            /*tex
                Now we remove the dummy right one. If something is in between we assume it's on
                purpose.
            */
            {
                halfword nxt = node_next(list);
                if (nxt && node_type(nxt) == fence_noad && node_subtype(nxt) == right_fence_side) {
                    /* todo : check for delimiter . or 0 */
                    node_next(list) = null;
                    tex_flush_node_list(nxt);
                }
            }
            return 1; /* we had a growing one */
        }
    }
    return 0;
}

static void tex_aux_finish_fenced(halfword current, halfword main_style, scaled max_depth, scaled max_height, kernset *kerns)
{
    delimiterextremes extremes = { .tfont = null_font, .tchar = 0, .bfont = null_font, .bchar = 0, .height = 0, .depth = 0 };
    noad_analyzed(current) = (singleword) tex_aux_make_left_right(current, main_style, max_depth, max_height, lmt_math_state.size, &extremes);
    if (kerns && extremes.tfont) { 
        switch (node_subtype(current)) { 
            case left_fence_side:
            case extended_left_fence_side:
                if (tex_math_has_class_option(fenced_noad_subtype, carry_over_left_top_kern_class_option)) {  
                    kerns->topleft = tex_char_top_left_kern_from_font(extremes.tfont, extremes.tchar);
                }
                if (tex_math_has_class_option(fenced_noad_subtype, carry_over_left_bottom_kern_class_option)) {  
                    kerns->bottomleft = tex_char_bottom_left_kern_from_font(extremes.bfont, extremes.bchar);
                }
                if (tex_math_has_class_option(fenced_noad_subtype, prefer_delimiter_dimensions_class_option)) {  
                    kerns->height = extremes.height;
                    kerns->depth = extremes.depth;
                    kerns->dimensions = 1;
                    kerns->font = extremes.tfont;
                }
                break;
            case right_fence_side:
            case extended_right_fence_side:
            case left_operator_side:
            case no_fence_side:
                if (tex_math_has_class_option(fenced_noad_subtype, carry_over_right_top_kern_class_option)) {  
                    kerns->topright = tex_char_top_right_kern_from_font(extremes.tfont, extremes.tchar);
                }
                if (tex_math_has_class_option(fenced_noad_subtype, carry_over_right_bottom_kern_class_option)) {  
                    kerns->bottomright = tex_char_bottom_right_kern_from_font(extremes.bfont, extremes.bchar);
                }
                if (tex_math_has_class_option(fenced_noad_subtype, prefer_delimiter_dimensions_class_option)) {  
                    kerns->height = extremes.height;
                    kerns->depth = extremes.depth;
                }
                break;
        }
    }
}

/*tex

    Here is the overall plan of |mlist_to_hlist|, and the list of its local variables. In
    \LUAMETATEX\ we could actually use the fact that we have a double linked list. Because we have
    a more generic class and penalty handling the two stages are clearly separated, also variable
    wise.

*/

static halfword tex_aux_unroll_noad(halfword tail, halfword l, quarterword s)
{
    while (l) {
        halfword n = node_next(l);
        node_next(l) = null;
        if (node_type(l) == hlist_node && node_subtype(l) == s && ! box_source_anchor(l)) {
            if (box_list(l)) {
                tex_couple_nodes(tail, box_list(l));
                tail = tex_tail_of_node_list(tail);
                box_list(l) = null;
            }
            tex_flush_node(l);
        } else {
            tex_couple_nodes(tail, l);
            tail = l;
        }
        l = n;
    }
    return tail;
}

static halfword tex_aux_unroll_list(halfword tail, halfword l)
{
    while (l) {
        halfword n = node_next(l);
        node_next(l) = null;
        if (node_type(l) == hlist_node && ! box_source_anchor(l)) {
            if (box_list(l)) {
                switch (node_subtype(l)) {
                    case hbox_list:
                    case container_list:
                    case math_list_list: /* in case of a ghost (we could remap subtype instead) */
                        tex_couple_nodes(tail, box_list(l));
                        tail = tex_tail_of_node_list(tail);
                        box_list(l) = null;
                        break;
                    default:
                        tex_couple_nodes(tail, l);
                        tail = l;
                        break;
                }
            }
            tex_flush_node(l);
        } else { 
            tex_couple_nodes(tail, l);
            tail = l;
        }
        l = n;
    }
    return tail;
}

inline static void tex_aux_wipe_noad(halfword n)
{
    if (tex_nodetype_has_attributes(node_type(n))) {
        remove_attribute_list(n);
    }
    tex_reset_node_properties(n);
    tex_free_node(n, get_node_size(node_type(n)));
}

static halfword tex_aux_append_ghost(halfword ghost, halfword p)
{
    halfword l = noad_new_hlist(ghost);
    if (l) {
        if (has_noad_option_unpacklist(ghost)) {
            /* always anyway */
            p = tex_aux_unroll_noad(p, l, math_list_list);
        } else if (has_noad_option_unrolllist(ghost)) {
            p = tex_aux_unroll_list(p, l);
        } else {
            if (node_type(l) == hlist_node && ! node_next(l)) {
                node_subtype(l) = math_ghost_list;
            }
            tex_couple_nodes(p, l);
            p = tex_tail_of_node_list(p);
        }
        noad_new_hlist(ghost) = null;
    }
    tex_aux_wipe_noad(ghost);
    return p;
}

static halfword tex_aux_get_plus_glyph(halfword current)
{
    if (node_type(current) == simple_noad) {
        halfword list = noad_new_hlist(current);
        if (list && node_type(list) == hlist_node) {
            list = box_list(list);
        }
        if (list && node_type(list) == glue_node) {
            list = node_next(list);
        }
        if (list && node_type(list) == glyph_node && ! node_next(list)) {
            return list;
        }
    }
    return null;
}

static void tex_aux_show_math_list(const char *fmt, halfword list)
{
    tex_begin_diagnostic();
    tex_print_format(fmt, lmt_math_state.level);
    tex_show_node_list(list, tracing_math_par >= 3 ? max_integer : show_box_depth_par, tracing_math_par >= 3 ? max_integer : show_box_breadth_par);
    tex_print_ln();
    tex_end_diagnostic();
}

static halfword tex_aux_check_source(halfword current, halfword list, int repack)
{
    if (list && noad_source(current)) {
        switch (node_type(list)) {
            case hlist_node:
            case vlist_node:
             // printf("anchoring to list: %i\n", noad_source(current));
                box_source_anchor(list) = noad_source(current);
                tex_set_box_geometry(list, anchor_geometry);
                noad_source(current) = 0; 
                break;
            default:
                if (repack) {
                    if (tracing_math_par >= 2) {
                        tex_begin_diagnostic();
                        tex_print_format("[math: packing due to source field %D]", noad_source(current));
                        tex_end_diagnostic();
                    }
                    list = tex_hpack(list, 0, packing_additional, direction_unknown, holding_none_option);
                 // printf("anchoring to wrapped list: %i\n", noad_source(current));
                    tex_attach_attribute_list_copy(list, current);
                    box_source_anchor(list) = noad_source(current);
                    noad_source(current) = 0; 
                    tex_set_box_geometry(list, anchor_geometry);
                    noad_new_hlist(current) = list;
                    node_subtype(list) = math_pack_list;
                }
                break;
        }
    } else {
        /* can't happen as we already checked before the call */
    }
    return list; 
}

static void tex_aux_wrapup_nucleus_and_add_scripts(halfword current, halfword nxt, int current_style, halfword *italic, kernset *kerns)
{
    halfword p = tex_aux_check_nucleus_complexity(current, italic, current_style, lmt_math_state.size, kerns);
    if (p && noad_source(current)) {
        p = tex_aux_check_source(current, p, has_noad_option_source_on_nucleus(current));
    }
    if (noad_has_scripts(current)) {
        scaled drop = 0;
        if (node_type(current) == accent_noad && noad_has_superscripts(current)) { 
            drop = tex_get_math_y_parameter_default(current_style, math_parameter_accent_superscript_drop, 0);
            drop += scaledround(kerns->toptotal * tex_get_math_parameter_default(current_style, math_parameter_accent_superscript_percent, 0) / 100.0);
        }
        tex_aux_make_scripts(current, p, *italic, current_style, 0, 0, drop, kerns);
    } else {
        /*tex
            Adding italic correction here is kind of fuzzy because some characters already have
            that built in. However, we also add it in the scripts so if it's optional here it
            also should be there. The compexity tester can have added it in which case delta
            is zero.
        */
        if (nxt && *italic) {
            if (node_type(nxt) == simple_noad && tex_math_has_class_option(node_subtype(nxt), no_italic_correction_class_option)) {
                *italic = 0;
            }
            if (*italic) {
                /* If we want it as option we need the fontor store it in the noad. */
                tex_aux_math_insert_italic_kern(p, *italic, current, "final");
            }
        }
        tex_aux_assign_new_hlist(current, p);
    }
}

/*tex

    This function is called recursively, for instance for wrapped content in fence, accent, fraction 
    and radical noads. Especially the fences introduce some messy code but I might clean that up 
    stepwise. We don't want to get away too much from the original. 

    Because we have more than two passes, and the function became way larger, it has been split up
    in smaller functions. 

*/

typedef struct mliststate {
    halfword mlist;
    int      penalties;
    int      main_style;
    int      beginclass;
    int      endclass;
    kernset *kerns;
    halfword scale;
    scaled   max_height;
    scaled   max_depth;
} mliststate;

static void tex_mlist_to_hlist_set_boundaries(mliststate *state)
{
    halfword b = tex_aux_fake_nucleus((quarterword) state->beginclass);
    halfword e = tex_aux_fake_nucleus((quarterword) state->endclass);
    if (state->mlist) {
        tex_couple_nodes(b, state->mlist);
    }
    state->mlist = b;
    tex_couple_nodes(tex_tail_of_node_list(state->mlist), e);
    state->beginclass = unset_noad_class;
    state->endclass = unset_noad_class;
}

static void tex_mlist_to_hlist_preroll_radicals(mliststate *state)
{
    halfword current = state->mlist;
    halfword current_style = state->main_style;
    halfword height = 0;
    halfword depth = 0;
    tex_aux_set_current_math_size(current_style);
    tex_aux_set_current_math_scale(state->scale);
    if (tracing_math_par >= 2) {
        tex_aux_show_math_list("[math: radical sizing pass, level %i]", state->mlist);
    }
    while (current) {
        switch (node_type(current)) {
            case radical_noad:
                {
                    halfword body = null;
                    tex_aux_preroll_radical(current, current_style, lmt_math_state.size);
                    body = noad_new_hlist(current);
                    if (box_height(body) > height) {
                        height = box_height(body);
                    }
                    if (box_depth(body) > depth) {
                        depth = box_depth(body);
                    }
                }
                break;
            case style_node:
                tex_aux_make_style(current, &current_style, NULL);
                break;
            case parameter_node:
                tex_def_math_parameter(node_subtype(current), parameter_name(current), parameter_value(current), cur_level + lmt_math_state.level, indirect_math_regular);
                break;
        }
        current = node_next(current);
    }
    /*tex
        A positive value is assigned, a negative value subtracted and a value of maxdimen will use 
        the maximum found dimensions. Todo: use an option to control this instead. 
    */
    current = state->mlist;
    while (current) {
        if (node_type(current) == radical_noad) {
            switch (node_subtype(current)) { 
                case normal_radical_subtype:
                case radical_radical_subtype:
                case root_radical_subtype:
                case rooted_radical_subtype:
                    {
                        halfword body = noad_new_hlist(current);
                        if (radical_height(current) == max_dimen) {
                            box_height(body) = height;
                        } else if (radical_height(current) < 0) {
                            box_height(body) += radical_height(current);
                            if (box_height(body) < 0) {
                                box_height(body) += 0;
                            }
                        } else if (radical_height(current)) {
                            box_height(body) = radical_height(current);
                        }
                        if (radical_depth(current) == max_dimen) {
                            box_depth(body) = depth;
                        } else if (radical_depth(current) < 0) {
                            box_depth(body) += radical_depth(current);
                            if (box_depth(body) < 0) {
                                box_depth(body) += 0;
                            }
                        } else if (radical_depth(current)) {
                            box_depth(body) = radical_depth(current);
                        }
                    }
                    break;
            }
        }
        current = node_next(current);
    }
}

/*tex 
    At some point this will all change to well defined kernel/script/talic handling but then we no 
    longer are compatible. It depends on fonts being okay. We already have some dead brances. 
*/

static void tex_mlist_to_hlist_preroll_dimensions(mliststate *state)
{
    halfword current = state->mlist;
    scaled current_mu = 0;
    halfword current_style = state->main_style;
    int blockrulebased = 0;
    /*tex We set the math unit width corresponding to |size|: */
    tex_aux_set_current_math_size(current_style);
    tex_aux_set_current_math_scale(state->scale);
    current_mu = tex_get_math_quad_size_scaled(lmt_math_state.size);
    if (tracing_math_par >= 2) {
        tex_aux_show_math_list("[math: first pass, level %i]", state->mlist);
    }
    while (current) {
        /*tex The italic correction offset for subscript and superscript: */
        scaled italic = 0;
        halfword nxt = node_next(current);
        noad_classes fenceclasses = { unset_noad_class, unset_noad_class, unset_noad_class };
        kernset localkerns;
        tex_math_wipe_kerns(&localkerns);
        /*tex
            At some point we had nicely cleaned up switch driven code here but we ended up with a
            more generic approach. The reference is still in the pre-2022 zips and git repository.

            The fact that we have configurable atom spacing (with inheritance) means that we can
            now have a rather simple switch without any remapping and RESWITCH magic.
        */
        if (blockrulebased > 0) {
            blockrulebased -= 1;
        }
        switch (node_type(current)) {
            case simple_noad:
                /*tex
                    Because we have added features we no longer combine the case in clever ways to
                    minimize code. Let the compiler do that for us. We could be generic and treat
                    all the same but for now we just emulate some of traditional \TEX's selectivity.
                */
                if (blockrulebased > 0) {
                    noad_options(current) |= noad_option_no_ruling;
                    blockrulebased = 0;
                }
                switch (node_subtype(current)) {
                    case under_noad_subtype:
                        tex_aux_make_under(current, current_style, lmt_math_state.size, math_rules_fam_par);
                        break;
                    case over_noad_subtype:
                        tex_aux_make_over(current, current_style, lmt_math_state.size, math_rules_fam_par);
                        break;
                    case vcenter_noad_subtype:
                        tex_aux_make_vcenter(current, current_style, lmt_math_state.size);
                        break;
                    case fenced_noad_subtype:
                        if (tex_aux_make_fenced(current, current_style, lmt_math_state.size, &fenceclasses)) {
                            /*tex We have a left operator so we fall through! */
                        } else {
                            break;
                        }
                    case operator_noad_subtype:
                        /* compatibility */
                        if (! (has_noad_option_limits(current) || has_noad_option_nolimits(current))) {
                            /* otherwise we don't enter the placement function */
                            noad_options(current) |= (current_style == display_style || current_style == cramped_display_style) ? noad_option_limits : noad_option_no_limits;
                        }
                        goto PROCESS;
                    default:
                        /* setting both forces check */
                        if ((has_noad_option_limits(current) && has_noad_option_nolimits(current))) {
                            if (current_style == display_style || current_style == cramped_display_style) {
                                noad_options(current) = unset_option(noad_options(current), noad_option_no_limits);
                                noad_options(current) |= noad_option_limits;
                            } else {
                                noad_options(current) = unset_option(noad_options(current), noad_option_limits);
                                noad_options(current) |= noad_option_no_limits;
                            }
                        }
                      PROCESS:
                        if (  // node_subtype(q) == operator_noad_subtype
                                // ||
                                   has_noad_option_limits(current)       || has_noad_option_nolimits(current)
                                || has_noad_option_openupheight(current) || has_noad_option_openupdepth(current)
                                || has_noad_option_adapttoleft(current)  || has_noad_option_adapttoright(current)
                            ) {
                            if (node_subtype(current) == fenced_noad_subtype && ! noad_has_scripts(current)) {
                                /*tex
                                    This is a special case: the right counterpart of the left operator
                                    can trigger a boxing of all that comes before so we need to enforce
                                    nolimits. Mikael Sundqvist will reveal all this in the CMS manual.
                                */
                                italic = tex_aux_make_op(current, current_style, lmt_math_state.size, 0, limits_horizontal_mode, NULL);
                            } else {
                                italic = tex_aux_make_op(current, current_style, lmt_math_state.size, 0, limits_unknown_mode, NULL);
                            }
                            /* tex_math_has_class_option(node_subtype(current),keep_correction_class_code) */
                            if (node_subtype(current) != operator_noad_subtype) {
                                italic = 0;
                            }
                            if (fenceclasses.main != unset_noad_class) {
                                noad_class_main(current) = fenceclasses.main;
                            }
                            if (fenceclasses.left != unset_noad_class) {
                                noad_class_left(current) = fenceclasses.left;
                            }
                            if (fenceclasses.right != unset_noad_class) {
                                noad_class_right(current) = fenceclasses.right;
                            }
                            if (has_noad_option_limits(current) || has_noad_option_nolimits(current)) {
                                goto CHECK_DIMENSIONS;
                            }
                        } else {
                            // tex_aux_make_ord(current, lmt_math_state.size);
                            tex_aux_check_ord(current, lmt_math_state.size, null);
                        }
                        break;
                }
                break;
            case fence_noad:
                {
                    /* why still ... */
                    current_style = state->main_style;
                    tex_aux_set_current_math_size(current_style);
                    current_mu = tex_get_math_quad_size_scaled(lmt_math_state.size);
                    /* ... till here */
                    goto DONE_WITH_NODE;
                }
            case fraction_noad:
                tex_aux_make_fraction(current, current_style, lmt_math_state.size, state->kerns);
                goto CHECK_DIMENSIONS;
            case radical_noad:
                tex_aux_make_radical(current, current_style, lmt_math_state.size, &localkerns);
                break;
            case accent_noad:
                tex_aux_make_accent(current, current_style, lmt_math_state.size, &localkerns);
                break;
            case style_node:
                tex_aux_make_style(current, &current_style, &current_mu);
                goto DONE_WITH_NODE;
            case choice_node:
                current = tex_aux_make_choice(current, current_style);
                goto DONE_WITH_NODE;
            case parameter_node:
                /* maybe not needed as we do a first pass */
                tex_def_math_parameter(node_subtype(current), parameter_name(current), parameter_value(current), cur_level + lmt_math_state.level, indirect_math_regular);
                goto DONE_WITH_NODE;
            case insert_node:
            case mark_node:
            case adjust_node:
            case boundary_node:
            case whatsit_node:
            case penalty_node:
            case disc_node:
            case par_node: /* for local boxes */
                goto DONE_WITH_NODE;
            case rule_node:
                tex_aux_check_math_strut_rule(current, current_style);
                if (rule_height(current) > state->max_height) {
                    state->max_height = rule_height(current);
                }
                if (rule_depth(current) > state->max_depth) {
                    state->max_depth = rule_depth(current);
                }
                goto DONE_WITH_NODE;
            case glue_node:
                if (node_subtype(current) == rulebased_math_glue) {
                    blockrulebased = 2;
                }
                tex_aux_make_glue(current, current_mu, current_style);
                goto DONE_WITH_NODE;
            case kern_node:
                tex_aux_make_kern(current, current_mu, current_style);
                goto DONE_WITH_NODE;
            default:
                tex_confusion("mlist to hlist, case 1");
        }
        /*tex
            When we get to the following part of the program, we have \quote {fallen through} from
            cases that did not lead to |check_dimensions| or |done_with_noad| or |done_with_node|.
            Thus, |q|~points to a noad whose nucleus may need to be converted to an hlist, and
            whose subscripts and superscripts need to be appended if they are present.

            If |nucleus(q)| is not a |math_char|, the variable |italic| is the amount by which a
            superscript should be moved right with respect to a subscript when both are present.
        */
        tex_aux_wrapup_nucleus_and_add_scripts(current, nxt, current_style, &italic, &localkerns);
      CHECK_DIMENSIONS:
        {
            scaledwhd siz = tex_natural_hsizes(noad_new_hlist(current), null, normal_glue_multiplier, normal_glue_sign, normal_glue_sign);
            if (siz.ht > state->max_height) {
                state->max_height = siz.ht;
            }
            if (siz.dp > state->max_depth) {
                state->max_depth = siz.dp;
            }
        }
      DONE_WITH_NODE:
        if ((node_type(current) == simple_noad) && noad_new_hlist(current)) { 
            if (has_noad_option_phantom(current) || has_noad_option_void(current)) {
                noad_new_hlist(current) = tex_aux_make_list_phantom(noad_new_hlist(current), has_noad_option_void(current), get_attribute_list(current));
            }
        } 
        current = node_next(current);
    }
}

static void tex_mlist_to_hlist_size_fences(mliststate *state)
{
    halfword current = state->mlist;
    halfword current_style = state->main_style;
    tex_aux_set_current_math_size(current_style);
    tex_aux_set_current_math_scale(state->scale);
    if (tracing_math_par >= 2) {
        tex_aux_show_math_list("[math: fence sizing pass, level %i]", state->mlist);
    }
    while (current) {
        switch (node_type(current)) {
            case fence_noad:
                tex_aux_finish_fenced(current, current_style, state->max_depth, state->max_height, state->kerns);
                break;
            case style_node:
                tex_aux_make_style(current, &current_style, NULL);
                break;
            case parameter_node:
                /* tricky as this is sort of persistent, we need to reset it at the start */
                tex_def_math_parameter(node_subtype(current), parameter_name(current), parameter_value(current), cur_level + lmt_math_state.level, indirect_math_regular);
                break;
        }
        current = node_next(current);
    }
}

static void tex_mlist_to_hlist_finalize_list(mliststate *state)
{
    halfword recent = null; /*tex Watch out: can be wiped, so more a signal! */
    int recent_type = 0;
    int recent_subtype = ordinary_noad_subtype;
    halfword current_style = state->main_style;
    halfword fenced = null;
    halfword packedfence = null;
    halfword recent_left_slack = 0;
    halfword recent_right_slack = 0;
    halfword recent_class_overload = unset_noad_class;
    halfword recent_script_state = 0;
    halfword recent_plus_glyph = null;
    scaled current_mu = 0;
    halfword current = state->mlist;
    halfword p = temp_head;
    halfword ghost = null;
    node_next(p) = null;
    tex_aux_set_current_math_size(current_style);
    tex_aux_set_current_math_scale(state->scale);
    current_mu = tex_get_math_quad_size_scaled(lmt_math_state.size);
    if (math_penalties_mode_par) {
        state->penalties = 1; /* move to caller ? */
    }
    if (tracing_math_par >= 2) {
        tex_aux_show_math_list("[math: second pass, level %i]", state->mlist);
    }
  RESTART:
    while (current) {
        /*tex
            If node |q| is a style node, change the style and |goto delete_q|; otherwise if it is
            not a noad, put it into the hlist, advance |q|, and |goto done|; otherwise set |s| to
            the size of noad |q|, set |t| to the associated type (|ord_noad.. inner_noad|), and set
            |pen| to the associated penalty.

            Just before doing the big |case| switch in the second pass, the program sets up default
            values so that most of the branches are short.

            We need to remain somewhat compatible so we still handle some open and close fence
            setting (marked as safeguard) here but as we (1) take the class from the delimiter,
            when set, or (2) derive it from the fence subtype, we don't really need it. In some
            cases, like with bars that serve a dual purpose, it will always be a mess.

        */
        /*tex the effective |type| of noad |q| during the second pass */
        halfword current_type = simple_noad;
        /*tex the effective |subtype| of noad |q| during the second pass */
        halfword current_subtype = ordinary_noad_subtype;
        /*tex penalties to be inserted */
        halfword post_penalty = infinite_penalty;
        halfword pre_penalty = infinite_penalty;
        /*tex experiment */
        halfword current_left_slack = 0;
        halfword current_right_slack = 0;
        halfword current_script_state = 0;
        halfword current_plus_glyph = 0;
        halfword old_recent = 0;
        halfword old_current = 0;
      HERE:
        switch (node_type(current)) {
            case simple_noad:
                if (node_subtype(current) == ghost_noad_subtype) {
                    /* for now, what to do with edges */
                    halfword nxt = node_next(current);
                    if (ghost) {
                        // check for noad_new_hlist(ghost)
                        halfword p = tex_tail_of_node_list(noad_new_hlist(ghost)); 
                        noad_class_right(ghost) = noad_class_right(current);
                        p = tex_aux_append_ghost(current, p);
                        noad_new_hlist(ghost) = tex_head_of_node_list(p); 
                    } else {
                        ghost = current;
                    }
                    current = nxt;
                    if (current) {
                        goto HERE;
                    } else {
                        goto RESTART;
                    }
                } else {
                    /*tex
                        Here we have a wrapped list of left, middle, right and content nodes.  
                    */
                    current_subtype = node_subtype(current);
                    current_left_slack = noad_left_slack(current);
                    current_right_slack = noad_right_slack(current);
                    current_script_state = noad_script_state(current);
                    switch (current_subtype) {
                        case fenced_noad_subtype:
                            {
                                fenced = current;
                                if (get_noad_right_class(fenced) != unset_noad_class) {
                                    current_subtype = get_noad_left_class(fenced);
                                } else if (get_noad_main_class(fenced) != unset_noad_class) { // needs testing by MS
                                    current_subtype = get_noad_main_class(fenced);
                                } else {
                                    current_subtype = open_noad_subtype; /* safeguard, see comment above */
                                }
                                break;
                            }
                        default:
                            {
                                halfword list = noad_new_hlist(current);
                                if (list && tex_is_math_disc(list)) {
                                    current_type = simple_noad;
                                    current_subtype = disc_class(box_list(list));
                                }
                                if (list && noad_source(current)) {
                                    tex_aux_check_source(current, list, 1);
                                } 
                                break;
                            }
                    }
                    if (get_noad_left_class(current) != unset_noad_class) {
                        current_subtype = get_noad_left_class(current);
                    } else if (get_noad_main_class(current) != unset_noad_class) {
                        current_subtype = get_noad_main_class(current);
                    }
                }
                break;
            case radical_noad:
                switch (node_subtype(current)) {
                    case normal_radical_subtype:
                    case radical_radical_subtype:
                    case root_radical_subtype:
                    case rooted_radical_subtype:
                    case delimited_radical_subtype:
                        current_type = simple_noad;
                        current_subtype = radical_noad_subtype;
                        break;
                    case under_delimiter_radical_subtype:
                    case delimiter_under_radical_subtype:
                        current_type = simple_noad;
                        current_subtype = under_noad_subtype;
                        break;
                    case over_delimiter_radical_subtype:
                    case delimiter_over_radical_subtype:
                        current_type = simple_noad;
                        current_subtype = over_noad_subtype;
                        break;
                    case h_extensible_radical_subtype:
                        current_type = simple_noad;
                        current_subtype = accent_noad_subtype;
                        break;
                }
                break;
            case accent_noad:
                current_type = simple_noad; /*tex Same kind of fields. */
                current_subtype = accent_noad_subtype;
                current_left_slack = noad_left_slack(current);
                current_right_slack = noad_right_slack(current);
                break;
            case fraction_noad:
                current_type = simple_noad; /*tex Same kind of fields. */
                current_subtype = fraction_noad_subtype; /* inner_noad_type */
                break;
            case fence_noad:
                /*tex Here we have a left, right, middle */
                current_type = simple_noad; /*tex Same kind of fields. */
                current_subtype = noad_analyzed(current);
                packedfence = current;
                break;
            case style_node:
                tex_aux_make_style(current, &current_style, &current_mu);
                recent = current;
                current = node_next(current);
                tex_aux_wipe_noad(recent);
                goto RESTART;
            case parameter_node:
                tex_def_math_parameter(node_subtype(current), parameter_name(current), parameter_value(current), cur_level + lmt_math_state.level, indirect_math_regular);
                recent = current;
                current = node_next(current);
                tex_aux_wipe_noad(recent);
                goto RESTART;
            case glue_node:
                switch (node_subtype(current)) {
                    case conditional_math_glue:
                    case rulebased_math_glue:
                        {
                            halfword t = current;
                            current = node_next(current);
                            tex_flush_node(t);
                            goto MOVEON;
                        }
                    default:
                        break;
                }
            // case glyph_node:
            case disc_node:
            case hlist_node:
            case boundary_node:
            case whatsit_node:
            case penalty_node:
            case rule_node:
            case adjust_node:
            case insert_node:
            case mark_node:
            case par_node:
            case kern_node:
                tex_couple_nodes(p, current);
                p = current;
                current = node_next(current);
                node_next(p) = null;
              MOVEON:
                if (current) {
                    /*tex These nodes are invisible! */
                    switch (node_type(p)) {
                        case boundary_node:
                        case adjust_node:
                        case insert_node:
                        case mark_node:
                        case par_node:
                            goto HERE;
                        case rule_node:
                            if (node_subtype(p) == strut_rule_subtype) {
                                goto HERE;
                            }
                    }
                }
                continue;
                //  goto NEXT_NODE;
            default:
                tex_confusion("mlist to hlist, case 2");
        }
        /*tex
            Apply some logic. The hard coded pairwise comparison is replaced by a generic one
            because we can have more classes. For a while spacing and pairing was under a mode
            control but that made no sense. We start with the begin class.  
        */
        recent_class_overload = get_noad_right_class(current);
        if (current_type == simple_noad && state->beginclass == unset_noad_class) {
            if (noad_new_hlist(current)) { 
                tex_flush_node(noad_new_hlist(current));
                noad_new_hlist(current) = null;
            }
            state->beginclass = current_subtype;
            /* */
            recent_type = current_type;
            recent_subtype = current_subtype;
            recent = current;
            current = node_next(current);
            goto WIPE;
        }
        /*tex 
            This is a special case where a sign starts something marked as (like) numeric, in 
            which there will be different spacing applied. 
        */
        if (tex_math_has_class_option(current_subtype, look_ahead_for_end_class_option)) {
            halfword endhack = node_next(current);
            if (endhack && node_type(endhack) == simple_noad && (node_subtype(endhack) == math_end_class || get_noad_main_class(endhack) == math_end_class)) {
                halfword value = tex_aux_math_ruling(current_subtype, math_end_class, current_style);
                if (value != MATHPARAMDEFAULT) {
                    // recent_subtype = (value >> 16) & 0xFF;
                    // current_subtype = value & 0xFF;
                    current_subtype = (value >> 16) & 0xFF;
                }

            }
        }
        old_recent = recent_subtype;
        old_current = current_subtype;
        if (current_subtype != unset_noad_class && recent_subtype != unset_noad_class && current_type == simple_noad) {
            if (recent_type == simple_noad && ! has_noad_option_noruling(current)) {
                halfword value = tex_aux_math_ruling(recent_subtype, current_subtype, current_style);
                if (value != MATHPARAMDEFAULT) {
                    recent_subtype = (value >> 16) & 0xFF;
                    current_subtype = value & 0xFF;
                }
            }
            if (tracing_math_par >= 2) {
                tex_begin_diagnostic();
                if (old_recent != recent_subtype || old_current != current_subtype) {
                    tex_print_format("[math: atom ruling, recent %n, current %n, new recent %n, new current %n]", old_recent, old_current, recent_subtype, current_subtype);
                } else {
                    tex_print_format("[math: atom ruling, recent %n, current %n]", old_recent, old_current);
                }
                tex_end_diagnostic();
            }
        }
        /*tex Now we set the inter-atom penalties: */
        if (ghost && ! has_noad_option_right(ghost)) {
            p = tex_aux_append_ghost(ghost, p);
            ghost = null;
        }
        if (current_type == simple_noad) {
            pre_penalty = tex_aux_math_penalty(state->main_style, 1, current_subtype);
            post_penalty = tex_aux_math_penalty(state->main_style,0, current_subtype);
        }
        /*tex Dirty trick: */ /* todo: use kerns info */
        current_plus_glyph = tex_aux_get_plus_glyph(current);
        /*tex Append inter-element spacing based on |r_type| and |t| */
        if (current_plus_glyph && recent_script_state) {
            /*tex This is a very special case and used {x^2 / 3| kind of situations: */
            halfword plus = tex_aux_checked_left_kern(current_plus_glyph, recent_script_state, current_subtype);
            if (plus) {
                halfword kern = tex_new_kern_node(plus, math_shape_kern_subtype);
                tex_attach_attribute_list_copy(kern, current);
                tex_couple_nodes(p, kern);
                p = kern;
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: state driven left shape kern %p]", plus, pt_unit);
                    tex_end_diagnostic();
                }
            }
        }
        if (recent_type > 0) {
            halfword last = node_type(p); /* can be temp */
            halfword glue = tex_aux_math_spacing_glue(recent_subtype, current_subtype, current_style, current_mu);
            halfword kern = null;
            if (glue) {
                tex_attach_attribute_list_copy(glue, current);
            }
            if (recent_right_slack) {
                halfword kern = tex_new_kern_node(-recent_right_slack, horizontal_math_kern_subtype);
                tex_attach_attribute_list_copy(kern, current);
                tex_couple_nodes(p, kern);
                p = kern;
                if (current_subtype >= 0 && tex_math_has_class_option(current_subtype, no_pre_slack_class_option)) {
                    /* */
                } else if (! glue) {
                    glue = tex_aux_math_dimen(recent_right_slack, inter_math_skip_glue, -2);
                } else {
                    glue_amount(glue) += recent_right_slack;
                }
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: migrating right slack %p]", recent_right_slack, pt_unit);
                    tex_end_diagnostic();
                }
                recent_right_slack = 0;
            }
            if (recent_plus_glyph && current_script_state) {
                /*tex This is a very special case and used {x^2 / 3| kind of situations: */
                halfword plus = tex_aux_checked_right_kern(recent_plus_glyph, current_script_state, recent_subtype);
                if (plus) {
                    halfword kern = tex_new_kern_node(plus, math_shape_kern_subtype);
                    tex_attach_attribute_list_copy(kern, current);
                    tex_couple_nodes(p, kern);
                    p = kern;
                    if (tracing_math_par >= 2) {
                        tex_begin_diagnostic();
                        tex_print_format("[math: state driven right shape kern %p]", plus, pt_unit);
                        tex_end_diagnostic();
                    }
                }
            }
            if (current_left_slack) {
                kern = tex_new_kern_node(-current_left_slack, horizontal_math_kern_subtype);
                tex_attach_attribute_list_copy(kern, p);
                /* tex_couple_nodes(node_prev(p), kern); */ /* close to the molecule */
                /* tex_couple_nodes(kern, p);            */ /* close to the molecule */
                if (recent_subtype >= 0 && tex_math_has_class_option(recent_subtype, no_post_slack_class_option)) {
                    /* */
                } else if (! glue) {
                    glue = tex_aux_math_dimen(current_left_slack, inter_math_skip_glue, -1);
                } else {
                    glue_amount(glue) += current_left_slack;
                }
                current_left_slack = 0;
            }
            /*tex
                Do we still want this check in infinite. 
            */
            if (state->penalties && pre_penalty < infinite_penalty && node_type(last) != penalty_node) {
                /*tex no checking of prev node type */
                halfword penalty = tex_new_penalty_node(pre_penalty, math_pre_penalty_subtype);
                tex_attach_attribute_list_copy(penalty, current);
                tex_couple_nodes(p, penalty);
                p = penalty;
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: pre penalty, left %n, right %n, amount %i]", recent_subtype, current_subtype, penalty_amount(penalty));
                    tex_end_diagnostic();
                }
            }
            if (tex_math_has_class_option(current_subtype, remove_italic_correction_class_option)) {
                if (node_type(p) == kern_node && node_subtype(p) == italic_kern_subtype) {
                    halfword prv = node_prev(p);
                    if (prv) {
                        if (tracing_math_par >= 2) {
                            tex_begin_diagnostic();
                            tex_print_format("[math: removing italic correction %D between %i and %i]", kern_amount(p), recent_subtype, current_subtype);
                            tex_end_diagnostic();
                        }
                        tex_flush_node(p);
                        p = prv;
                    }
                }
            }
            if (glue) {
                tex_couple_nodes(p, glue);
                p = glue;
            }
            if (kern) {
                tex_couple_nodes(p, kern);
                p = kern;
            }
        }
        if (ghost) {
            p = tex_aux_append_ghost(ghost, p);
            ghost = null;
        }
        {
            halfword l = noad_new_hlist(current);
            if (! l) { 
                /* curious */
            } else if (node_type(l) == hlist_node && box_source_anchor(l)) {
                tex_couple_nodes(p, l);
            } else if (packedfence) { 
                /*tex This branch probably can go away, see below. */
                /*tex Watch out: we can have |[prescripts] [fencelist] [postscripts]| */
                if (tex_math_has_class_option(fenced_noad_subtype, unpack_class_option)) {
                    p = tex_aux_unroll_noad(p, l, math_fence_list);
                } else { 
                    tex_couple_nodes(p, l);
                }
            } else if ((current_subtype == open_noad_subtype || current_subtype == fenced_noad_subtype) && tex_math_has_class_option(fenced_noad_subtype, unpack_class_option)) {
                /*tex tricky as we have an open subtype for spacing now. */
                p = tex_aux_unroll_noad(p, l, math_fence_list);
            } else if (has_noad_option_unpacklist(current) || tex_math_has_class_option(current_subtype, unpack_class_option)) {
                /*tex So here we only unpack a math list. */
                p = tex_aux_unroll_noad(p, l, math_list_list);
            } else if (has_noad_option_unrolllist(current)) {
                p = tex_aux_unroll_list(p, l);
            } else if (tex_is_math_disc(l)) {
                /* hm, temp nodes here */
                tex_couple_nodes(p, box_list(l));
                box_list(l) = null;
                tex_flush_node(l);
            } else if (current_type == simple_noad && current_subtype == math_end_class) {
                 if (noad_new_hlist(current)) { 
                      tex_flush_node(noad_new_hlist(current));
                      noad_new_hlist(current) = null;
                 }
            } else {
                tex_couple_nodes(p, l);
            }
            p = tex_tail_of_node_list(p);
            if (fenced) {
                if (get_noad_right_class(fenced) != unset_noad_class) {
                    current_subtype = get_noad_right_class(fenced);
                } else if (get_noad_main_class(fenced) != unset_noad_class) { // needs testing by MS
                    current_subtype = get_noad_main_class(fenced);
                } else {
                    current_subtype = close_noad_subtype; /* safeguard, see comment above */
                }
                fenced = null;
            }
            noad_new_hlist(current) = null;
            packedfence = null;
        }
        /*tex
            Append any |new_hlist| entries for |q|, and any appropriate penalties. We insert a
            penalty node after the hlist entries of noad |q| if |pen| is not an \quote {infinite}
            penalty, and if the node immediately following |q| is not a penalty node or a
            |rel_noad| or absent entirely. We could combine more here but for beter understanding
            we keep the branches seperated. This code is not performance sentitive anyway.

            We can actually drop the omit check because we pair by class. 
        */
        if (state->penalties && node_next(current) && post_penalty < infinite_penalty) {
            halfword recent = node_next(current);
            recent_type = node_type(recent);
            recent_subtype = node_subtype(recent);
            /* todo: maybe also check the mainclass of the recent  */
            if ((recent_type != penalty_node) && ! (recent_type == simple_noad && tex_math_has_class_option(recent_subtype, omit_penalty_class_option))) {
                halfword z = tex_new_penalty_node(post_penalty, math_post_penalty_subtype);
                tex_attach_attribute_list_copy(z, current);
                tex_couple_nodes(p, z);
                p = z;
                if (tracing_math_par >= 2) {
                    tex_begin_diagnostic();
                    tex_print_format("[math: post penalty, left %n, right %n, amount %i]", recent_subtype, current_subtype, penalty_amount(z));
                    tex_end_diagnostic();
                }
            }
        }
        if (recent_class_overload != unset_noad_class) {
            current_type = simple_noad;
            current_subtype = recent_class_overload;
        }
        if (current_type == simple_noad && current_subtype != math_end_class) {
            state->endclass = current_subtype;
        }
        recent_type = current_type;
        recent_subtype = current_subtype;
        recent_left_slack = current_left_slack;
        recent_right_slack = current_right_slack;
        recent_script_state = current_script_state;
        recent_plus_glyph = current_plus_glyph;
        // if (first && recent_left_slack) {
        if (p == temp_head && recent_left_slack) {
            halfword k = tex_new_kern_node(-recent_left_slack, horizontal_math_kern_subtype);
            halfword h = node_next(temp_head);
            tex_attach_attribute_list_copy(k, p);
            tex_couple_nodes(k, h);
            node_next(temp_head) = k;
            if (tracing_math_par >= 2) {
                tex_begin_diagnostic();
                tex_print_format("[math: nilling recent left slack %p]", recent_left_slack);
                tex_end_diagnostic();
            }
        }
        recent = current;
        current = node_next(current);
        if (! current && recent_right_slack) {
            halfword k = tex_new_kern_node(-recent_right_slack, horizontal_math_kern_subtype);
            tex_attach_attribute_list_copy(k, p);
            tex_couple_nodes(p, k);
            p = k;
            if (tracing_math_par >= 2) {
                tex_begin_diagnostic();
                tex_print_format("[math: nilling recent right slack %p]", recent_right_slack);
                tex_end_diagnostic();
            }
        }
        // first = 0;
        /*tex
            The m|-|to|-|hlist conversion takes place in|-|place, so the various dependant fields
            may not be freed (as would happen if |flush_node| was called). A low|-|level |free_node|
            is easier than attempting to nullify such dependant fields for all possible node and
            noad types.
        */
      WIPE:
        tex_aux_wipe_noad(recent);
    }
    if (tracing_math_par >= 3) {
        tex_aux_show_math_list("[math: result, level %i]", node_next(temp_head));
    }
}

halfword tex_mlist_to_hlist(halfword mlist, int penalties, int main_style, int beginclass, int endclass, kernset *kerns) /* classes should be quarterwords */
{
    /*tex
        We start with a little housekeeping. There are now only two variables that live across the
        two passes. We actually could split this function in two. For practical reasons we have 
        collected all relevant state parameters in a structure. The values in there can be adapted 
        in this state. 
    */
    mliststate state;
    state.mlist = mlist;
    state.penalties = penalties;
    state.main_style = main_style;
    state.beginclass = beginclass == unset_noad_class ? math_begin_class : beginclass;
    state.endclass = endclass == unset_noad_class ? math_end_class : endclass;
    state.kerns = kerns;
    state.scale = glyph_scale_par;
    state.max_height = 0;
    state.max_depth = 0;
    if (state.kerns) { 
        tex_math_wipe_kerns(state.kerns);
    }
    ++lmt_math_state.level;
    /*tex
        Here we can deal with end_class spacing: we can inject a dummy current atom with no content and
        just a class. In fact, we can always add a begin and endclass. A nucleus is kind of mandate. 
    */
    tex_mlist_to_hlist_set_boundaries(&state);
    /*tex
        This first pass processes the bodies of radicals so that we can normalize them when height
        and/or depth are set.
    */
    tex_mlist_to_hlist_preroll_radicals(&state);
    /*
        Make a second pass over the mlist. This is needed in order to get the maximum height and 
        depth in order to make fences match.
    */
    tex_mlist_to_hlist_preroll_dimensions(&state);
    /*tex
        The fence sizing is done in the third pass. Using a dedicated pass permits experimenting.
    */
    tex_mlist_to_hlist_size_fences(&state);
    /*tex
        Make a fourth pass over the mlist; traditionally this was the second pass. We removing all 
        noads and insert the proper spacing (glue) and penalties. The binary checking is gone and 
        replaced by generic arbitrary inter atom mapping control, so for the hard coded older logic 
        one has to check the (development) git repository.

        The original comment for this pass is: \quotation {We have now tied up all the loose ends of 
        the first pass of |mlist_to_hlist|. The second pass simply goes through and hooks everything 
        together with the proper glue and penalties. It also handles the |fence_noad|s that might be 
        present, since |max_hl| and |max_d| are now known. Variable |p| points to a node at the 
        current end of the final hlist.} However, in \LUAMETATEX\ the fence sizing has already be 
        done in the previous pass. 
    */
    tex_mlist_to_hlist_finalize_list(&state);
    /*tex
        We're done now and can restore the possibly changed values as well as provide some feedback
        about the result.
    */
    tex_unsave_math_data(cur_level + lmt_math_state.level);
    cur_list.math_begin = state.beginclass;
    cur_list.math_end = state.endclass;
    glyph_scale_par = state.scale;
    --lmt_math_state.level;
    node_prev(node_next(temp_head)) = null;
    return node_next(temp_head);
}
