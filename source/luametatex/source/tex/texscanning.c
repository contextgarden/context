/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

static void tex_aux_scan_expr       (halfword level);
static void tex_aux_scan_expression (int level);

/*tex
    A helper.
*/

static inline void tex_push_back(halfword tok, halfword cmd, halfword chr)
{
    if (cmd != spacer_cmd && tok != deep_frozen_relax_token && ! (cmd == relax_cmd && chr == no_relax_code)) {
        tex_back_input(tok);
    }
}

/*tex

    Let's turn now to some procedures that \TEX\ calls upon frequently to digest certain kinds of
    patterns in the input. Most of these are quite simple; some are quite elaborate. Almost all of
    the routines call |get_x_token|, which can cause them to be invoked recursively.

    The |scan_left_brace| routine is called when a left brace is supposed to be the next non-blank
    token. (The term \quote {left brace} means, more precisely, a character whose catcode is
    |left_brace|.) \TEX\ allows |\relax| to appear before the |left_brace|.

*/

/* This reads a mandatory |left_brace|: */

void tex_scan_left_brace(void)
{
    /*tex Get the next non-blank non-relax non-call token */
    while(1) {
        tex_get_x_token();
        switch (cur_cmd) {
            case left_brace_cmd:
                /* we found one */
                return;
            case spacer_cmd:
            case relax_cmd:
         /* case end_paragraph_cmd: */ /* could be an option in keyword scanner */
                /* stay in while */
                break;
            default:
                /* we recover */
                tex_handle_error(
                    back_error_type,
                    "Missing { inserted",
                    "A left brace was mandatory here, so I've put one in."
                );
                cur_tok = left_brace_token + '{';
                cur_cmd = left_brace_cmd;
                cur_chr = '{';
                ++lmt_input_state.align_state;
                return;
        }
    }
}

/*tex

    The |scan_optional_equals| routine looks for an optional |=| sign preceded by optional spaces;
    |\relax| is not ignored here.

*/

void tex_scan_optional_equals(void)
{
    /*tex Get the next non-blank non-call token. */
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_tok != equal_token) {
        tex_back_input(cur_tok);
    }
}

/*tex

    Here is a procedure that sounds an alarm when mu and non-mu units are being switched.

*/

static void tex_aux_mu_error(int n)
{
    tex_handle_error(
        normal_error_type,
        "Incompatible glue units (case %i)",
        n,
        "I'm going to assume that 1mu=1pt when they're mixed."
    );
}

/*tex

    The next routine |scan_something_internal| is used to fetch internal numeric quantities like
    |\hsize|, and also to handle the |\the| when expanding constructions like |\the\toks0| and
    |\the\baselineskip|. Soon we will be considering the |scan_int| procedure, which calls
    |scan_something_internal|; on the other hand, |scan_something_internal| also calls |scan_int|,
    for constructions like |\catcode\`\$| or |\fontdimen 3 \ff|. So we have to declare |scan_int|
    as a |forward| procedure. A few other procedures are also declared at this point.

    \TEX\ doesn't know exactly what to expect when |scan_something_internal| begins. For example,
    an integer or dimension or glue value could occur immediately after |\hskip|; and one can even
    say |\the} with respect to token lists in constructions like |\xdef\o{\the\output}|. On the
    other hand, only integers are allowed after a construction like |\count|. To handle the various
    possibilities, |scan_something_internal| has a |level| parameter, which tells the \quote
    {highest} kind of quantity that |scan_something_internal| is allowed to produce. Seven levels
    are  distinguished, namely |int_val|, |attr_val|, |dimen_val|, |glue_val|, |mu_val|, |tok_val|
    and |ident_val|.

    The output of |scan_something_internal| (and of the other routines |scan_int|, |scan_dimension|,
    and |scan_glue| below) is put into the global variable |cur_val|, and its level is put into
    |cur_val_level|. The highest values of |cur_val_level| are special: |mu_val| is used only when
    |cur_val| points to something in a \quote {muskip} register, or to one of the three parameters
    |\thinmuskip|, |\medmuskip|, |\thickmuskip|; |ident_val| is used only when |cur_val| points to
    a font identifier; |tok_val| is used only when |cur_val| points to |null| or to the reference
    count of a token list. The last two cases are allowed only when |scan_something_internal| is
    called with |level = tok_val|.

    If the output is glue, |cur_val| will point to a glue specification, and the reference count
    of that glue will have been updated to reflect this reference; if the output is a nonempty
    token list, |cur_val| will point to its reference count, but in this case the count will not
    have been updated. Otherwise |cur_val| will contain the integer or scaled value in question.

*/

scanner_state_info lmt_scanner_state = {
    .current_cmd       = 0,
    .current_chr       = 0,
    .current_cs        = 0,
 // .current_flag      = 0,
    .current_tok       = 0,
    .current_val       = 0,
    .current_val_level = 0,
    .current_box       = 0,
    .last_cs_name      = 0,
    .arithmic_error    = 0,
    .expression_depth  = 0,
};

/*tex

    When a |glue_val| changes to a |dimen_val|, we use the width component of the glue; there is no
    need to decrease the reference count, since it has not yet been increased. When a |dimen_val|
    changes to an |int_val|, we use scaled points so that the value doesn't actually change. And
    when a |mu_val| changes to a |glue_val|, the value doesn't change either.

    In \LUATEX\ we don't share glue but we have copies, so there is no need to mess with the
    reference count and downgrading.

*/

static inline void tex_aux_downgrade_cur_val(int level, int succeeded, int negative)
{
    switch (cur_val_level) {
        case posit_val_level:
            if (negative) {
                cur_val = tex_posit_neg(cur_val);
            }
            switch (level) {
                case dimension_val_level:
                    cur_val = tex_posit_to_dimension(cur_val);
                cur_val_level = level;
                    break;
                case integer_val_level:
                case attribute_val_level:
                    cur_val = (halfword) tex_posit_to_integer(cur_val);
                cur_val_level = level;
                    break;
            }
          // if (cur_val_level > level) {
          //     cur_val_level = level;
          // }
            break;
        case integer_val_level:
            if (cur_val_level > level) {
                cur_val_level = level;
            }
            if (negative) {
                cur_val = -cur_val;
            }
            if (level == posit_val_level) {
                cur_val = tex_integer_to_posit(cur_val).v;
            }
            break;
        case attribute_val_level:
            if (cur_val_level > level) {
                cur_val_level = level;
            }
            if (negative) {
                cur_val = -cur_val;
            }
            if (level == posit_val_level) {
                cur_val = tex_integer_to_posit(cur_val).v;
            }
            break;
        case dimension_val_level:
            if (cur_val_level > level) {
                cur_val_level = level;
            }
            if (negative) {
                cur_val = -cur_val;
            }
            if (level == posit_val_level) {
                cur_val = tex_dimension_to_posit(cur_val).v;
            }
            break;
        case muglue_val_level:
            if (level == glue_val_level) {
                goto COPYGLUE;
            }
        case glue_val_level:
            if (level == posit_val_level) {
                cur_val_level = level;
                cur_val = tex_dimension_to_posit(negative ? - glue_amount(cur_val) : glue_amount(cur_val)).v;
            } else if (cur_val_level > level) {
                /* we can end up here with tok_val_level and a minus .. fuzzy */
                cur_val_level = level;
                cur_val = negative ? - glue_amount(cur_val) : glue_amount(cur_val);
            } else {
              COPYGLUE:
                if (succeeded == 1) {
                    cur_val = tex_new_glue_spec_node(cur_val);
                }
                if (negative) {
                    glue_amount(cur_val) = -glue_amount(cur_val);
                    glue_stretch(cur_val) = -glue_stretch(cur_val);
                    glue_shrink(cur_val) = -glue_shrink(cur_val);
                }
            }
            break;
        case token_val_level:
        case font_val_level:
        case mathspec_val_level:
        case fontspec_val_level:
            /*tex
                This test pays back as this actually happens, but we also need it for the
                |none_lua_function| handling. We end up here in |ident_val_level| and |token_val_level|
                and they don't downgrade, nor negate which saves a little testing.
            */
            break;
     // case specification_val_level:
     // case list_val_level:
     // case no_val_level:
     //     break;
        default:
            tex_confusion("downgrade");
     }
}

/*tex

    Some of the internal items can be fetched both routines, and these have been split off into the
    next routine, that returns true if the command code was understood.

    The |last_item_cmd| branch has been flattened a bit because we don't need to treat \ETEX\
    specific thingies special any longer.

*/

static void tex_aux_set_cur_val_by_lua_value_cmd(halfword index, halfword property)
{
    int category = lua_value_none_code;
    halfword value = 0; /* can also be scaled */
    strnumber u = tex_save_cur_string();
    lmt_token_state.luacstrings = 0;
    category = lmt_function_call_by_category(index, property, &value);
    switch (category) {
        case lua_value_none_code:
            cur_val_level = no_val_level;
            break;
        case lua_value_integer_code:
        case lua_value_cardinal_code:
            cur_val_level = integer_val_level;
            break;
        case lua_value_dimension_code:
            cur_val_level = dimension_val_level;
            break;
        case lua_value_skip_code:
            cur_val_level = glue_val_level;
            break;
        case lua_value_boolean_code:
            /*tex For usage with |\ifboolean| */
            value = value ? 1 : 0;
            cur_val_level = integer_val_level;
            break;
        case lua_value_float_code:
            cur_val_level = posit_val_level;
            break;
        case lua_value_string_code:
            cur_val_level = no_val_level;
            break;
        case lua_value_node_code:
        case lua_value_direct_code:
            if (value) {
                switch (node_type(value)) {
                    case hlist_node:
                    case vlist_node:
                    case whatsit_node:
                    case rule_node:
                        cur_val_level = list_val_level;
                        break;
                    default:
                        /* maybe a warning */
                        value = null;
                        cur_val_level = no_val_level;
                        break;
                }
            } else {
                value = null;
                cur_val_level = no_val_level;
            }
            break;
        case lua_value_conditional_code:
            /* for now */
        default:
            cur_val_level = no_val_level;
            break;
    }
    cur_val = value;
    tex_restore_cur_string(u);
    if (lmt_token_state.luacstrings > 0) {
        tex_lua_string_start();
    }
}

halfword tex_scan_lua_value(int index)
{
    tex_aux_set_cur_val_by_lua_value_cmd(index, 0);
    return cur_val_level;
}

static halfword tex_aux_scan_register_index(void)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_cmd) {
        case register_toks_cmd      : return cur_chr - register_toks_base;
        case register_integer_cmd   : return cur_chr - register_integer_base;
        case register_attribute_cmd : return cur_chr - register_attribute_base;
        case register_posit_cmd     : return cur_chr - register_posit_base;
        case register_dimension_cmd : return cur_chr - register_dimension_base;
        case register_glue_cmd      : return cur_chr - register_glue_base;
        case register_muglue_cmd    : return cur_chr - register_muglue_base;
        case char_given_cmd         : return cur_chr;
        case mathspec_cmd           : return tex_get_math_spec(cur_chr).character_value;
        case integer_cmd            : return cur_chr;
     /* case index_cmd              : return cur_chr; */
        case posit_cmd              : return cur_chr;
        case dimension_cmd          : return cur_chr;
        default                     : return -1;
    }
}

static halfword tex_aux_scan_character_index(void)
{
    halfword result = -1;
    tex_get_token();
    if (cur_tok < cs_token_flag) {
        result = cur_chr;
    } else if (cur_cmd == char_given_cmd) {
        result = cur_chr;
    } else if (cur_cmd == mathspec_cmd) {
        result = tex_get_math_spec(cur_chr).character_value;
    } else {
        strnumber txt = cs_text(cur_tok - cs_token_flag);
        if (tex_single_letter(txt)) {
            result = aux_str2uni(str_string(txt));
        } else if (tex_is_active_cs(txt)) {
            result = active_cs_value(txt);
        } else {
            result = max_character_code + 1;
        }
    }
    return result > max_character_code ? -1 : result;
}

/*
    Fetch an item in the current node, if appropriate. Here is where |\last*| |\ |, and some more
    are implemented. The reference count for |\lastskip| will be updated later. We also handle
    |\inputlineno| and |\badness| here, because they are legal in similar contexts. In the follow
    up engines much more than these are handled here.
*/

static int tex_aux_set_cur_val_by_some_cmd(int code)
{
    switch (code) {
        case lastpenalty_code:
            cur_val_level = integer_val_level;
            goto COMMON;
        case lastkern_code:
            cur_val_level = dimension_val_level;
            goto COMMON;
        case lastskip_code:
            cur_val_level = glue_val_level;
            goto COMMON;
        case lastboundary_code:
            cur_val_level = integer_val_level;
          COMMON:
            {
                cur_val = 0;
                if (cur_list.tail != contribute_head && ! (cur_list.tail && node_type(cur_list.tail) == glyph_node) && cur_list.mode != nomode) {
                    switch (code) {
                        case lastpenalty_code:
                            if (node_type(cur_list.tail) == penalty_node) {
                                cur_val = penalty_amount(cur_list.tail);
                            }
                            break;
                        case lastkern_code:
                            if (node_type(cur_list.tail) == kern_node) {
                                cur_val = kern_amount(cur_list.tail);
                            }
                            break;
                        case lastskip_code:
                            if (node_type(cur_list.tail) == glue_node) {
                                cur_val = cur_list.tail;
                                if (node_subtype(cur_list.tail) == mu_glue) {
                                    cur_val_level = muglue_val_level;
                                }
                            }
                            break; /* should we return 1 ? */
                        case lastboundary_code:
                            if (node_type(cur_list.tail) == boundary_node && node_subtype(cur_list.tail) == user_boundary) {
                                cur_val = boundary_data(cur_list.tail);
                            }
                            break;
                    }
                } else if (cur_list.mode == vmode && cur_list.tail == cur_list.head) {
                    switch (code) {
                        case lastpenalty_code:
                            cur_val = lmt_page_builder_state.last_penalty;
                            break;
                        case lastkern_code:
                            cur_val = lmt_page_builder_state.last_kern;
                            break;
                        case lastskip_code:
                            if (lmt_page_builder_state.last_glue != max_halfword) {
                                cur_val = lmt_page_builder_state.last_glue;
                            }
                            break; /* should we return 1 ? */
                        case lastboundary_code:
                            cur_val = lmt_page_builder_state.last_boundary;
                            break;
                    }
                }
                break;
            }
        case last_node_type_code:
            /*tex
                We have mode nodes and when the mode parameter is set we report the real numbers.
                This is a bit messy.
            */
            {
                cur_val_level = integer_val_level;
                if (cur_list.tail != contribute_head && cur_list.mode != nomode) {
                    cur_val = node_type(cur_list.tail);
                } else if (cur_list.mode == vmode && cur_list.tail == cur_list.head) {
                    cur_val = lmt_page_builder_state.last_node_type;
                } else if (cur_list.tail == cur_list.head || cur_list.mode == nomode) {
                    cur_val = -1;
                } else {
                    cur_val = node_type(cur_list.tail);
                }
                break;
            }
        case last_node_subtype_code:
            {
                cur_val_level = integer_val_level;
                if (cur_list.tail != contribute_head && cur_list.mode != nomode) {
                    cur_val = node_subtype(cur_list.tail);
                } else if (cur_list.mode == vmode && cur_list.tail == cur_list.head) {
                    cur_val = lmt_page_builder_state.last_node_subtype;
                } else if (cur_list.tail == cur_list.head || cur_list.mode == nomode) {
                    cur_val = -1;
                } else {
                    cur_val = node_subtype(cur_list.tail);
                }
                break;
            }
        case input_line_no_code:
            cur_val = lmt_input_state.input_line;
            cur_val_level = integer_val_level;
            break;
        case badness_code:
            cur_val = lmt_packaging_state.last_badness;
            cur_val_level = integer_val_level;
            break;
        case overshoot_code:
            cur_val = lmt_packaging_state.last_overshoot;
            cur_val_level = dimension_val_level;
            break;
        case luatex_version_code:
            cur_val = lmt_version_state.version;
            cur_val_level = integer_val_level;
            break;
        case luatex_revision_code:
            cur_val = lmt_version_state.revision;
            cur_val_level = integer_val_level;
            break;
        case current_group_level_code:
            cur_val = cur_level - level_one;
            cur_val_level = integer_val_level;
            break;
        case current_group_type_code:
            cur_val = cur_group;
            cur_val_level = integer_val_level;
            break;
        case current_stack_size_code:
            cur_val = lmt_save_state.save_stack_data.ptr;
            cur_val_level = integer_val_level;
            break;
        case current_if_level_code:
            {
                halfword q = lmt_condition_state.cond_ptr;
                cur_val = 0;
                while (q) {
                    ++cur_val;
                    q = node_next(q);
                }
                cur_val_level = integer_val_level;
                break;
            }
        case current_if_type_code:
            {
                /*tex
                    We have more conditions than standard \TEX\ and \ETEX\ and the order is also somewhat
                    different. One problem is that in \ETEX\ a zero means \quotation {not in an test}, so
                    we're one off! Not that it matters much as this feature is probably never really used,
                    but we kept if for compatibility reasons. But it's gone now ... as usual with some
                    sentiment as it was nicely abstracted cleaned up code.
                */
                cur_val = lmt_condition_state.cond_ptr ? (lmt_condition_state.cur_if - first_real_if_test_code) : -1;
                cur_val_level = integer_val_level;
                break;
            }
        case current_if_branch_code:
            {
                switch (lmt_condition_state.if_limit) {
                    case if_code:
                        cur_val = 0;
                        break;
                    case fi_code:
                        cur_val = -1;
                        break;
                    case else_code:
                    case or_code:
                    case or_else_code:
                    case or_unless_code:
                        cur_val = 1;
                        break;
                    default:
                        cur_val = 0;
                        break;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case glue_stretch_order_code:
        case glue_shrink_order_code:
            {
                /*TeX
                    Not that we need it but \LUATEX\ now has |\eTeXglue..order|. In \CONTEXT\ we're
                    not using the internal codes anyway (or symbolic constants). In \LUATEX\ there
                    is some \ETEX\ related shifting but we don't do that here.
                */
                halfword q = tex_scan_glue(glue_val_level, 0, 0);
                cur_val = (code == glue_stretch_order_code) ? glue_stretch_order(q) : glue_shrink_order(q);
                tex_flush_node(q);
                cur_val_level = integer_val_level;
                break;
            }
        case font_id_code:
            {
                cur_val = tex_scan_font_identifier(NULL);
                cur_val_level = integer_val_level;
                break;
            }
        case glyph_x_scaled_code:
            {
                cur_val = tex_font_x_scaled(tex_scan_dimension(0, 0, 0, 1, NULL));
                cur_val_level = dimension_val_level;
                break;
            }
        case glyph_y_scaled_code:
            {
                cur_val = tex_font_y_scaled(tex_scan_dimension(0, 0, 0, 1, NULL));
                cur_val_level = dimension_val_level;
                break;
            }
        case font_spec_id_code:
        case font_spec_scale_code:
        case font_spec_xscale_code:
        case font_spec_yscale_code:
        case font_spec_slant_code:
        case font_spec_weight_code:
            {
                halfword fs = tex_scan_fontspec_identifier();
                if (fs) {
                    switch (code) {
                        case font_spec_id_code:
                            cur_val = font_spec_identifier(fs);
                            break;
                        case font_spec_scale_code:
                            cur_val = font_spec_scale(fs);
                            break;
                        case font_spec_xscale_code:
                            cur_val = font_spec_x_scale(fs);
                            break;
                        case font_spec_yscale_code:
                            cur_val = font_spec_y_scale(fs);
                            break;
                        case font_spec_slant_code:
                            cur_val = font_spec_slant(fs);
                            break;
                        case font_spec_weight_code:
                            cur_val = font_spec_weight(fs);
                            break;
                    }
                } else {
                    cur_val = 0;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case font_char_wd_code:
        case font_char_ht_code:
        case font_char_dp_code:
        case font_char_ic_code:
        case font_char_ta_code:
        case font_char_ba_code:
        case scaled_font_char_wd_code:
        case scaled_font_char_ht_code:
        case scaled_font_char_dp_code:
        case scaled_font_char_ic_code:
        case scaled_font_char_ta_code:
        case scaled_font_char_ba_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                halfword chr = tex_scan_char_number(0);
                if (tex_char_exists(fnt, chr)) {
                    switch (code) {
                        case font_char_wd_code:
                        case scaled_font_char_wd_code:
                            cur_val = tex_char_width_from_font(fnt, chr);
                            break;
                        case font_char_ht_code:
                        case scaled_font_char_ht_code:
                            cur_val = tex_char_height_from_font(fnt, chr);
                            break;
                        case font_char_dp_code:
                        case scaled_font_char_dp_code:
                            cur_val = tex_char_depth_from_font(fnt, chr);
                            break;
                        case font_char_ic_code:
                        case scaled_font_char_ic_code:
                            cur_val = tex_char_italic_from_font(fnt, chr);
                            break;
                        case font_char_ta_code:
                        case scaled_font_char_ta_code:
                            cur_val = tex_char_top_anchor_from_font(fnt, chr);
                            break;
                        case font_char_ba_code:
                        case scaled_font_char_ba_code:
                            cur_val = tex_char_bottom_anchor_from_font(fnt, chr);
                            break;
                    }
                    switch (code) {
                        case scaled_font_char_wd_code:
                        case scaled_font_char_ic_code:
                        case scaled_font_char_ta_code:
                        case scaled_font_char_ba_code:
                            cur_val = tex_font_x_scaled(cur_val);
                            break;
                        case scaled_font_char_ht_code:
                        case scaled_font_char_dp_code:
                            cur_val = tex_font_y_scaled(cur_val);
                            break;
                    }
                } else {
                    cur_val = 0;
                }
                cur_val_level = dimension_val_level;
                break;
            }
        case font_size_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                cur_val = font_size(fnt);
                cur_val_level = dimension_val_level;
                break;
            }
        case font_math_control_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                cur_val = font_mathcontrol(fnt);
                cur_val_level = integer_val_level;
                break;
            }
        case font_text_control_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                cur_val = font_textcontrol(fnt);
                cur_val_level = integer_val_level;
                break;
            }
        case math_scale_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                if (tex_is_valid_font(fnt)) {
                    cur_val = tex_get_math_font_scale(fnt, tex_math_style_to_size(tex_current_math_style()));
                } else {
                    cur_val = 1000;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case math_style_code:
            {
                cur_val = tex_current_math_style();
                if (cur_val < 0) {
                    cur_val = text_style;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case math_main_style_code:
            {
                cur_val = tex_current_math_main_style();
                if (cur_val < 0) {
                    cur_val = text_style;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case math_parent_style_code:
            {
                cur_val = tex_current_math_parent_style();
                if (cur_val < 0) {
                    cur_val = text_style;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case math_style_font_id_code:
            {
                halfword style = tex_scan_math_style_identifier(0, 0);
                halfword family = tex_scan_math_family_number();
                cur_val = tex_fam_fnt(family, tex_size_of_style(style));
                cur_val_level = integer_val_level;
                break;
            }
        case math_stack_style_code:
            {
                cur_val = tex_math_style_variant(cur_list.math_style, math_parameter_stack_variant);
                if (cur_val < 0) {
                    cur_val = text_style;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case math_char_class_code:
        case math_char_fam_code:
        case math_char_slot_code:
            /* we actually need two commands or we need to look ahead */
            {
                mathcodeval mval = tex_no_math_code();
                mathdictval dval = tex_no_dict_code();
                if (tex_scan_math_cmd_val(&mval, &dval)) {
                    switch (code) {
                        case math_char_class_code:
                            cur_val = mval.class_value;
                            break;
                        case math_char_fam_code:
                            cur_val = mval.family_value;
                            break;
                        case math_char_slot_code:
                            cur_val = mval.character_value;
                            break;
                        default:
                            cur_val = 0;
                            break;
                    }
                } else {
                     cur_val = 0;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case scaled_slant_per_point_code:
        case scaled_interword_space_code:
        case scaled_interword_stretch_code:
        case scaled_interword_shrink_code:
        case scaled_ex_height_code:
        case scaled_em_width_code:
        case scaled_extra_space_code:
            {
                cur_val =  tex_get_scaled_parameter(cur_font_par, (code - scaled_slant_per_point_code + 1));
                cur_val_level = dimension_val_level;
                break;
            }
        case scaled_math_axis_code:
        case scaled_math_ex_height_code:
        case scaled_math_em_width_code:
            {
                halfword style = tex_scan_math_style_identifier(0, 0);
                switch (code) {
                    case scaled_math_axis_code:
                        cur_val = tex_math_parameter_x_scaled(style, math_parameter_axis);
                        break;
                    case scaled_math_ex_height_code:
                        cur_val = tex_math_parameter_y_scaled(style, math_parameter_exheight);
                        break;
                    case scaled_math_em_width_code:
                        cur_val = tex_math_parameter_x_scaled(style, math_parameter_quad);
                        break;
                }
                cur_val_level = dimension_val_level;
                break;
            }
        case last_arguments_code:
            {
                cur_val = lmt_expand_state.arguments;
                cur_val_level = integer_val_level;
                break;
            }
        case parameter_count_code:
            {
                cur_val = tex_get_parameter_count();
                cur_val_level = integer_val_level;
                break;
            }
        case parameter_index_code:
            {
                cur_val = tex_get_parameter_index(tex_scan_parameter_index());
                cur_val_level = integer_val_level;
                break;
            }
        /*
        case lua_value_function_code:
            {
                halfword v = scan_integer(0, NULL);
                if (v <= 0) {
                    tex_normal_error("luafunction", "invalid number");
                } else {
                    set_cur_val_by_lua_value_cmd(code);
                }
                return 1;
            }
        */
        case insert_progress_code:
            {
                cur_val = tex_get_insert_progress(tex_scan_integer(0, NULL));
                cur_val_level = dimension_val_level;
                break;
            }
        case left_margin_kern_code:
        case right_margin_kern_code:
            {
                halfword v = tex_scan_integer(0, NULL);
                halfword b = box_register(v);
                if (b && (node_type(b) == hlist_node)) {
                    if (code == left_margin_kern_code) {
                        cur_val = tex_left_marginkern(box_list(b));
                    } else {
                        cur_val = tex_right_marginkern(box_list(b));
                    }
                } else {
                    tex_normal_error("marginkern", "a hbox expected");
                    cur_val = 0;
                }
                cur_val_level = dimension_val_level;
                break;
            }
        case par_shape_length_code:
            {
                cur_val = par_shape_par ? specification_count(par_shape_par) : 0;
                cur_val_level = integer_val_level;
                break;
            }
        case par_shape_indent_code:
        case par_shape_width_code:
            {
                halfword shape = par_shape_par;
                if (shape) {
                    halfword index = tex_scan_integer(0, NULL);
                    if (index >= 1 && index <= specification_count(shape)) {
                        cur_val = code == par_shape_indent_code ? tex_get_specification_indent(shape, index) : tex_get_specification_width(shape, index);
                    } else {
                        cur_val = 0;
                    }
                } else {
                    cur_val = 0;
                }
                cur_val_level = dimension_val_level;
                break;
            }
        case glue_stretch_code:
        case glue_shrink_code:
            {
                halfword q = tex_scan_glue(glue_val_level, 0, 0);
                cur_val = code == glue_stretch_code ? glue_stretch(q) : glue_shrink(q);
                tex_flush_node(q);
                cur_val_level = dimension_val_level;
                break;
            }
        case mu_to_glue_code:
            cur_val = tex_scan_glue(muglue_val_level, 0, 0);
            cur_val_level = glue_val_level;
            return 1;
        case glue_to_mu_code:
            cur_val = tex_scan_glue(glue_val_level, 0, 0);
            cur_val_level = muglue_val_level;
            return 1;
        case numexpr_code:
     /* case attrexpr_code: */
            tex_aux_scan_expr(integer_val_level);
            return 1;
        case posexpr_code:
            tex_aux_scan_expr(posit_val_level);
            return 1;
        case dimexpr_code:
            tex_aux_scan_expr(dimension_val_level);
            return 1;
        case glueexpr_code:
            tex_aux_scan_expr(glue_val_level);
            return 1;
        case muexpr_code:
            tex_aux_scan_expr(muglue_val_level);
            return 1;
        case numexpression_code:
            tex_aux_scan_expression(integer_val_level);
            return 1;
        case dimexpression_code:
            tex_aux_scan_expression(dimension_val_level);
            return 1;
     // case dimen_to_scale_code:
     //     cur_val_level = integer_val_level;
     //     cur_val = round_xn_over_d(100, scan_dimension(0, 0, 0, 0, NULL), 65536);
     //     return 1;
        case numeric_scale_code:
            cur_val_level = integer_val_level;
            cur_val = tex_scan_scale(0);
            return 1;
        case numeric_scaled_code:
            {
                scaled n = tex_scan_scale(0);
                scaled i = tex_scan_integer(0, NULL);
                cur_val_level = integer_val_level;
                cur_val = tex_xn_over_d(i, n, scaling_factor);
            }
            return 1;
        case index_of_register_code:
            cur_val = tex_aux_scan_register_index();
            cur_val_level = integer_val_level;
            return 1;
        case index_of_character_code:
            cur_val = tex_aux_scan_character_index();
            cur_val_level = integer_val_level;
            return 1;
        case last_chk_integer_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_condition_state.chk_integer;
            return 1;
        case last_chk_dimension_code:
            cur_val_level = dimension_val_level;
            cur_val = lmt_condition_state.chk_dimension;
            return 1;
        case last_left_class_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_math_state.last_left;
            if (! valid_math_class_code(cur_val)) {
                cur_val = unset_noad_class;
            }
            return 1;
        case last_right_class_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_math_state.last_right;
            if (! valid_math_class_code(cur_val)) {
                cur_val = unset_noad_class;
            }
            return 1;
        case last_atom_class_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_math_state.last_atom;
            if (! valid_math_class_code(cur_val)) {
                cur_val = unset_noad_class;
            }
            return 1;
        case nested_loop_iterator_code:
            cur_val = tex_nested_loop_iterator();
            cur_val_level = integer_val_level;
            return 1;
        case previous_loop_iterator_code:
            cur_val = tex_previous_loop_iterator();
            cur_val_level = integer_val_level;
            return 1;
        case current_loop_iterator_code:
        case last_loop_iterator_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_main_control_state.loop_iterator;
            return 1;
        case current_loop_nesting_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_main_control_state.loop_nesting;
            return 1;
        case last_par_trigger_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_main_control_state.last_par_trigger;
            return 1;
        case last_par_context_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_main_control_state.last_par_context;
            return 1;
        case last_page_extra_code:
            cur_val_level = integer_val_level;
            cur_val = lmt_page_builder_state.last_extra_used;
            return 1;
        case math_atom_glue_code:
            {
                halfword style = tex_scan_math_style_identifier(0, 0);
                halfword leftclass = tex_scan_math_class_number(0);
                halfword rightclass = tex_scan_math_class_number(0);
                cur_val = tex_math_spacing_glue(leftclass, rightclass, style);
                cur_val_level = muglue_val_level;
                break;
            }
    }
    return 0;
}

static void tex_aux_set_cur_val_by_auxiliary_cmd(int code)
{
    switch (code) {
        case space_factor_code:
            if (is_h_mode(cur_list.mode)) {
                cur_val = cur_list.space_factor;
            } else {
                tex_handle_error(normal_error_type, "Improper %C", auxiliary_cmd, code,
                    "You can refer to \\spacefactor only in horizontal mode and not in \n"
                    "inside \\write. So I'm forgetting what you said and using zero instead."
                );
                cur_val = 0;
            }
            cur_val_level = integer_val_level;
            break;
        case prev_depth_code:
            if (is_v_mode(cur_list.mode)) {
                cur_val = cur_list.prev_depth;
            } else {
                tex_handle_error(normal_error_type, "Improper %C", auxiliary_cmd, code,
                    "You can refer to \\prevdepth only in horizontal mode and not in \n"
                    "inside \\write. So I'm forgetting what you said and using zero instead."
                );
                cur_val = 0;
            }
            cur_val_level = dimension_val_level;
            break;
        case prev_graf_code:
            if (cur_list.mode == nomode) {
                /*tex So |prev_graf=0| within |\write|, not that we have that. */
                cur_val = 0;
            } else {
                cur_val = lmt_nest_state.nest[tex_vmode_nest_index()].prev_graf;
            }
            cur_val_level = integer_val_level;
            break;
        case interaction_mode_code:
            cur_val = lmt_error_state.interaction;
            cur_val_level = integer_val_level;
            break;
        case insert_mode_code:
            cur_val = lmt_insert_state.mode;
            cur_val_level = integer_val_level;
            break;
    }
}

/*tex
    For penalty specifications a zero count will report the number of entries. For the others we
    always report that value. New is that negative numbers will count from the end.
*/

static void tex_aux_set_cur_val_by_specification_cmd(int code)
{
    halfword spec = eq_value(code);
    cur_val = spec ? tex_aux_get_specification_value(spec, code) : 0;
    cur_val_level = integer_val_level;
}

# define page_state_okay (lmt_page_builder_state.contents == contribute_nothing && ! lmt_page_builder_state.output_active)

static void tex_aux_set_cur_val_by_page_property_cmd(int code)
{
    switch (code) {
        case page_goal_code:
            cur_val = page_state_okay ? max_dimension : lmt_page_builder_state.goal;
            cur_val_level = dimension_val_level;
            break;
        case page_vsize_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.vsize;
            cur_val_level = dimension_val_level;
            break;
        case page_total_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.total;
            cur_val_level = dimension_val_level;
            break;
        case page_excess_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.excess;
            cur_val_level = dimension_val_level;
            break;
        case page_depth_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.depth;
            cur_val_level = dimension_val_level;
            break;
        case page_stretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.stretch;
            cur_val_level = dimension_val_level;
            break;
        case page_fistretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.fistretch;
            cur_val_level = dimension_val_level;
            break;
        case page_filstretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.filstretch;
            cur_val_level = dimension_val_level;
            break;
        case page_fillstretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.fillstretch;
            cur_val_level = dimension_val_level;
            break;
        case page_filllstretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.filllstretch;
            cur_val_level = dimension_val_level;
            break;
        case page_shrink_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.shrink;
            cur_val_level = dimension_val_level;
            break;
        case page_last_height_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_height;
            cur_val_level = dimension_val_level;
            break;
        case page_last_depth_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_depth;
            cur_val_level = dimension_val_level;
            break;
        case page_last_stretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_stretch;
            cur_val_level = dimension_val_level;
            break;
        case page_last_fistretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_fistretch;
            cur_val_level = dimension_val_level;
            break;
        case page_last_filstretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_filstretch;
            cur_val_level = dimension_val_level;
            break;
        case page_last_fillstretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_fillstretch;
            cur_val_level = dimension_val_level;
            break;
        case page_last_filllstretch_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_filllstretch;
            cur_val_level = dimension_val_level;
            break;
        case page_last_shrink_code:
            cur_val = page_state_okay ? 0 : lmt_page_builder_state.last_shrink;
            cur_val_level = dimension_val_level;
            break;
        case dead_cycles_code:
            cur_val = lmt_page_builder_state.dead_cycles;
            cur_val_level = integer_val_level;
            break;
        case insert_penalties_code:
            cur_val = lmt_page_builder_state.insert_penalties;
            cur_val_level = integer_val_level;
            break;
        case insert_heights_code:
            cur_val = lmt_page_builder_state.insert_heights;
            cur_val_level = dimension_val_level;
            break;
        case insert_storing_code:
            cur_val = lmt_insert_state.storing;
            cur_val_level = integer_val_level;
            break;
        case insert_distance_code:
            cur_val = tex_get_insert_distance(tex_scan_integer(0, NULL));
            cur_val_level = glue_val_level;
            break;
        case insert_multiplier_code:
            cur_val = tex_get_insert_multiplier(tex_scan_integer(0, NULL));
            cur_val_level = integer_val_level;
            break;
        case insert_limit_code:
            cur_val = tex_get_insert_limit(tex_scan_integer(0, NULL));
            cur_val_level = dimension_val_level;
            break;
        case insert_storage_code:
            cur_val = tex_get_insert_storage(tex_scan_integer(0, NULL));
            cur_val_level = integer_val_level;
            break;
        case insert_penalty_code:
            cur_val = tex_get_insert_penalty(tex_scan_integer(0, NULL));
            cur_val_level = integer_val_level;
            break;
        case insert_maxdepth_code:
            cur_val = tex_get_insert_maxdepth(tex_scan_integer(0, NULL));
            cur_val_level = dimension_val_level;
            break;
        case insert_height_code:
            cur_val = tex_get_insert_height(tex_scan_integer(0, NULL));
            cur_val_level = dimension_val_level;
            break;
        case insert_depth_code:
            cur_val = tex_get_insert_depth(tex_scan_integer(0, NULL));
            cur_val_level = dimension_val_level;
            break;
        case insert_width_code:
            cur_val = tex_get_insert_width(tex_scan_integer(0, NULL));
            cur_val_level = dimension_val_level;
            break;
        default:
            tex_confusion("page property");
            break;
    }
}

static void tex_aux_set_cur_val_by_define_char_cmd(int code)
{
    halfword index = tex_scan_char_number(0);
    switch (code) {
        case catcode_charcode:
            code = tex_get_cat_code(cat_code_table_par, index);
            break;
        case lccode_charcode:
            code = tex_get_lc_code(index);
            break;
        case uccode_charcode:
            code = tex_get_uc_code(index);
            break;
        case sfcode_charcode:
            code = tex_get_sf_code(index);
            break;
        case hccode_charcode:
            code = tex_get_hc_code(index);
            break;
        case hmcode_charcode:
            code = tex_get_hm_code(index);
            break;
        case amcode_charcode:
            code = tex_get_am_code(index);
            break;
        case cccode_charcode:
            code = tex_get_cc_code(index);
            break;
        case mathcode_charcode:
        case extmathcode_charcode:
            code = tex_get_math_code_number(index);
            break;
        case delcode_charcode:
        case extdelcode_charcode:
            code = tex_get_del_code_number(index);
            break;
        default:
            tex_confusion("scan char");
            break;
    }
    cur_val = code;
    cur_val_level = integer_val_level;
}

/*
    First, here is a short routine that is called from lua code. All the real work is delegated to
    |short_scan_something_internal| that is shared between this routine and |scan_something_internal|.
    In the end it was much cleaner to integrate |tex_aux_short_scan_something_internal| into the two
    switches.
*/

static halfword tex_aux_scan_math_style_number(halfword code)
{
    switch (code) {
        case yet_unset_math_style:
            return tex_scan_math_style_identifier(0, 0);
        case scaled_math_style:
            return cur_list.math_scale;
        case former_choice_math_style:
            return 0;
        default:
            return code;
    }
}

static void tex_aux_set_cur_val_by_math_style_cmd(halfword code)
{
    cur_val = tex_aux_scan_math_style_number(code);
    cur_val_level = integer_val_level;
}

/*tex

    OK, we're ready for |scan_something_internal| itself. A second parameter, |negative|, is set
    |true| if the value that is found should be negated. It is assumed that |cur_cmd| and |cur_chr|
    represent the first token of the internal quantity to be scanned; an error will be signalled if
    |cur_cmd < min_internal| or |cur_cmd > max_internal|.

*/

/*tex Fetch an internal parameter: */

static void tex_aux_missing_number_error(int where)
{
    tex_handle_error(
        back_error_type,
        "Missing number, case %i, treated as zero", where,
        "A number should have been here; I inserted '0'. (If you can't figure out why I\n"
        "needed to see a number, look up 'weird error' in the index to The TeXbook.)"
    );
}

/* todo: get rid of cur_val */

// static int tex_aux_valid_tok_level(halfword level)
// {
//     if (level == token_val_level) {
//         return 1;
//     } else {
//         if (lmt_error_state.intercept) {
//             lmt_error_state.last_intercept = 1 ;
//         } else {
//             tex_aux_missing_number_error();
//         }
//         cur_val = 0;
//         cur_val_level = dimension_val_level; /* why dimen */
//         return 0;
//     }
// }

static int tex_aux_scan_hyph_data_number(halfword code, halfword *target)
{
    switch (code) {
        case prehyphenchar_code:
            *target = tex_get_pre_hyphen_char(language_par);
            break;
        case posthyphenchar_code:
            *target = tex_get_post_hyphen_char(language_par);
            break;
        case preexhyphenchar_code:
            *target = tex_get_pre_exhyphen_char(language_par);
            break;
        case postexhyphenchar_code:
            *target = tex_get_post_exhyphen_char(language_par);
            break;
        case hyphenationmin_code:
            *target = tex_get_hyphenation_min(language_par);
            break;
        case hjcode_code:
            *target = tex_get_hj_code(language_par, tex_scan_integer(0, NULL));
            break;
        default:
            return 0;
    }
    return 1;
}

static void tex_aux_set_cur_val_by_math_parameter_cmd(halfword chr)
{
    switch (chr) {
        case math_parameter_reset_spacing:
            /* or just zero */
        case math_parameter_set_spacing:
        case math_parameter_let_spacing:
        case math_parameter_copy_spacing:
            {
                halfword left = tex_scan_math_class_number(0);
                halfword right = tex_scan_math_class_number(0);
                halfword style = tex_scan_math_style_identifier(0, 0);
                halfword node = tex_math_spacing_glue(left, right, style);
                cur_val = node ? node : zero_glue;
                cur_val_level = muglue_val_level;
                break;
            }
        case math_parameter_set_atom_rule:
        case math_parameter_let_atom_rule:
        case math_parameter_copy_atom_rule:
        // case math_parameter_let_parent:
        case math_parameter_copy_parent:
        case math_parameter_set_defaults:
            {
                // cur_val = 0;
                // cur_val_level = integer_val_level;
                break;
            }
        case math_parameter_let_parent:
            {
                halfword mathclass = tex_scan_math_class_number(0);
                if (valid_math_class_code(mathclass)) {
                    cur_val = tex_math_has_class_parent(mathclass);
                    cur_val_level = integer_val_level;
                }
                break;
            }
        case math_parameter_set_pre_penalty:
        case math_parameter_set_post_penalty:
        case math_parameter_set_display_pre_penalty:
        case math_parameter_set_display_post_penalty:
            {
                halfword mathclass = tex_scan_math_class_number(0);
                if (valid_math_class_code(mathclass)) {
                    switch (chr) {
                        case math_parameter_set_pre_penalty:
                            cur_val = count_parameter(first_math_pre_penalty_code + mathclass);
                            break;
                        case math_parameter_set_post_penalty:
                            cur_val = count_parameter(first_math_post_penalty_code + mathclass);
                            break;
                        case math_parameter_set_display_pre_penalty:
                            cur_val = count_parameter(first_math_display_pre_penalty_code + mathclass);
                            break;
                        case math_parameter_set_display_post_penalty:
                            cur_val = count_parameter(first_math_display_post_penalty_code + mathclass);
                            break;
                    }
                } else {
                    cur_val = 0;
                }
                cur_val_level = integer_val_level;
                break;
            }
        case math_parameter_ignore:
            {
                halfword code = tex_scan_math_parameter();
                cur_val = code >= 0 ? count_parameter(first_math_ignore_code + code) : 0;
                cur_val_level = integer_val_level;
                break;
            }
        case math_parameter_options:
            {
                halfword mathclass = tex_scan_math_class_number(0);
                if (valid_math_class_code(mathclass)) {
                    cur_val = count_parameter(first_math_options_code + mathclass);
                } else {
                    cur_val = 0;
                }
                break;
            }
        default:
            {
                cur_val = tex_scan_math_style_identifier(0, 0);
                switch (math_parameter_value_type(chr)) {
                    case math_integer_parameter:
                        cur_val_level = integer_val_level;
                        break;
                    case math_dimension_parameter:
                        cur_val_level = dimension_val_level;
                        break;
                    case math_muglue_parameter:
                        cur_val_level = muglue_val_level;
                        break;
                    case math_style_parameter:
                        cur_val_level = integer_val_level;
                        break;
                }
                chr = tex_get_math_parameter(cur_val, chr, NULL);
                if (cur_val_level == muglue_val_level) {
                    switch (chr) {
                        case petty_muskip_code:
                            chr = petty_muskip_par;
                            break;
                        case tiny_muskip_code:
                            chr = tiny_muskip_par;
                            break;
                        case thin_muskip_code:
                            chr = thin_muskip_par;
                            break;
                        case med_muskip_code:
                            chr = med_muskip_par;
                            break;
                        case thick_muskip_code:
                            chr = thick_muskip_par;
                            break;
                    }
                }
                cur_val = chr;
                break;
            }
    }
}

static void tex_aux_set_cur_val_by_box_property_cmd(halfword chr)
{
    /*tex We hike on the dimen_cmd but some are integers. */
    halfword n = tex_scan_box_register_number();
    halfword b = box_register(n);
    switch (chr) {
        case box_width_code:
            cur_val = b ? box_width(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_height_code:
            cur_val = b ? box_height(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_depth_code:
            cur_val = b ? box_depth(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_direction_code:
            cur_val = b ? box_dir(b) : 0;
            cur_val_level = integer_val_level;
            break;
        case box_geometry_code:
            cur_val = b ? box_geometry(b) : 0;
            cur_val_level = integer_val_level;
            break;
        case box_orientation_code:
            cur_val = b ? box_orientation(b) : 0;
            cur_val_level = integer_val_level;
            break;
        case box_anchor_code:
        case box_anchors_code:
            cur_val = b ? box_anchor(b) : 0;
            cur_val_level = integer_val_level;
            break;
        case box_source_code:
            cur_val = b ? box_source_anchor(b) : 0;
            cur_val_level = integer_val_level;
            break;
        case box_target_code:
            cur_val = b ? box_target_anchor(b) : 0;
            cur_val_level = integer_val_level;
            break;
        case box_xoffset_code:
            cur_val = b ? box_x_offset(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_yoffset_code:
            cur_val = b ? box_y_offset(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_xmove_code:
            cur_val = b ? (box_width(b) - box_x_offset(b)) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_ymove_code:
            cur_val = b ? (box_total(b) - box_y_offset(b)) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_total_code:
            cur_val = b ? box_total(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_shift_code:
            cur_val = b ? box_shift_amount(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_adapt_code:
            cur_val = 0;
            cur_val_level = integer_val_level;
            break;
        case box_repack_code:
            if (node_type(b) == hlist_node) {
                cur_val = box_list(b) ? tex_natural_hsize(box_list(b), NULL) : 0;
            } else {
                cur_val = box_list(b) ? tex_natural_vsize(box_list(b)) : 0;
            }
            cur_val_level = dimension_val_level;
            break;
        case box_stretch_code:
            cur_val = box_list(b) ? tex_stretch(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_shrink_code:
            cur_val = box_list(b) ? tex_shrink(b) : 0;
            cur_val_level = dimension_val_level;
            break;
        case box_freeze_code:
            cur_val = node_type(b) == hlist_node ? box_width(b) : box_total(b);
            cur_val_level = dimension_val_level;
            break;
        case box_limitate_code:
            /* todo: return the delta */
            cur_val = node_type(b) == hlist_node ? box_width(b) : box_total(b);
            cur_val_level = dimension_val_level;
            break;
        case box_finalize_code:
            /* todo: return what? */
            cur_val = node_type(b) == hlist_node ? box_width(b) : box_total(b);
            cur_val_level = dimension_val_level;
            break;
        case box_limit_code:
            /* todo: return the delta */
            cur_val = node_type(b) == hlist_node ? box_width(b) : box_total(b);
            cur_val_level = dimension_val_level;
            break;
        case box_attribute_code:
            {
                halfword att = tex_scan_attribute_register_number();
                cur_val = b ? tex_has_attribute(b, att, unused_attribute_value) : unused_attribute_value; /* always b */
                cur_val_level = integer_val_level;
                break;
            }
        case box_vadjust_code:
            cur_val = 0;
            if (b) {
                if (box_pre_adjusted(b)) {
                    cur_val |= has_pre_adjust;
                }
                if (box_post_adjusted(b)) {
                    cur_val |= has_post_adjust;
                }
                if (box_pre_migrated(b)) {
                    cur_val |= has_pre_migrated;
                }
                if (box_post_migrated(b)) {
                    cur_val |= has_post_migrated;
                }
            }
            cur_val_level = integer_val_level;
            break;
    }
}

static void tex_aux_set_cur_val_by_font_property_cmd(halfword chr)
{
    switch (chr) {
        case font_hyphen_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                cur_val = font_hyphen_char(fnt);
                cur_val_level = integer_val_level;
                break;
            }
        case font_skew_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                cur_val = font_skew_char(fnt);
                cur_val_level = integer_val_level;
                break;
            }
        case font_lp_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                halfword chr = tex_scan_char_number(0);
                cur_val = tex_char_lp_from_font(fnt, chr);
                cur_val_level = dimension_val_level;
                break;
            }
        case font_rp_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                halfword chr = tex_scan_char_number(0);
                cur_val = tex_char_rp_from_font(fnt, chr);
                cur_val_level = dimension_val_level;
                break;
            }
        case font_ef_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                halfword chr = tex_scan_char_number(0);
                cur_val = tex_char_ef_from_font(fnt, chr);
                cur_val_level = integer_val_level;
                break;
            }
        case font_cf_code:
            {
                halfword fnt = tex_scan_font_identifier(NULL);
                halfword chr = tex_scan_char_number(0);
                cur_val = tex_char_cf_from_font(fnt, chr);
                cur_val_level = integer_val_level;
                break;
            }
        case font_dimension_code:
            {
                cur_val = tex_get_font_dimension();
                cur_val_level = dimension_val_level;
                break;
            }
        case scaled_font_dimension_code:
            {
                cur_val = tex_get_scaled_font_dimension();
                cur_val_level = dimension_val_level;
                break;
            }
    }
}

static void tex_aux_set_cur_val_by_register_cmd(halfword chr)
{
    switch (chr) {
        case integer_val_level:
            {
                halfword n = tex_scan_integer_register_number();
                cur_val = count_register(n);
                break;
            }
        case attribute_val_level:
            {
                halfword n = tex_scan_attribute_register_number();
                cur_val = attribute_register(n);
                break;
            }
        case posit_val_level:
            {
                halfword n = tex_scan_posit_register_number();
                cur_val = posit_register(n);
                break;
            }
        case dimension_val_level:
            {
                scaled n = tex_scan_dimension_register_number();
                cur_val = dimension_register(n);
                break;
            }
        case glue_val_level:
            {
                halfword n = tex_scan_glue_register_number();
                cur_val = skip_register(n);
                break;
            }
        case muglue_val_level:
            {
                halfword n = tex_scan_muglue_register_number();
                cur_val = muskip_register(n);
                break;
            }
        case token_val_level:
            {
                halfword n = tex_scan_toks_register_number();
                cur_val = toks_register(n);
                break;
            }
    }
    cur_val_level = chr;
}

static void tex_aux_set_cur_val_by_math_spec_cmd(halfword chr)
{
    cur_val = chr;
    if (chr) {
        switch (node_subtype(chr)) {
            case tex_mathcode:
                cur_val = math_spec_value(chr);
                cur_val_level = integer_val_level;
                break;
            case umath_mathcode:
            /* case umathnum_mathcode: */
            case mathspec_mathcode:
                cur_val_level = mathspec_val_level;
                break;
            default:
                cur_val = 0;
                cur_val_level = integer_val_level;
                break;
        }
    } else {
        cur_val_level = integer_val_level;
    }
}

static halfword tex_aux_scan_something_internal(halfword cmd, halfword chr, int level, int negative, halfword property)
{
    int succeeded = 1;
    switch (cmd) {
        /* begin of tex_aux_short_scan_something_internal */
        case char_given_cmd:
            cur_val = chr;
            cur_val_level = integer_val_level;
            break;
        case some_item_cmd:
            {
                /*tex
                    Because the items in this case directly refer to |cur_chr|, it needs to be saved
                    and restored.
                */
                int save_cur_chr = cur_chr;
                cur_chr = chr;
                if (tex_aux_set_cur_val_by_some_cmd(chr)) {
                    succeeded = 2;
                } else {
                    cur_chr = save_cur_chr;
                }
                break;
            }
        case internal_toks_cmd:
        case register_toks_cmd:
            cur_val = eq_value(chr);
            cur_val_level = token_val_level;
            break;
        case internal_integer_cmd:
        case register_integer_cmd:
        case internal_attribute_cmd:
        case register_attribute_cmd:
            cur_val = eq_value(chr);
            cur_val_level = integer_val_level;
            if (level == posit_val_level) {
                cur_val = (halfword) tex_posit_to_integer(cur_val);
            }
            break;
        case internal_posit_cmd:
        case register_posit_cmd:
            cur_val = eq_value(chr);
            cur_val_level = posit_val_level;
            break;
        case internal_dimension_cmd:
        case register_dimension_cmd:
            cur_val = eq_value(chr);
            cur_val_level = dimension_val_level;
            if (level == posit_val_level) {
                cur_val = tex_posit_to_dimension(cur_val);
            }
            break;
        case internal_glue_cmd:
        case register_glue_cmd:
            cur_val = eq_value(chr);
            cur_val_level = glue_val_level;
            break;
        case internal_muglue_cmd:
        case register_muglue_cmd:
            cur_val = eq_value(chr);
            cur_val_level = muglue_val_level;
            break;
        case lua_value_cmd:
            tex_aux_set_cur_val_by_lua_value_cmd(chr, property);
            if (cur_val_level == no_val_level) {
                return 0;
            }
            break;
        case iterator_value_cmd:
            cur_val = chr > 0x100000 ? - (chr - 0x100000) : chr;
            cur_val_level = integer_val_level;
            break;
        case math_style_cmd:
            tex_aux_set_cur_val_by_math_style_cmd(chr);
            break;
        case auxiliary_cmd:
            tex_aux_set_cur_val_by_auxiliary_cmd(chr);
            break;
        case page_property_cmd:
            tex_aux_set_cur_val_by_page_property_cmd(chr);
            break;
        case specification_cmd:
            tex_aux_set_cur_val_by_specification_cmd(chr);
            break;
        case define_char_code_cmd:
            tex_aux_set_cur_val_by_define_char_cmd(chr);
            break;
        /* end of tex_aux_short_scan_something_internal */
        case define_font_cmd:
         // if (tex_aux_valid_tok_level(level)) {
            if (level == token_val_level) { /* Is this test still needed? */
                cur_val = cur_font_par;
                cur_val_level = font_val_level;
                return cur_val;
            } else {
                break;
            }
        case set_font_cmd:
         // if (tex_aux_valid_tok_level(level)) {
            if (level == token_val_level) { /* Is this test still needed? */
                cur_val = cur_chr;
                cur_val_level = font_val_level;
                return cur_val;
            } else {
                break;
            }
        case define_family_cmd:
            {
                halfword fam = tex_scan_math_family_number();
                cur_val = tex_fam_fnt(fam, chr);
                cur_val_level = font_val_level;
                return cur_val;
            }
        case math_parameter_cmd:
            tex_aux_set_cur_val_by_math_parameter_cmd(chr);
            break;
        case box_property_cmd:
            tex_aux_set_cur_val_by_box_property_cmd(chr);
            break;
        case font_property_cmd:
            tex_aux_set_cur_val_by_font_property_cmd(chr);
            break;
        case register_cmd:
            tex_aux_set_cur_val_by_register_cmd(chr);
            break;
        case ignore_something_cmd:
            break;
        case hyphenation_cmd:
            if (tex_aux_scan_hyph_data_number(chr, &cur_val)) {
                cur_val_level = integer_val_level;
                break;
            } else {
                goto DEFAULT;
            }
        case integer_cmd:
        case index_cmd:
            cur_val = chr;
            cur_val_level = integer_val_level;
            break;
        case dimension_cmd:
            cur_val = chr;
            cur_val_level = dimension_val_level;
            break;
        case posit_cmd:
            cur_val = chr;
            cur_val_level = posit_val_level;
            break;
        case gluespec_cmd:
            cur_val = chr;
            cur_val_level = glue_val_level;
            break;
        case mugluespec_cmd:
            cur_val = chr;
            cur_val_level = muglue_val_level;
            break;
        case mathspec_cmd:
            tex_aux_set_cur_val_by_math_spec_cmd(chr);
            break;
        case fontspec_cmd:
            cur_val = tex_get_font_identifier(chr) ? chr : null;
            cur_val_level = fontspec_val_level;
            break;
        case association_cmd:
            switch (chr) {
                case unit_association_code:
                    cur_val = tex_get_unit_class(tex_scan_unit_register_number(0));
                    cur_val_level = integer_val_level;
                    break;
            }
            break;
        case begin_paragraph_cmd:
            switch (chr) {
                case snapshot_par_code:
                    {
                        halfword par = tex_find_par_par(cur_list.head);
                        cur_val = par ? par_state(par) : 0;
                        cur_val_level = integer_val_level;
                        break;
                    }
                /* case attribute_par_code: */
                case wrapup_par_code:
                    {
                        halfword par = tex_find_par_par(cur_list.head);
                        cur_val = par ? par_end_par_tokens(par) : null;
                        cur_val_level = token_val_level;
                        break;
                    }
                default:
                    goto DEFAULT;
            }
            break;
        /*
        case special_box_cmd:
            switch (chr) {
                case left_box_code:
                    cur_val = cur_mode == hmode ? local_left_box_par : null;
                    cur_val_level = list_val_level;
                    return cur_val;
                case right_box_code:
                    cur_val = cur_mode == hmode ? local_right_box_par : null;
                    cur_val_level = list_val_level;
                    return cur_val;
                default:
                   goto DEFAULT;
            }
            break;
        */
        /*tex
            This one is not in the [min_internal_cmd,max_internal_cmd] range!
        */
        case parameter_cmd:
            tex_get_x_token();
            if (valid_iterator_reference(cur_tok)) {
                cur_val = tex_expand_iterator(cur_tok);
                cur_val_level = integer_val_level;
                break;
            } else {
                goto DEFAULT;
            }
        case interaction_cmd:
            cur_val = cur_chr;
            cur_val_level = integer_val_level;
            break;
        case specificationspec_cmd:
            {
                quarterword code = node_subtype(chr);
                halfword count = tex_get_specification_count(chr);
                if (count) {
                    switch (code) {
                        case integer_list_code:
                        case dimension_list_code:
                        case posit_list_code:
                            {
                                /* todo: repeat */
                                halfword index = tex_scan_integer(0, NULL);
                                halfword value = 0;
                                if (index) {
                                    if (index < 0) {
                                        index = count + index + 1;
                                    }
                                    if (index >= 1 && index <= count) {
                                        if (specification_double(chr)) {
                                            switch (tex_scan_integer(0, NULL)) {
                                                case 1:
                                                    value = tex_get_specification_nepalty(chr, index);
                                                    if (specification_integer(chr)) {
                                                        code = integer_list_code;
                                                    }
                                                    break;
                                                case 2:
                                                    value = tex_get_specification_penalty(chr, index);
                                                    break;
                                            }
                                        } else {
                                            value = tex_get_specification_penalty(chr, 2);
                                        }
                                    }
                                    switch (code) {
                                        case integer_list_code:
                                            cur_val = value;
                                            cur_val_level = integer_val_level;
                                            break ;
                                        case dimension_list_code:
                                            cur_val = value;
                                            cur_val_level = dimension_val_level;
                                            break;
                                        case posit_list_code:
                                            cur_val = value;
                                            cur_val_level = posit_val_level;
                                            break;
                                    }
                                } else {
                                    cur_val = count;
                                    cur_val_level = integer_val_level;
                                }
                            }
                            break;
                        default:
                            cur_val = count;
                            cur_val_level = integer_val_level;
                            break;
                    }
                } else {
                    cur_val = count;
                    cur_val_level = integer_val_level;
                }
                break;
            }
        default:
          DEFAULT:
            /*tex Complain that |\the| can not do this; give zero result. */
            tex_handle_error(
                normal_error_type,
                "You can't use '%C' after \\the",
                cmd, chr,
                "I'm forgetting what you said and using zero instead."
            );
            cur_val = 0;
            cur_val_level = (level == token_val_level) ? integer_val_level : dimension_val_level;
            break;
    }
    tex_aux_downgrade_cur_val(level, succeeded, negative);
    return cur_val;
}

void tex_scan_something_simple(halfword cmd, halfword chr)
{
    if (cmd >= min_internal_cmd && cmd <= max_internal_cmd) {
        tex_aux_scan_something_internal(cmd, chr, no_val_level, 0, 0);
    } else {
     // tex_handle_error(
     //     normal_error_type,
     //     "You can't use '%C' as (Lua) tex library index",
     //     cmd, chr,
     //     "I'm forgetting what you said and using zero instead."
     // );
        cur_val = 0;
        cur_val_level = integer_val_level;
    }
}

/*tex

    It is nice to have routines that say what they do, so the original |scan_eight_bit_int| is
    superceded by |scan_register_number| and |scan_mark_number|. It may become split up even further
    in the future.

    Many of the |restricted classes| routines are the essentially the same except for the upper
    limit and the error message, so it makes sense to combine these all into one function.

*/

static inline halfword tex_aux_scan_limited_int(int optional_equal, int min, int max, const char *invalid)
{
    halfword v = tex_scan_integer(optional_equal, NULL);
    if (v < min || v > max) {
        tex_handle_error(
            normal_error_type,
            "%s (%i) should be in the range %i..%i",
            invalid, v, min, max,
            "I'm going to use 0 instead of that illegal code value."
        );
        return 0;
    } else {
        return v;
    }
}

halfword   tex_scan_integer_register_number   (void)               { return tex_aux_scan_limited_int(0, 0, max_integer_register_index, "Integer register index"); }
halfword   tex_scan_dimension_register_number (void)               { return tex_aux_scan_limited_int(0, 0, max_dimension_register_index, "Dimension register index"); }
halfword   tex_scan_attribute_register_number (void)               { return tex_aux_scan_limited_int(0, 0, max_attribute_register_index, "Attribute register index"); }
halfword   tex_scan_posit_register_number     (void)               { return tex_aux_scan_limited_int(0, 0, max_posit_register_index, "Posit register index"); }
halfword   tex_scan_glue_register_number      (void)               { return tex_aux_scan_limited_int(0, 0, max_glue_register_index, "Glue register index"); }
halfword   tex_scan_muglue_register_number    (void)               { return tex_aux_scan_limited_int(0, 0, max_muglue_register_index, "Muglue register index"); }
halfword   tex_scan_toks_register_number      (void)               { return tex_aux_scan_limited_int(0, 0, max_toks_register_index, "Toks register index"); }
halfword   tex_scan_box_register_number       (void)               { return tex_aux_scan_limited_int(0, 0, max_box_register_index, "Box register index"); }
halfword   tex_scan_unit_register_number      (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_unit_register_index, "Unit register index"); }
halfword   tex_scan_mark_number               (void)               { return tex_aux_scan_limited_int(0, 0, max_mark_index, "Marks index"); }
halfword   tex_scan_char_number               (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_character_code, "Character code"); }
halfword   tex_scan_math_char_number          (void)               { return tex_aux_scan_limited_int(0, 0, max_math_character_code, "Character code"); }
halfword   tex_scan_math_family_number        (void)               { return tex_aux_scan_limited_int(0, 0, max_math_family_index, "Math family"); }
halfword   tex_scan_math_properties_number    (void)               { return tex_aux_scan_limited_int(0, 0, max_math_property, "Math properties"); }
halfword   tex_scan_math_group_number         (void)               { return tex_aux_scan_limited_int(0, 0, max_math_group, "Math group"); }
halfword   tex_scan_math_index_number         (void)               { return tex_aux_scan_limited_int(0, 0, max_math_index, "Math index"); }
halfword   tex_scan_math_discretionary_number (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_math_discretionary, "Math discretionary"); }
singleword tex_scan_box_index                 (void)               { return (singleword) tex_aux_scan_limited_int(0, 0, max_box_index, "Box index"); }
singleword tex_scan_box_axis                  (void)               { return (singleword) tex_aux_scan_limited_int(0, 0, max_box_axis, "Box axis"); }
halfword   tex_scan_category_code             (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_category_code,"Category code"); }
halfword   tex_scan_space_factor              (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, min_space_factor, max_space_factor, "Space factor"); }
halfword   tex_scan_scale_factor              (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, min_scale_factor, max_scale_factor, "Scale factor"); }
halfword   tex_scan_function_reference        (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_function_reference, "Function reference"); }
halfword   tex_scan_bytecode_reference        (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_bytecode_index, "Bytecode reference"); }
halfword   tex_scan_limited_scale             (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, -max_limited_scale, max_limited_scale, "Limited scale"); }
halfword   tex_scan_positive_scale            (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, min_limited_scale, max_limited_scale, "Limited scale"); }
halfword   tex_scan_positive_number           (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_integer, "Positive number"); }
halfword   tex_scan_parameter_index           (void)               { return tex_aux_scan_limited_int(0, 0, 15, "Parameter index"); }
halfword   tex_scan_classification_code       (int optional_equal) { return tex_aux_scan_limited_int(optional_equal, 0, max_classification_code,"Classification code"); }

halfword   tex_scan_math_class_number(int optional_equal)
{
    halfword v = tex_aux_scan_limited_int(optional_equal, -1, max_math_class_code + 1, "Math class");
    if (v >= 0 && v <= max_math_class_code) {
        return v;
    } else {
        return unset_noad_class;
    }
}

/*tex

    An integer number can be preceded by any number of spaces and |+| or |-| signs. Then comes
    either a decimal constant (i.e., radix 10), an octal constant (i.e., radix 8, preceded by~|'|),
    a hexadecimal constant (radix 16, preceded by~|"|), an alphabetic constant (preceded by~|`|),
    or an internal variable. After scanning is complete, |cur_val| will contain the answer, which
    must be at most $2^{31}-1=2147483647$ in absolute value. The value of |radix| is set to 10, 8,
    or 16 in the cases of decimal, octal, or hexadecimal constants, otherwise |radix| is set to
    zero. An optional space follows a constant.

    The |scan_int| routine is used also to scan the integer part of a fraction; for example, the
    |3| in |3.14159| will be found by |scan_int|. The |scan_dimension| routine assumes that |cur_tok
    = point_token| after the integer part of such a fraction has been scanned by |scan_int|, and
    that the decimal point has been backed up to be scanned again.

*/

static void tex_aux_number_to_big_error(void)
{
    tex_handle_error(
        normal_error_type,
        "Number too big",
        "I can only go up to 2147483647 = '17777777777 = \"7FFFFFFF, so I'm using that\n"
        "number instead of yours."
    );
}

static void tex_aux_improper_constant_error(void)
{
    tex_handle_error(
        back_error_type,
        "Improper alphabetic constant",
        "A one-character control sequence belongs after a ` mark. So I'm essentially\n"
        "inserting \\0 here."
    );
}

/*tex

    The next function is somewhat special. It is also called in other scanners and therefore
    |cur_val| cannot simply be replaced. For that reason we do return the value but also set
    |cur_val|, just in case. I might sort this out some day when other stuff has been reworked.

    The routine has been optimnized a bit (equal scanning and such) and after a while I decided to
    split the three cases. It makes for a bit nicer code.

    If we backport the checking code to \LUATEX, a pre May 24 2020 copy has to be taken, because
    that is closer to the original.

*/


static void tex_aux_scan_integer_no_number(int where)
{
    /*tex Express astonishment that no number was here. */
    if (lmt_error_state.intercept) {
        lmt_error_state.last_intercept = 1 ;
        if (cur_cmd != spacer_cmd) {
            tex_back_input(cur_tok);
        }
    } else {
        tex_aux_missing_number_error(where);
    }
}

halfword tex_scan_integer(int optional_equal, int *radix)
{
    bool negative = false;
    long long result = 0;
    while (1) {
        tex_get_x_token();
        if (cur_cmd == spacer_cmd) {
            continue;
        } else if (cur_tok == equal_token) {
            if (optional_equal) {
                optional_equal = 0;
                continue;
            } else {
                break;
            }
        } else if (cur_tok == minus_token) {
            negative = ! negative;
        } else if (cur_tok != plus_token) {
            break;
        }
    };
    if (cur_tok == alpha_token) {
        /*tex
            Scan an alphabetic character code into |result|. A space is ignored after an alphabetic
            character constant, so that such constants behave like numeric ones. We don't expand the
            next token!
        */
        tex_get_token();
        if (cur_tok < cs_token_flag) {
            result = cur_chr;
            if (cur_cmd == right_brace_cmd) {
               ++lmt_input_state.align_state;
        //  } else if (cur_cmd < right_brace_cmd) {
            } else if (cur_cmd == left_brace_cmd || cur_cmd == relax_cmd) {
                /* left_brace_cmd or relax_cmd (really?)*/
               --lmt_input_state.align_state;
            }
        } else {
            /*tex
                The value of a csname in this context is its name. A single letter case happens more
                frequently than an active character but both seldom are ran into anyway.
            */
            strnumber txt = cs_text(cur_tok - cs_token_flag);
            if (tex_single_letter(txt)) {
                result = aux_str2uni(str_string(txt));
            } else if (tex_is_active_cs(txt)) {
                result = active_cs_value(txt);
            } else {
                result = max_character_code + 1;
            }
        }
        if (result > max_character_code) {
            if (lmt_error_state.intercept) {
                lmt_error_state.last_intercept = 1;
                tex_back_input(cur_tok);
            } else {
                tex_aux_improper_constant_error();
                return 0;
            }
        } else {
            /*tex Scan an optional space. */
            tex_get_x_token();
            if (cur_cmd != spacer_cmd) {
                tex_back_input(cur_tok);
            }
        }
    } else if ((cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) || cur_cmd == parameter_cmd) {
        result = tex_aux_scan_something_internal(cur_cmd, cur_chr, integer_val_level, 0, 0);
        if (cur_val_level != integer_val_level) {
            tex_aux_scan_integer_no_number(6);
            return 0;
        }
    } else {
        /*tex has an error message been issued? */
        bool vacuous = true;
        bool ok_so_far = true;
        /*tex
            Scan a numeric constant. The interwoven common loop has been split up now.
        */
        switch (cur_tok) {
            case octal_token:
                {
                    if (radix) {
                        *radix = 8;
                    }
                    while (1) {
                        unsigned d = 0;
                        tex_get_x_token();
                        if ((cur_tok >= zero_token) && (cur_tok <= seven_token)) {
                            d = cur_tok - zero_token;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        if (ok_so_far) {
                            result = result * 8 + d;
                            if (result > max_integer) {
                                result = max_integer;
                                if (lmt_error_state.intercept) {
                                    vacuous = true;
                                    goto DONE;
                                } else {
                                    tex_aux_number_to_big_error();
                                }
                                ok_so_far = 0;
                            }
                        }
                    }
                 // break;
                }
            case hex_token:
                {
                    if (radix) {
                        *radix = 16;
                    }
                    while (1) {
                        unsigned d = 0;
                        tex_get_x_token();
                        if ((cur_tok >= zero_token) && (cur_tok <= nine_token)) {
                            d = cur_tok - zero_token;
                        } else if ((cur_tok >= A_token_l) && (cur_tok <= F_token_l)) {
                            d = cur_tok - A_token_l + 10;
                        } else if ((cur_tok >= A_token_o) && (cur_tok <= F_token_o)) {
                            d = cur_tok - A_token_o + 10;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        if (ok_so_far) {
                            result = result * 16 + d;
                            if (result > max_integer) {
                                result = max_integer;
                                if (lmt_error_state.intercept) {
                                    vacuous = true;
                                    goto DONE;
                                } else {
                                    tex_aux_number_to_big_error();
                                }
                                ok_so_far = false;
                            }
                        }
                    }
                 // break;
                }
            default:
                if (radix) {
                    *radix = 10;
                }
                while (1) {
                    unsigned d = 0;
                    if ((cur_tok >= zero_token) && (cur_tok <= nine_token)) {
                        d = cur_tok - zero_token;
                    } else {
                        goto DONE;
                    }
                    vacuous = false;
                    if (ok_so_far) {
                        result = result * 10 + d;
                        if (result > max_integer) {
                            result = max_integer;
                            if (lmt_error_state.intercept) {
                                vacuous = true;
                                goto DONE;
                            } else {
                                tex_aux_number_to_big_error();
                            }
                            ok_so_far = false;
                        }
                    }
                    tex_get_x_token();
                }
                // break;
        }
      DONE:
        if (vacuous) {
            tex_aux_scan_integer_no_number(7);
        } else {
            tex_push_back(cur_tok, cur_cmd, cur_chr);
        }
    }
    /*tex For now we still keep |cur_val| set too. */
    cur_val = (halfword) (negative ? - result : result);
    return cur_val;
}

void tex_scan_integer_validate(void)
{
    while (1) {
        tex_get_x_token();
        if (cur_cmd == spacer_cmd || cur_tok == minus_token) {
            continue;
        } else if (cur_tok != plus_token) {
            break;
        }
    };
    if (cur_tok == alpha_token) {
        long long result = 0;
        tex_get_token();
        if (cur_tok < cs_token_flag) {
            result = cur_chr;
            /* Really when validating? */
            if (cur_cmd == right_brace_cmd) {
               ++lmt_input_state.align_state;
            } else if (cur_cmd == left_brace_cmd || cur_cmd == relax_cmd) {
               --lmt_input_state.align_state;
            }
        } else {
            strnumber txt = cs_text(cur_tok - cs_token_flag);
            if (tex_single_letter(txt)) {
                result = aux_str2uni(str_string(txt));
            } else if (tex_is_active_cs(txt)) {
                result = active_cs_value(txt);
            } else {
                result = max_character_code + 1;
            }
        }
        if (result > max_character_code) {
            if (lmt_error_state.intercept) {
                lmt_error_state.last_intercept = 1;
                tex_back_input(cur_tok);
            } else {
                tex_aux_improper_constant_error();
            }
        } else {
            tex_get_x_token();
            if (cur_cmd != spacer_cmd) {
                tex_back_input(cur_tok);
            }
        }
    } else if ((cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) || cur_cmd == parameter_cmd) {
        tex_aux_scan_something_internal(cur_cmd, cur_chr, integer_val_level, 0, 0);
        if (cur_val_level != integer_val_level) {
            tex_aux_scan_integer_no_number(8);
        }
    } else {
        bool vacuous = true;
        switch (cur_tok) {
            case octal_token:
                while (1) {
                    tex_get_x_token();
                    if (! (cur_tok >= zero_token && cur_tok <= seven_token)) {
                        goto DONE;
                    }
                    vacuous = false;
                }
            case hex_token:
                while (1) {
                    tex_get_x_token();
                    if (! ((cur_tok >= zero_token && cur_tok <= nine_token) ||
                            (cur_tok >= A_token_l  && cur_tok <= F_token_l ) ||
                            (cur_tok >= A_token_o  && cur_tok <= F_token_o ) )) {
                        goto DONE;
                    }
                    vacuous = false;
                }
            default:
                while (1) {
                    if (! (cur_tok >= zero_token && cur_tok <= nine_token)) {
                        goto DONE;
                    }
                    vacuous = false;
                    tex_get_x_token();
                }
        }
      DONE:
        if (vacuous) {
            tex_aux_scan_integer_no_number(9);
        } else {
            tex_push_back(cur_tok, cur_cmd, cur_chr);
        }
    }
}

int tex_scan_cardinal(int optional_equal, unsigned *value, int dontbark)
{
    long long result = 0;
 // do {
 //     tex_get_x_token();
 // } while (cur_cmd == spacer_cmd);
    while (1) {
        tex_get_x_token();
        if (cur_cmd != spacer_cmd) {
            if (optional_equal && (cur_tok == equal_token)) {
                optional_equal = 0;
            } else {
                break;
            }
        }
    }
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        result = tex_aux_scan_something_internal(cur_cmd, cur_chr, integer_val_level, 0, 0);
    } else {
        bool vacuous = true;
        switch (cur_tok) {
            case octal_token:
                {
                    while (1) {
                        unsigned d = 0;
                        tex_get_x_token();
                        if ((cur_tok >= zero_token) && (cur_tok <= seven_token)) {
                            d = cur_tok - zero_token;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        result = result * 8 + d;
                        if (result > max_cardinal) {
                            result = max_cardinal;
                        }
                    }
                 // break;
                }
            case hex_token:
                {
                    while (1) {
                        unsigned d = 0;
                        tex_get_x_token();
                        if ((cur_tok >= zero_token) && (cur_tok <= nine_token)) {
                            d = cur_tok - zero_token;
                        } else if ((cur_tok >= A_token_l) && (cur_tok <= F_token_l)) {
                            d = cur_tok - A_token_l + 10;
                        } else if ((cur_tok >= A_token_o) && (cur_tok <= F_token_o)) {
                            d = cur_tok - A_token_o + 10;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        result = result * 16 + d;
                        if (result > max_cardinal) {
                            result = max_cardinal;
                        }
                    }
                 // break;
                }
            default:
                {
                    while (1) {
                        unsigned d = 0;
                        if ((cur_tok >= zero_token) && (cur_tok <= nine_token)) {
                            d = cur_tok - zero_token;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        result = result * 10 + d;
                        if (result > max_cardinal) {
                            result = max_cardinal;
                        }
                        tex_get_x_token();
                    }
                 // break;
                }
        }
      DONE:
        if (vacuous) {
            if (dontbark) {
                return 0;
            } else {
                tex_aux_missing_number_error(1);
            }
        } else {
            tex_push_back(cur_tok, cur_cmd, cur_chr);
        }
    }
    *value = (unsigned) result;
    cur_val = (halfword) result;
    return 1;
}

/*tex

    The following code is executed when |scan_something_internal| was called asking for |mu_val|,
    when we really wanted a mudimen instead of muglue.

*/

static halfword tex_aux_coerced_glue(halfword value, halfword level)
{
    if (level == glue_val_level || level == muglue_val_level) {
        int v = glue_amount(value);
        tex_flush_node(value);
        return v;
    } else {
        return value;
    }
}

/*tex

    The |scan_dimension| routine is similar to |scan_int|, but it sets |cur_val| to a |scaled| value,
    i.e., an integral number of sp. One of its main tasks is therefore to interpret the
    abbreviations for various kinds of units and to convert measurements to scaled points.

    There are three parameters: |mu| is |true| if the finite units must be |mu|, while |mu| is
    |false| if |mu| units are disallowed; |inf| is |true| if the infinite units |fil|, |fill|,
    |filll| are permitted; and |shortcut| is |true| if |cur_val| already contains an integer and
    only the units need to be considered.

    The order of infinity that was found in the case of infinite glue is returned in the global
    variable |cur_order|.

    Constructions like |-'77 pt| are legal dimensions, so |scan_dimension| may begin with |scan_int|.
    This explains why it is convenient to use |scan_integer| also for the integer part of a decimal
    fraction.

    Several branches of |scan_dimension| work with |cur_val| as an integer and with an auxiliary
    fraction |f|, so that the actual quantity of interest is $|cur_val|+|f|/2^{16}$. At the end of
    the routine, this \quote {unpacked} representation is put into the single word |cur_val|, which
    suddenly switches significance from |integer| to |scaled|.

    The necessary conversion factors can all be specified exactly as fractions whose numerator and
    denominator add to 32768 or less. According to the definitions here, $\rm 2660 \, dd \approx
    1000.33297 \, mm$; this agrees well with the value $\rm 1000.333 \, mm$ cited by Hans Rudolf
    Bosshard in {\em Technische Grundlagen zur Satzherstellung} (Bern, 1980). The Didot point has
    been newly standardized in 1978; it's now exactly $\rm 1 \, nd = 0.375 \, mm$. Conversion uses
    the equation $0.375 = 21681 / 20320 / 72.27 \cdot 25.4$. The new Cicero follows the new Didot
    point; $\rm 1 \, nc = 12 \, nd$. These would lead to the ratios $21681 / 20320$ and $65043
    / 5080$, respectively. The closest approximations supported by the algorithm would be $11183 /
    10481$ and $1370 / 107$. In order to maintain the relation $\rm 1 \, nc = 12 \, nd$, we pick
    the ratio $685 / 642$ for $\rm nd$, however.

*/

static void tex_aux_scan_dimension_mu_error(void) {
    tex_handle_error(
        normal_error_type,
        "Illegal unit of measure (mu inserted)",
        "The unit of measurement in math glue must be mu." );

}

static void tex_aux_scan_dimension_fi_error(void) {
    tex_handle_error(
        normal_error_type,
        "Illegal unit of measure",
        "The unit of measurement can't be fi, fil, fill or filll here." );

}

static void tex_aux_scan_dimension_unknown_unit_error(void) {
    tex_handle_error(
        normal_error_type,
        "Illegal unit of measure (pt inserted)",
        "Dimensions can be in units of em, ex, sp, cm, mm, es, ts, pt, bp, dk, pc, dd\n"
        "cc or in; but yours is a new one! I'll assume that you meant to say pt, for\n"
        "printer's points: two letters."
    );
}

/*tex
    The Edith and Tove were introduced at BachoTeX 2023 and because the error message
    was still in feet we decided to adapt it accordingly so now in addition it reports
    different values, including Theodores little feet measured by Arthur as being roughly
    five Ediths.
*/

static void tex_aux_scan_dimension_out_of_range_error(void) {
    tex_handle_error(
        normal_error_type,
        "Dimension too large",
        "I can't work with sizes bigger than about 19 feet (45 Theodores as of 2023),\n"
        "575 centimeters, 2300 Toves, 230 Ediths or 16383 points. Continue and I'll use\n"
        "the largest value I can."
    );
}

# define set_conversion(A,B) do { num=(A); denom=(B); } while(0)

/*tex

    This function sets |cur_val| to a dimension. We still have some |cur_val| sync issue so no
    result replacement yet. (The older variant, also already optimzied can be found in the
    history).

    When order is |NULL| mu units and glue fills are not scanned.

*/

typedef enum scanned_unit {
    no_unit_scanned,         /* 0 : error */
    normal_unit_scanned,     /* 1 : cm mm pt bp dd cc in dk */
    scaled_point_scanned,    /* 2 : sp */
    relative_unit_scanned,   /* 3 : ex em px */
    math_unit_scanned,       /* 4 : mu */
    flexible_unit_scanned,   /* 5 : fi fil fill filll */
    quantitity_unit_scanned, /* 6 : internal quantity */
} scanned_unit;

/*tex

    We support the Knuthian Potrzebie cf.\ \url {https://en.wikipedia.org/wiki/Potrzebie} as the
    |dk| unit. It was added on 2021-09-22 exactly when we crossed the season during an evening
    session at the 15th \CONTEXT\ meeting in Bassenge (Boirs) Belgium. It took a few iterations to
    find the best numerator and denominator, but Taco Hoekwater, Harald Koenig and Mikael Sundqvist
    figured it out in this interactive session. The error messages have been adapted accordingly and
    the scanner in the |tex| library also handles it. One |dk| is 6.43985pt. There is no need to
    make \METAPOST\ aware of this unit because there it is just a numeric multiplier in a macro
    package.

    From Wikipedia:

    In issue 33, Mad published a partial table of the \quotation {Potrzebie System of Weights and
    Measures}, developed by 19-year-old Donald~E. Knuth, later a famed computer scientist. According
    to Knuth, the basis of this new revolutionary system is the potrzebie, which equals the thickness
    of Mad issue 26, or 2.2633484517438173216473 mm [...].

    We also provide alternatives for the inch: the |es| and |ts|, two units dedicated to women
    (Edith and Tove) that come close to the inch but are more metric. Their values have been
    carefully callibrated at the 2023 BachoTeX meeting and a report will be published in the
    proceedings as well as TUGboat (medio 2023).

    An additional |eu| has been introduced as a multiplier for |ts| that defaults to 10 which makes
    one |eu| default to one |es|.

    The |true| addition has now officially been dropped.

*/

/*tex
    We keep this as reference:
*/

// static int tex_aux_scan_unit(halfword *num, halfword *denom, halfword *value, halfword *order)
// {
// //AGAIN: /* only for true */
//     do {
//         tex_get_x_token();
//     } while (cur_cmd == spacer_cmd);
//     if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
//         return quantitity_unit_scanned;
//     } else {
//         int chrone, chrtwo;
//         halfword tokone, toktwo;
//         halfword save_cur_cs = cur_cs;
//         tokone = cur_tok;
//         if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
//             chrone = cur_chr;
//         } else {
//             goto BACK_ONE;
//         }
//         tex_get_x_token();
//         toktwo = cur_tok;
//         if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
//             chrtwo = cur_chr;
//         } else {
//             goto BACK_TWO;
//         }
//         cur_cs = save_cur_cs;
//         switch (chrone) {
//             case 'p': case 'P':
//                 switch (chrtwo) {
//                     case 't': case 'T':
//                         return normal_unit_scanned;
//                     case 'c': case 'C':
//                         *num = 12;
//                         *denom = 1;
//                         return normal_unit_scanned;
//                     case 'x': case 'X':
//                         *value = px_dimension_par;
//                         return relative_unit_scanned;
//                 }
//                 break;
//             case 'm': case 'M':
//                 switch (chrtwo) {
//                     case 'm': case 'M':
//                         *num = 7227;
//                         *denom = 2540;
//                         return normal_unit_scanned;
//                     case 'u': case 'U':
//                         if (order) {
//                             return math_unit_scanned;
//                         } else {
//                             break;
//                         }
//                 }
//                 break;
//             case 'c': case 'C':
//                 switch (chrtwo) {
//                     case 'm': case 'M':
//                         *num = 7227;
//                         *denom = 254;
//                         return normal_unit_scanned;
//                     case 'c': case 'C':
//                         *num = 14856;
//                         *denom = 1157;
//                         return normal_unit_scanned;
//                 }
//                 break;
//             case 's': case 'S':
//                 switch (chrtwo) {
//                     case 'p': case 'P':
//                         return scaled_point_scanned;
//                 }
//                 break;
//             case 'b': case 'B':
//                 switch (chrtwo) {
//                     case 'p': case 'P':
//                         *num = 7227;
//                         *denom = 7200;
//                         return normal_unit_scanned;
//                 }
//                 break;
//             case 'i': case 'I':
//                 switch (chrtwo) {
//                     case 'n': case 'N':
//                         *num = 7227;
//                         *denom = 100;
//                         return normal_unit_scanned;
//                 }
//                 break;
//             case 'd': case 'D':
//                 switch (chrtwo) {
//                     case 'd': case 'D':
//                         *num = 1238;
//                         *denom = 1157;
//                         return normal_unit_scanned;
//                     case 'k': case 'K': /* number: 422042 */
//                         *num = 49838;  // 152940;
//                         *denom = 7739; //  23749;
//                         return normal_unit_scanned;
//                 }
//                 break;
//             case 't': case 'T':
//                 switch (chrtwo) {
//                     case 's': case 'S':
//                         *num = 4588;
//                         *denom = 645;
//                         return normal_unit_scanned;
//                 }
//              // if (order) {
//              //     switch (chrtwo) {
//              //         case 'r': case 'R':
//              //             if (tex_scan_mandate_keyword("true", 2)) {
//              //                 /*tex This is now a bogus prefix that might get dropped! */
//              //                 goto AGAIN;
//              //             }
//              //     }
//              // }
//                 break;
//             case 'e': case 'E':
//                 switch (chrtwo) {
//                     case 'm': case 'M':
//                         *value = tex_get_scaled_em_width(cur_font_par);
//                         return relative_unit_scanned;
//                     case 'x': case 'X':
//                         *value = tex_get_scaled_ex_height(cur_font_par);
//                         return relative_unit_scanned;
//                     case 's': case 'S':
//                         *num = 9176;
//                         *denom = 129;
//                         return normal_unit_scanned;
//                     case 'u': case 'U':
//                         *num = 9176 * eu_factor_par;
//                         *denom = 129 * 10;
//                         return normal_unit_scanned;
//                 }
//                 break;
//             case 'f': case 'F':
//                 if (order) {
//                     switch (chrtwo) {
//                         case 'i': case 'I':
//                             *order = fi_glue_order;
//                             if (tex_scan_character("lL", 0, 0, 0)) {
//                                 *order = fil_glue_order;
//                                 if (tex_scan_character("lL", 0, 0, 0)) {
//                                     *order = fill_glue_order;
//                                     if (tex_scan_character("lL", 0, 0, 0)) {
//                                         *order = filll_glue_order;
//                                     }
//                                 }
//                             }
//                             return flexible_unit_scanned;
//                     }
//                 }
//                 break;
//         }
//         /* only lowercase for now */
//         {
//             int index = unit_parameter_index(chrone, chrtwo);
//             if (index >= 0) {
//                 halfword cs = unit_parameter(index);
//                 if (cs > 0) {
//                     halfword cmd = eq_type(cs);
//                     halfword chr = eq_value(cs);
//                     switch (cmd) {
//                         case internal_dimension_cmd:
//                         case register_dimension_cmd:
//                             *value = eq_value(chr);
//                             return relative_unit_scanned;
//                         case dimension_cmd:
//                             *value = chr;
//                             return relative_unit_scanned;
//                     }
//                 }
//             }
//         }
//       BACK_TWO:
//         tex_back_input(toktwo);
//       BACK_ONE:
//         tex_back_input(tokone);
//         cur_cs = save_cur_cs;
//         return no_unit_scanned;
//     }
// }

/*tex
    The hash variant makes the binary some 500 bytes larger but it just looks a bit nicer and we
    might need to calculate index anyway. Let the compiler sort it out.
*/

/*tex
    User units are bound to dimensions and some more. It could have been a callback but that is
    kind of ugly at the scanner level and also bit unnatural. It would perform a bit less but this
    is not critical so that's not an excuse. Somehow I like it this way. We would have to pass the
    hash and handle it at the \LUA\ end.
*/

# define unit_hashes(a,b,c,d) \
         unit_parameter_hash(a,c): \
    case unit_parameter_hash(b,d): \
    case unit_parameter_hash(a,d): \
    case unit_parameter_hash(b,c)

int tex_valid_userunit(halfword cmd, halfword chr, halfword cs)
{
    (void) cs;
    switch (cmd) {
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case constant_call_cmd:
            return chr && ! get_token_preamble(chr);
        case internal_dimension_cmd:
        case register_dimension_cmd:
        case dimension_cmd:
        case lua_value_cmd:
            return 1;
        default:
            return 0;
    }
}

int tex_get_unit_class(halfword index)
{
    halfword class = unit_parameter(index);
    return class < 0 ? - class : class ? user_unit_class : unset_unit_class;
}

int tex_get_userunit(halfword index, scaled *value)
{
    halfword cs = unit_parameter(index);
    if (cs > 0) {
        halfword cmd = eq_type(cs);
        halfword chr = eq_value(cs);
        switch (cmd) {
            case internal_dimension_cmd:
            case register_dimension_cmd:
                *value = eq_value(chr);
                return relative_unit_scanned;
            case dimension_cmd:
                *value = chr;
                return relative_unit_scanned;
            case call_cmd:
            case protected_call_cmd:
            case semi_protected_call_cmd:
            case constant_call_cmd:
                if (chr && ! get_token_preamble(chr)) {
                    halfword list = token_link(chr);
                    tex_begin_associated_list(list);
                    tex_aux_scan_expr(dimension_val_level);
                    if (cur_val_level == dimension_val_level) {
                        *value = cur_val;
                        return 1;
                    }
                }
                /*tex So we can actually have an empty macro. */
                *value = 0;
                return 1;
            case lua_value_cmd:
                /* We pass the index but more for tracing than for usage. */
                tex_aux_set_cur_val_by_lua_value_cmd(chr, index);
                if (cur_val_level == dimension_val_level) {
                    *value = cur_val;
                    return 1;
             }
        }
    }
    /*tex We could go zero but better not. */
    *value = 0;
    return 0;
}

void tex_initialize_units(void)
{
    unit_parameter(unit_parameter_hash('p','t')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('c','m')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('m','m')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('e','m')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('e','x')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('s','p')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('b','p')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('f','i')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('t','s')) = - luametatex_unit_class;
    unit_parameter(unit_parameter_hash('e','s')) = - luametatex_unit_class;
    unit_parameter(unit_parameter_hash('e','u')) = - luametatex_unit_class;
    unit_parameter(unit_parameter_hash('d','k')) = - luametatex_unit_class;
    unit_parameter(unit_parameter_hash('m','u')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('d','d')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('c','c')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('p','c')) = - tex_unit_class;
    unit_parameter(unit_parameter_hash('p','x')) = - pdftex_unit_class;
    unit_parameter(unit_parameter_hash('i','n')) = - tex_unit_class;
}

static int tex_aux_scan_unit(halfword *num, halfword *denom, halfword *value, halfword *order)
{
//AGAIN: /* only for true */
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        return quantitity_unit_scanned;
    } else {
        int chrone, chrtwo, index;
        halfword tokone, toktwo;
        halfword save_cur_cs = cur_cs;
        tokone = cur_tok;
        if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
            chrone = cur_chr;
        } else {
            goto BACK_ONE;
        }
        tex_get_x_token();
        toktwo = cur_tok;
        if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
            chrtwo = cur_chr;
        } else {
            goto BACK_TWO;
        }
        cur_cs = save_cur_cs;
        index = unit_parameter_index(chrone, chrtwo);
        if (index >= 0) {
            switch (index) {
                case unit_hashes('p','P','t','T'):
                    return normal_unit_scanned;
                case unit_hashes('c','C','m','M'):
                    *num = 7227;
                    *denom = 254;
                    return normal_unit_scanned;
                case unit_hashes('m','M','m','M'):
                    *num = 7227;
                    *denom = 2540;
                    return normal_unit_scanned;
                case unit_hashes('e','E','m','M'):
                    *value = tex_get_scaled_em_width(cur_font_par);
                    return relative_unit_scanned;
                case unit_hashes('e','E','x','X'):
                    *value = tex_get_scaled_ex_height(cur_font_par);
                    return relative_unit_scanned;
                case unit_hashes('s','S','p','P'):
                    return scaled_point_scanned;
                case unit_hashes('b','B','p','P'):
                    *num = 7227;
                    *denom = 7200;
                    return normal_unit_scanned;
                case unit_hashes('f','F','i','I'):
                    if (order) {
                        *order = fi_glue_order;
                        if (tex_scan_character("lL", 0, 0, 0)) {
                            *order = fil_glue_order;
                            if (tex_scan_character("lL", 0, 0, 0)) {
                                *order = fill_glue_order;
                                if (tex_scan_character("lL", 0, 0, 0)) {
                                    *order = filll_glue_order;
                                }
                            }
                        }
                        return flexible_unit_scanned;
                    }
                    break;
                case unit_hashes('t','T','s','S'):
                    *num = 4588;
                    *denom = 645;
                    return normal_unit_scanned;
                case unit_hashes('e','E','s','S'):
                    *num = 9176;
                    *denom = 129;
                    return normal_unit_scanned;
                case unit_hashes('e','E','u','U'):
                    *num = 9176 * eu_factor_par;
                    *denom = 129 * 10;
                    return normal_unit_scanned;
                case unit_hashes('d','D','k','K'): /* number: 422042 */
                    *num = 49838;  // 152940;
                    *denom = 7739; //  23749;
                    return normal_unit_scanned;
                case unit_hashes('m','M','u','U'):
                    if (order) {
                        return math_unit_scanned;
                    } else {
                        break;
                    }
                case unit_hashes('d','D','d','D'):
                    *num = 1238;
                    *denom = 1157;
                    return normal_unit_scanned;
                case unit_hashes('c','C','c','C'):
                    *num = 14856;
                    *denom = 1157;
                    return normal_unit_scanned;
                case unit_hashes('p','P','c','C'):
                    *num = 12;
                    *denom = 1;
                    return normal_unit_scanned;
                case unit_hashes('p','P','x','X'):
                    *value = px_dimension_par;
                    return relative_unit_scanned;
                case unit_hashes('i','I','n','N'):
                    *num = 7227;
                    *denom = 100;
                    return normal_unit_scanned;
             // case unit_hashes('t','T','r','R'):
             //     if (order) {
             //        if (tex_scan_mandate_keyword("true", 2)) {
             //            /*tex This is now a bogus prefix that might get dropped! */
             //            goto AGAIN;
             //        }
             //     }
             //     break;
                default:
                    if (tex_get_userunit(index, value)) {
                        return relative_unit_scanned;
                    }
            }
        }
      BACK_TWO:
        tex_back_input(toktwo);
      BACK_ONE:
        tex_back_input(tokone);
        cur_cs = save_cur_cs;
        return no_unit_scanned;
    }
}

/*tex
    When we drop |true| support we can use the next variant which is a bit more efficient and also
    handles optional units. Later we will see a more limited variant that also includes the scaler.
    This version can still be found in the archive.

    The fact that we can say |.3\somedimen| is made easy because when we fail to see a unit we can
    check if the seen token is some quantity.
*/

halfword tex_scan_dimension(int mu, int inf, int shortcut, int optional_equal, halfword *order)
{
    bool negative = false;
    int fraction = 0;
    int num = 0;
    int denom = 0;
    scaled v;
    int save_cur_val;
    halfword cur_order = normal_glue_order;
    lmt_scanner_state.arithmic_error = 0;
    if (! shortcut) {
        while (1) {
            tex_get_x_token();
            if (cur_cmd == spacer_cmd) {
                continue;
            } else if (cur_tok == equal_token) {
                if (optional_equal) {
                    optional_equal = 0;
                    continue;
                } else {
                    break;
                }
            } else if (cur_tok == minus_token) {
                negative = ! negative;
            } else if (cur_tok != plus_token) {
                break;
            }
        }
        if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
            cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, mu ? muglue_val_level : dimension_val_level, 0, 0); /* adapts cur_val_level */
            if (mu) {
                cur_val = tex_aux_coerced_glue(cur_val, cur_val_level);
                if (cur_val_level == muglue_val_level) {
                    goto ATTACH_SIGN;
                } else if (cur_val_level != integer_val_level) {
                    tex_aux_mu_error(2);
                }
            } else if (cur_val_level == dimension_val_level) {
                goto ATTACH_SIGN;
            } else if (cur_val_level == posit_val_level) {
                cur_val = tex_posit_to_dimension(cur_val);
                goto ATTACH_SIGN;
            }
        } else {
            int has_fraction = tex_token_is_seperator(cur_tok);
            if (has_fraction) {
                cur_val = 0;
            } else {
                int cur_radix;
                tex_back_input(cur_tok);
                cur_val = tex_scan_integer(0, &cur_radix);
                if (cur_radix == 10 && tex_token_is_seperator(cur_tok)) {
                    has_fraction = 1;
                    tex_get_token();
                }
            }
            if (has_fraction) {
                unsigned k = 0;
                unsigned char digits[18];
                while (1) {
                    tex_get_x_token();
                    if ((cur_tok > nine_token) || (cur_tok < zero_token)) {
                        break;
                    } else if (k < 17) {
                        digits[k] = (unsigned char) (cur_tok - zero_token);
                        ++k;
                    }
                }
                fraction = tex_round_decimals_digits(digits, k);
                if (cur_cmd != spacer_cmd) {
                    tex_back_input(cur_tok);
                }
            }
        }
    } else {
        /* only when we scan for a glue (filler) component */
    }
    if (cur_val < 0) {
        negative = ! negative;
        cur_val = -cur_val;
    }
    save_cur_val = cur_val;
    /*tex
        Actually we have cur_tok but it's already pushed back and we also need to skip spaces so
        let's not overdo this.
    */
    if (! lmt_error_state.last_intercept) {
        switch (tex_aux_scan_unit(&num, &denom, &v, &cur_order)) {
            case no_unit_scanned:
                /* error */
                if (lmt_error_state.intercept) {
                    lmt_error_state.last_intercept = 1;
                } else {
                    tex_aux_scan_dimension_unknown_unit_error();
                }
                goto ATTACH_FRACTION;
            case normal_unit_scanned:
                /* cm mm pt bp dd cc in dk */
                if (mu) {
                    tex_aux_scan_dimension_unknown_unit_error();
                } else if (num) {
                    int remainder = 0;
                    cur_val = tex_xn_over_d_r(cur_val, num, denom, &remainder);
                    fraction = (num * fraction + unity * remainder) / denom;
                    cur_val += fraction / unity;
                    fraction = fraction % unity;
                }
                goto ATTACH_FRACTION;
            case scaled_point_scanned:
                /* sp */
                if (mu) {
                    tex_aux_scan_dimension_unknown_unit_error();
                }
                goto DONE;
            case relative_unit_scanned:
                /* ex em px */
                if (mu) {
                    tex_aux_scan_dimension_unknown_unit_error();
                }
                cur_val = tex_nx_plus_y(save_cur_val, v, tex_xn_over_d(v, fraction, unity));
                goto DONE;
            case math_unit_scanned:
                /* mu (slightly different but an error anyway */
                if (! mu) {
                    tex_aux_scan_dimension_mu_error();
                }
                goto ATTACH_FRACTION;
            case flexible_unit_scanned:
                /* fi fil fill filll */
                if (mu) {
                    tex_aux_scan_dimension_unknown_unit_error();
                } else if (! inf) {
                    if (! order && lmt_error_state.intercept) {
                        lmt_error_state.last_intercept = 1;
                    } else {
                        tex_aux_scan_dimension_fi_error();
                    }
                }
                goto ATTACH_FRACTION;
            case quantitity_unit_scanned:
                /* internal quantity */
                cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, mu ? muglue_val_level : dimension_val_level, 0, 0); /* adapts cur_val_level */
                if (mu) {
                    cur_val = tex_aux_coerced_glue(cur_val, cur_val_level);
                    if (cur_val_level != muglue_val_level) {
                        tex_aux_mu_error(3);
                    }
                }
                v = cur_val;
                cur_val = tex_nx_plus_y(save_cur_val, v, tex_xn_over_d(v, fraction, unity));
                goto ATTACH_SIGN;
        }
    }
  ATTACH_FRACTION:
    if (cur_val >= 040000) { // 0x4000
        lmt_scanner_state.arithmic_error = 1;
    } else {
        cur_val = cur_val * unity + fraction;
    }
  DONE:
    tex_get_x_token();
    tex_push_back(cur_tok, cur_cmd, cur_chr);
  ATTACH_SIGN:
    if (lmt_scanner_state.arithmic_error || (abs(cur_val) >= 010000000000)) { // 0x40000000
        if (lmt_error_state.intercept) {
            lmt_error_state.last_intercept = 1;
        } else {
            tex_aux_scan_dimension_out_of_range_error();
        }
        cur_val = max_dimension;
        lmt_scanner_state.arithmic_error = 0;
    }
    if (negative) {
        cur_val = -cur_val;
    }
    if (order) {
        *order = cur_order;
    }
    return cur_val;
}


void tex_scan_dimension_validate(void)
{
    lmt_scanner_state.arithmic_error = 0;
    while (1) {
        tex_get_x_token();
        if (cur_cmd == spacer_cmd || cur_tok == minus_token) {
            continue;
        } else if (cur_tok != plus_token) {
            break;
        }
    }
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        tex_aux_scan_something_internal(cur_cmd, cur_chr, dimension_val_level, 0, 0);
        if (cur_val_level == dimension_val_level || cur_val_level == posit_val_level) {
            return;
        }
    } else {
        int has_fraction = tex_token_is_seperator(cur_tok);
        if (! has_fraction) {
            int cur_radix;
            tex_back_input(cur_tok);
            tex_scan_integer(0, &cur_radix);
            if (cur_radix == 10 && tex_token_is_seperator(cur_tok)) {
                has_fraction = 1;
                tex_get_token();
            }
        }
        if (has_fraction) {
            while (1) {
                tex_get_x_token();
                if (cur_tok > nine_token || cur_tok < zero_token) {
                    break;
                }
            }
            if (cur_cmd != spacer_cmd) {
                tex_back_input(cur_tok);
            }
        }
    }
    {
        int num = 0;
        int denom = 0;
        scaled value;
        switch (tex_aux_scan_unit(&num, &denom, &value, NULL)) {
            case no_unit_scanned:
            case flexible_unit_scanned:
                lmt_error_state.last_intercept = 1;
                break;
            case normal_unit_scanned:
            case scaled_point_scanned:
            case relative_unit_scanned:
            case math_unit_scanned:
                break;
            case quantitity_unit_scanned:
                tex_aux_scan_something_internal(cur_cmd, cur_chr, dimension_val_level, 0, 0);
                return;
        }
    }
    tex_get_x_token();
    tex_push_back(cur_tok, cur_cmd, cur_chr);
}

/*tex

    The final member of \TEX's value-scanning trio is |scan_glue|, which makes |cur_val| point to
    a glue specification. The reference count of that glue spec will take account of the fact that
    |cur_val| is pointing to~it. The |level| parameter should be either |glue_val| or |mu_val|.

    Since |scan_dimension| was so much more complex than |scan_integer|, we might expect |scan_glue|
    to be even worse. But fortunately, it is very simple, since most of the work has already been
    done.

*/

/* todo: get rid of cur_val */

halfword tex_scan_glue(int level, int optional_equal, int options_too)
{
    /*tex should the answer be negated? */
    bool negative = false;
    /*tex new glue specification */
    halfword q = null;
    /*tex does |level=mu_val|? */
    int mu = level == muglue_val_level;
    /*tex Get the next non-blank non-sign. */
    do {
        /*tex Get the next non-blank non-call token. */
        while (1) {
            tex_get_x_token();
            if (cur_cmd != spacer_cmd) {
                if (optional_equal && (cur_tok == equal_token)) {
                    optional_equal = 0;
                } else {
                    break;
                }
            }
        }
        if (cur_tok == minus_token) {
            negative = ! negative;
            cur_tok = plus_token;
        }
    } while (cur_tok == plus_token);
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, level, negative, 0);
        if (cur_val_level >= glue_val_level) {
            if (cur_val_level != level) {
                tex_aux_mu_error(4);
            }
            return cur_val;
        }
        if (cur_val_level == integer_val_level) {
            cur_val = tex_scan_dimension(mu, 0, 1, 0, NULL);
     /*
        This only works for |\mutoglue\emwidth| and not a fraction, so let's not do this now. At
        some point we could consider making |\mutoglue| and |\gluetomu| more tolerant but they
        are hardly used anyway.
     */
     /* } else if (cur_val_level == dimension_val_level) { */
     /*    mu = 0;                                         */
        } else if (level == muglue_val_level) {
            tex_aux_mu_error(5);
        }
    } else {
        tex_back_input(cur_tok);
        cur_val = tex_scan_dimension(mu, 0, 0, 0, NULL);
        if (negative) {
            cur_val = -cur_val;
        }
    }
    /*tex
        Create a new glue specification whose width is |cur_val|; scan for its stretch and shrink
        components.
    */
    q = tex_new_glue_spec_node(zero_glue);
    glue_amount(q) = cur_val;
    while (1) {
        switch (tex_scan_character("pmlPML", 0, 1, 0)) {
            case 0:
                return q;
            case 'p': case 'P':
                if (tex_scan_mandate_keyword("plus", 1)) {
                    halfword order;
                    glue_stretch(q) = tex_scan_dimension(mu, 1, 0, 0, &order);
                    glue_stretch_order(q) = order;
                }
                break;
            case 'm': case 'M':
                if (tex_scan_mandate_keyword("minus", 1)) {
                    halfword order;
                    glue_shrink(q) = tex_scan_dimension(mu, 1, 0, 0, &order);
                    glue_shrink_order(q) = order;
                }
                break;
            case 'l': case 'L':
                if (options_too && tex_scan_mandate_keyword("limit", 1)) {
                    glue_options(q) |= glue_option_limit;
                    break;
                } else {
                    /* fall through */
                }
            default:
                tex_aux_show_keyword_error(options_too ? "plus|minus|limit" : "plus|minus");
                return q;
        }
    }
}

/*tex

    This started as an experiment. A font object is just a container for a combination of id and
    scales. It permits fast font switching (not that setting the font id and scales separately is
    that slow) and has the benefit of a more sparse logging. We use nodes and not some array
    because after all we always have symbolic names and we then get saving and restoring as well as
    memory management for free.

    When an spec is given we make a copy but can overload the scales after that. Otherwise we just
    create a new spec with default scales 1000. This fontspec object was introduced after we had
    experimental compact font support in \CONTEXT\ for over a year working well.

*/

halfword tex_scan_font(int optional_equal)
{
    halfword fv = null;
    halfword id, fs;
    if (optional_equal) {
        tex_scan_optional_equals();
    }
    id = tex_scan_font_identifier(&fv);
    if (fv) {
        fs = tex_copy_node(fv);
    } else {
        /*tex We create a new one and assign the mandate id. */
        fs = tex_new_node(font_spec_node, normal_code);
        font_spec_identifier(fs) = id;
        font_spec_scale(fs) = unused_scale_value;
        font_spec_x_scale(fs) = unused_scale_value;
        font_spec_y_scale(fs) = unused_scale_value;
        font_spec_slant(fs) = 0;
        font_spec_weight(fs) = 0;
    }
    while (1) {
        switch (tex_scan_character("asxywoASXYWO", 0, 1, 0)) {
            case 0:
                return fs;
            case 'a': case 'A':
                if (tex_scan_mandate_keyword("all", 1)) {
                    font_spec_scale(fs) = tex_scan_scale_factor(0);
                    font_spec_x_scale(fs) = tex_scan_scale_factor(0);
                    font_spec_y_scale(fs) = tex_scan_scale_factor(0);
                    font_spec_slant(fs) = tex_scan_scale_factor(0);
                    font_spec_weight(fs) =  tex_scan_scale_factor(0);
                    font_spec_state(fs) |= font_spec_all_set;
                }
                break;
            case 's': case 'S':
                switch (tex_scan_character("clCL", 0, 1, 0)) {
                    case 'c': case 'C':
                        if (tex_scan_mandate_keyword("scale", 2)) {
                            font_spec_scale(fs) = tex_scan_scale_factor(0);
                            font_spec_state(fs) |= font_spec_scale_set;
                        }
                        break;
                    case 'l': case 'L':
                        if (tex_scan_mandate_keyword("slant", 2)) {
                            font_spec_slant(fs) = tex_scan_scale_factor(0);
                            font_spec_state(fs) |= font_spec_slant_set;
                        }
                        break;
                    default:
                        tex_aux_show_keyword_error("scale|slant");
                        return fs;
                }
                break;
            case 'x': case 'X':
                if (tex_scan_mandate_keyword("xscale", 1)) {
                    font_spec_x_scale(fs) = tex_scan_scale_factor(0);
                    font_spec_state(fs) |= font_spec_x_scale_set;
                }
                break;
            case 'y': case 'Y':
                if (tex_scan_mandate_keyword("yscale", 1)) {
                    font_spec_y_scale(fs) = tex_scan_scale_factor(0);
                    font_spec_state(fs) |= font_spec_y_scale_set;
                }
                break;
            case 'w': case 'W':
                if (tex_scan_mandate_keyword("weight", 1)) {
                    font_spec_weight(fs) = tex_scan_scale_factor(0);
                    font_spec_state(fs) |= font_spec_weight_set;
                }
                break;
            case 'o': case 'O': /* oblique */
                if (tex_scan_mandate_keyword("oblique", 1)) {
                    font_spec_slant(fs) = tex_scan_scale_factor(0);
                    font_spec_state(fs) |= font_spec_slant_set;
                }
                break;
            default:
                return fs;
        }
    }
}

/*tex

    This procedure is supposed to scan something like |\skip \count 12|, i.e., whatever can follow
    |\the|, and it constructs a token list containing something like |-3.0pt minus 0.5 fill|.

    There is a bit duplicate code here but it makes a nicer switch as we also need to deal with
    tokens and font identifiers.

*/

# define push_selector { \
    saved_selector = lmt_print_state.selector; \
    lmt_print_state.selector = new_string_selector_code; \
}

# define pop_selector { \
    lmt_print_state.selector = saved_selector; \
}

halfword tex_the_value_toks(int code, halfword *tail, halfword property) /* maybe split this as already checked */
{
    tex_get_x_token();
    cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, token_val_level, 0, property);
    switch (cur_val_level) {
        case integer_val_level:
        case attribute_val_level:
            {
                int saved_selector;
                push_selector;
                tex_print_int(cur_val);
                pop_selector;
                return tex_cur_str_toks(tail);
            }
        case posit_val_level:
            {
                int saved_selector;
                push_selector;
                tex_print_posit(cur_val);
                pop_selector;
                return tex_cur_str_toks(tail);
            }
        case dimension_val_level:
            {
                int saved_selector;
                push_selector;
                tex_print_dimension(cur_val, code == the_without_unit_code ? no_unit : pt_unit);
                pop_selector;
                return tex_cur_str_toks(tail);
            }
        case glue_val_level:
        case muglue_val_level:
            {
                int saved_selector;
                push_selector;
                tex_print_spec(cur_val, (code != the_without_unit_code) ? (cur_val_level == glue_val_level ? pt_unit : mu_unit) : no_unit);
                tex_flush_node(cur_val);
                pop_selector;
                return tex_cur_str_toks(tail);
            }
        case token_val_level:
            {
                /*tex Copy the token list */
                halfword h = null;
                halfword p = null;
                if (cur_val) {
                    /*tex Do not copy the reference count! */
                    halfword r = token_link(cur_val);
                    while (r) {
                        p = tex_store_new_token(p, token_info(r));
                        if (! h) {
                            h = p;
                        }
                        r = token_link(r);
                    }
                }
                if (tail) {
                    *tail = p;
                }
                return h;
            }
        case font_val_level:
            {
                int saved_selector;
                push_selector;
                tex_print_font_identifier(cur_val);
                pop_selector;
                return tex_cur_str_toks(tail);
            }
        case mathspec_val_level:
            {
                /*tex So we don't mess with null font. */
                if (cur_val) {
                    int saved_selector;
                    push_selector;
                    tex_print_mathspec(cur_val);
                    pop_selector;
                    return tex_cur_str_toks(tail);
                } else {
                    return null;
                }
            }
        case fontspec_val_level:
            {
                /*tex So we don't mess with null font. */
                if (cur_val) {
                    int saved_selector;
                    push_selector;
                    tex_print_font_specifier(cur_val);
                    pop_selector;
                    return tex_cur_str_toks(tail);
                } else {
                    return null;
                }
            }
        case list_val_level:
            {
                if (cur_val) {
                  // halfword copy = tex_copy_node_list(cur_val, null);
                     halfword copy = tex_copy_node(cur_val);
                     tex_tail_append(copy);
                     cur_val = null;
                }
                break;
            }
    }
    return null;
}

void tex_detokenize_list(halfword head)
{
    int saved_selector;
    push_selector;
    tex_show_token_list(head, 0, 0);
    pop_selector;
}

halfword tex_the_detokenized_toks(halfword *tail, int expand, int protect) // maybe we need single here too
{
    halfword head = expand ? tex_scan_toks_expand(0, tail, 1, protect) : tex_scan_general_text(tail);
    if (head) {
        halfword first = expand ? token_link(head) : head;
        if (first) {
            int saved_selector;
            push_selector;
            tex_show_token_list(first, 0, protect);
            pop_selector;
            tex_flush_token_list(head);
            return tex_cur_str_toks(tail);
        }
    }
    return null;
}

/*tex
    The |the_without_unit| variant implements |\thewithoutunit| is not really that impressive but
    just there because it's cheap to implement and also avoids a kind of annoying macro definition,
    one of the kind that demonstrates that one really understands \TEX. Now, with plenty of memory
    and disk space the added code is probably not noticed and adds less bytes to the binary than a
    macro does to the (and probably every) format file.
*/

halfword tex_the_toks(int code, halfword *tail)
{
    switch (code) {
        case the_code:
        case the_without_unit_code:
            return tex_the_value_toks(code, tail, 0);
     /* case the_with_property_code: */
     /*     return tex_the_value_toks(code, tail, tex_scan_integer(0, 0)); */
        case unexpanded_code:
            return tex_scan_general_text(tail);
        case detokenize_code:
        case expanded_detokenize_code:
        case protected_detokenize_code:
        case protected_expanded_detokenize_code:
            return tex_the_detokenized_toks(tail,
                code == expanded_detokenize_code  || code == protected_expanded_detokenize_code,
                code == protected_detokenize_code || code == protected_expanded_detokenize_code
            );
        default:
            return null;
    }
}

strnumber tex_the_scanned_result(void)
{
    /*tex return value */
    strnumber r;
    /*tex holds |selector| setting */
    int saved_selector;
    push_selector;
    switch (cur_val_level) {
        case integer_val_level:
        case attribute_val_level:
            tex_print_int(cur_val);
            break;
        case posit_val_level:
            tex_print_posit(cur_val);
            break;
        case dimension_val_level:
            tex_print_dimension(cur_val, pt_unit);
            break;
        case glue_val_level:
            tex_print_spec(cur_val, pt_unit);
            tex_flush_node(cur_val);
            break;
        case muglue_val_level:
            tex_print_spec(cur_val, mu_unit);
            tex_flush_node(cur_val);
            break;
        case token_val_level:
            if (cur_val) {
                tex_token_show(cur_val);
                break;
            } else {
                r = get_nullstr();
                goto DONE;
            }
        /*
        case list_val_level:
            printf("TODO\n");
            if (cur_val) {
                cur_val = tex_copy_node(cur_val);
                tex_couple_nodes(cur_list.tail, cur_val);
                cur_list.tail = cur_val;
            }
            r = get_nullstr();
            goto DONE;
        */
        default:
            r = get_nullstr();
            goto DONE;
    }
    r = tex_make_string();
  DONE:
    pop_selector;
    return r;
}

/*tex

    The following routine is used to implement |\fontdimen n f|. We no longer automatically increase
    the number of allocated dimensions because we have plenty of dimensions available and loading is
    done differently anyway.

*/

static halfword tex_aux_scan_font_id_and_parameter(halfword *fnt, halfword *n)
{
    *n = tex_scan_integer(0, NULL);
    *fnt = tex_scan_font_identifier(NULL);
    if (*n <= 0 || *n > max_integer) {
        tex_handle_error(
            normal_error_type,
            "Font '%s' has at most %i fontdimen parameters",
            font_original(*fnt), font_parameter_count(*fnt),
            "The font parameter index is out of range."
        );
        return 0;
    } else {
        return 1;
    }
}

void tex_set_font_dimension(void)
{
    halfword fnt, n;
    if (tex_aux_scan_font_id_and_parameter(&fnt, &n)) {
        tex_set_font_parameter(fnt, n, tex_scan_dimension(0, 0, 0, 1, NULL));
    }
}

halfword tex_get_font_dimension(void)
{
    halfword fnt, n;
    return tex_aux_scan_font_id_and_parameter(&fnt, &n) ? tex_get_font_parameter(fnt, n) : null;
}

void tex_set_scaled_font_dimension(void)
{
    halfword fnt, n;
    if (tex_aux_scan_font_id_and_parameter(&fnt, &n)) {
        tex_set_scaled_parameter(fnt, n, tex_scan_dimension(0, 0, 0, 1, NULL));
    }
}

halfword tex_get_scaled_font_dimension(void)
{
    halfword fnt, n;
    return tex_aux_scan_font_id_and_parameter(&fnt, &n) ? tex_get_scaled_parameter(fnt, n) : null;
}

/*tex Declare procedures that scan font-related stuff. */

halfword tex_scan_math_style_identifier(int tolerant, int styles)
{
    halfword style = tex_scan_integer(0, NULL);
    if (is_valid_math_style(style)) {
        return style;
    } else if (styles && are_valid_math_styles(style)) {
        return style;
    } else if (tolerant) {
        return -1;
    } else {
        tex_handle_error(
            back_error_type,
            "Missing math style, treated as \\displaystyle",
            "A style should have been here; I inserted '\\displaystyle'."
        );
        return display_style;
    }
}

halfword tex_scan_math_parameter(void)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd == math_parameter_cmd && cur_chr < math_parameter_last) {
        return cur_chr;
    } else {
        tex_handle_error(
            normal_error_type,
            "Invalid math parameter",
            "I'm going to ignore this one."
        );
        return -1;
    }
}

halfword tex_scan_fontspec_identifier(void)
{
    /*tex Get the next non-blank non-call. */
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd == fontspec_cmd) {
        return cur_chr;
    } else {
        return 0;
    }
}

halfword tex_scan_font_identifier(halfword *spec)
{
    /*tex Get the next non-blank non-call. */
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_cmd) {
        case define_font_cmd:
            return cur_font_par;
        case set_font_cmd:
            return cur_chr;
        case fontspec_cmd:
            {
                halfword fnt = tex_get_font_identifier(cur_chr);
                if (fnt && spec) {
                    *spec = fnt ? cur_chr : null;
                }
                return fnt;
            }
        case define_family_cmd:
            {
                halfword siz = cur_chr;
                halfword fam = tex_scan_math_family_number();
                halfword fnt = tex_fam_fnt(fam, siz);
                return fnt;
            }
        case register_integer_cmd:
            {
                /*tex Checking here saves a push back when we want an integer. */
                halfword fnt = register_integer_number(cur_chr);
                if (tex_is_valid_font(fnt)) {
                    return fnt;
                } else {
                    break; /* to error */
                }
            }
        case integer_cmd:
            {
                /*tex Checking here saves a push back when we want an integer. */
                halfword fnt = cur_chr;
                if (tex_is_valid_font(fnt)) {
                    return fnt;
                } else {
                    break; /* to error */
                }
            }
        case internal_integer_cmd:
            {
                /*tex Bonus:  |\setfontid| */
                if (internal_integer_number(cur_chr) == font_code) {
                    halfword fnt = tex_scan_integer(0, NULL);
                    if (tex_is_valid_font(fnt)) {
                        return fnt;
                    }
                }
                break; /* to error */
            }
        default:
            {
                /*tex We abuse |scan_cardinal| here but we have to push back.  */
                unsigned fnt = null_font;
                tex_back_input(cur_tok);
                if (tex_scan_cardinal(0, &fnt, 1)) {
                    if (tex_is_valid_font((halfword) fnt)) {
                        return (halfword) fnt;
                    }
                }
                break; /* to error */
            }
    }
    tex_handle_error(
        back_error_type,
        "Missing or invalid font identifier (or equivalent) or integer (register or otherwise)",
        "I was looking for a control sequence whose current meaning has been defined by\n"
        "\\font or a valid font id number."
    );
    return null_font;
}

/*tex

    The |scan_general_text| procedure is much like |scan_toks (false, false)|, but will be invoked
    via |expand|, i.e., recursively.

    The token list (balanced text) created by |scan_general_text| begins at |link (temp_token_head)|
    and ends at |cur_val|. (If |cur_val = temp_token_head|, the list is empty.)

*/

halfword tex_scan_general_text(halfword *tail)
{
    /*tex The tail of the token list being built: */
    halfword p = get_reference_token();
    halfword head;
    /*tex The number of nested left braces: */
    halfword unbalance = 0;
    halfword saved_scanner_status = lmt_input_state.scanner_status;
    halfword saved_warning_index = lmt_input_state.warning_index;
    halfword saved_def_ref = lmt_input_state.def_ref;
    lmt_input_state.scanner_status = scanner_is_absorbing;
    lmt_input_state.warning_index = cur_cs;
    lmt_input_state.def_ref = p;
    /*tex Remove the compulsory left brace. */
    tex_scan_left_brace();
    while (1) {
        tex_get_token();
        if (! cur_cs) {
            switch (cur_cmd) {
                case left_brace_cmd:
                    if (! cur_cs) {
                        ++unbalance;
                    }
                    break;
                case right_brace_cmd:
                    if (unbalance) {
                        --unbalance;
                        break;
                    } else {
                        goto DONE;
                    }
            }
        }
        p = tex_store_new_token(p, cur_tok);
    }
  DONE:
    head = token_link(lmt_input_state.def_ref);
    if (tail) {
        *tail = head ? p : null;
    }
    /*tex Discard reference count. */
    tex_put_available_token(lmt_input_state.def_ref);
    lmt_input_state.scanner_status = saved_scanner_status;
    lmt_input_state.warning_index = saved_warning_index;
    lmt_input_state.def_ref = saved_def_ref;
    return head;
}

/*tex

    |scan_toks|. This function returns a pointer to the tail of a new token list, and it also makes
    |def_ref| point to the reference count at the head of that list.

    There are two boolean parameters, |macro_def| and |xpand|. If |macro_def| is true, the goal is
    to create the token list for a macro definition; otherwise the goal is to create the token list
    for some other \TEX\ primitive: |\mark|, |\output|, |\everypar|, |\lowercase|, |\uppercase|,
    |\message|, |\errmessage|, |\write|, or |\special|. In the latter cases a left brace must be
    scanned next; this left brace will not be part of the token list, nor will the matching right
    brace that comes at the end. If |xpand| is false, the token list will simply be copied from the
    input using |get_token|. Otherwise all expandable tokens will be expanded until unexpandable
    tokens are left, except that the results of expanding |\the| are not expanded further. If both
    |macro_def| and |xpand| are true, the expansion applies only to the macro body (i.e., to the
    material following the first |left_brace| character).

    The value of |cur_cs| when |scan_toks| begins should be the |eqtb| address of the control
    sequence to display in runaway error messages.

    Watch out: there are two extensions to the macro definition parser: a |#0| will just gobble the
    argument and not copy it to the parameter stack, and |#+| will not remove braces around a
    \quote {single group} argument, something that comes in handy when you grab and pass over an
    argument.

    If the next character is a parameter number, make |cur_tok| a |match| token; but if it is a
    left brace, store |left_brace|, |end_match|, set |hash_brace|, and |goto done|.

    For practical reasone, we have split the |scan_toks| function up in four smaller dedicated
    functions. When we add features it makes no sense to clutter the code even more. Keep in mind
    that compared to the reference \TEX\ inplementation we have to support |\expanded| token lists
    but also |\protected| and friends. There is of course some overlap now but that's a small
    price to pay for readability.

    The split functions need less redundant checking and the expandable variants got one loop
    instead of two nested loops.

*/

static inline bool tex_parameter_escape_mode(void)
{
    return (parameter_mode_par & parameter_escape_mode) == parameter_escape_mode;
}

halfword tex_scan_toks_normal(int left_brace_found, halfword *tail)
{
    halfword unbalance = 0;
    halfword result = get_reference_token();
    halfword p = result;
    lmt_input_state.scanner_status = scanner_is_absorbing;
    lmt_input_state.warning_index = cur_cs;
    lmt_input_state.def_ref = result;
    if (! left_brace_found) {
        tex_scan_left_brace();
    }
    while (1) {
        tex_get_token();
        switch (cur_cmd) {
            case left_brace_cmd:
                if (! cur_cs) {
                    ++unbalance;
                }
                break;
            case right_brace_cmd:
                if (! cur_cs) {
                    if (unbalance) {
                        --unbalance;
                    } else {
                        goto DONE;
                    }
                }
                break;
            case prefix_cmd:
                if (cur_chr == enforced_code && (! overload_mode_par || lmt_main_state.run_state != production_state)) { /* todo cur_tok == let_aliased_token */
                    cur_tok = token_val(prefix_cmd, always_code);
                }
                break;
        }
        p = tex_store_new_token(p, cur_tok);
    }
  DONE:
    lmt_input_state.scanner_status = scanner_is_normal;
    if (tail) {
        *tail = p;
    }
    return result;
}

halfword tex_scan_toks_expand(int left_brace_found, halfword *tail, int expandconstant, int keepparameters)
{
    halfword unbalance = 0;
    halfword result = get_reference_token();
    halfword p = result;
    lmt_input_state.scanner_status = scanner_is_absorbing;
    lmt_input_state.warning_index = cur_cs;
    lmt_input_state.def_ref = result;
    if (! left_brace_found) {
        tex_scan_left_brace();
    }
    while (1) {
      PICKUP:
        tex_get_next();
        switch (cur_cmd) {
            case call_cmd:
            case tolerant_call_cmd:
                tex_expand_current_token();
                goto PICKUP;
            case constant_call_cmd:
                {
                    halfword h = token_link(cur_chr);
                    while (h) {
                        p = tex_store_new_token(p, token_info(h));
                        h = token_link(h);
                    }
                    goto PICKUP;
                }
            case protected_call_cmd:
            case tolerant_protected_call_cmd:
                cur_tok = cs_token_flag + cur_cs;
                goto APPENDTOKEN;
            case semi_protected_call_cmd:
            case tolerant_semi_protected_call_cmd:
                if (expandconstant) {
                    tex_expand_current_token();
                    goto PICKUP;
                } else {
                    cur_tok = cs_token_flag + cur_cs;
                    goto APPENDTOKEN;
                }
            case the_cmd:
                {
                    halfword t = null;
                    halfword h = tex_the_toks(cur_chr, &t);
                    if (h) {
                        set_token_link(p, h);
                        p = t;
                    }
                    goto PICKUP;
                }
            case parameter_cmd:
                {
                    /*tex This is kind of tricky and thereby experimental. No need for the extensive x here. */
                    halfword tok1, tok2;
                    tex_x_token();
                    tok1 = cur_tok;
                    tex_get_next();
                    tex_x_token();
                    tok2 = cur_tok;
                    if (keepparameters || ! tex_parameter_escape_mode()) {
                        /* not done */
                    } else {
                        halfword t;
                        halfword h = tex_expand_parameter(tok2, &t);
                        if (h) {
                            set_token_link(p, h);
                            p = t;
                            goto PICKUP;
                        } else {
                            tex_flush_token_list(h);
                        }
                    }
                    p = tex_store_new_token(p, tok1);
                    p = tex_store_new_token(p, tok2);
                    goto PICKUP;
                }
            case prefix_cmd:
                if (cur_chr == enforced_code && (! overload_mode_par || lmt_main_state.run_state != production_state)) {
                    cur_tok = token_val(prefix_cmd, always_code);
                    goto APPENDTOKEN;
                }
            default:
                if (cur_cmd > max_command_cmd) {
                    tex_expand_current_token();
                    goto PICKUP;
                } else {
                    goto DONEEXPANDING;
                }
        }
      DONEEXPANDING:
        tex_x_token();
     // if (cur_tok < right_brace_limit) {
     //     if (cur_cmd == left_brace_cmd) {
     //         ++unbalance;
     //     } else if (unbalance) {
     //         --unbalance;
     //     } else {
     //         goto FINALYDONE;
     //     }
     // }
        if (! cur_cs) {
            switch (cur_cmd) {
                case left_brace_cmd:
                    ++unbalance;
                    break;
                case right_brace_cmd:
                    if (unbalance) {
                        --unbalance;
                    } else {
                        goto FINALYDONE;
                    }
                    break;
            }
        }
      APPENDTOKEN:
        p = tex_store_new_token(p, cur_tok);
    }
  FINALYDONE:
    lmt_input_state.scanner_status = scanner_is_normal;
    if (tail) {
        *tail = p;
    }
    return result;
}

static void tex_aux_too_many_parameters_error(void)
{
    tex_handle_error(
        normal_error_type,
        "You already have 15 parameters",
        "I'm going to ignore the # sign you just used, as well the token that followed it.\n"
        /*tex That last bit was added in the TeX 2021 buglet fix round. */
    );
}

static void tex_aux_parameters_order_error(void)
{
    tex_handle_error(
        back_error_type,
        "Parameters must be numbered consecutively",
        "I've inserted the digit you should have used after the #."
    );
}

static void tex_aux_missing_brace_error(void)
{
    tex_handle_error(
        normal_error_type,
        "Missing { inserted",
        "Where was the left brace? You said something like '\\def\\a}', which I'm going to\n"
        "interpret as '\\def\\a{}'."
    );
}

static void tex_aux_illegal_parameter_in_body_error(void)
{
    tex_handle_error(
        back_error_type,
        "Illegal parameter number in definition of %S",
        lmt_input_state.warning_index,
        "You meant to type ## instead of #, right? Or maybe a } was forgotten somewhere\n"
        "earlier, and things are all screwed up? I'm going to assume that you meant ##."
    );
}

/*tex
    There are interesting aspects in reporting the preamble, like:

    \starttyping
    \def\test#1#{test#1} : macro:#1{->test#1{
    \stoptyping

    So, the \type {#} gets reported as left brace.

    The |\par| handling depends on the mode

    \starttyping
    % 0x1 text | 0x2 macro | 0x4 go-on

    \autoparagraphmode0 \def\foo#1\par{[#1]} 0: \meaningfull\foo\par \foo test\par test\par
    \autoparagraphmode1 \def\foo#1\par{[#1]} 1: \meaningfull\foo\par \foo test\par test\par
    \autoparagraphmode2 \def\foo#1\par{[#1]} 2: \meaningfull\foo\par \foo test\par test\par % discard after #1 till \par
    \autoparagraphmode4 \def\foo#1\par{[#1]} 4: \meaningfull\foo\par \foo test\par test\par
    \stoptyping
*/

/* There is no real gain and we get a 1K larger binary: */ /* inline */

static int tex_aux_valid_macro_preamble(halfword *p, int *counter, halfword *hash_brace)
{
    halfword h = *p;
    while (1) {
        tex_get_token();
        switch (cur_cmd) {
            case left_brace_cmd:
            case right_brace_cmd:
                if (cur_cs) {
                    break;
                } else {
                    goto DONE;
                }
            case parameter_cmd:
                tex_get_token();
                /*
                    cf. TeX 2021 we not do a more strict testing. Interesting is that wondered why we
                    had a more generous test here but just considered that a feature or intended side
                    effect but in the end we have to be strict.

                    \starttyping
                    \def\cs#1#\bgroup hi#1}       % was weird but okay pre 2021
                    \def\cs#1\bgroup{hi#1\bgroup} % but this is better indeed
                    \stoptyping
                */
                if (cur_tok < left_brace_limit) {
             /* if (cur_cmd == left_brace_cmd) { */
                    /*tex The |\def\foo#{}| case. */
                    *hash_brace = cur_tok;
                    *p = tex_store_new_token(*p, cur_tok);
                    *p = tex_store_new_token(*p, end_match_token);
                    set_token_preamble(h, macro_with_preamble);
                    set_token_parameters(h, *counter);
                    return 1;
                } else if (*counter == 0xF) {
                    tex_aux_too_many_parameters_error();
                } else {
                    switch (cur_tok) {
                        case zero_token:
                            ++*counter;
                            cur_tok = match_token;
                            break;
                        case asterisk_token:
                            cur_tok = spacer_match_token;
                            break;
                        case plus_token:
                            ++*counter;
                            cur_tok = keep_match_token;
                            break;
                        case minus_token:
                            cur_tok = thrash_match_token;
                            break;
                        case period_token:
                            cur_tok = par_spacer_match_token;
                            break;
                        case comma_token:
                            cur_tok = keep_spacer_match_token;
                            break;
                        case slash_token:
                            ++*counter;
                            cur_tok = prune_match_token;
                            break;
                        case colon_token:
                            cur_tok = continue_match_token;
                            break;
                        case semi_colon_token:
                            cur_tok = quit_match_token;
                            break;
                        case equal_token:
                            ++*counter;
                            cur_tok = mandate_match_token;
                            break;
                        case circumflex_token_l:
                        case circumflex_token_o:
                            ++*counter;
                            cur_tok = leading_match_token;
                            break;
                        case underscore_token_l:
                        case underscore_token_o:
                            ++*counter;
                            cur_tok = mandate_keep_match_token;
                            break;
                        case at_token_l:
                        case at_token_o:
                            cur_tok = par_command_match_token;
                            break;
                        case L_token_l:
                        case L_token_o:
                            cur_tok = left_match_token;
                            break;
                        case R_token_l:
                        case R_token_o:
                            cur_tok = right_match_token;
                            break;
                        case G_token_l:
                        case G_token_o:
                            cur_tok = gobble_match_token;
                            break;
                        case M_token_l:
                        case M_token_o:
                            cur_tok = gobble_more_match_token;
                            break;
                        case S_token_l:
                        case S_token_o:
                            cur_tok = brackets_match_token;
                            break;
                        case P_token_l:
                        case P_token_o:
                            cur_tok = parentheses_match_token;
                            break;
                        case X_token_l:
                        case X_token_o:
                            cur_tok = angles_match_token;
                            break;
                        default:
                            if (cur_tok >= one_token && cur_tok <= nine_token) {
                                ++*counter;
                                if ((cur_tok - other_token - '0') == *counter) {
                                    cur_tok += match_token - other_token ;
                                    break;
                                }
                            } else if (cur_tok >= A_token_l && cur_tok <= F_token_l) {
                                ++*counter;
                                if ((cur_tok - A_token_l + 10) == *counter) {
                                    cur_tok += match_token - letter_token;
                                    break;
                                }
                            }
                            tex_aux_parameters_order_error();
                            cur_tok = match_token; /* zero */
                            break;
                    }
                }
                break;
            case end_paragraph_cmd:
                if (! auto_paragraph_mode(auto_paragraph_macro)) {
                   cur_tok = par_command_match_token;
                }
                break;
        }
        *p = tex_store_new_token(*p, cur_tok);
    }
  DONE:
    if (h != *p) {
        *p = tex_store_new_token(*p, end_match_token);
        set_token_preamble(h, macro_with_preamble);
        set_token_parameters(h, *counter);
    }
    if (cur_cmd == right_brace_cmd) {
        ++lmt_input_state.align_state;
        tex_aux_missing_brace_error();
        return 0;
    } else {
        return 1;
    }
}

halfword tex_scan_macro_normal(void)
{
    halfword hash_brace = 0;
    halfword counter = 0;
    halfword result = get_reference_token();
    halfword p = result;
    lmt_input_state.scanner_status = scanner_is_defining;
    lmt_input_state.warning_index = cur_cs;
    lmt_input_state.def_ref = result;
    if (tex_aux_valid_macro_preamble(&p, &counter, &hash_brace)) {
        halfword unbalance = 0;
        while (1) {
            tex_get_token();
            switch (cur_cmd) {
                case left_brace_cmd:
                    if (! cur_cs) {
                        ++unbalance;
                    }
                    break;
                case right_brace_cmd:
                    if (! cur_cs) {
                        if (unbalance) {
                            --unbalance;
                        } else {
                            goto FINALYDONE;
                        }
                    }
                    break;
                case parameter_cmd:
                    {
                        halfword s = cur_tok;
                        tex_get_token();
                        if (cur_cmd == parameter_cmd) {
                            /*tex Keep the |#|. */
                        } else {
                            halfword n;
                            if (cur_tok >= one_token && cur_tok <= nine_token) {
                                n = cur_chr - '0';
                            } else if (cur_tok >= A_token_l && cur_tok <= F_token_l) {
                                n = cur_chr - '0' - gap_match_count;
                            } else {
                                n = counter + 1;
                            }
                            if (n <= counter) {
                                cur_tok = token_val(parameter_reference_cmd, n);
                            } else {
                                halfword v = tex_parameter_escape_mode() ? valid_parameter_reference(cur_tok) : 0;
                                if (v) {
                                    p = tex_store_new_token(p, token_val(parameter_cmd, match_visualizer));
                                } else {
                                    tex_aux_illegal_parameter_in_body_error();
                                    cur_tok = s;
                                }
                            }
                        }
                    }
                    break;
                case prefix_cmd:
                    if (cur_chr == enforced_code && (! overload_mode_par || lmt_main_state.run_state != production_state)) { /* todo cur_tok == let_aliased_token */
                        cur_tok = token_val(prefix_cmd, always_code);
                    }
                    break;
                default:
                    break;
            }
            p = tex_store_new_token(p, cur_tok);
        }
    }
  FINALYDONE:
    lmt_input_state.scanner_status = scanner_is_normal;
    if (hash_brace) {
        p = tex_store_new_token(p, hash_brace);
    }
    return result;
}

halfword tex_scan_macro_expand(void)
{
    halfword hash_brace = 0;
    halfword counter = 0;
    halfword result = get_reference_token();
    halfword p = result;
    lmt_input_state.scanner_status = scanner_is_defining;
    lmt_input_state.warning_index = cur_cs;
    lmt_input_state.def_ref = result;
    if (tex_aux_valid_macro_preamble(&p, &counter, &hash_brace)) {
        halfword unbalance = 0;
        while (1) {
          PICKUP:
            tex_get_next();
            switch (cur_cmd) {
                case call_cmd:
                case tolerant_call_cmd:
                    tex_expand_current_token();
                    goto PICKUP;
                case index_cmd:
                    tex_inject_parameter(cur_chr);
                    goto PICKUP;
                case constant_call_cmd:
                    {
                        halfword h = token_link(cur_chr);
                        while (h) {
                            p = tex_store_new_token(p, token_info(h));
                            h = token_link(h);
                        }
                        goto PICKUP;
                    }
                case protected_call_cmd:
                case semi_protected_call_cmd:
                case tolerant_protected_call_cmd:
                case tolerant_semi_protected_call_cmd:
                    cur_tok = cs_token_flag + cur_cs;
                    goto APPENDTOKEN;
                case the_cmd:
                    {
                        halfword t = null;
                        halfword h = tex_the_toks(cur_chr, &t);
                        if (h) {
                            set_token_link(p, h);
                            p = t;
                        }
                        goto PICKUP;
                    }
                case relax_cmd:
                    if (cur_chr == no_relax_code) {
                        /*tex Think of |\ifdim\dimen0=\dimen2\norelax| inside an |\edef|. */
                        goto PICKUP;
                    } else {
                        goto DONEEXPANDING;
                    }
                case prefix_cmd:
                    if (cur_chr == enforced_code && (! overload_mode_par || lmt_main_state.run_state != production_state)) {
                        cur_tok = token_val(prefix_cmd, always_code);
                        goto APPENDTOKEN;
                    } else {
                        goto DONEEXPANDING;
                    }
                case parameter_cmd:
                    {
                        /* move into switch ... */
                        halfword s = cur_tok;
                        tex_get_x_token();
                        if (cur_cmd == parameter_cmd) {
                            /*tex Keep the |#|. */
                        } else {
                            halfword n;
                            if (cur_tok >= one_token && cur_tok <= nine_token) {
                                n = cur_chr - '0';
                            } else if (cur_tok >= A_token_l && cur_tok <= F_token_l) {
                                n = cur_chr - '0' - gap_match_count;
                            } else {
                                n = counter + 1;
                            }
                            if (n <= counter) {
                                cur_tok = token_val(parameter_reference_cmd, n);
                            } else {
                                halfword v = tex_parameter_escape_mode() ? valid_parameter_reference(cur_tok) : 0;
                                if (v) {
                                    halfword t = null;
                                    halfword h = tex_expand_parameter(cur_tok, &t);
                                    if (h) {
                                        set_token_link(p, h);
                                        p = t;
                                    }
                                    goto PICKUP;
                                } else {
                                    tex_aux_illegal_parameter_in_body_error();
                                    cur_tok = s;
                                }
                            }
                        }
                        goto APPENDTOKEN;
                    }
                case left_brace_cmd:
                    if (cur_cs) {
                        cur_tok = cs_token_flag + cur_cs;
                    } else {
                        cur_tok = token_val(cur_cmd, cur_chr);
                        ++unbalance;
                    }
                    goto APPENDTOKEN;
                case right_brace_cmd:
                    if (cur_cs) {
                        cur_tok = cs_token_flag + cur_cs;
                        goto APPENDTOKEN;
                    } else {
                        cur_tok = token_val(cur_cmd, cur_chr);
                        if (unbalance) {
                            --unbalance;
                            goto APPENDTOKEN;
                        } else {
                            goto FINALYDONE;
                        }
                    }
                default:
                    if (cur_cmd > max_command_cmd) {
                        tex_expand_current_token();
                        goto PICKUP;
                    } else {
                        goto DONEEXPANDING;
                    }
            }
          DONEEXPANDING:
            if (cur_cs) {
                cur_tok = cs_token_flag + cur_cs;
            } else {
                cur_tok = token_val(cur_cmd, cur_chr);
            }
          APPENDTOKEN:
            p = tex_store_new_token(p, cur_tok);
        }
    }
  FINALYDONE:
    lmt_input_state.scanner_status = scanner_is_normal;
    if (hash_brace) {
        p = tex_store_new_token(p, hash_brace);
    }
    return result;
}

/*tex

    The |scan_expr| procedure scans and evaluates an expression. Evaluating an expression is a
    recursive process: When the left parenthesis of a subexpression is scanned we descend to the
    next level of recursion; the previous level is resumed with the matching right parenthesis.

*/

typedef enum expression_states {
    expression_none,     /*tex |(| or |(expr)| */
    expression_add,      /*tex |+| */
    expression_subtract, /*tex |-| */
    expression_multiply, /*tex |*| */
    expression_divide,   /*tex |/| */
    expression_scale,    /*tex |* factor| */
    expression_idivide,  /*tex |:|, is like |/| but floored */
    expression_imodulo,  /*tex |;| */
} expression_states;

/*tex

    We want to make sure that each term and (intermediate) result is in the proper range. Integer
    values must not exceed |infinity| ($2^{31} - 1$) in absolute value, dimensions must not exceed
    |max_dimension| ($2^{30} - 1$). We avoid the absolute value of an integer, because this might fail
    for the value $-2^{31}$ using 32-bit arithmetic.

    Todo: maybe use |long long| here.

*/

static inline void tex_aux_normalize_glue(halfword g)
{
    if (! glue_stretch(g)) {
        glue_stretch_order(g) = normal_glue_order;
    }
    if (! glue_shrink(g)) {
        glue_shrink_order(g) = normal_glue_order;
    }
}

/*tex

    Parenthesized subexpressions can be inside expressions, and this nesting has a stack. Seven
    local variables represent the top of the expression stack: |p| points to pushed-down entries,
    if any; |l| specifies the type of expression currently beeing evaluated; |e| is the expression
    so far and |r| is the state of its evaluation; |t| is the term so far and |s| is the state of
    its evaluation; finally |n| is the numerator for a combined multiplication and division, if any.

    The function |add_or_sub (x, y, max_answer, negative)| computes the sum (for |negative = false|)
    or difference (for |negative = true|) of |x| and |y|, provided the absolute value of the result
    does not exceed |max_answer|.

*/

static inline int tex_aux_add_or_sub(int x, int y, int max_answer, int operation)
{
    switch (operation) {
        case expression_subtract:
            y = -y;
            // fall-trough
        case expression_add:
            if (x >= 0) {
                if (y <= max_answer - x) {
                    return x + y;
                } else {
                    lmt_scanner_state.arithmic_error = 1;
                }
            } else if (y >= -max_answer - x) {
                return x + y;
            } else {
                lmt_scanner_state.arithmic_error = 1;
            }
            break;
    }
    return 0;
}

/*tex

    The function |quotient (n, d)| computes the rounded quotient $q = \lfloor n / d + {1 \over 2}
    \rfloor$, when $n$ and $d$ are positive.

*/

// static inline int tex_aux_quotient(int n, int d, int round)
// {
//     /*tex The answer: */
//     if (d == 0) {
//         lmt_scanner_state.arithmic_error = 1;
//         return 0;
//     } else {
//         /*tex Should the answer be negated? */
//         bool negative;
//         int a;
//         if (d > 0) {
//             negative = false;
//         } else {
//             d = -d;
//             negative = true;
//         }
//         if (n < 0) {
//             n = -n;
//             negative = ! negative;
//         }
//         a = n / d;
//         if (round) {
//             n = n - a * d;
//             /*tex Avoid certain compiler optimizations! Really? */
//             d = n - d;
//             if (d + n >= 0) {
//                 ++a;
//             }
//         }
//         if (negative) {
//             a = -a;
//         }
//         return a;
//     }
// }

static inline int tex_aux_quotient(int n, int d, int rounded)
{
    if (d == 0) {
        lmt_scanner_state.arithmic_error = 1;
        return 0;
    } else if (rounded) {
        return lround((double) n / (double) d);
    } else {
        return n / d;
    }
}

static inline int tex_aux_modulo(int n, int d)
{
    if (d == 0) {
        lmt_scanner_state.arithmic_error = 1;
        return 0;
    } else {
        return n % d;
    }
}

int tex_quotient(int n, int d, int round)
{
    return tex_aux_quotient(n, d, round);
}

/*tex

    Finally, the function |fract (x, n, d, max_answer)| computes the integer $q = \lfloor x n / d
    + {1 \over 2} \rfloor$, when $x$, $n$, and $d$ are positive and the result does not exceed
    |max_answer|. We can't use floating point arithmetic since the routine must produce identical
    results in all cases; and it would be too dangerous to multiply by~|n| and then divide by~|d|,
    in separate operations, since overflow might well occur. Hence this subroutine simulates double
    precision arithmetic, somewhat analogous to Metafont's |make_fraction| and |take_fraction|
    routines.

*/

int tex_fract(int x, int n, int d, int max_answer)
{
    /*tex should the answer be negated? */
    bool negative = false;
    /*tex the answer */
    int a = 0;
    /*tex a proper fraction */
    int f;
    /*tex smallest integer such that |2 * h >= d| */
    int h;
    /*tex intermediate remainder */
    int r;
    /*tex temp variable */
    int t;
    if (d == 0) {
        goto TOO_BIG;
    }
    if (x == 0) {
        return 0;
    }
    if (n == d) {
        return x;
    }
    if (d < 0) {
        d = -d;
        negative = true;
    }
    if (x < 0) {
        x = -x;
        negative = ! negative;
    }
    if (n < 0) {
        n = -n;
        negative = ! negative;
    }
    t = n / d;
    if (t > max_answer / x) {
        goto TOO_BIG;
    }
    a = t * x;
    n = n - t * d;
    if (n == 0) {
        goto FOUND;
    }
    t = x / d;
    if (t > (max_answer - a) / n) {
        goto TOO_BIG;
    }
    a = a + t * n;
    x = x - t * d;
    if (x == 0) {
        goto FOUND;
    }
    if (x < n) {
        t = x;
        x = n;
        n = t;
    }
    /*tex

        Now |0 < n <= x < d| and we compute $f = \lfloor xn/d+{1\over2}\rfloor$. The loop here
        preserves the following invariant relations between |f|, |x|, |n|, and~|r|: (i)~$f + \lfloor
        (xn + (r + d))/d\rfloor = \lfloor x_0 n_0/d + {1\over2} \rfloor$; (ii)~|-d <= r < 0 < n <= x
        < d|, where $x_0$, $n_0$ are the original values of~$x$ and $n$.

        Notice that the computation specifies |(x - d) + x| instead of |(x + x) - d|, because the
        latter could overflow.

    */
    f = 0;
    r = (d / 2) - d;
    h = -r;
    while (1) {
        if (odd(n)) {
            r = r + x;
            if (r >= 0) {
                r = r - d;
                ++f;
            }
        }
        n = n / 2;
        if (n == 0) {
            break;
        } else if (x < h) {
            x = x + x;
        } else {
            t = x - d;
            x = t + x;
            f = f + n;
            if (x < n) {
                if (x == 0) {
                    break;
                } else {
                    t = x;
                    x = n;
                    n = t;
                }
            }
        }
    }
    if (f > (max_answer - a)) {
        goto TOO_BIG;
    }
    a = a + f;
  FOUND:
    if (negative) {
        a = -a;
    }
    goto DONE;
  TOO_BIG:
    lmt_scanner_state.arithmic_error = 1;
    a = 0;
  DONE:
    return a;
}

/*tex

    The main stacking logic approach is kept but I get the impression that the code is still
    suboptimal. We also accept braced expressions.

*/

static void tex_aux_scan_expr(halfword level)
{
    /*tex state of expression so far */
    int result;
    /*tex state of term so far */
    int state;
    /*tex next operation or type of next factor */
    int operation;
    /*tex expression so far */
    int expression;
    /*tex term so far */
    int term;
    /*tex current factor */
    int factor = 0;
    /*tex numerator of combined multiplication and division */
    int numerator;
    /*tex saved values of |arith_error| */
    int error_a = lmt_scanner_state.arithmic_error;
    int error_b = 0;
    /*tex top of expression stack */
    halfword top = null;
    int braced = 0;
    int nonelevel = level == posit_val_level ? posit_val_level : integer_val_level;
    /*tex Scan and evaluate an expression |e| of type |l|. */
    cur_val_level = level; /* for now */
    lmt_scanner_state.expression_depth++;
    if (lmt_scanner_state.expression_depth > 1000) {
        tex_fatal_error("\\*expr can only be nested 1000 deep");
    }
  RESTART:
    result = expression_none;
    state = expression_none;
    expression = 0;
    term = 0;
    numerator = 0;
  CONTINUE:
//    operation = state == expression_none ? level : integer_val_level; /* we abuse operation */
    operation = state == expression_none ? level : nonelevel; /* we abuse operation */
    /*tex
        Scan a factor |f| of type |o| or start a subexpression. Get the next non-blank non-call
        token.
    */
  AGAIN:
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (! braced) {
        if (cur_cmd == left_brace_cmd) {
            braced = 1;
            goto AGAIN;
        } else {
            braced = 2;
        }
    }
    if (cur_tok == left_parent_token) {
        /*tex Push the expression stack and |goto restart|. */
        halfword t = tex_get_node(expression_node_size);
        node_type(t) = expression_node;
        node_subtype(t) = 0;
        /* */
        node_next(t) = top;
        expression_type(t) = (singleword) level;
        expression_state(t) = (singleword) state;
        expression_result(t) = (singleword) result;
        expression_expression(t) = expression;
        expression_term(t) = term;
        expression_numerator(t) = numerator;
        top = t;
        level = operation;
        goto RESTART;
    }
    if (cur_cmd != spacer_cmd) {
        tex_back_input(cur_tok);
    }
    switch (operation) {
        case integer_val_level:
        case attribute_val_level:
            factor = tex_scan_integer(0, NULL);
            break;
        case posit_val_level:
            factor = tex_scan_posit(0);
            break;
        case dimension_val_level:
            factor = tex_scan_dimension(0, 0, 0, 0, NULL);
            break;
        case glue_val_level:
            factor = tex_scan_glue(glue_val_level, 0, 0);
            break;
        case muglue_val_level:
            factor = tex_scan_glue(muglue_val_level, 0, 0);
            break;
    }
  FOUND:
    /*tex
        Scan the next operator and set |o| and get the next non-blank non-call token.
    */
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    switch (cur_tok) {
        case plus_token:
            operation = expression_add;
            break;
        case minus_token:
            operation = expression_subtract;
            break;
        case asterisk_token:
            operation = expression_multiply;
            break;
        case slash_token:
            operation = expression_divide;
            break;
        case colon_token:
//            if (etex_expr_mode) {
//                /* according to MS some folk don't like this feature, well ... */
//                goto PREVENTBASHING;
//            } else {
                operation = expression_idivide;
//            }
            break;
        case semi_colon_token:
//            if (etex_expr_mode) {
//                /* according to MS some folk don't like this feature, well ... */
//                goto PREVENTBASHING;
//            } else {
                operation = expression_imodulo;
//            }
            break;
        /*tex
            The commented bitwise experiment as of 2020-07-20 has been removed and is now in
            |\scanbitexpr|. You can find it in the archive.
        */
        default:
//          PREVENTBASHING:
            operation = expression_none;
            if (! top) {
                if (cur_cmd == relax_cmd) {
                    /* we're done */
                } else if (cur_cmd == right_brace_cmd && braced == 1) {
                    /* we're done */
                } else {
                    tex_back_input(cur_tok);
                }
            } else if (cur_tok != right_parent_token) {
                tex_handle_error(
                    back_error_type,
                    "Missing ) inserted for expression",
//            etex_expr_mode ?
                    "I was expecting to see '+', '-', '*', '/', ':', ';' or ')' but didn't."
//            :
//                  "I was expecting to see '+', '-', '*', '/' or ')' but didn't."
                );
            }
            break;
    }
    lmt_scanner_state.arithmic_error = error_b;
    /*tex Make sure that |f| is in the proper range. */
    switch (level) {
        case integer_val_level:
        case attribute_val_level:
            if ((factor > max_integer) || (factor < min_integer)) {
                lmt_scanner_state.arithmic_error = 1;
                factor = 0;
            }
            break;
        case posit_val_level:
            if ((factor > max_integer) || (factor < min_integer)) {
                lmt_scanner_state.arithmic_error = 1;
                factor = 0;
            }
            break;
        case dimension_val_level:
            if (abs(factor) > max_dimension) {
                lmt_scanner_state.arithmic_error = 1;
                factor = 0;
            }
            break;
        case glue_val_level:
        case muglue_val_level:
            if ((abs(glue_amount(factor)) > max_dimension) || (abs(glue_stretch(factor)) > max_dimension) || (abs(glue_shrink(factor)) > max_dimension)) {
                lmt_scanner_state.arithmic_error = 1;
                tex_reset_glue_to_zero(factor);
            }
            break;
        default:
            if ((state > expression_subtract) && ((factor > max_integer) || (factor < min_integer))) {
                lmt_scanner_state.arithmic_error = 1;
                factor = 0;
            }
    }
    /*tex Cases for evaluation of the current term. */
    switch (state) {
        case expression_none:
            /*tex
                Applying the factor |f| to the partial term |t| (with the operator |s|) is delayed
                until the next operator |o| has been scanned. Here we handle the first factor of a
                partial term. A glue spec has to be copied unless the next operator is a right
                parenthesis; this allows us later on to simply modify the glue components.
            */
            term = factor;
            if ((level >= glue_val_level) && (operation != expression_none)) {
                /*tex Do we really need to copy here? */
                tex_aux_normalize_glue(term);
            } else {
                term = factor;
            }
            break;
        case expression_multiply:
            /*tex
                If a multiplication is followed by a division, the two operations are combined into
                a 'scaling' operation. Otherwise the term |t| is multiplied by the factor |f|.
            */
            if (operation == expression_divide) {
                numerator = factor;
                operation = expression_scale;
            } else {
                switch (level) {
                    case integer_val_level:
                    case attribute_val_level:
                        term = tex_multiply_integers(term, factor);
                        break;
                    case posit_val_level:
                        term = tex_posit_mul(term, factor);
                        break;
                    case dimension_val_level:
                        term = tex_nx_plus_y(term, factor, 0);
                        break;
                    default:
                        glue_amount(term) = tex_nx_plus_y(glue_amount(term), factor, 0);
                        glue_stretch(term) = tex_nx_plus_y(glue_stretch(term), factor, 0);
                        glue_shrink(term) = tex_nx_plus_y(glue_shrink(term),  factor, 0);
                        break;
                }
            }
            break;
        case expression_divide:
            /*tex Here we divide the term |t| by the factor |f|. */
            switch (level) {
                case integer_val_level:
                case attribute_val_level:
                case dimension_val_level:
                    term = tex_aux_quotient(term, factor, 1);
                    break;
                case posit_val_level:
                    if (factor == 0) {
                        lmt_scanner_state.arithmic_error = 1;
                        term = 0;
                    } else {
                        term = tex_posit_div(term, factor);
                    }
                    break;
                default:
                    glue_amount(term) = tex_aux_quotient(glue_amount(term), factor, 1);
                    glue_stretch(term) = tex_aux_quotient(glue_stretch(term), factor, 1);
                    glue_shrink(term) = tex_aux_quotient(glue_shrink(term), factor, 1);
                    break;
            }
            break;
        case expression_scale:
            /*tex Here the term |t| is multiplied by the quotient $n/f$. */
            switch (level) {
                case integer_val_level:
                case attribute_val_level:
                    term = tex_fract(term, numerator, factor, max_integer);
                    break;
                case posit_val_level:
                    if (numerator == 0) {
                        lmt_scanner_state.arithmic_error = 1;
                        term = 0;
                    } else {
                        term = tex_posit_div(tex_posit_mul(term, factor), numerator);
                    }
                    break;
                case dimension_val_level:
                    term = tex_fract(term, numerator, factor, max_dimension);
                    break;
                default:
                    glue_amount(term) = tex_fract(glue_amount(term),   numerator, factor, max_dimension);
                    glue_stretch(term) = tex_fract(glue_stretch(term), numerator, factor, max_dimension);
                    glue_shrink(term) = tex_fract(glue_shrink(term),  numerator, factor, max_dimension);
                    break;
            }
            break;
        case expression_idivide:
            /*tex Here we divide the term |t| by the factor |f| but we don't round. */
            if (level < glue_val_level) {
                term = tex_aux_quotient(term, factor, 0);
            } else {
                glue_amount(term) = tex_aux_quotient(glue_amount(term),   factor, 0);
                glue_stretch(term) = tex_aux_quotient(glue_stretch(term), factor, 0);
                glue_shrink(term) = tex_aux_quotient(glue_shrink(term),  factor, 0);
            }
            break;
        case expression_imodulo:
            /* \the\numexpr#2-(#2:#1)*#1\relax */
            if (level < glue_val_level) {
                term = tex_aux_modulo(term, factor);
            } else {
                glue_amount(term) = tex_aux_modulo(glue_amount(term),   factor);
                glue_stretch(term) = tex_aux_modulo(glue_stretch(term), factor);
                glue_shrink(term) = tex_aux_modulo(glue_shrink(term),  factor);
            }
            break;
    }
    if (operation > expression_subtract) {
        state = operation;
    } else {
        /*tex
            Evaluate the current expression. When a term |t| has been completed it is copied to,
            added to, or subtracted from the expression |e|.
        */
        state = expression_none;
        if (result == expression_none) {
            expression = term;
        } else {
            switch (level) {
                case integer_val_level:
                case attribute_val_level:
                    expression = tex_aux_add_or_sub(expression, term, max_integer, result);
                    break;
                case posit_val_level:
                    switch (result) {
                        case expression_subtract:
                            expression = tex_posit_sub(expression, term);
                            break;
                        case expression_add:
                            expression = tex_posit_add(expression, term);
                            break;
                    }
                    break;
                case dimension_val_level:
                    expression = tex_aux_add_or_sub(expression, term, max_dimension, result);
                    break;
                default :
                    /*tex
                        Compute the sum or difference of two glue specs. We know that |stretch_order
                        (e) > normal| implies |stretch (e) <> 0| and |shrink_order (e)  > normal|
                        implies |shrink (e) <> 0|.
                    */
                    glue_amount(expression) = tex_aux_add_or_sub(glue_amount(expression), glue_amount(term), max_dimension, result);
                    if (glue_stretch_order(expression) == glue_stretch_order(term)) {
                        glue_stretch(expression) = tex_aux_add_or_sub(glue_stretch(expression), glue_stretch(term), max_dimension, result);
                    } else if ((glue_stretch_order(expression) < glue_stretch_order(term)) && (glue_stretch(term) != 0)) {
                        glue_stretch(expression) = glue_stretch(term);
                        glue_stretch_order(expression) = glue_stretch_order(term);
                    }
                    if (glue_shrink_order(expression) == glue_shrink_order(term)) {
                        glue_shrink(expression) = tex_aux_add_or_sub(glue_shrink(expression), glue_shrink(term), max_dimension, result);
                    } else if ((glue_shrink_order(expression) < glue_shrink_order(term)) && (glue_shrink(term) != 0)) {
                        glue_shrink(expression) = glue_shrink(term);
                        glue_shrink_order(expression) = glue_shrink_order(term);
                    }
                    tex_flush_node(term);
                    tex_aux_normalize_glue(expression);
                    break;
            }
        }
        result = operation;
    }
    error_b = lmt_scanner_state.arithmic_error;
    if (operation != expression_none) {
        goto CONTINUE;
    } else if (top) {
        /*tex Pop the expression stack and |goto found|. */
        halfword t = top;
        top = node_next(top);
        factor = expression;
        expression = expression_expression(t);
        term = expression_term(t);
        numerator = expression_numerator(t);
        state = expression_state(t);
        result = expression_result(t);
        level = expression_type(t);
        tex_free_node(t, expression_node_size);
        goto FOUND;
    } else if (error_b) {
        tex_handle_error(
            normal_error_type,
            "Arithmetic overflow",
            "I can't evaluate this expression, since the result is out of range."
        );
        if (level >= glue_val_level) {
            tex_reset_glue_to_zero(expression);
        } else {
            expression = 0;
        }
    }
    lmt_scanner_state.arithmic_error = error_a;
    lmt_scanner_state.expression_depth--;
    cur_val_level = level;
    cur_val = expression;
}

/*tex

    Already early in \LUAMETATEX\ I wondered about adding suypport for boolean expressions but at
    that time (2019) I still wanted it as part of \type |\numexpr|. I added some code that actually
    worked okay, but kept it commented. After all, we don't need it that often and \CONTEXT\ has
    helpers for it so it's best to avoid the extra overhead in other expressions.

    However, occasionally, when I check the manual I came back to this. I wondered about some more
    that just extra bitwise operators. However, prcedence makes it a bit tricky. Also, we can't use
    some characters because they can be letter, other, active or have special meaning in math or
    alignments. Then I played with verbose operators: mod (instead of a percent sign), and
    |and|, |or|, |band|, |bor| and |bxor| (cf the \LUA\ bit32 library).

    In the end I decided not to integrate it but make a dedicated |\bitexpr| instead. I played with
    some variants but the approach in the normal expression scanned is not really suitable for it.

    In the end, after some variations, I decided that some reverse polish notation approach made
    more sense and when considering an infix to rpn translation and searching the web a bit I ran
    into nice example:

        https://github.com/chidiwilliams/expression-evaluator/blob/main/simple.js

    It shows how to handled the nested expressions. I made a comaprable variant in \LUA, extended
    it for more than the usual four operators, condensed it a bit and then went on to write the code
    below. Of course we have a completely different token parser and we use \TEX\ (temp) nodes for
    a few stacks. I know that we can combine the loops but that becomes messy and performance is
    quite okay, also because we move items from one to another stack with little overhead. Although
    stacks are not that large, using static sized stacks (\CCODE\ arrays) makes no sense here.

    After the initial |\bitexpr| I eventually ended up with an integer and dimension scanner and
    it became more complex that originally intended, but the current implementaiton is flexible
    enough to extend. I can probably squeeze out some more performance.

    Beware: details can change, for instance handling some (math) \UNICODE\ characters has been
    dropped because it's an inconsistent bunch and incomplete anyway.

    In the end we have a set of dedicated scanners. We could use the existing ones but for instance
    units are optional here. We also have a bit more predictable sentinel, so we can optimize some
    push back. We don't handle mu units nor fillers. It was also kind of fun to explore that.

*/

typedef enum bit_expression_states {
    bit_expression_none,

    bit_expression_bor,       /*  |   bor  v */
    bit_expression_band,      /*  &   band   */
    bit_expression_bxor,      /*  ^   bxor   */

    bit_expression_bset,      /*      bset   */
    bit_expression_bunset,    /*      bunset */

    bit_expression_bleft,     /*  <<         */
    bit_expression_bright,    /*  >>         */

    bit_expression_less,      /*  <          */
    bit_expression_lessequal, /*  <=         */
    bit_expression_equal,     /*  =   ==     */
    bit_expression_moreequal, /*  >=         */
    bit_expression_more,      /*  >          */
    bit_expression_unequal,   /*  <>  !=     */

    bit_expression_add,       /*  +          */
    bit_expression_subtract,  /*  -          */

    bit_expression_multiply,  /*  *          */
    bit_expression_divide,    /*  /   :      */

    bit_expression_mod,       /*  %   mod    */

 // bit_expression_power,     /*             */

    bit_expression_not,       /* ! ~  not    */

    bit_expression_or,        /* or          */
    bit_expression_and,       /* and         */

    bit_expression_open,
    bit_expression_close,

    bit_expression_number,
    bit_expression_float,
    bit_expression_dimension,
} bit_expression_states;


static int bit_operator_precedence[] = {  /* like in lua */
    0, // bit_expression_none
    4, // bit_expression_bor
    6, // bit_expression_band
    5, // bit_expression_bxor

    7, // bit_expression_bset   // like shifts
    7, // bit_expression_bunset // like shifts

    7, // bit_expression_bleft
    7, // bit_expression_bright

    3, // bit_expression_less
    3, // bit_expression_lessequal
    3, // bit_expression_equal
    3, // bit_expression_more
    3, // bit_expression_moreequal
    3, // bit_expression_unequal

    8, // bit_expression_add
    8, // bit_expression_subtract

    9, // bit_expression_multiply
    9, // bit_expression_divide

    9, // bit_expression_mod

// 10, // bit_expression_power

   10, // bit_expression_not

    1, // bit_expression_or
    2, // bit_expression_and

    0, // bit_expression_open
    0, // bit_expression_close

    0, // bit_expression_number
    0,
    0,
};

static const char *bit_expression_names[] = {
    "none", "bor", "band", "bxor", "bset", "bunset",
    "<<", ">>", "<", "<=", "==", ">=", ">", "<>",
    "+", "-", "*", "/", "mod", "not", "or", "and",
    "open", "close", "number", "float", "dimension"
};

/*tex
    This way we stay within the regular tex accuracy with 1000 scales. But I will play with a
    variant that only uses doubles: |dimenexpression| and |numberexpression|.
*/

# define factor 1 // 256, 1000 : wrong results so needs a fix

typedef struct stack_info {
    halfword head;
    halfword tail;
} stack_info;

static stack_info tex_aux_new_stack(void)
{
    return (stack_info) {
        .head = null,
        .tail = null,
    };
}

static void tex_aux_dispose_stack(stack_info *stack)
{
    /*tex Unless we have a problem we have stacks with zero or one slot. */
    halfword current = stack->head;
    while (current) {
        halfword next = node_next(current);
        tex_free_node(current, expression_node_size);
        current = next;
    }
}

static void tex_push_stack_entry(stack_info *stack, long long value)
{
    halfword n = tex_get_node(expression_node_size);
    node_type(n) = expression_node;
    node_subtype(n) = 0;
    expression_entry(n) = value;
    if (! stack->head) {
        stack->head = n;
    } else if (stack->head == stack->tail)  {
        node_next(stack->head) = n;
        node_prev(n) = stack->head;
    } else {
        node_prev(n) = stack->tail;
        node_next(stack->tail) = n;
    }
    stack->tail = n;
}

static long long tex_pop_stack_entry(stack_info *stack)
{
    halfword t = stack->tail;
    if (t) {
        long long v = expression_entry(t);
        if (t == stack->head) {
            stack->head = null;
            stack->tail = null;
        } else {
            stack->tail = node_prev(t);
            node_next(stack->tail) = null;
        }
        tex_free_node(t, expression_node_size);
        return v;
    } else {
        return 0;
    }
}

static void tex_move_stack_entry(stack_info *target, stack_info *source)
{
    halfword n = source->tail;
    if (n == source->head) {
        source->head = null;
        source->tail = null;
    } else {
        source->tail = node_prev(n);
    }
    if (! target->head) {
        target->head = n;
        node_prev(n) = null;
    } else if (target->head == target->tail)  {
        node_next(target->head) = n;
        node_prev(n) = target->head;
    } else {
        node_prev(n) = target->tail;
        node_next(target->tail) = n;
    }
    node_next(n) = null;
    target->tail = n;
}

static void tex_take_stack_entry(stack_info *target, stack_info *source, halfword current)
{
    while (source->head != current) {
        halfword next = node_next(source->head);
        tex_free_node(source->head, expression_node_size);
        source->head = next;
    }
    if (current == source->tail) {
        source->head = null;
        source->tail = null;
    } else {
        source->head = node_next(current);
    }
    if (! target->head) {
        target->head = current;
        node_prev(current) = null;
    } else if (target->head == target->tail)  {
        node_next(target->head) = current;
        node_prev(current) = target->head;
    } else {
        node_prev(current) = target->tail;
        node_next(target->tail) = current;
    }
    node_next(current) = null;
    target->tail = current;
}

static halfword tex_aux_scan_unit_applied(halfword value, halfword fraction, int has_fraction, int *has_unit)
{
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        halfword saved_val = value;
        value = tex_aux_scan_something_internal(cur_cmd, cur_chr, dimension_val_level, 0, 0);
        value = tex_nx_plus_y(saved_val, cur_val, tex_xn_over_d(cur_val, fraction, unity));
        return value;
    } else if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
        halfword num = 0;
        halfword denom = 0;
        halfword saved_cs = cur_cs;
        halfword saved_tok = cur_tok;
        *has_unit = 1;
        switch (cur_chr) {
            case 'p': case 'P':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 't': case 'T':
                            goto NORMALUNIT;
                        case 'c': case 'C':
                            num = 12;
                            denom = 1;
                            goto NORMALUNIT;
                        case 'x': case 'X':
                            return tex_nx_plus_y(value, px_dimension_par, tex_xn_over_d(px_dimension_par, fraction, unity));
                    }
                }
                break;
            case 'c': case 'C':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 'm': case 'M':
                            num = 7227;
                            denom = 254;
                            goto NORMALUNIT;
                        case 'c': case 'C':
                            num = 14856;
                            denom = 1157;
                            goto NORMALUNIT;
                    }
                }
                break;
            case 's': case 'S':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 'p': case 'P':
                            return scaled_point_scanned;
                    }
                }
                break;
            case 't': case 'T':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 's': case 'S':
                            num = 4588;
                            denom = 645;
                            goto NORMALUNIT;
                    }
                }
                break;
            case 'b': case 'B':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 'p': case 'P':
                            num = 7227;
                            denom = 7200;
                            goto NORMALUNIT;
                    }
                }
                break;
            case 'i': case 'I':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 'n': case 'N':
                            num = 7227;
                            denom = 100;
                            goto NORMALUNIT;
                    }
                }
                break;
            case 'd': case 'D':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 'd': case 'D':
                            num = 1238;
                            denom = 1157;
                            goto NORMALUNIT;
                    }
                }
                break;
            case 'e': case 'E':
                tex_get_x_token();
                if (cur_cmd == letter_cmd || cur_cmd == other_char_cmd) {
                    switch (cur_chr) {
                        case 'm': case 'M':
                            return tex_get_scaled_em_width(cur_font_par);
                        case 'x': case 'X':
                            return tex_get_scaled_ex_height(cur_font_par);
                        case 's': case 'S':
                            num = 9176;
                            denom = 129;
                            goto NORMALUNIT;
                        case 'u': case 'U':
                            num = 9176 * eu_factor_par;
                            denom = 129 * 10;
                            goto NORMALUNIT;
                    }
                }
                break;
            default:
                goto HALFUNIT;
        }
        goto NOUNIT;
      NORMALUNIT:
        if (num) {
            int remainder = 0;
            value = tex_xn_over_d_r(value, num, denom, &remainder);
            fraction = (num * fraction + unity * remainder) / denom;
            value += fraction / unity;
            fraction = fraction % unity;
        }
        if (value >= 040000) { // 0x4000
            lmt_scanner_state.arithmic_error = 1;
        } else {
            value = value * unity + fraction;
        }
        return value;
      NOUNIT:
        tex_back_input(cur_tok);
      HALFUNIT:
        tex_back_input(saved_tok);
        cur_cs = saved_cs;
        cur_tok = saved_tok;
    } else {
        tex_back_input(cur_tok);
    }
    if (has_fraction) {
        *has_unit = 0;
        if (value >= 040000) { // 0x4000
            lmt_scanner_state.arithmic_error = 1;
        } else {
            value = value * unity + fraction;
        }
    }
    return value;
}

// This replaces the above but I need to test it first!

// static halfword tex_aux_scan_unit_applied(halfword value, halfword fraction, int has_fraction, int *has_unit)
// {
//     halfword num = 0;
//     halfword denom = 0;
//     scaled unit = 0;
//     *has_unit = 0;
//     switch (tex_aux_scan_unit(&num, &denom, &unit, NULL)) {
//         case normal_unit_scanned:
//             if (num) {
//                 int remainder = 0;
//                 cur_val = tex_xn_over_d_r(cur_val, num, denom, &remainder);
//                 fraction = (num * fraction + unity * remainder) / denom;
//                 cur_val += fraction / unity;
//                 fraction = fraction % unity;
//             }
//             *has_unit = 1;
//             goto FRACTION;
//         case scaled_point_scanned:
//             *has_unit = 0;
//             return value;
//         case relative_unit_scanned:
//             *has_unit = 1;
//             return tex_nx_plus_y(value, unit, tex_xn_over_d(unit, fraction, unity));
//         case quantitity_unit_scanned:
//             tex_aux_scan_something_internal(cur_cmd, cur_chr, dimension_val_level, 0, 0);
//             value = tex_nx_plus_y(value, cur_val, tex_xn_over_d(cur_val, fraction, unity));
//             *has_unit = 1;
//             return value;
//      /* case math_unit_scanned:     */ /* ignored */
//      /* case flexible_unit_scanned: */ /* ignored */
//      /* case no_unit_scanned:       */ /* nothing */
//     }
//   FRACTION:
//     if (has_fraction) {
//         *has_unit = 0;
//         if (value >= 040000) { // 0x4000
//             lmt_scanner_state.arithmic_error = 1;
//         } else {
//             value = value * unity + fraction;
//         }
//     }
//     return value;
// }

static halfword tex_scan_bit_int(int *radix)
{
    bool negative = false;
    long long result = 0;
    do {
        if (cur_tok == minus_token) {
            negative = ! negative;
            cur_tok = plus_token;
        }
    } while (cur_tok == plus_token);
    if (cur_tok == alpha_token) {
        tex_get_token();
        if (cur_tok < cs_token_flag) {
            result = cur_chr;
        } else {
            strnumber txt = cs_text(cur_tok - cs_token_flag);
            if (tex_single_letter(txt)) {
                result = aux_str2uni(str_string(txt));
            } else if (tex_is_active_cs(txt)) {
                result = active_cs_value(txt);
            } else {
                result = max_character_code + 1;
            }
        }
        if (result > max_character_code) {
            tex_aux_improper_constant_error();
            return 0;
        }
    } else if ((cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) || cur_cmd == parameter_cmd) {
        result = tex_aux_scan_something_internal(cur_cmd, cur_chr, integer_val_level, 0, 0);
        if (cur_val_level != integer_val_level) {
            tex_aux_missing_number_error(2);
            return 0;
        }
    } else {
        bool vacuous = true;
        bool ok_so_far = true;
        switch (cur_tok) {
            case octal_token:
                {
                    if (radix) {
                        *radix = 8;
                    }
                    while (1) {
                        unsigned d = 0;
                        tex_get_x_token();
                        if ((cur_tok >= zero_token) && (cur_tok <= seven_token)) {
                            d = cur_tok - zero_token;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        if (ok_so_far) {
                            result = result * 8 + d;
                            if (result > max_integer) {
                                result = max_integer;
                                tex_aux_number_to_big_error();
                                ok_so_far = false;
                            }
                        }
                    }
                 // break;
                }
            case hex_token:
                {
                    if (radix) {
                        *radix = 16;
                    }
                    while (1) {
                        unsigned d = 0;
                        tex_get_x_token();
                        if ((cur_tok >= zero_token) && (cur_tok <= nine_token)) {
                            d = cur_tok - zero_token;
                        } else if ((cur_tok >= A_token_l) && (cur_tok <= F_token_l)) {
                            d = cur_tok - A_token_l + 10;
                        } else if ((cur_tok >= A_token_o) && (cur_tok <= F_token_o)) {
                            d = cur_tok - A_token_o + 10;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        if (ok_so_far) {
                            result = result * 16 + d;
                            if (result > max_integer) {
                                result = max_integer;
                                tex_aux_number_to_big_error();
                                ok_so_far = false;
                            }
                        }
                    }
                 // break;
                }
            default:
                {
                    if (radix) {
                        *radix = 10;
                    }
                    while (1) {
                        unsigned d = 0;
                        if ((cur_tok >= zero_token) && (cur_tok <= nine_token)) {
                            d = cur_tok - zero_token;
                        } else {
                            goto DONE;
                        }
                        vacuous = false;
                        if (ok_so_far) {
                            result = result * 10 + d;
                            if (result > max_integer) {
                                result = max_integer;
                                tex_aux_number_to_big_error();
                                ok_so_far = false;
                            }
                        }
                        tex_get_x_token();
                    }
                 // break;
                }
        }
      DONE:
        if (vacuous) {
            tex_aux_missing_number_error(3);
        } else {
            tex_push_back(cur_tok, cur_cmd, cur_chr);
        }
    }
    cur_val = (halfword) (negative ? - result : result);
    return cur_val;
}

static halfword tex_scan_bit_dimension(int *has_fraction, int *has_unit)
{
    bool negative = false;
    int fraction = 0;
    *has_fraction = 0;
    *has_unit = 1;
    lmt_scanner_state.arithmic_error = 0;
    do {
        if (cur_tok == minus_token) {
            negative = ! negative;
            cur_tok = plus_token;
        }
    } while (cur_tok == plus_token);
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, integer_val_level, 0, 0);
        if (cur_val_level == dimension_val_level) {
            goto ATTACH_SIGN;
        }
    } else {
        *has_fraction = tex_token_is_seperator(cur_tok);
        if (*has_fraction) {
            /*tex We started with a |.| or |,|. */
            cur_val = 0;
        } else {
            int cur_radix = 10;
            cur_val = tex_scan_bit_int(&cur_radix);
            if (cur_radix == 10 && tex_token_is_seperator(cur_tok)) {
                *has_fraction = 1;
                tex_get_token();
            }
        }
        if (*has_fraction) {
            unsigned k = 0;
            unsigned char digits[18];
            while (1) {
                tex_get_x_token();
                if (cur_tok > nine_token || cur_tok < zero_token) {
                    break;
                } else if (k < 17) {
                    digits[k] = (unsigned char) (cur_tok - zero_token);
                    ++k;
                }
            }
            fraction = tex_round_decimals_digits(digits, k);
            if (cur_cmd != spacer_cmd) {
                /* we can avoid this when parsing a unit but not now */
                tex_back_input(cur_tok);
            }
        }
    }
    if (cur_val < 0) {
        negative = ! negative;
        cur_val = - cur_val;
    }
    cur_val = tex_aux_scan_unit_applied(cur_val, fraction, *has_fraction, has_unit);
  ATTACH_SIGN:
    if (lmt_scanner_state.arithmic_error || (abs(cur_val) >= 010000000000)) { // 0x40000000
        tex_aux_scan_dimension_out_of_range_error();
        cur_val = max_dimension;
        lmt_scanner_state.arithmic_error = 0;
    }
    if (negative) {
        cur_val = -cur_val;
    }
    return cur_val;
}

static void tex_aux_trace_expression(stack_info stack, halfword level, halfword n, int what)
{
    tex_begin_diagnostic();
    if (n > 0) {
        tex_print_format(level == dimension_val_level ? "[dimexpression rpn %i %s:" : "[numexpression rpn %i %s:", n, what ? "r" :"s");
        if (! stack.head) {
            tex_print_char(' ');
        }
    } else {
        tex_print_str(level == dimension_val_level ? "[dimexpression rpn:" : "[numexpression rpn:");
    }
    for (halfword current = stack.head; current; current = node_next(current)) {
        tex_print_char(' ');
        switch (node_subtype(current)) {
            case bit_expression_number:
                tex_print_int(scaledround((double) expression_entry(current) / factor));
                break;
            case bit_expression_float:
                tex_print_dimension(scaledround((double) expression_entry(current) / factor), no_unit);
                break;
            case bit_expression_dimension:
                tex_print_char('(');
                tex_print_dimension(scaledround((double) expression_entry(current) / factor), no_unit);
                tex_print_char(')');
                break;
            default:
                tex_print_str(bit_expression_names[expression_entry(current)]);
                break;
        }
    }
    tex_print_char(']');
    tex_end_diagnostic();
}

/* This one is not yet okay ... work in progress. We might go for posits here. */

static void tex_aux_scan_expression(int level)
{
    stack_info operators = tex_aux_new_stack();
    stack_info reverse = tex_aux_new_stack();
    stack_info stack = tex_aux_new_stack();
    halfword operation = bit_expression_none;
    bool alreadygotten = false;
    int braced = 0;
    int trace = tracing_expressions_par;
    while (1) {
        if (alreadygotten) {
            alreadygotten = false;
        } else {
            tex_get_x_token();
        }
        operation = bit_expression_none;
        switch (cur_cmd) {
            case relax_cmd:
                goto COLLECTED;
            case left_brace_cmd:
                if (! braced) {
                    braced = 1;
                    continue;
                } else {
                    goto NUMBER;
                 // goto UNEXPECTED;
                }
            case right_brace_cmd:
                if (braced) {
                    goto COLLECTED;
                } else {
                    goto NUMBER;
                 // goto UNEXPECTED;
                }
            case spacer_cmd:
                continue;
            case superscript_cmd:
                switch (cur_chr) {
                    case '^':
                        operation = bit_expression_bxor;
                        goto OKAY;
                }
                goto UNEXPECTED;
            case alignment_tab_cmd:
                switch (cur_chr) {
                    case '&':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                            case alignment_tab_cmd:
                                switch (cur_chr) {
                                    case '&':
                                        operation = bit_expression_and;
                                        goto OKAY;
                                    default:
                                        operation = bit_expression_band;
                                        alreadygotten = true;
                                        goto OKAY;
                                }
                        }
                }
                goto UNEXPECTED;
            case letter_cmd:
            case other_char_cmd:
                switch (cur_chr) {
                    case '(':
                        tex_push_stack_entry(&operators, bit_expression_open);
                        continue;
                    case ')':
                        while (operators.tail && expression_entry(operators.tail) != bit_expression_open) {
                            tex_move_stack_entry(&reverse, &operators);
                        }
                        tex_pop_stack_entry(&operators);
                        continue;
                    case '+':
                        operation = bit_expression_add;
                        break;
                    case '-':
                        operation = bit_expression_subtract;
                        break;
                    case '*':
                        operation = bit_expression_multiply;
                        break;
                    case '/':
                    case ':':
                        operation = bit_expression_divide;
                        break;
                    case '%':
                    case ';':
                        operation = bit_expression_mod;
                        break;
                    case '&':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                            case alignment_tab_cmd:
                                switch (cur_chr) {
                                    case '&':
                                        operation = bit_expression_and;
                                        goto OKAY;
                                }
                        }
                        operation = bit_expression_band;
                        alreadygotten = true;
                        break;
                    case '^':
                        operation = bit_expression_bxor;
                        break;
                    case 'v':
                        operation = bit_expression_bor;
                        break;
                    case '|':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                                switch (cur_chr) {
                                    case '|':
                                        operation = bit_expression_or;
                                        goto OKAY;
                                }
                        }
                        operation = bit_expression_bor;
                        alreadygotten = true;
                        break;
                    case '<':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                                switch (cur_chr) {
                                    case '<':
                                        operation = bit_expression_bleft;
                                        goto OKAY;
                                    case '=':
                                        operation = bit_expression_lessequal;
                                        goto OKAY;
                                    case '>':
                                        operation = bit_expression_unequal;
                                        goto OKAY;
                                }
                        }
                        operation = bit_expression_less;
                        alreadygotten = true;
                        break;
                    case '>':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                                switch (cur_chr) {
                                    case '>':
                                        operation = bit_expression_bright;
                                        goto OKAY;
                                    case '=':
                                        operation = bit_expression_moreequal;
                                        goto OKAY;
                                }
                        }
                        operation = bit_expression_more;
                        alreadygotten = true;
                        break;
                    case '=':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                                switch (cur_chr) {
                                    case '=':
                                        break;
                                    default:
                                        alreadygotten = true;
                                        break;
                                }
                        }
                        operation = bit_expression_equal;
                        break;
                    case '~': case '!':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd:
                            case other_char_cmd:
                                switch (cur_chr) {
                                    case '=':
                                        operation = bit_expression_unequal;
                                        goto OKAY;
                                }
                        }
                        operation = bit_expression_not;
                        alreadygotten = true;
                        break;
                    case 'm': case 'M':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'o': case 'O':
                                tex_get_x_token();
                                switch (cur_cmd) {
                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'd': case 'D':
                                        operation = bit_expression_mod;
                                        goto OKAY;
                                    }
                                }
                            }
                        }
                        goto UNEXPECTED;
                    case 'n': case 'N':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'o': case 'O':
                                tex_get_x_token();
                                switch (cur_cmd) {
                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'o': case 'T':
                                        operation = bit_expression_not;
                                        goto OKAY;
                                    }
                                }
                            }
                        }
                        goto UNEXPECTED;
                    case 'a': case 'A':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'n': case 'N':
                                tex_get_x_token();
                                switch (cur_cmd) {
                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'd': case 'D':
                                        operation = bit_expression_and;
                                        goto OKAY;
                                    }
                                }
                            }
                        }
                        goto UNEXPECTED;
                    case 'b': case 'B':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd: case other_char_cmd:
                                switch (cur_chr) {
                                    case 'a': case 'A':
                                        tex_get_x_token();
                                        switch (cur_cmd) {
                                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'n': case 'N':
                                                tex_get_x_token();
                                                switch (cur_cmd) {
                                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'd': case 'D':
                                                        operation = bit_expression_band;
                                                        goto OKAY;
                                                    }
                                                }
                                            }
                                        }
                                        break;
                                    case 'o': case 'O':
                                        tex_get_x_token();
                                        switch (cur_cmd) {
                                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'r': case 'R':
                                                operation = bit_expression_bor;
                                                goto OKAY;
                                            }
                                        }
                                        break;
                                    case 'x': case 'X':
                                        tex_get_x_token();
                                        switch (cur_cmd) {
                                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'o': case 'O':
                                                tex_get_x_token();
                                                switch (cur_cmd) {
                                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'r': case 'R':
                                                        operation = bit_expression_bxor;
                                                        goto OKAY;
                                                    }
                                                }
                                            }
                                        }
                                        break;
                                    case 's': case 'S':
                                        tex_get_x_token();
                                        switch (cur_cmd) {
                                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'e': case 'S':
                                                tex_get_x_token();
                                                switch (cur_cmd) {
                                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 't': case 'T':
                                                        operation = bit_expression_bset;
                                                        goto OKAY;
                                                    }
                                                }
                                            }
                                        }
                                        break;
                                    case 'r': case 'R':
                                        tex_get_x_token();
                                        switch (cur_cmd) {
                                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'e': case 'E':
                                                tex_get_x_token();
                                                switch (cur_cmd) {
                                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 's': case 'S':
                                                        tex_get_x_token();
                                                        switch (cur_cmd) {
                                                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'e': case 'S':
                                                                tex_get_x_token();
                                                                switch (cur_cmd) {
                                                                    case letter_cmd: case other_char_cmd: switch (cur_chr) { case 't': case 'T':
                                                                        operation = bit_expression_bset;
                                                                        goto OKAY;
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        break;
                                }
                        }
                        goto UNEXPECTED;
                    case 'o': case 'O':
                        tex_get_x_token();
                        switch (cur_cmd) {
                            case letter_cmd: case other_char_cmd: switch (cur_chr) { case 'r': case 'R':
                                operation = bit_expression_or;
                                goto OKAY;
                            }
                        }
                        goto UNEXPECTED;
                    default:
                        goto NUMBER;
                }
              OKAY:
                while (operators.tail && bit_operator_precedence[expression_entry(operators.tail)] >= bit_operator_precedence[operation]) {
                 // tex_push_stack_entry(&reverse, tex_pop_stack_entry(&operators));
                    tex_move_stack_entry(&reverse, &operators);
                }
                tex_push_stack_entry(&operators, operation);
                break;
            default:
              NUMBER:
                /*tex These use |cur_tok|: */
                {
                    int has_fraction = 0;
                    int has_unit = 1;
                    operation = level == dimension_val_level ? tex_scan_bit_dimension(&has_fraction, &has_unit) : tex_scan_bit_int(NULL);
                    tex_push_stack_entry(&reverse, operation * factor);
                    if (level == dimension_val_level && has_unit) {
                        node_subtype(reverse.tail) = bit_expression_dimension;
                    } else if (has_fraction) {
                        node_subtype(reverse.tail) = bit_expression_float;
                    } else {
                        node_subtype(reverse.tail) = bit_expression_number;
                    }
                    continue;
                }
        }
    }
  COLLECTED:
    while (operators.tail) {
        tex_move_stack_entry(&reverse, &operators);
    }
    /*tex This is the reference: */
    /*
    {
        halfword current = reverse.head;
        while (current) {
            if (node_subtype(current) == bit_expression_number) {
                tex_push_stack_entry(&stack, expression_entry(current));
            } else {
                halfword token = expression_entry(current);
                long long v;
                if (token == bit_expression_not) {
                    v = ~ (long long) tex_pop_stack_entry(&stack);
                } else {
                    long long b = (long long) tex_pop_stack_entry(&stack);
                    long long a = (long long) tex_pop_stack_entry(&stack);
                    switch (token) {
                       // calculations, see below
                    }
                }
                // checks, see below
                tex_push_stack_entry(&stack, (halfword) v);
            }
            current = node_next(current);
        }
    }
    */
    if (trace == 1) {
        tex_aux_trace_expression(reverse, level, 0, 0);
    }
    {
        halfword current = reverse.head;
        int step = 0;
        while (current) {
            halfword next = node_next(current);
            halfword subtype = node_subtype(current);
            if (trace > 1) {
                step = step + 1;
                tex_aux_trace_expression(reverse, level, step, 0);
                tex_aux_trace_expression(stack, level, step, 1);
            }
            switch (subtype) {
                case bit_expression_number:
                case bit_expression_float:
                case bit_expression_dimension:
                    tex_take_stack_entry(&stack, &reverse, current);
                    break;
                default:
                    {
                        halfword token = (halfword) expression_entry(current);
                        long long v = 0;
                        if (token == bit_expression_not) {
                            v =~ stack.tail ? expression_entry(stack.tail) : 0;
                        } else {
                            quarterword sa, sb;
                            long long va, vb;
                            sb = node_subtype(stack.tail);
                            vb = tex_pop_stack_entry(&stack);
                            if (stack.tail) {
                                sa = node_subtype(stack.tail);
                                va = expression_entry(stack.tail);
                            } else {
                                sa = bit_expression_number;
                                va = 0;
                            }
                            switch (token) {
                                case bit_expression_bor:
                                    v = va | vb;
                                    break;
                                case bit_expression_band:
                                    v = va & vb;
                                    break;
                                case bit_expression_bxor:
                                    v = va ^ vb;
                                    break;
                                case bit_expression_bset:
                                    v = va | ((long long) 1 << (vb - 1));
                                    break;
                                case bit_expression_bunset:
                                    v = va & ~ ((long long) 1 << (vb - 1));
                                    break;
                                case bit_expression_bleft:
                                    v = va << vb;
                                    break;
                                case bit_expression_bright:
                                    v = va >> vb;
                                    break;
                                case bit_expression_less:
                                    v = va < vb;
                                    break;
                                case bit_expression_lessequal:
                                    v = va <= vb;
                                    break;
                                case bit_expression_equal:
                                    v = va == vb;
                                    break;
                                case bit_expression_moreequal:
                                    v = va >= vb;
                                    break;
                                case bit_expression_more:
                                    v = va > vb;
                                    break;
                                case bit_expression_unequal:
                                    v = va != vb;
                                    break;
                                case bit_expression_add:
                                    v = va + vb;
                                    break;
                                case bit_expression_subtract:
                                    v = va - vb;
                                    break;
                                case bit_expression_multiply:
                                    {
                                        double d = (double) va * (double) vb;
                                        if (sa == bit_expression_float) {
                                            d = d / (65536 * factor);
                                        } else if (sb == bit_expression_float) {
                                            d = d / (65536 * factor);
                                        } else {
                                            d = d / factor;
                                        }
                                        if (sa == bit_expression_dimension || sb == bit_expression_dimension) {
                                            node_subtype(stack.tail) = bit_expression_dimension;
                                        }
                                        v = longlonground(d);
                                    }
                                    break;
                                case bit_expression_divide:
                                    if (vb) {
                                        double d = (double) va / (double) vb;
                                        if (sa == bit_expression_float) {
                                        // d = d / (65536 * factor);
                                           d = d * (65536 * factor);
                                        } else if (sb == bit_expression_float) {
                                         // d = d / (65536 * factor);
                                            d = d * (65536 * factor);
                                        } else {
                                            d = d * factor;
                                        }
                                        if (sa == bit_expression_dimension || sb == bit_expression_dimension) {
                                            node_subtype(stack.tail) = bit_expression_dimension;
                                        }
                                        v = longlonground(d);
                                    } else {
                                        goto ZERO;
                                    }
                                    break;
                                case bit_expression_mod:
                                    v =  va % vb;
                                    break;
                                case bit_expression_or:
                                    v = (va || vb) ? 1 : 0;
                                    break;
                                case bit_expression_and:
                                    v = (va && vb) ? 1 : 0;
                                    break;
                                default:
                                    v = 0;
                                    break;
                            }
                        }
                        if (v < min_integer) {
                            v = min_integer;
                        } else if (v > max_integer) {
                            v = max_integer;
                        }
                        expression_entry(stack.tail) = v;
                        break;
                    }
            }
            current = next;
        }
    }
    goto DONE;
  ZERO:
    tex_handle_error(
        back_error_type,
        "I can't divide by zero",
        "I was expecting to see a nonzero number. Didn't."
    );
    goto DONE;
  UNEXPECTED:
    tex_handle_error(
        back_error_type,
        "Premature end of bit expression",
        "I was expecting to see an integer or bitwise operator. Didn't."
    );
  DONE:
    cur_val = scaledround(((double) expression_entry(stack.tail)) / factor);
    cur_val_level = level;
    tex_aux_dispose_stack(&stack);
    tex_aux_dispose_stack(&reverse);
    tex_aux_dispose_stack(&operators);
}

int tex_scanned_expression(int level)
{
    tex_aux_scan_expression(level);
    return cur_val;
}

/*tex
    We used to only scale by 1000 when we had a fraction but that is kind of fuzzy so now we always
    assume a fraction.
*/

halfword tex_scan_scale(int optional_equal)
{
    bool negative = false;
    lmt_scanner_state.arithmic_error = 0;
    do {
        while (1) {
            tex_get_x_token();
            if (cur_cmd != spacer_cmd) {
                if (optional_equal && (cur_tok == equal_token)) {
                    optional_equal = 0;
                } else {
                    break;
                }
            }
        }
        if (cur_tok == minus_token) {
            negative = ! negative;
            cur_tok = plus_token;
        }
    } while (cur_tok == plus_token);
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, integer_val_level, 0, 0);
    } else {
        int has_fraction = tex_token_is_seperator(cur_tok);
        if (has_fraction) {
            cur_val = 0;
        } else {
            int cur_radix;
            tex_back_input(cur_tok);
            cur_val = tex_scan_integer(0, &cur_radix);
            tex_get_token();
            if (cur_radix == 10 && tex_token_is_seperator(cur_tok)) {
                has_fraction = 1;
            }
        }
        cur_val = cur_val * 1000;
        if (has_fraction) {
            unsigned k = 4;
            while (1) {
                tex_get_x_token();
                if (cur_tok < zero_token || cur_tok > nine_token) {
                    break;
                } else if (k == 1) {
                    /* rounding */
                    if (cur_tok >= five_token && cur_tok <= nine_token) {
                        cur_val += 1;
                    }
                    --k;
                } else if (k) {
                    cur_val = cur_val + (k == 4 ? 100 : (k == 3 ? 10 : 1)) * (cur_tok - zero_token);
                    --k;
                }
            }
        }
        tex_push_back(cur_tok, cur_cmd, cur_chr);
    }
    if (negative) {
        cur_val = -cur_val;
    }
    if (lmt_scanner_state.arithmic_error || (abs(cur_val) >= 0x40000000)) {
     // scan_dimension_out_of_range_error();
        cur_val = max_dimension;
        lmt_scanner_state.arithmic_error = 0;
    }
    return cur_val;
}

/* todo: share with lmttokenlib.scan_float */

# define max_posit_size 60

halfword tex_scan_posit(int optional_equal)
{
    int hexadecimal = 1;
    int exponent = 1;
    bool negative = false;
    int b = 0;
    char buffer[max_posit_size+4] = { 0 };
    do {
        while (1) {
            tex_get_x_token();
            if (cur_cmd != spacer_cmd) {
                if (optional_equal && (cur_tok == equal_token)) {
                    optional_equal = 0;
                } else {
                    break;
                }
            }
        }
        if (cur_tok == minus_token) {
            negative = ! negative;
            cur_tok = plus_token;
        }
    } while (cur_tok == plus_token);
    if (cur_cmd >= min_internal_cmd && cur_cmd <= max_internal_cmd) {
        cur_val = tex_aux_scan_something_internal(cur_cmd, cur_chr, posit_val_level, 0, 0);
    } else {
        if (negative) {
            buffer[b++] = '-';
        }
        /*tex we accept |[.,]digits| */
        if (hexadecimal && (cur_tok == zero_token)) {
            buffer[b++] = '0';
            tex_get_x_token();
            if (tex_token_is_hexadecimal(cur_tok)) {
                buffer[b++] = 'x';
                goto SCANHEXADECIMAL;
            } else {
                goto PICKUPDECIMAL;
            }
        } else {
            goto SCANDECIMAL;
        }
      SCANDECIMAL:
        if (tex_token_is_seperator(cur_tok)) {
            buffer[b++] = '.';
            while (1) {
                tex_get_x_token();
                if (tex_token_is_digit(cur_tok)) {
                    buffer[b++] = (unsigned char) cur_chr;
                } else if (exponent) {
                    goto DECIMALEXPONENT;
                } else {
                    tex_back_input(cur_tok);
                    goto DONE;
                }
                if (b >= 60) {
                    goto TOOBIG;
                }
            }
        } else {
            goto PICKUPDECIMAL;
        }
        while (1) {
            tex_get_x_token();
          PICKUPDECIMAL:
            if (tex_token_is_digit(cur_tok)) {
                buffer[b++] = (unsigned char) cur_chr;
            } else if (tex_token_is_seperator(cur_tok)) {
                buffer[b++] = '.';
                while (1) {
                    tex_get_x_token();
                    if (tex_token_is_digit(cur_tok)) {
                        buffer[b++] = (unsigned char) cur_chr;
                    } else {
                        tex_back_input(cur_tok);
                        break;
                    }
                }
            } else if (exponent) {
                goto DECIMALEXPONENT;
            } else {
                tex_back_input(cur_tok);
                goto DONE;
            }
            if (b >= max_posit_size) {
                goto TOOBIG;
            }
        }
      DECIMALEXPONENT:
        if (tex_token_is_exponent(cur_tok)) {
            buffer[b++] = (unsigned char) cur_chr;
            tex_get_x_token();
            if (tex_token_is_sign(cur_tok)) {
                buffer[b++] = (unsigned char) cur_chr;
            } else if (tex_token_is_digit(cur_tok)) {
                buffer[b++] = (unsigned char) cur_chr;
            }
            while (1) {
                tex_get_x_token();
                if (tex_token_is_digit(cur_tok)) {
                    buffer[b++] = (unsigned char) cur_chr;
                } else {
                    break;
                }
                if (b >= max_posit_size) {
                    goto TOOBIG;
                }
            }
        }
        tex_back_input(cur_tok);
        goto DONE;
      SCANHEXADECIMAL:
        tex_get_x_token();
        if (tex_token_is_seperator(cur_tok)) {
            buffer[b++] = '.';
            while (1) {
                tex_get_x_token();
                if (tex_token_is_xdigit(cur_tok)) {
                    buffer[b++] = (unsigned char) cur_chr;
                } else if (exponent) {
                    goto HEXADECIMALEXPONENT;
                } else {
                    tex_back_input(cur_tok);
                    goto DONE;
                }
                if (b >= max_posit_size) {
                    goto TOOBIG;
                }
            }
        } else {
            /* hm, we could avoid this pushback */
            tex_back_input(cur_tok);
            while (1) {
                tex_get_x_token();
                if (tex_token_is_xdigit(cur_tok)) {
                    buffer[b++] = (unsigned char) cur_chr;
                } else if (tex_token_is_seperator(cur_tok)) {
                    buffer[b++] = '.';
                    while (1) {
                        tex_get_x_token();
                        if (tex_token_is_xdigit(cur_tok)) {
                            buffer[b++] = (unsigned char) cur_chr;
                        } else {
                            tex_back_input(cur_tok);
                            break;
                        }
                    }
                } else if (exponent) {
                    goto HEXADECIMALEXPONENT;
                } else {
                    tex_back_input(cur_tok);
                    goto DONE;
                }
                if (b >= max_posit_size) {
                    goto TOOBIG;
                }
            }
        }
      HEXADECIMALEXPONENT:
        if (tex_token_is_xexponent(cur_tok)) {
            buffer[b++] = (unsigned char) cur_chr;
            tex_get_x_token();
            if (tex_token_is_sign(cur_tok)) {
                buffer[b++] = (unsigned char) cur_chr;
            } else if (tex_token_is_xdigit(cur_tok)) {
                buffer[b++] = (unsigned char) cur_chr;
            }
            while (1) {
                tex_get_x_token();
                if (tex_token_is_xdigit(cur_tok)) {
                    buffer[b++] = (unsigned char) cur_chr;
                } else {
                    break;
                }
                if (b >= max_posit_size) {
                    goto TOOBIG;
                }
            }
        }
        tex_back_input(cur_tok);
      DONE:
        if (b) {
            double d = strtod(buffer, NULL);
            cur_val = tex_double_to_posit(d).v;
            return cur_val;
        } else {
            tex_aux_missing_number_error(4);
        }
      TOOBIG:
        cur_val = tex_integer_to_posit(0).v;
    }
    return cur_val;
}

int tex_scan_tex_value(halfword level, halfword *value)
{
    tex_aux_scan_expr(level);
    *value = cur_val;
    return 1;
}

quarterword tex_scan_direction(int optional_equal)
{
    int i = tex_scan_integer(optional_equal, NULL);
    return (quarterword) checked_direction_value(i);
}

halfword tex_scan_geometry(int optional_equal)
{
    int i = tex_scan_integer(optional_equal, NULL);
    return checked_geometry_value(i);
}

halfword tex_scan_orientation(int optional_equal)
{
    halfword i = tex_scan_integer(optional_equal, NULL);
    return checked_orientation_value(i);
}

halfword tex_scan_anchor(int optional_equal)
{
    halfword a = tex_scan_integer(optional_equal, NULL);
    halfword l = (a >> 16) & 0xFFFF;
    halfword r =  a        & 0xFFFF;
    return (checked_anchor_value(l) << 16) + checked_anchor_value(r);
}

halfword tex_scan_anchors(int optional_equal)
{
    halfword l = tex_scan_integer(optional_equal, NULL) & 0xFFFF;
    halfword r = tex_scan_integer(0, NULL)              & 0xFFFF;
    return (checked_anchor_value(l) << 16) + checked_anchor_value(r);
}

halfword tex_scan_attribute(halfword attrlist)
{
    halfword i = tex_scan_attribute_register_number();
    halfword v = tex_scan_integer(1, NULL);
    if (eq_value(register_attribute_location(i)) != v) {
        if (attrlist) {
            attrlist = tex_patch_attribute_list(attrlist, i, v);
        } else {
            attrlist = tex_copy_attribute_list_set(tex_current_attribute_list(), i, v);
        }
    }
    return attrlist;
}

halfword tex_scan_extra_attribute(halfword attrlist)
{
    halfword i = tex_scan_attribute_register_number();
    halfword v = tex_scan_integer(1, NULL);
    if (attrlist) {
        attrlist = tex_patch_attribute_list(attrlist, i, v);
    } else {
        attrlist = tex_copy_attribute_list_set(null, i, v);
    }
    return attrlist;
}
