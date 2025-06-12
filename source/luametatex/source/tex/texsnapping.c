/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex This is experimental code, and it might disappear. */

int tex_snapping_needed(snapping_specification *specification)
{
    return specification && specification->method; 
}

void tex_snapping_reset(snapping_specification *specification)
{
    if (specification) {
        memset(specification, 0, sizeof(snapping_specification));
    }
}

int tex_snapping_content(halfword first, halfword last, snapping_specification *specification)
{
    int okay = 0;
    if (specification && specification->method) {
        int enforce = 0;
        int ignore = 0;
        while (first) {
            switch (node_type(first)) {
                case hlist_node:
                case vlist_node:
                    if (! tex_has_box_option(first, box_option_no_snapping)) {
                        if (! ignore && (enforce || (specification->method & snapping_method_list))) {
                            if (specification->method & snapping_method_threshold) {
                                if (box_height(first) <= specification->top) {
                                    box_height(first) = specification->height;
                                    okay = 1;
                                }
                                if (box_depth(first) <= specification->bottom) {
                                    box_depth(first) = specification->depth;
                                    okay = 1;
                                }
                            }
                        }
                    }
                    break;
                case rule_node:
                    if (! tex_has_rule_option(first, rule_option_no_snapping)) {
                        if (! ignore && (enforce || specification->method & snapping_method_rule)) {
                            if (specification->method & snapping_method_threshold) {
                                if (rule_height(first) <= specification->top) {
                                    rule_height(first) = specification->height;
                                    okay = 1;
                                }
                                if (rule_depth(first) <= specification->bottom) {
                                    rule_depth(first) = specification->depth;
                                    okay = 1;
                                }
                            }
                        }
                    }
                    break;
                case math_node:
                    {
                        switch (node_subtype(first)) {
                            case begin_inline_math:
                            case begin_broken_math:
                                if (tex_has_math_option(first, math_option_no_snapping)) {
                                    ignore = 1;
                                    enforce = 0;
                                } else {
                                    ignore = ! (specification->method & snapping_method_math);
                                    enforce = 1;
                                }
                                break;
                            case end_inline_math:
                            case end_broken_math:
                                ignore = 0;
                                enforce = 0;
                                break;
                        }
                    }
                    break;
            }
            if (first == last) { 
                return 0; 
            } else {
                first = node_next(first);
            }
        }
    }
    return okay;
}

int tex_snapping_indeed(halfword first, halfword last, snapping_specification *specification)
{
    int okay = 0;
    if (specification && specification->method) {
        int enforce = 0;
        int ignore = 0;
        while (first) {
            switch (node_type(first)) {
                case hlist_node:
                case vlist_node:
                    if (! ignore && (enforce || (specification->method & snapping_method_list) || tex_has_box_option(first, box_option_snapping))) {
                        if (specification->method & snapping_method_threshold) {
                            if (box_height(first) <= specification->top && box_depth(first) <= specification->bottom) {
                                okay = 1;
                            }
                        }
                    } else {
                        if (box_height(first) > specification->height || box_depth(first) > specification->depth) {
                            return 0;
                        }
                    }
                    break;
                case glyph_node:
                 // if (tex_has_glyph_option(first, glyph_option_snapping)) {
                 //     if (! ignore && (enforce || specification->method & snapping_method_glyph)) {
                 //         if (specification->method & snapping_method_threshold) {
                 //             if (glyph_height(first) <= specification->top && glyph_depth(first) <= specification->bottom) {
                 //                 okay = 1;
                 //             }
                 //         }
                 //     }
                 // } else { 
                 //     if (tex_char_height_from_glyph(first) > specification->height || tex_char_depth_from_glyph(first) > specification->depth) {
                 //         return 0;
                 //     }
                 // }
                    break;
                case rule_node:
                    if (tex_has_rule_option(first, rule_option_snapping)) {
                        if (! ignore && (enforce || specification->method & snapping_method_rule)) {
                            if (specification->method & snapping_method_threshold) {
                                if (rule_height(first) <= specification->top && rule_depth(first) <= specification->bottom) {
                                    okay = 1;
                                }
                            }
                        }
                    } else { 
                        if (rule_height(first) > specification->height || rule_depth(first) > specification->depth) {
                            return 0;
                        }
                    }
                    break;
                case math_node:
                    {
                        switch (node_subtype(first)) {
                            case begin_inline_math:
                            case begin_broken_math:
                                if (tex_has_math_option(first, math_option_snapping)) {
                                    ignore = ! (specification->method & snapping_method_math);
                                    enforce = 1;
                                } else {
                                    ignore = 1;
                                    enforce = 0;
                                }
                                break;
                            case end_inline_math:
                            case end_broken_math:
                                ignore = 1;
                                enforce = 0;
                                break;
                        }
                    }
                    break;
            }
            if (first == last) { 
                return okay; 
            } else {
                first = node_next(first);
            }
        }
    }
    return okay; 
}
