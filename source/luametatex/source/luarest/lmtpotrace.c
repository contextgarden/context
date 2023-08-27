/*
    See license.txt in the root of this project.
*/

/*tex 

   We use the library part of potrace:
   
       Copyright (C) 2001-2019 Peter Selinger. This file is part of Potrace. It is free software 
       and it is covered by the GNU General Public License. See the file COPYING for details.

   For the following code we used some of: 
   
       A simple and self-contained demo of the potracelib API.
       
   that comes with the file set. We can use a minimal set of files because potrace has been very 
   table for a while! 

   In case one wonders why we need it: one can think of vectorizing logos, old fonts, shapes of any 
   kind that can be used anywhere in \CONTEXT\ and \METAFUN. Just stay tuned. 

*/

# include <luametatex.h>
# include <potracelib.h>
# include <curve.h> 

# define POTRACE_METATABLE "potracer"
 
#define BM_WORDSIZE          ((int)sizeof(potrace_word))
#define BM_WORDBITS          (8*BM_WORDSIZE)
#define BM_HIBIT             (((potrace_word)1)<<(BM_WORDBITS-1))
#define bm_scanline(bm, y)   ((bm)->map + (y)*(bm)->dy)
#define bm_index(bm, x, y)   (&bm_scanline(bm, y)[(x)/BM_WORDBITS])
#define bm_mask(x)           (BM_HIBIT >> ((x) & (BM_WORDBITS-1)))
#define bm_range(x, a)       ((int)(x) >= 0 && (int)(x) < (a))
#define bm_safe(bm, x, y)    (bm_range(x, (bm)->w) && bm_range(y, (bm)->h))
#define BM_USET(bm, x, y)    (*bm_index(bm, x, y) |= bm_mask(x))
#define BM_UCLR(bm, x, y)    (*bm_index(bm, x, y) &= ~bm_mask(x))
#define BM_UPUT(bm, x, y, b) ((b) ? BM_USET(bm, x, y) : BM_UCLR(bm, x, y))
#define BM_PUT(bm, x, y, b)  (bm_safe(bm, x, y) ? BM_UPUT(bm, x, y, b) : 0)

/* also internal frees */

static potrace_bitmap_t *new_bitmap(int w, int h) 
{
    int dy = (w + BM_WORDBITS - 1) / BM_WORDBITS;
    potrace_bitmap_t *bitmap = (potrace_bitmap_t *) lmt_memory_malloc(sizeof(potrace_bitmap_t));
    if (! bitmap) {
        return NULL;
    }
    bitmap->w = w;
    bitmap->h = h;
    bitmap->dy = dy;
    bitmap->map = (potrace_word *) lmt_memory_calloc(h, dy * BM_WORDSIZE);
    if (! bitmap->map) {
        lmt_memory_free(bitmap);
        return NULL;
    } else {
        return bitmap;
    }
}

static void free_bitmap(potrace_bitmap_t *bitmap) 
{ 
    if (bitmap) {
        lmt_memory_free(bitmap->map);
    }
    lmt_memory_free(bitmap);
}

static const char* const policies[] = { "black", "white", "left", "right", "minority", "majority", "random", NULL }; 

typedef struct potracer { 
    potrace_state_t  *state;
    potrace_param_t  *parameters;
    potrace_bitmap_t *bitmap;
    const char       *bytes;
    int               width;
    int               height;
    int               swap;
    int               nx;
    int               ny;
    unsigned char     value;
    unsigned char     match;
    /* 7 bytes padding */
} potracer;

static potracer *potracelib_aux_maybe_ispotracer(lua_State *L)
{
    return (potracer *) luaL_checkudata(L, 1, POTRACE_METATABLE);
}

static unsigned char lmt_tochar(lua_State *L, int index)
{
    const char *s = lua_tostring(L, index);
    return s ? (unsigned char) s[0] : '0';
}

static void potracelib_aux_get_parameters(lua_State *L, int index, potracer *p) 
{
    if (lua_getfield(L, index, "size")      == LUA_TNUMBER ) { p->parameters->turdsize     =   lmt_tointeger(L, -1); } lua_pop(L, 1);
    if (lua_getfield(L, index, "threshold") == LUA_TNUMBER ) { p->parameters->alphamax     =   lua_tonumber (L, -1); } lua_pop(L, 1);
    if (lua_getfield(L, index, "tolerance") == LUA_TNUMBER ) { p->parameters->opttolerance =   lua_tonumber (L, -1); } lua_pop(L, 1);
    if (lua_getfield(L, index, "optimize")  == LUA_TBOOLEAN) { p->parameters->opticurve    =   lua_toboolean(L, -1); } lua_pop(L, 1);
    if (lua_getfield(L, index, "value")     == LUA_TSTRING ) { p->value                    =   lmt_tochar   (L, -1); } lua_pop(L, 1);
    if (lua_getfield(L, index, "negate")    == LUA_TBOOLEAN) { p->match                    = ! lua_toboolean(L, -1); } lua_pop(L, 1);

    if (lua_getfield(L, index, "policy") == LUA_TSTRING ) { 
        p->parameters->turnpolicy = luaL_checkoption(L, -1, "minority", policies); 
    } 
    lua_pop(L, 1);
}

static void potracelib_get_bitmap(potracer *p, unsigned char match) 
{
    /* Kind of suboptimal but it might change anyway so let the compiler worry about it. */

    const char *bytes = p->bytes;

    if (bytes) { 
        unsigned char c = p->value;
        if (p->swap) { 
            if (p->nx != 1 || p->ny != 1) { 
                /* maybe a 3x3 fast one */
                for (int x = 0; x < p->width; x += p->nx) {
                    int bp = (p->height/p->nx) * (x/p->nx);
                    for (int y = 0; y < p->height; y += p->ny) {
                        unsigned char b = (unsigned char) bytes[bp++] == c ? 1 : 0;
                        if (b) { 
                            int dy = p->height - y - 1;
                            for (int xn = 0; xn < p->nx; xn++) {
                                for (int yn = 0; yn < p->ny; yn++) {
                                    BM_PUT(p->bitmap, x + xn, dy - yn, b);
                                }
                            }
                        }
                    }
                }
            } else { /* fast one */
                for (int x = 0; x < p->width; x++) {
                    int bp = p->height * x;
                    for (int y = 0; y < p->height; y++) {
                        unsigned char b = (unsigned char) bytes[bp++] == c ? 1 : 0;
                        if (b) { 
                            BM_PUT(p->bitmap, x, p->height - y - 1, b);
                        }
                    }
                }
            }
        } else {
            if (p->nx != 1 || p->ny != 1) { 
                /* maybe a 3x3 fast one */
                for (int y = 0; y < p->height; y += p->ny) {
                    int bp = (p->width/p->ny) * (y/p->ny);
                    for (int x = 0; x < p->width; x += p->nx) {
                        unsigned char b = (unsigned char) bytes[bp++] == c ? 1 : 0;
                        if (b) { 
                            int dy = p->height - y - 1;
                            for (int xn = 0; xn < p->nx; xn++) {
                                for (int yn = 0; yn < p->ny; yn++) {
                                    BM_PUT(p->bitmap, x + xn, dy - yn, b);
                                }
                            }
                        }
                    }
                }
            } else { /* fast one */
                for (int y = 0; y < p->height; y++) {
                    int bp = p->width * y;
                    for (int x = 0; x < p->width; x++) {
                        unsigned char b = ((unsigned char) bytes[bp++] == c ? 1 : 0) == match;
                        if (b) { 
                            BM_PUT(p->bitmap, x, p->height - y - 1, b);
                        }
                    }
                }
            }
        }
    }
}


# define max_explode 3

static int potracelib_new(lua_State *L) 
{
    if (lua_type(L, 1) == LUA_TTABLE) {

        potracer p = { 
            .state      = NULL,
            .parameters = NULL,
            .bitmap     = NULL,
            .bytes      = NULL,
            .height     = 0,
            .width      = 0,
            .swap       = 0, 
            .nx         = 1,
            .ny         = 1,
            .value      = '1',
            .match      = 1,
        };

        size_t length = 0;

        if (lua_getfield(L, 1, "bytes")   == LUA_TSTRING)  { p.bytes   =   lua_tolstring(L, -1, &length); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "width")   == LUA_TNUMBER)  { p.width   =   lmt_tointeger(L, -1);          } lua_pop(L, 1);
        if (lua_getfield(L, 1, "height")  == LUA_TNUMBER)  { p.height  =   lmt_tointeger(L, -1);          } lua_pop(L, 1);
        if (lua_getfield(L, 1, "nx")      == LUA_TNUMBER)  { p.nx      =   lmt_tointeger(L, -1);          } lua_pop(L, 1);
        if (lua_getfield(L, 1, "ny")      == LUA_TNUMBER)  { p.ny      =   lmt_tointeger(L, -1);          } lua_pop(L, 1);
        if (lua_getfield(L, 1, "swap")    == LUA_TBOOLEAN) { p.swap    =   lua_toboolean(L, -1);          } lua_pop(L, 1);
        if (lua_getfield(L, 1, "value")   == LUA_TSTRING)  { p.value   =   lmt_tochar   (L, -1);          } lua_pop(L, 1);
        if (lua_getfield(L, 1, "negate")  == LUA_TBOOLEAN) { p.match   = ! lua_toboolean(L, -1);          } lua_pop(L, 1);
                                          
        if (! p.bytes) {
            return 0;
        } 

        if ((size_t) (p.width * p.height) > length) {
            return 0;
        }

        p.nx = p.nx < 1 ? 1 : (p.nx > max_explode ? max_explode : p.nx); 
        p.ny = p.ny < 1 ? 1 : (p.ny > max_explode ? max_explode : p.ny); 

        p.width *= p.nx;
        p.height *= p.ny;

        if (p.swap) { 
            int tmp = p.width; 
            p.width = p.height;
            p.height = tmp;
            tmp = p.nx; 
            p.nx = p.ny;
            p.ny = tmp;
        }

        p.parameters = potrace_param_default();
        if (! p.parameters) {
            free_bitmap(p.bitmap);
            return 0;
        }

        potracelib_aux_get_parameters(L, 1, &p); 

        lua_pop(L, 1);

        {
            potracer *pp = (potracer *) lua_newuserdatauv(L, sizeof(potracer), 0);
            if (pp) { 
                *pp = p; 
                luaL_getmetatable(L, POTRACE_METATABLE);
                lua_setmetatable(L, -2);
                return 1;
            }
        }
    }
    return 0;
}

static void potracelib_aux_free(potracer *p)
{
    if (p) { 
        if (p->state) { 
            potrace_state_free(p->state);
            p->state = NULL;
        }
        if (p->parameters) { 
            potrace_param_free(p->parameters);
            p->parameters = NULL;
        }
        if (p->bitmap) { 
            free_bitmap(p->bitmap);
            p->bitmap = NULL;
        } 
    }
}

static int potracelib_free(lua_State *L) 
{
    potracelib_aux_free(potracelib_aux_maybe_ispotracer(L));
    return 0;
}

static int aux_potracelib_entries(potracer *p)
{
    potrace_path_t *entry = p->state->plist;
    int entries = 0;
    while (entry) {
        entries++;
        entry = entry->next;
    }
    return entries; 
}

/* maybe also - last*/

static potrace_path_t *aux_potrace_goto_first(potracer *p, int nofentries, int *first, int *last, int *used) {
    potrace_path_t *entry = p->state->plist;
    if (*first && ! *last) {
        *last = nofentries; 
    }
    if (*last < 0) { 
        *last = nofentries - *last;
        if (*last < 0) { 
            *last = 1; 
        }
    }
    if (*first <= 0) { 
        *first = 1; 
    }
    if ((! *last) || (*last > nofentries)) { 
        *last = nofentries; 
    }
    if (*first > *last) {
        *first = *last; 
    }
    for (int i = 1; i < *first; i++) {
        entry = entry->next;
    }
    *used = *last - *first + 1; 
    return entry; 
}

static int potracelib_totable_normal(lua_State *L, potracer *p, int first, int last)
{
    int entries = 0;
    int nofentries = aux_potracelib_entries(p);
    int used = nofentries;
    potrace_path_t *entry = aux_potrace_goto_first(p, nofentries, &first, &last, &used);
    lua_createtable(L, used, 0);
    while (entry) {
        int segments = 0;
        int n = entry->curve.n;
        int m = n + 1;
        int *tag = entry->curve.tag;
        int sign = (entry->next == NULL || entry->next->sign == '+') ? 1 : 0;
        potrace_dpoint_t (*c)[3] =entry->curve.c;
        lua_createtable(L, m, sign ? 2 : 1);
        if (sign) {
            lua_push_boolean_at_key(L, sign, 1);
        }
        lua_push_integer_at_key(L, index, first + entries); /* for tracing when we select */
        lua_createtable(L, 2, 0);
        lua_push_number_at_index(L, 1, c[n-1][2].x);
        lua_push_number_at_index(L, 2, c[n-1][2].y);
        lua_rawseti(L, -2, ++segments);
        for (int i = 0; i < n; i++) {
            switch (tag[i]) {
                case POTRACE_CORNER:
                    lua_createtable(L, 2, 0);
                    lua_push_number_at_index(L, 1, c[i][1].x);
                    lua_push_number_at_index(L, 2, c[i][1].y);
                    lua_rawseti(L, -2, ++segments);
                    lua_createtable(L, 2, 0);
                    lua_push_number_at_index(L, 1, c[i][2].x);
                    lua_push_number_at_index(L, 2, c[i][2].y);
                    lua_rawseti(L, -2, ++segments);
                	break;
                case POTRACE_CURVETO:
                    lua_createtable(L, 6, 0);
                    lua_push_number_at_index(L, 1, c[i][2].x);
                    lua_push_number_at_index(L, 2, c[i][2].y);
                    lua_push_number_at_index(L, 3, c[i][0].x);
                    lua_push_number_at_index(L, 4, c[i][0].y);
                    lua_push_number_at_index(L, 5, c[i][1].x);
                    lua_push_number_at_index(L, 6, c[i][1].y);
                    lua_rawseti(L, -2, ++segments);
                	break;
            }
        }
        lua_rawseti(L, -2, ++entries);
        if (first + entries > last) { 
            break; 
        } else {
            entry = entry->next;
        }
    }
    return 1;
}

/*tex 
    These intermediate state tables are based on the debugger in |backend_eps.c|. There is no need 
    to speed them up. 
*/

static int potracelib_totable_debug(lua_State *L, potracer *p, int first, int last)
{
    int entries = 0;
    int nofentries = aux_potracelib_entries(p);
    int used = nofentries;
    potrace_path_t *entry = aux_potrace_goto_first(p, nofentries, &first, &last, &used);
    lua_createtable(L, used, 0);
    while (entry) { 
        point_t *pt = entry->priv->pt;
        int segments = 0;
        int sign = (entry->next == NULL || entry->next->sign == '+') ? 1 : 0;
        lua_newtable(L);
        if (sign) {
            lua_push_boolean_at_key(L, sign, 1);
        }
        lua_push_integer_at_key(L, index, first + entries); /* for tracing when we select */
        /*tex 
            We can get a redundant point 0 when we go left and come back right on the same line, 
            but we can simplify that at the receiving end. 
        */
        if (sign)  { 
            point_t cur = pt[entry->priv->len - 1];
            point_t prev = cur; 
            lua_push_number_at_index(L, ++segments, cur.x);
            lua_push_number_at_index(L, ++segments, cur.y);
            for (int i = 0; i < entry->priv->len; i++) {
                if (pt[i].x != cur.x && pt[i].y != cur.y) {
                    cur = prev;
                    lua_push_number_at_index(L, ++segments, cur.x);
                    lua_push_number_at_index(L, ++segments, cur.y);
                }
                prev = pt[i];
            }
            lua_push_number_at_index(L, ++segments, pt[entry->priv->len-1].x);
            lua_push_number_at_index(L, ++segments, pt[entry->priv->len-1].y);
        } else { 
            point_t cur = pt[0];
            point_t prev = cur; 
            lua_push_number_at_index(L, ++segments, cur.x);
            lua_push_number_at_index(L, ++segments, cur.y);
            for (int i = entry->priv->len - 1; i >= 0; i--) {
                if (pt[i].x != cur.x && pt[i].y != cur.y) {
                    cur = prev;
                    lua_push_number_at_index(L, ++segments, cur.x);
                    lua_push_number_at_index(L, ++segments, cur.y);
                }
                prev = pt[i];
            }
            lua_push_number_at_index(L, ++segments, pt[0].x);
            lua_push_number_at_index(L, ++segments, pt[0].y);
        }
        lua_rawseti(L, -2, ++entries);
        if (first + entries > last) { 
            break; 
        } else {
            entry = entry->next;
        }
    }
    return 1;
}

static int potracelib_totable(lua_State *L)
{
    int debug = lua_toboolean(L, 2);
    int first = lmt_optinteger(L, 3, 0);
    int last = lmt_optinteger(L, 4, first);
    lua_settop(L, 1);
    {
        potracer *p = potracelib_aux_maybe_ispotracer(L);
        if (p) { 
            return debug ? potracelib_totable_debug(L, p, first, last) : potracelib_totable_normal(L, p, first, last);
        } else {
            return 0;
        }
    }
}

static int potracelib_process(lua_State *L)
{
    potracer *p = potracelib_aux_maybe_ispotracer(L);
    if (p) { 
        potracelib_aux_get_parameters(L, 2, p); 
        if (p->bitmap) {
            free_bitmap(p->bitmap);
        }
        p->bitmap = new_bitmap(p->width, p->height);
        if (p->bitmap) {
            potracelib_get_bitmap(p, p->match);
            p->state = potrace_trace(p->parameters, p->bitmap);
            if (p->state && p->state->status == POTRACE_STATUS_OK) {
                lua_pushboolean(L, 1);
                return 1;
            }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int potracelib_tostring(lua_State * L)
 {
    potracer *p = potracelib_aux_maybe_ispotracer(L);
    if (p) {
        (void) lua_pushfstring(L, "<potracer %p>", p);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex 
    We keep the interface simple because we glue via \LUA\ and have to connect to \METAPOST\ too. 
*/

static const struct luaL_Reg potracelib_instance_metatable[] = {
    { "__tostring", potracelib_tostring },
    { "__gc",       potracelib_free     },
    { NULL,         NULL                },
};

static const luaL_Reg potracelib_function_list[] =
{
    { "new",        potracelib_new     },
    { "free",       potracelib_free    },
    { "process",    potracelib_process },
    { "totable",    potracelib_totable },
    /* */
    { NULL,    NULL             },
};

int luaopen_potrace(lua_State *L)
{
    luaL_newmetatable(L, POTRACE_METATABLE);
    luaL_setfuncs(L, potracelib_instance_metatable, 0);
    lua_newtable(L);
    luaL_setfuncs(L, potracelib_function_list, 0);
    return 1;
}