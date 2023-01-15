/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    This is where the action starts. We're speaking of \LUATEX, a continuation of \PDFTEX\ (which
    included \ETEX) and \ALEPH. As \TEX, \LUATEX\ is a document compiler intended to simplify high
    quality typesetting for many of the world's languages. It is an extension of D.E. Knuth's \TEX,
    which was designed essentially for the typesetting of languages using the Latin alphabet.
    Although it is a direct decendant of \TEX, and therefore mostly compatible, there are some
    subtle differences that relate to \UNICODE\ support and \OPENTYPE\ math.

    The \ALEPH\ subsystem loosens many of the restrictions imposed by~\TeX: register numbers are no
    longer limited to 8~bits. Fonts may have more than 256~characters, more than 256~fonts may be
    used, etc. We use a similar model. We also borrowed the directional model but have upgraded it a
    bit as well as integrated it more tightly.

    This program is directly derived from Donald E. Knuth's \TEX; the change history which follows
    and the reward offered for finders of bugs refer specifically to \TEX; they should not be taken
    as referring to \LUATEX, \PDFTEX, nor \ETEX, although the change history is relevant in that it
    demonstrates the evolutionary path followed. This program is not \TEX; that name is reserved
    strictly for the program which is the creation and sole responsibility of Professor Knuth.

    \starttyping
    % Version 0 was released in September 1982 after it passed a variety of tests.
    % Version 1 was released in November 1983 after thorough testing.
    % Version 1.1 fixed "disappearing font identifiers" et alia (July 1984).
    % Version 1.2 allowed '0' in response to an error, et alia (October 1984).
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
    % Succesive versions have been checked and if needed fixes havebeen applied.
    \stoptyping

    Although considerable effort has been expended to make the \LUATEX\ program correct and
    reliable, no warranty is implied; the authors disclaim any obligation or liability for damages,
    including but not limited to special, indirect, or consequential damages arising out of or in
    connection with the use or performance of this software. This work has been a \quote {labor
    of love| and the authors (Hartmut Henkel, Taco Hoekwater, Hans Hagen and Luigi Scarso) hope that
    users enjoy it.

    After a decade years of experimenting and reaching a more or less stable state, \LUATEX\ 1.0 was
    released and a few years later end 2018 we were at version 1.1 which is a meant to be a stable
    version. No more substantial additions will take place (that happens in \LUAMETATEX). As a
    follow up we decided to experiment with a stripped down version, basically the \TEX\ core
    without backend and with minimal font and file management. We'll see where that ends.

    {\em You will find a lot of comments that originate in original \TEX. We kept them as a side
    effect of the conversion from \WEB\ to \CWEB. Because there is not much webbing going on here
    eventually the files became regular \CCODE\ files with still potentially typeset comments. As
    we add our own comments, and also comments are there from \PDFTEX, \ALEPH\ and \ETEX, we get a
    curious mix. The best comments are of course from Don Knuth. All bad comments are ours. All
    errors are ours too!

    Not all comments make sense, because some things are implemented differently, for instance some
    memory management. But the principles of tokens and nodes stayed. It anyway means that you
    sometimes need to keep in mind that the explanation is more geared to traditional \TEX. But that's
    not a bad thing. Sorry Don for any confusion we introduced. The readers should have a copy of the
    \TEX\ books at hand anyway.}

    A large piece of software like \TEX\ has inherent complexity that cannot be reduced below a certain
    level of difficulty, although each individual part is fairly simple by itself. The \WEB\ language
    is intended to make the algorithms as readable as possible, by reflecting the way the individual
    program pieces fit together and by providing the cross-references that connect different parts.
    Detailed comments about what is going on, and about why things were done in certain ways, have been
    liberally sprinkled throughout the program. These comments explain features of the implementation,
    but they rarely attempt to explain the \TeX\ language itself, since the reader is supposed to be
    familiar with {\em The \TeX book}.

    The present implementation has a long ancestry, beginning in the summer of~1977, when Michael~F.
    Plass and Frank~M. Liang designed and coded a prototype based on some specifications that the
    author had made in May of that year. This original proto\TEX\ included macro definitions and
    elementary manipulations on boxes and glue, but it did not have line-breaking, page-breaking,
    mathematical formulas, alignment routines, error recovery, or the present semantic nest;
    furthermore, it used character lists instead of token lists, so that a control sequence like |
    \halign| was represented by a list of seven characters. A complete version of \TEX\ was designed
    and coded by the author in late 1977 and early 1978; that program, like its prototype, was
    written in the SAIL language, for which an excellent debugging system was available. Preliminary
    plans to convert the SAIL code into a form somewhat like the present \quotation {web} were
    developed by Luis Trabb~Pardo and the author at the beginning of 1979, and a complete
    implementation was created by Ignacio~A. Zabala in 1979 and 1980. The \TEX82 program, which was
    written by the author during the latter part of 1981 and the early part of 1982, also
    incorporates ideas from the 1979 implementation of \TeX\ in {MESA} that was written by Leonidas
    Guibas, Robert Sedgewick, and Douglas Wyatt at the Xerox Palo Alto Research Center. Several
    hundred refinements were introduced into \TEX82 based on the experiences gained with the original
    implementations, so that essentially every part of the system has been substantially improved.
    After the appearance of Version 0 in September 1982, this program benefited greatly from the
    comments of many other people, notably David~R. Fuchs and Howard~W. Trickey. A final revision in
    September 1989 extended the input character set to eight-bit codes and introduced the ability to
    hyphenate words from different languages, based on some ideas of Michael~J. Ferguson.

    No doubt there still is plenty of room for improvement, but the author is firmly committed to
    keeping \TEX82 frozen from now on; stability and reliability are to be its main virtues. On the
    other hand, the \WEB\ description can be extended without changing the core of \TEX82 itself,
    and the program has been designed so that such extensions are not extremely difficult to make.
    The |banner| string defined here should be changed whenever \TEX\ undergoes any modifications,
    so that it will be clear which version of \TEX\ might be the guilty party when a problem arises.

    This program contains code for various features extending \TEX, therefore this program is called
    \LUATEX\ and not \TEX; the official name \TEX\ by itself is reserved for software systems that
    are fully compatible with each other. A special test suite called the \quote {TRIP test} is
    available for helping to determine whether a particular implementation deserves to be known
    as \TEX\ [cf.~Stanford Computer Science report CS1027, November 1984].

    A similar test suite called the \quote {e-TRIP test} is available for helping to determine
    whether a particular implementation deserves to be known as \ETEX.

    {\em NB: Although \LUATEX\ can pass lots of the test it's not trip compatible: we use \UTF,
    support different font models, have adapted the backend to todays demands, etc.}

    This is the first of many sections of \TEX\ where global variables are defined.

    The \LUAMETATEX\ source is an adaptation of the \LUATEX\ source and it took quite a bit of
    work to get there. I tried to stay close to the original Knuthian names and code but there are
    all kind of subtle differences with the \LUATEX\ code, which came from the \PASCAL\ code. And
    yes, all errors are mine (Hans).

*/

/*tex

    This program (we're talking of original \TEX\ here) has two important variations:

    \startitemize[n]
        \startitem
            There is a long and slow version called \INITEX, which does the extra calculations
            needed to initialize \TEX's internal tables; and
        \stopitem
        \startitem
            there is a shorter and faster production version, which cuts the initialization to
            a bare minimum.
        \stopitem
    \stopitemize

    Remark: Due to faster processors and media, the difference is not as large as it used to be,
    so \quote {long} and \quote {slow] no longer really apply. Making a \PDFTEX\ format takes 6
    seconds because patterns are loaded in \UTF-8 format which demands interpretation, while
    \XETEX\ which has native \UTF-8\ support takes just over 3 seconds. Making \CONTEXT\ \LMTX\
    format with \LUAMETATEX taked 2.54 seconds, and it involves loading hundreds of files with
    megabytes of code (much more than in \MKII). So it's not that bad. Loading a format file for
    a production run takes less than half a second (which includes quite some \LUA\ initialization).
    On a more modern machine these times are less of course.

*/

main_state_info lmt_main_state = {
    .run_state     = production_state,
    .ready_already = output_disabled_state,
    .start_time    = 0.0,
};

/*tex

    This state registers if are we are |INITEX| with |ini_version|, keeps the \TEX\ width of
    context lines on terminal error messages in |error_line| and the width of first lines of
    contexts in terminal error messages in |half_error_line| which should be between 30 and
    |error_line - 15|. The width of longest text lines output, which should be at least 60,
    is strored in |max_print_line| and the maximum number of strings, which must not exceed
    |max_halfword| is kept in |max_strings|.

    The number of strings available after format loaded is |strings_free|, the maximum number of
    characters simultaneously present in current lines of open files and in control sequences
    between |\csname| and |\endcsname|, which must not exceed |max_halfword|, is kept in
    |buf_size|. The maximum number of simultaneous input sources is in |stack_size| and the
    maximum number of input files and error insertions that can be going on simultaneously in
    |max_in_open|. The maximum number of simultaneous macro parameters is in |param_size| and
    the maximum number of semantic levels simultaneously active in |nest_size|. The space for
    saving values outside of current group, which must be at most |max_halfword|, is in
    |save_size| and the depth of recursive calls of the |expand| procedure is limited by
    |expand_depth|.

    The times recent outputs that didn't ship anything out is tracked with |dead_cycles|. All
    these (formally single global) variables are collected in one state structure. (The error
    reporting is to some extent an implementation detail. As errors can be intercepted by \LUA\
    we keep things simple.)

    We have noted that there are two versions of \TEX82. One, called \INITEX, has to be run
    first; it initializes everything from scratch, without reading a format file, and it has the
    capability of dumping a format file. The other one is called \VIRTEX; it is a \quote {virgin}
    program that needs to input a format file in order to get started. (This model has been
    adapted for a long time by the \TEX\ distributions, that ship multiple platforms and provide a
    large infrastructure.)

    For \LUATEX\ it is important to know that we still dump a format. But, in order to gain speed
    and a smaller footprint, we gzip the format (level 3). We also store some information that
    makes an abort possible in case of an incompatible engine version, which is important as
    \LUATEX\ develops. It is possible to store \LUA\ code in the format but not the current
    upvalues so you still need to initialize. Also, traditional fonts are stored, as are extended
    fonts but any additional information needed for instance to deal with \OPENTYPE\ fonts is to
    be handled by \LUA\ code and therefore not present in the format. (Actually, this version no
    longer stores fonts at all.)

*/

static void final_cleanup(int code);

void tex_main_body(void)
{

    tex_engine_set_limits_data("errorlinesize",     &lmt_error_state.line_limits);
    tex_engine_set_limits_data("halferrorlinesize", &lmt_error_state.half_line_limits);
    tex_engine_set_limits_data("expandsize",        &lmt_expand_state.limits);

    tex_engine_set_memory_data("buffersize",        &lmt_fileio_state.io_buffer_data);
    tex_engine_set_memory_data("filesize",          &lmt_input_state.in_stack_data);
    tex_engine_set_memory_data("fontsize",          &lmt_font_state.font_data);
    tex_engine_set_memory_data("hashsize",          &lmt_hash_state.hash_data);
    tex_engine_set_memory_data("inputsize",         &lmt_input_state.input_stack_data);
    tex_engine_set_memory_data("languagesize",      &lmt_language_state.language_data);
    tex_engine_set_memory_data("marksize",          &lmt_mark_state.mark_data);
    tex_engine_set_memory_data("insertsize",        &lmt_insert_state.insert_data);
    tex_engine_set_memory_data("nestsize",          &lmt_nest_state.nest_data);
    tex_engine_set_memory_data("nodesize",          &lmt_node_memory_state.nodes_data);
    tex_engine_set_memory_data("parametersize",     &lmt_input_state.parameter_stack_data);
    tex_engine_set_memory_data("poolsize",          &lmt_string_pool_state.string_body_data);
    tex_engine_set_memory_data("savesize",          &lmt_save_state.save_stack_data);
    tex_engine_set_memory_data("stringsize",        &lmt_string_pool_state.string_pool_data);
    tex_engine_set_memory_data("tokensize",         &lmt_token_memory_state.tokens_data);

    tex_initialize_fileio_state();
    tex_initialize_nest_state();
    tex_initialize_save_stack();
    tex_initialize_input_state();

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_string_mem();
    }

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_string_pool();
    }

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_token_mem();
        tex_initialize_hash_mem();
    }

    tex_initialize_errors();
    tex_initialize_nesting();
    tex_initialize_pagestate();
    tex_initialize_levels();
    tex_initialize_primitives();
    tex_initialize_marks();

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_inserts();
    }

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_node_mem();
    }

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_nodes();
        tex_initialize_tokens();
        tex_initialize_expansion();
        tex_initialize_alignments();
        tex_initialize_buildpage();
        tex_initialize_active();
        tex_initialize_equivalents();
        tex_initialize_math_codes();
        tex_initialize_text_codes();
        tex_initialize_cat_codes(0);
        tex_initialize_xx_codes();
    }

    tex_initialize_dump_state();
    tex_initialize_variables();
    tex_initialize_commands();
    tex_initialize_fonts();

    if (lmt_main_state.run_state == initializing_state) {
        tex_initialize_languages();
    }

    lmt_main_state.ready_already = output_enabled_state;

    /*tex in case we quit during initialization */

    lmt_error_state.history = fatal_error_stop;

    /*tex
        Get the first line of input and prepare to start When we begin the following code, \TEX's
        tables may still contain garbage; the strings might not even be present. Thus we must
        proceed cautiously to get bootstrapped in.

        But when we finish this part of the program, \TEX\ is ready to call on the |main_control|
        routine to do its work.

        This copies the command line:
    */

    tex_initialize_inputstack();

    if (lmt_main_state.run_state == initializing_state) {
        /* We start out fresh. */
    } else if (tex_load_fmt_file()) {

        tex_initialize_expansion();
        tex_initialize_alignments();

        aux_get_date_and_time(&time_par, &day_par, &month_par, &year_par, &lmt_engine_state.utc_time);

        while ((lmt_input_state.cur_input.loc < lmt_input_state.cur_input.limit) && (lmt_fileio_state.io_buffer[lmt_input_state.cur_input.loc] == ' ')) {
            ++lmt_input_state.cur_input.loc;
        }
    } else {
        tex_normal_exit();
    }

    if (end_line_char_inactive) {
        --lmt_input_state.cur_input.limit;
    } else {
        lmt_fileio_state.io_buffer[lmt_input_state.cur_input.limit] = (unsigned char) end_line_char_par;
    }

    aux_get_date_and_time(&time_par, &day_par, &month_par, &year_par, &lmt_engine_state.utc_time);

    tex_initialize_math();

    tex_fixup_selector(lmt_fileio_state.log_opened); /* hm, the log is not yet opened anyway */

    tex_engine_check_configuration();

    tex_initialize_directions();

    {
        char *ptr = tex_engine_input_filename();
        char *fln = NULL;
        tex_check_job_name(ptr);
        tex_open_log_file();
        tex_engine_get_config_string("firstline", &fln);
        if (fln) {
            tex_any_string_start(fln); /* experiment, see context lmtx */
        }
        if (ptr) {
            tex_start_input(ptr);
        } else if (! fln) {
            tex_emergency_message("startup error", "no input found, quitting");
            tex_emergency_exit();
        }
    }

    /*tex 
        We assume that |ignore_depth_criterium_par| is unchanged. If needed we can always do 
        this: 
    */

 /* cur_list.prev_depth = ignore_depth_criterium_par; */

    /*tex Ready to go, so come to life. */

    lmt_error_state.history = spotless;

 // {
 //     int dump = tex_main_control();
 //     if (dump && lmt_main_state.run_state != initializing_state) {
 //         /*tex Maybe we need to issue a warning here. For now we just ignore it. */
 //         dump = 0;
 //     }
 //     final_cleanup(dump);
 // }
    final_cleanup(tex_main_control());

    tex_close_files_and_terminate(0);

    tex_normal_exit();
}

/*tex

    Here we do whatever is needed to complete \TEX's job gracefully on the local operating system.
    The code here might come into play after a fatal error; it must therefore consist entirely of
    \quote {safe} operations that cannot produce error messages. For example, it would be a mistake
    to call |str_room| or |make_string| at this time, because a call on |overflow| might lead to an
    infinite loop.

    Actually there's one way to get error messages, via |prepare_mag|; but that can't cause infinite
    recursion.

    This program doesn't bother to close the input files that may still be open.

    We can decide to remove the reporting code here as it can (and in \CONTEXT\ will) be done in a
    callback anyway, so we never enter that branch.

    The output statistics go directly to the log file instead of using |print| commands, because
    there's no need for these strings to take up |string_pool| memory.

    We now assume a callback being set, if wanted at all, but we keep this as a reference so that
    we know what is of interest:

    \starttyping
    void close_files_and_terminate(int error)
    {
        int callback_id = lmt_callback_defined(stop_run_callback);
        if (fileio_state.log_opened) {
            if (callback_id == 0) {
                fprintf(print_state.log_file,
                    "\n\nHere is how much memory " My_Name " used:\n"
                );
                fprintf(print_state.log_file,
                    " %d strings out of %d\n",
                    string_pool_state.string_pool_data.ptr       - string_pool_state.reserved,
                    string_pool_state.string_pool_data.allocated - string_pool_state.reserved + STRING_OFFSET
                );
                fprintf(print_state.log_file,
                    " %d multiletter control sequences out of %d + %d extra\n",
                    hash_state.hash_data.real,
                    hash_size,
                    hash_state.hash_data.allocated
                );
                fprintf(print_state.log_file,
                    " %d words of node memory allocated out of %d",
                    node_memory_state.nodes_data.allocated,
                    node_memory_state.nodes_data.size
                );
                fprintf(print_state.log_file,
                    " %d words of token memory allocated out of %d",
                    token_memory_state.tokens_data.allocated,
                    token_memory_state.tokens_data.size
                );
                fprintf(print_state.log_file,
                    " %d font%s using %d bytes\n",
                    get_font_max_id(),
                    (get_font_max_id() == 1 ? "" : "s"),
                    font_state.font_bytes
                );
                fprintf(print_state.log_file,
                    " %d input stack positions out of %d\n",
                    input_state.input_stack_data.top,
                    input_state.input_stack_data.size
                );
                fprintf(print_state.log_file,
                    " %d nest stack positions out of %d\n",
                    nest_state.nest_data.top,
                    nest_state.nest_data.size
                );
                fprintf(print_state.log_file,
                    " %d parameter stack positions out of %d\n",
                    input_state.param_stack_data.top,
                    input_state.param_stack_data.size
                );
                fprintf(print_state.log_file,
                    " %d buffer stack positions out of %d\n",
                    fileio_state.io_buffer_data.top,
                    fileio_state.io_buffer_data.size
                );
                fprintf(print_state.log_file,
                    " %d save stack positions out of %d\n",
                    save_state.save_stack_data.top,
                    save_state.save_stack_data.size
                );
            }
            print_state.selector = print_state.selector - 2;
            if ((print_state.selector == term_only_selector_code) && (callback_id == 0)) {
                print_str_nl("Transcript written on ");
                print_file_name((unsigned char *) fileio_state.log_name);
                print_char('.');
                print_ln();
            }
            close_log_file();
        }
        callback_id = lmt_callback_defined(wrapup_run_callback);
        if (callback_id > 0) {
            lmt_run_callback(lua_state.lua_instance, callback_id, "b->", error);
        }
        free_text_codes();
        free_math_codes();
        free_languages();
    }
    \stoptyping
*/

void tex_close_files_and_terminate(int error)
{
    int callback_id = lmt_callback_defined(wrapup_run_callback);
    if (lmt_fileio_state.log_opened) {
        tex_close_log_file();
    }
    if (callback_id > 0) {
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "b->", error);
    }
}

/*tex

    We get to the |final_cleanup| routine when |\end| or |\dump| has been scanned and it's all
    over now.

*/

static void final_cleanup(int dump)
{
    int badrun = 0;
    if (! lmt_fileio_state.job_name) {
        tex_open_log_file ();
    }
    tex_cleanup_directions();
    while (lmt_input_state.input_stack_data.ptr > 0)
        if (lmt_input_state.cur_input.state == token_list_state) {
            tex_end_token_list();
        } else {
            tex_end_file_reading();
        }
    while (lmt_input_state.open_files > 0) {
        tex_report_stop_file();
        --lmt_input_state.open_files;
    }
    if (cur_level > level_one) {
        tex_print_format("(\\end occurred inside a group at level %i)", cur_level - level_one);
        tex_show_save_groups();
        badrun = 1;
    }
    while (lmt_condition_state.cond_ptr) {
        halfword t;
        if (lmt_condition_state.if_line != 0) {
            tex_print_format("(\\end occurred when %C on line %i was incomplete)", if_test_cmd, lmt_condition_state.cur_if, lmt_condition_state.if_line);
            badrun = 2;
        } else {
            tex_print_format("(\\end occurred when %C was incomplete)");
            badrun = 3;
        }
        lmt_condition_state.if_line = if_limit_line(lmt_condition_state.cond_ptr);
        lmt_condition_state.cur_if = node_subtype(lmt_condition_state.cond_ptr);
        t = lmt_condition_state.cond_ptr;
        lmt_condition_state.cond_ptr = node_next(lmt_condition_state.cond_ptr);
        tex_flush_node(t);
    }
    if (lmt_print_state.selector == terminal_and_logfile_selector_code && lmt_callback_defined(stop_run_callback) == 0) {
        if ((lmt_error_state.history == warning_issued) || (lmt_error_state.history != spotless && lmt_error_state.interaction < error_stop_mode)) {
            lmt_print_state.selector = terminal_selector_code;
            tex_print_message("see the transcript file for additional information");
            lmt_print_state.selector = terminal_and_logfile_selector_code;
        }
    }
    if (dump) {
        tex_cleanup_alignments();
        tex_cleanup_expansion();
        if (lmt_main_state.run_state == initializing_state) {
            for (int i = 0; i <= lmt_mark_state.mark_data.ptr; i++) {
                tex_wipe_mark(i);
            }
            tex_flush_node_list(lmt_packaging_state.page_discards_head);
            tex_flush_node_list(lmt_packaging_state.split_discards_head);
            if (lmt_page_builder_state.last_glue != max_halfword) {
                tex_flush_node(lmt_page_builder_state.last_glue);
            }
            for (int i = 0; i <= lmt_insert_state.insert_data.ptr; i++) {
                tex_wipe_insert(i);
            }
            tex_store_fmt_file();
        } else {
            tex_print_message("\\dump is performed only by INITEX");
            badrun = 4;
        }
    }
    if (lmt_callback_defined(stop_run_callback)) {
        /*
            We don't issue the error callback here (yet), mainly because we don't really know what
            bad things happened. This might evolve as currently it is not seen as fatal error.
        */
        lmt_run_callback(lmt_lua_state.lua_instance, stop_run_callback, "d->", badrun);
    }
}

