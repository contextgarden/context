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
    [par_shape_dimension_code]      = classification_unknown,   
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

static void tex_aux_copy_deep_frozen_from_primitive(halfword code, const char *s)
{
    halfword p = tex_prim_lookup(tex_located_string(s));
    cs_text(code) = cs_text(p);
    copy_eqtb_entry(code, p);
}

/* 
    The commands are sorted alphabetically which makes it easier to check the syntax charts. The 
    order within the command classes is more chronological. 
*/

void tex_initialize_commands(void)
{

    if (lmt_main_state.run_state == initializing_state) {

        lmt_hash_state.no_new_cs = 0;
        lmt_fileio_state.io_first = 0;

        /*tex glue */

        tex_primitive(tex_command,    "abovedisplayshortskip",          internal_glue_cmd,      above_display_short_skip_code,            internal_glue_base);
        tex_primitive(tex_command,    "abovedisplayskip",               internal_glue_cmd,      above_display_skip_code,                  internal_glue_base);
        tex_primitive(luatex_command, "additionalpageskip",             internal_glue_cmd,      additional_page_skip_code,                internal_glue_base);
        tex_primitive(tex_command,    "baselineskip",                   internal_glue_cmd,      baseline_skip_code,                       internal_glue_base);
        tex_primitive(tex_command,    "belowdisplayshortskip",          internal_glue_cmd,      below_display_short_skip_code,            internal_glue_base);
        tex_primitive(tex_command,    "belowdisplayskip",               internal_glue_cmd,      below_display_skip_code,                  internal_glue_base);
        tex_primitive(luatex_command, "emergencyleftskip",              internal_glue_cmd,      emergency_left_skip_code,                 internal_glue_base);
        tex_primitive(luatex_command, "emergencyrightskip",             internal_glue_cmd,      emergency_right_skip_code,                internal_glue_base);
        tex_primitive(luatex_command, "initialpageskip",                internal_glue_cmd,      initial_page_skip_code,                   internal_glue_base);
        tex_primitive(luatex_command, "initialtopskip",                 internal_glue_cmd,      initial_top_skip_code,                    internal_glue_base);
        tex_primitive(tex_command,    "leftskip",                       internal_glue_cmd,      left_skip_code,                           internal_glue_base);
        tex_primitive(tex_command,    "lineskip",                       internal_glue_cmd,      line_skip_code,                           internal_glue_base);
        tex_primitive(luatex_command, "mathsurroundskip",               internal_glue_cmd,      math_skip_code,                           internal_glue_base);
        tex_primitive(luatex_command, "maththreshold",                  internal_glue_cmd,      math_threshold_code,                      internal_glue_base);
        tex_primitive(luatex_command, "parfillleftskip",                internal_glue_cmd,      par_fill_left_skip_code,                  internal_glue_base);
        tex_primitive(luatex_command, "parfillrightskip",               internal_glue_cmd,      par_fill_right_skip_code,                 internal_glue_base);
        tex_primitive(tex_command,    "parfillskip",                    internal_glue_cmd,      par_fill_right_skip_code,                 internal_glue_base); /*tex This is more like an alias now. */
        tex_primitive(luatex_command, "parinitleftskip",                internal_glue_cmd,      par_init_left_skip_code,                  internal_glue_base);
        tex_primitive(luatex_command, "parinitrightskip",               internal_glue_cmd,      par_init_right_skip_code,                 internal_glue_base);
        tex_primitive(tex_command,    "parskip",                        internal_glue_cmd,      par_skip_code,                            internal_glue_base);
        tex_primitive(tex_command,    "rightskip",                      internal_glue_cmd,      right_skip_code,                          internal_glue_base);
        tex_primitive(tex_command,    "spaceskip",                      internal_glue_cmd,      space_skip_code,                          internal_glue_base);
        tex_primitive(tex_command,    "splittopskip",                   internal_glue_cmd,      split_top_skip_code,                      internal_glue_base);
        tex_primitive(tex_command,    "tabskip",                        internal_glue_cmd,      tab_skip_code,                            internal_glue_base);
        tex_primitive(tex_command,    "topskip",                        internal_glue_cmd,      top_skip_code,                            internal_glue_base);
        tex_primitive(tex_command,    "xspaceskip",                     internal_glue_cmd,      xspace_skip_code,                         internal_glue_base);

        /*tex math glue */

        tex_primitive(tex_command,    "medmuskip",                      internal_muglue_cmd,    med_muskip_code,                          internal_muglue_base);
        tex_primitive(luatex_command, "pettymuskip",                    internal_muglue_cmd,    petty_muskip_code,                        internal_muglue_base);
        tex_primitive(tex_command,    "thickmuskip",                    internal_muglue_cmd,    thick_muskip_code,                        internal_muglue_base);
        tex_primitive(tex_command,    "thinmuskip",                     internal_muglue_cmd,    thin_muskip_code,                         internal_muglue_base);
        tex_primitive(luatex_command, "tinymuskip",                     internal_muglue_cmd,    tiny_muskip_code,                         internal_muglue_base);

        /*tex tokens */

        tex_primitive(no_command,     "endofgroup",                     internal_toks_cmd,      end_of_group_code,                        internal_toks_base);
     /* tex_primitive(luatex_command, "endofpar",                       internal_toks_cmd,      end_of_par_code,                          internal_toks_base); */
        tex_primitive(tex_command,    "errhelp",                        internal_toks_cmd,      error_help_code,                          internal_toks_base);
        tex_primitive(luatex_command, "everybeforepar",                 internal_toks_cmd,      every_before_par_code,                    internal_toks_base);
        tex_primitive(tex_command,    "everycr",                        internal_toks_cmd,      every_cr_code,                            internal_toks_base);
        tex_primitive(tex_command,    "everydisplay",                   internal_toks_cmd,      every_display_code,                       internal_toks_base);
        tex_primitive(etex_command,   "everyeof",                       internal_toks_cmd,      every_eof_code,                           internal_toks_base);
        tex_primitive(tex_command,    "everyhbox",                      internal_toks_cmd,      every_hbox_code,                          internal_toks_base);
        tex_primitive(tex_command,    "everyjob",                       internal_toks_cmd,      every_job_code,                           internal_toks_base);
        tex_primitive(tex_command,    "everymath",                      internal_toks_cmd,      every_math_code,                          internal_toks_base);
        tex_primitive(luatex_command, "everymathatom",                  internal_toks_cmd,      every_math_atom_code,                     internal_toks_base);
        tex_primitive(tex_command,    "everypar",                       internal_toks_cmd,      every_par_code,                           internal_toks_base);
        tex_primitive(luatex_command, "everytab",                       internal_toks_cmd,      every_tab_code,                           internal_toks_base);
        tex_primitive(tex_command,    "everyvbox",                      internal_toks_cmd,      every_vbox_code,                          internal_toks_base);
        tex_primitive(tex_command,    "output",                         internal_toks_cmd,      output_routine_code,                      internal_toks_base);

        /*tex counters (we could omit the int_base here as effectively it is subtracted) */

        tex_primitive(tex_command,    "adjdemerits",                    internal_integer_cmd,   adj_demerits_code,                        internal_integer_base);
        tex_primitive(luatex_command, "adjustspacing",                  internal_integer_cmd,   adjust_spacing_code,                      internal_integer_base);
        tex_primitive(luatex_command, "adjustspacingshrink",            internal_integer_cmd,   adjust_spacing_shrink_code,               internal_integer_base);
        tex_primitive(luatex_command, "adjustspacingstep",              internal_integer_cmd,   adjust_spacing_step_code,                 internal_integer_base);
        tex_primitive(luatex_command, "adjustspacingstretch",           internal_integer_cmd,   adjust_spacing_stretch_code,              internal_integer_base);
     /* tex_primitive(luatex_command, "alignmentcellattr",              internal_integer_cmd,   alignment_cell_attribute_code,            internal_integer_base); */ /* todo */
        tex_primitive(luatex_command, "alignmentcellsource",            internal_integer_cmd,   alignment_cell_source_code,               internal_integer_base);
        tex_primitive(luatex_command, "alignmentwrapsource",            internal_integer_cmd,   alignment_wrap_source_code,               internal_integer_base);
        tex_primitive(luatex_command, "automatichyphenpenalty",         internal_integer_cmd,   automatic_hyphen_penalty_code,            internal_integer_base);
        tex_primitive(luatex_command, "automigrationmode",              internal_integer_cmd,   auto_migration_mode_code,                 internal_integer_base);
        tex_primitive(luatex_command, "autoparagraphmode",              internal_integer_cmd,   auto_paragraph_mode_code,                 internal_integer_base);
        tex_primitive(tex_command,    "binoppenalty",                   internal_integer_cmd,   post_binary_penalty_code,                 internal_integer_base); /*tex For old times sake. */
        tex_primitive(tex_command,    "brokenpenalty",                  internal_integer_cmd,   broken_penalty_code,                      internal_integer_base);
        tex_primitive(luatex_command, "catcodetable",                   internal_integer_cmd,   cat_code_table_code,                      internal_integer_base);
        tex_primitive(tex_command,    "clubpenalty",                    internal_integer_cmd,   club_penalty_code,                        internal_integer_base);
        tex_primitive(tex_command,    "day",                            internal_integer_cmd,   day_code,                                 internal_integer_base);
        tex_primitive(tex_command,    "defaulthyphenchar",              internal_integer_cmd,   default_hyphen_char_code,                 internal_integer_base);
        tex_primitive(tex_command,    "defaultskewchar",                internal_integer_cmd,   default_skew_char_code,                   internal_integer_base);
        tex_primitive(tex_command,    "delimiterfactor",                internal_integer_cmd,   delimiter_factor_code,                    internal_integer_base);
        tex_primitive(luatex_command, "discretionaryoptions",           internal_integer_cmd,   discretionary_options_code,               internal_integer_base);
        tex_primitive(tex_command,    "displaywidowpenalty",            internal_integer_cmd,   display_widow_penalty_code,               internal_integer_base);
        tex_primitive(tex_command,    "doublehyphendemerits",           internal_integer_cmd,   double_hyphen_demerits_code,              internal_integer_base);
        tex_primitive(luatex_command, "doublepenaltymode",              internal_integer_cmd,   double_penalty_mode_code,                 internal_integer_base);
        tex_primitive(tex_command,    "endlinechar",                    internal_integer_cmd,   end_line_char_code,                       internal_integer_base);
        tex_primitive(tex_command,    "errorcontextlines",              internal_integer_cmd,   error_context_lines_code,                 internal_integer_base);
        tex_primitive(tex_command,    "escapechar",                     internal_integer_cmd,   escape_char_code,                         internal_integer_base);
        tex_primitive(luatex_command, "spacechar",                      internal_integer_cmd,   space_char_code,                          internal_integer_base);
        tex_primitive(luatex_command, "eufactor",                       internal_integer_cmd,   eu_factor_code,                           internal_integer_base);
        tex_primitive(luatex_command, "exceptionpenalty",               internal_integer_cmd,   exception_penalty_code,                   internal_integer_base);
        tex_primitive(tex_command,    "exhyphenchar",                   internal_integer_cmd,   ex_hyphen_char_code,                      internal_integer_base);
        tex_primitive(tex_command,    "exhyphenpenalty",                internal_integer_cmd,   ex_hyphen_penalty_code,                   internal_integer_base);
        tex_primitive(luatex_command, "explicithyphenpenalty",          internal_integer_cmd,   explicit_hyphen_penalty_code,             internal_integer_base);
        tex_primitive(tex_command,    "fam",                            internal_integer_cmd,   family_code,                              internal_integer_base);
        tex_primitive(tex_command,    "finalhyphendemerits",            internal_integer_cmd,   final_hyphen_demerits_code,               internal_integer_base);
        tex_primitive(luatex_command, "firstvalidlanguage",             internal_integer_cmd,   first_valid_language_code,                internal_integer_base);
        tex_primitive(tex_command,    "floatingpenalty",                internal_integer_cmd,   floating_penalty_code,                    internal_integer_base);
        tex_primitive(tex_command,    "globaldefs",                     internal_integer_cmd,   global_defs_code,                         internal_integer_base);
     /* tex_primitive(luatex_command, "gluedatafield",                  internal_integer_cmd,   glue_data_code,                           internal_integer_base); */
        tex_primitive(luatex_command, "glyphdatafield",                 internal_integer_cmd,   glyph_data_code,                          internal_integer_base);
        tex_primitive(luatex_command, "glyphoptions",                   internal_integer_cmd,   glyph_options_code,                       internal_integer_base);
        tex_primitive(luatex_command, "glyphscale",                     internal_integer_cmd,   glyph_scale_code,                         internal_integer_base);
        tex_primitive(luatex_command, "glyphscriptfield",               internal_integer_cmd,   glyph_script_code,                        internal_integer_base);
        tex_primitive(luatex_command, "glyphscriptscale",               internal_integer_cmd,   glyph_script_scale_code,                  internal_integer_base);
        tex_primitive(luatex_command, "glyphscriptscriptscale",         internal_integer_cmd,   glyph_scriptscript_scale_code,            internal_integer_base);
        tex_primitive(luatex_command, "glyphstatefield",                internal_integer_cmd,   glyph_state_code,                         internal_integer_base);
        tex_primitive(luatex_command, "glyphtextscale",                 internal_integer_cmd,   glyph_text_scale_code,                    internal_integer_base);
        tex_primitive(luatex_command, "glyphxscale",                    internal_integer_cmd,   glyph_x_scale_code,                       internal_integer_base);
        tex_primitive(luatex_command, "glyphyscale",                    internal_integer_cmd,   glyph_y_scale_code,                       internal_integer_base);
        tex_primitive(luatex_command, "glyphslant",                     internal_integer_cmd,   glyph_slant_code,                         internal_integer_base);
        tex_primitive(luatex_command, "glyphweight",                    internal_integer_cmd,   glyph_weight_code,                        internal_integer_base);
        tex_primitive(tex_command,    "hangafter",                      internal_integer_cmd,   hang_after_code,                          internal_integer_base);
        tex_primitive(tex_command,    "hbadness",                       internal_integer_cmd,   hbadness_code,                            internal_integer_base);
        tex_primitive(tex_command,    "holdinginserts",                 internal_integer_cmd,   holding_inserts_code,                     internal_integer_base);
        tex_primitive(luatex_command, "holdingmigrations",              internal_integer_cmd,   holding_migrations_code,                  internal_integer_base);
        tex_primitive(luatex_command, "hyphenationmode",                internal_integer_cmd,   hyphenation_mode_code,                    internal_integer_base);
        tex_primitive(tex_command,    "hyphenpenalty",                  internal_integer_cmd,   hyphen_penalty_code,                      internal_integer_base);
        tex_primitive(tex_command,    "interlinepenalty",               internal_integer_cmd,   inter_line_penalty_code,                  internal_integer_base);
        tex_primitive(no_command,     "internaldirstate",               internal_integer_cmd,   internal_dir_state_code,                  internal_integer_base);
        tex_primitive(no_command,     "internalmathscale",              internal_integer_cmd,   internal_math_scale_code,                 internal_integer_base);
        tex_primitive(no_command,     "internalmathstyle",              internal_integer_cmd,   internal_math_style_code,                 internal_integer_base);
        tex_primitive(no_command,     "internalparstate",               internal_integer_cmd,   internal_par_state_code,                  internal_integer_base);
        tex_primitive(tex_command,    "language",                       internal_integer_cmd,   language_code,                            internal_integer_base);
        tex_primitive(etex_command,   "lastlinefit",                    internal_integer_cmd,   last_line_fit_code,                       internal_integer_base);
        tex_primitive(tex_command,    "lefthyphenmin",                  internal_integer_cmd,   left_hyphen_min_code,                     internal_integer_base);
        tex_primitive(luatex_command, "linebreakoptional",              internal_integer_cmd,   line_break_optional_code,                 internal_integer_base);
        tex_primitive(luatex_command, "linebreakpasses",                internal_integer_cmd,   line_break_passes_code,                   internal_integer_base);
        tex_primitive(luatex_command, "linebreakchecks",                internal_integer_cmd,   line_break_checks_code,                   internal_integer_base);
        tex_primitive(luatex_command, "linedirection",                  internal_integer_cmd,   line_direction_code,                      internal_integer_base);
        tex_primitive(tex_command,    "linepenalty",                    internal_integer_cmd,   line_penalty_code,                        internal_integer_base);
        tex_primitive(luatex_command, "localbrokenpenalty",             internal_integer_cmd,   local_broken_penalty_code,                internal_integer_base); 
        tex_primitive(luatex_command, "localinterlinepenalty",          internal_integer_cmd,   local_interline_penalty_code,             internal_integer_base); 
        tex_primitive(luatex_command, "localpretolerance",              internal_integer_cmd,   local_pre_tolerance_code,                 internal_integer_base); /* not that useful */
        tex_primitive(luatex_command, "localtolerance",                 internal_integer_cmd,   local_tolerance_code,                     internal_integer_base); /* not that useful */
        tex_primitive(tex_command,    "looseness",                      internal_integer_cmd,   looseness_code,                           internal_integer_base);
        tex_primitive(luatex_command, "luacopyinputnodes",              internal_integer_cmd,   copy_lua_input_nodes_code,                internal_integer_base);
     /* tex_primitive(tex_command,    "mag",                            internal_integer_cmd,   mag_code,                                 internal_integer_base); */ /* backend */
        tex_primitive(luatex_command, "mathbeginclass",                 internal_integer_cmd,   math_begin_class_code,                    internal_integer_base);
        tex_primitive(luatex_command, "mathcheckfencesmode",            internal_integer_cmd,   math_check_fences_mode_code,              internal_integer_base);
        tex_primitive(luatex_command, "mathdictgroup",                  internal_integer_cmd,   math_dict_group_code,                     internal_integer_base);
        tex_primitive(luatex_command, "mathdictproperties",             internal_integer_cmd,   math_dict_properties_code,                internal_integer_base);
        tex_primitive(luatex_command, "mathdirection",                  internal_integer_cmd,   math_direction_code,                      internal_integer_base);
        tex_primitive(luatex_command, "mathdisplaymode",                internal_integer_cmd,   math_display_mode_code,                   internal_integer_base);
        tex_primitive(luatex_command, "mathdisplaypenaltyfactor",       internal_integer_cmd,   math_display_penalty_factor_code,         internal_integer_base);
        tex_primitive(luatex_command, "mathdisplayskipmode",            internal_integer_cmd,   math_display_skip_mode_code,              internal_integer_base);
        tex_primitive(luatex_command, "mathdoublescriptmode",           internal_integer_cmd,   math_double_script_mode_code,             internal_integer_base);
        tex_primitive(luatex_command, "mathendclass",                   internal_integer_cmd,   math_end_class_code,                      internal_integer_base);
        tex_primitive(luatex_command, "matheqnogapstep",                internal_integer_cmd,   math_eqno_gap_step_code,                  internal_integer_base);
        tex_primitive(luatex_command, "mathfontcontrol",                internal_integer_cmd,   math_font_control_code,                   internal_integer_base);
        tex_primitive(luatex_command, "mathgluemode",                   internal_integer_cmd,   math_glue_mode_code,                      internal_integer_base);
        tex_primitive(luatex_command, "mathgroupingmode",               internal_integer_cmd,   math_grouping_mode_code,                  internal_integer_base);
        tex_primitive(luatex_command, "mathinlinepenaltyfactor",        internal_integer_cmd,   math_inline_penalty_factor_code,          internal_integer_base);
        tex_primitive(luatex_command, "mathleftclass",                  internal_integer_cmd,   math_left_class_code,                     internal_integer_base);
        tex_primitive(luatex_command, "mathlimitsmode",                 internal_integer_cmd,   math_limits_mode_code,                    internal_integer_base);
        tex_primitive(luatex_command, "mathnolimitsmode",               internal_integer_cmd,   math_nolimits_mode_code,                  internal_integer_base);
        tex_primitive(luatex_command, "mathpenaltiesmode",              internal_integer_cmd,   math_penalties_mode_code,                 internal_integer_base);
        tex_primitive(luatex_command, "mathpretolerance",               internal_integer_cmd,   math_pre_tolerance_code,                  internal_integer_base);
        tex_primitive(luatex_command, "mathrightclass",                 internal_integer_cmd,   math_right_class_code,                    internal_integer_base);
        tex_primitive(luatex_command, "mathrulesfam",                   internal_integer_cmd,   math_rules_fam_code,                      internal_integer_base);
        tex_primitive(luatex_command, "mathrulesmode",                  internal_integer_cmd,   math_rules_mode_code,                     internal_integer_base);
        tex_primitive(luatex_command, "mathscriptsmode",                internal_integer_cmd,   math_scripts_mode_code,                   internal_integer_base);
        tex_primitive(luatex_command, "mathslackmode",                  internal_integer_cmd,   math_slack_mode_code,                     internal_integer_base);
        tex_primitive(luatex_command, "mathspacingmode",                internal_integer_cmd,   math_spacing_mode_code,                   internal_integer_base); /*tex Inject zero spaces, for tracing */
        tex_primitive(luatex_command, "mathsurroundmode",               internal_integer_cmd,   math_skip_mode_code,                      internal_integer_base);
        tex_primitive(luatex_command, "mathtolerance",                  internal_integer_cmd,   math_tolerance_code,                      internal_integer_base);
        tex_primitive(tex_command,    "maxdeadcycles",                  internal_integer_cmd,   max_dead_cycles_code,                     internal_integer_base);
        tex_primitive(tex_command,    "month",                          internal_integer_cmd,   month_code,                               internal_integer_base);
        tex_primitive(tex_command,    "newlinechar",                    internal_integer_cmd,   new_line_char_code,                       internal_integer_base);
        tex_primitive(luatex_command, "normalizelinemode",              internal_integer_cmd,   normalize_line_mode_code,                 internal_integer_base);
        tex_primitive(luatex_command, "normalizeparmode",               internal_integer_cmd,   normalize_par_mode_code,                  internal_integer_base);
        tex_primitive(luatex_command, "nospaces",                       internal_integer_cmd,   no_spaces_code,                           internal_integer_base);
        tex_primitive(luatex_command, "orphanpenalty",                  internal_integer_cmd,   orphan_penalty_code,                      internal_integer_base);
        tex_primitive(luatex_command, "toddlerpenalty",                 internal_integer_cmd,   toddler_penalty_code,                     internal_integer_base);
        tex_primitive(luatex_command, "outputbox",                      internal_integer_cmd,   output_box_code,                          internal_integer_base);
        tex_primitive(tex_command,    "outputpenalty",                  internal_integer_cmd,   output_penalty_code,                      internal_integer_base);
        tex_primitive(luatex_command, "overloadmode",                   internal_integer_cmd,   overload_mode_code,                       internal_integer_base);
     /* tex_primitive(luatex_command, "pageboundarypenalty",            internal_integer_cmd,   page_boundary_penalty_code,               internal_integer_base); */
        tex_primitive(luatex_command, "parametermode",                  internal_integer_cmd,   parameter_mode_code,                      internal_integer_base);
        tex_primitive(luatex_command, "pardirection",                   internal_integer_cmd,   par_direction_code,                       internal_integer_base);
        tex_primitive(tex_command,    "pausing",                        internal_integer_cmd,   pausing_code,                             internal_integer_base);
        tex_primitive(tex_command,    "postdisplaypenalty",             internal_integer_cmd,   post_display_penalty_code,                internal_integer_base);
        tex_primitive(luatex_command, "postinlinepenalty",              internal_integer_cmd,   post_inline_penalty_code,                 internal_integer_base);
        tex_primitive(luatex_command, "postshortinlinepenalty",         internal_integer_cmd,   post_short_inline_penalty_code,           internal_integer_base);
        tex_primitive(luatex_command, "prebinoppenalty",                internal_integer_cmd,   pre_binary_penalty_code,                  internal_integer_base); /*tex For old times sake. */
        tex_primitive(etex_command,   "predisplaydirection",            internal_integer_cmd,   pre_display_direction_code,               internal_integer_base);
        tex_primitive(luatex_command, "predisplaygapfactor",            internal_integer_cmd,   math_pre_display_gap_factor_code,         internal_integer_base);
        tex_primitive(tex_command,    "predisplaypenalty",              internal_integer_cmd,   pre_display_penalty_code,                 internal_integer_base);
        tex_primitive(luatex_command, "preinlinepenalty",               internal_integer_cmd,   pre_inline_penalty_code,                  internal_integer_base);
        tex_primitive(luatex_command, "prerelpenalty",                  internal_integer_cmd,   pre_relation_penalty_code,                internal_integer_base); /*tex For old times sake. */
        tex_primitive(luatex_command, "preshortinlinepenalty",          internal_integer_cmd,   pre_short_inline_penalty_code,            internal_integer_base);
        tex_primitive(tex_command,    "pretolerance",                   internal_integer_cmd,   pre_tolerance_code,                       internal_integer_base);
        tex_primitive(luatex_command, "protrudechars",                  internal_integer_cmd,   protrude_chars_code,                      internal_integer_base);
        tex_primitive(tex_command,    "relpenalty",                     internal_integer_cmd,   post_relation_penalty_code,               internal_integer_base); /*tex For old times sake. */
        tex_primitive(tex_command,    "righthyphenmin",                 internal_integer_cmd,   right_hyphen_min_code,                    internal_integer_base);
        tex_primitive(etex_command,   "savinghyphcodes",                internal_integer_cmd,   saving_hyph_codes_code,                   internal_integer_base);
        tex_primitive(etex_command,   "savingvdiscards",                internal_integer_cmd,   saving_vdiscards_code,                    internal_integer_base);
        tex_primitive(luatex_command, "scriptspacebeforefactor",        internal_integer_cmd,   script_space_before_factor_code,          internal_integer_base);
        tex_primitive(luatex_command, "scriptspacebetweenfactor",       internal_integer_cmd,   script_space_between_factor_code,         internal_integer_base);
        tex_primitive(luatex_command, "scriptspaceafterfactor",         internal_integer_cmd,   script_space_after_factor_code,           internal_integer_base);
        tex_primitive(luatex_command, "setfontid",                      internal_integer_cmd,   font_code,                                internal_integer_base);
        tex_primitive(tex_command,    "setlanguage",                    internal_integer_cmd,   language_code,                            internal_integer_base); /* compatibility */
        tex_primitive(luatex_command, "shapingpenaltiesmode",           internal_integer_cmd,   shaping_penalties_mode_code,              internal_integer_base);
        tex_primitive(luatex_command, "shapingpenalty",                 internal_integer_cmd,   shaping_penalty_code,                     internal_integer_base);
        tex_primitive(luatex_command, "shortinlineorphanpenalty",       internal_integer_cmd,   short_inline_orphan_penalty_code,         internal_integer_base);
        tex_primitive(tex_command,    "showboxbreadth",                 internal_integer_cmd,   show_box_breadth_code,                    internal_integer_base);
        tex_primitive(tex_command,    "showboxdepth",                   internal_integer_cmd,   show_box_depth_code,                      internal_integer_base);
        tex_primitive(tex_command,    "shownodedetails",                internal_integer_cmd,   show_node_details_code,                   internal_integer_base);
        tex_primitive(luatex_command, "singlelinepenalty",              internal_integer_cmd,   single_line_penalty_code,                 internal_integer_base);
        tex_primitive(luatex_command, "lefttwindemerits",               internal_integer_cmd,   left_twin_demerits_code,                  internal_integer_base);
        tex_primitive(luatex_command, "righttwindemerits",              internal_integer_cmd,   right_twin_demerits_code,                 internal_integer_base);
        tex_primitive(luatex_command, "spacefactormode",                internal_integer_cmd,   space_factor_mode,                        internal_integer_base);
        tex_primitive(luatex_command, "spacefactorshrinklimit",         internal_integer_cmd,   space_factor_shrink_limit_code,           internal_integer_base);
        tex_primitive(luatex_command, "spacefactorstretchlimit",        internal_integer_cmd,   space_factor_stretch_limit_code,          internal_integer_base);
        tex_primitive(luatex_command, "spacefactoroverload",            internal_integer_cmd,   space_factor_overload_code,               internal_integer_base);
        tex_primitive(luatex_command, "boxlimitmode",                   internal_integer_cmd,   box_limit_mode_code,                      internal_integer_base);
        tex_primitive(luatex_command, "supmarkmode",                    internal_integer_cmd,   sup_mark_mode_code,                       internal_integer_base);
        tex_primitive(luatex_command, "textdirection",                  internal_integer_cmd,   text_direction_code,                      internal_integer_base);
        tex_primitive(tex_command,    "time",                           internal_integer_cmd,   time_code,                                internal_integer_base);
        tex_primitive(tex_command,    "tolerance",                      internal_integer_cmd,   tolerance_code,                           internal_integer_base);
        tex_primitive(luatex_command, "tracingadjusts",                 internal_integer_cmd,   tracing_adjusts_code,                     internal_integer_base);
        tex_primitive(luatex_command, "tracingalignments",              internal_integer_cmd,   tracing_alignments_code,                  internal_integer_base);
        tex_primitive(etex_command,   "tracingassigns",                 internal_integer_cmd,   tracing_assigns_code,                     internal_integer_base);
        tex_primitive(tex_command,    "tracingcommands",                internal_integer_cmd,   tracing_commands_code,                    internal_integer_base);
        tex_primitive(luatex_command, "tracingexpressions",             internal_integer_cmd,   tracing_expressions_code,                 internal_integer_base);
        tex_primitive(luatex_command, "tracingfitness",                 internal_integer_cmd,   tracing_fitness_code,                     internal_integer_base);
     /* tex_primitive(luatex_command, "tracingfonts",                   internal_integer_cmd,   tracing_fonts_code,                       internal_integer_base); */
        tex_primitive(luatex_command, "tracingfullboxes",               internal_integer_cmd,   tracing_full_boxes_code,                  internal_integer_base);
        tex_primitive(etex_command,   "tracinggroups",                  internal_integer_cmd,   tracing_groups_code,                      internal_integer_base);
        tex_primitive(luatex_command, "tracinghyphenation",             internal_integer_cmd,   tracing_hyphenation_code,                 internal_integer_base);
        tex_primitive(etex_command,   "tracingifs",                     internal_integer_cmd,   tracing_ifs_code,                         internal_integer_base);
        tex_primitive(luatex_command, "tracinginserts",                 internal_integer_cmd,   tracing_inserts_code,                     internal_integer_base);
        tex_primitive(luatex_command, "tracinglevels",                  internal_integer_cmd,   tracing_levels_code,                      internal_integer_base);
        tex_primitive(luatex_command, "tracinglists",                   internal_integer_cmd,   tracing_lists_code,                       internal_integer_base);
        tex_primitive(tex_command,    "tracingloners",                  internal_integer_cmd,   tracing_loners_code,                      internal_integer_base);
        tex_primitive(tex_command,    "tracinglostchars",               internal_integer_cmd,   tracing_lost_chars_code,                  internal_integer_base);
        tex_primitive(tex_command,    "tracingmacros",                  internal_integer_cmd,   tracing_macros_code,                      internal_integer_base);
        tex_primitive(luatex_command, "tracingmarks",                   internal_integer_cmd,   tracing_marks_code,                       internal_integer_base);
        tex_primitive(luatex_command, "tracingmath",                    internal_integer_cmd,   tracing_math_code,                        internal_integer_base);
        tex_primitive(etex_command,   "tracingnesting",                 internal_integer_cmd,   tracing_nesting_code,                     internal_integer_base);
        tex_primitive(luatex_command, "tracingnodes",                   internal_integer_cmd,   tracing_nodes_code,                       internal_integer_base);
        tex_primitive(tex_command,    "tracingonline",                  internal_integer_cmd,   tracing_online_code,                      internal_integer_base);
        tex_primitive(tex_command,    "tracingoutput",                  internal_integer_cmd,   tracing_output_code,                      internal_integer_base);
        tex_primitive(tex_command,    "tracingpages",                   internal_integer_cmd,   tracing_pages_code,                       internal_integer_base);
        tex_primitive(tex_command,    "tracingparagraphs",              internal_integer_cmd,   tracing_paragraphs_code,                  internal_integer_base);
        tex_primitive(luatex_command, "tracingpasses",                  internal_integer_cmd,   tracing_passes_code,                      internal_integer_base);
        tex_primitive(luatex_command, "tracingpenalties",               internal_integer_cmd,   tracing_penalties_code,                   internal_integer_base);
        tex_primitive(tex_command,    "tracingrestores",                internal_integer_cmd,   tracing_restores_code,                    internal_integer_base);
        tex_primitive(tex_command,    "tracingstats",                   internal_integer_cmd,   tracing_stats_code,                       internal_integer_base); /* obsolete */
        tex_primitive(tex_command,    "uchyph",                         internal_integer_cmd,   uc_hyph_code,                             internal_integer_base); /* obsolete, not needed */
        tex_primitive(luatex_command, "variablefam",                    internal_integer_cmd,   variable_family_code,                     internal_integer_base); /* obsolete, not used */
        tex_primitive(tex_command,    "vbadness",                       internal_integer_cmd,   vbadness_code,                            internal_integer_base);
        tex_primitive(tex_command,    "widowpenalty",                   internal_integer_cmd,   widow_penalty_code,                       internal_integer_base);
        tex_primitive(tex_command,    "year",                           internal_integer_cmd,   year_code,                                internal_integer_base);

        /*tex dimensions */

        tex_primitive(tex_command,    "boxmaxdepth",                    internal_dimension_cmd, box_max_depth_code,                       internal_dimension_base);
        tex_primitive(tex_command,    "delimitershortfall",             internal_dimension_cmd, delimiter_shortfall_code,                 internal_dimension_base);
        tex_primitive(tex_command,    "displayindent",                  internal_dimension_cmd, display_indent_code,                      internal_dimension_base);
        tex_primitive(tex_command,    "displaywidth",                   internal_dimension_cmd, display_width_code,                       internal_dimension_base);
        tex_primitive(tex_command,    "emergencyextrastretch",          internal_dimension_cmd, emergency_extra_stretch_code,             internal_dimension_base);
        tex_primitive(tex_command,    "emergencystretch",               internal_dimension_cmd, emergency_stretch_code,                   internal_dimension_base);
        tex_primitive(luatex_command, "glyphxoffset",                   internal_dimension_cmd, glyph_x_offset_code,                      internal_dimension_base);
        tex_primitive(luatex_command, "glyphyoffset",                   internal_dimension_cmd, glyph_y_offset_code,                      internal_dimension_base);
        tex_primitive(tex_command,    "hangindent",                     internal_dimension_cmd, hang_indent_code,                         internal_dimension_base);
        tex_primitive(tex_command,    "hfuzz",                          internal_dimension_cmd, hfuzz_code,                               internal_dimension_base);
     /* tex_primitive(tex_command,    "hoffset",                        internal_dimension_cmd, h_offset_code,                            internal_dimension_base); */ /* backend */
        tex_primitive(tex_command,    "hsize",                          internal_dimension_cmd, hsize_code,                               internal_dimension_base);
        tex_primitive(luatex_command, "ignoredepthcriterion",           internal_dimension_cmd, ignore_depth_criterion_code,              internal_dimension_base); /* mostly for myself, tutorials etc */
        tex_primitive(tex_command,    "lineskiplimit",                  internal_dimension_cmd, line_skip_limit_code,                     internal_dimension_base);
        tex_primitive(tex_command,    "mathsurround",                   internal_dimension_cmd, math_surround_code,                       internal_dimension_base);
        tex_primitive(tex_command,    "maxdepth",                       internal_dimension_cmd, max_depth_code,                           internal_dimension_base);
        tex_primitive(tex_command,    "nulldelimiterspace",             internal_dimension_cmd, null_delimiter_space_code,                internal_dimension_base);
        tex_primitive(tex_command,    "overfullrule",                   internal_dimension_cmd, overfull_rule_code,                       internal_dimension_base);
        tex_primitive(luatex_command, "pageextragoal",                  internal_dimension_cmd, page_extra_goal_code,                     internal_dimension_base);
        tex_primitive(tex_command,    "parindent",                      internal_dimension_cmd, par_indent_code,                          internal_dimension_base);
        tex_primitive(tex_command,    "predisplaysize",                 internal_dimension_cmd, pre_display_size_code,                    internal_dimension_base);
        tex_primitive(luatex_command, "pxdimen",                        internal_dimension_cmd, px_dimension_code,                        internal_dimension_base);
        tex_primitive(tex_command,    "scriptspace",                    internal_dimension_cmd, script_space_code,                        internal_dimension_base);
        tex_primitive(luatex_command, "shortinlinemaththreshold",       internal_dimension_cmd, short_inline_math_threshold_code,         internal_dimension_base);
        tex_primitive(tex_command,    "splitmaxdepth",                  internal_dimension_cmd, split_max_depth_code,                     internal_dimension_base);
        tex_primitive(luatex_command, "tabsize",                        internal_dimension_cmd, tab_size_code,                            internal_dimension_base);
        tex_primitive(tex_command,    "vfuzz",                          internal_dimension_cmd, vfuzz_code,                               internal_dimension_base);
     /* tex_primitive(tex_command,    "voffset",                        internal_dimension_cmd, v_offset_code,                            internal_dimension_base); */ /* backend */
        tex_primitive(tex_command,    "vsize",                          internal_dimension_cmd, vsize_code,                               internal_dimension_base);

        /*tex Probably never used with \UNICODE\ omnipresent now: */

        tex_primitive(tex_command,    "accent",                         accent_cmd,             normal_code,                              0);

        /*tex These three times two can go in one cmd: */

        tex_primitive(tex_command,    "advance",                        arithmic_cmd,           advance_code,                             0);
        tex_primitive(luatex_command, "advanceby",                      arithmic_cmd,           advance_by_code,                          0);
     /* tex_primitive(luatex_command, "advancebyminusone",              arithmic_cmd,           advance_by_minus_one_code,                0); */
     /* tex_primitive(luatex_command, "advancebyplusone",               arithmic_cmd,           advance_by_plus_one_code,                 0); */
        tex_primitive(tex_command,    "divide",                         arithmic_cmd,           divide_code,                              0);
        tex_primitive(luatex_command, "divideby",                       arithmic_cmd,           divide_by_code,                           0);
        tex_primitive(luatex_command, "rdivide",                        arithmic_cmd,           r_divide_code,                            0);
        tex_primitive(luatex_command, "rdivideby",                      arithmic_cmd,           r_divide_by_code,                         0);
        tex_primitive(luatex_command, "edivide",                        arithmic_cmd,           e_divide_code,                            0);
        tex_primitive(luatex_command, "edivideby",                      arithmic_cmd,           e_divide_by_code,                         0);
        tex_primitive(tex_command,    "multiply",                       arithmic_cmd,           multiply_code,                            0);
        tex_primitive(luatex_command, "multiplyby",                     arithmic_cmd,           multiply_by_code,                         0);

        /*tex We combined the after thingies into one category:*/

        tex_primitive(luatex_command, "afterassigned",                  after_something_cmd,    after_assigned_code,                      0);
        tex_primitive(tex_command,    "afterassignment",                after_something_cmd,    after_assignment_code,                    0);
        tex_primitive(tex_command,    "aftergroup",                     after_something_cmd,    after_group_code,                         0);
        tex_primitive(luatex_command, "aftergrouped",                   after_something_cmd,    after_grouped_code,                       0);
        tex_primitive(luatex_command, "atendofgroup",                   after_something_cmd,    at_end_of_group_code,                     0);
        tex_primitive(luatex_command, "atendofgrouped",                 after_something_cmd,    at_end_of_grouped_code,                   0);
        tex_primitive(luatex_command, "atendoffile",                    after_something_cmd,    at_end_of_file_code,                      0);
        tex_primitive(luatex_command, "atendoffiled",                   after_something_cmd,    at_end_of_filed_code,                     0);

        tex_primitive(tex_command,    "begingroup",                     begin_group_cmd,        semi_simple_group_code,                   0);
        tex_primitive(luatex_command, "beginmathgroup",                 begin_group_cmd,        math_simple_group_code,                   0);
        tex_primitive(luatex_command, "beginsimplegroup",               begin_group_cmd,        also_simple_group_code,                   0);

        tex_primitive(luatex_command, "boundary",                       boundary_cmd,           user_boundary,                            0);
        tex_primitive(luatex_command, "luaboundary",                    boundary_cmd,           lua_boundary,                             0);
        tex_primitive(luatex_command, "mathboundary",                   boundary_cmd,           math_boundary,                            0);
        tex_primitive(luatex_command, "noboundary",                     boundary_cmd,           cancel_boundary,                          0);
        tex_primitive(luatex_command, "optionalboundary",               boundary_cmd,           optional_boundary,                        0);
        tex_primitive(luatex_command, "pageboundary",                   boundary_cmd,           page_boundary,                            0);
     /* tex_primitive(luatex_command, "parboundary",                    boundary_cmd,           par_boundary,                             0); */
        tex_primitive(luatex_command, "protrusionboundary",             boundary_cmd,           protrusion_boundary,                      0);
        tex_primitive(luatex_command, "wordboundary",                   boundary_cmd,           word_boundary,                            0);

        tex_primitive(luatex_command, "hpenalty",                       penalty_cmd,            h_penalty_code,                           0);
        tex_primitive(tex_command,    "penalty",                        penalty_cmd,            normal_penalty_code,                      0);
        tex_primitive(luatex_command, "vpenalty",                       penalty_cmd,            v_penalty_code,                           0);

        tex_primitive(tex_command,    "char",                           char_number_cmd,        char_number_code,                         0);
        tex_primitive(luatex_command, "glyph",                          char_number_cmd,        glyph_number_code,                        0);

        tex_primitive(luatex_command, "etoks",                          combine_toks_cmd,       expanded_toks_code,                       0);
        tex_primitive(luatex_command, "etoksapp",                       combine_toks_cmd,       append_expanded_toks_code,                0);
        tex_primitive(luatex_command, "etokspre",                       combine_toks_cmd,       prepend_expanded_toks_code,               0);
        tex_primitive(luatex_command, "gtoksapp",                       combine_toks_cmd,       global_append_toks_code,                  0);
        tex_primitive(luatex_command, "gtokspre",                       combine_toks_cmd,       global_prepend_toks_code,                 0);
        tex_primitive(luatex_command, "toksapp",                        combine_toks_cmd,       append_toks_code,                         0);
        tex_primitive(luatex_command, "tokspre",                        combine_toks_cmd,       prepend_toks_code,                        0);
        tex_primitive(luatex_command, "xtoks",                          combine_toks_cmd,       global_expanded_toks_code,                0);
        tex_primitive(luatex_command, "xtoksapp",                       combine_toks_cmd,       global_append_expanded_toks_code,         0);
        tex_primitive(luatex_command, "xtokspre",                       combine_toks_cmd,       global_prepend_expanded_toks_code,        0);

        tex_primitive(luatex_command, "begincsname",                    cs_name_cmd,            begin_cs_name_code,                       0);
        tex_primitive(tex_command,    "csname",                         cs_name_cmd,            cs_name_code,                             0);
        tex_primitive(luatex_command, "futurecsname",                   cs_name_cmd,            future_cs_name_code,                      0); /* Okay but rare applications (less tracing). */
        tex_primitive(luatex_command, "lastnamedcs",                    cs_name_cmd,            last_named_cs_code,                       0);

        tex_primitive(tex_command,    "endcsname",                      end_cs_name_cmd,        normal_code,                              0);

        /* set_font_id could use def_font_cmd */

        tex_primitive(tex_command,    "font",                           define_font_cmd,        normal_code,                              0);

        tex_primitive(tex_command,    "delimiter",                      delimiter_number_cmd,   math_delimiter_code,                      0);
        tex_primitive(luatex_command, "Udelimiter",                     delimiter_number_cmd,   math_udelimiter_code,                     0);

        /*tex We don't combine these because they have different runners and mode handling. */

        tex_primitive(tex_command,    " ",                              explicit_space_cmd,     normal_code,                              0); 
        tex_primitive(luatex_command, "explicitspace",                  explicit_space_cmd,     normal_code,                              0); 

        tex_primitive(tex_command,    "/",                              italic_correction_cmd,  italic_correction_code,                   0); 
        tex_primitive(luatex_command, "explicititaliccorrection",       italic_correction_cmd,  italic_correction_code,                   0); 
        tex_primitive(luatex_command, "forcedleftcorrection",           italic_correction_cmd,  left_correction_code,                     0); 
        tex_primitive(luatex_command, "forcedrightcorrection",          italic_correction_cmd,  right_correction_code,                    0); 

        tex_primitive(luatex_command, "expand",                         expand_after_cmd,       expand_code,                              0);
        tex_primitive(luatex_command, "expandactive",                   expand_after_cmd,       expand_active_code,                       0);
        tex_primitive(tex_command,    "expandafter",                    expand_after_cmd,       expand_after_code,                        0);
     /* tex_primitive(luatex_command, "expandafterfi",                  expand_after_cmd,       expand_after_fi_code,                     0); */ /* keep as reference */
        tex_primitive(luatex_command, "expandafterpars",                expand_after_cmd,       expand_after_pars_code,                   0);
        tex_primitive(luatex_command, "expandafterspaces",              expand_after_cmd,       expand_after_spaces_code,                 0);
     /* tex_primitive(luatex_command, "expandafterthree",               expand_after_cmd,       expand_after_3_code,                      0); */ /* Yes or no. */
     /* tex_primitive(luatex_command, "expandaftertwo",                 expand_after_cmd,       expand_after_2_code,                      0); */ /* Yes or no. */
        tex_primitive(luatex_command, "expandcstoken",                  expand_after_cmd,       expand_cs_token_code,                     0);
        tex_primitive(luatex_command, "expandedafter",                  expand_after_cmd,       expand_after_toks_code,                   0);
        tex_primitive(luatex_command, "expandparameter",                expand_after_cmd,       expand_parameter_code,                    0);
        tex_primitive(luatex_command, "expandtoken",                    expand_after_cmd,       expand_token_code,                        0);
        tex_primitive(luatex_command, "expandtoks",                     expand_after_cmd,       expand_toks_code,                         0);
        tex_primitive(luatex_command, "futureexpand",                   expand_after_cmd,       future_expand_code,                       0);
        tex_primitive(luatex_command, "futureexpandis",                 expand_after_cmd,       future_expand_is_code,                    0);
        tex_primitive(luatex_command, "futureexpandisap",               expand_after_cmd,       future_expand_is_ap_code,                 0);
        tex_primitive(luatex_command, "semiexpand",                     expand_after_cmd,       expand_semi_code,                         0);
        tex_primitive(etex_command,   "unless",                         expand_after_cmd,       expand_unless_code,                       0);

        tex_primitive(luatex_command, "ignorearguments",                ignore_something_cmd,   ignore_argument_code,                     0);
        tex_primitive(luatex_command, "ignorenestedupto",               ignore_something_cmd,   ignore_nested_upto_code,                  0);
        tex_primitive(luatex_command, "ignorepars",                     ignore_something_cmd,   ignore_par_code,                          0);
        tex_primitive(tex_command,    "ignorespaces",                   ignore_something_cmd,   ignore_space_code,                        0);
        tex_primitive(luatex_command, "ignoreupto",                     ignore_something_cmd,   ignore_upto_code,                         0);
        tex_primitive(luatex_command, "ignorerest",                     ignore_something_cmd,   ignore_rest_code,                         0);

        tex_primitive(tex_command,    "endinput",                       input_cmd,              end_of_input_code,                        0);
        tex_primitive(tex_command,    "input",                          input_cmd,              normal_input_code,                        0);
        tex_primitive(tex_command,    "eofinput",                       input_cmd,              eof_input_code,                           0);
        tex_primitive(luatex_command, "quitloop",                       input_cmd,              quit_loop_code,                           0);
        tex_primitive(luatex_command, "quitloopnow",                    input_cmd,              quit_loop_now_code,                       0);
     /* tex_primitive(luatex_command, "quitfinow",                      input_cmd,              quit_fi_now_code,                         0); */ /*tex only for performance testing */
        tex_primitive(luatex_command, "retokenized",                    input_cmd,              retokenized_code,                         0);
        tex_primitive(luatex_command, "scantextokens",                  input_cmd,              tex_token_input_code,                     0);
        tex_primitive(etex_command,   "scantokens",                     input_cmd,              token_input_code,                         0);
        tex_primitive(luatex_command, "tokenized",                      input_cmd,              tokenized_code,                           0);

        tex_primitive(tex_command,    "insert",                         insert_cmd,             normal_code,                              0);

        tex_primitive(luatex_command, "luabytecodecall",                lua_function_call_cmd,  lua_bytecode_call_code,                   0);
        tex_primitive(luatex_command, "luafunctioncall",                lua_function_call_cmd,  lua_function_call_code,                   0);

        tex_primitive(luatex_command, "clearmarks",                     mark_cmd,               clear_marks_code,                         0);
        tex_primitive(luatex_command, "flushmarks",                     mark_cmd,               flush_marks_code,                         0);
        tex_primitive(tex_command,    "mark",                           mark_cmd,               set_mark_code,                            0);
        tex_primitive(etex_command,   "marks",                          mark_cmd,               set_marks_code,                           0);

        tex_primitive(tex_command,    "mathaccent",                     math_accent_cmd,        math_accent_code,                         0);
        tex_primitive(luatex_command, "Umathaccent",                    math_accent_cmd,        math_uaccent_code,                        0);

        tex_primitive(tex_command,    "mathchar",                       math_char_number_cmd,   math_char_number_code,                    0);
        tex_primitive(luatex_command, "Umathchar",                      math_char_number_cmd,   math_xchar_number_code,                   0);
        tex_primitive(luatex_command, "mathclass",                      math_char_number_cmd,   math_class_number_code,                   0);
        tex_primitive(luatex_command, "mathdictionary",                 math_char_number_cmd,   math_dictionary_number_code,              0);
        tex_primitive(luatex_command, "nomathchar",                     math_char_number_cmd,   math_char_ignore_code,                    0);

        tex_primitive(tex_command,    "mathchoice",                     math_choice_cmd,        math_choice_code,                         0);
        tex_primitive(luatex_command, "mathdiscretionary",              math_choice_cmd,        math_discretionary_code,                  0);
        tex_primitive(luatex_command, "mathstack",                      math_choice_cmd,        math_stack_code,                          0);

        tex_primitive(tex_command,    "noexpand",                       no_expand_cmd,          normal_code,                              0);

        tex_primitive(tex_command,    "radical",                        math_radical_cmd,       normal_radical_subtype,                   0);
        tex_primitive(luatex_command, "Udelimited",                     math_radical_cmd,       delimited_radical_subtype,                0);
        tex_primitive(luatex_command, "Udelimiterover",                 math_radical_cmd,       delimiter_over_radical_subtype,           0);
        tex_primitive(luatex_command, "Udelimiterunder",                math_radical_cmd,       delimiter_under_radical_subtype,          0);
        tex_primitive(luatex_command, "Uhextensible",                   math_radical_cmd,       h_extensible_radical_subtype,             0);
        tex_primitive(luatex_command, "Uoverdelimiter",                 math_radical_cmd,       over_delimiter_radical_subtype,           0);
        tex_primitive(luatex_command, "Uradical",                       math_radical_cmd,       radical_radical_subtype,                  0);
        tex_primitive(luatex_command, "Uroot",                          math_radical_cmd,       root_radical_subtype,                     0);
        tex_primitive(luatex_command, "Urooted",                        math_radical_cmd,       rooted_radical_subtype,                   0);
        tex_primitive(luatex_command, "Uunderdelimiter",                math_radical_cmd,       under_delimiter_radical_subtype,          0);

        tex_primitive(tex_command,    "setbox",                         set_box_cmd,            normal_code,                              0);

        /*tex
            Instead of |set_(e)tex_shape_cmd| we use |set_specification_cmd| because since \ETEX\
            it no longer relates to par shapes only. ALso, because there are nodes involved, that
            themselves have a different implementation, it is less confusing.
        */

        tex_primitive(etex_command,   "clubpenalties",                  specification_cmd,      club_penalties_code,                      internal_specification_base);
        tex_primitive(etex_command,   "displaywidowpenalties",          specification_cmd,      display_widow_penalties_code,             internal_specification_base);
        tex_primitive(etex_command,   "interlinepenalties",             specification_cmd,      inter_line_penalties_code,                internal_specification_base);
        tex_primitive(luatex_command, "mathbackwardpenalties",          specification_cmd,      math_backward_penalties_code,             internal_specification_base);
        tex_primitive(luatex_command, "mathforwardpenalties",           specification_cmd,      math_forward_penalties_code,              internal_specification_base);
        tex_primitive(luatex_command, "orphanpenalties",                specification_cmd,      orphan_penalties_code,                    internal_specification_base);
        tex_primitive(luatex_command, "parpasses",                      specification_cmd,      par_passes_code,                          internal_specification_base);
        tex_primitive(tex_command,    "parshape",                       specification_cmd,      par_shape_code,                           internal_specification_base);
        tex_primitive(etex_command,   "widowpenalties",                 specification_cmd,      widow_penalties_code,                     internal_specification_base);
        tex_primitive(luatex_command, "brokenpenalties",                specification_cmd,      broken_penalties_code,                    internal_specification_base);
        tex_primitive(luatex_command, "fitnessdemerits",                specification_cmd,      fitness_demerits_code,                    internal_specification_base);

        tex_primitive(etex_command,   "detokenize",                     the_cmd,                detokenize_code,                          0); /* maybe convert_cmd */
        tex_primitive(luatex_command, "expandeddetokenize",             the_cmd,                expanded_detokenize_code,                 0); /* maybe convert_cmd */
        tex_primitive(luatex_command, "protecteddetokenize",            the_cmd,                protected_detokenize_code,                0); /* maybe convert_cmd */
        tex_primitive(luatex_command, "protectedexpandeddetokenize",    the_cmd,                protected_expanded_detokenize_code,       0); /* maybe convert_cmd */
        tex_primitive(tex_command,    "the",                            the_cmd,                the_code,                                 0);
        tex_primitive(luatex_command, "thewithoutunit",                 the_cmd,                the_without_unit_code,                    0);
     /* tex_primitive(luatex_command, "thewithproperty",                the_cmd,                the_with_property_code,                   0); */ /* replaced by value functions */
        tex_primitive(etex_command,   "unexpanded",                     the_cmd,                unexpanded_code,                          0); /* maybe convert_cmd */

        tex_primitive(tex_command,    "botmark",                        get_mark_cmd,           bot_mark_code,                            0); /* \botmarks        0 */
        tex_primitive(etex_command,   "botmarks",                       get_mark_cmd,           bot_marks_code,                           0);
        tex_primitive(luatex_command, "currentmarks",                   get_mark_cmd,           current_marks_code,                       0);
        tex_primitive(tex_command,    "firstmark",                      get_mark_cmd,           first_mark_code,                          0); /* \firstmarks      0 */
        tex_primitive(etex_command,   "firstmarks",                     get_mark_cmd,           first_marks_code,                         0);
        tex_primitive(tex_command,    "splitbotmark",                   get_mark_cmd,           split_bot_mark_code,                      0); /* \splitbotmarks   0 */
        tex_primitive(etex_command,   "splitbotmarks",                  get_mark_cmd,           split_bot_marks_code,                     0);
        tex_primitive(tex_command,    "splitfirstmark",                 get_mark_cmd,           split_first_mark_code,                    0); /* \splitfirstmarks 0 */
        tex_primitive(etex_command,   "splitfirstmarks",                get_mark_cmd,           split_first_marks_code,                   0);
        tex_primitive(tex_command,    "topmark",                        get_mark_cmd,           top_mark_code,                            0); /* \topmarks        0 */
        tex_primitive(etex_command,   "topmarks",                       get_mark_cmd,           top_marks_code,                           0);

        tex_primitive(tex_command,    "vadjust",                        vadjust_cmd,            normal_code,                              0);

        tex_primitive(tex_command,    "halign",                         halign_cmd,             normal_code,                              0);
        tex_primitive(tex_command,    "valign",                         valign_cmd,             normal_code,                              0);

        tex_primitive(tex_command,    "vcenter",                        vcenter_cmd,            normal_code,                              0);

        /* todo rule codes of nodes, so empty will move */

        tex_primitive(luatex_command, "novrule",                        vrule_cmd,              empty_rule_code,                          0);
        tex_primitive(luatex_command, "srule",                          vrule_cmd,              strut_rule_code,                          0);
        tex_primitive(luatex_command, "virtualvrule",                   vrule_cmd,              virtual_rule_code,                        0);
        tex_primitive(tex_command,    "vrule",                          vrule_cmd,              normal_rule_code,                         0);

        tex_primitive(tex_command,    "hrule",                          hrule_cmd,              normal_rule_code,                         0);
        tex_primitive(luatex_command, "nohrule",                        hrule_cmd,              empty_rule_code,                          0);
        tex_primitive(luatex_command, "virtualhrule",                   hrule_cmd,              virtual_rule_code,                        0);

        tex_primitive(luatex_command, "attribute",                      register_cmd,           attribute_val_level,                      0);
        tex_primitive(tex_command,    "count",                          register_cmd,           integer_val_level,                        0);
        tex_primitive(tex_command,    "dimen",                          register_cmd,           dimension_val_level,                      0);
        tex_primitive(luatex_command, "float",                          register_cmd,           posit_val_level,                          0);
        tex_primitive(tex_command,    "muskip",                         register_cmd,           muglue_val_level,                         0);
        tex_primitive(tex_command,    "skip",                           register_cmd,           glue_val_level,                           0);
        tex_primitive(tex_command,    "toks",                           register_cmd,           token_val_level,                          0);

        tex_primitive(luatex_command, "insertmode",                     auxiliary_cmd,          insert_mode_code,                         0);
        tex_primitive(etex_command,   "interactionmode",                auxiliary_cmd,          interaction_mode_code,                    0);
        tex_primitive(tex_command,    "prevdepth",                      auxiliary_cmd,          prev_depth_code,                          0);
        tex_primitive(tex_command,    "prevgraf",                       auxiliary_cmd,          prev_graf_code,                           0);
        tex_primitive(tex_command,    "spacefactor",                    auxiliary_cmd,          space_factor_code,                        0);

        tex_primitive(tex_command,    "deadcycles",                     page_property_cmd,      dead_cycles_code,                         0);
        tex_primitive(luatex_command, "insertdepth",                    page_property_cmd,      insert_depth_code,                        0);
        tex_primitive(luatex_command, "insertdistance",                 page_property_cmd,      insert_distance_code,                     0);
        tex_primitive(luatex_command, "insertheight",                   page_property_cmd,      insert_height_code,                       0);
        tex_primitive(luatex_command, "insertheights",                  page_property_cmd,      insert_heights_code,                      0);
        tex_primitive(luatex_command, "insertlimit",                    page_property_cmd,      insert_limit_code,                        0);
        tex_primitive(luatex_command, "insertmaxdepth",                 page_property_cmd,      insert_maxdepth_code,                     0);
        tex_primitive(luatex_command, "insertmultiplier",               page_property_cmd,      insert_multiplier_code,                   0);
        tex_primitive(tex_command,    "insertpenalties",                page_property_cmd,      insert_penalties_code,                    0);
        tex_primitive(luatex_command, "insertpenalty",                  page_property_cmd,      insert_penalty_code,                      0);
        tex_primitive(luatex_command, "insertstorage",                  page_property_cmd,      insert_storage_code,                      0);
        tex_primitive(luatex_command, "insertstoring",                  page_property_cmd,      insert_storing_code,                      0);
        tex_primitive(luatex_command, "insertwidth",                    page_property_cmd,      insert_width_code,                        0);
        tex_primitive(tex_command,    "pagedepth",                      page_property_cmd,      page_depth_code,                          0);
        tex_primitive(luatex_command, "pagedepth",                      page_property_cmd,      page_depth_code,                          0);
        tex_primitive(luatex_command, "pageexcess",                     page_property_cmd,      page_excess_code,                         0);
        tex_primitive(tex_command,    "pagefilllstretch",               page_property_cmd,      page_filllstretch_code,                   0);
        tex_primitive(tex_command,    "pagefillstretch",                page_property_cmd,      page_fillstretch_code,                    0);
        tex_primitive(tex_command,    "pagefilstretch",                 page_property_cmd,      page_filstretch_code,                     0);
        tex_primitive(luatex_command, "pagefistretch",                  page_property_cmd,      page_fistretch_code,                      0);
        tex_primitive(tex_command,    "pagegoal",                       page_property_cmd,      page_goal_code,                           0);
        tex_primitive(luatex_command, "pagelastdepth",                  page_property_cmd,      page_last_depth_code,                     0);
        tex_primitive(luatex_command, "pagelastfilllstretch",           page_property_cmd,      page_last_filllstretch_code,              0);
        tex_primitive(luatex_command, "pagelastfillstretch",            page_property_cmd,      page_last_fillstretch_code,               0);
        tex_primitive(luatex_command, "pagelastfilstretch",             page_property_cmd,      page_last_filstretch_code,                0);
        tex_primitive(luatex_command, "pagelastfistretch",              page_property_cmd,      page_last_fistretch_code,                 0);
        tex_primitive(luatex_command, "pagelastheight",                 page_property_cmd,      page_last_height_code,                    0);
        tex_primitive(luatex_command, "pagelastshrink",                 page_property_cmd,      page_last_shrink_code,                    0);
        tex_primitive(luatex_command, "pagelaststretch",                page_property_cmd,      page_last_stretch_code,                   0);
        tex_primitive(tex_command,    "pageshrink",                     page_property_cmd,      page_shrink_code,                         0);
        tex_primitive(tex_command,    "pagestretch",                    page_property_cmd,      page_stretch_code,                        0);
        tex_primitive(tex_command,    "pagetotal",                      page_property_cmd,      page_total_code,                          0);
        tex_primitive(luatex_command, "pagevsize",                      page_property_cmd,      page_vsize_code,                          0);

        tex_primitive(luatex_command, "boxadapt",                       box_property_cmd,       box_adapt_code,                           0);
        tex_primitive(luatex_command, "boxanchor",                      box_property_cmd,       box_anchor_code,                          0);
        tex_primitive(luatex_command, "boxanchors",                     box_property_cmd,       box_anchors_code,                         0);
        tex_primitive(luatex_command, "boxattribute",                   box_property_cmd,       box_attribute_code,                       0);
        tex_primitive(luatex_command, "boxdirection",                   box_property_cmd,       box_direction_code,                       0);
        tex_primitive(luatex_command, "boxfinalize",                    box_property_cmd,       box_finalize_code,                        0);
        tex_primitive(luatex_command, "boxfreeze",                      box_property_cmd,       box_freeze_code,                          0);
        tex_primitive(luatex_command, "boxgeometry",                    box_property_cmd,       box_geometry_code,                        0);
        tex_primitive(luatex_command, "boxlimitate",                    box_property_cmd,       box_limitate_code,                        0);
        tex_primitive(luatex_command, "boxlimit",                       box_property_cmd,       box_limit_code,                           0);
        tex_primitive(luatex_command, "boxorientation",                 box_property_cmd,       box_orientation_code,                     0);
        tex_primitive(luatex_command, "boxrepack",                      box_property_cmd,       box_repack_code,                          0);
        tex_primitive(luatex_command, "boxshift",                       box_property_cmd,       box_shift_code,                           0);
        tex_primitive(luatex_command, "boxshrink",                      box_property_cmd,       box_shrink_code,                          0);
        tex_primitive(luatex_command, "boxsource",                      box_property_cmd,       box_source_code,                          0);
        tex_primitive(luatex_command, "boxstretch",                     box_property_cmd,       box_stretch_code,                         0);
        tex_primitive(luatex_command, "boxtarget",                      box_property_cmd,       box_target_code,                          0);
        tex_primitive(luatex_command, "boxtotal",                       box_property_cmd,       box_total_code,                           0);
        tex_primitive(luatex_command, "boxvadjust",                     box_property_cmd,       box_vadjust_code,                         0);
        tex_primitive(luatex_command, "boxxmove",                       box_property_cmd,       box_xmove_code,                           0);
        tex_primitive(luatex_command, "boxxoffset",                     box_property_cmd,       box_xoffset_code,                         0);
        tex_primitive(luatex_command, "boxymove",                       box_property_cmd,       box_ymove_code,                           0);
        tex_primitive(luatex_command, "boxyoffset",                     box_property_cmd,       box_yoffset_code,                         0);
        tex_primitive(tex_command,    "dp",                             box_property_cmd,       box_depth_code,                           0);
        tex_primitive(tex_command,    "ht",                             box_property_cmd,       box_height_code,                          0);
        tex_primitive(tex_command,    "wd",                             box_property_cmd,       box_width_code,                           0);
     // tex_primitive(luatex_command, "boxdepth",                       box_property_cmd,       box_depth_code,                           0);
     // tex_primitive(luatex_command, "boxheight",                      box_property_cmd,       box_height_code,                          0);
     // tex_primitive(luatex_command, "boxwidth",                       box_property_cmd,       box_width_code,                           0);

        tex_primitive(tex_command,    "badness",                        some_item_cmd,          badness_code,                             0);
        tex_primitive(etex_command,   "currentgrouplevel",              some_item_cmd,          current_group_level_code,                 0);
        tex_primitive(etex_command,   "currentgrouptype",               some_item_cmd,          current_group_type_code,                  0);
        tex_primitive(etex_command,   "currentifbranch",                some_item_cmd,          current_if_branch_code,                   0);
        tex_primitive(etex_command,   "currentiflevel",                 some_item_cmd,          current_if_level_code,                    0);
        tex_primitive(etex_command,   "currentiftype",                  some_item_cmd,          current_if_type_code,                     0);
        tex_primitive(luatex_command, "currentloopiterator",            some_item_cmd,          current_loop_iterator_code,               0);
        tex_primitive(luatex_command, "currentloopnesting",             some_item_cmd,          current_loop_nesting_code,                0);
        tex_primitive(etex_command,   "currentstacksize",               some_item_cmd,          current_stack_size_code,                  0);
     // tex_primitive(luatex_command, "dimentoscale",                   some_item_cmd,          dimen_to_scale_code,                      0);
        tex_primitive(etex_command,   "dimexpr",                        some_item_cmd,          dimexpr_code,                             0);
        tex_primitive(luatex_command, "dimexpression",                  some_item_cmd,          dimexpression_code,                       0); /* experiment */
        tex_primitive(luatex_command, "floatexpr",                      some_item_cmd,          posexpr_code,                             0);
        tex_primitive(luatex_command, "fontcharba",                     some_item_cmd,          font_char_ba_code,                        0);
        tex_primitive(etex_command,   "fontchardp",                     some_item_cmd,          font_char_dp_code,                        0);
        tex_primitive(etex_command,   "fontcharht",                     some_item_cmd,          font_char_ht_code,                        0);
        tex_primitive(etex_command,   "fontcharic",                     some_item_cmd,          font_char_ic_code,                        0);
        tex_primitive(luatex_command, "fontcharta",                     some_item_cmd,          font_char_ta_code,                        0);
        tex_primitive(etex_command,   "fontcharwd",                     some_item_cmd,          font_char_wd_code,                        0);
        tex_primitive(luatex_command, "scaledfontcharba",               some_item_cmd,          scaled_font_char_ba_code,                 0);
        tex_primitive(luatex_command, "scaledfontchardp",               some_item_cmd,          scaled_font_char_dp_code,                 0);
        tex_primitive(luatex_command, "scaledfontcharht",               some_item_cmd,          scaled_font_char_ht_code,                 0);
        tex_primitive(luatex_command, "scaledfontcharic",               some_item_cmd,          scaled_font_char_ic_code,                 0);
        tex_primitive(luatex_command, "scaledfontcharta",               some_item_cmd,          scaled_font_char_ta_code,                 0);
        tex_primitive(luatex_command, "scaledfontcharwd",               some_item_cmd,          scaled_font_char_wd_code,                 0);
        tex_primitive(luatex_command, "fontid",                         some_item_cmd,          font_id_code,                             0);
        tex_primitive(luatex_command, "fontmathcontrol",                some_item_cmd,          font_math_control_code,                   0);
        tex_primitive(luatex_command, "fontspecid",                     some_item_cmd,          font_spec_id_code,                        0);
        tex_primitive(luatex_command, "fontspecifiedsize",              some_item_cmd,          font_size_code,                           0);
        tex_primitive(luatex_command, "fontspecscale",                  some_item_cmd,          font_spec_scale_code,                     0);
        tex_primitive(luatex_command, "fontspecxscale",                 some_item_cmd,          font_spec_xscale_code,                    0);
        tex_primitive(luatex_command, "fontspecyscale",                 some_item_cmd,          font_spec_yscale_code,                    0);
        tex_primitive(luatex_command, "fontspecslant",                  some_item_cmd,          font_spec_slant_code,                     0);
        tex_primitive(luatex_command, "fontspecweight",                 some_item_cmd,          font_spec_weight_code,                    0);
        tex_primitive(luatex_command, "fonttextcontrol",                some_item_cmd,          font_text_control_code,                   0);
        tex_primitive(etex_command,   "glueexpr",                       some_item_cmd,          glueexpr_code,                            0);
        tex_primitive(etex_command,   "glueshrink",                     some_item_cmd,          glue_shrink_code,                         0);
        tex_primitive(etex_command,   "glueshrinkorder",                some_item_cmd,          glue_shrink_order_code,                   0);
        tex_primitive(etex_command,   "gluestretch",                    some_item_cmd,          glue_stretch_code,                        0);
        tex_primitive(etex_command,   "gluestretchorder",               some_item_cmd,          glue_stretch_order_code,                  0);
        tex_primitive(etex_command,   "gluetomu",                       some_item_cmd,          glue_to_mu_code,                          0);
        tex_primitive(luatex_command, "glyphxscaled",                   some_item_cmd,          glyph_x_scaled_code,                      0);
        tex_primitive(luatex_command, "glyphyscaled",                   some_item_cmd,          glyph_y_scaled_code,                      0);
        tex_primitive(luatex_command, "indexofcharacter",               some_item_cmd,          index_of_character_code,                  0);
        tex_primitive(luatex_command, "indexofregister",                some_item_cmd,          index_of_register_code,                   0);
        tex_primitive(tex_command,    "inputlineno",                    some_item_cmd,          input_line_no_code,                       0);
        tex_primitive(luatex_command, "insertprogress",                 some_item_cmd,          insert_progress_code,                     0);
        tex_primitive(luatex_command, "lastarguments",                  some_item_cmd,          last_arguments_code,                      0);
        tex_primitive(luatex_command, "lastatomclass",                  some_item_cmd,          last_atom_class_code,                     0);
        tex_primitive(luatex_command, "lastboundary",                   some_item_cmd,          lastboundary_code,                        0);
        tex_primitive(luatex_command, "lastchkdimension",               some_item_cmd,          last_chk_dimension_code,                  0);
        tex_primitive(luatex_command, "lastchknumber",                  some_item_cmd,          last_chk_integer_code,                    0);
        tex_primitive(tex_command,    "lastkern",                       some_item_cmd,          lastkern_code,                            0);
        tex_primitive(luatex_command, "lastleftclass",                  some_item_cmd,          last_left_class_code,                     0);
        tex_primitive(luatex_command, "lastloopiterator",               some_item_cmd,          last_loop_iterator_code,                  0);
        tex_primitive(luatex_command, "lastnodesubtype",                some_item_cmd,          last_node_subtype_code,                   0);
        tex_primitive(etex_command,   "lastnodetype",                   some_item_cmd,          last_node_type_code,                      0);
        tex_primitive(luatex_command, "lastpageextra",                  some_item_cmd,          last_page_extra_code,                     0);
        tex_primitive(luatex_command, "lastpartrigger",                 some_item_cmd,          last_par_trigger_code,                    0);
        tex_primitive(luatex_command, "lastparcontext",                 some_item_cmd,          last_par_context_code,                    0);
        tex_primitive(tex_command,    "lastpenalty",                    some_item_cmd,          lastpenalty_code,                         0);
        tex_primitive(luatex_command, "lastrightclass",                 some_item_cmd,          last_right_class_code,                    0);
        tex_primitive(tex_command,    "lastskip",                       some_item_cmd,          lastskip_code,                            0);
        tex_primitive(luatex_command, "leftmarginkern",                 some_item_cmd,          left_margin_kern_code,                    0);
        tex_primitive(luatex_command, "luatexrevision",                 some_item_cmd,          luatex_revision_code,                     0);
        tex_primitive(luatex_command, "luatexversion",                  some_item_cmd,          luatex_version_code,                      0);
     /* tex_primitive(luatex_command, "luavaluefunction",               some_item_cmd,          lua_value_function_code,                  0); */
        tex_primitive(luatex_command, "mathatomglue",                   some_item_cmd,          math_atom_glue_code,                      0);
        tex_primitive(luatex_command, "mathmainstyle",                  some_item_cmd,          math_main_style_code,                     0);
        tex_primitive(luatex_command, "mathparentstyle",                some_item_cmd,          math_parent_style_code,                   0);
        tex_primitive(luatex_command, "mathscale",                      some_item_cmd,          math_scale_code,                          0);
        tex_primitive(luatex_command, "mathstackstyle",                 some_item_cmd,          math_stack_style_code,                    0);
        tex_primitive(luatex_command, "mathstyle",                      some_item_cmd,          math_style_code,                          0);
        tex_primitive(luatex_command, "mathstylefontid",                some_item_cmd,          math_style_font_id_code,                  0);
        tex_primitive(etex_command,   "muexpr",                         some_item_cmd,          muexpr_code,                              0);
        tex_primitive(etex_command,   "mutoglue",                       some_item_cmd,          mu_to_glue_code,                          0);
        tex_primitive(luatex_command, "nestedloopiterator",             some_item_cmd,          nested_loop_iterator_code,                0);
        tex_primitive(luatex_command, "numericscale",                   some_item_cmd,          numeric_scale_code,                       0);
        tex_primitive(luatex_command, "numericscaled",                  some_item_cmd,          numeric_scaled_code,                      0);
        tex_primitive(etex_command,   "numexpr",                        some_item_cmd,          numexpr_code,                             0);
        tex_primitive(luatex_command, "numexpression",                  some_item_cmd,          numexpression_code,                       0); /* experiment */
        tex_primitive(luatex_command, "overshoot",                      some_item_cmd,          overshoot_code,                           0);
        tex_primitive(luatex_command, "parametercount",                 some_item_cmd,          parameter_count_code,                     0);
        tex_primitive(luatex_command, "parameterindex",                 some_item_cmd,          parameter_index_code,                     0);
        tex_primitive(etex_command,   "parshapedimen",                  some_item_cmd,          par_shape_dimension_code,                 0); /* bad name */
        tex_primitive(etex_command,   "parshapeindent",                 some_item_cmd,          par_shape_indent_code,                    0);
        tex_primitive(etex_command,   "parshapelength",                 some_item_cmd,          par_shape_length_code,                    0);
        tex_primitive(luatex_command, "parshapewidth",                  some_item_cmd,          par_shape_dimension_code,                 0);
        tex_primitive(luatex_command, "previousloopiterator",           some_item_cmd,          previous_loop_iterator_code,              0);
        tex_primitive(luatex_command, "rightmarginkern",                some_item_cmd,          right_margin_kern_code,                   0);
        tex_primitive(luatex_command, "scaledemwidth",                  some_item_cmd,          scaled_em_width_code,                     0);
        tex_primitive(luatex_command, "scaledexheight",                 some_item_cmd,          scaled_ex_height_code,                    0);
        tex_primitive(luatex_command, "scaledextraspace",               some_item_cmd,          scaled_extra_space_code,                  0);
        tex_primitive(luatex_command, "scaledinterwordshrink",          some_item_cmd,          scaled_interword_shrink_code,             0);
        tex_primitive(luatex_command, "scaledinterwordspace",           some_item_cmd,          scaled_interword_space_code,              0);
        tex_primitive(luatex_command, "scaledinterwordstretch",         some_item_cmd,          scaled_interword_stretch_code,            0);
        tex_primitive(luatex_command, "scaledslantperpoint",            some_item_cmd,          scaled_slant_per_point_code,              0);
        tex_primitive(luatex_command, "scaledmathaxis",                 some_item_cmd,          scaled_math_axis_code,                    0);
        tex_primitive(luatex_command, "scaledmathexheight",             some_item_cmd,          scaled_math_ex_height_code,               0);
        tex_primitive(luatex_command, "scaledmathemwidth",              some_item_cmd,          scaled_math_em_width_code,                0);
        tex_primitive(luatex_command, "mathcharclass",                  some_item_cmd,          math_char_class_code,                     0);
        tex_primitive(luatex_command, "mathcharfam",                    some_item_cmd,          math_char_fam_code,                       0);
        tex_primitive(luatex_command, "mathcharslot",                   some_item_cmd,          math_char_slot_code,                      0);

        tex_primitive(luatex_command, "csactive",                       convert_cmd,            cs_active_code,                           0);
        tex_primitive(luatex_command, "csnamestring",                   convert_cmd,            cs_lastname_code,                         0);
        tex_primitive(luatex_command, "csstring",                       convert_cmd,            cs_string_code,                           0);
        tex_primitive(luatex_command, "detokened",                      convert_cmd,            detokened_code,                           0);
        tex_primitive(luatex_command, "detokenized",                    convert_cmd,            detokenized_code,                         0);
        tex_primitive(luatex_command, "directlua",                      convert_cmd,            lua_code,                                 0);
        tex_primitive(luatex_command, "expanded",                       convert_cmd,            expanded_code,                            0);
     /* tex_primitive(luatex_command, "expandedaftercs",                convert_cmd,            expanded_after_cs_code,                   0); */ /* no gain as we need {{#1}} then */
        tex_primitive(tex_command,    "fontname",                       convert_cmd,            font_name_code,                           0);
        tex_primitive(luatex_command, "fontspecifiedname",              convert_cmd,            font_specification_code,                  0);
        tex_primitive(luatex_command, "formatname",                     convert_cmd,            format_name_code,                         0);
        tex_primitive(tex_command,    "jobname",                        convert_cmd,            job_name_code,                            0);
        tex_primitive(luatex_command, "luabytecode",                    convert_cmd,            lua_bytecode_code,                        0);
        tex_primitive(luatex_command, "luaescapestring",                convert_cmd,            lua_escape_string_code,                   0);
        tex_primitive(luatex_command, "luafunction",                    convert_cmd,            lua_function_code,                        0);
        tex_primitive(luatex_command, "luatexbanner",                   convert_cmd,            luatex_banner_code,                       0);
     /* tex_primitive(luatex_command, "luatokenstring",                 convert_cmd,            lua_token_string_code,                    0); */
        tex_primitive(tex_command,    "meaning",                        convert_cmd,            meaning_code,                             0);
        tex_primitive(luatex_command, "meaningasis",                    convert_cmd,            meaning_asis_code,                        0); /* for manuals and articles */
        tex_primitive(luatex_command, "meaningful",                     convert_cmd,            meaning_ful_code,                         0); /* full as in fil */
        tex_primitive(luatex_command, "meaningfull",                    convert_cmd,            meaning_full_code,                        0); /* full as in fill, maybe some day meaninfulll  */
        tex_primitive(luatex_command, "meaningles",                     convert_cmd,            meaning_les_code,                         0); /* less as in fil, can't be less than this */
        tex_primitive(luatex_command, "meaningless",                    convert_cmd,            meaning_less_code,                        0); /* less as in fill */
        tex_primitive(tex_command,    "number",                         convert_cmd,            number_code,                              0);
        tex_primitive(tex_command,    "romannumeral",                   convert_cmd,            roman_numeral_code,                       0);
        tex_primitive(luatex_command, "semiexpanded",                   convert_cmd,            semi_expanded_code,                       0);
        tex_primitive(tex_command,    "string",                         convert_cmd,            string_code,                              0);
        tex_primitive(luatex_command, "todimension",                    convert_cmd,            to_dimension_code,                        0);
        tex_primitive(luatex_command, "tohexadecimal",                  convert_cmd,            to_hexadecimal_code,                      0);
        tex_primitive(luatex_command, "tointeger",                      convert_cmd,            to_integer_code,                          0);
        tex_primitive(luatex_command, "tomathstyle",                    convert_cmd,            to_mathstyle_code,                        0);
        tex_primitive(luatex_command, "toscaled",                       convert_cmd,            to_scaled_code,                           0);
        tex_primitive(luatex_command, "tosparsedimension",              convert_cmd,            to_sparse_dimension_code,                 0);
        tex_primitive(luatex_command, "tosparsescaled",                 convert_cmd,            to_sparse_scaled_code,                    0);
        tex_primitive(luatex_command, "tocharacter",                    convert_cmd,            to_character_code,                        0);

        tex_primitive(tex_command,    "else",                           if_test_cmd,            else_code,                                0);
        tex_primitive(tex_command,    "fi",                             if_test_cmd,            fi_code,                                  0);
        tex_primitive(no_command,     "inif",                           if_test_cmd,            if_code,                                  0);
        tex_primitive(no_command,     "noif",                           if_test_cmd,            no_if_code,                               0);
        tex_primitive(tex_command,    "or",                             if_test_cmd,            or_code,                                  0);
        tex_primitive(luatex_command, "orelse",                         if_test_cmd,            or_else_code,                             0);
        tex_primitive(luatex_command, "orunless",                       if_test_cmd,            or_unless_code,                           0);

        tex_primitive(tex_command,    "if",                             if_test_cmd,            if_char_code,                             0);
        tex_primitive(luatex_command, "ifabsdim",                       if_test_cmd,            if_abs_dim_code,                          0);
        tex_primitive(luatex_command, "ifabsfloat",                     if_test_cmd,            if_abs_posit_code,                        0);
        tex_primitive(luatex_command, "ifabsnum",                       if_test_cmd,            if_abs_int_code,                          0);
        tex_primitive(luatex_command, "ifarguments",                    if_test_cmd,            if_arguments_code,                        0);
     /* tex_primitive(luatex_command, "ifbitwiseand",                   if_test_cmd,            if_bitwise_and_code,                      0); */
        tex_primitive(luatex_command, "ifboolean",                      if_test_cmd,            if_boolean_code,                          0);
        tex_primitive(tex_command,    "ifcase",                         if_test_cmd,            if_case_code,                             0);
        tex_primitive(tex_command,    "ifcat",                          if_test_cmd,            if_cat_code,                              0);
        tex_primitive(luatex_command, "ifchkdim",                       if_test_cmd,            if_chk_dim_code,                          0);
        tex_primitive(luatex_command, "ifchkdimension",                 if_test_cmd,            if_chk_dimension_code,                    0);
        tex_primitive(luatex_command, "ifchknum",                       if_test_cmd,            if_chk_int_code,                          0);
        tex_primitive(luatex_command, "ifchknumber",                    if_test_cmd,            if_chk_integer_code,                      0);
        tex_primitive(luatex_command, "ifcmpdim",                       if_test_cmd,            if_cmp_dim_code,                          0);
        tex_primitive(luatex_command, "ifcmpnum",                       if_test_cmd,            if_cmp_int_code,                          0);
        tex_primitive(luatex_command, "ifcondition",                    if_test_cmd,            if_condition_code,                        0);
        tex_primitive(etex_command,   "ifcsname",                       if_test_cmd,            if_csname_code,                           0);
        tex_primitive(luatex_command, "ifcstok",                        if_test_cmd,            if_cstok_code,                            0);
        tex_primitive(etex_command,   "ifdefined",                      if_test_cmd,            if_defined_code,                          0);
        tex_primitive(tex_command,    "ifdim",                          if_test_cmd,            if_dim_code,                              0);
        tex_primitive(luatex_command, "ifdimexpression",                if_test_cmd,            if_dimexpression_code,                    0);
        tex_primitive(luatex_command, "ifdimval",                       if_test_cmd,            if_val_dim_code,                          0);
        tex_primitive(luatex_command, "ifempty",                        if_test_cmd,            if_empty_code,                            0);
        tex_primitive(tex_command,    "iffalse",                        if_test_cmd,            if_false_code,                            0);
        tex_primitive(luatex_command, "ifflags",                        if_test_cmd,            if_flags_code,                            0);
        tex_primitive(luatex_command, "iffloat",                        if_test_cmd,            if_posit_code,                            0);
        tex_primitive(etex_command,   "iffontchar",                     if_test_cmd,            if_font_char_code,                        0);
        tex_primitive(luatex_command, "ifhaschar",                      if_test_cmd,            if_has_char_code,                         0);
        tex_primitive(luatex_command, "ifhastok",                       if_test_cmd,            if_has_tok_code,                          0);
        tex_primitive(luatex_command, "ifhastoks",                      if_test_cmd,            if_has_toks_code,                         0);
        tex_primitive(luatex_command, "ifhasxtoks",                     if_test_cmd,            if_has_xtoks_code,                        0);
        tex_primitive(tex_command,    "ifhbox",                         if_test_cmd,            if_hbox_code,                             0);
        tex_primitive(tex_command,    "ifhmode",                        if_test_cmd,            if_hmode_code,                            0);
        tex_primitive(luatex_command, "ifinalignment",                  if_test_cmd,            if_in_alignment_code,                     0); 
        tex_primitive(luatex_command, "ifincsname",                     if_test_cmd,            if_in_csname_code,                        0); /* This is obsolete and might be dropped. */
        tex_primitive(tex_command,    "ifinner",                        if_test_cmd,            if_inner_code,                            0);
        tex_primitive(luatex_command, "ifinsert",                       if_test_cmd,            if_insert_code,                           0);
        tex_primitive(luatex_command, "ifintervaldim",                  if_test_cmd,            if_interval_dim_code,                     0); /* playground */
        tex_primitive(luatex_command, "ifintervalfloat",                if_test_cmd,            if_interval_posit_code,                   0); /* playground */
        tex_primitive(luatex_command, "ifintervalnum",                  if_test_cmd,            if_interval_int_code,                     0); /* playground */
        tex_primitive(luatex_command, "iflastnamedcs",                  if_test_cmd,            if_last_named_cs_code,                    0);
        tex_primitive(luatex_command, "ifmathparameter",                if_test_cmd,            if_math_parameter_code,                   0);
        tex_primitive(luatex_command, "ifmathstyle",                    if_test_cmd,            if_math_style_code,                       0);
        tex_primitive(luatex_command, "ifcramped",                      if_test_cmd,            if_cramped_code,                          0);
        tex_primitive(tex_command,    "ifmmode",                        if_test_cmd,            if_mmode_code,                            0);
        tex_primitive(tex_command,    "ifnum",                          if_test_cmd,            if_int_code,                              0);
        tex_primitive(luatex_command, "ifnumexpression",                if_test_cmd,            if_numexpression_code,                    0);
        tex_primitive(luatex_command, "ifnumval",                       if_test_cmd,            if_val_int_code,                          0);
        tex_primitive(tex_command,    "ifodd",                          if_test_cmd,            if_odd_code,                              0);
        tex_primitive(luatex_command, "ifparameter",                    if_test_cmd,            if_parameter_code,                        0);
        tex_primitive(luatex_command, "ifparameters",                   if_test_cmd,            if_parameters_code,                       0);
        tex_primitive(luatex_command, "ifrelax",                        if_test_cmd,            if_relax_code,                            0);
        tex_primitive(luatex_command, "iftok",                          if_test_cmd,            if_tok_code,                              0);
        tex_primitive(tex_command,    "iftrue",                         if_test_cmd,            if_true_code,                             0);
        tex_primitive(tex_command,    "ifvbox",                         if_test_cmd,            if_vbox_code,                             0);
        tex_primitive(tex_command,    "ifvmode",                        if_test_cmd,            if_vmode_code,                            0);
        tex_primitive(tex_command,    "ifvoid",                         if_test_cmd,            if_void_code,                             0);
        tex_primitive(tex_command,    "ifx",                            if_test_cmd,            if_x_code,                                0);
        tex_primitive(luatex_command, "ifzerodim",                      if_test_cmd,            if_zero_dim_code,                         0);
        tex_primitive(luatex_command, "ifzerofloat",                    if_test_cmd,            if_zero_posit_code,                       0);
        tex_primitive(luatex_command, "ifzeronum",                      if_test_cmd,            if_zero_int_code,                         0);

        tex_primitive(tex_command,    "above",                          math_fraction_cmd,      math_above_code,                          0);
        tex_primitive(tex_command,    "abovewithdelims",                math_fraction_cmd,      math_above_delimited_code,                0);
        tex_primitive(tex_command,    "atop",                           math_fraction_cmd,      math_atop_code,                           0);
        tex_primitive(tex_command,    "atopwithdelims",                 math_fraction_cmd,      math_atop_delimited_code,                 0);
        tex_primitive(tex_command,    "over",                           math_fraction_cmd,      math_over_code,                           0);
        tex_primitive(tex_command,    "overwithdelims",                 math_fraction_cmd,      math_over_delimited_code,                 0);

        tex_primitive(luatex_command, "Uabove",                         math_fraction_cmd,      math_u_above_code,                        0);
        tex_primitive(luatex_command, "Uabovewithdelims",               math_fraction_cmd,      math_u_above_delimited_code,              0);
        tex_primitive(luatex_command, "Uatop",                          math_fraction_cmd,      math_u_atop_code,                         0);
        tex_primitive(luatex_command, "Uatopwithdelims",                math_fraction_cmd,      math_u_atop_delimited_code,               0);
        tex_primitive(luatex_command, "Uover",                          math_fraction_cmd,      math_u_over_code,                         0);
        tex_primitive(luatex_command, "Uoverwithdelims",                math_fraction_cmd,      math_u_over_delimited_code,               0);
        tex_primitive(luatex_command, "Uskewed",                        math_fraction_cmd,      math_u_skewed_code,                       0);
        tex_primitive(luatex_command, "Uskewedwithdelims",              math_fraction_cmd,      math_u_skewed_delimited_code,             0);
        tex_primitive(luatex_command, "Ustretched",                     math_fraction_cmd,      math_u_stretched_code,                    0);
        tex_primitive(luatex_command, "Ustretchedwithdelims",           math_fraction_cmd,      math_u_stretched_delimited_code,          0);

        tex_primitive(luatex_command, "cfcode",                         font_property_cmd,      font_cf_code,                             0); /* obsolete */
        tex_primitive(luatex_command, "efcode",                         font_property_cmd,      font_ef_code,                             0); /* obsolete */
        tex_primitive(tex_command,    "fontdimen",                      font_property_cmd,      font_dimension_code,                      0);
        tex_primitive(tex_command,    "hyphenchar",                     font_property_cmd,      font_hyphen_code,                         0);
        tex_primitive(luatex_command, "lpcode",                         font_property_cmd,      font_lp_code,                             0); /* obsolete */
        tex_primitive(luatex_command, "rpcode",                         font_property_cmd,      font_rp_code,                             0); /* obsolete */
        tex_primitive(luatex_command, "scaledfontdimen",                font_property_cmd,      scaled_font_dimension_code,               0);
        tex_primitive(tex_command,    "skewchar",                       font_property_cmd,      font_skew_code,                           0);

        tex_primitive(tex_command,    "lowercase",                      case_shift_cmd,         lower_case_code,                          0);
        tex_primitive(tex_command,    "uppercase",                      case_shift_cmd,         upper_case_code,                          0);

        tex_primitive(luatex_command, "amcode",                         define_char_code_cmd,   amcode_charcode,                          0);
        tex_primitive(tex_command,    "catcode",                        define_char_code_cmd,   catcode_charcode,                         0);
        tex_primitive(luatex_command, "cccode",                         define_char_code_cmd,   cccode_charcode,                          0);
        tex_primitive(tex_command,    "delcode",                        define_char_code_cmd,   delcode_charcode,                         0);
        tex_primitive(luatex_command, "hccode",                         define_char_code_cmd,   hccode_charcode,                          0);
        tex_primitive(luatex_command, "hmcode",                         define_char_code_cmd,   hmcode_charcode,                          0);
        tex_primitive(tex_command,    "lccode",                         define_char_code_cmd,   lccode_charcode,                          0);
        tex_primitive(tex_command,    "mathcode",                       define_char_code_cmd,   mathcode_charcode,                        0);
        tex_primitive(tex_command,    "sfcode",                         define_char_code_cmd,   sfcode_charcode,                          0);
        tex_primitive(tex_command,    "uccode",                         define_char_code_cmd,   uccode_charcode,                          0);

        tex_primitive(luatex_command, "Udelcode",                       define_char_code_cmd,   extdelcode_charcode,                      0);
        tex_primitive(luatex_command, "Umathcode",                      define_char_code_cmd,   extmathcode_charcode,                     0);

        tex_primitive(luatex_command, "cdef",                           def_cmd,                constant_def_code,                        0);
        tex_primitive(luatex_command, "cdefcsname",                     def_cmd,                constant_def_csname_code,                 0);
        tex_primitive(tex_command,    "def",                            def_cmd,                def_code,                                 0);
        tex_primitive(luatex_command, "defcsname",                      def_cmd,                def_csname_code,                          0);
        tex_primitive(tex_command,    "edef",                           def_cmd,                expanded_def_code,                        0);
        tex_primitive(luatex_command, "edefcsname",                     def_cmd,                expanded_def_csname_code,                 0);
        tex_primitive(tex_command,    "gdef",                           def_cmd,                global_def_code,                          0);
        tex_primitive(luatex_command, "gdefcsname",                     def_cmd,                global_def_csname_code,                   0);
        tex_primitive(tex_command,    "xdef",                           def_cmd,                global_expanded_def_code,                 0);
        tex_primitive(luatex_command, "xdefcsname",                     def_cmd,                global_expanded_def_csname_code,          0);

        tex_primitive(tex_command,    "scriptfont",                     define_family_cmd,      script_size,                              0);
        tex_primitive(tex_command,    "scriptscriptfont",               define_family_cmd,      script_script_size,                       0);
        tex_primitive(tex_command,    "textfont",                       define_family_cmd,      text_size,                                0);

        tex_primitive(tex_command,    "-",                              discretionary_cmd,      explicit_discretionary_code,              0);
        tex_primitive(luatex_command, "automaticdiscretionary",         discretionary_cmd,      automatic_discretionary_code,             0);
        tex_primitive(tex_command,    "discretionary",                  discretionary_cmd,      normal_discretionary_code,                0);
        tex_primitive(luatex_command, "explicitdiscretionary",          discretionary_cmd,      explicit_discretionary_code,              0);

        tex_primitive(tex_command,    "eqno",                           equation_number_cmd,    right_location_code,                      0);
        tex_primitive(tex_command,    "leqno",                          equation_number_cmd,    left_location_code,                       0);

        tex_primitive(tex_command,    "moveleft",                       hmove_cmd,              move_backward_code,                       0);
        tex_primitive(tex_command,    "moveright",                      hmove_cmd,              move_forward_code,                        0);

        tex_primitive(tex_command,    "hfil",                           hskip_cmd,              fi_l_code,                                0);
        tex_primitive(tex_command,    "hfill",                          hskip_cmd,              fi_ll_code,                               0);
        tex_primitive(tex_command,    "hfilneg",                        hskip_cmd,              fi_l_neg_code,                            0);
        tex_primitive(tex_command,    "hskip",                          hskip_cmd,              skip_code,                                0);
        tex_primitive(tex_command,    "hss",                            hskip_cmd,              fi_ss_code,                               0);

        tex_primitive(luatex_command, "hjcode",                         hyphenation_cmd,        hjcode_code,                              0);
        tex_primitive(tex_command,    "hyphenation",                    hyphenation_cmd,        hyphenation_code,                         0);
        tex_primitive(luatex_command, "hyphenationmin",                 hyphenation_cmd,        hyphenationmin_code,                      0);
        tex_primitive(tex_command,    "patterns",                       hyphenation_cmd,        patterns_code,                            0);
        tex_primitive(luatex_command, "postexhyphenchar",               hyphenation_cmd,        postexhyphenchar_code,                    0);
        tex_primitive(luatex_command, "posthyphenchar",                 hyphenation_cmd,        posthyphenchar_code,                      0);
        tex_primitive(luatex_command, "preexhyphenchar",                hyphenation_cmd,        preexhyphenchar_code,                     0);
        tex_primitive(luatex_command, "prehyphenchar",                  hyphenation_cmd,        prehyphenchar_code,                       0);

        tex_primitive(tex_command,    "hkern",                          kern_cmd,               h_kern_code,                              0);
        tex_primitive(tex_command,    "kern",                           kern_cmd,               normal_kern_code,                         0);
     /* tex_primitive(tex_command,    "nonzerowidthkern",               kern_cmd,               non_zero_width_kern_code,                 0); */ /* maybe */
        tex_primitive(tex_command,    "vkern",                          kern_cmd,               v_kern_code,                              0);

        tex_primitive(luatex_command, "localleftbox",                   local_box_cmd,          local_left_box_code,                      0);
        tex_primitive(luatex_command, "localmiddlebox",                 local_box_cmd,          local_middle_box_code,                    0);
        tex_primitive(luatex_command, "localrightbox",                  local_box_cmd,          local_right_box_code,                     0);
        tex_primitive(luatex_command, "resetlocalboxes",                local_box_cmd,          local_reset_boxes_code,                   0);

        tex_primitive(tex_command,    "shipout",                        legacy_cmd,             shipout_code,                             0);

        tex_primitive(tex_command,    "cleaders",                       leader_cmd,             c_leaders_code,                           0);
        tex_primitive(luatex_command, "gleaders",                       leader_cmd,             g_leaders_code,                           0);
        tex_primitive(tex_command,    "leaders",                        leader_cmd,             a_leaders_code,                           0);
        tex_primitive(luatex_command, "uleaders",                       leader_cmd,             u_leaders_code,                           0);
        tex_primitive(tex_command,    "xleaders",                       leader_cmd,             x_leaders_code,                           0);

        tex_primitive(tex_command,    "left",                           math_fence_cmd,         left_fence_side,                          0);
        tex_primitive(tex_command,    "middle",                         math_fence_cmd,         middle_fence_side,                        0);
        tex_primitive(tex_command,    "right",                          math_fence_cmd,         right_fence_side,                         0);
        tex_primitive(luatex_command, "Uleft",                          math_fence_cmd,         extended_left_fence_side,                 0);
        tex_primitive(luatex_command, "Umiddle",                        math_fence_cmd,         extended_middle_fence_side,               0);
        tex_primitive(luatex_command, "Uoperator",                      math_fence_cmd,         left_operator_side,                       0);
        tex_primitive(luatex_command, "Uright",                         math_fence_cmd,         extended_right_fence_side,                0);
        tex_primitive(luatex_command, "Uvextensible",                   math_fence_cmd,         no_fence_side,                            0);

        tex_primitive(luatex_command, "futuredef",                      let_cmd,                future_def_code,                          0);
        tex_primitive(tex_command,    "futurelet",                      let_cmd,                future_let_code,                          0);
        tex_primitive(luatex_command, "glet",                           let_cmd,                global_let_code,                          0);
        tex_primitive(luatex_command, "gletcsname",                     let_cmd,                global_let_csname_code,                   0);
        tex_primitive(luatex_command, "glettonothing",                  let_cmd,                global_let_to_nothing_code,               0); /* more a def but a let is nicer */
        tex_primitive(tex_command,    "let",                            let_cmd,                let_code,                                 0);
        tex_primitive(luatex_command, "letcharcode",                    let_cmd,                let_charcode_code,                        0);
        tex_primitive(luatex_command, "letcsname",                      let_cmd,                let_csname_code,                          0);
        tex_primitive(luatex_command, "letfrozen",                      let_cmd,                let_frozen_code,                          0);
        tex_primitive(luatex_command, "letprotected",                   let_cmd,                let_protected_code,                       0);
        tex_primitive(luatex_command, "lettolastnamedcs",               let_cmd,                let_to_last_named_cs_code,                0); /* more intuitive than using an edef */
        tex_primitive(luatex_command, "lettonothing",                   let_cmd,                let_to_nothing_code,                      0); /* more a def but a let is nicer */
        tex_primitive(luatex_command, "swapcsvalues",                   let_cmd,                swap_cs_values_code,                      0);
        tex_primitive(luatex_command, "unletfrozen",                    let_cmd,                unlet_frozen_code,                        0);
        tex_primitive(luatex_command, "unletprotected",                 let_cmd,                unlet_protected_code,                     0);

        tex_primitive(tex_command,    "displaylimits",                  math_modifier_cmd,      display_limits_modifier_code,             0);
        tex_primitive(tex_command,    "limits",                         math_modifier_cmd,      limits_modifier_code,                     0);
        tex_primitive(tex_command,    "nolimits",                       math_modifier_cmd,      no_limits_modifier_code,                  0);

        /* beware, Umathaxis is overloaded ... maybe only a generic modifier with keywords */

        tex_primitive(luatex_command, "Umathadapttoleft",               math_modifier_cmd,      adapt_to_left_modifier_code,              0);
        tex_primitive(luatex_command, "Umathadapttoright",              math_modifier_cmd,      adapt_to_right_modifier_code,             0);
        tex_primitive(luatex_command, "Umathlimits",                    math_modifier_cmd,      limits_modifier_code,                     0);
        tex_primitive(luatex_command, "Umathnoaxis",                    math_modifier_cmd,      no_axis_modifier_code,                    0);
        tex_primitive(luatex_command, "Umathnolimits",                  math_modifier_cmd,      no_limits_modifier_code,                  0);
        tex_primitive(luatex_command, "Umathopenupdepth",               math_modifier_cmd,      openup_depth_modifier_code,               0);
        tex_primitive(luatex_command, "Umathopenupheight",              math_modifier_cmd,      openup_height_modifier_code,              0);
        tex_primitive(luatex_command, "Umathphantom",                   math_modifier_cmd,      phantom_modifier_code,                    0);
        tex_primitive(luatex_command, "Umathsource",                    math_modifier_cmd,      source_modifier_code,                     0);
        tex_primitive(luatex_command, "Umathuseaxis",                   math_modifier_cmd,      axis_modifier_code,                       0);
        tex_primitive(luatex_command, "Umathvoid",                      math_modifier_cmd,      void_modifier_code,                       0);

        tex_primitive(tex_command,    "box",                            make_box_cmd,           box_code,                                 0);
        tex_primitive(tex_command,    "copy",                           make_box_cmd,           copy_code,                                0);
        tex_primitive(luatex_command, "dbox",                           make_box_cmd,           dbox_code,                                0);
        tex_primitive(luatex_command, "dpack",                          make_box_cmd,           dpack_code,                               0);
        tex_primitive(luatex_command, "dsplit",                         make_box_cmd,           dsplit_code,                              0);
        tex_primitive(tex_command,    "hbox",                           make_box_cmd,           hbox_code,                                0);
        tex_primitive(luatex_command, "hpack",                          make_box_cmd,           hpack_code,                               0);
        tex_primitive(luatex_command, "insertbox",                      make_box_cmd,           insert_box_code,                          0);
        tex_primitive(luatex_command, "insertcopy",                     make_box_cmd,           insert_copy_code,                         0);
        tex_primitive(tex_command,    "lastbox",                        make_box_cmd,           last_box_code,                            0);
        tex_primitive(luatex_command, "localleftboxbox",                make_box_cmd,           local_left_box_box_code,                  0);
        tex_primitive(luatex_command, "localmiddleboxbox",              make_box_cmd,           local_middle_box_box_code,                0);
        tex_primitive(luatex_command, "localrightboxbox",               make_box_cmd,           local_right_box_box_code,                 0);
        tex_primitive(luatex_command, "tpack",                          make_box_cmd,           tpack_code,                               0);
        tex_primitive(luatex_command, "tsplit",                         make_box_cmd,           tsplit_code,                              0);
        tex_primitive(tex_command,    "vbox",                           make_box_cmd,           vbox_code,                                0);
        tex_primitive(luatex_command, "vpack",                          make_box_cmd,           vpack_code,                               0);
        tex_primitive(tex_command,    "vsplit",                         make_box_cmd,           vsplit_code,                              0);
        tex_primitive(tex_command,    "vtop",                           make_box_cmd,           vtop_code,                                0);

        /*tex Begin compatibility. */

        tex_primitive(tex_command,    "mathbin",                        math_component_cmd,     math_component_binary_code,               0);
        tex_primitive(tex_command,    "mathclose",                      math_component_cmd,     math_component_close_code,                0);
        tex_primitive(tex_command,    "mathinner",                      math_component_cmd,     math_component_inner_code,                0);
        tex_primitive(tex_command,    "mathop",                         math_component_cmd,     math_component_operator_code,             0);
        tex_primitive(tex_command,    "mathopen",                       math_component_cmd,     math_component_open_code,                 0);
        tex_primitive(tex_command,    "mathord",                        math_component_cmd,     math_component_ordinary_code,             0);
        tex_primitive(tex_command,    "mathpunct",                      math_component_cmd,     math_component_punctuation_code,          0);
        tex_primitive(tex_command,    "mathrel",                        math_component_cmd,     math_component_relation_code,             0);
        tex_primitive(tex_command,    "overline",                       math_component_cmd,     math_component_over_code,                 0);
        tex_primitive(tex_command,    "underline",                      math_component_cmd,     math_component_under_code,                0);

        /*tex End compatibility. */

        /*
            We had these for a while but they are now dropped because (1) we should not overload |\mathaccent|
            (at least not now) and we have many user classes in \CONTEXT\ anyway.
        */

        /* begin of gone */ /*

        tex_primitive(luatex_command, "mathaccent",                     math_component_cmd,     math_component_accent_code,               0);
        tex_primitive(luatex_command, "mathbinary",                     math_component_cmd,     math_component_binary_code,               0);
        tex_primitive(luatex_command, "mathclose",                      math_component_cmd,     math_component_close_code,                0);
        tex_primitive(luatex_command, "mathfenced",                     math_component_cmd,     math_component_fenced_code,               0);
        tex_primitive(luatex_command, "mathfraction",                   math_component_cmd,     math_component_fraction_code,             0);
        tex_primitive(luatex_command, "mathghost",                      math_component_cmd,     math_component_ghost_code,                0);
        tex_primitive(luatex_command, "mathinner",                      math_component_cmd,     math_component_inner_code,                0);
        tex_primitive(luatex_command, "mathmiddle",                     math_component_cmd,     math_component_middle_code,               0);
        tex_primitive(luatex_command, "mathopen",                       math_component_cmd,     math_component_open_code,                 0);
        tex_primitive(luatex_command, "mathoperator",                   math_component_cmd,     math_component_operator_code,             0);
        tex_primitive(luatex_command, "mathordinary",                   math_component_cmd,     math_component_ordinary_code,             0);
        tex_primitive(luatex_command, "mathoverline",                   math_component_cmd,     math_component_over_code,                 0);
        tex_primitive(luatex_command, "mathpunctuation",                math_component_cmd,     math_component_punctuation_code,          0);
        tex_primitive(luatex_command, "mathradical",                    math_component_cmd,     math_component_radical_code,              0);
        tex_primitive(luatex_command, "mathrelation",                   math_component_cmd,     math_component_relation_code,             0);
        tex_primitive(luatex_command, "mathunderline",                  math_component_cmd,     math_component_under_code,                0);

        */ /* end of gone */

        tex_primitive(luatex_command, "mathatom",                       math_component_cmd,     math_component_atom_code,                 0);

        tex_primitive(luatex_command, "Ustartdisplaymath",              math_shift_cs_cmd,      begin_display_math_code,                  0);
        tex_primitive(luatex_command, "Ustartmath",                     math_shift_cs_cmd,      begin_inline_math_code,                   0);
        tex_primitive(luatex_command, "Ustartmathmode",                 math_shift_cs_cmd,      begin_math_mode_code,                     0);
        tex_primitive(luatex_command, "Ustopdisplaymath",               math_shift_cs_cmd,      end_display_math_code,                    0);
        tex_primitive(luatex_command, "Ustopmath",                      math_shift_cs_cmd,      end_inline_math_code,                     0);
        tex_primitive(luatex_command, "Ustopmathmode",                  math_shift_cs_cmd,      end_math_mode_code,                       0);

        tex_primitive(luatex_command, "allcrampedstyles",               math_style_cmd,         all_cramped_styles,                       0);
        tex_primitive(luatex_command, "alldisplaystyles",               math_style_cmd,         all_display_styles,                       0);
        tex_primitive(luatex_command, "allmainstyles",                  math_style_cmd,         all_main_styles,                          0);
        tex_primitive(luatex_command, "allmathstyles",                  math_style_cmd,         all_math_styles,                          0);
        tex_primitive(luatex_command, "allscriptscriptstyles",          math_style_cmd,         all_script_script_styles,                 0);
        tex_primitive(luatex_command, "allscriptstyles",                math_style_cmd,         all_script_styles,                        0);
        tex_primitive(luatex_command, "allsplitstyles",                 math_style_cmd,         all_split_styles,                         0);
        tex_primitive(luatex_command, "alltextstyles",                  math_style_cmd,         all_text_styles,                          0);
        tex_primitive(luatex_command, "alluncrampedstyles",             math_style_cmd,         all_uncramped_styles,                     0);
        tex_primitive(luatex_command, "allunsplitstyles",               math_style_cmd,         all_unsplit_styles,                       0);
        tex_primitive(luatex_command, "crampeddisplaystyle",            math_style_cmd,         cramped_display_style,                    0);
        tex_primitive(luatex_command, "crampedscriptscriptstyle",       math_style_cmd,         cramped_script_script_style,              0);
        tex_primitive(luatex_command, "crampedscriptstyle",             math_style_cmd,         cramped_script_style,                     0);
        tex_primitive(luatex_command, "crampedtextstyle",               math_style_cmd,         cramped_text_style,                       0);
        tex_primitive(tex_command,    "displaystyle",                   math_style_cmd,         display_style,                            0);
        tex_primitive(luatex_command, "scaledmathstyle",                math_style_cmd,         scaled_math_style,                        0);
        tex_primitive(tex_command,    "scriptscriptstyle",              math_style_cmd,         script_script_style,                      0);
        tex_primitive(tex_command,    "scriptstyle",                    math_style_cmd,         script_style,                             0);
        tex_primitive(tex_command,    "textstyle",                      math_style_cmd,         text_style,                               0);
        tex_primitive(luatex_command, "currentlysetmathstyle",          math_style_cmd,         currently_set_math_style,                 0);
        tex_primitive(luatex_command, "givenmathstyle",                 math_style_cmd,         yet_unset_math_style,                     0);

        tex_primitive(tex_command,    "errmessage",                     message_cmd,            error_message_code,                       0);
        tex_primitive(tex_command,    "message",                        message_cmd,            message_code,                             0);

        tex_primitive(tex_command,    "mkern",                          mkern_cmd,              normal_code,                              0);

        tex_primitive(luatex_command, "mathatomskip",                   mskip_cmd,              atom_mskip_code,                          0);
        tex_primitive(tex_command,    "mskip",                          mskip_cmd,              normal_mskip_code,                        0);

        /*tex
            We keep |\long| and |\outer| as dummies, while |\protected| is promoted to a real cmd
            and |\frozen| can provide a mild form of protection against overloads. We still intercept
            the commands.
        */

        tex_primitive(luatex_command, "aliased",                        prefix_cmd,             aliased_code,                                    0);
        tex_primitive(no_command,     "always",                         prefix_cmd,             always_code,                                     0);
        tex_primitive(luatex_command, "constant",                       prefix_cmd,             constant_code,                                   0);
        tex_primitive(luatex_command, "constrained",                    prefix_cmd,             constrained_code,                                0);
        tex_primitive(luatex_command, "deferred",                       prefix_cmd,             deferred_code,                                   0);
        tex_primitive(luatex_command, "enforced",                       prefix_cmd,             enforced_code,                                   0);
        tex_primitive(luatex_command, "frozen",                         prefix_cmd,             frozen_code,                                     0);
        tex_primitive(tex_command,    "global",                         prefix_cmd,             global_code,                                     0);
        tex_primitive(luatex_command, "immediate",                      prefix_cmd,             immediate_code,                                  0);
        tex_primitive(luatex_command, "immutable",                      prefix_cmd,             immutable_code,                                  0);
        tex_primitive(luatex_command, "inherited",                      prefix_cmd,             inherited_code,                                  0);
        tex_primitive(luatex_command, "instance",                       prefix_cmd,             instance_code,                                   0);
        tex_primitive(tex_command,    "long",                           prefix_cmd,             long_code,                                       0); /* nop */
        tex_primitive(luatex_command, "mutable",                        prefix_cmd,             mutable_code,                                    0);
        tex_primitive(luatex_command, "noaligned",                      prefix_cmd,             noaligned_code,                                  0);
        tex_primitive(tex_command,    "outer",                          prefix_cmd,             outer_code,                                      0); /* nop */
        tex_primitive(luatex_command, "overloaded",                     prefix_cmd,             overloaded_code,                                 0);
        tex_primitive(luatex_command, "permanent",                      prefix_cmd,             permanent_code,                                  0);
     /* tex_primitive(luatex_command, "primitive",                      prefix_cmd,             primitive_code,                                  0); */
        tex_primitive(etex_command,   "protected",                      prefix_cmd,             protected_code,                                  0);
        tex_primitive(luatex_command, "retained",                       prefix_cmd,             retained_code,                                   0);
        tex_primitive(luatex_command, "semiprotected",                  prefix_cmd,             semiprotected_code,                              0);
        tex_primitive(luatex_command, "tolerant",                       prefix_cmd,             tolerant_code,                                   0);
        tex_primitive(luatex_command, "untraced",                       prefix_cmd,             untraced_code,                                   0);
                                                                                                                                                 
        tex_primitive(tex_command,    "unboundary",                     remove_item_cmd,        boundary_item_code,                              0);
        tex_primitive(tex_command,    "unkern",                         remove_item_cmd,        kern_item_code,                                  0);
        tex_primitive(tex_command,    "unpenalty",                      remove_item_cmd,        penalty_item_code,                               0);
        tex_primitive(tex_command,    "unskip",                         remove_item_cmd,        skip_item_code,                                  0);
                                                                                                                                                 
        tex_primitive(tex_command,    "batchmode",                      interaction_cmd,        batch_mode,                                      0);
        tex_primitive(tex_command,    "errorstopmode",                  interaction_cmd,        error_stop_mode,                                 0);
        tex_primitive(tex_command,    "nonstopmode",                    interaction_cmd,        nonstop_mode,                                    0);
        tex_primitive(tex_command,    "scrollmode",                     interaction_cmd,        scroll_mode,                                     0);
                                                                                                                                                 
        tex_primitive(luatex_command, "attributedef",                   shorthand_def_cmd,      attribute_def_code,                              0);
        tex_primitive(tex_command,    "chardef",                        shorthand_def_cmd,      char_def_code,                                   0);
        tex_primitive(tex_command,    "countdef",                       shorthand_def_cmd,      count_def_code,                                  0);
        tex_primitive(tex_command,    "dimendef",                       shorthand_def_cmd,      dimen_def_code,                                  0);
        tex_primitive(luatex_command, "dimensiondef",                   shorthand_def_cmd,      dimension_def_code,                              0);
     /* tex_primitive(luatex_command, "dimensiondefcsname",             shorthand_def_cmd,      dimension_def_csname_code,                       0); */
        tex_primitive(luatex_command, "floatdef",                       shorthand_def_cmd,      float_def_code,                                  0);
        tex_primitive(luatex_command, "fontspecdef",                    shorthand_def_cmd,      fontspec_def_code,                               0);
        tex_primitive(luatex_command, "specificationdef",               shorthand_def_cmd,      specification_def_code,                          0);
        tex_primitive(luatex_command, "gluespecdef",                    shorthand_def_cmd,      gluespec_def_code,                               0);
        tex_primitive(luatex_command, "integerdef",                     shorthand_def_cmd,      integer_def_code,                                0);
     /* tex_primitive(luatex_command, "integerdefcsname",               shorthand_def_cmd,      integer_def_csname_code,                         0); */
        tex_primitive(luatex_command, "luadef",                         shorthand_def_cmd,      lua_def_code,                                    0);
        tex_primitive(tex_command,    "mathchardef",                    shorthand_def_cmd,      math_char_def_code,                              0);
     /* tex_primitive(luatex_command, "mathspecdef",                    shorthand_def_cmd,      mathspec_def_code,                               0); */
        tex_primitive(luatex_command, "mugluespecdef",                  shorthand_def_cmd,      mugluespec_def_code,                             0);
        tex_primitive(tex_command,    "muskipdef",                      shorthand_def_cmd,      muskip_def_code,                                 0);
        tex_primitive(luatex_command, "parameterdef",                   shorthand_def_cmd,      parameter_def_code,                              0);
        tex_primitive(luatex_command, "positdef",                       shorthand_def_cmd,      posit_def_code,                                  0);
        tex_primitive(tex_command,    "skipdef",                        shorthand_def_cmd,      skip_def_code,                                   0);
        tex_primitive(tex_command,    "toksdef",                        shorthand_def_cmd,      toks_def_code,                                   0);
        tex_primitive(luatex_command, "Umathchardef",                   shorthand_def_cmd,      math_uchar_def_code,                             0);
        tex_primitive(luatex_command, "Umathdictdef",                   shorthand_def_cmd,      math_dchar_def_code,                             0);
                                                                                                                                                 
        tex_primitive(luatex_command, "associateunit",                  association_cmd,        unit_association_code,                           0);
                                                                                                                                                 
        tex_primitive(tex_command,    "indent",                         begin_paragraph_cmd,    indent_par_code,                                 0);
        tex_primitive(tex_command,    "noindent",                       begin_paragraph_cmd,    noindent_par_code,                               0);
        tex_primitive(luatex_command, "parattribute",                   begin_paragraph_cmd,    attribute_par_code,                              0);
        tex_primitive(luatex_command, "quitvmode",                      begin_paragraph_cmd,    quitvmode_par_code,                              0);
        tex_primitive(luatex_command, "snapshotpar",                    begin_paragraph_cmd,    snapshot_par_code,                               0);
        tex_primitive(luatex_command, "undent",                         begin_paragraph_cmd,    undent_par_code,                                 0);
        tex_primitive(luatex_command, "wrapuppar",                      begin_paragraph_cmd,    wrapup_par_code,                                 0);
                                                                                                                                                 
        tex_primitive(tex_command,    "dump",                           end_job_cmd,            dump_code,                                       0);
        tex_primitive(tex_command,    "end",                            end_job_cmd,            end_code,                                        0);
                                                                                                                                                 
        tex_primitive(luatex_command, "beginlocalcontrol",              begin_local_cmd,        local_control_begin_code,                        0);
        tex_primitive(luatex_command, "expandedendless",                begin_local_cmd,        expanded_endless_code,                           0);
        tex_primitive(luatex_command, "expandedloop",                   begin_local_cmd,        expanded_loop_code,                              0);
        tex_primitive(luatex_command, "expandedrepeat",                 begin_local_cmd,        expanded_repeat_code,                            0);
        tex_primitive(luatex_command, "localcontrol",                   begin_local_cmd,        local_control_token_code,                        0);
        tex_primitive(luatex_command, "localcontrolled",                begin_local_cmd,        local_control_list_code,                         0);
        tex_primitive(luatex_command, "localcontrolledendless",         begin_local_cmd,        local_control_endless_code,                      0);
        tex_primitive(luatex_command, "localcontrolledloop",            begin_local_cmd,        local_control_loop_code,                         0);
        tex_primitive(luatex_command, "localcontrolledrepeat",          begin_local_cmd,        local_control_repeat_code,                       0);
        tex_primitive(luatex_command, "unexpandedendless",              begin_local_cmd,        unexpanded_endless_code,                         0);
        tex_primitive(luatex_command, "unexpandedloop",                 begin_local_cmd,        unexpanded_loop_code,                            0);
        tex_primitive(luatex_command, "unexpandedrepeat",               begin_local_cmd,        unexpanded_repeat_code,                          0);
                                                                                                                                                 
        tex_primitive(luatex_command, "endlocalcontrol",                end_local_cmd,          normal_code,                                     0);
                                                                                                                                                 
        tex_primitive(tex_command,    "unhbox",                         un_hbox_cmd,            box_code,                                        0);
        tex_primitive(tex_command,    "unhcopy",                        un_hbox_cmd,            copy_code,                                       0);
        tex_primitive(luatex_command, "unhpack",                        un_hbox_cmd,            unpack_code,                                     0);
        tex_primitive(tex_command,    "unvbox",                         un_vbox_cmd,            box_code,                                        0);
        tex_primitive(tex_command,    "unvcopy",                        un_vbox_cmd,            copy_code,                                       0);
        tex_primitive(luatex_command, "unvpack",                        un_vbox_cmd,            unpack_code,                                     0);
                                                                                                                                                 
        tex_primitive(etex_command,   "pagediscards",                   un_vbox_cmd,            page_discards_code,                              0);
        tex_primitive(etex_command,   "splitdiscards",                  un_vbox_cmd,            split_discards_code,                             0);
                                                                                                                                                 
        tex_primitive(luatex_command, "insertunbox",                    un_vbox_cmd,            insert_box_code,                                 0);
        tex_primitive(luatex_command, "insertuncopy",                   un_vbox_cmd,            insert_copy_code,                                0);
                                                                                                                                                 
        tex_primitive(tex_command,    "lower",                          vmove_cmd,              move_forward_code,                               0);
        tex_primitive(tex_command,    "raise",                          vmove_cmd,              move_backward_code,                              0);
                                                                                                                                                 
        tex_primitive(tex_command,    "vfil",                           vskip_cmd,              fi_l_code,                                       0);
        tex_primitive(tex_command,    "vfill",                          vskip_cmd,              fi_ll_code,                                      0);
        tex_primitive(tex_command,    "vfilneg",                        vskip_cmd,              fi_l_neg_code,                                   0);
        tex_primitive(tex_command,    "vskip",                          vskip_cmd,              skip_code,                                       0);
        tex_primitive(tex_command,    "vss",                            vskip_cmd,              fi_ss_code,                                      0);
                                                                                                                                                 
        tex_primitive(tex_command,    "show",                           xray_cmd,               show_code,                                       0);
        tex_primitive(tex_command,    "showbox",                        xray_cmd,               show_box_code,                                   0);
        tex_primitive(luatex_command, "showcodestack",                  xray_cmd,               show_code_stack_code,                            0);
        tex_primitive(etex_command,   "showgroups",                     xray_cmd,               show_groups_code,                                0);
        tex_primitive(luatex_command, "showstack",                      xray_cmd,               show_stack_code,                                 0);
        tex_primitive(etex_command,   "showifs",                        xray_cmd,               show_ifs_code,                                   0);
        tex_primitive(tex_command,    "showlists",                      xray_cmd,               show_lists_code,                                 0);
        tex_primitive(tex_command,    "showthe",                        xray_cmd,               show_the_code,                                   0);
        tex_primitive(etex_command,   "showtokens",                     xray_cmd,               show_tokens_code,                                0);
                                                                                                                                                 
        tex_primitive(luatex_command, "initcatcodetable",               catcode_table_cmd,      init_cat_code_table_code,                        0);
        tex_primitive(luatex_command, "savecatcodetable",               catcode_table_cmd,      save_cat_code_table_code,                        0);
        tex_primitive(luatex_command, "restorecatcodetable",            catcode_table_cmd,      restore_cat_code_table_code,                     0);
     /* tex_primitive(luatex_command, "setcatcodetabledefault",         catcode_table_cmd,      dflt_cat_code_table_code,                        0); */ /* This was an experiment. */
                                                                                                                                                 
        tex_primitive(luatex_command, "alignmark",                      parameter_cmd,          normal_code,                                     0);
        tex_primitive(luatex_command, "parametermark",                  parameter_cmd,          normal_code,                                     0); /* proper primitive for syntax highlighting */
                                                                                                                                                 
        tex_primitive(luatex_command, "aligntab",                       alignment_tab_cmd,      tab_mark_code,                                   0);
                                                                                                                                                 
        tex_primitive(luatex_command, "aligncontent",                   alignment_cmd,          align_content_code,                              0);
        tex_primitive(tex_command,    "cr",                             alignment_cmd,          cr_code,                                         0);
        tex_primitive(tex_command,    "crcr",                           alignment_cmd,          cr_cr_code,                                      0);
        tex_primitive(tex_command,    "noalign",                        alignment_cmd,          no_align_code,                                   0);
        tex_primitive(tex_command,    "omit",                           alignment_cmd,          omit_code,                                       0);
        tex_primitive(luatex_command, "realign",                        alignment_cmd,          re_align_code,                                   0);
        tex_primitive(tex_command,    "span",                           alignment_cmd,          span_code,                                       0);
                                                                                                                                                 
        tex_primitive(luatex_command, "noatomruling",                   math_script_cmd,        math_no_ruling_space_code,                       0);
        tex_primitive(tex_command,    "nonscript",                      math_script_cmd,        math_no_script_space_code,                       0);
        tex_primitive(luatex_command, "nosubprescript",                 math_script_cmd,        math_no_sub_pre_script_code,                     0);
        tex_primitive(luatex_command, "nosubscript",                    math_script_cmd,        math_no_sub_script_code,                         0);
        tex_primitive(luatex_command, "nosuperprescript",               math_script_cmd,        math_no_super_pre_script_code,                   0);
        tex_primitive(luatex_command, "nosuperscript",                  math_script_cmd,        math_no_super_script_code,                       0);
        tex_primitive(luatex_command, "primescript",                    math_script_cmd,        math_prime_script_code,                          0);
        tex_primitive(luatex_command, "indexedsubprescript",            math_script_cmd,        math_indexed_sub_pre_script_code,                0);
        tex_primitive(luatex_command, "indexedsubscript",               math_script_cmd,        math_indexed_sub_script_code,                    0);
        tex_primitive(luatex_command, "indexedsuperprescript",          math_script_cmd,        math_indexed_super_pre_script_code,              0);
        tex_primitive(luatex_command, "indexedsuperscript",             math_script_cmd,        math_indexed_super_script_code,                  0);
        tex_primitive(luatex_command, "subprescript",                   math_script_cmd,        math_sub_pre_script_code,                        0);
        tex_primitive(luatex_command, "subscript",                      math_script_cmd,        math_sub_script_code,                            0);
        tex_primitive(luatex_command, "superprescript",                 math_script_cmd,        math_super_pre_script_code,                      0);
        tex_primitive(luatex_command, "superscript",                    math_script_cmd,        math_super_script_code,                          0);
        tex_primitive(luatex_command, "noscript",                       math_script_cmd,        math_no_script_code,                             0);

        tex_primitive(luatex_command, "copymathatomrule",               math_parameter_cmd,     math_parameter_copy_atom_rule,                   0);
        tex_primitive(luatex_command, "copymathparent",                 math_parameter_cmd,     math_parameter_copy_parent,                      0);
        tex_primitive(luatex_command, "copymathspacing",                math_parameter_cmd,     math_parameter_copy_spacing,                     0);
        tex_primitive(luatex_command, "letmathatomrule",                math_parameter_cmd,     math_parameter_let_atom_rule,                    0);
        tex_primitive(luatex_command, "letmathparent",                  math_parameter_cmd,     math_parameter_let_parent,                       0);
        tex_primitive(luatex_command, "letmathspacing",                 math_parameter_cmd,     math_parameter_let_spacing,                      0);
        tex_primitive(luatex_command, "resetmathspacing",               math_parameter_cmd,     math_parameter_reset_spacing,                    0);
        tex_primitive(luatex_command, "setdefaultmathcodes",            math_parameter_cmd,     math_parameter_set_defaults,                     0);
        tex_primitive(luatex_command, "setmathatomrule",                math_parameter_cmd,     math_parameter_set_atom_rule,                    0);
        tex_primitive(luatex_command, "setmathdisplaypostpenalty",      math_parameter_cmd,     math_parameter_set_display_post_penalty,         0);
        tex_primitive(luatex_command, "setmathdisplayprepenalty",       math_parameter_cmd,     math_parameter_set_display_pre_penalty,          0);
        tex_primitive(luatex_command, "setmathignore",                  math_parameter_cmd,     math_parameter_ignore,                           0);
        tex_primitive(luatex_command, "setmathoptions",                 math_parameter_cmd,     math_parameter_options,                          0);
        tex_primitive(luatex_command, "setmathpostpenalty",             math_parameter_cmd,     math_parameter_set_post_penalty,                 0);
        tex_primitive(luatex_command, "setmathprepenalty",              math_parameter_cmd,     math_parameter_set_pre_penalty,                  0);
        tex_primitive(luatex_command, "setmathspacing",                 math_parameter_cmd,     math_parameter_set_spacing,                      0);

        tex_primitive(luatex_command, "Umathaccentbasedepth",           math_parameter_cmd,     math_parameter_accent_base_depth,                0);
        tex_primitive(luatex_command, "Umathaccentbaseheight",          math_parameter_cmd,     math_parameter_accent_base_height,               0);
        tex_primitive(luatex_command, "Umathaccentbottomovershoot",     math_parameter_cmd,     math_parameter_accent_bottom_overshoot,          0);
        tex_primitive(luatex_command, "Umathaccentbottomshiftdown",     math_parameter_cmd,     math_parameter_accent_bottom_shift_down,         0);
        tex_primitive(luatex_command, "Umathaccentextendmargin",        math_parameter_cmd,     math_parameter_accent_extend_margin,             0);
        tex_primitive(luatex_command, "Umathaccentsuperscriptdrop",     math_parameter_cmd,     math_parameter_accent_superscript_drop,          0);
        tex_primitive(luatex_command, "Umathaccentsuperscriptpercent",  math_parameter_cmd,     math_parameter_accent_superscript_percent,       0);
        tex_primitive(luatex_command, "Umathaccenttopovershoot",        math_parameter_cmd,     math_parameter_accent_top_overshoot,             0);
        tex_primitive(luatex_command, "Umathaccenttopshiftup",          math_parameter_cmd,     math_parameter_accent_top_shift_up,              0);
        tex_primitive(luatex_command, "Umathaccentvariant",             math_parameter_cmd,     math_parameter_degree_variant,                   0);
        tex_primitive(luatex_command, "Umathaxis",                      math_parameter_cmd,     math_parameter_axis,                             0);
     /* tex_primitive(luatex_command, "Umathbinbinspacing",             math_parameter_cmd,     math_parameter_binary_binary_spacing, 0); */ /* Gone, as are more of these! */
        tex_primitive(luatex_command, "Umathbottomaccentvariant",       math_parameter_cmd,     math_parameter_bottom_accent_variant,            0);
        tex_primitive(luatex_command, "Umathconnectoroverlapmin",       math_parameter_cmd,     math_parameter_connector_overlap_min,            0);
        tex_primitive(luatex_command, "Umathdegreevariant",             math_parameter_cmd,     math_parameter_accent_variant,                   0);
        tex_primitive(luatex_command, "Umathdelimiterextendmargin",     math_parameter_cmd,     math_parameter_delimiter_extend_margin,          0);
        tex_primitive(luatex_command, "Umathdelimiterovervariant",      math_parameter_cmd,     math_parameter_delimiter_over_variant,           0);
        tex_primitive(luatex_command, "Umathdelimiterpercent",          math_parameter_cmd,     math_parameter_delimiter_percent,                0);
        tex_primitive(luatex_command, "Umathdelimitershortfall",        math_parameter_cmd,     math_parameter_delimiter_shortfall,              0);
        tex_primitive(luatex_command, "Umathdelimiterundervariant",     math_parameter_cmd,     math_parameter_delimiter_under_variant,          0);
        tex_primitive(luatex_command, "Umathdenominatorvariant",        math_parameter_cmd,     math_parameter_denominator_variant,              0);
        tex_primitive(luatex_command, "Umathextrasubpreshift",          math_parameter_cmd,     math_parameter_extra_subprescript_shift,         0);
        tex_primitive(luatex_command, "Umathextrasubprespace",          math_parameter_cmd,     math_parameter_extra_subprescript_space,         0);
        tex_primitive(luatex_command, "Umathextrasubshift",             math_parameter_cmd,     math_parameter_extra_subscript_shift,            0);
        tex_primitive(luatex_command, "Umathextrasubspace",             math_parameter_cmd,     math_parameter_extra_subscript_space,            0);
        tex_primitive(luatex_command, "Umathextrasuppreshift",          math_parameter_cmd,     math_parameter_extra_superprescript_shift,       0);
        tex_primitive(luatex_command, "Umathextrasupprespace",          math_parameter_cmd,     math_parameter_extra_superprescript_space,       0);
        tex_primitive(luatex_command, "Umathextrasupshift",             math_parameter_cmd,     math_parameter_extra_superscript_shift,          0);
        tex_primitive(luatex_command, "Umathextrasupspace",             math_parameter_cmd,     math_parameter_extra_superscript_space,          0);
        tex_primitive(luatex_command, "Umathsubscriptsnap",             math_parameter_cmd,     math_parameter_subscript_snap,                   0);
        tex_primitive(luatex_command, "Umathsuperscriptsnap",           math_parameter_cmd,     math_parameter_superscript_snap,                 0);
        tex_primitive(luatex_command, "Umathflattenedaccentbasedepth",  math_parameter_cmd,     math_parameter_flattened_accent_base_depth,      0);
        tex_primitive(luatex_command, "Umathflattenedaccentbaseheight", math_parameter_cmd,     math_parameter_flattened_accent_base_height,     0);
        tex_primitive(luatex_command, "Umathflattenedaccentbottomshiftdown", math_parameter_cmd, math_parameter_flattened_accent_bottom_shift_down, 0);
        tex_primitive(luatex_command, "Umathflattenedaccenttopshiftup",      math_parameter_cmd, math_parameter_flattened_accent_top_shift_up,      0);
        tex_primitive(luatex_command, "Umathfractiondelsize",           math_parameter_cmd,     math_parameter_fraction_del_size,                0);
        tex_primitive(luatex_command, "Umathfractiondenomdown",         math_parameter_cmd,     math_parameter_fraction_denom_down,              0);
        tex_primitive(luatex_command, "Umathfractiondenomvgap",         math_parameter_cmd,     math_parameter_fraction_denom_vgap,              0);
        tex_primitive(luatex_command, "Umathfractionnumup",             math_parameter_cmd,     math_parameter_fraction_num_up,                  0);
        tex_primitive(luatex_command, "Umathfractionnumvgap",           math_parameter_cmd,     math_parameter_fraction_num_vgap,                0);
        tex_primitive(luatex_command, "Umathfractionrule",              math_parameter_cmd,     math_parameter_fraction_rule,                    0);
        tex_primitive(luatex_command, "Umathfractionvariant",           math_parameter_cmd,     math_parameter_fraction_variant,                 0);
        tex_primitive(luatex_command, "Umathhextensiblevariant",        math_parameter_cmd,     math_parameter_h_extensible_variant,             0);
        tex_primitive(luatex_command, "Umathlimitabovebgap",            math_parameter_cmd,     math_parameter_limit_above_bgap,                 0);
        tex_primitive(luatex_command, "Umathlimitabovekern",            math_parameter_cmd,     math_parameter_limit_above_kern,                 0);
        tex_primitive(luatex_command, "Umathlimitabovevgap",            math_parameter_cmd,     math_parameter_limit_above_vgap,                 0);
        tex_primitive(luatex_command, "Umathlimitbelowbgap",            math_parameter_cmd,     math_parameter_limit_below_bgap,                 0);
        tex_primitive(luatex_command, "Umathlimitbelowkern",            math_parameter_cmd,     math_parameter_limit_below_kern,                 0);
        tex_primitive(luatex_command, "Umathlimitbelowvgap",            math_parameter_cmd,     math_parameter_limit_below_vgap,                 0);
        tex_primitive(luatex_command, "Umathnolimitsubfactor",          math_parameter_cmd,     math_parameter_nolimit_sub_factor,               0); /* These are bonus parameters. */
        tex_primitive(luatex_command, "Umathnolimitsupfactor",          math_parameter_cmd,     math_parameter_nolimit_sup_factor,               0); /* These are bonus parameters. */
        tex_primitive(luatex_command, "Umathnumeratorvariant",          math_parameter_cmd,     math_parameter_numerator_variant,                0);
        tex_primitive(luatex_command, "Umathoperatorsize",              math_parameter_cmd,     math_parameter_operator_size,                    0);
        tex_primitive(luatex_command, "Umathoverbarkern",               math_parameter_cmd,     math_parameter_overbar_kern,                     0);
        tex_primitive(luatex_command, "Umathoverbarrule",               math_parameter_cmd,     math_parameter_overbar_rule,                     0);
        tex_primitive(luatex_command, "Umathoverbarvgap",               math_parameter_cmd,     math_parameter_overbar_vgap,                     0);
        tex_primitive(luatex_command, "Umathoverdelimiterbgap",         math_parameter_cmd,     math_parameter_over_delimiter_bgap,              0);
        tex_primitive(luatex_command, "Umathoverdelimitervariant",      math_parameter_cmd,     math_parameter_over_delimiter_variant,           0);
        tex_primitive(luatex_command, "Umathoverdelimitervgap",         math_parameter_cmd,     math_parameter_over_delimiter_vgap,              0);
        tex_primitive(luatex_command, "Umathoverlayaccentvariant",      math_parameter_cmd,     math_parameter_overlay_accent_variant,           0);
        tex_primitive(luatex_command, "Umathoverlinevariant",           math_parameter_cmd,     math_parameter_over_line_variant,                0);
        tex_primitive(luatex_command, "Umathprimeraise",                math_parameter_cmd,     math_parameter_prime_raise,                      0);
        tex_primitive(luatex_command, "Umathprimeraisecomposed",        math_parameter_cmd,     math_parameter_prime_raise_composed,             0);
        tex_primitive(luatex_command, "Umathprimeshiftdrop",            math_parameter_cmd,     math_parameter_prime_shift_drop,                 0);
        tex_primitive(luatex_command, "Umathprimeshiftup",              math_parameter_cmd,     math_parameter_prime_shift_up,                   0);
        tex_primitive(luatex_command, "Umathprimespaceafter",           math_parameter_cmd,     math_parameter_prime_space_after,                0);
        tex_primitive(luatex_command, "Umathprimevariant",              math_parameter_cmd,     math_parameter_prime_variant,                    0);
        tex_primitive(luatex_command, "Umathquad",                      math_parameter_cmd,     math_parameter_quad,                             0);
        tex_primitive(luatex_command, "Umathexheight",                  math_parameter_cmd,     math_parameter_exheight,                         0);
        tex_primitive(luatex_command, "Umathradicaldegreeafter",        math_parameter_cmd,     math_parameter_radical_degree_after,             0);
        tex_primitive(luatex_command, "Umathradicaldegreebefore",       math_parameter_cmd,     math_parameter_radical_degree_before,            0);
        tex_primitive(luatex_command, "Umathradicaldegreeraise",        math_parameter_cmd,     math_parameter_radical_degree_raise,             0);
        tex_primitive(luatex_command, "Umathradicalextensibleafter",    math_parameter_cmd,     math_parameter_radical_extensible_after,         0);
        tex_primitive(luatex_command, "Umathradicalextensiblebefore",   math_parameter_cmd,     math_parameter_radical_extensible_before,        0);
        tex_primitive(luatex_command, "Umathradicalkern",               math_parameter_cmd,     math_parameter_radical_kern,                     0);
        tex_primitive(luatex_command, "Umathradicalrule",               math_parameter_cmd,     math_parameter_radical_rule,                     0);
        tex_primitive(luatex_command, "Umathradicalvariant",            math_parameter_cmd,     math_parameter_radical_variant,                  0);
        tex_primitive(luatex_command, "Umathradicalvgap",               math_parameter_cmd,     math_parameter_radical_vgap,                     0);
        tex_primitive(luatex_command, "Umathruledepth",                 math_parameter_cmd,     math_parameter_rule_depth,                       0);
        tex_primitive(luatex_command, "Umathruleheight",                math_parameter_cmd,     math_parameter_rule_height,                      0);
        tex_primitive(luatex_command, "Umathskeweddelimitertolerance",  math_parameter_cmd,     math_parameter_skewed_delimiter_tolerance,       0);
        tex_primitive(luatex_command, "Umathskewedfractionhgap",        math_parameter_cmd,     math_parameter_skewed_fraction_hgap,             0);
        tex_primitive(luatex_command, "Umathskewedfractionvgap",        math_parameter_cmd,     math_parameter_skewed_fraction_vgap,             0);
        tex_primitive(luatex_command, "Umathspaceafterscript",          math_parameter_cmd,     math_parameter_space_after_script,               0);
        tex_primitive(luatex_command, "Umathspacebetweenscript",        math_parameter_cmd,     math_parameter_space_between_script,             0);
        tex_primitive(luatex_command, "Umathspacebeforescript",         math_parameter_cmd,     math_parameter_space_before_script,              0);
        tex_primitive(luatex_command, "Umathstackdenomdown",            math_parameter_cmd,     math_parameter_stack_denom_down,                 0);
        tex_primitive(luatex_command, "Umathstacknumup",                math_parameter_cmd,     math_parameter_stack_num_up,                     0);
        tex_primitive(luatex_command, "Umathstackvariant",              math_parameter_cmd,     math_parameter_stack_variant,                    0);
        tex_primitive(luatex_command, "Umathstackvgap",                 math_parameter_cmd,     math_parameter_stack_vgap,                       0);
        tex_primitive(luatex_command, "Umathsubscriptvariant",          math_parameter_cmd,     math_parameter_subscript_variant,                0);
        tex_primitive(luatex_command, "Umathsubshiftdown",              math_parameter_cmd,     math_parameter_subscript_shift_down,             0);
        tex_primitive(luatex_command, "Umathsubshiftdrop",              math_parameter_cmd,     math_parameter_subscript_shift_drop,             0);
        tex_primitive(luatex_command, "Umathsubsupshiftdown",           math_parameter_cmd,     math_parameter_subscript_superscript_shift_down, 0);
        tex_primitive(luatex_command, "Umathsubsupvgap",                math_parameter_cmd,     math_parameter_subscript_superscript_vgap,       0);
        tex_primitive(luatex_command, "Umathsubtopmax",                 math_parameter_cmd,     math_parameter_subscript_top_max,                0);
        tex_primitive(luatex_command, "Umathsupbottommin",              math_parameter_cmd,     math_parameter_superscript_bottom_min,           0);
        tex_primitive(luatex_command, "Umathsuperscriptvariant",        math_parameter_cmd,     math_parameter_superscript_variant,              0);
        tex_primitive(luatex_command, "Umathsupshiftdrop",              math_parameter_cmd,     math_parameter_superscript_shift_drop,           0);
        tex_primitive(luatex_command, "Umathsupshiftup",                math_parameter_cmd,     math_parameter_superscript_shift_up,             0);
        tex_primitive(luatex_command, "Umathsupsubbottommax",           math_parameter_cmd,     math_parameter_superscript_subscript_bottom_max, 0);
        tex_primitive(luatex_command, "Umathtopaccentvariant",          math_parameter_cmd,     math_parameter_top_accent_variant,               0);
        tex_primitive(luatex_command, "Umathunderbarkern",              math_parameter_cmd,     math_parameter_underbar_kern,                    0);
        tex_primitive(luatex_command, "Umathunderbarrule",              math_parameter_cmd,     math_parameter_underbar_rule,                    0);
        tex_primitive(luatex_command, "Umathunderbarvgap",              math_parameter_cmd,     math_parameter_underbar_vgap,                    0);
        tex_primitive(luatex_command, "Umathunderdelimiterbgap",        math_parameter_cmd,     math_parameter_under_delimiter_bgap,             0);
        tex_primitive(luatex_command, "Umathunderdelimitervariant",     math_parameter_cmd,     math_parameter_under_delimiter_variant,          0);
        tex_primitive(luatex_command, "Umathunderdelimitervgap",        math_parameter_cmd,     math_parameter_under_delimiter_vgap,             0);
        tex_primitive(luatex_command, "Umathunderlinevariant",          math_parameter_cmd,     math_parameter_under_line_variant,               0);
        tex_primitive(luatex_command, "Umathvextensiblevariant",        math_parameter_cmd,     math_parameter_v_extensible_variant,             0);

        tex_primitive(luatex_command, "Umathxscale",                    math_parameter_cmd,     math_parameter_x_scale,                          0);
        tex_primitive(luatex_command, "Umathyscale",                    math_parameter_cmd,     math_parameter_y_scale,                          0);

        tex_primitive(no_command,     "insertedpar",                    end_paragraph_cmd,      inserted_end_paragraph_code,                     0);
        tex_primitive(no_command,     "newlinepar",                     end_paragraph_cmd,      new_line_end_paragraph_code,                     0);
        tex_primitive(tex_command,    "par",                            end_paragraph_cmd,      normal_end_paragraph_code,                       0); /* |too_big_char| */
        tex_primitive(luatex_command, "localbreakpar",                  end_paragraph_cmd,      local_break_end_paragraph_code,                  0);

     /* tex_primitive(luatex_command, "linepar",                        undefined_cs_cmd,       0,                                               0); */ /*tex A user can define this one.*/

        tex_primitive(tex_command,    "endgroup",                       end_group_cmd,          semi_simple_group_code,                          0);
        tex_primitive(luatex_command, "endmathgroup",                   end_group_cmd,          math_simple_group_code,                          0);
        tex_primitive(luatex_command, "endsimplegroup",                 end_group_cmd,          also_simple_group_code,                          0);

        tex_primitive(no_command,     "noexpandrelax",                  relax_cmd,              no_expand_relax_code,                            0);
        tex_primitive(luatex_command, "norelax",                        relax_cmd,              no_relax_code,                                   0);
        tex_primitive(tex_command,    "relax",                          relax_cmd,              relax_code,                                      0);

        tex_primitive(tex_command,    "nullfont",                       set_font_cmd,           null_font,                                       0);

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

        lmt_token_state.par_loc   = tex_prim_lookup(tex_located_string("par"));
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

        cs_text(deep_frozen_cs_dont_expand_code) = tex_maketexstring("notexpanded");
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
