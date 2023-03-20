/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex 

    The code can be simplified a lot when we decide that traditional 8 bit fonts are virtualized in
    a way that avoids the split delimiter definitions (small and large) and that the traditional 
    way to define characters is dropped in favor of the unicode variants. So, this might happen at
    some point. After all it makes no sense to use this engine with traditional fonts because there
    \PDFTEX\ is a better choice. 

    We might also benefit more from the fact that we have prev pointers. Occasionally I visit this 
    file and make some variables more verbose. I'm in no hurry with that. 

*/

/*tex

    When \TEX\ reads a formula that is enclosed between |$|'s, it constructs an \quote {mlist},
    which is essentially a tree structure representing that formula. An mlist is a linear sequence
    of items, but we can regard it as a tree structure because mlists can appear within mlists. For
    example, many of the entries can be subscripted or superscripted, and such \quote {scripts} are
    mlists in their own right.

    An entire formula is parsed into such a tree before any of the actual typesetting is done,
    because the current style of type is usually not known until the formula has been fully scanned.
    For example, when the formula |$a+b \over c+d$| is being read, there is no way to tell that |a+b|
    will be in script size until |\over| has appeared.

    During the scanning process, each element of the mlist being built is classified as a relation,
    a binary operator, an open parenthesis, etc., or as a construct like |\sqrt| that must be built
    up. This classification appears in the mlist data structure.

    After a formula has been fully scanned, the mlist is converted to an hlist so that it can be
    incorporated into the surrounding text. This conversion is controlled by a recursive procedure
    that decides all of the appropriate styles by a \quote {top-down} process starting at the
    outermost level and working in towards the subformulas. The formula is ultimately pasted together
    using combinations of horizontal and vertical boxes, with glue and penalty nodes inserted as
    necessary.

    An mlist is represented internally as a linked list consisting chiefly of \quote {noads}
    (pronounced \quotation {no-adds}), to distinguish them from the somewhat similar \quote {nodes}
    in hlists and vlists. Certain kinds of ordinary nodes are allowed to appear in mlists together
    with the noads; \TEX\ tells the difference by means of the |type| field, since a noad's |type|
    is always greater than that of a node. An mlist does not contain character nodes, hlist nodes,
    vlist nodes, math nodes or unset nodes; in particular, each mlist item appears in the
    variable-size part of |mem|, so the |type| field is always present.

    Each noad is five or more words long. The first word contains the |type| and |subtype| and |link|
    fields that are already so familiar to us; the second contains the attribute list pointer, and
    the third, fourth an fifth words are called the noad's |nucleus|, |subscr|, and |supscr| fields.
    (This use of a combined attribute list is temporary. Eventually, each of fields need their own
    list)

    Consider, for example, the simple formula |$x^2$|, which would be parsed into an mlist containing
    a single element called an |ord_noad|. The |nucleus| of this noad is a representation of |x|, the
    |subscr| is empty, and the |supscr| is a representation of |2|.

    The |nucleus|, |subscr|, and |supscr| fields are further broken into subfields. If |p| points to
    a noad, and if |q| is one of its principal fields (e.g., |q=subscr(p)|), |q=null| indicates a
    field with no value (the corresponding attribute of noad |p| is not present). Otherwise, there are
    several possibilities for the subfields, depending on the |type| of |q|.

    \startitemize

        \startitem
            |type(q)=math_char_node| means that |math_fam(q)| refers to one of the sixteen font
            families, and |character(q)| is the number of a character within a font of that family, as
            in a character node.
        \stopitem

        \startitem
            |type(q) = math_text_char_node| is similar, but the character is unsubscripted and
            unsuperscripted and it is followed immediately by another character from the same font.
            (This |type| setting appears only briefly during the processing; it is used to suppress
            unwanted italic corrections.)
        \stopitem

        \startitem
            |type(q) = sub_box_node| means that |math_list(q)| points to a box node (either an
            |hlist_node| or a |vlist_node|) that should be used as the value of the field. The
            |shift_amount| in the subsidiary box node is the amount by which that box will be 
            shifted downward.
        \stopitem

        \startitem
            |type(q) = sub_mlist_node| means that |math_list(q)| points to an mlist; the mlist must
            be converted to an hlist in order to obtain the value of this field.
        \stopitem

        \startitem
            In the latter case, we might have |math_list(q) = null|. This is not the same as |q =
            null|; for example, |$P_{\}$| and |$P$| produce different results (the former will not
            have the \quote {italic correction} added to the width of |P|, but the \quote {script
            skip} will be added).
        \stopitem

    \startitemize

    Concerning display skips, \TEX\ normally always inserts before and only after when larger than
    zero. This can now be controlled with |\mathdisplayskipmode|:

    \starttabulate
    \NC 0 \NC normal \TEX \NC \NR
    \NC 1 \NC always      \NC \NR
    \NC 2 \NC non-zero    \NC \NR
    \NC 3 \NC ignore      \NC \NR
    \stoptabulate

*/

math_state_info lmt_math_state = {
    .size       = 0,
    .level      = 0,
    .par_head   = NULL,
    .fam_head   = NULL,
    .last_left  = 0,
    .last_right = 0,
    .last_atom  = 0,
    .scale      = 1000,
};

static int      tex_aux_scan_math           (halfword p, halfword style, int usetextfont, halfword toks, halfword toks_text, int nocomponent, halfword cls, halfword all);
static halfword tex_aux_finish_math_list    (halfword p);
static void     tex_aux_math_math_component (halfword n, int append);

# define cramped 1

# define cramped_style(A) (2 * ((A) / 2) + cramped)                     /*tex cramp the style */
# define sub_style(A)     (2 * ((A) / 4) + script_style + cramped)      /*tex smaller and cramped */
# define sup_style(A)     (2 * ((A) / 4) + script_style + ((A) % 2))    /*tex smaller */
# define num_style(A)     ((A) + 2 - 2 * ((A) / 6))                     /*tex smaller unless already scriptscript */
# define denom_style(A)   (2 * ((A) / 2) + cramped + 2 - 2 * ((A) / 6)) /*tex smaller, cramped */
# define sup_sup_style(A) sup_style(sup_style((A)))                     /*tex smaller */

inline static mathdictval tex_fake_math_dict(halfword chr) 
{
    mathdictval d = tex_no_dict_code();
    if (math_dict_properties_par || math_dict_group_par) {
        d.properties = (unsigned short) math_dict_properties_par;
        d.group = (unsigned short) math_dict_group_par;
        d.index = (unsigned int) chr;
    }
    return d;
}

void tex_math_copy_char_data(halfword target, halfword source, int wipelist)
{
    if (node_type(source) == math_char_node) {
        kernel_math_family(target) = kernel_math_family(source);
        kernel_math_character(target) = kernel_math_character(source);
        kernel_math_options(target) = kernel_math_options(source);
        kernel_math_properties(target) = kernel_math_properties(source);
        kernel_math_group(target) = kernel_math_group(source);
        kernel_math_index(target) = kernel_math_index(source);
    } else {
        kernel_math_list(target) = kernel_math_list(source);
        if (wipelist) { 
           kernel_math_list(source) = null;
        }
    }
}

static inline void tex_math_set_scripts_options(halfword n)
{
    switch (math_scripts_mode_par) { 
        case 1: noad_options(n) |= noad_option_fixed_super_or_sub_script; break;
        case 2: noad_options(n) |= noad_option_fixed_super_and_sub_script; break;
    }
}

// static const math_styles map_cramped_style[] = { /*tex cramp the style */
//     cramped_display_style,
//     cramped_display_style,
//     cramped_text_style,
//     cramped_text_style,
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
// };
//
// static const math_styles map_subscript_style[] = { /*tex smaller and cramped */
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
// };
//
// static const math_styles map_superscript_style[] = { /*tex smaller */
//     script_style,
//     script_style,
//     script_style,
//     script_style,
//     script_script_style,
//     script_script_style,
//     script_script_style,
//     script_script_style,
// };
//
// static const math_styles map_numerator_style[] = {/*tex smaller unless already scriptscript */
//     script_style,
//     cramped_script_style,
//     script_style,
//     cramped_script_style,
//     script_script_style,
//     cramped_script_script_style,
//     script_script_style,
//     cramped_script_script_style,
// };
//
// static const math_styles map_denominator_style[] = { /*tex smaller, all cramped */
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
//     cramped_script_script_style,
// };
//
// static const math_styles map_double_superscript_style[] = { /*tex smaller, keep cramped */
//     script_style,
//     cramped_script_style,
//     script_style,
//     cramped_script_style,
//     script_script_style,
//     cramped_script_script_style,
//     script_script_style,
//     cramped_script_script_style,
// };

/*tex
    This is very \TEX: a variable class influences the family being used.
*/

halfword tex_size_of_style(halfword style)
{
    switch (style) {
        case script_style:
        case cramped_script_style:
            return script_size;
        case script_script_style:
        case cramped_script_script_style:
            return script_script_size;
        default:
            return text_size;
    }
}

halfword tex_math_style_variant(halfword style, halfword param)
{
    switch (tex_get_math_parameter(style, param, NULL)) {
        case math_normal_style_variant:
            return style;
        case math_cramped_style_variant:
         // return map_cramped_style[s];
            return cramped_style(style);
        case math_subscript_style_variant:
         // return map_subscript_style[s];
            return sub_style(style);
        case math_superscript_style_variant:
        case math_small_style_variant:
         // return map_superscript_style[s];
            return sup_style(style);
        case math_smaller_style_variant:
        case math_numerator_style_variant:
         // return map_numerator_style[s];
            return num_style(style);
        case math_denominator_style_variant:
         // return map_denominator_style[s];
            return denom_style(style);
        case math_double_superscript_variant:
         // return map_double_superscript_style[s];
            return sup_sup_style(style);
        default:
            return style;
    }
}

int tex_math_has_class_option(halfword cls, int option)
{
    halfword value = count_parameter(first_math_options_code + cls);
    if (value == no_class_options) {
        unsigned parent = (unsigned) count_parameter(first_math_parent_code + cls);
        cls = (parent >> 16) & 0xFF;
        if (! valid_math_class_code(cls)) {
            return 0;
        }
        value = count_parameter(first_math_options_code + cls);
    }
    return (value & option) == option;
}

static void tex_aux_unsave_math(void)
{
    tex_unsave();
    lmt_save_state.save_stack_data.ptr -= saved_math_n_of_items;
    tex_flush_node_list(lmt_dir_state.text_dir_ptr);
    if (saved_type(saved_math_item_direction) == text_direction_save_type) {
        lmt_dir_state.text_dir_ptr = saved_value(saved_math_item_direction);
    } else {
        tex_confusion("unsave math");
    }
}

/*tex

    Sometimes it is necessary to destroy an mlist. The following subroutine empties the current
    list, assuming that |abs(mode) = mmode|  aka |is_m_mode(mode)|.

*/

void tex_flush_math(void)
{
    halfword head = cur_list.head;
    tex_flush_node_list(node_next(head));
    tex_flush_node_list(cur_list.incomplete_noad);
    node_next(head) = null;
    cur_list.tail = head;
    cur_list.incomplete_noad = null;
}

/*tex A printing helper. */

static void tex_aux_print_parameter(const char *what, halfword style, halfword param, halfword indirect, halfword value)
{
    tex_begin_diagnostic();
    tex_print_format("{%s ", what);
    if (indirect >= 0 && indirect <= last_math_indirect) {
        tex_print_str(lmt_interface.math_indirect_values[indirect].name);
        tex_print_char(' ');
    }
    if (param < math_parameter_last) {
        tex_print_cmd_chr(set_math_parameter_cmd, param);
    } else {
        tex_print_format("%x %x ", math_parameter_spacing_left(param), math_parameter_spacing_right(param));
    }
    tex_print_cmd_chr(math_style_cmd, style);
    tex_print_char('=');
    switch (math_parameter_value_type(param)) {
        case math_int_parameter:
        case math_style_parameter:
            tex_print_int(value);
            break;
        case math_dimen_parameter:
            tex_print_dimension(value, pt_unit);
            break;
        case math_muglue_parameter:
            tex_print_spec(value, mu_unit);
            break;
        default:
            tex_print_int(value);
            break;
    }
    tex_print_char('}');
    tex_end_diagnostic();
}

static void tex_aux_print_fam(const char *what, halfword size, halfword fam)
{
    tex_begin_diagnostic();
    tex_print_format("{%s %C family %i: %F}", what, define_family_cmd, size, fam, tex_fam_fnt(fam, size));
    tex_end_diagnostic();
}

/*tex
    Before we can do anything in math mode, we need fonts. We can use |max_n_of_math_families|
    instead of 256 but we need to pack in bytes anyway so there is no gain.
*/

int tex_fam_fnt(int fam, int size)
{
    sa_tree_item item;
    sa_get_item_4(lmt_math_state.fam_head, fam + (256 * size), &item);
    return (int) item.int_value;
}

void tex_def_fam_fnt(int fam, int size, int fnt, int level)
{
    sa_tree_item item;
    item.int_value = fnt;
    sa_set_item_4(lmt_math_state.fam_head, fam + (256 * size), item, level);
    if (tracing_assigns_par > 1) {
        tex_aux_print_fam("assigning", size, fam);
    }
    tex_fixup_math_parameters(fam, size, fnt, level);
}

static void tex_aux_unsave_math_fam_data(int gl)
{
    if (lmt_math_state.fam_head->stack) {
        while (lmt_math_state.fam_head->sa_stack_ptr > 0 && abs(lmt_math_state.fam_head->stack[lmt_math_state.fam_head->sa_stack_ptr].level) >= (int) gl) {
            sa_stack_item item = lmt_math_state.fam_head->stack[lmt_math_state.fam_head->sa_stack_ptr];
            if (item.level > 0) {
                sa_rawset_item_4(lmt_math_state.fam_head, item.code, item.value_1);
                /*tex Now do a trace message, if requested. */
                if (tracing_restores_par > 1) {
                    int size = item.code / 256;
                    int fam = item.code % 256;
                    tex_aux_print_fam("restoring", size, fam);
                }
            }
            (lmt_math_state.fam_head->sa_stack_ptr)--;
        }
    }
}

/*tex Math parameters, we have a lot of them! Todo: move the style into 2 */

void tex_def_math_parameter(int style, int param, scaled value, int level, int indirect)
{
    sa_tree_item item1, item2;
    int different = 1;
    if (level <= 1) {
        if (math_parameter_value_type(param) == math_muglue_parameter) {
            sa_get_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * style)), &item1, &item2);
            if (item2.int_value == indirect_math_regular && item1.int_value > thick_mu_skip_code) {
                if (lmt_node_memory_state.nodesizes[item1.int_value]) {
                    tex_free_node(item1.int_value, glue_spec_size);
                }
            }
        }
    } else { 
        /*tex Less tracing at the cost of a lookup. */
        sa_get_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * style)), &item1, &item2);
        different = item1.int_value != value || item2.int_value != indirect;
    }
 // if (different) { // maybe
        item1.int_value = value;
        item2.int_value = indirect;
        sa_set_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * style)), item1, item2, level);
        if (different && tracing_assigns_par > 1) {
            tex_aux_print_parameter("assigning", style, param, indirect, value);
        }
 // }
}

// mukern .. there is no mudimen

scaled tex_get_math_parameter(int style, int param, halfword *type)
{
    halfword indirect, value;
    sa_tree_item v1, v2;
    sa_get_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * style)), &v1, &v2);
    indirect = v2.int_value == lmt_math_state.par_head->dflt.int_value ? indirect_math_unset : v2.uint_value;
    value = v1.int_value;
    switch (indirect) {
        case indirect_math_unset:
            if (type) {
                *type = no_val_level;
            }
            return MATHPARAMDEFAULT;
        /* we stored nothing */
        case indirect_math_regular:
            switch (math_parameter_value_type(param)) {
                case math_dimen_parameter:
                    if (type) {
                        *type = dimen_val_level;
                    }
                    return value;
                case math_muglue_parameter:
                    if (type) {
                        *type = mu_val_level;
                    }
                    return value <= thick_mu_skip_code ? mu_glue_parameter(value) : value;
             // case math_int_parameter:
             // case math_style_parameter:
                default:
                    if (type) {
                        *type = int_val_level;
                    }
                    return value;
            }
        /* we stored cs */
        case indirect_math_integer:
            if (! value) {
                if (type) {
                    *type = int_val_level;
                }
                return value;
            } else if (eq_type(value) == integer_cmd) {
                if (type) {
                    *type = int_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_dimension:
            if (! value) {
                if (type) {
                    *type = dimen_val_level;
                }
                return value;
            } else if (eq_type(value) == dimension_cmd) {
                if (type) {
                    *type = dimen_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_mugluespec:
            if (! value) {
                if (type) {
                    *type = mu_val_level;
                }
                return value;
            } else {
                switch (eq_type(value)) {
                    case mugluespec_cmd:
                        if (type) {
                            *type = mu_val_level;
                        }
                        return eq_value(value);
                    default:
                        goto MISMATCH;
                }

            }
        case indirect_math_gluespec:
            if (! value) {
                if (type) {
                    *type = glue_val_level;
                }
                return value;
            } else {
                switch (eq_type(value)) {
                    case gluespec_cmd:
                        if (type) {
                            *type = glue_val_level;
                        }
                        return eq_value(value);
                    default:
                        goto MISMATCH;
                }
            }
        /* we stored chr */
        case indirect_math_register_integer:
            if (! value) {
                if (type) {
                    *type = int_val_level;
                }
                return value;
            } else if (eq_type(value) == register_int_reference_cmd) {
                if (type) {
                    *type = int_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_register_dimension:
            if (! value) {
                if (type) {
                    *type = dimen_val_level;
                }
                return value;
            } else if (eq_type(value) == register_dimen_reference_cmd) {
                if (type) {
                    *type = dimen_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_register_gluespec:
            if (! value) {
                if (type) {
                    *type = glue_val_level;
                }
                return value;
            } else if (eq_type(value) == register_glue_reference_cmd) {
                if (type) {
                    *type = glue_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_register_mugluespec:
            if (! value) {
                if (type) {
                    *type = mu_val_level;
                }
                return value;
            } else if (eq_type(value) == register_mu_glue_reference_cmd) {
                if (type) {
                    *type = mu_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_internal_integer:
            if (! value) {
                if (type) {
                    *type = int_val_level;
                }
                return value;
            } else if (eq_type(value) == internal_int_reference_cmd) {
                if (type) {
                    *type = int_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_internal_dimension:
            if (! value) {
                if (type) {
                    *type = dimen_val_level;
                }
                return value;
            } else if (eq_type(value) == internal_dimen_reference_cmd) {
                if (type) {
                    *type = dimen_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_internal_gluespec:
            if (! value) {
                if (type) {
                    *type = glue_val_level;
                }
                return value;
            } else if (eq_type(value) == internal_glue_reference_cmd) {
                if (type) {
                    *type = glue_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        case indirect_math_internal_mugluespec:
            if (! value) {
                if (type) {
                    *type = mu_val_level;
                }
                return value;
            } else  if (eq_type(value) == internal_mu_glue_reference_cmd) {
                if (type) {
                    *type = mu_val_level;
                }
                return eq_value(value);
            } else {
                goto MISMATCH;
            }
        default:
          MISMATCH:
            tex_handle_error(
                normal_error_type,
                "Invalid inherited math parameter",
                "You probably changed the type of the inherited math parameter, so I will "
                "use zero instead."
            );
            return 0;
    }
}

int tex_has_math_parameter(int style, int param)
{
    sa_tree_item v1, v2;
    sa_get_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * style)), &v1, &v2);
    return v2.int_value == lmt_math_state.par_head->dflt.int_value ? indirect_math_unset : v2.uint_value;
}

static void tex_aux_unsave_math_parameter_data(int gl)
{
    if (lmt_math_state.par_head->stack) {
        while (lmt_math_state.par_head->sa_stack_ptr > 0 && abs(lmt_math_state.par_head->stack[lmt_math_state.par_head->sa_stack_ptr].level) >= (int) gl) {
            sa_stack_item item = lmt_math_state.par_head->stack[lmt_math_state.par_head->sa_stack_ptr];
            if (item.level > 0) {
                int param = item.code % math_parameter_max_range;
                int style = item.code / math_parameter_max_range;
                if (math_parameter_value_type(param) == math_muglue_parameter) {
                    sa_tree_item item1, item2;
                    sa_get_item_8(lmt_math_state.par_head, item.code, &item1, &item2);
                    if (item2.int_value == indirect_math_regular && item1.int_value > thick_mu_skip_code) {
                     /* if (tex_valid_node(item1.int_value)) { */
                        if (lmt_node_memory_state.nodesizes[item1.int_value]) {
                            // printf("HERE 2.1: %i %i / %i %i / %i\n",item2.int_value,item1.int_value, item.value_1.int_value, item.value_2.int_value, node_type(item1.int_value));
                            tex_free_node(item1.int_value, glue_spec_size);
                        } else {
                            // printf("HERE 2.2: %i %i / %i %i / %i\n",item2.int_value,item1.int_value, item.value_1.int_value, item.value_2.int_value, node_type(item1.int_value));
                        }
                    }
                }
                sa_rawset_item_8(lmt_math_state.par_head, item.code, item.value_1, item.value_2);
                /*tex Do a trace message, if requested. */
                if (tracing_restores_par > 1) {
                    int indirect = item.value_2.int_value;
                    tex_aux_print_parameter("restoring", style, param, indirect, tex_get_math_parameter(style, param, NULL));
                }
            }
            lmt_math_state.par_head->sa_stack_ptr--;
        }
    }
}

/*tex Saving and unsaving of both: */

void tex_unsave_math_data(int level)
{
    tex_aux_unsave_math_fam_data(level);
    tex_aux_unsave_math_parameter_data(level);
}

/*tex Dumping and undumping: */

void tex_dump_math_data(dumpstream f)
{
    if (! lmt_math_state.fam_head) {
        lmt_math_state.fam_head = sa_new_tree(MATHFONTSTACK, 4, (sa_tree_item) { .int_value = MATHFONTDEFAULT });
    }
    sa_dump_tree(f, lmt_math_state.fam_head);
    if (! lmt_math_state.par_head) {
        lmt_math_state.par_head = sa_new_tree(MATHPARAMSTACK, 8, (sa_tree_item) { .int_value = MATHPARAMDEFAULT });
    }
    sa_dump_tree(f, lmt_math_state.par_head);
}

void tex_undump_math_data(dumpstream f)
{
    lmt_math_state.fam_head = sa_undump_tree(f);
    lmt_math_state.par_head = sa_undump_tree(f);
}

void tex_initialize_math(void)
{
    if (! lmt_math_state.fam_head) {
        lmt_math_state.fam_head = sa_new_tree(MATHFONTSTACK, 4, (sa_tree_item) { .int_value = MATHFONTDEFAULT });
    }
    if (! lmt_math_state.par_head) {
        lmt_math_state.par_head = sa_new_tree(MATHPARAMSTACK, 8, (sa_tree_item) { .int_value = MATHPARAMDEFAULT });
        tex_initialize_math_spacing();
    }
    return;
}

/*tex

    Each portion of a formula is classified as Ord, Op, Bin, Rel, Ope, Clo, Pun, or Inn, for purposes
    of spacing and line breaking. An |ord_noad|, |op_noad|, |bin_noad|, |rel_noad|, |open_noad|,
    |close_noad|, |punct_noad|, or |inner_noad| is used to represent portions of the various types.
    For example, an |=| sign in a formula leads to the creation of a |rel_noad| whose |nucleus| field
    is a representation of an equals sign (usually |fam = 0|, |character = 075|). A formula preceded
    by |\mathrel| also results in a |rel_noad|. When a |rel_noad| is followed by an |op_noad|, say,
    and possibly separated by one or more ordinary nodes (not noads), \TEX\ will insert a penalty
    node (with the current |rel_penalty|) just after the formula that corresponds to the |rel_noad|,
    unless there already was a penalty immediately following; and a \quote {thick space} will be
    inserted just before the formula that corresponds to the |op_noad|.

    A noad of type |ord_noad|, |op_noad|, \dots, |inner_noad| usually has a |subtype = normal|. The
    only exception is that an |op_noad| might have |subtype = limits| or |no_limits|, if the normal
    positioning of limits has been overridden for this operator.

    A |radical_noad| also has a |left_delimiter| field, which usually represents a square root sign.

    A |fraction_noad| has a |right_delimiter| field as well as a |left_delimiter|.

    Delimiter fields have four subfields called |small_fam|, |small_char|, |large_fam|, |large_char|.
    These subfields represent variable-size delimiters by giving the \quote {small} and \quote
    {large} starting characters, as explained in Chapter~17 of {\em The \TEX book}.

    A |fraction_noad| is actually quite different from all other noads. It has |thickness|,
    |denominator|, and |numerator| fields instead of |nucleus|, |subscr|, and |supscr|. The
    |thickness| is a scaled value that tells how thick to make a fraction rule; however, the special
    value |preset_rule_thickness| is used to stand for the |preset_rule_thickness| of the current
    size. The |numerator| and |denominator| point to mlists that define a fraction; we always have
    |type(numerator) = type(denominator) = sub_mlist|. The |left_delimiter| and |right_delimiter|
    fields specify delimiters that will be placed at the left and right of the fraction. In this way,
    a |fraction_noad| is able to represent all of \TEX's operators |\over|, |\atop|, |\above|,
    |\overwithdelims|, |\atopwithdelims|, and |\abovewithdelims|.

    The |new_noad| function creates an |ord_noad| that is completely |null|.

*/

halfword tex_new_sub_box(halfword curbox)
{
    halfword noad = tex_new_node(simple_noad, ordinary_noad_subtype);
    halfword sbox = tex_new_node(sub_box_node, 0);
    noad_nucleus(noad) = sbox;
    kernel_math_list(sbox) = curbox;
    return noad;
}

static quarterword tex_aux_set_math_char(halfword target, mathcodeval *mval, mathdictval *dval)
{
    halfword hmcode = tex_get_hm_code(mval->character_value);
    kernel_math_character(target) = mval->character_value;
    if (mval->class_value == math_use_current_family_code) {
        kernel_math_family(target) = cur_fam_par_in_range ? cur_fam_par : mval->family_value;
        node_subtype(target) = ordinary_noad_subtype;
    } else if (mval->family_value == variable_family_par) {
        /*tex For CMS chairman MS, so that he can answer a ltx question someplace. */
        kernel_math_family(target) = cur_fam_par_in_range ? cur_fam_par : mval->family_value;
        node_subtype(target) = mval->class_value;
    } else {
        kernel_math_family(target) = mval->family_value;
        node_subtype(target) = mval->class_value;
    }
    if (dval) { 
        kernel_math_properties(target) = dval->properties;
        kernel_math_group(target) = dval->group;
        kernel_math_index(target) = dval->index;
    }
    if ((hmcode & auto_discretionary_normal) == auto_discretionary_normal) { // has_discretionary_normal
        math_kernel_node_set_option(target, math_kernel_auto_discretionary);
    } 
    if ((hmcode & auto_discretionary_italic) == auto_discretionary_italic) {  // has_discretionary_italic
        math_kernel_node_set_option(target, math_kernel_full_discretionary);
    }
    return node_subtype(target);
}

/*tex

    A few more kinds of noads will complete the set: An |under_noad| has its nucleus underlined; an
    |over_noad| has it overlined. An |accent_noad| places an accent over its nucleus; the accent
    character appears as |math_fam (accent_chr (p))| and |math_character (accent_chr (p))|. A
    |vcenter_noad| centers its nucleus vertically with respect to the axis of the formula; in such
    noads we always have |type (nucleus (p)) = sub_box|.

    And finally, we have the |fence_noad| type, to implement \TEX's |\left| and |\right| as well as
    \ETEX's |\middle|. The |nucleus| of such noads is replaced by a |delimiter| field; thus, for
    example, |\left(| produces a |fence_noad| such that |delimiter(p)| holds the family and
    character codes for all left parentheses. A |fence_noad| of subtype |left_noad_side| never
    appears in an mlist except as the first element, and a |fence_noad| with subtype
    |right_noad_side| never appears in an mlist except as the last element; furthermore, we either
    have both a |left_noad_side| and a |right_noad_side|, or neither one is present.

    Math formulas can also contain instructions like |\textstyle| that override \TeX's normal style
    rules. A |style_node| is inserted into the data structure to record such instructions; it is
    three words long, so it is considered a node instead of a noad. The |subtype| is either
    |display_style| or |text_style| or |script_style| or |script_script_style|. The second and
    third words of a |style_node| are not used, but they are present because a |choice_node| is
    converted to a |style_node|.

    \TEX\ uses even numbers 0, 2, 4, 6 to encode the basic styles |display_style|, \dots,
    |script_script_style|, and adds~1 to get the \quote {cramped} versions of these styles. This
    gives a numerical order that is backwards from the convention of Appendix~G in {\em The \TEX
    book}; i.e., a smaller style has a larger numerical value.

*/

void tex_run_math_style(void) {
    switch (cur_chr) { 
        case yet_unset_math_style:
            { 
                halfword style = tex_scan_math_style_identifier(1, 0);
                if (is_valid_math_style(style)) {
                    halfword noad = tex_new_node(style_node, (quarterword) style);
                    cur_list.math_style = style;
                    tex_tail_append(noad);
                }
            }
            break;
        case scaled_math_style:
            { 
                halfword noad = tex_new_node(style_node, scaled_math_style);
                style_scale(noad) = tex_scan_int(0, NULL);
             // style_scale(noad) = tex_scan_positive_scale(0);
                tex_tail_append(noad);
            }
            break;
        default: 
            if (is_valid_math_style(cur_chr)) {
                halfword noad = tex_new_node(style_node, (quarterword) cur_chr);
                cur_list.math_style = cur_chr;
                tex_tail_append(noad);
            } else {
                /*tex For now silently ignored. */
            }
    }
}

/*tex

    Let's consider now the previously unwritten part of |show_node_list| that displays the things
    that can only be present in mlists; this program illustrates how to access the data structures
    just defined.

    In the context of the following program, |p| points to a node or noad that should be displayed,
    and the current string contains the \quote {recursion history} that leads to this point. The
    recursion history consists of a dot for each outer level in which |p| is subsidiary to some
    node, or in which |p| is subsidiary to the |nucleus| field of some noad; the dot is replaced by
    |_| or |^| or |/| or |\\| if |p| is descended from the |subscr| or |supscr| or |denominator| or
    |numerator| fields of noads. For example, the current string would be |{\^_/}| if |p| points to
    the |ord_noad| for |x| in the (ridiculous) formula {$\sqrt {a ^ {\mathinner {b _
    {c \over x+y}}}}$|.

*/

static void tex_aux_display_choice_noad    (halfword n, int threshold, int max);
static void tex_aux_display_parameter_node (halfword n);
static void tex_aux_display_simple_noad    (halfword n, int threshold, int max);
static void tex_aux_display_radical_noad   (halfword n, int threshold, int max);
static void tex_aux_display_accent_noad    (halfword n, int threshold, int max);
static void tex_aux_display_fence_noad     (halfword n, int threshold, int max);
static void tex_aux_display_fraction_noad  (halfword n, int threshold, int max);

static void tex_aux_print_fam_and_char(halfword n)
{
    tex_print_format(", family %x, character %x, original %x", kernel_math_family(n), kernel_math_character(n));
    tex_aux_show_dictionary(n, kernel_math_properties(n), kernel_math_group(n), kernel_math_index(n), tex_fam_fnt(kernel_math_family(n), 0), kernel_math_character(n));
}

int tex_show_math_node(halfword n, int threshold, int max)
{
    switch (node_type(n)) {
        case style_node:
            /* why not shown? */
            break;
        case choice_node:
            tex_aux_display_choice_noad(n, threshold, max);
            break;
        case parameter_node:
            tex_aux_display_parameter_node(n);
            break;
        case simple_noad:
            tex_aux_display_simple_noad(n, threshold, max);
            break;
        case radical_noad:
            tex_aux_display_radical_noad(n, threshold, max);
            break;
        case accent_noad:
            tex_aux_display_accent_noad(n, threshold, max);
            break;
        case fence_noad:
            tex_aux_display_fence_noad(n, threshold, max);
            break;
        case fraction_noad:
            tex_aux_display_fraction_noad(n, threshold, max);
            break;
        case math_text_char_node:
        case math_char_node:
            tex_aux_print_fam_and_char(n);
            break;
        case sub_box_node:
            tex_print_node_list(kernel_math_list(n), NULL, threshold, max);
            break;
        case sub_mlist_node:
            if (kernel_math_list(n)) {
                tex_print_node_list(kernel_math_list(n), NULL, threshold, max);
            } else {
                tex_print_str(", empty");
            }
            break;
        default:
            return 0;
    }
    return 1;
}

inline static halfword tex_aux_valid_delimiter(halfword d)
{
    return (d && (delimiter_small_family(d) || delimiter_small_character(d) || delimiter_large_family(d) || delimiter_large_character(d))) ? d : null;
}

static void tex_aux_print_delimiter(halfword d)
{
    if (delimiter_small_family(d) < 0) {
        /*tex This should never happen. */
        tex_print_int(-1);
    } else if (delimiter_small_family(d) < 16 && delimiter_large_family(d) < 16 && delimiter_small_character(d) < 256 && delimiter_large_character(d) < 256) {
        /*tex Traditional tex style. */
        int a = delimiter_small_family(d) * 256 + delimiter_small_character(d);
        a = a * 0x1000 + delimiter_large_family(d) * 256 + delimiter_large_character(d);
        tex_print_format(", code %x", a);
    } else if ((delimiter_large_family(d) == 0 && delimiter_large_character(d) == 0) || delimiter_small_character(d) > 65535 || delimiter_large_character(d) > 65535) {
        /*tex \LUATEX\ style. */
        tex_print_format(", family %x, character %x", delimiter_small_family(d), delimiter_small_character(d));
    }
}

/*tex

    The next subroutine will descend to another level of recursion when a subsidiary mlist needs to
    be displayed. The parameter |c| indicates what character is to become part of the recursion
    history. An empty mlist is distinguished from a missing field, because these are not equivalent
    (as explained above).

*/

static void tex_aux_display_common_noad(halfword n, int threshold, int max)
{
    tex_print_node_list(noad_nucleus(n), "nucleus", threshold, max);
    tex_print_node_list(noad_supscr(n), "superscript", threshold, max);
    tex_print_node_list(noad_subscr(n), "subscript", threshold, max);
    tex_print_node_list(noad_supprescr(n), "superprescript", threshold, max);
    tex_print_node_list(noad_subprescr(n), "subprescript", threshold, max);
    tex_print_node_list(noad_prime(n), "primescript", threshold, max);
    tex_print_node_list(noad_new_hlist(n), "newhlist", threshold, max);
}

static void tex_aux_display_parameter_node(halfword n)
{
    tex_print_format(", id %i, style %i", parameter_name(n), parameter_style(n));
}

static void tex_aux_display_choice_noad(halfword n, int threshold, int max)
{
    switch (node_subtype(n)) { 
        case normal_choice_subtype: 
            tex_print_node_list(choice_display_mlist(n), "display", threshold, max);
            tex_print_node_list(choice_text_mlist(n), "text", threshold, max);
            tex_print_node_list(choice_script_mlist(n), "script", threshold, max);
            tex_print_node_list(choice_script_script_mlist(n), "scriptscript", threshold, max);
            break;
        case discretionary_choice_subtype: 
            tex_print_format(", class %i", choice_class(n));
            tex_print_node_list(choice_pre_break(n), "pre", threshold, max);
            tex_print_node_list(choice_post_break(n), "post", threshold, max);
            tex_print_node_list(choice_no_break(n), "replace", threshold, max);
            break;
    }
}

static void tex_aux_display_simple_noad(halfword n, int threshold, int max)
{
    if (noad_source(n)) {
        tex_print_format(", source %i", noad_source(n));
    }
    tex_aux_display_common_noad(n, threshold, max);
}

static void tex_aux_display_radical_noad(halfword n, int threshold, int max) /* todo: more fields */
{
    if (noad_width(n)) {
        tex_print_format(", width %D", noad_width(n), pt_unit);
    }
    if (radical_height(n)) {
        tex_print_format(", height %D", radical_height(n), pt_unit);
    }
    if (radical_depth(n)) {
        tex_print_format(", depth %D", radical_depth(n), pt_unit);
    }
    if (radical_size(n)) {
        tex_print_format(", size %i", radical_size(n));
    }
    if (noad_source(n) != 0) {
        tex_print_format(", source %i", noad_source(n));
    }
    if (noad_options(n)) {
        tex_print_format(", options %x", noad_options(n));
    }
    if (radical_left_delimiter(n)) { 
        tex_print_str(", left");
        tex_aux_print_delimiter(radical_left_delimiter(n));
    }
    if (radical_right_delimiter(n)) { 
        tex_print_str(", right");
        tex_aux_print_delimiter(radical_right_delimiter(n));
    }
    if (radical_degree(n)) {
        tex_print_node_list(radical_degree(n), "degree", threshold, max);
    }
    tex_aux_display_common_noad(n, threshold, max);
}

static void tex_aux_display_accent_noad(halfword n, int threshold, int max) /* todo: more fields */
{
    halfword top_char = accent_top_character(n);
    halfword bottom_char = accent_bottom_character(n);
    halfword fraction = accent_fraction(n);
    if (fraction) {
        tex_print_str(", fraction ");
        tex_print_int(fraction);
    }
    switch (node_subtype(n)) {
        case bothflexible_accent_subtype:
            if (top_char) {
                tex_print_str(", top ");
                tex_aux_print_fam_and_char(top_char);
            }
            if (bottom_char) {
                tex_print_str(", bottom ");
                tex_aux_print_fam_and_char(bottom_char);
            }
            if (! (top_char || bottom_char)) {
                tex_print_str(", overlay ");
                tex_aux_print_fam_and_char(accent_middle_character(n));
            }
            break;
        case fixedtop_accent_subtype:
            if (top_char) {
                tex_print_str(", fixed top ");
                tex_aux_print_fam_and_char(top_char);
            }
            if (bottom_char) {
                tex_print_str(", bottom ");
                tex_aux_print_fam_and_char(bottom_char);
            }
            break;
        case fixedbottom_accent_subtype:
            if (top_char) {
                tex_print_str(", top ");
                tex_aux_print_fam_and_char(top_char);
            }
            if (bottom_char) {
                tex_print_str(", fixed bottom ");
                tex_aux_print_fam_and_char(bottom_char);
            }
            break;
        case fixedboth_accent_subtype:
            if (top_char) {
                tex_print_str(", fixed top ");
                tex_aux_print_fam_and_char(top_char);
            }
            if (bottom_char) {
                tex_print_str(", fixed bottom ");
                tex_aux_print_fam_and_char(bottom_char);
            }
            break;
    }
    tex_aux_display_common_noad(n, threshold, max);
}

static void tex_aux_display_fence_noad(halfword n, int threshold, int max) /* todo: more fields */
{
    if (noad_height(n)) {
        tex_print_format(", height %D", noad_height(n), pt_unit);
    }
    if (noad_depth(n)) {
        tex_print_format(", depth %D", noad_depth(n), pt_unit);
    }
    if (fence_top_overshoot(n)) {
        tex_print_format(", top %D", fence_top_overshoot(n), pt_unit);
    }
    if (fence_bottom_overshoot(n)) {
        tex_print_format(", top %D", fence_bottom_overshoot(n), pt_unit);
    }
    if (get_noad_main_class(n) != unset_noad_class) {
        tex_print_format(", class %i", get_noad_main_class(n));
    }
    if (get_noad_left_class(n) != unset_noad_class) {
        tex_print_format(", leftclass %i", get_noad_left_class(n));
    }
    if (get_noad_right_class(n) != unset_noad_class) {
        tex_print_format(", rightclass %i", get_noad_right_class(n));
    }
    if (noad_source(n) != 0) {
        tex_print_format(", source %i", noad_source(n));
    }
    if (noad_options(n)) {
        tex_print_format(", options %x", noad_options(n));
    }
    tex_aux_print_delimiter(fence_delimiter_list(n));
    tex_print_node_list(fence_delimiter_top(n), "top", threshold, max);
    tex_print_node_list(fence_delimiter_bottom(n), "bottom", threshold, max);
}

static void tex_aux_display_fraction_noad(halfword n, int threshold, int max) /* todo: more fields */
{
    halfword leftdelimiter = tex_aux_valid_delimiter(fraction_left_delimiter(n));
    halfword rightdelimiter = tex_aux_valid_delimiter(fraction_right_delimiter(n));
    tex_print_str(", thickness ");
    if (fraction_rule_thickness(n) == preset_rule_thickness) {
        tex_print_str("default");
    } else {
        tex_print_dimension(fraction_rule_thickness(n), pt_unit);
    }
    if (leftdelimiter) {
        tex_print_str(", leftdelimiter ");
        tex_aux_print_delimiter(leftdelimiter);
    }
    if (rightdelimiter) {
        tex_print_str(", rightdelimiter ");
        tex_aux_print_delimiter(rightdelimiter);
    }
    if (noad_source(n) != 0) {
        tex_print_str(", source ");
        tex_print_int(noad_source(n));
    }
    if (noad_options(n)) {
        tex_print_str(", options ");
        tex_print_qhex(noad_options(n));
    }
    tex_print_node_list(fraction_numerator(n), "numerator", threshold, max);
    tex_print_node_list(fraction_denominator(n), "denominator", threshold, max);
}

/*tex

    The routines that \TEX\ uses to create mlists are similar to those we have just seen for the
    generation of hlists and vlists. But it is necessary to make \quote {noads} as well as nodes,
    so the reader should review the discussion of math mode data structures before trying to make
    sense out of the following program.

    Here is a little routine that needs to be done whenever a subformula is about to be processed.
    The parameter is a code like |math_group|.

*/

static void tex_aux_new_save_level_math(quarterword group)
{
    halfword direction = math_direction_par;
    tex_set_saved_record(saved_math_item_direction, text_direction_save_type, 0, lmt_dir_state.text_dir_ptr);
    lmt_save_state.save_stack_data.ptr += saved_math_n_of_items;
    lmt_dir_state.text_dir_ptr = tex_new_dir(normal_dir_subtype, direction);
    tex_new_save_level(group);
    update_tex_par_direction(direction);
    update_tex_text_direction(direction);
}

static void tex_aux_push_math(quarterword group, int style)
{
    if (math_direction_par != text_direction_par) {
        cur_list.math_dir = 1;
    }
    cur_list.math_begin = math_begin_class_par;
    cur_list.math_end = math_end_class_par;
    cur_list.math_main_style = style;
    tex_push_nest();
    cur_list.mode = inline_mmode;
    cur_list.incomplete_noad = null;
    cur_list.math_style = style;
    tex_aux_new_save_level_math(group);
    update_tex_math_left_class(unset_noad_class);
    update_tex_math_right_class(unset_noad_class);
}

static void tex_aux_enter_inline_math(int style)
{
    tex_aux_push_math(math_inline_group, style);
    update_tex_family(0, unused_math_family);
    if (every_math_par) {
        tex_begin_token_list(every_math_par, every_math_text);
    }
}

static void tex_aux_enter_display_math(halfword cmd);

/*tex

    We get into math mode from horizontal mode when a |$| (i.e., a |math_shift| character) is
    scanned. We must check to see whether this |$| is immediately followed by another, in case
    display math mode is called for.

*/

void tex_run_math_initialize(void)
{
    switch(cur_cmd) {
        case math_shift_cmd:
            /*tex |get_x_token| would fail on |\ifmmode|! */
            lmt_nest_state.math_mode = 1;
            tex_get_token();
            lmt_nest_state.math_mode = 0;
            if (cur_cmd == math_shift_cmd && cur_list.mode > nomode) {
                tex_aux_enter_display_math(math_shift_cmd);
            } else {
                tex_back_input(cur_tok);
                tex_aux_enter_inline_math(text_style);
            }
            break;
        case math_shift_cs_cmd:
            if (cur_chr == begin_math_mode_code) {
                tex_aux_enter_inline_math(tex_scan_math_style_identifier(0, 0));
            } else if (cur_chr == begin_display_math_code && cur_list.mode > nomode) {
                tex_aux_enter_display_math(begin_display_math_code);
            } else if (cur_chr == begin_inline_math_code) {
                tex_aux_enter_inline_math(text_style);
            } else {
                tex_you_cant_error("math shift 1");
            }
            break;
        default:
            tex_you_cant_error("math shift 2");
            break;
    }
}

/*tex

    We get into ordinary math mode from display math mode when |\eqno| or |\leqno| appears. In such
    cases |cur_chr| will be 0 or~1, respectively; the value of |cur_chr| is placed onto |save_stack|
    for safe keeping. When \TEX\ is in display math mode, |cur_group = math_shift_group|, so it is
    not necessary for the |start_eq_no| procedure to test for this condition.

*/

void tex_run_math_equation_number(void) {
    if (cur_group == math_display_group) {
        tex_set_saved_record(saved_equation_number_item_location, equation_number_location_save_type, 0, cur_chr);
        lmt_save_state.save_stack_data.ptr += saved_equation_number_n_of_items;
        tex_aux_enter_inline_math(text_style);
    } else {
        tex_off_save();
    }
}

/*tex

    Subformulas of math formulas cause a new level of math mode to be entered, on the semantic nest
    as well as the save stack. These subformulas arise in several ways: (1)~A left brace by itself
    indicates the beginning of a subformula that will be put into a box, thereby freezing its glue
    and preventing line breaks. (2)~A subscript or superscript is treated as a subformula if it is
    not a single character; the same applies to the nucleus of things like |\underline|. (3)~The
    |\left| primitive initiates a subformula that will be terminated by a matching |\right|. The
    group codes placed on |save_stack| in these three cases are |math_group|, |math_group|, and
    |math_left_group|, respectively.

    Here is the code that handles case (1); the other cases are not quite as trivial, so we shall
    consider them later.

*/

void tex_run_math_left_brace(void)
{
    if (math_grouping_mode_par) {
        /*tex This is an experiment. Some tracing has to be adapted probably. */
        tex_new_save_level(math_simple_group);
        update_tex_internal_math_style(cur_mode == mmode ? cur_list.math_style : -1);
        update_tex_internal_math_scale(cur_mode == mmode ? cur_list.math_scale : -1);
    } else {
        halfword q = tex_new_node(math_char_node, 0);
        halfword n = tex_new_node(simple_noad, ordinary_noad_subtype);
        tex_tail_append(n);
        noad_nucleus(n) = q;
        tex_back_input(cur_tok);
        tex_aux_scan_math(q, cur_list.math_style, 0, 0, 0, 0, unset_noad_class, unset_noad_class);
    }
}

/*tex

    If the inline directions of |\pardir| and |\mathdir| are opposite, then this function will
    return true. Discovering that fact is somewhat odd because it needs traversal of the
    |save_stack|. The occurance of displayed equations is weird enough that this is probably still
    better than having yet another field in the |input_stack| structures.

    None of this makes much sense if the inline direction of either one of |\pardir| or |\mathdir|
    is vertical, but in that case the current math machinery is ill suited anyway so I do not
    bother to test that. We now just return the direction.

*/

static int tex_aux_pre_math_par_direction(void)
{
    return tex_located_save_value(internal_int_location(par_direction_code));
}

/*tex

    When we enter display math mode, we need to call |line_break| to process the partial paragraph
    that has just been interrupted by the display. Then we can set the proper values of
    |display_width| and |display_indent| and |pre_display_size|.

*/

static void tex_aux_enter_display_math(halfword cmd)
{
    if (math_display_mode_par) {
        tex_aux_push_math(math_inline_group, display_style);
        cur_list.math_mode = cmd; 
        cur_list.mode = inline_mmode; /* new */
        update_tex_family(0, unused_math_family);
        if (every_display_par) {
            tex_begin_token_list(every_display_par, every_display_text);
        }
    } else { 
        /*tex new or partial |pre_display_size| */
        scaled size;
        /*tex new |display_width| */
        scaled width;
        /*tex new |display_indent| */
        scaled indent;
        /*tex
            Deal with |\noindent$$| or |$${ }$$| or the 2nd of |$${ }$$| |$${ }$$|.
        */
        if (cur_list.head == cur_list.tail || (node_next(cur_list.head) == cur_list.tail && node_type(cur_list.tail) == par_node && ! node_next(cur_list.tail))) {
            if (node_next(cur_list.head) == cur_list.tail) {
                /*tex
                    |resume_after_display| inserts a |par_node|, but if there is another display
                    immediately following, we have to get rid of that node.
                */
                tex_flush_node(cur_list.tail);
             /* cur_list.tail = cur_list.head; */ /* probably needed */
            }
            tex_pop_nest();
            size = - max_dimen;
        } else {
            tex_line_break(1, math_display_group);
         // size = tex_actual_box_width(lmt_linebreak_state.just_box, tex_x_over_n(tex_get_font_em_width(cur_font_par), 1000) * math_pre_display_gap_factor_par);
            size = tex_actual_box_width(lmt_linebreak_state.just_box, scaledround((tex_get_font_em_width(cur_font_par) / 1000.0) * math_pre_display_gap_factor_par));
        }
        /*tex
            Now we are in vertical mode, working on the list that will contain the display. A displayed
            equation is considered to be three lines long, so we calculate the length and offset of line
            number |prev_graf + 2|.
        */
        if (par_shape_par) {
            /*tex scope of paragraph shape specification */
            int n = tex_get_specification_count(par_shape_par);
            if (n > 0) {
                if (cur_list.prev_graf + 2 < n) {
                    n = cur_list.prev_graf + 2;
                }
                indent = tex_get_specification_indent(par_shape_par, n) ;
                width = tex_get_specification_width(par_shape_par, n);
                indent = swap_parshape_indent(pre_display_direction_par, indent, width);
            } else {
                width = hsize_par;
                indent = 0;
            }
        } else if ((hang_indent_par != 0) && (((hang_after_par >= 0) && (cur_list.prev_graf + 2 > hang_after_par)) || (cur_list.prev_graf + 1 < -hang_after_par))) {
            halfword hangindent = swap_hang_indent(pre_display_direction_par, hang_indent_par);
            width = hsize_par - abs(hangindent);
            indent = hangindent > 0 ? hangindent : 0;
        } else {
            width = hsize_par;
            indent = 0;
        }
        tex_aux_push_math(math_display_group, display_style);
        cur_list.mode = mmode;
        update_tex_family(0, unused_math_family);
        update_tex_pre_display_size(size);
        update_tex_display_width(width);
        update_tex_display_indent(indent);
        update_tex_pre_display_direction(tex_aux_pre_math_par_direction());
        if (every_display_par) {
            tex_begin_token_list(every_display_par, every_display_text);
        }
        if (lmt_nest_state.nest_data.ptr == 1) {
            if (! lmt_page_builder_state.output_active) {
                lmt_page_filter_callback(before_display_page_context, 0);
            }
            tex_build_page();
        }
    }
}

/*tex

    The next routine parses all variations of a delimiter code. The |extcode| tells what syntax form
    to use (\TEX\ or \LUATEX) , the |doclass| tells whether or not read a math class also (for
    |\delimiter| c.s.). The class is passed on for conversion to |\mathchar|.

*/

static delcodeval tex_aux_scan_extdef_del_code(int extcode, int doclass)
{
    delcodeval d = tex_no_del_code();
    switch (extcode) {
        case tex_mathcode:
            /*tex This is the easiest: |\delcode|,*/
            {
                halfword v = tex_scan_int(0, NULL);
                /*tex |MFCCFCC| or |FCCFCC| */
                if (doclass) {
                    d.small.class_value = (short) (v / 0x1000000);
                    v = (v & 0xFFFFFF);
                }
                if (v > 0xFFFFFF) {
                    tex_handle_error(
                        normal_error_type,
                        "Invalid delimiter code",
                        "I'm going to use 0 instead of that illegal code value."
                    );
                    v = 0;
                }
                d.small.family_value = (short) (v / 0x100000);
                d.small.character_value = (v % 0x100000) / 0x1000;
                d.large.family_value = (short) ((v & 0xFFF) / 0x100);
                d.large.character_value = (v % 0x100);
                /* */
                d.small.character_value = math_character_part(d.small.character_value);
                d.large.character_value = math_character_part(d.large.character_value);
            }
            break;
        case umath_mathcode:
            /*tex |\Udelcode|: |<0-7><0-0xFF><0-0x10FFFF>| or |<0-0xFF><0-0x10FFFF>| */
            {
                if (doclass) {
                    d.small.class_value = (short) tex_scan_math_class_number(0);
                }
                d.small.family_value = (short) tex_scan_math_family_number();
                d.small.character_value = tex_scan_math_char_number();
                if (d.small.family_value < 0 || d.small.family_value > max_math_family_index) {
                    tex_handle_error(
                        normal_error_type,
                        "Invalid delimiter family",
                        "I'm going to use family 0 instead."
                    );
                    d.small.family_value = 0;
                    d.small.character_value = 0;
                }
            }
            break;
        default:
            /*tex Something's gone wrong! */
            tex_confusion("unknown extcode, case 1");
            break;
    }
    d.large.class_value = d.small.class_value;
    return d;
}

void tex_scan_extdef_del_code(int level, int extcode)
{
    delcodeval d;
    int chr = tex_scan_char_number(0);
    tex_scan_optional_equals();
    d = tex_aux_scan_extdef_del_code(extcode, 0);
    tex_set_del_code(chr, d, (quarterword) level);
}

mathdictval tex_scan_mathdict(void)
{
    mathdictval d = tex_no_dict_code(); /* use this one directly */
    d.properties = (unsigned short) tex_scan_math_properties_number();
    d.group = (unsigned short) tex_scan_math_group_number();
    d.index = (unsigned int) tex_scan_math_index_number();
    return d;
}

mathcodeval tex_scan_mathchar(int extcode)
{
    mathcodeval d = tex_no_math_code(); /* use this one directly */
    switch (extcode) {
        case tex_mathcode:
            /*tex |"<4bits><4bits><8bits>| */
            {
                halfword v = tex_scan_int(0, NULL);
                if (v >= 0) {
                    if (v > 0xFFFF) {
                        v = 0xFFFF;
                    }
                    d.class_value = (short) math_old_class_part(v);
                    d.family_value = (short) math_old_family_part(v);
                    d.character_value = math_old_character_part(v);
                }
            }
            break;
        case umath_mathcode:
            /*tex |"<6bits>"<6bits>"<20bits>| */
            {
                d.class_value = (short) tex_scan_math_class_number(0);
                d.family_value = (short) tex_scan_math_family_number();
                d.character_value = tex_scan_math_char_number();
            }
            break;
        /*
        case umathnum_mathcode:
            // |"<6bits><6bits><20bits>|: the largest numeric value is $2^32-1$, but the top of bit 21 can't
            // be used as it contains invalid USV's. Note: |scan_int| won't accept families 128-255
            // because these use bit 32.
            {
                halfword v = tex_scan_int(0, NULL);
                d.class_value = (short) math_class_part(v);
                d.family_value = (short) math_family_part(v);
                d.character_value = math_character_part(v);
            }
            break;
        */
        default:
            /*tex Something's gone wrong. */
            tex_confusion("unknown extcode, case 2");
            break;
    }
    if (d.class_value < 0 || d.character_value > max_math_character_code || d.class_value > max_math_class_code || d.family_value > max_math_family_index) {
        tex_handle_error(
            normal_error_type,
            "Invalid math code",
            "I'm going to use 0 instead of that illegal code value."
        );
        d.class_value = 0;
        d.family_value = 0;
        d.character_value = 0;
    }
    return d;
}

halfword tex_new_math_spec(mathcodeval m, quarterword code)
{
    halfword s = tex_new_node(math_spec_node, code);
    math_spec_class(s) = (singleword) m.class_value;
    math_spec_family(s) = (singleword) m.family_value;
    math_spec_character(s) = m.character_value;
    return s;
}

halfword tex_new_math_dict_spec(mathdictval d, mathcodeval m, quarterword code)
{
    halfword s = tex_new_node(math_spec_node, code);
    math_spec_class(s) = (singleword) m.class_value;
    math_spec_family(s) = (singleword) m.family_value;
    math_spec_character(s) = m.character_value;
    math_spec_properties(s) = (quarterword) d.properties;
    math_spec_group(s) = (quarterword) d.group;
    math_spec_index(s) = d.index;
    return s;
}

mathcodeval tex_get_math_spec(halfword s)
{
    mathcodeval m = tex_no_math_code();
    if (s) {
        m.class_value = math_spec_class(s);
        m.family_value = math_spec_family(s);
        m.character_value = math_spec_character(s);
    }
    return m;
}

mathdictval tex_get_math_dict(halfword s)
{
    mathdictval d = tex_no_dict_code();
    if (s) {
        d.properties = math_spec_properties(s);
        d.group = math_spec_group(s);
        d.index = math_spec_index(s);
    }
    return d;
}

halfword tex_scan_math_spec(int optional_equal)
{
    mathcodeval m;
    if (optional_equal) {
        tex_scan_optional_equals();
    }
    m = tex_scan_mathchar(umath_mathcode);
    return tex_new_math_spec(m, mathspec_mathcode);
}

void tex_scan_extdef_math_code(int level, int extcode)
{
    mathcodeval d;
    int chr = tex_scan_char_number(0);
    tex_scan_optional_equals();
    d = tex_scan_mathchar(extcode);
    tex_set_math_code(chr, d, (quarterword) level);
}

/*tex This reads in a delcode when actually a mathcode is needed. */

mathcodeval tex_scan_delimiter_as_mathchar(int extcode)
{
    delcodeval dval = tex_aux_scan_extdef_del_code(extcode, 1);
    return dval.small;
}

/*tex

    Recall that the |nucleus|, |subscr|, and |supscr| fields in a noad are broken down into subfields
    called |type| and either |math_list| or |(math_fam, math_character)|. The job of |scan_math| is
    to figure out what to place in one of these principal fields; it looks at the subformula that
    comes next in the input, and places an encoding of that subformula into a given word of |mem|.

    already prepared: every [component, degree, radical, over, under, accent, prime, subscript,
    superscript]

    toks      : every_subscript_par
    toks_text : every_subscipt_text or every_math_text (for tracing)

*/

/*tex 
    For some reason |$\char44$| gives an undefined |$| when we made that character active in math. 
*/

static void tex_aux_report_active(int where, const char *what, int code, int character) 
{
    tex_begin_diagnostic();
    tex_print_format("[active: location %i, %s, code %i, char %i]",where, what, code, character);
    tex_end_diagnostic();
}

static void tex_aux_append_math_char(mathcodeval mval, mathdictval dval, int automatic);

int tex_check_active_math_char(int character)
{
    halfword code = tex_get_am_code(character);
    if (code) {
        switch (code) {
            case alignment_tab_cmd:              
            case superscript_cmd:                
            case subscript_cmd:                  
            case letter_cmd:                     
            case other_char_cmd:
            case active_char_cmd:
                cur_cmd = code;
                cur_chr = character;
                cur_tok = token_val(cur_cmd, cur_chr);
                if (tracing_commands_par >= 4) {
                    switch (code) {
                        case alignment_tab_cmd:              
                        case superscript_cmd:                
                        case subscript_cmd:                  
                            tex_aux_report_active(4, "control", code, character);
                            break;
                        case letter_cmd:                     
                        case other_char_cmd:
                            tex_aux_report_active(4, "inject", code, character);
                            break;
                        case active_char_cmd:
                            tex_aux_report_active(4, "active", code, character);
                            break;
                    }
                }
                return 1;
            default: 
                if (tracing_commands_par >= 4) {
                    tex_aux_report_active(4, "ignore", code, character);
                }
                return 1;
        }
    } else { 
        return 0;
    }
}

int tex_pass_active_math_char(int character)
{
    halfword code = tex_get_am_code(character);
    if (code) {
        return 1;
    } else { 
        return 0;
    }
}

static int tex_aux_scan_active_math_char(mathcodeval *mval, int where)
{
    halfword character = mval->character_value;
    halfword code = tex_get_am_code(character);
    if (code) {
        switch (code) {
            case alignment_tab_cmd:              
            case superscript_cmd:                
            case subscript_cmd:                  
                cur_cmd = code;
                cur_chr = character;
                cur_tok = token_val(cur_cmd, cur_chr);
                tex_back_input(cur_tok);
                if (tracing_commands_par >= 4) {
                    tex_aux_report_active(where, "control", code, character);
                }
                return 1;
            case letter_cmd:                     
            case other_char_cmd:
                cur_cmd = code;
                cur_chr = character;
                cur_tok = token_val(cur_cmd, cur_chr);
                if (tracing_commands_par >= 4) {
                    tex_aux_report_active(where, "inject", code, character);
                }
                return 0;
            case active_char_cmd:
                /*tex 
                    We reset the code so that we don't get a loop, whuich means that the macro that 
                    gets invoked has to set the amcode again if needed. 
                */
                tex_set_am_code(character, other_char_cmd, 0);
                cur_cs = tex_active_to_cs(cur_chr, 1);
                cur_cmd = eq_type(cur_cs);
                cur_chr = eq_value(cur_cs);
                tex_x_token();
                tex_back_input(cur_tok);
                if (tracing_commands_par >= 4) {
                    tex_aux_report_active(where, "active", code, character);
                }
                return 1;
            default: 
                if (tracing_commands_par >= 4) {
                    tex_aux_report_active(where, "ignore", code, character);
                }
                return 1;
        }
    } else if (mval->class_value == active_math_class_value) {
        /*tex We might eventually drop tthis feature in favor of the amcode. */
        cur_cs = tex_active_to_cs(cur_chr, 1);
        cur_cmd = eq_type(cur_cs);
        cur_chr = eq_value(cur_cs);
        tex_x_token();
        tex_back_input(cur_tok);
        if (tracing_commands_par >= 4) {
            tex_aux_report_active(where, "active", code, character);
        }
        return 1;
    } else { 
     // if (tracing_commands_par >= 4) {
     //     tex_aux_report_active(where, "keep", code, mval->character_value);
     // }
        return 0;
    }
}

static int tex_aux_scan_math(halfword target, halfword style, int usetextfont, halfword toks, halfword toks_text, int nocomponent, halfword cls, halfword all)
{
    mathcodeval mval = tex_no_math_code();
    mathdictval dval = tex_no_dict_code();
    lmt_math_state.last_atom = cls;
  RESTART:
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd || cur_cmd == relax_cmd);
//  RESWITCH:
    switch (cur_cmd) {
        case char_number_cmd:
            /* The |\glyph| variant is accepted but no keywords here. */
            cur_chr = tex_scan_char_number(0);
            // fall through 
        case letter_cmd:
        case other_char_cmd:
        case char_given_cmd:
            mval = tex_get_math_code(cur_chr);
            if (tex_aux_scan_active_math_char(&mval, 1)) { 
                goto RESTART; /* rescan pushed back token */
            } else {
                dval = tex_fake_math_dict(mval.character_value);
                break;
            }
    //  case char_number_cmd:
    //      /* The |\glyph| variant is accepted but no keywords here. */
    //      cur_chr = tex_scan_char_number();
    //      cur_cmd = char_given_cmd;
    //      goto RESWITCH;
        case math_char_number_cmd:
            switch (cur_chr) {
                case math_char_number_code:
                    mval = tex_scan_mathchar(tex_mathcode);
                    break;
                case math_xchar_number_code:
                    mval = tex_scan_mathchar(umath_mathcode);
                    break;
                default:
                    tex_confusion("scan math char, case 1");
                    break;
            }
            dval = tex_fake_math_dict(mval.character_value);
            break;
        case mathspec_cmd:
            mval = tex_get_math_spec(cur_chr);
            dval = tex_get_math_dict(cur_chr);
            break;
        case delimiter_number_cmd:
            switch (cur_chr) {
                case math_delimiter_code:
                    mval = tex_scan_delimiter_as_mathchar(tex_mathcode);
                    break;
                case math_udelimiter_code:
                    mval = tex_scan_delimiter_as_mathchar(umath_mathcode);
                    break;
                default:
                    tex_confusion("scan math char, case 2");
                    break;
            }
            break;
		case math_component_cmd:
			if (nocomponent) {
                goto DEFAULT;
            } else {
			    tex_set_saved_record(saved_math_group_item_pointer, math_pointer_save_type, 0, target);
                tex_set_saved_record(saved_math_group_all_class, math_class_save_type, 0, unset_noad_class);
			    lmt_save_state.save_stack_data.ptr += saved_math_group_n_of_items;
			    tex_aux_push_math(math_component_group, style);
                if (usetextfont) {
                    tex_set_math_text_font(style, usetextfont);
                }
    		    tex_aux_math_math_component(cur_list.tail, 0);
                tex_finish_math_group();
    			return 1;
		    }
        case left_brace_cmd:
            goto SCAN_SUBFORMULA;
        default:
            /*tex
                The pointer |p| is placed on |save_stack| while a complex subformula is being
                scanned.
            */
          DEFAULT:
            tex_back_input(cur_tok);
            tex_scan_left_brace();
          SCAN_SUBFORMULA:
            tex_set_saved_record(saved_math_group_item_pointer, math_pointer_save_type, 0, target);
            tex_set_saved_record(saved_math_group_all_class, math_class_save_type, 0, all);
            lmt_save_state.save_stack_data.ptr += saved_math_group_n_of_items;
            tex_aux_push_math(math_group, style);
            toks = every_math_atom_par;
            toks_text = every_math_atom_text; 
            if (toks) {
                tex_begin_token_list(toks, (quarterword) toks_text);
            }
            if (usetextfont) {
                tex_set_math_text_font(style, usetextfont);
            }
            return 1;
    }
    node_type(target) = math_char_node;
    if (glyph_options_par & glyph_option_no_italic_correction) {
        math_kernel_node_set_option(target, math_kernel_no_italic_correction);
    }
    if (glyph_options_par & glyph_option_no_left_kern) {
        math_kernel_node_set_option(target, math_kernel_no_left_pair_kern);
    }
    if (glyph_options_par & glyph_option_no_right_kern) {
        math_kernel_node_set_option(target, math_kernel_no_right_pair_kern);
    }
    tex_aux_set_math_char(target, &mval, &dval);
    return 0;
}

/*tex

    The |append_math_char| procedure creates a new noad appropriate to a given math code, and
    appends it to the current mlist. However, if the math code is sufficiently large, the |cur_chr|
    is treated as an active character and nothing is appended.

*/

static void tex_aux_append_math_accent(mathcodeval mval, mathdictval dval)
{
    halfword accent = tex_new_node(accent_noad, bothflexible_accent_subtype);
    quarterword subtype = ordinary_noad_subtype;
    tex_tail_append(accent);
    if (! (mval.character_value == 0 && mval.family_value == 0)) {
        halfword q = tex_new_node(math_char_node, 0);
        subtype = tex_aux_set_math_char(q, &mval, &dval);
        accent_top_character(accent) = q;
    }
    {
        halfword q = tex_new_node(math_char_node, subtype);
        noad_nucleus(accent) = q;
        tex_aux_scan_math(q, tex_math_style_variant(cur_list.math_style, math_parameter_accent_variant), 0, 0, 0, 0, unset_noad_class, unset_noad_class);
    }
}

/*tex 
    Fences are actually constructs and middle sort of interferes here: we keep a sort of flat fence
    sequence so middle ends a group and opens a new one. 

*/

static void tex_aux_append_math_fence(halfword fence, quarterword mathclass)
{
    switch (mathclass) {
        case open_noad_subtype:
            {
                tex_aux_push_math(math_fence_group, cur_list.math_style);
                node_subtype(fence) = left_fence_side;
                node_next(cur_list.head) = fence;
                cur_list.tail = fence;
                cur_list.delimiter = fence;
            }
            break;
        case close_noad_subtype:
            {
                halfword q = tex_aux_finish_math_list(fence);
                halfword n = tex_new_node(simple_noad, fenced_noad_subtype);
                halfword l = tex_new_node(sub_mlist_node, 0);
                tex_aux_unsave_math();
                tex_tail_append(n);
                node_subtype(fence) = right_fence_side;
                noad_nucleus(n) = l;
                noad_options(n) |= noad_option_unpack_list;
                kernel_math_list(noad_nucleus(n)) = q;
            }
            break;
        case middle_noad_subtype:
            { 
                halfword q = tex_aux_finish_math_list(fence);
                tex_aux_unsave_math();
                tex_aux_push_math(math_fence_group, cur_list.math_style);
                node_subtype(fence) = middle_fence_side;
                node_next(cur_list.head) = q;
                cur_list.tail = fence;
                cur_list.delimiter = fence;
            }
            break;
    }
}

static void tex_aux_append_math_fence_val(mathcodeval mval, mathdictval dval, quarterword mathclass)
{
    halfword fence = tex_new_node(fence_noad, middle_fence_side);
    halfword delimiter = tex_new_node(delimiter_node, mval.class_value);
    (void) dval; /* maybe todo */
    fence_delimiter_list(fence) = delimiter;
    delimiter_small_family(delimiter) = mval.family_value;
    delimiter_small_character(delimiter) = mval.character_value;
    delimiter_large_family(delimiter) = mval.family_value;
    delimiter_large_character(delimiter) = mval.character_value;
    set_noad_classes(fence, mval.class_value);
    /* todo : share the next three with the regular fences */
    noad_options(fence) |= noad_option_no_check;
    if (mathclass == middle_noad_subtype && cur_group != math_fence_group) { 
        tex_aux_append_math_fence_val(tex_no_math_code(), tex_no_dict_code(), open_noad_subtype);
    }
    tex_aux_append_math_fence(fence, mathclass);
}

static void tex_aux_append_math_char(mathcodeval mval, mathdictval dval, int automatic)
{
    if (tex_aux_scan_active_math_char(&mval, 2)) { 
        return; /* rescan pushed back token */
    } else { 
        if (automatic && tex_math_has_class_option(mval.class_value, auto_inject_class_option)) {
            switch (mval.class_value) { 
                case accent_noad_subtype:
                    tex_aux_append_math_accent(mval, dval);
                    return;
                case open_noad_subtype:
                case close_noad_subtype:
                case middle_noad_subtype:
                    tex_aux_append_math_fence_val(mval, dval, mval.class_value);
                    return;
            }
        } 
        {
            halfword p = tex_new_node(simple_noad, ordinary_noad_subtype);
            halfword q = tex_new_node(math_char_node, 0);
            noad_nucleus(p) = q;
            if (glyph_options_par & glyph_option_no_italic_correction) {
                math_kernel_node_set_option(q, math_kernel_no_italic_correction);
            }
            node_subtype(p) = tex_aux_set_math_char(q, &mval, &dval);
            tex_math_set_scripts_options(p);
            tex_tail_append(p);
        }
    }
}

/*tex

    The |append_math_char_in_text| procedure creates a new node representing a math char in text
    code, and appends it to the current list. However, if the math code is sufficiently large, the
    |cur_chr| is treated as an active character and nothing is appended.

*/

static void tex_aux_append_math_char_in_text(mathcodeval mval, mathdictval dval)
{
    (void) dval;
    if (tex_aux_scan_active_math_char(&mval, 3)) {
        return; /* rescan pushed back token */
    } else { 
        halfword p = tex_new_char_node(glyph_character_subtype, tex_fam_fnt(mval.family_value, text_size), mval.character_value, 1); /* todo: data */
        tex_tail_append(p);
    }
}

void tex_run_math_letter(void) 
{
    tex_aux_append_math_char(tex_get_math_code(cur_chr), tex_fake_math_dict(cur_chr), 1);
}

void tex_run_math_char_number(void) {
    /*tex 
        Both |\char| and |\glyph| get the same treatment. Scanning can change |cur_chr| so we do 
        that first. We no longer check for active here! 
    */
    mathcodeval mval = tex_no_math_code();
    mathdictval dval = tex_no_dict_code();
    cur_chr = tex_scan_char_number(0); 
    mval.character_value = cur_chr;
    mval.family_value = (short) cur_fam_par;
 // tex_aux_append_math_char(tex_get_math_code(cur_chr), tex_fake_math_dict(cur_chr));
    tex_aux_append_math_char(mval, dval, 1);
}

void tex_run_math_math_spec(void)
{
    tex_aux_append_math_char(tex_get_math_spec(cur_chr), tex_get_math_dict(cur_chr), 1);
}

void tex_run_text_math_spec(void)
{
    tex_aux_append_math_char_in_text(tex_get_math_spec(cur_chr), tex_get_math_dict(cur_chr));
}

int tex_scan_math_cmd_val(mathcodeval *mval, mathdictval *dval)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_cmd) {
        case mathspec_cmd:
            *mval = tex_get_math_spec(cur_chr);
            break;
        case math_char_number_cmd:
            switch (cur_chr) {
                case math_char_number_code:
                    *mval = tex_scan_mathchar(tex_mathcode);
                    break;
                case math_xchar_number_code:
                    *mval = tex_scan_mathchar(umath_mathcode);
                    break;
                case math_dchar_number_code:
                    *dval = tex_scan_mathdict();
                    *mval = tex_scan_mathchar(umath_mathcode);
                    break;
                default:
                    /* no message yet */
                    return 0;
            }
            break;
        case delimiter_number_cmd:
            switch (cur_chr) {
                case math_delimiter_code:
                    *mval = tex_scan_delimiter_as_mathchar(tex_mathcode);
                    break;
                case math_udelimiter_code:
                    *mval = tex_scan_delimiter_as_mathchar(umath_mathcode);
                    break;
                default:
                    /* no message yet */
                    return 0;
            }
            break;
        /*tex 
            This is/was an experiment but could work out ambigiuous in some cases so when I bring it 
            back it will be under more strict control. So, for instance a register would make us 
            enter the default branch but a direct number the other case. In the meantiem we no longer 
            use the direct char approach (for delimiters mostly) so we can comment it. 
        */
      // case letter_cmd: 
      // case other_char_cmd: 
      //     mval->character_value = cur_chr; 
      //     break; 
        default:
            /*tex
                We could do a fast |tex_scan_something_internal| here but this branch is not that 
                critical. 
            */     
            {
                halfword n = 0;
                tex_back_input(cur_tok);
                n = tex_scan_int(0, NULL);
                *mval = tex_mathchar_from_integer(n, umath_mathcode);
            }
            break;
    }
    return 1;
}

int tex_scan_math_code_val(halfword code, mathcodeval *mval, mathdictval *dval)
{
    switch (code) {
        case math_char_number_code:
            *mval = tex_scan_mathchar(tex_mathcode);
            break;
        case math_xchar_number_code:
            *mval = tex_scan_mathchar(umath_mathcode);
            break;
        case math_dchar_number_code:
            *dval = tex_scan_mathdict();
            *mval = tex_scan_mathchar(umath_mathcode);
            break;
        case math_class_number_code:
            {
                halfword family = cur_fam_par;
                halfword mathclass  = tex_scan_int(0, NULL);
                tex_scan_math_cmd_val(mval, dval);
                mval->class_value = (short) mathclass;
                mval->family_value = (short) family;
            }
            break;
        default:
            /* no message yet */
            tex_back_input(cur_tok);
            return 0;
    }
    return 1;
}

void tex_run_text_math_char_number(void) {
    mathcodeval mval = tex_no_math_code();
    mathdictval dval = tex_no_dict_code();
    if (tex_scan_math_code_val(cur_chr, &mval, &dval)) {
        tex_aux_append_math_char_in_text(mval, dval);
    }
}

void tex_run_math_math_char_number(void) {
    mathcodeval mval = tex_no_math_code();
    mathdictval dval = tex_no_dict_code();
    if (tex_scan_math_code_val(cur_chr, &mval, &dval)) {
        tex_aux_append_math_char(mval, dval, 1);
    }
}

void tex_run_math_delimiter_number(void) {
    switch (cur_chr) {
        case math_delimiter_code:
            tex_aux_append_math_char(tex_scan_delimiter_as_mathchar(tex_mathcode), tex_no_dict_code(), 0);
            break;
        case math_udelimiter_code:
            tex_aux_append_math_char(tex_scan_delimiter_as_mathchar(umath_mathcode), tex_no_dict_code(), 0);
            break;
    }
}

/*tex 
    In original \TEX\ the subtype overlaps the class. Here we are more strict: a subtype is the
    main class as in original \TEX\ but we also have overloads: main, left and right. The subtype 
    drives the rendering, the others the spacing etc. 
*/

static void tex_aux_math_math_component(halfword target, int append)
{
    quarterword subtype = unset_noad_class;
    quarterword allclass = unset_noad_class;
    halfword style = cur_list.math_style;
    int usetextfont = math_atom_no_font_option;
    reset_noad_classes(target);
    switch (cur_chr) {
        case math_component_ordinary_code:
            subtype = ordinary_noad_subtype;
            break;
        case math_component_operator_code:
            subtype = operator_noad_subtype;
            break;
        case math_component_binary_code:
            subtype = binary_noad_subtype;
            break;
        case math_component_relation_code:
            subtype = relation_noad_subtype;
            break;
        case math_component_open_code:
            subtype = open_noad_subtype;
            break;
        case math_component_close_code:
            subtype = close_noad_subtype;
            break;
        case math_component_punctuation_code:
            subtype = punctuation_noad_subtype;
            break;
        case math_component_variable_code:
            subtype = variable_noad_subtype;
            break;
        case math_component_inner_code:
            subtype = inner_noad_subtype;
            break;
        case math_component_under_code:
            subtype = under_noad_subtype;
            style = tex_math_style_variant(style, math_parameter_under_line_variant);
            break;
        case math_component_over_code:
            subtype = over_noad_subtype;
            style = tex_math_style_variant(style, math_parameter_over_line_variant);
            break;
        case math_component_fraction_code:
            subtype = fraction_noad_subtype;
            break;
        case math_component_radical_code:
            subtype = radical_noad_subtype;
            break;
        case math_component_middle_code:
            subtype = middle_noad_subtype;
            break;
        case math_component_accent_code:
            subtype = accent_noad_subtype;
            break;
        case math_component_fenced_code:
            subtype = fenced_noad_subtype;
            break;
        case math_component_ghost_code:
            subtype = ghost_noad_subtype;
            break;
        case math_component_atom_code:
            {
                halfword attrlist = null;
                while (1) {
                    switch (tex_scan_character("custnmaolprvCUSTNMAOLPRV", 0, 1, 0)) {
                        case 'a': case 'A':
                            switch (tex_scan_character("ltLT", 0, 0, 0)) {
                                case 't': case 'T':
                                    if (tex_scan_mandate_keyword("attr", 2)) {
                                        attrlist = tex_scan_attribute(attrlist);
                                    }
                                    break;
                                case 'l': case 'L':
                                    if (tex_scan_mandate_keyword("all", 2)) {
                                        allclass = (quarterword) tex_scan_math_class_number(0);
                                        if (! valid_math_class_code(allclass)) {
                                            allclass = unset_noad_class;
                                        }
                                    }
                                    break;
                                default:
                                    tex_aux_show_keyword_error("attr|all");
                                    goto DONE;
                            }
                            break;
                        case 'l': case 'L':
                            switch (tex_scan_character("ieIE", 0, 0, 0)) {
                                case 'e': case 'E':
                                    if (tex_scan_mandate_keyword("leftclass", 2)) {
                                        halfword c = tex_scan_math_class_number(0);
                                        if (! valid_math_class_code(c)) {
                                            c = ordinary_noad_subtype;
                                        }
                                        set_noad_left_class(target, c);
                                    }
                                    break;
                                case 'i': case 'I':
                                    if (tex_scan_mandate_keyword("limits", 2)) {
                                        noad_options(target) |= noad_option_limits;
                                    }
                                    break;
                                default:
                                    tex_aux_show_keyword_error("leftclass|limits");
                                    goto DONE;
                            }
                            break;
                        case 'r': case 'R':
                            if (tex_scan_mandate_keyword("rightclass", 1)) {
                                halfword c = tex_scan_math_class_number(0);
                                if (! valid_math_class_code(c)) {
                                    c = ordinary_noad_subtype;
                                }
                                set_noad_right_class(target, c);
                            }
                            break;
                        case 'c': case 'C':
                            if (tex_scan_mandate_keyword("class", 1)) {
                                subtype = (quarterword) tex_scan_math_class_number(0);
                                if (! valid_math_class_code(subtype)) {
                                    subtype = ordinary_noad_subtype;
                                }
                                set_noad_main_class(target, subtype);
                            }
                            break;
                        case 'u': case 'U':
                            /*tex A bit over the top, three steps but a push back is still worse. We can scan for 'un'. */
                            if (tex_scan_character("nN", 0, 0, 0)) {
                                switch (tex_scan_character("prPR", 0, 0, 0)) {
                                    case 'p': case 'P':
                                        if (tex_scan_mandate_keyword("unpack", 3)) {
                                            noad_options(target) |= noad_option_unpack_list;
                                        }
                                        break;
                                    case 'r': case 'R':
                                        if (tex_scan_mandate_keyword("unroll", 3)) {
                                            noad_options(target) |= noad_option_unroll_list;
                                        }
                                        break;
                                    default:
                                        tex_aux_show_keyword_error("unpack|unroll");
                                        goto DONE;
                                }
                            }
                            break;
                        case 's': case 'S':
                            if (tex_scan_mandate_keyword("source", 1)) {
                                noad_source(target) = tex_scan_int(0, NULL);
                            }
                            break;
                        case 't': case 'T':
                            if (tex_scan_mandate_keyword("textfont", 1)) {
                                usetextfont = math_atom_text_font_option;
                            }
                            break;
                        case 'm': case 'M':
                            if (tex_scan_mandate_keyword("mathfont", 1)) {
                                usetextfont = math_atom_math_font_option;
                            }
                            break;
                        case 'n': case 'N':
                            /*tex A bit over the top, three steps but a push back is still worse. We can scan for 'no'. */
                            if (tex_scan_character("oO", 0, 0, 0)) {
                                switch (tex_scan_character("loLO", 0, 0, 0)) {
                                    case 'l': case 'L':
                                        if (tex_scan_mandate_keyword("nolimits", 3)) {
                                            noad_options(target) |= noad_option_no_limits;
                                        }
                                        break;
                                    case 'o': case 'O':
                                        if (tex_scan_mandate_keyword("nooverflow", 3)) {
                                            noad_options(target) |= noad_option_no_overflow;
                                        }
                                        break;
                                    default:
                                        tex_aux_show_keyword_error("nolimits|nooverflow");
                                        goto DONE;
                                }
                            }
                            break;
                        case 'o': case 'O':
                            /* no names, just numbers, we might also do that with other noads */
                            if (tex_scan_mandate_keyword("options", 1)) {
                                noad_options(target) = tex_scan_int(0, NULL);
                            }
                            break;
                        case 'v': case 'V':
                            if (tex_scan_mandate_keyword("void", 1)) {
                                noad_options(target) |= noad_option_void;
                            }
                            break;
                        case 'p': case 'P':
                            if (tex_scan_mandate_keyword("phantom", 1)) {
                                noad_options(target) |= noad_option_phantom;
                            }
                            break;
                        default:
                            goto DONE;
                    }
                }
              DONE:
                if (attrlist) {
                    tex_attach_attribute_list_attribute(target, attrlist);
                }
                if (subtype == unset_noad_class) {
                    if (get_noad_left_class(target) != unset_noad_class && get_noad_right_class(target) != unset_noad_class) {
                        subtype = ordinary_noad_subtype;
                    } else {
                        /* mandate, maybe we will just force a keyword */
                        subtype = (quarterword) tex_scan_math_class_number(0);
                    }
                }
            }
            break;
    }
    if (! valid_math_class_code(subtype)) {
        subtype = ordinary_noad_subtype;
    }
    /*tex 
        Now we can scan for the content: 
    */
    {
        halfword content = tex_new_node(math_char_node, 0);
        noad_nucleus(target) = content;
        node_subtype(target) = subtype;
        if (append) {
            tex_tail_append(target);
        }
        tex_aux_scan_math(content, style, usetextfont, 0, 0, 0, subtype, allclass);
    }
}

void tex_run_math_math_component(void)
{
    halfword n = tex_new_node(simple_noad, ordinary_noad_subtype);
    tex_math_set_scripts_options(n);
    tex_aux_math_math_component(n, 1);
}

int tex_is_math_disc(halfword n)
{
    return
        n && node_type(n) == hlist_node && box_list(n) && node_type(box_list(n)) == disc_node &&
        disc_class(box_list(n)) != unset_disc_class && ! node_next(box_list(n));
}

halfword tex_math_make_disc(halfword d)
{
    halfword q = tex_new_node(sub_mlist_node, 0);
    halfword n = tex_new_node(simple_noad, (quarterword) disc_class(d));
    kernel_math_list(q) = d;
    noad_nucleus(n) = q;
    noad_options(n) = noad_option_unpack_list;
    return n;
}

/*tex
    Easiest is to permit all modifiers and just ignore those that make no sense. We then can
    stepwise support whatever modifier we like later on.
*/

void tex_run_math_modifier(void)
{
    halfword tail = cur_list.tail;
    if (cur_list.head != tail) {
        switch (node_type(tail)) {
            case simple_noad:
                switch (cur_chr) {
                    case adapt_to_left_modifier_code:
                        noad_options(tail) = unset_option(noad_options(tail), noad_option_adapt_to_right_size);
                        noad_options(tail) |= noad_option_adapt_to_left_size;
                        break;
                    case adapt_to_right_modifier_code:
                        noad_options(tail) = unset_option(noad_options(tail), noad_option_adapt_to_left_size);
                        noad_options(tail) |= noad_option_adapt_to_right_size;
                        break;
                    /* todo: actually this one can also be used for other types */
                    case axis_modifier_code:
                        noad_options(tail) |= noad_option_axis;
                        break;
                    case no_axis_modifier_code:
                        noad_options(tail) |= noad_option_no_axis;
                        break;
                    case phantom_modifier_code:
                        noad_options(tail) |= noad_option_phantom;
                        break;
                    case void_modifier_code:
                        noad_options(tail) |= noad_option_void;
                        break;
                    case source_modifier_code:
                        if (tex_scan_keyword("nucleus")) {
                            noad_options(tail) |= noad_option_source_on_nucleus;    
                        }
                        noad_source(tail) = tex_scan_int(0, NULL);
                        break;
                    case openup_height_modifier_code:
                        noad_options(tail) |= noad_option_openup_height;
                        noad_height(tail) = tex_scan_dimen(0, 0, 0, 0, NULL);
                        break;
                    case openup_depth_modifier_code:
                        noad_options(tail) |= noad_option_openup_depth;
                        noad_depth(tail) = tex_scan_dimen(0, 0, 0, 0, NULL);
                        break;
                    case display_limits_modifier_code:
                        noad_options(tail) = unset_option(noad_options(tail), noad_option_limits | noad_option_no_limits);
                        break;
                    case limits_modifier_code:
                        noad_options(tail) = unset_option(noad_options(tail), noad_option_no_limits);
                        noad_options(tail) |= noad_option_limits;
                        break;
                    case no_limits_modifier_code:
                        noad_options(tail) = unset_option(noad_options(tail), noad_option_limits);
                        noad_options(tail) |= noad_option_no_limits;
                        break;
                }
            default:
                switch (node_type(tail)) {
                    case accent_noad:
                        switch (cur_chr) {
                            case source_modifier_code:
                                if (tex_scan_keyword("nucleus")) {
                                    noad_options(tail) |= noad_option_source_on_nucleus;    
                                }
                                noad_source(tail) = tex_scan_int(0, NULL);
                                break;
                        }

                }
                break;
        }
    }
}

/*tex

     Delimiter fields of noads are filled in by the |scan_delimiter| routine. The first parameter
     of this procedure is the |mem| address where the delimiter is to be placed; the second tells
     if this delimiter follows |\radical| or not.

*/

static void tex_aux_scan_delimiter(halfword target, int code, int mathclass)
{
    delcodeval dval = tex_no_del_code();
    mathcodeval mval = tex_no_math_code();
    switch (code) {
        case no_mathcode:
            /* can be integrated */
            do {
                tex_get_x_token();
            } while (cur_cmd == spacer_cmd || cur_cmd == relax_cmd);
            switch (cur_cmd) {
                case letter_cmd:
                case other_char_cmd:
                    dval = tex_get_del_code(cur_chr);
                    if (tex_has_del_code(dval)) { 
                        goto REALDELIMITER;
                    } else { 
                        mval = tex_get_math_code(cur_chr);
                        goto FAKEDELIMITER;
                    }
                case delimiter_number_cmd:
                    switch (cur_chr) {
                        case math_delimiter_code:
                            /*tex |\delimiter| */
                            dval = tex_aux_scan_extdef_del_code(tex_mathcode, 1);
                            break;
                        case math_udelimiter_code:
                            /*tex |\Udelimiter| */
                            dval = tex_aux_scan_extdef_del_code(umath_mathcode, 1);
                            break;
                        default:
                            tex_confusion("scan delimiter, case 1");
                            break;
                    }
                    goto REALDELIMITER;
                case mathspec_cmd:
                    mval = tex_get_math_spec(cur_chr);
                    goto FAKEDELIMITER;
                case math_char_number_cmd:
                    switch (cur_chr) {
                        case math_char_number_code:
                            mval = tex_scan_mathchar(tex_mathcode);
                            break;
                        case math_xchar_number_code:
                            mval = tex_scan_mathchar(umath_mathcode);
                            break;
                        default:
                            tex_confusion("scan math char, case 1");
                            break;
                    }
                    goto FAKEDELIMITER;
            }
            break;
        case tex_mathcode:
            /*tex |\radical| */
            dval = tex_aux_scan_extdef_del_code(tex_mathcode, 1);
            goto REALDELIMITER;
        case umath_mathcode:
            /*tex |\Uradical| */
            dval = tex_aux_scan_extdef_del_code(umath_mathcode, 0);
            goto REALDELIMITER;
        default:
            tex_confusion("scan delimiter, case 2");
            goto REALDELIMITER;
    }
  FAKEDELIMITER:
    if (mathclass != unset_noad_class) {
        mval.class_value = (short) mathclass; 
    }
    dval.small = mval;
    dval.large = mval;
  REALDELIMITER:
    if (! target) {
        return;
    } else if (tex_has_del_code(dval)) {
        node_subtype(target) = dval.small.class_value;
        delimiter_small_family(target) = dval.small.family_value;
        delimiter_small_character(target) = dval.small.character_value;
        delimiter_large_family(target) = dval.large.family_value;
        delimiter_large_character(target) = dval.large.character_value;
    } else {
        tex_back_input(cur_tok);
        tex_handle_error(
            normal_error_type,
            "Missing delimiter (. inserted)",
            "I was expecting to see something like '(' or '\\{' or '\\}' here. Acceptable\n"
            "delimiters are characters whose \\delcode is nonnegative, or you can use\n"
            "'\\delimiter <delimiter code>'."
        );
        node_subtype(target) = unset_noad_class;
        delimiter_small_family(target) = 0;
        delimiter_small_character(target) = 0;
        delimiter_large_family(target) = 0;
        delimiter_large_character(target) = 0;
    }
    return;
}

void tex_run_math_radical(void)
{
    halfword code = cur_chr;
    fullword options = 0;
    halfword radical = tex_new_node(radical_noad, (quarterword) code);
    halfword style = yet_unset_math_style;
    halfword variant = 0; /* quad, harmless */
    halfword attrlist = null;
    tex_tail_append(radical);
    halfword top = null;
    halfword bottom = null;
    /* only kewords to UI ones? */
    while (1) {
        switch (tex_scan_character("abeswlmrhndtABESWLMRHDNT", 0, 1, 0)) {
            case 0:
                goto DONE;
            case 'a': case 'A':
                if (tex_scan_mandate_keyword("attr", 1)) {
                    attrlist = tex_scan_attribute(attrlist);
                }
                break;
            case 'b': case 'B':
                if (tex_scan_mandate_keyword("bottom", 1)) {
                    bottom = 1;
                }
                break;
            case 'e': case 'E':
                if (tex_scan_mandate_keyword("exact", 1)) {
                    options = options | noad_option_exact;
                }
                break;
            case 't': case 'T':
                if (tex_scan_mandate_keyword("top", 1)) {
                    top = 1;
                }
                break;
            case 's': case 'S':
                switch (tex_scan_character("hitoHITO", 0, 0, 0)) {
                    case 't': case 'T':
                        switch (tex_scan_character("ryRY", 0, 0, 0)) {
                            case 'y': case 'Y':
                                if (tex_scan_mandate_keyword("style", 3)) {
                                    switch (code) {
                                        case normal_radical_subtype:
                                        case radical_radical_subtype:
                                        case root_radical_subtype:
                                        case rooted_radical_subtype:
                                        case delimited_radical_subtype:
                                            style = tex_scan_math_style_identifier(1, 0);
                                            break;
                                        default:
                                            /* ignore */
                                            break;
                                    }
                                }
                                break;
                            case 'r': case 'R':
                                if (tex_scan_mandate_keyword("stretch", 3)) {
                                     options = options | noad_option_stretch;
                                }
                                break;
                            default: 
                                tex_aux_show_keyword_error("style|stretch");
                                goto DONE;
                        }
                        break;
                    case 'o': case 'O':
                        if (tex_scan_mandate_keyword("source", 2)) {
                            noad_source(radical) = tex_scan_int(0, NULL);
                        }
                        break;
                    case 'i': case 'I':
                        if (tex_scan_mandate_keyword("size", 2)) {
                            radical_size(radical) = tex_scan_int(0, NULL);
                        }
                        break;
                    case 'h': case 'H':
                        if (tex_scan_mandate_keyword("shrink", 2)) {
                             options = options | noad_option_shrink;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("style|source|stretch|shrink");
                        goto DONE;
                }
                break;
            case 'w': case 'W':
                if (tex_scan_mandate_keyword("width", 1)) {
                    noad_width(radical) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'd': case 'D':
                if (tex_scan_mandate_keyword("depth", 1)) {
                    radical_depth(radical) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'h': case 'H':
                if (tex_scan_mandate_keyword("height", 1)) {
                    radical_height(radical) = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'l': case 'L':
                if (tex_scan_mandate_keyword("left", 1)) {
                     options = options | noad_option_left;
                }
                break;
            case 'm': case 'M':
                if (tex_scan_mandate_keyword("middle", 1)) {
                    options = options | noad_option_middle;
                }
                break;
            case 'r': case 'R':
                if (tex_scan_mandate_keyword("right", 1)) {
                    options = options | noad_option_right;
                }
                break;
            case 'n': case 'N':
                if (tex_scan_mandate_keyword("nooverflow", 1)) {
                    options |= noad_option_no_overflow;
                }
                break;
            default:
                goto DONE;
        }
    }
  DONE:
    if (style == yet_unset_math_style) {
        switch (code) {
            case normal_radical_subtype:
            case radical_radical_subtype:
            case root_radical_subtype:
                variant = math_parameter_radical_variant;
                break;
            case under_delimiter_radical_subtype:
                variant = math_parameter_under_delimiter_variant;
                break;
            case over_delimiter_radical_subtype:
                variant = math_parameter_over_delimiter_variant;
                break;
            case delimiter_under_radical_subtype:
                variant = math_parameter_delimiter_under_variant;
                break;
            case delimiter_over_radical_subtype:
                variant = math_parameter_delimiter_over_variant;
                break;
            case delimited_radical_subtype:
                variant = math_parameter_radical_variant; /* math_parameter_delimited_variant */
                break;
            case h_extensible_radical_subtype:
                variant = math_parameter_h_extensible_variant;
                break;
        }
        style = variant ? tex_math_style_variant(cur_list.math_style, variant) : cur_list.math_style;
    }
    if (attrlist) {
        tex_attach_attribute_list_attribute(radical, attrlist);
    }
    noad_options(radical) = options;
    set_noad_style(radical, style);
    {
        switch (code) {
            case normal_radical_subtype:
                {
                    halfword left = tex_new_node(delimiter_node, 0);
                    radical_left_delimiter(radical) = left;
                    tex_aux_scan_delimiter(left, tex_mathcode, unset_noad_class);
                }
                break;
            case radical_radical_subtype:
            case root_radical_subtype:
            case rooted_radical_subtype:
            case delimited_radical_subtype:
                {
                    halfword left = tex_new_node(delimiter_node, 0);
                    radical_left_delimiter(radical) = left;
                    tex_aux_scan_delimiter(left, umath_mathcode, unset_noad_class);
                }
                switch (code) {
                    case rooted_radical_subtype:
                    case delimited_radical_subtype:
                        {
                            halfword right = tex_new_node(delimiter_node, 0);
                            radical_right_delimiter(radical) = right;
                            tex_aux_scan_delimiter(right, umath_mathcode, unset_noad_class);
                        }
                }
                break;
            case under_delimiter_radical_subtype:
            case over_delimiter_radical_subtype:
            case delimiter_under_radical_subtype:
            case delimiter_over_radical_subtype:
            case h_extensible_radical_subtype:
                {
                    halfword left = tex_new_node(delimiter_node, 0);
                    radical_left_delimiter(radical) = left;
                    tex_aux_scan_delimiter(left, umath_mathcode, unset_noad_class);
                }
                break;
            default:
                tex_confusion("scan math radical");
                break;
        }
        if (top) { 
            top = tex_new_node(delimiter_node, 0);
            radical_top_delimiter(radical) = top;
            tex_aux_scan_delimiter(top, umath_mathcode, unset_noad_class);
        }
        if (bottom) { 
            bottom = tex_new_node(delimiter_node, 0);
            radical_bottom_delimiter(radical) = bottom;
            tex_aux_scan_delimiter(bottom, umath_mathcode, unset_noad_class);
        }
    }
    switch (code) {
        case h_extensible_radical_subtype:
            /*tex type will change */
            {
                halfword q = tex_new_node(sub_box_node, 0);
                noad_nucleus(radical) = q;
                break;
            }
        case root_radical_subtype:
        case rooted_radical_subtype:
            {
                tex_set_saved_record(saved_radical_degree_done, radical_degree_done_save_type, 0, 0); 
                tex_set_saved_record(saved_radical_style, radical_style_save_type, 0, 0); 
                lmt_save_state.save_stack_data.ptr += saved_radical_n_of_items;
                tex_aux_push_math(math_radical_group, tex_math_style_variant(style, math_parameter_degree_variant));
                tex_scan_left_brace();
                break;
            }
        default :
            {
                halfword q = tex_new_node(math_char_node, 0);
                noad_nucleus(radical) = q;
                tex_aux_scan_math(q, tex_math_style_variant(style, variant ? variant : math_parameter_radical_variant), 0, 0, 0, 0, unset_noad_class, unset_noad_class);
                break;
            }
    }
}

void tex_finish_math_radical(void)
{
    halfword whatever = tex_new_node(sub_mlist_node, 0);
    tex_aux_unsave_math();
    if (saved_type(saved_radical_degree_done - saved_radical_n_of_items) == radical_degree_done_save_type) {
        halfword content = tex_aux_finish_math_list(null);
        halfword radical = cur_list.tail;
        kernel_math_list(whatever) = content;
        if (saved_value(saved_radical_degree_done - saved_radical_n_of_items)) {
            noad_nucleus(radical) = whatever;
            lmt_save_state.save_stack_data.ptr -= saved_radical_n_of_items;
        } else {
            halfword style = saved_value(saved_radical_style - saved_radical_n_of_items);
            radical_degree(radical) = whatever;
            tex_set_saved_record(saved_radical_degree_done - saved_radical_n_of_items, radical_degree_done_save_type, 0, 1); 
            tex_aux_push_math(math_radical_group, tex_math_style_variant(style, math_parameter_radical_variant));
            tex_scan_left_brace();     
        }
    } else {
        tex_confusion("scan radical");
    }
}

void tex_run_math_accent(void)
{
    mathcodeval t = tex_no_math_code();
    mathcodeval b = tex_no_math_code();
    mathcodeval o = tex_no_math_code();
    halfword code = cur_chr;
    halfword accent = tex_new_node(accent_noad, bothflexible_accent_subtype);
    quarterword subtype = ordinary_noad_subtype;
    halfword attrlist = null;
    if (cur_cmd == accent_cmd) {
        tex_handle_error(
            normal_error_type,
            "Please use \\mathaccent for accents in math mode",
            "I'm changing \\accent to \\mathaccent here; wish me luck. (Accents are not the\n"
            "same in formulas as they are in text.)" );
    }
    tex_tail_append(accent);
    switch (code) {
        case math_accent_code:
            /*tex |\mathaccent| */
            t = tex_scan_mathchar(tex_mathcode);
            break;
        case math_uaccent_code:
            /*tex |\Umathaccent| */
            while (1) {
                switch (tex_scan_character("abcnsftoABCNSFTO", 0, 1, 0)) {
                    case 'a': case 'A':
                        if (tex_scan_mandate_keyword("attr", 1)) {
                            attrlist = tex_scan_attribute(attrlist);
                        }
                        break;
                    case 'c': case 'C':
                        if (tex_scan_mandate_keyword("center", 1)) {
                            noad_options(accent) |= noad_option_center;
                        }
                        break;
                    case 's': case 'S':
                        if (tex_scan_mandate_keyword("source", 1)) {
                            noad_source(accent) = tex_scan_int(0, NULL);
                        }
                        break;
                    case 'f': case 'F':
                        switch (tex_scan_character("frFR", 0, 0, 0)) {
                            case 'r': case 'R':
                                if (tex_scan_mandate_keyword("fraction", 2)) {
                                    accent_fraction(accent) = tex_scan_int(0, NULL);
                                }
                                break;
                            case 'f': case 'F':
                                /*tex fixed <char> */
                                if (tex_scan_mandate_keyword("fixed", 2)) {
                                    node_subtype(accent) = fixedtop_accent_subtype;
                                    t = tex_scan_mathchar(umath_mathcode);
                                }
                                goto DONE;
                            default:
                                tex_aux_show_keyword_error("fraction|fixed");
                                goto DONE;
                        }
                    case 'n': case 'N':
                        if (tex_scan_mandate_keyword("nooverflow", 1)) {
                            /*tex 
                                Actually there never is an overflow but for consistency we do 
                                accept this key. Mayebe in the future it will be used. 
                            */
                            noad_options(accent) |= noad_option_no_overflow;
                        }
                        break;
                    case 'b': case 'B':
                        switch (tex_scan_character("aoAo", 0, 0, 0)) {
                            case 'a': case 'A':
                                if (tex_scan_mandate_keyword("base", 2)) {
                                    noad_options(accent) |= noad_option_auto_base;
                                }
                                break;
                            case 'o': case 'O':
                                /*tex bottom [fixed] <char> */
                                /*tex both [fixed] <char> [fixed] <char> */
                                if (tex_scan_character("t", 0, 0, 0)) {
                                     switch (tex_scan_character("thTH", 0, 0, 0)) {
                                         case 'h': case 'H':
                                            /*tex top bottom */
                                            if (tex_scan_keyword("fixed")) {
                                                node_subtype(accent) = fixedtop_accent_subtype;
                                            }
                                            t = tex_scan_mathchar(umath_mathcode);
                                            if (tex_scan_keyword("fixed")) {
                                                node_subtype(accent) = fixedboth_accent_subtype;
                                            }
                                            b = tex_scan_mathchar(umath_mathcode);
                                            goto DONE;
                                         case 't': case 'T':
                                             if (tex_scan_mandate_keyword("bottom", 4)) {
                                                /*tex bottom */
                                                if (tex_scan_keyword("fixed")) {
                                                    node_subtype(accent) = fixedbottom_accent_subtype;
                                                }
                                                b = tex_scan_mathchar(umath_mathcode);
                                             }
                                            goto DONE;
                                        default:
                                            tex_aux_show_keyword_error("both|bottom");
                                            goto DONE;
                                     }
                                }
                                goto DONE;
                            default:
                                tex_aux_show_keyword_error("base|both|bottom");
                                goto DONE;
                        }
                        break;
                    case 't': case 'T':
                        /*tex top [fixed] <char> */
                        if (tex_scan_mandate_keyword("top", 1)) {
                            if (tex_scan_keyword("fixed")) {
                                node_subtype(accent) = fixedtop_accent_subtype;
                            }
                            t = tex_scan_mathchar(umath_mathcode);
                        }
                        goto DONE;
                    case 'o': case 'O':
                        /*tex overlay [fixed] <char> */
                        if (tex_scan_mandate_keyword("overlay", 1)) {
                            if (tex_scan_keyword("fixed")) {
                                node_subtype(accent) = fixedtop_accent_subtype;
                            }
                            o = tex_scan_mathchar(umath_mathcode);
                        }
                        goto DONE;
                    default:
                        /*tex top <char> */
                        t = tex_scan_mathchar(umath_mathcode);
                        goto DONE;
                }
            }
        default:
            tex_confusion("scan math accent");
    }
  DONE:
    if (attrlist) {
        tex_attach_attribute_list_attribute(accent, attrlist);
    }
    if (! (t.character_value == 0 && t.family_value == 0)) {
        halfword n = tex_new_node(math_char_node, 0);
        subtype = tex_aux_set_math_char(n, &t, NULL);
        accent_top_character(accent) = n;
    }
    if (! (b.character_value == 0 && b.family_value == 0)) {
        halfword n = tex_new_node(math_char_node, 0);
        subtype = tex_aux_set_math_char(n, &b, NULL);
        accent_bottom_character(accent) = n;
    }
    if (! (o.character_value == 0 && o.family_value == 0)) {
        halfword n = tex_new_node(math_char_node, 0);
        subtype = tex_aux_set_math_char(n, &o, NULL);
        accent_middle_character(accent) = n;
    }
    {
        halfword n = tex_new_node(math_char_node, subtype);
        noad_nucleus(accent) = n;
        tex_aux_scan_math(n, tex_math_style_variant(cur_list.math_style, math_parameter_accent_variant), 0, 0, 0, 0, unset_noad_class, unset_noad_class);
    }
}

/*tex

    The routine that scans the four mlists of a |\mathchoice| is very much like the routine that
    builds discretionary nodes. Finally, the |\mathchoice| primitive creates a |choice_node|,
    which has special subfields |display_mlist|, |text_mlist|, |script_mlist|, and
    |script_script_mlist| pointing to the mlists for each style.

*/

void tex_run_math_choice(void) {
    switch (cur_chr) {
        case math_discretionary_code:
            {
                halfword n = tex_new_node(choice_node, discretionary_choice_subtype);
                choice_class(n) = unset_noad_class;
                while (1) {
                    switch (tex_scan_character("cC", 0, 1, 0)) {
                        case 0:
                            goto DONE;
                        case 'c': case 'C':
                            if (tex_scan_mandate_keyword("class", 1)) {
                                choice_class(n) = tex_scan_math_class_number(0);
                            }
                            break;
                        default:
                            goto DONE;
                    }
                }
              DONE:
                tex_tail_append(n);
                tex_set_saved_record(saved_choice_item_count, choices_count_save_type, 0, math_pre_break_choice);
                lmt_save_state.save_stack_data.ptr += saved_choice_n_of_items;
                tex_aux_push_math(math_choice_group, cur_list.math_style);
                tex_scan_left_brace();
                break;
            }
        case math_choice_code:
            /*tex |\mathchoice| */
            {
                halfword n = tex_new_node(choice_node, normal_choice_subtype);
                tex_tail_append(n);
                tex_set_saved_record(saved_choice_item_count, choices_count_save_type, 0, math_display_choice);
                lmt_save_state.save_stack_data.ptr += saved_choice_n_of_items;
                tex_aux_push_math(math_choice_group, display_style);
                tex_scan_left_brace();
                break;
            }
        case math_ustack_code:
            /*tex |\Ustack| */
            {
             // halfword m = tex_new_node(sub_mlist_node, 0); /* was for some reason a math_char_node */
                halfword m = tex_new_node(math_char_node, 0);
                halfword n = tex_new_node(simple_noad, ordinary_noad_subtype);
                halfword s = tex_math_style_variant(cur_list.math_style, math_parameter_stack_variant);
                tex_tail_append(n);
                noad_nucleus(n) = m;
                tex_scan_left_brace();
                tex_set_saved_record(saved_math_group_item_pointer, math_pointer_save_type, 0, m);
                tex_set_saved_record(saved_math_group_all_class, math_class_save_type, 0, unset_noad_class);
                lmt_save_state.save_stack_data.ptr += saved_math_group_n_of_items;
                tex_aux_push_math(math_stack_group, s);
                break;
            }
    }
}

int tex_current_math_style(void)
{
    return is_m_mode(cur_list.mode) ? cur_list.math_style : -1;
}

int tex_current_math_main_style(void)
{
    return is_m_mode(cur_list.mode) ? cur_list.math_main_style : -1;
}

void tex_finish_math_choice(void)
{
    halfword content;
    tex_aux_unsave_math();
    content = tex_aux_finish_math_list(null);
    /* We should just count and not rely on the next hackery test: */
    if (saved_type(saved_choice_item_count - saved_choice_n_of_items) == choices_count_save_type) {
        int choice = saved_value(saved_choice_item_count - saved_choice_n_of_items);
        int style = cur_list.math_style;
        switch (node_subtype(cur_list.tail)) { 
            case normal_choice_subtype:
                switch (choice) {
                    case math_display_choice:
                        choice_display_mlist(cur_list.tail) = content;
                        style = text_style;
                        break;
                    case math_text_choice:
                        choice_text_mlist(cur_list.tail) = content;
                        style = script_style;
                        break;
                    case math_script_choice:
                        choice_script_mlist(cur_list.tail) = content;
                        style = script_script_style;
                        break;
                    case math_script_script_choice:
                        choice_script_script_mlist(cur_list.tail) = content;
                        lmt_save_state.save_stack_data.ptr -= saved_choice_n_of_items;
                        return;
                }
                break;
            case discretionary_choice_subtype:
                switch (choice) {
                    case math_pre_break_choice:
                        choice_pre_break(cur_list.tail) = content;
                        style = display_style;
                        break;
                    case math_post_break_choice:
                        choice_post_break(cur_list.tail) = content;
                        style = text_style;
                        break;
                    case math_no_break_choice:
                        choice_no_break(cur_list.tail) = content;
                        style = script_style;
                        lmt_save_state.save_stack_data.ptr -= saved_choice_n_of_items;
                        return;
                }
                break;
        }
        tex_set_saved_record(saved_choice_item_count - saved_choice_n_of_items, choices_count_save_type, 0, choice + 1);
        tex_aux_push_math(math_choice_group, style);
        tex_scan_left_brace();
    } else {
        tex_confusion("scan build choices");
    }
}

void tex_finish_math_fraction(void)
{
    halfword content;
    tex_aux_unsave_math();
    content = tex_aux_finish_math_list(null);
    if (saved_type(saved_fraction_item_variant - saved_fraction_n_of_items) == fraction_variant_save_type) {
        halfword over = saved_value(saved_fraction_item_variant - saved_fraction_n_of_items);
        halfword autostyle = saved_value(saved_fraction_item_autostyle - saved_fraction_n_of_items);
        halfword userstyle = saved_value(saved_fraction_item_userstyle - saved_fraction_n_of_items);
        halfword fraction = cur_list.tail;
        set_noad_style(fraction, userstyle);
        switch (over) {
            case math_numerator_above:
                kernel_math_list(fraction_numerator(fraction)) = content;
                break;
            case math_denominator_above:
                kernel_math_list(fraction_denominator(fraction)) = content;
                lmt_save_state.save_stack_data.ptr -= saved_fraction_n_of_items;
                return;
        }
        tex_set_saved_record(saved_fraction_item_variant - saved_fraction_n_of_items, fraction_variant_save_type, 0, over + 1);
        tex_aux_push_math(math_fraction_group, autostyle);
        tex_scan_left_brace();
    } else {
        tex_confusion("scan build fraction");
    }
}

void tex_finish_math_operator(void)
{
    halfword content;
    tex_aux_unsave_math();
    content = tex_aux_finish_math_list(null);
    if (saved_type(saved_operator_item_variant - saved_operator_n_of_items) == operator_variant_save_type) {
        halfword over = saved_value(saved_operator_item_variant - saved_operator_n_of_items);
        halfword fenced = cur_list.tail;
        switch (over) {
            case math_limits_top:
                kernel_math_list(fence_delimiter_top(fenced)) = content;
                break;
            case math_limits_bottom:
                kernel_math_list(fence_delimiter_bottom(fenced)) = content;
                lmt_save_state.save_stack_data.ptr -= saved_operator_n_of_items;
                return;
        }
        tex_set_saved_record(saved_operator_item_variant - saved_operator_n_of_items, operator_variant_save_type, 0, over + 1);
        tex_aux_push_math(math_operator_group, tex_math_style_variant(cur_list.math_style, math_parameter_subscript_variant));
        tex_scan_left_brace();
    } else {
        tex_confusion("scan build operator");
    }
}

/*tex

    Subscripts and superscripts are attached to the previous nucleus by the action procedure called
    |sub_sup|.

*/

# define scripts_allowed(A) ((node_type((A)) >= simple_noad) && (node_type((A)) < fence_noad))

static halfword tex_math_double_atom(void)
{
    halfword tail = tex_new_node(simple_noad, ordinary_noad_subtype);
    halfword list = tex_new_node(sub_mlist_node, 0);
    tex_tail_append(tail);
    if (math_double_script_mode_par >= 0) { 
        node_subtype(tail) = (math_double_script_mode_par >> 16) & 0xFF;
        noad_class_left(tail) = (math_double_script_mode_par >> 8) & 0xFF;
        noad_class_right(tail) = (math_double_script_mode_par >> 0) & 0xFF;
    }
    noad_nucleus(tail) = list;
    return tail; 
}

void tex_run_math_script(void)
{
    int code = cur_chr;
    halfword tail = cur_list.tail;
    switch (cur_cmd) {
        case subscript_cmd:
            code = math_sub_script_code;
            break;
        case superscript_cmd:
            code = math_super_script_code;
            break;
    }
    switch (code) {
        case math_no_script_code:
            {
                halfword glue = tex_new_glue_node(zero_glue, conditional_math_glue);
                tex_tail_append(glue);
                tex_add_glue_option(glue, glue_option_no_auto_break);
            }
            return;
        case math_no_ruling_code:
            {
                halfword glue = tex_new_glue_node(zero_glue, rulebased_math_glue);
                tex_tail_append(glue);
                tex_add_glue_option(glue, glue_option_no_auto_break);
            }
            return;
        case math_sub_script_code:
            tex_get_token();
            if (cur_tok == underscore_token || cur_cmd == subscript_cmd) {
                tex_get_token();
                if (cur_tok == underscore_token || cur_cmd == subscript_cmd) {
                    tex_get_token();
                    if (cur_tok == underscore_token || cur_cmd == subscript_cmd) {
                        code = math_shifted_sub_pre_script_code;
                    } else {
                        tex_back_input(cur_tok);
                        code = math_shifted_sub_script_code;
                    }
                } else {
                    tex_back_input(cur_tok);
                    code = math_sub_pre_script_code;
                }
            } else {
                tex_back_input(cur_tok);
            }
            break;
        case math_super_script_code:
            tex_get_token();
            if (cur_tok == circumflex_token || cur_cmd == superscript_cmd) {
                tex_get_token();
                if (cur_tok == circumflex_token || cur_cmd == superscript_cmd) {
                    tex_get_token();
                    if (cur_tok == circumflex_token || cur_cmd == superscript_cmd) {
                        code = math_shifted_super_pre_script_code;
                    } else {
                        tex_back_input(cur_tok);
                        code = math_shifted_super_script_code;
                    }
                } else {
                    tex_back_input(cur_tok);
                    code = math_super_pre_script_code;
                }
            } else {
                tex_back_input(cur_tok);
            }
            break;
    }
    if (tail == cur_list.head || (! scripts_allowed(tail))) {
        halfword n = tex_new_node(sub_mlist_node, 0);
        tail = tex_new_node(simple_noad, ordinary_noad_subtype);
        tex_tail_append(tail);
        noad_nucleus(tail) = n;
    }
    switch (code) {
        case math_sub_script_code:
        case math_no_sub_script_code:
        case math_shifted_sub_script_code:
            {
                if (noad_subscr(tail)) {
                    tail = tex_math_double_atom();
                    if (math_double_script_mode_par < 0) { 
                        tex_handle_error(
                            normal_error_type,
                            "Double subscript",
                            "I treat 'x_1_2' essentially like 'x_1{}_2'."
                        );
                    }
                }
                switch (code) {
                    case math_no_sub_script_code:
                        noad_options(tail) |= noad_option_no_sub_script;
                        break;
                    case math_shifted_sub_script_code:
                        noad_options(tail) |= noad_option_shifted_sub_script;
                        break;
                }
                {
                    halfword n = tex_new_node(math_char_node, 0);
                    noad_subscr(tail) = n;
                    tex_aux_scan_math(n, tex_math_style_variant(cur_list.math_style, math_parameter_subscript_variant), 0, 0, 0, 1, unset_noad_class, unset_noad_class);
                    if (! noad_script_order(tail)) {
                        noad_script_order(tail) = script_subscript_first;
                    }
                }
                break;
            }
        case math_sub_pre_script_code:
        case math_no_sub_pre_script_code:
        case math_shifted_sub_pre_script_code:
            {
                if (noad_subprescr(tail)) {
                    int limitation = node_type(tail) == fraction_noad; /*tex See remark at node definition. */
                    tail = tex_math_double_atom();
                    if (math_double_script_mode_par < 0) { 
                        tex_handle_error(
                            normal_error_type,
                            limitation ? "Fractions take no pre subscript directly" : "Double pre subscript",
                            "I just ignore it; consider wrapping this element."
                        );
                    }
                }
                switch (code) {
                    case math_no_sub_pre_script_code:
                        noad_options(tail) |= noad_option_no_sub_pre_script;
                        break;
                    case math_shifted_sub_pre_script_code:
                        noad_options(tail) |= noad_option_shifted_sub_pre_script;
                        break;
                }
                {
                    halfword n = tex_new_node(math_char_node, 0);
                    noad_subprescr(tail) = n;
                    tex_aux_scan_math(n, tex_math_style_variant(cur_list.math_style, math_parameter_subscript_variant), 0, 0, 0, 1, unset_noad_class, unset_noad_class);
                }
                break;
            }
        case math_super_script_code:
        case math_no_super_script_code:
        case math_shifted_super_script_code:
            {
                if (noad_supscr(tail)) {
                    tail = tex_math_double_atom();
                    if (math_double_script_mode_par < 0) { 
                        tex_handle_error(
                            normal_error_type,
                            "Double superscript",
                            "I treat 'x^1^2' essentially like 'x^1{}^2'."
                        );
                    }
                }
                switch (code) {
                    case math_no_super_script_code:
                        noad_options(tail) |= noad_option_no_super_script;
                        break;
                    case math_shifted_super_script_code:
                        noad_options(tail) |= noad_option_shifted_super_script;
                        break;
                }
                {
                    halfword n = tex_new_node(math_char_node, 0);
                    noad_supscr(tail) = n;
                    if (! noad_script_order(tail)) {
                        noad_script_order(tail) = script_superscript_first;
                    }
                    tex_aux_scan_math(n, tex_math_style_variant(cur_list.math_style, math_parameter_superscript_variant), 0, 0, 0, 1, unset_noad_class, unset_noad_class);
                }
                break;
            }
        case math_super_pre_script_code:
        case math_no_super_pre_script_code:
        case math_shifted_super_pre_script_code:
            {
                if (noad_supprescr(tail)) {
                    int limitation = node_type(tail) == fraction_noad; /*tex See remark at node definition. */
                    tail = tex_math_double_atom();
                    if (math_double_script_mode_par < 0) { 
                        tex_handle_error(
                            normal_error_type,
                            limitation ? "Fractions take no pre superscript directly" : "Double pre superscript",
                            "I just ignore it; consider wrapping this element."
                        );
                    }
                }
                switch (code) {
                    case math_no_super_script_code:
                        noad_options(tail) |= noad_option_no_super_pre_script;
                        break;
                    case math_shifted_super_pre_script_code:
                        noad_options(tail) |= noad_option_shifted_super_pre_script;
                        break;
                }
                {
                    halfword n = tex_new_node(math_char_node, 0);
                    noad_supprescr(tail) = n;
                    tex_aux_scan_math(n, tex_math_style_variant(cur_list.math_style, math_parameter_superscript_variant), 0, 0, 0, 1, unset_noad_class, unset_noad_class);
                }
                break;
            }
        case math_prime_script_code:
            {
                if (noad_prime(tail)) {
                    tail = tex_math_double_atom();
                    if (math_double_script_mode_par < 0) { 
                        tex_handle_error(
                            normal_error_type,
                            "Double prime script",
                            "I'll add a dummy nucleus."
                        );
                    }
                }
                {
                    halfword n = tex_new_node(math_char_node, 0);
                    noad_prime(tail) = n;
                    if (! noad_script_order(tail)) {
                        noad_script_order(tail) = script_primescript_first;
                    }
                    /* maybe it's own variant */
                    tex_aux_scan_math(n, tex_math_style_variant(cur_list.math_style, math_parameter_superscript_variant), 0, 0, 0, 1, unset_noad_class, unset_noad_class);
                }
                break;
            }
    }
}

/*tex

    An operation like |\over| causes the current mlist to go into a state of suspended animation:
    |incomplete_noad| points to a |fraction_noad| that contains the mlist-so-far as its numerator,
    while the denominator is yet to come. Finally when the mlist is finished, the denominator will
    go into the incomplete fraction noad, and that noad will become the whole formula, unless it is
    surrounded by |\left| and |\right| delimiters.

    We can probably replace the |incomplete_noad_par| trickery because we can now look back in the
    list using the |alink| field. But not now.

*/

void tex_run_math_fraction(void)
{
    /*tex The type of generalized fraction we are scanning: */
    halfword code = cur_chr;
    if (cur_list.incomplete_noad) {
        /*tex Recovery code. */
        switch (code) {
            case math_above_delimited_code:
            case math_over_delimited_code:
            case math_atop_delimited_code:
            case math_u_above_delimited_code:
            case math_u_over_delimited_code:
            case math_u_atop_delimited_code:
            case math_u_skewed_delimited_code:
            case math_u_stretched_delimited_code:
                tex_aux_scan_delimiter(null, no_mathcode, unset_noad_class);
                tex_aux_scan_delimiter(null, no_mathcode, unset_noad_class);
                break;
        }
        switch (code) {
            case math_above_code:
            case math_above_delimited_code:
            case math_u_above_code:
            case math_u_above_delimited_code:
                tex_scan_dimen(0, 0, 0, 0, NULL);
                break;
        }
        /*tex This is somewhat weird, this error here. */
        tex_handle_error(
            normal_error_type,
            "Ambiguous; you need another { and }",
            "I'm ignoring this fraction specification, since I don't know whether a\n"
            "construction like 'x \\over y \\over z' means '{x \\over y} \\over z' or\n"
            "'x \\over {y \\over z}'."
        );
    } else {
        halfword fraction = tex_new_node(fraction_noad, 0);
        halfword numerator = tex_new_node(sub_mlist_node, 0);
        halfword denominator = null;
        halfword autostyle = tex_math_style_variant(cur_list.math_style, math_parameter_fraction_variant);
        halfword userstyle = -1;
        halfword attrlist = null;
        fullword options = 0;
        halfword mathclass = fraction_noad_subtype;
        halfword rulethickness = preset_rule_thickness;
        int ruledone = 0;
        fraction_h_factor(fraction) = 1000;
        fraction_v_factor(fraction) = 1000;
        switch (code) {
            case math_above_code:
            case math_above_delimited_code:
                node_subtype(fraction) = above_fraction_subtype;
                goto NEXTSTEP1;
            case math_over_code:
            case math_over_delimited_code:
                node_subtype(fraction) = over_fraction_subtype;
                goto NEXTSTEP1;
            case math_atop_code:
            case math_atop_delimited_code:
                node_subtype(fraction) = atop_fraction_subtype;
              NEXTSTEP1:
                {
                    cur_list.incomplete_noad = fraction;
                    fraction_numerator(fraction) = numerator;
                    kernel_math_list(numerator) = node_next(cur_list.head);
                    node_next(cur_list.head) = null;
                    cur_list.tail = cur_list.head;
                    cur_list.math_style = autostyle;
                    break;
                }
            case math_u_above_code:
            case math_u_above_delimited_code:
                node_subtype(fraction) = above_fraction_subtype;
                goto NEXTSTEP2;
            case math_u_over_code:
            case math_u_over_delimited_code:
                node_subtype(fraction) = over_fraction_subtype;
                goto NEXTSTEP2;
            case math_u_atop_code:
            case math_u_atop_delimited_code:
                node_subtype(fraction) = atop_fraction_subtype;
                goto NEXTSTEP2;
            case math_u_skewed_code:
            case math_u_skewed_delimited_code:
                node_subtype(fraction) = skewed_fraction_subtype;
                goto NEXTSTEP2;
            case math_u_stretched_code:
            case math_u_stretched_delimited_code:
                node_subtype(fraction) = stretched_fraction_subtype;
              NEXTSTEP2:
                {
                    cur_list.incomplete_noad = null;
                    denominator = tex_new_node(sub_mlist_node, 0);
                    tex_tail_append(fraction);
                    fraction_numerator(fraction) = numerator;
                    fraction_denominator(fraction) = denominator;
                    break;
                }
        }
        switch (code) {
            case math_u_skewed_code:
            case math_u_skewed_delimited_code:
            case math_u_stretched_code:
            case math_u_stretched_delimited_code:
                {
                    halfword q = tex_new_node(delimiter_node, 0);
                    fraction_middle_delimiter(fraction) = q;
                    tex_aux_scan_delimiter(q, no_mathcode, unset_noad_class);
                    break;
                }
        }
        switch (code) {
            case math_above_delimited_code:
            case math_over_delimited_code:
            case math_atop_delimited_code:
            case math_u_above_delimited_code:
            case math_u_over_delimited_code:
            case math_u_atop_delimited_code:
            case math_u_skewed_delimited_code:
            case math_u_stretched_delimited_code:
                {
                    halfword left = tex_new_node(delimiter_node, 0);
                    halfword right = tex_new_node(delimiter_node, 0);
                    fraction_left_delimiter(fraction) = left;
                    fraction_right_delimiter(fraction) = right;
                    tex_aux_scan_delimiter(left, no_mathcode, open_noad_subtype);
                    tex_aux_scan_delimiter(right, no_mathcode, close_noad_subtype);
                    break;
                }
        }
        switch (code) {
            /*tex We can't have keyword here because of compatibility reasons. */
            case math_above_code:
            case math_above_delimited_code:
                rulethickness = tex_scan_dimen(0, 0, 0, 0, NULL);
                break;
            case math_over_code:
            case math_over_delimited_code:
                rulethickness = preset_rule_thickness;
                break;
            case math_atop_code:
            case math_atop_delimited_code:
                break;
            /*tex
                But here we can! For practical reasons we accept the rule related options
                and in principle we cold do with one command.
            */
            case math_u_above_code:
            case math_u_above_delimited_code:
                goto OPTIONS;
            case math_u_atop_code:
            case math_u_atop_delimited_code:
            case math_u_over_code:
            case math_u_over_delimited_code:
                ruledone = 1;
                goto OPTIONS;
            case math_u_stretched_code:
            case math_u_stretched_delimited_code:
            case math_u_skewed_code:
            case math_u_skewed_delimited_code:
                ruledone = 1;
              OPTIONS:
                while (1) {
                    switch (tex_scan_character("acefhnpstvACEFHNPSTV", 0, 1, 0)) {
                        case 'a': case 'A':
                            if (tex_scan_mandate_keyword("attr", 1)) {
                                attrlist = tex_scan_attribute(attrlist);
                            }
                            break;
                        case 'c': case 'C':
                            if (tex_scan_mandate_keyword("class", 1)) {
                                halfword c = (quarterword) tex_scan_math_class_number(0);
                                if (valid_math_class_code(c)) {
                                    mathclass = c;
                                }
                            }
                            break;
                        case 'e': case 'E':
                            /* not used */
                            if (tex_scan_mandate_keyword("exact", 1)) {
                                options |= noad_option_exact;
                            }
                            break;
                        case 'p': case 'P':
                            /* not used */
                            if (tex_scan_mandate_keyword("proportional", 1)) {
                                options |= noad_option_proportional;
                            }
                            break;
                        case 'n': case 'N':
                            /*tex A bit over the top, three steps but a push back is still worse. */
                            if (tex_scan_character("oO", 0, 0, 0)) {
                                switch (tex_scan_character("aoAO", 0, 0, 0)) {
                                    case 'a': case 'A':
                                        if (tex_scan_mandate_keyword("noaxis", 3)) {
                                            options |= noad_option_no_axis;
                                        }
                                        break;
                                    case 'o': case 'O':
                                        if (tex_scan_mandate_keyword("nooverflow", 3)) {
                                            options |= noad_option_no_overflow;
                                        }
                                        break;
                                    default:
                                        tex_aux_show_keyword_error("noaxis|nooverflow");
                                        goto DONE;
                                }
                            }
                            break;
                        case 't': case 'T':
                            if (tex_scan_mandate_keyword("thickness", 1)) {
                                ruledone = 1;
                                rulethickness = tex_scan_dimen(0, 0, 0, 0, NULL);
                            }
                            break;
                        case 'f': case 'F':
                            if (tex_scan_mandate_keyword("font", 1)) {
                                ruledone = 1;
                                options |= noad_option_prefer_font_thickness;
                            }
                            break;
                        case 's': case 'S':
                            switch (tex_scan_character("toTO", 0, 0, 0)) {
                                case 't': case 'T':
                                    if (tex_scan_mandate_keyword("style", 2)) {
                                        halfword style = tex_scan_math_style_identifier(1, 0);
                                        if (denominator) {
                                            userstyle = style;
                                        } else {
                                            /* just ignore */
                                        }
                                    }
                                    break;
                                case 'o': case 'O':
                                    if (tex_scan_mandate_keyword("source", 2)) {
                                        noad_source(fraction) = tex_scan_int(0, NULL);
                                    }
                                    break;
                                default:
                                    tex_aux_show_keyword_error("style|source");
                                    goto DONE;
                            }
                            break;
                        case 'h': case 'H':
                            if (tex_scan_mandate_keyword("hfactor", 1)) {
                                fraction_h_factor(fraction) = tex_scan_int(0, NULL);
                            }
                            break;
                        case 'v': case 'V':
                            if (tex_scan_mandate_keyword("vfactor", 1)) {
                                fraction_v_factor(fraction) = tex_scan_int(0, NULL);
                            }
                            break;
                        default:
                            goto DONE;
                    }
                }
              DONE:
                if (! ruledone) {
                    rulethickness = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
        }
        fraction_rule_thickness(fraction) = rulethickness;
        noad_options(fraction) = options;
        set_noad_main_class(fraction, mathclass);
        if (attrlist) {
            tex_attach_attribute_list_attribute(fraction, attrlist);
        }
        if (denominator) {
            /*tex
                In this case we need to pick up two math groups, and after some playing around using
                a variant of choices made most sense.
            */
            tex_set_saved_record(saved_fraction_item_variant, fraction_variant_save_type, 0, math_numerator_above);
            tex_set_saved_record(saved_fraction_item_autostyle, fraction_auto_style_save_type, 0, autostyle);
            tex_set_saved_record(saved_fraction_item_userstyle, fraction_user_style_save_type, 0, userstyle);
            lmt_save_state.save_stack_data.ptr += saved_fraction_n_of_items;
            cur_list.math_flatten = 0;
            tex_aux_push_math(math_fraction_group, autostyle);
            tex_scan_left_brace();
        } else {
            /*tex
                This is the pre/post variant. Actually, this variant is the reason why math scanning
                code is somewhat complex, this |incomplete_noad| stuff.
            */
        }
    }
}

/*tex

    At the end of a math formula or subformula, the |finish_math_list| routine is called upon to
    return a halfword to the newly completed mlist, and to pop the nest back to the enclosing
    semantic level. The parameter to |finish_math_list|, if not null, points to a |fence_noad| that
    ends the current mlist; this |fence_noad| has not yet been appended.

*/

static halfword tex_aux_finish_math_list(halfword p)
{
    halfword q;
    if (cur_list.incomplete_noad) {
        halfword denominator = fraction_denominator(cur_list.incomplete_noad);
        if (denominator) {
            node_type(denominator) = sub_mlist_node;
        } else {
            denominator = tex_new_node(sub_mlist_node, 0);
            fraction_denominator(cur_list.incomplete_noad) = denominator;
            q = denominator;
        }
        kernel_math_list(denominator) = node_next(cur_list.head);
        if (p) {
            halfword numerator = fraction_numerator(cur_list.incomplete_noad);
            q = kernel_math_list(numerator);
            if ((node_type(q) != fence_noad) || (node_subtype(q) != left_fence_side) || (! cur_list.delimiter)) {
                tex_confusion("right fence");
            }
            kernel_math_list(numerator) = node_next(cur_list.delimiter);
            node_next(cur_list.delimiter) = cur_list.incomplete_noad;
            node_next(cur_list.incomplete_noad) = p;
        } else {
            q = cur_list.incomplete_noad;
        }
    } else {
        node_next(cur_list.tail) = p;
        q = node_next(cur_list.head);
    }
    tex_pop_nest();
    return q;
}

/*tex
    Here traditional \TEX\ does some flattening but it can interfrere. It is for instance needed
    in order to find the skew of an accented character which happens at the outer level but that
    bit of code now does that recursively. I need to check why the accent was flattened so we 
    keep the original code here for testing.

    A \CONTEXT\ test case: |$\tilde{x}'$| i.e.\ primes!
*/

static void tex_aux_flatten_math_list(halfword parent)
{
    halfword p = kernel_math_list(parent);
    if (p && ! node_next(p)) {
        switch (node_type(p)) {
            case simple_noad:
                {
                    // how about the options and class
                    if (! noad_has_following_scripts(p) && tex_math_has_class_option(node_subtype(p), flatten_class_option) && ! noad_source(p)) {
                        halfword n = noad_nucleus(p);
                        halfword s = parent;
                        node_type(s) = node_type(n);
                        tex_math_copy_char_data(s, n, 1);
                        tex_attach_attribute_list_copy(s, n);
                        tex_flush_node(p);
                    }
                    break;
                }
            case accent_noad:
                {
                    halfword tail = cur_list.tail;
                    if (saved_value(saved_math_group_item_pointer) == noad_nucleus(tail) && node_type(tail) == simple_noad) {
                        switch (node_subtype(tail)) {
                            case ordinary_noad_subtype:
                                tex_couple_nodes(node_prev(tail), p);
                                noad_nucleus(tail) = null;
                                noad_subscr(tail) = null;
                                noad_supscr(tail) = null;
                                noad_prime(tail) = null;
                                tex_attach_attribute_list_copy(p, tail);
                                tex_flush_node(tail);
                                cur_list.tail = p;
                                break;
                        }
                    }
                    break;
                }
        }
    }
}

/*tex

    Now at last we're ready to see what happens when a right brace occurs in a math formula. Two
    special cases are simplified here: braces are effectively removed when they surround a single
    Ord without sub- and/or superscripts, or when they surround an accent that is the nucleus of
    an Ord atom.

*/

void tex_finish_math_group(void)
{
    int old_style = cur_list.math_style;
    halfword p, parent;
    quarterword allclass; 
    tex_aux_unsave_math();
    lmt_save_state.save_stack_data.ptr -= saved_math_group_n_of_items;
    parent = saved_value(saved_math_group_item_pointer);
    allclass = (quarterword) saved_value(saved_math_group_all_class);
    node_type(parent) = sub_mlist_node; /* can be math_char_node */
    p = tex_aux_finish_math_list(null); /* this incomplete trickery */
    kernel_math_list(parent) = p;
    if (cur_list.math_flatten) {
        tex_aux_flatten_math_list(parent);
    }
    /*tex
        If needed, here we pickup a next \quote {argument}, so we sort of finish a group and reopen
        a new one. It is somewhat curious that we use a character node here.
    */
    if (allclass != unset_noad_class) {
        while (p) {
            if (node_type(p) == simple_noad) { 
             // node_subtype(p) = allclass; 
                if (get_noad_main_class(p) == unset_noad_class) {
                    set_noad_main_class(p, allclass); 
                }
                if (get_noad_left_class(p) == unset_noad_class) {
                    set_noad_left_class(p, allclass); 
                }
                if (get_noad_right_class(p) == unset_noad_class) {
                    set_noad_right_class(p, allclass); 
                }
            }
            p = node_next(p);
        }
        /* */
    }
    if (node_next(saved_value(saved_math_group_item_pointer)) > 0) {
        halfword q = tex_new_node(math_char_node, 0); /* hm */
        noad_nucleus(node_next(saved_value(saved_math_group_item_pointer))) = q;
        node_next(saved_value(saved_math_group_item_pointer)) = null;
        saved_value(saved_math_group_item_pointer) = q;
        tex_aux_scan_math(q, old_style, 0, 0, 0, 0, unset_noad_class, unset_noad_class);
        /*tex restart */
    }
}

/*tex

    We have dealt with all constructions of math mode except |\left| and |\right|, so the picture is
    completed by the following sections of the program. The |middle| feature of \ETEX\ allows one or
    several |\middle| delimiters to appear between |\left| and |\right|.

*/

void tex_run_math_fence(void)
{
    scaled ht = 0;
    scaled dp = 0;
    scaled top = 0;
    scaled bottom = 0;
    fullword options = 0;
    halfword mainclass = unset_noad_class;
    halfword leftclass = unset_noad_class;
    halfword rightclass = unset_noad_class;
    halfword source = 0;
    halfword attrlist = null;
    quarterword st = (quarterword) cur_chr;
    halfword style = cur_list.math_style;
    if (math_check_fences_par) { 
        options |= noad_option_no_check;
    }
    switch (st) {
        case left_operator_side:
        case no_fence_side:
            break;
        case extended_left_fence_side:   /*tex |\Uleft| */
            st = left_fence_side;
            break;
        case extended_middle_fence_side: /*tex |\Umiddle| */
            st = middle_fence_side;
            break;
        case extended_right_fence_side:  /*tex |\Uright| */
            st = right_fence_side;
            break;
        default :
            goto CHECK_PAIRING;
    }
    while (1) {
           /* todo: break down  */
        switch (tex_scan_character("hdanlevpcrsutbHDANLEVPCRSUTB", 0, 1, 0)) {
            case 0:
                goto CHECK_PAIRING;
            case 'a': case 'A':
                switch (tex_scan_character("uxtUXT", 0, 0, 0)) {
                    case 'u': case 'U':
                        if (tex_scan_mandate_keyword("auto", 2)) {
                            options |= noad_option_auto;
                        }
                        break;
                    case 't': case 'T':
                        if (tex_scan_mandate_keyword("attr", 2)) {
                            attrlist = tex_scan_attribute(attrlist);
                        }
                        break;
                    case 'x': case 'X':
                        if (tex_scan_mandate_keyword("axis", 2)) {
                            options |= noad_option_axis;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("auto|attr|axis");
                        goto CHECK_PAIRING;
                }
                break;
            case 'b': case 'B':
                if (tex_scan_mandate_keyword("bottom", 1)) {
                    bottom = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'd': case 'D':
                if (tex_scan_mandate_keyword("depth", 1)) {
                    dp = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'h': case 'H':
                if (tex_scan_mandate_keyword("height", 1)) {
                    ht = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 'n': case 'N':
                switch (tex_scan_character("oO", 0, 0, 0)) {
                    case 'o': case 'O':
                        switch (tex_scan_character("alcoALCO", 0, 0, 0)) {
                            case 'a': case 'A':
                                if (tex_scan_mandate_keyword("noaxis", 3)) {
                                    options |= noad_option_no_axis;
                                }
                                break;
                            case 'l': case 'L':
                                if (tex_scan_mandate_keyword("nolimits", 3)) {
                                    options = unset_option(options, noad_option_limits);
                                    options |= noad_option_no_limits;
                                }
                                break;
                            case 'c': case 'C':
                                if (tex_scan_mandate_keyword("nocheck", 3)) {
                                    options |= noad_option_no_check;
                                }
                                break;
                            case 'o': case 'O':
                                if (tex_scan_mandate_keyword("nooverflow", 3)) {
                                    options |= noad_option_no_overflow;
                                }
                                break;
                            default:
                                tex_aux_show_keyword_error("noaxis|nolimits|nocheck|nooverflow");
                                goto CHECK_PAIRING;
                        }
                        break;
                    default:
                        goto CHECK_PAIRING;
                }
                break;
            case 'l': case 'L':
                switch (tex_scan_character("ieIE", 0, 0, 0)) {
                    case 'e': case 'E':
                        if (tex_scan_mandate_keyword("leftclass", 2)) {
                            halfword c = tex_scan_math_class_number(0);
                         // if (! valid_math_class_code(c)) {
                            if (valid_math_class_code(c)) {
                                leftclass = c;
                            }
                        }
                        break;
                    case 'i': case 'I':
                        if (tex_scan_mandate_keyword("limits", 2)) {
                            options = unset_option(options, noad_option_no_limits);
                            options |= noad_option_limits;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("leftclass|limits");
                        goto CHECK_PAIRING;
                }
                break;
            case 'e': case 'E':
                if (tex_scan_mandate_keyword("exact", 1)) {
                    options |= noad_option_exact;
                }
                break;
            case 'v': case 'V':
                if (tex_scan_mandate_keyword("void", 1)) {
                    options |= noad_option_void;
                }
                break;
            case 'p': case 'P':
                if (tex_scan_mandate_keyword("phantom", 1)) {
                    options |= noad_option_phantom;
                }
                break;
            case 'c': case 'C':
                if (tex_scan_mandate_keyword("class", 1)) {
                    mainclass = tex_scan_math_class_number(0);
                }
                break;
            case 'r': case 'R':
                if (tex_scan_mandate_keyword("rightclass", 1)) {
                    halfword c = tex_scan_math_class_number(0);
                 // if (valid_math_class_code(c)) {
                    if (valid_math_class_code(c)) {
                        rightclass = c;
                    }
                }
                break;
            case 's': case 'S':
                if (tex_scan_mandate_keyword("source", 1)) {
                    source = tex_scan_int(0, NULL);
                }
                break;
            case 't': case 'T':
                if (tex_scan_mandate_keyword("top", 1)) {
                    top = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            default:
                goto CHECK_PAIRING;
        }
    }
  CHECK_PAIRING:
    switch (st) {
        case no_fence_side:
        case left_fence_side:
            break;
        case left_operator_side:
            {
                /* becomes a class option */
                int indisplay = style == display_style || style == cramped_display_style;
                /* options |= noad_option_no_check; */ /*tex Best just expect a dummy right. */
                if (! (has_option(options, noad_option_limits) || has_option(options, noad_option_no_limits))) {
                    /* otherwise we don't enter the placement function */
                    options |= indisplay ? noad_option_limits : noad_option_no_limits;
                }
            }
            break;
        default:
            if (cur_group != math_fence_group) {
                tex_aux_append_math_fence_val(tex_no_math_code(), tex_no_dict_code(), open_noad_subtype);
            }
            switch (cur_group) {
                case math_fence_group:
                    break;
                case math_inline_group:
                case math_display_group:
                case math_number_group:
                    tex_aux_scan_delimiter(null, no_mathcode, unset_noad_class);
                    if (st == middle_fence_side) {
                        tex_handle_error(
                            normal_error_type,
                            "Extra \\middle",
                            "I'm ignoring a \\middle that had no matching \\left."
                        );
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "Extra \\right",
                            "I'm ignoring a \\right that had no matching \\left."
                        );
                    }
                    break;
                default:
                    tex_off_save();
            }
    }
    /*tex
        Now we only have a no, left, middle or right case left.
    */
    {
        halfword fence = tex_new_node(fence_noad, st);
        halfword delimiter = tex_new_node(delimiter_node, 0);
        halfword autoclass = unset_noad_class;
        fence_delimiter_list(fence) = delimiter;
        noad_height(fence) = ht;
        noad_depth(fence) = dp;
        noad_options(fence) = options;
        set_noad_classes(fence, mainclass);
        if (leftclass != unset_noad_class) {
            set_noad_left_class(fence, leftclass);
        }
        if (rightclass != unset_noad_class) {
            set_noad_right_class(fence, rightclass);
        }
        noad_italic(fence) = 0;
        noad_source(fence) = source;
        /* */
        fence_top_overshoot(fence) = top;
        fence_bottom_overshoot(fence) = bottom;
        /*tex
            By setting this here, we can get rid of the hard coded values in |mlist_to_hlist| which
            sort of interfere (or at least confuse) things there. When set, the |leftclass| and
            |rightclass| settings win anyway.
        */
        if (mainclass == unset_noad_class) {
            mainclass = node_subtype(delimiter);
            if (mainclass == unset_noad_class || mainclass == ordinary_noad_subtype) {
                switch (st) {
                    case left_fence_side:
                        mainclass = open_noad_subtype;
                        break;
                    case middle_fence_side:
                        mainclass = middle_noad_subtype;
                        break;
                    case right_fence_side:
                        mainclass = close_noad_subtype;
                        break;
                }
            }
            set_noad_main_class(fence, mainclass);
        }
        /* */
        switch (st) {
            case left_fence_side:
                autoclass = open_noad_subtype;
                break;
            case middle_fence_side:
                autoclass = middle_noad_subtype; /* we need a way to overload this */
                break;
            case right_fence_side:
                autoclass = close_noad_subtype;
                break;
        }
        /* */
        tex_aux_scan_delimiter(delimiter, no_mathcode, autoclass);
        /* */
        if (attrlist) {
            tex_attach_attribute_list_attribute(fence, attrlist);
            tex_attach_attribute_list_attribute(delimiter, attrlist);
        }
        switch (st) {
            case left_fence_side:
                tex_aux_append_math_fence(fence, open_noad_subtype);
                break;
            case middle_fence_side:
                tex_aux_append_math_fence(fence, middle_noad_subtype);
                break;
            case right_fence_side:
                tex_aux_append_math_fence(fence, close_noad_subtype);
                break;
            case left_operator_side:
                {
                    halfword top = tex_new_node(sub_mlist_node, 0);
                    halfword bottom = tex_new_node(sub_mlist_node, 0);
                    fence_delimiter_top(fence) = top;
                    fence_delimiter_bottom(fence) = bottom;
                    tex_aux_push_math(math_fence_group, style);
                    node_next(cur_list.head) = fence;
                    cur_list.tail = fence;
                    cur_list.delimiter = fence;
                    tex_set_saved_record(saved_operator_item_variant, operator_variant_save_type, 0, math_limits_top);
                    lmt_save_state.save_stack_data.ptr += saved_operator_n_of_items;
                    tex_aux_push_math(math_operator_group, tex_math_style_variant(style, math_parameter_superscript_variant));
                    tex_scan_left_brace();
                }
                break;
            case no_fence_side:
                {
                    halfword n = tex_new_node(simple_noad, fenced_noad_subtype);
                    halfword l = tex_new_node(sub_mlist_node, 0);
                    tex_tail_append(n);
                    set_noad_main_class(n, mainclass); /*tex Really needed here! */
                    noad_nucleus(n) = l;
                    kernel_math_list(noad_nucleus(n)) = fence;
                }
                break;
            default:
                tex_confusion("left right fence");
                break;
        }
    }
}

/*tex

    \TEX\ gets to the following part of the program when the first |$| ending a display has been
    scanned.

*/

static void tex_aux_check_second_math_shift(void)
{
    tex_get_x_token();
    if (cur_cmd != math_shift_cmd) {
        tex_back_input(cur_tok);
        tex_handle_error(
            normal_error_type,
            "Display math should end with $$",
            "The '$' that I just saw supposedly matches a previous '$$'. So I shall assume\n"
            "that you typed '$$' both times."
        );
    }
}

static void tex_aux_check_display_math_end(void)
{
    switch (cur_chr) { 
        case end_display_math_code:
        case end_math_mode_code:
            return;
    }
    tex_handle_error(
        normal_error_type,
        "Display math should end with \\Ustopdisplaymath or \\Ustopmathmode",
        "I shall assume that you typed that."
    );
}

static void tex_aux_check_inline_math_end(void)
{
    switch (cur_chr) { 
        case end_inline_math_code:
        case end_math_mode_code:
            return;
    }
    tex_handle_error(
        normal_error_type,
        "Inline math should end with \\Ustopmath or \\Ustopmathmode",
        "I shall assume that you typed that."
    );
}

static void tex_aux_resume_after_display(void)
{
    switch (cur_group) {
        case math_display_group:
            tex_aux_unsave_math();
            cur_list.prev_graf += 3;
            tex_push_nest();
            cur_list.mode = hmode;
            cur_list.space_factor = default_space_factor;
            /*tex This needs to be intercepted in the display math start! Todo! */
            tex_tail_append(tex_new_par_node(penalty_par_subtype));
            tex_get_x_token();
            if (cur_cmd != spacer_cmd) {
                tex_back_input(cur_tok);
            }
            if (lmt_nest_state.nest_data.ptr == 1) {
                lmt_page_filter_callback(after_display_page_context, 0);
                tex_build_page();
            }
            break;
        default:    
            tex_confusion("finishing display math");
            break;
    }
}

/*tex

    The fuziest part of math mode processing occurs when a displayed formula is being centered and
    placed with an optional equation number. At this time we are in vertical mode (or internal
    vertical mode).

    \starttabulate
    \NC \type {p} \NC points to the mlist for the formula \NC \NR
    \NC \type {a} \NC is either |null| or it points to a box containing the equation number \NC \NR
    \NC \type {l} \NC is true if there was an |\leqno| (so |a| is a horizontal box) \NC \NR
    \stoptabulate

    Per 2022 we ditched display mode in \CONTEXT\ LMTX\ so the code related to display math is now
    completely frozen, if only because testing has become unreasonable. There is anyway not much more
    to do here.

*/

static void tex_aux_inject_display_skip(quarterword param, quarterword subtype)
{
    if (param > 0) {
        switch (display_skip_mode_par) {
            case display_skip_default :
            case display_skip_always :
                break;
            case display_skip_non_zero:
                if (tex_glue_is_zero(glue_parameter(param))) {
                    return;
                } else {
                    break;
                }
            case display_skip_ignore:
                return;
            default:
                /*tex > 3 reserved for future use */
                break;
        }
        tex_tail_append(tex_new_param_glue_node(param, subtype));
    }
}

static void tex_aux_finish_displayed_math(int atleft, halfword eqnumber, halfword equation)
{
    /*tex box containing the equation */
    halfword equation_box;
    /*tex width of the equation */
    scaled equation_width;
    /*tex width of the line */
    scaled line_width;
    /*tex width of equation number */
    scaled number_width;
    /*tex width of equation number plus space to separate from equation */
    scaled number_plus_gap_width;
    /*tex move the line right this much */
    scaled indent;
    /*tex displacement of equation in the line */
    scaled displacement;
    /*tex glue parameter codes for before and after */
    quarterword glue_above, glue_below;
    /*tex glue parameter subtypes for before and after */
    quarterword subtype_above, subtype_below;
    /*tex for equation numbers */
    scaled eqno_width;
    /*tex true if the math and surrounding (par) dirs are different */
    int swap_dir = math_direction_par != pre_display_direction_par;
    if (eqnumber && swap_dir) {
        atleft = ! atleft;
    }
    /* */
    lmt_packaging_state.post_adjust_tail = post_adjust_head;
    lmt_packaging_state.pre_adjust_tail = pre_adjust_head;
    lmt_packaging_state.post_migrate_tail = post_migrate_head;
    lmt_packaging_state.pre_migrate_tail = pre_migrate_head;
    /* */
    equation_box = tex_hpack(equation, 0, packing_additional, direction_unknown, holding_none_option);
    node_subtype(equation_box) = equation_list;
    attach_current_attribute_list(equation_box);
    equation = box_list(equation_box);
    /* */
    equation_width = box_width(equation_box);
    line_width = display_width_par;
    indent = display_indent_par;
    if (eqnumber) {
        number_width = box_width(eqnumber);
        eqno_width = number_width;
        number_plus_gap_width = number_width + tex_round_xn_over_d(math_eqno_gap_step_par, tex_get_math_quad_style(text_style), 1000);
        node_subtype(eqnumber) = equation_number_list;
        /*tex attach_current_attribute_list(eqno_box); */
    } else {
        number_width = 0;
        eqno_width = 0;
        number_plus_gap_width = 0;
    }
    if (equation_width + number_plus_gap_width > line_width) {
        /*tex

            The user can force the equation number to go on a separate line by causing its width to
            be zero.

        */
        if ((number_width != 0) && ((equation_width - lmt_packaging_state.total_shrink[normal_glue_order] + number_plus_gap_width <= line_width)
                || (lmt_packaging_state.total_shrink[fi_glue_order] != 0)
                || (lmt_packaging_state.total_shrink[fil_glue_order] != 0)
                || (lmt_packaging_state.total_shrink[fill_glue_order] != 0)
                || (lmt_packaging_state.total_shrink[filll_glue_order] != 0))) {
            box_list(equation_box) = null;
            tex_flush_node(equation_box);
            equation_box = tex_hpack(equation, line_width - number_plus_gap_width, packing_exactly, direction_unknown, holding_none_option);
            node_subtype(equation_box) = equation_list;
            attach_current_attribute_list(equation_box);
        } else {
            number_width = 0;
            if (equation_width > line_width) {
                box_list(equation_box) = null;
                tex_flush_node(equation_box);
                equation_box = tex_hpack(equation, line_width, packing_exactly, direction_unknown, holding_none_option);
                node_subtype(equation_box) = equation_list;
                attach_current_attribute_list(equation_box);
            }
        }
        equation_width = box_width(equation_box);
    }
    /*tex

        We try first to center the display without regard to the existence of the equation number.
        If that would make it too close (where \quote {too close} means that the space between
        display and equation number is less than the width of the equation number), we either
        center it in the remaining space or move it as far from the equation number as possible.
        The latter alternative is taken only if the display begins with glue, since we assume that
        the user put glue there to control the spacing precisely.

    */
    displacement = tex_half_scaled(line_width - equation_width);
    if ((number_width > 0) && (displacement < 2 * number_width)) {
        /*tex too close */
        displacement = tex_half_scaled(line_width - equation_width - number_width);
        /*
        if (p && !is_char_node(p) && node_type(p) == glue_node)
            d = 0;
        */ /* kind of weird this, so why not just */
        if (equation && node_type(equation) == glue_node) {
            displacement = 0;
        }
    }
    tex_tail_append(tex_new_penalty_node(pre_display_penalty_par, before_display_penalty_subtype));
    if ((displacement + indent <= pre_display_size_par) || ((cur_list.math_dir == dir_lefttoright) &&   atleft)
                                                        || ((cur_list.math_dir == dir_righttoleft) && ! atleft)) {
        /*tex not enough clearance */
        glue_above = above_display_skip_code;
        subtype_above = above_display_skip_glue;
        glue_below = below_display_skip_code;
        subtype_below = below_display_skip_glue;
    } else {
        glue_above = above_display_short_skip_code;
        subtype_above = above_display_short_skip_glue;
        glue_below = below_display_short_skip_code;
        subtype_below = below_display_short_skip_glue;
    }
    /*tex

        If the equation number is set on a line by itself, either before or after the formula, we
        append an infinite penalty so that no page break will separate the display from its number;
        and we use the same size and displacement for all three potential lines of the display,
        even though |\parshape| may specify them differently; |\leqno| on a forced single line due
        to |width=0|; it follows that |type(a) = hlist_node|.

    */
    if (eqnumber && atleft && (number_width == 0)) {
     /* if (math_direction_par == dir_lefttoright) { */
            box_shift_amount(eqnumber) = 0;
     /* } else { */
     /* } */
        tex_append_to_vlist(eqnumber, lua_key_index(equation_number), NULL);
        tex_tail_append(tex_new_penalty_node(infinite_penalty, equation_number_penalty_subtype));
    } else {
        tex_aux_inject_display_skip(glue_above, subtype_above);
    }
    if (number_width != 0) {
        scaled shift = line_width - equation_width - number_width - displacement;
        halfword move = tex_new_kern_node(shift, explicit_kern_subtype);
        if (atleft) {
            if (swap_dir) {
                if (math_direction_par == dir_lefttoright) {
                    /*tex TRT + TLT + \eqno: (swap_dir=true,  math_direction_par=TLT, l=true) */
                    halfword kern = tex_new_kern_node(shift + number_width, explicit_kern_subtype);
                    tex_try_couple_nodes(eqnumber, move);
                    tex_try_couple_nodes(move, equation_box);
                    tex_try_couple_nodes(equation_box, kern);
                } else {
                    /*tex TLT + TRT + \eqno: (swap_dir=true,  math_direction_par=TRT, l=true) */
                    tex_try_couple_nodes(eqnumber, move);
                    tex_try_couple_nodes(move, equation_box);
                }
            } else {
                halfword kern;
                if (math_direction_par == dir_lefttoright) {
                    /*tex TLT + TLT + \leqno: (swap_dir=false, math_direction_par=TLT, l=true) */
                    kern = tex_new_kern_node(shift + number_width, explicit_kern_subtype);
                } else {
                    /*tex TRT + TRT + \leqno: (swap_dir=false, math_direction_par=TRT, l=true) */
                    kern = tex_new_kern_node(shift, explicit_kern_subtype);
                }
                tex_try_couple_nodes(eqnumber, move);
                tex_try_couple_nodes(move, equation_box);
                tex_try_couple_nodes(equation_box, kern);
            }
            equation_box = eqnumber;
        } else {
            if (swap_dir) {
                if (math_direction_par == dir_lefttoright) {
                    /*tex TRT + TLT + \leqno: (swap_dir=true,  math_direction_par=TLT, l=false) */
                } else {
                    /*tex TLT + TRT + \leqno: (swap_dir=true,  math_direction_par=TRT, l=false) */
                }
                tex_try_couple_nodes(equation_box, move);
                tex_try_couple_nodes(move, eqnumber);
            } else {
                halfword kern;
                if (math_direction_par == dir_lefttoright) {
                    /*tex TLT + TLT + \eqno: (swap_dir=false, math_direction_par=TLT, l=false) */
                    kern = tex_new_kern_node(displacement, explicit_kern_subtype);
                } else {
                    /*tex TRT + TRT + \eqno: (swap_dir=false, math_direction_par=TRT, l=false) */
                    kern = tex_new_kern_node(shift + number_width, explicit_kern_subtype);
                }
                tex_try_couple_nodes(kern, equation_box);
                tex_try_couple_nodes(equation_box, move);
                tex_try_couple_nodes(move, eqnumber);
                equation_box = kern;
            }
        }
        equation_box = tex_hpack(equation_box, 0, packing_additional, direction_unknown, holding_none_option);
        node_subtype(equation_box) = equation_list; /* new */
        attach_current_attribute_list(equation_box);
        box_shift_amount(equation_box) = indent;
    } else {
        box_shift_amount(equation_box) = indent + displacement;
    }
    /* */
    if (pre_adjust_head != lmt_packaging_state.pre_adjust_tail) {
        tex_inject_adjust_list(pre_adjust_head, 1, lmt_linebreak_state.just_box, NULL);
    }
    lmt_packaging_state.pre_adjust_tail = null;
    /* Pre-migrate content (callback). */
    if (pre_migrate_head != lmt_packaging_state.pre_migrate_tail) {
        tex_append_list(pre_migrate_head, lmt_packaging_state.pre_migrate_tail);
     // if (! lmt_page_builder_state.output_active) {
     //     lmt_append_line_filter_callback(pre_migrate_append_line_context, 0);
     // }
    }
    /* */
    tex_append_to_vlist(equation_box, lua_key_index(equation), NULL); /* eqbox has the formula */
    if (eqnumber && number_width == 0 && ! atleft) {
        tex_tail_append(tex_new_penalty_node(infinite_penalty, equation_number_penalty_subtype));
     /* if (math_direction_par == dir_lefttoright) { */
            box_shift_amount(eqnumber) = indent + line_width - eqno_width ;
     /* } else { */
     /* } */
        tex_append_to_vlist(eqnumber, lua_key_index(equation_number), NULL);
        glue_below = 0; /* shouldn't this be an option */
    }
    /* */
    if (post_migrate_head != lmt_packaging_state.post_migrate_tail) {
        tex_append_list(post_migrate_head, lmt_packaging_state.post_migrate_tail);
        // if (! lmt_page_builder_state.output_active) {
        //     lmt_append_line_filter_callback(post_migrate_append_line_context, 0);
        // }
    }
    lmt_packaging_state.post_migrate_tail = null;
    if (lmt_packaging_state.post_adjust_tail) {
        if (post_adjust_head != lmt_packaging_state.post_adjust_tail) {
            tex_inject_adjust_list(post_adjust_head, 1, null, NULL);
        }
        lmt_packaging_state.post_adjust_tail = null;
    }
    /* */
    tex_tail_append(tex_new_penalty_node(post_display_penalty_par, after_display_penalty_subtype));
    tex_aux_inject_display_skip(glue_below, subtype_below);
    tex_aux_resume_after_display();
}

/*tex

    A |math_node|, which occurs only in horizontal lists, appears before and after mathematical
    formulas. The |subtype| field is |before| before the formula and |after| after it. There is a
    |surround| field, which represents the amount of surrounding space inserted by |\mathsurround|.

    As an outcome of the math upgrading sub project that Mikael Sundqvist and I undertook end 2021
    and beginning 2022 Mikael suggested penalties surrounding inline formulas so there you have it:
    |\preinlinepanelty| and |\postinlinepanelty|.

*/

void tex_run_math_shift(void) 
{
    switch (cur_group) {
        case math_inline_group:
        case math_display_group:
        case math_number_group:
            {
                /*tex box containing equation number */
                halfword eqnumber = null;
                /*tex Use |\leqno| instead of |\eqno|, we default to right. */
                int atleft = 0;
                /*tex |mmode| or |-mmode| */
                int mode = cur_list.mode;
                int mathmode = cur_list.math_mode; 
                /*tex this pops the nest, the formula */
                halfword p = tex_aux_finish_math_list(null);
                int mathleft = cur_list.math_begin;
                int mathright = cur_list.math_end;
                if (cur_cmd == math_shift_cs_cmd) { 
                    switch (cur_chr) { 
                        case begin_inline_math_code:
                        case begin_display_math_code:
                        case begin_math_mode_code:
                            tex_you_cant_error(NULL);
                            break;
                    }
                }
                if (cur_list.mode == -mode) { // todo: symbolic 
                    /*tex end of equation number */
                  AGAIN:
                    switch (cur_cmd) {
                        case math_shift_cmd:
                            tex_aux_check_second_math_shift();
                            break;
                        case end_paragraph_cmd:
                            tex_get_x_token();
                            goto AGAIN;
                        default:
                            tex_aux_check_display_math_end();
                            break;
                    }
                    tex_run_mlist_to_hlist(p, 0, text_style, unset_noad_class, unset_noad_class);
                    eqnumber = tex_hpack(node_next(temp_head), 0, packing_additional, direction_unknown, holding_none_option);
                    attach_current_attribute_list(eqnumber);
                    tex_aux_unsave_math();
                    /*tex now |cur_group = math_shift_group| */
                    lmt_save_state.save_stack_data.ptr -= saved_equation_number_n_of_items;
                    if (saved_type(saved_equation_number_item_location) == equation_number_location_save_type) {
                        atleft = saved_value(saved_equation_number_item_location) == left_location_code;
                        mode = cur_list.mode;
                        p = tex_aux_finish_math_list(null);
                    } else {
                        tex_confusion("after math");
                    }
                }
                if (mode == inline_mmode) { 
             // if (mode < 0) {
                    /*tex

                        The |unsave| is done after everything else here; hence an appearance of |\mathsurround|
                        inside of |$...$| affects the spacing at these particular |$|'s. This is consistent
                        with the conventions of |$$ ... $$|, since |\abovedisplayskip| inside a display affects
                        the space above that display.

                    */
                    halfword math = tex_new_node(math_node, begin_inline_math);
                    if (mathmode) { 
                        switch (cur_cmd) { 
                            case math_shift_cs_cmd: 
                                if (cur_chr != end_display_math_code && cur_chr != end_math_mode_code) {
                                    tex_aux_check_second_math_shift();
                                }
                                break;
                            case math_shift_cmd: 
                                tex_aux_check_second_math_shift();
                                break;
                        }
                    } else if (cur_cmd == math_shift_cs_cmd) {
                        tex_aux_check_inline_math_end();
                    }
                    tex_tail_append(math);
                    math_penalty(math) = pre_inline_penalty_par;
                    /*tex begin mathskip code */
                    switch (math_skip_mode_par) {
                        case math_skip_surround_when_zero:
                            if (! tex_glue_is_zero(math_skip_par)) {
                                tex_copy_glue_values(math, math_skip_par);
                            } else {
                                math_surround(math) = math_surround_par;
                            }
                            break ;
                        case math_skip_always_left:
                        case math_skip_always_both:
                        case math_skip_only_when_skip:
                            tex_copy_glue_values(math, math_skip_par);
                            break ;
                        case math_skip_always_right:
                        case math_skip_ignore:
                            break ;
                        case math_skip_always_surround:
                        default:
                            math_surround(math) = math_surround_par;
                            break;
                    }
                    /*tex end mathskip code */
                    if (cur_list.math_dir) {
                        tex_tail_append(tex_new_dir(normal_dir_subtype, math_direction_par)); 
                    }
                    tex_run_mlist_to_hlist(p, cur_list.mode > nomode, is_valid_math_style(cur_list.math_main_style) ?  cur_list.math_main_style : text_style, cur_list.math_begin, cur_list.math_end);
                    tex_try_couple_nodes(cur_list.tail, node_next(temp_head));
                    cur_list.tail = tex_tail_of_node_list(cur_list.tail);
                    if (cur_list.math_dir) {
                        tex_tail_append(tex_new_dir(cancel_dir_subtype, math_direction_par));
                    }
                    cur_list.math_dir = 0;
                    math = tex_new_node(math_node, end_inline_math);
                    tex_tail_append(math);
                    math_penalty(math) = post_inline_penalty_par;
                    /*tex begin mathskip code */
                    switch (math_skip_mode_par) {
                        case math_skip_surround_when_zero :
                            if (! tex_glue_is_zero(math_skip_par)) {
                                tex_copy_glue_values(math, math_skip_par);
                                math_surround(math) = 0;
                            } else {
                                math_surround(math) = math_surround_par;
                            }
                            break;
                        case math_skip_always_right:
                        case math_skip_always_both:
                        case math_skip_only_when_skip:
                            tex_copy_glue_values(math, math_skip_par);
                            break;
                        case math_skip_always_left:
                        case math_skip_ignore:
                            break;
                        case math_skip_always_surround:
                        default:
                            math_surround(math) = math_surround_par;
                            break;
                    }
                    /*tex end mathskip code */
                    cur_list.space_factor = default_space_factor;
                    mathleft = cur_list.math_begin;
                    mathright = cur_list.math_end;
                    tex_aux_unsave_math();
                } else {
                    if (! eqnumber) {
                        if (cur_cmd == math_shift_cmd) {
                            tex_aux_check_second_math_shift();
                        } else {
                            tex_aux_check_display_math_end();
                        }
                    }
                    tex_run_mlist_to_hlist(p, 0, display_style, cur_list.math_begin, cur_list.math_end);
                    mathleft = cur_list.math_begin;
                    mathright = cur_list.math_end;
                    tex_aux_finish_displayed_math(atleft, eqnumber, node_next(temp_head));
                }
                /* local */
                update_tex_math_left_class(mathleft);
                update_tex_math_right_class(mathright);
                /* global */
                lmt_math_state.last_left = mathleft;
                lmt_math_state.last_right = mathright;
            }
            break;
        default:
            tex_off_save();
            break;
    }
}

/*tex

    When |\halign| appears in a display, the alignment routines operate essentially as they do in
    vertical mode. Then the following program is activated, with |p| and |q| pointing to the
    beginning and end of the resulting list, and with |aux_save| holding the |prev_depth| value.

*/

void tex_finish_display_alignment(halfword head, halfword tail, halfword prevdepth)
{
    tex_handle_assignments();
  AGAIN:
    switch (cur_cmd) {
        case math_shift_cmd:
            tex_aux_check_second_math_shift();
            break;
        case end_paragraph_cmd:
            tex_get_x_token();
            goto AGAIN;
        default:
            tex_aux_check_display_math_end();
            break;
    }
    tex_pop_nest();
    tex_tail_append(tex_new_penalty_node(pre_display_penalty_par, before_display_penalty_subtype));
    tex_aux_inject_display_skip(above_display_skip_code, above_display_skip_glue);
    node_next(cur_list.tail) = head;
    if (head && tail) {
        cur_list.tail = tail;
    }
    tex_tail_append(tex_new_penalty_node(post_display_penalty_par, after_display_penalty_subtype));
    tex_aux_inject_display_skip(below_display_skip_code, below_display_skip_glue);
    cur_list.prev_depth = prevdepth;
    tex_aux_resume_after_display();
}

/*

    Turning macros into functions brought the mingw64 bin down from 2548224 to 2511360 bytes but
    not the linux one, so I guess mingw doesn't inline (yet, in 2020).

*/

static void tex_aux_define_inl_math_parameters(int size, int param, scaled value, int level)
{
    switch (size) {
        case script_size:
            tex_def_math_parameter(script_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_script_style, param, value, level, indirect_math_regular);
            break;
        case script_script_size:
            tex_def_math_parameter(script_script_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_script_script_style, param, value, level, indirect_math_regular);
            break;
        default:
            tex_def_math_parameter(text_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_text_style, param, value, level, indirect_math_regular);
            break;
    }
}

static void tex_aux_define_dis_math_parameters(int size, int param, scaled value, int level)
{
    if (size == text_size) {
        tex_def_math_parameter(display_style, param, value, level, indirect_math_regular);
        tex_def_math_parameter(cramped_display_style, param, value, level, indirect_math_regular);
    }
}

/*tex
    In principle we could save some storage in the format file with:

    \starttyping
    static void tex_aux_define_all_math_parameters(int size, int param, scaled value, int level)
    {
        tex_def_math_parameter(all_math_styles, param, value, level, indirect_math_regular);
    } 
    \stoptyping

    and then do this (we also need to move |all_math_styles| up in the enum to keep ranges compact):

    \starttyping
    if (! sa_get_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * style)), &item1, &item2)) {
        sa_get_item_8(lmt_math_state.par_head, (param + (math_parameter_max_range * all_math_styles)), &item1, &item2);
    }
    \stoptyping

    but in practice we actually get a bit larger file. 
*/

static void tex_aux_define_all_math_parameters(int size, int param, scaled value, int level)
{
    switch (size) {
        case script_size:
            tex_def_math_parameter(script_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_script_style, param, value, level, indirect_math_regular);
            break;
        case script_script_size:
            tex_def_math_parameter(script_script_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_script_script_style, param, value, level, indirect_math_regular);
            break;
        default:
            tex_def_math_parameter(text_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_text_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(display_style, param, value, level, indirect_math_regular);
            tex_def_math_parameter(cramped_display_style, param, value, level, indirect_math_regular);
            break;
    }
}

/*tex

    Here are the math parameters that are font-dependant. Before an mlist is converted to an hlist,
    \TEX\ makes sure that the fonts in family~2 have enough parameters to be math symbol fonts, and
    that the fonts in family~3 have enough parameters to be math extension fonts. The math-symbol
    parameters are referred to by using the following macros, which take a size code as their
    parameter; for example, |num1 (cur_size)| gives the value of the |num1| parameter for the
    current size.

    The math extension parameters have similar macros, but the size code is omitted (since it is
    always |cur_size| when we refer to such parameters).

*/

# define total_mathsy_parameters 22
# define total_mathex_parameters 13

# define mathsy(A,B) font_parameter(tex_fam_fnt(2,A),B)
# define mathex(A,B) font_parameter(tex_fam_fnt(3,A),B)

# define math_x_height(A)          mathsy(A,5)  /*tex height of |x| */
# define math_quad(A)              mathsy(A,6)  /*tex |18mu| */
# define num1(A)                   mathsy(A,8)  /*tex numerator shift-up in display styles */
# define num2(A)                   mathsy(A,9)  /*tex numerator shift-up in non-display, non-|\atop| */
# define num3(A)                   mathsy(A,10) /*tex numerator shift-up in non-display |\atop| */
# define denom1(A)                 mathsy(A,11) /*tex denominator shift-down in display styles */
# define denom2(A)                 mathsy(A,12) /*tex denominator shift-down in non-display styles */
# define sup1(A)                   mathsy(A,13) /*tex superscript shift-up in uncramped display style */
# define sup2(A)                   mathsy(A,14) /*tex superscript shift-up in uncramped non-display */
# define sup3(A)                   mathsy(A,15) /*tex superscript shift-up in cramped styles */
# define sub1(A)                   mathsy(A,16) /*tex subscript shift-down if superscript is absent */
# define sub2(A)                   mathsy(A,17) /*tex subscript shift-down if superscript is present */
# define sup_drop(A)               mathsy(A,18) /*tex superscript baseline below top of large box */
# define sub_drop(A)               mathsy(A,19) /*tex subscript baseline below bottom of large box */
# define delim1(A)                 mathsy(A,20) /*tex size of |\atopwithdelims| delimiters in display styles */
# define delim2(A)                 mathsy(A,21) /*tex size of |\atopwithdelims| delimiters in non-displays */
# define axis_height(A)            mathsy(A,22) /*tex height of fraction lines above the baseline */

# define default_rule_thickness(A) mathex(A,8)  /*tex thickness of |\over| bars */
# define big_operator_spacing1(A)  mathex(A,9)  /*tex minimum clearance above a displayed op */
# define big_operator_spacing2(A)  mathex(A,10) /*tex minimum clearance below a displayed op */
# define big_operator_spacing3(A)  mathex(A,11) /*tex minimum baselineskip above displayed op */
# define big_operator_spacing4(A)  mathex(A,12) /*tex minimum baselineskip below displayed op */
# define big_operator_spacing5(A)  mathex(A,13) /*tex padding above and below displayed limits */

/*tex
    Somehow a scale > 1000 results in extreme values.
*/

/*
inline static int tex_aux_get_font_math_parameter(scaled scale, halfword f, int id)
{
    scaled v = get_font_math_par(f, id);
//  return scale == 1000 ? v : round_xn_over_d(v, scale, 1000);
    if (v) {
        double d = 0.001 * scale * v;
        return (d < 0.0) ? (int) (d - 0.5) : (int) (d + 0.5);
    } else {
        return 0;
    }
}

inline static int tex_aux_get_font_math_quantity(scaled scale, halfword v)
{
//   return scale == 1000 ? v : round_xn_over_d(v, scale, 1000);
    if (v) {
        double d = 0.001 * scale * v;
        return (d < 0.0) ? (int) (d - 0.5) : (int) (d + 0.5);
    } else {
        return 0;
    }
}
*/

# define math_parameter(a,b) ((font_math_parameter_count(a) >= b) ? font_math_parameter(a,b) : undefined_math_parameter)

inline static scaled tex_aux_get_font_math_parameter(scaled scale, halfword f, int id)
{
    scaled v = math_parameter(f, id);
    if (v == undefined_math_parameter) {
        return v;
    } else {
        return v ? scaledround(0.001 * scale * v) : 0;
    }
}

inline static scaled tex_aux_get_font_math_quantity(scaled scale, halfword v)
{
    return v ? scaledround(0.001 * scale * v) : 0;
}

/*tex
    The next function is called when we define a family, but first we define a few helpers
    for identifying traditional math fonts. Watch the hard codes family check (gone now)!
*/

void tex_fixup_math_parameters(int fam, int size, int f, int level)
{
    scaled scale = tex_get_math_font_scale(f, size);

    if (tracing_math_par > 1) {
        tex_begin_diagnostic();
        tex_print_format("[math: fixing up font, family %i, size %i, font %i, level %i]", fam, size, f, level);
        tex_end_diagnostic();
    }

    /*tex These apply to all: */

    tex_aux_define_all_math_parameters(size, math_parameter_quad, tex_aux_get_font_math_quantity (scale, font_size(f)),  level);
    tex_aux_define_all_math_parameters(size, math_parameter_axis, tex_aux_get_font_math_parameter(scale, f, AxisHeight), level);

    tex_aux_define_all_math_parameters(size, math_parameter_accent_base_height,               tex_aux_get_font_math_parameter(scale, f, AccentBaseHeight),                  level);
    tex_aux_define_all_math_parameters(size, math_parameter_accent_base_depth,                tex_aux_get_font_math_parameter(scale, f, AccentBaseDepth),                   level); /* engine, reserved */
    tex_aux_define_all_math_parameters(size, math_parameter_flattened_accent_base_height,     tex_aux_get_font_math_parameter(scale, f, FlattenedAccentBaseHeight),         level);
    tex_aux_define_all_math_parameters(size, math_parameter_flattened_accent_base_depth,      tex_aux_get_font_math_parameter(scale, f, FlattenedAccentBaseDepth),          level); /* engine, reserved */
    tex_aux_define_all_math_parameters(size, math_parameter_overbar_kern,                     tex_aux_get_font_math_parameter(scale, f, OverbarExtraAscender),              level);
    tex_aux_define_all_math_parameters(size, math_parameter_overbar_rule,                     tex_aux_get_font_math_parameter(scale, f, OverbarRuleThickness),              level);
    tex_aux_define_all_math_parameters(size, math_parameter_overbar_vgap,                     tex_aux_get_font_math_parameter(scale, f, OverbarVerticalGap),                level);
    tex_aux_define_all_math_parameters(size, math_parameter_underbar_kern,                    tex_aux_get_font_math_parameter(scale, f, UnderbarExtraDescender),            level);
    tex_aux_define_all_math_parameters(size, math_parameter_underbar_rule,                    tex_aux_get_font_math_parameter(scale, f, UnderbarRuleThickness ),            level);
    tex_aux_define_all_math_parameters(size, math_parameter_underbar_vgap,                    tex_aux_get_font_math_parameter(scale, f, UnderbarVerticalGap),               level);
    tex_aux_define_all_math_parameters(size, math_parameter_under_delimiter_vgap,             tex_aux_get_font_math_parameter(scale, f, StretchStackGapAboveMin),           level);
    tex_aux_define_all_math_parameters(size, math_parameter_under_delimiter_bgap,             tex_aux_get_font_math_parameter(scale, f, StretchStackBottomShiftDown),       level);
    tex_aux_define_all_math_parameters(size, math_parameter_over_delimiter_vgap,              tex_aux_get_font_math_parameter(scale, f, StretchStackGapBelowMin),           level);
    tex_aux_define_all_math_parameters(size, math_parameter_over_delimiter_bgap,              tex_aux_get_font_math_parameter(scale, f, StretchStackTopShiftUp),            level);
    tex_aux_define_all_math_parameters(size, math_parameter_radical_kern,                     tex_aux_get_font_math_parameter(scale, f, RadicalExtraAscender),              level);
    tex_aux_define_all_math_parameters(size, math_parameter_radical_rule,                     tex_aux_get_font_math_parameter(scale, f, RadicalRuleThickness),              level);
    tex_aux_define_all_math_parameters(size, math_parameter_radical_degree_before,            tex_aux_get_font_math_parameter(scale, f, RadicalKernBeforeDegree),           level);
    tex_aux_define_all_math_parameters(size, math_parameter_radical_degree_after,             tex_aux_get_font_math_parameter(scale, f, RadicalKernAfterDegree),            level);
    tex_aux_define_all_math_parameters(size, math_parameter_subscript_shift_drop,             tex_aux_get_font_math_parameter(scale, f, SubscriptBaselineDropMin),          level);
    tex_aux_define_all_math_parameters(size, math_parameter_superscript_shift_drop,           tex_aux_get_font_math_parameter(scale, f, SuperscriptBaselineDropMax),        level);
    tex_aux_define_all_math_parameters(size, math_parameter_subscript_shift_down,             tex_aux_get_font_math_parameter(scale, f, SubscriptShiftDown),                level);
    tex_aux_define_all_math_parameters(size, math_parameter_prime_shift_drop,                 tex_aux_get_font_math_parameter(scale, f, PrimeBaselineDropMax),              level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_subscript_top_max,                tex_aux_get_font_math_parameter(scale, f, SubscriptTopMax),                   level);
    tex_aux_define_all_math_parameters(size, math_parameter_superscript_bottom_min,           tex_aux_get_font_math_parameter(scale, f, SuperscriptBottomMin),              level);
    tex_aux_define_all_math_parameters(size, math_parameter_superscript_subscript_bottom_max, tex_aux_get_font_math_parameter(scale, f, SuperscriptBottomMaxWithSubscript), level);
    tex_aux_define_all_math_parameters(size, math_parameter_subscript_superscript_vgap,       tex_aux_get_font_math_parameter(scale, f, SubSuperscriptGapMin),              level);
    tex_aux_define_all_math_parameters(size, math_parameter_limit_above_vgap,                 tex_aux_get_font_math_parameter(scale, f, UpperLimitGapMin),                  level);
    tex_aux_define_all_math_parameters(size, math_parameter_limit_above_bgap,                 tex_aux_get_font_math_parameter(scale, f, UpperLimitBaselineRiseMin),         level);
    tex_aux_define_all_math_parameters(size, math_parameter_limit_below_vgap,                 tex_aux_get_font_math_parameter(scale, f, LowerLimitGapMin),                  level);
    tex_aux_define_all_math_parameters(size, math_parameter_limit_below_bgap,                 tex_aux_get_font_math_parameter(scale, f, LowerLimitBaselineDropMin),         level);
    tex_aux_define_all_math_parameters(size, math_parameter_nolimit_sub_factor,               tex_aux_get_font_math_parameter(scale, f, NoLimitSubFactor),                  level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_nolimit_sup_factor,               tex_aux_get_font_math_parameter(scale, f, NoLimitSupFactor),                  level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_skewed_fraction_hgap,             tex_aux_get_font_math_parameter(scale, f, SkewedFractionHorizontalGap),       level);
    tex_aux_define_all_math_parameters(size, math_parameter_skewed_fraction_vgap,             tex_aux_get_font_math_parameter(scale, f, SkewedFractionVerticalGap),         level);
    tex_aux_define_all_math_parameters(size, math_parameter_space_before_script,              tex_aux_get_font_math_parameter(scale, f, SpaceBeforeScript),                 level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_space_after_script,               tex_aux_get_font_math_parameter(scale, f, SpaceAfterScript),                  level);
    tex_aux_define_all_math_parameters(size, math_parameter_connector_overlap_min,            tex_aux_get_font_math_parameter(scale, f, MinConnectorOverlap),               level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_fraction_rule,                    tex_aux_get_font_math_parameter(scale, f, FractionRuleThickness),             level);

    tex_aux_define_all_math_parameters(size, math_parameter_radical_degree_raise,               math_parameter(f, RadicalDegreeBottomRaisePercent), level);
    tex_aux_define_all_math_parameters(size, math_parameter_prime_raise,                        math_parameter(f, PrimeRaisePercent),               level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_prime_raise_composed,               math_parameter(f, PrimeRaiseComposedPercent),       level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_prime_space_after,                  math_parameter(f, PrimeSpaceAfter),                 level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_prime_width,                        math_parameter(f, PrimeWidthPercent),               level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_skewed_delimiter_tolerance,         math_parameter(f, SkewedDelimiterTolerance),        level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_top_shift_up,                math_parameter(f, AccentTopShiftUp),                level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_bottom_shift_down,           math_parameter(f, AccentBottomShiftDown),           level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_top_overshoot,               math_parameter(f, AccentTopOvershoot),              level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_bottom_overshoot,            math_parameter(f, AccentBottomOvershoot),           level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_superscript_drop,            math_parameter(f, AccentSuperscriptDrop),           level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_superscript_percent,         math_parameter(f, AccentSuperscriptPercent),        level); /* engine, default 0 */
    tex_aux_define_all_math_parameters(size, math_parameter_accent_extend_margin,               math_parameter(f, AccentExtendMargin),              level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_flattened_accent_top_shift_up,      math_parameter(f, FlattenedAccentTopShiftUp),       level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_flattened_accent_bottom_shift_down, math_parameter(f, FlattenedAccentBottomShiftDown),  level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_delimiter_percent,                  math_parameter(f, DelimiterPercent),                level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_delimiter_shortfall,                math_parameter(f, DelimiterShortfall),              level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_delimiter_extend_margin,            math_parameter(f, DelimiterExtendMargin),           level); /* engine, undefined */

    tex_aux_define_all_math_parameters(size, math_parameter_radical_extensible_after,           math_parameter(f, RadicalKernAfterExtensible),      level); /* engine, undefined */
    tex_aux_define_all_math_parameters(size, math_parameter_radical_extensible_before,          math_parameter(f, RadicalKernBeforeExtensible),     level); /* engine, undefined */

    /*tex Not all are official \OPENTYPE: */

    tex_aux_define_all_math_parameters(size, math_parameter_x_scale, 1000, level);
    tex_aux_define_all_math_parameters(size, math_parameter_y_scale, 1000, level);

    /*tex Most are zero and have to be set at by the macro package (if at all):. */

    tex_aux_define_all_math_parameters(size, math_parameter_limit_above_kern,              0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_limit_below_kern,              0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_superscript_shift,       0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_subscript_shift,         0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_superprescript_shift,    0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_subprescript_shift,      0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_rule_height,                   0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_rule_depth,                    0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_superscript_shift_distance,    0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_subscript_shift_distance,      0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_superprescript_shift_distance, 0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_subprescript_shift_distance,   0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_superscript_space,       0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_subscript_space,         0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_superprescript_space,    0, level);
    tex_aux_define_all_math_parameters(size, math_parameter_extra_subprescript_space,      0, level);

    /*tex A special one: */

    if (math_parameter(f, SubscriptShiftDownWithSuperscript) != undefined_math_parameter) { /* engine */
        tex_aux_define_all_math_parameters(size, math_parameter_subscript_superscript_shift_down, tex_aux_get_font_math_parameter(scale, f, SubscriptShiftDownWithSuperscript), level);
    } else {
        tex_aux_define_all_math_parameters(size, math_parameter_subscript_superscript_shift_down, tex_aux_get_font_math_parameter(scale, f, SubscriptShiftDown),                level);
    }

    /*tex These differentiate between display and inline: */

    tex_aux_define_dis_math_parameters(size, math_parameter_operator_size,       tex_aux_get_font_math_parameter(scale, f, DisplayOperatorMinHeight),                 level);
    tex_aux_define_inl_math_parameters(size, math_parameter_radical_vgap,        tex_aux_get_font_math_parameter(scale, f, RadicalVerticalGap),                       level);
    tex_aux_define_dis_math_parameters(size, math_parameter_radical_vgap,        tex_aux_get_font_math_parameter(scale, f, RadicalDisplayStyleVerticalGap),           level);
    tex_aux_define_inl_math_parameters(size, math_parameter_stack_num_up,        tex_aux_get_font_math_parameter(scale, f, StackTopShiftUp),                          level);
    tex_aux_define_dis_math_parameters(size, math_parameter_stack_num_up,        tex_aux_get_font_math_parameter(scale, f, StackTopDisplayStyleShiftUp),              level);
    tex_aux_define_inl_math_parameters(size, math_parameter_stack_denom_down,    tex_aux_get_font_math_parameter(scale, f, StackBottomShiftDown),                     level);
    tex_aux_define_dis_math_parameters(size, math_parameter_stack_denom_down,    tex_aux_get_font_math_parameter(scale, f, StackBottomDisplayStyleShiftDown),         level);
    tex_aux_define_inl_math_parameters(size, math_parameter_stack_vgap,          tex_aux_get_font_math_parameter(scale, f, StackGapMin),                              level);
    tex_aux_define_dis_math_parameters(size, math_parameter_stack_vgap,          tex_aux_get_font_math_parameter(scale, f, StackDisplayStyleGapMin),                  level);
    tex_aux_define_inl_math_parameters(size, math_parameter_fraction_num_vgap,   tex_aux_get_font_math_parameter(scale, f, FractionNumeratorGapMin),                  level);
    tex_aux_define_dis_math_parameters(size, math_parameter_fraction_num_vgap,   tex_aux_get_font_math_parameter(scale, f, FractionNumeratorDisplayStyleGapMin),      level);
    tex_aux_define_inl_math_parameters(size, math_parameter_fraction_num_up,     tex_aux_get_font_math_parameter(scale, f, FractionNumeratorShiftUp),                 level);
    tex_aux_define_dis_math_parameters(size, math_parameter_fraction_num_up,     tex_aux_get_font_math_parameter(scale, f, FractionNumeratorDisplayStyleShiftUp),     level);
    tex_aux_define_inl_math_parameters(size, math_parameter_fraction_denom_vgap, tex_aux_get_font_math_parameter(scale, f, FractionDenominatorGapMin),                level);
    tex_aux_define_dis_math_parameters(size, math_parameter_fraction_denom_vgap, tex_aux_get_font_math_parameter(scale, f, FractionDenominatorDisplayStyleGapMin),    level);
    tex_aux_define_inl_math_parameters(size, math_parameter_fraction_denom_down, tex_aux_get_font_math_parameter(scale, f, FractionDenominatorShiftDown),             level);
    tex_aux_define_dis_math_parameters(size, math_parameter_fraction_denom_down, tex_aux_get_font_math_parameter(scale, f, FractionDenominatorDisplayStyleShiftDown), level);
    tex_aux_define_inl_math_parameters(size, math_parameter_fraction_del_size,   tex_aux_get_font_math_parameter(scale, f, FractionDelimiterSize),                    level); /* engine, undefined */
    tex_aux_define_dis_math_parameters(size, math_parameter_fraction_del_size,   tex_aux_get_font_math_parameter(scale, f, FractionDelimiterDisplayStyleSize),        level); /* engine, undefined */

    /*tex A few more specials: */

    switch (size) {
        case script_size:
            tex_def_math_parameter(script_style,         math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUp),        level, indirect_math_regular);
            tex_def_math_parameter(cramped_script_style, math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUpCramped), level, indirect_math_regular);
            tex_def_math_parameter(script_style,         math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUp),              level, indirect_math_regular); /* engine, default 0 */
            tex_def_math_parameter(cramped_script_style, math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUpCramped),       level, indirect_math_regular); /* engine, default 0 */
            break;
        case script_script_size:
            tex_def_math_parameter(script_script_style,         math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUp),        level, indirect_math_regular);
            tex_def_math_parameter(cramped_script_script_style, math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUpCramped), level, indirect_math_regular);
            tex_def_math_parameter(script_script_style,         math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUp),              level, indirect_math_regular); /* engine, default 0 */
            tex_def_math_parameter(cramped_script_script_style, math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUpCramped),       level, indirect_math_regular); /* engine, default 0 */
            break;
        default:
            tex_def_math_parameter(display_style,         math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUp),        level, indirect_math_regular);
            tex_def_math_parameter(cramped_display_style, math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUpCramped), level, indirect_math_regular);
            tex_def_math_parameter(text_style,            math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUp),        level, indirect_math_regular);
            tex_def_math_parameter(cramped_text_style,    math_parameter_superscript_shift_up, tex_aux_get_font_math_parameter(scale, f, SuperscriptShiftUpCramped), level, indirect_math_regular);
            tex_def_math_parameter(display_style,         math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUp),              level, indirect_math_regular); /* engine, default 0 */
            tex_def_math_parameter(cramped_display_style, math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUpCramped),       level, indirect_math_regular); /* engine, default 0 */
            tex_def_math_parameter(text_style,            math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUp),              level, indirect_math_regular); /* engine, default 0 */
            tex_def_math_parameter(cramped_text_style,    math_parameter_prime_shift_up,       tex_aux_get_font_math_parameter(scale, f, PrimeShiftUpCramped),       level, indirect_math_regular); /* engine, default 0 */
            break;
    }

}

/*tex

    There is some trickery here. The values are actually pointers and in \LUATEX\ the predefined
    muglue ones are small numbers that are way below the normal node values. So, they are kind
    of save signals. However, in \LUAMETATEX\ we use zero based internal codes (because that is
    nicer for the interface.

*/

void tex_set_display_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    tex_def_math_parameter(display_style,         code, value, level, indirect);
    tex_def_math_parameter(cramped_display_style, code, value, level, indirect);
}

void tex_set_text_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    tex_def_math_parameter(text_style,         code, value, level, indirect);
    tex_def_math_parameter(cramped_text_style, code, value, level, indirect);
}

void tex_set_main_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    for (int style = display_style; style <= cramped_text_style; style++) {
        tex_def_math_parameter(style, code, value, level, indirect);
    }
}

void tex_set_script_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    tex_def_math_parameter(script_style,         code, value, level, indirect);
    tex_def_math_parameter(cramped_script_style, code, value, level, indirect);
}

void tex_set_script_script_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    tex_def_math_parameter(script_script_style,         code, value, level, indirect);
    tex_def_math_parameter(cramped_script_script_style, code, value, level, indirect);
}

void tex_set_all_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    for (int style = display_style; style <= cramped_script_script_style; style++) {
        tex_def_math_parameter(style, code, value, level, indirect);
    }
}

void tex_set_uncramped_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    for (int style = display_style; style <= script_script_style; style += 2) {
        tex_def_math_parameter(style, code, value, level, indirect);
    }
}

void tex_set_cramped_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    for (int style = cramped_display_style; style <= cramped_script_script_style; style += 2) {
        tex_def_math_parameter(style, code, value, level, indirect);
    }
}

void tex_set_split_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    tex_set_display_styles      (code, value, level, indirect);
    tex_set_text_styles         (code, value, level, indirect);
    tex_set_script_styles       (code, 0,     level, indirect);
    tex_set_script_script_styles(code, 0,     level, indirect);
}

void tex_set_unsplit_styles(halfword code, halfword value, halfword level, halfword indirect)
{
    tex_set_script_styles       (code, value, level, indirect);
    tex_set_script_script_styles(code, value, level, indirect);
}

void tex_reset_all_styles(halfword level)
{
    for (int code = math_parameter_atom_pairs_first; code <= math_parameter_atom_pairs_last; code++) {
        tex_set_all_styles(code, zero_mu_skip_code, level, indirect_math_unset);
    }
}

inline static halfword tex_aux_math_class_default(halfword mathclass) {
    return (mathclass << 24) + (mathclass << 16) + (mathclass << 8) + mathclass;
}

inline static void tex_set_math_class_default(halfword mathclass, halfword parent, halfword options)
{
    tex_word_define(0, internal_int_location(first_math_class_code   + mathclass), tex_aux_math_class_default(parent));
    tex_word_define(0, internal_int_location(first_math_atom_code    + mathclass), tex_aux_math_class_default(mathclass));
    tex_word_define(0, internal_int_location(first_math_options_code + mathclass), options);
    tex_word_define(0, internal_int_location(first_math_parent_code  + mathclass), tex_aux_math_class_default(mathclass));
}

static void tex_aux_set_math_atom_rule(halfword left, halfword right, halfword newleft, halfword newright)
{
    tex_set_all_styles(math_parameter_rules_pair(left, right), (newleft << 16) + newright, level_one, indirect_math_regular);
}

void tex_initialize_math_spacing(void)
{

    for (int mathclass = 0; mathclass <= max_math_class_code; mathclass++) {
        tex_set_math_class_default(mathclass, mathclass, no_class_options);
        /*tex We do this here as there is no real need for yet another initializer. */
        tex_word_define(0, internal_int_location(first_math_pre_penalty_code  + mathclass), infinite_penalty);
        tex_word_define(0, internal_int_location(first_math_post_penalty_code + mathclass), infinite_penalty);
        tex_word_define(0, internal_int_location(first_math_display_pre_penalty_code  + mathclass), infinite_penalty);
        tex_word_define(0, internal_int_location(first_math_display_post_penalty_code + mathclass), infinite_penalty);
    }

    tex_reset_all_styles(level_one);
    
    tex_set_math_class_default(ordinary_noad_subtype,    ordinary_noad_subtype,    no_italic_correction_class_option | 
                                                                                   check_ligature_class_option | 
                                                                                   check_kern_pair_class_option | 
                                                                                   flatten_class_option);
    tex_set_math_class_default(operator_noad_subtype,    operator_noad_subtype,    check_ligature_class_option |
                                                                                   check_kern_pair_class_option);
    tex_set_math_class_default(binary_noad_subtype,      binary_noad_subtype,      no_italic_correction_class_option | 
                                                                                   check_ligature_class_option | 
                                                                                   check_kern_pair_class_option | 
                                                                                   flatten_class_option);
    tex_set_math_class_default(relation_noad_subtype,    relation_noad_subtype,    no_italic_correction_class_option | 
                                                                                   check_ligature_class_option | 
                                                                                   check_kern_pair_class_option | 
                                                                                   flatten_class_option | 
                                                                                   omit_penalty_class_option);
    tex_set_math_class_default(open_noad_subtype,        open_noad_subtype,        no_italic_correction_class_option | 
                                                                                /* open_fence_class_option | */
                                                                                   check_ligature_class_option |
                                                                                   check_kern_pair_class_option); 
    tex_set_math_class_default(close_noad_subtype,       close_noad_subtype,       no_italic_correction_class_option | 
                                                                                /* close_fence_class_option | */
                                                                                   check_ligature_class_option |
                                                                                   check_kern_pair_class_option); 
    tex_set_math_class_default(punctuation_noad_subtype, punctuation_noad_subtype, no_italic_correction_class_option | 
                                                                                   check_ligature_class_option | 
                                                                                   check_kern_pair_class_option | 
                                                                                   flatten_class_option);
    tex_set_math_class_default(variable_noad_subtype,    ordinary_noad_subtype,    no_italic_correction_class_option);
    tex_set_math_class_default(active_noad_subtype,      ordinary_noad_subtype,    no_italic_correction_class_option);
    tex_set_math_class_default(inner_noad_subtype,       inner_noad_subtype,       flatten_class_option);
    tex_set_math_class_default(under_noad_subtype,       ordinary_noad_subtype,    no_class_options);
    tex_set_math_class_default(over_noad_subtype,        ordinary_noad_subtype,    no_class_options);
    tex_set_math_class_default(fraction_noad_subtype,    ordinary_noad_subtype,    no_class_options);
    tex_set_math_class_default(radical_noad_subtype,     ordinary_noad_subtype,    no_class_options);
    tex_set_math_class_default(middle_noad_subtype,      open_noad_subtype,        no_italic_correction_class_option); /* | middle_fence_class_option= */
    tex_set_math_class_default(accent_noad_subtype,      ordinary_noad_subtype,    no_class_options);
    tex_set_math_class_default(fenced_noad_subtype,      inner_noad_subtype   ,    no_class_options);
    tex_set_math_class_default(ghost_noad_subtype,       ordinary_noad_subtype,    no_class_options);
    tex_set_math_class_default(vcenter_noad_subtype,     ordinary_noad_subtype,    no_class_options);

    tex_aux_set_math_atom_rule(math_begin_class,         binary_noad_subtype,      ordinary_noad_subtype,    ordinary_noad_subtype);
    tex_aux_set_math_atom_rule(binary_noad_subtype,      math_end_class,           ordinary_noad_subtype,    ordinary_noad_subtype);

    tex_aux_set_math_atom_rule(binary_noad_subtype,      binary_noad_subtype,      binary_noad_subtype,      ordinary_noad_subtype);
    tex_aux_set_math_atom_rule(operator_noad_subtype,    binary_noad_subtype,      operator_noad_subtype,    ordinary_noad_subtype);
    tex_aux_set_math_atom_rule(open_noad_subtype,        binary_noad_subtype,      open_noad_subtype,        ordinary_noad_subtype);
    tex_aux_set_math_atom_rule(punctuation_noad_subtype, binary_noad_subtype,      punctuation_noad_subtype, ordinary_noad_subtype);
    tex_aux_set_math_atom_rule(relation_noad_subtype,    binary_noad_subtype,      relation_noad_subtype,    ordinary_noad_subtype);

    tex_aux_set_math_atom_rule(binary_noad_subtype,      close_noad_subtype,       ordinary_noad_subtype,    close_noad_subtype);
    tex_aux_set_math_atom_rule(binary_noad_subtype,      punctuation_noad_subtype, ordinary_noad_subtype,    punctuation_noad_subtype);
    tex_aux_set_math_atom_rule(binary_noad_subtype,      relation_noad_subtype,    ordinary_noad_subtype,    relation_noad_subtype);

    tex_aux_set_math_atom_rule(relation_noad_subtype,    close_noad_subtype,       ordinary_noad_subtype,    close_noad_subtype);
    tex_aux_set_math_atom_rule(relation_noad_subtype,    punctuation_noad_subtype, ordinary_noad_subtype,    punctuation_noad_subtype);

    /* */

//    math_parameter_spacing_pair(ordinary_noad_subtype,ordinary_noad_subtype)

    tex_set_all_styles   (math_parameter_spacing_pair(ordinary_noad_subtype,    operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(ordinary_noad_subtype,    binary_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(ordinary_noad_subtype,    relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(ordinary_noad_subtype,    inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_all_styles   (math_parameter_spacing_pair(operator_noad_subtype,    ordinary_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_spacing_pair(operator_noad_subtype,    operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(operator_noad_subtype,    relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(operator_noad_subtype,    inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_all_styles   (math_parameter_spacing_pair(operator_noad_subtype,    fraction_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_spacing_pair(operator_noad_subtype,    radical_noad_subtype),     thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_spacing_pair(fraction_noad_subtype,    operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_spacing_pair(radical_noad_subtype,     operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      ordinary_noad_subtype),    med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      operator_noad_subtype),    med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      open_noad_subtype),        med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      inner_noad_subtype),       med_mu_skip_code,   level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      middle_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      fraction_noad_subtype),    med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(binary_noad_subtype,      radical_noad_subtype),     med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(middle_noad_subtype,      binary_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(fraction_noad_subtype,    binary_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(radical_noad_subtype,     binary_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    ordinary_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    operator_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    open_noad_subtype),        thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    inner_noad_subtype),       thick_mu_skip_code, level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    middle_noad_subtype),      thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    fraction_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(relation_noad_subtype,    radical_noad_subtype),     thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(middle_noad_subtype,      relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(fraction_noad_subtype,    relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(radical_noad_subtype,     relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);

    tex_set_all_styles   (math_parameter_spacing_pair(close_noad_subtype,       operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(close_noad_subtype,       binary_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(close_noad_subtype,       relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(close_noad_subtype,       inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, ordinary_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, relation_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, open_noad_subtype),        thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, close_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, punctuation_noad_subtype), thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, fraction_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, middle_noad_subtype),      thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(punctuation_noad_subtype, radical_noad_subtype),     thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(fraction_noad_subtype,    punctuation_noad_subtype), thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(middle_noad_subtype,      punctuation_noad_subtype), thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(radical_noad_subtype,     punctuation_noad_subtype), thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       ordinary_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_spacing_pair(inner_noad_subtype,       operator_noad_subtype),    thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       binary_noad_subtype),      med_mu_skip_code,   level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       relation_noad_subtype),    thick_mu_skip_code, level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       open_noad_subtype),        thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       punctuation_noad_subtype), thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);

    tex_set_split_styles (math_parameter_spacing_pair(inner_noad_subtype,       middle_noad_subtype),      thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(fraction_noad_subtype,    inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(radical_noad_subtype,     inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(middle_noad_subtype,      inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(fraction_noad_subtype,    inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);
    tex_set_split_styles (math_parameter_spacing_pair(radical_noad_subtype,     inner_noad_subtype),       thin_mu_skip_code,  level_one, indirect_math_regular);

    /* */

    tex_set_all_styles   (math_parameter_x_scale, 1000, level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_y_scale, 1000, level_one, indirect_math_regular);

    /* could be initialize_math_defaults */

    tex_set_all_styles   (math_parameter_over_line_variant,       math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_under_line_variant,      math_normal_style_variant,       level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_over_delimiter_variant,  math_small_style_variant,        level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_under_delimiter_variant, math_small_style_variant,        level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_delimiter_over_variant,  math_normal_style_variant,       level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_delimiter_under_variant, math_normal_style_variant,       level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_h_extensible_variant,    math_normal_style_variant,       level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_v_extensible_variant,    math_normal_style_variant,       level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_fraction_variant,        math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_radical_variant,         math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_degree_variant,          math_double_superscript_variant, level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_accent_variant,          math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_top_accent_variant,      math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_bottom_accent_variant,   math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_overlay_accent_variant,  math_cramped_style_variant,      level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_numerator_variant,       math_numerator_style_variant,    level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_denominator_variant,     math_denominator_style_variant,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_superscript_variant,     math_superscript_style_variant,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_subscript_variant,       math_subscript_style_variant,    level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_prime_variant,           math_superscript_style_variant,  level_one, indirect_math_regular);
    tex_set_all_styles   (math_parameter_stack_variant,           math_numerator_style_variant,    level_one, indirect_math_regular);
}

/*tex

    This needs to be called just at the start of |mlist_to_hlist|, for backward compatibility with
    |\scriptspace|.

*/

void tex_finalize_math_parameters(void)
{
    int saved_trace = tracing_assigns_par;
    tracing_assigns_par = 0;
    if (tex_get_math_parameter(display_style,               math_parameter_space_after_script, NULL) == undefined_math_parameter) {
        tex_def_math_parameter(display_style,               math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(text_style,                  math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(script_style,                math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(script_script_style,         math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(cramped_display_style,       math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(cramped_text_style,          math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(cramped_script_style,        math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
        tex_def_math_parameter(cramped_script_script_style, math_parameter_space_after_script, script_space_par, level_one, indirect_math_regular);
    }
    tracing_assigns_par = saved_trace;
}

static void tex_aux_math_parameter_error(int style, int param, const char *name)
{
    if (param >= 0) {
        tex_handle_error(
            normal_error_type,
            "Math error: parameter '%s' with id %i in style %i is not set", 
            name, param, style,
            "Sorry, but I can't typeset math unless various parameters have been set. This is\n"
            "normally done by loading special math fonts into the math family slots. Your font\n"
            "set is lacking at least the parameter mentioned earlier."
        );
    } else {
        tex_formatted_error("math", "invalid parameter '%s' in style %i", name, style);
    }
    return;
}

/*tex
    For the moment this is experimental.
*/

inline static scaled tex_aux_max_scale(int style, int param)
{
    scaled scale = tex_get_math_parameter(style, param, NULL);
    if (scale > 5000) {
        return 5000;
    } else if (scale < 0) {
        return 0;
    } else {
        return scale;
    }
}

/*tex

    The non-staticness of this function is for the benefit of |texmath.w|. Watch out, this one
    uses the style! The style and size numbers don't match because we have cramped styles.

*/

scaled tex_get_math_quad_style(int style)
{
    scaled scale = tex_aux_max_scale(style, math_parameter_x_scale);
    scaled value = tex_get_math_parameter(style, math_parameter_quad, NULL);
    if (value == undefined_math_parameter) {
        tex_aux_math_parameter_error(style, -1, "quad");
        return 0;
    } else {
        return scaledround(0.001 * value * scale);
    }
}

/*tex

    For this reason the next one is different because it is called with a size specifier instead
    of a style specifier.

*/

scaled tex_math_axis_size(int size)
{
    scaled value;
    switch (size) {
        case script_size       : size = script_style;        break;
        case script_script_size: size = script_script_style; break;
        default                : size = text_style;          break;
    }
    value = tex_get_math_parameter(size, math_parameter_axis, NULL);
    if (value == undefined_math_parameter) {
        tex_aux_math_parameter_error(size, -1, "axis");
        return 0;
    } else {
        return value;
    }
}

scaled tex_get_math_quad_size(int size) /* used in degree before and after */
{
    switch (size) {
        case script_size       : size = script_style;        break;
        case script_script_size: size = script_script_style; break;
        default                : size = text_style;          break;
    }
    return tex_get_math_parameter(size, math_parameter_quad, NULL);
}

scaled tex_get_math_quad_size_scaled(int size) /* used in cur_mu */
{
    scaled value, scale;
    switch (size) {
        case script_size       : size = script_style;        break;
        case script_script_size: size = script_script_style; break;
        default                : size = text_style;          break;
    }
    value = tex_get_math_parameter(size, math_parameter_quad, NULL);
    scale = tex_aux_max_scale(size, math_parameter_x_scale);
 /* return tex_x_over_n(scaledround(0.001 * value * scale), 18); */
    return scaledround(0.001 * value * scale / 18.0);
}

static int tex_aux_math_parameter_okay(int param) 
{
    if (ignore_math_parameter(param)) {
        if (tracing_math_par > 1) {
            tex_begin_diagnostic();
            tex_print_format("[math: parameter, name %s, ignored]", lmt_name_of_math_parameter(param));
            tex_end_diagnostic();
        }
        return 0;
    } else { 
        return 1; 
    }
}

scaled tex_get_math_parameter_checked(int style, int param)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            tex_aux_math_parameter_error(style, param, lmt_name_of_math_parameter(param));
            return 0;
        } else {
            return value;
        }
    } else {
        return 0;
    }
}

scaled tex_get_math_parameter_default(int style, int param, scaled dflt)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            return dflt;
        } else {
            return value;
        }
    } else {
        return dflt;
    }
}

void tex_run_math_italic_correction(void) {
    tex_tail_append(tex_new_kern_node(0, explicit_kern_subtype)); /* maybe math_shape_kern */
}

/* */

scaled tex_get_math_x_parameter(int style, int param)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled scale = tex_aux_max_scale(style, math_parameter_x_scale);
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            return value;  // ?? scaledround(value * scale * 0.001);
        } else {
            return value ? scaledround(0.000000001 * glyph_scale_par * glyph_x_scale_par * value * scale) : 0;
        }
    } else {
        return 0;
    }
}

scaled tex_get_math_x_parameter_checked(int style, int param)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled scale = tex_aux_max_scale(style, math_parameter_x_scale);
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            tex_aux_math_parameter_error(style, param, lmt_name_of_math_parameter(param));
            return 0;
        } else {
            return value ? scaledround(0.000000001 * glyph_scale_par * glyph_x_scale_par * value * scale) : 0;
        }
    } else {
        return 0;
    }
}

scaled tex_get_math_x_parameter_default(int style, int param, scaled dflt)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled scale = tex_aux_max_scale(style, math_parameter_x_scale);
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            return dflt;
        } else{
            return value ? scaledround(0.000000001 * glyph_scale_par * glyph_x_scale_par * value * scale) : 0;
        }
    } else {
        return dflt;
    }
}

scaled tex_get_math_y_parameter(int style, int param)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled scale = tex_aux_max_scale(style, math_parameter_y_scale);
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            return value;
        } else{
            return value ? scaledround(0.000000001 * glyph_scale_par * glyph_y_scale_par * value * scale) : 0;
        }
    } else {
        return 0;
    }
}

scaled tex_get_math_y_parameter_checked(int style, int param)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled scale = tex_aux_max_scale(style, math_parameter_y_scale);
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            tex_aux_math_parameter_error(style, param, lmt_name_of_math_parameter(param));
            return 0;
        } else {
            return value ? scaledround(0.000000001 * glyph_scale_par * glyph_y_scale_par * value * scale) : 0;
        }
    } else {
        return 0;
    }
}

scaled tex_get_math_y_parameter_default(int style, int param, scaled dflt)
{
    if (tex_aux_math_parameter_okay(param)) {
        scaled scale = tex_aux_max_scale(style, math_parameter_y_scale);
        scaled value = tex_get_math_parameter(style, param, NULL);
        if (value == undefined_math_parameter) {
            return dflt;
        } else{
            return value ? scaledround(0.000000001 * glyph_scale_par * glyph_y_scale_par * value * scale) : 0;
        }
    } else {
        return dflt;
    }
}

scaled tex_get_font_math_parameter(int font, int size, int param)
{
    scaled scale = tex_get_math_font_scale(font, size);
    scaled value = tex_aux_get_font_math_parameter(scale, font, param);
    if (value == undefined_math_parameter) {
        return undefined_math_parameter;
    } else {
        return value ? scaledround(0.001 * glyph_scale_par * value) : 0;
    }
}

/* maybe more precission, so multiply all and divide by 0.000000001 */

scaled tex_get_font_math_y_parameter(int font, int size, int param)
{
    scaled scale = tex_get_math_font_scale(font, size);
    scaled value = tex_aux_get_font_math_parameter(scale, font, param);
    if (value == undefined_math_parameter) {
        return undefined_math_parameter;
    } else {
        return value ? scaledround(0.000001 * glyph_scale_par * glyph_y_scale_par * value) : 0;
    }
}

scaled tex_get_font_math_x_parameter(int font, int size, int param)
{
    scaled scale = tex_get_math_font_scale(font, size);
    scaled value = tex_aux_get_font_math_parameter(scale, font, param);
    if (value == undefined_math_parameter) {
        return undefined_math_parameter;
    } else {
        return value ? scaledround(0.000001 * glyph_scale_par * glyph_x_scale_par * value) : 0;
    }
}

halfword tex_to_math_spacing_parameter(halfword left, halfword right)
{
    halfword param = math_parameter_spacing_pair(left,right);
    return (param >= math_parameter_atom_pairs_first && param <= math_parameter_atom_pairs_last) ? param : -1;
}

halfword tex_to_math_rules_parameter(halfword left, halfword right)
{
    halfword param = math_parameter_rules_pair(left,right);
    return (param >= math_parameter_atom_rules_first && param <= math_parameter_atom_rules_last) ? param : -1;
}

void tex_set_default_math_codes(void)
{
    mathcodeval mval = tex_no_math_code();
    /*tex This will remap old font families at runtime. */
    mval.class_value = math_use_current_family_code;
    /*tex Upright math digts come from family 0. */
    for (int d = '0'; d <= '9'; d++) {
        mval.character_value = d;
        tex_set_math_code(d, mval, level_one);
    }
    /* In traditional fonts math italic has family 1. */
    mval.family_value = 1;
    for (int u = 'A'; u <= 'Z'; u++) {
        mval.character_value = u;
        tex_set_math_code(u, mval, level_one);
    }
    for (int l = 'a'; l <= 'z'; l++) {
        mval.character_value = l;
        tex_set_math_code(l, mval, level_one);
    }
    /*tex This is kind of standard. */
    tex_set_del_code('.', (delcodeval) { { 0, 0, 0, }, { 0, 0, 0 } }, level_one);
}

int tex_in_main_math_style(halfword style)
{
    switch (style) {
        case display_style:
        case text_style:
            return 1;
        /*
         case cramped_display_style:
         case cramped_text_style:
            return 0; // could be parameter driven
        */
        default: 
            return 0;
    }
}
