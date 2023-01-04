/*
    See license.txt in the root of this project.
*/

# ifndef LMT_INPUTSTACK_H
# define LMT_INPUTSTACK_H

/*tex

    The state of \TEX's input mechanism appears in the input stack, whose entries are records with
    six fields, called |state|, |index|, |start|, |loc|, |limit|, and |name|.

*/

/* todo: there is no need to be sparse here */

typedef struct in_state_record {
    halfword       start;
    halfword       loc;
    unsigned short state;
    union          { unsigned short index; unsigned short token_type;      }; /*tex: So, no macro but name. */
    union          { halfword       limit; halfword       parameter_start; }; /*tex: So, no macro but name. */
    halfword       name;
    short          cattable;   /*tex The category table used by the current line (see |textoken.c|). */
    unsigned short partial;    /*tex Is the current line partial (see |textoken.c|)? */
    int            state_file; /*tex Here we stack the tag of the current file. */
    int            state_line; /*tex Not used. */
} in_state_record;

typedef struct input_stack_record {
    halfword  input_file_callback_id;
    halfword  line;
    halfword  end_of_file_seen;
    halfword  group;
    halfword  if_ptr;
    halfword  padding;
    char     *full_source_filename;
} input_stack_record;

// todo: better names for in_state_record and input_stack_record ... now mixed up

typedef struct input_state_info {
    in_state_record    *input_stack;
    memory_data         input_stack_data;
    input_stack_record *in_stack;
    memory_data         in_stack_data;
    halfword           *parameter_stack;
    memory_data         parameter_stack_data;
    in_state_record     cur_input;            /*tex The \quote {top} input state. Why not just pointing. */
    int                 input_line;
    int                 scanner_status;
    halfword            def_ref;              /*tex Has to be set for error recovery etc. */
    int                 align_state;
    int                 base_ptr;
    halfword            warning_index;
    int                 open_files;
    int                 padding;
} input_state_info;

extern input_state_info lmt_input_state;

typedef struct input_file_state_info {
    int      forced_file;
    int      forced_line;
    halfword mode;
    halfword line;
} input_file_state_info;

extern input_file_state_info input_file_state;

inline static int input_file_value(void)
{
    return input_file_state.forced_file ? input_file_state.forced_file : lmt_input_state.cur_input.state_file;
}

inline static int input_line_value(void)
{
    return input_file_state.forced_line ? input_file_state.forced_line : (input_file_state.line ? input_file_state.line : lmt_input_state.input_line);
}

/*tex

    In \LUAMETATEX\ the io model was stepwise changed a bit, mostly in the \LUA\ feedback area.
    Support for nodes, tokens, short and long string were improved. Around 2.06.17 specification
    nodes became dynamic and that left the pseudo files as only variable node type. By removing
    variable nodes we can avoid some code in node management so getting rid of pseudo files made
    sense. The token scan macros used these but now use a lightweight varian tof the \LUA\ scanner,
    which we had anyway. The only complication is the |\everyeof| of |\scantokens|. Also, tracing
    (if at all) is now different but these three scanners are seldom used and were introduced in
    \ETEX\ (|scantokens|), \LUATEX\ (|\scantextokens|) and \LUAMETATEX\ (|tokenized|). The new
    approach also gives more room for future extensions.

    All this has been a very stepwise process, because we know that there are users who use \LMTX\
    in production and small steps are easier to test. Experiments mostly happen in parts of the
    code that is less critital ... after all \LUAMETATEX\ is also an experimental engine ... but
    io related code changes are kind of critital.

    Just to remember wahat we came from: the first 15 were reserved read channels but that is now
    delegated to \LUA, so we had an offset of 16 in:

*/

typedef enum io_codes {
    io_initial_input_code,
    io_lua_input_code,
    io_token_input_code,
    io_token_eof_input_code,
    io_tex_macro_code,
    io_file_input_code,
} io_codes;

/*
*
    Now, these |io_codes| are used in the name field but that field can also be a way larger number,
    i.e.\ the string index of the file. That also assumes that the first used index is above the last
    io_code. It can be the warning index too, just for the sake of an error context message. So:
    symbolic (small) number, tex string being the filename, and macro name. But, because we also
    have that information in other places (partly as side effect of luafication) a simpler model is
    used now where we use a few dedicates codes. It also means that we no longer store the filename
    in the string pool.

*/

# define io_token_input(c) (c >= io_lua_input_code && c <= io_token_eof_input_code)
# define io_file_input(c)  (c >= io_file_input_code)

/*tex

    Let's look more closely now at the control variables (|state|, |index|, |start|, |loc|, |limit|,
    |name|), assuming that \TEX\ is reading a line of characters that have been input from some file
    or from the user's terminal. There is an array called |buffer| that acts as a stack of all lines
    of characters that are currently being read from files, including all lines on subsidiary levels
    of the input stack that are not yet completed. \TEX\ will return to the other lines when it is
    finished with the present input file.

    (Incidentally, on a machine with byte-oriented addressing, it might be appropriate to combine
    |buffer| with the |str_pool| array, letting the buffer entries grow downward from the top of the
    string pool and checking that these two tables don't bump into each other.)

    The line we are currently working on begins in position |start| of the buffer; the next character
    we are about to read is |buffer[loc]|; and |limit| is the location of the last character present.
    If |loc > limit|, the line has been completely read. Usually |buffer[limit]| is the
    |end_line_char|, denoting the end of a line, but this is not true if the current line is an
    insertion that was entered on the user's terminal in response to an error message.

    The |name| variable is a string number that designates the name of the current file, if we are
    reading a text file. It is zero if we are reading from the terminal; it is |n+1| if we are reading
    from input stream |n|, where |0 <= n <= 16|. (Input stream 16 stands for an invalid stream number;
    in such cases the input is actually from the terminal, under control of the procedure |read_toks|.)
    Finally |18 <= name <=20| indicates that we are reading a pseudo file created by the |\scantokens|
    or |\scantextokens| command. A larger value is reserved for input coming from \LUA.

    The |state| variable has one of three values, when we are scanning such files:

    \startitemize
        \startitem
            |mid_line| is the normal state.
        \stopitem
        \startitem
            |skip_blanks| is like |mid_line|, but blanks are ignored.
        \stopitem
        \startitem
            |new_line| is the state at the beginning of a line.
        \stopitem
    \stopitemize

    These state values are assigned numeric codes so that if we add the state code to the next
    character's command code, we get distinct values. For example, |mid_line + spacer| stands for the
    case that a blank space character occurs in the middle of a line when it is not being ignored;
    after this case is processed, the next value of |state| will be |skip_blanks|.

    As with other constants, we only add some prefix or suffix but keep the normal name as much as
    possible, so that the original documentation still applies.

*/

typedef enum state_codes {
    token_list_state  = 0,
    /*tex when scanning a line of characters */
    mid_line_state    = 1,
    /*tex when ignoring blanks */
    skip_blanks_state = 2 + max_char_code,
    /*tex at the start of a line */
    new_line_state    = 3 + max_char_code + max_char_code,
} state_codes;

/*tex

    Additional information about the current line is available via the |index| variable, which
    counts how many lines of characters are present in the buffer below the current level. We
    have |index = 0| when reading from the terminal and prompting the user for each line; then if
    the user types, e.g., |\input paper|, we will have |index = 1| while reading the file
    |paper.tex|. However, it does not follow that |index| is the same as the input stack pointer,
    since many of the levels on the input stack may come from token lists. For example, the
    instruction |\input paper| might occur in a token list.

    The global variable |in_open| is equal to the |index| value of the highest \quote {non token
    list} level. Thus, the number of partially read lines in the buffer is |in_open + 1|, and we
    have |in_open = index| when we are not reading a token list.

    If we are not currently reading from the terminal, or from an input stream, we are reading from
    the file variable |input_file [index]|. We use the notation |terminal_input| as a convenient
    abbreviation  for |name = 0|, and |cur_file| as an abbreviation for |input_file [index]|.

    The global variable |line| contains the line number in the topmost open file, for use in error
    messages. If we are not reading from the terminal, |line_stack [index]| holds the line number
    or  the enclosing level, so that |line| can be restored when the current file has been read.
    Line numbers should never be negative, since the negative of the current line number is used to
    identify the user's output routine in the |mode_line| field of the semantic nest entries.

    If more information about the input state is needed, it can be included in small arrays like
    those shown here. For example, the current page or segment number in the input file might be
    put into a variable |page|, maintained for enclosing levels in ||page_stack:array [1 ..
    max_input_open] of integer| by analogy with |line_stack|.

    Users of \TEX\ sometimes forget to balance left and right braces properly, and one of the ways
    \TEX\ tries to spot such errors is by considering an input file as broken into subfiles by
    control sequences that are declared to be |\outer|.

    A variable called |scanner_status| tells \TEX\ whether or not to complain when a subfile ends.
    This variable has six possible values:

    \startitemize

    \startitem
        |normal|, means that a subfile can safely end here without incident.
    \stopitem

    \startitem
        |skipping|, means that a subfile can safely end here, but not a file, because we're reading
        past some conditional text that was not selected.
    \stopitem

    \startitem
        |defining|, means that a subfile shouldn't end now because a macro is being defined.
    \stopitem

    \startitem
        |matching|, means that a subfile shouldn't end now because a macro is being used and we are
        searching for the end of its arguments.
    \stopitem

    \startitem
        |aligning|, means that a subfile shouldn't end now because we are not finished with the
        preamble of an |\halign| or |\valign|.
    \stopitem

    \startitem
        |absorbing|, means that a subfile shouldn't end now because we are reading a balanced token
        list for |\message|, |\write|, etc.
    \stopitem

    \stopitemize

    If the |scanner_status| is not |normal|, the variable |warning_index| points to the |eqtb|
    location for the relevant control sequence name to print in an error message.

*/

typedef enum scanner_states {
    scanner_is_normal,    /*tex passing conditional text */
    scanner_is_skipping,  /*tex passing conditional text */
    scanner_is_defining,  /*tex reading a macro definition */
    scanner_is_matching,  /*tex reading macro arguments */
    scanner_is_tolerant,  /*tex reading tolerant macro arguments */
    scanner_is_aligning,  /*tex reading an alignment preamble */
    scanner_is_absorbing, /*tex reading a balanced text */
} scanner_states;

extern void tex_show_runaway(void); /*tex This is only used when running out of token memory. */

/*tex

    However, the discussion about input state really applies only to the case that we are inputting
    from a file. There is another important case, namely when we are currently getting input from a
    token list. In this case |state = token_list|, and the conventions about the other state
    variables are
    different:

    \startitemize

    \startitem
        |loc| is a pointer to the current node in the token list, i.e., the node that will be read
        next. If |loc=null|, the token list has been fully read.
    \stopitem

    \startitem
        |start| points to the first node of the token list; this node may or may not contain a
        reference count, depending on the type of token list involved.
    \stopitem

    \startitem
        |token_type|, which takes the place of |index| in the discussion above, is a code number
        that explains what kind of token list is being scanned.
    \stopitem

    \startitem
        |name| points to the |eqtb| address of the control sequence being expanded, if the current
        token list is a macro.
    \stopitem

    \startitem
        |param_start|, which takes the place of |limit|, tells where the parameters of the current
        macro begin in the |param_stack|, if the current token list is a macro.
    \stopitem

    \stopitemize

    The |token_type| can take several values, depending on where the current token list came from:

    \startitemize

    \startitem
        |parameter|, if a parameter is being scanned;
    \stopitem

    \startitem
        |u_template|, if the |u_j| part of an alignment template is being scanned;
    \stopitem

    \startitem
        |v_template|, if the |v_j| part of an alignment template is being scanned;
    \stopitem

    \startitem
        |backed_up|, if the token list being scanned has been inserted as \quotation {to be read
        again}.
    \stopitem

    \startitem
        |inserted|, if the token list being scanned has been inserted as the text expansion of a
        |\count| or similar variable;
    \stopitem

    \startitem
        |macro|, if a user-defined control sequence is being scanned;
    \stopitem

    \startitem
        |output_text|, if an |\output| routine is being scanned;
    \stopitem

    \startitem
        |every_par_text|, if the text of |\everypar| is being scanned;
    \stopitem

    \startitem
        |every_math_text|, if the text of |\everymath| is being scanned;
    \stopitem

    \startitem
        |every_display_text|, if the text of \everydisplay| is being scanned;
    \stopitem

    \startitem
        |every_hbox_text|, if the text of |\everyhbox| is being scanned;
    \stopitem

    \startitem
        |every_vbox_text|, if the text of |\everyvbox| is being scanned;
    \stopitem

    \startitem
        |every_job_text|, if the text of |\everyjob| is being scanned;
    \stopitem

    \startitem
        |every_cr_text|, if the text of |\everycr| is being scanned;
    \stopitem

    \startitem
        |mark_text|, if the text of a |\mark| is being scanned;
    \stopitem

    \startitem
        |write_text|, if the text of a |\write| is being scanned.
    \stopitem

    \stopitemize

    The codes for |output_text|, |every_par_text|, etc., are equal to a constant plus the
    corresponding codes for token list parameters |output_routine_loc|, |every_par_loc|, etc.

    The token list begins with a reference count if and only if |token_type >= macro|.

    Since \ETEX's additional token list parameters precede |toks_base|, the corresponding token
    types must precede |write_text|. However, in \LUAMETATEX\ we delegate all the read and write
    primitives to \LUA\ so that model has been simplified.

*/

/* #define token_type  input_state.cur_input.token_type  */ /*tex type of current token list */
/* #define param_start input_state.cur_input.param_start */ /*tex base of macro parameters in |param_stack| */

typedef enum token_types {
    parameter_text,        /*tex parameter */
    template_pre_text,     /*tex |u_j| template */
    template_post_text,    /*tex |v_j| template */
    backed_up_text,        /*tex text to be reread */
    inserted_text,         /*tex inserted texts */
    macro_text,            /*tex defined control sequences */
    output_text,           /*tex output routines */
    every_par_text,        /*tex |\everypar| */
    every_math_text,       /*tex |\everymath| */
    every_display_text,    /*tex |\everydisplay| */
    every_hbox_text,       /*tex |\everyhbox| */
    every_vbox_text,       /*tex |\everyvbox| */
    every_math_atom_text,  /*tex |\everymathatom| */
    every_job_text,        /*tex |\everyjob| */
    every_cr_text,         /*tex |\everycr| */
    every_tab_text,        /*tex |\everytab| */
    error_help_text,
    every_before_par_text, /*tex |\everybeforeeof| */
    every_eof_text,        /*tex |\everyeof| */
    end_of_group_text,
    mark_text,             /*tex |\topmark|, etc. */
    loop_text,
    end_paragraph_text,    /*tex |\everyendpar| */
    write_text,            /*tex |\write| */
    local_text,
    local_loop_text,
} token_types;

extern void        tex_initialize_input_state  (void);
/*     int         tex_room_on_parameter_stack (void); */
/*     int         tex_room_on_in_stack        (void); */
/*     int         tex_room_on_input_stack     (void); */
extern void        tex_copy_to_parameter_stack (halfword *pstack, int n);
extern void        tex_show_context            (void);
extern void        tex_show_validity           (void);
extern void        tex_set_trick_count         (void);
extern void        tex_begin_token_list        (halfword t, quarterword kind); /* include some tracing */
extern void        tex_begin_parameter_list    (halfword t);                   /* less inlining code */
extern void        tex_begin_backed_up_list    (halfword t);                   /* less inlining code */
extern void        tex_begin_inserted_list     (halfword t);                   /* less inlining code */
extern void        tex_begin_macro_list        (halfword t);                   /* less inlining code */
extern void        tex_end_token_list          (void);
extern void        tex_cleanup_input_state     (void);
extern void        tex_back_input              (halfword t);
extern void        tex_reinsert_token          (halfword t);
extern void        tex_insert_input            (halfword h);
extern void        tex_append_input            (halfword h);
extern void        tex_begin_file_reading      (void);
extern void        tex_end_file_reading        (void);
extern void        tex_initialize_inputstack   (void);
extern void        tex_lua_string_start        (void);
extern void        tex_tex_string_start        (int iotype, int cattable);
extern void        tex_any_string_start        (char *s);
extern halfword    tex_wrapped_token_list      (halfword h);
extern const char *tex_current_input_file_name (void);

# endif
