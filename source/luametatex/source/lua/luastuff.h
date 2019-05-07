/*
    See license.txt in the root of this project.
*/

# ifndef LUASTUFF_H
# define LUASTUFF_H

void luafunctioncall(int slot);
void luatokencall(int p);
void check_texconfig_init(void);
void make_table(lua_State * L, const char *tab, const char *mttab, const char *getfunc, const char *setfunc);
int lua_traceback(lua_State * L);
void luatex_error(lua_State * L, int fatal);
void initialize_lua(void);

# endif
