/*
    See license.txt in the root of this project.
*/

/*tex

    This header file is extra special because it is read in from within the
    \PASCAL\ source.

*/

# ifndef MEMORYWORD_H
# define MEMORYWORD_H

/*tex

    The memory_word type, which is too hard to translate automatically from
    Pascal. We have to make sure the byte-swapping that the (un)dumping routines
    do suffices to put things in the right place in memory.

    A memory_word can be broken up into a \quote {twohalves} or a \quote
    {fourquarters}, and a \quote {twohalves} can be further broken up. Here is a
    picture. |..._M| is for \quotation {most significant byte} and |..._L| stands
    for \quotation {least significant byte}.

    Big Endian:

    \starttabulate[|T|T|]
    \NC twohalves.v  \NC RH_MM RH_ML RH_LM RH_LL LH_MM LH_ML LH_LM LH_LL \NC \NR
    \NC twohalves.u  \NC ---------JUNK---------- ----B0----- ----B1----- \NC \NR
    \NC fourquarters \NC ----B0----- ----B1----- ----B2----- ----B3----- \NC \NR
    \NC twoints      \NC ---------CINT0--------- ---------CINT1--------- \NC \NR
    \stoptabulate

    Little Endian:

    \starttabulate[|T|T|]
    \NC twohalves.v  \NC LH_LL LH_LM LH_ML LH_MM RH_LL RH_LM RH_ML RH_MM \NC \NR
    \NC twohalves.u  \NC ----B1----- ----B0----- ---------JUNK---------- \NC \NR
    \NC fourquarters \NC ----B3----- ----B2----- ----B1----- ----B0----- \NC \NR
    \NC twoints      \NC ---------CINT1--------- ---------CINT0--------- \NC \NR
    \stoptabulate

*/

/*tex

    Because we're now in C we can actually replace this model by just a strip
    of integers. There is no real need to talk of words split into halfwords any
    longer. We (probably) only need to adapt the node definitions. On the other hand,
    memorywords nicely maps onto 64 bit.

*/

# if (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#     ifdef TEX_WORDS_BIGENDIAN
#         undef TEX_WORDS_BIGENDIAN
#     endif
# else
#     define TEX_WORDS_BIGENDIAN 1
# endif

/*
# if defined (BYTE_ORDER) && defined (BIG_ENDIAN) && defined (LITTLE_ENDIAN)
#     ifdef TEX_WORDS_BIGENDIAN
#         undef TEX_WORDS_BIGENDIAN
#     endif
#     if BYTE_ORDER == BIG_ENDIAN
#         define TEX_WORDS_BIGENDIAN
#     endif
# endif
*/

typedef union {
    struct {
# ifdef TEX_WORDS_BIGENDIAN
        halfword RH, LH;
# else
        halfword LH, RH;
# endif
    } v;
    /*tex Make B0,B1 overlap the most significant bytes of LH.  */
    struct {
# ifdef TEX_WORDS_BIGENDIAN
        halfword junk;
        quarterword B0, B1;
# else
        /* If 32-bit memory words, have to do something.  */
        quarterword B1, B0;
        halfword junk;
# endif
    } u;
} two_halves;

/*tex

    We could have a char (and C0 .. C7) too for usage in pseudo files but we don't
    really use pseudofiles that often so ...

*/

typedef struct {
    struct {
# ifdef TEX_WORDS_BIGENDIAN
        quarterword B0, B1, B2, B3;
# else
        quarterword B3, B2, B1, B0;
# endif
    } u;
} four_quarters;

/*tex

    The ints can become halfwords as they are used that way.

*/

typedef struct {
# ifdef TEX_WORDS_BIGENDIAN
    int CINT0, CINT1; /* the same as RH, LH */
# else
    int CINT1, CINT0; /* the same as LH, RH */
# endif
} two_ints;

typedef struct {
    glue_ratio GLUE;
} one_glue;

typedef union {
    two_halves hh;
    four_quarters qqqq;
    two_ints ii;
    one_glue gg;
} memory_word;

# define b0 u.B0
# define b1 u.B1
# define b2 u.B2
# define b3 u.B3

# define rhfield v.RH
# define lhfield v.LH

# define cint0 ii.CINT0
# define cint1 ii.CINT1

# define glue0 gg.GLUE

typedef struct smemory_word_ {
# ifdef TEX_WORDS_BIGENDIAN
    halfword hhrh;
    halfword hhlh;
# else
    halfword hhlh;
    halfword hhrh;
# endif
} smemory_word;

# endif
