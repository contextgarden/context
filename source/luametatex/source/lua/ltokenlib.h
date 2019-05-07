/*
    See license.txt in the root of this project.
*/

# ifndef LTOKENLIB_H
# define LTOKENLIB_H

typedef struct lua_token {
    int token;
    int origin;
} lua_token;

typedef struct command_item_ {
    int id;
    const char *name;
    int lua;
} command_item;

extern command_item command_names[];

extern void tokenlist_to_lua(lua_State * L, int p);
extern void tokenlist_to_luastring(lua_State * L, int p);
extern int tokenlist_from_lua(lua_State * L);
extern int get_command_id(const char *s);

# endif
