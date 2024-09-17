/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    We're essentially done with the parts of \TEX\ that are concerned with the input (|get_next|)
    and the output (|ship_out|). So it's time to get heavily into the remaining part, which does
    the real work of typesetting.

    After lists are constructed, \TEX\ wraps them up and puts them into boxes. Two major
    subroutines are given the responsibility for this task: |hpack| applies to horizontal lists
    (hlists) and |vpack| applies to vertical lists (vlists). The main duty of |hpack| and |vpack|
    is to compute the dimensions of the resulting boxes, and to adjust the glue if one of those
    dimensions is pre-specified. The computed sizes normally enclose all of the material inside the
    new box; but some items may stick out if negative glue is used, if the box is overfull, or if a
    |\vbox| includes other boxes that have been shifted left.

    The subroutine call |hpack(p, w, m)| returns a pointer to an |hlist_node| for a box containing
    the hlist that starts at |p|. Parameter |w| specifies a width; and parameter |m| is either
    |exactly| or |additional|. Thus, |hpack(p, w, exactly)| produces a box whose width is exactly
    |w|, while |hpack(p, w, additional)| yields a box whose width is the natural width plus |w|. It
    is convenient to define a macro called |natural| to cover the most common case, so that we can
    say |hpack(p, natural)| to get a box that has the natural width of list |p|.

    Similarly, |vpack(p, w, m)| returns a pointer to a |vlist_node| for a box containing the vlist
    that starts at |p|. In this case |w| represents a height instead of a width; the parameter |m|
    is interpreted as in |hpack|.

    The parameters to |hpack| and |vpack| correspond to \TEX's primitives like |\hbox to 300pt|,
    |\hbox spread 10pt|; note that |\hbox| with no dimension following it is equivalent to |\hbox
    spread 0pt|. The |scan_spec| subroutine scans such constructions in the user's input, including
    the mandatory left brace that follows them, and it puts the specification onto |save_stack| so
    that the desired box can later be obtained by executing the following code:

    \starttyping
    save_state.save_ptr := save_state.save_ptr-1;
    hpack(p, saved_value(0), saved_level(0));
    \stoptyping

     Scan a box specification and left brace:
 */

/*tex
    The next version is the (current) end point of successive improvements. After some keys were
    added it became important to avoid redundant checking and pushing back mismatched keys. The
    older (maybe more readable) variants using |scan_keyword| can be found in the archives (zip
    and git) instead of as comments here.
*/

/*tex

    When scanning, special care is necessary to ensure that the special |save_stack| codes are
    placed just below the new group code, because scanning can change |save_stack| when |\csname|
    appears. This coincides with the text on |dir| and |attr| keywords, as these are exaclty the
    uses of |\hbox|, |\vbox|, and |\vtop| in the input stream (the others are |\vcenter|, |\valign|,
    and  |\halign|).

    Scan a box specification and left brace comes next. Again, the more verbose, but already
    rather optimized intermediate variants are in the archives. Improving scanners like this happen
    stepwise in order to maintain compatibility (although \unknown\ we now quit earlier in a
    mismatch so we're not exact compatible when an forward looking error happens.

 */

/* todo: options bitset */

typedef enum saved_box_entries {
    saved_box_slot_entry        = 0,
    saved_box_context_entry     = 0,
    saved_box_packing_entry     = 0,
    saved_box_amount_entry      = 1,
    saved_box_direction_entry   = 1,
    saved_box_dir_pointer_entry = 1,
    saved_box_attr_list_entry   = 2,
    saved_box_pack_entry        = 2,
    saved_box_orientation_entry = 2,
    saved_box_anchor_entry      = 3,
    saved_box_geometry_entry    = 3,
    saved_box_xoffset_entry     = 3,
    saved_box_yoffset_entry     = 4,
    saved_box_xmove_entry       = 4,
    saved_box_ymove_entry       = 4,
    saved_box_shift_entry       = 5,
    saved_box_source_entry      = 5,
    saved_box_target_entry      = 5,
    saved_box_class_entry       = 6,
    saved_box_state_entry       = 6,
    saved_box_axis_entry        = 6, 
    saved_box_retain_entry      = 7,  
    saved_box_options_entry     = 7,
    saved_box_reserved_1_entry  = 7,
    saved_box_callback_entry    = 8, /* leaders related */
    saved_box_leaders_entry     = 8, /* leaders related */
    saved_box_reserved_2_entry  = 8, /* leaders related */
    saved_box_n_of_records      = 9,
} saved_box_entries;

typedef enum saved_box_options { 
    saved_box_reverse_option   = 0x01,
    saved_box_container_option = 0x02,
    saved_box_limit_option     = 0x04,
    saved_box_mathtext_option  = 0x08,
} saved_box_options;

inline static void saved_box_initialize(void)
{
    saved_type(0) = saved_record_0;
    saved_type(1) = saved_record_1;
    saved_type(2) = saved_record_2;
    saved_type(3) = saved_record_3;
    saved_type(4) = saved_record_4;
    saved_type(5) = saved_record_5;
    saved_type(6) = saved_record_6;
    saved_type(7) = saved_record_7;
    saved_type(8) = saved_record_8;
    saved_record(0) = box_save_type;
    saved_record(1) = box_save_type;
    saved_record(2) = box_save_type;
    saved_record(3) = box_save_type;
    saved_record(4) = box_save_type;
    saved_record(5) = box_save_type;
    saved_record(6) = box_save_type;
    saved_record(7) = box_save_type;
    saved_record(8) = box_save_type;
}

# define saved_box_slot        saved_value_1(saved_box_slot_entry)
# define saved_box_context     saved_value_2(saved_box_context_entry)
# define saved_box_packing     saved_value_3(saved_box_packing_entry)
# define saved_box_amount      saved_value_1(saved_box_amount_entry)
# define saved_box_direction   saved_value_2(saved_box_direction_entry)
# define saved_box_dir_pointer saved_value_3(saved_box_dir_pointer_entry)
# define saved_box_attr_list   saved_value_1(saved_box_attr_list_entry)
# define saved_box_pack        saved_value_2(saved_box_pack_entry)
# define saved_box_orientation saved_value_3(saved_box_orientation_entry)
# define saved_box_anchor      saved_value_1(saved_box_anchor_entry)
# define saved_box_geometry    saved_value_2(saved_box_geometry_entry)
# define saved_box_xoffset     saved_value_3(saved_box_xoffset_entry)
# define saved_box_yoffset     saved_value_1(saved_box_yoffset_entry)
# define saved_box_xmove       saved_value_2(saved_box_xmove_entry)
# define saved_box_ymove       saved_value_3(saved_box_ymove_entry)
# define saved_box_shift       saved_value_1(saved_box_shift_entry)
# define saved_box_source      saved_value_2(saved_box_source_entry)
# define saved_box_target      saved_value_3(saved_box_target_entry)
# define saved_box_class       saved_value_1(saved_box_class_entry)
# define saved_box_state       saved_value_2(saved_box_state_entry)
# define saved_box_axis        saved_value_3(saved_box_axis_entry)
# define saved_box_retain      saved_value_1(saved_box_retain_entry)
# define saved_box_options     saved_value_2(saved_box_options_entry)
# define saved_box_reserved_1  saved_value_3(saved_box_reserved_1_entry)
# define saved_box_callback    saved_value_1(saved_box_callback_entry)
# define saved_box_leaders     saved_value_2(saved_box_leaders_entry)
# define saved_box_reserved_2  saved_value_3(saved_box_reserved_2_entry)

void tex_show_packaging_group(const char *package)
{
    tex_print_str_esc(package);
    tex_print_str(saved_box_packing == packing_exactly ? " to " : " spread ");
    tex_print_dimension(saved_box_amount, pt_unit);
}

int tex_show_packaging_record(void)
{
    tex_print_str("box, ");
    switch (saved_type(0)) { 
        case saved_record_0:
            tex_print_format("slot %i, context %i, packing %i", save_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_1:
            tex_print_format("amount %p, direction %i, pointer %i", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_2:
            tex_print_format("attrlist %i, pack %i, orientation %i", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_3:
            tex_print_format("anchor %i, geometry %i, xoffset %p", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_4:
            tex_print_format("yoffset %p, xmove %p, ymove %p", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_5:       
            tex_print_format("shift %p, source %i, target %i", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_6:
            tex_print_format("class %i, state %i, axis %i", saved_value_1(0), saved_value_2(0), saved_value_3(0));
            break;
        case saved_record_7:
            tex_print_format("retain %i, options %i", saved_value_1(0), saved_value_2(0));
            break;
        case saved_record_8:
            tex_print_format("callback %i, leaders %i", saved_value_1(0), saved_value_2(0));
            break;
        default: 
            return 0;
    }
    return 1;
}

int tex_get_packaging_context(void) { return saved_box_context; }
int tex_get_packaging_shift  (void) { return saved_box_shift; }

static void tex_aux_scan_full_spec(halfword context, quarterword c, quarterword spec_direction, int just_pack, scaled shift, halfword slot, halfword callback, halfword leaders)
{
    quarterword spec_packing = packing_additional;
    int spec_amount = 0;
    halfword attrlist = null;
    halfword orientation = 0;
    scaled xoffset = 0;
    scaled yoffset = 0;
    scaled xmove = 0;
    scaled ymove = 0;
    halfword source = 0;
    halfword target = 0;
    halfword anchor = 0;
    halfword geometry = 0;
    halfword axis = 0;
    halfword state = 0;
    halfword retain = 0;
    halfword mainclass = unset_noad_class;
    halfword options = 0;
    int brace = 0;
    while (1) {
        /*tex Maybe |migrate <int>| makes sense here. */
        switch (tex_scan_character("tascdoxyrlmTASCDOXYRLM", 1, 1, 1)) {
            case 0:
                goto DONE;
            case 't': case 'T':
                switch (tex_scan_character("aoAO", 0, 0, 0)) {
                    case 'a': case 'A':
                        if (tex_scan_mandate_keyword("target", 2)) {
                            target = tex_scan_integer(1, NULL);
                        }
                        break;
                    case 'o': case 'O':
                        spec_packing = packing_exactly;
                        spec_amount = tex_scan_dimension(0, 0, 0, 0, NULL);
                        break;
                    default:
                        tex_aux_show_keyword_error("target|to");
                        goto DONE;
                }
                break;
            case 'a': case 'A':
                switch (tex_scan_character("dntxDNTX", 0, 0, 0)) {
                    case 'd': case 'D':
                        if (tex_scan_mandate_keyword("adapt", 2)) {
                            spec_packing = packing_adapted;
                            spec_amount = tex_scan_limited_scale(0);
                        }
                        break;
                    case 't': case 'T':
                        if (tex_scan_mandate_keyword("attr", 2)) {
                            attrlist = tex_scan_attribute(attrlist);
                        }
                        break;
                    case 'n': case 'N':
                        if (tex_scan_mandate_keyword("anchor", 2)) {
                            switch (tex_scan_character("sS", 0, 0, 0)) {
                                case 's': case 'S':
                                    anchor = tex_scan_anchors(0);
                                    break;
                                default:
                                    anchor = tex_scan_anchor(0);
                                    break;
                            }
                        }
                        break;
                    case 'x': case 'X':
                        if (tex_scan_mandate_keyword("axis", 2)) {
                            axis |= tex_scan_box_axis();
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("adapt|attr|anchor|axis");
                        goto DONE;
                }
                break;
            case 's': case 'S':
                switch (tex_scan_character("hpoHPO", 0, 0, 0)) {
                    case 'h': case 'H':
                        /*tex
                            This is a bonus because we decoupled the shift amount from the context,
                            where it can be somewhat confusing as that is a hybrid amount, kind, or
                            flag field. The keyword overloads an already given |move_cmd|.
                        */
                        if (tex_scan_mandate_keyword("shift", 2)) {
                            shift = tex_scan_dimension(0, 0, 0, 0, NULL);
                        }
                        break;
                    case 'p': case 'P':
                        if (tex_scan_mandate_keyword("spread", 2)) {
                            spec_packing = packing_additional;
                            spec_amount = tex_scan_dimension(0, 0, 0, 0, NULL);
                        }
                        break;
                    case 'o': case 'O':
                        if (tex_scan_mandate_keyword("source", 2)) {
                            source = tex_scan_integer(1, NULL);
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("shift|spread|source");
                        goto DONE;
                }
                break;
            case 'd': case 'D':
                switch (tex_scan_character("eiEI", 0, 0, 0)) {
                    case 'i': case 'I':
                        /*tex 
                            For the sake of third party code that assumes \LUATEX's old directives 
                            we can support |dir TRT| and |dirTLT|; only these. But \unknown\ that 
                            would also mean we have to deal with |\textdir| and such. 
                        */
# if (0) 
                        if (tex_scan_mandate_keyword("direction", 2)) {
                            spec_direction = tex_scan_direction(0);
                        }
# else 
                        if (tex_scan_keyword("rection")) {
                            spec_direction = tex_scan_direction(0);
                        } else if (tex_scan_character("rR", 0, 0, 0)) {
                            /*tex This is undocumented. */
                            if (tex_scan_character("tT", 0, 1, 0)) {
                                switch (tex_scan_character("lLrR", 0, 0, 0)) {
                                    case 'l': case 'L': 
                                        spec_direction = 0;
                                        break;
                                    case 'r': case 'R': 
                                        spec_direction = 1;
                                        break;
                                    default: 
                                        goto BADDIR;
                                }
                                if (! tex_scan_character("tT", 0, 0, 0)) {
                                    goto BADDIR;
                                }
                            } else { 
                              BADDIR:
                                tex_aux_show_keyword_error("tlt|trt");
                                goto DONE;
                            }
                        } else {
                            tex_aux_show_keyword_error("direction|dir");
                            goto DONE;
                        }
# endif 
                        break;
                    case 'e': case 'E':
                        if (tex_scan_mandate_keyword("delay", 2)) {
                            state |= package_u_leader_delayed;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("direction|delay");
                        goto DONE;
                }
                break;
            case 'o': case 'O':
                if (tex_scan_mandate_keyword("orientation", 1)) {
                    orientation = tex_scan_orientation(0);
                }
                break;
            case 'x': case 'X':
                switch (tex_scan_character("omOM", 0, 0, 0)) {
                    case 'o': case 'O' :
                        if (tex_scan_mandate_keyword("xoffset", 2)) {
                            xoffset = tex_scan_dimension(0, 0, 0, 0, NULL);
                        }
                        break;
                    case 'm': case 'M' :
                        if (tex_scan_mandate_keyword("xmove", 2)) {
                            xmove = tex_scan_dimension(0, 0, 0, 0, NULL);
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("xoffset|xmove");
                        goto DONE;
                }
                break;
            case 'y': case 'Y':
                switch (tex_scan_character("omOM", 0, 0, 0)) {
                    case 'o': case 'O' :
                        if (tex_scan_mandate_keyword("yoffset", 2)) {
                             yoffset = tex_scan_dimension(0, 0, 0, 0, NULL);
                        }
                        break;
                    case 'm': case 'M' :
                        if (tex_scan_mandate_keyword("ymove", 2)) {
                             ymove = tex_scan_dimension(0, 0, 0, 0, NULL);
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("yoffset|ymove");
                        goto DONE;
                }
                break;
            case 'r': case 'R':
                if (tex_scan_character("eE", 0, 0, 0)) {
                    switch (tex_scan_character("vVtT", 0, 0, 0)) {
                        case 'v': case 'V' :
                            if (tex_scan_mandate_keyword("reverse", 3)) {
                                options |= saved_box_reverse_option;
                            }
                            break;
                        case 't': case 'T' :
                            if (tex_scan_mandate_keyword("retain", 3)) {
                                retain = tex_scan_integer(0, NULL);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("reverse|retain");
                            goto DONE;
                    }
                }
                break;
            case 'c': case 'C':
                switch (tex_scan_character("olOL", 0, 0, 0)) {
                    case 'o': case 'O' :
                        if (tex_scan_mandate_keyword("container", 2)) {
                            options |= saved_box_container_option;
                        }
                        break;
                    case 'l': case 'L' :
                        if (tex_scan_mandate_keyword("class", 2)) {
                            mainclass = tex_scan_math_class_number(0);
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("container|class");
                        goto DONE;
                }
                break;
            case 'l': case 'L':
                if (tex_scan_mandate_keyword("limit", 1)) {
                    options |= saved_box_limit_option;
                }
                break;
            case 'm': case 'M':
                if (tex_scan_mandate_keyword("mathtext", 1)) {
                    options |= saved_box_mathtext_option;
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
    if (anchor || source || target) {
        geometry |= anchor_geometry;
    }
    if (orientation || xmove || ymove) {
        geometry |= orientation_geometry;
    }
    if (xoffset || yoffset) {
        geometry |= offset_geometry;
    }
    /*tex
        We either build one triggered by the |attr| key or we never set it in which case we use the
        default. As we will use it anyway, we also bump the reference, which also makes sure that
        it will stay.
    */
    if (! attrlist) {
        /* this alse sets the reference when not yet set */
        attrlist = tex_current_attribute_list();
    }
    /*tex Now we're referenced. We need to preserve this over the group. */
    add_attribute_reference(attrlist);
    /* */
    saved_box_initialize();
    saved_box_slot = slot;
    saved_box_context = context; 
    /*tex Traditionally these two are packed into one record: */
    saved_box_packing = spec_packing;
    saved_box_amount = spec_amount;
    /*tex Adjust |text_dir_ptr| for |scan_spec|: */
    saved_box_direction = spec_direction;
    if (spec_direction != direction_unknown) {
        saved_box_dir_pointer = lmt_dir_state.text_dir_ptr;
        lmt_dir_state.text_dir_ptr = tex_new_dir(normal_dir_subtype, spec_direction);
    } else {
        saved_box_dir_pointer = null;
    }
    saved_box_attr_list = attrlist;
    saved_box_pack = just_pack;
    saved_box_orientation = orientation;
    saved_box_anchor = anchor;
    saved_box_geometry = geometry;
    saved_box_xoffset = xoffset;
    saved_box_yoffset = yoffset;
    saved_box_xmove = xmove;
    saved_box_ymove = ymove;
    saved_box_source = source;
    saved_box_target = target;
    saved_box_state = state;
    saved_box_options = options;
    saved_box_shift = shift;
    saved_box_axis = axis;
    saved_box_class = mainclass;
    saved_box_retain = retain;
    saved_box_callback = callback;
    saved_box_leaders = leaders;
    lmt_save_state.save_stack_data.ptr += saved_box_n_of_records;
    tex_new_save_level(c);
    if (! brace) {
        tex_scan_left_brace();
    }
    update_tex_par_direction(spec_direction);
    update_tex_text_direction(spec_direction);
}

/*tex

    To figure out the glue setting, |hpack| and |vpack| determine how much stretchability and
    shrinkability are present, considering all four orders of infinity. The highest order of
    infinity that has a nonzero coefficient is then used as if no other orders were present.

    For example, suppose that the given list contains six glue nodes with the respective
    stretchabilities |3pt|, |8fill|, |5fil|, |6pt|, |-3fil|, |-8fill|. Then the total is essentially
    |2fil|; and if a total additional space of 6pt is to be achieved by stretching, the actual
    amounts of stretch will be |0pt|, |0pt|, |15pt|, |0pt|, |-9pt|, and |0pt|, since only |fi| glue
    will be considered. (The |fill| glue is therefore not really stretching infinitely with respect
    to |fil|; nobody would actually want that to happen.)

    The arrays |total_stretch| and |total_shrink| are used to determine how much glue of each kind
    is present. A global variable |last_badness| is used to implement |\badness|.

*/

packaging_state_info lmt_packaging_state = {
    .total_stretch          = { 0 },
    .total_shrink           = { 0 },  /*tex glue found by |hpack| or |vpack| */
    .last_badness           = 0,      /*tex badness of the most recently packaged box */
    .last_overshoot         = 0,      /*tex overshoot of the most recently packaged box */
    .post_adjust_tail       = null,   /*tex tail of adjustment list */
    .pre_adjust_tail        = null,
    .post_migrate_tail      = null,   /*tex tail of migration list */
    .pre_migrate_tail       = null,
    .last_leftmost_char     = null,
    .last_rightmost_char    = null,
    .pack_begin_line        = 0,
 /* .active_height          = { 0 }, */
    .best_height_plus_depth = 0,
    .previous_char_ptr      = null,
    .font_expansion_ratio   = 0,
    .except                 = 0,
    .page_discards_tail     = null,
    .page_discards_head     = null,
    .split_discards_head    = null,
};

/*tex

    This state collects the glue found by |hpack| or |vpack|: |total_stretch| and |total_shrink|
    and the badness of the most recently packaged box |last_badness|.

    If the variable |adjust_tail| is non-null, the |hpack| routine also removes all occurrences of
    |insert_node|, |mark_node|, and |adjust_node| items and appends the resulting material onto the
    list that ends at location |adjust_tail|.

    Tail of adjustment list is stored in |adjust_tail|. Materials in |\vadjust| used with |pre|
    keyword will be appended to |pre_adjust_tail| instead of |adjust_tail|.

    The optimizers use |last_leftmost_char| and last_rightmost_char|.

    In order to provide a decent indication of where an overfull or underfull box originated, we
    use a global variable |pack_begin_line| that is set nonzero only when |hpack| is being called
    by the paragraph builder or the alignment finishing routine.

    The source file line where the current paragraph or alignment began; a negative value denotes
    alignment |pack_begin_line|.

    Pointers to the prev and next char of an implicit kern are kept in |next_char_p| and
    prev_char_p|.

    The kern stretch and shrink code was (or had become) rather weird ... the width field is set,
    and then used in a second calculation, repeatedly, so why is that \unknown\ maybe some some
    weird left-over \unknown\ anyway, the values are so small that in practice they are not
    significant at all when the backend sees them because a few hundred sp positive or negative are
    just noise there (so adjustlevel 3 has hardly any consequence for the result but is more
    efficient).

    In the end I simplified the code because in practice these kerns can between glyphs burried in
    discretionary nodes. Also, we don't enable it by default so let's just stick to the leftmost
    character as reference. We can assume the same font anyway.

*/

static inline int tex_has_glyph_expansion(halfword a) 
{ 
    return 
        ! ((glyph_options(a) & glyph_option_no_expansion) == glyph_option_no_expansion) 
        && has_font_text_control(glyph_font(a), text_control_expansion);
}

scaled tex_char_stretch(halfword p) /* todo: move this to texfont.c and make it more efficient */
{
    if (tex_has_glyph_expansion(p)) {
        halfword m = lmt_font_state.adjust_stretch;
        if (m > 0) {
            halfword f = glyph_font(p);
            halfword c = glyph_character(p);
            scaled e = tex_char_ef_from_font(f, c);
            if (e > 0) {
                scaled dw = tex_calculated_glyph_width(p, m) - tex_char_width_from_glyph(p);
                if (dw > 0) {
                    return tex_round_xn_over_d(dw, e, scaling_factor);
                }
            }
        }
    }
    return 0;
}

scaled tex_char_shrink(halfword p) /* todo: move this to texfont.c and make it more efficient */
{
    if (tex_has_glyph_expansion(p)) {
        halfword m = lmt_font_state.adjust_shrink;
        if (m > 0) {
            halfword f = glyph_font(p);
            halfword c = glyph_character(p);
            scaled e = tex_char_cf_from_font(f, c);
            if (e > 0) {
                scaled dw = tex_char_width_from_glyph(p) - tex_calculated_glyph_width(p, -m);
                if (dw > 0) {
                    return tex_round_xn_over_d(dw, e, scaling_factor);
                }
            }
        }
    }
    return 0;
}

scaled tex_kern_stretch(halfword p)
{
    scaled w = kern_amount(p);
    if (w)  {
        halfword l = lmt_packaging_state.previous_char_ptr;
        if (l && node_type(l) == glyph_node && tex_has_glyph_expansion(l)) {
            scaled m = lmt_font_state.adjust_stretch;
            if (m > 0) {
                scaled e = tex_char_ef_from_font(glyph_font(l), glyph_character(l));
                if (e > 0) {
                    scaled dw = w - tex_round_xn_over_d(w, scaling_factor + m, scaling_factor);
                    if (dw > 0) {
                        return tex_round_xn_over_d(dw, e, scaling_factor);
                    }
                }
            }
        }
    }
    return 0;
}

scaled tex_kern_shrink(halfword p)
{
    scaled w = kern_amount(p) ;
    if (w)  {
        halfword l = lmt_packaging_state.previous_char_ptr;
        if (l && node_type(l) == glyph_node && tex_has_glyph_expansion(l)) {
            halfword m = lmt_font_state.adjust_shrink;
            if (m > 0) {
                scaled e = tex_char_cf_from_font(glyph_font(l), glyph_character(l));
                if (e > 0) {
                    scaled dw = tex_round_xn_over_d(w, scaling_factor - m, scaling_factor) - w;
                    if (dw > 0) {
                        return tex_round_xn_over_d(dw, e, scaling_factor);
                    }
                }
            }
        }
    }
    return 0;
}

/*tex 

    We only need to set the factor when we have a non-zero kern and a following glyph that permits 
    it being set. We never get here when |ratio| is zero.

*/

static void tex_aux_set_kern_expansion(halfword p, halfword ratio)
{
    if (kern_amount(p))  {
        halfword glyph = lmt_packaging_state.previous_char_ptr;
        if (glyph && node_type(glyph) == glyph_node && tex_has_glyph_expansion(glyph)) {
            halfword fnt = glyph_font(glyph);
            halfword chr = glyph_character(glyph);
            if (ratio > 0) {
                scaled expansion = tex_char_ef_from_font(fnt, chr);
                if (expansion > 0) { 
                    halfword stretch = lmt_font_state.adjust_stretch;
                    if (stretch > 0) {
                        kern_expansion(p) = tex_ext_xn_over_d(ratio * expansion, stretch, scaling_factor);
                    }
                }
            } else if (ratio < 0) {
                scaled compression = tex_char_cf_from_font(fnt, chr);
                if (compression > 0) { 
                    halfword shrink = lmt_font_state.adjust_shrink;
                    if (shrink > 0) {
                        kern_expansion(p) = tex_ext_xn_over_d(ratio * compression, shrink, scaling_factor);
                    }
                }
            } else { 
                /* already catched */
            }
        }
    }
}

static void tex_aux_set_glyph_expansion(halfword p, int ratio)
{
    switch (node_type(p)) {
        case glyph_node:
            if (tex_has_glyph_expansion(p)) {
                if (ratio > 0) {
                    halfword fnt = glyph_font(p);
                    halfword chr = glyph_character(p);
                    scaled expansion = tex_char_ef_from_font(fnt, chr);
                    if (expansion > 0) { 
                        halfword stretch = lmt_font_state.adjust_stretch;
                        if (stretch > 0) {
                            glyph_expansion(p) = tex_ext_xn_over_d(ratio * expansion, stretch, scaling_factor);
                        }
                    }
                } else if (ratio < 0) {
                    halfword fnt = glyph_font(p);
                    halfword chr = glyph_character(p);
                    scaled compression = tex_char_cf_from_font(fnt, chr);
                    if (compression > 0) { 
                        halfword shrink = lmt_font_state.adjust_shrink;
                        if (shrink > 0) {
                            glyph_expansion(p) = tex_ext_xn_over_d(ratio * compression, shrink, scaling_factor);
                        }
                    }
                }
            }
            break;
        case disc_node:
            {
                halfword r = disc_pre_break_head(p);
                while (r) {
                    if (node_type(r) == glyph_node) {
                        tex_aux_set_glyph_expansion(r, ratio);
                    }
                    r = node_next(r);
                }
                r = disc_post_break_head(p);
                while (r) {
                    if (node_type(r) == glyph_node) {
                        tex_aux_set_glyph_expansion(r, ratio);
                    }
                    r = node_next(r);
                }
                r = disc_no_break_head(p);
                while (r) {
                    if (node_type(r) == glyph_node) {
                        tex_aux_set_glyph_expansion(r, ratio);
                    }
                    r = node_next(r);
                }
                break;
            }
        default:
            tex_normal_error("font expansion", "invalid node type");
            break;
    }
}

scaled tex_left_marginkern(halfword p)
{
    while (p && node_type(p) == glue_node) {
        p = node_next(p);
    }
    if (p && node_type(p) == kern_node && node_subtype(p) == left_margin_kern_subtype) {
        return kern_amount(p);
    } else  {
        return 0;
    }
}

scaled tex_right_marginkern(halfword p)
{
    if (p) {
        p = tex_tail_of_node_list(p);
        /*tex
            There can be a leftskip, rightskip, penalty and yes, also a disc node with a nesting
            node that points to glue spec ... and we don't want to analyze that messy lot.
        */
        while (p) {
            switch(node_type(p)) {
                case glue_node:
                    /*tex We backtrack over glue. */
                    p = node_prev(p);
                    break;
                case kern_node:
                    if (node_subtype(p) == right_margin_kern_subtype) {
                        return kern_amount(p);
                    } else {
                        return 0;
                    }
                case disc_node:
                    /*tex
                        Officially we should look in the replace but currently protrusion doesn't
                        work anyway with |foo\discretionary {} {} {bar-} | (no following char) so we
                        don't need it now.
                    */
                    p = node_prev(p);
                    if (p && node_type(p) == kern_node && node_subtype(p) == right_margin_kern_subtype) {
                        return kern_amount(p);
                    } else {
                        return 0;
                    }
                default:
                    return 0;
            }
        }
    }
    return 0;
}

/*tex

    Character protrusion is something we inherited from \PDFTEX\ and the next helper calculates
    the extend. Is this |last_*_char| logic still valid?

*/

scaled tex_char_protrusion(halfword p, int side)
{
    if (side == left_margin_kern_subtype) {
        lmt_packaging_state.last_leftmost_char = null;
    } else {
        lmt_packaging_state.last_rightmost_char = null;
    }
    if (! p || node_type(p) != glyph_node || tex_has_glyph_option(p, glyph_option_no_protrusion)) {
        return 0;
    } else if (side == left_margin_kern_subtype) {
        lmt_packaging_state.last_leftmost_char = p;
        return tex_char_left_protrusion_from_glyph(p);
    } else {
        lmt_packaging_state.last_rightmost_char = p;
        return tex_char_right_protrusion_from_glyph(p);
    }
}

/*tex

    Here we prepare for |hpack|, which is place where we do font substituting when font expansion
    is being used.

*/

int tex_ignore_math_skip(halfword p)
{
    if (math_skip_mode_par == math_skip_only_when_skip) {
        if (node_subtype(p) == end_inline_math) {
            if (tex_math_skip_boundary(node_next(p))) {
                return 0;
            }
        } else {
            if (tex_math_skip_boundary(node_prev(p))) {
                return 0;
            }
        }
    } else if (math_skip_mode_par == math_skip_only_when_no_skip) {
        if (node_subtype(p) == end_inline_math) {
            if (! tex_math_skip_boundary(node_next(p))) {
                return 0;
            }
        } else {
            if (! tex_math_skip_boundary(node_prev(p))) {
                return 0;
            }
        }
    } else {
        return 0;
    }
    tex_reset_math_glue_to_zero(p);
    return 1;
}

# define fix_int(val,min,max) (val < min ? min : (val > max ? max : val))

inline static halfword tex_aux_used_order(halfword *total)
{
    if (total[filll_glue_order]) {
        return filll_glue_order;
    } else if (total[fill_glue_order]) {
        return fill_glue_order;
    } else if (total[fil_glue_order]) {
        return fil_glue_order;
    } else if (total[fi_glue_order]) {
        return fi_glue_order;
    } else {
        return normal_glue_order;
    }
}

/*tex

    The original code mentions: \quotation {Transfer node |p| to the adjustment list. Although node
    |q| is not necessarily the immediate predecessor of node |p|, it always points to some node in
    the list preceding |p|. Thus, we can delete nodes by moving |q| when necessary. The algorithm
    takes linear time, and the extra computation does not intrude on the inner loop unless it is
    necessary to make a deletion.}. The trick used is the following:

    \starttyping
    q = r + list_offset;
    node_next(q) = p;
    ....
            while (node_next(q) != p) {
                q = node_next(q);
            }
    \stoptyping

    This list offset points to the memory slot in the node and it happens that the next pointer
    takes the same subfield as the normal next pointer (these are actually offsets in an array of
    memorywords). This kind of neat trickery is needed because there are only forward linked lists,
    but we can do it differently and thereby also use the normal list pointer. We need a bit more
    checking but in the end we have a better abstraction.

*/

/*tex 
    For now we have this here but maybe it makes sense to move the adjust migration to the adjust 
    module (tracing and such). It's a bit fyzzy code anyway. 
*/

inline static void tex_aux_promote_pre_migrated(halfword r, halfword p)
{
    halfword pa = box_pre_adjusted(p);
    halfword pm = box_pre_migrated(p);
    if (pa) {
        if (lmt_packaging_state.pre_adjust_tail) {
            lmt_packaging_state.pre_adjust_tail = tex_append_adjust_list(pre_adjust_head, lmt_packaging_state.pre_adjust_tail, pa, "promote");
        } else if (box_pre_adjusted(r)) {
            tex_couple_nodes(box_pre_adjusted(r), pa);
        } else {
            box_pre_adjusted(r) = pa;
        }
        box_pre_adjusted(p) = null;
    }
    if (pm) {
        if (lmt_packaging_state.pre_migrate_tail) {
            tex_couple_nodes(lmt_packaging_state.pre_migrate_tail, pm);
            lmt_packaging_state.pre_migrate_tail = tex_tail_of_node_list(pm);
        } else {
            /* here we prepend pm to rm */
            halfword rm = box_pre_migrated(r);
            if (rm) {
                tex_couple_nodes(pm, rm);
            }
            box_pre_migrated(r) = pm;
        }
        box_pre_migrated(p) = null;
    }
}

inline static void tex_aux_promote_post_migrated(halfword r, halfword p)
{
    halfword pa = box_post_adjusted(p);
    halfword pm = box_post_migrated(p);
    if (pa) {
        if (lmt_packaging_state.post_adjust_tail) {
            lmt_packaging_state.post_adjust_tail = tex_append_adjust_list(post_adjust_head, lmt_packaging_state.post_adjust_tail, pa, "promote");
        } else if (box_post_adjusted(r)) {
            tex_couple_nodes(box_post_adjusted(r), pa);
        } else {
            box_post_adjusted(r) = pa;
        }
        box_post_adjusted(p) = null;
    }
    if (box_except(p)) {
        lmt_packaging_state.except = box_except(p);
    }
    if (pm) {
        if (lmt_packaging_state.post_migrate_tail) {
            tex_couple_nodes(lmt_packaging_state.post_migrate_tail, pm);
            lmt_packaging_state.post_migrate_tail = tex_tail_of_node_list(pm);
        } else {
            /* here we append pm to rm */
            halfword rm = box_post_migrated(r);
            if (rm) {
                tex_couple_nodes(tex_tail_of_node_list(rm), pm);
            } else {
                box_post_migrated(r) = pm;
            }
        }
        box_post_migrated(p) = null;
    }
}

inline static halfword tex_aux_post_migrate(halfword r, halfword p)
{
    halfword n = p;
    halfword nn = node_next(p);
    halfword pm = box_post_migrated(r);
    if (p == box_list(r)) {
        box_list(r) = nn;
        if (nn) {
            node_prev(nn) = null;
        }
    } else {
        tex_couple_nodes(node_prev(p), nn);
    }
    if (pm) {
        tex_couple_nodes(tex_tail_of_node_list(pm), n);
    } else {
        box_post_migrated(r) = n;
    }
    node_next(n) = null;
    p = nn;
    return p;
}

inline static halfword tex_aux_normal_migrate(halfword r, halfword p)
{
    halfword n = p;
    halfword nn = node_next(p);
    if (p == box_list(r)) {
        box_list(r) = nn;
        if (nn) {
            node_prev(nn) = null;
        }
    } else {
        tex_couple_nodes(node_prev(p), nn);
    }
    tex_couple_nodes(lmt_packaging_state.post_migrate_tail, n);
    lmt_packaging_state.post_migrate_tail = n;
    node_next(n) = null;
    p = nn;
    return p;
}

static void tex_aux_append_diagnostic_rule(halfword box, halfword rule)
{
    halfword n = box_list(box);
    if (n) {
        /* the caller actually knows tail */
        halfword t = tex_tail_of_node_list(n);
        halfword c = t; 
        while (c && node_type(c) == glue_node) {
            switch (node_subtype(c)) { 
                case par_fill_right_skip_glue:
                case par_init_right_skip_glue:
                case right_skip_glue:
                case right_hang_skip_glue:
                    c = node_prev(c); 
                    break;
                default:
                    goto DONE; 
            }
        }
      DONE:
        if (c) { 
            n = node_next(c);
            if (n) { 
                tex_couple_nodes(rule, n);
            }
        } else { 
            c = t; 
        }
        tex_couple_nodes(c, rule);
    } else { 
        box_list(box) = rule;
    }
}

void tex_repack(halfword p, scaled w, int m)
{
    if (p) {
        halfword tmp; 
        switch (node_type(p)) { 
            case hlist_node:
                tmp = tex_hpack(box_list(p), w, m, box_dir(p), holding_none_option, box_limit_none);
                break;
            case vlist_node: 
                tmp = tex_vpack(box_list(p), w, m > packing_additional ? packing_additional : m, max_dimension, box_dir(p), holding_none_option, NULL);
                break;
            default: 
                return;
        }
        box_width(p) = box_width(tmp);
        box_height(p) = box_height(tmp);
        box_depth(p) = box_depth(tmp);
        box_glue_set(p) = box_glue_set(tmp);
        box_glue_order(p) = box_glue_order(tmp);
        box_glue_sign(p) = box_glue_sign(tmp);
        box_list(tmp) = null;
        tex_flush_node(tmp);
    }
}

// Not ok. For now we accept some drift and assume it averages out. Just   
// for fun we could actually store it in the glue set field afterwards. 
// 
// { 
//     halfword drift = scaledround(wd) - ws;
//     if (drift < 0) {
//         d -= (double) drift; 
//         wd -= (double) drift; 
//     }
// } 

/*tex 
    When |limitate| equals the node type we indeed limitate. Otherwise we freeze. 
*/

void tex_freeze(halfword p, int recurse, int limitate, halfword factor) 
{
    if (p) {
        switch (node_type(p)) { 
            case hlist_node:
                {
                    halfword c = box_list(p);
                    double set = (double) box_glue_set(p);
                    halfword order = box_glue_order(p);
                    halfword sign = box_glue_sign(p);
                    if (factor > 0) { 
                        set *= factor * 0.001;
                    } else if (factor < 0) {
                        double max = - factor * 0.001; 
                        if (set > max) {
                            set = max;
                        }
                    }
                    while (c) {
                        switch (node_type(c)) {
                            case glue_node:
                                switch (sign) {
                                    case stretching_glue_sign:
                                        if (glue_stretch_order(c) == order) {
                                            glue_amount(c) += limitate == hlist_node ? glue_stretch(c) : scaledround(glue_stretch(c) * set);
                                        }
                                        break;
                                    case shrinking_glue_sign:
                                        if (glue_shrink_order(c) == order) {
                                            glue_amount(c) -= scaledround(glue_shrink(c) * set);
                                        }
                                        break;
                                }
                                glue_stretch(c) = 0;
                                glue_shrink(c) = 0;
                                glue_stretch_order(c) = 0;
                                glue_shrink_order(c) = 0;
                                break;
                            case hlist_node:
                            case vlist_node:
                                if (recurse) {
                                    tex_freeze(c, recurse, limitate, factor);
                                }
                                break;
                            case math_node:
                                switch (sign) {
                                    case stretching_glue_sign:
                                        if (math_stretch_order(c) == order) {
                                            math_amount(c) += limitate == hlist_node ? math_stretch(c) : scaledround(math_stretch(c) * set);
                                        }
                                        break;
                                    case shrinking_glue_sign:
                                        if (math_shrink_order(c) == order) {
                                            math_amount(c) += scaledround(math_shrink(c) * set);
                                        }
                                        break;
                                }
                                math_stretch(c) = 0;
                                math_shrink(c) = 0;
                                math_stretch_order(c) = 0;
                                math_shrink_order(c) = 0;
                                break;
                            default: 
                                break;
                        }
                        c = node_next(c);
                    }
                    box_glue_set(p) = 0;
                    box_glue_order(p) = 0;
                    box_glue_sign(p) = 0;
                }
                break;
            case vlist_node: 
                {
                    halfword c = box_list(p);
                    double set = (double) box_glue_set(p);
                    halfword order = box_glue_order(p);
                    halfword sign = box_glue_sign(p);
                    if (factor > 0) { 
                        set *= factor * 0.001;
                    } else if (factor < 0) {
                        double max = - factor * 0.001; 
                        if (set > max) {
                            set = max;
                        }
                    }
                    while (c) {
                        switch (node_type(c)) {
                            case glue_node:
                                switch (sign) {
                                    case stretching_glue_sign:
                                        if (glue_stretch_order(c) == order) {
                                                glue_amount(c) += limitate == vlist_node ? glue_stretch(c) : scaledround(glue_stretch(c) * set);
                                        }
                                        break;
                                    case shrinking_glue_sign:
                                        if (glue_shrink_order(c) == order) {
                                            glue_amount(c) -= scaledround(glue_shrink(c) * set);
                                        }
                                        break;
                                }
                                glue_stretch(c) = 0;
                                glue_shrink(c) = 0;
                                glue_stretch_order(c) = 0;
                                glue_shrink_order(c) = 0;
                                break;
                            case hlist_node:
                            case vlist_node:
                                if (recurse) {
                                    tex_freeze(c, recurse, limitate, factor);
                                }
                                break;
                            default: 
                                break;
                        }
                        c = node_next(c);
                    }
                    box_glue_set(p) = 0;
                    box_glue_order(p) = 0;
                    box_glue_sign(p) = 0;
                }
                break;
            default: 
                return;
        }
    }
}

void tex_limit(halfword p) 
{
    /* 
        For now we only handle stretch. This is not watertight because when we max some, the others
        actually can becoem relative smaller. Of course we can also freeze and then recalculate. 
    */
    if (p) { 
        halfword c = box_list(p);
        double set = (double) box_glue_set(p);
        halfword order = box_glue_order(p);
        halfword sign = box_glue_sign(p);
        int limit = set > 1 && order == normal_glue_order; 
        if (limit) {
            double nonfrozen = 0;
            double frozen = 0;
            while (c) {
                if (node_type(c) == glue_node) {
                    switch (sign) {
                        case stretching_glue_sign:
                            if (glue_stretch_order(c) == order) {
                                if (tex_has_glue_option(c, glue_option_limit)) {
                                    frozen += glue_stretch(c);
                                } else {
                                    nonfrozen += glue_stretch(c);
                                }
                            }
                            break;
                        case shrinking_glue_sign:
                            if (glue_shrink_order(c) == order) {
                                if (tex_has_glue_option(c, glue_option_limit)) {
                                    frozen -= glue_shrink(c);
                                } else { 
                                    nonfrozen -= glue_shrink(c);
                                }
                            }
                            break;
                    }
                }
                c = node_next(c);
            }
            if (frozen) { 
                set = (set * (frozen + nonfrozen) - frozen) / nonfrozen; 
            } else { 
                limit = 0;
            }
        }
        c = box_list(p);
        while (c) {
            if (node_type(c) == glue_node) {
                switch (sign) {
                    case stretching_glue_sign:
                        if (glue_stretch_order(c) == order) {
                            if (limit && tex_has_glue_option(c, glue_option_limit)) {
                                glue_amount(c) += glue_stretch(c);
                            } else {
                                glue_amount(c) += scaledround(glue_stretch(c) * set);
                            }
                        }
                        break;
                    case shrinking_glue_sign:
                        if (glue_shrink_order(c) == order) {
                            if (limit && tex_has_glue_option(c, glue_option_limit)) {
                                glue_amount(c) -= glue_shrink(c);
                            } else { 
                                glue_amount(c) -= scaledround(glue_shrink(c) * set);
                            }
                        }
                        break;
                }
                glue_stretch(c) = 0;
                glue_shrink(c) = 0;
                glue_stretch_order(c) = 0;
                glue_shrink_order(c) = 0;
            }
            c = node_next(c);
        }
        box_glue_set(p) = 0;
        box_glue_order(p) = 0;
        box_glue_sign(p) = 0;
    }
}

scaled tex_stretch(halfword p)
{
    scaled stretch = 0;
    if (p) {
        switch (node_type(p)) { 
            case hlist_node:
            case vlist_node:
                if (box_glue_sign(p) == stretching_glue_sign) { 
                    halfword c = box_list(p);
                    halfword order = box_glue_order(p);
                    while (c) {
                        switch (node_type(c)) {
                            case glue_node:
                                if (glue_stretch_order(c) == order) {
                                    stretch += glue_stretch(c);
                                }
                                break;
                            case math_node:
                                if (math_stretch_order(c) == order) {
                                    stretch += math_stretch(c);
                                }
                                break;
                        }
                        c = node_next(c);
                    }
                }
                break;
        }
    }
    return stretch;
}

scaled tex_shrink(halfword p)
{
    scaled shrink = 0;
    if (p) {
        switch (node_type(p)) { 
            case hlist_node:
            case vlist_node:
                if (box_glue_sign(p) == shrinking_glue_sign) { 
                    halfword c = box_list(p);
                    halfword order = box_glue_order(p);
                    while (c) {
                        switch (node_type(c)) {
                            case glue_node:
                                if (glue_shrink_order(c) == order) {
                                    shrink += glue_shrink(c);
                                }
                                break;
                            case math_node:
                                if (math_shrink_order(c) == order) {
                                    shrink += math_shrink(c);
                                }
                                break;
                        }
                        c = node_next(c);
                    }
                }
                break;
        }
    }
    return shrink;
}

int nn = 0;

halfword tex_hpack(halfword p, scaled target, int method, singleword pack_direction, int retain, int limit)
{
    halfword tail = null;
    scaled height = 0;
    scaled depth = 0;
    scaled width = 0;
    scaled excess = 0;
    singleword hpack_dir = pack_direction == direction_unknown ?(singleword) text_direction_par : pack_direction;
    int disc_level = 0;
    int has_uleader = 0;
    halfword pack_interrupt[8];
    scaled font_stretch = 0;
    scaled font_shrink = 0;
    int adjust_spacing = adjust_spacing_off;
    int has_limit = box_limit_mode_hlist ? 1 : (limit == box_limit_line && box_limit_mode_line ? 1 : -1);
    /*tex the box node that will be returned */
    halfword result = tex_new_node(hlist_node, unknown_list);
    box_dir(result) = hpack_dir;
    lmt_packaging_state.last_badness = 0;
    lmt_packaging_state.last_overshoot = 0;
    switch(method) { 
        case packing_linebreak:
            method = packing_expanded;
            /* fall through, later we'll come back here: */
        case packing_substitute:
            adjust_spacing = tex_checked_font_adjust(
                lmt_linebreak_state.adjust_spacing,
                lmt_linebreak_state.adjust_spacing_step,
                lmt_linebreak_state.adjust_spacing_shrink,
                lmt_linebreak_state.adjust_spacing_stretch
            );
            break;
        default:
            adjust_spacing = tex_checked_font_adjust(
                adjust_spacing_par,
                adjust_spacing_step_par,
                adjust_spacing_shrink_par,
                adjust_spacing_stretch_par
            );
            break;
    }
    box_list(result) = p;
    switch (method) { 
        case packing_expanded:
            /*tex Why not always: */
            lmt_packaging_state.previous_char_ptr = null;
            break;
        case packing_adapted:
            if (target > scaling_factor) { 
                target = scaling_factor;
            } else if (target < -scaling_factor) { 
                target = -scaling_factor;
            }
    }
    for (int i = normal_glue_order; i <= filll_glue_order; i++) {
        lmt_packaging_state.total_stretch[i] = 0;
        lmt_packaging_state.total_shrink[i] = 0;
    }
    /*tex

        Examine node |p| in the hlist, taking account of its effect on the dimensions of the new
        box, or moving it to the adjustment list; then advance |p| to the next node. For disc
        node we enter a level so we don't use recursion.

        In other engines there is an optimization for glyph runs but here we use just one switch
        for everything. The performance hit is neglectable. So the comment \quotation {Incorporate
        character dimensions into the dimensions of the hbox that will contain~it, then move to
        the next node.} no longer applies. In \LUATEX\ ligature building, kerning and hyphenation
        are decoupled so comments about inner loop and performance no longer make sense here.

    */
    while (p) {
        switch (node_type(p)) {
            case glyph_node:
                {
                    scaledwhd whd;
                    if (adjust_spacing) {
                        switch (method) {
                            case packing_expanded:
                                {
                                    lmt_packaging_state.previous_char_ptr = p;
                                    font_stretch += tex_char_stretch(p);
                                    font_shrink += tex_char_shrink(p);
                                    break;
                                }
                            case packing_substitute:
                                lmt_packaging_state.previous_char_ptr = p;
                                if (lmt_packaging_state.font_expansion_ratio != 0) {
                                    tex_aux_set_glyph_expansion(p, lmt_packaging_state.font_expansion_ratio);
                                }
                                break;
                        }
                    }
                    whd = tex_glyph_dimensions_ex(p);
                    width += whd.wd;
                    if (whd.ht > height) {
                        height = whd.ht;
                    }
                    if (whd.dp > depth) {
                        depth = whd.dp;
                    }
                    break;
                }
            case hlist_node:
            case vlist_node:
                {
                    /*tex

                        Incorporate box dimensions into the dimensions of the hbox that will contain
                        it.

                    */
                    halfword shift = box_shift_amount(p);
                    scaledwhd whd = tex_pack_dimensions(p);
                    width += whd.wd;
                    if (whd.ht - shift > height) {
                        height = whd.ht - shift;
                    }
                    if (whd.dp + shift > depth) {
                        depth = whd.dp + shift;
                    }
                    tex_aux_promote_pre_migrated(result, p);
                    tex_aux_promote_post_migrated(result, p);
                    break;
                }
            case unset_node:
                width += box_width(p);
                if (box_height(p) > height) {
                    height = box_height(p);
                }
                if (box_depth(p) > depth) {
                    depth = box_depth(p);
                }
                /*tex No promotions here. */
                break;
            case rule_node:
                /*tex

                    The code here implicitly uses the fact that running dimensions are indicated
                    by |null_flag|, which will be ignored in the calculations because it is a
                    highly negative number.

                */
                width += rule_width(p);
                if (rule_height(p) > height) {
                    height = rule_height(p);
                }
                if (rule_depth(p) > depth) {
                    depth = rule_depth(p);
                }
                break;
            case glue_node:
                /*tex Incorporate glue into the horizontal totals. Can this overflow? */
                {
                    switch (method) { 
                        case packing_adapted:
                            if (target < 0) {
                                if (glue_shrink_order(p) == normal_glue_order) {                                   
                                    glue_amount(p) -= scaledround(-0.001 * target * (double) glue_shrink(p));
                                }
                            } else if (target > 0) {
                                if (glue_stretch_order(p) == normal_glue_order) {
                                    glue_amount(p) += scaledround( 0.001 * target * (double) glue_stretch(p));
                                }
                            }
                            width += glue_amount(p);
                            glue_shrink_order(p) = normal_glue_order;
                            glue_shrink(p) = 0;
                            glue_stretch_order(p) = normal_glue_order;
                            glue_stretch(p) = 0;
                            break;
                        default:
                            width += glue_amount(p);
                            lmt_packaging_state.total_stretch[glue_stretch_order(p)] += glue_stretch(p);
                            lmt_packaging_state.total_shrink[glue_shrink_order(p)] += glue_shrink(p);
                    }
                    if (is_leader(p)) {
                        halfword gl = glue_leader_ptr(p);
                        scaled ht = 0;
                        scaled dp = 0;
                        switch (node_type(gl)) {
                            case hlist_node:
                            case vlist_node:
                                ht = box_height(gl);
                                dp = box_depth(gl);
                                break;
                            case rule_node:
                                ht = rule_height(gl);
                                dp = rule_depth(gl);
                                break;
                        }
                        if (ht > height) {
                            height = ht;
                        }
                        if (dp > depth) {
                            depth = dp;
                        }
                        if (node_subtype(p) == u_leaders) {
                            has_uleader = 1;
                        }
                    }
                    if (! has_limit && tex_has_glue_option(p, glue_option_limit)) {
                        has_limit = 1;
                    }
                    break;
                }
            case kern_node:
                if (adjust_spacing == adjust_spacing_full && node_subtype(p) == font_kern_subtype) {
                    switch (method) {
                        case packing_expanded:
                            {
                                font_stretch += tex_kern_stretch(p);
                                font_shrink += tex_kern_shrink(p);
                                break;
                            }
                        case packing_substitute:
                            if (lmt_packaging_state.font_expansion_ratio != 0) {
                                tex_aux_set_kern_expansion(p, lmt_packaging_state.font_expansion_ratio);
                            }
                            break;
                    }
                }
                width += tex_kern_dimension_ex(p);
                break;
            case disc_node:
                if (adjust_spacing) {
                    switch (method) {
                        case packing_expanded:
                            /*tex
                                Won't give this issues with complex discretionaries as we don't
                                do the |packing_expand| here? I need to look into this!
                            */
                            break;
                        case packing_substitute:
                            if (lmt_packaging_state.font_expansion_ratio != 0) {
                                tex_aux_set_glyph_expansion(p, lmt_packaging_state.font_expansion_ratio);
                            }
                            break;
                    }
                }
                if (disc_no_break_head(p)) {
                    pack_interrupt[disc_level] = node_next(p);
                    ++disc_level;
                    p = disc_no_break(p);
                }
                break;
            case math_node:
                if (tex_math_glue_is_zero(p) || tex_ignore_math_skip(p)) {
                    width += math_surround(p);
                } else {
                    width += math_amount(p);
                    lmt_packaging_state.total_stretch[math_stretch_order(p)] += math_stretch(p);
                    lmt_packaging_state.total_shrink[math_shrink_order(p)] += math_shrink(p);
                }
                break;
            case dir_node:
                break;
            case insert_node:
                if (retain_inserts(retain)) {
                    break;
                } else if (lmt_packaging_state.post_migrate_tail) {
                    p = tex_aux_normal_migrate(result, p);
                    /*tex Here |q| stays as it is and we're already at next. */
                    continue;
                } else if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_insert)) {
                    halfword l = insert_list(p);
                    p = tex_aux_post_migrate(result, p);
                    while (l) {
                        l = node_type(l) == insert_node ? tex_aux_post_migrate(result, l) : node_next(l);
                    }
                    /*tex Here |q| stays as it is and we're already at next. */
                    continue;
                } else {
                    /*tex Nothing done, so we move on. */
                    break;
                }
            case mark_node:
                if (retain_marks(retain)) {
                    break;
                } else if (lmt_packaging_state.post_migrate_tail) {
                    p = tex_aux_normal_migrate(result, p);
                    /*tex Here |q| stays as it is and we're already at next. */
                    continue;
                } else if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_mark)) {
                    p = tex_aux_post_migrate(result, p);
                    /*tex Here |q| stays as it is and we're already at next. */
                    continue;
                } else {
                    /*tex Nothing done, so we move on. */
                    break;
                }
            case adjust_node:
                /*tex
                    We could combine this with migration code but adjust content actually is taken into account
                    as part of the flow (dimensions, penalties, etc).
                */
                if (adjust_list(p) && ! retain_adjusts(retain)) {
                    halfword next = node_next(p);
                    halfword current = p;
                    /*tex Remove from list: */
                    if (p == box_list(result)) {
                        box_list(result) = next;
                        if (next) {
                            node_prev(next) = null;
                        }
                    } else {
                        tex_couple_nodes(node_prev(p), next);
                    }
                    if (lmt_packaging_state.post_adjust_tail || lmt_packaging_state.pre_adjust_tail) {
                        tex_adjust_passon(result, current);
                    } else if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_adjust)) {
                        tex_adjust_attach(result, current);
                    }
                    p = next;
                    continue;
                } else {
                    break;
                }
            default:
                break;
        }
        /*
            This is kind of tricky: q is the pre-last pointer so we don't change it when we're
            inside a disc node. This way of keeping track of the last node is different from the
            previous engine.
        */
        if (disc_level > 0) {
            p = node_next(p);
            if (! p) {
                --disc_level;
                p = pack_interrupt[disc_level];
            }
        } else {
            tail = p;
            p = node_next(p);
        }
    }
    box_height(result) = height;
    box_depth(result) = depth;
    /*tex
        Determine the value of |width(r)| and the appropriate glue setting; then |return| or |goto
        common_ending|. When we get to the present part of the program, |x| is the natural width of
        the box being packaged.
    */
    switch (method) { 
        case packing_additional: 
            target += width;
            break;
        case packing_adapted: 
            target = width;
            break;
    }
    box_width(result) = target;
    excess = target - width;
    if (excess == 0) {
        box_glue_sign(result) = normal_glue_sign;
        box_glue_order(result) = normal_glue_order;
        box_glue_set(result) = 0.0;
        goto EXIT;
    } else if (excess > 0) {
        /*tex
            Determine horizontal glue stretch setting, then |return| or |goto common_ending|. If
            |hpack| is called with |m=cal_expand_ratio| we calculate |font_expand_ratio| and return
            without checking for overfull or underfull box.
        */
        halfword order = tex_aux_used_order(lmt_packaging_state.total_stretch);
        if ((method == packing_expanded) && (order == normal_glue_order) && (font_stretch > 0)) {
            lmt_packaging_state.font_expansion_ratio = tex_divide_scaled_n(excess, font_stretch, scaling_factor_double);
            goto EXIT;
        }
        box_glue_order(result) = order;
        box_glue_sign(result) = stretching_glue_sign;
        if (lmt_packaging_state.total_stretch[order]) {
            box_glue_set(result) = (glueratio) ((double) excess / lmt_packaging_state.total_stretch[order]);
        } else {
            /*tex There's nothing to stretch. */
            box_glue_sign(result) = normal_glue_sign;
            box_glue_set(result) = 0.0;
        }
        if (order == normal_glue_order && box_list(result)) {
            /*tex
                Report an underfull hbox and |goto common_ending|, if this box is sufficiently bad.
            */
            lmt_packaging_state.last_badness = tex_badness(excess, lmt_packaging_state.total_stretch[normal_glue_order]);
            if (lmt_packaging_state.last_badness > hbadness_par) {
                int callback_id = lmt_callback_defined(hpack_quality_callback);
                const char *verdict = lmt_packaging_state.last_badness > 100 ? "underfull" : "loose" ; // beware, this needs to be adapted to the configureable 99 
                if (callback_id > 0) {
                    if (tail) { 
                        halfword rule = null;
                        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "SdNddS->N",
                         // lmt_packaging_state.last_badness > 100  ? "underfull" : "loose", // beware, this needs to be adapted to the configureable 99 
                            verdict, 
                            lmt_packaging_state.last_badness,
                            result,
                            abs(lmt_packaging_state.pack_begin_line),
                            lmt_input_state.input_line,
                            tex_current_input_file_name(),
                            &rule
                        );
                        if (rule && rule != result) {
                            tex_aux_append_diagnostic_rule(result, rule);
                        }
                    }
                } else {
                    tex_print_nlp();
                 // if (lmt_packaging_state.last_badness > 100) {
                 //     tex_print_format("%l[package: underfull \\hbox (badness %i)", lmt_packaging_state.last_badness);
                 // } else {
                 //     tex_print_format("%l[package: loose \\hbox (badness %i)", lmt_packaging_state.last_badness);
                 // }
                    tex_print_format(
                        "%l[package: %s \\hbox (badness %i)", 
                     // lmt_packaging_state.last_badness > 100 ? "underfull" : "loose",
                        verdict,
                        lmt_packaging_state.last_badness
                    );
                    goto COMMON_ENDING;
                }
            }
        }
        goto EXIT;
    } else {
        /*tex
            Determine horizontal glue shrink setting, then |return| or |goto common_ending|,
        */
        halfword order = tex_aux_used_order(lmt_packaging_state.total_shrink);
        if ((method == packing_expanded) && (order == normal_glue_order) && (font_shrink > 0)) {
            lmt_packaging_state.font_expansion_ratio = tex_divide_scaled_n(excess, font_shrink, scaling_factor_double);
            goto EXIT;
        }
        box_glue_order(result) = order;
        box_glue_sign(result) = shrinking_glue_sign;
        if (lmt_packaging_state.total_shrink[order]) {
            box_glue_set(result) = (glueratio) ((double) (-excess) / (double) lmt_packaging_state.total_shrink[order]);
        } else {
            /*tex There's nothing to shrink. */
            box_glue_sign(result) = normal_glue_sign;
            box_glue_set(result) = 0.0;
        }
        if (order == normal_glue_order && box_list(result)) {
            if (lmt_packaging_state.total_shrink[order] < -excess) {
                int overshoot = -excess - lmt_packaging_state.total_shrink[normal_glue_order];
                lmt_packaging_state.last_badness = scaling_factor_squared;
                lmt_packaging_state.last_overshoot = overshoot;
                /*tex Use the maximum shrinkage */
                box_glue_set(result) = 1.0;
                /*tex Report an overfull hbox and |goto common_ending|, if this box is sufficiently bad. */
                if ((overshoot > hfuzz_par) || (hbadness_par < 100)) {
                    int callback_id = lmt_callback_defined(hpack_quality_callback);
                    halfword rule = null;
                    if (callback_id > 0) {
                        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "SdNddS->N",
                            "overfull",
                            overshoot,
                            result,
                            abs(lmt_packaging_state.pack_begin_line),
                            lmt_input_state.input_line,
                            tex_current_input_file_name(),
                            &rule);
                    } else if (tail && overfull_rule_par > 0) {
                        rule = tex_new_rule_node(normal_rule_subtype);
                        rule_width(rule) = overfull_rule_par;
                    }
                    if (rule && rule != result) {
                        tex_aux_append_diagnostic_rule(result, rule);
                    }
                    if (callback_id == 0) {
                        tex_print_nlp();
                        tex_print_format("%l[package: overfull \\hbox (%p too wide)", overshoot);
                        goto COMMON_ENDING;
                    }
                }
            } else {
                /*tex Report a tight hbox and |goto common_ending|, if this box is sufficiently bad. */
                lmt_packaging_state.last_badness = tex_badness(-excess, lmt_packaging_state.total_shrink[normal_glue_order]);
                if (lmt_packaging_state.last_badness > hbadness_par) {
                    int callback_id = lmt_callback_defined(hpack_quality_callback);
                    if (callback_id > 0) {
                        halfword rule = null;
                        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "SdNddS->N",
                            "tight",
                            lmt_packaging_state.last_badness,
                            result,
                            abs(lmt_packaging_state.pack_begin_line),
                            lmt_input_state.input_line,
                            tex_current_input_file_name(),
                            &rule);
                        if (rule && rule != result) {
                            tex_aux_append_diagnostic_rule(result, rule);
                        }
                    } else {
                        tex_print_nlp();
                        tex_print_format("%l[package: tight \\hbox (badness %i)", lmt_packaging_state.last_badness);
                        goto COMMON_ENDING;
                    }
                }
            }
        }
        goto EXIT;
    }
  COMMON_ENDING:
    /*tex Finish issuing a diagnostic message for an overfull or underfull hbox. */
    if (lmt_page_builder_state.output_active) {
        tex_print_format(" has occurred while \\output is active]");
    } else if (lmt_packaging_state.pack_begin_line == 0) {
        tex_print_format(" detected at line %i]", lmt_input_state.input_line);
    } else if (lmt_packaging_state.pack_begin_line > 0) {
        tex_print_format(" in paragraph at lines %i--%i]", lmt_packaging_state.pack_begin_line, lmt_input_state.input_line);
    } else {
        tex_print_format(" in alignment at lines %i--%i]", -lmt_packaging_state.pack_begin_line, lmt_input_state.input_line);
    }
    tex_print_ln();
    lmt_print_state.font_in_short_display = null_font;
    if (tracing_full_boxes_par > 0) {
        halfword detail = show_node_details_par;
        show_node_details_par = tracing_full_boxes_par;
        tex_short_display(box_list(result));
        tex_print_ln();
        tex_begin_diagnostic();
        tex_show_box(result);
        tex_end_diagnostic();
        show_node_details_par = detail;
    }
  EXIT:
    if ((method == packing_expanded) && (lmt_packaging_state.font_expansion_ratio != 0)) {
        halfword list = box_list(result);
        box_list(result) = null;
        tex_flush_node(result);
        lmt_packaging_state.font_expansion_ratio = fix_int(lmt_packaging_state.font_expansion_ratio, -scaling_factor, scaling_factor);
        /*tex This nested call uses the more or less global font_expand_ratio. */
        result = tex_hpack(list, target, packing_substitute, hpack_dir, holding_none_option, box_limit_none);
    } else { 
        if (has_uleader) { 
           set_box_package_state(result, package_u_leader_found);
        }
        if (has_limit > 0) {
            tex_limit(result);
        }
    }
    /*tex Here we reset the |font_expand_ratio|. */
    lmt_packaging_state.font_expansion_ratio = 0;
    return result;
}

halfword tex_filtered_hpack(halfword p, halfword qt, scaled w, int m, int grp, halfword d, int just_pack, halfword attr, int state, int retain)
{
    halfword head;
    singleword direction = (singleword) checked_direction_value(d);
    if (just_pack) {
        head = node_next(p);
    } else if (node_type(p) == temp_node && ! node_next(p)) {
        head = node_next(p);
    } else {
        /*tex Maybe here: |node_prev(p) = null|. */
        head = node_next(p);
        if (head) {
            node_prev(head) = null;
            if (tex_list_has_glyph(head)) {
                tex_handle_hyphenation(head, qt);
                head = tex_handle_glyphrun(head, grp, direction);
            }
            if (head) {
                /*tex ignores empty anyway. Maybe also pass tail? */
                head = lmt_hpack_filter_callback(head, w, m, grp, direction, attr);
            }
        }
    }
    head = tex_hpack(head, w, m, direction, retain, box_limit_none);
    if (has_box_package_state(head, package_u_leader_found)) {
        if (head && normalize_line_mode_option(flatten_h_leaders_mode)) { 
            if (! is_box_package_state(state, package_u_leader_delayed)) {
                tex_flatten_leaders(head, grp, just_pack, "filtered hpack", 0);
            }
        }
    }
    return head;
}

/*tex Here is a function to calculate the natural whd of a (horizontal) node list. */

scaledwhd tex_natural_hsizes(halfword p, halfword pp, glueratio g_mult, int g_sign, int g_order)
{
    scaledwhd siz = { .wd = 0, .ht = 0, .dp = 0, .ns = 0 };
    scaled gp = 0;
    scaled gm = 0;
    while (p && p != pp) {
        switch (node_type(p)) {
            case glyph_node:
                {
                    scaledwhd whd = tex_glyph_dimensions_ex(p);
                    siz.wd += whd.wd;
                    if (whd.ht > siz.ht) {
                        siz.ht = whd.ht;
                    }
                    if (whd.dp > siz.dp) {
                        siz.dp = whd.dp;
                    }
                    break;
                }
            case hlist_node:
            case vlist_node:
                {
                    scaled s = box_shift_amount(p);
                    scaledwhd whd = tex_pack_dimensions(p);
                    siz.wd += whd.wd;
                    if (whd.ht - s > siz.ht) {
                        siz.ht = whd.ht - s;
                    }
                    if (whd.dp + s > siz.dp) {
                        siz.dp = whd.dp + s;
                    }
                    break;
                }
            case unset_node:
                siz.wd += box_width(p);
                if (box_height(p) > siz.ht) {
                    siz.ht = box_height(p);
                }
                if (box_depth(p) > siz.dp) {
                    siz.dp = box_depth(p);
                }
                break;
            case rule_node:
                siz.wd += rule_width(p);
                if (rule_height(p) > siz.ht) {
                    siz.ht = rule_height(p);
                }
                if (rule_depth(p) > siz.dp) {
                    siz.dp = rule_depth(p);
                }
                break;
            case glue_node:
                siz.wd += glue_amount(p);
                switch (g_sign) {
                    case stretching_glue_sign:
                        if (glue_stretch_order(p) == g_order) {
                            gp += glue_stretch(p);
                        }
                        break;
                    case shrinking_glue_sign:
                        if (glue_shrink_order(p) == g_order) {
                            gm += glue_shrink(p);
                        }
                        break;
                }
                if (is_leader(p)) {
                    halfword gl = glue_leader_ptr(p);
                    halfword ht = 0;
                    halfword dp = 0;
                    switch (node_type(gl)) {
                        case hlist_node:
                        case vlist_node:
                            ht = box_height(gl);
                            dp = box_depth(gl);
                            break;
                        case rule_node:
                            ht = rule_height(gl);
                            dp = rule_depth(gl);
                            break;
                    }
                    if (ht) {
                        siz.ht = ht;
                    }
                    if (dp > siz.dp) {
                        siz.dp = dp;
                    }
                }
                break;
            case kern_node:
                siz.wd += tex_kern_dimension_ex(p);
                break;
            case disc_node:
                {
                    scaledwhd whd = tex_natural_hsizes(disc_no_break_head(p), null, g_mult, g_sign, g_order); /* hm, really glue here?  */
                    siz.wd += whd.wd;
                    if (whd.ht > siz.ht) {
                        siz.ht = whd.ht;
                    }
                    if (whd.dp > siz.dp) {
                        siz.dp = whd.dp;
                    }
                }
                break;
            case math_node:
                if (tex_math_glue_is_zero(p) || tex_ignore_math_skip(p)) {
                    siz.wd += math_surround(p);
                } else {
                    siz.wd += math_amount(p);
                    switch (g_sign) {
                        case stretching_glue_sign:
                            if (math_stretch_order(p) == g_order) {
                                gp += math_stretch(p);
                            }
                            break;
                        case shrinking_glue_sign:
                            if (math_shrink_order(p) == g_order) {
                                gm += math_shrink(p);
                            }
                            break;
                    }
                }
                break;
            case sub_box_node:
                /* really? */
                break;
            case sub_mlist_node:
                {
                    /* hack */
                    scaledwhd whd = tex_natural_hsizes(kernel_math_list(p), null, normal_glue_multiplier, normal_glue_sign, normal_glue_sign);
                    siz.wd += whd.wd;
                    if (whd.ht > siz.ht) {
                        siz.ht = whd.ht;
                    }
                    if (whd.dp > siz.dp) {
                        siz.dp = whd.dp;
                    }
                }
                break;
            default:
                break;
        }
        p = node_next(p);
    }
    siz.ns = siz.wd;
    switch (g_sign) {
        case stretching_glue_sign:
            siz.wd += glueround((glueratio)(g_mult) * (glueratio)(gp));
            break;
        case shrinking_glue_sign:
            siz.wd -= glueround((glueratio)(g_mult) * (glueratio)(gm));
            break;
    }
    return siz;
}

scaledwhd tex_natural_msizes(halfword p, int ignoreprime)
{
    scaledwhd siz = { .wd = 0, .ht = 0, .dp = 0, .ns = 0 };
    while (p) {
        switch (node_type(p)) {
            case glyph_node:
                {
                    scaledwhd whd = tex_glyph_dimensions_ex(p);
                    siz.wd += whd.wd;
                    if (whd.ht > siz.ht) {
                        siz.ht = whd.ht;
                    }
                    if (whd.dp > siz.dp) {
                        siz.dp = whd.dp;
                    }
                    break;
                }
            case hlist_node:
            case vlist_node:
                {
                    scaled s = box_shift_amount(p);
                    scaledwhd whd = ignoreprime ? tex_natural_msizes(box_list(p), ignoreprime) : tex_pack_dimensions(p);
                    siz.wd += whd.wd;
                    if (ignoreprime) {
                        switch (node_subtype(p)) { 
                            case math_prime_list:
                            case math_sup_list:
                            case math_scripts_list:
                                goto HERE;
                        }
                    }
                    if (whd.ht - s > siz.ht) {
                        siz.ht = whd.ht - s;
                    }
                  HERE:
                    if (whd.dp + s > siz.dp) {
                        siz.dp = whd.dp + s;
                    }
                    break;
                }
            case unset_node:
                siz.wd += box_width(p);
                if (box_height(p) > siz.ht) {
                    siz.ht = box_height(p);
                }
                if (box_depth(p) > siz.dp) {
                    siz.dp = box_depth(p);
                }
                break;
            case rule_node:
                siz.wd += rule_width(p);
                if (rule_height(p) > siz.ht) {
                    siz.ht = rule_height(p);
                }
                if (rule_depth(p) > siz.dp) {
                    siz.dp = rule_depth(p);
                }
                break;
            case glue_node:
                siz.wd += glue_amount(p);
                if (is_leader(p)) {
                    halfword gl = glue_leader_ptr(p);
                    halfword ht = 0;
                    halfword dp = 0;
                    switch (node_type(gl)) {
                        case hlist_node:
                        case vlist_node:
                            ht = box_height(gl);
                            dp = box_depth(gl);
                            break;
                        case rule_node:
                            ht = rule_height(gl);
                            dp = rule_depth(gl);
                            break;
                    }
                    if (ht) {
                        siz.ht = ht;
                    }
                    if (dp > siz.dp) {
                        siz.dp = dp;
                    }
                }
                break;
            case kern_node:
                siz.wd += tex_kern_dimension_ex(p);
                break;
            case disc_node:
                {
                    scaledwhd whd = tex_natural_msizes(disc_no_break_head(p), ignoreprime);
                    siz.wd += whd.wd;
                    if (whd.ht > siz.ht) {
                        siz.ht = whd.ht;
                    }
                    if (whd.dp > siz.dp) {
                        siz.dp = whd.dp;
                    }
                }
                break;
            case math_node:
                if (tex_math_glue_is_zero(p) || tex_ignore_math_skip(p)) {
                    siz.wd += math_surround(p);
                } else {
                    siz.wd += math_amount(p);
                }
                break;
            case sub_box_node:
                break;
            case sub_mlist_node:
                {
                    scaledwhd whd = tex_natural_msizes(kernel_math_list(p), ignoreprime);
                    siz.wd += whd.wd;
                    if (whd.ht > siz.ht) {
                        siz.ht = whd.ht;
                    }
                    if (whd.dp > siz.dp) {
                        siz.dp = whd.dp;
                    }
                }
                break;
            default:
                break;
        }
        p = node_next(p);
    }
    siz.ns = siz.wd;
    return siz;
}

scaledwhd tex_natural_vsizes(halfword p, halfword pp, glueratio g_mult, int g_sign, int g_order)
{
    scaledwhd siz = { .wd = 0, .ht = 0, .dp = 0, .ns = 0 };
    scaled gp = 0;
    scaled gm = 0;
    while (p && p != pp) {
        switch (node_type(p)) {
            case hlist_node:
            case vlist_node:
                {
                    scaled shift = box_shift_amount(p);
                    scaledwhd whd = tex_pack_dimensions(p);
                    if (whd.wd + shift > siz.wd) {
                        siz.wd = whd.wd + shift;
                    }
                    siz.ht += siz.dp + whd.ht;
                    siz.dp = whd.dp;
                }
                break;
            case unset_node:
                siz.ht += siz.dp + box_height(p);
                siz.dp = box_depth(p);
                if (box_width(p) > siz.wd) {
                    siz.wd = box_width(p);
                }
                break;
            case rule_node:
                siz.ht += siz.dp + rule_height(p);
                siz.dp = rule_depth(p);
                if (rule_width(p) > siz.wd) {
                    siz.wd = rule_width(p);
                }
                break;
            case glue_node:
                {
                    siz.ht += siz.dp + glue_amount(p);
                    siz.dp = 0;
                    if (is_leader(p)) {
                        halfword gl = glue_leader_ptr(p);
                        halfword wd = 0;
                        switch (node_type(gl)) {
                            case hlist_node:
                            case vlist_node:
                                wd = box_width(gl);
                                break;
                            case rule_node:
                                wd = rule_width(gl);
                                break;
                        }
                        if (wd > siz.wd) {
                            siz.wd = wd;
                        }
                    }
                    switch (g_sign) {
                        case stretching_glue_sign:
                            if (glue_stretch_order(p) == g_order) {
                                gp += glue_stretch(p);
                            }
                            break;
                        case shrinking_glue_sign:
                            if (glue_shrink_order(p) == g_order) {
                                gm += glue_shrink(p);
                            }
                            break;
                    }
                    break;
                }
            case kern_node:
                siz.ht += siz.dp + kern_amount(p);
                siz.dp = 0;
                break;
            case glyph_node:
                tex_confusion("glyph in vpack");
                break;
            case disc_node:
                tex_confusion("discretionary in vpack");
                break;
            default:
                break;
        }
        p = node_next(p);
    }
    siz.ns = siz.ht;
    switch (g_sign) {
        case stretching_glue_sign:
            siz.ht += glueround((glueratio)(g_mult) * (glueratio)(gp));
            break;
        case shrinking_glue_sign:
            siz.ht -= glueround((glueratio)(g_mult) * (glueratio)(gm));
            break;
    }
    return siz;
}

/*tex simplified variant with less memory access */

halfword tex_natural_width(halfword p, halfword pp, glueratio g_mult, int g_sign, int g_order)
{
    scaled wd = 0;
    scaled gp = 0;
    scaled gm = 0;
    while (p && p != pp) {
        /* no real gain over check in switch */
        switch (node_type(p)) {
            case glyph_node:
                wd += tex_glyph_width(p); /* Plus expansion? */
                break;
            case hlist_node:
            case vlist_node:
            case unset_node:
                wd += box_width(p);
                break;
            case rule_node:
                wd += rule_width(p);
                break;
            case glue_node:
                wd += glue_amount(p);
                switch (g_sign) {
                    case stretching_glue_sign:
                        if (glue_stretch_order(p) == g_order) {
                            gp += glue_stretch(p);
                        }
                        break;
                    case shrinking_glue_sign:
                        if (glue_shrink_order(p) == g_order) {
                            gm += glue_shrink(p);
                        }
                        break;
                }
                break;
            case kern_node:
                wd += kern_amount(p); // + kern_expansion(p);
                break;
            case disc_node:
                wd += tex_natural_width(disc_no_break(p), null, g_mult, g_sign, g_order);
                break;
            case math_node:
                if (tex_math_glue_is_zero(p) || tex_ignore_math_skip(p)) {
                    wd += math_surround(p);
                } else {
                    wd += math_amount(p);
                    switch (g_sign) {
                        case stretching_glue_sign:
                            if (math_stretch_order(p) == g_order) {
                                gp += math_stretch(p);
                            }
                            break;
                        case shrinking_glue_sign:
                            if (math_shrink_order(p) == g_order) {
                                gm += math_shrink(p);
                            }
                            break;
                    }
                }
                break;
            default:
                break;
        }
        p = node_next(p);
    }
    switch (g_sign) {
        case stretching_glue_sign:
            wd += glueround((glueratio) (g_mult) * (glueratio) (gp));
            break;
        case shrinking_glue_sign:
            wd -= glueround((glueratio) (g_mult) * (glueratio) (gm));
            break;
    }
    return wd;
}

halfword tex_natural_hsize(halfword p, halfword *correction)
{
    scaled wd = 0;
    halfword c = null;
    while (p) {
        switch (node_type(p)) {
            case glyph_node:
                wd += tex_glyph_width(p); /* Plus expansion? */
                break;
            case hlist_node:
            case vlist_node:
            case unset_node:
                wd += box_width(p);
                break;
            case rule_node:
                wd += rule_width(p);
                break;
            case glue_node:
                wd += glue_amount(p);
                if (node_subtype(p) == correction_skip_glue) {
                    c = p;
                }
                break;
            case kern_node:
                wd += kern_amount(p); //  + kern_expansion(p);
                break;
            case disc_node:
                wd += tex_natural_hsize(disc_no_break(p), NULL);
                break;
            case math_node:
                if (tex_math_glue_is_zero(p) || tex_ignore_math_skip(p)) {
                    wd += math_surround(p);
                } else {
                    wd += math_amount(p);
                }
                break;
            default:
                break;
        }
        p = node_next(p);
    }
    if (correction) {
        *correction = c;
    }
    return wd;
}

halfword tex_natural_vsize(halfword p)
{
    scaled ht = 0;
    scaled dp = 0;
    while (p) {
        switch (node_type(p)) {
            case hlist_node:
            case vlist_node:
                ht += dp + box_height(p);
                dp = box_depth(p);
                break;
            case unset_node:
                ht += dp + box_height(p);
                dp = box_depth(p);
                break;
            case rule_node:
                ht += dp + rule_height(p);
                dp = rule_depth(p);
                break;
            case glue_node:
                ht += dp + glue_amount(p);
                dp = 0;
                break;
            case kern_node:
                ht += dp + kern_amount(p);
                dp = 0;
                break;
            default:
                break;
        }
        p = node_next(p);
    }
    return ht + dp;
}

/*tex

    The |vpack| subroutine is actually a special case of a slightly more general routine called
    |vpackage|, which has four parameters. The fourth parameter, which is |max_dimension| in the case
    of |vpack|, specifies the maximum depth of the page box that is constructed. The depth is first
    computed by the normal rules; if it exceeds this limit, the reference point is simply moved
    down until the limiting depth is attained. We actually hav efive parameters because we also
    deal with teh direction.

*/

halfword tex_vpack(halfword p, scaled targetheight, int m, scaled targetdepth, singleword pack_direction, int retain, scaled *excess)
{
    scaled width = 0;
    scaled depth = 0;
    scaled height = 0;
    int has_uleader = 0;
    /*tex the box node that will be returned */
    halfword box = tex_new_node(vlist_node, unknown_list);
    int has_limit = box_limit_mode_vlist ? 1 : -1;
    (void) retain; /* todo */
    box_dir(box) = pack_direction;
    box_shift_amount(box) = 0;
    box_list(box) = p;
    lmt_packaging_state.last_badness = 0;
    lmt_packaging_state.last_overshoot = 0;
    for (int i = normal_glue_order; i <= filll_glue_order; i++) {
        lmt_packaging_state.total_stretch[i] = 0;
        lmt_packaging_state.total_shrink[i] = 0;
    }
    while (p) {
        /*tex

            Examine node |p| in the vlist, taking account of its effect on the dimensions of the
            new box; then advance |p| to the next node.

        */
        halfword n = node_next(p);
        switch (node_type(p)) {
            case hlist_node:
            case vlist_node:
                {
                    /*tex

                        Incorporate box dimensions into the dimensions of the vbox that will
                        contain it.

                    */
                    scaled shift = box_shift_amount(p);
                    scaledwhd whd = tex_pack_dimensions(p);
                    if (whd.wd + shift > width) {
                        width = whd.wd + shift;
                    }
                    height += depth + whd.ht;
                    depth = whd.dp;
                    tex_aux_promote_pre_migrated(box, p);
                    tex_aux_promote_post_migrated(box, p);
                }
                break;
            case unset_node:
                height += depth + box_height(p);
                depth = box_depth(p);
                if (box_width(p) > width) {
                    width = box_width(p);
                }
                /* No promotions here. */
                break;
            case rule_node:
                height += depth + rule_height(p);
                depth = rule_depth(p);
                if (rule_width(p) > width) {
                    width = rule_width(p);
                }
                break;
            case glue_node:
                /*tex Incorporate glue into the vertical totals. */
                height += depth + glue_amount(p);
                depth = 0;
                lmt_packaging_state.total_stretch[glue_stretch_order(p)] += glue_stretch(p);
                lmt_packaging_state.total_shrink[glue_shrink_order(p)] += glue_shrink(p);
                if (is_leader(p)) {
                    halfword gl = glue_leader_ptr(p);
                    scaled wd = 0;
                    switch (node_type(gl)) {
                        case hlist_node:
                        case vlist_node:
                            wd = box_width(gl);
                            break;
                        case rule_node:
                            wd = rule_width(gl);
                            break;
                    }
                    if (wd > width) {
                        width = wd;
                    }
                    if (node_subtype(p) == u_leaders) {
                        has_uleader = 1;
                    }
                }
                if (! has_limit && tex_has_glue_option(p, glue_option_limit)) {
                    has_limit = 1;
                }
                break;
            case kern_node:
                height += depth + kern_amount(p);
                depth = 0;
                break;
            case insert_node:
                if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_insert)) {
                    halfword l = insert_list(p);
                    tex_aux_post_migrate(box, p);
                    while (l) {
                        l = node_type(l) == insert_node ? tex_aux_post_migrate(box, l) : node_next(l);
                    }
                }
                break;
            case mark_node:
                 if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_mark)) {
                    tex_aux_post_migrate(box, p);
                 }
                 break;
            case glyph_node:
                tex_confusion("glyph in vpack");
                break;
            case disc_node:
                tex_confusion("discretionary in vpack");
                break;
            default:
                break;
        }
        p = n;
    }
    box_width(box) = width;
    if (depth > targetdepth) {
        height += depth - targetdepth;
        box_depth(box) = targetdepth;
    } else {
        box_depth(box) = depth;
    }
    /*tex

        Determine the value of |height(r)| and the appropriate glue setting; then |return| or |goto
        common_ending|. When we get to the present part of the program, |x| is the natural height of
        the box being packaged.
    */
    if (m == packing_additional) {
        targetheight += height;
    }
    box_height(box) = targetheight;
    {
        scaled targetexcess = targetheight - height;
        /*tex Now |x| is the excess to be made up. */
        if (excess) { 
            *excess = targetexcess; 
        }
        if (targetexcess == 0) {
            box_glue_sign(box) = normal_glue_sign;
            box_glue_order(box) = normal_glue_order;
            box_glue_set(box) = 0.0;
         // goto EXIT;
        } else if (targetexcess > 0) {
            /*tex Determine vertical glue stretch setting, then |return| or |goto common_ending|. */
            halfword order = tex_aux_used_order(lmt_packaging_state.total_stretch);
            box_glue_order(box) = order;
            box_glue_sign(box) = stretching_glue_sign;
            if (lmt_packaging_state.total_stretch[order] != 0) {
                box_glue_set(box) = (glueratio) ((double) targetexcess / lmt_packaging_state.total_stretch[order]);
            } else {
                /*tex There's nothing to stretch. */
                box_glue_sign(box) = normal_glue_sign;
                box_glue_set(box) = 0.0;
            }
            if (order == normal_glue_order && box_list(box)) {
                /*tex Report an underfull vbox and |goto common_ending|, if this box is sufficiently bad. */
                lmt_packaging_state.last_badness = tex_badness(targetexcess, lmt_packaging_state.total_stretch[normal_glue_order]);
                if (lmt_packaging_state.last_badness > vbadness_par) {
                    int callback_id = lmt_callback_defined(vpack_quality_callback);
                    if (callback_id > 0) {
                        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "SdNddS->",
                            lmt_packaging_state.last_badness > 100 ? "underfull" : "loose",
                            lmt_packaging_state.last_badness,
                            box,
                            abs(lmt_packaging_state.pack_begin_line),
                            lmt_input_state.input_line,
                            tex_current_input_file_name()
                        );
                     // goto EXIT;
                    } else {
                        tex_print_nlp();
                        if (lmt_packaging_state.last_badness > 100) {
                            tex_print_format("%l[package: underfull \\vbox (badness %i)", lmt_packaging_state.last_badness);
                        } else {
                            tex_print_format("%l[package: loose \\vbox (badness %i)", lmt_packaging_state.last_badness);
                        }
                        goto COMMON_ENDING;
                    }
                }
            }
         // goto EXIT;
        } else {
            /*tex Determine vertical glue shrink setting, then |return| or |goto common_ending|. */
            halfword order = tex_aux_used_order(lmt_packaging_state.total_shrink);
            box_glue_order(box) = order;
            box_glue_sign(box) = shrinking_glue_sign;
            if (lmt_packaging_state.total_shrink[order] != 0) {
                box_glue_set(box) = (glueratio) ((double) (-targetexcess) / lmt_packaging_state.total_shrink[order]);
            } else {
                /*tex There's nothing to shrink. */
                box_glue_sign(box) = normal_glue_sign;
                box_glue_set(box) = 0.0;
            }
            if (order == normal_glue_order && box_list(box)) {
                if (lmt_packaging_state.total_shrink[order] < -targetexcess) {
                    int overshoot = -targetexcess - lmt_packaging_state.total_shrink[normal_glue_order];
                    lmt_packaging_state.last_badness = scaling_factor_squared;
                    lmt_packaging_state.last_overshoot = overshoot;
                    /*tex Use the maximum shrinkage */
                    box_glue_set(box)  = 1.0;
                    /*tex Report an overfull vbox and |goto common_ending|, if this box is sufficiently bad. */
                    if ((overshoot > vfuzz_par) || (vbadness_par < 100)) {
                        int callback_id = lmt_callback_defined(vpack_quality_callback);
                        if (callback_id > 0) {
                            lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "SdNddS->",
                                "overfull",
                                overshoot,
                                box,
                                abs(lmt_packaging_state.pack_begin_line),
                                lmt_input_state.input_line,
                                tex_current_input_file_name()
                            );
                         // goto EXIT;
                        } else {
                            tex_print_nlp();
                            tex_print_format("%l[package: overfull \\vbox (%p too high)", - targetexcess - lmt_packaging_state.total_shrink[normal_glue_order]);
                            goto COMMON_ENDING;
                        }
                    }
                } else {
                    /*tex Report a tight vbox and |goto common_ending|, if this box is sufficiently bad. */
                    lmt_packaging_state.last_badness = tex_badness(-targetexcess, lmt_packaging_state.total_shrink[normal_glue_order]);
                    if (lmt_packaging_state.last_badness > vbadness_par) {
                        int callback_id = lmt_callback_defined(vpack_quality_callback);
                        if (callback_id > 0) {
                            lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "SdNddS->",
                                "tight",
                                lmt_packaging_state.last_badness,
                                box,
                                abs(lmt_packaging_state.pack_begin_line),
                                lmt_input_state.input_line,
                                tex_current_input_file_name()
                            );
                         // goto EXIT;
                        } else {
                            tex_print_nlp();
                            tex_print_format("%l[package: tight \\vbox (badness %i)", lmt_packaging_state.last_badness);
                            goto COMMON_ENDING;
                        }
                    }
                }
            }
         // goto EXIT;
        }
    }
    goto EXIT;
  COMMON_ENDING:
    /*tex Finish issuing a diagnostic message or an overfull or underfull vbox. */
    if (lmt_page_builder_state.output_active) {
        tex_print_format(" has occurred while \\output is active]");
    } else if (lmt_packaging_state.pack_begin_line != 0) {
        tex_print_format(" in alignment at lines %i--%i]", abs(lmt_packaging_state.pack_begin_line), lmt_input_state.input_line);
    } else {
        tex_print_format(" detected at line %i]", lmt_input_state.input_line);
    }
    tex_print_ln();
    tex_begin_diagnostic();
    tex_show_box(box);
    tex_end_diagnostic();
  EXIT:
    if (has_uleader) { 
        set_box_package_state(box, package_u_leader_found);
    }
    if (has_limit > 0) {
        tex_limit(box);
    }
    /*tex Further (experimental) actions can go here. */
    return box;
}

halfword tex_filtered_vpack(halfword p, scaled h, int m, scaled maxdepth, int grp, halfword direction, int just_pack, halfword attr, int state, int retain, int *excess)
{
    halfword result = p;
    if (! just_pack) {
        /* We have to do it here because we cannot nest packaging! */
        if (result && normalize_line_mode_option(flatten_h_leaders_mode)) { 
            halfword c = result; 
            while (c) {
                switch (node_type(c)) {
                    case hlist_node:
                    case vlist_node:
                        if (has_box_package_state(c, package_u_leader_found) && ! is_box_package_state(state, package_u_leader_delayed)) {
                            tex_flatten_leaders(c, grp, just_pack, "before vpack", 0);
                        }
                        break;
                }
                c = node_next(c);
            }
        }
        result = lmt_vpack_filter_callback(result, h, m, maxdepth, grp, direction, attr);
    }
    result = tex_vpack(result, h, m, maxdepth, (singleword) checked_direction_value(direction), retain, excess);
    if (result && normalize_par_mode_option(flatten_v_leaders_mode) && ! is_box_package_state(state, package_u_leader_delayed)) {
        tex_flatten_leaders(result, grp, just_pack, "after vpack", 0);
    }
    if (! just_pack) {
        result = lmt_packed_vbox_filter_callback(result, grp);
    }
    return result;
}

static scaled tex_aux_first_height(halfword boxnode) 
{
    halfword list = box_list(boxnode);
    if (list) {
        switch (node_type(list)) {
            case hlist_node:
            case vlist_node:
                return box_height(list);
            case rule_node:
                return rule_height(list);
        }
    }
    return 0;
}

static void tex_aux_set_vnature(halfword boxnode, int nature)
{
    switch (nature) { 
        case vtop_code: 
        case tsplit_code: 
            {
                /*tex

                    Read just the height and depth of |boxnode| (|boxnode|), for |\vtop|. The height of
                    a |\vtop| box is inherited from the first item on its list, if that item is an
                    |hlist_node|, |vlist_node|, or |rule_node|; otherwise the |\vtop| height is zero.

                */
                scaled height = tex_aux_first_height(boxnode);
                box_depth(boxnode) = box_total(boxnode) - height;
                box_height(boxnode) = height;
                box_package_state(boxnode) = vtop_package_state;
            }
            break;
        case vbox_code: 
        case vsplit_code: 
            box_package_state(boxnode) = vbox_package_state;
            break;
        case dbox_code: 
        case dsplit_code: 
            box_package_state(boxnode) = dbox_package_state;
            break;
    }
}


/*tex
    Here we always start out in l2r mode and without shift. After all we need to be compatible with
    how it was before.
*/

void tex_run_vcenter(void)
{
    tex_aux_scan_full_spec(direct_box_flag, vcenter_group, direction_l2r, 0, 0, -1, 0, 0);
    tex_normal_paragraph(vcenter_par_context);
    tex_push_nest();
    cur_list.mode = internal_vmode;
    cur_list.prev_depth = ignore_depth_criterion_par;
    if (every_vbox_par) {
        tex_begin_token_list(every_vbox_par, every_vbox_text);
    }
}

void tex_finish_vcenter_group(void)
{
    if (! tex_wrapped_up_paragraph(vcenter_par_context, 1)) {
        halfword p;
        tex_end_paragraph(vcenter_group, vcenter_par_context);
        tex_package(vbox_code); /* todo: vcenter_code */
        p = tex_pop_tail();
        if (p) {
            switch (node_type(p)) {
                case vlist_node:
                    {
                        scaled delta = box_total(p);
                        box_height(p) = tex_half_scaled(delta);
                        box_depth(p) = delta - box_height(p);
                        break;
                    }
                case simple_noad:
                    node_subtype(p) = vcenter_noad_subtype;
                    break;
                /*
                case style_node:
                    break;
                */
            }
            tex_tail_append(p);
        }
    }
}

void tex_package(singleword nature)
{
    int grp = cur_group;
    scaled maxdepth = box_max_depth_par;
    tex_unsave();
    {
        lmt_save_state.save_stack_data.ptr -= saved_box_n_of_records;
        halfword boxnode = null; /*tex Aka |cur_box|. */
        /*tex 
            We need to save some over the callback because it can do something that messes with 
            the stack entries that has already been decremented. 
        */
        halfword slot = saved_box_slot;
        halfword context = saved_box_context;
        halfword dirptr = saved_box_dir_pointer;
        halfword orientation = saved_box_orientation;
        halfword anchor = saved_box_anchor;
        halfword geometry = saved_box_geometry;
        halfword attrlist = saved_box_attr_list;
        halfword state = saved_box_state;
        scaled shift = saved_box_shift;
        halfword source = saved_box_source;
        halfword target = saved_box_target;
        halfword axis = saved_box_axis;
        halfword mainclass = saved_box_class;
        halfword callback = saved_box_callback;
        halfword leaders = saved_box_leaders;
        halfword options = saved_box_options;
        scaled xoffset = saved_box_xoffset;
        scaled yoffset = saved_box_yoffset;
        scaled xmove = saved_box_xmove;
        scaled ymove = saved_box_ymove;
        if (cur_list.mode == restricted_hmode) {
            boxnode = tex_filtered_hpack(
                cur_list.head, cur_list.tail, 
                saved_box_amount, saved_box_packing, grp, 
                saved_box_direction, saved_box_pack, attrlist, state, saved_box_retain
            );
            node_subtype(boxnode) = hbox_list;
            if (options & saved_box_reverse_option) {
                box_list(boxnode) = tex_reversed_node_list(box_list(boxnode));
            }
            box_package_state(boxnode) = hbox_package_state;
        } else {
            boxnode = tex_filtered_vpack(
                node_next(cur_list.head), 
                saved_box_amount, saved_box_packing, maxdepth, grp, 
                saved_box_direction, saved_box_pack, attrlist, state, saved_box_retain, 
                NULL
            );
            box_package_state(boxnode) = hbox_package_state;
            tex_aux_set_vnature(boxnode, nature);
        }
        if (options & saved_box_limit_option && box_list(boxnode)) {
            tex_limit(boxnode);
        }
        if (dirptr) {
            /*tex Adjust back |text_dir_ptr| for |scan_spec| */
            tex_flush_node_list(lmt_dir_state.text_dir_ptr);
            lmt_dir_state.text_dir_ptr = dirptr;
        }
        /*
            An attribute is not assigned beforehand, just passed. But, when some is assigned we need 
            to retain it. So, how do we deal with attributes that are added? Maybe we have to merge
            changes? Or maybe an extra option in hpack ... some day.
        */
        tex_attach_attribute_list_attribute(boxnode, attrlist);
        delete_attribute_reference(attrlist);
        /* */
        if (tex_has_geometry(geometry, offset_geometry) || tex_has_geometry(geometry, orientation_geometry)) {
            scaled wd = box_width(boxnode);
            scaled ht = box_height(boxnode);
            scaled dp = box_depth(boxnode);
            if (xmove) {
                xoffset = tex_aux_checked_dimension1(xoffset + xmove);
                wd = tex_aux_checked_dimension2(wd + xmove);
            }
            if (ymove) {
                yoffset = tex_aux_checked_dimension1(yoffset + ymove);
                ht = tex_aux_checked_dimension2(ht + ymove);
                dp = tex_aux_checked_dimension2(dp - ymove);
            }
            box_w_offset(boxnode) = wd;
            box_h_offset(boxnode) = ht;
            box_d_offset(boxnode) = dp;
            switch (orientationonly(orientation)) {
                case 0 : /*   0 */
                    break;
                case 2 : /* 180 */
                    box_height(boxnode) = dp;
                    box_depth(boxnode) = ht;
                    geometry |= orientation_geometry;
                    break;
                case 1 : /*  90 */
                case 3 : /* 270 */
                    box_width(boxnode) = ht + dp;
                    box_height(boxnode) = wd;
                    box_depth(boxnode) = 0;
                    geometry |= orientation_geometry;
                    break;
                case 4 : /*   0 */
                    box_height(boxnode) = ht + dp;
                    box_depth(boxnode) = 0;
                    geometry |= orientation_geometry;
                    break;
                case 5 : /* 180 */
                    box_height(boxnode) = 0;
                    box_depth(boxnode) = ht + dp;
                    geometry |= orientation_geometry;
                    break;
                default :
                    break;
            }
            if (xoffset || yoffset) {
                box_x_offset(boxnode) = xoffset;
                box_y_offset(boxnode) = yoffset;
                geometry |= offset_geometry;
            }
        }
        if (source || target) {
            box_source_anchor(boxnode) = source;
            box_target_anchor(boxnode) = target;
            geometry |= anchor_geometry;
        }
        box_anchor(boxnode) = anchor;
        box_orientation(boxnode) = orientation;
        box_geometry(boxnode) = (singleword) geometry;
        if (options & saved_box_container_option) {
            node_subtype(boxnode) = container_list;
        } else if (options & saved_box_mathtext_option) {
            node_subtype(boxnode) = math_text_list;
        }
        box_axis(boxnode) = (singleword) axis;
        box_package_state(boxnode) |= (singleword) state;
        tex_pop_nest();
        tex_box_end(context, boxnode, shift, mainclass, slot, callback, leaders);
    }
}

static int local_box_mapping[] = { 
    [local_left_box_box_code  ] = local_left_box_code,
    [local_right_box_box_code ] = local_right_box_code,
    [local_middle_box_box_code] = local_middle_box_code
};

void tex_run_unpackage(void)
{
    int code = cur_chr; /*tex should we copy? */
    switch (code) {
        case box_code:
        case copy_code:
        case unpack_code:
            {
                halfword index = tex_scan_box_register_number();
                halfword box = box_register(index);
                if (box) {
                    int bad = 0;
                    switch (cur_list.mode) {
                        case vmode: 
                        case internal_vmode: 
                            if (node_type(box) != vlist_node) { 
                                bad = 1;
                            }
                            break;
                        case hmode: 
                        case restricted_hmode: 
                            if (node_type(box) != hlist_node) { 
                                bad = 1;
                            }
                            break;
                        case mmode: 
                        case inline_mmode: 
                            bad = 1;
                            break;
                    }
                    if (bad) {
                        tex_handle_error(
                            normal_error_type,
                            "Incompatible list can't be unboxed",
                            "Sorry, Pandora. (You sneaky devil.) I refuse to unbox an \\hbox in vertical mode\n"
                            "or vice versa. And I can't open any boxes in math mode."
                        );
                    } else {
                        /*tex 
                            We go via variables because we do varmem assignments. Probably this is 
                            not needed.
                        */
                        halfword tail = cur_list.tail;
                        halfword list = box_list(box);
                        halfword pre_migrated  = code == unpack_code ? null : box_pre_migrated(box);
                        halfword post_migrated = code == unpack_code ? null : box_post_migrated(box);
                        /* probably overkill as we inject vadjust again, maybe it should be an option, 'bind' or so */
                        halfword pre_adjusted  = code == unpack_code ? null : box_pre_adjusted(box);
                        halfword post_adjusted = code == unpack_code ? null : box_post_adjusted(box);
                        int prunekerns = list && node_type(box) == hlist_node && normalize_line_mode_option(remove_margin_kerns_mode);
                        /*tex 
                            This topskip move is an ugly catch for wrong usage: when messing with 
                            vboxes the migrated material can end up outside the unvboxed (pagebody)
                            content which is not what one wants. The way to prevent is to force 
                            hmode when unboxing. It makes no sense to complicate this mechanism 
                            even more by soem fragile hackery. Best just create what gets asked 
                            and remember that thsi was decided. We need to copy the list earlier 
                            when we do this! 
                        */
                        /*
                        if (list) { 
                            if (code == copy_code) {
                                list = tex_copy_node_list(list, null);
                            } else {
                                box_list(box) = null;
                            }     
                        }
                        {
                            int movetopskip = list && (pre_adjusted || pre_migrated) && node_type(list) == glue_node && node_subtype(list) == top_skip_glue;
                            if (movetopskip) {
                                halfword topskip = list; 
                                list = node_next(list);
                                node_prev(topskip) = null;
                                node_next(topskip) = null;
                                tex_try_couple_nodes(tail, topskip);
                                tail = topskip;
                                if (list) { 
                                    node_prev(list) = null;
                                }
                                if (pre_adjusted && tracing_adjusts_par > 1) {
                                    tex_begin_diagnostic();
                                    tex_print_format("[adjust: topskip moved]");
                                    tex_end_diagnostic();
                                }
                            }
                        }
                        */ 
                        if (pre_adjusted) {
                            if (code == copy_code) {
                                pre_adjusted  = tex_copy_node_list(pre_adjusted, null);
                            } else {
                                box_pre_adjusted(box) = null;
                            }
                            tail = tex_flush_adjust_prepend(pre_adjusted, tail);
                        }
                        if (pre_migrated) {
                            if (code == copy_code) {
                                pre_migrated  = tex_copy_node_list(pre_migrated, null);
                            } else {
                                box_pre_migrated(box) = null;
                            }
                            tex_try_couple_nodes(tail, pre_migrated);
                            tail = tex_tail_of_node_list(pre_migrated);
                        }
                        if (list) {
                            if (code == copy_code) {
                                list = tex_copy_node_list(list, null);
                            } else {
                                box_list(box) = null;
                            }     
                            tex_try_couple_nodes(tail, list);
                            tail = tex_tail_of_node_list(list);
                        }
                        if (post_migrated) {
                            if (code == copy_code) {
                                post_migrated = tex_copy_node_list(post_migrated, null);
                            } else {
                                box_post_migrated(box) = null;
                            }
                            tex_try_couple_nodes(tail, post_migrated);
                            tail = tex_tail_of_node_list(post_migrated);
                        }
                        if (post_adjusted) {
                            if (code == copy_code) {
                                post_adjusted = tex_copy_node_list(post_adjusted, null);
                            } else {
                                box_post_adjusted(box) = null;
                            }
                            tail = tex_flush_adjust_append(post_adjusted, tail);
                        }
                        if (code != copy_code) {
                            box_register(index) = null;
                            tex_flush_node(box);
                        }
                        cur_list.tail = prunekerns ? tex_wipe_margin_kerns(cur_list.head) : tex_tail_of_node_list(tail);
                    }
                }
                break;
            }
        case page_discards_code:
            {
                tex_try_couple_nodes(cur_list.tail, lmt_packaging_state.page_discards_head);
                cur_list.tail = tex_tail_of_node_list(cur_list.tail);
                lmt_packaging_state.page_discards_head = null;
                break;
            }
        case split_discards_code:
            {
                tex_try_couple_nodes(cur_list.tail, lmt_packaging_state.split_discards_head);
                cur_list.tail = tex_tail_of_node_list(cur_list.tail);
                lmt_packaging_state.split_discards_head = null;
                break;
            }
        case insert_box_code:
        case insert_copy_code:
            {
                /*
                    This one is sensitive for messing with callbacks. Somehow attributes and the if
                    stack ifs can get corrupted but I have no clue yet how that happens but temp
                    nodes have the same size so ...
                */
                halfword index = tex_scan_integer(0, NULL);
                if (tex_valid_insert_id(index)) {
                    halfword boxnode = tex_get_insert_content(index); /* also checks for id */
                    if (boxnode) {
                        if (! is_v_mode(cur_list.mode)) {
                            tex_handle_error(
                                normal_error_type,
                                "Unpacking an inserts can only happen in vertical mode.",
                                NULL
                            );
                        } else if (node_type(boxnode) == vlist_node) {
                            if (code == insert_copy_code) {
                                boxnode = tex_copy_node(boxnode);
                            } else {
                                tex_set_insert_content(index, null);
                            }
                            if (boxnode) {
                                halfword list = box_list(boxnode);
                                if (list) {
                                    tex_try_couple_nodes(cur_list.tail, list);
                                    cur_list.tail = tex_tail_of_node_list(list);
                                    box_list(boxnode) = null;
                                }
                                tex_flush_node(boxnode);
                            }
                        } else {
                            /* error, maybe migration list  */
                        }
                    }
                }
                break;
            }
        case local_left_box_box_code:
        case local_right_box_box_code:
        case local_middle_box_box_code:
            {
                tex_try_couple_nodes(cur_list.tail, tex_get_local_boxes(local_box_mapping[code]));
                cur_list.tail = tex_tail_of_node_list(cur_list.tail);
                break;
            }
        default:
            {
                tex_confusion("weird unpackage");
                break;
            }
    }
}

/*tex

    When a box is being appended to the current vertical list, the baselineskip calculation is
    handled by the |append_to_vlist| routine.

    Todo: maybe store some more in lines, so that we can get more consistent spacing (for instance
    the |baseline_skip_par| and |prev_depth_par| are now pars and not values frozen with the line.
    But as usual we can expect side effects so \unknown

*/

static halfword tex_aux_depth_correction(halfword b, const line_break_properties *properties)
{
    /*tex The deficiency of space between baselines: */
    halfword p;
    halfword height = has_box_package_state(b, dbox_package_state) ? tex_aux_first_height(b) : box_height(b);
    halfword depth = cur_list.prev_depth;
    if (properties) {
        scaled d = glue_amount(properties->baseline_skip) - depth - height;
        if (d < properties->line_skip_limit) {
            p = tex_new_glue_node(properties->line_skip, line_skip_glue);
        } else {
            p = tex_new_glue_node(properties->baseline_skip, baseline_skip_glue);
            glue_amount(p) = d;
        }
    } else {
        scaled d = glue_amount(baseline_skip_par) - depth - height;
        if (d < line_skip_limit_par) {
            p = tex_new_param_glue_node(line_skip_code, line_skip_glue);
        } else {
            p = tex_new_param_glue_node(baseline_skip_code, baseline_skip_glue);
            glue_amount(p) = d; /* we keep the stretch and shrink */
        }
    }
    return p;
}

void tex_append_to_vlist(halfword b, int location, const line_break_properties *properties)
{
    if (location >= 0) { 
        halfword result = null;
        halfword next_depth = ignore_depth_criterion_par;
        int prev_set = 0;
        int check_depth = 0;
        if (lmt_append_to_vlist_callback(b, location, cur_list.prev_depth, &result, &next_depth, &prev_set, &check_depth)) {
            if (prev_set) {
                cur_list.prev_depth = next_depth;
            }
            if (check_depth && result && (cur_list.prev_depth > ignore_depth_criterion_par)) {
                /*tex
                    We only deal with a few types and one can always at the \LUA\ end check for some of
                    these and decide not to apply the correction.
                */
                switch (node_type(result)) {
                    case hlist_node:
                    case vlist_node:
                    case rule_node:
                        {
                            halfword glue = tex_aux_depth_correction(result, properties);
                            tex_tail_append(glue);
                            break;
                        }
                }
            }
            if (result) { 
                tex_tail_append_list(result);
            }
            return;
        }
    }
    if (cur_list.prev_depth > ignore_depth_criterion_par) {
        halfword glue = tex_aux_depth_correction(b, properties);
        tex_tail_append(glue);
    }
    tex_tail_append(b);
    cur_list.prev_depth = box_depth(b);
}

/*tex

    When |saving_vdiscards| is positive then the glue, kern, and penalty nodes removed by the page
    builder or by |\vsplit| from the top of a vertical list are saved in special lists instead of
    being discarded.

    The |vsplit| procedure, which implements \TEX's |\vsplit| operation, is considerably simpler
    than |line_break| because it doesn't have to worry about hyphenation, and because its mission
    is to discover a single break instead of an optimum sequence of breakpoints. But before we get
    into the details of |vsplit|, we need to consider a few more basic things.

    A subroutine called |prune_page_top| takes a pointer to a vlist and returns a pointer to a
    modified vlist in which all glue, kern, and penalty nodes have been deleted before the first
    box or rule node. However, the first box or rule is actually preceded by a newly created glue
    node designed so that the topmost baseline will be at distance |split_top_skip| from the top,
    whenever this is possible without backspacing.

    When the second argument |s| is |false| the deleted nodes are destroyed, otherwise they are
    collected in a list starting at |split_discards|.

    Are the prev pointers okay here?

*/

halfword tex_prune_page_top(halfword p, int s)
{
    /*tex Lags one step behind |p|. */
    halfword prev_p = temp_head;
    halfword r = null;
    node_next(temp_head) = p;
    while (p) {
        switch (node_type(p)) {
            case hlist_node:
            case vlist_node:
            case rule_node:
                {
                    /*tex Insert glue for |split_top_skip| and set |p| to |null|. */
                    halfword h = node_type(p) == rule_node ? rule_height(p) : box_height(p);
                    halfword q = tex_new_param_glue_node(split_top_skip_code, split_top_skip_glue);
                 // node_next(prev_p) = q; 
                    tex_couple_nodes(prev_p, q); /* there is no real need to point back to temp */
                    tex_couple_nodes(q, p);
                    glue_amount(q) = glue_amount(q) > h ? glue_amount(q) - h : 0;
                    p = null;
                }
                break;
            case boundary_node:
                /* shouldn't we discard */
            case whatsit_node:
            case mark_node:
            case insert_node:
                prev_p = p;
                p = node_next(prev_p);
                break;
            case glue_node:
            case kern_node:
            case penalty_node:
                {
                    halfword q = p;
                    p = node_next(q);
                    node_next(q) = null;
                    node_next(prev_p) = p;
                    if (s) {
                        if (lmt_packaging_state.split_discards_head) {
                            node_next(r) = q;
                        } else {
                            lmt_packaging_state.split_discards_head = q;
                        }
                        r = q;
                    } else {
                        tex_flush_node_list(q);
                    }
                }
                break;
            default:
                tex_confusion("pruning page top");
                break;
        }
    }
    return node_next(temp_head);
}

/*tex

    The next subroutine finds the best place to break a given vertical list so as to obtain a box
    of height~|h|, with maximum depth~|d|. A pointer to the beginning of the vertical list is given,
    and a pointer to the optimum breakpoint is returned. The list is effectively followed by a
    forced break, i.e., a penalty node with the |eject_penalty|; if the best break occurs at this
    artificial node, the value |null| is returned.

    An array of six |scaled| distances is used to keep track of the height from the beginning of
    the list to the current place, just as in |line_break|. In fact, we use one of the same arrays,
    only changing its name to reflect its new significance.

    The distance from first active node to |cur_p| is stored in |active_height|.

    A global variable |best_height_plus_depth| will be set to the natural size of the box (without
    stretching or shrinking) that corresponds to the optimum breakpoint found by |vert_break|. This
    value is used by the insertion splitting algorithm of the page builder.

    \starttyping
    scaled best_height_plus_depth;
    \stoptyping

 */

static halfword tex_aux_vert_badness(scaled goal, scaled active_height[])
{
    if (active_height[total_advance_amount] < goal) {
        if (active_height[total_fi_amount] || active_height[total_fil_amount] || active_height[total_fill_amount] || active_height[total_filll_amount]) {
            return 0;
        } else {
            return tex_badness(goal - active_height[total_advance_amount], active_height[total_stretch_amount]);
        }
    } else if (active_height[total_advance_amount] - goal > active_height[total_shrink_amount]) {
        return awful_bad;
    } else {
        return tex_badness(active_height[total_advance_amount] - goal, active_height[total_shrink_amount]);
    }
}

static halfword tex_aux_vert_costs(halfword badness, halfword penalty)
{
    if (badness >= awful_bad) {
        return badness; 
    } else if (penalty <= eject_penalty) {
        return penalty;
    } else if (badness < infinite_bad) {
        return badness + penalty;
    } else {
        return deplorable;
    }
}

halfword tex_vert_break(halfword current, scaled height, scaled depth)
{
    /*tex
        If |p| is a glue node, |type(prev_p)| determines whether |p| is a legal breakpoint, an
        initial glue node is not a legal breakpoint.
    */
    halfword previous = current;
    /*tex The to be checked penalty value: */
    halfword penalty = 0;
    /*tex The smallest badness plus penalties found so far: */
    halfword least_cost = awful_bad;
    /*tex The most recent break that leads to |least_cost|: */
    halfword best_place = null;
    /*tex The depth of previous box in the list: */
    scaled previous_depth = 0;
    /*tex The various glue components: */
    scaled active_height[10] = { 0 };
    while (1) {
        /*tex
            If node |p| is a legal breakpoint, check if this break is the best known, and |goto
            done| if |p| is null or if the page-so-far is already too full to accept more stuff.

            A subtle point to be noted here is that the maximum depth~|d| might be negative, so
            |cur_height| and |prev_dp| might need to be corrected even after a glue or kern node.
        */
        if (current) {
            /*tex
                Use node |p| to update the current height and depth measurements; if this node is
                not a legal breakpoint, |goto not_found| or |update_heights|, otherwise set |pi|
                to the associated penalty at the break.
            */
            switch (node_type(current)) {
                case hlist_node:
                case vlist_node:
                    /*tex
                        If we do this we also need to subtract the dimensions and bubble it up. But
                        at least we could inline the inserts.
                    */
                    /*
                    if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_post)) {
                        // same code as in page builder
                    }
                    if (auto_migrating_mode_permitted(auto_migration_mode_par, auto_migrate_pre)) {
                        // same code as in page builder
                        continue;
                    }
                    */
                    active_height[total_advance_amount] += previous_depth + box_height(current);
                    previous_depth = box_depth(current);
                    goto NOT_FOUND;
                case rule_node:
                    active_height[total_advance_amount] += previous_depth + rule_height(current);
                    previous_depth = rule_depth(current);
                    goto NOT_FOUND;
                case boundary_node:
                case whatsit_node:
                    goto NOT_FOUND;
                case glue_node:
                    if (precedes_break(previous)) {
                        penalty = 0;
                        break;
                    } else {
                        goto UPDATE_HEIGHTS;
                    }
                case kern_node:
                    if (node_next(current) && node_type(node_next(current)) == glue_node) {
                        penalty = 0;
                        break;
                    } else {
                        goto UPDATE_HEIGHTS;
                    }
                case penalty_node:
                    penalty = penalty_amount(current);
                    /* option: penalty = 0; */
                    break;
                case mark_node:
                case insert_node:
                    goto NOT_FOUND;
                default:
                    tex_confusion("vertical break");
                    break;
            }
        } else {
            penalty = eject_penalty;
        }
        /*tex
            Check if node |p| is a new champion breakpoint; then |goto done| if |p| is a forced
            break or if the page-so-far is already too full.
        */
        if (penalty < infinite_penalty) {
            /*tex Compute the badness, |b|, using |awful_bad| if the box is too full. */
            int badness = tex_aux_vert_badness(height, active_height);
            int costs = tex_aux_vert_costs(badness, penalty);
            if (costs <= least_cost) {
                best_place = current;
                least_cost = costs;
                lmt_packaging_state.best_height_plus_depth = active_height[total_advance_amount] + previous_depth;
                /*tex 
                    Here's a patch suggested by DEK related to glue in inserts that needs to be taken 
                    into account. That patch is not applied to regular \TEX\ for compatibility reasons.
                */
                if (lmt_packaging_state.best_height_plus_depth > (height + previous_depth) && costs < awful_bad) { 
                    lmt_packaging_state.best_height_plus_depth = height + previous_depth;
                }
            }
            if ((costs == awful_bad) || (penalty <= eject_penalty)) {
                return best_place;
            }
        }
      UPDATE_HEIGHTS:
        /*tex
            Update the current height and depth measurements with respect to a glue or kern node~|p|.
            Vertical lists that are subject to the |vert_break| procedure should not contain infinite
            shrinkability, since that would permit any amount of information to fit on one page. We 
            only end up here for glue and kern nodes.
        */
        switch(node_type(current)) {
            case kern_node:
                active_height[total_advance_amount] += previous_depth + kern_amount(current);
                previous_depth = 0;
                goto KEEP_GOING; /* We assume a positive depth. */
            case glue_node:
                active_height[total_stretch_amount + glue_stretch_order(current)] += glue_stretch(current);
                active_height[total_shrink_amount] += glue_shrink(current);
                if (glue_shrink_order(current) != normal_glue_order  && glue_shrink(current)) {
                    tex_handle_error(
                        normal_error_type,
                        "Infinite glue shrinkage found in box being split",
                        "The box you are \\vsplitting contains some infinitely shrinkable glue, e.g.,\n"
                        "'\\vss' or '\\vskip 0pt minus 1fil'. Such glue doesn't belong there; but you can\n"
                        "safely proceed, since the offensive shrinkability has been made finite."
                    );
                    glue_shrink_order(current) = normal_glue_order;
                }
                active_height[total_advance_amount] += previous_depth+ glue_amount(current);
                previous_depth = 0;
                goto KEEP_GOING; /* We assume a positive depth. */
        }
      NOT_FOUND:
        if (previous_depth > depth) {
            active_height[total_advance_amount] += previous_depth - depth;
            previous_depth = depth;
        }
      KEEP_GOING:
        previous = current;
        current = node_next(previous);
    }
    return best_place; /* This location is unreachable but some compilers like it this way. */
}

/*tex

    Now we are ready to consider |vsplit| itself. Most of its work is accomplished by the two
    subroutines that we have just considered.

    Given the number of a vlist box |n|, and given a desired page height |h|, the |vsplit|
    function finds the best initial segment of the vlist and returns a box for a page of height~|h|.
    The remainder of the vlist, if any, replaces the original box, after removing glue and penalties
    and adjusting for |split_top_skip|. Mark nodes in the split-off box are used to set the values
    of |split_first_mark| and |split_bot_mark|; we use the fact that |split_first_mark(x) = null| if
    and only if |split_bot_mark(x) = null|.

    The original box becomes \quote {void} if and only if it has been entirely extracted. The
    extracted box is \quote {void} if and only if the original box was void (or if it was,
    erroneously, an hlist box).

    Extract a page of height |h| from box |n|:
*/

halfword tex_vsplit(halfword n, scaled h, int m)
{
    /*tex the box to be split */
    halfword v = box_register(n);
    tex_flush_node_list(lmt_packaging_state.split_discards_head);
    lmt_packaging_state.split_discards_head = null;
    for (halfword i = 0; i <= lmt_mark_state.mark_data.ptr; i++) {
        tex_delete_mark(i, split_first_mark_code);
        tex_delete_mark(i, split_bot_mark_code);
    }
    /*tex Dispense with trivial cases of void or bad boxes. */
    if (! v) {
        return null;
    } else if (node_type(v) != vlist_node) {
        tex_handle_error(
            normal_error_type,
            "\\vsplit needs a \\vbox",
            "The box you are trying to split is an \\hbox. I can't split such a box, so I''ll\n"
            "leave it alone."
        );
        return null;
    } else {
        /*tex points to where the break occurs */
        halfword q = tex_vert_break(box_list(v), h, split_max_depth_par);
        /*tex

            Look at all the marks in nodes before the break, and set the final link to |null| at
            the break. It's possible that the box begins with a penalty node that is the quote
            {best} break, so we must be careful to handle this special case correctly.

        */
        halfword p = box_list(v);
        /*tex The direction of the box to be split, obsolete! */
        int vdir = box_dir(v);
        if (p == q) {
            box_list(v) = null;
        } else {
            while (1) {
                if (node_type(p) == mark_node) {
                    tex_update_split_mark(p);
                }
                if (node_next(p) == q) {
                    node_next(p) = null;
                    break;
                } else {
                    p = node_next(p);
                }
            }
        }
        q = tex_prune_page_top(q, saving_vdiscards_par > 0);
        p = box_list(v);
        box_list(v) = null;
        tex_flush_node(v);
        if (q) {
            box_register(n) = tex_filtered_vpack(q, 0, packing_additional, max_depth_par, split_keep_group, vdir, 0, 0, 0, holding_none_option, NULL);
        } else {
            /*tex The |eq_level| of the box stays the same. */
            box_register(n) = null;
        }
        return tex_filtered_vpack(p, m == packing_additional ? 0 : h, m, max_depth_par, split_off_group, vdir, 0, 0, 0, holding_none_option, NULL);
    }
}

/*tex

    Now that we can see what eventually happens to boxes, we can consider the first steps in their
    creation. The |begin_box| routine is called when |box_context| is a context specification,
    |cur_chr| specifies the type of box desired, and |cur_cmd=make_box|.

*/

void tex_begin_box(int boxcontext, scaled shift, halfword slot, halfword callback, halfword leaders)
{
    halfword code = cur_chr;
    halfword boxnode = null; /*tex Aka |cur_box|. */
    switch (code) {
        case box_code:
            {
                halfword n = tex_scan_box_register_number();
                boxnode = box_register(n);
                /*tex The box becomes void, at the same level. */
                box_register(n) = null;
                break;
            }
        case copy_code:
            {
                halfword n = tex_scan_box_register_number();
                boxnode = box_register(n) ? tex_copy_node(box_register(n)) : null;
                break;
            }
     /* case unpack_code: */
     /*     break;        */
         case last_box_code:
            /*tex
                If the current list ends with a box node, delete it from the list and make |boxnode|
                point to it; otherwise set |boxnode := null|.
            */
            boxnode = null;
            if (is_m_mode(cur_list.mode)) {
                tex_you_cant_error(
                    "Sorry; this \\lastbox will be void."
                );
            } else if (cur_list.mode == vmode && cur_list.head == cur_list.tail) {
                tex_you_cant_error(
                    "Sorry...I usually can't take things from the current page.\n"
                    "This \\lastbox will therefore be void."
                );
            } else if (cur_list.head != cur_list.tail) {
                switch (node_type(cur_list.tail)) {
                    case hlist_node:
                    case vlist_node:
                        {
                            /*tex Remove the last box */
                            halfword q = node_prev(cur_list.tail);
                            if (! q || node_next(q) != cur_list.tail) {
                                q = cur_list.head;
                                while (node_next(q) != cur_list.tail)
                                    q = node_next(q);
                            }
                            tex_uncouple_node(cur_list.tail);
                            boxnode = cur_list.tail;
                            box_shift_amount(boxnode) = 0;
                            cur_list.tail = q;
                            node_next(cur_list.tail) = null;
                        }
                        break;
                }
            }
            break;
        case tsplit_code:
        case vsplit_code:
        case dsplit_code:
            {
                /*tex
                    Split off part of a vertical box, make |boxnode| point to it. Here we deal with
                    things like |\vsplit 13 to 100pt|. Maybe todo: just split off one line.

                */
                halfword mode = packing_exactly ;
                halfword index = tex_scan_box_register_number();
                halfword size = 0;
                halfword attrlist = null;
                while (1) {
                    switch (tex_scan_character("atuATU", 0, 1, 0)) {
                        case 0:
                            goto DONE;
                        case 'a': case 'A':
                            if (tex_scan_mandate_keyword("attr", 1)) {
                                attrlist = tex_scan_attribute(attrlist);
                            }
                            break;
                        case 't': case 'T':
                            if (tex_scan_mandate_keyword("to", 1)) {
                                mode = packing_exactly ;
                                size = tex_scan_dimension(0, 0, 0, 0, NULL);
                            }
                            break;
                        case 'u': case 'U':
                            if (tex_scan_mandate_keyword("upto", 1)) {
                                mode = packing_additional;
                                size = tex_scan_dimension(0, 0, 0, 0, NULL);
                            }
                            break;
                        default:
                            tex_aux_show_keyword_error("attr|upto|to");
                            goto DONE;
                    }
                }
              DONE:
                boxnode = tex_vsplit(index, size, mode);
                tex_aux_set_vnature(boxnode, code);
                if (attrlist) { 
                    tex_attach_attribute_list_attribute(boxnode, attrlist);
                }
            }
            break;
        case insert_box_code:
        case insert_copy_code:
            {
                halfword index = tex_scan_integer(0, NULL);
                if (tex_valid_insert_id(index)) {
                    boxnode = tex_get_insert_content(index);
                    if (boxnode) {
                        if (node_type(boxnode) == vlist_node) {
                            if (code == insert_copy_code) {
                                boxnode = tex_copy_node(boxnode);
                            } else {
                                tex_set_insert_content(index, null);
                            }
                        } else {
                            tex_set_insert_content(index, null);
                            /* error, maybe migration list  */
                        }
                    }
                }
                break;
            }
        case local_left_box_box_code:
            {
                boxnode = tex_get_local_boxes(local_left_box_code);
                break;
            }
        case local_right_box_box_code:
            {
                boxnode = tex_get_local_boxes(local_right_box_code);
                break;
            }
        case local_middle_box_box_code:
            {
                boxnode = tex_get_local_boxes(local_middle_box_code);
                break;
            }
       /*tex

            Initiate the construction of an hbox or vbox, then |return|. Here is where we
            enter restricted horizontal mode or internal vertical mode, in order to make a
            box. The juggling with codes and addition or subtraction was somewhat messy.

        */
        default:
            {
                quarterword direction;
                int justpack = 0;
                quarterword group = vbox_group;
                int mode = vmode;
                int adjusted = 0;
                switch (cur_list.mode) {
                    case vmode:
                    case internal_vmode:
                        direction = dir_lefttoright;
                        if (boxcontext == direct_box_flag) {
                            adjusted = 1;
                        }
                        break;
                    case hmode:
                    case restricted_hmode:
                        direction = (singleword) text_direction_par;
                        break;
                    case mmode:
                    case inline_mmode:
                        direction = (singleword) math_direction_par;
                        break;
                    default: 
                        direction = direction_unknown;
                        break;
                }
                switch (code) {
                    case tpack_code:
                     // mode = vmode; 
                        justpack = 1;
                        group = vtop_group;
                        break;
                    case vpack_code:
                     // mode = vmode; 
                        justpack = 1;
                     // group = vbox_group;
                        break;
                    case hpack_code:
                        mode = hmode; 
                        justpack = 1;
                        group = adjusted ? adjusted_hbox_group : hbox_group;
                        break;
                    case dpack_code:
                     // mode = vmode; 
                        justpack = 1;
                        group = dbox_group;
                        break;
                    case vtop_code:
                     // mode = vmode;
                     // justpack = 0;
                        group = vtop_group;
                        break;
                    case vbox_code:
                     // mode = vmode;
                     // justpack = 0;
                     // group = vbox_group;
                        break;
                    case hbox_code:   
                        mode = hmode;
                     // justpack = 0;
                        group = adjusted ? adjusted_hbox_group : hbox_group;
                        break;
                    case dbox_code:
                     // mode = vmode;
                     // justpack = 0;
                        group = dbox_group;
                        break;
                }
                tex_aux_scan_full_spec(boxcontext, group, direction, justpack, shift, slot, callback, leaders);
                tex_normal_paragraph(vmode_par_context);
                tex_push_nest();
                update_tex_internal_dir_state(0);
                cur_list.mode = - mode;
                if (mode == vmode) {
                    cur_list.prev_depth = ignore_depth_criterion_par;
                    if (every_vbox_par) {
                        tex_begin_token_list(every_vbox_par, every_vbox_text);
                    }
                } else {
                    cur_list.space_factor = default_space_factor;
                    if (every_hbox_par) {
                        tex_begin_token_list(every_hbox_par, every_hbox_text);
                    }
                }
                return;
            }
    }
    /*tex In simple cases, we use the box immediately. */
    tex_box_end(boxcontext, boxnode, shift, unset_noad_class, slot, callback, leaders);
}
