/*
    See license.txt in the root of this project.
*/

/*tex

    The relative ordering of the header files is important here, otherwise some of the defines that
    are needed for lua_sdump come out wrong.

*/

/* todo: byteconcat and utf concat (no separator) */

# include "luametatex.h"

/*tex Helpers */

inline static int strlib_aux_tounicode(const char *s, size_t l, size_t *p)
{
    unsigned char i = s[*p];
    *p += 1;
    if (i < 0x80) {
        return i;
    } else if (i >= 0xF0) {
        if ((*p + 2) < l) {
            unsigned char j = s[*p];
            unsigned char k = s[*p + 1];
            unsigned char l = s[*p + 2];
            if (j >= 0x80 && k >= 0x80 && l >= 0x80) {
                *p += 3;
                return (((((i - 0xF0) * 0x40) + (j - 0x80)) * 0x40) + (k - 0x80)) * 0x40 + (l - 0x80);
            }
        }
    } else if (i >= 0xE0) {
        if ((*p + 1) < l) {
            unsigned char j = s[*p];
            unsigned char k = s[*p + 1];
            if (j >= 0x80 && k >= 0x80) {
               *p += 2;
               return (((i - 0xE0) * 0x40) + (j - 0x80)) * 0x40 + (k - 0x80);
            }
        }
    } else if (i >= 0xC0) {
        if (*p < l) {
            unsigned char j = s[*p];
            if (j >= 0x80) {
               *p += 1;
               return ((i - 0xC0) * 0x40) + (j - 0x80);
            }
        }
    }
    return 0xFFFD;
}

inline static int strlib_aux_tounichar(const char *s, size_t l, size_t p)
{
    unsigned char i = s[p++];
    if (i < 0x80) {
        return 1;
    } else if (i >= 0xF0) {
        if ((p + 2) < l) {
            unsigned char j = s[p];
            unsigned char k = s[p + 1];
            unsigned char l = s[p + 2];
            if (j >= 0x80 && k >= 0x80 && l >= 0x80) {
                return 4;
            }
        }
    } else if (i >= 0xE0) {
        if ((p + 1) < l) {
            unsigned char j = s[p];
            unsigned char k = s[p + 1];
            if (j >= 0x80 && k >= 0x80) {
                return 3;
            }
        }
    } else if (i >= 0xC0) {
        if (p < l) {
            unsigned char j = s[p];
            if (j >= 0x80) {
                return 2;
            }
        }
    }
    return 0;
}

inline static size_t strlib_aux_toline(const char *s, size_t l, size_t p, size_t *b)
{
    size_t i = p;
    while (i < l) {
        if (s[i] == 13) {
            if ((i + 1) < l) {
                if (s[i + 1] == 10) {
                    *b = 2; /* cr lf */
                } else {
                    *b = 1; /* cr */
                }
            }
            return i - p;
        } else if (s[i] == 10) {
            *b = 1; /* lf */
            return i - p;
        } else {
            /* other */
            i += 1;
        }
    }
    return i - p ;
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

static int strlib_aux_utfcharacters(lua_State *L)
{
    static const unsigned char mask[4] = { 0x80, 0xE0, 0xF0, 0xF8 };
    static const unsigned char mequ[4] = { 0x00, 0xC0, 0xE0, 0xF0 };
    size_t ls = 0;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    size_t ind = lmt_tointeger(L, lua_upvalueindex(2));
    size_t l = ls;
    if (ind >= l) {
        return 0;
    } else {
        unsigned char c = (unsigned char) s[ind];
        for (size_t j = 0; j < 4; j++) {
            if ((c & mask[j]) == mequ[j]) {
                if (ind + 1 + j > l) {
                    /*tex The result will not fit. */
                    return strlib_aux_utf_failed(L, (int) l);
                }
                for (size_t k = 1; k <= j; k++) {
                    c = (unsigned char) s[ind + k];
                    if ((c & 0xC0) != 0x80) {
                        /*tex We have a bad follow byte. */
                        return strlib_aux_utf_failed(L, (int) (ind + k));
                    }
                }
                /*tex The iterator. */
                lua_pushinteger(L, ind + j + 1);
                lua_replace(L, lua_upvalueindex(2));
                lua_pushlstring(L, ind + s, j + 1);
                return 1;
            }
        }
        return strlib_aux_utf_failed(L, (int) (ind + 1)); /* we found a follow byte! */
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
        int b = strlib_aux_tounichar(s, l, p);
        if (b) {
            lua_pushlstring(L, s + p, b);
            p += b;
        } else {
            lua_pushliteral(L, utf_fffd_string);
            p += 1;
        }
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

    We provide a few helpers that we derived from the lua utf8 module and slunicode. That way we're
    sort of covering a decent mix.

*/

# define MAXUNICODE 0x10FFFF

/*tex

    This is a combination of slunicode and utf8 converters but without mode and a bit faster on the
    average than the utf8 one. The one character branch is a bit more efficient, as is preallocating
    the buffer size.

*/

static int strlib_utfcharacter(lua_State *L) /* todo: use tounichar here too */
{
    int n = lua_gettop(L);
    if (n == 1) {
        char u[6];
        char *c = aux_uni2string(&u[0], (unsigned) lua_tointeger(L, 1));
        *c = '\0';
        lua_pushstring(L, u);
        return 1;
    } else {
        luaL_Buffer b;
        luaL_buffinitsize(L, &b, (size_t) n * 4);
        for (int i = 1; i <= n; i++) {
            unsigned u = (unsigned) lua_tointeger(L, i);
            if (u <= MAXUNICODE) {
                if (0x80 > u) {
                    luaL_addchar(&b, (unsigned char) u);
                } else {
                    if (0x800 > u)
                        luaL_addchar(&b, (unsigned char) (0xC0 | (u >> 6)));
                    else {
                        if (0x10000 > u)
                            luaL_addchar(&b, (unsigned char) (0xE0 | (u >> 12)));
                        else {
                            luaL_addchar(&b, (unsigned char) (0xF0 | (u >> 18)));
                            luaL_addchar(&b, (unsigned char) (0x80 | (0x3F & (u >> 12))));
                        }
                        luaL_addchar(&b, 0x80 | (0x3F & (u >> 6)));
                    }
                    luaL_addchar(&b, 0x80 | (0x3F & u));
                }
            }
        }
        luaL_pushresult(&b);
        return 1;
    }
}

/*tex

    The \UTF8 codepoint function takes two arguments, being positions in the string, while slunicode
    byte takes two arguments representing the number of utf characters. The variant below always
    returns all codepoints.

*/

static int strlib_utfvalue(lua_State *L)
{
    size_t l = 0;
    size_t p = 0;
    int i = 0;
    const char *s = luaL_checklstring(L, 1, &l);
    while (p < l) {
        lua_pushinteger(L, strlib_aux_tounicode(s, l, &p));
        i++;
    }
    return i;
}

/*tex This is a simplified version of utf8.len but without range. */

static int strlib_utflength(lua_State *L)
{
    size_t ls = 0;
    size_t ind = 0;
    size_t n = 0;
    const char *s = lua_tolstring(L, 1, &ls);
    while (ind < ls) {
        unsigned char i = (unsigned char) *(s + ind);
        if (i < 0x80) {
            ind += 1;
        } else if (i >= 0xF0) {
            ind += 4;
        } else if (i >= 0xE0) {
            ind += 3;
        } else if (i >= 0xC0) {
            ind += 2;
        } else {
            /*tex bad news, stupid recovery */
            ind += 1;
        }
        n++;
    }
    lua_pushinteger(L, n);
    return 1;
}

/*tex A handy one that formats a float but also strips trailing zeros. */

static int strlib_format_f6(lua_State *L)
{
    double n = luaL_optnumber(L, 1, 0.0);
    if (n == 0.0) {
        lua_pushliteral(L, "0");
    } else if (n == 1.0) {
        lua_pushliteral(L, "1");
    } else {
        char s[128];
        int i, l;
        /* we should check for max int */
        if (fmod(n, 1) == 0) {
            i = snprintf(s, 128, "%i", (int) n);
        } else {
            if (lua_type(L, 2) == LUA_TSTRING) {
                const char *f = lua_tostring(L, 2);
                i = snprintf(s, 128, f, n);
            } else {
                i = snprintf(s, 128, "%0.6f", n) ;
            }
            l = i - 1;
            while (l > 1) {
                if (s[l - 1] == '.') {
                    break;
                } else if (s[l] == '0') {
                    s[l] = '\0';
                    --i;
                } else {
                    break;
                }
                l--;
            }
        }
        lua_pushlstring(L, s, i);
    }
    return 1;
}

/*tex
    The next one is mostly provided as check because doing it in pure \LUA\ is not slower and it's
    not a bottleneck anyway. There are soms subtle side effects when we don't check for these ranges,
    especially the trigger bytes (|0xD7FF| etc.) because we can get negative numbers which means
    wrapping around and such.
*/

inline static unsigned char strlib_aux_hexdigit(unsigned char n) {
    return (n < 10 ? '0' : 'A' - 10) + n;
}

# define invalid_unicode(u) ( \
    (u >= 0x00E000 && u <= 0x00F8FF) || \
    (u >= 0x0F0000 && u <= 0x0FFFFF) || \
    (u >= 0x100000 && u <= 0x10FFFF) || \
 /* (u >= 0x00D800 && u <= 0x00DFFF)) { */ \
    (u >= 0x00D7FF && u <= 0x00DFFF) \
)

static int strlib_format_tounicode16(lua_State *L)
{
    lua_Integer u = lua_tointeger(L, 1);
    if (invalid_unicode(u)) {
        lua_pushliteral(L, "FFFD");
    } else if (u < 0xD7FF || (u > 0xDFFF && u <= 0xFFFF)) {
        char s[4] ;
        s[3] = strlib_aux_hexdigit((unsigned char) ((u & 0x000F) >>  0));
        s[2] = strlib_aux_hexdigit((unsigned char) ((u & 0x00F0) >>  4));
        s[1] = strlib_aux_hexdigit((unsigned char) ((u & 0x0F00) >>  8));
        s[0] = strlib_aux_hexdigit((unsigned char) ((u & 0xF000) >> 12));
        lua_pushlstring(L, s, 4);
    } else {
        unsigned u1, u2;
        char     s[8] ;
        u = u - 0x10000; /* negative when invalid range */
        u1 = (unsigned) (u >> 10) + 0xD800;
        u2 = (unsigned) (u % 0x400) + 0xDC00;
        s[3] = strlib_aux_hexdigit((unsigned char) ((u1 & 0x000F) >>  0));
        s[2] = strlib_aux_hexdigit((unsigned char) ((u1 & 0x00F0) >>  4));
        s[1] = strlib_aux_hexdigit((unsigned char) ((u1 & 0x0F00) >>  8));
        s[0] = strlib_aux_hexdigit((unsigned char) ((u1 & 0xF000) >> 12));
        s[7] = strlib_aux_hexdigit((unsigned char) ((u2 & 0x000F) >>  0));
        s[6] = strlib_aux_hexdigit((unsigned char) ((u2 & 0x00F0) >>  4));
        s[5] = strlib_aux_hexdigit((unsigned char) ((u2 & 0x0F00) >>  8));
        s[4] = strlib_aux_hexdigit((unsigned char) ((u2 & 0xF000) >> 12));
        lua_pushlstring(L, s, 8);
    }
    return 1;
}

static int strlib_format_toutf8(lua_State *L) /* could be integrated into utfcharacter */
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            luaL_Buffer b;
            luaL_buffinitsize(L, &b, (n + 1) * 4);
            for (lua_Integer i = 0; i <= n; i++) {
                /* there should be one operation for getting a number from a table */
                if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                    unsigned u = (unsigned) lua_tointeger(L, -1);
                    if (0x80 > u) {
                        luaL_addchar(&b, (unsigned char) u);
                    } else if (invalid_unicode(u)) {
                        luaL_addchar(&b, 0xFF);
                        luaL_addchar(&b, 0xFD);
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

/*
static int strlib_format_toutf16(lua_State* L) {
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            luaL_Buffer b;
            luaL_buffinitsize(L, &b, (n + 2) * 4);
            for (lua_Integer i = 0; i <= n; i++) {
                if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                    unsigned u = (unsigned) lua_tointeger(L, -1);
                    if (invalid_unicode(u)) {
                        luaL_addchar(&b, 0xFF);
                        luaL_addchar(&b, 0xFD);
                    } else if (u < 0x10000) {
                        luaL_addchar(&b, (unsigned char) ((u & 0x00FF)     ));
                        luaL_addchar(&b, (unsigned char) ((u & 0xFF00) >> 8));
                    } else {
                        u = u - 0x10000;
                        luaL_addchar(&b, (unsigned char) ((((u>>10)+0xD800) & 0x00FF)     ));
                        luaL_addchar(&b, (unsigned char) ((((u>>10)+0xD800) & 0xFF00) >> 8));
                        luaL_addchar(&b, (unsigned char) (( (u%1024+0xDC00) & 0x00FF)     ));
                        luaL_addchar(&b, (unsigned char) (( (u%1024+0xDC00) & 0xFF00) >> 8));
                    }
                }
                lua_pop(L, 1);
            }
            luaL_addchar(&b, 0);
            luaL_addchar(&b, 0);
            luaL_pushresult(&b);
        } else {
            lua_pushliteral(L, "");
        }
        return 1;
    }
    return 0;
}
*/

static int strlib_format_toutf32(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer n = lua_rawlen(L, 1);
        if (n > 0) {
            luaL_Buffer b;
            luaL_buffinitsize(L, &b, (n + 2) * 4);
            for (lua_Integer i = 0; i <= n; i++) {
                /* there should be one operation for getting a number from a table */
                if (lua_rawgeti(L, 1, i) == LUA_TNUMBER) {
                    unsigned u = (unsigned) lua_tointeger(L, -1);
                    if (invalid_unicode(u)) {
                        luaL_addchar(&b, 0x00);
                        luaL_addchar(&b, 0x00);
                        luaL_addchar(&b, 0xFF);
                        luaL_addchar(&b, 0xFD);
                    } else {
                        luaL_addchar(&b, (unsigned char) ((u & 0x000000FF)      ));
                        luaL_addchar(&b, (unsigned char) ((u & 0x0000FF00) >>  8));
                        luaL_addchar(&b, (unsigned char) ((u & 0x00FF0000) >> 16));
                        luaL_addchar(&b, (unsigned char) ((u & 0xFF000000) >> 24));
                    }
                }
                lua_pop(L, 1);
            }
            for (int i = 0; i <= 3; i++) {
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

// static char map[] = {
//     '0', '1', '2', '3',
//     '4', '5', '6', '7',
//     '8', '9', 'A', 'B',
//     'C', 'D', 'E', 'F',
// };

static int strlib_pack_rows_columns(lua_State* L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_Integer rows = lua_rawlen(L, 1);
        if (lua_rawgeti(L, 1, 1) == LUA_TTABLE) {
            lua_Integer columns = lua_rawlen(L, -1);
            switch (lua_rawgeti(L, -1, 1)) {
                case LUA_TNUMBER:
                    {
                        lua_Integer size = rows * columns;
                        char *result = lmt_memory_malloc(size);
                        lua_pop(L, 2); /* row and cell */
                        if (result) {
                            char *first = result;
                            for (lua_Integer r = 1; r <= rows; r++) {
                                if (lua_rawgeti(L, -1, r) == LUA_TTABLE) {
                                    for (lua_Integer c = 1; c <= columns; c++) {
                                        if (lua_rawgeti(L, -1, c) == LUA_TNUMBER) {
                                            lua_Integer v = lua_tointeger(L, -1);
                                            if (v < 0) {
                                                v = 0;
                                            } else if (v > 255) {
                                                v = 255;
                                            }
                                            *result++ = (char) v;
                                        }
                                        lua_pop(L, 1);
                                    }
                                }
                                lua_pop(L, 1);
                            }
                            lua_pushlstring(L, first, result - first);
                            return 1;
                        }
                    }
                case LUA_TTABLE:
                    {
                        lua_Integer mode = lua_rawlen(L, -1);
                        lua_Integer size = rows * columns * mode;
                        char *result = lmt_memory_malloc(size);
                        lua_pop(L, 2); /* row and cell */
                        if (result) {
                            char *first = result;
                            for (lua_Integer r = 1; r <= rows; r++) {
                                if (lua_rawgeti(L, -1, r) == LUA_TTABLE) {
                                    for (lua_Integer c = 1; c <= columns; c++) {
                                        if (lua_rawgeti(L, -1, c) == LUA_TTABLE) {
                                            for (int i = 1; i <= mode; i++) {
                                                if (lua_rawgeti(L, -1, i) == LUA_TNUMBER) {
                                                    lua_Integer v = lua_tointeger(L, -1);
                                                    if (v < 0) {
                                                        v = 0;
                                                    } else if (v > 255) {
                                                        v = 255;
                                                    }
                                                    *result++ = (char) v;
                                                }
                                                lua_pop(L, 1);
                                            }
                                        }
                                        lua_pop(L, 1);
                                    }
                                }
                                lua_pop(L, 1);
                            }
                            lua_pushlstring(L, first, result - first);
                            return 1;
                        }
                    }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static const luaL_Reg strlib_function_list[] = {
    { "characters",        strlib_characters         },
    { "characterpairs",    strlib_characterpairs     },
    { "bytes",             strlib_bytes              },
    { "bytepairs",         strlib_bytepairs          },
    { "bytetable",         strlib_bytetable          },
    { "linetable",         strlib_linetable          },
    { "utfvalues",         strlib_utfvalues          },
    { "utfcharacters",     strlib_utfcharacters      },
    { "utfcharacter",      strlib_utfcharacter       },
    { "utfvalue",          strlib_utfvalue           },
    { "utflength",         strlib_utflength          },
    { "utfvaluetable",     strlib_utfvaluetable      },
    { "utfcharactertable", strlib_utfcharactertable  },
    { "f6",                strlib_format_f6          },
    { "tounicode16",       strlib_format_tounicode16 },
    { "toutf8",            strlib_format_toutf8      },
 /* { "toutf16",           strlib_format_toutf16     }, */ /* untested */
    { "toutf32",           strlib_format_toutf32     },
    { "packrowscolumns",   strlib_pack_rows_columns  },
    { NULL,                NULL                      },
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
    The next (old, moved here) experiment was used to check if using some buffer is more efficient
    than using a table that we concat. It makes no difference. If we ever use this, the initializer
    |luaextend_string_buffer| will me merged into |luaextend_string|. We could gain a little on a
    bit more efficient |luaL_checkudata| as we use elsewhere because in practice (surprise) its
    overhead makes buffers like this {\em 50 percent} slower than the concatinated variant and
    twice as slow when we reuse a temporary table. It's just better to stay at the \LUA\ end.
*/

/*
# define STRING_BUFFER_METATABLE "string.buffer"

typedef struct lmt_string_buffer {
    char   *buffer;
    size_t  length;
    size_t  size;
    size_t  step;
    size_t  padding;
} lmt_string_buffer;

static int strlib_buffer_gc(lua_State* L)
{
    lmt_string_buffer *b = (lmt_string_buffer *) luaL_checkudata(L, 1, STRING_BUFFER_METATABLE);
    if (b && b->buffer) {
        lmt_memory_free(b->buffer);
    }
    return 0;
}

static int strlib_buffer_new(lua_State* L)
{
    size_t size = lmt_optsizet(L, 1, LUAL_BUFFERSIZE);
    size_t step = lmt_optsizet(L, 2, size);
    lmt_string_buffer *b = (lmt_string_buffer *) lua_newuserdatauv(L, sizeof(lmt_string_buffer), 0);
    b->buffer = lmt_memory_malloc(size);
    b->size   = size;
    b->step   = step;
    b->length = 0;
    luaL_setmetatable(L, STRING_BUFFER_METATABLE);
    return 1;

}

static int strlib_buffer_add(lua_State* L)
{
    lmt_string_buffer *b = (lmt_string_buffer *) luaL_checkudata(L, 1,  STRING_BUFFER_METATABLE);
    switch (lua_type(L, 2)) {
        case LUA_TSTRING:
            {
                size_t l;
                const char *s = lua_tolstring(L, 2, &l);
                size_t length = b->length + l;
                if (length >= b->size) {
                    while (length >= b->size) {
                         b->size += b->step;
                    }
                    b->buffer = lmt_memory_realloc(b->buffer, b->size);
                }
                memcpy(&b->buffer[b->length], s, l);
                b->length = length;
            }
            break;
        default:
            break;
    }
    return 0;
}

static int strlib_buffer_get_data(lua_State* L)
{
    lmt_string_buffer *b = (lmt_string_buffer *) luaL_checkudata(L, 1,  STRING_BUFFER_METATABLE);
    if (b->buffer) {
        lua_pushlstring(L, b->buffer, b->length);
        lua_pushinteger(L, (int) b->length);
        return 2;
    } else {
        lua_pushnil(L);
        return 1;
    }
}

static int strlib_buffer_get_size(lua_State* L)
{
    lmt_string_buffer *b = (lmt_string_buffer *) luaL_checkudata(L, 1,  STRING_BUFFER_METATABLE);
    lua_pushinteger(L, b->length);
    return 1;
}

static const luaL_Reg strlib_function_list_buffer[] = {
    { "newbuffer",         strlib_buffer_new         },
    { "addtobuffer",       strlib_buffer_add         },
    { "getbufferdata",     strlib_buffer_get_data    },
    { "getbuffersize",     strlib_buffer_get_size    },
    { NULL,                NULL                      },
};

int luaextend_string_buffer(lua_State * L)
{
    lua_getglobal(L, "string");
    for (const luaL_Reg *lib = strlib_function_list_buffer; lib->name; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);
    luaL_newmetatable(L, STRING_BUFFER_METATABLE);
    lua_pushcfunction(L, strlib_buffer_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    return 1;
}

*/
