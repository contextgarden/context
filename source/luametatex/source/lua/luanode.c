/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

int lua_newgraf_callback(int invmode, int indented)
{
    int callback_id = callback_defined(new_graf_callback);
    int top;
    if (callback_id > 0 && (top = callback_okay(Luas, callback_id))) {
        int i;
        lua_pushboolean(Luas,invmode);
        lua_pushboolean(Luas,indented);
        i = callback_call(Luas,2,1,top);
        if (i != 0) {
            callback_error(Luas,top,i);
        } else {
            indented = lua_toboolean(Luas,-1);
            callback_wrapup(Luas,top);
        }
    }
    return indented;
}

void lua_node_filter_s(int filterid, int extrainfo)
{
    int callback_id = callback_defined(filterid);
    int top;
    if (callback_id > 0 && (top = callback_okay(Luas, callback_id))) {
        int i;
        lua_push_string_by_index(Luas,extrainfo);
        i = callback_call(Luas,1,0,top);
        if (i != 0) {
            callback_error(Luas,top,i);
        } else {
            callback_wrapup(Luas,top);
        }
    }
}

void lua_node_filter(int filterid, int extrainfo, halfword head_node, halfword * tail_node)
{
    if (head_node) {
        /*tex We start after head. */
        halfword start_node = vlink(head_node);
        if (start_node) {
            int callback_id = callback_defined(filterid);
            int top;
            if (callback_id > 0 && (top = callback_okay(Luas, callback_id))) {
                int i;
                /*tex We make sure we have no prev */
                alink(start_node) = null ;
                /*tex the action */
                nodelist_to_lua(Luas, start_node);
                lua_push_group_code(Luas,extrainfo);
                i = callback_call(Luas,2,1,top);
                if (i != 0) {
                    callback_error(Luas,top,i);
                } else {
                    /*tex the result */
                    if (lua_isboolean(Luas, -1)) {
                        if (lua_toboolean(Luas, -1) != 1) {
                            /*tex discard */
                            flush_node_list(start_node);
                            vlink(head_node) = null;
                        } else {
                            /*tex keep */
                        }
                    } else {
                        /*tex append to old head */
                        halfword start_done = nodelist_from_lua(Luas,-1);
                        try_couple_nodes(head_node,start_done);
                    }
                    /*tex redundant as we set top anyway */
                    lua_pop(Luas, 2);
                    /*tex find tail in order to update tail */
                    start_node = vlink(head_node);
                    if (start_node) {
                        /*tex maybe just always slide (harmless and fast) */
                        if (fix_node_lists) {
                            /*tex slides and returns last node */
                            *tail_node = fix_node_list(start_node);
                        } else {
                            halfword last_node = vlink(start_node);
                            while (last_node != null) {
                                start_node = last_node;
                                last_node = vlink(start_node);
                            }
                            /*tex we're at the end now */
                            *tail_node = start_node;
                        }
                    } else {
                        /*tex we're already at the end */
                        *tail_node = head_node;
                    }
                    callback_wrapup(Luas,top);
                }
            }
        }
    }
    return;
}

int lua_linebreak_callback(int is_broken, halfword head_node, halfword * new_head)
{
    if (head_node) {
        halfword start_node = vlink(head_node);
        if (start_node) {
            int callback_id = callback_defined(linebreak_filter_callback);
            int top;
            if (callback_id > 0 && (top = callback_okay(Luas, callback_id))) {
                int i;
                int ret = 0;
                alink(start_node) = null ;
                nodelist_to_lua(Luas, start_node);
                lua_pushboolean(Luas, is_broken);
                i = callback_call(Luas,2,1,top);
                if (i) {
                    callback_error(Luas,top,i);
                } else {
                    halfword *p = lua_touserdata(Luas, -1);
                    if (p != NULL) {
                        int a = nodelist_from_lua(Luas,-1);
                        try_couple_nodes(*new_head,a);
                        ret = 1;
                    }
                    callback_wrapup(Luas,top);
                }
                return ret;
            }
        }
    }
    return 0;
}

int lua_appendtovlist_callback(halfword box, int location, halfword prev_depth,
    int is_mirrored, halfword * result, int * next_depth, int * prev_set)
{
    if (box) {
        int callback_id = callback_defined(append_to_vlist_filter_callback);
        int top;
        if (callback_id > 0 && (top = callback_okay(Luas,callback_id))) {
            int i;
            nodelist_to_lua(Luas, box);
            lua_push_string_by_index(Luas,location);
            lua_pushinteger(Luas, (int) prev_depth);
            lua_pushboolean(Luas, is_mirrored); /* obsolete */
            i = callback_call(Luas,4,2,top);
            if (i) {
                callback_error(Luas,top,i);
            } else {
                if (lua_type(Luas,-1) == LUA_TNUMBER) {
                    *next_depth = lua_roundnumber(Luas,-1);
                    *prev_set = 1;
                    if (lua_type(Luas, -2) != LUA_TNIL) {
                        halfword *p = check_isnode(Luas, -2);
                        *result = *p;
                    }
                } else if (lua_type(Luas, -1) != LUA_TNIL) {
                    halfword *p = check_isnode(Luas, -1);
                    *result = *p;
                }
                callback_wrapup(Luas,top);
                return 1;
            }
        }
    }
    return 0;
}

halfword lua_hpack_filter(halfword head_node, scaled size, int pack_type, int extrainfo, int pack_direction, halfword attr)
{
    if (head_node) {
        int callback_id = callback_defined(hpack_filter_callback);
        int top;
        if (callback_id > 0 && (top = callback_okay(Luas, callback_id))) {
            int i;
            alink(head_node) = null ;
            nodelist_to_lua(Luas, head_node);
            lua_push_group_code(Luas,extrainfo);
            lua_pushinteger(Luas, size);
            lua_push_pack_type(Luas, pack_type);
            if (pack_direction >= 0) {
                lua_pushinteger(Luas, pack_direction);
            } else {
                lua_pushnil(Luas);
            }
            if (attr) {
                nodelist_to_lua(Luas, attr);
            } else {
                lua_pushnil(Luas);
            }
            i = callback_call(Luas,6,1,top);
            if (i) {
                callback_error(Luas,top,i);
                return head_node;
            } else {
                halfword ret = head_node;
                if (lua_isboolean(Luas, -1)) {
                    if (lua_toboolean(Luas, -1) != 1) {
                        flush_node_list(head_node);
                        ret = null;
                    }
                } else {
                    ret = nodelist_from_lua(Luas,-1);
                }
                if (fix_node_lists) {
                    fix_node_list(ret);
                }
                callback_wrapup(Luas, top);
                return ret;
            }
        }
    }
    return head_node;
}

halfword lua_vpack_filter(halfword head_node, scaled size, int pack_type, scaled maxd, int extrainfo, int pack_direction, halfword attr)
{
    if (head_node) {
        int callback_id = callback_defined(extrainfo == 8 ? pre_output_filter_callback : vpack_filter_callback);
        int top;
        if (callback_id > 0 && (top = callback_okay(Luas,callback_id))) {
            int i;
            alink(head_node) = null ;
            nodelist_to_lua(Luas, head_node);
            lua_push_group_code(Luas, extrainfo);
            lua_pushinteger(Luas, size);
            lua_push_pack_type(Luas, pack_type);
            lua_pushinteger(Luas, maxd);
            if (pack_direction >= 0) {
                lua_pushinteger(Luas, pack_direction);
            } else {
                lua_pushnil(Luas);
            }
            if (attr) {
                nodelist_to_lua(Luas, attr);
            } else {
                lua_pushnil(Luas);
            }
            i = callback_call(Luas,7,1,top);
            if (i) {
                callback_error(Luas, top, i);
                return head_node;
            } else {
                halfword ret = head_node;
                if (lua_isboolean(Luas, -1)) {
                    if (lua_toboolean(Luas, -1) != 1) {
                        flush_node_list(head_node);
                        ret = null;
                    }
                } else {
                    ret = nodelist_from_lua(Luas,-1);
                }
                if (fix_node_lists) {
                    fix_node_list(ret);
                }
                callback_wrapup(Luas, top);
                return ret;
            }
        }
    }
    return head_node;
}

/*tex

    This is a quick hack to fix \ETEX's |\lastnodetype| now that there are many
    more visible node types.

*/

int visible_last_node_type(int n)
{
    if (type(n) != glyph_node) {
        return get_etex_code(type(n));
    } else if (is_ligature(n)) {
        /*tex old ligature value */
        return 7;
    } else {
        /*tex old character value */
        return 0;
    }
}
