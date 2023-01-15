/*
    See license.txt in the root of this project.
*/

/*tex

    There isn't much here because most happens in the header file. Here we also set up the
    environment in which we run, which depends in the operating system used.

*/

# include "luametatex.h"

lua_state_info lmt_lua_state = {
    .lua_instance            = NULL,
    .used_bytes              = 0,
    .used_bytes_max          = 0,
    .function_table_id       = 0,
    .function_callback_count = 0,
    .value_callback_count    = 0,
    .bytecode_callback_count = 0,
    .local_callback_count    = 0,
    .saved_callback_count    = 0,
    .file_callback_count     = 0,
    .direct_callback_count   = 0,
    .message_callback_count  = 0,
    .function_table_size     = 0,
    .bytecode_bytes          = 0,
    .bytecode_max            = 0,
    .version_number          = (int) LUA_VERSION_NUM,
    .release_number          = (int) LUA_VERSION_RELEASE_NUM,
    .used_buffer             = NULL,
    .integer_size            = sizeof(lua_Integer),
};

/*tex
    Some more can move here, or we can move some to modules instead. It's a very stepwise
    process because things need to keep running.
*/

lmt_keys_info lmt_keys;

lmt_interface_info lmt_interface = {
    .pack_type_values          = NULL,
    .group_code_values         = NULL,
    .par_context_values        = NULL,
    .par_begin_values          = NULL,
    .par_mode_values           = NULL,
    .math_style_name_values    = NULL,
    .math_style_variant_values = NULL,
    .lua_function_values       = NULL,
    .direction_values          = NULL,
    .node_fill_values          = NULL,
    .page_contribute_values    = NULL,
    .math_style_values         = NULL,
    .math_parameter_values     = NULL,
    .field_type_values         = NULL,
    .node_data                 = NULL,
    .command_names             = NULL,
} ;

value_info *lmt_aux_allocate_value_info(size_t last)
{
    value_info *v = lmt_memory_calloc(last + 2, sizeof(value_info));
    set_value_entry_nop(v, last + 1);
    return v;
}

void lmt_initialize_interface(void)
{
    lmt_interface.pack_type_values = lmt_aux_allocate_value_info(packing_adapted);

    # define set_pack_type_value(n,k) lmt_interface.pack_type_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_pack_type_value(packing_exactly,    exactly);
    set_pack_type_value(packing_additional, additional);
    set_pack_type_value(packing_expanded,   expanded);
    set_pack_type_value(packing_substitute, substitute);
    set_pack_type_value(packing_adapted,    adapted);

    lmt_interface.group_code_values = lmt_aux_allocate_value_info(lua_group);

    # define set_group_code_value(n,k) lmt_interface.group_code_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_group_code_value(bottom_level_group,   bottomlevel);
    set_group_code_value(simple_group,         simple);
    set_group_code_value(hbox_group,           hbox);
    set_group_code_value(adjusted_hbox_group,  adjustedhbox);
    set_group_code_value(vbox_group,           vbox);
    set_group_code_value(vtop_group,           vtop);
    set_group_code_value(dbox_group,           dbox);
    set_group_code_value(align_group,          align);
    set_group_code_value(no_align_group,       noalign);
    set_group_code_value(output_group,         output);
    set_group_code_value(math_group,           mathsubformula);
    set_group_code_value(math_component_group, mathcomponent);
    set_group_code_value(math_stack_group,     mathstack);
    set_group_code_value(discretionary_group,  discretionary);
    set_group_code_value(insert_group,         insert);
    set_group_code_value(vadjust_group,        vadjust);
    set_group_code_value(vcenter_group,        vcenter);
    set_group_code_value(math_fraction_group,  mathfraction);
    set_group_code_value(math_radical_group,   mathradical);
    set_group_code_value(math_operator_group,  mathoperator);
    set_group_code_value(math_choice_group,    mathchoice);
    set_group_code_value(also_simple_group,    alsosimple);
    set_group_code_value(semi_simple_group,    semisimple);
    set_group_code_value(math_simple_group,    mathsimple);
    set_group_code_value(math_inline_group,    mathinline);
    set_group_code_value(math_display_group,   mathdisplay);
    set_group_code_value(math_number_group,    mathnumber);
    set_group_code_value(math_fence_group,     mathfence);
    set_group_code_value(local_box_group,      localbox);
    set_group_code_value(split_off_group,      splitoff);
    set_group_code_value(split_keep_group,     splitkeep);
    set_group_code_value(preamble_group,       preamble);
    set_group_code_value(align_set_group,      alignset);
    set_group_code_value(finish_row_group,     finishrow);
    set_group_code_value(lua_group,            lua);

    lmt_interface.par_context_values = lmt_aux_allocate_value_info(reset_par_context);

    # define set_par_context_value(n,k) lmt_interface.par_context_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_par_context_value(normal_par_context,      normal);
    set_par_context_value(vmode_par_context,       vmode);
    set_par_context_value(vbox_par_context,        vbox);
    set_par_context_value(vtop_par_context,        vtop);
    set_par_context_value(dbox_par_context,        dbox);
    set_par_context_value(vcenter_par_context,     vcenter);
    set_par_context_value(vadjust_par_context,     vadjust);
    set_par_context_value(insert_par_context,      insert);
    set_par_context_value(output_par_context,      output);
    set_par_context_value(align_par_context,       align);
    set_par_context_value(no_align_par_context,    noalign);
    set_par_context_value(span_par_context,        span);
    set_par_context_value(reset_par_context,       reset);

    lmt_interface.page_context_values = lmt_aux_allocate_value_info(alignment_page_context);

    # define set_page_context_value(n,k) lmt_interface.page_context_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_page_context_value(box_page_context,             box);
    set_page_context_value(end_page_context,             end);
    set_page_context_value(vadjust_page_context,         vadjust);
    set_page_context_value(penalty_page_context,         penalty);
    set_page_context_value(boundary_page_context,        boundary);
    set_page_context_value(insert_page_context,          insert);
    set_page_context_value(hmode_par_page_context,       hmodepar);
    set_page_context_value(vmode_par_page_context,       vmodepar);
    set_page_context_value(begin_paragraph_page_context, beginparagraph);
    set_page_context_value(before_display_page_context,  beforedisplay);
    set_page_context_value(after_display_page_context,   afterdisplay);
    set_page_context_value(after_output_page_context,    afteroutput);
    set_page_context_value(alignment_page_context,       alignment);

    lmt_interface.append_line_context_values = lmt_aux_allocate_value_info(post_migrate_append_line_context);

    # define set_append_line_context_value(n,k) lmt_interface.append_line_context_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_append_line_context_value(box_append_line_context,          box);
    set_append_line_context_value(pre_box_append_line_context,      prebox);
    set_append_line_context_value(pre_adjust_append_line_context,   preadjust);
    set_append_line_context_value(post_adjust_append_line_context,  postadjust);
    set_append_line_context_value(pre_migrate_append_line_context,  premigrate);
    set_append_line_context_value(post_migrate_append_line_context, postmigrate);

    lmt_interface.alignment_context_values = lmt_aux_allocate_value_info(wrapup_pass_alignment_context);

    # define set_alignment_context_value(n,k) lmt_interface.alignment_context_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_alignment_context_value(preamble_pass_alignment_context, preamble);
    set_alignment_context_value(preroll_pass_alignment_context,  preroll);
    set_alignment_context_value(package_pass_alignment_context,  package);
    set_alignment_context_value(wrapup_pass_alignment_context,   wrapup);

    lmt_interface.par_begin_values = lmt_aux_allocate_value_info(vrule_char_par_begin);

    # define set_par_begin_value(n,k) lmt_interface.par_begin_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_par_begin_value(normal_par_begin,       normal);
    set_par_begin_value(force_par_begin,        force);
    set_par_begin_value(indent_par_begin,       indent);
    set_par_begin_value(no_indent_par_begin,    noindent);
    set_par_begin_value(math_char_par_begin,    mathchar);
    set_par_begin_value(char_par_begin,         char);
    set_par_begin_value(boundary_par_begin,     boundary);
    set_par_begin_value(space_par_begin,        space);
    set_par_begin_value(math_par_begin,         math);
    set_par_begin_value(kern_par_begin,         kern);
    set_par_begin_value(hskip_par_begin,        hskip);
    set_par_begin_value(un_hbox_char_par_begin, unhbox);
    set_par_begin_value(valign_char_par_begin,  valign);
    set_par_begin_value(vrule_char_par_begin,   vrule);

    lmt_interface.par_mode_values = lmt_aux_allocate_value_info(math_par_subtype);

    # define set_par_mode_value(n,k) lmt_interface.par_mode_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_par_mode_value(vmode_par_par_subtype, vmodepar);
    set_par_mode_value(local_box_par_subtype, localbox);
    set_par_mode_value(hmode_par_par_subtype, hmodepar);
    set_par_mode_value(penalty_par_subtype,   penalty);
    set_par_mode_value(math_par_subtype,      math);

    lmt_interface.math_style_name_values = lmt_aux_allocate_value_info(cramped_script_script_style);

    # define set_math_style_name_value(n,k) lmt_interface.math_style_name_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_math_style_name_value(display_style,               display);
    set_math_style_name_value(cramped_display_style,       crampeddisplay);
    set_math_style_name_value(text_style,                  text);
    set_math_style_name_value(cramped_text_style,          crampedtext);
    set_math_style_name_value(script_style,                script);
    set_math_style_name_value(cramped_script_style,        crampedscript);
    set_math_style_name_value(script_script_style,         scriptscript);
    set_math_style_name_value(cramped_script_script_style, crampedscriptscript);

    lmt_interface.math_style_variant_values = lmt_aux_allocate_value_info(math_double_superscript_variant);

    # define set_math_style_variant_value(n,k) lmt_interface.math_style_variant_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_math_style_variant_value(math_normal_style_variant,       normal);
    set_math_style_variant_value(math_cramped_style_variant,      cramped);
    set_math_style_variant_value(math_subscript_style_variant,    subscript);
    set_math_style_variant_value(math_superscript_style_variant,  superscript);
    set_math_style_variant_value(math_small_style_variant,        small);
    set_math_style_variant_value(math_smaller_style_variant,      smaller);
    set_math_style_variant_value(math_numerator_style_variant,    numerator);
    set_math_style_variant_value(math_denominator_style_variant,  denominator);
    set_math_style_variant_value(math_double_superscript_variant, doublesuperscript);

    lmt_interface.lua_function_values = lmt_aux_allocate_value_info(lua_value_direct_code);

    # define set_lua_function_value(n,k) lmt_interface.lua_function_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_lua_function_value(lua_value_none_code,      none);
    set_lua_function_value(lua_value_integer_code,   integer);
    set_lua_function_value(lua_value_cardinal_code,  cardinal);
    set_lua_function_value(lua_value_dimension_code, dimension);
    set_lua_function_value(lua_value_skip_code,      skip);
    set_lua_function_value(lua_value_boolean_code,   boolean);
    set_lua_function_value(lua_value_float_code,     float);
    set_lua_function_value(lua_value_string_code,    string);
    set_lua_function_value(lua_value_node_code,      node);
    set_lua_function_value(lua_value_direct_code,    direct);

    lmt_interface.direction_values = lmt_aux_allocate_value_info(dir_righttoleft);

    # define set_direction_value(n,k) lmt_interface.direction_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_direction_value(dir_lefttoright, lefttoright);
    set_direction_value(dir_righttoleft, righttoleft);

    lmt_interface.field_type_values = lmt_aux_allocate_value_info(attribute_field);

    # define set_field_type_value(n,k) lmt_interface.field_type_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_field_type_value(nil_field,            nil);
    set_field_type_value(integer_field,        integer);
    set_field_type_value(dimension_field,      dimension);
    set_field_type_value(glue_field,           glue);
    set_field_type_value(number_field,         number);
    set_field_type_value(string_field,         string);
    set_field_type_value(boolean_field,        boolean);
    set_field_type_value(function_field,       function);
    set_field_type_value(node_field,           node);
    set_field_type_value(node_list_field,      nodelist);
    set_field_type_value(token_field,          token);
    set_field_type_value(token_list_field,     tokenlist);
    set_field_type_value(attribute_field,      attribute);

    lmt_interface.node_fill_values = lmt_aux_allocate_value_info(filll_glue_order);

    # define set_node_fill_value(n,k) lmt_interface.node_fill_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_node_fill_value(normal_glue_order, normal);
    set_node_fill_value(fi_glue_order,     fi);
    set_node_fill_value(fil_glue_order,    fil);
    set_node_fill_value(fill_glue_order,   fill);
    set_node_fill_value(filll_glue_order,  filll);

    lmt_interface.page_contribute_values = lmt_aux_allocate_value_info(contribute_rule);

    # define set_page_contribute_value(n,k) lmt_interface.page_contribute_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_page_contribute_value(contribute_nothing, empty);
    set_page_contribute_value(contribute_insert,  insert);
    set_page_contribute_value(contribute_box,     box);
    set_page_contribute_value(contribute_rule,    rule);

    lmt_interface.math_style_values = lmt_aux_allocate_value_info(cramped_script_script_style);

    # define set_math_style_value(n,k) lmt_interface.math_style_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_math_style_value(display_style,               display);
    set_math_style_value(cramped_display_style,       crampeddisplay);
    set_math_style_value(text_style,                  text);
    set_math_style_value(cramped_text_style,          crampedtext);
    set_math_style_value(script_style,                script);
    set_math_style_value(cramped_script_style,        crampedscript);
    set_math_style_value(script_script_style,         scriptscript);
    set_math_style_value(cramped_script_script_style, crampedscriptscript);

    lmt_interface.math_indirect_values = lmt_aux_allocate_value_info(last_math_indirect);

    # define set_math_indirect_value(n,k) lmt_interface.math_indirect_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .id = n }

    set_math_indirect_value(indirect_math_unset,               unset);
    set_math_indirect_value(indirect_math_regular,             regular);
    set_math_indirect_value(indirect_math_integer,             integer);
    set_math_indirect_value(indirect_math_dimension,           dimension);
    set_math_indirect_value(indirect_math_gluespec,            gluespec);
    set_math_indirect_value(indirect_math_mugluespec,          mugluespec);
    set_math_indirect_value(indirect_math_register_integer,    registerinteger);
    set_math_indirect_value(indirect_math_register_dimension,  registerdimension);
    set_math_indirect_value(indirect_math_register_gluespec,   registergluespec);
    set_math_indirect_value(indirect_math_register_mugluespec, registermugluespec);
    set_math_indirect_value(indirect_math_internal_integer,    internalinteger);
    set_math_indirect_value(indirect_math_internal_dimension,  internaldimension);
    set_math_indirect_value(indirect_math_internal_dimension,  internalgluespec);
    set_math_indirect_value(indirect_math_internal_mugluespec, internalmugluespec);

    lmt_interface.math_parameter_values = lmt_aux_allocate_value_info(last_math_parameter);

    # define set_math_parameter_value(n,t,k) lmt_interface.math_parameter_values[n] = (value_info) { .lua = lua_key_index(k), .name = lua_key(k), .type = t }

    set_math_parameter_value(math_parameter_quad,                             math_dimen_parameter, quad);
    set_math_parameter_value(math_parameter_axis,                             math_dimen_parameter, axis);
    set_math_parameter_value(math_parameter_accent_base_height,               math_dimen_parameter, accentbaseheight);
    set_math_parameter_value(math_parameter_accent_base_depth,                math_dimen_parameter, accentbasedepth);
    set_math_parameter_value(math_parameter_flattened_accent_base_height,     math_dimen_parameter, flattenedaccentbaseheight);
    set_math_parameter_value(math_parameter_flattened_accent_base_depth,      math_dimen_parameter, flattenedaccentbasedepth);
    set_math_parameter_value(math_parameter_x_scale,                          math_int_parameter,   xscale);
    set_math_parameter_value(math_parameter_y_scale,                          math_int_parameter,   yscale);
    set_math_parameter_value(math_parameter_operator_size,                    math_dimen_parameter, operatorsize);
    set_math_parameter_value(math_parameter_overbar_kern,                     math_dimen_parameter, overbarkern);
    set_math_parameter_value(math_parameter_overbar_rule,                     math_dimen_parameter, overbarrule);
    set_math_parameter_value(math_parameter_overbar_vgap,                     math_dimen_parameter, overbarvgap);
    set_math_parameter_value(math_parameter_underbar_kern,                    math_dimen_parameter, underbarkern);
    set_math_parameter_value(math_parameter_underbar_rule,                    math_dimen_parameter, underbarrule);
    set_math_parameter_value(math_parameter_underbar_vgap,                    math_dimen_parameter, underbarvgap);
    set_math_parameter_value(math_parameter_radical_kern,                     math_dimen_parameter, radicalkern);
    set_math_parameter_value(math_parameter_radical_rule,                     math_dimen_parameter, radicalrule);
    set_math_parameter_value(math_parameter_radical_vgap,                     math_dimen_parameter, radicalvgap);
    set_math_parameter_value(math_parameter_radical_degree_before,            math_dimen_parameter, radicaldegreebefore);
    set_math_parameter_value(math_parameter_radical_degree_after,             math_dimen_parameter, radicaldegreeafter);
    set_math_parameter_value(math_parameter_radical_degree_raise,             math_int_parameter,   radicaldegreeraise);
    set_math_parameter_value(math_parameter_radical_extensible_after,         math_dimen_parameter, radicalextensibleafter);
    set_math_parameter_value(math_parameter_radical_extensible_before,        math_dimen_parameter, radicalextensiblebefore);
    set_math_parameter_value(math_parameter_stack_vgap,                       math_dimen_parameter, stackvgap);
    set_math_parameter_value(math_parameter_stack_num_up,                     math_dimen_parameter, stacknumup);
    set_math_parameter_value(math_parameter_stack_denom_down,                 math_dimen_parameter, stackdenomdown);
    set_math_parameter_value(math_parameter_fraction_rule,                    math_dimen_parameter, fractionrule);
    set_math_parameter_value(math_parameter_fraction_num_vgap,                math_dimen_parameter, fractionnumvgap);
    set_math_parameter_value(math_parameter_fraction_num_up,                  math_dimen_parameter, fractionnumup);
    set_math_parameter_value(math_parameter_fraction_denom_vgap,              math_dimen_parameter, fractiondenomvgap);
    set_math_parameter_value(math_parameter_fraction_denom_down,              math_dimen_parameter, fractiondenomdown);
    set_math_parameter_value(math_parameter_fraction_del_size,                math_dimen_parameter, fractiondelsize);
    set_math_parameter_value(math_parameter_skewed_fraction_hgap,             math_dimen_parameter, skewedfractionhgap);
    set_math_parameter_value(math_parameter_skewed_fraction_vgap,             math_dimen_parameter, skewedfractionvgap);
    set_math_parameter_value(math_parameter_limit_above_vgap,                 math_dimen_parameter, limitabovevgap);
    set_math_parameter_value(math_parameter_limit_above_bgap,                 math_dimen_parameter, limitabovebgap);
    set_math_parameter_value(math_parameter_limit_above_kern,                 math_dimen_parameter, limitabovekern);
    set_math_parameter_value(math_parameter_limit_below_vgap,                 math_dimen_parameter, limitbelowvgap);
    set_math_parameter_value(math_parameter_limit_below_bgap,                 math_dimen_parameter, limitbelowbgap);
    set_math_parameter_value(math_parameter_limit_below_kern,                 math_dimen_parameter, limitbelowkern);
    set_math_parameter_value(math_parameter_nolimit_sup_factor,               math_dimen_parameter, nolimitsupfactor);
    set_math_parameter_value(math_parameter_nolimit_sub_factor,               math_dimen_parameter, nolimitsubfactor);
    set_math_parameter_value(math_parameter_under_delimiter_vgap,             math_dimen_parameter, underdelimitervgap);
    set_math_parameter_value(math_parameter_under_delimiter_bgap,             math_dimen_parameter, underdelimiterbgap);
    set_math_parameter_value(math_parameter_over_delimiter_vgap,              math_dimen_parameter, overdelimitervgap);
    set_math_parameter_value(math_parameter_over_delimiter_bgap,              math_dimen_parameter, overdelimiterbgap);
    set_math_parameter_value(math_parameter_subscript_shift_drop,             math_dimen_parameter, subshiftdrop);
    set_math_parameter_value(math_parameter_superscript_shift_drop,           math_dimen_parameter, supshiftdrop);
    set_math_parameter_value(math_parameter_subscript_shift_down,             math_dimen_parameter, subshiftdown);
    set_math_parameter_value(math_parameter_subscript_superscript_shift_down, math_dimen_parameter, subsupshiftdown);
    set_math_parameter_value(math_parameter_subscript_top_max,                math_dimen_parameter, subtopmax);
    set_math_parameter_value(math_parameter_superscript_shift_up,             math_dimen_parameter, supshiftup);
    set_math_parameter_value(math_parameter_superscript_bottom_min,           math_dimen_parameter, supbottommin);
    set_math_parameter_value(math_parameter_superscript_subscript_bottom_max, math_dimen_parameter, supsubbottommax);
    set_math_parameter_value(math_parameter_subscript_superscript_vgap,       math_dimen_parameter, subsupvgap);
    set_math_parameter_value(math_parameter_space_before_script,              math_dimen_parameter, spacebeforescript);
    set_math_parameter_value(math_parameter_space_after_script,               math_dimen_parameter, spaceafterscript);
    set_math_parameter_value(math_parameter_connector_overlap_min,            math_dimen_parameter, connectoroverlapmin);

    /*tex

        Gone are the many:

        \starttyping
        set_math_parameter_value(math_parameter_ordinary_ordinary_spacing, math_muglue_parameter, ordordspacing);
        \stoptyping

        thanks to the more generic multiple class mechanism.

    */

    set_math_parameter_value(math_parameter_extra_superscript_shift,            math_dimen_parameter,  extrasuperscriptshift);
    set_math_parameter_value(math_parameter_extra_subscript_shift,              math_dimen_parameter,  extrasubscriptshift);
    set_math_parameter_value(math_parameter_extra_superprescript_shift,         math_dimen_parameter,  extrasuperprescriptshift);
    set_math_parameter_value(math_parameter_extra_subprescript_shift,           math_dimen_parameter,  extrasubprescriptshift);

    set_math_parameter_value(math_parameter_prime_raise,                        math_int_parameter,    primeraise);
    set_math_parameter_value(math_parameter_prime_raise_composed,               math_int_parameter,    primeraisecomposed);
    set_math_parameter_value(math_parameter_prime_shift_up,                     math_dimen_parameter,  primeshiftup);
    set_math_parameter_value(math_parameter_prime_shift_drop,                   math_dimen_parameter,  primeshiftdrop);
    set_math_parameter_value(math_parameter_prime_space_after,                  math_dimen_parameter,  primespaceafter);
    set_math_parameter_value(math_parameter_prime_width,                        math_int_parameter,    primewidth);

    set_math_parameter_value(math_parameter_rule_height,                        math_dimen_parameter,  ruleheight);
    set_math_parameter_value(math_parameter_rule_depth,                         math_dimen_parameter,  ruledepth);

    set_math_parameter_value(math_parameter_superscript_shift_distance,         math_dimen_parameter,  superscriptshiftdistance);
    set_math_parameter_value(math_parameter_subscript_shift_distance,           math_dimen_parameter,  subscriptshiftdistance);
    set_math_parameter_value(math_parameter_superprescript_shift_distance,      math_dimen_parameter,  presuperscriptshiftdistance);
    set_math_parameter_value(math_parameter_subprescript_shift_distance,        math_dimen_parameter,  presubscriptshiftdistance);

    set_math_parameter_value(math_parameter_extra_superscript_space,            math_dimen_parameter,  extrasuperscriptspace);
    set_math_parameter_value(math_parameter_extra_subscript_space,              math_dimen_parameter,  extrasubscriptspace);
    set_math_parameter_value(math_parameter_extra_superprescript_space,         math_dimen_parameter,  extrasuperprescriptspace);
    set_math_parameter_value(math_parameter_extra_subprescript_space,           math_dimen_parameter,  extrasubprescriptspace);

    set_math_parameter_value(math_parameter_skewed_delimiter_tolerance,         math_dimen_parameter,  skeweddelimitertolerance);

    set_math_parameter_value(math_parameter_accent_top_shift_up,                math_dimen_parameter,  accenttopshiftup);
    set_math_parameter_value(math_parameter_accent_bottom_shift_down,           math_dimen_parameter,  accentbottomshiftdown);
    set_math_parameter_value(math_parameter_accent_top_overshoot,               math_int_parameter,    accenttopovershoot);
    set_math_parameter_value(math_parameter_accent_bottom_overshoot,            math_int_parameter,    accentbottomovershoot);
    set_math_parameter_value(math_parameter_accent_superscript_drop,            math_dimen_parameter,  accentsuperscriptdrop);
    set_math_parameter_value(math_parameter_accent_superscript_percent,         math_int_parameter,    accentsuperscriptpercent);
    set_math_parameter_value(math_parameter_accent_extend_margin,               math_int_parameter,    accentextendmargin);
    set_math_parameter_value(math_parameter_flattened_accent_top_shift_up,      math_dimen_parameter,  flattenedaccenttopshiftup);
    set_math_parameter_value(math_parameter_flattened_accent_bottom_shift_down, math_dimen_parameter,  flattenedaccentbottomshiftdown);

    set_math_parameter_value(math_parameter_delimiter_percent,                  math_int_parameter,    delimiterpercent);
    set_math_parameter_value(math_parameter_delimiter_shortfall,                math_dimen_parameter,  delimitershortfall);

    set_math_parameter_value(math_parameter_over_line_variant,                  math_style_parameter,  overlinevariant);
    set_math_parameter_value(math_parameter_under_line_variant,                 math_style_parameter,  underlinevariant);
    set_math_parameter_value(math_parameter_over_delimiter_variant,             math_style_parameter,  overdelimitervariant);
    set_math_parameter_value(math_parameter_under_delimiter_variant,            math_style_parameter,  underdelimitervariant);
    set_math_parameter_value(math_parameter_delimiter_over_variant,             math_style_parameter,  delimiterovervariant);
    set_math_parameter_value(math_parameter_delimiter_under_variant,            math_style_parameter,  delimiterundervariant);
    set_math_parameter_value(math_parameter_h_extensible_variant,               math_style_parameter,  hextensiblevariant);
    set_math_parameter_value(math_parameter_v_extensible_variant,               math_style_parameter,  vextensiblevariant);
    set_math_parameter_value(math_parameter_fraction_variant,                   math_style_parameter,  fractionvariant);
    set_math_parameter_value(math_parameter_radical_variant,                    math_style_parameter,  radicalvariant);
    set_math_parameter_value(math_parameter_degree_variant,                     math_style_parameter,  degreevariant);
    set_math_parameter_value(math_parameter_accent_variant,                     math_style_parameter,  accentvariant);
    set_math_parameter_value(math_parameter_top_accent_variant,                 math_style_parameter,  topaccentvariant);
    set_math_parameter_value(math_parameter_bottom_accent_variant,              math_style_parameter,  bottomaccentvariant);
    set_math_parameter_value(math_parameter_overlay_accent_variant,             math_style_parameter,  overlayaccentvariant);
    set_math_parameter_value(math_parameter_numerator_variant,                  math_style_parameter,  numeratorvariant);
    set_math_parameter_value(math_parameter_denominator_variant,                math_style_parameter,  denominatorvariant);
    set_math_parameter_value(math_parameter_superscript_variant,                math_style_parameter,  superscriptvariant);
    set_math_parameter_value(math_parameter_subscript_variant,                  math_style_parameter,  subscriptvariant);
    set_math_parameter_value(math_parameter_prime_variant,                      math_style_parameter,  primevariant);
    set_math_parameter_value(math_parameter_stack_variant,                      math_style_parameter,  stackvariant);

    lmt_interface.math_font_parameter_values = lmt_aux_allocate_value_info(math_parameter_last_code + 1);

    # define set_math_font_parameter(n, t) lmt_interface.math_font_parameter_values[n] = (value_info) { .lua = lua_key_index(n), .name = lua_key(n), .type = t }

    set_math_font_parameter(ScriptPercentScaleDown,                   math_int_parameter);
    set_math_font_parameter(ScriptScriptPercentScaleDown,             math_int_parameter);
    set_math_font_parameter(DelimitedSubFormulaMinHeight,             math_dimen_parameter);
    set_math_font_parameter(DisplayOperatorMinHeight,                 math_dimen_parameter);
    set_math_font_parameter(MathLeading,                              math_dimen_parameter);
    set_math_font_parameter(AxisHeight,                               math_dimen_parameter);
    set_math_font_parameter(AccentBaseHeight,                         math_dimen_parameter);
    set_math_font_parameter(AccentBaseDepth,                          math_dimen_parameter);
    set_math_font_parameter(FlattenedAccentBaseHeight,                math_dimen_parameter);
    set_math_font_parameter(FlattenedAccentBaseDepth,                 math_dimen_parameter);
    set_math_font_parameter(SubscriptShiftDown,                       math_dimen_parameter);
    set_math_font_parameter(SubscriptTopMax,                          math_dimen_parameter);
    set_math_font_parameter(SubscriptBaselineDropMin,                 math_dimen_parameter);
    set_math_font_parameter(SuperscriptShiftUp,                       math_dimen_parameter);
    set_math_font_parameter(SuperscriptShiftUpCramped,                math_dimen_parameter);
    set_math_font_parameter(SuperscriptBottomMin,                     math_dimen_parameter);
    set_math_font_parameter(SuperscriptBaselineDropMax,               math_dimen_parameter);
    set_math_font_parameter(SubSuperscriptGapMin,                     math_dimen_parameter);
    set_math_font_parameter(SuperscriptBottomMaxWithSubscript,        math_dimen_parameter);
    set_math_font_parameter(SpaceBeforeScript,                        math_dimen_parameter);
    set_math_font_parameter(SpaceAfterScript,                         math_dimen_parameter);
    set_math_font_parameter(UpperLimitGapMin,                         math_dimen_parameter);
    set_math_font_parameter(UpperLimitBaselineRiseMin,                math_dimen_parameter);
    set_math_font_parameter(LowerLimitGapMin,                         math_dimen_parameter);
    set_math_font_parameter(LowerLimitBaselineDropMin,                math_dimen_parameter);
    set_math_font_parameter(StackTopShiftUp,                          math_dimen_parameter);
    set_math_font_parameter(StackTopDisplayStyleShiftUp,              math_dimen_parameter);
    set_math_font_parameter(StackBottomShiftDown,                     math_dimen_parameter);
    set_math_font_parameter(StackBottomDisplayStyleShiftDown,         math_dimen_parameter);
    set_math_font_parameter(StackGapMin,                              math_dimen_parameter);
    set_math_font_parameter(StackDisplayStyleGapMin,                  math_dimen_parameter);
    set_math_font_parameter(StretchStackTopShiftUp,                   math_dimen_parameter);
    set_math_font_parameter(StretchStackBottomShiftDown,              math_dimen_parameter);
    set_math_font_parameter(StretchStackGapAboveMin,                  math_dimen_parameter);
    set_math_font_parameter(StretchStackGapBelowMin,                  math_dimen_parameter);
    set_math_font_parameter(FractionNumeratorShiftUp,                 math_dimen_parameter);
    set_math_font_parameter(FractionNumeratorDisplayStyleShiftUp,     math_dimen_parameter);
    set_math_font_parameter(FractionDenominatorShiftDown,             math_dimen_parameter);
    set_math_font_parameter(FractionDenominatorDisplayStyleShiftDown, math_dimen_parameter);
    set_math_font_parameter(FractionNumeratorGapMin,                  math_dimen_parameter);
    set_math_font_parameter(FractionNumeratorDisplayStyleGapMin,      math_dimen_parameter);
    set_math_font_parameter(FractionRuleThickness,                    math_dimen_parameter);
    set_math_font_parameter(FractionDenominatorGapMin,                math_dimen_parameter);
    set_math_font_parameter(FractionDenominatorDisplayStyleGapMin,    math_dimen_parameter);
    set_math_font_parameter(SkewedFractionHorizontalGap,              math_dimen_parameter);
    set_math_font_parameter(SkewedFractionVerticalGap,                math_dimen_parameter);
    set_math_font_parameter(OverbarVerticalGap,                       math_dimen_parameter);
    set_math_font_parameter(OverbarRuleThickness,                     math_dimen_parameter);
    set_math_font_parameter(OverbarExtraAscender,                     math_dimen_parameter);
    set_math_font_parameter(UnderbarVerticalGap,                      math_dimen_parameter);
    set_math_font_parameter(UnderbarRuleThickness,                    math_dimen_parameter);
    set_math_font_parameter(UnderbarExtraDescender,                   math_dimen_parameter);
    set_math_font_parameter(RadicalVerticalGap,                       math_dimen_parameter);
    set_math_font_parameter(RadicalDisplayStyleVerticalGap,           math_dimen_parameter);
    set_math_font_parameter(RadicalRuleThickness,                     math_dimen_parameter);
    set_math_font_parameter(RadicalExtraAscender,                     math_dimen_parameter);
    set_math_font_parameter(RadicalKernBeforeDegree,                  math_dimen_parameter);
    set_math_font_parameter(RadicalKernAfterDegree,                   math_dimen_parameter);
    set_math_font_parameter(RadicalDegreeBottomRaisePercent,          math_int_parameter);
    set_math_font_parameter(RadicalKernAfterExtensible,               math_dimen_parameter);
    set_math_font_parameter(RadicalKernBeforeExtensible,              math_dimen_parameter);
    set_math_font_parameter(MinConnectorOverlap,                      math_dimen_parameter);
    set_math_font_parameter(SubscriptShiftDownWithSuperscript,        math_dimen_parameter);
    set_math_font_parameter(FractionDelimiterSize,                    math_dimen_parameter);
    set_math_font_parameter(FractionDelimiterDisplayStyleSize,        math_dimen_parameter);
    set_math_font_parameter(NoLimitSubFactor,                         math_int_parameter);
    set_math_font_parameter(NoLimitSupFactor,                         math_int_parameter);
    set_math_font_parameter(PrimeRaisePercent,                        math_int_parameter);
    set_math_font_parameter(PrimeRaiseComposedPercent,                math_int_parameter);
    set_math_font_parameter(PrimeShiftUp,                             math_dimen_parameter);
    set_math_font_parameter(PrimeShiftUpCramped,                      math_dimen_parameter);
    set_math_font_parameter(PrimeBaselineDropMax,                     math_dimen_parameter);
    set_math_font_parameter(PrimeSpaceAfter,                          math_dimen_parameter);
    set_math_font_parameter(PrimeWidthPercent,                        math_int_parameter);
    set_math_font_parameter(SkewedDelimiterTolerance,                 math_dimen_parameter);
    set_math_font_parameter(AccentTopShiftUp,                         math_dimen_parameter);
    set_math_font_parameter(AccentBottomShiftDown,                    math_dimen_parameter);
    set_math_font_parameter(AccentTopOvershoot,                       math_int_parameter);
    set_math_font_parameter(AccentBottomOvershoot,                    math_int_parameter);
    set_math_font_parameter(AccentSuperscriptDrop,                    math_dimen_parameter);
    set_math_font_parameter(AccentSuperscriptPercent,                 math_int_parameter);
    set_math_font_parameter(AccentExtendMargin,                       math_dimen_parameter);
    set_math_font_parameter(FlattenedAccentTopShiftUp,                math_dimen_parameter);
    set_math_font_parameter(FlattenedAccentBottomShiftDown,           math_dimen_parameter);
    set_math_font_parameter(DelimiterPercent,                         math_int_parameter);
    set_math_font_parameter(DelimiterShortfall,                       math_dimen_parameter);
}
