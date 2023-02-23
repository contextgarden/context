/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXMATH_H
# define LMT_TEXMATH_H

/*tex
    This module also deals with math parameters. That code has been cleaned up a lot, and it
    worked out well, but at some point Mikael Sundqvist and I entered \quutation {alternative
    spacing models mode} and a more generic model was implemented. As a consequence new code
    showed up and already cleaned up code (the many parameters) could be thrown out. That's how
    it goed and it is in retrospect good that we had not yet released.

*/

# define MATHPARAMSTACK   8
# define MATHPARAMDEFAULT undefined_math_parameter

# define MATHFONTSTACK   8
# define MATHFONTDEFAULT 0

typedef struct math_state_info {
    int      size;        /*tex Size code corresponding to |cur_style|. */
    int      level;       /*tex Maybe we should expose this one. */
    sa_tree  par_head;
    sa_tree  fam_head;
    halfword last_left;
    halfword last_right;
    scaled   last_atom;  
    scaled   scale;        
} math_state_info;

extern math_state_info lmt_math_state;

typedef enum math_sizes {
    text_size,
    script_size,
    script_script_size
} math_sizes;

# define last_math_size script_script_size

# define undefined_math_parameter max_dimen

typedef enum math_indirect_types {
    indirect_math_unset,
    indirect_math_regular,
    indirect_math_integer,
    indirect_math_dimension,
    indirect_math_gluespec,
    indirect_math_mugluespec,
    indirect_math_register_integer,
    indirect_math_register_dimension,
    indirect_math_register_gluespec,
    indirect_math_register_mugluespec,
    indirect_math_internal_integer,
    indirect_math_internal_dimension,
    indirect_math_internal_gluespec,
    indirect_math_internal_mugluespec,
} math_indirect_types;

# define last_math_indirect indirect_math_internal_mugluespec

typedef enum math_parameter_types {
    math_int_parameter,
    math_dimen_parameter,
    math_muglue_parameter,
    math_style_parameter,
    math_pair_parameter,
} math_parameter_types;

typedef enum math_parameters {
    math_parameter_quad,
    math_parameter_axis,
    math_parameter_accent_base_height,
    math_parameter_accent_base_depth,
    math_parameter_flattened_accent_base_height,
    math_parameter_flattened_accent_base_depth,
    math_parameter_x_scale,
    math_parameter_y_scale,
    math_parameter_operator_size,
    math_parameter_overbar_kern,
    math_parameter_overbar_rule,
    math_parameter_overbar_vgap,
    math_parameter_underbar_kern,
    math_parameter_underbar_rule,
    math_parameter_underbar_vgap,
    math_parameter_radical_kern,
    math_parameter_radical_rule,
    math_parameter_radical_vgap,
    math_parameter_radical_degree_before,
    math_parameter_radical_degree_after,
    math_parameter_radical_degree_raise,
    math_parameter_radical_extensible_after,
    math_parameter_radical_extensible_before,
    math_parameter_stack_vgap,
    math_parameter_stack_num_up,
    math_parameter_stack_denom_down,
    math_parameter_fraction_rule,
    math_parameter_fraction_num_vgap,
    math_parameter_fraction_num_up,
    math_parameter_fraction_denom_vgap,
    math_parameter_fraction_denom_down,
    math_parameter_fraction_del_size,
    math_parameter_skewed_fraction_hgap,
    math_parameter_skewed_fraction_vgap,
    math_parameter_limit_above_vgap,
    math_parameter_limit_above_bgap,
    math_parameter_limit_above_kern,
    math_parameter_limit_below_vgap,
    math_parameter_limit_below_bgap,
    math_parameter_limit_below_kern,
    math_parameter_nolimit_sub_factor, /*tex bonus */
    math_parameter_nolimit_sup_factor, /*tex bonus */
    math_parameter_under_delimiter_vgap,
    math_parameter_under_delimiter_bgap,
    math_parameter_over_delimiter_vgap,
    math_parameter_over_delimiter_bgap,
    math_parameter_subscript_shift_drop,
    math_parameter_superscript_shift_drop,
    math_parameter_subscript_shift_down,
    math_parameter_subscript_superscript_shift_down,
    math_parameter_subscript_top_max,
    math_parameter_superscript_shift_up,
    math_parameter_superscript_bottom_min,
    math_parameter_superscript_subscript_bottom_max,
    math_parameter_subscript_superscript_vgap,
    math_parameter_space_before_script,
    math_parameter_space_after_script,
    math_parameter_connector_overlap_min,
    /* */
    math_parameter_extra_superscript_shift,
    math_parameter_extra_subscript_shift,
    math_parameter_extra_superprescript_shift,
    math_parameter_extra_subprescript_shift,
    /* */
    math_parameter_prime_raise,
    math_parameter_prime_raise_composed,
    math_parameter_prime_shift_up,
    math_parameter_prime_shift_drop,
    math_parameter_prime_space_after,
    math_parameter_prime_width,
    /* */
    math_parameter_rule_height,
    math_parameter_rule_depth,
    /* */
    math_parameter_superscript_shift_distance,
    math_parameter_subscript_shift_distance,
    math_parameter_superprescript_shift_distance,
    math_parameter_subprescript_shift_distance,
    /* */
    math_parameter_extra_superscript_space,
    math_parameter_extra_subscript_space,
    math_parameter_extra_superprescript_space,
    math_parameter_extra_subprescript_space,
    /* */
    math_parameter_skewed_delimiter_tolerance,
    /* */
    math_parameter_accent_top_shift_up,
    math_parameter_accent_bottom_shift_down,
    math_parameter_accent_top_overshoot,
    math_parameter_accent_bottom_overshoot,
    math_parameter_accent_superscript_drop,
    math_parameter_accent_superscript_percent,
    math_parameter_accent_extend_margin,
    math_parameter_flattened_accent_top_shift_up,
    math_parameter_flattened_accent_bottom_shift_down,
    /* */
    math_parameter_delimiter_percent,
    math_parameter_delimiter_shortfall,
    math_parameter_delimiter_extend_margin,
    /* */
    math_parameter_over_line_variant,
    math_parameter_under_line_variant,
    math_parameter_over_delimiter_variant,
    math_parameter_under_delimiter_variant,
    math_parameter_delimiter_over_variant,
    math_parameter_delimiter_under_variant,
    math_parameter_h_extensible_variant,
    math_parameter_v_extensible_variant,
    math_parameter_fraction_variant,
    math_parameter_radical_variant,
    math_parameter_accent_variant,
    math_parameter_degree_variant,
    math_parameter_top_accent_variant,
    math_parameter_bottom_accent_variant,
    math_parameter_overlay_accent_variant,
    math_parameter_numerator_variant,
    math_parameter_denominator_variant,
    math_parameter_superscript_variant,
    math_parameter_subscript_variant,
    math_parameter_prime_variant,
    math_parameter_stack_variant,
    /* */
    /*tex The growing list of |math_parameter_ATOM1_ATOM2_spacing| is gone. */
    /* */
    math_parameter_last = 255,
    math_parameter_atom_pairs_first = math_parameter_last             + 1,
    math_parameter_atom_pairs_last  = math_parameter_atom_pairs_first + (max_n_of_math_classes * max_n_of_math_classes),
    math_parameter_atom_rules_first = math_parameter_atom_pairs_last  + 1,
    math_parameter_atom_rules_last  = math_parameter_atom_rules_first + (max_n_of_math_classes * max_n_of_math_classes),
    /* a special private one */
    math_parameter_reset_spacing,
    math_parameter_set_spacing,
    math_parameter_let_spacing,
    math_parameter_copy_spacing,
    math_parameter_set_atom_rule,
    math_parameter_let_atom_rule,
    math_parameter_copy_atom_rule,
    math_parameter_let_parent,
    math_parameter_copy_parent,
    math_parameter_set_pre_penalty,
    math_parameter_set_post_penalty,
    math_parameter_set_display_pre_penalty,
    math_parameter_set_display_post_penalty,
    math_parameter_ignore,
    math_parameter_options,
    math_parameter_set_defaults,
} math_parameters;

# define math_parameter_max_range (16 * 1024)  // 4 * (max_n_of_math_classes * max_n_of_math_classes)

# define math_parameter_spacing_pair(l,r) (math_parameter_atom_pairs_first + (l * max_n_of_math_classes) + r)
# define math_parameter_rules_pair(l,r)   (math_parameter_atom_rules_first + (l * max_n_of_math_classes) + r)

# define math_parameter_spacing_left(n)  ((n - math_parameter_atom_pairs_first) / max_n_of_math_classes)
# define math_parameter_spacing_right(n) ((n - math_parameter_atom_pairs_first) % max_n_of_math_classes)

# define math_parameter_rules_left(n)    ((n - math_parameter_atom_rules_first) / max_n_of_math_classes)
# define math_parameter_rules_right(n)   ((n - math_parameter_atom_rules_first) % max_n_of_math_classes)

# define ignore_math_parameter(n)   (count_parameter(first_math_ignore_code + n))
# define options_math_parameter(n)  (count_parameter(first_math_options_code + n))

# define math_all_class    (max_n_of_math_classes - 3)
# define math_begin_class  (max_n_of_math_classes - 2)
# define math_end_class    (max_n_of_math_classes - 1)

# define valid_math_class_code(n)  (n >= 0 && n < max_n_of_math_classes)

# define last_math_parameter               math_parameter_stack_variant
# define math_parameter_first_variant      math_parameter_over_line_variant
# define math_parameter_last_variant       math_parameter_stack_variant
# define math_default_spacing_parameter    math_parameter_spacing_pair(ordinary_noad_subtype,ordinary_noad_subtype)
# define math_default_rules_parameter      0

typedef enum math_class_options {
    no_pre_slack_class_option                 = 0x0000001,
    no_post_slack_class_option                = 0x0000002,
    left_top_kern_class_option                = 0x0000004,
    right_top_kern_class_option               = 0x0000008,
    left_bottom_kern_class_option             = 0x0000010,
    right_bottom_kern_class_option            = 0x0000020,
    look_ahead_for_end_class_option           = 0x0000040,
    no_italic_correction_class_option         = 0x0000080,
    check_ligature_class_option               = 0x0000100,
    check_italic_correction_class_option      = 0x0000200,
    check_kern_pair_class_option              = 0x0000400,
    flatten_class_option                      = 0x0000800,
    omit_penalty_class_option                 = 0x0001000,
    unpack_class_option                       = 0x0002000,
    raise_prime_option                        = 0x0004000,
 // open_fence_class_option                   = 0x0000100,
 // close_fence_class_option                  = 0x0000200,
 // middle_fence_class_option                 = 0x0000400,
    carry_over_left_top_kern_class_option     = 0x0008000,
    carry_over_right_top_kern_class_option    = 0x0010000,
    carry_over_left_bottom_kern_class_option  = 0x0020000,
    carry_over_right_bottom_kern_class_option = 0x0040000,
    prefer_delimiter_dimensions_class_option  = 0x0080000,
    auto_inject_class_option                  = 0x0100000,
    remove_italic_correction_class_option     = 0x0200000,
    operator_italic_correction_class_option   = 0x0400000,
    no_class_options                          = 0xF000000,
} math_class_options;

extern int tex_math_has_class_option(halfword cls, int option);

typedef enum math_atom_font_options {
    math_atom_no_font_option   = 0,
    math_atom_text_font_option = 1,
    math_atom_math_font_option = 2,
} math_atom_font_options;

inline static int math_parameter_value_type(int n)
{
    if (n < last_math_parameter) {
        return lmt_interface.math_parameter_values[n].type;
    } else if (n >= math_parameter_atom_rules_first && n <= math_parameter_atom_rules_last) {
        return math_pair_parameter;
    } else {
        return math_muglue_parameter;
    }
}

/*tex
    We used to have a lot of defines like:

    \starttyping
    # define math_parameter_A_B_spacing  math_parameter_spacing_pair(A_noad_subtype,B_noad_subtype)
    \stoptyping

    but we now inline them as they are only used once.

*/

/*tex

    We also need to compute the change in style between mlists and their subsidiaries. The following
    macros define the subsidiary style for an overlined nucleus (|cramped_style|), for a subscript
    or a superscript (|sub_style| or |sup_style|), or for a numerator or denominator (|num_style| or
    |denom_style|). We now delegate that to a helper function so that eventually we can symbolic
    presets.

*/

typedef enum math_style_variants {
    math_normal_style_variant,
    math_cramped_style_variant,
    math_subscript_style_variant,
    math_superscript_style_variant,
    math_small_style_variant,
    math_smaller_style_variant,
    math_numerator_style_variant,
    math_denominator_style_variant,
    math_double_superscript_variant,
} math_style_variants;

# define last_math_style_variant math_double_superscript_variant

/*

These are the mandate font parameters: % https://docs.microsoft.com/en-us/typography/opentype/spec/math

\starttabulate[|T|p|]
\NC ScriptPercentScaleDown                   \NC Percentage of scaling down for level 1 superscripts and subscripts. Suggested value: 80 pct. \NC \NR
\NC ScriptScriptPercentScaleDown             \NC Percentage of scaling down for level 2 (scriptScript) superscripts and subscripts. Suggested value: 60 pct. \NC \NR
\NC DelimitedSubFormulaMinHeight             \NC Minimum height required for a delimited expression (contained within parentheses, etc.) to be treated as a sub-formula. Suggested value: normal line height × 1.5. \NC \NR
\NC DisplayOperatorMinHeight                 \NC Minimum height of n-ary operators (such as integral and summation) for formulas in display mode (that is, appearing as standalone page elements, not embedded inline within text). \NC \NR
\NC MathLeading                              \NC White space to be left between math formulas to ensure proper line spacing. For example, for applications that treat line gap as a part of line ascender, formulas with ink going above (os2.sTypoAscender + os2.sTypoLineGap - MathLeading) or with ink going below os2.sTypoDescender will result in increasing line height. \NC \NR
\NC AxisHeight                               \NC Axis height of the font. In math typesetting, the term axis refers to a horizontal reference line used for positioning elements in a formula. The math axis is similar to but distinct from the baseline for regular text layout. For example, in a simple equation, a minus symbol or fraction rule would be on the axis, but a string for a variable name would be set on a baseline that is offset from the axis. The axisHeight value determines the amount of that offset. \NC \NR
\NC AccentBaseHeight                         \NC Maximum (ink) height of accent base that does not require raising the accents. Suggested: x‑height of the font (os2.sxHeight) plus any possible overshots. \NC \NR
\NC FlattenedAccentBaseHeight                \NC Maximum (ink) height of accent base that does not require flattening the accents. Suggested: cap height of the font (os2.sCapHeight). \NC \NR
\NC SubscriptShiftDown                       \NC The standard shift down applied to subscript elements. Positive for moving in the downward direction. Suggested: os2.ySubscriptYOffset. \NC \NR
\NC SubscriptTopMax                          \NC Maximum allowed height of the (ink) top of subscripts that does not require moving subscripts further down. Suggested: 4/5 x- height. \NC \NR
\NC SubscriptBaselineDropMin                 \NC Minimum allowed drop of the baseline of subscripts relative to the (ink) bottom of the base. Checked for bases that are treated as a box or extended shape. Positive for subscript baseline dropped below the base bottom. \NC \NR
\NC SuperscriptShiftUp                       \NC Standard shift up applied to superscript elements. Suggested: os2.ySuperscriptYOffset. \NC \NR
\NC SuperscriptShiftUpCramped                \NC Standard shift of superscripts relative to the base, in cramped style. \NC \NR
\NC SuperscriptBottomMin                     \NC Minimum allowed height of the (ink) bottom of superscripts that does not require moving subscripts further up. Suggested: ¼ x-height. \NC \NR
\NC SuperscriptBaselineDropMax               \NC Maximum allowed drop of the baseline of superscripts relative to the (ink) top of the base. Checked for bases that are treated as a box or extended shape. Positive for superscript baseline below the base top. \NC \NR
\NC SubSuperscriptGapMin                     \NC Minimum gap between the superscript and subscript ink. Suggested: 4 × default rule thickness. \NC \NR
\NC SuperscriptBottomMaxWithSubscript        \NC The maximum level to which the (ink) bottom of superscript can be pushed to increase the gap between superscript and subscript, before subscript starts being moved down. Suggested: 4/5 x-height. \NC \NR
\NC SpaceAfterScript                         \NC Extra white space to be added after each subscript and superscript. Suggested: 0.5 pt for a 12 pt font. (Note that, in some math layout implementations, a constant value, such as 0.5 pt, may be used for all text sizes. Some implementations may use a constant ratio of text size, such as 1/24 of em.) \NC \NR
\NC UpperLimitGapMin                         \NC Minimum gap between the (ink) bottom of the upper limit, and the (ink) top of the base operator. \NC \NR
\NC UpperLimitBaselineRiseMin                \NC Minimum distance between baseline of upper limit and (ink) top of the base operator. \NC \NR
\NC LowerLimitGapMin                         \NC Minimum gap between (ink) top of the lower limit, and (ink) bottom of the base operator. \NC \NR
\NC LowerLimitBaselineDropMin                \NC Minimum distance between baseline of the lower limit and (ink) bottom of the base operator. \NC \NR
\NC StackTopShiftUp                          \NC Standard shift up applied to the top element of a stack. \NC \NR
\NC StackTopDisplayStyleShiftUp              \NC Standard shift up applied to the top element of a stack in display style. \NC \NR
\NC StackBottomShiftDown                     \NC Standard shift down applied to the bottom element of a stack. Positive for moving in the downward direction. \NC \NR
\NC StackBottomDisplayStyleShiftDown         \NC Standard shift down applied to the bottom element of a stack in display style. Positive for moving in the downward direction. \NC \NR
\NC StackGapMin                              \NC Minimum gap between (ink) bottom of the top element of a stack, and the (ink) top of the bottom element. Suggested: 3 × default rule thickness. \NC \NR
\NC StackDisplayStyleGapMin                  \NC Minimum gap between (ink) bottom of the top element of a stack, and the (ink) top of the bottom element in display style. Suggested: 7 × default rule thickness. \NC \NR
\NC StretchStackTopShiftUp                   \NC Standard shift up applied to the top element of the stretch stack. \NC \NR
\NC StretchStackBottomShiftDown              \NC Standard shift down applied to the bottom element of the stretch stack. Positive for moving in the downward direction. \NC \NR
\NC StretchStackGapAboveMin                  \NC Minimum gap between the ink of the stretched element, and the (ink) bottom of the element above. Suggested: same value as upperLimitGapMin. \NC \NR
\NC StretchStackGapBelowMin                  \NC Minimum gap between the ink of the stretched element, and the (ink) top of the element below. Suggested: same value as lowerLimitGapMin. \NC \NR
\NC FractionNumeratorShiftUp                 \NC Standard shift up applied to the numerator. \NC \NR
\NC FractionNumeratorDisplayStyleShiftUp     \NC Standard shift up applied to the numerator in display style. Suggested: same value as stackTopDisplayStyleShiftUp. \NC \NR
\NC FractionDenominatorShiftDown             \NC Standard shift down applied to the denominator. Positive for moving in the downward direction. \NC \NR
\NC FractionDenominatorDisplayStyleShiftDown \NC Standard shift down applied to the denominator in display style. Positive for moving in the downward direction. Suggested: same value as stackBottomDisplayStyleShiftDown. \NC \NR
\NC FractionNumeratorGapMin                  \NC Minimum tolerated gap between the (ink) bottom of the numerator and the ink of the fraction bar. Suggested: default rule thickness. \NC \NR
\NC FractionNumDisplayStyleGapMin            \NC Minimum tolerated gap between the (ink) bottom of the numerator and the ink of the fraction bar in display style. Suggested: 3 × default rule thickness. \NC \NR
\NC FractionRuleThickness                    \NC Thickness of the fraction bar. Suggested: default rule thickness. \NC \NR
\NC FractionDenominatorGapMin                \NC Minimum tolerated gap between the (ink) top of the denominator and the ink of the fraction bar. Suggested: default rule thickness. \NC \NR
\NC FractionDenomDisplayStyleGapMin          \NC Minimum tolerated gap between the (ink) top of the denominator and the ink of the fraction bar in display style. Suggested: 3 × default rule thickness. \NC \NR
\NC SkewedFractionHorizontalGap              \NC Horizontal distance between the top and bottom elements of a skewed fraction. \NC \NR
\NC SkewedFractionVerticalGap                \NC Vertical distance between the ink of the top and bottom elements of a skewed fraction. \NC \NR
\NC OverbarVerticalGap                       \NC Distance between the overbar and the (ink) top of he base. Suggested: 3 × default rule thickness. \NC \NR
\NC OverbarRuleThickness                     \NC Thickness of overbar. Suggested: default rule thickness. \NC \NR
\NC OverbarExtraAscender                     \NC Extra white space reserved above the overbar. Suggested: default rule thickness. \NC \NR
\NC UnderbarVerticalGap                      \NC Distance between underbar and (ink) bottom of the base. Suggested: 3 × default rule thickness. \NC \NR
\NC UnderbarRuleThickness                    \NC Thickness of underbar. Suggested: default rule thickness. \NC \NR
\NC UnderbarExtraDescender                   \NC Extra white space reserved below the underbar. Always positive. Suggested: default rule thickness. \NC \NR
\NC RadicalVerticalGap                       \NC Space between the (ink) top of the expression and the bar over it. Suggested: 1¼ default rule thickness. \NC \NR
\NC RadicalDisplayStyleVerticalGap           \NC Space between the (ink) top of the expression and the bar over it. Suggested: default rule thickness + ¼ x-height. \NC \NR
\NC RadicalRuleThickness                     \NC Thickness of the radical rule. This is the thickness of the rule in designed or constructed radical signs. Suggested: default rule thickness. \NC \NR
\NC RadicalExtraAscender                     \NC Extra white space reserved above the radical. Suggested: same value as radicalRuleThickness. \NC \NR
\NC RadicalKernBeforeDegree                  \NC Extra horizontal kern before the degree of a radical, if such is present. Suggested: 5/18 of em. \NC \NR
\NC RadicalKernAfterDegree                   \NC Negative kern after the degree of a radical, if such is present. Suggested: −10/18 of em. \NC \NR
\NC RadicalDegreeBottomRaisePercent          \NC Height of the bottom of the radical degree, if such is present, in proportion to the ascender of the radical sign. Suggested: 60 pct. \NC \NR
\stoptabulate

And these are our own, some are a bit older already but most were introduced when we (Mikael and 
Hans) overhauled the math engine. 

\starttabulate[|T|c|p|]
\NC MinConnectorOverlap               \NC 0         \NC \NC \NR
\NC SubscriptShiftDownWithSuperscript \NC inherited \NC \NC \NR
\NC FractionDelimiterSize             \NC undefined \NC \NC \NR
\NC FractionDelimiterDisplayStyleSize \NC undefined \NC \NC \NR
\NC NoLimitSubFactor                  \NC 0         \NC \NC \NR     
\NC NoLimitSupFactor                  \NC 0         \NC \NC \NR     
\NC AccentBaseDepth                   \NC reserved  \NC \NC \NR 
\NC FlattenedAccentBaseDepth          \NC reserved  \NC \NC \NR 
\NC SpaceBeforeScript                 \NC 0         \NC \NC \NR     
\NC PrimeRaisePercent                 \NC 0         \NC \NC \NR     
\NC PrimeShiftUp                      \NC 0         \NC \NC \NR     
\NC PrimeShiftUpCramped               \NC 0         \NC \NC \NR     
\NC PrimeSpaceAfter                   \NC 0         \NC \NC \NR     
\NC PrimeBaselineDropMax              \NC 0         \NC \NC \NR     
\NC PrimeWidthPercent                 \NC 0         \NC \NC \NR     
\NC SkewedDelimiterTolerance          \NC 0         \NC \NC \NR     
\NC AccentTopShiftUp                  \NC undefined \NC \NC \NR     
\NC AccentBottomShiftDown             \NC undefined \NC \NC \NR     
\NC AccentTopOvershoot                \NC 0         \NC \NC \NR     
\NC AccentBottomOvershoot             \NC 0         \NC \NC \NR     
\NC AccentSuperscriptDrop             \NC 0         \NC \NC \NR     
\NC AccentSuperscriptPercent          \NC 0         \NC \NC \NR     
\NC FlattenedAccentTopShiftUp         \NC undefined \NC \NC \NR     
\NC FlattenedAccentBottomShiftDown    \NC undefined \NC \NC \NR     
\NC DelimiterPercent                  \NC           \NC \NC \NR     
\NC DelimiterShortfall                \NC           \NC \NC \NR     
\stoptabulate

*/

typedef enum math_parameter_codes {
    /* official */
    ScriptPercentScaleDown = 1,
    ScriptScriptPercentScaleDown,
    DelimitedSubFormulaMinHeight,
    DisplayOperatorMinHeight,
    MathLeading,
    AxisHeight,
    AccentBaseHeight,
    FlattenedAccentBaseHeight,
    SubscriptShiftDown,
    SubscriptTopMax,
    SubscriptBaselineDropMin,
    SuperscriptShiftUp,
    SuperscriptShiftUpCramped,
    SuperscriptBottomMin,
    SuperscriptBaselineDropMax,
    SubSuperscriptGapMin,
    SuperscriptBottomMaxWithSubscript,
    SpaceAfterScript,
    UpperLimitGapMin,
    UpperLimitBaselineRiseMin,
    LowerLimitGapMin,
    LowerLimitBaselineDropMin,
    StackTopShiftUp,
    StackTopDisplayStyleShiftUp,
    StackBottomShiftDown,
    StackBottomDisplayStyleShiftDown,
    StackGapMin,
    StackDisplayStyleGapMin,
    StretchStackTopShiftUp,
    StretchStackBottomShiftDown,
    StretchStackGapAboveMin,
    StretchStackGapBelowMin,
    FractionNumeratorShiftUp,
    FractionNumeratorDisplayStyleShiftUp,
    FractionDenominatorShiftDown,
    FractionDenominatorDisplayStyleShiftDown,
    FractionNumeratorGapMin,
    FractionNumeratorDisplayStyleGapMin,
    FractionRuleThickness,
    FractionDenominatorGapMin,
    FractionDenominatorDisplayStyleGapMin,
    SkewedFractionHorizontalGap,
    SkewedFractionVerticalGap,
    OverbarVerticalGap,
    OverbarRuleThickness,
    OverbarExtraAscender,
    UnderbarVerticalGap,
    UnderbarRuleThickness,
    UnderbarExtraDescender,
    RadicalVerticalGap,
    RadicalDisplayStyleVerticalGap,
    RadicalRuleThickness,
    RadicalExtraAscender,
    RadicalKernBeforeDegree,
    RadicalKernAfterDegree,
    RadicalDegreeBottomRaisePercent,
    RadicalKernAfterExtensible,
    RadicalKernBeforeExtensible,
    /* unofficial */
    MinConnectorOverlap,
    SubscriptShiftDownWithSuperscript,
    FractionDelimiterSize,
    FractionDelimiterDisplayStyleSize,
    NoLimitSubFactor,                         
    NoLimitSupFactor,                         
    AccentBaseDepth,          /* reserved */
    FlattenedAccentBaseDepth, /* reserved */
    SpaceBeforeScript,                        
    PrimeRaisePercent,                        
    PrimeRaiseComposedPercent,                        
    PrimeShiftUp,                             
    PrimeShiftUpCramped,                      
    PrimeBaselineDropMax,                     
    PrimeSpaceAfter,                          
    PrimeWidthPercent,                        
    SkewedDelimiterTolerance,                 
    AccentTopShiftUp,                         
    AccentBottomShiftDown,                    
    AccentTopOvershoot,                       
    AccentBottomOvershoot,                    
    AccentSuperscriptDrop,                    
    AccentSuperscriptPercent,                 
    AccentExtendMargin,                 
    FlattenedAccentTopShiftUp,                
    FlattenedAccentBottomShiftDown,           
    DelimiterPercent,                       
    DelimiterShortfall,
    DelimiterExtendMargin,
    /* done */
    math_parameter_last_code,
} math_parameter_codes;

# define math_parameter_last_font_code    NoLimitSupFactor
# define math_parameter_first_engine_code SpaceBeforeScript

typedef enum display_skip_modes {
    display_skip_default,
    display_skip_always,
    display_skip_non_zero,
    display_skip_ignore,
} display_skip_modes;

typedef enum math_skip_modes {
    math_skip_surround_when_zero = 0, /*tex obey mathsurround when zero glue */
    math_skip_always_left        = 1,
    math_skip_always_right       = 2,
    math_skip_always_both        = 3,
    math_skip_always_surround    = 4, /*tex ignore, obey marthsurround */
    math_skip_ignore             = 5, /*tex all spacing disabled */
    math_skip_only_when_skip     = 6,
} math_skip_modes;

/*tex All kind of helpers: */

# define math_use_current_family_code math_component_variable_code
# define fam_par_in_range(fam)        ((fam >= 0) && (cur_fam_par < max_n_of_math_families))
# define cur_fam_par_in_range         ((cur_fam_par >= 0) && (cur_fam_par < max_n_of_math_families))

extern halfword tex_size_of_style                (halfword style);

extern halfword tex_to_math_spacing_parameter    (halfword left, halfword right);
extern halfword tex_to_math_rules_parameter      (halfword left, halfword right);

extern halfword tex_math_style_variant           (halfword style, halfword param);

extern void     tex_def_math_parameter           (int style, int param, scaled value, int level, int indirect);
extern scaled   tex_get_math_parameter           (int style, int param, halfword *type);
extern int      tex_has_math_parameter           (int style, int param);
extern scaled   tex_get_math_parameter_checked   (int style, int param);
extern scaled   tex_get_math_parameter_default   (int style, int param, scaled dflt);

extern scaled   tex_get_math_x_parameter         (int style, int param);
extern scaled   tex_get_math_x_parameter_checked (int style, int param);
extern scaled   tex_get_math_x_parameter_default (int style, int param, scaled dflt);

extern scaled   tex_get_math_y_parameter         (int style, int param);
extern scaled   tex_get_math_y_parameter_checked (int style, int param);
extern scaled   tex_get_math_y_parameter_default (int style, int param, scaled dflt);

extern scaled   tex_get_font_math_parameter      (int font, int size, int param);
extern scaled   tex_get_font_math_x_parameter    (int font, int size, int param);
extern scaled   tex_get_font_math_y_parameter    (int font, int size, int param);

extern void     tex_fixup_math_parameters        (int fam, int size, int fnt, int level);
extern void     tex_finalize_math_parameters     (void);
extern scaled   tex_get_math_quad_style          (int style);
extern scaled   tex_math_axis_size               (int size);
extern scaled   tex_get_math_quad_size           (int size);
extern scaled   tex_get_math_quad_size_scaled    (int size);

extern void     tex_initialize_math              (void);
extern void     tex_initialize_math_spacing      (void);

extern void     tex_set_display_styles           (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_text_styles              (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_main_styles              (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_script_styles            (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_script_script_styles     (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_all_styles               (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_split_styles             (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_unsplit_styles           (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_uncramped_styles         (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_set_cramped_styles           (halfword code, halfword value, halfword level, halfword indirect);
extern void     tex_reset_all_styles             (halfword level);

extern void     tex_dump_math_data               (dumpstream f);
extern void     tex_undump_math_data             (dumpstream f);
extern void     tex_unsave_math_data             (int level);

extern void     tex_math_copy_char_data          (halfword target, halfword source, int wipelist);

extern int      tex_show_math_node               (halfword n, int threshold, int max);
extern void     tex_flush_math                   (void);
extern int      tex_is_math_disc                 (halfword n);
extern halfword tex_math_make_disc               (halfword n);
extern int      tex_in_main_math_style           (halfword style);

extern halfword tex_new_sub_box                  (halfword n);
//     halfword tex_math_vcenter_group           (halfword n);
extern int      tex_fam_fnt                      (int fam, int size);
extern void     tex_def_fam_fnt                  (int fam, int size, int fnt, int level);
extern void     tex_scan_extdef_del_code         (int level, int extcode);
extern void     tex_scan_extdef_math_code        (int level, int extcode);
extern int      tex_current_math_style           (void);
extern int      tex_current_math_main_style      (void);
extern int      tex_scan_math_code_val           (halfword code, mathcodeval *mval, mathdictval *dval);
extern int      tex_scan_math_cmd_val            (mathcodeval *mval, mathdictval *dval);

extern halfword    tex_scan_math_spec            (int optional_equal);
extern halfword    tex_new_math_spec             (mathcodeval m, quarterword code);
extern halfword    tex_new_math_dict_spec        (mathdictval d, mathcodeval m, quarterword code);
extern mathcodeval tex_get_math_spec             (halfword s);
extern mathdictval tex_get_math_dict             (halfword s);
extern void        tex_run_math_math_spec        (void);
extern void        tex_run_text_math_spec        (void);

extern void     tex_set_default_math_codes       (void);

extern int      tex_check_active_math_char       (int character);
extern int      tex_pass_active_math_char        (int character);

/*tex The runners in maincontrol: */

extern void     tex_run_math_left_brace        (void);
extern void     tex_run_math_math_component    (void);
extern void     tex_run_math_modifier          (void);
extern void     tex_run_math_radical           (void);
extern void     tex_run_math_accent            (void);
extern void     tex_run_math_style             (void);
extern void     tex_run_math_choice            (void);
extern void     tex_run_math_script            (void);
extern void     tex_run_math_fraction          (void);
extern void     tex_run_math_fence             (void);
extern void     tex_run_math_initialize        (void);
extern void     tex_run_math_letter            (void);
extern void     tex_run_math_math_char_number  (void);
extern void     tex_run_text_math_char_number  (void);
extern void     tex_run_math_char_number       (void);
extern void     tex_run_math_delimiter_number  (void);
extern void     tex_run_math_equation_number   (void);
extern void     tex_run_math_shift             (void);
extern void     tex_run_math_italic_correction (void);

extern void     tex_finish_math_group          (void);
extern void     tex_finish_math_choice         (void);
extern void     tex_finish_math_fraction       (void);
extern void     tex_finish_math_radical        (void);
extern void     tex_finish_math_operator       (void);
extern void     tex_finish_display_alignment   (halfword head, halfword tail, halfword prevdepth);

typedef enum math_control_codes {
    math_control_use_font_control            = 0x000001, /* use the font flag, maybe for traditional, might go */
    math_control_over_rule                   = 0x000002,
    math_control_under_rule                  = 0x000004,
    math_control_radical_rule                = 0x000008,
    math_control_fraction_rule               = 0x000010,
    math_control_accent_skew_half            = 0x000020,
    math_control_accent_skew_apply           = 0x000040,
    math_control_apply_ordinary_kern_pair    = 0x000080,
    math_control_apply_vertical_italic_kern  = 0x000100,
    math_control_apply_ordinary_italic_kern  = 0x0000200,
    math_control_apply_char_italic_kern      = 0x0000400, /* traditional */
    math_control_rebox_char_italic_kern      = 0x0000800, /* traditional */
    math_control_apply_boxed_italic_kern     = 0x0001000,
    math_control_staircase_kern              = 0x0002000,
    math_control_apply_text_italic_kern      = 0x0004000,
    math_control_check_text_italic_kern      = 0x0008000,
    math_control_check_space_italic_kern     = 0x0010000,
    math_control_apply_script_italic_kern    = 0x0020000,
    math_control_analyze_script_nucleus_char = 0x0040000,
    math_control_analyze_script_nucleus_list = 0x0080000,
    math_control_analyze_script_nucleus_box  = 0x0100000, 
    math_control_accent_top_skew_with_offset = 0x0200000, 
    math_control_ignore_kern_dimensions      = 0x0400000, /* for bad fonts (like xits fence depths) */
    math_control_ignore_flat_accents         = 0x0800000, 
    math_control_extend_accents              = 0x1000000, 
    math_control_extend_delimiters           = 0x2000000, 
} math_control_codes;

/*tex This is what we use for \OPENTYPE\ in \CONTEXT: */

# define assumed_math_control ( \
    math_control_over_rule \
  | math_control_under_rule \
  | math_control_radical_rule \
  | math_control_fraction_rule \
  | math_control_accent_skew_half \
  | math_control_accent_skew_apply \
  | math_control_apply_ordinary_kern_pair \
  | math_control_apply_vertical_italic_kern \
  | math_control_apply_ordinary_italic_kern \
  | math_control_apply_boxed_italic_kern \
  | math_control_staircase_kern \
  | math_control_apply_text_italic_kern \
  | math_control_check_text_italic_kern \
  | math_control_apply_script_italic_kern \
  | math_control_analyze_script_nucleus_char \
  | math_control_analyze_script_nucleus_list \
  | math_control_analyze_script_nucleus_box \
  | math_control_accent_top_skew_with_offset \
)

/*tex
    In the process of improving the math engine several intermediate features have been
    added that were removed later. They were mostly an aid for testing but in the end it
    made no sense to keep them around. To some extend they could enforce compatibility
    but with most fonts being opentype now that is no longer feasible.

    \starttyping
    typedef enum math_flatten_codes {
        math_flatten_ordinary    = 0x01,
        math_flatten_binary      = 0x02,
        math_flatten_relation    = 0x04,
        math_flatten_punctuation = 0x08,
        math_flatten_inner       = 0x10,
    } math_flatten_codes;
    \stoptyping

*/

typedef enum saved_math_items {
    saved_math_item_direction = 0,
 /* saved_math_item_x_scale   = 1, */ /* this was an experiment */
 /* saved_math_item_y_scale   = 2, */ /* this was an experiment */
 /* saved_math_n_of_items     = 3, */
    saved_math_n_of_items     = 1,
} saved_math_items;

typedef enum saved_equation_number_items {
    saved_equation_number_item_location = 0,
    saved_equation_number_n_of_items    = 1,
} saved_equation_number_items;

typedef enum saved_choice_items {
    saved_choice_item_count = 0,
    saved_choice_n_of_items = 1,
} saved_choice_items;

typedef enum saved_fraction_items {
    saved_fraction_item_userstyle = 0,
    saved_fraction_item_autostyle = 1,
    saved_fraction_item_variant   = 2,
    saved_fraction_n_of_items     = 3,
} saved_fraction_items;

typedef enum saved_radical_items {
    saved_radical_degree_done = 0,
    saved_radical_style       = 1,
    saved_radical_n_of_items  = 2,
} saved_radical_items;

typedef enum saved_operator_items {
    saved_operator_item_variant = 0,
    saved_operator_n_of_items   = 1,
} saved_operator_items;

/*tex
    These items are for regular groups, ustacks, atoms and such. We could make dedicated items
    but in the end it means duplicatign code and we then also need to redo accents as these 
    check for the group, in which case we then have to intercept the lot. I might do it anyway. 
*/

typedef enum saved_math_group_items {
    saved_math_group_item_pointer = 0,
    saved_math_group_all_class    = 1,
    saved_math_group_n_of_items   = 2,
} saved_math_group_items;

# endif
