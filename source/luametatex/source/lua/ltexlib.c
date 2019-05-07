/*
    See license.txt in the root of this project.
*/

/*

    Because the lists start with a temp node, we have to set the prev link to nil
    because otherwise at the lua end we expose temp which can create havoc. In
    the setter no prev link is created so we can presume that it's not used later
    on.

*/

# include "luatex-common.h"

/*tex

    We use a flag to indicate the kind of data that we are dealing with:

    \starttabulate
    \NC 0 \NC string \NC \NR
    \NC 1 \NC char   \NC \NR
    \NC 2 \NC token  \NC \NR
    \NC 3 \NC node   \NC \NR
    \stoptabulate

    By treating simple \ASCII\ characters special we prevent mallocs.

*/

typedef struct {
    unsigned char c1, c2, c3, c4;
} spindle_char;


typedef union {
    spindle_char c;
    halfword h ;
} spindle_data;

typedef struct {
    char *text;
    unsigned int tsize;
    void *next;
    int partial;   /* waste of space */
    short cattable;
    short kind;
    spindle_data data;
} rope;

typedef struct {
    rope *head;
    rope *tail;
    char complete;
} spindle;

# define FULL_LINE    0
# define PARTIAL_LINE 1

# define write_spindle spindles[spindle_index]
# define read_spindle  spindles[(spindle_index-1)]

typedef struct spindle_state_info {
    int spindle_size;
    int spindle_index;
    spindle *spindles;
} spindle_state_info ;

static spindle_state_info spindle_state = { 0, 0, NULL } ;

# define spindle_size  spindle_state.spindle_size
# define spindles      spindle_state.spindles
# define spindle_index spindle_state.spindle_index

static void luac_initialize(void)
{
    spindles = malloc(sizeof(spindle));
    spindle_index = 0;
    spindles[0].head = NULL;
    spindles[0].tail = NULL;
    spindle_size = 1;
}

static int luac_store(lua_State * L, int i, int partial, int cattable)
{
    char *st = NULL;
    size_t tsize = 0;
    rope *rn = NULL;
    int kind = 0;
    spindle_data data ;
    int t = lua_type(L, i);
    if (t == LUA_TNUMBER || t == LUA_TSTRING) {
        const char *sttemp = lua_tolstring(L, i, &tsize);
        if (!partial) {
            while (tsize > 0 && sttemp[tsize-1] == ' ') {
                tsize--;
            }
        }
        switch (tsize) {
            case 4:
                data.c.c4 = (unsigned char) sttemp[3];
                __attribute__((fallthrough));
            case 3:
                data.c.c3 = (unsigned char) sttemp[2];
                __attribute__((fallthrough));
            case 2:
                data.c.c2 = (unsigned char) sttemp[1];
                __attribute__((fallthrough));
            case 1:
                data.c.c1 = (unsigned char) sttemp[0];
                kind = 1; /* ascii char */
                break;
            case 0:
             // kind = 0; /* empty string */
                return 0;
                break;
            default:
             // kind = 0; /* string, we could intercept single utf */
                st = malloc((unsigned) (tsize + 1));
                memcpy(st, sttemp, (tsize + 1));
                break;
        }
    } else if (t == LUA_TUSERDATA) {
        void *p = lua_touserdata(L, i);
        if (p == NULL) {
            return 0;
        } else if (lua_getmetatable(L, i)) {
            lua_get_metatablelua(luatex_token);
            if (lua_rawequal(L, -1, -2)) {
                kind = 2; /* token */
                data.h = token_info((*((lua_token *)p)).token);
                lua_pop(L, 2);
            } else {
                lua_get_metatablelua(luatex_node);
                if (lua_rawequal(L, -1, -3)) {
                    kind = 3; /* node */
                    data.h = *((halfword *)p);
                    lua_pop(L, 3);
                } else {
                    lua_pop(L, 3);
                    return 0;
                }
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
    /* common */
    luacstrings++;
    rn = (rope *) malloc(sizeof(rope));
    rn->text = st;
    rn->tsize = (unsigned) tsize;
    rn->kind = kind;
    rn->data = data;
    rn->next = NULL;
    rn->partial = partial;
    rn->cattable = cattable;
    /* add */
    if (write_spindle.head == NULL) {
        write_spindle.head = rn;
    } else {
        write_spindle.tail->next = rn;
    }
    write_spindle.tail = rn;
    write_spindle.complete = 0;
    return 1;
}

static int do_luacprint(lua_State * L, int partial, int deftable)
{
    int cattable = deftable;
    int startstrings = 1;
    int n = lua_gettop(L);
    if (cattable != NO_CAT_TABLE && lua_type(L, 1) == LUA_TNUMBER && n > 1) {
        cattable = lua_tointeger(L, 1);
        startstrings = 2;
        if (cattable != -1 && cattable != -2 && !valid_catcode_table(cattable)) {
            cattable = DEFAULT_CAT_TABLE;
        }
    }
    if (lua_type(L, startstrings) == LUA_TTABLE) {
        int i;
        for (i = 1;; i++) {
            lua_rawgeti(L, startstrings, i);
            if (luac_store(L, -1, partial, cattable)) {
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
                break;
            }
        }
    } else {
        int i;
        for (i = startstrings; i <= n; i++) {
            luac_store(L, i, partial, cattable);
        }
    }
    return 0;
}

/* lua.write */

static int luacwrite(lua_State * L)
{
    return do_luacprint(L, FULL_LINE, NO_CAT_TABLE);
}

/* lua.print */

static int luacprint(lua_State * L)
{
    return do_luacprint(L, FULL_LINE, DEFAULT_CAT_TABLE);
}

/* lua.sprint */

static int luacsprint(lua_State * L)
{
    return do_luacprint(L, PARTIAL_LINE, DEFAULT_CAT_TABLE);
}

/* lua.cprint */

static int luaccprint(lua_State * L)
{
    /*tex so a negative value is a specific catcode with offset 1 */
    int cattable = lua_tointeger(L,1);
    if (cattable < 0 || cattable > 15) {
        cattable = - 12 - 0xFF ;
    } else {
        cattable = - cattable - 0xFF;
    }
    if (lua_type(L, 2) == LUA_TTABLE) {
        int i;
        for (i = 1;; i++) {
            lua_rawgeti(L, 2, i);
            if (luac_store(L, -1, PARTIAL_LINE, cattable)) {
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
                break;
            }
        }
    } else {
        int i;
        int n = lua_gettop(L);
        for (i = 2; i <= n; i++) {
            luac_store(L, i, PARTIAL_LINE, cattable);
        }
    }
    return 0;
}

/* lua.tprint */

static int luactprint(lua_State * L)
{
    int i, j;
    int cattable, startstrings;
    int n = lua_gettop(L);
    for (i = 1; i <= n; i++) {
        cattable = DEFAULT_CAT_TABLE;
        startstrings = 1;
        if (lua_type(L, i) != LUA_TTABLE) {
            luaL_error(L, "no string to print");
        }
        lua_pushvalue(L, i); /* push the table */
        lua_pushinteger(L, 1);
        lua_gettable(L, -2);
        if (lua_type(L, -1) == LUA_TNUMBER) {
            cattable = lua_tointeger(L, -1);
            startstrings = 2;
            if (cattable != -1 && cattable != -2 && !valid_catcode_table(cattable)) {
                cattable = DEFAULT_CAT_TABLE;
            }
        }
        lua_pop(L, 1);
        for (j = startstrings;; j++) {
            lua_pushinteger(L, j);
            lua_gettable(L, -2);
            if (luac_store(L, -1, PARTIAL_LINE, cattable)) {
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
                break;
            }
        }
        lua_pop(L, 1); /* pop the table */
    }
    return 0;
}

/*
int luacstring_cattable(void)
{
    return (int) read_spindle.tail->cattable;
}

int luacstring_partial(void)
{
    return read_spindle.tail->partial;
}

int luacstring_final_line(void)
{
    return (read_spindle.tail->next == NULL);
}

int luacstring_input(halfword *n)
*/

int luacstring_input(halfword *n, int *cattable, int *partial, int *finalline)
{
    rope *t = read_spindle.head;
    int ret = 1 ;
    if (!read_spindle.complete) {
        read_spindle.complete = 1;
        read_spindle.tail = NULL;
    }
    if (t == NULL) {
        if (read_spindle.tail != NULL)
            free(read_spindle.tail);
        read_spindle.tail = NULL;
        return 0;
    } else {
        switch (t->kind) {
            case 0:
                if (t->text != NULL) {
                    /*tex put that thing in the buffer */
//                char *st = t->text;
                 /* int ret = iofirst; */
                    iolast = iofirst;
                    check_buffer_overflow(iolast + (int) t->tsize);
memcpy(&iobuffer[iolast], &t->text[0], sizeof(unsigned char) * t->tsize);
iolast += t->tsize;
//                    while (t->tsize-- > 0) {
//                        iobuffer[iolast++] = (unsigned char) * st++;
//                    }
                    free(t->text);
                    t->text = NULL;
                }
*cattable = t->cattable;
*partial = t->partial;
*finalline = (t->next == NULL);
                    break;
            case 1:
                {
                    iolast = iofirst;
                    check_buffer_overflow(iolast + (int) t->tsize);
                    switch (t->tsize) {
                        case 4:
                            iobuffer[iolast+3] = (unsigned char) t->data.c.c4;
                            __attribute__((fallthrough));
                        case 3:
                            iobuffer[iolast+2] = (unsigned char) t->data.c.c3;
                            __attribute__((fallthrough));
                        case 2:
                            iobuffer[iolast+1] = (unsigned char) t->data.c.c2;
                            __attribute__((fallthrough));
                        case 1:
                            iobuffer[iolast+0] = (unsigned char) t->data.c.c1;
                            break;
                    }
                    iolast += t->tsize;
*cattable = t->cattable;
*partial = t->partial;
*finalline = (t->next == NULL);
                }
                break;
            case 2:
                *n = t->data.h;
                ret = 2;
                break;
            case 3:
                *n = t->data.h;
                ret = 3;
                break;
        }
    }
    if (read_spindle.tail != NULL) {
        /*tex not a one-liner */
        free(read_spindle.tail);
    }
    read_spindle.tail = t;
    read_spindle.head = t->next;
    return ret;
}

/*tex open for reading, and make a new one for writing */

void luacstring_start(void)
{
    spindle_index++;
    if (spindle_size == spindle_index) {
        /* add a new one */
        spindles = realloc(spindles, (unsigned) (sizeof(spindle) * (unsigned) (spindle_size + 1)));
        spindles[spindle_index].head = NULL;
        spindles[spindle_index].tail = NULL;
        spindles[spindle_index].complete = 0;
        spindle_size++;
    }
}

/*tex close for reading */

void luacstring_close(void)
{
    rope *next, *t;
    next = read_spindle.head;
    while (next != NULL) {
        if (next->text != NULL)
            free(next->text);
        t = next;
        next = next->next;
        if (t==read_spindle.tail) {
            read_spindle.tail = NULL;
        }
        free(t);
    }
    read_spindle.head = NULL;
    if (read_spindle.tail != NULL)
        free(read_spindle.tail);
    read_spindle.tail = NULL;
    read_spindle.complete = 0;
    spindle_index--;
}

/*tex local (static) versions */

# define check_index_range(j,s) \
  if (j<0 || j > 65535) { \
    luaL_error(L, "incorrect index specification for tex.%s()", s);  }

# define check_register(base) do { \
    int k = get_item_index(L, lua_gettop(L), base); \
    if ((k>=0) && (k <= 65535)) { \
        lua_pushinteger(L,k); \
    } else { \
        lua_pushboolean(L,0); \
    } \
    return 1; \
} while (1)

static const char *scan_integer_part(lua_State * L, const char *ss, int *ret, int *radix_ret)
{
    int negative = 0;  /*tex should the answer be negated? */
    int m = 214748364; /*tex |2^31 / radix|, the threshold of danger */
    int d;             /*tex the digit just scanned */
    int vacuous = 1;   /*tex have no digits appeared? */
    int OK_so_far = 1; /*tex has an error message been issued? */
    int radix1 = 10;   /*tex the radix of the integer */
    int c = 0;         /*tex the current character */
    const char *s;     /*tex where we stopped in the string |ss| */
    int val = 0;       /*tex return value */
    s = ss;
    do {
        do {
            c = *s++;
        } while (c && c == ' ');
        if (c == '-') {
            negative = !negative;
            c = '+';
        }
    } while (c == '+');
    if (c == '\'') {
        radix1 = 8;
        m = 02000000000;
        c = *s++;
    } else if (c == '"') {
        radix1 = 16;
        m = 01000000000;
        c = *s++;
    }
    /*tex Accumulate the constant until |cur_tok| is not a suitable digit */
    while (1) {
        if ((c < '0' + radix1) && (c >= '0') && (c <= '0' + 9)) {
            d = c - '0';
        } else if (radix1 == 16) {
            if ((c <= 'A' + 5) && (c >= 'A')) {
                d = c - 'A' + 10;
            } else if ((c <= 'a' + 5) && (c >= 'a')) {
                d = c - 'a' + 10;
            } else {
                break;
            }
        } else {
            break;
        }
        vacuous = 0;
        if ((val >= m) && ((val > m) || (d > 7) || (radix1 != 10))) {
            if (OK_so_far) {
                luaL_error(L, "Number too big");
                val = infinity;
                OK_so_far = 0;
            }
        } else {
            val = val * radix1 + d;
        }
        c = *s++;
    }
    if (vacuous) {
        /*tex Express astonishment that no number was here */
        luaL_error(L, "Missing number, treated as zero");
    }
    if (negative)
        val = -val;
    *ret = val;
    *radix_ret = radix1;
    if (c != ' ' && s > ss)
        s--;
    return s;
}

# define set_conversion(A,B) do { num=(A); denom=(B); } while(0)

/*tex sets |cur_val| to a dimension */

static const char *scan_dimen_part(lua_State * L, const char *ss, int *ret)
{
    int negative = 0;           /*tex should the answer be negated? */
    int f = 0;                  /*tex numerator of a fraction whose denominator is $2^{16}$ */
    int num, denom;             /*tex conversion ratio for the scanned units */
    int k;                      /*tex number of digits in a decimal fraction */
    scaled v;                   /*tex an internal dimension */
    int save_cur_val;           /*tex temporary storage of |cur_val| */
    int c;                      /*tex the current character */
    const char *s = ss;         /*tex where we are in the string */
    int radix1 = 0;             /*tex the current radix */
    int rdig[18];               /*tex to save the |dig[]| array */
    int saved_tex_remainder;    /*tex to save |tex_remainder|  */
    int saved_arith_error;      /*tex to save |arith_error|  */
    int saved_cur_val;          /*tex to save the global |cur_val| */
    saved_tex_remainder = scanner_state.tex_remainder;
    saved_arith_error = scanner_state.arith_error;
    saved_cur_val = cur_val;
    /*tex get the next non-blank non-sign */
    do {
        /*tex get the next non-blank non-call token */
        do {
            c = *s++;
        } while (c && c == ' ');
        if (c == '-') {
            negative = !negative;
            c = '+';
        }
    } while (c == '+');
    if (c == ',') {
        c = '.';
    }
    if (c != '.') {
        s = scan_integer_part(L, (s > ss ? (s - 1) : ss), &cur_val, &radix1);
        c = *s;
    } else {
        radix1 = 10;
        cur_val = 0;
        c = *(--s);
    }
    if (c == ',')
        c = '.';
    if ((radix1 == 10) && (c == '.')) {
        /*tex scan decimal fraction */
        for (k = 0; k < 18; k++)
            rdig[k] = dig[k];
        k = 0;
        s++;
        /*tex get rid of the '.' */
        while (1) {
            c = *s++;
            if ((c > '0' + 9) || (c < '0'))
                break;
            if (k < 17) {
                /*tex digits for |k>=17| cannot affect the result */
                dig[k++] = c - '0';
            }
        }
        f = round_decimals(k);
        if (c != ' ')
            c = *(--s);
        for (k = 0; k < 18; k++)
            dig[k] = rdig[k];
    }
    if (cur_val < 0) {
        /*tex in this case |f=0| */
        negative = !negative;
        cur_val = -cur_val;
    }
    /*tex
        Scan for (u)units that are internal dimensions; |goto attach_sign| with
        |cur_val| set if found.
    */
    save_cur_val = cur_val;
    /*tex Get the next non-blank non-call... */
    do {
        c = *s++;
    } while (c && c == ' ');
    if (c != ' ')
        c = *(--s);
    if (strncmp(s, "em", 2) == 0) {
        s += 2;
        v = (quad(cur_font_par));
    } else if (strncmp(s, "ex", 2) == 0) {
        s += 2;
        v = (x_height(cur_font_par));
    } else if (strncmp(s, "px", 2) == 0) {
        s += 2;
        v = px_dimen_par;
    } else {
        goto NOT_FOUND;
    }
    c = *s++;
    if (c != ' ') {
        c = *(--s);
    }
    cur_val = nx_plus_y(save_cur_val, v, xn_over_d(v, f, 0200000));
    goto ATTACH_SIGN;
  NOT_FOUND:
    /*tex Scan for (m)\.{mu} units and |goto attach_fraction| */
    if (strncmp(s, "mu", 2) == 0) {
        s += 2;
        goto ATTACH_FRACTION;
    }
    if (strncmp(s, "true", 4) == 0) {
        /*tex Adjust (f)for the magnification ratio */
        s += 4;
        do {
            c = *s++;
        } while (c && c == ' ');
        c = *(--s);
    }
    if (strncmp(s, "pt", 2) == 0) {
        s += 2;
        /*tex the easy case */
        goto ATTACH_FRACTION;
    }
    /*tex
        Scan for (a)all other units and adjust |cur_val| and |f| accordingly; |goto done|
        in the case of scaled points
    */
    if (strncmp(s, "mm", 2) == 0) {
        s += 2;
        set_conversion(7227, 2540);
    } else if (strncmp(s, "cm", 2) == 0) {
        s += 2;
        set_conversion(7227, 254);
    } else if (strncmp(s, "sp", 2) == 0) {
        s += 2;
        goto DONE;
    } else if (strncmp(s, "bp", 2) == 0) {
        s += 2;
        set_conversion(7227, 7200);
    } else if (strncmp(s, "in", 2) == 0) {
        s += 2;
        set_conversion(7227, 100);
    } else if (strncmp(s, "dd", 2) == 0) {
        s += 2;
        set_conversion(1238, 1157);
    } else if (strncmp(s, "cc", 2) == 0) {
        s += 2;
        set_conversion(14856, 1157);
    } else if (strncmp(s, "pc", 2) == 0) {
        s += 2;
        set_conversion(12, 1);
    } else if (strncmp(s, "nd", 2) == 0) {
        s += 2;
        set_conversion(685, 642);
    } else if (strncmp(s, "nc", 2) == 0) {
        s += 2;
        set_conversion(1370, 107);
    } else {
        /*tex Complain about unknown unit and |goto done2| */
        luaL_error(L, "Illegal unit of measure (pt inserted)");
        goto DONE2;
    }
    cur_val = xn_over_d(cur_val, num, denom);
    f = (num * f + 0200000 * scanner_state.tex_remainder) / denom;
    cur_val = cur_val + (f / 0200000);
    f = f % 0200000;
  DONE2:
  ATTACH_FRACTION:
    if (cur_val >= 040000)
        scanner_state.arith_error = 1;
    else
        cur_val = cur_val * 65536 + f;
  DONE:
    /*tex Scan an optional space */
    c = *s++;
    if (c != ' ')
        s--;
  ATTACH_SIGN:
    if (scanner_state.arith_error || (abs(cur_val) >= 010000000000)) {
        /*tex Report that this dimension is out of range */
        luaL_error(L, "Dimension too large");
        cur_val = max_dimen;
    }
    if (negative)
        cur_val = -cur_val;
    *ret = cur_val;
    scanner_state.tex_remainder = saved_tex_remainder;
    scanner_state.arith_error = saved_arith_error;
    cur_val = saved_cur_val;
    return s;
}

static int dimen_to_number(lua_State * L, const char *s)
{
    int j = 0;
    const char *d = scan_dimen_part(L, s, &j);
    if (*d) {
        luaL_error(L, "conversion failed (trailing junk?)");
        j = 0;
    }
    return j;
}

static int tex_scaledimen(lua_State * L)
{
    int sp;
    int t = lua_type(L, 1);
    if (t == LUA_TNUMBER) {
        sp = lua_roundnumber(L, 1);
    } else if (t == LUA_TSTRING) {
        sp = dimen_to_number(L, lua_tostring(L, 1));
    } else {
        luaL_error(L, "argument must be a string or a number");
        return 0;
    }
    lua_pushinteger(L, sp);
    return 1;
}

static int texerror (lua_State * L)
{
    const char *errhlp = NULL;
    const char *error = luaL_checkstring(L,1);
    if (lua_type(L, 2) == LUA_TSTRING) {
        errhlp = luaL_checkstring(L,2);
    }
    error_state.deletions_allowed = 0;
    tex_error(error, errhlp);
    error_state.deletions_allowed = 1;
    return 0;
}

static int get_item_index(lua_State * L, int i, int base)
{
    size_t kk;
    int k;
    int cur_cs1;
    const char *s;
    switch (lua_type(L, i)) {
        case LUA_TSTRING:
            s = lua_tolstring(L, i, &kk);
            cur_cs1 = string_lookup(s, kk);
            if (cur_cs1 == undefined_control_sequence || cur_cs1 == undefined_cs_cmd)
                k = -1; /*tex guarandeed invalid */
            else
                k = (equiv(cur_cs1) - base);
            break;
        case LUA_TNUMBER:
            k = luaL_checkinteger(L, i);
            break;
        default:
            luaL_error(L, "argument must be a string or a number");
            k = -1; /*tex not a valid index */
    }
    return k;
}

# define check_item_global(L,top,isglobal) \
    if (top == 3 && (lua_type(L,1) == LUA_TSTRING)) { \
        const char *first = lua_tostring(L, 1); \
        if (lua_key_eq(first,global)) { \
            isglobal = 1; \
        } \
    }

# define set_item_index_plus(L, where, base, what, value, is_global, is_assign, set_register, glue) { \
    size_t len; \
    const char *str; \
    int key, err, cs; \
    int save_global_defs = global_defs_par; \
    if (is_global) { \
        global_defs_par = 1; \
    } \
    switch (lua_type(L, where)) { \
        case LUA_TSTRING: \
            str = lua_tolstring(L, where, &len); \
            cs = string_lookup(str, len); \
            if (cs == undefined_control_sequence || cs == undefined_cs_cmd) { \
                luaL_error(L, "incorrect %s name", what); \
            } else { \
                key = equiv(cs) - base; \
                if (key >= 0 && key <= 65535) { \
                    err = set_register(key, value); \
                    if (err) { \
                        luaL_error(L, "incorrect %s value", what); \
                    } \
                } else if (is_assign(eq_type(cs))) { \
                    if (glue) { \
                        int a = is_global; \
                        define(equiv(cs), assign_glue_cmd, value); \
                    } else { \
                        assign_internal_value((is_global ? 4 : 0), equiv(cs), value); \
                    } \
                } else { \
                    luaL_error(L, "incorrect %s name", what); \
                } \
            } \
            break; \
        case LUA_TNUMBER: \
            key = luaL_checkinteger(L, where); \
            if (key>=0 && key <= 65535) { \
                err = set_register(key, value); \
                if (err) { \
                    luaL_error(L, "incorrect %s value", what); \
                } \
            } else { \
                luaL_error(L, "incorrect %s index", what); \
            } \
            break; \
        default: \
            luaL_error(L, "argument of 'set%s' must be a string or a number", what); \
    } \
    global_defs_par = save_global_defs; \
}

static int gettex(lua_State * L);

# define get_item_index_plus(L, where, base, what, value, is_assign, get_register, texget) { \
    size_t len; \
    const char *str; \
    int key, cs; \
    switch (lua_type(L, where)) { \
        case LUA_TSTRING: \
            str = lua_tolstring(L, where, &len); \
            cs = string_lookup(str, len); \
            if (cs == undefined_control_sequence || cs == undefined_cs_cmd) { \
                luaL_error(L, "incorrect %s name", what); \
            } else { \
                key = equiv(cs) - base; \
                if (key >= 0 && key <= 65535) { \
                    value = get_register(key); \
                } else if (is_assign(eq_type(cs))) { \
                    texget = gettex(L); /* lazy */ \
                } else { \
                    luaL_error(L, "incorrect %s name", what); \
                } \
            } \
            break; \
        case LUA_TNUMBER: \
            key = luaL_checkinteger(L, where); \
            if (key>=0 && key <= 65535) { \
                value = get_register(key); \
            } else { \
                luaL_error(L, "incorrect %s index", what); \
            } \
            break; \
        default: \
            luaL_error(L, "argument of 'get%s' must be a string or a number", what); \
    } \
}

static int isdimen(lua_State * L)
{
    check_register(scaled_base);
}

static int setdimen(lua_State * L)
{
    int isglobal = 0;
    int value = 0;
    int top = lua_gettop(L);
    int t = lua_type(L, top);
    check_item_global(L,top,isglobal);
    if (t == LUA_TNUMBER) {
        value = lua_roundnumber(L, top);
    } else if (t == LUA_TSTRING) {
        value = dimen_to_number(L, lua_tostring(L, top));
    } else {
        luaL_error(L, "unsupported %s value type","dimen");
    }
    set_item_index_plus(L, top-1, scaled_base, "dimen", value, isglobal, is_dim_assign, set_tex_dimen_register, 0);
    return 0;
}

static int getdimen(lua_State * L)
{
    int value = 0;
    int texget = 0;
    get_item_index_plus(L, lua_gettop(L), scaled_base, "dimen", value, is_dim_assign, get_tex_dimen_register, texget);
    if (texget > 0) {
        return texget;
    } else {
        lua_pushinteger(L, value);
        return 1;
    }
}

static int isskip(lua_State * L)
{
    check_register(skip_base);
}

static int setskip(lua_State * L)
{
    int isglobal = 0;
    halfword *value = NULL;
    int top = lua_gettop(L);
    check_item_global(L,top,isglobal);
    value = check_isnode(L, top);
    if (type(*value) == glue_spec_node) {
        set_item_index_plus(L, top-1, skip_base, "skip", *value, isglobal, is_glue_assign, set_tex_skip_register, 1);
    } else {
        luaL_error(L, "glue_spec expected");
    }
    return 0;
}

static int getskip(lua_State * L)
{
    int value = 0;
    int texget = 0;
    get_item_index_plus(L, lua_gettop(L), skip_base, "skip", value, is_glue_assign, get_tex_skip_register, texget);
    if (texget > 0) {
        return texget;
    } else if (value) {
        lua_nodelib_push_fast(L, copy_node(value));
    } else {
        lua_nodelib_push_fast(L, copy_node(zero_glue));
    }
    return 1;
}

static int setglue(lua_State * L)
{
    int isglobal = 0;
    int index = 1;
    halfword value = copy_node(zero_glue);
    int top = lua_gettop(L);
    check_item_global(L,top,isglobal);
    if (isglobal) {
        index = 2;
        top -= 1;
    }
    /*tex [global] slot [width] [stretch] [shrink] [stretch_order] [shrink_order] */
    if (top > 1) { width(value) = lua_roundnumber(L,index+1); }
    if (top > 2) { stretch(value) = lua_roundnumber(L,index+2); }
    if (top > 3) { shrink(value) = lua_roundnumber(L,index+3); }
    if (top > 4) { stretch_order(value) = lua_tointeger(L,index+4); }
    if (top > 5) { shrink_order(value) = lua_tointeger(L,index+5); }
    set_item_index_plus(L, index, skip_base, "skip", value, isglobal, is_glue_assign, set_tex_skip_register, 1);
    return 0;
}

static int getglue(lua_State * L)
{
    int value = 0;
    int texget = 0;
    int top = lua_gettop(L);
    int dim = -1;
    if (top > 1 && lua_type(L,top) == LUA_TBOOLEAN) {
        dim = lua_toboolean(L,top);
        top = top - 1;
    } else {
        lua_pushboolean(L,1);
        dim = 1 ;
        /*tex no top adaption. somewhat messy, but the gettex fallback checks itself */
    }
    /*tex checks itself for the boolean */
    get_item_index_plus(L, top, skip_base, "glue", value, is_glue_assign, get_tex_skip_register, texget);
    if (texget > 0) {
        return texget;
    } else if (dim == 0) {
        /* false */
        if (value) {
            lua_pushinteger(L,width(value));
        } else {
            lua_pushinteger(L,0);
        }
        return 1;
   } else {
        /*tex true and nil */
        if (value) {
            lua_pushinteger(L,width(value));
            lua_pushinteger(L,stretch(value));
            lua_pushinteger(L,shrink(value));
            lua_pushinteger(L,stretch_order(value));
            lua_pushinteger(L,shrink_order(value));
        } else {
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
        }
        return 5;
    }
}

static int ismuskip(lua_State * L)
{
    check_register(mu_skip_base);
}

static int setmuskip(lua_State * L)
{
    int isglobal = 0;
    halfword *value = NULL;
    int top = lua_gettop(L);
    check_item_global(L,top,isglobal);
    value = check_isnode(L, top);
    set_item_index_plus(L, top-1, mu_skip_base, "muskip", *value, isglobal, is_mu_glue_assign, set_tex_mu_skip_register, 1);
    return 0;
}

static int getmuskip(lua_State * L)
{
    int value = 0;
    int texget = 0;
    get_item_index_plus(L, lua_gettop(L), mu_skip_base, "muskip", value, is_mu_glue_assign, get_tex_mu_skip_register, texget);
    if (texget > 0) {
        return texget;
    } else {
        lua_nodelib_push_fast(L, copy_node(value));
        return 1;
    }
}

static int setmuglue(lua_State * L)
{
    int isglobal = 0;
    int index = 1;
    halfword value = copy_node(zero_glue);
    int top = lua_gettop(L);
    check_item_global(L,top,isglobal);
    if (isglobal) {
        index = 2;
        top -= 1;
    }
    /*tex [global] slot [width] [stretch] [shrink] [stretch_order] [shrink_order] */
    if (top > 1) { width(value) = lua_roundnumber(L,index+1); }
    if (top > 2) { stretch(value) = lua_roundnumber(L,index+2); }
    if (top > 3) { shrink(value) = lua_roundnumber(L,index+3); }
    if (top > 4) { stretch_order(value) = lua_tointeger(L,index+4); }
    if (top > 5) { shrink_order(value) = lua_tointeger(L,index+5); }
    set_item_index_plus(L, index, mu_skip_base, "muskip", value, isglobal, is_mu_glue_assign, set_tex_mu_skip_register, 1);
    return 0;
}

static int getmuglue(lua_State * L)
{
    int value = 0;
    int texget = 0;
    int top = lua_gettop(L);
    int dim = -1;
    if (top > 1 && lua_type(L,top) == LUA_TBOOLEAN) {
        dim = lua_toboolean(L,top);
        top = top - 1;
    } else {
        lua_pushboolean(L,1);
        dim = 1 ;
        /*tex no top adaption. somewhat messy, but the gettex fallback checks itself */
    }
    /*tex checks itself for the boolean */
    get_item_index_plus(L, top, mu_skip_base, "muskip", value, is_mu_glue_assign, get_tex_mu_skip_register, texget);
    if (texget > 0) {
        return texget;
    } else if (dim == 0) {
        /*tex false */
        if (value) {
            lua_pushinteger(L,width(value));
        } else {
            lua_pushinteger(L,0);
        }
        return 1;
   } else {
        /*tex true and nil */
        if (value) {
            lua_pushinteger(L,width(value));
            lua_pushinteger(L,stretch(value));
            lua_pushinteger(L,shrink(value));
            lua_pushinteger(L,stretch_order(value));
            lua_pushinteger(L,shrink_order(value));
        } else {
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
            lua_pushinteger(L,0);
        }
        return 5;
    }
}

static int iscount(lua_State * L)
{
    check_register(count_base);
}

static int setcount(lua_State * L)
{
    int t;
    int isglobal = 0;
    int value = 0;
    int top = lua_gettop(L);
    check_item_global(L,top,isglobal);
    t = lua_type(L,top);
    if (t == LUA_TNUMBER) {
        value = lua_tointeger(L, top);
    } else {
        luaL_error(L, "unsupported %s value type","count");
    }
    set_item_index_plus(L, top-1, count_base, "count", value, isglobal, is_int_assign, set_tex_count_register, 0);
    return 0;
}

static int getcount(lua_State * L)
{
    int value = 0;
    int texget = 0;
    get_item_index_plus(L, lua_gettop(L), count_base, "count", value, is_int_assign, get_tex_count_register, texget);
    if (texget > 0) {
        return texget;
    } else {
        lua_pushinteger(L, value);
        return 1;
    }
}

static int isattribute(lua_State * L)
{
    check_register(attribute_base);
}

/*tex there are no system set attributes so this is a bit overkill */

static int setattribute(lua_State * L)
{
    int t;
    int isglobal = 0;
    int value = 0;
    int top = lua_gettop(L);
    check_item_global(L,top,isglobal);
    t = lua_type(L,top);
    if (t == LUA_TNUMBER) {
        value = lua_tointeger(L, top);
    } else {
        luaL_error(L, "unsupported %s value type","attribute");
    }
    set_item_index_plus(L, top-1, attribute_base, "attribute", value, isglobal, is_attr_assign, set_tex_attribute_register, 0);
    return 0;
}

static int getattribute(lua_State * L)
{
    int value = 0;
    int texget = 0;
    get_item_index_plus(L, lua_gettop(L), attribute_base, "attribute", value, is_attr_assign, get_tex_attribute_register, texget);
    if (texget > 0) {
        return texget;
    } else {
        lua_pushinteger(L, value);
        return 1;
    }
}

/*tex todo: we can avoid memcpy as there is no need to go through the pool */

/* use string_to_toks */

static int istoks(lua_State * L)
{
    check_register(toks_base);
}

static int settoks(lua_State * L)
{
    int i, err, k;
    lstring str;
    char *s;
    const char *ss;
    int is_global = 0;
    int save_global_defs = global_defs_par;
    int n = lua_gettop(L);
    if (n == 3 && (lua_type(L,1) == LUA_TSTRING)) {
        const char *first = lua_tostring(L, 1);
        if (lua_key_eq(first,global))
            is_global = 1;
    }
    if (is_global) {
        global_defs_par = 1;
    }
    i = lua_gettop(L);
    if (lua_type(L,i) == LUA_TSTRING) {
        ss = lua_tolstring(L, i, &str.l);
        s = malloc (str.l+1);
        memcpy(s, ss, str.l+1);
        str.s = (unsigned char *)s;
        k = get_item_index(L, (i - 1), toks_base);
        check_index_range(k, "settoks");
        err = set_tex_toks_register(k, str);
        free(str.s);
        global_defs_par = save_global_defs;
        if (err) {
            luaL_error(L, "incorrect value");
        }
    } else {
        luaL_error(L, "unsupported value type");
    }
    return 0;
}

static int scantoks(lua_State * L)
{
    int i, err, k, c;
    lstring str;
    char *s;
    const char *ss;
    int is_global = 0;
    int save_global_defs = global_defs_par;
    int n = lua_gettop(L);
    if (n == 4 && (lua_type(L,1) == LUA_TSTRING)) {
        const char *first = lua_tostring(L, 1);
        if (lua_key_eq(first,global))
            is_global = 1;
    }
    /* action : vsettokscct(L, is_global); */
    if (is_global) {
        global_defs_par = 1;
    }
    i = lua_gettop(L);
    if (lua_type(L,i) == LUA_TSTRING) {
        ss = lua_tolstring(L, i, &str.l);
        s = malloc (str.l+1);
        memcpy (s, ss, str.l+1);
        str.s = (unsigned char *)s;
        k = get_item_index(L, (i - 2), toks_base);
        c = luaL_checkinteger(L, i - 1);
        check_index_range(k, "settoks");
        err = scan_tex_toks_register(k, c, str);
        free(str.s);
        global_defs_par = save_global_defs;
        if (err) {
            luaL_error(L, "incorrect value");
        }
    } else {
        luaL_error(L, "unsupported value type");
    }
    return 0;
}

static int gettoks(lua_State * L)
{
    char *ss;
    str_number t;
    int k = get_item_index(L, lua_gettop(L), toks_base);
    check_index_range(k, "gettoks");
    t = get_tex_toks_register(k);
    ss = makecstring(t);
    lua_pushstring(L, ss);
    free(ss);
    flush_str(t);
    return 1;
}

static int get_box_id(lua_State * L, int i, int report)
{
    const char *s;
    int cur_cs1, cur_cmd1;
    size_t k = 0;
    int j = -1;
    switch (lua_type(L, i)) {
        case LUA_TSTRING:
            s = lua_tolstring(L, i, &k);
            cur_cs1 = string_lookup(s, k);
            cur_cmd1 = eq_type(cur_cs1);
            if (cur_cmd1 == char_given_cmd ||
                cur_cmd1 == math_given_cmd) {
                j = equiv(cur_cs1);
            }
            break;
        case LUA_TNUMBER:
            j = lua_tointeger(L, (i));
            break;
        default:
            if (report) {
                luaL_error(L, "argument must be a string or a number");
            }
            /*tex An invalid box id. */
            j = -1;
    }
    return j;
}

static int getbox(lua_State * L)
{
    int t;
    int k = get_box_id(L, -1, 1);
    check_index_range(k, "getbox");
    t = get_tex_box_register(k);
    nodelist_to_lua(L, t);
    return 1;
}

static int splitbox(lua_State * L)
{
    int k = get_box_id(L, 1, 1);
    check_index_range(k, "splitbox");
    if (lua_isnumber(L, 2)) {
        int m = 1;
        if (lua_type(L, 3) == LUA_TSTRING) {
            const char *s = lua_tostring(L, 3);
            if (lua_key_eq(s, exactly)) {
                m = 0;
            } else if (lua_key_eq(s, additional)) {
                m = 1;
            }
        } else if (lua_type(L, 3) == LUA_TNUMBER) {
            m = (int) lua_tointeger(L, 3);
        }
        if ((m<0) || (m>1)) {
            luaL_error(L, "wrong mode in splitbox");
        }
        nodelist_to_lua(L, vsplit(k,lua_roundnumber(L,2),m));
    } else {
        /* maybe a warning */
        lua_pushnil(L);
    }
    return 1;
}

static int isbox(lua_State * L)
{
    int k = get_box_id(L, -1, 0);
    lua_pushboolean(L,(k>=0 && k<=65535));
    return 1;
}

static int vsetbox(lua_State * L, int is_global)
{
    int j, err, t;
    int save_global_defs;
    int k = get_box_id(L, -2, 1);
    check_index_range(k, "setbox");
    t = lua_type(L, -1);
    if (t == LUA_TBOOLEAN) {
        j = lua_toboolean(L, -1);
        if (j == 0) {
            j = null;
        } else {
            return 0;
        }
    } else if (t == LUA_TNIL) {
        j = null;
    } else {
        j = nodelist_from_lua(L,-1);
        if (j != null && type(j) != hlist_node && type(j) != vlist_node) {
            luaL_error(L, "setbox: incompatible node type (%s)\n", get_node_name(type(j)));
            return 0;
        }
    }
    save_global_defs = global_defs_par;
    if (is_global) {
        global_defs_par = 1;
    }
    err = set_tex_box_register(k, j);
    global_defs_par = save_global_defs;
    if (err) {
        luaL_error(L, "incorrect value");
    }
    return 0;
}

static int setbox(lua_State * L)
{
    int isglobal = 0;
    int n = lua_gettop(L);
    if (n == 3 && (lua_type(L,1) == LUA_TSTRING)) {
        const char *first = lua_tostring(L, 1);
        if (lua_key_eq(first,global)) {
            isglobal = 1;
        }
    }
    return vsetbox(L, isglobal);
}

# define check_char_range(j,s,lim) \
    if (j<0 || j >= lim) { \
        luaL_error(L, "incorrect character value %d for tex.%s()", (int) j, s); \
    }

static int setcode (lua_State *L, void (*setone)(int,halfword,quarterword),
            void (*settwo)(int,halfword,quarterword), const char *name, int lim)
{
    int ch;
    halfword val, ucval;
    int level = cur_level;
    int n = lua_gettop(L);
    int f = 1;
    if (n>1 && lua_type(L,1) == LUA_TTABLE)
        f++;
    if (n>2 && (lua_type(L,f) == LUA_TSTRING)) {
        const char *first = lua_tostring(L, f);
        if (lua_key_eq(first,global)) {
            level = level_one;
            f++;
        }
    }
    ch = luaL_checkinteger(L, f);
    check_char_range(ch, name, 65536*17);
    val = (halfword) luaL_checkinteger(L, f+1);
    check_char_range(val, name, lim);
    (setone)(ch, val, level);
    if (settwo != NULL && n-f == 2) {
        ucval = (halfword) luaL_checkinteger(L, f+2);
        check_char_range(ucval, name, lim);
        (settwo)(ch, ucval, level);
    }
    return 0;
}

static int setlccode(lua_State * L)
{
    return setcode(L, &set_lc_code, &set_uc_code, "setlccode",  65536*17);
}

static int getlccode(lua_State * L)
{
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getlccode", 65536*17);
    lua_pushinteger(L, get_lc_code(ch));
    return 1;
}

static int setuccode(lua_State * L)
{
    return setcode(L, &set_uc_code, &set_lc_code, "setuccode", 65536*17);
}

static int getuccode(lua_State * L)
{
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getuccode",  65536*17);
    lua_pushinteger(L, get_uc_code(ch));
    return 1;
}

static int setsfcode(lua_State * L)
{
    return setcode(L, &set_sf_code, NULL, "setsfcode", 32768);
}

static int getsfcode(lua_State * L)
{
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getsfcode",  65536*17);
    lua_pushinteger(L, get_sf_code(ch));
    return 1;
}

static int setcatcode(lua_State * L)
{
    int ch;
    halfword val;
    int level = cur_level;
    int cattable = cat_code_table_par;
    int n = lua_gettop(L);
    int f = 1;
    if (n>1 && lua_type(L,1) == LUA_TTABLE)
        f++;
    if (n>2 && (lua_type(L,f) == LUA_TSTRING)) {
        const char *first = lua_tostring(L, f);
        if (lua_key_eq(first,global)) {
            level = level_one;
            f++;
        }
    }
    if (n-f == 2) {
        cattable = luaL_checkinteger(L, -3);
    }
    ch = luaL_checkinteger(L, -2);
    check_char_range(ch, "setcatcode", 65536*17);
    val = (halfword) luaL_checkinteger(L, -1);
    check_char_range(val, "setcatcode", 16);
    set_cat_code(cattable, ch, val, level);
    return 0;
}

static int getcatcode(lua_State * L)
{
    int cattable = cat_code_table_par;
    int ch = luaL_checkinteger(L, -1);
    if (lua_gettop(L)>=2 && lua_type(L,-2)==LUA_TNUMBER) {
        cattable = luaL_checkinteger(L, -2);
    }
    check_char_range(ch, "getcatcode",  65536*17);
    lua_pushinteger(L, get_cat_code(cattable, ch));
    return 1;
}

/*
    [global] code { c f ch }
    [global] code   c f ch   (a bit easier on memory, counterpart of getter)
*/

static int setmathcode(lua_State * L)
{
    int ch;
    halfword cval, fval, chval;
    int level = cur_level;
    int f = 1;
    if (lua_type(L,1) == LUA_TSTRING) {
        const char *first = lua_tostring(L,1);
        if (lua_key_eq(first,global)) {
            level = level_one;
            f = 2;
        }
    }
    ch = luaL_checkinteger(L, f);
    check_char_range(ch, "setmathcode", 65536*17);
    f += 1 ;
    if (lua_type(L,f) == LUA_TNUMBER) {
        cval = luaL_checkinteger(L, f);
        fval = luaL_checkinteger(L, f+1);
        chval = luaL_checkinteger(L, f+2);
    } else if (lua_type(L,f) == LUA_TTABLE) {
        lua_rawgeti(L, f, 1);
        cval = (halfword) luaL_checkinteger(L, -1);
        lua_rawgeti(L, f, 2);
        fval = (halfword) luaL_checkinteger(L, -1);
        lua_rawgeti(L, f, 3);
        chval = (halfword) luaL_checkinteger(L, -1);
        lua_pop(L,3);
    } else {
        luaL_error(L, "Bad arguments for tex.setmathcode()");
        return 0;
    }
    check_char_range(cval, "setmathcode", 8);
    check_char_range(fval, "setmathcode", 256);
    check_char_range(chval, "setmathcode", 65536*17);
    set_math_code(ch, cval,fval, chval, (quarterword) (level));
    return 0;
}

static int getmathcode(lua_State * L)
{
    mathcodeval mval = { 0, 0, 0 };
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getmathcode",  65536*17);
    mval = get_math_code(ch);
    lua_newtable(L);
    lua_pushinteger(L,mval.class_value);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L,mval.family_value);
    lua_rawseti(L, -2, 2);
    lua_pushinteger(L,mval.character_value);
    lua_rawseti(L, -2, 3);
    return 1;
}

static int getmathcodes(lua_State * L)
{
    mathcodeval mval = { 0, 0, 0 };
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getmathcodes",  65536*17);
    mval = get_math_code(ch);
    lua_pushinteger(L,mval.class_value);
    lua_pushinteger(L,mval.family_value);
    lua_pushinteger(L,mval.character_value);
    return 3;
}

/*
    [global] code { c f ch }
    [global] code   c f ch   (a bit easier on memory, counterpart of getter)
*/

static int setdelcode(lua_State * L)
{
    int ch;
    halfword sfval, scval, lfval, lcval;
    int level = cur_level;
    int f = 1;
    if (lua_type(L,1) == LUA_TSTRING) {
        const char *first = lua_tostring(L,1);
        if (lua_key_eq(first,global)) {
            level = level_one;
            f = 2;
        }
    }
    ch = luaL_checkinteger(L, f);
    check_char_range(ch, "setdelcode", 65536*17);
    f += 1;
    if (lua_type(L,f) == LUA_TNUMBER) {
        sfval = luaL_checkinteger(L, f);
        scval = luaL_checkinteger(L, f+1);
        lfval = luaL_checkinteger(L, f+2);
        lcval = luaL_checkinteger(L, f+3);
    } else if (lua_type(L,f) == LUA_TTABLE) {
        lua_rawgeti(L, f, 1);
        sfval = (halfword) luaL_checkinteger(L, -1);
        lua_rawgeti(L, f, 2);
        scval = (halfword) luaL_checkinteger(L, -1);
        lua_rawgeti(L, f, 3);
        lfval = (halfword) luaL_checkinteger(L, -1);
        lua_rawgeti(L, f, 4);
        lcval = (halfword) luaL_checkinteger(L, -1);
        lua_pop(L,4);
    } else {
        luaL_error(L, "Bad arguments for tex.setdelcode()");
        return 0;
    }
    check_char_range(sfval, "setdelcode", 256);
    check_char_range(scval, "setdelcode", 65536*17);
    check_char_range(lfval, "setdelcode", 256);
    check_char_range(lcval, "setdelcode", 65536*17);
    set_del_code(ch, sfval, scval, lfval, lcval, (quarterword) (level));
    return 0;
}

static int getdelcode(lua_State * L)
{
    delcodeval mval = { 0, 0, 0, 0, 0 };
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getdelcode",  65536*17);
    mval = get_del_code(ch);
    lua_newtable(L);
    lua_pushinteger(L,mval.small_family_value);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L,mval.small_character_value);
    lua_rawseti(L, -2, 2);
    lua_pushinteger(L,mval.large_family_value);
    lua_rawseti(L, -2, 3);
    lua_pushinteger(L,mval.large_character_value);
    lua_rawseti(L, -2, 4);
    return 1;
}

static int getdelcodes(lua_State * L)
{
    delcodeval mval = { 0, 0, 0, 0, 0 };
    int ch = luaL_checkinteger(L, -1);
    check_char_range(ch, "getdelcodes",  65536*17);
    mval = get_del_code(ch);
    lua_pushinteger(L,mval.small_family_value);
    lua_pushinteger(L,mval.small_character_value);
    lua_pushinteger(L,mval.large_family_value);
    lua_pushinteger(L,mval.large_character_value);
    return 4;
}

static int settex(lua_State * L)
{
    int i = lua_gettop(L);
    if (lua_type(L,i-1) == LUA_TSTRING) {
        size_t k;
        const char *st = lua_tolstring(L, (i - 1), &k);
        if (lua_key_eq(st,prevdepth)) {
            if (lua_type(L, i) == LUA_TNUMBER) {
                cur_list.prev_depth_field = lua_roundnumber(L, i);
            } else if (lua_type(L, i) == LUA_TSTRING) {
                cur_list.prev_depth_field = dimen_to_number(L, lua_tostring(L, i));
            } else {
                luaL_error(L, "unsupported value type");
            }
            return 0;
        } else if (lua_key_eq(st,prevgraf)) {
            if (lua_type(L, i) == LUA_TNUMBER) {
                cur_list.pg_field = lua_tointeger(L, i);
            } else {
                luaL_error(L, "unsupported value type");
            }
            return 0;
        } else if (lua_key_eq(st,spacefactor)) {
            if (lua_type(L, i) == LUA_TNUMBER) {
                cur_list.space_factor_field = lua_roundnumber(L, i);
            } else {
                luaL_error(L, "unsupported value type");
            }
            return 0;
        } else {
            int texstr = maketexlstring(st, k);
            int isprim = is_primitive(texstr);
            flush_str(texstr);
            if (isprim) {
                int j = 0;
                int cur_cs1, cur_cmd1;
                int isglobal = 0;
                if (i == 3 && (lua_type(L,1) == LUA_TSTRING)) {
                    const char *first = lua_tostring(L, 1);
                    if (lua_key_eq(first,global))
                        isglobal = 1;
                }
                cur_cs1 = string_lookup(st, k);
                cur_cmd1 = eq_type(cur_cs1);
                if (is_int_assign(cur_cmd1)) {
                    if (lua_type(L, i) == LUA_TNUMBER) {
                        int luai = lua_tointeger(L, i);
                        assign_internal_value((isglobal ? 4 : 0), equiv(cur_cs1), luai);
                    } else {
                        luaL_error(L, "unsupported value type");
                    }
                } else if (is_dim_assign(cur_cmd1)) {
                    if (lua_type(L, i) == LUA_TNUMBER) {
                        j = lua_roundnumber(L, i);
                    } else if (lua_type(L, i) == LUA_TSTRING) {
                        j = dimen_to_number(L, lua_tostring(L, i));
                    } else {
                        luaL_error(L, "unsupported value type");
                    }
                    assign_internal_value((isglobal ? 4 : 0), equiv(cur_cs1), j);
                } else if (is_glue_assign(cur_cmd1)) {
                    int a = isglobal;
                    if (lua_type(L, i) == LUA_TNUMBER) {
                        halfword value = copy_node(zero_glue);
                        width(value) = lua_roundnumber(L,i);
                        if (i > 1) { stretch(value) = lua_roundnumber(L,i+1); }
                        if (i > 3) { shrink(value) = lua_roundnumber(L,i+2); }
                        if (i > 4) { stretch_order(value) = lua_tointeger(L,i+3); }
                        if (i > 5) { shrink_order(value) = lua_tointeger(L,i+4); }
                        define(equiv(cur_cs1), assign_glue_cmd, value);
                    } else {
                        halfword *j1 = check_isnode(L, i);     /* the value */
                        define(equiv(cur_cs1), assign_glue_cmd, *j1);
                    }
                } else if (is_toks_assign(cur_cmd1)) {
                    if (lua_type(L,i) == LUA_TSTRING) {
                        j = tokenlist_from_lua(L);  /* uses stack -1 */
                        assign_internal_value((isglobal ? 4 : 0), equiv(cur_cs1), j);

                    } else {
                        luaL_error(L, "unsupported value type");
                    }

                } else if (lua_istable(L, (i - 2))) {
                    /*
                        people may want to add keys that are also primitives |tex.wd| for example)
                        so creating an error is not right here
                    */
                    lua_rawset(L, (i - 2));
                }
            } else if (lua_istable(L, (i - 2))) {
                lua_rawset(L, (i - 2));
            }
        }
    } else if (lua_istable(L, (i - 2))) {
        lua_rawset(L, (i - 2));
    }
    return 0;
}

/* todo: some will to the pdf namespace  .. ignore > 31 */

static int do_convert(lua_State * L, int cur_code)
{
    int texstr;
    int i = -1;
    char *str = NULL;
    switch (cur_code) {
        /* ignored (yet) */

        case insert_ht_code:               /* arg <register int> */
        case lua_code:                     /* arg complex */
        case lua_escape_string_code:       /* arg token list */
        case left_margin_kern_code:        /* arg box */
        case right_margin_kern_code:       /* arg box */
        case string_code:                  /* arg token */
        case cs_string_code:               /* arg token */
        case meaning_code:                 /* arg token */
            break;
        /* the next fall through, and come from 'official' indices! */
        case font_name_code:               /* arg fontid */
        case font_identifier_code:         /* arg fontid */
        case number_code:                  /* arg int */
        case roman_numeral_code:           /* arg int */
            if (lua_gettop(L) < 1) {
                /* error */
            }
            i = lua_tointeger(L, 1);
            __attribute__((fallthrough));
        default:
            /* no backend here */
            if (cur_code < 32) {
                texstr = the_convert_string(cur_code, i);
                if (texstr) {
                    str = makecstring(texstr);
                    flush_str(texstr);
                }
            }
    }
    /* end */
    if (str) {
        lua_pushstring(L, str);
        free(str);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int do_scan_internal(lua_State * L, int cur_cmd1, int cur_code, int values)
{
    int texstr;
    int retval = 1 ;
    char *str = NULL;
    int save_cur_val, save_cur_val_level;
    save_cur_val = cur_val;
    save_cur_val_level = cur_val_level;
    scan_something_simple(cur_cmd1, cur_code);
    switch (cur_val_level) {
        case int_val_level:
        case dimen_val_level:
        case attr_val_level:
            lua_pushinteger(L, cur_val);
            break;
        case glue_val_level:
        case mu_val_level:
            if (values == 0) {
                lua_pushinteger(L,width(cur_val));
                flush_node(cur_val);
            } else if (values == 1) {
                lua_pushinteger(L,width(cur_val));
                lua_pushinteger(L,stretch(cur_val));
                lua_pushinteger(L,shrink(cur_val));
                lua_pushinteger(L,stretch_order(cur_val));
                lua_pushinteger(L,shrink_order(cur_val));
                flush_node(cur_val);
                retval = 5;
            } else {
                lua_nodelib_push_fast(L, cur_val);
            }
            break;
        default:
            texstr = the_scanned_result();
            str = makecstring(texstr);
            if (str) {
                lua_pushstring(L, str);
                free(str);
            } else {
                lua_pushnil(L);
            }
            flush_str(texstr);
            break;
    }
    cur_val = save_cur_val;
    cur_val_level = save_cur_val_level;
    return retval;
}

static int do_lastitem(lua_State * L, int cur_code)
{
    int retval = 1;
    switch (cur_code) {
        /* the next two do not actually exist */
        case lastattr_code:
        case attrexpr_code:
            lua_pushnil(L);
            break;
            /* the expressions do something complicated with arguments, yuck */
        case numexpr_code:
        case dimexpr_code:
        case glueexpr_code:
        case muexpr_code:
            lua_pushnil(L);
            break;
            /* these read a glue or muglue, todo */
        case mu_to_glue_code:
        case glue_to_mu_code:
        case glue_stretch_order_code:
        case glue_shrink_order_code:
        case glue_stretch_code:
        case glue_shrink_code:
            lua_pushnil(L);
            break;
            /* these read a fontid and a char, todo */
        case font_char_wd_code:
        case font_char_ht_code:
        case font_char_dp_code:
        case font_char_ic_code:
            lua_pushnil(L);
            break;
            /* these read an integer, todo */
        case par_shape_length_code:
        case par_shape_indent_code:
        case par_shape_dimen_code:
            lua_pushnil(L);
            break;
        case lastpenalty_code:
        case lastkern_code:
        case lastskip_code:
        case last_node_type_code:
        case input_line_no_code:
        case badness_code:
        case luatex_version_code:
        case eTeX_minor_version_code:
        case eTeX_version_code:
        case current_group_level_code:
        case current_group_type_code:
        case current_if_level_code:
        case current_if_type_code:
        case current_if_branch_code:
            retval = do_scan_internal(L, last_item_cmd, cur_code, -1);
            break;
        default:
            lua_pushnil(L);
            break;
    }
    return retval;
}

static int tex_setmathparm(lua_State * L)
{
    int i, j;
    int k;
    int l = cur_level;
    void *p;
    int n = lua_gettop(L);
    if ((n == 3) || (n == 4)) {
        if (n == 4 && (lua_type(L,1) == LUA_TSTRING)) {
            const char *first = lua_tostring(L, 1);
            if (lua_key_eq(first,global))
                l = 1;
        }
        i = luaL_checkoption(L, (n - 2), NULL, math_param_names);
        j = luaL_checkoption(L, (n - 1), NULL, math_style_names);
        if (i<0 && i>=math_param_last) {
            /* invalid spec, just ignore it  */
        } else if (i>=math_param_first_mu_glue) {
            p = lua_touserdata(L, n);
            k = *((halfword *)p);
            def_math_param(i, j, (scaled) k, l);
        } else if (lua_type(L, n) == LUA_TNUMBER) {
            k = lua_roundnumber(L, n);
            def_math_param(i, j, (scaled) k, l);
        } else {
            luaL_error(L, "argument must be a number");
        }
    }
    return 0;
}

static int tex_getmathparm(lua_State * L)
{
    if ((lua_gettop(L) == 2)) {
        int i = luaL_checkoption(L, 1, NULL, math_param_names);
        int j = luaL_checkoption(L, 2, NULL, math_style_names);
        scaled k = get_math_param(i, j);
        if (i<0 && i>=math_param_last) {
            lua_pushnil(L);
        } else if (i>=math_param_first_mu_glue) {
            if (k <= thick_mu_skip_code) {
                k = glue_par(k);
            }
            lua_nodelib_push_fast(L, k);
        } else {
            lua_pushinteger(L, k);
        }
    }
    return 1;
}

static int getfontname(lua_State * L)
{
    return do_convert(L, font_name_code);
}

static int getfontidentifier(lua_State * L)
{
    return do_convert(L, font_identifier_code);
}

static int getnumber(lua_State * L)
{
    return do_convert(L, number_code);
}

static int getromannumeral(lua_State * L)
{
    return do_convert(L, roman_numeral_code);
}

static int get_parshape(lua_State * L)
{
    halfword par_shape_ptr = par_shape_par_ptr;
    if (par_shape_ptr != 0) {
        int m = 1;
        int n = vinfo(par_shape_ptr + 1);
        lua_createtable(L, n, 0);
        while (m <= n) {
            lua_createtable(L, 2, 0);
            lua_pushinteger(L, vlink((par_shape_ptr) + (2 * (m - 1)) + 2));
            lua_rawseti(L, -2, 1);
            lua_pushinteger(L, vlink((par_shape_ptr) + (2 * (m - 1)) + 3));
            lua_rawseti(L, -2, 2);
            lua_rawseti(L, -2, m);
            m++;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int gettex(lua_State * L)
{
    int cur_cs1 = -1;
    int retval = 1; /* default is to return nil  */
    int t = lua_gettop(L);
    int b = -1 ;
    if (t > 1 && lua_type(L,t) == LUA_TBOOLEAN) {
        /*
             0 == flush width only
             1 == flush all glue parameters
        */
        b = lua_toboolean(L,t);
        t = t - 1;
    }
    if (lua_type(L,t) == LUA_TSTRING) {
        /*
            1 == tex
            2 == boxmaxdepth
                or
            1 == boxmaxdepth
        */
        int texstr;
        size_t k;
        const char *st = lua_tolstring(L, t, &k);
        if (lua_key_eq(st,prevdepth)) {
            lua_pushinteger(L, cur_list.prev_depth_field);
            return 1;
        } else if (lua_key_eq(st,prevgraf)) {
            lua_pushinteger(L, cur_list.pg_field);
            return 1;
        } else if (lua_key_eq(st,spacefactor)) {
            lua_pushinteger(L, cur_list.space_factor_field);
            return 1;
        }
        texstr = maketexlstring(st, k);
        cur_cs1 = prim_lookup(texstr);   /* not found == relax == 0 */
        flush_str(texstr);
    }
    if (cur_cs1 > 0) {
        int cur_cmd1 = get_prim_eq_type(cur_cs1);
        int cur_code = get_prim_equiv(cur_cs1);
        switch (cur_cmd1) {
            case last_item_cmd:
                retval = do_lastitem(L, cur_code);
                break;
            case convert_cmd:
                retval = do_convert(L, cur_code);
                break;
            case assign_toks_cmd:
            case assign_int_cmd:
            case assign_attr_cmd:
            case assign_direction_cmd:
            case assign_dimen_cmd:
            case set_aux_cmd:
            case set_prev_graf_cmd:
            case set_page_int_cmd:
            case set_page_dimen_cmd:
            case char_given_cmd:
            case math_given_cmd:
                retval = do_scan_internal(L, cur_cmd1, cur_code, -1);
                break;
            case assign_glue_cmd:
            case assign_mu_glue_cmd:
                retval = do_scan_internal(L, cur_cmd1, cur_code, b);
                break;
            case set_tex_shape_cmd:
                retval = get_parshape(L);
                break;
            default:
                lua_pushnil(L);
                break;
        }
    } else if ((t == 2) && (lua_type(L,2) == LUA_TSTRING)) {
        lua_rawget(L, 1);
    }
    return retval;
}

static int getlist(lua_State * L)
{
    const char *str;
    int top = lua_gettop(L);
    if (lua_type(L,top) == LUA_TSTRING) {
        str = lua_tostring(L, top);
        if (lua_key_eq(str,page_ins_head)) {
            if (vlink(page_ins_head) == page_ins_head)
                lua_pushinteger(L, null);
            else
                lua_pushinteger(L, vlink(page_ins_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,contrib_head)) {
            alink(vlink(contrib_head)) = null ;
            lua_pushinteger(L, vlink(contrib_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,page_discards_head)) {
            alink(vlink(page_disc)) = null ;
            lua_pushinteger(L, page_disc);
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,split_discards_head)) {
            alink(vlink(split_disc)) = null ;
            lua_pushinteger(L, split_disc);
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,page_head)) {
            alink(vlink(page_head)) = null ;/*hh-ls */
            lua_pushinteger(L, vlink(page_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,temp_head)) {
            alink(vlink(temp_head)) = null ;/*hh-ls */
            lua_pushinteger(L, vlink(temp_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,hold_head)) {
            alink(vlink(hold_head)) = null ;/*hh-ls */
            lua_pushinteger(L, vlink(hold_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,adjust_head)) {
            alink(vlink(adjust_head)) = null ;/*hh-ls */
            lua_pushinteger(L, vlink(adjust_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,best_page_break)) {
            lua_pushinteger(L, best_page_break);
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,least_page_cost)) {
            lua_pushinteger(L, least_page_cost);
        } else if (lua_key_eq(str,best_size)) {
            lua_pushinteger(L, best_size);
        } else if (lua_key_eq(str,pre_adjust_head)) {
            alink(vlink(pre_adjust_head)) = null ;/*hh-ls */
            lua_pushinteger(L, vlink(pre_adjust_head));
            lua_nodelib_push(L);
        } else if (lua_key_eq(str,align_head)) {
            alink(vlink(align_head)) = null ;/*hh-ls */
            lua_pushinteger(L, vlink(align_head));
            lua_nodelib_push(L);
        } else {
            lua_pushnil(L);
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int setlist(lua_State * L)
{
    int top = (lua_type(L,1) == LUA_TTABLE) ? 2 : 1 ;
    if (lua_type(L,top) == LUA_TSTRING) {
        const char *str = lua_tostring(L, top);
        if (lua_key_eq(str,best_size)) {
            best_size = (int) lua_tointeger(L, top+1);
        } else if (lua_key_eq(str,least_page_cost)) {
            least_page_cost = (int) lua_tointeger(L, top+1);
        } else {
            halfword *n_ptr;
            halfword n = 0;
            if (!lua_isnil(L, top+1)) {
                n_ptr = check_isnode(L, top+1);
                n = *n_ptr;
            }
            if (lua_key_eq(str,page_ins_head)) {
                if (n == 0) {
                    vlink(page_ins_head) = page_ins_head;
                } else {
                    halfword m;
                    vlink(page_ins_head) = n;
                    m = tail_of_list(n);
                    vlink(m) = page_ins_head;
                }
            } else if (lua_key_eq(str,contrib_head)) {
                vlink(contrib_head) = n;
                if (n == 0) {
                    contrib_tail = contrib_head;
                }
            } else if (lua_key_eq(str,best_page_break)) {
                best_page_break = n;
            } else if (lua_key_eq(str,page_head)) {
                vlink(page_head) = n;
                page_tail = (n == 0 ? page_head : tail_of_list(n));
            } else if (lua_key_eq(str,temp_head)) {
                vlink(temp_head) = n;
            } else if (lua_key_eq(str,page_discards_head)) {
                page_disc = n;
            } else if (lua_key_eq(str,split_discards_head)) {
                split_disc = n;
            } else if (lua_key_eq(str,hold_head)) {
                vlink(hold_head) = n;
            } else if (lua_key_eq(str,adjust_head)) {
                vlink(adjust_head) = n;
                adjust_tail = (n == 0 ? adjust_head : tail_of_list(n));
            } else if (lua_key_eq(str,pre_adjust_head)) {
                vlink(pre_adjust_head) = n;
                pre_adjust_tail = (n == 0 ? pre_adjust_head : tail_of_list(n));
            } else if (lua_key_eq(str,align_head)) {
                vlink(align_head) = n;
            }
        }
    }
    return 0;
}

# define NEST_METATABLE "luatex.nest"

static int lua_nest_getfield(lua_State * L)
{
    list_state_record *r, **rv = lua_touserdata(L, -2);
    const char *field = lua_tostring(L, -1);
    r = *rv;
    if (lua_key_eq(field,mode)) {
        lua_pushinteger(L, r->mode_field);
    } else if (lua_key_eq(field,head)) {
        lua_nodelib_push_fast(L, r->head_field);
    } else if (lua_key_eq(field,tail)) {
        lua_nodelib_push_fast(L, r->tail_field);
    } else if (lua_key_eq(field,delimptr)) {
        lua_pushinteger(L, r->eTeX_aux_field);
        lua_nodelib_push(L);
    } else if (lua_key_eq(field,prevgraf)) {
        lua_pushinteger(L, r->pg_field);
    } else if (lua_key_eq(field,modeline)) {
        lua_pushinteger(L, r->ml_field);
    } else if (lua_key_eq(field,prevdepth)) {
        lua_pushinteger(L, r->prev_depth_field);
    } else if (lua_key_eq(field,spacefactor)) {
        lua_pushinteger(L, r->space_factor_field);
    } else if (lua_key_eq(field,noad)) {
        lua_pushinteger(L, r->incompleat_noad_field);
        lua_nodelib_push(L);
    } else if (lua_key_eq(field,dirs)) {
        lua_pushinteger(L, r->dirs_field);
        lua_nodelib_push(L);
    } else if (lua_key_eq(field,mathdir)) {
        lua_pushboolean(L, r->math_field);
    } else if (lua_key_eq(field,mathstyle)) {
        lua_pushinteger(L, r->math_style_field);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int lua_nest_setfield(lua_State * L)
{
    halfword *n;
    int i;
    list_state_record *r, **rv = lua_touserdata(L, -3);
    const char *field = lua_tostring(L, -2);
    r = *rv;
    if (lua_key_eq(field,mode)) {
        i = lua_tointeger(L, -1);
        r->mode_field = i;
    } else if (lua_key_eq(field,head)) {
        n = check_isnode(L, -1);
        r->head_field = *n;
    } else if (lua_key_eq(field,tail)) {
        n = check_isnode(L, -1);
        r->tail_field = *n;
    } else if (lua_key_eq(field,delimptr)) {
        n = check_isnode(L, -1);
        r->eTeX_aux_field = *n;
    } else if (lua_key_eq(field,prevgraf)) {
        i = lua_tointeger(L, -1);
        r->pg_field = i;
    } else if (lua_key_eq(field,modeline)) {
        i = lua_tointeger(L, -1);
        r->ml_field = i;
    } else if (lua_key_eq(field,prevdepth)) {
        i = lua_roundnumber(L, -1);
        r->prev_depth_field = i;
    } else if (lua_key_eq(field,spacefactor)) {
        i = lua_roundnumber(L, -1);
        r->space_factor_field = i;
    } else if (lua_key_eq(field,noad)) {
        n = check_isnode(L, -1);
        r->incompleat_noad_field = *n;
    } else if (lua_key_eq(field,dirs)) {
        n = check_isnode(L, -1);
        r->dirs_field = *n;
    } else if (lua_key_eq(field,mathdir)) {
        r->math_field = lua_toboolean(L, -1);
    } else if (lua_key_eq(field,mathstyle)) {
        i = lua_tointeger(L, -1);
        r->math_style_field = i;
    }
    return 0;
}

static const struct luaL_Reg nest_m[] = {
    { "__index",    lua_nest_getfield },
    { "__newindex", lua_nest_setfield },
    { NULL,         NULL }
};

static void init_nest_lib(lua_State * L)
{
    luaL_newmetatable(L, NEST_METATABLE);
    luaL_setfuncs(L, nest_m, 0);
    lua_pop(L, 1);
}

static int getnest(lua_State * L)
{
    list_state_record **nestitem;
    int n = lua_gettop(L);
    int p = -1 ;
    if (n == 0) {
        p = nest_ptr;
    } else {
        int t = lua_type(L, n);
        if (t == LUA_TNUMBER) {
            int ptr = lua_tointeger(L, n);
            if (ptr >= 0 && ptr <= nest_ptr) {
                p = ptr;
            }
        } else if (t == LUA_TSTRING) {
            const char *s = lua_tostring(L, n);
            if (lua_key_eq(s,top)) {
                p = nest_ptr;
            } else if (lua_key_eq(s,ptr)) {
                lua_pushinteger(L, nest_ptr);
                return 1;
            }
        }
    }
    if (p > -1) {
        nestitem = lua_newuserdata(L, sizeof(list_state_record *));
        *nestitem = &nest[p];
        luaL_getmetatable(L, NEST_METATABLE);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int setnest(lua_State * L)
{
    luaL_error(L, "You can't modify the semantic nest array directly");
    return 0;
}

static int do_integer_error(double m)
{
    tex_error(
        "Number too big",
        "I can only go up to 2147483647='17777777777=" "7FFFFFFF,\n"
        "so I'm using that number instead of yours."
    );
    return (m > 0.0 ? infinity : -infinity);
}

static int tex_roundnumber(lua_State * L)
{
    double m = (double) lua_tonumber(L, 1) + 0.5; /* integer or float */
    if (abs(m) > (double) infinity)
        lua_pushinteger(L, do_integer_error(m));
    else
        lua_pushinteger(L, floor(m));
    return 1;
}

static int tex_scaletable(lua_State * L)
{
    double delta = luaL_checknumber(L, 2);
    if (lua_istable(L, 1)) {
        lua_newtable(L);        /* the new table is at index 3 */
        lua_pushnil(L);
        while (lua_next(L, 1) != 0) {   /* numeric value */
            lua_pushvalue(L, -2);
            lua_insert(L, -2);
            if (lua_type(L,-2) == LUA_TNUMBER) {
                double m = (double) lua_tonumber(L, -1) * delta + 0.5; /* integer or float */
                lua_pop(L, 1);
                if (abs(m) > (double) infinity)
                    lua_pushinteger(L, do_integer_error(m));
                else
                    lua_pushinteger(L, floor(m));
            }
            lua_rawset(L, 3);
        }
    } else if (lua_type(L,1) == LUA_TNUMBER) {
        double m = (double) lua_tonumber(L, 1) * delta + 0.5; /* integer or float */
        if (abs(m) > (double) infinity)
            lua_pushinteger(L, do_integer_error(m));
        else
            lua_pushinteger(L, floor(m));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int tex_definefont(lua_State * L)
{
    const char *csname;
    int f, u;
    str_number t, d;
    size_t l;
    int i = 1;
    int a = 0;
    if (!no_new_control_sequence) {
        tex_error(
            "Definition active",
            "You can't create a new font inside a \\csname\\endcsname pair"
        );
    }
    if ((lua_gettop(L) == 3) && lua_isboolean(L, 1)) {
        a = lua_toboolean(L, 1);
        i = 2;
    }
    csname = luaL_checklstring(L, i, &l);
    f = luaL_checkinteger(L, (i + 1));
    no_new_control_sequence = 0;
    u = string_lookup(csname, l);
    no_new_control_sequence = 1;
    if (a)
        geq_define(u, set_font_cmd, f);
    else
        eq_define(u, set_font_cmd, f);
    eqtb[font_id_base + f] = eqtb[u];
    /*tex

        This is tricky: when we redefine a string we loose the old one. So this
        will change as it's only used to display the |\fontname| so we can store
        that with the font.

    */
    d = cs_text(font_id_base + f);
    t = maketexlstring(csname, l); /* the csname */
    if (!d) {
        /*tex We have a new string. */
        cs_text(font_id_base + f) = t;
    } else if (str_eq_str(d,t)){
        /*tex We have the same string. */
        flush_str(t);
    } else {
        d = search_string(t);
        if (d) {
            /*tex We have already such a string. */
            cs_text(font_id_base + f) = d;
            flush_str(t);
        } else {
            /*tex The old value is lost but still in the pool. */
            cs_text(font_id_base + f) = t;
        }
    }
    /*tex The hackery ends here! */
    return 0;
}

static int tex_hashpairs(lua_State * L)
{
    str_number s = 0;
    int cs = 1;
    int nt = 0;
    lua_newtable(L);
    while (cs < hash_size) {
        s = cs_text(cs);
        if (s > 0) {
            char *ss = makecstring(s);
            lua_pushstring(L, ss);
            free(ss);
            lua_rawseti(L, -2, ++nt);
        }
        cs++;
    }
    return 1;
}

static int tex_primitives(lua_State * L)
{
    str_number s = 0;
    int cs = 0;
    int nt = 0;
    lua_newtable(L);
    while (cs < prim_size) {
        s = get_prim_text(cs);
        if (s > 0) {
            char *ss = makecstring(s);
            lua_pushstring(L, ss);
            free(ss);
            lua_rawseti(L, -2, ++nt);
        }
        cs++;
    }
    return 1;
}

static int tex_extraprimitives(lua_State * L)
{
    int n, i;
    int mask = 0;
    int cs = 0;
    int nt = 0;
    n = lua_gettop(L);
    if (n == 0) {
        mask = etex_command + luatex_command;
    } else {
        for (i = 1; i <= n; i++) {
            if (lua_type(L,i) == LUA_TSTRING) {
                const char *s = lua_tostring(L, i);
                if (lua_key_eq(s,etex)) {
                    mask |= etex_command;
                } else if (lua_key_eq(s,tex)) {
                    mask |= tex_command;
                } else if (lua_key_eq(s,core)) {
                    mask |= core_command;
                } else if (lua_key_eq(s,luatex)) {
                    mask |= luatex_command;
                }
            }
        }
    }
    lua_newtable(L);
    while (cs < prim_size) {
        str_number s = get_prim_text(cs);
        if (s > 0 && (get_prim_origin(cs) & mask)) {
            char *ss = makecstring(s);
            lua_pushstring(L, ss);
            free(ss);
            lua_rawseti(L, -2, ++nt);
        }
        cs++;
    }
    return 1;
}

static int tex_enableprimitives(lua_State * L)
{
    int n = lua_gettop(L);
    if (n == 2) {
        size_t l;
        int i;
        const char *pre = luaL_checklstring(L, 1, &l);
        if (lua_istable(L, 2)) {
            int nncs = no_new_control_sequence;
            no_new_control_sequence = 1;
            i = 1;
            while (1) {
                lua_rawgeti(L, 2, i);
                if (lua_type(L,3) == LUA_TSTRING) {
                    const char *prm = lua_tostring(L, 3);
                    str_number s = maketexstring(prm);
                    halfword prm_val = prim_lookup(s);
                    if (prm_val != undefined_primitive) {
                        char *newprm;
                        int val;
                        size_t newl;
                        halfword cur_cmd1 = get_prim_eq_type(prm_val);
                        halfword cur_chr1 = get_prim_equiv(prm_val);
                        if (strncmp(pre, prm, l) != 0) {       /* not a prefix */
                            newl = strlen(prm) + l;
                            newprm = (char *) malloc((unsigned) (newl + 1));
                            strcpy(newprm, pre);
                            strcat(newprm + l, prm);
                        } else {
                            newl = strlen(prm);
                            newprm = (char *) malloc((unsigned) (newl + 1));
                            strcpy(newprm, prm);
                        }
                        val = string_lookup(newprm, newl);
                        if (val == undefined_control_sequence || eq_type(val) == undefined_cs_cmd) {
                            primitive_def(newprm, newl, (quarterword) cur_cmd1, cur_chr1);
                        }
                        free(newprm);
                    }
                    flush_str(s);
                } else {
                    lua_pop(L, 1);
                    break;
                }
                lua_pop(L, 1);
                i++;
            }
            lua_pop(L, 1);      /* the table */
            no_new_control_sequence = nncs;
        } else {
            luaL_error(L, "Expected an array of names as second argument");
        }
    } else {
        luaL_error(L, "wrong number of arguments");
    }
    return 0;
}

# define get_int_par(A,B) do { \
    lua_key_rawgeti(A); \
    if (lua_type(L, -1) == LUA_TNUMBER) { \
        A = (int) lua_tointeger(L, -1); \
    } else { \
        A = (B); \
    } \
    lua_pop(L,1); \
} while (0)

# define get_intx_par(A,B,C,D)  do { \
    lua_key_rawgeti(A); \
    if (lua_type(L, -1) == LUA_TNUMBER) { \
        A = (int) lua_tointeger(L, -1); \
        C = null; \
    } else if (lua_type(L, -1) == LUA_TTABLE){ \
        A = 0; \
        C = nodelib_topenalties(L, lua_gettop(L)); \
    } else { \
        A = (B); \
        C = (D); \
    } \
    lua_pop(L,1); \
} while (0)

# define get_dimen_par(A,B)  do { \
    lua_key_rawgeti(A); \
    if (lua_type(L, -1) == LUA_TNUMBER) { \
        A = (int) lua_roundnumber(L, -1); \
    } else { \
        A = (B); \
    } \
    lua_pop(L,1); \
} while (0)

# define get_glue_par(A,B)  do { \
    lua_key_rawgeti(A); \
    if (lua_type(L, -1) != LUA_TNIL) { \
        A = *check_isnode(L, -1); \
    } else { \
        A = (B); \
    } \
    lua_pop(L,1); \
} while (0)

static halfword nodelib_toparshape(lua_State * L, int i)
{
    int n = 0;
    /* find |n| */
    lua_pushnil(L);
    while (lua_next(L, i) != 0) {
        n++;
        lua_pop(L, 1);
    }
    if (n > 0) {
        int j = 0;
        halfword p = new_node(shape_node, 2 * (n + 1) + 1);
        vinfo(p + 1) = n;
        /* fill |p| */
        lua_pushnil(L);
        while (lua_next(L, i) != 0) {
            /* don't give an error for non-tables, we may add special syntaxes at some point */
            j++;
            if (lua_type(L, i) == LUA_TTABLE) {
                lua_rawgeti(L, -1, 1);      /* indent */
                if (lua_type(L, -1) == LUA_TNUMBER) {
                    int indent = lua_roundnumber(L, -1);
                    lua_pop(L, 1);
                    lua_rawgeti(L, -1, 2);  /* width */
                    if (lua_type(L, -1) == LUA_TNUMBER) {
                        int width = lua_roundnumber(L, -1);
                        lua_pop(L, 1);
                        vvalue(p + 2 * j) = indent;
                        vvalue(p + 2 * j + 1) = width;
                    }
                }
            }
            lua_pop(L, 1);
        }
        return p;
    } else {
        return null;
    }
}

/*tex penalties */

static halfword nodelib_topenalties(lua_State * L, int i)
{
    int n = 0;
    lua_pushnil(L);
    while (lua_next(L, i) != 0) {
        n++;
        lua_pop(L, 1);
    }
    if (n > 0) {
        halfword p = new_node(shape_node, 2 * ((n / 2) + 1) + 1 + 1);
        int j = 2;
        vinfo(p + 1) = (n / 2) + 1;
        vvalue(p + 2) = n;
        lua_pushnil(L);
        while (lua_next(L, i) != 0) {
            j++;
            if (lua_type(L, -1) == LUA_TNUMBER) {
                int pen = lua_tointeger(L, -1);
                vvalue(p+j) = pen;
            }
            lua_pop(L, 1);
        }
        if (!odd(n)) {
            vvalue(p+j+1) = 0;
        }
        return p;
    } else {
        return null;
    }
}

static int tex_run_linebreak(lua_State * L)
{
    halfword *j;
    halfword p;
    halfword final_par_glue;
    int paragraph_dir = 0;
    /*tex locally initialized parameters for line breaking */
    int pretolerance, tracingparagraphs, tolerance, looseness,
        adjustspacing, adjdemerits, protrudechars,
        linepenalty, lastlinefit, doublehyphendemerits, finalhyphendemerits,
        hangafter, interlinepenalty, widowpenalty, clubpenalty, brokenpenalty;
    halfword emergencystretch, hangindent, hsize, leftskip, rightskip,parshape;
    int fewest_demerits = 0, actual_looseness = 0;
    halfword clubpenalties, interlinepenalties, widowpenalties;
    int save_vlink_tmp_head;
    /*tex push a new nest level */
    push_nest();
    save_vlink_tmp_head = vlink(temp_head);
    j = check_isnode(L, 1);     /* the value */
    vlink(temp_head) = *j;
    p = *j;
    if ((!is_char_node(vlink(*j))) && ((type(vlink(*j)) == local_par_node))) {
        paragraph_dir = local_par_dir(vlink(*j));
    }
    while (vlink(p) != null)
        p = vlink(p);
    final_par_glue = p;
    /*tex initialize local parameters */
    if (lua_gettop(L) != 2 || lua_type(L, 2) != LUA_TTABLE) {
        lua_checkstack(L, 3);
        lua_newtable(L);
    }
    lua_key_rawgeti(pardir);
    if (lua_type(L, -1) == LUA_TNUMBER) {
        paragraph_dir = checked_direction_value(lua_tointeger(L,-1));
    }
    lua_pop(L, 1);
    lua_key_rawgeti(parshape);
    if (lua_type(L, -1) == LUA_TTABLE) {
        parshape = nodelib_toparshape(L, lua_gettop(L));
    } else {
        parshape = equiv(par_shape_loc);
    }
    lua_pop(L, 1);
    get_int_par  (pretolerance, pretolerance_par);
    get_int_par  (tracingparagraphs, tracing_paragraphs_par);
    get_int_par  (tolerance, tolerance_par);
    get_int_par  (looseness, looseness_par);
    get_int_par  (adjustspacing, adjust_spacing_par);
    get_int_par  (adjdemerits, adj_demerits_par);
    get_int_par  (protrudechars, protrude_chars_par);
    get_int_par  (linepenalty, line_penalty_par);
    get_int_par  (lastlinefit, last_line_fit_par);
    get_int_par  (doublehyphendemerits, double_hyphen_demerits_par);
    get_int_par  (finalhyphendemerits, final_hyphen_demerits_par);
    get_int_par  (hangafter, hang_after_par);
    get_intx_par (interlinepenalty,inter_line_penalty_par, interlinepenalties, equiv(inter_line_penalties_loc));
    get_intx_par (clubpenalty, club_penalty_par, clubpenalties, equiv(club_penalties_loc));
    get_intx_par (widowpenalty, widow_penalty_par, widowpenalties, equiv(widow_penalties_loc));
    get_int_par  (brokenpenalty, broken_penalty_par);
    get_dimen_par(emergencystretch, emergency_stretch_par);
    get_dimen_par(hangindent, hang_indent_par);
    get_dimen_par(hsize, hsize_par);
    get_glue_par (leftskip, left_skip_par);
    get_glue_par (rightskip, right_skip_par);
    ext_do_line_break(
        paragraph_dir,
        pretolerance,
        tracingparagraphs,
        tolerance,
        emergencystretch,
        looseness,
        adjustspacing,
        parshape,
        adjdemerits,
        protrudechars,
        linepenalty,
        lastlinefit,
        doublehyphendemerits,
        finalhyphendemerits,
        hangindent,
        hsize,
        hangafter,
        leftskip,
        rightskip,
        interlinepenalties,
        interlinepenalty,
        clubpenalty,
        clubpenalties,
        widowpenalties,
        widowpenalty,
        brokenpenalty,
        final_par_glue
    );
    /*tex return the generated list, and its prevdepth */
    get_linebreak_info (&fewest_demerits, &actual_looseness) ;
    lua_nodelib_push_fast(L, vlink(cur_list.head_field));
    lua_newtable(L);
    lua_push_key(demerits);
    lua_pushinteger(L, fewest_demerits);
    lua_settable(L, -3);
    lua_push_key(looseness);
    lua_pushinteger(L, actual_looseness);
    lua_settable(L, -3);
    lua_push_key(prevdepth);
    lua_pushinteger(L, cur_list.prev_depth_field);
    lua_settable(L, -3);
    lua_push_key(prevgraf);
    lua_pushinteger(L, cur_list.pg_field);
    lua_settable(L, -3);
    /*tex restore nest stack */
    vlink(temp_head) = save_vlink_tmp_head;
    pop_nest();
    if (parshape != equiv(par_shape_loc))
        flush_node(parshape);
    return 2;
}

static int tex_reset_paragraph(lua_State * L)
{
    (void) L;
    normal_paragraph();
    return 0;
}

static int tex_shipout(lua_State * L)
{
    int boxnum = get_box_id(L, 1, 1);
    if (box(boxnum)) {
        flush_node_list(box(boxnum));
        box(boxnum) = null;
    }
    return 0;
}

static int tex_badness(lua_State * L)
{
    scaled t = lua_tointeger(L,1);
    scaled s = lua_tointeger(L,2);
    lua_pushinteger(L, badness(t,s));
    return 1;
}

static int tex_show_context(lua_State * L)
{
    (void) L;
    show_context();
    return 0;
}

static int tex_build_page(lua_State * L)
{
    (void) L;
    build_page();
    return 0;
}

static int lua_get_page_state(lua_State * L)
{
    lua_pushinteger(L,page_contents);
    return 1;
}

static int lua_get_local_level(lua_State * L)
{
    lua_pushinteger(L,current_local_level());
    return 1;
}

/* synctex */

static int lua_set_synctex_mode(lua_State * L)
{
    synctex_set_mode(lua_tointeger(L, 1));
    return 0;
}
static int lua_get_synctex_mode(lua_State * L)
{
    lua_pushinteger(L,synctex_get_mode());
    return 1;
}

static int lua_set_synctex_tag(lua_State * L)
{
    synctex_set_tag(lua_tointeger(L, 1));
    return 0;
}

static int lua_get_synctex_tag(lua_State * L)
{
    lua_pushinteger(L,synctex_get_tag());
    return 1;
}

static int lua_force_synctex_tag(lua_State * L)
{
    synctex_force_tag(lua_tointeger(L, 1););
    return 0;
}

static int lua_force_synctex_line(lua_State * L)
{
    synctex_force_line(lua_tointeger(L, 1));
    return 0;
}

static int lua_set_synctex_line(lua_State * L)
{
    synctex_set_line(lua_tointeger(L, 1));
    return 0;
}

static int lua_get_synctex_line(lua_State * L)
{
    lua_pushinteger(L,synctex_get_line());
    return 1;
}

static int lua_set_synctex_no_files(lua_State * L)
{
    synctex_set_no_files(lua_tointeger(L, 1));
    return 0;
}

/*tex
    This is experimental and might change. In version 10 we hope to have the
    final version available. It actually took quite a bit of time to understand
    the implications of mixing lua prints in here. The current variant is (so far)
    the most robust (wrt crashes and side effects).
*/

# define mode mode_par

/*tex
    When we add save levels then we can get crashes when one flushed bad
    groups due to out of order flushing. So we play safe! But still we can
    have issues so best make sure you're in hmode.
*/

static int forcehmode(lua_State * L)
{
    if (abs(mode) == vmode) {
        if (lua_type(L,1) == LUA_TBOOLEAN) {
            new_graf(lua_toboolean(L,1));
        } else {
            new_graf(1);
        }
    }
    return 0;
}

static int runtoks(lua_State * L)
{
    if (lua_type(L,1) == LUA_TFUNCTION) {
        int old_mode = mode;
        int ref;
        halfword r = get_avail();
        halfword t = get_avail();
        token_info(r) = token_val(end_local_cmd,0);
        lua_pushvalue(L, 1);
        ref = luaL_ref(L,LUA_REGISTRYINDEX);
        token_info(t) = token_val(lua_local_call_cmd, ref);
        begin_token_list(r,inserted);
        begin_token_list(t,inserted);
        if (luacstrings > 0) {
            lua_string_start();
        }
        if (tracing_nesting_par > 2) {
            local_control_message("entering token scanner via function");
        }
        mode = -hmode;
        local_control();
        mode = old_mode;
        luaL_unref(L,LUA_REGISTRYINDEX,ref);
    } else {
        int k = get_item_index(L, lua_gettop(L), toks_base);
        halfword t = toks(k);
        check_index_range(k, "gettoks");
        if (t != null) {
            int old_mode = mode;
            halfword r = get_avail();
            token_info(r) = token_val(end_local_cmd,0);
            begin_token_list(r,inserted);
            /* new_save_level(semi_simple_group); */
            begin_token_list(t,local_text);
            if (luacstrings > 0) {
                lua_string_start();
            }
            if (tracing_nesting_par > 2) {
                local_control_message("entering token scanner via register");
            }
            mode = -hmode;
            local_control();
            mode = old_mode;
            /* unsave(); */
        }
    }
    return 0;
}

/* new, can go into luatex too */

static int lua_set_math_dir(lua_State * L)
{
    set_math_dir(lua_tointeger(L,1));
    return 0;
}

static int lua_set_par_dir(lua_State * L)
{
    set_par_dir(lua_tointeger(L,1));
    return 0;
}

static int lua_set_text_dir(lua_State * L)
{
    set_text_dir(lua_tointeger(L,1));
    return 0;
}

static int lua_set_line_dir(lua_State * L)
{
    set_line_dir(lua_tointeger(L,1));
    return 0;
}

static int lua_set_box_dir(lua_State * L)
{
    int b = lua_tointeger(L,1);
    int d = lua_tointeger(L,2);
    check_index_range(b, "setboxdir");
    set_box_dir(b,d);
    return 0;
}

static int gethelptext(lua_State * L)
{
    if (error_state.help_text != NULL) {
        lua_pushstring(L,error_state.help_text);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int setinteraction(lua_State * L)
{
    if (lua_type(L,1) == LUA_TNUMBER) {
        int i = lua_tointeger(L,1);
        if (i >= 0 && i <= 3) {
            error_state.interaction = i;
        }
    }
    return 0;
}

static int getinteraction(lua_State * L)
{
    lua_pushinteger(L,error_state.interaction);
    return 1;
}

static int setglyphdata(lua_State * L)
{
    int a = 0;
    word_define(int_base+character_data_code, (halfword) luaL_optinteger(L,1,UNUSED_ATTRIBUTE));
    return 0;
}

static int getglyphdata(lua_State * L)
{
    lua_pushinteger(L,character_data_par);
    return 1;
}

static int lua_fatal_error(lua_State * L)
{
    const char *s = lua_tostring(L, 1);
    fatal_error(s);
    return 1;
}

/* */

/* till here */

static const struct luaL_Reg texlib[] = {
    { "write",                luacwrite },
    { "print",                luacprint },
    { "sprint",               luacsprint },
    { "tprint",               luactprint },
    { "cprint",               luaccprint },
    { "error",                texerror },
    { "set",                  settex },
    { "get",                  gettex },
    { "isdimen",              isdimen },
    { "setdimen",             setdimen },
    { "getdimen",             getdimen },
    { "isskip",               isskip },
    { "setskip",              setskip },
    { "getskip",              getskip },
    { "isglue",               isskip },
    { "setglue",              setglue },
    { "getglue",              getglue },
    { "ismuskip",             ismuskip },
    { "setmuskip",            setmuskip },
    { "getmuskip",            getmuskip },
    { "ismuglue",             ismuskip },
    { "setmuglue",            setmuglue },
    { "getmuglue",            getmuglue },
    { "isattribute",          isattribute },
    { "setattribute",         setattribute },
    { "getattribute",         getattribute },
    { "iscount",              iscount },
    { "setcount",             setcount },
    { "getcount",             getcount },
    { "istoks",               istoks },
    { "settoks",              settoks },
    { "scantoks",             scantoks },
    { "gettoks",              gettoks },
    { "isbox",                isbox },
    { "setbox",               setbox },
    { "getbox",               getbox },
    { "splitbox",             splitbox },
    { "setlist",              setlist },
    { "getlist",              getlist },
    { "setnest",              setnest }, /* only a message */
    { "getnest",              getnest },
    { "setcatcode",           setcatcode },
    { "getcatcode",           getcatcode },
    { "setdelcode",           setdelcode },
    { "getdelcode",           getdelcode },
    { "getdelcodes",          getdelcodes },
    { "setlccode",            setlccode },
    { "getlccode",            getlccode },
    { "setmathcode",          setmathcode },
    { "getmathcode",          getmathcode },
    { "getmathcodes",         getmathcodes },
    { "setsfcode",            setsfcode },
    { "getsfcode",            getsfcode },
    { "setuccode",            setuccode },
    { "getuccode",            getuccode },
    { "round",                tex_roundnumber },
    { "scale",                tex_scaletable },
    { "sp",                   tex_scaledimen },
    { "fontname",             getfontname },
    { "fontidentifier",       getfontidentifier },
    { "number",               getnumber },
    { "romannumeral",         getromannumeral },
    { "definefont",           tex_definefont },
    { "hashtokens",           tex_hashpairs },
    { "primitives",           tex_primitives },
    { "extraprimitives",      tex_extraprimitives },
    { "enableprimitives",     tex_enableprimitives },
    { "shipout",              tex_shipout },
    { "badness",              tex_badness },
    { "setmath",              tex_setmathparm },
    { "getmath",              tex_getmathparm },
    { "linebreak",            tex_run_linebreak },
    { "resetparagraph",       tex_reset_paragraph },
    { "show_context",         tex_show_context },
    { "triggerbuildpage",     tex_build_page },
    { "gethelptext",          gethelptext },
    { "getpagestate",         lua_get_page_state },
    { "getlocallevel",        lua_get_local_level },
    { "set_synctex_mode",     lua_set_synctex_mode },
    { "get_synctex_mode",     lua_get_synctex_mode },
    { "set_synctex_tag",      lua_set_synctex_tag },
    { "get_synctex_tag",      lua_get_synctex_tag },
    { "set_synctex_no_files", lua_set_synctex_no_files },
    { "force_synctex_tag",    lua_force_synctex_tag },
    { "force_synctex_line",   lua_force_synctex_line },
    { "set_synctex_line",     lua_set_synctex_line },
    { "get_synctex_line",     lua_get_synctex_line },
    { "runtoks",              runtoks },
    { "forcehmode",           forcehmode },
    { "settextdir",           lua_set_text_dir },
    { "setlinedir",           lua_set_line_dir },
    { "setmathdir",           lua_set_math_dir },
    { "setpardir",            lua_set_par_dir },
    { "setboxdir",            lua_set_box_dir },
    { "getinteraction",       getinteraction },
    { "setinteraction",       setinteraction },
    { "getglyphdata",         getglyphdata },
    { "setglyphdata",         setglyphdata },
    { "fatalerror",           lua_fatal_error },
    { NULL,                   NULL }
};

int luaopen_tex(lua_State * L)
{
    luac_initialize();
    /* */
    lua_newtable(L);
    luaL_setfuncs(L, texlib, 0);
    make_table(L, "attribute", "tex.attribute", "getattribute", "setattribute");
    make_table(L, "skip",      "tex.skip",      "getskip",      "setskip");
    make_table(L, "glue",      "tex.glue",      "getglue",      "setglue");
    make_table(L, "muskip",    "tex.muskip",    "getmuskip",    "setmuskip");
    make_table(L, "muglue",    "tex.muglue",    "getmuglue",    "setmuglue");
    make_table(L, "dimen",     "tex.dimen",     "getdimen",     "setdimen");
    make_table(L, "count",     "tex.count",     "getcount",     "setcount");
    make_table(L, "toks",      "tex.toks",      "gettoks",      "settoks");
    make_table(L, "box",       "tex.box",       "getbox",       "setbox");
    make_table(L, "sfcode",    "tex.sfcode",    "getsfcode",    "setsfcode");
    make_table(L, "lccode",    "tex.lccode",    "getlccode",    "setlccode");
    make_table(L, "uccode",    "tex.uccode",    "getuccode",    "setuccode");
    make_table(L, "catcode",   "tex.catcode",   "getcatcode",   "setcatcode");
    make_table(L, "mathcode",  "tex.mathcode",  "getmathcode",  "setmathcode");
    make_table(L, "delcode",   "tex.delcode",   "getdelcode",   "setdelcode");
    make_table(L, "lists",     "tex.lists",     "getlist",      "setlist");
    make_table(L, "nest",      "tex.nest",      "getnest",      "setnest");
    init_nest_lib(L);
    /*tex make the meta entries and fetch it back */
    luaL_newmetatable(L, "tex.meta");
    lua_pushstring(L, "__index");
    lua_pushcfunction(L, gettex);
    lua_settable(L, -3);
    lua_pushstring(L, "__newindex");
    lua_pushcfunction(L, settex);
    lua_settable(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}
