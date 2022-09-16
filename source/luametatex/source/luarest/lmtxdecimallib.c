/*
    See license.txt in the root of this project.
*/

/*
    decNumberCompare(decNumber *, const decNumber *, const decNumber *, decContext *);

    decNumberRemainder(decNumber *, const decNumber *, const decNumber *, decContext *);
    decNumberRemainderNear(decNumber *, const decNumber *, const decNumber *, decContext *);

    # define decNumberIsCanonical(dn)
    # define decNumberIsFinite(dn)
    # define decNumberIsInfinite(dn)
    # define decNumberIsNaN(dn)
    # define decNumberIsNegative(dn)
    # define decNumberIsQNaN(dn)
    # define decNumberIsSNaN(dn)
    # define decNumberIsSpecial(dn)
    # define decNumberIsZero(dn)
    # define decNumberRadix(dn)

    The main reason why we have this module is that we already load the library in \METAPOST\
    so it was a trivial extension to make. Because it is likely that we keep decimal support
    there, it is also quite likely that we keep this module, even if it's rarely used. The binary
    number system used in \METAPOST\ is not included. It is even less likely to be used and adds
    much to the binary. Some more functions might be added here so that we become more compatible
    with the other math libraries that are present.

*/

# include <luametatex.h>

# include <decContext.h>
# include <decNumber.h>

# define DECIMAL_METATABLE "decimal number"

typedef decNumber *decimal;

static decContext context;

# define min_precision      25
# define default_precision  50
# define max_precision    2500

static void xdecimallib_initialize(void)
{
    decContextDefault(&context, DEC_INIT_BASE);
    context.traps = 0;
    context.emax = 999999;
    context.emin = -999999;
    context.digits = default_precision;
}

/*tex
    Todo: Use metatable at the top. But we're not going to crunch numbers anyway so for now there
    is no need for it. Anyway, the overhade of calculations is much larger than that of locating
    a metatable.
*/

inline static decimal xdecimallib_push(lua_State *L)
{
    decimal p = lua_newuserdatauv(L, sizeof(decNumber), 0);
    luaL_setmetatable(L, DECIMAL_METATABLE);
    return p;
}

static void decNumberFromDouble(decNumber *A, double B, decContext *C) /* from mplib, extra arg */
{
    char buf[1000];
    char *c;
    snprintf(buf, 1000, "%-650.325lf", B);
    c = buf;
    while (*c++) {
        if (*c == ' ') {
            *c = '\0';
            break;
        }
    }
    decNumberFromString(A, buf, C);
}

inline static int xdecimallib_new(lua_State *L)
{
    decimal p = xdecimallib_push(L);
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            decNumberFromString(p, lua_tostring(L, 1), &context);
            break;
        case LUA_TNUMBER:
            if (lua_isinteger(L, 1)) {
                decNumberFromInt32(p, (int32_t) lua_tointeger(L, 1));
            } else {
                decNumberFromDouble(p, lua_tonumber(L, 1), &context);
            }
            break;
        default:
            decNumberZero(p);
            break;
    }
    return 1;
}

/*
    This is nicer for the user. Beware, we create a userdata object on the stack so we need to
    replace the original non userdata.
*/

static decimal xdecimallib_get(lua_State *L, int i)
{
    switch (lua_type(L, i)) {
        case LUA_TUSERDATA:
            return (decimal) luaL_checkudata(L, i, DECIMAL_METATABLE);
        case LUA_TSTRING:
            {
                decimal p = xdecimallib_push(L);
                decNumberFromString(p, lua_tostring(L, i), &context);
                lua_replace(L, i);
                return p;
            }
        case LUA_TNUMBER:
            {
                decimal p = xdecimallib_push(L);
                if (lua_isinteger(L, i)) {
                    decNumberFromInt32(p, (int32_t) lua_tointeger(L, i));
                } else {
                    decNumberFromDouble(p, lua_tonumber(L, i), &context);
                }
                lua_replace(L, i);
                return p;
            }
        default:
            {
                decimal p = xdecimallib_push(L);
                decNumberZero(p);
                lua_replace(L, i);
                return p;
            }
    }
}

static int xdecimallib_tostring(lua_State *L)
{
    decimal a = xdecimallib_get(L, 1);
    luaL_Buffer buffer;
    char *b = luaL_buffinitsize(L, &buffer, (size_t) a->digits + 14);
    decNumberToString(a, b);
    luaL_addsize(&buffer, strlen(b));
    luaL_pushresult(&buffer);
    return 1;
}

static int xdecimallib_toengstring(lua_State *L)
{
    decimal a = xdecimallib_get(L, 1);
    luaL_Buffer buffer;
    char *b = luaL_buffinitsize(L, &buffer, (size_t) a->digits + 14);
    decNumberToEngString(a, b);
    luaL_addsize(&buffer, strlen(b));
    luaL_pushresult(&buffer);
    return 1;
}

static int xdecimallib_tonumber(lua_State *L)
{
    decimal a = xdecimallib_get(L, 1);
    char *buffer = lmt_memory_malloc((size_t) a->digits + 14); /* could be shared */
    if (buffer) {
        double result = 0.0;
        decNumberToString(a, buffer);
        if (sscanf(buffer, "%lf", &result)) {
            lua_pushnumber(L, result);
        } else {
            lua_pushnil(L);
        }
        lmt_memory_free(buffer);
        return 1;
    } else {
        return 0;
    }
}

static int xdecimallib_copy(lua_State *L)
{
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberCopy(p, a);
    return 1;
}

static int xdecimallib_eq(lua_State *L)
{
    decNumber result;
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decNumberCompare(&result, a, b, &context);
    lua_pushboolean(L, decNumberIsZero(&result));
    return 1;
}

static int xdecimallib_le(lua_State *L)
{
    decNumber result;
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2); /* todo: also number or string */
    decNumberCompare(&result, a, b, &context);
    lua_pushboolean(L, decNumberIsNegative(&result) || decNumberIsZero(&result));
    return 1;
}

static int xdecimallib_lt(lua_State *L)
{
    decNumber result;
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2); /* todo: also number or string */
    decNumberCompare(&result, a, b, &context);
    lua_pushboolean(L, decNumberIsNegative(&result));
    return 1;
}

static int xdecimallib_add(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberAdd(p, a, b, &context);
    return 1;
}

static int xdecimallib_sub(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberSubtract(p, a, b, &context);
    return 1;
}

static int xdecimallib_mul(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberMultiply(p, a, b, &context);
    return 1;
}

static int xdecimallib_div(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberDivide(p, a, b, &context);
    return 1;
}

static int xdecimallib_idiv(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberDivideInteger(p, a, b, &context);
    return 1;
}

static int xdecimallib_mod(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberRemainder(p, a, b, &context);
    return 1;
}

static int xdecimallib_neg(lua_State* L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberCopyNegate(p, a);
    return 1;
}

static int xdecimallib_min(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberMin(p, a, b, &context);
    return 1;
}

static int xdecimallib_max(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberMax(p, a, b, &context);
    return 1;
}

static int xdecimallib_minus(lua_State* L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberNextMinus(p, a, &context);
    return 1;
}

static int xdecimallib_plus(lua_State* L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberNextPlus(p, a, &context);
    return 1;
}

static int xdecimallib_trim(lua_State* L) {
    decimal a = xdecimallib_get(L, 1);
    decNumberTrim(a);
    return 0;
}

static int xdecimallib_pow(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberPower(p, a, b, &context);
    return 1;
}

static int xdecimallib_abs(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberCopyAbs(p, a);
    return 1;
}

static int xdecimallib_sqrt(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberSquareRoot(p, a, &context);
    return 1;
}

static int xdecimallib_ln(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberLn(p, a, &context);
    return 1;
}

static int xdecimallib_log10(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberLog10(p, a, &context);
    return 1;
}

static int xdecimallib_exp(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal p = xdecimallib_push(L);
    decNumberExp(p, a, &context);
    return 1;
}

static int xdecimallib_rotate(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberRotate(p, a, b, &context);
    return 1;
}

static int xdecimallib_shift(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberShift(p, a, b, &context);
    return 1;
}

static int xdecimallib_left(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    lua_Integer shift = luaL_optinteger(L, 2, 1);
    decimal p = xdecimallib_push(L);
    decNumber s;
    decNumberFromInt32(&s, (int32_t) shift);
    decNumberShift(p, a, &s, &context);
    return 1;
}

static int xdecimallib_right(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    lua_Integer shift = - luaL_optinteger(L, 2, 1);
    decimal p = xdecimallib_push(L);
    decNumber s;
    decNumberFromInt32(&s, (int32_t) shift);
    decNumberShift(p, a, &s, &context);
    return 1;
}

static int xdecimallib_and(lua_State *L) {
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberAnd(p, a, b, &context);
    return 1;
}

static int xdecimallib_or(lua_State *L)
{
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberOr(p, a, b, &context);
    return 1;
}

static int xdecimallib_xor(lua_State *L)
{
    decimal a = xdecimallib_get(L, 1);
    decimal b = xdecimallib_get(L, 2);
    decimal p = xdecimallib_push(L);
    decNumberXor(p, a, b, &context);
    return 1;
}

static int xdecimallib_setp(lua_State *L)
{
    int i = (int) luaL_optinteger(L, 1, default_precision);
    if (i < min_precision) {
        context.digits = min_precision;
    } else if (i > max_precision) {
        context.digits = max_precision;
    } else {
        context.digits = i;
    }
    lua_pushinteger(L, context.digits);
    return 1;
}

static int xdecimallib_getp(lua_State *L)
{
    lua_pushinteger(L, context.digits);
    return 1;
}

static const luaL_Reg xdecimallib_function_list[] =
{
    /* management */
    { "new",          xdecimallib_new         },
    { "copy",         xdecimallib_copy        },
    { "trim",         xdecimallib_trim        },
    { "tostring",     xdecimallib_tostring    },
    { "toengstring",  xdecimallib_toengstring },
    { "tonumber",     xdecimallib_tonumber    },
    { "setprecision", xdecimallib_setp        },
    { "getprecision", xdecimallib_getp        },
    /* operators */
    { "__add",        xdecimallib_add         },
    { "__idiv",       xdecimallib_idiv        },
    { "__div",        xdecimallib_div         },
    { "__mod",        xdecimallib_mod         },
    { "__eq",         xdecimallib_eq          },
    { "__le",         xdecimallib_le          },
    { "__lt",         xdecimallib_lt          },
    { "__mul",        xdecimallib_mul         },
    { "__sub",        xdecimallib_sub         },
    { "__unm",        xdecimallib_neg         },
    { "__pow",        xdecimallib_pow         },
    { "__bor",        xdecimallib_or          },
    { "__bxor",       xdecimallib_xor         },
    { "__band",       xdecimallib_and         },
    { "__shl",        xdecimallib_left        },
    { "__shr",        xdecimallib_right       },
    /* functions */
    { "conj",         xdecimallib_neg         },
    { "abs",          xdecimallib_abs         },
    { "pow",          xdecimallib_pow         },
    { "sqrt",         xdecimallib_sqrt        },
    { "ln",           xdecimallib_ln          },
    { "log",          xdecimallib_log10       },
    { "exp",          xdecimallib_exp         },
    { "bor",          xdecimallib_or          },
    { "bxor",         xdecimallib_xor         },
    { "band",         xdecimallib_and         },
    { "shift",        xdecimallib_shift       },
    { "rotate",       xdecimallib_rotate      },
    { "minus",        xdecimallib_minus       },
    { "plus",         xdecimallib_plus        },
    { "min",          xdecimallib_min         },
    { "max",          xdecimallib_max         },
    /* */
    { NULL,           NULL                    },
};

int luaopen_xdecimal(lua_State *L)
{
    xdecimallib_initialize();

    luaL_newmetatable(L, DECIMAL_METATABLE);
    luaL_setfuncs(L, xdecimallib_function_list, 0);
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushliteral(L, "tostring");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "__name");
    lua_pushliteral(L, "decimal");
    lua_settable(L, -3);
    return 1;
}
