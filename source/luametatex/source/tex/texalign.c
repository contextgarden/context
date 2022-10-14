/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    It's sort of a miracle whenever |halign and |valign| work, because they cut across so many of
    the control structures of \TEX. Therefore the present page is probably not the best place for
    a beginner to start reading this program; it is better to master everything else first.

    Let us focus our thoughts on an example of what the input might be, in order to get some idea
    about how the alignment miracle happens. The example doesn't do anything useful, but it is
    sufficiently general to indicate all of the special cases that must be dealt with; please do
    not be disturbed by its apparent complexity and meaninglessness.

    \starttyping
    \tabskip 2pt plus 3pt
    \halign to 300pt{u1#v1&
    \hskip 50pt \tabskip 1pt plus 1fil u2#v2&
    \hskip 50pt u3#v3\cr
    \hskip 25pt a1&\omit a2&\vrule\cr
    \hskip 25pt \noalign\{\vskip 3pt}
    \hskip 25pt b1\span b2\cr
    \hskip 25pt \omit&c2\span\omit\cr}
    \stoptyping

    Here's what happens:

    \startitemize

        \startitem
            When |\halign to 300pt {}| is scanned, the |scan_align_spec| routine places the 300pt
            dimension onto the |save_stack|, and an |align_group| code is placed above it. This
            will make it possible to complete the alignment when the matching right brace is found.
        \stopitem

        \startitem
            The preamble is scanned next. Macros in the preamble are not expanded, except as part
            of a tabskip specification. For example, if |u2| had been a macro in the preamble above,
            it would have been expanded, since \TEX\ must look for |minus ...| as part of the
            tabskip glue. A preamble list is constructed based on the user's preamble; in our case
            it contains the following seven items:

            \starttabulate
            \NC \type{\glue 2pt plus 3pt}              \NC the tabskip preceding column 1      \NC \NR
            \NC \type{\alignrecord} of width $-\infty$ \NC preamble info for column 1          \NC \NR
            \NC \type{\glue 2pt plus 3pt}              \NC the tabskip between columns 1 and 2 \NC \NR
            \NC \type{\alignrecord} of width $-\infty$ \NC preamble info for column 2          \NC \NR
            \NC \type{\glue 1pt plus 1fil}             \NC the tabskip between columns 2 and 3 \NC \NR
            \NC \type{\alignrecord} of width $-\infty$ \NC preamble info for column 3          \NC \NR
            \NC \type{\glue 1pt plus 1fil}             \NC the tabskip following column 3      \NC \NR
            \stoptabulate

            These \quote {alignrecord} entries have the same size as an |unset_node|, since they
            will later be converted into such nodes. These alignrecord nodes have no |depth| field;
            this is split into |u_part| and |v_part|, and they point to token lists for the
            templates of the alignment. For example, the |u_part| field in the first alignrecord
            points to the token list |u1|, i.e., the template preceding the \type {#} for column~1.
            Furthermore, They have a |span_ptr| instead of a |node_attr| field, and these |span_ptr|
            fields are initially set to the value |end_span|, for reasons explained below.
        \stopitem

        \startitem
            \TEX\ now looks at what follows the |\cr| that ended the preamble. It is not |\noalign|
            or |\omit|, so this input is put back to be read again, and the template |u1| is fed to
            the scanner. Just before reading |u1|, \TeX\ goes into restricted horizontal mode. Just
            after reading |u1|, \TEX\ will see |a1|, and then (when the |&| is sensed) \TEX\ will
            see |v1|. Then \TEX\ scans an |end_template| token, indicating the end of a column. At
            this point an |unset_node| is created, containing the contents of the current hlist
            (i.e., |u1a1v1|). The natural width of this unset node replaces the |width| field of
            the alignrecord for column~1; in general, the alignrecords will record the maximum
            natural width that has occurred so far in a given column.
        \stopitem

        \startitem
            Since |\omit| follows the |&|, the templates for column~2 are now bypassed. Again \TEX\
            goes into restricted horizontal mode and makes an |unset_node| from the resulting hlist;
            but this time the hlist contains simply |a2|. The natural width of the new unset box is
            remembered in the |width| field of the alignrecord for column~2.
        \stopitem

        \startitem
            A third |unset_node| is created for column 3, using essentially the mechanism that
            worked for column~1; this unset box contains |u3\vrule v3|. The vertical rule in this
            case has running dimensions that will later extend to the height and depth of the whole
            first row, since each |unset_node| in a row will eventually inherit the height and depth
            of its enclosing box.
        \stopitem

        \startitem
            The first row has now ended; it is made into a single unset box comprising the following
            seven items:

            \starttyping
            \glue 2pt plus 3pt
            \unsetbox for 1 column: u1a1v1
            \glue 2pt plus 3pt
            \unsetbox for 1 column: a2
            \glue 1pt plus 1fil
            \unsetbox for 1 column: u3\vrule v3
            \glue 1pt plus 1fil
            \stoptyping

            The width of this unset row is unimportant, but it has the correct height and depth, so
            the correct baselineskip glue will be computed as the row is inserted into a vertical
            list.
        \stopitem

        \startitem
            Since |\noalign| follows the current |\cr|, \TEX\ appends additional material (in this
            case |\vskip 3pt|) to the vertical list. While processing this material, \TeX\ will be
            in internal vertical mode, and |no_align_group| will be on |save_stack|.
        \stopitem

        \startitem
            The next row produces an unset box that looks like this:

            \starttyping
            \glue 2pt plus 3pt
            \unsetbox for 2 columns: u1b1v1u2b2v2
            \glue 1pt plus 1fil
            \unsetbox for 1 column: {(empty)}
            \glue 1pt plus 1fil
            \stoptyping

            The natural width of the unset box that spans columns 1~and~2 is stored in a \quote
            {span node}, which we will explain later; the |span_ptr| field of the alignrecord for
            column~1 now points to the new span node, and the |span_ptr| of the span node points to
            |end_span|.
        \stopitem

        \startitem

            The final row produces the unset box

            \starttyping
            \glue 2pt plus 3pt
            \unsetbox for 1 column: (empty)
            \glue 2pt plus 3pt
            \unsetbox for 2 columns: u2c2v2
            \glue 1pt plus 1fil
            \stoptyping

            A new span node is attached to the align record for column 2.
        \stopitem

        \startitem
            The last step is to compute the true column widths and to change all the unset boxes to
            hboxes, appending the whole works to the vertical list that encloses the |\halign|. The
            rules for deciding on the final widths of each unset column box will be explained below.
        \stopitem

    \stopitemize

    Note that as |\halign| is being processed, we fearlessly give up control to the rest of \TEX. At
    critical junctures, an alignment routine is called upon to step in and do some little action, but
    most of the time these routines just lurk in the background. It's something like post-hypnotic
    suggestion.

    We have mentioned that alignrecords contain no |height| or |depth| fields. Their |glue_sign| and
    |glue_order| are pre-empted as well, since it is necessary to store information about what to do
    when a template ends. This information is called the |extra_info| field.

    Alignments can occur within alignments, so a small stack is used to access the alignrecord
    information. At each level we have a |preamble| pointer, indicating the beginning of the
    preamble list; a |cur_align| pointer, indicating the current position in the preamble list; a
    |cur_span| pointer, indicating the value of |cur_align| at the beginning of a sequence of
    spanned columns; a |cur_loop| pointer, indicating the tabskip glue before an alignrecord that
    should be copied next if the current list is extended; and the |align_state| variable, which
    indicates the nesting of braces so that |\cr| and |\span| and tab marks are properly
    intercepted. There also are pointers |cur_head| and |cur_tail| to the head and tail of a list
    of adjustments being moved out from horizontal mode to vertical~mode, and alike |cur_pre_head|
    and |cur_pre_tail| for pre-adjust lists.

    The current values of these nine quantities appear in global variables; when they have to be
    pushed down, they are stored in 6-word nodes, and |align_ptr| points to the topmost such node.

*/

/*tex

    So far, hardly anything has been added to the alignment code so the above, original \TEX\
    the program documentation still applies. Of course we have callbacks. Attributes are a bit
    complicating here. I experimented with some row and cell specific ones but grouping will always
    make it messy. One never knows what a preamble injects. So leaving it as-is is better than a
    subtoptimal solution with side effects. To mention one aspect: we have unset nodes that use the
    attribute fields for other purposes and get adapted later on anyway. I'll look into it again
    at some point.

    Contrary to other mechanisms, there are not that many extensions. One is that we can nest
    |\noalign| (so we don't need kludges at the macro level). The look ahead trickery has not been
    changed but we might get some variants (we have protected macros so it's not as sensitive as
    it was in the past.

    The |\tabsize| feature is experimental and possibly a prelude to more. I played with that
    when a test file (korean font table) was allocating so many nodes that I wondered if we could
    limit that (and redundant boxes and glue are the only things we can do here). It actually
    also saves a bit of runtime. This feature has not been tested yet with |\span| and |\omit|.

*/

/*
    Todo: lefttabskip righttabskip middletabskip
*/

typedef struct alignment_state_info {
    halfword cur_align;             /*tex The current position in the preamble list. */
    halfword cur_span;              /*tex The start of the currently spanned columns in the preamble list. */
    halfword cur_loop;              /*tex A place to copy when extending a periodic preamble. */
    halfword align_ptr;             /*tex The most recently pushed-down alignment stack node. */
    halfword cur_post_adjust_head;  /*tex Adjustment list head pointer. */
    halfword cur_post_adjust_tail;  /*tex Adjustment list tail pointer. */
    halfword cur_pre_adjust_head;   /*tex Pre-adjustment list head pointer. */
    halfword cur_pre_adjust_tail;   /*tex Pre-adjustment list tail pointer. */
    halfword cur_post_migrate_head;
    halfword cur_post_migrate_tail;
    halfword cur_pre_migrate_head;
    halfword cur_pre_migrate_tail;
    halfword hold_token_head;       /*tex head of a temporary list of another kind */
    halfword omit_template;         /*tex a constant token list */
    halfword no_align_level;
    halfword no_tab_skips;
    halfword attr_list;
    halfword cell_source;
    halfword wrap_source;
    halfword callback;
 // halfword reverse;       // todo 
 // halfword discard_skips; // todo 
} alignment_state_info ;

static alignment_state_info lmt_alignment_state = {
    .cur_align             = null,
    .cur_span              = null,
    .cur_loop              = null,
    .align_ptr             = null,
    .cur_post_adjust_head  = null,
    .cur_post_adjust_tail  = null,
    .cur_pre_adjust_head   = null,
    .cur_pre_adjust_tail   = null,
    .cur_post_migrate_head = null,
    .cur_post_migrate_tail = null,
    .cur_pre_migrate_head  = null,
    .cur_pre_migrate_tail  = null,
    .hold_token_head       = null,  /*tex head of a temporary list of another kind */
    .omit_template         = null,  /*tex a constant token list */
    .no_align_level        = 0,
    .no_tab_skips          = 0,
    .attr_list             = null,
    .cell_source           = 0,
    .wrap_source           = 0,
    .callback              = 0,
 // .reverse               = 0, 
 // .discard_skips         = 0,
};

/*tex We could as well save these in the alignment stack. */

typedef enum saved_align_items {
    saved_align_specification,
    saved_align_reverse,
    saved_align_discard,
    saved_align_noskips, /*tex Saving is not needed but it doesn't hurt either */
    saved_align_callback,
    saved_align_n_of_items,
} saved_align_items;

/*tex The current preamble list: */

# define preamble node_next(align_head)

/*tex We use them before we define them: */

static void tex_aux_initialize_row    (void);
static void tex_aux_initialize_column (void);
static void tex_aux_finish_row        (void);
static int  tex_aux_finish_column     (void);
static void tex_aux_finish_align      (void);

/*tex
    We get |alignment_record| into |unset_node| and |unset_node| into |[hv]list_node|. And because
    we can access the fields later on w emake sure that we wipe them. The box orientation field kind
    of protects reading them but still it's nicer this way. In general in \LUATEX\ and \LUAMETATEX\
    we need to be more careful because we expose fields.
*/

inline static void tex_aux_change_list_type(halfword n, quarterword type)
{
    node_type(n) = type;
    box_w_offset(n) = 0;    /* box_glue_stretch    align_record_span_ptr   */
    box_h_offset(n) = 0;    /* box_glue_shrink     align_record_extra_info */
    box_d_offset(n) = 0;    /* box_span_count                              */
    box_x_offset(n) = 0;    /*                     align_record_u_part     */
    box_y_offset(n) = 0;    /*                     align_record_v_part     */
 // box_geometry(n) = 0;    /* box_size                                    */
    box_orientation(n) = 0; /* box_size                                    */
}

/*tex

    The |align_state| and |preamble| variables are initialized elsewhere. Alignment stack
    maintenance is handled by a pair of trivial routines called |push_alignment| and |pop_alignment|.

    It makes not much sense to add support for an |attr| keyword to |\halign| and |\valign| because
    then we need to decide if we tag rows or cells or both or come up with |cellattr| and |rowattr|
    and such. But then it even makes sense to have explicit commands (in addition to the seperator)
    to tags individual cells. It's too much hassle for now and the advantages are not that large.

*/

static void tex_aux_push_alignment(void)
{
    /*tex The new alignment stack node: */
    halfword p = tex_new_node(align_stack_node, 0);
    align_stack_align_ptr(p) = lmt_alignment_state.align_ptr;
    align_stack_cur_align(p) = lmt_alignment_state.cur_align;
    align_stack_preamble(p) = preamble;
    align_stack_cur_span(p) = lmt_alignment_state.cur_span;
    align_stack_cur_loop(p) = lmt_alignment_state.cur_loop;
    align_stack_align_state(p) = lmt_input_state.align_state;
    align_stack_wrap_source(p) = lmt_alignment_state.wrap_source;
    align_stack_no_align_level(p) = lmt_alignment_state.no_align_level;
    align_stack_cur_post_adjust_head(p) = lmt_alignment_state.cur_post_adjust_head;
    align_stack_cur_post_adjust_tail(p) = lmt_alignment_state.cur_post_adjust_tail;
    align_stack_cur_pre_adjust_head(p) = lmt_alignment_state.cur_pre_adjust_head;
    align_stack_cur_pre_adjust_tail(p) = lmt_alignment_state.cur_pre_adjust_tail;
    align_stack_cur_post_migrate_head(p) = lmt_alignment_state.cur_post_migrate_head;
    align_stack_cur_post_migrate_tail(p) = lmt_alignment_state.cur_post_migrate_tail;
    align_stack_cur_pre_migrate_head(p) = lmt_alignment_state.cur_pre_migrate_head;
    align_stack_cur_pre_migrate_tail(p) = lmt_alignment_state.cur_pre_migrate_tail;
    align_stack_no_tab_skips(p) = lmt_alignment_state.no_tab_skips;
    align_stack_attr_list(p) = lmt_alignment_state.attr_list;
    lmt_alignment_state.align_ptr = p;
    lmt_alignment_state.cur_post_adjust_head = tex_new_temp_node();
    lmt_alignment_state.cur_pre_adjust_head = tex_new_temp_node();
    lmt_alignment_state.cur_post_migrate_head = tex_new_temp_node();
    lmt_alignment_state.cur_pre_migrate_head = tex_new_temp_node();
    /* */
    lmt_alignment_state.cell_source = 0;
    lmt_alignment_state.wrap_source = 0;
}

static void tex_aux_pop_alignment(void)
{
    /*tex The top alignment stack node: */
    halfword p = lmt_alignment_state.align_ptr;
    tex_flush_node(lmt_alignment_state.cur_post_adjust_head);
    tex_flush_node(lmt_alignment_state.cur_pre_adjust_head);
    tex_flush_node(lmt_alignment_state.cur_post_migrate_head);
    tex_flush_node(lmt_alignment_state.cur_pre_migrate_head);
    lmt_alignment_state.align_ptr = align_stack_align_ptr(p);
    lmt_alignment_state.cur_align = align_stack_cur_align(p);
    preamble = align_stack_preamble(p);
    lmt_alignment_state.cur_span = align_stack_cur_span(p);
    lmt_alignment_state.cur_loop = align_stack_cur_loop(p);
    lmt_input_state.align_state = align_stack_align_state(p);
    lmt_alignment_state.wrap_source = align_stack_wrap_source(p);
    lmt_alignment_state.no_align_level  = align_stack_no_align_level(p);
    lmt_alignment_state.cur_post_adjust_head = align_stack_cur_post_adjust_head(p);
    lmt_alignment_state.cur_post_adjust_tail = align_stack_cur_post_adjust_tail(p);
    lmt_alignment_state.cur_pre_adjust_head = align_stack_cur_pre_adjust_head(p);
    lmt_alignment_state.cur_pre_adjust_tail = align_stack_cur_pre_adjust_tail(p);
    lmt_alignment_state.cur_post_migrate_head = align_stack_cur_post_migrate_head(p);
    lmt_alignment_state.cur_post_migrate_tail = align_stack_cur_post_migrate_tail(p);
    lmt_alignment_state.cur_pre_migrate_head = align_stack_cur_pre_migrate_head(p);
    lmt_alignment_state.cur_pre_migrate_tail = align_stack_cur_pre_migrate_tail(p);
    lmt_alignment_state.no_tab_skips = align_stack_no_tab_skips(p);
    lmt_alignment_state.attr_list = align_stack_attr_list(p);
    tex_flush_node(p);
}

/*tex

    \TEX\ has eight procedures that govern alignments: |initialize_align| and |finish_align| are
    used at the  very beginning and the very end; |initialize_row| and |finish_row| are used at
    the beginning and end of individual rows; |initialize_span| is used at the beginning of a
    sequence of spanned columns (possibly involving only one column); |initialize_column| and
    |finish_column| are used at the beginning and end of individual columns; and |align_peek| is
    used after |\cr| to see whether the next item is |\noalign|.

    We shall consider these routines in the order they are first used during the course of a
    complete |\halign|, namely |initialize_align|, |align_peek|, |initialize_row|,
    |initialize_span|, |initialize_column|, |finish_column|, |finish_row|, |finish_align|.

    The preamble is copied directly, except that |\tabskip| causes a change to the tabskip glue,
    thereby possibly expanding macros that immediately follow it. An appearance of |\span| also
    causes such an expansion.

    Note that if the preamble contains |\global\tabskip|, the |\global| token survives in the
    preamble and the |\tabskip| defines new tabskip glue (locally).

    We enter |\span| into |eqtb| with |tab_mark| as its command code, and with |span_code| as the
    command modifier. This makes \TEX\ interpret it essentially the same as an alignment delimiter
    like |&|, yet it is recognizably different when we need to distinguish it from a normal
    delimiter. It also turns out to be useful to give a special |cr_code| to |\cr|, and an even
    larger |cr_cr_code| to |\crcr|.

    The end of a template is represented by two frozen control sequences called |\endtemplate|. The
    first has the command code |end_template|, which is |> outer_call|, so it will not easily
    disappear in the presence of errors. The |get_x_token| routine converts the first into the
    second, which has |endv| as its command code.

    The |cr_code| is distinct from |span_code| and from any character and |\crcr| differs from
    |\cr|.
*/

/*
    In \LUAMETATEX\ the code has been adapted a bit. Because we have some access to alignment
    related properties (commands, lists, etc.) The command codes have been reshuffled and
    combined. Instead of dedicated cmd codes, we have a shared cmd with subtypes. The logic
    hasn't changed, just the triggering of actions. In theory there can be a performance penalty
    (due to extra checking) but in practice that will not be noticed becasue this seldom happens.
    The advange is that we have a uniform token interface. It also makes it possible to extend
    the code.

*/

static void tex_aux_get_preamble_token(void)
{
  RESTART:
    tex_get_token();
    while (cur_cmd == alignment_cmd && cur_chr == span_code) {
        /*tex This token will be expanded once. */
        tex_get_token();
        if (cur_cmd > max_command_cmd) {
            tex_expand_current_token();
            tex_get_token();
        }
    }
    switch (cur_cmd) {
        case end_template_cmd:
            tex_alignment_interwoven_error(5);
            break;
        case internal_glue_cmd:
            if (cur_chr == internal_glue_location(tab_skip_code)) {
                halfword v = tex_scan_glue(glue_val_level, 1);
                if (global_defs_par > 0) {
                    update_tex_tab_skip_global(v);
                } else {
                    update_tex_tab_skip_local(v);
                }
                goto RESTART;
            } else {
                break;
            }
        case internal_dimen_cmd:
            if (cur_chr == internal_dimen_location(tab_size_code)) {
                scaled v = tex_scan_dimen(0, 0, 0, 1, NULL);
                tex_word_define(global_defs_par > 0 ? global_flag_bit : 0, internal_dimen_location(tab_size_code), v);
                goto RESTART;
            } else {
                break;
            }
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case tolerant_call_cmd:
        case tolerant_protected_call_cmd:
        case tolerant_semi_protected_call_cmd:
            if (has_eq_flag_bits(cur_cs, noaligned_flag_bit)) {
                tex_expand_current_token();
                goto RESTART;
            } else {
                break;
            }
    }
}

/*tex

    When |\halign| or |\valign| has been scanned in an appropriate mode, \TEX\ calls
    |initialize_align|, whose task is to get everything off to a good start. This mostly involves
    scanning the preamble and putting its information into the preamble list.

*/

static void tex_aux_scan_align_spec(quarterword c)
{
    quarterword mode = packing_additional;
    quarterword reverse = 0;
    quarterword discard = 0;
    quarterword noskips = 0;
    quarterword callback = 0;
    scaled amount = 0;
    halfword attrlist = null;
    int brace = 0;
    while (1) {
        cur_val = 0; /* why */
        switch (tex_scan_character("acdnrtsACDNRTS", 1, 1, 1)) {
            case 0:
                goto DONE;
            case 'a': case 'A':
                if (tex_scan_mandate_keyword("attr", 1)) {
                    halfword i = tex_scan_attribute_register_number();
                    halfword v = tex_scan_int(1, NULL);
                    if (eq_value(register_attribute_location(i)) != v) {
                        if (attrlist) {
                            attrlist = tex_patch_attribute_list(attrlist, i, v);
                        } else {
                            attrlist = tex_copy_attribute_list_set(tex_current_attribute_list(), i, v);
                        }
                    }
                }
                break;
            case 'c': case 'C':
                if (tex_scan_mandate_keyword("callback", 1)) {
                    callback = 1;
                }
                break;
            case 'd': case 'D':
                if (tex_scan_mandate_keyword("discard", 1)) {
                    discard = 1;
                }
                break;
            case 'n': case 'N':
                if (tex_scan_mandate_keyword("noskips", 1)) {
                    noskips = 1;
                }
                break;
            case 'r': case 'R':
                if (tex_scan_mandate_keyword("reverse", 1)) {
                    reverse = 1;
                }
                break;
            case 't': case 'T':
                if (tex_scan_mandate_keyword("to", 1)) {
                    mode = packing_exactly;
                    amount = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case 's': case 'S':
                if (tex_scan_mandate_keyword("spread", 1)) {
                    mode = packing_additional;
                    amount = tex_scan_dimen(0, 0, 0, 0, NULL);
                }
                break;
            case '{':
                brace = 1;
                goto DONE;
            default:
                goto DONE;
        }
    }
  DONE:
    if (! attrlist) {
        /* this alse sets the reference when not yet set */
        attrlist = tex_current_attribute_list();
    }
    /*tex Now we're referenced. We need to preserve this over the group. */
    add_attribute_reference(attrlist);
    tex_set_saved_record(saved_align_specification, box_spec_save_type, mode, amount);
    /* We save them but could put them in the state as we do for some anyway. */
    tex_set_saved_record(saved_align_reverse, box_reverse_save_type, reverse, 0);
    tex_set_saved_record(saved_align_discard, box_discard_save_type, noskips ? 0 : discard, 0);
    tex_set_saved_record(saved_align_noskips, box_noskips_save_type, noskips, 0);
    tex_set_saved_record(saved_align_callback, box_callback_save_type, callback, 0);
    lmt_save_state.save_stack_data.ptr += saved_align_n_of_items;
    tex_new_save_level(c);
    if (! brace) {
        tex_scan_left_brace();
    }
    lmt_alignment_state.no_tab_skips = noskips;
    lmt_alignment_state.attr_list = attrlist;
    lmt_alignment_state.callback = callback;
}

/*tex

    The tricky part about alignments is getting the templates into the scanner at the right time,
    and recovering control when a row or column is finished.

    We usually begin a row after each |\cr| has been sensed, unless that |\cr| is followed by
    |\noalign| or by the right brace that terminates the alignment. The |align_peek| routine is
    used to look ahead and do the right thing; it either gets a new row started, or gets a
    |\noalign} started, or finishes off the alignment.

*/

static void tex_aux_align_peek(void);

static void tex_aux_trace_no_align(const char *s)
{
    if (tracing_alignments_par > 0) {
        tex_begin_diagnostic();
        tex_print_format("[alignment: %s noalign, level %i]", s, lmt_alignment_state.no_align_level);
        tex_end_diagnostic();
    }
}

static void tex_aux_run_no_align(void)
{
    tex_scan_left_brace();
    tex_new_save_level(no_align_group);
    ++lmt_alignment_state.no_align_level;
    tex_aux_trace_no_align("entering");
    if (cur_list.mode == -vmode) {
        tex_normal_paragraph(no_align_par_context);
    }
}
static int tex_aux_nested_no_align(void)
{
    int state = lmt_alignment_state.no_align_level > 0;
    if (state) {
        tex_scan_left_brace();
        tex_new_save_level(no_align_group);
        ++lmt_alignment_state.no_align_level;
        tex_aux_trace_no_align("entering");
        if (cur_list.mode == -vmode) {
            tex_normal_paragraph(no_align_par_context);
        }
    }
    return state;
}

void tex_finish_no_alignment_group(void)
{
    if (! tex_wrapped_up_paragraph(no_align_par_context)) { /* needs testing */
        tex_end_paragraph(no_align_group, no_align_par_context);
        tex_aux_trace_no_align("leaving");
        --lmt_alignment_state.no_align_level;
        tex_unsave();
        if (lmt_alignment_state.no_align_level == 0) {
            tex_aux_align_peek();
        }
    }
}

static void tex_aux_align_peek(void)
{
  RESTART:
    lmt_input_state.align_state = 1000000;
  AGAIN:
    tex_get_x_or_protected();
    switch (cur_cmd) {
        case spacer_cmd:
            goto AGAIN;
        case right_brace_cmd:
            tex_aux_finish_align();
            break;
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case tolerant_call_cmd:
        case tolerant_protected_call_cmd:
        case tolerant_semi_protected_call_cmd:
            if (has_eq_flag_bits(cur_cs, noaligned_flag_bit)) {
                tex_expand_current_token();
                goto RESTART;
            } else {
                goto NEXTROW;
            }
        case alignment_cmd:
            switch (cur_chr) {
                case cr_cr_code:
                    /*tex Ignore |\crcr|. */
                    goto RESTART;
                case no_align_code:
                    tex_aux_run_no_align();
                    return;
            }
            // fall through
        default:
          NEXTROW:
            /*tex Start a new row. */
            tex_aux_initialize_row();
            /*tex Start a new column and replace what we peeked at. */
            tex_aux_initialize_column();
            break;
    }
}

/*tex
*
    Magick numbers are used to indicate the level of alignment. However, keep in  mind that in
    \LUANETATEX\ the fundamental parts of the rendering are separated. Contrary to traditional
    \TEX\ we don't have the interwoven hyphenation, ligature building, kerning, etc.\ code.

    In the end we have a list starting and ending with tabskips and align records seperated by
    such skips.

*/

void tex_run_alignment_initialize(void)
{
    halfword saved_cs = cur_cs;
    tex_aux_push_alignment();
    lmt_input_state.align_state = -1000000;
    /*tex
        When |\halign| is used as a displayed formula, there should be no other pieces of mlists
        present.
    */
    if (cur_list.mode == mmode && ((cur_list.tail != cur_list.head) || cur_list.incomplete_noad)) {
        tex_handle_error(
            normal_error_type,
            "Improper \\halign inside math mode",
            "Displays can use special alignments (like \\eqalignno) only if nothing but the\n"
            "alignment itself is in math mode. So I've deleted the formulas that preceded this\n"
            "alignment."
        );
        tex_flush_math();
    }
    /*tex We enter a new semantic level. */
    tex_push_nest();
    /*tex
        In vertical modes, |prev_depth| already has the correct value. But if we are in |mmode|
        (displayed formula mode), we reach out to the enclosing vertical mode for the |prev_depth|
        value that produces the correct baseline calculations.
    */
    if (cur_list.mode == mmode) {
        cur_list.mode = -vmode;
        cur_list.prev_depth = lmt_nest_state.nest[lmt_nest_state.nest_data.ptr - 2].prev_depth;
    } else if (cur_list.mode > 0) {
        cur_list.mode = -cur_list.mode;
    }
    /*tex This one also saves some in the state. */
    tex_aux_scan_align_spec(align_group);
    /*tex
        Scan the preamble. Even when we ignore zero tabskips, we do store them in the list because
        the machinery later on steps over them and checking for present glue makes the code
        horrible. The overhead is small because it's only the preamble where we waste glues then.
    */
    preamble = null;
    lmt_alignment_state.cur_align = align_head;
    lmt_alignment_state.cur_loop = null;
    lmt_input_state.scanner_status = scanner_is_aligning;
    lmt_input_state.warning_index = saved_cs;
    lmt_input_state.align_state = -1000000;
    /*tex At this point, |cur_cmd = left_brace|. */
    while (1) {
        /*tex Append the current tabskip glue to the preamble list. */
        halfword glue = tex_new_param_glue_node(tab_skip_code, tab_skip_glue);
        if (lmt_alignment_state.no_tab_skips && tex_glue_is_zero(glue)) {
            node_subtype(glue) = ignored_glue;
        }
        tex_couple_nodes(lmt_alignment_state.cur_align, glue);
        lmt_alignment_state.cur_align = glue;
        if (cur_cmd == alignment_cmd && (cur_chr == cr_code || cur_chr == cr_cr_code)) { /* Also cr_cr here? */
            /*tex A |\cr| ends the preamble. */
            break;
        } else {
            /*tex
                Scan preamble text until |cur_cmd| is |tab_mark| or |car_ret| and then scan the
                template |u_j|, putting the resulting token list in |hold_token_head|. Spaces are
                eliminated from the beginning of a template.
            */
            halfword record = null;
            halfword current = lmt_alignment_state.hold_token_head;
            token_link(current) = null;
            while (1) {
                tex_aux_get_preamble_token();
                if (cur_cmd == parameter_cmd || (cur_cmd == alignment_cmd && cur_chr == align_content_code)) {
                    break;
                } else if ((cur_cmd == alignment_cmd || cur_cmd == alignment_tab_cmd) && (lmt_input_state.align_state == -1000000)) {
                    if ((current == lmt_alignment_state.hold_token_head) && (! lmt_alignment_state.cur_loop) && (cur_cmd == alignment_tab_cmd)) {
                        lmt_alignment_state.cur_loop = lmt_alignment_state.cur_align;
                    } else {
                        tex_back_input(cur_tok);
                        tex_handle_error(
                            normal_error_type,
                            "Missing # inserted in alignment preamble",
                            "There should be exactly one # between &'s, when an \\halign or \\valign is being\n"
                            "set up. In this case you had none, so I've put one in; maybe that will work."
                        );
                        break;
                    }
                } else if (cur_cmd != spacer_cmd || current != lmt_alignment_state.hold_token_head) {
                    current = tex_store_new_token(current, cur_tok);
                }
            }
            /*tex A new align record: */
            record = tex_new_node(align_record_node, 0);
            tex_couple_nodes(lmt_alignment_state.cur_align, record);
            lmt_alignment_state.cur_align = record;
            align_record_span_ptr(record) = end_span;
            box_width(record) = null_flag;
            align_record_pre_part(record) = token_link(lmt_alignment_state.hold_token_head);
            /*tex Scan the template |v_j|, putting the resulting token list in |hold_token_head|. */
            current = lmt_alignment_state.hold_token_head;
            token_link(current) = null;
            while (1) {
                tex_aux_get_preamble_token();
                if ((cur_cmd == alignment_cmd || cur_cmd == alignment_tab_cmd) && (lmt_input_state.align_state == -1000000)) {
                    break;
                } else if (cur_cmd == parameter_cmd || (cur_cmd == alignment_cmd && cur_chr == align_content_code)) {
                    tex_handle_error(
                        normal_error_type,
                        "Only one # is allowed per tab",
                        "There should be exactly one # between &'s, when an \\halign or \\valign is being\n"
                        "set up. In this case you had more than one, so I'm ignoring all but the first."
                    );
                } else {
                    current = tex_store_new_token(current, cur_tok);
                }
            }
            if (tab_size_par > 0) {
                box_size(record) = tab_size_par;
                set_box_package_state(record, package_dimension_size_set);
            } else {
                box_width(record) = null_flag;
            }
            /*tex Put |\endtemplate| at the end: */
            current = tex_store_new_token(current, deep_frozen_end_template_1_token);
            align_record_post_part(lmt_alignment_state.cur_align) = token_link(lmt_alignment_state.hold_token_head);
        }
    }
    if (tracing_alignments_par > 1) {
        tex_print_levels();
        tex_print_str("<alignment preamble>");
        tex_show_node_list(preamble, max_integer, max_integer);
    }
    if (lmt_alignment_state.callback) {
        lmt_alignment_callback(cur_list.head, preamble_pass_alignment_context, lmt_alignment_state.attr_list, preamble);
    }
    lmt_input_state.scanner_status = scanner_is_normal;
    tex_new_save_level(align_group);
    if (every_cr_par) {
        tex_begin_token_list(every_cr_par, every_cr_text);
    }
    /*tex Look for |\noalign| or |\omit|. */
    tex_aux_align_peek();
}

void tex_finish_alignment_group(void)
{
    tex_back_input(cur_tok);
    cur_tok = deep_frozen_cr_token;
    tex_handle_error(
        insert_error_type,
        "Missing \\cr inserted",
        "I'm guessing that you meant to end an alignment here."
    );
}

/*tex

    The parameter to |initialize_span| is a pointer to the alignrecord where the next column or group
    of columns will begin. A new semantic level is entered, so that the columns will generate a list
    for subsequent packaging.

*/

static void tex_aux_initialize_span(halfword p)
{
    tex_push_nest();
    if (cur_list.mode == -hmode) {
        cur_list.space_factor = 1000;
    } else {
        cur_list.prev_depth = ignore_depth;
        tex_normal_paragraph(span_par_context);
    }
    lmt_alignment_state.cur_span = p;
}

/*tex

    To start a row (i.e., a \quote {row} that rhymes with \quote {dough} but not with \quote
    {bough}), we enter a new semantic level, copy the first tabskip glue, and change from internal
    vertical mode to restricted horizontal mode or vice versa. The |space_factor| and |prev_depth|
    are not used on this semantic level, but we clear them to zero just to be tidy.

*/

static void tex_aux_initialize_row(void)
{
    tex_push_nest();
    cur_list.mode = (- hmode - vmode) - cur_list.mode; /* weird code */
    if (cur_list.mode == -hmode) {
        cur_list.space_factor = 0;
    } else {
        cur_list.prev_depth = 0;
    }
    lmt_alignment_state.cur_align = preamble;
    if (node_subtype(preamble) != ignored_glue) {
        halfword glue = tex_new_glue_node(preamble, tab_skip_glue);
        tex_tail_append(glue);
        tex_attach_attribute_list_attribute(glue, lmt_alignment_state.attr_list);
    }
    lmt_alignment_state.cur_align = node_next(preamble);
    lmt_alignment_state.cur_post_adjust_tail = lmt_alignment_state.cur_post_adjust_head;
    lmt_alignment_state.cur_pre_adjust_tail = lmt_alignment_state.cur_pre_adjust_head;
    lmt_alignment_state.cur_post_migrate_tail = lmt_alignment_state.cur_post_migrate_head;
    lmt_alignment_state.cur_pre_migrate_tail = lmt_alignment_state.cur_pre_migrate_head;
    tex_aux_initialize_span(lmt_alignment_state.cur_align);
}

/*tex

    When a column begins, we assume that |cur_cmd| is either |omit| or else the current token should
    be put back into the input until the \<u_j> template has been scanned. Note that |cur_cmd| might
    be |tab_mark| or |car_ret|. We also assume that |align_state| is approximately 1000000 at this
    time. We remain in the same mode, and start the template if it is called for.

*/

static void tex_aux_initialize_column(void)
{
    align_record_cmd(lmt_alignment_state.cur_align) = cur_cmd;
    align_record_chr(lmt_alignment_state.cur_align) = cur_chr;
    if (cur_cmd == alignment_cmd && cur_chr == omit_code) {
        lmt_input_state.align_state = 0;
    } else {
        tex_back_input(cur_tok);
        if (every_tab_par) {
            tex_begin_token_list(every_tab_par, every_tab_text);
        }
        tex_begin_token_list(align_record_pre_part(lmt_alignment_state.cur_align), template_pre_text);
    }
    /*tex Now |align_state = 1000000|, one of these magic numbers. */
}

/*tex

    The scanner sets |align_state| to zero when the |u_j| template ends. When a subsequent |\cr|
    or |\span| or tab mark occurs with |align_state=0|, the scanner activates the following code,
    which fires up the |v_j| template. We need to remember the |cur_chr|, which is either
    |cr_cr_code|, |cr_code|, |span_code|, or a character code, depending on how the column text has
    ended.

    This part of the program had better not be activated when the preamble to another alignment is
    being scanned, or when no alignment preamble is active.

*/

void tex_insert_alignment_template(void)
{
    if (lmt_input_state.scanner_status == scanner_is_aligning || ! lmt_alignment_state.cur_align) {
        tex_alignment_interwoven_error(6);
    } else {
        /*tex in case of an |\omit| the gets discarded and is nowhere else referenced. */
        halfword cmd = align_record_cmd(lmt_alignment_state.cur_align);
        halfword chr = align_record_chr(lmt_alignment_state.cur_align);
        halfword tok = (cmd == alignment_cmd && chr == omit_code) ? lmt_alignment_state.omit_template : align_record_post_part(lmt_alignment_state.cur_align);
        align_record_cmd(lmt_alignment_state.cur_align) = cur_cmd;
        align_record_chr(lmt_alignment_state.cur_align) = cur_chr;
        tex_begin_token_list(tok, template_post_text);
        lmt_input_state.align_state = 1000000;
        lmt_alignment_state.cell_source = alignment_cell_source_par;
        if (alignment_wrap_source_par) {
            lmt_alignment_state.wrap_source = alignment_wrap_source_par;
        }
    }
}

/*tex Determine the stretch or shrink order */

inline static halfword tex_aux_determine_order(scaled *total)
{
    if      (total[filll_glue_order]) return filll_glue_order;
    else if (total[fill_glue_order])  return fill_glue_order;
    else if (total[fil_glue_order])   return fil_glue_order;
    else if (total[fi_glue_order])    return fi_glue_order;
    else                              return normal_glue_order;
}

/*tex

    A span node is a 3-word record containing |width|, |span_span|, and |span_ptr| fields. The
    |span_span| field indicates the number of spanned columns; the |span_ptr| field points to a
    span node for the same starting column, having a greater extent of spanning, or to |end_span|,
    which has the largest possible |span_span| field; the |width| field holds the largest natural
    width corresponding to a particular set of spanned columns.

    A list of the maximum widths so far, for spanned columns starting at a given column, begins
    with the |span_ptr| field of the alignrecord for that column. The code has to make sure that
    there is room for |span_ptr| in both the align record and the span nodes, which is why
    |span_ptr| replaces |node_attr|.

*/

static halfword tex_aux_new_span_node(halfword n, int s, scaled w)
{
    halfword p = tex_new_node(span_node, 0);
    span_ptr(p) = n; /*tex This one overlaps with |alignment_record_ptr|. */
    span_span(p) = s;
    span_width(p) = w;
    return p;
}

/*tex

    When the |end_template| command at the end of a |v_j| template comes through the scanner,
    things really start to happen; and it is the |finialize_column| routine that makes them happen.
    This routine returns |true| if a row as well as a column has been finished.

*/

void tex_alignment_interwoven_error(int n)
{
    tex_formatted_error("alignment", "interwoven preambles are not allowed, case %d", n);
}

halfword tex_alignment_hold_token_head(void)
{
    return lmt_alignment_state.hold_token_head;
}

static int tex_aux_finish_column(void)
{
    if (! lmt_alignment_state.cur_align) {
        tex_confusion("end template, case 1");
    } else {
        halfword q = node_next(lmt_alignment_state.cur_align);
        if (! q) {
            tex_confusion("end template, case 2");
        } else if (lmt_input_state.align_state < 500000) {
            tex_alignment_interwoven_error(1);
        } else {
            /*tex A few state variables. */
            halfword cmd = align_record_cmd(lmt_alignment_state.cur_align);
            halfword chr = align_record_chr(lmt_alignment_state.cur_align);
            /*tex
                We check the alignrecord after the current one. If the preamble list has been
                traversed, check that the row has ended.
            */
            halfword record = node_next(q);
            if (alignment_wrap_source_par) {
                lmt_alignment_state.wrap_source = alignment_wrap_source_par;
            }
            if (! record && ! ((cmd == alignment_cmd) && (chr == cr_code || chr == cr_cr_code))) {
                if (lmt_alignment_state.cur_loop) {
                    /*tex Lengthen the preamble periodically. A new align record: */
                    record = tex_new_node(align_record_node, 0);
                    tex_couple_nodes(q, record);
                    align_record_span_ptr(record) = end_span;
                    box_width(record) = null_flag;
                    lmt_alignment_state.cur_loop = node_next(lmt_alignment_state.cur_loop);
                    /*tex Copy the templates from node |cur_loop| into node |p|. */
                    {
                        halfword q = lmt_alignment_state.hold_token_head;
                        halfword r = align_record_pre_part(lmt_alignment_state.cur_loop);
                        while (r) {
                            q = tex_store_new_token(q, token_info(r));
                            r = token_link(r);
                        }
                        token_link(q) = null;
                        align_record_pre_part(record) = token_link(lmt_alignment_state.hold_token_head);
                    }
                    {
                        halfword q = lmt_alignment_state.hold_token_head;
                        halfword r = align_record_post_part(lmt_alignment_state.cur_loop);
                        while (r) {
                            q = tex_store_new_token(q, token_info(r));
                            r = token_link(r);
                        }
                        token_link(q) = null;
                        align_record_post_part(record) = token_link(lmt_alignment_state.hold_token_head);
                    }
                    lmt_alignment_state.cur_loop = node_next(lmt_alignment_state.cur_loop);
                    {
                        halfword glue = tex_new_glue_node(lmt_alignment_state.cur_loop, tab_skip_glue);
                        if (lmt_alignment_state.no_tab_skips && tex_glue_is_zero(glue)) {
                            node_subtype(glue) = ignored_glue;
                        }
                        tex_couple_nodes(record, glue);
                    }
                } else {
                    chr = cr_code;
                    align_record_chr(lmt_alignment_state.cur_align) = chr;
                    tex_handle_error(
                        normal_error_type,
                        "Extra alignment tab has been changed to \\cr",
                        "You have given more \\span or & marks than there were in the preamble to the\n"
                        "\\halign or \\valign now in progress. So I'll assume that you meant to type \\cr\n"
                        "instead."
                    );
                }
            }
            if (! (cmd == alignment_cmd && chr == span_code)) {
                /*tex a new unset box */
                halfword cell = null;
                /*tex natural width */
                scaled width = 0;
                scaled size = 0;
                int state = 0;
                int packing = packing_additional;
                /*tex The span counter. */
                halfword spans = 0;
                tex_unsave();
                tex_new_save_level(align_group);
                /*tex Package an unset box for the current column and record its width. */
                state = has_box_package_state(lmt_alignment_state.cur_align, package_dimension_size_set);
                if (state) {
                    size = box_size(lmt_alignment_state.cur_align);
                    packing = packing_exactly;
                }
                if (cur_list.mode == -hmode) {
                    lmt_packaging_state.post_adjust_tail = lmt_alignment_state.cur_post_adjust_tail;
                    lmt_packaging_state.pre_adjust_tail = lmt_alignment_state.cur_pre_adjust_tail;
                    lmt_packaging_state.post_migrate_tail = lmt_alignment_state.cur_post_migrate_tail;
                    lmt_packaging_state.pre_migrate_tail = lmt_alignment_state.cur_pre_migrate_tail;
                    cell = tex_filtered_hpack(cur_list.head, cur_list.tail, size, packing, align_set_group, direction_unknown, 0, null, 0, 0);
                    width = box_width(cell);
                    lmt_alignment_state.cur_post_adjust_tail = lmt_packaging_state.post_adjust_tail;
                    lmt_alignment_state.cur_pre_adjust_tail = lmt_packaging_state.pre_adjust_tail;
                    lmt_alignment_state.cur_post_migrate_tail = lmt_packaging_state.post_migrate_tail;
                    lmt_alignment_state.cur_pre_migrate_tail = lmt_packaging_state.pre_migrate_tail;
                    lmt_packaging_state.post_adjust_tail = null;
                    lmt_packaging_state.pre_adjust_tail = null;
                    lmt_packaging_state.post_migrate_tail = null;
                    lmt_packaging_state.pre_migrate_tail = null;
                } else {
                    cell = tex_filtered_vpack(node_next(cur_list.head), size, packing, 0, align_set_group, direction_unknown, 0, null, 0, 0);
                    width = box_height(cell);
                }
                if (lmt_alignment_state.cell_source) {
                    box_source_anchor(cell) = lmt_alignment_state.cell_source;
                    tex_set_box_geometry(cell, anchor_geometry);
                }
                tex_attach_attribute_list_attribute(cell, lmt_alignment_state.attr_list);
                if (lmt_alignment_state.cur_span != lmt_alignment_state.cur_align) {
                    /*tex Update width entry for spanned columns. */
                    halfword ptr = lmt_alignment_state.cur_span;
                    do {
                        ++spans;
                        ptr = node_next(node_next(ptr));
                    } while (ptr != lmt_alignment_state.cur_align);
                    if (spans > max_quarterword) {
                        /*tex This can happen, but won't. */
                        tex_confusion("too many spans");
                    }
                    ptr = lmt_alignment_state.cur_span;
                    while (span_span(align_record_span_ptr(ptr)) < spans) {
                        ptr = align_record_span_ptr(ptr);
                    }
                    if (span_span(align_record_span_ptr(ptr)) > spans) {
                        halfword span = tex_aux_new_span_node(align_record_span_ptr(ptr), spans, width);
                        align_record_span_ptr(ptr) = span;
                    } else if (span_width(align_record_span_ptr(ptr)) < width) {
                        span_width(align_record_span_ptr(ptr)) = width;
                    }
                } else if (width > box_width(lmt_alignment_state.cur_align)) {
                    box_width(lmt_alignment_state.cur_align) = width;
                }
                tex_aux_change_list_type(cell, unset_node);
                box_span_count(cell) = spans;
                if (! state) {
                    halfword order = tex_aux_determine_order(lmt_packaging_state.total_stretch);
                    box_glue_order(cell) = order;
                    box_glue_stretch(cell) = lmt_packaging_state.total_stretch[order];
                    order = tex_aux_determine_order(lmt_packaging_state.total_shrink);
                    box_glue_sign(cell) = order; /* hm, sign */
                    box_glue_shrink(cell) = lmt_packaging_state.total_shrink[order];
                }
                tex_pop_nest();
                tex_tail_append(cell);
                /*tex Copy the tabskip glue between columns. */
                if (node_subtype(node_next(lmt_alignment_state.cur_align)) != ignored_glue) {
                    halfword glue = tex_new_glue_node(node_next(lmt_alignment_state.cur_align), tab_skip_glue);
                    tex_attach_attribute_list_attribute(cell, lmt_alignment_state.attr_list);
                    tex_tail_append(glue);
                }
                if (cmd == alignment_cmd && (chr == cr_code || chr == cr_cr_code)) {
                    return 1;
                } else {
                    tex_aux_initialize_span(record);
                }
            }
            lmt_input_state.align_state = 1000000;
            do {
                tex_get_x_or_protected();
            } while (cur_cmd == spacer_cmd);
            lmt_alignment_state.cur_align = record;
            tex_aux_initialize_column();
        }
    }
    return 0;
}

/*tex

    At the end of a row, we append an unset box to the current vlist (for |\halign|) or the current
    hlist (for |\valign|). This unset box contains the unset boxes for the columns, separated by
    the tabskip glue. Everything will be set later.

*/

static void tex_aux_finish_row(void)
{
    halfword row;
    if (cur_list.mode == -hmode) {
        row = tex_filtered_hpack(cur_list.head, cur_list.tail, 0, packing_additional, finish_row_group, direction_unknown, 0, null, 0, 0);
        tex_pop_nest();
        if (lmt_alignment_state.cur_pre_adjust_head != lmt_alignment_state.cur_pre_adjust_tail) {
            tex_inject_adjust_list(lmt_alignment_state.cur_pre_adjust_head, 0, null, NULL);
        }
        if (lmt_alignment_state.cur_pre_migrate_head != lmt_alignment_state.cur_pre_migrate_tail) {
            tex_append_list(lmt_alignment_state.cur_pre_migrate_head, lmt_alignment_state.cur_pre_migrate_tail);
        }
        tex_append_to_vlist(row, lua_key_index(alignment), NULL);
        if (lmt_alignment_state.cur_post_migrate_head != lmt_alignment_state.cur_post_migrate_tail) {
            tex_append_list(lmt_alignment_state.cur_post_migrate_head, lmt_alignment_state.cur_post_migrate_tail);
        }
        if (lmt_alignment_state.cur_post_adjust_head != lmt_alignment_state.cur_post_adjust_tail) {
            tex_inject_adjust_list(lmt_alignment_state.cur_post_adjust_head, 0, null, NULL);
        }
    } else {
        row = tex_filtered_vpack(node_next(cur_list.head), 0, packing_additional, max_depth_par, finish_row_group, direction_unknown, 0, null, 0, 0);
        tex_pop_nest();
        tex_tail_append(row);
        cur_list.space_factor = 1000;
    }
    if (lmt_alignment_state.wrap_source) {
        box_source_anchor(row) = lmt_alignment_state.wrap_source;
        tex_set_box_geometry(row, anchor_geometry);
    }
    tex_aux_change_list_type(row, unset_node);
    tex_attach_attribute_list_attribute(row, lmt_alignment_state.attr_list);
    if (every_cr_par) {
        tex_begin_token_list(every_cr_par, every_cr_text);
    }
    tex_aux_align_peek();
    /*tex Note that |glue_shrink(p) = 0| since |glue_shrink == shift_amount|. */
}

/*tex

    Finally, we will reach the end of the alignment, and we can breathe a sigh of relief that
    memory hasn't overflowed. All the unset boxes will now be set so that the columns line up,
    taking due account of spanned columns.

    Normalizing by stripping zero tabskips makes the lists a little smaller which then is easier
    on later processing. But is is an option. We could actually not inject zero skips at all but
    then the code starts deviating too much. In some cases it can save a lot of zero glue nodes
    but we allocate them initially anyway. We don't save runtime here. (Some day I'll play a bit
    more with this and then probably also implement some pending extensions.)

*/

static void tex_aux_strip_zero_tab_skips(halfword q)
{
    halfword h = box_list(q);
    halfword t = h;
    while (t) {
        halfword n = node_next(t);
        if (node_type(t) == glue_node && node_subtype(t) == tab_skip_glue && tex_glue_is_zero(t)) {
            tex_try_couple_nodes(node_prev(t),n);
            if (t == h) {
                /*tex We only come here once. */
                h = n;
                box_list(q) = h;
            }
            tex_flush_node(t);
        }
        t = n;
    }
}

static void tex_aux_finish_align(void)
{
    /*tex a shared register for the list operations (others are localized) */
    halfword preroll;
    /*tex shift offset for unset boxes */
    scaled offset = 0;
    /*tex something new */
    halfword reverse = 0;
    halfword callback = lmt_alignment_state.callback;
    halfword discard = normalize_line_mode_permitted(normalize_line_mode_par, discard_zero_tab_skips_mode);
    /*tex The |align_group| was for individual entries: */
    if (cur_group != align_group) {
        tex_confusion("align, case 1");
    }
    tex_unsave();
    /*tex The |align_group| was for the whole alignment: */
    if (cur_group != align_group) {
        tex_confusion("align, case 2");
    }
    tex_unsave();
    if (lmt_nest_state.nest[lmt_nest_state.nest_data.ptr - 1].mode == mmode) {
        offset = display_indent_par;
    }
    lmt_save_state.save_stack_data.ptr -= saved_align_n_of_items;
    lmt_packaging_state.pack_begin_line = -cur_list.mode_line;
    reverse = saved_level(saved_align_reverse);            /* we can as well save these in the state */
    discard = discard || saved_level(saved_align_discard); /* we can as well save these in the state */
    /*tex
        All content is available now so this is a perfect spot for some processing. However, we
        cannot mess with the unset boxes (as these can have special properties). The main reason
        for some postprocessing can be to align (vertically) at a specific location in a cell
        but then we also need to process twice (and adapt the width in the preamble record).

        We flush the tokenlists so that in principle we can access the align record nodes as normal
        lists.
    */
    {
        halfword q = node_next(preamble);
        do {
            tex_flush_token_list(align_record_pre_part(q));
            tex_flush_token_list(align_record_post_part(q));
            align_record_pre_part(q) = null;
            align_record_post_part(q) = null;
            q = node_next(node_next(q));
        } while (q);
    }
    if (callback) {
        lmt_alignment_callback(cur_list.head, preroll_pass_alignment_context, lmt_alignment_state.attr_list, preamble);
    }
    /*tex

        Go through the preamble list, determining the column widths and changing the alignrecords
        to dummy unset boxes.

        It's time now to dismantle the preamble list and to compute the column widths. Let $w_{ij}$
        be the maximum of the natural widths of all entries that span columns $i$ through $j$,
        inclusive. The alignrecord for column~$i$ contains  $w_{ii}$ in its |width| field, and there
        is also a linked list of the nonzero $w_{ij}$ for increasing $j$, accessible via the |info|
        field; these span nodes contain the value $j-i+|min_quarterword|$ in their |link| fields.
        The values of $w_{ii}$ were initialized to |null_flag|, which we regard as $-\infty$.

        The final column widths are defined by the formula $$ w_j = \max_{1\L i\L j} \biggl( w_{ij}
        - \sum_{i\L k < j}(t_k + w_k) \biggr), $$ where $t_k$ is the natural width of the tabskip
        glue between columns $k$ and~$k + 1$. However, if $w_{ij} = -\infty$ for all $i$ in the
        range $1 <= i <= j$ (i.e., if every entry that involved column~$j$ also involved column~$j
        + 1$), we let $w_j = 0$, and we zero out the tabskip glue after column~$j$.

        \TEX\ computes these values by using the following scheme: First $w_1 = w_{11}$. Then
        replace $w_{2j}$ by $\max(w_{2j}, w_{1j} - t_1 - w_1)$, for all $j > 1$. Then $w_2 =
        w_{22}$. Then replace $w_{3j}$ by $\max(w_{3j}, w_{2j} - t_2 - w_2)$ for all $j > 2$; and
        so on. If any $w_j$ turns out to be $-\infty$, its value is changed to zero and so is the
        next tabskip.

    */
    {
        halfword q = node_next(preamble);
        do {
            /* So |q| and |p| point to alignment nodes that become unset ones. */
            halfword p = node_next(node_next(q));
            if (box_width(q) == null_flag) {
                /*tex Nullify |width(q)| and the tabskip glue following this column. */
                box_width(q) = 0;
                tex_reset_glue_to_zero(node_next(q));
            }
            if (align_record_span_ptr(q) != end_span) {
                /*tex

                    Merge the widths in the span nodes of |q| with those of |p|, destroying the
                    span nodes of |q|.

                    Merging of two span-node lists is a typical exercise in the manipulation of
                    linearly linked data structures. The essential invariant in the following
                    |repeat| loop is that we want to dispense with node |r|, in |q|'s list, and
                    |u| is its successor; all nodes of |p|'s list up to and including |s| have
                    been processed, and the successor of |s| matches |r| or precedes |r| or follows
                    |r|, according as |link(r) = n| or |link(r) > n| or |link(r) < n|.

                */
                halfword t = box_width(q) + glue_amount(node_next(q));
                halfword n = 1;
                halfword r = align_record_span_ptr(q);
                halfword s = end_span;
                align_record_span_ptr(s) = p;
                do {
                    halfword u = align_record_span_ptr(r);
                    span_width(r) -= t;
                    while (span_span(r) > n) {
                        s = align_record_span_ptr(s);
                        n = span_span(align_record_span_ptr(s)) + 1;
                    }
                    if (span_span(r) < n) {
                        align_record_span_ptr(r) = align_record_span_ptr(s);
                        align_record_span_ptr(s) = r;
                        --span_span(r);
                        s = r;
                    } else {
                        if (span_width(r) > span_width(align_record_span_ptr(s))) {
                            span_width(align_record_span_ptr(s)) = span_width(r);
                        }
                        tex_flush_node(r);
                    }
                    r = u;
                } while (r != end_span);
            }
            tex_aux_change_list_type(q, unset_node);
            box_glue_order(q) = normal_glue_order;
            box_glue_sign(q) = normal_glue_sign;
            box_height(q) = 0;
            box_depth(q) = 0;
            q = p;
        } while (q);
    }
    if (callback) {
        lmt_alignment_callback(cur_list.head, package_pass_alignment_context, lmt_alignment_state.attr_list, preamble);
    }
    /*tex

        Package the preamble list, to determine the actual tabskip glue amounts, and let |p| point
        to this prototype box.

        Now the preamble list has been converted to a list of alternating unset boxes and tabskip
        glue, where the box widths are equal to the final column sizes. In case of |\valign|, we
        change the widths to heights, so that a correct error message will be produced if the
        alignment is overfull or underfull.

    */
    if (cur_list.mode == -vmode) {
        halfword rule_save = overfull_rule_par;
        /*tex Prevent the rule from being packaged. */
        overfull_rule_par = 0; 
        preroll = tex_hpack(preamble, saved_value(saved_align_specification), saved_extra(saved_align_specification), direction_unknown, holding_none_option);
        overfull_rule_par = rule_save;
    } else {
        halfword unset = node_next(preamble);
        do {
            box_height(unset) = box_width(unset);
            box_width(unset) = 0;
            unset = node_next(node_next(unset));
        } while (unset);
        /* why filtered here ... */
        preroll = tex_filtered_vpack(preamble, saved_value(saved_align_specification), saved_extra(saved_align_specification), max_depth_par, preamble_group, direction_unknown, 0, 0, 0, holding_none_option);
        /* ... so we'll do this soon instead: */
     /* preroll = tex_vpack(preamble, saved_value(saved_align_specification), saved_extra(saved_align_specification), max_depth_par, direction_unknown, migrate_all_option); */
        unset = node_next(preamble);
        do {
            box_width(unset) = box_height(unset);
            box_height(unset) = 0;
            unset = node_next(node_next(unset));
        } while (unset);
    }
    lmt_packaging_state.pack_begin_line = 0;
    /*tex
        Here we set the glue in all the unset boxes of the current list based on the prerolled
        preamble.
    */
    {
        halfword rowptr = node_next(cur_list.head);
        while (rowptr) {
            switch (node_type(rowptr)) {
                 case unset_node:
                    {
                        /*tex
                            We set the unset box |q| and the unset boxes in it. The unset box |q|
                            represents a row that contains one or more unset boxes, depending on
                            how soon |\cr| occurred in that row.

                            We also reset some fields but this needs checking because we never set
                            set them in these unset boxes but in the preamble ones.
                        */
                        halfword preptr;
                        halfword colptr;
                        if (cur_list.mode == -vmode) {
                            tex_aux_change_list_type(rowptr, hlist_node);
                            box_width(rowptr) = box_width(preroll);
                        } else {
                            tex_aux_change_list_type(rowptr, vlist_node);
                            box_height(rowptr) = box_height(preroll);
                        }
                        node_subtype(rowptr) = align_row_list;
                        box_glue_order(rowptr) = box_glue_order(preroll);
                        box_glue_sign(rowptr) = box_glue_sign(preroll);
                        box_glue_set(rowptr) = box_glue_set(preroll);
                        box_shift_amount(rowptr) = offset;
                        colptr = box_list(rowptr);
                        preptr = box_list(preroll);
                        if (node_type(colptr) == glue_node) {
                            colptr = node_next(colptr);
                        }
                        if (node_type(preptr) == glue_node) {
                            preptr = node_next(preptr);
                        }
                        if (node_type(colptr) != unset_node) {
                            tex_formatted_error("alignment", "bad box");
                        }
                        do {
                            /*tex
                                We set the glue in node |r| and change it from an unset node. A box
                                made from spanned columns will be followed by tabskip glue nodes
                                and by empty boxes as if there were no spanning. This permits
                                perfect alignment of subsequent entries, and it prevents values
                                that depend on floating point arithmetic from entering into the
                                dimensions of any boxes.
                            */
                            halfword spans = box_span_count(colptr);
                            scaled total = box_width(preptr);
                            scaled width = total; /*tex The width of a column. */
                            halfword tail = hold_head;
                            int state = has_box_package_state(preptr, package_dimension_size_set);
                            /*tex
                                When we have a span we need to add dummies. We append tabskip glue
                                and an empty box to list |u|, and update |s| and |t| as the
                                prototype nodes are passed. We could shortcut some code when we
                                have zero skips but we seldom end up in this branch anyway.
                            */
                            while (spans > 0) {
                                --spans;
                                preptr = node_next(preptr);
                                if (node_subtype(preptr) != ignored_glue) {
                                 /* halfword glue = tex_new_glue_node(preptr, tab_skip_glue); */
                                    halfword glue = tex_new_glue_node(preptr, node_subtype(preptr));
                                    tex_try_couple_nodes(tail, glue);
                                    tex_attach_attribute_list_attribute(glue, lmt_alignment_state.attr_list);
                                    total += glue_amount(preptr);
                                    /*tex The |glueratio| case is redundant, anyway ... */
                                    switch (box_glue_sign(preroll)) {
                                        case stretching_glue_sign:
                                            if (glue_stretch_order(preptr) == box_glue_order(preroll)) {
                                                total += glueround((glueratio) (box_glue_set(preroll)) * (glueratio) (glue_stretch(preptr)));
                                            }
                                            break;
                                        case shrinking_glue_sign:
                                            if (glue_shrink_order(preptr) == box_glue_order(preroll)) {
                                                total -= glueround((glueratio) (box_glue_set(preroll)) * (glueratio) (glue_shrink(preptr)));
                                            }
                                            break;
                                    }
                                    tail = glue;
                                    /*tex Move on to the box. */
                                }
                                preptr = node_next(preptr);
                                {
                                    halfword box = tex_new_null_box_node(cur_list.mode == -vmode ? hlist_node : vlist_node, align_cell_list);
                                    tex_couple_nodes(tail, box);
                                    tex_attach_attribute_list_attribute(box, lmt_alignment_state.attr_list);
                                    total += box_width(preptr);
                                    if (cur_list.mode == -vmode) {
                                        box_width(box) = box_width(preptr);
                                    } else {
                                        box_height(box) = box_width(preptr);
                                    }
                                    tail = box;
                                }
                            }
                            if (cur_list.mode == -vmode) {
                                /*tex
                                    Make the unset node |r| into an |hlist_node| of width |w|,
                                    setting the glue as if the width were |t|.
                                */
                                box_height(colptr) = box_height(rowptr);
                                box_depth(colptr) = box_depth(rowptr);
                                if (! state) {
                                    if (total == box_width(colptr)) {
                                        box_glue_sign(colptr) = normal_glue_sign;
                                        box_glue_order(colptr) = normal_glue_order;
                                        box_glue_set(colptr) = 0.0;
                                    } else if (total > box_width(colptr)) {
                                        box_glue_sign(colptr) = stretching_glue_sign;
                                        if (box_glue_stretch(colptr) == 0) {
                                            box_glue_set(colptr) = 0.0;
                                        } else {
                                            box_glue_set(colptr) = (glueratio) ( ( (glueratio) total - (glueratio) box_width(colptr) ) / ( (glueratio) box_glue_stretch(colptr) ) );
                                        }
                                    } else {
                                        box_glue_order(colptr) = box_glue_sign(colptr);
                                        box_glue_sign(colptr) = shrinking_glue_sign;
                                        if (box_glue_shrink(colptr) == 0) {
                                            box_glue_set(colptr) = 0.0;
                                        } else if ((box_glue_order(colptr) == normal_glue_order) && (box_width(colptr) - total > box_glue_shrink(colptr))) {
                                            box_glue_set(colptr) = 1.0;
                                        } else {
                                            box_glue_set(colptr) = (glueratio) ( ( (glueratio) box_width(colptr) - (glueratio) total ) / ( (glueratio) box_glue_shrink(colptr) ) );
                                        }
                                    }
                                }
                                box_width(colptr) = width;
                                tex_aux_change_list_type(colptr, hlist_node);
                                node_subtype(colptr) = align_cell_list;
                            } else {
                                /*tex
                                    Make the unset node |r| into a |vlist_node| of height |w|,
                                    setting the glue as if the height were |t|.
                                */
                                box_width(colptr) = box_width(rowptr);
                                if (! state) {
                                    if (total == box_height(colptr)) {
                                        box_glue_sign(colptr) = normal_glue_sign;
                                        box_glue_order(colptr) = normal_glue_order;
                                        box_glue_set(colptr) = 0.0;
                                    } else if (total > box_height(colptr)) {
                                        box_glue_sign(colptr) = stretching_glue_sign;
                                        if (box_glue_stretch(colptr) == 0) {
                                            box_glue_set(colptr) = 0.0;
                                        } else {
                                            box_glue_set(colptr) = (glueratio) ( ( (glueratio) total - (glueratio) box_height(colptr) ) / ( (glueratio) box_glue_stretch(colptr) ) );
                                        }
                                    } else {
                                        box_glue_order(colptr) = box_glue_sign(colptr);
                                        box_glue_sign(colptr) = shrinking_glue_sign;
                                        if (box_glue_shrink(colptr) == 0) {
                                            box_glue_set(colptr) = 0.0;
                                        } else if ((box_glue_order(colptr) == normal_glue_order) && (box_height(colptr) - total > box_glue_shrink(colptr))) {
                                            box_glue_set(colptr) = 1.0;
                                        } else {
                                            box_glue_set(colptr) = (glueratio) ( ( (glueratio) box_height(colptr) - (glueratio) total) / ( (glueratio) box_glue_shrink(colptr) ) );
                                        }
                                    }
                                }
                                box_height(colptr) = width;
                                tex_aux_change_list_type(colptr, vlist_node);
                                node_subtype(colptr) = align_cell_list;
                            }
                            box_shift_amount(colptr) = 0;
                            if (tail != hold_head) {
                                /*tex Append blank boxes to account for spanned nodes. */
                                tex_try_couple_nodes(tail, node_next(colptr));
                                tex_try_couple_nodes(colptr, node_next(hold_head));
                                colptr = tail;
                            }
                            colptr = node_next(colptr);
                            preptr = node_next(preptr);
                            if (node_type(colptr) == glue_node) {
                                colptr = node_next(colptr);
                            }
                            if (node_type(preptr) == glue_node) {
                                preptr = node_next(preptr);
                            }
                        } while (colptr);
                        if (discard) {
                            tex_aux_strip_zero_tab_skips(rowptr);
                        }
                        if (reverse) {
                            box_list(rowptr) = tex_reversed_node_list(box_list(rowptr));
                        }
                    }
                    break;
                case rule_node:
                    {
                        /*tex
                            Make the running dimensions in rule |q| extend to the boundaries of the
                            alignment.
                        */
                        if (rule_width(rowptr) == null_flag) {
                            rule_width(rowptr) = box_width(preroll);
                        }
                        if (rule_height(rowptr) == null_flag) {
                            rule_height(rowptr) = box_height(preroll);
                        }
                        if (rule_depth(rowptr) == null_flag) {
                            rule_depth(rowptr) = box_depth(preroll);
                        }
                        /*tex We could use offset fields in rule instead. */
                        if (offset) {
                            halfword prv = node_prev(rowptr);
                            halfword nxt = node_next(rowptr);
                            halfword box = null;
                            node_prev(rowptr) = null;
                            node_next(rowptr) = null;
                            box = tex_hpack(rowptr, 0, packing_additional, direction_unknown, holding_none_option);
                            tex_attach_attribute_list_attribute(box, rowptr);
                            box_shift_amount(box) = offset;
                            node_subtype(box) = align_cell_list; /*tex This is not really a cell. */
                         // node_subtype(box) = unknown_list;    /*tex So maybe we will do this. */
                            tex_try_couple_nodes(prv, box);
                            tex_try_couple_nodes(box, nxt);
                            rowptr = box;
                        }
                    }
                    break;
                default:
                    /*tex
                        When we're in a |\halign| we get the rows (the |unset_node|s) while the
                        rules are horizontal ones. Furthermore we can get (vertical) glues and
                        whatever else got kicked in between the rows, but all that is (currently)
                        not processed.
                    */
                    break;
            }
            rowptr = node_next(rowptr);
        }
    }
    if (callback) {
        lmt_alignment_callback(cur_list.head, wrapup_pass_alignment_context, lmt_alignment_state.attr_list, preamble);
    }
    tex_flush_node_list(preroll);
    delete_attribute_reference(lmt_alignment_state.attr_list);
    tex_aux_pop_alignment();
    /*tex
        We now have a completed alignment, in the list that starts at |cur_list.head| and ends at
        |cur_list.tail|. This list will be merged with the one that encloses it. (In case the
        enclosing mode is |mmode|, for displayed formulas, we will need to insert glue before and
        after the display; that part of the program will be deferred until we're more familiar with
        such operations.)
    */
    {
        scaled prevdepth = cur_list.prev_depth;
        halfword head = node_next(cur_list.head);
        halfword tail = cur_list.tail;
        tex_pop_nest();
        if (cur_list.mode == mmode) {
            tex_finish_display_alignment(head, tail, prevdepth);
        } else {
            cur_list.prev_depth = prevdepth;
            if (head) {
                tex_tail_append(head);
                cur_list.tail = tail;
            }
            if (cur_list.mode == vmode) {
                if (! lmt_page_builder_state.output_active) {
                    lmt_page_filter_callback(alignment_page_context, 0);
                }
                tex_build_page();
            }
        }
    }
}

/*tex

    The token list |omit_template| just referred to is a constant token list that contains the
    special control sequence |\endtemplate| only.

*/

void tex_initialize_alignments(void)
{
    lmt_alignment_state.hold_token_head = tex_get_available_token(null);
    lmt_alignment_state.omit_template = tex_get_available_token(deep_frozen_end_template_1_token);
    span_span(end_span) = max_quarterword + 1;
    align_record_span_ptr(end_span) = null;
}

/*tex
*
    We no longer store |hold_token_head| and |omit_template| in the format file. It is a bit
    cleaner to just initialize them. So we free them.

*/

void tex_cleanup_alignments(void)
{
    tex_put_available_token(lmt_alignment_state.hold_token_head);
    tex_put_available_token(lmt_alignment_state.omit_template);
    lmt_alignment_state.hold_token_head = null;
    lmt_alignment_state.omit_template = null;
}

/*tex

    We've now covered most of the abuses of |\halign| and |\valign|. Let's take a look at what
    happens when they are used correctly.

    An |align_group| code is supposed to remain on the |save_stack| during an entire alignment,
    until |finish_align| removes it.

    A devious user might force an |end_template| command to occur just about anywhere; we must
    defeat such hacks.

*/

void tex_run_alignment_end_template(void)
{
    lmt_input_state.base_ptr = lmt_input_state.input_stack_data.ptr;
    lmt_input_state.input_stack[lmt_input_state.base_ptr] = lmt_input_state.cur_input;
    while ((  lmt_input_state.input_stack[lmt_input_state.base_ptr].index != template_post_text )
        && (! lmt_input_state.input_stack[lmt_input_state.base_ptr].loc)
        && (  lmt_input_state.input_stack[lmt_input_state.base_ptr].state == token_list_state)) {
        --lmt_input_state.base_ptr;
    }
    if (lmt_input_state.input_stack[lmt_input_state.base_ptr].index != template_post_text ) {
        tex_alignment_interwoven_error(2);
    } else if (lmt_input_state.input_stack[lmt_input_state.base_ptr].loc)  {
        tex_alignment_interwoven_error(3);
    } else if (lmt_input_state.input_stack[lmt_input_state.base_ptr].state != token_list_state) {
        tex_alignment_interwoven_error(4);
    } else if (cur_group == align_group) {
        if (! tex_wrapped_up_paragraph(align_par_context)) { /* needs testing */
            tex_end_paragraph(align_group, align_par_context);
            if (tex_aux_finish_column()) {
                tex_aux_finish_row();
            }
        }
    } else {
        tex_off_save();
    }
}

/*tex

    When |\cr| or |\span| or a tab mark comes through the scanner into |main_control|, it might be
    that the user has foolishly inserted one of them into something that has nothing to do with
    alignment. But it is far more likely that a left brace or right brace has been omitted, since
    |get_next| takes actions appropriate to alignment only when |\cr| or |\span| or tab marks occur
    with |align_state = 0|. The following program attempts to make an appropriate recovery.

    As an experiment we support nested |\noalign| usage but we do keep the braces so there is still
    grouping. We don't flag these groups as |no_align_group| because then we need to do more work
    and it's not worth the trouble. One can actually argue for not doing that anyway.

    I might now rename the next one to |run_alignment| (and then also a companion as we have two
    cases of usage).

*/

void tex_run_alignment_error(void)
{
    int cmd = cur_cmd;
    int chr = cur_chr;
    if (cmd == alignment_cmd && chr == no_align_code) {
        if (! tex_aux_nested_no_align()) {
            tex_handle_error(
                normal_error_type,
                "Misplaced \\noalign",
                "I expect to see \\noalign only after the \\cr of an alignment. Proceed, and I'll\n"
                "ignore this case."
            );
        }
    } else if (abs(lmt_input_state.align_state) > 2) {
        /*tex
            Express consternation over the fact that no alignment is in progress. In traditional
            \TEX\ the ampersand case will show a specific tab help, while in case of another
            character a more generic message is shown.

            We go for consistency here, so a little patch:
        */
        switch (cmd) {
            case alignment_tab_cmd:
                tex_handle_error(normal_error_type, "Misplaced %C", cmd, chr,
                    "I can't figure out why you would want to use a tab mark here. If some right brace\n"
                    "up above has ended a previous alignment prematurely, you're probably due for more\n"
                    "error messages."
                );
                break;
            default:
                tex_handle_error(normal_error_type, "Misplaced %C", cmd, chr,
                    "I can't figure out why you would want to use a tab mark or \\cr or \\span just\n"
                    "now. If something like a right brace up above has ended a previous alignment\n"
                    "prematurely, you're probably due for more error messages."
                );
                break;
        }
    } else {
        const char * helpinfo =
            "I've put in what seems to be necessary to fix the current column of the current\n"
            "alignment. Try to go on, since this might almost work.";
        tex_back_input(cur_tok);
        if (lmt_input_state.align_state < 0) {
            ++lmt_input_state.align_state;
            cur_tok = left_brace_token + '{';
            tex_handle_error(
                insert_error_type,
                "Missing { inserted",
                helpinfo
            );
        } else {
            --lmt_input_state.align_state;
            cur_tok = right_brace_token + '}';
            switch (cmd) {
                case alignment_cmd:
                    tex_handle_error(
                        insert_error_type,
                        "Missing } inserted, unexpected ",
                        cmd, chr,
                        helpinfo
                    );
                    break;
                case alignment_tab_cmd:
                    tex_handle_error(
                        insert_error_type,
                        "Missing } inserted, unexpected tab character (normally &)",
                        helpinfo
                    );
                    break;
            }
        }
    }
}
