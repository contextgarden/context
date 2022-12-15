/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Only a dozen or so command codes |> max_command| can possibly be returned by |get_next|; in
    increasing order, they are |undefined_cs|, |expand_after|, |no_expand|, |input|, |if_test|,
    |fi_or_else|, |cs_name|, |convert|, |the|, |get_mark|, |call|, |long_call|, |outer_call|,
    |long_outer_call|, and |end_template|.

    Sometimes, recursive calls to the following |expand| routine may cause exhaustion of the
    run-time calling stack, resulting in forced execution stops by the operating system. To
    diminish the chance of this happening, a counter is used to keep track of the recursion depth,
    in conjunction with a constant called |expand_depth|.

    Note that this does not catch all possible infinite recursion loops, just the ones that
    exhaust the application calling stack. The actual maximum value of |expand_depth| is outside
    of our control, but the initial setting of |100| should be enough to prevent problems.

*/

expand_state_info lmt_expand_state = {
    .limits           = {
        .minimum = min_expand_depth,
        .maximum = max_expand_depth,
        .size    = min_expand_depth,
        .top     = 0,
    },
    .depth            = 0,
    .cs_name_level    = 0,
    .arguments        = 0,
    .match_token_head = null,
    .padding          = 0,
};

       static void tex_aux_macro_call                (halfword cs, halfword cmd, halfword chr);
inline static void tex_aux_manufacture_csname        (void);
inline static void tex_aux_manufacture_csname_use    (void);
inline static void tex_aux_manufacture_csname_future (void);
inline static void tex_aux_inject_last_tested_cs     (void);

/*tex

    We no longer store |match_token_head| in the format file. It is a bit cleaner to just
    initialize them. So we free them.

*/

void tex_initialize_expansion(void)
{
    lmt_expand_state.match_token_head = tex_get_available_token(null);
}

void tex_cleanup_expansion(void)
{
    tex_put_available_token(lmt_expand_state.match_token_head);
}

halfword tex_expand_match_token_head(void)
{
    return lmt_expand_state.match_token_head;
}

/*tex

    The |expand| subroutine is used when |cur_cmd > max_command|. It removes a \quote {call} or a
    conditional or one of the other special operations just listed. It follows that |expand| might
    invoke itself recursively. In all cases, |expand| destroys the current token, but it sets things
    up so that the next |get_next| will deliver the appropriate next token. The value of |cur_tok|
    need not be known when |expand| is called.

    Since several of the basic scanning routines communicate via global variables, their values are
    saved as local variables of |expand| so that recursive calls don't invalidate them.

*/

inline static void tex_aux_expand_after(void)
{
    /*tex
        Expand the token after the next token. It takes only a little shuffling to do what \TEX\
        calls |\expandafter|.
    */
    halfword t1 = tex_get_token();
    halfword t2 = tex_get_token();
    if (cur_cmd > max_command_cmd) {
        tex_expand_current_token();
    } else {
         tex_back_input(t2);
      /* token_link(t1) = t2; */ /* no gain, rarely happens */
    }
    tex_back_input(t1);
}

inline static void tex_aux_expand_toks_after(void)
{
    halfword t1 = tex_scan_toks_normal(0, NULL);
    halfword t2 = tex_get_token();
    if (cur_cmd > max_command_cmd) {
        tex_expand_current_token();
    } else {
        tex_back_input(t2);
    }
    tex_begin_backed_up_list(token_link(t1));
    tex_put_available_token(t1);
}

/*tex
    Here we deal with stuff not in the big switch. Where that is discussed there is mentioning of
    it all being a bit messy, also due to the fact that that switch (or actually a lookup table)
    also uses the mode for determining what to do. We see no reason to change this model.
*/

void tex_expand_current_token(void)
{
    ++lmt_expand_state.depth;
    if (lmt_expand_state.depth > lmt_expand_state.limits.top) {
        if (lmt_expand_state.depth >= lmt_expand_state.limits.size) {
            tex_overflow_error("expansion depth", lmt_expand_state.limits.size);
        } else {
            lmt_expand_state.limits.top += 1;
        }
    }
    /*tex We're okay. */
    {
        halfword saved_cur_val = cur_val;
        halfword saved_cur_val_level = cur_val_level;
     // halfword saved_head = token_link(token_data.backup_head);
        if (cur_cmd < first_call_cmd) {
            /*tex Expand a nonmacro. */
            if (tracing_commands_par > 1) {
                tex_show_cmd_chr(cur_cmd, cur_chr);
            }
            switch (cur_cmd) {
                case expand_after_cmd:
                    {
                        int mode = cur_chr;
                        switch (mode) {
                            case expand_after_code:
                                tex_aux_expand_after();
                                break;
                            /*
                            case expand_after_3_code:
                                tex_aux_expand_after();
                                // fall-through
                            case expand_after_2_code:
                                tex_aux_expand_after();
                                tex_aux_expand_after();
                                break;
                            */
                            case expand_unless_code:
                                tex_conditional_unless();
                                break;
                            case future_expand_code:
                                /*tex
                                    This is an experiment: |\futureexpand| (2) which takes |\check \yes
                                    \nop| as arguments. It's not faster, but gives less tracing noise
                                    than a macro. The variant |\futureexpandis| (3) alternative doesn't
                                    inject the gobbles space(s).
                                */
                                tex_get_token();
                                {
                                    halfword spa = null;
                                    halfword chr = cur_chr;
                                    halfword cmd = cur_cmd;
                                    halfword yes = tex_get_token(); /* when match */
                                    halfword nop = tex_get_token(); /* when no match */
                                    while (1) {
                                        halfword t = tex_get_token();
                                        if (cur_cmd == spacer_cmd) {
                                            spa = t;
                                        } else {
                                            tex_back_input(t);
                                            break;
                                        }
                                    }
                                    /*tex The value 1 means: same input level. */
                                    if (cur_cmd == cmd && cur_chr == chr) {
                                        tex_reinsert_token(yes);
                                    } else {
                                        if (spa) {
                                            tex_reinsert_token(space_token);
                                        }
                                        tex_reinsert_token(nop);
                                    }
                                }
                                break;
                            case future_expand_is_code:
                                tex_get_token();
                                {
                                    halfword chr = cur_chr;
                                    halfword cmd = cur_cmd;
                                    halfword yes = tex_get_token(); /* when match */
                                    halfword nop = tex_get_token(); /* when no match */
                                    while (1) {
                                        halfword t = tex_get_token();
                                        if (cur_cmd != spacer_cmd) {
                                            tex_back_input(t);
                                            break;
                                        }
                                    }
                                    tex_reinsert_token((cur_cmd == cmd && cur_chr == chr) ? yes : nop);
                                }
                                break;
                            case future_expand_is_ap_code:
                                tex_get_token();
                                {
                                    halfword chr = cur_chr;
                                    halfword cmd = cur_cmd;
                                    halfword yes = tex_get_token(); /* when match */
                                    halfword nop = tex_get_token(); /* when no match */
                                    while (1) {
                                        halfword t = tex_get_token();
                                        if (cur_cmd != spacer_cmd && cur_cmd != end_paragraph_cmd) {
                                            tex_back_input(t);
                                            break;
                                        }
                                    }
                                    /*tex We stay at the same input level. */
                                    tex_reinsert_token((cur_cmd == cmd && cur_chr == chr) ? yes : nop);
                                }
                                break;
                            case expand_after_spaces_code:
                                {
                                    /* maybe two variants: after_spaces and after_par like in the ignores */
                                    halfword t1 = tex_get_token();
                                    while (1) {
                                        halfword t2 = tex_get_token();
                                        if (cur_cmd != spacer_cmd) {
                                            tex_back_input(t2);
                                            break;
                                        }
                                    }
                                    tex_reinsert_token(t1);
                                    break;
                                }
                            case expand_after_pars_code:
                                {
                                    halfword t1 = tex_get_token();
                                    while (1) {
                                        halfword t2 = tex_get_token();
                                        if (cur_cmd != spacer_cmd && cur_cmd != end_paragraph_cmd) {
                                            tex_back_input(t2);
                                            break;
                                        }
                                    }
                                    tex_reinsert_token(t1);
                                    break;
                                }
                            case expand_token_code:
                                {
                                    /* we can share code with lmtokenlib .. todo */
                                    halfword cat = tex_scan_category_code(0);
                                    halfword chr = tex_scan_char_number(0);
                                    /* too fragile: 
                                        halfword tok = null;
                                        switch (cat) {
                                            case letter_cmd:
                                            case other_char_cmd:
                                            case ignore_cmd:
                                            case spacer_cmd:
                                                tok = token_val(cat, chr);
                                                break;
                                            case active_char_cmd:
                                                {
                                                    halfword cs = tex_active_to_cs(chr, ! lmt_hash_state.no_new_cs);
                                                    if (cs) { 
                                                        chr = eq_value(cs);
                                                        tok = cs_token_flag + cs;
                                                        break;
                                                    }
                                                }
                                            default:
                                                tok = token_val(other_char_cmd, chr);
                                                break;
                                        }
                                    */
                                    switch (cat) {
                                        case letter_cmd:
                                        case other_char_cmd:
                                        case ignore_cmd:
                                        case spacer_cmd:
                                            break;
                                        default:
                                            cat = other_char_cmd;
                                            break;
                                    }
                                    tex_back_input(token_val(cat, chr));
                                    break;
                                }
                            case expand_cs_token_code:
                                {
                                    tex_get_token();
                                    if (cur_tok >= cs_token_flag) {
                                        halfword cmd = eq_type(cur_cs);
                                        switch (cmd) {
                                            case left_brace_cmd:
                                            case right_brace_cmd:
                                            case math_shift_cmd:
                                            case alignment_tab_cmd:
                                            case superscript_cmd:
                                            case subscript_cmd:
                                            case spacer_cmd:
                                            case letter_cmd:
                                            case other_char_cmd:
                                            case active_char_cmd: /* new */
                                                cur_tok = token_val(cmd, eq_value(cur_cs));
                                                break;
                                        }
                                    }
                                    tex_back_input(cur_tok);
                                    break;
                                }
                            case expand_code:
                                {
                                    tex_get_token();
                                    if (cur_cmd >= first_call_cmd && cur_cmd <= last_call_cmd) {
                                        tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
                                    } else {
                                        /* Use expand_current_token so that protected lua call are dealt with too? */
                                        tex_back_input(cur_tok);
                                    }
                                    break;
                                }
                            case expand_active_code:
                                {
                                    tex_get_token();
                                    if (cur_cmd == active_char_cmd) {
                                        cur_cs = tex_active_to_cs(cur_chr, ! lmt_hash_state.no_new_cs);
                                        if (cur_cs) {
                                            cur_tok = cs_token_flag + cur_cs;
                                        } else {
                                            cur_tok = token_val(cur_cmd, cur_chr);
                                        }
                                    }
                                    tex_back_input(cur_tok);
                                    break;
                                }
                            case semi_expand_code:
                                {
                                    tex_get_token();
                                    if (is_semi_protected_cmd(cur_cmd)) {
                                        tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
                                    } else {
                                        /* Use expand_current_token so that protected lua call are dealt with too? */
                                        tex_back_input(cur_tok);
                                    }
                                    break;
                                }
                            case expand_after_toks_code:
                                {
                                    tex_aux_expand_toks_after();
                                    break;
                                }
                            /*
                            case expand_after_fi:
                                {
                                    conditional_after_fi();
                                    break;
                                }
                            */
                        }
                    }
                    break;
                case cs_name_cmd:
                    /*tex Manufacture a control sequence name. */
                    switch (cur_chr) {
                        case cs_name_code:
                            tex_aux_manufacture_csname();
                            break;
                        case last_named_cs_code:
                            tex_aux_inject_last_tested_cs();
                            break;
                        case begin_cs_name_code:
                            tex_aux_manufacture_csname_use();
                            break;
                        case future_cs_name_code:
                            tex_aux_manufacture_csname_future();
                            break;
                    }
                    break;
                case no_expand_cmd:
                    {
                        /*tex
                            Suppress expansion of the next token. The implementation of |\noexpand|
                            is a bit trickier, because it is necessary to insert a special
                            |dont_expand| marker into \TEX's reading mechanism. This special marker
                            is processed by |get_next|, but it does not slow down the inner loop.

                            Since |\outer| macros might arise here, we must also clear the
                            |scanner_status| temporarily.
                        */
                        halfword t;
                        halfword save_scanner_status = lmt_input_state.scanner_status;
                        lmt_input_state.scanner_status = scanner_is_normal;
                        t = tex_get_token();
                        lmt_input_state.scanner_status = save_scanner_status;
                        tex_back_input(t);
                        /*tex Now |start| and |loc| point to the backed-up token |t|. */
                        if (t >= cs_token_flag) {
                            halfword p = tex_get_available_token(deep_frozen_dont_expand_token);
                            set_token_link(p, lmt_input_state.cur_input.loc);
                            lmt_input_state.cur_input.start = p;
                            lmt_input_state.cur_input.loc = p;
                        }
                    }
                    break;
                case if_test_cmd:
                    if (cur_chr < first_real_if_test_code) {
                        tex_conditional_fi_or_else();
                    } else if (cur_chr != if_condition_code) {
                        tex_conditional_if(cur_chr, 0);
                    } else {
                        /*tex The |\ifcondition| primitive is a no-op unless we're in skipping mode. */
                    }
                    break;
                case the_cmd:
                    {
                        halfword h = tex_the_toks(cur_chr, NULL);
                        tex_begin_inserted_list(h);
                        break;
                    }
                case lua_call_cmd:
                    if (cur_chr > 0) {
                        strnumber u = tex_save_cur_string();
                        lmt_token_state.luacstrings = 0;
                        lmt_function_call(cur_chr, 0);
                        tex_restore_cur_string(u);
                        if (lmt_token_state.luacstrings > 0) {
                            tex_lua_string_start();
                        }
                    } else {
                        tex_normal_error("luacall", "invalid number");
                    }
                    break;
                case lua_local_call_cmd:
                    if (cur_chr > 0) {
                        lua_State *L = lmt_lua_state.lua_instance;
                        strnumber u = tex_save_cur_string();
                        lmt_token_state.luacstrings = 0;
                        /* todo: use a private table as we can overflow, unless we register early */
                        lua_rawgeti(L, LUA_REGISTRYINDEX, cur_chr);
                        if (lua_pcall(L, 0, 0, 0)) {
                            tex_formatted_warning("luacall", "local call error: %s", lua_tostring(L, -1));
                        } else {
                            tex_restore_cur_string(u);
                            if (lmt_token_state.luacstrings > 0) {
                                tex_lua_string_start();
                            }
                        }
                    } else {
                        tex_normal_error("luacall", "invalid number");
                    }
                    break;
                case begin_local_cmd:
                    tex_begin_local_control();
                    break;
                case convert_cmd:
                    tex_run_convert_tokens(cur_chr);
                    break;
                case input_cmd:
                    /*tex Initiate or terminate input from a file */
                    switch (cur_chr) {
                        case normal_input_code:
                            if (lmt_fileio_state.name_in_progress) {
                                tex_insert_relax_and_cur_cs();
                            } else {
                                tex_start_input(tex_read_file_name(0, NULL, texinput_extension));
                            }
                            break;
                        case end_of_input_code:
                            lmt_token_state.force_eof = 1;
                            break;
                        case quit_loop_code:
                            lmt_main_control_state.quit_loop = 1;
                            break;
                        case token_input_code:
                            tex_tex_string_start(io_token_eof_input_code, cat_code_table_par);
                            break;
                        case tex_token_input_code:
                            tex_tex_string_start(io_token_input_code, cat_code_table_par);
                            break;
                        case tokenized_code:
                        case retokenized_code:
                            {
                                /*tex
                                    This variant complements the other expandable primitives but
                                    also supports an optional keyword, who knows when that comes in
                                    handy; what goes in is detokenized anyway. For now it is an
                                    undocumented feature. It is likely that there is a |cct| passed
                                    so we don't need to optimize. If needed we can make a version
                                    where this is mandate.
                                */
                                int cattable = (cur_chr == retokenized_code || tex_scan_optional_keyword("catcodetable")) ? tex_scan_int(0, NULL) : cat_code_table_par;
                                full_scanner_status saved_full_status = tex_save_full_scanner_status();
                                strnumber u = tex_save_cur_string();
                                halfword s = tex_scan_toks_expand(0, NULL, 0);
                                tex_unsave_full_scanner_status(saved_full_status);
                                if (token_link(s)) {
                                     tex_begin_inserted_list(tex_wrapped_token_list(s));
                                     tex_tex_string_start(io_token_input_code, cattable);
                                }
                                tex_put_available_token(s);
                                tex_restore_cur_string(u);
                            }
                            break;
                        default:
                            break;
                    }
                    break;
                case get_mark_cmd:
                    {
                        /*tex Insert the appropriate mark text into the scanner. */
                        halfword num = 0;
                        halfword code = cur_chr;
                        switch (code) {
                            case top_marks_code:
                            case first_marks_code:
                            case bot_marks_code:
                            case split_first_marks_code:
                            case split_bot_marks_code:
                            case current_marks_code:
                                num = tex_scan_mark_number();
                                break;
                        }
                        if (tex_valid_mark(num)) {
                            halfword ptr = tex_get_some_mark(code, num);
                            if (ptr) {
                                tex_begin_token_list(ptr, mark_text);
                            }
                        }
                        break;
                    }
                /*
                case string_cmd:
                    {
                        halfword head = str_toks(str_lstring(cs_offset_value + cur_chr), NULL);
                        begin_inserted_list(head);
                        break;
                    }
                */
                default:
                    /* Maybe ... or maybe an option */
                 // if (lmt_expand_state.cs_name_level == 0) {
                        if (tex_cs_state(cur_cs) == cs_undefined_error) { 
                            /*tex Complain about an undefined macro */
                            tex_handle_error(
                                normal_error_type,
                                "Undefined control sequence %m", cur_cs,
                                "The control sequence at the end of the top line of your error message was never\n"
                                "\\def'ed. You can just continue as I'll forget about whatever was undefined."
                            );
                        } else { 
                            /*tex We ended up in a situation that is unlikely to happen in traditional \TEX. */
                            tex_handle_error(
                                normal_error_type,
                                "Control sequence expected instead of %C", cur_cmd, cur_chr,
                                "You injected something that confused the parser, maybe by using some Lua call."
                            );
                        }
                 // }
                    break;
            }
        } else if (cur_cmd <= last_call_cmd) {
             tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
        } else {
            /*tex
                Insert a token containing |frozen_endv|. An |end_template| command is effectively
                changed to an |endv| command by the following code. (The reason for this is discussed
                below; the |frozen_end_template| at the end of the template has passed the
                |check_outer_validity| test, so its mission of error detection has been accomplished.)
            */
            tex_back_input(deep_frozen_end_template_2_token);
        }
        cur_val = saved_cur_val;
        cur_val_level = saved_cur_val_level;
     // set_token_link(token_data.backup_head, saved_head);
    }
    --lmt_expand_state.depth;
}

static void tex_aux_complain_missing_csname(void)
{
    tex_handle_error(
        back_error_type,
        "Missing \\endcsname inserted",
        "The control sequence marked <to be read again> should not appear between \\csname\n"
        "and \\endcsname."
    );
}

inline static int tex_aux_uni_to_buffer(unsigned char *b, int m, int c)
{
    if (c <= 0x7F) {
        b[m++] = (unsigned char) c;
    } else if (c <= 0x7FF) {
        b[m++] = (unsigned char) (0xC0 + c / 0x40);
        b[m++] = (unsigned char) (0x80 + c % 0x40);
    } else if (c <= 0xFFFF) {
        b[m++] = (unsigned char) (0xE0 +  c / 0x1000);
        b[m++] = (unsigned char) (0x80 + (c % 0x1000) / 0x40);
        b[m++] = (unsigned char) (0x80 + (c % 0x1000) % 0x40);
    } else {
        b[m++] = (unsigned char) (0xF0 +   c / 0x40000);
        b[m++] = (unsigned char) (0x80 + ( c % 0x40000) / 0x1000);
        b[m++] = (unsigned char) (0x80 + ((c % 0x40000) % 0x1000) / 0x40);
        b[m++] = (unsigned char) (0x80 + ((c % 0x40000) % 0x1000) % 0x40);
    }
    return m;
}

/*tex
    We also quit on a protected macro call, which is different from \LUATEX\ (and \PDFTEX) but makes
    much sense. It also long token lists that never (should) match anyway.
*/

static int tex_aux_collect_cs_tokens(halfword *p, int *n)
{
    while (1) {
        tex_get_next();
        switch (cur_cmd) {
            case left_brace_cmd:
            case right_brace_cmd:
            case math_shift_cmd:
            case alignment_tab_cmd:
         /* case end_line_cmd: */
            case parameter_cmd:
            case superscript_cmd:
            case subscript_cmd:
         /* case ignore_cmd: */
            case spacer_cmd:
            case letter_cmd:
            case other_char_cmd:
            case active_char_cmd: /* new */
              // cur_tok = token_val(cur_cmd, cur_chr);
              // *p = tex_store_new_token(*p, cur_tok);
                 *p = tex_store_new_token(*p, token_val(cur_cmd, cur_chr));
                 *n += 1;
                 break;
         /* case comment_cmd: */
         /* case invalid_char_cmd: */
            /*
            case string_cmd:
                cur_tok = token_val(cur_cmd, cur_chr);
                *p = store_new_token(*p, cur_tok);
                *n += str_length(cs_offset_value + cur_chr);
                break;
            */
            case call_cmd:
            case tolerant_call_cmd:
                if (get_token_reference(cur_chr) == max_token_reference) { // ! get_token_parameters(cur_chr)) {
                    /* we avoid the macro stack and expansion and we don't trace either */
                    halfword h = token_link(cur_chr);
                    while (h) {
                        *p = tex_store_new_token(*p, token_info(h));
                        *n += 1;
                        h = token_link(h);
                    }
                } else {
                    tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
                }
                break;
            case end_cs_name_cmd:
                return 1;
            default:
                if (cur_cmd > max_command_cmd && cur_cmd < first_call_cmd) {
                    tex_expand_current_token();
                } else {
                    return 0;
                }
         }
     }
}

int tex_is_valid_csname(void)
{
    halfword cs = null_cs;
    int b = 0;
    int n = 0;
    halfword h = tex_get_available_token(null);
    halfword p = h;
    lmt_expand_state.cs_name_level += 1;
    if (! tex_aux_collect_cs_tokens(&p, &n)) {
        do {
            tex_get_x_or_protected(); /* we skip unprotected ! */
        } while (cur_cmd != end_cs_name_cmd);
        goto FINISH;
        /* no real gain as we hardly ever end up here */
     // while (1) {
     //     tex_get_token();
     //     if (cur_cmd == end_cs_name_cmd) {
     //         goto FINISH;
     //     } else if (cur_cmd <= max_command_cmd || is_protected_cmd(cur_cmd)) {
     //       /* go on */
     //     } else {
     //         tex_expand_current_token();
     //         if (cur_cmd != end_cs_name_cmd) {
     //             goto FINISH;
     //         }
     //     }
     // }
    } else if (n) {
        /*tex Look up the characters of list |n| in the hash table, and set |cur_cs|. */
        int f = lmt_fileio_state.io_first;
        if (tex_room_in_buffer(f + n * 4)) {
            int m = f;
            halfword l = token_link(h);
            while (l) {
                m = tex_aux_uni_to_buffer(lmt_fileio_state.io_buffer, m, token_chr(token_info(l)));
                l = token_link(l);
            }
            cs = tex_id_locate(f, m - f, 0); /*tex Don't create a new cs! */
            b = (cs != undefined_control_sequence) && (eq_type(cs) != undefined_cs_cmd);
        }
    }
  FINISH:
    tex_flush_token_list_head_tail(h, p, n + 1);
    lmt_scanner_state.last_cs_name = cs;
    lmt_expand_state.cs_name_level -= 1;
    cur_cs = cs;
    return b;
}

inline static halfword tex_aux_get_cs_name(void)
{
    halfword h = tex_get_available_token(null); /* hm */
    halfword p = h;
    int n = 0;
    lmt_expand_state.cs_name_level += 1;
    if (tex_aux_collect_cs_tokens(&p, &n)) {
        /*tex Look up the characters of list |r| in the hash table, and set |cur_cs|. */
        int siz;
        char *s = tex_tokenlist_to_tstring(h, 1, &siz, 0, 0, 0, 0);
        cur_cs = (siz > 0) ? tex_string_locate((char *) s, siz, 1) : null_cs;
    } else {
        tex_aux_complain_missing_csname();
    }
    lmt_scanner_state.last_cs_name = cur_cs;
    lmt_expand_state.cs_name_level -= 1;
    tex_flush_token_list_head_tail(h, p, n);
    return cur_cs;
}

inline static void tex_aux_manufacture_csname(void)
{
    halfword cs = tex_aux_get_cs_name();
    if (eq_type(cs) == undefined_cs_cmd) {
        /*tex The |save_stack| might change! */
        tex_eq_define(cs, relax_cmd, relax_code);
    }
    /*tex The control sequence will now match |\relax| */
    tex_back_input(cs + cs_token_flag);
}

inline static void tex_aux_manufacture_csname_use(void)
{
    if (tex_is_valid_csname()) {
        tex_back_input(cur_cs + cs_token_flag);
    } else {
        lmt_scanner_state.last_cs_name = deep_frozen_relax_token;
    }
}

inline static void tex_aux_manufacture_csname_future(void)
{
    halfword t = tex_get_token();
    if (tex_is_valid_csname()) {
        tex_back_input(cur_cs + cs_token_flag);
    } else {
        lmt_scanner_state.last_cs_name = deep_frozen_relax_token;
        tex_back_input(t);
    }
}

halfword tex_create_csname(void)
{
    halfword cs = tex_aux_get_cs_name();
    if (eq_type(cs) == undefined_cs_cmd) {
        tex_eq_define(cs, relax_cmd, relax_code);
    }
    return cs; // cs + cs_token_flag;
}

inline static void tex_aux_inject_last_tested_cs(void)
{
    if (lmt_scanner_state.last_cs_name != null_cs) {
        tex_back_input(lmt_scanner_state.last_cs_name + cs_token_flag);
    }
}

/*tex

    Sometimes the expansion looks too far ahead, so we want to insert a harmless |\relax| into the
    user's input.
*/

void tex_insert_relax_and_cur_cs(void)
{
    tex_back_input(cs_token_flag + cur_cs);
    tex_reinsert_token(deep_frozen_relax_token);
    lmt_input_state.cur_input.token_type = inserted_text;
}

/*tex

    Here is a recursive procedure that is \TEX's usual way to get the next token of input. It has
    been slightly optimized to take account of common cases.

*/

halfword tex_get_x_token(void)
{
    /*tex This code sets |cur_cmd|, |cur_chr|, |cur_tok|, and expands macros. */
    while (1) {
        tex_get_next();
        if (cur_cmd <= max_command_cmd) {
            break;
        } else if (cur_cmd < first_call_cmd) {
            tex_expand_current_token();
        } else if (cur_cmd <= last_call_cmd) {
            tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
        } else {
            cur_cs = deep_frozen_cs_end_template_2_code;
            cur_cmd = end_template_cmd;
            /*tex Now |cur_chr = token_state.null_list|. */
            break;
        }
    }
    if (cur_cs) {
        cur_tok = cs_token_flag + cur_cs;
    } else {
        cur_tok = token_val(cur_cmd, cur_chr);
    }
    return cur_tok;
}

/*tex

    The |get_x_token| procedure is equivalent to two consecutive procedure calls: |get_next; x_token|.
    It's |get_x_token| without the initial |get_next|.

*/

void tex_x_token(void)
{
    while (cur_cmd > max_command_cmd) {
        tex_expand_current_token();
        tex_get_next();
    }
    if (cur_cs) {
        cur_tok = cs_token_flag + cur_cs;
    } else {
        cur_tok = token_val(cur_cmd, cur_chr);
    }
}

/*tex

    A control sequence that has been |\def|'ed by the user is expanded by \TEX's |macro_call|
    procedure. Here we also need to deal with marks, but these are  discussed elsewhere.

    So let's consider |macro_call| itself, which is invoked when \TEX\ is scanning a control
    sequence whose |cur_cmd| is either |call|, |long_call|, |outer_call|, or |long_outer_call|. The
    control sequence definition appears in the token list whose reference count is in location
    |cur_chr| of |mem|.

    The global variable |long_state| will be set to |call| or to |long_call|, depending on whether
    or not the control sequence disallows |\par| in its parameters. The |get_next| routine will set
    |long_state| to |outer_call| and emit |\par|, if a file ends or if an |\outer| control sequence
    occurs in the midst of an argument.

    The parameters, if any, must be scanned before the macro is expanded. Parameters are token
    lists without reference counts. They are placed on an auxiliary stack called |pstack| while
    they are being scanned, since the |param_stack| may be losing entries during the matching
    process. (Note that |param_stack| can't be gaining entries, since |macro_call| is the only
    routine that puts anything onto |param_stack|, and it is not recursive.)

    After parameter scanning is complete, the parameters are moved to the |param_stack|. Then the
    macro body is fed to the scanner; in other words, |macro_call| places the defined text of the
    control sequence at the top of \TEX's input stack, so that |get_next| will proceed to read it
    next.

    The global variable |cur_cs| contains the |eqtb| address of the control sequence being expanded,
    when |macro_call| begins. If this control sequence has not been declared |\long|, i.e., if its
    command code in the |eq_type| field is not |long_call| or |long_outer_call|, its parameters are
    not allowed to contain the control sequence |\par|. If an illegal |\par| appears, the macro call
    is aborted, and the |\par| will be rescanned.

    Beware: we cannot use |cur_cmd| here because for instance |\bgroup| can be part of an argument
    without there being an |\egroup|. We really need to check raw brace tokens (|{}|) here when we
    pick up an argument!

 */

/*tex

    In \LUAMETATEX| we have an extended argument definition system. The approach is still the same
    and the additional code kind of fits in. There is a bit more testing going on but the overhead
    is kept at a minimum so performance is not hit. Macro packages like \CONTEXT\ spend a lot of
    time expanding and the extra overhead of the extensions is compensated by some gain in using
    them. However, the most important motive is in readability of macro code on the one hand and
    the wish for less tracing (due to all this multi-step processing) on the other. It suits me
    well. This is definitely a case of |goto| abuse.

*/

static halfword tex_aux_prune_list(halfword h)
{
    halfword t = h;
    halfword p = null;
    int done = 0;
    int last = null;
    while (t) {
        halfword l = token_link(t);
        halfword i = token_info(t);
        halfword c = token_cmd(i);
        if (c != spacer_cmd && c != end_paragraph_cmd && i != lmt_token_state.par_token) { // c != 0xFF
            done = 1;
            last = null;
        } else if (done) {
            if (! last) {
                last = p; /* before space */
            }
        } else {
            h = l;
            tex_put_available_token(t);
        }
        p = t;
        t = l;
    }
    if (last) {
        halfword l = token_link(last);
        token_link(last) = null;
        tex_flush_token_list(l);
    }
    return h;
}

int tex_get_parameter_count(void)
{
    int n = 0;
    for (int i = lmt_input_state.cur_input.parameter_start; i < lmt_input_state.parameter_stack_data.ptr; i++) {
        if (lmt_input_state.parameter_stack[i]) {
            ++n;
        } else {
            break;
        }
    }
    return n;
}

/*tex 
    We can avoid the copy of parameters to the stack but it complicates the code because we also need 
    to clean up the previous set of parameters etc. It's not worth the effort. However, there are 
    plenty of optimizations compared to the original. Some are measurable on an average run, others
    are more likely to increase performance when thousands of successive runs happen in e.g. a virtual 
    environment where threads fight for memory access and cpu cache. And because \CONTEXT\ is us used 
    that way we keep looking into ways to gain performance, but not at the cost of dirty hacks (that 
    I tried out of curiosity but rejected in the end). 
*/

static void tex_aux_macro_call(halfword cs, halfword cmd, halfword chr)
{
    int tracing = tracing_macros_par > 0;
    if (tracing) {
        /*tex
            Setting |\tracingmacros| to 2 means that elsewhere marks etc are shown so in fact a bit
            more detail. However, as we turn that on anyway, using a value of 3 is not that weird
            for less info here. Introducing an extra parameter makes no sense.
        */
        tex_begin_diagnostic();
        tex_print_cs_checked(cs);
        if (is_untraced(eq_flag(cs))) {
            tracing = 0;
        } else {
            if (! get_token_preamble(chr)) {
                tex_print_str("->");
            } else {
                /* maybe move the preamble scanner to here */
            }
            tex_token_show(chr, default_token_show_max);
        }
        tex_end_diagnostic();
    }
    if (get_token_preamble(chr)) {
        halfword matchpointer = token_link(chr);
        halfword matchtoken = token_info(matchpointer);
        int save_scanner_status = lmt_input_state.scanner_status;
        halfword save_warning_index = lmt_input_state.warning_index;
        int nofscanned = 0;
        int nofarguments = 0;
        halfword pstack[max_match_count]; 
        /*tex
            Scan the parameters and make |link(r)| point to the macro body; but |return| if an
            illegal |\par| is detected.

            At this point, the reader will find it advisable to review the explanation of token
            list format that was presented earlier, since many aspects of that format are of
            importance chiefly in the |macro_call| routine.

            The token list might begin with a string of compulsory tokens before the first
            |match| or |end_match|. In that case the macro name is supposed to be followed by
            those tokens; the following program will set |s=null| to represent this restriction.
            Otherwise |s| will be set to the first token of a string that will delimit the next
            parameter.
        */
        int tolerant = is_tolerant_cmd(cmd);
        /*tex the number of tokens or groups (usually) */
        halfword count = 0;
        /*tex one step before the last |right_brace| token */
        halfword rightbrace = null;
        /*tex the state, currently the character used in parameter */
        int match = 0;
        int thrash = 0;
        int quitting = 0;
        int last = 0;
        /*tex current node in parameter token list being built */
        halfword p = null;
        /*tex backup pointer for parameter matching */
        halfword s = null;
        int spacer = 0;
        /*tex
             One day I will check the next code for too many tests, no that much branching that it.
             The numbers in |#n| are match tokens except the last one, which is has a different
             token info.
        */
        lmt_input_state.warning_index = cs;
        lmt_input_state.scanner_status = tolerant ? scanner_is_tolerant : scanner_is_matching;
        /* */
        do {
            /*tex
                So, can we use a local head here? After all, there is no expansion going on here,
                so no need to access |temp_token_head|. On the other hand, it's also used as a
                signal, so not now.
            */
          RESTART:
            set_token_link(lmt_expand_state.match_token_head, null);
          AGAIN:
            spacer = 0;
          LATER:
            if (matchtoken < match_token || matchtoken >= end_match_token) {
                s = null;
            } else {
                switch (matchtoken) {
                    case spacer_match_token:
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        do {
                            tex_get_token();
                        } while (cur_cmd == spacer_cmd);
                        last = 1;
                        goto AGAIN;
                    case mandate_match_token:
                        match = match_mandate;
                        goto MANDATE;
                    case mandate_keep_match_token:
                        match = match_bracekeeper;
                      MANDATE:
                        if (last) {
                            last = 0;
                        } else {
                            tex_get_token();
                            last = 1;
                        }
                        if (cur_tok < left_brace_limit) {
                            matchpointer = token_link(matchpointer);
                            matchtoken = token_info(matchpointer);
                            s = matchpointer;
                            p = lmt_expand_state.match_token_head;
                            count = 0;
                            last = 0;
                            goto GROUPED;
                        } else {
                            if (tolerant) {
                                last = 0;
                                nofarguments = nofscanned;
                                tex_back_input(cur_tok);
                                goto QUITTING;
                            } else {
                                last = 0;
                                tex_back_input(cur_tok);
                            }
                            s = null;
                            goto BAD;
                        }
                     // break;
                    case thrash_match_token:
                        match = 0;
                        thrash = 1;
                        break;
                    case leading_match_token:
                        match = match_spacekeeper;
                        break;
                    case prune_match_token:
                        match = match_pruner;
                        break;
                    case continue_match_token:
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        goto AGAIN;
                    case quit_match_token:
                        match = match_quitter;
                        if (tolerant) {
                            last = 0;
                            nofarguments = nofscanned;
                            matchpointer = token_link(matchpointer);
                            matchtoken = token_info(matchpointer);
                            goto QUITTING;
                        } else {
                            break;
                        }
                    case par_spacer_match_token:
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        do {
                            /* discard as we go */
                            tex_get_token();
                        } while (cur_cmd == spacer_cmd || cur_cmd == end_paragraph_cmd);
                        last = 1;
                        goto AGAIN;
                    case keep_spacer_match_token:
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        do {
                            tex_get_token();
                            if (cur_cmd == spacer_cmd) {
                                spacer = 1;
                            } else {
                                break;
                            }
                        } while (1);
                        last = 1;
                        goto LATER;
                    case par_command_match_token:
                        /* this discards till the next par token */
                        do {
                            tex_get_token();
                        } while (cur_cmd != end_paragraph_cmd);
                        goto DELIMITER;
                    default:
                        match = matchtoken - match_token;
                        break;
                }
                matchpointer = token_link(matchpointer);
                matchtoken = token_info(matchpointer);
                s = matchpointer;
                p = lmt_expand_state.match_token_head;
                count = 0;
            }
            /*tex
                Scan a parameter until its delimiter string has been found; or, if |s = null|,
                simply scan the delimiter string. If |info(r)| is a |match| or |end_match|
                command, it cannot be equal to any token found by |get_token|. Therefore an
                undelimited parameter --- i.e., a |match| that is immediately followed by
                |match| or |end_match| --- will always fail the test |cur_tok=info(r)| in the
                following algorithm.
            */
          CONTINUE:
            /*tex Set |cur_tok| to the next token of input. */
            if (last) {
                last = 0;
            } else {
                tex_get_token();
            }
            /* is token_cmd reliable here? */
            if (! count && token_cmd(matchtoken) == ignore_cmd) {
                if (cur_cmd < ignore_cmd || cur_cmd > other_char_cmd || cur_chr != token_chr(matchtoken)) {
                    /*tex We could optimize this but it doesn't pay off now. */
                    tex_back_input(cur_tok);
                }
                matchpointer = token_link(matchpointer);
                matchtoken = token_info(matchpointer);
                if (s) {
                    s = matchpointer;
                }
                goto AGAIN;
            }
            if (cur_tok == matchtoken) {
                /*tex
                    When we end up here we have a match on a delimiter. Advance |r|; |goto found|
                    if the parameter delimiter has been fully matched, otherwise |goto continue|.
                    A slightly subtle point arises here: When the parameter delimiter ends with
                    |#|, the token list will have a left brace both before and after the
                    |end_match|. Only one of these should affect the |align_state|, but both will
                    be scanned, so we must make a correction.
                */
              DELIMITER:
                matchpointer = token_link(matchpointer);
                matchtoken = token_info(matchpointer);
                if (matchtoken >= match_token && matchtoken <= end_match_token) {
                    if (cur_tok < left_brace_limit) {
                        --lmt_input_state.align_state;
                    }
                    goto FOUND;
                } else {
                    goto CONTINUE;
                }
            } else if (cur_cmd == ignore_something_cmd && cur_chr == ignore_argument_code) {
                quitting = count ? 1 : count ? 2 : 3;
                goto FOUND;
            }
            /*tex
                Contribute the recently matched tokens to the current parameter, and |goto continue|
                if a partial match is still in effect; but abort if |s = null|.

                When the following code becomes active, we have matched tokens from |s| to the
                predecessor of |r|, and we have found that |cur_tok <> info(r)|. An interesting
                situation now presents itself: If the parameter is to be delimited by a string such
                as |ab|, and if we have scanned |aa|, we want to contribute one |a| to the current
                parameter and resume looking for a |b|. The program must account for such partial
                matches and for others that can be quite complex. But most of the time we have
                |s = r| and nothing needs to be done.

                Incidentally, it is possible for |\par| tokens to sneak in to certain parameters of
                non-|\long| macros. For example, consider a case like |\def\a#1\par!{...}| where
                the first |\par| is not followed by an exclamation point. In such situations it
                does not seem appropriate to prohibit the |\par|, so \TEX\ keeps quiet about this
                bending of the rules.
            */
            if (s != matchpointer) {
              BAD:
                if (tolerant) {
                    quitting = nofscanned ? 1 : count ? 2 : 3;
                    tex_back_input(cur_tok);
                 // last = 0;
                    goto FOUND;
                } else if (s) {
                    /*tex cycle pointer for backup recovery */
                    halfword t = s;
                    do {
                        halfword u, v;
                        if (match) {
                            p = tex_store_new_token(p, token_info(t));
                        }
                        ++count;
                        u = token_link(t);
                        v = s;
                        while (1) {
                            if (u == matchpointer) {
                                if (cur_tok != token_info(v)) {
                                    break;
                                } else {
                                    matchpointer = token_link(v);
                                    matchtoken = token_info(matchpointer);
                                    goto CONTINUE;
                                }
                            }
                            if (token_info(u) != token_info(v)) {
                                break;
                            } else {
                                u = token_link(u);
                                v = token_link(v);
                            }
                        }
                        t = token_link(t);
                    } while (t != matchpointer);
                    matchpointer = s;
                    matchtoken = token_info(matchpointer);
                    /*tex At this point, no tokens are recently matched. */
                } else {
                    tex_handle_error(
                        normal_error_type,
                        "Use of %S doesn't match its definition",
                        lmt_input_state.warning_index,
                        "If you say, e.g., '\\def\\a1{...}', then you must always put '1' after '\\a',\n"
                        "since control sequence names are made up of letters only. The macro here has not\n"
                        "been followed by the required stuff, so I'm ignoring it."
                    );
                    goto EXIT;
                }
            }
          GROUPED:
            if (cur_tok < left_brace_limit) {
                /*tex Contribute an entire group to the current parameter. */
                int unbalance = 0;
                while (1) {
                    if (match) {
                        p = tex_store_new_token(p, cur_tok);
                    }
                    if (last) {
                        last = 0;
                    } else {
                        tex_get_token();
                    }
                    if (cur_tok < right_brace_limit) {
                        if (cur_tok < left_brace_limit) {
                            ++unbalance;
                        } else if (unbalance) {
                            --unbalance;
                        } else {
                            break;
                        }
                    }
                }
                rightbrace = p;
                if (match) {
                    p = tex_store_new_token(p, cur_tok);
                }
            } else if (cur_tok < right_brace_limit) {
                /*tex Report an extra right brace and |goto continue|. */
                tex_back_input(cur_tok);
                /* moved up: */
                ++lmt_input_state.align_state;
                tex_insert_paragraph_token();
                /* till here */
                tex_handle_error(
                    insert_error_type,
                    "Argument of %S has an extra }",
                    lmt_input_state.warning_index,
                    "I've run across a '}' that doesn't seem to match anything. For example,\n"
                    "'\\def\\a#1{...}' and '\\a}' would produce this error. The '\\par' that I've just\n"
                    "inserted will cause me to report a runaway argument that might be the root of the\n"
                    "problem." );
                goto CONTINUE;
                /*tex A white lie; the |\par| won't always trigger a runaway. */
            } else {
                /*tex
                    Store the current token, but |goto continue| if it is a blank space that would
                    become an undelimited parameter.
                */
                if (cur_tok == space_token && matchtoken <= end_match_token && matchtoken >= match_token && matchtoken != leading_match_token) {
                    goto CONTINUE;
                }
                if (match) {
                    p = tex_store_new_token(p, cur_tok);
                }
            }
            ++count;
            if (matchtoken > end_match_token || matchtoken < match_token) {
                goto CONTINUE;
            }
          FOUND:
            if (s) {
                /*
                    Tidy up the parameter just scanned, and tuck it away. If the parameter consists
                    of a single group enclosed in braces, we must strip off the enclosing braces.
                    That's why |rightbrace| was introduced. Actually, in most cases |m == 1|.
                */
                if (! thrash) {
                    if (token_info(p) < right_brace_limit && count == 1 && p != lmt_expand_state.match_token_head && match != match_bracekeeper) {
                        set_token_link(rightbrace, null);
                        tex_put_available_token(p);
                        p = token_link(lmt_expand_state.match_token_head);
                        pstack[nofscanned] = token_link(p);
                        tex_put_available_token(p);
                    } else {
                        pstack[nofscanned] = token_link(lmt_expand_state.match_token_head);
                    }
                    if (match == match_pruner) {
                        pstack[nofscanned] = tex_aux_prune_list(pstack[nofscanned]);
                    }
                    ++nofscanned;
                    if (tracing) {
                        tex_begin_diagnostic();
                        tex_print_format("%c%c<-", match_visualizer, '0' + nofscanned + (nofscanned > 9 ? gap_match_count : 0));
                        tex_show_token_list(pstack[nofscanned - 1], null, default_token_show_max, 0);
                        tex_end_diagnostic();
                    }
                } else {
                    thrash = 0;
                }
            }
            /*tex
                Now |info(r)| is a token whose command code is either |match| or |end_match|.
            */
            if (quitting) {
                nofarguments = quitting == 3 ? 0 : quitting == 2 && count == 0 ? 0 : nofscanned;
              QUITTING:
                if (spacer) {
                    tex_back_input(space_token); /* experiment */
                }
                while (1) {
                    switch (matchtoken) {
                        case end_match_token:
                            goto QUITDONE;
                        case spacer_match_token:
                        case thrash_match_token:
                        case par_spacer_match_token:
                        case keep_spacer_match_token:
                            goto NEXTMATCH;
                        case mandate_match_token:
                        case leading_match_token:
                            pstack[nofscanned] = null;
                            break;
                        case mandate_keep_match_token:
                            p = tex_store_new_token(null, left_brace_token);
                            pstack[nofscanned] = p;
                            p = tex_store_new_token(p, right_brace_token);
                            break;
                        case continue_match_token:
                            matchpointer = token_link(matchpointer);
                            matchtoken = token_info(matchpointer);
                            quitting = 0;
                            goto RESTART;
                        case quit_match_token:
                            if (quitting) {
                                matchpointer = token_link(matchpointer);
                                matchtoken = token_info(matchpointer);
                                quitting = 0;
                                goto RESTART;
                            } else {
                                goto NEXTMATCH;
                            }
                        default:
                            if (matchtoken >= match_token && matchtoken < end_match_token) {
                                pstack[nofscanned] = null;
                                break;
                            } else {
                                goto NEXTMATCH;
                            }
                    }
                    nofscanned++;
                    if (tracing) {
                        tex_begin_diagnostic();
                        tex_print_format("%c%i--", match_visualizer, nofscanned);
                        tex_end_diagnostic();
                    }
                  NEXTMATCH:
                    matchpointer = token_link(matchpointer);
                    matchtoken = token_info(matchpointer);
                }
            }
        } while (matchtoken != end_match_token);
        nofarguments = nofscanned;
      QUITDONE:
        matchpointer = token_link(matchpointer);
        /*tex
            Feed the macro body and its parameters to the scanner Before we put a new token list on the
            input stack, it is wise to clean off all token lists that have recently been depleted. Then
            a user macro that ends with a call to itself will not require unbounded stack space.
        */
        tex_cleanup_input_state();
        /*tex
            We don't really start a list, it's more housekeeping. The starting point is the body and
            the later set |loc| reflects that.
        */
        tex_begin_macro_list(chr);
        /*tex
            Beware: here the |name| is used for symbolic locations but also for macro indices but these
            are way above the symbolic |token_types| that we use. Better would be to have a dedicated
            variable but let's not open up a can of worms now. We can't use |warning_index| combined
            with a symbolic name either. We're at |end_match_token| now so we need to advance.
        */
        lmt_input_state.cur_input.name = cs;
        lmt_input_state.cur_input.loc = matchpointer;
        /*tex
            This comes last, after the cleanup and the start of the macro list.
        */
        if (nofscanned) {
            tex_copy_pstack_to_param_stack(&pstack[0], nofscanned);
        }
      EXIT:
        lmt_expand_state.arguments = nofarguments;
        lmt_input_state.scanner_status = save_scanner_status;
        lmt_input_state.warning_index = save_warning_index;
    } else {
        tex_cleanup_input_state();
        if (token_link(chr)) {
            tex_begin_macro_list(chr);
            lmt_expand_state.arguments = 0;
            lmt_input_state.cur_input.name = lmt_input_state.warning_index;
            lmt_input_state.cur_input.loc = token_link(chr);
        } else { 
            /* We ignore empty bodies but it doesn't gain us that much. */
        }
    }
}
