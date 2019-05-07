/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    We consider now the way \TEX\ handles various kinds of |\if| commands.

    Conditions can be inside conditions, and this nesting has a stack that is
    independent of the |save_stack|.

    Four global variables represent the top of the condition stack: |cond_ptr|
    points to pushed-down entries, if any; |if_limit| specifies the largest code
    of a |fi_or_else| command that is syntactically legal; |cur_if| is the name
    of the current type of conditional; and |if_line| is the line number at which
    it began.

    If no conditions are currently in progress, the condition stack has the
    special state |cond_ptr = null|, |if_limit = normal|, |cur_if = 0|, |if_line
    = 0|. Otherwise |cond_ptr| points to a two-word node; the |type|, |subtype|,
    and |link| fields of the first word contain |if_limit|, |cur_if|, and
    |cond_ptr| at the next level, and the second word contains the corresponding
    |if_line|.

    In |cond_ptr| we keep track of the top of the condition stack while
    |if_limit| holds the upper bound on |fi_or_else| codes. The type of
    conditional being worked on is stored in cur_if and |if_line| keeps track of
    the line where that conditional began. When we skip conditional text,
    |skip_line| keeps track of the line number where skipping began, for use in
    error messages.

    All these variables are collected in:

*/

condition_state_info condition_state ;

/*tex

    Here is a procedure that ignores text until coming to an |\or|, |\else|, or
    |\fi| at level zero of |\if|\unknown|\fi| nesting. After it has acted,
    |cur_chr| will indicate the token that was found, but |cur_tok| will not be
    set (because this makes the procedure run faster).

    With |l| we keep track of the level of |\if|\unknown|\fi| nesting and
    |scanner_status| let us return to the entry status.

*/

void pass_text(void)
{
    int l = 0;
    int save_scanner_status = scanner_status;
    scanner_status = skipping;
    skip_line = input_line;
    while (1) {
        get_next();
        if (cur_cmd == fi_or_else_cmd) {
            if (l == 0) {
                break;
            } else if (cur_chr == fi_code) {
                decr(l);
            }
        } else if (cur_cmd == if_test_cmd) {
            incr(l);
        }
    }
    scanner_status = save_scanner_status;
    if (tracing_ifs_par > 0)
        show_cur_cmd_chr();
}

/*tex

When we begin to process a new |\if|, we set |if_limit:=if_code|; then if\/ |\or|
or |\else| or |\fi| occurs before the current |\if| condition has been evaluated,
|\relax| will be inserted. For example, a sequence of commands like |\ifvoid 1
\else ... \fi| would otherwise require something after the |1|.

*/

void push_condition_stack(void)
{
    halfword p = get_node(if_node_size);
    type(p) = if_node;
    subtype(p) = 0;
    vlink(p) = cond_ptr;
    if_limit_type(p) = (quarterword) if_limit;
    if_limit_subtype(p) = (quarterword) cur_if;
    if_line_field(p) = if_line;
    cond_ptr = p;
    cur_if = cur_chr;
    if_limit = if_code;
    if_line = input_line;
}

void pop_condition_stack(void)
{
    halfword p;
    if (if_stack[in_open] == cond_ptr) {
        /*tex Conditionals are possibly not properly nested with files. */
        if_warning();
    }
    p = cond_ptr;
    if_line = if_line_field(p);
    cur_if = if_limit_subtype(p);
    if_limit = if_limit_type(p);
    cond_ptr = vlink(p);
    free_node(p,if_node_size);
}

/*tex

Here's a procedure that changes the |if_limit| code corresponding to a given
value of |cond_ptr|.

*/

void change_if_limit(int l, halfword p)
{
    if (p == cond_ptr) {
        if_limit = l;
    } else {
        halfword q = cond_ptr;
        while (1) {
            if (q == null)
                confusion("if");
            if (vlink(q) == p) {
                if_limit_type(q) = (quarterword) l;
                return;
            }
            q = vlink(q);
        }
    }
}

/*tex

    The conditional|\ifcsname| is equivalent to |\expandafter| |\expandafter|
    |\ifdefined| |\csname|, except that no new control sequence will be entered
    into the hash table (once all tokens preceding the mandatory |\endcsname|
    have been expanded).

*/

// static int test_for_cs(void)
// {
//     /*tex Is the condition true? */
//     int b = 0;
//     /*tex To be tested against the second operand: */
//     int m;
//     /*tex For traversing token lists in |\ifx| tests: */
//     halfword p, q, n;
//     fast_get_avail(n);
//     /*tex Head of the list of characters: */
//     p = n;
//     expand_state.is_in_csname += 1;
//     while (1) {
//         get_x_token();
//         if (cur_cs) {
//            break;
//         } else {
//          // store_new_token(cur_tok);
//             fast_store_new_token(cur_tok); /* multiline macro */
//         }
//     }
//     if (cur_cmd != end_cs_name_cmd) {
//         last_tested_cs = null_cs;
//         if (suppress_ifcsname_error_par) {
//             do {
//                 get_x_token();
//             } while (cur_cmd != end_cs_name_cmd);
//             flush_list(n);
//             expand_state.is_in_csname -= 1;
//             return b;
//         } else {
//             complain_missing_csname();
//         }
//     }
//     /*tex Look up the characters of list |n| in the hash table, and set |cur_cs|. */
//     m = iofirst;
//     p = token_link(n);
//     while (p) {
//         int s = token_chr(token_info(p));
//         if (m >= max_buf_stack) {
//             max_buf_stack = m + 4;
//             if (max_buf_stack >= main_state.buf_size)
//                 check_buffer_overflow(max_buf_stack);
//         }
//         if (s <= 0x7F) {
//             iobuffer[m++] = (unsigned char) s;
//         } else if (s <= 0x7FF) {
//             iobuffer[m++] = (unsigned char) (0xC0 + s / 0x40);
//             iobuffer[m++] = (unsigned char) (0x80 + s % 0x40);
//         } else if (s <= 0xFFFF) {
//             iobuffer[m++] = (unsigned char) (0xE0 +  s / 0x1000);
//             iobuffer[m++] = (unsigned char) (0x80 + (s % 0x1000) / 0x40);
//             iobuffer[m++] = (unsigned char) (0x80 + (s % 0x1000) % 0x40);
//         } else {
//             iobuffer[m++] = (unsigned char) (0xF0 +   s / 0x40000);
//             iobuffer[m++] = (unsigned char) (0x80 + ( s % 0x40000) / 0x1000);
//             iobuffer[m++] = (unsigned char) (0x80 + ((s % 0x40000) % 0x1000) / 0x40);
//             iobuffer[m++] = (unsigned char) (0x80 + ((s % 0x40000) % 0x1000) % 0x40);
//         }
//         p = token_link(p);
//     }
//     if (m > iofirst) {
//         /*tex |no_new_control_sequence| is |true| */
//         cur_cs = id_lookup(iofirst, m - iofirst);
//     } else {
//         /*tex the list is empty */
//         cur_cs = null_cs;
//     }
//     b = (eq_type(cur_cs) != undefined_cs_cmd);
//     flush_list(n);
//     last_cs_name = cur_cs;
//     expand_state.is_in_csname -= 1;
//     return b;
// }

static int test_for_cs(void)
{
    /*tex Is the condition true? */
    int b = 0;
    /*tex number of tokens */
    int t = 0;
    /*tex For traversing token lists in |\ifx| tests: */
    halfword p, q, n;
    fast_get_avail(n);
    /*tex Head of the list of characters: */
    p = n;
    expand_state.is_in_csname += 1;
    while (1) {
        get_x_token();
        if (cur_cs) {
            break;
        } else {
             t++;
         // store_new_token(cur_tok);
            fast_store_new_token(cur_tok); /* multiline macro */
        }
    }
    if (cur_cmd != end_cs_name_cmd) {
        last_tested_cs = null_cs;
        if (suppress_ifcsname_error_par) {
            do {
                get_x_token();
            } while (cur_cmd != end_cs_name_cmd);
        } else {
            complain_missing_csname();
        }
        cur_cs = null_cs;
    } else if (t) {
        /*tex Look up the characters of list |n| in the hash table, and set |cur_cs|. */
        int m = iofirst;
        /*tex We just check once. */
        if ((m + t*4) >= max_buf_stack) {
            max_buf_stack = m + t*4;
            if (max_buf_stack >= main_state.buf_size)
                check_buffer_overflow(max_buf_stack);
        }
        /* */
        p = token_link(n);
        while (p) {
            int s = token_chr(token_info(p));
            if (s <= 0x7F) {
                iobuffer[m++] = (unsigned char) s;
            } else if (s <= 0x7FF) {
                iobuffer[m++] = (unsigned char) (0xC0 + s / 0x40);
                iobuffer[m++] = (unsigned char) (0x80 + s % 0x40);
            } else if (s <= 0xFFFF) {
                iobuffer[m++] = (unsigned char) (0xE0 +  s / 0x1000);
                iobuffer[m++] = (unsigned char) (0x80 + (s % 0x1000) / 0x40);
                iobuffer[m++] = (unsigned char) (0x80 + (s % 0x1000) % 0x40);
            } else {
                iobuffer[m++] = (unsigned char) (0xF0 +   s / 0x40000);
                iobuffer[m++] = (unsigned char) (0x80 + ( s % 0x40000) / 0x1000);
                iobuffer[m++] = (unsigned char) (0x80 + ((s % 0x40000) % 0x1000) / 0x40);
                iobuffer[m++] = (unsigned char) (0x80 + ((s % 0x40000) % 0x1000) % 0x40);
            }
            p = token_link(p);
        }
        /*tex |no_new_control_sequence| is |true| */
        cur_cs = id_lookup(iofirst, m - iofirst);
        b = (eq_type(cur_cs) != undefined_cs_cmd);
    } else {
        /*tex the list is empty */
        cur_cs = null_cs;
    }
    flush_list(n);
    last_cs_name = cur_cs;
    expand_state.is_in_csname -= 1;
    return b;
}

/*tex

    An active character will be treated as category 13 following |\if \noexpand|
    or following |\ifcat \noexpand|.

*/

#define get_x_token_or_active_char() do { \
    get_x_token(); \
    if (cur_cmd==relax_cmd && cur_chr==no_expand_flag && is_active_cs(cs_text(cur_cs))) { \
        cur_cmd=active_char_cmd; \
        cur_chr=active_cs_value(cs_text(cur_tok-cs_token_flag)); \
    } \
} while (0)

/*tex

    A condition is started when the |expand| procedure encounters an |if_test|
    command; in that case |expand| reduces to |conditional|, which is a recursive
    procedure.

*/

static void missing_equal_error(int this_if)
{
    print_err("Missing = inserted for ");
    print_cmd_chr(if_test_cmd, this_if);
    help(
        "I was expecting to see `<', `=', or `>'. Didn't."
    );
}

void conditional(void)
{
    /*tex Is the condition true? */
    int result = 0;
    /*tex To be tested against the second operand: */
    int case_value;
    /*tex The |cond_ptr| corresponding to this conditional: */
    halfword save_cond_ptr;
    /*tex The type of this conditional: */
    int this_if;
    /*tex Was this |\if| preceded by |\unless|? */
    int is_unless;
    if ((tracing_ifs_par > 0) && (tracing_commands_par <= 1)) {
        show_cur_cmd_chr();
    }
    push_condition_stack();
    save_cond_ptr = cond_ptr;
    is_unless = (cur_chr >= unless_code);
    this_if = cur_chr % unless_code;
    /*tex Either process |\ifcase| or set |b| to the value of a boolean condition. */
    switch (this_if) {
        case if_char_code:
        case if_cat_code:
            /*tex Test if two characters match. */
            {
                halfword n, m;
                get_x_token_or_active_char();
                if ((cur_cmd > active_char_cmd) || (cur_chr > biggest_char)) {
                    /*tex It's not a character. */
                    m = relax_cmd;
                    n = too_big_char;
                } else {
                    m = cur_cmd;
                    n = cur_chr;
                }
                get_x_token_or_active_char();
                if ((cur_cmd > active_char_cmd) || (cur_chr > biggest_char)) {
                    cur_cmd = relax_cmd;
                    cur_chr = too_big_char;
                }
                if (this_if == if_char_code)
                    result = (n == cur_chr);
                else
                    result = (m == cur_cmd);
            }
            break;
        case if_abs_int_code:
        case if_int_code:
            /*tex
                Test the relation between integers or dimensions. Here we use the fact
                that |<|, |=|, and |>| are consecutive ASCII codes.
            */
            {
                halfword n, r;
                scan_int(0);
                n = cur_val;
                if ((n < 0) && (this_if == if_abs_int_code))
                    negate(n);
                /*tex Get the next non-blank non-call... */
                do {
                    get_x_token();
                } while (cur_cmd == spacer_cmd);
                r = cur_tok - other_token;
                if ((r < '<') || (r > '>')) {
                    missing_equal_error(this_if);
                    back_error();
                    r = '=';
                }
                scan_int(0);
                if ((cur_val < 0) && (this_if == if_abs_int_code))
                    negate(cur_val);
                switch (r) {
                    case '<':
                        result = (n < cur_val);
                        break;
                    case '=':
                        result = (n == cur_val);
                        break;
                    case '>':
                        result = (n > cur_val);
                        break;
                    default:
                        /*tex This can't happen. */
                        result = 0;
                        break;
                }
            }
            break;
        case if_abs_dim_code:
        case if_dim_code:
            /*tex
                Test the relation between integers or dimensions. Here we use the fact
                that |<|, |=|, and |>| are consecutive ASCII codes.
            */
            {
                halfword n, r;
                scan_normal_dimen(0);
                n = cur_val;
                if ((n < 0) && (this_if == if_abs_dim_code)) {
                    /*tex first value */
                    negate(n);
                }
                /*tex Get the next non-blank non-call... */
                do {
                    get_x_token();
                } while (cur_cmd == spacer_cmd);
                r = cur_tok - other_token;
                if ((r < '<') || (r > '>')) {
                    missing_equal_error(this_if);
                    back_error();
                    r = '=';
                }
                scan_normal_dimen(0);
                if ((cur_val < 0) && (this_if == if_abs_dim_code)) {
                    /*tex second value */
                    negate(cur_val);
                }
                switch (r) {
                    case '<':
                        result = (n < cur_val);
                        break;
                    case '=':
                        result = (n == cur_val);
                        break;
                    case '>':
                        result = (n > cur_val);
                        break;
                    default:
                        break;
                }
            }
            break;
        case if_odd_code:
            /*tex Test if an integer is odd. */
            scan_int(0);
            result = odd(cur_val);
            break;
        case if_vmode_code:
            result = (abs(cur_list.mode_field) == vmode);
            break;
        case if_hmode_code:
            result = (abs(cur_list.mode_field) == hmode);
            break;
        case if_mmode_code:
            result = (abs(cur_list.mode_field) == mmode);
            break;
        case if_inner_code:
            result = (cur_list.mode_field < 0);
            break;
        case if_void_code:
            {
                scan_register_num();
                result = (box(cur_val) == null);
            }
            break;
        case if_hbox_code:
            {
                halfword p;
                scan_register_num();
                p = box(cur_val);
                result = (p != null) && (type(p) == hlist_node);
            }
            break;
        case if_vbox_code:
            {
                halfword p;
                scan_register_num();
                p = box(cur_val);
                result = (p != null) && (type(p) == vlist_node);
            }
            break;
        case if_tok_code:
            {
                halfword pp = -1;
                halfword qq = -1;
                halfword p, q;
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                do {
                    get_x_token();
                } while (cur_cmd == spacer_cmd && cur_cmd == relax_cmd);
                if (cur_cmd == left_brace_cmd) {
                    scan_toks(0,1,1);
                    p = def_ref;
                    pp = p;
                } else if (cur_cmd == assign_toks_cmd) {
                    p = toks(equiv(cur_cs) - toks_base);
                } else if (cur_cmd == toks_register_cmd) {
                    scan_register_num();
                    p = equiv(toks_base + cur_val);
                } else {
                    back_input();
                    scan_register_num();
                    p = equiv(toks_base + cur_val);
                }
                do {
                    get_x_token();
                } while (cur_cmd == spacer_cmd || cur_cmd == relax_cmd);
                if (cur_cmd == left_brace_cmd) {
                    scan_toks(0,1,1);
                    q = def_ref;
                    qq = q;
                } else if (cur_cmd == assign_toks_cmd) {
                    q = toks(equiv(cur_cs) - toks_base);
                } else if (cur_cmd == toks_register_cmd) {
                    scan_register_num();
                    q = equiv(toks_base + cur_val);
                } else {
                    back_input();
                    scan_register_num();
                    q = equiv(toks_base + cur_val);
                }
                p = token_link(p);
                q = token_link(q);
                if (p == q) {
                    result = 1;
                } else {
                    while ((p != null) && (q != null)) {
                        if (token_info(p) != token_info(q)) {
                            p = null;
                            break;
                        } else {
                            p = token_link(p);
                            q = token_link(q);
                        }
                    }
                    result = ((p == null) && (q == null));
                }
                if (pp >= 0) {
                    flush_list(pp);
                }
                if (qq >= 0) {
                    flush_list(qq);
                }
                scanner_status = save_scanner_status;
            }
            break;
        case if_x_code:
            {
                /*tex
                    Test if two tokens match. Note that |\ifx| will declare two
                    macros different if one is |\long| or |\outer| and the other
                    isn't, even though the texts of the macros are the same.

                    We need to reset |scanner_status|, since |\outer| control
                    sequences are allowed, but we might be scanning a macro
                    definition or preamble.
                 */
                halfword p, q, n;
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                get_next();
                n = cur_cs;
                p = cur_cmd;
                q = cur_chr;
                get_next();
                if (cur_cmd != p) {
                    result = 0;
                } else if (cur_cmd < call_cmd) {
                    result = (cur_chr == q);
                } else {
                    /*tex
                        Test if two macro texts match. Note also that |\ifx|
                        decides that macros |\a| and |\b| are different in
                        examples like this:

                        \starttyping
                        \def\a{\c}  \def\c{}
                        \def\b{\d}  \def\d{}
                        \stoptyping
                    */
                    p = token_link(cur_chr);
                    /*tex Omit reference counts. */
                    q = token_link(equiv(n));
                    if (p == q) {
                        result = 1;
                    } else {
                        while ((p != null) && (q != null)) {
                            if (token_info(p) != token_info(q)) {
                                p = null;
                                break;
                            } else {
                                p = token_link(p);
                                q = token_link(q);
                            }
                        }
                        result = ((p == null) && (q == null));
                    }
                }
                scanner_status = save_scanner_status;
            }
            break;
        case if_true_code:
            result = 1;
            break;
        case if_false_code:
            break;
        case if_cmp_int_code:
            {
                halfword n;
                scan_int(0);
                n = cur_val;
                scan_int(0);
                case_value = (n < cur_val) ? 0 : (n > cur_val) ? 2 : 1;
                goto REST_OF_CASE;
            }
            break;
        case if_cmp_dim_code:
            {
                halfword n;
                scan_normal_dimen(0);
                n = cur_val;
                scan_normal_dimen(0);
                case_value = (n < cur_val) ? 0 : (n > cur_val) ? 2 : 1;
                goto REST_OF_CASE;
            }
            break;
        case if_chk_int_code:
        case if_val_int_code:
        case if_chk_dim_code:
        case if_val_dim_code:
            {
                error_state.intercept = 1;
                error_state.last_intercept = 0;
                if (this_if == if_chk_int_code || this_if == if_val_int_code) {
                    scan_int(0);
                } else {
                    scan_normal_dimen(0);
                }
                if (this_if == if_chk_int_code || this_if == if_chk_dim_code) {
                    case_value = error_state.last_intercept ? 2 : 1;
                } else {
                    case_value = error_state.last_intercept ? 4 : (cur_val < 0) ? 1 : (cur_val > 0) ? 3 : 2;
                }
                error_state.intercept = 0;
                error_state.last_intercept = 0;
                /* common */
                goto REST_OF_CASE;
            }
            break;
        case if_case_code:
            /*tex Select the appropriate case and |return| or |goto common_ending|. */
            {
                scan_int(0);
                /*tex |n| is the number of cases to pass. */
                case_value = cur_val;
                if (tracing_commands_par > 1) {
                    begin_diagnostic();
                    switch (this_if) {
                        case if_case_code    : tprint("{case "); break ;
                        case if_chk_int_code : tprint("{chknum "); break ;
                        case if_cmp_int_code : tprint("{cmpnum "); break ;
                        case if_val_int_code : tprint("{numval "); break ;
                        case if_chk_dim_code : tprint("{chkdim "); break ;
                        case if_cmp_dim_code : tprint("{cmpdim "); break ;
                        case if_val_dim_code : tprint("{dimval "); break ;
                    }
                    print_scaled(case_value);
                    print_char('}');
                    end_diagnostic(0);
                }
            REST_OF_CASE:
                while (case_value != 0) {
                    pass_text();
                    if (cond_ptr == save_cond_ptr) {
                        if (cur_chr == or_code)
                            decr(case_value);
                        else
                            goto COMMON_ENDING;
                    } else if (cur_chr == fi_code) {
                        pop_condition_stack();
                    }
                }
                change_if_limit(or_code, save_cond_ptr);
                /*tex Wait for |\or|, |\else|, or |\fi|. */
                return;
            }
            break;
        case if_def_code:
            /*tex
                The conditional |\ifdefined| tests if a control sequence is
                defined. We need to reset |scanner_status|, since |\outer|
                control sequences are allowed, but we might be scanning a macro
                definition or preamble.
            */
            {
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                get_next();
                result = (cur_cmd != undefined_cs_cmd);
                scanner_status = save_scanner_status;
            }
            break;
        case if_cs_code:
            result = test_for_cs();
            break;
        case if_in_csname_code:
            result = expand_state.is_in_csname;
            break;
        case if_font_char_code:
            /*tex
                The conditional |\iffontchar| tests the existence of a
                character in a font.
            */
            {
                halfword f;
                scan_font_ident();
                f = cur_val;
                scan_char_num();
                result = char_exists(f, cur_val);
            }
            break;
        case if_condition_code:
            /*tex This can't happen! */
         /* result = 0; */
            break;
        case if_eof_code:
            scan_four_bit_int();
            result = (read_open[cur_val] == closed);
            break;
        /*
        case if_primitive_code:
            {
                halfword m;
                int save_scanner_status = scanner_status;
                scanner_status = normal;
                get_next();
                scanner_status = save_scanner_status;
                m = prim_lookup(cs_text(cur_cs));
                b = ((cur_cmd != undefined_cs_cmd) &&
                    (m != undefined_primitive) &&
                    (cur_cmd == get_prim_eq_type(m)) &&
                    (cur_chr == get_prim_equiv(m)));
            }
            break;
        */
        default:
            /*tex there are no other cases, but we need to please |-Wall|. */
         /* b = 0; */
            break;
    }
    if (is_unless) {
        result = !result;
    }
    if (tracing_commands_par > 1) {
        /*tex Display the value of |b|. */
        begin_diagnostic();
        if (result) {
            tprint("{true}");
        } else {
            tprint("{false}");
        }
        end_diagnostic(0);
    }
    if (result) {
        change_if_limit(else_code, save_cond_ptr);
        /*tex Wait for |\else| or |\fi|. */
        return;
    }
    /*tex
        Skip to |\else| or |\fi|, then |goto common_ending|. In a construction
        like |\if\iftrue abc\else d\fi|, the first |\else| that we come to after
        learning that the |\if| is false is not the |\else| we're looking for.
        Hence the following curious logic is needed.
     */
    while (1) {
        pass_text();
        if (cond_ptr == save_cond_ptr) {
            if (cur_chr != or_code)
                goto COMMON_ENDING;
            print_err("Extra \\or");
            help(
                "I'm ignoring this; it doesn't match any \\if."
            );
            error();
        } else if (cur_chr == fi_code) {
            pop_condition_stack();
        }
    }
  COMMON_ENDING:
    if (cur_chr == fi_code) {
        pop_condition_stack();
    } else {
        /*tex Wait for |\fi|. */
        if_limit = fi_code;
    }
}
