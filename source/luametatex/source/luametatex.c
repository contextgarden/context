/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    The version number can be queried with |\luatexversion| and the revision with
    with |\luatexrevision|. Traditionally the revision can be any character and
    \PDFTEX\ occasionally used no digits. Here we still use a character but we
    will stick to 0 upto 9 so users can expect a number represented as string.

*/

version_state_info version_state = { 200, '0', "2.00.0" };

/*tex

    We |#define DLLPROC| in order to build LuaTeX and LuajitTeX as DLL for
    W32TeX. We can omit the first define as we go for static binaries.

*/

# if defined(_WIN32) && !defined(__MINGW32__)
    extern __declspec(dllexport) int DLLPROC(int ac, char* *av);
# else
    extern int main(int ac, char* *av)
# endif
{
    /*tex We set up the whole machinery, for instance booting \LUA. */
    lua_initialize(ac,av);
    /*tex Kind of special: */
    set_interrupt_handler();
    /*tex Now we're ready for the more traditional \TEX\ initializations */
    main_body();
    /*tex When we arrive here we had a succesful run. */
    return EXIT_SUCCESS;
}
