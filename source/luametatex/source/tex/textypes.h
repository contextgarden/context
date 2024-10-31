/*
    See license.txt in the root of this project.
*/

# ifndef LMT_TEXTYPES_H
# define LMT_TEXTYPES_H

# include <stdio.h>

# define LMT_TOSTRING_INDEED(s) #s
# define LMT_TOSTRING(s) LMT_TOSTRING_INDEED(s)

/*tex

    Here is the comment from the engine(s) that we started with. Keep in mind that \TEX\ originates
    on other architectures and that it was written in \PASCAL.

    In order to make efficient use of storage space, \TEX\ bases its major data structures on a
    |memoryword|, which contains either a (signed) integer, possibly scaled, or a (signed)
    |glue_ratio|, or a small number of fields that are one half or one quarter of the size used for
    storing integers. More details about how we pack data in a memory word can be found in the
    |memoryword| files.

    If |x| is a variable of type |memoryword|, it contains up to four fields that can be referred
    to as follows (\LUATEX\ differs a bit here but the principles remain):

    \starttabulate
        \NC |x.int|                           \NC an |integer|            \NC \NR
        \NC |x.sc |                           \NC a |scaled| integer      \NC \NR
        \NC |x.gr|                            \NC a |glueratio|           \NC \NR
        \NC |x.hh.lh|, |x.hh.rh|              \NC two halfword fields)    \NC \NR
        \NC |x.hh.b0|, |x.hh.b1|              \NC two quarterword fields  \NC \NR
        \NC |x.qqqq.b0| \unknown\ |x.qqqq.b3| \NC four quarterword fields \NC \NR
    \stoptabulate

    This is somewhat cumbersome to write, and not very readable either, but macros will be used to
    make the notation shorter and more transparent. The |memoryword| file gives a formal definition
    of |memoryword| and its subsidiary types, using packed variant records. \TEX\ makes no
    assumptions about the relative positions of the fields within a word.

    We are assuming 32-bit integers, a halfword must contain at least 32 bits, and a quarterword
    must contain at least 16 bits.

    The present implementation tries to accommodate as many variations as possible, so it makes few
    assumptions. If integers having the subrange |min_quarterword .. max_quarterword| can be packed
    into a quarterword, and if integers having the subrange |min_halfword .. max_halfword| can be
    packed into a halfword, everything should work satisfactorily.

    It is usually most efficient to have |min_quarterword = min_halfword = 0|, so one should try to
    achieve this unless it causes a severe problem. The values defined here are recommended for most
    32-bit computers.

    We cannot use the full range of 32 bits in a halfword, because we have to allow negative values
    for potential backend tricks like web2c's dynamic allocation, and parshapes pointers have to be
    able to store at least twice the value |max_halfword| (see below). Therefore, |max_halfword| is
    $2^{30}-1$

    Via the intermediate step if \WEBC\ we went from \PASCAL\ to \CCODE. As in the meantime we also
    live in a 64 bit world the above model has been adapted a bit but the principles and names remain.

    A |halfword| is a 32 bit integer and a |quarterword| a 16 bit one. The |scaled| type is used for
    scaled integers but it's just another name for |halfword| or |int|. The code sometimes uses an
    |int| instead of |scaled| or |halfword| (which might get fixed). By using the old type names we
    sort of get an indication what we're dealing with.

    If we even bump scaled to 64 bit we need to redo some code that now assumes that a scaled and
    halfword are the same size (as in values). Instead we can then decide to go 64 bit for both.

    The |internal_font_number| type is now also a |halfword| so it's no longer used as such.

    We now use 64 memory words split into whatever pieces we need. This also means that we can use
    a double as glueratio which us saves some casting.

    In principle we can widen up the engine to use long instead of int because it is relatively easy 
    to adapt the nodes but it will take much more memory and we gain nothing. I might (re)introduce 
    the pointer as type instead of halfword just for clarity but the mixed usage doesn't really make 
    ot better. It's more about perception. I will do that when I have reason to check some code and 
    are in edit mode. 

*/

typedef int             strnumber;
typedef int             halfword;
typedef long long       fullword;
typedef unsigned short  quarterword;   /*tex It really is an unsigned one! But \MPLIB| had it signed. */
typedef unsigned char   singleword;
typedef int             scaled;
typedef double          glueratio;     /*tex This looks better in our (tex specific) syntax highlighting. */
typedef int             pointer;       /*tex Maybe I'll replace halfwords that act as pointer some day. */
typedef FILE           *dumpstream;

/*      glueratio       glue_ratio; */ /*tex one-word representation of a glue expansion factor */
/*      unsigned char   glue_ord;   */ /*tex infinity to the 0, 1, 2, 3, or 4 power */
/*      unsigned short  group_code; */ /*tex |save_level| for a level boundary */

/*tex

    The documentation refers to pointers and halfwords and scaled and all are in fact just integers.
    Okay, one can wonder about negative pointers but we never reach the limits so we're okay wrr
    wraparound. At some point we might just replace all by int as some of the helpers already do
    that. For now we keep halfword and scaled but we removed (the not so often used) pointers
    because they were already mixed with halfwords in similar usage.

    So, again we use constants that reflect the original naming and also the related comments.

    Here are some more constants. Others definitions can be font alongside where they make most
    sense. For instance, these are used all over the place: |null|, |normal|, etc. However, over
    time, with all these extensions it was not used consistently. So, I replaced the usage of
    |normal| by more explicit identifiers, also because we have more subtypes in this engine. But
    we kept most constants (but most in enums)!

    Characters of text that have been converted to \TEX's internal form are said to be of type
    |unsigned char|, which is a subrange of the integers. We are assuming that our runtime system
    is able to read and write \UTF-8.

    If constants in this file change, one also must change the format identifier!

*/

typedef struct scaledwhd {
    scaled wd;
    scaled ht;
    scaled dp;
    union { 
        scaled ic; /* padding anyway */
        scaled ns; /* natural size */
    };
} scaledwhd;

typedef struct scaledkrn {
    scaled bl;
    scaled br;
    scaled tl;
    scaled tr;
} scaledkrn;

extern halfword tex_badness(
    scaled t,
    scaled s
);

/*tex
    We could use the 4 leftmost bits in tokens for [protected frozen tolerant permanent] flags but
    it would mean way more shifting and checking so we don't to that. However, we already use
    one nibble for the cstokenflag: 0x1FFFFFFF so we actually have no room. We also have a signed
    unsigned issue because halfwords are integers so quite a bit needs to be adapted if we use all
    32 bits. We have between 128 and 256 cmd codes so we need one byte for that. We also have to
    deal with the max utf / unicode values.
*/

# define cs_offset_bits                            21
# define cs_offset_value                   0x00200000  // ((1 << STRING_OFFSET_BITS) - 1)
# define cs_offset_max                     0x001FFFFF
# define cs_token_flag                     0x1FFFFFFF

# define max_cardinal                      0xFFFFFFFF
# define min_cardinal                               0
# define max_integer                       0x7FFFFFFF /*tex aka |infinity| */
# define min_integer                      -0x7FFFFFFF /*tex aka |min_infinity| */
# define max_posit                       max_cardinal 
# define min_posit                       min_cardinal 
# define max_dimension                     0x3FFFFFFF
# define min_dimension                    -0x3FFFFFFF
# define max_dimen                      max_dimension
# define min_dimen                      min_dimension
# define min_data_value                             0
# define max_data_value                 cs_offset_max
# define max_half_value                         32767 /*tex For instance sf codes.*/

# define one_bp                                 65781

# define max_infinity                      0x7FFFFFFF /*tex the largest positive value that \TEX\ knows */
# define min_infinity                     -0x7FFFFFFF
# define awful_bad                         0x3FFFFFFF /*tex more than a billion demerits |07777777777| */ 
# define infinite_bad                           10000 /*tex infinitely bad value */
# define infinite_penalty                infinite_bad /*tex infinite penalty value */
# define eject_penalty              -infinite_penalty /*tex negatively infinite penalty value */
# define final_penalty                    -0x40000000 /*tex in the output routine */
# define deplorable                            100000 /*tex more than |inf_bad|, but less than |awful_bad| */
# define extremely_deplorable               100000000
# define large_width_excess                   7230584
# define small_stretchability                 1663497
# define loose_criterion                           99 
# define decent_criterion                          12 
# define tight_criterion                           12 /* same as |decent_criterion| */
# define max_calculated_badness                  8189
# define emergency_adj_demerits                 10000

# define default_rule                           26214 /*tex 0.4pt */
# define ignore_depth                       -65536000 /*tex The magic dimension value to mean \quote {ignore me}: -1000pt */

# define min_quarterword                            0 /*tex The smallest allowable value in a |quarterword|. */
# define max_quarterword                        65535 /*tex The largest allowable value in a |quarterword|. */

# define min_halfword                     -0x3FFFFFFF /*tex The smallest allowable value in a |halfword|. */
# define max_halfword                      0x3FFFFFFF /*tex The largest allowable value in a |halfword|. */

# define null_flag                        -0x40000000
# define zero_glue                                  0
# define unity                                0x10000 /*tex |0200000| or $2^{16}$, represents 1.00000 */
# define two                                  0x20000 /*tex |0400000| or $2^{17}$, represents 2.00000 */
# define null                                       0
# define null_font                                  0

# define unused_attribute_value           -0x7FFFFFFF /*tex as low as it goes */
# define unused_state_value                         0 /*tex 0 .. 0xFFFF */
# define unused_script_value                        0 /*tex 0 .. 0xFFFF */
# define unused_scale_value                      1000

# define unused_math_style                       0xFF
# define unused_math_family                      0xFF

# define preset_rule_thickness             0x40000000 /*tex denotes |unset_rule_thickness|: |010000000000|. */

# define min_space_factor                           0 /*tex watch out: |\spacefactor| cannot be zero but the sf code can!*/
# define max_space_factor                      0x7FFF /*tex |077777| */
# define min_scale_factor                           0 
# define max_scale_factor                      100000 /*tex for now */
# define default_space_factor                    1000
# define space_factor_threshold                  2000
# define default_tolerance                      10000
# define default_hangafter                          1
# define default_deadcycles                        25
# define default_pre_display_gap                 2000
# define default_eqno_gap_step                   1000

# define default_output_box                       255

# define scaling_factor                          1000
# define scaling_factor_squared               1000000
# define scaling_factor_double                   1000.0
//define scaling_multiplier_double               0.001

# define max_math_scaling_factor                 5000

# define max_font_adjust_step                     100
# define max_font_adjust_stretch_factor          1000
# define max_font_adjust_shrink_factor            500

# define math_default_penalty    (infinite_penalty+1)

# define initial_alignment_state             -1000000
# define busy_alignment_state                 1000000
# define interwoven_alignment_threshold        500000

/*tex

    For practical reasons all these registers were max'd to 64K but that really makes no sense for
    e.g. glue and mu glue and even attributes. Imagine using more than 8K attributes: we get long
    linked lists, slow lookup, lots of copying, need plenty node memory. These large ranges also
    demand more memory as we need these eqtb entries. So, when I was pondering specific ex and em
    glue (behaving like mu glue in math) I realized that we can do that at no cost at all: we just
    make some register ranges smaller. Keep in mind that we already have cheap integer, dimension,
    and glue shortcuts that can be used instead of registers for storing constant values.

    large  : 7 * 64                           = 448   3.584 Kb
    medium : 4 * 64 + 2 * 32 + 1 * 16         = 336   2.688 Kb
    small  :          4 * 32          + 3 * 8 = 152   1.216 Kb

    The memory saving is not that large but keep in mind that we have these huge eqtb arrays and
    registers are accessed frequently so the more we have in the CPU cache the better. (We already
    use less than in \LUATEX\ because we got rid of some parallel array so there it would have more
    impact).

    At some point we might actually drop these maxima indeed as we really don't need that many 
    if these registers and if (say) 16K is not enough, then nothing is. 

*/

# if 1

    # define max_toks_register_index      0xFFFF /* 0xFFFF 0xFFFF 0x7FFF */ /* 64 64 32 */
    # define max_box_register_index       0xFFFF /* 0xFFFF 0xFFFF 0x7FFF */ /* 64 64 32 */
    # define max_integer_register_index   0xFFFF /* 0xFFFF 0xFFFF 0x3FFF */ /* 64 64 16 */
    # define max_dimension_register_index 0xFFFF /* 0xFFFF 0xFFFF 0x3FFF */ /* 64 64 16 */
    # define max_posit_register_index     0xFFFF /* 0xFFFF 0x7FFF 0x1FFF */ /* 64 32  8 */
    # define max_attribute_register_index 0xFFFF /* 0xFFFF 0x7FFF 0x1FFF */ /* 64 32  8 */
    # define max_glue_register_index      0xFFFF /* 0xFFFF 0x7FFF 0x1FFF */ /* 64 32  8 */
    # define max_muglue_register_index    0xFFFF /* 0xFFFF 0x3FFF 0x1FFF */ /* 64 16  8 */

# else

    # define max_toks_register_index      0x1FFF //  8K
    # define max_box_register_index       0x7FFF // 32K /* less of we use a lua stack */
    # define max_integer_register_index   0x1FFF //  8k
    # define max_dimension_register_index 0x1FFF //  8k  
    # define max_posit_register_index     0x1FFF //  8k 
    # define max_attribute_register_index 0x1FFF //  8k 
    # define max_glue_register_index      0x0FFF //  4k 
    # define max_muglue_register_index    0x0FFF //  4k 

# endif

# define max_unit_register_index       26*26

# define max_n_of_toks_registers      (max_toks_register_index      + 1)
# define max_n_of_box_registers       (max_box_register_index       + 1)
# define max_n_of_integer_registers   (max_integer_register_index   + 1)
# define max_n_of_dimension_registers (max_dimension_register_index + 1)
# define max_n_of_attribute_registers (max_attribute_register_index + 1)
# define max_n_of_posit_registers     (max_posit_register_index     + 1)
# define max_n_of_glue_registers      (max_glue_register_index      + 1)
# define max_n_of_muglue_registers    (max_muglue_register_index    + 1)
# define max_n_of_unit_registers      (max_unit_register_index      + 1)

# define max_n_of_bytecodes                   65536 /* dynamic */
# define max_n_of_math_families                  64
# define max_n_of_math_classes                   64
# define max_n_of_catcode_tables                256
# define max_n_of_box_indices          max_halfword

# define max_character_code                0x10FFFF /*tex 1114111, the largest allowed character number; must be |< max_halfword| */
//define max_math_character_code           0x0FFFFF /*tex 1048575, for now this is plenty, otherwise we need to store differently */
# define max_math_character_code max_character_code /*tex part gets clipped when we convert to a number */
# define max_function_reference       cs_offset_max
# define min_iterator_value                -0xFFFFF /* When we decide to generalize it might become 0xFFFF0 with */
# define max_iterator_value                 0xFFFFF /* 0x0000F being a classifier so that we save cmd's          */
# define max_category_code                       15
# define max_newline_character                  127 /*tex This is an old constraint but there is no reason to change it. */
# define max_endline_character                  127 /*tex To keep it simple we stick to the maximum single UTF character. */
# define max_box_axis                           255
# define max_size_of_word                      1000 /*tex More than enough (esp. since this can end up on the stack. Includes {}{}{} exception stuff. */
# define min_limited_scale                        0 /*tex Zero is a signal too. */
# define max_limited_scale                     1000
# define min_math_style_scale                     0 /*tex Zero is a signal too. */
# define max_math_style_scale                  2000
# define max_parameter_index                     15

# define max_size_of_word_buffer (4 * max_size_of_word + 2 + 1 + 2) /* utf + two_periods + sentinal_zero + some_slack */

# define max_mark_index          (max_n_of_marks         - 1)
# define max_insert_index        (max_n_of_inserts       - 1)
# define max_box_index           (max_n_of_box_indices   - 1)
# define max_bytecode_index      (max_n_of_bytecodes     - 1)

# define max_math_family_index   (max_n_of_math_families - 1)
# define max_math_class_code     (max_n_of_math_classes  - 1)
# define max_math_property       0xFFFF
# define max_math_group          0xFFFF
# define max_math_index          max_character_code
# define max_math_discretionary  0xFF

# define max_classification_code 0xFFFF

# define ascii_space  32
# define ascii_max   127

# define default_space_factor 1000
# define special_space_factor  999

/*tex 
    We started out with 32 but it makes no sense to initialize that many every time we need to do
    that. In \CONTEXT\ we have a granular setup with nine values. The maximum practical value is 
    actually 99 and one needs step sizes that are reasonable. 
*/

# define default_fitness              0
# define min_n_of_fitness_values      5
# define max_n_of_fitness_values     15 
# define all_fitness_values        0xFF

/*tex

    This is very math specific: we used to pack info into an unsigned 32 bit integer: class, family
    and character. We now use node for that (which also opend up the possibility to store more
    info) but in case of a zero family we can also decide to use the older method of packing packing
    a number: |FF+10FFFF| but the gain (at least on \CONTEXT) is litle: around 10K so here we only
    mention it as consideration. We can consider anyway to omit the class part when we need a
    numeric representation, although we don't really need (or like) that kind of abuse.

*/

# define math_class_bits      6
# define math_family_bits     6
# define math_character_bits 20

# define math_class_part(a)     ((a >> 26) & 0x3F)
# define math_family_part(a)    ((a >> 20) & 0x3F)
# define math_character_part(a)  (a        & 0xFFFFF)

# define math_old_class_part(a)     ((a >> 12) & 0x0F)
# define math_old_family_part(a)    ((a >>  8) & 0x0F)
# define math_old_character_part(a)  (a        & 0xFF)

# define math_old_class_mask(a)     (a & 0x0F)
# define math_old_family_mask(a)    (a & 0x0F)
# define math_old_character_mask(a) (a & 0xFF)

# define math_packed_character(c,f,v)     (((c & 0x3F) << 26) + ((f & 0x3F) << 20) + (v & 0xFFFFF))
# define math_old_packed_character(c,f,v) (((c & 0x0F) << 12) + ((f & 0x0F) <<  8) + (v & 0x000FF))

# define rule_font_fam_offset 0xFFFFFF

/*tex We put these here for consistency: */

# define too_big_char (max_character_code + 1) /*tex 1114112, |biggest_char + 1| */
# define special_char (max_character_code + 2) /*tex 1114113, |biggest_char + 2| */
# define number_chars (max_character_code + 3) /*tex 1114114, |biggest_char + 3| */

/*tex

    As mentioned, because we're now in \CCODE\ we use a bit simplified memory mode. We don't do any
    byte swapping related to endian properties as we don't share formats between architectures
    anyway. A memory word is 64 bits and interpreted in several ways. So the memoryword is a bit
    different. We also use the opportunity to squeeze eight characters into the word.

    halfword    : 32 bit integer       (2)
    quarterword : 16 bit integer       (4)
    singlechar  :  8 bit unsigned char (8)
    int         : 32 bit integer       (2)
    glue        : 64 bit double        (1)

    The names below still reflect the original \TEX\ names but we have simplified the model a bit.
    Watch out: we still make |B0| and |B1| overlap |LH| which for instance is needed when a we
    store the size of a node in the type and subtype field. The same is true for the overlapping
    |CINT|s! Don't change this without also checking the macros elsewhere.

    \starttyping
    typedef union memoryword {
        struct {
            halfword H0, H1;
        } h;
        struct {
            quarterword B0, B1, B2, B3;
        } q;
        struct {
            unsigned char C0, C1, C2, C3, C4, C5, C6, C7;
        } s;
        struct {
            glueratio GLUE;
        } g;
    } memoryword;
    \stoptyping

    The dual 32 bit model suits tokens well and for nodes is only needed because we store a double but
    when we'd store a 32 bit float instead (which is cf tex) we could use a smaller single 32 bit word.

    On the other hand. it might even make sense for nodes to move to a quad 32 bit variant because it
    makes smaller node identifiers which might remove some limits. But as many nodes have an odd size
    we will waste more memory. Of course for nodes we can at some point decide to go full dynamic and
    use a pointer table but then we need to abstract the embedded subnodes (in disc and insert) first.

    It is a bit tricky if we want to use a [8][8][16][32], [16][16][32] of similar mixing because of
    endiannes, which is why we use a more stepwise definition of memoryword. This mixed scheme permits
    packing more data in anode.

*/

// typedef union memoryword {
//     halfword      H[2];  /* 2 * 32 bit */
//     unsigned int  U[2];
//     quarterword   Q[4];  /* 4 * 16 bit */
//     unsigned char C[8];  /* 8 *  8 bit */
//     glueratio     GLUE;  /* 1 * 64 bit */
//     short         X;
//     long long     L;
//     double        D;
//     void          *P;    /* 1 * 64 bit or 32 bit */
// } memoryword;

typedef union memorysplit {
    quarterword  Q;
    short        X;
    singleword   S[2];
} memorysplit;

typedef union memoryalias {
    halfword     H;
    unsigned int U;
 /* quarterword  Q[2]; */
 /* singleword   S[4]; */
    memorysplit  X[2];
} memoryalias;

typedef union memoryword {
 /* halfword      H[2]; */
 /* unsigned int  U[2]; */
 /* quarterword   Q[4]; */
    memoryalias   A[2];
    unsigned char C[8];
    glueratio     GLUE;
    long long     L;
    double        D;
    void          *P;
} memoryword;

typedef union tokenword {
    union { 
        halfword info;
        halfword val;
        struct  { 
            int cmd:8; 
            int chr:24; 
        };
    };
    halfword link; 
} tokenword;

/*tex

    These symbolic names will be used in the definitions of tokens and nodes, the core data
    structures of the \TEX\ machinery. In some cases halfs and quarters overlap.

*/

# define half0   A[0].H
# define half1   A[1].H

# define hulf0   A[0].U
# define hulf1   A[1].U

// # define quart00  A[0].Q[0]
// # define quart01  A[0].Q[1]
// # define quart10  A[1].Q[0]
// # define quart11  A[1].Q[1]

# define quart00  A[0].X[0].Q
# define quart01  A[0].X[1].Q
# define quart10  A[1].X[0].Q
# define quart11  A[1].X[1].Q

# define short00  A[0].X[0].X
# define short01  A[0].X[1].X
# define short10  A[1].X[0].X
# define short11  A[1].X[1].X

// # define single00 A[0].S[0]
// # define single01 A[0].S[1]
// # define single02 A[0].S[2]
// # define single03 A[0].S[3]
// # define single10 A[1].S[0]
// # define single11 A[1].S[1]
// # define single12 A[1].S[2]
// # define single13 A[1].S[3]

# define single00 A[0].X[0].S[0]
# define single01 A[0].X[0].S[1]
# define single02 A[0].X[1].S[0]
# define single03 A[0].X[1].S[1]
# define single10 A[1].X[0].S[0]
# define single11 A[1].X[0].S[1]
# define single12 A[1].X[1].S[0]
# define single13 A[1].X[1].S[1]

# define glue0   GLUE
# define long0   L
# define double0 D

/*tex

    We're coming from \PASCAL\ which has a boolean type, while in \CCODE\ an |int| is used. However,
    as we often have callbacks and and a connection with the \LUA\ end using |boolean|, |true| and
    |false| is often somewhat inconstent. For that reason we now use |int| instead. It also prevents
    interference with a different definition of |boolean|, something that we can into a few times in
    the past with external code.

    There were not that many explicit booleans used anyway so better be consistent in using integers
    than have an inconsistent mix.

*/

/*tex

    The following parameters can be changed at compile time to extend or reduce \TEX's capacity.
    They may have different values in |INITEX| and in production versions of \TEX. Some values can
    be adapted at runtime. We start with those that influence memory management. Anyhow, some day
    I will collect some statistics from runs and come up with (probably) lower defaults.

*/

/*tex These do a stepwise allocation. */

/*tex The buffer is way too large ... only lines ... we could start out smaller */

/*define magic_maximum         2097151 */ /* (max string) Because we step 500K we will always be below this. */
//define magic_maximum         2000000    /* Looks nicer and we never need the real maximum anyway. */
# define magic_maximum cs_offset_value    /* Looks nicer and we never need the real maximum anyway. */

# define max_hash_size   magic_maximum    /* This is one of these magic numbers. */
# define min_hash_size          150000    /* A reasonable default. */
# define siz_hash_size          250000
# define stp_hash_size          100000    /* Often we have enough. */

# define max_pool_size   magic_maximum    /* stringsize ! */
# define min_pool_size          150000
# define siz_pool_size          500000
# define stp_pool_size          100000

# define max_body_size       100000000    /* poolsize */
# define min_body_size        10000000
# define siz_body_size        20000000
# define stp_body_size         1000000

# define max_node_size       100000000    /* Currently these are the memory words! */
# define min_node_size         2000000    /* Currently these are the memory words! */
# define siz_node_size        25000000
# define stp_node_size          500000    /* Currently these are the memory words! */

# define max_token_size       10000000    /* If needed we can go much larger. */
# define min_token_size        2000000    /* The original 10000 is a bit cheap. */
# define siz_token_size       10000000
# define stp_token_size         500000

# define max_buffer_size     100000000    /* Let's be generous */
# define min_buffer_size       1000000    /* We often need quite a bit. */
# define siz_buffer_size      10000000
# define stp_buffer_size       1000000    /* We use this step when we increase the table. */

# define max_nest_size           10000    /* The table will grow dynamically but the file system might have limitations. */
# define min_nest_size            1000    /* Quite a bit more that the old default 50. */
# define siz_nest_size           10000    /* Quite a bit more that the old default 50. */
# define stp_nest_size            1000    /* We use this step when we increase the table. */

# define max_in_open              2000    /* The table will grow dynamically but the file system might have limitations. */
# define min_in_open               500    /* This used to be 100, but who knows what users load. */
# define siz_in_open              2000    /* This used to be 100, but who knows what users load. */
# define stp_in_open               250    /* We use this step when we increase the table. */

# define max_parameter_size     100000    /* This should be plenty and if not there probably is an issue in the macro package. */
# define min_parameter_size      20000    /* The original value of 60 is definitely not enough when we nest macro calls. */
# define siz_parameter_size     100000    /* The original value of 60 is definitely not enough when we nest macro calls. */
# define stp_parameter_size      10000    /* We use this step when we increase the table. */

# define max_save_size          500000    /* The table will grow dynamically. */
# define min_save_size          100000    /* The original value was 5000, which is not that large for todays usage. */
# define siz_save_size          500000    /* The original value was 5000, which is not that large for todays usage. */
# define stp_save_size           10000    /* We use this step when we increase the table. */

# define max_stack_size         100000    /* The table will grow dynamically. */
# define min_stack_size          10000    /* The original value was 500, okay long ago, but not now. */
# define siz_stack_size         100000    /* The original value was 500, okay long ago, but not now. */
# define stp_stack_size          10000    /* We use this step when we increase the table. */

# define max_mark_size           10000    /*tex The 64K was rediculous (5 64K arrays of halfword). */
# define min_mark_size              50
# define stp_mark_size              50

# define max_insert_size           500
# define min_insert_size            10
# define stp_insert_size            10

# define max_font_size          100000    /* We're now no longer hooked into the eqtb (saved 500+ K in the format too). */
# define min_font_size             250
# define stp_font_size             250

# define max_language_size       10000    /* We could bump this (as we merged the hj codes) but it makes no sense. */
# define min_language_size         250
# define stp_language_size         250

/*tex
    Units. At some point these will be used in texscanning and lmtexlib (3 times replacement).
*/

# define bp_numerator   7227  // base point
# define bp_denonimator 7200

# define cc_numerator  14856  // cicero
# define cc_denonimator 1157

# define cm_numerator   7227  // centimeter
# define cm_denonimator  254

# define dd_numerator   1238  // didot
# define dd_denonimator 1157

# define dk_numerator  49838  // knuth
# define dk_denonimator 7739

# define es_numerator   9176  // edith
# define es_denonimator  129

# define in_numerator   7227  // inch
# define in_denonimator  100

# define mm_numerator   7227  // millimeter
# define mm_denonimator 2540

# define pc_numerator     12  // pica
# define pc_denonimator    1

# define pt_numerator      1  // point
# define pt_denonimator    1

# define sp_numerator      1  // scaled point
# define sp_denonimator    1

# define ts_numerator   4588  // tove
# define ts_denonimator  645

# define eu_min_factor     1
# define eu_max_factor    50
# define eu_def_factor    10

/*tex 1 font id in slot 0 + 16 characters after that */

# define max_twin_length  16
# define max_twin_snippet (max_twin_length + 1)

/*tex

    These are used in the code, so when we want them to adapt, which is needed when we make them
    configurable, we need to change this.

*/

# define max_n_of_marks      max_mark_size
# define max_n_of_inserts    max_insert_size
# define max_n_of_fonts      max_font_size
# define max_n_of_languages  max_language_size

/*tex

    The following settings are not related to memory management. Some day I will probably change
    the error half stuff. There is already an indent related frozen setting here.

*/

# define max_expand_depth     1000000      /* Just a number, no allocation. */
# define min_expand_depth       10000

# define max_error_line           255      /* This also determines size of a (static) array */
# define min_error_line           132      /* Good old \TEX\ uses a value of 79. */

# define max_half_error_line      255
# define min_half_error_line       80      /* Good old \TEX\ uses a value of 50. */

# define memory_data_unset         -1

typedef struct memory_data {
    int ptr;       /* the current pointer */
    int top;       /* the maximum used pointer */
    int size;      /* the used (optionally user asked) value */
    int allocated; /* the currently allocated amount */
    int step;      /* the step used for growing */
    int minimum;   /* the default mininum allocated, also the step */
    int maximum;   /* the maximum possible */
    int itemsize;  /* the itemsize */
    int initial;
    int offset;    /* offset of ptr and top */
} memory_data;

typedef struct limits_data {
    int size;      /* the used (optionally user asked) value */
    int minimum;   /* the default mininum allocated */
    int maximum;   /* the maximum possible */
    int top;       /* the maximum used */
} limits_data;

extern void tex_dump_constants   (dumpstream f);
extern void tex_undump_constants (dumpstream f);

/*tex

This is an experimental feature, different approaces to the main command dispatcher:

\starttabulate[|l|l|l|l|l|l]
\BC n  \BC method          \BC [vhm]mode   \BC binary    \BC manual \BC comment \NC \NR
\ML
\NC 0  \NC jump table      \NC cmd offsets \NC 2.691.584 \NC 10.719 \NC original method, selector: (cmd + mode) \NC \NR
\NC 1  \NC case with modes \NC sequential  \NC 2.697.216 \NC 10.638 \NC nicer modes, we can delegate more to runners \NC \NR
\NC 2  \NC flat case       \NC cmd offsets \NC 2.695.168 \NC 10.562 \NC variant on original \NC \NR
\stoptabulate

The second method can be codes differently where we can delegate more to runners (that then can get
called with a mode argument). Maybe for a next iteration. Concerning performance: the differences
can be neglected (no differences on the test suite) because the bottleneck in \CONTEXT\ is at the
\LUA\ end.

I occasionally test the variants. The last test showed that mode 1 gives a bit larger binary. There
is no real difference in performance.

Well, per end December 2022 we only have the case with modes left but one can always find the old 
code in the archive. 

*/

/*tex For the moment here. */

typedef struct line_break_properties {
    halfword initial_par;
    halfword group_context;
    halfword par_context;
    halfword tracing_paragraphs;
    halfword tracing_fitness;
    halfword tracing_toddlers;
    halfword tracing_orphans;
    halfword tracing_passes;
    halfword paragraph_dir;
    halfword parfill_left_skip;
    halfword parfill_right_skip;
    halfword parinit_left_skip;
    halfword parinit_right_skip;
    halfword emergency_left_skip;
    halfword emergency_right_skip;
    halfword pretolerance;
    halfword tolerance;
    halfword emergency_stretch;
    halfword emergency_original; 
    halfword emergency_extra_stretch;
    halfword looseness;
    halfword adjust_spacing;
    halfword protrude_chars;
    halfword adj_demerits;
    halfword max_adj_demerits;
    halfword line_penalty;
    halfword last_line_fit;
    halfword double_hyphen_demerits;
    halfword final_hyphen_demerits;
    scaled   hsize;
    halfword left_skip;
    halfword right_skip;
    scaled   hang_indent;
    halfword hang_after;
    halfword par_shape;
    halfword inter_line_penalty;
    halfword inter_line_penalties;
    halfword club_penalty;
    halfword club_penalties;
    halfword widow_penalty;
    halfword widow_penalties;
    halfword display_widow_penalty;
    halfword display_widow_penalties;
    halfword orphan_penalties;
    halfword toddler_penalties;
    halfword left_twin_demerits;
    halfword right_twin_demerits;
    halfword fitness_classes;
    halfword adjacent_demerits;
    halfword orphan_line_factors;
    halfword broken_penalty;
    halfword broken_penalties;
    halfword baseline_skip;
    halfword line_skip;
    halfword line_skip_limit;
    halfword adjust_spacing_step;
    halfword adjust_spacing_shrink;
    halfword adjust_spacing_stretch;
    halfword hyphenation_mode;
    halfword shaping_penalties_mode;
    halfword shaping_penalty;
    halfword par_passes;
    halfword line_break_checks;
    halfword extra_hyphen_penalty; 
    halfword line_break_optional;
    halfword single_line_penalty;
    halfword hyphen_penalty;
    halfword ex_hyphen_penalty;
    /*tex Only in par passes (for now). */
    halfword math_penalty_factor;
    halfword sf_factor;
    halfword sf_stretch_factor;
} line_break_properties;

typedef enum sparse_identifiers {
    unknown_sparse_identifier,
    catcode_sparse_identifier,
    lccode_sparse_identifier,
    uccode_sparse_identifier,
    sfcode_sparse_identifier,
    hjcode_sparse_identifier,
    hmcode_sparse_identifier,
    hccode_sparse_identifier,
    amcode_sparse_identifier,
    fontchar_sparse_identifier,
    mathcode_sparse_identifier,
    delcode_sparse_identifier,
    mathfont_sparse_identifier, 
    mathparam_sparse_identifier, 
    user_sparse_identifier,
} sparse_identifiers;

/*tex

    Here are the group codes that are used to discriminate between different kinds of groups. They
    allow \TEX\ to decide what special actions, if any, should be performed when a group ends.

    Some groups are not supposed to be ended by right braces. For example, the |$| that begins a
    math formula causes a |math_shift_group| to be started, and this should be terminated by a
    matching |$|. Similarly, a group that starts with |\left| should end with |\right|, and one
    that starts with |\begingroup| should end with |\endgroup|.

*/

typedef enum tex_group_codes {
    bottom_level_group,  /*tex group code for the outside world */
    simple_group,        /*tex group code for local structure only */
    hbox_group,          /*tex code for |\hbox| */
    adjusted_hbox_group, /*tex code for |\hbox| in vertical mode */
    vbox_group,          /*tex code for |\vbox| */
    vtop_group,          /*tex code for |\vtop| */
    dbox_group,          /*tex code for |\dbox| */
    align_group,         /*tex code for |\halign|, |\valign| */
    no_align_group,      /*tex code for |\noalign| */
    output_group,        /*tex code for output routine */
    math_group,          /*tex code for, e.g., |\char'136| */
    math_stack_group,
    math_component_group,
    discretionary_group, /*tex code for |\discretionary|' */
    insert_group,        /*tex code for |\insert| */
    vadjust_group,       /*tex code for |\vadjust| */
    vcenter_group,       /*tex code for |\vcenter| */
    math_fraction_group, /*tex code for |\over| and friends */
    math_operator_group,
    math_radical_group,
    math_choice_group,   /*tex code for |\mathchoice| */
    also_simple_group,   /*tex code for |\begingroup|\unknown|\egroup| */
    semi_simple_group,   /*tex code for |\begingroup|\unknown|\endgroup| */
    math_simple_group,   /*tex code for |\beginmathgroup|\unknown|\endmathgroup| */
    math_fence_group,    /*tex code for fences |\left|\unknown|\right| */
    math_inline_group,   
    math_display_group,  
    math_number_group,     
    local_box_group,     /*tex code for |\localleftbox|\unknown|localrightbox| */
    split_off_group,     /*tex box code for the top part of a |\vsplit| */
    split_keep_group,    /*tex box code for the bottom part of a |\vsplit| */
    preamble_group,      /*tex box code for the preamble processing  in an alignment */
    align_set_group,     /*tex box code for the final item pass in an alignment */
    finish_row_group,    /*tex box code for a provisory line in an alignment */
    lua_group,
} tex_group_codes;

/*
    In the end I decided to split them into context and begin, but maybe some day
    they all merge into one (easier on tracing and reporting in shared helpers).
*/

typedef enum tex_par_context_codes {
    normal_par_context,
    vmode_par_context,
    vbox_par_context,
    vtop_par_context,
    dbox_par_context,
    vcenter_par_context,
    vadjust_par_context,
    insert_par_context,
    output_par_context,
    align_par_context,
    no_align_par_context,
    span_par_context,
    math_par_context,
    lua_par_context,
    reset_par_context,
    n_of_par_context_codes,
} tex_par_context_codes;

typedef enum tex_alignment_context_codes {
    preamble_pass_alignment_context,
    preroll_pass_alignment_context,
    package_pass_alignment_context,
    wrapup_pass_alignment_context,
} tex_alignment_context_codes;

typedef enum tex_breaks_context_codes {
    initialize_line_break_context,
    start_line_break_context,
    list_line_break_context,
    stop_line_break_context,
    collect_line_break_context,
    line_line_break_context,
    delete_line_break_context,
    report_line_break_context,
    wrapup_line_break_context,
} tex_breaks_context_codes;

typedef enum tex_build_context_codes {
    initialize_show_build_context,
    step_show_build_context,
    check_show_build_context,
    skip_show_build_context,
    move_show_build_context,
    fireup_show_build_context,
    wrapup_show_build_context,
} tex_build_context_codes;

typedef enum tex_page_context_codes {
    box_page_context,
    end_page_context,
    vadjust_page_context,
    penalty_page_context,
    boundary_page_context,
    insert_page_context,
    hmode_par_page_context,
    vmode_par_page_context,
    begin_paragraph_page_context,
    before_display_page_context,
    after_display_page_context,
    after_output_page_context,
    alignment_page_context,
    triggered_page_context
} tex_page_context_codes;

typedef enum tex_append_line_context_codes {
    box_append_line_context,
    pre_box_append_line_context,
    pre_adjust_append_line_context,
    post_adjust_append_line_context,
    pre_migrate_append_line_context,
    post_migrate_append_line_context,
} tex_append_line_context_codes;

typedef enum tex_par_trigger_codes {
    normal_par_trigger,
    force_par_trigger,
    indent_par_trigger,
    no_indent_par_trigger,
    math_char_par_trigger,
    char_par_trigger,
    boundary_par_trigger,
    space_par_trigger,
    math_par_trigger,
    kern_par_trigger,
    hskip_par_trigger,
    un_hbox_char_par_trigger,
    valign_char_par_trigger,
    vrule_char_par_trigger,
} tex_par_trigger_codes;

/*tex 
    In the end we don't go granular because all we need is some control over specific features and 
    we keep these generic and independent of whatever unicode provides. Otherwise we'd also have to 
    bloat the format file. 
*/

// typedef enum tex_character_classification_codes { 
//     letter_classification_code      = 0x0001,
//     other_classification_code       = 0x0002,
//     punctuation_classification_code = 0x0004,
//     spacing_classification_code     = 0x0008,
//                                     
//     lowercase_classification_code   = 0x0010,
//     uppercase_classification_code   = 0x0020,
//     titlecase_classification_code   = 0x0030, /* ! */
//     accent_classification_code      = 0x0040, 
//     digit_classification_code       = 0x0080,
//                                     
//     open_classification_code        = 0x0100,
//     close_classification_code       = 0x0200, 
//     middle_classification_code      = 0x0300, /* ! */
//     quote_classification_code       = 0x0400,
//     dash_classification_code        = 0x0800,
//                                     
//     symbol_classification_code      = 0x1000,
//     math_classification_code        = 0x2000,
//     control_classification_code     = 0x4000, 
//     currency_classification_code    = 0x8000, /* or reserve this one, maybe generic unit */
// } tex_character_classification_codes;

typedef enum tex_character_control_codes { 
    ignore_twin_character_control_code = 0x0001,
} tex_character_control_codes;

# define default_character_control 0

# define has_character_control(a,b) ((a & b) != 0) 


# endif

