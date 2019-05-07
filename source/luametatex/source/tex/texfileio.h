/*
    See license.txt in the root of this project.
*/

# ifndef TEXFILEIO_H
# define TEXFILEIO_H

extern int lua_a_open_in(FILE ** f, char *fn, int n);
extern int lua_a_open_out(FILE ** f, char *fn, int n);
extern void lua_a_close_in(FILE * f, int n);
extern void lua_a_close_out(FILE * f);
extern int lua_input_ln(FILE * f, int n);

extern void do_zdump(char *, int, int);
extern void do_zundump(char *, int, int);

/*tex

The user's terminal acts essentially like other files of text, except that it is
used both for input and for output. When the terminal is considered an input
file, the file variable is called |term_in|, and when it is considered an output
file the file variable is |term_out|.

*/

# define term_in  stdin  /*tex the terminal as an input file */
# define term_out stdout /*tex the terminal as an output file */

/*tex

Sometimes it is necessary to synchronize the input/output mixture that happens on
the user's terminal, and three system-dependent procedures are used for this
purpose. The first of these, |update_terminal|, is called when we want to make
sure that everything we have output to the terminal so far has actually left the
computer's internal buffers and been sent. The second, |clear_terminal|, is
called when we wish to cancel any input that the user may have typed ahead (since
we are about to issue an unexpected error message). The third,
|wake_up_terminal|, is supposed to revive the terminal if the user has disabled
it by some instruction to the operating system. The following macros show how
these operations can be specified with \UNIX. |update_terminal| does an |fflush|.
|clear_terminal| is redefined to do nothing, since the user should control the
terminal.

*/

# define format_extension     ".fmt"
# define transcript_extension ".log"
# define texinput_extension   ".tex"

typedef struct fileio_state_info {
    int *input_file_callback_id;
    int read_file_callback_id[17];
    /* */
    unsigned char *iobuffer; /*tex lines of characters being read */
    int iofirst;             /*tex the first unused position in |buffer| */
    int iolast;              /*tex end of the line just input to |buffer| */
    int max_buf_stack;       /*tex largest index used in |buffer| */
    /* */
    char *job_name;          /*tex the principal file name. */
    char *log_name;          /*tex full name of the log file */
    char *fmt_name;
    /* */
    int name_in_progress;    /*tex Is a file name being scanned? */
    int log_opened;          /*tex Has the transcript file been opened? */
} fileio_state_info ;

extern fileio_state_info fileio_state;

# define iobuffer           fileio_state.iobuffer
# define iofirst            fileio_state.iofirst
# define iolast             fileio_state.iolast
# define max_buf_stack      fileio_state.max_buf_stack

# define input_file_callback_id  fileio_state.input_file_callback_id
# define read_file_callback_id   fileio_state.read_file_callback_id

# define update_terminal() fflush (term_out)
# define clear_terminal() do { ; } while (0)

/*tex Cancel the user's cancellation of output: */

# define wake_up_terminal() do { ; } while (0)

extern int init_terminal(void);
extern void term_input(void);

extern void open_log_file(void);
extern void close_log_file(void);
extern void start_input(void);

extern void check_fmt_name(void);

extern int open_fmt_file(void);
extern void close_fmt_file(void);

extern int zopen_fmt_input(FILE **);
extern int zopen_fmt_output(FILE **);
extern void zclose_fmt(FILE *);

# define report_start_file(name) do { \
    int report_id = callback_defined(start_file_callback); \
    if (report_id == 0) { \
        tprint("("); \
        tprint_file_name((unsigned char *) name); \
    } else { \
        (void) run_callback(report_id, "S->",name); \
    } \
} while (0)

# define report_stop_file() do { \
    int report_id = callback_defined(stop_file_callback); \
    if (report_id == 0) { \
        tprint(")"); \
    } else { \
        (void) run_callback(report_id, "->"); \
    } \
} while (0)

/*tex

    This used to be |filename.h| but it makes more sense now to have it here.

*/

extern char *read_file_name(int optionalequal, const char * name, const char* ext);
extern char *prompt_file_name(int isinput, const char * badname, const char *s, const char *e);
extern void tprint_file_name(unsigned char *n);

# endif
