/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    We start with a couple of \ETEX\ related comments:

    The |\showtokens| command displays a token list. The |\showifs| command displays all currently
    active conditionals.

    The |\unexpanded| primitive prevents expansion of tokens much as the result from |\the| applied
    to a token variable. The |\detokenize| primitive converts a token list into a list of character
    tokens much as if the token list were written to a file. We use the fact that the command
    modifiers for |\unexpanded| and |\detokenize| are odd whereas those for |\the| and |\showthe|
    are even.

    The |protected| feature of \ETEX\ defines the |\protected| prefix command for macro definitions.
    Such macros are protected against expansions when lists of expanded tokens are built, e.g., for
    |\edef| or during |\write|.

    The |\pagediscards| and |\splitdiscards| commands share the command code |un_vbox| with |\unvbox|
    and |\unvcopy|, they are distinguished by their |chr_code| values |last_box_code| and
    |vsplit_code|. These |chr_code| values are larger than |box_code| and |copy_code|.

    The |\interlinepenalties|, |\clubpenalties|, |\widowpenalties|, and |\displaywidowpenalties|
    commands allow to define arrays of penalty values to be used instead of the corresponding single
    values.

*/

/*tex

    The symbolic names for glue parameters are put into \TEX's hash table by using the routine called
    |primitive|, defined below. Let us enter them now, so that we don't have to list all those
    parameter names anywhere else.

    Many of \TEX's primitives need no |equiv|, since they are identifiable by their |eq_type| alone.
    These primitives are loaded into the hash table.

    The processing of |\input| involves the |start_input| subroutine, which will be declared later;
    the processing of |\endinput| is trivial.

    The hash table is initialized with |\count|, |\attribute|, |\dimen|, |\skip|, and |\muskip| all
    having |register| as their command code; they are distinguished by the |chr_code|, which is
    either |int_val|, |attr_val|, |dimen_val|, |glue_val|, or |mu_val|.

    Because in \LUATEX\ and \LUAMETATEX\ we have more primitives, and use a lookup table, we combine
    commands, for instance the |\aftergroup| and |\afterassignment| are just simple runners and
    instead of the old two single cases, we now have one case that handles the four variants. This
    keeps similar code close and also saves lookups. So, we have a few |cmd| less than normally in
    a \TEX\ engine, but also a few more. Some have been renamed because they do more now (already
    in \ETEX).

*/

const unsigned char some_item_classification[] = {
    [lastpenalty_code]              = classification_no_arguments,
    [lastkern_code]                 = classification_no_arguments,
    [lastskip_code]                 = classification_no_arguments,
    [lastboundary_code]             = classification_no_arguments,
    [last_node_type_code]           = classification_no_arguments,
    [last_node_subtype_code]        = classification_no_arguments,
    [input_line_no_code]            = classification_no_arguments,
    [badness_code]                  = classification_no_arguments,
    [overshoot_code]                = classification_no_arguments,
    [luatex_version_code]           = classification_no_arguments,
    [luatex_revision_code]          = classification_no_arguments,
    [current_group_level_code]      = classification_no_arguments,
    [current_group_type_code]       = classification_no_arguments,
    [current_stack_size_code]       = classification_no_arguments,
    [current_if_level_code]         = classification_no_arguments,
    [current_if_type_code]          = classification_no_arguments,
    [current_if_branch_code]        = classification_no_arguments,
    [glue_stretch_order_code]       = classification_unknown,
    [glue_shrink_order_code]        = classification_unknown,
    [font_id_code]                  = classification_unknown,
    [glyph_x_scaled_code]           = classification_unknown,
    [glyph_y_scaled_code]           = classification_unknown,
    [font_char_wd_code]             = classification_unknown,
    [font_char_ht_code]             = classification_unknown,
    [font_char_dp_code]             = classification_unknown,
    [font_char_ic_code]             = classification_unknown,
    [font_char_ta_code]             = classification_unknown,
    [font_char_ba_code]             = classification_unknown,
    [scaled_font_char_wd_code]      = classification_unknown,
    [scaled_font_char_ht_code]      = classification_unknown,
    [scaled_font_char_dp_code]      = classification_unknown,
    [scaled_font_char_ic_code]      = classification_unknown,
    [scaled_font_char_ta_code]      = classification_unknown,
    [scaled_font_char_ba_code]      = classification_unknown,
    [font_spec_id_code]             = classification_unknown,
    [font_spec_scale_code]          = classification_unknown,
    [font_spec_xscale_code]         = classification_unknown,
    [font_spec_yscale_code]         = classification_unknown,
    [font_size_code]                = classification_unknown,
    [font_math_control_code]        = classification_unknown,
    [font_text_control_code]        = classification_unknown,
    [math_scale_code]               = classification_unknown,
    [math_style_code]               = classification_no_arguments,
    [math_main_style_code]          = classification_no_arguments,
    [math_parent_style_code]        = classification_no_arguments,
    [math_style_font_id_code]       = classification_unknown,
    [math_stack_style_code]         = classification_no_arguments,
    [math_char_class_code]          = classification_unknown,
    [math_char_fam_code]            = classification_unknown,
    [math_char_slot_code]           = classification_unknown,
    [scaled_slant_per_point_code]   = classification_no_arguments,
    [scaled_interword_space_code]   = classification_no_arguments,
    [scaled_interword_stretch_code] = classification_no_arguments,
    [scaled_interword_shrink_code]  = classification_no_arguments,
    [scaled_ex_height_code]         = classification_no_arguments,
    [scaled_em_width_code]          = classification_no_arguments,
    [scaled_extra_space_code]       = classification_no_arguments,
    [last_arguments_code]           = classification_no_arguments,
    [parameter_count_code]          = classification_no_arguments,
    [parameter_index_code]          = classification_no_arguments,
 /* [lua_value_function_code]       = classification_no_arguments, */
    [insert_progress_code]          = classification_unknown,
    [left_margin_kern_code]         = classification_unknown,
    [right_margin_kern_code]        = classification_unknown,
    [par_shape_length_code]         = classification_unknown,
    [par_shape_indent_code]         = classification_unknown,
    [par_shape_width_code]          = classification_unknown,
    [glue_stretch_code]             = classification_unknown,
    [glue_shrink_code]              = classification_unknown,
    [mu_to_glue_code]               = classification_unknown,
    [glue_to_mu_code]               = classification_unknown,
    [numexpr_code]                  = classification_unknown,
    [posexpr_code]                  = classification_unknown,
 /* [attrexpr_code]                 = classification_unknown, */
    [dimexpr_code]                  = classification_unknown,
    [glueexpr_code]                 = classification_unknown,
    [muexpr_code]                   = classification_unknown,
    [numexpression_code]            = classification_unknown,
    [dimexpression_code]            = classification_unknown,
    [last_chk_integer_code]         = classification_unknown,
    [last_chk_dimension_code]       = classification_unknown,
 // [dimen_to_scale_code]           = classification_no_arguments,
    [numeric_scale_code]            = classification_no_arguments,
    [numeric_scaled_code]           = classification_no_arguments,
    [index_of_register_code]        = classification_unknown,
    [index_of_character_code]       = classification_unknown,
    [math_atom_glue_code]           = classification_unknown,
    [last_left_class_code]          = classification_no_arguments,
    [last_right_class_code]         = classification_no_arguments,
    [last_atom_class_code]          = classification_no_arguments,
    [nested_loop_iterator_code]     = classification_no_arguments,
    [previous_loop_iterator_code]   = classification_no_arguments,
    [current_loop_iterator_code]    = classification_no_arguments,
    [current_loop_nesting_code]     = classification_no_arguments,
    [last_loop_iterator_code]       = classification_no_arguments,
    [last_par_context_code]         = classification_no_arguments,
    [last_page_extra_code]          = classification_no_arguments,
    [last_line_width_code]          = classification_no_arguments,
    [last_line_count_code]          = classification_no_arguments,
};

const unsigned char some_convert_classification[] = {
    [number_code]              = classification_integer,
    [to_integer_code]          = classification_integer,
    [to_hexadecimal_code]      = classification_integer,
    [to_scaled_code]           = classification_integer,
    [to_sparse_scaled_code]    = classification_integer,
    [to_dimension_code]        = classification_integer,
    [to_sparse_dimension_code] = classification_integer,
    [to_mathstyle_code]        = classification_unknown,
    [lua_code]                 = classification_unknown,
    [lua_function_code]        = classification_unknown,
    [lua_bytecode_code]        = classification_unknown,
    [expanded_code]            = classification_unknown,
    [semi_expanded_code]       = classification_unknown,
 /* [expanded_after_cs_code]   = classification_unknown, */
    [string_code]              = classification_unknown,
    [cs_string_code]           = classification_unknown,
    [cs_active_code]           = classification_unknown,
    [cs_lastname_code]         = classification_unknown,
    [detokenized_code]         = classification_unknown,
    [detokened_code]           = classification_unknown,
    [roman_numeral_code]       = classification_integer,
    [meaning_code]             = classification_unknown,
    [meaning_full_code]        = classification_unknown,
    [meaning_less_code]        = classification_unknown,
    [meaning_asis_code]        = classification_unknown,
    [meaning_ful_code]         = classification_unknown,
    [meaning_les_code]         = classification_unknown,
    [to_character_code]        = classification_integer,
    [lua_escape_string_code]   = classification_unknown,
 /* [lua_token_string_code]    = classification_unknown, */
    [font_name_code]           = classification_integer,
    [font_specification_code]  = classification_integer,
    [job_name_code]            = classification_no_arguments,
    [format_name_code]         = classification_no_arguments,
    [luatex_banner_code]       = classification_no_arguments,
    [font_identifier_code]     = classification_integer,
};

static void tex_aux_copy_deep_frozen_from_primitive(halfword code, const char *name)
{
    /* Is this okay? */
    halfword p = tex_primitive_lookup(tex_located_string(name));
    /* As lookup needs a string! */
// strnumber s = tex_maketexstring(name);
// halfword p = tex_primitive_lookup(s); /* todo: no need for tex string */
// tex_flush_str(s);
    cs_text(code) = cs_text(p);
    copy_eqtb_entry(code, p);
}

/*
    The commands are sorted alphabetically which makes it easier to check the syntax charts. The
    order within the command classes is more chronological.
*/

/* todo: get rid of fontdimen and use the few named ones */

void tex_initialize_commands(void)
{

    if (lmt_main_state.run_state == initializing_state) {

        lmt_hash_state.no_new_cs = 0;
        lmt_fileio_state.io_first = 0;

        /*tex glue */
                                          
        tex_primitive(tex_command,        display_legacy,  "abovedisplayshortskip",          internal_glue_cmd,      above_display_short_skip_code,            internal_glue_base);
        tex_primitive(tex_command,        display_legacy,  "abovedisplayskip",               internal_glue_cmd,      above_display_skip_code,                  internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "additionalpageskip",             internal_glue_cmd,      additional_page_skip_code,                internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "balancetopskip",                 internal_glue_cmd,      balance_top_skip_code,                    internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "balancebottomskip",              internal_glue_cmd,      balance_bottom_skip_code,                 internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "baselineskip",                   internal_glue_cmd,      baseline_skip_code,                       internal_glue_base);
        tex_primitive(tex_command,        display_legacy,  "belowdisplayshortskip",          internal_glue_cmd,      below_display_short_skip_code,            internal_glue_base);
        tex_primitive(tex_command,        display_legacy,  "belowdisplayskip",               internal_glue_cmd,      below_display_skip_code,                  internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "bottomskip",                     internal_glue_cmd,      bottom_skip_code,                         internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "emergencyleftskip",              internal_glue_cmd,      emergency_left_skip_code,                 internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "emergencyrightskip",             internal_glue_cmd,      emergency_right_skip_code,                internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "initialpageskip",                internal_glue_cmd,      initial_page_skip_code,                   internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "initialtopskip",                 internal_glue_cmd,      initial_top_skip_code,                    internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "leftskip",                       internal_glue_cmd,      left_skip_code,                           internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "lineskip",                       internal_glue_cmd,      line_skip_code,                           internal_glue_base);
        tex_primitive(luatex_command,     no_legacy,       "mathsurroundskip",               internal_glue_cmd,      math_skip_code,                           internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "maththreshold",                  internal_glue_cmd,      math_threshold_code,                      internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "parfillleftskip",                internal_glue_cmd,      par_fill_left_skip_code,                  internal_glue_base);
        tex_primitive(luametatex_command, aliased_legacy,  "parfillrightskip",               internal_glue_cmd,      par_fill_right_skip_code,                 internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "parfillskip",                    internal_glue_cmd,      par_fill_right_skip_code,                 internal_glue_base); /*tex This is more like an alias now. */
        tex_primitive(luametatex_command, no_legacy,       "parinitleftskip",                internal_glue_cmd,      par_init_left_skip_code,                  internal_glue_base);
        tex_primitive(luametatex_command, no_legacy,       "parinitrightskip",               internal_glue_cmd,      par_init_right_skip_code,                 internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "parskip",                        internal_glue_cmd,      par_skip_code,                            internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "rightskip",                      internal_glue_cmd,      right_skip_code,                          internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "spaceskip",                      internal_glue_cmd,      space_skip_code,                          internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "splittopskip",                   internal_glue_cmd,      split_top_skip_code,                      internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "tabskip",                        internal_glue_cmd,      tab_skip_code,                            internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "topskip",                        internal_glue_cmd,      top_skip_code,                            internal_glue_base);
        tex_primitive(tex_command,        no_legacy,       "xspaceskip",                     internal_glue_cmd,      xspace_skip_code,                         internal_glue_base);

        /*tex math glue */

        tex_primitive(tex_command,        no_legacy,       "medmuskip",                      internal_muglue_cmd,    med_muskip_code,                          internal_muglue_base);
        tex_primitive(luametatex_command, no_legacy,       "pettymuskip",                    internal_muglue_cmd,    petty_muskip_code,                        internal_muglue_base);
        tex_primitive(tex_command,        no_legacy,       "thickmuskip",                    internal_muglue_cmd,    thick_muskip_code,                        internal_muglue_base);
        tex_primitive(tex_command,        no_legacy,       "thinmuskip",                     internal_muglue_cmd,    thin_muskip_code,                         internal_muglue_base);
        tex_primitive(luametatex_command, no_legacy,       "tinymuskip",                     internal_muglue_cmd,    tiny_muskip_code,                         internal_muglue_base);

        /*tex tokens */

        tex_primitive(no_command,         no_legacy,       "endofgroup",                     internal_toks_cmd,      end_of_group_code,                        internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "errhelp",                        internal_toks_cmd,      error_help_code,                          internal_toks_base);
        tex_primitive(luametatex_command, no_legacy,       "everybeforepar",                 internal_toks_cmd,      every_before_par_code,                    internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "everycr",                        internal_toks_cmd,      every_cr_code,                            internal_toks_base);
        tex_primitive(tex_command,        display_legacy,  "everydisplay",                   internal_toks_cmd,      every_display_code,                       internal_toks_base);
        tex_primitive(etex_command,       no_legacy,       "everyeof",                       internal_toks_cmd,      every_eof_code,                           internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "everyhbox",                      internal_toks_cmd,      every_hbox_code,                          internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "everyjob",                       internal_toks_cmd,      every_job_code,                           internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "everymath",                      internal_toks_cmd,      every_math_code,                          internal_toks_base);
        tex_primitive(luametatex_command, no_legacy,       "everymathatom",                  internal_toks_cmd,      every_math_atom_code,                     internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "everypar",                       internal_toks_cmd,      every_par_code,                           internal_toks_base);
        tex_primitive(luametatex_command, no_legacy,       "everyparbegin",                  internal_toks_cmd,      every_par_begin_code,                     internal_toks_base);
        tex_primitive(luametatex_command, no_legacy,       "everyparend",                    internal_toks_cmd,      every_par_end_code,                       internal_toks_base);
        tex_primitive(luametatex_command, no_legacy,       "everytab",                       internal_toks_cmd,      every_tab_code,                           internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "everyvbox",                      internal_toks_cmd,      every_vbox_code,                          internal_toks_base);
        tex_primitive(tex_command,        no_legacy,       "output",                         internal_toks_cmd,      output_routine_code,                      internal_toks_base);

        /*tex counters (we could omit the int_base here as effectively it is subtracted) */

        tex_primitive(tex_command,        single_legacy,   "adjdemerits",                    internal_integer_cmd,   adj_demerits_code,                        internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "adjustspacing",                  internal_integer_cmd,   adjust_spacing_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "adjustspacingshrink",            internal_integer_cmd,   adjust_spacing_shrink_code,               internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "adjustspacingstep",              internal_integer_cmd,   adjust_spacing_step_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "adjustspacingstretch",           internal_integer_cmd,   adjust_spacing_stretch_code,              internal_integer_base);
     /* tex_primitive(luametatex_command, no_legacy,       "alignmentcellattr",              internal_integer_cmd,   alignment_cell_attribute_code,            internal_integer_base); */ /* todo */
        tex_primitive(luametatex_command, no_legacy,       "alignmentcellsource",            internal_integer_cmd,   alignment_cell_source_code,               internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "alignmentwrapsource",            internal_integer_cmd,   alignment_wrap_source_code,               internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "automatichyphenpenalty",         internal_integer_cmd,   automatic_hyphen_penalty_code,            internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "automigrationmode",              internal_integer_cmd,   auto_migration_mode_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "autoparagraphmode",              internal_integer_cmd,   auto_paragraph_mode_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "balancechecks",                  internal_integer_cmd,   balance_checks_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "balancebreakpasses",             internal_integer_cmd,   balance_break_passes_code,                internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "balancetolerance",               internal_integer_cmd,   balance_tolerance_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "balanceadjdemerits",             internal_integer_cmd,   balance_adj_demerits_code,                internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "balancelooseness",               internal_integer_cmd,   balance_looseness_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "balancepenalty",                 internal_integer_cmd,   balance_penalty_code,                     internal_integer_base);
        tex_primitive(tex_command,        math_legacy,     "binoppenalty",                   internal_integer_cmd,   post_binary_penalty_code,                 internal_integer_base); /*tex For old times sake. */
        tex_primitive(tex_command,        single_legacy,   "brokenpenalty",                  internal_integer_cmd,   broken_penalty_code,                      internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "catcodetable",                   internal_integer_cmd,   cat_code_table_code,                      internal_integer_base);
        tex_primitive(tex_command,        single_legacy,   "clubpenalty",                    internal_integer_cmd,   club_penalty_code,                        internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "day",                            internal_integer_cmd,   day_code,                                 internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "defaulthyphenchar",              internal_integer_cmd,   default_hyphen_char_code,                 internal_integer_base);
        tex_primitive(tex_command,        math_legacy,     "defaultskewchar",                internal_integer_cmd,   default_skew_char_code,                   internal_integer_base);
        tex_primitive(tex_command,        math_legacy,     "delimiterfactor",                internal_integer_cmd,   delimiter_factor_code,                    internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "discretionaryoptions",           internal_integer_cmd,   discretionary_options_code,               internal_integer_base);
        tex_primitive(tex_command,        display_legacy,  "displaywidowpenalty",            internal_integer_cmd,   display_widow_penalty_code,               internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "doublehyphendemerits",           internal_integer_cmd,   double_hyphen_demerits_code,              internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "doublepenaltymode",              internal_integer_cmd,   double_penalty_mode_code,                 internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "endlinechar",                    internal_integer_cmd,   end_line_char_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "errorcontextlines",              internal_integer_cmd,   error_context_lines_code,                 internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "escapechar",                     internal_integer_cmd,   escape_char_code,                         internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "spacechar",                      internal_integer_cmd,   space_char_code,                          internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "etexexprmode",                   internal_integer_cmd,   etex_expr_mode_code,                      internal_integer_base); /* Some want this. */
        tex_primitive(luametatex_command, no_legacy,       "eufactor",                       internal_integer_cmd,   eu_factor_code,                           internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "exceptionpenalty",               internal_integer_cmd,   exception_penalty_code,                   internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "exhyphenchar",                   internal_integer_cmd,   ex_hyphen_char_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "exhyphenpenalty",                internal_integer_cmd,   ex_hyphen_penalty_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "exapostrophechar",               internal_integer_cmd,   ex_apostrophe_char_code,                  internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "explicithyphenpenalty",          internal_integer_cmd,   explicit_hyphen_penalty_code,             internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "fam",                            internal_integer_cmd,   family_code,                              internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "finalhyphendemerits",            internal_integer_cmd,   final_hyphen_demerits_code,               internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "firstvalidlanguage",             internal_integer_cmd,   first_valid_language_code,                internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "floatingpenalty",                internal_integer_cmd,   floating_penalty_code,                    internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "globaldefs",                     internal_integer_cmd,   global_defs_code,                         internal_integer_base);
     /* tex_primitive(luametatex_command, no_legacy,       "gluedatafield",                  internal_integer_cmd,   glue_data_code,                           internal_integer_base); */
        tex_primitive(luametatex_command, no_legacy,       "glyphdatafield",                 internal_integer_cmd,   glyph_data_code,                          internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphoptions",                   internal_integer_cmd,   glyph_options_code,                       internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphscale",                     internal_integer_cmd,   glyph_scale_code,                         internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphscriptfield",               internal_integer_cmd,   glyph_script_code,                        internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphscriptscale",               internal_integer_cmd,   glyph_script_scale_code,                  internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphscriptscriptscale",         internal_integer_cmd,   glyph_scriptscript_scale_code,            internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphstatefield",                internal_integer_cmd,   glyph_state_code,                         internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphtextscale",                 internal_integer_cmd,   glyph_text_scale_code,                    internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphxscale",                    internal_integer_cmd,   glyph_x_scale_code,                       internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphyscale",                    internal_integer_cmd,   glyph_y_scale_code,                       internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphslant",                     internal_integer_cmd,   glyph_slant_code,                         internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphweight",                    internal_integer_cmd,   glyph_weight_code,                        internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "hangafter",                      internal_integer_cmd,   hang_after_code,                          internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "hbadness",                       internal_integer_cmd,   hbadness_code,                            internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "hbadnessmode",                   internal_integer_cmd,   hbadness_mode_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "holdinginserts",                 internal_integer_cmd,   holding_inserts_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "holdingmigrations",              internal_integer_cmd,   holding_migrations_code,                  internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "hyphenationmode",                internal_integer_cmd,   hyphenation_mode_code,                    internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "hyphenpenalty",                  internal_integer_cmd,   hyphen_penalty_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "interlinepenalty",               internal_integer_cmd,   inter_line_penalty_code,                  internal_integer_base);
        tex_primitive(no_command,         no_legacy,       "internaldirstate",               internal_integer_cmd,   internal_dir_state_code,                  internal_integer_base);
        tex_primitive(no_command,         no_legacy,       "internalmathscale",              internal_integer_cmd,   internal_math_scale_code,                 internal_integer_base);
        tex_primitive(no_command,         no_legacy,       "internalmathstyle",              internal_integer_cmd,   internal_math_style_code,                 internal_integer_base);
        tex_primitive(no_command,         no_legacy,       "internalparstate",               internal_integer_cmd,   internal_par_state_code,                  internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "language",                       internal_integer_cmd,   language_code,                            internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "lastlinefit",                    internal_integer_cmd,   last_line_fit_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "lefthyphenmin",                  internal_integer_cmd,   left_hyphen_min_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "linebreakoptional",              internal_integer_cmd,   line_break_optional_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "linebreakpasses",                internal_integer_cmd,   line_break_passes_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "linebreakchecks",                internal_integer_cmd,   line_break_checks_code,                   internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "linedirection",                  internal_integer_cmd,   line_direction_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "linepenalty",                    internal_integer_cmd,   line_penalty_code,                        internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "localbrokenpenalty",             internal_integer_cmd,   local_broken_penalty_code,                internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "localinterlinepenalty",          internal_integer_cmd,   local_interline_penalty_code,             internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "localpretolerance",              internal_integer_cmd,   local_pre_tolerance_code,                 internal_integer_base); /* not that useful */
        tex_primitive(luametatex_command, no_legacy,       "localtolerance",                 internal_integer_cmd,   local_tolerance_code,                     internal_integer_base); /* not that useful */
        tex_primitive(tex_command,        no_legacy,       "looseness",                      internal_integer_cmd,   looseness_code,                           internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "luacopyinputnodes",              internal_integer_cmd,   copy_lua_input_nodes_code,                internal_integer_base);
     /* tex_primitive(tex_command,        ignored_legacy,  "mag",                            internal_integer_cmd,   mag_code,                                 internal_integer_base); */ /* backend */
        tex_primitive(luametatex_command, no_legacy,       "mathbeginclass",                 internal_integer_cmd,   math_begin_class_code,                    internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathcheckfencesmode",            internal_integer_cmd,   math_check_fences_mode_code,              internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathdictgroup",                  internal_integer_cmd,   math_dict_group_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathdictproperties",             internal_integer_cmd,   math_dict_properties_code,                internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "mathdirection",                  internal_integer_cmd,   math_direction_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathdisplaymode",                internal_integer_cmd,   math_display_mode_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathdisplaypenaltyfactor",       internal_integer_cmd,   math_display_penalty_factor_code,         internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "mathdisplayskipmode",            internal_integer_cmd,   math_display_skip_mode_code,              internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathdoublescriptmode",           internal_integer_cmd,   math_double_script_mode_code,             internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathendclass",                   internal_integer_cmd,   math_end_class_code,                      internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "matheqnogapstep",                internal_integer_cmd,   math_eqno_gap_step_code,                  internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathfontcontrol",                internal_integer_cmd,   math_font_control_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathgluemode",                   internal_integer_cmd,   math_glue_mode_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathgroupingmode",               internal_integer_cmd,   math_grouping_mode_code,                  internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathinlinepenaltyfactor",        internal_integer_cmd,   math_inline_penalty_factor_code,          internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathleftclass",                  internal_integer_cmd,   math_left_class_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathlimitsmode",                 internal_integer_cmd,   math_limits_mode_code,                    internal_integer_base);
     /* tex_primitive(luametatex_command, no_legacy,       "mathnolimitsmode",               internal_integer_cmd,   math_nolimits_mode_code,                  internal_integer_base); */
        tex_primitive(luametatex_command, no_legacy,       "mathoptions",                    internal_integer_cmd,   math_options_code,                        internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "mathpenaltiesmode",              internal_integer_cmd,   math_penalties_mode_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathpretolerance",               internal_integer_cmd,   math_pre_tolerance_code,                  internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathrightclass",                 internal_integer_cmd,   math_right_class_code,                    internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "mathrulesfam",                   internal_integer_cmd,   math_rules_fam_code,                      internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "mathrulesmode",                  internal_integer_cmd,   math_rules_mode_code,                     internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "mathscriptsmode",                internal_integer_cmd,   math_scripts_mode_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathslackmode",                  internal_integer_cmd,   math_slack_mode_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathspacingmode",                internal_integer_cmd,   math_spacing_mode_code,                   internal_integer_base); /*tex Inject zero spaces, for tracing */
        tex_primitive(luametatex_command, no_legacy,       "mathsurroundmode",               internal_integer_cmd,   math_skip_mode_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "mathtolerance",                  internal_integer_cmd,   math_tolerance_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "emptyparagraphmode",             internal_integer_cmd,   empty_paragraph_mode_code,                internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "maxdeadcycles",                  internal_integer_cmd,   max_dead_cycles_code,                     internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "month",                          internal_integer_cmd,   month_code,                               internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "newlinechar",                    internal_integer_cmd,   new_line_char_code,                       internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "normalizelinemode",              internal_integer_cmd,   normalize_line_mode_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "normalizeparmode",               internal_integer_cmd,   normalize_par_mode_code,                  internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "nospaces",                       internal_integer_cmd,   no_spaces_code,                           internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "outputbox",                      internal_integer_cmd,   output_box_code,                          internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "nooutputboxerror",               internal_integer_cmd,   no_output_box_error_code,                 internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "outputpenalty",                  internal_integer_cmd,   output_penalty_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "overloadmode",                   internal_integer_cmd,   overload_mode_code,                       internal_integer_base);
     /* tex_primitive(luametatex_command, no_legacy,       "pageboundarypenalty",            internal_integer_cmd,   page_boundary_penalty_code,               internal_integer_base); */
        tex_primitive(luametatex_command, no_legacy,       "parametermode",                  internal_integer_cmd,   parameter_mode_code,                      internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "pardirection",                   internal_integer_cmd,   par_direction_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "pausing",                        internal_integer_cmd,   pausing_code,                             internal_integer_base);
        tex_primitive(tex_command,        display_legacy,  "postdisplaypenalty",             internal_integer_cmd,   post_display_penalty_code,                internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "postinlinepenalty",              internal_integer_cmd,   post_inline_penalty_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "postshortinlinepenalty",         internal_integer_cmd,   post_short_inline_penalty_code,           internal_integer_base);
        tex_primitive(luatex_command,     math_legacy,     "prebinoppenalty",                internal_integer_cmd,   pre_binary_penalty_code,                  internal_integer_base); /*tex For old times sake. */
        tex_primitive(luatex_command,     display_legacy,  "predisplaydirection",            internal_integer_cmd,   pre_display_direction_code,               internal_integer_base);
        tex_primitive(luatex_command,     display_legacy,  "predisplaygapfactor",            internal_integer_cmd,   math_pre_display_gap_factor_code,         internal_integer_base);
        tex_primitive(tex_command,        display_legacy,  "predisplaypenalty",              internal_integer_cmd,   pre_display_penalty_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "preinlinepenalty",               internal_integer_cmd,   pre_inline_penalty_code,                  internal_integer_base);
        tex_primitive(luatex_command,     math_legacy,     "prerelpenalty",                  internal_integer_cmd,   pre_relation_penalty_code,                internal_integer_base); /*tex For old times sake. */
        tex_primitive(luametatex_command, no_legacy,       "preshortinlinepenalty",          internal_integer_cmd,   pre_short_inline_penalty_code,            internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "pretolerance",                   internal_integer_cmd,   pre_tolerance_code,                       internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "protrudechars",                  internal_integer_cmd,   protrude_chars_code,                      internal_integer_base);
        tex_primitive(tex_command,        math_legacy,     "relpenalty",                     internal_integer_cmd,   post_relation_penalty_code,               internal_integer_base); /*tex For old times sake. */
        tex_primitive(tex_command,        no_legacy,       "righthyphenmin",                 internal_integer_cmd,   right_hyphen_min_code,                    internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "savinghyphcodes",                internal_integer_cmd,   saving_hyph_codes_code,                   internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "savingvdiscards",                internal_integer_cmd,   saving_vdiscards_code,                    internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "scriptspacebeforefactor",        internal_integer_cmd,   script_space_before_factor_code,          internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "scriptspacebetweenfactor",       internal_integer_cmd,   script_space_between_factor_code,         internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "scriptspaceafterfactor",         internal_integer_cmd,   script_space_after_factor_code,           internal_integer_base);
        tex_primitive(luatex_command,     no_legacy,       "setfontid",                      internal_integer_cmd,   font_code,                                internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "setlanguage",                    internal_integer_cmd,   language_code,                            internal_integer_base); /* compatibility */
        tex_primitive(luametatex_command, no_legacy,       "shapingpenaltiesmode",           internal_integer_cmd,   shaping_penalties_mode_code,              internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "shapingpenalty",                 internal_integer_cmd,   shaping_penalty_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "shortinlineorphanpenalty",       internal_integer_cmd,   short_inline_orphan_penalty_code,         internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "showboxbreadth",                 internal_integer_cmd,   show_box_breadth_code,                    internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "showboxdepth",                   internal_integer_cmd,   show_box_depth_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "shownodedetails",                internal_integer_cmd,   show_node_details_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "singlelinepenalty",              internal_integer_cmd,   single_line_penalty_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "lefttwindemerits",               internal_integer_cmd,   left_twin_demerits_code,                  internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "righttwindemerits",              internal_integer_cmd,   right_twin_demerits_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "spacefactormode",                internal_integer_cmd,   space_factor_mode,                        internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "spacefactorshrinklimit",         internal_integer_cmd,   space_factor_shrink_limit_code,           internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "spacefactorstretchlimit",        internal_integer_cmd,   space_factor_stretch_limit_code,          internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "spacefactoroverload",            internal_integer_cmd,   space_factor_overload_code,               internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "boxlimitmode",                   internal_integer_cmd,   box_limit_mode_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "supmarkmode",                    internal_integer_cmd,   sup_mark_mode_code,                       internal_integer_base);
     /* tex_primitive(luametatex_command, no_legacy,       "commentmode",                    internal_integer_cmd,   comment_mode_code,                        internal_integer_base); */ /* experiment */
        tex_primitive(luatex_command,     no_legacy,       "textdirection",                  internal_integer_cmd,   text_direction_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "time",                           internal_integer_cmd,   time_code,                                internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tolerance",                      internal_integer_cmd,   tolerance_code,                           internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingadjusts",                 internal_integer_cmd,   tracing_adjusts_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingalignments",              internal_integer_cmd,   tracing_alignments_code,                  internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "tracingassigns",                 internal_integer_cmd,   tracing_assigns_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingbalancing",               internal_integer_cmd,   tracing_balancing_code,                   internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingcommands",                internal_integer_cmd,   tracing_commands_code,                    internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingexpressions",             internal_integer_cmd,   tracing_expressions_code,                 internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingfitness",                 internal_integer_cmd,   tracing_fitness_code,                     internal_integer_base);
     /* tex_primitive(luatex_command,     no_legacy,       "tracingfonts",                   internal_integer_cmd,   tracing_fonts_code,                       internal_integer_base); */
        tex_primitive(luametatex_command, no_legacy,       "tracingfullboxes",               internal_integer_cmd,   tracing_full_boxes_code,                  internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "tracinggroups",                  internal_integer_cmd,   tracing_groups_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracinghyphenation",             internal_integer_cmd,   tracing_hyphenation_code,                 internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "tracingifs",                     internal_integer_cmd,   tracing_ifs_code,                         internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracinginserts",                 internal_integer_cmd,   tracing_inserts_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracinglevels",                  internal_integer_cmd,   tracing_levels_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracinglists",                   internal_integer_cmd,   tracing_lists_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingloners",                  internal_integer_cmd,   tracing_loners_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracinglostchars",               internal_integer_cmd,   tracing_lost_chars_code,                  internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingmacros",                  internal_integer_cmd,   tracing_macros_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingmarks",                   internal_integer_cmd,   tracing_marks_code,                       internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingmath",                    internal_integer_cmd,   tracing_math_code,                        internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingmvl",                     internal_integer_cmd,   tracing_mvl_code,                         internal_integer_base);
        tex_primitive(etex_command,       no_legacy,       "tracingnesting",                 internal_integer_cmd,   tracing_nesting_code,                     internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingnodes",                   internal_integer_cmd,   tracing_nodes_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingonline",                  internal_integer_cmd,   tracing_online_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingorphans",                 internal_integer_cmd,   tracing_orphans_code,                     internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingoutput",                  internal_integer_cmd,   tracing_output_code,                      internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingpages",                   internal_integer_cmd,   tracing_pages_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingparagraphs",              internal_integer_cmd,   tracing_paragraphs_code,                  internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingpasses",                  internal_integer_cmd,   tracing_passes_code,                      internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracingpenalties",               internal_integer_cmd,   tracing_penalties_code,                   internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "tracinglooseness",               internal_integer_cmd,   tracing_looseness_code,                   internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingrestores",                internal_integer_cmd,   tracing_restores_code,                    internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "tracingstats",                   internal_integer_cmd,   tracing_stats_code,                       internal_integer_base); /* obsolete */
        tex_primitive(luametatex_command, no_legacy,       "tracingtoddlers",                internal_integer_cmd,   tracing_toddlers_code,                    internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "uchyph",                         internal_integer_cmd,   uc_hyph_code,                             internal_integer_base); /* obsolete, not needed */
        tex_primitive(luatex_command,     no_legacy,       "variablefam",                    internal_integer_cmd,   variable_family_code,                     internal_integer_base); /* obsolete, not used */
        tex_primitive(tex_command,        no_legacy,       "vbadness",                       internal_integer_cmd,   vbadness_code,                            internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "vbadnessmode",                   internal_integer_cmd,   vbadness_mode_code,                       internal_integer_base);
        tex_primitive(luametatex_command, no_legacy,       "vsplitchecks",                   internal_integer_cmd,   vsplit_checks_code,                       internal_integer_base);
        tex_primitive(tex_command,        single_legacy,   "widowpenalty",                   internal_integer_cmd,   widow_penalty_code,                       internal_integer_base);
        tex_primitive(tex_command,        no_legacy,       "year",                           internal_integer_cmd,   year_code,                                internal_integer_base);

        /*tex dimensions */

        tex_primitive(luametatex_command, no_legacy,       "balanceemergencystretch",        internal_dimension_cmd, balance_emergency_stretch_code,           internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "balanceemergencyshrink",         internal_dimension_cmd, balance_emergency_shrink_code,            internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "balancevsize",                   internal_dimension_cmd, balance_vsize_code,                       internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "balancelineheight",              internal_dimension_cmd, balance_line_height_code,                 internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "boxmaxdepth",                    internal_dimension_cmd, box_max_depth_code,                       internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "delimitershortfall",             internal_dimension_cmd, delimiter_shortfall_code,                 internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "displayindent",                  internal_dimension_cmd, display_indent_code,                      internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "displaywidth",                   internal_dimension_cmd, display_width_code,                       internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "emergencyextrastretch",          internal_dimension_cmd, emergency_extra_stretch_code,             internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "emergencystretch",               internal_dimension_cmd, emergency_stretch_code,                   internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphxoffset",                   internal_dimension_cmd, glyph_x_offset_code,                      internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "glyphyoffset",                   internal_dimension_cmd, glyph_y_offset_code,                      internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "hangindent",                     internal_dimension_cmd, hang_indent_code,                         internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "hfuzz",                          internal_dimension_cmd, hfuzz_code,                               internal_dimension_base);
     /* tex_primitive(tex_command,        ignored_legacy,  "hoffset",                        internal_dimension_cmd, h_offset_code,                            internal_dimension_base); */ /* backend */
        tex_primitive(tex_command,        no_legacy,       "hsize",                          internal_dimension_cmd, hsize_code,                               internal_dimension_base);
        tex_primitive(luatex_command,     no_legacy,       "ignoredepthcriterion",           internal_dimension_cmd, ignore_depth_criterion_code,              internal_dimension_base); /* mostly for myself, tutorials etc */
        tex_primitive(tex_command,        no_legacy,       "lineskiplimit",                  internal_dimension_cmd, line_skip_limit_code,                     internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "mathsurround",                   internal_dimension_cmd, math_surround_code,                       internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "maxdepth",                       internal_dimension_cmd, max_depth_code,                           internal_dimension_base);
        tex_primitive(tex_command,        math_legacy,     "nulldelimiterspace",             internal_dimension_cmd, null_delimiter_space_code,                internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "overfullrule",                   internal_dimension_cmd, overfull_rule_code,                       internal_dimension_base);
        tex_primitive(luatex_command,     no_legacy,       "pageextragoal",                  internal_dimension_cmd, page_extra_goal_code,                     internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "parindent",                      internal_dimension_cmd, par_indent_code,                          internal_dimension_base);
        tex_primitive(tex_command,        display_legacy,  "predisplaysize",                 internal_dimension_cmd, pre_display_size_code,                    internal_dimension_base);
        tex_primitive(luatex_command,     no_legacy,       "pxdimen",                        internal_dimension_cmd, px_dimension_code,                        internal_dimension_base);
        tex_primitive(tex_command,        math_legacy,     "scriptspace",                    internal_dimension_cmd, script_space_code,                        internal_dimension_base);
        tex_primitive(luatex_command,     no_legacy,       "shortinlinemaththreshold",       internal_dimension_cmd, short_inline_math_threshold_code,         internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "splitmaxdepth",                  internal_dimension_cmd, split_max_depth_code,                     internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "splitextraheight",               internal_dimension_cmd, split_extra_height_code,                  internal_dimension_base);
        tex_primitive(luametatex_command, no_legacy,       "tabsize",                        internal_dimension_cmd, tab_size_code,                            internal_dimension_base);
        tex_primitive(tex_command,        no_legacy,       "vfuzz",                          internal_dimension_cmd, vfuzz_code,                               internal_dimension_base);
     /* tex_primitive(tex_command,        ignored_legacy,  "voffset",                        internal_dimension_cmd, v_offset_code,                            internal_dimension_base); */ /* backend */
        tex_primitive(tex_command,        no_legacy,       "vsize",                          internal_dimension_cmd, vsize_code,                               internal_dimension_base);

        /*tex Probably never used with \UNICODE\ omnipresent now: */

        tex_primitive(tex_command,        text_legacy,     "accent",                         accent_cmd,             normal_code,                              0);

        /*tex These three times two can go in one cmd: */

        tex_primitive(tex_command,        no_legacy,       "advance",                        arithmic_cmd,           advance_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "advanceby",                      arithmic_cmd,           advance_by_code,                          0);
     /* tex_primitive(luametatex_command, no_legacy,       "advancebyminusone",              arithmic_cmd,           advance_by_minus_one_code,                0); */
     /* tex_primitive(luametatex_command, no_legacy,       "advancebyplusone",               arithmic_cmd,           advance_by_plus_one_code,                 0); */
        tex_primitive(tex_command,        no_legacy,       "divide",                         arithmic_cmd,           divide_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "divideby",                       arithmic_cmd,           divide_by_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "rdivide",                        arithmic_cmd,           r_divide_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "rdivideby",                      arithmic_cmd,           r_divide_by_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "edivide",                        arithmic_cmd,           e_divide_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "edivideby",                      arithmic_cmd,           e_divide_by_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "multiply",                       arithmic_cmd,           multiply_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "multiplyby",                     arithmic_cmd,           multiply_by_code,                         0);

        /*tex We combined the after thingies into one category:*/

        tex_primitive(luametatex_command, no_legacy,       "afterassigned",                  after_something_cmd,    after_assigned_code,                      0);
        tex_primitive(tex_command,        no_legacy,       "afterassignment",                after_something_cmd,    after_assignment_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "aftergroup",                     after_something_cmd,    after_group_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "aftergrouped",                   after_something_cmd,    after_grouped_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "atendofgroup",                   after_something_cmd,    at_end_of_group_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "atendofgrouped",                 after_something_cmd,    at_end_of_grouped_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "atendoffile",                    after_something_cmd,    at_end_of_file_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "atendoffiled",                   after_something_cmd,    at_end_of_filed_code,                     0);

        tex_primitive(tex_command,        no_legacy,       "begingroup",                     begin_group_cmd,        semi_simple_group_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "beginmathgroup",                 begin_group_cmd,        math_simple_group_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "beginsimplegroup",               begin_group_cmd,        also_simple_group_code,                   0);

        tex_primitive(luametatex_command, no_legacy,       "boundary",                       boundary_cmd,           user_boundary,                            0);
        tex_primitive(luametatex_command, no_legacy,       "attributeboundary",              boundary_cmd,           attribute_boundary,                       0);
        tex_primitive(luametatex_command, no_legacy,       "luaboundary",                    boundary_cmd,           lua_boundary,                             0);
        tex_primitive(luametatex_command, no_legacy,       "mathboundary",                   boundary_cmd,           math_boundary,                            0);
        tex_primitive(luametatex_command, no_legacy,       "noboundary",                     boundary_cmd,           cancel_boundary,                          0);
        tex_primitive(luametatex_command, no_legacy,       "optionalboundary",               boundary_cmd,           optional_boundary,                        0);
        tex_primitive(luametatex_command, no_legacy,       "pageboundary",                   boundary_cmd,           page_boundary,                            0);
     /* tex_primitive(luametatex_command, no_legacy,       "parboundary",                    boundary_cmd,           par_boundary,                             0); */
        tex_primitive(luametatex_command, no_legacy,       "protrusionboundary",             boundary_cmd,           protrusion_boundary,                      0);
        tex_primitive(luametatex_command, no_legacy,       "wordboundary",                   boundary_cmd,           word_boundary,                            0);
        tex_primitive(luametatex_command, no_legacy,       "balanceboundary",                boundary_cmd,           balance_boundary,                         0);

        tex_primitive(luametatex_command, no_legacy,       "hpenalty",                       penalty_cmd,            h_penalty_code,                           0);
        tex_primitive(tex_command,        no_legacy,       "penalty",                        penalty_cmd,            normal_penalty_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "vpenalty",                       penalty_cmd,            v_penalty_code,                           0);

        tex_primitive(tex_command,        no_legacy,       "char",                           char_number_cmd,        char_number_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "glyph",                          char_number_cmd,        glyph_number_code,                        0);

        tex_primitive(luametatex_command, no_legacy,       "etoks",                          combine_toks_cmd,       expanded_toks_code,                       0);
        tex_primitive(luatex_command,     no_legacy,       "etoksapp",                       combine_toks_cmd,       append_expanded_toks_code,                0);
        tex_primitive(luatex_command,     no_legacy,       "etokspre",                       combine_toks_cmd,       prepend_expanded_toks_code,               0);
        tex_primitive(luatex_command,     no_legacy,       "gtoksapp",                       combine_toks_cmd,       global_append_toks_code,                  0);
        tex_primitive(luatex_command,     no_legacy,       "gtokspre",                       combine_toks_cmd,       global_prepend_toks_code,                 0);
        tex_primitive(luatex_command,     no_legacy,       "toksapp",                        combine_toks_cmd,       append_toks_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "tokspre",                        combine_toks_cmd,       prepend_toks_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "xtoks",                          combine_toks_cmd,       global_expanded_toks_code,                0);
        tex_primitive(luatex_command,     no_legacy,       "xtoksapp",                       combine_toks_cmd,       global_append_expanded_toks_code,         0);
        tex_primitive(luatex_command,     no_legacy,       "xtokspre",                       combine_toks_cmd,       global_prepend_expanded_toks_code,        0);

        tex_primitive(luatex_command,     no_legacy,       "begincsname",                    cs_name_cmd,            begin_cs_name_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "csname",                         cs_name_cmd,            cs_name_code,                             0);
        tex_primitive(luatex_command,     no_legacy,       "futurecsname",                   cs_name_cmd,            future_cs_name_code,                      0); /* Okay but rare applications (less tracing). */
        tex_primitive(luatex_command,     no_legacy,       "lastnamedcs",                    cs_name_cmd,            last_named_cs_code,                       0);

        tex_primitive(tex_command,        no_legacy,       "endcsname",                      end_cs_name_cmd,        normal_code,                              0);

        /* set_font_id could use def_font_cmd */

        tex_primitive(tex_command,        callback_legacy, "font",                           define_font_cmd,        normal_code,                              0);

        tex_primitive(tex_command,        math_legacy,     "delimiter",                      delimiter_number_cmd,   math_delimiter_code,                      0);
        tex_primitive(luatex_command,     no_legacy,       "Udelimiter",                     delimiter_number_cmd,   math_udelimiter_code,                     0);

        /*tex We don't combine these because they have different runners and mode handling. */

        tex_primitive(tex_command,        no_legacy,       " ",                              explicit_space_cmd,     normal_code,                              0);
        tex_primitive(luametatex_command, aliased_legacy,  "explicitspace",                  explicit_space_cmd,     normal_code,                              0); /* unexpandable */

        tex_primitive(tex_command,        no_legacy,       "/",                              italic_correction_cmd,  italic_correction_code,                   0);
        tex_primitive(luametatex_command, aliased_legacy,  "explicititaliccorrection",       italic_correction_cmd,  italic_correction_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "forcedleftcorrection",           italic_correction_cmd,  left_correction_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "forcedrightcorrection",          italic_correction_cmd,  right_correction_code,                    0);

        tex_primitive(luametatex_command, no_legacy,       "expand",                         expand_after_cmd,       expand_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "expandactive",                   expand_after_cmd,       expand_active_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "expandafter",                    expand_after_cmd,       expand_after_code,                        0);
     /* tex_primitive(luametatex_command, no_legacy,       "expandafterfi",                  expand_after_cmd,       expand_after_fi_code,                     0); */ /* keep as reference */
        tex_primitive(luametatex_command, no_legacy,       "expandafterpars",                expand_after_cmd,       expand_after_pars_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "expandafterspaces",              expand_after_cmd,       expand_after_spaces_code,                 0);
     /* tex_primitive(luametatex_command, no_legacy,       "expandafterthree",               expand_after_cmd,       expand_after_3_code,                      0); */ /* Yes or no. */
     /* tex_primitive(luametatex_command, no_legacy,       "expandaftertwo",                 expand_after_cmd,       expand_after_2_code,                      0); */ /* Yes or no. */
        tex_primitive(luametatex_command, no_legacy,       "expandcstoken",                  expand_after_cmd,       expand_cs_token_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "expandedafter",                  expand_after_cmd,       expand_after_toks_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "expandparameter",                expand_after_cmd,       expand_parameter_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "expandtoken",                    expand_after_cmd,       expand_token_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "expandtoks",                     expand_after_cmd,       expand_toks_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "futureexpand",                   expand_after_cmd,       future_expand_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "futureexpandis",                 expand_after_cmd,       future_expand_is_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "futureexpandisap",               expand_after_cmd,       future_expand_is_ap_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "semiexpand",                     expand_after_cmd,       expand_semi_code,                         0);
        tex_primitive(etex_command,       no_legacy,       "unless",                         expand_after_cmd,       expand_unless_code,                       0);

        tex_primitive(luatex_command,     no_legacy,       "ignorearguments",                ignore_something_cmd,   ignore_argument_code,                     0);
        tex_primitive(luatex_command,     no_legacy,       "ignorenestedupto",               ignore_something_cmd,   ignore_nested_upto_code,                  0);
        tex_primitive(luatex_command,     no_legacy,       "ignorepars",                     ignore_something_cmd,   ignore_par_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "ignorespaces",                   ignore_something_cmd,   ignore_space_code,                        0);
        tex_primitive(luatex_command,     no_legacy,       "ignoreupto",                     ignore_something_cmd,   ignore_upto_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "ignorerest",                     ignore_something_cmd,   ignore_rest_code,                         0);

        tex_primitive(tex_command,        no_legacy,       "endinput",                       input_cmd,              end_of_input_code,                        0);
        tex_primitive(tex_command,        no_legacy,       "input",                          input_cmd,              normal_input_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "eofinput",                       input_cmd,              eof_input_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "quitloop",                       input_cmd,              quit_loop_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "quitloopnow",                    input_cmd,              quit_loop_now_code,                       0);
     /* tex_primitive(luametatex_command, no_legacy,       "quitfinow",                      input_cmd,              quit_fi_now_code,                         0); */ /*tex only for performance testing */
        tex_primitive(luametatex_command, no_legacy,       "retokenized",                    input_cmd,              retokenized_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "scantextokens",                  input_cmd,              tex_token_input_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "tokenized",                      input_cmd,              tokenized_code,                           0);
        tex_primitive(etex_command,       no_legacy,       "scantokens",                     input_cmd,              token_input_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "ignoretokens",                   input_cmd,              ignore_input_code,                        0);

        tex_primitive(luametatex_command, no_legacy,       "beginmvl",                       mvl_cmd,                begin_mvl_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "endmvl",                         mvl_cmd,                end_mvl_code,                             0);

        tex_primitive(tex_command,        no_legacy,       "insert",                         insert_cmd,             normal_code,                              0);

        tex_primitive(luatex_command,     no_legacy,       "luabytecodecall",                lua_function_call_cmd,  lua_bytecode_call_code,                   0);
        tex_primitive(luatex_command,     no_legacy,       "luafunctioncall",                lua_function_call_cmd,  lua_function_call_code,                   0);

        tex_primitive(luatex_command,     no_legacy,       "clearmarks",                     mark_cmd,               clear_marks_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "flushmarks",                     mark_cmd,               flush_marks_code,                         0);
        tex_primitive(tex_command,        single_legacy,   "mark",                           mark_cmd,               set_mark_code,                            0);
        tex_primitive(etex_command,       no_legacy,       "marks",                          mark_cmd,               set_marks_code,                           0);

        tex_primitive(tex_command,        math_legacy,     "mathaccent",                     math_accent_cmd,        math_accent_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "Umathaccent",                    math_accent_cmd,        math_uaccent_code,                        0);

        tex_primitive(tex_command,        math_legacy,     "mathchar",                       math_char_number_cmd,   math_char_number_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathchar",                      math_char_number_cmd,   math_xchar_number_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "mathclass",                      math_char_number_cmd,   math_class_number_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "mathdictionary",                 math_char_number_cmd,   math_dictionary_number_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "nomathchar",                     math_char_number_cmd,   math_char_ignore_code,                    0);

        tex_primitive(tex_command,        no_legacy,       "mathchoice",                     math_choice_cmd,        math_choice_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "mathdiscretionary",              math_choice_cmd,        math_discretionary_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "mathstack",                      math_choice_cmd,        math_stack_code,                          0);

        tex_primitive(tex_command,        no_legacy,       "noexpand",                       no_expand_cmd,          normal_code,                              0);

        tex_primitive(tex_command,        math_legacy,     "radical",                        math_radical_cmd,       normal_radical_subtype,                   0);
        tex_primitive(luametatex_command, no_legacy,       "Udelimited",                     math_radical_cmd,       delimited_radical_subtype,                0);
        tex_primitive(luatex_command,     no_legacy,       "Udelimiterover",                 math_radical_cmd,       delimiter_over_radical_subtype,           0);
        tex_primitive(luatex_command,     no_legacy,       "Udelimiterunder",                math_radical_cmd,       delimiter_under_radical_subtype,          0);
        tex_primitive(luatex_command,     no_legacy,       "Uhextensible",                   math_radical_cmd,       h_extensible_radical_subtype,             0);
        tex_primitive(luatex_command,     no_legacy,       "Uoverdelimiter",                 math_radical_cmd,       over_delimiter_radical_subtype,           0);
        tex_primitive(luatex_command,     no_legacy,       "Uradical",                       math_radical_cmd,       radical_radical_subtype,                  0);
        tex_primitive(luatex_command,     no_legacy,       "Uroot",                          math_radical_cmd,       root_radical_subtype,                     0);
        tex_primitive(luametatex_command, no_legacy,       "Urooted",                        math_radical_cmd,       rooted_radical_subtype,                   0);
        tex_primitive(luatex_command,     no_legacy,       "Uunderdelimiter",                math_radical_cmd,       under_delimiter_radical_subtype,          0);

        tex_primitive(tex_command,        no_legacy,       "setbox",                         set_box_cmd,            normal_code,                              0);

        /*tex
            Instead of |set_(e)tex_shape_cmd| we use |set_specification_cmd| because since \ETEX\
            it no longer relates to par shapes only. ALso, because there are nodes involved, that
            themselves have a different implementation, it is less confusing.
        */

        tex_primitive(etex_command,       no_legacy,       "clubpenalties",                  specification_cmd,      club_penalties_code,                      internal_specification_base);
        tex_primitive(etex_command,       math_legacy,     "displaywidowpenalties",          specification_cmd,      display_widow_penalties_code,             internal_specification_base);
        tex_primitive(etex_command,       no_legacy,       "interlinepenalties",             specification_cmd,      inter_line_penalties_code,                internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "mathbackwardpenalties",          specification_cmd,      math_backward_penalties_code,             internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "mathforwardpenalties",           specification_cmd,      math_forward_penalties_code,              internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "orphanpenalties",                specification_cmd,      orphan_penalties_code,                    internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "toddlerpenalties",               specification_cmd,      toddler_penalties_code,                   internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "parpasses",                      specification_cmd,      par_passes_code,                          internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "parpassesexception",             specification_cmd,      par_passes_exception_code,                internal_specification_base);
        tex_primitive(tex_command,        no_legacy,       "parshape",                       specification_cmd,      par_shape_code,                           internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "balanceshape",                   specification_cmd,      balance_shape_code,                       internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "balancepasses",                  specification_cmd,      balance_passes_code,                      internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "balancefinalpenalties",          specification_cmd,      balance_final_penalties_code,             internal_specification_base);
        tex_primitive(etex_command,       no_legacy,       "widowpenalties",                 specification_cmd,      widow_penalties_code,                     internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "brokenpenalties",                specification_cmd,      broken_penalties_code,                    internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "fitnessclasses",                 specification_cmd,      fitness_classes_code,                     internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "adjacentdemerits",               specification_cmd,      adjacent_demerits_code,                   internal_specification_base);
        tex_primitive(luametatex_command, no_legacy,       "orphanlinefactors",              specification_cmd,      orphan_line_factors_code,                 internal_specification_base);

        tex_primitive(etex_command,       no_legacy,       "detokenize",                     the_cmd,                detokenize_code,                          0); /* maybe convert_cmd */
        tex_primitive(luametatex_command, no_legacy,       "expandeddetokenize",             the_cmd,                expanded_detokenize_code,                 0); /* maybe convert_cmd */
        tex_primitive(luametatex_command, no_legacy,       "protecteddetokenize",            the_cmd,                protected_detokenize_code,                0); /* maybe convert_cmd */
        tex_primitive(luametatex_command, no_legacy,       "protectedexpandeddetokenize",    the_cmd,                protected_expanded_detokenize_code,       0); /* maybe convert_cmd */
        tex_primitive(tex_command,        no_legacy,       "the",                            the_cmd,                the_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "thewithoutunit",                 the_cmd,                the_without_unit_code,                    0);
     /* tex_primitive(luatex_command,     no_legacy,       "thewithproperty",                the_cmd,                the_with_property_code,                   0); */ /* replaced by value functions */
        tex_primitive(etex_command,       no_legacy,       "unexpanded",                     the_cmd,                unexpanded_code,                          0); /* maybe convert_cmd */
        tex_primitive(luametatex_command, aliased_legacy,  "notexpanded",                    the_cmd,                unexpanded_code,                          0); /* we want it as primitive, we had a pre eTeX \unexpanded aready in context*/

        tex_primitive(tex_command,        single_legacy,   "botmark",                        get_mark_cmd,           bot_mark_code,                            0); /* \botmarks        0 */
        tex_primitive(etex_command,       no_legacy,       "botmarks",                       get_mark_cmd,           bot_marks_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "currentmarks",                   get_mark_cmd,           current_marks_code,                       0);
        tex_primitive(tex_command,        single_legacy,   "firstmark",                      get_mark_cmd,           first_mark_code,                          0); /* \firstmarks      0 */
        tex_primitive(etex_command,       no_legacy,       "firstmarks",                     get_mark_cmd,           first_marks_code,                         0);
        tex_primitive(tex_command,        single_legacy,   "splitbotmark",                   get_mark_cmd,           split_bot_mark_code,                      0); /* \splitbotmarks   0 */
        tex_primitive(etex_command,       no_legacy,       "splitbotmarks",                  get_mark_cmd,           split_bot_marks_code,                     0);
        tex_primitive(tex_command,        single_legacy,   "splitfirstmark",                 get_mark_cmd,           split_first_mark_code,                    0); /* \splitfirstmarks 0 */
        tex_primitive(etex_command,       no_legacy,       "splitfirstmarks",                get_mark_cmd,           split_first_marks_code,                   0);
        tex_primitive(tex_command,        single_legacy,   "topmark",                        get_mark_cmd,           top_mark_code,                            0); /* \topmarks        0 */
        tex_primitive(etex_command,       no_legacy,       "topmarks",                       get_mark_cmd,           top_marks_code,                           0);

        tex_primitive(tex_command,        no_legacy,       "vadjust",                        vadjust_cmd,            normal_code,                              0);

        tex_primitive(tex_command,        no_legacy,       "halign",                         halign_cmd,             normal_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "valign",                         valign_cmd,             normal_code,                              0);

        tex_primitive(tex_command,        no_legacy,       "vcenter",                        vcenter_cmd,            normal_code,                              0);

        /* todo rule codes of nodes, so empty will move */

        tex_primitive(luatex_command,     no_legacy,       "novrule",                        vrule_cmd,              empty_rule_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "srule",                          vrule_cmd,              strut_rule_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "virtualvrule",                   vrule_cmd,              virtual_rule_code,                        0);
        tex_primitive(tex_command,        no_legacy,       "vrule",                          vrule_cmd,              normal_rule_code,                         0);

        tex_primitive(tex_command,        no_legacy,       "hrule",                          hrule_cmd,              normal_rule_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "nohrule",                        hrule_cmd,              empty_rule_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "virtualhrule",                   hrule_cmd,              virtual_rule_code,                        0);

        tex_primitive(luatex_command,     no_legacy,       "attribute",                      register_cmd,           attribute_val_level,                      0);
        tex_primitive(tex_command,        no_legacy,       "count",                          register_cmd,           integer_val_level,                        0);
        tex_primitive(tex_command,        no_legacy,       "dimen",                          register_cmd,           dimension_val_level,                      0);
        tex_primitive(luametatex_command, no_legacy,       "float",                          register_cmd,           posit_val_level,                          0);
        tex_primitive(tex_command,        no_legacy,       "muskip",                         register_cmd,           muglue_val_level,                         0);
        tex_primitive(tex_command,        no_legacy,       "skip",                           register_cmd,           glue_val_level,                           0);
        tex_primitive(tex_command,        no_legacy,       "toks",                           register_cmd,           token_val_level,                          0);

        tex_primitive(luametatex_command, no_legacy,       "insertmode",                     auxiliary_cmd,          insert_mode_code,                         0);
        tex_primitive(etex_command,       no_legacy,       "interactionmode",                auxiliary_cmd,          interaction_mode_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "prevdepth",                      auxiliary_cmd,          prev_depth_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "prevgraf",                       auxiliary_cmd,          prev_graf_code,                           0);
        tex_primitive(tex_command,        no_legacy,       "spacefactor",                    auxiliary_cmd,          space_factor_code,                        0);

        tex_primitive(tex_command,        no_legacy,       "deadcycles",                     page_property_cmd,      dead_cycles_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "insertdepth",                    page_property_cmd,      insert_depth_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "insertdistance",                 page_property_cmd,      insert_distance_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "insertheight",                   page_property_cmd,      insert_height_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "insertheights",                  page_property_cmd,      insert_heights_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "insertlimit",                    page_property_cmd,      insert_limit_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "insertmaxdepth",                 page_property_cmd,      insert_maxdepth_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "insertmultiplier",               page_property_cmd,      insert_multiplier_code,                   0);
        tex_primitive(tex_command,        no_legacy,       "insertpenalties",                page_property_cmd,      insert_penalties_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "insertpenalty",                  page_property_cmd,      insert_penalty_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "insertshrink",                   page_property_cmd,      insert_shrink_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "insertstorage",                  page_property_cmd,      insert_storage_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "insertstoring",                  page_property_cmd,      insert_storing_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "insertstretch",                  page_property_cmd,      insert_stretch_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "insertwidth",                    page_property_cmd,      insert_width_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "insertlineheight",               page_property_cmd,      insert_line_height_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "insertlinedepth",                page_property_cmd,      insert_line_depth_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "insertdirection",                page_property_cmd,      insert_direction_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "pagedepth",                      page_property_cmd,      page_depth_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "pageexcess",                     page_property_cmd,      page_excess_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "pagefilllstretch",               page_property_cmd,      page_filllstretch_code,                   0);
        tex_primitive(tex_command,        no_legacy,       "pagefillstretch",                page_property_cmd,      page_fillstretch_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "pagefilstretch",                 page_property_cmd,      page_filstretch_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "pagefistretch",                  page_property_cmd,      page_fistretch_code,                      0);
        tex_primitive(tex_command,        no_legacy,       "pagegoal",                       page_property_cmd,      page_goal_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastdepth",                  page_property_cmd,      page_last_depth_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastfilllstretch",           page_property_cmd,      page_last_filllstretch_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastfillstretch",            page_property_cmd,      page_last_fillstretch_code,               0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastfilstretch",             page_property_cmd,      page_last_filstretch_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastfistretch",              page_property_cmd,      page_last_fistretch_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastheight",                 page_property_cmd,      page_last_height_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "pagelastshrink",                 page_property_cmd,      page_last_shrink_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "pagelaststretch",                page_property_cmd,      page_last_stretch_code,                   0);
        tex_primitive(tex_command,        no_legacy,       "pageshrink",                     page_property_cmd,      page_shrink_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "pagestretch",                    page_property_cmd,      page_stretch_code,                        0);
        tex_primitive(tex_command,        no_legacy,       "pagetotal",                      page_property_cmd,      page_total_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "pagevsize",                      page_property_cmd,      page_vsize_code,                          0);

        tex_primitive(luametatex_command, no_legacy,       "splitlastdepth",                 page_property_cmd,      split_last_depth_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "splitlastheight",                page_property_cmd,      split_last_height_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "splitlastshrink",                page_property_cmd,      split_last_shrink_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "splitlaststretch",               page_property_cmd,      split_last_stretch_code,                  0);

        tex_primitive(luametatex_command, no_legacy,       "mvlcurrentlyactive",             page_property_cmd,      mvl_currently_active_code,                0);

        tex_primitive(luametatex_command, no_legacy,       "boxadapt",                       box_property_cmd,       box_adapt_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "boxanchor",                      box_property_cmd,       box_anchor_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "boxanchors",                     box_property_cmd,       box_anchors_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxattribute",                   box_property_cmd,       box_attribute_code,                       0);
        tex_primitive(luatex_command,     no_legacy,       "boxdirection",                   box_property_cmd,       box_direction_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "boxfinalize",                    box_property_cmd,       box_finalize_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "boxfreeze",                      box_property_cmd,       box_freeze_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "boxinserts",                     box_property_cmd,       box_inserts_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxmigrate",                     box_property_cmd,       box_migrate_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxgeometry",                    box_property_cmd,       box_geometry_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "boxlimitate",                    box_property_cmd,       box_limitate_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "boxlimit",                       box_property_cmd,       box_limit_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "boxorientation",                 box_property_cmd,       box_orientation_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "boxrepack",                      box_property_cmd,       box_repack_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "boxshift",                       box_property_cmd,       box_shift_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "boxshrink",                      box_property_cmd,       box_shrink_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "boxsubtype",                     box_property_cmd,       box_subtype_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxsource",                      box_property_cmd,       box_source_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "boxstretch",                     box_property_cmd,       box_stretch_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxtarget",                      box_property_cmd,       box_target_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "boxtotal",                       box_property_cmd,       box_total_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "boxvadjust",                     box_property_cmd,       box_vadjust_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxxmove",                       box_property_cmd,       box_xmove_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "boxxoffset",                     box_property_cmd,       box_xoffset_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "boxymove",                       box_property_cmd,       box_ymove_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "boxyoffset",                     box_property_cmd,       box_yoffset_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "dp",                             box_property_cmd,       box_depth_code,                           0);
        tex_primitive(tex_command,        no_legacy,       "ht",                             box_property_cmd,       box_height_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "wd",                             box_property_cmd,       box_width_code,                           0);
     // tex_primitive(luametatex_command, aliased_legacy,  "boxdepth",                       box_property_cmd,       box_depth_code,                           0);
     // tex_primitive(luametatex_command, aliased_legacy,  "boxheight",                      box_property_cmd,       box_height_code,                          0);
     // tex_primitive(luametatex_command, aliased_legacy,  "boxwidth",                       box_property_cmd,       box_width_code,                           0);

        tex_primitive(tex_command,        no_legacy,       "badness",                        some_item_cmd,          badness_code,                             0);
        tex_primitive(etex_command,       no_legacy,       "currentgrouplevel",              some_item_cmd,          current_group_level_code,                 0);
        tex_primitive(etex_command,       no_legacy,       "currentgrouptype",               some_item_cmd,          current_group_type_code,                  0);
        tex_primitive(etex_command,       no_legacy,       "currentifbranch",                some_item_cmd,          current_if_branch_code,                   0);
        tex_primitive(etex_command,       no_legacy,       "currentiflevel",                 some_item_cmd,          current_if_level_code,                    0);
        tex_primitive(etex_command,       no_legacy,       "currentiftype",                  some_item_cmd,          current_if_type_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "currentloopiterator",            some_item_cmd,          current_loop_iterator_code,               0);
        tex_primitive(luametatex_command, no_legacy,       "currentloopnesting",             some_item_cmd,          current_loop_nesting_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "currentstacksize",               some_item_cmd,          current_stack_size_code,                  0);
     // tex_primitive(luatex_command,     no_legacy,       "dimentoscale",                   some_item_cmd,          dimen_to_scale_code,                      0);
        tex_primitive(etex_command,       no_legacy,       "dimexpr",                        some_item_cmd,          dimexpr_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "dimexpression",                  some_item_cmd,          dimexpression_code,                       0); /* experiment */
        tex_primitive(luametatex_command, no_legacy,       "dimexperimental",                some_item_cmd,          dimexperimental_code,                     0); /* experiment */
        tex_primitive(luametatex_command, no_legacy,       "floatexpr",                      some_item_cmd,          posexpr_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "fontcharba",                     some_item_cmd,          font_char_ba_code,                        0);
        tex_primitive(etex_command,       no_legacy,       "fontchardp",                     some_item_cmd,          font_char_dp_code,                        0);
        tex_primitive(etex_command,       no_legacy,       "fontcharht",                     some_item_cmd,          font_char_ht_code,                        0);
        tex_primitive(etex_command,       no_legacy,       "fontcharic",                     some_item_cmd,          font_char_ic_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "fontcharta",                     some_item_cmd,          font_char_ta_code,                        0);
        tex_primitive(etex_command,       no_legacy,       "fontcharwd",                     some_item_cmd,          font_char_wd_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontcharba",               some_item_cmd,          scaled_font_char_ba_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontchardp",               some_item_cmd,          scaled_font_char_dp_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontcharht",               some_item_cmd,          scaled_font_char_ht_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontcharic",               some_item_cmd,          scaled_font_char_ic_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontcharta",               some_item_cmd,          scaled_font_char_ta_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontcharwd",               some_item_cmd,          scaled_font_char_wd_code,                 0);
        tex_primitive(luatex_command,     no_legacy,       "fontid",                         some_item_cmd,          font_id_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "fontmathcontrol",                some_item_cmd,          font_math_control_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecid",                     some_item_cmd,          font_spec_id_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecifiedsize",              some_item_cmd,          font_size_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecscale",                  some_item_cmd,          font_spec_scale_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecxscale",                 some_item_cmd,          font_spec_xscale_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecyscale",                 some_item_cmd,          font_spec_yscale_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecslant",                  some_item_cmd,          font_spec_slant_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecweight",                 some_item_cmd,          font_spec_weight_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "fonttextcontrol",                some_item_cmd,          font_text_control_code,                   0);
        tex_primitive(etex_command,       no_legacy,       "glueexpr",                       some_item_cmd,          glueexpr_code,                            0);
        tex_primitive(etex_command,       no_legacy,       "glueshrink",                     some_item_cmd,          glue_shrink_code,                         0);
        tex_primitive(etex_command,       no_legacy,       "glueshrinkorder",                some_item_cmd,          glue_shrink_order_code,                   0);
        tex_primitive(etex_command,       no_legacy,       "gluestretch",                    some_item_cmd,          glue_stretch_code,                        0);
        tex_primitive(etex_command,       no_legacy,       "gluestretchorder",               some_item_cmd,          glue_stretch_order_code,                  0);
        tex_primitive(etex_command,       no_legacy,       "gluetomu",                       some_item_cmd,          glue_to_mu_code,                          0);
        tex_primitive(luatex_command,     no_legacy,       "glyphxscaled",                   some_item_cmd,          glyph_x_scaled_code,                      0);
        tex_primitive(luatex_command,     no_legacy,       "glyphyscaled",                   some_item_cmd,          glyph_y_scaled_code,                      0);
        tex_primitive(luatex_command,     no_legacy,       "indexofcharacter",               some_item_cmd,          index_of_character_code,                  0);
        tex_primitive(luatex_command,     no_legacy,       "indexofregister",                some_item_cmd,          index_of_register_code,                   0);
        tex_primitive(tex_command,        no_legacy,       "inputlineno",                    some_item_cmd,          input_line_no_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "insertprogress",                 some_item_cmd,          insert_progress_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "lastarguments",                  some_item_cmd,          last_arguments_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "lastatomclass",                  some_item_cmd,          last_atom_class_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "lastboundary",                   some_item_cmd,          lastboundary_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "lastchkdimension",               some_item_cmd,          last_chk_dimension_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "lastchknumber",                  some_item_cmd,          last_chk_integer_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "lastkern",                       some_item_cmd,          lastkern_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "lastleftclass",                  some_item_cmd,          last_left_class_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "lastloopiterator",               some_item_cmd,          last_loop_iterator_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "lastnodesubtype",                some_item_cmd,          last_node_subtype_code,                   0);
        tex_primitive(etex_command,       no_legacy,       "lastnodetype",                   some_item_cmd,          last_node_type_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "lastpageextra",                  some_item_cmd,          last_page_extra_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "lastlinewidth",                  some_item_cmd,          last_line_width_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "lastlinecount",                  some_item_cmd,          last_line_count_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "lastpartrigger",                 some_item_cmd,          last_par_trigger_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "lastparcontext",                 some_item_cmd,          last_par_context_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "lastpenalty",                    some_item_cmd,          lastpenalty_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "lastrightclass",                 some_item_cmd,          last_right_class_code,                    0);
        tex_primitive(tex_command,        no_legacy,       "lastskip",                       some_item_cmd,          lastskip_code,                            0);
        tex_primitive(luatex_command,     no_legacy,       "leftmarginkern",                 some_item_cmd,          left_margin_kern_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "luametatexmajorversion",         some_item_cmd,          luametatex_major_version_code,            0);
        tex_primitive(luametatex_command, no_legacy,       "luametatexminorversion",         some_item_cmd,          luametatex_minor_version_code,            0);
        tex_primitive(luametatex_command, no_legacy,       "luametatexrelease",              some_item_cmd,          luametatex_release_code,                  0);
        tex_primitive(luatex_command,     no_legacy,       "luatexrevision",                 some_item_cmd,          luatex_revision_code,                     0);
        tex_primitive(luatex_command,     no_legacy,       "luatexversion",                  some_item_cmd,          luatex_version_code,                      0);
     /* tex_primitive(luametatex_command, no_legacy,       "luavaluefunction",               some_item_cmd,          lua_value_function_code,                  0); */
        tex_primitive(luametatex_command, no_legacy,       "mathatomglue",                   some_item_cmd,          math_atom_glue_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "mathmainstyle",                  some_item_cmd,          math_main_style_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "mathparentstyle",                some_item_cmd,          math_parent_style_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "mathscale",                      some_item_cmd,          math_scale_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "mathstackstyle",                 some_item_cmd,          math_stack_style_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "mathstyle",                      some_item_cmd,          math_style_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "mathstylefontid",                some_item_cmd,          math_style_font_id_code,                  0);
        tex_primitive(etex_command,       no_legacy,       "muexpr",                         some_item_cmd,          muexpr_code,                              0);
        tex_primitive(etex_command,       no_legacy,       "mutoglue",                       some_item_cmd,          mu_to_glue_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "nestedloopiterator",             some_item_cmd,          nested_loop_iterator_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "numericscale",                   some_item_cmd,          numeric_scale_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "numericscaled",                  some_item_cmd,          numeric_scaled_code,                      0);
        tex_primitive(etex_command,       no_legacy,       "numexpr",                        some_item_cmd,          numexpr_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "numexpression",                  some_item_cmd,          numexpression_code,                       0); /* experiment */
        tex_primitive(luametatex_command, no_legacy,       "numexperimental",                some_item_cmd,          numexperimental_code,                     0); /* experiment */
        tex_primitive(luametatex_command, no_legacy,       "overshoot",                      some_item_cmd,          overshoot_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "parametercount",                 some_item_cmd,          parameter_count_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "parameterindex",                 some_item_cmd,          parameter_index_code,                     0);
        tex_primitive(etex_command,       no_legacy,       "parshapedimen",                  some_item_cmd,          par_shape_width_code,                     0); /* bad name */
        tex_primitive(etex_command,       no_legacy,       "parshapeindent",                 some_item_cmd,          par_shape_indent_code,                    0);
        tex_primitive(etex_command,       no_legacy,       "parshapelength",                 some_item_cmd,          par_shape_length_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "parshapewidth",                  some_item_cmd,          par_shape_width_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "balanceshapevsize",              some_item_cmd,          balance_shape_vsize_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "balanceshapetopspace",           some_item_cmd,          balance_shape_top_space_code,             0);
        tex_primitive(luametatex_command, no_legacy,       "balanceshapebottomspace",        some_item_cmd,          balance_shape_bottom_space_code,          0);
        tex_primitive(luametatex_command, no_legacy,       "previousloopiterator",           some_item_cmd,          previous_loop_iterator_code,              0);
        tex_primitive(luatex_command,     no_legacy,       "rightmarginkern",                some_item_cmd,          right_margin_kern_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "scaledemwidth",                  some_item_cmd,          scaled_em_width_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "scaledexheight",                 some_item_cmd,          scaled_ex_height_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "scaledextraspace",               some_item_cmd,          scaled_extra_space_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "scaledinterwordshrink",          some_item_cmd,          scaled_interword_shrink_code,             0);
        tex_primitive(luametatex_command, no_legacy,       "scaledinterwordspace",           some_item_cmd,          scaled_interword_space_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "scaledinterwordstretch",         some_item_cmd,          scaled_interword_stretch_code,            0);
        tex_primitive(luametatex_command, no_legacy,       "scaledslantperpoint",            some_item_cmd,          scaled_slant_per_point_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "scaledmathaxis",                 some_item_cmd,          scaled_math_axis_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "scaledmathexheight",             some_item_cmd,          scaled_math_ex_height_code,               0);
        tex_primitive(luametatex_command, no_legacy,       "scaledmathemwidth",              some_item_cmd,          scaled_math_em_width_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "mathcharclass",                  some_item_cmd,          math_char_class_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "mathcharfam",                    some_item_cmd,          math_char_fam_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "mathcharslot",                   some_item_cmd,          math_char_slot_code,                      0);

        tex_primitive(luametatex_command, no_legacy,       "csactive",                       convert_cmd,            cs_active_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "csnamestring",                   convert_cmd,            cs_lastname_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "csstring",                       convert_cmd,            cs_string_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "detokened",                      convert_cmd,            detokened_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "detokenized",                    convert_cmd,            detokenized_code,                         0);
        tex_primitive(luatex_command,     no_legacy,       "directlua",                      convert_cmd,            lua_code,                                 0);
        tex_primitive(luatex_command,     no_legacy,       "expanded",                       convert_cmd,            expanded_code,                            0);
     /* tex_primitive(luametatex_command, no_legacy,       "expandedaftercs",                convert_cmd,            expanded_after_cs_code,                   0); */ /* no gain as we need {{#1}} then */
        tex_primitive(tex_command,        no_legacy,       "fontname",                       convert_cmd,            font_name_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "fontidentifier",                 convert_cmd,            font_identifier_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecifiedname",              convert_cmd,            font_specification_code,                  0);
        tex_primitive(luatex_command,     no_legacy,       "formatname",                     convert_cmd,            format_name_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "jobname",                        convert_cmd,            job_name_code,                            0);
        tex_primitive(luatex_command,     no_legacy,       "luabytecode",                    convert_cmd,            lua_bytecode_code,                        0);
        tex_primitive(luatex_command,     no_legacy,       "luaescapestring",                convert_cmd,            lua_escape_string_code,                   0);
        tex_primitive(luatex_command,     no_legacy,       "luafunction",                    convert_cmd,            lua_function_code,                        0);
        tex_primitive(luatex_command,     no_legacy,       "luatexbanner",                   convert_cmd,            luatex_banner_code,                       0);
     /* tex_primitive(luametatex_command, no_legacy,       "luatokenstring",                 convert_cmd,            lua_token_string_code,                    0); */
        tex_primitive(tex_command,        no_legacy,       "meaning",                        convert_cmd,            meaning_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "meaningasis",                    convert_cmd,            meaning_asis_code,                        0); /* for manuals and articles */
        tex_primitive(luametatex_command, no_legacy,       "meaningful",                     convert_cmd,            meaning_ful_code,                         0); /* full as in fil */
        tex_primitive(luametatex_command, no_legacy,       "meaningfull",                    convert_cmd,            meaning_full_code,                        0); /* full as in fill, maybe some day meaninfulll  */
        tex_primitive(luametatex_command, no_legacy,       "meaningles",                     convert_cmd,            meaning_les_code,                         0); /* less as in fil, can't be less than this */
        tex_primitive(luametatex_command, no_legacy,       "meaningless",                    convert_cmd,            meaning_less_code,                        0); /* less as in fill */
        tex_primitive(tex_command,        no_legacy,       "number",                         convert_cmd,            number_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "romannumeral",                   convert_cmd,            roman_numeral_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "semiexpanded",                   convert_cmd,            semi_expanded_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "string",                         convert_cmd,            string_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "todimension",                    convert_cmd,            to_dimension_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "tohexadecimal",                  convert_cmd,            to_hexadecimal_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "tointeger",                      convert_cmd,            to_integer_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "tomathstyle",                    convert_cmd,            to_mathstyle_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "toscaled",                       convert_cmd,            to_scaled_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "tosparsedimension",              convert_cmd,            to_sparse_dimension_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "tosparsescaled",                 convert_cmd,            to_sparse_scaled_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "tolimitedfloat",                 convert_cmd,            to_limited_float_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "tocharacter",                    convert_cmd,            to_character_code,                        0);

        tex_primitive(tex_command,        no_legacy,       "else",                           if_test_cmd,            else_code,                                0);
        tex_primitive(tex_command,        no_legacy,       "fi",                             if_test_cmd,            fi_code,                                  0);
        tex_primitive(no_command,         no_legacy,       "inif",                           if_test_cmd,            if_code,                                  0);
        tex_primitive(no_command,         no_legacy,       "noif",                           if_test_cmd,            no_if_code,                               0);
        tex_primitive(tex_command,        no_legacy,       "or",                             if_test_cmd,            or_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "orelse",                         if_test_cmd,            or_else_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "orunless",                       if_test_cmd,            or_unless_code,                           0);

        tex_primitive(tex_command,        no_legacy,       "if",                             if_test_cmd,            if_char_code,                             0);
        tex_primitive(luatex_command,     no_legacy,       "ifabsdim",                       if_test_cmd,            if_abs_dim_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifabsfloat",                     if_test_cmd,            if_abs_posit_code,                        0);
        tex_primitive(luatex_command,     no_legacy,       "ifabsnum",                       if_test_cmd,            if_abs_int_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifarguments",                    if_test_cmd,            if_arguments_code,                        0);
     /* tex_primitive(luametatex_command, no_legacy,       "ifbitwiseand",                   if_test_cmd,            if_bitwise_and_code,                      0); */
        tex_primitive(luametatex_command, no_legacy,       "ifboolean",                      if_test_cmd,            if_boolean_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "ifcase",                         if_test_cmd,            if_case_code,                             0);
        tex_primitive(tex_command,        no_legacy,       "ifcat",                          if_test_cmd,            if_cat_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "ifchkdim",                       if_test_cmd,            if_chk_dim_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifchkdimension",                 if_test_cmd,            if_chk_dimension_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "ifchkdimexpr",                   if_test_cmd,            if_chk_dimexpr_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "ifchknum",                       if_test_cmd,            if_chk_int_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifchknumber",                    if_test_cmd,            if_chk_integer_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "ifchknumexpr",                   if_test_cmd,            if_chk_intexpr_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifcmpdim",                       if_test_cmd,            if_cmp_dim_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifcmpnum",                       if_test_cmd,            if_cmp_int_code,                          0);
        tex_primitive(luatex_command,     no_legacy,       "ifcondition",                    if_test_cmd,            if_condition_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "ifcramped",                      if_test_cmd,            if_cramped_code,                          0);
        tex_primitive(etex_command,       no_legacy,       "ifcsname",                       if_test_cmd,            if_csname_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "ifcstok",                        if_test_cmd,            if_cstok_code,                            0);
        tex_primitive(etex_command,       no_legacy,       "ifdefined",                      if_test_cmd,            if_defined_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "ifdim",                          if_test_cmd,            if_dim_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "ifdimexpression",                if_test_cmd,            if_dimexpression_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "ifdimval",                       if_test_cmd,            if_val_dim_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifempty",                        if_test_cmd,            if_empty_code,                            0);
        tex_primitive(tex_command,        no_legacy,       "iffalse",                        if_test_cmd,            if_false_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "ifflags",                        if_test_cmd,            if_flags_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "iffloat",                        if_test_cmd,            if_posit_code,                            0);
        tex_primitive(etex_command,       no_legacy,       "iffontchar",                     if_test_cmd,            if_font_char_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "ifhaschar",                      if_test_cmd,            if_has_char_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "ifhastok",                       if_test_cmd,            if_has_tok_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "ifhastoks",                      if_test_cmd,            if_has_toks_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "ifhasxtoks",                     if_test_cmd,            if_has_xtoks_code,                        0);
        tex_primitive(tex_command,        no_legacy,       "ifhbox",                         if_test_cmd,            if_hbox_code,                             0);
        tex_primitive(tex_command,        no_legacy,       "ifhmode",                        if_test_cmd,            if_hmode_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "ifinalignment",                  if_test_cmd,            if_in_alignment_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "ifincsname",                     if_test_cmd,            if_in_csname_code,                        0); /* This is obsolete and might be dropped. */
        tex_primitive(tex_command,        no_legacy,       "ifinner",                        if_test_cmd,            if_inner_code,                            0);
        tex_primitive(luatex_command,     no_legacy,       "ifinsert",                       if_test_cmd,            if_insert_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "ifintervaldim",                  if_test_cmd,            if_interval_dim_code,                     0); /* playground */
        tex_primitive(luametatex_command, no_legacy,       "ifintervalfloat",                if_test_cmd,            if_interval_posit_code,                   0); /* playground */
        tex_primitive(luametatex_command, no_legacy,       "ifintervalnum",                  if_test_cmd,            if_interval_int_code,                     0); /* playground */
        tex_primitive(luametatex_command, no_legacy,       "iflastnamedcs",                  if_test_cmd,            if_last_named_cs_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "iflist",                         if_test_cmd,            if_list_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "ifmathparameter",                if_test_cmd,            if_math_parameter_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "ifmathstyle",                    if_test_cmd,            if_math_style_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "ifmmode",                        if_test_cmd,            if_mmode_code,                            0);
        tex_primitive(tex_command,        no_legacy,       "ifnum",                          if_test_cmd,            if_int_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "ifnumexpression",                if_test_cmd,            if_numexpression_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "ifnumval",                       if_test_cmd,            if_val_int_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "ifodd",                          if_test_cmd,            if_odd_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "ifparameter",                    if_test_cmd,            if_parameter_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "ifparameters",                   if_test_cmd,            if_parameters_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "ifrelax",                        if_test_cmd,            if_relax_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "iftok",                          if_test_cmd,            if_tok_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "iftrue",                         if_test_cmd,            if_true_code,                             0);
        tex_primitive(tex_command,        no_legacy,       "ifvbox",                         if_test_cmd,            if_vbox_code,                             0);
        tex_primitive(tex_command,        no_legacy,       "ifvmode",                        if_test_cmd,            if_vmode_code,                            0);
        tex_primitive(tex_command,        no_legacy,       "ifvoid",                         if_test_cmd,            if_void_code,                             0);
        tex_primitive(tex_command,        no_legacy,       "ifx",                            if_test_cmd,            if_x_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "ifzerodim",                      if_test_cmd,            if_zero_dim_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "ifzerofloat",                    if_test_cmd,            if_zero_posit_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "ifzeronum",                      if_test_cmd,            if_zero_int_code,                         0);

        tex_primitive(tex_command,        math_legacy,     "above",                          math_fraction_cmd,      math_above_code,                          0);
        tex_primitive(tex_command,        math_legacy,     "abovewithdelims",                math_fraction_cmd,      math_above_delimited_code,                0);
        tex_primitive(tex_command,        math_legacy,     "atop",                           math_fraction_cmd,      math_atop_code,                           0);
        tex_primitive(tex_command,        math_legacy,     "atopwithdelims",                 math_fraction_cmd,      math_atop_delimited_code,                 0);
        tex_primitive(tex_command,        math_legacy,     "over",                           math_fraction_cmd,      math_over_code,                           0);
        tex_primitive(tex_command,        math_legacy,     "overwithdelims",                 math_fraction_cmd,      math_over_delimited_code,                 0);

        tex_primitive(luametatex_command, no_legacy,       "Uabove",                         math_fraction_cmd,      math_u_above_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "Uabovewithdelims",               math_fraction_cmd,      math_u_above_delimited_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "Uatop",                          math_fraction_cmd,      math_u_atop_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "Uatopwithdelims",                math_fraction_cmd,      math_u_atop_delimited_code,               0);
        tex_primitive(luametatex_command, no_legacy,       "Uover",                          math_fraction_cmd,      math_u_over_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "Uoverwithdelims",                math_fraction_cmd,      math_u_over_delimited_code,               0);
        tex_primitive(luatex_command,     no_legacy,       "Uskewed",                        math_fraction_cmd,      math_u_skewed_code,                       0);
        tex_primitive(luatex_command,     no_legacy,       "Uskewedwithdelims",              math_fraction_cmd,      math_u_skewed_delimited_code,             0);
        tex_primitive(luametatex_command, no_legacy,       "Ustretched",                     math_fraction_cmd,      math_u_stretched_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "Ustretchedwithdelims",           math_fraction_cmd,      math_u_stretched_delimited_code,          0);

        tex_primitive(luametatex_command, no_legacy,       "cfcode",                         font_property_cmd,      font_cf_code,                             0); /* obsolete */
        tex_primitive(luatex_command,     no_legacy,       "efcode",                         font_property_cmd,      font_ef_code,                             0); /* obsolete */
        tex_primitive(tex_command,        no_legacy,       "fontdimen",                      font_property_cmd,      font_dimension_code,                      0);
        tex_primitive(tex_command,        no_legacy,       "hyphenchar",                     font_property_cmd,      font_hyphen_code,                         0);         
        tex_primitive(luatex_command,     no_legacy,       "lpcode",                         font_property_cmd,      font_lp_code,                             0); /* obsolete */         
        tex_primitive(luatex_command,     no_legacy,       "rpcode",                         font_property_cmd,      font_rp_code,                             0); /* obsolete */         
        tex_primitive(luametatex_command, no_legacy,       "scaledfontdimen",                font_property_cmd,      scaled_font_dimension_code,               0);         
        tex_primitive(tex_command,        math_legacy,     "skewchar",                       font_property_cmd,      font_skew_code,                           0);         
        tex_primitive(luametatex_command, no_legacy,       "scaledfontslantperpoint",        font_property_cmd,      scaled_font_slant_per_point_code,         0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontinterwordspace",       font_property_cmd,      scaled_font_interword_space_code,         0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontinterwordstretch",     font_property_cmd,      scaled_font_interword_stretch_code,       0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontinterwordshrink",      font_property_cmd,      scaled_font_interword_shrink_code,        0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontexheight",             font_property_cmd,      scaled_font_ex_height_code,               0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontemwidth",              font_property_cmd,      scaled_font_em_width_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "scaledfontextraspace",           font_property_cmd,      scaled_font_extra_space_code,             0);

        tex_primitive(tex_command,        no_legacy,       "lowercase",                      case_shift_cmd,         lower_case_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "uppercase",                      case_shift_cmd,         upper_case_code,                          0);

        tex_primitive(luametatex_command, no_legacy,       "amcode",                         define_char_code_cmd,   amcode_charcode,                          0);
        tex_primitive(tex_command,        no_legacy,       "catcode",                        define_char_code_cmd,   catcode_charcode,                         0);
        tex_primitive(luametatex_command, no_legacy,       "cccode",                         define_char_code_cmd,   cccode_charcode,                          0);
        tex_primitive(tex_command,        math_legacy,     "delcode",                        define_char_code_cmd,   delcode_charcode,                         0);
        tex_primitive(luatex_command,     no_legacy,       "hccode",                         define_char_code_cmd,   hccode_charcode,                          0);
        tex_primitive(luatex_command,     no_legacy,       "hmcode",                         define_char_code_cmd,   hmcode_charcode,                          0);
        tex_primitive(tex_command,        no_legacy,       "lccode",                         define_char_code_cmd,   lccode_charcode,                          0);
        tex_primitive(tex_command,        math_legacy,     "mathcode",                       define_char_code_cmd,   mathcode_charcode,                        0);
        tex_primitive(tex_command,        no_legacy,       "sfcode",                         define_char_code_cmd,   sfcode_charcode,                          0);
        tex_primitive(tex_command,        no_legacy,       "uccode",                         define_char_code_cmd,   uccode_charcode,                          0);

        tex_primitive(luatex_command,     no_legacy,       "Udelcode",                       define_char_code_cmd,   extdelcode_charcode,                      0);
        tex_primitive(luatex_command,     no_legacy,       "Umathcode",                      define_char_code_cmd,   extmathcode_charcode,                     0);

        tex_primitive(luametatex_command, no_legacy,       "cdef",                           def_cmd,                constant_def_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "cdefcsname",                     def_cmd,                constant_def_csname_code,                 0);
        tex_primitive(tex_command,        no_legacy,       "def",                            def_cmd,                def_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "defcsname",                      def_cmd,                def_csname_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "edef",                           def_cmd,                expanded_def_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "edefcsname",                     def_cmd,                expanded_def_csname_code,                 0);
        tex_primitive(tex_command,        no_legacy,       "gdef",                           def_cmd,                global_def_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "gdefcsname",                     def_cmd,                global_def_csname_code,                   0);
        tex_primitive(tex_command,        no_legacy,       "xdef",                           def_cmd,                global_expanded_def_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "xdefcsname",                     def_cmd,                global_expanded_def_csname_code,          0);

        tex_primitive(tex_command,        no_legacy,       "scriptfont",                     define_family_cmd,      script_size,                              0);
        tex_primitive(tex_command,        no_legacy,       "scriptscriptfont",               define_family_cmd,      script_script_size,                       0);
        tex_primitive(tex_command,        no_legacy,       "textfont",                       define_family_cmd,      text_size,                                0);

        tex_primitive(tex_command,        no_legacy,       "-",                              discretionary_cmd,      explicit_discretionary_code,              0);
        tex_primitive(luatex_command,     no_legacy,       "automaticdiscretionary",         discretionary_cmd,      automatic_discretionary_code,             0);
        tex_primitive(tex_command,        no_legacy,       "discretionary",                  discretionary_cmd,      normal_discretionary_code,                0);
        tex_primitive(luatex_command,     aliased_legacy,  "explicitdiscretionary",          discretionary_cmd,      explicit_discretionary_code,              0);

        tex_primitive(tex_command,        display_legacy,  "eqno",                           equation_number_cmd,    right_location_code,                      0);
        tex_primitive(tex_command,        display_legacy,  "leqno",                          equation_number_cmd,    left_location_code,                       0);

        tex_primitive(tex_command,        no_legacy,       "moveleft",                       hmove_cmd,              move_backward_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "moveright",                      hmove_cmd,              move_forward_code,                        0);

        tex_primitive(tex_command,        no_legacy,       "hfil",                           hskip_cmd,              fi_l_code,                                0);
        tex_primitive(tex_command,        no_legacy,       "hfill",                          hskip_cmd,              fi_ll_code,                               0);
        tex_primitive(tex_command,        no_legacy,       "hfilneg",                        hskip_cmd,              fi_l_neg_code,                            0);
        tex_primitive(tex_command,        no_legacy,       "hskip",                          hskip_cmd,              skip_code,                                0);
        tex_primitive(tex_command,        no_legacy,       "hss",                            hskip_cmd,              fi_ss_code,                               0);

        tex_primitive(luatex_command,     no_legacy,       "hjcode",                         hyphenation_cmd,        hjcode_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "hyphenation",                    hyphenation_cmd,        hyphenation_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "hyphenationmin",                 hyphenation_cmd,        hyphenationmin_code,                      0);
        tex_primitive(tex_command,        no_legacy,       "patterns",                       hyphenation_cmd,        patterns_code,                            0);
        tex_primitive(luatex_command,     no_legacy,       "postexhyphenchar",               hyphenation_cmd,        postexhyphenchar_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "posthyphenchar",                 hyphenation_cmd,        posthyphenchar_code,                      0);
        tex_primitive(luatex_command,     no_legacy,       "preexhyphenchar",                hyphenation_cmd,        preexhyphenchar_code,                     0);
        tex_primitive(luatex_command,     no_legacy,       "prehyphenchar",                  hyphenation_cmd,        prehyphenchar_code,                       0);

        tex_primitive(tex_command,        no_legacy,       "hkern",                          kern_cmd,               h_kern_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "kern",                           kern_cmd,               normal_kern_code,                         0);
     /* tex_primitive(luametatex_command, no_legacy,       "nonzerowidthkern",               kern_cmd,               non_zero_width_kern_code,                 0); */ /* maybe */
        tex_primitive(tex_command,        no_legacy,       "vkern",                          kern_cmd,               v_kern_code,                              0);

        tex_primitive(luatex_command,     no_legacy,       "localleftbox",                   local_box_cmd,          local_left_box_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "localmiddlebox",                 local_box_cmd,          local_middle_box_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "localrightbox",                  local_box_cmd,          local_right_box_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "resetlocalboxes",                local_box_cmd,          local_reset_boxes_code,                   0);

        tex_primitive(tex_command,        callback_legacy, "shipout",                        legacy_cmd,             shipout_code,                             0);

        tex_primitive(tex_command,        no_legacy,       "cleaders",                       leader_cmd,             c_leaders_code,                           0);
        tex_primitive(luatex_command,     no_legacy,       "gleaders",                       leader_cmd,             g_leaders_code,                           0);
        tex_primitive(tex_command,        no_legacy,       "leaders",                        leader_cmd,             a_leaders_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "uleaders",                       leader_cmd,             u_leaders_code,                           0);
        tex_primitive(tex_command,        no_legacy,       "xleaders",                       leader_cmd,             x_leaders_code,                           0);

        tex_primitive(tex_command,        math_legacy,     "left",                           math_fence_cmd,         left_fence_side,                          0);
        tex_primitive(tex_command,        math_legacy,     "middle",                         math_fence_cmd,         middle_fence_side,                        0);
        tex_primitive(tex_command,        math_legacy,     "right",                          math_fence_cmd,         right_fence_side,                         0);
        tex_primitive(luametatex_command, no_legacy,       "Uleft",                          math_fence_cmd,         extended_left_fence_side,                 0);
        tex_primitive(luametatex_command, no_legacy,       "Umiddle",                        math_fence_cmd,         extended_middle_fence_side,               0);
        tex_primitive(luametatex_command, no_legacy,       "Uoperator",                      math_fence_cmd,         left_operator_side,                       0);
        tex_primitive(luametatex_command, no_legacy,       "Uright",                         math_fence_cmd,         extended_right_fence_side,                0);
        tex_primitive(luatex_command,     no_legacy,       "Uvextensible",                   math_fence_cmd,         no_fence_side,                            0);

        tex_primitive(luametatex_command, no_legacy,       "futuredef",                      let_cmd,                future_def_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "futurelet",                      let_cmd,                future_let_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "glet",                           let_cmd,                global_let_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "gletcsname",                     let_cmd,                global_let_csname_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "glettonothing",                  let_cmd,                global_let_to_nothing_code,               0); /* more a def but a let is nicer */
        tex_primitive(tex_command,        no_legacy,       "let",                            let_cmd,                let_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "letcharcode",                    let_cmd,                let_charcode_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "letcsname",                      let_cmd,                let_csname_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "letfrozen",                      let_cmd,                let_frozen_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "letprotected",                   let_cmd,                let_protected_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "lettolastnamedcs",               let_cmd,                let_to_last_named_cs_code,                0); /* more intuitive than using an edef */
        tex_primitive(luametatex_command, no_legacy,       "lettonothing",                   let_cmd,                let_to_nothing_code,                      0); /* more a def but a let is nicer */
        tex_primitive(luametatex_command, no_legacy,       "swapcsvalues",                   let_cmd,                swap_cs_values_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "unletfrozen",                    let_cmd,                unlet_frozen_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "unletprotected",                 let_cmd,                unlet_protected_code,                     0);

        tex_primitive(tex_command,        no_legacy,       "displaylimits",                  math_modifier_cmd,      display_limits_modifier_code,             0);
        tex_primitive(tex_command,        no_legacy,       "limits",                         math_modifier_cmd,      limits_modifier_code,                     0);
        tex_primitive(tex_command,        no_legacy,       "nolimits",                       math_modifier_cmd,      no_limits_modifier_code,                  0);

        /* beware, Umathaxis is overloaded ... maybe only a generic modifier with keywords */

        tex_primitive(luametatex_command, no_legacy,       "Umathadapttoleft",               math_modifier_cmd,      adapt_to_left_modifier_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathadapttoright",              math_modifier_cmd,      adapt_to_right_modifier_code,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathlimits",                    math_modifier_cmd,      limits_modifier_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "Umathnoaxis",                    math_modifier_cmd,      no_axis_modifier_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "Umathnolimits",                  math_modifier_cmd,      no_limits_modifier_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "Umathopenupdepth",               math_modifier_cmd,      openup_depth_modifier_code,               0);
        tex_primitive(luametatex_command, no_legacy,       "Umathopenupheight",              math_modifier_cmd,      openup_height_modifier_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathphantom",                   math_modifier_cmd,      phantom_modifier_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "Umathsource",                    math_modifier_cmd,      source_modifier_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "Umathuseaxis",                   math_modifier_cmd,      axis_modifier_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "Umathvoid",                      math_modifier_cmd,      void_modifier_code,                       0);

        tex_primitive(tex_command,        no_legacy,       "box",                            make_box_cmd,           box_code,                                 0);
        tex_primitive(tex_command,        no_legacy,       "copy",                           make_box_cmd,           copy_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "dbox",                           make_box_cmd,           dbox_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "dpack",                          make_box_cmd,           dpack_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "dsplit",                         make_box_cmd,           dsplit_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "hbox",                           make_box_cmd,           hbox_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "hpack",                          make_box_cmd,           hpack_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "insertbox",                      make_box_cmd,           insert_box_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "insertcopy",                     make_box_cmd,           insert_copy_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "lastbox",                        make_box_cmd,           last_box_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "localleftboxbox",                make_box_cmd,           local_left_box_box_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "localmiddleboxbox",              make_box_cmd,           local_middle_box_box_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "localrightboxbox",               make_box_cmd,           local_right_box_box_code,                 0);
        tex_primitive(luametatex_command, no_legacy,       "tpack",                          make_box_cmd,           tpack_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "tsplit",                         make_box_cmd,           tsplit_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "vbox",                           make_box_cmd,           vbox_code,                                0);
        tex_primitive(luatex_command,     no_legacy,       "vpack",                          make_box_cmd,           vpack_code,                               0);
        tex_primitive(tex_command,        no_legacy,       "vsplit",                         make_box_cmd,           vsplit_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "vtop",                           make_box_cmd,           vtop_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "vbalance",                       make_box_cmd,           vbalance_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "vbalancedbox",                   make_box_cmd,           vbalanced_box_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "vbalancedtop",                   make_box_cmd,           vbalanced_top_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "vbalancedinsert",                make_box_cmd,           vbalanced_insert_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "vbalanceddiscard",               make_box_cmd,           vbalanced_discard_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "vbalanceddeinsert",              make_box_cmd,           vbalanced_deinsert_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "vbalancedreinsert",              make_box_cmd,           vbalanced_reinsert_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "flushmvl",                       make_box_cmd,           flush_mvl_box_code,                       0);

        /*tex Begin compatibility. */

        tex_primitive(tex_command,        no_legacy,       "mathbin",                        math_component_cmd,     math_component_binary_code,               0);
        tex_primitive(tex_command,        no_legacy,       "mathclose",                      math_component_cmd,     math_component_close_code,                0);
        tex_primitive(tex_command,        no_legacy,       "mathinner",                      math_component_cmd,     math_component_inner_code,                0);
        tex_primitive(tex_command,        no_legacy,       "mathop",                         math_component_cmd,     math_component_operator_code,             0);
        tex_primitive(tex_command,        no_legacy,       "mathopen",                       math_component_cmd,     math_component_open_code,                 0);
        tex_primitive(tex_command,        no_legacy,       "mathord",                        math_component_cmd,     math_component_ordinary_code,             0);
        tex_primitive(tex_command,        no_legacy,       "mathpunct",                      math_component_cmd,     math_component_punctuation_code,          0);
        tex_primitive(tex_command,        no_legacy,       "mathrel",                        math_component_cmd,     math_component_relation_code,             0);
        tex_primitive(tex_command,        math_legacy,     "overline",                       math_component_cmd,     math_component_over_code,                 0);
        tex_primitive(tex_command,        math_legacy,     "underline",                      math_component_cmd,     math_component_under_code,                0);

        /*tex End compatibility. */

        /*
            We had these for a while but they are now dropped because (1) we should not overload |\mathaccent|
            (at least not now) and we have many user classes in \CONTEXT\ anyway.
        */

        /* begin of gone */ /*

        tex_primitive(luatex_command,     no_legacy,       "mathaccent",                     math_component_cmd,     math_component_accent_code,               0);
        tex_primitive(luatex_command,     no_legacy,       "mathbinary",                     math_component_cmd,     math_component_binary_code,               0);
        tex_primitive(luatex_command,     no_legacy,       "mathclose",                      math_component_cmd,     math_component_close_code,                0);
        tex_primitive(luatex_command,     no_legacy,       "mathfenced",                     math_component_cmd,     math_component_fenced_code,               0);
        tex_primitive(luatex_command,     no_legacy,       "mathfraction",                   math_component_cmd,     math_component_fraction_code,             0);
        tex_primitive(luatex_command,     no_legacy,       "mathghost",                      math_component_cmd,     math_component_ghost_code,                0);
        tex_primitive(luatex_command,     no_legacy,       "mathinner",                      math_component_cmd,     math_component_inner_code,                0);
        tex_primitive(luatex_command,     no_legacy,       "mathmiddle",                     math_component_cmd,     math_component_middle_code,               0);
        tex_primitive(luatex_command,     no_legacy,       "mathopen",                       math_component_cmd,     math_component_open_code,                 0);
        tex_primitive(luatex_command,     no_legacy,       "mathoperator",                   math_component_cmd,     math_component_operator_code,             0);
        tex_primitive(luatex_command,     no_legacy,       "mathordinary",                   math_component_cmd,     math_component_ordinary_code,             0);
        tex_primitive(luatex_command,     no_legacy,       "mathoverline",                   math_component_cmd,     math_component_over_code,                 0);
        tex_primitive(luatex_command,     no_legacy,       "mathpunctuation",                math_component_cmd,     math_component_punctuation_code,          0);
        tex_primitive(luatex_command,     no_legacy,       "mathradical",                    math_component_cmd,     math_component_radical_code,              0);
        tex_primitive(luatex_command,     no_legacy,       "mathrelation",                   math_component_cmd,     math_component_relation_code,             0);
        tex_primitive(luatex_command,     no_legacy,       "mathunderline",                  math_component_cmd,     math_component_under_code,                0);

        */ /* end of gone */

        tex_primitive(luametatex_command, no_legacy,       "mathatom",                       math_component_cmd,     math_component_atom_code,                 0);

        tex_primitive(luatex_command,     no_legacy,       "Ustartdisplaymath",              math_shift_cs_cmd,      begin_display_math_code,                  0);
        tex_primitive(luatex_command,     no_legacy,       "Ustartmath",                     math_shift_cs_cmd,      begin_inline_math_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "Ustartmathmode",                 math_shift_cs_cmd,      begin_math_mode_code,                     0);
        tex_primitive(luatex_command,     no_legacy,       "Ustopdisplaymath",               math_shift_cs_cmd,      end_display_math_code,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Ustopmath",                      math_shift_cs_cmd,      end_inline_math_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "Ustopmathmode",                  math_shift_cs_cmd,      end_math_mode_code,                       0);

        tex_primitive(luametatex_command, no_legacy,       "allcrampedstyles",               math_style_cmd,         all_cramped_styles,                       0);
        tex_primitive(luametatex_command, no_legacy,       "alldisplaystyles",               math_style_cmd,         all_display_styles,                       0);
        tex_primitive(luametatex_command, no_legacy,       "allmainstyles",                  math_style_cmd,         all_main_styles,                          0);
        tex_primitive(luametatex_command, no_legacy,       "allmathstyles",                  math_style_cmd,         all_math_styles,                          0);
        tex_primitive(luametatex_command, no_legacy,       "allscriptscriptstyles",          math_style_cmd,         all_script_script_styles,                 0);
        tex_primitive(luametatex_command, no_legacy,       "allscriptstyles",                math_style_cmd,         all_script_styles,                        0);
        tex_primitive(luametatex_command, no_legacy,       "allsplitstyles",                 math_style_cmd,         all_split_styles,                         0);
        tex_primitive(luametatex_command, no_legacy,       "alltextstyles",                  math_style_cmd,         all_text_styles,                          0);
        tex_primitive(luametatex_command, no_legacy,       "alluncrampedstyles",             math_style_cmd,         all_uncramped_styles,                     0);
        tex_primitive(luametatex_command, no_legacy,       "allunsplitstyles",               math_style_cmd,         all_unsplit_styles,                       0);
        tex_primitive(luatex_command,     no_legacy,       "crampeddisplaystyle",            math_style_cmd,         cramped_display_style,                    0);
        tex_primitive(luatex_command,     no_legacy,       "crampedscriptscriptstyle",       math_style_cmd,         cramped_script_script_style,              0);
        tex_primitive(luatex_command,     no_legacy,       "crampedscriptstyle",             math_style_cmd,         cramped_script_style,                     0);
        tex_primitive(luatex_command,     no_legacy,       "crampedtextstyle",               math_style_cmd,         cramped_text_style,                       0);
        tex_primitive(tex_command,        no_legacy,       "displaystyle",                   math_style_cmd,         display_style,                            0);
        tex_primitive(luametatex_command, no_legacy,       "scaledmathstyle",                math_style_cmd,         scaled_math_style,                        0);
        tex_primitive(tex_command,        no_legacy,       "scriptscriptstyle",              math_style_cmd,         script_script_style,                      0);
        tex_primitive(tex_command,        no_legacy,       "scriptstyle",                    math_style_cmd,         script_style,                             0);
        tex_primitive(tex_command,        no_legacy,       "textstyle",                      math_style_cmd,         text_style,                               0);
        tex_primitive(luametatex_command, no_legacy,       "currentlysetmathstyle",          math_style_cmd,         currently_set_math_style,                 0);
        tex_primitive(luametatex_command, no_legacy,       "givenmathstyle",                 math_style_cmd,         yet_unset_math_style,                     0);

        tex_primitive(tex_command,        no_legacy,       "errmessage",                     message_cmd,            error_message_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "message",                        message_cmd,            message_code,                             0);

        tex_primitive(tex_command,        no_legacy,       "mkern",                          mkern_cmd,              normal_code,                              0);

        tex_primitive(luametatex_command, no_legacy,       "mathatomskip",                   mskip_cmd,              atom_mskip_code,                          0);
        tex_primitive(tex_command,        no_legacy,       "mskip",                          mskip_cmd,              normal_mskip_code,                        0);

        /*tex
            We keep |\long| and |\outer| as dummies, while |\protected| is promoted to a real cmd
            and |\frozen| can provide a mild form of protection against overloads. We still intercept
            the commands.
        */

        tex_primitive(luametatex_command, no_legacy,       "aliased",                        prefix_cmd,             aliased_code,                                    0);
        tex_primitive(no_command,         no_legacy,       "always",                         prefix_cmd,             always_code,                                     0);
        tex_primitive(luametatex_command, no_legacy,       "constant",                       prefix_cmd,             constant_code,                                   0);
        tex_primitive(luametatex_command, no_legacy,       "constrained",                    prefix_cmd,             constrained_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "deferred",                       prefix_cmd,             deferred_code,                                   0);
        tex_primitive(luametatex_command, no_legacy,       "enforced",                       prefix_cmd,             enforced_code,                                   0);
        tex_primitive(luametatex_command, no_legacy,       "frozen",                         prefix_cmd,             frozen_code,                                     0);
        tex_primitive(tex_command,        no_legacy,       "global",                         prefix_cmd,             global_code,                                     0);
        tex_primitive(luatex_command,     no_legacy,       "immediate",                      prefix_cmd,             immediate_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "immutable",                      prefix_cmd,             immutable_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "inherited",                      prefix_cmd,             inherited_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "instance",                       prefix_cmd,             instance_code,                                   0);
        tex_primitive(tex_command,        ignored_legacy,  "long",                           prefix_cmd,             long_code,                                       0); /* nop */
        tex_primitive(luametatex_command, no_legacy,       "mutable",                        prefix_cmd,             mutable_code,                                    0);
        tex_primitive(luametatex_command, no_legacy,       "noaligned",                      prefix_cmd,             noaligned_code,                                  0);
        tex_primitive(tex_command,        ignored_legacy,  "outer",                          prefix_cmd,             outer_code,                                      0); /* nop */
        tex_primitive(luametatex_command, no_legacy,       "overloaded",                     prefix_cmd,             overloaded_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "permanent",                      prefix_cmd,             permanent_code,                                  0);
     /* tex_primitive(luametatex_command, no_legacy,       "primitive",                      prefix_cmd,             primitive_code,                                  0); */
        tex_primitive(etex_command,       no_legacy,       "protected",                      prefix_cmd,             protected_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "retained",                       prefix_cmd,             retained_code,                                   0);
        tex_primitive(luametatex_command, no_legacy,       "semiprotected",                  prefix_cmd,             semiprotected_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "tolerant",                       prefix_cmd,             tolerant_code,                                   0);
        tex_primitive(luatex_command,     no_legacy,       "untraced",                       prefix_cmd,             untraced_code,                                   0);

        tex_primitive(tex_command,        no_legacy,       "unboundary",                     remove_item_cmd,        boundary_item_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "unkern",                         remove_item_cmd,        kern_item_code,                                  0);
        tex_primitive(tex_command,        no_legacy,       "unpenalty",                      remove_item_cmd,        penalty_item_code,                               0);
        tex_primitive(tex_command,        no_legacy,       "unskip",                         remove_item_cmd,        skip_item_code,                                  0);

        tex_primitive(tex_command,        no_legacy,       "batchmode",                      interaction_cmd,        batch_mode,                                      0);
        tex_primitive(tex_command,        no_legacy,       "errorstopmode",                  interaction_cmd,        error_stop_mode,                                 0);
        tex_primitive(tex_command,        no_legacy,       "nonstopmode",                    interaction_cmd,        nonstop_mode,                                    0);
        tex_primitive(tex_command,        no_legacy,       "scrollmode",                     interaction_cmd,        scroll_mode,                                     0);

        tex_primitive(luatex_command,     no_legacy,       "attributedef",                   shorthand_def_cmd,      attribute_def_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "chardef",                        shorthand_def_cmd,      char_def_code,                                   0);
        tex_primitive(tex_command,        no_legacy,       "countdef",                       shorthand_def_cmd,      count_def_code,                                  0);
        tex_primitive(tex_command,        no_legacy,       "dimendef",                       shorthand_def_cmd,      dimen_def_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "dimensiondef",                   shorthand_def_cmd,      dimension_def_code,                              0);
     /* tex_primitive(luametatex_command, no_legacy,       "dimensiondefcsname",             shorthand_def_cmd,      dimension_def_csname_code,                       0); */
        tex_primitive(luametatex_command, no_legacy,       "floatdef",                       shorthand_def_cmd,      float_def_code,                                  0);
        tex_primitive(luametatex_command, no_legacy,       "fontspecdef",                    shorthand_def_cmd,      fontspec_def_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "specificationdef",               shorthand_def_cmd,      specification_def_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "gluespecdef",                    shorthand_def_cmd,      gluespec_def_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "integerdef",                     shorthand_def_cmd,      integer_def_code,                                0);
     /* tex_primitive(luametatex_command, no_legacy,       "integerdefcsname",               shorthand_def_cmd,      integer_def_csname_code,                         0); */
        tex_primitive(luatex_command,     no_legacy,       "luadef",                         shorthand_def_cmd,      lua_def_code,                                    0);
        tex_primitive(tex_command,        math_legacy,     "mathchardef",                    shorthand_def_cmd,      math_char_def_code,                              0);
     /* tex_primitive(luametatex_command, no_legacy,       "mathspecdef",                    shorthand_def_cmd,      mathspec_def_code,                               0); */
        tex_primitive(luametatex_command, no_legacy,       "mugluespecdef",                  shorthand_def_cmd,      mugluespec_def_code,                             0);
        tex_primitive(tex_command,        no_legacy,       "muskipdef",                      shorthand_def_cmd,      muskip_def_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "parameterdef",                   shorthand_def_cmd,      parameter_def_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "positdef",                       shorthand_def_cmd,      posit_def_code,                                  0);
        tex_primitive(tex_command,        no_legacy,       "skipdef",                        shorthand_def_cmd,      skip_def_code,                                   0);
        tex_primitive(tex_command,        no_legacy,       "toksdef",                        shorthand_def_cmd,      toks_def_code,                                   0);
        tex_primitive(luatex_command,     no_legacy,       "Umathchardef",                   shorthand_def_cmd,      math_uchar_def_code,                             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathdictdef",                   shorthand_def_cmd,      math_dchar_def_code,                             0);

        tex_primitive(luametatex_command, no_legacy,       "associateunit",                  association_cmd,        unit_association_code,                           0);

        tex_primitive(tex_command,        no_legacy,       "indent",                         begin_paragraph_cmd,    indent_par_code,                                 0);
        tex_primitive(tex_command,        no_legacy,       "noindent",                       begin_paragraph_cmd,    noindent_par_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "parattribute",                   begin_paragraph_cmd,    attribute_par_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "paroptions",                     begin_paragraph_cmd,    options_par_code,                                0); /* currently only used for experiments */
        tex_primitive(luatex_command,     no_legacy,       "quitvmode",                      begin_paragraph_cmd,    quitvmode_par_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "snapshotpar",                    begin_paragraph_cmd,    snapshot_par_code,                               0);
        tex_primitive(luametatex_command, no_legacy,       "undent",                         begin_paragraph_cmd,    undent_par_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "wrapuppar",                      begin_paragraph_cmd,    wrapup_par_code,                                 0);

        tex_primitive(tex_command,        no_legacy,       "dump",                           end_job_cmd,            dump_code,                                       0);
        tex_primitive(tex_command,        no_legacy,       "end",                            end_job_cmd,            end_code,                                        0);

        tex_primitive(luametatex_command, no_legacy,       "beginlocalcontrol",              begin_local_cmd,        local_control_begin_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "expandedendless",                begin_local_cmd,        expanded_endless_code,                           0);
        tex_primitive(luametatex_command, no_legacy,       "expandedloop",                   begin_local_cmd,        expanded_loop_code,                              0);
        tex_primitive(luametatex_command, no_legacy,       "expandedrepeat",                 begin_local_cmd,        expanded_repeat_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "localcontrol",                   begin_local_cmd,        local_control_token_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "localcontrolled",                begin_local_cmd,        local_control_list_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "localcontrolledendless",         begin_local_cmd,        local_control_endless_code,                      0);
        tex_primitive(luametatex_command, no_legacy,       "localcontrolledloop",            begin_local_cmd,        local_control_loop_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "localcontrolledrepeat",          begin_local_cmd,        local_control_repeat_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "unexpandedendless",              begin_local_cmd,        unexpanded_endless_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "unexpandedloop",                 begin_local_cmd,        unexpanded_loop_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "unexpandedrepeat",               begin_local_cmd,        unexpanded_repeat_code,                          0);

        tex_primitive(luatex_command,     no_legacy,       "endlocalcontrol",                end_local_cmd,          normal_code,                                     0);

        tex_primitive(tex_command,        no_legacy,       "unhbox",                         un_hbox_cmd,            box_code,                                        0);
        tex_primitive(tex_command,        no_legacy,       "unhcopy",                        un_hbox_cmd,            copy_code,                                       0);
        tex_primitive(luametatex_command, no_legacy,       "unhpack",                        un_hbox_cmd,            unpack_code,                                     0);
        tex_primitive(tex_command,        no_legacy,       "unvbox",                         un_vbox_cmd,            box_code,                                        0);
        tex_primitive(tex_command,        no_legacy,       "unvcopy",                        un_vbox_cmd,            copy_code,                                       0);
        tex_primitive(luametatex_command, no_legacy,       "unvpack",                        un_vbox_cmd,            unpack_code,                                     0);

        tex_primitive(etex_command,       no_legacy,       "pagediscards",                   un_vbox_cmd,            page_discards_code,                              0);
        tex_primitive(etex_command,       no_legacy,       "splitdiscards",                  un_vbox_cmd,            split_discards_code,                             0);
        tex_primitive(luametatex_command, no_legacy,       "copysplitdiscards",              un_vbox_cmd,            copy_split_discards_code,                        0);

        tex_primitive(luametatex_command, no_legacy,       "insertunbox",                    un_vbox_cmd,            insert_box_code,                                 0);
        tex_primitive(luametatex_command, no_legacy,       "insertuncopy",                   un_vbox_cmd,            insert_copy_code,                                0);

        tex_primitive(tex_command,        no_legacy,       "lower",                          vmove_cmd,              move_forward_code,                               0);
        tex_primitive(tex_command,        no_legacy,       "raise",                          vmove_cmd,              move_backward_code,                              0);

        tex_primitive(tex_command,        no_legacy,       "vfil",                           vskip_cmd,              fi_l_code,                                       0);
        tex_primitive(tex_command,        no_legacy,       "vfill",                          vskip_cmd,              fi_ll_code,                                      0);
        tex_primitive(tex_command,        no_legacy,       "vfilneg",                        vskip_cmd,              fi_l_neg_code,                                   0);
        tex_primitive(tex_command,        no_legacy,       "vskip",                          vskip_cmd,              skip_code,                                       0);
        tex_primitive(tex_command,        no_legacy,       "vss",                            vskip_cmd,              fi_ss_code,                                      0);

        tex_primitive(tex_command,        no_legacy,       "show",                           xray_cmd,               show_code,                                       0);
        tex_primitive(tex_command,        no_legacy,       "showbox",                        xray_cmd,               show_box_code,                                   0);
        tex_primitive(luametatex_command, no_legacy,       "showcodestack",                  xray_cmd,               show_code_stack_code,                            0);
        tex_primitive(etex_command,       no_legacy,       "showgroups",                     xray_cmd,               show_groups_code,                                0);
        tex_primitive(luametatex_command, no_legacy,       "showstack",                      xray_cmd,               show_stack_code,                                 0);
        tex_primitive(etex_command,       no_legacy,       "showifs",                        xray_cmd,               show_ifs_code,                                   0);
        tex_primitive(tex_command,        no_legacy,       "showlists",                      xray_cmd,               show_lists_code,                                 0);
        tex_primitive(tex_command,        no_legacy,       "showthe",                        xray_cmd,               show_the_code,                                   0);
        tex_primitive(etex_command,       no_legacy,       "showtokens",                     xray_cmd,               show_tokens_code,                                0);

        tex_primitive(luatex_command,     no_legacy,       "initcatcodetable",               catcode_table_cmd,      init_cat_code_table_code,                        0);
        tex_primitive(luatex_command,     no_legacy,       "savecatcodetable",               catcode_table_cmd,      save_cat_code_table_code,                        0);
        tex_primitive(luametatex_command, no_legacy,       "restorecatcodetable",            catcode_table_cmd,      restore_cat_code_table_code,                     0);
     /* tex_primitive(luametatex_command, no_legacy,       "setcatcodetabledefault",         catcode_table_cmd,      dflt_cat_code_table_code,                        0); */ /* This was an experiment. */

        tex_primitive(luatex_command,     no_legacy,       "alignmark",                      parameter_cmd,          normal_code,                                     0);
        tex_primitive(luametatex_command, no_legacy,       "parametermark",                  parameter_cmd,          normal_code,                                     0); /* proper primitive for syntax highlighting */

        tex_primitive(luatex_command,     no_legacy,       "aligntab",                       alignment_tab_cmd,      tab_mark_code,                                   0);

        tex_primitive(luametatex_command, no_legacy,       "aligncontent",                   alignment_cmd,          align_content_code,                              0);
        tex_primitive(tex_command,        no_legacy,       "cr",                             alignment_cmd,          cr_code,                                         0);
        tex_primitive(tex_command,        no_legacy,       "crcr",                           alignment_cmd,          cr_cr_code,                                      0);
        tex_primitive(tex_command,        no_legacy,       "noalign",                        alignment_cmd,          no_align_code,                                   0);
        tex_primitive(tex_command,        no_legacy,       "omit",                           alignment_cmd,          omit_code,                                       0);
        tex_primitive(luatex_command,     no_legacy,       "realign",                        alignment_cmd,          re_align_code,                                   0);
        tex_primitive(tex_command,        no_legacy,       "span",                           alignment_cmd,          span_code,                                       0);

        tex_primitive(luametatex_command, no_legacy,       "noatomruling",                   math_script_cmd,        math_no_ruling_space_code,                       0);
        tex_primitive(tex_command,        no_legacy,       "nonscript",                      math_script_cmd,        math_no_script_space_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "nosubprescript",                 math_script_cmd,        math_no_sub_pre_script_code,                     0);
        tex_primitive(luametatex_command, no_legacy,       "nosubscript",                    math_script_cmd,        math_no_sub_script_code,                         0);
        tex_primitive(luametatex_command, no_legacy,       "nosuperprescript",               math_script_cmd,        math_no_super_pre_script_code,                   0);
        tex_primitive(luametatex_command, no_legacy,       "nosuperscript",                  math_script_cmd,        math_no_super_script_code,                       0);
        tex_primitive(luametatex_command, no_legacy,       "primescript",                    math_script_cmd,        math_prime_script_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "indexedsubprescript",            math_script_cmd,        math_indexed_sub_pre_script_code,                0);
        tex_primitive(luametatex_command, no_legacy,       "indexedsubscript",               math_script_cmd,        math_indexed_sub_script_code,                    0);
        tex_primitive(luametatex_command, no_legacy,       "indexedsuperprescript",          math_script_cmd,        math_indexed_super_pre_script_code,              0);
        tex_primitive(luametatex_command, no_legacy,       "indexedsuperscript",             math_script_cmd,        math_indexed_super_script_code,                  0);
        tex_primitive(luametatex_command, no_legacy,       "subprescript",                   math_script_cmd,        math_sub_pre_script_code,                        0);
        tex_primitive(luatex_command,     no_legacy,       "subscript",                      math_script_cmd,        math_sub_script_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "superprescript",                 math_script_cmd,        math_super_pre_script_code,                      0);
        tex_primitive(luatex_command,     no_legacy,       "superscript",                    math_script_cmd,        math_super_script_code,                          0);
        tex_primitive(luatex_command,     no_legacy,       "noscript",                       math_script_cmd,        math_no_script_code,                             0);

        tex_primitive(luametatex_command, no_legacy,       "copymathatomrule",               math_parameter_cmd,     math_parameter_copy_atom_rule,                   0);
        tex_primitive(luametatex_command, no_legacy,       "copymathparent",                 math_parameter_cmd,     math_parameter_copy_parent,                      0);
        tex_primitive(luametatex_command, no_legacy,       "copymathspacing",                math_parameter_cmd,     math_parameter_copy_spacing,                     0);
        tex_primitive(luametatex_command, no_legacy,       "letmathatomrule",                math_parameter_cmd,     math_parameter_let_atom_rule,                    0);
        tex_primitive(luametatex_command, no_legacy,       "letmathparent",                  math_parameter_cmd,     math_parameter_let_parent,                       0);
        tex_primitive(luametatex_command, no_legacy,       "letmathspacing",                 math_parameter_cmd,     math_parameter_let_spacing,                      0);
        tex_primitive(luametatex_command, no_legacy,       "resetmathspacing",               math_parameter_cmd,     math_parameter_reset_spacing,                    0);
        tex_primitive(luametatex_command, no_legacy,       "setdefaultmathcodes",            math_parameter_cmd,     math_parameter_set_defaults,                     0);
        tex_primitive(luametatex_command, no_legacy,       "setmathatomrule",                math_parameter_cmd,     math_parameter_set_atom_rule,                    0);
        tex_primitive(luametatex_command, no_legacy,       "setmathdisplaypostpenalty",      math_parameter_cmd,     math_parameter_set_display_post_penalty,         0);
        tex_primitive(luametatex_command, no_legacy,       "setmathdisplayprepenalty",       math_parameter_cmd,     math_parameter_set_display_pre_penalty,          0);
        tex_primitive(luametatex_command, no_legacy,       "setmathignore",                  math_parameter_cmd,     math_parameter_ignore,                           0);
        tex_primitive(luametatex_command, no_legacy,       "setmathoptions",                 math_parameter_cmd,     math_parameter_options,                          0);
        tex_primitive(luametatex_command, no_legacy,       "setmathpostpenalty",             math_parameter_cmd,     math_parameter_set_post_penalty,                 0);
        tex_primitive(luametatex_command, no_legacy,       "setmathprepenalty",              math_parameter_cmd,     math_parameter_set_pre_penalty,                  0);
        tex_primitive(luametatex_command, no_legacy,       "setmathspacing",                 math_parameter_cmd,     math_parameter_set_spacing,                      0);

        tex_primitive(luametatex_command, no_legacy,       "Umathaccentbasedepth",           math_parameter_cmd,     math_parameter_accent_base_depth,                0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentbaseheight",          math_parameter_cmd,     math_parameter_accent_base_height,               0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentbottomovershoot",     math_parameter_cmd,     math_parameter_accent_bottom_overshoot,          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentbottomshiftdown",     math_parameter_cmd,     math_parameter_accent_bottom_shift_down,         0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentextendmargin",        math_parameter_cmd,     math_parameter_accent_extend_margin,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentsuperscriptdrop",     math_parameter_cmd,     math_parameter_accent_superscript_drop,          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentsuperscriptpercent",  math_parameter_cmd,     math_parameter_accent_superscript_percent,       0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccenttopovershoot",        math_parameter_cmd,     math_parameter_accent_top_overshoot,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccenttopshiftup",          math_parameter_cmd,     math_parameter_accent_top_shift_up,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathaccentvariant",             math_parameter_cmd,     math_parameter_degree_variant,                   0);
        tex_primitive(luatex_command,     no_legacy,       "Umathaxis",                      math_parameter_cmd,     math_parameter_axis,                             0);
     /* tex_primitive(luatex_command,     no_legacy,       "Umathbinbinspacing",             math_parameter_cmd,     math_parameter_binary_binary_spacing, 0); */ /* Gone, as are more of these! */
        tex_primitive(luametatex_command, no_legacy,       "Umathbottomaccentvariant",       math_parameter_cmd,     math_parameter_bottom_accent_variant,            0);
        tex_primitive(luatex_command,     no_legacy,       "Umathconnectoroverlapmin",       math_parameter_cmd,     math_parameter_connector_overlap_min,            0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdegreevariant",             math_parameter_cmd,     math_parameter_accent_variant,                   0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdelimiterextendmargin",     math_parameter_cmd,     math_parameter_delimiter_extend_margin,          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdelimiterovervariant",      math_parameter_cmd,     math_parameter_delimiter_over_variant,           0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdelimiterpercent",          math_parameter_cmd,     math_parameter_delimiter_percent,                0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdelimitershortfall",        math_parameter_cmd,     math_parameter_delimiter_shortfall,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdelimiterundervariant",     math_parameter_cmd,     math_parameter_delimiter_under_variant,          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathdenominatorvariant",        math_parameter_cmd,     math_parameter_denominator_variant,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasubpreshift",          math_parameter_cmd,     math_parameter_extra_subprescript_shift,         0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasubprespace",          math_parameter_cmd,     math_parameter_extra_subprescript_space,         0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasubshift",             math_parameter_cmd,     math_parameter_extra_subscript_shift,            0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasubspace",             math_parameter_cmd,     math_parameter_extra_subscript_space,            0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasuppreshift",          math_parameter_cmd,     math_parameter_extra_superprescript_shift,       0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasupprespace",          math_parameter_cmd,     math_parameter_extra_superprescript_space,       0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasupshift",             math_parameter_cmd,     math_parameter_extra_superscript_shift,          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathextrasupspace",             math_parameter_cmd,     math_parameter_extra_superscript_space,          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathsubscriptsnap",             math_parameter_cmd,     math_parameter_subscript_snap,                   0);
        tex_primitive(luametatex_command, no_legacy,       "Umathsuperscriptsnap",           math_parameter_cmd,     math_parameter_superscript_snap,                 0);
        tex_primitive(luametatex_command, no_legacy,       "Umathflattenedaccentbasedepth",  math_parameter_cmd,     math_parameter_flattened_accent_base_depth,      0);
        tex_primitive(luametatex_command, no_legacy,       "Umathflattenedaccentbaseheight", math_parameter_cmd,     math_parameter_flattened_accent_base_height,     0);
        tex_primitive(luametatex_command, no_legacy,       "Umathflattenedaccentbottomshiftdown", math_parameter_cmd, math_parameter_flattened_accent_bottom_shift_down, 0);
        tex_primitive(luametatex_command, no_legacy,       "Umathflattenedaccenttopshiftup",      math_parameter_cmd, math_parameter_flattened_accent_top_shift_up,      0);
        tex_primitive(luatex_command,     no_legacy,       "Umathfractiondelsize",           math_parameter_cmd,     math_parameter_fraction_del_size,                0);
        tex_primitive(luatex_command,     no_legacy,       "Umathfractiondenomdown",         math_parameter_cmd,     math_parameter_fraction_denom_down,              0);
        tex_primitive(luatex_command,     no_legacy,       "Umathfractiondenomvgap",         math_parameter_cmd,     math_parameter_fraction_denom_vgap,              0);
        tex_primitive(luatex_command,     no_legacy,       "Umathfractionnumup",             math_parameter_cmd,     math_parameter_fraction_num_up,                  0);
        tex_primitive(luatex_command,     no_legacy,       "Umathfractionnumvgap",           math_parameter_cmd,     math_parameter_fraction_num_vgap,                0);
        tex_primitive(luatex_command,     no_legacy,       "Umathfractionrule",              math_parameter_cmd,     math_parameter_fraction_rule,                    0);
        tex_primitive(luametatex_command, no_legacy,       "Umathfractionvariant",           math_parameter_cmd,     math_parameter_fraction_variant,                 0);
        tex_primitive(luametatex_command, no_legacy,       "Umathhextensiblevariant",        math_parameter_cmd,     math_parameter_h_extensible_variant,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathlimitabovebgap",            math_parameter_cmd,     math_parameter_limit_above_bgap,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathlimitabovekern",            math_parameter_cmd,     math_parameter_limit_above_kern,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathlimitabovevgap",            math_parameter_cmd,     math_parameter_limit_above_vgap,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathlimitbelowbgap",            math_parameter_cmd,     math_parameter_limit_below_bgap,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathlimitbelowkern",            math_parameter_cmd,     math_parameter_limit_below_kern,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathlimitbelowvgap",            math_parameter_cmd,     math_parameter_limit_below_vgap,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathnolimitsubfactor",          math_parameter_cmd,     math_parameter_nolimit_sub_factor,               0); /* These are bonus parameters. */
        tex_primitive(luatex_command,     no_legacy,       "Umathnolimitsupfactor",          math_parameter_cmd,     math_parameter_nolimit_sup_factor,               0); /* These are bonus parameters. */
        tex_primitive(luametatex_command, no_legacy,       "Umathnumeratorvariant",          math_parameter_cmd,     math_parameter_numerator_variant,                0);
        tex_primitive(luatex_command,     no_legacy,       "Umathoperatorsize",              math_parameter_cmd,     math_parameter_operator_size,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathoverbarkern",               math_parameter_cmd,     math_parameter_overbar_kern,                     0);
        tex_primitive(luatex_command,     no_legacy,       "Umathoverbarrule",               math_parameter_cmd,     math_parameter_overbar_rule,                     0);
        tex_primitive(luatex_command,     no_legacy,       "Umathoverbarvgap",               math_parameter_cmd,     math_parameter_overbar_vgap,                     0);
        tex_primitive(luatex_command,     no_legacy,       "Umathoverdelimiterbgap",         math_parameter_cmd,     math_parameter_over_delimiter_bgap,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathoverdelimitervariant",      math_parameter_cmd,     math_parameter_over_delimiter_variant,           0);
        tex_primitive(luatex_command,     no_legacy,       "Umathoverdelimitervgap",         math_parameter_cmd,     math_parameter_over_delimiter_vgap,              0);
        tex_primitive(luametatex_command, no_legacy,       "Umathoverlayaccentvariant",      math_parameter_cmd,     math_parameter_overlay_accent_variant,           0);
        tex_primitive(luametatex_command, no_legacy,       "Umathoverlinevariant",           math_parameter_cmd,     math_parameter_over_line_variant,                0);
        tex_primitive(luametatex_command, no_legacy,       "Umathprimeraise",                math_parameter_cmd,     math_parameter_prime_raise,                      0);
        tex_primitive(luametatex_command, no_legacy,       "Umathprimeraisecomposed",        math_parameter_cmd,     math_parameter_prime_raise_composed,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathprimeshiftdrop",            math_parameter_cmd,     math_parameter_prime_shift_drop,                 0);
        tex_primitive(luametatex_command, no_legacy,       "Umathprimeshiftup",              math_parameter_cmd,     math_parameter_prime_shift_up,                   0);
        tex_primitive(luametatex_command, no_legacy,       "Umathprimespaceafter",           math_parameter_cmd,     math_parameter_prime_space_after,                0);
        tex_primitive(luametatex_command, no_legacy,       "Umathprimevariant",              math_parameter_cmd,     math_parameter_prime_variant,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathquad",                      math_parameter_cmd,     math_parameter_quad,                             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathexheight",                  math_parameter_cmd,     math_parameter_exheight,                         0);
        tex_primitive(luatex_command,     no_legacy,       "Umathradicaldegreeafter",        math_parameter_cmd,     math_parameter_radical_degree_after,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathradicaldegreebefore",       math_parameter_cmd,     math_parameter_radical_degree_before,            0);
        tex_primitive(luatex_command,     no_legacy,       "Umathradicaldegreeraise",        math_parameter_cmd,     math_parameter_radical_degree_raise,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathradicalextensibleafter",    math_parameter_cmd,     math_parameter_radical_extensible_after,         0);
        tex_primitive(luametatex_command, no_legacy,       "Umathradicalextensiblebefore",   math_parameter_cmd,     math_parameter_radical_extensible_before,        0);
        tex_primitive(luatex_command,     no_legacy,       "Umathradicalkern",               math_parameter_cmd,     math_parameter_radical_kern,                     0);
        tex_primitive(luatex_command,     no_legacy,       "Umathradicalrule",               math_parameter_cmd,     math_parameter_radical_rule,                     0);
        tex_primitive(luametatex_command, no_legacy,       "Umathradicalvariant",            math_parameter_cmd,     math_parameter_radical_variant,                  0);
        tex_primitive(luatex_command,     no_legacy,       "Umathradicalvgap",               math_parameter_cmd,     math_parameter_radical_vgap,                     0);
        tex_primitive(luatex_command,     no_legacy,       "Umathruledepth",                 math_parameter_cmd,     math_parameter_rule_depth,                       0);
        tex_primitive(luatex_command,     no_legacy,       "Umathruleheight",                math_parameter_cmd,     math_parameter_rule_height,                      0);
        tex_primitive(luatex_command,     no_legacy,       "Umathskeweddelimitertolerance",  math_parameter_cmd,     math_parameter_skewed_delimiter_tolerance,       0);
        tex_primitive(luatex_command,     no_legacy,       "Umathskewedfractionhgap",        math_parameter_cmd,     math_parameter_skewed_fraction_hgap,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathskewedfractionvgap",        math_parameter_cmd,     math_parameter_skewed_fraction_vgap,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathspaceafterscript",          math_parameter_cmd,     math_parameter_space_after_script,               0);
        tex_primitive(luatex_command,     no_legacy,       "Umathspacebetweenscript",        math_parameter_cmd,     math_parameter_space_between_script,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathspacebeforescript",         math_parameter_cmd,     math_parameter_space_before_script,              0);
        tex_primitive(luatex_command,     no_legacy,       "Umathstackdenomdown",            math_parameter_cmd,     math_parameter_stack_denom_down,                 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathstacknumup",                math_parameter_cmd,     math_parameter_stack_num_up,                     0);
        tex_primitive(luametatex_command, no_legacy,       "Umathstackvariant",              math_parameter_cmd,     math_parameter_stack_variant,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathstackvgap",                 math_parameter_cmd,     math_parameter_stack_vgap,                       0);
        tex_primitive(luametatex_command, no_legacy,       "Umathsubscriptvariant",          math_parameter_cmd,     math_parameter_subscript_variant,                0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsubshiftdown",              math_parameter_cmd,     math_parameter_subscript_shift_down,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsubshiftdrop",              math_parameter_cmd,     math_parameter_subscript_shift_drop,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsubsupshiftdown",           math_parameter_cmd,     math_parameter_subscript_superscript_shift_down, 0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsubsupvgap",                math_parameter_cmd,     math_parameter_subscript_superscript_vgap,       0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsubtopmax",                 math_parameter_cmd,     math_parameter_subscript_top_max,                0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsupbottommin",              math_parameter_cmd,     math_parameter_superscript_bottom_min,           0);
        tex_primitive(luametatex_command, no_legacy,       "Umathsuperscriptvariant",        math_parameter_cmd,     math_parameter_superscript_variant,              0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsupshiftdrop",              math_parameter_cmd,     math_parameter_superscript_shift_drop,           0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsupshiftup",                math_parameter_cmd,     math_parameter_superscript_shift_up,             0);
        tex_primitive(luatex_command,     no_legacy,       "Umathsupsubbottommax",           math_parameter_cmd,     math_parameter_superscript_subscript_bottom_max, 0);
        tex_primitive(luametatex_command, no_legacy,       "Umathtopaccentvariant",          math_parameter_cmd,     math_parameter_top_accent_variant,               0);
        tex_primitive(luatex_command,     no_legacy,       "Umathunderbarkern",              math_parameter_cmd,     math_parameter_underbar_kern,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathunderbarrule",              math_parameter_cmd,     math_parameter_underbar_rule,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathunderbarvgap",              math_parameter_cmd,     math_parameter_underbar_vgap,                    0);
        tex_primitive(luatex_command,     no_legacy,       "Umathunderdelimiterbgap",        math_parameter_cmd,     math_parameter_under_delimiter_bgap,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathunderdelimitervariant",     math_parameter_cmd,     math_parameter_under_delimiter_variant,          0);
        tex_primitive(luatex_command,     no_legacy,       "Umathunderdelimitervgap",        math_parameter_cmd,     math_parameter_under_delimiter_vgap,             0);
        tex_primitive(luametatex_command, no_legacy,       "Umathunderlinevariant",          math_parameter_cmd,     math_parameter_under_line_variant,               0);
        tex_primitive(luametatex_command, no_legacy,       "Umathvextensiblevariant",        math_parameter_cmd,     math_parameter_v_extensible_variant,             0);

        tex_primitive(luametatex_command, no_legacy,       "Umathxscale",                    math_parameter_cmd,     math_parameter_x_scale,                          0);
        tex_primitive(luametatex_command, no_legacy,       "Umathyscale",                    math_parameter_cmd,     math_parameter_y_scale,                          0);

        tex_primitive(no_command,         no_legacy,       "insertedpar",                    end_paragraph_cmd,      inserted_end_paragraph_code,                     0);
        tex_primitive(no_command,         no_legacy,       "newlinepar",                     end_paragraph_cmd,      new_line_end_paragraph_code,                     0);
        tex_primitive(tex_command,        no_legacy,       "par",                            end_paragraph_cmd,      normal_end_paragraph_code,                       0); /* |too_big_char| */
        tex_primitive(luametatex_command, no_legacy,       "localbreakpar",                  end_paragraph_cmd,      local_break_end_paragraph_code,                  0);

     /* tex_primitive(luatex_command,     no_legacy,       "linepar",                        undefined_cs_cmd,       0,                                               0); */ /*tex A user can define this one.*/

        tex_primitive(tex_command,        no_legacy,       "endgroup",                       end_group_cmd,          semi_simple_group_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "endmathgroup",                   end_group_cmd,          math_simple_group_code,                          0);
        tex_primitive(luametatex_command, no_legacy,       "endsimplegroup",                 end_group_cmd,          also_simple_group_code,                          0);

        tex_primitive(no_command,         no_legacy,       "noexpandrelax",                  relax_cmd,              no_expand_relax_code,                            0);
        tex_primitive(luametatex_command, no_legacy,       "norelax",                        relax_cmd,              no_relax_code,                                   0);
        tex_primitive(luametatex_command, no_legacy,       "noarguments",                    relax_cmd,              no_arguments_relax_code,                         0);
        tex_primitive(tex_command,        no_legacy,       "relax",                          relax_cmd,              relax_code,                                      0);

        tex_primitive(tex_command,        no_legacy,       "nullfont",                       set_font_cmd,           null_font,                                       0);

        /*tex

            A bunch of commands that need a special treatment, so we delayed their initialization.
            They are in the above list but commented. We start with those that alias to (already
            defined) primitives. Actually we can say something like:

            \starttyping
            primitive(tex_command, "fi", if_test_cmd, fi_code, 0);
            cs_text(deep_frozen_cs_fi_code) = maketexstring("fi");
            copy_eqtb_entry(deep_frozen_cs_fi_code, cur_val);
            \stoptyping

            but we use a helper that does a primitive lookup and shares the already allocated
            string. The effect is the same but it adds a little abstraction and saves a few
            redundant strings.

        */

        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_end_group_code, "endgroup");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_relax_code,     "relax");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_fi_code,        "fi");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_no_if_code,     "noif");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_always_code,    "always");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_right_code,     "right");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_null_font_code, "nullfont");
        tex_aux_copy_deep_frozen_from_primitive(deep_frozen_cs_cr_code,        "cr");

        lmt_token_state.par_loc   = tex_primitive_lookup(tex_located_string("par"));
        lmt_token_state.par_token = cs_token_flag + lmt_token_state.par_loc;

     /* lmt_token_state.line_par_loc   = tex_prim_lookup(tex_located_string("linepar")); */
     /* lmt_token_state.line_par_token = cs_token_flag + lmt_token_state.line_par_loc;   */

        /*tex
            These don't alias to existing commands. They are all inaccessible but might show up in
            error messages and tracing. We could set the flags to resticted values. We need to
            intercept them in the function that prints the |chr| because they can be out of range.
        */

        cs_text(deep_frozen_cs_end_template_code) = tex_maketexstring("endtemplate");
        set_eq_type(deep_frozen_cs_end_template_code, deep_frozen_end_template_cmd);
        set_eq_flag(deep_frozen_cs_end_template_code, 0);
        set_eq_value(deep_frozen_cs_end_template_code, lmt_token_state.null_list);
        set_eq_level(deep_frozen_cs_end_template_code, level_one);

        cs_text(deep_frozen_cs_dont_expand_code) = tex_maketexstring("dontexpand");
        set_eq_type(deep_frozen_cs_dont_expand_code, deep_frozen_dont_expand_cmd);
        set_eq_flag(deep_frozen_cs_dont_expand_code, 0);

        cs_text(deep_frozen_cs_keep_constant_code) = tex_maketexstring("keepconstant");
        set_eq_type(deep_frozen_cs_keep_constant_code, deep_frozen_keep_constant_cmd);
        set_eq_flag(deep_frozen_cs_keep_constant_code, 0);
        set_eq_value(deep_frozen_cs_keep_constant_code, lmt_token_state.null_list); /* not needed */
        set_eq_level(deep_frozen_cs_keep_constant_code, level_one);                 /* not needed */

        cs_text(deep_frozen_cs_protection_code) = tex_maketexstring("inaccessible");

        cs_text(deep_frozen_cs_end_write_code) = tex_maketexstring("endwrite");
        set_eq_type(deep_frozen_cs_end_write_code, call_cmd);
        set_eq_flag(deep_frozen_cs_end_write_code, 0);
        set_eq_value(deep_frozen_cs_end_write_code, null);
        set_eq_level(deep_frozen_cs_end_write_code, level_one);

        /*tex The empty list reference should be reassigned after compacting! */

        lmt_token_state.empty = get_reference_token();
     // tex_add_token_reference(lmt_token_state.empty);
        set_token_reference(lmt_token_state.empty, max_token_reference);

        lmt_string_pool_state.reserved = lmt_string_pool_state.string_pool_data.ptr;
        lmt_hash_state.no_new_cs = 1;

    }
}
