/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex 

    We have a a limited set of codes (normal, empty, strut and virtual) but at the \LUA\ end one
    can have more subtypes, like outline or image. The four common ones have the same numbers but 
    the codes are (as usual) used in the primitive commands. 

    In theory we could win some on also supporting shorter keywords but in the current setup there 
    is little gain (e.g. 50K times nothing 0.004, one 0.007, two 0.010 and three 0.013, and in 
    practice scanning the dimension takes much of that). 

    \starttabulate[|Tl|Tl|]
    \NC wd  \NC dimen \NC \NR
    \NC ht  \NC dimen \NC \NR 
    \NC dp  \NC dimen  \NC \NR
    \NC hd  \NC dimen dimen \NC \NR
    \NC whd \NC dimen dimen dimen \NC \NR
    \stoptabulate 

    Virtual rules don't accept |left|, |right|,  |top|, |bottom|, |char|, |font| and |fam| keys
    because they use these fields for other purposes. 

    The default nullflags also serve as a signal, for instance un strut rules combined with char 
    keys. Because a strut is meant for vertical purposes we set the width to zero. 

*/

halfword tex_aux_scan_rule_spec(rule_types type, halfword code)
{
    /*tex |width|, |depth|, and |height| all equal |null_flag| now */
    halfword rule = tex_new_rule_node((quarterword) code); /* here code == subtype */
    halfword attr = node_attr(rule);
    if (code == strut_rule_code) { 
        rule_width(rule) = 0;
        switch (type) {
            case h_rule_type:
                rule_options(rule) |= rule_option_horizontal;
                break;
            case v_rule_type:
                rule_options(rule) |= rule_option_vertical;
                break;
            default: 
                break;
        }
    } else { 
        switch (type) {
            case h_rule_type:
                rule_height(rule) = default_rule;
                rule_depth(rule) = 0;
                rule_options(rule) |= rule_option_horizontal;
                break;
            case v_rule_type:
                rule_options(rule) |= rule_option_vertical;
                /* fall through */
            case m_rule_type:
                rule_width(rule) = default_rule;
                break;
        }
    }
    while (1) {
        switch (tex_scan_character("awhdpxylrtbcfoAWHDPXYLRTBCFO", 0, 1, 0)) {
            case 0:
                goto DONE;
            case 'a': case 'A':
                if (tex_scan_mandate_keyword("attr", 1)) {
                    attr = tex_scan_attribute(attr);
                }
                break;
            case 'w': case 'W':
                if (tex_scan_mandate_keyword("width", 1)) {
                    rule_width(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                }
                break;
            case 'h': case 'H':
                if (tex_scan_mandate_keyword("height", 1)) {
                    rule_height(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                }
                break;
            case 'd': case 'D':
                if (tex_scan_mandate_keyword("depth", 1)) {
                    rule_depth(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                }
                break;
            case 'p': case 'P':
                if (tex_scan_mandate_keyword("pair", 1)) {
                    rule_height(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                    rule_depth(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                }
                break;
            case 'l': case 'L':
                if (code != virtual_rule_code) { 
                    if (tex_scan_mandate_keyword("left", 1)) {
                        rule_left(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                    }
                } else { 
                    goto DONE;
                }
                break;
            case 'r': case 'R':
                if (code != virtual_rule_code) { 
                    switch (tex_scan_character("uiUI", 0, 0, 0)) {
                        case 'u': case 'U':
                            if (tex_scan_mandate_keyword("running", 2)) {
                                rule_width(rule) = null_flag;
                                rule_height(rule) = null_flag;
                                rule_depth(rule) = null_flag;
                            }
                            break;
                        case 'i': case 'I':
                            if (tex_scan_mandate_keyword("right", 2)) {
                                rule_right(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("right|running");
                            goto DONE;
                    }
                } else {
                    if (tex_scan_mandate_keyword("running", 1)) {
                        tex_set_rule_font(rule, tex_scan_font_identifier(NULL));
                    }
                }
                break;
            case 't': case 'T': /* just because it's nicer */
                if (code != virtual_rule_code) { 
                    if (tex_scan_mandate_keyword("top", 1)) {
                        rule_left(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                    }
                    break;
                } else {
                    goto DONE;
                }
            case 'b': case 'B': /* just because it's nicer */
                if (code != virtual_rule_code) { 
                    if (tex_scan_mandate_keyword("bottom", 1)) {
                        rule_right(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                    }
                    break;
                } else {
                    goto DONE;
                }
            case 'x': case 'X':
                if (tex_scan_mandate_keyword("xoffset", 1)) {
                    rule_x_offset(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                }
                break;
            case 'y': case 'Y':
                if (tex_scan_mandate_keyword("yoffset", 1)) {
                    rule_y_offset(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                }
                break;
            case 'f': case 'F':
                if (code != virtual_rule_code) { 
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
                } else { 
                    goto DONE;
                }
            case 'o': case 'O':
                if (code == normal_rule_code) { 
                    switch (tex_scan_character("nfNF", 0, 0, 0)) {
                        case 'n': case 'N':
                            rule_line_on(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                            break;
                        case 'f': case 'F':
                            if (tex_scan_mandate_keyword("off", 2)) {
                                rule_line_off(rule) = tex_scan_dimension(0, 0, 0, 0, NULL);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("on|off");
                            goto DONE;
                    }
                    break;
                } else { 
                    goto DONE;
                }
            case 'c': case 'C':
                if (code == strut_rule_code) { 
                    if (tex_scan_mandate_keyword("char", 1)) {
                        rule_strut_character(rule) = tex_scan_char_number(0);
                    }
                    break;
                } else { 
                    goto DONE;
                }
            default:
                goto DONE;
        }
    }
  DONE:
  //  if (! attr) {
    if (attr) {
        /* Also bumps reference and replaces the one set. */
        tex_attach_attribute_list_attribute(rule, attr);
    }    
    switch (code) {
        case strut_rule_code:
            if (type == v_rule_type) {
                tex_aux_check_text_strut_rule(rule, text_style);
            }
            break;
        case virtual_rule_code:
            rule_virtual_width(rule) = rule_width(rule);
            rule_virtual_height(rule) = rule_height(rule);
            rule_virtual_depth(rule) = rule_depth(rule);
            rule_width(rule) = 0;
            rule_height(rule) = 0;
            rule_depth(rule) = 0;
            break;
    }
    if (type == h_rule_type) { 
        if (rule_width(rule) == null_flag) { 
            rule_options(rule) |= rule_option_running;
        }
    } else { 
        if (rule_height(rule) == null_flag && rule_width(rule) == null_flag) { 
            rule_options(rule) |= rule_option_running;
        }
    }
    return rule;
}

void tex_aux_run_vrule(void)
{
    tex_tail_append(tex_aux_scan_rule_spec(v_rule_type, cur_chr));
    cur_list.space_factor = default_space_factor;
}

void tex_aux_run_hrule(void)
{
    tex_tail_append(tex_aux_scan_rule_spec(h_rule_type, cur_chr));
    cur_list.prev_depth = ignore_depth_criterion_par;
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
            halfword chr = rule_strut_character(rule);
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
            halfword chr = rule_strut_character(rule);
            if (fnt > 0 && chr && tex_char_exists(fnt, chr)) {
                scaledwhd whd = tex_char_whd_from_font(fnt, chr);
                if (ht == null_flag) {
                    rule_height(rule) = whd.ht;
                }
                if (dp == null_flag) {
                    rule_depth(rule) = whd.dp;
                }
            }
        }
    }
}

halfword tex_get_rule_font(halfword n, halfword style)
{
    if (node_subtype(n) != virtual_rule_subtype) {
        halfword fnt = rule_strut_font(n);
        if (fnt >= rule_font_fam_offset) {
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
    } else { 
        return null_font;
    }
}

halfword tex_get_rule_family(halfword n)
{
    if (node_subtype(n) != virtual_rule_subtype) {
        halfword fnt = rule_strut_font(n);
        if (fnt >= rule_font_fam_offset) {
            halfword fam = fnt - rule_font_fam_offset;
            if (fam_par_in_range(fam)) {
                return fam;
            }
        }
    }
    return 0;
}

void tex_set_rule_font(halfword n, halfword fnt)
{
    if (node_subtype(n) != virtual_rule_subtype) {
        if (fnt < 0 || fnt >= rule_font_fam_offset) {
            rule_strut_font(n) = 0;
        } else {
            rule_strut_font(n) = fnt;
        }
    }
}

void tex_set_rule_family(halfword n, halfword fam)
{
    if (node_subtype(n) != virtual_rule_subtype) {
        if (fam < 0 || fam >= max_n_of_math_families) {
            rule_strut_font(n) = rule_font_fam_offset;
        } else {
            rule_strut_font(n) = rule_font_fam_offset + fam;
        }
    }
}

halfword tex_get_rule_left(halfword n)
{
    return node_subtype(n) == virtual_rule_subtype ? 0 : rule_left(n); 
}

halfword tex_get_rule_right(halfword n)
{
    return node_subtype(n) == virtual_rule_subtype ? 0 : rule_right(n); 
}

void tex_set_rule_left(halfword n, halfword value)
{
    if (node_subtype(n) != virtual_rule_subtype) {
        rule_left(n) = value; 
    }
}

void tex_set_rule_right(halfword n, halfword value)
{
    if (node_subtype(n) != virtual_rule_subtype) {
        rule_right(n) = value; 
    }
}

halfword tex_get_rule_on(halfword n)
{
    return node_subtype(n) == normal_rule_subtype ? rule_line_on(n) : 0; 
}

halfword tex_get_rule_off(halfword n)
{
    return node_subtype(n) == normal_rule_subtype ? rule_line_off(n) : 0; 
}

void tex_set_rule_on(halfword n, halfword value)
{
    if (node_subtype(n) == normal_rule_subtype) {
        rule_line_on(n) = value; 
    }
}

void tex_set_rule_off(halfword n, halfword value)
{
    if (node_subtype(n) == normal_rule_subtype) {
        rule_line_off(n) = value; 
    }
}


