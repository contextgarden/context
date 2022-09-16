/*

    See license.txt in the root of this project.

    This is a reformatted and slightly adapted version of lcomplex.c:

    title  : C99 complex numbers for Lua 5.3+
    author : Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
    date   : 26 Jul 2018 17:57:06
    licence: This code is hereby placed in the public domain and also under the MIT license

    That implementation doesn't work for MSVC so I rewrote the code to support the microsoft
    compiler. I no longer use the macro approach to save bytes because with expanded code it is
    easier to get rid of some compiler warnings (if possible at all).

    In an optional module we hook the error functions into the complex library.

    Note: Alan has to test if all works okay.

*/

# include "luametatex.h"

# include <complex.h>

# define COMPLEX_METATABLE "complex number"

# if (_MSC_VER)

    /*tex
        Instead of the somewhat strange two-doubles-in-a-row hack in C the microsoft vatiant
        uses structs. Here we use the double variant.
    */

    # define Complex _Dcomplex

    inline static Complex xcomplexlib_get(lua_State *L, int i)
    {
        switch (lua_type(L, i)) {
            case LUA_TUSERDATA:
                return *((Complex*) luaL_checkudata(L, i, COMPLEX_METATABLE));
            case LUA_TNUMBER:
            case LUA_TSTRING:
                return _Cbuild(luaL_checknumber(L, i), 0);
            default:
                return _Cbuild(0, 0);
        }
    }

# else

    /*tex
        Here we use the two-doubles-in-a-row variant.
    */

    # define Complex double complex

    inline static Complex xcomplexlib_get(lua_State *L, int i)
    {
        switch (lua_type(L, i)) {
            case LUA_TUSERDATA:
                return *((Complex*)luaL_checkudata(L, i, COMPLEX_METATABLE));
            case LUA_TNUMBER:
            case LUA_TSTRING:
                return luaL_checknumber(L, i);
            default:
                return 0;
        }
    }

# endif

inline static int xcomplexlib_push(lua_State *L, Complex z)
{
    Complex *p = lua_newuserdatauv(L, sizeof(Complex), 0);
    luaL_setmetatable(L, COMPLEX_METATABLE);
    *p = z;
    return 1;
}

# if (_MSC_VER)

    static int xcomplexlib_new(lua_State *L)
    {
        xcomplexlib_push(L, _Cbuild(0, 0));
        return 1;
    }

    static int xcomplexlib_inew(lua_State *L)
    {
        xcomplexlib_push(L, _Cbuild(0, 1));
        return 1;
    }

    static int xcomplexlib_eq(lua_State *L)
    {
        Complex a = xcomplexlib_get(L, 1);
        Complex b = xcomplexlib_get(L, 2);
        lua_pushboolean(L, creal(a) == creal(b) && cimag(a) == cimag(b));
        return 1;
    }

    static int xcomplexlib_add(lua_State *L) {
        Complex a = xcomplexlib_get(L, 1);
        Complex b = xcomplexlib_get(L, 2);
        return xcomplexlib_push(L, _Cbuild(creal(a) + creal(b), cimag(a) + cimag(b)));
    }

    static int xcomplexlib_sub(lua_State *L) {
        Complex a = xcomplexlib_get(L, 1);
        Complex b = xcomplexlib_get(L, 2);
        return xcomplexlib_push(L, _Cbuild(creal(a) - creal(b), cimag(a) - cimag(b)));
    }

    static int xcomplexlib_neg(lua_State *L) {
        Complex a = xcomplexlib_get(L, 1);
        return xcomplexlib_push(L, _Cbuild(-creal(a), -cimag(a)));
    }

    static int xcomplexlib_div(lua_State *L) {
        Complex b = xcomplexlib_get(L, 2);
        if (creal(b) == 0.0 || cimag(b) == 0.0) {
            return 0;
        } else {
            Complex a = xcomplexlib_get(L, 1);
            Complex t = { 1 / creal(b), 1 / cimag(b) };
            return xcomplexlib_push(L, _Cmulcc(a, t));
        }
    }

    static int xcomplexlib_mul(lua_State *L) {
        Complex a = xcomplexlib_get(L, 1);
        Complex b = xcomplexlib_get(L, 2);
        return xcomplexlib_push(L, _Cmulcc(a, b));
    }

# else

    static int xcomplexlib_new(lua_State *L)
    {
        return xcomplexlib_push(L, luaL_optnumber(L, 1, 0) + luaL_optnumber(L, 2, 0) * I);
    }

    static int xcomplexlib_inew(lua_State *L)
    {
        return xcomplexlib_push(L, I);
    }

    static int xcomplexlib_eq(lua_State *L)
    {
        lua_pushboolean(L, xcomplexlib_get(L, 1) == xcomplexlib_get(L, 2));
        return 1;
    }

    static int xcomplexlib_add(lua_State *L)
    {
        return xcomplexlib_push(L, xcomplexlib_get(L, 1) + xcomplexlib_get(L, 2));
    }

    static int xcomplexlib_sub(lua_State *L)
    {
        return xcomplexlib_push(L, xcomplexlib_get(L, 1) - xcomplexlib_get(L, 2));
    }

    static int xcomplexlib_neg(lua_State *L)
    {
        return xcomplexlib_push(L, - xcomplexlib_get(L, 1));
    }

    static int xcomplexlib_div(lua_State *L)
    {
        return xcomplexlib_push(L, xcomplexlib_get(L, 1) / xcomplexlib_get(L, 2));
    }

    static int xcomplexlib_mul(lua_State *L)
    {
        return xcomplexlib_push(L, xcomplexlib_get(L, 1) * xcomplexlib_get(L, 2));
    }

# endif

static int xcomplexlib_abs(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) cabs(xcomplexlib_get(L, 1)));
    return 1;
}

static int xcomplexlib_acos(lua_State *L)
{
    return xcomplexlib_push(L, cacos(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_acosh(lua_State *L)
{
    return xcomplexlib_push(L, cacosh(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_arg(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) carg(xcomplexlib_get(L, 1)));
    return 1;
}

static int xcomplexlib_asin(lua_State *L)
{
    return xcomplexlib_push(L, casin(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_asinh(lua_State *L)
{
    return xcomplexlib_push(L, casinh(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_atan(lua_State *L)
{
    return xcomplexlib_push(L, catan(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_atanh(lua_State *L)
{
    return xcomplexlib_push(L, catanh(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_cos(lua_State *L)
{
    return xcomplexlib_push(L, ccos(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_cosh(lua_State *L)
{
    return xcomplexlib_push(L, ccosh(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_exp(lua_State *L)
{
    xcomplexlib_push(L, cexp(xcomplexlib_get(L, 1)));
    return 1;
}

static int xcomplexlib_imag(lua_State *L) {
    lua_pushnumber(L, (lua_Number) (cimag)(xcomplexlib_get(L, 1)));
    return 1;
}

static int xcomplexlib_log(lua_State *L)
{
    return xcomplexlib_push(L, clog(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_pow(lua_State *L)
{
    return xcomplexlib_push(L, cpow(xcomplexlib_get(L, 1), xcomplexlib_get(L, 2)));
}

static int xcomplexlib_proj(lua_State *L)
{
    return xcomplexlib_push(L, cproj(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_real(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) creal(xcomplexlib_get(L, 1)));
    return 1;
}

static int xcomplexlib_sin(lua_State *L)
{
    return xcomplexlib_push(L, csin(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_sinh(lua_State *L)
{
    return xcomplexlib_push(L, csinh(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_sqrt(lua_State *L)
{
    return xcomplexlib_push(L, csqrt(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_tan(lua_State *L)
{
    return xcomplexlib_push(L, ctan(xcomplexlib_get(L, 1)));
}

static int xcomplexlib_tanh(lua_State *L)
{
    return xcomplexlib_push(L, ctanh(xcomplexlib_get(L, 1)));
}

/*tex A few convenience functions: */

static int xcomplexlib_tostring(lua_State *L)
{
    Complex z = xcomplexlib_get(L, 1);
    lua_Number x = creal(z);
    lua_Number y = cimag(z);
    lua_settop(L, 0);
    if (x != 0.0 || y == 0.0) {
        lua_pushnumber(L, x);
    }
    if (y != 0.0) {
        if (y == 1.0) {
            if (x != 0.0) {
                lua_pushliteral(L, "+");
            }
        } else if (y == -1.0) {
            lua_pushliteral(L, "-");
        } else {
            if (y > 0.0 && x != 0.0) {
                lua_pushliteral(L, "+");
            }
            lua_pushnumber(L, y);
        }
        lua_pushliteral(L, "i");
    }
    lua_concat(L, lua_gettop(L));
    return 1;
}

static int xcomplexlib_topair(lua_State *L)
{
    Complex z = xcomplexlib_get(L, 1);
    lua_pushnumber(L, (lua_Number) creal(z));
    lua_pushnumber(L, (lua_Number) cimag(z));
    return 2;
}

static int xcomplexlib_totable(lua_State *L)
{
    Complex z = xcomplexlib_get(L, 1);
    lua_createtable(L, 2, 0);
    lua_pushnumber(L, (lua_Number) creal(z));
    lua_pushnumber(L, (lua_Number) cimag(z));
    lua_rawseti(L, -3, 1);
    lua_rawseti(L, -3, 2);
    return 1;
}

/*tex Now we assemble the library: */

static const struct luaL_Reg xcomplexlib_function_list[] = {
    /* management */
    { "new",        xcomplexlib_new        },
    { "tostring",   xcomplexlib_tostring   },
    { "topair",     xcomplexlib_topair     },
    { "totable",    xcomplexlib_totable    },
    { "i",          xcomplexlib_inew       },
    /* operators */
    { "__add",      xcomplexlib_add        },
    { "__div",      xcomplexlib_div        },
    { "__eq",       xcomplexlib_eq         },
    { "__mul",      xcomplexlib_mul        },
    { "__sub",      xcomplexlib_sub        },
    { "__unm",      xcomplexlib_neg        },
    { "__pow",      xcomplexlib_pow        },
    /* functions */
    { "abs",        xcomplexlib_abs        },
    { "acos",       xcomplexlib_acos       },
    { "acosh",      xcomplexlib_acosh      },
    { "arg",        xcomplexlib_arg        },
    { "asin",       xcomplexlib_asin       },
    { "asinh",      xcomplexlib_asinh      },
    { "atan",       xcomplexlib_atan       },
    { "atanh",      xcomplexlib_atanh      },
    { "conj",       xcomplexlib_neg        },
    { "cos",        xcomplexlib_cos        },
    { "cosh",       xcomplexlib_cosh       },
    { "exp",        xcomplexlib_exp        },
    { "imag",       xcomplexlib_imag       },
    { "log",        xcomplexlib_log        },
    { "pow",        xcomplexlib_pow        },
    { "proj",       xcomplexlib_proj       },
    { "real",       xcomplexlib_real       },
    { "sin",        xcomplexlib_sin        },
    { "sinh",       xcomplexlib_sinh       },
    { "sqrt",       xcomplexlib_sqrt       },
    { "tan",        xcomplexlib_tan        },
    { "tanh",       xcomplexlib_tanh       },
    /* */
    { NULL,         NULL                   },
};

int luaopen_xcomplex(lua_State *L)
{
    luaL_newmetatable(L, COMPLEX_METATABLE);
    luaL_setfuncs(L, xcomplexlib_function_list, 0);
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushliteral(L, "tostring");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "I");
    lua_pushliteral(L, "i");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "__name"); /* kind of redundant */
    lua_pushliteral(L, "complex");
    lua_settable(L, -3);
    return 1;
}
