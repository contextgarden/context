/*
    See license.txt in the root of this project.
*/

/*tex 
    This is an experiment using the posit (unum) implementation from https://gitlab.com/cerlane/SoftPosit#known, which is 
    afaiks the standard. At some point it migh tbe interesting to have this as MetaPost number plugin too, but first I need 
    to figure out some helpers (sin, cos, pow etc). 

    Watch out: this is just a playground for me and a few others. There are \CONTEXT\ interfaces but these are also quite 
    experimental. For instance we might move to 64 bit posits. And how about quires.  It all depends on developments in 
    this area. 

    The standard is at: 

        https://posithub.org/docs/posit_standard-2.pdf

    The reference code can be found here:

        https://gitlab.com/cerlane/SoftPosit

    However, the implementation lags behind the standard: no posit64 and no functions except from a few that add, subtract, 
    multiply, divide etc. But I will keep an eye in it.  

    Todo: check if we used the right functions (also in auxposit).

*/

# include <luametatex.h>

# define POSIT_METATABLE "posit number"
 
inline static posit_t *positlib_push(lua_State *L)
{
    posit p = lua_newuserdatauv(L, sizeof(posit_t), 0);
    luaL_setmetatable(L, POSIT_METATABLE);
    return p;
}

inline static int positlib_new(lua_State *L)
{
    posit p = positlib_push(L);
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            *p = double_to_posit(lua_tonumber(L, 1));
            break;
        case LUA_TNUMBER:
            if (lua_isinteger(L, 1)) {
                *p = i64_to_posit(lua_tointeger(L, 1));
            } else {
                *p = double_to_posit(lua_tonumber(L, 1));
            }
            break;
        default:
            p->v = 0;
            break;
    }
    return 1;
}

inline static int positlib_toposit(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TNUMBER) {
        posit_t p = double_to_posit(lua_tonumber(L, 1));
        lua_pushinteger(L, p.v);
    } else {
        lua_pushinteger(L, 0);
    }
    return 1;
}

inline static int positlib_fromposit(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TNUMBER) {
        posit_t p = { .v = lmt_roundnumber(L, 1) };
        lua_pushnumber(L, posit_to_double(p));
    } else {
        lua_pushinteger(L, 0);
    }
    return 1;
}

/*
    This is nicer for the user. Beware, we create a userdata object on the stack so we need to
    replace the original non userdata.
*/

static posit_t *positlib_get(lua_State *L, int i)
{
    switch (lua_type(L, i)) {
        case LUA_TUSERDATA:
            return (posit) luaL_checkudata(L, i, POSIT_METATABLE);
        case LUA_TSTRING:
            {
                posit p = positlib_push(L);
                *p = double_to_posit(lua_tonumber(L, i));
                lua_replace(L, i);
                return p;
            }
        case LUA_TNUMBER:
            {
                posit p = positlib_push(L);
                if (lua_isinteger(L, i)) {
                    *p = i64_to_posit(lua_tointeger(L, 1));
                } else {
                    *p = double_to_posit(lua_tonumber(L, i));
                }
                lua_replace(L, i);
                return p;
            }
        default:
            {
                posit p = positlib_push(L);
                lua_replace(L, i);
                return p;
            }
    }
}

static int positlib_tostring(lua_State *L)
{
    posit p = positlib_get(L, 1);
    double d = posit_to_double(*p);
    lua_pushnumber(L, d);
    lua_tostring(L, -1);
    return 1;
}


static int positlib_tonumber(lua_State *L)
{
    posit p = positlib_get(L, 1);
    double d = posit_to_double(*p);
    lua_pushnumber(L, d);
    return 1;
}

static int positlib_copy(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p  = *a;
    return 1;
}

static int positlib_eq(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    lua_pushboolean(L, posit_eq(*a, *b));
    return 1;
}

static int positlib_le(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    lua_pushboolean(L, posit_le(*a, *b));
    return 1;
}

static int positlib_lt(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    lua_pushboolean(L, posit_lt(*a, *b));
    return 1;
}

static int positlib_add(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    *p = posit_add(*a, *b);
    return 1;
}

static int positlib_sub(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    *p = posit_sub(*a, *b);
    return 1;
}

static int positlib_mul(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    *p = posit_mul(*a, *b);
    return 1;
}

static int positlib_div(lua_State *L) {
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    *p = posit_div(*a, *b);
    return 1;
}

static int positlib_round(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = posit_round_to_integer(*a);
    return 1;
}

static int positlib_rounded(lua_State *L) 
{ 
    posit a = positlib_get(L, 1);
    lua_pushinteger(L, posit_to_integer(*a));
    return 1;
}

static int positlib_integer(lua_State *L) 
{
    posit p = positlib_get(L, 1);
    lua_pushinteger(L, (lua_Integer) posit_to_i64(*p));
    return 1;
}

static int positlib_NaN(lua_State *L) 
{
    posit p = positlib_get(L, 1);
    lua_pushboolean(L, p->v == (uint32_t) 0x80000000);
    return 1;
}

static int positlib_NaR(lua_State *L) 
{
    posit p = positlib_get(L, 1);
    lua_pushboolean(L, posit_is_NaR(p->v));
    return 1;
}

// static int positlib_idiv(lua_State *L) {
//     return 0;
// }

// static int positlib_mod(lua_State *L) {
//     return 0;
// }

static int positlib_neg(lua_State* L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = posit_neg(*a); 
    return 1;
}

static int positlib_min(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    *p = posit_lt(*a, *b) ? *a : *b; 
    return 1;
}

static int positlib_max(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    *p = posit_lt(*a, *b) ? *b : *a; 
    return 1;
}

static int positlib_pow(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(pow(posit_to_double(*a),posit_to_double(*b)));
    return 1;
}
 
static int positlib_abs(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = posit_abs(*a);
    return 1;
}

static int positlib_sqrt(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = posit_sqrt(*a);
    return 1;
}
 
// static int positlib_ln(lua_State *L) 
// {
//     posit a = positlib_get(L, 1);
//     posit p = positlib_push(L);
//     *p = double_to_posit(ln(posit_to_double(*a)));
//     return 1;
// }
 
static int positlib_log10(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(log10(posit_to_double(*a)));
    return 1;
}

static int positlib_log1p(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(log1p(posit_to_double(*a)));
    return 1;
}

static int positlib_log2(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(log2(posit_to_double(*a)));
    return 1;
}

static int positlib_logb(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(logb(posit_to_double(*a)));
    return 1;
}

static int positlib_log(lua_State *L)
{
    if (lua_gettop(L) == 1) {
        posit a = positlib_get(L, 1);
        posit p = positlib_push(L);
        *p = double_to_posit(log(posit_to_double(*a)));
    } else {
        posit a = positlib_get(L, 1);
        posit b = positlib_get(L, 2);
        posit p = positlib_push(L);
        double d = posit_to_double(*a);
        double n = posit_to_double(*b);
        if (n == 10.0) {
            n = (lua_Number) log10(d);
        } else if (n == 2.0) {
            n = (lua_Number) log2(d);
        } else {
            n = (lua_Number) log(d) / (lua_Number) log(n);
        }
        *p = double_to_posit(n);
    }
    return 1;
}

static int positlib_exp(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(exp(posit_to_double(*a)));
    return 1;
}

static int positlib_exp2(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(exp2(posit_to_double(*a)));
    return 1;
}

static int positlib_ceil(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(ceil(posit_to_double(*a)));
    return 1;
}

static int positlib_floor(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(floor(posit_to_double(*a)));
    return 1;
}

static int positlib_modf(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    posit q = positlib_push(L);
    double d; 
    *q = double_to_posit(modf(posit_to_double(*a),&d));
    *p = double_to_posit(d);
    return 2;
}

static int positlib_sin(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(sin(posit_to_double(*a)));
    return 1;
}

static int positlib_cos(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(cos(posit_to_double(*a)));
    return 1;
}

static int positlib_tan(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(tan(posit_to_double(*a)));
    return 1;
}

static int positlib_asin(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(asin(posit_to_double(*a)));
    return 1;
}

static int positlib_acos(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(acos(posit_to_double(*a)));
    return 1;
}

static int positlib_atan(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit p = positlib_push(L);
    *p = double_to_posit(atan(posit_to_double(*a)));
    return 1;
}

static int positlib_rotate(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    lua_Integer n = luaL_optinteger(L, 2, 1);
    posit p = positlib_push(L);
    if (n > 0) { 
        p->v = (a->v >> n) | (a->v << (posit_bits - n));
    } else if (n < 0) {
        p->v = (a->v << n) | (a->v >> (posit_bits - n));
    } else {
        p->v = a->v; 
    }
    return 1;
}

static int positlib_shift(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    lua_Integer shift = luaL_optinteger(L, 2, 1);
    posit p = positlib_push(L);
    if (shift > 0) { 
        p->v = (a->v >> shift) & 0xFFFFFFFF;
    } else if (shift < 0) { 
        p->v = (a->v << -shift) & 0xFFFFFFFF;
    } else { 
        p->v = a->v; 
    }
    return 1;
}
 
static int positlib_left(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    lua_Integer shift = luaL_optinteger(L, 2, 1);
    posit p = positlib_push(L);
    p->v = (a->v << shift) & 0xFFFFFFFF;
    return 1;
}

static int positlib_right(lua_State *L) 
{
    posit_t *a = positlib_get(L, 1);
    lua_Integer shift = - luaL_optinteger(L, 2, 1);
    posit_t *p = positlib_push(L);
    p->v = (a->v >> shift) & 0xFFFFFFFF;
    return 1;
}
 
static int positlib_and(lua_State *L) 
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    p->v = (a->v) & (b->v); 
    return 1;
}

static int positlib_or(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    p->v = (a->v) | (b->v); 
    return 1;
}

static int positlib_xor(lua_State *L)
{
    posit a = positlib_get(L, 1);
    posit b = positlib_get(L, 2);
    posit p = positlib_push(L);
    p->v = (a->v) ^ (b->v); 
    return 1;
}
 
static const luaL_Reg positlib_function_list[] =
{
    /* management */
    { "new",          positlib_new       },
    { "copy",         positlib_copy      },
    { "tostring",     positlib_tostring  },
    { "tonumber",     positlib_tonumber  },
    { "integer",      positlib_integer   },
    { "rounded",      positlib_rounded   },
    { "toposit",      positlib_toposit   },
    { "fromposit",    positlib_fromposit },
    /* operators */                      
    { "__add",        positlib_add       },
 // { "__idiv",       positlib_idiv      },
    { "__div",        positlib_div       },
 // { "__mod",        positlib_mod       },
    { "__eq",         positlib_eq        },
    { "__le",         positlib_le        },
    { "__lt",         positlib_lt        },
    { "__mul",        positlib_mul       },
    { "__sub",        positlib_sub       },
    { "__unm",        positlib_neg       },
    { "__pow",        positlib_pow       },
    { "__bor",        positlib_or        },
    { "__bxor",       positlib_xor       },
    { "__band",       positlib_and       },
    { "__shl",        positlib_left      },
    { "__shr",        positlib_right     },
    /* */                                
    { "NaN",          positlib_NaN       },
    { "NaN",          positlib_NaR       },
    /* */                                
    { "bor",          positlib_or        },
    { "bxor",         positlib_xor       },
    { "band",         positlib_and       },
    { "shift",        positlib_shift     },
    { "rotate",       positlib_rotate    },
    /* */                                
    { "min",          positlib_min       },
    { "max",          positlib_max       },
    { "abs",          positlib_abs       },
    { "conj",         positlib_neg       },
    { "modf",         positlib_modf      },
    /* */
    { "acos",         positlib_acos      },
 // { "acosh",        positlib_acosh     },
    { "asin",         positlib_asin      },
 // { "asinh",        positlib_asinh     },
    { "atan",         positlib_atan      },
 // { "atan2",        positlib_atan2     },
 // { "atanh",        positlib_atanh     },
 // { "cbrt",         positlib_cbrt      },
    { "ceil",         positlib_ceil      },
 // { "copysign",     positlib_copysign  },
    { "cos",          positlib_cos       },
 // { "cosh",         positlib_cosh      },
 // { "deg",          positlib_deg       },
 // { "erf",          positlib_erf       },
 // { "erfc",         positlib_erfc      },
    { "exp",          positlib_exp       },
    { "exp2",         positlib_exp2      },
 // { "expm1",        positlib_expm1     },
 // { "fabs",         positlib_fabs      },
 // { "fdim",         positlib_fdim      },
    { "floor",        positlib_floor     },
 // { "fma",          positlib_fma       },
 // { "fmax",         positlib_fmax      },
 // { "fmin",         positlib_fmin      },
 // { "fmod",         positlib_fmod      },
 // { "frexp",        positlib_frexp     },
 // { "gamma",        positlib_gamma     },
 // { "hypot",        positlib_hypot     },
 // { "isfinite",     positlib_isfinite  },
 // { "isinf",        positlib_isinf     },
 // { "isnan",        positlib_isnan     },
 // { "isnormal",     positlib_isnormal  },
 // { "j0",           positlib_j0        },
 // { "j1",           positlib_j1        },
 // { "jn",           positlib_jn        },
 // { "ldexp",        positlib_ldexp     },
 // { "lgamma",       positlib_lgamma    },
    { "log",          positlib_log       },
    { "log10",        positlib_log10     },
    { "log1p",        positlib_log1p     },
    { "log2",         positlib_log2      },
    { "logb",         positlib_logb      },
 // { "modf",         positlib_modf      },
 // { "nearbyint",    positlib_nearbyint },
 // { "nextafter",    positlib_nextafter },
    { "pow",          positlib_pow       },
 // { "rad",          positlib_rad       },
 // { "remainder",    positlib_remainder },
 // { "remquo",       positlib_fremquo   },
    { "round",        positlib_round     },
 // { "scalbn",       positlib_scalbn    },
    { "sin",          positlib_sin       },
 // { "sinh",         positlib_sinh      },
    { "sqrt",         positlib_sqrt      },
    { "tan",          positlib_tan       },
 // { "tanh",         positlib_tanh      },
 // { "tgamma",       positlib_tgamma    },
 // { "trunc",        positlib_trunc     },
 // { "y0",           positlib_y0        },
 // { "y1",           positlib_y1        },
 // { "yn",           positlib_yn        },
    /* */
    { NULL,           NULL               },
};

int luaopen_posit(lua_State *L)
{
    luaL_newmetatable(L, POSIT_METATABLE);
    luaL_setfuncs(L, positlib_function_list, 0);
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushliteral(L, "tostring");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "__name");
    lua_pushliteral(L, "posit");
    lua_settable(L, -3);
    return 1;
}
