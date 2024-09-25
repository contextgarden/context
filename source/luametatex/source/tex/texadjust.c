/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex 

Traditional \TEX\ only has |\vadjust| that injects its content after the line that it's embedded 
in. The \PDFTEX\ engine added a |pre| keyword so that we can also inject before a line. Here we
extend the functionality again. First of all we migrate the pre and post material to the outer 
vertical level. This goes via dedicated fields in the list nodes. We also have more keywords 
that control depth before and after the line so that we can get more consistent spacing. Appending 
and prepending can be controlled too. There is of course more overhead than in traditional \TEX, 
but it can normally be neglected because |\vadjust| is not used that often. 

*/

typedef struct adjust_properties {
    halfword options;
    halfword code;
    halfword index;
    scaled   depthbefore;
    scaled   depthafter;
    halfword attrlist;
    scaled   except; 
    halfword padding;
} adjust_properties;

typedef enum saved_adjust_entries {
    saved_adjust_location_entry     = 0,
    saved_adjust_options_entry      = 0,
    saved_adjust_index_entry        = 0,
    saved_adjust_attr_list_entry    = 1,
    saved_adjust_depth_before_entry = 1,
    saved_adjust_depth_after_entry  = 1,
    saved_adjust_except_entry       = 2,
    saved_adjust_target_entry       = 2,
    saved_adjust_n_of_records       = 3,
} saved_adjust_entries;

inline static void saved_adjust_initialize(void)
{
    saved_type(0) = saved_record_0;
    saved_type(1) = saved_record_1;
    saved_type(2) = saved_record_2;
    saved_record(0) = adjust_save_type;
    saved_record(1) = adjust_save_type;
    saved_record(2) = adjust_save_type;
}

# define saved_adjust_location     saved_value_1(saved_adjust_location_entry)
# define saved_adjust_options      saved_value_2(saved_adjust_options_entry)
# define saved_adjust_index        saved_value_3(saved_adjust_index_entry)
# define saved_adjust_attr_list    saved_value_1(saved_adjust_attr_list_entry)
# define saved_adjust_depth_before saved_value_2(saved_adjust_depth_before_entry)
# define saved_adjust_depth_after  saved_value_3(saved_adjust_depth_after_entry)
# define saved_adjust_except       saved_value_1(saved_adjust_except_entry)
# define saved_adjust_target       saved_value_2(saved_adjust_target_entry)

void tex_show_adjust_group(void)
{
    tex_print_str_esc("vadjust");
    if (saved_adjust_location == pre_adjust_code) {
        tex_print_str(" pre");
    }
    if (saved_adjust_options & adjust_option_before) {
        tex_print_str(" before");
    }
}

int tex_show_adjust_record(void)
{
    tex_print_str("adjust ");
    switch (saved_type(0)) { 
       case saved_record_0:
            tex_print_format("location %i, options %i, index %i", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
       case saved_record_1:
            tex_print_format("attrlist %i, depth before %p, depth after %p", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
       case saved_record_2:
            tex_print_format("target %i", saved_value_1(0));
            break;
       default: 
            return 0;
    }
    return 1;
}

static void tex_scan_adjust_keys(adjust_properties *properties)
{
    properties->code = post_adjust_code;
    properties->options = adjust_option_none;
    properties->index = 0;
    properties->depthbefore = 0;
    properties->depthafter = 0;
    properties->attrlist = null;
    properties->except = 0;
    while (1) {
        switch (tex_scan_character("abdeipABDEIP", 0, 1, 0)) {
            case 'p': case 'P':
                switch (tex_scan_character("roRO", 0, 0, 0)) {
                    case 'r': case 'R':
                        if (tex_scan_mandate_keyword("pre", 2)) {
                            properties->code = pre_adjust_code;
                        }
                        break;
                    case 'o': case 'O':
                        if (tex_scan_mandate_keyword("post", 2)) {
                            properties->code = post_adjust_code;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("pre|post");
                        goto DONE;
                }
                break;
            case 'b': case 'B':
                switch (tex_scan_character("aeAE", 0, 0, 0)) {
                    case 'a': case 'A':
                        if (tex_scan_mandate_keyword("baseline", 2)) {
                            properties->options |= adjust_option_baseline;
                        }
                        break;
                    case 'e': case 'E':
                        if (tex_scan_mandate_keyword("before", 2)) {
                            properties->options |= adjust_option_before;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("baseline|before");
                        goto DONE;
               }
                break;
            case 'i': case 'I':
                if (tex_scan_mandate_keyword("index", 1)) {
                    properties->index = tex_scan_integer(0, NULL);
                    if (! tex_valid_adjust_index(properties->index)) {
                        properties->index = 0; /* for now no error */
                    }
                }
                break;
            case 'a': case 'A':
                switch (tex_scan_character("ftFT", 0, 0, 0)) {
                    case 'f': case 'F':
                        if (tex_scan_mandate_keyword("after", 2)) {
                            properties->options &= ~(adjust_option_before | properties->options);
                        }
                        break;
                    case 't': case 'T':
                        if (tex_scan_mandate_keyword("attr", 2)) {
                            properties->attrlist = tex_scan_attribute(properties->attrlist);
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("after|attr");
                        goto DONE;
                }   
                break;
            case 'd': case 'D':
                if (tex_scan_mandate_keyword("depth", 1)) {
                    switch (tex_scan_character("abclABCL", 0, 1, 0)) { /* so a space is permitted */
                        case 'a': case 'A':
                            if (tex_scan_mandate_keyword("after", 1)) {
                                properties->options |= adjust_option_depth_after;
                                properties->depthafter = tex_scan_dimension(0, 0, 0, 0, NULL);
                            }
                            break;
                        case 'b': case 'B':
                            if (tex_scan_mandate_keyword("before", 1)) {
                                properties->options |= adjust_option_depth_before;
                                properties->depthbefore = tex_scan_dimension(0, 0, 0, 0, NULL);
                            }
                            break;
                        case 'c': case 'C':
                            if (tex_scan_mandate_keyword("check", 1)) {
                                properties->options |= adjust_option_depth_check;
                            }
                            break;
                        case 'l': case 'L':
                            if (tex_scan_mandate_keyword("last", 1)) {
                                properties->options |= adjust_option_depth_last;
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("after|before|check|last");
                            goto DONE;
                    }
                }
                break;
            case 'e': case 'E':
                if (tex_scan_mandate_keyword("except", 1)) {
                    properties->except = tex_scan_dimension(0, 0, 0, 0, NULL);
                    properties->options |= adjust_option_except;
                }
                break;
            default:
                goto DONE;
        }
    }
  DONE:
    if (! properties->attrlist) {
        properties->attrlist = tex_current_attribute_list();
        add_attribute_reference(properties->attrlist); /* needs checking */
    }
}

int tex_valid_adjust_index(halfword n)
{
    return n >= 0;
}

void tex_set_vadjust(halfword target)
{
    adjust_properties properties;
    tex_scan_adjust_keys(&properties);
    saved_adjust_initialize();
    saved_adjust_location = properties.code;
    saved_adjust_options = properties.options;
    saved_adjust_index = properties.index;
    saved_adjust_attr_list = properties.attrlist;
    saved_adjust_depth_before = properties.depthbefore;
    saved_adjust_depth_after = properties.depthafter;
    saved_adjust_except = properties.except;
    saved_adjust_target = target;
    lmt_save_state.save_stack_data.ptr += saved_adjust_n_of_records;
    tex_new_save_level(vadjust_group);
    tex_scan_left_brace();
    tex_normal_paragraph(vadjust_par_context);
    tex_push_nest();
    cur_list.mode = internal_vmode;
    cur_list.prev_depth = ignore_depth_criterion_par;
}

void tex_run_vadjust(void)
{
    tex_set_vadjust(-1);
}

void tex_finish_vadjust_group(void)
{
    if (! tex_wrapped_up_paragraph(vadjust_par_context, 0)) {
        halfword box, adjust, target; /*tex for short-term use */
        tex_end_paragraph(vadjust_group, vadjust_par_context);
        tex_unsave();
        lmt_save_state.save_stack_data.ptr -= saved_adjust_n_of_records;
        box = tex_vpack(node_next(cur_list.head), 0, packing_additional, max_dimension, direction_unknown, holding_none_option, NULL);
        tex_pop_nest();
        adjust = tex_new_node(adjust_node, (quarterword) saved_adjust_location);
        target = saved_adjust_target;
        adjust_list(adjust) = box_list(box);
        adjust_options(adjust) = (halfword) saved_adjust_options;
        adjust_index(adjust) = (halfword) saved_adjust_index;
        adjust_depth_before(adjust) = (halfword) saved_adjust_depth_before;
        adjust_depth_after(adjust) = (halfword) saved_adjust_depth_after;
        adjust_except(adjust) = (halfword) saved_adjust_except;
        tex_attach_attribute_list_attribute(adjust, (halfword) saved_adjust_attr_list);
        if (target < 1) {
            tex_tail_append(adjust);
        } else { 
            tex_adjust_attach(target, adjust);
        }
        if (has_adjust_option(adjust, adjust_option_except) && ! adjust_list(adjust)) { 
            /*tex 
                We create a simple adjust node. Anything more complex is kind of weird anyway. We 
                need something in the list in order to make migration work out anyway. 
            */
            node_subtype(adjust) = post_adjust_code;
            adjust_depth_before(adjust) = 0;
            adjust_depth_after(adjust) = 0;
            adjust_list(adjust) = tex_new_node(boundary_node, adjust_boundary);
        }
        box_list(box) = null;
        tex_flush_node(box);
        /*tex We never do the callback ... maybe move it outside. */
        if (target < 0 && lmt_nest_state.nest_data.ptr == 0) {
            tex_build_page(vadjust_page_context, 0);
        }
    }
}

/*tex Append or prepend vadjust nodes. Here head is a temp node! */

halfword tex_append_adjust_list(halfword head, halfword tail, halfword adjust, const char *detail)
{
    while (adjust && node_type(adjust) == adjust_node) {
        halfword next = node_next(adjust);
        if (tail == head) {
            node_next(head) = adjust;
        } else {
            tex_couple_nodes(tail, adjust);
        }
        if (tracing_adjusts_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[adjust: index %i, location %s, append, %s]", adjust_index(adjust), tex_aux_subtype_str(adjust), detail);
            tex_print_node_list(adjust_list(adjust), "adjust",show_box_depth_par, show_box_breadth_par);
            tex_end_diagnostic();
        }
        tail = adjust;
        adjust = next;
    }
    return tail;
}

halfword tex_prepend_adjust_list(halfword head, halfword tail, halfword adjust, const char *detail)
{
    while (adjust && node_type(adjust) == adjust_node) {
        halfword next = node_next(adjust);
        if (tail == head) {
            node_next(head) = adjust;
            tail = adjust;
        } else {
            tex_try_couple_nodes(adjust, node_next(node_next(head)));
            tex_couple_nodes(node_next(head), adjust);
        }
        if (tracing_adjusts_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[adjust: index %i, location %s, prepend, %s]", adjust_index(adjust), tex_aux_subtype_str(adjust), detail);
            tex_print_node_list(adjust_list(adjust), "adjust", show_box_depth_par, show_box_breadth_par);
            tex_end_diagnostic();
        }
        adjust = next;
    }
    return tail;
}

void tex_inject_adjust_list(halfword adjust, int obeyoptions, halfword nextnode, const line_break_properties *properties)
{
    if (adjust && node_type(adjust) == temp_node) {
        adjust = node_next(adjust);
    }
    while (adjust && node_type(adjust) == adjust_node) {
        halfword next = node_next(adjust);
        halfword list = adjust_list(adjust);
        if (tracing_adjusts_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[adjust: index %i, location %s, inject]", adjust_index(adjust), tex_aux_subtype_str(adjust));
            tex_print_node_list(adjust_list(adjust), "adjust", show_box_depth_par, show_box_breadth_par);
            tex_end_diagnostic();
        }
        if (list) {
            if (obeyoptions) {
                /*tex 
                    We can have an except here which means that we can have a adjust boundary in 
                    order to get here at all. We need to wipe that one so that it can't interfere
                    in (for instance) callbacks.
                */
                if (node_type(list) == boundary_node && node_subtype(list) == adjust_boundary) {
                    tex_flush_node_list(list);
                } else { 
                    if (has_adjust_option(adjust, adjust_option_baseline)) { 
                        /*tex
                            Here we attach data to a line. On the todo is to prepend and append to 
                            the lines (nicer when we number lines). We could also look at rules. 
                        */
                        switch (node_type(list)) { 
                            case hlist_node:
                            case vlist_node:
                                if (nextnode) { 
                                    /*tex 
                                        This is the |pre| case where |nextnode| is the line to be appended 
                                        after the adjust box |list|.
                                    */
                                    if (node_type(nextnode) == hlist_node || node_type(nextnode) == vlist_node) {
                                        if (box_height(nextnode) > box_height(list)) {
                                            box_height(list) = box_height(nextnode);
                                        }
                                        if (box_depth(list) > box_depth(nextnode)) {
                                            box_depth(nextnode) = box_depth(list);
                                        }
                                        /* not ok yet */
                                        box_y_offset(nextnode) += box_height(nextnode);
                                        tex_check_box_geometry(nextnode);
                                        /* till here */
                                        box_height(nextnode) = 0;
                                        box_depth(list) = 0;
                                    }
                                } else { 
                                    /*tex 
                                        Here we have the |post| case where the line will end up before the 
                                        adjusted content.
                                    */
                                    halfword prevnode = cur_list.tail;
                                    if (node_type(prevnode) == hlist_node || node_type(prevnode) == vlist_node) {
                                        if (box_height(prevnode) < box_height(list)) {
                                            box_height(prevnode) = box_height(list);
                                        }
                                        if (box_depth(list) < box_depth(prevnode)) {
                                            box_depth(list) = box_depth(prevnode);
                                        }
                                        box_height(list) = 0;
                                        box_depth(prevnode) = 0;
                                    }
                                }
                                break;
                        }
                    }
                    if (has_adjust_option(adjust, adjust_option_depth_before)) { 
                        cur_list.prev_depth = adjust_depth_before(adjust);
                    }
                    if (has_adjust_option(adjust, adjust_option_depth_check)) { 
                        tex_append_to_vlist(list, -1, properties);
                    } else { 
                        tex_tail_append_list(list);
                    }
                    if (has_adjust_option(adjust, adjust_option_depth_after)) { 
                        cur_list.prev_depth = adjust_depth_after(adjust);
                    } else if (has_adjust_option(adjust, adjust_option_depth_last)) { 
                        /*tex We could also look at rules. */
                        switch (node_type(list)) { 
                            case hlist_node:
                            case vlist_node:
                                cur_list.prev_depth = box_depth(list);
                                break;
                        }
                    }
                }
            } else { 
                tex_tail_append_list(list);
            }
            if (! lmt_page_builder_state.output_active) {
                lmt_append_line_filter_callback(post_adjust_append_line_context, adjust_index(adjust));
            }
            adjust_list(adjust) = null;
        }
        tex_flush_node(adjust);
        adjust = next;
    }
}


void tex_adjust_attach(halfword box, halfword adjust)
{
    if (adjust_list(adjust)) {
        node_prev(adjust) = null;
        node_next(adjust) = null;
        if (tracing_adjusts_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[adjust: index %i, location %s, attach]", adjust_index(adjust), tex_aux_subtype_str(adjust));
            tex_print_node_list(adjust_list(adjust), "attach",show_box_depth_par, show_box_breadth_par);
            tex_end_diagnostic();
        }
        switch (node_subtype(adjust)) {
            case pre_adjust_code:
                if (! box_pre_adjusted(box)) {
                    box_pre_adjusted(box) = adjust;
                } else if (has_adjust_option(adjust, adjust_option_before)) {
                    tex_couple_nodes(adjust, box_pre_adjusted(box));
                    box_pre_adjusted(box) = adjust;
                } else {
                    tex_couple_nodes(tex_tail_of_node_list(box_pre_adjusted(box)), adjust);
                }
                node_subtype(adjust) = local_adjust_code;
                break;
            case post_adjust_code:
                if (! box_post_adjusted(box)) {
                    box_post_adjusted(box) = adjust;
                } else if (has_adjust_option(adjust, adjust_option_before)) {
                    tex_couple_nodes(adjust, box_post_adjusted(box));
                    box_post_adjusted(box) = adjust;
                } else {
                    tex_couple_nodes(tex_tail_of_node_list(box_post_adjusted(box)), adjust);
                }
                node_subtype(adjust) = local_adjust_code;
                break;
            case local_adjust_code:
                tex_normal_error("vadjust post", "unexpected local attach");
                break;
        }
    } else {
        tex_flush_node(adjust);
    }
}

void tex_adjust_passon(halfword box, halfword adjust)
{
    halfword head = adjust ? adjust_list(adjust) : null;
    (void) box;
    if (head) {
        node_prev(adjust) = null;
        node_next(adjust) = null;
        switch (node_subtype(adjust)) {
            case pre_adjust_code:
                if (lmt_packaging_state.pre_adjust_tail) {
                    if (lmt_packaging_state.pre_adjust_tail != pre_adjust_head && has_adjust_option(adjust, adjust_option_before)) {
                        lmt_packaging_state.pre_adjust_tail = tex_prepend_adjust_list(pre_adjust_head, lmt_packaging_state.pre_adjust_tail, adjust, "passon");
                    } else {
                        lmt_packaging_state.pre_adjust_tail = tex_append_adjust_list(pre_adjust_head, lmt_packaging_state.pre_adjust_tail, adjust, "passon");
                    }
                } else {
                    tex_normal_error("vadjust pre", "invalid list");
                }
                break;
            case post_adjust_code:
                if (has_adjust_option(adjust, adjust_option_except) && adjust_except(adjust) > lmt_packaging_state.except) { 
                    lmt_packaging_state.except = adjust_except(adjust);
                }
                if (lmt_packaging_state.post_adjust_tail) {
                    if (lmt_packaging_state.post_adjust_tail != post_adjust_head && has_adjust_option(adjust, adjust_option_before)) {
                        lmt_packaging_state.post_adjust_tail = tex_prepend_adjust_list(post_adjust_head, lmt_packaging_state.post_adjust_tail, adjust, "passon");
                    } else {
                        lmt_packaging_state.post_adjust_tail = tex_append_adjust_list(post_adjust_head, lmt_packaging_state.post_adjust_tail, adjust, "passon");
                    }
                } else {
                    tex_normal_error("vadjust post", "invalid list");
                }
                break;
            case local_adjust_code:
                tex_normal_error("vadjust post", "unexpected local passon");
                break;
        }
    } else {
        tex_flush_node(adjust);
    }
}

static void tex_aux_show_flush_adjust(halfword adjust, const char *what, const char *detail)
{
    if (tracing_adjusts_par > 1) {
        tex_begin_diagnostic();
        tex_print_format("[adjust: index %i, location %s, flush, %s]", adjust_index(adjust), tex_aux_subtype_str(adjust), detail);
        tex_print_node_list(adjust_list(adjust), what, show_box_depth_par, show_box_breadth_par);
        tex_end_diagnostic();
    }
}

halfword tex_flush_adjust_append(halfword adjust, halfword tail)
{
    while (adjust) {
        halfword p = adjust;
        halfword h = adjust_list(adjust);
        if (h) {
            int ishmode = is_h_mode(cur_list.mode);
            tex_aux_show_flush_adjust(p, "append", ishmode ? "repack" : "direct");
            if (ishmode) { 
                halfword n = tex_new_node(adjust_node, post_adjust_code);
                // tex_attach_attribute_list_copy(n, post_adjusted);
                adjust_list(n) = h;
                h = n;
            }
            tex_try_couple_nodes(tail, h);
            tail = tex_tail_of_node_list(h);
            adjust_list(p) = null;
        }
        adjust = node_next(p);
        tex_flush_node(p);
    }
    return tail;
}

halfword tex_flush_adjust_prepend(halfword adjust, halfword tail)
{
    while (adjust) {
        halfword p = adjust;
        halfword h = adjust_list(adjust);
        if (h) {
            int ishmode = is_h_mode(cur_list.mode);
            tex_aux_show_flush_adjust(p, "prepend", ishmode ? "repack" : "direct");
            if (ishmode) { 
                halfword n = tex_new_node(adjust_node, pre_adjust_code);
                // tex_attach_attribute_list_copy(n, pre_adjusted);
                adjust_list(n) = h;
                h = n;
            }
            tex_try_couple_nodes(tail, h);
            tail = tex_tail_of_node_list(h);
            adjust_list(p) = null;
        }
        adjust = node_next(p);
        tex_flush_node(p);
    }
    return tail;
}

void tex_initialize_adjust(void)
{
}

void tex_cleanup_adjust(void)
{
}
