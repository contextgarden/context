/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    The version number can be queried with |\luatexversion| and the revision with with
    |\luatexrevision|. Traditionally the revision can be any character and \PDFTEX\ occasionally
    used no digits. Here we still use a character but we will stick to 0 upto 9 so users can expect
    a number represented as string. Further comments have been moved to the manual.

*/

# ifndef LMT_COMPILER_USED
    # define LMT_COMPILER_USED "unknown"
# endif

/*tex
    It would be nice if we could test if musl is used. Comments in the web indicate that there
    never be some macro to check for that (argument: it shouldn't matter code/api wise). Well it
    does matter if you have to make a choice for a binary (set path to a tree), as needed in a
    TeX distribution that ships a lot. A bit lack of imagination I guess or maybe it's only for
    people who compile themselves. So if no one cares, I don't either. Maybe CMAKE can help some
    day.
*/

// # ifndef LMT_LIBC_USED
//    # if defined(__GLIBC__)
//        # define LMT_LIBC_USED "glibc"
//    # elif defined(__UCLIBC__)
//        # define LMT_LIBC_USED "uclibc"
//    # else
//        # define LMT_LIBC_USED "unknown"
//    # endif
// # endif

version_state_info lmt_version_state = {
    .version       = luametatex_version,
    .revision      = luametatex_revision,
    .verbose       = luametatex_version_string,
    .banner        = "This is " luametatex_name_camelcase ", Version " luametatex_version_string,
    .compiler      = LMT_COMPILER_USED,
 // .libc          = LMT_LIBC_USED,
    .developmentid = luametatex_development_id,
    .formatid      = luametatex_format_fingerprint,
    .copyright     = luametatex_copyright_holder,
};

int main(int ac, char* *av)
{
    /*tex We set up the whole machinery, for instance booting \LUA. */
    tex_engine_initialize(ac, av);
    /*tex Kind of special: */
    aux_set_interrupt_handler();
    /*tex Now we're ready for the more traditional \TEX\ initializations */
    tex_main_body();
    /*tex When we arrive here we had a succesful run. */
    return EXIT_SUCCESS; /* unreachable */
}
