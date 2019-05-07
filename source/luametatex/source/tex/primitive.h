/*
    See license.txt in the root of this project.
*/

# ifndef LUATEX_PRIMITIVE_H
# define LUATEX_PRIMITIVE_H 1

/*tex

    This is a list of origins for primitive commands. The engine starts out with
    hardly anything enabled so as a first step one should enable the \TEX\
    primitives, and additional \ETEX\ and \LUATEX\ primitives. Maybe at some
    moment we should just enable all by default.

*/

typedef enum {
    tex_command    =  1,
    etex_command   =  2,
    luatex_command =  4,
    core_command   =  8,
    no_command     = 16,
} command_origin;

# define hash_size  65536               /*tex maximum number of control sequences; it should be at most about |(fix_mem_max-fix_mem_min)/10| */
# define hash_prime 55711               /*tex a prime number equal to about 85 percent of |hash_size| */

/* maybe: */

/* # define hash_size  131072 */
/* # define hash_prime 111411 */

typedef struct hash_state_info {
    two_halves *hash;                /*tex the hash table */
    halfword hash_used;              /*tex allocation pointer for |hash| */
    int hash_extra;                  /*tex |hash_extra=hash| above |eqtb_size| */
    halfword hash_top;               /*tex maximum of the hash array */
    halfword hash_high;              /*tex pointer to next high hash location */
    int no_new_control_sequence;     /*tex are new identifiers legal? */
    int cs_count;                    /*tex total number of known identifiers */
} hash_state_info ;

extern hash_state_info hash_state;

/*tex

    We use no defines as a |hash| macro will clash with lua hash. Most hash accerssors
    are in a few places where it makes sense to be explicit anyway.

*/

# define no_new_control_sequence hash_state.no_new_control_sequence

# define cs_next(a) hash_state.hash[(a)].lhfield   /*tex link for coalesced lists */
# define cs_text(a) hash_state.hash[(a)].rhfield   /*tex string number for control sequence name */

# define undefined_primitive 0
# define prim_size  2100                /*tex maximum number of primitives (quite a bit more than needed) */
# define prim_prime 1777                /*tex about 85 percent of |primitive_size| */

typedef struct prim_info {
    halfword subids;    /*tex number of name entries */
    halfword offset;    /*tex offset to be used for |chr_code|s */
    str_number *names;  /*tex array of names */
} prim_info;

typedef struct prim_state_info {
    halfword prim_used;
    two_halves prim[(prim_size + 1)];
    memory_word prim_eqtb[(prim_size + 1)];
    prim_info prim_data[(last_cmd + 1)];
} prim_state_info;

extern prim_state_info prim_state;

# define prim_used prim_state.prim_used
# define prim      prim_state.prim
# define prim_eqtb prim_state.prim_eqtb
# define prim_data prim_state.prim_data

# define prim_next(a) prim[(a)].lhfield                     /*tex Link for coalesced lists: */
# define prim_text(a) prim[(a)].rhfield                     /*tex String number for control sequence name: */
# define prim_is_full (prim_used==prim_base)                /*tex Test if all positions are occupied: */
# define prim_origin_field(a) (a).hh.b1
# define prim_eq_type_field(a)  (a).hh.b0
# define prim_equiv_field(a) (a).hh.rhfield
# define prim_origin(a) prim_origin_field(prim_eqtb[(a)])   /*tex Level of definition: */
# define prim_eq_type(a) prim_eq_type_field(prim_eqtb[(a)]) /*tex Command code for equivalent: */
# define prim_equiv(a) prim_equiv_field(prim_eqtb[(a)])     /*tex Equivalent value: */

extern void init_primitives(void);
extern void ini_init_primitives(void);
extern halfword prim_lookup(str_number s);
extern int is_primitive(str_number csname);

/* These can actually be macros. */

// extern quarterword get_prim_eq_type(int p);
// extern halfword get_prim_equiv(int p);
// extern str_number get_prim_text(int p);
// extern quarterword get_prim_origin(int p);

# define get_prim_eq_type(p) prim_eq_type(p)
# define get_prim_equiv(p)   prim_equiv(p)
# define get_prim_text(p)    prim_text(p)
# define get_prim_origin(p)  prim_origin(p)

extern void dump_primitives(void);
extern void undump_primitives(void);

# define primitive_tex(a,b,c,d)    primitive((a),(b),(c),(d),tex_command)
# define primitive_etex(a,b,c,d)   primitive((a),(b),(c),(d),etex_command)
# define primitive_luatex(a,b,c,d) primitive((a),(b),(c),(d),luatex_command)
# define primitive_core(a,b,c,d)   primitive((a),(b),(c),(d),core_command)
# define primitive_no(a,b,c,d)     primitive((a),(b),(c),(d),no_command)

extern void primitive(const char *ss, quarterword c, halfword o, halfword off, int cmd_origin);
extern void primitive_def(const char *s, size_t l, quarterword c, halfword o);
extern void print_cmd_chr(quarterword cmd, halfword chr_code);

extern halfword string_lookup(const char *s, size_t l);
extern halfword id_lookup(int j, int l);

# endif
