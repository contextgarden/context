/*
    See license.txt in the root of this project.
*/

# ifndef TEXTOKEN_H
#  define TEXTOKEN_H

# include "luatex-common.h"

# define token_list    0
# define null          0
# define cs_token_flag 0x1FFFFFFF

# define left_brace_token  0x0200000 /*tex $2^{21}\cdot|left_brace|$ */
# define right_brace_token 0x0400000 /*tex $2^{21}\cdot|right_brace|$ */
# define left_brace_limit  0x0400000 /*tex $2^{21}\cdot(|left_brace|+1)$ */
# define right_brace_limit 0x0600000 /*tex $2^{21}\cdot(|right_brace|+1)$ */
# define math_shift_token  0x0600000 /*tex $2^{21}\cdot|math_shift|$ */
# define tab_token         0x0800000 /*tex $2^{21}\cdot|tab_mark|$ */
# define out_param_token   0x0A00000 /*tex $2^{21}\cdot|out_param|$ */
# define space_token       0x1400020 /*tex $2^{21}\cdot|spacer|+|" "|$ */
# define letter_token      0x1600000 /*tex $2^{21}\cdot|letter|$ */
# define other_token       0x1800000 /*tex $2^{21}\cdot|other_char|$ */
# define match_token       0x1A00000 /*tex $2^{21}\cdot|match|$ */
# define end_match_token   0x1C00000 /*tex $2^{21}\cdot|end_match|$ */
# define protected_token   0x1C00001
/*define protected_token   0x1D00000 */ /* also works and is maybe nicer */

typedef struct fixed_memory_state_info {
    smemory_word * fixmem; /* * volatile fixmem; */
    unsigned fix_mem_min;
    unsigned fix_mem_max;
    unsigned fix_mem_end; /*tex The last one-word node used in |mem|. */
    halfword avail;
    int dyn_used;
    int fix_mem_init;
} fixed_memory_state_info;

extern fixed_memory_state_info fixed_memory_state;

# define just_open 1 /*tex newly opened, first line not yet read */
# define closed    2 /*tex not open, or at end of file */

typedef struct token_data_info {
    halfword temp_token_head; /*tex head of a temporary list of some kind */
    halfword hold_token_head; /*tex head of a temporary list of another kind */
    halfword omit_template;   /*tex a constant token list */
    halfword null_list;       /*tex permanently empty list */
    halfword backup_head;     /*tex head of token list built by |scan_keyword| */
    int in_lua_escape;
    FILE *read_file[16];
    int read_open[17];
    int force_eof;
    int luacstrings;
    /* maybe not in here */
    halfword par_loc;
    halfword par_token;
} token_data_info;

extern token_data_info token_data;

# define temp_token_head token_data.temp_token_head
# define hold_token_head token_data.hold_token_head
# define omit_template   token_data.omit_template
# define null_list       token_data.null_list
# define backup_head     token_data.backup_head
# define in_lua_escape   token_data.in_lua_escape
# define force_eof       token_data.force_eof
# define luacstrings     token_data.luacstrings
# define par_loc         token_data.par_loc
# define par_token       token_data.par_token
# define read_file       token_data.read_file
# define read_open       token_data.read_open

extern void initialize_tokens(void);

# define token_info(a)       fixed_memory_state.fixmem[(a)].hhlh
# define token_link(a)       fixed_memory_state.fixmem[(a)].hhrh
# define set_token_info(a,b) fixed_memory_state.fixmem[(a)].hhlh=(b)
# define set_token_link(a,b) fixed_memory_state.fixmem[(a)].hhrh=(b)

/*tex The head of the list of available one-word nodes: */

extern halfword get_avail(void);

/*tex

    A one-word node is recycled by calling |free_avail|. This routine is part of
    \TEX's \quotation {inner loop}, so we want it to be fast.

*/

# define free_avail(A) do { \
    token_link(A) = fixed_memory_state.avail; \
    fixed_memory_state.avail = (A); \
    decr(fixed_memory_state.dyn_used); \
} while (0)

/*tex

    There's also a |fast_get_avail| routine, which saves the procedure-call
    overhead at the expense of extra programming. This routine is used in
    the places that would otherwise account for the most calls of |get_avail|.

*/

# define fast_get_avail(A) do { \
    if (fixed_memory_state.avail) { \
        (A) = fixed_memory_state.avail; \
        fixed_memory_state.avail = token_link((A)); \
        token_link((A)) = null; \
        incr(fixed_memory_state.dyn_used); \
    } else { \
        (A) = get_avail(); \
    } \
} while (0)

extern void print_meaning(void);
extern void flush_list(halfword p);
extern void show_token_list(int p, int q, int l);
extern void token_show(halfword p);

/*tex Reference count preceding a token list: */

# define token_ref_count(a)       token_info((a))
# define set_token_ref_count(a,b) token_info((a))=b

/*tex A new reference to a token list: */

# define add_token_ref(a) \
    token_ref_count(a)++

/*tex We can both take the fast route as it makes little difference in binary size. */

# define store_new_token(a) do { \
    q = get_avail(); \
    token_link(p) = q; \
    token_info(q) = (a); \
    p = q; \
} while (0)

# define fast_store_new_token(a) do { \
    fast_get_avail(q); \
    token_link(p) = q; \
    token_info(q) = (a); \
    p = q;\
} while (0)

extern void delete_token_ref(halfword p);

extern void make_token_table(lua_State * L, int cmd, int chr, int cs);

# define DEFAULT_CAT_TABLE -1
# define NO_CAT_TABLE      -2

extern void get_next(void);
extern void check_outer_validity(void);
extern int scan_keyword(const char *);
extern int scan_keyword_case_sensitive(const char *);
extern halfword active_to_cs(int, int);
void get_token_lua(void);
extern halfword string_to_toks(const char *);
extern int get_char_cat_code(int);
extern void get_token(void);

/*
# define get_token() { \
    no_new_control_sequence = 0; \
    get_next(); \
    no_new_control_sequence = 1; \
    if (cur_cs == 0) \
        cur_tok = token_val(cur_cmd, cur_chr); \
    else \
        cur_tok = cs_token_flag + cur_cs; \
}
*/

/*tex

    The |no_expand_flag| is a special character value that is inserted by
    |get_next| if it wants to suppress expansion.

*/

# define no_expand_flag special_char

extern void firm_up_the_line(void);

extern halfword str_toks(lstring b);
extern halfword str_scan_toks(int c, lstring b);
extern void ins_the_toks(void);
extern void combine_the_toks(int how);

extern void conv_toks(void);
extern str_number the_convert_string(halfword c, int i);

extern halfword lua_str_toks(lstring b);

extern void initialize_read(void);

extern void read_toks(int n, halfword r, halfword j);

/*tex Return a string from tokens list: */

extern str_number tokens_to_string(halfword p);

extern char *tokenlist_to_xstring(int p, int inhibit_par, int *siz);
extern char *tokenlist_to_cstring(int p, int inhibit_par, int *siz);
extern char *tokenlist_to_tstring(int p, int inhibit_par, int *siz); /* experiment, less mallocs */

# define token_cmd(A)    ((A) >>  STRING_OFFSET_BITS)
# define token_chr(A)    ((A) &  (STRING_OFFSET - 1))
# define token_val(A,B) (((A) <<  STRING_OFFSET_BITS) + (B))

extern void l_set_token_data(void) ;

# endif
