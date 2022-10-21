/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LTOKENLIB_H
# define LMT_LTOKENLIB_H

typedef enum token_origins {
    token_origin_lua,
    token_origin_tex,
} token_origins;

typedef struct lua_token {
    int           token;
    token_origins origin;
} lua_token;

typedef enum command_item_types {
    unused_command_item,
    regular_command_item,
    character_command_item,
    register_command_item,
    internal_command_item,
    reference_command_item,
    data_command_item,
    token_command_item,
    node_command_item,
} command_item_types;

extern void     lmt_token_list_to_lua         (lua_State *L, halfword p);
extern void     lmt_token_list_to_luastring   (lua_State *L, halfword p, int nospace, int strip, int wipe);
extern halfword lmt_token_list_from_lua       (lua_State *L, int slot);
extern halfword lmt_token_code_from_lua       (lua_State *L, int slot);

extern void     lmt_function_call             (int slot, int prefix);
extern int      lmt_function_call_by_class    (int slot, int property, halfword *value);
extern void     lmt_token_call                (int p);
extern void     lmt_local_call                (int slot);

extern char    *lmt_get_expansion             (halfword head, int *len);

extern void     lmt_token_register_to_lua     (lua_State *L, halfword t);

extern void     lmt_tokenlib_initialize       (void);

extern int      lmt_push_specification        (lua_State *L, halfword ptr, int onlycount);

extern void     lmt_push_cmd_name             (lua_State *L, int cmd);

extern halfword lmt_macro_to_tok              (lua_State* L, int slot, halfword *tail);

# endif
