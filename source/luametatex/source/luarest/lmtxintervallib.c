/*

    See license.txt in the root of this project.

*/

# include "luametatex.h"

# include <fi_lib.h>

/*
    This is an experiment with the (pure c) interval library written by Werner Hofschuster and
    Walter Kraemer from Universitaet Karlsruhe, Germany. It is a relative small clean library
    that we adapted a bit for our purpose: reformatted for better understanding, a more formal
    error reporting so that we can hook oru own messaging in, a few fixes, etc. We don't expect
    updates to the original so there is little danger for diverging. We got rid of a few compiler
    warnings in the process.

    If we ever integrate in MP I might also come up with passing pointers but not for now. In
    that perspective we might introduce interval comparison instead as that makes more sense.
    Using an interval math model will conflict with the already "eps(ilon)" being used in the
    MP code base. We anyway still need to find examples of practical usage.

    Some left overs:

        interval eq_ii  (interval y)             : assignment
        interval eq_id  (double y)               : assignment
        int      ig_ii  (interval x, interval y) : x.INF >  y.INF && x.SUP >  y.SUP
        int      ige_ii (interval x, interval y) : x.INF >= y.INF && x.SUP >= y.SUP
        int      dis_ii (interval x, interval y) : x.SUP <  y.INF || y.SUP <  x.INF
        interval j_coth (interval x)             : maybe
        interval j_acth (interval x)             : maybe
        interval j_cot  (interval x)             : maybe

    Maybe:

    xinterval.midpoints(table_of_intervals) -> table of numbers

*/

/*tex See |lmtinterface.h| for |INTERVAL_METATABLE_INSTANCE|. */

static const double epsilon = 0.000001;

static inline interval interval_neg(interval i)
{
    return (interval) { - i.SUP, - i.INF };
}

static inline interval interval_mod(interval a, interval b)
{
    double d;
    interval i = div_ii(a, b);
    i.INF = modf(i.INF, &d);
    i.SUP = modf(i.SUP, &d);
    return mul_ii(i, b);
}

static inline int interval_equal(interval a, interval b, double eps)
{
    double ma = 0.5 * (a.INF + a.SUP);
    double mb = 0.5 * (b.INF + b.SUP);
    return fabs(ma - mb) <= eps;
}

static inline int interval_less(interval a, interval b, double eps)
{
    double ma = 0.5 * (a.INF + a.SUP);
    double mb = 0.5 * (b.INF + b.SUP);
    return (ma - eps) < (mb + eps);
}

static inline int interval_greater(interval a, interval b, double eps)
{
    double ma = 0.5 * (a.INF + a.SUP);
    double mb = 0.5 * (b.INF + b.SUP);
    return (ma + eps) > (mb - eps);
}

static inline int interval_lessequal(interval a, interval b, double eps)
{
    double ma = 0.5 * (a.INF + a.SUP);
    double mb = 0.5 * (b.INF + b.SUP);
    return fabs(ma - mb) <= eps || (ma - eps) < (mb + eps);
}

static inline int interval_greaterequal(interval a, interval b, double eps)
{
    double ma = 0.5 * (a.INF + a.SUP);
    double mb = 0.5 * (b.INF + b.SUP);
    return fabs(ma - mb) <= eps || (ma + eps) > (mb - eps);
}

static inline int interval_eq(interval a, interval b)
{
    return a.INF == b.INF && a.SUP == b.SUP;
}
static inline int interval_gt(interval a, interval b)
{
    return a.INF > b.INF && a.SUP > b.SUP;
}
static inline int interval_lt(interval a, interval b)
{
    return a.INF < b.INF && a.SUP < b.SUP;
}
static inline int interval_ge(interval a, interval b)
{
    return (a.INF > b.INF && a.SUP > b.SUP) || (a.INF == b.INF && a.SUP == b.SUP);
}
static inline int interval_le(interval a, interval b)
{
    return (a.INF < b.INF && a.SUP < b.SUP) || (a.INF == b.INF && a.SUP == b.SUP);
}

static inline int interval_seteq(interval a, interval b)
{
    return a.INF <= b.SUP && a.SUP >= b.INF;
}
static inline int interval_setlt(interval a, interval b)
{
    return a.SUP < b.INF;
}
static inline int interval_setgt(interval a, interval b)
{
    return a.INF > b.SUP;
}
static inline int interval_setle(interval a, interval b)
{
    return a.SUP <= b.INF;
}
static inline int interval_setge(interval a, interval b)
{
    return a.INF >= b.SUP;
}

static inline interval xintervallib_get(lua_State *L, int i)
{
    switch (lua_type(L, i)) {
        case LUA_TUSERDATA:
            {
                interval * u = lua_touserdata(L, i);
                if (u && lua_getmetatable(L, i)) {
                    lua_get_metatablelua(interval_instance);
                    if (! lua_rawequal(L, -1, -2)) {
                       u = NULL;
                    }
                    lua_pop(L, 2);
                }
                if (u) {
                    return *u;
                } else {
                    tex_formatted_error("interval lib", "lua <interval> expected, not an object with type %s", luaL_typename(L, i));
                    goto INVALID;
                }
            }
        case LUA_TNUMBER:
        case LUA_TSTRING:
            {
                double d = luaL_checknumber(L, i);
             // return (interval) { d, d };
                return eq_id(d);
            }
        case LUA_TTABLE:
            {
                interval u;
                if (lua_rawgeti(L, i, 1) == LUA_TNUMBER) {
                    u.INF = lua_tonumber(L, -1);
                    if (lua_rawgeti(L, i, 2) == LUA_TNUMBER) {
                        u.SUP = lua_tonumber(L, -1);
                    } else {
                        lua_pop(L, 1);
                        u.SUP = 0;
                    }
                } else {
                    lua_pop(L, 1);
                    u.INF = 0;
                    u.SUP = 0;
                }
                return u;
            }
        default:
          INVALID:
            return (interval) { 0, 0 };
    }
}

static inline int xintervallib_push(lua_State *L, interval z)
{
    interval *p = lua_newuserdatauv(L, sizeof(interval), 0);
    lua_get_metatablelua(interval_instance);
    lua_setmetatable(L, -2);
    *p = z;
    return 1;
}

static int xintervallib_new(lua_State *L)
{
    interval i;
    switch (lua_type(L, 1)) {
        case LUA_TNUMBER:
                i.INF = lua_tonumber(L, 1);
                if (lua_type(L, 2) == LUA_TNUMBER) {
                    i.SUP = lua_tonumber(L, 2);
                } else {
                    i.SUP = i.INF;
                }
            break;
        case LUA_TTABLE:
            if (lua_rawgeti(L, 1, 1) == LUA_TNUMBER) {
                i.INF = lua_tonumber(L, -1);
                if (lua_rawgeti(L, 1, 2) == LUA_TNUMBER) {
                    i.SUP = lua_tonumber(L, -1);
                } else {
                    lua_pop(L, 1);
                    i.SUP = i.INF;
                }
                break;
            } else {
                lua_pop(L, 1);
             // i.INF = 0;
             // i.SUP = 0;
            }
         // break;
        default:
            i.INF = 0;
            i.SUP = 0;
            break;
    }
    xintervallib_push(L, i);
    return 1;
}

static int xintervallib_neweps(lua_State *L)
{
    interval i;
    double d = lua_tonumber(L, 1);
    double e = luaL_optnumber(L, 2, epsilon);
    i.INF = d - e;
    i.SUP = d + e;
    xintervallib_push(L, i);
    return 1;
}

static int xintervallib_eq(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    lua_pushboolean(L, interval_eq(a, b));
 // lua_pushboolean(L, ieq_ii(a, b));
    return 1;
}

static int xintervallib_le(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    lua_pushboolean(L, interval_le(a, b));
 // lua_pushboolean(L, ise_ii(a, b)); /* needs checking */
    return 1;
}

static int xintervallib_lt(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    lua_pushboolean(L, interval_lt(a, b));
 // lua_pushboolean(L, is_ii(a, b)); /* needs checking */
    return 1;
}

static int xintervallib_add(lua_State *L) {
    interval i;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        i = add_di(lua_tonumber(L, 1), xintervallib_get(L, 2));
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        i = add_id(xintervallib_get(L, 1), lua_tonumber(L, 2));
    } else {
        i = add_ii(xintervallib_get(L, 1), xintervallib_get(L, 2));
    }
    return xintervallib_push(L, i);
}

static int xintervallib_sub(lua_State *L) {
    interval i;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        i = sub_di(lua_tonumber(L, 1), xintervallib_get(L, 2));
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        i = sub_id(xintervallib_get(L, 1), lua_tonumber(L, 2));
    } else {
        i = sub_ii(xintervallib_get(L, 1), xintervallib_get(L, 2));
    }
    return xintervallib_push(L, i);
}

static int xintervallib_neg(lua_State *L) {
    interval i = xintervallib_get(L, 1);
    return xintervallib_push(L, (interval) { - i.SUP, -i.INF });
}

static int xintervallib_div(lua_State *L) {
    interval i;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        i = div_di(lua_tonumber(L, 1), xintervallib_get(L, 2));
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        i = div_id(xintervallib_get(L, 1), lua_tonumber(L, 2));
    } else {
        i = div_ii(xintervallib_get(L, 1), xintervallib_get(L, 2));
    }
    return xintervallib_push(L, i);
}

static int xintervallib_mod(lua_State *L) {
    interval i;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        i = interval_mod(eq_id(lua_tonumber(L, 1)), xintervallib_get(L, 2));
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        i = interval_mod(xintervallib_get(L, 1), eq_id(lua_tonumber(L, 2)));
    } else {
        i = interval_mod(xintervallib_get(L, 1), xintervallib_get(L, 2));
    }
    return xintervallib_push(L, i);
}

static int xintervallib_mul(lua_State *L) {
    interval i;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        i = mul_di(lua_tonumber(L, 1), xintervallib_get(L, 2));
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        i = mul_id(xintervallib_get(L, 1), lua_tonumber(L, 2));
    } else {
        i = mul_ii(xintervallib_get(L, 1), xintervallib_get(L, 2));
    }
    return xintervallib_push(L, i);
}

static int xintervallib_abs(lua_State *L)
{
    return xintervallib_push(L, j_abs(xintervallib_get(L, 1)));
}

static int xintervallib_acos(lua_State *L)
{
    return xintervallib_push(L, j_acos(xintervallib_get(L, 1)));
}

static int xintervallib_acosh(lua_State *L)
{
    return xintervallib_push(L, j_acsh(xintervallib_get(L, 1)));
}

static int xintervallib_asin(lua_State *L)
{
    return xintervallib_push(L, j_asin(xintervallib_get(L, 1)));
}

static int xintervallib_asinh(lua_State *L)
{
    return xintervallib_push(L, j_asnh(xintervallib_get(L, 1)));
}

static int xintervallib_atan(lua_State *L)
{
    return xintervallib_push(L, j_atan(xintervallib_get(L, 1)));
}

static int xintervallib_atanh(lua_State *L)
{
    return xintervallib_push(L, j_atnh(xintervallib_get(L, 1)));
}

static int xintervallib_cos(lua_State *L)
{
    return xintervallib_push(L, j_cos(xintervallib_get(L, 1)));
}

static int xintervallib_cosh(lua_State *L)
{
    return xintervallib_push(L, j_cosh(xintervallib_get(L, 1)));
}

static int xintervallib_diameter(lua_State *L)
{
    lua_pushnumber(L, q_diam(xintervallib_get(L, 1)));
    return 1;
}

static int xintervallib_erf(lua_State *L)
{
    return xintervallib_push(L, j_erf(xintervallib_get(L, 1)));
}

static int xintervallib_erfc(lua_State *L)
{
    return xintervallib_push(L, j_erfc(xintervallib_get(L, 1)));
}

static int xintervallib_exp(lua_State *L)
{
    return xintervallib_push(L, j_exp(xintervallib_get(L, 1)));
}

static int xintervallib_expm1(lua_State *L)
{
    return xintervallib_push(L, j_expm(xintervallib_get(L, 1)));
}

static int xintervallib_exp2(lua_State *L)
{
    return xintervallib_push(L, j_exp2(xintervallib_get(L, 1)));
}

static int xintervallib_exp10(lua_State *L)
{
    return xintervallib_push(L, j_ex10(xintervallib_get(L, 1)));
}

static int xintervallib_hull(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    return xintervallib_push(L, hull(a, b));
}

static int xintervallib_intersect(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    return xintervallib_push(L, intsec(a, b));
}

static int xintervallib_equal(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    double eps = luaL_optnumber(L, 3, epsilon);
    lua_pushboolean(L, interval_equal(a, b, eps));
    return 1;
}

static int xintervallib_less(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    double eps = luaL_optnumber(L, 3, epsilon);
    lua_pushboolean(L, interval_less(a, b, eps));
    return 1;
}

static int xintervallib_greater(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    double eps = luaL_optnumber(L, 3, epsilon);
    lua_pushboolean(L, interval_greater(a, b, eps));
    return 1;
}

static int xintervallib_lessequal(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    double eps = luaL_optnumber(L, 3, epsilon);
    lua_pushboolean(L, interval_lessequal(a, b, eps));
    return 1;
}

static int xintervallib_greaterequal(lua_State *L)
{
    interval a = xintervallib_get(L, 1);
    interval b = xintervallib_get(L, 2);
    double eps = luaL_optnumber(L, 3, epsilon);
    lua_pushboolean(L, interval_greaterequal(a, b, eps));
    return 1;
}

static int xintervallib_seteq(lua_State *L)
{
    lua_pushboolean(L, interval_seteq(xintervallib_get(L, 1), xintervallib_get(L, 2)));
    return 1;
}

static int xintervallib_setlt(lua_State *L)

{
    lua_pushboolean(L, interval_setlt(xintervallib_get(L, 1), xintervallib_get(L, 2)));
    return 1;
}

static int xintervallib_setgt(lua_State *L)
{
    lua_pushboolean(L, interval_setgt(xintervallib_get(L, 1), xintervallib_get(L, 2)));
    return 1;
}

static int xintervallib_setle(lua_State *L)
{
    lua_pushboolean(L, interval_setle(xintervallib_get(L, 1), xintervallib_get(L, 2)));
    return 1;
}

static int xintervallib_setge(lua_State *L)
{
    lua_pushboolean(L, interval_setge(xintervallib_get(L, 1), xintervallib_get(L, 2)));
    return 1;
}

static int xintervallib_log1p(lua_State *L)
{
   return xintervallib_push(L, j_lg1p(xintervallib_get(L, 1)));
}

static int xintervallib_log(lua_State *L)
{
   return xintervallib_push(L, j_log(xintervallib_get(L, 1)));
}

static int xintervallib_log2(lua_State *L)
{
   return xintervallib_push(L, j_log2(xintervallib_get(L, 1)));
}

static int xintervallib_log10(lua_State *L)
{
   return xintervallib_push(L, j_lg10(xintervallib_get(L, 1)));
}

static int xintervallib_mid(lua_State *L)
{
   lua_pushnumber(L, q_mid(xintervallib_get(L, 1)));
   return 1;
}

/* x^a = exp(a*log(x)) */

static int xintervallib_pow(lua_State *L)
{
    interval i = xintervallib_get(L, 1);
    interval e = xintervallib_get(L, 2);
    return xintervallib_push(L, j_exp(mul_ii(e, j_log(i))));
}

static int xintervallib_sin(lua_State *L)
{
    return xintervallib_push(L, j_sin(xintervallib_get(L, 1)));
}

static int xintervallib_sinh(lua_State *L)
{
    return xintervallib_push(L, j_sinh(xintervallib_get(L, 1)));
}

static int xintervallib_sqr(lua_State *L)
{
    return xintervallib_push(L, j_sqr(xintervallib_get(L, 1)));
}

static int xintervallib_sqrt(lua_State *L)
{
    return xintervallib_push(L, j_sqrt(xintervallib_get(L, 1)));
}

static int xintervallib_tan(lua_State *L)
{
    return xintervallib_push(L, j_tan(xintervallib_get(L, 1)));
}

static int xintervallib_tanh(lua_State *L)
{
    return xintervallib_push(L, j_tanh(xintervallib_get(L, 1)));
}

static int xintervallib_within(lua_State *L)
{
    int result;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        result = in_di(lua_tonumber(L, 1), xintervallib_get(L, 2));
    } else {
        result = in_ii(xintervallib_get(L, 1), xintervallib_get(L, 2));
    }
    lua_pushboolean(L, result);
    return 1;
}

/*tex A few convenience functions: */

static int xintervallib_tostring(lua_State *L)
{
    interval z = xintervallib_get(L, 1);
    lua_settop(L, 0);
    lua_pushliteral(L, "[");
    lua_pushnumber(L, z.INF);
    lua_pushliteral(L, " .. ");
    lua_pushnumber(L, z.SUP);
    lua_pushliteral(L, "]");
    lua_concat(L, lua_gettop(L));
    return 1;
}

static int xintervallib_asstring(lua_State *L)
{
    interval z = xintervallib_get(L, 1);
    char buffer[128];
    lua_settop(L, 0);
    snprintf(buffer, 128, "[%24.15e .. %24.15e]", z.INF, z.SUP);
    lua_pushstring(L, buffer);
    return 1;
}

static int xintervallib_topair(lua_State *L)
{
    interval z = xintervallib_get(L, 1);
    lua_pushnumber(L, z.INF);
    lua_pushnumber(L, z.SUP);
    return 2;
}

static int xintervallib_totable(lua_State *L)
{
    interval z = xintervallib_get(L, 1);
    lua_createtable(L, 2, 0);
    lua_pushnumber(L, z.INF);
    lua_rawseti(L, -2, 1);
    lua_pushnumber(L, z.SUP);
    lua_rawseti(L, -2, 2);
    return 1;
}

static int xintervallib_usedendian(lua_State *L)
{
    lua_pushinteger(L, q_usedendian());
    return 1;
}

static int xintervallib_usedhandler(int kind, const char *name, double x1, double x2)
{
    lua_State *L = lmt_lua_state.lua_instance;
    switch (kind) {
        case fi_lib_error_nan:
            luaL_error(L, "xinterval %s: %s",         name, "nan"                  ); break;
        case fi_lib_error_overflow_double:
            luaL_error(L, "xinterval %s: %s %f",      name, "overflow",      x1    ); break;
        case fi_lib_error_overflow_interval:
            luaL_error(L, "xinterval %s: %s [%f %f]", name, "overflow",      x1, x2); break;
        case fi_lib_error_invalid_double:
            luaL_error(L, "xinterval %s: %s %f",      name, "invalid",       x1    ); break;
        case fi_lib_error_invalid_interval:
            luaL_error(L, "xinterval %s: %s [%f %f]", name, "invalid",       x1, x2); break;
        case fi_lib_error_zero_division_double:
            luaL_error(L, "xinterval %s: %s %f",      name, "zero division", x1    ); break;
        case fi_lib_error_zero_division_interval:
            luaL_error(L, "xinterval %s: %s [%f %f]", name, "zero division", x1, x2); break;
    }
    return 0;
}

/*tex Now we assemble the library: */

static const struct luaL_Reg xintervallib_function_list[] = {
    /* management */
    { "new",          xintervallib_new          },
    { "neweps",       xintervallib_neweps       },
    { "tostring",     xintervallib_tostring     },
    { "asstring",     xintervallib_asstring     },
    { "topair",       xintervallib_topair       },
    { "totable",      xintervallib_totable      },
    /* operators */
    { "__add",        xintervallib_add          },
    { "__div",        xintervallib_div          },
    { "__eq",         xintervallib_eq           },
    { "__le",         xintervallib_le           },
    { "__lt",         xintervallib_lt           },
    { "__mul",        xintervallib_mul          },
    { "__sub",        xintervallib_sub          },
    { "__unm",        xintervallib_neg          },
    { "__pow",        xintervallib_pow          },
    { "__mod",        xintervallib_mod          },
    /* functions */
    { "abs",          xintervallib_abs          },
    { "acos",         xintervallib_acos         },
    { "acosh",        xintervallib_acosh        },
    { "asin",         xintervallib_asin         },
    { "asinh",        xintervallib_asinh        },
    { "atan",         xintervallib_atan         },
    { "atanh",        xintervallib_atanh        },
 /* { "conj",         xintervallib_neg          }, */
    { "cos",          xintervallib_cos          },
    { "cosh",         xintervallib_cosh         },
    { "diameter",     xintervallib_diameter     },
    { "erf",          xintervallib_erf          },
    { "erfc",         xintervallib_erfc         },
    { "exp",          xintervallib_exp          },
    { "expm1",        xintervallib_expm1        },
    { "exp2",         xintervallib_exp2         },
    { "exp10",        xintervallib_exp10        },
    { "hull",         xintervallib_hull         },
    { "intersect",    xintervallib_intersect    },
    { "log",          xintervallib_log          },
    { "log1p",        xintervallib_log1p        },
    { "log2",         xintervallib_log2         },
    { "log10",        xintervallib_log10        },
    { "mid",          xintervallib_mid          },
    { "mod",          xintervallib_mod          }, /* ! */
    { "pow",          xintervallib_pow          },
    { "sin",          xintervallib_sin          },
    { "sinh",         xintervallib_sinh         },
    { "sqr",          xintervallib_sqr          },
    { "sqrt",         xintervallib_sqrt         },
    { "tan",          xintervallib_tan          },
    { "tanh",         xintervallib_tanh         },
    { "within",       xintervallib_within       },
    /* */
    { "equal",        xintervallib_equal        },
    { "less",         xintervallib_less         },
    { "greater",      xintervallib_greater      },
    { "lessequal",    xintervallib_lessequal    },
    { "greaterequal", xintervallib_greaterequal },
    /* */
    { "seteq",        xintervallib_seteq        },
    { "setlt",        xintervallib_setlt        },
    { "setgt",        xintervallib_setgt        },
    { "setle",        xintervallib_setle        },
    { "setge",        xintervallib_setge        },
    /* */
    { "usedendian",   xintervallib_usedendian   },
    /* */
    { NULL,           NULL                      },
};

int luaopen_xinterval(lua_State *L)
{
    luaL_newmetatable(L, INTERVAL_METATABLE_INSTANCE);
    luaL_setfuncs(L, xintervallib_function_list, 0);
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushliteral(L, "tostring");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "__name");
    lua_pushliteral(L, INTERVAL_METATABLE_INSTANCE);
    lua_settable(L, -3);
    /* */
    q_usehandler(&xintervallib_usedhandler);
    /* */
    return 1;
}
