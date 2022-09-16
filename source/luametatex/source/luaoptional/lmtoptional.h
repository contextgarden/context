/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LUAOPTIONAL_H
# define LMT_LUAOPTIONAL_H

# include <lua.h>

/*tex This saves a bunch of h files. */

extern int luaopen_optional      (lua_State *L);
extern int luaopen_library       (lua_State *L);
extern int luaopen_foreign       (lua_State *L);

extern int luaopen_sqlite        (lua_State *L);
extern int luaopen_mysql         (lua_State *L);
extern int luaopen_curl          (lua_State *L);
extern int luaopen_postgress     (lua_State *L);
extern int luaopen_ghostscript   (lua_State *L);
extern int luaopen_graphicsmagick(lua_State *L);
extern int luaopen_imagemagick   (lua_State *L);
extern int luaopen_zint          (lua_State *L);
extern int luaopen_mujs          (lua_State *L);
extern int luaopen_lzo           (lua_State *L);
extern int luaopen_lz4           (lua_State *L);
extern int luaopen_zstd          (lua_State *L);
extern int luaopen_lzma          (lua_State *L);
extern int luaopen_kpse          (lua_State *L); /*tex For testing compatibility, if needed at all, not really I guess. */
extern int luaopen_hb            (lua_State *L); /*tex For when Idris needs to check fonts some day ... old stuff, not tested much. */

extern int luaextend_xcomplex    (lua_State *L);

# endif
