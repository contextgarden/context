/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    The nested structure provided by |\char'173| \unknown\ |\char'175| groups in \TEX\ means that
    |eqtb| entries valid in outer groups should be saved and restored later if they are overridden
    inside the braces. When a new |eqtb| value is being assigned, the program therefore checks to
    see if the previous entry belongs to an outer level. In such a case, the old value is placed on
    the |save_stack| just before the new value enters |eqtb|. At the end of a grouping level, i.e.,
    when the right brace is sensed, the |save_stack| is used to restore the outer values, and the
    inner ones are destroyed.

    Entries on the |save_stack| are of type |save_record|. The top item on this stack is
    |save_stack[p]|, where |p=save_ptr-1|; it contains three fields called |save_type|, |save_level|,
    and |save_value|, and it is interpreted in one of four ways:

    \startitemize[n]

    \startitem
        If |save_type(p) = restore_old_value|, then |save_value(p)| is a location in |eqtb| whose
        current value should be destroyed at the end of the current group and replaced by
        |save_word(p-1)| (|save_type(p-1) == saved_eqtb|). Furthermore if |save_value(p) >= int_base|,
        then |save_level(p)| should replace the corresponding entry in |xeq_level| (if |save_value(p)
        < int_base|, then the level is part of |save_word(p-1)|).
    \stopitem

    \startitem
        If |save_type(p) = restore_zero|, then |save_value(p)| is a location in |eqtb| whose current
        value should be destroyed at the end of the current group, when it should be replaced by the
        current value of |eqtb[undefined_control_sequence]|.
    \stopitem

    \startitem
        If |save_type(p) = insert_token|, then |save_value(p)| is a token that should be inserted
        into \TeX's input when the current group ends.
    \stopitem

    \startitem
        If |save_type(p) = level_boundary|, then |save_level(p)| is a code explaining what kind of
        group we were previously in, and |save_value(p)| points to the level boundary word at the
        bottom of the entries for that group. Furthermore, |save_value(p-1)| contains the source
        line number at which the current level of grouping was entered, this field has itself a
        type: |save_type(p-1) == saved_line|.
    \stopitem

    \stopitemize

    Besides this \quote {official} use, various subroutines push temporary variables on the save
    stack when it is handy to do so. These all have an explicit |save_type|, and they are:

    \starttabulate
        \NC |saved_adjust|     \NC signifies an adjustment is beging scanned \NC\NR
        \NC |saved_insert|     \NC an insertion is being scanned \NC\NR
        \NC |saved_disc|       \NC the |\discretionary| sublist we are working on right now \NC\NR
        \NC |saved_boxtype|    \NC whether a |\localbox| is |\left| or |\right| \NC\NR
        \NC |saved_textdir|    \NC a text direction to be restored \NC\NR
        \NC |saved_eqno|       \NC diffentiates between |\eqno| and |\leqno| \NC\NR
        \NC |saved_choices|    \NC the |\mathchoices| sublist we are working on right now \NC\NR
        \NC |saved_above|      \NC used for the \LUAMETATEX\ above variants \NC\NR
        \NC |saved_math|       \NC and interrupted math list \NC\NR
        \NC |saved_boxcontext| \NC the box context value \NC\NR
        \NC |saved_boxspec|    \NC the box |to| or |spread| specification \NC\NR
        \NC |saved_boxdir|     \NC the box |dir| specification \NC\NR
        \NC |saved_boxattr|    \NC the box |attr| specification \NC\NR
        \NC |saved_boxpack|    \NC the box |pack| specification \NC\NR
        \NC |...|              \NC some more in \LUATEX\ and \LUAMETATEX \NC\NR
    \stoptabulate

    The global variable |cur_group| keeps track of what sort of group we are currently in. Another
    global variable, |cur_boundary|, points to the topmost |level_boundary| word. And |cur_level|
    is the current depth of nesting. The routines are designed to preserve the condition that no
    entry in the |save_stack| or in |eqtb| ever has a level greater than |cur_level|.

*/

save_state_info lmt_save_state = {
    .save_stack       = NULL,
    .save_stack_data  = {
        .minimum   = min_save_size,
        .maximum   = max_save_size,
        .size      = siz_save_size,
        .step      = stp_save_size,
        .allocated = 0,
        .itemsize  = sizeof(save_record),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
    },
    .current_level    = 0,
    .current_group    = 0,
    .current_boundary = 0,
 // .padding          = 0,
};

/*tex

    The comments below are (of course) coming from \LUATEX's ancestor and are still valid! However,
    in \LUATEX\ we use \UTF\ instead of \ASCII, have attributes, have more primites, etc. But the
    principles remain the same. We are not 100\% compatible in output and will never be.

*/

static void tex_aux_show_eqtb(halfword n);

static void tex_aux_diagnostic_trace(halfword p, const char *s)
{
    tex_begin_diagnostic();
    tex_print_format("{%s ", s);
    tex_aux_show_eqtb(p);
    tex_print_char('}');
    tex_end_diagnostic();
}

/*tex

    Now that we have studied the data structures for \TEX's semantic routines (in other modules),
    we ought to consider the data structures used by its syntactic routines. In other words, our
    next concern will be the tables that \TEX\ looks at when it is scanning what the user has
    written.

    The biggest and most important such table is called |eqtb|. It holds the current \quote
    {equivalents} of things; i.e., it explains what things mean or what their current values are,
    for all quantities that are subject to the nesting structure provided by \TEX's grouping
    mechanism. There are six parts to |eqtb|:

    \startitemize[n]

    \startitem
        |eqtb[null_cs]| holds the current equivalent of the zero-length control sequence.
    \stopitem

    \startitem
        |eqtb[hash_base..(glue_base-1)]| holds the current equivalents of single- and multiletter
        control sequences.
    \stopitem

    \startitem
        |eqtb[glue_base..(local_base-1)]| holds the current equivalents of glue parameters like
        the current baselineskip.
    \stopitem

    \startitem
        |eqtb[local_base..(int_base-1)]| holds the current equivalents of local halfword
        quantities like the current box registers, the current \quote {catcodes}, the current font,
        and a pointer to the current paragraph shape.
    \stopitem

    \startitem
        |eqtb[int_base .. (dimen_base-1)]| holds the current equivalents of fullword integer
        parameters like the current hyphenation penalty.
    \stopitem

    \startitem
        |eqtb[dimen_base .. eqtb_size]| holds the current equivalents of fullword dimension
        parameters like the current hsize or amount of hanging indentation.
    \stopitem

    \stopitemize

    Note that, for example, the current amount of baselineskip glue is determined by the setting of
    a particular location in region~3 of |eqtb|, while the current meaning of the control sequence
    |\baselineskip| (which might have been changed by |\def| or |\let|) appears in region~2.

    The last two regions of |eqtb| have fullword values instead of the three fields |eq_level|,
    |eq_type|, and |equiv|. An |eq_type| is unnecessary, but \TEX\ needs to store the |eq_level|
    information in another array called |xeq_level|.

    The last statement is no longer true. We have plenty of room in the 64 bit memory words now so
    we no longer need the parallel |x| array. For the moment we keep the commented code.

*/

// equivalents_state_info lmt_equivalents_state = {
// };

void tex_initialize_levels(void)
{
    cur_level = level_one;
    cur_group = bottom_level_group;
    cur_boundary = 0;
    lmt_scanner_state.last_cs_name = null_cs;
}

void tex_initialize_undefined_cs(void)
{
    set_eq_type(undefined_control_sequence, undefined_cs_cmd);
    set_eq_flag(undefined_control_sequence, 0);
    set_eq_value(undefined_control_sequence, null);
    set_eq_level(undefined_control_sequence, level_zero);
}

void tex_dump_equivalents_mem(dumpstream f)
{
    /*tex
        Dump regions 1 to 4 of |eqtb|, the table of equivalents: glue muglue toks boxes. The table
        of equivalents usually contains repeated information, so we dump it in compressed form: The
        sequence of $n + 2$ values $(n, x_1, \ldots, x_n, m)$ in the format file represents $n+m$
        consecutive entries of |eqtb|, with |m| extra copies of $x_n$, namely $(x_1, \ldots, x_n,
        x_n, \ldots, x_n)$.
    */
    int index = null_cs;
    do {
        int different = 1;
        int equivalent = 0;
        int j = index;
        while (j < eqtb_size - 1) {
            if (equal_eqtb_entries(j, j + 1)) {
                ++equivalent;
                goto FOUND1;
            } else {
                ++different;
            }
            ++j;
        }
        /*tex |j = int_base-1| */
        goto DONE1;
      FOUND1:
        j++;
        while (j < eqtb_size - 1) {
            if (equal_eqtb_entries(j, j + 1)) {
                ++equivalent;
            } else {
                goto DONE1;
            }
            ++j;
        }
      DONE1:
     // printf("index %i, different %i, equivalent %i\n",index,different,equivalent);
        dump_int(f, different);
        dump_things(f, lmt_hash_state.eqtb[index], different);
        dump_int(f, equivalent);
        index = index + different + equivalent;
    } while (index <= eqtb_size);
    /*tex Dump the |hash_extra| part: */
    dump_int(f, lmt_hash_state.hash_data.ptr);
    if (lmt_hash_state.hash_data.ptr > 0) {
        dump_things(f, lmt_hash_state.eqtb[eqtb_size + 1], lmt_hash_state.hash_data.ptr);
    }
    /*tex A special register. */
    dump_int(f, lmt_token_state.par_loc);
 /* dump_int(f, lmt_token_state.line_par_loc); */ /*tex See note in textoken.c|. */
    dump_int(f, lmt_token_state.empty);
}

void tex_undump_equivalents_mem(dumpstream f)
{
    /*tex Undump regions 1 to 6 of the table of equivalents |eqtb|. */
    int index = null_cs;
    do {
        int different;
        int equivalent;
        undump_int(f, different);
        if (different > 0) {
            undump_things(f, lmt_hash_state.eqtb[index], different);
        }
        undump_int(f, equivalent);
     // printf("index %i, different %i, equivalent %i\n",index,different,equivalent);
        if (equivalent > 0) {
            int last = index + different - 1;
            for (int i = 1; i <= equivalent; i++) {
                lmt_hash_state.eqtb[last + i] = lmt_hash_state.eqtb[last];
            }
        }
        index = index + different + equivalent;
    } while (index <= eqtb_size);
    /*tex Undump |hash_extra| part. */
    undump_int(f, lmt_hash_state.hash_data.ptr);
    if (lmt_hash_state.hash_data.ptr > 0) {
        /* we get a warning on possible overrun here */
        undump_things(f, lmt_hash_state.eqtb[eqtb_size + 1], lmt_hash_state.hash_data.ptr);
    }
    undump_int(f, lmt_token_state.par_loc);
    if (lmt_token_state.par_loc >= hash_base && lmt_token_state.par_loc <= lmt_hash_state.hash_data.top) {
        lmt_token_state.par_token = cs_token_flag + lmt_token_state.par_loc;
    } else {
        tex_fatal_undump_error("parloc");
    }
 /* undump_int(f, lmt_token_state.line_par_loc); */
 /* if (lmt_token_state.line_par_loc >= hash_base && lmt_token_state.line_par_loc <= lmt_hash_state.hash_data.top) { */
 /*     lmt_token_state.line_par_token = cs_token_flag + lmt_token_state.line_par_loc; */
 /* } else { */
 /*     tex_fatal_undump_error("lineparloc"); */
 /* } */
    undump_int(f, lmt_token_state.empty);
    return;
}

/*tex

    At this time it might be a good idea for the reader to review the introduction to |eqtb| that
    was given above just before the long lists of parameter names. Recall that the \quote {outer
    level} of the program is |level_one|, since undefined control sequences are assumed to be \quote
    {defined} at |level_zero|.

    The following function is used to test if there is room for up to eight more entries on
    |save_stack|. By making a conservative test like this, we can get by with testing for overflow
    in only a few places.

    We now let the save stack dynamically grow. In practice the stack is small but when a large one
    is needed, the overhead is probably neglectable compared to what the macro need.

*/

# define reserved_save_stack_slots 32 /* We need quite some for boxes so we bump it. */

void tex_initialize_save_stack(void)
{
    int size = lmt_save_state.save_stack_data.minimum;
    lmt_save_state.save_stack = aux_allocate_clear_array(sizeof(save_record), lmt_save_state.save_stack_data.step, reserved_save_stack_slots);
    if (lmt_save_state.save_stack) {
        lmt_save_state.save_stack_data.allocated = lmt_save_state.save_stack_data.step;
    } else {
        tex_overflow_error("save", size);
    }
}

static int tex_room_on_save_stack(void)
{
    int top = lmt_save_state.save_stack_data.ptr;
    if (top > lmt_save_state.save_stack_data.top) {
        lmt_save_state.save_stack_data.top = top;
        if (top > lmt_save_state.save_stack_data.allocated) {
            save_record *tmp = NULL;
            top = lmt_save_state.save_stack_data.allocated + lmt_save_state.save_stack_data.step;
            if (top > lmt_save_state.save_stack_data.size) {
                top = lmt_save_state.save_stack_data.size;
            }
            if (top > lmt_save_state.save_stack_data.allocated) {
                top = lmt_save_state.save_stack_data.allocated + lmt_save_state.save_stack_data.step;
                tmp = aux_reallocate_array(lmt_save_state.save_stack, sizeof(save_record), top, reserved_save_stack_slots);
                lmt_save_state.save_stack = tmp;
            }
            lmt_run_memory_callback("save", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("save", top);
                return 0;
            }
         // memset((void *) (lmt_save_state.save_stack + lmt_save_state.save_stack_data.allocated + 1), 0, ((size_t) lmt_save_state.save_stack_data.step + reserved_save_stack_slots) * sizeof(save_record));
            lmt_save_state.save_stack_data.allocated = top;
        }
    }
    return 1;
}

void tex_save_halfword_on_stack(quarterword t, halfword v) /* todo: also value_2 and value_3 */
{
    if (tex_room_on_save_stack()) {
        saved_type(0) = t;
        saved_record(0) = 0;
        saved_value_1(0) = v;
        ++lmt_save_state.save_stack_data.ptr;
    }
}

/*tex

    Procedure |new_save_level| is called when a group begins. The argument is a group identification
    code like |hbox_group|. After calling this routine, it is safe to put six more entries on
    |save_stack|.

    In some cases integer-valued items are placed onto the |save_stack| just below a |level_boundary|
    word, because this is a convenient place to keep information that is supposed to \quote {pop up}
    just when the group has finished. For example, when |\hbox to 100pt| is being treated, the 100pt
    dimension is stored on |save_stack| just before |new_save_level| is called.

    The |group_trace| procedure is called when a new level of grouping begins (|e=false|) or ends
    (|e = true|) with |saved_value (-1)| containing the line number.

*/

static void tex_aux_group_trace(int g)
{
    tex_begin_diagnostic();
    tex_print_format(g ? "{leaving %G}" : "{entering %G}", g);
    tex_end_diagnostic();
}

/*tex

    A group entered (or a conditional started) in one file may end in a different file. Such
    slight anomalies, although perfectly legitimate, may cause errors that are difficult to
    locate. In order to be able to give a warning message when such anomalies occur, \ETEX\
    uses the |grp_stack| and |if_stack| arrays to record the initial |cur_boundary| and
    |condition_ptr| values for each input file.

    When a group ends that was apparently entered in a different input file, the |group_warning|
    procedure is invoked in order to update the |grp_stack|. If moreover |\tracingnesting| is
    positive we want to give a warning message. The situation is, however, somewhat complicated
    by two facts:

    \startitemize[n,packed]
        \startitem
            There may be |grp_stack| elements without a corresponding |\input| file or
            |\scantokens| pseudo file (e.g., error insertions from the terminal); and
        \stopitem
        \startitem
            the relevant information is recorded in the |name_field| of the |input_stack| only
            loosely synchronized with the |in_open| variable indexing |grp_stack|.
        \stopitem
    \stopitemize

    Per end 2023 the decision was made to use the two halfwords in the memory word that is used for
    saving eq values for other purposes too. It meant for instance that instead if every new group 
    needing 3 stack entries, it now needs just one. Actually there are not that meny mechanism that 
    need the stack. For instance alignments have their own stack, math needs it for multi argument 
    mechanism and the most demanding one is box handling. In addition to the two extra |value_2| and 
    |value_3| fields we also use |options| and |extra| as alias for |level| (these are quarterwords). 

*/

static void tex_aux_group_warning(void)
{
    /*tex do we need a warning? */
    bool warning = false;
    /*tex index into |grp_stack| */
    int index = lmt_input_state.in_stack_data.ptr;
    lmt_input_state.base_ptr = lmt_input_state.input_stack_data.ptr;
    /*tex store current state */
    lmt_input_state.input_stack[lmt_input_state.base_ptr] = lmt_input_state.cur_input;
    while ((lmt_input_state.in_stack[index].group == cur_boundary) && (index > 0)) {
        /*tex

            Set variable |w| to indicate if this case should be reported. This code scans the input
            stack in order to determine the type of the current input file.

        */
        if (tracing_nesting_par > 0) {
            while ((lmt_input_state.input_stack[lmt_input_state.base_ptr].state == token_list_state) || (lmt_input_state.input_stack[lmt_input_state.base_ptr].index > index)) {
                --lmt_input_state.base_ptr;
            }
            if (lmt_input_state.input_stack[lmt_input_state.base_ptr].name > 17) {
                /*tex |>  max_file_input_code| .. hm */
                warning = true;
            }
        }
        lmt_input_state.in_stack[index].group = save_value(lmt_save_state.save_stack_data.ptr);
        --index;
    }
    if (warning) {
        tex_begin_diagnostic();
        tex_print_format("[warning: end of %G of a different file]", 1);
        tex_end_diagnostic();
        if (tracing_nesting_par > 1) {
            tex_show_context();
        }
        if (lmt_error_state.history == spotless) {
            lmt_error_state.history = warning_issued;
        }
    }
}

/*tex 
    We store the line number and attribute state in the memory word part for the save entry and  
    then we need only one slot instead of three. Each slot is 16 bytes so we're also a bit nicer to 
    caching memory (if it happens at all). Because in practice we don't group that much (400.000 
    times in the luametatex manual and a similar amount in the primitives manual) there is no real  
    significant (positive) impact on performance. It's all about abstraction. 
*/

typedef enum saved_group_entries {
    saved_group_group_entry           = 0,
    saved_group_boundary_entry        = 0,
    saved_group_attribute_state_entry = 0,
    saved_group_input_line_entry      = 0,
    saved_group_n_records             = 1,
} saved_group_entries;

# define saved_group_group           saved_group(saved_group_group_entry)
# define saved_group_boundary        saved_value_1(saved_group_boundary_entry)
# define saved_group_attribute_state saved_value_2(saved_group_attribute_state_entry)
# define saved_group_input_line      saved_value_3(saved_group_input_line_entry)

inline static void saved_group_initialize(void)
{
    saved_type(0) = level_boundary_save_type;
    /* here level is really level */
}

void tex_new_save_level(quarterword group)
{
    /*tex We begin a new level of grouping. This will cost us three entries. */
    if (tex_room_on_save_stack()) {
        add_attribute_reference(current_attribute_state); 
        saved_group_initialize();
        saved_group_group = cur_group;
        saved_group_boundary = cur_boundary;
        saved_group_attribute_state = current_attribute_state;
        saved_group_input_line = lmt_input_state.input_line;
        if (cur_level == max_quarterword) {
            /*tex We quit if |(cur_level+1)| is too big to be stored in |eqtb|. */
            tex_overflow_error("grouping levels", max_quarterword - min_quarterword);
        }
        cur_boundary = lmt_save_state.save_stack_data.ptr;
        cur_group = group;
        if (tracing_groups_par > 0) {
            tex_aux_group_trace(0);
        }
        ++cur_level;
        lmt_save_state.save_stack_data.ptr += saved_group_n_records;
        if (end_of_group_par) {
            update_tex_end_of_group(null);
        }
    }
}

int tex_saved_line_at_level(void)
{
    return lmt_save_state.save_stack_data.ptr > 0 ? (saved_group_input_line > 0 ? saved_group_input_line : 0) : 0;
}

/*tex

    The |\showgroups| command displays all currently active grouping levels. The modifications of
    \TEX\ required for the display produced by the |show_save_groups| procedure were first discussed
    by Donald~E. Knuth in {\em TUGboat} {\bf 11}, 165--170 and 499--511, 1990.

    In order to understand a group type we also have to know its mode. Since unrestricted horizontal
    modes are not associated with grouping, they are skipped when traversing the semantic nest.

    I have to admit that I never used (or needed) this so we might as well drop it from \LUAMETATEX\
    and given the already extensive tracing we can decide to drop it.

    The output is not (entirely) downward compatible which is no big deal because we output some more
    details anyway.
*/

void tex_show_save_groups(void)
{
    int pointer = lmt_nest_state.nest_data.ptr;
    int saved_pointer = lmt_save_state.save_stack_data.ptr;
    quarterword saved_level = cur_level;
    quarterword saved_group = cur_group;
    halfword saved_tracing = tracing_levels_par;
    int alignmentstate = 1; /* to keep track of alignments */
    const char *package = NULL;
    lmt_save_state.save_stack_data.ptr = cur_boundary;
    --cur_level;
    tracing_levels_par |= tracing_levels_group;
    while (1) {
        int mode;
        tex_print_levels();
        tex_print_group(1);
        if (cur_group == bottom_level_group) {
            goto DONE;
        }
        do {
            mode = lmt_nest_state.nest[pointer].mode;
            if (pointer > 0) {
                --pointer;
            } else {
                mode = vmode;
            }
        } while (mode == hmode);
        tex_print_str(": ");
        switch (cur_group) {
            case simple_group:
                ++pointer;
                goto FOUND2;
            case hbox_group:
            case adjusted_hbox_group:
                package = "hbox";
                break;
            case vbox_group:
                package = "vbox";
                break;
            case vtop_group:
                package = "vtop";
                break;
            case dbox_group:
                package = "dbox";
                break;
            case align_group:
                if (alignmentstate == 0) {
                    package = (mode == internal_vmode) ? "halign" : "valign";
                    alignmentstate = 1;
                    goto FOUND1;
                } else {
                    if (alignmentstate == 1) {
                        tex_print_str("align entry");
                    } else {
                        tex_print_str_esc("cr");
                    }
                    if (pointer >= alignmentstate) {
                        pointer -= alignmentstate;
                    }
                    alignmentstate = 0;
                    goto FOUND2;
                }
            case no_align_group:
                ++pointer;
                alignmentstate = -1;
                tex_print_str_esc("noalign");
                goto FOUND2;
            case output_group:
                tex_print_str_esc("output");
                goto FOUND2;
         // maybe: 
         //
         // case math_group:
         // case math_component_group:
         // case math_stack_group:
         //      tex_print_str_esc(lmt_interface.group_code_values[cur_group].name);
         //      goto FOUND2;
            case math_group:
                tex_print_str_esc("mathsubformula");
                goto FOUND2;
            case math_component_group:
                tex_print_str_esc("mathcomponent");
                goto FOUND2;
            case math_stack_group:
                tex_print_str_esc("mathstack");
                goto FOUND2;
            case discretionary_group:
                tex_show_discretionary_group();
                goto FOUND2;
            case math_fraction_group:
                tex_show_math_fraction_group();
                goto FOUND2;
            case math_radical_group:
                tex_show_math_radical_group();
                goto FOUND2;
            case math_operator_group:
                tex_show_math_operator_group();
                goto FOUND2;
            case math_choice_group:
                tex_show_math_choice_group();
                goto FOUND2;
            case insert_group:
                tex_show_insert_group();
                goto FOUND2;
            case vadjust_group:
                tex_show_adjust_group();
                goto FOUND2;
            case vcenter_group:
                package = "vcenter";
                goto FOUND1;
            case also_simple_group:
            case semi_simple_group:
                ++pointer;
                tex_print_str_esc("begingroup");
                goto FOUND2;
         // case math_simple_group:
         //     ++pointer;
         //     tex_print_str_esc("beginmathgroup");
         //     goto FOUND2;
            case math_inline_group:
                tex_print_char('$');
            case math_display_group:
                tex_print_char('$');
                goto FOUND2;
            case math_number_group:
                tex_show_math_number_group();
                goto FOUND2;
            case math_fence_group:
                /* kind of ugly ... maybe also save that one */ /* todo: operator */
                tex_print_str_esc((node_subtype(lmt_nest_state.nest[pointer + 1].delimiter) == left_fence_side) ? "left" : "middle");
                goto FOUND2;
            default:
                tex_confusion("show groups");
                break;
        }
        /*tex 
            Show the box context. In traditional \TEX\ the shift is encoded in the context which is 
            why it had such a large offset for the other context value. That somewhat dirty trick 
            was has stepwise been removed.
        */
        switch (tex_get_packaging_context()) {
            case direct_box_flag:
                {
                    scaled shift = tex_get_packaging_shift();
                    if (shift != null_flag) { 
                        /*tex We passed the safeguard. */
                        singleword cmd = is_v_mode(lmt_nest_state.nest[pointer].mode) ? hmove_cmd : vmove_cmd;
                        tex_print_cmd_chr(cmd, (shift > 0) ? move_forward_code : move_backward_code);
                        tex_print_dimension(abs(shift), pt_unit);
                    }
                }
                break;
            case global_box_flag:
                tex_print_str_esc("global");
            case box_flag:
                {
                    tex_print_str_esc("setbox");
                    tex_print_int(tex_get_packaging_context());
                    tex_print_char('=');
                }
                break;
            case a_leaders_flag:
                tex_print_cmd_chr(leader_cmd, a_leaders);
                break;
            case c_leaders_flag:
                tex_print_cmd_chr(leader_cmd, c_leaders);
                break;
            case x_leaders_flag:
                tex_print_cmd_chr(leader_cmd, x_leaders);
                break;
            case g_leaders_flag:
                tex_print_cmd_chr(leader_cmd, g_leaders);
                break;
            case u_leaders_flag:
                tex_print_cmd_chr(leader_cmd, u_leaders);
                break;
        }
      FOUND1:
        tex_show_packaging_group(package);
      FOUND2:
        --cur_level;
        cur_group = saved_group_group;
        lmt_save_state.save_stack_data.ptr = saved_group_boundary;
    }
  DONE:
    lmt_save_state.save_stack_data.ptr = saved_pointer;
    cur_level = saved_level;
    cur_group = saved_group;
    tracing_levels_par = saved_tracing;
}

void tex_show_save_stack(void)
{
    halfword savedptr = lmt_save_state.save_stack_data.ptr;
    tex_print_format("%l[savestack size %i]\n", lmt_save_state.save_stack_data.ptr);
    while (lmt_save_state.save_stack_data.ptr) {
        --lmt_save_state.save_stack_data.ptr;
        tex_print_nlp();
        tex_print_levels();
        tex_print_format("[%i: ", lmt_save_state.save_stack_data.ptr);
        if (save_type(lmt_save_state.save_stack_data.ptr) >= saved_record_0 && save_type(lmt_save_state.save_stack_data.ptr) <= saved_record_9) {
            tex_print_format("save record %i, ", save_type(lmt_save_state.save_stack_data.ptr) - saved_record_0 + 1, save_record(lmt_save_state.save_stack_data.ptr));
            /* these have to be provided in the modules */
            switch (save_record(lmt_save_state.save_stack_data.ptr)) {
                case unknown_save_type:
                    break;
                case box_save_type:
                    if (tex_show_packaging_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case local_box_save_type:
                    if (tex_show_localbox_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case alignment_save_type:
                    if (tex_show_alignment_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case adjust_save_type:
                    if (tex_show_adjust_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case math_save_type:
                    if (tex_show_math_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case fraction_save_type:
                    if (tex_show_math_fraction_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case radical_save_type:
                    if (tex_show_math_radical_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case operator_save_type:
                    if (tex_show_math_operator_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case math_group_save_type:
                    if (tex_show_math_group_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case choice_save_type:
                    if (tex_show_math_choice_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case number_save_type:
                    if (tex_show_math_number_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case insert_save_type:
                    if (tex_show_insert_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                case discretionary_save_type:
                    if (tex_show_discretionary_record()) {
                        break;
                    } else { 
                        goto INVALID_TYPE;
                    }
                default: 
                    goto INVALID_RECORD;
            }
        } else {
            switch (save_type(lmt_save_state.save_stack_data.ptr)) {
                case level_boundary_save_type:
                    tex_print_format("boundary, group '%s', boundary %i, attrlist %i, line %i", lmt_interface.group_code_values[saved_group_group].name, saved_group_boundary, saved_group_attribute_state, tex_saved_line_at_level());
                    break;
                case restore_old_value_save_type:
                    tex_print_format("restore, level %i, cs ", save_level(lmt_save_state.save_stack_data.ptr));
                    tex_aux_show_eqtb(save_value(lmt_save_state.save_stack_data.ptr));
                    break;
                case insert_tokens_save_type:
                    tex_print_format("insert, pointer %i", save_value(lmt_save_state.save_stack_data.ptr));
                    break;
                case restore_lua_save_type:
                    tex_print_format("restore lua, level %i, function %i", save_level(lmt_save_state.save_stack_data.ptr), save_value(lmt_save_state.save_stack_data.ptr));
                    break;
                case restore_zero_save_type:
                    tex_print_format("restore zero, level %i, cs ", save_level(lmt_save_state.save_stack_data.ptr));
                    tex_aux_show_eqtb(save_value(lmt_save_state.save_stack_data.ptr));
                    break;
                default:
                    goto INVALID_TYPE;
            }
        }
        goto DONE;
      INVALID_RECORD:
        tex_print_format("invalid record %i", save_record(lmt_save_state.save_stack_data.ptr));
        goto DONE;
      INVALID_TYPE:
        tex_print_format("invalid type %i", save_type(lmt_save_state.save_stack_data.ptr));
        goto DONE;
      DONE:
        tex_print_char(']');
        tex_print_nlp();
    }
    tex_print_format("%l[savestack bottom]\n");
    lmt_save_state.save_stack_data.ptr = savedptr;
}

/*tex
    This is an experiment. The |handle_overload| function can either go on or quit, depending on
    how strong one wants to check for overloads.

    \starttabulate[||||||||]
        \NC   \NC         \NC immutable \NC permanent \NC primitive \NC frozen \NC instance \NC \NR
        \NC 1 \NC warning \NC +         \NC +         \NC +         \NC        \NC          \NC \NR
        \NC 2 \NC error   \NC +         \NC +         \NC +         \NC        \NC          \NC \NR
        \NC 3 \NC warning \NC +         \NC +         \NC +         \NC +      \NC          \NC \NR
        \NC 4 \NC error   \NC +         \NC +         \NC +         \NC +      \NC          \NC \NR
        \NC 5 \NC warning \NC +         \NC +         \NC +         \NC +      \NC +        \NC \NR
        \NC 6 \NC error   \NC +         \NC +         \NC +         \NC +      \NC +        \NC \NR
    \stoptabulate

    The overload callback gets passed:
        (boolean) error,
        (integer) overload,
        (string)  csname,
        (integer) flags.

    See January 2020 files for an alternative implementation.
*/

static void tex_aux_handle_overload(const char *s, halfword cs, int overload, int error_type)
{
    int callback_id = lmt_callback_defined(handle_overload_callback);
    if (callback_id > 0) {
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "bdsd->", error_type == normal_error_type, overload, cs_text(cs), eq_flag(cs));
    } else {
        tex_handle_error(
            error_type,
            "You can't redefine %s %S.",
            s, cs,
            NULL
        );
    }
}

static int tex_aux_report_overload(halfword cs, int overload)
{
    int error_type = overload & 1 ? warning_error_type : normal_error_type;
    if (has_eq_flag_bits(cs, immutable_flag_bit)) {
        tex_aux_handle_overload("immutable", cs, overload, error_type);
    } else if (has_eq_flag_bits(cs, primitive_flag_bit)) {
        tex_aux_handle_overload("primitive", cs, overload, error_type);
    } else if (has_eq_flag_bits(cs, permanent_flag_bit)) {
        tex_aux_handle_overload("permanent", cs, overload, error_type);
    } else if (has_eq_flag_bits(cs, frozen_flag_bit)) {
        tex_aux_handle_overload("frozen", cs, overload, error_type);
    } else if (has_eq_flag_bits(cs, instance_flag_bit)) {
        tex_aux_handle_overload("instance", cs, overload, warning_error_type);
        return 1;
    }
    return error_type == warning_error_type;
}

# define overload_error_type(overload) (overload & 1 ? warning_error_type : normal_error_type)

int tex_define_permitted(halfword cs, halfword prefixes)
{
    halfword overload = overload_mode_par;
    if (! cs || ! overload || has_eq_flag_bits(cs, mutable_flag_bit)) {
        return 1;
    } else if (is_overloaded(prefixes)) {
        if (overload > 2 && has_eq_flag_bits(cs, immutable_flag_bit | permanent_flag_bit | primitive_flag_bit)) {
            return tex_aux_report_overload(cs, overload);
        }
    } else if (overload > 4) {
        if (has_eq_flag_bits(cs, immutable_flag_bit | permanent_flag_bit | primitive_flag_bit | frozen_flag_bit | instance_flag_bit)) {
            return tex_aux_report_overload(cs, overload);
        }
    } else if (overload > 2) {
        if (has_eq_flag_bits(cs, immutable_flag_bit | permanent_flag_bit | primitive_flag_bit | frozen_flag_bit)) {
            return tex_aux_report_overload(cs, overload);
        }
    } else if (has_eq_flag_bits(cs, immutable_flag_bit)) {
        return tex_aux_report_overload(cs, overload);
    }
    return 1;
}

static int tex_aux_mutation_permitted(halfword cs)
{
    halfword overload = overload_mode_par;
    if (cs && overload && has_eq_flag_bits(cs, immutable_flag_bit)) {
        return tex_aux_report_overload(cs, overload);
    } else {
        return 1;
    }
}

/*tex

    Just before an entry of |eqtb| is changed, the following procedure should be called to update
    the other data structures properly. It is important to keep in mind that reference counts in
    |mem| include references from within |save_stack|, so these counts must be handled carefully.

*/

// static void tex_aux_eq_destroy(memoryword w)
// {
//     halfword p = eq_value_field(w);
//     if (p) { 
//         switch (eq_type_field(w)) {
//             case call_cmd:
//             case protected_call_cmd:
//             case semi_protected_call_cmd:
//             case constant_call_cmd:
//             case tolerant_call_cmd:
//             case tolerant_protected_call_cmd:
//             case tolerant_semi_protected_call_cmd:
//             case register_toks_reference_cmd:
//             case internal_toks_reference_cmd:
//                 tex_delete_token_reference(p);
//                 break;
//             case internal_glue_reference_cmd:
//             case register_glue_reference_cmd:
//             case internal_muglue_reference_cmd:
//             case register_muglue_reference_cmd:
//             case gluespec_cmd:
//             case mugluespec_cmd:
//             case mathspec_cmd:
//             case fontspec_cmd:
//             case specification_reference_cmd:
//                 tex_flush_node(p);
//                 break;
//             case internal_box_reference_cmd:
//             case register_box_reference_cmd:
//                 tex_flush_node_list(p);
//                 break;
//             default:
//                 break;
//         }
//     }
// }

// static int tex_aux_eq_destructor(memoryword w)
// {
//     return eq_value_field(w) ? lmt_hash_state.destructors[eq_type_field(w)] : 0;
// }

inline static void tex_aux_eq_destroy(memoryword w)
{
    halfword p = eq_value_field(w);
    if (p) { 
        switch (lmt_hash_state.destructors[eq_type_field(w)]) {
            case eq_token_list: 
                tex_delete_token_reference(p);
                break;
            case eq_node: 
                tex_flush_node(p);
                break;
            case eq_node_list: 
                tex_flush_node_list(p);
                break;
        }
    }
}

/*tex

    To save a value of |eqtb[p]| that was established at level |l|, we can use the following
    subroutine. This code could be simplified after the xeq cleanup so we actually use one slot
    less per saved value.

*/

static void tex_aux_eq_save(halfword p, quarterword l)
{
    if (tex_room_on_save_stack()) {
        if (l == level_zero) {
            save_type(lmt_save_state.save_stack_data.ptr) = restore_zero_save_type;
        } else {
            save_type(lmt_save_state.save_stack_data.ptr) = restore_old_value_save_type;
            save_word(lmt_save_state.save_stack_data.ptr) = lmt_hash_state.eqtb[p];
        }
        save_level(lmt_save_state.save_stack_data.ptr) = l;
        save_value(lmt_save_state.save_stack_data.ptr) = p;
        ++lmt_save_state.save_stack_data.ptr;
    }
}

/*tex

    The procedure |eq_define| defines an |eqtb| entry having specified |eq_type| and |equiv| fields,
    and saves the former value if appropriate. This procedure is used only for entries in the first
    four regions of |eqtb|, i.e., only for entries that have |eq_type| and |equiv| fields. After
    calling this routine, it is safe to put four more entries on |save_stack|, provided that there
    was room for four more entries before the call, since |eq_save| makes the necessary test.

    The destroy if same branch comes from \ETEX\ but is it really right to destroy here if we
    actually want to keep the value? In practice we only come here with zero cases but even then,
    it looks like we can destroy the token list or node (list). Not, that might actually work ok in
    the case of glue refs that have work by ref count and token lists and node (lists) are always
    different so there we do no harm.

    There is room for some optimization here. 

*/

inline static int tex_aux_equal_eq(halfword p, singleword cmd, singleword flag, halfword chr)
{
    /* maybe keep flag test at call end and then only flip flags */
    if (eq_flag(p) == flag) {
     // printf("eqtest> %03i %03i\n",eq_type(p),cmd);
        switch (eq_type(p)) {
            case internal_glue_reference_cmd:
            case register_glue_reference_cmd:
            case internal_muglue_reference_cmd:
            case register_muglue_reference_cmd:
            case gluespec_cmd:
            case mugluespec_cmd:
                /*tex We compare the pointer as well as the record. */
                if (tex_same_glue(eq_value(p), chr)) {
                    if (chr) {
                        tex_flush_node(chr);
                    }
                    return 1;
                } else {
                    return 0;
                }
            case mathspec_cmd:
                /*tex Idem here. */
                if (tex_same_mathspec(eq_value(p), chr)) {
                    if (chr) {
                        tex_flush_node(chr);
                    }
                    return 1;
                } else {
                    return 0;
                }
            case fontspec_cmd:
                /*tex And here. */
                if (tex_same_fontspec(eq_value(p), chr)) {
                    if (chr) {
                        tex_flush_node(chr);
                    }
                    return 1;
                } else {
                    return 0;
                }
            /*  
            case specificationspec_cmd:
                if (eq_type(p) == cmd && eq_value(p) == chr) {
                    return 1;
                } else { 
                    return 0;
                }
            */
            case call_cmd:
            case protected_call_cmd:
            case semi_protected_call_cmd:
            case constant_call_cmd:
            case tolerant_call_cmd:
            case tolerant_protected_call_cmd:
            case tolerant_semi_protected_call_cmd:
                /*tex The initial token reference will do as it is unique. */
             // if (eq_value(p) == chr) {
                if (eq_value(p) == chr && eq_level(p) == cur_level) {
                    tex_delete_token_reference(eq_value(p));
                    return 1;
                } else {
                    return 0;
                }
            case specification_reference_cmd:
            case unit_reference_cmd:
            case internal_box_reference_cmd:
            case register_box_reference_cmd:
                /*tex These are also references. The ! chr is a bit strange. Todo: test without. */
// if (eq_type(p) == cmd && eq_value(p) == chr && chr) {
//     printf("SAME\n");
//     // destoy ?? 
// }
                if (eq_type(p) == cmd && eq_value(p) == chr && ! chr) {
             // if (eq_type(p) == cmd && eq_value(p) == chr && ! chr && eq_level(p) == cur_level) {
                    return 1;
                } else {
                    /* play safe */
                    return 0;
                }
            case internal_toks_reference_cmd:
            case register_toks_reference_cmd:
                /*tex As are these. */
                if (p && chr && eq_value(p) == chr) {
                    tex_delete_token_reference(eq_value(p));
                    return 1;
                } else {
                    return 0;
                }
            case internal_toks_cmd:
            case register_toks_cmd:
                /*tex Again we have references. */
                if (eq_value(p) == chr) {
             // if (eq_value(p) == chr && eq_level(p) == cur_level) {
                    return 1;
                } else {
                    return 0;
                }
            case integer_cmd:
            case index_cmd:
            case dimension_cmd:
            case posit_cmd:
                if (eq_type(p) == cmd && eq_value(p) == chr) {
             // if (eq_type(p) == cmd && eq_value(p) == chr && eq_level(p) == cur_level) {
                    return 1;
                } else { 
                    return 0;
                }
            default:
                /*tex
                    We can best also check the level because for integer defs etc we run into
                    issues otherwise (see testcase tests/luametatex/eqtest.tex based on MS's
                    math file).
                */
                if (eq_type(p) == cmd && eq_value(p) == chr) {
             // if (eq_type(p) == cmd && eq_value(p) == chr && eq_level(p) == cur_level) {
                    return 1;
                } else { 
                    return 0;
                }
        }
    } else {
        return 0;
    }
}

/*tex Used to define a not yet defined cs or box or ... */

void tex_eq_define(halfword p, singleword cmd, halfword chr)
{
    bool trace = tracing_assigns_par > 0;
    if (tex_aux_equal_eq(p, cmd, 0, chr)) {
        if (trace) {
            tex_aux_diagnostic_trace(p, "reassigning");
        }
    } else {
        if (trace) {
            tex_aux_diagnostic_trace(p, "changing");
        }
        if (eq_level(p) == cur_level) {
            tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        } else if (cur_level > level_one) {
            tex_aux_eq_save(p, eq_level(p));
        }
        set_eq_level(p, cur_level);
        set_eq_type(p, cmd);
        set_eq_flag(p, 0);
        set_eq_value(p, chr);
        if (trace) {
            tex_aux_diagnostic_trace(p, "into");
        }
    }
}

/*tex

    The counterpart of |eq_define| for the remaining (fullword) positions in |eqtb| is called
    |eq_word_define|. Since |xeq_level[p] >= level_one| for all |p|, a |restore_zero| will never
    be used in this case.

*/

void tex_eq_word_define(halfword p, int w) /* not used */
{
    bool trace = tracing_assigns_par > 0;
    if (eq_value(p) == w) {
        if (trace) {
            tex_aux_diagnostic_trace(p, "reassigning");
        }
    } else {
        if (trace) {
            tex_aux_diagnostic_trace(p, "changing");
        }
        if (eq_level(p) != cur_level) {
            tex_aux_eq_save(p, eq_level(p));
            set_eq_level(p, cur_level);
        }
        eq_value(p) = w;
        if (trace) {
            tex_aux_diagnostic_trace(p, "into");
        }
    }
}

/*tex

    The |eq_define| and |eq_word_define| routines take care of local definitions. Global definitions
    are done in almost the same way, but there is no need to save old values, and the new value is
    associated with |level_one|.

*/

void tex_geq_define(halfword p, singleword cmd, halfword chr) /* not used */
{
    bool trace = tracing_assigns_par > 0;
    if (trace) {
        tex_aux_diagnostic_trace(p, "globally changing");
    }
    tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
    set_eq_level(p, level_one);
    set_eq_type(p, cmd);
    set_eq_flag(p, 0);
    set_eq_value(p, chr);
    if (trace) {
        tex_aux_diagnostic_trace(p, "into");
    }
}

void tex_geq_word_define(halfword p, int w) /* not used */
{
    bool trace = tracing_assigns_par > 0;
    if (trace) {
        tex_aux_diagnostic_trace(p, "globally changing");
    }
    eq_value(p) = w;
    set_eq_level(p, level_one);
    if (trace) {
        tex_aux_diagnostic_trace(p, "into");
    }
}

/*tex
    Instead of a macro that distinguishes between global or not we now use a few normal functions.
    That way we don't need to define a bogus variable |a| in some cases. This is typically one of
    those changes that happened after other bits and pieces got redone. (One can also consider it
    a side effect of looking at the code through a visual studio lense.)
*/

inline static void tex_aux_set_eq_data(halfword p, singleword t, halfword e, singleword f, quarterword l)
{
    singleword flag = eq_flag(p);
    set_eq_level(p, l);
    set_eq_type(p, t);
    set_eq_value(p, e);
    if (is_mutable(f) || is_mutable(flag)) {
        set_eq_flag(p, (f | flag) & ~(noaligned_flag_bit | permanent_flag_bit | primitive_flag_bit | immutable_flag_bit));
    } else {
        set_eq_flag(p, f);
    }
}

void tex_define(int g, halfword p, singleword t, halfword e) /* int g -> singleword g */
{
    bool trace = tracing_assigns_par > 0;
    singleword f = make_eq_flag_bits(g);
    if (is_global(g)) {
        /* what if already global */
        if (trace) {
            tex_aux_diagnostic_trace(p, "globally changing");
        }
     // if (tex_aux_equal_eq(p, t, f, e) && (eq_level(p) == level_one)) {
     //     return; /* we can save some stack */
     // }
        tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        tex_aux_set_eq_data(p, t, e, f, level_one);
    } else if (! is_constrained(g) && tex_aux_equal_eq(p, t, f, e)) {
        /* hm, we tweak the ref ! */
        if (trace) {
            tex_aux_diagnostic_trace(p, "reassigning");
            return;
        }
    } else {
        if (trace) {
            tex_aux_diagnostic_trace(p, "changing");
        }
        if (eq_level(p) == cur_level) {
            tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        } else if (is_retained(g)) {
            /* nothing */
        } else if (cur_level > level_one) {
            tex_aux_eq_save(p, eq_level(p));
        }
        tex_aux_set_eq_data(p, t, e, f, cur_level);
    }
    if (trace) {
        tex_aux_diagnostic_trace(p, "into");
    }
}

/*tex 
    Used in |\dimendef| but also |\dimensiondef| and alike. Before it gets called we already 
    redefined to |\relax| so we might have saved. 
*/

void tex_define_again(int g, halfword p, singleword t, halfword e) /* int g -> singleword g */
{
    if (tracing_assigns_par > 0) { 
        singleword f = make_eq_flag_bits(g);
        if (is_global(g)) {
            /* what if already global */
            tex_aux_diagnostic_trace(p, "globally changing");
         // if (tex_aux_equal_eq(p, t, f, e) && (eq_level(p) == level_one)) {
         //     return; /* we can save some stack */
         // }
            tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
            tex_aux_set_eq_data(p, t, e, f, level_one);
        } else if (! is_constrained(g) && tex_aux_equal_eq(p, t, f, e)) {
            /* hm, we tweak the ref ! */
            tex_aux_diagnostic_trace(p, "reassigning");
        } else {
            tex_aux_diagnostic_trace(p, is_retained(g) ? "retained changing": "changing");
            if (eq_level(p) == cur_level) {
                tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
            } else if (is_retained(g)) { 
                /* nothing */
            } else if (cur_level > level_one) {
                tex_aux_eq_save(p, eq_level(p));
            }
            tex_aux_set_eq_data(p, t, e, f, cur_level);
        }
        tex_aux_diagnostic_trace(p, "into");
    } else { 
        set_eq_type(p, t);
        set_eq_value(p, e);    
    }
}

/*tex
    The next one is used when we let something. 
*/

void tex_define_inherit(int g, halfword p, singleword f, singleword t, halfword e)
{
    bool trace = tracing_assigns_par > 0;
    if (is_global(g)) {
        /* what if already global */
        if (trace) {
            tex_aux_diagnostic_trace(p, "globally changing");
        }
     // if (equal_eq(p, t, f, e) && (eq_level(p) == level_one)) {
     //    return; /* we can save some stack */
     // }
        tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        tex_aux_set_eq_data(p, t, e, f, level_one);
    } else if (! is_constrained(g) && tex_aux_equal_eq(p, t, f, e)) {
        if (trace) {
            tex_aux_diagnostic_trace(p, "reassigning");
            return;
        }
    } else {
        if (trace) {
            tex_aux_diagnostic_trace(p, is_retained(g) ? "retained changing" : "changing");
        }
        if (eq_level(p) == cur_level) {
            tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        } else if (is_retained(g)) {
            /* nothing */
        } else if (cur_level > level_one) {
            tex_aux_eq_save(p, eq_level(p));
        }
        tex_aux_set_eq_data(p, t, e, f, cur_level);
    }
    if (trace) {
        tex_aux_diagnostic_trace(p, "into");
    }
}

/*tex
    Used in swapping but beware: when we swap a global vsize with a local ... we can get side 
    effect. No retain here. 
*/

static void tex_aux_just_define(int g, halfword p, halfword e)
{
    bool trace = tracing_assigns_par > 0;
    if (is_global(g)) {
        if (trace) {
            tex_aux_diagnostic_trace(p, "globally changing");
        }
        tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
    } else {
        if (trace) {
            tex_aux_diagnostic_trace(p, "changing");
        }
        if (eq_level(p) == cur_level) {
            tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        } else if (cur_level > level_one) {
            tex_aux_eq_save(p, eq_level(p));
        }
        set_eq_level(p, cur_level);
    }
    set_eq_value(p, e);
    if (trace) {
        tex_aux_diagnostic_trace(p, "into");
    }
}

/* We can have a variant that doesn't save/restore so we just have to swap back then. */

void tex_define_swapped(int g, halfword p1, halfword p2, int force)
{
    halfword t1 = eq_type(p1);
    halfword t2 = eq_type(p2);
    halfword l1 = eq_level(p1);
    halfword l2 = eq_level(p2);
    singleword f1 = eq_flag(p1);
    singleword f2 = eq_flag(p2);
    halfword v1 = eq_value(p1);
    halfword v2 = eq_value(p2);
    if (t1 == t2 && l1 == l2) {
        halfword overload = force ? 0 : overload_mode_par;
        if (overload) {
           if (f1 != f2) {
               goto NOTDONE;
           } else if (is_immutable(f1)) {
               goto NOTDONE;
           }
        }
        if (v1 == v2)  {
            return; 
        } else {
            switch (t1) {
                case register_posit_cmd:
                case register_integer_cmd:
                case register_attribute_cmd:
                case register_dimension_cmd:
                case register_glue_cmd:   /* unchecked */
                case register_muglue_cmd: /* unchecked */
                case internal_muglue_cmd: /* unchecked */
                case integer_cmd:
                case index_cmd:
                case dimension_cmd:
                case posit_cmd:
                    tex_aux_just_define(g, p1, v2);
                    tex_aux_just_define(g, p2, v1);
                    return;
                case register_toks_cmd:
                case internal_toks_cmd:
                    if (v1) tex_add_token_reference(v1);
                    if (v2) tex_add_token_reference(v2);
                    tex_aux_just_define(g, p1, v2);
                    tex_aux_just_define(g, p2, v1);
                    if (v1) tex_delete_token_reference(v1);
                    if (v2) tex_delete_token_reference(v2);
                    return;
                case internal_integer_cmd:
                    tex_assign_internal_integer_value(g, p1, v2);
                    tex_assign_internal_integer_value(g, p2, v1);
                    return;
                case internal_attribute_cmd:
                    tex_assign_internal_attribute_value(g, p1, v2);
                    tex_assign_internal_attribute_value(g, p2, v1);
                    return;
                case internal_posit_cmd:
                    tex_assign_internal_posit_value(g, p1, v2);
                    tex_assign_internal_posit_value(g, p2, v1);
                    return;
                case internal_dimension_cmd:
                    tex_assign_internal_dimension_value(g, p1, v2);
                    tex_assign_internal_dimension_value(g, p2, v1);
                    return;
                case internal_glue_cmd:
                    /* todo */
                    tex_assign_internal_skip_value(g, p1, v2);
                    tex_assign_internal_skip_value(g, p2, v1);
                    return;
                default:
                    if (overload > 2) {
                        if (has_flag_bits(f1, immutable_flag_bit | permanent_flag_bit | primitive_flag_bit)) {
                            if (overload > 3) {
                                goto NOTDONE;
                            }
                        }
                    }
                    if (is_call_cmd(t1)) {
                        if (v1) tex_add_token_reference(v1);
                        if (v2) tex_add_token_reference(v2);
                        tex_aux_just_define(g, p1, v2);
                        tex_aux_just_define(g, p2, v1);
                        /* no delete here .. hm */
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "\\swapcsvalues not (yet) implemented for commands (%C, %C)",
                            t1, v1, t2, v2, NULL
                        );

                    }
                    return;
            }
        }
    }
  NOTDONE:
    tex_handle_error(
        normal_error_type,
        "\\swapcsvalues requires equal commands (%C, %C), levels (%i, %i) and flags (%i, %i)",
        t1, v1, t2, v2, l1, l2, f1, f2, NULL
    );
}

/*tex 
    Used in pushing and popping. No retain here. 
*/

void tex_forced_define(int g, halfword p, singleword f, singleword t, halfword e)
{
    bool trace = tracing_assigns_par > 0;
    if (is_global(g)) {
        if (trace) {
            tex_aux_diagnostic_trace(p, "globally changing");
        }
        tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        set_eq_level(p, level_one);
    } else {
        if (trace) {
            tex_aux_diagnostic_trace(p, "changing");
        }
        if (eq_level(p) == cur_level) {
            tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
        } else if (cur_level > level_one) {
            tex_aux_eq_save(p, eq_level(p));
        }
        set_eq_level(p, cur_level);
    }
    set_eq_type(p, t);
    set_eq_flag(p, f);
    set_eq_value(p, e);
    if (trace) {
        tex_aux_diagnostic_trace(p, "into");
    }
}

/*tex 
    Registers and other values that are stored directly without reference.
*/

void tex_word_define(int g, halfword p, halfword w)
{
    if (tex_aux_mutation_permitted(p)) {
        bool trace = tracing_assigns_par > 0;
        if (is_global(g)) {
            if (trace) {
                tex_aux_diagnostic_trace(p, "globally changing");
            }
            eq_value(p) = w;
            set_eq_level(p, level_one);
        } else if (! is_constrained(g) && eq_value(p) == w) {
            if (trace) {
                tex_aux_diagnostic_trace(p, "reassigning");
                return;
            }
        } else if (is_retained(g)) {
            if (trace) {
                tex_aux_diagnostic_trace(p, "retained changing");
                set_eq_level(p, cur_level);
            }
            eq_value(p) = w;
        } else {
            if (trace) {
                tex_aux_diagnostic_trace(p, "changing");
            }
            if (eq_level(p) != cur_level) {
                tex_aux_eq_save(p, eq_level(p));
                set_eq_level(p, cur_level);
            }
            eq_value(p) = w;
        }
        if (trace) {
            tex_aux_diagnostic_trace(p, "into");
        }
        if (is_immutable(g)) {
            eq_flag(p) |= immutable_flag_bit;
        } else if (is_mutable(g)) {
            eq_flag(p) |= mutable_flag_bit;
        }
    }
}

/*
void tex_forced_word_define(int g, halfword p, singleword f, halfword w)
{
    if (tex_aux_mutation_permitted(p)) {
        bool trace = tracing_assigns_par > 0;
        if (is_global(g)) {
            if (trace) {
                tex_aux_diagnostic_trace(p, "globally changing");
            }
            eq_value(p) = w;
            set_eq_level(p, level_one);
        } else if (eq_value(p) == w) {
            if (trace) {
                tex_aux_diagnostic_trace(p, "reassigning");
                return;
            }
        } else if (is_retained(g)) {
            if (trace) {
                tex_aux_diagnostic_trace(p, "retained changing");
            }
            eq_value(p) = w;
        } else {
            if (trace) {
                tex_aux_diagnostic_trace(p, "changing");
            }
            if (eq_level(p) != cur_level) {
                tex_aux_eq_save(p, eq_level(p));
                set_eq_level(p, cur_level);
            }
            eq_value(p) = w;
        }
        if (trace) {
            tex_aux_diagnostic_trace(p, "into");
        }
        eq_flag(p) = f;
    }
}
*/

/*tex

    Subroutine |save_for_after_group| puts a token on the stack for save-keeping.

*/

void tex_save_for_after_group(halfword t)
{
    if (t && cur_level > level_one && tex_room_on_save_stack()) {
        save_type(lmt_save_state.save_stack_data.ptr) = insert_tokens_save_type;
        save_level(lmt_save_state.save_stack_data.ptr) = level_zero;
        save_value(lmt_save_state.save_stack_data.ptr) = t;
        ++lmt_save_state.save_stack_data.ptr;
    }
}

/*tex

    The |unsave| routine goes the other way, taking items off of |save_stack|. This routine takes
    care of restoration when a level ends. Here, everything belonging to the topmost group is
    cleared off of the save stack.

    In \TEX\ there are a few |\after...| commands, like |\aftergroup| and |\afterassignment| while
    |\futurelet| also has this property of postponed actions. The |\every...| token registers do
    the opposite and do stuff up front. In addition to |\aftergrouped| we have a variant that
    accepts a token list, as does |\afterassigned|. These items are saved on the stack.

    In \LUAMETATEX\ we can also do things just before a group ends as well as just before the
    paragraph finishes. In the end it was not that hard to implement in the \LUATEX\ concept,
    although it adds a little overhead, but the benefits compensate that. Because we can use some
    mechanisms used in other extensions only a few extra lines are needed. All are accumulative
    but the paragraph bound one is special in the sense that is is bound to the current paragraph,
    so the actual implementation of that one happens elsewhere and differently.

    Side note: when |\par| overloading was introduced in \PDFTEX\ and per request also added to
    |\LUATEX| it made no sense to add that to \LUAMETATEX\ too. We already have callbacks, and
    there is information available about what triggered a |\par|. Another argument against
    supporting this is that overloading |\par| is messy and unreliable (macro package and user
    demand and actions can badly interfere). The mentioned hooks already give more than enough
    opportunities. One doesn't expect users to overload |\relax| either.

    Side note: at some point I will look into |\after| hooks in for instance alignments and maybe
    something nicer that |\afterassignment| can be used for pushing stuff into boxes (|\everybox|
    is not that helpful). But again avoiding extra overhead might is a very good be a reason to
    not do that at all.

*/

void tex_unsave(void)
{
    if (end_of_group_par) {
        /*tex 
            This is not yet always ok, and looks like we can get weird commands (in some group 
            ending situations)! But I need a better example of a failure. (low priority) 
        */
        tex_begin_inserted_list(tex_get_available_token(token_val(end_local_cmd, 0)));
        tex_begin_token_list(end_of_group_par, end_of_group_text);
        if (tracing_nesting_par > 2) {
            tex_local_control_message("entering token scanner via endgroup");
        }
        tex_local_control(1);
// tex_cleanup_input_state();
    }
    delete_attribute_reference(current_attribute_state); 
    tex_unsave_math_codes(cur_level);
    tex_unsave_cat_codes(cat_code_table_par, cur_level);
    tex_unsave_text_codes(cur_level);
    tex_unsave_math_data(cur_level);
    if (cur_level > level_one) {
        /*tex
            Variable |a| registers if we already have processed an |\aftergroup|. We append when
            >= 1.
        */
        bool append = false;
        bool trace = tracing_restores_par > 0;
        --cur_level;
        /*tex Clear off top level from |save_stack|. */
        while (1) {
            --lmt_save_state.save_stack_data.ptr;
            switch (save_type(lmt_save_state.save_stack_data.ptr)) {
                case level_boundary_save_type:
                    goto DONE;
                case restore_old_value_save_type:
                    {
                        halfword p = save_value(lmt_save_state.save_stack_data.ptr);
                        /*tex
                            Store |save_stack[save_ptr]| in |eqtb[p]|, unless |eqtb[p]| holds a global
                            value A global definition, which sets the level to |level_one|, will not be
                            undone by |unsave|. If at least one global definition of |eqtb[p]| has been
                            carried out within the group that just ended, the last such definition will
                            therefore survive.
                        */
                     // if (p < internal_integer_base || p > eqtb_size) {
                        if (p < internal_integer_base || p >= internal_specification_base) {
                            if (eq_level(p) == level_one) {
                                tex_aux_eq_destroy(save_word(lmt_save_state.save_stack_data.ptr));
                                if (trace) {
                                    tex_aux_diagnostic_trace(p, "retaining");
                                }
                            } else {
                                tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
                                lmt_hash_state.eqtb[p] = save_word(lmt_save_state.save_stack_data.ptr);
                                if (trace) {
                                    tex_aux_diagnostic_trace(p, "restoring");
                                }
                            }
                        } else if (eq_level(p) == level_one) {
                            if (trace) {
                                tex_aux_diagnostic_trace(p, "retaining");
                            }
                        } else {
                            lmt_hash_state.eqtb[p] = save_word(lmt_save_state.save_stack_data.ptr);
                            if (trace) {
                                tex_aux_diagnostic_trace(p, "restoring");
                            }
                        }
                        break;
                    }
                case insert_tokens_save_type:
                    {
                        /*tex A list starts a new input level (for now). */
                        halfword p = save_value(lmt_save_state.save_stack_data.ptr);
                        if (append) {
                            /*tex We stay at the same input level (an \ETEX\ feature). */
                            tex_append_input(p);
                        } else {
                            tex_insert_input(p);
                            append = true;
                        }
                        break;
                    }
                case restore_lua_save_type:
                    {
                        /* The same as lua_function_code in |textoken.c|. */
                        halfword p = save_value(lmt_save_state.save_stack_data.ptr);
                        if (p > 0) {
                            strnumber u = tex_save_cur_string();
                            lmt_token_state.luacstrings = 0;
                            lmt_function_call(p, 0);
                            tex_restore_cur_string(u);
                            if (lmt_token_state.luacstrings > 0) {
                                tex_lua_string_start();
                            }
                        } else {
                            tex_normal_error("lua restore", "invalid number");
                        }
                        append = true;
                        break;
                    }
                case restore_zero_save_type:
                    {
                        halfword p = save_value(lmt_save_state.save_stack_data.ptr);
                        if (eq_level(p) == level_one) {
                            if (trace) {
                                tex_aux_diagnostic_trace(p, "retaining");
                            }
                        } else {
                            if (p < internal_integer_base || p > eqtb_size) {
                                tex_aux_eq_destroy(lmt_hash_state.eqtb[p]);
                            }
                            lmt_hash_state.eqtb[p] = lmt_hash_state.eqtb[undefined_control_sequence];
                            if (trace) {
                                tex_aux_diagnostic_trace(p, "restoring");
                            }
                        }
                        break;
                    }
                default:
                    /* we have a messed up save pointer */
                    tex_formatted_error("tex unsave", "bad save type case %d, probably a stack pointer issue", save_type(lmt_save_state.save_stack_data.ptr));
                    break;
            }
        }
      DONE:
        if (tracing_groups_par > 0) {
            tex_aux_group_trace(1);
        }
        if (lmt_input_state.in_stack[lmt_input_state.in_stack_data.ptr].group == cur_boundary) {
            /*tex Groups are possibly not properly nested with files. */
            tex_aux_group_warning();
        }
        cur_group = saved_group_group;
        cur_boundary = saved_group_boundary;
        set_current_attribute_state(saved_group_attribute_state); 
    } else {
        /*tex |unsave| is not used when |cur_group=bottom_level| */
        tex_confusion("current level");
    }
}

/*tex

    Most of the parameters kept in |eqtb| can be changed freely, but there's an exception: The
    magnification should not be used with two different values during any \TEX\ job, since a
    single magnification is applied to an entire run. The global variable |mag_set| is set to the
    current magnification whenever it becomes necessary to \quote {freeze} it at a particular value.

    The |prepare_mag| subroutine is called whenever \TEX\ wants to use |mag| for magnification. If
    nonzero, this magnification should be used henceforth. We might drop magnifaction at some point.

    {\em NB: As we delegate the backend to \LUA\ we have no mag.}

    Let's pause a moment now and try to look at the Big Picture. The \TEX\ program consists of three
    main parts: syntactic routines, semantic routines, and output routines. The chief purpose of the
    syntactic routines is to deliver the user's input to the semantic routines, one token at a time.
    The semantic routines act as an interpreter responding to these tokens, which may be regarded as
    commands. And the output routines are periodically called on to convert box-and-glue lists into a
    compact set of instructions that will be sent to a typesetter. We have discussed the basic data
    structures and utility routines of \TEX, so we are good and ready to plunge into the real activity
    by considering the syntactic routines.

    Our current goal is to come to grips with the |get_next| procedure, which is the keystone of
    \TEX's input mechanism. Each call of |get_next| sets the value of three variables |cur_cmd|,
    |cur_chr|, and |cur_cs|, representing the next input token.

    \startitemize
        \startitem
            |cur_cmd| denotes a command code from the long list of codes given above;
        \stopitem
        \startitem
            |cur_chr| denotes a character code or other modifier of the command code;
        \stopitem
        \startitem
            |cur_cs| is the |eqtb| location of the current control sequence, if the current token
            was a control sequence, otherwise it's zero.
        \stopitem
    \stopitemize

    Underlying this external behavior of |get_next| is all the machinery necessary to convert from
    character files to tokens. At a given time we may be only partially finished with the reading of
    several files (for which |\input| was specified), and partially finished with the expansion of
    some user-defined macros and/or some macro parameters, and partially finished with the generation
    of some text in a template for |\halign|, and so on. When reading a character file, special
    characters must be classified as math delimiters, etc.; comments and extra blank spaces must be
    removed, paragraphs must be recognized, and control sequences must be found in the hash table.
    Furthermore there are occasions in which the scanning routines have looked ahead for a word like
    |plus| but only part of that word was found, hence a few characters must be put back into the input
    and scanned again.

    To handle these situations, which might all be present simultaneously, \TEX\ uses various stacks
    that hold information about the incomplete activities, and there is a finite state control for each
    level of the input mechanism. These stacks record the current state of an implicitly recursive
    process, but the |get_next| procedure is not recursive. Therefore it will not be difficult to
    translate these algorithms into low-level languages that do not support recursion.

    In general, |cur_cmd| is the current command as set by |get_next|, while |cur_chr| is the operand
    of the current command. The control sequence found here is registsred in |cur_cs| and is zero if
    none found. The |cur_tok| variable contains the packed representative of |cur_cmd| and |cur_chr|
    and like the other ones is global.

    Here is a procedure that displays the current command. The variable |n| holds the level of |\if ...
    \fi| nesting and |l| the line where |\if| started.

*/

void tex_show_cmd_chr(halfword cmd, halfword chr)
{
    tex_begin_diagnostic();
    if (cur_list.mode != lmt_nest_state.shown_mode) {
        if (tracing_commands_par >= 4) {
            /*tex So, larger than \ETEX's extra info 3 value. We might just always do this. */
            tex_print_format("[mode: entering %M]", cur_list.mode);
            tex_print_nlp();
            tex_print_levels();
            tex_print_str("{");
        } else {
            tex_print_format("{%M: ", cur_list.mode);
        }
        lmt_nest_state.shown_mode = cur_list.mode;
    } else {
        tex_print_str("{");
    }
    tex_print_cmd_chr((singleword) cmd, chr);
    if (cmd == if_test_cmd && tracing_ifs_par > 0) {
        halfword p;
        int n, l;
        if (tracing_commands_par >= 4) {
            tex_print_str(": ");
        } else {
            tex_print_char(' ');
        }
        if (cur_chr >= first_real_if_test_code || cur_chr == or_else_code || cur_chr == or_unless_code) { /* can be other >= test */
            n = 1;
            l = lmt_input_state.input_line;
        } else {
            tex_print_cmd_chr(if_test_cmd, lmt_condition_state.cur_if);
            tex_print_char(' ');
            n = 0;
            l = lmt_condition_state.if_line;
        }
        /*tex
            We now also have a proper counter but this is a check for a potential mess up. If
            als is right, |lmt_condition_state.if_nesting| often should match |n|.
        */
        p = lmt_condition_state.cond_ptr;
        while (p) {
            ++n;
            p = node_next(p);
        }
        if (l) {
            if (tracing_commands_par >= 4) {
                tex_print_format("(level %i, line %i, nesting %i)", n, l, lmt_condition_state.if_nesting);
            } else {
             // tex_print_format("(level %i) entered on line %i", n, l);
                tex_print_format("(level %i, line %i)", n, l);
            }
        } else {
            tex_print_format("(level %i)", n);
        }
    }
    tex_print_char('}');
    tex_end_diagnostic();
}

/*tex

    Here is a procedure that displays the contents of |eqtb[n]| symbolically.

    We're now at equivalent |n| in region 4. First we initialize most things to null or undefined
    values. An undefined font is represented by the internal code |font_base|.

    However, the character code tables are given initial values based on the conventional
    interpretation of \ASCII\ code. These initial values should not be changed when \TEX\ is
    adapted for use with non-English languages; all changes to the initialization conventions
    should be made in format packages, not in \TEX\ itself, so that global interchange of formats
    is possible.

    The reorganization was done because I wanted a cleaner token interface at the \LUA\ end. So
    we also do some more checking. The order differs from traditional \TEX\ but of course the
    approach is similar.

    The regions in \LUAMETATEX\ are a bit adapted as a side effect of the \ETEX\ extensions as
    well as our own. For instance, we tag all regions because we also need a consistent token
    interface to \LUA. We also dropped fonts and some more from the table.

    A previous, efficient, still range based variant can be found in the my archive but it makes
    no sense to keep it commented here (apart from sentimental reasons) so one now only can see 
    the range agnostic version here.

*/

void tex_aux_show_eqtb(halfword n)
{
    if (n < null_cs) {
        tex_print_format("bad token %i, case 1", n);
    } else if (eqtb_indirect_range(n)) {
        tex_print_cs(n);
        tex_print_char('=');
        tex_print_cmd_chr(eq_type(n), eq_value(n));
        if (eq_type(n) >= call_cmd) {
            tex_print_char(':');
            tex_token_show(eq_value(n));
        }
    } else {
        switch (eq_type(n)) {
            case internal_toks_reference_cmd:
                tex_print_cmd_chr(internal_toks_cmd, n);
                goto TOKS;
            case register_toks_reference_cmd:
                tex_print_str_esc("toks");
                tex_print_int(register_toks_number(n));
              TOKS:
                tex_print_char('=');
                tex_token_show(eq_value(n));
                break;
            case internal_box_reference_cmd:
                tex_print_cmd_chr(eq_type(n), n);
                goto BOX;
            case register_box_reference_cmd:
                tex_print_str_esc("box");
                tex_print_int(register_box_number(n));
              BOX:
                tex_print_char('=');
                if (eq_value(n)) {
                    tex_show_node_list(eq_value(n), 0, 1);
                    tex_print_levels();
                } else {
                    tex_print_str("void");
                }
                break;
            case internal_glue_reference_cmd:
                tex_print_cmd_chr(internal_glue_cmd, n);
                goto SKIP;
            case register_glue_reference_cmd:
                tex_print_str_esc("skip");
                tex_print_int(register_glue_number(n));
              SKIP:
                tex_print_char('=');
                if (tracing_nodes_par > 2) {
                    tex_print_format("<%i>", eq_value(n));
                }
                tex_print_spec(eq_value(n), pt_unit);
                break;
            case internal_muglue_reference_cmd:
                tex_print_cmd_chr(internal_muglue_cmd, n);
                goto MUSKIP;
            case register_muglue_reference_cmd:
                tex_print_str_esc("muskip");
                tex_print_int(register_muglue_number(n));
              MUSKIP:
                if (tracing_nodes_par > 2) {
                    tex_print_format("<%i>", eq_value(n));
                }
                tex_print_char('=');
                tex_print_spec(eq_value(n), mu_unit);
                break;
            case internal_integer_reference_cmd:
                tex_print_cmd_chr(internal_integer_cmd, n);
                goto COUNT;
            case register_integer_reference_cmd:
                tex_print_str_esc("count");
                tex_print_int(register_integer_number(n));
              COUNT:
                tex_print_char('=');
                tex_print_int(eq_value(n));
                break;
            case internal_attribute_reference_cmd:
                tex_print_cmd_chr(internal_attribute_cmd, n);
                goto ATTRIBUTE;
            case register_attribute_reference_cmd:
                tex_print_str_esc("attribute");
                tex_print_int(register_attribute_number(n));
              ATTRIBUTE:
                tex_print_char('=');
                tex_print_int(eq_value(n));
                break;
            case internal_posit_reference_cmd:
                tex_print_cmd_chr(internal_posit_cmd, n);
                goto POSIT;
            case register_posit_reference_cmd:
                tex_print_str_esc("posit");
                tex_print_int(register_posit_number(n));
              POSIT:
                tex_print_char('=');
                tex_print_posit(eq_value(n));
                break;
            case internal_dimension_reference_cmd:
                tex_print_cmd_chr(internal_dimension_cmd, n);
                goto DIMEN;
            case register_dimension_reference_cmd:
                tex_print_str_esc("dimen");
                tex_print_int(register_dimension_number(n));
              DIMEN:
                tex_print_char('=');
                tex_print_dimension(eq_value(n), pt_unit);
                break;
            case specification_reference_cmd:
                tex_print_cmd_chr(specification_cmd, n);
                tex_print_char('=');
                if (eq_value(n)) {
                 // if (tracing_nodes_par > 2) {
                 //     tex_print_format("<%i>", eq_value(n));
                 // }
                    tex_print_int(specification_count(eq_value(n)));
                } else {
                    tex_print_char('0');
                }
                break;
            case unit_reference_cmd:
                tex_print_cmd_chr(association_cmd, n);
                tex_print_char('=');
                if (eq_value(n)) {
                    tex_print_str("todo");
                } else {
                    tex_print_char('0');
                }
                break;
            default:
                tex_print_format("bad token %i, case 2", n);
                break;
        }
    }
}

/*tex

    A couple of (self documenting) convenient helpers. They do what we do in \LUATEX, but we now
    have collapsed all the options in one mode parameter that also gets stored in the glyph so
    the older functions are gone. Progress.

*/

halfword tex_automatic_disc_penalty(halfword mode)
{
    return hyphenation_permitted(mode, automatic_penalty_hyphenation_mode) ? automatic_hyphen_penalty_par : ex_hyphen_penalty_par;
}

halfword tex_explicit_disc_penalty(halfword mode)
{
    return hyphenation_permitted(mode, explicit_penalty_hyphenation_mode) ? explicit_hyphen_penalty_par : ex_hyphen_penalty_par;
}

/*tex

    The table of equivalents needs to get (pre)populated by the right commands and references, so
    that happens here (called in maincontrol at ini time).

    For diagnostic purposes we now have the type set for registers. As a consequence we not have
    four |glue_ref| variants, which is a trivial extension.

*/

inline static void tex_aux_set_eq(halfword base, quarterword level, singleword cmd, halfword value, halfword count)
{
    if (count > 0) {
        set_eq_level(base, level);
        set_eq_type(base, cmd);
        set_eq_flag(base, 0);
        set_eq_value(base, value);
        for (int k = base + 1; k <= base + count; k++){
            copy_eqtb_entry(k, base);
        }
    }
}

void tex_synchronize_equivalents(void)
{
    tex_aux_set_eq(null_cs, level_zero, undefined_cs_cmd, null, lmt_hash_state.hash_data.top - 1);
}

void tex_initialize_equivalents(void)
{
    /*tex Order matters here! */
    tex_aux_set_eq(null_cs,                     level_zero, undefined_cs_cmd,                 null,                   lmt_hash_state.hash_data.top - 1);
    tex_aux_set_eq(internal_glue_base,          level_one,  internal_glue_reference_cmd,      zero_glue,              number_glue_pars);
    tex_aux_set_eq(register_glue_base,          level_one,  register_glue_reference_cmd,      zero_glue,              max_glue_register_index);
    tex_aux_set_eq(internal_muglue_base,        level_one,  internal_muglue_reference_cmd,    zero_glue,              number_muglue_pars);
    tex_aux_set_eq(register_muglue_base,        level_one,  register_muglue_reference_cmd,    zero_glue,              max_muglue_register_index);
    tex_aux_set_eq(internal_toks_base,          level_one,  internal_toks_reference_cmd,      null,                   number_tok_pars);
    tex_aux_set_eq(register_toks_base,          level_one,  register_toks_reference_cmd,      null,                   max_toks_register_index);
    tex_aux_set_eq(internal_box_base,           level_one,  internal_box_reference_cmd,       null,                   number_box_pars);
    tex_aux_set_eq(register_box_base,           level_one,  register_box_reference_cmd,       null,                   max_box_register_index);
    tex_aux_set_eq(internal_integer_base,       level_one,  internal_integer_reference_cmd,   0,                      number_integer_pars);
    tex_aux_set_eq(register_integer_base,       level_one,  register_integer_reference_cmd,   0,                      max_integer_register_index);
    tex_aux_set_eq(internal_attribute_base,     level_one,  internal_attribute_reference_cmd, unused_attribute_value, number_attribute_pars);
    tex_aux_set_eq(register_attribute_base,     level_one,  register_attribute_reference_cmd, unused_attribute_value, max_attribute_register_index);
    tex_aux_set_eq(internal_posit_base,         level_one,  internal_posit_reference_cmd,     0,                      number_posit_pars);
    tex_aux_set_eq(register_posit_base,         level_one,  register_posit_reference_cmd,     0,                      max_posit_register_index);
    tex_aux_set_eq(internal_dimension_base,     level_one,  internal_dimension_reference_cmd, 0,                      number_dimension_pars);
    tex_aux_set_eq(register_dimension_base,     level_one,  register_dimension_reference_cmd, 0,                      max_dimension_register_index);
    tex_aux_set_eq(internal_specification_base, level_one,  specification_reference_cmd,      null,                   number_specification_pars);
    tex_aux_set_eq(internal_unit_base,          level_one,  unit_reference_cmd,               unset_unit_class,       max_unit_register_index);
    tex_aux_set_eq(undefined_control_sequence,  level_zero, undefined_cs_cmd,                 null,                   0);
    /*tex why here? */
    cat_code_table_par = 0;
}

void tex_initialize_destructors(void)
{
    lmt_hash_state.destructors[call_cmd]                         = eq_token_list;                   
    lmt_hash_state.destructors[protected_call_cmd]               = eq_token_list;
    lmt_hash_state.destructors[semi_protected_call_cmd]          = eq_token_list;
    lmt_hash_state.destructors[constant_call_cmd]                = eq_token_list;
    lmt_hash_state.destructors[tolerant_call_cmd]                = eq_token_list;
    lmt_hash_state.destructors[tolerant_protected_call_cmd]      = eq_token_list;
    lmt_hash_state.destructors[tolerant_semi_protected_call_cmd] = eq_token_list;
    lmt_hash_state.destructors[register_toks_reference_cmd]      = eq_token_list;
    lmt_hash_state.destructors[internal_toks_reference_cmd]      = eq_token_list;
    lmt_hash_state.destructors[internal_glue_reference_cmd]      = eq_node; 
    lmt_hash_state.destructors[register_glue_reference_cmd]      = eq_node;
    lmt_hash_state.destructors[internal_muglue_reference_cmd]    = eq_node;
    lmt_hash_state.destructors[register_muglue_reference_cmd]    = eq_node;
    lmt_hash_state.destructors[gluespec_cmd]                     = eq_node;
    lmt_hash_state.destructors[mugluespec_cmd]                   = eq_node;
    lmt_hash_state.destructors[mathspec_cmd]                     = eq_node;
    lmt_hash_state.destructors[fontspec_cmd]                     = eq_node;
    lmt_hash_state.destructors[specificationspec_cmd]            = eq_node;
    lmt_hash_state.destructors[specification_reference_cmd]      = eq_node;
    lmt_hash_state.destructors[internal_box_reference_cmd]       = eq_node_list; 
    lmt_hash_state.destructors[register_box_reference_cmd]       = eq_node_list; 
}

int tex_located_save_value(int id)
{
    int i = lmt_save_state.save_stack_data.ptr - 1;
    while (save_type(i) != level_boundary_save_type) {
        i--;
    }
    while (i < lmt_save_state.save_stack_data.ptr) {
        if (save_type(i) == restore_old_value_save_type && save_value(i) == id) {
            /*
            if (math_direction_par != save_value(i - 1)) {
                return 1;
            }
            */
            return save_value(i - 1);
        }
        i++;
    }
    return 0;
}

extern int tex_cs_state(halfword p) 
{
    if (p == null_cs) {
        return cs_null_error;
    } else if (p < hash_base) {
        return cs_below_base_error;
    } else if (p == undefined_control_sequence) {
        return cs_undefined_error;
    } else if (eqtb_out_of_range(p)) {
        return cs_out_of_range_error;
    } else {
        return cs_no_error;
    }
}
