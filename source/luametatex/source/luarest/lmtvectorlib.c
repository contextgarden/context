/*
    See license.txt in the root of this project.
*/

/*tex

    This is just an experiment by Mikael and Hans in the perspective of 3D experiments in
    \METAPOST\ with the \LUA\ interface. It is also a kind of follow up on the \type {matrix}
    module from which we took some of the code. So we have a mix of Jeong Dalyoung, Mikael
    Sundqvist & Hans Hagen code here. More methods might be added.

    This module is sort of generic but also geared at using on combination with \METAPOST, which
    is why we have a few public functions. For that we have extra helpers that work on meshes. 

*/

# include <luametatex.h>
# include "libraries/triangles/triangles.h"

/*tex See |lmtinterface.h| for |VECTOR_METATABLE_INSTANCE|. */
/*tex See |lmtinterface.h| for |MESH_METATABLE_INSTANCE|. */

/*
    todo:

    -- maybe also store size (more readable, less clutter)
    -- extra array for w (doubles)
    -- userdata lua upvalue for whatever extras
*/

static const char *mesh_names[5] = { 
    [no_mesh_type]       = "no", 
    [dot_mesh_type]      = "dot", 
    [line_mesh_type]     = "line", 
    [triangle_mesh_type] = "triangle", 
    [quad_mesh_type]     = "quad"
};

# define valid_mesh(n) (n >= dot_mesh_type && n <= quad_mesh_type ? n : triangle_mesh_type)

/*tex 

    We need to be way above EPSILON in triangles.c because otherwise we get too many 
    false positives at that end! 

    For practical reason we now use a configurable epsilon because we need to interplay 
    nicely with the overlap detection. Alas.  

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

/* memcpy(v->data, a->data,a->rows * a->columns * sizeof(double)); */

inline static void vectorlib_aux_copy_data(vector v, const vector a)
{
    for (int i = 0; i < a->rows * a->columns; i++) {
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
            v->rows = r;
            v->columns = c;
            v->type = generic_type;
            v->stacking = s;
            v->index = 0;
            v->padding = 0;
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

static int vectorlib_isvector(lua_State *L)
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
                    if (t > v->rows * v->columns) {
                        t = v->rows * v->columns;
                    }
                    for (int i = 0; i < t; i++) {
                        v->data[i] = lua_type(L, i + 3) == LUA_TNUMBER ? lua_tonumber(L, i + 3) : 0.0;
                    }
                } else {
                    for (int i = 0; i < v->rows * v->columns; i++) {
                        v->data[i] = 0.0;
                    }
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
        for (int i = 0; i < t; i++) {
            v->data[i] = lua_tonumber(L, i + 1);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static inline int vectorlib_onecolumn(lua_State *L)
{
    int t = lua_gettop(L);
    if (t) {
        vector v = vectorlib_aux_push(L, t, 1, 0);
        for (int i = 0; i < t; i++) {
            v->data[i] = lua_tonumber(L, i + 1);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
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
            lua_createtable(L, v->rows * v->columns, 0);
            for (int i = 1; i <= v->rows * v->columns; i++) {
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
        v->type = a->type;
        vectorlib_aux_copy_data(v, a);
    } else {
        lua_pushnil(L);
    }
    return 1;
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
        for (int i = 0; i < b->rows * b->columns; i++) {
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
            for (int i = 0; i < b->rows * b->columns; i++) {
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
            for (int i = 0; i < a->rows * a->columns; i++) {
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
            for (int i = 0; i < a->rows * a->columns; i++) {
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
            for (int i = 0; i < b->rows * b->columns; i++) {
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
            for (int i = 0; i < a->rows * a->columns; i++) {
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
            for (int i = 0; i < a->rows * a->columns; i++) {
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
                for (int i = 0; i < b->rows * b->columns; i++) {
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
                for (int i = 0; i < a->rows * a->columns; i++) {
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
            for (int i = 0; i < a->rows * a->columns; i++) {
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
        for (int i = 0; i < a->rows * a->columns; i++) {
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
        lua_pushnumber(L, index > 0 && index <= v->rows * v->columns ? v->data[index-1] : 0);
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
        if (index > 0 && index <= v->rows * v->columns) {
            v->data[index-1] = lua_type(L, 3) == LUA_TNUMBER ? lua_tonumber(L, 3) : 0;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int vectorlib_getlength(lua_State *L)
{
    vector v = vectorlib_aux_get(L, 1);
    lua_pushinteger(L, v ? v->rows : 0);
    return 1;
}

static int vectorlib_setnext(lua_State *L)
{
    vector a = vectorlib_aux_get(L, 1);
    if (a && a->index < (a->rows * a->columns)) {
        int value = 1;
        for (int c = 0; c < a->columns; c++) { 
            a->data[a->index++] = lua_type(L, ++value) == LUA_TNUMBER ? lua_tonumber(L, value) : 0;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
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
        for (int i = 0; i < v->rows * v->columns; i++) {
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
        for (int i = 0; i < a->rows * a->columns; i++) {
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
        for (int i = 0; i < a->rows * a->columns; i++) {
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
        for (int i = 0; i < a->rows * a->columns; i++) {
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
            for (int i = 0; i < a->rows * a->columns; i++) {
                if (ISZERO(a->data[i])) { 
                    a->data[i] = 0.0;
                }
            }
        } else {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            double epsilon = lmt_optdouble(L, 3, vector_epsilon);
            for (int i = 0; i < a->rows * a->columns; i++) {
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
        for (int i = 0; i < a->rows * a->columns; i++) {
            d += a->data[i] * a->data[i];
        }
        if (d > 0.0) {
            vector v = vectorlib_aux_push(L, a->rows, a->columns, a->stacking);
            d = sqrt(d);
            for (int i = 0; i < a->rows * a->columns; i++) {
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
                long index = a->rows * a->columns;
                vectorlib_aux_copy_data(v, a);
                for (int i = 0; i < b->rows * b->columns; i++) {
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
                for (int i = 0; i < a->rows * a->columns; i++) {
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

static inline unsigned short vectorlib_valid_point(lua_State *L, int index)
{
    int p = lmt_tointeger(L, index);
    return p < 0 ? 0 : p > max_mesh ? max_mesh : p;
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

static int vectorlib_ismesh(lua_State *L)
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

static inline void vectorlib_mesh_wipe_entry(meshentry *entry)
{
    for (int i = 0; i < 4; i++) {
        entry->points[i] = 0;
    }
    entry->average = 0.0;
}

static inline mesh vectorlib_mesh_aux_push(lua_State *L, int r)
{
    mesh m = lua_newuserdatauv(L, 2 * sizeof(int) + r * sizeof(meshentry), 0);
    if (m && r > 0) {
        m->rows = r;
        m->type = triangle_mesh_type;
        lua_get_metatablelua(mesh_instance);
        lua_setmetatable(L, -2);
    }
    return m;
}

static int vectorlib_mesh_new(lua_State *L)
{
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
            {
                mesh m = vectorlib_mesh_aux_push(L, lmt_optinteger(L, 1, 1));
                for (int i = 0; i < m->rows; i++) {
                    vectorlib_mesh_wipe_entry(&(m->data[i]));
                }
                return 1;
            }
        case LUA_TTABLE:
           {
                int t = lua_rawgeti(L, 1, 1);
                lua_pop(L, 1);
                switch (t) {
                    case LUA_TNUMBER:
                        /* local v = vector.new(   { 1,2,3 }, { 4,5,6  }  ) */ /* n can determine quads */
                        {
                            int rows = lua_gettop(L);
                            if (rows) {
                                mesh m = vectorlib_mesh_aux_push(L, rows);
                                for (int i = 0; i < rows; i++) {
                                    meshentry *entry = &(m->data[i]);
                                    if (lua_type(L, i + 1) == LUA_TTABLE) {
                                        for (int j = 0; j < 4; j++) {
                                            entry->points[j] = lua_rawgeti(L, i + 1, j + 1) == LUA_TNUMBER ? vectorlib_valid_point(L, -1) : 0;
                                            lua_pop(L, 1);
                                        }
                                        entry->average = 0.0;
                                    } else {
                                        vectorlib_mesh_wipe_entry(entry);
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
                            int rows = (int) lua_rawlen(L, 1);
                            if (rows) {
                                mesh m = vectorlib_mesh_aux_push(L, rows);
                                for (int i = 0; i < rows; i++) {
                                    meshentry *entry = &(m->data[i]);
                                    if (lua_rawgeti(L, 1, i + 1) == LUA_TTABLE) {
                                        for (int j = 0; j < 4; j++) {
                                            entry->points[j] = lua_rawgeti(L, -1, j + 1) == LUA_TNUMBER ? vectorlib_valid_point(L, -1) : 0;
                                            lua_pop(L, 1);
                                        }
                                        entry->average = 0.0;
                                    } else { 
                                        vectorlib_mesh_wipe_entry(entry);
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


inline static mesh vectorlib_mesh_aux_get(lua_State *L, int index)
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

mesh vectorlib_get_mesh(lua_State *L, int index)
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

static int vectorlib_mesh_tostring(lua_State *L)
{
    mesh v = vectorlib_mesh_aux_get(L, 1);
    if (v) {
        lua_pushfstring(L, "<mesh %d %s : %p>", v->rows, mesh_names[valid_mesh(v->type)], v);
        return 1;
    } else {
        return 0;
    }
}

static int vectorlib_mesh_totable(lua_State *L)
{
    mesh m = vectorlib_aux_maybe_ismesh(L, 1);
    if (m) { 
        long target = 1;
        int size = m->type == quad_mesh_type ? 4 : 3;
        if (lua_toboolean(L, 2)) {
            lua_createtable(L, m->rows * (size + 1), 0);
            for (int r = 0; r < m->rows; r++) {
                meshentry *triangle = &(m->data[r]);
                for (int i = 0; i < size; i++) {
                    lua_pushinteger(L, triangle->points[i]);    
                    lua_rawseti(L, -2, target++);
                }
                lua_pushnumber(L, triangle->average); 
                lua_rawseti(L, -2, target++);
            }
        } else {
            lua_createtable(L, m->rows, 0);
            for (int r = 0; r < m->rows; r++) {
                meshentry *triangle = &(m->data[r]);
                long index = 1; 
                lua_createtable(L, size + 1, 0);
                for (int i = 0; i < size; i++) {
                    lua_pushinteger(L, triangle->points[i]);    
                    lua_rawseti(L, -2, index++);
                }
                lua_pushnumber(L, triangle->average); 
                lua_rawseti(L, -2, index);
                lua_rawseti(L, -2, target++);
            }
        }
        return 1;
    } else { 
        return 0;
    }
}

static int vectorlib_mesh_index(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        int index = lmt_tointeger(L, 2);
        if (index > 0 && index <= m->rows) { 
            lua_pushnumber(L, m->data[index - 1].average);
            return 1;
        }
    }
    return 0;
}

static int vectorlib_mesh_getvalue(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        int index = lmt_tointeger(L, 2);
        if (index > 0 && index <= m->rows) { 
            meshentry *triangle = &(m->data[index-1]);
            int size = m->type == quad_mesh_type ? 4 : 3;
            if (lua_toboolean(L, 3)) {
                long target = 1;
                lua_createtable(L, size + 1, 0);
                for (int i = 0; i < size; i++) {
                    lua_pushinteger(L, triangle->points[i]);
                    lua_rawseti(L, -2, target++);
                }
                lua_pushnumber(L, triangle->average);
                lua_rawseti(L, -2, target);
                return 1;
            } else { 
                for (int i = 0; i < size; i++) {
                    lua_pushinteger(L, triangle->points[i]);
                }
                lua_pushnumber(L, triangle->average);
                return size + 1;
            }
        }
    }
    return 0;
}

static int vectorlib_mesh_setvalue(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        int index = lmt_tointeger(L, 2);
        if (index > 0 && index <= m->rows) { 
            meshentry *triangle = &(m->data[index-1]);
            switch (lua_type(L, 3)) {
                case LUA_TNUMBER:
                    {
                        triangle->average = lua_tonumber(L, 3);
                        break;
                    }
                case LUA_TTABLE:
                    {
                        int size = m->type == quad_mesh_type ? 4 : 3;
                        for (int i = 1; i <= size; i++) {
                            if (lua_rawgeti(L, 3, i) == LUA_TNUMBER) {
                                if (i < size) {
                                    triangle->points[i-1] = vectorlib_valid_point(L, -1);
                                } else { 
                                    triangle->average = lua_tonumber(L, -1);
                                }
                            }
                            lua_pop(L, 1);
                        }
                        break;
                    }
            }
        }
    }
    return 0;
}

static int vectorlib_mesh_getlength(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    lua_pushinteger(L, m ? m->rows : 0);
    return 1;
}


static int vectorlib_mesh_getdimensions(lua_State *L)
{
    mesh m = vectorlib_mesh_aux_get(L, 1);
    if (m) {
        lua_pushinteger(L, m->rows);
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
        if (vectorlib_contour_aux_okay(*l && valid_mesh((*l)->type), what, "mesh list expected ((p1 .. pN),average)")) { 
            return 1;
        }
    }
    return 0;
}

static int vectorlib_contour_getmesh(lua_State *L)
{
    vector v = NULL;
    mesh l = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &l, "getmesh")) {
        int i = lmt_tointeger(L, 3) - 1; /* triangle index */
        if (i >= 0 && i < l->rows) {
            int done = 0;
            int okay = 0;
            int size = valid_mesh(l->type);
            meshentry *triangle = &(l->data[i]);
            for (int j = 0; j < size; j++) {
                int r = triangle->points[j] - 1;
                if (r >= 0 && r < v->rows) { 
                    int k = r * v->columns;
                    if (! okay) { 
                        lua_createtable(L, 2 * size, 0);
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
                lua_pushnumber(L, triangle->average);
                return 2;
            } else {
                /*tex We signal that we have a zero entry. */
                lua_pushboolean(L, 0);
                return 1;
            }
        }
    }
    return 0;
}

static int vectorlib_contour_getarea(lua_State *L)
{
    vector v = NULL;
    mesh l = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &l, "getarea")) {
        int i = lmt_tointeger(L, 3) - 1; /* triangle index */
        if (i >= 0 && i < l->rows) {
            meshentry *entry = &(l->data[i]);
            switch (l->type) { 
                case line_mesh_type:
                    lua_pushnumber(L, 0.0);
                    return 1;
                case quad_mesh_type:
                    {
                        int p1 = entry->points[0] - 1;
                        int p3 = entry->points[2] - 1;
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
                case triangle_mesh_type: /* from wikipedia */
                    {
                        int p1 = entry->points[0] - 1;
                        int p2 = entry->points[1] - 1;
                        int p3 = entry->points[2] - 1;
                        if (p1 >= 0 && p1 < v->rows && p2 >= 0 && p2 < v->rows && p3 >= 0 && p3 < v->rows) { 
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
    return 0;
}

/* see below, todo: optimize */

static int vectorlib_contour_aux_checkoverlap(vector v, mesh l, int U, int V, int method, double epsilon)
{
    int u0 = l->data[U].points[0] - 1;
    int u1 = l->data[U].points[1] - 1;
    int u2 = l->data[U].points[2] - 1;
    int v0 = l->data[V].points[0] - 1;
    int v1 = l->data[V].points[1] - 1;
    int v2 = l->data[V].points[2] - 1;
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
    mesh l = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &l, "checkoverlap")) {
        if (l->type == triangle_mesh_type) { 
            int U = lmt_tointeger(L, 3) - 1;
            int V = lmt_tointeger(L, 4) - 1;
            if (U >= 0 && U < l->rows && V >= 0 && V < l->rows) {
                int method = lmt_optinteger(L, 5, 1);
                double epsilon = lmt_optdouble(L, 6, vector_epsilon);
                int overlapping = vectorlib_contour_aux_checkoverlap(v, l, U, V, method, epsilon);
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
    mesh l = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &l, "collectoverlap")) {
        if (l->type == triangle_mesh_type) { 
            int details = lua_toboolean(L, 3);
            int method = lmt_optinteger(L, 4, 1);
            double epsilon = lmt_optdouble(L, 5, vector_epsilon);
            int vr = v->rows; 
            int vc = v->columns; 
            int lr = l->rows; 
            int m = 0;
            for (int i = 0; i < lr; i++) {
                meshentry *triangle = &(l->data[i]);
                int u0 = triangle->points[0];
                int u1 = triangle->points[1];
                int u2 = triangle->points[2];
                if (
                    u0 >= 1  && u1 >= 1  && u2 >= 1  &&
                    u0 <= vr && u1 <= vr && u2 <= vr
                ) {
                } else { 
                    vectorlib_contour_aux_okay(0, "collectoverlap", "triangle list entries has invalid point references");
                    return 0;
                }
            }
            for (int i = 0; i < lr - 1; i++) {
                meshentry *triangle = &(l->data[i]);
                int u0 = triangle->points[0] - 1;
                int u1 = triangle->points[1] - 1;
                int u2 = triangle->points[2] - 1;
                double *U0 = &(v->data[u0 * vc]); 
                double *U1 = &(v->data[u1 * vc]); 
                double *U2 = &(v->data[u2 * vc]); 
                for (int j = i + 1; j < lr; j++) {
                    meshentry *triangle = &(l->data[j]);
                    int v0 = triangle->points[0] - 1;
                    if (
                        u0 == v0 || u1 == v0 || u2 == v0 
                    ) { 
                        continue; /* triangles_intersection_nop_same_points */
                    }
                    int v1 = triangle->points[1] - 1;
                    if (
                        u0 == v1 || u1 == v1 || u2 == v1
                    ) { 
                        continue; /* triangles_intersection_nop_same_points */
                    }
                    int v2 = triangle->points[2] - 1;
                    if (
                        u0 == v2 || u1 == v2 || u2 == v2
                    ) { 
                        continue; /* triangles_intersection_nop_same_points */
                    } 
                    double *V0 = &(v->data[v0 * vc]); 
                    if ( 
                        (ISZERO(U0[0] - V0[0]) && ISZERO(U0[1] - V0[1]) && ISZERO(U0[2] - V0[2])) || 
                        (ISZERO(U1[0] - V0[0]) && ISZERO(U1[1] - V0[1]) && ISZERO(U1[2] - V0[2])) || 
                        (ISZERO(U2[0] - V0[0]) && ISZERO(U2[1] - V0[1]) && ISZERO(U2[2] - V0[2]))
                    ) { 
                        continue; /* triangles_intersection_nop_same_values */
                    } 
                    double *V1 = &(v->data[v1 * vc]); 
                    if ( 
                        (ISZERO(U0[0] - V1[0]) && ISZERO(U0[1] - V1[1]) && ISZERO(U0[2] - V1[2])) || 
                        (ISZERO(U1[0] - V1[0]) && ISZERO(U1[1] - V1[1]) && ISZERO(U1[2] - V1[2])) || 
                        (ISZERO(U2[0] - V1[0]) && ISZERO(U2[1] - V1[1]) && ISZERO(U2[2] - V1[2])) 
                    ) { 
                        continue; /* triangles_intersection_nop_same_values */
                    } 
                    double *V2 = &(v->data[v2 * vc]);
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
                            if (! m) {
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
                            lua_rawseti(L, -2, ++m);
                        }
                    } else {
                        int state = method == 2
                            ? triangles_intersect_gd(U0, U1, U2, V0, V1, V2, epsilon)
                            : triangles_intersect   (U0, U1, U2, V0, V1, V2, epsilon);
                        if (state > triangles_intersection_yes_bound) { 
                            if (! m) {
                                lua_createtable(L, 8, 0);
                            }
                            lua_createtable(L, 2, 0);
                            lua_pushinteger(L, i + 1);
                            lua_rawseti(L, -2, 1);
                            lua_pushinteger(L, j + 1);
                            lua_rawseti(L, -2, 2);
                            lua_rawseti(L, -2, ++m);
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
    mesh l = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &l, "average")) {
        double minx = 0.0;
        double maxx = 0.0;
        double miny = 0.0;
        double maxy = 0.0;
        double minz = 0.0;
        double maxz = 0.0;
        int okay = 0;
        int done = 0;
        int size = valid_mesh(l->type);
        int tolerant = lua_toboolean(L, 3);
        int method = lmt_optinteger(L, 4, 1);
     // int first = lmt_optinteger(L, 5, 1);
     // int last = lmt_optinteger(L, 6, l->rows);
     // if (first <= 0) {
     //     first = 0;
     // } else { 
     //     --first;
     // }
     // if (last == 0) { 
     //     last = l->rows;
     // } else if (last > l->rows) { 
     //     last = l->rows;
     // } else { 
     //     --last;
     // }
     // for (int i = first; i < last; i++) {
        for (int i = 0; i < l->rows; i++) {
            meshentry *entry = &(l->data[i]);
            double average = 0.0;
            double amin = 0;
            int a = 0;
            for (int j = 0; j < size; j++) {
                int r = entry->points[j];
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
            entry->average = average;
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
    } else { 
        return 0;
    }
}

static int vectorlib_contour_bounds(lua_State *L)
{
    vector v = NULL;
    mesh l = NULL;
    if (vectorlib_contour_aux_is_valid(L, &v, &l, "bounds")) {
        double minx = 0.0;
        double maxx = 0.0;
        double miny = 0.0;
        double maxy = 0.0;
        int okay = 0;
        int size = valid_mesh(l->type);
        int first = lmt_optinteger(L, 3, 1);
        int last = lmt_optinteger(L, 4, l->rows);
        if (first <= 0) {
            first = 0;
        } else { 
            --first;
        }
        if (last == 0) { 
            last = l->rows;
        } else if (last > l->rows) { 
            last = l->rows;
        } else { 
            --last;
        }
        for (int i = first; i < last; i++) {
            meshentry *entry = &(l->data[i]);
            for (int j = 0; j < size; j++) {
                int r = entry->points[j];
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
    return 0;
}

int vectorlib_contour_compare_mesh_average(const void *entry_1, const void *entry_2) 
{
    const meshentry *value_1 = (const meshentry *) entry_1;
    const meshentry *value_2 = (const meshentry *) entry_2;
    if (value_1->average > value_2->average) { 
        return  1;
    } else if (value_1->average < value_2->average) {
        return -1;
    } else {
        return 0;
    }
}

static int vectorlib_contour_sort(lua_State *L)
{
    mesh m = vectorlib_get_mesh(L, 1);
    if (m && m->rows > 1) {
        qsort(m->data, m->rows, sizeof(meshentry), vectorlib_contour_compare_mesh_average);
    }
    return 0;
}

/* we can combine these two */

static int vectorlib_contour_makemesh(lua_State *L) 
{
    int columns = lmt_tointeger(L, 1);
    int rows = lmt_tointeger(L, 2);
    int size = columns * rows;
    int type = valid_mesh(lmt_optinteger(L, 3, triangle_mesh_type));
    if (size > 0 && size <= max_mesh) {
        switch (type) { 
            case triangle_mesh_type:
                size *= 2;
                break;
            case quad_mesh_type:
                break;
            case line_mesh_type:
                break;
            default: 
                /*tex We silently recover. */
                type = triangle_mesh_type;
                size *= 2;
                break;
        }
        /*tex When we arrived here we're okay. */
        {
            mesh m = vectorlib_mesh_aux_push(L, size);
            int index = 0; 
            int offset = columns + 1;
            m->type = type;
            for (int r = 1; r <= rows; r++) {
                for (int c = 1; c <= columns; c++) {
                    int p1 = (r - 1) * offset + c; // left point of current row
                    int p2 =  r      * offset + c; // left point of next row
                    int p11 = p1 + 1;
                    int p21 = p2 + 1;
                    if (p11 > max_mesh || p21 > max_mesh) {
                        /* we clip */
                    } else {
                        switch (type) { 
                            case triangle_mesh_type:
                                /* first */
                                m->data[index  ].points[0] = (unsigned short) p1;
                                m->data[index  ].points[1] = (unsigned short) p11;
                                m->data[index  ].points[2] = (unsigned short) p21;
                                m->data[index  ].points[3] = 0;
                                m->data[index++].average   = 0.0;
                                /* second */
                                m->data[index  ].points[0] = (unsigned short) p1;
                                m->data[index  ].points[1] = (unsigned short) p21;
                                m->data[index  ].points[2] = (unsigned short) p2;
                                m->data[index  ].points[3] = 0;
                                m->data[index++].average   = 0.0;
                                break;
                            case quad_mesh_type: 
                                m->data[index  ].points[0] = (unsigned short) p1;
                                m->data[index  ].points[1] = (unsigned short) p11;
                                m->data[index  ].points[2] = (unsigned short) p21;
                                m->data[index  ].points[3] = (unsigned short) p2;
                                m->data[index++].average   = 0.0;
                                break;
                            case line_mesh_type: 
                                m->data[index  ].points[0] = (unsigned short) p1;
                                m->data[index  ].points[1] = (unsigned short) p2;
                                m->data[index  ].points[2] = 0;
                                m->data[index  ].points[3] = 0;
                                m->data[index++].average   = 0.0;
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

/* */

static const luaL_Reg vectorlib_vector_function_list[] =
{
    /* management */
    { "new",            vectorlib_new            },
    { "isvector",       vectorlib_isvector       },
    { "ismesh",         vectorlib_ismesh         },
    { "onerow",         vectorlib_onerow         },
    { "onecolumn",      vectorlib_onecolumn      },
    { "copy",           vectorlib_copy           },
    { "type",           vectorlib_type           },
    { "tostring",       vectorlib_tostring       },
    { "totable",        vectorlib_totable        },
    { "get",            vectorlib_getvalue       },
    { "set",            vectorlib_setvalue       },
    { "getrow",         vectorlib_getrow         }, /* table */
    { "getrc",          vectorlib_getvaluerc     },
    { "setrc",          vectorlib_setvaluerc     },
    { "setnext",        vectorlib_setnext        },
    /* info */
    { "gettype",        vectorlib_gettype        },
    { "setstacking",    vectorlib_setstacking    },
    { "getstacking",    vectorlib_getstacking    },
    { "getdimensions",  vectorlib_getdimensions  },
    { "setepsilon",     vectorlib_setepsilon     },
    { "getepsilon",     vectorlib_getepsilon     },
    { "iszero",         vectorlib_iszero         },
 /* { "isidentity",     vectorlib_isidentity     }, */ /* todo */
    /* operators */
    { "add",            vectorlib_add            },
    { "div",            vectorlib_div            },
    { "mul",            vectorlib_mul            },
    { "sub",            vectorlib_sub            },
    { "negate",         vectorlib_neg            },
    { "equal",          vectorlib_eq             },
    /* functions */
    { "round",          vectorlib_round          },
    { "floor",          vectorlib_floor          },
    { "ceiling",        vectorlib_ceiling        },
    { "truncate",       vectorlib_truncate       },
    { "inverse",        vectorlib_inverse        },
    { "rowechelon",     vectorlib_rowechelon     },
    { "identity",       vectorlib_identity       },
    { "transpose",      vectorlib_transpose      },
    { "normalize",      vectorlib_normalize      },
    { "homogenize",     vectorlib_homogenize     },
    { "determinant",    vectorlib_determinant    },
    { "issingular",     vectorlib_issingular     },
    { "inner",          vectorlib_inner          }, /* maybe: innerproduct */
    { "product",        vectorlib_product        },
    { "crossproduct",   vectorlib_crossproduct   },
    /* manipulations */
    { "concat",         vectorlib_concat         },
    { "slice",          vectorlib_slice          },
    { "delete",         vectorlib_delete         },
    { "remove",         vectorlib_remove         },
    { "insert",         vectorlib_insert         },
    { "replace",        vectorlib_replace        },
    { "swap",           vectorlib_swap           },
    { "exchange",       vectorlib_exchange       },
    { "append",         vectorlib_append         },
    /* nothing more */                                            
    { NULL,             NULL                     },
};

static const luaL_Reg vectorlib_mesh_function_list[] =
{
    { "new",           vectorlib_mesh_new           },
    { "ismesh",        vectorlib_ismesh             },
    { "type",          vectorlib_mesh_type          },
    { "tostring",      vectorlib_mesh_tostring      },
    { "totable",       vectorlib_mesh_totable       },
    { "getdimensions", vectorlib_mesh_getdimensions },
    { "get",           vectorlib_mesh_getvalue      }, /* table when third is true */
    { "set",           vectorlib_mesh_setvalue      },
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
    { NULL,         NULL                },
};

static const luaL_Reg vectorlib_mesh_metatable[] =
{
    { "__len",      vectorlib_mesh_getlength },
    { "__index",    vectorlib_mesh_index     },
    { "__newindex", vectorlib_mesh_setvalue  },
    { "__tostring", vectorlib_mesh_tostring  },
    { NULL,         NULL                     },
};

int luaopen_vector(lua_State *L)
{
    luaL_newmetatable(L, VECTOR_METATABLE_INSTANCE);
    luaL_setfuncs(L, vectorlib_vector_metatable, 0);
    luaL_newmetatable(L, MESH_METATABLE_INSTANCE);
    luaL_setfuncs(L, vectorlib_mesh_metatable, 0);
    /* vector.* */
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_vector_function_list, 0);
    /* vector.mesh */
 // lua_pushliteral(L, "mesh");
    lua_pushstring(L, lua_key(mesh));
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_mesh_function_list, 0);
    lua_rawset(L, -3);
    /* vector.contour */
 // lua_pushstring(L, lua_key(contour));
    lua_pushliteral(L, "contour");
    lua_newtable(L);
    luaL_setfuncs(L, vectorlib_contour_function_list, 0);
    lua_rawset(L, -3);
    return 1;
}
