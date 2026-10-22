/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

version_state_info lmt_version_state = {
    .majorversion      = luametatex_majorversion,
    .minorversion      = luametatex_minorversion,
    .version           = luametatex_version,
    .release           = luametatex_release,
    .functionality     = luametatex_functionality,
# if defined(LMT_DISTRIBUTION_USED)
    .distribution      = LMT_DISTRIBUTION_USED,
# else
    .distribution      = "regular",
# endif
    .verbose           = luametatex_version_string,
    .banner            = "This is " luametatex_name_camelcase ", Version " luametatex_version_string,
# if defined(LMT_COMPILER_USED)
    .compiler          = LMT_COMPILER_USED,
# else
    .compiler          = "unknown",
# endif
    .cversion          = LMT_CVERSION_USED,
    .likely            = LMT_LIKELY_USED,
    .formatid          = luametatex_format_fingerprint,
    .copyright         = luametatex_copyright_holder,
    .luaversionmajor   = LUA_VERSION_MAJOR_N,
    .luaversionminor   = LUA_VERSION_MINOR_N,	
    .luaversionrelease = LUA_VERSION_RELEASE_N,
    .luametatexversion = (double) luametatex_version_number,
    .luaversion        = (double) LUA_VERSION_MAJOR_N + (double) LUA_VERSION_MINOR_N / 10,
    .luaformat         = LUAC_FORMAT,
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
