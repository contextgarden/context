/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"


static int valid_specification_options[] = {
    [club_penalties_code]          = specification_option_double | specification_option_largest | specification_option_final,
    [display_widow_penalties_code] = specification_option_double | specification_option_largest | specification_option_final,
    [inter_line_penalties_code]    = specification_option_final,
    [math_backward_penalties_code] = 0,
    [math_forward_penalties_code]  = 0,
    [orphan_penalties_code]        = 0,
    [par_passes_code]              = specification_option_presets,
    [par_shape_code]               = specification_option_repeat,
    [balance_passes_code]          = specification_option_presets,
    [balance_final_penalties_code] = 0,
    [widow_penalties_code]         = specification_option_double | specification_option_largest | specification_option_final,
    [broken_penalties_code]        = specification_option_double,
    [fitness_classes_code]         = 0,
    [adjacent_demerits_code]       = specification_option_double,
    [integer_list_code]            = specification_option_double | specification_option_integer | specification_option_default | specification_option_rotate,
    [dimension_list_code]          = specification_option_double | specification_option_integer | specification_option_default | specification_option_rotate,
    [posit_list_code]              = specification_option_double | specification_option_integer | specification_option_default | specification_option_rotate,
};

static halfword tex_aux_scan_specification_options(quarterword code)
{
    halfword options = 0; 
    halfword valid = valid_specification_options[code];
    while (1) {
        /*tex Maybe |migrate <int>| makes sense here. */
        switch (tex_scan_character("ordlpifORDLPIF", 0, 1, 0)) {
            case 0:
                return options;
            case 'o': case 'O':
                if (tex_scan_mandate_keyword("options", 1)) {
                    options |= tex_scan_integer(0, NULL, NULL);
                }
                break;
            case 'r': case 'R':
                switch (tex_scan_character("eoEO", 0, 0, 1)) {
                    case 'e': case 'E':
                        if ((valid & specification_option_repeat) && tex_scan_mandate_keyword("repeat", 2)) {
                            options |= specification_option_repeat;
                        }
                        break;
                    case 'o': case 'O':
                        if ((valid & specification_option_rotate) && tex_scan_mandate_keyword("rotate", 2)) {
                            options |= specification_option_rotate;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("repeat|rotate");
                        return options;
                }
                break;
            case 'd': case 'D':
                switch (tex_scan_character("eoEO", 0, 0, 1)) {
                    case 'e': case 'E':
                        if ((valid & specification_option_default) && tex_scan_mandate_keyword("default", 2)) {
                            options |= specification_option_default;
                        }
                        break;
                    case 'o': case 'O':
                        if ((valid & specification_option_double) && tex_scan_mandate_keyword("double", 2)) {
                            options |= specification_option_double;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("default|double");
                        return options;
                }
                break;
            case 'l': case 'L':
                if ((valid & specification_option_largest) && tex_scan_mandate_keyword("largest", 1)) {
                    options |= specification_option_largest;
                }
                break;
            case 'p': case 'P':
                if ((valid & specification_option_presets) && tex_scan_mandate_keyword("presets", 1)) {
                    options |= specification_option_presets;
                }
                break;
            case 'i': case 'I':
                if ((valid & specification_option_integer) && tex_scan_mandate_keyword("integer", 1)) {
                    options |= specification_option_integer;
                }
                break;
            case 'f': case 'F':
                if ((valid & specification_option_final) && tex_scan_mandate_keyword("final", 1)) {
                    options |= specification_option_final;
                }
                break;
           default:
                return options;
        }
    }
}

/*tex 
    We could have one function but this is cleaner because we have no parameters related to these
    list specifications. 
*/

/* todo: set/get a specific slot */

static void tex_aux_scan_specification_list_default(halfword p, halfword count, int pair, halfword first, halfword second)
{
    for (int n = 1; n <= count; n++) {
        tex_set_specification_penalty(p, n, first);   
        if (pair) {
            tex_set_specification_nepalty(p, n, second);   
        }
    }
}

static halfword tex_aux_scan_specification_list(quarterword code)
{
    halfword p = null;
    halfword count = tex_scan_integer(1, NULL, NULL);
    if (count > 0) {
        halfword options = tex_aux_scan_specification_options(code);
     // halfword options = tex_scan_partial_keyword("options") ? tex_scan_integer(0, NULL) : 0;
        int pair = specification_option_double(options);
        int isint = specification_option_integer(options);
        switch (code) { 
            case integer_val_level:
                p = tex_new_specification_node(count, integer_list_code, options);
                if (specification_option_default(options)) {
                    tex_aux_scan_specification_list_default(p, count, pair, 
                        tex_scan_integer(0, NULL, NULL), pair ? tex_scan_integer(0, NULL, NULL) : 0   
                    );
                } else { 
                    for (int n = 1; n <= count; n++) {
                        if (pair) {
                            tex_set_specification_nepalty(p, n, tex_scan_integer(0, NULL, NULL));   
                        }
                        tex_set_specification_penalty(p, n, tex_scan_integer(0, NULL, NULL));   
                    }
                }
                break;
            case dimension_val_level:
                p = tex_new_specification_node(count, dimension_list_code, options);
                if (specification_option_default(options)) {
                    tex_aux_scan_specification_list_default(p, count, pair, 
                        isint ? tex_scan_integer(0, NULL, NULL) : tex_scan_dimension(0, 0, 0, 0, NULL, NULL),   
                        pair ? tex_scan_dimension(0, 0, 0, 0, NULL, NULL) : 0
                    );
                } else { 
                    for (int n = 1; n <= count; n++) {
                        if (pair) {
                            tex_set_specification_nepalty(p, n, isint ? tex_scan_integer(0, NULL, NULL) : tex_scan_dimension(0, 0, 0, 0, NULL, NULL));   
                        }
                        tex_set_specification_penalty(p, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL));   
                    }
                }
                break;
            case posit_val_level:
                p = tex_new_specification_node(count, posit_list_code, options);
                if (specification_option_default(options)) {
                    tex_aux_scan_specification_list_default(p, count, pair, 
                        isint ? tex_scan_integer(0, NULL, NULL) : tex_scan_posit(0),   
                        pair ? tex_scan_posit(0) : 0   
                    );
                } else { 
                    for (int n = 1; n <= count; n++) {
                        if (pair) {
                            tex_set_specification_nepalty(p, n, isint ? tex_scan_integer(0, NULL, NULL) : tex_scan_posit(0));   
                        }
                        tex_set_specification_penalty(p, n, tex_scan_posit(0));   
                    }
                }
                break;
        }
    }
    return p;
}

/*tex 
    Of course we could split this one up and we might do that some day but it's not that important
    right now.

    If we have a penalties array we could first scan for a specification reference command and when 
    it is of the requested type we could copy its values. But it's not that often needed. Like: 

    \starttyping
    \specificationdef\myclubpenalties \clubpenalties \mywidowpenalties 
    \stoptyping

    Also, we tend to have different setups for widow penalties for odd and even pages in a spread 
    but not for club penalties which makes it even less urgent. 
*/

static halfword tex_aux_scan_specification_par_shape(void)
{
    halfword count = tex_scan_integer(1, NULL, NULL);
    if (count > 0) {
     // halfword options = tex_scan_partial_keyword("options") ? tex_scan_integer(0, NULL) : 0;
        halfword options = tex_aux_scan_specification_options(par_shape_code);
        halfword spec = tex_new_specification_node(count, par_shape_code, options);
        for (int n = 1; n <= count; n++) {
            tex_set_specification_indent(spec, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL));
            tex_set_specification_width(spec, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL)); 
        }
        return spec; 
    } else {
        return null; 
    }
}

static halfword tex_aux_scan_specification_fitness_classes(void)
{
    halfword count = tex_scan_integer(1, NULL, NULL);
    halfword spec = null;
    if (count > max_n_of_fitness_values) {
        /*tex Todo: warning. */
        count = max_n_of_fitness_values;
    }
    if (count) {
        halfword options = tex_aux_scan_specification_options(fitness_classes_code);
        spec = tex_new_specification_node(count, fitness_classes_code, options);
        for (int n = 1; n <= count; n++) {
            tex_set_specification_fitness_class(spec, n, tex_scan_integer(0, NULL, NULL));   
        }
        tex_check_fitness_classes(spec);
    } else {
        spec = tex_default_fitness_classes();
    }
    return spec;
}

static halfword tex_aux_scan_specification_adjacent_demerits(void)
{
    halfword count = tex_scan_integer(1, NULL, NULL);
    halfword spec = null;
    if (count > max_n_of_fitness_values) {
        /*tex Todo: warning. */
        count = max_n_of_fitness_values;
    }
    if (count) {
        halfword options = tex_aux_scan_specification_options(adjacent_demerits_code);
        halfword duplex = specification_option_double(options);
        halfword max = 0;
        if (count == -1 && ! duplex) {
            /*tex This permits an efficient redefinition of the traditional |\adjdemerits|. */
            spec = tex_new_specification_node(0, adjacent_demerits_code, options);
            specification_count(spec) = 1;
            max = tex_scan_integer(0, NULL, NULL);
            specification_adjacent_adj(spec) = max;
        } else { 
            spec = tex_new_specification_node(count, adjacent_demerits_code, options);
            for (int n = 1; n <= count; n++) {
                halfword value = tex_scan_integer(0, NULL, NULL);
                tex_set_specification_adjacent_u(spec, n, value);
                if (value > max) {
                    max = value; 
                }
                if (duplex) { 
                    value = tex_scan_integer(0, NULL, NULL);
                    if (value > max) {
                        max = value; 
                    }
                }
                tex_set_specification_adjacent_d(spec, n, value);  
            }
            tex_set_specification_option(options, specification_option_double);
        }
        specification_adjacent_max(spec) = abs(max); 
    }
    return spec;
}

/*tex 
    This scanner is a bit over the top but making a different one does not make sense not does 
    simple scan_keyword and plenty pushback. We just have these long keywords. On a test that 
    scans al keywords the tree based variant is more than three times faster than the sequential 
    push back one. 
*/

static int tex_aux_first_with_criterium(halfword passes, int subpasses) 
{
    for (halfword subpass = 1; subpass <= subpasses; subpass++) {
        if (tex_get_passes_features(passes, subpass) & passes_criterium_set) {
            return subpass; 
        }
    }
    return 0;
}

static int tex_aux_first_with_quit(halfword passes, int subpasses) 
{
    for (halfword subpass = 1; subpass <= subpasses; subpass++) {
        if (tex_get_passes_features(passes, subpass) & passes_quit_pass) {
            return subpass; 
        }
    }
    return 0;
}

static halfword tex_aux_scan_par_specification(halfword code, halfword (*scan)(void))
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd == specificationspec_cmd && node_subtype(cur_chr) == code) { 
        return tex_copy_node(eq_value(cur_cs));
    } else { 
        tex_back_input(cur_tok);
        return scan();
    }
}

static halfword tex_aux_scan_specification_penalties(quarterword code)
{
    halfword p = null;
    halfword count = tex_scan_integer(1, NULL, NULL);
    int pairs = 0;
    switch (code) { 
        case broken_penalties_code: 
            if (count > 1) {
                tex_handle_error(
                    normal_error_type,
                    "count has to be 1 for \\brokenpenalties",
                    NULL
                );
                count = 1;
            }
        case balance_final_penalties_code: 
        case club_penalties_code: 
        case widow_penalties_code: 
        case display_widow_penalties_code: 
        case toddler_penalties_code: 
            pairs = 1;
     /* case inter_line_penalties_code: */
     /* case orphan_penalties_code: */
     /* case math_forward_penalties_code: */
     /* case math_backward_penalties_code: */
    }
    if (count != 0) { 
     // halfword options = tex_scan_partial_keyword("options") ? tex_scan_integer(0, NULL, NULL) : 0;
        halfword options = tex_aux_scan_specification_options(code);
        int pair = pairs ? specification_option_double(options) : 0;
        if (count == 1 || count == -1) {
            halfword nepalty = pair ? tex_scan_integer(1, NULL, NULL) : 0;
            halfword penalty = tex_scan_integer(pair ? 0 : 1, NULL, NULL);
            /*tex 
                We always need a node unless we introduce a zero_specification_cmd which is a bit
                of overkill. 
            */
         /* if (penalty || nepalty) { */
                if (count == -1) { 
                    options |= specification_option_final;
                    count = 1; 
                }
                p = tex_new_specification_node(0, code, options);
                specification_count(p) = count;
                tex_set_specification_nepalty(p, 0, nepalty); 
                tex_set_specification_penalty(p, 0, penalty);
         /* } */
        } else if (count > 0) {
            int final = specification_option_final(options);
            p = tex_new_specification_node(final ? count + 1 : count, code, options);
            for (int n = 1; n <= count; n++) {
                if (pair) {
                    tex_set_specification_nepalty(p, n, tex_scan_integer(0, NULL, NULL)); 
                }
                tex_set_specification_penalty(p, n, tex_scan_integer(0, NULL, NULL)); 
            }
            if (final) { 
                if (pair) {
                    tex_set_specification_nepalty(p, count + 1, 0); 
                }
                tex_set_specification_penalty(p, count + 1, 0);
            }
        }
        if (p && ! pair) { 
            tex_remove_specification_option(p, specification_option_double);
        }
    }
    return p;
}

static halfword tex_aux_scan_specification_orphan_penalties(void)
{
    return tex_aux_scan_specification_penalties(orphan_penalties_code);
}

static halfword tex_aux_scan_specification_toddler_penalties(void)
{
    return tex_aux_scan_specification_penalties(toddler_penalties_code);
}

static halfword tex_aux_scan_specification_orphan_line_factors(void)
{
    return tex_aux_scan_specification_penalties(orphan_line_factors_code);
}

static halfword tex_aux_scan_specification_par_passes(void)
{
    halfword p = null;
    halfword count = tex_scan_integer(1, NULL, NULL);
    if (count > 0) {
        /*tex 
            We have no named options here. Presets are automatically set anyway. We might even drop 
            the option scanning here.
        */
        halfword options = tex_scan_partial_keyword("options") ? tex_scan_integer(0, NULL, NULL) : 0;
        halfword n = 1;
        if (count > 0xFF) {
            /* todo: message */
            count = 0xFF;
        }
        p = tex_new_specification_node(count, par_passes_code, options);
        while (n <= count) {
            switch (tex_scan_character("acdefhilmnoqrstuACDEFHILMNOQRSTU", 0, 1, 0)) {
                case 0:
                    goto DONE;
                case 'a': case 'A':
                    if (tex_scan_mandate_keyword("adj", 1)) {
                        switch (tex_scan_character("aduADU", 0, 0, 0)) {
                            case 'd': case 'D' :                                     
                                if (tex_scan_mandate_keyword("adjdemerits", 4)) {
                                    tex_set_passes_adjdemerits(p, n, tex_scan_integer(0, NULL, NULL));
                                    tex_set_passes_okay(p, n, passes_adjdemerits_okay);
                                } break;
                            case 'a': case 'A':
                                if (tex_scan_mandate_keyword("adjacentdemerits", 4)) {
                                    tex_set_passes_adjacentdemerits(p, n, tex_aux_scan_par_specification(adjacent_demerits_code, tex_aux_scan_specification_adjacent_demerits));
                                    tex_set_passes_okay(p, n, passes_adjacentdemerits_okay);
                                }
                                break;
                            case 'u': case 'U': 
                                if (tex_scan_mandate_keyword("adjustspacing", 4)) {
                                    if (tex_scan_character("sS", 0, 0, 0)) {
                                        switch (tex_scan_character("thTH", 0, 0, 0)) {
                                            case 't': case 'T':
                                                switch (tex_scan_character("erER", 0, 0, 0)) {
                                                    case 'e': case 'E':
                                                        if (tex_scan_mandate_keyword("adjustspacingstep", 16)) {
                                                            tex_set_passes_adjustspacingstep(p, n, tex_scan_integer(0, NULL, NULL));   
                                                            tex_set_passes_okay(p, n, passes_adjustspacingstep_okay);
                                                        }
                                                        break;
                                                    case 'r': case 'R':
                                                        if (tex_scan_mandate_keyword("adjustspacingstretch", 16)) {
                                                            tex_set_passes_adjustspacingstretch(p, n, tex_scan_integer(0, NULL, NULL));
                                                            tex_set_passes_okay(p, n, passes_adjustspacingstretch_okay);
                                                        }
                                                        break;
                                                    default:
                                                        tex_aux_show_keyword_error("adjustspacingstep|adjustspacingstretch");
                                                        goto DONE;
                                                }
                                                break;
                                            case 'h': case 'H':
                                                if (tex_scan_mandate_keyword("adjustspacingshrink", 15)) {
                                                    tex_set_passes_adjustspacingshrink(p, n, tex_scan_integer(0, NULL, NULL)); 
                                                    tex_set_passes_okay(p, n, passes_adjustspacingshrink_okay);
                                                }
                                                break;
                                            default:
                                                tex_aux_show_keyword_error("adjustspacingstep|adjustspacingshrink|adjustspacingstretch");
                                                goto DONE;
                                        }
                                    } else {
                                        tex_set_passes_adjustspacing(p, n, tex_scan_integer(0, NULL, NULL));   
                                        tex_set_passes_okay(p, n, passes_adjustspacing_okay);
                                    } 
                                }
                                break;
                            default:
                                goto NOTDONE1;
                        }
                    } else { 
                        NOTDONE1:
                        tex_aux_show_keyword_error("adjdemerits|adjacentdemerits|adjustspacing|adjustspacingstep|adjustspacingshrink|adjustspacingstretch");
                        goto DONE;
                    }
                    break;
                case 'c': case 'C':
                    switch (tex_scan_character("alAL", 0, 0, 0)) {
                        case 'a': case 'A':
                            if (tex_scan_mandate_keyword("callback", 2)) {
                                tex_set_passes_callback(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_features(p, n, passes_callback_set);
                                tex_set_passes_okay(p, n, passes_callback_okay);
                            }
                            break;
                        case 'l': case 'L': 
                            if (tex_scan_mandate_keyword("classes", 2)) {
                                tex_set_passes_classes(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_features(p, n, passes_criterium_set);
                                tex_set_passes_okay(p, n, passes_classes_okay);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("classes|callback");
                            goto DONE;
                    }
                    break;
                case 'd': case 'D':
                    switch (tex_scan_character("oeOE", 0, 0, 0)) {
                        case 'e': case 'E':
                            if (tex_scan_mandate_keyword("demerits", 2)) {
                                tex_set_passes_demerits(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_features(p, n, passes_criterium_set);
                                tex_set_passes_okay(p, n, passes_demerits_okay);
                            }
                            break;
                        case 'o': case 'O':
                            if (tex_scan_mandate_keyword("doublehyphendemerits", 2)) {
                                tex_set_passes_doublehyphendemerits(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_okay(p, n, passes_doublehyphendemerits_okay);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("demerits|doublehyphendemerits");
                            goto DONE;
                    }
                    break;
                case 'e': case 'E':
                    switch (tex_scan_character("mxMX", 0, 0, 0)) {
                        case 'm': case 'M':
                            if (tex_scan_mandate_keyword("emergency", 2)) {
                                switch (tex_scan_character("flsprwFLSPRW", 0, 0, 0)) {
                                    case 'f': case 'F':
                                        /* tex 
                                            Using a factor is better from the perspective 
                                            of |\specificationdef| usage because we don't 
                                            want hardcoded dimensions then. 
                                        */
                                        if (tex_scan_mandate_keyword("emergencyfactor", 10)) {
                                            tex_set_passes_emergencyfactor(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_emergencyfactor_okay);
                                        }
                                        break;
                                    case 'l': case 'L':
                                        if (tex_scan_mandate_keyword("emergencyleftextra", 10)) {
                                            tex_set_passes_emergencyleftextra(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_emergencyleftextra_okay);
                                        }
                                        break;
                                    case 'p': case 'P':
                                        if (tex_scan_mandate_keyword("emergencypercentage", 10)) {
                                            tex_set_passes_emergencypercentage(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_emergencypercentage_okay);
                                        }
                                        break;
                                    case 'r': case 'R':
                                        if (tex_scan_mandate_keyword("emergencyrightextra", 10)) {
                                            tex_set_passes_emergencyrightextra(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_emergencyrightextra_okay);
                                        }
                                        break;
                                    case 's': case 'S':
                                        if (tex_scan_mandate_keyword("emergencystretch", 10)) {
                                            tex_set_passes_emergencystretch(p, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_emergencystretch_okay);
                                        }
                                        break;
                                    case 'w': case 'W':
                                        if (tex_scan_mandate_keyword("emergencywidthextra", 10)) {
                                            tex_set_passes_emergencywidthextra(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_emergencywidthextra_okay);
                                        }
                                        break;
                                    default:
                                        goto NOTDONE4;
                                }
                            } else { 
                                NOTDONE4:
                                tex_aux_show_keyword_error("emergencyfactor|emergencystretch|emergencypercentage|emergencyleftextra|emergencyrightextra");
                                goto DONE;
                            }
                            break;
                        case 'x': case 'X':
                            if (tex_scan_mandate_keyword("extrahyphenpenalty", 2)) {
                                tex_set_passes_extrahyphenpenalty(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_okay(p, n, passes_extrahyphenpenalty_okay);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("emergencyfactor|extrahyphenpenalty");
                            goto DONE;
                    }
                    break;
                case 'f': case 'F':
                    if (tex_scan_mandate_keyword("fi", 1)) {
                        switch (tex_scan_character("ntNT", 0, 0, 0)) {
                            case 'n': case 'N':
                                if (tex_scan_mandate_keyword("finalhyphendemerits", 3)) {
                                    tex_set_passes_finalhyphendemerits(p, n, tex_scan_integer(0, NULL, NULL));
                                    tex_set_passes_okay(p, n, passes_finalhyphendemerits_okay);
                                }
                                break;
                            case 't': case 'T':
                                if (tex_scan_mandate_keyword("fitnessclasses", 3)) {
                                    tex_set_passes_fitnessclasses(p, n, tex_aux_scan_par_specification(fitness_classes_code, tex_aux_scan_specification_fitness_classes));
                                    tex_set_passes_okay(p, n, passes_fitnessclasses_okay);
                                }
                                break;
                            default:
                                goto NOTDONE2;
                        }
                    } else { 
                        NOTDONE2:
                        tex_aux_show_keyword_error("finalhyphendemetits|fitnessclasses");
                        goto DONE;
                    }
                    break;
                case 'h': case 'H':
                    if (tex_scan_mandate_keyword("hyphenation", 1)) {
                        tex_set_passes_hyphenation(p, n, tex_scan_integer(0, NULL, NULL));
                        tex_set_passes_okay(p, n, passes_hyphenation_okay);
                    }
                    break;
                case 'i': case 'I':
                    switch (tex_scan_character("dfDF", 0, 0, 0)) {
                        case 'd': case 'D':
                            if (tex_scan_mandate_keyword("identifier", 2)) {
                                passes_identifier(p) = tex_scan_integer(0, NULL, NULL);
                            }
                            break;
                        case 'f': case 'F':
                            switch (tex_scan_character("aefgmltAEFGMLT", 0, 0, 0)) {
                                case 'a': case 'A':
                                    if (tex_scan_mandate_keyword("ifadjustspacing", 3)) {
                                        tex_set_passes_features(p, n, passes_if_adjust_spacing);
                                    } 
                                    break;
                                case 'e': case 'E':
                                    if (tex_scan_mandate_keyword("ifemergencystretch", 3)) {
                                        tex_set_passes_features(p, n, passes_if_emergency_stretch);
                                    } 
                                    break;
                                case 'f': case 'F':
                                    if (tex_scan_mandate_keyword("iffactor", 3)) {
                                        tex_set_passes_features(p, n, passes_if_space_factor);
                                    } 
                                    break;
                                case 'g': case 'G':
                                    if (tex_scan_mandate_keyword("ifglue", 3)) {
                                        tex_set_passes_features(p, n, passes_if_glue);
                                    } 
                                    break;
                                case 'l': case 'L':
                                    if (tex_scan_mandate_keyword("iflooseness", 3)) {
                                        tex_set_passes_features(p, n, passes_if_looseness);
                                    } 
                                    break;
                                case 'm': case 'M':
                                    if (tex_scan_mandate_keyword("ifmath", 3)) {
                                        tex_set_passes_features(p, n, passes_if_math);
                                    } 
                                    break;
                                case 't': case 'T':
                                    if (tex_scan_mandate_keyword("iftext", 3)) {
                                        tex_set_passes_features(p, n, passes_if_text);
                                    } 
                                    break;
                                default:
                                    tex_aux_show_keyword_error("if[adjustspacing|emergencystretch|factor|glue|looseness|math|text]");
                                    goto DONE;
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("identifier|if[...]");
                            goto DONE;
                    }
                    break;
                case 'l': case 'L':
                    switch (tex_scan_character("ieoIEO", 0, 0, 0)) {
                        case 'e': case 'E':
                            if (tex_scan_mandate_keyword("lefttwindemerits", 2)) {
                                tex_set_passes_lefttwindemerits(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_okay(p, n, passes_lefttwindemerits_okay);
                            } 
                            break;
                        case 'i': case 'I':
                            if (tex_scan_mandate_keyword("line", 2)) {
                                switch (tex_scan_character("bpBP", 0, 0, 0)) {
                                    case 'b': case 'B':
                                        if (tex_scan_mandate_keyword("linebreak", 5)) {
                                            switch (tex_scan_character("coCO", 0, 0, 0)) {
                                                case 'c': case 'C':
                                                    if (tex_scan_mandate_keyword("linebreakchecks", 10)) {
                                                        tex_set_passes_linebreakchecks(p, n, tex_scan_integer(0, NULL, NULL));
                                                        tex_set_passes_okay(p, n, passes_linebreakchecks_okay);
                                                    } 
                                                    break;
                                                case 'o': case 'O':
                                                    if (tex_scan_mandate_keyword("linebreakoptional", 10)) {
                                                        tex_set_passes_linebreakoptional(p, n, tex_scan_integer(0, NULL, NULL));
                                                        tex_set_passes_okay(p, n, passes_linebreakoptional_okay);
                                                    } 
                                                    break;
                                                default:
                                                    tex_aux_show_keyword_error("linebreakoptional|linebreakchecks");
                                                    goto DONE;
                                            }
                                        }
                                        break;
                                    case 'p': case 'P':
                                        if (tex_scan_mandate_keyword("linepenalty", 5)) {
                                            tex_set_passes_linepenalty(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_passes_okay(p, n, passes_linepenalty_okay);
                                        } 
                                        break;
                                    default:
                                        tex_aux_show_keyword_error("linebreakoptional|linebreakchecks|linepenalty");
                                        goto DONE;
                                }
                            }
                            break;
                        case 'o': case 'O':
                            if (tex_scan_mandate_keyword("looseness", 2)) {
                                tex_set_passes_looseness(p, n, tex_scan_integer(0, NULL, NULL));
                                tex_set_passes_okay(p, n, passes_looseness_okay);
                            } 
                            break;
                        default:
                            tex_aux_show_keyword_error("lefttwindemerits|looseness|line[...]");
                            goto DONE;
                    }
                    break;
                case 'm': case 'M':
                    if (tex_scan_mandate_keyword("mathpenaltyfactor", 1)) {
                        halfword v = tex_scan_integer(0, NULL, NULL);
                        if (v < 0) {
                            v = 0;
                        } else if (v == scaling_factor) { 
                            v = 0;
                        }
                        tex_set_passes_mathpenaltyfactor(p, n, v);
                        tex_set_passes_okay(p, n, passes_mathpenaltyfactor_okay);
                    }
                    break;
                case 'n': case 'N':
                    if (tex_scan_mandate_keyword("next", 1)) {
                        n++;
                    }
                    break;
                case 'o': case 'O':
                    if (tex_scan_mandate_keyword("orphan", 1)) {
                        switch (tex_scan_character("plPL", 0, 0, 0)) {
                            case 'p': case 'P':
                                if (tex_scan_mandate_keyword("orphanpenalties", 7)) {
                                    tex_set_passes_orphanpenalties(p, n, tex_aux_scan_par_specification(orphan_penalties_code, tex_aux_scan_specification_orphan_penalties));
                                    tex_set_passes_okay(p, n, passes_orphanpenalties_okay);
                                }
                                break;
                            case 'l': case 'L':
                                if (tex_scan_mandate_keyword("orphanlinefactors", 7)) {
                                    tex_set_passes_orphanlinefactors(p, n, tex_aux_scan_par_specification(orphan_line_factors_code, tex_aux_scan_specification_orphan_line_factors));
                                    tex_set_passes_okay(p, n, passes_orphanlinefactors_okay);
                                }
                                break;
                            default:
                                tex_aux_show_keyword_error("orphanpenalty|orphanpenalties|orphanlinefactors");
                                goto DONE;
                        }
                    }
                    break;
                case 'q': case 'Q':
                    if (tex_scan_mandate_keyword("quit", 1)) {
                        tex_set_passes_features(p, n, passes_quit_pass);
                    }
                    break;
                case 'r': case 'R':
                    if (tex_scan_mandate_keyword("righttwindemerits", 1)) {
                        tex_set_passes_righttwindemerits(p, n, tex_scan_integer(0, NULL, NULL));
                        tex_set_passes_okay(p, n, passes_righttwindemerits_okay);
                    }
                    break;
                case 's': case 'S':
                    switch (tex_scan_character("kfKF", 0, 0, 0)) {
                        case 'k': case 'K':
                            if (tex_scan_mandate_keyword("skip", 2)) {
                                tex_set_passes_features(p, n, passes_skip_pass);
                            }
                            break;
                        case 'f': case 'F':
                            switch (tex_scan_character("fsFS", 0, 0, 0)) {
                                case 'f': case 'F':
                                    if (tex_scan_mandate_keyword("sffactor", 3)) {
                                        tex_set_passes_sffactor(p, n, tex_scan_integer(0, NULL, NULL));
                                        tex_set_passes_okay(p, n, passes_sffactor_okay);
                                    }
                                    break;
                                case 's': case 'S':
                                    if (tex_scan_mandate_keyword("sfstretchfactor", 3)) {
                                        tex_set_passes_sfstretchfactor(p, n, tex_scan_integer(0, NULL, NULL));
                                        tex_set_passes_okay(p, n, passes_sfstretchfactor_okay);
                                    }
                                    break;
                                default: 
                                    goto NOTDONE5;
                            }
                            break;
                        default:
                          NOTDONE5:
                            tex_aux_show_keyword_error("skip|sffactor|sfstretchfactor");
                            goto DONE;
                    }
                    break;
                case 't': case 'T':
                    switch (tex_scan_character("hoHO", 0, 0, 0)) {
                        case 'h': case 'H':
                            if (tex_scan_mandate_keyword("threshold", 2)) {
                                tex_set_passes_threshold(p, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL));
                                tex_set_passes_features(p, n, passes_criterium_set);
                                tex_set_passes_okay(p, n, passes_threshold_okay);
                            }
                            break;
                        case 'o': case 'O':
                            switch (tex_scan_character("dlDL", 0, 0, 0)) {
                                case 'd': case 'D':
                                    if (tex_scan_mandate_keyword("toddlerpenalties", 3)) {
                                        tex_set_passes_toddlerpenalties(p, n, tex_aux_scan_par_specification(toddler_penalties_code, tex_aux_scan_specification_toddler_penalties));
                                        tex_set_passes_okay(p, n, passes_toddlerpenalties_okay);
                                    }

                                    break;
                                case 'l': case 'L':
                                    if (tex_scan_mandate_keyword("tolerance", 3)) {
                                        tex_set_passes_tolerance(p, n, tex_scan_integer(0, NULL, NULL));
                                        tex_set_passes_okay(p, n, passes_tolerance_okay);
                                    }
                                    break;
                                default:
                                    goto NOTDONE3;
                            }
                            break;
                        default:
                            NOTDONE3:
                            tex_aux_show_keyword_error("threshold|tolerance|toddlerpenalties");
                            goto DONE;
                    }
                    break;
                case 'u': case 'U':
                    if (tex_scan_mandate_keyword("unlessmath", 1)) {
                        tex_set_passes_features(p, n, passes_unless_math);
                    } 
                    break;
                default:
                    goto DONE;
            }
        }
        DONE:
        if (n < count) {
            tex_handle_error(
                normal_error_type,
                "there %s only %i of %i %s specified for \\parpasses",
                n == 1 ? "is" : "are", n, count, count == 1 ? "pass" : "passes",
                NULL
            );
        }
        {
            halfword first = tex_aux_first_with_criterium(p, count);
            halfword quit = tex_aux_first_with_quit(p, count);
            if (first == 0) { 
                tex_add_specification_option(p, specification_option_presets);
                passes_first_final(p) = count;
            } else if (first == 1) { 
                tex_remove_specification_option(p, specification_option_presets);
                passes_first_final(p) = 2;
            } else { 
                tex_add_specification_option(p, specification_option_presets);
                passes_first_final(p) = first - 1;
            }
            if (quit) { 
                /*tex We always want a result. */
                passes_first_final(p) = quit == 1 ? 1 : quit - 1;
            }
        }
    }
    return p;
}


/* TODO: emergencyshrink */

static halfword tex_aux_scan_specification_balance_passes(void)
{
    halfword p = null;
    halfword count = tex_scan_integer(1, NULL, NULL);
    if (count > 0) {
        /*tex 
            We have no named options here. Presets are automatically set anyway. We might even drop 
            the option scanning here.
        */
        halfword options = tex_scan_partial_keyword("options") ? tex_scan_integer(0, NULL, NULL) : 0;
        halfword n = 1;
        if (count > 0xFF) {
            /* todo: message */
            count = 0xFF;
        }
        p = tex_new_specification_node(count, balance_passes_code, options);
        while (n <= count) {
            switch (tex_scan_character("acdefilnpqtACDEFILNPQT", 0, 1, 0)) {
                case 0:
                    goto DONE;
                case 'a': case 'A':
                    if (tex_scan_mandate_keyword("adjdemerits", 1)) {
                        tex_set_balance_passes_adjdemerits(p, n, tex_scan_integer(0, NULL, NULL));
                        tex_set_passes_okay(p, n, passes_adjdemerits_okay);
                    }
                    break;
                case 'c': case 'C':
                    if (tex_scan_mandate_keyword("classes", 1)) {
                        tex_set_balance_passes_classes(p, n, tex_scan_integer(0, NULL, NULL));
                        tex_set_balance_passes_features(p, n, passes_criterium_set);
                        tex_set_balance_passes_okay(p, n, passes_classes_okay);
                    }
                    break;
                case 'd': case 'D':
                    if (tex_scan_mandate_keyword("demerits", 1)) {
                        tex_set_balance_passes_demerits(p, n, tex_scan_integer(0, NULL, NULL));
                        tex_set_balance_passes_features(p, n, passes_criterium_set);
                        tex_set_balance_passes_okay(p, n, passes_demerits_okay);
                    }
                    break;
                case 'e': case 'E':
                    switch (tex_scan_character("mxMX", 0, 0, 0)) {
                        case 'm': case 'M':
                            if (tex_scan_mandate_keyword("emergency", 2)) {
                                switch (tex_scan_character("fpsFPS", 0, 0, 0)) {
                                    case 'f': case 'F':
                                        if (tex_scan_mandate_keyword("emergencyfactor", 10)) {
                                            tex_set_balance_passes_emergencyfactor(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_balance_passes_okay(p, n, passes_emergencyfactor_okay);
                                        }
                                        break;
                                    case 'p': case 'P':
                                        if (tex_scan_mandate_keyword("emergencypercentage", 10)) {
                                            tex_set_balance_passes_emergencypercentage(p, n, tex_scan_integer(0, NULL, NULL));
                                            tex_set_balance_passes_okay(p, n, passes_emergencypercentage_okay);
                                        }
                                        break;
                                    case 's': case 'S':
                                        /* todo: emergencyshrink */
                                        if (tex_scan_mandate_keyword("emergencystretch", 10)) {
                                            tex_set_balance_passes_emergencystretch(p, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL));
                                            tex_set_balance_passes_okay(p, n, passes_emergencystretch_okay);
                                        }
                                        break;
                                    default:
                                        goto NOTDONE4;
                                }
                            } else { 
                             // NOTDONE4:
                             // tex_aux_show_keyword_error("emergencyfactor|emergencystretch|emergencypercentage");
                             // goto DONE;
                                goto NOTDONE4;
                            }
                            break;
                        default:
                            NOTDONE4:
                            tex_aux_show_keyword_error("emergencyfactor|emergencystretch|emergencypercentage");
                            goto DONE;
                    }
                    break;
                case 'f': case 'F':
                    if (tex_scan_mandate_keyword("fitnessclasses", 1)) {
                        tex_set_balance_passes_fitnessclasses(p, n, tex_aux_scan_par_specification(fitness_classes_code, tex_aux_scan_specification_fitness_classes));
                        tex_set_balance_passes_okay(p, n, passes_fitnessclasses_okay);
                    }
                    break;
                case 'i': case 'I':
                    switch (tex_scan_character("dfDF", 0, 0, 0)) {
                        case 'd': case 'D':
                            if (tex_scan_mandate_keyword("identifier", 2)) {
                                passes_identifier(p) = tex_scan_integer(0, NULL, NULL);
                            }
                            break;
                        case 'f': case 'F':
                            switch (tex_scan_character("elEL", 0, 0, 0)) {
                                case 'e': case 'E':
                                    if (tex_scan_mandate_keyword("ifemergencystretch", 3)) {
                                        tex_set_balance_passes_features(p, n, passes_if_emergency_stretch);
                                    } 
                                    break;
                                case 'l': case 'L':
                                    if (tex_scan_mandate_keyword("iflooseness", 3)) {
                                        tex_set_balance_passes_features(p, n, passes_if_looseness);
                                    } 
                                    break;
                                default:
                                    tex_aux_show_keyword_error("if[emergencystretch|looseness]");
                                    goto DONE;
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("identifier|if[...]");
                            goto DONE;
                    }
                    break;
                case 'l': case 'L':
                    if (tex_scan_mandate_keyword("looseness", 1)) {
                        tex_set_balance_passes_looseness(p, n, tex_scan_integer(0, NULL, NULL));
                        tex_set_balance_passes_okay(p, n, passes_looseness_okay);
                    } 
                    break;
                case 'n': case 'N':
                    if (tex_scan_mandate_keyword("next", 1)) {
                        n++;
                    }
                    break;
                case 'p': case 'P':
                    if (tex_scan_mandate_keyword("page", 1)) {
                        switch (tex_scan_character("bpBP", 0, 0, 0)) {
                            case 'b': case 'B':
                                if (tex_scan_mandate_keyword("pagebreakchecks", 5)) {
                                    tex_set_balance_passes_pagebreakchecks(p, n, tex_scan_integer(0, NULL, NULL));
                                    tex_set_balance_passes_okay(p, n, passes_balancechecks_okay);
                                } 
                                break;
                            case 'p': case 'P':
                                if (tex_scan_mandate_keyword("pagepenalty", 5)) {
                                    tex_set_balance_passes_pagepenalty(p, n, tex_scan_integer(0, NULL, NULL));
                                    tex_set_balance_passes_okay(p, n, passes_balancepenalty_okay);
                                } 
                                break;
                            default:
                                tex_aux_show_keyword_error("pagebreakchecks|pagepenalty");
                                goto DONE;
                        }
                    }
                    break;
                case 'q': case 'Q':
                    if (tex_scan_mandate_keyword("quit", 1)) {
                        tex_set_balance_passes_features(p, n, passes_quit_pass);
                    }
                    break;
                case 't': case 'T':
                    switch (tex_scan_character("hoHO", 0, 0, 0)) {
                        case 'h': case 'H':
                            if (tex_scan_mandate_keyword("threshold", 2)) {
                                tex_set_balance_passes_threshold(p, n, tex_scan_dimension(0, 0, 0, 0, NULL, NULL));
                                tex_set_balance_passes_features(p, n, passes_criterium_set);
                                tex_set_balance_passes_okay(p, n, passes_threshold_okay);
                            }
                            break;
                        case 'o': case 'O':
                            switch (tex_scan_character("dlDL", 0, 0, 0)) {
                                case 'l': case 'L':
                                    if (tex_scan_mandate_keyword("tolerance", 3)) {
                                        tex_set_balance_passes_tolerance(p, n, tex_scan_integer(0, NULL, NULL));
                                        tex_set_balance_passes_okay(p, n, passes_tolerance_okay);
                                    }
                                    break;
                                default:
                                    goto NOTDONE3;
                            }
                            break;
                        default:
                            NOTDONE3:
                            tex_aux_show_keyword_error("threshold|tolerance");
                            goto DONE;
                    }
                    break;
                default:
                    goto DONE;
            }
        }
      DONE:
        if (n < count) {
            tex_handle_error(
                normal_error_type,
                "there %s only %i of %i %s specified for \\parpasses",
                n == 1 ? "is" : "are", n, count, count == 1 ? "pass" : "passes",
                NULL
            );
        }
        {
            halfword first = tex_aux_first_with_criterium(p, count);
            halfword quit = tex_aux_first_with_quit(p, count);
            if (first == 0) { 
                tex_add_specification_option(p, specification_option_presets);
                passes_first_final(p) = count;
            } else if (first == 1) { 
                tex_remove_specification_option(p, specification_option_presets);
                passes_first_final(p) = 2;
            } else { 
                tex_add_specification_option(p, specification_option_presets);
                passes_first_final(p) = first - 1;
            }
            if (quit) { 
                /*tex We always want a result. */
                passes_first_final(p) = quit == 1 ? 1 : quit - 1;
            }
        }
    }
    return p;
}

static halfword tex_aux_scan_specification_balance_shape(void)
{
    halfword p = null;
    halfword count = tex_scan_integer(1, NULL, NULL);
    if (count > 0) {
        /*tex 
            We have no named options here. Presets are automatically set anyway. We might even drop 
            the option scanning here.
        */
        halfword options = tex_scan_partial_keyword("options") ? tex_scan_integer(0, NULL, NULL) : 0;
        halfword n = 1;
        if (count > 0xFF) {
            /* todo: message */
            count = 0xFF;
        }
        p = tex_new_specification_node(count, balance_shape_code, options);
        while (n <= count) {
            switch (tex_scan_character("itbonvITBONV", 0, 1, 0)) {
                case 0:
                    goto DONE;
                case 'i': case 'I':
                    switch (tex_scan_character("dnDN", 0, 0, 0)) {
                        case 'd': case 'D':
                            if (tex_scan_mandate_keyword("identifier", 2)) {
                                balance_shape_identifier(p) = tex_scan_integer(0, NULL, NULL);
                            }
                            break;
                        case 'n': case 'N':
                            if (tex_scan_mandate_keyword("index", 2)) {
                                tex_set_balance_index(p, n, tex_scan_integer(0, NULL, NULL));
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("identifier|index");
                            goto DONE;
                    } 
                    break;
                case 'v': case 'V':
                    if (tex_scan_mandate_keyword("vsize", 1)) {
                        tex_set_balance_vsize(p, n, tex_scan_dimension(0, 0, 0, 1, NULL, NULL));
                    }
                    break;
                case 't': case 'T':
                    if (tex_scan_mandate_keyword("topskip", 1)) {
                        tex_set_balance_topskip(p, n, tex_scan_glue(glue_val_level, 0, 0));
                    }
                    break;
                case 'b': case 'B':
                    if (tex_scan_mandate_keyword("bottomskip", 1)) {
                        tex_set_balance_bottomskip(p, n, tex_scan_glue(glue_val_level, 0, 0));
                    }
                    break;
                case 'o': case 'O':
                    if (tex_scan_mandate_keyword("options", 1)) {
                        tex_set_balance_options(p, n, tex_scan_integer(0, NULL, NULL));
                    }
                    break;
                case 'n': case 'N':
                    if (tex_scan_mandate_keyword("next", 1)) {
                        n++;
                    }
                    break;
                default:
                    goto DONE;
            }
        }
      DONE:
        if (n < count) {
            tex_handle_error(
                normal_error_type,
                "there %s only %i of %i %s specified for \\balanceshape",
                n == 1 ? "is" : "are", n, count, count == 1 ? "page" : "pages",
                NULL
            );
        }
    }
    return p;
}


static halfword tex_aux_scan_specification(quarterword code)
{
    switch (code) { 
        case par_shape_code: 
            return tex_aux_scan_specification_par_shape();
        case balance_shape_code: 
            return tex_aux_scan_specification_balance_shape();
        case fitness_classes_code: 
            return tex_aux_scan_specification_fitness_classes();
        case adjacent_demerits_code: 
            return tex_aux_scan_specification_adjacent_demerits();
        case par_passes_code: 
        case par_passes_exception_code: 
            return tex_aux_scan_specification_par_passes();
        case balance_passes_code: 
            return tex_aux_scan_specification_balance_passes();
        default: 
            return tex_aux_scan_specification_penalties(code);
    }
}

// void tex_aux_set_specification(int a, halfword target)
// {
//     quarterword code = (quarterword) internal_specification_number(target);
//     halfword p = tex_aux_scan_specification(code);
//     tex_define(a, target, specification_reference_cmd, p);
//     if (is_frozen(a) && cur_mode == hmode) {
//         tex_update_par_par(specification_reference_cmd, code);
//     }
// }

void tex_aux_set_specification(int a, halfword target)
{
    quarterword code = (quarterword) internal_specification_number(target);
    halfword spec = null;
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_cmd) { 
        case specificationspec_cmd: 
            spec = eq_value(cur_cs); 
            spec = spec ? tex_copy_node(spec) : null;
            break;
        default: 
            tex_back_input(cur_tok);
            spec = tex_aux_scan_specification(code);
            break;
    }
    tex_define(a, target, specification_reference_cmd, spec);
    if (is_frozen(a) && cur_mode == hmode) {
        tex_update_par_par(specification_reference_cmd, code);
    }
}

void tex_specification_range_error(halfword target)
{
    tex_handle_error(
        normal_error_type,
        "Specification index should be in the range [1,%i].",
        specification_count(target),
        NULL
    );
}

void tex_run_specification_spec(void)
{
    if (cur_chr) { 
        quarterword code = node_subtype(cur_chr);
        switch (code) {
            case integer_list_code:
            case dimension_list_code:
            case posit_list_code:
                {
                    halfword target = cur_chr;
                    halfword duplex = specification_double(target);
                    halfword index = tex_scan_integer(0, NULL, NULL);
                    halfword first = 0; /*tex Clang doesn't notice that we have three cases only. */ 
                    halfword second = 0; 
                    switch (code) {
                        case integer_list_code:
                            first = tex_scan_integer(1, NULL, NULL);
                            second = duplex ? tex_scan_integer(0, NULL, NULL) : 0;
                            break;
                        case dimension_list_code:
                            first = specification_integer(target) ? tex_scan_integer(1, NULL, NULL) : tex_scan_dimension(0, 0, 0, 0, NULL, NULL);
                            second = duplex ? tex_scan_dimension(0, 0, 0, 0, NULL, NULL) : 0;
                            break;
                        case posit_list_code:
                            first = specification_integer(target) ? tex_scan_integer(0, NULL, NULL) : tex_scan_posit(0);
                            second = duplex ? tex_scan_posit(0) : 0;
                            break;
                    }
                    if (index < 0) {
                        index = specification_count(target) + index + 1;
                    }
                    if (index > specification_count(target) && specification_rotate(target)) {
                        index = (index % specification_count(target));
                        if (index == 0) { 
                            index = specification_count(target);
                        }
                    } 
                    if (index >= 1 && index <= specification_count(target)) {
                        if (duplex) {
                            tex_set_specification_penalty(target, index, second);
                            tex_set_specification_nepalty(target, index, first);
                        } else {
                            tex_set_specification_penalty(target, index, first);
                        }
                    } else { 
                        tex_specification_range_error(target);
                    }
                    break;
                }
            default: 
                {
                    halfword target = internal_specification_location(code);
                    halfword a = 0; /* local */
                    halfword p = tex_copy_node(cur_chr);
                    tex_define(a, target, specification_reference_cmd, p);
                    if (is_frozen(a) && cur_mode == hmode) {
                        tex_update_par_par(specification_reference_cmd, code);
                    }
                    break;
                }
        }
    }
}

halfword tex_scan_specifier(void)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_cmd) { 
        case specificationspec_cmd: 
            {
                halfword spec = eq_value(cur_cs); 
                return spec ? tex_copy_node(spec) : null;
            }
        case specification_cmd:
            {
                quarterword code = (quarterword) internal_specification_number(cur_chr);
                halfword spec = tex_aux_scan_specification(code);
                if (! spec) { 
                    /* We want to be able to reset. */
                    spec = tex_new_specification_node(0, code, 0);
                }
                return spec; 
            }
        case register_cmd:
            switch (cur_chr) { 
                case integer_val_level:
                case dimension_val_level:
                case posit_val_level:
                    return tex_aux_scan_specification_list((quarterword) cur_chr);
                default:
                    break;
            }
    }
    tex_handle_error(
        back_error_type,
        "Missing or invalid specification",
        "I expect to see classification command like \\widowpenalties."
    );
    return null;
}

halfword tex_aux_get_specification_value(halfword spec, halfword code)
{
    halfword count = specification_count(spec);
    (void) code;
    switch (node_subtype(spec)) { 
        case par_shape_code:
        case par_passes_code:
        case fitness_classes_code:
            {
                halfword index = tex_scan_integer(0, NULL, NULL);
                return tex_get_specification_fitness_class(spec, index); /* weird call */
            }
        case balance_shape_code:
            {
                return 0;
            }
        case adjacent_demerits_code:
            {
                halfword index = tex_scan_integer(0, NULL, NULL);
                if (index == -1) {
                    return specification_adjacent_adj(spec);
                } else { 
                    return tex_get_specification_adjacent_u(spec, index);
                }
            }
        default:
            {
                halfword index = tex_scan_integer(0, NULL, NULL);
                if (! count) { 
                    if (index == 1 || index == -1) {
                        return tex_get_specification_penalty(spec, 1);
                    }
                } else if (index) {
                    if (index < 1) {
                        /*tex We count from the end. */
                        index = count + index + 1;
                    }
                    if (index > count) {
                        /*tex The last one in a penalty list repeated. */
                        index = count; 
                    }
                    if (index >= 1) { 
                        return tex_get_specification_penalty(spec, index);
                    } else {
                        /*tex We silently ignore this. */
                    }
                }
           }
           break;
    }
    return 0;
}
