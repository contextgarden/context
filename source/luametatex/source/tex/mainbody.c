/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    This is where the action starts. We're speaking of \LUATEX, a continuation of
    \PDFTEX\ (which included \ETEX) and \ALEPH. As \TEX, \LUATEX\ is a document
    compiler intended to simplify high quality typesetting for many of the
    world's languages. It is an extension of D.E. Knuth's \TEX, which was
    designed essentially for the typesetting of languages using the Latin
    alphabet. Although it is a direct decendant of \TEX, and therefore mostly
    compatible, there are some subtle differences that relate to \UNICODE\
    support and \OPENTYPE\ math.

    The \ALEPH\ subsystem loosens many of the restrictions imposed by~\TeX:
    register numbers are no longer limited to 8~bits. Fonts may have more than
    256~characters, more than 256~fonts may be used, etc. We use a similar model.
    We also borrowed the directional model but have upgraded it a bit as well as
    integrated it more tightly.

    This program is directly derived from Donald E. Knuth's \TEX; the change
    history which follows and the reward offered for finders of bugs refer
    specifically to \TEX; they should not be taken as referring to \LUATEX,
    \PDFTEX, nor \ETEX, although the change history is relevant in that it
    demonstrates the evolutionary path followed. This program is not \TEX; that
    name is reserved strictly for the program which is the creation and sole
    responsibility of Professor Knuth.

    \starttyping
    % Version 0 was released in September 1982 after it passed a variety of tests.
    % Version 1 was released in November 1983 after thorough testing.
    % Version 1.1 fixed ``disappearing font identifiers'' et alia (July 1984).
    % Version 1.2 allowed `0' in response to an error, et alia (October 1984).
    % Version 1.3 made memory allocation more flexible and local (November 1984).
    % Version 1.4 fixed accents right after line breaks, et alia (April 1985).
    % Version 1.5 fixed \the\toks after other expansion in \edefs (August 1985).
    % Version 2.0 (almost identical to 1.5) corresponds to "Volume B" (April 1986).
    % Version 2.1 corrected anomalies in discretionary breaks (January 1987).
    % Version 2.2 corrected "(Please type...)" with null \endlinechar (April 1987).
    % Version 2.3 avoided incomplete page in premature termination (August 1987).
    % Version 2.4 fixed \noaligned rules in indented displays (August 1987).
    % Version 2.5 saved cur_order when expanding tokens (September 1987).
    % Version 2.6 added 10sp slop when shipping leaders (November 1987).
    % Version 2.7 improved rounding of negative-width characters (November 1987).
    % Version 2.8 fixed weird bug if no \patterns are used (December 1987).
    % Version 2.9 made \csname\endcsname's "relax" local (December 1987).
    % Version 2.91 fixed \outer\def\a0{}\a\a bug (April 1988).
    % Version 2.92 fixed \patterns, also file names with complex macros (May 1988).
    % Version 2.93 fixed negative halving in allocator when mem_min<0 (June 1988).
    % Version 2.94 kept open_log_file from calling fatal_error (November 1988).
    % Version 2.95 solved that problem a better way (December 1988).
    % Version 2.96 corrected bug in "Infinite shrinkage" recovery (January 1989).
    % Version 2.97 corrected blunder in creating 2.95 (February 1989).
    % Version 2.98 omitted save_for_after at outer level (March 1989).
    % Version 2.99 caught $$\begingroup\halign..$$ (June 1989).
    % Version 2.991 caught .5\ifdim.6... (June 1989).
    % Version 2.992 introduced major changes for 8-bit extensions (September 1989).
    % Version 2.993 fixed a save_stack synchronization bug et alia (December 1989).
    % Version 3.0 fixed unusual displays; was more \output robust (March 1990).
    % Version 3.1 fixed nullfont, disabled \write{\the\prevgraf} (September 1990).
    % Version 3.14 fixed unprintable font names and corrected typos (March 1991).
    % Version 3.141 more of same; reconstituted ligatures better (March 1992).
    % Version 3.1415 preserved nonexplicit kerns, tidied up (February 1993).
    % Version 3.14159 allowed fontmemsize to change; bulletproofing (March 1995).
    % Version 3.141592 fixed \xleaders, glueset, weird alignments (December 2002).
    % Version 3.1415926 was a general cleanup with minor fixes (February 2008).
    \stoptyping

    Although considerable effort has been expended to make the \LUATEX\ program
    correct and reliable, no warranty is implied; the authors disclaim any
    obligation or liability for damages, including but not limited to special,
    indirect, or consequential damages arising out of or in connection with the
    use or performance of this software. This work has been a \quote {labor of
    love| and the authors (Hartmut Henkel, Taco Hoekwater, Hans Hagen and Luigi
    Scarso) hope that users enjoy it.

    After a decade years of experimenting and reaching a more or less stable
    state, \LUATEX\ 1.0 was released and a few years later end 2018 we were at
    version 1.1 which is a meant to be a stable version. No more substantial
    additions will take place. As a follow up we decided to experiment with a
    stripped down version, basically the \TEX\ core without backend and with
    minimal font and file management. We'll see where that ends.

    {\em You will find a lot of comments that originate in original \TEX. We kept
    them as a side effect of the conversion from \WEB\ to \CWEB. Because there is
    not much webbing going on here eventually the files became regular \CCODE\
    files with still potentially typeset comments. As we add our own comments,
    and also comments are there from \PDFTEX, \ALEPH\ and \ETEX, we get a curious
    mix. The best comments are of course from Don Knuth. All bad comments are
    ours. All errors are ours too!

    Not all comments make sense, because some things are implemented differently,
    for instance some memory management. But the principles of tokens and nodes
    stayed. It anyway means that you sometimes need to keep in mind that the
    explanation is more geared to traditional \TEX. But that's not a bad thing.
    Sorry Don for any confusion we introduced. The readers should have a copy of
    the \TEX\ books at hand anyway.}

    A large piece of software like \TEX\ has inherent complexity that cannot be
    reduced below a certain level of difficulty, although each individual part is
    fairly simple by itself. The \WEB\ language is intended to make the
    algorithms as readable as possible, by reflecting the way the individual
    program pieces fit together and by providing the cross-references that
    connect different parts. Detailed comments about what is going on, and about
    why things were done in certain ways, have been liberally sprinkled
    throughout the program. These comments explain features of the
    implementation, but they rarely attempt to explain the \TeX\ language itself,
    since the reader is supposed to be familiar with {\em The \TeX book}.

    The present implementation has a long ancestry, beginning in the summer
    of~1977, when Michael~F. Plass and Frank~M. Liang designed and coded a
    prototype based on some specifications that the author had made in May of
    that year. This original proto\TEX\ included macro definitions and elementary
    manipulations on boxes and glue, but it did not have line-breaking,
    page-breaking, mathematical formulas, alignment routines, error recovery, or
    the present semantic nest; furthermore, it used character lists instead of
    token lists, so that a control sequence like |\halign| was represented by a
    list of seven characters. A complete version of \TEX\ was designed and coded
    by the author in late 1977 and early 1978; that program, like its prototype,
    was written in the SAIL language, for which an excellent debugging system was
    available. Preliminary plans to convert the SAIL code into a form somewhat
    like the present \quotation {web} were developed by Luis Trabb~Pardo and the
    author at the beginning of 1979, and a complete implementation was created by
    Ignacio~A. Zabala in 1979 and 1980. The \TEX82 program, which was written by
    the author during the latter part of 1981 and the early part of 1982, also
    incorporates ideas from the 1979 implementation of \TeX\ in {MESA} that was
    written by Leonidas Guibas, Robert Sedgewick, and Douglas Wyatt at the Xerox
    Palo Alto Research Center. Several hundred refinements were introduced into
    \TEX82 based on the experiences gained with the original implementations, so
    that essentially every part of the system has been substantially improved.
    After the appearance of Version 0 in September 1982, this program benefited
    greatly from the comments of many other people, notably David~R. Fuchs and
    Howard~W. Trickey. A final revision in September 1989 extended the input
    character set to eight-bit codes and introduced the ability to hyphenate
    words from different languages, based on some ideas of Michael~J. Ferguson.

    No doubt there still is plenty of room for improvement, but the author is
    firmly committed to keeping \TEX82 frozen from now on; stability and
    reliability are to be its main virtues. On the other hand, the \WEB\
    description can be extended without changing the core of \TEX82 itself, and
    the program has been designed so that such extensions are not extremely
    difficult to make. The |banner| string defined here should be changed
    whenever \TEX\ undergoes any modifications, so that it will be clear which
    version of \TEX\ might be the guilty party when a problem arises.

    This program contains code for various features extending \TEX, therefore
    this program is called \LUATEX\ and not \TEX; the official name \TEX\ by
    itself is reserved for software systems that are fully compatible with each
    other. A special test suite called the \quote {TRIP test} is available for
    helping to determine whether a particular implementation deserves to be known
    as \TEX\ [cf.~Stanford Computer Science report CS1027, November 1984].

    A similar test suite called the \quote {e-TRIP test} is available for helping
    to determine whether a particular implementation deserves to be known as
    \ETEX.

    {\em NB: Although \LUATEX\ can pass lots of the test it's not trip
    compatible: we use \UTF, support different font models, have adapted the
    backend to todays demands, etc.}

    This is the first of many sections of \TEX\ where global variables are
    defined.

*/

/*tex

    This program has two important variations: (1) There is a long and slow
    version called \INITEX, which does the extra calculations needed to
    initialize \TEX's internal tables; and (2)~there is a shorter and faster
    production version, which cuts the initialization to a bare minimum.

*/

main_state_info main_state ;

/*tex

    This state registers if are we are |INITEX| with |ini_version|,
    keeps the \TEX\ width of context lines on terminal error messages in
    |error_line| and the width of first lines of contexts in terminal
    error messages in |half_error_line| which should be
    between 30 and |error_line-15|. The width of longest text lines
    output, which should be at least 60, is strored in |max_print_line|
    and the maximum number of strings, which must not exceed |max_halfword|
    is kept in |max_strings|.

    The number of strings available after format loaded is |strings_free|, the
    maximum number of characters simultaneously present in current lines of open
    files and in control sequences between |\csname| and |\endcsname|, which must
    not exceed |max_halfword|, is kept in |buf_size|. The maximum number of
    simultaneous input sources is in |stack_size| and the maximum number of input
    files and error insertions that can be going on simultaneously in
    |max_in_open|. The maximum number of simultaneous macro parameters is in
    |param_size| and the maximum number of semantic levels simultaneously active
    in |nest_size|. The space for saving values outside of current group, which
    must be at most |max_halfword|, is in |save_size| and the depth of recursive
    calls of the |expand| procedure is limited by |expand_depth|.

    The times recent outputs that didn't ship anything out is tracked with
    |dead_cycles|. All these (formally single global) variables are collected in
    one state structure. (The error reporting is to some extent an implementation
    detail. As errors can be intercepted by \LUA\ we keep things simple.)

    We have noted that there are two versions of \TEX82. One, called \INITEX, has
    to be run first; it initializes everything from scratch, without reading a
    format file, and it has the capability of dumping a format file. The other
    one is called \VIRTEX; it is a \quote {virgin} program that needs to input a
    format file in order to get started. (This model has been adapted for a long
    time by the \TEX\ distributions, that ship multiple platforms and provide a
    large infrastructure.)

    For \LUATEX\ it is important to know that we still dump a format. But, in
    order to gain speed and a smaller footprint, we gzip the format (level 3). We
    also store some information that makes an abort possible in case of an
    incompatible engine version, which is important as \LUATEX\ develops. It is
    possible to store \LUA\ code in the format but not the current upvalues so
    you still need to initialize. Also, traditional fonts are stored, as are
    extended fonts but any additional information needed for instance to deal
    with \OPENTYPE\ fonts is to be handled by \LUA\ code and therefore not
    present in the format. (Actually, this version no longer stores fonts at
    all.)

*/

#define setup_texconfig_var_min_max(A,B,C) do { \
    get_lua_number("texconfig",B,&C); \
    if (C == 0) { \
        C = inf_##A; \
    } else if (C < inf_##A) { \
        C = inf_##A; \
    } else if (C > sup_##A) { \
        C = sup_##A; \
    } \
} while (0)

#define setup_texconfig_var_default(A,B,C) do { \
    get_lua_number("texconfig",B,&C); \
    if (C == 0) { \
        C = inf_##A; \
    } else if (C < inf_##A) { \
        C = inf_##A; \
    } \
} while (0)

int main_initialize(void)
{
    /*
        In case somebody has inadvertently made bad settings of the constants,
        \LUATEX\ checks them using a variable called |bad|.
    */
    int bad = 0;
    /*tex
        Bounds that may be set from the configuration file. We want the user to
        be able to specify the names with underscores, but \TANGLE\ removes
        underscores, so we're stuck giving the names twice, once as a string,
        once as the identifier. How ugly. (Actually, we no longer use |w| files.)
    */
    setup_texconfig_var_min_max(max_strings,     "max_strings",     main_state.max_strings);
    setup_texconfig_var_min_max(strings_free,    "strings_free",    main_state.strings_free);
    setup_texconfig_var_min_max(buf_size,        "buf_size",        main_state.buf_size);
    setup_texconfig_var_min_max(nest_size,       "nest_size",       main_state.nest_size);
    setup_texconfig_var_min_max(max_in_open,     "max_in_open",     main_state.max_in_open);
    setup_texconfig_var_min_max(param_size,      "param_size",      main_state.param_size);
    setup_texconfig_var_min_max(save_size,       "save_size",       main_state.save_size);
    setup_texconfig_var_min_max(stack_size,      "stack_size",      main_state.stack_size);
    setup_texconfig_var_min_max(hash_extra,      "hash_extra",      hash_state.hash_extra);
    setup_texconfig_var_min_max(expand_depth,    "expand_depth",    main_state.expand_depth);
    setup_texconfig_var_default(error_line,      "error_line",      main_state.error_line);
    setup_texconfig_var_default(half_error_line, "half_error_line", main_state.half_error_line);
    setup_texconfig_var_default(fix_mem_init,    "fix_mem_init",    fixed_memory_state.fix_mem_init);
    /*tex A safeguard: */
    if (main_state.half_error_line > main_state.error_line) {
        main_state.half_error_line = main_state.error_line/2;
    }
    /*tex
        Array memory allocation
    */
    iobuffer = mallocarray(unsigned char, (unsigned) main_state.buf_size);
    nest = mallocarray(list_state_record, (unsigned) main_state.nest_size);
    save_stack = mallocarray(save_record, (unsigned) main_state.save_size);
    input_stack = mallocarray(in_state_record, (unsigned) main_state.stack_size);
    input_file = mallocarray(FILE *, (unsigned) main_state.max_in_open);
    input_file_callback_id = mallocarray(int, (unsigned) main_state.max_in_open);
    line_stack = mallocarray(int, (unsigned) main_state.max_in_open);
    eof_seen = mallocarray(int, (unsigned) main_state.max_in_open);
    grp_stack = mallocarray(save_pointer, (unsigned) main_state.max_in_open);
    if_stack = mallocarray(halfword, (unsigned) main_state.max_in_open);
    source_filename_stack = mallocarray(str_number, (unsigned) main_state.max_in_open);
    full_source_filename_stack = mallocarray(char *, (unsigned) main_state.max_in_open);
    param_stack = mallocarray(halfword, (unsigned) main_state.param_size);
    /*tex
        Only in ini mode:
    */
    init_string_pool();
    /* */
    if (main_state.ini_version) {
        fixed_memory_state.fixmem = mallocarray(smemory_word, fixed_memory_state.fix_mem_init + 1);
        memset((void *)(fixed_memory_state.fixmem), 0, (fixed_memory_state.fix_mem_init + 1) * sizeof(smemory_word));
        fixed_memory_state.fix_mem_min = 0;
        fixed_memory_state.fix_mem_max = fixed_memory_state.fix_mem_init;
        eqtb_top = eqtb_size + hash_state.hash_extra;
        if (hash_state.hash_extra == 0)
            hash_state.hash_top = undefined_control_sequence;
        else
            hash_state.hash_top = eqtb_top;
        hash_state.hash = mallocarray(two_halves, (unsigned) (hash_state.hash_top + 1));
        memset(hash_state.hash, 0, sizeof(two_halves) * (unsigned) (hash_state.hash_top + 1));
        eqtb = mallocarray(memory_word, (unsigned) (eqtb_top + 1));
        memset(eqtb, 0, sizeof(memory_word) * (unsigned) (eqtb_top + 1));
        init_string_pool_array((unsigned) main_state.max_strings);
        reset_cur_string();
    }
    /*tex
        Check the constant values \unknown
    */
    if ((main_state.half_error_line < 30) || (main_state.half_error_line > main_state.error_line - 15))
        bad = 1;
    if (hash_prime > hash_size)
        bad = 5;
    if (main_state.max_in_open >= (sup_max_in_open+1)) /* 128 */
        bad = 6;
    /*tex
        Here are the inequalities that the quarterword and halfword values
        must satisfy (or rather, the inequalities that they mustn't satisfy):
    */
    if ((min_quarterword > 0) || (max_quarterword < 0x7FFF))
        bad = 11;
    if ((min_halfword > 0) || (max_halfword < 0x3FFFFFFF))
        bad = 12;
    if ((min_quarterword < min_halfword) || (max_quarterword > max_halfword))
        bad = 13;
    if (font_base < min_quarterword)
        bad = 15;
    if ((main_state.save_size > max_halfword) || (main_state.max_strings > max_halfword))
        bad = 17;
    if (main_state.buf_size > max_halfword)
        bad = 18;
    if (max_quarterword - min_quarterword < 0xFFFF)
        bad = 19;
    if (cs_token_flag + eqtb_size + hash_state.hash_extra > max_halfword)
        bad = 21;
    if (bad > 0) {
        wterm_cr();
        fprintf(term_out,
            "Ouch---my internal constants have been clobbered! ---case %d",
            (int) bad
        );
    } else {
        /*tex Set global variables to their starting values. */
        initialize();
        if (main_state.ini_version) {
            /*tex Initialize all the primitives. */
            no_new_control_sequence = 0;
            iofirst = 0;
            initialize_commands();
            string_pool_state.init_str_ptr = string_pool_state.str_ptr;
            no_new_control_sequence = 1;
            fix_date_and_time();
        }
        main_state.ready_already = 314159;
    }
    return bad;
}

void main_body(void)
{
    int bad = main_initialize();
    /*tex in case we quit during initialization */
    error_state.history = fatal_error_stop;
    if (bad > 0) {
        goto FINAL_END;
    }
    print_banner();
    /*tex
        Get the first line of input and prepare to start When we begin the
        following code, \TEX's tables may still contain garbage; the strings
        might not even be present. Thus we must proceed cautiously to get
        bootstrapped in.

        But when we finish this part of the program, \TEX\ is ready to call on
        the |main_control| routine to do its work.
    */
    /*tex
        This copies the command line,
    */
    initialize_inputstack();
    /*
    if (iobuffer[iloc] == '*') {
        incr(iloc);
    }
    if ((dump_state.format_ident == 0) || (iobuffer[iloc] == '&')) {
    */
    if (dump_state.format_ident == 0) {
        if (dump_state.format_ident != 0 && !main_state.ini_version) {
            /*tex Erase preloaded format. */
            initialize();
        }
        if (!load_fmt_file()) {
            goto FINAL_END;
        } else {
            while ((iloc < ilimit) && (iobuffer[iloc] == ' ')) {
                incr(iloc);
            }
        }
    }
    /* */
    if (end_line_char_inactive) {
        decr(ilimit);
    } else {
        iobuffer[ilimit] = (unsigned char) end_line_char_par;
    }
    fix_date_and_time();
    initialize_math();
    fixup_selector(fileio_state.log_opened); /* hm, the log is not yet opened anyway */
    check_texconfig_init();
    if ((iloc < ilimit) && (get_cat_code(cat_code_table_par, iobuffer[iloc]) != escape_cmd)) {
        /*tex |\input| assumed */
        start_input();
    }
    /*tex Initialize |text_dir_ptr| */
    text_dir_ptr = new_dir(normal_dir,0);
    /*tex Ready to go! */
    error_state.history = spotless;
    /*tex Come to life. */
    main_control();
    flush_node(text_dir_ptr);
    /*tex Prepare for death. */
    final_cleanup();
    close_files_and_terminate();
  FINAL_END:
    do_final_end();
}

/*tex

    Here we do whatever is needed to complete \TEX's job gracefully on the local
    operating system. The code here might come into play after a fatal error; it
    must therefore consist entirely of \quote {safe} operations that cannot
    produce error messages. For example, it would be a mistake to call |str_room|
    or |make_string| at this time, because a call on |overflow| might lead to an
    infinite loop.

    Actually there's one way to get error messages, via |prepare_mag|; but that
    can't cause infinite recursion.

    This program doesn't bother to close the input files that may still be open.

*/

void close_files_and_terminate(void)
{
    int callback_id;
    callback_id = callback_defined(stop_run_callback);
    if (tracing_stats_par > 0) {
        if (callback_id == 0) {
            /*tex
                Output statistics about this job. The present section goes
                directly to the log file instead of using |print| commands,
                because there's no need for these strings to take up
                |string_pool| memory.
            */
            if (fileio_state.log_opened) {
                fprintf(log_file,
                    "\n\nHere is how much of LuaTeX's memory you used:\n"
                );
                fprintf(log_file,
                    " %d string%s out of %d\n",
                    (int) (string_pool_state.str_ptr - string_pool_state.init_str_ptr),
                    (string_pool_state.str_ptr == (string_pool_state.init_str_ptr + 1) ? "" : "s"),
                    (int) (main_state.max_strings - string_pool_state.init_str_ptr + STRING_OFFSET)
                );
                fprintf(log_file,
                    " %d,%d words of node,token memory allocated",
                    (int) var_mem_max, (int) fixed_memory_state.fix_mem_max
                );
                print_node_mem_stats();
                fprintf(log_file,
                    " %d multiletter control sequences out of %ld+%d\n",
                    (int) hash_state.cs_count, (long) hash_size, (int) hash_state.hash_extra
                );
                fprintf(log_file,
                    " %d font%s using %d bytes\n",
                    (int) max_font_id(), (max_font_id() == 1 ? "" : "s"), font_state.font_bytes
                );
                fprintf(log_file,
                    " %di,%dn,%dp,%db,%ds stack positions out of %di,%dn,%dp,%db,%ds\n",
                    (int) max_in_stack, (int) max_nest_stack,
                    (int) max_param_stack, (int) max_buf_stack,
                    (int) max_save_stack + 6, (int) main_state.stack_size,
                    (int) main_state.nest_size, (int) main_state.param_size, (int) main_state.buf_size,
                    (int) main_state.save_size
                );
            }
        }
    }
    wake_up_terminal();
    if (fileio_state.log_opened) {
        wlog_cr();
        selector = selector - 2;
        if ((selector == term_only) && (callback_id == 0)) {
            tprint_nl("Transcript written on ");
            tprint_file_name((unsigned char *)fileio_state.log_name);
            print_char('.');
            print_ln();
        }
        close_log_file();
    }
    callback_id = callback_defined(wrapup_run_callback);
    if (callback_id > 0) {
        run_callback(callback_id, "->");
    }
    free_text_codes();
    free_math_codes();
}

/*tex

    We get to the |final_cleanup| routine when |\end| or |\dump| has been scanned
    and |its_all_over|.

*/

void final_cleanup(void)
{
    /*tex Here's one for looping marks: */
    halfword i;
    /*tex This was a global temp_ptr: */
    halfword t;
    /*tex This one gets the value 0 for |\end|, 1 for |\dump|. */
    int c = cur_chr;
    if (fileio_state.job_name == NULL)
        open_log_file();
    while (input_ptr > 0)
        if (istate == token_list)
            end_token_list();
        else
            end_file_reading();
    while (open_parens > 0) {
        report_stop_file();
        decr(open_parens);
    }
    if (cur_level > level_one) {
        tprint_nl("(\\end occurred inside a group at level ");
        print_int(cur_level - level_one);
        print_char(')');
        show_save_groups();
    }
    while (cond_ptr != null) {
        tprint_nl("(\\end occurred when ");
        print_cmd_chr(if_test_cmd, cur_if);
        if (if_line != 0) {
            tprint(" on line ");
            print_int(if_line);
        }
        tprint(" was incomplete)");
        if_line = if_line_field(cond_ptr);
        cur_if = subtype(cond_ptr);
        t = cond_ptr;
        cond_ptr = vlink(cond_ptr);
        flush_node(t);
    }
    if (callback_defined(stop_run_callback) == 0) {
        if (error_state.history != spotless)
            if ((error_state.history == warning_issued) || (error_state.interaction < error_stop_mode))
                if (selector == term_and_log) {
                    selector = term_only;
                    tprint_nl("(see the transcript file for additional information)");
                    selector = term_and_log;
                }
    }
    if (c == 1) {
        if (main_state.ini_version) {
            for (i = 0; i <= biggest_used_mark; i++) {
                delete_top_mark(i);
                delete_first_mark(i);
                delete_bot_mark(i);
                delete_split_first_mark(i);
                delete_split_bot_mark(i);
            }
            for (c = last_box_code; c <= vsplit_code; c++)
                flush_node_list(disc_ptr[c]);
            if (last_glue != max_halfword) {
                flush_node(last_glue);
            }
            /*tex Flush the pseudo files. */
            while (pseudo_files != null) {
                pseudo_close();
            }
            store_fmt_file();
        } else {
            tprint_nl("(\\dump is performed only by INITEX)");
        }
    }
    if (callback_defined(stop_run_callback) != 0) {
        run_callback(stop_run_callback, "->");
    }
}

/*tex

    Once \TEX\ is working, you should be able to diagnose most errors with the
    |\show| commands and other diagnostic features.

    Because we have made some internal changes the optional debug interface has
    been removed.

*/

void check_buffer_overflow(int wsize)
{
    if (wsize > main_state.buf_size) {
        int nsize = main_state.buf_size + main_state.buf_size / 5 + 5;
        if (nsize < wsize) {
            nsize = wsize + 5;
        }
        iobuffer = (unsigned char *) reallocarray(iobuffer, char, (unsigned) nsize);
        main_state.buf_size = nsize;
    }
}
