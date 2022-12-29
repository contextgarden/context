/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex Todo: move some helpers to other places. */

inline static int tex_aux_the_cat_code(halfword b)
{
    return (lmt_input_state.cur_input.cattable == default_catcode_table_preset) ?
        tex_get_cat_code(cat_code_table_par, b)
    : ( (lmt_input_state.cur_input.cattable > -0xFF) ?
        tex_get_cat_code(lmt_input_state.cur_input.cattable, b)
    : (
        - lmt_input_state.cur_input.cattable - 0xFF
    ) ) ;
}

/*tex

    The \TEX\ system does nearly all of its own memory allocation, so that it can readily be
    transported into environments that do not have automatic facilities for strings, garbage
    collection, etc., and so that it can be in control of what error messages the user receives.
    The dynamic storage requirements of \TEX\ are handled by providing two large arrays called
    |fixmem| and |varmem| in which consecutive blocks of words are used as nodes by the \TEX\
    routines.

    Pointer variables are indices into this array, or into another array called |eqtb| that
    will be explained later. A pointer variable might also be a special flag that lies outside
    the bounds of |mem|, so we allow pointers to assume any |halfword| value. The minimum
    halfword value represents a null pointer. \TEX\ does not assume that |mem[null]| exists.

    Locations in |fixmem| are used for storing one-word records; a conventional |AVAIL| stack is
    used for allocation in this array.

    One can make an argument to switch to standard \CCODE\ allocation but the current approach is
    very efficient in memory usage and performence so we stay with it. On the average memory
    consumption of \TEX| is not that large, definitely not compared to other programs that deal
    with text.

    The big dynamic storage area is named |fixmem| where the smallest location of one|-|word
    memory in use is |fix_mem_min| and the largest location of one|-|word memory in use is
    |fix_mem_max|.

    The |dyn_used| variable keeps track of how much memory is in use. The head of the list of
    available one|-|word nodes is registered in |avail|. The last one-|word node used in |mem|
    is |fix_mem_end|.

    All these variables are packed in the structure |token_memory_state|.

*/

token_memory_state_info lmt_token_memory_state = {
    .tokens      = NULL,
    .tokens_data = {
        .minimum   = min_token_size,
        .maximum   = max_token_size,
        .size      = siz_token_size,
        .step      = stp_token_size,
        .allocated = 0,
        .itemsize  = sizeof(memoryword),
        .top       = 0,
        .ptr       = 0, /* used to register usage */
        .initial   = 0,
        .offset    = 0,
    },
    .available  = 0,
    .padding    = 0,
};

/*tex

    Token data has its own memory space. Again we have some state variables: |temp_token_head| is
    the head of a (temporary) list of some kind as are |hold_token_head| and |omit_template|. A
    permanently empty list is available in |null_list| and the head of the token list built by
    |scan_keyword| is registered in |backup_head|. All these variables are packed in the structure
    |token_data| but some have been moved to a more relevant state (so omit and hold are now in the
    alignment state).

*/

token_state_info lmt_token_state = {
    .null_list      = null,
    .in_lua_escape  = 0,
    .force_eof      = 0,
    .luacstrings    = 0,
    .par_loc        = null,
    .par_token      = null,
 /* .line_par_loc   = null, */ /* removed because not really used and useful */
 /* .line_par_token = null, */ /* idem */
    .buffer         = NULL,
    .bufloc         = 0,
    .bufmax         = 0,
    .empty          = null, 
};

/*tex Some properties are dumped in the format so these are aet already! */

# define reserved_token_mem_slots 2 // play safe for slight overuns

void tex_initialize_token_mem(void)
{
    memoryword *tokens = NULL;
    int size = 0;
    if (lmt_main_state.run_state == initializing_state) {
        size = lmt_token_memory_state.tokens_data.minimum;
    } else {
        size = lmt_token_memory_state.tokens_data.allocated;
        lmt_token_memory_state.tokens_data.initial = lmt_token_memory_state.tokens_data.ptr;
    }
    if (size > 0) {
        tokens = aux_allocate_clear_array(sizeof(memoryword), size, reserved_token_mem_slots);
    }
    if (tokens) {
        lmt_token_memory_state.tokens = tokens;
        lmt_token_memory_state.tokens_data.allocated = size;
    } else {
        tex_overflow_error("tokens", size);
    }
}

static void tex_aux_bump_token_memory(void)
{
    /*tex We need to manage the big dynamic storage area. */
    int size = lmt_token_memory_state.tokens_data.allocated + lmt_token_memory_state.tokens_data.step;
    if (size > lmt_token_memory_state.tokens_data.size) {
        lmt_run_memory_callback("token", 0);
        tex_show_runaway();
        tex_overflow_error("token memory size", lmt_token_memory_state.tokens_data.allocated);
    } else {
        memoryword *tokens = aux_reallocate_array(lmt_token_memory_state.tokens, sizeof(memoryword), size, reserved_token_mem_slots);
        lmt_run_memory_callback("token", tokens ? 1 : 0);
        if (tokens) {
            lmt_token_memory_state.tokens = tokens;
        } else {
            /*tex If memory is exhausted, display possible runaway text. */
            tex_show_runaway();
            tex_overflow_error("token memory size", lmt_token_memory_state.tokens_data.allocated);
        }
    }
    memset((void *) (lmt_token_memory_state.tokens + lmt_token_memory_state.tokens_data.allocated + 1), 0, ((size_t) lmt_token_memory_state.tokens_data.step + reserved_token_mem_slots) * sizeof(memoryword));
    lmt_token_memory_state.tokens_data.allocated = size;
}

void tex_initialize_tokens(void)
{
    lmt_token_memory_state.available = null;
    lmt_token_memory_state.tokens_data.top = 0;
    lmt_token_state.null_list = tex_get_available_token(null);
    lmt_token_state.in_lua_escape = 0;
}

/*tex
    Experiment. It saves some 512K on the \CONTEXT\ format of October 2020. It makes me wonder if I
    should spend some time on optimizing token lists (kind of cisc commands as we're currently kind
    of risc).
*/

void tex_compact_tokens(void)
{
    int nc = 0;
 // memoryword *target = allocate_array(sizeof(memoryword), (size_t) token_memory_state.tokens_data.allocated, 0);
    memoryword *target = aux_allocate_clear_array(sizeof(memoryword), lmt_token_memory_state.tokens_data.allocated, 0);
    halfword *mapper = aux_allocate_array(sizeof(halfword), lmt_token_memory_state.tokens_data.allocated, 0);
    int nofluacmds = 0;
    if (target && mapper) {
        memoryword *tokens = lmt_token_memory_state.tokens;
        memset((void *) mapper, -1, ((size_t) lmt_token_memory_state.tokens_data.allocated) * sizeof(halfword));
        /* also reset available */
        for (int cs = 0; cs < (eqtb_size + lmt_hash_state.hash_data.ptr + 1); cs++) {
            switch (eq_type(cs)) {
                case call_cmd:
                case protected_call_cmd:
                case semi_protected_call_cmd:
                case tolerant_call_cmd:
                case tolerant_protected_call_cmd:
                case tolerant_semi_protected_call_cmd:
                case internal_toks_reference_cmd:
                case register_toks_reference_cmd:
                    {
                        halfword v = eq_value(cs); /* ref count token*/
                        if (v) {
                            if (mapper[v] < 0) {
                             // printf("before =>"); { halfword tt = v; while (tt) { printf("%7d ",tt); tt = token_link(tt); } } printf("\n");
                                halfword t = v;
                                nc++;
                                mapper[v] = nc; /* new ref count token index */
                                while (1) {
                                    target[nc].half1 = tokens[t].half1; /* info cq. ref count */
                                    t = tokens[t].half0;
                                    if (t) {
                                        nc++;
                                        target[nc-1].half0 = nc;        /* link to next */
                                    } else {
                                        target[nc].half0 = null;        /* link to next */
                                        break;
                                    }
                                }
                             // printf("after  =>"); { halfword tt = mapper[v]; while (tt) { printf("%7d ",tt); tt = target[tt].half0; } } printf("\n");
                            }
                            eq_value(cs) = mapper[v];
                        }
                        break;
                    }
                case lua_value_cmd:
                case lua_call_cmd:
                case lua_local_call_cmd:
                    {
                        ++nofluacmds;
                        break;
                    }
            }
        }
        lmt_token_state.empty = mapper[lmt_token_state.empty];
     // print(dump_state.format_identifier);
        tex_print_format("tokenlist compacted from %i to %i entries, ", lmt_token_memory_state.tokens_data.top, nc);
        if (nofluacmds) {
            /*tex
                We just mention them because when these are aliased the macro package needs to make
                sure that after loading that happens again because registered funciton references
                can have changed between format generation and run!
            */
            tex_print_format("%i potentially aliased lua call/value entries, ", nofluacmds);
        }
        lmt_token_memory_state.tokens_data.top = nc;
        lmt_token_memory_state.tokens_data.ptr = nc;
        aux_deallocate_array(lmt_token_memory_state.tokens);
        lmt_token_memory_state.tokens = target;
        lmt_token_memory_state.available = null;
    } else {
        tex_overflow_error("token compaction size", lmt_token_memory_state.tokens_data.allocated);
    }
}


/*tex

    The function |get_avail| returns a pointer (index) to a new one word node whose |link| field is
    |null| (which is just 0). However, \TEX\ will halt if there is no more room left.

    If the available space list is empty, i.e., if |avail = null|, we try first to increase
    |fix_mem_end|. If that cannot be done, i.e., if |fix_mem_end = fix_mem_max|, we try to reallocate
    array |fixmem|. If, that doesn't work, we have to quit. Users can configure \TEX\ to use a lot of
    memory but in some scenarios limitations make sense.

    Remark: we can have a pool of chunks where we get from or just allocate per token (as we have lots
    of them that is slow). But then format loading becomes much slower as we need to recreate the
    linked list. A no go. In todays terms \TEX\ memory usage is low anyway.

    The freed tokens are kept in a linked list. First we check if we can quickly get one of these. If
    that fails, we try to get one from the available pool. If that fails too, we enlarge the pool and
    try again. We keep track of the used number of tokens. We also make sure that the tokens links to
    nothing.

    One problem is of course that tokens can be scattered over memory. We could have some sorter that
    occasionally kicks in but it doesn't pay off. Normally definitions (in the format) are in sequence
    but a normal run \unknown\ it would be interesting to know if this impacts the cache.

*/

halfword tex_get_available_token(halfword t)
{
    halfword p = lmt_token_memory_state.available;
    if (p) {
        lmt_token_memory_state.available = token_link(p);
    } else if (lmt_token_memory_state.tokens_data.top < lmt_token_memory_state.tokens_data.allocated) {
        p = ++lmt_token_memory_state.tokens_data.top;
     } else {
        tex_aux_bump_token_memory();
        p = ++lmt_token_memory_state.tokens_data.top;
    }
    ++lmt_token_memory_state.tokens_data.ptr;
    token_link(p) = null;
    token_info(p) = t;
    return p;
}

/*tex

    Because we only have forward links, a freed token ends up at the head of the list of available
    tokens.

*/

void tex_put_available_token(halfword p)
{
    token_link(p) = lmt_token_memory_state.available;
    lmt_token_memory_state.available = p;
    --lmt_token_memory_state.tokens_data.ptr;
}

halfword tex_store_new_token(halfword p, halfword t)
{
    halfword q = tex_get_available_token(t);
    token_link(p) = q;
    return q;
}

/*tex

    The procedure |flush_list (p)| frees an entire linked list of oneword nodes that starts at
    position |p|. It makes list of single word nodes available. The second variant in principle
    is faster but in practice this goes unnoticed. Of course there is a little price to pay for
    keeping track of memory usage.

*/

void tex_flush_token_list(halfword head)
{
    if (head) {
        halfword current = head;
        halfword tail;
        int i = 0;
        do {
            ++i;
            tail = current;
            current = token_link(tail);
        } while (current);
        lmt_token_memory_state.tokens_data.ptr -= i;
        token_link(tail) = lmt_token_memory_state.available;
        lmt_token_memory_state.available = head;
    }
}

void tex_flush_token_list_head_tail(halfword head, halfword tail, int n)
{
    if (head) {
        lmt_token_memory_state.tokens_data.ptr -= n;
        token_link(tail) = lmt_token_memory_state.available;
        lmt_token_memory_state.available = head;
    }
}

void tex_add_token_reference(halfword p)
{
    if (get_token_reference(p) < max_token_reference) {
        add_token_reference(p);
 //   } else {
 //       tex_overflow_error("reference count", max_token_reference);
    }
}

void tex_increment_token_reference(halfword p, int n)
{
    if ((get_token_reference(p) + n) < max_token_reference) {
        inc_token_reference(p, n);
    } else { 
        inc_token_reference(p, max_token_reference - get_token_reference(p));
 // } else {
 //     tex_overflow_error("reference count", max_token_reference);
    }
}

// void tex_delete_token_reference(halfword p)
// {
//     if (p) {
//         if (get_token_reference(p)) {
//             sub_token_reference(p);
//         } else {
//             tex_flush_token_list(p);
//         }
//     }
// }

void tex_delete_token_reference(halfword p)
{
    if (p) {
        halfword r = get_token_reference(p);
        if (! r) {
            tex_flush_token_list(p);
        } if(r < max_token_reference) {
            sub_token_reference(p);
        }
    }
}

/*tex

    A \TEX\ token is either a character or a control sequence, and it is represented internally in
    one of two ways:

    \startitemize[n]
        \startitem
            A character whose ASCII code number is |c| and whose command code is |m| is represented
            as the number $2^{21}m+c$; the command code is in the range |1 <= m <= 14|.
        \stopitem
        \startitem
            A control sequence whose |eqtb| address is |p| is represented as the number
            |cs_token_flag+p|. Here |cs_token_flag = t =| $2^{25}-1$ is larger than $2^{21}m+c$, yet
            it is small enough that |cs_token_flag + p < max_halfword|; thus, a token fits
            comfortably in a halfword.
        \stopitem
    \stopitemize

    A token |t| represents a |left_brace| command if and only if |t < left_brace_limit|; it
    represents a |right_brace| command if and only if we have |left_brace_limit <= t <
    right_brace_limit|; and it represents a |match| or |end_match| command if and only if
    |match_token <= t <= end_match_token|. The following definitions take care of these
    token-oriented constants and a few others.

    A token list is a singly linked list of one-word nodes in |mem|, where each word contains a token
    and a link. Macro definitions, output routine definitions, marks, |\write| texts, and a few other
    things are remembered by \TEX\ in the form of token lists, usually preceded by a node with a
    reference count in its |token_ref_count| field. The token stored in location |p| is called
    |info(p)|.

    Three special commands appear in the token lists of macro definitions. When |m = match|, it means
    that \TEX\ should scan a parameter for the current macro; when |m = end_match|, it means that
    parameter matching should end and \TEX\ should start reading the macro text; and when |m =
    out_param|, it means that \TEX\ should insert parameter number |c| into the text at this point.

    The enclosing |\char'173| and |\char'175| characters of a macro definition are omitted, but the
    final right brace of an output routine is included at the end of its token list.

    Here is an example macro definition that illustrates these conventions. After \TEX\ processes
    the text:

    \starttyping
    \def\mac a#1#2 \b {#1\-a ##1#2 \#2\}
    \stoptyping

    The definition of |\mac| is represented as a token list containing:

    \starttyping
    (reference count) letter a match # match # spacer \b end_match
    out_param1 \- letter a spacer, mac_param # other_char 1
    out_param2 spacer out_param 2
    \stoptyping

    The procedure |scan_toks| builds such token lists, and |macro_call| does the parameter matching.

    Examples such as |\def \m {\def \m {a} b}| explain why reference counts would be needed even if
    \TEX\ had no |\let| operation: When the token list for |\m| is being read, the redefinition of
    |\m| changes the |eqtb| entry before the token list has been fully consumed, so we dare not
    simply destroy a token list when its control sequence is being redefined.

    If the parameter-matching part of a definition ends with |#{}|, the corresponding token list
    will have |{| just before the |end_match| and also at the very end. The first |{| is used to
    delimit the parameter; the second one keeps the first from disappearing.

    The |print_meaning| subroutine displays |cur_cmd| and |cur_chr| in symbolic form, including the
    expansion of a macro or mark.

*/

void tex_print_meaning(halfword code)
{
    /*tex

    This would make sense but some macro packages don't like it:

    \starttyping
    if (cur_cmd == math_given_cmd) {
        cur_cmd = math_xgiven_cmd ;
    }
    \stoptyping

    Eventually we might just do it that way. We also can have |\meaningonly| that omits the
    |macro:| and arguments.
    */
    int untraced = is_untraced(eq_flag(cur_cs));
    if (! untraced) {
        switch (code) {
            case meaning_code:
            case meaning_full_code:
            case meaning_asis_code:
                tex_print_cmd_flags(cur_cs, cur_cmd, (code == meaning_full_code || code == meaning_asis_code), code == meaning_asis_code);
                break;
        }
    }
    switch (cur_cmd) {
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case tolerant_call_cmd:
        case tolerant_protected_call_cmd:
        case tolerant_semi_protected_call_cmd:
            if (untraced) {
                tex_print_cs(cur_cs);
                return;
            } else {
                int constant = (cur_chr && get_token_reference(cur_chr) == max_token_reference);
                switch (code) {
                    case meaning_code:
                    case meaning_full_code:
                        if (constant) {
                            tex_print_str("constant ");
                        }
                        tex_print_str("macro");
                        goto FOLLOWUP;
                    case meaning_asis_code:
                        if (constant) {
                            tex_print_str_esc("constant ");
                        }
                     // tex_print_format("%e%C %S ", def_cmd, def_code, cur_cs);
                        tex_print_cmd_chr(def_cmd, def_code);
                        tex_print_char(' ');
                        tex_print_cs(cur_cs);
                        tex_print_char(' ');
                        if (cur_chr && token_link(cur_chr)) {
                            halfword body = get_token_preamble(cur_chr) ? tex_show_token_list(token_link(cur_chr), null, default_token_show_max, 1) : token_link(cur_chr);
                            tex_print_char('{');
                            if (body) {
                                tex_show_token_list(body, null, default_token_show_max, 0);
                            }
                            tex_print_char('}');
                        }
                        return;
                }
                goto DETAILS;
            }
        case get_mark_cmd:
            tex_print_cmd_chr((singleword) cur_cmd, cur_chr);
            tex_print_char(':');
            tex_print_nlp();
            tex_token_show(tex_get_some_mark(cur_chr, 0), default_token_show_max);
            return;
        case lua_value_cmd:
        case lua_call_cmd:
        case lua_local_call_cmd:
        case lua_protected_call_cmd:
            if (untraced) {
                tex_print_cs(cur_cs);
                return;
            } else {
                goto DEFAULT;
            }
        case if_test_cmd:
            if (cur_chr > last_if_test_code) {
                tex_print_cs(cur_cs);
                return;
            } else {
                goto DEFAULT;
            }
        default:
         DEFAULT:
            tex_print_cmd_chr((singleword) cur_cmd, cur_chr);
            if (cur_cmd < call_cmd) {
                return;
            } else {
                /* all kind of reference cmds */
                break;
            }
    }
  FOLLOWUP:
    tex_print_char(':');
  DETAILS:
    tex_print_nlp();
    tex_token_show(cur_chr, default_token_show_max);
}

/*tex

    The procedure |show_token_list|, which prints a symbolic form of the token list that starts at
    a given node |p|, illustrates these conventions. The token list being displayed should not begin
    with a reference count. However, the procedure is intended to be robust, so that if the memory
    links are awry or if |p| is not really a pointer to a token list, nothing catastrophic will
    happen.

    An additional parameter |q| is also given; this parameter is either null or it points to a node
    in the token list where a certain magic computation takes place that will be explained later.
    Basically, |q| is non-null when we are printing the two-line context information at the time of
    an error message; |q| marks the place corresponding to where the second line should begin.

    For example, if |p| points to the node containing the first |a| in the token list above, then
    |show_token_list| will print the string

    \starttyping
    a#1#2 \b ->#1-a ##1#2 #2
    \stoptyping

    and if |q| points to the node containing the second |a|, the magic computation will be performed
    just before the second |a| is printed.

    The generation will stop, and |\ETC.| will be printed, if the length of printing exceeds a given
    limit~|l|. Anomalous entries are printed in the form of control sequences that are not followed
    by a blank space, e.g., |\BAD.|; this cannot be confused with actual control sequences because a
    real control sequence named |BAD| would come out |\BAD |.

    In \LUAMETATEX\ we have some more node types and token types so we also have additional tracing.
    Because there is some more granularity in for instance nodes (subtypes) more detail is reported.

*/

static const char *tex_aux_special_cmd_string(halfword cmd, halfword chr, const char *unknown)
{
    switch (cmd) {
        case node_cmd               : return "[[special cmd: node pointer]]";
        case lua_protected_call_cmd : return "[[special cmd: lua protected call]]";
        case lua_value_cmd          : return "[[special cmd: lua value call]]";
        case iterator_value_cmd     : return "[[special cmd: iterator value]]";
        case lua_call_cmd           : return "[[special cmd: lua call]]";
        case lua_local_call_cmd     : return "[[special cmd: lua local call]]";
        case begin_local_cmd        : return "[[special cmd: begin local call]]";
        case end_local_cmd          : return "[[special cmd: end local call]]";
     // case prefix_cmd             : return "[[special cmd: enforced]]";
        case prefix_cmd             : return "\\always ";
        default                     : printf("[[unknown cmd: (%i,%i)]\n", cmd, chr); return unknown;
    }
}

halfword tex_show_token_list(halfword p, halfword q, int l, int asis)
{
    if (p) {
        /*tex the highest parameter number, as an \ASCII\ digit */
        unsigned char n = 0;
        int min = 0;
        int max = lmt_token_memory_state.tokens_data.top;
        lmt_print_state.tally = 0;
//        if (l <= 0) {
            l = extreme_token_show_max;
//        }
        while (p && (lmt_print_state.tally < l)) {
            if (p == q) {
                /*tex Do magic computation. We only end up here in context showing. */
                tex_set_trick_count();
            }
            /*tex Display token |p|, and |return| if there are problems. */
            if (p < min || p > max) {
                tex_print_str(error_string_clobbered(41));
                return null;
            } else if (token_info(p) >= cs_token_flag) {
             // if (! ((print_state.inhibit_par_tokens) && (token_info(p) == token_state.par_token))) {
                    tex_print_cs_checked(token_info(p) - cs_token_flag);
             // }
            } else if (token_info(p) < 0) {
                tex_print_str(error_string_bad(42));
            } else if (token_info(p) == 0) {
                tex_print_str(error_string_bad(44));
            } else {
                int cmd = token_cmd(token_info(p));
                int chr = token_chr(token_info(p));
                /*
                    Display the token (|cmd|,|chr|). The procedure usually \quote {learns} the character
                    code used for macro parameters by seeing one in a |match| command before it runs
                    into any |out_param| commands.

                */
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
                    case ignore_cmd: /* new */
                        tex_print_tex_str(chr);
                        break;
                    case parameter_cmd:
                        if (! lmt_token_state.in_lua_escape && (lmt_expand_state.cs_name_level == 0)) {
                            tex_print_tex_str(chr);
                        }
                        tex_print_tex_str(chr);
                        break;
                    case parameter_reference_cmd:
                        tex_print_tex_str(match_visualizer);
                        if (chr <= 9) {
                            tex_print_char(chr + '0');
                        } else if (chr <= max_match_count) {
                            tex_print_char(chr + '0' + gap_match_count);
                        } else {
                            tex_print_char('!');
                            return null;
                        }
                        break;
                    case match_cmd:
                        tex_print_char(match_visualizer);
                        if (is_valid_match_ref(chr)) {
                            ++n;
                        }
                        tex_print_char(chr ? chr : '0');
                        if (n > max_match_count) {
                            /*tex Can this happen at all? */
                            return null;
                        } else {
                            break;
                        }
                    case end_match_cmd:
                        if (asis) {
                            return token_link(p);
                        } else if (chr == 0) {
                            tex_print_str("->");
                        }
                        break;
                    case ignore_something_cmd:
                        break;
                    case set_font_cmd:
                        tex_print_format("[font->%s]", font_original(cur_val));
                        break;
                    case end_paragraph_cmd:
                        tex_print_format("%e%s", "par ");
                        break;
                    default:
                        tex_print_str(tex_aux_special_cmd_string(cmd, chr, error_string_bad(43)));
                        break;
                }
            }
            p = token_link(p);
        }
        if (p) {
            tex_print_str_esc("ETC.");
        }
    }
    return p;
}

/*
# define do_buffer_to_unichar(a,b) do { \
    a = (halfword)str2uni(fileio_state.io_buffer+b); \
    b += utf8_size(a); \
} while (0)
*/

inline static halfword get_unichar_from_buffer(int *b)
{
    halfword a = (halfword) ((const unsigned char) *(lmt_fileio_state.io_buffer + *b));
    if (a <= 0x80) {
        *b += 1;
    } else {
        int al; 
        a = (halfword) aux_str2uni_len(lmt_fileio_state.io_buffer + *b, &al);
        *b += al;
    }
    return a;
}

/*tex

    Here's the way we sometimes want to display a token list, given a pointer to its reference count;
    the pointer may be null.

*/

void tex_token_show(halfword p, int max)
{
    if (p && token_link(p)) {
        tex_show_token_list(token_link(p), null, max, 0);
    }
}

/*tex

    The next function, |delete_token_ref|, is called when a pointer to a token list's reference
    count is being removed. This means that the token list should disappear if the reference count
    was |null|, otherwise the count should be decreased by one. Variable |p| points to the reference
    count of a token list that is losing one reference.

*/

int tex_get_char_cat_code(int c)
{
    return tex_aux_the_cat_code(c);
}

static void tex_aux_invalid_character_error(void)
{
    tex_handle_error(
        normal_error_type,
        "Text line contains an invalid character",
        "A funny symbol that I can't read has just been input. Continue, and I'll forget\n"
        "that it ever happened."
    );
}

static int tex_aux_process_sup_mark(void);

static int tex_aux_scan_control_sequence(void);

typedef enum next_line_retval {
    next_line_ok,
    next_line_return,
    next_line_restart
} next_line_retval;

static next_line_retval tex_aux_next_line(void);

/*tex

    In case you are getting bored, here is a slightly less trivial routine: Given a string of
    lowercase letters, like |pt| or |plus| or |width|, the |scan_keyword| routine checks to see
    whether the next tokens of input match this string. The match must be exact, except that
    ppercase letters will match their lowercase counterparts; uppercase equivalents are determined
    by subtracting |"a" - "A"|, rather than using the |uc_code| table, since \TEX\ uses this
    routine only for its own limited set of keywords.

    If a match is found, the characters are effectively removed from the input and |true| is
    returned. Otherwise |false| is returned, and the input is left essentially unchanged (except
    for the fact that some macros may have been expanded, etc.).

    In \LUATEX\ and its follow up we have more keywords and for instance when scanning a box
    specification that is noticeable because the |scan_keyword| function is a little inefficient
    in the sense that when there is no match, it will push back what got read so far. So there is
    token allocation, pushing a level etc involved. Keep in mind that expansion happens here so what
    gets pushing back is not always literally pushing back what we started with.

    In \LUAMETATEX\ we now have a bit different approach. The |scan_mandate_keyword| follows up on
    |scan_character| so we have a two step approach. We could actually pass a list of valid keywords
    but that would make for a complex function with no real benefits.

*/

halfword tex_scan_character(const char *s, int left_brace, int skip_space, int skip_relax)
{
    halfword save_cur_cs = cur_cs;
//    (void) skip_space; /* some day */
    while (1) {
        tex_get_x_token();
        switch (cur_cmd) {
            case spacer_cmd:
                if (skip_space) {
                    break;
                } else {
                    goto DONE;
                }
            case relax_cmd:
                if (skip_relax) {
                    break;
                } else {
                    goto DONE;
                }
            case letter_cmd:
            case other_char_cmd:
                if (cur_chr <= 'z' && strchr(s, cur_chr)) {
                    cur_cs = save_cur_cs;
                    return cur_chr;
                } else {
                    goto DONE;
                }
            case left_brace_cmd:
                if (left_brace) {
                    cur_cs = save_cur_cs;
                    return '{';
                } else {
                    goto DONE;
                }
            default:
                goto DONE;
        }
    }
  DONE:
    tex_back_input(cur_tok);
    cur_cs = save_cur_cs;
    return 0;
}

void tex_aux_show_keyword_error(const char *s)
{
    tex_handle_error(
        normal_error_type,
        "Valid keyword expected, likely '%s'",
        s,
        "You started a keyword but it seems to be an invalid one. The first character(s)\n"
        "might give you a clue. You might want to quit unwanted lookahead with \\relax."
    );
}

/*tex
    Scanning an optional keyword starts at the beginning. This means that we can also (for instance)
    have a minus or plus sign which means that we have a different loop than with the alternative
    that already checked the first character.
*/

int tex_scan_optional_keyword(const char *s)
{
    halfword save_cur_cs = cur_cs;
    int done = 0;
    const char *p = s;
    while (*p) {
        tex_get_x_token();
        switch (cur_cmd) {
            case letter_cmd:
            case other_char_cmd:
                if ((cur_chr == *p) || (cur_chr == *p - 'a' + 'A')) {
                    if (*(++p)) {
                        done = 1;
                    } else {
                        cur_cs = save_cur_cs;
                        return 1;
                    }
                } else if (done) {
                    goto BAD_NEWS;
                } else {
                    // can be a minus or so ! as in \advance\foo -10
                    tex_back_input(cur_tok);
                    cur_cs = save_cur_cs;
                    return 1;
                }
                break;
            case spacer_cmd:  /* normally spaces are not pushed back */
                if (done) {
                    goto BAD_NEWS;
                } else {
                    break;
                }
                // fall through
            default:
                tex_back_input(cur_tok);
                if (done) {
                    /* unless we accept partial keywords */
                    goto BAD_NEWS;
                } else {
                    cur_cs = save_cur_cs;
                    return 0;
                }
        }
    }
  BAD_NEWS:
    tex_aux_show_keyword_error(s);
    cur_cs = save_cur_cs;
    return 0;
}

/*tex
    Here we know that the first character(s) matched so we are in the middle of a keyword already
    which means a different loop than the previous one. 
*/

int tex_scan_mandate_keyword(const char *s, int offset)
{
    halfword save_cur_cs = cur_cs;
    int done = 0;
 // int done = offset > 0;
    const char *p = s + offset; /* offset always > 0 so no issue with +/- */
    while (*p) {
        tex_get_x_token();
        switch (cur_cmd) {
            case letter_cmd:
            case other_char_cmd:
                if ((cur_chr == *p) || (cur_chr == *p - 'a' + 'A')) {
                    if (*(++p)) {
                        done = 1;
                    } else {
                        cur_cs = save_cur_cs;
                        return 1;
                    }
                } else {
                    goto BAD_NEWS;
                }
                break;
         // case spacer_cmd:  /* normally spaces are not pushed back */
         // case relax_cmd:   /* normally not, should be option  */
         //     if (done) {
         //         back_input(cur_tok);
         //         goto BAD_NEWS;
         //     } else {
         //         break;
         //     }
         // default:
         //     goto BAD_NEWS;
            case spacer_cmd:  /* normally spaces are not pushed back */
                if (done) {
                    goto BAD_NEWS;
                } else {
                    break;
                }
                // fall through
            default:
                tex_back_input(cur_tok);
                /* unless we accept partial keywords */
                goto BAD_NEWS;
        }
    }
  BAD_NEWS:
    tex_aux_show_keyword_error(s);
    cur_cs = save_cur_cs;
    return 0;
}

/*
    This is the original scanner with push|-|back. It's a matter of choice: we are more restricted
    on the one hand and more loose on the other.
*/

int tex_scan_keyword(const char *s)
{
    if (*s) {
        halfword h = null;
        halfword p = null;
        halfword save_cur_cs = cur_cs;
        int n = 0;
        while (*s) {
            /*tex Recursion is possible here! */
            tex_get_x_token();
            if ((cur_cmd == letter_cmd || cur_cmd == other_char_cmd) && ((cur_chr == *s) || (cur_chr == *s - 'a' + 'A'))) {
                p = tex_store_new_token(p, cur_tok);
                if (! h) {
                    h = p;
                }
                n++;
                s++;
            } else if ((p != h) || (cur_cmd != spacer_cmd)) {
                tex_back_input(cur_tok);
                if (h) {
                    tex_begin_backed_up_list(h);
                }
                cur_cs = save_cur_cs;
                return 0;
            }
        }
        if (h) {
            tex_flush_token_list_head_tail(h, p, n);
        }
        cur_cs = save_cur_cs;
        return 1;
    } else {
        /*tex but not with newtokenlib zero keyword simply doesn't match  */
        return 0 ;
    }
}

int tex_scan_keyword_case_sensitive(const char *s)
{
    if (*s) {
        halfword h = null;
        halfword p = null;
        halfword save_cur_cs = cur_cs;
        int n = 0;
        while (*s) {
            tex_get_x_token();
            if ((cur_cmd == letter_cmd || cur_cmd == other_char_cmd) && (cur_chr == *s)) {
                p = tex_store_new_token(p, cur_tok);
                if (! h) {
                    h = p;
                }
                n++;
                s++;
            } else if ((p != h) || (cur_cmd != spacer_cmd)) {
                tex_back_input(cur_tok);
                if (h) {
                    tex_begin_backed_up_list(h);
                }
                cur_cs = save_cur_cs;
                return 0;
            }
        }
        if (h) {
            tex_flush_token_list_head_tail(h, p, n);
        }
        cur_cs = save_cur_cs;
        return 1;
    } else {
        return 0 ;
    }
}

/*tex

    We can not return |undefined_control_sequence| under some conditions (inside |shift_case|,
    for example). This needs thinking.

*/

halfword tex_active_to_cs(int c, int force)
{
    halfword cs = -1;
    if (c >= 0 && c <= max_character_code) {
        char utfbytes[8] = { active_character_first, active_character_second, active_character_third, 0 };
        aux_uni2string((char *) &utfbytes[3], c);
        cs = tex_string_locate(utfbytes, (size_t) utf8_size(c) + 3, force);
    }
    if (cs < 0) {
        cs = tex_string_locate(active_character_unknown, 4, force); /*tex Including the zero sentinel. */
    }
    return cs;
}

/*tex

    The heart of \TEX's input mechanism is the |get_next| procedure, which we shall develop in the
    next few sections of the program. Perhaps we shouldn't actually call it the \quote {heart},
    however, because it really acts as \TEX's eyes and mouth, reading the source files and
    gobbling them up. And it also helps \TEX\ to regurgitate stored token lists that are to be
    processed again.

    The main duty of |get_next| is to input one token and to set |cur_cmd| and |cur_chr| to that
    token's command code and modifier. Furthermore, if the input token is a control sequence, the
    |eqtb| location of that control sequence is stored in |cur_cs|; otherwise |cur_cs| is set to
    zero.

    Underlying this simple description is a certain amount of complexity because of all the cases
    that need to be handled. However, the inner loop of |get_next| is reasonably short and fast.

    When |get_next| is asked to get the next token of a |\read| line, it sets |cur_cmd = cur_chr
    = cur_cs = 0| in the case that no more tokens appear on that line. (There might not be any
    tokens at all, if the |end_line_char| has |ignore| as its catcode.)

    The value of |par_loc| is the |eqtb| address of |\par|. This quantity is needed because a
    blank line of input is supposed to be exactly equivalent to the appearance of |\par|; we must
    set |cur_cs := par_loc| when detecting a blank line.

    Parts |get_next| are executed more often than any other instructions of \TEX. The global
    variable |force_eof| is normally |false|; it is set |true| by an |\endinput| command.
    |luacstrings| is the number of lua print statements waiting to be input, it is changed by
    |lmt_token_call|.

    If the user has set the |pausing| parameter to some positive value, and if nonstop mode has
    not been selected, each line of input is displayed on the terminal and the transcript file,
    followed by |=>|. \TEX\ waits for a response. If the response is simply |carriage_return|,
    the line is accepted as it stands, otherwise the line typed is used instead of the line in the
    file.

    We no longer need the following:

*/

// void firm_up_the_line(void)
// {
//     ilimit = fileio_state.io_last;
// }

/*tex

    The other variant gives less clutter in tracing cache usage when profiling and for some files
    (like the manual) also a bit of a speedup. Splitting the switch which gives 10 times less Bim
    in vallgrind! See the \LUATEX\ source for that code.

    The big switch changes the state if necessary, and |goto switch| if the current character
    should be ignored, or |goto reswitch| if the current character changes to another.

    The n-way switch accomplishes the scanning quickly, assuming that a decent \CCODE\ compiler
    has translated the code. Note that the numeric values for |mid_line|, |skip_blanks|, and
    |new_line| are spaced apart from each other by |max_char_code+1|, so we can add a character's
    command code to the state to get a single number that characterizes both.

    Remark: checking performance indicated that this switch was the cause of many branch prediction
    errors but changing it to:

    \starttyping
    c = istate + cur_cmd;
    if (c == (mid_line_state + letter_cmd) || c == (mid_line_state + other_char_cmd)) {
        return 1;
    } else if (c >= new_line_state) {
        switch (c) {
        }
    } else if (c >= skip_blanks_state) {
        switch (c) {
        }
    } else if (c >= mid_line_state) {
        switch (c) {
        }
    } else {
        istate = mid_line_state;
        return 1;
    }
    \stoptyping

    This gives as many prediction errors. So, we can indeed assume that the compiler does the right
    job, or that there is simply no other way.

    When a line is finished a space is emited. When a character of type |spacer| gets through, its
    character code is changed to |\ =040|. This means that the \ASCII\ codes for tab and space, and
    for the space inserted at the end of a line, will be treated alike when macro parameters are
    being matched. We do this since such characters are indistinguishable on most computer terminal
    displays.

*/

/*

    c = istate + cur_cmd;
    if (c == (mid_line_state + letter_cmd) || c == (mid_line_state + other_char_cmd)) {
        return 1;
    } else if (c >= new_line_state) {
        ....
    }

*/

/*tex

    This trick has been dropped when the wrapup mechanism had proven to be useful. The idea was
    to backport this to \LUATEX\ but some other \PDFTEX\ compatible parstuff made it there and
    backporting par related features becomes too messy.

    \starttyping
    lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
    cur_cs = lmt_token_state.line_par_loc;
    cur_cmd = eq_type(cur_cs);
    if (cur_cmd == undefined_cs_cmd) {
        cur_cs = lmt_token_state.par_loc;
        cur_cmd = eq_type(cur_cs);
    }
    cur_chr = eq_value(cur_cs);
    \stoptyping

*/

static int tex_aux_get_next_file(void)
{
  SWITCH:
    if (lmt_input_state.cur_input.loc <= lmt_input_state.cur_input.limit) {
        /*tex current line not yet finished */
        cur_chr = get_unichar_from_buffer(&lmt_input_state.cur_input.loc);
      RESWITCH:
        if (lmt_input_state.cur_input.cattable == no_catcode_table_preset) {
            /* happens seldom: detokenized line */
            cur_cmd = cur_chr == ' ' ? 10 : 12;
        } else {
            cur_cmd = tex_aux_the_cat_code(cur_chr);
        }
        switch (lmt_input_state.cur_input.state + cur_cmd) {
            case mid_line_state    + ignore_cmd:
            case skip_blanks_state + ignore_cmd:
            case new_line_state    + ignore_cmd:
            case skip_blanks_state + spacer_cmd:
            case new_line_state    + spacer_cmd:
                /*tex Cases where character is ignored. */
                goto SWITCH;
            case mid_line_state    + escape_cmd:
            case new_line_state    + escape_cmd:
            case skip_blanks_state + escape_cmd:
                /*tex Scan a control sequence. */
                lmt_input_state.cur_input.state = (unsigned char) tex_aux_scan_control_sequence();
                break;
            case mid_line_state    + active_char_cmd:
            case new_line_state    + active_char_cmd:
            case skip_blanks_state + active_char_cmd:
                /*tex Process an active-character. */
                if ((lmt_input_state.scanner_status == scanner_is_tolerant || lmt_input_state.scanner_status == scanner_is_matching) && tex_pass_active_math_char(cur_chr)) {
                    /*tex We need to intercept a delimiter in arguments. */
                } else if ((lmt_input_state.scanner_status == scanner_is_defining || lmt_input_state.scanner_status == scanner_is_absorbing) && tex_pass_active_math_char(cur_chr)) {
                    /*tex We are storing stuff in a token list or macro body. */
                } else if ((cur_mode == mmode || lmt_nest_state.math_mode) && tex_check_active_math_char(cur_chr)) {
                    /*tex We have an intercept. */
                } else { 
                    cur_cs = tex_active_to_cs(cur_chr, ! lmt_hash_state.no_new_cs);
                    cur_cmd = eq_type(cur_cs);
                    cur_chr = eq_value(cur_cs);
                }
                lmt_input_state.cur_input.state = mid_line_state;
                break;
            case mid_line_state    + superscript_cmd:
            case new_line_state    + superscript_cmd:
            case skip_blanks_state + superscript_cmd:
                /*tex We need to check for multiple ^:
                    (0) always check for ^^ ^^^^ ^^^^^^^
                    (1) only check in text mode
                    (*) never
                */
                if (sup_mark_mode_par) {
                    if (sup_mark_mode_par == 1 && cur_mode != mmode && tex_aux_process_sup_mark()) {
                        goto RESWITCH;
                    }
                } else if (tex_aux_process_sup_mark()) {
                    goto RESWITCH;
                } else {
                    /*tex
                        We provide prescripts and shifted script in math mode and avoid fance |^|
                        processing in text mode (which is what we do in \CONTEXT).
                    */
                }
                lmt_input_state.cur_input.state = mid_line_state;
                break;
            case mid_line_state    + invalid_char_cmd:
            case new_line_state    + invalid_char_cmd:
            case skip_blanks_state + invalid_char_cmd:
                /*tex Decry the invalid character and |goto restart|. */
                tex_aux_invalid_character_error();
                /*tex Because state may be |token_list| now: */
                return 0;
            case mid_line_state + spacer_cmd:
                /*tex Enter |skip_blanks| state, emit a space. */
                lmt_input_state.cur_input.state = skip_blanks_state;
                cur_chr = ' ';
                break;
            case mid_line_state + end_line_cmd:
                /*tex Finish the line. See note above about dropped |\linepar|. */
                lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
                cur_cmd = spacer_cmd;
                cur_chr = ' ';
                break;
            case skip_blanks_state + end_line_cmd:
            case mid_line_state    + comment_cmd:
            case new_line_state    + comment_cmd:
            case skip_blanks_state + comment_cmd:
                /*tex Finish line, |goto switch|; */
                lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
                goto SWITCH;
            case new_line_state + end_line_cmd:
                if (! auto_paragraph_mode(auto_paragraph_go_on)) {
                    lmt_input_state.cur_input.loc = lmt_input_state.cur_input.limit + 1;
                }
                /*tex Finish line, emit a |\par|; */
                if (auto_paragraph_mode(auto_paragraph_text))  {
                    cur_cs = null;
                    cur_cmd = end_paragraph_cmd;
                    cur_chr = new_line_end_paragraph_code;
                 // cur_chr = normal_end_paragraph_code;
                } else {
                    cur_cs = lmt_token_state.par_loc;
                    cur_cmd = eq_type(cur_cs);
                    cur_chr = eq_value(cur_cs);
                }
                break;
            case skip_blanks_state + left_brace_cmd:
            case new_line_state    + left_brace_cmd:
                lmt_input_state.cur_input.state = mid_line_state;
                lmt_input_state.align_state++;
                break;
            case mid_line_state + left_brace_cmd:
                lmt_input_state.align_state++;
                break;
            case skip_blanks_state + right_brace_cmd:
            case new_line_state    + right_brace_cmd:
                lmt_input_state.cur_input.state = mid_line_state;
                lmt_input_state.align_state--;
                break;
            case mid_line_state + right_brace_cmd:
                lmt_input_state.align_state--;
                break;
            case mid_line_state + math_shift_cmd:
            case mid_line_state + alignment_tab_cmd:
            case mid_line_state + parameter_cmd:
            case mid_line_state + subscript_cmd:
            case mid_line_state + letter_cmd:
            case mid_line_state + other_char_cmd:
                break;
            /*
            case skip_blanks_state + math_shift_cmd:
            case skip_blanks_state + tab_mark_cmd:
            case skip_blanks_state + mac_param_cmd:
            case skip_blanks_state + sub_mark_cmd:
            case skip_blanks_state + letter_cmd:
            case skip_blanks_state + other_char_cmd:
            case new_line_state    + math_shift_cmd:
            case new_line_state    + tab_mark_cmd:
            case new_line_state    + mac_param_cmd:
            case new_line_state    + sub_mark_cmd:
            case new_line_state    + letter_cmd:
            case new_line_state    + other_char_cmd:
            */
            default:
                lmt_input_state.cur_input.state = mid_line_state;
                break;
        }
    } else {
        if (! io_token_input(lmt_input_state.cur_input.name)) {
            lmt_input_state.cur_input.state = new_line_state;
        }
        /*tex

           Move to next line of file, or |goto restart| if there is no next line, or |return| if a
           |\read| line has finished.

        */
        do {
            next_line_retval r = tex_aux_next_line();
            if (r == next_line_restart) {
                /*tex This happens more often. */
                return 0;
            } else if (r == next_line_return) {
                return 1;
            }
        } while (0);
     /* check_interrupt(); */
        goto SWITCH;
    }
    return 1;
}

/*tex

    Notice that a code like |^^8| becomes |x| if not followed by a hex digit. We only support a
    limited set:

    \starttyping
    ^^^^^^XXXXXX
    ^^^^XXXXXX
    ^^XX ^^<char>
    \stoptyping

*/

# define is_hex(a) ((a >= '0' && a <= '9') || (a >= 'a' && a <= 'f'))

 inline static halfword tex_aux_two_hex_to_cur_chr(int c1, int c2)
 {
   return
        0x10 * (c1 <= '9' ? c1 - '0' : c1 - 'a' + 10)
      + 0x01 * (c2 <= '9' ? c2 - '0' : c2 - 'a' + 10);
 }

 inline static halfword tex_aux_four_hex_to_cur_chr(int c1, int c2,int c3, int c4)
 {
   return
         0x1000 * (c1 <= '9' ? c1 - '0' : c1 - 'a' + 10)
       + 0x0100 * (c2 <= '9' ? c2 - '0' : c2 - 'a' + 10)
       + 0x0010 * (c3 <= '9' ? c3 - '0' : c3 - 'a' + 10)
       + 0x0001 * (c4 <= '9' ? c4 - '0' : c4 - 'a' + 10);
}

inline static halfword tex_aux_six_hex_to_cur_chr(int c1, int c2, int c3, int c4, int c5, int c6)
{
   return
         0x100000 * (c1 <= '9' ? c1 - '0' : c1 - 'a' + 10)
       + 0x010000 * (c2 <= '9' ? c2 - '0' : c2 - 'a' + 10)
       + 0x001000 * (c3 <= '9' ? c3 - '0' : c3 - 'a' + 10)
       + 0x000100 * (c4 <= '9' ? c4 - '0' : c4 - 'a' + 10)
       + 0x000010 * (c5 <= '9' ? c5 - '0' : c5 - 'a' + 10)
       + 0x000001 * (c6 <= '9' ? c6 - '0' : c6 - 'a' + 10);

}

static int tex_aux_process_sup_mark(void)
{
    if (cur_chr == lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc]) {
        if (lmt_input_state.cur_input.loc < lmt_input_state.cur_input.limit) {
            if ((cur_chr == lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 1]) && (cur_chr == lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 2])) {
                if ((cur_chr == lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 3]) && (cur_chr == lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 4])) {
                    if ((lmt_input_state.cur_input.loc + 10) <= lmt_input_state.cur_input.limit) {
                        /*tex |^^^^^^XXXXXX| */
                        int c1 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc +  5];
                        int c2 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc +  6];
                        int c3 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc +  7];
                        int c4 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc +  8];
                        int c5 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc +  9];
                        int c6 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 10];
                        if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4) && is_hex(c5) && is_hex(c6)) {
                            lmt_input_state.cur_input.loc += 11;
                            cur_chr = tex_aux_six_hex_to_cur_chr(c1, c2, c3, c4, c5, c6);
                            return 1;
                        } else {
                            tex_handle_error(
                                normal_error_type,
                                "^^^^^^ needs six hex digits",
                                NULL
                            );
                        }
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "^^^^^^ needs six hex digits, end of input",
                            NULL
                        );
                    }
                } else if ((lmt_input_state.cur_input.loc + 6) <= lmt_input_state.cur_input.limit) {
                /*tex |^^^^XXXX| */
                    int c1 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 3];
                    int c2 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 4];
                    int c3 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 5];
                    int c4 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 6];
                    if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4)) {
                        lmt_input_state.cur_input.loc += 7;
                        cur_chr = tex_aux_four_hex_to_cur_chr(c1, c2, c3, c4);
                        return 1;
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "^^^^ needs four hex digits",
                            NULL
                        );
                    }
                } else {
                    tex_handle_error(
                        normal_error_type,
                        "^^^^ needs four hex digits, end of input",
                        NULL
                    );
                }
            } else if ((lmt_input_state.cur_input.loc + 2) <= lmt_input_state.cur_input.limit) {
                /*tex |^^XX| */
                int c1 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 1];
                int c2 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 2];
                if (is_hex(c1) && is_hex(c2)) {
                    lmt_input_state.cur_input.loc += 3;
                    cur_chr = tex_aux_two_hex_to_cur_chr(c1, c2);
                    return 1;
                }
            }
            /*tex The single character case: */
            {
                int c1 = lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc + 1];
                if (c1 < 0200) {
                    lmt_input_state.cur_input.loc = lmt_input_state.cur_input.loc + 2;
                 // if (is_hex(c1) && (iloc <= ilimit)) {
                 //     int c2 = fileio_state.io_buffer[iloc];
                 //     if (is_hex(c2)) {
                 //         ++iloc;
                 //         cur_chr = two_hex_to_cur_chr(c1, c2);
                 //         return 1;
                 //     }
                 // }
                 // /*tex The somewhat odd cases, often special control characters: */
                    cur_chr = (c1 < 0100 ? c1 + 0100 : c1 - 0100);
                    return 1;
                }
            }
        }
    }
    return 0;
}

/*tex

    Control sequence names are scanned only when they appear in some line of a file. Once they have
    been scanned the first time, their |eqtb| location serves as a unique identification, so \TEX\
    doesn't need to refer to the original name any more except when it prints the equivalent in
    symbolic form.

    The program that scans a control sequence has been written carefully in order to avoid the
    blowups that might otherwise occur if a malicious user tried something like |\catcode'15 = 0|.
    The algorithm might look at |buffer[ilimit + 1]|, but it never looks at |buffer[ilimit + 2]|.

    If expanded characters like |^^A| or |^^df| appear in or just following a control sequence name,
    they are converted to single characters in the buffer and the process is repeated, slowly but
    surely.

*/

/*tex

    Whenever we reach the following piece of code, we will have |cur_chr = buffer[k - 1]| and |k <=
    ilimit + 1| and |cat = get_cat_code(cat_code_table, cur_chr)|. If an expanded code like |^^A| or
    |^^df| appears in |buffer[(k - 1) .. (k + 1)]| or |buffer[(k - 1) .. (k + 2)]|, we will store
    the corresponding code in |buffer[k - 1]| and shift the rest of the buffer left two or three
    places.

*/

static int tex_aux_check_expanded_code(int *kk, halfword *chr)
{
    if (sup_mark_mode_par > 1 || (sup_mark_mode_par == 1 && cur_mode == mmode)) {
        return 0;
    } else {
        int k = *kk;
        /* chr is the ^ character or an equivalent one */
        if (lmt_fileio_state.io_buffer[k] == *chr && k < lmt_input_state.cur_input.limit) {
            int d = 1;
            int l;
            if ((*chr == lmt_fileio_state.io_buffer[k + 1]) && (*chr == lmt_fileio_state.io_buffer[k + 2])) {
                if ((*chr == lmt_fileio_state.io_buffer[k + 3]) && (*chr == lmt_fileio_state.io_buffer[k + 4])) {
                    if ((k + 10) <= lmt_input_state.cur_input.limit) {
                        int c1 = lmt_fileio_state.io_buffer[k + 6 - 1];
                        int c2 = lmt_fileio_state.io_buffer[k + 6    ];
                        int c3 = lmt_fileio_state.io_buffer[k + 6 + 1];
                        int c4 = lmt_fileio_state.io_buffer[k + 6 + 2];
                        int c5 = lmt_fileio_state.io_buffer[k + 6 + 3];
                        int c6 = lmt_fileio_state.io_buffer[k + 6 + 4];
                        if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4) && is_hex(c5) && is_hex(c6)) {
                            d = 6;
                            *chr = tex_aux_six_hex_to_cur_chr(c1, c2, c3, c4, c5, c6);
                        } else {
                            tex_handle_error(
                                normal_error_type,
                                "^^^^^^ needs six hex digits",
                                NULL
                            );
                        }
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "^^^^^^ needs six hex digits, end of input",
                            NULL
                        );
                    }
                } else if ((k + 6) <= lmt_input_state.cur_input.limit) {
                    int c1 = lmt_fileio_state.io_buffer[k + 4 - 1];
                    int c2 = lmt_fileio_state.io_buffer[k + 4    ];
                    int c3 = lmt_fileio_state.io_buffer[k + 4 + 1];
                    int c4 = lmt_fileio_state.io_buffer[k + 4 + 2];
                    if (is_hex(c1) && is_hex(c2) && is_hex(c3) && is_hex(c4)) {
                        d = 4;
                        *chr = tex_aux_four_hex_to_cur_chr(c1, c2, c3, c4);
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "^^^^ needs four hex digits",
                            NULL
                        );
                    }
                } else {
                    tex_handle_error(
                        normal_error_type,
                        "^^^^ needs four hex digits, end of input",
                        NULL
                    );
                }
            } else {
                int c1 = lmt_fileio_state.io_buffer[k + 1];
                if (c1 < 0200) { /* really ? */
                    d = 1;
                    if (is_hex(c1) && (k + 2) <= lmt_input_state.cur_input.limit) {
                        int c2 = lmt_fileio_state.io_buffer[k + 2];
                        if (is_hex(c2)) {
                            d = 2;
                            *chr = tex_aux_two_hex_to_cur_chr(c1, c2);
                        } else {
                            *chr = (c1 < 0100 ? c1 + 0100 : c1 - 0100);
                        }
                    } else {
                        *chr = (c1 < 0100 ? c1 + 0100 : c1 - 0100);
                    }
                }
            }
            if (d > 2) {
                d = 2 * d - 1;
            } else {
                d++;
            }
            if (*chr <= 0x7F) {
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) *chr;
            } else if (*chr <= 0x7FF) {
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0xC0 + *chr / 0x40);
                k++;
                d--;
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0x80 + *chr % 0x40);
            } else if (*chr <= 0xFFFF) {
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0xE0 + *chr / 0x1000);
                k++;
                d--;
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0x80 + (*chr % 0x1000) / 0x40);
                k++;
                d--;
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0x80 + (*chr % 0x1000) % 0x40);
            } else {
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0xF0 + *chr / 0x40000);
                k++;
                d--;
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0x80 + (*chr % 0x40000) / 0x1000);
                k++;
                d--;
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0x80 + ((*chr % 0x40000) % 0x1000) / 0x40);
                k++;
                d--;
                lmt_fileio_state.io_buffer[k - 1] = (unsigned char) (0x80 + ((*chr % 0x40000) % 0x1000) % 0x40);
            }
            l = k;
            lmt_input_state.cur_input.limit -= d;
            while (l <= lmt_input_state.cur_input.limit) {
                lmt_fileio_state.io_buffer[l] = lmt_fileio_state.io_buffer[l + d];
                l++;
            }
            *kk = k;
            cur_chr = *chr; /* hm */
            return 1;
        } else {
            return 0;
        }
    }
}

static int tex_aux_scan_control_sequence(void)
{
    int state = mid_line_state;
    if (lmt_input_state.cur_input.loc > lmt_input_state.cur_input.limit) {
        /*tex |state| is irrelevant in this case. */
        cur_cs = null_cs;
    } else {
        /*tex |cat_code(cur_chr)|, usually: */
        while (1) {
            int loc = lmt_input_state.cur_input.loc;
            halfword chr = get_unichar_from_buffer(&loc);
            halfword cat = tex_aux_the_cat_code(chr);
            if (cat != letter_cmd || loc > lmt_input_state.cur_input.limit) {
                if (cat == spacer_cmd) {
                    state = skip_blanks_state;
                } else {
                    state = mid_line_state;
                    if (cat == superscript_cmd && tex_aux_check_expanded_code(&loc, &chr)) {
                        continue;
                    }
                }
             // state = cat == spacer_cmd ? skip_blanks_state : mid_line_state;
             // /*tex If an expanded \unknown */
             // if (cat == sup_mark_cmd && check_expanded_code(&loc, chr)) {
             //    continue;
             // }
            } else {
                state = skip_blanks_state;
                do {
                    chr = get_unichar_from_buffer(&loc);
                    cat = tex_aux_the_cat_code(chr);
                } while (cat == letter_cmd && loc <= lmt_input_state.cur_input.limit);
                /*tex If an expanded \unknown */
                if (cat == superscript_cmd && tex_aux_check_expanded_code(&loc, &chr)) {
                    continue;
                } else if (cat != letter_cmd) {
                    /*tex Backtrack one character which can be \UTF. */
                    if (chr <= 0x7F) {
                        loc -= 1; /* in most cases */
                    } else if (chr > 0xFFFF) {
                        loc -= 4;
                    } else if (chr > 0x7FF) {
                        loc -= 3;
                    } else /* if (cur_chr > 0x7F) */ {
                        loc -= 2;
                    }
                    /*tex Now |k| points to first nonletter. */
                }
            }
            cur_cs = tex_id_locate(lmt_input_state.cur_input.loc, loc - lmt_input_state.cur_input.loc, ! lmt_hash_state.no_new_cs);
            lmt_input_state.cur_input.loc = loc;
            break;
        }
    }
    cur_cmd = eq_type(cur_cs);
    cur_chr = eq_value(cur_cs);
    return state;
}

/*tex

    All of the easy branches of |get_next| have now been taken care of. There is one more branch.
    Conversely, the |file_warning| procedure is invoked when a file ends and some groups entered or
    conditionals started while reading from that file are still incomplete.

*/

static void tex_aux_file_warning(void)
{
    halfword cond_ptr = lmt_save_state.save_stack_data.ptr;  /*tex saved value of |save_ptr| or |cond_ptr| */
    int cur_if = cur_group;                                  /*tex saved value of |cur_group| or |cur_if| */
    int cur_unless = 0;
    int if_step = 0;
    int if_unless = 0;
    int if_limit = cur_level;                                /*tex saved value of |cur_level| or |if_limit| */
    int if_line = 0;                                         /*tex saved value of |if_line| */
    lmt_save_state.save_stack_data.ptr = cur_boundary;
    while (lmt_input_state.in_stack[lmt_input_state.in_stack_data.ptr].group != lmt_save_state.save_stack_data.ptr) {
        --cur_level;
        tex_print_nlp();
        tex_print_format("Warning: end of file when %G is incomplete", 1);
        cur_group = save_level(lmt_save_state.save_stack_data.ptr);
        lmt_save_state.save_stack_data.ptr = save_value(lmt_save_state.save_stack_data.ptr);
    }
    /*tex Restore old values. */
    lmt_save_state.save_stack_data.ptr = cond_ptr;
    cur_level = (quarterword) if_limit;
    cur_group = (quarterword) cur_if;
    cond_ptr = lmt_condition_state.cond_ptr;
    cur_if = lmt_condition_state.cur_if;
    cur_unless = lmt_condition_state.cur_unless;
    if_step = lmt_condition_state.if_step;
    if_unless = lmt_condition_state.if_unless;
    if_limit = lmt_condition_state.if_limit;
    if_line = lmt_condition_state.if_line;
    while (lmt_input_state.in_stack[lmt_input_state.in_stack_data.ptr].if_ptr != lmt_condition_state.cond_ptr) {
        /* todo, more info */
        tex_print_nlp();
        tex_print_format("Warning: end of file when %C", if_test_cmd, lmt_condition_state.cur_if);
        if (lmt_condition_state.if_limit == fi_code) {
            tex_print_str_esc("else");
        }
        if (lmt_condition_state.if_line) {
            tex_print_format(" entered on line %i", lmt_condition_state.if_line);
        }
        tex_print_str(" is incomplete");
        lmt_condition_state.cur_if = if_limit_subtype(lmt_condition_state.cond_ptr);
        lmt_condition_state.cur_unless = if_limit_unless(lmt_condition_state.cond_ptr);
        lmt_condition_state.if_step = if_limit_step(lmt_condition_state.cond_ptr);
        lmt_condition_state.if_unless = if_limit_stepunless(lmt_condition_state.cond_ptr);
        lmt_condition_state.if_limit = if_limit_type(lmt_condition_state.cond_ptr);
        lmt_condition_state.if_line = if_limit_line(lmt_condition_state.cond_ptr);
        lmt_condition_state.cond_ptr = node_next(lmt_condition_state.cond_ptr);
    }
    /*tex restore old values */
    lmt_condition_state.cond_ptr = cond_ptr;
    lmt_condition_state.cur_if = cur_if;
    lmt_condition_state.cur_unless = cur_unless;
    lmt_condition_state.if_step = if_step;
    lmt_condition_state.if_unless = if_unless;
    lmt_condition_state.if_limit = if_limit;
    lmt_condition_state.if_line = if_line;
    tex_print_nlp();
    if (tracing_nesting_par > 1) {
        tex_show_context();
    }
    if (lmt_error_state.history == spotless) {
        lmt_error_state.history = warning_issued;
    }
}

static void tex_aux_check_validity(void)
{
    switch (lmt_input_state.scanner_status) {
        case scanner_is_normal:
            break;
        case scanner_is_skipping:
            tex_handle_error(
                condition_error_type,
                "The file ended while I was skipping conditional text.",
                "This kind of error happens when you say '\\if...' and forget the\n"
                "matching '\\fi'. It can also be that you  use '\\orelse' or '\\orunless\n'"
                "in the wrong way. Or maybe a forbidden control sequence was encountered."
            );
            break;
        case scanner_is_defining:
            tex_handle_error(runaway_error_type, "The file ended when scanning a definition.", NULL);
            break;
        case scanner_is_matching:
            tex_handle_error(runaway_error_type, "The file ended when scanning an argument.", NULL);
            break;
        case scanner_is_tolerant:
            break;
        case scanner_is_aligning:
            tex_handle_error(runaway_error_type, "The file ended when scanning an alignment preamble.", NULL);
            break;
        case scanner_is_absorbing:
            tex_handle_error(runaway_error_type, "The file ended when absorbing something.", NULL);
            break;
    }
}

static next_line_retval tex_aux_next_line(void)
{
    if (lmt_input_state.cur_input.name > io_initial_input_code) {
        /*tex Read next line of file into |buffer|, or |goto restart| if the file has ended. */
        unsigned inhibit_eol = 0;
        ++lmt_input_state.input_line;
        lmt_fileio_state.io_first = lmt_input_state.cur_input.start;
        if (! lmt_token_state.force_eof) {
            unsigned force_eol = 0;
            switch (lmt_input_state.cur_input.name) {
                case io_lua_input_code:
                    {
                        halfword n = null;
                        int cattable = 0;
                        int partial = 0;
                        int finalline = 0;
                        int t = lmt_cstring_input(&n, &cattable, &partial, &finalline);
                        switch (t) {
                            case eof_tex_input:
                                lmt_token_state.force_eof = 1;
                                break;
                            case string_tex_input:
                                /*tex string */
                                lmt_input_state.cur_input.limit = lmt_fileio_state.io_last; /*tex Was |firm_up_the_line();|. */
                                lmt_input_state.cur_input.cattable = (short) cattable;
                                lmt_input_state.cur_input.partial = (signed char) partial;
                                if (finalline || partial || cattable == no_catcode_table_preset) {
                                    inhibit_eol = 1;
                                }
                                if (! partial) {
                                    lmt_input_state.cur_input.state = new_line_state;
                                }
                                break;
                            case token_tex_input:
                                /*tex token */
                                if (n >= cs_token_flag && eq_type(n - cs_token_flag) == input_cmd && eq_value(n - cs_token_flag) == end_of_input_code && lmt_input_state.cur_input.index > 0) {
                                    tex_end_file_reading();
                                }
                                tex_back_input(n);
                                return next_line_restart;
                            case token_list_tex_input:
                                /*tex token */
                                tex_begin_backed_up_list(n);
                                return next_line_restart;
                            case node_tex_input:
                                /*tex node */
                                if (node_token_overflow(n)) {
                                    tex_back_input(token_val(ignore_cmd, node_token_lsb(n)));
                                    tex_reinsert_token(token_val(node_cmd, node_token_msb(n)));
                                    return next_line_restart;
                                } else {
                                    /*tex |0x10FFFF == 1114111| */
                                    tex_back_input(token_val(node_cmd, n));
                                    return next_line_restart;
                                }
                            default:
                                lmt_token_state.force_eof = 1;
                                break;
                        }
                        break;
                    }
                case io_token_input_code:
                case io_token_eof_input_code:
                    {
                        /* can be simplified but room for extensions now */
                        halfword n = null;
                        int cattable = 0;
                        int partial = 0;
                        int finalline = 0;
                        int t = lmt_cstring_input(&n, &cattable, &partial, &finalline);
                        switch (t) {
                            case eof_tex_input:
                                lmt_token_state.force_eof = 1;
                                if (lmt_input_state.cur_input.name == io_token_eof_input_code && every_eof_par) {
                                    force_eol = 1;
                                }
                                break;
                            case string_tex_input:
                                /*tex string */
                                lmt_input_state.cur_input.limit = lmt_fileio_state.io_last; /*tex Was |firm_up_the_line();|. */
                                lmt_input_state.cur_input.cattable = (short) cattable;
                                lmt_input_state.cur_input.partial = (signed char) partial;
                                inhibit_eol = lmt_input_state.cur_input.name != io_token_eof_input_code;
                                if (! partial) {
                                    lmt_input_state.cur_input.state = new_line_state;
                                }
                                break;
                            default:
                                lmt_token_state.force_eof = 1;
                                break;
                        }
                        break;
                    }
                case io_tex_macro_code:
                    /* what */
                default:
                    if (tex_lua_input_ln()) {
                        /*tex Not end of file, set |ilimit|. */
                        lmt_input_state.cur_input.limit = lmt_fileio_state.io_last; /*tex Was |firm_up_the_line();|. */
                        lmt_input_state.cur_input.cattable = default_catcode_table_preset;
                    } else if (every_eof_par && (! lmt_input_state.in_stack[lmt_input_state.cur_input.index].end_of_file_seen)) {
                        force_eol = 1;
                    } else {
                        tex_aux_check_validity();
                        lmt_token_state.force_eof = 1;
                    }
                    break;
            }
            if (force_eol) {
                lmt_input_state.cur_input.limit = lmt_fileio_state.io_first - 1;
                /* tex Fake one empty line. */
                lmt_input_state.in_stack[lmt_input_state.cur_input.index].end_of_file_seen = 1;
                tex_begin_token_list(every_eof_par, every_eof_text);
                return next_line_restart;
            }
        }
        if (lmt_token_state.force_eof) {
            if (tracing_nesting_par > 0) {
                if ((lmt_input_state.in_stack[lmt_input_state.in_stack_data.ptr].group != cur_boundary) || (lmt_input_state.in_stack[lmt_input_state.in_stack_data.ptr].if_ptr != lmt_condition_state.cond_ptr)) {
                    if (! io_token_input(lmt_input_state.cur_input.name)) {
                        /*tex Give warning for some unfinished groups and/or conditionals. */
                        tex_aux_file_warning();
                    }
                }
            }
            if (io_file_input(lmt_input_state.cur_input.name)) {
                tex_report_stop_file();
                --lmt_input_state.open_files;
            }
            lmt_token_state.force_eof = 0;
            tex_end_file_reading();
            return next_line_restart;
        } else {
            if (inhibit_eol || end_line_char_inactive) {
                lmt_input_state.cur_input.limit--;
            } else {
                lmt_fileio_state.io_buffer[lmt_input_state.cur_input.limit] = (unsigned char) end_line_char_par;
            }
            lmt_fileio_state.io_first = lmt_input_state.cur_input.limit + 1;
            lmt_input_state.cur_input.loc = lmt_input_state.cur_input.start;
            /*tex We're ready to read. */
        }
    } else if (lmt_input_state.input_stack_data.ptr > 0) {
        cur_cmd = 0;
        cur_chr = 0;
        return next_line_return;
    } else {
        /*tex A somewhat weird check: */
        switch (lmt_print_state.selector) {
            case no_print_selector_code:
            case terminal_selector_code:
                tex_open_log_file();
                break;
        }
        tex_handle_error(eof_error_type, "end of file encountered", NULL);
        /*tex Just in case it is not handled in a callback: */
        if (lmt_error_state.interaction > nonstop_mode) {
            tex_fatal_error("aborting job");
        }
    }
    return next_line_ok;
}

/*tex
    Let's consider now what happens when |get_next| is looking at a token list.
*/

static int tex_aux_get_next_tokenlist(void)
{
    halfword t = token_info(lmt_input_state.cur_input.loc);
    /*tex Move to next. */
    lmt_input_state.cur_input.loc = token_link(lmt_input_state.cur_input.loc);
    if (t >= cs_token_flag) {
        /*tex A control sequence token */
        cur_cs = t - cs_token_flag;
        cur_cmd = eq_type(cur_cs);
        if (cur_cmd == deep_frozen_dont_expand_cmd) {
            /*tex

                Get the next token, suppressing expansion. The present point in the program is
                reached only when the |expand| routine has inserted a special marker into the
                input. In this special case, |token_info(iloc)| is known to be a control sequence
                token, and |token_link(iloc) = null|.

            */
            cur_cs = token_info(lmt_input_state.cur_input.loc) - cs_token_flag;
            lmt_input_state.cur_input.loc = null;
            cur_cmd = eq_type(cur_cs);
            if (cur_cmd > max_command_cmd) {
                cur_cmd = relax_cmd;
             // cur_chr = no_expand_flag;
                cur_chr = no_expand_relax_code;
                return 1;
            }
        }
        cur_chr = eq_value(cur_cs);
    } else {
        cur_cmd = token_cmd(t);
        cur_chr = token_chr(t);
        switch (cur_cmd) {
            case left_brace_cmd:
                lmt_input_state.align_state++;
                break;
            case right_brace_cmd:
                lmt_input_state.align_state--;
                break;
            case parameter_reference_cmd:
                /*tex Insert macro parameter and |goto restart|. */
                tex_begin_parameter_list(lmt_input_state.parameter_stack[lmt_input_state.cur_input.parameter_start + cur_chr - 1]);
                return 0;
        }
    }
    return 1;
}

/*tex

    Now we're ready to take the plunge into |get_next| itself. Parts of this routine are executed
    more often than any other instructions of \TEX. This sets |cur_cmd|, |cur_chr|, |cur_cs| to
    next token.

    Handling alignments is interwoven because there we switch between constructing cells and rows
    (node lists) based on templates that are token lists. This is why in several places we find
    checks for |align_state|.

*/

void tex_get_next(void)
{
    while (1) {
        cur_cs = 0;
        if (lmt_input_state.cur_input.state != token_list_state) {
            /*tex Input from external file, |goto restart| if no input found. */
            if (! tex_aux_get_next_file()) {
                continue;
            } else {
                /*tex Check align state later on! */
            }
        } else if (! lmt_input_state.cur_input.loc) {
            /*tex List exhausted, resume previous level. */
            tex_end_token_list();
            continue;
        } else if (! tex_aux_get_next_tokenlist()) {
            /*tex Parameter needs to be expanded. */
            continue;
        }
        if ((lmt_input_state.align_state == 0) && (cur_cmd == alignment_tab_cmd || cur_cmd == alignment_cmd)) {
            /*tex If an alignment entry has just ended, take appropriate action. */
            tex_insert_alignment_template();
            continue;
        } else {
            break;
        }
    }
}

/*tex

    Since |get_next| is used so frequently in \TEX, it is convenient to define three related
    procedures that do a little more:

    \startitemize
        \startitem
            |get_token| not only sets |cur_cmd| and |cur_chr|, it also sets |cur_tok|, a packed
            halfword version of the current token.
        \stopitem
        \startitem
            |get_x_token|, meaning \quote {get an expanded token}, is like |get_token|, but if the
            current token turns out to be a user-defined control sequence (i.e., a macro call), or
            a conditional, or something like |\topmark| or |\expandafter| or |\csname|, it is
            eliminated from the input by beginning the expansion of the macro or the evaluation of
            the conditional.
        \stopitem
        \startitem
            |x_token| is like |get_x_token| except that it assumes that |get_next| has already been
            called.
        \stopitem
    \stopitemize

    In fact, these three procedures account for almost every use of |get_next|. No new control
    sequences will be defined except during a call of |get_token|, or when |\csname| compresses a
    token list, because |no_new_control_sequence| is always |true| at other times.

    This sets |cur_cmd|, |cur_chr|, |cur_tok|. For convenience we also return the token because in
    some places we store it and then some direct assignment looks a bit nicer.

*/

halfword tex_get_token(void)
{
    lmt_hash_state.no_new_cs = 0;
    tex_get_next();
    lmt_hash_state.no_new_cs = 1;
    cur_tok = cur_cs ? cs_token_flag + cur_cs : token_val(cur_cmd, cur_chr);
    return cur_tok;
}

/*tex

    The |get_x_or_protected| procedure is like |get_x_token| except that protected macros are not
    expanded. It sets |cur_cmd|, |cur_chr|, |cur_tok|, and expands non-protected macros.

*/

void tex_get_x_or_protected(void)
{
    lmt_hash_state.no_new_cs = 0;
    while (1) {
        tex_get_next();
        if (cur_cmd <= max_command_cmd || is_protected_cmd(cur_cmd)) {
            break;
        } else {
            tex_expand_current_token();
        }
    }
    cur_tok = cur_cs ? cs_token_flag + cur_cs : token_val(cur_cmd, cur_chr); /* needed afterwards ? */
    lmt_hash_state.no_new_cs = 1;
}

/*tex This changes the string |s| to a token list. */

halfword tex_string_to_toks(const char *ss)
{
    const char *s = ss;
    const char *se = ss + strlen(s);
    /*tex tail of the token list */
    halfword h = null;
    halfword p = null;
    /*tex new node being added to the token list via |store_new_token| */
    while (s < se) {
        int tl; 
        halfword t = (halfword) aux_str2uni_len((const unsigned char *) s, &tl);
        s += tl;
        if (t == ' ') {
            t = space_token;
        } else {
            t += other_token;
        }
        p = tex_store_new_token(p, t);
        if (! h) {
            h = p;
        }
    }
    return h;
}

/*tex

    The token lists for macros and for other things like |\mark| and |\output| and |\write| are
    produced by a procedure called |scan_toks|.

    Before we get into the details of |scan_toks|, let's consider a much simpler task, that of
    converting the current string into a token list. The |str_toks| function does this; it
    classifies spaces as type |spacer| and everything else as type |other_char|.

    The token list created by |str_toks| begins at |link(temp_token_head)| and ends at the value
    |p| that is returned. If |p = temp_token_head|, the list is empty.

    |lua_str_toks| is almost identical, but it also escapes the three symbols that \LUA\ considers
    special while scanning a literal string.
*/

static halfword lmt_str_toks(lstring b) /* returns head */
{
    unsigned char *k = (unsigned char *) b.s;
    halfword head = null;
    halfword tail = head;
    while (k < (unsigned char *) b.s + b.l) {
        int tl; 
        halfword t = aux_str2uni_len(k, &tl);
        k += tl;
        if (t == ' ') {
            t = space_token;
        } else {
            if ((t == '\\') || (t == '"') || (t == '\'') || (t == 10) || (t == 13)) {
                tail = tex_store_new_token(tail, escape_token);
                if (! head) {
                    head = tail;
                }
                if (t == 10) {
                    t = 'n';
                } else if (t == 13) {
                    t = 'r';
                }
            }
            t += other_token;
        }
        tail = tex_store_new_token(tail, t);
        if (! head) {
            head = tail;
        }
    }
    return head;
}

/*tex

    Incidentally, the main reason for wanting |str_toks| is the function |the_toks|, which has
    similar input/output characteristics. This changes the string |str_pool[b .. pool_ptr]| to a
    token list:

*/

halfword tex_str_toks(lstring s, halfword *tail)
{
    halfword h = null;
    halfword p = null;
    if (s.s) {
        unsigned char *k = s.s;
        unsigned char *l = k + s.l;
        while (k < l) {
            int tl;
            halfword t = aux_str2uni_len(k, &tl);
            if (t == ' ') {
                t = space_token;
            } else {
                t += other_token;
            }
            k += tl;
            p = tex_store_new_token(p, t);
            if (! h) {
                h = p;
            }
        }
    }
    if (tail) {
        *tail = null;
    }
    return h;
}

halfword tex_cur_str_toks(halfword *tail)
{
    halfword h = null;
    halfword p = null;
    unsigned char *k = (unsigned char *) lmt_string_pool_state.string_temp;
    if (k) {
        unsigned char *l = k + lmt_string_pool_state.string_temp_top;
        /*tex tail of the token list */
        while (k < l) {
            /*tex token being appended */
            int tl;
            halfword t = aux_str2uni_len(k, &tl);
            if (t == ' ') {
                t = space_token;
            } else {
                t += other_token;
            }
            k += tl;
            p = tex_store_new_token(p, t);
            if (! h) {
                h = p;
            }
        }
    }
    tex_reset_cur_string();
    if (tail) {
        *tail = p;
    }
    return h;
}

/*tex

    Most of the converter is similar to the one I made for macro so at some point I can make a
    helper; also todo: there is no need to go through the pool.

*/

/*tex Change the string |str_pool[b..pool_ptr]| to a token list. */

halfword tex_str_scan_toks(int ct, lstring ls)
{
    /*tex index into string */
    unsigned char *k = ls.s;
    unsigned char *l = k + ls.l;
    /*tex tail of the token list */
    halfword h = null;
    halfword p = null;
    while (k < l) {
        int cc;
        /*tex token being appended */
        int lt;
        halfword t = aux_str2uni_len(k, &lt);
        k += lt;
        cc = tex_get_cat_code(ct, t);
        if (cc == 0) {
            /*tex We have a potential control sequence so we check for it. */
            int lname = 0 ;
            int s = 0 ;
            int c = 0 ;
            unsigned char *name = k ;
            while (k < l) {
                t = (halfword) aux_str2uni_len((const unsigned char *) k, &s);
                c = tex_get_cat_code(ct,t);
                if (c == 11) {
                    k += s ;
                    lname += s ;
                } else if (c == 10) {
                    /*tex We ignore a trailing space like normal scanning does. */
                    k += s ;
                    break ;
                } else {
                    break ;
                }
            }
            if (s > 0) {
                /*tex We have a potential |\cs|. */
                halfword cs = tex_string_locate((const char *) name, lname, 0);
                if (cs == undefined_control_sequence) {
                    /*tex Let's play safe and backtrack. */
                    t += cc * (1<<21);
                    k = name ;
                } else {
                    t = cs_token_flag + cs;
                }
            } else {
                /*tex
                    Just a character with some meaning, so |\unknown| becomes effectively
                    |\unknown| assuming that |\\| has some useful meaning of course.
                */
                t += cc * (1<<21);
                k = name ;
            }
        } else {
            /*tex
                Whatever token, so for instance $x^2$ just works given a \TEX\ catcode regime.
            */
            t += cc * (1<<21);
        }
        p = tex_store_new_token(p, t);
        if (! h) {
            h = p;
        }
    }
    return h;
}

/* these two can be combined, then we can avoid the h check  */

static void tex_aux_set_toks_register(halfword loc, singleword cmd, halfword t, int g)
{
    halfword ref = get_reference_token();
    set_token_link(ref, t);
    tex_define((g > 0) ? global_flag_bit : 0, loc, cmd == internal_toks_cmd ? internal_toks_reference_cmd : register_toks_reference_cmd, ref);
}

static void tex_aux_append_copied_toks_list(halfword loc, singleword cmd, int g, halfword s, halfword t)
{
    halfword ref = get_reference_token();
    halfword p = ref;
    while (s) {
        p = tex_store_new_token(p, token_info(s));
        s = token_link(s);
    }
    while (t) {
        p = tex_store_new_token(p, token_info(t));
        t = token_link(t);
    }
    tex_define((g > 0) ? global_flag_bit : 0, loc, cmd == internal_toks_cmd ? internal_toks_reference_cmd : register_toks_reference_cmd, ref);
}

/*tex Public helper: */

halfword tex_copy_token_list(halfword h1, halfword *t)
{
    halfword h2 = tex_store_new_token(null, token_info(h1));
    halfword t1 = token_link(h1);
    halfword t2 = h2;
    while (t1) {
        t2 = tex_store_new_token(t2, token_info(t1));
        t1 = token_link(t1);
    }
    if (t) {
        *t = t2;
    }
    return h2;
}

/*tex

    At some point I decided to implement the following primitives:

    \starttabulate[|T||T||]
    \NC 0 \NC \type {toksapp}   \NC 1 \NC \type {etoksapp} \NC \NR
    \NC 2 \NC \type {tokspre}   \NC 3 \NC \type {etokspre} \NC \NR
    \NC 4 \NC \type {gtoksapp}  \NC 5 \NC \type {xtoksapp} \NC \NR
    \NC 6 \NC \type {gtokspre}  \NC 7 \NC \type {xtokspre} \NC \NR
    \stoptabulate

    These append and prepend tokens to token lists. In \CONTEXT\ we always had macros doing something
    like that. It was only a few years later that I ran again into an article that Taco and I wrote
    in 1999 in the NTG Maps about an extension to \ETEX\ (called eetex). The first revelation was
    that I had completely forgotten about it, which can be explained by the two decade time-lap. The
    second was that Taco actually added that to the program at that time, so I could have used (parts
    of) that code. Anyway, among the other proposed (and implemented) features were manipulating
    lists and ways to output packed data to the \DVI\ files (numbers packed into 1 upto 4 bytes).
    Maybe some day I'll have a go at lists, although with todays computers there is not that much to
    gain. Also, \CONTEXT\ progressed to different internals so the urge is no longer there. The also
    discussed \SGML\ mode also in no longer that relevant given that we have \LUA.

    If we want to handle macros too we really need to distinguish between toks and macros with
    |cur_chr| above, but not now. We can't expand, and have to use |get_r_token| or so. I don't need
    it anyway.

    \starttyping
    get_r_token();
    if (cur_cmd == call_cmd) {
        nt = cur_cs;
        target = equiv(nt);
    } else {
        // some error message
    }
    \stoptyping
*/

# define immediate_permitted(loc,target) ((eq_level(loc) == cur_level) && (get_token_reference(target) == 0))

void tex_run_combine_the_toks(void)
{
    halfword source = null;
    halfword target = null;
    halfword append, expand, global;
    halfword nt, ns;
    singleword cmd;
    /* */
    switch (cur_chr) {
        case expanded_toks_code:                append = 0; global = 0; expand = 1; break;
        case append_toks_code:                  append = 1; global = 0; expand = 0; break;
        case append_expanded_toks_code:         append = 1; global = 0; expand = 1; break;
        case prepend_toks_code:                 append = 2; global = 0; expand = 0; break;
        case prepend_expanded_toks_code:        append = 2; global = 0; expand = 1; break;
        case global_expanded_toks_code:         append = 0; global = 1; expand = 1; break;
        case global_append_toks_code:           append = 1; global = 1; expand = 0; break;
        case global_append_expanded_toks_code:  append = 1; global = 1; expand = 1; break;
        case global_prepend_toks_code:          append = 2; global = 1; expand = 0; break;
        case global_prepend_expanded_toks_code: append = 2; global = 1; expand = 1; break;
        default:                                append = 0; global = 0; expand = 0; break;
    }
    /*tex The target. */
    tex_get_x_token();
    if (cur_cmd == register_toks_cmd || cur_cmd == internal_toks_cmd) {
        nt = eq_value(cur_cs);
        cmd = (singleword) cur_cmd;
    } else {
        /*tex Maybe a number. */
        tex_back_input(cur_tok);
        nt = register_toks_location(tex_scan_toks_register_number());
        cmd = register_toks_cmd;
    }
    target = eq_value(nt);
    /*tex The source. */
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd);
    if (cur_cmd == left_brace_cmd) {
        source = expand ? tex_scan_toks_expand(1, NULL, 0) : tex_scan_toks_normal(1, NULL);
        /*tex The action. */
        if (source) {
            if (target) {
                halfword s = token_link(source);
                if (s) {
                    halfword t = token_link(target);
                    if (! t) {
                        /*tex Can this happen? */
                        set_token_link(target, s);
                        token_link(source) = null;
                    } else {
                        switch (append) {
                            case 0:
                                goto ASSIGN_1;
                            case 1:
                                /*append */
                                if (immediate_permitted(nt,target)) {
                                    halfword p = t;
                                    while (token_link(p)) {
                                        p = token_link(p);
                                    }
                                    token_link(p) = s;
                                    token_link(source) = null;
                                } else {
                                    tex_aux_append_copied_toks_list(nt, cmd, global, t, s);
                                }
                                break;
                            case 2:
                                /* prepend */
                                if (immediate_permitted(nt,target)) {
                                    halfword p = s;
                                    while (token_link(p)) {
                                        p = token_link(p);
                                    }
                                    token_link(source) = null;
                                    set_token_link(p, t);
                                    set_token_link(target, s);
                                } else {
                                    tex_aux_append_copied_toks_list(nt, cmd, global, s, t);
                                }
                                break;
                        }
                    }
                }
            } else {
                ASSIGN_1:
                tex_aux_set_toks_register(nt, cmd, token_link(source), global);
                token_link(source) = null;
            }
            tex_flush_token_list(source);
        }
    } else {
        if (cur_cmd == register_toks_cmd) {
            ns = register_toks_number(eq_value(cur_cs));
        } else if (cur_cmd == internal_toks_cmd) {
            ns = internal_toks_number(eq_value(cur_cs));
        } else {
            ns = tex_scan_toks_register_number();
        }
        /*tex The action. */
        source = toks_register(ns);
        if (source) {
            if (target) {
                halfword s = token_link(source);
                halfword t = token_link(target);
                switch (append) {
                    case 0:
                        /*assign */
                        goto ASSIGN_2;
                    case 1:
                        /*append */
                        if (immediate_permitted(nt, target)) {
                            halfword p = t;
                            while (token_link(p)) {
                                p = token_link(p);
                            }
                            while (s) {
                                p = tex_store_new_token(p, token_info(s));
                                s = token_link(s);
                            }
                        } else {
                            tex_aux_append_copied_toks_list(nt, cmd, global, t, s);
                        }
                        break;
                    case 2:
                        if (immediate_permitted(nt, target)) {
                            halfword h = null;
                            halfword p = null;
                            while (s) {
                                p = tex_store_new_token(p, token_info(s));
                                if (! h) {
                                    h = p;
                                }
                                s = token_link(s);
                            }
                            set_token_link(p, t);
                            set_token_link(target, h);
                        } else {
                            tex_aux_append_copied_toks_list(nt, cmd, global, s, t);
                        }
                        break;
                }
            } else {
                ASSIGN_2:
             // set_toks_register(nt, source, global);
                tex_add_token_reference(source);
                eq_value(nt) = source;
            }
        }
    }
}

/*tex

    This routine, used in the next one, prints the job name, possibly modified by the
    |process_jobname| callback.

*/

static void tex_aux_print_job_name(void)
{
    if (lmt_fileio_state.job_name) {
        /*tex \CCODE\ strings for jobname before and after processing. */
        char *s = lmt_fileio_state.job_name;
        int callback_id = lmt_callback_defined(process_jobname_callback);
        if (callback_id > 0) {
            char *ss;
            int lua_retval = lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "S->S", s, &ss);
            if (lua_retval && ss) {
                s = ss;
            }
        }
        tex_print_str(s);
    }
}

/*tex

    The procedure |run_convert_tokens| uses |str_toks| to insert the token list for |convert|
    functions into the scanner; |\outer| control sequences are allowed to follow |\string| and
    |\meaning|.

*/

/*tex Codes not really needed but cleaner when testing */

# define push_selector { \
    saved_selector = lmt_print_state.selector; \
    lmt_print_state.selector = new_string_selector_code; \
}

# define pop_selector { \
    lmt_print_state.selector = saved_selector; \
}

void tex_run_convert_tokens(halfword code)
{
    /*tex Scan the argument for command |c|. */
    switch (code) {
        /*tex
            The |number_code| is quite popular. Beware, when used with a lua none function, a zero
            is injected. We could intercept it at the cost of messy code, but on the other hand,
            nothing guarantees that the call returns a number so this side effect can be defended
            as a recovery measure.
        */
        case number_code:
            {
                int saved_selector;
                halfword v = tex_scan_int(0, NULL);
                push_selector;
                tex_print_int(v);
                pop_selector;
                break;
            }
        case to_integer_code:
        case to_hexadecimal_code:
            {
                int saved_selector;
                halfword v = tex_scan_int(0, NULL);
                tex_get_x_token(); /* maybe not x here */
                if (cur_cmd != relax_cmd) {
                    tex_back_input(cur_tok);
                }
                push_selector;
                if (code == to_integer_code) {
                    tex_print_int(v);
                } else { 
                    tex_print_hex(v);
                }
                pop_selector;
                break;
            }
        case to_scaled_code:
        case to_sparse_scaled_code:
        case to_dimension_code:
        case to_sparse_dimension_code:
            {
                int saved_selector;
                halfword v = tex_scan_dimen(0, 0, 0, 0, NULL);
                tex_get_x_token(); /* maybe not x here */
                if (cur_cmd != relax_cmd) {
                    tex_back_input(cur_tok);
                }
                push_selector;
                switch (code) {
                    case to_sparse_dimension_code:
                    case to_sparse_scaled_code:
                        tex_print_sparse_dimension(v, no_unit);
                        break;
                    default:
                        tex_print_dimension(v, no_unit);
                        break;
                }
                switch (code) {
                    case to_dimension_code:
                    case to_sparse_dimension_code:
                        tex_print_unit(pt_unit);
                        break;
                }
                pop_selector;
                break;
            }
        case to_mathstyle_code:
            {
                int saved_selector;
                halfword v = tex_scan_math_style_identifier(1, 0);
                push_selector;
                tex_print_int(v);
                pop_selector;
                break;
            }
        case lua_function_code:
            {
                halfword v = tex_scan_int(0, NULL);
                if (v > 0) {
                    strnumber u = tex_save_cur_string();
                    lmt_token_state.luacstrings = 0;
                    lmt_function_call(v, 0);
                    tex_restore_cur_string(u);
                    if (lmt_token_state.luacstrings > 0) {
                        tex_lua_string_start();
                    }
                } else {
                    tex_normal_error("luafunction", "invalid number");
                }
                return;
            }
        case lua_bytecode_code:
            {
                halfword v = tex_scan_int(0, NULL);
                if (v < 0 || v > 65535) {
                    tex_normal_error("luabytecode", "invalid number");
                } else {
                    strnumber u = tex_save_cur_string();
                    lmt_token_state.luacstrings = 0;
                    lmt_bytecode_call(v);
                    tex_restore_cur_string(u);
                    if (lmt_token_state.luacstrings > 0) {
                        tex_lua_string_start();
                    }
                }
                return;
            }
        case lua_code:
            {
                full_scanner_status saved_full_status = tex_save_full_scanner_status();
                strnumber u = tex_save_cur_string();
                halfword s = tex_scan_toks_expand(0, NULL, 0);
                tex_unsave_full_scanner_status(saved_full_status);
                lmt_token_state.luacstrings = 0;
                lmt_token_call(s);
                tex_delete_token_reference(s); /* boils down to flush_list */
                tex_restore_cur_string(u);
                if (lmt_token_state.luacstrings > 0) {
                    tex_lua_string_start();
                }
                /*tex No further action. */
                return;
            }
        case expanded_code:
        case semi_expanded_code:
            {
                full_scanner_status saved_full_status = tex_save_full_scanner_status();
                strnumber u = tex_save_cur_string();
                halfword s = tex_scan_toks_expand(0, NULL, code == semi_expanded_code);
                tex_unsave_full_scanner_status(saved_full_status);
                if (token_link(s)) {
                    tex_begin_inserted_list(token_link(s));
                    token_link(s) = null;
                }
                tex_put_available_token(s);
                tex_restore_cur_string(u);
                /*tex No further action. */
                return;
            }
     /* case immediate_assignment_code: */
     /* case immediate_assigned_code:   */
        /*tex
             These two were an on-the-road-to-bachotex brain-wave. A first variant did more in
             sequence till a relax or spacer was seen. These commands permits for instance setting
             counters in full expansion. However, as we have the more powerful local control
             mechanisms available these two commands have been dropped in \LUAMETATEX. Performance
             wise there is not that much to gain from |\immediateassigned| and it's even somewhat
             limited. So, they're gone now. Actually, one can also use the local control feature in
             an |\edef|, which {\em is} rather efficient, so we're good anyway. The upgraded code
             can be found in the archive.
        */
        case string_code:
            {
                int saved_selector;
                int saved_scanner_status = lmt_input_state.scanner_status;
                lmt_input_state.scanner_status = scanner_is_normal;
                tex_get_token();
                lmt_input_state.scanner_status = saved_scanner_status;
                push_selector;
                if (cur_cs) {
                    tex_print_cs(cur_cs);
                } else {
                    tex_print_tex_str(cur_chr);
                }
                pop_selector;
                break;
            }
        case cs_string_code:
        case cs_active_code:
            {
                int saved_selector;
                int saved_scanner_status = lmt_input_state.scanner_status;
                lmt_input_state.scanner_status = scanner_is_normal;
                tex_get_token();
                lmt_input_state.scanner_status = saved_scanner_status;
                push_selector;
                if (code == cs_active_code) {
                    // tex_print_char(active_first);
                    // tex_print_char(active_second);
                    // tex_print_char(active_third);
                    tex_print_str(active_character_namespace);
                    if (cur_cmd == active_char_cmd) {
                        tex_print_char(cur_chr);
                    } else {
                        /*tex So anything else will just inject the hash (abstraction, saves a command). */
                        tex_back_input(cur_tok);
                    }
                } else if (cur_cs) {
                    tex_print_cs_name(cur_cs);
                } else {
                    tex_print_tex_str(cur_chr);
                }
                pop_selector;
                break;
            }
        /*
        case cs_lastname_code:
            if (lmt_scanner_state.last_cs_name != null_cs) {
                int saved_selector;
                push_selector;
                tex_print_cs_name(lmt_scanner_state.last_cs_name);
                pop_selector;
            }
            break;
        */
        case detokenized_code:
            {
                int saved_selector;
                int saved_scanner_status = lmt_input_state.scanner_status;
                halfword t = null; 
                lmt_input_state.scanner_status = scanner_is_normal;
                tex_get_token();
                lmt_input_state.scanner_status = saved_scanner_status;
                t = tex_get_available_token(cur_tok);
                push_selector;
                tex_show_token_list(t, null, extreme_token_show_max, 0);
                tex_put_available_token(t);
                pop_selector;
                break;
            }
        case roman_numeral_code:
            {
                int saved_selector;
                halfword v = tex_scan_int(0, NULL);
                push_selector;
                tex_print_roman_int(v);
                pop_selector;
                break;
            }
        case meaning_code:
        case meaning_full_code:
        case meaning_less_code:
        case meaning_asis_code:
            {
                int saved_selector;
                int saved_scanner_status = lmt_input_state.scanner_status;
                lmt_input_state.scanner_status = scanner_is_normal;
                tex_get_token();
                lmt_input_state.scanner_status = saved_scanner_status;
                push_selector;
                tex_print_meaning(code);
                pop_selector;
                break;
            }
        case uchar_code:
            {
                int saved_selector;
                int chr = tex_scan_char_number(0);
                push_selector;
                tex_print_tex_str(chr);
                pop_selector;
                break;
            }
        case lua_escape_string_code:
     /* case lua_token_string_code: */ /* for now rejected: could also be keyword */
            {
                /* tex 
                    If I would need it I could probably add support for catcode tables and verbose 
                    serialization. Maybe we can use some of the other (more efficient) helpers when
                    we have a detokenize variant. We make sure that the escape character is a 
                    backslash because these conversions can occur anywhere and are very much 
                    related to \LUA\ calls. (Maybe it makes sense to pass it a argument to the
                    serializer.) 

                    A |\luatokenstring| primitive doesn't really make sense because \LUATEX\ lacks
                    it and |\luaescapestring| is a compatibility primitive.
                */
                lstring str;
                int length = 0;
                int saved_in_lua_escape = lmt_token_state.in_lua_escape;
                halfword saved_escape_char = escape_char_par;
                full_scanner_status saved_full_status = tex_save_full_scanner_status();
                halfword result = tex_scan_toks_expand(0, NULL, 0); 
             /* halfword result = tex_scan_toks_expand(0, NULL, code == lua_token_string_code); */
                lmt_token_state.in_lua_escape = 1;
                escape_char_par = '\\';
                str.s = (unsigned char *) tex_tokenlist_to_tstring(result, 0, &length, 0, 0, 0, 0);
                str.l = (unsigned) length;
                lmt_token_state.in_lua_escape = saved_in_lua_escape;
                escape_char_par = saved_escape_char;
                tex_delete_token_reference(result); /* boils down to flush_list */
                tex_unsave_full_scanner_status(saved_full_status);
                if (str.l) {
                    result = lmt_str_toks(str);
                    tex_begin_inserted_list(result);
                }
                return;
            }
        case font_name_code:
            {
                int saved_selector;
                halfword fnt = tex_scan_font_identifier(NULL);
                push_selector;
                tex_print_font(fnt);
                pop_selector;
                break;
            }
        case font_specification_code:
            {
                int saved_selector;
                halfword fnt = tex_scan_font_identifier(NULL);
                push_selector;
                tex_append_string((const unsigned char *) font_original(fnt), (unsigned) strlen(font_original(fnt)));
                pop_selector;
                break;
            }
        case job_name_code:
            {
                int saved_selector;
                if (! lmt_fileio_state.job_name) {
                    tex_open_log_file();
                }
                push_selector;
                tex_aux_print_job_name();
                pop_selector;
                break;
            }
        case format_name_code:
            {
                int saved_selector;
                if (! lmt_fileio_state.job_name) {
                    tex_open_log_file();
                }
                push_selector;
                tex_print_str(lmt_engine_state.dump_name);
                pop_selector;
                break;
            }
        case luatex_banner_code:
            {
                int saved_selector;
                push_selector;
                tex_print_str(lmt_engine_state.luatex_banner);
                pop_selector;
                break;
            }
        default:
            tex_confusion("convert tokens");
            break;
    }
    {
        halfword head = tex_cur_str_toks(NULL);
        tex_begin_inserted_list(head);
    }
}

/*tex
    The boolean |in_lua_escape| is keeping track of the lua string escape state.
*/

strnumber tex_the_convert_string(halfword c, int i)
{
    int saved_selector = lmt_print_state.selector;
    strnumber ret = 0;
    int done = 1 ;
    lmt_print_state.selector = new_string_selector_code;
    switch (c) {
        case number_code:
        case to_integer_code:
            tex_print_int(i);
            break;
        case to_hexadecimal_code:
            tex_print_hex(i);
            break;
        case to_scaled_code:
            tex_print_dimension(i, no_unit);
            break;
        case to_sparse_scaled_code:
            tex_print_sparse_dimension(i, no_unit);
            break;
        case to_dimension_code:
            tex_print_dimension(i, pt_unit);
            break;
        case to_sparse_dimension_code:
            tex_print_sparse_dimension(i, pt_unit);
            break;
     /* case to_mathstyle_code: */
     /* case lua_function_code: */
     /* case lua_code: */
     /* case expanded_code: */
     /* case string_code: */
     /* case cs_string_code: */
        case roman_numeral_code:
            tex_print_roman_int(i);
            break;
     /* case meaning_code: */
        case uchar_code:
            tex_print_tex_str(i);
            break;
     /* case lua_escape_string_code: */
        case font_name_code:
            tex_print_font(i);
            break;
        case font_specification_code:
            tex_print_str(font_original(i));
            break;
     /* case left_margin_kern_code: */
     /* case right_margin_kern_code: */
     /* case math_char_class_code: */
     /* case math_char_fam_code: */
     /* case math_char_slot_code: */
     /* case insert_ht_code: */
        case job_name_code:
            tex_aux_print_job_name();
            break;
        case format_name_code:
            tex_print_str(lmt_engine_state.dump_name);
            break;
        case luatex_banner_code:
            tex_print_str(lmt_engine_state.luatex_banner);
            break;
        case font_identifier_code:
            tex_print_font_identifier(i);
            break;
        default:
            done = 0;
            break;
    }
    if (done) {
        ret = tex_make_string();
    }
    lmt_print_state.selector = saved_selector;
    return ret;
}

/*tex Return a string from tokens list: */

strnumber tex_tokens_to_string(halfword p)
{
    if (lmt_print_state.selector == new_string_selector_code) {
        tex_normal_error("tokens", "tokens_to_string() called while selector = new_string");
        return get_nullstr();
    } else {
        int saved_selector = lmt_print_state.selector;
        lmt_print_state.selector = new_string_selector_code;
        tex_token_show(p, extreme_token_show_max);
        lmt_print_state.selector = saved_selector;
        return tex_make_string();
    }
}

/*tex

    The actual token conversion in this function is now functionally equivalent to |show_token_list|,
    except that it always prints the whole token list. Often the result is not that large, for
    instance |\directlua| is seldom large. However, this converter is also used for patterns
    and exceptions where size is mnore an issue. For that reason we used to have three variants,
    one of which (experimentally) used a buffer. At some point, in the manual we were talking of
    millions of allocations but times have changed.

    Macros were used to inline the appending code (in the thre variants), but in the end I decided
    to just merge all into one function, with a bit more overhead because we need to optionally
    skip a macro preamble.

    Values like 512 and 128 also work ok. There is not much to gain in optimization here. We used
    to have 3 mostly overlapping functions, one of which used a buffer. We can probably use a
    larger default buffer size and larger step and only free when we think it's too large.

*/

# define default_buffer_size  512 /*tex This used to be 256 */
# define default_buffer_step 4096 /*tex When we're larger, we always are much larger. */

// todo: check ret

static void tex_aux_make_room_in_buffer(int a)
{
    if (lmt_token_state.bufloc + a + 1 > lmt_token_state.bufmax) {
        char *tmp = aux_reallocate_array(lmt_token_state.buffer, sizeof(unsigned char), lmt_token_state.bufmax + default_buffer_step, 1);
        if (tmp) {
            lmt_token_state.bufmax += default_buffer_step;
        } else {
            // error
        }
        lmt_token_state.buffer = tmp;
    }
}

static void tex_aux_append_uchar_to_buffer(int s)
{
    tex_aux_make_room_in_buffer(4);
    if (s <= 0x7F) {
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (s);
    } else if (s <= 0x7FF) {
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0xC0 + (s / 0x40));
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0x80 + (s % 0x40));
    } else if (s <= 0xFFFF) {
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0xE0 +  (s / 0x1000));
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0x80 + ((s % 0x1000) / 0x40));
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0x80 + ((s % 0x1000) % 0x40));
    } else {
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0xF0 +   (s / 0x40000));
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0x80 +  ((s % 0x40000) / 0x1000));
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0x80 + (((s % 0x40000) % 0x1000) / 0x40));
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (0x80 + (((s % 0x40000) % 0x1000) % 0x40));
    }
}

static void tex_aux_append_char_to_buffer(int c)
{
    tex_aux_make_room_in_buffer(1);
    lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (c);
}

/*tex Only errors and unknowns. */

static void tex_aux_append_str_to_buffer(const char *s)
{
    const char *v = s;
    tex_aux_make_room_in_buffer((int) strlen(v));
    /*tex Using memcpy will inline and give a larger binary ... and we seldom need this. */
    while (*v) {
        lmt_token_state.buffer[lmt_token_state.bufloc++] = (char) (*v);
        v++;
    }
}

/*tex Only bogus csnames. */

static void tex_aux_append_esc_to_buffer(const char *s)
{
    int e = escape_char_par;
    if (e > 0 && e < cs_offset_value) {
        tex_aux_append_uchar_to_buffer(e);
    }
    tex_aux_append_str_to_buffer(s);
}

# define is_cat_letter(a)  (tex_aux_the_cat_code(aux_str2uni(str_string((a)))) == letter_cmd)

/* make two versions: macro and not */

char *tex_tokenlist_to_tstring(int pp, int inhibit_par, int *siz, int skippreamble, int nospace, int strip, int wipe)
{
    if (pp) {
        /*tex We need to go beyond the reference. */
        int p = token_link(pp);
        if (p) {
            int e = escape_char_par;  /*tex The serialization of the escape, normally a backlash. */
            int n = 0;                /*tex The character after |#|, so |#0| upto |#9| */
            int min = 0;
            int max = lmt_token_memory_state.tokens_data.top;
            int skip = 0;
            int tail = p; 
            int count = 0;
            if (lmt_token_state.bufmax > default_buffer_size) {
                /* Let's start fresh and small. */
                aux_deallocate_array(lmt_token_state.buffer);
                lmt_token_state.buffer = aux_allocate_clear_array(sizeof(unsigned char), default_buffer_size, 1);
                lmt_token_state.bufmax = default_buffer_size;
            } else if (! lmt_token_state.buffer) {
                /* Let's start. */
                lmt_token_state.buffer = aux_allocate_clear_array(sizeof(unsigned char), default_buffer_size, 1);
                lmt_token_state.bufmax = default_buffer_size;
            }
            lmt_token_state.bufloc = 0;
            if (skippreamble) {
                skip = get_token_preamble(pp);
            }
            while (p) {
                if (p < min || p > max) {
                    tex_aux_append_str_to_buffer(error_string_clobbered(31));
                    break;
                } else {
                    int infop = token_info(p);
                    if (infop < 0) {
                        /* unlikely, will go after checking  */
                        tex_aux_append_str_to_buffer(error_string_bad(32));
                    } else if (infop < cs_token_flag) {
                        /*tex We nearly always end up here because otherwise we have an error. */
                        int cmd = token_cmd(infop);
                        int chr = token_chr(infop);
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
                            case active_char_cmd:
                                if (! skip) {
                                    tex_aux_append_uchar_to_buffer(chr);
                                }
                                break;
                            case parameter_cmd:
                                if (! skip) {
                                    if (! nospace && (! lmt_token_state.in_lua_escape && (lmt_expand_state.cs_name_level == 0))) {
                                        tex_aux_append_uchar_to_buffer(chr);
                                    }
                                    tex_aux_append_uchar_to_buffer(chr);
                                }
                                break;
                            case parameter_reference_cmd:
                                if (! skip) {
                                    tex_aux_append_char_to_buffer(match_visualizer);
                                    if (chr <= 9) {
                                        tex_aux_append_char_to_buffer(chr + '0');
                                    } else if (chr <= max_match_count) {
                                        tex_aux_append_char_to_buffer(chr + '0' + gap_match_count);
                                    } else {
                                        tex_aux_append_char_to_buffer('!'); 
                                        goto EXIT;
                                    }
                                } else {
                                    if (chr > max_match_count) {
                                        goto EXIT;
                                    }
                                }
                                break;
                            case match_cmd:
                                if (! skip) {
                                    tex_aux_append_char_to_buffer(match_visualizer);
                                }
                                if (is_valid_match_ref(chr)) {
                                    ++n;
                                }
                                if (! skip) {
                                 // tex_aux_append_char_to_buffer(chr ? chr : '0');
                                    if (chr <= 9) {
                                        tex_aux_append_char_to_buffer(chr + '0');
                                    } else if (chr <= max_match_count) {
                                        tex_aux_append_char_to_buffer(chr + '0' + gap_match_count);
                                    }
                                }
                                if (n > max_match_count) {
                                    goto EXIT;
                                }
                                break;
                            case end_match_cmd:
                                if (chr == 0) {
                                    if (! skip) {
                                        tex_aux_append_char_to_buffer('-');
                                        tex_aux_append_char_to_buffer('>');
                                    }
                                    skip = 0 ;
                                }
                                break;
                            /*
                            case string_cmd:
                                c = c + cs_offset_value;
                                do_make_room((int) str_length(c));
                                for (int i = 0; i < str_length(c); i++) {
                                    token_state.buffer[token_state.bufloc++] = str_string(c)[i];
                                }
                                break;
                            */
                            case end_paragraph_cmd:
                                if (! inhibit_par && (auto_paragraph_mode(auto_paragraph_text))) {
                                    tex_aux_append_esc_to_buffer("par");
                                }
                                break;
                            default:
                                tex_aux_append_str_to_buffer(tex_aux_special_cmd_string(cmd, chr, error_string_bad(33)));
                                break;
                        }
                    } else if (! (inhibit_par && infop == lmt_token_state.par_token)) {
                        int q = infop - cs_token_flag;
                        if (q < hash_base) {
                            if (q == null_cs) {
                                tex_aux_append_esc_to_buffer("csname");
                                tex_aux_append_esc_to_buffer("endcsname");
                            } else {
                                tex_aux_append_str_to_buffer(error_string_impossible(34));
                            }
                        } else if (eqtb_out_of_range(q)) {
                            tex_aux_append_str_to_buffer(error_string_impossible(35));
                        } else {
                            strnumber txt = cs_text(q);
                            if (txt  < 0 || txt  >= lmt_string_pool_state.string_pool_data.ptr) {
                                tex_aux_append_str_to_buffer(error_string_nonexistent(36));
                            } else {
                                int allocated = 0;
                                char *sh = tex_makecstring(txt, &allocated);
                                char *s = sh;
                                if (tex_is_active_cs(txt)) {
                                    s = s + 3;
                                    while (*s) {
                                        tex_aux_append_char_to_buffer(*s);
                                        s++;
                                    }
                                } else {
                                    if (e >= 0) {
                                        tex_aux_append_uchar_to_buffer(e);
                                    }
                                    while (*s) {
                                        tex_aux_append_char_to_buffer(*s);
                                        s++;
                                    }
                                    if ((! nospace) && ((! tex_single_letter(txt)) || is_cat_letter(txt))) {
                                        tex_aux_append_char_to_buffer(' ');
                                    }
                                }
                                if (allocated) {
                                    lmt_memory_free(sh);    
                                }
                            }
                        }
                    }
                    tail = p; 
                    ++count;
                    p = token_link(p);
                }
            }
        EXIT:
            if (strip && lmt_token_state.bufloc > 1) { 
                if (lmt_token_state.buffer[lmt_token_state.bufloc-1] == strip) {
                    lmt_token_state.bufloc -= 1;
                }
                if (lmt_token_state.bufloc > 1 && lmt_token_state.buffer[0] == strip) {
                    memcpy(&lmt_token_state.buffer[0], &lmt_token_state.buffer[1], lmt_token_state.bufloc-1);
                    lmt_token_state.bufloc -= 1;
                }
            }
            lmt_token_state.buffer[lmt_token_state.bufloc] = '\0';
            if (siz) {
                *siz = lmt_token_state.bufloc;
            }
            if (wipe) { 
                tex_flush_token_list_head_tail(pp, tail, count);
            }
            return lmt_token_state.buffer;
        } else { 
            if (wipe) {
                 tex_put_available_token(pp);
            }
        }
    }
    if (siz) {
        *siz = 0;
    }
    return NULL;
}

/*tex

    The \LUA\ interface needs some extra functions. The functions themselves are quite boring, but
    they are handy because otherwise this internal stuff has to be accessed from \CCODE\ directly,
    where lots of the defines are not available.

*/

/* The bin gets 1.2K smaller if we inline these. */

halfword tex_get_tex_dimen_register     (int j, int internal) { return internal ? dimen_parameter(j) : dimen_register(j) ; }
halfword tex_get_tex_skip_register      (int j, int internal) { return internal ? glue_parameter(j) : skip_register(j) ; }
halfword tex_get_tex_mu_skip_register   (int j, int internal) { return internal ? mu_glue_parameter(j) : mu_skip_register(j); }
halfword tex_get_tex_count_register     (int j, int internal) { return internal ? count_parameter(j) : count_register(j)  ; }
halfword tex_get_tex_attribute_register (int j, int internal) { return internal ? attribute_parameter(j) : attribute_register(j) ; }
halfword tex_get_tex_box_register       (int j, int internal) { return internal ? box_parameter(j) : box_register(j) ; }

void tex_set_tex_dimen_register(int j, halfword v, int flags, int internal)
{
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (internal) {
        tex_assign_internal_dimen_value(flags, internal_dimen_location(j), v);
    } else {
        tex_word_define(flags, register_dimen_location(j), v);
    }
}

void tex_set_tex_skip_register(int j, halfword v, int flags, int internal)
{
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (internal) {
        tex_assign_internal_skip_value(flags, internal_glue_location(j), v);
    } else {
        tex_word_define(flags, register_glue_location(j), v);
    }
}

void tex_set_tex_mu_skip_register(int j, halfword v, int flags, int internal)
{
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    tex_word_define(flags, internal ? internal_mu_glue_location(j) : register_mu_glue_location(j), v);
}

void tex_set_tex_count_register(int j, halfword v, int flags, int internal)
{
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (internal) {
        tex_assign_internal_int_value(flags, internal_int_location(j), v);
    } else {
        tex_word_define(flags, register_int_location(j), v);
    }
}

void tex_set_tex_attribute_register(int j, halfword v, int flags, int internal)
{
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (j > lmt_node_memory_state.max_used_attribute) {
        lmt_node_memory_state.max_used_attribute = j;
    }
    tex_change_attribute_register(flags, register_attribute_location(j), v);
    tex_word_define(flags, internal ? internal_attribute_location(j) : register_attribute_location(j), v);
}

void tex_set_tex_box_register(int j, halfword v, int flags, int internal)
{
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (internal) {
        tex_define(flags, internal_box_location(j), internal_box_reference_cmd, v);
    } else {
        tex_define(flags, register_box_location(j), register_box_reference_cmd, v);
    }
}

void tex_set_tex_toks_register(int j, lstring s, int flags, int internal)
{
    halfword ref = get_reference_token();
    halfword head = tex_str_toks(s, NULL);
    set_token_link(ref, head);
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (internal) {
        tex_define(flags, internal_toks_location(j), internal_toks_reference_cmd, ref);
    } else {
        tex_define(flags, register_toks_location(j), register_toks_reference_cmd, ref);
    }
}

void tex_scan_tex_toks_register(int j, int c, lstring s, int flags, int internal)
{
    halfword ref = get_reference_token();
    halfword head = tex_str_scan_toks(c, s);
    set_token_link(ref, head);
    if (global_defs_par) {
        flags = add_global_flag(flags);
    }
    if (internal) {
        tex_define(flags, internal_toks_location(j), internal_toks_reference_cmd, ref);
    } else {
        tex_define(flags, register_toks_location(j), register_toks_reference_cmd, ref);
    }
}

int tex_get_tex_toks_register(int j, int internal)
{
    halfword t = internal ? toks_parameter(j) : toks_register(j);
    if (t) {
        return tex_tokens_to_string(t);
    } else {
        return get_nullstr();
    }
}

/* Options: (0) error when undefined [bad], (1) create [but undefined], (2) ignore [discard] */

halfword tex_parse_str_to_tok(halfword head, halfword *tail, halfword ct, const char *str, size_t lstr, int option)
{
    halfword p = null;
    if (! head) {
        head = get_reference_token();
    }
    p = (tail && *tail) ? *tail : head;
    if (lstr > 0) {
        const char *se = str + lstr;
        while (str < se) {
            /*tex hh: |str2uni| could return len too (also elsewhere) */
            int ul;
            halfword u = (halfword) aux_str2uni_len((const unsigned char *) str, &ul);
            halfword t = null;
            halfword cc = tex_get_cat_code(ct, u);
            str += ul;
            /*tex
                This is a relative simple converter; if more is needed one can just use |tex.print|
                with a regular |\def| or |\gdef| and feed the string into the regular scanner.
            */
            switch (cc) {
                case escape_cmd:
                    {
                        /*tex We have a potential control sequence so we check for it. */
                        int lname = 0;
                        const char *name  = str;
                        while (str < se) {
                            int s; 
                            halfword u = (halfword) aux_str2uni_len((const unsigned char *) str, &s);
                            int c = tex_get_cat_code(ct, u);
                            if (c == letter_cmd) {
                                str += s;
                                lname += s;
                            } else if (c == spacer_cmd) {
                                /*tex We ignore a trailing space like normal scanning does. */
                                if (lname == 0) {
                             // if (u == 32) {
                                    lname += s;
                                }
                                str += s;
                                break ;
                            } else {
                                if (lname == 0) {
                                    lname += s;
                                    str += s;
                                }
                                break ;
                            }
                        }
                        if (lname > 0) {
                            /*tex We have a potential |\cs|. */
                            halfword cs = tex_string_locate(name, lname, option == 1 ? 1 : 0); /* 1 == create */
                            if (cs == undefined_control_sequence) {
                                if (option == 2) {
                                    /*tex We ignore unknown commands. */
                                 // t = null;
                                } else {
                                    /*tex We play safe and backtrack, as we have option 0, but never used anyway. */
                                    t = u + (cc * (1<<21));
                                    str = name;
                                }
                            } else {
                                /* We end up here when option is 1. */
                                t = cs_token_flag + cs;
                            }
                        } else {
                            /*tex
                                Just a character with some meaning, so |\unknown| becomes effectively
                                |\unknown| assuming that |\\| has some useful meaning of course.
                            */
                            t = u + (cc * (1 << 21));
                            str = name;
                        }
                        break;
                    }
                case comment_cmd:
                    goto DONE;
                case ignore_cmd:
                    break;
                case spacer_cmd:
                 /* t = u + (cc * (1<<21)); */
                    t = token_val(spacer_cmd, ' ');
                    break;
                default:
                    /*tex
                        Whatever token, so for instance $x^2$ just works given a tex catcode regime.
                    */
                    t = u + (cc * (1<<21));
                    break;
            }
            if (t) {
                p = tex_store_new_token(p, t);
            }
        }
    }
  DONE:
    if (tail) {
        *tail = p;
    }
    return head;
}

/*tex So far for the helpers. */

void tex_dump_token_mem(dumpstream f)
{
    /*tex
        It doesn't pay off to prune the available list. We save less than 10K if we do this and
        it assumes a sequence at the end. It doesn't help that the list is in reverse order so
        we just dump the lot. But we do check the allocated size. We cheat a bit in reducing
        the ptr so that we can set the the initial counter on loading.
    */
    halfword p = lmt_token_memory_state.available;
    halfword u = lmt_token_memory_state.tokens_data.top + 1;
    while (p) {
        --u;
        p = token_link(p);
    }
    lmt_token_memory_state.tokens_data.ptr = u;
    dump_int(f, lmt_token_state.null_list); /* the only one left */
    dump_int(f, lmt_token_memory_state.tokens_data.allocated);
    dump_int(f, lmt_token_memory_state.tokens_data.top);
    dump_int(f, lmt_token_memory_state.tokens_data.ptr);
    dump_int(f, lmt_token_memory_state.available);
    dump_things(f, lmt_token_memory_state.tokens[0], lmt_token_memory_state.tokens_data.top + 1);
}

void tex_undump_token_mem(dumpstream f)
{
    undump_int(f, lmt_token_state.null_list); /* the only one left */
    undump_int(f, lmt_token_memory_state.tokens_data.allocated);
    undump_int(f, lmt_token_memory_state.tokens_data.top);
    undump_int(f, lmt_token_memory_state.tokens_data.ptr);
    undump_int(f, lmt_token_memory_state.available);
    tex_initialize_token_mem();
    undump_things(f, lmt_token_memory_state.tokens[0], lmt_token_memory_state.tokens_data.top + 1);
}
