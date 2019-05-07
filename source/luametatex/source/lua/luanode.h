/*
    See license.txt in the root of this project.
*/

# ifndef LUANODE_H
# define LUANODE_H

int visible_last_node_type(int n);
void print_node_mem_stats(void);

extern void lua_nodelib_push_fast(lua_State * L, halfword n);

halfword lua_hpack_filter(
    halfword head_node,
    scaled size,
    int pack_type,
    int extrainfo,
    int d,
    halfword a
);

halfword lua_vpack_filter(
    halfword head_node,
    scaled size,
    int pack_type,
    scaled maxd,
    int extrainfo,
    int d,
    halfword a
);

void lua_node_filter(
    int filterid,
    int extrainfo,
    halfword head_node,
    halfword * tail_node
);

void lua_node_filter_s(
    int filterid,
    int extrainfo
);

int lua_linebreak_callback(
    int is_broken,
    halfword head_node,
    halfword * new_head
);

int lua_appendtovlist_callback(
    halfword box,
    int location,
    halfword prev_depth,
    int is_mirrored,
    halfword * result,
    int * next_depth,
    int * prev_set
);

int lua_newgraf_callback(
    int invmode,
    int indented
);

# endif
