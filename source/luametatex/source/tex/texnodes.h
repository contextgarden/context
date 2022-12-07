/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXNODES_H
# define LMT_TEXNODES_H

/*tex

    We can probably ditch |volatile| so that the compiler can optimize access a bit better. We
    only need to make sure that we create nodes before we use their pointers. So, beware: a
    newnode has to go via an intermediate variable because the |varmem| array can have been be
    reallocated. I need to (re)check all cases! In case of a copy we use a intermediate volatile
    variable.

    Anyway, we now have only a few |quarterwords| in use, most noticeably the type and subtype.
    Eventually I might go for a consistent

    type      subtype
    prev      next
    attribute data
    etc

    model. Or maybe even just a flat list, no need for memoryword, but just all halfwords. However,
    it will demand all kind of tiny adaptations and we don't gain much. We'd also loose some charm
    of traditional \TEX. Also, we now have a double glue related field and that would then become
    a float. So, not now.

    There are a few more node types than in standard \TEX, but less than we have in e.g.\ \PDFTEX\
    or stock \LUATEX. For instance margin nodes are now just kern nodes, some whatits are first
    class nodes and we have only one generic whatsit left. We also have more subtypes which makes
    a more detailed tracking of where nodes come from possible. Other nodes, like the |inserting|
    and |split_up| nodes are ot both |inserting| but with a subtype because the register index is
    no longer the subtype.

    Not all nodes can end up in a node list. Some are used for housekeeping (stack, expressions,
    conditional nesting, etc.) or show up in the process of breaking paragraphs into lines. When
    we talk of nodes with users in the perspective of \TEX\ we normally refer to the ones in
    horizontal and vertical lists or math lists, not to those more obscure housekeeping nodes. It
    just happens that they share the same memory model and management.

    A complication is that some nodes have pointers that themselves point to a (often smaller)
    node but use the same accessors. This means that (1) their layout should be the same with
    respect to the pointer, which happens with span nodes or (2) that there is some offset in play,
    which happens with ins pointers and break nodes that are embedded in a disc node.

    Now that we no longer have variable nodes, we can consider a different allocation model, like
    a chain of malloced nodes but on the other hand storing them might be more work. We also cannot
    longer share the accessors so again more work is needed. But ... maybe attributes might end up
    as allocated lists some day, but that also demands storage. The current memory management is
    very efficient and we don't gain anything with redoing that, apart maybe from nodes becoming
    structs. Even then we will have an array of pointers instead of what we have now, but without
    the jumps by side in the indices. So, given the constraints of offsets and overlap it makes no
    sense to waste time on this.

    Instead of |var_mem| we use |nodes| and related names. This better complements the additional
    variables that we have for dynamic management. Some more names have been changed (also in order
    to avoid side effect in syntax highlighting). Too common names also result in too many matches
    when searching the source tree.

    Soo, eventually most fields now have the type of the node in their name, which makes it more
    clear what they are. As mentioned, it makes the syntax highlighted source look better as some
    generic names are used elsewhere too. Another reason is that we have more fields in nodes and
    when browsing the source it helps to know that a |width| is actually the |glue_amount| which
    when we go down is actually a height anyway. It also makes it possible at some point to make
    some nodes smaller when we don't need these \quote {shared by name} fields. We also need this
    transition in order to get better interfacing to the \LUA\ end, one reason being that we need
    to distinguish between fields that overlap (as in lists, unset nodes and and alignment
    records).

    Todo: all subtype related constants will become |_subtype| so that also means a couple more
    _code ones for commands. It's all about consistency but that will happen stepwise. A typical
    rainy day with some newly acquired music in background kind of activity:

    - discretionary
    - adjust
    - noad
    - fence
    - radical
    - boundary

*/

typedef enum node_types {
    hlist_node,
    vlist_node,
    rule_node,
    insert_node,
    mark_node,
    adjust_node,
    boundary_node,
    disc_node,
    whatsit_node,
    /*tex The last_preceding_break_node: */
    par_node,
    dir_node,
    /*tex The last_non_discardable_node: */
    math_node,
    glue_node,
    kern_node,
    penalty_node,
    style_node,
    choice_node,
    parameter_node,
    simple_noad,
    radical_noad,
    fraction_noad,
    accent_noad,
    fence_noad,
    math_char_node,      
    math_text_char_node,
    sub_box_node,
    sub_mlist_node,
    delimiter_node,
    glyph_node,
    /*tex This was the last node with attributes, except unset nodes. */
    unset_node,
    specification_node,
    align_record_node,
    attribute_node,
    glue_spec_node,
    temp_node,
    split_node,
    /*tex The next set of nodes is invisible from the \LUA\ (but nesting nodes can show up). */
    expression_node,
    math_spec_node,
    font_spec_node,
    nesting_node,
    span_node,
    align_stack_node,
 // noad_state_node,
    if_node,
    /*tex These two are active nodes. */
    unhyphenated_node, 
    hyphenated_node,   
    delta_node,
    passive_node,
} node_types;

# define max_chain_size  32

# define unknown_node_type    -1
# define unknown_node_subtype -1

/* Todo: [type] [subtype|size] [index] -> nodes : advantage is no holes in node id's */

typedef struct node_memory_state_info {
    memoryword  *nodes;
 // memoryword  *volatile nodes;
    char        *nodesizes;
    halfword     free_chain[max_chain_size];
    memory_data  nodes_data;
    memory_data  extra_data;
    int          reserved; /*tex There are some predefined nodes. */
    int          padding;
    int          node_properties_id;
    int          lua_properties_level;
    halfword     attribute_cache;
    halfword     max_used_attribute;
    int          node_properties_table_size;
} node_memory_state_info;

extern node_memory_state_info lmt_node_memory_state;

typedef enum field_types {
    nil_field,
    integer_field,
    dimension_field,
    glue_field,
    number_field,
    string_field,
    boolean_field,
    function_field,
    node_field,
    node_list_field,
    token_field,
    token_list_field,
    attribute_field,
} field_types;

extern halfword tex_get_node            (int size);
extern void     tex_free_node           (halfword p, int size);
extern void     tex_dump_node_mem       (dumpstream f);
extern void     tex_undump_node_mem     (dumpstream f);
extern void     tex_initialize_node_mem (void);
extern void     tex_initialize_nodes    (void);

extern void     lmt_nodelib_initialize  (void); /* name ? */

/*tex

    Most fields are integers (halfwords) that get aliased to |vinfo| and |vlink| for traditional
    reasons. The |vlink| name is actually representing a next pointer. Only the type and subtype
    remain quarterwords, the rest are just halfwords which wastes space for directions,
    orientation, glue orders and glue signs but so be it.

    A memory word has two 32 bit integers so 8 bytes. A glueratio is a double which is 8 bytes so
    there we waste some space. There is actually no need now to pack (node) data in pairs so maybe
    some day I'll change that. When we make glue ration a float again we can go flat (and with most
    node fields now being fully qualified that is easier).

    The first memoryword contains the |type| and |subtype| that are both 16 bit integers (unsigned)
    as well as the |vlink| (next) pointer. After that comes the word that keeps the |attr| and
    |alink| (prev) fields. Instead of the link names we use more meaningful ones. The |next|, |prev|
    and |attr| fields all are halfwords representing a node index.

    The |node_size| field is used in managing freed nodes (mostly as a check) and it overwrites the
    |type| and |subtype| fields. Actually we could just use the type or subtype but as the size is
    small but on the other hand using an int here makes sense.

    half0 | quart0 quart1 | vinfo | size | type subtype
    half1 |               | vlink

    The |tlink| and |rlink| fields are used in disc nodes as tail and replace pointers (again
    halfwords). We no longer need |rlink| as it's equivalent to |alink| (the prev pointer). The
    |tlink| fields is used for links to the tail of a list. These indirect macros are somewhat
    complicating matters. Again these have been renamed.

    We used to have |alink(a)| being |vlink(a,1)| but that has (after a few years) been replaced by
    |node_prev| because is cleaner. Keep in mind that in \LUATEX\ we use double linked node lists. So,
    we now only have some \quote {hard coded} pointers to the memory array in this file, not in the
    files that use the node fields. However, for the next two paragraphs to be true, I need to find
    a solution for the insert_ptr first because that is an index.

    Now, a logical question is: should we stick to the link and info model for nodes? One reason
    is that we share the model with tokens. A less relevant reason is that the glue is stored in 8
    bytes but that can be reverted to 4 bytes if needed. So, indeed at some point we might see a 32
    bit wide array show up here as we're now more or less prepared for that. It will bump the direct
    node numbers but that should work out okay. So, in the end, after stepwise abstraction we now
    have field definitions that use a base and offset e.g. |vlink(a,3)| instead of |vlink(a+3)|.
    Also, we have many more fields and using meaningful names quickly started to make sense.

    Once all is stable I will play with |var_mem| being an array of pointers and |malloc| the
    smaller memoryword arrays (per node). This might lead to (not always) smaller memory footprint:
    we have one pointer per node (but only that array gets preallocated) but we need less memory in
    total, unless we use many nodes. Anyway, we keep the  indirect model (which might add overhead,
    but that can be compensated by \CPU\ caches) because using a numeric node pointer is more
    efficient and quite handy. If we would go completely struct the source would change so much that
    we loose the charm of \TEX\ and documentation and there is no gain in it. Also, using halfword
    indices (but then to pointers) for nodes has the huge advantage that it is fast in \LUA\ (always
    a bottleneck) and these node indices can (and have to) be stored in tokens. One nice side effect
    would be that we have node indices in a sequence (without the current jumps due to node size
    offset, which in turn gives more room for nodes references in tokens).

    In spite of all extensions we hope the spirit of how \TEX\ does it is still very visible.

*/

# define mvalue(a,b)  lmt_node_memory_state.nodes[a+b].P
# define lvalue(a,b)  lmt_node_memory_state.nodes[a+b].L
# define dvalue(a,b)  lmt_node_memory_state.nodes[a+b].D

# define vinfo(a,b)   lmt_node_memory_state.nodes[a+b].half0
# define vlink(a,b)   lmt_node_memory_state.nodes[a+b].half1

# define vinfo0(a,b)  lmt_node_memory_state.nodes[a+b].quart00
# define vinfo1(a,b)  lmt_node_memory_state.nodes[a+b].quart01
# define vlink0(a,b)  lmt_node_memory_state.nodes[a+b].quart10
# define vlink1(a,b)  lmt_node_memory_state.nodes[a+b].quart11

# define vinfo00(a,b) lmt_node_memory_state.nodes[a+b].single00
# define vinfo01(a,b) lmt_node_memory_state.nodes[a+b].single01
# define vinfo02(a,b) lmt_node_memory_state.nodes[a+b].single02
# define vinfo03(a,b) lmt_node_memory_state.nodes[a+b].single03
# define vlink00(a,b) lmt_node_memory_state.nodes[a+b].single10
# define vlink01(a,b) lmt_node_memory_state.nodes[a+b].single11
# define vlink02(a,b) lmt_node_memory_state.nodes[a+b].single12
# define vlink03(a,b) lmt_node_memory_state.nodes[a+b].single13

/*tex
    We have some shared field names. Some day the subtypes will get meaningful names dependent on
    the node type, if only because some already have. We used to have

    \starttyping
    # define type(a)         vinfo0(a,0)
    # define subtype(a)      vinfo1(a,0)
    # define node_size(a)    vinfo(a,0)
    \stoptyping

    but we dropped the size mechanism and made most field shortcuts verbose in order to be able to
    use variable names with the same name combined with proper syntax highlighting etc. It also
    gives less noise when we search in the whole source tree. More later.
*/

# define node_type(a)    vinfo0(a,0)
# define node_subtype(a) vinfo1(a,0)

# define node_next(a) vlink(a,0)
# define node_prev(a) vlink(a,1)
# define node_attr(a) vinfo(a,1)

# define node_head(a) vlink(a,0) /*tex the head |hlink(a)| aka |vlink(a)| of a disc sublist */
# define node_tail(a) vinfo(a,1) /*tex the tail |tlink(a)| aka |vinfo(a)|, overlaps with |node_attr()| */

/*tex

    The dimension fields shared their locations which made for sometimes more compact code but
    in the end the number of placxes where it really saved code were limited. Also, compilers will
    do their job and deal with common code. So, these are now replaced by more meaningful names:

    \starttyping
    # define width(a)  vlink(a,2)
    # define depth(a)  vlink(a,3)
    # define height(a) vlink(a,4)
    \stoptyping

    Inserts use a trick. The insert pointers directly point into a node at the place where the list
    starts which is why |list_ptr| has to overlap with |node_next|! I have looked into changign this
    but it doesn't pay off and it's best to stay close to the original. A side effect is that some
    fields in insert nodes are sort of impossible (for now).

    \starttyping
    # define box_list_ptr(a) vlink(a,5) // We need to use the same field as |node_next|.
    # define insert_list(a) (a + 5) // This kind of makes a virtual node: start at list.
    \stoptyping

    Beware of the fact that for instance alignments use some fields for other purposes, like:
    |u_part(a)|, |v_part(a)|, |span_ptr(a)|, etc. and assume the rest of the fields to overlap
    with list nodes. So, we cannot simply reshuffle positions!

    In the original \TEX\ source (and also in \LUATEX) there are a couple of offsets used. Most
    noticeably is the |list_offset| but in 2.0618 the related trickery was replaced by using
    |list_ptr| and using the fact that we have a doubel linked list. The four fields are in
    successive memory words and that means that we can use |node_next| in a field pointed to
    by |list_offset| (because actually we then have the list pointer!). This makes for simple
    loops in original \TEX. The dimension offsets are used to set fields in boxed but we already
    abstracted that to proper field names; these were for instance used in alignment nodes that
    have mostly the same properties as a box node.

    \starttyping
    # define width_offset  2
    # define depth_offset  3
    # define height_offset 4
    # define list_offset   5
    \stoptyping

    These abstractions mean that we now have nodes, fields and offsets all abstracted in such a way
    that all definitions and trickery in in this file. Of course I could have messed up.

*/

/*tex

    Syntex supports demands some extra fields in nodes that makes it possible to output location as
    well as file/line information for viewer-editor synchronization. The ideas is quite okay but
    unfortunately the implementation of the library is rather bound to the way e.g. \LATEX\ typesets
    documents. Synctex has always been problematic when it comes to \CONTEXT. There is for instance
    no control over filenames and discussions around some limitations (and possible features) in the
    \PDFTEX\ and early \LUATEX\ times never resulted in fixing that (setting filenames, adding some
    additional synchronization points, etc). All that was supposed to happen deep down in the library
    and was not considered to be dealt with by a macro package. For instance multiple loading of the
    same file (metapost runs or smaple files) was a problem as was the need to block access to files
    in tds (like styles). We also needed binding to for instance elements in an \XML\ file where line
    numbers are sort of special and out of sync with inclusion. I guess we were ahead of the pack
    because after nearly two decades of \LUATEX\ there is some discussion about this.

    Anyway, for the reasons mentioned \LUATEX\ offers some setters that overload the engine ones and
    that permits \CONTEXT\ to implement its own variant. However, in \LUAMETATEX\ setting tags and
    lines from \LUA\ is now the only way to support \SYNCTEX\ because the library is absent: we just
    have some extra fields in some nodes. In \LUAMETATEX\ only glyph and list nodes have these fields
    as it makes no sense to have them elsewhere: macro packages can add glue and kerns and rules and
    \unknown\ all over the place and adding file state info there only makes things confusing and
    working less well. This is what the mode parameter can handle in \LUATEX\ and in \LUAMETATEX\ it
    only supports the modes 1 and 3.

    As a side note: the fact that a viewer needs to embed the library is also a limitation. Calling
    out to an external program that analyzes the file and gives back the filename and line is more
    flexible and robust. Because we have such an analyzer in \MKIV\ it was no big deal to add a few
    lines so that the \TEX shop environment could use that script/method (bidirectional); hopefully
    other viewers and editors will follow.

    So, compared to \LUATEX\ less nodes have the extra fields (which saves memory) and therefore
    less has to be set. Because there is no library at all, writing a synctex file is up to some
    additional \LUA\ code, but that was already the case in \MKIV\ anyway. We might at some point
    change the field names to \quote {file} and \quote {line} and remove interface options that
    have no use any more. We also moved to a more generic naming of (input related) fields.

*/

/*

    Temporary nodes are really special head node pointers that only need links. They ensure that
    there is at least one node in a list.

*/

# define temp_node_size 2

/*tex

    In \LUATEX\ we have attribute list nodes and attribute nodes that are (anyway) of the same
    size. In the end I decided to combine them into one node with a subtype. That also helps
    diagnose issues. It is one of the few nodes now that has fields depending on the subtype
    but these nodes are not really user ones anyway.

*/

# define attribute_node_size 2
# define attribute_unset(a)  vinfo(a,1)
# define attribute_index(a)  vinfo(a,1) /*tex actually we need half of this */
# define attribute_count(a)  vlink(a,1) /*tex the reference count */
# define attribute_value(a)  vlink(a,1)

typedef enum attribute_subtypes {
    attribute_list_subtype,
    attribute_value_subtype,
} attribute_subtypes;

# define last_attribute_subtype attribute_value_subtype

/*tex
    Penalties have only one primitive so we don't have |_code| here, also because it would conflict
    with arguments.
*/

# define penalty_node_size 3
# define penalty_amount(a) vlink(a,2)

typedef enum penalty_subtypes {
    user_penalty_subtype,
    linebreak_penalty_subtype, /*tex includes widow, club, broken etc. */
    line_penalty_subtype,
    word_penalty_subtype,
    orphan_penalty_subtype,
    final_penalty_subtype,
    math_pre_penalty_subtype,
    math_post_penalty_subtype,
    before_display_penalty_subtype,
    after_display_penalty_subtype,
    equation_number_penalty_subtype,
} penalty_subtypes;

# define last_penalty_subtype equation_number_penalty_subtype

/*tex
    We have plenty of glue variables and in the node lists most are also flagged. There is no
    one|-|to|-|one correspondence between the codes (in tokens) and subtypes (in nodes) as listed
    below, but they come close. The special math related glues and inserts now have nicer numbers.
*/

typedef enum glue_subtypes {
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
    zero_space_skip_glue,
    par_fill_right_skip_glue,
    par_fill_left_skip_glue,
    par_init_right_skip_glue,
    par_init_left_skip_glue,
    indent_skip_glue,
    left_hang_skip_glue,
    right_hang_skip_glue,
    correction_skip_glue,
    inter_math_skip_glue,
    ignored_glue,           /*tex |subtype| for cases where we ignore zero glue (alignments) */
    page_glue,              /*tex |subtype| used in the page builder */
    /*tex math */
    math_skip_glue,
    thin_mu_skip_glue,
    med_mu_skip_glue,
    thick_mu_skip_glue,
    /*tex more math */
    conditional_math_glue,  /*tex special |subtype| to suppress glue in the next node */ /* no need for jump */
    rulebased_math_glue,
    mu_glue,                /*tex |subtype| for math glue */
    /*tex leaders (glue with list) */
    a_leaders,              /*tex |subtype| for aligned leaders */
    c_leaders,              /*tex |subtype| for centered leaders */
    x_leaders,              /*tex |subtype| for expanded leaders */
    g_leaders,              /*tex |subtype| for global (page) leaders */
    u_leaders,
} glue_subtypes;

# define last_glue_subtype u_leaders

typedef enum skip_glue_codes_alias {
    par_fill_skip_glue = par_fill_right_skip_glue,
} skip_glue_codes_alias;

# define is_leader(a) (node_subtype(a) >= a_leaders)

# define glue_node_size        7
# define glue_spec_size        5
# define glue_data(a)          vinfo(a,2) /* ignored in spec */
# define glue_amount(a)        vlink(a,2)
# define glue_shrink(a)        vinfo(a,3)
# define glue_stretch(a)       vlink(a,3)
# define glue_stretch_order(a) vinfo(a,4)
# define glue_shrink_order(a)  vlink(a,4)
# define glue_font(a)          vinfo(a,5) /* not in spec */ /* when inter_math_skip_glue: parameter */
# define glue_leader_ptr(a)    vlink(a,5) /* not in spec */
# define glue_options(a)       vinfo(a,6) /* not in spec */ /* for now only internal */
# define glue_unused(a)        vlink(a,6) /* not in spec */

inline static void tex_add_glue_option    (halfword a, halfword r) { glue_options(a) |= r; }
inline static void tex_remove_glue_option (halfword a, halfword r) { glue_options(a) &= ~(r | glue_options(a)); }
inline static int  tex_has_glue_option    (halfword a, halfword r) { return (glue_options(a) & r) == r; }

typedef enum glue_option_codes {
    glue_option_normal        = 0x0000,
 // glue_force_auto_break     = 0x0001,
 // glue_originates_in_math   = 0x0002,
    glue_option_no_auto_break = 0x0001,
} glue_option_codes; 

typedef enum math_subtypes {
    begin_inline_math,
    end_inline_math
} math_subtypes;

# define last_math_subtype end_inline_math

/*tex
    Math nodes (currently) partially overlap with glue because they also have a glue property.
*/

# define math_node_size        6
# define math_surround(a)      vinfo(a,2)
# define math_amount(a)        vlink(a,2)
# define math_shrink(a)        vinfo(a,3)
# define math_stretch(a)       vlink(a,3)
# define math_stretch_order(a) vinfo(a,4)
# define math_shrink_order(a)  vlink(a,4)
# define math_penalty(a)       vinfo(a,5)
# define math_options(a)       vlink(a,5) 

inline static void tex_add_math_option    (halfword a, halfword r) { math_options(a) |= r; }
inline static void tex_remove_math_option (halfword a, halfword r) { math_options(a) &= ~(r | math_options(a)); }
inline static int  tex_has_math_option    (halfword a, halfword r) { return (math_options(a) & r) == r; }

/*tex Here are some (inline) helpers. We need specific ones for math glue. */

inline static int tex_glue_is_zero(halfword g)
{
    return (! g) || ((glue_amount(g) == 0) && (glue_stretch(g) == 0) && (glue_shrink(g) == 0));
}

inline static int tex_math_glue_is_zero(halfword g)
{
    return (! g) || ((math_amount(g) == 0) && (math_stretch(g) == 0) && (math_shrink(g) == 0));
}

inline static int tex_same_glue(halfword a, halfword b)
{
    return
        (a == b) /* same glue specs or both zero */
     || (a && b && glue_amount(a)        == glue_amount(b)
                && glue_stretch(a)       == glue_stretch(b)
                && glue_shrink(a)        == glue_shrink(b)
                && glue_stretch_order(a) == glue_stretch_order(b)
                && glue_shrink_order(a)  == glue_shrink_order(b)
        )
    ;
}

inline static void tex_reset_glue_to_zero(halfword target)
{
    if (target) {
        glue_amount(target) = 0;
        glue_stretch(target) = 0;
        glue_shrink(target) = 0;
        glue_stretch_order(target) = 0;
        glue_shrink_order(target) = 0;
    }
}

inline static void tex_reset_math_glue_to_zero(halfword target)
{
    if (target) {
        math_amount(target) = 0;
        math_stretch(target) = 0;
        math_shrink(target) = 0;
        math_stretch_order(target) = 0;
        math_shrink_order(target) = 0;
    }
}

inline static void tex_copy_glue_values(halfword target, halfword source)
{
    if (source) {
        glue_amount(target) = glue_amount(source);
        glue_stretch(target) = glue_stretch(source);
        glue_shrink(target) = glue_shrink(source);
        glue_stretch_order(target) = glue_stretch_order(source);
        glue_shrink_order(target) = glue_shrink_order(source);
    } else {
        glue_amount(target) = 0;
        glue_stretch(target) = 0;
        glue_shrink(target) = 0;
        glue_stretch_order(target) = 0;
        glue_shrink_order(target) = 0;
    }
}

inline static int tex_is_par_init_glue(halfword n)
{
    switch (node_subtype(n)) {
        case indent_skip_glue:
        case par_init_left_skip_glue:
        case par_init_right_skip_glue:
            return 1;
        default:
            return 0;
    }
}

/*tex
    Kern nodes are relatively simple. Instead of |width| we use |kern_amount| which  makes more
    sense: we can go left, right, up or down. Margin kerns have been dropped and are now just a
    special subtype of regular kerns.
*/

typedef enum kern_subtypes {
    font_kern_subtype,
    explicit_kern_subtype,      /*tex |subtype| of kern nodes from |\kern| and |\/| */
    accent_kern_subtype,        /*tex |subtype| of kern nodes from accents */
    italic_kern_subtype,
    left_margin_kern_subtype,
    right_margin_kern_subtype,
    explicit_math_kern_subtype,
    math_shape_kern_subtype,
    horizontal_math_kern_subtype,
    vertical_math_kern_subtype,
} kern_subtypes;

# define last_kern_subtype vertical_math_kern_subtype

# define kern_node_size       3
# define kern_amount(a)       vlink(a,2) /*tex aka |width = vlink(a,2)| */
# define kern_expansion(a)    vinfo(a,2) /*tex expansion factor (hz) */

inline static int tex_is_margin_kern(halfword n)
{
    return (n && node_type(n) == kern_node && (node_subtype(n) == left_margin_kern_subtype || node_subtype(n) == right_margin_kern_subtype));
}

/*tex

    Disc nodes are complicated: they have three embedded nesting nodes to which the |pre_break|,
    |post_break| and |no_break| fields point. In there we find a head pointer (|vlink| aka |hlink|)
    and tail pointer (|tlink|). The |alink| pointer is used in the base mode font machinery and is
    not really a prev pointer. We have to make sure it gets nilled when we communicate with \LUA.

    The no-, pre-, and postbreak fields point to nesting nodes that are part of the disc node (three
    times two memorywords). Sometimes these nodes are actually used, for instance when a temp node
    is expected at the head of a list. The layout is:

    \starttyping
    [ type+subtype + next      ]
    [ attr         + prev      ]
    [ penalty      + nobreak   ]
    [ prebreak     + postbreak ]
    [ type+subtype next/hlink  ] (nesting node prebreak)
    [ tlink        prev        ]
    [ type+subtype next/hlink  ] (nesting node postbreak)
    [ tlink        prev        ]
    [ type+subtype next/hlink  ] (nesting node nobreak)
    [ tlink        prev        ]
    \stoptyping

    Another reason why we need the indirect apoproach is that we can set the fields to |null| which
    is better than point to a nest node with no following up.

*/

/*tex
    Among the dropped nodes (\LUATEX\ has them) are movements nodes (used in the \DVI\ backend)
    and variable nodes (replaced by specification nodes).

    Nesting nodes are really simple and just use the common type, subtype and next fields so they
    have no dedicated fields. They can be part of another node type (like disc nodes).
*/

# define nesting_node_size 2

typedef enum nesting_subtypes {
    pre_break_code,
    post_break_code,
    no_break_code,
    insert_head_code,
    unset_nesting_code,
} nesting_subtypes;

# define last_nesting_subtype unset_nesting_code

/*tex Here the codes in commands and subtypes are in sync. */

typedef enum discretionary_subtypes {
    normal_discretionary_code,
    explicit_discretionary_code,
    automatic_discretionary_code,
    mathematics_discretionary_code,
    syllable_discretionary_code,
} discretionary_subtypes;

# define last_discretionary_subtype syllable_discretionary_code
# define last_discretionary_code    automatic_discretionary_code

typedef enum disc_options {
    disc_option_normal_word = 0x0,
    disc_option_pre_word    = 0x1,
    disc_option_post_word   = 0x2,
} disc_options;

# define disc_node_size       13
# define disc_no_break(a)     vlink(a,2) /* beware: vinfo is used for type/subtype */
# define disc_pre_break(a)    vlink(a,3) /* beware: vinfo is used for type/subtype */
# define disc_post_break(a)   vlink(a,4) /* beware: vinfo is used for type/subtype */
/*       disc_no_break_node   5  6 */    /* this is a nesting node of size 2 */
/*       disc_pre_break_node  7  8 */    /* this is a nesting node of size 2 */
/*       disc_post_break_node 9 10 */    /* this is a nesting node of size 2 */
# define disc_penalty(a)      vinfo(a,11)
# define disc_options(a)      vlink(a,11)
# define disc_class(a)        vinfo(a,12)
# define disc_unused(a)       vlink(a,12)

# define set_disc_penalty(a,b) disc_penalty(a) = b
# define set_disc_class(a,b)   disc_class(a) = b
# define set_disc_options(a,b) disc_options(a) = b
# define set_disc_option(a,b)  disc_options(a) |= b

# define has_disc_option(a,b) ((disc_options(a) & b) == b)

# define unset_disc_class -1

/*tex
    These are pseudo nodes inside a node. We used to reference them by |*_break_head| but now call
    just call them nodes so that we can use head and tail instead of hlink and tlink.
*/

# define disc_pre_break_node(a)   (a+5)
# define disc_post_break_node(a)  (a+7)
# define disc_no_break_node(a)    (a+9)

# define disc_pre_break_head(a)  node_head(disc_pre_break_node(a))
# define disc_post_break_head(a) node_head(disc_post_break_node(a))
# define disc_no_break_head(a)   node_head(disc_no_break_node(a))

# define disc_pre_break_tail(a)  node_tail(disc_pre_break_node(a))
# define disc_post_break_tail(a) node_tail(disc_post_break_node(a))
# define disc_no_break_tail(a)   node_tail(disc_no_break_node(a))

extern void     tex_set_disc_field          (halfword target, halfword location, halfword source);
extern void     tex_check_disc_field        (halfword target);
extern void     tex_set_discpart            (halfword d, halfword h, halfword t, halfword code);
extern halfword tex_flatten_discretionaries (halfword head, int *count, int nest);
extern void     tex_flatten_leaders         (halfword box, int *count);
extern void     tex_soften_hyphens          (halfword head, int *found, int *replaced);
extern halfword tex_harden_spaces           (halfword head, halfword tolerance, int *count);

/*tex
    Lists need a rather large node, also because the have quite some extra possibilities, like the
    orientation features. We can put the dir with the orientation but it becomes messy in casting
    that way. Also, memory is not really a constraint and for a cpu cache we're better off this
    way.

    In the original setup the unset and align_record nodes have overlapping fields. This has the
    side effect that when we access the alternates from \LUA\ that they can have weird values
    unless we reset them. Even then, it can be that we actually want to use those other fields
    somehow. For that reason it's better to waste a few more slots and play safe. We can now
    actually explore table cells with offsets if we want.

    Beware: in alignments

    \startitemize[packed]
    \startitem align record nodes become unset nodes \stopitem
    \startitem unset nodes become hlist or vlist nodes \stopitem
    \stopitemize
*/

typedef enum list_subtypes {
    unknown_list,
    line_list,                 /*tex paragraph lines */
    hbox_list,                 /*tex |\hbox| */
    indent_list,               /*tex indentation box */
    container_list,            /*tex container box */
    align_row_list,            /*tex row from a |\halign| or |\valign| */
    align_cell_list,           /*tex cell from a |\halign| or |\valign| */
    equation_list,             /*tex display equation */
    equation_number_list,      /*tex display equation number */
    math_list_list,
    math_char_list,
    math_pack_list,
    math_h_extensible_list,
    math_v_extensible_list,
    math_h_delimiter_list,
    math_v_delimiter_list,
    math_over_delimiter_list,
    math_under_delimiter_list,
    math_numerator_list,
    math_denominator_list,
    math_modifier_list,
    math_fraction_list,
    math_nucleus_list,
    math_sup_list,
    math_sub_list,
    math_pre_post_list,
    math_degree_list,
    math_scripts_list,
    math_over_list,
    math_under_list,
    math_accent_list,
    math_radical_list,
    math_fence_list,
    math_rule_list,
    math_ghost_list,
    insert_result_list,
    local_list,
    local_left_list,
    local_right_list,
    local_middle_list,
} list_subtypes ;

# define last_list_subtype     local_middle_list
# define noad_class_list_base  0x0100

typedef enum list_anchors {
    left_origin_anchor    = 0x001,
    left_height_anchor    = 0x002,
    left_depth_anchor     = 0x003,
    right_origin_anchor   = 0x004,
    right_height_anchor   = 0x005,
    right_depth_anchor    = 0x006,
    center_origin_anchor  = 0x007,
    center_height_anchor  = 0x008,
    center_depth_anchor   = 0x009,
    halfway_total_anchor  = 0x00A,
    halfway_height_anchor = 0x00B,
    halfway_depth_anchor  = 0x00C,
    halfway_left_anchor   = 0x00D,
    halfway_right_anchor  = 0x00E,
} list_anchors;

typedef enum list_signs {
    negate_x_anchor = 0x100,
    negate_y_anchor = 0x200,
} list_signs;

typedef enum list_geometries {
    no_geometry          = 0x0,
    offset_geometry      = 0x1,
    orientation_geometry = 0x2,
    anchor_geometry      = 0x4,
} list_geometries;

# define box_node_size          15
# define box_width(a)           vlink(a,2)
# define box_w_offset(a)        vinfo(a,2)
# define box_depth(a)           vlink(a,3)
# define box_d_offset(a)        vinfo(a,3)
# define box_height(a)          vlink(a,4)
# define box_h_offset(a)        vinfo(a,4)
# define box_list(a)            vlink(a,5)    /* 5 = list_offset */
# define box_shift_amount(a)    vinfo(a,5)
# define box_glue_order(a)      vlink(a,6)
# define box_glue_sign(a)       vinfo(a,6)
# define box_glue_set(a)        dvalue(a,7)   /* So we reserve a whole memory word! */
# define box_dir(a)             vlink00(a,8)  /* We could encode it as geomtry but not now. */
# define box_package_state(a)   vlink01(a,8)
# define box_axis(a)            vlink02(a,8)
# define box_geometry(a)        vlink03(a,8)
# define box_orientation(a)     vinfo(a,8)    /* Also used for size in alignments. */
# define box_x_offset(a)        vlink(a,9)
# define box_y_offset(a)        vinfo(a,9)
# define box_pre_migrated(a)    vlink(a,10)
# define box_post_migrated(a)   vinfo(a,10)
# define box_pre_adjusted(a)    vlink(a,11)
# define box_post_adjusted(a)   vinfo(a,11)
# define box_source_anchor(a)   vlink(a,12)
# define box_target_anchor(a)   vinfo(a,12)
# define box_anchor(a)          vlink(a,13)
# define box_index(a)           vinfo(a,13)
# define box_input_file(a)      vlink(a,14) /* aka box_synctex_tag  */
# define box_input_line(a)      vinfo(a,14) /* aka box_synctex_line */

# define box_total(a) (box_height(a) + box_depth(a)) /* Here we add, with glyphs we maximize. */ 

inline static void tex_set_box_geometry   (halfword b, halfword g) { box_geometry(b) |= (singleword) (g); }
/*     static void tex_unset_box_geometry (halfword b, halfword g) { box_geometry(b) &= (singleword) ~((singleword) (g) | box_geometry(b)); } */
inline static void tex_unset_box_geometry (halfword b, halfword g) { box_geometry(b) &= (singleword) (~g); }
inline static int  tex_has_geometry       (halfword g, halfword f) { return ((singleword) (g) & (singleword) (f)) == (singleword) (f); }
inline static int  tex_has_box_geometry   (halfword b, halfword g) { return (box_geometry(b) & (singleword) (g)) == (singleword) (g); }

typedef enum package_states {
    unknown_package_state = 0x00,
    hbox_package_state    = 0x01,
    vbox_package_state    = 0x02,
    vtop_package_state    = 0x03,
    /* maybe vcenter */
} package_states;

typedef enum package_dimension_states {
    package_dimension_not_set  = 0x00,
    package_dimension_size_set = 0x04,
} package_dimension_states;

typedef enum package_leader_states {
    package_u_leader_not_set  = 0x00,
    package_u_leader_set      = 0x08,
    package_u_leader_delayed  = 0x10,
} package_leader_states;

# define set_box_package_state(p,s) box_package_state(p) |= s
# define has_box_package_state(p,s) ((box_package_state(p) & s) == s)
# define is_box_package_state(p,s)  ((p & s) == s)

typedef enum list_axis { /* or maybe math states */
    no_math_axis = 0x01,
} list_axis;

# define has_box_axis(p,s) ((box_axis(p) & s) == s)
# define set_box_axis(p,s) box_axis(p) |= (s & 0xFF)

/*tex
    These |unset| nodes have the same layout as list nodes and at some point become an |hlist| or
    |vlist| node.
*/

# define unset_node_size     box_node_size
# define box_glue_stretch(a) box_w_offset(a)
# define box_glue_shrink(a)  box_h_offset(a)
# define box_span_count(a)   box_d_offset(a)
# define box_size(a)         box_orientation(a)

/*tex
    The |align record| nodes have the same layout as list nodes and at some point become an |unset|
    node.
*/

# define align_record_size         box_node_size
# define align_record_span_ptr(a)  box_w_offset(a)    /*tex A column spanning list */
# define align_record_cmd(a)       box_h_offset(a)    /*tex Info to remember during template. */
# define align_record_chr(a)       box_d_offset(a)    /*tex Info to remember during template. */
# define align_record_pre_part(a)  box_x_offset(a)    /*tex The pointer to |u_j| token list. */
# define align_record_post_part(a) box_y_offset(a)    /*tex The pointer to |v_j| token list. */
# define align_record_dimension(a) box_orientation(a) /*tex Optionally enforced width. */

/*tex
   Span nodes are tricky in the sense that their |span_link| actually has to sit in the same slot
   as |align_record_span_ptr| because we need the initial location to be the same. This is why we
   renamed this field to |span_ptr|. Moving it to another spot than in \LUATEX\ also opens the
   possibility for attributes to cells.
*/

# define span_node_size 3
# define span_span(a)   vinfo(a,1)
# define span_unused(a) vlink(a,1)
# define span_width(a)  vlink(a,2)  /* overlaps with |box_width(a)|. */
# define span_ptr(a)    vinfo(a,2)  /* overlaps with |box_w_offset(a)| and align_record_span_ptr(a). */

/*tex
    Here the subtypes and command codes partly overlay. We actually hav eonly avery few left because
    it's mostly a backend feature now.
*/

typedef enum rule_subtypes {
    normal_rule_subtype,
    empty_rule_subtype,
    strut_rule_subtype,
    outline_rule_subtype,
    user_rule_subtype,
    math_over_rule_subtype,
    math_under_rule_subtype,
    math_fraction_rule_subtype,
    math_radical_rule_subtype,
    box_rule_subtype,
    image_rule_subtype,
} rule_subtypes;

typedef enum rule_codes {
    normal_rule_code,
    empty_rule_code,
    strut_rule_code,
} rule_codes;

# define last_rule_subtype image_rule_subtype
# define first_rule_code   normal_rule_code
# define last_rule_code    strut_rule_code

# define rule_node_size    7
# define rule_width(a)     vlink(a,2)
# define rule_x_offset(a)  vinfo(a,2)
# define rule_depth(a)     vlink(a,3)
# define rule_y_offset(a)  vinfo(a,3)
# define rule_height(a)    vlink(a,4)
# define rule_data(a)      vinfo(a,4)
# define rule_left(a)      vinfo(a,5)
# define rule_right(a)     vlink(a,5)
# define rule_font(a)      vinfo(a,6)
# define rule_character(a) vlink(a,6)

# define rule_total(a) (rule_height(a) + rule_depth(a))

/*tex

    Originally glyph nodes had a |lig_ptr| but storing components makes not that much sense so we
    dropped that. The free slot is now used for a state field. We already had a data field that
    took another free slot and that behaves like an attribute. The glyph data field can be set at
    the \TEX\ end, the state field is only accessible in \LUA. At the same time we reshuffled the
    fields a bit so that the most accessed fields are close together.

    The \LUATEX\ engine dropped the language node and moved that feature to the glyph nodes. In
    addition to the language more properties could be set but they were all packed into one
    halfword. In \LUAMETATEX\ we waste a few more bytes and keep the language separate but we
    still pack a few properties.

    In \TEX\ we have character nodes and glyph nodes, but here we only have one type. The subtype
    can be used to indicate if we have ligatures but in \LUATEX\ for various reasons we don't follow
    the integrated approach that \TEX\ has: we have callbacks for hyphenation, ligature building,
    kerning etc.\ which demands separation, but more important is that we want to use \LUA\ to deal
    with modern fonts. The components field that is still present in \LUATEX\ is gone because it
    serves no purpose. We don't need to reassemble and when dealing with \OPENTYPE\ fonts we loose
    information in successive steps anyway.

    This also makes that the subtype is now only used to flag if glyphs have been processed. The
    macro package can decide what additional properties get stored in this field.

    We used to have this:

    \starttyping
    inline static void protect_glyph      (halfword a) { quarterword s = node_subtype(a) ; if (s <= 256) { node_subtype(a) = s == 1 ? 256 : 256 + s; } }
    inline static void unprotect_glyph    (halfword a) { quarterword s = node_subtype(a) ; if (s >  256) { node_subtype(a) = s - 256; } }
    inline static int  is_protected_glyph (halfword a) { return node_subtype(a) >= 256; }
    \stoptyping

    These were also dropped:

    \starttyping
    # define is_character(p)        (((node_subtype(p)) & glyph_character) == glyph_character)
    # define is_ligature(p)         (((node_subtype(p)) & glyph_ligature ) == glyph_ligature )
    # define is_simple_character(p) (is_character(p) && ! is_ligature(p))
    # define set_is_glyph(p)         node_subtype(p) = (quarterword) (node_subtype(p) & ~glyph_character)
    \stoptyping

*/

/*tex

    Putting |width|, |height| and |depth| in a glyph has some advantages, for instance when we
    fetch them in the builder, packer, \LUA\ interface, but it also has a disadvantage: we need to
    have more complex copying of glyph nodes. For instance, when we copy glyphs in the open type
    handler (e.g. for multiples) we also copy the fields. But then when we set a character, we also
    would have to set the dimensions. Okay, some helper could do that (or a flag in setchar). It's
    anyway not something to do in a hurry. An |x_extra| field is something different: combined with
    setting |x_offset| that could replace font kerns: |x_advance = width + x_offset + x_extra|.

*/

//define glyph_node_size     12
# define glyph_node_size     13
# define glyph_character(a)  vinfo(a,2)
# define glyph_font(a)       vlink(a,2)
# define glyph_data(a)       vinfo(a,3)   /*tex We had that unused, so now it's like an attribute. */
# define glyph_state(a)      vlink(a,3)   /*tex A user field (can be handy in \LUA). */
# define glyph_language(a)   vinfo(a,4)
# define glyph_script(a)     vlink(a,4)
# define glyph_options(a)    vinfo(a,5)
# define glyph_hyphenate(a)  vlink(a,5)
# define glyph_protected(a)  vinfo00(a,6)
# define glyph_lhmin(a)      vinfo01(a,6)
# define glyph_rhmin(a)      vinfo02(a,6)
# define glyph_discpart(a)   vinfo03(a,6)
# define glyph_expansion(a)  vlink(a,6)
# define glyph_x_scale(a)    vinfo(a,7)
# define glyph_y_scale(a)    vlink(a,7)
# define glyph_scale(a)      vinfo(a,8)
# define glyph_raise(a)      vlink(a,8)
# define glyph_left(a)       vinfo(a,9)
# define glyph_right(a)      vlink(a,9)
# define glyph_x_offset(a)   vinfo(a,10)
# define glyph_y_offset(a)   vlink(a,10)
//define glyph_input_file(a) vinfo(a,11) /* aka glyph_synctex_tag  */
//define glyph_input_line(a) vlink(a,11) /* aka glyph_synctex_line */
# define glyph_properties(a) vinfo0(a,11)
# define glyph_group(a)      vinfo1(a,11)
# define glyph_index(a)      vlink(a,11)
# define glyph_input_file(a) vinfo(a,12) 
# define glyph_input_line(a) vlink(a,12) 

# define get_glyph_data(a)      ((halfword) glyph_data(a))
# define get_glyph_state(a)     ((halfword) glyph_state(a))
# define get_glyph_language(a)  ((halfword) glyph_language(a))
# define get_glyph_script(a)    ((halfword) glyph_script(a))
# define get_glyph_x_scale(a)   ((halfword) glyph_x_scale(a))
# define get_glyph_y_scale(a)   ((halfword) glyph_y_scale(a))
# define get_glyph_scale(a)     ((halfword) glyph_scale(a))
# define get_glyph_raise(a)     ((halfword) glyph_raise(a))
# define get_glyph_lhmin(a)     ((halfword) glyph_lhmin(a))
# define get_glyph_rhmin(a)     ((halfword) glyph_rhmin(a))
# define get_glyph_left(a)      ((halfword) glyph_left(a))
# define get_glyph_right(a)     ((halfword) glyph_right(a))
# define get_glyph_hyphenate(a) ((halfword) glyph_hyphenate(a))
# define get_glyph_options(a)   ((halfword) glyph_options(a))
# define get_glyph_dohyph(a)    (hyphenation_permitted(glyph_hyphenate(a), syllable_hyphenation_mode ) || hyphenation_permitted(glyph_hyphenate(a), force_handler_hyphenation_mode))
# define get_glyph_uchyph(a)    (hyphenation_permitted(glyph_hyphenate(a), uppercase_hyphenation_mode) || hyphenation_permitted(glyph_hyphenate(a), force_handler_hyphenation_mode))

# define set_glyph_data(a,b)      glyph_data(a) = b
# define set_glyph_state(a,b)     glyph_state(a) = b
# define set_glyph_language(a,b)  glyph_language(a) = b
# define set_glyph_script(a,b)    glyph_script(a) = b
# define set_glyph_x_scale(a,b)   glyph_x_scale(a) = b
# define set_glyph_y_scale(a,b)   glyph_y_scale(a) = b
# define set_glyph_x_offset(a,b)  glyph_x_offset(a) = b
# define set_glyph_y_offset(a,b)  glyph_y_offset(a) = b
# define set_glyph_scale(a,b)     glyph_scale(a) = b
# define set_glyph_raise(a,b)     glyph_raise(a) = b
# define set_glyph_left(a,b)      glyph_left(a) = b
# define set_glyph_right(a,b)     glyph_right(a) = b
# define set_glyph_lhmin(a,b)     glyph_lhmin(a) = (singleword) b
# define set_glyph_rhmin(a,b)     glyph_rhmin(a) = (singleword) b
# define set_glyph_hyphenate(a,b) glyph_hyphenate(a) = ((halfword) b)
# define set_glyph_options(a,b)   glyph_options(a) = ((halfword) b)
/*       set_glyph_dohyph(a,b)    glyph_hyphenate(a) = ((halfword) flip_hyphenation_mode(glyph_hyphenate(a),syllable_hyphenation_mode)) */
# define set_glyph_uchyph(a,b)    glyph_hyphenate(a) = ((halfword) flip_hyphenation_mode(glyph_hyphenate(a),uppercase_hyphenation_mode))
# define set_glyph_discpart(a,b)  glyph_discpart(a) = (singleword) (b)
# define get_glyph_discpart(a)    ((halfword) glyph_discpart(a))

typedef enum glyph_subtypes {
    /* initial value: */
    glyph_unset_subtype,
    /* traditional text: */
    glyph_character_subtype,
    glyph_ligature_subtype,
    /* special math */
    glyph_math_delimiter_subtype,
    glyph_math_extensible_subtype,
    /* engine math, class driven */
    glyph_math_ordinary_subtype,
    glyph_math_operator_subtype,
    glyph_math_binary_subtype,
    glyph_math_relation_subtype,
    glyph_math_open_subtype,
    glyph_math_close_subtype,
    glyph_math_punctuation_subtype,
    glyph_math_variable_subtype,
    glyph_math_active_subtype,
    glyph_math_inner_subtype,
    glyph_math_under_subtype,
    glyph_math_over_subtype,
    glyph_math_fraction_subtype,
    glyph_math_radical_subtype,
    glyph_math_middle_subtype,
    glyph_math_accent_subtype,
    glyph_math_fenced_subtype,
    glyph_math_ghost_subtype,
    /* extra math, user classes, set but anonymous */
    glyph_math_extra_subtype = 31,
} glyph_subtypes;

# define last_glyph_subtype glyph_math_accent_subtype

typedef enum glyph_hstate_codes {
    glyph_discpart_unset,
    glyph_discpart_pre,
    glyph_discpart_post,
    glyph_discpart_replace,
    glyph_discpart_always,
} glyph_hstate_codes;

typedef enum glyph_option_codes {
    /*tex These are part of the defaults (all): */
    glyph_option_normal_glyph         = 0x0000,
    glyph_option_no_left_ligature     = 0x0001,
    glyph_option_no_right_ligature    = 0x0002,
    glyph_option_no_left_kern         = 0x0004,
    glyph_option_no_right_kern        = 0x0008,
    glyph_option_no_expansion         = 0x0010,
    glyph_option_no_protrusion        = 0x0020,
    glyph_option_apply_x_offset       = 0x0040,
    glyph_option_apply_y_offset       = 0x0080,
    glyph_option_no_italic_correction = 0x0100,
    /* These are only meant for math characters: */
    glyph_option_math_discretionary   = 0x0200,
    glyph_option_math_italics_too     = 0x0400,
    /*tex So watch out: this is a subset! */
    glyph_option_all                  = 0x01FF,
} glyph_option_codes;

typedef enum auto_discretionary_codes {
    auto_discretionary_normal = 0x0001, /* turn glyphs into discretionary with three similar components */
    auto_discretionary_italic = 0x0002, /* also include italic correcxtion when present */
} auto_discretionary_codes;

inline static void tex_add_glyph_option    (halfword a, halfword r) { glyph_options(a) |= r; }
inline static void tex_remove_glyph_option (halfword a, halfword r) { glyph_options(a) &= ~(r | glyph_options(a)); }
inline static int  tex_has_glyph_option    (halfword a, halfword r) { return (glyph_options(a) & r) == r; }

/*tex
    As we have a small field available for protection we no longer need to pack the protection
    state in the subtype. We can now basically use the subtype for anything we want (as long as it
    stays within the range |0x0000-0xFFFF|.
*/

/* inline static void tex_protect_glyph      (halfword a) {        node_subtype(a) |= (quarterword) 0x8000; } */
/* inline static void tex_unprotect_glyph    (halfword a) {        node_subtype(a) &= (quarterword) 0x7FFF; } */
/* inline static int  tex_is_protected_glyph (halfword a) { return node_subtype(a) >= (quarterword) 0x8000; } */
/* inline static int  tex_subtype_of_glyph   (halfword a) { return node_subtype(a) &  (quarterword) 0x7FFF; } */

typedef enum glyph_protection_codes {
    glyph_unprotected_code    = 0x0,
    glyph_protected_text_code = 0x1,
    glyph_protected_math_code = 0x2,
} glyph_protection_codes;

/*tex
    Next come some very specialized nodes types. First the marks. They just register a token list.
*/

# define mark_node_size 3
# define mark_ptr(a)    vlink(a,2)
# define mark_index(a)  vinfo(a,2)

typedef enum mark_codes {
    set_mark_value_code,
    reset_mark_value_code,
} mark_codes;

# define last_mark_subtype reset_mark_value_code

/*tex
    The (not really used in \CONTEXT) |\vadjust| nodes are also small. The codes and subtypes
    overlap.
*/

typedef enum adjust_subtypes {
    pre_adjust_code,
    post_adjust_code,
    local_adjust_code,
} adjust_subtypes;

typedef enum adjust_options {
    adjust_option_none         = 0x00,
    adjust_option_before       = 0x01,
    adjust_option_baseline     = 0x02,
    adjust_option_depth_before = 0x04,
    adjust_option_depth_after  = 0x08,
    adjust_option_depth_check  = 0x10,
    adjust_option_depth_last   = 0x20,
} adjust_options;

# define last_adjust_subtype local_adjust_code

# define adjust_node_size       5
# define adjust_list(a)         vlink(a,2)
# define adjust_options(a)      vinfo(a,2)
# define adjust_index(a)        vlink(a,3)
# define adjust_reserved(a)     vinfo(a,3)
# define adjust_depth_before(a) vlink(a,4)
# define adjust_depth_after(a)  vinfo(a,4)

# define has_adjust_option(p,o) ((adjust_options(p) & o) == o)

/*tex
    Inserts are more complicated. The |ins| node stores an insert in the list while |inserting|
    nodes keep track of where to break the page so that they (hopefully) stay with the text. As
    already mentioned, the insert node is tricky in the sense that it uses an offset to an
    embedded (fake) node. That node acts as start of a next chain. Making that more transparent
    would demand some changes that I'm not willing to make right now (and maybe never).
*/

# define insert_node_size       6          /* can become 1 smaller or we can have insert_index instead of subtype */
# define insert_index(a)        vinfo(a,2) /* width is not used */
# define insert_float_cost(a)   vlink(a,2)
# define insert_max_depth(a)    vlink(a,3)
# define insert_total_height(a) vlink(a,4) /* the sum of height and depth, i.e. total */
# define insert_list(a)         vinfo(a,5) /* is alias for |node_next|*/
# define insert_split_top(a)    vlink(a,5) /* a state variable */

# define insert_first_box(a)    (a + 5)    /*tex A fake node where box_list_ptr becomes a next field. */

# define split_node_size        5          /*tex Can become a |split_up_node|. */
# define split_insert_index(a)  vinfo(a,2) /*tex Same slot! */
# define split_broken(a)        vlink(a,2) /*tex An insertion for this class will break here if anywhere. */
# define split_broken_insert(a) vinfo(a,3) /*tex This insertion might break at |broken_ptr|. */
# define split_last_insert(a)   vlink(a,3) /*tex The most recent insertion for this |subtype|. */
# define split_best_insert(a)   vinfo(a,4) /*tex The optimum most recent insertion. */
# define split_height(a)        vlink(a,4) /*tex Aka |height(a) = vlink(a,4)| */ /* todo */

typedef enum split_subtypes {
    normal_split_subtype,
    insert_split_subtype,
} split_subtypes;

# define last_split_subtype insert_split_subtype

/*tex
    It's now time for some Some handy shortcuts. These are used when determining proper break points
    and|/|or the beginning or end of words.
*/

# define last_preceding_break_node whatsit_node
# define last_non_discardable_node dir_node
# define last_node_with_attributes glyph_node
# define last_complex_node         align_record_node
# define max_node_type             passive_node

# define precedes_break(a)  (node_type(a) <= last_preceding_break_node)
# define precedes_kern(a)   ((node_type(a) == kern_node) && (node_subtype(a) == font_kern_subtype || node_subtype(a) == accent_kern_subtype || node_subtype(a) == math_shape_kern_subtype))
# define precedes_dir(a)    ((node_type(a) == dir_node) && normalize_line_mode_permitted(normalize_line_mode_par,break_after_dir_mode))
# define non_discardable(a) (node_type(a) <= last_non_discardable_node)

inline static int tex_nodetype_is_complex     (halfword t) { return t <= last_complex_node; }
inline static int tex_nodetype_has_attributes (halfword t) { return t <= last_node_with_attributes; }
inline static int tex_nodetype_has_subtype    (halfword t) { return t != glue_spec_node && t != math_spec_node && t != font_spec_node; }
inline static int tex_nodetype_has_prev       (halfword t) { return t != glue_spec_node && t != math_spec_node && t != font_spec_node && t != attribute_node; }
inline static int tex_nodetype_has_next       (halfword t) { return t != glue_spec_node && t != math_spec_node && t != font_spec_node; }
inline static int tex_nodetype_is_visible     (halfword t) { return (t >= 0) && (t <= max_node_type) && lmt_interface.node_data[t].visible; }

/*tex
    This is a bit weird place to define them but anyway. In the meantime in \LUAMETATEX\ we no
    longer have the option to report the codes used in \ETEX. We have different nodes so it makes
    no sense to complicate matters (although earlier version of \LUAMETATEX\ has this organized
    quite well \unknown\ just an example of cleaning up, wondering about the use and then dropping
    it.
*/

# define get_node_size(i) (lmt_interface.node_data[i].size)
# define get_node_name(i) (lmt_interface.node_data[i].name)
/*       get_etex_code(i) (lmt_interface.node_data[i].etex) */

/*tex
    Although expressions could use some dedicated data structure, currently they are implemented
    using a linked list. This means that only memory is the limitation for recursion but I might
    as well go for a dedicated structure some day, just for the fun of implementing it. It is
    probably also more efficient. The current approach is inherited from \ETEX. The stack is only
    used when we have expressions between parenthesis.
*/

# define expression_node_size     3
# define expression_type(a)       vinfo00(a,1)   /*tex one of the value levels */
# define expression_state(a)      vinfo01(a,1)
# define expression_result(a)     vinfo02(a,1)
# define expression_unused(a)     vinfo03(a,1)
# define expression_expression(a) vlink(a,1)     /*tex saved expression so far */
# define expression_term(a)       vlink(a,2)     /*tex saved term so far */
# define expression_numerator(a)  vinfo(a,2)     /*tex saved numerator */

/*tex
    To be decided: go double 
*/

# define expression_entry(a)      lvalue(a,2)

/*tex
    This is a node that stores a font state. In principle we can do without but for tracing it
    really helps to have this compound element because it is more compact. We could have gone
    numeric and use the sparse array approach but then we'd have to add a 4 int store which is more
    code and also makes save and restore more complex.
*/

# define font_spec_node_size     4           /* we can be smaller: no attr and no prev */
# define font_spec_identifier(a) vinfo(a,2)
# define font_spec_scale(a)      vlink(a,2)
# define font_spec_x_scale(a)    vinfo(a,3)
# define font_spec_y_scale(a)    vlink(a,3)

inline static int tex_same_fontspec(halfword a, halfword b)
{
    return
        (a == b)
     || (a && b && font_spec_identifier(a) == font_spec_identifier(b)
                && font_spec_scale(a)      == font_spec_scale(b)
                && font_spec_x_scale(a)    == font_spec_x_scale(b)
                && font_spec_y_scale(a)    == font_spec_y_scale(b)
        )
    ;
}

/*tex
    At the cost of some more memory we now use a mode for storage. This not only overcomes the
    \UNICODE\ limitation but also permits storing more in the future.
*/

# define math_spec_node_size     3
# define math_spec_class(a)      vinfo00(a,1)  /* attr */
# define math_spec_family(a)     vinfo01(a,1)
# define math_spec_character(a)  vlink(a,1)    /* prev */
# define math_spec_properties(a) vinfo0(a,2)
# define math_spec_group(a)      vinfo1(a,2)
# define math_spec_index(a)      vlink(a,2)

# define math_spec_value(a)     (((math_spec_class(a) & 0x3F) << 12) + ((math_spec_family(a) & 0x3F) << 8) + (math_spec_character(a) & 0xFF))

inline static int tex_same_mathspec(halfword a, halfword b)
{
    return
        (a == b)
     || (a && b && math_spec_class(a)      == math_spec_class(b)
                && math_spec_family(a)     == math_spec_family(b)
                && math_spec_character(a)  == math_spec_character(b)
                && math_spec_properties(a) == math_spec_properties(b)
                && math_spec_group(a)      == math_spec_group(b)
                && math_spec_index(a)      == math_spec_index(b)
        )
    ;
}

/*tex
    Here are some more stack related nodes.
*/

# define align_stack_node_size                 10
# define align_stack_align_ptr(a)              vinfo(a,1)
# define align_stack_cur_align(a)              vlink(a,1)
# define align_stack_preamble(a)               vinfo(a,2)
# define align_stack_cur_span(a)               vlink(a,2)
# define align_stack_cur_loop(a)               vinfo(a,3)
# define align_stack_wrap_source(a)            vlink(a,3)
# define align_stack_align_state(a)            vinfo(a,4)
# define align_stack_no_align_level(a)         vlink(a,4)
# define align_stack_cur_post_adjust_head(a)   vinfo(a,5)
# define align_stack_cur_post_adjust_tail(a)   vlink(a,5)
# define align_stack_cur_pre_adjust_head(a)    vinfo(a,6)
# define align_stack_cur_pre_adjust_tail(a)    vlink(a,6)
# define align_stack_cur_post_migrate_head(a)  vinfo(a,7)
# define align_stack_cur_post_migrate_tail(a)  vlink(a,7)
# define align_stack_cur_pre_migrate_head(a)   vinfo(a,8)
# define align_stack_cur_pre_migrate_tail(a)   vlink(a,8)
# define align_stack_no_tab_skips(a)           vinfo(a,9)
# define align_stack_attr_list(a)              vlink(a,9)

/*tex
    If nodes are for nesting conditionals. We have more state information that in (for instance)
    \LUATEX\ because we have more tracing and more test variants.
*/

# define if_node_size            3             /*tex we can use prev now */
# define if_limit_type(a)        vinfo0(a,1)   /*tex overlaps with node_attr */
# define if_limit_subtype(a)     vinfo1(a,1)   /*tex overlaps with node_attr */
# define if_limit_unless(a)      vinfo00(a,2)
# define if_limit_step(a)        vinfo01(a,2)
# define if_limit_stepunless(a)  vinfo02(a,2)
# define if_limit_unused(a)      vinfo03(a,2)
# define if_limit_line(a)        vlink(a,2)

/*tex
    Now come some rather special ones. For instance par shapes and file cq.\ line related nodes
    were variable nodes. Thsi was dropped and replaced by a more generic specficiation node type.
    In principle we can use that for more purposes.

    We use a bit of abstraction as preparation for different allocations. Dynamic allocation makes
    it possible to get rid of variable nodes but it is slower.

    Because this node has no links we can use the next field as counter. The subtype is just for
    diagnostics. This node is special in the sense that it has a real pointer. Such nodes will not
    be stored in the format file. Because there is a pointer field we have some extra accessors.

    Todo: we also need to catch the fact that we can run out of memory but in practice that will
    not happen soon, for instance because we seldom use parshapes. And in the meantime the pseudo
    file related nodes are gone anyway because all file IO has been delegated to \LUA\ now.
*/

# define specification_node_size  3
# define specification_count(a)   vlink(a,0)
# define specification_options(a) vinfo(a,1)
# define specification_unused(a)  vlink(a,1)
# define specification_pointer(a) (mvalue(a,2))

typedef enum specification_options {
    specification_option_repeat = 0x01,
} specifications_options;

# define specification_index(a,n) ((memoryword *) specification_pointer(a))[n - 1]

# define specification_repeat(a)  ((specification_options(a) & specification_option_repeat) == specification_option_repeat)

# define specification_n(a,n)     (specification_repeat(a) ? ((n - 1) % specification_count(a) + 1) : (n > specification_count(a) ? specification_count(a) : n))

/* interesting: 1Kb smaller bin: */

// inline static halfword specification_n(halfword a, halfword n) { return specification_repeat(a) ? ((n - 1) % specification_count(a) + 1) : (n > specification_count(a) ? specification_count(a) : n); }

extern void            tex_null_specification_list     (halfword a);
extern void            tex_new_specification_list      (halfword a, halfword n, halfword o);
extern void            tex_dispose_specification_list  (halfword a);
extern void            tex_copy_specification_list     (halfword a, halfword b);
extern void            tex_shift_specification_list    (halfword a, int n, int rotate);

inline static int      tex_get_specification_count     (halfword a)                         { return specification_count(a); }
inline static halfword tex_get_specification_indent    (halfword a, halfword n)             { return specification_index(a,specification_n(a,n)).half0; }
inline static halfword tex_get_specification_width     (halfword a, halfword n)             { return specification_index(a,specification_n(a,n)).half1; }
inline static halfword tex_get_specification_penalty   (halfword a, halfword n)             { return specification_index(a,specification_n(a,n)).half0; }
inline static void     tex_set_specification_indent    (halfword a, halfword n, halfword v) { specification_index(a,n).half0 = v; }
inline static void     tex_set_specification_width     (halfword a, halfword n, halfword v) { specification_index(a,n).half1 = v; }
inline static void     tex_set_specification_penalty   (halfword a, halfword n, halfword v) { specification_index(a,n).half0 = v; }
inline static void     tex_set_specification_option    (halfword a, int o)                  { specification_options(a) |= o; }

extern        halfword tex_new_specification_node      (halfword n, quarterword s, halfword options);
extern        void     tex_dispose_specification_nodes (void);

/*tex
    We now define some math related nodes (and noads) and start with style and choice nodes. Style
    nodes can be smaller, the information is encoded in |subtype|, but choice nodes are on-the-spot
    converted to style nodes with slack. The advantage is that we don't run into issues when a choice
    node is the first node in which case we would have to adapt head pointers (read: feed them back
    into the calling routines). So, we keep this as it is now.

    Parameter nodes started out as an experiment. We could actually use the same mechanism as
    attributes but (1) we don't want attribute nodes in the list, it is very math specific and (3)
    we don't need to be real fast here.

    Maybe these three can be merged into one type but on the other hand they are part of the \TEX\
    legacy and well documented so \unknown for now we keep it as-is. In the meantime we are no 
    longer casting choices to styles. 

*/

# define style_node_size               3
# define style_style                   node_subtype
# define style_scale(a)                vinfo(a,2)
# define style_reserved(a)             vlink(a,2)

# define choice_node_size              5
//define choice_style                  node_subtype
# define choice_display_mlist(a)       vinfo(a,2) /*tex mlist to be used in display style or pre_break */
# define choice_text_mlist(a)          vlink(a,2) /*tex mlist to be used in text style or post_break */
# define choice_script_mlist(a)        vinfo(a,3) /*tex mlist to be used in script style or no_break */
# define choice_script_script_mlist(a) vlink(a,3) /*tex mlist to be used in scriptscript style */
# define choice_class(a)               vinfo(a,4) /*tex we could abuse the script script field */
# define choice_unused(a)              vlink(a,4)

# define choice_pre_break              choice_display_mlist
# define choice_post_break             choice_text_mlist          
# define choice_no_break               choice_script_mlist

# define parameter_node_size           3
# define parameter_style               node_subtype
# define parameter_name(a)             vinfo(a,2)
# define parameter_value(a)            vlink(a,2)

typedef enum simple_choice_subtypes {
    normal_choice_subtype,
    discretionary_choice_subtype,
} simple_choice_subtypes; 

# define last_choice_subtype discretionary_choice_subtype

/*tex
    Because noad types get changed when processing we need to make sure some if the node sizes
    match and that we don't share slots with different properties.

    First come the regular noads. The generic noad has the same size and similar fields as a fence
    noad, and their types get swapped a few times.

    We accept a little waste of space in order to get nicer code. After all, math is not that
    demanding. Although delimiter, accent, fraction and radical share the same structure we do use
    specific field names because of clarity. Not all fields are used always.

    \starttabulate[|l|l|l|l|l|l|]
    \FL
    \BC            \BC noad       \BC accent            \BC fraction         \BC radical         \NC fence        \NC \NR
    \ML                                                                                          \NC              
    \NC vlink  2   \NC new_hlist  \NC                   \NC                  \NC                 \NC              \NC \NR
    \ML                                                                                          \NC              
    \NC vinfo  2   \NC nucleus    \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vlink  3   \NC supscr     \NC                   \NC numerator        \NC                 \NC              \NC \NR
    \NC vinfo  3   \NC subscr     \NC                   \NC denominator      \NC                 \NC              \NC \NR
    \NC vlink  4   \NC supprescr  \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo  4   \NC subprescr  \NC                   \NC                  \NC                 \NC              \NC \NR
    \ML                                                                                          \NC              
    \NC vlink  5   \NC italic     \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo  5   \NC width      \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vlink  6   \NC height     \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo  6   \NC depth      \NC                   \NC                  \NC                 \NC              \NC \NR
    \ML                                                                                          \NC              
    \NC vlink  7   \NC options    \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo  7   \NC style      \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vlink  8   \NC family     \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo  8   \NC class      \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vlink  9   \NC source     \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo  9   \NC prime      \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vlink 10   \NC leftslack  \NC                   \NC                  \NC                 \NC              \NC \NR
    \NC vinfo 10   \NC rightslack \NC                   \NC                  \NC                 \NC              \NC \NR
    \ML                                                                                          \NC              
    \NC vlink 11   \NC extra_1    \NC top_character     \NC rule_thickness   \NC degree          \NC list         \NC \NR
    \NC vinfo 11   \NC extra_2    \NC bot_character     \NC left_delimiter   \NC left_delimiter  \NC source       \NC \NR
    \NC vlink 12   \NC extra_3    \NC overlay_character \NC right_delimiter  \NC right_delimiter \NC top          \NC \NR
    \NC vinfo 12   \NC extra_4    \NC fraction          \NC middle_delimiter \NC                 \NC bottom       \NC \NR
    \NC vlink 13   \NC extra_5    \NC topovershoot      \NC                  \NC height          \NC topovershoot \NC \NR
    \NC vinfo 13   \NC extra_6    \NC botovershoot      \NC                  \NC depth           \NC botovershoot \NC \NR
    \LL
    \stoptabulate

    We can use smaller variables for style and class and then have one field available for other 
    usage so no need to grow.

    As with other nodes, not all fields are used and|/|or can be set at the tex end but they are 
    available for usage at the \LUA\ end. Some have been used for experiments and stay around. 

*/

//define noad_state_node_size      6
//define noad_state_topright(a)    vlink(a,2)
//define noad_state_bottomright(a) vinfo(a,2)
//define noad_state_topleft(a)     vlink(a,3)
//define noad_state_bottomleft(a)  vinfo(a,3)
//define noad_state_height(a)      vlink(a,4)
//define noad_state_depth(a)       vinfo(a,4)
//define noad_state_toptotal(a)    vlink(a,5)
//define noad_state_bottomtotal(a) vinfo(a,5)

# define noad_size            14
# define noad_new_hlist(a)    vlink(a,2)    /*tex the translation of an mlist; a bit confusing name */
# define noad_nucleus(a)      vinfo(a,2)
# define noad_supscr(a)       vlink(a,3)
# define noad_subscr(a)       vinfo(a,3)
# define noad_supprescr(a)    vlink(a,4)
# define noad_subprescr(a)    vinfo(a,4)
# define noad_italic(a)       vlink(a,5)    /*tex Sometimes used, might become more. */
# define noad_width(a)        vinfo(a,5)
# define noad_height(a)       vlink(a,6)
# define noad_depth(a)        vinfo(a,6)
//define noad_options(a)      vlink(a,7)
//define noad_style(a)        vinfo00(a,7)
//define noad_family(a)       vinfo01(a,7)
//define noad_script_state(a) vinfo02(a,7)
//define noad_analyzed(a)     vinfo03(a,7)  /*tex used for experiments */
//define noad_state(a)        vlink(a,8)    /*tex this might replace */
# define noad_options(a)      lvalue(a,7)   /*tex 64 bit fullword */
# define noad_style(a)        vlink00(a,8)
# define noad_family(a)       vlink01(a,8)
# define noad_script_state(a) vlink02(a,8)
# define noad_analyzed(a)     vlink03(a,8)  /*tex used for experiments */
# define noad_class_main(a)   vinfo00(a,8)
# define noad_class_left(a)   vinfo01(a,8)
# define noad_class_right(a)  vinfo02(a,8)
# define noad_script_order(a) vinfo03(a,8)
# define noad_source(a)       vlink(a,9)
# define noad_prime(a)        vinfo(a,9)
# define noad_left_slack(a)   vlink(a,10)
# define noad_right_slack(a)  vinfo(a,10)
# define noad_extra_1(a)      vlink(a,11)
# define noad_extra_2(a)      vinfo(a,11)
# define noad_extra_3(a)      vlink(a,12)
# define noad_extra_4(a)      vinfo(a,12)
# define noad_extra_5(a)      vlink(a,13)
# define noad_extra_6(a)      vinfo(a,13)

# define noad_total(a) (noad_height(a) + noad_depth(a))

# define noad_has_postscripts(a)       (noad_subscr(a) || noad_supscr(a))
# define noad_has_prescripts(a)        (noad_subprescr(a) || noad_supprescr(a))
# define noad_has_scripts(a)           (noad_has_postscripts(a) || noad_has_prescripts(a) || noad_prime(a))
# define noad_has_following_scripts(a) (noad_subscr(a) || noad_supscr(a) || noad_prime(a))
# define noad_has_superscripts(a)      (noad_supprescr(a) || noad_supscr(a) || noad_prime(a))
# define noad_has_subscripts(a)        (noad_subprescr(a) || noad_subscr(a))

# define noad_has_scriptstate(a,s)     ((noad_script_state(a) & s) == s)

# define unset_noad_class 0xFE

typedef enum noad_script_states {
    post_super_script_state = 0x01,
    post_sub_script_state   = 0x02,
    pre_super_script_state  = 0x04,
    pre_sub_script_state    = 0x08,
    prime_script_state      = 0x10,
} noad_script_states;

typedef enum noad_script_locations {
    prime_unknown_location,
    prime_at_begin_location,
    prime_above_sub_location,
    prime_at_end_location,
} noad_prime_locations;

typedef enum noad_script_order {
    script_unknown_first,
    script_primescript_first,
    script_subscript_first,
    script_superscript_first,
} noad_script_order;

typedef struct noad_classes {
    singleword main;
    singleword left;
    singleword right;
} noad_classes;

# define reset_noad_classes(n) do { \
   noad_class_main(n)  = (singleword) unset_noad_class; \
   noad_class_left(n)  = (singleword) unset_noad_class; \
   noad_class_right(n) = (singleword) unset_noad_class; \
   noad_analyzed(n)    = (singleword) unset_noad_class; \
} while (0);

# define set_noad_classes(n,c) do { \
   noad_class_main(n)  = (singleword) (c & 0xFF); \
   noad_class_left(n)  = (singleword) (c & 0xFF); \
   noad_class_right(n) = (singleword) (c & 0xFF); \
} while (0);

# define set_noad_main_class(n,c)  noad_class_main(n)  = (singleword) (c & 0xFF)
# define set_noad_left_class(n,c)  noad_class_left(n)  = (singleword) (c & 0xFF)
# define set_noad_right_class(n,c) noad_class_right(n) = (singleword) (c & 0xFF)

# define get_noad_main_class(n)  (noad_class_main(n))
# define get_noad_left_class(n)  (noad_class_left(n))
# define get_noad_right_class(n) (noad_class_right(n))

# define set_noad_style(n,s)  noad_style(n)  = (singleword) (s & 0xFF)
# define set_noad_family(n,f) noad_family(n) = (singleword) (f & 0xFF)

/*tex
    Options are something \LUATEX\ and in \LUAMETEX\ we added some more. When we have dimensions
    then we obey |axis| and otherwise |noaxis|. This might evolve a bit over time. These options
    currently are on the same spot but we pretend they aren't so we have dedicated accessors. This
    also makes clear what noads have what options.

    If we run out of options we can combine some, like auto.
*/

// # if (defined(_MSC_VER) && ! defined(__MINGW32__))
// typedef enum noad_options : unsigned __int64 {
// # else 
typedef enum noad_options {
// # endif 
    noad_option_axis                       = 0x000000001,
    noad_option_no_axis                    = 0x000000002,
    noad_option_exact                      = 0x000000004,
    noad_option_left                       = 0x000000008, /* align option for overflown under/over */ /* used ? */
    noad_option_middle                     = 0x000000010, /* idem */
    noad_option_right                      = 0x000000020, /* idem */
    noad_option_adapt_to_left_size         = 0x000000040, /* old trickery, might go away but kind of fun */
    noad_option_adapt_to_right_size        = 0x000000080, /* idem */
    noad_option_no_sub_script              = 0x000000100,
    noad_option_no_super_script            = 0x000000200,
    noad_option_no_sub_pre_script          = 0x000000400,
    noad_option_no_super_pre_script        = 0x000000800,
    noad_option_no_script                  = 0x000001000,
    noad_option_no_overflow                = 0x000002000, /* keep (middle) extensible widthin target size */
    noad_option_void                       = 0x000004000, /* wipe and set width to zero */
    noad_option_phantom                    = 0x000008000, /* wipe */
    noad_option_openup_height              = 0x000010000,
    noad_option_openup_depth               = 0x000020000,
    noad_option_limits                     = 0x000040000, /* traditional modifier */
    noad_option_no_limits                  = 0x000080000, /* idem */
    noad_option_prefer_font_thickness      = 0x000100000,
    noad_option_no_ruling                  = 0x000200000,
    noad_option_shifted_sub_script         = 0x000400000,
    noad_option_shifted_super_script       = 0x000800000,
    noad_option_shifted_sub_pre_script     = 0x001000000,
    noad_option_shifted_super_pre_script   = 0x002000000,
    noad_option_unpack_list                = 0x004000000,
    noad_option_no_check                   = 0x008000000, /* don't check for missing end fence */
    noad_option_auto                       = 0x010000000,
    noad_option_unroll_list                = 0x020000000,
    noad_option_followed_by_space          = 0x040000000,
    noad_option_proportional               = 0x080000000,
    /*tex Watch out: the following options exceed halfword: |noad_options| are |long long|. */
} noad_options;

/*tex The Microsoft compiler truncates to int, so: */

# define noad_option_source_on_nucleus          0x100000000
# define noad_option_fixed_super_or_sub_script  0x200000000
# define noad_option_fixed_super_and_sub_script 0x400000000

# define has_option(a,b)     (((a) & (b)) == (b))
# define unset_option(a,b)   ((a) & ~(b))

inline static void tex_add_noad_option    (halfword a, halfword r) { noad_options(a) |= r; }
inline static void tex_remove_noad_option (halfword a, halfword r) { noad_options(a) &= ~(r | noad_options(a)); }
inline static int  tex_has_noad_option    (halfword a, halfword r) { return (noad_options(a) & r) == r; }

inline static int has_noad_no_script_option(halfword n, halfword option)
{
    switch (node_type(n)) {
        case simple_noad:
        case accent_noad:
        case radical_noad:
        case fence_noad:
        case fraction_noad:
            return has_option(noad_options(n), option) || has_option(noad_options(n), noad_option_no_script);
    }
    return 0;
}

# define has_noad_option_nosubscript(a)    has_noad_no_script_option(a, noad_option_no_sub_script)
# define has_noad_option_nosupscript(a)    has_noad_no_script_option(a, noad_option_no_super_script)
# define has_noad_option_nosubprescript(a) has_noad_no_script_option(a, noad_option_no_sub_pre_script)
# define has_noad_option_nosupprescript(a) has_noad_no_script_option(a, noad_option_no_super_pre_script)

# define has_noad_option_shiftedsubscript(a)           (has_option(noad_options(a), noad_option_shifted_sub_script))
# define has_noad_option_shiftedsupscript(a)           (has_option(noad_options(a), noad_option_shifted_super_script))
# define has_noad_option_shiftedsubprescript(a)        (has_option(noad_options(a), noad_option_shifted_sub_pre_script))
# define has_noad_option_shiftedsupprescript(a)        (has_option(noad_options(a), noad_option_shifted_super_pre_script))
# define has_noad_option_axis(a)                       (has_option(noad_options(a), noad_option_axis))
# define has_noad_option_exact(a)                      (has_option(noad_options(a), noad_option_exact))
# define has_noad_option_noaxis(a)                     (has_option(noad_options(a), noad_option_no_axis))
# define has_noad_option_openupheight(a)               (has_option(noad_options(a), noad_option_openup_height))
# define has_noad_option_openupdepth(a)                (has_option(noad_options(a), noad_option_openup_depth))
# define has_noad_option_adapttoleft(a)                (has_option(noad_options(a), noad_option_adapt_to_left_size))
# define has_noad_option_adapttoright(a)               (has_option(noad_options(a), noad_option_adapt_to_right_size))
# define has_noad_option_limits(a)                     (has_option(noad_options(a), noad_option_limits))
# define has_noad_option_nolimits(a)                   (has_option(noad_options(a), noad_option_no_limits))
# define has_noad_option_nooverflow(a)                 (has_option(noad_options(a), noad_option_no_overflow))
# define has_noad_option_preferfontthickness(a)        (has_option(noad_options(a), noad_option_prefer_font_thickness))
# define has_noad_option_noruling(a)                   (has_option(noad_options(a), noad_option_no_ruling))
# define has_noad_option_unpacklist(a)                 (has_option(noad_options(a), noad_option_unpack_list))
# define has_noad_option_nocheck(a)                    (has_option(noad_options(a), noad_option_no_check))
# define has_noad_option_exact(a)                      (has_option(noad_options(a), noad_option_exact))
# define has_noad_option_left(a)                       (has_option(noad_options(a), noad_option_left))
# define has_noad_option_middle(a)                     (has_option(noad_options(a), noad_option_middle))
# define has_noad_option_right(a)                      (has_option(noad_options(a), noad_option_right))
# define has_noad_option_auto(a)                       (has_option(noad_options(a), noad_option_auto))
# define has_noad_option_phantom(a)                    (has_option(noad_options(a), noad_option_phantom))
# define has_noad_option_void(a)                       (has_option(noad_options(a), noad_option_void))
# define has_noad_option_unrolllist(a)                 (has_option(noad_options(a), noad_option_unroll_list))
# define has_noad_option_followedbyspace(a)            (has_option(noad_options(a), noad_option_followed_by_space))
# define has_noad_option_proportional(a)               (has_option(noad_options(a), noad_option_proportional))
# define has_noad_option_source_on_nucleus(a)          (has_option(noad_options(a), noad_option_source_on_nucleus))
# define has_noad_option_fixed_super_or_sub_script(a)   (has_option(noad_options(a), noad_option_fixed_super_or_sub_script))
# define has_noad_option_fixed_super_and_sub_script(a)  (has_option(noad_options(a), noad_option_fixed_super_and_sub_script))

/*tex
    In the meantime the codes and subtypes are in sync. The variable component does not really
    become a subtype.
*/

typedef enum simple_noad_subtypes {
    ordinary_noad_subtype,
    operator_noad_subtype,
    binary_noad_subtype,
    relation_noad_subtype,
    open_noad_subtype,
    close_noad_subtype,
    punctuation_noad_subtype,
    variable_noad_subtype,    /* we want to run in parallel */
    active_noad_subtype,      /* we want to run in parallel */
    inner_noad_subtype,
    under_noad_subtype,
    over_noad_subtype,
    fraction_noad_subtype,
    radical_noad_subtype,
    middle_noad_subtype,
    accent_noad_subtype,
    fenced_noad_subtype,
    ghost_noad_subtype,
    vcenter_noad_subtype,
} simple_noad_subtypes;

# define last_noad_type    vcenter_noad_subtype
# define last_noad_subtype vcenter_noad_subtype

typedef enum math_component_types {
    math_component_ordinary_code,
    math_component_operator_code,
    math_component_binary_code,
    math_component_relation_code,
    math_component_open_code,
    math_component_close_code,
    math_component_punctuation_code,
    math_component_variable_code,
    math_component_inner_code,
    math_component_under_code,
    math_component_over_code,
    math_component_fraction_code,
    math_component_radical_code,
    math_component_middle_code,
    math_component_accent_code,
    math_component_fenced_code,
    math_component_ghost_code,
    math_component_atom_code,
} math_component_types;

# define first_math_component_type math_component_ordinary_code
# define last_math_component_type  math_component_accent_code

/*tex
    When I added adapt options, the |math_limits_cmd| became |math_modifier_cmd| just because it
    nicely fits in there.
*/

typedef enum math_modifier_types {
    display_limits_modifier_code,
    limits_modifier_code,
    no_limits_modifier_code,
    adapt_to_left_modifier_code,
    adapt_to_right_modifier_code,
    axis_modifier_code,
    no_axis_modifier_code,
    phantom_modifier_code,
    void_modifier_code,
    source_modifier_code,
    openup_height_modifier_code,
    openup_depth_modifier_code,
} math_modifier_types;

# define first_math_modifier_code display_limits_modifier_code
# define last_math_modifier_code  openup_depth_modifier_code

/*tex accent noads: todo, left and right offsets and options */

# define accent_noad_size        noad_size
# define accent_top_character    noad_extra_1 /*tex the |top_accent_chr| field of an accent noad */
# define accent_bottom_character noad_extra_2 /*tex the |bot_accent_chr| field of an accent noad */
# define accent_middle_character noad_extra_3 /*tex the |overlay_accent_chr| field of an accent noad */
# define accent_fraction         noad_extra_4
# define accent_top_overshoot    noad_extra_5
# define accent_bot_overshoot    noad_extra_6

typedef enum math_accent_subtypes {
    bothflexible_accent_subtype,
    fixedtop_accent_subtype,
    fixedbottom_accent_subtype,
    fixedboth_accent_subtype,
} math_accent_subtypes;

# define last_accent_subtype fixedboth_accent_subtype

/*tex
    With these left and right fencing noads we have a historical mix of |fence| and |delimiter| (and
    |shield|) naming which for now we keep. It gets swapped with the generic noad, so size matters.
 */

# define fence_noad_size        noad_size
# define fence_delimiter_list   noad_extra_1    // not really a list
# define fence_delimiter_top    noad_extra_3
# define fence_delimiter_bottom noad_extra_4
# define fence_top_overshoot    noad_extra_5
# define fence_bottom_overshoot noad_extra_6

typedef enum fence_subtypes {
    unset_fence_side,
    left_fence_side,
    middle_fence_side,
    right_fence_side,
    left_operator_side,
    no_fence_side,
    extended_left_fence_side,
    extended_middle_fence_side,
    extended_right_fence_side,
} fence_subtypes;

# define last_fence_subtype extended_right_fence_side
# define first_fence_code   left_fence_side
# define last_fence_code    extended_right_fence_side

/*tex
    Fraction noads are generic in the sense that they are also used for non|-|fractions, not that
    it matters much. We keep them as they are in \TEX\ but have more fields.

    We put the numerator and denomerator in script fields so there can be no such direct scripts
    attached. Because we have prescripts we can used these fields and limit this handicap a bit but
    if we ever overcome this (at the cost of more fields in these similar noads) we need to adapt
    the error message for double scripts in |tex_run_math_script|.

*/

# define fraction_noad_size        noad_size
# define fraction_numerator        noad_supprescr /* ! */
# define fraction_denominator      noad_subprescr /* ! */
# define fraction_rule_thickness   noad_extra_1
# define fraction_left_delimiter   noad_extra_2
# define fraction_right_delimiter  noad_extra_3
# define fraction_middle_delimiter noad_extra_4
# define fraction_h_factor         noad_extra_5
# define fraction_v_factor         noad_extra_6

typedef enum fraction_subtypes {
    over_fraction_subtype,
    atop_fraction_subtype, 
    above_fraction_subtype, 
    skewed_fraction_subtype,
    stretched_fraction_subtype,
} fraction_subtypes;

# define valid_fraction_subtype(s) (s >= over_fraction_subtype && s <= stretched_fraction_subtype) 

/*tex
    Radical noads are like fraction noads, but they only store a |left_delimiter|. They are also
    used for extensibles (over, under, etc) so the name is is somewhat confusing.
*/

# define radical_noad_size       noad_size
# define radical_degree          noad_extra_1
# define radical_left_delimiter  noad_extra_2
# define radical_right_delimiter noad_extra_3
# define radical_size            noad_extra_4
# define radical_height          noad_extra_5
# define radical_depth           noad_extra_6

typedef enum radical_subtypes {
    normal_radical_subtype,
    radical_radical_subtype,
    root_radical_subtype,
    rooted_radical_subtype,
    under_delimiter_radical_subtype,
    over_delimiter_radical_subtype,
    delimiter_under_radical_subtype,
    delimiter_over_radical_subtype,
    delimited_radical_subtype,
    h_extensible_radical_subtype,
} radical_subtypes;

# define last_radical_subtype h_extensible_radical_subtype
# define last_radical_code    h_extensible_radical_subtype

/*tex
    Again a very simple small node: it represents a math character so naturally it has a family.
    It can be turned list. These are subnodes. When an extra options field gets added, the
    overlapping character and list fields can be split, so then we also have the origin saved.

    The following nodes are kernel nodes: |math_char_node|, |math_text_char_node|, |sub_box_node|
    and |sub_mlist_node|. Characters eventually becomes wrapped in a list. 
*/

typedef enum math_kernel_options {
    math_kernel_no_italic_correction = 0x0001,
    math_kernel_no_left_pair_kern    = 0x0002,
    math_kernel_no_right_pair_kern   = 0x0004,
    math_kernel_auto_discretionary   = 0x0008,
    math_kernel_full_discretionary   = 0x0010,
    math_kernel_ignored_character    = 0x0020,
    math_kernel_is_large_operator    = 0x0040,
    math_kernel_has_italic_shape     = 0x0080,
} math_kernel_options;

# define math_kernel_node_size     5
# define kernel_math_family(a)     vinfo(a,2)
# define kernel_math_character(a)  vlink(a,2)
# define kernel_math_options(a)    vinfo(a,3)
# define kernel_math_list(a)       vlink(a,3)
# define kernel_math_properties(a) vinfo0(a,4)  /* for characters */
# define kernel_math_group(a)      vinfo1(a,4)  /* for characters */
# define kernel_math_index(a)      vlink(a,4)   /* for characters */

# define math_kernel_node_has_option(a,b) ((kernel_math_options(a) & b) == b)
# define math_kernel_node_set_option(a,b) kernel_math_options(a) = (kernel_math_options(a) | b)

/*tex
    This is also a subnode, this time for a delimiter field. The large family field is only used
    in traditional \TEX\ fonts where a base character can come from one font, and the extensible
    from another, but in \OPENTYPE\ math font that doesn't happen.
*/
    
/* It could be: */

// # define math_delimiter_node_size     4
// # define delimiter_small_family(a)    vinfo00(a,2)  
// # define delimiter_large_family(a)    vinfo01(a,2)  
// # define delimiter_reserved_1         vinfo02(a,2)  
// # define delimiter_reserved_2         vinfo03(a,2)  
// # define delimiter_reserved_3         vlink(a,2)  
// # define delimiter_small_character(a) vinfo(a,3)
// # define delimiter_large_character(a) vlink(a,3)

/* And some day (we then even assume traditionally to be mapped onto wide): */

// # define math_delimiter_node_size 3
// # define delimiter_family(a)      vinfo00(a,2)  
// # define delimiter_reserved_1     vinfo01(a,2)  
// # define delimiter_reserved_2     vinfo02(a,2)  
// # define delimiter_reserved_3     vinfo03(a,2)  
// # define delimiter_character(a)   vlink(a,2)

# define math_delimiter_node_size     4
# define delimiter_small_family(a)    vinfo(a,2) /*tex |family| for small delimiter */
# define delimiter_small_character(a) vlink(a,2) /*tex |character| for small delimiter */
# define delimiter_large_family(a)    vinfo(a,3) /*tex |family| for large delimiter */
# define delimiter_large_character(a) vlink(a,3) /*tex |character| for large delimiter */

/*tex
    Before we come to the by now rather large local par node we define some small ones. The
    boundary nodes are an extended version of the original ones. The direction nodes are
    a simplified version of what \OMEGA\ has as whatsit. In \LUATEX\ it became a first class
    citizen and in \LUAMETATEX\ we cleaned it up.
*/

typedef enum boundary_subtypes {
    cancel_boundary,
    user_boundary,
    protrusion_boundary,
    word_boundary,
    page_boundary,
    par_boundary,
} boundary_subtypes;

# define last_boundary_subtype word_boundary
# define last_boundary_code    page_boundary

# define boundary_node_size 3
# define boundary_data(a)   vinfo(a,2)

typedef enum dir_subtypes {
    normal_dir_subtype,
    cancel_dir_subtype,
} dir_subtypes;

# define last_dir_subtype cancel_dir_subtype

# define dir_node_size    3
# define dir_direction(a) vinfo(a,2)
# define dir_level(a)     vlink(a,2)

/*tex
    Local par nodes come from \OMEGA\ and store the direction as well as local boxes. In \LUATEX
    we use a leaner direction model and in \LUAMETATEX\ we only kept the two directions that just
    work. In the end it is the backend that deals with these properties. The frontend just keeps
    a little track of them.

    However, in \LUAMETATEX\ we can also store the paragraph state in this node. That way we no
    longer have the issue that properties are lost when a group ends before a |\par| is triggered.
    This is probably a feature that only makes sense in \CONTEXT\ which is why I made sure that
    there is not much overhead. In the first version one could control each variable, but as we
    ran out of bits in the end was done per group of variables. However, when I really need more
    detail I might go for a 64 bit field instead. After all we have that possibility in memory
    words.

    These local par nodes can actually end up in the middle of lines  as they can be used to change
    the left and right box as well as inject penalties. For that reason they now have a proper
    subtype so that the initial and successive instances can be recognized.
 */

typedef enum par_codes {
    par_none_code,
    par_hsize_code,
    par_left_skip_code,
    par_right_skip_code,
    par_hang_indent_code,
    par_hang_after_code,
    par_par_indent_code,
    par_par_fill_left_skip_code,
    par_par_fill_right_skip_code,
    par_par_init_left_skip_code,
    par_par_init_right_skip_code,
    par_adjust_spacing_code,
    par_protrude_chars_code,
    par_pre_tolerance_code,
    par_tolerance_code,
    par_emergency_stretch_code,
    par_looseness_code,
    par_last_line_fit_code,
    par_line_penalty_code,
    par_inter_line_penalty_code,
    par_club_penalty_code,
    par_widow_penalty_code,
    par_display_widow_penalty_code,
    par_orphan_penalty_code,
    par_broken_penalty_code,
    par_adj_demerits_code,
    par_double_hyphen_demerits_code,
    par_final_hyphen_demerits_code,
    par_par_shape_code,
    par_inter_line_penalties_code,
    par_club_penalties_code,
    par_widow_penalties_code,
    par_display_widow_penalties_code,
    par_orphan_penalties_code,
    par_baseline_skip_code,
    par_line_skip_code,
    par_line_skip_limit_code,
    par_adjust_spacing_step_code,
    par_adjust_spacing_shrink_code,
    par_adjust_spacing_stretch_code,
    par_hyphenation_mode_code,
    par_shaping_penalties_mode_code,
    par_shaping_penalty_code,
} par_codes;

typedef enum par_categories {
    par_none_category            = 0x00000000,
    par_hsize_category           = 0x00000001, // \hsize
    par_skip_category            = 0x00000002, // \leftskip \rightskip
    par_hang_category            = 0x00000004, // \hangindent \hangafter
    par_indent_category          = 0x00000008, // \parindent
    par_par_fill_category        = 0x00000010, // \parfillskip \parfillleftskip
    par_adjust_category          = 0x00000020, // \adjustspacing
    par_protrude_category        = 0x00000040, // \protrudechars
    par_tolerance_category       = 0x00000080, // \tolerance \pretolerance
    par_stretch_category         = 0x00000100, // \emergcystretch
    par_looseness_category       = 0x00000200, // \looseness
    par_last_line_category       = 0x00000400, // \lastlinefit
    par_line_penalty_category    = 0x00000800, // \linepenalty \interlinepenalty \interlinepenalties
    par_club_penalty_category    = 0x00001000, // \clubpenalty \clubpenalties
    par_widow_penalty_category   = 0x00002000, // \widowpenalty \widowpenalties
    par_display_penalty_category = 0x00004000, // \displaypenalty \displaypenalties
    par_broken_penalty_category  = 0x00008000, // \brokenpenalty
    par_demerits_category        = 0x00010000, // \doublehyphendemerits \finalhyphendemerits \adjdemerits
    par_shape_category           = 0x00020000, // \parshape
    par_line_category            = 0x00040000, // \baselineskip \lineskip \lineskiplimit
    par_hyphenation_category     = 0x00080000, // \Hyphenationmode
    par_shaping_penalty_category = 0x00100000, // \shapingpenaltiesmode
    par_orphan_penalty_category  = 0x00200000, // \orphanpenalties
    par_all_category             = 0x7FFFFFFF, //
} par_categories;

static int par_category_to_codes[] = {
    par_none_category,
    par_hsize_category,           // par_hsize_code
    par_skip_category,            // par_left_skip_code
    par_skip_category,            // par_right_skip_code
    par_hang_category,            // par_hang_indent_code
    par_hang_category,            // par_hang_after_code
    par_indent_category,          // par_par_indent_code
    par_par_fill_category,        // par_par_fill_skip_code
    par_par_fill_category,        // par_par_fill_left_skip_code
    par_par_fill_category,        // par_par_init_skip_code
    par_par_fill_category,        // par_par_init_skip_code
    par_adjust_category,          // par_adjust_spacing_code
    par_protrude_category,        // par_protrude_chars_code
    par_tolerance_category,       // par_pre_tolerance_code
    par_tolerance_category,       // par_tolerance_code
    par_stretch_category,         // par_emergency_stretch_code
    par_looseness_category,       // par_looseness_code
    par_last_line_category,       // par_last_line_fit_code
    par_line_penalty_category,    // par_line_penalty_code
    par_line_penalty_category,    // par_inter_line_penalty_code
    par_club_penalty_category,    // par_club_penalty_code
    par_widow_penalty_category,   // par_widow_penalty_code
    par_display_penalty_category, // par_display_widow_penalty_code
    par_orphan_penalty_category,  // par_orphan_penalty_code
    par_broken_penalty_category,  // par_broken_penalty_code
    par_demerits_category,        // par_adj_demerits_code
    par_demerits_category,        // par_double_hyphen_demerits_code
    par_demerits_category,        // par_final_hyphen_demerits_code
    par_shape_category,           // par_par_shape_code
    par_line_penalty_category,    // par_inter_line_penalties_code
    par_club_penalty_category,    // par_club_penalties_code
    par_widow_penalty_category,   // par_widow_penalties_code
    par_display_penalty_category, // par_display_widow_penalties_code
    par_orphan_penalty_category,  // par_orphan_penalties_code
    par_line_category,            // par_baseline_skip_code
    par_line_category,            // par_line_skip_code
    par_line_category,            // par_line_skip_limit_code
    par_adjust_category,          // par_adjust_spacing_step_code
    par_adjust_category,          // par_adjust_spacing_shrink_code
    par_adjust_category,          // par_adjust_spacing_stretch_code
    par_hyphenation_category,     // par_hyphenation_mode_code
    par_shaping_penalty_category, // par_shaping_penalties_mode_code
    par_shaping_penalty_category, // par_shaping_penalty_code
};

/*tex
    Todo: make the fields 6+ into a par_state node so that local box ones can be
    small. Also, penalty and broken fields now are duplicate. Do we need to keep
    these?
*/

# define par_node_size                  28
# define par_penalty_interline(a)       vinfo(a,2) /*tex These come from \OMEGA. */
# define par_penalty_broken(a)          vlink(a,2) /*tex These come from \OMEGA. */
# define par_box_left(a)                vinfo(a,3)
# define par_box_left_width(a)          vlink(a,3)
# define par_box_right(a)               vinfo(a,4)
# define par_box_right_width(a)         vlink(a,4)
# define par_box_middle(a)              vinfo(a,5) /* no width here */
# define par_dir(a)                     vlink(a,5)
# define par_state(a)                   vinfo(a,6)
# define par_hsize(a)                   vlink(a,6)
# define par_left_skip(a)               vinfo(a,7)
# define par_right_skip(a)              vlink(a,7)
# define par_hang_indent(a)             vinfo(a,8)
# define par_hang_after(a)              vlink(a,8)
# define par_par_indent(a)              vinfo(a,9)
# define par_par_fill_left_skip(a)      vlink(a,9)
# define par_par_fill_right_skip(a)     vinfo(a,10)
# define par_adjust_spacing(a)          vlink(a,10)
# define par_protrude_chars(a)          vinfo(a,11)
# define par_pre_tolerance(a)           vlink(a,11)
# define par_tolerance(a)               vinfo(a,12)
# define par_emergency_stretch(a)       vlink(a,12)
# define par_looseness(a)               vinfo(a,13)
# define par_last_line_fit(a)           vlink(a,13)
# define par_line_penalty(a)            vinfo(a,14)
# define par_inter_line_penalty(a)      vlink(a,14)
# define par_club_penalty(a)            vinfo(a,15)
# define par_widow_penalty(a)           vlink(a,15)
# define par_display_widow_penalty(a)   vinfo(a,16)
# define par_orphan_penalty(a)          vlink(a,16)
# define par_broken_penalty(a)          vinfo(a,17)
# define par_adj_demerits(a)            vlink(a,17)
# define par_double_hyphen_demerits(a)  vinfo(a,18)
# define par_final_hyphen_demerits(a)   vlink(a,18)
# define par_par_shape(a)               vinfo(a,19)
# define par_inter_line_penalties(a)    vlink(a,19)
# define par_club_penalties(a)          vinfo(a,20)
# define par_widow_penalties(a)         vlink(a,20)
# define par_display_widow_penalties(a) vinfo(a,21)
# define par_orphan_penalties(a)        vlink(a,21)
# define par_baseline_skip(a)           vinfo(a,22)
# define par_line_skip(a)               vlink(a,22)
# define par_line_skip_limit(a)         vinfo(a,23)
# define par_adjust_spacing_step(a)     vlink(a,23)
# define par_adjust_spacing_shrink(a)   vinfo(a,24)
# define par_adjust_spacing_stretch(a)  vlink(a,24)
# define par_end_par_tokens(a)          vinfo(a,25)
# define par_hyphenation_mode(a)        vlink(a,25)
# define par_shaping_penalties_mode(a)  vinfo(a,26)
# define par_shaping_penalty(a)         vlink(a,26)
# define par_par_init_left_skip(a)      vlink(a,27)
# define par_par_init_right_skip(a)     vinfo(a,27)

typedef enum par_subtypes {
    vmode_par_par_subtype,
    local_box_par_subtype,
    hmode_par_par_subtype,
    penalty_par_subtype,
    math_par_subtype,
} par_subtypes;

# define last_par_subtype math_par_subtype

inline static int tex_is_start_of_par_node(halfword n)
{
    return ( n && (node_type(n) == par_node) && (node_subtype(n) == vmode_par_par_subtype || node_subtype(n) == hmode_par_par_subtype) );
}

extern halfword    tex_get_par_par          (halfword p, halfword what);
extern void        tex_set_par_par          (halfword p, halfword what, halfword v, int force);
extern void        tex_snapshot_par         (halfword p, halfword what);
extern halfword    tex_find_par_par         (halfword head);
/*     halfword    tex_internal_to_par_code (halfword cmd, halfword index); */
extern void        tex_update_par_par       (halfword cmd, halfword index);

inline static int  tex_par_state_is_set     (halfword p, halfword what)     { return (par_state(p) & par_category_to_codes[what]) == par_category_to_codes[what]; }
inline static void tex_set_par_state        (halfword p, halfword what)     { par_state(p) |= par_category_to_codes[what]; }
inline static int  tex_par_to_be_set        (halfword state, halfword what) { return (state & par_category_to_codes[what]) == par_category_to_codes[what]; }

/*tex
    Because whatsits are used by the backend (or callbacks in the frontend) we do provide this node.
    It only has the basic properties: subtype, attribute, prev link and  next link. User nodes have
    been dropped because one can use whatsits to achieve the same. We also don't standardize the
    subtypes as it's very macro package specific what they do. So, only a size here:
*/

# define whatsit_node_size 2

/*tex
    Active and passive nodes are used in the par builder. There is plenty of comments in the code
    that explains them (although it's not that trivial I guess). Delta nodes just store the
    progression in widths, stretch and shrink: they are copies of arrays. Originally they just used
    offsets:

    \starttyping
    # define delta_node_size    10
    # define delta_field(a,n)   node_next(a + n)
    \stoptyping

    But that wasted 9 halfs for storing the 9 fields. So, next I played with this:

    \starttyping
    # define delta_field_1(d) (delta_field(d,1)) // or: vinfo(d,1)
    # define delta_field_2(d) (delta_field(d,2)) // or: vlink(d,1)
    ...
    # define delta_field_9(d) (delta_field(d,9)) // or: vinfo(d,5)
    \stoptyping

    But soon after that more meaningfull names were introduced, simply because in the code where they
    are used also verbose names showed up.

    The active node is actually a |hyphenated_node| or an |unhyphenated_node| but for now we keep
    the \TEX\ lingua. We could probably turn the type into a subtype and moev fitness to another
    spot.
*/

/* is vinfo(a,2) used? it not we can have fitness there and hyphenated/unyphenates as subtype */

# define active_node_size                  4            /*tex |hyphenated_node| or |unhyphenated_node| */
# define active_fitness                    node_subtype /*tex |very_loose_fit..tight_fit| on final line for this break */
# define active_break_node(a)              vlink(a,1)   /*tex pointer to the corresponding passive node */
# define active_line_number(a)             vinfo(a,1)   /*tex line that begins at this breakpoint */
# define active_total_demerits(a)          vlink(a,2)   /*tex the quantity that \TEX\ minimizes */
# define active_short(a)                   vinfo(a,3)   /*tex |shortfall| of this line */
# define active_glue(a)                    vlink(a,3)   /*tex corresponding glue stretch or shrink */

# define passive_node_size                 7
# define passive_cur_break(a)              vlink(a,1)   /*tex in passive node, points to position of this breakpoint */
# define passive_prev_break(a)             vinfo(a,1)   /*tex points to passive node that should precede this one */
# define passive_pen_inter(a)              vinfo(a,2)
# define passive_pen_broken(a)             vlink(a,2)
# define passive_left_box(a)               vlink(a,3)
# define passive_left_box_width(a)         vinfo(a,3)
# define passive_last_left_box(a)          vlink(a,4)
# define passive_last_left_box_width(a)    vinfo(a,4)
# define passive_right_box(a)              vlink(a,5)
# define passive_right_box_width(a)        vinfo(a,5)
# define passive_serial(a)                 vlink(a,6)   /*tex serial number for symbolic identification (pass) */
# define passive_middle_box(a)             vinfo(a,6)

# define delta_node_size                   6
# define delta_field_total_glue(d)         vinfo(d,1)
# define delta_field_total_shrink(d)       vinfo(d,2)
# define delta_field_total_stretch(d)      vlink(d,2)
# define delta_field_total_fi_amount(d)    vinfo(d,3)
# define delta_field_total_fil_amount(d)   vlink(d,3)
# define delta_field_total_fill_amount(d)  vinfo(d,4)
# define delta_field_total_filll_amount(d) vlink(d,4)
# define delta_field_font_shrink(d)        vinfo(d,5)
# define delta_field_font_stretch(d)       vlink(d,5)

/*tex
    Again we now have some helpers. We have a double linked list so here we go:
*/

inline static void tex_couple_nodes(int a, int b)
{
    node_next(a) = b;
    node_prev(b) = a;
}

inline static void tex_try_couple_nodes(int a, int b)
{
    if (b) {
        if (a) {
            node_next(a) = b;
        }
        node_prev(b) = a;
    } else if (a) {
        node_next(a) = null;
   }
}

inline static void tex_uncouple_node(int a)
{
    node_next(a) = null;
    node_prev(a) = null;
}

inline static halfword tex_head_of_node_list(halfword n)
{
    while (node_prev(n)) {
        n = node_prev(n);
    }
    return n;
}

inline static halfword tex_tail_of_node_list(halfword n)
{
    while (node_next(n)) {
        n = node_next(n);
    }
    return n;
}

/*tex
    Attribute management is kind of complicated. They are stored in a sorted linked list and we
    try to share these for successive nodes. In \LUATEX\ a state is kept and reset frequently but
    in \LUAMETATEX\ we try to be more clever, for instance we keep track of grouping. This comes
    as some overhead but saves reconstructing (often the same) list. It also saves memory.
*/

# define attribute_cache_disabled max_halfword
# define current_attribute_state  lmt_node_memory_state.attribute_cache

extern halfword tex_copy_attribute_list        (halfword attr);
extern halfword tex_copy_attribute_list_set    (halfword attr, int index, int value);
extern halfword tex_patch_attribute_list       (halfword attr, int index, int value);
extern void     tex_dereference_attribute_list (halfword attr);
extern void     tex_build_attribute_list       (halfword target);
extern halfword tex_current_attribute_list     (void);
extern int      tex_unset_attribute            (halfword target, int index, int value);
extern void     tex_unset_attributes           (halfword first, halfword last, int index);
extern void     tex_set_attribute              (halfword target, int index, int value);
extern int      tex_has_attribute              (halfword target, int index, int value);

extern void     tex_reset_node_properties      (halfword target);

# define get_attribute_list(target) \
    node_attr(target)

# define add_attribute_reference(a) do { \
    if (a && a != attribute_cache_disabled) { \
        ++attribute_count(a); \
    } \
} while (0)

# define delete_attribute_reference(a) do { \
    if (a && a != attribute_cache_disabled) { \
        tex_dereference_attribute_list(a); \
    } \
} while (0)

# define remove_attribute_list(target) do { \
    halfword old_a = node_attr(target); \
    delete_attribute_reference(old_a); \
    node_attr(target) = null; \
} while (0)

/*
inline static void remove_attribute_list(halfword target)
{
    halfword a_old = node_attr(target);
    if (a_old && a_old != attribute_cache_disabled) {
        dereference_attribute_list(a_old);
    }
    node_attr(target) = null;
}
*/

/* This can be dangerous: */

# define wipe_attribute_list_only(target) \
    node_attr(target) = null;

/*tex
    Better is to add a ref before we remove one because there's the danger of premature freeing
    otherwise.
*/

typedef enum saved_attribute_items {
    saved_attribute_item_list  = 0,
    saved_attribute_n_of_items = 1,
} saved_attribute_items;

inline static void tex_attach_attribute_list_copy(halfword target, halfword source)
{
    halfword a_new = node_attr(source);
    halfword a_old = node_attr(target);
    node_attr(target) = a_new;
    add_attribute_reference(a_new);
    delete_attribute_reference(a_old);
}

inline static void tex_attach_attribute_list_attribute(halfword target, halfword a_new)
{
    halfword a_old = node_attr(target);
    if (a_old != a_new) {
        node_attr(target) = a_new;
        add_attribute_reference(a_new);
        delete_attribute_reference(a_old);
    }
}

# define attach_current_attribute_list tex_build_attribute_list /* (target) */

# define set_current_attribute_state(v) do { \
      current_attribute_state = v; \
} while (0)

/*
# define change_attribute_register(a,id,value) do { \
    if (eq_value(id) != value) { \
        if (is_global(a)) { \
            int i; \
            for (i = (lmt_save_state.save_stack_data.ptr - 1); i >= 0; i--) { \
                if (save_type(i) == attribute_list_save_type) { \
                    delete_attribute_reference(save_value(i)); \
                    save_value(i) = attribute_cache_disabled; \
                } \
            } \
        } else { \
            delete_attribute_reference(current_attribute_state); \
        } \
        set_current_attribute_state(attribute_cache_disabled); \
    } \
} while (0)
*/

extern void tex_change_attribute_register(halfword a, halfword id, halfword value);

# define save_attribute_state_before() do { \
    halfword c = current_attribute_state; \
    tex_set_saved_record(saved_attribute_item_list, attribute_list_save_type, 0, c); \
    lmt_save_state.save_stack_data.ptr += saved_attribute_n_of_items; \
    add_attribute_reference(c); \
} while (0)

# define save_attribute_state_after() do { \
} while (0)

# define unsave_attribute_state_before() do { \
    halfword c = current_attribute_state; \
    delete_attribute_reference(c); \
} while (0)

# define unsave_attribute_state_after() do { \
    lmt_save_state.save_stack_data.ptr -= saved_attribute_n_of_items; \
    set_current_attribute_state(saved_value(saved_attribute_item_list)); \
} while (0)

/*tex
    We now arrive at some functions that report the nodes to users. The subtype information that
    is used in the \LUA\ interface is stored alongside.
*/

extern void        tex_print_short_node_contents         (halfword n);
extern const char *tex_aux_subtype_str                   (halfword n);
extern void        tex_show_node_list                    (halfword n, int threshold, int max);
extern halfword    tex_actual_box_width                  (halfword r, scaled base_width);
extern void        tex_print_name                        (halfword p, const char *what);
extern void        tex_print_node_list                   (halfword n, const char *what, int threshold, int max);
/*     void        tex_print_node_and_details            (halfword p); */
/*     void        tex_print_subtype_and_attributes_info (halfword p, halfword s, node_info *data); */
extern void        tex_print_extended_subtype            (halfword p, quarterword s);
extern void        tex_aux_show_dictionary               (halfword p, halfword properties, halfword group, halfword index, halfword font, halfword character);

/*tex 
    Basic node management:
*/

extern halfword tex_new_node        (quarterword i, quarterword j);
extern void     tex_flush_node_list (halfword n);
extern void     tex_flush_node      (halfword n);
extern halfword tex_copy_node_list  (halfword n, halfword e);
extern halfword tex_copy_node       (halfword n);
extern halfword tex_copy_node_only  (halfword n);
/*     halfword tex_fix_node_list   (halfword n); */

/*tex
    We already defined glue and gluespec node but here are some of the properties
    that they have. Again a few helpers.
*/

typedef enum glue_orders {
    normal_glue_order,
    fi_glue_order,
    fil_glue_order,
    fill_glue_order,
    filll_glue_order
} glue_orders;

typedef enum glue_amounts {
    /* we waste slot zero, we padd anyway */
    total_glue_amount    = 1, // 1 //
    total_stretch_amount = 2, // 3 //
    total_fi_amount      = 3, // 4 //
    total_fil_amount     = 4, // 5 //
    total_fill_amount    = 5, // 6 //
    total_filll_amount   = 6, // 7 //
    total_shrink_amount  = 7, // 2 //
    font_stretch_amount  = 8, // 8 //
    font_shrink_amount   = 9, // 9 //
} glue_amounts;

# define min_glue_order normal_glue_order
# define max_glue_order filll_glue_order

typedef enum glue_signs {
    normal_glue_sign,
    stretching_glue_sign,
    shrinking_glue_sign
} glue_signs;

# define min_glue_sign normal_glue_sign
# define max_glue_sign shrinking_glue_sign

# define normal_glue_multiplier 0.0

inline static halfword tex_checked_glue_sign  (halfword sign)  { return ((sign  < min_glue_sign ) || (sign  > max_glue_sign )) ? normal_glue_sign  : sign ; }
inline static halfword tex_checked_glue_order (halfword order) { return ((order < min_glue_order) || (order > max_glue_order)) ? normal_glue_order : order; }

/*tex
    These are reserved nodes that sit at the start of main memory. We could actually just allocate
    them, but then we also need to set some when we start up. Now they are just saved in the format
    file. In \TEX\ these nodes were shared as much as possible (using a reference count) but here
    we just use copies.

    Below we start at |zero_glue| which in our case is just 0, or |null| in \TEX\ speak. After these
    reserved nodes the memory used for whatever nodes are needed takes off.

    Changing this to real nodes makes sense but is also tricky due to initializations ... some day
    (we need to store stuff in teh states then and these are not saved!).

*/

# define fi_glue           (zero_glue         + glue_spec_size) /*tex These are constants */
# define fil_glue          (fi_glue           + glue_spec_size)
# define fill_glue         (fil_glue          + glue_spec_size)
# define filll_glue        (fill_glue         + glue_spec_size)
# define fil_neg_glue      (filll_glue        + glue_spec_size)

# define page_insert_head  (fil_neg_glue      + glue_spec_size)
# define contribute_head   (page_insert_head  + split_node_size) /*tex This was temp_node_size but we assign more. */
# define page_head         (contribute_head   + temp_node_size)
# define temp_head         (page_head         + glue_node_size)  /*tex It gets a glue type assigned. */
# define hold_head         (temp_head         + temp_node_size)
# define post_adjust_head  (hold_head         + temp_node_size)
# define pre_adjust_head   (post_adjust_head  + temp_node_size)
# define post_migrate_head (pre_adjust_head   + temp_node_size)
# define pre_migrate_head  (post_migrate_head + temp_node_size)
# define align_head        (pre_migrate_head  + temp_node_size)
# define active_head       (align_head        + temp_node_size)
# define end_span          (active_head       + active_node_size)
# define begin_period      (end_span          + span_node_size)  /*tex Used to mark begin of word in hjn. */
# define end_period        (begin_period      + glyph_node_size) /*tex Used to mark end of word in hjn. */

# define last_reserved     (end_period        + glyph_node_size - 1)

/*tex More helpers! */

extern int       tex_list_has_glyph       (halfword list);

extern halfword  tex_new_null_box_node    (quarterword type, quarterword subtype);
extern halfword  tex_new_rule_node        (quarterword subtype);
extern halfword  tex_new_glyph_node       (quarterword subtype, halfword fnt, halfword chr, halfword parent); /*tex afterwards: when we mess around */
extern halfword  tex_new_char_node        (quarterword subtype, halfword fnt, halfword chr, int all);         /*tex as we go: in maincontrol */
extern halfword  tex_new_text_glyph       (halfword fnt, halfword chr);
extern halfword  tex_new_disc_node        (quarterword subtype);
extern halfword  tex_new_glue_spec_node   (halfword param);
extern halfword  tex_new_param_glue_node  (quarterword param, quarterword subtype);
extern halfword  tex_new_glue_node        (halfword qlue, quarterword subtype);
extern halfword  tex_new_kern_node        (scaled width, quarterword subtype);
extern halfword  tex_new_penalty_node     (halfword penalty, quarterword subtype);
extern halfword  tex_new_par_node         (quarterword mode);

extern halfword  tex_new_temp_node        (void);

extern scaled    tex_glyph_width          (halfword p); /* x/y scaled */
extern scaled    tex_glyph_height         (halfword p); /* x/y scaled */
extern scaled    tex_glyph_depth          (halfword p); /* x/y scaled */
extern scaled    tex_glyph_total          (halfword p); /* x/y scaled */
extern scaledwhd tex_glyph_dimensions     (halfword p); /* x/y scaled */
extern int       tex_glyph_has_dimensions (halfword p); /* x/y scaled */
extern scaled    tex_glyph_width_ex       (halfword p); /* x/y scaled, expansion included */
extern scaledwhd tex_glyph_dimensions_ex  (halfword p); /* x/y scaled, expansion included */

extern halfword  tex_kern_dimension       (halfword p);
extern halfword  tex_kern_dimension_ex    (halfword p); /* expansion included */

extern scaled    tex_effective_glue       (halfword parent, halfword glue);

extern scaledwhd tex_pack_dimensions      (halfword p);

extern halfword  tex_list_node_mem_usage  (void);
extern halfword  tex_reversed_node_list   (halfword list);
extern int       tex_n_of_used_nodes      (int counts[]);

# define _valid_node_(p) ((p > lmt_node_memory_state.reserved) && (p < lmt_node_memory_state.nodes_data.allocated) && (lmt_node_memory_state.nodesizes[p] > 0))

inline static int tex_valid_node(halfword n)
{
    return n && _valid_node_(n) ? n : null;
}

/*tex This is a bit strange place but better than a macro elsewhere: */

inline static int tex_math_skip_boundary(halfword n)
{
    return (n && node_type(n) == glue_node
              && (node_subtype(n) == space_skip_glue  ||
                  node_subtype(n) == xspace_skip_glue ||
                  node_subtype(n) == zero_space_skip_glue));
}

typedef enum special_node_list_types { /* not in sycn with the above .. maybe add bogus ones */
    page_insert_list_type,
    contribute_list_type,
    page_list_type,
    temp_list_type,
    hold_list_type,
    post_adjust_list_type,
    pre_adjust_list_type,
    post_migrate_list_type,
    pre_migrate_list_type,
    align_list_type,
    /* in different spot */
    page_discards_list_type,
    split_discards_list_type,
 // best_page_break_type
} special_node_list_types;

extern int      tex_is_special_node_list  (halfword n, int *istail);
extern halfword tex_get_special_node_list (special_node_list_types list, halfword *tail);
extern void     tex_set_special_node_list (special_node_list_types list, halfword head);

# endif

