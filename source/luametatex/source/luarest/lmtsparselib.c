/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex
    This module just provides as a more compact alternative for storing bitsets. I have no clue if
    it ever will be used but we had this sparse tree mechanism so the overhead in terms of code is
    neglectable. A possible application is bitmaps. Because we cross the c boundary it's about three
    times slower when we get/set values than staying in \LUA\ although traversing from |min| to
    |max| is performance wise the same. We could actually gain a bit when we add more helpers (like
    |inc| and |dec| or so).

    So, for the moment I consider this a low impact, and thereby undocumented, fun project.
*/

# define SPARSE_STACK 8
# define SPARSE_BYTES 4

typedef struct sa_tree_object {
    sa_tree tree;
    int     min;
    int     max;
} sa_tree_object;

static sa_tree_object *sparselib_aux_check_is_sa_object(lua_State *L, int n)
{
    sa_tree_object *o = (sa_tree_object *) lua_touserdata(L, n);
    if (o && lua_getmetatable(L, n)) {
        lua_get_metatablelua(sparse_instance);
        if (! lua_rawequal(L, -1, -2)) {
            o = NULL;
        }
        lua_pop(L, 2);
        if (o) {
            return o;
        }
    }
    tex_normal_warning("sparse lib", "lua <sparse object> expected");
    return NULL;
}

/* bytes=1|2|4, default=0|* */

static int sparselib_new(lua_State *L)
{
    int bytes = lmt_optinteger(L, 1, SPARSE_BYTES);
    int defval = lmt_optinteger(L, 2, 0);
    sa_tree_item item = { .int_value = defval };
    sa_tree_object *o = lua_newuserdatauv(L, sizeof(sa_tree_object), 0);
    switch (bytes) {
        case 1:
            {
                int d = defval < 0 ? 0 : (defval > 0xFF ? 0xFF : defval);
                for (int i = 0; i <= 3; i++) {
                    item.uchar_value[i] = (unsigned char) d;
                }
                break;
            }
        case 2:
            {
                int d =  defval < 0 ? 0 : (defval > 0xFFFF ? 0xFFFF : defval);
                for (int i = 0; i <= 1; i++) {
                    item.ushort_value[i] = (unsigned short) d;
                }
                break;
            }
        case 4:
            break;
        default:
            bytes = SPARSE_BYTES;
            break;
    }
    o->tree = sa_new_tree(SPARSE_STACK, bytes, item);
    o->min = -1;
    o->max = -1;
    luaL_setmetatable(L, SPARSE_METATABLE_INSTANCE);
    return 1;
}

static int sparselib_gc(lua_State *L)
{
    sa_tree_object *o = (sa_tree_object *) lua_touserdata(L, 1);
    if (o) {
       sa_destroy_tree(o->tree);
    }
    return 0;
}

static int sparselib_tostring(lua_State *L) {
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        lua_pushfstring(L, "<sa.object %p>", o->tree);
        return 1;
    } else {
        return 0;
    }
}

/* sparse, index, value */

static int sparselib_set(lua_State *L) /* maybe also globalset as fast one */
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        quarterword level;
        int slot = lmt_check_for_level(L, 2, &level, cur_level);
        int n = lmt_tointeger(L, slot++);
        if (n >= 0) {
            int v = lmt_tointeger(L, slot++);
            if (o->min < 0) {
                o->min = n;
                o->max = n;
            } else if (n < o->min) {
                o->min = n;
            } else if (n > o->max) {
                o->max = n;
            }
            sa_set_item_n(o->tree, n, v, (int) level);
        }
    }
    return 0;
}

/* sparse, index */

static int sparselib_get(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        int n = lmt_tointeger(L, 2);
        if (n >= 0) {
            lua_pushinteger(L, sa_get_item_n(o->tree, n));
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int sparselib_min(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        lua_pushinteger(L, o->min >= 0 ? o->min : 0);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int sparselib_max(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        lua_pushinteger(L, o->max >= 0 ? o->max : 0);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int sparselib_range(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        lua_pushinteger(L, o->min >= 0 ? o->min : 0);
        lua_pushinteger(L, o->max >= 0 ? o->max : 0);
    } else {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    return 2;
}

static int sparselib_aux_nil(lua_State *L)
{
    lua_pushnil(L);
    return 1;
}

static int sparselib_aux_next(lua_State *L)
{
    sa_tree_object *o = (sa_tree_object *) lua_touserdata(L, lua_upvalueindex(1));
    int ind = lmt_tointeger(L, lua_upvalueindex(2));
    if (ind <= o->max) {
        lua_pushinteger(L, (lua_Integer) ind + 1);
        lua_replace(L, lua_upvalueindex(2));
        lua_pushinteger(L, ind);
        lua_pushinteger(L, sa_get_item_n(o->tree, ind));
        return 2;
    } else {
        return 0;
    }
}

static int sparselib_traverse(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o && o->min >= 0) {
        lua_settop(L, 1);
        lua_pushinteger(L, o->min);
        lua_pushcclosure(L, sparselib_aux_next, 2);
    } else {
        lua_pushcclosure(L, sparselib_aux_nil, 0);
    }
    return 1;
}

static int sparselib_concat(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        sa_tree t = o->tree;
        if (t->bytes == 1) {
            luaL_Buffer buffer;
            int min = lmt_optinteger(L, 2, o->min);
            int max = lmt_optinteger(L, 3, o->max);
            if (min < 0) {
                min = 0;
            }
            if (max < min) {
                max = min;
            }
            /* quick hack: we can add whole slices */
            luaL_buffinitsize(L, &buffer, (size_t) max - (size_t) min + 1);
            for (int i = min; i <= max; i++) {
                char c;
                int h = LMT_SA_H_PART(i);
                if (t->tree[h]) {
                    int m = LMT_SA_M_PART(i);
                    if (t->tree[h][m]) {
                        c = (char) t->tree[h][m][LMT_SA_L_PART(i)/4].uchar_value[i%4];
                    } else {
                        c = (char) t->dflt.uchar_value[i%4];
                    }
                } else {
                    c = (char) t->dflt.uchar_value[i%4];
                }
                luaL_addlstring(&buffer, &c, 1);
            }
            luaL_pushresult(&buffer);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int sparselib_restore(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
     /* restore_sa_stack(o->tree, cur_level); */
        sa_restore_stack(o->tree, cur_level+1);
    }
    return 0;
}

static int sparselib_wipe(lua_State *L)
{
    sa_tree_object *o = sparselib_aux_check_is_sa_object(L, 1);
    if (o) {
        int bytes = o->tree->bytes;
        sa_tree_item dflt = o->tree->dflt;
        sa_destroy_tree(o->tree);
        o->tree = sa_new_tree(SPARSE_STACK, bytes, dflt);
        o->min = -1;
        o->max = -1;
    }
    return 0;
}

static const struct luaL_Reg sparselib_instance[] = {
    { "__tostring", sparselib_tostring },
    { "__gc",       sparselib_gc       },
    { "__index",    sparselib_get      },
    { "__newindex", sparselib_set      },
    { NULL,         NULL               },
};

static const luaL_Reg sparselib_function_list[] =
{
    { "new",      sparselib_new      },
    { "set",      sparselib_set      },
    { "get",      sparselib_get      },
    { "min",      sparselib_min      },
    { "max",      sparselib_max      },
    { "range",    sparselib_range    },
    { "traverse", sparselib_traverse },
    { "concat",   sparselib_concat   },
    { "restore",  sparselib_restore  },
    { "wipe",     sparselib_wipe     },
    { NULL,       NULL               },
};

int luaopen_sparse(lua_State *L)
{
    luaL_newmetatable(L, SPARSE_METATABLE_INSTANCE);
    luaL_setfuncs(L, sparselib_instance, 0);
    lua_newtable(L);
    luaL_setfuncs(L, sparselib_function_list, 0);
    return 1;
}
