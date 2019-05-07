/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

fileio_state_info fileio_state = { NULL, { 0 }, NULL, 0, 0, 0, NULL, NULL, NULL, 0, 0 };

static int open_outfile(FILE ** f, const char *name, const char *mode)
{
    FILE *res = fopen(name, mode);
    if (res != NULL) {
        *f = res;
        return 1;
    }
    return 0;
}

/*tex

    Read a line of input as efficiently as possible while still looking like
    Pascal. We set |last| to |first| and return |false| if we get to eof.
    Otherwise, we return |true| and set |last = first + lengt (line except
    trailing whitespace)|.

*/

static int the_input_line(FILE * f)
{
    int i = EOF;
    /*tex Recognize either LF or CR as a line terminator. */
    iolast = iofirst;
    while (iolast < main_state.buf_size && (i = getc(f)) != EOF && i != '\n' && i != '\r') {
        iobuffer[iolast++] = (unsigned char) i;
    }
    if (i == EOF && errno != EINTR && iolast == iofirst) {
        return 0;
    } else {
        /*tex We didn't get the whole line because our buffer was too small. */
        if (i != EOF && i != '\n' && i != '\r') {
            formatted_error("system", "the buffer size (%u) is too small for the input line", (unsigned) main_state.buf_size);
            return 0;
        } else {
            iobuffer[iolast] = ' ';
            if (iolast >= max_buf_stack) {
                max_buf_stack = iolast;
            }
            /*tex If next char is LF of a CRLF, read it. */
            if (i == '\r') {
                while ((i = getc(f)) == EOF && errno == EINTR);
                if (i != '\n')
                    ungetc(i, f);
            }
            /*tex
                Trim trailing space character (but not, e.g., tabs). We can't have line
                terminators because we stopped reading at the first \r or \n. TeX's rule
                is to strip only trailing spaces (and eols). David Fuchs mentions that
                this stripping was done to ensure portability of TeX documents given the
                padding with spaces on fixed-record "lines" on some systems of the time,
                e.g., IBM VM/CMS and OS/360.
            */
            while (iolast > iofirst && iobuffer[iolast - 1] == ' ') {
                --iolast;
            }
            /*tex Don't bother using xord if we don't need to. */
            return 1;
        }
    }
}

/*tex

    We conform to the way Web2c does handle trailing tabs and spaces. This decade
    old behaviour was changed in September 2017 and can introduce compatibility
    issues in existing workflows. Because we don't want too many differences with
    upstream \TEX live we just follow up on that patch and it's up to macro
    packages to deal with possible issues (which can be done via the usual
    callbacks. One can wonder why we then still prune spaces but we leave that to
    the reader.

    Patched original comment:

    Make last be one past the last non-space character in `buffer', ignoring line
    terminators (but not, e.g., tabs). This is because we are supposed to treat
    this like a line of TeX input. Although there are pathological cases (SPC CR
    SPC CR) where this differs from input_line below, and from previous behavior
    of removing all whitespace, the simplicity of removing all trailing line
    terminators seems more in keeping with actual command line processing.

    The IS_SPC_OR_EOL macro deals with space characters (SPACE 32) and newlines
    (CR and LF) and no longer looks at tabs (TAB 9).

*/

static void t_open_in(void)
{
    /*tex n case there are no arguments. */
    iobuffer[iofirst] = 0;
    /*tex We outsource copying to a helper elsewhere. */
    command_line_to_input(iobuffer,iofirst);
    /*tex Find the end of the buffer looking at spaces and newlines. */
    for (iolast = iofirst; iobuffer[iolast]; ++iolast);
#define IS_SPC_OR_EOL(c) ((c) == ' ' || (c) == '\r' || (c) == '\n')
    for (--iolast; iolast >= iofirst && IS_SPC_OR_EOL (iobuffer[iolast]); --iolast);
    /*tex
        One more time, this time converting to \TEX's internal character
        representation.
    */
    iolast++;
}

/*tex

    When input files are opened via a callback, they will also be read using
    callbacks. for that purpose, the |open_read_file_callback| returns an integer
    to uniquely identify a callback table. This id replaces the file point |f| in
    this case, because the input does not have to be a file in the traditional
    sense.

    Signalling this fact is achieved by having two arrays of integers.

    \starttyping
    int *input_file_callback_id;
    int read_file_callback_id[17];
    \stoptyping

    Find an |\input| or |\read| file. |n| differentiates between those case.

*/

static char *luatex_find_data_file(const char *s)
{
    char *ftemp = NULL;
    int callback_id = callback_defined(find_data_file_callback);
    if (callback_id > 0) {
        (void) run_callback(callback_id, "S->R", s, &ftemp);
    } else {
        normal_error("system","missing find_data_file callback");
    }
    return ftemp;
}

int lua_a_open_in(FILE ** f, char *fn, int n)
{
    char *fnam;
    if (n == 0) {
        input_file_callback_id[iindex] = 0;
    } else {
        read_file_callback_id[n] = 0;
    }
    fnam = luatex_find_data_file(fn);
    if (fnam == NULL) {
        return 0;
    } else {
        int callback_id = callback_defined(open_data_file_callback);
        if (callback_id > 0) {
            int k = run_and_save_callback(callback_id, "S->", fnam);
            if (k > 0) {
                if (n == 0) {
                    input_file_callback_id[iindex] = k;
                } else {
                    read_file_callback_id[n] = k;
                }
                return 1;
            } else {
                /*tex read failed */
                return 0;
            }
        } else {
            /* untested */
            *f = fopen(fnam, "rb");
            /*
                normal_error("system","missing open_data_file callback");
                file_ok = 0;
            */
            return (*f != NULL);
        }
    }
}

int lua_a_open_out(FILE ** f, char *fn, int n)
{
    int callback_id = callback_defined(find_write_file_callback);
    if (callback_id > 0) {
        str_number fnam = 0;
        int test = run_callback(callback_id, "dS->s", n, fn, &fnam);
        if ((test) && (fnam != 0) && (str_length(fnam) > 0)) {
            return open_outfile(f, fn, FOPEN_W_MODE);
        }
    } else {
        normal_error("system","missing find_write_file callback");
    }
    return 0;
}

void lua_a_close_in(FILE * f, int n)
{
    int callback_id;
    if (n == 0) {
        callback_id = input_file_callback_id[iindex];
    } else {
        callback_id = read_file_callback_id[n];
    }
    if (callback_id > 0) {
        run_saved_callback(callback_id, lua_key_index(close), "->");
        destroy_saved_callback(callback_id);
        if (n == 0)
            input_file_callback_id[iindex] = 0;
        else
            read_file_callback_id[n] = 0;
    } else {
        fclose(f);
    }
}

void lua_a_close_out(FILE * f)
{
    fclose(f);
}

/*tex

    Binary input and output are done with \CCODE's ordinary procedures, so we
    don't have to make any other special arrangements for binary \IO. Text output
    is also easy to do with standard routines. The treatment of text input is
    more difficult, however, because of the necessary translation to |unsigned char|
    values. \TEX's conventions should be efficient, and they should blend nicely
    with the user's operating environment.

    Input from text files is read one line at a time, using a routine called
    |lua_input_ln|. This function is defined in terms of global variables called
    |buffer|, |first|, and |last| that will be described in detail later; for
    now, it suffices for us to know that |buffer| is an array of |unsigned char|
    values, and that |first| and |last| are indices into this array representing
    the beginning and ending of a line of text.

    The lines of characters being read: |buffer|, the first unused position in
    |first|, the end of the line just input |last|, the largest index used in
    |buffer|: |max_buf_stack|.

    The |lua_input_ln| function brings the next line of input from the specified
    file into available positions of the buffer array and returns the value
    |true|, unless the file has already been entirely read, in which case it
    returns |false| and sets |last:=first|. In general, the |unsigned char|
    numbers that represent the next line of the file are input into
    |buffer[first]|, |buffer[first + 1]|, \dots, |buffer[last - 1]|; and the
    global variable |last| is set equal to |first| plus the length of the line.
    Trailing blanks are removed from the line; thus, either |last=first| (in
    which case the line was entirely blank) or |buffer[last-1] <> " "|.

    An overflow error is given, however, if the normal actions of |lua_input_ln|
    would make |last >= buf_size|; this is done so that other parts of \TEX\ can
    safely look at the contents of |buffer[last+1]| without overstepping the
    bounds of the |buffer| array. Upon entry to |lua_input_ln|, the condition
    |first < buf_size| will always hold, so that there is always room for an
    \quote {empty} line.

    The variable |max_buf_stack|, which is used to keep track of how large the
    |buf_size| parameter must be to accommodate the present job, is also kept up
    to date by |lua_input_ln|.

    If the |bypass_eoln| parameter is |true|, |lua_input_ln| will do a |get|
    before looking at the first character of the line; this skips over an |eoln|
    that was in |f^|. The procedure does not do a |get| when it reaches the end
    of the line; therefore it can be used to acquire input from the user's
    terminal as well as from ordinary text files.

    Since the inner loop of |lua_input_ln| is part of \TEX's \quote {inner loop}
    --- each character of input comes in at this place --- it is wise to reduce
    system overhead by making use of special routines that read in an entire
    array of characters at once, if such routines are available.

*/

int lua_input_ln(FILE * f, int n) /*tex |bypass_eoln| was not used */
{
    int callback_id;
    if (n == 0) {
        callback_id = input_file_callback_id[iindex];
    } else {
        callback_id = read_file_callback_id[n];
    }
    if (callback_id > 0) {
        int last_ptr = 0;
        iolast = iofirst;
        last_ptr = run_saved_callback_line(callback_id, iofirst);
        if (last_ptr < 0) {
            return 0;
        } else if (last_ptr > 0) {
            iolast = last_ptr;
            if (iolast > max_buf_stack) {
                max_buf_stack = iolast;
            }
        }
        return 1;
    } else {
        return the_input_line(f) ? 1 : 0;
    }
}

/*tex

    We need a special routine to read the first line of \TEX\ input from the
    user's terminal. This line is different because it is read before we have
    opened the transcript file; there is sort of a \quote {chicken and egg}
    problem here. If the user types |\input paper| on the first line, or if some
    macro invoked by that line does such an |\input|, the transcript file will be
    named |paper.log|; but if no |\input| commands are performed during the first
    line of terminal input, the transcript file will acquire its default name
    |texput.log|. (The transcript file will not contain error messages generated
    by the first line before the first |\input| command.)

    The first line is special also because it may be read before \TEX\ has input
    a format file. In such cases, normal error messages cannot yet be given. The
    following code uses concepts that will be explained later.

    Different systems have different ways to get started. But regardless of what
    conventions are adopted, the routine that initializes the terminal should
    satisfy the following specifications:

    \startitemize[n]

        \startitem
            It should open file |term_in| for input from the terminal. (The file
            |term_out| will already be open for output to the terminal.)
        \stopitem

        \startitem
            If the user has given a command line, this line should be considered
            the first line of terminal input. Otherwise the user should be
            prompted with |**|, and the first line of input should be whatever is
            typed in response.
        \stopitem

        \startitem
            The first line of input, which might or might not be a command line,
            should appear in locations |first| to |last-1| of the |buffer| array.
        \stopitem

        \startitem
            The global variable |loc| should be set so that the character to be
            read next by \TeX\ is in |buffer[loc]|. This character should not be
            blank, and we should have |loc<last|.
        \stopitem

    \stopitemize

    It may be necessary to prompt the user several times before a non-blank line
    comes in. The prompt is |**| instead of the later |*| because the meaning is
    slightly different: |\input| need not be typed immediately after |**|.)

    The following code does the required initialization. If anything has been
    specified on the command line, then |t_open_in| will return with |last >
    first|.

    This code has been adapted and we no longer ask for a name. It makes no sense
    because one needs to initialize the primitives and backend anyway and no one
    is going to do that interactively. Of course one can implement a session in
    \LUA.

*/

int init_terminal(void)
{
    /*tex This gets the terminal input started. The name of the input fule is in the buffer! */
    t_open_in();
    if (iolast > iofirst) {
        iloc = iofirst;
        while ((iloc < iolast) && (iobuffer[iloc] == ' ')) {
            incr(iloc);
        }
        if (iloc < iolast) {
            return 1;
        }
    }
    return 0;
//     while (1) {
//         wake_up_terminal();
//         fputs("**", term_out);
//         update_terminal();
//         if (!the_input_line(term_in)) {
//             /*tex This shouldn't happen. */
//             fputs("\n! End of file on the terminal... why?\n", term_out);
//             return 0;
//         } else {
//             iloc = iofirst;
//             while ((iloc < iolast) && (iobuffer[iloc] == ' ')) {
//                 incr(iloc);
//             }
//             /*tex Return unless the line was all blank. */
//             if (iloc < iolast) {
//                 return 1;
//             } else {
//                 fputs("Please type the name of your input file.\n", term_out);
//             }
//         }
//     }
}


/*tex

    Here is a procedure that asks the user to type a line of input, assuming that
    the |selector| setting is either |term_only| or |term_and_log|. The input is
    placed into locations |first| through |last-1| of the |buffer| array, and
    echoed on the transcript file if appropriate.

    This will become a callback!

*/

void term_input(void)
{
    int callback_id = callback_defined(terminal_input_callback);
    if (callback_id > 0) {
        (void) run_callback(callback_id, "->l",(iobuffer + iofirst));
    } else {
        /*tex Now the user sees the prompt for sure: */
        update_terminal();
        if (!the_input_line(term_in)) {
            fatal_error("End of file on the terminal!");
        } else {
            /*tex The user's line ended with \.{<return>}: */
            term_offset = 0;
            /*tex Prepare to echo the input. */
            decr(selector);
            if (iolast != iofirst) {
                /*tex Index into |buffer|: */
                int k;
                for (k = iofirst; k <= iolast - 1; k++)
                    print_char(iobuffer[k]);
            }
            print_ln();
            /*tex Restore previous status. */
            incr(selector);
        }
    }
}

/*tex

    It's time now to fret about file names. Besides the fact that different
    operating systems treat files in different ways, we must cope with the fact
    that completely different naming conventions are used by different groups of
    people. The following programs show what is required for one particular
    operating system; similar routines for other systems are not difficult to
    devise.

    \TEX\ assumes that a file name has three parts: the name proper; its \quote
    {extension}; and a \quote {file area} where it is found in an external file
    system. The extension of an input file or a write file is assumed to be
    |.tex| unless otherwise specified; it is |transcript_extension| on the
    transcript file that records each run of \TEX; it is |.tfm| on the font
    metric files that describe characters in the fonts \TEX\ uses; it is |.dvi|
    on the output files that specify typesetting information; and it is
    |format_extension| on the format files written by \INITEX\ to initialize
    \TEX. The file area can be arbitrary on input files, but files are usually
    output to the user's current area.

    Simple uses of \TEX\ refer only to file names that have no explicit extension
    or area. For example, a person usually says |\input paper| or |\font\tenrm =
    helvetica| instead of |\input {paper.new}| or |\font\tenrm = {test}|. Simple
    file names are best, because they make the \TEX\ source files portable;
    whenever a file name consists entirely of letters and digits, it should be
    treated in the same way by all implementations of \TEX. However, users need
    the ability to refer to other files in their environment, especially when
    responding to error messages concerning unopenable files; therefore we want
    to let them use the syntax that appears in their favorite operating system.

    The following procedures don't allow spaces to be part of file names; but
    some users seem to like names that are spaced-out. System-dependent changes
    to allow such things should probably be made with reluctance, and only when
    an entire file name that includes spaces is \quote {quoted} somehow.

    Here are the global values that file names will be scanned into.

    \starttyping
    str_number cur_name;
    str_number cur_area;
    str_number cur_ext;
    \stoptyping

    The file names we shall deal with have the following structure: If the name
    contains |/| or |:| (for Amiga only), the file area consists of all
    characters up to and including the final such character; otherwise the file
    area is null. If the remaining file name contains |.|, the file extension
    consists of all such characters from the last |.| to the end, otherwise the
    file extension is null.

    We can scan such file names easily by using two global variables that keep
    track of the occurrences of area and extension delimiters:

    Input files that can't be found in the user's area may appear in a standard
    system area called |TEX_area|. Font metric files whose areas are not given
    explicitly are assumed to appear in a standard system area called
    |TEX_font_area|. These system area names will, of course, vary from place
    to place.

    This whole model has been adapted a little but we do keep the |area|, |name|,
    |ext| distinction for now although we don't use the string pool.

*/

static char *pack_file_name(char *s, int l, const char *name, const char *ext)
{
    const char *fn = (char *) s;
    if (fn == NULL || l == 0) {
        fn = name;
    }
    if (fn == NULL) {
        return NULL;
    } else if (ext == NULL) {
        return strdup(fn);
    } else {
        int e = -1;
        int i = 0;
        for (; i < l; i++) {
            if (IS_DIR_SEP(fn[i])) {
                e = -1;
            } else if (s[i] == '.') {
                e = i;
            }
        }
        if (e >= 0) {
            return strdup(fn);
        } else {
            char *f = malloc(strlen(fn) + strlen(ext) + 1);
            sprintf(f,"%s%s",fn,ext);
            return f;
        }
    }
}

/*tex

    Here is a routine that manufactures the output file names, assuming that
    |job_name <> 0|. It ignores and changes the current settings of |cur_area| and
    |cur_ext|; |s = transcript_extension|, |".dvi"|, or |format_extension|
*/

/*tex

    The packer does split the basename every time but isn't called that
    often so we can use it in the checker too.

*/

static char *pack_job_name(const char *e, int keeppath)
{
    char *n = fileio_state.job_name;
    int ln = (n == NULL) ? 0 : strlen(n);
    int le = (e == NULL) ? 0 : strlen(e);
    if (!ln) {
        fatal_error("bad jobname");
        return NULL;
    } else {
        char *fn = NULL;
        int f = -1; /* first */
        int l = -1; /* last */
        int i = 0;
        int k = 0;
        for (; i < ln; i++) {
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
        if (l < 0) {
            l = ln;
        }
        fn = (char*) malloc((l -f) + le + 2); /* a bit too much */
        for (i=f;i<l;i++) {
            fn[k++] = n[i];
        }
        for (i=0;i<le;i++) {
            fn[k++] = e[i];
        }
        fn[k] = 0;
        return fn;
    }
}

void check_fmt_name(void)
{
    if (engine_state.dump_name != NULL) {
        char * tmp = fileio_state.job_name;
        fileio_state.job_name = engine_state.dump_name;
        fileio_state.fmt_name = pack_job_name(format_extension,1);
        fileio_state.job_name = tmp;
    } else if (!main_state.ini_version) {
        /*tex For |dump_name| to be NULL is a bug. */
        emergency_message("startup error","no format file given, quitting");
        exit(EXIT_FAILURE);
    }
}


static void check_job_name(char * fn)
{
    if (fileio_state.job_name == NULL) {
        if (engine_state.startup_jobname != NULL) {
            fileio_state.job_name = engine_state.startup_jobname; /* not freed here */
            fileio_state.job_name = pack_job_name(NULL,0);
        } else if (fn != NULL) {
            fileio_state.job_name = fn;
            fileio_state.job_name = pack_job_name(NULL,0); /* not freed here */
        } else {
            emergency_message("startup warning","using fallback jobname 'texput', continuing");
            fileio_state.job_name = strdup("texput");
        }
    }
    if (fileio_state.log_name == NULL) {
        fileio_state.log_name = pack_job_name(transcript_extension,0);
    }
    if (fileio_state.fmt_name == NULL) {
        fileio_state.fmt_name = pack_job_name(format_extension,0);
    }
}

/*tex

    A messier routine is also needed, since format file names must be scanned
    before \TEX's string mechanism has been initialized. We shall use the global
    variable |TEX_format_default| to supply the text for default system areas and
    extensions related to format files.

    Under \UNIX\ we don't give the area part, instead depending on the path
    searching that will happen during file opening. Also, the length will be set
    in the main program.

    \starttyping
    char *TEX_format_default;
    \stoptyping

    This part of the program becomes active when a \quote {virgin} \TEX\ is
    trying to get going, just after the preliminary initialization, or when the
    user is substituting another format file by typing |&| after the initial
    |**| prompt. The buffer contains the first line of input in |buffer[loc ..
    (last - 1)]|, where |loc < last| and |buffer[loc] <> " "|.

*/

int open_fmt_file(void)
{
    if (!zopen_fmt_input(&dump_state.fmt_file)) {
        emergency_message("startup error","invalid format file '%s' given, quitting",fileio_state.fmt_name);
        exit(EXIT_FAILURE);
        return 0;
    } else {
        return 1;
    }
}

void close_fmt_file(void)
{
    zclose_fmt(dump_state.fmt_file);
}

/*tex

    The variable |name_in_progress| is used to prevent recursive use of
    |scan_file_name|, since the |begin_name| and other procedures communicate via
    global variables. Recursion would arise only by devious tricks like
    |\input\input f|; such attempts at sabotage must be thwarted. Furthermore,
    |name_in_progress| prevents |\input| from being initiated when a font size
    specification is being scanned.

    Another variable, |job_name|, contains the file name that was first |\input|
    by the user. This name is extended by |transcript_extension| and |.dvi| and
    |format_extension| in the names of \TEX's output files. The fact if the
    transcript file been opened is registered in |log_opened_global|.

    Initially |job_name = 0|; it becomes nonzero as soon as the true name is known.
    We have |job_name = 0| if and only if the |log| file has not been opened,
    except of course for a short time just after |job_name| has become nonzero.

    The full name of the log file si stored in |log_name|. The
    |open_log_file| routine is used to open the transcript file and to help it
    catch up to what has previously been printed on the terminal.

*/

void open_log_file(void)
{
    if (! fileio_state.log_opened) {
        /*tex previous |selector| setting */
        int old_setting = selector;
        selector = term_only;
        check_job_name(NULL);
        if (!lua_a_open_out(&log_file, fileio_state.log_name, 0)) {
            emergency_message("startup error","log file '%s' cannot be opened, quitting",fileio_state.log_name);
            exit(EXIT_FAILURE);
        } else {
            /*tex There is no need to free |fn|! */
            selector = log_only;
            fileio_state.log_opened = 1;
            if (callback_defined(start_run_callback) == 0) {
                /*tex index into |buffer| */
                int k;
                /*tex end of first input line */
                int l;
                /*tex Print the banner line, including current date and time. */
                log_banner();
                /*tex Make sure bottom level is in memory. */
                input_stack[input_ptr] = cur_input;
                tprint_nl("**");
                /*tex The last position of first line. */
                l = input_stack[0].limit_field;
                if (iobuffer[l] == end_line_char_par) {
                    /*tex maybe also handle multichar endlinechar */
                    decr(l);
                }
                for (k = 1; k <= l; k++) {
                    print_char(iobuffer[k]);
                }
                /*tex now the transcript file contains the first line of input */
                print_ln();
            }
            /*tex should be done always */
            flush_loggable_info();
            /*tex should be done always */
            selector = old_setting + 2;
        }
    }
}

void close_log_file(void)
{
    lua_a_close_out(log_file);
    fileio_state.log_opened = 0;
}

/*tex

    Let's turn now to the procedure that is used to initiate file reading when an
    |\input| command is being processed.

*/

void start_input(void)
{
    str_number temp_str;
    char *fn = read_file_name(0,NULL,texinput_extension);
    while (1) {
        /*tex Set up |cur_file| and new level of input. */
        begin_file_reading();
        if (lua_a_open_in(&cur_file, fn, 0)) {
            break;
        } else {
            /*tex Remove the level that didn't work. */
            end_file_reading();
            emergency_message("runtime error","input file '%s' is not found, quitting",fn);
            exit(EXIT_FAILURE);
        }
    }
    /* a bit messy as we also have fn ... some day ... */
    iname = maketexstring(fn);
    source_filename_stack[in_open] = iname;
    full_source_filename_stack[in_open] = fn;
    /*tex We can try to conserve string pool space now. */
    temp_str = search_string(iname);
    if (temp_str > 0) {
        flush_str(iname);
        iname = temp_str;
    }
    check_job_name(fn);
    open_log_file();
    /*tex

        |open_log_file| doesn't |show_context|, so |limit| and |loc| needn't be
        set to meaningful values yet.

    */
    report_start_file(fn);
    free(fn);
    incr(open_parens);
    update_terminal();
    istate = new_line;
    /*tex

        Read the first line of the new file. Here we have to remember to tell the
        |lua_input_ln| routine not to start with a |get|. If the file is empty,
        it is considered to contain a single blank line.

    */
    input_line = 1;
    lua_input_ln(cur_file, 0);
    firm_up_the_line();
    if (end_line_char_inactive) {
        decr(ilimit);
    } else {
        iobuffer[ilimit] = (unsigned char) end_line_char_par;
    }
    iofirst = ilimit + 1;
    iloc = istart;
}

/*tex

    Because the format is zipped we read and write dump files through zlib.
    Earlier versions recast |*f| from |FILE *| to |gzFile|, but there is no
    guarantee that these have the same size, so a static variable is needed.

    We no longer do byte-swapping so formats are generated for the system and
    not shared. It actually slowed down loading of the format on the majority of
    used platforms (intel).

    A \CONTEXT\ format is uncompressed some 16 MB but that used to be over 30MB
    due to more (preallocated) memory usage. A compressed format is 11 MB so the
    saving is not that much. If we were in lua I'd load the whole file in one go
    and use a fast decompression after which we could access the bytes in memory.
    But it's not worth the trouble.

    So, in principle we can undefine COMPRESSION below and experiment a bit with
    it. With SSD's it makes no dent, but on a network it still might.

*/

# undef COMPRESSION

// # define COMPRESSION "R3"

# ifdef COMPRESSION

    static void fmt_error(int nitems, int item_size)
    {
        fprintf(stderr, "Could not (un)dump %d %d-byte item(s).\n", nitems, item_size);
        exit(EXIT_FAILURE);
    }

    inline void do_zdump(char *p, int item_size, int nitems)
    {
        if (nitems == 0) {
            return;
        } else if (gzwrite(dump_state.gz_fmtfile, (void *) p, (unsigned) (item_size * nitems)) != item_size * nitems) {
            fmt_error(nitems,item_size);
        }
    }

    inline void do_zundump(char *p, int item_size, int nitems)
    {
        if (nitems == 0) {
            return;
        } else if (gzread(dump_state.gz_fmtfile, (void *) p, (unsigned) (item_size * nitems)) <= 0) {
            fmt_error(nitems,item_size);
        }
    }

# else

    inline void do_zdump(char *p, int item_size, int nitems)
    {
        fwrite((void *) p, item_size, nitems, dump_state.fmt_file);
    }

    inline void do_zundump(char *p, int item_size, int nitems)
    {
        if (fread((void *) p, item_size, nitems, dump_state.fmt_file)) {};
    }

# endif

/*tex

    Tests has shown that a level 3 compression is the most optimal tradeoff
    between file size and load time.

*/

int zopen_fmt_input(FILE ** f)
{
    int res = 0;
    int callbackid = callback_defined(find_format_file_callback);
    if (callbackid > 0) {
        char *fnam = NULL;
        res = run_callback(callbackid, "S->R", fileio_state.fmt_name, &fnam);
        if (res && (fnam != NULL) && strlen(fnam) > 0) {
            *f = fopen(fnam, FOPEN_RBIN_MODE);
            if (*f == NULL) {
                return 0;
            }
        } else {
            return 0;
        }
        if (res) {
# ifdef COMPRESSION
            dump_state.gz_fmtfile = gzdopen(fileno(*f), "rb" COMPRESSION);
# endif
        }
    } else {
        normal_error("system","missing find_format_file callback");
    }
    return res;
}

int zopen_fmt_output(FILE ** f)
{
    *f = fopen(fileio_state.fmt_name, FOPEN_WBIN_MODE);
    if (*f == NULL) {
        return 0;
    } else {
# ifdef COMPRESSION
        dump_state.gz_fmtfile = gzdopen(fileno(*f), "wb" COMPRESSION);
# endif
    }
    return 1;
}

void zclose_fmt(FILE * f)
{
    (void) f;
# ifdef COMPRESSION
    gzclose(dump_state.gz_fmtfile);
# endif
}

/*tex

    In order to isolate the system-dependent aspects of file names, the
    system-independent parts of \TEX\ are expressed in terms of
    three system-dependent procedures called |begin_name|, |more_name|, and
    |end_name|. In essence, if the user-specified characters of the file name are
    |c_1|\unknown|c_n|, the system-independent driver program does the operations

    \starttyping
    |begin_name|;
    |more_name|(c_1);
    .....
    |more_name|(c_n);
    |end_name|
    \stoptyping

    These three procedures communicate with each other via global variables.
    Afterwards the file name will appear in the string pool as three strings
    called |cur_name|, |cur_area|, and |cur_ext|; the latter two are null (i.e.,
    |""|), unless they were explicitly specified by the user.

    Actually the situation is slightly more complicated, because \TEX\ needs to
    know when the file name ends. The |more_name| routine is a function (with
    side effects) that returns |true| on the calls |more_name(c_1)|, \dots,
    |more_name(c_{n-1})|. The final call |more_name(c_n)| returns |false|; or, it
    returns |true| and the token following |c_n| is something like |\hbox| (i.e.,
    not a character). In other words, |more_name| is supposed to return |true|
    unless it is sure that the file name has been completely scanned; and
    |end_name| is supposed to be able to finish the assembly of |cur_name|,
    |cur_area|, and |cur_ext| regardless of whether |more_name(c_n)| returned
    |true| or |false|.

    This code has been adapted and the string pool is no longer used. We also
    don't ask for another name on the console.

*/

/*tex

    And here's the second. The string pool might change as the file name is being
    scanned, since a new |\csname| might be entered; therefore we keep
    |area_delimiter| and |ext_delimiter| relative to the beginning of the current
    string, instead of assigning an absolute address like |pool_ptr| to them.

*/

static int more_name(unsigned char c, int *quoted_filename)
{
    if (c == ' ' && (! *quoted_filename)) {
        return 0;
    } else if (c == '"') {
        *quoted_filename = !*quoted_filename;
        return 1;
    } else {
        append_char(c);
        return 1;
    }
}

/*tex

   Now let's consider the \quote {driver} routines by which \TEX\ deals with file
   names in a system-independent manner. First comes a procedure that looks for a
   file name in the input by calling |get_x_token| for the information.

*/

char *read_file_name(int optionalequal, const char * name, const char* ext)
{
    char *fn = NULL;
    if (optionalequal) {
        scan_optional_equals();
    }
    do {
        get_x_token();
    } while ((cur_cmd == spacer_cmd) || (cur_cmd == relax_cmd));
    back_input();
    if (cur_cmd == left_brace_cmd) {
        char *s = NULL;
        int l = 0;
        scan_toks(0, 1, 0);
        s = tokenlist_to_cstring(def_ref, 1, &l);
        fn = pack_file_name(s,l,name,ext);
        free(s);
    } else {
        int quoted_filename = 0;
        /*tex Set |cur_name| to desired file name. */
        str_number u = 0;
        fileio_state.name_in_progress = 1;
        /*tex Get the next non-blank non-call token: */
        do {
            get_x_token();
        } while ((cur_cmd == spacer_cmd) || (cur_cmd == relax_cmd));
        while (1) {
            if ((cur_cmd > other_char_cmd) || (cur_chr > biggest_char)) {   /* not a character */
                back_input();
                break;
            } else if ((cur_chr == ' ') && (istate != token_list) && (iloc > ilimit) && !quoted_filename) {
                /*tex
                    If |cur_chr| is a space and we're not scanning a token list, check
                    whether we're at the end of the buffer. Otherwise we end up adding
                    spurious spaces to file names in some cases.
                */
                break;
            } else if (cur_chr > 127) {
                unsigned char *bytes;
                unsigned char *thebytes;
                thebytes = uni2str((unsigned) cur_chr); /* we can use the buffer variant */
                bytes = thebytes;
                while (*bytes) {
                    if (!more_name(*bytes, &quoted_filename)) {
                        break;
                    }
                    bytes++;
                }
                free(thebytes);
            } else if (!more_name(cur_chr, &quoted_filename)) {
                break;
            }
            u = save_cur_string();
            get_x_token();
            restore_cur_string(u);
        }
        fn = pack_file_name((char *) cur_string,cur_length,name,ext);
        reset_cur_string();
        fileio_state.name_in_progress = 0;
    }
    return fn;
}

void tprint_file_name(unsigned char *n)
{
    int must_quote = 0;
    if (n != NULL) {
        unsigned char *j = n;
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
        print_char('"');
    }
    if (n != NULL) {
        unsigned char *j = n;
        while (*j) {
            if (*j == '"') {
                /* skip embedded quote, maybe escape */
            } else {
                print_char(*j);
            }
            j++;
        }
    }
    if (must_quote) {
        /* final quote */
        print_char('"');
    }
}
