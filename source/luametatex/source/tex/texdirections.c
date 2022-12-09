/*
    See license.txt in the root of this project.
*/

/*tex

    In \LUATEX\ we started with the \OMEGA\ direction model, although only a handful of directions
    is supported there (four to be precise). For l2r and r2l typesetting the frontend can basically
    ignore directions. Only the font handler needs to be direction aware. The vertical directions in
    \LUATEX\ demand swapping height and width occasionally when doing calculations. In the end it is
    the backend code that does the hard work.

    In the end, in \LUAMETATEX\ we only kept the horizontal directions. The vertical ones were not
    really useful and didn't even work well. It's up to the macro package to cook up proper
    solutions. The simplification (and rewrite) of the code also resulted in a more advanced box
    model (with rotation and offsets) that can help implementing vertical rendering, but that code
    is not here.

    Todo: |\tracingdirections| but costly so not really. The tracinglist is a middleground but I 
    might comment it at some point. 

*/

# include "luametatex.h"

dir_state_info lmt_dir_state = {
    .text_dir_ptr = null,
    .padding      = 0,
};

/*tex The next two are used by the linebreak routine; they could be macros. */

inline static halfword tex_aux_push_dir_node(halfword p, halfword d)
{
    halfword n = tex_copy_node(d);
    node_next(n) = p;
    return n;
}

inline static halfword tex_aux_pop_dir_node(halfword p)
{
    halfword n = node_next(p);
    tex_flush_node(p);
    return n;
}

halfword tex_update_dir_state(halfword p, halfword initial)
{
    if (node_subtype(p) == normal_dir_subtype) {
        lmt_linebreak_state.dir_ptr = tex_aux_push_dir_node(lmt_linebreak_state.dir_ptr, p);
        return dir_direction(p);
    } else {
        lmt_linebreak_state.dir_ptr = tex_aux_pop_dir_node(lmt_linebreak_state.dir_ptr);
        if (lmt_linebreak_state.dir_ptr) {
            return dir_direction(lmt_linebreak_state.dir_ptr);
        } else {
            return initial;
        }
    }
}

/*tex 
    The next function runs over the whole list (|first|, |last|) and initial is normally the 
    direction of the paragraph.  
*/

halfword tex_sanitize_dir_state(halfword first, halfword last, halfword initial)
{
    for (halfword e = first; e && e != last; e = node_next(e)) {
        if (node_type(e) == dir_node) {
            if (node_subtype(e) == normal_dir_subtype) {
                lmt_linebreak_state.dir_ptr = tex_aux_push_dir_node(lmt_linebreak_state.dir_ptr, e);
            } else if (lmt_linebreak_state.dir_ptr && dir_direction(lmt_linebreak_state.dir_ptr) == dir_direction(e)) {
                /*tex A bit strange test. */
                lmt_linebreak_state.dir_ptr = tex_aux_pop_dir_node(lmt_linebreak_state.dir_ptr);
            }
        }
    }
    if (lmt_linebreak_state.dir_ptr) {
        return dir_direction(lmt_linebreak_state.dir_ptr);
    } else {
        return initial;
    }
}

/*tex
    Here we inject the nodes that inititialize and cancel the direction states as stored in the 
    (reverse) stack into the list, after |tail|. 
*/

void tex_append_dir_state(void)
{
    halfword dir = lmt_dir_state.text_dir_ptr;
    halfword tail = cur_list.tail;    
    halfword first = null;
    halfword last = null;
    if (tracing_paragraph_lists) {
        tex_begin_diagnostic();
        tex_print_format("[paragraph: dirstate]");
        tex_show_box(dir);
        tex_end_diagnostic();
    }
    while (dir) {
        if ((node_next(dir)) || (dir_direction(dir) != par_direction_par)) {
            halfword tmp = tex_new_dir(normal_dir_subtype, dir_direction(dir));
            tex_attach_attribute_list_copy(tmp, tail);
            tex_try_couple_nodes(tmp, first);
            first = tmp; 
            if (! last) {
                last = tmp; 
            } 
        }
        dir = node_next(dir);
    }
    if (first) { 
        if (tracing_paragraph_lists) {
            tex_begin_diagnostic();
            tex_print_format("[paragraph: injected dirs]");
            tex_show_box(first);
            tex_end_diagnostic();
        }
        tex_couple_nodes(cur_list.tail, first);
        cur_list.tail = last; 
    }
}

halfword tex_complement_dir_state(halfword tail)
{
    halfword aftertail = node_next(tail);
    for (halfword topdir = lmt_linebreak_state.dir_ptr; topdir ; topdir = node_next(topdir)) {
        halfword dir = tex_new_dir(cancel_dir_subtype, dir_direction(topdir));
        tex_attach_attribute_list_copy(dir, tail);
        tex_couple_nodes(tail, dir);
        tex_try_couple_nodes(dir, aftertail);
        tail = dir;
    }
    return tail;
}

void tex_initialize_directions(void)
{
    lmt_dir_state.text_dir_ptr = tex_new_dir(normal_dir_subtype, direction_def_value);
}

void tex_cleanup_directions(void)
{
    tex_flush_node(lmt_dir_state.text_dir_ptr); /* tex_free_node(lmt_dir_state.text_dir_ptr, dir_node_size) */
}

halfword tex_new_dir(quarterword subtype, halfword direction)
{
    halfword p = tex_new_node(dir_node, subtype);
    dir_direction(p) = direction;
    dir_level(p) = cur_level;
    return p;
}

void tex_push_text_dir_ptr(halfword val)
{
    if (tracing_direction_lists) {
        tex_begin_diagnostic();
        tex_print_format("[direction: push text, level %i, before]", cur_level);
        tex_show_box(lmt_dir_state.text_dir_ptr);
        tex_end_diagnostic();
    }
    if (dir_level(lmt_dir_state.text_dir_ptr) == cur_level) {
        /*tex update */
        dir_direction(lmt_dir_state.text_dir_ptr) = val;
    } else {
        /*tex we push in front of head */
        halfword text_dir_tmp = tex_new_dir(normal_dir_subtype, val);
        node_next(text_dir_tmp) = lmt_dir_state.text_dir_ptr;
        lmt_dir_state.text_dir_ptr = text_dir_tmp;
    }
    if (tracing_direction_lists) {
        tex_begin_diagnostic();
        tex_print_format("[direction: push text, level %i, after]", cur_level);
        tex_show_box(lmt_dir_state.text_dir_ptr);
        tex_end_diagnostic();
    }
}

void tex_pop_text_dir_ptr(void)
{
    halfword text_dir_ptr = lmt_dir_state.text_dir_ptr;
    if (tracing_direction_lists) {
        tex_begin_diagnostic();
        tex_print_format("[direction: pop text, level %i, before]", cur_level);
        tex_show_box(lmt_dir_state.text_dir_ptr);
        tex_end_diagnostic();
    }
    if (dir_level(text_dir_ptr) == cur_level) { // maybe > and whole chain 
        /*tex we remove from the head */
        halfword text_dir_tmp = node_next(text_dir_ptr);
        tex_flush_node(text_dir_ptr);
        lmt_dir_state.text_dir_ptr = text_dir_tmp;
    }
    if (tracing_direction_lists) {
        tex_begin_diagnostic();
        tex_print_format("[direction: pop text, level %i, after]", cur_level);
        tex_show_box(lmt_dir_state.text_dir_ptr);
        tex_end_diagnostic();
    }
}

void tex_set_math_dir(halfword d)
{
    if (valid_direction(d)) {
        update_tex_math_direction(d);
    }
}

void tex_set_par_dir(halfword d)
{
    if (valid_direction(d)) {
        update_tex_par_direction(d);
    }
}

void tex_set_text_dir(halfword d)
{
    if (valid_direction(d)) {
        tex_inject_text_or_line_dir(d, 0);
        update_tex_text_direction(d);
        update_tex_internal_dir_state(internal_dir_state_par + 1);
    }
}

void tex_set_line_dir(halfword d)
{
    if (valid_direction(d)) {
        tex_inject_text_or_line_dir(d, 1);
        update_tex_text_direction(d);
        update_tex_internal_dir_state(internal_dir_state_par + 1);
    }
}

void tex_set_box_dir(halfword b, singleword d)
{
    if (valid_direction(d)) {
        box_dir(box_register(b)) = (singleword) d;
    }
}
