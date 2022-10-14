/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

dump_state_info lmt_dump_state = {
    .fingerprint = luametatex_format_fingerprint,
    .padding     = 0
};

/*tex

    After \INITEX\ has seen a collection of fonts and macros, it can write all the necessary
    information on an auxiliary file so that production versions of \TEX\ are able to initialize
    their memory at high speed. The present section of the program takes care of such output and
    input. We shall consider simultaneously the processes of storing and restoring, so that the
    inverse relation between them is clear.

    The global variable |format_ident| is a string that is printed right after the |banner| line
    when \TEX\ is ready to start. For \INITEX\ this string says simply |(INITEX)|; for other
    versions of \TEX\ it says, for example, |(preloaded format = plain 1982.11.19)|, showing the
    year, month, and day that the format file was created. We have |format_ident = 0| before \TEX's
    tables are loaded. |FORMAT_ID| is a new field of type int suitable for the identification of a
    format: values between 0 and 256 (included) can not be used because in the previous format they
    are used for the length of the name of the engine.

    Because most used processors are little endian, we flush that way, but after that we just stick
    to the architecture. This also lets it come out as a readable 12 character (not nul terminated)
    string on a little endian machine. By using integers we can be sure that when it's generated on
    a different architecture the format is not seen as valid.

*/

/*

    In \LUAMETATEX\ the code has been overhauled. The sections are better separated and we write
    less to the file because we try to be sparse. Also, a more dynamic approach is used. In the
    \CONTEXT\ macro package most of what goes into the format is \LUA\ bytecode.

    We no longer hand endian related code here which saves swapping bytes on the most popular
    architectures. We also maintain some statistics and have several points where we check if
    we're still okay.

    Here we only have the main chunk. The specific data sections are implemented where it makes
    most sense.

*/

# define MAGIC_FORMAT_NUMBER_LE_1 0x58544D4C // 0x4C4D5458 // LMTX
# define MAGIC_FORMAT_NUMBER_LE_2 0x5845542D // 0x2D544558 // -TEX
# define MAGIC_FORMAT_NUMBER_LE_3 0x544D462D // 0x2D464D54 // -FMT

static int tex_aux_report_dump_state(dumpstream f, int pos, const char *what)
{
    int tmp = ftell(f);
    tex_print_format("%i %s", tmp - pos, what);
    fflush(stdout);
    return tmp;
}

/* todo: move more dumping to other files, then also the sizes. */

static void tex_aux_dump_fingerprint(dumpstream f)
{
    dump_via_int(f, MAGIC_FORMAT_NUMBER_LE_1);
    dump_via_int(f, MAGIC_FORMAT_NUMBER_LE_2);
    dump_via_int(f, MAGIC_FORMAT_NUMBER_LE_3);
    dump_via_int(f, luametatex_format_fingerprint);
}

static void tex_aux_undump_fingerprint(dumpstream f)
{
    int x;
    undump_int(f, x);
    if (x == MAGIC_FORMAT_NUMBER_LE_1) {
        undump_int(f, x);
        if (x == MAGIC_FORMAT_NUMBER_LE_2) {
            undump_int(f, x);
            if (x == MAGIC_FORMAT_NUMBER_LE_3) {
                undump_int(f, x);
                if (x == luametatex_format_fingerprint) {
                    return;
                } else {
                    tex_fatal_undump_error("version id");
                }
            }
        }
    }
    tex_fatal_undump_error("initial fingerprint");
}

static void tex_aux_dump_final_check(dumpstream f)
{
    dump_via_int(f, luametatex_format_fingerprint);
}

static void tex_aux_undump_final_check(dumpstream f)
{
    int x;
    undump_int(f, x);
    if (x == luametatex_format_fingerprint) {
        return;
    } else {
        tex_fatal_undump_error("final fingerprint");
    }
}

static void tex_aux_create_fmt_name(void)
{
    lmt_print_state.selector = new_string_selector_code;
//    lmt_dump_state.format_identifier = tex_make_string();
//    lmt_dump_state.format_name = tex_make_string();
    tex_print_format("%s %i.%i.%i %s",lmt_fileio_state.fmt_name, year_par, month_par, day_par, lmt_fileio_state.job_name);
    lmt_print_state.selector = terminal_and_logfile_selector_code;
}

static void tex_aux_dump_preamble(dumpstream f)
{
    dump_via_int(f, hash_size);
    dump_via_int(f, hash_prime);
    dump_via_int(f, prim_size);
    dump_via_int(f, prim_prime);
    dump_int(f, lmt_hash_state.hash_data.allocated);
    dump_int(f, lmt_hash_state.hash_data.ptr);
    dump_int(f, lmt_hash_state.hash_data.top);
}

static void tex_aux_undump_preamble(dumpstream f)
{
    int x;
    undump_int(f, x);
    if (x != hash_size) {
        goto BAD;
    }
    undump_int(f, x);
    if (x != hash_prime) {
        goto BAD;
    }
    undump_int(f, x);
    if (x != prim_size) {
        goto BAD;
    }
    undump_int(f, x);
    if (x != prim_prime) {
        goto BAD;
    }
    undump_int(f, lmt_hash_state.hash_data.allocated);
    undump_int(f, lmt_hash_state.hash_data.ptr);
    undump_int(f, lmt_hash_state.hash_data.top);
    /*tex
        We can consider moving all these allocaters to the start instead of this exception.
    */
    tex_initialize_hash_mem();
    return;
  BAD:
    tex_fatal_undump_error("preamble");
}

void tex_store_fmt_file(void)
{
    int pos = 0;
    dumpstream f = NULL;

    /*tex
        If dumping is not allowed, abort. The user is not allowed to dump a format file unless
        |save_ptr = 0|. This condition implies that |cur_level=level_one|, hence the |xeq_level|
        array is constant and it need not be dumped.
    */

    if (lmt_save_state.save_stack_data.ptr != 0) {
        tex_handle_error(
            succumb_error_type,
            "You can't dump inside a group",
            "'{...\\dump}' is a no-no."
        );
    }

    /*tex
        We don't store some things.
    */

    tex_dispose_specification_nodes();

    /*tex
        Create the |format_ident|, open the format file, and inform the user that dumping has begun.
    */

    {
        int callback_id = lmt_callback_defined(pre_dump_callback);
        if (callback_id > 0) {
            (void) lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "->");
        }
    }

    /*tex
        We report the usual plus some more statistics. When something is wrong the machine just
        quits, hopefully with some meaningful error. We always create the format in normal log and
        terminal mode. We create a format name first because we also use that in error reporting.
    */

    tex_aux_create_fmt_name();

    f = tex_open_fmt_file(1);
    if (! f) {
        tex_formatted_error("system", "format file '%s' cannot be opened for writing", lmt_fileio_state.fmt_name);
        return;
    }

    tex_print_nlp();
    tex_print_format("Dumping format in file '%s': ", lmt_fileio_state.fmt_name);
    fflush(stdout);

    tex_compact_tokens();
    tex_compact_string_pool();

    tex_aux_dump_fingerprint(f); pos = tex_aux_report_dump_state(f, pos, "fingerprint + ");
    lmt_dump_engine_info(f);     pos = tex_aux_report_dump_state(f, pos, "engine + ");
    tex_aux_dump_preamble(f);    pos = tex_aux_report_dump_state(f, pos, "preamble + ");
    tex_dump_constants(f);       pos = tex_aux_report_dump_state(f, pos, "constants + ");
    tex_dump_string_pool(f);     pos = tex_aux_report_dump_state(f, pos, "stringpool + ");
    tex_dump_node_mem(f);        pos = tex_aux_report_dump_state(f, pos, "nodes + ");
    tex_dump_token_mem(f);       pos = tex_aux_report_dump_state(f, pos, "tokens + ");
    tex_dump_equivalents_mem(f); pos = tex_aux_report_dump_state(f, pos, "equivalents + ");
    tex_dump_math_codes(f);      pos = tex_aux_report_dump_state(f, pos, "math codes + ");
    tex_dump_text_codes(f);      pos = tex_aux_report_dump_state(f, pos, "text codes + ");
    tex_dump_primitives(f);      pos = tex_aux_report_dump_state(f, pos, "primitives + ");
    tex_dump_hashtable(f);       pos = tex_aux_report_dump_state(f, pos, "hashtable + ");
    tex_dump_font_data(f);       pos = tex_aux_report_dump_state(f, pos, "fonts + ");
    tex_dump_math_data(f);       pos = tex_aux_report_dump_state(f, pos, "math + ");
    tex_dump_language_data(f);   pos = tex_aux_report_dump_state(f, pos, "language + ");
    tex_dump_insert_data(f);     pos = tex_aux_report_dump_state(f, pos, "insert + ");
    lmt_dump_registers(f);       pos = tex_aux_report_dump_state(f, pos, "bytecodes + ");
    tex_aux_dump_final_check(f); pos = tex_aux_report_dump_state(f, pos, "housekeeping = ");

    tex_aux_report_dump_state(f, 0, "total.");
    tex_close_fmt_file(f);
    tex_print_ln();

}

/*tex

    Corresponding to the procedure that dumps a format file, we have a function that reads one in.
    The function returns |false| if the dumped format is incompatible with the present \TEX\ table
    sizes, etc.

    The inverse macros are slightly more complicated, since we need to check the range of the values
    we are reading in. We say |undump (a) (b) (x)| to read an integer value |x| that is supposed to
    be in the range |a <= x <= b|.

*/

int tex_fatal_undump_error(const char *s)
{
    tex_emergency_message("system", "fatal format error, loading file '%s' failed with bad '%s' data, remake the format", emergency_fmt_name, s);
    return tex_emergency_exit();
}

//define undumping(s) printf("undumping: %s\n",s); fflush(stdout);
# define undumping(s)

static void tex_aux_undump_fmt_data(dumpstream f)
{
    undumping("warmingup")

    undumping("fingerprint") tex_aux_undump_fingerprint(f);
    undumping("engineinfo")  lmt_undump_engine_info(f);
    undumping("preamble")    tex_aux_undump_preamble(f);
    undumping("constants")   tex_undump_constants(f);
    undumping("strings")     tex_undump_string_pool(f);
    undumping("nodes")       tex_undump_node_mem(f);
    undumping("tokens")      tex_undump_token_mem(f);
    undumping("equivalents") tex_undump_equivalents_mem(f);
    undumping("mathcodes")   tex_undump_math_codes(f);
    undumping("textcodes")   tex_undump_text_codes(f);
    undumping("primitives")  tex_undump_primitives(f);
    undumping("hashtable")   tex_undump_hashtable(f);
    undumping("fonts")       tex_undump_font_data(f);
    undumping("math")        tex_undump_math_data(f);
    undumping("languages")   tex_undump_language_data(f);
    undumping("inserts")     tex_undump_insert_data(f);
    undumping("bytecodes")   lmt_undump_registers(f);
    undumping("finalcheck")  tex_aux_undump_final_check(f);

    undumping("done")

    /*tex This should go elsewhere. */

    cur_list.prev_depth = ignore_depth;
}

/*
    The next code plays nice but on an error we exit anyway so some code is never reached in that
    case.
*/

int tex_load_fmt_file(void)
{
    dumpstream f = tex_open_fmt_file(0);
    if (f) {
        tex_aux_undump_fmt_data(f);
        tex_close_fmt_file(f);
        return 1;
    } else {
        return tex_fatal_undump_error("filehandle");
    }
}

void tex_initialize_dump_state(void)
{
    if (! lmt_engine_state.dump_name) {
        lmt_engine_state.dump_name = lmt_memory_strdup("initex");
    }
}
