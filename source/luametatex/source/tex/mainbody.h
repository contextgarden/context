/*
    See license.txt in the root of this project.
*/

# ifndef MAINBODY_H
# define MAINBODY_H

/*tex

    The following parameters can be changed at compile time to extend or reduce
    \TEX's capacity. They may have different values in |INITEX| and in
    production versions of \TEX.

*/

# define inf_max_strings     100000
# define sup_max_strings     2097151

# define inf_strings_free    100
# define sup_strings_free    2097151

# define inf_buf_size        5000
# define sup_buf_size        100000000

# define inf_fix_mem_init    10000
# define sup_fix_mem_init    1000000

# define inf_nest_size       50
# define sup_nest_size       5000

# define inf_max_in_open     100
# define sup_max_in_open     1000

# define inf_param_size      60
# define sup_param_size      32767

# define inf_save_size       5000
# define sup_save_size       500000

# define inf_stack_size      500
# define sup_stack_size      50000

# define inf_hash_extra      0
# define sup_hash_extra      2097151

# define inf_expand_depth    10000
# define sup_expand_depth    10000000

# define sup_error_line      255
# define inf_error_line      79

# define sup_half_error_line 255
# define inf_half_error_line 50

/*tex Types in the outer block: */

typedef int str_number;
typedef int pool_pointer;
typedef int save_pointer;

typedef int halfword;
typedef unsigned short quarterword;

/*tex

    The |scaled| type is used for scaled integers but it's just another name
    for |halfword| or |int|.

*/

typedef int scaled;

typedef struct scaled_whd_ {
    scaled wd;
    scaled ht;
    scaled dp;
} scaled_whd;

typedef int internal_font_number;

typedef float glue_ratio;          /*tex one-word representation of a glue expansion factor */
typedef unsigned char glue_ord;    /*tex infinity to the 0, 1, 2, 3, or 4 power */

typedef unsigned short group_code; /*tex |save_level| for a level boundary */

/*tex

    Characters of text that have been converted to \TEX's internal form are said
    to be of type |unsigned char|, which is a subrange of the integers. We are
    assuming that our runtime system is able to read and write \UTF-8.

*/

/* Global variables */

typedef struct main_state_info {
    int ini_version;     /*tex Are we |INITEX|? */
    int error_line;
    int half_error_line;
    int max_strings;
    int strings_free;
    int buf_size;
    int stack_size;
    int max_in_open;
    int param_size;
    int nest_size;
    int save_size;
    int expand_depth;
    int dead_cycles;
    int ready_already;
    double starttime ;
} main_state_info ;

extern main_state_info main_state ;

/*tex

    In order to make efficient use of storage space, \TEX\ bases its major data
    structures on a |memory_word|, which contains either a (signed) integer,
    possibly scaled, or a (signed) |glue_ratio|, or a small number of fields that
    are one half or one quarter of the size used for storing integers.

    If |x| is a variable of type |memory_word|, it contains up to four fields
    that can be referred to as follows: $$\vbox{\halign{\hfil#&#\hfil&#\hfil\cr
    |x|&.|int|&(an |integer|)\cr |x|&.|sc|\qquad&(a |scaled| integer)\cr
    |x|&.|gr|&(a |glue_ratio|)\cr |x.hh.lh|, |x.hh|&.|rh|&(two halfword
    fields)\cr |x.hh.b0|, |x.hh.b1|, |x.hh|&.|rh|&(two quarterword fields, one
    halfword field)\cr |x.qqqq.b0|, |x.qqqq.b1|, |x.qqqq|&.|b2|,
    |x.qqqq.b3|\hskip-100pt &\qquad\qquad\qquad(four quarterword fields)\cr}}$$
    This is somewhat cumbersome to write, and not very readable either, but
    macros will be used to make the notation shorter and more transparent. The
    \PASCAL\ code below gives a formal definition of |memory_word| and its
    subsidiary types, using packed variant records. \TEX\ makes no assumptions
    about the relative positions of the fields within a word.

    We are assuming 32-bit integers, a halfword must contain at least
    32 bits, and a quarterword must contain at least 16 bits.

    N.B.: Valuable memory space will be dreadfully wasted unless \TEX\ is
    compiled by a \PASCAL\ that packs all of the |memory_word| variants into the
    space of a single integer. This means, for example, that |glue_ratio| words
    should be |short_real| instead of |real| on some computers. Some \PASCAL\
    compilers will pack an integer whose subrange is |0 .. 255| into an eight-bit
    field, but others insist on allocating space for an additional sign bit; on
    such systems you can get 256 values into a quarterword only if the subrange
    is |-128 .. 127|.

    The present implementation tries to accommodate as many variations as
    possible, so it makes few assumptions. If integers having the subrange
    |min_quarterword .. max_quarterword| can be packed into a quarterword, and if
    integers having the subrange |min_halfword .. max_halfword| can be packed
    into a halfword, everything should work satisfactorily.

    It is usually most efficient to have |min_quarterword = min_halfword=0|, so one
    should try to achieve this unless it causes a severe problem. The values
    defined here are recommended for most 32-bit computers.

    We cannot use the full range of 32 bits in a halfword, because we have to
    allow negative values for potential backend tricks like web2c's dynamic
    allocation, and parshapes pointers have to be able to store at least twice
    the value |max_halfword| (see below). Therefore, |max_halfword| is $2^{30}-1$

*/

# define max_integer   0x7FFFFFFF
# define max_dimen     0x3FFFFFFF
# define one_bp          65781
# define min_infinity -0x7FFFFFFF

/*tex

    The documentation refers to pointers and halfwords and scaled and all are in
    fact just integers. Okay, one can wonder about negative pointers but we never
    reach the limits so we're okay wrr wraparound. At some point we might just
    replace all by int as some of the helpers already do that. For now we keep
    halfword and scaled but we removed (the not so often used) pointers because
    they were already mixed with halfwords in similar usage.

*/

# define pointer halfword

# define min_quarterword    0        /*tex The smallest allowable value in a |quarterword|. */
# define max_quarterword    65535    /*tex The largest allowable value in a |quarterword|. */
# define min_halfword    -0x3FFFFFFF /*tex The smallest allowable value in a |halfword|. */
# define max_halfword     0x3FFFFFFF /*tex The largest allowable value in a |halfword|. */

/*tex

    The following procedure, which is called just before \TEX\ initializes its
    input and output, establishes the initial values of the date and time. It
    calls a macro-defined |dateandtime| routine. |dateandtime| in turn is also a
    |CCODE\ macro, which calls |get_date_and_time|, passing it the addresses of
    the day, month, etc., so they can be set by the routine. |get_date_and_time|
    also sets up interrupt catching if that is conditionally compiled in the
    \CCODE\ code.

*/

# define fix_date_and_time() get_date_and_time(&time_par,&day_par,&month_par,&year_par,&engine_state.utc_time)

extern void main_body(void);
extern void close_files_and_terminate(void);
extern void final_cleanup(void);
extern int main_initialize(void);
extern void check_buffer_overflow(int wsize);

# endif
