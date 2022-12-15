/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXTOKEN_H
# define LMT_TEXTOKEN_H

# include "luametatex.h"

/*tex

    These are constants that can be added to a chr value and then give a token with the right cmd
    and chr combination, whichs is then equivalent to |token_val (cmd, chr)|. The cmd results from
    shifting right 21 bits. The following tokens therefore should match the order of the (first
    bunch) of cmd codes!

    \TEX\ stores the specific match character which defaults to |#|. When tokens get serialized the
    machinery starts with |match_chr = '#'| but overloads that by the last stored variant. So the
    last (!) seen |match_chr| in the macro preamble determines what gets used in showing the body.
    One could argue that this is a buglet but I more see it as a side effect. In practice there is
    never a mix of such characters used. Anyway, one could as well use the first seen in the
    preamble and use that for the rest because consistency is better than confusion. Even better is
    to just always use |#| and store the numbers in preamble match tokens, which opens up
    possibilities (for strict or tolerant matching, skipping spaces, optional delimiters and even
    more arguments).

*/

//define cs_token_flag            0x1FFFFFFF

# define node_token_max           0x0FFFFF
# define node_token_flag          0x100000
# define node_token_lsb(sum)      (sum & 0x0000FFFF)
# define node_token_msb(sum)      (((sum & 0xFFFF0000) >> 16) + node_token_flag)
# define node_token_sum(msb,lsb)  (((msb & 0x0000FFFF) << 16) + lsb)
# define node_token_overflow(sum) (sum > node_token_max)
# define node_token_flagged(sum)  (sum > node_token_flag)

/*tex
    Instead of |fixmem| we use |tokens| because it is dynamic anyway and we then better match variables
    that deal with managing that. Most was already hidden in a few files anyway.
*/

typedef struct token_memory_state_info {
    memoryword  *tokens;      /*tex |memoryword *volatile fixmem;| */
    memory_data  tokens_data;
    halfword     available;
    int          padding;
} token_memory_state_info;

extern token_memory_state_info lmt_token_memory_state;

typedef enum read_states {
    reading_normal,      /*tex we're going ahead */
    reading_just_opened, /*tex newly opened, first line not yet read */
    reading_closed,      /*tex not open, or at end of file */
} read_states;

typedef enum lua_input_types {
    unset_lua_input,
    string_lua_input,
    packed_lua_input,
    token_lua_input,
    token_list_lua_input,
    node_lua_input,
} lua_input_types;

typedef enum tex_input_types {
    eof_tex_input,
    string_tex_input,
    token_tex_input,
    token_list_tex_input,
    node_tex_input,
} tex_input_types;

typedef enum catcode_table_presets {
    default_catcode_table_preset = -1,
    no_catcode_table_preset      = -2,
} catcode_table_presets;

/*tex
*
    There are a few temporary head pointers, one is |temp_token_head|. This one we keep because
    when we expand, we can run into situations where we need that pointer. But, |backup_head| is
    a real temporary one: we can replace that with local variables. Okay, it is kind of kept in
    the format file but if it ends up there we're in some kind of troubles anyway. So,
    |backup_head| is now local and |temp_token_head| only global when we are scanning; in cases
    where we serialize tokens lists it has been replaced by local variables (and the related
    functions now keep track of head and tail). This makes sense because in \LUAMETATEX\ we often
    go between \TEX\ and \LUA\ and this keeps it kind of simple. This also makes clear when we
    are scanning (the global head is used) and doing something simple with a list. The same is
    true for |match_token_head| thatmoved to the expand state. The |backup_head| variable is gone
    because we now use locals.

*/

typedef struct token_state_info {
    halfword  null_list;        /*tex permanently empty list */
    int       in_lua_escape;
    int       force_eof;
    int       luacstrings;
    /*tex These are pseudo constants, their value depends on the number of primitives etc. */
    halfword  par_loc;
    halfword  par_token;
 /* halfword  line_par_loc;   */ /*tex See note in textoken.c|. */
 /* halfword  line_par_token; */ /*tex See note in textoken.c|. */
    /* */
    char     *buffer;
    int       bufloc;
    int       bufmax;
    int       empty;
} token_state_info;

extern token_state_info lmt_token_state;

/*tex

    We now can have 15 paremeters but if needed we can go higher. However, we then also need to 
    cache more and change the |preamble| and |count| to some funny bit ranges. If needed we can 
    bump the reference count maximum but quite likely one already has run out of something else
    already.   

    \starttyping
    preamble  = 0xF0000000 : 1 when we have one, including trailing #
    count     = 0x0F000000
    reference = 0x00FFFFFF
    \stoptyping

*/

# define max_match_count 15
# define gap_match_count  7

# define max_token_reference 0x00FFFFFF

# define get_token_preamble(a)   ((lmt_token_memory_state.tokens[a].hulf1 >> 28) & 0xF)
# define get_token_parameters(a) ((lmt_token_memory_state.tokens[a].hulf1 >> 24) & 0xF)
# define get_token_reference(a)  ((lmt_token_memory_state.tokens[a].hulf1      ) & max_token_reference)

# define set_token_preamble(a,b)   lmt_token_memory_state.tokens[a].hulf1 += ((b) << 28)  /* normally the variable is still zero here */
# define set_token_parameters(a,b) lmt_token_memory_state.tokens[a].hulf1 += ((b) << 24)  /* normally the variable is still zero here */

# define set_token_reference(a,b)  lmt_token_memory_state.tokens[a].hulf1 += (b)
# define add_token_reference(a)    lmt_token_memory_state.tokens[a].hulf1 += 1            /* we are way off the parameter count */
# define sub_token_reference(a)    lmt_token_memory_state.tokens[a].hulf1 -= 1            /* we are way off the parameter count */
# define inc_token_reference(a,b)  lmt_token_memory_state.tokens[a].hulf1 += (b)          /* we are way off the parameter count */
# define dec_token_reference(a,b)  lmt_token_memory_state.tokens[a].hulf1 -= (b)          /* we are way off the parameter count */

/* */

# define token_info(a)       lmt_token_memory_state.tokens[a].half1
# define token_link(a)       lmt_token_memory_state.tokens[a].half0
# define get_token_info(a)   lmt_token_memory_state.tokens[a].half1
# define get_token_link(a)   lmt_token_memory_state.tokens[a].half0
# define set_token_info(a,b) lmt_token_memory_state.tokens[a].half1 = (b)
# define set_token_link(a,b) lmt_token_memory_state.tokens[a].half0 = (b)

# define token_cmd(A)    ((A) >> cs_offset_bits)
# define token_chr(A)    ((A) &  cs_offset_max)
# define token_val(A,B) (((A) << cs_offset_bits) + (B))

/*tex
    Sometimes we add a value directly. Instead we could use |token_val| on the spot but then we
    also need different range checkers. We use numbers because we don't have the cmd codes defined
    yet when we're here. so we can't use for instance |token_val (spacer_cmd, 20)| yet.
*/

# define left_brace_token        token_val( 1, 0) // token_val(left_brace_cmd,0)
# define right_brace_token       token_val( 2, 0) // token_val(right_brace_cmd,0)
# define math_shift_token        token_val( 3, 0) // token_val(math_shift_cmd,0)
# define alignment_token         token_val( 4, 0)
# define superscript_token       token_val( 7, 0)
# define subscript_token         token_val( 8, 0)
# define ignore_token            token_val( 9, 0) // token_val(ignore_cmd,0)
# define space_token             token_val(10,32) // token_val(spacer_cmd,32)
# define letter_token            token_val(11, 0) // token_val(letter_cmd,0)
# define other_token             token_val(12, 0) // token_val(other_char_cmd,0)
# define active_token            token_val(13, 0)

# define match_token             token_val(19,0)  // token_val(match_cmd,0)
# define end_match_token         token_val(20,0)  // token_val(end_match_cmd,0)

# define left_brace_limit  right_brace_token
# define right_brace_limit math_shift_token

# define octal_token             (other_token  + '\'') /*tex apostrophe, indicates an octal constant */
# define hex_token               (other_token  + '"')  /*tex double quote, indicates a hex constant */
# define alpha_token             (other_token  + '`')  /*tex reverse apostrophe, precedes alpha constants */
# define point_token             (other_token  + '.')  /*tex decimal point */
# define continental_point_token (other_token  + ',')  /*tex decimal point, Eurostyle */
# define period_token            (other_token  + '.')  /*tex decimal point */
# define comma_token             (other_token  + ',')  /*tex decimal comma */
# define plus_token              (other_token  + '+')
# define minus_token             (other_token  + '-')
# define slash_token             (other_token  + '/')
# define asterisk_token          (other_token  + '*')
# define colon_token             (other_token  + ':')
# define semi_colon_token        (other_token  + ';')
# define equal_token             (other_token  + '=')
# define less_token              (other_token  + '<')
# define more_token              (other_token  + '>')
# define exclamation_token_o     (other_token  + '!')
# define exclamation_token_l     (letter_token + '!')
# define underscore_token        (other_token  + '_')
# define underscore_token_o      (other_token  + '_')
# define underscore_token_l      (letter_token + '_')
# define circumflex_token        (other_token  + '^')
# define circumflex_token_o      (other_token  + '^')
# define circumflex_token_l      (letter_token + '^')
# define escape_token            (other_token  + '\\')
# define left_parent_token       (other_token  + '(')
# define right_parent_token      (other_token  + ')')
# define zero_token              (other_token  + '0')  /*tex zero, the smallest digit */
# define five_token              (other_token  + '5')
# define seven_token             (other_token  + '7')
# define nine_token              (other_token  + '9')  /*tex zero, the smallest digit */

# define a_token_l               (letter_token + 'a')  /*tex the smallest special hex digit */
# define a_token_o               (other_token  + 'a')

# define b_token_l               (letter_token + 'b')  /*tex the smallest special hex digit */
# define b_token_o               (other_token  + 'b')

# define d_token_l               (letter_token + 'd')
# define d_token_o               (other_token  + 'd')

# define e_token_l               (letter_token + 'e')
# define e_token_o               (other_token  + 'e')

# define f_token_l               (letter_token + 'f')  /*tex the largest special hex digit */
# define f_token_o               (other_token  + 'f')

# define i_token_l               (letter_token + 'i')
# define i_token_o               (other_token  + 'i')

# define l_token_l               (letter_token + 'l')
# define l_token_o               (other_token  + 'l')

# define m_token_l               (letter_token + 'm')
# define m_token_o               (other_token  + 'm')

# define n_token_l               (letter_token + 'n')
# define n_token_o               (other_token  + 'n')

# define o_token_l               (letter_token + 'o')
# define o_token_o               (other_token  + 'o')

# define p_token_l               (letter_token + 'p')
# define p_token_o               (other_token  + 'p')

# define r_token_l               (letter_token + 'r')
# define r_token_o               (other_token  + 'r')

# define s_token_l               (letter_token + 's')
# define s_token_o               (other_token  + 's')

# define t_token_l               (letter_token + 't')
# define t_token_o               (other_token  + 't')

# define u_token_l               (letter_token + 'u')
# define u_token_o               (other_token  + 'u')

# define x_token_l               (letter_token + 'x')
# define x_token_o               (other_token  + 'x')

# define A_token_l               (letter_token + 'A')  /*tex the smallest special hex digit */
# define A_token_o               (other_token  + 'A')

# define E_token_l               (letter_token + 'E')
# define E_token_o               (other_token  + 'E')

# define F_token_l               (letter_token + 'F')  /*tex the largest special hex digit */
# define F_token_o               (other_token  + 'F')

# define P_token_l               (letter_token + 'P')  /*tex the largest special hex digit */
# define P_token_o               (other_token  + 'P')

# define X_token_l               (letter_token + 'X')
# define X_token_o               (other_token  + 'X')

# define at_token_l              (letter_token + '@')
# define at_token_o              (other_token  + '@')

# define match_visualizer    '#'
# define match_spacer        '*'  /* ignore spaces */
# define match_bracekeeper   '+'  /* keep the braces */
# define match_thrasher      '-'  /* discard and don't count the argument */
# define match_par_spacer    '.'  /* ignore pars and spaces */
# define match_keep_spacer   ','  /* push back space when no match */
# define match_pruner        '/'  /* remove leading and trailing spaces and pars */
# define match_continuator   ':'  /* pick up scanning here */
# define match_quitter       ';'  /* quit scanning */
# define match_mandate       '='  /* braces are mandate */
# define match_spacekeeper   '^'  /* keep leading spaces */
# define match_mandate_keep  '_'  /* braces are mandate and kept */
# define match_par_command   '@'  /* par delimiter, only internal */

# define spacer_match_token        (match_token + match_spacer)
# define keep_match_token          (match_token + match_bracekeeper)
# define thrash_match_token        (match_token + match_thrasher)
# define par_spacer_match_token    (match_token + match_par_spacer)
# define keep_spacer_match_token   (match_token + match_keep_spacer)
# define prune_match_token         (match_token + match_pruner)
# define continue_match_token      (match_token + match_continuator)
# define quit_match_token          (match_token + match_quitter)
# define mandate_match_token       (match_token + match_mandate)
# define leading_match_token       (match_token + match_spacekeeper)
# define mandate_keep_match_token  (match_token + match_mandate_keep)
# define par_command_match_token   (match_token + match_par_command)

# define is_valid_match_ref(r) (r != thrash_match_token && r != spacer_match_token && r != keep_spacer_match_token && r != continue_match_token && r != quit_match_token)

/*tex
    Managing the head of the list of available one-word nodes. The |get_avail| function has been
    given a more verbose name. It gets from the pool and should not be confused with |get_token|
    which reads from the input or token list. The |free_avail| function got renamed to
    |put_available_token| so we have some symmetry here.
*/

extern void     tex_compact_tokens            (void);
extern void     tex_initialize_tokens         (void);
extern void     tex_initialize_token_mem      (void);
extern halfword tex_get_available_token       (halfword t);
extern void     tex_put_available_token       (halfword p);
extern halfword tex_store_new_token           (halfword p, halfword t);
extern void     tex_delete_token_reference    (halfword p);
extern void     tex_add_token_reference       (halfword p);
extern void     tex_increment_token_reference (halfword p, int n);

# define get_reference_token() tex_get_available_token(null)

/*tex

    The |no_expand_flag| is a special character value that is inserted by |get_next| if it wants to
    suppress expansion.

*/

# define no_expand_flag special_char /* no_expand_relax_code */

/*tex  A few special values: */

# define default_token_show_min 32
# define default_token_show_max 2500
# define extreme_token_show_max 0x3FFFFFFF

/*tex  All kind of helpers: */

extern void       tex_dump_token_mem              (dumpstream f);
extern void       tex_undump_token_mem            (dumpstream f);
extern void       tex_print_meaning               (halfword code);
extern void       tex_flush_token_list            (halfword p);
extern void       tex_flush_token_list_head_tail  (halfword h, halfword t, int n);
extern halfword   tex_show_token_list             (halfword p, halfword q, int l, int asis); /* Here |l| will go away. */
extern void       tex_token_show                  (halfword p, int max);
/*     void       tex_add_token_ref               (halfword p); */
/*     void       tex_delete_token_ref            (halfword p); */
extern void       tex_get_next                    (void);
extern halfword   tex_scan_character              (const char *s, int left_brace, int skip_space, int skip_relax);
extern int        tex_scan_optional_keyword       (const char *s);
extern int        tex_scan_mandate_keyword        (const char *s, int offset);
extern void       tex_aux_show_keyword_error      (const char *s);
extern int        tex_scan_keyword                (const char *s);
extern int        tex_scan_keyword_case_sensitive (const char *s);
extern halfword   tex_active_to_cs                (int c, int force);
extern halfword   tex_string_to_toks              (const char *s);
extern int        tex_get_char_cat_code           (int c);
extern halfword   tex_get_token                   (void);
extern void       tex_get_x_or_protected          (void);
extern halfword   tex_str_toks                    (lstring s, halfword *tail); /* returns head */
extern halfword   tex_cur_str_toks                (halfword *tail);            /* returns head */
extern halfword   tex_str_scan_toks               (int c, lstring b);          /* returns head */
extern void       tex_run_combine_the_toks        (void);
extern void       tex_run_convert_tokens          (halfword code);
extern strnumber  tex_the_convert_string          (halfword c, int i);
extern strnumber  tex_tokens_to_string            (halfword p);
extern char      *tex_tokenlist_to_tstring        (int p, int inhibit_par, int *siz, int skip, int nospace, int strip, int wipe);

extern halfword   tex_get_tex_dimen_register      (int j, int internal);
extern halfword   tex_get_tex_skip_register       (int j, int internal);
extern halfword   tex_get_tex_mu_skip_register    (int j, int internal);
extern halfword   tex_get_tex_count_register      (int j, int internal);
extern halfword   tex_get_tex_attribute_register  (int j, int internal);
extern halfword   tex_get_tex_box_register        (int j, int internal);
extern halfword   tex_get_tex_toks_register       (int j, int internal);

extern void       tex_set_tex_dimen_register      (int j, halfword v, int flags, int internal);
extern void       tex_set_tex_skip_register       (int j, halfword v, int flags, int internal);
extern void       tex_set_tex_mu_skip_register    (int j, halfword v, int flags, int internal);
extern void       tex_set_tex_count_register      (int j, halfword v, int flags, int internal);
extern void       tex_set_tex_attribute_register  (int j, halfword v, int flags, int internal);
extern void       tex_set_tex_box_register        (int j, halfword v, int flags, int internal);

extern void       tex_set_tex_toks_register       (int j,        lstring s, int flags, int internal);
extern void       tex_scan_tex_toks_register      (int j, int c, lstring s, int flags, int internal);

extern halfword   tex_copy_token_list             (halfword h, halfword *t);

extern halfword   tex_parse_str_to_tok            (halfword head, halfword *tail, halfword ct, const char *str, size_t lstr, int option);

inline static int tex_valid_token                 (int t) { return ((t >= 0) && (t <= (int) lmt_token_memory_state.tokens_data.top)); }

/*tex 

    This is also a sort of documentation. Active characters are stored in the hash using a prefix 
    which assumes that users don't use that one. So far we've seen no clashes which is due to the 
    fact that the namespace prefix U+FFFF is an invalid \UNICODE\ character and it's kind of hard 
    to get that one into the input anyway. 

    The replacement character U+FFFD is a kind of fallback when we run into some troubles or when 
    a control sequence is expected (and undefined is unacceptable). 

    U+FFFD  REPLACEMENT CHARACTER 
    U+FFFE  NOT A CHARACTER
    U+FFFF  NOT A CHARACTER 

    I experimented with a namespace character (catcodtable id) as fourth character but there are 
    some unwanted side effects, for instance in testing an active character as separator (in 
    arguments) so that code waa eventually removed. I might come back to this one day (active 
    characters in the catcode regime namespace).

*/

# define utf_fffd_string            "\xEF\xBF\xBD" /* U+FFFD : 65533 */

# define active_character_namespace "\xEF\xBF\xBF" /* U+FFFF : 65535 */

# define active_character_first     '\xEF'        
# define active_character_second    '\xBF'
# define active_character_third     '\xBF'

# define active_first               0xEF        
# define active_second              0xBF
# define active_third               0xBF

# define active_character_unknown   "\xEF\xBF\xBD" /* utf_fffd_string */

# define active_cs_value(A) aux_str2uni(str_string(A)+3)

# endif
