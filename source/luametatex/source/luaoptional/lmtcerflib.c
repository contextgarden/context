/*

    See license.txt in the root of this project.

    In order to match the xmath library we also support complex error functions. For that we use
    the libcerf funcitonality. That library itself is a follow up on other code (you can find
    articles on the web).

    One complication is that the library (at the time we started using it) is not suitable for the
    MSVC compiler so we use adapted code, so yet another succession. We currently embed libcerf but
    when we have the optional library compilation up and running on the garden that might become a
    real optional module instead.

    Note: Alan has to test if all works okay.

*/

# include "lmtoptional.h"
# include "luametatex.h"

# include <complex.h>
# include <cerf.h>

/*tex We start with some similar code as in |xcomplex.c|. */

# define COMPLEX_METATABLE "complex number"

# if (_MSC_VER)

    # define Complex _Dcomplex

    static Complex lmt_tocomplex(lua_State *L, int i)
    {
        switch (lua_type(L, i)) {
            case LUA_TNUMBER:
            case LUA_TSTRING:
                return _Cbuild(luaL_checknumber(L, i), 0);
            default:
                return *((Complex*)luaL_checkudata(L, i, COMPLEX_METATABLE));
        }
    }

# else

    # define Complex double complex

    static Complex lmt_tocomplex(lua_State *L, int i)
    {
        switch (lua_type(L, i)) {
            case LUA_TNUMBER:
            case LUA_TSTRING:
                return luaL_checknumber(L, i);
            default:
                return *((Complex*)luaL_checkudata(L, i, COMPLEX_METATABLE));
        }
    }

# endif

static int lmt_pushcomplex(lua_State *L, Complex z)
{
    Complex *p = lua_newuserdatauv(L, sizeof(Complex), 0);
    luaL_setmetatable(L, COMPLEX_METATABLE);
    *p = z;
    return 1;
}

/*tex We use that here: */

static int xcomplexlib_cerf_erf (lua_State *L) {
    return lmt_pushcomplex(L, cerf(lmt_tocomplex(L, 1)));
}

static int xcomplexlib_cerf_erfc (lua_State *L) {
    return lmt_pushcomplex(L, lmt_tocomplex(L, 1));
}

static int xcomplexlib_cerf_erfcx (lua_State *L) {
    return lmt_pushcomplex(L, cerfcx(lmt_tocomplex(L, 1)));
}

static int xcomplexlib_cerf_erfi (lua_State *L) {
    return lmt_pushcomplex(L, cerfi(lmt_tocomplex(L, 1)));
}

static int xcomplexlib_cerf_dawson (lua_State *L) {
    return lmt_pushcomplex(L, cdawson(lmt_tocomplex(L, 1)));
}

static int xcomplexlib_cerf_voigt (lua_State *L) {
    lua_pushnumber(L, voigt(lua_tonumber(L, 1), lua_tonumber(L, 2), lua_tonumber(L, 3)));
    return 1;
}

static int xcomplexlib_cerf_voigt_hwhm (lua_State *L) {
    int error = 0;
    double result = voigt_hwhm(lua_tonumber(L, 1), lua_tonumber(L, 2), &error);
    lua_pushnumber(L, result);
    switch (error) {
        case 1 : 
            tex_formatted_warning("voigt_hwhm", "bad arguments");
            break;
        case 2 : 
            tex_formatted_warning("voigt_hwhm", "huge deviation");
            break;
        case 3 : 
            tex_formatted_warning("voigt_hwhm", "no convergence");
            break;
    }
    return 1;
}

static struct luaL_Reg xcomplexlib_cerf_function_list[] = {
    { "erf",        xcomplexlib_cerf_erf        },
    { "erfc",       xcomplexlib_cerf_erfc       },
    { "erfcx",      xcomplexlib_cerf_erfcx      },
    { "erfi",       xcomplexlib_cerf_erfi       },
    { "dawson",     xcomplexlib_cerf_dawson     },
    { "voigt",      xcomplexlib_cerf_voigt      },
    { "voigt_hwhm", xcomplexlib_cerf_voigt_hwhm },
    { NULL,         NULL                        },
};

int luaextend_xcomplex(lua_State *L)
{
    lua_getglobal(L, "string");
    for (const luaL_Reg *lib = xcomplexlib_cerf_function_list; lib->name; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);
    return 1;
}
