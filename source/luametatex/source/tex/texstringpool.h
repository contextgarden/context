/*
    See license.txt in the root of this project.
*/

# ifndef LMT_STRINGPOOL_H
# define LMT_STRINGPOOL_H

/*tex

    Both \LUA\ and |TEX\ strings can contain |nul| characters, but \CCODE\ strings cannot. The pool
    is implemented differently anyway. The |init_str_ptr| is an offset that indicates how many strings
    are in the format. Does it still make sense to have that distinction? Do we care?

    We store the used bytes (in strings) in the |real| field so that it is carried with the data blob
    (and ends up in statistics).

*/

typedef struct lstring {
    union {
        unsigned char *s;
        const    char *c;
    };
    size_t         l; /* could be int, but this way we padd */
} lstring;

typedef struct string_pool_info {
    lstring       *string_pool;
    memory_data    string_pool_data;
    memory_data    string_body_data;
    strnumber      reserved;
    /*tex only when format is made and loaded */
    int            string_max_length;
    /*tex used for temporary string building: */
    unsigned char *string_temp;
    int            string_temp_allocated;
    int            string_temp_top;
} string_pool_info;

extern string_pool_info lmt_string_pool_state;

# define STRING_EXTRA_AMOUNT 512

/*tex This is the reference of the empty string: */

# define get_nullstr() cs_offset_value

/*tex

    Several of the elementary string operations are performed using macros instead of procedures,
    because many of the operations are done quite frequently and we want to avoid the overhead of
    procedure calls. For example, here is a simple macro that computes the length of a string.

    Keep in mind that we are talking of a |string_pool| table that officially starts with the
    unicode characters (as in \TEX\ with \ASCII) but that we use an offset to jump ove that. So the
    real size doesn't include those single character code points.

*/

# define str_length(a)  (lmt_string_pool_state.string_pool[(a) - cs_offset_value].l)
# define str_string(a)  (lmt_string_pool_state.string_pool[(a) - cs_offset_value].s)
# define str_lstring(a) (lmt_string_pool_state.string_pool[(a) - cs_offset_value])

/*tex

    Strings are created by appending character codes to |str_pool|. The |append_char| macro,
    defined here, does not check to see if the value of |pool_ptr| has gotten too high; this test
    is supposed to be made before |append_char| is used. There is also a |flush_char| macro, which
    erases the last character appended.

    To test if there is room to append |l| more characters to |str_pool|, we shall write |str_room
    (l)|, which aborts \TEX\ and gives an apologetic error message if there isn't enough room. The
    length of the current string is called |cur_length|.

*/

/*tex Forget the last character in the pool. */

inline void        tex_flush_char(void)       { --lmt_string_pool_state.string_temp_top; }

extern strnumber   tex_make_string            (void);
extern strnumber   tex_push_string            (const unsigned char *s, int l);
extern char       *tex_take_string            (int *len);
extern int         tex_str_eq_buf             (strnumber s, int k, int n);
extern int         tex_str_eq_str             (strnumber s, strnumber t);
extern int         tex_str_eq_cstr            (strnumber s, const char *, size_t);
extern int         tex_get_strings_started    (void);
extern void        tex_reset_cur_string       (void);
/*     strnumber   tex_search_string          (strnumber search); */
/*     int         tex_used_strings           (void); */
extern strnumber   tex_maketexstring          (const char *s);
extern strnumber   tex_maketexlstring         (const char *s, size_t);
extern void        tex_append_char            (unsigned char c);
extern void        tex_append_string          (const unsigned char *s, unsigned l);
extern char       *tex_makecstring            (int s);
extern char       *tex_makeclstring           (int s, size_t *len);
extern void        tex_dump_string_pool       (dumpstream f);
extern void        tex_undump_string_pool     (dumpstream f);
extern void        tex_initialize_string_pool (void);
extern void        tex_initialize_string_mem  (void);
extern void        tex_flush_str              (strnumber s);
extern strnumber   tex_save_cur_string        (void);
extern void        tex_restore_cur_string     (strnumber u);

/*     void        tex_increment_pool_string  (int n); */
/*     void        tex_decrement_pool_string  (int n); */

extern void        tex_compact_string_pool    (void);

# endif
