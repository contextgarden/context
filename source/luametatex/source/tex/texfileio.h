/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXFILEIO_H
# define LMT_TEXFILEIO_H

# include "textypes.h"

# define FOPEN_R_MODE    "r"
# define FOPEN_W_MODE    "wb"
# define FOPEN_RBIN_MODE "rb"
# define FOPEN_WBIN_MODE "wb"

# define IS_SPC_OR_EOL(c) ((c) == ' ' || (c) == '\r' || (c) == '\n')

extern void tex_initialize_fileio_state (void);
extern int  tex_room_in_buffer          (int top);
extern int  tex_lua_a_open_in           (const char *fn);
extern void tex_lua_a_close_in          (void);
extern int  tex_lua_input_ln            (void);

/*tex

    The user's terminal acts essentially like other files of text, except that it is used both for
    input and for output. In traditional \TEX, when the terminal is considered an input file, the
    file variable is called |term_in|, and when it is considered an output file the file variable
    is |term_out|.

    However, in \LUATEX\ in addition to files we also have pseudo files (something \ETEX) and input
    coming from \LUA, which makes for a much more complex system. In \LUAMETATEX\ the model has
    been stepwise simplified: pseudo files are gone and use a mechanism simular to \LUA\ input, and
    the terminal is left up to the (anyway kind of mandate) file related callbacks, with read file
    id zero still being the console. Output to the console is part of a model that intercepts output
    to the log file and/or the console and can delegate handling to callbacks as well.

    So, in the end, the terminal code in \LUAMETATEX\ is gone as all goes through \LUA, which also
    means that |terminal_update|, |clear_terminal| and |wake_up_terminal| are no longer needed.

    It is important to notice that reading from files is split into two: the files explicitly opened
    with |\openin| are managed independent from the files opened with |\input|.  The first category
    is not part of input file nesting management.

*/

# define format_extension     ".fmt"
# define transcript_extension ".log"
# define texinput_extension   ".tex"

typedef struct fileio_state_info {
    unsigned char *io_buffer;           /*tex lines of characters being read */
    memory_data    io_buffer_data;
    int            io_first;            /*tex the first unused position in |buffer| */
    int            io_last;             /*tex end of the line just input to |buffer| */
    int            name_in_progress;    /*tex Is a file name being scanned? */
    int            log_opened;          /*tex the transcript file has been opened */
    char          *job_name;            /*tex the principal file name */
    char          *log_name;            /*tex full name of the log file */
    char          *fmt_name;
} fileio_state_info ;

extern fileio_state_info lmt_fileio_state;

# define emergency_job_name (lmt_fileio_state.job_name ? lmt_fileio_state.job_name : "unknown job name")
# define emergency_log_name (lmt_fileio_state.log_name ? lmt_fileio_state.log_name : "unknown log name")
# define emergency_fmt_name (lmt_fileio_state.fmt_name ? lmt_fileio_state.fmt_name : "unknown fmt name")

extern void        tex_terminal_update   (void);
extern void        tex_open_log_file     (void);
extern void        tex_close_log_file    (void);
extern void        tex_start_input       (char *fn);
extern void        tex_check_fmt_name    (void);
extern void        tex_check_job_name    (char *fn);
extern dumpstream  tex_open_fmt_file     (int writemode);
extern void        tex_close_fmt_file    (dumpstream f);
extern char       *tex_read_file_name    (int optionalequal, const char * name, const char* ext);
extern void        tex_print_file_name   (unsigned char *name);
extern void        tex_report_start_file (unsigned char *name);
extern void        tex_report_stop_file  (void);

# endif
