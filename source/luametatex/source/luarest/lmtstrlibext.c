/*
    See license.txt in the root of this project.
*/

/* todo: byteconcat and utf concat (no separator) */

/*tex

    The code below evolved over time. For instance the loop over \UTF\ came from the original
    \LUATEX\ code base. There are various ways to deal with \UTF\ and claims with respect to
    performance often don't really show off, also because over time compilers became very clever
    in optimizing. Take multiplication versus shifting ... it depends. Anyway, we occasionally
    come back to the code and improve it. Actually this is one of the areas where an \LLM\ comes
    in handy: identify a potential (!) bottleneck and come up with a commonly known variant that
    one can then try out. Because these are well defines small use cases, it might work out in
    out favor.

*/

# include "luametatex.h"
# include <limits.h>

# define max_format_precision (INT_MAX - 350)
# define max_nesting_depth    1000 /* nested tables, we need to stay within the C stack */

static inline int strlib_aux_parse_decimal(int value, int digit)
{
    if (value > (INT_MAX - digit) / 10) {
        return INT_MAX;
    } else {
        return value * 10 + digit;
    }
}

static inline int strlib_aux_normalize_precision(lua_Integer precision)
{
    if (precision <= 0) {
        return 0;
    } else if ((lua_Unsigned) precision > (lua_Unsigned) max_format_precision) {
        return max_format_precision;
    } else {
        return (int) precision;
    }
}

/*tex 
    Helpers. We do a bit more checking than needed; we know what goes in, but do it anyway. 
*/

static inline int strlib_aux_tounicode(const char *str, size_t len, size_t *pos)
{
    const unsigned char *s = (const unsigned char *) str;
    size_t start = *pos;
    if (start >= len) {
        return 0xFFFD;
    }
    unsigned char i         = s[start];
    size_t        required  = 0;
    size_t        total_len = 1;
    int           codepoint = 0;
    if (i < 0x80) {
        *pos = start + 1;
        return i;
    } else if (i >= 0xC0 && i <= 0xDF) {
        required  = 1;
        total_len = 2;
        codepoint = i & 0x1F;
    } else if (i >= 0xE0 && i <= 0xEF) {
        required  = 2;
        total_len = 3;
        codepoint = i & 0x0F;
    } else if (i >= 0xF0 && i <= 0xF4) {
        required  = 3;
        total_len = 4;
        codepoint = i & 0x07;
    } else {
        /* invalid lead byte (e.g., 0xF5-0xFF or raw continuation bytes 0x80-0xBF) */
        *pos = start + 1;
        return 0xFFFD;
    }
    /* check if the string ends prematurely before the sequence completes */
    if (start + total_len > len) {
        *pos = start + 1;
        return 0xFFFD;
    }
    /* validate continuation bytes and check for overlong/invalid encodings */
    if (required == 1) {
        unsigned char j = s[start + 1];
        if ((j & 0xC0) == 0x80 && i >= 0xC2) { /* i >= 0xC2 rejects overlong 0xC0, 0xC1 */
            *pos = start + 2;
            return codepoint << 6 | (j & 0x3F);
        }
    } else if (required == 2) {
        unsigned char j = s[start + 1];
        unsigned char k = s[start + 2];
        if ((j & 0xC0) == 0x80 && (k & 0xC0) == 0x80) {
            /* reject overlong (E0 0x80-0x9F) and surrogate halves (ED 0xA0-0xBF) */
            if (!((i == 0xE0 && j < 0xA0) || (i == 0xED && j >= 0xA0))) {
                int cp = (codepoint << 12) | ((j & 0x3F) << 6) | (k & 0x3F);
                *pos = start + 3;
                return cp;
            }
        }
    } else if (required == 3) {
        unsigned char j = s[start + 1];
        unsigned char k = s[start + 2];
        unsigned char l = s[start + 3];
        if ((j & 0xC0) == 0x80 && (k & 0xC0) == 0x80 && (l & 0xC0) == 0x80) {
            /* reject out-of-range (> 0x10FFFF) */
            if (!((i == 0xF0 && j < 0x90) || (i == 0xF4 && j > 0x8F))) {
                int cp = (codepoint << 18) | ((j & 0x3F) << 12) | ((k & 0x3F) << 6) | (l & 0x3F);
                *pos = start + 4;
                return cp;
            }
        }
    }
    /* validation failed: only consume the lead byte so that we don't swallow valid characters */
    *pos = start + 1;
    return 0xFFFD;
}

static inline size_t strlib_aux_toline(const char *s, size_t l, size_t p, size_t *b)
{
    size_t i = p;
    *b = 0;
    while (i < l) {
        char c = s[i];
        if (c == '\r') {
            if (i + 1 < l && s[i + 1] == '\n') {
                *b = 2; /* cr lf */
            } else {
                *b = 1; /* cr */
            }
            return i - p;
        } else if (c == '\n') {
            *b = 1;     /* lf */
            return i - p;
        }
        i++;
    }
    /* end of buffer */
    return i - p;
}

/*tex End of helpers. */

static int strlib_aux_bytepairs(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
    if (ind < ls) {
        unsigned char i;
        /*tex iterator */
        if (ind + 1 < ls) {
            lua_pushinteger(L, ind + 2);
        } else {
            lua_pushinteger(L, ind + 1);
        }
        lua_replace(L, lua_upvalueindex(2));
        i = (unsigned char)*(s + ind);
        /*tex byte one */
        lua_pushinteger(L, i);
        if (ind + 1 < ls) {
            /*tex byte two */
            i = (unsigned char)*(s + ind + 1);
            lua_pushinteger(L, i);
        } else {
            /*tex odd string length */
            lua_pushnil(L);
        }
        return 2;
    } else {
        return 0;
    }
}

static int strlib_bytepairs(lua_State *L)
{
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, strlib_aux_bytepairs, 2);
    return 1;
}

static int strlib_aux_bytes(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
    if (ind < ls) {
        /*tex iterator */
        lua_pushinteger(L, ind + 1);
        lua_replace(L, lua_upvalueindex(2));
        /*tex byte */
        lua_pushinteger(L, (unsigned char)*(s + ind));
        return 1;
    } else {
        return 0;
    }
}

static int strlib_bytes(lua_State *L)
{
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, strlib_aux_bytes, 2);
    return 1;
}

static int strlib_aux_utf_failed(lua_State *L, int new_ind)
{
    lua_pushinteger(L, new_ind);
    lua_replace(L, lua_upvalueindex(2));
    lua_pushliteral(L, utf_fffd_string);
    return 1;
}

/* kind of complex ... these masks */

// static int strlib_aux_utfcharacters(lua_State *L)
// {
//     static const unsigned char mask[4] = { 0x80, 0xE0, 0xF0, 0xF8 };
//     static const unsigned char mequ[4] = { 0x00, 0xC0, 0xE0, 0xF0 };
//     size_t ls = 0;
//     const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
//     size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
//     size_t l = ls;
//     if (ind >= l) {
//         return 0;
//     } else {
//         unsigned char c = (unsigned char) s[ind];
//         for (size_t j = 0; j < 4; j++) {
//             if ((c & mask[j]) == mequ[j]) {
//                 if (ind + 1 + j > l) {
//                     /*tex The result will not fit. */
//                     return strlib_aux_utf_failed(L, (int) l);
//                 }
//                 for (size_t k = 1; k <= j; k++) {
//                     c = (unsigned char) s[ind + k];
//                     if ((c & 0xC0) != 0x80) {
//                         /*tex We have a bad follow byte. */
//                         return strlib_aux_utf_failed(L, (int) (ind + k));
//                     }
//                 }
//                 /*tex The iterator. */
//                 lua_pushinteger(L, ind + j + 1);
//                 lua_replace(L, lua_upvalueindex(2));
//                 lua_pushlstring(L, ind + s, j + 1);
//                 return 1;
//             }
//         }
//         return strlib_aux_utf_failed(L, (int) (ind + 1)); /* we found a follow byte! */
//     }
// }

/*tex
    Based on the above the gemini-in-browser \LLM\ suggested the following variant, but here we
    have a branche instead.
*/

// static int strlib_aux_utfcharacters(lua_State *L)
// {
//     size_t ls = 0;
//     const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
//     size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
//     if (ind >= ls) {
//         return 0;
//     } else {
//         unsigned char c = (unsigned char) s[ind];
//         size_t len;
//         if (c < 0x80) {
//             len = 1;
//         } else if (c >= 0xC0 && c < 0xE0) {
//             len = 2;
//         } else if (c >= 0xE0 && c < 0xF0) {
//             len = 3;
//         } else if (c >= 0xF0 && c < 0xF8) {
//             len = 4;
//         } else {
//             return strlib_aux_utf_failed(L, (int)(ind + 1));
//         }
//         if (ind + len > ls) {
//             /*tex The result will not fit. */
//             return strlib_aux_utf_failed(L, (int)ls);
//         }
//         for (size_t k = 1; k < len; k++) {
//             if (((unsigned char) s[ind + k] & 0xC0) != 0x80) {
//                 /*tex We have a bad follow byte. */
//                 return strlib_aux_utf_failed(L, (int) (ind + k));
//             }
//         }
//         lua_pushinteger(L, ind + len);
//         lua_replace(L, lua_upvalueindex(2));
//         lua_pushlstring(L, s + ind, len);
//         return 1;
//     }
// }

/*tex
    So, when pressed a bit for avoiding this like the original, it cooked up the following, which
    probably is the way to go on modern \CPU's. It is a nice limited case so relatively easy to
    check (which is really needed!). The basic setup is still the same as we had.
*/

/*tex
    And when asked about the if's it then went (slightly adapted afterwards). But we might as well
    consult the competition as this seems to be a common approach.
*/

static int strlib_aux_utfcharacters(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    size_t ind = (size_t) lmt_tointeger(L, lua_upvalueindex(2));
    if (ind >= ls) {
        return 0;
    } else {
        size_t next = ind;
        int codepoint = strlib_aux_tounicode(s, ls, &next);
        if (codepoint == 0xFFFD) {
            return strlib_aux_utf_failed(L, (int) next);
        }
        lua_pushinteger(L, next);
        lua_replace(L, lua_upvalueindex(2));
        lua_pushlstring(L, s + ind, next - ind);
        return 1;
    }
}

static int strlib_utfcharacters(lua_State *L)
{
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, strlib_aux_utfcharacters, 2);
    return 1;
}

static int strlib_aux_utfvalues(lua_State *L)
{
    size_t l = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &l);
    size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
    if (ind < l) {
        int v = strlib_aux_tounicode(s, l, &ind);
        lua_pushinteger(L, ind);
        lua_replace(L, lua_upvalueindex(2));
        lua_pushinteger(L, v);
        return 1;
    } else {
        return 0;
    }
}

static int strlib_utfvalues(lua_State *L)
{
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, strlib_aux_utfvalues, 2);
    return 1;
}

static int strlib_aux_characterpairs(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
    if (ind < ls) {
        char b[1];
        lua_pushinteger(L, ind + 2); /*tex So we can overshoot ls here. */
        lua_replace(L, lua_upvalueindex(2));
        b[0] = s[ind];
        lua_pushlstring(L, b, 1);
        if ((ind + 1) < ls) {
            b[0] = s[ind + 1];
            lua_pushlstring(L, b, 1);
        } else {
            lua_pushliteral(L, "");
        }
        return 2;
    } else {
        return 0;  /* string ended */
    }
}

static int strlib_characterpairs(lua_State *L)
{
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, strlib_aux_characterpairs, 2);
    return 1;
}

static int strlib_aux_characters(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
    if (ind < ls) {
        char b[1];
        lua_pushinteger(L, ind + 1); /* iterator */
        lua_replace(L, lua_upvalueindex(2));
        b[0] = *(s + ind);
        lua_pushlstring(L, b, 1);
        return 1;
    } else {
        return 0;  /* string ended */
    }
}

static int strlib_characters(lua_State *L)
{
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, strlib_aux_characters, 2);
    return 1;
}

static int strlib_bytetable(lua_State *L)
{
    size_t l;
    const char *s = luaL_checklstring(L, 1, &l);
    lua_createtable(L, (int) l, 0);
    for (size_t i = 0; i < l; i++) {
        lua_pushinteger(L, (unsigned char)*(s + i));
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

static int strlib_utfvaluetable(lua_State *L)
{
    size_t n = 1;
    size_t l = 0;
    size_t p = 0;
    const char *s = luaL_checklstring(L, 1, &l);
    lua_createtable(L, (int) l, 0);
    while (p < l) {
        lua_pushinteger(L, strlib_aux_tounicode(s, l, &p));
        lua_rawseti(L, -2, n++);
    }
    return 1;
}

static int strlib_utfcharactertable(lua_State *L)
{
    size_t n = 1;
    size_t l = 0;
    size_t p = 0;
    const char *s = luaL_checklstring(L, 1, &l);
    lua_createtable(L, (int) l, 0);
    while (p < l) {
        size_t next = p;
        int cp = strlib_aux_tounicode(s, l, &next);
        if (next <= p) {
            next = p + 1;
        }
        /* Emit U+FFFD if decoding failed, unless it's a literal U+FFFD string in the source */
        if (cp == 0xFFFD && !(next - p == 3 && (unsigned char)s[p] == 0xEF && (unsigned char)s[p+1] == 0xBF && (unsigned char)s[p+2] == 0xBD)) {
            lua_pushliteral(L, utf_fffd_string);
        } else {
            lua_pushlstring(L, s + p, next - p);
        }
        p = next;
        lua_rawseti(L, -2, n++);
    }
    return 1;
}

static int strlib_linetable(lua_State *L)
{
    size_t n = 1;
    size_t l = 0;
    size_t p = 0;
    const char *s = luaL_checklstring(L, 1, &l);
    lua_createtable(L, (int) l, 0);
    while (p < l) {
        size_t b = 0;
        size_t m = strlib_aux_toline(s, l, p, &b);
        if (m) {
            lua_pushlstring(L, s + p, m);
        } else {
            lua_pushliteral(L, "");
        }
        p += m + b;
        lua_rawseti(L, -2, n++);
    }
    return 1;
}

/*tex

    In \LUATEX\ we have \type {slunicode} but in \CONTEXT\ we rather early decided not to use
    it because we needed more detail. There all happened in a dedicated \type {utf8} module that
    has a rather good performance anyway. In \LUAMETATEX\ we introduced some helpers; there
    actually is all kind of \UTF\ code spread over the code base, depending on needs. Keep in
    mind that in the end little \UTF\ is needed because when for instance we resolve \type
    {\csname}'s string mostly contain \ASCII\ as do macro files, \LUA\ files and \METAPOST.

*/

# define MAXUNICODE 0x10FFFF

/*tex
    This is a quick and dirty, no checking done variant. We use a \LUA\ buffer which comes at
    a price.
*/

static inline void strlib_aux_add_utfchar(luaL_Buffer *b, unsigned u)
{
    if (u <= MAXUNICODE && (u < 0xD800 || u > 0xDFFF)) {
        if (0x80 > u) {
            luaL_addchar(b, (unsigned char) u);
        } else {
            if (0x800 > u)
                luaL_addchar(b, (unsigned char) (0xC0 | (u >> 6)));
            else {
                if (0x10000 > u)
                    luaL_addchar(b, (unsigned char) (0xE0 | (u >> 12)));
                else {
                    luaL_addchar(b, (unsigned char) (0xF0 | (u >> 18)));
                    luaL_addchar(b, (unsigned char) (0x80 | (0x3F & (u >> 12))));
                }
                luaL_addchar(b, 0x80 | (0x3F & (u >> 6)));
            }
            luaL_addchar(b, 0x80 | (0x3F & u));
        }
    }
}

static inline void strlib_aux_add_utfnumber(lua_State *L, luaL_Buffer *b, int index)
{
    strlib_aux_add_utfchar(b, (unsigned) lmt_tounsigned(L, index));
}

/*tex
    When we loop over a table we push its elements, which is not permitted when a \LUA\ buffer has
    to grow because then it expects a balanced stack. So we first determine the (maximum) size and
    then fill a buffer of that size directly. Code points are handled as in the single character
    case.
*/

static size_t strlib_aux_utf_collect(lua_State *L, int index, char *s, size_t size, int depth)
{
    size_t n = 0;
    switch (lua_type(L, index)) {
        case LUA_TNUMBER:
            if (! s) {
                n = 4;
            } else if (size >= 4) {
                n = (size_t) (aux_uni2string(s, (unsigned) lmt_tounsigned(L, index)) - s);
            }
            break;
        case LUA_TSTRING:
            {
                size_t l = 0;
                const char *str = lua_tolstring(L, index, &l);
                if (! s) {
                    n = l;
                } else if (l <= size) {
                    memcpy(s, str, l);
                    n = l;
                }
                break;
            }
        case LUA_TTABLE:
            if (depth < max_nesting_depth && lua_checkstack(L, 1)) {
                lua_Unsigned m = lua_rawlen(L, index);
                for (lua_Unsigned i = 1; i <= m; i++) {
                    lua_rawgeti(L, index, (lua_Integer) i);
                    n += strlib_aux_utf_collect(L, lua_gettop(L), s ? s + n : NULL, s ? size - n : 0, depth + 1);
                    lua_pop(L, 1);
                }
            }
            break;
    }
    return n;
}

static int strlib_utfcharacter(lua_State *L)
{
    int n = lua_gettop(L);
    if (n == 1 && lua_type(L, 1) == LUA_TNUMBER) {
        char u[6];
        char *c = aux_uni2string(&u[0], (unsigned) lua_tointeger(L, 1));
        *c = '\0';
        lua_pushstring(L, u);
        return 1;
    } else {
        luaL_Buffer b;
        size_t size = 0;
        size_t length = 0;
        for (int i = 1; i <= n; i++) {
            size += strlib_aux_utf_collect(L, i, NULL, 0, 0);
        }
        char *s = luaL_buffinitsize(L, &b, size);
        for (int i = 1; i <= n; i++) {
            length += strlib_aux_utf_collect(L, i, s + length, size - length, 0);
        }
        luaL_pushresultsize(&b, length);
        return 1;
    }
}

/*tex

    The \UTF8 code point function takes two arguments, being positions in the string, while slunicode
    byte takes two arguments representing the number of \UTF\ characters. The variant below always
    returns all code points.

*/

static int strlib_utfvalue(lua_State *L)
{
    size_t l = 0;
    size_t p = 0;
    int i = 0;
    const char *s = luaL_checklstring(L, 1, &l);
    /* we return each code point, so (as in |utf8.codepoint|) we need room on the stack */
    if (l >= INT_MAX) {
        return luaL_error(L, "string too long");
    }
    luaL_checkstack(L, (int) l, "string too long");
    while (p < l) {
        lua_pushinteger(L, strlib_aux_tounicode(s, l, &p));
        i++;
    }
    return i;
}

/*tex
    This one uses the same shift based few \CPU\ cycle length trick as above. It does
    a bit more checking so that likely kills the gain.
*/

static int strlib_utflength(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, 1, &ls);
    size_t ind = 0;
    size_t n = 0;
    while (ind < ls) {
        size_t next = ind;
        strlib_aux_tounicode(s, ls, &next);
        if (next <= ind) {
            next = ind + 1;
        }
        ind = next;
        n++;
    }
    lua_pushinteger(L, (lua_Integer) n);
    return 1;
}

/*tex
    This one is uses quite a bit in \CONTEXT\ and it formats a float where it strips trailing zeros;
    it also checks for zeros and ones. It started out as \LUA\ code but we wanted a bit more
    performance. We mostly use it with six digits precision but occasionally we go for nine
    digits.
*/

# include <inttypes.h>

/*tex
    A user format has to be a single floating point specifier, like |%.3f|, so no literal text,
    no |*| and no length modifiers: we pass a double and want to get just a number.
*/

static inline int strlib_aux_valid_f6_format(const char *f)
{
    if (*f++ != '%') {
        return 0;
    }
    while (*f && strchr("-+ #0", *f)) {
        f++;
    }
    for (int d = 0; d < 3 && *f >= '0' && *f <= '9'; d++) {
        f++;
    }
    if (*f == '.') {
        f++;
        for (int d = 0; d < 3 && *f >= '0' && *f <= '9'; d++) {
            f++;
        }
    }
    return *f && strchr("fFeEgG", *f) && ! f[1];
}

static int strlib_format_f6(lua_State *L)
{
    double n = luaL_optnumber(L, 1, 0.0);
    if (n == 0.0) {
        lua_pushliteral(L, "0");
        return 1;
    } else if (n == 1.0) {
        lua_pushliteral(L, "1");
        return 1;
    } else {
        char s[512];
        int len;
        /* do we have an integer within 53-bit float precision */
        if (fmod(n, 1.0) == 0.0 && n >= -9007199254740992.0 && n <= 9007199254740992.0) {
            len = snprintf(s, sizeof(s), "%" PRId64, (int64_t) n);
            lua_pushlstring(L, s, (size_t) len);
            return 1;
        }
        /* default format */
        const char *fmt = "%.6f";
        if (lua_type(L, 2) == LUA_TSTRING) {
            const char *user_fmt = lua_tostring(L, 2);
            if (strlib_aux_valid_f6_format(user_fmt)) {
                fmt = user_fmt;
            }
        }
        len = snprintf(s, sizeof(s), fmt, n);
        if (len <= 0 || len >= (int) sizeof(s)) {
            /* a user format can be too wide but the default always fits */
            len = snprintf(s, sizeof(s), "%.6f", n);
        }
        /* remove trailing zeros after decimal point, respecting exponents if present */
        char *dot = strchr(s, '.');
        if (dot) {
            char *exp_ptr = strpbrk(s, "eE");
            char *ptr = exp_ptr ? (exp_ptr - 1) : (s + len - 1);
            
            while (ptr > dot && *ptr == '0') {
                ptr--;
            }
            if (ptr == dot) {
                ptr--;
            }   
            if (exp_ptr) {
                size_t mantissa_len = (size_t) (ptr - s + 1);
                size_t exp_len = strlen(exp_ptr);
                memmove(s + mantissa_len, exp_ptr, exp_len + 1);
                len = (int) (mantissa_len + exp_len);
            } else {
                len = (int) (ptr - s + 1);
                s[len] = '\0';
            }
        }       
        lua_pushlstring(L, s, (size_t) len);
        return 1;
    }
}

static int strlib_format_g6(lua_State *L)
{
    double n = luaL_optnumber(L, 1, 0.0);
    if (n == 0.0) {
        lua_pushliteral(L, "0");
        return 1;
    } else if (n == 1.0) {
        lua_pushliteral(L, "1");
        return 1;
    } else {
        char s[128];
        /* Fast path: 53-bit exact integers */
        if (fmod(n, 1.0) == 0.0 && n >= -9007199254740992.0 && n <= 9007199254740992.0) {
            int len = snprintf(s, sizeof(s), "%" PRId64, (int64_t) n);
            lua_pushlstring(L, s, (size_t) len);
            return 1;
        }
        /* Standard custom double-to-string conversion (handles exponential notation & trimming deterministically) */
        int len = double_to_string_g(n, s, 6);
        lua_pushlstring(L, s, (size_t) len);
        return 1;
    }
}

static int strlib_format_fd(lua_State *L)
{
    double n = luaL_optnumber(L, 1, 0.0);
    int    m = strlib_aux_normalize_precision(luaL_optinteger(L, 2, 6));
    if (n == 0.0) {
        lua_pushliteral(L, "0");
        return 1;
    } else if (n == 1.0) {
        lua_pushliteral(L, "1");
        return 1;
    } else {
        char str[512]; /* Safe capacity for large doubles */
        int len = double_to_string_f(n, str, m);
        if (len < 0 || len >= (int) sizeof(str)) {
            len = (int) sizeof(str) - 1;
            str[len] = '\0';
        }
        lua_pushlstring(L, str, (size_t) len);
        return 1;
    }
}

static inline int strlib_format_fdn(lua_State *L, int m)
{
    double n = luaL_optnumber(L, 1, 0.0);
    if (n == 0.0) {
        lua_pushliteral(L, "0");
        return 1;
    } else if (n == 1.0) {
        lua_pushliteral(L, "1");
        return 1;
    } else {
        char str[512];
        int len = double_to_string_f(n, str, m);
        if (len < 0 || len >= (int) sizeof(str)) {
            len = (int) sizeof(str) - 1;
            str[len] = '\0';
        }
        lua_pushlstring(L, str, (size_t) len);
        return 1;
    }
}

static int strlib_format_fd3(lua_State *L) { return strlib_format_fdn(L, 3); }
static int strlib_format_fd6(lua_State *L) { return strlib_format_fdn(L, 6); }
static int strlib_format_fd9(lua_State *L) { return strlib_format_fdn(L, 9); }

static int strlib_format_gd(lua_State *L)
{
    double n = luaL_optnumber(L, 1, 0.0);
    int    m = strlib_aux_normalize_precision(luaL_optinteger(L, 2, 6));
    if (n == 0.0) {
        lua_pushliteral(L, "0");
        return 1;
    } else if (n == 1.0) {
        lua_pushliteral(L, "1");
        return 1;
    } else {
        char str[512];
        int len = double_to_string_g(n, str, m);
        if (len < 0 || len >= (int) sizeof(str)) {
            len = (int) sizeof(str) - 1;
            str[len] = '\0';
        }
        lua_pushlstring(L, str, (size_t) len);
        return 1;
    }
}

/*tex
    The next one is mostly provided as check because doing it in pure \LUA\ is not slower and it's
    not a bottleneck anyway. There are some subtle side effects when we don't check for these ranges,
    especially the trigger bytes (|0xD7FF| etc.) because we can get negative numbers which means
    wrapping around and such.
*/

# if 1

    /* We don't want these in tounicode vectors: */

    static inline int invalid_unicode(lua_Integer u)
    {
        return
           (u >= 0x00E000 && u <= 0x00F8FF)
        || (u >= 0x0F0000 && u <= 0x0FFFFF)
        || (u >= 0x100000 && u <= 0x10FFFF)
        || (u >= 0x00D800 && u <= 0x00DFFF)
        || (u >= 0x00D7FF && u <= 0x00DFFF)
        || (u >  0x10FFFF);
    }

# else

    /* But officially it is: surrogates, non-characters, out-of-bounds */

    static inline int invalid_unicode(lua_Integer u)
    {
        return
            (u >= 0x00E000 && u <= 0x00F8FF)
         || (u >= 0x00D800 && u <= 0x00DFFF)
         || (u >  0x10FFFF);
    }

# endif

static const char hex_upper[] = "0123456789ABCDEF";
static const char hex_lower[] = "0123456789abcdef";

static inline void write_hex16(char *s, unsigned int val)
{
    s[0] = hex_upper[(val >> 12) & 0xF];
    s[1] = hex_upper[(val >> 8)  & 0xF];
    s[2] = hex_upper[(val >> 4)  & 0xF];
    s[3] = hex_upper[ val        & 0xF];
}

// static int strlib_tounicode16(lua_State *L)
// {
//     lua_Integer u = lua_tointeger(L, 1);   
//     if (u < 0 || u > MAXUNICODE || invalid_unicode(u)) {
//         lua_pushliteral(L, "FFFD");
//     } else if (u <= 0xFFFF) {
//         /* basic multilingual plane: single 16-bit word */
//         char s[4];
//         write_hex16(s, (unsigned int) u);
//         lua_pushlstring(L, s, 4);
//     } else {
//         /* supplementary planes (U+10000 .. U+10FFFF): UTF-16 surrogate pair */
//         char s[8];
//         unsigned int v = (unsigned int) (u - 0x10000);
//         unsigned int u1 = (v >> 10)   + 0xD800; /* high surrogate */
//         unsigned int u2 = (v & 0x3FF) + 0xDC00; /* low  surrogate */
//         write_hex16(s, u1);
//         write_hex16(s + 4, u2);
//         lua_pushlstring(L, s, 8);
//     }
//     return 1;
// }

/*tex 

    When porting the \LUA\ variant we combined three functions in one and handle for instance 
    negative numbers better. 

*/

static inline size_t strlib_aux_tounicode16_chars(lua_Integer u, char *s)
{
    if (u < 0 || u > MAXUNICODE || invalid_unicode(u)) {
        memcpy(s, "FFFD", 4);
        return 4;
    } else if (u <= 0xFFFF) {
        /* basic multilingual plane: single 16-bit word */
        write_hex16(s, (unsigned int) u);
        return 4;
    } else {
        /* supplementary planes (U+10000 .. U+10FFFF): UTF-16 surrogate pair */
        unsigned int v  = (unsigned int) (u - 0x10000);
        unsigned int u1 = (v >> 10)   + 0xD800; /* high surrogate */
        unsigned int u2 = (v & 0x3FF) + 0xDC00; /* low  surrogate */
        write_hex16(s, u1);
        write_hex16(s + 4, u2);
        return 8;
    }
}

static inline void strlib_aux_add_tounicode16(luaL_Buffer *b, lua_Integer u)
{
    char str[8];
    size_t len = strlib_aux_tounicode16_chars(u, str);
    luaL_addlstring(b, str, len);
}

inline static void strlib_aux_tounicode16_collect(lua_State *L, int index, luaL_Buffer *b, int depth)
{
    switch (lua_type(L, index)) {
        case LUA_TNUMBER:
            strlib_aux_add_tounicode16(b, lua_tointeger(L, index));
            break;
        case LUA_TTABLE:
            if (depth < max_nesting_depth && lua_checkstack(L, 1)) {
                lua_Unsigned n = lua_rawlen(L, index);
                for (lua_Unsigned i = 1; i <= n; i++) {
                    lua_rawgeti(L, index, (lua_Integer) i);
                    strlib_aux_tounicode16_collect(L, lua_gettop(L), b, depth + 1);
                    lua_pop(L, 1);
                }
            }
            break;
        default:
            luaL_addlstring(b, "FFFD", 4);
            break;
    }
}

static int strlib_tounicode16(lua_State *L)
{
    int n = lua_gettop(L);
    if (n == 1 && lua_type(L, 1) == LUA_TNUMBER) {
        char s[8];
        size_t len = strlib_aux_tounicode16_chars(lua_tointeger(L, 1), s);
        lua_pushlstring(L, s, len);
        return 1;
    } else {
        luaL_Buffer b;
        luaL_buffinitsize(L, &b, (size_t) (n > 0 ? n : 1) * 8);
        for (int i = 1; i <= n; i++) {
            strlib_aux_tounicode16_collect(L, i, &b, 0);
        }
        luaL_pushresult(&b);
        return 1;
    }
}

/*tex 
    This converts a hex string to characters. Spacing is ignored and invalid characters result in 
    a false result. Empty strings are okay. Originally we assumed \type {XX XX XX} and just skipped
    single ones but we might as well also handle \type {X X X}. This code is not that critical and
    was introduced when we wanted flexible bitmap definition in \METAPOST\ and \LUA\ as part of the
    \type {potrace} experiments.

    Previous (less efficient) implementations can be found in the git history (luametatex and
    context). Here we use a 256-byte lookup table for hex decoding but of course it comes at a
    memory price (we use shorts as suggested by gemini):

    - 0 .. 15 : valid hex nibbles
    - 256     : whitespace (skip)
    - 257     : invalid character / failure

    It's anyway a nice example of a variant, given the usual reformatting and a bit of
    cleaning up. We need the table a few times. 
*/

static const unsigned short strlib_hex_table[256] = {
    /* 0x00 - 0x1F: control characters \t \n \r are valid spacing */
    257,257,257,257,257,257,257,257,257,256,256,257,257,256,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    /* 0x20 - 0x2F: ' ' is valid spacing */
    256,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    /* 0x30 - 0x39: digits '0'-'9' (0 .. 9) */
    0,    1,  2,  3,  4,  5,  6,  7,  8,  9,257,257,257,257,257,257,
    /* 0x40 - 0x4F: uppercase 'A'-'F' (10 .. 15) */
    257, 10, 11, 12, 13, 14, 15,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    /* 0x60 - 0x6F: lowercase 'a'-'f' (10 .. 15) */
    257, 10, 11, 12, 13, 14, 15,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    /* 0x80 - 0xFF: high ASCII / non ASCII (all invalid) */
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
    257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,257,
};

/*tex 
    
    Contrary to the original \LUA\ variant we return multiple code points but our normal use case
    is still a single one. Checking is a bit more aggressive (thank you, internet).

*/

static inline int strlib_aux_from_hex_4(const char *s)
{
    unsigned short h0 = strlib_hex_table[(unsigned char) s[0]];
    unsigned short h1 = strlib_hex_table[(unsigned char) s[1]];
    unsigned short h2 = strlib_hex_table[(unsigned char) s[2]];
    unsigned short h3 = strlib_hex_table[(unsigned char) s[3]];
    if (h0 >= 16 || h1 >= 16 || h2 >= 16 || h3 >= 16) {
        return -1;
    }
    return (int) ((h0 << 12) | (h1 << 8) | (h2 << 4) | h3);
}

static int strlib_fromunicode16(lua_State *L)
{
    size_t      len = 0;
    const char *str = luaL_checklstring(L, 1, &len);
    /* ensure multiple of 4 trick: cutoff */
    len &= ~(size_t) 3;
    if (len == 0) {
        return 0;
    } else if (len >= INT_MAX) {
        return luaL_error(L, "string too long");
    }
    luaL_checkstack(L, (int) (len / 4), "string too long");
    size_t i     = 0;
    int    count = 0;
    unsigned int high_surrogate = 0;
    while (i < len) {
        int word = strlib_aux_from_hex_4(str + i);
        i += 4;
        if (word < 0) {
            if (high_surrogate) {
                lua_pushinteger(L, 0xFFFD);
                count++;
                high_surrogate = 0;
            }
            lua_pushinteger(L, 0xFFFD);
            count++;
            continue;
        }
        if (high_surrogate) {
            if (word >= 0xDC00 && word <= 0xDFFF) {
                unsigned int cp = 0x10000 + (((high_surrogate & 0x3FF) << 10) | (word & 0x3FF));
                lua_pushinteger(L, (lua_Integer) cp);
                count++;
                high_surrogate = 0;
                continue;
            } else {
                lua_pushinteger(L, 0xFFFD);
                count++;
                high_surrogate = 0;
            }
        }
        if (word >= 0xD800 && word <= 0xDBFF) {
            high_surrogate = (unsigned int) word;
        } else if (word >= 0xDC00 && word <= 0xDFFF) {
            lua_pushinteger(L, 0xFFFD);
            count++;
        } else {
            lua_pushinteger(L, (lua_Integer) word);
            count++;
        }
    }
    if (high_surrogate) {
        lua_pushinteger(L, 0xFFFD);
        count++;
    }
    return count;
}

/* */

static int strlib_format_toutf8(lua_State *L) /* could be integrated into utfcharacter */
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            luaL_Buffer b;
            luaL_buffinitsize(L, &b, (n + 1) * 4);
            for (lua_Integer i = 1; i <= n; i++) {
                /* there should be one operation for getting a number from a table */
                if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                    unsigned u = (unsigned) lua_tointeger(L, -1);
                    if (0x80 > u) {
                        luaL_addchar(&b, (unsigned char) u);
                    } else if (invalid_unicode(u)) {
                        luaL_addchar(&b, 0xEF);
                        luaL_addchar(&b, 0xBF);
                        luaL_addchar(&b, 0xBD);
                    } else {
                        if (0x800 > u)
                            luaL_addchar(&b, (unsigned char) (0xC0 | (u >> 6)));
                        else {
                            if (0x10000 > u)
                                luaL_addchar(&b, (unsigned char) (0xE0 | (u >> 12)));
                            else {
                                luaL_addchar(&b, (unsigned char) (0xF0 | (u >>18)));
                                luaL_addchar(&b, (unsigned char) (0x80 | (0x3F & (u >> 12))));
                            }
                            luaL_addchar(&b, 0x80 | (0x3F & (u >> 6)));
                        }
                        luaL_addchar(&b, 0x80 | (0x3F & u));
                    }
                }
                lua_pop(L, 1);
            }
            luaL_pushresult(&b);
        } else {
            lua_pushliteral(L, "");
        }
        return 1;
    }
    return 0;
}

static int strlib_format_toutf16(lua_State* L) {
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            int addzero = lua_toboolean(L, 2);
            luaL_Buffer b;
            luaL_buffinitsize(L, &b, (n + 2) * 4);
            for (lua_Integer i = 1; i <= n; i++) {
                if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                    unsigned u = (unsigned) lua_tointeger(L, -1);
                    if (invalid_unicode(u)) {
                        luaL_addchar(&b, 0xFD);
                        luaL_addchar(&b, 0xFF);
                    } else if (u < 0x10000) {
                        luaL_addchar(&b, (unsigned char) ((u & 0x00FF)     ));
                        luaL_addchar(&b, (unsigned char) ((u & 0xFF00) >> 8));
                    } else {
                        u = u - 0x10000;
                        luaL_addchar(&b, (unsigned char) ((((u >> 10) + 0xD800) & 0x00FF)     ));
                        luaL_addchar(&b, (unsigned char) ((((u >> 10) + 0xD800) & 0xFF00) >> 8));
                        luaL_addchar(&b, (unsigned char) (( (u % 1024 + 0xDC00) & 0x00FF)     ));
                        luaL_addchar(&b, (unsigned char) (( (u % 1024 + 0xDC00) & 0xFF00) >> 8));
                    }
                }
                lua_pop(L, 1);
            }
            if (addzero) { 
                luaL_addchar(&b, 0);
                luaL_addchar(&b, 0);
            }
            luaL_pushresult(&b);
        } else {
            lua_pushliteral(L, "");
        }
        return 1;
    }
    return 0;
}

static int strlib_format_toutf32(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            int addzero = lua_toboolean(L, 2);
            luaL_Buffer b;
            luaL_buffinitsize(L, &b, (n + 2) * 4);
            for (lua_Integer i = 1; i <= n; i++) {
                /* there should be one operation for getting a number from a table */
                if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                    unsigned u = (unsigned) lua_tointeger(L, -1);
                    if (invalid_unicode(u)) {
                        luaL_addchar(&b, 0xFD);
                        luaL_addchar(&b, 0xFF);
                        luaL_addchar(&b, 0x00);
                        luaL_addchar(&b, 0x00);
                    } else {
                        luaL_addchar(&b, (unsigned char) ((u & 0x000000FF)      ));
                        luaL_addchar(&b, (unsigned char) ((u & 0x0000FF00) >>  8));
                        luaL_addchar(&b, (unsigned char) ((u & 0x00FF0000) >> 16));
                        luaL_addchar(&b, (unsigned char) ((u & 0xFF000000) >> 24));
                    }
                }
                lua_pop(L, 1);
            }
            if (addzero) {
                for (int i = 0; i <= 3; i++) {
                    luaL_addchar(&b, 0);
                }
            }
            luaL_pushresult(&b);
        } else {
            lua_pushliteral(L, "");
        }
        return 1;
    }
    return 0;
}

/* 
    str, true       : big endian
    str, false      : little endian
    str, nil, true  : check bom, default to big endian 
    str, nil, false : check bom, default to little endian 
    str, nil, nil   : check bom, default to little endian 
*/

static int strlib_utf16toutf8(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, 1, &ls);
    /* ignore trailing odd byte if string length isn't even */
    ls &= ~(size_t) 1;
    if (!ls) {
        lua_pushliteral(L, "");
    } else {
        int be = 1;
        size_t i = 0;
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            be = lua_toboolean(L, 2);
        } else if (ls >= 2 && (unsigned char) s[0] == 0xFE && (unsigned char) s[1] == 0xFF) {
            be = 1;
            i += 2;
        } else if (ls >= 2 && (unsigned char) s[0] == 0xFF && (unsigned char) s[1] == 0xFE) {
            be = 0;
            i += 2;
        } else {
            be = lua_toboolean(L, 3);
        }
        luaL_Buffer b;
        luaL_buffinitsize(L, &b, (ls - i) * 3 / 2 + 1);
        unsigned int high_surrogate = 0;
        while (i < ls) {
            unsigned char c1   = (unsigned char) s[i++];
            unsigned char c2   = (unsigned char) s[i++];
            unsigned int  word = be ? ((unsigned int) c1 << 8) | c2 : ((unsigned int) c2 << 8) | c1;
            if (high_surrogate) {
                if (word >= 0xDC00 && word <= 0xDFFF) {
                    /* valid surrogate pair: decode codepoint */
                    unsigned int codepoint = (((high_surrogate & 0x3FF) << 10) | (word & 0x3FF)) + 0x10000;
                    strlib_aux_add_utfchar(&b, codepoint);
                    high_surrogate = 0;
                    continue;
                } else {
                    /* previous high surrogate was orphan/unpaired */
                    strlib_aux_add_utfchar(&b, 0xFFFD);
                    high_surrogate = 0;
                }
            }
            if (word >= 0xD800 && word <= 0xDBFF) {
                /* high surrogate for next word */
                high_surrogate = word;
            } else if (word >= 0xDC00 && word <= 0xDFFF) {
                /* lone low surrogate */
                strlib_aux_add_utfchar(&b, 0xFFFD);
            } else {
                /* normal BMP character */
                strlib_aux_add_utfchar(&b, word);
            }
        }
        /* trailing unpaired high surrogate at end-of-string */
        if (high_surrogate) {
            strlib_aux_add_utfchar(&b, 0xFFFD);
        }
        luaL_pushresult(&b);
    }
    return 1;
}

/* for pdf */

static inline void strlib_aux_topdfsixteen(const char *s, size_t ls, luaL_Buffer *b, int bom, int brackets)
{
    if (brackets) {
        luaL_addchar(b, '<');
    }
    if (bom) {
        luaL_addlstring(b, "FEFF", 4);
    }
    size_t p = 0;
    while (p < ls) {
        int u = strlib_aux_tounicode(s, ls, &p);
        if (u < 0 || u > MAXUNICODE || invalid_unicode(u)) {
            luaL_addlstring(b, "FFFD", 4);
        } else if (u <= 0xFFFF) {
            char hex[4];
            write_hex16(hex, (unsigned int) u);
            luaL_addlstring(b, hex, 4);
        } else {
            char hex[8];
            unsigned int v  = (unsigned int) (u - 0x10000);
            unsigned int u1 = (v >> 10) + 0xD800;
            unsigned int u2 = (v & 0x3FF) + 0xDC00;
            write_hex16(hex, u1);
            write_hex16(hex + 4, u2);
            luaL_addlstring(b, hex, 8);
        }
    }
    if (brackets) {
        luaL_addchar(b, '>');
    }
}

static int strlib_topdfsixteen(lua_State *L)
{
    size_t      len      = 0;
    const char *str      = luaL_checklstring(L, 1, &len);
    int         bom      = ! lua_toboolean(L, 2);
    int         brackets = ! lua_toboolean(L, 3);
    luaL_Buffer b;
    /* each unicode point can be up to 8 hex chars (including surrogate pair) */
    luaL_buffinitsize(L, &b, (len + 1) * 8 + (bom ? 4 : 0) + (brackets ? 2 : 0));
    strlib_aux_topdfsixteen(str, len, &b, bom, brackets);
    luaL_pushresult(&b);
    return 1;
}

static int strlib_topdfeight(lua_State *L)
{
    size_t      len         = 0;
    const char *str         = luaL_checklstring(L, 1, &len);
    int         parentheses = ! lua_toboolean(L, 2);
    luaL_Buffer b;
    /* in the worst case every char expands or gets prefixed/suffixed */
    luaL_buffinitsize(L, &b, len * 2 + (parentheses ? 2 : 0));
    if (parentheses) {
        luaL_addchar(&b, '(');
    }
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char) str[i];
        switch (c) {
            case '(':
                if (parentheses) {
                    luaL_addchar(&b, '\\');
                    luaL_addchar(&b, '(');
                } else {
                    luaL_addchar(&b, '(');
                }
                break;
            case ')':
                if (parentheses) {
                    luaL_addchar(&b, '\\');
                    luaL_addchar(&b, ')');
                } else {
                    luaL_addchar(&b, ')');
                }
                break;
            case '\\':
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, '\\');
                break;
            case '\n':
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, 'n');
                break;
            case '\r':
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, 'r');
                break;
            case '\t':
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, 't');
                break;
            case '\b':
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, 'b');
                break;
            case '\f':
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, 'f');
                break;
            default:
                luaL_addchar(&b, (char) c);
                break;
        }
    }
    if (parentheses) {
        luaL_addchar(&b, ')');
    }
    luaL_pushresult(&b);
    return 1;
}

static int strlib_topdfstring(lua_State *L)
{
    luaL_Buffer b;
    size_t      len   = 0;
    const char *str   = luaL_checklstring(L, 1, &len);
    int         utf16 = 0;
    int         utf8  = 0;
    /* check for characters outside 0x20 .. 0x7F (0x00..0x1F and 0x80..0xFF) */
    if (lua_toboolean(L, 2)) {
        /* possibly utf () strings */
        for (size_t i = 0; i < len; i++) {
            unsigned char c = (unsigned char) str[i];
            if (c < 0x20) {
                utf16 = 1;
                break;
            } else if (c > 0x7F) {
                utf8 = 1;
            }
        }
    } else {
        /* no utf () strings */
        for (size_t i = 0; i < len; i++) {
            unsigned char c = (unsigned char) str[i];
            if (c < 0x20 || c > 0x7F) {
                utf16 = 1;
                break;
            }
        }
    }
    if (utf16) {
        /* UTF-16 hex format with FEFF BOM, wrapped in < and > */
        luaL_buffinitsize(L, &b, (len + 1) * 8 + 4 + 2);
        strlib_aux_topdfsixteen(str, len, &b, 1, 1);
    } else {
        /* 0x20..0x7F ASCII/UTF8: wrap in () and escape (, ), and \ */
        luaL_buffinitsize(L, &b, len * 2 + (utf8 ? 5 : 2));
        luaL_addchar(&b, '(');
        if (utf8) {
            luaL_addlstring(&b, "\xEF\xBB\xBF", 3);
        }
        for (size_t i = 0; i < len; i++) {
            unsigned char c = (unsigned char) str[i];
            if (c == '(') {
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, '(');
            } else if (c == ')') {
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, ')');
            } else if (c == '\\') {
                luaL_addchar(&b, '\\');
                luaL_addchar(&b, '\\');
            } else {
                luaL_addchar(&b, (char) c);
            }
        }
        luaL_addchar(&b, ')');
    }
    luaL_pushresult(&b);
    return 1;
}

static int strlib_pack_rows_columns(lua_State* L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer rows = lua_rawlen(L, 1);
        if (rows <= 0) {
            lua_pushliteral(L, "");
            return 1;
        } else if (lua_rawgeti(L, 1, 1) == LUA_TTABLE) {
            lua_Integer columns = lua_rawlen(L, -1);
            if (columns <= 0) {
                lua_pop(L, 1); /* pop row table */
                lua_pushliteral(L, "");
                return 1;
            }
            switch (lua_rawgeti(L, -1, 1)) {
                case LUA_TNUMBER:
                    {
                        if ((size_t) rows > SIZE_MAX / (size_t) columns) {
                            lua_pop(L, 2); /* row and cell */
                            return luaL_error(L, "table dimensions in string.packrowscolumns are too large");
                        }
                        size_t size = (size_t) rows * (size_t) columns;
                        unsigned char *result = lmt_memory_malloc(size);
                        lua_pop(L, 2); /* row and cell */
                        if (result) {
                            unsigned char *first = result;
                            for (lua_Integer r = 1; r <= rows; r++) {
                                if (lua_rawgeti(L, 1, r) == LUA_TTABLE) {
                                    for (lua_Integer c = 1; c <= columns; c++) {
                                        if (lua_rawgeti(L, -1, c) == LUA_TNUMBER) {
                                            lua_Integer v = lua_tointeger(L, -1);
                                            *result++ = v < 0 ? 0 : v > 255 ? 255 : (unsigned char) v;
                                        } else {
                                            *result++ = 0;
                                        }
                                        lua_pop(L, 1);
                                    }
                                }
                                lua_pop(L, 1);
                            }
                            lua_pushlstring(L, (char *) first, (size_t) (result - first));
                            lmt_memory_free(first);
                            return 1;
                        } else {
                            return luaL_error(L, "not enough memory for string.packrowscolumns");
                        }
                    }
                case LUA_TTABLE:
                    {
                        int mode = (int) lua_rawlen(L, -1);
                        if (mode <= 0) {
                            lua_pop(L, 2);
                            lua_pushliteral(L, "");
                            return 1;
                        }
                        if ((size_t) rows > SIZE_MAX / (size_t) columns || ((size_t) rows * (size_t) columns) > SIZE_MAX / (size_t) mode) {
                            lua_pop(L, 2);
                            return luaL_error(L, "table dimensions in string.packrowscolumns are too large");
                        }
                        size_t size = (size_t) rows * (size_t) columns * (size_t) mode;
                        unsigned char *result = lmt_memory_malloc(size);
                        lua_pop(L, 2); /* row and cell */
                        if (result) {
                            unsigned char *first = result;
                            for (lua_Integer r = 1; r <= rows; r++) {
                                if (lua_rawgeti(L, 1, r) == LUA_TTABLE) {
                                    for (lua_Integer c = 1; c <= columns; c++) {
                                        if (lua_rawgeti(L, -1, c) == LUA_TTABLE) {
                                            for (int i = 1; i <= mode; i++) {
                                                if (lua_rawgeti(L, -1, i) == LUA_TNUMBER) {
                                                    lua_Integer v = lua_tointeger(L, -1);
                                                    *result++ = v < 0 ? 0 : v > 255 ? 255 : (unsigned char) v;
                                                } else {
                                                    *result++ = 0;
                                                }
                                                lua_pop(L, 1);
                                            }
                                        }
                                        lua_pop(L, 1);
                                    }
                                }
                                lua_pop(L, 1);
                            }
                            lua_pushlstring(L, (char *) first, (size_t) (result - first));
                            lmt_memory_free(first);
                            return 1;
                        } else {
                            return luaL_error(L, "not enough memory for string.packrowscolumns");
                        }
                    }
                default:
                    lua_pop(L, 1); /* pop element */
                    break;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int strlib_hextocharacters(lua_State *L)
{
    size_t ls = 0;
    const char *s = lua_tolstring(L, 1, &ls);
    if (ls == 0) {
        lua_pushliteral(L, "");
        return 1;
    } else {
        const char *end = s + ls;
        luaL_Buffer b;
        luaL_buffinitsize(L, &b, ls / 2);
        /* states :: -1 : looking for 1st digit, >= 0 : holds 1st digit */
        int high_nibble = -1;
        while (s < end) {
            unsigned char c = (unsigned char) *s++;
            unsigned short val = strlib_hex_table[c];
            if (val < 16) {
                if (high_nibble < 0) {
                    /* first digit of pair */
                    high_nibble = val;
                } else {
                    /* second digit: assemble byte and add it to the buffer */
                    luaL_addchar(&b, (char) ((high_nibble << 4) | val));
                    high_nibble = -1;
                }
            } else if (val == 256) {
                /* skip white spacing safely */
                continue;
            } else {
                /* invalid character found */
                lua_pushboolean(L, 0);
                return 1;
            }
        }
        /* a trailing unpaired hex digit is invalid */
        if (high_nibble >= 0) {
            lua_pushboolean(L, 0);
            return 1;
        } else {
            luaL_pushresult(&b);
            return 1;
        }
    }
}

static int strlib_octtointeger(lua_State *L)
{
    const char *s = luaL_checkstring(L, 1);
    lua_pushinteger(L, (lua_Integer) strtoul(s, NULL, 8));
    return 1;
}

static int strlib_dectointeger(lua_State *L)
{
    const char *s = luaL_checkstring(L, 1);
    lua_pushinteger(L, (lua_Integer) strtoul(s, NULL, 10));
    return 1;
}

static int strlib_hextointeger(lua_State *L)
{
    const char *s = luaL_checkstring(L, 1);
    lua_pushinteger(L, (lua_Integer) strtoul(s, NULL, 16));
    return 1;
}

static int strlib_chrtointeger(lua_State *L)
{
    size_t l = 0;
    const char *s = lua_tolstring(L, 1, &l);
    if (l == 0) {
        lua_pushinteger(L, 0);
        return 1;
    } else if (l > sizeof(lua_Integer)) {
        lua_pushboolean(L, 0);
        return 1;
    } else {
        lua_Unsigned n = 0;
        for (size_t p = 0; p < l; p++) {
            n = (n << 8) | (unsigned char)s[p];
        }
        lua_pushinteger(L, (lua_Integer)n);
        return 1;
    }
}

/*tex 
    I considered a version where we |break| on a non-number but in that case we normally know where
    the last useful slot is anyway so I removed that variant. 
*/

static int strlib_utftabletostring(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            lua_Integer f = lmt_optinteger(L, 2, 1);
            lua_Integer l = lmt_optinteger(L, 3, n);
            if (f < 1) { f = 1; }
            if (l > n) { l = n; }
            if (l >= f) {
                luaL_Buffer b;
                luaL_buffinitsize(L, &b, (size_t) (l-f+1) * 4);
                for (lua_Integer i = f; i <= l; i++) {
                    if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                        strlib_aux_add_utfnumber(L, &b, -1);
                    }
                    lua_pop(L, 1);
                }
                luaL_pushresult(&b);
                return 1;
            }
        }
    }
    lua_pushliteral(L, "");
    return 1;
}

static int strlib_splitintolines(lua_State *L)
{
    size_t l = 0;
    const char *s = lua_tolstring(L, 1, &l);
    lua_newtable(L);
    if (l > 0) {
        size_t n = 0;
        lua_Integer i = 0;
        const char *f = s;
        while (*s) {
            if (*s == 13) {
                /* cr */
                lua_pushlstring(L, f, n);
                lua_rawseti(L, -2, ++i);
                f = ++s;
                if (*f == 10) {
                    f = ++s;
                }
                if (! *f) {
                    return 1;
                }
                n = 0;
            } else if (*s == 10) {
                /* lf */
                lua_pushlstring(L, f, n);
                lua_rawseti(L, -2, ++i);
                f = ++s;
                if (! *f) {
                    return 1;
                }
                n = 0;
            } else {
                ++n;
                ++s;
            }
        }
        if (f) {
            lua_pushlstring(L, f, n);
            lua_rawseti(L, -2, ++i);
        }
    }
    return 1;
}

/*tex

    The table serializer in \CONTEXT\ is quite okay but sometimes we have rather large tables,
    like the character database, fonts and a utility file. So, as a test I played with a C based
    serializer variant. Some initial statistics were promising:

    loading char-def.lua : 0.11100000000000002
    table.serialize      : size 6127996, time: 0.312
    string.serialize     : size 6127997, time: 0.053

    So indeed handy to have it as alternative. For this approach we revive an older idea of
    buffers so eventually we might implement it as described at the bottom of this file.

    Because we know the length of constant strings, we can use the more optimal length aware
    append in most cases. Single characters have their own optimal append. We might add more 
    to this repertoire if we ever add the buffer userdata. 

    We start with string buffers. As mentioned this is oldish code revived. To that we added
    some more, in order to support serializing but after that we also added for instance a 
    format feature because we could share code that way. So it became abit larger effort than 
    initially planned. This kind of code is rather easy in the sense that there are no 
    heuristics or unexpected side effects, contrary to the rest of the engine. This is easy 
    going coding, a distraction from more complex matters, and desired interfaces are known  
    and translations of what we already have in \LUA.

*/

# define lmt_string_buffer_default  (1024 * 1024)
# define default_format_size        4096 /* occasionally 8192 or 16384 */

typedef struct lmt_string_buffer {
    char      *buffer;
    size_t     length;
    size_t     size;
    size_t     step;
    lua_State *L;      /* the (current) state, errors have to be raised there (think coroutines) */
} lmt_string_buffer;

inline static void lmt_buffer_allocate(lua_State *L, lmt_string_buffer *b)
{
    b->size   = lmt_string_buffer_default;
    b->length = 0;
    b->buffer = (char *) lmt_memory_malloc(b->size);
    b->step   = 0; /* maybe, as other memory management in lmtx */
    b->L      = L;
}

inline static void lmt_buffer_dispose(lmt_string_buffer *b)
{
    lmt_memory_free(b->buffer);
}

inline static int lmt_buffer_has_room(lmt_string_buffer *b, size_t needed)
{
    if (b->size == 0) {
        b->size   = default_format_size;
        b->length = 0;
        b->buffer = (char *) lmt_memory_malloc(b->size);
        b->step   = 0;
    }
    if (needed > SIZE_MAX - b->length) {
        luaL_error(b->L, "not enough memory for buffer");
        return 0;
    }
    size_t required = b->length + needed;
    if (required >= b->size) {
        size_t new_size = b->size;
        if (b->step) {
            while (required >= new_size) {
                if (new_size > SIZE_MAX - b->step) {
                    luaL_error(b->L, "not enough memory for buffer");
                    return 0;
                }
                new_size += b->step;
            }
        } else {
            while (required >= new_size) {
                if (new_size > (SIZE_MAX / 2)) {
                    /* prevent arithmetic overflow wrap-around */
                    luaL_error(b->L, "not enough memory for buffer");
                    return 0;
                }
                new_size *= 2;
            }
        }
        char *new_buffer = (char *) lmt_memory_realloc(b->buffer, new_size);
        if lmt_unlikely(! new_buffer) {
            luaL_error(b->L, "not enough memory for buffer");
            return 0;
        }
        b->buffer = new_buffer;
        b->size   = new_size;
    }
    return 1;
}

inline static void lmt_buffer_add_lstring(lmt_string_buffer *b, const char *str, size_t len)
{
    if (lmt_buffer_has_room(b, len)) {
        memcpy(b->buffer + b->length, str, len);
        b->length += len;
    }
}

inline static void lmt_buffer_add_string(lmt_string_buffer *b, const char *str)
{
    lmt_buffer_add_lstring(b, str, strlen(str));
}

inline static void lmt_buffer_add_char(lmt_string_buffer *b, char chr)
{
    if (lmt_buffer_has_room(b, 1)) {
        b->buffer[b->length] = chr;
        b->length += 1;
    }
}

inline static void lmt_buffer_add_char_ok(lmt_string_buffer *b, char chr)
{
    b->buffer[b->length] = chr;
    b->length += 1;
}

inline static void lmt_buffer_add_spaces(lmt_string_buffer *b, int n)
{
    if (n > 0 && lmt_buffer_has_room(b, n)) {
        memset(b->buffer + b->length, ' ', n);
        b->length += n;
    }
}

static inline void strlib_aux_add_z(lmt_string_buffer *b, lua_Number val, lua_Integer precision)
{
    int    req_precision = strlib_aux_normalize_precision(precision);
    size_t req_room      = (size_t) req_precision + 350;
    if (lmt_buffer_has_room(b, req_room)) {
        int len = double_to_string_z(val, b->buffer + b->length, b->size - b->length, req_precision);
        if (len >= 0) {
            b->length += (size_t) len;
        }
    }
}

/*tex

    The next (old, moved here) experiment was used to check if using some buffer is more efficient
    than using a table that we concat. It makes no difference. The experiment added the helpers to
    the string library but now that we have the sequencer lib we can best add it there. We could
    gain a little on a bit more efficient |luaL_checkudata| as we use elsewhere because in practice
    (surprise) its overhead makes buffers like this {\em 50 percent} slower than the concatinated
    variant and twice as slow when we reuse a temporary table. It's just better to stay at the
    \LUA\ end. Replacing the userdata test with a dedicated test gives a speed boost but we're
    still some {\em 10 percent} slower. So, as the overhead in the engine is little we just enable
    it, if only for experiments.The archive has the previous code, where it hooks into the string 
    library (that we extend anyway).

    Because I knew that there was room for improvement I chat a bit with gemini and we got to 
    a real low level speedup. 

    Baseline C API            0.381s   1.0×  Full C API stack validation + lua_tolstring   
    Direct Pointer Check      0.095s   4.0×  ttisfulluserdata + getudatamem (bypassed C API stack)
    Direct Buffer Formatting  0.063s   6.0×  serialize_integer (bypassed Lua string creation)  
    Lua table.concat          0.032s  11.9×  Inlined VM bytecode instructions (TSETI)

    Using this feature only makes sense when we have massive amounts and don't want to create 
    intermediate tables. So a 50% performance loss is acceptable. After that I added a addformat 
    variant (okay, asked gemini and then refactored that in what we had as serializers) and after 
    playing around abit we got a 400% percent gain over using |string.format|:

    \starttyping
    local add       = sequencer.addtobuffer
    local addformat = sequencer.addformattobuffer
    local format    = string.format

    local n = 500000

    local c = os.clock()
    local b = sequencer.newbuffer(1024*1024)
    for i=1,n do
        add(b,"foo")
        add(b,i)
        addformat(b,"%.10f",1.2345678900) -- extra test
        add(b,"\n")
    end
    print(sequencer.getbuffersize(b),os.clock()-c)

    local c = os.clock()
    local b = { }
    for i=1,n do
        b[#b+1] = "foo"
        b[#b+1] = i
        b[#b+1] = format("%.10f",1.2345678900) -- extra test
        b[#b+1] = "\n"
    end
    b = table.concat(b)
    print(#,os.clock()-c)
    \stoptyping 

    The buffered size is smaller because we strip redundant zero's. So, after all an interesting 
    experiment.

*/

static const void *G_BUFFER_METATABLE_PTR = NULL;

static inline lmt_string_buffer *strlib_buffer_instance(lua_State *L)
{
    lmt_string_buffer *b = (lmt_string_buffer *) lua_touserdata(L, 1);
    if (b && lua_getmetatable(L, 1)) {
        if (lua_topointer(L, -1) != G_BUFFER_METATABLE_PTR || ! b->buffer) {
            b = NULL;
        } else {
            b->L = L; /* the buffer can be used in another coroutine than where it was made */
        }
        lua_pop(L, 1);
        return b;
    }
    return NULL;
}

static int strlib_buffer_gc(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        lmt_memory_free(b->buffer);
        b->buffer = NULL;
    }
    return 0;
}

static int strlib_buffer_tostring(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        lua_pushfstring(L, "<buffer %p>", b);
        return 1;
    } else {
        return 0;
    }
}

# define minimum_step 1024

static int strlib_buffer_new(lua_State *L)
{
    size_t size = lmt_optsizet(L, 1, LUAL_BUFFERSIZE);
    if (size < minimum_step) {
        size = minimum_step; /* Ensure size is never zero or unreasonably small */
    }
    size_t step = lmt_optsizet(L, 2, size);
    lmt_string_buffer *b = (lmt_string_buffer *) lua_newuserdatauv(L, sizeof(lmt_string_buffer), 0);
    /* lmt_buffer_allocate(b); */
    b->size   = size;
    b->length = 0;
    b->buffer = (char *) lmt_memory_malloc(b->size);
    b->step   = (step < minimum_step) ? minimum_step : ((step > size) ? size : step); /* let's be reasonable*/
    b->L      = L;
    lua_get_metatablelua(string_buffer_instance);
    lua_setmetatable(L, -2);
    return 1;
}

static int strlib_buffer_get_data(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        lua_pushlstring(L, b->buffer, b->length);
        lua_pushinteger(L, (lua_Integer) b->length);
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int strlib_buffer_get_size(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    lua_pushinteger(L, b ? b->length : 0);
    return 1;
}

static const luaL_Reg sequencerlib_metatable_list[] =
{
 // { "__newindex", strlib_buffer_setvalue  },
    { "__tostring", strlib_buffer_tostring  },
    { "__gc",       strlib_buffer_gc        },
    { NULL,         NULL                    },
};

/*tex

    Right after we started with \MKIV\ we needed serialization of (often large) tables. Of 
    course we used \LUA. That code could either construct a table with strings (to be concat)
    or write to file. That handle overhead was later avoided by a variant. We also wanted 
    some number values to be hex as it's easier with \UNICODE\ but in the end the overhead 
    made that a seldom used option. We also kept track of circular references but again, that
    was never useful at this level so we dealt with that differently. We also moved on to 
    using formatters, because those are faster than \LUA's formatter. 

    Move some to \CCODE\ was already on the agenda and prototyped in a helperlib that is 
    not part of the regular distribution. We now include an update to this.

*/

/* 
    This is a typical case where one can prompt an llm framework: can you make me a lookup table
    for this. Most languages need something like this when they serialize, so here is what Gemini 
    cooked up (not that much faster but neat anyway). It actually did it wrong but I wanted |\xNN| 
    anyway that got fixed. This replaces a loop with per-character escape checking, pretty much 
    what we do at the \LUA\ end. The |> 127| slots are unchanged because \LUA\ is byte agnostic.  
*/

typedef struct {
    char    bytes[4];
    uint8_t len;
} char_esc_t;

#define ESC1(c)          { { (char) (c), 0, 0, 0 }, 1 }
#define ESC2(a, b)       { { a,          b, 0, 0 }, 2 }
#define ESC3(a, b, c)    { { a,          b, c, 0 }, 3 }
#define ESC4(a, b, c, d) { { a,          b, c, d }, 4 }

static const char_esc_t ESCAPE_LUT[256] = {
    /* 0x00 - 0x07 */ ESC4('\\','x','0','0'), ESC4('\\','x','0','1'), ESC4('\\','x','0','2'), ESC4('\\','x','0','3'), ESC4('\\','x','0','4'), ESC4('\\','x','0','5'), ESC4('\\','x','0','6'), ESC4('\\','x','0','7'),
    /* 0x08 - 0x0F */ ESC4('\\','x','0','8'), ESC2('\\','t'),         ESC2('\\','n'),         ESC4('\\','x','0','B'), ESC4('\\','x','0','C'), ESC2('\\','r'),         ESC4('\\','x','0','E'), ESC4('\\','x','0','F'),
    /* 0x10 - 0x17 */ ESC4('\\','x','1','0'), ESC4('\\','x','1','1'), ESC4('\\','x','1','2'), ESC4('\\','x','1','3'), ESC4('\\','x','1','4'), ESC4('\\','x','1','5'), ESC4('\\','x','1','6'), ESC4('\\','x','1','7'),
    /* 0x18 - 0x1F */ ESC4('\\','x','1','8'), ESC4('\\','x','1','9'), ESC4('\\','x','1','A'), ESC4('\\','x','1','B'), ESC4('\\','x','1','C'), ESC4('\\','x','1','D'), ESC4('\\','x','1','E'), ESC4('\\','x','1','F'),
    /* 0x20 - 0x27 */ ESC1(' '),              ESC1('!'),              ESC2('\\','"'),         ESC1('#'),              ESC1('$'),              ESC1('%'),              ESC1('&'),              ESC1('\''),
    /* 0x28 - 0x2F */ ESC1('('),              ESC1(')'),              ESC1('*'),              ESC1('+'),              ESC1(','),              ESC1('-'),              ESC1('.'),              ESC1('/'),
    /* 0x30 - 0x37 */ ESC1('0'),              ESC1('1'),              ESC1('2'),              ESC1('3'),              ESC1('4'),              ESC1('5'),              ESC1('6'),              ESC1('7'),
    /* 0x38 - 0x3F */ ESC1('8'),              ESC1('9'),              ESC1(':'),              ESC1(';'),              ESC1('<'),              ESC1('='),              ESC1('>'),              ESC1('?'),
    /* 0x40 - 0x47 */ ESC1('@'),              ESC1('A'),              ESC1('B'),              ESC1('C'),              ESC1('D'),              ESC1('E'),              ESC1('F'),              ESC1('G'),
    /* 0x48 - 0x4F */ ESC1('H'),              ESC1('I'),              ESC1('J'),              ESC1('K'),              ESC1('L'),              ESC1('M'),              ESC1('N'),              ESC1('O'),
    /* 0x50 - 0x57 */ ESC1('P'),              ESC1('Q'),              ESC1('R'),              ESC1('S'),              ESC1('T'),              ESC1('U'),              ESC1('V'),              ESC1('W'),
    /* 0x58 - 0x5F */ ESC1('X'),              ESC1('Y'),              ESC1('Z'),              ESC1('['),              ESC2('\\','\\'),        ESC1(']'),              ESC1('^'),              ESC1('_'),
    /* 0x60 - 0x67 */ ESC1('`'),              ESC1('a'),              ESC1('b'),              ESC1('c'),              ESC1('d'),              ESC1('e'),              ESC1('f'),              ESC1('g'),
    /* 0x68 - 0x6F */ ESC1('h'),              ESC1('i'),              ESC1('j'),              ESC1('k'),              ESC1('l'),              ESC1('m'),              ESC1('n'),              ESC1('o'),
    /* 0x70 - 0x77 */ ESC1('p'),              ESC1('q'),              ESC1('r'),              ESC1('s'),              ESC1('t'),              ESC1('u'),              ESC1('v'),              ESC1('w'),
    /* 0x78 - 0x7F */ ESC1('x'),              ESC1('y'),              ESC1('z'),              ESC1('{'),              ESC1('|'),              ESC1('}'),              ESC1('~'),              ESC4('\\','x','7','F'),
    /* 0x80 - 0xFF */ // High bytes (128-255) map to single bytes (UTF-8 compatible)
    ESC1(128), ESC1(129), ESC1(130), ESC1(131), ESC1(132), ESC1(133), ESC1(134), ESC1(135), ESC1(136), ESC1(137), ESC1(138), ESC1(139), ESC1(140), ESC1(141), ESC1(142), ESC1(143),
    ESC1(144), ESC1(145), ESC1(146), ESC1(147), ESC1(148), ESC1(149), ESC1(150), ESC1(151), ESC1(152), ESC1(153), ESC1(154), ESC1(155), ESC1(156), ESC1(157), ESC1(158), ESC1(159),
    ESC1(160), ESC1(161), ESC1(162), ESC1(163), ESC1(164), ESC1(165), ESC1(166), ESC1(167), ESC1(168), ESC1(169), ESC1(170), ESC1(171), ESC1(172), ESC1(173), ESC1(174), ESC1(175),
    ESC1(176), ESC1(177), ESC1(178), ESC1(179), ESC1(180), ESC1(181), ESC1(182), ESC1(183), ESC1(184), ESC1(185), ESC1(186), ESC1(187), ESC1(188), ESC1(189), ESC1(190), ESC1(191),
    ESC1(192), ESC1(193), ESC1(194), ESC1(195), ESC1(196), ESC1(197), ESC1(198), ESC1(199), ESC1(200), ESC1(201), ESC1(202), ESC1(203), ESC1(204), ESC1(205), ESC1(206), ESC1(207),
    ESC1(208), ESC1(209), ESC1(210), ESC1(211), ESC1(212), ESC1(213), ESC1(214), ESC1(215), ESC1(216), ESC1(217), ESC1(218), ESC1(219), ESC1(220), ESC1(221), ESC1(222), ESC1(223),
    ESC1(224), ESC1(225), ESC1(226), ESC1(227), ESC1(228), ESC1(229), ESC1(230), ESC1(231), ESC1(232), ESC1(233), ESC1(234), ESC1(235), ESC1(236), ESC1(237), ESC1(238), ESC1(239),
    ESC1(240), ESC1(241), ESC1(242), ESC1(243), ESC1(244), ESC1(245), ESC1(246), ESC1(247), ESC1(248), ESC1(249), ESC1(250), ESC1(251), ESC1(252), ESC1(253), ESC1(254), ESC1(255)
};

#undef ESC1
#undef ESC2
#undef ESC3
#undef ESC4

static void serialize_string_escaped(lmt_string_buffer *b, const char *s, size_t len)
{
    if (len > (SIZE_MAX - 2) / 4) {
        luaL_error(b->L, "not enough memory for buffer");
        return;
    }
    if (lmt_buffer_has_room(b, len * 4 + 2)) {
        b->buffer[b->length++] = '"';
        for (size_t i = 0; i < len; i++) {
            unsigned char c = (unsigned char)s[i];
            char_esc_t esc = ESCAPE_LUT[c];
            memcpy(b->buffer + b->length, esc.bytes, esc.len);
            b->length += esc.len;
        }
        b->buffer[b->length++] = '"';
    }
}

/*tex

    We can use this: 

    \starttyping
    static void serialize_string(lmt_string_buffer *b, const char *s, size_t len)
    {
        if (lmt_buffer_has_room(b, (len * 2) + 2)) {
            b->buffer[b->length++] = '"';      
            for (size_t i = 0; i < len; i++) {
                char c = s[i];
                if (c == '"' || c == '\\' ) {
                    b->buffer[b->length++] = '\\';
                }           
                b->buffer[b->length++] = c;
            }
            b->buffer[b->length++] = '"';
        }
    }
    \stoptyping

    Instead we use an editor safe variant instead. It adds e.g. 3K to a dejavu stream table of 
    nearly 500K so that's ok. After all we use the bytecode compiler version which is smaller 
    anyway. 

*/

static void serialize_string(lmt_string_buffer *b, const char *s, size_t len)
{
    if (len > (SIZE_MAX - 2) / 2) {
        luaL_error(b->L, "not enough memory for buffer");
        return;
    }
    if (lmt_buffer_has_room(b, (len * 2) + 2)) {
        b->buffer[b->length++] = '"';
        for (size_t i = 0; i < len; i++) {
            char c = s[i];
            switch (c) {
                /* we keep nul, e.g. scite just shows that well */
                case '"':
                case '\\':
                    b->buffer[b->length++] = '\\';
                    b->buffer[b->length++] = c;
                    break;
                case '\f':
                    b->buffer[b->length++] = '\\';
                    b->buffer[b->length++] = 'f';
                    break;
                case '\n':
                    b->buffer[b->length++] = '\\';
                    b->buffer[b->length++] = 'n';
                    break;
                case '\r':
                    b->buffer[b->length++] = '\\';
                    b->buffer[b->length++] = 'r';
                    break;
                case '\t':
                    b->buffer[b->length++] = '\\';
                    b->buffer[b->length++] = 't';
                    break;
                case '\v':
                    b->buffer[b->length++] = '\\';
                    b->buffer[b->length++] = 'v';
                    break;
                default:
                    b->buffer[b->length++] = c;
                    break;
            }
        }
        b->buffer[b->length++] = '"';
    }
}

static void serialize_double(lmt_string_buffer *b, double val)
{
    if (lmt_buffer_has_room(b, 350)) {
        if (val >= -9223372036854775808.0 && val < 9223372036854775808.0) {
            int64_t i = (int64_t) val;
            if ((double) i == val && ! (i == 0 && signbit(val))) {
                b->length += snprintf(b->buffer + b->length, 350, "%" PRId64, i);
                return;
            }
        }
        b->length += snprintf(b->buffer + b->length, 350, "%a", val);
    }
}

static void serialize_integer(lmt_string_buffer *b, lua_Integer val)
{
    if (lmt_buffer_has_room(b, 32)) {
        b->length += snprintf(b->buffer + b->length, 32, "%" LUA_INTEGER_FRMLEN "d", val);
    }
}

static int strlib_buffer_add(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        int top = lua_gettop(L);
        for (int i = 2; i <= top; i++) {
            switch (lua_type(L, i)) {
                case LUA_TSTRING:
                    {
                        size_t l;
                        const char *s = lua_tolstring(L, i, &l);
                        lmt_buffer_add_lstring(b, s, l);
                        break;
                    }
                case LUA_TNUMBER:
                    {
                        if (lua_isinteger(L, i)) {
                            /* Write integer directly into b->buffer (zero Lua string creation) */
                            serialize_integer(b, lua_tointeger(L, i));
                        } else {
                            if (lmt_buffer_has_room(b, 350)) {
                                b->length += double_to_string_f(lua_tonumber(L, i), b->buffer + b->length, 17);
                            }
                        }
                        break;
                    }
                case LUA_TBOOLEAN:
                    {
                        if (lua_toboolean(L, i)) {
                            lmt_buffer_add_lstring(b, "true", 4);
                        } else {
                            lmt_buffer_add_lstring(b, "false", 5);
                        }
                        break;
                    }
                default:
                    break;
            }
        }
    }
    return 0;
}

/*tex

    With a bit of gemini help I stepwise added a formatter. Intermediate and final checks 
    stepwise made the buffering faster. A kind of fun excercize as long as one stays in 
    control and does specific suggestions and corrects when needed. Kind of a game and this 
    is straightforward code. 

    \startty    ping 
    local n = 500000

    local format   = string.format 
    local f        = string.formatters["%i %N %N %N %N %N %N cm"]
    local sqformat = sequencer.format
    local s

    local c = os.clock()
    for i=1,n do
        s = format("%i %f %f %f %f %f %f cm",i,1.999,2.999,3.999,4.999,5.999,6.999)
    end
    print("format   ",os.clock()-c,s)

    local c = os.clock()
    for i=1,n do
        s = f(i,1.999,2.999,3.999,4.999,5.999,6.999)
    end
    print("formatter",os.clock()-c,s)

    local c = os.clock()
    for i=1,n do
        local b = newbuffer(64)
        addformat(b,"%i %f %f %f %f %f %f cm",i,1.999,2.999,3.999,4.999,5.999,6.999)
        s = getbuffer(b)
    end
    print("buffer  ",os.clock()-c,s)

    local c = os.clock()
    for i=1,n do
        s = sqformat("%i %N %N %N %N %N %N cm",i,1.999,2.999,3.999,4.999,5.999,6.999)
    end
    print("sqformat",os.clock()-c,s)
    \stoptyping 

    \starttabulate[|l|r|r|r|]
    \HL
    \NC \bf Method
    \NC \bf 6 Floats (\type{%N})
    \NC \bf 1 Int + 6 Floats (\type{%i %N...})
    \NC \bf Delta (Overhead of \type{%i}) \NR
    \HL
    \NC \type{string.format}                \NC 1.036s \NC 1.097s     \NC +0.061s (+5.8\%) \NR
    \NC \type{formatter}                    \NC 0.334s \NC \bf 0.460s \NC \bf +0.126s (+37.7\% penalty) \NR
    \NC \type{buffer} (per-loop allocation) \NC 1.080s \NC 1.128s     \NC +0.048s (+4.4\%) \NR
    \NC \type{sqformat}                     \NC 0.336s \NC \bf 0.354s \NC \bf +0.018s (+5.3\% penalty) \NR
    \HL
    \stoptabulate

    Key Takeaways

    \startitemize
        \startitem 
            formatter (ConTeXt Lua Generator): Performs best when format strings are static and 
            consist purely of fast primitive conversions, but takes a performance hit as format 
            complexity and argument count grow due to Lua string concatenation chain overhead.
        \stopitem 
        \startitem 
            sequencer.format (sqformat): Handles complex, multi-type format strings (integers, 
            floats, hex, strings, booleans) with virtually linear performance scaling.
        \stopitem 
        \startitem 
            sequencer.addformattobuffer (Persistent Buffer): Remaining in C memory across 
            multiple steps without returning an intermediate string to Lua remains the fastest 
            path for bulk output (PDF/SVG streams, file writing, macro expansion).
        \stopitem 
    \stopitemize 

*/

static void strlib_aux_sequenced(
    lua_State         *L,
    int                index,
    lmt_string_buffer *buffer,
    int                sep_is_true,
    const char        *sep_str,
    size_t             sep_len,
    int                simple,
    int                seen,
    int                depth
);

static inline void strlib_aux_array_sequenced(
    lua_State         *L,
    int                tbl_idx,
    lmt_string_buffer *b,
    const char        *sep_str,
    size_t             sep_len
)
{
    lua_Unsigned n = lua_rawlen(L, tbl_idx);
    for (lua_Unsigned k = 1; k <= n; k++) {
        if (k > 1 && sep_len > 0) {
            lmt_buffer_add_lstring(b, sep_str, sep_len);
        }
        lua_rawgeti(L, tbl_idx, (lua_Integer) k);

        switch (lua_type(L, -1)) {
            case LUA_TNUMBER:
                if (lua_isinteger(L, -1)) {
                    serialize_integer(b, lua_tointeger(L, -1));
                } else {
                    if (lmt_buffer_has_room(b, 350)) {
                        b->length += double_to_string_f(lua_tonumber(L, -1), b->buffer + b->length, 17);
                    }
                }
                break;
            case LUA_TSTRING:
                {
                    size_t      len;
                    const char *str = lua_tolstring(L, -1, &len);
                    lmt_buffer_add_lstring(b, str, len);
                }
                break;
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, -1)) {
                    lmt_buffer_add_lstring(b, "true", 4);
                } else {
                    lmt_buffer_add_lstring(b, "false", 5);
                }
                break;
            default:
                break;
        }
        lua_pop(L, 1);
    }
}

static inline void strlib_aux_format_padded_number(
    lmt_string_buffer *b,
    const char        *prefix,
    size_t             prefix_len,
    const char        *temp_digits,
    int                digit_count,
    int                width,
    int                precision,
    int                has_precision,
    int                pad_zero,
    int                left_align
)
{
    /* left alignment takes precedence and disables zero-padding, as does a precision (printf) */
    if (left_align || has_precision) {
        pad_zero = 0;
    }
    /* when we pad with zeros the sign is part of the width */
    int min_digits = has_precision ? precision : (pad_zero ? width - (int) prefix_len : 1);
    if (min_digits <= 0) {
        min_digits = 1;
    }
    int num_len           = (digit_count < min_digits) ? min_digits : digit_count;
    int sign_len          = (int) prefix_len;
    int total_content_len = num_len + sign_len;
    int padding           = (width > total_content_len) ? width - total_content_len : 0;
    int total_len         = total_content_len + padding;
    if (lmt_buffer_has_room(b, (size_t) total_len)) {
        /* right alignment spaces (if not zero-padding and not left-aligned) */
        if (padding > 0 && !left_align && !pad_zero) {
            for (int z = 0; z < padding; z++) {
                b->buffer[b->length++] = ' ';
            }
        }
        /* write sign or prefix (e.g., "-", "+", "0x", "U+") */
        if (prefix_len > 0 && prefix != NULL) {
            memcpy(b->buffer + b->length, prefix, prefix_len);
            b->length += prefix_len;
        }
        /* zero padding between prefix and digits */
        if (pad_zero && padding > 0) {
            for (int z = 0; z < padding; z++) {
                b->buffer[b->length++] = '0';
            }
        }
        /* leading zero padding for precision / min_digits */
        for (int z = 0; z < num_len - digit_count; z++) {
            b->buffer[b->length++] = '0';
        }
        /* append digits in correct forward order */
        int len = digit_count;
        while (len > 0) {
            b->buffer[b->length++] = temp_digits[--len];
        }
        /* left alignment spaces */
        if (padding > 0 && left_align) {
            for (int z = 0; z < padding; z++) {
                b->buffer[b->length++] = ' ';
            }
        }
    }
}

static inline void strlib_aux_format_padded_string(
    lmt_string_buffer *b,
    const char        *temp,
    int                len,
    int                width,
    int                left_align
)
{
    int padding = (width > len) ? width - len : 0;
    if (padding <= 0) {
        lmt_buffer_add_lstring(b, temp, (size_t) len);
    } else {
        if (left_align) {
            lmt_buffer_add_lstring(b, temp, (size_t) len);
            lmt_buffer_add_spaces(b, padding);
        } else {
            lmt_buffer_add_spaces(b, padding);
            lmt_buffer_add_lstring(b, temp, (size_t) len);
        }
    }
}

/*tex
    Floats are formatted directly into the buffer, for which there is room for the width, and
    then we pad in place. Zeros go after the sign but are not used for infinity and nan.
*/

static inline void strlib_aux_format_padded_float(
    lmt_string_buffer *b,
    int                len,
    int                width,
    int                pad_zero,
    int                left_align
)
{
    int padding = width - len;
    if (padding > 0) {
        char *s = b->buffer + b->length;
        if (left_align) {
            memset(s + len, ' ', (size_t) padding);
        } else {
            int sign = s[0] == '-';
            if (pad_zero && s[sign] >= '0' && s[sign] <= '9') {
                memmove(s + sign + padding, s + sign, (size_t) (len - sign));
                memset(s + sign, '0', (size_t) padding);
            } else {
                memmove(s + padding, s, (size_t) len);
                memset(s, ' ', (size_t) padding);
            }
        }
        len = width;
    }
    b->length += (size_t) len;
}

/* %S and^%s are a bit diferent but ok */

static const char *const C_X00_table[33] = {
    "[null]",  "[soh]",  "[stx]",  "[etx]",  "[eot]",  "[enq]",  "[ack]",  "[bel]",
    "[bs]",    "[ht]",   "[lf]",   "[vt]",   "[ff]",   "[cr]",   "[so]",   "[si]",
    "[dle]",   "[dc1]",  "[dc2]",  "[dc3]",  "[dc4]",  "[nak]",  "[syn]",  "[etb]",
    "[can]",   "[em]",   "[sub]",  "[esc]",  "[fs]",   "[gs]",   "[rs]",   "[us]",
    "[space]" /* 0x20 */
};

static inline void strlib_aux_format_sS(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec,
    int                width,
    int                left_align,
    int                has_precision,
    int                precision
)
{
    size_t      len = 0;
    const char *str = NULL;
    int         pop = 0;
    if (spec == 'S') {
        str = luaL_tolstring(L, (*arg_idx)++, &len);
        pop = 1;
    } else {
        switch(lua_type(L, *arg_idx)) {
            case LUA_TSTRING:
                str = lua_tolstring(L, (*arg_idx)++, &len);
                break;
            case LUA_TNUMBER:
                str = luaL_tolstring(L, (*arg_idx)++, &len);
                pop = 1;
                break;
            default:
                (*arg_idx)++;
                break;
        }
    }
    if (str) {
        if (has_precision && (size_t) precision < len) {
            len = (size_t) precision;
        }
        if (width == 0) {
            lmt_buffer_add_lstring(b, str, len);
        } else {
            int padding = width - (int) len;
            if (padding > 0) {
                if (! left_align) {
                    lmt_buffer_add_spaces (b, padding);
                    lmt_buffer_add_lstring(b, str, len);
                } else {
                    lmt_buffer_add_lstring(b, str, len);
                    lmt_buffer_add_spaces (b, padding);
                }
            } else {
                lmt_buffer_add_lstring(b, str, len);
            }
        }
    }
    if (pop) {
        lua_pop(L, 1);
    }
}

static inline void strlib_aux_format_qQ(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec
)
{
    if (spec == 'q') {
        switch (lua_type(L, *arg_idx)) {
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, (*arg_idx)++)) {
                    lmt_buffer_add_lstring(b, "true", 4);
                } else {
                    lmt_buffer_add_lstring(b, "false", 5);
                }
                break;
            case LUA_TNUMBER:
                if (lua_isinteger(L, *arg_idx)) {
                    serialize_integer(b, lua_tointeger(L, (*arg_idx)++));
                } else {
                    serialize_double(b, lua_tonumber(L, (*arg_idx)++));
                }
                break;
            case LUA_TNIL:
                lmt_buffer_add_lstring(b, "nil", 3);
                (*arg_idx)++;
                break;
            default:
                {
                    size_t      len = 0;
                    const char *str = lua_tolstring(L, (*arg_idx)++, &len);
                    if (str) {
                        serialize_string(b, str, len);
                    } else {
                        lmt_buffer_add_lstring(b, "\"\"", 2);
                    }
                }
                break;
        }
    } else {
        /* %Q (fast lpeg-style serialize_string) */
        size_t      len = 0;
        const char *str = luaL_tolstring(L, (*arg_idx)++, &len);
        if (str) {
            serialize_string(b, str, len);
        } else {
            lmt_buffer_add_lstring(b, "\"\"", 2);
        }
        lua_pop(L, 1);
    }
}
static inline void strlib_aux_format_aA(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec,
    const char        *sep_str,
    size_t             sep_len
)
{
    char quote = (spec == 'a') ? '\'' : '"';
    switch (lua_type(L, *arg_idx)) {
        case LUA_TNIL:
            goto EMPTY;
        case LUA_TNUMBER:
            {
                if (lua_isinteger(L, *arg_idx)) {
                    serialize_integer(b, lua_tointeger(L, *arg_idx));
                } else if (lmt_buffer_has_room(b, 350)) {
                    b->length += double_to_string_f(lua_tonumber(L, *arg_idx), b->buffer + b->length, 17);
                }
                (*arg_idx)++;
            }
            return;
        case LUA_TBOOLEAN:
            lmt_buffer_add_char(b, quote);
            if (lua_toboolean(L, (*arg_idx)++)) {
                lmt_buffer_add_lstring(b, "true", 4);
            } else {
                lmt_buffer_add_lstring(b, "false", 5);
            }
            lmt_buffer_add_char(b, quote);
            return;
        case LUA_TTABLE:
            {
                lmt_buffer_add_char(b, quote);
                const char *use_sep = (sep_str != NULL) ? sep_str : ",";
                size_t      use_len = (sep_str != NULL) ? sep_len : 1;
                int         tbl_idx = (*arg_idx)++;
             // lua_newtable(L);
             // int         seen = lua_gettop(L);
                strlib_aux_sequenced(L, tbl_idx, b, 0, use_sep, use_len, 0, 0, 1); /* no seen */
             // lua_remove(L, seen);
                lmt_buffer_add_char(b, quote);
            }
            return;
        default:
            {
                size_t      len = 0;
                const char *str = lua_tolstring(L, (*arg_idx)++, &len);
                lmt_buffer_add_char(b, quote);
                if (str && len > 0) {
                    lmt_buffer_add_lstring(b, str, len);
                }
                lmt_buffer_add_char(b, quote);
            }
            return;
    }
  EMPTY:
    lmt_buffer_add_char(b, quote);
    lmt_buffer_add_char(b, quote);
    (*arg_idx)++;
}

static inline void strlib_aux_format_C(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx
)
{
    switch (lua_type(L, *arg_idx)) {
        case LUA_TNUMBER:
            {
                lua_Unsigned code = (lua_Unsigned) lua_tointeger(L, (*arg_idx)++);
                if (code <= 0x20) {
                    lmt_buffer_add_string(b, C_X00_table[code]);
                } else {
                    if (lmt_buffer_has_room(b, 64)) {
                        int len = aux_uni2strlen((unsigned) code, b->buffer + b->length);
                        b->length += len;
                        b->length += snprintf(b->buffer + b->length, 64, " (U+%05X)", (unsigned) code);
                    }
                }
            }
            break;
        case LUA_TSTRING:
            {
                size_t      len = 0;
                const char *str = lua_tolstring(L, (*arg_idx)++, &len);
                if (str && len > 0) {
                    size_t pos  = 0;
                    int    code = strlib_aux_tounicode(str, len, &pos);
                    if (code >= 0 && code <= 0x20) {
                        lmt_buffer_add_string(b, C_X00_table[code]);
                    } else if (code > 0x20 && code <= 0x10FFFF) {
                        if (lmt_buffer_has_room(b, len + 64)) {
                            lmt_buffer_add_lstring(b, str, len);
                            b->length += snprintf( b->buffer + b->length, 64, " (U+%05X)", (unsigned) code);
                        }
                    } else {
                        lmt_buffer_add_lstring(b, str, len);
                        lmt_buffer_add_lstring(b, " (U+FFFD)", 9);
                    }
                }
            }
            break;
        default:
            (*arg_idx)++;
            break;
    }
}

static inline void strlib_aux_format_F(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    int                has_precision,
    int                precision,
    int                width,
    int                pad_zero,
    int                left_align
)
{
    if (lua_type(L, *arg_idx) == LUA_TNUMBER) {
        lua_Number val = lua_tonumber(L, (*arg_idx)++);
        int prc = has_precision ? precision : 9;
        if (lmt_buffer_has_room(b, (size_t) prc + (size_t) width + 350)) {
            char  *s    = b->buffer + b->length;
            size_t room = b->size - b->length;
            int    len  = 0;
            if (! has_precision && val > -0.0000000005 && val < 0.0000000005) {
                s[0] = '0';
                len = 1;
            } else if (fmod(val, 1.0) == 0.0 && val >= -9007199254740992.0 && val <= 9007199254740992.0) {
                len = double_to_string_z(val, s, room, 0);
            } else {
                len = double_to_string_z(val, s, room, prc);
            }
            if (len > 0) {
                strlib_aux_format_padded_float(b, len, width, pad_zero, left_align);
            }
        }
    } else {
        (*arg_idx)++;
    }
}

static inline void strlib_aux_format_eEgG(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec,
    int                width,
    int                pad_zero,
    int                left_align,
    int                has_precision,
    int                precision
)
{
    switch (lua_type(L, *arg_idx)) {
        case LUA_TNUMBER:
            {
                lua_Number val = lua_tonumber(L, (*arg_idx)++);
                int  req_prc  = has_precision ? precision : 6;
                size_t req_room = (width > 0 ? (size_t)width : 0) + (size_t)req_prc + 64;
                if (lmt_buffer_has_room(b, req_room)) {
                    size_t available = b->size - b->length;
                    char fmt_str[32];
                    snprintf(fmt_str, sizeof(fmt_str), "%%%s%s%s.*%c",
                        left_align ? "-" : "",
                        pad_zero   ? "0" : "",
                        width > 0  ? "*" : "",
                        spec
                    );
                    int written;
                    if (width > 0) {
                        written = snprintf(b->buffer + b->length, available, fmt_str, width, req_prc, val);
                    } else {
                        written = snprintf(b->buffer + b->length, available, fmt_str, req_prc, val);
                    }
                    if (written > 0) {
                        size_t add_len = (size_t)written < available ? (size_t)written : available - 1;
                        b->length += add_len;
                    }
                }
            }
            break;
        default:
            (*arg_idx)++;
            break;
    }
}

static inline void strlib_aux_format_jJ(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec,
    int                has_precision,
    int                precision
)
{
    double val    = 0.0;
    int    is_num = 0;
    switch (lua_type(L, *arg_idx)) {
        case LUA_TNUMBER:
            {
                val = lua_tonumber(L, (*arg_idx)++);
                is_num = 1;
            }
            break;
        case LUA_TSTRING:
            {
                /* also string-to-number casting (tonumber(n)) */
                const char *s = lua_tostring(L, *arg_idx);
                char *endptr;
                val = strtod(s, &endptr);
                if (endptr != s && *endptr == '\0') {
                    is_num = 1;
                }
                (*arg_idx)++;
            }
            break;
        default:
            (*arg_idx)++;
            break;
    }
    if (is_num) {
        int    req_precision = strlib_aux_normalize_precision(has_precision ? precision : 6);
        size_t req_room      = (size_t) req_precision + 350;
        if (lmt_buffer_has_room(b, req_room)) {
            int len = double_to_string_j(
                val,
                b->buffer + b->length,
                b->size - b->length, /* Pass true available buffer capacity */
                (spec == 'j') ? 'e' : 'E',
                req_precision
            );
            if (len >= 0) {
                b->length += (size_t) len;
            }
        }
    } else {
        /* fallback to tostring(n) if not a valid number */
        size_t      len = 0;
        const char *str = luaL_tolstring(L, *arg_idx - 1, &len);
        if (str) {
            lmt_buffer_add_lstring(b, str, len);
            lua_pop(L, 1);
        }
    }
}

/* 
    This |%k| one is handy when we want to align (as in tables) so we have an explicit before/after 
    decimal digit width specifiers.

    string.sqformatters["%7.2f"](12.34) --> "  12.34"
    string.sqformatters["%4.2k"](12.34) --> "  12.34"

    %f requiring manual total width calculation: 4 digits before + 1 dot + 2 digits after = 7 total
    %k with explicit before and after widths: %4.2k where before=4, after=2
*/

static inline void strlib_aux_format_left_right(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec,
    int                width,
    int                left_align
)
{
    size_t      len = 0;
    const char *str = NULL;
    int         pop = 0;
    switch (lua_type(L, *arg_idx)) {
        case LUA_TSTRING:
            str = lua_tolstring(L, (*arg_idx)++, &len);
            break;
        case LUA_TNUMBER:
            str = luaL_tolstring(L, (*arg_idx)++, &len);
            pop = 1;
            break;
        default:
            /* ignore non-string types */
            (*arg_idx)++;
            break;
    }
    if (str && len > 0) {
        /* if width == 0 (e.g. %< or %> without width), handle string directly */
        if (width == 0) {
            lmt_buffer_add_lstring(b, str, len);
        } else {
            /* count UTF-8 character length (codepoints) using existing helper */
            size_t utflen = 0;
            size_t ind    = 0;
            while (ind < len) {
                size_t next = ind;
                strlib_aux_tounicode(str, len, &next);
                if (next <= ind) {
                    next = ind + 1;
                }
                ind = next;
                utflen++;
            }
            int target_width     = width;
            int is_right_aligned = (spec == '>');
            /* if flag '-' was supplied (%-10> or %-10<), invert effective alignment direction */
            if (left_align) {
                is_right_aligned = ! is_right_aligned;
            }
            int padding = target_width - (int) utflen;
            if (padding > 0) {
                if (is_right_aligned) {
                    /* spaces before string */
                    lmt_buffer_add_spaces (b, padding);
                    lmt_buffer_add_lstring(b, str, len);
                } else {
                    /* spaces after string */
                    lmt_buffer_add_lstring(b, str, len);
                    lmt_buffer_add_spaces (b, padding);
                }
            } else {
                lmt_buffer_add_lstring(b, str, len);
            }
        }
    }
    if (pop) {
        lua_pop(L, 1);
    }
}

/* plug-in support, watch out, function hook in differently from formatters */

static inline void strlib_aux_format_extension(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    int                top,
    const char        *ext_name,
    size_t             ext_len,
    int                f_width,
    int                has_width
)
{
    /* upvalue 2 is the local extensions table */
    int ext_tbl = lua_upvalueindex(2);
    if (lua_istable(L, ext_tbl)) {
        lua_pushlstring(L, ext_name, ext_len);
        lua_gettable(L, ext_tbl);
    } else {
        lua_pushnil(L);
    }
    if (lua_type(L, -1) == LUA_TFUNCTION) {
        /* not really width but we pass the shared name */
        int f = has_width ? f_width : 1;
        if (f > 0 && *arg_idx <= top) {
            /* push arguments onto the stack for the callback to pick up */
            int args_to_pass = (f > (top - *arg_idx + 1)) ? (top - *arg_idx + 1) : f;
            luaL_checkstack(L, args_to_pass, "too many arguments for format extension");
            for (int i = 0; i < args_to_pass; i++) {
                lua_pushvalue(L, (*arg_idx)++);
            }
            if (lua_pcall(L, args_to_pass, 1, 0) == LUA_OK) {
                size_t      len = 0;
                const char *str = lua_tolstring(L, -1, &len);
                if (str && len > 0) {
                    lmt_buffer_add_lstring(b, str, len);
                }
                lua_pop(L, 1); /* return value */
            } else {
                lua_error(L);
            }
        } else {
            lua_pop(L, 1); /* function */
            (*arg_idx)++;
        }
        return;
    } else {
        /* extension object or nil */
        lua_pop(L, 1);
    }
}

/* %t, %T, %{...}t, %{...}T, %<sep...>t, %<sep...>T (a non table argument is skipped) */

static inline void strlib_aux_format_tT(
    lua_State         *L,
    lmt_string_buffer *b,
    int               *arg_idx,
    char               spec,
    const char        *sep_str,
    size_t             sep_len
)
{
    int tbl_idx = (*arg_idx)++;
    if (lua_istable(L, tbl_idx)) {
        if (spec == 'T') {
            /* capital %T: key=value pairs (hashed/sorted) */
            lua_newtable(L);
            int seen = lua_gettop(L);
            strlib_aux_sequenced(L, tbl_idx, b, 0, sep_str ? sep_str : " | ", sep_str ? sep_len : 3, 0, seen, 1);
            lua_remove(L, seen);
        } else {
            /* lowercase %t: array values (1..n) */
            strlib_aux_array_sequenced(L, tbl_idx, b, sep_str, sep_len);
        }
    }
}

/*tex

    This format helper started out simple with a few keys but as it was relative efficient, I
    stepwise added the various emthods from |string.formatters| which was kind of easy given that 
    we could use gemini to generate the snippets by feeding the \LUA\ code plus a bit of 
    explanation. It took some iterations, testing, fixing, cleanup etc but it was easy to test 
    compatibility. We already had helpers in |auxserialize| that we could use (and a few variants 
    were added). 

    Scanning what comes before a key is kind of messy especially because we need to intercept for
    instance table specific formatters but by adding stepwise we kept it kind of clean im the end. 

    Once all was more or less in place there were various places the code could be made a bit more 
    efficient (avoid scanning etc). A typical case of \quotation {think a bit about improvements} 
    during a long walk. The 0..9 trick for instance permits fast paths for frequently used formats 
    and some more will be added (ones we often use in \CONTEXT). I might spot more locations cq.\ 
    shortcuts. Using the C formatter over the \LUA\ brought processing the manual down from 16 to 
    just over 15 seconds and the test suite from 455 to 415 seconds (2018 laptop running Wwindows 
    11). This is mainly because the backend uses lots of formatting and when \METAPOST\ graphics 
    are converted to \PDF\ we also format a lot. The memory footprint is often a bit smaller too.

*/

 /* todo: don't throw errors, just ignore, we quit anyway so ... */

static void strlib_aux_addformat(
    lua_State         *L,
    lmt_string_buffer *b,
    const char        *fmt,
    size_t             fmt_len,
    int                top,
    int                arg_idx
)
{
    size_t i        = 0;
    size_t start    = 0;
    int    base_idx = arg_idx;

    while (i < fmt_len) {
        if (fmt[i] == '%') {
            /* flush preceding chunk of literal text */
            int d = i - start;
            if (d == 1) {
                 lmt_buffer_add_char(b, (int) fmt[start]);
            } else if (d > 0) {
                 lmt_buffer_add_lstring(b, fmt + start, d);
            }
            /* an incomplete specifier at the end is flushed as it is */
            start = i;
            /* skip '%' and check */
            i++;
            if (i >= fmt_len) {
                break;
            }
            unsigned char spec          = fmt[i];
            int           width         = 0;
            int           pad_zero      = 0;
            int           left_align    = 0;
            int           space_flag    = 0;
            int           precision     = 17;
            int           has_precision = 0;
         // const char   *sep_str       = NULL;
         // size_t        sep_len       = 0;
            /* 
               If the character immediately following '%' is directly  in our list of valid single-character format specifiers, 
               we bypass all flag, width, precision, table, and extension parsing.
            */
            switch (spec) {
                case 0x01: // soh %.1N
                case 0x02: // stx %.2N
                case 0x03: // etx %.3N
                case 0x04: // eot %.4N
                case 0x05: // enq %.5N
                case 0x06: // ack %.6N
                case 0x07: // bel %.7N
                case 0x08: // bs  %.8N
                case 0x09: // ht  %.9N
                    {   
                        /* stripped float (ConTeXt formatters drop-in: strips redundant zeros) */                    
                        lua_Number val = lua_tonumber(L, arg_idx++);
                        if (lmt_buffer_has_room(b, 350)) {
                            b->length += double_to_string_f(val, b->buffer + b->length, spec);
                        }
                    }
                    start = ++i;
                    continue;
             // case 0x0A: // lf
             //     break;
                case 0x0B: // vt  %02i
                case 0x0C: // ff  %03i
             // case 0x0D: // cr
             //     break;
                case 0x0E: // so  %04i
                case 0x0F: // si  %05i
                    {
                        int w = (spec == 0x0B) ? 2 : (spec == 0x0C) ? 3 : (spec == 0x0E) ? 4 : 5;
                        lua_Integer val = lua_tointeger(L, arg_idx++);
                        size_t req_room = (size_t) w + 32;
                        if (lmt_buffer_has_room(b, req_room)) {
                            char fmt_str[32];
                            snprintf(fmt_str, sizeof(fmt_str), "%%0%d" LUA_INTEGER_FRMLEN "d", w);
                            b->length += (size_t) snprintf(b->buffer + b->length, req_room, fmt_str, val);
                        }
                    }
                    start = ++i;
                    continue;
                case 0x10: // dle %02X
                case 0x11: // dc1 %03X
                case 0x12: // dc2 %04X
                case 0x13: // dc3 %05X
                case 0x14: // dc4 %06X
                case 0x15: // nak %07X
                case 0x16: // syn %08X
                   {
                        int w = spec - 0x0E;
                        lua_Unsigned val = (lua_Unsigned) lua_tointeger(L, arg_idx++);
                        int min_digits = w;
                        char               temp[32];
                        int                len         = 0;
                        do {
                            temp[len++] = hex_upper[val & 0x0F];
                            val >>= 4;
                        } while (val > 0);
                        int total_len = (len < min_digits) ? min_digits : len;
                        if (lmt_buffer_has_room(b, total_len)) {
                            for (int z = 0; z < total_len - len; z++) {
                                b->buffer[b->length++] = '0';
                            }
                            while (len > 0) {
                                b->buffer[b->length++] = temp[--len];
                            }
                        }
                    }
                    start = ++i;
                    continue;
                case 0x17: // etb (%.6N,%.6N)
                    {   
                        lua_Number v1 = lua_tonumber(L, arg_idx++); if (arg_idx > top) { break; }
                        lua_Number v2 = lua_tonumber(L, arg_idx++);
                        if (lmt_buffer_has_room(b, 350 + 350 + 3)) {
                            lmt_buffer_add_char_ok(b,'(');
                            b->length += double_to_string_f(v1, b->buffer + b->length, 6);
                            lmt_buffer_add_char_ok(b,',');
                            b->length += double_to_string_f(v2, b->buffer + b->length, 6);
                            lmt_buffer_add_char_ok(b,')');
                        }
                    }
                    start = ++i;
                    continue;
                case 0x18: // can (%.6N,%.6N,%.6N)
                case 0x1A: // sub (%.3N,%.3N,%.3N)
                    {   
                        lua_Number v1 = lua_tonumber(L, arg_idx++); if (arg_idx > top) { break; }
                        lua_Number v2 = lua_tonumber(L, arg_idx++); if (arg_idx > top) { break; }
                        lua_Number v3 = lua_tonumber(L, arg_idx++);
                        if (lmt_buffer_has_room(b, 350 * 3 + 4)) {
                            int precision = spec == 0x18 ? 6 : 3;
                            lmt_buffer_add_char_ok(b,'(');
                            b->length += double_to_string_f(v1, b->buffer + b->length, precision);
                            lmt_buffer_add_char_ok(b,',');
                            b->length += double_to_string_f(v2, b->buffer + b->length, precision);
                            lmt_buffer_add_char_ok(b,',');
                            b->length += double_to_string_f(v3, b->buffer + b->length, precision);
                            lmt_buffer_add_char_ok(b,')');
                        }
                    }
                    start = ++i;
                    continue;
                case 0x19: // em (%.3N)
                    {   
                        lua_Number v1 = lua_tonumber(L, arg_idx++);
                        if (lmt_buffer_has_room(b, 350 + 2)) {
                            lmt_buffer_add_char_ok(b,'(');
                            b->length += double_to_string_f(v1, b->buffer + b->length, 3);
                            lmt_buffer_add_char_ok(b,')');
                        }
                    }
                    start = ++i;
                    continue;
                case 0x1B: // esc (%.3N,%.3N,%.3N,%.3N)
                    {   
                        lua_Number v1 = lua_tonumber(L, arg_idx++); if (arg_idx > top) { break; }
                        lua_Number v2 = lua_tonumber(L, arg_idx++); if (arg_idx > top) { break; }
                        lua_Number v3 = lua_tonumber(L, arg_idx++); if (arg_idx > top) { break; }
                        lua_Number v4 = lua_tonumber(L, arg_idx++);
                        if (lmt_buffer_has_room(b, 350 * 4 + 5)) {
                            lmt_buffer_add_char_ok(b,'(');
                            b->length += double_to_string_f(v1, b->buffer + b->length, 3);
                            lmt_buffer_add_char_ok(b,',');
                            b->length += double_to_string_f(v2, b->buffer + b->length, 3);
                            lmt_buffer_add_char_ok(b,',');
                            b->length += double_to_string_f(v3, b->buffer + b->length, 3);
                            lmt_buffer_add_char_ok(b,',');
                            b->length += double_to_string_f(v4, b->buffer + b->length, 3);
                            lmt_buffer_add_char_ok(b,')');
                        }
                    }
                    start = ++i;
                    continue;
             // case 0x1C: // fs %-15s
             // case 0x1D: // gs %--t
             // case 0x1E: // rs %s
             // case 0x1F: // us %...
                case 'a': case 'A':
                    strlib_aux_format_aA(L, b, &arg_idx, spec, NULL, 0);
                    start = ++i;
                    continue;
                case 't': case 'T':
                    strlib_aux_format_tT(L, b, &arg_idx, spec, NULL, 0);
                    start = ++i;
                    continue;
                case '{':
                    {
                        /* braces are only used for a table separator: %{...}t or %{...}T */
                        size_t close = i + 1;
                        while (close < fmt_len && fmt[close] != '}') {
                            close++;
                        }
                        if (close + 1 < fmt_len) { 
                            switch (fmt[close + 1]) { 
                                case 't': case 'T':
                                    strlib_aux_format_tT(L, b, &arg_idx, fmt[close + 1], fmt + i + 1, close - i - 1);
                                    start = i = close + 2;
                                    continue;
                                case 'a': case 'A':
                                    strlib_aux_format_aA(L, b, &arg_idx, fmt[close + 1], fmt + i + 1, close - i - 1);
                                    start = i = close + 2;
                                    continue;
                                default:
                                    break;
                            }
                        }
                    }
                    break;
                case 'b': case 'B':
                case 'c': case 'C':
             // case 'd': case 'D': /* 'D' not used */
                case 'd':
                case 'e': case 'E':
                case 'f': case 'F':
                case 'g': case 'G':
                case 'h': case 'H':
                case 'i': case 'I':
                case 'j': case 'J':
                case 'k': case 'K':
                case 'l': case 'L':
             // case 'm': case 'M': /* 'M' not used */
                case 'm':
                case 'n': case 'N':
             // case 'o': case 'O': /* 'O' not used */
                case 'o':
                case 'p': case 'P':
                case 'q': case 'Q':
                case 'r': case 'R':
                case 's': case 'S':
             // case 't': case 'T': /* see above */
                case 'u': case 'U':
                case 'v': case 'V':
             // case 'w': case 'W': /* see below */
                case 'W':
                case 'x': case 'X':
             // case 'z': case 'Z': /* see below */
                case 'Z':
                case '<': case '>':
                    i++;
                    goto SWITCH;
                default:
                    break;
            }
            /*             
                Fast check for %!extension_name! or %1!extension_name! We must check this before 
                table checks so that extension names ending in 't' (like !tex!) are not 
                incorrectly captured as table formatters. Only consume digits if a '!' is actually
                present ahead, preventing standard flags/widths (like %09i) from being swallowed 
                prematurely.
            */
            {
                size_t scan = i;
                int has_extension = 0;
                while (scan < fmt_len && fmt[scan] >= '0' && fmt[scan] <= '9') {
                    scan++;
                }
                if (scan < fmt_len && fmt[scan] == '!') {
                    has_extension = 1;
                }

                if (has_extension) {
                    int pre_val = 0;
                    int has_pre = 0;
                    while (i < fmt_len && fmt[i] >= '0' && fmt[i] <= '9') {
                        pre_val = strlib_aux_parse_decimal(pre_val, fmt[i] - '0');
                        has_pre = 1;
                        i++;
                    }
                    if (i < fmt_len && fmt[i] == '!') {
                        size_t ext_start = i + 1;
                        i++;
                        while (i < fmt_len && fmt[i] != '!') {
                            i++;
                        }
                        if (i < fmt_len && fmt[i] == '!') {
                            const char *ext_name = fmt + ext_start;
                            size_t      ext_len  = i - ext_start;
                            i++; /* skip ending '!' */
                            strlib_aux_format_extension(L, b, &arg_idx, top, ext_name, ext_len, pre_val, has_pre);
                            start = i;
                            continue;
                        }
                    }
                }
            }

            /* check for %<sep...>t, %<sep...>T, %<sep...>a, %<sep...>A (plain and braced tables are handled above) */

            if (i < fmt_len) {

                size_t scan = i;

                while (scan < fmt_len) {
                    unsigned char c = fmt[scan];
                    if (
                        (c >= 'a' && c <= 'z') || 
                        (c >= 'A' && c <= 'Z') || 
                        (c >= '0' && c <= '9') || 
                         c == '%' || c == '{'
                    ) {
                        break;
                    }
                    scan++;
                }

                /* */

                if (scan < fmt_len) {
                    char target_c = fmt[scan];
                    if (target_c == 't' || target_c == 'T') {
                        strlib_aux_format_tT(L, b, &arg_idx, target_c, fmt + i, scan - i);
                        start = i = scan + 1; /* Skip separator string and 't'/'T' */
                        continue;
                    } else if (target_c == 'a' || target_c == 'A') {
                     // sep_str = fmt + i;
                     // sep_len = scan - i;
                     // i = scan; /* Skip separator string, leave 'a'/'A' for switch */
                        strlib_aux_format_aA(L, b, &arg_idx, target_c, fmt + i, scan - i);
                        start = i = scan + 1; /* Skip separator string and 'a'/'A' */
                        continue;
                    }
                }
            }
            /* single-pass flag scanning */
            while (i < fmt_len) {
                char c = fmt[i];
                if (c == '-') {
                    left_align = 1;
                    i++;
                } else if (c == '0') {
                    pad_zero = 1;
                    i++;
                } else if (c == ' ' || c == '\xA0') {
                    space_flag = 1;
                    i++;
                } else {
                    break;
                }
            }
            /* width parsing loop */
            if (width == 0) {
                while (i < fmt_len) {
                    char c = fmt[i];
                    if (c >= '0' && c <= '9') {
                        width = strlib_aux_parse_decimal(width, c - '0');
                        i++;
                    } else {
                        break;
                    }
                }
            }
            /* precision parsing loop */
            if (i < fmt_len && fmt[i] == '.') {
                i++;
                precision     = 0;
                has_precision = 1;
                while (i < fmt_len) {
                    char c = fmt[i];
                    if (c >= '0' && c <= '9') {
                        precision = strlib_aux_parse_decimal(precision, c - '0');
                        i++;
                    } else {
                        break;
                    }
                }
            }
            /* sanity check */
            if (i >= fmt_len) {
                break;
            }
            precision = strlib_aux_normalize_precision(precision);
            spec      = fmt[i++];

        SWITCH:

            switch (spec) {
                /* exceptions: specifiers that do not consume an argument */
                case '%':
                    lmt_buffer_add_char(b, '%');
                    break;
                case 'z':
                    arg_idx += (width > 0) ? width : 1;
                    break;
                case 'Z':
                    if (width > 0 && width <= 100) {
                        size_t      len;
                        const char *str = lua_tolstring(L, base_idx + width - 1, &len);                        
                        if (len > 0 && str) {
                            lmt_buffer_add_lstring(b, str, len);
                        }
                    }
                    break;
                default:
                    if (arg_idx <= top) {
                        switch (spec) {
                            /* integer with zero-padding support */
                            case 'I':
                            case 'i':
                            case 'd':
                                {
                                    lua_Integer  val      = lua_tointeger(L, arg_idx++);
                                    int          is_plus  = (spec == 'I' && val >= 0);
                                    int          is_space = (space_flag && !is_plus && val >= 0);
                                    int          is_neg   = (val < 0);        
                                    lua_Unsigned uval     = is_neg ? (lua_Unsigned) (-(val + 1)) + 1 : (lua_Unsigned) val;        
                                    char temp[32];
                                    int len = 0;
                                    do {
                                        temp[len++] = '0' + (char) (uval % 10);
                                        uval /= 10;
                                    } while (uval > 0);        
                                    const char *prefix     = NULL;
                                    size_t      prefix_len = 0;
                                    char sign_char[1];
                                    if (is_neg) {
                                        sign_char[0] = '-'; prefix = sign_char; prefix_len = 1;
                                    } else if (is_plus) {
                                        sign_char[0] = '+'; prefix = sign_char; prefix_len = 1;
                                    } else if (is_space) {
                                        sign_char[0] = ' '; prefix = sign_char; prefix_len = 1;
                                    }
                                    if (spec == 'I' && prefix) {
                                        /* as in the \LUA\ formatter the sign is not part of the width */
                                        lmt_buffer_add_char(b, sign_char[0]);
                                        prefix_len = 0;
                                    }
                                    strlib_aux_format_padded_number(b, prefix, prefix_len, temp, len, width, precision, has_precision, pad_zero, left_align);
                                }
                                break;
                            /* float */
                            case 'f':
                                {
                                    lua_Number val = lua_tonumber(L, arg_idx++);
                                    int        prc = has_precision ? precision : 6;
                                    if (lmt_buffer_has_room(b, (size_t) prc + (size_t) width + 350)) {
                                        int len = double_to_string_z(val, b->buffer + b->length, b->size - b->length, prc);
                                        if (len > 0) {
                                            strlib_aux_format_padded_float(b, len, width, pad_zero, left_align);
                                        }
                                    }
                                }
                                break;
                            /* checked float: near-zero clamping & exact integer conversion */
                            case 'F':
                                strlib_aux_format_F(L, b, &arg_idx, has_precision, precision, width, pad_zero, left_align);
                                break;
                            /* stripped float without redundant zeros */                    
                            case 'n':
                            case 'N':
                                {
                                    char       temp[350];
                                    lua_Number val = lua_tonumber(L, arg_idx++);
                                    int        len = double_to_string_f(val, temp, has_precision ? precision : 9);
                                    if (len > 0) {
                                        strlib_aux_format_padded_string(b, temp, len, width, left_align);
                                    }
                                }
                                break;
                            /* exponential & shortest float (%e, %E, %g, %G) */
                            case 'e':
                            case 'E':
                            case 'g':
                            case 'G':
                                strlib_aux_format_eEgG(L, b, &arg_idx, spec, width, pad_zero, left_align, has_precision, precision);
                                break;
                            /* sparse exponential float (%j / %J) */
                            case 'j':
                            case 'J':
                                strlib_aux_format_jJ(L, b, &arg_idx, spec, has_precision, precision);
                                break;
                            /* tex|postscript points */
                            case 'p':
                                {
                                    lua_Number val = lua_tonumber(L, arg_idx++) / 65536.0;
                                    if (lmt_buffer_has_room(b, 350)) {
                                        b->length += double_to_string_f(val, b->buffer + b->length, 5);
                                        lmt_buffer_add_lstring(b,"pt", 2);
                                    }
                                }
                                break;
                            case 'P':
                                {
                                    lua_Number val = lua_tonumber(L, arg_idx++) / 65536.0;
                                    strlib_aux_add_z(b, val, 5);
                                }
                                break;
                            case 'b':
                                {
                                    lua_Number val = (lua_tonumber(L, arg_idx++) * (7200.0 / 7227.0)) / 65536.0;
                                    if (lmt_buffer_has_room(b, 350)) {
                                        b->length += double_to_string_f(val, b->buffer + b->length, 5);
                                        lmt_buffer_add_lstring(b,"bp", 2);
                                    }
                                    break;
                                }
                            case 'B':
                                {
                                    lua_Number val = (lua_tonumber(L, arg_idx++) * (7200.0 / 7227.0)) / 65536.0;
                                    strlib_aux_add_z(b, val, 5);
                                }
                                break;
                            /* rounded float (%r) using custom auxserialize routine */
                            case 'r':
                                {
                                    lua_Number val = lua_tonumber(L, arg_idx++);
                                    if (lmt_buffer_has_room(b, 350)) {
                                        b->length += double_to_string_r(val, b->buffer + b->length);
                                    }
                                }
                                break;
                            /* formatted float with before/after widths (%k) */
                            case 'k':
                                {
                                    if (lua_type(L, arg_idx) == LUA_TNUMBER) {
                                        lua_Number val           = lua_tonumber(L, arg_idx++);
                                        int        digits_before = width;
                                        int        digits_after  = has_precision ? precision : 0;
                                        int        total_width   = digits_before;
                                        if (digits_after > INT_MAX - total_width) {
                                            total_width = INT_MAX;
                                        } else {
                                            total_width += digits_after;
                                            if (digits_after > 0 && total_width < INT_MAX) {
                                                total_width++;
                                            }
                                        }
                                        size_t req_room = (size_t) total_width + 350;
                                        if (lmt_buffer_has_room(b, req_room)) {
                                            char fmt_str[32];
                                            snprintf(fmt_str, sizeof(fmt_str), "%%%d.%df", total_width, digits_after);
                                            b->length += (size_t) snprintf(b->buffer + b->length, req_room, fmt_str, val);
                                        }
                                    } else {
                                        arg_idx++; /* skip non-number argument */
                                    }
                                }
                                break;
                            /* prefixed hexadecimal variants (U+, u+, 0x) */
                            case 'U':
                            case 'u':
                            case 'H':
                            case 'h':
                                {
                                    if (! width) {
                                        pad_zero = 1;
                                        width    = 5;
                                    }
                                    char         temp[32];
                                    const char  *prefix = (spec == 'U') ? "U+" : (spec == 'u') ? "u+" : "0x";
                                                 spec   = (spec == 'U' || spec == 'H') ? 'X' : 'x';
                                    lua_Unsigned val    = (lua_Unsigned) lua_tointeger(L, arg_idx++);
                                    int          len    = 0;
                                    const char  *digits = (spec == 'X') ? hex_upper : hex_lower;
                                    do {
                                        temp[len++] = digits[val & 0x0F];
                                        val >>= 4;
                                    } while (val > 0);
                                    /* as in the \LUA\ formatter the prefix is not part of the width */
                                    lmt_buffer_add_lstring(b, prefix, 2);
                                    strlib_aux_format_padded_number(b, NULL, 0, temp, len, width, precision, has_precision, pad_zero, left_align);
                                }
                                break;
                            /* standard hexadecimal (%x, %X) */
                            case 'x':
                            case 'X':
                                {
                                    char         temp[32];
                                    lua_Unsigned val    = (lua_Unsigned) lua_tointeger(L, arg_idx++);
                                    int          len    = 0;
                                    const char  *digits = (spec == 'X') ? hex_upper : hex_lower;
                                    do {
                                        temp[len++] = digits[val & 0x0F];
                                        val >>= 4;
                                    } while (val > 0);

                                    strlib_aux_format_padded_number(b, NULL, 0, temp, len, width, precision, has_precision, pad_zero, left_align);
                                }
                                break;
                            /* string formatting: %s (selective/direct) & %S (forced tostring) */
                            case 's':
                            case 'S':
                                strlib_aux_format_sS(L, b, &arg_idx, spec, width, left_align, has_precision, precision);
                                break;
                            /* quoted string formatting: %q (nil-safe standard Lua %q) & %Q (fast LPeg-style serialize_string) */
                            case 'q':
                            case 'Q':
                                strlib_aux_format_qQ(L, b, &arg_idx, spec);
                                break;
                            /* boolean (logic) */
                            case 'l':
                            case 'L':
                                {
                                    int val = lua_toboolean(L, arg_idx++);
                                    if (val) {
                                        lmt_buffer_add_lstring(b, spec == 'l' ? "true"  : "TRUE",  4);
                                    } else {
                                        lmt_buffer_add_lstring(b, spec == 'l' ? "false" : "FALSE", 5);
                                    }
                                }
                                break;
                            /* utf8 character */
                            case 'c':
                                {
                                    char         buffer[8];
                                    lua_Unsigned val = (lua_Unsigned) lua_tointeger(L, arg_idx++);
                                    int          len = aux_uni2strlen((unsigned) val, buffer);
                                    if (len) {
                                        lmt_buffer_add_lstring(b, buffer, len);
                                    }
                                }
                                break;
                            /* traced unicode character (%C) */
                            case 'C':
                                strlib_aux_format_C(L, b, &arg_idx);
                                break;
                            /* octal */
                            case 'o':
                                {
                                    char         temp[32];
                                    lua_Unsigned val = (lua_Unsigned) lua_tointeger(L, arg_idx++);
                                    int          len = 0;
                                    do {
                                        temp[len++] = '0' + (val & 0x07);
                                        val >>= 3;
                                    } while (val > 0);

                                    strlib_aux_format_padded_number(b, NULL, 0, temp, len, width, precision, has_precision, pad_zero, left_align);
                                }
                                break;
                            /* spaces/width padding helper (ConTeXt formatters compatibility) */
                            case 'w':
                            case 'W':
                                {
                                    int count = width;
                                    /* if no explicit width in specifier (e.g. %w instead of %12w), take from argument stack */
                                    if (count <= 0) {
                                        count = (int) lua_tointeger(L, arg_idx++);
                                    }
                                    if (count > 0) {
                                        lmt_buffer_add_spaces(b, count);
                                    }
                                }
                                break;
                            /* money with period or commas and optional thousand separators */
                            case 'm':
                            case 'M':
                                {
                                    lua_Number  val = lua_tonumber(L, arg_idx++);
                                    char        decimal_sep = (spec == 'm') ? '.' : ',';
                                    const char *thousand_sep;
                                    size_t      thousand_sep_len;
                                    if (space_flag) {
                                        /* if space flag was present (% m), use space as thousand separator */
                                        thousand_sep     = " ";
                                        thousand_sep_len = 1;
                                    } else {
                                        /* default: %m -> ',', %M -> '.' */
                                        thousand_sep     = (spec == 'm') ? "," : ".";
                                        thousand_sep_len = 1;
                                    }
                                    /* we can have 309 digits plus separators */
                                    if (lmt_buffer_has_room(b, 512)) {
                                        b->length += double_to_string_m(val, b->buffer + b->length, thousand_sep, thousand_sep_len, decimal_sep);
                                    }
                                }
                                break;
                            /* grouped integer (%v / %V) */
                            case 'v':
                            case 'V':
                                {
                                    const char *thousand_sep;
                                    size_t      thousand_sep_len;
                                    if (space_flag) {
                                        thousand_sep     = " ";
                                        thousand_sep_len = 1;
                                    } else {
                                        thousand_sep     = (spec == 'v') ? "," : ".";
                                        thousand_sep_len = 1;
                                    }
                                    lua_Integer val = lua_tointeger(L, arg_idx++);
                                    if (lmt_buffer_has_room(b, 350)) {
                                        b->length += integer_to_string_v(val, b->buffer + b->length, thousand_sep, thousand_sep_len);
                                    }
                                }
                                break;
                            /* UTF-8 character-aware padding (%< and %>) */
                            case '<':
                            case '>':
                                strlib_aux_format_left_right(L, b, &arg_idx, spec, width, left_align);
                                break;
                            default:
                                lmt_buffer_add_char(b, '%');
                                lmt_buffer_add_char(b, spec);
                                break;
                        }
                    } else {
                        arg_idx++;
                    }
                    break;
            }
            start = i;
        } else {
            i++;
        }
    }
    /* flush remaining literal tail */
    int d = i - start;
    if (d == 1) {
        lmt_buffer_add_char(b, (int) fmt[start]);
    } else if (d > 0) {
        lmt_buffer_add_lstring(b, fmt + start, d);
    }
}

/* 
    1  : buffer userdata 
    2  : format string 
    3+ : arguments 
*/

static int strlib_buffer_addformat(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        size_t      len;
        const char *fmt = luaL_checklstring(L, 2, &len);
        int         top = lua_gettop(L);
        strlib_aux_addformat(L, b, fmt, len, top, 3);
    }
    return 0;
}

/* 
    1  : format string 
    2+ : arguments 
*/

# define buffer_stack_size  8 /* this should be enough, but we need to keep an eye on it */

/* 
    We use a bitmap to track which slots [0..7] are in use (a pool), but we can also use a 'depth' 
    counter.

    An error (in a |__tostring| metamethod, an extension, a memory issue) bypasses the release of
    a slot. Because a nested call always runs at a deeper \CCODE\ call level (we never yield while
    formatting), a slot that was taken at the same or a deeper level than the current one can no
    longer be in use, so then we can just take it over.
*/

typedef struct lmt_buffer_stack {
    lmt_string_buffer buffers[buffer_stack_size];
    unsigned int      levels[buffer_stack_size];
    unsigned int      active_mask;
} lmt_buffer_stack;

static inline int lmt_buffer_stack_get(lua_State *L, lmt_buffer_stack *bs, lmt_string_buffer **out_b)
{
    unsigned int level = getCcalls(L);
    /* locate the first available (or abandoned) zero-indexed slot */
    for (int i = 0; i < buffer_stack_size; i++) {
        if (! ((bs->active_mask >> i) & 1) || bs->levels[i] >= level) {
            bs->active_mask |= (1U << i);
            bs->levels[i] = level;
            lmt_string_buffer *b = &bs->buffers[i];
            if (! b->buffer) {
                b->size   = default_format_size;
                b->length = 0;
                b->buffer = (char *) lmt_memory_malloc(b->size);
                b->step   = 0;
            } else if (b->size < default_format_size) {
                /* we need to guarantee that b->size is never zero or too small on reuse */
                b->size   = default_format_size;
                b->buffer = (char *) lmt_memory_realloc(b->buffer, b->size);
            }
            b->length = 0;
            b->L      = L;
            *out_b    = b;
            return i; /* Returns zero-based index 0, 1, 2... */
        }
    }
    /* when all stack slots are exhausted we just allocate */
    lmt_string_buffer *b = (lmt_string_buffer *) lmt_memory_malloc(sizeof(lmt_string_buffer));
    b->size   = default_format_size;
    b->length = 0;
    b->buffer = (char *) lmt_memory_malloc(b->size);
    b->step   = 0;
    b->L      = L;
    *out_b    = b;
    return -1; /* -1 indicates dynamic fallback */
}

static inline void lmt_buffer_stack_release(lmt_buffer_stack *bs, int stack_idx, lmt_string_buffer *b)
{
    if (stack_idx >= 0 && stack_idx < buffer_stack_size) {
        /* Clear the bit for this zero-indexed slot */
        bs->active_mask &= ~(1U << stack_idx);
    } else {
        /* Clean up dynamic fallback allocation */
        if (b->buffer) {
            lmt_memory_free(b->buffer);
        }
        lmt_memory_free(b);
    }
}

static int strlib_format_buffer_gc(lua_State *L)
{
    lmt_buffer_stack *bs = (lmt_buffer_stack *) lua_touserdata(L, 1);
    if (bs) {
        for (int i = 0; i < buffer_stack_size; i++) {
            if (bs->buffers[i].buffer) {
                lmt_memory_free(bs->buffers[i].buffer);
                bs->buffers[i].buffer = NULL;
            }
        }
    }
    return 0;
}

static int strlib_format(lua_State *L)
{
    /* upfront validation (safe to throw errors) */
    size_t             len;
    const char        *fmt       = luaL_checklstring(L, 1, &len);
    int                top       = lua_gettop(L);
    /* acquire buffer from stack */
    lmt_buffer_stack  *bs        = (lmt_buffer_stack *) lua_touserdata(L, lua_upvalueindex(3));
    lmt_string_buffer *b         = NULL;
    int                stack_idx = lmt_buffer_stack_get(L, bs, &b);
    /* pure formatting (fmt and top are pre-passed) */
    strlib_aux_addformat(L, b, fmt, len, top, 2);
    lua_pushlstring(L, b->buffer, b->length);    
    /* cleanup/reset buffer if it grew too large */
    if (b->length > default_format_size && stack_idx >= 0) {
        lmt_memory_free(b->buffer);
        b->buffer = (char *) lmt_memory_malloc(default_format_size);
        b->size   = default_format_size;
        b->length = 0;
    }    
    /* when an error bypasses this, the slot is taken over later (see above) */ 
    lmt_buffer_stack_release(bs, stack_idx, b);
    return 1;
}

/*tex

    When we checked this file with Luna (on Mikaels machine) it suggested checking for cycles, 
    something we explicitly had removed when going from \LUA\ to \CCODE. Anyway, it's now an 
    option, with basically zero overhead when not enabled. In \CONTEXT\ we never have these cycles
    but in our inspector we enable the check. 

    We also checked with Claude and it fixed some edge cases, especially stack safeguards, although
    it's is unlikely that we nest too deep or crash on memory (it actually ran quite some tests 
    comparing the old and new methods, unsupported features, real applications in \CONTEXT, so it
    compafed \PDF\ files that we generate, etc. It also did ASANmemorty checks with a special 
    build. 


*/

static inline int  strlib_aux_serialize_enter(lua_State *L, int index, int seen, int depth);
static inline void strlib_aux_serialize_leave(lua_State *L, int index, int seen);

static void strlib_aux_tostring(lua_State *L, lmt_string_buffer *b, int index, int seen, int depth)
{
    index = lua_absindex(L, index);
    switch (lua_type(L, index)) {
        case LUA_TSTRING:
            {
                size_t      len;
                const char *str = lua_tolstring(L, index, &len);
                lmt_buffer_add_lstring(b, str, len);
                break;
            }
        case LUA_TNUMBER:
            if (lua_isinteger(L, index)) {
                serialize_integer(b, lua_tointeger(L, index));
            } else if (lmt_buffer_has_room(b, 350)) {
                b->length += double_to_string_f(lua_tonumber(L, index), b->buffer + b->length, 17);
            }
            break;
        case LUA_TBOOLEAN:
            if (lua_toboolean(L, index)) {
                lmt_buffer_add_lstring(b, "true", 4);
            } else {
                lmt_buffer_add_lstring(b, "false", 5);
            }
            break;
        case LUA_TTABLE:
            {
                if (! strlib_aux_serialize_enter(L, index, seen, depth)) {
                    lmt_buffer_add_lstring(b, "nil", 3);
                    break;
                }
                /* todo: sorted hash */
                lua_Unsigned n = lua_rawlen(L, index);
                if (n > 0) {
                    for (lua_Unsigned i = 1; i <= n; i++) {
                        lua_rawgeti(L, index, (lua_Integer) i);
                        strlib_aux_tostring(L, b, lua_gettop(L), seen, depth + 1);
                        lua_pop(L, 1);
                    }
                }
                strlib_aux_serialize_leave(L, index, seen);
                break;
            }
        default:
            break;
    }
}

static int strlib_tostring(lua_State *L)
{
    lmt_buffer_stack  *bs        = (lmt_buffer_stack *) lua_touserdata(L, lua_upvalueindex(3));
    lmt_string_buffer *b         = NULL;
    int                stack_idx = lmt_buffer_stack_get(L, bs, &b);
    int                top       = lua_gettop(L);
# if 0
    int                seen      = 0;
    lua_newtable(L);
    seen = lua_gettop(L);
    for (int i = 1; i <= top; i++) {
        strlib_aux_tostring(L, b, i, seen, 1);
    }
    lua_remove(L, seen);
# else 
    for (int i = 1; i <= top; i++) {
        strlib_aux_tostring(L, b, i, 0, 1);
    }
# endif 
    lua_pushlstring(L, b->buffer, b->length);
    if (b->length > default_format_size && stack_idx >= 0) {
        lmt_memory_free(b->buffer);
        b->buffer = (char *) lmt_memory_malloc(default_format_size);
        b->size   = default_format_size;
        b->length = 0;
    }
    lmt_buffer_stack_release(bs, stack_idx, b);
    return 1;
}

/* 
    An easy one, no escaping etc.: 

    1 : buffer 
    2 : string 
    3 : [offset (1-based)]
    4 : [length]
*/

static int strlib_buffer_addbytes(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        size_t      len;
        const char *str = lua_tolstring(L, 2, &len);
        if (str) {
            lua_Integer start = luaL_optinteger(L, 3, 1);
            if (start > 0) {
                lua_Unsigned offset_value = (lua_Unsigned) (start - 1);
                if (offset_value < (lua_Unsigned) len) {
                    size_t      offset = (size_t) offset_value;
                    lua_Integer length;
                    if (lua_isnoneornil(L, 4)) {
                        length = (lua_Integer) (len - offset);
                    } else {
                        length = luaL_checkinteger(L, 4);
                    }
                    if (length > 0) {
                        size_t available = len - offset;
                        size_t count     = (lua_Unsigned) length > (lua_Unsigned) available
                            ? available
                            : (size_t) length;
                        lmt_buffer_add_lstring(b, str + offset, count);
                    }
                }
            }
        }
    }
    return 0;
}

/*
    A bit like lua pack but simple (we have plenty helpers elsewhere): 

    1 : buffer
    2 : format character ('b', 'w', 'l', 'q' or 'W', 'L', 'Q' for Big Endian)
    3 : integer
*/

static int strlib_buffer_addpacking(lua_State *L)
{
    lmt_string_buffer *b = strlib_buffer_instance(L);
    if (b) {
        const char *fmt = lua_tostring(L, 2);
        if (!fmt) return 0;

        lua_Integer val = lua_tointeger(L, 3);

        switch (fmt[0]) {
            case 'b': /* 8-bit uint */
            case 'B':
                if (lmt_buffer_has_room(b, 1)) {
                    b->buffer[b->length++] = (char) (val & 0xFF);
                }
                break;
            case 'w': /* 16-bit Little Endian */
                if (lmt_buffer_has_room(b, 2)) {
                    b->buffer[b->length++] = (char)  (val       & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 8) & 0xFF);
                }
                break;
            case 'W': /* 16-bit Big Endian */
                if (lmt_buffer_has_room(b, 2)) {
                    b->buffer[b->length++] = (char) ((val >> 8) & 0xFF);
                    b->buffer[b->length++] = (char)  (val       & 0xFF);
                }
                break;
            case 'l': /* 32-bit Little Endian */
                if (lmt_buffer_has_room(b, 4)) {
                    b->buffer[b->length++] = (char)  (val        & 0xFF);
                    b->buffer[b->length++] = (char) ((val >>  8) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 16) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 24) & 0xFF);
                }
                break;
            case 'L': /* 32-bit Big Endian */
                if (lmt_buffer_has_room(b, 4)) {
                    b->buffer[b->length++] = (char) ((val >> 24) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 16) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >>  8) & 0xFF);
                    b->buffer[b->length++] = (char)  (val        & 0xFF);
                }
                break;
            case 'q': /* 64-bit Little Endian */
                if (lmt_buffer_has_room(b, 8)) {
                    b->buffer[b->length++] = (char)  (val        & 0xFF);
                    b->buffer[b->length++] = (char) ((val >>  8) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 16) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 24) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 32) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 40) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 48) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 56) & 0xFF);
                }
                break;
            case 'Q': /* 64-bit Big Endian */
                if (lmt_buffer_has_room(b, 8)) {
                    b->buffer[b->length++] = (char) ((val >> 56) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 48) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 40) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 32) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 24) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >> 16) & 0xFF);
                    b->buffer[b->length++] = (char) ((val >>  8) & 0xFF);
                    b->buffer[b->length++] = (char)  (val        & 0xFF);
                }
                break;
            default:
                break;
        }
    }
    return 0;
}

/*tex
    We now come to the table serializers. We need to retain the same sorting as the original \LUA\
    variant. This evolved a bit.
*/

# define lmt_key_default 64

/*tex 

    We don't need (have) long strings, so a 32 bit integer is okay for the length. The sort type 
    also dictates the  order. It's hard to measure gain but on various large tables we're about 
    5 times as as efficient as the original \LUA\ variant that we had around for about two 
    decades. I might (as experiment bring back hex indexes but then we also need control over 
    specific fields so plenty of extra overhead). 

    There is quite a bit of repetition in the code below but so is in the \LUA\ originals. When 
    implementing this kind of code one has to test compatibility and I think we're fine. The 
    integer check when we have a double is actually better so we acoid hex floats when possible. 

    For sure this will evolve a bit more. I also need to check this with the key sorters elsewhere
    as they were the starting point but became a bit redundant now. But one step at a time (after 
    all we've been fine for quite a while now.)

    Capitalized like LUA_T....:
*/ 

typedef enum lmt_sort_type {
    LMT_TYPE_NIL = 0,  // serialized tables normally have sane keys 
    LMT_TYPE_FALSE,    // 0 integer 
    LMT_TYPE_TRUE,     // 1 integer 
    LMT_TYPE_INTEGER,  // NN
    LMT_TYPE_DOUBLE,   // NN.MM after NN 
    LMT_TYPE_STRING,
    /* not used as key in a serialize */
    LMT_TYPE_TABLE,
    LMT_TYPE_FUNCTION,
    LMT_TYPE_USERDATA,
} lmt_sort_type;

typedef struct lmt_serialize_sort_data {
    uint32_t        type;          /* 4 bytes */
    uint32_t        string_length; /* 4 bytes */
    union {                        /* 8 bytes */
        lua_Integer integer_value;
        double      double_value;
        const char *string_value;
    };
} lmt_serialize_sort_data;

static int lmt_serialize_compare(const void *a, const void *b)
{
    const lmt_serialize_sort_data *ka = (const lmt_serialize_sort_data *) a;
    const lmt_serialize_sort_data *kb = (const lmt_serialize_sort_data *) b;
    /* Both elements have the exact same type tag. */
    if (ka->type == kb->type) {
        switch (ka->type) {
            case LMT_TYPE_INTEGER:
                return (ka->integer_value > kb->integer_value)
                     - (ka->integer_value < kb->integer_value);
            case LMT_TYPE_DOUBLE:
                return (ka->double_value > kb->double_value)
                     - (ka->double_value < kb->double_value);
            case LMT_TYPE_STRING: {
                uint32_t min_len = ka->string_length < kb->string_length
                                 ? ka->string_length : kb->string_length;
                int cmp = memcmp(ka->string_value, kb->string_value, min_len);
                if (cmp != 0) {
                    return cmp;
                } else {
                    return (ka->string_length > kb->string_length)
                         - (ka->string_length < kb->string_length);
                }
            }
            default:
                /* NIL, FALSE, and TRUE are identical to themselves. */
                return 0;
        }
    }
    /* Mixed number comparison (e.g. INT vs FLOAT: 1 < 1.5 < 2). */
    if ((ka->type == LMT_TYPE_INTEGER || ka->type == LMT_TYPE_DOUBLE) &&
        (kb->type == LMT_TYPE_INTEGER || kb->type == LMT_TYPE_DOUBLE))
    {
        double da = (ka->type == LMT_TYPE_INTEGER) ? (double) ka->integer_value : ka->double_value;
        double db = (kb->type == LMT_TYPE_INTEGER) ? (double) kb->integer_value : kb->double_value;
        return (da > db) - (da < db);
    }
    /* Different primary types (ordered by enum: NIL < FALSE < TRUE < INT/FLOAT < STRING) */
    return (ka->type < kb->type) ? -1 : 1;
}

/*tex
    Each nested table keeps some values on the stack so we make sure that there is room. We also
    quit when the nesting gets too deep, which happens when we have a cycle that is not checked,
    because otherwise we can run out of \CCODE\ stack. Such a table is treated like a seen one.
*/

static inline int strlib_aux_serialize_enter(lua_State *L, int index, int seen, int depth)
{
    if (depth > max_nesting_depth || ! lua_checkstack(L, LUA_MINSTACK)) {
        return 0;
    }
    if (seen == 0) {
        return 1; /* Bypass cycle tracking completely */
    }
    lua_pushvalue(L, index);
    lua_rawget(L, seen);
    int active = lua_toboolean(L, -1);
    lua_pop(L, 1);
    if (active) {
        return 0;
    }
    lua_pushvalue(L, index);
    lua_pushboolean(L, 1);
    lua_rawset(L, seen);
    return 1;
}

static inline void strlib_aux_serialize_leave(lua_State *L, int index, int seen)
{
    if (seen == 0) {
        return; /* Nothing to clean up */
    }
    lua_pushvalue(L, index);
    lua_pushnil(L);
    lua_rawset(L, seen);
}

static void strlib_aux_serialize(lua_State *L, int index, lmt_string_buffer *b, int depth, int escaped, int seen)
{
    index = lua_absindex(L, index);
    if (! strlib_aux_serialize_enter(L, index, seen, depth)) {
        lmt_buffer_add_lstring(b, "nil", 3);
        return;
    }

    int maxkeys = lmt_key_default;
    int nofkeys = 0;

    lmt_serialize_sort_data *keys = (lmt_serialize_sort_data *) lmt_memory_malloc(maxkeys * sizeof(lmt_serialize_sort_data));

    /* First we collect keys. */

    lua_pushnil(L);
    while (lua_next(L, index) != 0) {
        if (nofkeys >= maxkeys) {
            maxkeys *= 2;
            keys = (lmt_serialize_sort_data *) lmt_memory_realloc(keys, maxkeys * sizeof(lmt_serialize_sort_data));
        }

        lmt_serialize_sort_data *sk = &keys[nofkeys];

        switch (lua_type(L, -2)) {
            case LUA_TNUMBER:
                if (lua_isinteger(L, -2)) {
                    sk->type          = LMT_TYPE_INTEGER;
                    sk->integer_value = lua_tointeger(L, -2);
                } else {
                    sk->type         = LMT_TYPE_DOUBLE;
                    sk->double_value = lua_tonumber(L, -2);
                }
                nofkeys++;
                break;
            case LUA_TBOOLEAN:
                sk->type = lua_toboolean(L, -2) ? LMT_TYPE_TRUE : LMT_TYPE_FALSE;
                nofkeys++;
                break;
            case LUA_TSTRING: {
                size_t len;
                sk->type          = LMT_TYPE_STRING;
                sk->string_value  = lua_tolstring(L, -2, &len);
                sk->string_length = (uint32_t) len;
                nofkeys++;
                break;
            }
            default:
                /* Ignore unsupported key types (tables, functions, userdata) */
                break;
        }
        lua_pop(L, 1);
    }

    /*tex We quit when we have an empty table or one with weird keys. */

    if (nofkeys == 0) {
        lmt_buffer_add_lstring(b, "{}", 2);
        lmt_memory_free(keys);
        strlib_aux_serialize_leave(L, index, seen);
        return;
    }

    /*tex We sort as we do in the \LUA\ original. */

    qsort(keys, nofkeys, sizeof(lmt_serialize_sort_data), lmt_serialize_compare);

    /*tex We want simple array-only tables as one-liners. */

    int is_sequence = 1;
    for (int i = 0; i < nofkeys; i++) {
        lmt_serialize_sort_data *sk = &keys[i];

        if (sk->type != LMT_TYPE_INTEGER || sk->integer_value != (i + 1)) {
            is_sequence = 0;
            break;
        }
        lua_pushinteger(L, sk->integer_value);
        lua_gettable(L, index);
        if (lua_istable(L, -1)) {
            is_sequence = 0;
        }
        lua_pop(L, 1);
        if (! is_sequence) {
            break;
        }
    }

    /* Now we can start serializing the (sub)table. */

    lmt_buffer_add_lstring(b, is_sequence ? "{ " : "{\n", 2);

    /* We're serialize the entries. */

    lua_Integer expected_index = 1;

    for (int i = 0; i < nofkeys; i++) {
        lmt_serialize_sort_data *sk = &keys[i];
        /* We push the key back onto the stack. */
        switch (sk->type) {
            case LMT_TYPE_INTEGER : lua_pushinteger(L, sk->integer_value); break;
            case LMT_TYPE_DOUBLE  : lua_pushnumber (L, sk->double_value); break;
            case LMT_TYPE_FALSE   : lua_pushboolean(L, 0); break;
            case LMT_TYPE_TRUE    : lua_pushboolean(L, 1); break;
            case LMT_TYPE_STRING  : lua_pushlstring(L, sk->string_value, sk->string_length); break;
            default               : lua_pushnil    (L); break;
        }

        lua_pushvalue(L, -1);
        lua_gettable(L, index);

        int v_index = lua_gettop(L);

        /* Serialize the key but only when we have no sequence. */

        if (! is_sequence) {
            lmt_buffer_add_spaces(b, depth);
            int is_sequence_key = 0;
            switch (sk->type) {
                case LMT_TYPE_INTEGER:
                    if (sk->integer_value == expected_index) {
                        is_sequence_key = 1;
                        expected_index++;
                    }
                    if (! is_sequence_key) {
                        lmt_buffer_add_char(b, '[');
                        serialize_integer(b, sk->integer_value);
                        lmt_buffer_add_lstring(b, "]=", 2);
                    }
                    break;
                case LMT_TYPE_DOUBLE:
                    lmt_buffer_add_char(b, '[');
                    serialize_double(b, sk->double_value);
                    lmt_buffer_add_lstring(b, "]=", 2);
                    break;
                case LMT_TYPE_STRING:
                    lmt_buffer_add_char(b, '[');
                    if lmt_unlikely(escaped) {
                        serialize_string_escaped(b, sk->string_value, sk->string_length);
                    } else {
                        serialize_string(b, sk->string_value, sk->string_length);
                    }
                    lmt_buffer_add_lstring(b, "]=", 2);
                    break;
                case LMT_TYPE_FALSE:
                    lmt_buffer_add_lstring(b, "[false]=", 8);
                    break;
                case LMT_TYPE_TRUE:
                    lmt_buffer_add_lstring(b, "[true]=", 7);
                    break;
                default:
                    break;
            }
        }

        /* Serialize the value. */

        switch (lua_type(L, v_index)) {
            case LUA_TNUMBER:
                if (lua_isinteger(L, v_index)) {
                    serialize_integer(b, lua_tointeger(L, v_index));
                } else {
                    serialize_double(b, lua_tonumber(L, v_index));
                }
                break;
            case LUA_TSTRING: {
                size_t len;
                const char *v_str = lua_tolstring(L, v_index, &len);
                serialize_string(b, v_str, len);
                break;
            }
            case LUA_TBOOLEAN:
                if (lua_toboolean(L, v_index)) {
                    lmt_buffer_add_lstring(b, "true", 4);
                } else {
                    lmt_buffer_add_lstring(b, "false", 5);
                }
                break;
            case LUA_TTABLE:
                strlib_aux_serialize(L, v_index, b, depth + 1, escaped, seen);
                break;
            default:
                lmt_buffer_add_lstring(b, "nil", 3);
                break;
        }

        /* Add comma's and newlines. */

        if (! is_sequence) {
            lmt_buffer_add_lstring(b, ",\n", 2);
        } else if (i < nofkeys - 1) {
            lmt_buffer_add_lstring(b, ", ", 2);
        }

        lua_pop(L, 2);
    }

     /* We can end the table and of course we need to handle spaces. */

    if (is_sequence) {
        lmt_buffer_add_lstring(b, " }", 2);
    } else {
        if (depth > 1) {
            lmt_buffer_add_spaces(b, depth - 1);
        }
        lmt_buffer_add_char(b, '}');
    }

    lmt_memory_free(keys);
    strlib_aux_serialize_leave(L, index, seen);
}

/* 
    1 : table
    2 : string   : <string> = 
        "return" : return 
        number   : [<number>] =
        boolean  : return 
        default  : t = 
    3 : boolean  : in strings characters < 0x20 get [name] (escaped)
    4 : boolean  : check cycles 
*/

static int strlib_serialize(lua_State *L)
{
    lmt_string_buffer buffer;
    lmt_buffer_allocate(L, &buffer);
    switch (lua_type(L, 2)) {
        case LUA_TSTRING:
            {
                const char *name = lua_tostring(L, 2);
                if (strcmp(name, "return") == 0) {
                    lmt_buffer_add_lstring(&buffer, "return ", 7);
                } else {
                    lmt_buffer_add_string(&buffer, name);
                    lmt_buffer_add_char(&buffer, '=');
                }
            }
            break;
        case LUA_TNUMBER:
            {
                size_t len;
                const char *num_str = lua_tolstring(L, 2, &len);
                lmt_buffer_add_char(&buffer, '[');
                lmt_buffer_add_lstring(&buffer, num_str, len);
                lmt_buffer_add_lstring(&buffer, "]=", 2);
            }
            break;
        case LUA_TBOOLEAN:
            if (lua_toboolean(L, 2)) {
                lmt_buffer_add_lstring(&buffer, "return ", 7);
                break;
            }
            FALLTHROUGH
        default:
            lmt_buffer_add_lstring(&buffer, "t=", 2);
            break;
    }
    if (! lua_istable(L, 1)) {
        lmt_buffer_add_lstring(&buffer, "{}", 2);
    } else {
        int seen  = 0;
        int check = lua_toboolean(L, 4);         
        if (check) {
            lua_newtable(L);
            seen = lua_gettop(L);
        }
        strlib_aux_serialize(L, 1, &buffer, 1, lua_type(L, 3) == LUA_TBOOLEAN ? lua_toboolean(L, 3) : 0, seen);        
        if (check) {
            lua_remove(L, seen);
        }
    }
    lua_pushlstring(L, buffer.buffer, buffer.length);
    lmt_buffer_dispose(&buffer);
    return 1;
}

static void serialize_value(lua_State *L, int index, lmt_string_buffer *b)
{
    switch (lua_type(L, index)) {
        case LUA_TNUMBER:
            if (lua_isinteger(L, index)) {
                serialize_integer(b, lua_tointeger(L, index));
            } else {
                serialize_double(b, lua_tonumber(L, index));
            }
            break;
        case LUA_TSTRING: {
            size_t len;
            const char *s = lua_tolstring(L, index, &len);
            serialize_string(b, s, len);
            break;
        }
        case LUA_TBOOLEAN:
            if (lua_toboolean(L, index)) {
                lmt_buffer_add_lstring(b, "true", 4);
            } else {
                lmt_buffer_add_lstring(b, "false", 5);
            }
            break;
        default:
            lmt_buffer_add_lstring(b, "nil", 3);
            break;
    }
}

static void strlib_aux_fastserialize(lua_State *L, int index, lmt_string_buffer *b, int outer, int seen, int depth)
{
    index = lua_absindex(L, index);
    if (! strlib_aux_serialize_enter(L, index, seen, depth)) {
        lmt_buffer_add_lstring(b, outer ? "nil" : "nil,", outer ? 3 : 4);
        return;
    }

    lmt_buffer_add_char(b, '{');

    lua_Unsigned n = lua_rawlen(L, index);

    /* Handle index 0 independently of n > 0 */
    lua_rawgeti(L, index, 0);
    if (! lua_isnil(L, -1)) {
        lmt_buffer_add_lstring(b, "[0]=", 4);
        if (lua_istable(L, -1)) {
            strlib_aux_fastserialize(L, lua_gettop(L), b, 0, seen, depth + 1);
        } else {
            serialize_value(L, -1, b);
            lmt_buffer_add_char(b, ',');
        }
    }
    lua_pop(L, 1);

    if (n > 0) {
        /* The array part, if present, comes first. */
        for (lua_Unsigned i = 1; i <= n; i++) {
            lua_rawgeti(L, index, (lua_Integer)i);
            lmt_buffer_add_char(b, '[');
            serialize_integer(b, (lua_Integer)i);
            lmt_buffer_add_lstring(b, "]=", 2);
            if (lua_istable(L, -1)) {
                strlib_aux_fastserialize(L, lua_gettop(L), b, 0, seen, depth + 1);
            } else {
                serialize_value(L, -1, b);
                lmt_buffer_add_char(b, ',');
            }
            lua_pop(L, 1);
        }
    }

    /* The hash part comes next; skip only exact integer sequence keys already handled. */
    lua_pushnil(L);
    while (lua_next(L, index) != 0) {
        int process = 1;
        if (lua_type(L, -2) == LUA_TNUMBER) {
            if (lua_isinteger(L, -2)) {
                lua_Integer k = lua_tointeger(L, -2);
                if (k == 0 || (k >= 1 && (lua_Unsigned) k <= n)) {
                    process = 0;
                }
            } else {
                lua_Number k = lua_tonumber(L, -2);
                if (fmod(k, 1.0) == 0.0 && (k == 0.0 || (k >= 1.0 && k <= (lua_Number) n))) {
                    process = 0;
                }
            }
        }
        if (process) {
            lmt_buffer_add_char(b, '[');
            serialize_value(L, -2, b);
            lmt_buffer_add_lstring(b, "]=", 2);
            if (lua_istable(L, -1)) {
                strlib_aux_fastserialize(L, lua_gettop(L), b, 0, seen, depth + 1);
            } else {
                serialize_value(L, -1, b);
                lmt_buffer_add_char(b, ',');
            }
        }
        /* pop value, retain key for next iteration */
        lua_pop(L, 1);
    }

    strlib_aux_serialize_leave(L, index, seen);

    if (outer) {
        lmt_buffer_add_char(b, '}');
    } else {
        lmt_buffer_add_lstring(b, "},", 2);
    }
}

/*
    1 : table
    2 : string  : prefix (default "return")
    3 : boolean : check cycles
*/

static int strlib_fastserialize(lua_State *L)
{
    lmt_string_buffer buffer;
    lmt_buffer_allocate(L, &buffer);

    if (lua_type(L, 2) == LUA_TSTRING) {
        size_t len;
        const char *prefix = lua_tolstring(L, 2, &len);
        lmt_buffer_add_lstring(&buffer, prefix, len);
    } else {
        lmt_buffer_add_lstring(&buffer, "return", 6);
    }

    if (lua_istable(L, 1)) {
        int seen  = 0;
        int check = lua_toboolean(L, 3);
        if (check) {
            lua_newtable(L);
            seen = lua_gettop(L);
        }
        strlib_aux_fastserialize(L, 1, &buffer, 1, seen, 1);
        if (check) {
            lua_remove(L, seen);
        }
    } else {
        lmt_buffer_add_lstring(&buffer, "{}", 2);
    }

    lua_pushlstring(L, buffer.buffer, buffer.length);
    lmt_buffer_dispose(&buffer);

    return 1;
}

/*tex

    Once we had the above in place, and given the buffer infrastructure, the next bunch 
    was easy: auto converted and cleaned up cq. optimized afterwards. 

*/ 

/* Helper structure for zero-copy entry sorting */

typedef struct tabstr_entry {
    const char *str;
    uint32_t    len;
} tabstr_entry;

typedef struct tabstr_item {
    uint32_t offset;
    uint32_t len;
} tabstr_item;

static int tabstr_entry_compare(const void *a, const void *b)
{
    const tabstr_entry *ea = (const tabstr_entry *)a;
    const tabstr_entry *eb = (const tabstr_entry *)b;
    uint32_t minlen = ea->len < eb->len ? ea->len : eb->len;
    int cmp = memcmp(ea->str, eb->str, minlen);
    if (cmp != 0) {
        return cmp;
    } else {
        return (ea->len > eb->len) - (ea->len < eb->len);
    }
}

/* Helper to append key/value strings safely without mutating Lua keys during lua_next */

static inline void tabstr_add_value_string(lua_State *L, int idx, lmt_string_buffer *b)
{
    size_t len;
    /* 
        luaL_tolstring pushes the string representation onto the top of stack
        without mutating the value at 'idx' (critical for lua_next key safety). 
    */
    const char *s = luaL_tolstring(L, idx, &len);
    lmt_buffer_add_lstring(b, s, len);
    lua_pop(L, 1);
}

/* tabstr_normal */

static void strlib_aux_tabstr_normal(lua_State *L, int index, lmt_string_buffer *out, int seen, int depth)
{
    index = lua_absindex(L, index);
    if (! strlib_aux_serialize_enter(L, index, seen, depth)) {
        return;
    }
    int                maxentries = 16;
    int                nofentries = 0;
    tabstr_item       *entries    = (tabstr_item *) lmt_memory_malloc(maxentries * sizeof(tabstr_item));
    lmt_string_buffer  text_buf;
    lmt_buffer_allocate(L, &text_buf);
    lua_pushnil(L);
    while (lua_next(L, index) != 0) {
        if (nofentries >= maxentries) {
            maxentries *= 2;
            entries = (tabstr_item *) lmt_memory_realloc(entries, maxentries * sizeof(tabstr_item));
        }
        size_t start_off = text_buf.length;
        /* key: */
        tabstr_add_value_string(L, -2, &text_buf);
        /* value:
           - table:  k .. ">" .. tabstr_normal(v)
           - true:   k .. "+"
           - truthy: k .. "=" .. v
           - falsy:  k .. "-"
        */
        if (lua_istable(L, -1)) {
            lmt_buffer_add_char(&text_buf, '>');
            strlib_aux_tabstr_normal(L, lua_gettop(L), &text_buf, seen, depth + 1);
        } else if (lua_isboolean(L, -1) && lua_toboolean(L, -1)) {
            lmt_buffer_add_char(&text_buf, '+');
        } else if (lua_toboolean(L, -1)) { /* truthy (non-boolean, non-nil, non-table) */
            lmt_buffer_add_char(&text_buf, '=');
            tabstr_add_value_string(L, -1, &text_buf);
        } else { /* falsy (false or nil) */
            lmt_buffer_add_char(&text_buf, '-');
        }
        entries[nofentries].offset = (uint32_t) start_off;
        entries[nofentries].len    = (uint32_t) (text_buf.length - start_off);
        nofentries++;
        lua_pop(L, 1);
    }
    if (nofentries == 1) {
        lmt_buffer_add_lstring(out, text_buf.buffer + entries[0].offset, entries[0].len);
    } else if (nofentries > 1) {
        tabstr_entry *sort_list = (tabstr_entry *) lmt_memory_malloc(nofentries * sizeof(tabstr_entry));
        for (int i = 0; i < nofentries; i++) {
            sort_list[i].str = text_buf.buffer + entries[i].offset;
            sort_list[i].len = entries[i].len;
        }
        qsort(sort_list, nofentries, sizeof(tabstr_entry), tabstr_entry_compare);
        for (int i = 0; i < nofentries; i++) {
            if (i > 0) {
                lmt_buffer_add_char(out, ',');
            }
            lmt_buffer_add_lstring(out, sort_list[i].str, sort_list[i].len);
        }
        lmt_memory_free(sort_list);
    }
    lmt_memory_free(entries);
    lmt_buffer_dispose(&text_buf);
    strlib_aux_serialize_leave(L, index, seen);
}

static int strlib_tabstr_normal(lua_State *L)
{
    if (! lua_istable(L, 1)) {
        lua_pushliteral(L, "");
        return 1;
    }
    int check = lua_toboolean(L, 2);
    int seen  = 0;

    lmt_string_buffer buffer;
    lmt_buffer_allocate(L, &buffer);

    if (check) {
        lua_newtable(L);
        seen = lua_gettop(L);
    }
    strlib_aux_tabstr_normal(L, 1, &buffer, seen, 1);
    if (check) {
        lua_remove(L, seen);
    }

    lua_pushlstring(L, buffer.buffer, buffer.length);
    lmt_buffer_dispose(&buffer);
    return 1;
}

/* tabstr_flat */

static int strlib_tabstr_flat(lua_State *L)
{
    if (! lua_istable(L, 1)) {
        lua_pushliteral(L, "");
        return 1;
    }
    int               maxentries = 16;
    int               nofentries = 0;
    tabstr_item      *entries    = (tabstr_item *) lmt_memory_malloc(maxentries * sizeof(tabstr_item));
    lmt_string_buffer text_buf;
    lmt_buffer_allocate(L, &text_buf);
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        if (nofentries >= maxentries) {
            maxentries *= 2;
            entries = (tabstr_item *) lmt_memory_realloc(entries, maxentries * sizeof(tabstr_item));
        }
        size_t start_off = text_buf.length;
        tabstr_add_value_string(L, -2, &text_buf);
        lmt_buffer_add_char(&text_buf, '=');
        tabstr_add_value_string(L, -1, &text_buf);
        entries[nofentries].offset = (uint32_t) start_off;
        entries[nofentries].len    = (uint32_t) (text_buf.length - start_off);
        nofentries++;
        lua_pop(L, 1);
    }
    lmt_string_buffer out;
    lmt_buffer_allocate(L, &out);
    if (nofentries == 1) {
        lmt_buffer_add_lstring(&out, text_buf.buffer + entries[0].offset, entries[0].len);
    } else if (nofentries > 1) {
        tabstr_entry *sort_list = (tabstr_entry *) lmt_memory_malloc(nofentries * sizeof(tabstr_entry));
        for (int i = 0; i < nofentries; i++) {
            sort_list[i].str = text_buf.buffer + entries[i].offset;
            sort_list[i].len = entries[i].len;
        }
        qsort(sort_list, nofentries, sizeof(tabstr_entry), tabstr_entry_compare);
        for (int i = 0; i < nofentries; i++) {
            if (i > 0) {
                lmt_buffer_add_char(&out, ',');
            }
            lmt_buffer_add_lstring(&out, sort_list[i].str, sort_list[i].len);
        }
        lmt_memory_free(sort_list);
    }
    lua_pushlstring(L, out.buffer, out.length);
    lmt_memory_free(entries);
    lmt_buffer_dispose(&text_buf);
    lmt_buffer_dispose(&out);
    return 1;
}

/* tabstr_mixed (array indexed 1..n, no sorting) */

static int strlib_tabstr_mixed(lua_State *L)
{
    if (! lua_istable(L, 1)) {
        lua_pushliteral(L, "");
        return 1;
    }
    lua_Unsigned n = lua_rawlen(L, 1);
    if (n == 0) {
        lua_pushliteral(L, "");
        return 1;
    }
    lmt_string_buffer b;
    lmt_buffer_allocate(L, &b);
    for (lua_Unsigned i = 1; i <= n; i++) {
        if (i > 1) {
            lmt_buffer_add_char(&b, ',');
        }
        lua_rawgeti(L, 1, (lua_Integer)i);
        if (lua_isboolean(L, -1)) {
            if (lua_toboolean(L, -1)) {
                lmt_buffer_add_lstring(&b, "++", 2);
            } else {
                lmt_buffer_add_lstring(&b, "--", 2);
            }
        } else {
            tabstr_add_value_string(L, -1, &b);
        }
        lua_pop(L, 1);
    }
    lua_pushlstring(L, b.buffer, b.length);
    lmt_buffer_dispose(&b);
    return 1;
}

/* tabstr_boolean */

static int strlib_tabstr_boolean(lua_State *L)
{
    if (! lua_istable(L, 1)) {
        lua_pushliteral(L, "");
        return 1;
    }
    int                maxentries = 16;
    int                nofentries = 0;
    tabstr_item       *entries    = (tabstr_item *) lmt_memory_malloc(maxentries * sizeof(tabstr_item));
    lmt_string_buffer  text_buf;
    lmt_buffer_allocate(L, &text_buf);
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        if (nofentries >= maxentries) {
            maxentries *= 2;
            entries = (tabstr_item *) lmt_memory_realloc(entries, maxentries * sizeof(tabstr_item));
        }
        size_t start_off = text_buf.length;
        tabstr_add_value_string(L, -2, &text_buf);
        if (lua_toboolean(L, -1)) {
            lmt_buffer_add_char(&text_buf, '+');
        } else {
            lmt_buffer_add_char(&text_buf, '-');
        }
        entries[nofentries].offset = (uint32_t) start_off;
        entries[nofentries].len    = (uint32_t) (text_buf.length - start_off);
        nofentries++;
        lua_pop(L, 1);
    }
    lmt_string_buffer out;
    lmt_buffer_allocate(L, &out);
    if (nofentries == 1) {
        lmt_buffer_add_lstring(&out, text_buf.buffer + entries[0].offset, entries[0].len);
    } else if (nofentries > 1) {
        tabstr_entry *sort_list = (tabstr_entry *) lmt_memory_malloc(nofentries * sizeof(tabstr_entry));
        for (int i = 0; i < nofentries; i++) {
            sort_list[i].str = text_buf.buffer + entries[i].offset;
            sort_list[i].len = entries[i].len;
        }
        qsort(sort_list, nofentries, sizeof(tabstr_entry), tabstr_entry_compare);
        for (int i = 0; i < nofentries; i++) {
            if (i > 0) {
                lmt_buffer_add_char(&out, ',');
            }
            lmt_buffer_add_lstring(&out, sort_list[i].str, sort_list[i].len);
        }
        lmt_memory_free(sort_list);
    }
    lua_pushlstring(L, out.buffer, out.length);
    lmt_memory_free(entries);
    lmt_buffer_dispose(&text_buf);
    lmt_buffer_dispose(&out);
    return 1;
}

/* 
    From this it made sense to also provide a native loop over a sorted hash, another 
    oldie we use a lot. We're constent in the sorting. 
*/

static int strlib_aux_sorted_next(lua_State *L)
{
    lua_Integer  idx = lua_tointeger(L, lua_upvalueindex(3));
    lua_Unsigned len = lua_rawlen(L, lua_upvalueindex(2));
    if ((lua_Unsigned) idx > len) {
        /* iteration complete */
        return 0;
    }
    /* advance iterator index upvalue */
    lua_pushinteger(L, idx + 1);
    lua_replace(L, lua_upvalueindex(3));
    /* push key from sorted keys array (upvalue 2) */
    lua_rawgeti(L, lua_upvalueindex(2), idx);
    /* push value from target table (upvalue 1) */
    lua_pushvalue(L, -1);
    lua_gettable(L, lua_upvalueindex(1));
    /* key, value */
    return 2;
}

static int strlib_sortedhash(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    int index   = lua_absindex(L, 1);
    int maxkeys = lmt_key_default;
    int nofkeys = 0;
    lmt_serialize_sort_data *keys = (lmt_serialize_sort_data *) lmt_memory_malloc(maxkeys * sizeof(lmt_serialize_sort_data));
    /* collect all sortable keys */
    lua_pushnil(L);
    while (lua_next(L, index) != 0) {
        if (nofkeys >= maxkeys) {
            maxkeys *= 2;
            keys = (lmt_serialize_sort_data *) lmt_memory_realloc(keys, maxkeys * sizeof(lmt_serialize_sort_data));
        }
        lmt_serialize_sort_data *sk = &keys[nofkeys];
        switch (lua_type(L, -2)) {
            case LUA_TNUMBER:
                if (lua_isinteger(L, -2)) {
                    sk->type          = LMT_TYPE_INTEGER;
                    sk->integer_value = lua_tointeger(L, -2);
                } else {
                    sk->type         = LMT_TYPE_DOUBLE;
                    sk->double_value = lua_tonumber(L, -2);
                }
                nofkeys++;
                break;
            case LUA_TBOOLEAN:
                sk->type = lua_toboolean(L, -2) ? LMT_TYPE_TRUE : LMT_TYPE_FALSE;
                nofkeys++;
                break;
            case LUA_TSTRING: {
                size_t len;
                sk->type          = LMT_TYPE_STRING;
                sk->string_value  = lua_tolstring(L, -2, &len);
                sk->string_length = (uint32_t) len;
                nofkeys++;
                break;
            }
            default:
                break;
        }
        lua_pop(L, 1);
    }
    /* sort these keys using the already existing comparator */
    if (nofkeys > 1) {
        qsort(keys, nofkeys, sizeof(lmt_serialize_sort_data), lmt_serialize_compare);
    }
    /* sonstruct an array of sorted keys */
    lua_createtable(L, nofkeys, 0);
    int keys_table_idx = lua_gettop(L);
    for (int i = 0; i < nofkeys; i++) {
        lmt_serialize_sort_data *sk = &keys[i];
        switch (sk->type) {
            case LMT_TYPE_INTEGER:
                lua_pushinteger(L, sk->integer_value);
                break;
            case LMT_TYPE_DOUBLE:
                lua_pushnumber(L, sk->double_value);
                break;
            case LMT_TYPE_FALSE:
                lua_pushboolean(L, 0);
                break;
            case LMT_TYPE_TRUE:
                lua_pushboolean(L, 1);
                break;
            case LMT_TYPE_STRING:
                lua_pushlstring(L, sk->string_value, sk->string_length);
                break;
            default:
                lua_pushnil(L);
                break;
        }
        lua_rawseti(L, keys_table_idx, i + 1);
    }
    lmt_memory_free(keys);
    /* return a C closure with upvalues (the modern approach):

       1: target table
       2: sorted keys array table
       3: first index counter

    */
    lua_pushvalue(L, 1);
    lua_pushvalue(L, keys_table_idx);
    lua_pushinteger(L, 1);
    /* and off we go */
    lua_pushcclosure(L, strlib_aux_sorted_next, 3);
    return 1;
}

/*tex

    These are (for instance) part of a hash, not that critical in terms of performance but it fits 
    the repertoire. 

*/

static void strlib_aux_sequenced(
    lua_State         *L,
    int                index,
    lmt_string_buffer *buffer,
    int                sep_is_true,
    const char        *sep_str,
    size_t             sep_len,
    int                simple,
    int                seen,
    int                depth
)
{
    index = lua_absindex(L, index);
    if (! strlib_aux_serialize_enter(L, index, seen, depth)) {
        return;
    }
    if (sep_is_true) {
        lmt_buffer_add_lstring(buffer, "{ ", 2);
    }
    lua_Unsigned n = lua_rawlen(L, index);
    if (n > 0) {
        /* array part */
        for (lua_Unsigned i = 1; i <= n; i++) {
            if (i > 1) {
                if (sep_is_true) {
                    lmt_buffer_add_lstring(buffer, ", ", 2);
                } else {
                    lmt_buffer_add_lstring(buffer, sep_str, sep_len);
                }
            }
            lua_rawgeti(L, index, (lua_Integer)i);
            if (lua_istable(L, -1)) {
                lmt_buffer_add_char(buffer, '{');
                strlib_aux_sequenced(L, lua_gettop(L), buffer, sep_is_true, sep_str, sep_len, simple, seen, depth + 1);
                lmt_buffer_add_char(buffer, '}');
            } else {
                tabstr_add_value_string(L, -1, buffer);
            }
            lua_pop(L, 1);
        }
    } else {
        /* hashed part (sorted keys) */
        int maxkeys = lmt_key_default;
        int nofkeys = 0;
        lmt_serialize_sort_data *keys = (lmt_serialize_sort_data *) lmt_memory_malloc(maxkeys * sizeof(lmt_serialize_sort_data));
        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
            if (nofkeys >= maxkeys) {
                maxkeys *= 2;
                keys = (lmt_serialize_sort_data *) lmt_memory_realloc(keys, maxkeys * sizeof(lmt_serialize_sort_data));
            }
            lmt_serialize_sort_data *sk = &keys[nofkeys];
            switch (lua_type(L, -2)) {
                case LUA_TNUMBER:
                    if (lua_isinteger(L, -2)) {
                        sk->type          = LMT_TYPE_INTEGER;
                        sk->integer_value = lua_tointeger(L, -2);
                    } else {
                        sk->type         = LMT_TYPE_DOUBLE;
                        sk->double_value = lua_tonumber(L, -2);
                    }
                    nofkeys++;
                    break;
                case LUA_TBOOLEAN:
                    sk->type = lua_toboolean(L, -2) ? LMT_TYPE_TRUE : LMT_TYPE_FALSE;
                    nofkeys++;
                    break;
                case LUA_TSTRING:
                    {
                        size_t len;
                        sk->type          = LMT_TYPE_STRING;
                        sk->string_value  = lua_tolstring(L, -2, &len);
                        sk->string_length = (uint32_t) len;
                        nofkeys++;
                    }
                    break;
                default:
                    break;
            }
            lua_pop(L, 1);
        }
        if (nofkeys > 1) {
            qsort(keys, nofkeys, sizeof(lmt_serialize_sort_data), lmt_serialize_compare);
        }
        int entries_added = 0;
        for (int i = 0; i < nofkeys; i++) {
            lmt_serialize_sort_data *sk = &keys[i];
            /* key */
            switch (sk->type) {
                case LMT_TYPE_INTEGER: lua_pushinteger(L, sk->integer_value); break;
                case LMT_TYPE_DOUBLE : lua_pushnumber (L, sk->double_value); break;
                case LMT_TYPE_FALSE  : lua_pushboolean(L, 0); break;
                case LMT_TYPE_TRUE   : lua_pushboolean(L, 1); break;
                case LMT_TYPE_STRING : lua_pushlstring(L, sk->string_value, sk->string_length); break;
                default:               lua_pushnil    (L); break;
            }
            /* value */
            lua_pushvalue(L, -1);
            lua_gettable(L, index);
            int v_type  = lua_type(L, -1);
            int process = 0;
            int is_true = 0;
            if (simple) {
                if (v_type == LUA_TBOOLEAN && lua_toboolean(L, -1)) {
                    process = 1;
                    is_true = 1;
                } else if (v_type != LUA_TNIL && !(v_type == LUA_TBOOLEAN && ! lua_toboolean(L, -1))) {
                    if (v_type == LUA_TSTRING) {
                        size_t len;
                        lua_tolstring(L, -1, &len);
                        if (len > 0) {
                            process = 1;
                        }
                    } else {
                        process = 1;
                    }
                }
            } else {
                process = 1;
            }
            if (process) {
                if (entries_added > 0) {
                    if (sep_is_true) {
                        lmt_buffer_add_lstring(buffer, ", ", 2);
                    } else {
                        lmt_buffer_add_lstring(buffer, sep_str, sep_len);
                    }
                }
                tabstr_add_value_string(L, -2, buffer);  /* key */
                if (! is_true) {
                    lmt_buffer_add_char(buffer, '=');
                    if (v_type == LUA_TTABLE) {
                        lmt_buffer_add_char(buffer, '{');
                        strlib_aux_sequenced(L, lua_gettop(L), buffer, sep_is_true, sep_str, sep_len, simple, seen, depth + 1);
                        lmt_buffer_add_char(buffer, '}');
                    } else {
                        tabstr_add_value_string(L, -1, buffer);
                    }
                }
                entries_added++;
            }
            lua_pop(L, 2); /* pop key and value */
        }
        lmt_memory_free(keys);
    }
    if (sep_is_true) {
        lmt_buffer_add_lstring(buffer, " }", 2);
    }
    strlib_aux_serialize_leave(L, index, seen);
}

static int strlib_sequenced(lua_State *L)
{
    if (lua_isnoneornil(L, 1) || (lua_isboolean(L, 1) && ! lua_toboolean(L, 1))) {
        lua_pushliteral(L, "");
        return 1;
    }
    if (! lua_istable(L, 1)) {
        size_t len;
        const char *s = luaL_tolstring(L, 1, &len);
        lua_pushlstring(L, s, len);
        return 1;
    }
    /* parse 'sep' parameter */
    int         sep_is_true = 0;
    const char *sep_str     = " | ";
    size_t      sep_len     = 3;
    if (lua_isboolean(L, 2)) {
        if (lua_toboolean(L, 2)) {
            sep_is_true = 1;
        }
    } else if (lua_type(L, 2) == LUA_TSTRING) {
        sep_str = lua_tolstring(L, 2, &sep_len);
    }
    /* parse 'simple' parameter */
    int simple = lua_toboolean(L, 3);
    int check  = lua_toboolean(L, 4);
    int seen   = 0;
    lmt_string_buffer buffer;
    lmt_buffer_allocate(L, &buffer);
    if (check) {
        lua_newtable(L);
        seen = lua_gettop(L);
    }
    strlib_aux_sequenced(L, 1, &buffer, sep_is_true, sep_str, sep_len, simple, seen, 1);
    if (check) {
        lua_remove(L, seen);
    }
    lua_pushlstring(L, buffer.buffer, buffer.length);
    lmt_buffer_dispose(&buffer);
    return 1;
}

/*tex

    We define these function in the |strlib| namespace but eventually register them in their own
    library |sequencer|. They could have gone into |table| but they are rather specific and target
    our usage, although serialize is kind of generic. 

*/

static const luaL_Reg sequencerlib_function_list[] = {
    /* tables */
    { "serialize",          strlib_serialize          },
    { "fastserialize",      strlib_fastserialize      },
    { "tabstr_normal",      strlib_tabstr_normal      },
    { "tabstr_flat",        strlib_tabstr_flat        },
    { "tabstr_mixed",       strlib_tabstr_mixed       },
    { "tabstr_boolean",     strlib_tabstr_boolean     },
    { "sortedhash",         strlib_sortedhash         },
    { "sequenced",          strlib_sequenced          },
    /* strings */
    { "format",             strlib_format             },
    { "tostring",           strlib_tostring           },
    /* buffers */
    { "newbuffer",          strlib_buffer_new         },
    { "addtobuffer",        strlib_buffer_add         },
    { "addformattobuffer",  strlib_buffer_addformat   },
    { "addbytestobuffer",   strlib_buffer_addbytes    },
    { "addpackingtobuffer", strlib_buffer_addpacking  },
    { "getbufferdata",      strlib_buffer_get_data    },
    { "getbuffersize",      strlib_buffer_get_size    },
    /* */
    { NULL,                NULL                       },
};

/* this would also work when set: 

    static const void *G_BUFFER_METATABLE_PTR = NULL;

    ...
    luaL_getmetatable(L, STRING_BUFFER_METATABLE_INSTANCE);
    G_BUFFER_METATABLE_PTR = lua_topointer(L, -1);
    lua_pop(L, 1);
    ...

    lmt_string_buffer *strlib_buffer_instance(lua_State *L)
    {
        lmt_string_buffer *b = (lmt_string_buffer *) lua_touserdata(L, 1);
        if (b && lua_getmetatable(L, 1)) {
            if (lua_topointer(L, -1) != G_BUFFER_METATABLE_PTR) {
                b = NULL;
            }
            lua_pop(L, 1);
            return b;
        }
        return NULL;
    }

*/

int luaopen_sequencer(lua_State *L)
{
    luaL_newmetatable(L, STRING_BUFFER_METATABLE_INSTANCE);

    /* Cache metatable pointer for high-performance validation */
    G_BUFFER_METATABLE_PTR = lua_topointer(L, -1);

    luaL_setfuncs(L, sequencerlib_metatable_list, 0);

    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    /* create extensions table (upvalue 2) */

    lua_newtable(L);                                            /* stack: [metatable, extensions] */

    /* create format/tostring buffer stack (upvalue 3) */
    lmt_buffer_stack *bs = (lmt_buffer_stack *) lua_newuserdatauv(L, sizeof(lmt_buffer_stack), 0);
    bs->active_mask = 0;
    for (int i = 0; i < buffer_stack_size; i++) {
        bs->buffers[i].buffer = NULL;
        bs->buffers[i].size   = 0;
        bs->buffers[i].length = 0;
        bs->buffers[i].step   = 0;
    }

    lua_newtable(L);
    lua_pushcfunction(L, strlib_format_buffer_gc);
    lua_setfield(L, -2, "__gc");
    lua_setmetatable(L, -2);                                    /* stack: [metatable, extensions, buffer_ud] */

    /* create the main 'sequencer' library table */
    lua_newtable(L);                                            /* stack: [metatable, extensions, buffer_ud, library] */

    lua_pushvalue(L, -3);                                       /* extensions */
    lua_setfield(L, -2, "extensions");                          

    /* bind C functions using 3 upvalues */
    lua_pushvalue(L, -4);                                       /* upvalue 1: metatable */
    lua_pushvalue(L, -4);                                       /* upvalue 2: extensions table */
    lua_pushvalue(L, -4);                                       /* upvalue 3: buffer userdata */
    luaL_setfuncs(L, sequencerlib_function_list, 3);            /* register with 3 upvalues */

    /* clean up the stack */
    lua_remove(L, -2);                                          /* remove buffer_ud */
    lua_remove(L, -2);                                          /* remove extensions */
    lua_remove(L, -2);                                          /* remove metatable */

    return 1;                                                   /* return library table */
}
/*tex 

    The next list of functions registers in the |string| namespace. Maybe in retrospect we should
    have created a new namespace but it was already decided when we started with \LUATEX, so we 
    stick to it. 

*/

static const luaL_Reg strlib_function_list[] = {
    { "characters",        strlib_characters        },
    { "characterpairs",    strlib_characterpairs    },
    { "bytes",             strlib_bytes             },
    { "bytepairs",         strlib_bytepairs         },
    { "bytetable",         strlib_bytetable         },
    { "linetable",         strlib_linetable         },
    { "utfvalues",         strlib_utfvalues         },
    { "utfcharacters",     strlib_utfcharacters     },
    { "utfcharacter",      strlib_utfcharacter      },
    { "utfvalue",          strlib_utfvalue          },
    { "utflength",         strlib_utflength         },
    { "utfvaluetable",     strlib_utfvaluetable     },
    { "utfcharactertable", strlib_utfcharactertable },
    { "utftabletostring",  strlib_utftabletostring  },
    { "f6",                strlib_format_f6         },
    { "g6",                strlib_format_g6         },
    { "fd",                strlib_format_fd         },
    { "fd3",               strlib_format_fd3        }, /* no argument needed */
    { "fd6",               strlib_format_fd6        }, /* idem */
    { "fd9",               strlib_format_fd9        }, /* idem */
    { "gd",                strlib_format_gd         }, /* seldom needed but cheap to provide */
    { "tounicode16",       strlib_tounicode16       },
    { "fromunicode16",     strlib_fromunicode16     },
    { "toutf8",            strlib_format_toutf8     },
    { "toutf16",           strlib_format_toutf16    }, /* this is kind of untested */
    { "toutf32",           strlib_format_toutf32    },
    { "utf16toutf8",       strlib_utf16toutf8       },
    { "packrowscolumns",   strlib_pack_rows_columns },
    { "hextocharacters",   strlib_hextocharacters   },
    { "octtointeger",      strlib_octtointeger      },
    { "dectointeger",      strlib_dectointeger      },
    { "hextointeger",      strlib_hextointeger      },
    { "chrtointeger",      strlib_chrtointeger      },
    { "splitintolines",    strlib_splitintolines    },
    /* handy for pdf strings */                     
    { "topdfsixteen",      strlib_topdfsixteen      }, 
    { "topdfeight",        strlib_topdfeight        },
    { "topdfstring",       strlib_topdfstring       },
    /* */                                           
    { NULL,                NULL                     },
};

int luaextend_string(lua_State * L)
{
    lua_getglobal(L, "string");
    for (const luaL_Reg *lib = strlib_function_list; lib->name; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);
    return 1;
}

/*

LUAMOD_API int luaopen_strlib(lua_State *L) {
    // create the library table (or use luaL_newlib for other functions)
    lua_newtable(L);

    // push the upvalues onto the stack BEFORE creating the closure
    lua_pushliteral(L, "0"); // Upvalue index 1
    lua_pushliteral(L, "1"); // Upvalue index 2

    // create the closure with 2 upvalues
    // (This pops the 2 strings off the stack and attaches them to the function)
    lua_pushcclosure(L, strlib_format_f6, 2);

    // set the function in the library table 
    lua_setfield(L, -2, "f6");

    return 1; // the library table
}

static int strlib_format_f6(lua_State *L)
{
    double n = luaL_optnumber(L, 1, 0.0);
    if (n == 0.0) {
        // upvalue 1: "0"
        lua_pushvalue(L, lua_upvalueindex(1));
        return 1;
    } else if (n == 1.0) {
        // upvalue 2: "1"
        lua_pushvalue(L, lua_upvalueindex(2));
        return 1;
    }
    // ...
}

*/
