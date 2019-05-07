/*
    See license.txt in the root of this project.
*/

# ifndef TEXNODES_H
# define TEXNODES_H

/*tex

    We can probably ditch |volatile| so that the compiler can optimize acccess
    a bit better.

*/

typedef struct node_memory_state_info {
    memory_word * varmem; /* * volatile varmem; */
    int node_properties_id;
    int lua_properties_level;
    halfword attr_list_cache;
    int max_used_attr;
    int var_used;
    int my_prealloc;
    int fix_node_lists;
    halfword rover;
    int forced_tag;
    int forced_line;
    halfword var_mem_max;
    char *varmem_sizes;
    int node_properties_table_size;
    halfword synctex_anyway_mode;
    halfword synctex_line_field;
    halfword synctex_no_files;
} node_memory_state_info;

extern node_memory_state_info node_memory_state;

# define varmem               node_memory_state.varmem
# define var_mem_max          node_memory_state.var_mem_max
/*       var_used             node_memory_state.var_used */
# define max_used_attr        node_memory_state.max_used_attr
# define attr_list_cache      node_memory_state.attr_list_cache
# define my_prealloc          node_memory_state.my_prealloc
# define fix_node_lists       node_memory_state.fix_node_lists
# define lua_properties_level node_memory_state.lua_properties_level
# define node_properties_id   node_memory_state.node_properties_id
/*define rover                node_memory_state.rover */
# define varmem_sizes         node_memory_state.varmem_sizes

extern void initialize_nodes(void);

# define varmemcast(a) (memory_word *)(a)

# define out_of_memory() (varmem == NULL)

extern halfword get_node(int s);
extern void free_node(halfword p, int s);
extern void init_node_mem(int s);
extern void dump_node_mem(void);
extern void undump_node_mem(void);

# define max_halfword  0x3FFFFFFF
# define max_dimen     0x3FFFFFFF

# ifndef null
# define null          0
# endif

# define null_flag    -0x40000000
# define zero_glue     0
# define normal        0

/*tex

    Most fields are integers (halfwords) that get aliased to |vinfo| and |vlink| for
    traditional reasons. The |vlink| name is actually representing a next pointer.

    A memory word has two 32 bit integers. Glue is a float is a double which normally
    takes 64 bits. So, we're now purely 64 bit based. This means that we could
    simplify the aliases a bit and already downstream the code has been made more
    neutral. The |qvalue| is used in the input stack code.

*/

# define vvalue(a) varmem[(a)].cint0
# define dvalue(a) varmem[(a)].glue0
# define qvalue(a) varmem[(a)].qqqq

# define vinfo(a) varmem[(a)].hh.v.LH
# define vlink(a) varmem[(a)].hh.v.RH

/*tex

    The first struct contains the |type| and |subtype| that are both 16 bit integers
    as well as the |vlink| (next) pointer.

*/

# define type(a)    varmem[(a)].hh.u.B0
# define subtype(a) varmem[(a)].hh.u.B1

/*tex

    The second struct contains the |alink| (prev) pointer and the attribute list pointer
    |node_attr|. Both are integers (halfwords) representing a node.

*/

# define node_attr(a) vinfo((a)+1)
# define alink(a)     vlink((a)+1)

/*tex

    The |node_size| field is used in managing freed nodes (mostly as a check) and it
    overwrites the |type| and |subtype| fields.

*/

# define node_size(a) varmem[(a)].hh.v.LH

/*tex

    The |tlink| and |rlink| fields are used in disc nodes as tail and replace pointers
    (again halfwords).

*/

# define tlink(a) vinfo((a)+1) /*tex overlaps with |node_attr()| */
# define rlink(a) vlink((a)+1) /*tex aka |alink()| */

/*tex really special head node pointers that only need links */

# define temp_node_size 2

/*tex attribute lists */

# define UNUSED_ATTRIBUTE -0x7FFFFFFF  /*tex as low as it goes */

/*tex

    It is convenient to have attribute list nodes and attribute node be the same
    size.

*/

# define attribute_node_size 2
# define cache_disabled max_halfword

# define disable_attr_cache attr_list_cache = cache_disabled;

# define check_attr_cache \
    if (attr_list_cache == cache_disabled) { \
        update_attribute_cache(); \
    }

# define attr_list_ref(a)   vinfo((a)+1) /*tex the reference count */
# define attribute_id(a)    vinfo((a)+1)
# define attribute_value(a) vlink((a)+1)

# define assign_attribute_ref(n,p) do { \
    node_attr(n) = p; \
    attr_list_ref(p)++; \
} while (0)

# define add_node_attr_ref(a) do { \
    if (a != null) \
        attr_list_ref((a))++; \
} while (0)

# define  replace_attribute_list(a,b) do { \
    delete_attribute_ref(node_attr(a)); \
    node_attr(a) = b; \
} while (0)

extern void update_attribute_cache(void);
extern halfword copy_attribute_list(halfword n);
extern halfword do_set_attribute(halfword p, int i, int val);

# define width_offset  2 /*tex used in setting box dimensions */
# define depth_offset  3 /*tex used in setting box dimensions */
# define height_offset 4 /*tex used in setting box dimensions */
# define list_offset   6

typedef enum {
    user_skip_glue,
    line_skip_glue,
    baseline_skip_glue,
    par_skip_glue,
    above_display_skip_glue,
    below_display_skip_glue,
    above_display_short_skip_glue,
    below_display_short_skip_glue,
    left_skip_glue,
    right_skip_glue,
    top_skip_glue,
    split_top_skip_glue,
    tab_skip_glue,
    space_skip_glue,
    xspace_skip_glue,
    par_fill_skip_glue,
    math_skip_glue,
    thin_mu_skip_glue,
    med_mu_skip_glue,
    thick_mu_skip_glue,
    /*tex math */
    cond_math_glue = 98,        /*tex special |subtype| to suppress glue in the next node */
    mu_glue,                    /*tex |subtype| for math glue */
    /*tex leaders */
    a_leaders,                  /*tex |subtype| for aligned leaders */
    c_leaders,                  /*tex |subtype| for centered leaders */
    x_leaders,                  /*tex |subtype| for expanded leaders */
    g_leaders                   /*tex |subtype| for global (page) leaders */
} glue_subtypes;

/*tex normal nodes */

# define inf_bad            10000         /*tex infinitely bad value */
# define inf_penalty        inf_bad       /*tex infinite penalty value */
# define eject_penalty    -(inf_penalty)  /*tex negatively infinite penalty value */

# define penalty_node_size  3
# define penalty(a)         vlink((a)+2)

typedef enum {
    user_penalty,
    linebreak_penalty, /*tex includes widow, club, broken etc. */
    line_penalty,
    word_penalty,
    final_penalty,
    noad_penalty,
    before_display_penalty,
    after_display_penalty,
    equation_number_penalty,
} penalty_subtypes ;

# define glue_node_size       7
# define glue_spec_size       5
/*       width(a)             vinfo((a)+2) */
/*       leader_ptr(a)        vlink((a)+2) */
# define shrink(a)            vinfo((a)+3)
# define stretch(a)           vlink((a)+3)
# define stretch_order(a)     vinfo((a)+4)
# define shrink_order(a)      vlink((a)+4)
# define leader_ptr(a)        vlink((a)+5) /*tex should be in vlink((a)+2) but fails */
# define synctex_tag_glue(a)  vinfo((a)+6)
# define synctex_line_glue(a) vlink((a)+6)

# define glue_is_zero(p) \
    ((!p) || ((width(p) == 0) && (stretch(p) == 0) && (shrink(p) == 0)))

# define glue_is_positive(p) \
    ((!p) || (width(p) > 0))

# define reset_glue_to_zero(p) \
if (p) { \
    width(p) = 0; \
    stretch(p) = 0; \
    shrink(p) = 0; \
    stretch_order(p) = 0; \
    shrink_order(p) = 0; \
}

# define copy_glue_values(p,q) \
if (q) { \
    width(p) = width(q); \
    stretch(p) = stretch(q); \
    shrink(p) = shrink(q); \
    stretch_order(p) = stretch_order(q); \
    shrink_order(p) = shrink_order(q); \
} else { \
    width(p) = 0; \
    stretch(p) = 0; \
    shrink(p) = 0; \
    stretch_order(p) = 0; \
    shrink_order(p) = 0; \
}

/*tex

    Disc nodes could eventually be smaller, because the indirect pointers are not
    really needed (8 instead of 10).

*/

typedef enum {
    discretionary_disc = 0,
    explicit_disc,
    automatic_disc,
    syllable_disc,
    init_disc,     /*tex first of a duo of syllable_discs */
    select_disc,   /*tex second of a duo of syllable_discs */
} discretionary_subtypes;

# define disc_node_size      10

# define disc_penalty(a)     vlink((a)+2)
# define no_break(a)         vinfo((a)+2)
# define pre_break(a)        vinfo((a)+3)
# define post_break(a)       vlink((a)+3)

# define pre_break_head(a)   ((a)+4) /* there is a subtype used (sort of, as we still use select discs) */
# define post_break_head(a)  ((a)+6) /* there is a subtype used (sort of, as we still use select discs) */
# define no_break_head(a)    ((a)+8) /* there is a subtype used (sort of, as we still use select discs) */

# define vlink_pre_break(a)  vlink(pre_break_head(a))
# define vlink_post_break(a) vlink(post_break_head(a))
# define vlink_no_break(a)   vlink(no_break_head(a))

# define tlink_pre_break(a)  tlink(pre_break_head(a))
# define tlink_post_break(a) tlink(post_break_head(a))
# define tlink_no_break(a)   tlink(no_break_head(a))

typedef enum {
    font_kern = 0,
    explicit_kern,  /*tex |subtype| of kern nodes from |\kern| and |\/| */
    accent_kern,    /*tex |subtype| of kern nodes from accents */
    italic_kern,
} kern_subtypes;

# define kern_node_size       5
# define ex_kern(a)           vinfo((a)+3)  /*tex expansion factor (hz) */
# define synctex_tag_kern(a)  vinfo((a)+4)
# define synctex_line_kern(a) vlink((a)+4)

typedef enum {
    unknown_list              =  0,
    line_list                 =  1, /*tex paragraph lines */
    hbox_list                 =  2, /*tex |\hbox| */
    indent_list               =  3, /*tex indentation box */
    align_row_list            =  4, /*tex row from a |\halign| or |\valign| */
    align_cell_list           =  5, /*tex cell from a |\halign| or |\valign| */
    equation_list             =  6, /*tex display equation */
    equation_number_list      =  7, /*tex display equation number */
    math_list_list            =  8,
    math_char_list            =  9,
    math_h_extensible_list    = 10,
    math_v_extensible_list    = 11,
    math_h_delimiter_list     = 12,
    math_v_delimiter_list     = 13,
    math_over_delimiter_list  = 14,
    math_under_delimiter_list = 15,
    math_numerator_list       = 16,
    math_denominator_list     = 17,
    math_limits_list          = 18,
    math_fraction_list        = 19,
    math_nucleus_list         = 20,
    math_sup_list             = 21,
    math_sub_list             = 22,
    math_degree_list          = 23,
    math_scripts_list         = 24,
    math_over_list            = 25,
    math_under_list           = 26,
    math_accent_list          = 27,
    math_radical_list         = 28,
} list_subtypes ;

/*tex
    We can put the dir with the orientation but it becomes messy in casting that way.
*/

# define box_node_size       10
# define width(a)            vlink((a)+2)   /* 2 = width_offset */
# define box_w_offset(a)     vinfo((a)+2)
# define depth(a)            vlink((a)+3)   /* 3 = depth_offset */
# define box_d_offset(a)     vinfo((a)+3)
# define height(a)           vlink((a)+4)   /* 4 = height_offset */
# define box_h_offset(a)     vinfo((a)+4)
# define shift_amount(a)     vlink((a)+5)
# define box_dir(a)          subtype((a)+5) /* a quarterword */
# define box_orientation(a)  type((a)+5)
# define list_ptr(a)         vlink((a)+6)   /* 6 = list_offset */
# define glue_order(a)       subtype((a)+6)
# define glue_sign(a)        type((a)+6)
# define glue_set(a)         dvalue((a)+7)
# define box_x_offset(a)     vinfo((a)+8)
# define box_y_offset(a)     vlink((a)+8)
# define synctex_tag_box(a)  vinfo((a)+9)
# define synctex_line_box(a) vlink((a)+9)

/*tex unset nodes */

# define glue_stretch(a) vvalue((a)+7)
# define glue_shrink     shift_amount
# define span_count      subtype

# define preset_rule_thickness 010000000000 /*tex denotes |unset_rule_thickness| */

typedef enum {
    normal_rule = 0,
    box_rule,
    image_rule,
    empty_rule,
    user_rule,
    math_over_rule,
    math_under_rule,
    math_fraction_rule,
    math_radical_rule,
    outline_rule,
} rule_subtypes;

# define rule_node_size        7
/*       width(a)              vlink((a)+2) */
# define rule_x_offset(a)      vinfo((a)+2)
/*       depth(a)              vlink((a)+3) */
# define rule_y_offset(a)      vinfo((a)+3)
/*       height(a)             vlink((a)+4) */
# define rule_data(a)          vinfo((a)+4)
# define rule_left(a)          vinfo((a)+5)
# define rule_right(a)         vlink((a)+5)
# define synctex_tag_rule(a)   vinfo((a)+6)
# define synctex_line_rule(a)  vlink((a)+6)

# define mark_node_size        3
# define mark_ptr(a)           vlink((a)+2)
# define mark_class(a)         vinfo((a)+2)

# define adjust_node_size      3
# define adjust_pre            subtype
# define adjust_ptr(a)         vlink(a+2)

# define glyph_node_size       7
# define character(a)          vinfo((a)+2)
# define font(a)               vlink((a)+2)
# define lang_data(a)          vinfo((a)+3)
# define lig_ptr(a)            vlink((a)+3)
# define x_displace(a)         vinfo((a)+4)
# define y_displace(a)         vlink((a)+4)
# define ex_glyph(a)           vinfo((a)+5)
# define glyph_data(a)         vlink((a)+5)
# define synctex_tag_glyph(a)  vinfo((a)+6)
# define synctex_line_glyph(a) vlink((a)+6)

# define is_char_node(a)  (a!=null && type(a)==glyph_node)

# define char_lang(a)   ((const int)(signed short)(((signed int)((unsigned)lang_data(a)&0x7FFF0000)<<1)>>17))
# define char_lhmin(a)  ((const int)(((unsigned)lang_data(a) & 0x0000FF00)>>8))
# define char_rhmin(a)  ((const int)(((unsigned)lang_data(a) & 0x000000FF)))
# define char_uchyph(a) ((const int)(((unsigned)lang_data(a) & 0x80000000)>>31))

# define make_lang_data(a,b,c,d) \
    (a>0 ? (1<<31): 0) + \
    (b<<16) + \
    (((c>0 && c<256) ? c : 255)<<8) + \
    (((d>0 && d<256) ? d : 255))

# define init_lang_data(a)    lang_data(a)=256+1

# define set_char_lang(a,b)   lang_data(a)=make_lang_data(char_uchyph(a),b,char_lhmin(a),char_rhmin(a))
# define set_char_lhmin(a,b)  lang_data(a)=make_lang_data(char_uchyph(a),char_lang(a),b,char_rhmin(a))
# define set_char_rhmin(a,b)  lang_data(a)=make_lang_data(char_uchyph(a),char_lang(a),char_lhmin(a),b)
# define set_char_uchyph(a,b) lang_data(a)=make_lang_data(b,char_lang(a),char_lhmin(a),char_rhmin(a))

# define margin_kern_node_size 4
# define margin_char(a)        vlink((a)+3)

/*tex |subtype| of marginal kerns */

typedef enum {
    left_side = 0,
    right_side
} margin_kern_subtypes ;

typedef enum {
    before = 0,
    after
} math_subtypes ;

# define math_node_size       7
/*       width(a)             vinfo((a)+2) */
/*       overlaps width                    */
/*       shrink(a)            vinfo((a)+3) */
/*       stretch(a)           vlink((a)+3) */
/*       stretch_order(a)     vinfo((a)+4) */
/*       shrink_order(a)      vlink((a)+4) */
/*       leader_ptr slot                   */
# define surround(a)          vinfo((a)+5)
# define synctex_tag_math(a)  vinfo((a)+6)
# define synctex_line_math(a) vlink((a)+6)

# define ins_node_size    6
# define float_cost(a)    vvalue((a)+2)
# define ins_ptr(a)       vinfo((a)+5)
# define split_top_ptr(a) vlink((a)+5)

# define page_ins_node_size 5

typedef enum {
    hlist_node = 0,
    vlist_node,
    rule_node,
    ins_node,
    mark_node,
    adjust_node,
    boundary_node,
    disc_node,
    whatsit_node,
# define last_preceding_break_node whatsit_node
    local_par_node,
    dir_node,
# define last_non_discardable_node dir_node
    math_node,
    glue_node,
    kern_node,
    penalty_node,
    unset_node,
    style_node,
    choice_node,
    simple_noad,
    radical_noad,
    fraction_noad,
    accent_noad,
    fence_noad,
    math_char_node,             /*tex kernel fields */
    sub_box_node,
    sub_mlist_node,
    math_text_char_node,
    delim_node,                 /*tex shield fields */
    margin_kern_node,
    glyph_node,                 /*tex this and below have attributes */
    shape_node,
    pseudo_line_node,
    /* fast nodes: use dummy name */
    pseudo_file_node,
    align_record_node,
    inserting_node,
    split_up_node,
    expr_node,
    nesting_node,
    span_node,
    attribute_node,
    glue_spec_node,
    attribute_list_node,
    temp_node,
    align_stack_node,
    movement_node,
    if_node,
    unhyphenated_node,
    hyphenated_node,
    delta_node,
    passive_node,
} node_types;

# define MAX_NODE_TYPE passive_node
# define NOP_NODE_TYPE align_record_node

# define precedes_break(a)  (type(a)<=last_preceding_break_node)
# define precedes_kern(a)   ((type(a) == kern_node) && (subtype(a) == font_kern || subtype(a) == accent_kern))
# define precedes_dir(a)    ((type(a) == dir_node) && (break_after_dir_mode_par == 1))
# define non_discardable(a) (type(a)<=last_non_discardable_node)

# define known_node_type(i) ( i >= 0 && i <= MAX_NODE_TYPE)

# define last_known_node temp_node /*tex used by \lastnodetype */

# define movement_node_size    3
# define if_node_size          2
# define align_stack_node_size 6
# define nesting_node_size     2

# define expr_node_size        3
# define expr_type(A)          type((A)+1)
# define expr_state(A)         subtype((A)+1)  /*tex enum defined in scanning.w */
# define expr_e_field(A)       vlink((A)+1)    /*tex saved expression so far */
# define expr_t_field(A)       vlink((A)+2)    /*tex saved term so far */
# define expr_n_field(A)       vinfo((A)+2)    /*tex saved numerator */

# define span_node_size        3
# define span_span(a)          vlink((a)+1)
# define span_link(a)          vinfo((a)+1)

# define pseudo_file_node_size 2
# define pseudo_lines(a)       vlink((a)+1)

# define nodetype_has_attributes(t) (((t)<=glyph_node) && ((t)!=unset_node))

# define nodetype_has_subtype(t) ((t)!=attribute_list_node && (t)!=attribute_node && (t)!=glue_spec_node)
# define nodetype_has_prev(t) nodetype_has_subtype((t))

/*tex

    style and choice nodes; style nodes can be smaller, the information is encoded in
    |subtype|, but choice nodes are on-the-spot converted to style nodes

*/

# define style_node_size        4
# define display_mlist(a)       vinfo((a)+2) /*tex mlist to be used in display style */
# define text_mlist(a)          vlink((a)+2) /*tex mlist to be used in text style */
# define script_mlist(a)        vinfo((a)+3) /*tex mlist to be used in script style */
# define script_script_mlist(a) vlink((a)+3) /*tex mlist to be used in scriptscript style */

/*tex

    Because noad types get changed when processing we need to make sure some if the node
    sizes match and that we don't share slots with different properties.

*/

/*tex regular noads */

# define noad_size      8
# define new_hlist(a)   vlink((a)+2) /*tex the translation of an mlist */
# define nucleus(a)     vinfo((a)+2) /*tex the |nucleus| field of a noad */
# define supscr(a)      vlink((a)+3) /*tex the |supscr| field of a noad */
# define subscr(a)      vinfo((a)+3) /*tex the |subscr| field of a noad */
# define noaditalic(a)  vlink((a)+4)
# define noadwidth(a)   vinfo((a)+4)
# define noadheight(a)  vlink((a)+5)
# define noaddepth(a)   vinfo((a)+5)
# define noadextra1(a)  vlink((a)+6) /*tex we need to match delimiter (saves copy) */
# define noadoptions(a) vinfo((a)+6)
# define noadextra3(a)  vlink((a)+7) /*tex see (!) below */
# define noadextra4(a)  vinfo((a)+7) /*tex used to store samesize */

# define noad_fam(a)    vlink((a)+6) /*tex noadextra1 */

typedef enum {
    ord_noad_type = 0,
    op_noad_type_normal,
    op_noad_type_limits,
    op_noad_type_no_limits,
    bin_noad_type,
    rel_noad_type,
    open_noad_type,
    close_noad_type,
    punct_noad_type,
    inner_noad_type,
    under_noad_type,
    over_noad_type,
    vcenter_noad_type,
} noad_types;

/*tex accent noads */

# define accent_noad_size      8
# define top_accent_chr(a)     vinfo((a)+6) /*tex the |top_accent_chr| field of an accent noad */
# define bot_accent_chr(a)     vlink((a)+6) /*tex the |bot_accent_chr| field of an accent noad */
# define overlay_accent_chr(a) vinfo((a)+7) /*tex the |overlay_accent_chr| field of an accent noad */
# define accentfraction(a)     vlink((a)+7)

typedef enum {
    bothflexible_accent,
    fixedtop_accent,
    fixedbottom_accent,
    fixedboth_accent,
} math_accent_subtypes ;

/*tex left and right noads */

# define fence_noad_size      8            /*tex needs to match noad size */
# define delimiteritalic(a)   vlink((a)+4)
/*       delimiterwidth(a)    vinfo((a)+4) */
# define delimiterheight(a)   vlink((a)+5)
# define delimiterdepth(a)    vinfo((a)+5)
# define delimiter(a)         vlink((a)+6) /*tex |delimiter| field in left and right noads */
# define delimiteroptions(a)  vinfo((a)+6)
# define delimiterclass(a)    vlink((a)+7) /*tex (!) we could probably pack some more in 6 */
# define delimitersamesize(a) vinfo((a)+7) /*tex set by engine */

/*tex when dimensions then axis else noaxis */

typedef enum {
    noad_option_set             =        0x08,
    noad_option_unused_1        = 0x00 + 0x08,
    noad_option_unused_2        = 0x01 + 0x08,
    noad_option_axis            = 0x02 + 0x08,
    noad_option_no_axis         = 0x04 + 0x08,
    noad_option_exact           = 0x10 + 0x08,
    noad_option_left            = 0x11 + 0x08,
    noad_option_middle          = 0x12 + 0x08,
    noad_option_right           = 0x14 + 0x08,
    noad_option_no_sub_script   = 0x21 + 0x08,
    noad_option_no_super_script = 0x22 + 0x08,
    noad_option_no_script       = 0x23 + 0x08,
} delimiter_options ;

# define delimiteroptionset(a) ((delimiteroptions(a) & noad_option_set    ) == noad_option_set    )
# define delimiteraxis(a)      ((delimiteroptions(a) & noad_option_axis   ) == noad_option_axis   )
# define delimiternoaxis(a)    ((delimiteroptions(a) & noad_option_no_axis) == noad_option_no_axis)
# define delimiterexact(a)     ((delimiteroptions(a) & noad_option_exact  ) == noad_option_exact  )

# define noadoptionnosubscript(a) ( (type(a) == simple_noad) && ( \
                                    ((delimiteroptions(a) & noad_option_no_sub_script  ) == noad_option_no_sub_script) || \
                                    ((delimiteroptions(a) & noad_option_no_script      ) == noad_option_no_script    ) ))
# define noadoptionnosupscript(a) ( (type(a) == simple_noad) && ( \
                                    ((delimiteroptions(a) & noad_option_no_super_script) == noad_option_no_super_script) || \
                                    ((delimiteroptions(a) & noad_option_no_script      ) == noad_option_no_script      ) ))

typedef enum {
    noad_delimiter_mode_noshift = 0x01,
    noad_delimiter_mode_italics = 0x02,
    noad_delimiter_mode_ordinal = 0x04,
    noad_delimiter_mode_samenos = 0x08,
    noad_delimiter_mode_charnos = 0x10,
} delimiter_modes ;

# define delimitermodenoshift ((math_delimiters_mode_par & noad_delimiter_mode_noshift) == noad_delimiter_mode_noshift)
# define delimitermodeitalics ((math_delimiters_mode_par & noad_delimiter_mode_italics) == noad_delimiter_mode_italics)
# define delimitermodeordinal ((math_delimiters_mode_par & noad_delimiter_mode_ordinal) == noad_delimiter_mode_ordinal)
# define delimitermodesamenos ((math_delimiters_mode_par & noad_delimiter_mode_samenos) == noad_delimiter_mode_samenos)
# define delimitermodecharnos ((math_delimiters_mode_par & noad_delimiter_mode_charnos) == noad_delimiter_mode_charnos)

/*tex subtype of fence noads */

typedef enum {
    unset_noad_side  = 0,
    left_noad_side   = 1,
    middle_noad_side = 2,
    right_noad_side  = 3,
    no_noad_side     = 4,
} fence_subtypes ;

/*tex fraction noads */

# define fraction_noad_size  8
# define thickness(a)        vlink((a)+2)    /*tex |thickness| field in a fraction noad */
/*                           vinfo((a)+2) */ /* not used? */
# define numerator(a)        vlink((a)+3)    /*tex |numerator| field in a fraction noad */
# define denominator(a)      vinfo((a)+3)    /*tex |denominator| field in a fraction noad */
/*                           vlink((a)+4) */ /* not used? */
/*                           vinfo((a)+4) */ /* not used? */
# define left_delimiter(a)   vlink((a)+5)    /*tex first delimiter field of a noad */
# define right_delimiter(a)  vinfo((a)+5)    /*tex second delimiter field of a fraction noad */
# define middle_delimiter(a) vlink((a)+6)
# define fractionoptions(a)  vinfo((a)+6)
# define fraction_fam(a)     vlink((a)+7)
/*                           vinfo((a)+7) */ /* not used? */

# define fractionoptionset(a) ((fractionoptions(a) & noad_option_set    ) == noad_option_set    )
# define fractionexact(a)     ((fractionoptions(a) & noad_option_exact  ) == noad_option_exact  )
# define fractionnoaxis(a)    ((fractionoptions(a) & noad_option_no_axis) == noad_option_no_axis)

/*tex radical noads, it is like a fraction, but it only stores a |left_delimiter| */

# define radical_noad_size 7
# define radicalwidth(a)   vinfo((a)+4)
/*                         vlink((a)+4) */ /* not used? */
/*                         vlink((a)+5) */ /* not used? */
/*                         vinfo((a)+5) */ /* not used? */
# define degree(a)         vlink((a)+6)    /* the root degree in a radical noad */
# define radicaloptions(a) vinfo((a)+6)

# define radicaloptionset(a) ((radicaloptions(a) & noad_option_set   ) == noad_option_set)
# define radicalexact(a)     ((radicaloptions(a) & noad_option_exact ) == noad_option_exact)
# define radicalleft(a)      ((radicaloptions(a) & noad_option_left  ) == noad_option_left)
# define radicalmiddle(a)    ((radicaloptions(a) & noad_option_middle) == noad_option_middle)
# define radicalright(a)     ((radicaloptions(a) & noad_option_right ) == noad_option_right)

typedef enum {
    radical_noad_type,
    uradical_noad_type,
    uroot_noad_type,
    uunderdelimiter_noad_type,
    uoverdelimiter_noad_type,
    udelimiterunder_noad_type,
    udelimiterover_noad_type,
} radical_subtypes;

/*tex accessors for the |nucleus|-style node fields */

# define math_kernel_node_size 3
# define math_fam(a)           vinfo((a)+2)
# define math_character(a)     vlink((a)+2) /* overlaps */
# define math_list(a)          vlink((a)+2) /* overlaps */

/*tex accessors for the |delimiter|-style two-word subnode fields */

# define math_shield_node_size 4

# define small_fam(A)  vinfo((A)+2) /*tex |fam| for small delimiter */
# define small_char(A) vlink((A)+2) /*tex |character| for small delimiter */
# define large_fam(A)  vinfo((A)+3) /*tex |fam| for large delimiter */
# define large_char(A) vlink((A)+3) /*tex |character| for large delimiter */

/*tex we should have the codes in a separate enum: extension_codes */

# define get_node_size(i) (node_data[i].size)
# define get_node_name(i) (node_data[i].name)
# define get_etex_code(i) (node_data[i].etex)

# define GLYPH_CHARACTER (1 << 0)
# define GLYPH_LIGATURE  (1 << 1)
# define GLYPH_GHOST     (1 << 2)
# define GLYPH_LEFT      (1 << 3)
# define GLYPH_RIGHT     (1 << 4)

typedef enum {
    glyph_unset     = 0,
    glyph_character = GLYPH_CHARACTER,
    glyph_ligature  = GLYPH_LIGATURE,
    glyph_ghost     = GLYPH_GHOST,
    glyph_left      = GLYPH_LEFT,
    glyph_right     = GLYPH_RIGHT,
} glyph_subtypes;

# define is_character(p)        ((subtype(p)) & GLYPH_CHARACTER)
# define is_ligature(p)         ((subtype(p)) & GLYPH_LIGATURE )
# define is_ghost(p)            ((subtype(p)) & GLYPH_GHOST    )

# define is_simple_character(p) (is_character(p) && !is_ligature(p) && !is_ghost(p))

# define is_leftboundary(p)     (is_ligature(p) && ((subtype(p)) & GLYPH_LEFT ))
# define is_rightboundary(p)    (is_ligature(p) && ((subtype(p)) & GLYPH_RIGHT))
# define is_leftghost(p)        (is_ghost(p)    && ((subtype(p)) & GLYPH_LEFT ))
# define is_rightghost(p)       (is_ghost(p)    && ((subtype(p)) & GLYPH_RIGHT))

# define set_is_glyph(p)         subtype(p) = (quarterword) (subtype(p) & ~GLYPH_CHARACTER)
# define set_is_character(p)     subtype(p) = (quarterword) (subtype(p) |  GLYPH_CHARACTER)
# define set_is_ligature(p)      subtype(p) = (quarterword) (subtype(p) |  GLYPH_LIGATURE)
# define set_is_ghost(p)         subtype(p) = (quarterword) (subtype(p) |  GLYPH_GHOST)

# define set_to_glyph(p)         subtype(p) = (quarterword) (subtype(p) & 0xFF00)
# define set_to_character(p)     subtype(p) = (quarterword)((subtype(p) & 0xFF00) | GLYPH_CHARACTER)
# define set_to_ligature(p)      subtype(p) = (quarterword)((subtype(p) & 0xFF00) | GLYPH_LIGATURE)
# define set_to_ghost(p)         subtype(p) = (quarterword)((subtype(p) & 0xFF00) | GLYPH_GHOST)

# define set_is_leftboundary(p)  { set_to_ligature(p); subtype(p) |= GLYPH_LEFT;  }
# define set_is_rightboundary(p) { set_to_ligature(p); subtype(p) |= GLYPH_RIGHT; }
# define set_is_leftghost(p)     { set_to_ghost(p);    subtype(p) |= GLYPH_LEFT;  }
# define set_is_rightghost(p)    { set_to_ghost(p);    subtype(p) |= GLYPH_RIGHT; }

typedef enum {
    cancel_boundary = 0,
    user_boundary,
    protrusion_boundary,
    word_boundary,
} boundary_subtypes ;

#  define boundary_node_size 3
#  define boundary_value(a) vinfo((a)+2)

typedef enum {
    normal_dir = 0,
    cancel_dir,
} dir_subtypes ;

# define dir_node_size 3
# define dir_dir(a)    vinfo((a)+2)
# define dir_level(a)  vlink((a)+2)

# define local_par_size 6

# define local_pen_inter(a)       vinfo((a)+2)
# define local_pen_broken(a)      vlink((a)+2)
# define local_box_left(a)        vlink((a)+3)
# define local_box_left_width(a)  vinfo((a)+3)
# define local_box_right(a)       vlink((a)+4)
# define local_box_right_width(a) vinfo((a)+4)
# define local_par_dir(a)         vinfo((a)+5)
/*                                vlink((a)+5) */ /* can be used for a counter */

/*tex a generic whatsit */

# define whatsit_node_size 2

/*tex nodes used in the parbuilder */

# define active_node_size               4             /*tex number of words in extended active nodes */
# define fitness                        subtype       /*tex |very_loose_fit..tight_fit| on final line for this break */
# define break_node(a)                  vlink((a)+1)  /*tex pointer to the corresponding passive node */
# define line_number(a)                 vinfo((a)+1)  /*tex line that begins at this breakpoint */
# define total_demerits(a)              vvalue((a)+2) /*tex the quantity that \TEX\ minimizes */
# define active_short(a)                vinfo((a)+3)  /*tex |shortfall| of this line */
# define active_glue(a)                 vlink((a)+3)  /*tex corresponding glue stretch or shrink */

# define passive_node_size              7
# define cur_break(a)                   vlink((a)+1)  /*tex in passive node, points to position of this breakpoint */
# define prev_break(a)                  vinfo((a)+1)  /*tex points to passive node that should precede this one */
# define passive_pen_inter(a)           vinfo((a)+2)
# define passive_pen_broken(a)          vlink((a)+2)
# define passive_left_box(a)            vlink((a)+3)
# define passive_left_box_width(a)      vinfo((a)+3)
# define passive_last_left_box(a)       vlink((a)+4)
# define passive_last_left_box_width(a) vinfo((a)+4)
# define passive_right_box(a)           vlink((a)+5)
# define passive_right_box_width(a)     vinfo((a)+5)
# define serial(a)                      vlink((a)+6)  /*tex serial number for symbolic identification */
/*                                      vinfo((a)+6) */

# define delta_node_size                10            /*tex 8 fields, stored in a+1..9 */

/*tex We have a double linked list so here are some helpers: */

# define couple_nodes(a,b)      { vlink(a) = b; alink(b) = a; }
# define try_couple_nodes(a,b)  if (b == null) { vlink(a) = b; } else { couple_nodes(a,b); }
# define uncouple_node(a)       { vlink(a) = null; alink(a) = null; }

extern void delete_attribute_ref(halfword b);
extern void reset_node_properties(halfword b);
extern void reassign_attribute(halfword n,halfword new);
extern void build_attribute_list(halfword b);
extern halfword current_attribute_list(void);

extern int unset_attribute(halfword n, int c, int w);
extern void set_attribute(halfword n, int c, int w);
extern int has_attribute(halfword n, int c, int w);

extern void print_short_node_contents(halfword n);
extern void show_node_list(int i);
extern halfword actual_box_width(halfword r, scaled base_width);

typedef struct _subtype_info {
    int id;
    const char *name;
    int lua;
} subtype_info;

typedef struct _field_info {
    const char *name;
    int lua;
} field_info;

typedef struct _node_info {
    int id;
    int size;
    subtype_info *subtypes;
    field_info *fields;
    const char *name;
    int etex;
    int lua;
} node_info;

extern node_info node_data[];

extern subtype_info node_subtypes_dir[];
extern subtype_info node_subtypes_localpar[];
extern subtype_info node_subtypes_glue[];
extern subtype_info node_subtypes_mathglue[];
extern subtype_info node_subtypes_leader[];
extern subtype_info node_subtypes_boundary[];
extern subtype_info node_subtypes_penalty[];
extern subtype_info node_subtypes_kern[];
extern subtype_info node_subtypes_rule[];
extern subtype_info node_subtypes_glyph[];
extern subtype_info node_subtypes_disc[];
extern subtype_info node_subtypes_marginkern[];
extern subtype_info node_subtypes_list[];
extern subtype_info node_subtypes_adjust[];
extern subtype_info node_subtypes_math[];
extern subtype_info node_subtypes_noad[];
extern subtype_info node_subtypes_radical[];
extern subtype_info node_subtypes_accent[];
extern subtype_info node_subtypes_fence[];

extern subtype_info node_values_fill[];
extern subtype_info node_values_dir[];

extern subtype_info other_values_page_states[];

extern halfword new_node(int i, int j);
extern void flush_node_list(halfword);
extern void flush_node(halfword);
extern halfword do_copy_node_list(halfword, halfword);
extern halfword copy_node_list(halfword);
extern halfword copy_node(const halfword);
extern void check_node(halfword);
extern halfword fix_node_list(halfword);
extern char *sprint_node_mem_usage(void);

typedef enum {
    normal_g = 0, /*tex normal */
    sfi,
    fil,
    fill,
    filll
} glue_orders;

# define zero_glue        0
# define sfi_glue         zero_glue+glue_spec_size
# define fil_glue         sfi_glue+glue_spec_size
# define fill_glue        fil_glue+glue_spec_size
# define ss_glue          fill_glue+glue_spec_size
# define fil_neg_glue     ss_glue+glue_spec_size
# define page_ins_head    fil_neg_glue+glue_spec_size

# define contrib_head     page_ins_head+temp_node_size
# define page_head        contrib_head+temp_node_size
# define temp_head        page_head+temp_node_size
# define hold_head        temp_head+temp_node_size
# define adjust_head      hold_head+temp_node_size
# define pre_adjust_head  adjust_head+temp_node_size
# define active           pre_adjust_head+temp_node_size
# define align_head       active+active_node_size
# define end_span         align_head+temp_node_size
# define begin_point      end_span+span_node_size
# define end_point        begin_point+glyph_node_size
# define var_mem_stat_max (end_point+glyph_node_size-1)

# define stretching 1
# define shrinking  2

# define is_running(A) ((A)==null_flag) /*tex This tests for a running dimension. */

extern halfword tail_of_list(halfword p);

extern halfword new_null_box(void);
extern halfword new_rule(int s);
extern halfword new_glyph(int f, int c, int d);
extern halfword new_char(int f, int c, int d);

extern halfword raw_glyph(void);

extern halfword new_disc(void);
extern halfword new_math(scaled w, int s);
extern halfword new_spec(halfword p);
extern halfword new_param_glue(int n);
extern halfword new_glue(halfword q);
extern halfword new_skip_param(int n);
extern halfword new_kern(scaled w);
extern halfword new_penalty(int m, int s);

extern scaled glyph_width(halfword p);
extern scaled glyph_width_ex(halfword p);
extern scaled glyph_height(halfword p);
extern scaled glyph_depth(halfword p);

extern scaled_whd glyph_dimensions(halfword p);
extern scaled_whd pack_dimensions(halfword p);

extern halfword make_local_par_node(int mode);

# define synctex_set_mode(m)     node_memory_state.synctex_anyway_mode = m
# define synctex_get_mode()      node_memory_state.synctex_anyway_mode
# define synctex_set_no_files(f) node_memory_state.synctex_no_files = f
# define synctex_get_no_files()  (int) node_memory_state.synctex_no_files
# define synctex_set_tag(t)      cur_input.synctex_tag_field = t
# define synctex_get_tag()       (int) cur_input.synctex_tag_field
# define synctex_get_line()      (int) node_memory_state.synctex_line_field
# define synctex_force_tag(t)    node_memory_state.forced_tag = t
# define synctex_force_line(t)   node_memory_state.forced_line = t
# define synctex_set_line(l)     node_memory_state.synctex_line_field = l

extern void l_set_node_data(void) ;

extern halfword *check_isnode(lua_State * L, int i);
extern halfword list_node_mem_usage(void);

/* checking */

# define valid_node(p) (p > my_prealloc && p < var_mem_max && varmem_sizes[p] > 0)

# endif
