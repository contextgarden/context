/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

fileio_state_info lmt_fileio_state = {
   .io_buffer        = NULL,
   .io_buffer_data   = {
        .minimum   = min_buffer_size,
        .maximum   = max_buffer_size,
        .size      = siz_buffer_size,
        .step      = stp_buffer_size,
        .allocated = 0,
        .itemsize  = sizeof(unsigned char),
        .top       = 0,
        .ptr       = 0,
        .initial   = memory_data_unset,
        .offset    = 0,
   },
   .io_first         = 0,
   .io_last          = 0,
   .name_in_progress = 0,
   .log_opened       = 0,
   .job_name         = NULL,
   .log_name         = NULL,
   .fmt_name         = NULL
};

/*tex

    Once \TEX\ is working, you should be able to diagnose most errors with the |\show| commands and
    other diagnostic features. Because we have made some internal changes the optional debug interface
    has been removed.

*/

# define reserved_io_buffer_slots 256

void tex_initialize_fileio_state(void)
{
    int size = lmt_fileio_state.io_buffer_data.minimum;
    lmt_fileio_state.io_buffer = aux_allocate_clear_array(sizeof(unsigned char), size, reserved_io_buffer_slots);
    if (lmt_fileio_state.io_buffer) {
        lmt_fileio_state.io_buffer_data.allocated = size;
    } else {
        tex_overflow_error("buffer", size);
    }
}

int tex_room_in_buffer(int top)
{
    /*tex Beware: |top| can exceed the old size plus the step. */
    if (top > lmt_fileio_state.io_buffer_data.top) {
       lmt_fileio_state.io_buffer_data.top = top;
        if (top > lmt_fileio_state.io_buffer_data.allocated) {
            unsigned char *tmp = NULL;
            if (top <= lmt_fileio_state.io_buffer_data.size) {
                if (lmt_fileio_state.io_buffer_data.allocated + lmt_fileio_state.io_buffer_data.step > top) {
                    top = lmt_fileio_state.io_buffer_data.allocated + lmt_fileio_state.io_buffer_data.step;
                    if (top > lmt_fileio_state.io_buffer_data.size) {
                        top = lmt_fileio_state.io_buffer_data.size;
                    }
                }
                if (top > lmt_fileio_state.io_buffer_data.allocated) {
                    lmt_fileio_state.io_buffer_data.allocated = top;
                    tmp = aux_reallocate_array(lmt_fileio_state.io_buffer, sizeof(unsigned char), top, reserved_io_buffer_slots);
                    lmt_fileio_state.io_buffer = tmp;
                }
            }
            lmt_run_memory_callback("buffer", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("buffer", top);
                return 0;
            }
        }
    }
    return 1;
}

static int tex_aux_open_outfile(FILE **f, const char *name, const char *mode)
{
    FILE *res = aux_utf8_fopen(name, mode);
    if (res) {
        *f = res;
        return 1;
    }
    return 0;
}

/*tex

    We conform to the way \WEBC\ does handle trailing tabs and spaces. This decade old behaviour
    was changed in September 2017 and can introduce compatibility issues in existing workflows.
    Because we don't want too many differences with upstream \TEX live we just follow up on that
    patch and it's up to macro packages to deal with possible issues (which can be done via the
    usual callbacks. One can wonder why we then still prune spaces but we leave that to the reader.

    Patched original comment:

    Make last be one past the last non-space character in \quote {buffer}, ignoring line
    terminators (but not, e.g., tabs). This is because we are supposed to treat this like a line of
    TeX input. Although there are pathological cases (|SP CR SC CR|) where this differs from
    input_line below, and from previous behavior of removing all whitespace, the simplicity of
    removing all trailing line terminators seems more in keeping with actual command line
    processing.

    The |IS_SPC_OR_EOL| macro deals with space characters (|SPACE 32|) and newlines (|CR| and |LF|)
    and no longer looks at tabs (|TAB 9|).

*/

/*
    The terminal input code is gone as is the read related code (that had already been nicely
    cleaned up and abstracted but that is the price we pay for stepwise progress. That code is
    still in the git repository of course.

    At some point I might do the same as we do in mplib: four callbacks for open, close, read
    and write (in which case the log goes via write). Part of the management is them moved to
    \LUA\ and we save a lookup.

    When I adapted the code in this module and the one dealing with errors, I decided to delegate
    all interaction to \LUA, also because the sometimes tight integration in the scanning and
    expansion mechanisms. In the 2021 TeX tuneup there have been some patches in the interaction
    code and some remarks ring a bell: especially the relation between offering feedback and
    waiting for input. However, because we delegate to \LUA, the engine is no longer responsible
    for what the macro package lets the user do in case of an error. For instance, in \CONTEXT\ we
    just abort the run: it makes no sense to carry on the wrong way. Computers are fast enough for
    a \quotation {Fix and run again.} approach. But we do offer the message and optional help as
    cue. On the agenda is a further abstraction of error handling. This deviation is fine as we
    obey Don's wish to not call it \TEX\ but instead add some more letters to the name.

*/

int tex_lua_a_open_in(const char *fn)
{
    int callback_id = lmt_callback_defined(open_data_file_callback);
    if (callback_id > 0) {
        int k = lmt_run_and_save_callback(lmt_lua_state.lua_instance, callback_id, "S->", fn);
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].input_file_callback_id = k;
        return k > 0;
    } else {
        tex_emergency_message("startup error", "missing open_data_file callback");
        tex_emergency_exit();
        return 0;
    }
}

void tex_lua_a_close_in()
{
    int k = lmt_input_state.in_stack[lmt_input_state.cur_input.index].input_file_callback_id;
    if (k > 0) {
        lmt_run_saved_callback_close(lmt_lua_state.lua_instance, k);
        lmt_destroy_saved_callback(lmt_lua_state.lua_instance, k);
        lmt_input_state.in_stack[lmt_input_state.cur_input.index].input_file_callback_id = 0;
    }
}

/*tex

    Binary input and output are done with \CCODE's ordinary procedures, so we don't have to make
    any other special arrangements for binary \IO. Text output is also easy to do with standard
    routines. The treatment of text input is more difficult, however, because of the necessary
    translation to |unsigned char| values. \TEX's conventions should be efficient, and they should
    blend nicely with the user's operating environment.

    Input from text files is read one line at a time, using a routine called |lua_input_ln|. This
    function is defined in terms of global variables called |buffer|, |first|, and |last| that will
    be described in detail later; for now, it suffices for us to know that |buffer| is an array of
    |unsigned char| values, and that |first| and |last| are indices into this array representing
    the beginning and ending of a line of text.

    The lines of characters being read: |buffer|, the first unused position in |first|, the end of
    the line just input |last|, the largest index used in |buffer|: |max_buf_stack|.

    The |lua_input_ln| function brings the next line of input from the specified file into available
    positions of the buffer array and returns the value |true|, unless the file has already been
    entirely read, in which case it returns |false| and sets |last:=first|. In general, the
    |unsigned char| numbers that represent the next line of the file are input into |buffer[first]|,
    |buffer[first + 1]|, \dots, |buffer[last - 1]|; and the global variable |last| is set equal to
    |first| plus the length of the line. Trailing blanks are removed from the line; thus, either
    |last = first| (in which case the line was entirely blank) or |buffer[last - 1] <> " "|.

    An overflow error is given, however, if the normal actions of |lua_input_ln| would make |last
    >= buf_size|; this is done so that other parts of \TEX\ can safely look at the contents of
    |buffer[last+1]| without overstepping the bounds of the |buffer| array. Upon entry to
    |lua_input_ln|, the condition |first < buf_size| will always hold, so that there is always room
    for an \quote {empty} line.

    The variable |max_buf_stack|, which is used to keep track of how large the |buf_size| parameter
    must be to accommodate the present job, is also kept up to date by |lua_input_ln|.

    If the |bypass_eoln| parameter is |true|, |lua_input_ln| will do a |get| before looking at the
    first character of the line; this skips over an |eoln| that was in |f^|. The procedure does not
    do a |get| when it reaches the end of the line; therefore it can be used to acquire input from
    the user's terminal as well as from ordinary text files.

    Since the inner loop of |lua_input_ln| is part of \TEX's \quote {inner loop} --- each character
    of input comes in at this place --- it is wise to reduce system overhead by making use of
    special routines that read in an entire array of characters at once, if such routines are
    available.

*/

int tex_lua_input_ln(void) /*tex |bypass_eoln| was not used */
{
    int callback_id = lmt_input_state.in_stack[lmt_input_state.cur_input.index].input_file_callback_id;
    if (callback_id > 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        int last_ptr = 0;
        lmt_fileio_state.io_last = lmt_fileio_state.io_first;
        last_ptr = lmt_run_saved_callback_line(L, callback_id, lmt_fileio_state.io_first);
        if (last_ptr < 0) {
            return 0;
        } else if (last_ptr > 0) {
            lmt_fileio_state.io_last = last_ptr;
            if (last_ptr > lmt_fileio_state.io_buffer_data.top) {
                lmt_fileio_state.io_buffer_data.top = last_ptr;
            }
        }
        return 1;
    } else {
        return 0;
    }
}

/*tex

    We need a special routine to read the first line of \TEX\ input from the user's terminal.
    This line is different because it is read before we have opened the transcript file; there is
    sort of a \quote {chicken and egg} problem here. If the user types |\input paper| on the first
    line, or if some macro invoked by that line does such an |\input|, the transcript file will be
    named |paper.log|; but if no |\input| commands are performed during the first line of terminal
    input, the transcript file will acquire its default name |texput.log|. (The transcript file
    will not contain error messages generated by the first line before the first |\input| command.)

    The first line is special also because it may be read before \TEX\ has input a format file. In
    such cases, normal error messages cannot yet be given. The following code uses concepts that
    will be explained later.

    Different systems have different ways to get started. But regardless of what conventions are
    adopted, the routine that initializes the terminal should satisfy the following specifications:

    \startitemize[n]

        \startitem
            It should open file |term_in| for input from the terminal.
        \stopitem

        \startitem
            If the user has given a command line, this line should be considered the first line of
            terminal input. Otherwise the user should be prompted with |**|, and the first line of
            input should be whatever is typed in response.
        \stopitem

        \startitem
            The first line of input, which might or might not be a command line, should appear in
            locations |first| to |last-1| of the |buffer| array.
        \stopitem

        \startitem
            The global variable |loc| should be set so that the character to be read next by \TEX\
            is in |buffer[loc]|. This character should not be blank, and we should have |loc < last|.
        \stopitem

    \stopitemize

    It may be necessary to prompt the user several times before a non-blank line comes in. The
    prompt is |**| instead of the later |*| because the meaning is slightly different: |\input|
    need not be typed immediately after |**|.)

    The following code does the required initialization. If anything has been specified on the
    command line, then |t_open_in| will return with |last > first|.

    This code has been adapted and we no longer ask for a name. It makes no sense because one needs
    to initialize the primitives and backend anyway and no one is going to do that interactively.
    Of course one can implement a session in \LUA. We keep the \TEX\ trick to push the name into
    the input buffer and then exercise an |\input| which ensures proper housekeeping. There is a
    bit overkill in the next function but for now we keep it (as reference).

    For a while copying the argument to th ebuffer lived in the engine lib but it made no sense
    to duplicate code, so now it's here. Anyway, the following does no longer apply:

    \startquotation
    This is supposed to open the terminal for input, but what we really do is copy command line
    arguments into \TEX's buffer, so it can handle them. If nothing is available, or we've been
    called already (and hence, |argc == 0|), we return with |last = first|.
    \stopquotation

    In \LUAMETATEX\ we don't really have a terminal. In the \LUATEX\ precursor we used to append
    all the remaining arguments but now we just take the first one. If one wants filenames with
    spaces \unknown\ use quotes. Keep in mind that original \TEX\ permits this:

    \starttyping
    tex ... filename \\hbox{!} \\end
    \stoptyping

    But we don't follow that route in the situation where \LUA\ is mostly in charge of passing
    input from files and the console.

    In the end I went for an easier solution: just pass the name to the file reader. But we keep
    this as nostalgic reference to how \TEX\ originally kin dof did these things.

    \starttyping
    int input_file_name_pushed(void)
    {
        const char *ptr = engine_input_filename();
        if (ptr) {
            int len = strlen(ptr);
            fileio_state.io_buffer[fileio_state.io_first] = 0;
            if (len > 0 && room_in_buffer(len + 1)) {
                // We cannot use strcat, because we have multibyte UTF-8 input. Hm, why not.
                fileio_state.io_last= fileio_state.io_first;
                while (*ptr) {
                    fileio_state.io_buffer[fileio_state.io_last++] = (unsigned char) * (ptr++);
                }
                // Backtrack over spaces and newlines.
                for (
                    --fileio_state.io_last;
                    fileio_state.io_last >= fileio_state.io_first && IS_SPC_OR_EOL(fileio_state.io_buffer[fileio_state.io_last]);
                    --fileio_state.io_last
                );
                // Terminate the string.
                fileio_state.io_buffer[++fileio_state.io_last] = 0;
                // One more time, this time converting to \TEX's internal character representation.
                if (fileio_state.io_last > fileio_state.io_first) {
                    input_state.cur_input.loc = fileio_state.io_first;
                    while ((input_state.cur_input.loc < fileio_state.io_last) && (fileio_state.io_buffer[input_state.cur_input.loc] == ' ')) {
                        ++input_state.cur_input.loc;
                    }
                    if (input_state.cur_input.loc < fileio_state.io_last) {
                        input_state.cur_input.limit = fileio_state.io_last;
                        fileio_state.io_first = fileio_state.io_last + 1;
                    }
                    if (input_state.cur_input.loc < input_state.cur_input.limit) {
                        return 1;
                    }
                }
            }
        }
        fileio_state.io_first = 1;
        fileio_state.io_last = 1;
        return 0;
    }
    \stopttyping

    It's this kind of magic that can take lots of time to play with and figure out, also because
    we cannot break expectations too much.

*/

/*tex

    Per June 22 2020 the terminal code is gone. See |texlegacy.c| for the old, already adapted
    long ago, code. It was already shedulded for removal a while. We only keep the update.

*/

void tex_terminal_update(void) /* renamed, else conflict in |lmplib|. */
{
    fflush(stdout);
}

/*tex

    It's time now to fret about file names. Besides the fact that different operating systems treat
    files in different ways, we must cope with the fact that completely different naming conventions
    are used by different groups of people. The following programs show what is required for one
    particular operating system; similar routines for other systems are not difficult to devise.

    \TEX\ assumes that a file name has three parts: the name proper; its \quote {extension}; and a
    \quote {file area} where it is found in an external file system. The extension of an input file
    or a write file is assumed to be |.tex| unless otherwise specified; it is |transcript_extension|
    on the transcript file that records each run of \TEX; it is |.tfm| on the font metric files that
    describe characters in the fonts \TEX\ uses; it is |.dvi| on the output files that specify
    typesetting information; and it is |format_extension| on the format files written by \INITEX\
    to initialize \TEX. The file area can be arbitrary on input files, but files are usually output
    to the user's current area.

    Simple uses of \TEX\ refer only to file names that have no explicit extension or area. For
    example, a person usually says |\input paper| or |\font \tenrm = helvetica| instead of |\input
    {paper.new}| or |\font \tenrm = {test}|. Simple file names are best, because they make the \TEX\
    source files portable; whenever a file name consists entirely of letters and digits, it should be
    treated in the same way by all implementations of \TEX. However, users need the ability to refer
    to other files in their environment, especially when responding to error messages concerning
    unopenable files; therefore we want to let them use the syntax that appears in their favorite
    operating system.

    The following procedures don't allow spaces to be part of file names; but some users seem to like
    names that are spaced-out. System-dependent changes to allow such things should probably be made
    with reluctance, and only when an entire file name that includes spaces is \quote {quoted} somehow.

    Here are the global values that file names will be scanned into.

    \starttyping
    strnumber cur_name;
    strnumber cur_area;
    strnumber cur_ext;
    \stoptyping

    The file names we shall deal with have the following structure: If the name contains |/| or |:|
    (for Amiga only), the file area consists of all characters up to and including the final such
    character; otherwise the file area is null. If the remaining file name contains |.|, the file
    extension consists of all such characters from the last |.| to the end, otherwise the file
    extension is null.

    We can scan such file names easily by using two global variables that keep track of the
    occurrences of area and extension delimiters:

    Input files that can't be found in the user's area may appear in a standard system area called
    |TEX_area|. Font metric files whose areas are not given explicitly are assumed to appear in a
    standard system area called |TEX_font_area|. These system area names will, of course, vary from
    place to place.

    This whole model has been adapted a little but we do keep the |area|, |name|, |ext| distinction
    for now although we don't use the string pool.

*/

static char *tex_aux_pack_file_name(char *s, int l, const char *name, const char *ext)
{
    const char *fn = (char *) s;
    if ((! fn) || (l <= 0)) {
        fn = name;
    }
    if (! fn) {
        return NULL;
    } else if (! ext) {
        return lmt_memory_strdup(fn);
    } else {
        int e = -1;
        for (int i = 0; i < l; i++) {
            if (IS_DIR_SEP(fn[i])) {
                e = -1;
            } else if (fn[i] == '.') {
                e = i;
            }
        }
        if (e >= 0) {
            return lmt_memory_strdup(fn);
        } else {
            char *f = lmt_memory_malloc(strlen(fn) + strlen(ext) + 1);
            if (f) {
                sprintf(f, "%s%s", fn, ext);
            }
            return f;
        }
    }
}

/*tex

    Here is a routine that manufactures the output file names, assuming that |job_name <> 0|. It
    ignores and changes the current settings of |cur_area| and |cur_ext|; |s = transcript_extension|,
    |".dvi"|, or |format_extension|

    The packer does split the basename every time but isn't called that often so we can use it in
    the checker too.

*/

static char *tex_aux_pack_job_name(const char *e, int keeppath, int keepsuffix)
{
    char *n = lmt_fileio_state.job_name;
    int ln = (n) ? (int) strlen(n) : 0;
    if (! ln) {
        tex_fatal_error("bad jobname");
        return NULL;
    } else {
        int le = (e) ? (int) strlen(e) : 0;
        int f = -1; /* first */
        int l = -1; /* last */
        char *fn = NULL;
        int k = 0;
        for (int i = 0; i < ln; i++) {
            if (IS_DIR_SEP(n[i])) {
                f = i;
                l = -1;
            } else if (n[i] == '.') {
                l = i;
            }
        }
        if (keeppath) {
            f = 0;
        } else if (f < 0) {
            f = 0;
        } else {
            f += 1;
        }
        if (keepsuffix || l < 0) {
            l = ln;
        }
        fn = (char*) lmt_memory_malloc((l - f) + le + 2); /* a bit too much */
        if (fn) {
            for (int i = f; i < l; i++) {
                fn[k++] = n[i];
            }
            for (int i = 0; i < le; i++) {
                fn[k++] = e[i];
            }
            fn[k] = 0;
        }
        return fn;
    }
}

/*tex

    The following comment is obsolete but we keep it as reference because it tells some history.

    \startquotation
    Because the format is zipped we read and write dump files through zlib. Earlier versions recast
    |*f| from |FILE *| to |gzFile|, but there is no guarantee that these have the same size, so a
    static variable is needed.

    We no longer do byte-swapping so formats are generated for the system and not shared. It
    actually slowed down loading of the format on the majority of used platforms (intel).

    A \CONTEXT\ format is uncompressed some 16 MB but that used to be over 30MB due to more
    (preallocated) memory usage. A compressed format is 11 MB so the saving is not that much. If
    we were in lua I'd load the whole file in one go and use a fast decompression after which we
    could access the bytes in memory. But it's not worth the trouble.

    Tests has shown that a level 3 compression is the most optimal tradeoff between file size and
    load time.

    So, in principle we can undefine |FMT_COMPRESSION| below and experiment a bit with it. With
    SSD's it makes no dent, but on a network it still might.

    Per end May 2019 the |FMT_COMPRESSION| branch is gone so that we can simplify the opener and
    closer.
    \stopquotation

*/

void tex_check_fmt_name(void)
{
    if (lmt_engine_state.dump_name) {
        char *tmp = lmt_fileio_state.job_name;
        lmt_fileio_state.job_name = lmt_engine_state.dump_name;
        lmt_fileio_state.fmt_name = tex_aux_pack_job_name(format_extension, 1, 0);
        lmt_fileio_state.job_name = tmp;
    } else if (lmt_main_state.run_state != initializing_state) {
        /*tex For |dump_name| to be NULL is a bug. */
        tex_emergency_message("startup error", "no format file given, quitting");
        tex_emergency_exit();
    }
}

void tex_check_job_name(char * fn)
{
    if (! lmt_fileio_state.job_name) {
        if (lmt_engine_state.startup_jobname) {
            lmt_fileio_state.job_name = lmt_engine_state.startup_jobname; /* not freed here */
            lmt_fileio_state.job_name = tex_aux_pack_job_name(NULL, 0, 0);
        } else if (fn) {
            lmt_fileio_state.job_name = fn;
            lmt_fileio_state.job_name = tex_aux_pack_job_name(NULL, 0, 0); /* not freed here */
        } else {
            tex_emergency_message("startup warning", "using fallback jobname 'texput', continuing");
            lmt_fileio_state.job_name = lmt_memory_strdup("texput");
        }
    }
    if (! lmt_fileio_state.log_name) {
        lmt_fileio_state.log_name = tex_aux_pack_job_name(transcript_extension, 0, 1);
    }
    if (! lmt_fileio_state.fmt_name) {
        lmt_fileio_state.fmt_name = tex_aux_pack_job_name(format_extension, 0, 1);
    }
}

/*tex

    A messier routine is also needed, since format file names must be scanned before \TEX's
    string mechanism has been initialized. We shall use the global variable |TEX_format_default|
    to supply the text for default system areas and extensions related to format files.

    Under \UNIX\ we don't give the area part, instead depending on the path searching that will
    happen during file opening. Also, the length will be set in the main program.

    \starttyping
    char *TEX_format_default;
    \stoptyping

    This part of the program becomes active when a \quote {virgin} \TEX\ is trying to get going,
    just after the preliminary initialization, or when the user is substituting another format file
    by typing |&| after the initial |**| prompt. The buffer contains the first line of input in
    |buffer[loc .. (last - 1)]|, where |loc < last| and |buffer[loc] <> " "|.

*/

dumpstream tex_open_fmt_file(int writemode)
{
    dumpstream f = NULL;
    if (! lmt_fileio_state.fmt_name) {
        /* this can't happen */
        tex_emergency_message("startup error", "no format output file '%s' given, quitting", emergency_fmt_name);
        tex_emergency_exit();
    } else if (writemode) {
        f = aux_utf8_fopen(lmt_fileio_state.fmt_name, FOPEN_WBIN_MODE);
        if (! f) {
            tex_emergency_message("startup error", "invalid format output file '%s' given, quitting", lmt_fileio_state.fmt_name);
            tex_emergency_exit();
        }
    } else {
        int callbackid = lmt_callback_defined(find_format_file_callback);
        if (callbackid > 0) {
            char *fnam = NULL;
            int test = lmt_run_callback(lmt_lua_state.lua_instance, callbackid, "S->R", lmt_fileio_state.fmt_name, &fnam);
            if (test && fnam && strlen(fnam) > 0) {
                lmt_memory_free(lmt_fileio_state.fmt_name);
                lmt_fileio_state.fmt_name = fnam;
            } else {
                lmt_memory_free(fnam);
            }
            f = aux_utf8_fopen(lmt_fileio_state.fmt_name, FOPEN_RBIN_MODE);
            if (! f) {
                tex_emergency_message("startup error", "invalid format input file '%s' given, quitting", emergency_fmt_name);
                tex_emergency_exit();
            }
        } else {
            /*tex For the moment we make this mandate! */
            tex_emergency_message("startup error", "missing find_format_file callback");
            tex_emergency_exit();
        }
    }
    return f;
}

void tex_close_fmt_file(dumpstream f)
{
    if (f) {
        fclose(f);
    }
}

/*tex

    The variable |name_in_progress| is used to prevent recursive use of |scan_file_name|, since the
    |begin_name| and other procedures communicate via global variables. Recursion would arise only
    by devious tricks like |\input \input f|; such attempts at sabotage must be thwarted.
    Furthermore, |name_in_progress| prevents |\input| from being initiated when a font size
    specification is being scanned.

    Another variable, |job_name|, contains the file name that was first |\input| by the user. This
    name is extended by |transcript_extension| and |.dvi| and |format_extension| in the names of
    \TEX's output files. The fact if the transcript file been opened is registered in
    |log_opened_global|.

    Initially |job_name = 0|; it becomes nonzero as soon as the true name is known. We have
    |job_name = 0| if and only if the |log| file has not been opened, except of course for a short
    time just after |job_name| has become nonzero.

    The full name of the log file is stored in |log_name|. The |open_log_file| routine is used to
    open the transcript file and to help it catch up to what has previously been printed on the
    terminal.

*/

void tex_open_log_file(void)
{
    if (! lmt_fileio_state.log_opened) {
        int callback_id = lmt_callback_defined(find_log_file_callback);
        if (callback_id > 0) {
            char *filename = NULL;
            int okay = 0;
            tex_check_job_name(NULL);
            okay = lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "S->R", lmt_fileio_state.log_name, &filename);
            if (okay && filename && (strlen(filename) > 0)) {
                lmt_memory_free(lmt_fileio_state.log_name);
                lmt_fileio_state.log_name = filename;
            } else {
                lmt_memory_free(filename);
            }
        } else {
            /*tex For the moment we make this mandate! */
            tex_emergency_message("startup error", "missing find_log_file callback");
            tex_emergency_exit();
        }
        if (tex_aux_open_outfile(&lmt_print_state.logfile, lmt_fileio_state.log_name, FOPEN_W_MODE)) {
            /*tex The previous |selector| setting is saved:*/
            int saved_selector = lmt_print_state.selector;
            lmt_print_state.selector = logfile_selector_code;
            lmt_fileio_state.log_opened = 1;
            /*tex Again we resolve a callback id: */
            callback_id = lmt_callback_defined(start_run_callback);
            /*tex There is no need to free |fn|! */
            if (callback_id == 0) {
                tex_print_banner();
                /*tex Print the banner line, including current date and time. */
                tex_print_log_banner();
                /*tex Make sure bottom level is in memory. */
                lmt_input_state.input_stack[lmt_input_state.input_stack_data.ptr] = lmt_input_state.cur_input;
                /*tex We don't have a first line so that code is gone. */
                tex_print_ln();
            } else if (callback_id > 0) {
                lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "->");
            } else {
                tex_print_banner();
            }
            /*tex should be done always */
            if (lmt_print_state.loggable_info) {
                fprintf(lmt_print_state.logfile, "%s\n", lmt_print_state.loggable_info);
                lmt_memory_free(lmt_print_state.loggable_info);
                lmt_print_state.loggable_info = NULL;
            }
            switch (saved_selector) {
                case no_print_selector_code : lmt_print_state.selector = logfile_selector_code; break;
                case terminal_selector_code : lmt_print_state.selector = terminal_and_logfile_selector_code; break;
                default                     : lmt_print_state.selector = saved_selector; break;
            }
        } else {
            tex_emergency_message("startup error", "log file '%s' cannot be opened, quitting", emergency_log_name);
            tex_emergency_exit();
        }
    }
}

void tex_close_log_file(void)
{
    fclose(lmt_print_state.logfile);
    lmt_fileio_state.log_opened = 0;
}

/*tex

    Let's turn now to the procedure that is used to initiate file reading when an |\input| command
    is being processed. This function is used with |\\input| as well as in the start up.

*/

void tex_start_input(char *fn)
{
    /*tex Set up |cur_file| and new level of input. */
    tex_begin_file_reading();
    if (! tex_lua_a_open_in(fn)) {
        /*tex
            Normally this is catched earler, as we have lookup callbacks but the first file, the
            one passed on the command line can fall though this checking.
        */
        tex_end_file_reading();
        tex_emergency_message("runtime error", "input file '%s' is not found, quitting", fn);
        tex_emergency_exit();
    }
    lmt_input_state.in_stack[lmt_input_state.in_stack_data.ptr].full_source_filename = fn;
    lmt_input_state.cur_input.name = io_file_input_code;
    /*tex
        |open_log_file| doesn't |show_context|, so |limit| and |loc| needn't be set to meaningful
        values yet.
    */
    tex_report_start_file((unsigned char *) fn);
    ++lmt_input_state.open_files;
    tex_terminal_update();
    lmt_input_state.cur_input.state = new_line_state;
    /*tex

        Read the first line of the new file. Here we have to remember to tell the |lua_input_ln|
        routine not to start with a |get|. If the file is empty, it is considered to contain a
        single blank line.

    */
    lmt_input_state.input_line = 1;
    tex_lua_input_ln();
    lmt_input_state.cur_input.limit = lmt_fileio_state.io_last; /*tex Was |firm_up_the_line();|. */
    if (end_line_char_inactive) {
        --lmt_input_state.cur_input.limit;
    } else {
        lmt_fileio_state.io_buffer[lmt_input_state.cur_input.limit] = (unsigned char) end_line_char_par;
    }
    lmt_fileio_state.io_first = lmt_input_state.cur_input.limit + 1;
    lmt_input_state.cur_input.loc = lmt_input_state.cur_input.start;
}

/*tex

    In order to isolate the system-dependent aspects of file names, the system-independent parts of
    \TEX\ are expressed in terms of three system-dependent procedures called |begin_name|,
    |more_name|, and |end_name|. In essence, if the user-specified characters of the file name are
    |c_1|\unknown|c_n|, the system-independent driver program does the operations

    \starttyping
    |begin_name|;
    |more_name|(c_1);
    .....
    |more_name|(c_n);
    |end_name|
    \stoptyping

    These three procedures communicate with each other via global variables. Afterwards the file
    name will appear in the string pool as three strings called |cur_name|, |cur_area|, and
    |cur_ext|; the latter two are null (i.e., |""|), unless they were explicitly specified by the
    user.

    Actually the situation is slightly more complicated, because \TEX\ needs to know when the file
    name ends. The |more_name| routine is a function (with side effects) that returns |true| on the
    calls |more_name (c_1)|, \dots, |more_name (c_{n - 1})|. The final call |more_name(c_n)| returns
    |false|; or, it returns |true| and the token following |c_n| is something like |\hbox| (i.e.,
    not a character). In other words, |more_name| is supposed to return |true| unless it is sure that
    the file name has been completely scanned; and |end_name| is supposed to be able to finish the
    assembly of |cur_name|, |cur_area|, and |cur_ext| regardless of whether |more_name (c_n)|
    returned |true| or |false|.

    This code has been adapted and the string pool is no longer used. We also don't ask for another
    name on the console.

*/

/*tex

    And here's the second. The string pool might change as the file name is being scanned, since a
    new |\csname| might be entered; therefore we keep |area_delimiter| and |ext_delimiter| relative
    to the beginning of the current string, instead of assigning an absolute address like |pool_ptr|
    to them.

    Now let's consider the \quote {driver} routines by which \TEX\ deals with file names in a
    system-independent manner. First comes a procedure that looks for a file name in the input by
    calling |get_x_token| for the information.

*/

char *tex_read_file_name(int optionalequal, const char * name, const char* ext)
{
    char *fn = NULL;
    int l = 0;
    char *s = NULL;
    halfword result;
    if (optionalequal) {
        tex_scan_optional_equals();
    }
    do {
        tex_get_x_token();
    } while (cur_cmd == spacer_cmd || cur_cmd == relax_cmd);
    if (cur_cmd == left_brace_cmd) {
        result = tex_scan_toks_expand(1, NULL, 0);
    } else {
        int quote = 0;
        halfword p = get_reference_token();
        result = p;
        while (1) {
            switch (cur_cmd) {
                case escape_cmd:
                case left_brace_cmd:
                case right_brace_cmd:
                case math_shift_cmd:
                case alignment_tab_cmd:
                case parameter_cmd:
                case superscript_cmd:
                case subscript_cmd:
                case letter_cmd:
                case other_char_cmd:
                    if (cur_chr == '"') {
                        if (quote) {
                            goto DONE;
                        } else {
                            quote = 1;
                        }
                    } else {
                         p = tex_store_new_token(p, cur_tok);
                    }
                    break;
                case spacer_cmd:
                case end_line_cmd:
                    if (quote) {
                        p = tex_store_new_token(p, token_val(spacer_cmd, ' '));
                    } else {
                        goto DONE;
                    }
                case ignore_cmd:
                    break;
                default:
                    tex_back_input(cur_tok);
                    goto DONE;
            }
            tex_get_x_token();
        }
    }
  DONE:
    s = tex_tokenlist_to_tstring(result, 1, &l, 0, 0, 0, 1);
    fn = s ? tex_aux_pack_file_name(s, l, name, ext) : NULL;
    return fn;
}

void tex_print_file_name(unsigned char *name)
{
    int must_quote = 0;
    if (name) {
        unsigned char *j = name;
        while (*j) {
            if (*j == ' ') {
                must_quote = 1;
                break;
            } else {
                j++;
            }
        }
    }
    if (must_quote) {
        /* initial quote */
        tex_print_char('"');
    }
    if (name) {
        unsigned char *j = name;
        while (*j) {
            if (*j == '"') {
                /* skip embedded quote, maybe escape */
            } else {
                tex_print_char(*j);
            }
            j++;
        }
    }
    if (must_quote) {
        /* final quote */
        tex_print_char('"');
    }
}

void tex_report_start_file(unsigned char *name)
{
    int callback_id = lmt_callback_defined(start_file_callback);
    if (callback_id) {
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "S->", name);
    } else {
        tex_print_char('(');
        tex_print_file_name((unsigned char *) name);
    }
}

void tex_report_stop_file(void)
{
    int callback_id = lmt_callback_defined(stop_file_callback);
    if (callback_id) {
        lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "->");
    } else {
        tex_print_char(')');
    }
}
