/*
    See license.txt in the root of this project.
*/

/*tex

    The tokenlib started out as an expetiment. The first version provided a rough interface to the
    internals but could only really be used for simple introspection and limited piping back. A major
    step up came in a second version where Taco introduced a couple of scanners. During experiments
    in \CONTEXT\ I added some more so now we have a reasonable repertoire of creators, accessors and
    scanners. Piping back to \LUA\ happens in the |tex| library and that one also has been enhanced
    and accepts tokens.

    In \LUAMETATEX\ much got streamlined, partially rewritten and some more got added so we're now
    actually at the third version. In the meantime the experimental status has been revoked. Also,
    the internals that relate to tokens in \LUAMETATEX\ have been redone so that the interface to
    \LUA\ feels more natural.

    Tokens are numbers but these can best be treated as abstractions. The number can be split in
    components that code some properties. However, these numbers can change depending on what
    abstraction we decide to use. As with the nodes integers make for an efficient coding but are
    effectively just black boxes. The Lua interface below communicates via such numbers but don't
    make your code dependent of the values. The mentioned rework of the internals now makes sure
    that we get less funny numbers. For instance all chr codes nor occupy proper ranges and names
    are more meaningful.

*/

# include "luametatex.h"

/* # define TOKEN_METATABLE_INSTANCE "luatex.token" */

typedef struct lua_token_package {
    struct {
        quarterword level; /* not used but it reflects the original */
        quarterword how;   /* global */
    };
    singleword cmd;
    singleword flag;
    halfword   chr;
    halfword   cs;
} lua_token_package;

/*

    So, given what is said above, the \LUA\ interface no longer really is about magic numbers
    combined from cmd and chr codes, sometimes called modes, but consistently tries to use the
    combination instead of the composed number. The number is still there (and available) but users
    need to keep in mind that constructing them directly is bad idea: the internals and therefore
    cmd and chr codes can change! We start with a table that defines all the properties.

    It must be noticed that the codebase is now rather different from \LUATEX. Of course we still
    have most of the original commands but new ones have been added, experimental one have been
    dropped, some have been combined. One criterium for grouping commands is that such a group gets
    a unique treatment in reading a follow up, serialization, expansion, the main loop, the
    registers and variables it refers to, etc. There is some logic behind it!

    command_item lmt_command_names[] = {
        { .id = escape_cmd, .lua = 0, .name = NULL, .kind = character_command_item, .min = 0, .max = max_character_code, .base = 0,  .fixedvalue = too_big_char },
        ....
    } ;

    has been replaced by a dynamic allocation and later assignment.

    In principle we can add some more clever token definers for instance for integers but that will
    be done when I need it. The special data / reference commands need some checking (min, max etc.)

*/

# define ignore_entry -1
# define direct_entry -2

void lmt_tokenlib_initialize(void)
{

    lmt_interface.command_names = lmt_memory_malloc((register_dimen_reference_cmd + 2) * sizeof(command_item));

    lmt_interface.command_names[escape_cmd]                       = (command_item) { .id = escape_cmd,                         .lua = lua_key_index(escape),                       .name = lua_key(escape),                       .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = too_big_char };
    lmt_interface.command_names[left_brace_cmd]                   = (command_item) { .id = left_brace_cmd,                     .lua = lua_key_index(left_brace),                   .name = lua_key(left_brace),                   .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[right_brace_cmd]                  = (command_item) { .id = right_brace_cmd,                    .lua = lua_key_index(right_brace),                  .name = lua_key(right_brace),                  .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_shift_cmd]                   = (command_item) { .id = math_shift_cmd,                     .lua = lua_key_index(math_shift),                   .name = lua_key(math_shift),                   .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[alignment_tab_cmd]                = (command_item) { .id = alignment_tab_cmd,                  .lua = lua_key_index(alignment_tab),                .name = lua_key(alignment_tab),                .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[end_line_cmd]                     = (command_item) { .id = end_line_cmd,                       .lua = lua_key_index(end_line),                     .name = lua_key(end_line),                     .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[parameter_cmd]                    = (command_item) { .id = parameter_cmd,                      .lua = lua_key_index(parameter),                    .name = lua_key(parameter),                    .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[superscript_cmd]                  = (command_item) { .id = superscript_cmd,                    .lua = lua_key_index(superscript),                  .name = lua_key(superscript),                  .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[subscript_cmd]                    = (command_item) { .id = subscript_cmd,                      .lua = lua_key_index(subscript),                    .name = lua_key(subscript),                    .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[ignore_cmd]                       = (command_item) { .id = ignore_cmd,                         .lua = lua_key_index(ignore),                       .name = lua_key(ignore),                       .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[spacer_cmd]                       = (command_item) { .id = spacer_cmd,                         .lua = lua_key_index(spacer),                       .name = lua_key(spacer),                       .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[letter_cmd]                       = (command_item) { .id = letter_cmd,                         .lua = lua_key_index(letter),                       .name = lua_key(letter),                       .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[other_char_cmd]                   = (command_item) { .id = other_char_cmd,                     .lua = lua_key_index(other_char),                   .name = lua_key(other_char),                   .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[active_char_cmd]                  = (command_item) { .id = active_char_cmd,                    .lua = lua_key_index(active_char),                  .name = lua_key(active_char),                  .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = too_big_char };
    lmt_interface.command_names[comment_cmd]                      = (command_item) { .id = comment_cmd,                        .lua = lua_key_index(comment),                      .name = lua_key(comment),                      .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[invalid_char_cmd]                 = (command_item) { .id = invalid_char_cmd,                   .lua = lua_key_index(invalid_char),                 .name = lua_key(invalid_char),                 .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[relax_cmd]                        = (command_item) { .id = relax_cmd,                          .lua = lua_key_index(relax),                        .name = lua_key(relax),                        .kind = regular_command_item,   .min = 0,                         .max = last_relax_code,              .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[end_template_cmd]                 = (command_item) { .id = end_template_cmd,                   .lua = lua_key_index(alignment),                    .name = lua_key(alignment),                    .kind = regular_command_item,   .min = 0,                         .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[alignment_cmd]                    = (command_item) { .id = alignment_cmd,                      .lua = lua_key_index(end_template),                 .name = lua_key(end_template),                 .kind = regular_command_item,   .min = 0,                         .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[match_cmd]                        = (command_item) { .id = match_cmd,                          .lua = lua_key_index(match),                        .name = lua_key(match),                        .kind = regular_command_item,   .min = 0,                         .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[end_match_cmd]                    = (command_item) { .id = end_match_cmd,                      .lua = lua_key_index(end_match),                    .name = lua_key(end_match),                    .kind = regular_command_item,   .min = 0,                         .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[parameter_reference_cmd]          = (command_item) { .id = parameter_reference_cmd,            .lua = lua_key_index(parameter_reference),          .name = lua_key(parameter_reference),          .kind = regular_command_item,   .min = 0,                         .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[end_paragraph_cmd]                = (command_item) { .id = end_paragraph_cmd,                  .lua = lua_key_index(end_paragraph),                .name = lua_key(end_paragraph),                .kind = regular_command_item,   .min = 0,                         .max = last_end_paragraph_code,      .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[end_job_cmd]                      = (command_item) { .id = end_job_cmd,                        .lua = lua_key_index(end_job),                      .name = lua_key(end_job),                      .kind = regular_command_item,   .min = 0,                         .max = last_end_job_code,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[delimiter_number_cmd]             = (command_item) { .id = delimiter_number_cmd,               .lua = lua_key_index(delimiter_number),             .name = lua_key(delimiter_number),             .kind = regular_command_item,   .min = 0,                         .max = last_math_delimiter_code,     .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[char_number_cmd]                  = (command_item) { .id = char_number_cmd,                    .lua = lua_key_index(char_number),                  .name = lua_key(char_number),                  .kind = regular_command_item,   .min = 0,                         .max = last_char_number_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_char_number_cmd]             = (command_item) { .id = math_char_number_cmd,               .lua = lua_key_index(math_char_number),             .name = lua_key(math_char_number),             .kind = regular_command_item,   .min = 0,                         .max = last_math_char_number_code,   .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_mark_cmd]                     = (command_item) { .id = set_mark_cmd,                       .lua = lua_key_index(set_mark),                     .name = lua_key(set_mark),                     .kind = regular_command_item,   .min = 0,                         .max = last_set_mark_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[node_cmd]                         = (command_item) { .id = node_cmd,                           .lua = lua_key_index(node),                         .name = lua_key(node),                         .kind = node_command_item,      .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[xray_cmd]                         = (command_item) { .id = xray_cmd,                           .lua = lua_key_index(xray),                         .name = lua_key(xray),                         .kind = regular_command_item,   .min = 0,                         .max = last_xray_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[make_box_cmd]                     = (command_item) { .id = make_box_cmd,                       .lua = lua_key_index(make_box),                     .name = lua_key(make_box),                     .kind = regular_command_item,   .min = 0,                         .max = last_nu_box_code,             .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[hmove_cmd]                        = (command_item) { .id = hmove_cmd,                          .lua = lua_key_index(hmove),                        .name = lua_key(hmove),                        .kind = regular_command_item,   .min = 0,                         .max = last_move_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[vmove_cmd]                        = (command_item) { .id = vmove_cmd,                          .lua = lua_key_index(vmove),                        .name = lua_key(vmove),                        .kind = regular_command_item,   .min = 0,                         .max = last_move_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[un_hbox_cmd]                      = (command_item) { .id = un_hbox_cmd,                        .lua = lua_key_index(un_hbox),                      .name = lua_key(un_hbox),                      .kind = regular_command_item,   .min = 0,                         .max = last_un_box_code,             .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[un_vbox_cmd]                      = (command_item) { .id = un_vbox_cmd,                        .lua = lua_key_index(un_vbox),                      .name = lua_key(un_vbox),                      .kind = regular_command_item,   .min = 0,                         .max = last_un_box_code,             .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[remove_item_cmd]                  = (command_item) { .id = remove_item_cmd,                    .lua = lua_key_index(remove_item),                  .name = lua_key(remove_item),                  .kind = regular_command_item,   .min = 0,                         .max = last_remove_item_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[hskip_cmd]                        = (command_item) { .id = hskip_cmd,                          .lua = lua_key_index(hskip),                        .name = lua_key(hskip),                        .kind = regular_command_item,   .min = first_skip_code,           .max = last_skip_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[vskip_cmd]                        = (command_item) { .id = vskip_cmd,                          .lua = lua_key_index(vskip),                        .name = lua_key(vskip),                        .kind = regular_command_item,   .min = first_skip_code,           .max = last_skip_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[mskip_cmd]                        = (command_item) { .id = mskip_cmd,                          .lua = lua_key_index(mskip),                        .name = lua_key(mskip),                        .kind = regular_command_item,   .min = 0,                         .max = last_mskip_code,              .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[kern_cmd]                         = (command_item) { .id = kern_cmd,                           .lua = lua_key_index(kern),                         .name = lua_key(kern),                         .kind = regular_command_item,   .min = 0,                         .max = last_kern_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[mkern_cmd]                        = (command_item) { .id = mkern_cmd,                          .lua = lua_key_index(mkern),                        .name = lua_key(mkern),                        .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[leader_cmd]                       = (command_item) { .id = leader_cmd,                         .lua = lua_key_index(leader),                       .name = lua_key(leader),                       .kind = regular_command_item,   .min = first_leader_code,         .max = last_leader_code,             .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[legacy_cmd]                       = (command_item) { .id = legacy_cmd,                         .lua = lua_key_index(legacy),                       .name = lua_key(legacy),                       .kind = regular_command_item,   .min = first_legacy_code,         .max = last_legacy_code ,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[local_box_cmd]                    = (command_item) { .id = local_box_cmd,                      .lua = lua_key_index(local_box),                    .name = lua_key(local_box),                    .kind = regular_command_item,   .min = first_local_box_code,      .max = last_local_box_code,          .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[halign_cmd]                       = (command_item) { .id = halign_cmd,                         .lua = lua_key_index(halign),                       .name = lua_key(halign),                       .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[valign_cmd]                       = (command_item) { .id = valign_cmd,                         .lua = lua_key_index(valign),                       .name = lua_key(valign),                       .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[vrule_cmd]                        = (command_item) { .id = vrule_cmd,                          .lua = lua_key_index(vrule),                        .name = lua_key(vrule),                        .kind = regular_command_item,   .min = first_rule_code,           .max = last_rule_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[hrule_cmd]                        = (command_item) { .id = hrule_cmd,                          .lua = lua_key_index(hrule),                        .name = lua_key(hrule),                        .kind = regular_command_item,   .min = first_rule_code,           .max = last_rule_code,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[insert_cmd]                       = (command_item) { .id = insert_cmd,                         .lua = lua_key_index(insert),                       .name = lua_key(insert),                       .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[vadjust_cmd]                      = (command_item) { .id = vadjust_cmd,                        .lua = lua_key_index(vadjust),                      .name = lua_key(vadjust),                      .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[ignore_something_cmd]             = (command_item) { .id = ignore_something_cmd,               .lua = lua_key_index(ignore_something),             .name = lua_key(ignore_something),             .kind = regular_command_item,   .min = 0,                         .max = last_ignore_something_code,   .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[after_something_cmd]              = (command_item) { .id = after_something_cmd,                .lua = lua_key_index(after_something),              .name = lua_key(after_something),              .kind = regular_command_item,   .min = 0,                         .max = last_after_something_code,    .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[penalty_cmd]                      = (command_item) { .id = penalty_cmd,                        .lua = lua_key_index(penalty),                      .name = lua_key(penalty),                      .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[begin_paragraph_cmd]              = (command_item) { .id = begin_paragraph_cmd,                .lua = lua_key_index(begin_paragraph),              .name = lua_key(begin_paragraph),              .kind = regular_command_item,   .min = 0,                         .max = last_begin_paragraph_code,    .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[italic_correction_cmd]            = (command_item) { .id = italic_correction_cmd,              .lua = lua_key_index(italic_correction),            .name = lua_key(italic_correction),            .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[accent_cmd]                       = (command_item) { .id = accent_cmd,                         .lua = lua_key_index(accent),                       .name = lua_key(accent),                       .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_accent_cmd]                  = (command_item) { .id = math_accent_cmd,                    .lua = lua_key_index(math_accent),                  .name = lua_key(math_accent),                  .kind = regular_command_item,   .min = 0,                         .max = last_math_accent_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[discretionary_cmd]                = (command_item) { .id = discretionary_cmd,                  .lua = lua_key_index(discretionary),                .name = lua_key(discretionary),                .kind = regular_command_item,   .min = 0,                         .max = last_discretionary_code,      .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[equation_number_cmd]              = (command_item) { .id = equation_number_cmd,                .lua = lua_key_index(equation_number),              .name = lua_key(equation_number),              .kind = regular_command_item,   .min = first_location_code,       .max = last_location_code,           .base = 0,                       .fixedvalue = 0            }; /* maybe dedicated codes */
    lmt_interface.command_names[math_fence_cmd]                   = (command_item) { .id = math_fence_cmd,                     .lua = lua_key_index(math_fence),                   .name = lua_key(math_fence),                   .kind = regular_command_item,   .min = first_fence_code,          .max = last_fence_code,              .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_component_cmd]               = (command_item) { .id = math_component_cmd,                 .lua = lua_key_index(math_component),               .name = lua_key(math_component),               .kind = regular_command_item,   .min = first_math_component_type, .max = last_math_component_type,     .base = 0,                       .fixedvalue = 0            }; /* a bit too tolerant */
    lmt_interface.command_names[math_modifier_cmd]                = (command_item) { .id = math_modifier_cmd,                  .lua = lua_key_index(math_modifier),                .name = lua_key(math_modifier),                .kind = regular_command_item,   .min = first_math_modifier_code,  .max = last_math_modifier_code,      .base = 0,                       .fixedvalue = 0            }; /* a bit too tolerant */
    lmt_interface.command_names[math_fraction_cmd]                = (command_item) { .id = math_fraction_cmd,                  .lua = lua_key_index(math_fraction),                .name = lua_key(math_fraction),                .kind = regular_command_item,   .min = 0,                         .max = last_math_fraction_code,      .base = 0,                       .fixedvalue = 0            }; /* partial */
    lmt_interface.command_names[math_style_cmd]                   = (command_item) { .id = math_style_cmd,                     .lua = lua_key_index(math_style),                   .name = lua_key(math_style),                   .kind = regular_command_item,   .min = 0,                         .max = last_math_style,              .base = 0,                       .fixedvalue = 0            }; /* partial */
    lmt_interface.command_names[math_choice_cmd]                  = (command_item) { .id = math_choice_cmd,                    .lua = lua_key_index(math_choice),                  .name = lua_key(math_choice),                  .kind = regular_command_item,   .min = 0,                         .max = last_math_choice_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[vcenter_cmd]                      = (command_item) { .id = vcenter_cmd,                        .lua = lua_key_index(vcenter),                      .name = lua_key(vcenter),                      .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[case_shift_cmd]                   = (command_item) { .id = case_shift_cmd,                     .lua = lua_key_index(case_shift),                   .name = lua_key(case_shift),                   .kind = regular_command_item,   .min = 0,                         .max = last_case_shift_code,         .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[message_cmd]                      = (command_item) { .id = message_cmd,                        .lua = lua_key_index(message),                      .name = lua_key(message),                      .kind = regular_command_item,   .min = 0,                         .max = last_message_code,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[catcode_table_cmd]                = (command_item) { .id = catcode_table_cmd,                  .lua = lua_key_index(catcode_table),                .name = lua_key(catcode_table),                .kind = regular_command_item,   .min = 0,                         .max = last_catcode_table_code,      .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[end_local_cmd]                    = (command_item) { .id = end_local_cmd,                      .lua = lua_key_index(end_local),                    .name = lua_key(end_local),                    .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[lua_function_call_cmd]            = (command_item) { .id = lua_function_call_cmd,              .lua = lua_key_index(lua_function_call),            .name = lua_key(lua_function_call),            .kind = reference_command_item, .min = 0,                         .max = max_function_reference,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[lua_protected_call_cmd]           = (command_item) { .id = lua_protected_call_cmd,             .lua = lua_key_index(lua_protected_call),           .name = lua_key(lua_protected_call),           .kind = reference_command_item, .min = 0,                         .max = max_function_reference,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[begin_group_cmd]                  = (command_item) { .id = begin_group_cmd,                    .lua = lua_key_index(begin_group),                  .name = lua_key(begin_group),                  .kind = regular_command_item,   .min = 0,                         .max = last_begin_group_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[end_group_cmd]                    = (command_item) { .id = end_group_cmd,                      .lua = lua_key_index(end_group),                    .name = lua_key(end_group),                    .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[explicit_space_cmd]               = (command_item) { .id = explicit_space_cmd,                 .lua = lua_key_index(explicit_space),               .name = lua_key(explicit_space),               .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[boundary_cmd]                     = (command_item) { .id = boundary_cmd,                       .lua = lua_key_index(boundary),                     .name = lua_key(boundary),                     .kind = regular_command_item,   .min = 0,                         .max = last_boundary_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_radical_cmd]                 = (command_item) { .id = math_radical_cmd,                   .lua = lua_key_index(math_radical),                 .name = lua_key(math_radical),                 .kind = regular_command_item,   .min = 0,                         .max = last_radical_code,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_script_cmd]                  = (command_item) { .id = math_script_cmd,                    .lua = lua_key_index(math_script),                  .name = lua_key(math_script),                  .kind = regular_command_item,   .min = 0,                         .max = last_math_script_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[math_shift_cs_cmd]                = (command_item) { .id = math_shift_cs_cmd,                  .lua = lua_key_index(math_shift_cs),                .name = lua_key(math_shift_cs),                .kind = regular_command_item,   .min = 0,                         .max = last_math_shift_cs_code,      .base = 0,                       .fixedvalue = 0            }; /* a bit too tolerant */
    lmt_interface.command_names[end_cs_name_cmd]                  = (command_item) { .id = end_cs_name_cmd,                    .lua = lua_key_index(end_cs_name),                  .name = lua_key(end_cs_name),                  .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[char_given_cmd]                   = (command_item) { .id = char_given_cmd,                     .lua = lua_key_index(char_given),                   .name = lua_key(char_given),                   .kind = character_command_item, .min = 0,                         .max = max_character_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[some_item_cmd]                    = (command_item) { .id = some_item_cmd,                      .lua = lua_key_index(some_item),                    .name = lua_key(some_item),                    .kind = regular_command_item,   .min = 0,                         .max = last_some_item_code,          .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[internal_toks_cmd]                = (command_item) { .id = internal_toks_cmd,                  .lua = lua_key_index(internal_toks),                .name = lua_key(internal_toks),                .kind = internal_command_item,  .min = first_toks_code,           .max = last_toks_code,               .base = internal_toks_base,      .fixedvalue = 0            };
    lmt_interface.command_names[register_toks_cmd]                = (command_item) { .id = register_toks_cmd,                  .lua = lua_key_index(register_toks),                .name = lua_key(register_toks),                .kind = register_command_item,  .min = 0,                         .max = biggest_reg,                  .base = register_toks_base,      .fixedvalue = 0            };
    lmt_interface.command_names[internal_int_cmd]                 = (command_item) { .id = internal_int_cmd,                   .lua = lua_key_index(internal_int),                 .name = lua_key(internal_int),                 .kind = internal_command_item,  .min = first_int_code,            .max = last_int_code,                .base = internal_int_base,       .fixedvalue = 0            };
    lmt_interface.command_names[register_int_cmd]                 = (command_item) { .id = register_int_cmd,                   .lua = lua_key_index(register_int),                 .name = lua_key(register_int),                 .kind = register_command_item,  .min = 0,                         .max = max_int_register_index,       .base = register_int_base,       .fixedvalue = 0            };
    lmt_interface.command_names[internal_attribute_cmd]           = (command_item) { .id = internal_attribute_cmd,             .lua = lua_key_index(internal_attribute),           .name = lua_key(internal_attribute),           .kind = unused_command_item,    .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_attribute_cmd]           = (command_item) { .id = register_attribute_cmd,             .lua = lua_key_index(register_attribute),           .name = lua_key(register_attribute),           .kind = register_command_item,  .min = 0,                         .max = max_attribute_register_index, .base = register_attribute_base, .fixedvalue = 0            };
    lmt_interface.command_names[internal_dimen_cmd]               = (command_item) { .id = internal_dimen_cmd,                 .lua = lua_key_index(internal_dimen),               .name = lua_key(internal_dimen),               .kind = internal_command_item,  .min = first_dimen_code,          .max = last_dimen_code,              .base = internal_dimen_base,     .fixedvalue = 0            };
    lmt_interface.command_names[register_dimen_cmd]               = (command_item) { .id = register_dimen_cmd,                 .lua = lua_key_index(register_dimen),               .name = lua_key(register_dimen),               .kind = register_command_item,  .min = 0,                         .max = max_dimen_register_index,     .base = register_dimen_base,     .fixedvalue = 0            };
    lmt_interface.command_names[internal_glue_cmd]                = (command_item) { .id = internal_glue_cmd,                  .lua = lua_key_index(internal_glue),                .name = lua_key(internal_glue),                .kind = internal_command_item,  .min = first_glue_code,           .max = last_glue_code,               .base = internal_glue_base,      .fixedvalue = 0            };
    lmt_interface.command_names[register_glue_cmd]                = (command_item) { .id = register_glue_cmd,                  .lua = lua_key_index(register_glue),                .name = lua_key(register_glue),                .kind = register_command_item,  .min = 0,                         .max = max_glue_register_index,      .base = register_glue_base,      .fixedvalue = 0            };
    lmt_interface.command_names[internal_mu_glue_cmd]             = (command_item) { .id = internal_mu_glue_cmd,               .lua = lua_key_index(internal_mu_glue),             .name = lua_key(internal_mu_glue),             .kind = internal_command_item,  .min = first_mu_glue_code,        .max = last_mu_glue_code,            .base = internal_mu_glue_base,   .fixedvalue = 0            };
    lmt_interface.command_names[register_mu_glue_cmd]             = (command_item) { .id = register_mu_glue_cmd,               .lua = lua_key_index(register_mu_glue),             .name = lua_key(register_mu_glue),             .kind = register_command_item,  .min = 0,                         .max = max_mu_glue_register_index,   .base = register_mu_glue_base,   .fixedvalue = 0            };
    lmt_interface.command_names[lua_value_cmd]                    = (command_item) { .id = lua_value_cmd,                      .lua = lua_key_index(lua_value),                    .name = lua_key(lua_value),                    .kind = reference_command_item, .min = 0,                         .max = max_function_reference,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[iterator_value_cmd]               = (command_item) { .id = iterator_value_cmd,                 .lua = lua_key_index(iterator_value),               .name = lua_key(iterator_value),               .kind = data_command_item,      .min = min_iterator_value,        .max = max_iterator_value,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_font_property_cmd]            = (command_item) { .id = set_font_property_cmd,              .lua = lua_key_index(set_font_property),            .name = lua_key(set_font_property),            .kind = regular_command_item,   .min = 0,                         .max = last_font_property_code,      .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_auxiliary_cmd]                = (command_item) { .id = set_auxiliary_cmd,                  .lua = lua_key_index(set_auxiliary),                .name = lua_key(set_auxiliary),                .kind = regular_command_item,   .min = 0,                         .max = last_auxiliary_code,          .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_page_property_cmd]            = (command_item) { .id = set_page_property_cmd,              .lua = lua_key_index(set_page_property),            .name = lua_key(set_page_property),            .kind = regular_command_item,   .min = 0,                         .max = last_page_property_code,      .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_box_property_cmd]             = (command_item) { .id = set_box_property_cmd,               .lua = lua_key_index(set_box_property),             .name = lua_key(set_box_property),             .kind = regular_command_item,   .min = 0,                         .max = last_box_property_code,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_specification_cmd]            = (command_item) { .id = set_specification_cmd,              .lua = lua_key_index(set_specification),            .name = lua_key(set_specification),            .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[define_char_code_cmd]             = (command_item) { .id = define_char_code_cmd,               .lua = lua_key_index(define_char_code),             .name = lua_key(define_char_code),             .kind = regular_command_item,   .min = 0,                         .max = last_charcode_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[define_family_cmd]                = (command_item) { .id = define_family_cmd,                  .lua = lua_key_index(define_family),                .name = lua_key(define_family),                .kind = regular_command_item,   .min = 0,                         .max = last_math_size,               .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_math_parameter_cmd]           = (command_item) { .id = set_math_parameter_cmd,             .lua = lua_key_index(set_math_parameter),           .name = lua_key(set_math_parameter),           .kind = regular_command_item,   .min = 0,                         .max = last_math_parameter,          .base = 0,                       .fixedvalue = 0            };
 // lmt_interface.command_names[set_font_cmd]                     = (command_item) { .id = set_font_cmd,                       .lua = lua_key_index(set_font),                     .name = lua_key(set_font),                     .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[set_font_cmd]                     = (command_item) { .id = set_font_cmd,                       .lua = lua_key_index(set_font),                     .name = lua_key(set_font),                     .kind = data_command_item,      .min = 0,                         .max = max_font_size,                .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[define_font_cmd]                  = (command_item) { .id = define_font_cmd,                    .lua = lua_key_index(define_font),                  .name = lua_key(define_font),                  .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[integer_cmd]                      = (command_item) { .id = integer_cmd,                        .lua = lua_key_index(integer),                      .name = lua_key(integer),                      .kind = data_command_item,      .min = min_integer,               .max = max_integer,                  .base = direct_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[dimension_cmd]                    = (command_item) { .id = dimension_cmd,                      .lua = lua_key_index(dimension),                    .name = lua_key(dimension),                    .kind = data_command_item,      .min = min_dimen,                 .max = max_dimen,                    .base = direct_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[gluespec_cmd]                     = (command_item) { .id = gluespec_cmd,                       .lua = lua_key_index(gluespec),                     .name = lua_key(gluespec),                     .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[mugluespec_cmd]                   = (command_item) { .id = mugluespec_cmd,                     .lua = lua_key_index(mugluespec),                   .name = lua_key(mugluespec),                   .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[mathspec_cmd]                     = (command_item) { .id = mathspec_cmd,                       .lua = lua_key_index(mathspec),                     .name = lua_key(fontspec),                     .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[fontspec_cmd]                     = (command_item) { .id = fontspec_cmd,                       .lua = lua_key_index(fontspec),                     .name = lua_key(fontspec),                     .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_cmd]                     = (command_item) { .id = register_cmd,                       .lua = lua_key_index(register),                     .name = lua_key(register),                     .kind = regular_command_item,   .min = first_value_level,         .max = last_value_level,             .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[combine_toks_cmd]                 = (command_item) { .id = combine_toks_cmd,                   .lua = lua_key_index(combine_toks),                 .name = lua_key(combine_toks),                 .kind = regular_command_item,   .min = 0,                         .max = last_combine_toks_code,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[arithmic_cmd]                     = (command_item) { .id = arithmic_cmd,                       .lua = lua_key_index(arithmic),                     .name = lua_key(arithmic),                     .kind = regular_command_item,   .min = 0,                         .max = last_arithmic_code,           .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[prefix_cmd]                       = (command_item) { .id = prefix_cmd,                         .lua = lua_key_index(prefix),                       .name = lua_key(prefix),                       .kind = regular_command_item,   .min = 0,                         .max = last_prefix_code,             .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[let_cmd]                          = (command_item) { .id = let_cmd,                            .lua = lua_key_index(let),                          .name = lua_key(let),                          .kind = regular_command_item,   .min = 0,                         .max = last_let_code,                .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[shorthand_def_cmd]                = (command_item) { .id = shorthand_def_cmd,                  .lua = lua_key_index(shorthand_def),                .name = lua_key(shorthand_def),                .kind = regular_command_item,   .min = 0,                         .max = last_shorthand_def_code,      .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[def_cmd]                          = (command_item) { .id = def_cmd,                            .lua = lua_key_index(def),                          .name = lua_key(def),                          .kind = regular_command_item,   .min = 0,                         .max = last_def_code,                .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_box_cmd]                      = (command_item) { .id = set_box_cmd,                        .lua = lua_key_index(set_box),                      .name = lua_key(set_box),                      .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[hyphenation_cmd]                  = (command_item) { .id = hyphenation_cmd,                    .lua = lua_key_index(hyphenation),                  .name = lua_key(hyphenation),                  .kind = regular_command_item,   .min = 0,                         .max = last_hyphenation_code,        .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[set_interaction_cmd]              = (command_item) { .id = set_interaction_cmd,                .lua = lua_key_index(set_interaction),              .name = lua_key(set_interaction),              .kind = regular_command_item,   .min = 0,                         .max = last_interaction_level,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[undefined_cs_cmd]                 = (command_item) { .id = undefined_cs_cmd,                   .lua = lua_key_index(undefined_cs),                 .name = lua_key(undefined_cs),                 .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[expand_after_cmd]                 = (command_item) { .id = expand_after_cmd,                   .lua = lua_key_index(expand_after),                 .name = lua_key(expand_after),                 .kind = regular_command_item,   .min = 0,                         .max = last_expand_after_code,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[no_expand_cmd]                    = (command_item) { .id = no_expand_cmd,                      .lua = lua_key_index(no_expand),                    .name = lua_key(no_expand),                    .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[input_cmd]                        = (command_item) { .id = input_cmd,                          .lua = lua_key_index(input),                        .name = lua_key(input),                        .kind = regular_command_item,   .min = 0,                         .max = last_input_code,              .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[lua_call_cmd]                     = (command_item) { .id = lua_call_cmd,                       .lua = lua_key_index(lua_call),                     .name = lua_key(lua_call),                     .kind = reference_command_item, .min = 0,                         .max = max_function_reference,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[lua_local_call_cmd]               = (command_item) { .id = lua_local_call_cmd,                 .lua = lua_key_index(lua_local_call),               .name = lua_key(lua_local_call),               .kind = reference_command_item, .min = 0,                         .max = max_function_reference,       .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[begin_local_cmd]                  = (command_item) { .id = begin_local_cmd,                    .lua = lua_key_index(begin_local),                  .name = lua_key(begin_local),                  .kind = regular_command_item,   .min = 0,                         .max = 0,                            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[if_test_cmd]                      = (command_item) { .id = if_test_cmd,                        .lua = lua_key_index(if_test),                      .name = lua_key(if_test),                      .kind = regular_command_item,   .min = first_if_test_code,        .max = last_if_test_code,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[cs_name_cmd]                      = (command_item) { .id = cs_name_cmd,                        .lua = lua_key_index(cs_name),                      .name = lua_key(cs_name),                      .kind = regular_command_item,   .min = 0,                         .max = last_cs_name_code,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[convert_cmd]                      = (command_item) { .id = convert_cmd,                        .lua = lua_key_index(convert),                      .name = lua_key(convert),                      .kind = regular_command_item,   .min = 0,                         .max = last_convert_code,            .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[the_cmd]                          = (command_item) { .id = the_cmd,                            .lua = lua_key_index(the),                          .name = lua_key(the),                          .kind = regular_command_item,   .min = 0,                         .max = last_the_code,                .base = 0,                       .fixedvalue = 0            };
    lmt_interface.command_names[get_mark_cmd]                     = (command_item) { .id = get_mark_cmd,                       .lua = lua_key_index(get_mark),                     .name = lua_key(get_mark),                     .kind = regular_command_item,   .min = 0,                         .max = last_get_mark_code,           .base = 0,                       .fixedvalue = 0            };
 /* lmt_interface.command_names[string_cmd]                       = (command_item) { .id = string_cmd,                         .lua = lua_key_index(string),                       .name = lua_key(string),                       .kind = regular_command_item,   .min = ignore_entry,              .max = max_integer,                  .base = 0,                       .fixedvalue = 0            }; */
    lmt_interface.command_names[call_cmd]                         = (command_item) { .id = call_cmd,                           .lua = lua_key_index(call),                         .name = lua_key(call),                         .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[protected_call_cmd]               = (command_item) { .id = protected_call_cmd,                 .lua = lua_key_index(protected_call),               .name = lua_key(protected_call),               .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[semi_protected_call_cmd]          = (command_item) { .id = semi_protected_call_cmd,            .lua = lua_key_index(protected_call),               .name = lua_key(protected_call),               .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[tolerant_call_cmd]                = (command_item) { .id = tolerant_call_cmd,                  .lua = lua_key_index(tolerant_call),                .name = lua_key(tolerant_call),                .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[tolerant_protected_call_cmd]      = (command_item) { .id = tolerant_protected_call_cmd,        .lua = lua_key_index(tolerant_protected_call),      .name = lua_key(tolerant_protected_call),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[tolerant_semi_protected_call_cmd] = (command_item) { .id = tolerant_semi_protected_call_cmd,   .lua = lua_key_index(tolerant_protected_call),      .name = lua_key(tolerant_protected_call),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[deep_frozen_end_template_cmd]     = (command_item) { .id = deep_frozen_end_template_cmd,       .lua = lua_key_index(deep_frozen_cs_end_template),  .name = lua_key(deep_frozen_cs_end_template),  .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[deep_frozen_dont_expand_cmd]      = (command_item) { .id = deep_frozen_dont_expand_cmd,        .lua = lua_key_index(deep_frozen_cs_dont_expand),   .name = lua_key(deep_frozen_cs_dont_expand),   .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_glue_reference_cmd]      = (command_item) { .id = internal_glue_reference_cmd,        .lua = lua_key_index(internal_glue_reference),      .name = lua_key(internal_glue_reference),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_glue_reference_cmd]      = (command_item) { .id = register_glue_reference_cmd,        .lua = lua_key_index(register_glue_reference),      .name = lua_key(register_glue_reference),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_mu_glue_reference_cmd]   = (command_item) { .id = internal_mu_glue_reference_cmd,     .lua = lua_key_index(internal_mu_glue_reference),   .name = lua_key(internal_mu_glue_reference),   .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_mu_glue_reference_cmd]   = (command_item) { .id = register_mu_glue_reference_cmd,     .lua = lua_key_index(register_mu_glue_reference),   .name = lua_key(register_mu_glue_reference),   .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_box_reference_cmd]       = (command_item) { .id = internal_box_reference_cmd,         .lua = lua_key_index(specification_reference),      .name = lua_key(specification_reference),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_box_reference_cmd]       = (command_item) { .id = register_box_reference_cmd,         .lua = lua_key_index(internal_box_reference),       .name = lua_key(internal_box_reference),       .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_toks_reference_cmd]      = (command_item) { .id = internal_toks_reference_cmd,        .lua = lua_key_index(register_box_reference),       .name = lua_key(register_box_reference),       .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_toks_reference_cmd]      = (command_item) { .id = register_toks_reference_cmd,        .lua = lua_key_index(internal_toks_reference),      .name = lua_key(internal_toks_reference),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[specification_reference_cmd]      = (command_item) { .id = specification_reference_cmd,        .lua = lua_key_index(register_toks_reference),      .name = lua_key(register_toks_reference),      .kind = token_command_item,     .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_int_reference_cmd]       = (command_item) { .id = internal_int_reference_cmd,         .lua = lua_key_index(internal_int_reference),       .name = lua_key(internal_int_reference),       .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_int_reference_cmd]       = (command_item) { .id = register_int_reference_cmd,         .lua = lua_key_index(register_int_reference),       .name = lua_key(register_int_reference),       .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_attribute_reference_cmd] = (command_item) { .id = internal_attribute_reference_cmd,   .lua = lua_key_index(internal_attribute_reference), .name = lua_key(internal_attribute_reference), .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_attribute_reference_cmd] = (command_item) { .id = register_attribute_reference_cmd,   .lua = lua_key_index(register_attribute_reference), .name = lua_key(register_attribute_reference), .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[internal_dimen_reference_cmd]     = (command_item) { .id = internal_dimen_reference_cmd,       .lua = lua_key_index(internal_dimen_reference),     .name = lua_key(internal_dimen_reference),     .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_dimen_reference_cmd]     = (command_item) { .id = register_dimen_reference_cmd,       .lua = lua_key_index(register_dimen_reference),     .name = lua_key(register_dimen_reference),     .kind = regular_command_item,   .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };
    lmt_interface.command_names[register_dimen_reference_cmd + 1] = (command_item) { .id = unknown_value,                      .lua = 0,                                           .name = NULL,                                  .kind = unused_command_item,    .min = ignore_entry,              .max = ignore_entry,                 .base = ignore_entry,            .fixedvalue = 0            };

    if (lmt_interface.command_names[last_cmd].id != last_cmd) {
        tex_fatal_error("mismatch between tex and lua command name tables");
    }
}

typedef struct saved_tex_scanner {
    int cmd;
    int chr;
    int cs;
    int tok;
} saved_tex_scanner;

inline static saved_tex_scanner tokenlib_aux_save_tex_scanner(void) {
    return (saved_tex_scanner) {
        .cmd = cur_cmd,
        .chr = cur_chr,
        .cs  = cur_cs,
        .tok = cur_tok
    };
}

inline static void tokenlib_aux_unsave_tex_scanner(saved_tex_scanner a)
{
    cur_cmd = a.cmd;
    cur_chr = a.chr;
    cur_cs  = a.cs;
    cur_tok = a.tok;
}

static int tokenlib_aux_get_command_id(const char *s)
{
    for (int i = 0; lmt_interface.command_names[i].id != -1; i++) {
        if (s == lmt_interface.command_names[i].name) {
            return i;
        }
    }
    return -1;
}

/*tex
    We have some checkers that use the information from |command_names|:

    \startitemize
    \startitem the 0..64K counter, dimen, token etc registers \stopitem
    \startitem the predefined internal quantities \stopitem
    \stopitemize
*/

/*
inline static int tokenlib_valid_cmd(int cmd)
{
    return cmd >= first_cmd && cmd <= last_cmd;
}
*/

inline static int tokenlib_aux_valid_chr(int cmd, int chr)
{
    command_item item = lmt_interface.command_names[cmd];
    if (chr > 0) {
        switch (item.base) {
            case ignore_entry:
            case direct_entry:
                break;
            default:
                if (chr >= item.min && chr <= item.max) {
                    return item.base + chr;
                }
        }
    } else if (chr == item.fixedvalue) {
        return chr;
    }
    return 0;
}

inline static int tokenlib_aux_valid_cs(int cs)
{
    return (cs >= 0 && cs <= lmt_token_memory_state.tokens_data.allocated) ? cs : -1;
}

// not ok

inline static int tokenlib_aux_valid_token(int cmd, int chr, int cs)
{
    if (cs) {
        cs = tokenlib_aux_valid_cs(cs);
        if (cs >= 0) {
            return cs_token_flag + cs;
        }
    } if (cmd >= first_cmd && cmd <= last_cmd) {
        chr = tokenlib_aux_valid_chr(cmd, chr);
        if (chr >= 0) {
            return token_val(cmd, chr);
        }
    }
    return -1;
}

inline static int tokenlib_aux_to_valid_index(int cmd, int chr)
{
    if (cmd >= 0 && cmd <= last_cmd) {
        command_item item = lmt_interface.command_names[cmd];
        switch (item.kind) {
            case unused_command_item:
                 return 0;
            case regular_command_item:
            case character_command_item:
                 return chr;
            case register_command_item:
            case internal_command_item:
            case reference_command_item:
            case data_command_item:
                switch (item.base) {
                    case ignore_entry:
                        return 0;
                    case direct_entry:
                        break;
                    default:
                        chr -= item.base;
                        break;
                }
                return (chr >= item.min && chr <= item.max) ? chr : item.min;
            case token_command_item:
            case node_command_item:
                return item.fixedvalue;
        }
    }
    return 0;
}

inline static void tokenlib_aux_make_token_table(lua_State *L, int cmd, int chr, int cs)
{
    lua_createtable(L, 3, 0);
    lua_pushinteger(L, cmd);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L, tokenlib_aux_to_valid_index(cmd, chr)); /* index or value */
    lua_rawseti(L, -2, 2);
    lua_pushinteger(L, cs);
    lua_rawseti(L, -2, 3);
}

/*tex

    Takes a table |{ cmd, chr, cs }| where either the first two are taken or the last one. This is
    something historic. So we have either |{ cmd, chr, - }| or |{ -, -, cs}| to deal with. This
    might change in the future but we then need to check all usage in \CONTEXT\ first.
*/

inline static int lmt_token_from_lua(lua_State *L)
{
    int cmd, chr, cs;
    lua_rawgeti(L, -1, 1);
    cmd = lmt_tointeger(L, -1);
    lua_rawgeti(L, -2, 2);
    chr = lmt_optinteger(L, -1, 0);
    lua_rawgeti(L, -3, 3);
    cs = lmt_optinteger(L, -1, 0);
    lua_pop(L, 3);
    return tokenlib_aux_valid_token(cmd, chr, cs); /* just the token value */
}

void lmt_token_list_to_lua(lua_State *L, halfword p)
{
    int i = 1;
    int v = p;
    int max = lmt_token_memory_state.tokens_data.top; /*tex It doesn't change here. */
    while (v && v < max) {
        i++;
        v = token_link(v);
    }
    lua_createtable(L, i, 0);
    i = 1;
    while (p && p < max) {
        int cmd, chr, cs;
        if (token_info(p) >= cs_token_flag) {
            cs = token_info(p) - cs_token_flag;
            cmd = eq_type(cs);
            chr = eq_value(cs);
        } else {
            cs = 0;
            cmd = token_cmd(token_info(p));
            chr = token_chr(token_info(p));
        }
        tokenlib_aux_make_token_table(L, cmd, chr, cs);
        lua_rawseti(L, -2, i++);
        p = token_link(p);
    }
}

void lmt_token_list_to_luastring(lua_State *L, halfword p, int nospace, int strip, int wipe)
{
    int l;
    char *s = tex_tokenlist_to_tstring(p, 1, &l, 0, nospace, strip, wipe); /* nasty ... preambles or not, could have been endmatchtoken  */
    if (l) {
        lua_pushlstring(L, s, (size_t) l);
    } else {
        lua_pushliteral(L, "");
    }
}

static lua_token *tokenlib_aux_check_istoken(lua_State *L, int ud);

halfword lmt_token_list_from_lua(lua_State *L, int slot)
{
    halfword h = tex_get_available_token(null);
    halfword p = h;
    token_link(h) = null;
    switch (lua_type(L, slot)) {
        case LUA_TTABLE:
            {
                int j = (int) lua_rawlen(L, slot);
                if (j > 0) {
                    for (int i = 1; i <= j; i++) {
                        int tok;
                        lua_rawgeti(L, slot, (int) i);
                        tok = lmt_token_from_lua(L);
                        if (tok >= 0) {
                            p = tex_store_new_token(p, tok);
                        }
                        lua_pop(L, 1);
                    };
                }
                return h;
            }
        case LUA_TSTRING:
            {
                size_t j;
                const char *s = lua_tolstring(L, slot, &j);
                for (size_t i = 0; i < j; i++) {
                    int tok;
                    if (s[i] == ascii_space) {
                        tok = token_val(spacer_cmd, s[i]);
                    } else {
                        int k = (int) aux_str2uni((const unsigned char *) (s + i));
                        i = i + (size_t) (utf8_size(k)) - 1;
                        tok = token_val(other_char_cmd, k);
                    }
                    p = tex_store_new_token(p, tok);
                }
                return h;
            }
        case LUA_TUSERDATA:
            {
                lua_token *t = tokenlib_aux_check_istoken(L, slot);
                p = tex_store_new_token(p, t->token);
                return h;
            }
        default:
            {
                tex_put_available_token(h);
                return null;
            }
    }
}

halfword lmt_token_code_from_lua(lua_State *L, int slot)
{
    lua_token *t = tokenlib_aux_check_istoken(L, slot);
    return t->token;
}

# define DEFAULT_SCAN_CODE_SET (2048 + 4096) /*tex default: letter and other */

/*tex two core helpers .. todo: combine active*/

# define is_active_string(s) (strlen(s) > 3 && *s == 0xEF && *(s+1) == 0xBF && *(s+2) == 0xBF)

static unsigned char *tokenlib_aux_get_cs_text(int cs, int *allocated)
{
    if (cs == null_cs) {
        return (unsigned char *) "\\csname\\endcsname";
    } else if ((cs_text(cs) < 0) || (cs_text(cs) >= lmt_string_pool_state.string_pool_data.ptr)) {
        return (unsigned char *) "";
 // } else {
 //     return (unsigned char *) tex_makecstring(cs_text(cs));
    } else if (cs_text(cs) < cs_offset_value) {
        *allocated = 1;
        return (unsigned char *) aux_uni2str((unsigned) cs_text(cs));
    } else {
        return (unsigned char *) (str_length(cs_text(cs)) > 0 ?  (unsigned char *) str_string(cs_text(cs)) :  (unsigned char *) "");
    }
}

static lua_token *tokenlib_aux_maybe_istoken(lua_State *L, int ud)
{
    lua_token *t = lua_touserdata(L, ud);
    if (t && lua_getmetatable(L, ud)) {
        lua_get_metatablelua(token_instance);
        if (! lua_rawequal(L, -1, -2)) {
            t = NULL;
        }
        lua_pop(L, 2);
    }
    return t;
}

static lua_token_package *tokenlib_aux_maybe_ispackage(lua_State *L, int ud)
{
    lua_token_package *t = lua_touserdata(L, ud);
    if (t && lua_getmetatable(L, ud)) {
        lua_get_metatablelua(token_package);
        if (! lua_rawequal(L, -1, -2)) {
            t = NULL;
        }
        lua_pop(L, 2);
    }
    return t;
}

/*tex we could make the message a function and just inline the rest (via a macro) */

lua_token *tokenlib_aux_check_istoken(lua_State *L, int ud)
{
    lua_token *t = tokenlib_aux_maybe_istoken(L, ud);
    if (! t) {
        tex_formatted_error("token lib", "lua <token> expected, not an object with type %s", luaL_typename(L, ud));
    }
    return t;
}

static lua_token_package *tokenlib_aux_check_ispackage(lua_State *L, int ud)
{
    lua_token_package *t = tokenlib_aux_maybe_ispackage(L, ud);
    if (! t) {
        tex_formatted_error("token lib", "lua <token package> expected, not an object with type %s", luaL_typename(L, ud));
    }
    return t;
}

/*tex token library functions */

static void tokenlib_aux_make_new_token(lua_State *L, int cmd, int chr, int cs)
{
    int tok = tokenlib_aux_valid_token(cmd, chr, cs);
    if (tok >= 0) {
        lua_token *thetok = (lua_token *) lua_newuserdatauv(L, sizeof(lua_token), 0);
        thetok->token = tex_get_available_token(tok);
        thetok->origin = token_origin_lua;
        lua_get_metatablelua(token_instance);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }
}

static void tokenlib_aux_make_new_token_tok(lua_State *L, int tok)
{
    if (tok >= 0) {
        lua_token *thetok = (lua_token *) lua_newuserdatauv(L, sizeof(lua_token), 0);
        thetok->token = tex_get_available_token(tok);
        thetok->origin = token_origin_lua;
        lua_get_metatablelua(token_instance);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }
}

static void tokenlib_aux_make_new_package(lua_State *L, singleword cmd, singleword flag, int chr, int cs, quarterword how)
{
    lua_token_package *package = (lua_token_package *) lua_newuserdatauv(L, sizeof(lua_token_package), 0);
    package->cmd = cmd;
    package->flag = flag;
    package->chr = chr;
    package->cs = cs;
    package->how = how;
    lua_get_metatablelua(token_package);
    lua_setmetatable(L, -2);
}

static void tokenlib_aux_push_token(lua_State *L, int tok)
{
    lua_token *thetok = (lua_token *) lua_newuserdatauv(L, sizeof(lua_token), 0);
    thetok->token = tok;
    thetok->origin = token_origin_lua;
    lua_get_metatablelua(token_instance);
    lua_setmetatable(L, -2);
}

static int tokenlib_getcommandid(lua_State *L)
{
    int id = -1;
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            id = tokenlib_aux_get_command_id(lua_tostring(L, 1));
            break;
        case LUA_TNUMBER:
            id = lmt_tointeger(L, 1);
            break;
    }
    if (id >= 0 && id < number_glue_pars) {
        lua_pushinteger(L, id);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int tokenlib_scan_next(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    halfword tok = tex_get_token();
    tokenlib_aux_make_new_token_tok(L, tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_next_expanded(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    halfword tok = tex_get_x_token();
    tokenlib_aux_make_new_token_tok(L, tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_skip_next(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    (void) L;
    tex_get_token();
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 0;
}

static int tokenlib_skip_next_expanded(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    (void) L;
    tex_get_x_token();
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 0;
}

/*tex

    This is experimental code:

        \starttyping
        local t1 = token.get_next()
        local t2 = token.get_next()
        local t3 = token.get_next()
        local t4 = token.get_next()
        -- watch out, we flush in sequence
        token.put_next { t1, t2 }
        -- but this one gets pushed in front
        token.put_next ( t3, t4 )
        -- so when we get wxyz we put yzwx!
        \stoptyping

    At some point we can consider a token.print that delays and goes via the same rope mechanism as
    |texio.print| and friends but then one can as well serialize the tokens and do a normal print so
    there is no real gain in it. After all, the tokenlib operates at the input level so we might as
    well keep it there.

*/

inline static int tokenlib_aux_to_token_val(int chr)
{
    switch (chr) {
        case '\n':
        case '\r':
        case ' ':
            return token_val(spacer_cmd, ' ');
        default:
            {
                int cmd = tex_get_cat_code(cat_code_table_par, chr);
                switch (cmd) {
                    case escape_cmd:
                    case ignore_cmd:
                    case comment_cmd:
                    case invalid_char_cmd:
                    case active_char_cmd:
                        cmd = other_char_cmd;
                        break;
                }
                return token_val(cmd, chr);
            }
    }
}

/*tex
    The original implementation was a bit different in the sense that I distinguished between one or
    more arguments with the one argument case handling a table. The reason was that I considered
    having an optional second argument that could control the catcode table.

    In the end this function is not used that often (of at all), so after checking the manual, I
    decided not to provide that feature so the code could be simplified a bit. But, as compensation,
    nested tables became possible.
*/

static void tokenlib_aux_to_token(lua_State *L, int i, int m, int *head, int *tail)
{
    switch (lua_type(L, i)) {
        case LUA_TSTRING:
            /*tex More efficient is to iterate (but then we also need to know the length). */
            {
                size_t l = 0;
                const char *s = lua_tolstring(L, i, &l);
                const unsigned char *p = (const unsigned char *) s;
                size_t n = aux_utf8len(s, l);
                for (size_t j = 0; j < n; j++) {
                    int ch = *p;
                    halfword x = tex_get_available_token(tokenlib_aux_to_token_val(aux_str2uni(p)));
                    if (*head) {
                        token_link(*tail) = x;
                    } else {
                        *head = x;
                    }
                    *tail = x;
                    p += utf8_size(ch);
                }
                break;
            }
        case LUA_TNUMBER:
            {
                halfword t = tex_get_available_token(tokenlib_aux_to_token_val((int) lua_tointeger(L, i)));
                if (*head) {
                    token_link(*tail) = t;
                } else {
                    *head = t;
                }
                *tail = t;
                break;
            }
        case LUA_TTABLE:
            {
                size_t n = lua_rawlen(L, i);
                for (size_t j = 1; j <= n; j++) {
                    lua_rawgeti(L, i, j);
                    tokenlib_aux_to_token(L, -1, m, head, tail);
                    lua_pop(L, 1);
                }
                break;
            }
        case LUA_TUSERDATA:
            {
                /* todo: like nodelib: |maybe_is_token|. */
                lua_token *p = lua_touserdata(L, i);
                halfword t, q;
                if (p && lua_getmetatable(L, i)) {
                    t = lua_rawequal(L, m, -1) ? token_info(p->token) : tokenlib_aux_to_token_val(0xFFFD);
                    lua_pop(L, 1); /* The metatable. */
                } else {
                    t = tokenlib_aux_to_token_val(0xFFFD);
                }
                q = tex_get_available_token(t);
                if (*head) {
                    token_link(*tail) = q;
                } else {
                    *head = q;
                }
                *tail = q;
                break;
            }
        default:
            /*tex Just ignore it. */
            break;
    }
}

inline static int tokenlib_put_next(lua_State *L)
{
    int top = lua_gettop(L);
    if (top > 0) {
        halfword h = null;
        halfword t = null;
        int m = top + 1;
        lua_get_metatablelua(token_instance);
        for (int i = 1; i <= top; i++) {
            tokenlib_aux_to_token(L, i, m, &h, &t);
        }
        if (h) {
            tex_begin_inserted_list(h);
        }
        lua_settop(L, top);
    }
    return 0;
}

inline static int tokenlib_put_back(lua_State *L)
{
    lua_token *t = tokenlib_aux_check_istoken(L, 1);
    if (t) {
        tex_back_input(token_info(t->token));
    }
    return 0;
}

static int tokenlib_scan_keyword(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    int v = 0;
    if (s) {
        saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
        v = tex_scan_keyword(s);
        tokenlib_aux_unsave_tex_scanner(texstate);
    }
    lua_pushboolean(L, v);
    return 1;
}

static int tokenlib_scan_keyword_cs(lua_State *L)
{
    const char *s = lua_tostring(L, 1);
    int v = 0;
    if (s) {
        saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
        v = tex_scan_keyword_case_sensitive(s);
        tokenlib_aux_unsave_tex_scanner(texstate);
    }
    lua_pushboolean(L, v);
    return 1;
}

static int tokenlib_scan_csname(lua_State *L)
{
    int t;
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    if (lua_toboolean(L, 1)) {
        /*tex unchecked (maybe backport this option to luatex) */
        do {
            tex_get_token();
        } while (cur_tok == space_token);
    } else {
        /*tex checked */
        tex_get_next();
    }
    t = cur_cs ? cs_token_flag + cur_cs : token_val (cur_cmd, cur_chr);
    if (t >= cs_token_flag) {
        int allocated = 0;
        unsigned char *s = tokenlib_aux_get_cs_text(t - cs_token_flag, &allocated);
        if (s) {
            if (tex_is_active_cs(cs_text(t - cs_token_flag))) {
                lua_pushstring(L, (char *) (s + 3));
            } else {
                lua_pushstring(L, (char *) s);
            }
            if (allocated) {
                lmt_memory_free(s);
            }
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_integer(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int eq = lua_toboolean(L, 1);
    halfword v = tex_scan_int(eq, NULL);
    lua_pushinteger(L, (int) v);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_cardinal(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    unsigned int v = 0;
    tex_scan_cardinal(&v, 0);
    lua_pushinteger(L, (unsigned int) v);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_gobble_integer(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int eq = lua_toboolean(L, 1);
    lmt_error_state.intercept = 1;
    lmt_error_state.last_intercept = 0;
    tex_scan_int(eq, NULL);
    lua_pushboolean(L, ! lmt_error_state.last_intercept);
    lmt_error_state.intercept = 0;
    lmt_error_state.last_intercept = 0;
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

inline static void tokenlib_aux_goto_first_candidate(void)
{
    do {
        tex_get_token();
    } while (cur_cmd == spacer_cmd);
}

inline static void tokenlib_aux_goto_first_candidate_x(void)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
}

inline static void tokenlib_aux_add_utf_char_to_buffer(luaL_Buffer *b, halfword chr)
{
    if (chr <= ascii_max) {
        luaL_addchar(b, (unsigned char) chr);
    } else {
        /*
        unsigned char word[5 + 1];
        char *uindex = aux_uni2string((char *) word, (unsigned int) chr);
        *uindex = '\0';
        luaL_addstring(b, (char *) word);
        */
        unsigned char word[5 + 1];
        aux_uni2string((char *) word, (unsigned int) chr);
        luaL_addlstring(b, (char *) word, utf8_size(chr));
    }
}

/*tex
    We could of course work with sets or ranges but the bit of duplicate code doesn't harm that
    much. The hexadecimal variant also deals with \LUA\ serialized numbers like |123.345E67| being
    equivalent to |0x1.6e0276db950fp+229| (as output by the |q| formatter option).

    Nota Bene: |DECIMAL| can be defined as macro or whatever else; the ms compiler reports an error,
    so we use |SCANDECIMAL| instead.
*/

static int tokenlib_scan_float_indeed(lua_State *L, int exponent, int hexadecimal)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int negative = 0;
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    tokenlib_aux_goto_first_candidate_x();
    if (lua_toboolean(L, 1) && (cur_tok == equal_token)) {
        tokenlib_aux_goto_first_candidate_x();
    }
    /*tex we collapse as in |scan_dimen| */
    while(1) {
        if (cur_tok == minus_token) {
            negative = ! negative;
        } else if (cur_tok != plus_token) {
            break;
        }
        tokenlib_aux_goto_first_candidate_x();
    }
    if (negative) {
        luaL_addchar(&b, '-');
    }
    /*tex we accept |[.,]digits| */
    if (hexadecimal && (cur_tok == zero_token)) {
        luaL_addchar(&b, '0');
        tex_get_x_token();
        if (tex_token_is_hexadecimal(cur_tok)) {
            luaL_addchar(&b, 'x');
            goto SCANHEXADECIMAL;
        } else {
            goto PICKUPDECIMAL;
        }
    } else {
        goto SCANDECIMAL;
    }
  SCANDECIMAL:
    if (tex_token_is_seperator(cur_tok)) {
        luaL_addchar(&b, '.');
        while (1) {
            tex_get_x_token();
            if (tex_token_is_digit(cur_tok)) {
                luaL_addchar(&b, (unsigned char) cur_chr);
            } else if (exponent) {
                goto DECIMALEXPONENT;
            } else {
                tex_back_input(cur_tok);
                goto DONE;
            }
        }
    } else {
        goto PICKUPDECIMAL;
    }
    while (1) {
        tex_get_x_token();
      PICKUPDECIMAL:
        if (tex_token_is_digit(cur_tok)) {
            luaL_addchar(&b, (unsigned char) cur_chr);
        } else if (tex_token_is_seperator(cur_tok)) {
            luaL_addchar(&b, '.');
            while (1) {
                tex_get_x_token();
                if (tex_token_is_digit(cur_tok)) {
                    luaL_addchar(&b, (unsigned char) cur_chr);
                } else {
                    tex_back_input(cur_tok);
                    break;
                }
            }
        } else if (exponent) {
            goto DECIMALEXPONENT;
        } else {
            tex_back_input(cur_tok);
            goto DONE;
        }
    }
  DECIMALEXPONENT:
    if (tex_token_is_exponent(cur_tok)) {
        luaL_addchar(&b, (unsigned char) cur_chr);
        tex_get_x_token();
        if (tex_token_is_sign(cur_tok)) {
            luaL_addchar(&b, (unsigned char) cur_chr);
        } else if (tex_token_is_digit(cur_tok)) {
            luaL_addchar(&b, (unsigned char) cur_chr);
        }
        while (1) {
            tex_get_x_token();
            if (tex_token_is_digit(cur_tok)) {
                luaL_addchar(&b, (unsigned char) cur_chr);
            } else {
                break;
            }
        }
    }
    tex_back_input(cur_tok);
    goto DONE;
  SCANHEXADECIMAL:
    tex_get_x_token();
    if (tex_token_is_seperator(cur_tok)) {
       luaL_addchar(&b, '.');
        while (1) {
            tex_get_x_token();
            if (tex_token_is_xdigit(cur_tok)) {
                luaL_addchar(&b, (unsigned char) cur_chr);
            } else if (exponent) {
                goto HEXADECIMALEXPONENT;
            } else {
                tex_back_input(cur_tok);
                goto DONE;
            }
        }
    } else {
        /* hm, we could avoid this pushback */
        tex_back_input(cur_tok);
        while (1) {
            tex_get_x_token();
            if (tex_token_is_xdigit(cur_tok)) {
                luaL_addchar(&b, (unsigned char) cur_chr);
            } else if (tex_token_is_seperator(cur_tok)) {
                luaL_addchar(&b, '.');
                while (1) {
                    tex_get_x_token();
                    if (tex_token_is_xdigit(cur_tok)) {
                        luaL_addchar(&b, (unsigned char) cur_chr);
                    } else {
                        tex_back_input(cur_tok);
                        break;
                    }
                }
            } else if (exponent) {
                goto HEXADECIMALEXPONENT;
            } else {
                tex_back_input(cur_tok);
                goto DONE;
            }
        }
    }
  HEXADECIMALEXPONENT:
    if (tex_token_is_xexponent(cur_tok)) {
        luaL_addchar(&b, (unsigned char) cur_chr);
        tex_get_x_token();
        if (tex_token_is_sign(cur_tok)) {
            /*
            tex_normal_warning("scanner", "no negative hexadecimal exponent permitted, ignoring minus sign");
            */
            luaL_addchar(&b, (unsigned char) cur_chr);
        } else if (tex_token_is_xdigit(cur_tok)) {
            luaL_addchar(&b, (unsigned char) cur_chr);
        }
        while (1) {
            tex_get_x_token();
            if (tex_token_is_xdigit(cur_tok)) {
                luaL_addchar(&b, (unsigned char) cur_chr);
            } else {
                break;
            }
        }
    }
    tex_back_input(cur_tok);
  DONE:
    luaL_pushresult(&b);
    {
        int ok = 0;
        double d = lua_tonumberx(L, -1, &ok);
        if (ok) {
            lua_pushnumber(L, d);
        } else {
            lua_pushnil(L);
        }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_integer_indeed(lua_State *L, int cardinal)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int negative = 0;
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    tokenlib_aux_goto_first_candidate_x();
    if (lua_toboolean(L, 1) && (cur_tok == equal_token)) {
        tokenlib_aux_goto_first_candidate_x();
    }
    /*tex we collapse as in |scan_dimen| */
    if (! cardinal) {
        while(1) {
            if (cur_tok == minus_token) {
                negative = ! negative;
            } else if (cur_tok != plus_token) {
                break;
            }
            tokenlib_aux_goto_first_candidate_x();
        }
        if (negative) {
            luaL_addchar(&b, '-');
        }
    } else if (cur_tok == minus_token) {
        tex_normal_warning("scanner", "positive number expected, ignoring minus sign");
        tokenlib_aux_goto_first_candidate_x();
    }
    if (cur_tok == zero_token) {
        luaL_addchar(&b, '0');
        tex_get_x_token();
        if (tex_token_is_hexadecimal(cur_tok)) {
            luaL_addchar(&b, 'x');
            goto HEXADECIMAL;
        } else {
            goto PICKUPDECIMAL;
        }
    } else {
        goto PICKUPDECIMAL;
    }
    while (1) {
        tex_get_x_token();
      PICKUPDECIMAL:
        if (tex_token_is_digit(cur_tok)) {
            luaL_addchar(&b, (unsigned char) cur_chr);
        } else {
            tex_back_input(cur_tok);
            goto DONE;
        }
    }
  HEXADECIMAL:
    while (1) {
        tex_get_x_token();
        if (tex_token_is_xdigit(cur_tok)) {
            luaL_addchar(&b, (unsigned char) cur_chr);
        } else {
            tex_back_input(cur_tok);
            goto DONE;
        }
    }
  DONE:
    luaL_pushresult(&b);
    if (cardinal) {
        int ok = 0;
        lua_Unsigned c = lua_tointegerx(L, -1, &ok);
        if (ok) {
            lua_pushinteger(L, c);
        } else {
            lua_pushnil(L);
        }
    } else {
        int ok = 0;
        lua_Integer i = lua_tointegerx(L, -1, &ok);
        if (ok) {
            lua_pushinteger(L, i);
        } else {
            lua_pushnil(L);
        }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_float(lua_State *L)
{
    return tokenlib_scan_float_indeed(L, 1, 0);
}

static int tokenlib_scan_real(lua_State *L)
{
    return tokenlib_scan_float_indeed(L, 0, 0);
}

static int tokenlib_scan_luanumber(lua_State* L)
{
    return tokenlib_scan_float_indeed(L, 1, 1);
}

static int tokenlib_scan_luainteger(lua_State* L)
{
    return tokenlib_scan_integer_indeed(L, 0);
}

static int tokenlib_scan_luacardinal(lua_State* L)
{
    return tokenlib_scan_integer_indeed(L, 1);
}

static int tokenlib_scan_scale(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int eq = lua_toboolean(L, 1);
    halfword val = tex_scan_scale(eq);
    lua_pushinteger(L, val);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_dimen(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int inf = lua_toboolean(L, 1);
    int mu = lua_toboolean(L, 2);
    int eq = lua_toboolean(L, 3);
    halfword order;
    halfword val = tex_scan_dimen(mu, inf, 0, eq, &order);
    lua_pushinteger(L, val);
    tokenlib_aux_unsave_tex_scanner(texstate);
    if (inf) {
        lua_pushinteger(L, order);
        return 2;
    } else {
        return 1;
    }
}

static int tokenlib_gobble_dimen(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int inf = lua_toboolean(L, 1);
    int mu = lua_toboolean(L, 2);
    int eq = lua_toboolean(L, 3);
    lmt_error_state.intercept = 1;
    lmt_error_state.last_intercept = 0;
    tex_scan_dimen(mu, inf, 0, eq, NULL);
    lua_pushboolean(L, ! lmt_error_state.last_intercept);
    lmt_error_state.intercept = 0;
    lmt_error_state.last_intercept = 0;
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_skip(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int mu = lua_toboolean(L, 1) ? mu_val_level : glue_val_level;
    int eq = lua_toboolean(L, 2);
    halfword v = tex_scan_glue(mu, eq);
    lmt_push_node_fast(L, v);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_glue(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int mu = lua_toboolean(L, 1) ? mu_val_level : glue_val_level;
    int eq = lua_toboolean(L, 2);
    int t  = lua_toboolean(L, 3);
    halfword v = tex_scan_glue(mu, eq);
    tokenlib_aux_unsave_tex_scanner(texstate);
    if (t) {
        lua_createtable(L, 5, 0);
        lua_pushinteger(L, glue_amount(v));
        lua_rawseti(L, -2, 1);
        lua_pushinteger(L, glue_stretch(v));
        lua_rawseti(L, -2, 2);
        lua_pushinteger(L, glue_shrink(v));
        lua_rawseti(L, -2, 3);
        lua_pushinteger(L, glue_stretch_order(v));
        lua_rawseti(L, -2, 4);
        lua_pushinteger(L, glue_shrink_order(v));
        lua_rawseti(L, -2, 5);
        return 1;
    } else {
        lua_pushinteger(L, glue_amount(v));
        lua_pushinteger(L, glue_stretch(v));
        lua_pushinteger(L, glue_shrink(v));
        lua_pushinteger(L, glue_stretch_order(v));
        lua_pushinteger(L, glue_shrink_order(v));
        return 5;
    }
}

inline static void lmt_token_list_to_lua_tokens(lua_State *L, halfword t)
{
    int i = 1;
    lua_newtable(L);
    while (t) {
        halfword n = token_link(t);
        token_link(t) = null;
        tokenlib_aux_push_token(L, t);
        lua_rawseti(L, -2, i++);
        t = n;
    }
}

void lmt_token_register_to_lua(lua_State *L, halfword t)
{
    int i = 1;
    lua_newtable(L);
    if (t) {
        t = token_link(t);
        while (t) {
            halfword m = tex_get_available_token(token_info(t));
            tokenlib_aux_push_token(L, m);
            lua_rawseti(L, -2, i++);
            t = token_link(t);
        }
    }
}

static int tokenlib_scan_toks(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int macro = lua_toboolean(L, 1);
    int expand = lua_toboolean(L, 2);
    halfword defref = lmt_input_state.def_ref;
    halfword result, t;
    if (macro) {
        result = expand ? tex_scan_macro_expand() : tex_scan_macro_normal();
    } else {
        result = expand ? tex_scan_toks_expand(0, NULL, 0) : tex_scan_toks_normal(0, NULL);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    lmt_input_state.def_ref = defref;
    t = token_link(result);
    token_link(result) = null;
    tex_put_available_token(result);
    lmt_token_list_to_lua_tokens(L, t);
    return 1;
}

static int tokenlib_scan_tokenlist(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int macro = lua_toboolean(L, 1);
    int expand = lua_toboolean(L, 2);
    halfword result;
    halfword defref = lmt_input_state.def_ref;
    if (macro) {
        result = expand ? tex_scan_macro_expand() : tex_scan_macro_normal();
    } else {
        result = expand ? tex_scan_toks_expand(0, NULL, 0) : tex_scan_toks_normal(0, NULL);
    }
    tokenlib_aux_push_token(L, result);
    tokenlib_aux_unsave_tex_scanner(texstate);
    lmt_input_state.def_ref = defref;
    return 1;
}

/* todo: other call_cmd */

static int tokenlib_scan_string(lua_State *L)
{
    /*tex can be simplified, no need for intermediate list */
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate_x(); /* actually this expands a following macro*/
    switch (cur_cmd) {
        case left_brace_cmd:
            {
                halfword defref = lmt_input_state.def_ref;
                halfword result = tex_scan_toks_expand(1, NULL, 0);
                lmt_token_list_to_luastring(L, result, 0, 0, 1);
                lmt_input_state.def_ref = defref;
                break;
            }
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case tolerant_call_cmd:
        case tolerant_protected_call_cmd:
        case tolerant_semi_protected_call_cmd:
            {
                halfword t = token_link(cur_chr);
                lmt_token_list_to_luastring(L, t, 0, 0, 1);
                break;
            }
        case letter_cmd:
        case other_char_cmd:
            {
                luaL_Buffer b;
                luaL_buffinit(L, &b);
                while (1) {
                    tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
                    tex_get_x_token();
                    if (cur_cmd != letter_cmd && cur_cmd != other_char_cmd ) {
                        break ;
                    }
                }
                tex_back_input(cur_tok);
                luaL_pushresult(&b);
                break;
            }
        default:
            {
                tex_back_input(cur_tok);
                lua_pushnil(L);
                break;
            }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_argument(lua_State *L)
{
    /*tex can be simplified, no need for intermediate list */
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate();
    switch (cur_cmd) {
        case left_brace_cmd:
            {
                halfword defref = lmt_input_state.def_ref;
                int expand = lua_type(L, 1) == LUA_TBOOLEAN ? lua_toboolean(L, 1) : 1;
                halfword result = expand ? tex_scan_toks_expand(1, NULL, 0) : tex_scan_toks_normal(1, NULL);
                lmt_token_list_to_luastring(L, result, 0, 0, 1);
                lmt_input_state.def_ref = defref;
                break;
            }
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case tolerant_call_cmd:
        case tolerant_protected_call_cmd:
        case tolerant_semi_protected_call_cmd:
              {
                  halfword result;
                  halfword defref = lmt_input_state.def_ref;
                  tex_back_input(right_brace_token + '}');
                  if (lua_type(L, 1) == LUA_TBOOLEAN && ! lua_toboolean(L, 1)) {
                      tex_expand_current_token();
                      result = tex_scan_toks_normal(1, NULL);
                  } else {
                      tex_back_input(cur_tok);
                      result = tex_scan_toks_expand(1, NULL, 0);
                  }
                  lmt_token_list_to_luastring(L, result, 0, 0, 1);
                  lmt_input_state.def_ref = defref;
                  break;
              }
        case letter_cmd:
        case other_char_cmd:
            {
                luaL_Buffer b;
                luaL_buffinit(L, &b);
             //  while (1) {
                    tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
             //      get_x_token();
             //      if (cur_cmd != letter_cmd && cur_cmd != other_char_cmd ) {
             //          break ;
             //      }
             //  }
             // back_input(cur_tok);
                luaL_pushresult(&b);
                break;
            }
        default:
            {
                tex_back_input(cur_tok);
                lua_pushnil(L);
                break;
            }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static void show_right_brace_error(void)
{
    tex_handle_error(
        normal_error_type,
        "Unbalanced value parsing (in Lua call)",
        "A { has to be matched by a }."
    );
}

static int tokenlib_scan_integer_argument(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int wrapped = 0;
    tokenlib_aux_goto_first_candidate();
    if (cur_cmd != left_brace_cmd) {
        tex_back_input(cur_tok);
    } else {
        wrapped = 1;
    }
    lua_pushinteger(L, (int) tex_scan_int(0, NULL));
    if (wrapped) {
        tokenlib_aux_goto_first_candidate();
        if (cur_cmd != right_brace_cmd) {
            show_right_brace_error();
        }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_dimen_argument(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int wrapped = 0;
    halfword order = 0;
    int inf = lua_toboolean(L, 1);
    int mu = lua_toboolean(L, 2);
    int eq = lua_toboolean(L, 3);
    tokenlib_aux_goto_first_candidate();
    if (cur_cmd != left_brace_cmd) {
        tex_back_input(cur_tok);
    } else {
        wrapped = 1;
    }
    lua_pushinteger(L, tex_scan_dimen(mu, inf, 0, eq, &order));
    if (wrapped) {
        tokenlib_aux_goto_first_candidate();
        if (cur_cmd != right_brace_cmd) {
            show_right_brace_error();
        }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    if (inf) {
        lua_pushinteger(L, order);
        return 2;
    } else {
        return 1;
    }
}

static int tokenlib_scan_delimited(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    halfword left = lua_type(L, 1) == LUA_TNUMBER ? lmt_tohalfword(L, 1) : 0;
    halfword right = lua_type(L, 2) == LUA_TNUMBER ? lmt_tohalfword(L, 2) : 0;
    int expand = (lua_type(L, 3) == LUA_TBOOLEAN) ? expand = lua_toboolean(L, 3) : 1;
    /* Maybe some more? */
    if (left) {
        left  = token_val(left  == 32 ? spacer_cmd : other_char_cmd, left);
    }
    if (right) {
        right = token_val(right == 32 ? spacer_cmd : other_char_cmd, right);
    } else {
        /* actually an error as we now get a runaway argument */
    }
    if (expand) {
        tokenlib_aux_goto_first_candidate_x();
    } else {
        tokenlib_aux_goto_first_candidate();
    }
    if (! left || cur_tok == left) {
        halfword defref = lmt_input_state.def_ref;
        halfword result = get_reference_token();
        halfword unbalance = 0;
        halfword p = result;
        lmt_input_state.def_ref = result;
        /* */
        if (expand) {
            /* like scan_toks_expand, maybe use |get_x_or_protected|.  */
            if (! left) {
                goto INITIAL1; /* ugly but saved a |back_input| */
            }
            while (1) {
              PICKUP:
                tex_get_next();
              INITIAL1:
                switch (cur_cmd) {
                    case call_cmd:
                    case tolerant_call_cmd:
                        tex_expand_current_token();
                        goto PICKUP;
                    case protected_call_cmd:
                    case semi_protected_call_cmd:
                    case tolerant_protected_call_cmd:
                    case tolerant_semi_protected_call_cmd:
                        cur_tok = cs_token_flag + cur_cs;
                        goto APPENDTOKEN;
                    case the_cmd:
                        {
                            halfword t = null;
                            halfword h = tex_the_toks(cur_chr, &t);
                            if (h) {
                                set_token_link(p, h);
                                p = t;
                            }
                            goto PICKUP;
                        }
                    default:
                        if (cur_cmd > max_command_cmd) {
                            tex_expand_current_token();
                            goto PICKUP;
                        } else {
                            goto DONEEXPANDING;
                        }
                }
              DONEEXPANDING:
                tex_x_token();
                if (cur_tok == right) {
                    break;
                } else if (cur_tok < right_brace_limit) {
                 /* if (cur_cmd < right_brace_cmd) { */
                    if (cur_cmd == left_brace_cmd || cur_cmd == relax_cmd) {
                        ++unbalance;
                    } else if (unbalance) {
                        --unbalance;
                    } else {
                        goto FINALYDONE;
                    }
                }
              APPENDTOKEN:
                p = tex_store_new_token(p, cur_tok);
            }
        } else {
            /* like scan_toks_normal */
            if (! left) {
                goto INITIAL2; /* ugly but saved a |back_input| */
            }
            while (1) {
                tex_get_token();
              INITIAL2:
                if (cur_tok == right) {
                    break;
                } else if (cur_tok < right_brace_limit) {
                 /* if (cur_cmd < right_brace_cmd) { */
                    if (cur_cmd == left_brace_cmd || cur_cmd == relax_cmd) {
                        ++unbalance;
                    } else if (unbalance) {
                        --unbalance;
                    } else {
                        break;
                    }
                }
                p = tex_store_new_token(p, cur_tok);
            }
        }
      FINALYDONE:
        /* */
        lmt_input_state.def_ref = defref;
        lmt_token_list_to_luastring(L, result, 0, 0, 1);
    } else {
        tex_back_input(cur_tok);
        lua_pushnil(L);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_gobble_until(lua_State *L) /* not ok because we can have different cs's */
{
    lua_token *left = tokenlib_aux_check_istoken(L, 1);
    lua_token *right = tokenlib_aux_check_istoken(L, 2);
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    int level = 1;
    int l = token_info(left->token);
    int r = token_info(right->token);
    int cmd, chr, lcmd, lchr, rcmd, rchr;
    if (l >= cs_token_flag) {
        lcmd = eq_type(l - cs_token_flag);
        lchr = eq_value(l - cs_token_flag);
    } else {
        lcmd = token_cmd(l);
        lchr = token_chr(l);
    }
    if (r >= cs_token_flag) {
        rcmd = eq_type(r - cs_token_flag);
        rchr = eq_value(r - cs_token_flag);
    } else {
        rcmd = token_cmd(l);
        rchr = token_chr(l);
    }
    while (1) {
        tex_get_token();
        if (cur_tok >= cs_token_flag) {
            cmd = eq_type(cur_cs);
            chr = eq_value(cur_cs);
        } else {
            cmd = cur_cmd;
            chr = cur_chr;
        }
        if (cmd == lcmd && chr == lchr) {
            ++level;
        } else if (cmd == rcmd && chr == rchr) {
            --level;
            if (level == 0) {
                break;
            }
        }
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 0;
}

/* only csnames, todo: no need for a token list .. make a direct tostring  */

static int tokenlib_grab_until(lua_State *L)
{
    lua_token *left = tokenlib_aux_check_istoken(L, 1);
    lua_token *right = tokenlib_aux_check_istoken(L, 2);
    int l = token_info(left->token);
    int r = token_info(right->token);
    int lstr = 0;
    int rstr = 0;
    if (l >= cs_token_flag) {
        lstr = cs_text(l - cs_token_flag);
    }
    if (r >= cs_token_flag) {
        rstr = cs_text(r - cs_token_flag);
    }
    if (lstr && rstr) {
        saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
        halfword defref = lmt_input_state.def_ref;
        halfword result = get_reference_token();
        halfword p = result;
        int level = 1;
        int nospace = lua_toboolean(L, 3);
        int strip = lmt_optinteger(L, 4, -1);
        while (1) {
            tex_get_token();
            if (cur_tok >= cs_token_flag) {
                int str = cs_text(cur_tok - cs_token_flag);
                if (str == lstr) {
                    ++level;
                } else if (str == rstr) {
                    --level;
                    if (level == 0) {
                        break;
                    }
                }
            }
            p = tex_store_new_token(p, cur_tok);
        }
        tokenlib_aux_unsave_tex_scanner(texstate);
        lmt_input_state.def_ref = defref;
        lmt_token_list_to_luastring(L, result, nospace, strip, 1);
    } else { 
        lua_pushnil(L);
    }
    return 1;
}

static int tokenlib_scan_word(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate_x();
    if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        while (1) {
            tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
            tex_get_x_token();
            if (cur_cmd != letter_cmd && cur_cmd != other_char_cmd) {
                break;
            }
        }
        if (! (lua_toboolean(L, 1) && ((cur_cmd == spacer_cmd) || (cur_cmd == relax_cmd)))) {
            tex_back_input(cur_tok);
        }
        luaL_pushresult(&b);
    } else {
        tex_back_input(cur_tok);
        lua_pushnil(L);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_letters(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate_x();
    if (cur_cmd == letter_cmd) {
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        while (1) {
            tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
            tex_get_x_token();
            if (cur_cmd != letter_cmd) {
                break ;
            }
        }
        if (! (lua_toboolean(L, 1) && ((cur_cmd == spacer_cmd) || (cur_cmd == relax_cmd)))) {
            tex_back_input(cur_tok);
        }
        luaL_pushresult(&b);
    } else {
        tex_back_input(cur_tok);
        lua_pushnil(L);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_char(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate(); /* no expansion */ /* optional expansion ? */ /* gobbles spaces */
    if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
        int c = lmt_tointeger(L, 1);
        if (c == cur_chr) {
            lua_pushboolean(L, 1);
        } else {
            lua_pushboolean(L, 0);
            tex_back_input(cur_tok);
        }
    } else {
        lua_pushboolean(L, 0);
        tex_back_input(cur_tok);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_next_char(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    const char mapping[14][2] = { "\\", "{", "}", "$", "&", "\n", "#", "^", "_", " ", "", "", "", "%" };
    tex_get_token();
    switch (cur_cmd) {
        case escape_cmd:
        case left_brace_cmd:
        case right_brace_cmd:
        case math_shift_cmd:
        case alignment_tab_cmd:
        case end_line_cmd:
        case parameter_cmd:
        case superscript_cmd:
        case subscript_cmd:
        case ignore_cmd:
        case spacer_cmd:
        case comment_cmd:
            lua_pushstring(L, mapping[cur_cmd]);
            break;
        case letter_cmd:
        case other_char_cmd:
        case active_char_cmd: /* needs testing */
            {
                char buffer[6];
                char *uindex = aux_uni2string((char *) buffer, (unsigned int) cur_chr);
                *uindex = '\0';
                lua_pushstring(L, buffer);
                break;
            }
        default:
            lua_pushstring(L, "");
            break;
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_is_next_char(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate(); /* no expansion */ /* optional expansion ? */ /* gobbles spaces */
    if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd ) {
        int c = lmt_tointeger(L, 1);
        lua_pushboolean(L, c == cur_chr);
    } else {
        lua_pushboolean(L, 0);
    }
    tex_back_input(cur_tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_peek_next(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    if (lua_toboolean(L, 1)) {
        tokenlib_aux_goto_first_candidate();
    } else {
        tex_get_token();
    }
 // make_new_token(L, cur_cmd, cur_chr, cur_cs);
    tokenlib_aux_make_new_token_tok(L, cur_tok);
    tex_back_input(cur_tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_peek_next_expanded(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    if (lua_toboolean(L, 1)) {
        tokenlib_aux_goto_first_candidate_x();
    } else {
        tex_get_x_token();
    }
 // make_new_token(L, cur_cmd, cur_chr, cur_cs);
    tokenlib_aux_make_new_token_tok(L, cur_tok);
    tex_back_input(cur_tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_peek_next_char(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate(); /* no expansion */ /* optional expansion ? */ /* gobbles spaces */
    if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd ) {
        lua_pushinteger(L, cur_chr);
    } else {
        lua_pushnil(L);
    }
    tex_back_input(cur_tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

/*tex

    This next two are experimental and might evolve. It will take a while before
    I decide if this is the way to go. They are not used in critical code so we
    have all time of the world.

*/

static int tokenlib_scan_key(lua_State *L)
{
    int c1 = lmt_optinteger(L, 1, '\0');
    int c2 = lmt_optinteger(L, 2, '\0');
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate_x();
    if ((cur_cmd == letter_cmd || cur_cmd == other_char_cmd) && (cur_chr != c1) && (cur_chr != c2)) {
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        while (1) {
            tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
            tex_get_x_token();
            if ((cur_cmd != letter_cmd && cur_cmd != other_char_cmd) || (cur_chr == c1) || (cur_chr == c2)) {
                break ;
            }
        }
        /*
        if (! (lua_toboolean(L, 1) && (cur_cmd == spacer_cmd || cur_cmd == relax_cmd))) {
            back_input(cur_tok);
        }
        */
        tex_back_input(cur_tok);
        luaL_pushresult(&b);
    } else {
        tex_back_input(cur_tok);
        lua_pushnil(L);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

/* todo: other call_cmd */
/* todo: non expandable option */

static int tokenlib_scan_value(lua_State *L)
{
    /*tex can be simplified, no need for intermediate list */
    int c1 = lmt_optinteger(L, 1, '\0');
    int c2 = lmt_optinteger(L, 2, '\0');
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tokenlib_aux_goto_first_candidate_x(); /* no _x */
    switch (cur_cmd) {
        case left_brace_cmd:
            {
                halfword result;
                halfword defref = lmt_input_state.def_ref;
                result = tex_scan_toks_expand(1, NULL, 0);
                lmt_input_state.def_ref = defref;
                lmt_token_list_to_luastring(L, result, 0, 0, 1);
            }
            break;
        /*
        case call_cmd:
            {
                halfword t = cur_cs ? cs_token_flag + cur_cs : token_val(cur_cmd, cur_chr);
                if (t >= cs_token_flag) {
                    unsigned char *s = get_cs_text(t - cs_token_flag);
                   if (s) {
                     // if (is_active_cs(cs_text(t - cs_token_flag))) {
                        luaL_Buffer b;
                        luaL_buffinit(L, &b);
                        cs_name_to_buffer(s);
                        luaL_pushresult(&b);
                        lmt_memory_free(s);
                    } else {
                        lua_pushnil(L);
                    }
                } else {
                    lua_pushnil(L);
                }
            }
            break;
        */
        case letter_cmd:
        case other_char_cmd:
            {
                luaL_Buffer b;
                luaL_buffinit(L, &b);
                while (1) {
                    switch (cur_cmd) {
                        case left_brace_cmd:
                            {
                                halfword result;
                                halfword defref = lmt_input_state.def_ref;
                                result = tex_scan_toks_expand(1, NULL, 0);
                                lmt_input_state.def_ref = defref;
                                lmt_token_list_to_luastring(L, result, 0, 0, 1);
                                luaL_addchar(&b, '{');
                                luaL_addvalue(&b);
                                luaL_addchar(&b, '}');
                            }
                            break;
                        case call_cmd:
                        case protected_call_cmd:
                        case semi_protected_call_cmd:
                        case tolerant_call_cmd:
                        case tolerant_protected_call_cmd:
                        case tolerant_semi_protected_call_cmd:
                            {
                                /*tex We need to add a space. */
                                halfword t = cur_cs ? cs_token_flag + cur_cs : token_val(cur_cmd, cur_chr);
                                if (t >= cs_token_flag) {
                                    int allocated = 0;
                                    unsigned char *s = tokenlib_aux_get_cs_text(t - cs_token_flag, &allocated);
                                    if (s) {
                                        if (tex_is_active_cs(cs_text(t - cs_token_flag))) {
                                            lua_pushstring(L, (char *) (s + 3));
                                            luaL_addvalue(&b);
                                        } else {
                                            luaL_addchar(&b, '\\');
                                            lua_pushstring(L, (char *) s);
                                            luaL_addvalue(&b);
                                            luaL_addchar(&b, ' ');
                                        }
                                        if (allocated) {
                                            lmt_memory_free(s);
                                        }
                                    }
                                }
                            }
                            break;
                        case letter_cmd:
                        case other_char_cmd:
                            if (cur_chr == c1 || cur_chr == c2) {
                                goto DONE;
                            } else {
                                tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
                            }
                            break;
                        default:
                            /* what to do */
                            tokenlib_aux_add_utf_char_to_buffer(&b, cur_chr);
                            break;
                    }
                    tex_get_x_token();
                }
              DONE:
                tex_back_input(cur_tok);
                luaL_pushresult(&b);
            }
            break;
        default:
            {
                tex_back_input(cur_tok);
                lua_pushnil(L);
            }
            break;
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

/*tex Till here. */

static int tokenlib_future_expand(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    halfword spa = null;
    halfword yes = tex_get_token(); /* no expansion */
    halfword nop = tex_get_token(); /* no expansion */
    while (1) {
        halfword t = tex_get_token();
        switch (t) {
            case spacer_cmd:
                spa = t; /* preserves spaces */
                break;
            case letter_cmd:
            case other_char_cmd:
                if (lua_tointeger(L, 1) == cur_chr) {
                    tex_back_input(t);
                    tex_back_input(yes);
                    tokenlib_aux_unsave_tex_scanner(texstate);
                    return 0;
                }
            default:
                tex_back_input(t);
                if (spa && lua_toboolean(L, 2)) {
                    tex_back_input(spa);
                }
                tex_back_input(nop);
                tokenlib_aux_unsave_tex_scanner(texstate);
                return 0;
        }
    }
 // return 0;
}

static int tokenlib_scan_code(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tex_get_x_token();
    if (cur_cmd <= max_char_code_cmd) {
        int cc = lmt_optinteger(L, 1, DEFAULT_SCAN_CODE_SET);
        if (cc & (1 << (cur_cmd))) {
            lua_pushinteger(L, (int) cur_chr);
        } else {
            lua_pushnil(L);
            tex_back_input(cur_tok);
        }
    } else {
        lua_pushnil(L);
        tex_back_input(cur_tok);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_scan_token_code(lua_State *L)
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    halfword t = tex_get_token();
    /* maybe treat spaces as such */
    if (cur_cmd <= max_char_code_cmd) {
        if (DEFAULT_SCAN_CODE_SET & (1 << (cur_cmd))) {
            lua_pushinteger(L, (int) cur_chr);
        } else {
            lua_pushnil(L);
            tex_back_input(t);
        }
    } else {
        lua_pushnil(L);
        tex_back_input(t);
    }
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

static int tokenlib_is_token(lua_State *L)
{
    lua_pushboolean(L, tokenlib_aux_maybe_istoken(L, 1) ? 1 : 0);
    return 1;
}

static int tokenlib_expand(lua_State *L)
{
    (void) L;
    tex_expand_current_token();
    /* should we push back? */
    return 0;
}

static int tokenlib_is_defined(lua_State *L)
{
    int b = 0;
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t l;
        const char *s = lua_tolstring(L, 1, &l);
        if (l > 0) {
            int cs = tex_string_locate(s, l, 0);
            b = (cs != undefined_control_sequence) && (eq_type(cs) != undefined_cs_cmd);
        }
    }
    lua_pushboolean(L, b);
    return 1;
}

/*tex
    The next two will be redone so that they check if valid tokens are created. For that I need to
    clean up the \TEX\ end a bit more so that we can do proper cmd checking.
*/

static int tokenlib_create(lua_State *L)
{
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            {
                int cs = 0;
                int chr = (int) lua_tointeger(L, 1);
                int cmd = (int) luaL_optinteger(L, 2, tex_get_cat_code(cat_code_table_par, chr));
                switch (cmd) {
                    case escape_cmd:
                    case ignore_cmd:
                    case comment_cmd:
                    case invalid_char_cmd:
                     /* tex_formatted_warning("token lib","not a good token, catcode %i can not be returned, so 12 will be used",(int) cmd); */
                        cmd = other_char_cmd;
                        break;
                    case active_char_cmd:
                        cs = tex_active_to_cs(chr, ! lmt_hash_state.no_new_cs);
                        cmd = eq_type(cs);
                        chr = eq_value(cs);
                        break;
                }
                tokenlib_aux_make_new_token(L, cmd, chr, cs);
                break;
            }
        case LUA_TSTRING:
            {
                size_t l;
                const char *s = lua_tolstring(L, 1, &l);
                if (l > 0) {
                    int cs = tex_string_locate(s, l, lua_toboolean(L, 2));
                    int cmd = eq_type(cs);
                    int chr = eq_value(cs);
                    tokenlib_aux_make_new_token(L, cmd, chr, cs);
                } else {
                    lua_pushnil(L);
                }
                break;
            }
        default:
            {
                lua_pushnil(L);
                break;
            }
    }
    return 1;
}

/*tex
    The order of arguments is somewhat strange but it comes from \LUATEX.
*/

static int tokenlib_new(lua_State *L)
{
    int chr = 0;
    int cmd = 0;
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            cmd = (int) tokenlib_aux_get_command_id(lua_tostring(L, 1));
            chr = (int) luaL_optinteger(L, 2, 0);
            break;
        case LUA_TNUMBER:
            chr = (int) lua_tointeger(L, 1);
            cmd = (int) luaL_optinteger(L, 2, 0);
            break;
        default:
            break;
    }
    tokenlib_aux_make_new_token(L, cmd, chr, 0);
    return 1;
}

/*tex
    The next few are more test functions and at some point they will replace the above or at least
    be combined so that we do proper checking.
*/

static int tokenlib_get_cmdchrcs(lua_State* L)
{
    size_t l;
    const char *s = lua_tolstring(L, 1, &l);
    if (l > 0) {
        int cs = tex_string_locate(s, l, 0);
        int cmd = eq_type(cs);
        int chr = eq_value(cs);
        if (! lua_toboolean(L, 2)) {
            /*tex This option is only for diagnostics! */
            chr = tokenlib_aux_to_valid_index(cmd, chr);
        }
        lua_pushinteger(L, cmd);
        lua_pushinteger(L, chr); /* or index */
        lua_pushinteger(L, cs);
        return 3;
    }
    return 0;
}

static int tokenlib_scan_cmdchr(lua_State *L)
{
    int cmd, chr;
    halfword tok = tex_get_token();
    if (tok >= cs_token_flag) {
        tok -= cs_token_flag;
        cmd = eq_type(tok);
        chr = eq_value(tok);
    } else {
        cmd = token_cmd(tok);
        chr = token_chr(tok);
    }
    lua_pushinteger(L, cmd);
    lua_pushinteger(L, tokenlib_aux_to_valid_index(cmd, chr));
    return 2;
}

static int tokenlib_scan_cmdchr_expanded(lua_State *L)
{
    int cmd, chr;
    halfword tok = tex_get_x_token();
    if (tok >= cs_token_flag) {
        tok -= cs_token_flag;
        cmd = eq_type(tok);
        chr = eq_value(tok);
    } else {
        cmd = token_cmd(tok);
        chr = token_chr(tok);
    }
    lua_pushinteger(L, cmd);
    lua_pushinteger(L, tokenlib_aux_to_valid_index(cmd, chr));
    return 2;
}


static int tokenlib_get_cstoken(lua_State* L)
{
    size_t l;
    const char *s = lua_tolstring(L, 1, &l);
    if (l > 0) {
        lua_pushinteger(L, (lua_Integer) tex_string_locate(s, l, 0) + cs_token_flag);
        return 1;
    }
    return 0;
}

static int tokenlib_getprimitives(lua_State *L)
{
    int cs = 0;
    int nt = 0;
    int raw = lua_toboolean(L, 1);
    lua_createtable(L, prim_size, 0);
    while (cs < prim_size) {
        strnumber s = get_prim_text(cs);
        if (s > 0 && (get_prim_origin(cs) != no_command)) {
            char *ss = tex_to_cstring(s);
            int cmd = prim_eq_type(cs);
            int chr = prim_equiv(cs);
            if (! raw) {
                chr = tokenlib_aux_to_valid_index(cmd, chr);
            }
            lua_createtable(L, 4, 0);
            lua_pushinteger(L, cmd);
            lua_rawseti(L, -2, 1);
            lua_pushinteger(L, chr);
            lua_rawseti(L, -2, 2);
            lua_pushstring(L, ss);
            lua_rawseti(L, -2, 3);
            lua_pushinteger(L, prim_origin(cs));
            lua_rawseti(L, -2, 4);
            lua_rawseti(L, -2, ++nt);
        }
        cs++;
    }
    return 1;
}

/*tex token instance functions */

static int tokenlib_free(lua_State *L)
{
 /* lua_token *n = check_istoken(L, 1); */
    lua_token *n = lua_touserdata(L, 1);
    if (n->origin == token_origin_lua) {
        if (token_link(n->token)) {
            tex_flush_token_list(n->token);
        } else {
            tex_put_available_token(n->token);
        }
    } else {
        /*tex This can't happen (yet). */
    }
    return 1;
}

/*tex fast accessors */

inline static int tokenlib_get_command(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword t = token_info(n->token);
    lua_pushinteger(L, (t >= cs_token_flag) ? (int) eq_type(t - cs_token_flag) : token_cmd(t));
    return 1;
}

inline static int tokenlib_get_index(lua_State *L)
{
    int cmd, chr;
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    if (tok >= cs_token_flag) {
        tok -= cs_token_flag;
        cmd = eq_type(tok);
        chr = eq_value(tok);
    } else {
        cmd = token_cmd(tok);
        chr = token_chr(tok);
    }
    lua_pushinteger(L, tokenlib_aux_to_valid_index(cmd, chr));
    return 1;
}

inline static int tokenlib_get_range(lua_State *L)
{
    int cmd;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        cmd = (int) lua_tointeger(L, 1);
    } else {
        lua_token *n = tokenlib_aux_check_istoken(L, 1);
        halfword tok = token_info(n->token);
        cmd = (tok >= cs_token_flag) ? eq_type(tok - cs_token_flag) : token_cmd(tok);
    }
    if (cmd >= 0 && cmd <= last_cmd) {
        command_item item = lmt_interface.command_names[cmd];
        lua_pushinteger(L, item.kind);
        switch (item.kind) {
            case unused_command_item:
                lua_pushboolean(L, 0);
                lua_pushboolean(L, 0);
                break;
            case regular_command_item:
            case character_command_item:
            case register_command_item:
            case internal_command_item:
            case reference_command_item:
            case data_command_item:
                lua_pushinteger(L, item.min);
                lua_pushinteger(L, item.max);
                break;
            case token_command_item:
            case node_command_item:
                lua_pushboolean(L, 0);
                lua_pushboolean(L, 0);
                break;
        }
        lua_pushinteger(L, item.fixedvalue);
        return 4;
    } else {
        return 0;
    }
}

inline static int tokenlib_get_cmdname(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    int cmd = (tok >= cs_token_flag) ? eq_type(tok - cs_token_flag) : token_cmd(tok);
    lua_push_key_by_index(lmt_interface.command_names[cmd].lua);
    return 1;
}

void lmt_push_cmd_name(lua_State *L, int cmd)
{
    if (cmd >= 0) {
        lua_push_key_by_index(lmt_interface.command_names[cmd].lua);
    } else {
        lua_pushnil(L);
    }
}

inline static int tokenlib_get_csname(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    if (tok >= cs_token_flag) {
        int allocated = 0;
        unsigned char *s = tokenlib_aux_get_cs_text(tok - cs_token_flag, &allocated);
        if (s) {
            if (tex_is_active_cs(cs_text(tok - cs_token_flag))) {
                lua_pushstring(L, (char *) (s + 3));
            } else {
                lua_pushstring(L, (char *) s);
            }
            if (allocated) {
                lmt_memory_free(s);
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

inline static int tokenlib_get_id(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    lua_pushinteger(L, n->token);
    return 1;
}

inline static int tokenlib_get_tok(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushinteger(L, tok);
    return 1;
}

inline static int tokenlib_get_active(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    int result = 0;
    if (tok >= cs_token_flag) {
        int allocated = 0;
        unsigned char *s = tokenlib_aux_get_cs_text(tok - cs_token_flag, &allocated);
        if (s) {
            result = tex_is_active_cs(cs_text(tok - cs_token_flag));
            if (allocated) {
                lmt_memory_free(s);
            }
        }
    }
    lua_pushboolean(L, result);
    return 1;
}

inline static int tokenlib_get_expandable(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    halfword cmd = (tok >= cs_token_flag) ? eq_type(tok - cs_token_flag) : token_cmd(tok);
    lua_pushboolean(L, cmd > max_command_cmd);
    return 1;
}

inline static int tokenlib_get_protected(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    halfword cmd = (tok >= cs_token_flag) ? eq_type(tok - cs_token_flag) : token_cmd(tok);
    lua_pushboolean(L, is_protected_cmd(cmd));
    return 1;
}

inline static int tokenlib_get_tolerant(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    halfword cmd = (tok >= cs_token_flag) ? eq_type(tok - cs_token_flag) : token_cmd(tok);
    lua_pushboolean(L, is_tolerant_cmd(cmd));
    return 1;
}

inline static int tokenlib_get_noaligned(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, noaligned_flag_bit));
    return 1;
}

inline static int tokenlib_get_primitive(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, primitive_flag_bit));
    return 1;
}

inline static int tokenlib_get_permanent(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, permanent_flag_bit));
    return 1;
}

inline static int tokenlib_get_immutable(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, immutable_flag_bit));
    return 1;
}

inline static int tokenlib_get_mutable(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, mutable_flag_bit));
    return 1;
}

inline static int tokenlib_get_frozen(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, frozen_flag_bit));
    return 1;
}

inline static int tokenlib_get_instance(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, instance_flag_bit));
    return 1;
}


inline static int tokenlib_get_untraced(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag && has_eq_flag_bits(tok - cs_token_flag, untraced_flag_bit));
    return 1;
}


inline static int tokenlib_get_flags(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    lua_pushboolean(L, tok >= cs_token_flag ? eq_flag(tok - cs_token_flag) : 0);
    return 1;
}

inline static int tokenlib_get_parameters(lua_State *L)
{
    lua_token *n = tokenlib_aux_check_istoken(L, 1);
    halfword tok = token_info(n->token);
    if (tok >= cs_token_flag && is_call_cmd(eq_type(tok - cs_token_flag))) {
        halfword v = eq_value(tok - cs_token_flag);
        if (v && token_link(v)) {
            lua_pushinteger(L, get_token_parameters(v));
            return 1;
        }
    }
    lua_pushnil(L);
    return 0;
}

static int tokenlib_getfield(lua_State *L)
{
    const char *s = lua_tostring(L, 2);
    if (lua_key_eq(s, command)) {
        return tokenlib_get_command(L);
    } else if (lua_key_eq(s, index)) {
        return tokenlib_get_index(L);
    } else if (lua_key_eq(s, cmdname)) {
        return tokenlib_get_cmdname(L);
    } else if (lua_key_eq(s, csname)) {
        return tokenlib_get_csname(L);
    } else if (lua_key_eq(s, id)) {
        return tokenlib_get_id(L);
    } else if (lua_key_eq(s, tok)) {
        return tokenlib_get_tok(L);
    } else if (lua_key_eq(s, active)) {
        return tokenlib_get_active(L);
    } else if (lua_key_eq(s, expandable)) {
        return tokenlib_get_expandable(L);
    } else if (lua_key_eq(s, protected)) {
        return tokenlib_get_protected(L);
    } else if (lua_key_eq(s, frozen)) {
        return tokenlib_get_frozen(L);
    } else if (lua_key_eq(s, tolerant)) {
        return tokenlib_get_tolerant(L);
    } else if (lua_key_eq(s, noaligned)) {
        return tokenlib_get_noaligned(L);
    } else if (lua_key_eq(s, permanent)) {
        return tokenlib_get_permanent(L);
    } else if (lua_key_eq(s, immutable)) {
        return tokenlib_get_immutable(L);
    } else if (lua_key_eq(s, mutable)) {
        return tokenlib_get_mutable(L);
    } else if (lua_key_eq(s, primitive)) {
        return tokenlib_get_primitive(L);
    } else if (lua_key_eq(s, instance)) {
        return tokenlib_get_instance(L);
    } else if (lua_key_eq(s, untraced)) {
        return tokenlib_get_untraced(L);
    } else if (lua_key_eq(s, flags)) {
        return tokenlib_get_flags(L);
    } else if (lua_key_eq(s, parameters)) {
        return tokenlib_get_parameters(L);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int tokenlib_get_fields(lua_State *L)
{
    halfword cmd = null;
    halfword chr = null;
    int flags = 0;
    int onlyflags = lua_toboolean(L, 2);
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            {
                size_t l;
                const char *str = lua_tolstring(L, 1, &l);
                if (l > 0) {
                    halfword cs; 
                    lua_createtable(L, 0, onlyflags ? 0 : 5);
                    cs = tex_string_locate(str, l, 0);
                    cmd = eq_type(cs);
                    chr = eq_value(cs);
                    flags = eq_flag(cs);
                    if (! onlyflags) {
                        lua_push_key(csname);
                        lua_pushstring(L, str);
                        lua_rawset(L, -3);
                    }
                    break;
                } else {
                    return 0;
                }
            }
        case LUA_TUSERDATA:
            {
                lua_token *n = tokenlib_aux_check_istoken(L, 1);
                halfword tok = token_info(n->token);
                lua_createtable(L, 0, onlyflags ? 0 : 5);
                if (tok >= cs_token_flag) {
                    int t = tok - cs_token_flag;
                    int allocated = 0;
                    unsigned char* str = tokenlib_aux_get_cs_text(t, &allocated);
                    if (str) {
                        if (! onlyflags) {
                            lua_push_key(csname);
                            if (tex_is_active_cs(cs_text(t))) {
                                lua_push_key(active);
                                lua_pushboolean(L, 1);
                                lua_rawset(L, -3);
                                lua_pushstring(L, (char*) (str + 3));
                            } else {
                                lua_pushstring(L, (char*) str);
                            }
                            lua_rawset(L, -3);
                        }
                        if (allocated) {
                            lmt_memory_free(str);
                        }
                    }
                    cmd = eq_type(t);
                    chr = eq_value(t);
                } else {
                    cmd = token_cmd(tok);
                    chr = token_chr(tok);
                }
                break;
            }
        default:
            return 0;

    }
    if (flags) {
        if (is_frozen   (flags)) { lua_push_key(frozen);    lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_noaligned(flags)) { lua_push_key(noaligned); lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_permanent(flags)) { lua_push_key(permanent); lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_immutable(flags)) { lua_push_key(immutable); lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_mutable  (flags)) { lua_push_key(mutable);   lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_primitive(flags)) { lua_push_key(primitive); lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_instance (flags)) { lua_push_key(instance);  lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_untraced (flags)) { lua_push_key(untraced);  lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (flags) { lua_push_key(flags); lua_pushinteger(L, flags); lua_rawset(L, -3); }
        if (is_protected(cmd)) { lua_push_key(protected); lua_pushboolean(L, 1); lua_rawset(L, -3); }
        if (is_tolerant (cmd)) { lua_push_key(tolerant);  lua_pushboolean(L, 1); lua_rawset(L, -3); }
    }
    if (! onlyflags) {
        lua_push_key(command);
        lua_pushinteger(L, cmd);
        lua_rawset(L, -3);
        lua_push_key(cmdname);
        lua_push_key_by_index(lmt_interface.command_names[cmd].lua);
        lua_rawset(L, -3);
        lua_push_key(index); /* or value */
        lua_pushinteger(L, tokenlib_aux_to_valid_index(cmd, chr));
        lua_rawset(L, -3);
        if (is_call_cmd(cmd) && chr && token_link(chr)) {
            lua_push_key(parameters);
            lua_pushinteger(L, get_token_parameters(token_link(chr)));
            lua_rawset(L, -3);
        }
    }
    return 1;
}

/*tex end */

static int tokenlib_equal(lua_State* L)
{
    lua_token* n = tokenlib_aux_check_istoken(L, 1);
    lua_token* m = tokenlib_aux_check_istoken(L, 2);
    lua_pushboolean(L, token_info(n->token) == token_info(m->token));
    return 1;
}

static int tokenlib_tostring(lua_State* L)
{
    lua_token* n = tokenlib_aux_maybe_istoken(L, 1);
    if (n) {
        halfword id = n->token;
        halfword tok = token_info(id);
        halfword lnk = token_link(id);
        char* ori = (n->origin == token_origin_lua) ? "lua" : "tex";
        halfword cmd, chr;
        unsigned char* csn = NULL;
        unsigned char* csp = NULL;
        const char* cmn = NULL;
        if (tok >= cs_token_flag) {
            int allocated = 0;
            tok -= cs_token_flag;
            csn = tokenlib_aux_get_cs_text(tok, &allocated);
            if (allocated) {
                csp = csn;
            }
            if (csn && tex_is_active_cs(cs_text(tok))) {
                csn += 3;
            }
            cmd = eq_type(tok);
            chr = eq_value(tok);
        } else {
            cmd = token_cmd(tok);
            chr = token_chr(tok);
        }
        if (! cmn) {
            if (cmd >= first_cmd && cmd <= last_cmd) {
                cmn = lmt_interface.command_names[cmd].name;
                switch (lmt_interface.command_names[cmd].base) {
                    case ignore_entry:
                    case direct_entry:
                        break;
                    default:
                        chr -= lmt_interface.command_names[cmd].base;
                }
            } else {
                cmn = "bad_token";
            }
        }
        if (csn && csn[0] != '\0') {
            if (lnk) {
                lua_pushfstring(L, "<%s token : %d => %d : %s : %s %d>", ori, id, lnk, (char *) csn, cmn, chr);
            } else {
                lua_pushfstring(L, "<%s token : %d == %s : %s %d>", ori, id, (char *) csn, cmn, chr);
            }
        } else {
            if (! lnk) {
                lua_pushfstring(L, "<%s token : %d == %s %d>", ori, id, cmn, chr);
            } else if (cmd == 0 && chr == 0) {
                /*tex A zero escape token is less likely than an initial list refcount token. */
                lua_pushfstring(L, "<%s token : %d => %d : refcount>", ori, id, lnk);
            } else {
                lua_pushfstring(L, "<%s token : %d => %d : %s %d>", ori, id, lnk, cmn, chr);
            }
        }
        if (csp) {
            lmt_memory_free(csp);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int tokenlib_package_tostring(lua_State *L)
{
    lua_token_package *n = tokenlib_aux_check_ispackage(L, 1);
    if (n) {
        if (is_call_cmd(n->cmd)) {
            lua_pushfstring(L, "<tex token package %d: %d %d %d>", n->cs, n->cmd, n->chr, get_token_reference(n->chr));
        } else {
            lua_pushfstring(L, "<tex token package %d: %d %d>", n->cs, n->cmd, n->chr);
        }
        return 1;
    } else {
        return 0;
    }
}

static int tokenlib_type(lua_State *L)
{
    if (tokenlib_aux_maybe_istoken(L, 1)) {
        lua_push_key(token);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int tokenlib_scan_token(lua_State *L) /*tex Similer to |get_next_expanded|, expands and no skips. */
{
    saved_tex_scanner texstate = tokenlib_aux_save_tex_scanner();
    tex_get_x_token();
 // make_new_token(L, cur_cmd, cur_chr, cur_cs);
    tokenlib_aux_make_new_token_tok(L, cur_tok);
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

/*tex This is always a copy! */

static int tokenlib_scan_box(lua_State *L)
{
    saved_tex_scanner texstate;
    if (lua_gettop(L) > 0) {
        const char *s = lua_tostring(L, 1);
        halfword code = -1 ;
        if (lua_key_eq(s, hbox)) {
            code = vtop_code + hmode;
        } else if (lua_key_eq(s, vbox)) {
            code = vtop_code + vmode;
        } else if (lua_key_eq(s, vtop)) {
            code = vtop_code;
        }
        if (code >= 0) {
            tex_back_input(token_val(make_box_cmd, code));
        }
    }
    /*tex
        This is a tricky call as we are in \LUA\ and therefore mess with the main loop.
    */
    texstate = tokenlib_aux_save_tex_scanner();
    lmt_push_node_fast(L, tex_local_scan_box());
    tokenlib_aux_unsave_tex_scanner(texstate);
    return 1;
}

/* experiment */

/* [catcodetable] csname content        : \def\csname{content}  */
/* [catcodetable] csname content global : \gdef\csname{content} */
/* [catcodetable] csname                : \def\csname{}         */

/* TODO: check for a quick way to set a macro to empty (HH) */

static int tokenlib_get_meaning(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        halfword cs = tex_string_locate(name, lname, 0);
        halfword cmd = eq_type(cs);
        if (is_call_cmd(cmd)) {
            int chr = eq_value(cs);
            if (lua_toboolean(L, 2)) {
                if (lua_toboolean(L, 3)) {
                    lmt_token_list_to_lua(L, token_link(chr));
                } else {
                    lmt_token_register_to_lua(L, chr);
                }
            } else {
                char *str = tex_tokenlist_to_tstring(chr, 1, NULL, 0, 0, 0, 0);
                lua_pushstring(L, str ? str : "");
            }
            return 1;
        }
    }
    return 0;
}

/*tex

    The final line of this routine is slightly subtle; at least, the author didn't think about it
    until getting burnt! There is a used-up token list on the stack, namely the one that contained
    |end_write_token|. We insert this artificial |\endwrite| to prevent runaways, as explained
    above.) If it were not removed, and if there were numerous writes on a single page, the stack
    would overflow.

*/

static void tokenlib_aux_expand_macros_in_tokenlist(halfword p)
{
    halfword old_mode;
    halfword q = tex_get_available_token(right_brace_token + '}');
    halfword r = tex_get_available_token(deep_frozen_end_write_token);
    token_link(q) = r;
    tex_begin_inserted_list(q);
    tex_begin_token_list(p, write_text);
    q = tex_get_available_token(left_brace_token + '{'); /* not needed when we expand with first arg == 1 */
    tex_begin_inserted_list(q);
    /*tex Now we're ready to scan |{<token list>}| |\endwrite|. */
    old_mode = cur_list.mode;
    cur_list.mode = 0;
    /*tex Disable |\prevdepth|, |\spacefactor|, |\lastskip|, |\prevgraf|. */
    cur_cs = 0; /* was write_loc i.e. eq of \write */
    /*tex Expand macros, etc. */
    tex_scan_toks_expand(0, NULL, 0); /* could be 1 and no left brace above */
 //   tex_scan_toks_expand(1, NULL); /* could be 1 and no left brace above */
    tex_get_token();
    if (cur_tok != deep_frozen_end_write_token) {
        /*tex Recover from an unbalanced write command */
        tex_handle_error(
            normal_error_type,
            "Unbalanced token list expansion",
            "On this page there's a token list expansion with fewer real {'s than }'s. I can't\n"
            "handle that very well; good luck."
        );
        do {
            tex_get_token();
        } while (cur_tok != deep_frozen_end_write_token);
    }
    cur_list.mode = old_mode;
    /*tex Conserve stack space. */
    tex_end_token_list();
}

static int tokenlib_get_macro(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        halfword cs = tex_string_locate(name, lname, 0);
        halfword cmd = eq_type(cs);
        if (is_call_cmd(cmd)) {
            halfword chr = eq_value(cs);
            char *str = NULL;
            if (lua_toboolean(L, 2)) {
                tokenlib_aux_expand_macros_in_tokenlist(chr); // todo: use return value instead of def_ref
                str = tex_tokenlist_to_tstring(lmt_input_state.def_ref, 1, NULL, 0, 0, 0, 1);
            } else {
                str = tex_tokenlist_to_tstring(chr, 1, NULL, 1, 0, 0, 0);
            }
            lua_pushstring(L, str ? str : "");
            return 1;
        }
    }
    return 0;
}

/* maybe just memoryword */

// todo: node lists:
//
// [internal|register]_[glue|mu_glue]_reference_cmd
// specification_reference_cmd
// box_reference_cmd

static int tokenlib_push_macro(lua_State *L) // todo: just store cmd and flag together
{
    /*tex
        We need to check for a valid hit, but what is best here, for instance using |(cmd >= call_cmd)|
        is not okay as we miss a lot then.

        Active characters: maybe when we pass a number ... 
    */
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        if (lname > 0) {
            halfword cs = tex_string_locate(name, lname, 0);
            singleword cmd = eq_type(cs);
            halfword chr = eq_value(cs);
            quarterword global = lua_toboolean(L, 2) ? add_global_flag(0) : 0; /* how */
            if (is_call_cmd(cmd)) {
                tex_add_token_reference(chr);
            }
            tokenlib_aux_make_new_package(L, cmd, eq_flag(cs), chr, cs, global);
            return 1;
        }
    }
    return 0;
}

static int tokenlib_pop_macro(lua_State *L)
{
    lua_token_package *p = tokenlib_aux_check_ispackage(L, 1);
    if (p) {
        tex_forced_define(p->how, p->cs, p->flag, p->cmd, p->chr);
    }
    return 0;
}

char *lmt_get_expansion(halfword head, int *len)
{
    char *str = NULL;
    halfword ref = get_reference_token();
    set_token_link(ref, head);
    tokenlib_aux_expand_macros_in_tokenlist(ref); // todo: use return value instead of def_ref
    str = tex_tokenlist_to_tstring(lmt_input_state.def_ref, 1, len, 0, 0, 0, 1);
    tex_flush_token_list(ref);
    return str;
}

static int tokenlib_get_expansion(lua_State* L)
{
    const char *str;
    size_t len;
    int slot = 1;
    halfword ct = lua_type(L, slot) == LUA_TNUMBER ? lmt_tohalfword(L, slot++) : cat_code_table_par;
    if (! tex_valid_catcode_table(ct)) {
        ct = cat_code_table_par;
    }
    str = lua_tolstring(L, 1, &len);
    if (len > 0) {
        halfword h = get_reference_token();
        halfword t = h;
        char *s;
        int l;
        tex_parse_str_to_tok(h, &t, ct, str, len, 2); /* ignore unknown */
        tokenlib_aux_expand_macros_in_tokenlist(h); // todo: use return value instead of def_ref
        s = tex_tokenlist_to_tstring(lmt_input_state.def_ref, 1, &l, 0, 0, 0, 1);
        tex_flush_token_list(h);
        if (l > 0) {
            lua_pushlstring(L, (const char *) s, (size_t) l);
            return 1;
        }
    }
    lua_pushliteral(L, "");
    return 1;
}

static int tokenlib_save_lua(lua_State *L)
{
    halfword f = lmt_tohalfword(L, 1);
    if (lua_toboolean(L, 2) && cur_level > 0) {
        /* use with care */
        halfword ptr = lmt_save_state.save_stack_data.ptr;
        while (1) {
            --ptr;
            switch (save_type(ptr)) {
                case level_boundary_save_type:
                    goto SAVE;
                case restore_lua_save_type:
                    if (save_value(ptr) == f) {
                        return 0;
                    } else {
                        break;
                    }
            }
        }
    }
  SAVE:
    tex_save_halfword_on_stack(restore_lua_save_type, f);
    return 0;
}

static int tokenlib_set_lua(lua_State *L)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        if (name) {
            halfword cs; 
            int flags = 0;
            int funct = lmt_tointeger(L, 2); /*tex todo: check range */
            lmt_check_for_flags(L, 3, &flags, 1, 1);
            cs = tex_string_locate(name, lname, 1);
            if (tex_define_permitted(cs, flags)) {
                if (is_value(flags)) {
                    tex_define(flags, cs, lua_value_cmd, funct);
                } else if (is_conditional(flags)) {
                    tex_define(flags, cs, if_test_cmd, last_if_test_code + funct);
                /* with some effort we could combine these two an dise the flag */
                } else if (is_protected(flags)) {
                    tex_define(flags, cs, lua_protected_call_cmd, funct);
                } else {
                    tex_define(flags, cs, lua_call_cmd, funct);
                }
            }
        }
    }
    return 0;
}

/* [catcodes,]name,data[,global,frozen,protected]* */

static int tokenlib_undefine_macro(lua_State *L) /* todo: protected */
{
    size_t lname = 0;
    const char *name = lua_tolstring(L, 1, &lname);
    if (name) {
        halfword cs = tex_string_locate(name, lname, 1);
        int flags = 0;
        lmt_check_for_flags(L, 2, &flags, 1, 1);
        tex_define(flags, cs, undefined_cs_cmd, null);
    }
    return 0;
}

static int tokenlib_set_macro(lua_State *L) /* todo: protected */
{
    int top = lua_gettop(L);
    if (top > 0) {
        const char *name = NULL;
        size_t lname = 0;
        int slot = 1;
        halfword ct = lua_type(L, slot) == LUA_TNUMBER ? lmt_tohalfword(L, slot++) : cat_code_table_par;
        if (! tex_valid_catcode_table(ct)) {
            ct = cat_code_table_par;
        }
        name = lua_tolstring(L, slot++, &lname);
        if (name) {
            size_t lstr = 0;
            const char *str = lua_tolstring(L, slot++, &lstr);
            halfword cs = tex_string_locate(name, lname, 1);
            int flags = 0;
            if (slot <= top) {
                slot = lmt_check_for_flags(L, slot, &flags, 1, 1);
            }
            if (tex_define_permitted(cs, flags)) { /* we check before we allocate */
                halfword h = get_reference_token();
                halfword t = h;
                if (lstr > 0) {
                    /*tex Options: 1=create (will trigger an error), 2=ignore. */
                    tex_parse_str_to_tok(h, &t, ct, str, lstr, lua_toboolean(L, slot++) ? 2 : 1);
                }
                tex_define(flags, cs, tex_flags_to_cmd(flags), h);
            }
        }
    }
    return 0;
}

// todo: use: is_call_cmd(cmd)

halfword lmt_macro_to_tok(lua_State *L, int slot, halfword *tail)
{
    halfword tok = 0;
    switch (lua_type(L, slot)) {
        case LUA_TSTRING:
            {
                size_t lname = 0;
                const char *name = lua_tolstring(L, slot, &lname);
                int cs = tex_string_locate(name, lname, 0);
                int cmd = eq_type(cs);
                if (is_call_cmd(cmd)) {
                    tok = cs_token_flag + cs;
                } else if (cmd != undefined_cs_cmd) {
                    /*tex Bonus: not really a macro! */
                    tok = token_val(cmd, eq_value(cs));
                }
                break;
            }
        case LUA_TUSERDATA:
            tok = token_info(lmt_token_code_from_lua(L, slot));
            if (! is_call_cmd(tok >= cs_token_flag ? eq_type(tok - cs_token_flag) : token_cmd(tok))) {
                tok = 0;
            }
            break;
    }
    if (tok) {
        int top = lua_gettop(L);
        halfword m = tex_get_available_token(tok);
        halfword a = m;
        halfword c = cat_code_table_par;
        if (top > slot) {
            int arg = 0;
            for (int i = slot + 1; i <= top; i++) {
                switch (lua_type(L, i)) {
                    case LUA_TBOOLEAN:
                        {
                             arg = lua_toboolean(L, i);
                             break;
                        }
                    case LUA_TSTRING:
                        {
                            size_t l;
                            const char *s = lua_tolstring(L, i, &l);
                            if (arg) {
                                a = tex_store_new_token(a, left_brace_token + '{');
                            }
                            /*tex We use option 1 so we get an undefined error. */
                            tex_parse_str_to_tok(a, &a, c, s, l, 1);
                            if (arg) {
                                a = tex_store_new_token(a, right_brace_token + '}');
                            }
                            break;
                        }
                    case LUA_TNUMBER:
                        {
                            /* catcode table */
                            c = lmt_tohalfword(L, i);
                            break;
                        }
                    case LUA_TTABLE:
                        {
                            size_t l;
                            const char *s ;
                            int j = (int) lua_rawlen(L, i);
                            for (int k = 1; k <= j; k++) {
                                lua_rawgeti(L, i, k);
                                s = lua_tolstring(L, -1, &l);
                                a = tex_store_new_token(a, left_brace_token + '{');
                                /*tex We use option 1 so we get an udndefined error. */
                                tex_parse_str_to_tok(a, &a, c, s, l, 1);
                                a = tex_store_new_token(a, right_brace_token + '}');
                                lua_pop(L, 1);
                            };
                            break;
                        }
                    case LUA_TUSERDATA:
                        {
                            a = tex_store_new_token(a, lmt_token_code_from_lua(L, i));
                            break;
                        }
                }
            }
        }
        if (tail) {
            *tail = a;
        }
        return m;
    } else {
        if (tail) {
            *tail = null;
        }
        return null;
    }
}

static int tokenlib_expand_macro(lua_State *L)
{
    halfword tail = null;
    halfword tok = lmt_macro_to_tok(L, 1, &tail);
    if (tok) {
        /* todo: append to tail */
        tex_begin_inserted_list(tex_get_available_token(token_val(end_local_cmd, 0)));
        tex_begin_inserted_list(tok);
     // halfword h = tex_get_available_token(token_val(end_local_cmd, 0));
     // token_link(tail) = h;
     // tex_begin_inserted_list(tok);
        if (lmt_token_state.luacstrings > 0) {
            tex_lua_string_start();
        }
        if (tracing_nesting_par > 2) {
            tex_local_control_message("entering local control via (run) macro");
        }
        tex_local_control(1);
    } else {
        tex_local_control_message("invalid (run) macro");
    }
    return 0;
}

/* a weird place, should be in tex */

static int tokenlib_set_char(lua_State *L) /* also in texlib */
{
    int top = lua_gettop(L);
    if (top >= 2) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        if (name) {
            int value = lmt_tointeger(L, 2);
            if (value >= 0 && value <= max_character_code) {
                int flags = 0;
                int cs = tex_string_locate(name, lname, 1);
                if (top > 2) {
                    lmt_check_for_flags(L, 3, &flags, 1, 0);
                }
                tex_define(flags, cs, char_given_cmd, value);
            }
        }
    }
    return 0;
}

/* a weird place, these should be in tex */

static int tokenlib_set_constant(lua_State *L, singleword cmd, halfword min, halfword max)
{
    int top = lua_gettop(L);
    if (top >= 2) {
        size_t lname = 0;
        const char *name = lua_tolstring(L, 1, &lname);
        if (name) {
            halfword value = lmt_tohalfword(L, 2);
            if (value >= min && value <= max) {
                int flags = 0;
                int cs = tex_string_locate(name, lname, 1);
                if (top > 2) {
                    lmt_check_for_flags(L, 3, &flags, 1, 0);
                }
                tex_define(flags, cs, cmd, value);
            }
        }
    }
    return 0;
}

static int tokenlib_get_constant(lua_State *L, halfword cmd)
{
    if (lua_type(L, 1) == LUA_TSTRING) {
        size_t l;
        const char *s = lua_tolstring(L, 1, &l);
        if (l > 0) {
            int cs = tex_string_locate(s, l, 0);
            if (eq_type(cs) == cmd) {
                lua_pushinteger(L, eq_value(cs));
                return 1;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int tokenlib_set_integer(lua_State *L)
{
    return tokenlib_set_constant(L, integer_cmd, min_integer, max_integer);
}

static int tokenlib_set_dimension(lua_State *L)
{
    return tokenlib_set_constant(L, dimension_cmd, min_dimen, max_dimen);
}

// static int tokenlib_set_gluespec(lua_State *L)
// {
//     return tokenlib_set_constant(L, gluespec_cmd, min_dimen, max_dimen);
// }

static int tokenlib_get_integer(lua_State *L)
{
    return tokenlib_get_constant(L, integer_cmd);
}

static int tokenlib_get_dimension(lua_State *L)
{
    return tokenlib_get_constant(L, dimension_cmd);
}

// static int tokenlib_get_gluespec(lua_State *L)
// {
//     return tokenlib_get_constant(L, gluespec_cmd);
// }

/*
static int tokenlib_get_command_names(lua_State *L)
{
    lua_createtable(L, data_cmd + 1, 0);
    for (int i = 0; command_names[i].lua; i++) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, command_names[i].lua);
        lua_rawseti(L, -2, i);
    }
    return 1;
}
*/

static int tokenlib_serialize(lua_State *L)
{
    lua_token *n = tokenlib_aux_maybe_istoken(L, 1);
    if (n) {
        halfword t = n->token;
        char *s;
        tokenlib_aux_expand_macros_in_tokenlist(t); // todo: use return value instead of def_ref
        s = tex_tokenlist_to_tstring(lmt_input_state.def_ref, 1, NULL, 0, 0, 0, 1);
        lua_pushstring(L, s ? s : "");
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int tokenlib_getcommandvalues(lua_State *L)
{
    lua_createtable(L, number_tex_commands, 1);
    for (int i = 0; i < number_tex_commands; i++) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_interface.command_names[i].lua);
        lua_rawseti(L, -2, lmt_interface.command_names[i].id);
    }
    return 1;
}

static int tokenlib_getfunctionvalues(lua_State *L)
{
    return lmt_push_info_values(L, lmt_interface.lua_function_values);
}

static const struct luaL_Reg tokenlib_function_list[] = {
    { "type",                tokenlib_type                  },
    { "create",              tokenlib_create                },
    { "new",                 tokenlib_new                   },
    /* */
    { "istoken",             tokenlib_is_token              },
    { "isdefined",           tokenlib_is_defined            },
    /* getters */
    { "scannext",            tokenlib_scan_next             },
    { "scannextexpanded",    tokenlib_scan_next_expanded    },
    { "scannextchar",        tokenlib_scan_next_char        },
    /* skippers */
    { "skipnext",            tokenlib_skip_next             },
    { "skipnextexpanded",    tokenlib_skip_next_expanded    },
    /* peekers */
    { "peeknext",            tokenlib_peek_next             },
    { "peeknextexpanded",    tokenlib_peek_next_expanded    },
    { "peeknextchar",        tokenlib_peek_next_char        },
    /* scanners */
    { "scancmdchr",          tokenlib_scan_cmdchr           },
    { "scancmdchrexpanded",  tokenlib_scan_cmdchr_expanded  },
    { "scankeyword",         tokenlib_scan_keyword          },
    { "scankeywordcs",       tokenlib_scan_keyword_cs       },
    { "scaninteger",         tokenlib_scan_integer          },
    { "scanintegerargument", tokenlib_scan_integer_argument },
    { "scandimenargument",   tokenlib_scan_dimen_argument   },
    { "scancardinal",        tokenlib_scan_cardinal         },
    { "scanfloat",           tokenlib_scan_float            },
    { "scanreal",            tokenlib_scan_real             },
    { "scanluanumber",       tokenlib_scan_luanumber        },
    { "scanluainteger",      tokenlib_scan_luainteger       },
    { "scanluacardinal",     tokenlib_scan_luacardinal      },
    { "scanscale",           tokenlib_scan_scale            },
    { "scandimen",           tokenlib_scan_dimen            },
    { "scanskip",            tokenlib_scan_skip             },
    { "scanglue",            tokenlib_scan_glue             },
    { "scantoks",            tokenlib_scan_toks             },
    { "scantokenlist",       tokenlib_scan_tokenlist        },
    { "scancode",            tokenlib_scan_code             },
    { "scantokencode",       tokenlib_scan_token_code       }, /* doesn't expand */
    { "scanstring",          tokenlib_scan_string           },
    { "scanargument",        tokenlib_scan_argument         },
    { "scandelimited",       tokenlib_scan_delimited        },
    { "scanword",            tokenlib_scan_word             },
    { "scanletters",         tokenlib_scan_letters          },
    { "scankey",             tokenlib_scan_key              },
    { "scanvalue",           tokenlib_scan_value            },
    { "scanchar",            tokenlib_scan_char             },
    { "scancsname",          tokenlib_scan_csname           },
    { "scantoken",           tokenlib_scan_token            }, /* expands next token if needed */
    { "scanbox",             tokenlib_scan_box              },
    { "isnextchar",          tokenlib_is_next_char          },
    /* writers */
    { "putnext",             tokenlib_put_next              },
    { "putback",             tokenlib_put_back              },
    { "expand",              tokenlib_expand                },
    /* getters */
    { "getcommand",          tokenlib_get_command           },
    { "getindex",            tokenlib_get_index             },
    { "getrange",            tokenlib_get_range             },
 /* { "get_mode",             tokenlib_get_mode              }, */ /* obsolete */
    { "getcmdname",          tokenlib_get_cmdname           },
    { "getcsname",           tokenlib_get_csname            },
    { "getid",               tokenlib_get_id                },
    { "gettok",              tokenlib_get_tok               }, /* obsolete */
    { "getactive",           tokenlib_get_active            },
    { "getexpandable",       tokenlib_get_expandable        },
    { "getprotected",        tokenlib_get_protected         },
    { "getfrozen",           tokenlib_get_frozen            },
    { "gettolerant",         tokenlib_get_tolerant          },
    { "getnoaligned",        tokenlib_get_noaligned         },
    { "getprimitive",        tokenlib_get_primitive         },
    { "getpermanent",        tokenlib_get_permanent         },
    { "getimmutable",        tokenlib_get_immutable         },
    { "getinstance",         tokenlib_get_instance          },
    { "getflags",            tokenlib_get_flags             },
    { "getparameters",       tokenlib_get_parameters        },
    { "getmacro",            tokenlib_get_macro             },
    { "getmeaning",          tokenlib_get_meaning           },
    { "getcmdchrcs",         tokenlib_get_cmdchrcs          },
    { "getcstoken",          tokenlib_get_cstoken           },
    { "getfields",           tokenlib_get_fields            },
    /* setters */
    { "setmacro",            tokenlib_set_macro             },
    { "undefinemacro",       tokenlib_undefine_macro        },
    { "expandmacro",         tokenlib_expand_macro          },
    { "setchar",             tokenlib_set_char              },
    { "setlua",              tokenlib_set_lua               },
    { "setinteger",          tokenlib_set_integer           }, /* can go ... also in texlib */
    { "getinteger",          tokenlib_get_integer           }, /* can go ... also in texlib */
    { "setdimension",        tokenlib_set_dimension         }, /* can go ... also in texlib */
    { "getdimension",        tokenlib_get_dimension         }, /* can go ... also in texlib */
    /* gobblers */
    { "gobbleinteger",       tokenlib_gobble_integer        },
    { "gobbledimen",         tokenlib_gobble_dimen          },
    { "gobble",              tokenlib_gobble_until          },
    { "grab",                tokenlib_grab_until            },
    /* macros */
    { "futureexpand",        tokenlib_future_expand         },
    { "pushmacro",           tokenlib_push_macro            },
    { "popmacro",            tokenlib_pop_macro             },
    /* whatever */
    { "savelua",             tokenlib_save_lua              },
    { "serialize",           tokenlib_serialize             },
    { "getexpansion",        tokenlib_get_expansion         },
    /* interface */
    { "getfunctionvalues",   tokenlib_getfunctionvalues     },
    { "getcommandvalues",    tokenlib_getcommandvalues      },
    { "getcommandid",        tokenlib_getcommandid          },
    { "getprimitives",       tokenlib_getprimitives         },
    /* done */
    { NULL,                  NULL                           },
};

static const struct luaL_Reg tokenlib_instance_metatable[] = {
    { "__index",    tokenlib_getfield },
    { "__tostring", tokenlib_tostring },
    { "__gc",       tokenlib_free     },
    { "__eq",       tokenlib_equal    },
    { NULL,         NULL              },
};

static const struct luaL_Reg tokenlib_package_metatable[] = {
    { "__tostring", tokenlib_package_tostring },
    { NULL,         NULL                      },
};

int luaopen_token(lua_State *L)
{
    luaL_newmetatable(L, TOKEN_METATABLE_INSTANCE);
    luaL_setfuncs(L, tokenlib_instance_metatable, 0);
    luaL_newmetatable(L, TOKEN_METATABLE_PACKAGE);
    luaL_setfuncs(L, tokenlib_package_metatable, 0);
    lua_newtable(L);
    luaL_setfuncs(L, tokenlib_function_list, 0);
    return 1;
}

typedef struct LoadS { // name
    char   *s;
    size_t  size;
} LoadS;

static const char *tokenlib_aux_reader(lua_State *L, void *ud, size_t *size)
{
    LoadS *ls = (LoadS *) ud;
    (void) L;
    if (ls->size > 0) {
        *size = ls->size;
        ls->size = 0;
        return ls->s;
    } else {
        return NULL;
    }
}

void lmt_token_call(int p) /*tex The \TEX\ pointer to the token list. */
{
    LoadS ls;
    int l = 0;
    ls.s = tex_tokenlist_to_tstring(p, 1, &l, 0, 0, 0, 0);
    ls.size = (size_t) l;
    if (ls.size > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int i;
        int top = lua_gettop(L);
        lua_pushcfunction(L, lmt_traceback);
        i = lua_load(L, tokenlib_aux_reader, &ls, "=[\\directlua]", NULL);
        if (i != 0) {
            lmt_error(L, "token call, syntax", -1, i == LUA_ERRSYNTAX ? 0 : 1);
        } else {
            ++lmt_lua_state.direct_callback_count;
            i = lua_pcall(L, 0, 0, top + 1);
            if (i != 0) {
                lua_remove(L, top + 1);
                lmt_error(L, "token call, execute", -1, i == LUA_ERRRUN ? 0 : 1);
            }
        }
        lua_settop(L, top);
    }
}

void lmt_function_call(int slot, int prefix) /*tex Functions are collected in an indexed table. */
{
    lua_State *L = lmt_lua_state.lua_instance;
    int stacktop = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_lua_state.function_table_id);
    lua_pushcfunction(L, lmt_traceback);
    if (lua_rawgeti(L, -2, slot) == LUA_TFUNCTION) {
        int i = 1;
        /*tex function index */
        lua_pushinteger(L, slot);
        if (prefix > 0) {
             lua_pushinteger(L, prefix);
             ++i;
        }
        ++lmt_lua_state.function_callback_count;
        i = lua_pcall(L, i, 0, stacktop + 2);
        if (i) {
            lua_remove(L, stacktop + 2);
            lmt_error(L, "registered function call", slot, i == LUA_ERRRUN ? 0 : 1);
        }
    }
    lua_settop(L, stacktop);
}

void lmt_local_call(int slot)
{
    lua_State *L = lmt_lua_state.lua_instance;
    int stacktop = lua_gettop(L);
    lua_pushcfunction(L, lmt_traceback);
    if (lua_rawgeti(L, LUA_REGISTRYINDEX, slot) == LUA_TFUNCTION) {
        int i;
        ++lmt_lua_state.local_callback_count;
        i = lua_pcall(L, 0, 0, stacktop + 1);
        if (i) {
            lua_remove(L, stacktop + 1);
            lmt_error(L, "local function call", slot, i == LUA_ERRRUN ? 0 : 1);
        }
    }
    lua_settop(L, stacktop);
}

int lmt_function_call_by_class(int slot, int property, halfword *value)
{
    lua_State *L = lmt_lua_state.lua_instance;
    int stacktop = lua_gettop(L);
    int class = lua_value_none_code;
    lua_pushcfunction(L, lmt_traceback);
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_lua_state.function_table_id);
    if (lua_rawgeti(L, -1, slot) == LUA_TFUNCTION) {
        int i;
        /*tex function index */
        lua_pushinteger(L, slot);
        if (property) {
            lua_pushinteger(L, property);
        } else {
            lua_push_key(value);
        }
        ++lmt_lua_state.value_callback_count;
        i = lua_pcall(L, 2, 2, stacktop + 1);
        if (i) {
            lua_remove(L, stacktop + 1);
            lmt_error(L, "function call", slot, i == LUA_ERRRUN ? 0 : 1);
        } else {
            if (lua_type(L, -2) == LUA_TNUMBER) {
                class = lmt_tointeger(L, -2);
            }
            switch (class) {
                case lua_value_none_code:
                    {
                        break;
                    }
                case lua_value_integer_code:
                    {
                        *value = lua_type(L, -1) == LUA_TNUMBER ? lmt_tohalfword(L, -1) : 0;
                        if (*value < - max_integer) {
                            *value = max_integer;
                        } else if (*value > max_integer) {
                            *value = max_integer;
                        }
                        break;
                    }
                case lua_value_cardinal_code:
                    {
                        lua_Unsigned u = lua_type(L, -1) == LUA_TNUMBER ? (lua_Unsigned) lua_tointeger(L, -1) : 0;
                        if (u > max_cardinal) {
                            u = max_cardinal;
                        }
                        if (*value > max_integer) {
                            *value = (halfword) (u - 0x100000000);
                        } else {
                            *value = (halfword) u;
                        }
                        break;
                    }
                case lua_value_dimension_code:
                    {
                        *value = lua_type(L, -1) == LUA_TNUMBER ? lmt_tohalfword(L, -1) : 0;
                        if (*value < - max_dimen) {
                            *value = max_dimen;
                        } else if (*value > max_dimen) {
                            *value = max_dimen;
                        }
                        break;
                    }
                case lua_value_skip_code:
                    {
                        halfword n = lmt_check_isnode(L, -1);
                        if (n && node_type(n) == glue_spec_node) {
                            *value = n;
                        } else {
                            luaL_error(L, "gluespec node expected");
                            *value = tex_copy_node(zero_glue);
                        }
                        break;
                    }
                case lua_value_float_code:
                case lua_value_string_code:
                    {
                        class = lua_value_none_code;
                        break;
                    }
                case lua_value_boolean_code:
                    {
                        *value = lua_toboolean(L, -1);
                        break;
                    }
                case lua_value_node_code:
                    {
                        *value = lmt_check_isnode(L, -1);
                        break;
                    }
                case lua_value_direct_code:
                        *value = lmt_check_isdirect(L, -1);
                        break;
                default:
                    {
                        class = lua_value_none_code;
                        break;
                    }
            }
        }
    }
    lua_settop(L, stacktop);
    return class;
}

/* some day maybe an alternative too

void lmt_function_call(int slot)
{
    lua_State *L = lua_state.lua_instance;
    int stacktop = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, lua_state.function_table_id);
    if (lua_rawgeti(L, -1, slot) == LUA_TFUNCTION) {
        lua_pushinteger(L, slot);
        ++lua_state.function_callback_count;
        lua_call(L, 1, 0);
    }
    lua_settop(L,stacktop);
}

*/

int lmt_push_specification(lua_State *L, halfword ptr, int onlycount)
{
    if (ptr) {
        switch (node_subtype(ptr)) {
            case par_shape_code:
                {
                    int n = specification_count(ptr);
                    if (onlycount == 1) {
                        lua_pushinteger(L, n);
                    } else {
                        int r = specification_repeat(ptr);
                        lua_createtable(L, n, r ? 1 : 0);
                        if (r) {
                            lua_push_boolean_at_key(L, repeat, r);
                        }
                        for (int m = 1; m <= n; m++) {
                            lua_createtable(L, 2, 0);
                            lua_pushinteger(L, tex_get_specification_indent(ptr, m));
                            lua_rawseti(L, -2, 1);
                            lua_pushinteger(L, tex_get_specification_width(ptr, m));
                            lua_rawseti(L, -2, 2);
                            lua_rawseti(L, -2, m);
                        }
                    }
                    return 1;
                }
            case inter_line_penalties_code:
            case club_penalties_code:
            case widow_penalties_code:
            case display_widow_penalties_code:
            case orphan_penalties_code:
            case math_forward_penalties_code:
            case math_backward_penalties_code:
                {
                    int n = specification_count(ptr);
                    if (onlycount == 1) {
                        lua_pushinteger(L, n);
                    } else {
                        lua_createtable(L, n, 0);
                        for (int m = 1; m <= n; m++) {
                            lua_pushinteger(L, tex_get_specification_penalty(ptr, m));
                            lua_rawseti(L, -2, m);
                        }
                    }
                    return 1;
                }
        }
    }
    lua_pushnil(L);
    return 1;
}
