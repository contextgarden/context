/*
    See license.txt in the root of this project.
*/

# ifndef LMT_EQUIVALENTS_H
# define LMT_EQUIVALENTS_H

# include "tex/textypes.h"

/*tex

    Like the preceding parameters, the following quantities can be changed at compile time to extend
    or reduce \TEX's capacity. But if they are changed, it is necessary to rerun the initialization
    program |INITEX| to generate new tables for the production \TEX\ program. One can't simply make
    helter-skelter changes to the following constants, since certain rather complex initialization
    numbers are computed from them. They are defined here using \WEB\ macros, instead of being put
    into \PASCAL's |const| list, in order to emphasize this distinction.

    The original token interface at the \LUA\ end used the \quote {real} chr values that are offsets
    into the table of equivalents. However, that is sort of fragile when one also provides ways to
    construct tokens. For that reason the \LUAMETATEX\ interface is a bit more abstract and therefore
    can do some testing. After all, the real numbers don't matter. This means that registers for
    instance run from |0..65535| (without the region offsets).

    In order to make this easier the token registers are now more consistent with the other registers
    in the sense that there is no longer a special cmd for those registers. This was not that hard to
    do because most code already was sort of prepared for that move.

    Now, there is one \quote {complication}: integers, dimensions etc references can be registers but
    also internal variables. This means that we cannot simply remap the eq slots they refer to. When
    we offset by some base (the first register) we end up with negative indices for the internal ones
    because they come before this 64K range. So, this is why the \LUA\ interface works with negative
    numbers for internal variables.

    Another side effect is that we now have the mu glue internals in the muglue region. This is
    possible because we have separated the subtypes from the chr codes. I might also relocate the
    special things (like penalties) some day.

    In a couple of cases a specific chr was used that made it possible to share for instance setters.
    Examples are |\mkern| and |\mskip|. This resulted is (sort of) funny single numbers in the token
    interface, so we have that now normalized as well (at the cost of a few split functions). Of course
    that doesn't change the concept, unless one considers the fact that we have more granularity in
    node subtypes (no longer parallel to the codes, as there are more) an issue. (Actually we can now
    easily introduce hkern and vkern if we want.)

*/

/*tex

    Each entry in |eqtb| is a |memoryword|. Most of these words are of type |two_halves|, and
    subdivided into three fields:

    \startitemize

    \startitem
        The |eq_level| (a quarterword) is the level of grouping at which this equivalent was
        defined. If the level is |level_zero|, the equivalent has never been defined;
        |level_one| refers to the outer level (outside of all groups), and this level is also
        used for global definitions that never go away. Higher levels are for equivalents that
        will disappear at the end of their group.
    \stopitem

    \startitem
        The |eq_type| (another quarterword) specifies what kind of entry this is. There are many
        types, since each \TEX\ primitive like |\hbox|, |\def|, etc., has its own special code.
        The list of command codes above includes all possible settings of the |eq_type| field.
    \stopitem

    \startitem
        The |equiv| (a halfword) is the current equivalent value. This may be a font number, a
        pointer into |mem|, or a variety of other things.
    \stopitem

    \stopitemize

    Many locations in |eqtb| have symbolic names. The purpose of the next paragraphs is to define
    these names, and to set up the initial values of the equivalents.

    In the first region we have a single entry for the \quote {null csname} of length zero. In
    \LUATEX, the active characters and and single-letter control sequence names are part of the
    next region.

    Then comes region 2, which corresponds to the hash table that we will define later. The maximum
    address in this region is used for a dummy control sequence that is perpetually undefined.
    There also are several locations for control sequences that are perpetually defined (since they
    are used in error recovery).

    Region 3 of |eqtb| contains the |number_regs| |\skip| registers, as well as the glue parameters
    defined here. It is important that the \quote {muskip} parameters have larger numbers than the
    others.

    Region 4 of |eqtb| contains the local quantities defined here. The bulk of this region is taken
    up by five tables that are indexed by eight-bit characters; these tables are important to both
    the syntactic and semantic portions of \TEX. There are also a bunch of special things like font
    and token parameters, as well as the tables of |\toks| and |\box| registers.

    Region 5 of |eqtb| contains the integer parameters and registers defined here, as well as the
    |del_code| table. The latter table differs from the |cat_code..math_code| tables that precede it,
    since delimiter codes are fullword integers while the other kinds of codes occupy at most a
    halfword. This is what makes region~5 different from region~4. We will store the |eq_level|
    information in an auxiliary array of quarterwords that will be defined later.

    The integer parameters should really be initialized by a macro package; the following
    initialization does the minimum to keep \TEX\ from complete failure.

    The final region of |eqtb| contains the dimension parameters defined here, and the |number_regs|
    |\dimen| registers.

    Beware: in \LUATEX\ we have so many characters (\UNICODE) that we use a dedicated hash system
    for special codes, math properties etc. This means that we have less in the regions than mentioned
    here. On the other hand, we do have more registers (attributes) so that makes it a bit larger again.

    The registers get marked as being \quote {undefined} commands. We could actually gove them a the
    right commmand code etc.\ bur for now we just use the ranges as traditional \TEX\ does.

    Most of the symbolic names and hard codes numbers are not enumerations. There is still room for
    improvement and occasionally I enter a new round of doing that. However, it talkes a lot of time
    and checking (more than writing from scratch) as we need to make sure it all behaves like \TEX\
    does. Quite some code went through several stages of reaching this abstraction, just to make sure
    that it kept working. These intermediate versions ended up in the \CONTEXT\ distribution to that
    any issue would show up soon. A rather major step was splitting the |assign_*_cmd|s into
    internal and register commands and ranges. This was a side effect of getting the token interface
    at the \LUA\ end a bit nicer; there is really no need to expose the user to codes that demand
    catching up with the \TEX\ internals when we can just provide a nice interface.

    The font location is kind of special as it holds a halfword data field that points to a font
    accessor and as such doesn't fit into a counter concept. Otherwise we could have made it a
    counter. We could probably just use a font id and do a lookup elsewhere because this engine is
    already doing it differently. So, eventually this needs checking.

*/

/*
    For practical reasons we have the regions a bit different. For instance, we also have attributes, local
    boxes, no math characters here, etc. Maybe specification codes sould get their own region.

    HASH FROZEN
    [I|R]FONTS
    UNDEFINED
    [I|R]GLUE
    [I|R]MUGLUE
    [I|R]TOKS
    [I|R]BOXES
    [I|R]INT
    [I|R]ATTR
    [I|R]DIMEN
    SPECIFICATIONS
    EQUIVPLUS

    When I'd done a bit of clean up and abstraction (actually it took quite some time because the only
    reliable way to do it is stepwise with lots of testing) I wondered why there is a difference in
    the way the level is kept track of. For those entries that store a value directly, a separate
    |xeq_level| array is used. So, after \quote {following the code}, taking a look at the original
    implementation, and a walk, I came to the conclusion that because \LUATEX\ uses 64 memory words,
    we actually don't need that parallel array: we have plenty of room and, the level fields are not
    shared. In traditional \TEX\ we have a memory word with two faces:

    [level] [type]
    [    value   ]

    but in \LUATEX\ it's wider. There is no overlap.

    [level] [type] [value]

    So, we can get rid of that extra array. Actually, in the \PASCAL\ source we see that this
    parallel array is smaller because it only covers the value ranges (the first index starts at
    the start of the first relevant register range). Keep in mind that the middle part of the hash
    is registers and when we have a frozen hash size, that part is not present which is why there
    was that parallel array needed; a side effect of the |extra_hash| extension.

    Another side effect of this simplification is that we can store and use the type which can be
    handy too.

    For the changes, look for |xeq simplification| comments in the files and for the cleaned up
    precursor in the archives of luametatex (in case there is doubt). When the save stack was made
    more efficient the old commented |xeq| code has been removed.

    -----------------------------------
    null control sequence
    hash entries (hash_size)
    multiple frozen control sequences
    special sequences (font, undefined)
    -----------------------------------
    glue registers
    mu glue registers
    token registers
    box registers
    integer registers
    attribute registers
    dimension registers
    specifications
    ---------- eqtb size --------------
    extra hash entries
    -----------------------------------

    eqtb_top = eqtb_size + hash_extra
    hash_top = hash_extra == 0 ? undefined_control_sequence : eqtb_top;

    There used to be a large font area but I moved that to the font record so that we don't waste
    space (it saves some 500K on the format file and plenty of memory).

    Todo: split the eqtb and make the register arrays dynamic. We need to change the save/restore
    code then and it might have a slight impact on performance (checking what table to use).

*/

/*tex
    Maybe we should multiply the following by 2 but there is no real gain. Many entries end up in the extended
    area anyway.

    \starttyping
    # define hash_size  65536
    # define hash_prime 55711
    \stoptyping

    Here |hash_size| is the maximum number of control sequences; it should be at most about
    |(fix_mem_max - fix_mem_min)/10|. The value of |hash_prime| is a prime number equal to about
    85 percent of |hash_size|.

    The hash runs in parallel to the eqtb and a large hash table makes for many holes and that
    compresses badly. For instance:

    590023 => down to 1024 * 512 == 524288 ==> 85% = 445644 => prime 445633/445649

    will make a much larger format and we gain nothing. Actually, because we have extra hash
    anyway, this whole 85\% criterium is irrelevant: we only need to make sure that we have
    enough room for the frozen sequences (assuming we stay within the concept).

    primes:

    \starttyping
     65447  65449  65479  65497  65519  65521 =>  65536 (85% ==  55711)
    131009 131011 131023 131041 131059 131063 => 131072 (85% == 111409)
    \stoptyping

    lookups:

    \starttyping
    n=131040 cs=46426 indirect= 9173
    n= 65496 cs=46426 indirect=14512
    \stoptyping

*/

// # define hash_size  65536
// # define hash_prime 65497

# define hash_size  131072                               /*tex 128K */
# define hash_prime 131041                               /*tex Plenty of room for the frozen. */

# define null_cs                 1                       /*tex equivalent of |\csname\| |\endcsname| */
# define hash_base               (null_cs   + 1)         /*tex beginning of region 2, for the hash table */
# define frozen_control_sequence (hash_base + hash_size) /*tex for error recovery */

typedef enum deep_frozen_cs_codes {
    deep_frozen_cs_protection_code = frozen_control_sequence, /*tex inaccessible but definable */
    deep_frozen_cs_cr_code,                                   /*tex permanent |\cr| */
    deep_frozen_cs_end_group_code,                            /*tex permanent |\endgroup| */
    deep_frozen_cs_right_code,                                /*tex permanent |\right| */
    deep_frozen_cs_fi_code,                                   /*tex permanent |\fi| */
    deep_frozen_cs_no_if_code,                                /*tex hidden |\noif| */
    deep_frozen_cs_always_code,                               /*tex hidden internalized |\enforces| */
    deep_frozen_cs_end_template_1_code,                       /*tex permanent |\endtemplate| */
    deep_frozen_cs_end_template_2_code,                       /*tex second permanent |\endtemplate| */
    deep_frozen_cs_relax_code,                                /*tex permanent |\relax| */
    deep_frozen_cs_end_write_code,                            /*tex permanent |\endwrite| */
    deep_frozen_cs_dont_expand_code,                          /*tex permanent |\notexpanded:| */
    deep_frozen_cs_null_font_code,                            /*tex permanent |\nullfont| */
    deep_frozen_cs_undefined_code,
} deep_frozen_cs_codes;

# define first_deep_frozen_cs_location deep_frozen_cs_protection_code
# define last_deep_frozen_cs_location  deep_frozen_cs_undefined_code

typedef enum glue_codes {
    line_skip_code,                /*tex interline glue if |baseline_skip| is infeasible */
    baseline_skip_code,            /*tex desired glue between baselines */
    par_skip_code,                 /*tex extra glue just above a paragraph */
    above_display_skip_code,       /*tex extra glue just above displayed math */
    below_display_skip_code,       /*tex extra glue just below displayed math */
    above_display_short_skip_code, /*tex glue above displayed math following short lines */
    below_display_short_skip_code, /*tex glue below displayed math following short lines */
    left_skip_code,                /*tex glue at left of justified lines */
    right_skip_code,               /*tex glue at right of justified lines */
    top_skip_code,                 /*tex glue at top of main pages */
    split_top_skip_code,           /*tex glue at top of split pages */
    tab_skip_code,                 /*tex glue between aligned entries */
    space_skip_code,               /*tex glue between words (if not |zero_glue|) */
    xspace_skip_code,              /*tex glue after sentences (if not |zero_glue|) */
    par_fill_left_skip_code,       /*tex glue at the start of the last line of paragraph */
    par_fill_right_skip_code,      /*tex glue on last line of paragraph */
    par_init_left_skip_code,
    par_init_right_skip_code,
 /* indent_skip_code,           */ /*tex internal, might go away here */
 /* left_hang_skip_code,        */ /*tex internal, might go away here */
 /* right_hang_skip_code,       */ /*tex internal, might go away here */
 /* correction_skip_code,       */ /*tex internal, might go away here */
 /* inter_math_skip_code,       */ /*tex internal, might go away here */
    math_skip_code,                /*tex glue before and after inline math */
    math_threshold_code,
    /*tex total number of glue parameters */
    number_glue_pars,
} glue_codes;

# define first_glue_code line_skip_code
# define last_glue_code  math_threshold_code

/*tex 

    In addition to the three original predefined muskip registers we have two more. These muskips 
    are used in a symbolic way: by using a reference we can change their values on the fly and the 
    engine will pick up the value set at the end of the formula (and use it in the second pass). 
    In the other engines the threesome are hard coded into the atom pair spacing. 

    In \LUAMETATEX\ we have a configurable system so these three registers are only used in the 
    initialization, can be overloaded in the macro package, and are saved in the format file (as 
    any other register). But there can be more than these. Before we had a way to link spacing to 
    arbitrary registers (in the user's register space) we added |\tinymuskip| because we needed it. 
    It is not used in initializations in the engine but is applied in the \CONTEXT\ format. We 
    could throw it out and use just a user register now but we consider it part of the (updated) 
    concept so it will stick around. Even more: we decided that a smaller one makes sense so end 
    June 2022 Mikael and I decided to also provide |\pettymuskip| for which Mikael saw a good use 
    case in the spacing in scripts between ordinary symbols and binary as well as relational ones. 

    The Cambridge dictionary describes \quote {petty} as \quotation {not important and not worth 
    giving attention to}, but of course we do! It's just that till not we never saw any request 
    for an upgrade of the math (sub) engine, let alone that \TEX\ users bothered about the tiny 
    and petty spacing artifacts (and posibilities) of the engine. Both internal registers are 
    dedicated to Don Knuth who {\em does} pay a lot attentions to details but who of course will 
    not use this engine and thereby not spoiled. So, they are there and at the same time they 
    are not. But: in \CONTEXT\ they {\em are} definitely used!

*/

typedef enum mu_glue_codes {
    zero_mu_skip_code,
    petty_mu_skip_code,            /*tex petty space in math formula */
    tiny_mu_skip_code,             /*tex tiny space in math formula */
    thin_mu_skip_code,             /*tex thin space in math formula */
    med_mu_skip_code,              /*tex medium space in math formula */
    thick_mu_skip_code,            /*tex thick space in math formula */
    /*tex total number of mu glue parameters */
    number_mu_glue_pars,
} mu_glue_codes;

# define first_mu_glue_code  petty_mu_skip_code
# define last_mu_glue_code   thick_mu_skip_code

typedef enum tok_codes {
    output_routine_code,          /*tex points to token list for |\output| */
    every_par_code,               /*tex points to token list for |\everypar| */
    every_math_code,              /*tex points to token list for |\everymath| */
    every_display_code,           /*tex points to token list for |\everydisplay| */
    every_hbox_code,              /*tex points to token list for |\everyhbox| */
    every_vbox_code,              /*tex points to token list for |\everyvbox| */
    every_math_atom_code,         /*tex points to token list for |\everymathatom| */
    every_job_code,               /*tex points to token list for |\everyjob|*/
    every_cr_code,                /*tex points to token list for |\everycr| */
    every_tab_code,               /*tex points to token list for |\everytab| */
    error_help_code,              /*tex points to token list for |\errhelp|*/
    every_before_par_code,        /*tex points to token list for |\everybeforepar| */
    every_eof_code,               /*tex points to token list for |\everyeof| */
    end_of_group_code,            /*tex collects end-of-group tokens, internal register */
 // end_of_par_code,
    /*tex total number of token parameters */
    number_tok_pars,
} tok_codes;

# define first_toks_code output_routine_code
# define last_toks_code  every_eof_code

typedef enum specification_codes {
    par_shape_code,               /*tex specifies paragraph shape, internal register */
    inter_line_penalties_code,    /*tex additional penalties between lines */
    club_penalties_code,          /*tex penalties for creating club lines */
    widow_penalties_code,         /*tex penalties for creating widow lines */
    display_widow_penalties_code, /*tex ditto, just before a display */
    orphan_penalties_code,
    math_forward_penalties_code,
    math_backward_penalties_code,
    number_specification_pars,
} specification_codes;

# define first_specification_code par_shape_code
# define last_specification_code  math_backward_penalties_code

/*tex Beware: these are indices into |page_builder_state.page_so_far| array! */

typedef enum page_property_codes {
    page_goal_code,
    page_vsize_code,
    page_total_code,
    page_depth_code,
    dead_cycles_code,
    insert_penalties_code,
    insert_heights_code,
    insert_storing_code, /* page */
    insert_distance_code,
    insert_multiplier_code,
    insert_limit_code,
    insert_storage_code, /* per insert */
    insert_penalty_code,
    insert_maxdepth_code,
    insert_height_code,
    insert_depth_code,
    insert_width_code,
    page_stretch_code,
    page_filstretch_code,
    page_fillstretch_code,
    page_filllstretch_code,
    page_shrink_code,
} page_property_codes;

# define first_page_property_code page_goal_code
# define last_page_property_code  insert_width_code

/*tex
    We cheat: these previous bases are to really bases which is why math and del get separated by
    one. See usage! Todo: group them better (also elsewhere in switches).
*/

typedef enum int_codes {
    pre_tolerance_code,                 /*tex badness tolerance before hyphenation */
    tolerance_code,                     /*tex badness tolerance after hyphenation */
    line_penalty_code,                  /*tex added to the badness of every line */
    hyphen_penalty_code,                /*tex penalty for break after discretionary hyphen */
    ex_hyphen_penalty_code,             /*tex penalty for break after explicit hyphen */
    club_penalty_code,                  /*tex penalty for creating a club line */
    widow_penalty_code,                 /*tex penalty for creating a widow line */
    display_widow_penalty_code,         /*tex ditto, just before a display */
    broken_penalty_code,                /*tex penalty for breaking a page at a broken line */
    post_binary_penalty_code,           /*tex penalty for breaking after a binary operation */
    post_relation_penalty_code,         /*tex penalty for breaking after a relation */
    pre_display_penalty_code,           /*tex penalty for breaking just before a displayed formula */
    post_display_penalty_code,          /*tex penalty for breaking just after a displayed formula */
    pre_inline_penalty_code,            /*tex penalty for breaking just before an inlined formula */
    post_inline_penalty_code,           /*tex penalty for breaking just after an inlined formula */
    inter_line_penalty_code,            /*tex additional penalty between lines */
    double_hyphen_demerits_code,        /*tex demerits for double hyphen break */
    final_hyphen_demerits_code,         /*tex demerits for final hyphen break */
    adj_demerits_code,                  /*tex demerits for adjacent incompatible lines */
 /* mag_code,                        */ /*tex magnification ratio */
    delimiter_factor_code,              /*tex ratio for variable-size delimiters */
    looseness_code,                     /*tex change in number of lines for a paragraph */
    time_code,                          /*tex current time of day */
    day_code,                           /*tex current day of the month */
    month_code,                         /*tex current month of the year */
    year_code,                          /*tex current year of our Lord */
    show_box_breadth_code,              /*tex nodes per level in |show_box| */
    show_box_depth_code,                /*tex maximum level in |show_box| */
    show_node_details_code,             /*tex controls subtype and attribute details */
    hbadness_code,                      /*tex hboxes exceeding this badness will be shown by |hpack| */
    vbadness_code,                      /*tex vboxes exceeding this badness will be shown by |vpack| */
    pausing_code,                       /*tex pause after each line is read from a file */
    tracing_online_code,                /*tex show diagnostic output on terminal */
    tracing_macros_code,                /*tex show macros as they are being expanded */
    tracing_stats_code,                 /*tex show memory usage if \TeX\ knows it */
    tracing_paragraphs_code,            /*tex show line-break calculations */
    tracing_pages_code,                 /*tex show page-break calculations */
    tracing_output_code,                /*tex show boxes when they are shipped out */
    tracing_lost_chars_code,            /*tex show characters that aren't in the font */
    tracing_commands_code,              /*tex show command codes at |big_switch| */
    tracing_restores_code,              /*tex show equivalents when they are restored */
    tracing_fonts_code,
    tracing_assigns_code,               /*tex show assignments */
    tracing_groups_code,                /*tex show save/restore groups */
    tracing_ifs_code,                   /*tex show conditionals */
    tracing_math_code,
    tracing_levels_code,                /*tex show levels when tracing */
    tracing_nesting_code,               /*tex show incomplete groups and ifs within files */
    tracing_alignments_code,            /*tex show nesting of noalign and preambles */
    tracing_inserts_code,               /*tex show some info about insert processing */
    tracing_marks_code,                 /*tex show state of marks */
    tracing_adjusts_code,               /*tex show state of marks */
    tracing_hyphenation_code,           /*tex show some info regarding hyphenation */
    tracing_expressions_code,           /*tex show some info regarding expressions */
    tracing_nodes_code,                 /*tex show node numbers too */
    tracing_full_boxes_code,            /*tex show [over/under]full boxes in the log */
    tracing_penalties_code,   
    tracing_lists_code,   
    uc_hyph_code,                       /*tex hyphenate words beginning with a capital letter */
    output_penalty_code,                /*tex penalty found at current page break */
    max_dead_cycles_code,               /*tex bound on consecutive dead cycles of output */
    hang_after_code,                    /*tex hanging indentation changes after this many lines */
    floating_penalty_code,              /*tex penalty for insertions heldover after a split */
    global_defs_code,                   /*tex override |\global| specifications */
    family_code,                        /*tex current family */
    escape_char_code,                   /*tex escape character for token output */
    default_hyphen_char_code,           /*tex value of |\hyphenchar| when a font is loaded */
    default_skew_char_code,             /*tex value of |\skewchar| when a font is loaded */
    end_line_char_code,                 /*tex character placed at the right end of the buffer */
    new_line_char_code,                 /*tex character that prints as |print_ln| */
    language_code,                      /*tex current language */
    font_code,                          /*tex current font */
    hyphenation_mode_code,
    left_hyphen_min_code,               /*tex minimum left hyphenation fragment size */
    right_hyphen_min_code,              /*tex minimum right hyphenation fragment size */
    holding_inserts_code,               /*tex do not remove insertion nodes from |\box255| */
    holding_migrations_code, 
    error_context_lines_code,           /*tex maximum intermediate line pairs shown */
    local_interline_penalty_code,       /*tex local |\interlinepenalty| */
    local_broken_penalty_code,          /*tex local |\brokenpenalty| */
    disable_spaces_code,
    glyph_scale_code,
    glyph_x_scale_code,
    glyph_y_scale_code,
    glyph_data_code,
    glyph_state_code,
    glyph_script_code,
    glyph_options_code,
    glyph_text_scale_code,
    glyph_script_scale_code,
    glyph_scriptscript_scale_code,
 /* glue_data_code, */
    cat_code_table_code,
    output_box_code,
    ex_hyphen_char_code,
    adjust_spacing_code,                /*tex level of spacing adjusting */
    adjust_spacing_step_code,           /*tex level of spacing adjusting step */
    adjust_spacing_stretch_code,        /*tex level of spacing adjusting stretch */
    adjust_spacing_shrink_code,         /*tex level of spacing adjusting shrink */
    protrude_chars_code,                /*tex protrude chars at left/right edge of paragraphs */
    pre_display_direction_code,         /*tex text direction preceding a display */
    last_line_fit_code,                 /*tex adjustment for last line of paragraph */
    saving_vdiscards_code,              /*tex save items discarded from vlists */
    saving_hyph_codes_code,             /*tex save hyphenation codes for languages */
    math_eqno_gap_step_code,            /*tex factor/1000 used for distance between eq and eqno */
    math_display_skip_mode_code,
    math_scripts_mode_code,
    math_limits_mode_code,
    math_nolimits_mode_code,
    math_rules_mode_code,
    math_rules_fam_code,
    math_penalties_mode_code,
    math_check_fences_mode_code,
    math_slack_mode_code,
    math_skip_mode_code,
    math_double_script_mode_code,
    math_font_control_code,
    math_display_mode_code,
    math_dict_group_code,
    math_dict_properties_code,
    math_pre_display_gap_factor_code,
    pre_binary_penalty_code,
    pre_relation_penalty_code,
    first_valid_language_code,
    automatic_hyphen_penalty_code,
    explicit_hyphen_penalty_code,
    exception_penalty_code,
    copy_lua_input_nodes_code,
    auto_migration_mode_code,
    normalize_line_mode_code,
    normalize_par_mode_code,
    math_spacing_mode_code,
    math_grouping_mode_code,
    math_glue_mode_code,
    math_begin_class_code,
    math_end_class_code,
    math_left_class_code,
    math_right_class_code,
    sup_mark_mode_code,
    par_direction_code,
    text_direction_code,
    math_direction_code,
    line_direction_code, /*tex gets remapped so is no real register */
    overload_mode_code,
    auto_paragraph_mode_code,
    shaping_penalties_mode_code,
    shaping_penalty_code,
    orphan_penalty_code,
    alignment_cell_source_code,
    alignment_wrap_source_code,
 /* page_boundary_penalty_code, */
    line_break_criterium_code,
    /* 
        This one was added as experiment to \LUATEX\ (answer to a forwarded question) but as it 
        didn't get tested it will go away. \CONTEXT\ doesn't need it and we don't need to be 
        compatible anyway. Lesson learned.
    */
    variable_family_code,
    /* those below these are not interfaced via primitives */
    internal_par_state_code,
    internal_dir_state_code,
    internal_math_style_code,
    internal_math_scale_code,
    /*tex total number of integer parameters */
    first_math_class_code,
    last_math_class_code = first_math_class_code + max_n_of_math_classes,
    first_math_atom_code,
    last_math_atom_code = first_math_atom_code + max_n_of_math_classes,
    first_math_options_code,
    last_math_options_code = first_math_options_code + max_n_of_math_classes,
    first_math_parent_code,
    last_math_parent_code = first_math_parent_code + max_n_of_math_classes,
    first_math_pre_penalty_code,
    last_math_pre_penalty_code = first_math_pre_penalty_code + max_n_of_math_classes,
    first_math_post_penalty_code,
    last_math_post_penalty_code = first_math_post_penalty_code + max_n_of_math_classes,
    first_math_display_pre_penalty_code,
    last_math_display_pre_penalty_code = first_math_display_pre_penalty_code + max_n_of_math_classes,
    first_math_display_post_penalty_code,
    last_math_display_post_penalty_code = first_math_display_post_penalty_code + max_n_of_math_classes,
    first_math_ignore_code,
    last_math_ignore_code = first_math_ignore_code + math_parameter_last,
    /* */
    number_int_pars,
} int_codes;

# define first_int_code pre_tolerance_code
# define last_int_code  variable_family_code

typedef enum dimen_codes {
    par_indent_code,           /*tex indentation of paragraphs */
    math_surround_code,        /*tex space around math in text */
    line_skip_limit_code,      /*tex threshold for |line_skip| instead of |baseline_skip| */
    hsize_code,                /*tex line width in horizontal mode */
    vsize_code,                /*tex page height in vertical mode */
    max_depth_code,            /*tex maximum depth of boxes on main pages */
    split_max_depth_code,      /*tex maximum depth of boxes on split pages */
    box_max_depth_code,        /*tex maximum depth of explicit vboxes */
    hfuzz_code,                /*tex tolerance for overfull hbox messages */
    vfuzz_code,                /*tex tolerance for overfull vbox messages */
    delimiter_shortfall_code,  /*tex maximum amount uncovered by variable delimiters */
    null_delimiter_space_code, /*tex blank space in null delimiters */
    script_space_code,         /*tex extra space after subscript or superscript */
    pre_display_size_code,     /*tex length of text preceding a display */
    display_width_code,        /*tex length of line for displayed equation */
    display_indent_code,       /*tex indentation of line for displayed equation */
    overfull_rule_code,        /*tex width of rule that identifies overfull hboxes */
    hang_indent_code,          /*tex amount of hanging indentation */
 /* h_offset_code,          */ /*tex amount of horizontal offset when shipping pages out */
 /* v_offset_code,          */ /*tex amount of vertical offset when shipping pages out */
    emergency_stretch_code,    /*tex reduces badnesses on final pass of line-breaking */
    glyph_x_offset_code,
    glyph_y_offset_code,
    px_dimen_code,
    tab_size_code,
    page_extra_goal_code,
    ignore_depth_criterium_code,
    /*tex total number of dimension parameters */
    number_dimen_pars,
} dimen_codes;

# define first_dimen_code par_indent_code
# define last_dimen_code  tab_size_code

typedef enum attribute_codes {
    /*tex total number of attribute parameters */
    number_attribute_pars,
} attribute_codes;

// typedef enum special_sequence_codes {
//  // current_font_sequence_code,
//     undefined_control_sequence_code,
//     n_of_special_sequences,
// } special_sequence_codes;
//
// /* The last one is frozen_null_font. */
//
// # define special_sequence_base         (last_frozen_cs_loc + 1)
// # define current_font_sequence         (special_sequence_base + current_font_sequence_code)
// # define undefined_control_sequence    (special_sequence_base + undefined_control_sequence_code)
// # define first_register_base           (special_sequence_base + n_of_special_sequences)

# define undefined_control_sequence     deep_frozen_cs_undefined_code

# define special_sequence_base          (last_deep_frozen_cs_location + 1)
# define first_register_base            (last_deep_frozen_cs_location + 1)

# define internal_glue_base             (first_register_base)
# define register_glue_base             (internal_glue_base + number_glue_pars + 1)
# define internal_glue_location(a)      (internal_glue_base + (a))
# define register_glue_location(a)      (register_glue_base + (a))
# define internal_glue_number(a)        ((a) - internal_glue_base)
# define register_glue_number(a)        ((a) - register_glue_base)

# define internal_mu_glue_base          (register_glue_base    + max_n_of_glue_registers)
# define register_mu_glue_base          (internal_mu_glue_base + number_mu_glue_pars + 1)
# define internal_mu_glue_location(a)   (internal_mu_glue_base + (a))
# define register_mu_glue_location(a)   (register_mu_glue_base + (a))
# define internal_mu_glue_number(a)     ((a) - internal_mu_glue_base)
# define register_mu_glue_number(a)     ((a) - register_mu_glue_base)

# define internal_toks_base             (register_mu_glue_base + max_n_of_mu_glue_registers)
# define register_toks_base             (internal_toks_base    + number_tok_pars + 1)
# define internal_toks_location(a)      (internal_toks_base    + (a))
# define register_toks_location(a)      (register_toks_base    + (a))
# define internal_toks_number(a)        ((a) - internal_toks_base)
# define register_toks_number(a)        ((a) - register_toks_base)

# define internal_box_base              (register_toks_base + max_n_of_toks_registers)
# define register_box_base              (internal_box_base  + number_box_pars + 1)
# define internal_box_location(a)       (internal_box_base  + (a))
# define register_box_location(a)       (register_box_base  + (a))
# define internal_box_number(a)         ((a) - internal_box_base)
# define register_box_number(a)         ((a) - register_box_base)

# define internal_int_base              (register_box_base + max_n_of_box_registers)
# define register_int_base              (internal_int_base + number_int_pars + 1)
# define internal_int_location(a)       (internal_int_base + (a))
# define register_int_location(a)       (register_int_base + (a))
# define internal_int_number(a)         ((a) - internal_int_base)
# define register_int_number(a)         ((a) - register_int_base)

# define internal_attribute_base        (register_int_base  + max_n_of_int_registers)
# define register_attribute_base        (internal_attribute_base + number_attribute_pars + 1)
# define internal_attribute_location(a) (internal_attribute_base + (a))
# define register_attribute_location(a) (register_attribute_base + (a))
# define internal_attribute_number(a)   ((a) - internal_attribute_base)
# define register_attribute_number(a)   ((a) - register_attribute_base)

# define internal_dimen_base            (register_attribute_base  + max_n_of_attribute_registers)
# define register_dimen_base            (internal_dimen_base + number_dimen_pars + 1)
# define internal_dimen_location(a)     (internal_dimen_base + (a))
# define register_dimen_location(a)     (register_dimen_base + (a))
# define internal_dimen_number(a)       ((a) - internal_dimen_base)
# define register_dimen_number(a)       ((a) - register_dimen_base)

# define internal_specification_base        (register_dimen_base + max_n_of_dimen_registers)
# define internal_specification_location(a) (internal_specification_base + (a))
# define internal_specification_number(a)   ((a) - internal_specification_base)

# define eqtb_size       (internal_specification_base + number_specification_pars)
# define eqtb_max_so_far (eqtb_size + lmt_hash_state.hash_data.ptr + 1)

/* below: top or ptr +1 ? */

# define eqtb_indirect_range(n) ((n < internal_glue_base) || ((n > eqtb_size) && (n <= lmt_hash_state.hash_data.top)))
# define eqtb_out_of_range(n)   ((n >= undefined_control_sequence) && ((n <= eqtb_size) || n > lmt_hash_state.hash_data.top))
# define eqtb_invalid_cs(n)     ((n == 0) || (n > lmt_hash_state.hash_data.top) || ((n > frozen_control_sequence) && (n <= eqtb_size)))

# define character_in_range(i)  (i >= 0 && i <= max_character_code)
# define catcode_in_range(i)    (i >= 0 && i <= max_category_code)
# define family_in_range(i)     (i >= 0 && i <= max_math_family_index)
# define class_in_range(i)      (i >= 0 && i <= max_math_class_code)
# define half_in_range(i)       (i >= 0 && i <= max_half_value)
# define box_index_in_range(i)  (i >= 0 && i <= max_box_index)

/* These also have funny offsets: */

typedef enum align_codes  {
    tab_mark_code,
    span_code,
    omit_code,
    align_content_code,
    no_align_code,
    cr_code,
    cr_cr_code,
} align_codes;

/*
    typedef struct equivalents_state_info {
    } equivalents_state_info ;

    extern equivalents_state_info lmt_equivalents_state;
*/

extern void tex_initialize_levels       (void);
extern void tex_initialize_equivalents  (void);
extern void tex_synchronize_equivalents (void);
extern void tex_initialize_undefined_cs (void);
extern void tex_dump_equivalents_mem    (dumpstream f);
extern void tex_undump_equivalents_mem  (dumpstream f);

/*tex
    The more low level |_field| shortcuts are used when we (for instance) work with copies, as done
    in the save stack entries. In most cases we use the second triplet of shortcuts. We replaced
    |equiv(A)| and |equiv_value(A)| by |eq_value(A)}|.
*/

# define eq_level_field(A) (A).quart01
# define eq_full_field(A)  (A).quart00
# define eq_type_field(A)  (A).single00
# define eq_flag_field(A)  (A).single01
# define eq_value_field(A) (A).half1

# define eq_level(A)       lmt_hash_state.eqtb[(A)].quart01  /*tex level of definition */
# define eq_full(A)        lmt_hash_state.eqtb[(A)].quart00  /*tex command code for equivalent */
# define eq_type(A)        lmt_hash_state.eqtb[(A)].single00 /*tex command code for equivalent */
# define eq_flag(A)        lmt_hash_state.eqtb[(A)].single01
# define eq_value(A)       lmt_hash_state.eqtb[(A)].half1

# define set_eq_level(A,B) lmt_hash_state.eqtb[(A)].quart01  = (quarterword) (B)
# define set_eq_type(A,B)  lmt_hash_state.eqtb[(A)].single00 = (singleword) (B)
# define set_eq_flag(A,B)  lmt_hash_state.eqtb[(A)].single01 = (singleword) (B)
# define set_eq_value(A,B) lmt_hash_state.eqtb[(A)].half1    = (B)

# define copy_eqtb_entry(target,source) lmt_hash_state.eqtb[target] = lmt_hash_state.eqtb[source]

# define equal_eqtb_entries(A,B) ( \
    (lmt_hash_state.eqtb[(A)].half0 == lmt_hash_state.eqtb[(B)].half0) \
 && (lmt_hash_state.eqtb[(A)].half1 == lmt_hash_state.eqtb[(B)].half1) \
)

/*tex

    Because we operate in 64 bit we padd with a halfword, and because if that we have an extra field. Now,
    because we already no longer need the parallel eqtb level table, we can use this field to store the
    value alongside which makes that we can turn the dual slot |restore_old_value| and |saved_eqtb| into
    one which in turn makes stack usage shrink. The performance gain is probably neglectable.

*/

typedef struct save_record {
    quarterword saved_level;
    quarterword saved_type;  /*tex We need less so we can actually decide to store the offset as check. */
    halfword    saved_value; /*tex Started out as padding, is now actually used for value. */
    memoryword  saved_word;
} save_record;

typedef struct save_state_info {
    save_record *save_stack;
    memory_data  save_stack_data;
    quarterword  current_level;        /*tex current nesting level for groups */
    quarterword  current_group;        /*tex current group type */
    int          current_boundary;     /*tex where the current level begins */
    int          padding;
} save_state_info;

extern save_state_info lmt_save_state;

# define cur_level    lmt_save_state.current_level
# define cur_group    lmt_save_state.current_group
# define cur_boundary lmt_save_state.current_boundary

/*tex

    We use the notation |saved(k)| to stand for an item that appears in location |save_ptr + k| of
    the save stack.

    The level field is also available for other purposes, so maybe we need an alias that is more
    generic.

*/

# define save_type(A)   lmt_save_state.save_stack[(A)].saved_type  /*tex classifies a |save_stack| entry */
# define save_extra(A)  lmt_save_state.save_stack[(A)].saved_level /*tex a more generic alias: to be used */
# define save_level(A)  lmt_save_state.save_stack[(A)].saved_level /*tex saved level for regions 5 and 6, or group code, or ...  */
# define save_value(A)  lmt_save_state.save_stack[(A)].saved_value /*tex |eqtb| location or token or |save_stack| location or ... */
# define save_word(A)   lmt_save_state.save_stack[(A)].saved_word  /*tex |eqtb| entry */

# define saved_valid(A) (lmt_save_state.save_stack_data.ptr + (A) >= 0)
# define saved_type(A)  lmt_save_state.save_stack[lmt_save_state.save_stack_data.ptr + (A)].saved_type
# define saved_extra(A) lmt_save_state.save_stack[lmt_save_state.save_stack_data.ptr + (A)].saved_level
# define saved_level(A) lmt_save_state.save_stack[lmt_save_state.save_stack_data.ptr + (A)].saved_level
# define saved_value(A) lmt_save_state.save_stack[lmt_save_state.save_stack_data.ptr + (A)].saved_value
# define saved_word(A)  lmt_save_state.save_stack[lmt_save_state.save_stack_data.ptr + (A)].saved_word

inline static void tex_set_saved_record(halfword ptr, quarterword type, quarterword level, halfword value)
{
    saved_type(ptr)  = type;
    saved_level(ptr) = level;
    saved_value(ptr) = value;
}

# define reserved_save_stack_slots 32 /* was 8 */

/*tex

    The rather explicit |save_| items indicate a type. They are sometimes used to lookup a specific
    field (when tracing).

    Todo: less of these, a few more generic ones, like count, dimen, etc
*/

typedef enum save_types {
    restore_old_value_save_type, /*tex a value should be restored later */
    restore_zero_save_type,      /*tex an undefined entry should be restored */
    insert_tokens_save_type,
    restore_lua_save_type,
    level_boundary_save_type,    /*tex the beginning of a group */
    /* */
    line_number_save_type,
    /* */
    insert_index_save_type,
    /* */
    discretionary_count_save_type,
    /* */
    text_direction_save_type,
    /* */
    equation_number_location_save_type,
    /* */
    choices_count_save_type,
    /* */
    fraction_variant_save_type,
    fraction_auto_style_save_type,
    fraction_user_style_save_type,
    /* */
    radical_degree_done_save_type, /* make this better: just types */
    radical_style_save_type,
    /* */
    operator_variant_save_type,
    /* */
    attribute_list_save_type,
    /* */
    math_pointer_save_type,
    math_class_save_type,
    /* */
    box_type_save_type,
    box_context_save_type,
    box_spec_save_type,
    box_direction_save_type,
    box_attr_list_save_type,
    box_pack_save_type,
    box_orientation_save_type,
    box_anchor_save_type,
    box_geometry_save_type,
    box_xoffset_save_type,
    box_yoffset_save_type,
    box_xmove_save_type,
    box_ymove_save_type,
    box_reverse_save_type,
    box_discard_save_type,
    box_noskips_save_type,
    box_callback_save_type,
    box_container_save_type,
    box_shift_save_type,
    box_source_save_type,
    box_target_save_type,
    box_axis_save_type,
    box_class_save_type,
    box_state_save_type,
    box_retain_save_type,
    /* */
    local_box_location_save_type,
    local_box_index_save_type,
    local_box_options_save_type,
    /* */
    adjust_location_save_type,
    adjust_options_save_type,
    adjust_index_save_type,
    adjust_attr_list_save_type,
    adjust_depth_before_save_type,
    adjust_depth_after_save_type,
} save_types;

/*tex Nota bena: |equiv_value| is the same as |equiv| but sometimes we use that name instead. */

// int_par(A) hash_state.eqtb_i_i[(A)].half1

# define int_parameter(A)           eq_value(internal_int_location(A))
# define count_parameter(A)         eq_value(internal_int_location(A))
# define attribute_parameter(A)     eq_value(internal_attribute_location(A))
# define dimen_parameter(A)         eq_value(internal_dimen_location(A))
# define toks_parameter(A)          eq_value(internal_toks_location(A))
# define glue_parameter(A)          eq_value(internal_glue_location(A))
# define mu_glue_parameter(A)       eq_value(internal_mu_glue_location(A))
# define box_parameter(A)           eq_value(internal_box_location(A))
# define specification_parameter(A) eq_value(internal_specification_location(A))

/*tex These come from |\ALEPH| aka |\OMEGA|: */


# define is_valid_local_box_code(c) (c >= first_local_box_code && c <= last_local_box_code)

/*tex

    Here are the group codes that are used to discriminate between different kinds of groups. They
    allow \TEX\ to decide what special actions, if any, should be performed when a group ends.

    Some groups are not supposed to be ended by right braces. For example, the |$| that begins a
    math formula causes a |math_shift_group| to be started, and this should be terminated by a
    matching |$|. Similarly, a group that starts with |\left| should end with |\right|, and one
    that starts with |\begingroup| should end with |\endgroup|.

*/

typedef enum tex_group_codes {
    bottom_level_group,  /*tex group code for the outside world */
    simple_group,        /*tex group code for local structure only */
    hbox_group,          /*tex code for |\hbox| */
    adjusted_hbox_group, /*tex code for |\hbox| in vertical mode */
    vbox_group,          /*tex code for |\vbox| */
    vtop_group,          /*tex code for |\vtop| */
    dbox_group,          /*tex code for |\dbox| */
    align_group,         /*tex code for |\halign|, |\valign| */
    no_align_group,      /*tex code for |\noalign| */
    output_group,        /*tex code for output routine */
    math_group,          /*tex code for, e.g., |\char'136| */
    math_stack_group,
    math_component_group,
    discretionary_group, /*tex code for |\discretionary|' */
    insert_group,        /*tex code for |\insert| */
    vadjust_group,       /*tex code for |\vadjust| */
    vcenter_group,       /*tex code for |\vcenter| */
    math_fraction_group, /*tex code for |\over| and friends */
    math_operator_group,
    math_radical_group,
    math_choice_group,   /*tex code for |\mathchoice| */
    also_simple_group,   /*tex code for |\begingroup|\unknown|\egroup| */
    semi_simple_group,   /*tex code for |\begingroup|\unknown|\endgroup| */
    math_simple_group,   /*tex code for |\beginmathgroup|\unknown|\endmathgroup| */
    math_shift_group,    /*tex code for |$|\unknown\|$| */
    math_fence_group,    /*tex code for fences |\left|\unknown|\right| */
    local_box_group,     /*tex code for |\localleftbox|\unknown|localrightbox| */
    split_off_group,     /*tex box code for the top part of a |\vsplit| */
    split_keep_group,    /*tex box code for the bottom part of a |\vsplit| */
    preamble_group,      /*tex box code for the preamble processing  in an alignment */
    align_set_group,     /*tex box code for the final item pass in an alignment */
    finish_row_group,    /*tex box code for a provisory line in an alignment */
    lua_group,
} tex_group_codes;

typedef enum saved_group_items {
    saved_group_line_number    = 0,
    saved_group_level_boundary = 1,
    saved_group_n_of_items     = 2,
} saved_group_items;

/*
    In the end I decided to split them into context and begin, but maybe some day
    they all merge into one (easier on tracing and reporting in shared helpers).
*/

typedef enum tex_par_context_codes {
    normal_par_context,
    vmode_par_context,
    vbox_par_context,
    vtop_par_context,
    dbox_par_context,
    vcenter_par_context,
    vadjust_par_context,
    insert_par_context,
    output_par_context,
    align_par_context,
    no_align_par_context,
    span_par_context,
    reset_par_context,
} tex_par_context_codes;

typedef enum tex_alignment_context_codes {
    preamble_pass_alignment_context,
    preroll_pass_alignment_context,
    package_pass_alignment_context,
    wrapup_pass_alignment_context,
} tex_alignment_context_codes;

typedef enum tex_page_context_codes {
    box_page_context,
    end_page_context,
    vadjust_page_context,
    penalty_page_context,
    boundary_page_context,
    insert_page_context,
    hmode_par_page_context,
    vmode_par_page_context,
    begin_paragraph_page_context,
    before_display_page_context,
    after_display_page_context,
    after_output_page_context,
    alignment_page_context,
} tex_page_context_codes;

typedef enum tex_append_line_context_codes {
    box_append_line_context,
    pre_box_append_line_context,
    pre_adjust_append_line_context,
    post_adjust_append_line_context,
    pre_migrate_append_line_context,
    post_migrate_append_line_context,
} tex_append_line_context_codes;

typedef enum tex_par_begin_codes {
    normal_par_begin,
    force_par_begin,
    indent_par_begin,
    no_indent_par_begin,
    math_char_par_begin,
    char_par_begin,
    boundary_par_begin,
    space_par_begin,
    math_par_begin,
    kern_par_begin,
    hskip_par_begin,
    un_hbox_char_par_begin,
    valign_char_par_begin,
    vrule_char_par_begin,
} tex_par_begin_codes;

typedef enum tex_tracing_levels_codes {
    tracing_levels_group    = 0x01,
    tracing_levels_input    = 0x02,
    tracing_levels_catcodes = 0x04,
} tex_tracing_levels_codes;

extern void tex_initialize_save_stack  (void);
/*     int  tex_room_on_save_stack     (void); */
extern void tex_save_halfword_on_stack (quarterword t, halfword v);
extern void tex_show_cmd_chr           (halfword cmd, halfword chr);
extern void tex_new_save_level         (quarterword c);                            /*tex begin a new level of grouping */
extern int  tex_saved_line_at_level    (void);
extern void tex_eq_define              (halfword p, singleword cmd, halfword chr); /*tex new data for |eqtb| */
extern void tex_eq_word_define         (halfword p, int w);
extern void tex_geq_define             (halfword p, singleword cmd, halfword chr); /*tex global |eq_define| */
extern void tex_geq_word_define        (halfword p, int w);                        /*tex global |eq_word_define| */
extern void tex_save_for_after_group   (halfword t);
extern void tex_unsave                 (void);                                     /*tex pops the top level off the save stack */
extern void tex_show_save_groups       (void);
extern int  tex_located_save_value     (int id);

/*tex

    The |prefixed_command| does not have to adjust |a| so that |a mod 4 = 0|, since the following
    routines test for the |\global| prefix as follows. Anyway, in the meantime we reshuffled the
    bits and changed a lot.

    When we need more bits, we will do this:

    One one of these:

    \starttyping
    primitive_flag   = 00000001 : cannot be changed  system set
    permanent_flag   = 00000010 : cannot be changed  \permanent
    immutable_flag   = 00000011 : cannot be changed  \immutable
    frozen_flag      = 00000100 : can be overloaded  \frozen and \overloaded
    mutable_flag     = 00000101 : never checked      \mutable
    reserved_1_flag  = 00000110
    \stoptyping

    Independent, not used combined:

    \starttyping
    noaligned_flag   = 00001000 : valid align peek   \noaligned (can be more generic: \alignpeekable or \alignable, also span and omit?)
    reserved_3_flag  = 00010000 : maybe obsolete indicator
    \stoptyping

    Informative:

    \starttyping
    instance_flag    = 00100000 : just a tag         \instance
    symbol_flag      = 01000000 : just a tag         \symbolic (or character)
    c_quantity_flag  = 01100000
    d_quantity-flag  = 10000000
    reserved_4_flag  = 10100000
    reserved_5_flag  = 11100000
    \stoptyping

    Maybe names like \flaginstance \flagpermanent etc are better? Now we run out of meaningful
    prefixes. Also testing the prefix then becomes more work.

*/

typedef enum flag_bit {
    /* properties and prefixes */
    frozen_flag_bit        = 0x00001,
    permanent_flag_bit     = 0x00002,
    immutable_flag_bit     = 0x00004,
    primitive_flag_bit     = 0x00008,
    mutable_flag_bit       = 0x00010,
    noaligned_flag_bit     = 0x00020,
    instance_flag_bit      = 0x00040,
    untraced_flag_bit      = 0x00080,
    /* prefixes */
    global_flag_bit        = 0x00100,
    tolerant_flag_bit      = 0x00200,
    protected_flag_bit     = 0x00400,
    overloaded_flag_bit    = 0x00800,
    aliased_flag_bit       = 0x01000,
    immediate_flag_bit     = 0x02000,
    conditional_flag_bit   = 0x04000,
    value_flag_bit         = 0x08000,
    semiprotected_flag_bit = 0x10000,
    inherited_flag_bit     = 0x20000,
    constant_flag_bit      = 0x40000,
} flag_bits;

/*tex Flags: */

# define add_flag(a,b)              ((a) | (b))

# define add_frozen_flag(a)         ((a) | frozen_flag_bit)
# define add_permanent_flag(a)      ((a) | permanent_flag_bit)
# define add_immutable_flag(a)      ((a) | immutable_flag_bit)
# define add_primitive_flag(a)      ((a) | primitive_flag_bit)
# define add_mutable_flag(a)        ((a) | mutable_flag_bit)
# define add_noaligned_flag(a)      ((a) | noaligned_flag_bit)
# define add_instance_flag(a)       ((a) | instance_flag_bit)
# define add_untraced_flag(a)       ((a) | untraced_flag_bit)

# define add_global_flag(a)         ((a) | global_flag_bit)
# define add_tolerant_flag(a)       ((a) | tolerant_flag_bit)
# define add_protected_flag(a)      ((a) | protected_flag_bit)
# define add_semiprotected_flag(a)  ((a) | semiprotected_flag_bit)
# define add_overloaded_flag(a)     ((a) | overloaded_flag_bit)
# define add_aliased_flag(a)        ((a) | aliased_flag_bit)
# define add_immediate_flag(a)      ((a) | immediate_flag_bit)
# define add_conditional_flag(a)    ((a) | conditional_flag_bit)
# define add_value_flag(a)          ((a) | value_flag_bit)
# define add_inherited_flag(a)      ((a) | inherited_flag_bit)
# define add_constant_flag(a)       ((a) | constant_flag_bit)

# define remove_flag(a,b)           ((a) & ~(b))

# define remove_frozen_flag(a)      ((a) & ~frozen_flag_bit)
# define remove_permanent_flag(a)   ((a) & ~permanent_flag_bit)
# define remove_immutable_flag(a)   ((a) & ~immutable_flag_bit)
# define remove_primitive_flag(a)   ((a) & ~primitive_flag_bit)
# define remove_mutable_flag(a)     ((a) & ~mutable_flag_bit)
# define remove_noaligned_flag(a)   ((a) & ~noaligned_flag_bit)
# define remove_instance_flag(a)    ((a) & ~instance_flag_bit)
# define remove_untraced_flag(a)    ((a) & ~untraced_flag_bit)

# define remove_global_flag(a)      ((a) & ~global_flag_bit)
# define remove_tolerant_flag(a)    ((a) & ~tolerant_flag_bit)
# define remove_protected_flag(a)   ((a) & ~protected_flag_bit)
# define remove_overloaded_flag(a)  ((a) & ~overloaded_flag_bit)
# define remove_aliased_flag(a)     ((a) & ~aliased_flag_bit)
# define remove_immediate_flag(a)   ((a) & ~immediate_flag_bit)
# define remove_conditional_flag(a) ((a) & ~conditional_flag_bit)
# define remove_value_flag(a)       ((a) & ~value_flag_bit)

# define is_frozen(a)               (((a) & frozen_flag_bit)    == frozen_flag_bit)
# define is_permanent(a)            (((a) & permanent_flag_bit) == permanent_flag_bit)
# define is_immutable(a)            (((a) & immutable_flag_bit) == immutable_flag_bit)
# define is_primitive(a)            (((a) & primitive_flag_bit) == primitive_flag_bit)
# define is_mutable(a)              (((a) & mutable_flag_bit)   == mutable_flag_bit)
# define is_noaligned(a)            (((a) & noaligned_flag_bit) == noaligned_flag_bit)
# define is_instance(a)             (((a) & instance_flag_bit)  == instance_flag_bit)
# define is_untraced(a)             (((a) & untraced_flag_bit)  == untraced_flag_bit)

# define is_global(a)               (((a) & global_flag_bit)        == global_flag_bit)
# define is_tolerant(a)             (((a) & tolerant_flag_bit)      == tolerant_flag_bit)
# define is_protected(a)            (((a) & protected_flag_bit)     == protected_flag_bit)
# define is_semiprotected(a)        (((a) & semiprotected_flag_bit) == semiprotected_flag_bit)
# define is_overloaded(a)           (((a) & overloaded_flag_bit)    == overloaded_flag_bit)
# define is_aliased(a)              (((a) & aliased_flag_bit)       == aliased_flag_bit)
# define is_immediate(a)            (((a) & immediate_flag_bit)     == immediate_flag_bit)
# define is_conditional(a)          (((a) & conditional_flag_bit)   == conditional_flag_bit)
# define is_value(a)                (((a) & value_flag_bit)         == value_flag_bit)
# define is_inherited(a)            (((a) & inherited_flag_bit)     == inherited_flag_bit)
# define is_constant(a)             (((a) & constant_flag_bit)      == constant_flag_bit)

# define is_expandable(cmd)         (cmd > max_command_cmd)

# define global_or_local(a)         (is_global(a) ? level_one : cur_level)

# define has_flag_bits(p,a)         ((p) & (a))

# define remove_overload_flags(a)   ((a) & ~(permanent_flag_bit | immutable_flag_bit | primitive_flag_bit))

# define make_eq_flag_bits(a)       ((singleword) ((a) & 0xFF))
# define has_eq_flag_bits(p,a)      (eq_flag(p) & (a))
# define set_eq_flag_bits(p,a)      set_eq_flag(p, make_eq_flag_bits(a))

inline static singleword tex_flags_to_cmd(int flags)
{
    if (is_tolerant(flags)) {
        return is_protected    (flags) ? tolerant_protected_call_cmd :
              (is_semiprotected(flags) ? tolerant_semi_protected_call_cmd : tolerant_call_cmd);
    } else {
        return is_protected    (flags) ? protected_call_cmd :
              (is_semiprotected(flags) ? semi_protected_call_cmd : call_cmd);
    }
}

/*tex
    The macros and functions for the frozen, tolerant, protected cmd codes are gone but
    can be found in the archive. We now have just one |call_cmd| with properties stored
    elsewhere.

    int g -> singleword g
*/

extern int  tex_define_permitted   (halfword cs, halfword prefixes);
extern void tex_define             (int g, halfword p, singleword cmd, halfword chr);
extern void tex_define_again       (int g, halfword p, singleword cmd, halfword chr);
extern void tex_define_inherit     (int g, halfword p, singleword flag, singleword cmd, halfword chr);
extern void tex_define_swapped     (int g, halfword p1, halfword p2, int force);
extern void tex_forced_define      (int g, halfword p, singleword flag, singleword cmd, halfword chr);
extern void tex_word_define        (int g, halfword p, halfword w);
extern void tex_forced_word_define (int g, halfword p, singleword flag, halfword w);

/*tex

    The |*_par| macros expand to the variables that are (in most cases) also accessible at the users
    end. Most are registers but some are in the (stack) lists. More |*_par| will move here: there is
    no real need for these macros but because there were already a bunch and because they were defined
    all over the place we moved them here.

*/

# define space_skip_par                  glue_parameter(space_skip_code)
# define xspace_skip_par                 glue_parameter(xspace_skip_code)
# define math_skip_par                   glue_parameter(math_skip_code)
# define math_skip_mode_par              count_parameter(math_skip_mode_code)
# define math_double_script_mode_par     count_parameter(math_double_script_mode_code)
# define math_font_control_par           count_parameter(math_font_control_code)
# define math_display_mode_par           count_parameter(math_display_mode_code)
# define math_dict_group_par             count_parameter(math_dict_group_code)
# define math_dict_properties_par        count_parameter(math_dict_properties_code)
# define math_threshold_par              glue_parameter(math_threshold_code)
# define page_extra_goal_par             dimen_parameter(page_extra_goal_code)

# define pre_display_size_par            dimen_parameter(pre_display_size_code)
# define display_width_par               dimen_parameter(display_width_code)
# define display_indent_par              dimen_parameter(display_indent_code)
# define math_surround_par               dimen_parameter(math_surround_code)

# define display_skip_mode_par           count_parameter(math_display_skip_mode_code)
# define math_eqno_gap_step_par          count_parameter(math_eqno_gap_step_code)

# define par_direction_par               count_parameter(par_direction_code)
# define text_direction_par              count_parameter(text_direction_code)
# define math_direction_par              count_parameter(math_direction_code)

# define first_valid_language_par        count_parameter(first_valid_language_code)

# define hsize_par                       dimen_parameter(hsize_code)
# define vsize_par                       dimen_parameter(vsize_code)
# define hfuzz_par                       dimen_parameter(hfuzz_code)
# define vfuzz_par                       dimen_parameter(vfuzz_code)
# define hbadness_par                    count_parameter(hbadness_code)
# define vbadness_par                    count_parameter(vbadness_code)

# define baseline_skip_par               glue_parameter(baseline_skip_code)
# define line_skip_par                   glue_parameter(line_skip_code)
# define par_indent_par                  dimen_parameter(par_indent_code)
# define hang_indent_par                 dimen_parameter(hang_indent_code)
# define hang_after_par                  count_parameter(hang_after_code)
# define left_skip_par                   glue_parameter(left_skip_code)
# define right_skip_par                  glue_parameter(right_skip_code)
# define par_fill_left_skip_par          glue_parameter(par_fill_left_skip_code)
# define par_fill_right_skip_par         glue_parameter(par_fill_right_skip_code)
# define par_init_left_skip_par          glue_parameter(par_init_left_skip_code)
# define par_init_right_skip_par         glue_parameter(par_init_right_skip_code)
# define tab_skip_par                    glue_parameter(tab_skip_code)

# define emergency_stretch_par           dimen_parameter(emergency_stretch_code)
# define pre_tolerance_par               count_parameter(pre_tolerance_code)
# define tolerance_par                   count_parameter(tolerance_code)
# define looseness_par                   count_parameter(looseness_code)
# define adjust_spacing_par              count_parameter(adjust_spacing_code)
# define adjust_spacing_step_par         count_parameter(adjust_spacing_step_code)
# define adjust_spacing_stretch_par      count_parameter(adjust_spacing_stretch_code)
# define adjust_spacing_shrink_par       count_parameter(adjust_spacing_shrink_code)
# define adj_demerits_par                count_parameter(adj_demerits_code)
# define protrude_chars_par              count_parameter(protrude_chars_code)
# define line_penalty_par                count_parameter(line_penalty_code)
# define last_line_fit_par               count_parameter(last_line_fit_code)
# define double_hyphen_demerits_par      count_parameter(double_hyphen_demerits_code)
# define final_hyphen_demerits_par       count_parameter(final_hyphen_demerits_code)
# define inter_line_penalty_par          count_parameter(inter_line_penalty_code)
# define club_penalty_par                count_parameter(club_penalty_code)
# define widow_penalty_par               count_parameter(widow_penalty_code)
# define display_widow_penalty_par       count_parameter(display_widow_penalty_code)
# define orphan_penalty_par              count_parameter(orphan_penalty_code)
/*define page_boundary_penalty_par       count_parameter(page_boundary_penalty_code) */ /* now in |\pageboundary| */
# define line_break_criterium_par        count_parameter(line_break_criterium_code)
# define broken_penalty_par              count_parameter(broken_penalty_code)
# define line_skip_limit_par             dimen_parameter(line_skip_limit_code)

# define alignment_cell_source_par       count_parameter(alignment_cell_source_code)
# define alignment_wrap_source_par       count_parameter(alignment_wrap_source_code)

# define delimiter_shortfall_par         dimen_parameter(delimiter_shortfall_code)
# define null_delimiter_space_par        dimen_parameter(null_delimiter_space_code)
# define script_space_par                dimen_parameter(script_space_code)
# define max_depth_par                   dimen_parameter(max_depth_code)
# define box_max_depth_par               dimen_parameter(box_max_depth_code)
# define split_max_depth_par             dimen_parameter(split_max_depth_code)
# define overfull_rule_par               dimen_parameter(overfull_rule_code)
# define box_max_depth_par               dimen_parameter(box_max_depth_code)
# define ignore_depth_criterium_par      dimen_parameter(ignore_depth_criterium_code)

# define top_skip_par                    glue_parameter(top_skip_code)
# define split_top_skip_par              glue_parameter(split_top_skip_code)

# define cur_fam_par                     count_parameter(family_code)
# define variable_family_par             count_parameter(variable_family_code)
# define pre_display_direction_par       count_parameter(pre_display_direction_code)
# define pre_display_penalty_par         count_parameter(pre_display_penalty_code)
# define post_display_penalty_par        count_parameter(post_display_penalty_code)
# define pre_inline_penalty_par          count_parameter(pre_inline_penalty_code)
# define post_inline_penalty_par         count_parameter(post_inline_penalty_code)

# define local_interline_penalty_par     count_parameter(local_interline_penalty_code)
# define local_broken_penalty_par        count_parameter(local_broken_penalty_code)
# define local_left_box_par              box_parameter(local_left_box_code)
# define local_right_box_par             box_parameter(local_right_box_code)
# define local_middle_box_par            box_parameter(local_middle_box_code)

# define end_line_char_par               count_parameter(end_line_char_code)
# define new_line_char_par               count_parameter(new_line_char_code)
# define escape_char_par                 count_parameter(escape_char_code)

# define end_line_char_inactive          ((end_line_char_par < 0) || (end_line_char_par > 127))

/*tex
    We keep these as reference but they are no longer equivalent to regular \TEX\ because we have
    class based penalties instead.
*/

/*define post_binary_penalty_par         count_parameter(post_binary_penalty_code)   */
/*define post_relation_penalty_par       count_parameter(post_relation_penalty_code) */
/*define pre_binary_penalty_par          count_parameter(pre_binary_penalty_code)    */
/*define pre_relation_penalty_par        count_parameter(pre_relation_penalty_code)  */

# define delimiter_factor_par            count_parameter(delimiter_factor_code)
# define math_penalties_mode_par         count_parameter(math_penalties_mode_code)
# define math_check_fences_par           count_parameter(math_check_fences_mode_code)
# define math_slack_mode_par             count_parameter(math_slack_mode_code)
# define null_delimiter_space_par        dimen_parameter(null_delimiter_space_code)
# define disable_spaces_par              count_parameter(disable_spaces_code)
# define glyph_options_par               count_parameter(glyph_options_code)
# define glyph_scale_par                 count_parameter(glyph_scale_code)
# define glyph_text_scale_par            count_parameter(glyph_text_scale_code)
# define glyph_script_scale_par          count_parameter(glyph_script_scale_code)
# define glyph_scriptscript_scale_par    count_parameter(glyph_scriptscript_scale_code)
# define glyph_x_scale_par               count_parameter(glyph_x_scale_code)
# define glyph_y_scale_par               count_parameter(glyph_y_scale_code)
# define glyph_x_offset_par              dimen_parameter(glyph_x_offset_code)
# define glyph_y_offset_par              dimen_parameter(glyph_y_offset_code)
# define math_scripts_mode_par           count_parameter(math_scripts_mode_code)
# define math_limits_mode_par            count_parameter(math_limits_mode_code)
# define math_nolimits_mode_par          count_parameter(math_nolimits_mode_code)
# define math_rules_mode_par             count_parameter(math_rules_mode_code)
# define math_rules_fam_par              count_parameter(math_rules_fam_code)
# define math_glue_mode_par              count_parameter(math_glue_mode_code)

typedef enum math_glue_modes {
    math_glue_stretch_code = 0x01,
    math_glue_shrink_code  = 0x02,
} math_glue_modes;

# define math_glue_stretch_enabled       ((math_glue_mode_par & math_glue_stretch_code) == math_glue_stretch_code)
# define math_glue_shrink_enabled        ((math_glue_mode_par & math_glue_shrink_code) == math_glue_shrink_code)
# define default_math_glue_mode          (math_glue_stretch_code | math_glue_shrink_code)

# define petty_mu_skip_par               mu_glue_parameter(petty_mu_skip_code)
# define tiny_mu_skip_par                mu_glue_parameter(tiny_mu_skip_code)
# define thin_mu_skip_par                mu_glue_parameter(thin_mu_skip_code)
# define med_mu_skip_par                 mu_glue_parameter(med_mu_skip_code)
# define thick_mu_skip_par               mu_glue_parameter(thick_mu_skip_code)

# define every_math_par                  toks_parameter(every_math_code)
# define every_display_par               toks_parameter(every_display_code)
# define every_cr_par                    toks_parameter(every_cr_code)
# define every_tab_par                   toks_parameter(every_tab_code)
# define every_hbox_par                  toks_parameter(every_hbox_code)
# define every_vbox_par                  toks_parameter(every_vbox_code)
# define every_math_atom_par             toks_parameter(every_math_atom_code)
# define every_eof_par                   toks_parameter(every_eof_code)
# define every_par_par                   toks_parameter(every_par_code)
# define every_before_par_par            toks_parameter(every_before_par_code)
# define every_job_par                   toks_parameter(every_job_code)
# define error_help_par                  toks_parameter(error_help_code)
# define end_of_group_par                toks_parameter(end_of_group_code)
/*define end_of_par_par                  toks_parameter(end_of_par_code) */

# define internal_par_state_par          count_parameter(internal_par_state_code)
# define internal_dir_state_par          count_parameter(internal_dir_state_code)
# define internal_math_style_par         count_parameter(internal_math_style_code)
# define internal_math_scale_par         count_parameter(internal_math_scale_code)

# define overload_mode_par               count_parameter(overload_mode_code)

# define auto_paragraph_mode_par         count_parameter(auto_paragraph_mode_code)

typedef enum auto_paragraph_modes {
    auto_paragraph_text  = 0x01,
    auto_paragraph_macro = 0x02,
    auto_paragraph_go_on = 0x04,
} auto_paragraph_modes;

# define auto_paragraph_mode(flag) ((auto_paragraph_mode_par) & (flag))

# define shaping_penalties_mode_par      count_parameter(shaping_penalties_mode_code)
# define shaping_penalty_par             count_parameter(shaping_penalty_code)

typedef enum shaping_penalties_mode_bits {
    inter_line_penalty_shaping = 0x01,
    widow_penalty_shaping      = 0x02,
    club_penalty_shaping       = 0x04,
    broken_penalty_shaping     = 0x08,
} shaping_penalties_mode_bits;

# define is_shaping_penalties_mode(what,flag) ((what) & (flag))

# define tab_size_par                    dimen_parameter(tab_size_code)

# define par_shape_par                   specification_parameter(par_shape_code)
# define inter_line_penalties_par        specification_parameter(inter_line_penalties_code)
# define club_penalties_par              specification_parameter(club_penalties_code)
# define widow_penalties_par             specification_parameter(widow_penalties_code)
# define display_widow_penalties_par     specification_parameter(display_widow_penalties_code)
# define orphan_penalties_par            specification_parameter(orphan_penalties_code)
# define math_forward_penalties_par      specification_parameter(math_forward_penalties_code)
# define math_backward_penalties_par     specification_parameter(math_backward_penalties_code)

/*tex 
    We keep these three as reference but because they are backend related they are basically 
    no-ops and ignored. 
*/

/*define h_offset_par                    dimen_parameter(h_offset_code) */
/*define v_offset_par                    dimen_parameter(v_offset_code) */
/*define mag_par                         count_parameter(mag_code) */

# define px_dimen_par                    dimen_parameter(px_dimen_code)

# define max_dead_cycles_par             count_parameter(max_dead_cycles_code)
# define output_box_par                  count_parameter(output_box_code)
# define holding_inserts_par             count_parameter(holding_inserts_code)
# define holding_migrations_par          count_parameter(holding_migrations_code)
# define output_routine_par              toks_parameter(output_routine_code)
# define floating_penalty_par            count_parameter(floating_penalty_code)

# define global_defs_par                 count_parameter(global_defs_code)
# define cat_code_table_par              count_parameter(cat_code_table_code)
# define saving_vdiscards_par            count_parameter(saving_vdiscards_code)

# define tracing_output_par              count_parameter(tracing_output_code)
# define tracing_stats_par               count_parameter(tracing_stats_code)
# define tracing_online_par              count_parameter(tracing_online_code)
# define tracing_paragraphs_par          count_parameter(tracing_paragraphs_code)
# define tracing_levels_par              count_parameter(tracing_levels_code)
# define tracing_nesting_par             count_parameter(tracing_nesting_code)
# define tracing_alignments_par          count_parameter(tracing_alignments_code)
# define tracing_inserts_par             count_parameter(tracing_inserts_code)
# define tracing_marks_par               count_parameter(tracing_marks_code)
# define tracing_adjusts_par             count_parameter(tracing_adjusts_code)
# define tracing_lost_chars_par          count_parameter(tracing_lost_chars_code)
# define tracing_ifs_par                 count_parameter(tracing_ifs_code)
# define tracing_commands_par            count_parameter(tracing_commands_code)
# define tracing_macros_par              count_parameter(tracing_macros_code)
# define tracing_assigns_par             count_parameter(tracing_assigns_code)
# define tracing_fonts_par               count_parameter(tracing_fonts_code)
# define tracing_pages_par               count_parameter(tracing_pages_code)
# define tracing_restores_par            count_parameter(tracing_restores_code)
# define tracing_groups_par              count_parameter(tracing_groups_code)
# define tracing_math_par                count_parameter(tracing_math_code)
# define tracing_hyphenation_par         count_parameter(tracing_hyphenation_code)
# define tracing_expressions_par         count_parameter(tracing_expressions_code)
# define tracing_nodes_par               count_parameter(tracing_nodes_code)
# define tracing_full_boxes_par          count_parameter(tracing_full_boxes_code)
# define tracing_penalties_par           count_parameter(tracing_penalties_code)
# define tracing_lists_par               count_parameter(tracing_lists_code)

/*tex 
    This tracer is mostly there for debugging purposes. Therefore what gets traced and how might
    change depending on my needs. 
*/

typedef enum tracing_lists_codes {
    trace_direction_list_code = 0x0001, 
    trace_paragraph_list_code = 0x0002, 
    trace_linebreak_list_code = 0x0004, 
} tracing_lists_codes;

# define tracing_direction_lists         ((tracing_lists_par & trace_direction_list_code) == trace_direction_list_code)
# define tracing_paragraph_lists         ((tracing_lists_par & trace_paragraph_list_code) == trace_paragraph_list_code)
# define tracing_linebreak_lists         ((tracing_lists_par & trace_linebreak_list_code) == trace_linebreak_list_code)

# define show_box_depth_par              count_parameter(show_box_depth_code)
# define show_box_breadth_par            count_parameter(show_box_breadth_code)
# define show_node_details_par           count_parameter(show_node_details_code)

# define pausing_par                     count_parameter(pausing_code)

# define error_context_lines_par         count_parameter(error_context_lines_code)
# define copy_lua_input_nodes_par        count_parameter(copy_lua_input_nodes_code)

# define math_pre_display_gap_factor_par count_parameter(math_pre_display_gap_factor_code)

# define time_par                        count_parameter(time_code)
# define day_par                         count_parameter(day_code)
# define month_par                       count_parameter(month_code)
# define year_par                        count_parameter(year_code)

typedef enum hyphenation_mode_bits {
    normal_hyphenation_mode              = 0x00001,
    automatic_hyphenation_mode           = 0x00002,
    explicit_hyphenation_mode            = 0x00004,
    syllable_hyphenation_mode            = 0x00008,
    uppercase_hyphenation_mode           = 0x00010,
    compound_hyphenation_mode            = 0x00020,
    strict_start_hyphenation_mode        = 0x00040,
    strict_end_hyphenation_mode          = 0x00080,
    automatic_penalty_hyphenation_mode   = 0x00100,
    explicit_penalty_hyphenation_mode    = 0x00200,
    permit_glue_hyphenation_mode         = 0x00400,
    permit_all_hyphenation_mode          = 0x00800,
    permit_math_replace_hyphenation_mode = 0x01000,
    force_check_hyphenation_mode         = 0x02000,
    lazy_ligatures_hyphenation_mode      = 0x04000,
    force_handler_hyphenation_mode       = 0x08000,
    feedback_compound_hyphenation_mode   = 0x10000,
    ignore_bounds_hyphenation_mode       = 0x20000,
    collapse_hyphenation_mode            = 0x40000,
} hyphenation_mode_bits;

# define hyphenation_permitted(a,b)   (((a) & (b)) == (b))
# define set_hyphenation_mode(a,b)    ((a) | (b))
# define unset_hyphenation_mode(a,b)  ((a) & ~(b))
# define flip_hyphenation_mode(a,b)   ((b) ? set_hyphenation_mode(a,b) : unset_hyphenation_mode(a,b))
# define default_hyphenation_mode     (normal_hyphenation_mode | automatic_hyphenation_mode | explicit_hyphenation_mode | syllable_hyphenation_mode | compound_hyphenation_mode | force_handler_hyphenation_mode | feedback_compound_hyphenation_mode)

# define language_par                    count_parameter(language_code)
# define hyphenation_mode_par            count_parameter(hyphenation_mode_code)
# define uc_hyph_par                     count_parameter(uc_hyph_code)
# define left_hyphen_min_par             count_parameter(left_hyphen_min_code)
# define right_hyphen_min_par            count_parameter(right_hyphen_min_code)
# define ex_hyphen_char_par              count_parameter(ex_hyphen_char_code)
# define hyphen_penalty_par              count_parameter(hyphen_penalty_code)
# define ex_hyphen_penalty_par           count_parameter(ex_hyphen_penalty_code)
# define default_hyphen_char_par         count_parameter(default_hyphen_char_code)
# define default_skew_char_par           count_parameter(default_skew_char_code)
# define saving_hyph_codes_par           count_parameter(saving_hyph_codes_code)

# define automatic_hyphen_penalty_par    count_parameter(automatic_hyphen_penalty_code)
# define explicit_hyphen_penalty_par     count_parameter(explicit_hyphen_penalty_code)
# define exception_penalty_par           count_parameter(exception_penalty_code)

# define math_spacing_mode_par           count_parameter(math_spacing_mode_code)
# define math_grouping_mode_par          count_parameter(math_grouping_mode_code)
# define math_begin_class_par            count_parameter(math_begin_class_code)
# define math_end_class_par              count_parameter(math_end_class_code)
# define math_left_class_par             count_parameter(math_left_class_code)
# define math_right_class_par            count_parameter(math_right_class_code)
# define sup_mark_mode_par               count_parameter(sup_mark_mode_code)

# define glyph_data_par                  count_parameter(glyph_data_code)
# define glyph_state_par                 count_parameter(glyph_state_code)
# define glyph_script_par                count_parameter(glyph_script_code)

/*define glue_data_par                   count_parameter(glue_data_code) */

# define cur_lang_par                    count_parameter(language_code)
# define cur_font_par                    count_parameter(font_code)

typedef enum normalize_line_mode_bits {
    normalize_line_mode          = 0x0001,
    parindent_skip_mode          = 0x0002,
    swap_hangindent_mode         = 0x0004,
    swap_parshape_mode           = 0x0008,
    break_after_dir_mode         = 0x0010,
    remove_margin_kerns_mode     = 0x0020, /*tex When unpacking an hbox \unknown\ a \PDFTEX\ leftover. */
    clip_width_mode              = 0x0040,
    flatten_discretionaries_mode = 0x0080,
    discard_zero_tab_skips_mode  = 0x0100,
    flatten_h_leaders_mode       = 0x0200,
} normalize_line_mode_bits;

typedef enum normalize_par_mode_bits {
    normalize_par_mode     = 0x0001,
    flatten_v_leaders_mode = 0x0002, /* used to be 0x200 */
} normalize_par_mode_bits;

# define normalize_line_mode_permitted(a,b) ((a & b) == b)
# define normalize_par_mode_permitted(a,b) ((a & b) == b)

# define normalize_line_mode_par  count_parameter(normalize_line_mode_code)
# define normalize_par_mode_par   count_parameter(normalize_par_mode_code)
# define auto_migration_mode_par  count_parameter(auto_migration_mode_code)

typedef enum auto_migration_mode_bits {
     auto_migrate_mark   = 0x01,
     auto_migrate_insert = 0x02,
     auto_migrate_adjust = 0x04,
     auto_migrate_pre    = 0x08,
     auto_migrate_post   = 0x10,
} auto_migration_mode_bits;

# define auto_migrating_mode_permitted(what,flag) ((what & flag) == flag)

# define attribute_register(j) eq_value(register_attribute_location(j))
# define box_register(j)       eq_value(register_box_location(j))
# define count_register(j)     eq_value(register_int_location(j))
# define dimen_register(j)     eq_value(register_dimen_location(j))
# define mu_skip_register(j)   eq_value(register_mu_glue_location(j))
# define skip_register(j)      eq_value(register_glue_location(j))
# define toks_register(j)      eq_value(register_toks_location(j))

/*
    Injecting these frozen tokens can for instance happen when we scan for an integer or dimension
    and run into an |\else| or |\fi| because (guess what) these scanners gobble trailing spaces! In
    that case the |deep_frozen_relax_token| gets pushed back and can for instance end up in an
    expansion (macro, write, etc) because we only look ahead. However, we can catch this side effect
    in the scanners (that we redefined anyway). Removing those |\relax|'s was on the todo list and
    now happens in the scanners. Actually it's one reason why we often use constants in tests
    because these don't have that side effect because the scanner then quite earlier.) Another place
    where that happens is in the |\input| command but there we can use braces. It is a typical
    example of a more cosmetic adaptation that got a bit more priority when we converted the
    \CONTEXT\ codebase from \MKIV\ to \LMTX, where testing involved checking the results. I also have
    to check the other frozen tokens that can get reported when we have for instance alignments. It
    is also why some of these tokens have an associated (private but serialized) |\csname|.

    For the record: we can these tokens deep_frozen because we don't want them to be confused with
    the |\frozen| user macros and the ones below are really deeply hidden, although sometimes they
    do surface.

*/

typedef enum deep_frozen_cs_tokens {
    deep_frozen_protection_token     = cs_token_flag + deep_frozen_cs_protection_code,
    deep_frozen_cr_token             = cs_token_flag + deep_frozen_cs_cr_code,
    deep_frozen_end_group_token      = cs_token_flag + deep_frozen_cs_end_group_code,
    deep_frozen_right_token          = cs_token_flag + deep_frozen_cs_right_code,
    deep_frozen_fi_token             = cs_token_flag + deep_frozen_cs_fi_code,
    deep_frozen_end_template_1_token = cs_token_flag + deep_frozen_cs_end_template_1_code,
    deep_frozen_end_template_2_token = cs_token_flag + deep_frozen_cs_end_template_2_code,
    deep_frozen_relax_token          = cs_token_flag + deep_frozen_cs_relax_code,
    deep_frozen_end_write_token      = cs_token_flag + deep_frozen_cs_end_write_code,
    deep_frozen_dont_expand_token    = cs_token_flag + deep_frozen_cs_dont_expand_code,
    deep_frozen_null_font_token      = cs_token_flag + deep_frozen_cs_null_font_code,
    deep_frozen_undefined_token      = cs_token_flag + deep_frozen_cs_undefined_code,
} deep_frozen_cs_tokens;

/*tex

    The next has been simplified and replaced by |\hyphenatiomode| but we keep it as reminder:

    \starttabulate[|T|T|T|]
    \NC hyphen_penalty_mode_par \NC automatic_disc (-)           \NC explicit_disc (\-) \NC \NR
    \HL
    \NC 0 (default)             \NC ex_hyphen_penalty_par        \NC ex_hyphen_penalty_par \NC \NR
    \NC 1                       \NC hyphen_penalty_par           \NC hyphen_penalty_par \NC \NR
    \NC 2                       \NC ex_hyphen_penalty_par        \NC hyphen_penalty_par \NC \NR
    \NC 3                       \NC hyphen_penalty_par           \NC ex_hyphen_penalty_par \NC \NR
    \NC 4                       \NC automatic_hyphen_penalty_par \NC explicit_disc_penalty_par \NC \NR
    \NC 5                       \NC ex_hyphen_penalty_par        \NC explicit_disc_penalty_par \NC \NR
    \NC 6                       \NC hyphen_penalty_par           \NC explicit_disc_penalty_par \NC \NR
    \NC 7                       \NC automatic_hyphen_penalty_par \NC ex_hyphen_penalty_par \NC \NR
    \NC 8                       \NC automatic_hyphen_penalty_par \NC hyphen_penalty_par \NC \NR
    \stoptabulate

*/

extern halfword tex_automatic_disc_penalty (halfword mode);
extern halfword tex_explicit_disc_penalty  (halfword mode);

/*tex

    We add a bit more abstraction when setting the system parameters. This is not really
    needed but it move all the |eq_| assignments to a place where we can keep an eye on
    them.

*/

# define update_tex_glyph_data(a,v)            tex_word_define(a, internal_int_location(glyph_data_code), v)
# define update_tex_glyph_state(a,v)           tex_word_define(a, internal_int_location(glyph_state_code), v)
# define update_tex_glyph_script(a,v)          tex_word_define(a, internal_int_location(glyph_script_code), v)
# define update_tex_family(a,v)                tex_word_define(a, internal_int_location(family_code), v)
# define update_tex_variable_family(a,v)       tex_word_define(a, internal_int_location(variable_family_code), v)
# define update_tex_language(a,v)              tex_word_define(a, internal_int_location(language_code), v)
# define update_tex_font(a,v)                  tex_word_define(a, internal_int_location(font_code), v)

/*define update_tex_glue_data(a,v)             tex_word_define(a, internal_int_location(glue_data_code), v) */

# define update_tex_display_indent(v)          tex_eq_word_define(internal_dimen_location(display_indent_code), v)
# define update_tex_display_width(v)           tex_eq_word_define(internal_dimen_location(display_width_code), v)
# define update_tex_hang_after(v)              tex_eq_word_define(internal_int_location(hang_after_code), v)
# define update_tex_hang_indent(v)             tex_eq_word_define(internal_dimen_location(hang_indent_code), v)
# define update_tex_looseness(v)               tex_eq_word_define(internal_int_location(looseness_code), v)
# define update_tex_math_direction(v)          tex_eq_word_define(internal_int_location(math_direction_code), v)
# define update_tex_internal_par_state(v)      tex_eq_word_define(internal_int_location(internal_par_state_code), v)
# define update_tex_internal_dir_state(v)      tex_eq_word_define(internal_int_location(internal_dir_state_code), v)
# define update_tex_internal_math_style(v)     tex_eq_word_define(internal_int_location(internal_math_style_code), v)
# define update_tex_internal_math_scale(v)     tex_eq_word_define(internal_int_location(internal_math_scale_code), v)
# define update_tex_output_penalty(v)          tex_geq_word_define(internal_int_location(output_penalty_code), v)
# define update_tex_par_direction(v)           tex_eq_word_define(internal_int_location(par_direction_code), v)
# define update_tex_pre_display_direction(v)   tex_eq_word_define(internal_int_location(pre_display_direction_code), v)
# define update_tex_pre_display_size(v)        tex_eq_word_define(internal_dimen_location(pre_display_size_code), v)
# define update_tex_text_direction(v)          tex_eq_word_define(internal_int_location(text_direction_code), v)

# define update_tex_font_identifier(v)         tex_eq_word_define(internal_int_location(font_code), v)
# define update_tex_glyph_scale(v)             tex_eq_word_define(internal_int_location(glyph_scale_code), v)
# define update_tex_glyph_x_scale(v)           tex_eq_word_define(internal_int_location(glyph_x_scale_code), v)
# define update_tex_glyph_y_scale(v)           tex_eq_word_define(internal_int_location(glyph_y_scale_code), v)

# define update_tex_math_left_class(v)         tex_eq_word_define(internal_int_location(math_left_class_code), v)
# define update_tex_math_right_class(v)        tex_eq_word_define(internal_int_location(math_right_class_code), v)

# define update_tex_par_shape(v)               tex_eq_define(internal_specification_location(par_shape_code),            specification_reference_cmd, v)
# define update_tex_inter_line_penalties(v)    tex_eq_define(internal_specification_location(inter_line_penalties_code), specification_reference_cmd, v)
/*define update_tex_club_penalties(v)          eq_define(internal_specification_location(club_penalties_code),           specification_reference_cmd, v) */
/*define update_tex_widow_penalties(v)         eq_define(internal_specification_location(widow_penalties_code),          specification_reference_cmd, v) */
/*define update_tex_display_widow_penalties(v) eq_define(internal_specification_location(display_widow_penalties_code),  specification_reference_cmd, v) */
/*define update_tex_orphan_penalties(v)        eq_define(internal_specification_location(orphan_penalties_code),         specification_reference_cmd, v) */

# define update_tex_end_of_group(v)            tex_eq_define(internal_toks_location(end_of_group_code), internal_toks_reference_cmd, v)
/*define update_tex_end_of_par(v)              eq_define(internal_toks_location(end_of_par_code), internal_toks_cmd, v) */

# define update_tex_local_left_box(v)          tex_eq_define(internal_box_location(local_left_box_code),  internal_box_reference_cmd, v);
# define update_tex_local_right_box(v)         tex_eq_define(internal_box_location(local_right_box_code), internal_box_reference_cmd, v);
# define update_tex_local_middle_box(v)        tex_eq_define(internal_box_location(local_middle_box_code), internal_box_reference_cmd, v);

# define update_tex_font_local(f,v)            tex_eq_define(f, set_font_cmd, v); /* Here |f| already has the right offset. */
# define update_tex_font_global(f,v)          tex_geq_define(f, set_font_cmd, v); /* Here |f| already has the right offset. */

# define update_tex_tab_skip_local(v)          tex_eq_define(internal_glue_location(tab_skip_code), internal_glue_reference_cmd, v);
# define update_tex_tab_skip_global(v)        tex_geq_define(internal_glue_location(tab_skip_code), internal_glue_reference_cmd, v);

# define update_tex_box_local(n,v)             tex_eq_define(register_box_location(n), register_box_reference_cmd, v);
# define update_tex_box_global(n,v)           tex_geq_define(register_box_location(n), register_box_reference_cmd, v);

# define update_tex_insert_mode(a,v)           tex_word_define(a, internal_int_location(insert_mode_code), v)

/*tex For the moment here; a preparation for a dedicated insert structure. */

# define insert_content(A)    box_register(A)
# define insert_multiplier(A) count_register(A)
# define insert_maxheight(A)  dimen_register(A)
# define insert_distance(A)   skip_register(A)

typedef enum cs_errors {
    cs_no_error,
    cs_null_error,
    cs_below_base_error,
    cs_undefined_error, 
    cs_out_of_range_error,
} cs_errors;

extern int tex_cs_state(halfword p) ;

# endif
