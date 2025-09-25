/*
    See license.txt in the root of this project.
*/

# include <luametatex.h>
# include "utilities/auxbytemaps.h"

# define BYTEMAP_METATABLE "bytemap"


typedef enum bytemap_loop {
    bytemap_loop_xy, 
    bytemap_loop_yx,
} bytemap_loop;

# define first_bytemap_loop bytemap_loop_xy
# define last_bytemap_loop  bytemap_loop_yx

static inline bytemap_data * bytemaplib_aux_valid(lua_State *L, int i)
{
    // we need a fast one for this 
    return (bytemap_data *) luaL_checkudata(L, i, BYTEMAP_METATABLE);
}

bytemap_data * bytemaplib_valid(lua_State *L, int i)
{
    return lua_type(L, i) == LUA_TUSERDATA ? (bytemap_data *) luaL_checkudata(L, i, BYTEMAP_METATABLE) : NULL;
}

static inline int bytemaplib_new(lua_State *L)
{
    int nx = lua_tointeger(L, 1);
    int ny = lua_tointeger(L, 2);
    int nz = lua_tointeger(L, 3);
    if (bytemap_okay(nx, ny, nz)) {
        int nn = nx * ny * nz;
        if (nn > 0) { 
            bytemap_data * bytemap = lua_newuserdatauv(L, sizeof(bytemap_data), 0);
            if (bytemap) { 
                luaL_setmetatable(L, BYTEMAP_METATABLE);
                bytemap_allocate(bytemap, nx, ny, nz, NULL);
            }
        }
        return 1;
    } else { 
        tex_formatted_warning("bytemaplib", "new overflow: %i x %i x #i", nx, ny, nz);
        return 0;
    }
}

static int bytemaplib_reset(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        bytemap_reset(bytemap, NULL);
    }
    return 0;
}

static int bytemaplib_reduce(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int method = lmt_optinteger(L, 2, bytemap_reduction_weighted);
        bytemap_reduce(bytemap, method, NULL);
    }
    return 0;
}

static int bytemaplib_slice_gray(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lua_tointeger(L, 2);
        int y = lua_tointeger(L, 3);
        int dx = lua_tointeger(L, 4);
        int dy = lua_tointeger(L, 5);
        int s = lua_tointeger(L, 6);
        bytemap_slice_gray(bytemap, x, y, dx, dy, s);
    }
    return 0;
}

static int bytemaplib_slice_rgb(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lua_tointeger(L, 2);
        int y = lua_tointeger(L, 3);
        int dx = lua_tointeger(L, 4);
        int dy = lua_tointeger(L, 5);
        int r = lua_tointeger(L, 6);
        int g = lua_tointeger(L, 7);
        int b = lua_tointeger(L, 8);
        bytemap_slice_rgb(bytemap, x, y, dx, dy, r, g, b);
    }
    return 0;
}

static int bytemaplib_slice_range(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lua_tointeger(L, 2);
        int y = lua_tointeger(L, 3);
        int dx = lua_tointeger(L, 4);
        int dy = lua_tointeger(L, 5);
        int min = lua_tointeger(L, 6);
        int max = lua_tointeger(L, 7);
        bytemap_slice_range(bytemap, x, y, dx, dy, min, max);
    }
    return 0;
}

static int bytemaplib_bounds(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int value = lua_tointeger(L, 2);
        int llx = 0;
        int lly = 1;
        int urx = bytemap->nx - 1;
        int ury = bytemap->ny - 1;
        bytemap_bounds(bytemap, value, &llx, &lly, &urx, &ury);
        lua_pushinteger(L, llx);
        lua_pushinteger(L, lly);
        lua_pushinteger(L, urx);
        lua_pushinteger(L, ury);
        return 4;
    }
    return 0;
}

static int bytemaplib_clip(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) {
        int value = lua_tointeger(L, 2);
        bytemap_clip(bytemap, value, NULL);
    }
    return 0;
}

static int bytemaplib_copy(lua_State *L)
{
    bytemap_data *source = bytemaplib_aux_valid(L, 1);
    if (source) { 
        bytemap_data *target = NULL;
        if (lua_gettop(L) > 1) {
            target = bytemaplib_aux_valid(L, 2);
        } else { 
            target = lua_newuserdatauv(L, sizeof(bytemap_data), 0);
            if (target) { 
                luaL_setmetatable(L, BYTEMAP_METATABLE);
                bytemap_wipe(target);
            }
        }
        if (target) { 
            bytemap_copy(source, target, NULL);
            return 1;
        }
    }
    return 0;
}

static int bytemaplib_has_byte_gray(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int s = lua_tointeger(L, 2);
        lua_pushboolean(L, bytemap_has_byte_gray(bytemap, s));
        return 1;
    }
    return 0;
}

static int bytemaplib_has_byte_range(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int min = lua_tointeger(L, 2);
        int max = lua_tointeger(L, 3);
        lua_pushboolean(L, bytemap_has_byte_range(bytemap, min, max));
        return 1;
    }
    return 0;
}

static int bytemaplib_has_byte_rgb(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int r = lmt_tointeger(L, 2);
        int g = lmt_tointeger(L, 3);
        int b = lmt_tointeger(L, 4);
        lua_pushboolean(L, bytemap_has_byte_rgb(bytemap, r, g, b));
    }
    return 0;
}

static int bytemaplib_set_gray(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lmt_tointeger(L, 2);
        int y = lmt_tointeger(L, 3);
        int s = lmt_tointeger(L, 4);
        bytemap_set_gray(bytemap, x, y, s);
    }
    return 0;
}

static int bytemaplib_set_rgb(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lmt_tointeger(L, 2);
        int y = lmt_tointeger(L, 3);
        int r = lmt_tointeger(L, 4);
        int g = lmt_tointeger(L, 5);
        int b = lmt_tointeger(L, 6);
        bytemap_set_rgb(bytemap, x, y, r, g, b);
    }
    return 0;
}

static int bytemaplib_get_byte(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lmt_tointeger(L, 2);
        int y = lmt_tointeger(L, 3);
        int z = lmt_tointeger(L, 3);
        lua_pushinteger(L, bytemap_get_byte(bytemap, x, y, z));
        return 1;
    }
    return 0;
}

static int bytemaplib_get_bytes(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int x = lmt_tointeger(L, 2);
        int y = lmt_tointeger(L, 3);
        unsigned char b1, b2, b3;
        bytemap_get_bytes(bytemap, x, y, &b1, &b2, &b3);
        if (bytemap->nz == 1) { 
            lua_pushinteger(L, b1);
            return 1;
        } else {
            lua_pushinteger(L, b1);
            lua_pushinteger(L, b2);
            lua_pushinteger(L, b3);
            return 3;
        }
    }
    return 0;
}

static int bytemaplib_get_value(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) { 
        int nx = 0;
        int ny = 0;
        int nz = 0;
        char * s = bytemap_get_value(bytemap, &nx, &ny, &nz);
        lua_pushlstring(L, s, nx * ny * nz);
        lua_pushinteger(L, nx);
        lua_pushinteger(L, ny);
        lua_pushinteger(L, nz);
        lmt_memory_free(s);
        return 4;
    }
    return 0;
}

/* 
    This one is modelled after the effects octave one but here there is only some gain when we
    want access to the values so when the third argument in true because then we save a call 
    and a userdata lookup (which we can actually speed up anyway). 
*/

/* bytemap function [existing] [looptype] */

static inline unsigned char clipped(int i)
{
    return i < 0 ? 0 : i > 255 ? 255 : (unsigned char) i;
}

static void bytemaplib_aux_loop(lua_State * L,  unsigned char * bytemap, int nx, int ny, int nz, int slot)
{
    if (bytemap) {
        int fn = lua_type(L, slot) == LUA_TFUNCTION;
        if (fn) {
            int existing = lua_toboolean(L, slot + 1) ? nz : 0;
            int loop = lua_tointeger(L, slot + 2);
            lua_settop(L, slot);
            if (loop == bytemap_loop_yx) {
                unsigned char *p = bytemap;
                for (int y = 0; y < ny; y++) {
                    for (int x = 0; x < nx; x++) {
                        /* we need to retain the function */
                        lua_pushvalue(L, slot);
                        /* pass to function */
                        lua_pushinteger(L, x);
                        lua_pushinteger(L, y);
                        if (existing == 3) {
                            lua_pushinteger(L, (int) *p);
                            lua_pushinteger(L, (int) *(p+1));
                            lua_pushinteger(L, (int) *(p+2));
                        } else if (existing == 1) { 
                            lua_pushinteger(L, (int) *p);
                        }
                        /* call function */
                        if (lua_pcall(L, existing + 2, nz, 0) != 0) { 
                            tex_formatted_warning("bytemaplib", "run bytemap: %s", lua_tostring(L, -1));
                        }
                        /* use results */
                        if (nz == 3) { 
                            *p++ = clipped(lmt_roundnumber(L, -3));
                            *p++ = clipped(lmt_roundnumber(L, -2));
                        }
                        *p++ = clipped(lmt_roundnumber(L, -1));
                        /* wrap up */
                        lua_settop(L, slot);
                    }
                }
            } else {
                unsigned char *p = bytemap;
                for (int x = 0; x < nx; x++) {
                    for (int y = 0; y < ny; y++) {
                        int i = ((ny - y - 1) * nx * nz) + x * nz;
                        /* we need to retain the function */
                        lua_pushvalue(L, slot);
                        /* pass to function */
                        lua_pushinteger(L, x);
                        lua_pushinteger(L, y);
                        if (existing == 3) {
                            lua_pushinteger(L, (int) p[i  ]);
                            lua_pushinteger(L, (int) p[i+1]);
                            lua_pushinteger(L, (int) p[i+2]);
                        } else if (existing == 1) {  
                            lua_pushinteger(L, (int) p[i  ]);
                        }
                        /* call function */
                        if (lua_pcall(L, existing + 2, nz, 0) != 0) { 
                            tex_formatted_warning("bytemaplib", "run bytemap: %s", lua_tostring(L, -1));
                        }
                        /* use results */
                        if (nz == 3) { 
                            p[i++] = clipped(lmt_roundnumber(L, -3)); /* slot + 1 */
                            p[i++] = clipped(lmt_roundnumber(L, -2)); /* slot + 2 */
                        }
                        p[i] = clipped(lmt_roundnumber(L, -1)); /* slot + 1 */
                        /* wrap up */
                        lua_settop(L, slot);
                    }
                }
            }
        }
    }
}

static int bytemaplib_process(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap && bytemap->data) {
        bytemaplib_aux_loop(L, bytemap->data, bytemap->nx, bytemap->ny, bytemap->nz, 2);
    }
    return 0;
}

static int bytemaplib_downsample(lua_State *L)
{
    bytemap_data *source = bytemaplib_aux_valid(L, 1);
    bytemap_data *target = bytemaplib_aux_valid(L, 2);
    if (source && target) {
        int r = lmt_optinteger(L, 3, 2);
        bytemap_downsample(source, target, r);
    }
    return 0;
}

static int bytemaplib_downgrade(lua_State *L)
{
    bytemap_data *source = bytemaplib_aux_valid(L, 1);
    bytemap_data *target = bytemaplib_aux_valid(L, 2);
    if (source && target) {
        int r = lmt_optinteger(L, 3, 2);
        bytemap_downgrade(source, target, r);
    }
    return 0;
}

int bytemaplib_bytemapped(lua_State * L, unsigned char * bytemap, int nx, int ny, int nz, int slot)
{
    if (bytemap && nx > 0 && ny > 0 && (nz == 1 || nz == 3)) {
        bytemaplib_aux_loop(L, bytemap, nx, ny, nz, slot);
    }
    return 0;
}

static int bytemaplib_tostring(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap) {
        lua_pushfstring(L, "<bytemap %p : %d %d %d>", bytemap, bytemap->nx, bytemap->ny, bytemap->nz); /* details */
        return 1;
    } else {
        return 0;
    }
    return 0;
}

static int bytemaplib_gc(lua_State *L)
{
    bytemap_data *bytemap = bytemaplib_aux_valid(L, 1);
    if (bytemap && bytemap->data) {
        lmt_memory_free(bytemap->data);
    }
    return 0;
}

static const luaL_Reg bytemaplib_metatable[] =
{
    { "__tostring", bytemaplib_tostring },
    { "__gc",       bytemaplib_gc       },
    { NULL,         NULL                },
};
 
static struct luaL_Reg bytemaplib_function_list[] = {
    { "new",          bytemaplib_new            },
    { "reset",        bytemaplib_reset          },
    { "reduce",       bytemaplib_reduce         },
    { "slicegray",    bytemaplib_slice_gray     },
    { "slicergb",     bytemaplib_slice_rgb      },
    { "slicerange",   bytemaplib_slice_range    },
    { "bounds",       bytemaplib_bounds         },
    { "clip",         bytemaplib_clip           },
    { "copy",         bytemaplib_copy           },
    { "hasbytegray",  bytemaplib_has_byte_gray  },
    { "hasbyterange", bytemaplib_has_byte_range },
    { "hasbytergb",   bytemaplib_has_byte_rgb   },
    { "setgray",      bytemaplib_set_gray       },
    { "setrgb",       bytemaplib_set_rgb        },
    { "getbyte",      bytemaplib_get_byte       },
    { "getbytes",     bytemaplib_get_bytes      },
    { "getvalue",     bytemaplib_get_value      },
    { "process",      bytemaplib_process        },
    { "downsample",   bytemaplib_downsample     },
    { "downgrade",    bytemaplib_downgrade      },
    { NULL,           NULL                      },
};

int luaopen_bytemap(lua_State *L)
{
    luaL_newmetatable(L, BYTEMAP_METATABLE);
    luaL_setfuncs(L, bytemaplib_metatable, 0);
    lua_newtable(L);
    luaL_setfuncs(L, bytemaplib_function_list, 0);
    return 1;
}
