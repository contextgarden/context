/*

    See license.txt in the root of this project.

    This is a reformatted and slightly adapted version of lmathx.c:

    title  : C99 math functions for Lua 5.3+
    author : Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
    date   : 24 Jun 2015 09:51:50
    licence: This code is hereby placed in the public domain.

*/

# include <math.h>

# include "lua.h"
# include "lauxlib.h"

# define CN(i) luaL_checknumber(L,i)
# define CI(i) ((int)luaL_checkinteger(L,i))

# undef  PI
# define PI (l_mathop(3.141592653589793238462643383279502884))
# define rad(x)	((x)*(PI/l_mathop(180.0)))
# define deg(x)	((x)*(l_mathop(180.0)/PI))

static int Lfmax(lua_State *L)
{
    int i = 2;
    int n = lua_gettop(L);
    lua_Number m = CN(1);
    for (; i<=n; i++) {
        m = l_mathop(fmax)(m,CN(i));
    }
    lua_pushnumber(L,m);
    return 1;
}

static int Lfmin(lua_State *L)
{
    int i = 2;
    int n = lua_gettop(L);
    lua_Number m = CN(1);
    for (; i<=n; i++) {
        m = l_mathop(fmin)(m,CN(i));
    }
    lua_pushnumber(L,m);
    return 1;
}

static int Lfrexp(lua_State *L)
{
    int e;
    lua_pushnumber(L,l_mathop(frexp)(CN(1),&e));
    lua_pushinteger(L,e);
    return 2;
}
static int Lfremquo(lua_State *L)
{
    int e;
    lua_pushnumber(L,l_mathop(remquo)(CN(1),CN(2),&e));
    lua_pushinteger(L,e);
    return 2;
}

static int Lmodf(lua_State *L)
{
    lua_Number ip;
    lua_Number fp = l_mathop(modf)(CN(1),&ip);
    lua_pushnumber(L,ip);
    lua_pushnumber(L,fp);
    return 2;
}

static int Latan(lua_State *L)
{
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L,l_mathop(atan)(CN(1)));
    } else {
        lua_pushnumber(L,l_mathop(atan2)(CN(1),CN(2)));
    }
    return 1;
}

static int Llog(lua_State *L)
{
    if (lua_gettop(L) == 1) {
        lua_pushnumber(L,l_mathop(log)(CN(1)));
    } else {
        lua_Number b = CN(2);
        if (b == 10.0) {
            lua_pushnumber(L,l_mathop(log10)(CN(1)));
        } else if (b == 2.0) {
            lua_pushnumber(L,l_mathop(log2)(CN(1)));
        } else {
            lua_pushnumber(L,l_mathop(log)(CN(1))/l_mathop(log)(b));
        }
    }
    return 1;
}

static int Lacos     (lua_State *L) { lua_pushnumber (L,l_mathop(acos)     (CN(1)));             return 1; }
static int Lacosh    (lua_State *L) { lua_pushnumber (L,l_mathop(acosh)    (CN(1)));             return 1; }
static int Lasin     (lua_State *L) { lua_pushnumber (L,l_mathop(asin)     (CN(1)));             return 1; }
static int Lasinh    (lua_State *L) { lua_pushnumber (L,l_mathop(asinh)    (CN(1)));             return 1; }
static int Latan2    (lua_State *L) { lua_pushnumber (L,l_mathop(atan2)    (CN(1),CN(2)));       return 1; }
static int Latanh    (lua_State *L) { lua_pushnumber (L,l_mathop(atanh)    (CN(1)));             return 1; }
static int Lcbrt     (lua_State *L) { lua_pushnumber (L,l_mathop(cbrt)     (CN(1)));             return 1; }
static int Lceil     (lua_State *L) { lua_pushnumber (L,l_mathop(ceil)     (CN(1)));             return 1; }
static int Lcopysign (lua_State *L) { lua_pushnumber (L,l_mathop(copysign) (CN(1),CN(2)));       return 1; }
static int Lcos      (lua_State *L) { lua_pushnumber (L,l_mathop(cos)      (CN(1)));             return 1; }
static int Lcosh     (lua_State *L) { lua_pushnumber (L,l_mathop(cosh)     (CN(1)));             return 1; }
static int Ldeg      (lua_State *L) { lua_pushnumber (L,         deg       (CN(1)));             return 1; }
static int Lerf      (lua_State *L) { lua_pushnumber (L,l_mathop(erf)      (CN(1)));             return 1; }
static int Lerfc     (lua_State *L) { lua_pushnumber (L,l_mathop(erfc)     (CN(1)));             return 1; }
static int Lexp      (lua_State *L) { lua_pushnumber (L,l_mathop(exp)      (CN(1)));             return 1; }
static int Lexp2     (lua_State *L) { lua_pushnumber (L,l_mathop(exp2)     (CN(1)));             return 1; }
static int Lexpm1    (lua_State *L) { lua_pushnumber (L,l_mathop(expm1)    (CN(1)));             return 1; }
static int Lfabs     (lua_State *L) { lua_pushnumber (L,l_mathop(fabs)     (CN(1)));             return 1; }
static int Lfdim     (lua_State *L) { lua_pushnumber (L,l_mathop(fdim)     (CN(1),CN(2)));       return 1; }
static int Lfloor    (lua_State *L) { lua_pushnumber (L,l_mathop(floor)    (CN(1)));             return 1; }
static int Lfma      (lua_State *L) { lua_pushnumber (L,l_mathop(fma)      (CN(1),CN(2),CN(3))); return 1; }
static int Lfmod     (lua_State *L) { lua_pushnumber (L,l_mathop(fmod)     (CN(1),CN(2)));       return 1; }
static int Lgamma    (lua_State *L) { lua_pushnumber (L,l_mathop(tgamma)   (CN(1)));             return 1; }
static int Lhypot    (lua_State *L) { lua_pushnumber (L,l_mathop(hypot)    (CN(1),CN(2)));       return 1; }
static int Lisfinite (lua_State *L) { lua_pushboolean(L,         isfinite  (CN(1)));             return 1; }
static int Lisinf    (lua_State *L) { lua_pushboolean(L,         isinf     (CN(1)));             return 1; }
static int Lisnan    (lua_State *L) { lua_pushboolean(L,         isnan     (CN(1)));             return 1; }
static int Lisnormal (lua_State *L) { lua_pushboolean(L,         isnormal  (CN(1)));             return 1; }
static int Lj0       (lua_State *L) { lua_pushnumber (L,l_mathop(j0)       (CN(1)));             return 1; }
static int Lj1       (lua_State *L) { lua_pushnumber (L,l_mathop(j1)       (CN(1)));             return 1; }
static int Ljn       (lua_State *L) { lua_pushnumber (L,l_mathop(jn)       (CI(1),CN(2)));       return 1; }
static int Lldexp    (lua_State *L) { lua_pushnumber (L,l_mathop(ldexp)    (CN(1),CI(2)));       return 1; }
static int Llgamma   (lua_State *L) { lua_pushnumber (L,l_mathop(lgamma)   (CN(1)));             return 1; }
static int Llog10    (lua_State *L) { lua_pushnumber (L,l_mathop(log10)    (CN(1)));             return 1; }
static int Llog1p    (lua_State *L) { lua_pushnumber (L,l_mathop(log1p)    (CN(1)));             return 1; }
static int Llog2     (lua_State *L) { lua_pushnumber (L,l_mathop(log2)     (CN(1)));             return 1; }
static int Llogb     (lua_State *L) { lua_pushnumber (L,l_mathop(logb)     (CN(1)));             return 1; }
static int Lnearbyint(lua_State *L) { lua_pushnumber (L,l_mathop(nearbyint)(CN(1)));             return 1; }
static int Lnextafter(lua_State *L) { lua_pushnumber (L,l_mathop(nextafter)(CN(1),CN(2)));       return 1; }
static int Lpow      (lua_State *L) { lua_pushnumber (L,l_mathop(pow)      (CN(1),CN(2)));       return 1; }
static int Lrad      (lua_State *L) { lua_pushnumber (L,         rad       (CN(1)));             return 1; }
static int Lremainder(lua_State *L) { lua_pushnumber (L,l_mathop(remainder)(CN(1),CN(2)));       return 1; }
static int Lround    (lua_State *L) { lua_pushnumber (L,l_mathop(round)    (CN(1)));             return 1; }
static int Lscalbn   (lua_State *L) { lua_pushnumber (L,l_mathop(scalbn)   (CN(1),CN(2)));       return 1; }
static int Lsin      (lua_State *L) { lua_pushnumber (L,l_mathop(sin)      (CN(1)));             return 1; }
static int Lsinh     (lua_State *L) { lua_pushnumber (L,l_mathop(sinh)     (CN(1)));             return 1; }
static int Lsqrt     (lua_State *L) { lua_pushnumber (L,l_mathop(sqrt)     (CN(1)));             return 1; }
static int Ltan      (lua_State *L) { lua_pushnumber (L,l_mathop(tan)      (CN(1)));             return 1; }
static int Ltanh     (lua_State *L) { lua_pushnumber (L,l_mathop(tanh)     (CN(1)));             return 1; }
static int Ltgamma   (lua_State *L) { lua_pushnumber (L,l_mathop(tgamma)   (CN(1)));             return 1; }
static int Ltrunc    (lua_State *L) { lua_pushnumber (L,l_mathop(trunc)    (CN(1)));             return 1; }
static int Ly0       (lua_State *L) { lua_pushnumber (L,l_mathop(y0)       (CN(1)));             return 1; }
static int Ly1       (lua_State *L) { lua_pushnumber (L,l_mathop(y1)       (CN(1)));             return 1; }
static int Lyn       (lua_State *L) { lua_pushnumber (L,l_mathop(yn)       (CI(1),CN(2)));       return 1; }

static const luaL_Reg extramath[] =
{
    { "acos",       Lacos },
    { "acosh",      Lacosh },
    { "asin",       Lasin },
    { "asinh",      Lasinh },
    { "atan",       Latan },
    { "atan2",      Latan2 },
    { "atanh",      Latanh },
    { "cbrt",       Lcbrt },
    { "ceil",       Lceil },
    { "copysign",   Lcopysign },
    { "cos",        Lcos },
    { "cosh",       Lcosh },
    { "deg",        Ldeg },
    { "erf",        Lerf },
    { "erfc",       Lerfc },
    { "exp",        Lexp },
    { "exp2",       Lexp2 },
    { "expm1",      Lexpm1 },
    { "fabs",       Lfabs },
    { "fdim",       Lfdim },
    { "floor",      Lfloor },
    { "fma",        Lfma },
    { "fmax",       Lfmax },
    { "fmin",       Lfmin },
    { "fmod",       Lfmod },
    { "frexp",      Lfrexp },
    { "gamma",      Lgamma },
    { "hypot",      Lhypot },
    { "isfinite",   Lisfinite },
    { "isinf",      Lisinf },
    { "isnan",      Lisnan },
    { "isnormal",   Lisnormal },
    { "j0",         Lj0 },
    { "j1",         Lj1 },
    { "jn",         Ljn },
    { "ldexp",      Lldexp },
    { "lgamma",     Llgamma },
    { "log",        Llog },
    { "log10",      Llog10 },
    { "log1p",      Llog1p },
    { "log2",       Llog2 },
    { "logb",       Llogb },
    { "modf",       Lmodf },
    { "nearbyint",  Lnearbyint },
    { "nextafter",  Lnextafter },
    { "pow",        Lpow },
    { "rad",        Lrad },
    { "remainder",  Lremainder },
    { "remquo",     Lfremquo },
    { "round",      Lround },
    { "scalbn",     Lscalbn },
    { "sin",        Lsin },
    { "sinh",       Lsinh },
    { "sqrt",       Lsqrt },
    { "tan",        Ltan },
    { "tanh",       Ltanh },
    { "tgamma",     Ltgamma },
    { "trunc",      Ltrunc },
    { "y0",         Ly0 },
    { "y1",         Ly1 },
    { "yn",         Lyn },

    { NULL,         NULL }

};

int luaopen_xmath(lua_State *L)
{
    luaL_newlib(L,extramath);
    lua_pushnumber(L,INFINITY);
    lua_setfield(L,-2,"inf");
    lua_pushnumber(L,NAN);
    lua_setfield(L,-2,"nan");
    lua_pushnumber(L,PI);
    lua_setfield(L,-2,"pi");
    return 1;
}
