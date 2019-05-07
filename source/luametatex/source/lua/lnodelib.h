/*
    See license.txt in the root of this project.
*/

# ifndef LNODELIB_H
# define LNODELIB_H

extern void lua_nodelib_push(lua_State * L);
extern int  nodelib_getlist(lua_State * L, int n);

extern void nodelist_to_lua(lua_State * L, int n);
extern int  nodelist_from_lua(lua_State * L, int n);

/*
# define nodelist_to_lua(L,n) do {  \
    lua_pushinteger(L, n); \
    lua_nodelib_push(L); \
} while (0)
*/

extern void initialize_properties(int set_size);

# endif
