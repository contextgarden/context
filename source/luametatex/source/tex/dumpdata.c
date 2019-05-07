/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    We use a magic number to register the version of the format. Normally this
    number only increments when we add a new primitive of change command codes.
    We start with 907 which is the sum of the values of the bytes of \quote
    {don knuth}.

*/

# define FORMAT_ID (907+55)

dump_state_info dump_state = { 0, 0, NULL, NULL } ;

/*tex

    After \INITEX\ has seen a collection of fonts and macros, it can write all
    the necessary information on an auxiliary file so that production versions of
    \TEX\ are able to initialize their memory at high speed. The present section
    of the program takes care of such output and input. We shall consider
    simultaneously the processes of storing and restoring, so that the inverse
    relation between them is clear.

    The global variable |format_ident| is a string that is printed right after
    the |banner| line when \TEX\ is ready to start. For \INITEX\ this string says
    simply |(INITEX)|; for other versions of \TEX\ it says, for example,
    |(preloaded format = plain 1982.11.19)|, showing the year, month, and day that
    the format file was created. We have |format_ident = 0| before \TEX's tables
    are loaded. |FORMAT_ID| is a new field of type int suitable for the
    identification of a format: values between 0 and 256 (included) can not be
    used because in the previous format they are used for the length of the name
    of the engine.

*/

void store_fmt_file(void)
{
    int k, l, x;
    halfword p;
    char *format_engine;
    int callback_id;
    /*tex
        If dumping is not allowed, abort. The user is not allowed to dump a
        format file unless |save_ptr=0|. This condition implies that
        |cur_level=level_one|, hence the |xeq_level| array is constant and it
        need not be dumped.
    */
    if (save_ptr != 0) {
        print_err("You can't dump inside a group");
        help(
            "`{...\\dump}' is a no-no."
        );
        succumb();
    }
    /*tex
        Create the |format_ident|, open the format file, and inform the user that
        dumping has begun.
    */
    callback_id = callback_defined(pre_dump_callback);
    if (callback_id > 0) {
        (void) run_callback(callback_id, "->");
    }
    selector = new_string;
    tprint(" (format=");
    tprint(fileio_state.fmt_name);
    print_char(' ');
    print_int(year_par);
    print_char('.');
    print_int(month_par);
    print_char('.');
    print_int(day_par);
    print_char(')');
    str_room(2);
    dump_state.format_ident = make_string();
    tprint(fileio_state.job_name);
    dump_state.format_name = make_string();
    if (error_state.interaction == batch_mode) {
        selector = log_only;
    } else {
        selector = term_and_log;
    }
    if (!zopen_fmt_output(&dump_state.fmt_file)) {
        return;
    }
    tprint_nl("Beginning to dump on file ");
    tprint(fileio_state.fmt_name);
    tprint_nl("");
    print(dump_state.format_ident);
    /*tex
        Dump constants for consistency check. The next few sections of the
        program should make it clear how we use the dump/undump macros. First
        comes Web2C \TEX's magic constant: "W2TX"
    */
    dump_int(0x57325458);
    dump_int(FORMAT_ID);
    /*tex
        We align |engine_name| to 4 bytes with one or more trailing |NUL|.
    */
    x = (int) strlen(engine_state.engine_name);
    format_engine = malloc((unsigned) (x + 4));
    strcpy(format_engine, engine_state.engine_name);
    for (k = x; k <= x + 3; k++) {
        format_engine[k] = 0;
    }
    x = x + 4 - (x % 4);
    dump_int(x);
    dump_things(format_engine[0], x);
    free(format_engine);
    dump_int(0x57325458);
    dump_int(max_halfword);
    dump_int(hash_state.hash_high);
    dump_int(eqtb_size);
    dump_int(hash_prime);
    /*tex Dump the string pool. */
    k = dump_string_pool();
    print_ln();
    print_int(k);
    tprint(" strings using ");
    print_int(string_pool_state.pool_size);
    tprint(" bytes");
    /*tex
        Dump the dynamic memory. By sorting the list of available spaces in the
        variable-size portion of |mem|, we are usually able to get by without
        having to dump very much of the dynamic memory.

        We recompute |var_used| and |dyn_used|, so that \INITEX\ dumps valid
        information even when it has not been gathering statistics.
    */
    dump_node_mem();
    dump_int(temp_token_head);
    dump_int(hold_token_head);
    dump_int(omit_template);
    dump_int(null_list);
    dump_int(backup_head);
    x = (int) fixed_memory_state.fix_mem_min;
    dump_int(x);
    x = (int) fixed_memory_state.fix_mem_max;
    dump_int(x);
    x = (int) fixed_memory_state.fix_mem_end;
    dump_int(x);
    dump_int(fixed_memory_state.avail);
    fixed_memory_state.dyn_used = (int) fixed_memory_state.fix_mem_end + 1;
    dump_things(fixed_memory_state.fixmem[fixed_memory_state.fix_mem_min], fixed_memory_state.fix_mem_end - fixed_memory_state.fix_mem_min + 1);
    x = x + (int) (fixed_memory_state.fix_mem_end + 1 - fixed_memory_state.fix_mem_min);
    p = fixed_memory_state.avail;
    while (p) {
        decr(fixed_memory_state.dyn_used);
        p = token_link(p);
    }
    dump_int(fixed_memory_state.dyn_used);
    print_ln();
    print_int(x);
    tprint(" memory locations dumped; current usage is ");
    print_int(node_memory_state.var_used);
    print_char('&');
    print_int(fixed_memory_state.dyn_used);
    /*tex
        Dump regions 1 to 4 of |eqtb|, the table of equivalents. The table of
        equivalents usually contains repeated information, so we dump it in
        compressed form: The sequence of $n+2$ values $(n,x_1,\ldots,x_n,m)$ in
        the format file represents $n+m$ consecutive entries of |eqtb|, with |m|
        extra copies of $x_n$, namely $(x_1,\ldots,x_n,x_n,\ldots,x_n)$.
    */
    k = null_cs;
    do {
        int j = k;
        while (j < int_base - 1) {
            if ((equiv(j) == equiv(j + 1)) && (eq_type(j) == eq_type(j + 1)) &&
                (eq_level(j) == eq_level(j + 1)))
                goto FOUND1;
            incr(j);
        }
        l = int_base;
        /*tex |j=int_base-1| */
        goto DONE1;
      FOUND1:
        incr(j);
        l = j;
        while (j < int_base - 1) {
            if ((equiv(j) != equiv(j + 1)) || (eq_type(j) != eq_type(j + 1)) ||
                (eq_level(j) != eq_level(j + 1)))
                goto DONE1;
            incr(j);
        }
      DONE1:
        dump_int(l - k);
        dump_things(eqtb[k], l - k);
        k = j + 1;
        dump_int(k - l);
    } while (k != int_base);
    /*tex Dump regions 5 and 6 of |eqtb|. */
    do {
        int j = k;
        while (j < eqtb_size) {
            if (equiv_value(j) == equiv_value(j+1))
                goto FOUND2;
            incr(j);
        }
        l = eqtb_size + 1;
        /*tex |j=eqtb_size| */
        goto DONE2;
      FOUND2:
        incr(j);
        l = j;
        while (j < eqtb_size) {
            if (equiv_value(j) != equiv_value(j + 1))
                goto DONE2;
            incr(j);
        }
      DONE2:
        dump_int(l - k);
        dump_things(eqtb[k], l - k);
        k = j + 1;
        dump_int(k - l);
    } while (k <= eqtb_size);
    if (hash_state.hash_high > 0) {
        /*tex Dump the |hash_extra| part: */
        dump_things(eqtb[eqtb_size + 1], hash_state.hash_high);
    }
    dump_int(par_loc);
    dump_math_codes();
    dump_text_codes();
    /*tex
        Dump the hash table, A different scheme is used to compress the hash
        table, since its lower region is usually sparse. When |text(p)<>0| for
        |p<=hash_used|, we output two words, |p| and |hash[p]|. The hash table
        is, of course, densely packed for |p>=hash_used|, so the remaining
        entries are output in a~block.
     */
    dump_primitives();
    dump_int(hash_state.hash_used);
    hash_state.cs_count = frozen_control_sequence - 1 - hash_state.hash_used + hash_state.hash_high;
    for (p = hash_base; p <= hash_state.hash_used; p++) {
        if (cs_text(p) != 0) {
            dump_int(p);
            dump_hh(hash_state.hash[p]);
            incr(hash_state.cs_count);
        }
    }
    dump_things(hash_state.hash[hash_state.hash_used + 1],undefined_control_sequence - 1 - hash_state.hash_used);
    if (hash_state.hash_high > 0) {
        dump_things(hash_state.hash[eqtb_size + 1], hash_state.hash_high);
    }
    dump_int(hash_state.cs_count);
    print_ln();
    print_int(hash_state.cs_count);
    tprint(" multiletter control sequences");
    /*tex Dump the font information. */
    dump_int(max_font_id());
    /*tex We no longer dump font data. */
    dump_math_data();
    /*tex Dump the hyphenation tables. */
    dump_language_data();
    /*tex Dump a couple more things and the closing check word. */
    dump_int(error_state.interaction);
    dump_int(dump_state.format_ident);
    dump_int(dump_state.format_name);
    dump_int(69069);
    /*tex
        We have already printed a lot of statistics, so we set |tracing_stats:=0|
        to prevent them from appearing again.
    */
    tracing_stats_par = 0;
    /*tex Dump the \LUA\ bytecodes. */
    dump_luac_registers();
    /*tex Close the format file. */
    zclose_fmt(dump_state.fmt_file);
    print_ln();
}

/*tex

    Corresponding to the procedure that dumps a format file, we have a function
    that reads one in. The function returns |false| if the dumped format is
    incompatible with the present \TEX\ table sizes, etc.

    The inverse macros are slightly more complicated, since we need to check the
    range of the values we are reading in. We say `|undump(a)(b)(x)|' to read an
    integer value |x| that is supposed to be in the range |a<=x<=b|.

*/

# define undump(A,B,C) do { \
    undump_int(x); \
    if (x<(A) || x>(B)) { \
        goto BAD_FMT; \
    } else { \
        (C) = x; \
    } \
} while (0)

# define undump_size(A,B,C,D) do { \
    undump_int(x); \
    if (x<(A)) { \
        goto BAD_FMT; \
    } else if (x>(B)) { \
        wake_up_terminal(); \
        wterm_cr(); \
        formatted_warning("system","file '%s' cannot be loaded, you must increase the %s",fileio_state.fmt_name,(C)); \
        goto BAD_FMT; \
    } \
    (D) = x; \
} while (0)

static int undump_fmt_data(void)
{
    int j, k, x;
    halfword p;
    char *format_engine;
    /*tex Undump constants for consistency check .*/
    if (main_state.ini_version) {
        free(hash_state.hash);
        free(eqtb);
        free(fixed_memory_state.fixmem);
        free(varmem);
    }
    undump_int(x);
    if (x != 0x57325458) {
        wake_up_terminal();
        wterm_cr();
        formatted_warning("system","file '%s' is not a format file",fileio_state.fmt_name);
        return 0;
    }
    undump_int(x);
    if (x != FORMAT_ID) {
        wake_up_terminal();
        wterm_cr();
        formatted_warning("system","format file '%s' has the wrong version id",fileio_state.fmt_name);
        return 0;
    }
    undump_int(x);
    if ((x < 0) || (x > 256)) {
        wake_up_terminal();
        wterm_cr();
        formatted_warning("system","format file '%s' is currupt",fileio_state.fmt_name);
        return 0;
    }
    format_engine = malloc((unsigned) x);
    undump_things(format_engine[0], x);
    format_engine[x - 1] = 0;
    if (strcmp(engine_state.engine_name, format_engine)) {
        wake_up_terminal();
        wterm_cr();
        formatted_warning("system","format file '%s' was written by engine '%s'",fileio_state.fmt_name,format_engine);
        free(format_engine);
        return 0;
    }
    free(format_engine);
    undump_int(x);
    if (x != 0x57325458) {
        wake_up_terminal();
        wterm_cr();
        formatted_warning("system","format file '%s' was written by a different version",fileio_state.fmt_name);
        return 0;
    }
    undump_int(x);
    if (x != max_halfword) {
        goto BAD_FMT;
    }
    undump_int(hash_state.hash_high);
    if ((hash_state.hash_high < 0) || (hash_state.hash_high > sup_hash_extra)) {
        goto BAD_FMT;
    }
    if (hash_state.hash_extra < hash_state.hash_high) {
        hash_state.hash_extra = hash_state.hash_high;
    }
    eqtb_top = eqtb_size + hash_state.hash_extra;
    if (hash_state.hash_extra == 0) {
        hash_state.hash_top = undefined_control_sequence;
    } else {
        hash_state.hash_top = eqtb_top;
    }
    hash_state.hash = mallocarray(two_halves, (unsigned) (1 + hash_state.hash_top));
    memset(hash_state.hash, 0, sizeof(two_halves) * (unsigned) (hash_state.hash_top + 1));
    eqtb = mallocarray(memory_word, (unsigned) (eqtb_top + 1));
    set_eq_type(undefined_control_sequence, undefined_cs_cmd);
    set_equiv(undefined_control_sequence, null);
    set_eq_level(undefined_control_sequence, level_zero);
    for (x = eqtb_size + 1; x <= eqtb_top; x++) {
        eqtb[x] = eqtb[undefined_control_sequence];
    }
    undump_int(x);
    if (x != eqtb_size) {
        goto BAD_FMT;
    }
    undump_int(x);
    if (x != hash_prime) {
        goto BAD_FMT;
    }
    /*tex Undump the string pool */
    string_pool_state.str_ptr = undump_string_pool();
    /*tex Undump the dynamic memory */
    undump_node_mem();
    undump_int(temp_token_head);
    undump_int(hold_token_head);
    undump_int(omit_template);
    undump_int(null_list);
    undump_int(backup_head);
    undump_int(fixed_memory_state.fix_mem_min);
    undump_int(fixed_memory_state.fix_mem_max);
    fixed_memory_state.fixmem = mallocarray(smemory_word, fixed_memory_state.fix_mem_max + 1);
    memset((void *)(fixed_memory_state.fixmem), 0, (fixed_memory_state.fix_mem_max + 1) * sizeof(smemory_word));
    undump_int(fixed_memory_state.fix_mem_end);
    undump_int(fixed_memory_state.avail);
    undump_things(fixed_memory_state.fixmem[fixed_memory_state.fix_mem_min], fixed_memory_state.fix_mem_end - fixed_memory_state.fix_mem_min + 1);
    undump_int(fixed_memory_state.dyn_used);
    /*tex Undump regions 1 to 6 of the table of equivalents |eqtb|. */
    k = null_cs;
    do {
        undump_int(x);
        if ((x < 1) || (k + x > eqtb_size + 1))
            goto BAD_FMT;
        undump_things(eqtb[k], x);
        k = k + x;
        undump_int(x);
        if ((x < 0) || (k + x > eqtb_size + 1))
            goto BAD_FMT;
        for (j = k; j <= k + x - 1; j++)
            eqtb[j] = eqtb[k - 1];
        k = k + x;
    } while (k <= eqtb_size);
    if (hash_state.hash_high > 0) {
        /*tex undump |hash_extra| part */
        undump_things(eqtb[eqtb_size + 1], hash_state.hash_high);
    }
    undump(hash_base, hash_state.hash_top, par_loc);
    par_token = cs_token_flag + par_loc;
    undump_math_codes();
    undump_text_codes();
    /*tex Undump the hash table */
    undump_primitives();
    undump(hash_base, frozen_control_sequence, hash_state.hash_used);
    p = hash_base - 1;
    do {
        undump(p + 1, hash_state.hash_used, p);
        undump_hh(hash_state.hash[p]);
    } while (p != hash_state.hash_used);
    undump_things(hash_state.hash[hash_state.hash_used + 1], undefined_control_sequence - 1 - hash_state.hash_used);
    if (hash_state.hash_high > 0) {
        undump_things(hash_state.hash[eqtb_size + 1], hash_state.hash_high);
    }
    undump_int(hash_state.cs_count);
    /*tex We no longer undump the font information. */
    undump_int(x);
    /* set_max_font_id(x); */
    set_max_font_id(0);
    undump_math_data();
    /*tex Undump the hyphenation tables */
    undump_language_data();
    /*tex Undump a couple more things and the closing check word */
    undump(batch_mode, error_stop_mode, error_state.interaction);
    undump(0, string_pool_state.str_ptr, dump_state.format_ident);
    undump(0, string_pool_state.str_ptr, dump_state.format_name);
    undump_int(x);
    if (x != 69069) {
        goto BAD_FMT;
    }
    /*tex Undump the lua bytecodes. */
    undump_luac_registers();
    prev_depth_par = ignore_depth;
    return 1;
  BAD_FMT:
    wake_up_terminal();
    wterm_cr();
    formatted_warning("system","fatal format error, loading file '%s' failed",fileio_state.fmt_name);
    return 0;
}

int load_fmt_file(void)
{
    if (!open_fmt_file()) {
        formatted_warning("system","opening format file '%s' failed",fileio_state.fmt_name);
        return 0;
    } else if (!undump_fmt_data()) {
        formatted_warning("system","loading format file '%s' failed",fileio_state.fmt_name);
        close_fmt_file();
        return 0;
    } else {
        close_fmt_file();
        return 1;
    }
}
