/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex
    The concept of local left and right boxes originates in \OMEGA\ but in \LUATEX\ it already was
    adapted and made more robust. Here we use an upgraded version with more features. These boxes
    are sort of a mix between marks (states) and inserts (with dimensions).

    We have linked lists of left or right boxes. This permits selective updating and multiple usage
    of these boxes. It also means that we need to do additional packing and width calculations.

    When we were in transition local boxes were handled as special boxes (alongside leader and
    shipout boxes but they got their own cmd again when we were done).
*/

/*tex
    Here we set fields in a new par node. We could have an extra width |_par| hut it doesn't really
    pay off (now).
*/

/*tex 
    An experiment with |\localleftskip| and |\localrightskip| kind of worked but it was in the end
    not that useful. 
*/

static inline scaled tex_aux_local_boxes_width(halfword n)
{
    scaled width = 0;
    while (n) {
        if (node_type(n) == hlist_node) {
            width += box_width(n);
        } else {
            /*tex Actually this is an error. */
        }
        n = node_next(n);
    }
    return width;
}

void tex_add_local_boxes(halfword p)
{
    if (local_left_box_par) {
        halfword copy = tex_copy_node_list(local_left_box_par, null);
        tex_set_local_left_width(p, tex_aux_local_boxes_width(copy));
        par_box_left(p) = copy;
    }
    if (local_right_box_par) {
        halfword copy = tex_copy_node_list(local_right_box_par, null);
        tex_set_local_right_width(p, tex_aux_local_boxes_width(copy));
        par_box_right(p) = copy;
    }
    if (local_middle_box_par) {
        halfword copy = tex_copy_node_list(local_middle_box_par, null);
        par_box_middle(p) = copy;
    }
}

/*tex
    Pass on to Lua or inject in the current list. So, we still have a linked list here
    with only boxes.
*/

halfword tex_get_local_boxes(halfword location)
{
    switch (location) {
        case local_left_box_code  : return tex_use_local_boxes(local_left_box_par,   local_left_box_code);
        case local_right_box_code : return tex_use_local_boxes(local_right_box_par,  local_right_box_code);
        case local_middle_box_code: return tex_use_local_boxes(local_middle_box_par, local_middle_box_code);
    }
    return null;
}

/*tex Set them from Lua, watch out; not an eq update */

void tex_set_local_boxes(halfword b, halfword location)
{
    switch (location) {
        case local_left_box_code  : tex_flush_node_list(local_left_box_par  ); local_left_box_par   = b; break;
        case local_right_box_code : tex_flush_node_list(local_right_box_par ); local_right_box_par  = b; break;
        case local_middle_box_code: tex_flush_node_list(local_middle_box_par); local_middle_box_par = b; break;
    }
}

/*tex Set them from TeX, watch out; this is an eq update */

static halfword tex_aux_reset_boxes(halfword head, halfword index)
{
    if (head && index) {
        halfword current = head;
        while (current) {
            halfword next = node_next(current);
            if (node_type(current) == hlist_node && box_index(current) == index) {
                if (current == head) {
                    head = node_next(head);
                    node_prev(head) = null;
                    next = head;
                } else {
                    tex_try_couple_nodes(node_prev(current), next);
                }
                tex_flush_node(current);
                break;
            } else {
                current = next;
            }
        }
        return head;
    } else {
        tex_flush_node_list(head);
        return null;
    }
}

void tex_reset_local_boxes(halfword index, halfword location)
{
    switch (location) {
        case local_left_box_code  : local_left_box_par  = tex_aux_reset_boxes(local_left_box_par,   index); break;
        case local_right_box_code : local_right_box_par = tex_aux_reset_boxes(local_right_box_par,  index); break;
        case local_middle_box_code: local_right_box_par = tex_aux_reset_boxes(local_middle_box_par, index); break;
    }
} 

void tex_reset_local_box(halfword location)
{
    switch (location) {
        case local_left_box_code   : update_tex_local_left_box  (null); break;
        case local_right_box_code  : update_tex_local_right_box (null); break;
        case local_middle_box_code : update_tex_local_middle_box(null); break;
        case local_reset_boxes_code: update_tex_local_left_box  (null);  /* It could be a loop if we have  */
                                     update_tex_local_right_box (null);  /* more but this will do for now. */
                                     update_tex_local_middle_box(null); break;
    }
}

static halfword tex_aux_update_boxes(halfword head, halfword b, halfword index)
{
    if (head && index) {
        halfword current = head;
        while (current) {
            halfword next = node_next(current);
            if (node_type(current) == hlist_node && box_index(current) == index) {
                tex_try_couple_nodes(b, node_next(current));
                if (current == head) {
                    head = b;
                } else {
                    tex_couple_nodes(node_prev(current), b);
                }
                tex_flush_node(current);
                break;
            } else if (next) {
                current = next;
            } else {
                tex_couple_nodes(current, b);
                break;
            }
        }
        return head;
    }
    return b;
}

void tex_update_local_boxes(halfword b, halfword index, halfword location) /* todo: avoid copying */
{
    switch (location) {
        case local_left_box_code:
            if (b) {
                halfword c = local_left_box_par ? tex_copy_node_list(local_left_box_par, null) : null;
                b = tex_aux_update_boxes(c, b, index);
            } else if (index) {
                halfword c = local_left_box_par ? tex_copy_node_list(local_left_box_par, null) : null;
                b = tex_aux_reset_boxes(c, index);
            }
            update_tex_local_left_box(b);
            break;
        case local_right_box_code:
            if (b) {
                halfword c = local_right_box_par ? tex_copy_node_list(local_right_box_par, null) : null;
                b = tex_aux_update_boxes(c, b, index);
            } else if (index) {
                halfword c = local_right_box_par ? tex_copy_node_list(local_right_box_par, null) : null;
                b = tex_aux_reset_boxes(c, index);
            }
            update_tex_local_right_box(b);
            break;
        default:
            if (b) {
                halfword c = local_middle_box_par ? tex_copy_node_list(local_middle_box_par, null) : null;
                b = tex_aux_update_boxes(c, b, index);
            } else if (index) {
                halfword c = local_middle_box_par ? tex_copy_node_list(local_middle_box_par, null) : null;
                b = tex_aux_reset_boxes(c, index);
            }
            update_tex_local_middle_box(b);
            break;
    }
}

/*tex The |par| option: */

/* todo: use helper */

static halfword tex_aux_replace_local_box(halfword b, halfword index, halfword par_box)
{
    if (b) {
        halfword c = par_box ? tex_copy_node_list(par_box, null) : null;
        b = tex_aux_update_boxes(c, b, index);
    } else if (index) {
        halfword c = par_box ? tex_copy_node_list(par_box, null) : null;
        b = tex_aux_reset_boxes(c, index);
    }
    if (par_box) {
        tex_flush_node_list(par_box);
    }
    return b;
}

void tex_replace_local_boxes(halfword par, halfword b, halfword index, halfword location) /* todo: avoid copying */
{
    switch (location) {
        case local_left_box_code:
            par_box_left(par) = tex_aux_replace_local_box(b, index, par_box_left(par));
            par_box_left_width(par) = tex_aux_local_boxes_width(b);
            break;
        case local_right_box_code:
            par_box_right(par) = tex_aux_replace_local_box(b, index, par_box_right(par));
            par_box_right_width(par) = tex_aux_local_boxes_width(b);
            break;
        case local_middle_box_code:
            par_box_middle(par) = tex_aux_replace_local_box(b, index, par_box_middle(par));
            /*tex We keep the zero width! */
            break;
    }
}

/*tex Get them for line injection. */

halfword tex_use_local_boxes(halfword p, halfword location)
{
    if (p) {
        p = tex_hpack(tex_copy_node_list(p, null), 0, packing_additional, direction_unknown, holding_none_option, box_limit_none);
        switch (location) {
            case local_left_box_code  : node_subtype(p) = local_left_list  ; break;
            case local_right_box_code : node_subtype(p) = local_right_list ; break;
            case local_middle_box_code: node_subtype(p) = local_middle_list; break;
        }
    }
    return p;
}

/* */

void tex_scan_local_boxes_keys(quarterword *options, halfword *index)
{
    *options = 0;
    *index = 0;
    while (1) {
        switch (tex_scan_character("iklpIKLP", 0, 1, 0)) {
            case 'i': case 'I':
                if (tex_scan_mandate_keyword("index", 1)) {
                    *index = tex_scan_box_index();
                }
                break;
            case 'k': case 'K':
                if (tex_scan_mandate_keyword("keep", 1)) {
                    *options |= local_box_keep_option;
                }
                break;
            case 'l': case 'L':
                if (tex_scan_mandate_keyword("local", 1)) {
                    *options |= local_box_local_option;
                }
                break;
            case 'p': case 'P':
                if (tex_scan_mandate_keyword("par", 1)) {
                    *options |= local_box_par_option;
                }
                break;
            default:
                return;
        }
    }
}

halfword tex_valid_box_index(halfword n)
{
    return box_index_in_range(n);
}

scaled   tex_get_local_left_width        (halfword p) { return par_box_left_width(p); }
scaled   tex_get_local_right_width       (halfword p) { return par_box_right_width(p); }
halfword tex_get_local_interline_penalty (halfword p) { return par_inter_line_penalty(p); }
halfword tex_get_local_broken_penalty    (halfword p) { return par_broken_penalty(p); }
halfword tex_get_local_tolerance         (halfword p) { return par_tolerance(p); }
halfword tex_get_local_pre_tolerance     (halfword p) { return par_pre_tolerance(p); }

void     tex_set_local_left_width        (halfword p, scaled   width    ) { par_box_left_width(p) = width; }
void     tex_set_local_right_width       (halfword p, scaled   width    ) { par_box_right_width(p) = width; }
void     tex_set_local_interline_penalty (halfword p, halfword penalty  ) { par_inter_line_penalty(p) = penalty; }
void     tex_set_local_broken_penalty    (halfword p, halfword penalty  ) { par_broken_penalty(p) = penalty; }
void     tex_set_local_tolerance         (halfword p, halfword tolerance) { par_tolerance(p) = tolerance; }
void     tex_set_local_pre_tolerance     (halfword p, halfword tolerance) { par_pre_tolerance(p) = tolerance; }

typedef enum saved_localbox_entries {
    saved_localbox_location_entry = 0,
    saved_localbox_index_entry    = 0,
    saved_localbox_options_entry  = 0,
    saved_localbox_n_of_records   = 1,
} saved_localbox_entries;

static inline void saved_localbox_initialize(void)
{
    saved_type(0) = saved_record_0;
    saved_record(0) = local_box_save_type;
}

static inline int saved_localbox_okay(void)
{
    return saved_type(0) == saved_record_0 && saved_record(0) == local_box_save_type;
}

# define saved_localbox_location saved_value_1(saved_localbox_location_entry)
# define saved_localbox_index    saved_value_2(saved_localbox_index_entry)
# define saved_localbox_options  saved_value_3(saved_localbox_options_entry)

int tex_show_localbox_record(void)
{
    tex_print_str("localbox ");
    switch (saved_type(0)) { 
       case saved_record_0:
            tex_print_format("location %i, index %i, options %i", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        default: 
            return 0;
    }
    return 1;
}

void tex_aux_scan_local_box(int code) {
    quarterword options = 0;
    halfword index = 0;
    tex_scan_local_boxes_keys(&options, &index);
    saved_localbox_initialize();
    saved_localbox_location = code;
    saved_localbox_index = index;
    saved_localbox_options = options;
    lmt_save_state.save_stack_data.ptr += saved_localbox_n_of_records;
    tex_new_save_level(local_box_group);
    tex_scan_left_brace();
    tex_push_nest();
    cur_list.mode = restricted_hmode;
    cur_list.space_factor = default_space_factor;
}

void tex_aux_finish_local_box(void)
{
    tex_unsave();
    lmt_save_state.save_stack_data.ptr -= saved_localbox_n_of_records;
    if (saved_localbox_okay()) {
        /* here we could just decrement ptr and then access */
        halfword location = saved_localbox_location;
        quarterword options = (quarterword) saved_localbox_options;
        halfword index = saved_localbox_index;
        int islocal = (options & local_box_local_option) == local_box_local_option;
        int keep = (options & local_box_keep_option) == local_box_keep_option;
        int atpar = (options & local_box_par_option) == local_box_par_option;
        halfword p = node_next(cur_list.head);
        tex_pop_nest();
        if (p) {
            /*tex Somehow |filtered_hpack| goes beyond the first node so we loose it. */
            node_prev(p) = null;
            if (tex_list_has_glyph(p)) {
                tex_handle_hyphenation(p, null);
                p = tex_handle_glyphrun(p, local_box_group, text_direction_par);
            }
            if (p) {
                p = lmt_hpack_filter_callback(p, 0, packing_additional, local_box_group, direction_unknown, null);
            }
            /*tex
                We really need something packed so we play safe! This feature is inherited but could
                have been delegated to a callback anyway.
            */
            p = tex_hpack(p, 0, packing_additional, direction_unknown, holding_none_option, box_limit_none);
            node_subtype(p) = local_list;
            box_index(p) = index;
         // attach_current_attribute_list(p); // leaks
        } else { 
            /* well */
        }
        // what to do with reset
        if (islocal) {
            /*tex There no copy needed either! */
        } else {
            tex_update_local_boxes(p, index, location);
        }
        if (cur_mode == hmode || cur_mode == mmode) {
            if (atpar) {
                halfword par = tex_find_par_par(cur_list.head);
                if (par) {
                    if (p && ! islocal) {
                        p = tex_copy_node(p);
                    }
                    tex_replace_local_boxes(par, p, index, location);
                }
            } else {
                /*tex
                    We had a null check here but we also want to be able to reset these boxes so we
                    no longer check.
                */
                tex_tail_append(tex_new_par_node(local_box_par_subtype));
                if (! keep) {
                    /*tex So we can group and keep it. */
                    update_tex_internal_par_state(internal_par_state_par + 1);
                }
            }
        }
    } else {
        tex_confusion("build local box");
    }
}
