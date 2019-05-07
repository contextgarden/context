/*
    See license.txt in the root of this project.
*/

# ifndef COMMANDS_H
# define COMMANDS_H

/*tex

Before we can go any further, we need to define symbolic names for the internal
code numbers that represent the various commands obeyed by \TEX. These codes are
somewhat arbitrary, but not completely so. For example, the command codes for
character types are fixed by the language, since a user says, e.g., |\catcode `\$
= 3| to make |\char'44| a math delimiter, and the command code |math_shift| is
equal to~3. Some other codes have been made adjacent so that |case| statements in
the program need not consider cases that are widely spaced, or so that |case|
statements can be replaced by |if| statements.

At any rate, here is the list, for future reference. First come the catcode
commands, several of which share their numeric codes with ordinary commands when
the catcode cannot emerge from \TEX's scanning routine.

Next are the ordinary run-of-the-mill command codes. Codes that are
|min_internal| or more represent internal quantities that might be expanded by
|\the|.

The next codes are special; they all relate to mode-independent assignment of
values to \TeX's internal registers or tables. Codes that are |max_internal| or
less represent internal quantities that might be expanded by |\the|.

There is no matching primitive to go with |assign_attr|, but even if there was no
|\attributedef|, a reserved number would still be needed because there is an
implied correspondence between the |assign_xxx| commands and |xxx_val| expression
values. That would break down otherwise.

The remaining command codes are extra special, since they cannot get through
\TEX's scanner to the main control routine. They have been given values higher
than |max_command| so that their special nature is easily discernible. The
expandable commands come first.

*/

typedef enum {
    relax_cmd = 0,                        /*tex do nothing (|\relax|) */
# define escape_cmd  relax_cmd            /*tex escape delimiter*/
    left_brace_cmd,                       /*tex beginning of a group */
    right_brace_cmd,                      /*tex ending of a group */
    math_shift_cmd,                       /*tex mathematics shift character */
    tab_mark_cmd,                         /*tex alignment delimiter (also |\span|) */
    car_ret_cmd,                          /*tex end of line (|carriage_return|, |\cr|, |\crcr|) */
# define out_param_cmd  car_ret_cmd       /*tex output a macro parameter */
    mac_param_cmd,                        /*tex macro parameter symbol */
    sup_mark_cmd,                         /*tex superscript */
    sub_mark_cmd,                         /*tex subscript */
    endv_cmd,                             /*tex end of |v_j| list in alignment template */
# define ignore_cmd endv_cmd              /*tex characters to ignore */
    spacer_cmd,                           /*tex characters equivalent to blank space */
    letter_cmd,                           /*tex characters regarded as letters */
    other_char_cmd,                       /*tex none of the special character types */
    par_end_cmd,                          /*tex end of paragraph (|\par|) */
# define active_char_cmd par_end_cmd      /*tex characters that invoke macros */
# define match_cmd par_end_cmd            /*tex match a macro parameter */
    stop_cmd,                             /*tex end of job (|\end|, |\dump|) */
# define comment_cmd stop_cmd             /*tex characters that introduce comments */
# define end_match_cmd stop_cmd           /*tex end of parameters to macro */
    delim_num_cmd,                        /*tex specify delimiter numerically (|\delimiter|) */
# define invalid_char_cmd delim_num_cmd   /*tex characters that shouldn't appear (|^^|) */
# define max_char_code_cmd delim_num_cmd  /*tex largest catcode for individual characters */
    char_num_cmd,                         /*tex character specified numerically (|\char|) */
    math_char_num_cmd,                    /*tex explicit math code (|mathchar} ) */
    mark_cmd,                             /*tex mark definition (|mark|) */
    node_cmd,
    xray_cmd,                             /*tex peek inside of \TeX\ (|show|, |showbox|, etc.) */
    make_box_cmd,                         /*tex make a box (|box|, |copy|, |hbox|, etc.) */
    hmove_cmd,                            /*tex horizontal motion (|moveleft|, |moveright|) */
    vmove_cmd,                            /*tex vertical motion (|raise|, |lower|) */
    un_hbox_cmd,                          /*tex unglue a box (|unhbox|, |unhcopy|) */
    un_vbox_cmd,                          /*tex unglue a box (|unvbox|, |unvcopy|, |pagediscards|, |splitdiscards|) */
    remove_item_cmd,                      /*tex nullify last item (|unpenalty|, |unkern|, |unskip|) */
    hskip_cmd,                            /*tex horizontal glue (|hskip|, |hfil|, etc.) */
    vskip_cmd,                            /*tex vertical glue (|vskip|, |vfil|, etc.) */
    mskip_cmd,                            /*tex math glue (|mskip|) */
    kern_cmd,                             /*tex fixed space (|kern|) */
    mkern_cmd,                            /*tex math kern (|mkern|) */
    leader_ship_cmd,                      /*tex use a box (|shipout|, |leaders|, etc.) */
    halign_cmd,                           /*tex horizontal table alignment (|halign|) */
    valign_cmd,                           /*tex vertical table alignment (|valign|) */
    no_align_cmd,                         /*tex temporary escape from alignment (|noalign|) */
    vrule_cmd,                            /*tex vertical rule (|vrule|) */
    hrule_cmd,                            /*tex horizontal rule (|hrule|) */
    insert_cmd,                           /*tex vlist inserted in box (|insert|) */
    vadjust_cmd,                          /*tex vlist inserted in enclosing paragraph (|vadjust|) */
    ignore_spaces_cmd,                    /*tex gobble |spacer| tokens (|ignorespaces|) */
    after_assignment_cmd,                 /*tex save till assignment is done (|afterassignment|) */
    after_group_cmd,                      /*tex save till group is done (|aftergroup|) */
    break_penalty_cmd,                    /*tex additional badness (|penalty|) */
    start_par_cmd,                        /*tex begin paragraph (|indent|, |noindent|) */
    ital_corr_cmd,                        /*tex italic correction (|/|) */
    accent_cmd,                           /*tex attach accent in text (|accent|) */
    math_accent_cmd,                      /*tex attach accent in math (|mathaccent|) */
    discretionary_cmd,                    /*tex discretionary texts (|-|, |discretionary|) */
    eq_no_cmd,                            /*tex equation number (|eqno|, |leqno|) */
    left_right_cmd,                       /*tex variable delimiter (|left|, |right| or |middle|) */
    math_comp_cmd,                        /*tex component of formula (|mathbin|, etc.) */
    limit_switch_cmd,                     /*tex diddle limit conventions (|displaylimits|, etc.) */
    above_cmd,                            /*tex generalized fraction (|above|, |atop|, etc.) */
    math_style_cmd,                       /*tex style specification (|displaystyle|, etc.) */
    math_choice_cmd,                      /*tex choice specification (|mathchoice|) */
    non_script_cmd,                       /*tex conditional math glue (|nonscript|) */
    vcenter_cmd,                          /*tex vertically center a vbox (|vcenter|) */
    case_shift_cmd,                       /*tex force specific case (|lowercase|, |uppercase|) */
    message_cmd,                          /*tex send to user (|message|, |errmessage|) */
    catcode_table_cmd,
    end_local_cmd,
    lua_function_call_cmd,
    lua_bytecode_call_cmd,
    lua_call_cmd,
    in_stream_cmd,                        /*tex files for reading (|openin|, |closein|) */
    begin_group_cmd,                      /*tex begin local grouping (|begingroup|) */
    end_group_cmd,                        /*tex end local grouping (|endgroup|) */
    omit_cmd,                             /*tex omit alignment template (|omit|) */
    ex_space_cmd,                         /*tex explicit space (|\ |) */
    boundary_cmd,                         /*tex insert boundry node with value (|*boundary|) */
    radical_cmd,                          /*tex square root and similar signs (|radical|) */
    super_sub_script_cmd,                 /*tex explicit super- or subscript */
    no_super_sub_script_cmd,              /*tex explicit no super- or subscript */
    math_shift_cs_cmd,                    /*tex start- and endmath */
    end_cs_name_cmd,                      /*tex end control sequence (|endcsname|) */
    char_ghost_cmd,                       /*tex |leftghost|, |rightghost| character for kerning */
    assign_local_box_cmd,                 /*tex box for guillemets |localleftbox| or |localrightbox| */
    char_given_cmd,                       /*tex character code defined by |chardef| */
# define min_internal_cmd char_given_cmd  /*tex the smallest code that can follow |the| */
    math_given_cmd,                       /*tex math code defined by |mathchardef| */
    xmath_given_cmd,                      /*tex math code defined by |Umathchardef| or |Umathcharnumdef| */
    last_item_cmd,                        /*tex most recent item (|lastpenalty|, |lastkern|, |lastskip|) */
# define max_non_prefixed_command_cmd last_item_cmd     /*tex largest command code that can't be |global| */
    toks_register_cmd,                    /*tex token list register (|toks|) */
    assign_toks_cmd,                      /*tex special token list (|output|, |everypar|, etc.) */
    assign_int_cmd,                       /*tex user-defined integer (|tolerance|, |day|, etc.) */
    assign_attr_cmd,                      /*tex  user-defined attributes  */
    assign_dimen_cmd,                     /*tex user-defined length (|hsize|, etc.) */
    assign_glue_cmd,                      /*tex user-defined glue (|baselineskip|, etc.) */
    assign_mu_glue_cmd,                   /*tex user-defined muglue (|thinmuskip|, etc.) */
    assign_font_dimen_cmd,                /*tex user-defined font dimension (|fontdimen|) */
    assign_font_int_cmd,                  /*tex user-defined font integer (|hyphenchar|, |skewchar|) */
    assign_hang_indent_cmd,
    set_aux_cmd,                          /*tex specify state info (|spacefactor|, |prevdepth|) */
    set_prev_graf_cmd,                    /*tex specify state info (|prevgraf|) */
    set_page_dimen_cmd,                   /*tex specify state info (|pagegoal|, etc.) */
    set_page_int_cmd,                     /*tex specify state info (|deadcycles|,  |insertpenalties|) */
    set_box_dimen_cmd,                    /*tex change dimension of box (|wd|, |ht|, |dp|) */
    set_tex_shape_cmd,                    /*tex specify fancy paragraph shape (|parshape|) */
    set_etex_shape_cmd,                   /*tex specify etex extended list (|interlinepenalties|, etc.) */
    def_char_code_cmd,                    /*tex define a character code (|catcode|, etc.) */
    def_del_code_cmd,                     /*tex define a delimiter code (|delcode|) */
    extdef_math_code_cmd,                 /*tex define an extended character code (|Umathcode|, etc.) */
    extdef_del_code_cmd,                  /*tex define an extended delimiter code (|Udelcode|, etc.) */
    def_family_cmd,                       /*tex declare math fonts (|textfont|, etc.) */
    set_math_param_cmd,                   /*tex set math parameters (|mathquad|, etc.) */
    set_font_cmd,                         /*tex set current font ( font identifiers ) */
    def_font_cmd,                         /*tex define a font file (|font|) */
    register_cmd,                         /*tex internal register (|count|, |dimen|, etc.) */
    assign_box_direction_cmd,             /*tex (|boxdirection|) */
    assign_direction_cmd,                 /*tex (|textdirection| etc) */
# define max_internal_cmd assign_direction_cmd  /*tex the largest code that can follow |the| */
    advance_cmd,                          /*tex advance a register or parameter (|advance|) */
    multiply_cmd,                         /*tex multiply a register or parameter (|multiply|) */
    divide_cmd,                           /*tex divide a register or parameter (|divide|) */
    prefix_cmd,                           /*tex qualify a definition (|global|, |long|, |outer|) */
    let_cmd,                              /*tex assign a command code (|let|, |futurelet|) */
    shorthand_def_cmd,                    /*tex code definition (|chardef|, |countdef|, etc.) */
    def_lua_call_cmd,
    read_to_cs_cmd,                       /*tex read into a control sequence (|read|) */
    def_cmd,                              /*tex macro definition (|def|, |gdef|, |xdef|, |edef|) */
    set_box_cmd,                          /*tex set a box (|setbox|) */
    hyph_data_cmd,                        /*tex hyphenation data (|hyphenation|, |patterns|) */
    set_interaction_cmd,                  /*tex define level of interaction (|batchmode|, etc.) */
    set_font_id_cmd,
    undefined_cs_cmd,                     /*tex initial state of most |eq_type| fields */
    expand_after_cmd,                     /*tex special expansion (|expandafter|) */
    no_expand_cmd,                        /*tex special nonexpansion (|noexpand|) */
    input_cmd,                            /*tex input a source file (|input|, |endinput| or |scantokens| or |scantextokens|) */
    lua_expandable_call_cmd,
    lua_local_call_cmd,
    if_test_cmd,                          /*tex conditional text (|if|, |ifcase|, etc.) */
    fi_or_else_cmd,                       /*tex delimiters for conditionals (|else|, etc.) */
    cs_name_cmd,                          /*tex make a control sequence from tokens (|csname|) */
    convert_cmd,                          /*tex convert to text (|number|, |string|, etc.) */
    the_cmd,                              /*tex expand an internal quantity (|the| or |unexpanded|, |detokenize|) */
    combine_toks_cmd,
    top_bot_mark_cmd,                     /*tex inserted mark (|topmark|, etc.) */
    call_cmd,                             /*tex non-long, non-outer control sequence */
    long_call_cmd,                        /*tex long, non-outer control sequence */
    outer_call_cmd,                       /*tex non-long, outer control sequence */
    long_outer_call_cmd,                  /*tex long, outer control sequence */
    end_template_cmd,                     /*tex end of an alignment template */
    dont_expand_cmd,                      /*tex the following token was marked by |noexpand|) */
    glue_ref_cmd,                         /*tex the equivalent points to a glue specification */
    shape_ref_cmd,                        /*tex the equivalent points to a parshape specification */
    box_ref_cmd,                          /*tex the equivalent points to a box node, or is |null| */
    data_cmd,                             /*tex the equivalent is simply a halfword number */
} tex_command_code;

# define max_command_cmd set_font_id_cmd  /*tex the largest command code seen at |big_switch| */
# define last_cmd data_cmd
# define max_non_prefixed_command last_item_cmd

typedef enum {
    above_code = 0,
    over_code = 1,
    atop_code = 2,
    skewed_code = 3,
    delimited_code = 4,
} fraction_codes;

typedef enum {
    number_code = 0,            /*tex command code for |\number| */
    lua_code,                   /*tex command code for |\directlua| */
    lua_function_code,          /*tex command code for |\luafunction| */
    lua_bytecode_code,          /*tex command code for |\luabytecode| */
    expanded_code,              /*tex command code for |\expanded| */
    immediate_assignment_code,  /*tex command code for |\immediateassignmentv */
    immediate_assigned_code,    /*tex command code for |\assigned| */
    math_style_code,            /*tex command code for |\mathstyle| */
    string_code,                /*tex command code for |\string| */
    cs_string_code,             /*tex command code for |\csstring| */
    roman_numeral_code,         /*tex command code for |\romannumeral| */
    meaning_code,               /*tex command code for |\meaning| */
    uchar_code,                 /*tex command code for |\Uchar| */
    lua_escape_string_code,     /*tex command code for |\luaescapestring| */
    font_id_code,               /*tex command code for |\fontid| */
    font_name_code,             /*tex command code for |\fontname| */
    left_margin_kern_code,      /*tex command code for |\leftmarginkern| */
    right_margin_kern_code,     /*tex command code for |\rightmarginkern| */
    math_char_class_code,
    math_char_fam_code,
    math_char_slot_code,
    insert_ht_code,             /*tex command code for |\insertht| */
    job_name_code,              /*tex command code for |\jobname| */
    format_name_code,           /*tex command code for |\AlephVersion| */
    luatex_banner_code,         /*tex command code for |\luatexbanner| */
    luatex_revision_code,       /*tex command code for |\luatexrevision| */
    etex_code,                  /*tex command code for |\eTeXVersion| */
    eTeX_revision_code,         /*tex command code for |\eTeXrevision| */
    font_identifier_code,       /*tex command code for |tex.fontidentifier| (virtual) */
    /* backend */
} convert_codes;

typedef enum {
    lastpenalty_code = 0,                 /*tex code for |\lastpenalty| */
    lastattr_code,                        /*tex not used */
    lastkern_code,                        /*tex code for |\lastkern| */
    lastskip_code,                        /*tex code for |\lastskip| */
    last_node_type_code,                  /*tex code for |\lastnodetype| */
    input_line_no_code,                   /*tex code for |\inputlineno| */
    badness_code,                         /*tex code for |\badness| */
    luatex_version_code,                  /*tex code for |\luatexversion| */
    eTeX_minor_version_code,              /*tex code for |\eTeXminorversion| */
    eTeX_version_code,                    /*tex code for |\eTeXversion| */
# define eTeX_int eTeX_version_code       /*tex first of \ETEX\ codes for integers */
    current_group_level_code,             /*tex code for |\currentgrouplevel| */
    current_group_type_code,              /*tex code for |\currentgrouptype| */
    current_if_level_code,                /*tex code for |\currentiflevel| */
    current_if_type_code,                 /*tex code for |\currentiftype| */
    current_if_branch_code,               /*tex code for |\currentifbranch| */
    glue_stretch_order_code,              /*tex code for |\gluestretchorder| */
    glue_shrink_order_code,               /*tex code for |\glueshrinkorder| */
    font_char_wd_code,                    /*tex code for |\fontcharwd| */
# define eTeX_dim font_char_wd_code       /*tex first of \ETEX\ codes for dimensions */
    font_char_ht_code,                    /*tex code for |\fontcharht| */
    font_char_dp_code,                    /*tex code for |\fontchardp| */
    font_char_ic_code,                    /*tex code for |\fontcharic| */
    par_shape_length_code,                /*tex code for |\parshapelength| */
    par_shape_indent_code,                /*tex code for |\parshapeindent| */
    par_shape_dimen_code,                 /*tex code for |\parshapedimen| */
    glue_stretch_code,                    /*tex code for |\gluestretch| */
    glue_shrink_code,                     /*tex code for |\glueshrink| */
    mu_to_glue_code,                      /*tex code for |\mutoglue| */
# define eTeX_glue mu_to_glue_code        /*tex first of \ETEX\ codes for glue */
    glue_to_mu_code,                      /*tex code for |\gluetomu| */
# define eTeX_mu glue_to_mu_code          /*tex first of \ETEX\ codes for muglue */
    numexpr_code,                         /*tex code for |\numexpr| */
# define eTeX_expr numexpr_code           /*tex first of \ETEX\ codes for expressions */
    attrexpr_code,                        /*tex not used */
    dimexpr_code,                         /*tex code for |\dimexpr| */
    glueexpr_code,                        /*tex code for |\glueexpr| */
    muexpr_code,                          /*tex code for |\muexpr| */
} last_item_codes;

typedef enum {
    save_cat_code_table_code=0,
    init_cat_code_table_code,
} catcode_table_codes;

typedef enum {
    lp_code_base = 2,
    rp_code_base = 3,
    ef_code_base = 4
} font_codes ;

extern void initialize_commands(void);

# endif
