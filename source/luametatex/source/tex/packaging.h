/*
    See license.txt in the root of this project.
*/

# ifndef PACKAGING_H
# define PACKAGING_H

/* We define some constants used when calling |hpack| to deal with font expansion. */

typedef enum {
    exactly = 0,      /*tex a box dimension is pre-specified */
    additional,       /*tex a box dimension is increased from the natural one */
    cal_expand_ratio, /*tex calculate amount for font expansion after breaking paragraph into lines */
    subst_ex_font     /*tex substitute fonts */
} hpack_subtypes;

extern void scan_spec(group_code c);
extern void scan_full_spec(group_code c, int spec_direction, int justpack);

typedef struct packaging_state_info {
    scaled total_stretch[5];
    scaled total_shrink[5];        /*tex glue found by |hpack| or |vpack| */
    int last_badness;              /*tex badness of the most recently packaged box */
    halfword adjust_tail;          /*tex tail of adjustment list */
    halfword pre_adjust_tail;
    halfword last_leftmost_char;
    halfword last_rightmost_char;
    int pack_begin_line;
    scaled active_height[10];      // = { 0 };
    scaled best_height_plus_depth; /*tex The height of the best box, without stretching or shrinking: */
    halfword prev_char_p;
} packaging_state_info;

extern packaging_state_info packaging_state;

# define total_stretch          packaging_state.total_stretch
# define total_shrink           packaging_state.total_shrink
# define last_badness           packaging_state.last_badness
# define adjust_tail            packaging_state.adjust_tail
# define pre_adjust_tail        packaging_state.pre_adjust_tail
# define last_leftmost_char     packaging_state.last_leftmost_char
# define last_rightmost_char    packaging_state.last_rightmost_char
# define pack_begin_line        packaging_state.pack_begin_line
# define active_height          packaging_state.active_height
# define best_height_plus_depth packaging_state.best_height_plus_depth
# define prev_char_p            packaging_state.prev_char_p

extern void set_prev_char_p(halfword p);
extern scaled char_stretch(halfword p);
extern scaled char_shrink(halfword p);
extern scaled kern_stretch(halfword p);
extern scaled kern_shrink(halfword p);
extern void do_subst_font(halfword p, int ex_ratio);
extern scaled char_pw(halfword p, int side);
extern halfword new_margin_kern(scaled w, halfword p, int side);

# define update_adjust_list(A) do { \
    if (A == null) \
        normal_error("pre vadjust", "adjust_tail or pre_adjust_tail is null"); \
    vlink(A) = adjust_ptr(p); \
    while (vlink(A) != null) \
        A = vlink(A); \
} while (0)

extern halfword filtered_hpack(halfword p, halfword qt, scaled w, int m, int grp, int d, int just_pack, halfword attr);
extern scaled_whd natural_sizes(halfword p, halfword pp, glue_ratio g_mult, int g_sign, int g_order);
extern halfword natural_width(halfword p, halfword pp, glue_ratio g_mult, int g_sign, int g_order);
extern halfword hpack(halfword p, scaled w, int m, int d);

extern halfword vpackage(halfword p, scaled h, int m, scaled l, int d);
extern halfword filtered_vpackage(halfword p, scaled h, int m, scaled l, int grp, int d, int just_pack, halfword attr);
extern void finish_vcenter(void);
extern void package(int c);
extern void append_to_vlist(halfword b, int location);

/*tex Special case of unconstrained depth: */

# define vpack(A,B,C,D) vpackage(A,B,C,max_dimen,D)

extern halfword prune_page_top(halfword p, int s);

# define awful_bad  07777777777 /*tex more than a billion demerits */
# define deplorable      100000 /*tex more than |inf_bad|, but less than |awful_bad| */

extern halfword vert_break(halfword p, scaled h, scaled d);

/*tex Extract a page of height |h| from box |n|: */

extern halfword vsplit(halfword n, scaled h, int m);

# define box_code      0 /*tex |chr_code| for |\box| */
# define copy_code     1 /*tex |chr_code| for |\copy| */
# define last_box_code 2 /*tex |chr_code| for |\lastbox| */
# define vsplit_code   3 /*tex |chr_code| for |\vsplit| */
# define tpack_code    4
# define vpack_code    5
# define hpack_code    6
# define vtop_code     7 /*tex |chr_code| for |\vtop| */

# define tail_page_disc disc_ptr[copy_code] /*tex last item removed by page builder */
# define page_disc disc_ptr[last_box_code]  /*tex first item removed by page builder */
# define split_disc disc_ptr[vsplit_code]   /*tex first item removed by |\vsplit| */

extern halfword disc_ptr[(vsplit_code + 1)]; /* list pointers */

/*tex

    Now let's turn to the question of how |\hbox| is treated. We actually need to
    consider also a slightly larger context, since constructions like

    \starttyping
    \setbox3={\\hbox...
    \leaders\hbox...
    \lower3.8pt\hbox...
    \stoptyping

    are supposed to invoke quite different actions after the box has been
    packaged. Conversely, constructions like |\setbox3=| can be followed by a
    variety of different kinds of boxes, and we would like to encode such things
    in an efficient way.

    In other words, there are two problems: To represent the context of a box,
    and to represent its type. The first problem is solved by putting a \quote
    {context code} on the |save_stack|, just below the two entries that give the
    dimensions produced by |scan_spec|. The context code is either a (signed)
    shift amount, or it is a large integer |>=box_flag|, where
    |box_flag=|$2^{30}$. Codes |box_flag| through |box_flag + biggest_reg|
    represent |\setbox0| through |\setbox biggest_reg|; codes |box_flag +
    biggest_reg + 1| through |box_flag+2*biggest_reg| represent |\global\setbox0|
    through |\global\setbox| |biggest_reg|'; code |box_flag + 2 * number_regs|
    represents |\shipout}'; and codes |box_flag + 2 * number_regs + 1| through
    |box_flag + 2 * number_regs + 3| represent |\leaders|, |\cleaders|, and
    |\xleaders|.

    The second problem is solved by giving the command code |make_box| to all
    control sequences that produce a box, and by using the following |chr_code|
    values to distinguish between them: |box_code|, |copy_code|, |last_box_code|,
    |vsplit_code|, |vtop_code|, |vtop_code + vmode|, and |vtop_code + hmode|,
    where the latter two are used denote |\vbox| and |\hbox|, respectively.

*/

# define box_flag            010000000000                  /*tex context code for |\setbox0| */
# define global_box_flag     (box_flag+number_regs)        /*tex context code for |\global\setbox0| */
# define max_global_box_flag (global_box_flag+number_regs)
# define ship_out_flag       (max_global_box_flag+1)       /*tex context code for |\shipout| */
# define lua_scan_flag       (max_global_box_flag+2)       /*tex context code for |scan_list| */
# define leader_flag         (max_global_box_flag+3)       /*tex context code for |\leaders| */

extern void begin_box(int box_context);

# define math_skip_boundary(n) \
    (n && type(n) == glue_node && (subtype(n) == space_skip_subtype || subtype(n) == xspace_skip_subtype))

extern int ignore_math_skip(halfword p) ;

# endif
