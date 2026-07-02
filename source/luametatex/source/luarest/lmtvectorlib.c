/*
    See license.txt in the root of this project.
*/

/*tex

    This started as an experiment by Mikael and Hans in the perspective of 3D experiments in
    \METAPOST\ with the \LUA\ interface. It is also a kind of follow up on the \type {matrix}
    module from which we took some of the code. So we have a mix of Jeong Dalyoung, Mikael
    Sundqvist & Hans Hagen vector operation code here. More methods might be added. You can find
    some info in articles we wrote about it.

    This module is sort of generic but also geared at using on combination with \METAPOST, which
    is why we have a few public functions. For that we have extra helpers that work on meshes
    and in the end we mostly use those mesh and contour features. For the moment we put all vector
    related code here but in the future we might split this up as we like. After all this is
    mostly used low level and as a playground for Hans, Mikael and Keith. We report on this in
    articles, wrap-ups and manuals.

    Quite a bit of the code below deals with z-buffering, implicit meshes, overlapping meshes
    and stippling, something we started workign on after BachoTeX 2026. It just made sense to add
    it here. Much of that are not user-level helpers and all of this is very much related to \LUA\
    code a the \LUAMETAFUN\ end. We don't make generic libraries that have no real use outside
    \CONTEXT) but tune them to what we need.

    Because meshes and points (and zbuffers) can have different configurations we have to rely on
    allocating memory in addition to the userdata, so we need \type {__gc} entries. This is a bit
    of a pain because we would like to prematurely call the collector in order to free memory of
    objects that are no longer in use. An explicit collect will not collect all objects. There is
    a danger of shared objects being freed by such an explicit call so we have extra checking
    going on but we can't catch all. So .. only use explicit collecting when you know what you're
    doing. At some point basic memory tracing was added here so that we can act upon excessive
    consumption if needed. It's mostly there for us, for tracing.

*/

# include <luametatex.h>
# include "libraries/triangles/triangles.h"

/*tex See |lmtinterface.h| for |VECTOR_METATABLE_INSTANCE|. */
/*tex See |lmtinterface.h| for |MESH_METATABLE_INSTANCE|. */

/*tex

    We can use a proper memory blob as elsewhere .. todo .. some shared mechanism for this but
    with little overhead. There are only a few libraries that use as much memory as this one
    does anyway.

*/

size_t memoryused = 0;

void * vectorlib_memory_malloc(size_t n)
{
    void *p = lmt_memory_malloc(n);
    if (p) {
     // printf("M + %i\n",(int) n);
        memoryused += n;
    }
    return p;
}

void * vectorlib_memory_realloc(void *p, size_t n, size_t m)
{
    void *q = lmt_memory_realloc(p, m);
    if (q) {
     // printf("R + %i\n",(int) m);
        memoryused += m;
    }
 // printf("R - %i\n",(int) n);
    memoryused -= n;
    return q;
}

void * vectorlib_memory_calloc(size_t n, size_t m)
{
    void *p = lmt_memory_calloc(n, m);
    if (p) {
     // printf("C + %i\n",(int) n * m);
        memoryused += n * m;
    }
    return p;
}

void vectorlib_memory_free(void * p, size_t n)
{
    if (p) {
        memoryused -= n;
     // printf("F - %i\n",(int) n);
        lmt_memory_free(p);
    }
}

static const char *mesh_names[triangle_7_mesh_type+1] = {
    [no_mesh_type]         = "no",
    [dot_mesh_type]        = "dot",
    [line_mesh_type]       = "line",
    [triangle_mesh_type]   = "triangle",
    [quad_mesh_type]       = "quad",
    /* these are virtual that is: point indices calculated on demand */
    [triangle_5_mesh_type] = "triangle type 5",
    [triangle_6_mesh_type] = "triangle type 6",
    [triangle_7_mesh_type] = "triangle type 7"
};

static int vectorlib_mesh_gettypevalues(lua_State *L)
{
    lua_createtable(L, 2, 5);
    for (int i = no_mesh_type; i < triangle_7_mesh_type; i++) {
        lua_set_string_by_index(L, i, mesh_names[i]);
    }
    return 1;
}

/*tex

    We need to be way above EPSILON in triangles.c because otherwise we get too many false
    positives at that end! For practical reason we now use a configurable epsilon because we
    need to interplay nicely with the overlap detection. Alas.

    \starttyping
    const double p_epsilon =  0.000001;
    const double m_epsilon = -0.000001;

    static inline int iszero(double d) {
        return d > m_epsilon && d < p_epsilon;
    }
    \stoptyping

    So we now do this:

*/

# define vector_epsilon_default 1.0e-06

static double vector_epsilon = vector_epsilon_default;

# define ISZERO(d) (fabs(d) < epsilon)

static int vectorlib_setepsilon(lua_State *L)
{
    vector_epsilon = lmt_optdouble(L, 1, vector_epsilon_default);
    return 1;
}

static int vectorlib_getepsilon(lua_State *L)
{
    lua_pushnumber(L, lua_toboolean(L, 1) ? vector_epsilon_default : vector_epsilon);
    return 1;
}

static int vectorlib_iszero(lua_State *L)
{
    double epsilon = lmt_optdouble(L, 2, vector_epsilon);
    lua_pushboolean(L, ISZERO(lua_tonumber(L, 1)));
    return 1;
}

static inline int vectorlib_aux_zero_in_column(const vector a, int c, double epsilon)
{
    for (int r = 0; r < a->rows; r++) {
        if (ISZERO(a->data[r * a->columns + c])) {
            return 1;
        }
    }
    return 0;
}

// static inline int vectorlib_aux_zero_in_row(const vector a, int r, double epsilon)
// {
//     for (int c = 0; c < a->columns; c++) {
//         if (ISZERO(a->data[r * a->columns + c])) {
//             return 1;
//         }
//     }
//     return 0;
// }

/* let the compiled deal with this: */

/* memcpy(v->data, a->data,a->size * sizeof(double)); */

inline static void vectorlib_aux_copy_data(vector v, const vector a)
{
    /* maybe more */
    for (int i = 0; i < a->size; i++) {
        v->data[i] = a->data[i];
    }
}

/*
     We let \LUA\ manage the temporary vectors if needed which sometimes means that we push too
     many intermediate nil's too but it's harmless.
*/

static inline vector vectorlib_aux_push(lua_State *L, int r, int c, int s)
{
    if (r >= max_vector_rows || c >= max_vector_columns || r*c > max_vector) {
        tex_formatted_error("vector lib", "you can have %i rows, %i columns and at most %i entries", max_vector_rows, max_vector_columns, max_vector);
        return NULL;
    } else {
        vector v = lua_newuserdatauv(L, 6 * sizeof(int) + r * c * sizeof(double), 0);
        if (v && r > 0 && c > 0) {
            v->rows     = r;
            v->columns  = c;
            v->type     = generic_type;
            v->stacking = s;
            v->index    = 0;
            v->size     = r * c;
            lua_get_metatablelua(vector_instance);
            lua_setmetatable(L, -2);
        }
        return v;
    }
}

static vector vectorlib_aux_maybe_isvector(lua_State *L, int index)
{
    vector v = lua_touserdata(L, index);
    if (v && lua_getmetatable(L, index)) {
        lua_get_metatablelua(vector_instance);
        if (! lua_rawequal(L, -1, -2)) {
            v = NULL;
        }
        lua_pop(L, 2);
    }
    return v;
}

static int vectorlib_vector_valid(lua_State *L)
{
    lua_pushboolean(L, vectorlib_aux_maybe_isvector(L, 1) ? 1 : 0);
    return 1;
}

static int vectorlib_type(lua_State *L)
{
    if (vectorlib_aux_maybe_isvector(L, 1)) {
        lua_push_key(vector);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* tex Only |{ { 1,2,3 }, { 4,5,6 } }| here as we can mix. */

static int vectorlib_aux_be_nice(lua_State *L, int index)
{
    /* We know that we have a table. */
    int rows = (int) lua_rawlen(L, index);
    int columns = lua_rawgeti(L, index, 1) == LUA_TTABLE ? (int) lua_rawlen(L, -1) : 0;
    lua_pop(L, 1);
    if (rows && columns) {
        vector v = vectorlib_aux_push(L, rows, columns, 0);
        for (int r = 0; r < rows; r++) {
            long target = r * columns;
            if (lua_rawgeti(L, index, r + 1) == LUA_TTABLE) {
                for (int c = 0; c < columns; c++) {
                    v->data[target++] = lua_rawgeti(L, -1, c + 1) == LUA_TNUMBER ? lua_tonumber(L, -1) : 0.0;
                    lua_pop(L, 1);
                }
            } else {
                for (int c = 0; c < columns; c++) {
                    v->data[target++] = 0.0;
                }
            }
            lua_pop(L, 1);
        }
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

inline static vector vectorlib_aux_get(lua_State *L, int index)
{
    switch (lua_type(L, index)) {
        case LUA_TUSERDATA:
            {
                vector v = lua_touserdata(L, index);
                if (v && lua_getmetatable(L, index)) {
                    lua_get_metatablelua(vector_instance);
                    if (! lua_rawequal(L, -1, -2)) {
                        v = NULL;
                    }
                    lua_pop(L, 2);
                }
                return v;
            }
        case LUA_TTABLE:
            {
                vectorlib_aux_be_nice(L, index);
                if (lua_type(L, -1) == LUA_TUSERDATA) {
                    vector v = lua_touserdata(L, -1);
                    lua_replace(L, index);
                    return v;
                } else {
                    lua_pop(L, 1);
                    break;
                }
            }
        default:
            break;
    }
    return NULL;
}

static int vectorlib_new(lua_State *L)
{
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            {
                /* local v = vector.new( 2, 3                       ) */
                /* local v = vector.new( 2, 3,   1,2,3,     4,5,6   ) */
                /* local v = vector.new( 2, 3, { 1,2,3 }, { 4,5,6 } ) */ /* maybe */
                /* local v = vector.new( 2, 3, { 1,2,3  ,   4,5,6 } ) */ /* maybe */
                int t = lua_gettop(L) - 2;
                vector v = vectorlib_aux_push(L, lmt_optinteger(L, 1, 1), lmt_optinteger(L, 2, 1), 0);
                if (t) {
                    if (t > v->size) {
                        t = v->size;
                    }
                    if (t < v->size) {
                        memset(v->data, 0, v->size * sizeof(double));
                        for (int i = 0; i < t; i++) {
                            v->data[i] = lua_type(L, i + 3) == LUA_TNUMBER ? lua_tonumber(L, i + 3) : 0.0;
                        }
                        if (t > 1) {
                            for (int i = t; i < v->size; i += t) {
                                memcpy(&(v->data[i]), v->data, sizeof(double) * t);
                            }
                        }
                    } else {
                        for (int i = 0; i < t; i++) {
                            v->data[i] = lua_type(L, i + 3) == LUA_TNUMBER ? lua_tonumber(L, i + 3) : 0.0;
                        }
                    }
                } else {
                    memset(v->data, 0, v->size * sizeof(double));
                }
                return 1;
            }
        case LUA_TTABLE:
           {
                int n = (int) lua_rawlen(L, 1);
                int t = lua_rawgeti(L, 1, 1);
                lua_pop(L, 1);
                switch (t) {
                    case LUA_TNUMBER:
                        /* local v = vector.new(   { 1,2,3 }, { 4,5,6  }  ) */
                        {
                            int columns = n;
                            int rows = lua_gettop(L);
                            if (rows && columns) {
                                vector v = vectorlib_aux_push(L, rows, columns, 0);
                                for (int r = 0; r < rows; r++) {
                                    long index = r * columns;
                                    if (lua_type(L, r + 1) == LUA_TTABLE) {
                                        for (int c = 0; c < columns; c++) {
                                            if (lua_rawgeti(L, r + 1, c + 1) == LUA_TNUMBER) {
                                                v->data[index++] = lua_tonumber(L, -1);
                                            } else {
                                                v->data[index++] = 0.0;
                                            }
                                            lua_pop(L, 1);
                                        }
                                    } else {
                                        for (int c = 0; c < columns; c++) {
                                            v->data[index++] = 0.0;
                                        }
                                    }
                                }
                                return 1;
                            } else {
                                break;
                            }
                        }
                    case LUA_TTABLE:
                        {
                            /* local v = vector.new( { { 1,2,3 }, { 4,5,6 } } ) */
                            int type = (int) lua_rawgeti(L, 1, 1);
                            int rows = (int) lua_rawlen(L, 1);
                            int columns = 0;
                            switch (type) {
                                case LUA_TTABLE:
                                    columns = (int) lua_rawlen(L, -1);
                                    break;
                                case LUA_TUSERDATA:
                                    {
                                        vector a = vectorlib_aux_get(L, 1);
                                        if (a) {
                                            columns = a->columns;
                                        }
                                        break;
                                    }
                            }
                            lua_pop(L, 1);
                            if (rows && columns) {
                                vector v = vectorlib_aux_push(L, rows, columns, 0);
                                long index = 0;
                                for (int r = 1; r <= rows; r++) {
                                    switch (lua_rawgeti(L, 1, r)) {
                                        case LUA_TTABLE:
                                            {
                                                for (int c = 1; c <= columns; c++) {
                                                    if (lua_rawgeti(L, -1, c) == LUA_TNUMBER) {
                                                        v->data[index++] = lua_tonumber(L, -1);
                                                    } else {
                                                        v->data[index++] = 0.0;
                                                    }
                                                    lua_pop(L, 1);
                                                }
                                                break;
                                            }
                                        case LUA_TUSERDATA:
                                            {
                                                vector a = vectorlib_aux_get(L, 1);
                                                if (a && a->columns * a->rows == columns) {
                                                    long source = 0;
                                                    for (int c = 0; c < columns; c++) {
                                                        v->data[index++] = a->data[source++];
                                                    }
                                                    break;
                                                } else {
                                                    /* fall through */
                                                }
                                            }
                                        default:
                                            {
                                                for (int c = 0; c < columns; c++) {
                                                    v->data[index++] = 0.0;
                                                }
                                                break;
                                            }
                                    }
                                    lua_pop(L, 1);
                                }
                                return 1;
                            } else {
                                break;
                            }
                        }
                    default:
                        break;
                }
                break;
            }
    }
    lua_pushnil(L);
    return 0;
}

static inline int vectorlib_onerow(lua_State *L)
{
    int t = lua_gettop(L);
    if (t) {
        vector v = vectorlib_aux_push(L, 1, t, 0);
        if (v) {
            for (int i = 0; i < t; i++) {
                v->data[i] = lua_tonumber(L, i + 1);
            }
            return 1;
        }
    }
    return 0;
}

static inline int vectorlib_onecolumn(lua_State *L)
{
    int t = lua_gettop(L);
    if (t) {
        vector v = vectorlib_aux_push(L, t, 1, 0);
        if (v) {
            for (int i = 0; i < t; i++) {
                v->data[i] = lua_tonumber(L, i + 1);
            }
            return 1;
        }
    }
    return 0;
}

vector vectorlib_get(lua_State *L, int index)
{
    if (lua_type(L, index) == LUA_TUSERDATA) {
        vector v = lua_touserdata(L, index);
        if (v && lua_getmetatable(L, index)) {
            lua_get_metatablelua(vector_instance);
            if (! lua_rawequal(L, -1, -2)) {
               v = NULL;
            }
            lua_pop(L, 2);
        }
        return v;
    } else {
        return NULL;
    }
}

static int vectorlib_tostring(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        lua_pushfstring(L, "<vector %d x %d : %p>", v->rows, v->columns, v);
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_totable(lua_State *L)
{
    vector v = vectorlib_aux_maybe_isvector(L, 1);
    if (v) {
        long source = 0;
        if (lua_toboolean(L, 2)) {
            lua_createtable(L, v->size, 0);
            for (int i = 1; i <= v->size; i++) {
                lua_pushnumber(L, v->data[source++]);
                lua_rawseti(L, -2, i);
            }
        } else {
            lua_createtable(L, v->rows, 0);
            for (int r = 1; r <= v->rows; r++) {
                lua_createtable(L, v->columns, 0);
                for (int c = 1; c <= v->columns; c++) {
                    lua_pushnumber(L, v->data[source++]);
                    lua_rawseti(L, -2, c);
                }
                lua_rawseti(L, -2, r);
            }
        }
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_aux_copy(lua_State *L, int index)
{
    vector a = vectorlib_aux_get(L, index);
    if (a) {
        /* could be a mem copy */
        vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
        if (v) {
            v->type = a->type;
            vectorlib_aux_copy_data(v, a);
            return 1;
        }
    }
    return 0;
}

static int vectorlib_copy(lua_State *L)
{
    return vectorlib_aux_copy(L, 1);
}

static int vectorlib_eq(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    int result = 1;
    if (a && b && a->rows == b->rows && a->columns == b->columns) {
        /* we can do a memcmp but we can have negative zero etc */
        for (int i = 0; i < b->size; i++) {
            if (a->data[i] != b->data[i]) {
                result = 0;
                break;
            }
        }
    } else {
        result = 0;
    }
    lua_pushboolean(L, result);
    return 1;
}

static int vectorlib_add(lua_State *L) {
    if (lua_type(L, 1) == LUA_TNUMBER) {
        vector b = vectorlib_aux_get(L, 2);
        if (b) {
            double d = lua_tonumber(L, 1);
            vector v = vectorlib_aux_push(L, b->rows, b->columns, b->stacking);
            for (int i = 0; i < b->size; i++) {
                v->data[i] = b->data[i] + d;
            }
        } else {
            lua_pushnil(L);
        }
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        vector a = vectorlib_aux_get(L, 1);
        if (a) {
            double d = lua_tonumber(L, 2);
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            for (int i = 0; i < a->size; i++) {
                v->data[i] = a->data[i] + d;
            }
        } else {
            lua_pushnil(L);
        }
    } else {
        vector a = vectorlib_aux_get(L, 1);
        vector b = vectorlib_aux_get(L, 2);
        if (a && b && a->rows == b->rows && a->columns == b->columns) {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            for (int i = 0; i < a->size; i++) {
                v->data[i] = a->data[i] + b->data[i];
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int vectorlib_sub(lua_State *L) {
    if (lua_type(L, 1) == LUA_TNUMBER) {
        vector b = vectorlib_aux_get(L, 2);
        if (b) {
            double d = lua_tonumber(L, 1);
            vector v = vectorlib_aux_push(L, b->rows, b->columns, b->stacking);
            for (int i = 0; i < b->size; i++) {
                v->data[i] = b->data[i] - d;
            }
        } else {
            lua_pushnil(L);
        }
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        vector a = vectorlib_aux_get(L, 1);
        if (a) {
            double d = lua_tonumber(L, 2);
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            for (int i = 0; i < a->size; i++) {
                v->data[i] = a->data[i] - d;
            }
        } else {
            lua_pushnil(L);
        }
    } else {
        vector a = vectorlib_aux_get(L, 1);
        vector b = vectorlib_aux_get(L, 2);
        if (a && b && a->rows == b->rows && a->columns == b->columns) {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            for (int i = 0; i < a->size; i++) {
                v->data[i] = a->data[i] - b->data[i];
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int vectorlib_product(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    if (a && b && a->columns == b->rows) {
        vector v = vectorlib_aux_push(L, a->rows, b->columns, b->stacking); /* not a->stacking */
        for (int ra = 0; ra < a->rows; ra++) {
            /* loop over rows a : a[r] */
            for (int cb = 0; cb < b->columns; cb++) {
                /* loop over columns b */
                double d = 0;
                for (int i = 0; i < b->rows; i++) {
                    /* loop over rows b */
                    d = d + a->data[ra * a->columns + i] * b->data[i * b->columns + cb];
                }
                /* result [ra][cb] */
                v->data[ra * b->columns + cb] = d;
            }
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_mul(lua_State *L) {
    if (lua_type(L, 1) == LUA_TNUMBER) {
        vector b = vectorlib_aux_get(L, 2);
        if (b) {
            double d = lua_tonumber(L, 1);
            if (d == 1.0) {
                vectorlib_aux_copy(L, 2);
            } else {
                vector v = vectorlib_aux_push(L, b->rows, b->columns, b->stacking);
                for (int i = 0; i < b->size; i++) {
                    v->data[i] = b->data[i] * d;
                }
            }
        } else {
            lua_pushnil(L);
        }
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        vector a = vectorlib_aux_get(L, 1);
        if (a) {
            double d = lua_tonumber(L, 2);
            if (d == 1.0) {
                vectorlib_aux_copy(L, 1);
            } else {
                vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
                for (int i = 0; i < a->size; i++) {
                    v->data[i] = a->data[i] * d;
                }
            }
        } else {
            lua_pushnil(L);
        }
    } else {
        return vectorlib_product(L);
    }
    return 1;
}

static int vectorlib_div(lua_State *L) {
    if (lua_type(L, 1) == LUA_TNUMBER) {
        lua_pushnil(L);
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        vector a = vectorlib_aux_get(L, 1);
        if (a) {
            double d = lua_tonumber(L, 2);
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            for (int i = 0; i < a->size; i++) {
                /* Should we check for d == 0.0 or not here? */
                v->data[i] = a->data[i] / d;
            }
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_neg(lua_State *L) {
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
        for (int i = 0; i < a->size; i++) {
            v->data[i] = - a->data[i];
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_getrow(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        int row = lmt_tointeger(L, 2) - 1;
        if (row >= 0 && row < v->rows) {
            long source = row * v->columns;
            if (lua_toboolean(L, 3)) {
                long target = 1;
                lua_createtable(L, v->columns, 0);
                for (int c = 0; c < v->columns; c++) {
                    lua_pushnumber(L, v->data[source++]);
                    lua_rawseti(L, -2, target++);
                }
                return 1;
            } else {
                for (int c = 0; c < v->columns; c++) {
                    lua_pushnumber(L, v->data[source++]);
                }
                return v->columns;
            }
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_getvalue(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        long index = lmt_tolong(L, 2);
        lua_pushnumber(L, index > 0 && index <= v->size ? v->data[index-1] : 0);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_setvalue(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        long index = lmt_tolong(L, 2);
        if (index > 0 && index <= v->size) {
            v->data[index-1] = lua_type(L, 3) == LUA_TNUMBER ? lua_tonumber(L, 3) : 0;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_getmemory(lua_State *L)
{
    lua_pushinteger(L, memoryused);
    return 1;
}

static int vectorlib_getsize(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    lua_pushinteger(L, a ? a->index : 0);
    return 1;
}

static int vectorlib_getlength(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        lua_pushinteger(L, v->rows);
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_setnext(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int n = a->columns;
        int i = a->index;
        if (i + n - 1 < a->size * n) {
            if (lua_type(L, 2) == LUA_TTABLE) {
                int m = (int) lua_rawlen(L, 2);
                if (m > n) {
                    m = n;
                }
                for (int c = 1; c <= m; c++) {
                    lua_rawgeti(L, 2, c);
                    a->data[i++] = lua_tonumber(L, -1);
                    lua_pop(L, 1);
                }
            } else {
                int slot = 2;
                for (int c = 1; c <= n; c++) {
                    a->data[i++] = lua_tonumber(L, slot++);
                }
            }
            a->index += n;
        }
    }
    return 0;
}

static int vectorlib_getvaluerc(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int row = lmt_tointeger(L, 2) - 1;
        int column = lmt_tointeger(L, 3) - 1;
        if (row >= 0 && row < a->rows && column >= 0 && column < a->columns) {
            lua_pushnumber(L, a->data[row * a->columns + column]);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_setvaluerc(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int row = lmt_tointeger(L, 2) - 1;
        int column = lmt_tointeger(L, 3) - 1;
        if (row >= 0 && row < a->rows && column >= 0 && column < a->columns) {
            a->data[row * a->columns + column] = lua_type(L, 4) == LUA_TNUMBER ? lua_tonumber(L, 4) : 0.0;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* round floor ceil */

static int vectorlib_identity(lua_State *L)
{
    int n = lmt_tointeger(L, 1);
    if (n > 0) {
        vector v = vectorlib_aux_push(L, n, n, 0);
        v->type = identity_type;
        for (int i = 0; i < v->size; i++) {
            v->data[i] = 0.0;
        }
        for (int i = 0; i < n; i++) {
            v->data[i * v->columns + i] = 1.0;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_transpose(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        if (a->type == identity_type) {
            vectorlib_aux_copy(L, 1);
        } else {
            // if one column or one row just swap
            vector v = vectorlib_aux_push(L, a->columns, a->rows, a->stacking);
            for (int r = 0; r < a->rows; r++) {
                for (int c = 0; c < a->columns; c++) {
                    v->data[c * a->rows + r] = a->data[r * a->columns + c];
                }
            }
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_inner(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    if (a && b && a->rows == b->rows) {
        double d = 0.0;
        for (int i = 0; i < a->rows; i++) {
            d = d + a->data[i] * b->data[i];
        }
        lua_pushnumber(L, d);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_round(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
        for (int i = 0; i < a->size; i++) {
            v->data[i] = round(a->data[i]);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_floor(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
        for (int i = 0; i < a->size; i++) {
            v->data[i] = floor(a->data[i]);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_ceiling(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
        for (int i = 0; i < a->size; i++) {
            v->data[i] = ceil(a->data[i]);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_truncate(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        if (lua_toboolean(L, 2)) {
            double epsilon = lmt_optdouble(L, 3, vector_epsilon);
            /* in place */
            for (int i = 0; i < a->size; i++) {
                if (ISZERO(a->data[i])) {
                    a->data[i] = 0.0;
                }
            }
        } else {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            double epsilon = lmt_optdouble(L, 3, vector_epsilon);
            for (int i = 0; i < a->size; i++) {
                v->data[i] = ISZERO(a->data[i]) ? 0.0 : a->data[i];
            }
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_aux_uppertriangle(vector v, int sign, double epsilon)
{
    for (int i = 0; i < v->rows - 1; i++) {
        double pivot = v->data[i * v->columns + i];
        if (ISZERO(pivot)) {
            int p = i + 1;
         // while (! (v->data[p * v->columns + i])) {
            while (ISZERO(v->data[p * v->columns + i])) {
                p++;
                if (p > v->rows) {
                    return sign;
                }
            }
         // for (int k = 0; k < v->columns; k++) {
         //     double d1 = v->data[p * v->columns + k];
         //     double d2 = v->data[i * v->columns + k];
         //     v->data[p * v->columns + k] = d2;
         //     v->data[i * v->columns + k] = d1;
         // }
            p = p * v->columns;
            i = i * v->columns;
            for (int k = 0; k < v->columns; k++) {
                double d1 = v->data[p];
                double d2 = v->data[i];
                v->data[p++] = d2;
                v->data[i++] = d1;
            }
            sign = -sign;
        }
        for (int k = i + 1; k < v->rows; k++) {
            double factor = - v->data[k * v->columns + i] / v->data[i * v->columns + i];
            long target = k * v->columns;
            if (ISZERO(factor)) {
                for (int l = i; l < v->columns; l++) {
                    v->data[target++] += 0.0;
                }
            } else {
                long source = i * v->columns;
                for (int l = i; l < v->columns; l++) {
                    v->data[target++] += factor * v->data[source++];
                }
            }
        }
    }
    return sign;
}

static int vectorlib_aux_determinant(lua_State *L, int singular, double *d, double epsilon)
{
    vector a = vectorlib_aux_get(L, 1);
    (void) singular;
    if (a && a->rows == a->columns) {
        if (a->type == identity_type) {
            *d = 1.0;
            return 1;
        } else {
            switch (a->columns) {
                case 1:
                    /* { { a } } : a */
                    {
                        *d =
                            a->data[0];
                    }
                    break;
                case 2:
                    /* { { a, b }, { c, d } } : ad - bc */
                    {
                        *d =
                            a->data[0] * a->data[3] -
                            a->data[1] * a->data[2];
                    }
                    break;
                case 3:
                    /* {{ a, b, c }, { d, e, f }. { g, g, i } } : a(ei-fh) - b(di-gf) + c(dh-eg) */
                    /* see gems article about pos / neg separation, appendix v2.5 */
                    {
                        *d =
                            a->data[0] * (a->data[4] * a->data[8] - a->data[5] * a->data[7]) -
                            a->data[1] * (a->data[3] * a->data[8] - a->data[6] * a->data[5]) +
                            a->data[2] * (a->data[3] * a->data[7] - a->data[4] * a->data[6]);
                    }
                    break;
                default:
                    vectorlib_aux_copy(L, 1);
                    {
                        vector a = vectorlib_aux_get(L, -1);
                        double epsilon = lmt_optdouble(L, 2, vector_epsilon);
                        int sign = vectorlib_aux_uppertriangle(a, 1, epsilon);
                        *d = 1.0;
                        for (int i = 0; i < a->rows; i++) {
                            double dd = a->data[i * a->columns + i];
                            if (ISZERO(dd)) {
                                /*tex
                                    This is also an attempt to avoid the -0.0 case. But even this
                                    doesn't catches all it seems.
                                */
                                *d = 0.0;
                                goto DONE;
                            } else {
                                *d = *d * a->data[i * a->columns + i];
                            }
                        }
                        *d = sign * *d;
                    }
                    break;
            }
            /*tex
                These -0.0 result in random tiny number, is this a compiler issue? The next test doesn't
                always catch is. We also have this issue in \METAPOST\ double mode. A |-d == 0.0| is more
                reliable than a |d == -0.0| test it seems.
            */
         // if (-d == 0.0) {
         //     d = 0.0;
         // }
          DONE:
            if (ISZERO(*d)) {
                *d = 0.0;
            }
            return 1;
        }
    } else {
        return 0;
    }
}

static int vectorlib_determinant(lua_State *L)
{
    double determinant = 0.0;
    double epsilon = lmt_optdouble(L, 2, vector_epsilon);
    if (vectorlib_aux_determinant(L, 0, &determinant, epsilon)) {
        if (ISZERO(determinant)) {
            lua_pushinteger(L, 0);
        } else {
            lua_pushnumber(L, determinant);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_issingular(lua_State *L)
{
    double d = 0.0;
    double epsilon = lmt_optdouble(L, 2, vector_epsilon);
    if (vectorlib_aux_determinant(L, 0, &d, epsilon)) {
        double e = lua_type(L, 2) == LUA_TNUMBER ? lua_tonumber(L, 2) : 0.001;
        lua_pushboolean(L, d <= e || d >= -e);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_aux_rowechelon(vector v, int reduce, int augmented, double epsilon)
{
    int pRow = 0;
    int pCol = 0;
    int nRow = v->rows;
    int nCol = v->columns;
    while (pRow < nRow) {
        double pivot = v->data[pRow * nCol + pCol];
        if (ISZERO(pivot)) {
            int i = pRow;
            int n = nRow;
            while (ISZERO(v->data[i * nCol + pCol])) {
                i++;
                if (i > n) {
                    pCol = pCol + 1;
                    if (pCol >= nCol) {
                        if (augmented) {
                            /* we have a serious problem */
                        }
                        return 1;
                    } else {
                        i = pRow;
                    }
                }
            }
            for (int k = 0; k < v->columns; k++) {
                double d1 = v->data[pRow * v->columns + k];
                double d2 = v->data[i    * v->columns + k];
                v->data[pRow * v->columns + k] = d2;
                v->data[i    * v->columns + k] = d1;
            }
        }
        pivot = v->data[pRow * nCol + pCol];
        for (int l = pCol; l < nCol; l++) {
            v->data[pRow * nCol + l] /= pivot;
        }
        if (reduce) {
            for (int k = 0; k < pRow; k++) {
                double factor = - v->data[k * nCol + pCol];
                for (int l = pCol; l < nCol; l++) {
                    v->data[k * nCol + l] += factor * v->data[pRow * nCol + l];
                }
            }
        }
        for (int k = pRow + 1; k < nRow; k++) {
            double factor = - v->data[k * nCol + pCol];
            for (int l = pCol; l < nCol; l++) { // + 1
                v->data[k * nCol + l] += factor * v->data[pRow * nCol + l];
            }
        }
        pRow = pRow + 1;
        pCol = pCol + 1;
        if (pRow > nRow || pCol > nCol) {
            pRow = nRow + 1;
        }
    }
    return 0;
}

static int vectorlib_inverse(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        switch (a->type) {
            case identity_type:
                vectorlib_aux_copy(L, 1);
                break;
            default:
                if (a->rows == a->columns) {
                   double epsilon = lmt_optdouble(L, 2, vector_epsilon);
                    switch (a->rows) {
                        case 1:
                            {
                                vector w = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
                                if (ISZERO(a->data[0])) {
                                    goto BAD;
                                } else {
                                    w->data[0] = 1.0 / a->data[0];
                                }
                            }
                            break;
                        case 2:
                            {
                                double d = 0.0;
                                if (vectorlib_aux_determinant(L, 0, &d, epsilon)) {
                                    if (ISZERO(d)) {
                                        goto BAD;
                                    } else {
                                        vector w = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
                                        w->data[0] =   a->data[3] / d;
                                        w->data[1] = - a->data[1] / d;
                                        w->data[2] = - a->data[2] / d;
                                        w->data[3] =   a->data[0] / d;
                                    }
                                }
                            }
                            break;
                        case 3:
                            {
                                double d = 0.0;
                                if (vectorlib_aux_determinant(L, 0, &d, epsilon)) {
                                    if (ISZERO(d)) {
                                        goto BAD;
                                    } else {
                                        vector w = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
                                        w->data[0] = (a->data[4] * a->data[8] - a->data[5] * a->data[7]) / d;
                                        w->data[1] = (a->data[2] * a->data[7] - a->data[1] * a->data[8]) / d;
                                        w->data[2] = (a->data[1] * a->data[5] - a->data[2] * a->data[4]) / d;
                                        w->data[3] = (a->data[5] * a->data[6] - a->data[3] * a->data[8]) / d;
                                        w->data[4] = (a->data[0] * a->data[8] - a->data[2] * a->data[6]) / d;
                                        w->data[5] = (a->data[2] * a->data[3] - a->data[0] * a->data[5]) / d;
                                        w->data[6] = (a->data[3] * a->data[7] - a->data[4] * a->data[6]) / d;
                                        w->data[7] = (a->data[1] * a->data[6] - a->data[0] * a->data[7]) / d;
                                        w->data[8] = (a->data[0] * a->data[4] - a->data[1] * a->data[3]) / d;
                                    }
                                }
                            }
                            break;
                        default:
                            {
                             // vectorlib_copy(L);
                             // vectorlib_identity(L);
                             // vectorlib_concat(L);
                                vector v = vectorlib_aux_push(L, a->rows, a->columns * 2, a->stacking);
                                vector w = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
                                for (int r = 0; r < a->rows; r++) {
                                    long target = r * v->columns;
                                    long source = r * a->columns;
                                    for (int c = 0; c < a->columns; c++) {
                                        v->data[target++] = a->data[source++];
                                    }
                                 // v->data[r * v->columns + a->columns + r] = 1.0;
                                    v->data[target + r] = 1.0;
                                }
                                vectorlib_aux_rowechelon(v, 1, 1, epsilon);
                                for (int r = 0; r < a->rows; r++) {
                                    if (ISZERO(v->data[r * v->columns + r])) {
                                        goto BAD;
                                    }
                                }
                                for (int r = 0; r < a->rows; r++) {
                                    long target = r * w->columns;
                                    long source = r * v->columns + a->columns;
                                    for (int c = 0; c < a->columns; c++) {
                                        w->data[target++] = v->data[source++];
                                    }
                                }
                            }
                            break;
                    }
                }
        }
        return 1;
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

static int vectorlib_rowechelon(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    int reduce = ! lua_toboolean(L, 2);
    if (a && a->rows == a->columns) {
        double epsilon = lmt_optdouble(L, 3, vector_epsilon); /* now, as we push */
        vectorlib_aux_copy(L, 1);
        switch (a->type) {
            case identity_type:
                break;
            default:
                {
                    a = vectorlib_aux_get(L, -1);
                    vectorlib_aux_rowechelon(a, reduce, 0, epsilon);
                    break;
                }
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_crossproduct(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    if (a && b) {
        if (a->columns == b->columns && a->rows == b->rows && (b->columns == 1 || b->rows == 1)) {
            switch (a->rows) {
                case 1:
                    switch (a->columns) {
                        case 1:
                            lua_pushinteger(L, 0);
                            return 1;
                        case 2:
                            lua_pushnumber(L, a->data[0] * b->data[1] - b->data[1] * a->data[0]);
                            return 1;
                        case 3:
                            /*u \times v = (u2*v3 - u3*v2, u3*v1 - u1*v3, u1*v2 - u2*v1) */
                            {
                                vector v = vectorlib_aux_push(L, 1, a->columns, a->stacking);
                                v->data[0] = a->data[1] * b->data[2] - a->data[2] * b->data[1];
                                v->data[1] = a->data[2] * b->data[0] - a->data[0] * b->data[2];
                                v->data[2] = a->data[0] * b->data[1] - a->data[1] * b->data[0];
                                return 1;
                            }
                        default:
                            break; /* maybe todo */
                    }
                    break;
                case 2:
                    /* u \times v = u1*v2 - u2*v1 */
                    lua_pushnumber(L, a->data[0] * b->data[1] - b->data[1] * a->data[0]);
                    return 1;
                case 3:
                    /*u \times v = (u2*v3 - u3*v2, u3*v1 - u1*v3, u1*v2 - u2*v1) */
                    {
                        vector v = vectorlib_aux_push(L, a->rows, 1, a->stacking);
                        v->data[0] = a->data[1] * b->data[2] - a->data[2] * b->data[1];
                        v->data[1] = a->data[2] * b->data[0] - a->data[0] * b->data[2];
                        v->data[2] = a->data[0] * b->data[1] - a->data[1] * b->data[0];
                        return 1;
                    }
                default:
                    break; /* maybe todo */
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_normalize(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        double d = 0.0;
        for (int i = 0; i < a->size; i++) {
            d += a->data[i] * a->data[i];
        }
        if (d > 0.0) {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            d = sqrt(d);
            for (int i = 0; i < a->size; i++) {
                v->data[i] = a->data[i] / d;
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_homogenize(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a && a->columns > 1) {
        double epsilon = lmt_optdouble(L, 2, vector_epsilon);
        if (! vectorlib_aux_zero_in_column(a, a->columns - 1, epsilon)) {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            for (int r = 0; r < a->rows; r++) {
                double d = a->data[r * a->columns + a->columns - 1];
                long target = r * a->columns;
                long source = r * a->columns;
                for (int c = 0; c < a->columns - 1; c++) {
                    v->data[target++] = a->data[source++] / d;
                }
                v->data[target] = 1.0;
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_concat(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    int vertical = lua_toboolean(L, 3);
    if (a && b) {
        if (vertical) {
            if (b->columns == a->columns) {
                vector v = vectorlib_aux_push(L, a->rows + b->rows, a->columns, a->stacking);
                long index = a->size;
                vectorlib_aux_copy_data(v, a);
                for (int i = 0; i < b->size; i++) {
                    v->data[index++] = b->data[i];
                }
                return 1;
            }
        } else {
            if (b->rows == a->rows) {
                vector v = vectorlib_aux_push(L, a->rows, a->columns + b->columns, a->stacking);
                for (int r = 0; r < a->rows; r++) {
                    long target = r * v->columns;
                    long source = r * a->columns;
                    for (int c = 0; c < a->columns; c++) {
                        v->data[target++] = a->data[source++];
                    }
                }
                for (int r = 0; r < b->rows; r++) {
                    long target = r * v->columns + a->columns;
                    long source = r * b->columns;
                    for (int c = 0; c < b->columns; c++) {
                        v->data[target++ ] = b->data[source++];
                    }
                }
                return 1;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_slice(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int fr = lmt_tointeger(L, 2);
        int fc = lmt_tointeger(L, 3);
        int nr = lmt_tointeger(L, 4);
        int nc = lmt_tointeger(L, 5);
        int tr = --fr + nr - 1;
        int tc = --fc + nc - 1;
        if ( (fr >= 0  && fr < a->rows) && (fc >= 0  && fc < a->columns) &&
             (tr >= fr && tr < a->rows) && (tc >= fc && tc < a->columns)) {
            vector v = vectorlib_aux_push(L, nr, nc, a->stacking);
            long target = 0;
            for (int r = fr; r <= tr; r++) {
                long source = r * a->columns;
                for (int c = fc; c <= tc; c++) {
                    v->data[target++] = a->data[source++];
                }
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_replace(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    if (a && b) {
        int fr = lmt_tointeger(L, 3);
        int fc = lmt_tointeger(L, 4);
        int nr = b->rows;
        int nc = b->columns;
        int tr = --fr + nr - 1;
        int tc = --fc + nc - 1;
        if ( (fr >= 0  && fr < a->rows) && (fc >= 0  && fc < a->columns) &&
             (tr >= fr && tr < a->rows) && (tc >= fc && tc < a->columns)) {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            long source = 0;
            vectorlib_aux_copy_data(v, a);
            for (int r = fr; r <= tr; r++) {
                long target = r * v->columns + fc;
                for (int c = fc; c <= tc; c++) {
                    v->data[target++] = b->data[source++];
                }
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_delete(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int f = lmt_tointeger(L, 2);
        int n = lmt_tointeger(L, 3);
        int t = --f + n - 1;
        int vertical = lua_toboolean(L, 4);
        if (vertical) {
            if ((n <= a->rows) && (f >= 0 && f < a->rows) && (t >= f && t < a->rows)) {
                vector v = vectorlib_aux_push(L, a->rows - n, a->columns, a->stacking);
                long target = 0;
                for (int r = 0; r < a->rows; r++) {
                    if (r < f || r > t) {
                        long source = r * a->columns;
                        for (int c = 0; c < a->columns; c++) {
                            v->data[target++] = a->data[source++];
                        }
                    }
                }
                return 1;
            }
        } else {
            if ((n <= a->columns) && (f >= 0 && f < a->columns) && (t >= f && t < a->columns)) {
                vector v = vectorlib_aux_push(L, a->rows, a->columns - n, a->stacking);
                long target = 0;
                for (int r = 0; r < a->rows; r++) {
                    int base = r * a->columns;
                    for (int c = 0; c < a->columns; c++) {
                        if (c < f || c > t) {
                            v->data[target++] = a->data[base + c];
                        }
                    }
                }
                return 1;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_remove(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int f = lmt_tointeger(L, 2);
        int n = lmt_tointeger(L, 3);
        int t = --f + n - 1;
        int vertical = lua_toboolean(L, 4);
        if (vertical) {
            if ((n <= a->rows) && (f >= 0 && f < a->rows) && (t >= f && t < a->rows)) {
                vector v = vectorlib_aux_push(L, a->rows - n, a->columns, a->stacking);
                vector w = vectorlib_aux_push(L,           n, a->columns, a->stacking);
                long vtarget = 0;
                long wtarget = 0;
                for (int r = 0; r < a->rows; r++) {
                    long source = r * a->columns;
                    if (r < f || r > t) {
                        for (int c = 0; c < a->columns; c++) {
                            v->data[vtarget++] = a->data[source++];
                        }
                    } else {
                        for (int c = 0; c < a->columns; c++) {
                            w->data[wtarget++] = a->data[source++];
                        }
                    }
                }
                return 2;
            }
        } else {
            if ((n <= a->columns) && (f >= 0 && f < a->columns) && (t >= f && t < a->columns)) {
                vector v = vectorlib_aux_push(L, a->rows, a->columns - n, a->stacking);
                vector w = vectorlib_aux_push(L, a->rows,              n, a->stacking);
                long vtarget = 0;
                long wtarget = 0;
                for (int r = 0; r < a->rows; r++) {
                    long source = r * a->columns;
                    for (int c = 0; c < a->columns; c++) {
                        if (c < f || c > t) {
                            v->data[vtarget++] = a->data[source++];
                        } else {
                            w->data[wtarget++] = a->data[source++];
                        }
                    }
                }
                return 2;
            }
        }
    }
    lua_pushnil(L);
    lua_pushnil(L);
    return 2;
}

static int vectorlib_insert(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    vector b = vectorlib_aux_get(L, 2);
    if (a && b) {
        int p = lmt_tointeger(L, 3);
        int vertical = lua_toboolean(L, 4);
        if (vertical) {
            if (a->columns == b->columns) {
                vector v = vectorlib_aux_push(L, a->rows + b->rows, a->columns, a->stacking);
                long target = 0;
                for (int r = 0; r < p; r++) {
                    long source = r * a->columns;
                    for (int c = 0; c < a->columns; c++) {
                        v->data[target++] = a->data[source++];
                    }
                }
                for (int r = 0; r < b->rows; r++) {
                    long source = r * b->columns;
                    for (int c = 0; c < b->columns; c++) {
                        v->data[target++] = b->data[source++];
                    }
                }
                for (int r = p; r < a->rows; r++) {
                    long source = r * a->columns;
                    for (int c = 0; c < a->columns; c++) {
                        v->data[target++] = a->data[source++];
                    }
                }
                return 1;
            }
        } else {
            if (a->rows == b->rows) {
                vector v = vectorlib_aux_push(L, a->rows, a->columns + b->columns, a->stacking);
                long target = 0;
                for (int r = 0; r < a->rows; r++) {
                    long source = r * a->columns;
                    for (int c = 0; c < p; c++) {
                        v->data[target++] = a->data[source++];
                    }
                    source = r * b->columns;
                    for (int c = 0; c < b->columns; c++) {
                        v->data[target++] = b->data[source++];
                    }
                    source = r * a->columns + p;
                    for (int c = p; c < a->columns; c++) {
                        v->data[target++] = a->data[source++];
                    }
                }
                return 1;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_append(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        double d = lua_tonumber(L, 2);
        int vertical = lua_toboolean(L, 3);
        if (vertical) {
            int row = a->rows + 1;
            vector v = vectorlib_aux_push(L, row, a->columns, a->stacking);
            vectorlib_aux_copy_data(v, a);
            for (int c = 0; c < a->columns; c++) {
                v->data[row + c] = d;
            }
            return 1;
        } else {
            vector v = vectorlib_aux_push(L, a->rows, a->columns + 1, a->stacking);
            long target = 0;
            long source = 0;
            for (int r = 0; r < a->rows; r++) {
                for (int c = 0; c < a->columns; c++) {
                    v->data[target++] = a->data[source++];
                }
                v->data[target++] = d;
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_exchange(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        int p = lmt_tointeger(L, 2) - 1;
        int q = lmt_tointeger(L, 3) - 1;
        int vertical = lua_toboolean(L, 4);
        if (vertical) {
            if (p >= 0 && p < a->rows && q >= 0 && q < a->rows) {
                vector v = vectorlib_aux_push(L, a->rows , a->columns, a->stacking);
                vectorlib_aux_copy_data(v, a);
                p *= a->columns;
                q *= a->columns;
                for (int c = 0; c < a->columns; c++) {
                    v->data[p] = a->data[q];
                    v->data[q] = a->data[p];
                    p++;
                    q++;
                }
                return 1;
            }
        } else {
            if (p >= 0 && p < a->columns && q >= 0 && q < a->columns) {
                vector v = vectorlib_aux_push(L, a->rows , a->columns, a->stacking);
                vectorlib_aux_copy_data(v, a);
                for (int i = 0; i < a->size; i++) {
                    v->data[i] = a->data[i];
                }
                for (int r = 0; r < a->rows; r++) {
                    v->data[p] = a->data[q];
                    v->data[q] = a->data[p];
                    p += a->columns;
                    q += a->columns;
                }
                return 1;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_swap(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a && (a->columns == 1 || a->rows == 1)) {
        vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
        v->rows = a->columns;
        v->columns = a->rows;
        vectorlib_aux_copy_data(v, a);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_gettype(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        lua_pushinteger(L, v->type);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_getdimensions(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    if (v) {
        lua_pushinteger(L, v->rows);
        lua_pushinteger(L, v->columns);
        return 2;
    } else {
        return 0;
    }
}

static int vectorlib_setstacking(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        a->stacking = lmt_tointeger(L, 2);
    }
    return 0;
}

static int vectorlib_getstacking(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a) {
        lua_pushinteger(L, a->stacking);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*
    Meshes:

    These we use for some experiments with alternative approaches to contour graphics in the
    \LUAMETAFUN\ subsystem. They are for now not official.

*/

static inline unsigned int vectorlib_valid_point(lua_State *L, int index)
{
    int p = lmt_tointeger(L, index);
    return p < 0 ? 0 : p > max_mesh ? max_mesh : (unsigned) p;
 // return p < 0 ? 0 : p > max_mesh ? max_mesh - 1 : p;
}

static mesh vectorlib_aux_maybe_ismesh(lua_State *L, int index)
{
    mesh m = lua_touserdata(L, index);
    if (m && lua_getmetatable(L, index)) {
        lua_get_metatablelua(mesh_instance);
        if (! lua_rawequal(L, -1, -2)) {
            m = NULL;
        }
        lua_pop(L, 2);
    }
    return m;
}

static int vectorlib_mesh_valid(lua_State *L)
{
    lua_pushboolean(L, vectorlib_aux_maybe_ismesh(L, 1) ? 1 : 0);
    return 1;
}

static int vectorlib_mesh_type(lua_State *L)
{
    if (vectorlib_aux_maybe_ismesh(L, 1)) {
        lua_push_key(mesh);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static inline void vectorlib_mesh_wipe_entry(mesh m, int index)
{
    int n = index * m->dimension;
    for (int i = 0; i < m->dimension; i++) {
        m->points[n++] = 0;
    }
    m->average[index] = 0;
}

void vectorlib_mesh_aux_get_points(const mesh triangles, int index, int t[3])
{
    /* no checking here: index is already zero based */
    switch (triangles->type) {
        case triangle_5_mesh_type:
            {
                t[0] = index * 3;
                t[1] = t[0] + 1;
                t[2] = t[1] + 1;
                return;
            }
        case triangle_6_mesh_type:
            {
                int row    = (index / 2) / triangles->columns;
                int column = (index / 2) % triangles->columns;
                if (row >= 0 && column >= 0 && row < triangles->rows && column < triangles->columns) {
                    int p1 =  row      * (triangles->columns + 1) + column;
                    int p2 = (row + 1) * (triangles->columns + 1) + column; // just add to p1
                    if (index % 2 == 0) {
                        t[0] = p1;
                        t[1] = p1 + 1; // p11;
                        t[2] = p2 + 1; // p21;
                    } else {
                        t[0] = p1;
                        t[1] = p2 + 1; // p21;
                        t[2] = p2;
                    }
                    return;
                } else {
                    break;
                }
            }
        case triangle_7_mesh_type:
            {
                if (index >= 0 && index < triangles->size) {
                    int p = (index / 2) * 4;
                    t[0] = p;
                    if (index % 2 == 0) {
                        t[1] = p + 1;
                        t[2] = p + 2;
                    } else {
                        t[1] = p + 2;
                        t[2] = p + 3;
                    }
                    return;
                } else {
                    break;
                }
            }
        case triangle_mesh_type:
            if (triangles->points) {
                int n = index * triangles ->dimension;
                t[0] = triangles->points[n++] - 1;
                t[1] = triangles->points[n++] - 1;
                t[2] = triangles->points[n++] - 1;
                return;
            } else {
                break;
            }
    }
    t[0] = 0;
    t[1] = 0;
    t[2] = 0;
}

int vectorlib_mesh_aux_get_points_okay(const mesh triangles, const points vertices, int index, int t[3])
{
    /* index is zero based */
    if (vertices->data) {
        switch (triangles->type) {
            case triangle_5_mesh_type:
                if (index >= 0 && index < triangles->size) {
                    t[0] = index * 3;
                    t[1] = t[0] + 1;
                    t[2] = t[1] + 1;
                    break;
                } else {
                    return 0;
                }
            case triangle_6_mesh_type:
                {
                    int row    = (index / 2) / triangles->columns;
                    int column = (index / 2) % triangles->columns;
                    if (row >= 0 && column >= 0 && row < triangles->rows && column < triangles->columns) {
                        int p1  =  row      * (triangles->columns + 1) + column;
                        int p2  = (row + 1) * (triangles->columns + 1) + column; // just add to p1
                        t[0] = p1;
                        if (index % 2 == 0) {
                            t[1] = p1 + 1; // p11;
                            t[2] = p2 + 1; // p21;
                        } else {
                            t[1] = p2 + 1; // p21;
                            t[2] = p2;
                        }
                        break;
                    } else {
                        return 0;
                    }
                }
            case triangle_7_mesh_type:
                {
                    if (index >= 0 && index < triangles->size) {
                        int p = (index / 2) * 4;
                        t[0] = p;
                        if (index % 2 == 0) {
                            t[1] = p + 1;
                            t[2] = p + 2;
                        } else {
                            t[1] = p + 2;
                            t[2] = p + 3;
                        }
                        break;
                    } else {
                        return 0;
                    }
                }
            case triangle_mesh_type:
               if (triangles->points && index >= 0 && index < triangles->size) {
                    int n = index * triangles ->dimension;
                    t[0] = triangles->points[n++] - 1;
                    t[1] = triangles->points[n++] - 1;
                    t[2] = triangles->points[n++] - 1;
                    break;
                } else {
                    return 0;
                }
            default:
                return 0;
        }
        return t[0] >= 0 && t[0] < vertices->size && t[1] >= 0 && t[1] < vertices->size && t[2] >= 0 && t[2] < vertices->size;
    } else {
        return 0;
    }
}

static inline mesh vectorlib_mesh_aux_push(lua_State *L, int rows, int type)
{
    mesh m = lua_newuserdatauv(L, sizeof(meshdata), 0);
    if (m && rows > 0) {
        if (type < dot_mesh_type || type > triangle_7_mesh_type) {
            m->type = triangle_mesh_type;
        } else {
            m->type = type;
        }
        m->size = rows;
        m->rows = rows;
        m->columns = 0;
        m->index = 0;
        if (virtual_mesh_type(m->type)) {
            m->dimension = 0;
            m->points = NULL;
            m->average = NULL;
            m->pointsbytes = 0;
            m->averagebytes = 0;
        } else {
            m->dimension = m->type;
            m->pointsbytes = m->rows * m->dimension * sizeof(unsigned);
            m->averagebytes = m->rows * sizeof(double);
            m->points = vectorlib_memory_malloc(m->pointsbytes);
            m->average = vectorlib_memory_malloc(m->averagebytes);
        }
        lua_get_metatablelua(mesh_instance);
        lua_setmetatable(L, -2);
    }
    return m;
}

static int vectorlib_mesh_new(lua_State *L)
{
    int rows = lmt_optinteger(L, 1, 1);
    int type = lmt_optinteger(L, 2, triangle_mesh_type);
    mesh m = vectorlib_mesh_aux_push(L, rows, type);
    if (m) {
        if (m->dimension) {
            for (int i = 0; i < m->rows; i++) {
                vectorlib_mesh_wipe_entry(m, i);
            }
        }
        return 1;
    } else {
        return 0;
    }
}

mesh vectorlib_mesh_aux_get(lua_State *L, int index)
{
    mesh m = lua_touserdata(L, index);
    if (m && lua_getmetatable(L, index)) {
        lua_get_metatablelua(mesh_instance);
        if (! lua_rawequal(L, -1, -2)) {
            m = NULL;
        }
        lua_pop(L, 2);
    }
    return m;
}

static mesh vectorlib_get_mesh(lua_State *L, int index)
{
    if (lua_type(L, index) == LUA_TUSERDATA) {
        mesh m = lua_touserdata(L, index);
        if (m && lua_getmetatable(L, index)) {
            lua_get_metatablelua(mesh_instance);
            if (! lua_rawequal(L, -1, -2)) {
               m = NULL;
            }
            lua_pop(L, 2);
        }
        return m;
    } else {
        return NULL;
    }
}

static int vectorlib_mesh_gc(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        if (m->points) {
            vectorlib_memory_free(m->points, m->pointsbytes);
            m->points = NULL;
            m->pointsbytes = 0;
        }
        if (m->average) {
            vectorlib_memory_free(m->average, m->averagebytes);
            m->average = NULL;
            m->averagebytes = 0;
        }
        m->type      = no_mesh_type;
        m->size      = 0;
        m->rows      = 0;
        m->columns   = 0;
        m->index     = 0;
        m->dimension = 0;
    }
    return 0;
}

static int vectorlib_mesh_tostring(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        lua_pushfstring(L, "<mesh %d %s : %p>", m->size, mesh_names[m->type], m);
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_mesh_totable(lua_State *L)
{
    mesh m = vectorlib_aux_maybe_ismesh(L, 1);
    if (m) {
        switch (m->type) {
            case triangle_5_mesh_type:
            case triangle_6_mesh_type:
            case triangle_7_mesh_type:
                {
                    lua_createtable(L, m->size, 0);
                    for (int index = 0; index < m->size; index++) {
                        int t[3];
                        vectorlib_mesh_aux_get_points(m, index, t);
                        lua_createtable(L, 3, 0);
                        lua_pushinteger(L, t[0] + 1); lua_rawseti(L, -2, 1);
                        lua_pushinteger(L, t[1] + 1); lua_rawseti(L, -2, 2);
                        lua_pushinteger(L, t[2] + 1); lua_rawseti(L, -2, 3);
                        lua_rawseti(L, -2, index + 1);
                    }
                    return 1;
                }
            case triangle_mesh_type:
            case quad_mesh_type:
                if (m->points && m->average) {
                    long target = 1;
                    int n = 0;
                    if (lua_toboolean(L, 2)) {
                        lua_createtable(L, m->size * (m->dimension + 1), 0);
                        for (int r = 0; r < m->size; r++) {
                            for (int i = 0; i < m->dimension; i++) {
                                lua_pushinteger(L, m->points[n++]);
                                lua_rawseti(L, -2, target++);
                            }
                            lua_pushnumber(L, m->average[r]);
                            lua_rawseti(L, -2, target++);
                        }
                    } else {
                        lua_createtable(L, m->size, 0);
                        for (int r = 0; r < m->size; r++) {
                            long index = 1;
                            lua_createtable(L, m->dimension + 1, 0);
                            for (int i = 0; i < m->dimension; i++) {
                                lua_pushinteger(L, m->points[n++]);
                                lua_rawseti(L, -2, index++);
                            }
                            lua_pushnumber(L, m->average[r]);
                            lua_rawseti(L, -2, index);
                            lua_rawseti(L, -2, target++);
                        }
                    }
                    return 1;
                } else {
                    break;
                }
        }
    }
    return 0;
}

static int vectorlib_mesh_index(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        switch (m->type) {
            case triangle_5_mesh_type:
            case triangle_6_mesh_type:
            case triangle_7_mesh_type:
                break;
            default:
                if (m->average) {
                    int index = lmt_tointeger(L, 2);
                    if (index > 0 && index <= m->size) {
                        lua_pushnumber(L, m->average[index - 1]);
                        return 1;
                    }
                } else {
                    break;
                }
        }
    }
    return 0;
}

static int vectorlib_mesh_getvalue(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        int index = lmt_tointeger(L, 2) - 1;
        if (index >= 0 && index < m->size) {
            switch (m->type) {
                case triangle_5_mesh_type:
                case triangle_6_mesh_type:
                case triangle_7_mesh_type:
                    {
                        int t[3];
                        vectorlib_mesh_aux_get_points(m, index, t);
                        if (lua_toboolean(L, 3)) {
                            lua_createtable(L, 3, 0);
                            lua_pushinteger(L, t[0] + 1); lua_rawseti(L, -1, 1);
                            lua_pushinteger(L, t[1] + 1); lua_rawseti(L, -1, 2);
                            lua_pushinteger(L, t[2] + 1); lua_rawseti(L, -1, 3);
                            return 1;
                        } else {
                            lua_pushinteger(L, t[0] + 1);
                            lua_pushinteger(L, t[1] + 1);
                            lua_pushinteger(L, t[2] + 1);
                            return 3;
                        }
                    }
                default:
                    if (m->points && m->average) {
                        int n = index * m->dimension;
                        if (lua_toboolean(L, 3)) {
                            long target = 1;
                            lua_createtable(L, m->dimension + 1, 0);
                            for (int i = 0; i < m->dimension; i++) {
                                lua_pushinteger(L, m->points[n++]);
                                lua_rawseti(L, -2, target++);
                            }
                            lua_pushnumber(L, m->average[index]);
                            lua_rawseti(L, -2, target);
                            return 1;
                        } else {
                            for (int i = 0; i < m->dimension; i++) {
                                lua_pushinteger(L, m->points[n++]);
                            }
                            lua_pushnumber(L, m->average[index]);
                            return m->dimension + 1;
                        }
                    } else {
                        break;
                    }
            }
        }
    }
    return 0;
}

static int vectorlib_mesh_setvalue(lua_State *L) /* better have a setaverage */
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        int index = lmt_tointeger(L, 2) - 1;
        if (index >= 0 && index < m->size) {
            switch (m->type) {
                case triangle_5_mesh_type:
                case triangle_6_mesh_type:
                case triangle_7_mesh_type:
                    /* for now we silently ignore */
                    return 0;
                default:
                    if (m->points && m->average) {
                        int n = index * m->dimension;
                        switch (lua_type(L, 3)) {
                            case LUA_TNUMBER:
                                {
                                    if (lua_gettop(L) > 3) {
                                        for (int i = 0; i < m->dimension; i++) {
                                            m->points[n++] = vectorlib_valid_point(L, i + 3);
                                        }
                                        m->average[index] = lua_tonumber(L, m->dimension + 3);
                                    } else {
                                        m->average[index] = lua_tonumber(L, 3);
                                    }
                                    break;
                                }
                            case LUA_TTABLE:
                                {
                                    for (int i = 0; i < m->dimension; i++) {
                                        lua_rawgeti(L, 3, i + 1);
                                        m->points[n++] = vectorlib_valid_point(L, -1);
                                        lua_pop(L, 1);
                                    }
                                    lua_rawgeti(L, 3, m->dimension + 1);
                                    m->average[index] = lua_tonumber(L, -1);
                                    lua_pop(L, 1);
                                    break;
                                }
                        }
                    } else {
                        break;
                    }
            }
        }
    }
    return 0;
}

static int vectorlib_mesh_setnext(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m && m->index < m->size) {
        switch (m->type) {
            case triangle_5_mesh_type:
            case triangle_6_mesh_type:
            case triangle_7_mesh_type:
                break;
            case dot_mesh_type:
            case line_mesh_type:
                /* maybe */
                break;
            case triangle_mesh_type:
            case quad_mesh_type:
                if (m->points && m->average) {
                    int n = m->index * m->dimension;
                    switch (lua_type(L, 2)) {
                        case LUA_TNUMBER:
                            {
                                for (int i = 0; i < m->dimension; i++) {
                                    m->points[n++] = vectorlib_valid_point(L, i + 2);
                                }
                                m->average[m->index] = lua_tonumber(L, m->dimension + 2);
                                break;
                            }
                        case LUA_TTABLE:
                            {
                                for (int i = 0; i < m->dimension; i++) {
                                    lua_rawgeti(L, 2, i + 1);
                                    m->points[n++] = vectorlib_valid_point(L, -1);
                                    lua_pop(L, 1);
                                }
                                lua_rawgeti(L, 2, m->dimension + 1);
                                m->average[m->index] = lua_tonumber(L, -1);
                                lua_pop(L, 1);
                                break;
                            }
                    }
                    m->index++;
                }
                break;
        }
    }
    return 0;
}

static int vectorlib_mesh_getlength(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    lua_pushinteger(L, m ? m->size : 0);
    return 1;
}

static int vectorlib_mesh_getdimensions(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        lua_pushinteger(L, m->size);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*

    Contours:

    These we use for some experiments with alternative approaches to contour graphics in the
    \LUAMETAFUN\ subsystem. They are for now not official.

*/

static int vectorlib_contour_aux_okay(int condition, const char *where, const char *message)
{
    if (! condition) {
        tex_formatted_error("vector lib", "error in vector.%s: %s\n", where, message);
    }
    return condition;
}

static int vectorlib_contour_aux_is_valid(lua_State *L, vector *v, mesh *l, const char *what)
{
    *v = vectorlib_get(L, 1);
    if (vectorlib_contour_aux_okay(*v && (*v)->rows > 1 && (*v)->columns > 2, what, "point list expected (x,y,z,...)")) {
        *l = vectorlib_get_mesh(L, 2);
        if (vectorlib_contour_aux_okay(*l && ! virtual_mesh_type((*l)->type), what, "no flat triangles meshes here (yet)")) {
            if (vectorlib_contour_aux_okay(*l != NULL, what, "mesh list expected ((p1 .. pN),average)")) {
                return 1;
            }
        }
    }
    return 0;
}

static int vectorlib_contour_getmesh(lua_State *L)
{
    vector v = NULL;
    mesh m = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &m, "getmesh")) {
        if (m->points && m->average) {
            int i = lmt_tointeger(L, 3) - 1; /* triangle index */
            if (i >= 0 && i < m->size) {
                int done = 0;
                int okay = 0;
                int n = i * m->dimension;
                for (int j = 0; j < m->dimension; j++) {
                    int r = m->points[n++] - 1;
                    if (r >= 0 && r < v->rows) {
                        int k = r * v->columns;
                        if (! okay) {
                            lua_createtable(L, 2 * m->dimension, 0);
                            okay = 1;
                        }
                        lua_pushnumber(L, v->data[k++]);
                        lua_rawseti(L, -2, ++done);
                        lua_pushnumber(L, v->data[k]);
                        lua_rawseti(L, -2, ++done);
                    } else {
                        break; /* error */
                    }
                }
                if (okay) {
                    lua_pushnumber(L, m->average[i]);
                    return 2;
                } else {
                    /*tex We signal that we have a zero entry. */
                    lua_pushboolean(L, 0);
                    return 1;
                }
            }
        }
    }
    return 0;
}

static int vectorlib_contour_getarea(lua_State *L)
{
    vector v = NULL;
    mesh m = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &m, "getarea")) {
        if (m->points) {
            int i = lmt_tointeger(L, 3) - 1; /* triangle index */
            if (i >= 0 && i < m->size) {
                switch (m->type) {
                    case line_mesh_type:
                        lua_pushnumber(L, 0);
                        return 1;
                    case quad_mesh_type:
                        {
                            int n  = i * m->dimension;
                            int p1 = m->points[n  ] - 1;
                            int p3 = m->points[n+2] - 1;
                            if (p1 >= 0 && p1 < v->rows && p3 >= 0 && p3 < v->rows) {
                                double x1 = v->data[p1 * v->columns];
                                double y1 = v->data[p1 * v->columns + 1];
                                double x3 = v->data[p3 * v->columns];
                                double y3 = v->data[p3 * v->columns + 1];
                                lua_pushnumber(L, fabs(x3 - x1) * fabs(y3 - y1));
                                return 1;
                            } else {
                                break;
                            }
                        }
                    case triangle_mesh_type:
                        {
                            int n  = i * m->dimension;
                            int p1 = m->points[n++] - 1;
                            int p2 = m->points[n++] - 1;
                            int p3 = m->points[n++] - 1;
                            if (p1 >= 0 && p1 < v->rows && p2 >= 0 && p2 < v->rows && p3 >= 0 && p3 < v->rows) {
                                /* from wikipedia */
                                double x1 = v->data[p1 * v->columns];
                                double y1 = v->data[p1 * v->columns + 1];
                                double x2 = v->data[p2 * v->columns];
                                double y2 = v->data[p2 * v->columns + 1];
                                double x3 = v->data[p3 * v->columns];
                                double y3 = v->data[p3 * v->columns + 1];
                                double ab = sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
                                double bc = sqrt(pow(x2 - x3, 2) + pow(y2 - y3, 2));
                                double ca = sqrt(pow(x3 - x1, 2) + pow(y3 - y1, 2));
                                lua_pushnumber(L, sqrt (
                                    (  ab + bc + ca) *
                                    (- ab + bc + ca) *
                                    (  ab - bc + ca) *
                                    (  ab + bc - ca)
                                ) / 4);
                                return 1;
                            } else {
                                break;
                            }
                        }
                }
            }
        }
    }
    return 0;
}

/*
    See below, todo: optimize. We can also decide to use some of the trickery from z-buffering and
    overlap detection here.

 */

static int vectorlib_contour_aux_checkoverlap(const vector v, const mesh m, int U, int V, int method, double epsilon)
{
    int ui = U * m->dimension;
    int vi = V * m->dimension;
    int u0 = m->points[ui++] - 1;
    int u1 = m->points[ui++] - 1;
    int u2 = m->points[ui++] - 1;
    int v0 = m->points[vi++] - 1;
    int v1 = m->points[vi++] - 1;
    int v2 = m->points[vi++] - 1;
    if (
        u0 >= 0      && u1 >= 0      && u2 >= 0      &&
        v0 >= 0      && v1 >= 0      && v2 >= 0      &&
        u0 < v->rows && u1 < v->rows && u2 < v->rows &&
        v0 < v->rows && v1 < v->rows && v2 < v->rows
    ) {
        if (
            u0 == v0 || u1 == v0 || u2 == v0 ||
            u0 == v1 || u1 == v1 || u2 == v1 ||
            u0 == v2 || u1 == v2 || u2 == v2
        ) {
            return triangles_intersection_nop_same_points;
        } else {
            double *U0 = &(v->data[u0 * v->columns]);
            double *U1 = &(v->data[u1 * v->columns]);
            double *U2 = &(v->data[u2 * v->columns]);
            double *V0 = &(v->data[v0 * v->columns]);
            double *V1 = &(v->data[v1 * v->columns]);
            double *V2 = &(v->data[v2 * v->columns]);
            if (
                /* we can't memcmp due to small differences (epsilon) */
                (ISZERO(U0[0] - V0[0]) && ISZERO(U0[1] - V0[1]) && ISZERO(U0[2] - V0[2])) ||
                (ISZERO(U1[0] - V0[0]) && ISZERO(U1[1] - V0[1]) && ISZERO(U1[2] - V0[2])) ||
                (ISZERO(U2[0] - V0[0]) && ISZERO(U2[1] - V0[1]) && ISZERO(U2[2] - V0[2])) ||
                (ISZERO(U0[0] - V1[0]) && ISZERO(U0[1] - V1[1]) && ISZERO(U0[2] - V1[2])) ||
                (ISZERO(U1[0] - V1[0]) && ISZERO(U1[1] - V1[1]) && ISZERO(U1[2] - V1[2])) ||
                (ISZERO(U2[0] - V1[0]) && ISZERO(U2[1] - V1[1]) && ISZERO(U2[2] - V1[2])) ||
                (ISZERO(U0[0] - V2[0]) && ISZERO(U0[1] - V2[1]) && ISZERO(U0[2] - V2[2])) ||
                (ISZERO(U1[0] - V2[0]) && ISZERO(U1[1] - V2[1]) && ISZERO(U1[2] - V2[2])) ||
                (ISZERO(U2[0] - V2[0]) && ISZERO(U2[1] - V2[1]) && ISZERO(U2[2] - V2[2]))
            ) {
                return triangles_intersection_nop_same_values;
            } else if (method == 2) {
                return triangles_intersect_gd(U0, U1, U2, V0, V1, V2, epsilon);
            } else {
                return triangles_intersect(U0, U1, U2, V0, V1, V2, epsilon);
            }
        }
    }
    return -1;
}

static int vectorlib_contour_checkoverlap(lua_State *L)
{
    vector v = NULL;
    mesh m = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &m, "checkoverlap")) {
        if (m->type == triangle_mesh_type) {
            int U = lmt_tointeger(L, 3) - 1;
            int V = lmt_tointeger(L, 4) - 1;
            if (U >= 0 && U < m->size && V >= 0 && V < m->size) {
                int method = lmt_optinteger(L, 5, 1);
                double epsilon = lmt_optdouble(L, 6, vector_epsilon);
                int overlapping = vectorlib_contour_aux_checkoverlap(v, m, U, V, method, epsilon);
                if (overlapping >= 0) {
                    lua_pushinteger(L, overlapping);
                    return 1;
                }
            }
        } else {
            /* we only check triangles */
        }
    }
    return 0;
}

static int vectorlib_contour_collectoverlap(lua_State *L)
{
    vector v = NULL;
    mesh m = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &m, "collectoverlap")) {
        if (m->type == triangle_mesh_type && m->points) {
            int details = lua_toboolean(L, 3);
            int method = lmt_optinteger(L, 4, 1);
            double epsilon = lmt_optdouble(L, 5, vector_epsilon);
            int vr = v->rows;
            int vc = v->columns;
            int lr = m->dimension;
            int done = 0;
            int n = 0;
            for (int i = 0; i < (m->rows * m->dimension); i++) {
                int p = m->points[i];
                if (p < 1 || p > vr) {
                    vectorlib_contour_aux_okay(0, "collectoverlap", "triangle list entries has invalid point references");
                    return 0;
                }
            }
            n = 0;
            for (int i = 0; i < lr - 1; i++) {
                int u0 = m->points[n++] - 1;
                int u1 = m->points[n++] - 1;
                int u2 = m->points[n++] - 1;
                double *U0 = &(v->data[u0 * vc]);
                double *U1 = &(v->data[u1 * vc]);
                double *U2 = &(v->data[u2 * vc]);
                for (int j = i + 1; j < lr; j++) {
                    int nn = j * m->dimension;
                    int v0, v1, v2;
                    double *V0, *V1, *V2;
                    v0 = m->points[nn++] - 1;
                    if (
                        u0 == v0 || u1 == v0 || u2 == v0
                    ) {
                        continue; /* triangles_intersection_nop_same_points */
                    }
                    v1 = m->points[nn++] - 1;
                    if (
                        u0 == v1 || u1 == v1 || u2 == v1
                    ) {
                        continue; /* triangles_intersection_nop_same_points */
                    }
                    v2 = m->points[nn++] - 1;
                    if (
                        u0 == v2 || u1 == v2 || u2 == v2
                    ) {
                        continue; /* triangles_intersection_nop_same_points */
                    }
                    V0 = &(v->data[v0 * vc]);
                    if (
                        (ISZERO(U0[0] - V0[0]) && ISZERO(U0[1] - V0[1]) && ISZERO(U0[2] - V0[2])) ||
                        (ISZERO(U1[0] - V0[0]) && ISZERO(U1[1] - V0[1]) && ISZERO(U1[2] - V0[2])) ||
                        (ISZERO(U2[0] - V0[0]) && ISZERO(U2[1] - V0[1]) && ISZERO(U2[2] - V0[2]))
                    ) {
                        continue; /* triangles_intersection_nop_same_values */
                    }
                    V1 = &(v->data[v1 * vc]);
                    if (
                        (ISZERO(U0[0] - V1[0]) && ISZERO(U0[1] - V1[1]) && ISZERO(U0[2] - V1[2])) ||
                        (ISZERO(U1[0] - V1[0]) && ISZERO(U1[1] - V1[1]) && ISZERO(U1[2] - V1[2])) ||
                        (ISZERO(U2[0] - V1[0]) && ISZERO(U2[1] - V1[1]) && ISZERO(U2[2] - V1[2]))
                    ) {
                        continue; /* triangles_intersection_nop_same_values */
                    }
                    V2 = &(v->data[v2 * vc]);
                    if (
                        (ISZERO(U0[0] - V2[0]) && ISZERO(U0[1] - V2[1]) && ISZERO(U0[2] - V2[2])) ||
                        (ISZERO(U1[0] - V2[0]) && ISZERO(U1[1] - V2[1]) && ISZERO(U1[2] - V2[2])) ||
                        (ISZERO(U2[0] - V2[0]) && ISZERO(U2[1] - V2[1]) && ISZERO(U2[2] - V2[2]))
                    ) {
                        continue; /* triangles_intersection_nop_same_values */
                    }
                    if (details) {
                        triangles_three Utimes, Vtimes;
                        int state = method == 2
                            ? triangles_intersect_with_line_gd(U0, U1, U2, V0, V1, V2, Utimes, Vtimes, epsilon)
                            : triangles_intersect_with_line   (U0, U1, U2, V0, V1, V2, Utimes, Vtimes, epsilon);
                        if (state > triangles_intersection_yes_bound) {
                            long index = 1;
                            if (! done) {
                                lua_createtable(L, 8, 0); /* main table, how many makes sense */
                            }
                            lua_createtable(L, 8, 0);
                         // lua_createtable(L, 9, 0);
                            lua_pushinteger(L, i + 1);
                            lua_rawseti(L, -2, index++);
                            lua_pushinteger(L, j + 1);
                            lua_rawseti(L, -2, index++);
                            for (int k = 0; k < 3; k++) {
                                lua_pushnumber(L, Utimes[k]);
                                lua_rawseti(L, -2, index++);
                            }
                            for (int k = 0; k < 3; k++) {
                                lua_pushnumber(L, Vtimes[k]);
                                lua_rawseti(L, -2, index++);
                            }
                         // lua_pushinteger(L, state);
                         // lua_rawseti(L, -2, index++);
                            lua_rawseti(L, -2, ++done);
                        }
                    } else {
                        int state = method == 2
                            ? triangles_intersect_gd(U0, U1, U2, V0, V1, V2, epsilon)
                            : triangles_intersect   (U0, U1, U2, V0, V1, V2, epsilon);
                        if (state > triangles_intersection_yes_bound) {
                            if (! done) {
                                lua_createtable(L, 8, 0);
                            }
                            lua_createtable(L, 2, 0);
                            lua_pushinteger(L, i + 1);
                            lua_rawseti(L, -2, 1);
                            lua_pushinteger(L, j + 1);
                            lua_rawseti(L, -2, 2);
                            lua_rawseti(L, -2, ++done);
                            /* maybe also store state */
                        }
                    }
                }
            }
            return m ? 1 : 0;
        } else {
            /* we only check triangles */
        }
    }
    return 0;
}

static int vectorlib_contour_average(lua_State *L)
{
    vector v = NULL;
    mesh m = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &m, "average")) {
        if (m->points && m->average) {
            double minx = 0.0;
            double maxx = 0.0;
            double miny = 0.0;
            double maxy = 0.0;
            double minz = 0.0;
            double maxz = 0.0;
            int okay = 0;
            int done = 0;
            int tolerant = lua_toboolean(L, 3);
            int method = lmt_optinteger(L, 4, 1);
            /* shared points count double */
            for (int i = 0; i < m->size; i++) {
                int n = i * m->dimension;
                double average = 0.0;
                double amin = 0;
                int a = 0;
                for (int j = 0; j < m->dimension; j++) {
                    int r = m->points[n++];
                    if (r > 0 && r <= v->rows) {
                        int k = (r - 1) * v->columns;
                        double x = v->data[k++];
                        double y = v->data[k++];
                        double z = v->data[k];
                        if (! a || z < amin) {
                            amin = z;
                        }
                        average += z;
                        if (done) {
                            if (x < minx) { minx = x; } else if (x > maxx) { maxx = x; }
                            if (y < miny) { miny = y; } else if (y > maxy) { maxy = y; }
                        } else {
                            minx = x; miny = y;
                            maxx = x; maxy = y;
                            done = 1;
                        }
                        a++;
                    } else if (! tolerant) {
                        tex_formatted_error("vector lib", "error in vector.average, invalid point index");
                        a = 0;
                        break;
                    }
                }
                if (method == 2) {
                    average = amin;
                } else {
                    average = a > 0 ? (average / a) : 0.0;
                    if (method == 3) {
                        average += amin;
                    }
                }
                m->average[i] = average;
                if (okay) {
                    if (average < minz) { minz = average; }
                    if (average > maxz) { maxz = average; }
                } else {
                    minz = average;
                    maxz = average;
                }
                okay++;
            }
            lua_createtable(L, 0, 7);
            lua_set_integer_by_key(L, "okay", okay);
            lua_set_number_by_key (L, "minx", minx);
            lua_set_number_by_key (L, "miny", miny);
            lua_set_number_by_key (L, "maxx", maxx);
            lua_set_number_by_key (L, "maxy", maxy);
            lua_set_number_by_key (L, "minz", minz);
            lua_set_number_by_key (L, "maxz", maxz);
            return 1;
        }
    }
    return 0;
}

static int vectorlib_contour_bounds(lua_State *L)
{
    vector v = NULL;
    mesh m = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &m, "bounds")) {
        if (m->points) {
            double minx = 0.0;
            double maxx = 0.0;
            double miny = 0.0;
            double maxy = 0.0;
            int okay = 0;
            int first = lmt_optinteger(L, 3, 1);
            int last = lmt_optinteger(L, 4, m->size);
            if (first <= 0) {
                first = 0;
            } else {
                --first;
            }
            if (last == 0) {
                last = m->size;
            } else if (last > m->size) {
                last = m->size;
            } else {
                --last;
            }
            for (int i = first; i < last; i++) {
                int n = i * m->dimension;
                for (int j = 0; j < m->dimension; j++) {
                    int r = m->points[n++];
                    if (r > 0 && r <= v->rows) {
                        int k = (r - 1) * v->columns;
                        double x = v->data[k++];
                        double y = v->data[k];
                        if (okay) {
                            if (x < minx) { minx = x; } else if (x > maxx) { maxx = x; }
                            if (y < miny) { miny = y; } else if (y > maxy) { maxy = y; }
                        } else {
                            minx = x; miny = y;
                            maxx = x; maxy = y;
                        }
                        okay++;
                    }
                }
            }
            lua_createtable(L, 0, 5);
            lua_set_integer_by_key(L, "okay", okay);
            lua_set_number_by_key (L, "minx", minx);
            lua_set_number_by_key (L, "miny", miny);
            lua_set_number_by_key (L, "maxx", maxx);
            lua_set_number_by_key (L, "maxy", maxy);
            return 1;
        }
    }
    return 0;
}

/*
    For sorting it's better to have the average in the record. So here we need to use our
    own quiksort.
*/

// static int vectorlib_contour_compare_mesh_average(const void *entry_1, const void *entry_2)
// {
//     const double *value_1 = (const double *) entry_1;
//     const double *value_2 = (const double *) entry_2;
//     if (value_1 > value_2) {
//         return  1;
//     } else if (value_1 < value_2) {
//         return -1;
//     } else {
//         return 0;
//     }
// }
//
// static int vectorlib_contour_sort(lua_State *L)
// {
//     mesh m = vectorlib_get_mesh(L, 1);
//     if (m && m->size > 1) {
//         qsort(m->average, m->size, sizeof(double), vectorlib_contour_compare_mesh_average);
//     }
//     return 0;
// }

/*
    We can pass the mesh m pointer around and just assume that the compiler will optimize
    the dimension multiplications.
 */

static inline void swap(mesh m, int i, int j)
{
    {
        double a = m->average[i];
        m->average[i] = m->average[j];
        m->average[j] = a;
    }
    {
        unsigned p[4]; /* in most cases a triangle */
        memcpy(&p        [0],                &m->points[i * m->dimension], sizeof(unsigned) * m->dimension);
        memcpy(&m->points[i * m->dimension], &m->points[j * m->dimension], sizeof(unsigned) * m->dimension);
        memcpy(&m->points[j * m->dimension], &p        [0],                sizeof(unsigned) * m->dimension);
    }
}

static inline int vectorlib_aux_partition(mesh m, int low, int high)
{
    double pivot = m->average[high];
    int i = low - 1;
    for (int j = low; j <= high - 1; j++) {
        if (m->average[j] < pivot) {
            i++;
            swap(m, i, j);
        }
    }
    swap(m, i + 1, high);
    return i + 1;
}

static void vectorlib_aux_sort(mesh m, int low, int high)
{
    if (low < high) {
        int pi = vectorlib_aux_partition(m, low, high);
        vectorlib_aux_sort(m, low, pi - 1);
        vectorlib_aux_sort(m, pi + 1, high);
    }
}

static int vectorlib_contour_sort(lua_State *L)
{
    mesh m = vectorlib_get_mesh(L, 1);
    if (m && m->size > 1) {
        vectorlib_aux_sort(m, 0, m->size - 1);
    }
    return 0;
}

/* Todo: make a stupid mesh for zbuffering! */

int vectorlib_contour_aux_makemesh(lua_State *L, int columns, int rows, int type)
{
    int size = columns * rows;
    if (size > 0 && size <= max_mesh) {
        type = (type >= dot_mesh_type && type <= triangle_7_mesh_type ? type : triangle_mesh_type);
        switch (type) {
            case triangle_mesh_type:
                size *= 2;
                break;
            case quad_mesh_type:
            case line_mesh_type:
                size *= 2;
                break;
            case triangle_6_mesh_type:
            case triangle_7_mesh_type:
                size *= 2;
                /* fall through */
            case triangle_5_mesh_type:
                {
                    mesh m     = vectorlib_mesh_aux_push(L, 1, type); /* we need to pass the test */
                    m->size    = size;
                    m->type    = type;
                    m->columns = columns;
                    m->rows    = rows;
                    return 1;
                }
            default:
                /*tex We silently recover. */
                type = triangle_mesh_type;
                size *= 2;
                break;
        }
        /*tex When we arrived here we're okay. */
        {
            mesh m = vectorlib_mesh_aux_push(L, size, type);
            int index = 0;
            int offset = columns + 1;
            for (int r = 1; r <= rows; r++) {
                for (int c = 1; c <= columns; c++) {
                    int p1 = (r - 1) * offset + c; // left point of current row
                    int p2 =  r      * offset + c; // left point of next row
                    int p11 = p1 + 1;
                    int p21 = p2 + 1;
                    if (p11 > max_mesh || p21 > max_mesh) {
                        /* we clip */
                    } else {
                        int n = index * m->dimension;
                        switch (type) {
                            case triangle_mesh_type:
                                /* first */
                                m->points[n++] = (unsigned int) p1;
                                m->points[n++] = (unsigned int) p11;
                                m->points[n++] = (unsigned int) p21;
                                m->average[index++] = 0.0;
                                /* second */
                                m->points[n++] = (unsigned int) p1;
                                m->points[n++] = (unsigned int) p21;
                                m->points[n++] = (unsigned int) p2;
                                m->average[index++] = 0.0;
                                break;
                            case quad_mesh_type:
                                m->points[n++] = (unsigned int) p1;
                                m->points[n++] = (unsigned int) p11;
                                m->points[n++] = (unsigned int) p21;
                                m->points[n++] = (unsigned int) p2;
                                m->average[index++] = 0.0;
                                break;
                            case line_mesh_type:
                                m->points[n++] = (unsigned int) p1;
                                m->points[n++] = (unsigned int) p2;
                                m->average[index++] = 0.0;
                                break;
                        }
                    }
                }
            }
        }
    } else {
        /* message */
        lua_pushnil(L);
    }
    return 1;

}

static int vectorlib_contour_makemesh(lua_State *L)
{
    return vectorlib_contour_aux_makemesh(L,
        lmt_tointeger(L, 1), // columns
        lmt_tointeger(L, 2), // rows
        lmt_optinteger(L, 3, triangle_mesh_type)
    );
}

/* Point */

static inline point vectorlib_aux_point_push(lua_State *L)
{
    point p = lua_newuserdatauv(L, sizeof(pointdata), 0);
    if (p) {
        memset(p, 0, sizeof(pointdata));
        lua_get_metatablelua(point_instance);
        lua_setmetatable(L, -2);
        return p;
    } else {
        return NULL;
    }
}

static inline point vectorlib_point_aux_get(lua_State *L, int index)
{
    point p = lua_touserdata(L, index);
    if (p && lua_getmetatable(L, index)) {
        lua_get_metatablelua(point_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
    }
    return p;
}

static inline int vectorlib_point_aux_set(lua_State *L, int index, int top, point p)
{
    switch (lua_type(L, index)) {
        case LUA_TNUMBER:
            p->x = top > 0 ? lua_tonumber(L, index++) : 0;
            p->y = top > 1 ? lua_tonumber(L, index++) : 0;
            p->z = top > 2 ? lua_tonumber(L, index  ) : NAN;
            return 1;
        case LUA_TTABLE:
            p->x = lua_rawgeti(L, index, 1) == LUA_TNUMBER ? lua_tonumber(L, -1) : 0;   lua_pop(L, 1);
            p->y = lua_rawgeti(L, index, 2) == LUA_TNUMBER ? lua_tonumber(L, -1) : 0;   lua_pop(L, 1);
            p->z = lua_rawgeti(L, index, 3) == LUA_TNUMBER ? lua_tonumber(L, -1) : NAN; lua_pop(L, 1);
            return 1;
        default:
            return 0;
    }
}

static int vectorlib_point_new(lua_State *L)
{
    int top = lua_gettop(L);
    point p = vectorlib_aux_point_push(L);
    if (p) {
        vectorlib_point_aux_set(L, 1, top, p);
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_point_type(lua_State *L)
{
    point p = vectorlib_point_aux_get(L, 1);
    if (p) {
        lua_pushstring(L, lua_key(point));
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_point_copy(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a) {
        point p = vectorlib_aux_point_push(L);
        p->x = a->x;
        p->y = a->y;
        p->z = a->z;
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_point_valid(lua_State *L)
{
    point p = vectorlib_point_aux_get(L, 1);
    if (p) {
        lua_pushinteger(L, isnan(p->z) ? 2 : 3);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int vectorlib_point_tostring(lua_State *L)
{
    point p = vectorlib_point_aux_get(L, 1);
    if (p) {
        if (isnan(p->z)) {
            lua_pushfstring(L, "<point %f %f : %p>", p->x, p->y, p);
        } else {
            lua_pushfstring(L, "<point %f %f %f : %p>", p->x, p->y, p->z, p);
        }
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_point_getlength(lua_State *L)
{
    point p = vectorlib_point_aux_get(L, 1);
    if (p) {
        double d = p->x * p->x + p->y * p->y;
        if (! isnan(p->z)) {
            d += p->z * p->z;
        }
        lua_pushnumber(L, sqrt(d));
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_point_add(lua_State *L)
{
    if (lua_type(L, 2) == LUA_TNUMBER) {
        point a = vectorlib_point_aux_get(L, 1);
        if (a) {
            point p = vectorlib_aux_point_push(L);
            double d = lua_tonumber(L, 2);
            p->x = a->x + d;
            p->y = a->y + d;
            p->z = isnan(a->z) ? NAN : a->z + d;
            return 1;
        }
    } else {
        point a = vectorlib_point_aux_get(L, 1);
        point b = vectorlib_point_aux_get(L, 2);
        if (a && b) {
            point p = vectorlib_aux_point_push(L);
            p->x = a->x + b->x;
            p->y = a->y + b->y;
            p->z = isnan(a->z) || isnan(b->z) ? NAN : a->z + b->z;
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_point_sub(lua_State *L)
{
    if (lua_type(L, 2) == LUA_TNUMBER) {
        point a = vectorlib_point_aux_get(L, 1);
        if (a) {
            point p = vectorlib_aux_point_push(L);
            double d = lua_tonumber(L, 2);
            p->x = a->x - d;
            p->y = a->y - d;
            p->z = isnan(a->z) ? NAN : a->z - d;
            return 1;
        }
    } else {
        point a = vectorlib_point_aux_get(L, 1);
        point b = vectorlib_point_aux_get(L, 2);
        if (a && b) {
            point p = vectorlib_aux_point_push(L);
            p->x = a->x - b->x;
            p->y = a->y - b->y;
            p->z = isnan(a->z) || isnan(b->z) ? NAN : a->z - b->z;
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_point_mul(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TNUMBER) {
        point b = vectorlib_point_aux_get(L, 2);
        if (b) {
            point p = vectorlib_aux_point_push(L);
            double d = lua_tonumber(L, 1);
            p->x = b->x * d;
            p->y = b->y * d;
            p->z = isnan(b->z) ? NAN : b->z * d;
            return 1;
        }
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        point a = vectorlib_point_aux_get(L, 1);
        if (a) {
            point p = vectorlib_aux_point_push(L);
            double d = lua_tonumber(L, 2);
            p->x = a->x * d;
            p->y = a->y * d;
            p->z = isnan(a->z) ? NAN : a->z * d;
            return 1;
        }
    } else {
        point a = vectorlib_point_aux_get(L, 1);
        point b = vectorlib_point_aux_get(L, 2);
        if (a && b) {
            point p = vectorlib_aux_point_push(L);
            p->x = a->x * b->x;
            p->y = a->y * b->y;
            p->z = isnan(a->z) || isnan(b->z) ? NAN : a->z * b->z;
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_point_div(lua_State *L)
{
    if (lua_type(L, 2) == LUA_TNUMBER) {
        point a = vectorlib_point_aux_get(L, 1);
        if (a) {
            double d = lua_tonumber(L, 2);
            if (d != 0.0) {
                point p = vectorlib_aux_point_push(L);
                p->x = a->x / d;
                p->y = a->y / d;
                p->z = isnan(a->z) ? NAN : a->z / d;
                return 1;
            }
        }
    } else {
        point a = vectorlib_point_aux_get(L, 1);
        point b = vectorlib_point_aux_get(L, 2);
        if (a && b && b->x != 0.0 && b->y != 0.0 && (isnan(b->z) || b->z != 0.0)) {
            point p = vectorlib_aux_point_push(L);
            p->x = a->x / b->x;
            p->y = a->y / b->y;
            p->z = isnan(a->z) || isnan(b->z) ? NAN : a->z / b->z;
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

static int vectorlib_point_neg(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a) {
        point p = vectorlib_aux_point_push(L);
        p->x = - a->x;
        p->y = - a->y;
        p->z = isnan(a->z) ? NAN : - a->z;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_eq(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    point b = vectorlib_point_aux_get(L, 1);
    if (a && b) {
        int same = a->x == b->x && a->y == b->y;
        if (! same) {
            /* we're done */
        } else if (isnan(a->z)) {
            if (isnan(b->z)) {
                /* we're done */
            } else {
                same = 0;
            }
        } else if (isnan(b->z)) {
            same = 0;
        } else {
            same = a->z == b->z;
        }
        lua_pushboolean(L, same);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_iszero(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a) {
        lua_pushboolean(L, a->x == 0 && a->y == 0 && (isnan(a->z) || a->z == 0));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_setnext(lua_State *L)
{
    int top = lua_gettop(L);
    point p = vectorlib_point_aux_get(L, 1);
    if (p) {
        vectorlib_point_aux_set(L, 1, top, p);
    }
    return 0;
}

static int vectorlib_point_getvalue(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a) {
        switch (lua_type(L, 2)) {
            case LUA_TNUMBER:
                switch (lua_tointeger(L, 2)) {
                    case 1:
                        lua_pushnumber(L, a->x);
                        return 1;
                    case 2:
                        lua_pushnumber(L, a->y);
                        return 1;
                    case 3:
                        if (isnan(a->z)) {
                            lua_pushnil(L);
                        } else {
                            lua_pushnumber(L, a->z);
                        }
                        return 1;
                }
                break;
            case LUA_TSTRING:
                {
                    const char *s = lua_tostring(L, 2);
                    if (lua_key_eq(s, x)) {
                        lua_pushnumber(L, a->x);
                        return 1;
                    } else if (lua_key_eq(s, y)) {
                        lua_pushnumber(L, a->y);
                        return 1;
                    } else if (lua_key_eq(s, z)) {
                        if (! isnan(a->z)) {
                            lua_pushnumber(L, a->z);
                            return 1;
                        } else {
                            break;
                        }
                    } else {
                        /* actually this table is still on the stack */
                        lua_get_metatablelua(point_instance);
                        lua_pushvalue(L, -2);
                        lua_gettable(L, -2);
                        return 1;
                    }
                }
        }
    }
    return 0;
}

static int vectorlib_point_totable(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a) {
        lua_createtable(L, isnan(a->z) ? 2 : 3, 0);
        lua_pushnumber(L, a->x); lua_rawseti(L, -2, 1);
        lua_pushnumber(L, a->y); lua_rawseti(L, -2, 2);
        if (! isnan(a->z)) {
            lua_pushnumber(L, a->z); lua_rawseti(L, -2, 3);
        }
        return 1;
    }
    return 0;
}

static int vectorlib_point_setvalue(lua_State *L)
{
    int top = lua_gettop(L);
    point p = vectorlib_point_aux_get(L, 1);
    if (p) {
        vectorlib_point_aux_set(L, 2, top, p);
    }
    return 0;
}

static int vectorlib_point_dotproduct(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    point b = vectorlib_point_aux_get(L, 2);
    if (a && b) {
        double d = a->x * b->x + a->y * b->y;
        if (! isnan(a->z) && ! isnan(b->z)) {
            d += a->z * b->z;
        }
        lua_pushnumber(L, d);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_crossproduct(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    point b = vectorlib_point_aux_get(L, 2);
    if (a && b) {
        if (! isnan(a->z) && ! isnan(b->z)) {
            point p = vectorlib_aux_point_push(L);
            p->x = a->y * b->z - a->z * b->y;
            p->y = a->z * b->x - a->x * b->z;
            p->z = a->x * b->y - a->y * b->x;
        } else {
            lua_pushnumber(L, a->x * b->y - a->y * b->x);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_perpendicular(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a && isnan(a->z)) {
        point p = vectorlib_aux_point_push(L);
        p->x = - a->y;
        p->y = a->x;
        p->z = NAN;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_distance(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    point b = vectorlib_point_aux_get(L, 2);
    if (a && b) {
        double d = (a->x - b->x) * (a->x - b->x) + (a->y - b->y) * (a->y - b->y);
        if (! isnan(a->z) && ! isnan(b->z)) {
            d += (a->z - b->z) * (a->z - b->z);
        }
        lua_pushnumber(L, sqrt(d));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_point_normalize(lua_State *L)
{
    point a = vectorlib_point_aux_get(L, 1);
    if (a) {
        point p = vectorlib_aux_point_push(L);
        double d = a->x * a->x + a->y * a->y;
        if (! isnan(a->z)) {
            d += a->z * a->z;
        }
        d = sqrt(d);
     // if (d >= 1e-6) {
        if (d > 0) {
            p->x = a->x / d;
            p->y = a->y / d;
            p->z = isnan(a->z) ? NAN : a->z / d;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* Points */

points vectorlib_points_aux_push(lua_State *L, int r, int c, int wipe)
{
    if (r < 1 || c < 1 || r > max_vector_rows || c > max_vector_columns || r * c > max_vector) {
        tex_formatted_error("vector lib", "you can have %i rows, %i columns and at most %i entries, requested: %i x %i = %i", max_vector_rows, max_vector_columns, max_vector, r, c, r * c);
        return NULL;
    } else {
        points p = lua_newuserdatauv(L, sizeof(pointsdata), 0);
        if (p) {
            p->rows     = r;
            p->columns  = c;
            p->type     = points_type;
            p->stacking = 0;
            p->index    = 0;
            p->size     = r * c;
            p->bytes    = p->size * sizeof(pointdata);
            if (wipe) {
                p->data = vectorlib_memory_calloc(p->size, sizeof(pointdata));
            } else {
                p->data = vectorlib_memory_malloc(p->bytes);
            }
            lua_get_metatablelua(points_instance);
            lua_setmetatable(L, -2);
        }
        return p;
    }
}

int vectorlib_points_aux_grow(lua_State *L, points p, int step)
{
    (void) L;
    p->data = vectorlib_memory_realloc(p->data, p->size * sizeof(pointdata), (p->size + step) * sizeof(pointdata));
    if (p->data) {
     // memset(&(p->data[p->size+1]), 0, step * sizeof(pointdata));
        p->size += step;
        return 1;
    } else {
        p->size = 0;
        p->index = 0;
        return 0;
    }
}

/* public */

static int vectorlib_points_new(lua_State *L)
{
    int rows    = lmt_optinteger(L, 1, 1);
    int columns = lmt_optinteger(L, 2, 1);
    points p    = vectorlib_points_aux_push(L, rows, columns, 1);
    if (p) {
     // memset(&(p->data[0]), 0, p->size * sizeof(pointdata));
        return 1;
    } else {
        return 0;
    }
}

points vectorlib_points_aux_get(lua_State *L, int index) /*  vectorlib_aux_maybe_ispoints(L, 1) ? 1 : 0); */
{
    points p = lua_touserdata(L, index);
    if (p && lua_getmetatable(L, index)) {
        lua_get_metatablelua(points_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
    }
    return p;
}

static int vectorlib_points_gc(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p && p->data) {
        vectorlib_memory_free(p->data, p->bytes);
        p->data    = NULL;
        p->bytes   = 0;
        p->rows    = 0;
        p->columns = 0;
        p->size    = 0;
        p->index   = 0;
    }
    return 0;
}

static int vectorlib_points_tostring(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p) {
        lua_pushfstring(L, "<points %d x %d : %p>", p->rows, p->columns, p);
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_points_valid(lua_State *L)
{
    lua_pushboolean(L, vectorlib_points_aux_get(L, 1) ? 1 : 0);
    return 1;
}

static int vectorlib_points_getlength(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p) {
        lua_pushinteger(L, p->size);
        return 1;
    } else {
        return 0;
    }
}

static inline int vectorlib_points_aux_set(lua_State *L, int index, points p, int idx)
{
    switch (lua_type(L, index)) {
        case LUA_TTABLE:
            {
                lua_rawgeti(L, index, 1); p->data[idx].x  = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_rawgeti(L, index, 2); p->data[idx].y  = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_rawgeti(L, index, 3); p->data[idx].z  = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_rawgeti(L, index, 4); p->data[idx].nx = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_rawgeti(L, index, 5); p->data[idx].ny = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_rawgeti(L, index, 6); p->data[idx].nz = lua_tonumber(L, -1); lua_pop(L, 1);
             // lua_rawgeti(L, index, 7); p->data[idx].u  = lua_tonumber(L, -1); lua_pop(L, 1);
             // lua_rawgeti(L, index, 8); p->data[idx].v  = lua_tonumber(L, -1); lua_pop(L, 1);
                return 1;
            }
        case LUA_TNUMBER:
            {
                p->data[idx].x  = lua_tonumber(L, index++);
                p->data[idx].y  = lua_tonumber(L, index++);
                p->data[idx].z  = lua_tonumber(L, index++);
                p->data[idx].nx = lua_tonumber(L, index++);
                p->data[idx].ny = lua_tonumber(L, index++);
                p->data[idx].nz = lua_tonumber(L, index++);
             // p->data[idx].u  = lua_tonumber(L, index++);
             // p->data[idx].v  = lua_tonumber(L, index++);
                return 1;
            }
        case LUA_TUSERDATA:
            {
                point u = vectorlib_point_aux_get(L, index);
                if (u && ! isnan(u->z)) {
                    memcpy(&(p->data[idx]), u, sizeof(pointdata));
                }
                return 1;
            }
        default:
            return 0;
    }
}

static int vectorlib_points_setnext(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p && p->index < p->size) {
        if (vectorlib_points_aux_set(L, 2, p, p->index)) {
            p->index++;
        }
    }
    return 0;
}

static int vectorlib_points_type(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p) {
        lua_push_key(points);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_points_totable(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p) {
        lua_createtable(L, p->size, 0);
        for (int n = 0; n < p->size; n++) {
            int i = 1;
            lua_createtable(L, 6, 0);
            lua_pushnumber(L, p->data[n].x);  lua_rawseti(L, -2, i++);
            lua_pushnumber(L, p->data[n].y);  lua_rawseti(L, -2, i++);
            lua_pushnumber(L, p->data[n].z);  lua_rawseti(L, -2, i++);
            lua_pushnumber(L, p->data[n].nx); lua_rawseti(L, -2, i++);
            lua_pushnumber(L, p->data[n].ny); lua_rawseti(L, -2, i++);
            lua_pushnumber(L, p->data[n].nz); lua_rawseti(L, -2, i++);
        //  lua_pushnumber(L, p->data[n].u);  lua_rawseti(L, -2, i++);
        //  lua_pushnumber(L, p->data[n].v);  lua_rawseti(L, -2, i  );
            lua_rawseti(L, -2, n + 1);
        }
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_points_get(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    int n = lmt_tointeger(L, 2) - 1;
    if (p && n >= 0 && n < p->size) {
        lua_pushnumber(L, p->data[n].x);
        lua_pushnumber(L, p->data[n].y);
        lua_pushnumber(L, p->data[n].z);
        lua_pushnumber(L, p->data[n].nx);
        lua_pushnumber(L, p->data[n].ny);
        lua_pushnumber(L, p->data[n].nz);
     // lua_pushnumber(L, p->data[n].u);
     // lua_pushnumber(L, p->data[n].v);
        return 6;
    } else {
        return 0;
    }
}

static int vectorlib_points_getxyz(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    int n = lmt_tointeger(L, 2) - 1;
    if (p && n >= 0 && n < p->size) {
        lua_pushnumber(L, p->data[n].x);
        lua_pushnumber(L, p->data[n].y);
        lua_pushnumber(L, p->data[n].z);
        return 3;
    } else {
        return 0;
    }
}

static int vectorlib_points_getnormal(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    int n = lmt_tointeger(L, 2) - 1;
    if (p && n >= 0 && n < p->size) {
        lua_pushnumber(L, p->data[n].nx);
        lua_pushnumber(L, p->data[n].ny);
        lua_pushnumber(L, p->data[n].nz);
        return 3;
    } else {
        return 0;
    }
}

// static int vectorlib_points_getuv(lua_State *L)
// {
//     points p = vectorlib_points_aux_get(L, 1);
//     int n = lmt_tointeger(L, 2) - 1;
//     if (p && n >= 0 && n < p->size) {
//         lua_pushnumber(L, p->data[n].u);
//         lua_pushnumber(L, p->data[n].v);
//         return 2;
//     } else {
//         return 0;
//     }
// }

static int vectorlib_points_set(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    int n = lmt_tointeger(L, 2) - 1;
    if (p && n >= 0 && n < p->size) {
        vectorlib_points_aux_set(L, 3, p, n);
    }
    return 0;
}

static int vectorlib_points_setxyz(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    int n = lmt_tointeger(L, 2) - 1;
    if (p && n >= 0 && n < p->size) {
        p->data[n].x = lua_tonumber(L, 3);
        p->data[n].y = lua_tonumber(L, 4);
        p->data[n].z = lua_tonumber(L, 5);
    }
    return 0;
}

static int vectorlib_points_setnormal(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    int n = lmt_tointeger(L, 2) - 1;
    if (p && n >= 0 && n < p->size) {
        p->data[n].nx = lua_tonumber(L, 3);
        p->data[n].ny = lua_tonumber(L, 4);
        p->data[n].nz = lua_tonumber(L, 5);
    }
    return 0;
}

// static int vectorlib_points_setuv(lua_State *L)
// {
//     points p = vectorlib_points_aux_get(L, 1);
//     int n = lmt_tointeger(L, 2) - 1;
//     if (p && n >= 0 && n < p->size) {
//         p->data[n].u = lua_tonumber(L, 3);
//         p->data[n].v = lua_tonumber(L, 4);
//     }
//     return 0;
// }

static int vectorlib_points_getbounds(lua_State *L)
{
    points p = vectorlib_points_aux_get(L, 1);
    if (p) {
        int    done    = 0;
        double xmin    = 0;
        double xmax    = 0;
        double ymin    = 0;
        double ymax    = 0;
        double zmin    = 0;
        double zmax    = 0;
        int    astable = lua_toboolean(L, 2);
        for (int i = 0; i < p->size; i++) {
            if (done) {
                if (p->data[i].x > xmax) { xmax = p->data[i].x; } else if (p->data[i].x < xmin) { xmin = p->data[i].x; }
                if (p->data[i].y > ymax) { ymax = p->data[i].y; } else if (p->data[i].y < ymin) { ymin = p->data[i].y; }
                if (p->data[i].z > zmax) { zmax = p->data[i].z; } else if (p->data[i].z < zmin) { zmin = p->data[i].z; }
            } else {
                xmin = p->data[i].x; xmax = p->data[i].x;
                ymin = p->data[i].y; ymax = p->data[i].y;
                zmin = p->data[i].z; zmax = p->data[i].z;
                done = 1;
            }
        }
        if (astable) {
            lua_createtable(L, 0, 6);
        }
        lua_pushnumber(L, xmin);
        lua_pushnumber(L, xmax);
        lua_pushnumber(L, ymin);
        lua_pushnumber(L, ymax);
        lua_pushnumber(L, zmin);
        lua_pushnumber(L, zmax);
        if (astable) {
            lua_setfield(L, -7, "zmax"); /* we can use the fast method */
            lua_setfield(L, -6, "zmin");
            lua_setfield(L, -5, "ymax");
            lua_setfield(L, -4, "ymin");
            lua_setfield(L, -3, "xmax");
            lua_setfield(L, -2, "xmin");
            return 1;
        } else {
            return 6;
        }
     // if (lua_toboolean(L, 2)) {
     //     lua_createtable(L, 0, 6);
     //     lua_pushnumber(L, xmin); lua_setfield(L, -2, "xmin");
     //     lua_pushnumber(L, xmax); lua_setfield(L, -2, "xmax");
     //     lua_pushnumber(L, ymin); lua_setfield(L, -2, "ymin");
     //     lua_pushnumber(L, ymax); lua_setfield(L, -2, "ymax");
     //     lua_pushnumber(L, zmin); lua_setfield(L, -2, "zmin");
     //     lua_pushnumber(L, zmax); lua_setfield(L, -2, "zmax");
     //     return 1;
     // } else {
     //     lua_pushnumber(L, xmin);
     //     lua_pushnumber(L, xmax);
     //     lua_pushnumber(L, ymin);
     //     lua_pushnumber(L, ymax);
     //     lua_pushnumber(L, zmin);
     //     lua_pushnumber(L, zmax);
     //     return 6;
     // }
    } else {
        return 0;
    }
}

/*tex

    We're done. What rests is opening up the interfaces. Keep in mind that much here is not really
    meant for users! It is geared towards integration in \LUAMETAFUN\ so not even \METAPOST\ calls
    for it directly; we glue various mechamnisms together!

 */

static const luaL_Reg vectorlib_vector_function_list[] =
{
    /* management */
    { "new",            vectorlib_new              },
    { "isvector",       vectorlib_vector_valid     },
    { "ismesh",         vectorlib_mesh_valid       },
    { "ispoints",       vectorlib_points_valid     },
    { "onerow",         vectorlib_onerow           },
    { "onecolumn",      vectorlib_onecolumn        },
    { "copy",           vectorlib_copy             },
    { "type",           vectorlib_type             },
    { "tostring",       vectorlib_tostring         },
    { "totable",        vectorlib_totable          },
    { "get",            vectorlib_getvalue         },
    { "set",            vectorlib_setvalue         },
    { "getrow",         vectorlib_getrow           }, /* table */
    { "getrc",          vectorlib_getvaluerc       },
    { "setrc",          vectorlib_setvaluerc       },
    { "setnext",        vectorlib_setnext          },
    { "getsize",        vectorlib_getsize          }, /* the index */
    { "getmemory",      vectorlib_getmemory        }, /* memory not managed by lua */
    /* info */
    { "gettype",        vectorlib_gettype          },
    { "setstacking",    vectorlib_setstacking      },
    { "getstacking",    vectorlib_getstacking      },
    { "getdimensions",  vectorlib_getdimensions    },
    { "setepsilon",     vectorlib_setepsilon       },
    { "getepsilon",     vectorlib_getepsilon       },
    { "iszero",         vectorlib_iszero           },
 /* { "isidentity",     vectorlib_isidentity       }, */ /* todo */
    /* operators */
    { "add",            vectorlib_add              },
    { "div",            vectorlib_div              },
    { "mul",            vectorlib_mul              },
    { "sub",            vectorlib_sub              },
    { "negate",         vectorlib_neg              },
    { "equal",          vectorlib_eq               },
    /* functions */
    { "round",          vectorlib_round            },
    { "floor",          vectorlib_floor            },
    { "ceiling",        vectorlib_ceiling          },
    { "truncate",       vectorlib_truncate         },
    { "inverse",        vectorlib_inverse          },
    { "rowechelon",     vectorlib_rowechelon       },
    { "identity",       vectorlib_identity         },
    { "transpose",      vectorlib_transpose        },
    { "normalize",      vectorlib_normalize        },
    { "homogenize",     vectorlib_homogenize       },
    { "determinant",    vectorlib_determinant      },
    { "issingular",     vectorlib_issingular       },
    { "inner",          vectorlib_inner            }, /* maybe: innerproduct */
    { "product",        vectorlib_product          },
    { "crossproduct",   vectorlib_crossproduct     },
    /* manipulations */
    { "concat",         vectorlib_concat           },
    { "slice",          vectorlib_slice            },
    { "delete",         vectorlib_delete           },
    { "remove",         vectorlib_remove           },
    { "insert",         vectorlib_insert           },
    { "replace",        vectorlib_replace          },
    { "swap",           vectorlib_swap             },
    { "exchange",       vectorlib_exchange         },
    { "append",         vectorlib_append           },
    /* nothing more */
    { NULL,             NULL                       },
};

static const luaL_Reg vectorlib_point_function_list[] =
{
    /* management */
    { "new",           vectorlib_point_new           },
    { "ispoint",       vectorlib_point_valid         },
    { "copy",          vectorlib_point_copy          },
    { "type",          vectorlib_point_type          },
    { "tostring",      vectorlib_point_tostring      },
    { "totable",       vectorlib_point_totable       },
    { "get",           vectorlib_point_getvalue      },
    { "set",           vectorlib_point_setvalue      },
    { "iszero",        vectorlib_point_iszero        },
    { "add",           vectorlib_point_add           },
    { "div",           vectorlib_point_div           },
    { "mul",           vectorlib_point_mul           },
    { "sub",           vectorlib_point_sub           },
    { "negate",        vectorlib_point_neg           },
    { "dotproduct",    vectorlib_point_dotproduct    },
    { "crossproduct",  vectorlib_point_crossproduct  },
    { "normalize",     vectorlib_point_normalize     },
    { "distance",      vectorlib_point_distance      },
    { "perpendicular", vectorlib_point_perpendicular },
    { "length",        vectorlib_point_getlength     },
    { "equal",         vectorlib_point_eq            },
    /* aliases */
    { "dot",           vectorlib_point_dotproduct    },
    { "cross",         vectorlib_point_crossproduct  },
    { "perp",          vectorlib_point_perpendicular },
    { "dist",          vectorlib_point_distance      },
    { "norm",          vectorlib_point_normalize     },
    { "len",           vectorlib_point_getlength     },
    { "neg",           vectorlib_point_neg           },
    /* nothing more */
    { NULL,            NULL                          },
};

static const luaL_Reg vectorlib_mesh_function_list[] =
{
    { "new",           vectorlib_mesh_new           },
    { "ismesh",        vectorlib_mesh_valid         },
    { "type",          vectorlib_mesh_type          },
    { "tostring",      vectorlib_mesh_tostring      },
    { "totable",       vectorlib_mesh_totable       },
    { "getdimensions", vectorlib_mesh_getdimensions },
    { "get",           vectorlib_mesh_getvalue      }, /* table when third is true */
    { "set",           vectorlib_mesh_setvalue      },
    { "gettypevalues", vectorlib_mesh_gettypevalues },
    /* nothing more */
    { NULL,            NULL                         },
};

static const luaL_Reg vectorlib_contour_function_list[] =
{
    /* for experiments with mp */
    { "average",        vectorlib_contour_average        },
    { "bounds",         vectorlib_contour_bounds         },
    { "makemesh",       vectorlib_contour_makemesh       },
    { "sort",           vectorlib_contour_sort           },
    { "getmesh",        vectorlib_contour_getmesh        },
    { "getarea",        vectorlib_contour_getarea        },
    { "checkoverlap",   vectorlib_contour_checkoverlap   },
    { "collectoverlap", vectorlib_contour_collectoverlap },
    /* nothing more */
    { NULL,            NULL                              },
};

static const luaL_Reg vectorlib_points_function_list[] =
{
    /* */
    { "new",        vectorlib_points_new       },
    { "ispoints",   vectorlib_points_valid     },
    { "type",       vectorlib_points_type      },
    { "totable",    vectorlib_points_totable   },
    { "tostring",   vectorlib_points_tostring  },
    { "get",        vectorlib_points_get       },
    { "set",        vectorlib_points_set       },
    { "getxyz",     vectorlib_points_getxyz    },
    { "setxyz",     vectorlib_points_setxyz    },
    { "getnormal",  vectorlib_points_getnormal },
    { "setnormal",  vectorlib_points_setnormal },
 // { "getuv",      vectorlib_points_getuv     },
 // { "setuv",      vectorlib_points_setuv     },
    { "getbounds",  vectorlib_points_getbounds },
    /* nothing more */
    { NULL,         NULL                       },
};

static const luaL_Reg vectorlib_vector_metatable[] =
{
    { "__len",      vectorlib_getlength },
    { "__index",    vectorlib_getvalue  },
    { "__newindex", vectorlib_setvalue  },
    { "__tostring", vectorlib_tostring  },
    { "__add",      vectorlib_add       },
    { "__div",      vectorlib_div       },
    { "__mul",      vectorlib_mul       },
    { "__sub",      vectorlib_sub       },
    { "__unm",      vectorlib_neg       },
    { "__eq",       vectorlib_eq        },
    { "__concat",   vectorlib_concat    },
    { "__call",     vectorlib_setnext   },
    /* */
    { NULL,         NULL                },
};

static const luaL_Reg vectorlib_point_metatable[] =
{
    { "__len",         vectorlib_point_getlength     },
    { "__index",       vectorlib_point_getvalue      },
    { "__newindex",    vectorlib_point_setvalue      },
    { "__tostring",    vectorlib_point_tostring      },
    { "__add",         vectorlib_point_add           },
    { "__div",         vectorlib_point_div           },
    { "__mul",         vectorlib_point_mul           },
    { "__sub",         vectorlib_point_sub           },
    { "__unm",         vectorlib_point_neg           },
    { "__eq",          vectorlib_point_eq            },
    { "__call",        vectorlib_point_setnext       },
    /* */
    { "negate",        vectorlib_point_neg           },
    { "dotproduct",    vectorlib_point_dotproduct    },
    { "crossproduct",  vectorlib_point_crossproduct  },
    { "normalize",     vectorlib_point_normalize     },
    { "distance",      vectorlib_point_distance      },
    { "perpendicular", vectorlib_point_perpendicular },
    { "length",        vectorlib_point_getlength     },
    /* */
    { "neg",           vectorlib_point_neg           },
    { "dot",           vectorlib_point_dotproduct    },
    { "cross",         vectorlib_point_crossproduct  },
    { "norm",          vectorlib_point_normalize     },
    { "dist",          vectorlib_point_distance      },
    { "perp",          vectorlib_point_perpendicular },
    { "len",           vectorlib_point_getlength     },
    /* */
    { NULL,            NULL                          },
};

static const luaL_Reg vectorlib_mesh_metatable[] =
{
    { "__len",      vectorlib_mesh_getlength },
    { "__index",    vectorlib_mesh_index     },
    { "__newindex", vectorlib_mesh_setvalue  },
    { "__tostring", vectorlib_mesh_tostring  },
    { "__call",     vectorlib_mesh_setnext   },
    { "__gc",       vectorlib_mesh_gc        },
    { NULL,         NULL                     },
};

static const luaL_Reg vectorlib_points_metatable[] =
{
    { "__tostring", vectorlib_points_tostring  },
    { "__len",      vectorlib_points_getlength },
    { "__gc",       vectorlib_points_gc        },
    { "__call",     vectorlib_points_setnext   },
    { NULL,         NULL                       },
};

int luaopen_vector(lua_State *L)
{
    luaL_newmetatable(L, VECTOR_METATABLE_INSTANCE);
    luaL_setfuncs(L, vectorlib_vector_metatable, 0);
    luaL_newmetatable(L, POINT_METATABLE_INSTANCE);
    luaL_setfuncs(L, vectorlib_point_metatable, 0);
    luaL_newmetatable(L, POINTS_METATABLE_INSTANCE);
    luaL_setfuncs(L, vectorlib_points_metatable, 0);
    luaL_newmetatable(L, MESH_METATABLE_INSTANCE);
    luaL_setfuncs(L, vectorlib_mesh_metatable, 0);
    /* vector.* */
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_vector_function_list, 0);
    /* vector.point */
    lua_pushstring(L, lua_key(point));
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_point_function_list, 0);
    lua_rawset(L, -3);
    /* vector.mesh */
    lua_pushstring(L, lua_key(mesh));
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_mesh_function_list, 0);
    lua_rawset(L, -3);
    /* vector.contour */
    lua_pushstring(L, lua_key(contour));
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_contour_function_list, 0);
    lua_rawset(L, -3);
    /* vector.points */
    lua_pushstring(L, lua_key(points));
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_points_function_list, 0);
    lua_rawset(L, -3);
    return 1;
}
