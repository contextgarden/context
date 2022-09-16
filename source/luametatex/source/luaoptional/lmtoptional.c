/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

/*tex

    We don't want the binary top explode and have depdencies that will kill this project in the
    end. So, we provide optionals: these are loaded lazy and libraries need to be present in
    the tree. They are unofficial and not supported in the sense that ConTeXt doesn't depend on
    them.

    The socket library is a candidate for ending up here too, as are the optional rest modules
    lzo and lz4.

*/

int luaopen_optional(lua_State *L) {
    /*tex We always have an |optional| root table. */
    lmt_library_initialize(L);
    luaopen_library(L);
    luaopen_foreign(L); /* maybe in main */
    /*tex These are kind of standard. */
    luaopen_sqlite(L);
    luaopen_mysql(L);
    luaopen_postgress(L);
    luaopen_curl(L);
    luaopen_ghostscript(L);
    luaopen_graphicsmagick(L);
    luaopen_imagemagick(L);
    luaopen_zint(L);
    /*tex These are fun. */
    luaopen_mujs(L);
    /*tex These might be handy. */
    luaopen_lzo(L);
    luaopen_lz4(L);
    luaopen_zstd(L);
    luaopen_lzma(L);
    /*tex These are extras. */
# ifdef LMT_KPSE_TOO
    luaopen_kpse(L);
# endif
# ifdef LMT_HB_TOO
    luaopen_hb(L);
# endif
    /*tex Done. */
    return 0;
}
