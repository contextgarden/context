/*
    See license.txt in the root of this project.
*/

# ifndef LMT_COMMANDS_H
# define LMT_COMMANDS_H

/*tex

    Before we can go any further, we need to define symbolic names for the internal code numbers
    that represent the various commands obeyed by \TEX. These codes are somewhat arbitrary, but
    not completely so. For example, the command codes for character types are fixed by the
    language, since a user says, e.g., |\catcode `\$ = 3| to make |\char'44| a math delimiter,
    and the command code |math_shift| is equal to~3. Some other codes have been made adjacent so
    that |case| statements in the program need not consider cases that are widely spaced, or so
    that |case| statements can be replaced by |if| statements.

    At any rate, here is the list, for future reference. First come the catcode commands, several
    of which share their numeric codes with ordinary commands when the catcode cannot emerge from
    \TEX's scanning routine.

    Next are the ordinary run-of-the-mill command codes. Codes that are |min_internal| or more
    represent internal quantities that might be expanded by |\the|.

    The next codes are special; they all relate to mode-independent assignment of values to \TEX's
    internal registers or tables. Codes that are |max_internal| or less represent internal
    quantities that might be expanded by |\the|.

    There is no matching primitive to go with |assign_attr|, but even if there was no
    |\attributedef|, a reserved number would still be needed because there is an implied
    correspondence between the |assign_xxx| commands and |xxx_val| expression values. That would
    break down otherwise.

    The remaining command codes are extra special, since they cannot get through \TEX's scanner to
    the main control routine. They have been given values higher than |max_command| so that their
    special nature is easily discernible. The expandable commands come first.

    The extensions on top of standard \TEX\ came with extra |cmd| categories so at some point it
    make sense to normalize soms of that. Similar commands became one category. Some more could be
    combined, like rules and move etc.\ but for now it makes no sense. We could also move the mode
    tests to the runners and make the main lookup simpler. Some commands need their own category
    because they also can bind to characters (like super and subscript).

    Because much now uses |last_item_cmd| this one has been renamed to the more neutral
    |some_item_cmd|.

    Watch out: check |command_names| in |lmttokenlib.c| after adding cmd's as these need to be in
    sync.

    Maybe we should use |box_property|, |font property| and |page property| instead if the now
    split ones. Actually we should drop setting font dimensions.

    todo: some codes -> subtypes (when not related to commands)

*/

/*tex
    Some commands are shared, for instance |car_ret_cmd| is never seen in a token list so it can be
    used for signaling a parameter: |out_param_cmd| in a macro body. These constants relate to the
    21 bit shifting in token properties!

    These two are for nicer syntax highlighting in visual studio code or any IDE that is clever
    enough to recognize enumerations. Otherwise they would get the color of a macro.

    \starttyping
    # define escape_cmd        relax_cmd
    # define out_param_cmd     car_ret_cmd
    # define end_template_cmd  ignore_cmd
    # define active_char_cmd   par_end_cmd
    # define match_cmd         par_end_cmd
    # define comment_cmd       stop_cmd
    # define end_match_cmd     stop_cmd
    # define invalid_char_cmd  delimiter_num_cmd
    \stoptyping

    In the end sharing these command codes (as regular \TEX\ does) with character codes is not worth
    the trouble because it gives fuzzy cmd codes in the \LUA\ token interface (and related tracing)
    so at the cost of some extra slots they now are unique. The |foo_token| macros have to match the
    cmd codes! Be aware that you need to map the new cmd names onto the original ones when you
    consult the \TEX\ program source.

    As a consequence of having more commands, the need to be distinctive in the \LUA\ token interface,
    some commands have been combined (at the cost of a little overhead in testing chr codes). Some
    names have been made more generic as a side effect but the principles remain the same. Sorry for
    any introduced confusion.

    An example of where some cmd codes were collapsed is alignments: |\omit|, |\span|, |\noalign|,
    |\cr| and |\crcr| are now all handled by one cmd/chr code combination. This might make it a bit
    easier to extend alignments when we're at it because it brings some code and logic together (of
    course the principles are the same, but there can be slight differences in the way errors are
    reported).
*/


typedef enum tex_command_code {
    /*tex
        The first 16 command codes are used for characters with a special meaning. In traditional
        \TEX\ some have different names and also aliases. because we have a public token interface
        they now are uniquely used for characters and the aliases have their own cmd/chr codes.
    */
    escape_cmd,                       /*tex  0: escape delimiter*/
    left_brace_cmd,                   /*tex  1: beginning of a group */
    right_brace_cmd,                  /*tex  2: ending of a group */
    math_shift_cmd,                   /*tex  3: mathematics shift character */
    alignment_tab_cmd,                /*tex  4: alignment delimiter */
    end_line_cmd,                     /*tex  5: end of line */
    parameter_cmd,                    /*tex  6: macro parameter symbol */
    superscript_cmd,                  /*tex  7: superscript */
    subscript_cmd,                    /*tex  8: subscript */
    ignore_cmd,                       /*tex  9: characters to ignore */
    spacer_cmd,                       /*tex 10: characters equivalent to blank space */
    letter_cmd,                       /*tex 11: characters regarded as letters */
    other_char_cmd,                   /*tex 12: none of the special character types */
    active_char_cmd,                  /*tex 13: characters that invoke macros */
    comment_cmd,                      /*tex 14: characters that introduce comments */
    invalid_char_cmd,                 /*tex 15: characters that shouldn't appear (|^^|) */
    /*tex
        The next set of commands is handled in the big switch where interpretation depends
        on the current mode. It is a chicken or egg choice: either we have one runner per
        command in which the mode is chosen, or we have a runner for each mode. The later is
        used in \TEX.
    */
    relax_cmd,                        /*tex do nothing (|\relax|) */
    end_template_cmd,                 /*tex end of |v_j| list in alignment template */
    alignment_cmd,                    /*tex |\cr|, |\crcr| and |\span| */
    match_cmd,                        /*tex match a macro parameter */
    end_match_cmd,                    /*tex end of parameters to macro */
    parameter_reference_cmd,          /*tex the value passed as parameter */
    end_paragraph_cmd,                /*tex end of paragraph (|\par|) */
    end_job_cmd,                      /*tex end of job (|\end|, |\dump|) */
    delimiter_number_cmd,             /*tex specify delimiter numerically (|\delimiter|) */
    char_number_cmd,                  /*tex character specified numerically (|\char|) */
    math_char_number_cmd,             /*tex explicit math code (|mathchar} ) */
    set_mark_cmd,                     /*tex mark definition (|mark|) */
    node_cmd,                         /*tex a node injected via \LUA */
    xray_cmd,                         /*tex peek inside of \TEX\ (|\show|, |\showbox|, etc.) */
    make_box_cmd,                     /*tex make a box (|\box|, |\copy|, |\hbox|, etc.) */
    hmove_cmd,                        /*tex horizontal motion (|\moveleft|, |\moveright|) */
    vmove_cmd,                        /*tex vertical motion (|\raise|, |\lower|) */
    un_hbox_cmd,                      /*tex unglue a box (|\unhbox|, |\unhcopy|) */
    un_vbox_cmd,                      /*tex unglue a box (|\unvbox|, |\unvcopy|, |\pagediscards|, |\splitdiscards|) */
    remove_item_cmd,                  /*tex nullify last item (|\unpenalty|, |\unkern|, |\unskip|) */
    hskip_cmd,                        /*tex horizontal glue (|\hskip|, |\hfil|, etc.) */
    vskip_cmd,                        /*tex vertical glue (|\vskip|, |\vfil|, etc.) */
    mskip_cmd,                        /*tex math glue (|\mskip|) */
    kern_cmd,                         /*tex fixed space (|\kern|) */
    mkern_cmd,                        /*tex math kern (|\mkern|) */
    leader_cmd,                       /*tex all these |\leaders| */
    legacy_cmd,                       /*tex obsolete |\shipout|,etc.) */
    local_box_cmd,                    /*tex use a box (|\localleftbox|, etc.) */
    halign_cmd,                       /*tex horizontal table alignment (|\halign|) */
    valign_cmd,                       /*tex vertical table alignment (|\valign|) */
    vrule_cmd,                        /*tex vertical rule (|\vrule|, etc.) */
    hrule_cmd,                        /*tex horizontal rule (|\hrule|. etc.) */
    insert_cmd,                       /*tex vlist inserted in box (|\insert|) */
    vadjust_cmd,                      /*tex vlist inserted in enclosing paragraph (|\vadjust|) */
    ignore_something_cmd,             /*tex gobble |spacer| tokens (|\ignorespaces|) */
    after_something_cmd,              /*tex save till assignment or group is done (|\after*|) */
    penalty_cmd,                      /*tex additional badness (|\penalty|) */
    begin_paragraph_cmd,              /*tex (begin) paragraph (|\indent|, |\noindent|) */
    italic_correction_cmd,            /*tex italic correction (|/|) */
    accent_cmd,                       /*tex attach accent in text (|\accent|) */
    math_accent_cmd,                  /*tex attach accent in math (|\mathaccent|) */
    discretionary_cmd,                /*tex discretionary texts (|-|, |\discretionary|) */
    equation_number_cmd,              /*tex equation number (|\eqno|, |\leqno|) */
    math_fence_cmd,                   /*tex variable delimiter (|\left|, |\right| or |\middle|) part of a fence */
    math_component_cmd,               /*tex component of formula (|\mathbin|, etc.) */
    math_modifier_cmd,                /*tex limit conventions (|\displaylimits|, etc.) */
    math_fraction_cmd,                /*tex generalized fraction (|\above|, |\atop|, etc.) */
    math_style_cmd,                   /*tex style specification (|\displaystyle|, etc.) */
    math_choice_cmd,                  /*tex choice specification (|\mathchoice|) */
    vcenter_cmd,                      /*tex vertically center a vbox (|\vcenter|) */
    case_shift_cmd,                   /*tex force specific case (|\lowercase|, |\uppercase|) */
    message_cmd,                      /*tex send to user (|\message|, |\errmessage|) */
    catcode_table_cmd,                /*tex manipulators for catcode tables */
    end_local_cmd,                    /*tex finishes a |local_cmd| */
    lua_function_call_cmd,            /*tex an expandable function call */
    lua_protected_call_cmd,           /*tex a function call that doesn's expand in edef like situations */
    begin_group_cmd,                  /*tex begin local grouping (|\begingroup|) */
    end_group_cmd,                    /*tex end local grouping (|\endgroup|) */
    explicit_space_cmd,               /*tex explicit space (|\ |) */
    boundary_cmd,                     /*tex insert boundry node with value (|\*boundary|) */
    math_radical_cmd,                 /*tex square root and similar signs (|\radical|) */
    math_script_cmd,                  /*tex explicit super- or subscript */
    math_shift_cs_cmd,                /*tex start- and endmath */
    end_cs_name_cmd,                  /*tex end control sequence (|\endcsname|) */
    /*tex
        The next set can come after |\the| so they are either handled in the big switch or
        during expansion of this serializer prefix.
    */
    char_given_cmd,                   /*tex character code defined by |\chardef| */
 // math_char_given_cmd,              /*tex math code defined by |\mathchardef| */
 // math_char_xgiven_cmd,             /*tex math code defined by |\Umathchardef| or |\Umathcharnumdef| */
    some_item_cmd,                    /*tex most recent item (|\lastpenalty|, |\lastkern|, |\lastskip| and more) */
    /*tex
       The previous command was described as \quotation {the last that cannot be prefixed by
       |\global|} which is not entirely true any more. Actually more accurate is that the next
       bunch can be prefixed and that's a mixed bag. It is used in |handle_assignments| which
       deals with assignments in some special cases.
    */
    internal_toks_cmd,                /*tex special token list (|\output|, |\everypar|, etc.) */
    register_toks_cmd,                /*tex user defined token lists */
    internal_int_cmd,                 /*tex integer (|\tolerance|, |\day|, etc.) */
    register_int_cmd,                 /*tex user-defined integers */
    internal_attribute_cmd,           /*tex */
    register_attribute_cmd,           /*tex user-defined attributes */
    internal_dimen_cmd,               /*tex length (|\hsize|, etc.) */
    register_dimen_cmd,               /*tex user-defined dimensions */
    internal_glue_cmd,                /*tex glue (|\baselineskip|, etc.) */
    register_glue_cmd,                /*tex user-defined glue */
    internal_mu_glue_cmd,             /*tex */
    register_mu_glue_cmd,             /*tex user-defined math glue */
    lua_value_cmd,                    /*tex reference to a regular lua function */
    iterator_value_cmd,
    set_font_property_cmd,            /*tex user-defined font integer (|\hyphenchar|, |\skewchar|) or (|\fontdimen|)  */
    set_auxiliary_cmd,                /*tex state info (|\spacefactor|, |\prevdepth|) */
    set_page_property_cmd,            /*tex page info (|\pagegoal|, etc.) */
    set_box_property_cmd,             /*tex change property of box (|\wd|, |\ht|, |\dp|) */
    set_specification_cmd,            /*tex specifications (|\parshape|, |\interlinepenalties|, etc.) */
    define_char_code_cmd,             /*tex define a character code (|\catcode|, etc.) */
    define_family_cmd,                /*tex declare math fonts (|\textfont|, etc.) */
    set_math_parameter_cmd,           /*tex set math parameters (|\mathquad|, etc.) */
    set_font_cmd,                     /*tex set current font (font identifiers) */
    define_font_cmd,                  /*tex define a font file (|\font|) */
    integer_cmd,                      /*tex the equivalent is a halfword number */
    dimension_cmd,                    /*tex the equivalent is a halfword number representing a dimension */
    gluespec_cmd,                     /*tex the equivalent is a halfword reference to glue */
    mugluespec_cmd,                   /*tex the equivalent is a halfword reference to glue with math units */
    mathspec_cmd,
    fontspec_cmd,
    register_cmd,                     /*tex internal register (|\count|, |\dimen|, etc.) */
 /* string_cmd, */                    /*tex discarded experiment but maybe ... */
    combine_toks_cmd,                 /*tex the |toksapp| and similar token (list) combiners */
    /*tex
        That was the last command that could follow |\the|.
    */
    arithmic_cmd,                     /*tex |\advance|, |\multiply|, |\divide|, ... */
    prefix_cmd,                       /*tex qualify a definition (|\global|, |\long|, |\outer|) */
    let_cmd,                          /*tex assign a command code (|\let|, |\futurelet|) */
    shorthand_def_cmd,                /*tex code definition (|\chardef|, |\countdef|, etc.) */
    def_cmd,                          /*tex macro definition (|\def|, |\gdef|, |\xdef|, |\edef|) */
    set_box_cmd,                      /*tex set a box (|\setbox|) */
    hyphenation_cmd,                  /*tex hyphenation data (|\hyphenation|, |\patterns|) */
    set_interaction_cmd,              /*tex define level of interaction (|\batchmode|, etc.) */
    /*tex
        Here ends the section that is part of the big switch.  What follows are commands that are
        intercepted when expanding tokens. The strint one came from a todo list and moved to a
        maybe list.
    */
    undefined_cs_cmd,                 /*tex initial state of most |eq_type| fields */
    expand_after_cmd,                 /*tex special expansion (|\expandafter|) */
    no_expand_cmd,                    /*tex special nonexpansion (|\noexpand|) */
    input_cmd,                        /*tex input a source file (|\input|, |\endinput| or |\scantokens| or |\scantextokens|) */
    lua_call_cmd,                     /*tex a reference to a \LUA\ function */
    lua_local_call_cmd,               /*tex idem, but in a nested main loop */
    begin_local_cmd,                  /*tex enter a a nested main loop */
    if_test_cmd,                      /*tex conditional text (|\if|, |\ifcase|, etc.) */
    cs_name_cmd,                      /*tex make a control sequence from tokens (|\csname|) */
    convert_cmd,                      /*tex convert to text (|\number|, |\string|, etc.) */
    the_cmd,                          /*tex expand an internal quantity (|\the| or |\unexpanded|, |\detokenize|) */
    get_mark_cmd,                     /*tex inserted mark (|\topmark|, etc.) */
 /* string_cmd, */
    /*tex
        These refer to macros. We might at some point promote the tolerant ones to have their own
        cmd codes. Protected macros were done with an initial token signaling that property but
        they became |protected_call_cmd|. After that we also got two frozen variants and later four
        tolerant so we ended up with eight. When I wanted some more, a different solution was
        chosen, so now we have just one again instead of |[tolerant_][frozen_][protected_]call_cmd|.
        But ... in the end I setteled again for four basic call commands because it's nicer in
        the token interface.

        The todo cmds come from a todo list and relate to |\expand| but then like \expand{...} even
        when normally it's protected. But it adds overhead we don't want right now an din the end I
        didn't need it. I keep it as reference so that I won't recycle it.

    */
    call_cmd,                         /*tex regular control sequence */
    protected_call_cmd,               /*tex idem but doesn't expand in edef like situations */
    semi_protected_call_cmd,
    tolerant_call_cmd,                /*tex control sequence with tolerant arguments */
    tolerant_protected_call_cmd,      /*tex idem but doesn't expand in edef like situations */
    tolerant_semi_protected_call_cmd,
    /*tex
        These are special and are inserted in token streams. They cannot end up in macros.
    */
    deep_frozen_end_template_cmd,     /*tex end of an alignment template */
    deep_frozen_dont_expand_cmd,      /*tex the following token was marked by |\noexpand|) */
    /*tex
        The next bunch is never seen directly as they are shortcuts to registers and special data
        strutures. They  are the internal register (pseudo) commands and are also needed for
        token and node memory management.
    */
    internal_glue_reference_cmd,      /*tex the equivalent points to internal glue specification */
    register_glue_reference_cmd,      /*tex the equivalent points to register glue specification */
    internal_mu_glue_reference_cmd,   /*tex the equivalent points to internal muglue specification */
    register_mu_glue_reference_cmd,   /*tex the equivalent points to egister muglue specification */
    internal_box_reference_cmd,       /*tex the equivalent points to internal box node, or is |null| */
    register_box_reference_cmd,       /*tex the equivalent points to register box node, or is |null| */
    internal_toks_reference_cmd,      /*tex the equivalent points to internal token list */
    register_toks_reference_cmd,      /*tex the equivalent points to register token list */
    specification_reference_cmd,      /*tex the equivalent points to parshape or penalties specification */
    /*
        We don't really need these but they are used to flag the registers eq entries properly. They
        are not really references because the values are included but we want to be consistent here.
    */
    internal_int_reference_cmd,
    register_int_reference_cmd,
    internal_attribute_reference_cmd,
    register_attribute_reference_cmd,
    internal_dimen_reference_cmd,
    register_dimen_reference_cmd,
    /*tex
        This is how many commands we have:
    */
    number_tex_commands,
} tex_command_code;

# define max_char_code_cmd    invalid_char_cmd    /*tex largest catcode for individual characters */
# define min_internal_cmd     char_given_cmd      /*tex the smallest code that can follow |the| */
# define max_non_prefixed_cmd some_item_cmd       /*tex largest command code that can't be |global| */
# define max_internal_cmd     register_cmd        /*tex the largest code that can follow |the| */
# define max_command_cmd      set_interaction_cmd /*tex the largest command code seen at |big_switch| */

# define first_cmd            escape_cmd
# define last_cmd             register_dimen_reference_cmd

# define first_call_cmd       call_cmd
# define last_call_cmd        tolerant_semi_protected_call_cmd

# define last_visible_cmd     tolerant_semi_protected_call_cmd

# define is_call_cmd(cmd)           (cmd >= first_call_cmd && cmd <= last_call_cmd)
# define is_protected_cmd(cmd)      (cmd == protected_call_cmd || cmd == tolerant_protected_call_cmd)
# define is_semi_protected_cmd(cmd) (cmd == semi_protected_call_cmd || cmd == tolerant_semi_protected_call_cmd)
# define is_tolerant_cmd(cmd)       (cmd == tolerant_call_cmd || cmd == tolerant_protected_call_cmd || cmd == tolerant_semi_protected_call_cmd)

# define is_referenced_cmd(cmd)     (cmd >= call_cmd)
# define is_nodebased_cmd(cmd)      (cmd >= gluespec_cmd && cmd <= fontspec_cmd)


# if (main_control_mode == 1)

/*tex Once these were different numbers, no series: */

typedef enum tex_modes {
    nomode,
    vmode,
    hmode,
    mmode,
} tex_modes;

# else

typedef enum tex_modes {
    nomode = 0,
    vmode  = 1,                           /*tex vertical mode */
    hmode  = 1 +    max_command_cmd + 1,  /*tex horizontal mode */
    mmode  = 1 + 2*(max_command_cmd + 1), /*tex math mode */
} tex_modes;

# endif

typedef enum arithmic_codes {
    advance_code,
    multiply_code,
    divide_code,
 /* bitwise_and_code, */
 /* bitwise_xor_code, */
 /* bitwise_or_code,  */
 /* bitwise_not_code, */
} arithmic_codes;

# define last_arithmic_code divide_code

typedef enum math_script_codes {
    math_no_script_code,
    math_no_ruling_code,
    math_sub_script_code,
    math_super_script_code,
    math_super_pre_script_code,
    math_sub_pre_script_code,
    math_no_sub_script_code,
    math_no_super_script_code,
    math_no_sub_pre_script_code,
    math_no_super_pre_script_code,
    math_shifted_sub_script_code,
    math_shifted_super_script_code,
    math_shifted_sub_pre_script_code,
    math_shifted_super_pre_script_code,
    math_prime_script_code,
} math_script_codes;

# define last_math_script_code math_prime_script_code

typedef enum math_fraction_codes {
    math_above_code,
    math_above_delimited_code,
    math_over_code,
    math_over_delimited_code,
    math_atop_code,
    math_atop_delimited_code,
    math_u_above_code,
    math_u_above_delimited_code,
    math_u_over_code,
    math_u_over_delimited_code,
    math_u_atop_code,
    math_u_atop_delimited_code,
    math_u_skewed_code,
    math_u_skewed_delimited_code,
    math_u_stretched_code,
    math_u_stretched_delimited_code,
} math_fraction_codes;

# define last_math_fraction_code math_u_skewed_code

/*tex
    These don't fit into the internal register model because they are for instance global or
    bound to the current list.
*/

typedef enum auxiliary_codes {
    space_factor_code,
    prev_depth_code,
    prev_graf_code,
    interaction_mode_code,
    insert_mode_code,
} auxiliary_codes;

# define last_auxiliary_code insert_mode_code

typedef enum convert_codes {
    number_code,               /*tex command code for |\number| */
    to_integer_code,           /*tex command code for |\tointeger| (also gobbles |\relax|) */
    to_hexadecimal_code,       /*tex command code for |\tohexadecimal| */
    to_scaled_code,            /*tex command code for |\toscaled| (also gobbles |\relax|) */
    to_sparse_scaled_code,     /*tex command code for |\tosparsescaled| (also gobbles |\relax|) */
    to_dimension_code,         /*tex command code for |\todimension| (also gobbles |\relax|) */
    to_sparse_dimension_code,  /*tex command code for |\tosparsedimension| */
    to_mathstyle_code,         /*tex command code for |\tomathstyle| */
    lua_code,                  /*tex command code for |\directlua| */
    lua_function_code,         /*tex command code for |\luafunction| */
    lua_bytecode_code,         /*tex command code for |\luabytecode| */
    expanded_code,             /*tex command code for |\expanded| */
    semi_expanded_code,        /*tex command code for |\constantexpanded| */
    string_code,               /*tex command code for |\string| */
    cs_string_code,            /*tex command code for |\csstring| */
    detokenized_code,          /*tex command code for |\detokenized| */
    roman_numeral_code,        /*tex command code for |\romannumeral| */
    meaning_code,              /*tex command code for |\meaning| */
    meaning_full_code,         /*tex command code for |\meaningfull| */
    meaning_less_code,         /*tex command code for |\meaningless| */
    meaning_asis_code,         /*tex command code for |\meaningasis| */
    uchar_code,                /*tex command code for |\Uchar| */
    lua_escape_string_code,    /*tex command code for |\luaescapestring| */
    font_name_code,            /*tex command code for |\fontname| */
    font_specification_code,   /*tex command code for |\fontspecification| */
    job_name_code,             /*tex command code for |\jobname| */
    format_name_code,          /*tex command code for |\AlephVersion| */
    luatex_banner_code,        /*tex command code for |\luatexbanner| */
    font_identifier_code,      /*tex command code for |tex.fontidentifier| (virtual) */
} convert_codes;

# define first_convert_code number_code
# define last_convert_code  luatex_banner_code

typedef enum input_codes {
    normal_input_code,
    end_of_input_code,
    token_input_code,
    tex_token_input_code,
    /* for now private */
    tokenized_code,
    retokenized_code,
    quit_loop_code,
} input_codes;

# define last_input_code tex_token_input_code

typedef enum some_item_codes {
    lastpenalty_code,           /*tex |\lastpenalty| */
    lastkern_code,              /*tex |\lastkern| */
    lastskip_code,              /*tex |\lastskip| */
    lastboundary_code,          /*tex |\lastboundary| */
    last_node_type_code,        /*tex |\lastnodetype| */
    last_node_subtype_code,     /*tex |\lastnodesubtype| */
    input_line_no_code,         /*tex |\inputlineno| */
    badness_code,               /*tex |\badness| */
    overshoot_code,             /*tex |\overshoot| */
    luatex_version_code,        /*tex |\luatexversion| */
    luatex_revision_code,       /*tex |\luatexrevision| */
    current_group_level_code,   /*tex |\currentgrouplevel| */
    current_group_type_code,    /*tex |\currentgrouptype| */
    current_if_level_code,      /*tex |\currentiflevel| */
    current_if_type_code,       /*tex |\currentiftype| */
    current_if_branch_code,     /*tex |\currentifbranch| */
    glue_stretch_order_code,    /*tex |\gluestretchorder| */
    glue_shrink_order_code,     /*tex |\glueshrinkorder| */
    font_id_code,               /*tex |\fontid| */
    glyph_x_scaled_code,        /*tex |\glyphxscaled| */
    glyph_y_scaled_code,        /*tex |\glyphyscaled| */
    font_char_wd_code,          /*tex |\fontcharwd| */
    font_char_ht_code,          /*tex |\fontcharht| */
    font_char_dp_code,          /*tex |\fontchardp| */
    font_char_ic_code,          /*tex |\fontcharic| */
    font_char_ta_code,          /*tex |\fontcharta| */
    font_spec_id_code,          /*tex |\fontspecid| */
    font_spec_scale_code,       /*tex |\fontspecscale| */
    font_spec_xscale_code,      /*tex |\fontspecxscale| */
    font_spec_yscale_code,      /*tex |\fontspecyscale| */
    font_size_code,             /*tex |\fontsize| */
    font_math_control_code,     /*tex |\fontmathcontrol| */
    font_text_control_code,     /*tex |\fonttextcontrol| */
    math_scale_code,            /*tex |\mathscale| */
    math_style_code,            /*tex |\mathstyle| */
    math_main_style_code,       /*tex |\mathmainstyle| */
    math_style_font_id_code,    /*tex |\mathstylefontid| */
    math_stack_style_code,      /*tex |\mathstackstyle| */
    math_char_class_code,       /*tex |\Umathcharclass| */
    math_char_fam_code,         /*tex |\Umathcharfam| */
    math_char_slot_code,        /*tex |\Umathcharslot| */
    scaled_slant_per_point_code,
    scaled_interword_space_code,
    scaled_interword_stretch_code,
    scaled_interword_shrink_code,
    scaled_ex_height_code,
    scaled_em_width_code,
    scaled_extra_space_code,
    last_arguments_code,        /*tex |\lastarguments| */
    parameter_count_code,       /*tex |\parametercount| */
 /* lua_value_function_code, */ /*tex |\luavaluefunction| */
    insert_progress_code,       /*tex |\insertprogress| */
    left_margin_kern_code,      /*tex |\leftmarginkern| */
    right_margin_kern_code,     /*tex |\rightmarginkern| */
    par_shape_length_code,      /*tex |\parshapelength| */
    par_shape_indent_code,      /*tex |\parshapeindent| */
    par_shape_dimen_code,       /*tex |\parshapedimen| */
    glue_stretch_code,          /*tex |\gluestretch| */
    glue_shrink_code,           /*tex |\glueshrink| */
    mu_to_glue_code,            /*tex |\mutoglue| */
    glue_to_mu_code,            /*tex |\gluetomu| */
    numexpr_code,               /*tex |\numexpr| */
 /* attrexpr_code, */           /*tex not used */
    dimexpr_code,               /*tex |\dimexpr| */
    glueexpr_code,              /*tex |\glueexpr| */
    muexpr_code,                /*tex |\muexpr| */
    numexpression_code,         /*tex |\numexpression| */
    dimexpression_code,         /*tex |\dimexpression| */
    last_chk_num_code,          /*tex |\ifchknum| */
    last_chk_dim_code,          /*tex |\ifchkdim| */
 // dimen_to_scale_code,        /*tex |\dimentoscale| */
    numeric_scale_code,         /*tex |\numericscale| */
    index_of_register_code,
    index_of_character_code,
    math_atom_glue_code,
    last_left_class_code,
    last_right_class_code,
    last_atom_class_code,
    current_loop_iterator_code,
    current_loop_nesting_code,
    last_loop_iterator_code,
    last_par_context_code,
    last_page_extra_code,
} some_item_codes;

# define last_some_item_code last_page_extra_code

typedef enum catcode_table_codes {
    save_cat_code_table_code,
    init_cat_code_table_code,
 /* dflt_cat_code_table_code, */
} catcode_table_codes;

# define last_catcode_table_code init_cat_code_table_code

typedef enum font_property_codes {
    font_hyphen_code,
    font_skew_code,
    font_lp_code,
    font_rp_code,
    font_ef_code,
    font_dimen_code,
    scaled_font_dimen_code,
} font_property_codes;

# define last_font_property_code scaled_font_dimen_code

typedef enum box_property_codes {
    box_width_code,
    box_height_code,
    box_depth_code,
    box_direction_code,
    box_geometry_code,
    box_orientation_code,
    box_anchor_code,
    box_anchors_code,
    box_source_code,
    box_target_code,
    box_xoffset_code,
    box_yoffset_code,
    box_xmove_code,
    box_ymove_code,
    box_total_code,
    box_shift_code,
    box_adapt_code,
    box_repack_code,
    box_freeze_code,
    /* we actually need set_box_int_cmd, or set_box_property */
    box_attribute_code,
} box_property_codes;

# define last_box_property_code box_attribute_code

typedef enum hyphenation_codes {
    hyphenation_code,
    patterns_code,
    prehyphenchar_code,
    posthyphenchar_code,
    preexhyphenchar_code,
    postexhyphenchar_code,
    hyphenationmin_code,
    hjcode_code,
} hyphenation_codes;

# define last_hyphenation_code hjcode_code

typedef enum begin_paragraph_codes {
    noindent_par_code,
    indent_par_code,
    quitvmode_par_code,
    undent_par_code,
    snapshot_par_code,
    attribute_par_code,
    wrapup_par_code,
} begin_paragraph_codes;

# define last_begin_paragraph_code wrapup_par_code

extern void tex_initialize_commands (void);

/*tex

   A |\chardef| creates a control sequence whose |cmd| is |char_given|; a |\mathchardef| creates a
   control sequence whose |cmd| is |math_given|; and the corresponding |chr| is the character code
   or math code. A |\countdef| or |\dimendef| or |\skipdef| or |\muskipdef| creates a control
   sequence whose |cmd| is |assign_int| or \dots\ or |assign_mu_glue|, and the corresponding |chr|
   is the |eqtb| location of the internal register in question.

    We have the following codes for |shorthand_def|:

*/

typedef enum relax_codes {
    relax_code,
    no_relax_code,
    no_expand_relax_code,
} relax_codes;

# define last_relax_code no_relax_code

typedef enum end_paragraph_codes {
    normal_end_paragraph_code,
    inserted_end_paragraph_code,
    new_line_end_paragraph_code,
} end_paragraph_codes;

# define last_end_paragraph_code new_line_end_paragraph_code

typedef enum shorthand_def_codes {
    char_def_code,        /*tex |\chardef| */
    math_char_def_code,   /*tex |\mathchardef| */
    math_xchar_def_code,  /*tex |\Umathchardef| */
    math_dchar_def_code,  /*tex |\Umathdictdef| */
 /* math_uchar_def_code,  */ /* |\Umathcharnumdef| */
    count_def_code,       /*tex |\countdef| */
    attribute_def_code,   /*tex |\attributedef| */
    dimen_def_code,       /*tex |\dimendef| */
    skip_def_code,        /*tex |\skipdef| */
    mu_skip_def_code,     /*tex |\muskipdef| */
    toks_def_code,        /*tex |\toksdef| */
 /* string_def_code, */
    lua_def_code,         /*tex |\luadef| */
    integer_def_code,
    dimension_def_code,
    gluespec_def_code,
    mugluespec_def_code,
 /* mathspec_def_code, */
    fontspec_def_code,
} shorthand_def_codes;

# define last_shorthand_def_code fontspec_def_code

typedef enum char_number_codes {
    char_number_code,  /*tex |\char| */
    glyph_number_code, /*tex |\glyph| */
} char_number_codes;

# define last_char_number_code glyph_number_code

typedef enum math_char_number_codes {
    math_char_number_code,  /*tex |\mathchar| */
    math_xchar_number_code, /*tex |\Umathchar| */
    math_dchar_number_code, /*tex |\Umathdict| */
 /* math_uchar_number_code, */ /* |\Umathcharnum| */
    math_class_number_code, /*tex |\Umathclass| */
} math_char_number_codes;

# define last_math_char_number_code math_class_number_code

typedef enum xray_codes {
    show_code,        /*tex |\show| */
    show_box_code,    /*tex |\showbox| */
    show_the_code,    /*tex |\showthe| */
    show_lists_code,  /*tex |\showlists| */
    show_groups_code, /*tex |\showgroups| */
    show_tokens_code, /*tex |\showtokens|, must be odd! */
    show_ifs_code,    /*tex |\showifs| */
} xray_codes;

# define last_xray_code show_ifs_code

typedef enum the_codes {
    the_code,
    the_without_unit_code,
 /* the_with_property_code, */ /* replaced by value functions */
    detokenize_code,
    unexpanded_code,
} the_codes;

# define last_the_code unexpanded_code

typedef enum expand_after_codes {
    expand_after_code,
    expand_unless_code,
    future_expand_code,
    future_expand_is_code,      /*tex nicer than: future_expand_ignore_spaces_code */
    future_expand_is_ap_code,   /*tex nicer than: future_expand_ignore_spaces_and_pars_code */
 /* expand_after_2_code, */
 /* expand_after_3_code, */
    expand_after_spaces_code,
    expand_after_pars_code,
    expand_token_code,
    expand_cs_token_code,
    expand_code,
    semi_expand_code,
    expand_after_toks_code,
 /* expand_after_fi, */
} expand_after_codes;

# define last_expand_after_code expand_after_toks_code

typedef enum after_something_codes {
    after_group_code,
    after_assignment_code,
    at_end_of_group_code,
    after_grouped_code,
    after_assigned_code,
    at_end_of_grouped_code,
} after_something_codes;

# define last_after_something_code at_end_of_grouped_code

typedef enum begin_group_codes {
    semi_simple_group_code,
    also_simple_group_code,
    math_simple_group_code,
} begin_group_codes;

# define last_begin_group_code also_simple_group_code

typedef enum end_job_codes {
    end_code,
    dump_code,
} end_job_codes;

# define last_end_job_code dump_code

typedef enum local_control_codes {
    local_control_begin_code,
    local_control_token_code,
    local_control_list_code,
    local_control_loop_code,
    expanded_loop_code,
    unexpanded_loop_code,
} local_control_codes;

# define last_local_control_code unexpanded_loop_code

/*tex

    Maybe also a prefix |\unfrozen| that avoids the warning or have a variant that only issues a
    warning but then we get 8 more cmd codes and we don't want that. An alternative is to have some
    bits for this but we don't have enough. Now, because frozen macros can be unfrozen we can
    indeed have a prefix that bypasses the check. Explicit (re)definitions are then up to the user.

*/

typedef enum prefix_codes {
    frozen_code,
    permanent_code,
    immutable_code,
 /* primitive_code, */
    mutable_code,
    noaligned_code,
    instance_code,
    untraced_code,
    global_code,
    tolerant_code,
    protected_code,
    overloaded_code,
    aliased_code,
    immediate_code,
 /* conditional_code */
 /* value_code */
    semiprotected_code,
    enforced_code,
    always_code,
    inherited_code,
    long_code,
    outer_code,
} prefix_codes;

# define last_prefix_code enforced_code

typedef enum combine_toks_codes {
    expanded_toks_code,
    append_toks_code,
    append_expanded_toks_code,
    prepend_toks_code,
    prepend_expanded_toks_code,
    global_expanded_toks_code,
    global_append_toks_code,
    global_append_expanded_toks_code,
    global_prepend_toks_code,
    global_prepend_expanded_toks_code,
} combine_toks_codes;

# define last_combine_toks_code global_prepend_expanded_toks_code

typedef enum cs_name_codes {
    cs_name_code,
    last_named_cs_code,
    begin_cs_name_code,
    future_cs_name_code,
} cs_name_codes;

# define last_cs_name_code begin_cs_name_code

typedef enum def_codes {
    expanded_def_code,
    def_code,
    global_expanded_def_code,
    global_def_code,
    expanded_def_csname_code,
    def_csname_code,
    global_expanded_def_csname_code,
    global_def_csname_code,
} def_codes;

# define last_def_code global_def_csname_code

typedef enum let_codes {
    global_let_code,
    let_code,
    future_let_code,
    future_def_code,
    let_charcode_code,
    swap_cs_values_code,
    let_protected_code,
    unlet_protected_code,
    let_frozen_code,
    unlet_frozen_code,
    let_csname_code,
    global_let_csname_code,
    let_to_nothing_code,
    global_let_to_nothing_code,
} let_codes;

# define last_let_code global_let_csname_code

typedef enum message_codes {
    message_code,
    error_message_code,
} message_codes;

# define last_message_code error_message_code

/*tex

    These are no longer needed, but we keep them as reference:

    \starttyping
    typedef enum in_stream_codes {
        close_stream_code,
        open_stream_code,
    } in_stream_codes;

    # define last_in_stream_code open_stream_code

    typedef enum read_to_cs_codes {
        read_code,
        read_line_code,
    } read_to_cs_codes;

    # define last_read_to_cs_code read_line_code
    \stoptyping

*/

typedef enum lua_call_codes {
    lua_function_call_code,
    lua_bytecode_call_code,
} lua_codes;

typedef enum math_delimiter_codes {
    math_delimiter_code,
    math_udelimiter_code,
} math_delimiter_codes;

# define last_math_delimiter_code math_udelimiter_code

typedef enum math_choice_codes {
    math_choice_code,
    math_discretionary_code,
    math_ustack_code,
} math_choice_codes;

# define last_math_choice_code math_ustack_code

typedef enum math_accent_codes {
    math_accent_code,
    math_uaccent_code,
} math_accent_codes;

# define last_math_accent_code math_uaccent_code

typedef enum lua_value_codes {
    lua_value_none_code,
    lua_value_integer_code,
    lua_value_cardinal_code,
    lua_value_dimension_code,
    lua_value_skip_code,
    lua_value_boolean_code,
    lua_value_float_code,
    lua_value_string_code,
    lua_value_node_code,
    lua_value_direct_code,
    /*tex total number of lua values */
    number_lua_values,
} lua_value_codes;

typedef enum math_shift_cs_codes {
    begin_inline_math_code,
    end_inline_math_code,
    begin_display_math_code,
    end_display_math_code,
    begin_math_mode_code,
    end_math_mode_code,
} math_shift_cs_codes;

# define first_math_shift_cs_code begin_inline_math_code
# define last_math_shift_cs_code  end_math_mode_code

/*tex
    The next base and offset are what we always had so we keep it but we do use a proper zero based
    chr code that we adapt to the old value in the runner, so from then on we're in old mode again.

    \starttyping
    # define leader_ship_base   (a_leaders - 1)
    # define leader_ship_offset (leader_flag - a_leaders)
    \stoptyping

    Internal boxes are kind of special as they can have different scanners and as such they don't
    really fit in the rest of the internals. Now, for consistency we treat local boxes as internal
    ones but if we ever need more (which is unlikely) we can have a dedicated local_box_base. If
    we ever extend the repertoire of interal boxes we havbe to keep the local ones at the start.

*/

typedef enum legacy_codes {
    shipout_code,
} legacy_codes;

# define first_legacy_code shipout_code
# define last_legacy_code  shipout_code

typedef enum leader_codes {
    a_leaders_code,
    c_leaders_code,
    x_leaders_code,
    g_leaders_code,
    u_leaders_code,
} leader_codes;

# define first_leader_code a_leaders_code
# define last_leader_code  u_leaders_code

typedef enum local_box_codes {
    local_left_box_code,
    local_right_box_code,
    local_middle_box_code,
    /* room for more but then we go internal_box_codes */
    number_box_pars,
} local_box_codes;

# define first_local_box_code local_left_box_code
# define last_local_box_code  local_middle_box_code

typedef enum local_box_options {
    local_box_par_option   = 0x1,
    local_box_local_option = 0x2,
    local_box_keep_option  = 0x4,
} local_box_options;

typedef enum skip_codes {
    fil_code,     /*tex |\hfil| and |\vfil| */
    fill_code,    /*tex |\hfill| and |\vfill| */
    filll_code,   /*tex |\hss| and |\vss|, aka |ss_code| */
    fil_neg_code, /*tex |\hfilneg| and |\vfilneg| */
    skip_code,    /*tex |\hskip| and |\vskip| */
    mskip_code,   /*tex |\mskip| */
} skip_codes;

# define first_skip_code fil_code
# define last_skip_code  skip_code

/*tex All kind of character related codes: */

typedef enum charcode_codes {
    catcode_charcode,
    lccode_charcode,
    uccode_charcode,
    sfcode_charcode,
    hccode_charcode,
    hmcode_charcode,
    mathcode_charcode,
    extmathcode_charcode,
 /* extmathcodenum_charcode, */
    delcode_charcode,
    extdelcode_charcode,
 /* extdelcodenum_charcode, */
} charcode_codes;

# define first_charcode_code catcode_charcode
/*define last_charcode_code  extdelcodenum_charcode */
# define last_charcode_code  extdelcode_charcode

typedef enum math_styles {
    display_style,               /*tex |\displaystyle| */
    cramped_display_style,       /*tex |\crampeddisplaystyle| */
    text_style,                  /*tex |\textstyle| */
    cramped_text_style,          /*tex |\crampedtextstyle| */
    script_style,                /*tex |\scriptstyle| */
    cramped_script_style,        /*tex |\crampedscriptstyle| */
    script_script_style,         /*tex |\scriptscriptstyle| */
    cramped_script_script_style, /*tex |\crampedscriptscriptstyle| */
    /* hidden */
    yet_unset_math_style,
    former_choice_math_style,
    scaled_math_style,
    /* even more hidden */       /*tex These can be used to emulate the defaults. */
    all_display_styles,
    all_text_styles,
    all_script_styles,
    all_script_script_styles,
    all_math_styles,
    all_split_styles,
    all_uncramped_styles,
    all_cramped_styles,
} math_styles;

# define first_math_style display_style
# define last_math_style  all_cramped_styles

# define is_valid_math_style(n)   (n >= display_style   && n <= cramped_script_script_style)
# define are_valid_math_styles(n) (n >= all_display_styles && n <= all_cramped_styles)

inline static halfword tex_math_style_to_size(halfword s)
{
    if (s == script_style || s == cramped_script_style) {
        return script_size;
    } else if (s == script_style || s == cramped_script_style) {
        return script_script_size;
    } else {
        return text_size;
    }
}

typedef enum math_choices {
    math_display_choice,
    math_text_choice,
    math_script_choice,
    math_script_script_choice,
} math_choices;

typedef enum math_discretionary_choices {
    math_pre_break_choice,
    math_post_break_choice,
    math_no_break_choice,
} math_discretionary_choices;

typedef enum math_aboves {
    math_numerator_above,
    math_denominator_above,
} math_aboves;

typedef enum math_limits {
    math_limits_top,
    math_limits_bottom,
} math_limits;

typedef enum dir_codes {
    dir_lefttoright,
    dir_righttoleft
} dir_codes;

typedef enum quantitity_levels {
    level_zero, /*tex level for undefined quantities */
    level_one,  /*tex outermost level for defined quantities */
} quantitity_levels;

typedef enum move_codes {
    move_forward_code,
    move_backward_code,
} move_codes;

# define last_move_code move_backward_code

typedef enum ignore_something_codes {
    ignore_space_code,
    ignore_par_code,
    ignore_argument_code,
} ignore_something_codes;

# define last_ignore_something_code ignore_argument_code

typedef enum case_shift_codes {
    lower_case_code,
    upper_case_code,
} case_shift_codes;

# define last_case_shift_code upper_case_code

typedef enum location_codes {
    left_location_code,
    right_location_code,
    top_location_code,
    bottom_location_code,
} location_codes;

# define first_location_code left_location_code
# define last_location_code  right_location_code

typedef enum remove_item_codes {
    kern_item_code,
    penalty_item_code,
    skip_item_code,
    boundary_item_code,
} remove_item_codes;

# define last_remove_item_code boundary_item_code

typedef enum kern_codes {
    normal_kern_code,
    h_kern_code,              /* maybe */
    v_kern_code,              /* maybe */
    non_zero_width_kern_code, /* maybe */
} kern_codes;

# define last_kern_code normal_kern_code

typedef enum tex_mskip_codes {
    normal_mskip_code,
    atom_mskip_code,
} tex_mskip_codes;

# define last_mskip_code atom_mskip_code

/*tex
    All the other cases are zero but we use an indicator for that.
*/

# define normal_code 0

# endif
