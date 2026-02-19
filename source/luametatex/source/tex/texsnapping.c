/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex
    This is experimental code, and it might disappear. It relates to snapping using \LUA, something
    we have in \CONTEXT\ (where snapping went from \MKII, to \MKVI\ and eventually \MKXL, but in
    2025 we started experimenting with more native snapping support in the engine.
*/

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

/*tex
    Here we have native snapping features, although they still assume control from the macro
    package end, maybe with a bit of \LUA\ help. Consider this experimental until it's used
    in \CONTEXT\ and documented there.

    We use an approach similar to par and balance passes, that is: we use specifications. For
    now we have one step but we might end up with more steps if we find a reason and variant
    approaches.
*/

halfword tex_snapping_scan(void)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_cmd) {
        case specificationspec_cmd:
            {
                halfword snapping = eq_value(cur_cs);
                if (node_subtype(snapping) == line_snapping_code) {
                    return snapping;
                }
            }
            break;
        case specification_cmd:
            if (cur_chr) {
                quarterword code = (quarterword) internal_specification_number(cur_chr);
                if (code == line_snapping_code) {
                    return eq_value(cur_chr); /* line_snapping_par */
                }
            }
            break;
    }
    tex_handle_error(
        back_error_type,
        "Missing or invalid snapping specification",
        "I expect to see a pre-defined snapping specification."
    );
    return null;
}

/*tex
    Because we want to trace we need a few more variables than optimal but the overhead can be
    neglected. The next helper is not that efficient, in the sense that it checks and sets up 
    conditions every time, which in a loop over a list iadd overhead. On the other hand, the 
    number of boxes that need snapping is normally not that large. 
*/

static inline scaled tex_aux_snap_dimen(scaled amount, halfword local_factor, halfword global_factor)
{
    if (amount) {
        /*tex
            We need to use the \TEX\ scaler and can't use double magic here! But when we
            go for an interval, then we can go double.
        */
        if (global_factor != scaling_factor) {
            amount = tex_xn_over_d_factor(amount, global_factor);
        }
        if (local_factor != scaling_factor) {
            amount = tex_xn_over_d_factor(amount, local_factor);
        }
    }
    return amount;
}

void tex_snapping_done(halfword *ht, halfword *dp, halfword snapping)
{
    if (snapping && specification_count(snapping) > 0) {
        int options = tex_get_line_snapping_options(snapping, 1);
        int factors = specification_factors(snapping);
        int global = specification_global(snapping);
        scaled amount = glue_amount(baseline_skip_par);
        scaled height = tex_get_line_snapping_height(snapping, 1);
        scaled depth  = tex_get_line_snapping_depth(snapping, 1);
        if (factors) {
            height = tex_aux_snap_dimen(amount, factors ? height : scaling_factor, global ? line_snapping_ht_factor_par : scaling_factor);
            depth  = tex_aux_snap_dimen(amount, factors ? depth  : scaling_factor, global ? line_snapping_dp_factor_par : scaling_factor);
        }
        if (height > 0 && depth > 0) {

    // if (keep && *ht < height && *dp < depth) {
    //      return;
    // }

            scaled tolerance = line_snapping_tolerance_par;
            scaled oldht = *ht;
            scaled olddp = *dp;
            scaled httolerance = tex_get_line_snapping_httolerance(snapping, 1);
            scaled dptolerance = tex_get_line_snapping_dptolerance(snapping, 1);
            scaled newht = height;
            scaled newdp = depth;
            scaled th, td;
            if (factors) {
                httolerance = tex_aux_snap_dimen(amount, factors ? httolerance : scaling_factor, global ? line_snapping_ht_factor_par : scaling_factor);
                dptolerance = tex_aux_snap_dimen(amount, factors ? dptolerance : scaling_factor, global ? line_snapping_dp_factor_par : scaling_factor);
            }
            th = oldht - httolerance - tolerance;
            td = olddp - dptolerance - tolerance;
            if (th < height) {
                *ht = newht;
            }
            if (td < depth) {
                *dp = newdp;
            }
            if (*ht > height || *dp > depth) {
                halfword step = tex_get_line_snapping_step(snapping, 1);
                int nh = 0;
                int nd = 0;
                if (step == 1 || step == 2) {
                    scaled ln = height + depth;
                    if (step == 1) {
                        while (newht < th) {
                            newht += ln;
                            nh++;
                        }
                        while (newdp < td) {
                            newdp += ln;
                            nd++;
                        }
                    } else {
                        while (newht < th) {
                            newht += ln/2;
                            nh++;
                        }
                        while (newdp < td) {
                            newdp += ln/2;
                            nd++;
                        }
                        if ((nh + nd) % 2) {
                            if (nh < nd) {
                                newht += ln/2;
                                nh++;
                            } else {
                                newdp += ln/2;
                                nd++;
                            }
                        } else {
                            /* we're fine */
                        }
                        if (ln % 2) {
                            /* We're off, is the next hack okay? */
                            newht += nh;
                            newdp += nd;
                        }
                    }
                } else {
                    newht = *ht;
                    newdp = *dp;
                }
                if (options & line_snapping_option_top) {
                 // if (options & line_snapping_option_line) {
                 // } else {
                        scaled delta = newht - height;
                        newdp = newdp + delta;
                        newht = height;
                 // }
                } else if (options & line_snapping_option_bottom) {
                 // if (options & line_snapping_option_line) {
                 // } else {
                       scaled delta = newdp - depth;
                        newht = newht + delta;
                        newdp = depth;
                 // }
                }
                *ht = newht;
                *dp = newdp;
                if (tracing_snapping_par > 0) {
                    tex_begin_diagnostic();
                    tex_print_format(
                        "%l[snapping: old (%p,%p), new (%p,%p), line (%p,%p), tolerance (%p,%p), step %i, applied (%i,%i)]",
                        oldht, olddp, newht, newdp,
                        height, depth, httolerance, dptolerance,
                        step, nh, nd
                    );
                    tex_end_diagnostic();
                }
            } else if (tracing_snapping_par > 0) {
                tex_begin_diagnostic();
                if (httolerance || dptolerance) {
                    tex_print_format(
                        "%l[snapping: old (%p,%p), new (%p,%p), line (%p,%p), tolerance (%p,%p)]",
                        oldht, olddp, newht, newdp,
                        height, depth, httolerance, dptolerance
                    );
                } else {
                    tex_print_format(
                        "%l[snapping: old (%p,%p), new (%p,%p), line (%p,%p)]",
                        oldht, olddp, newht, newdp,
                        height, depth
                    );
                }
                tex_end_diagnostic();
            }
        }
    }
}

void tex_snapping_line(halfword box, halfword snapping)
{
    if (! is_box_snapped_state(box)) {
     // tex_snapping_done(&(box_height(box)), &(box_depth(box)), snapping);
        scaled ht = box_height(box);
        scaled dp = box_depth(box);
        box_natural_height(box) = ht;
        box_natural_depth(box) = dp;
        if (tex_has_box_option(box, box_option_no_snapping)) {
            /* ignore */
        } else {
            tex_snapping_done(&ht, &dp, snapping);
            box_height(box) = ht;
            box_depth(box) = dp;
        }
        set_box_snapped_state(box);
    }
}

halfword tex_snapping_rule(halfword rule, halfword snapping, quarterword subtype)
{
    switch (node_subtype(rule)) {
        case normal_rule_subtype:
        case empty_rule_subtype:
            {
                scaled oldwd = rule_width(rule);
                scaled oldht = rule_height(rule);
                scaled olddp = rule_depth(rule);
                if (oldwd == null_flag || (oldht == null_flag && olddp == null_flag)) {
                    /* Definitely not as we pack (one can use uleaders). */
                } else {
                    scaled newht = oldht;
                    scaled newdp = olddp;
                    if (oldht == null_flag) {
                        newht = 0;
                    }
                    if (olddp == null_flag) {
                        newdp = 0;
                    }
                    tex_snapping_done(&newht, &newdp, snapping);
                    if (newht != oldht || newdp != olddp) {
                        halfword prev = node_prev(rule);
                        halfword next = node_next(rule);
                        halfword list = tex_new_node(hlist_node, subtype);
                        /* we could pack twice when we have a nulkl_flag */
                        box_natural_height(list) = oldht;
                        box_natural_depth(list) = olddp;
                        /* */
                        node_prev(rule) = null;
                        node_next(rule) = null;
                        box_list(list) = rule;
                        tex_attach_attribute_list_copy(list, rule);
                        tex_try_couple_nodes(prev, list);
                        tex_try_couple_nodes(list, next);
                        box_width(list) = oldwd;
                        if (oldht != null_flag) {
                            box_height(list) = newht;
                        }
                        if (olddp != null_flag) {
                            box_depth(list) = newdp;
                        }
                        set_box_snapped_state(list);
                        return list;
                    }
                }
                break;
            }
    }
    return rule;
}

halfword tex_snapping_list(halfword head, halfword tail, halfword snapping)
{
    halfword current = head;
    while (current) {
        int last = current == tail;
        switch (node_type(current)) {
            case hlist_node:
            case vlist_node:
                tex_snapping_line(current, snapping);
                break;
            case rule_node:
                {
                    int initial = current == head;
                    current = tex_snapping_rule(current, snapping, math_rule_list);
                    if (initial) {
                      head = current;
                    }
                    break;
                }
        }
        if (last) {
            break;
        } else {
            current = node_next(current);
        }
    }
    return head;
}
