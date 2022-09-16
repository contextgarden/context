/*

    See license.txt in the root of this project.

    This is a reformatted and slightly adapted version of lmathx.c:

    title  : C99 math functions for Lua 5.3+
    author : Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
    date   : 24 Jun 2015 09:51:50
    licence: This code is hereby placed in the public domain.

    In the end I just expanded and adapted the code a bit which made it easier to get rid of some
    compiler warnings (if possible at all).

*/

# include "luametatex.h"

# include <math.h>

# define xmathlib_pi  ((lua_Number)(3.141592653589793238462643383279502884))
# define xmathlib_180 ((lua_Number) 180.0)
# define xmathlib_inf ((lua_Number) INFINITY)
# define xmathlib_nan ((lua_Number) NAN)

static int xmathlib_acos(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) acos(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_acosh(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) acosh(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_asin(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) asin(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_asinh(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) asinh(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_atan(lua_State *L)
{
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number) atan(luaL_checknumber(L, 1)));
    } else {
        lua_pushnumber(L, (lua_Number) atan2(luaL_checknumber(L, 1),luaL_checknumber(L, 2)));
    }
    return 1;
}

static int xmathlib_atan2(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) atan2(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_atanh(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) atanh(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_cbrt(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) cbrt(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_ceil(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) ceil(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_copysign (lua_State *L)
{
    lua_pushnumber(L, (lua_Number) copysign(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_cos(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) cos(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_cosh(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) cosh(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_deg(lua_State *L)
{
    lua_pushnumber(L, luaL_checknumber(L, 1) * (xmathlib_180 / xmathlib_pi));
    return 1;
}

static int xmathlib_erf(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) erf(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_erfc(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) erfc(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_exp(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) exp(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_exp2(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) exp2(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_expm1(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) expm1(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_fabs(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) fabs(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_fdim(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) fdim(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_floor(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) floor(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_fma(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) fma(luaL_checknumber(L, 1), luaL_checknumber(L, 2), luaL_checknumber(L, 3)));
    return 1;
}

static int xmathlib_fmax(lua_State *L)
{
    int n = lua_gettop(L);
    lua_Number m = luaL_checknumber(L, 1);
    for (int i = 2; i <= n; i++) {
        m = (lua_Number) fmax(m, luaL_checknumber(L, i));
    }
    lua_pushnumber(L, m);
    return 1;
}

static int xmathlib_fmin(lua_State *L)
{
    int n = lua_gettop(L);
    lua_Number m = luaL_checknumber(L, 1);
    for (int i = 2; i <= n; i++) {
        m = (lua_Number) fmin(m, luaL_checknumber(L, i));
    }
    lua_pushnumber(L, m);
    return 1;
}

static int xmathlib_fmod(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) fmod(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_frexp(lua_State *L)
{
    int e;
    lua_pushnumber(L, (lua_Number) frexp(luaL_checknumber(L, 1), &e));
    lua_pushinteger(L, e);
    return 2;
}
static int xmathlib_fremquo(lua_State *L)
{
    int e;
    lua_pushnumber(L, (lua_Number) remquo(luaL_checknumber(L, 1),luaL_checknumber(L, 2), &e));
    lua_pushinteger(L, e);
    return 2;
}

static int xmathlib_gamma(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) tgamma(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_hypot(lua_State *L)
{
    lua_pushnumber(L, hypot(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_isfinite(lua_State *L)
{
    lua_pushboolean(L, isfinite(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_isinf(lua_State *L)
{
    lua_pushboolean(L, isinf(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_isnan(lua_State *L)
{
    lua_pushboolean(L, isnan(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_isnormal (lua_State *L)
{
    lua_pushboolean(L, isnormal(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_j0(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) j0(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_j1(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) j1(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_jn(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) jn((int) luaL_checkinteger(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_ldexp(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) ldexp(luaL_checknumber(L, 1), (int) luaL_checkinteger(L, 2)));
    return 1;
}

static int xmathlib_lgamma(lua_State *L)
{
    lua_pushnumber (L, (lua_Number) lgamma(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_log(lua_State *L)
{
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number) log(luaL_checknumber(L, 1)));
    } else {
        lua_Number n = luaL_checknumber(L, 2);
        if (n == 10.0) {
            n = (lua_Number) log10(luaL_checknumber(L, 1));
        } else if (n == 2.0) {
            n = (lua_Number) log2(luaL_checknumber(L, 1));
        } else {
            n = (lua_Number) log(luaL_checknumber(L, 1)) / (lua_Number) log(n);
        }
        lua_pushnumber(L, n);
    }
    return 1;
}

static int xmathlib_log10(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) log10(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_log1p(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) log1p(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_log2(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) log2(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_logb(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) logb(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_modf(lua_State *L)
{
    lua_Number ip;
    lua_Number fp = (lua_Number) modf(luaL_checknumber(L, 1), &ip);
    lua_pushnumber(L, ip);
    lua_pushnumber(L, fp);
    return 2;
}

static int xmathlib_nearbyint(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) nearbyint(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_nextafter(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) nextafter(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_pow(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) pow(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_rad(lua_State *L)
{
   lua_pushnumber(L, (luaL_checknumber(L, 1) * (xmathlib_pi / xmathlib_180)));
   return 1;
}

static int xmathlib_remainder(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) remainder(luaL_checknumber(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static int xmathlib_round(lua_State *L)
{
    lua_pushinteger(L, lround(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_scalbn(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) scalbn(luaL_checknumber(L, 1), (int) luaL_checkinteger(L, 2)));
    return 1;
}

static int xmathlib_sin(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) sin(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_sinh(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) sinh(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_sqrt(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) sqrt(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_tan(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) tan(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_tanh(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) tanh(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_tgamma(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) tgamma(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_trunc(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) trunc(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_y0(lua_State *L)
{
    lua_pushnumber(L, (lua_Number) y0(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_y1(lua_State *L)
{
    lua_pushnumber(L, y1(luaL_checknumber(L, 1)));
    return 1;
}

static int xmathlib_yn(lua_State *L)
{
    lua_pushnumber(L, yn((int) luaL_checkinteger(L, 1), luaL_checknumber(L, 2)));
    return 1;
}

static const luaL_Reg xmathlib_function_list[] =
{
    { "acos",      xmathlib_acos      },
    { "acosh",     xmathlib_acosh     },
    { "asin",      xmathlib_asin      },
    { "asinh",     xmathlib_asinh     },
    { "atan",      xmathlib_atan      },
    { "atan2",     xmathlib_atan2     },
    { "atanh",     xmathlib_atanh     },
    { "cbrt",      xmathlib_cbrt      },
    { "ceil",      xmathlib_ceil      },
    { "copysign",  xmathlib_copysign  },
    { "cos",       xmathlib_cos       },
    { "cosh",      xmathlib_cosh      },
    { "deg",       xmathlib_deg       },
    { "erf",       xmathlib_erf       },
    { "erfc",      xmathlib_erfc      },
    { "exp",       xmathlib_exp       },
    { "exp2",      xmathlib_exp2      },
    { "expm1",     xmathlib_expm1     },
    { "fabs",      xmathlib_fabs      },
    { "fdim",      xmathlib_fdim      },
    { "floor",     xmathlib_floor     },
    { "fma",       xmathlib_fma       },
    { "fmax",      xmathlib_fmax      },
    { "fmin",      xmathlib_fmin      },
    { "fmod",      xmathlib_fmod      },
    { "frexp",     xmathlib_frexp     },
    { "gamma",     xmathlib_gamma     },
    { "hypot",     xmathlib_hypot     },
    { "isfinite",  xmathlib_isfinite  },
    { "isinf",     xmathlib_isinf     },
    { "isnan",     xmathlib_isnan     },
    { "isnormal",  xmathlib_isnormal  },
    { "j0",        xmathlib_j0        },
    { "j1",        xmathlib_j1        },
    { "jn",        xmathlib_jn        },
    { "ldexp",     xmathlib_ldexp     },
    { "lgamma",    xmathlib_lgamma    },
    { "log",       xmathlib_log       },
    { "log10",     xmathlib_log10     },
    { "log1p",     xmathlib_log1p     },
    { "log2",      xmathlib_log2      },
    { "logb",      xmathlib_logb      },
    { "modf",      xmathlib_modf      },
    { "nearbyint", xmathlib_nearbyint },
    { "nextafter", xmathlib_nextafter },
    { "pow",       xmathlib_pow       },
    { "rad",       xmathlib_rad       },
    { "remainder", xmathlib_remainder },
    { "remquo",    xmathlib_fremquo   },
    { "round",     xmathlib_round     },
    { "scalbn",    xmathlib_scalbn    },
    { "sin",       xmathlib_sin       },
    { "sinh",      xmathlib_sinh      },
    { "sqrt",      xmathlib_sqrt      },
    { "tan",       xmathlib_tan       },
    { "tanh",      xmathlib_tanh      },
    { "tgamma",    xmathlib_tgamma    },
    { "trunc",     xmathlib_trunc     },
    { "y0",        xmathlib_y0        },
    { "y1",        xmathlib_y1        },
    { "yn",        xmathlib_yn        },
    { NULL,        NULL               },
};

int luaopen_xmath(lua_State *L)
{
    luaL_newlib(L, xmathlib_function_list);
    lua_pushnumber(L, xmathlib_inf);
    lua_setfield(L, -2, "inf");
    lua_pushnumber(L, xmathlib_nan);
    lua_setfield(L, -2, "nan");
    lua_pushnumber(L, xmathlib_pi);
    lua_setfield(L, -2, "pi");
    return 1;
}
