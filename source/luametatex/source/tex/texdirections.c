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

halfword tex_complement_dir_state(halfword tail)
{
    halfword e = node_next(tail);
    for (halfword p = lmt_linebreak_state.dir_ptr; p ; p = node_next(p)) {
        halfword s = tex_new_dir(cancel_dir_subtype, dir_direction(p));
        tex_attach_attribute_list_copy(s, tail);
        tex_couple_nodes(tail, s);
        tex_try_couple_nodes(s, e);
        tail = s;
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

/* todo: |\tracingdirections| */

void tex_push_text_dir_ptr(halfword val)
{
    if (dir_level(lmt_dir_state.text_dir_ptr) == cur_level) {
        /*tex update */
        dir_direction(lmt_dir_state.text_dir_ptr) = val;
    } else {
        /*tex add */
        halfword text_dir_tmp = tex_new_dir(normal_dir_subtype, val);
        node_next(text_dir_tmp) = lmt_dir_state.text_dir_ptr;
        lmt_dir_state.text_dir_ptr = text_dir_tmp;
    }
}

void tex_pop_text_dir_ptr(void)
{
    halfword text_dir_ptr = lmt_dir_state.text_dir_ptr;
    if (dir_level(text_dir_ptr) == cur_level) {
        /*tex remove */
        halfword text_dir_tmp = node_next(text_dir_ptr);
        tex_flush_node(text_dir_ptr);
        lmt_dir_state.text_dir_ptr = text_dir_tmp;
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
