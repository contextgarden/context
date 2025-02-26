/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    A |disc_node|, which occurs only in horizontal lists, specifies a \quote {discretionary}
    line break. If such a break occurs at node |p|, the text that starts at |pre_break(p)| will
    precede the break, the text that starts at |post_break(p)| will follow the break, and text
    that appears in |no_break(p)| nodes will be ignored. For example, an ordinary discretionary
    hyphen, indicated by |\-|, yields a |disc_node| with |pre_break| pointing to a |char_node|
    containing a hyphen, |post_break = null|, and |no_break=null|.

    If |subtype(p) = automatic_disc|, the |ex_hyphen_penalty| will be charged for this break.
    Otherwise the |hyphen_penalty| will be charged. The texts will actually be substituted into
    the list by the line-breaking algorithm if it decides to make the break, and the discretionary
    node will disappear at that time; thus, the output routine sees only discretionaries that were
    not chosen.

*/

halfword tex_new_disc_node(quarterword s)
{
    halfword p = tex_new_node(disc_node, s);
    disc_penalty(p) = hyphen_penalty_par;
    disc_class(p) = unset_disc_class;
    set_disc_options(p, discretionary_options_par);
    return p;
}
void tex_set_disc_field(halfword target, halfword location, halfword source)
{
    switch (location) {
        case pre_break_code:  target = disc_pre_break(target);  break;
        case post_break_code: target = disc_post_break(target); break;
        case no_break_code:   target = disc_no_break(target);   break;
    }
    if (source) {
        node_prev(source) = null; /* don't expose this one! */
        node_head(target) = source;
        node_tail(target) = tex_tail_of_node_list(source);
    } else {
        node_head(target) = null;
        node_tail(target) = null;
    }
}

void tex_check_disc_field(halfword n)
{
    halfword p = disc_pre_break_head(n);
    disc_pre_break_tail(n) = p ? tex_tail_of_node_list(p) : null;
    p = disc_post_break_head(n);
    disc_post_break_tail(n) = p ? tex_tail_of_node_list(p) : null;
    p = disc_no_break_head(n);
    disc_no_break_tail(n) = p ? tex_tail_of_node_list(p) : null;
}

void tex_set_discpart(halfword d, halfword h, halfword t, halfword code)
{
    halfword c = h;
    switch (node_subtype(d)) {
        case automatic_discretionary_code:
        case mathematics_discretionary_code:
            code = glyph_discpart_always;
            break;
    }
    while (c) {
        if (node_type(c) == glyph_node) {
            set_glyph_discpart(c, code);
        }
        if (c == t) {
            break;
        } else {
            c = node_next(c);
        }
    }
}

static int tex_set_discafter(halfword h, halfword t, halfword after)
{
    halfword c = h;
    while (c) {
        if (node_type(c) == glyph_node) {
            set_glyph_discafter(c, after);
            return 1;
        }
        if (c == t) {
            break;
        } else {
            c = node_next(c);
        }
    }
    return 0;
}

/*

glyph disc (pre post replace) glyph
disc (pre post replace) glyph
disc (pre post replace) disc

*/

halfword tex_flatten_discretionaries(halfword head, int *count, int nest)
{
    halfword current = head;
    halfword after = 0;
    while (current) {
        halfword next = node_next(current);
        switch (node_type(current)) {
            case disc_node:
                {
                    halfword d = current;
                    halfword h = disc_no_break_head(d);
                    halfword t = disc_no_break_tail(d);
                    after = node_subtype(current) + 1;
                    if (h) {
                        tex_set_discpart(current, h, t, glyph_discpart_replace);
                        tex_try_couple_nodes(t, next);
                        if (current == head) {
                            head = h;
                        } else {
                            tex_try_couple_nodes(node_prev(current), h);
                        }
                        disc_no_break_head(d) = null;
                        if (tex_set_discafter(h, t, after)) {
                            after = 0;
                        }
                    } else if (current == head) {
                        head = next;
                    } else {
                        tex_try_couple_nodes(node_prev(current), next);
                    }
                    tex_flush_node(d);
                    if (count) {
                        *count += 1;
                    }
                    break;
                }
            case glyph_node:
                if (after) {
                    set_glyph_discafter(current, after);
                    after = 0;
                }
                break;
            case hlist_node:
            case vlist_node:
                if (nest) {
                    halfword list = box_list(current);
                    if (list) {
                        box_list(current) = tex_flatten_discretionaries(list, count, nest);
                    }
                }
                break;
            case kern_node:
                switch (node_subtype(current)) {
                    case font_kern_subtype:
                        break;
                    default:
                        after = 0;
                        break;
                }
                break;
            case penalty_node:
            case boundary_node:
                /* maybe some more */
                break;
            default:
                after = 0;
                break;

        }
        current = next;
    }
    return head;
}

/*tex

    Discretionary nodes are easy in the common case |\-|, but in the general case we must process
    three braces full of items.

    The space factor does not change when we append a discretionary node, but it starts out as 1000
    in the subsidiary lists.

*/

typedef enum saved_discretionary_entries {
    saved_discretionary_component_entry = 0, /* value_1 */
    saved_discretionary_n_of_records    = 1,
} saved_discretionary_entries;

# define saved_discretionary_component saved_value_1(saved_discretionary_component_entry)

static inline void saved_discretionary_initialize(void)
{
    saved_type(0) = saved_record_0;
    saved_record(0) = discretionary_save_type;
}

static inline int saved_discretionary_current_component(void)
{
    return saved_type(saved_discretionary_component_entry - saved_discretionary_n_of_records) == saved_record_0 
        ? saved_value_1(saved_discretionary_component_entry - saved_discretionary_n_of_records) : -1 ;
}

static inline void saved_discretionary_update_component(void)
{
    saved_value_1(saved_discretionary_component_entry - saved_discretionary_n_of_records) += 1;
}

void tex_show_discretionary_group(void)
{
    tex_print_str_esc("discretionary");
    tex_aux_show_group_count(saved_discretionary_component);
}

int tex_show_discretionary_record(void)
{
    tex_print_str("discretionary ");
    switch (save_type(lmt_save_state.save_stack_data.ptr)) { 
       case saved_record_0:
            tex_print_format("component %i", saved_discretionary_component);
            break;
        default: 
            return 0;
    }
    return 1;
}

void tex_run_discretionary(void)
{
    switch (cur_chr) {
        case normal_discretionary_code:
            /*tex |\discretionary| */
            {
                halfword d = tex_new_disc_node(normal_discretionary_code);
                tex_tail_append(d);
                while (1) {
                    switch (tex_scan_character("pocbnsPOCBNS", 0, 1, 0)) {
                        case 0:
                            goto DONE;
                        case 'p': case 'P':
                            switch (tex_scan_character("eorEOR", 0, 0, 0)) {
                                case 'e': case 'E':
                                    if (tex_scan_mandate_keyword("penalty", 2)) {
                                        set_disc_penalty(d, tex_scan_integer(0, NULL, NULL));
                                    }
                                    break;
                                case 'o': case 'O':
                                    if (tex_scan_mandate_keyword("postword", 2)) {
                                        set_disc_option(d, disc_option_post_word);
                                    }
                                    break;
                                case 'r': case 'R':
                                    if (tex_scan_mandate_keyword("preword", 2)) {
                                        set_disc_option(d, disc_option_pre_word);
                                    }
                                    break;
                                default:
                                    tex_aux_show_keyword_error("penalty|postword|preword");
                                    goto DONE;
                            }
                            break;
                        case 'b': case 'B':
                            if (tex_scan_mandate_keyword("break", 1)) {
                                set_disc_option(d, disc_option_prefer_break);
                            }
                            break;
                        case 'n': case 'N':
                            if (tex_scan_mandate_keyword("nobreak", 1)) {
                                set_disc_option(d, disc_option_prefer_nobreak);
                            }
                            break;
                        case 'o': case 'O':
                            if (tex_scan_mandate_keyword("options", 1)) {
                                set_disc_options(d, tex_scan_integer(0, NULL, NULL));
                            }
                            break;
                        case 'c': case 'C':
                            if (tex_scan_mandate_keyword("class", 1)) {
                                set_disc_class(d, tex_scan_math_class_number(0));
                            }
                            break;
                        case 's': case 'S':
                            if (tex_scan_mandate_keyword("standalone", 1)) {
                                set_disc_option(d, disc_option_stand_alone);
                            }
                            break;
                        default:
                            goto DONE;
                    }
                }
            DONE:
                saved_discretionary_initialize();
                saved_discretionary_component = 0;
                lmt_save_state.save_stack_data.ptr += saved_discretionary_n_of_records;
                tex_new_save_level(discretionary_group);
                tex_scan_left_brace();
                tex_push_nest();
                cur_list.mode = restricted_hmode;
                cur_list.space_factor = default_space_factor; /* hm, quite hard coded */
            }
            break;
        case explicit_discretionary_code:
            /*tex |\-| */
            if (hyphenation_permitted(hyphenation_mode_par, explicit_hyphenation_mode)) {
                int c = tex_get_pre_hyphen_char(cur_lang_par);
                halfword d = tex_new_disc_node(explicit_discretionary_code);
                tex_tail_append(d);
                if (c > 0) {
                    halfword g = tex_new_char_node(glyph_unset_subtype, cur_font_par, c, 1);
                    set_glyph_disccode(g, glyph_disc_explicit);
                    tex_set_disc_field(d, pre_break_code, g);
                }
                c = tex_get_post_hyphen_char(cur_lang_par);
                if (c > 0) {
                    halfword g = tex_new_char_node(glyph_unset_subtype, cur_font_par, c, 1);
                    set_glyph_disccode(g, glyph_disc_explicit);
                    tex_set_disc_field(d, post_break_code, g);
                }
                disc_penalty(d) = tex_explicit_disc_penalty(hyphenation_mode_par);
            }
            break;
        case automatic_discretionary_code:
        case mathematics_discretionary_code:
            /*tex |-| */
            if (hyphenation_permitted(hyphenation_mode_par, automatic_hyphenation_mode)) {
                halfword c = tex_get_pre_exhyphen_char(cur_lang_par);
                halfword d = tex_new_disc_node(automatic_discretionary_code);
                halfword f = cur_chr == mathematics_discretionary_code ? glyph_disc_mathematics : glyph_disc_automatic;
                tex_tail_append(d);
                /*tex As done in hyphenator: */
                if (c <= 0) {
                    c = ex_hyphen_char_par;
                }
                if (c > 0) {
                    halfword g = tex_new_char_node(glyph_unset_subtype, cur_font_par, c, 1);
                    set_glyph_disccode(g, f);
                    tex_set_disc_field(d, pre_break_code, g);
                }
                c = tex_get_post_exhyphen_char(cur_lang_par);
                if (c > 0) {
                    halfword g = tex_new_char_node(glyph_unset_subtype, cur_font_par, c, 1);
                    set_glyph_disccode(g, f);
                    tex_set_disc_field(d, post_break_code, g);
                }
                c = ex_hyphen_char_par;
                if (c > 0) {
                    halfword g = tex_new_char_node(glyph_unset_subtype, cur_font_par, c, 1);
                    set_glyph_disccode(g, f);
                    tex_set_disc_field(d, no_break_code, g);
                }
                disc_penalty(d) = tex_automatic_disc_penalty(hyphenation_mode_par);
            } else {
                halfword c = ex_hyphen_char_par;
                if (c > 0) {
                    halfword g = tex_new_char_node(glyph_unset_subtype, cur_font_par, c, 1);
                    set_glyph_discpart(g, glyph_discpart_always);
                    set_glyph_disccode(g, glyph_disc_normal);
                    tex_tail_append(g);
                }
            }
            break;
    }
}

/*tex

    The three discretionary lists are constructed somewhat as if they were hboxes. A subroutine
    called |finish_discretionary| handles the transitions. (This is sort of fun.)

*/

void tex_finish_discretionary(void)
{
    halfword current, next;
    int length = 0;
    tex_unsave();
    /*tex
        Prune the current list, if necessary, until it contains only |char_node|, |kern_node|,
        |hlist_node|, |vlist_node| and |rule_node| items; set |n| to the length of the list, and
        set |q| to the lists tail. During this loop, |p = node_next(q)| and there are |n| items
        preceding |p|.
    */
    current = cur_list.head;
    next = node_next(current);
    while (next) {
        switch (node_type(next)) {
            case glyph_node:
            case hlist_node:
            case vlist_node:
            case rule_node:
            case kern_node:
                break;
            case glue_node:
                if (hyphenation_permitted(hyphenation_mode_par, permit_glue_hyphenation_mode)) {
                    if (glue_stretch_order(next)) {
                        glue_stretch(next) = 0;
                        glue_stretch_order(next) = 0;
                    }
                    if (glue_shrink_order(next)) {
                        glue_shrink(next) = 0;
                        glue_shrink_order(next) = 0;
                    }
                    break;
                } else {
                    // fall through
                }
            default:
                if (hyphenation_permitted(hyphenation_mode_par, permit_all_hyphenation_mode)) {
                    break;
                } else {
                    tex_handle_error(
                        normal_error_type,
                        "Improper discretionary list",
                        "Discretionary lists must contain only glyphs, boxes, rules and kerns."
                    );
                    tex_begin_diagnostic();
                    tex_print_str("The following discretionary sublist has been deleted:");
                    tex_print_levels();
                    tex_show_box(next);
                    tex_end_diagnostic();
                    tex_flush_node_list(next);
                    node_next(current) = null;
                    goto DONE;
                }
        }
        node_prev(next) = current;
        current = next;
        next = node_next(current);
        ++length;
    }
  DONE:
    next = node_next(cur_list.head);
    tex_pop_nest();
    {
        halfword discnode = cur_list.tail;

        if (next) {
            node_prev(next) = null;
            if (node_subtype(disc_node) == normal_discretionary_code && has_disc_option(discnode, disc_option_stand_alone)) {
                if (tex_list_has_glyph(next)) {
                    /* maybe test direction, maybe also pass pre/post/replace as 4th argument*/
                    next = tex_handle_glyphrun(next, discretionary_group, text_direction_par);
                    next = tex_flatten_discretionaries(next, NULL, 1);
                }
            }
        }

        switch (saved_discretionary_current_component()) {
            case 0:
                if (next && length > 0) {
                    tex_set_disc_field(discnode, pre_break_code, next);
                }
                break;
            case 1:
                if (next && length > 0) {
                    tex_set_disc_field(discnode, post_break_code, next);
                }
                break;
            case 2:
                /*tex
                    Attach list |p| to the current list, and record its length; then finish up and
                    |return|.
                */
                if (next && length > 0) {
                    if (cur_mode == mmode && ! hyphenation_permitted(hyphenation_mode_par, permit_math_replace_hyphenation_mode)) {
                        tex_handle_error(
                            normal_error_type,
                            "Illegal math \\discretionary",
                            "Sorry: The third part of a discretionary break must be empty, in math formulas. I\n"
                            "had to delete your third part."
                        );
                        tex_flush_node_list(next);
                    } else {
                        tex_set_disc_field(discnode, no_break_code, next);
                    }
                }
                if (! hyphenation_permitted(hyphenation_mode_par, normal_hyphenation_mode)) {
                    halfword replace = disc_no_break_head(discnode);
                    cur_list.tail = node_prev(cur_list.tail);
                    node_next(cur_list.tail) = null;
                    if (replace) {
                        tex_tail_append(replace);
                        cur_list.tail = disc_no_break_tail(discnode);
                        tex_set_disc_field(discnode, no_break_code, null);
                        tex_set_discpart(discnode, replace, disc_no_break_tail(discnode), glyph_discpart_replace);
                    }
                    tex_flush_node(discnode);
                } else if (cur_mode == mmode && disc_class(discnode) != unset_disc_class) {
                    halfword noad = null;
                    cur_list.tail = node_prev(discnode);
                    node_prev(discnode ) = null;
                    node_next(discnode ) = null;
                    noad = tex_math_make_disc(discnode);
                    tex_tail_append(noad);
                }
                /*tex There are no other cases. */
                lmt_save_state.save_stack_data.ptr -= saved_discretionary_n_of_records;
                return;
            default:
                tex_confusion("finish discretionary");
                return;
        }
        saved_discretionary_update_component();
        tex_new_save_level(discretionary_group);
        tex_scan_left_brace();
        tex_push_nest();
        cur_list.mode = restricted_hmode;
        cur_list.space_factor = default_space_factor;
    }
}
