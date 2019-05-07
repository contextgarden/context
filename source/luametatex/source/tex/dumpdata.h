/*
    See license.txt in the root of this project.
*/

# ifndef DUMPDATA_H
# define DUMPDATA_H

typedef struct dump_state_info {
    str_number format_ident;
    str_number format_name;  /*tex principal file name */
    FILE *fmt_file;          /*tex for input or output of format information */
    gzFile gz_fmtfile;
} dump_state_info;

extern dump_state_info dump_state;

extern void store_fmt_file(void);
extern int load_fmt_file(void);

/*tex (Un)dumping: these are called from the change file. */

# define dump_things(base, len)   do_zdump  ((char *) &(base), sizeof (base), (int) (len))
# define undump_things(base, len) do_zundump((char *) &(base), sizeof (base), (int) (len))

/*tex

    Like |do_undump|, but check each value against LOW and HIGH. The slowdown
    isn't significant, and this improves the chances of detecting incompatible
    format files. In fact, Knuth himself noted this problem with Web2c some years
    ago, so it seems worth fixing. We can't make this a subroutine because then
    we lose the type of BASE.

*/

/*
# define undump_checked_things(low, high, base, len) do { \
    unsigned i; \
    undump_things (base, len); \
    for (i = 0; i < (len); i++) { \
        if ((&(base))[i] < (low) || (&(base))[i] > (high)) { \
            fprintf(stderr, "Item %u (=%ld) of .fmt array at %lx <%ld or >%ld can't be undumped.", \
                i, (unsigned long) (&(base))[i], (unsigned long) &(base), \
                (unsigned long) low, (unsigned long) high); \
            exit(EXIT_FAILURE); \
        } \
    } \
} while (0)
*/

/*tex We now have other ways to check the format version. */

# define undump_checked_things(low, high, base, len) undump_things (base, len)

/*tex

    Like |undump_checked_things|, but only check the upper value. We use this
    when the base type is unsigned, and thus all the values will be greater than
    zero by definition.

*/

/*

# define undump_upper_check_things(high, base, len) do { \
    unsigned i; \
    undump_things (base, len); \
    for (i = 0; i < (len); i++) { \
        if ((&(base))[i] > (high)) { \
            FATAL4 ("Item %u (=%ld) of .fmt array at %lx >%ld", \
                i, (unsigned long) (&(base))[i], (unsigned long) &(base), \
                (unsigned long) high); \
        } \
    } \
} while (0)
*/

/*tex We now have other ways to check the format version. */

# define undump_upper_check_things(high, base, len) undump_things (base, len)

/*tex

    Use the above for all the other dumping and undumping.

*/

# define generic_dump(x)   dump_things(x,1)
# define generic_undump(x) undump_things(x,1)

# define dump_wd     generic_dump
# define dump_hh     generic_dump
# define dump_qqqq   generic_dump
# define undump_wd   generic_undump
# define undump_hh   generic_undump
# define undump_qqqq generic_undump

/*tex

    |dump_int| is called with constant integers, so we put them into a variable
    first.

*/

# define dump_int(x) do { \
    int x_val = (x); \
    generic_dump (x_val); \
} while (0)

/*tex

    Some compilers aren't willing to take addresses of variables in registers, so
    we must kludge.

*/

/*
# if defined(REGFIX) || defined(WIN32)
# define undump_int(x) do { \
    int x_val; \
    generic_undump (x_val); \
    x = x_val; \
} while (0)
# else
# define undump_int generic_undump
# endif
*/

# define undump_int generic_undump

# endif
