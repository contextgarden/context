/*
    See license.txt in the root of this project. Most code here is from the luac program by the
    official Lua project developers.
*/

# include "luametatex.h"

/*

    This is a slightly adapted version of luac which is not in the library but a separate program.
    We keep a copy around in order to check changes. The version below doesn't load files nor saves
    one. It is derived from:

    $Id: luac.c $
    Lua compiler (saves bytecodes to files; also lists bytecodes)
    See Copyright Notice in lua.h

    I added this helper because I wanted to look to what extend constants were resolved beforehand
    but in the end that was seldom the case because we get them from tables and that bit of code is
    not resolved at bytecode compile time (so in the end macros made more sense, although the gain
    is very little).

    I considered replacing the print with writing to a buffer so that we can deal with it later but
    it is not worth the effort.

*/

# include "ldebug.h"
# include "lopcodes.h"
# include "lopnames.h"

static TString **tmname = NULL;

# define toproto(L,i) getproto(s2v(L->top.p+(i)))
# define UPVALNAME(x) ((f->upvalues[x].name) ? getstr(f->upvalues[x].name) : "-")
# define LUACVOID(p)  ((const void*)(p))
# define eventname(i) (getstr(tmname[i]))

static void luaclib_aux_print_string(const TString* ts)
{
    const char* s = getstr(ts);
    size_t n = tsslen(ts);
    printf("\"");
    for (size_t i = 0; i < n; i++) {
        int c = (int) (unsigned char) s[i];
        switch (c) {
            case '"':
                printf("\\\"");
                break;
            case '\\':
                printf("\\\\");
                break;
            case '\a':
                printf("\\a");
                break;
            case '\b':
                printf("\\b");
                break;
            case '\f':
                printf("\\f");
                break;
            case '\n':
                printf("\\n");
                break;
            case '\r':
                printf("\\r");
                break;
            case '\t':
                printf("\\t");
                break;
            case '\v':
                printf("\\v");
                break;
            default:
                printf(isprint(c) ? "%c" : "\\%03d", c);
                break;
        }
    }
    printf("\"");
}

static void PrintType(const Proto* f, int i)
{
    const TValue* o = &f->k[i];
    switch (ttypetag(o)) {
        case LUA_VNIL:
            printf("N");
            break;
        case LUA_VFALSE:
        case LUA_VTRUE:
            printf("B");
            break;
        case LUA_VNUMFLT:
            printf("F");
            break;
        case LUA_VNUMINT:
            printf("I");
            break;
        case LUA_VSHRSTR:
        case LUA_VLNGSTR:
            printf("S");
            break;
        default:
            /* cannot happen */
            printf("?%d", ttypetag(o));
            break;
    }
    printf("\t");
}

static void PrintConstant(const Proto* f, int i)
{
    const TValue* o = &f->k[i];
    switch (ttypetag(o)) {
        case LUA_VNIL:
            printf("nil");
            break;
        case LUA_VFALSE:
            printf("false");
            break;
        case LUA_VTRUE:
            printf("true");
            break;
        case LUA_VNUMFLT:
            {
                char buff[100];
                sprintf(buff,"%.14g", fltvalue(o)); /* LUA_NUMBER_FMT */
                printf("%s", buff);
                if (buff[strspn(buff, "-0123456789")] == '\0') {
                    printf(".0");
                }
                break;
            }
        case LUA_VNUMINT:
# if defined(__MINGW64__) || defined(__MINGW32__)
            printf("%I64i", ivalue(o)); /* LUA_INTEGER_FMT */
# else
            printf("%lli", ivalue(o));  /* LUA_INTEGER_FMT */
# endif
            break;
        case LUA_VSHRSTR:
        case LUA_VLNGSTR:
            luaclib_aux_print_string(tsvalue(o));
            break;
        default:
            /* cannot happen */
            printf("?%d", ttypetag(o));
            break;
    }
}

#define COMMENT	   "\t; "
#define EXTRAARG   GETARG_Ax(code[pc+1])
#define EXTRAARGC  (EXTRAARG*(MAXARG_C+1))
#define ISK        (isk ? "k" : "")

static void luaclib_aux_print_code(const Proto* f)
{
    const Instruction* code = f->code;
    int n = f->sizecode;
    for (int pc = 0; pc < n; pc++) {
        Instruction i = code[pc];
        OpCode o = GET_OPCODE(i);
        int a = GETARG_A(i);
        int b = GETARG_B(i);
        int c = GETARG_C(i);
        int ax = GETARG_Ax(i);
        int bx = GETARG_Bx(i);
        int sb = GETARG_sB(i);
        int sc = GETARG_sC(i);
        int sbx = GETARG_sBx(i);
        int isk = GETARG_k(i);
        int line = luaG_getfuncline(f, pc);
        printf("\t%d\t", pc + 1);
        if (line > 0) {
            printf("[%d]\t", line);
        } else {
            printf("[-]\t");
        }
        printf("%-9s\t", opnames[o]);
        switch (o) {
            case OP_MOVE:
                printf("%d %d", a, b);
                break;
            case OP_LOADI:
                printf("%d %d", a, sbx);
                break;
            case OP_LOADF:
                printf("%d %d", a, sbx);
                break;
            case OP_LOADK:
                printf("%d %d", a, bx);
                printf(COMMENT);
                PrintConstant(f, bx);
                break;
            case OP_LOADKX:
                printf("%d", a);
                printf(COMMENT);
                PrintConstant(f, EXTRAARG);
                break;
            case OP_LOADFALSE:
                printf("%d", a);
                break;
            case OP_LFALSESKIP:
                printf("%d", a);
                break;
            case OP_LOADTRUE:
                printf("%d", a);
                break;
            case OP_LOADNIL:
                printf("%d %d", a, b);
                printf(COMMENT "%d out", b + 1);
                break;
            case OP_GETUPVAL:
                printf("%d %d", a, b);
                printf(COMMENT "%s", UPVALNAME(b));
                break;
            case OP_SETUPVAL:
                printf("%d %d", a, b);
                printf(COMMENT "%s", UPVALNAME(b));
                break;
            case OP_GETTABUP:
                printf("%d %d %d", a, b, c);
                printf(COMMENT "%s", UPVALNAME(b));
                printf(" ");
                PrintConstant(f, c);
                break;
            case OP_GETTABLE:
                printf("%d %d %d", a, b, c);
                break;
            case OP_GETI:
                printf("%d %d %d", a, b, c);
                break;
            case OP_GETFIELD:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_SETTABUP:
                printf("%d %d %d%s", a, b, c, ISK);
                printf(COMMENT "%s", UPVALNAME(a));
                printf(" ");
                PrintConstant(f, b);
                if (isk) {
                    printf(" ");
                    PrintConstant(f, c);
                }
                break;
            case OP_SETTABLE:
                printf("%d %d %d%s", a, b, c, ISK);
                if (isk) {
                    printf(COMMENT);
                    PrintConstant(f, c);
                }
                break;
            case OP_SETI:
                printf("%d %d %d%s", a, b, c, ISK);
                if (isk) {
                    printf(COMMENT);
                    PrintConstant(f, c);
                }
                break;
            case OP_SETFIELD:
                printf("%d %d %d%s", a, b, c, ISK);
                printf(COMMENT);
                PrintConstant(f, b);
                if (isk) {
                    printf(" ");
                    PrintConstant(f, c);
                }
                break;
            case OP_NEWTABLE:
                printf("%d %d %d", a, b, c);
                printf(COMMENT "%d", c + EXTRAARGC);
                break;
            case OP_SELF:
                printf("%d %d %d%s", a, b, c, ISK);
                if (isk) {
                    printf(COMMENT);
                    PrintConstant(f, c);
                }
                break;
            case OP_ADDI:
                printf("%d %d %d", a, b, sc);
                break;
            case OP_ADDK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_SUBK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_MULK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_MODK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_POWK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_DIVK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_IDIVK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_BANDK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_BORK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_BXORK:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                PrintConstant(f, c);
                break;
            case OP_SHRI:
                printf("%d %d %d", a, b, sc);
                break;
            case OP_SHLI:
                printf("%d %d %d", a, b, sc);
                break;
            case OP_ADD:
                printf("%d %d %d", a, b, c);
                break;
            case OP_SUB:
                printf("%d %d %d", a, b, c);
                break;
            case OP_MUL:
                printf("%d %d %d", a, b, c);
                break;
            case OP_MOD:
                printf("%d %d %d", a, b, c);
                break;
            case OP_POW:
                printf("%d %d %d", a, b, c);
                break;
            case OP_DIV:
                printf("%d %d %d", a, b, c);
                break;
            case OP_IDIV:
                printf("%d %d %d", a, b, c);
                break;
            case OP_BAND:
                printf("%d %d %d", a, b, c);
                break;
            case OP_BOR:
                printf("%d %d %d", a, b, c);
                break;
            case OP_BXOR:
                printf("%d %d %d", a, b, c);
                break;
            case OP_SHL:
                printf("%d %d %d", a, b, c);
                break;
            case OP_SHR:
                printf("%d %d %d", a, b, c);
                break;
            case OP_MMBIN:
                printf("%d %d %d", a, b, c);
                printf(COMMENT "%s", eventname(c));
                break;
            case OP_MMBINI:
                printf("%d %d %d %d", a, sb, c, isk);
                printf(COMMENT "%s", eventname(c));
                if (isk) {
                    printf(" flip");
                }
                break;
            case OP_MMBINK:
                printf("%d %d %d %d", a, b, c, isk);
                printf(COMMENT "%s ", eventname(c));
                PrintConstant(f, b);
                if (isk) {
                    printf(" flip");
                }
                break;
            case OP_UNM:
                printf("%d %d", a, b);
                break;
            case OP_BNOT:
                printf("%d %d", a, b);
                break;
            case OP_NOT:
                printf("%d %d", a, b);
                break;
            case OP_LEN:
                printf("%d %d", a, b);
                break;
            case OP_CONCAT:
                printf("%d %d", a, b);
                break;
            case OP_CLOSE:
                printf("%d", a);
                break;
            case OP_TBC:
                printf("%d", a);
                break;
            case OP_JMP:
                printf("%d", GETARG_sJ(i));
                printf(COMMENT "to %d", GETARG_sJ(i) + pc + 2);
                break;
            case OP_EQ:
                printf("%d %d %d", a, b, isk);
                break;
            case OP_LT:
                printf("%d %d %d", a, b, isk);
                break;
            case OP_LE:
                printf("%d %d %d", a, b, isk);
                break;
            case OP_EQK:
                printf("%d %d %d", a, b, isk);
                printf(COMMENT);
                PrintConstant(f, b);
                break;
            case OP_EQI:
                printf("%d %d %d", a, sb, isk);
                break;
            case OP_LTI:
                printf("%d %d %d", a, sb, isk);
                break;
            case OP_LEI:
                printf("%d %d %d", a, sb, isk);
                break;
            case OP_GTI:
                printf("%d %d %d", a, sb, isk);
                break;
            case OP_GEI:
                printf("%d %d %d", a, sb, isk);
                break;
            case OP_TEST:
                printf("%d %d", a, isk);
                break;
            case OP_TESTSET:
                printf("%d %d %d", a, b, isk);
                break;
            case OP_CALL:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                if (b==0) {
                    printf("all in ");
                } else {
                    printf("%d in ", b - 1);
                }
                if (c==0) {
                    printf("all out");
                } else {
                    printf("%d out", c- 1 );
                }
                break;
            case OP_TAILCALL:
                printf("%d %d %d", a, b, c);
                printf(COMMENT "%d in", b - 1);
                break;
            case OP_RETURN:
                printf("%d %d %d", a, b, c);
                printf(COMMENT);
                if (b == 0) {
                    printf("all out");
                } else {
                    printf("%d out", b - 1);
                }
                break;
            case OP_RETURN0:
                break;
            case OP_RETURN1:
                printf("%d", a);
                break;
            case OP_FORLOOP:
                printf("%d %d", a, bx);
                printf(COMMENT "to %d", pc - bx + 2);
                break;
            case OP_FORPREP:
                printf("%d %d", a, bx);
                printf(COMMENT "to %d", pc + bx + 2);
                break;
            case OP_TFORPREP:
                printf("%d %d", a, bx);
                printf(COMMENT "to %d", pc + bx + 2);
                break;
            case OP_TFORCALL:
                printf("%d %d", a, c);
                break;
            case OP_TFORLOOP:
                printf("%d %d", a, bx);
                printf(COMMENT "to %d", pc - bx + 2);
                break;
            case OP_SETLIST:
                printf("%d %d %d", a, b, c);
                if (isk) {
                    printf(COMMENT "%d", c + EXTRAARGC);
                }
                break;
            case OP_CLOSURE:
                printf("%d %d",a,bx);
                printf(COMMENT "%p", LUACVOID(f->p[bx]));
                break;
            case OP_VARARG:
                printf("%d %d", a, c);
                printf(COMMENT);
                if (c == 0) {
                    printf("all out");
                } else {
                    printf("%d out", c-1);
                }
                break;
            case OP_VARARGPREP:
                printf("%d",a);
                break;
            case OP_EXTRAARG:
                printf("%d", ax);
                break;
            default:
                printf("%d %d %d", a, b, c);
                printf(COMMENT "not handled");
                break;
        }
        printf("\n");
    }
}

# define SS(x) ((x == 1) ? "" : "s")
# define S(x)  (int)(x),SS(x)

static void luaclib_aux_print_header(const Proto* f)
{
    const char* s = f->source ? getstr(f->source) : "=?";
    if (*s == '@' || *s == '=') {
        s++;
    } else if (*s == LUA_SIGNATURE[0]) {
        s = "(bstring)";
    } else {
        s = "(string)";
    }
    printf("\n%s <%s:%d,%d> (%d instruction%s at %p)\n",
        (f->linedefined == 0) ? "main" : "function",
        s,
        f->linedefined,f->lastlinedefined,
        S(f->sizecode),LUACVOID(f)
    );
    printf("%d%s param%s, %d slot%s, %d upvalue%s, ",
        (int)(f->numparams),
        f->is_vararg?"+":"",
        SS(f->numparams),
        S(f->maxstacksize),
        S(f->sizeupvalues)
    );
    printf("%d local%s, %d constant%s, %d function%s\n",
        S(f->sizelocvars),
        S(f->sizek),
        S(f->sizep)
    );
}

static void luaclib_aux_print_debug(const Proto* f)
{
    {
        int n = f->sizek;
        printf("constants (%d) for %p:\n", n, LUACVOID(f));
        for (int i = 0; i < n; i++) {
            printf("\t%d\t", i);
            PrintType(f, i);
            PrintConstant(f, i);
            printf("\n");
        }
    }
    {
        int n = f->sizelocvars;
        printf("locals (%d) for %p:\n", n, LUACVOID(f));
        for (int i = 0; i < n; i++) {
            printf("\t%d\t%s\t%d\t%d\n",
                i,
                getstr(f->locvars[i].varname),
                f->locvars[i].startpc+1,
                f->locvars[i].endpc+1
            );
        }
    }
    {
        int n = f->sizeupvalues;
        printf("upvalues (%d) for %p:\n", n, LUACVOID(f));
        for (int i = 0; i < n; i++) {
            printf("\t%d\t%s\t%d\t%d\n",
                i,
                UPVALNAME(i),
                f->upvalues[i].instack,
                f->upvalues[i].idx
            );
        }
    }
}

/* We only have one (needs checking). */

static void luaclib_aux_print_function(const Proto* f, int full)
{
    int n = f->sizep;
    luaclib_aux_print_header(f);
    luaclib_aux_print_code(f);
    if (full) {
        luaclib_aux_print_debug(f);
    }
    for (int i = 0; i < n; i++) {
        luaclib_aux_print_function(f->p[i], full);
    }
}

static int luaclib_print(lua_State *L)
{
    int full = lua_toboolean(L, 2);
    size_t len = 0;
    const char *str = lua_tolstring(L, 1, &len);
    if (len > 0 && luaL_loadbuffer(L, str, len, str) == LUA_OK) {
        const Proto *f = toproto(L, -1);
        if (f) {
            tmname = G(L)->tmname;
            luaclib_aux_print_function(f, full);
        }
    }
    return 0;
}

/* So far for the adapted rip-off. */

void lmt_luaclib_initialize(void)
{
    /* not used yet */
}

static const struct luaL_Reg luaclib_function_list[] = {
    { "print", luaclib_print },
    { NULL,    NULL          },
};

int luaopen_luac(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, luaclib_function_list, 0);
    return 1;
}
