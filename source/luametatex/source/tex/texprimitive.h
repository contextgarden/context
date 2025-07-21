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
    tex_command        = 0x01,
    etex_command       = 0x02,
    luatex_command     = 0x04,
    luametatex_command = 0x08,
    no_command         = 0x10
} command_origin;

/*tex 

    Take |\fontdimen| which makes no sense any more. We can just replace it and for old times 
    sake handle it but a macro package can then block it. Or all the display math related 
    features that we don't use in \CONTEXT: we can optionally wipe them runtime. Commands like
    |\accent| make no sense any more. The same is true for the old school math font and pre 
    \UNICODE\ definitions and commands. The array variants can replace the singular ones. The \
    ignored ones are just \unknown\ ignored. 

*/

typedef enum command_legacy {
    no_legacy       = 0x00,
    /* these can be disabled (low level token blocked to) */
    text_legacy     = 0x01, /* makes no sense in new fonts   : accent             */
    math_legacy     = 0x02, /* sort of limited to eight bit  : left delimiter     */
    /* these are just tags (for manuals etc) */
    callback_legacy = 0x04, /* not implemented, callback      : font shipout       */
    ignored_legacy  = 0x08, /* doesn't do anything any more   : outer long         */
    /* but we can actually consider disabling these if we want */
    single_legacy   = 0x10, /* replaced by more advanced      : mark widowpenalty  */
    display_legacy  = 0x20, /* display math features          : a lot              */
    aliased_legacy  = 0x40, /* just handy for various reasons : notexpanded         */
} command_legacy;

typedef struct hash_state_info {
    memoryword   *hash;       /*tex The hash table. */
    memory_data   hash_data;
    memoryword   *eqtb;       /*tex The equivalents table. */
    memory_data   eqtb_data;
    int           no_new_cs;  /*tex Are new identifiers legal? */
    int           padding;
    unsigned char destructors[number_tex_commands]; 
} hash_state_info ;

extern hash_state_info lmt_hash_state;

/*tex

    We use no defines as a |hash| macro will clash with lua hash. Most hash accessors are in a few
    places where it makes sense to be explicit anyway.

    The only reason why we have a dedicated primitive hash is because we can selectively enable 
    them but at some point we might just always do that. There is never a runtiem lookup (asuming 
    a format). It also gives is access to some primitive metadata. 

*/

# define cs_next(a) lmt_hash_state.hash[(a)].half0 /*tex link for coalesced lists */
# define cs_text(a) lmt_hash_state.hash[(a)].half1 /*tex string number for control sequence name */

# define undefined_primitive    0
# define prim_size           2100 /*tex maximum number of primitives (quite a bit more than needed) */
# define prim_prime          1777 /*tex about 85 percent of |primitive_size| */

typedef enum primitive_permissions {
    primitive_permitted = 0x00,
    primitive_inhibited = 0x01,
    primitive_permanent = 0x02,
    primitive_warned    = 0x04,
} primitive_permissions;

typedef struct primitive_info {
    halfword       subids;      /*tex number of name entries */
    halfword       offset;      /*tex offset to be used for |chr_code|s */
    strnumber     *names;       /*tex array of names */
    unsigned char *permissions; /*tex array of bitsets */
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
//define prim_origin(a)      lmt_primitive_state.prim_eqtb[(a)].quart01 
# define prim_origin(a)      lmt_primitive_state.prim_eqtb[(a)].single02
# define prim_legacy(a)      lmt_primitive_state.prim_eqtb[(a)].single03

# define prim_eq_type(a)     lmt_primitive_state.prim_eqtb[(a)].quart00  /*tex Command code for equivalent. */
# define prim_equiv(a)       lmt_primitive_state.prim_eqtb[(a)].half1    /*tex Equivalent value. */

# define get_prim_eq_type(p) prim_eq_type(p)
# define get_prim_equiv(p)   prim_equiv(p)
# define get_prim_text(p)    prim_text(p)
# define get_prim_origin(p)  prim_origin(p)
# define get_prim_legacy(p)  prim_legacy(p)

extern void      tex_initialize_primitives (void);
extern void      tex_initialize_hash_mem   (void);
/*     int       tex_room_in_hash          (void); */
extern halfword  tex_primitive_lookup      (strnumber s);
/*     int       tex_cs_is_primitive       (strnumber csname); */
extern void      tex_primitive             (int origin, int legacy, const char *ss, singleword cmd, halfword chr, halfword offset);
extern void      tex_primitive_def         (const char *str, size_t length, singleword cmd, halfword chr);
extern void      tex_print_cmd_chr         (singleword cmd, halfword chr);
extern void      tex_dump_primitives       (dumpstream f);
extern void      tex_undump_primitives     (dumpstream f);
extern void      tex_dump_hashtable        (dumpstream f);
extern void      tex_undump_hashtable      (dumpstream f);
/*     halfword  tex_string_lookup         (const char *s, size_t l); */
extern halfword  tex_string_locate         (const char *s, size_t l, int create);
extern halfword  tex_string_locate_only    (const char *s, size_t l);
extern halfword  tex_located_string        (const char *s);
/*     halfword  tex_id_lookup             (int j, int l); */
extern halfword  tex_id_locate             (int j, int l, int create);
extern halfword  tex_id_locate_only        (int j, int l);
extern int       tex_id_locate_steps       (const char *s);
extern void      tex_print_cmd_flags       (halfword cs, halfword cmd, int flags, int escape);
extern int       tex_primitive_found       (const char *name, halfword *cmd, halfword *chr);
extern int       tex_inhibit_primitive     (halfword cmd, halfword chr, int permanent);
extern strnumber tex_primitive_name        (halfword cmd, halfword ch);

# endif
