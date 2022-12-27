/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

halfword tex_aux_scan_rule_spec(rule_types t, halfword s)
{
    /*tex |width|, |depth|, and |height| all equal |null_flag| now */
    halfword rule = tex_new_rule_node((quarterword) s);
    halfword attr = node_attr(rule);
    switch (t) {
        case h_rule_type:
            rule_height(rule) = default_rule;
            rule_depth(rule) = 0;
            break;
        case v_rule_type:
        case m_rule_type:
            if (s == strut_rule_code) {
                rule_width(rule) = 0;
                node_subtype(rule) = strut_rule_subtype;
                rule_height(rule) = null_flag;
                rule_depth(rule) = null_flag;
            } else {
                rule_width(rule) = default_rule;
            }
            break;
    }
    while (1) {
        /*tex
            Maybe:

               h : "whdxylrWHDXYLR"
               v : "whdxytbWHDXYTB"
               m : "whdxylrtbWHDXYLRTB"

            but for now we are tolerant because internally it's left/right anyway.

        */
        switch (tex_scan_character("awhdxylrtbcfAWHDXYLRTBCF", 0, 1, 0)) {
            case 0:
                goto DONE;
            case 'a': case 'A':
                if (tex_scan_mandate_keyword("attr", 1)) {
                    halfword i = tex_scan_attribute_register_number();
                    halfword v = tex_scan_int(1, NULL);
                    if (eq_value(register_attribute_location(i)) != v) {
                        if (attr) {
                            attr = tex_patch_attribute_list(attr, i, v);
                        } else {
                            attr = tex_copy_attribute_list_set(tex_current_attribute_list(), i, v);
                        }
                    }
                }
                break;
            case 'w': case 'W':
                if (tex_scan_mandate_keyword("width", 1)) {
                    rule_width(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'h': case 'H':
                if (tex_scan_mandate_keyword("height", 1)) {
                    rule_height(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'd': case 'D':
                if (tex_scan_mandate_keyword("depth", 1)) {
                    rule_depth(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'l': case 'L':
                if (tex_scan_mandate_keyword("left", 1)) {
                    rule_left(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'r': case 'R':
                if (tex_scan_mandate_keyword("right", 1)) {
                    rule_right(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 't': case 'T': /* just because it's nicer */
                if (tex_scan_mandate_keyword("top", 1)) {
                    rule_left(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'b': case 'B': /* just because it's nicer */
                if (tex_scan_mandate_keyword("bottom", 1)) {
                    rule_right(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'x': case 'X':
                if (tex_scan_mandate_keyword("xoffset", 1)) {
                    rule_x_offset(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'y': case 'Y':
                if (tex_scan_mandate_keyword("yoffset", 1)) {
                    rule_y_offset(rule) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'f': case 'F':
                switch (tex_scan_character("aoAO", 0, 0, 0)) {
                    case 'o': case 'O':
                        if (tex_scan_mandate_keyword("font", 2)) {
                            tex_set_rule_font(rule, tex_scan_font_identifier(NULL));
                        }
                        break;
                    case 'a': case 'A':
                        if (tex_scan_mandate_keyword("fam", 2)) {
                            tex_set_rule_family(rule, tex_scan_math_family_number());
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("font|fam");
                        goto DONE;
                }
                break;
            case 'c': case 'C':
                if (tex_scan_mandate_keyword("char", 1)) {
                    rule_character(rule) = tex_scan_char_number(0);
                }
                break;
            default:
                goto DONE;
        }
    }
  DONE:
    node_attr(rule) = attr;
    if (t == v_rule_type && s == strut_rule_code) {
        tex_aux_check_text_strut_rule(rule, text_style);
    }
    return rule;
}

void tex_aux_run_vrule(void)
{
    tex_tail_append(tex_aux_scan_rule_spec(v_rule_type, cur_chr));
    cur_list.space_factor = 1000;
}

void tex_aux_run_hrule(void)
{
    tex_tail_append(tex_aux_scan_rule_spec(h_rule_type, cur_chr));
    cur_list.prev_depth = ignore_depth_criterium_par;
}

void tex_aux_run_mrule(void)
{
    tex_tail_append(tex_aux_scan_rule_spec(m_rule_type, cur_chr));
}

void tex_aux_check_math_strut_rule(halfword rule, halfword style)
{
    if (node_subtype(rule) == strut_rule_subtype) {
        scaled ht = rule_height(rule);
        scaled dp = rule_depth(rule);
        if (ht == null_flag || dp == null_flag) {
            halfword fnt = tex_get_rule_font(rule, style);
            halfword chr = rule_character(rule);
            if (fnt > 0 && chr && tex_char_exists(fnt, chr)) {
                if (ht == null_flag) {
                    ht = tex_math_font_char_ht(fnt, chr, style);
                }
                if (dp == null_flag) {
                    dp = tex_math_font_char_dp(fnt, chr, style);
                }
            } else {
                if (ht == null_flag) {
                    ht = tex_get_math_y_parameter(style, math_parameter_rule_height);
                }
                if (dp == null_flag) {
                    dp = tex_get_math_y_parameter(style, math_parameter_rule_depth);
                }
            }
            rule_height(rule) = ht;
            rule_depth(rule) = dp;
        }
    }
}

void tex_aux_check_text_strut_rule(halfword rule, halfword style)
{
    if (node_subtype(rule) == strut_rule_subtype) {
        scaled ht = rule_height(rule);
        scaled dp = rule_depth(rule);
        if (ht == null_flag || dp == null_flag) {
            halfword fnt = tex_get_rule_font(rule, style);
            halfword chr = rule_character(rule);
            if (fnt > 0 && chr && tex_char_exists(fnt, chr)) {
                if (ht == null_flag) {
                    ht = tex_char_height_from_font(fnt, chr);
                }
                if (dp == null_flag) {
                    dp = tex_char_depth_from_font(fnt, chr);
                }
            }
            rule_height(rule) = ht;
            rule_depth(rule) = dp;
        }
    }
}

halfword tex_get_rule_font(halfword n, halfword style)
{
    halfword fnt = rule_font(n);
    if (fnt > rule_font_fam_offset) {
        halfword fam = fnt - rule_font_fam_offset;
        if (fam_par_in_range(fam)) {
            fnt = tex_fam_fnt(fam, tex_size_of_style(style));
        }
   }
    if (fnt < 0 || fnt >= max_n_of_fonts) {
        return null_font;
    } else {
        return fnt;
    }
}

halfword tex_get_rule_family(halfword n)
{
    halfword fnt = rule_font(n);
    if (fnt > rule_font_fam_offset) {
        halfword fam = fnt - rule_font_fam_offset;
        if (fam_par_in_range(fam)) {
            return fam;
        }
   }
   return 0;
}

void tex_set_rule_font(halfword n, halfword fnt)
{
    if (fnt < 0 || fnt >= rule_font_fam_offset) {
        rule_font(n) = 0;
    } else {
        rule_font(n) = fnt;
    }
}

void tex_set_rule_family(halfword n, halfword fam)
{
    if (fam < 0 || fam >= max_n_of_math_families) {
        rule_font(n) = rule_font_fam_offset;
    } else {
        rule_font(n) = rule_font_fam_offset + fam;
    }
}

