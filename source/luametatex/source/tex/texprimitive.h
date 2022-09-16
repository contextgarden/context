/*
    See license.txt in the root of this project.
*/

# ifndef LMT_PRIMITIVE_H
# define LMT_PRIMITIVE_H

/*tex

    This is a list of origins for primitive commands. The engine starts out with hardly anything
    enabled so as a first step one should enable the \TEX\ primitives, and additional \ETEX\ and
    \LUATEX\ primitives. Maybe at some moment we should just enable all by default.

*/

typedef enum command_origin {
    tex_command    = 1,
    etex_command   = 2,
    luatex_command = 4,
    no_command     = 8,
} command_origin;

typedef struct hash_state_info {
    memoryword  *hash;       /*tex The hash table. */
    memory_data  hash_data;
    memoryword  *eqtb;       /*tex The equivalents table. */
    memory_data  eqtb_data;
    int          no_new_cs;  /*tex Are new identifiers legal? */
    int          padding;
} hash_state_info ;

extern hash_state_info lmt_hash_state;

/*tex

    We use no defines as a |hash| macro will clash with lua hash. Most hash accessors are in a few
    places where it makes sense to be explicit anyway.

*/

# define cs_next(a) lmt_hash_state.hash[(a)].half0 /*tex link for coalesced lists */
# define cs_text(a) lmt_hash_state.hash[(a)].half1 /*tex string number for control sequence name */

# define undefined_primitive    0
# define prim_size           2100 /*tex (can be 1000) maximum number of primitives (quite a bit more than needed) */
# define prim_prime          1777 /*tex (can be  853) about 85 percent of |primitive_size| */

typedef struct primitive_info {
    halfword   subids; /*tex number of name entries */
    halfword   offset; /*tex offset to be used for |chr_code|s */
    strnumber *names;  /*tex array of names */
} prim_info;

typedef struct primitive_state_info {
    memoryword prim[prim_size + 1];
    memoryword prim_eqtb[prim_size + 1];
    prim_info  prim_data[last_cmd + 1];
    halfword   prim_used;
    /* alignment */
    int        padding;
} primitive_state_info;

extern primitive_state_info lmt_primitive_state;

# define prim_next(a)        lmt_primitive_state.prim[(a)].half0         /*tex Link for coalesced lists. */
# define prim_text(a)        lmt_primitive_state.prim[(a)].half1         /*tex String number for control sequence name. */
# define prim_origin(a)      lmt_primitive_state.prim_eqtb[(a)].quart01  /*tex Level of definition. */
# define prim_eq_type(a)     lmt_primitive_state.prim_eqtb[(a)].quart00  /*tex Command code for equivalent. */
# define prim_equiv(a)       lmt_primitive_state.prim_eqtb[(a)].half1    /*tex Equivalent value. */

# define get_prim_eq_type(p) prim_eq_type(p)
# define get_prim_equiv(p)   prim_equiv(p)
# define get_prim_text(p)    prim_text(p)
# define get_prim_origin(p)  prim_origin(p)

extern void     tex_initialize_primitives (void);
extern void     tex_initialize_hash_mem   (void);
/*     int      tex_room_in_hash          (void); */
extern halfword tex_prim_lookup           (strnumber s);
/*     int      tex_cs_is_primitive       (strnumber csname); */
extern void     tex_primitive             (int cmd_origin, const char *ss, singleword cmd, halfword chr, halfword offset);
extern void     tex_primitive_def         (const char *str, size_t length, singleword cmd, halfword chr);
extern void     tex_print_cmd_chr         (singleword cmd, halfword chr);
extern void     tex_dump_primitives       (dumpstream f);
extern void     tex_undump_primitives     (dumpstream f);
extern void     tex_dump_hashtable        (dumpstream f);
extern void     tex_undump_hashtable      (dumpstream f);
/*     halfword tex_string_lookup         (const char *s, size_t l); */
extern halfword tex_string_locate         (const char *s, size_t l, int create);
extern halfword tex_located_string        (const char *s);
/*     halfword tex_id_lookup             (int j, int l); */
extern halfword tex_id_locate             (int j, int l, int create);
extern void     tex_print_cmd_flags       (halfword cs, halfword cmd, int flags, int escape);

# endif
