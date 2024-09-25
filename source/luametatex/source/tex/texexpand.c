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
    halfword l1 = token_link(t1);
    if (l1) {
        halfword t2 = tex_get_token();
        if (cur_cmd > max_command_cmd) {
            tex_expand_current_token();
        } else {
            tex_back_input(t2);
        }
        tex_begin_backed_up_list(l1);
    }
    tex_put_available_token(t1);
}

/*tex
    Here we deal with stuff not in the big switch. Where that is discussed there is mentioning of
    it all being a bit messy, also due to the fact that that switch (or actually a lookup table)
    also uses the mode for determining what to do. We see no reason to change this model.
*/

void tex_inject_parameter(halfword n)
{
    if (n >= 0 && n < lmt_input_state.parameter_stack_data.ptr) {
        halfword p = lmt_input_state.parameter_stack[n];
        if (p) {
            tex_begin_parameter_list(p);
        }
    }
}

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
            halfword code = cur_chr;
            if (tracing_commands_par > 1) {
                tex_show_cmd_chr(cur_cmd, cur_chr);
            }
            switch (cur_cmd) {
                case expand_after_cmd:
                    switch (code) {
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
                                /*tex 
                                    These can be used instead of |\the<tok register [ref]>| but 
                                    that next token is not expanded so it doesn't accept |\if|. 
                                */
                                tex_get_token();
                                switch (cur_cmd) { 
                                    case call_cmd:
                                    case protected_call_cmd:               
                                    case semi_protected_call_cmd:
                                    case constant_call_cmd:
                                    case tolerant_call_cmd:
                                    case tolerant_protected_call_cmd:
                                    case tolerant_semi_protected_call_cmd:
                                        tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
                                        break;
                                    case internal_toks_reference_cmd:
                                    case register_toks_reference_cmd:
                                        if (cur_chr) {
                                            tex_begin_token_list(cur_chr, token_text);
                                        }
                                        break;
                                    case register_cmd:
                                        if (cur_chr == token_val_level) {
                                            halfword n = tex_scan_toks_register_number();
                                            halfword p = eq_value(register_toks_location(n));
                                            if (p) {
                                                tex_begin_token_list(p, token_text);
                                            }
                                        } else { 
                                            tex_back_input(cur_tok);
                                        }
                                        break;
                                    case internal_toks_cmd:
                                    case register_toks_cmd:
                                        { 
                                            halfword p = eq_value(cur_chr);   
                                            if (p) {
                                                tex_begin_token_list(p, token_text);
                                            }
                                        }
                                        break;
                                    case index_cmd:
                                        tex_inject_parameter(cur_chr);
                                        break;
                                    case case_shift_cmd:
                                        tex_run_case_shift(cur_chr);
                                        break;
                                    default: 
                                        /* Use expand_current_token so that protected lua call are dealt with too? */
                                        tex_back_input(cur_tok);
                                        break;
                                }                                            
                                break;
                            }
                        case expand_toks_code:
                            {
                                /*tex 
                                    These can be used instead of |\the<tok register [ref]>| and 
                                    contrary to above here the next token is expanded so it works 
                                    with a following |\if|. 
                                */
                                tex_get_x_token();
                                switch (cur_cmd) { 
                                    case internal_toks_reference_cmd:
                                    case register_toks_reference_cmd:
                                        if (cur_chr) {
                                            tex_begin_token_list(cur_chr, token_text);
                                        }
                                        break;
                                    case register_cmd:
                                        if (cur_chr == token_val_level) {
                                            halfword n = tex_scan_toks_register_number();
                                            halfword p = eq_value(register_toks_location(n));
                                            if (p) {
                                                tex_begin_token_list(p, token_text);
                                            }
                                        } else { 
                                            tex_back_input(cur_tok);
                                        }
                                        break;
                                    case internal_toks_cmd:
                                    case register_toks_cmd:
                                        { 
                                            halfword p = eq_value(cur_chr);   
                                            if (p) {
                                                tex_begin_token_list(p, token_text);
                                            }
                                        }
                                        break;
                                    default: 
                                        /* Issue an error message? */
                                        tex_back_input(cur_tok);
                                        break;
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
                        case expand_semi_code:
                            {
                                tex_get_token();
                                switch (cur_cmd) {
                                    case semi_protected_call_cmd:
                                    case tolerant_semi_protected_call_cmd:
                                        tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
                                        break;
                                    case lua_semi_protected_call_cmd:
                                        tex_aux_lua_call(cur_cmd, cur_chr);
                                        break;
                                    default:
                                        tex_back_input(cur_tok);
                                        break;
                                }
                                break;
                            }
                        case expand_after_toks_code:
                            {
                                tex_aux_expand_toks_after();
                                break;
                            }
                        case expand_parameter_code:
                            {
                                halfword n = tex_scan_integer(0, NULL);
                                if (n >= 0 && n < lmt_input_state.parameter_stack_data.ptr) {
                                    halfword p = lmt_input_state.parameter_stack[n];
                                    if (p) {
                                        tex_begin_parameter_list(p);
                                    }
                                }
                                break;
                            }
                        /* keep as reference */ /*
                        case expand_after_fi_code:
                            {
                                tex_conditional_after_fi();
                                break;
                            }
                        */
                    }
                    break;
                case cs_name_cmd:
                    /*tex Manufacture a control sequence name. */
                    switch (code) {
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
//                        halfword save_scanner_status = lmt_input_state.scanner_status;
//                        lmt_input_state.scanner_status = scanner_is_normal;
                        t = tex_get_token();
//                        lmt_input_state.scanner_status = save_scanner_status;
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
                    if (code < first_real_if_test_code) {
                        tex_conditional_fi_or_else();
                    } else if (code != if_condition_code) {
                        tex_conditional_if(code, 0);
                    } else {
                        /*tex The |\ifcondition| primitive is a no-op unless we're in skipping mode. */
                    }
                    break;
                case the_cmd:
                    {
                        halfword h = tex_the_toks(code, NULL);
                        if (h) { 
                            tex_begin_inserted_list(h);
                        }
                        break;
                    }
                case lua_call_cmd:
                    if (code > 0) {
                        strnumber u = tex_save_cur_string();
                        lmt_token_state.luacstrings = 0;
                        lmt_function_call(code, 0);
                        tex_restore_cur_string(u);
                        if (lmt_token_state.luacstrings > 0) {
                            tex_lua_string_start();
                        }
                    } else {
                        tex_normal_error("luacall", "invalid number in expansion");
                    }
                    break;
                case lua_local_call_cmd:
                    if (code > 0) {
                        lua_State *L = lmt_lua_state.lua_instance;
                        strnumber u = tex_save_cur_string();
                        lmt_token_state.luacstrings = 0;
                        /* todo: use a private table as we can overflow, unless we register early */
                        lua_rawgeti(L, LUA_REGISTRYINDEX, code);
                        if (lua_pcall(L, 0, 0, 0)) {
                            tex_formatted_warning("luacall", "local call error: %s", lua_tostring(L, -1));
                        } else {
                            tex_restore_cur_string(u);
                            if (lmt_token_state.luacstrings > 0) {
                                tex_lua_string_start();
                            }
                        }
                    } else {
                        tex_normal_error("luacall", "invalid local number in expansion");
                    }
                    break;
                case begin_local_cmd:
                    tex_begin_local_control();
                    break;
                case convert_cmd:
                    tex_run_convert_tokens(code);
                    break;
                case input_cmd:
                    /*tex Initiate or terminate input from a file */
                    switch (code) {
                        case normal_input_code:
                        case eof_input_code:
                            if (lmt_fileio_state.name_in_progress) {
                                tex_insert_relax_and_cur_cs();
                            } else if (code == normal_input_code) {
                                tex_start_input(tex_read_file_name(0, NULL, texinput_extension), null);
                            } else { 
                                halfword t = tex_scan_toks_normal(0, NULL);
                                tex_start_input(tex_read_file_name(0, NULL, texinput_extension), t);
                            }
                            break;
                        case end_of_input_code:
                            lmt_token_state.force_eof = 1;
                            break;
                        case quit_loop_code:
                            lmt_main_control_state.quit_loop = 1;
                            break;
                        case quit_loop_now_code:
                            if (lmt_main_control_state.loop_nesting) { 
                                while (1) { 
                                    tex_get_token();
                                    if (cur_cmd == end_local_cmd) {
                                        lmt_main_control_state.quit_loop = 1;
                                        tex_back_input(cur_tok);
                                        break;
                                    }
                                }
                            } else { 
                                /*tex We're not in a loop and end up at some fuzzy error. */
                            }
                            break;                            
                     /* case quit_fi_now_code: */ /*tex |\if ... \quitfinow\ignorerest \else .. \fi| */
                     /*     tex_quit_fi();     */
                     /*     break;             */
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
                                int cattable = (code == retokenized_code || tex_scan_optional_keyword("catcodetable")) ? tex_scan_integer(0, NULL) : cat_code_table_par;
                                full_scanner_status saved_full_status = tex_save_full_scanner_status();
                                strnumber u = tex_save_cur_string();
                                halfword s = tex_scan_toks_expand(0, NULL, 0, 0);
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
                case index_cmd: /* not needed here */
                    tex_inject_parameter(code); 
                    break;
                default:
                    /* Maybe ... or maybe an option */
                 // if (lmt_expand_state.cs_name_level == 0) {
                        if (tex_cs_state(cur_cs) == cs_undefined_error) { 
                            /*tex Complain about an undefined macro */
                            tex_handle_error(
                                normal_error_type,
                             // "Undefined control sequence %m", cur_cs,
                                "Undefined control sequence",
                                "The control sequence at the end of the top line of your error message was never\n"
                                "\\def'ed. You can just continue as I'll forget about whatever was undefined."
                            );
                        } else { 
                            /*tex We ended up in a situation that is unlikely to happen in traditional \TEX. */
                            tex_handle_error(
                                normal_error_type,
                                "Control sequence expected instead of %C", cur_cmd, code,
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
         // tex_back_input(deep_frozen_end_template_2_token); /* we never come here */
            tex_back_input(deep_frozen_end_template_token); /* we never come here */
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

// inline static int tex_aux_uni_to_buffer(unsigned char *b, int m, int c)
// {
//     if (c <= 0x7F) {
//         b[m++] = (unsigned char) c;
//     } else if (c <= 0x7FF) {
//         b[m++] = (unsigned char) (0xC0 + c / 0x40);
//         b[m++] = (unsigned char) (0x80 + c % 0x40);
//     } else if (c <= 0xFFFF) {
//         b[m++] = (unsigned char) (0xE0 +  c / 0x1000);
//         b[m++] = (unsigned char) (0x80 + (c % 0x1000) / 0x40);
//         b[m++] = (unsigned char) (0x80 + (c % 0x1000) % 0x40);
//     } else {
//         b[m++] = (unsigned char) (0xF0 +   c / 0x40000);
//         b[m++] = (unsigned char) (0x80 + ( c % 0x40000) / 0x1000);
//         b[m++] = (unsigned char) (0x80 + ((c % 0x40000) % 0x1000) / 0x40);
//         b[m++] = (unsigned char) (0x80 + ((c % 0x40000) % 0x1000) % 0x40);
//     }
//     return m;
// }

inline static int tex_aux_chr_to_buffer(unsigned char *b, int m, int c)
{
    b[m++] = (unsigned char) c;
    return m;
}

inline static int tex_aux_uni_to_buffer(unsigned char *b, int m, int c)
{
    if (c <= 0x7F) {
        b[m++] = (unsigned char) c;
    } else if (c <= 0x7FF) {
        b[m++] = (unsigned char) (0xC0 | (c >> 6));
        b[m++] = (unsigned char) (0x80 | (c & 0x3F));
    } else if (c <= 0xFFFF) {
        b[m++] = (unsigned char) (0xE0 | (c >> 12));
        b[m++] = (unsigned char) (0x80 | ((c >> 6) & 0x3F));
        b[m++] = (unsigned char) (0x80 | (c & 0x3F));
    } else {
        int u; 
        c -= 0x10000;
        u = (int) (((c & 0xf0000) >> 16) + 1);
        b[m++] = (unsigned char) (0xF0 | (u >> 2));
        b[m++] = (unsigned char) (0x80 | ((u & 3) << 4) | ((c & 0xF000) >> 12));
        b[m++] = (unsigned char) (0x80 | ((c & 0xFC0) >> 6));;
        b[m++] = (unsigned char) (0x80 | (c & 0x3F));;
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
            case active_char_cmd: /* new, here we don't expand */
                 *p = tex_store_new_token(*p, token_val(cur_cmd, cur_chr));
                 *n += 1;
                 break;
         /* case comment_cmd: */
         /* case invalid_char_cmd: */
         /*      break; */
            case call_cmd:
            case tolerant_call_cmd:
                tex_aux_macro_call(cur_cs, cur_cmd, cur_chr);
                break;
            case constant_call_cmd:
                {
                    halfword h = token_link(cur_chr);
                    if (h) { 
                        if (token_link(h)) { 
                            if (cur_chr > max_data_value) {
                                 while (h) {
                                     *p = tex_store_new_token(*p, token_info(h));
                                     h = token_link(h);
                                     *n += 1;
                                 }
                            } else {
                                *p = tex_store_new_token(*p, token_val(deep_frozen_keep_constant_cmd, cur_chr));
                                *n += 1;
                            }
                        } else { 
                            *p = tex_store_new_token(*p, token_info(h));
                            *n += 1;
                        }
                    }
                }
                break;
            case end_cs_name_cmd:
                return 1;
            case convert_cmd:
                if (cur_chr == cs_lastname_code) { 
                    if (lmt_scanner_state.last_cs_name != null_cs) {
                        /*tex We cheat and abuse the |convert_cmd| as carrier for the current string. */
                        *n += str_length(cs_text(lmt_scanner_state.last_cs_name));
                        cur_chr = cs_text(lmt_scanner_state.last_cs_name) - cs_offset_value + 0xFF;
                        *p = tex_store_new_token(*p, token_val(cur_cmd, cur_chr));
                    }
                    break;
                }
            default:
                if (cur_cmd > max_command_cmd && cur_cmd < first_call_cmd) {
                    tex_expand_current_token();
                } else {
                    return 0;
                }
         }
     }
}

/* why do we use different methods here */

inline static halfword tex_aux_cs_tokens_to_string(halfword h, halfword f)
{
    int m = f;
    halfword l = token_link(h);
    while (l) {
        halfword info = token_info(l);
        if (token_cmd(info) == deep_frozen_keep_constant_cmd) {
            halfword h = token_link(token_chr(info));
            while (h) {
                m = tex_aux_uni_to_buffer(lmt_fileio_state.io_buffer, m, token_chr(token_info(h)));
                h = token_link(h);
            }
        } else if (token_cmd(info) == convert_cmd) { 
         // if (token_chr(info) >= 0xFF) { 
                /*tex We know that we have something here. */
                strnumber t = token_chr(info) + cs_offset_value - 0xFF;
                memcpy(lmt_fileio_state.io_buffer + m,  str_string(t), str_length(t));
                m += str_length(t);
         // }
        } else {
            m = tex_aux_uni_to_buffer(lmt_fileio_state.io_buffer, m, token_chr(info));
        }
        l = token_link(l);
    }
    return m;
}

int tex_is_valid_csname(void)
{
    halfword cs = null_cs;
    halfword h = tex_get_available_token(null);
    halfword p = h;
    int b = 0;
    int n = 0;
    lmt_expand_state.cs_name_level += 1;
    if (! tex_aux_collect_cs_tokens(&p, &n)) {
         /*tex We seldom end up here so there is no gain in optimizing. */
     //  if (1) {
     //      int level = 1;
     //      while (level) {
     //          tex_get_next();
     //          switch (cur_cmd) {
     //              case end_cs_name_cmd:
     //                  level--;
     //                  break;
     //              case cs_name_cmd:
     //                  level++;
     //                  break;
     //              case if_test_cmd:
     //                  if (cur_chr == if_csname_code) { 
     //                      level++;
     //                  }
     //                  break;
     //          }
     //      }
     //  } else { 
            do {
                tex_get_x_or_protected(); /* we skip unprotected ! */
            } while (cur_cmd != end_cs_name_cmd);
     // }
    } else if (n) {
        /*tex Look up the characters of list |n| in the hash table, and set |cur_cs|. */
        int f = lmt_fileio_state.io_first;
        if (tex_room_in_buffer(f + n * 4)) {
            int m = tex_aux_cs_tokens_to_string(h, f);
            cs = tex_id_locate_only(f, m - f); 
            b = (cs != undefined_control_sequence) && (eq_type(cs) != undefined_cs_cmd);
        }
    } else { 
        /*tex Safeguard in case we accidentally redefined |null_cs|. */
     // copy_eqtb_entry(null_cs, undefined_control_sequence);
    }
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
        /*tex 
            Here we have to make a choice wrt duplicating hashes. In pdftex the hashes are 
            duplicated when we csname a meaning of a macro with |#1| and |##1| or just |##| 
            but in the token list these are actually references of single hashes. Therefore 
            we do as in luatex: we go single hash. In the end it doesn't matter much as such 
            weird control sequences are less likely to happen than embedded hashes (with 
            catcode parameter) so single is then more natural. 
        */
        int f = lmt_fileio_state.io_first;
        if (n && tex_room_in_buffer(f + n * 4)) {
            int m = tex_aux_cs_tokens_to_string(h, f);
            cur_cs = tex_id_locate(f, m - f, 1); 
        } else { 
            cur_cs = null_cs;
        }
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
        /*tex The control sequence will now match |\relax|. The savestack might change. */
        tex_eq_define(cs, relax_cmd, relax_code);
    }
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
         // cur_cs = deep_frozen_cs_end_template_2_code;
            cur_cs = deep_frozen_cs_end_template_code;
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
    bool done = 0;
    int last = null;
    while (t) {
        halfword l = token_link(t);
        halfword i = token_info(t);
        halfword c = token_cmd(i);
        if (c != spacer_cmd && c != end_paragraph_cmd && i != lmt_token_state.par_token) { // c != 0xFF
            done = true;
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

int tex_get_parameter_index(int n)
{
    n = lmt_input_state.cur_input.parameter_start + n - 1;
    if (n < lmt_input_state.parameter_stack_data.ptr) {
        return n; 
    }
    return -1;
}

/*tex 
    We can avoid the copy of parameters to the stack but it complicates the code because we also need 
    to clean up the previous set of parameters etc. It's not worth the effort. However, there are 
    plenty of optimizations compared to the original. Some are measurable on an average run, others
    are more likely to increase performance when thousands of successive runs happen in e.g. a virtual 
    environment where threads fight for memory access and cpu cache. And because \CONTEXT\ is us used 
    that way we keep looking into ways to gain performance, but not at the cost of dirty hacks (that 
    I tried out of curiosity but rejected in the end). 

    The arguments counter is a bit fuzzy and might disappear. I might rewrite this again using states. 
*/

// halfword tex_get_token(void)
// {
//     lmt_hash_state.no_new_cs = 0;
//     tex_get_next();
//     lmt_hash_state.no_new_cs = 1;
//     cur_tok = cur_cs ? cs_token_flag + cur_cs : token_val(cur_cmd, cur_chr);
//     return cur_tok;
// }

inline static void tex_aux_macro_grab_left_right(halfword lefttoken, halfword righttoken, int match)
{
    halfword tail = lmt_expand_state.match_token_head;
    int unbalance = 0;
    int nesting = 1;
    while (1) {
        halfword t = tex_get_token();
        if (cur_tok < right_brace_limit) {
            if (cur_tok < left_brace_limit) {
                ++unbalance;
            } else if (unbalance) {
                --unbalance;
            }
        } else if (unbalance) {
            /* just add */
        } else if (t == lefttoken) {
            ++nesting;  
        } else if (t == righttoken) {
            --nesting;
            if (! nesting) { 
                break;
            }
        }
        if (match) { 
            tail = tex_store_new_token(tail, t);
        }
    }
}

inline static void tex_aux_macro_grab_upto_par(int match)
{
    halfword tail = lmt_expand_state.match_token_head;
    int unbalance = 0;
    while (1) {
        halfword t = tex_get_token();
        if (cur_tok < right_brace_limit) {
            if (cur_tok < left_brace_limit) {
                ++unbalance;
            } else if (unbalance) {
                --unbalance;
            }
        } else if (unbalance) {
            /* just add */
        } else if (cur_cmd == end_paragraph_cmd) {
            break;
        }
        if (match) { 
            tail = tex_store_new_token(tail, t);
        }
    }
}

inline static void tex_aux_macro_gobble_upto(halfword gobbletoken, bool gobblemore)
{
    if (gobblemore) { 
        while (1) { 
            halfword t = tex_get_token();
            if (! (t == gobbletoken || cur_cmd == spacer_cmd)) {
                break;
            }
        }
    } else { 
        do {
        } while (tex_get_token() == gobbletoken);
    }
}

static void tex_aux_macro_call(halfword cs, halfword cmd, halfword chr)
{
    bool tracing = tracing_macros_par > 0;
    if (tracing) {
        /*tex
            Setting |\tracingmacros| to 2 means that elsewhere marks etc are shown so in fact a bit
            more detail. However, as we turn that on anyway, using a value of 3 is not that weird
            for less info here. Introducing an extra parameter makes no sense.
        */
        tex_begin_diagnostic();
        tex_print_cs_checked(cs);
        if (is_untraced(eq_flag(cs))) {
            tracing = false;
        } else {
            if (! get_token_preamble(chr)) {
                tex_print_str("->");
            } else {
                /* maybe move the preamble scanner to here */
            }
            tex_token_show(chr);
        }
        tex_end_diagnostic();
    }
    if (! get_token_preamble(chr)) {
        /*tex Happens more often (about two times). */
        tex_cleanup_input_state();
        if (token_link(chr)) {
            tex_begin_macro_list(chr);
            lmt_expand_state.arguments = 0;
            lmt_input_state.cur_input.name = lmt_input_state.warning_index;
            lmt_input_state.cur_input.loc = token_link(chr);
        } else { 
            /* We ignore empty bodies. */
        }
    } else {
        halfword matchpointer = token_link(chr);
        halfword matchtoken = token_info(matchpointer);
        int save_scanner_status = lmt_input_state.scanner_status;
        halfword save_warning_index = lmt_input_state.warning_index;
        int nofscanned = 0;
        int nofarguments = 0;
        halfword pstack[max_match_count] = { null }; 
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
        bool thrash = false;
        bool last = false;
        bool spacer = false;
        bool gobblemore = false;
        bool nested = false;
        int quitting = 0; /* multiple values */
        /*tex current node in parameter token list being built */
        halfword p = null;
        /*tex backup pointer for parameter matching */
        halfword s = null;
        halfword lefttoken = null;
        halfword righttoken = null;
        halfword gobbletoken = null;
        halfword leftparent = null;
        halfword rightparent = null;
        halfword leftbracket = null;
        halfword rightbracket = null;
        halfword leftangle = null;
        halfword rightangle = null;
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
            spacer = false;
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
                        last = true;
                        goto AGAIN;
                    case mandate_match_token:
                        match = match_mandate;
                        goto MANDATE;
                    case mandate_keep_match_token:
                        match = match_bracekeeper;
                      MANDATE:
                        if (last) {
                            last = false;
                        } else {
                            tex_get_token();
                            last = true;
                        }
                        if (cur_tok < left_brace_limit) {
                            matchpointer = token_link(matchpointer);
                            matchtoken = token_info(matchpointer);
                            s = matchpointer;
                            p = lmt_expand_state.match_token_head;
                            count = 0;
                            last = false;
                            goto GROUPED;
                        } else if (tolerant) {
                            last = false;
                            nofarguments = nofscanned;
                            tex_back_input(cur_tok);
                            goto QUITTING;
                        } else {
                            last = false;
                            tex_back_input(cur_tok);
                            s = null;
                            goto BAD;
                        }
                     // break;
                    case thrash_match_token:
                        match = 0;
                        thrash = true;
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
                            last = false;
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
                        last = true;
                        goto AGAIN;
                    case keep_spacer_match_token:
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        do {
                            tex_get_token();
                            if (cur_cmd == spacer_cmd) {
                                spacer = true;
                            } else {
                                break;
                            }
                        } while (1);
                        last = true;
                        goto LATER;
                    case left_match_token:
                        matchpointer = token_link(matchpointer);
                        lefttoken = token_info(matchpointer);
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                     // match = match_token;
                        goto AGAIN;
                    case right_match_token:
                        matchpointer = token_link(matchpointer);
                        righttoken = token_info(matchpointer);
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                     // match = match_token;
                        goto AGAIN;
                    case gobble_more_match_token:
                        gobblemore = true;
                    case gobble_match_token:
                        matchpointer = token_link(matchpointer);
                        gobbletoken = token_info(matchpointer);
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                     // match = match_token;
                        goto AGAIN;
                    case brackets_match_token:
                        leftbracket = left_bracket_token;
                        rightbracket = right_bracket_token;
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        nested = true;
                     // match = match_token;
                        goto AGAIN;
                    case parentheses_match_token:
                        leftparent = left_parent_token;
                        rightparent = right_parent_token;
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        nested = true;
                     // match = match_token;
                        goto AGAIN;
                    case angles_match_token:
                        leftangle= left_angle_token;
                        rightangle = right_angle_token;
                        matchpointer = token_link(matchpointer);
                        matchtoken = token_info(matchpointer);
                        nested = true;
                     // match = match_token;
                        goto AGAIN;
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
                Scan an argument delimited by two tokens that can be nested. The right only case is 
                basically just a simple delimited variant but a bit faster. 

                todo: when gobble ... 
            */
            if (lefttoken && righttoken) { 
                tex_aux_macro_grab_left_right(lefttoken, righttoken, match);
                lefttoken = null;
                righttoken = null;
                if (nested) {
                    leftparent = null;
                    rightparent = null;
                    leftbracket = null;
                    rightbracket = null;
                    leftangle = null;
                    rightangle = null;
                    nested = false;
                }
                goto FOUND;
            } else if (gobbletoken) { 
                tex_aux_macro_gobble_upto(gobbletoken, gobblemore);
                last = true; 
                gobbletoken = null;
                gobblemore = false;
            } else if (matchtoken == par_command_match_token) {
                tex_aux_macro_grab_upto_par(match);
                cur_tok = matchtoken; 
                goto DELIMITER;
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
                last = false;
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
                 // last = false;
                    goto FOUND;
                } else if (s) {
                    /*tex cycle pointer for backup recovery */
                    halfword t = s;
                    do {
                        halfword u, v;
                        if (match) {
                            p = tex_store_new_token(p, token_info(t));
                        }
                        ++count; /* why */
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
                            } else if (token_info(u) != token_info(v)) {
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
            /*tex We could check |cur_cmd| instead but then we also have to check |cur_cs| later on. */
            if (cur_tok < left_brace_limit) {
                /*tex Contribute an entire group to the current parameter. */
                int unbalance = 0;
                while (1) {
                    if (match) {
                        p = tex_store_new_token(p, cur_tok);
                    }
                    if (last) {
                        last = false;
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
                if (nested && (cur_tok == leftbracket || cur_tok == leftparent || cur_tok == leftangle)) {
                    int unbalance = 0;
                    int pairing = 1;
                    if (match) { 
                        p = tex_store_new_token(p, cur_tok);
                    }
                    while (1) {
                        halfword t = tex_get_token();
                        if (t < right_brace_limit) {
                            if (t < left_brace_limit) {
                                ++unbalance;
                            } else if (unbalance) {
                                --unbalance;
                            }
                        } else if (unbalance) {
                            /* just add */
                        } else if (t == leftbracket || t == leftparent || t == leftangle) {
                            ++pairing;
                        } else if (pairing && (t == rightbracket || t == rightparent || t == rightangle)) { 
                            --pairing;
                            if (! pairing && ! righttoken) { 
                                if (match) { 
                                    p = tex_store_new_token(p, t);
                                }
                                break;
                            }
                        } else if (t == righttoken) {
                            break;
                        }
                        if (match) {
                            p = tex_store_new_token(p, t);
                        }
                        /* align stuff */
                    }
                } else { 
                    if (match) {
                        p = tex_store_new_token(p, cur_tok);
                    }
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
                    halfword n = token_link(lmt_expand_state.match_token_head);
                    if (n) {
                        if (token_info(p) < right_brace_limit && count == 1 && p != lmt_expand_state.match_token_head && match != match_bracekeeper) {
                            set_token_link(rightbrace, null);
                            tex_put_available_token(p);
                            p = n;
                            pstack[nofscanned] = token_link(p);
                            tex_put_available_token(p);
                        } else {
                            pstack[nofscanned] = n;
                        }
                        if (match == match_pruner) {
                            pstack[nofscanned] = tex_aux_prune_list(pstack[nofscanned]);
                        }
                    }
                    ++nofscanned;
                    if (tracing) {
                        tex_begin_diagnostic();
                        tex_print_format("%c%c<-", match_visualizer, '0' + nofscanned + (nofscanned > 9 ? gap_match_count : 0));
                        tex_show_token_list(pstack[nofscanned - 1], 0, 0);
                        tex_end_diagnostic();
                    }
                } else {
                    thrash = false;
                }
                lefttoken = null;
                righttoken = null;
                if (nested) { 
                    leftparent = null;
                    rightparent = null;
                    leftbracket = null;
                    rightbracket = null;
                    leftangle = null;
                    rightangle = null;
                    nested = false;
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
                         /* pstack[nofscanned] = null; */ /* zerood anyway */
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
                        case left_match_token:
                        case right_match_token:
                        case gobble_match_token:
                        case gobble_more_match_token:
                            matchpointer = token_link(matchpointer);
                            matchtoken = token_info(matchpointer);
                            goto NEXTMATCH;
                        case brackets_match_token:
                        case parentheses_match_token:
                        case angles_match_token:
                            goto NEXTMATCH;
                        default:
                            if (matchtoken >= match_token && matchtoken < end_match_token) {
                             /* pstack[nofscanned] = null; */ /* zerood anyway */
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
        
            We could ignore this when |lmt_expand_state.cs_name_level > 0| but there is no gain. 
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
            tex_copy_to_parameter_stack(&pstack[0], nofscanned);
        }
      EXIT:
        lmt_expand_state.arguments = nofarguments;
        lmt_input_state.scanner_status = save_scanner_status;
        lmt_input_state.warning_index = save_warning_index;
    }
}
