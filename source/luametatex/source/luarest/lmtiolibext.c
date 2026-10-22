/*
    See license.txt in the root of this project.
*/

/*tex

    Lua doesn't have cardinals so basically we could stick to integers and accept that we have a
    limited range.

*/

/*tex

    Maybe also make a string reader with a user data string, after all we can now store a position
    in the userdata directly. Actually that overhead isn't worth the effort so now I made that bit
    also accept the table based specification that we use(d) at \quote {the other hand} which turns
    out to give a 20\% performance gain over the original wrappers. It might be a rason to use this
    feature more often.

*/
# include "luametatex.h"

# ifdef LUA_USE_POSIX

    # define l_fseek(f,o,w) fseeko(f,o,w)
    # define l_ftell(f)     ftello(f)
    # define l_seeknum      off_t

# elif defined(LUA_WIN) && !defined(_CRTIMP_TYPEINFO) && defined(_MSC_VER) && (_MSC_VER >= 1400)

    # define l_fseek(f,o,w) _fseeki64(f,o,w)
    # define l_ftell(f)     _ftelli64(f)
    # define l_seeknum      __int64

# elif defined(__MINGW32__)

    # define l_fseek(f,o,w) fseeko64(f,o,w)
    # define l_ftell(f)     ftello64(f)
    # define l_seeknum      int64_t

# else

    # define l_fseek(f,o,w) fseek(f,o,w)
    # define l_ftell(f)     ftell(f)
    # define l_seeknum      long

# endif

# define uchar(c) ((unsigned char)(c))

static inline int8_t siolib_signed8(uint32_t n)
{
    return (n & 0x80u) ? (int8_t) ((int32_t) n - 0x100) : (int8_t) n;
}

static inline int16_t siolib_signed16(uint32_t n)
{
    return (n & 0x8000u) ? (int16_t) ((int32_t) n - 0x10000) : (int16_t) n;
}

static inline int32_t siolib_signed24(uint32_t n)
{
    return (n & 0x800000u) ? (int32_t) n - 0x1000000 : (int32_t) n;
}

static inline int32_t siolib_signed32(uint32_t n)
{
    return (n & 0x80000000u) ? (int32_t) ((int64_t) n - INT64_C(0x100000000)) : (int32_t) n;
}

/*tex

    We can delegate some management to here (the stream code in \CONTEXT) so let's do that
    optionally. So we accept \typ {str, pos, ...} as well as \typ {tab, ...} now.

    When we use the table interface, we need access here which costs but wrapping and management
    at the \LUA\ end costs more, we need in some cases to update the position after we have read
    stuff and know how much to advance.

*/

typedef enum modes {
    mode_unknown,
    mode_table,
    mode_string,
} modes;

static const char * siolib_okay(lua_State *L, int len, size_t *p, size_t *l, int *mode)
{
    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            if (mode) {
                *mode = mode_table;
            }
            if (lua_rawgeti(L, 1, 1) == LUA_TSTRING) {
                size_t ls = 0;
                const char *s = lua_tolstring(L, -1, &ls);
                lua_pop(L, 1);
                if (lua_rawgeti(L, 1, 2) == LUA_TNUMBER) {
                    lua_Integer position = lua_tointeger(L, -1);
                    lua_pop(L, 1);
                    if (position >= 1 && (uintmax_t) (position - 1) <= (uintmax_t) ls) {
                        *p = (size_t) (position - 1);
                        if (l) {
                            /* checking happens elsewhere */
                            *l = ls;
                            return s;
                        } else if (len >= 0 && (size_t) len <= (ls - *p)) {
                            lua_pushinteger(L, (lua_Integer) (*p + (size_t) len + 1));
                            lua_rawseti(L, 1, 2);
                            return s;
                        }
                    }
                } else {
                    lua_pop(L, 1);
                }
            } else {
                lua_pop(L, 1);
            }
            break;
        case LUA_TSTRING:
            if (mode) {
                *mode = mode_string;
            }
            if (lua_type(L, 2) == LUA_TNUMBER) {
                size_t ls = 0;
                const char *s = lua_tolstring(L, 1, &ls);
                lua_Integer position = lua_tointeger(L, 2);
                if (position >= 1 && (uintmax_t) (position - 1) <= (uintmax_t) ls) {
                    *p = (size_t) (position - 1);
                    if (l) {
                        *l = ls;
                        return s;
                    } else if (len >= 0 && (size_t) len <= (ls - *p)) {
                        return s;
                    }
                }
            }
            break;
        default:
            if (mode) {
                *mode = mode_unknown;
            }
    }
    *p = 0;
    if (l) {
        *l = 0;
    }
    return NULL;
}

static void siolib_done(lua_State *L, int mode, lua_Integer n)
{
    if (mode == mode_table) {
        lua_rawgeti(L, 1, 2);
        lua_Integer l = lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_pushinteger(L, l + n);
        lua_rawseti(L, 1, 2);
    }
}

/*tex

    Here starts the real deal. We have \type {fio} and \type {sio} readers and of course they look
    very similar.

*/

static int fiolib_readcardinal1(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, a);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal1(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 1, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, a);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readcardinal2(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 8) | (uint32_t) b));
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readcardinal2_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int b = getc(f);
        if (b != EOF) {
            int a = getc(f);
            if (a != EOF) {
                lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 8) | (uint32_t) b));
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal2(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 2, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p]);
        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 8) | (uint32_t) b));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readcardinal2_le(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 2, &p, NULL, NULL);
    if (s) {
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 8) | (uint32_t) b));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readcardinal3(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int c = getc(f);
                if (c != EOF) {
                    lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c));
                    return 1;
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readcardinal3_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int c = getc(f);
        if (c != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int a = getc(f);
                if (a != EOF) {
                    lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c));
                    return 1;
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal3(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 3, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p]);
        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readcardinal3_le(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 3, &p, NULL, NULL);
    if (s) {
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readcardinal4(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int c = getc(f);
                if (c != EOF) {
                    int d = getc(f);
                    if (d != EOF) {
                        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                        return 1;
                    }
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readcardinal4_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int d = getc(f);
        if (d != EOF) {
            int c = getc(f);
            if (c != EOF) {
                int b = getc(f);
                if (b != EOF) {
                    int a = getc(f);
                    if (a != EOF) {
                        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                        return 1;
                    }
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal4(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer d = uchar(s[p]);
        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readcardinal4_le(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        lua_Integer d = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readcardinaltable(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        lua_Integer m = lua_tointeger(L, 3);
        lua_createtable(L, (int) n, 0);
        switch (m) {
            case 1:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) {
                        break;
                    } else {
                        lua_pushinteger(L, a);
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 2:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) break;
                    int b = getc(f);
                    if (b == EOF) break;
                    lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 8) | (uint32_t) b));
                    lua_rawseti(L, -2, i);
                }
                break;
            case 3:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) break;
                    int b = getc(f);
                    if (b == EOF) break;
                    int c = getc(f);
                    if (c == EOF) break;
                    lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c));
                    lua_rawseti(L, -2, i);
                }
                break;
            case 4:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) break;
                    int b = getc(f);
                    if (b == EOF) break;
                    int c = getc(f);
                    if (c == EOF) break;
                    int d = getc(f);
                    if (d == EOF) break;
                    lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                    lua_rawseti(L, -2, i);
                }
                break;
            default:
                break;
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinaltable(lua_State *L)
{
    size_t p, l;
    size_t start;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    /*tex We need to know the mode so we delay updating the advance. */
    lua_Integer n = lua_tointeger(L, mode == mode_table ? 2 : 3);
    lua_Integer m = lua_tointeger(L, mode == mode_table ? 3 : 4);
    lua_createtable(L, (int) n, 0);
    if (s) {
        start = p;
        switch (m) {
            case 1:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (p >= l) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_pushinteger(L, a);
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 2:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (l - p < 2) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_Integer b = uchar(s[p++]);
                        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 8) | (uint32_t) b));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 3:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (l - p < 3) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_Integer b = uchar(s[p++]);
                        lua_Integer c = uchar(s[p++]);
                        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 4:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (l - p < 4) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_Integer b = uchar(s[p++]);
                        lua_Integer c = uchar(s[p++]);
                        lua_Integer d = uchar(s[p++]);
                        lua_pushinteger(L, (lua_Integer) (((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            default:
                break;
        }
        siolib_done(L, mode, (lua_Integer) (p - start));
    }
    return 1;
}

static int fiolib_readinteger1(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, siolib_signed8((uint32_t) a));
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger1(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 1, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, siolib_signed8((uint32_t) a));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readinteger2(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                lua_pushinteger(L, siolib_signed16(((uint32_t) a << 8) | (uint32_t) b));
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readinteger2_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int b = getc(f);
        if (b != EOF) {
            int a = getc(f);
            if (a != EOF) {
                lua_pushinteger(L, siolib_signed16(((uint32_t) a << 8) | (uint32_t) b));
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger2(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 2, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p]);
        lua_pushinteger(L, siolib_signed16(((uint32_t) a << 8) | (uint32_t) b));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readinteger2_le(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 2, &p, NULL, NULL);
    if (s) {
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, siolib_signed16(((uint32_t) a << 8) | (uint32_t) b));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readinteger3(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int c = getc(f);
                if (c != EOF) {
                    uint32_t u = ((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c;
                    lua_pushinteger(L, siolib_signed24(u));
                    return 1;
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readinteger3_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int c = getc(f);
        if (c != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int a = getc(f);
                if (a != EOF) {
                    uint32_t u = ((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c;
                    lua_pushinteger(L, siolib_signed24(u));
                    return 1;
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger3(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 3, &p, NULL, NULL);
    if (s) {
        uint32_t a = uchar(s[p++]);
        uint32_t b = uchar(s[p++]);
        uint32_t c = uchar(s[p]);
        lua_pushinteger(L, siolib_signed24((a << 16) | (b << 8) | c));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readinteger3_le(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 3, &p, NULL, NULL);
    if (s) {
        uint32_t c = uchar(s[p++]);
        uint32_t b = uchar(s[p++]);
        uint32_t a = uchar(s[p]);
        lua_pushinteger(L, siolib_signed24((a << 16) | (b << 8) | c));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readinteger4(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int c = getc(f);
                if (c != EOF) {
                    int d = getc(f);
                    if (d != EOF) {
                        lua_pushinteger(L, siolib_signed32(((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                        return 1;
                    }
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readinteger4_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int d = getc(f);
        if (d != EOF) {
            int c = getc(f);
            if (c != EOF) {
                int b = getc(f);
                if (b != EOF) {
                    int a = getc(f);
                    if (a != EOF) {
                        lua_pushinteger(L, siolib_signed32(((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                        return 1;
                    }
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger4(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer d = uchar(s[p]);
        lua_pushinteger(L, siolib_signed32(((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readinteger4_le(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        lua_Integer d = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, siolib_signed32(((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readintegertable(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        lua_Integer m = lua_tointeger(L, 3);
        lua_createtable(L, (int) n, 0);
        switch (m) {
            case 1:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) {
                        break;
                    } else {
                        lua_pushinteger(L, siolib_signed8((uint32_t) a));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 2:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) break;
                    int b = getc(f);
                    if (b == EOF) break;
                    lua_pushinteger(L, siolib_signed16(((uint32_t) a << 8) | (uint32_t) b));
                    lua_rawseti(L, -2, i);
                }
                break;
            case 3:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) break;
                    int b = getc(f);
                    if (b == EOF) break;
                    int c = getc(f);
                    if (c == EOF) break;
                    uint32_t u = ((uint32_t) a << 16) | ((uint32_t) b << 8) | (uint32_t) c;
                    lua_pushinteger(L, siolib_signed24(u));
                    lua_rawseti(L, -2, i);
                }
                break;
            case 4:
                for (lua_Integer i = 1; i <= n; i++) {
                    int a = getc(f);
                    if (a == EOF) break;
                    int b = getc(f);
                    if (b == EOF) break;
                    int c = getc(f);
                    if (c == EOF) break;
                    int d = getc(f);
                    if (d == EOF) break;
                    lua_pushinteger(L, siolib_signed32(((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                    lua_rawseti(L, -2, i);
                }
                break;
            default:
                break;
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readintegertable(lua_State *L)
{
    size_t p, l;
    size_t start;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    /*tex We need to know the mode so we delay updating the advance. */
    lua_Integer n = lua_tointeger(L, mode == mode_table ? 2 : 3);
    lua_Integer m = lua_tointeger(L, mode == mode_table ? 3 : 4);
    lua_createtable(L, (int) n, 0);
    if (s) {
        start = p;
        switch (m) {
            case 1:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (p >= l) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_pushinteger(L, siolib_signed8((uint32_t) a));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 2:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (l - p < 2) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_Integer b = uchar(s[p++]);
                        lua_pushinteger(L, siolib_signed16(((uint32_t) a << 8) | (uint32_t) b));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 3:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (l - p < 3) {
                        break;
                    } else {
                        uint32_t a = uchar(s[p++]);
                        uint32_t b = uchar(s[p++]);
                        uint32_t c = uchar(s[p++]);
                        lua_pushinteger(L, siolib_signed24((a << 16) | (b << 8) | c));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 4:
                for (lua_Integer i = 1; i <= n; i++) {
                    if (l - p < 4) {
                        break;
                    } else {
                        lua_Integer a = uchar(s[p++]);
                        lua_Integer b = uchar(s[p++]);
                        lua_Integer c = uchar(s[p++]);
                        lua_Integer d = uchar(s[p++]);
                        lua_pushinteger(L, siolib_signed32(((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d));
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            default:
                break;
        }
        siolib_done(L, mode, (lua_Integer) (p - start));
    }
    return 1;
}

static int fiolib_readfixed2(lua_State *L) // signed
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int16_t n = siolib_signed16(((uint32_t) a << 8) | (uint32_t) b);
                lua_pushnumber(L, (double) n / 256.0);
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readfixed2(lua_State *L) // signed
{
    size_t p;
    const char *s = siolib_okay(L, 2, &p, NULL, NULL);
    if (s) {
        int a = uchar(s[p++]);
        int b = uchar(s[p]);
        int16_t n = siolib_signed16(((uint32_t) a << 8) | (uint32_t) b);
        lua_pushnumber(L, (double) n / 256.0);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readfixed4(lua_State *L) // signed
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int c = getc(f);
                if (c != EOF) {
                    int d = getc(f);
                    if (d != EOF) {
                        uint32_t u = ((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d;
                        int32_t n = siolib_signed32(u);
                        lua_pushnumber(L, (double) n / 65536.0);
                        return 1;
                    }
                }
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readfixed4(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        int a = uchar(s[p++]);
        int b = uchar(s[p++]);
        int c = uchar(s[p++]);
        int d = uchar(s[p]);
        uint32_t u = ((uint32_t) a << 24) | ((uint32_t) b << 16) | ((uint32_t) c << 8) | (uint32_t) d;
        int32_t n = siolib_signed32(u);
        lua_pushnumber(L, (double) n / 65536.0);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_read2dot14(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        if (a != EOF) {
            int b = getc(f);
            if (b != EOF) {
                int16_t n = siolib_signed16(((uint32_t) a << 8) | (uint32_t) b);
                lua_pushnumber(L, (double) n / 16384.0);
                return 1;
            }
        }
        lua_pushnil(L);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_read2dot14(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 2, &p, NULL, NULL);
    if (s) {
        int a = uchar(s[p++]);
        int b = uchar(s[p]);
        int16_t n = siolib_signed16(((uint32_t) a << 8) | (uint32_t) b);
        lua_pushnumber(L, (double) n / 16384.0);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex
    The const union trick is taken from \LUA, and let's assume that the compiler then
    optimizes the branches.
*/

static const union {
    int  dummy;
    char little;  /* true iff machine is little endian */
} nativeendian = { 1 };

static inline void copywithendian(char *dest, const char *src, unsigned size, int islittle)  /* taken from lua */
{
    if (islittle == nativeendian.little)
        memcpy(dest, src, size);
    else {
        dest += size - 1;
        while (size-- != 0) {
            *(dest--) = *(src++);
        }
    }
}

static inline int readwithendian4(char *dest, FILE *f, int islittle)  /* taken from lua */
{
    if (islittle == nativeendian.little) {
        for (unsigned i = 0; i < 4; i++) {
            int c = getc(f);
            if (c == EOF) {
                return 0;
            }
            dest[i] = (char) c;
        }
    } else {
        for (unsigned i = 0; i < 4; i++) {
            int c = getc(f);
            if (c == EOF) {
                return 0;
            }
            dest[3 - i] = (char) c;
        }
    }
    return 1;
}

static inline int readwithendian8(char *dest, FILE *f, int islittle)  /* taken from lua */
{
    if (islittle == nativeendian.little) {
        for (unsigned i = 0; i < 8; i++) {
            int c = getc(f);
            if (c == EOF) {
                return 0;
            }
            dest[i] = (char) c;
        }
    } else {
        for (unsigned i = 0; i < 8; i++) {
            int c = getc(f);
            if (c == EOF) {
                return 0;
            }
            dest[7 - i] = (char) c;
        }
    }
    return 1;
}

static inline void writewithendian(char *dest, FILE *f, unsigned size, int islittle)
{
    if (islittle == nativeendian.little) {
        for (unsigned i = 0; i < size; i++) {
            putc(dest[i], f);
        }
    } else {
        for (unsigned i = 0; i < size; i++) {
            putc(dest[size-1-i], f);
        }
    }
}

/* */

typedef struct floatcast  { union { char c[4]; float  f; }; } floatcast;
typedef struct doublecast { union { char c[8]; double d; }; } doublecast;

static int fiolib_readfloat(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        floatcast flt;
        if (readwithendian4(&flt.c[0], f, 0)) {
            lua_pushnumber(L, (double) flt.f);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_writefloat(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        floatcast flt;
        flt.f = (float) lua_tonumber(L, 2);
        writewithendian(&flt.c[0], f, 4, 0);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readfloatle(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        floatcast flt;
        if (readwithendian4(&flt.c[0], f, 1)) {
            lua_pushnumber(L, (double) flt.f);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_writefloatle(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        floatcast flt;
        flt.f = (float) lua_tonumber(L, 2);
        writewithendian(&flt.c[0], f, 4, 1);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readfloat(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        floatcast flt;
        copywithendian(&flt.c[0], &s[p], 4, 0);
        lua_pushnumber(L, (double) flt.f);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readfloatle(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 4, &p, NULL, NULL);
    if (s) {
        floatcast flt;
        copywithendian(&flt.c[0], &s[p], 4, 1);
        lua_pushnumber(L, (double) flt.f);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex
    These two are for stl files and they are not official and might go away again.
*/

static int siolib_readfloatle6(lua_State *L)
{
    size_t p; /* advance: six floats each four bytes */
    const char *s = siolib_okay(L, 24, &p, NULL, NULL);
    if (s) {
        for (int i = 0; i < 6; i++) {
            floatcast flt;
            copywithendian(&flt.c[0], &s[p], 4, 1);
            lua_pushnumber(L, (double) flt.f);
            p += 4;
        }
        return 6;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readfloatle12(lua_State *L)
{
    size_t p; /* advance: twelve floats each four bytes */
    const char *s = siolib_okay(L, 48, &p, NULL, NULL);
    if (s) {
        for (int i = 0; i < 12; i++) {
            floatcast flt;
            copywithendian(&flt.c[0], &s[p], 4, 1);
            lua_pushnumber(L, (double) flt.f);
            p += 4;
        }
        return 12;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex Till here. */

static int fiolib_readdouble(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        doublecast dbl;
        if (readwithendian8(&dbl.c[0], f, 0)) {
            lua_pushnumber(L, dbl.d);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_writedouble(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        doublecast dbl;
        dbl.d = lua_tonumber(L, 2);
        writewithendian(&dbl.c[0], f, 8, 0);
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readdoublele(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        doublecast dbl;
        if (readwithendian8(&dbl.c[0], f, 1)) {
            lua_pushnumber(L, dbl.d);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_writedoublele(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        doublecast dbl;
        dbl.d = lua_tonumber(L, 2);
        writewithendian(&dbl.c[0], f, 8, 1);
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readdouble(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 8, &p, NULL, NULL);
    if (s) {
        doublecast dbl;
        copywithendian(&dbl.c[0], &s[p], 8, 0);
        lua_pushnumber(L, dbl.d);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int siolib_readdoublele(lua_State *L)
{
    size_t p;
    const char *s = siolib_okay(L, 8, &p, NULL, NULL);
    if (s) {
        doublecast dbl;
        copywithendian(&dbl.c[0], &s[p], 8, 1);
        lua_pushnumber(L, dbl.d);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* */

static int fiolib_getposition(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        l_seeknum p = l_ftell(f);
        if (p < 0) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, (lua_Integer) p);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_setposition(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        l_seeknum p = (l_seeknum) lua_tointeger(L, 2);
        if (l_fseek(f, p, SEEK_SET) == 0) {
            lua_pushinteger(L, (lua_Integer) l_ftell(f));
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_skipposition(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        l_seeknum p = (l_seeknum) lua_tointeger(L, 2);
        if (l_fseek(f, p, SEEK_CUR) == 0) {
            lua_pushinteger(L, (lua_Integer) l_ftell(f));
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readbytetable(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        lua_createtable(L, (int) n, 0);
        for (lua_Integer i = 1; i <= n; i++) {
            int a = getc(f);
            if (a == EOF) {
                break;
            } else {
                lua_pushinteger(L, a);
                lua_rawseti(L, -2, i);
            }
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readbytetable(lua_State *L)
{
    size_t p, l;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    int n = lmt_tointeger(L, mode == mode_table ? 2 : 3);
    if (s) {
        lua_createtable(L, (int) n, 0);
        int i = 1;
        for (; i <= n && p < l; i++) {
            int a = uchar(s[p++]);
            lua_pushinteger(L, a);
            lua_rawseti(L, -2, i);
        }
        siolib_done(L, mode, i - 1);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int fiolib_readbytes(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        for (lua_Integer i = 1; i <= n; i++) {
            int a = getc(f);
            if (a == EOF) {
                return (int) (i - 1);
            } else {
                lua_pushinteger(L, a);
            }
        }
        return (int) n;
    } else {
        return 0;
    }
}

static int siolib_readbytes(lua_State *L)
{
    size_t p, l;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    int n = lmt_tointeger(L, mode == mode_table ? 2 : 3);
    if (s) {
        int i = 1;
        for (; i <= n && p < l; i++) {
            int a = uchar(s[p++]);
            lua_pushinteger(L, a);
        }
        siolib_done(L, mode, i - 1);
        return i - 1;
    } else {
        return 0;
    }
}

/*tex
    When we fail, we return nil.
*/

static int fiolib_readcline(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        luaL_Buffer buf;
        int c = 0;
        int n = 0;
        luaL_buffinit(L, &buf);
        do {
            char *b = luaL_prepbuffer(&buf);
            int i = 0;
            while (i < LUAL_BUFFERSIZE) {
                c = fgetc(f);
                if (c == '\n') {
                    goto GOOD;
                } else if (c == '\r') {
                    c = fgetc(f);
                    if (c != EOF && c != '\n') {
                        ungetc(c, f);
                    }
                    goto GOOD;
                } else if (c == EOF) {
                    if (n > 0) {
                        goto GOOD;
                    } else {
                        goto BAD;
                    }
                } else {
                    n++;
                    b[i++] = (char) c;
                }
            }
        } while (c != EOF);
        goto BAD;
        if (n == 0) {
            goto BAD;
        }
      GOOD:
        luaL_addsize(&buf, n);
        luaL_pushresult(&buf);
        lua_pushinteger(L, (lua_Integer) l_ftell(f));
        return 2;
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

static int siolib_readcline(lua_State *L)
{
    size_t p, l;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    if (s) {
        size_t i = p;
        int n = 0;
        while (p < l) {
            int c = uchar(s[p++]);
            if (c == '\n') {
                goto GOOD;
            } else if (c == '\r') {
                if (p < l) {
                    c = uchar(s[p]);
                    if (c == '\n') {
                        p++;
                    }
                }
                goto GOOD;
            } else {
                n++;
            }
        }
        if (n > 0) {
            goto GOOD;
        }
        goto BAD;
      GOOD:
        siolib_done(L, mode, p - i);
        lua_pushlstring(L, &s[i], n);
        lua_pushinteger(L, p + 1);
        return 2;
    }
  BAD:
    siolib_done(L, mode, 1);
    lua_pushnil(L);
 // lua_pushinteger(L, p + 1);
 // return 2;
    return 1;
}

static int fiolib_readcstring(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        luaL_Buffer buf;
        int c = 0;
        int n = 0;
        luaL_buffinit(L, &buf);
        do {
            char *b = luaL_prepbuffer(&buf);
            int i = 0;
            while (i < LUAL_BUFFERSIZE) {
                c = fgetc(f);
                if (c == '\0') {
                    goto GOOD;
                } else if (c == EOF) {
                    if (n > 0) {
                        goto GOOD;
                    } else {
                        goto BAD;
                    }
                } else {
                    n++;
                    b[i++] = (char) c;
                }
            }
        } while (c != EOF);
        goto BAD;
      GOOD:
        if (n > 0) {
            luaL_addsize(&buf, n);
            luaL_pushresult(&buf);
        } else {
            lua_pushliteral(L, "");
        }
        lua_pushinteger(L, (lua_Integer) l_ftell(f));
        return 2;
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

static int siolib_readcstring(lua_State *L)
{
    size_t p, l;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    if (s) {
        size_t i = p;
        int n = 0;
        while (p < l) {
            int c = uchar(s[p++]);
            if (c == '\0') {
                goto GOOD;
            } else {
                n++;
            }
        }
        goto BAD;
      GOOD:
        if (n > 0) {
            siolib_done(L, mode, n + 1);
            lua_pushlstring(L, &s[i], n);
        } else {
            siolib_done(L, mode, 1);
            lua_pushliteral(L, "");
        }
        lua_pushinteger(L, p + 1);
        return 2;
    }
  BAD:
    siolib_done(L, mode, 1);
    lua_pushnil(L);
 // lua_pushinteger(L, p + 1);
 // return 2;
    return 1;
}

/* */

static int fiolib_readnstring(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    size_t n = (size_t) luaL_checkinteger(L, 2);
    if (! f) {
        lua_pushnil(L);
        return 1;
    }
    luaL_Buffer buf;
    char *b = luaL_buffinitsize(L, &buf, n);
    size_t bytes_read = fread(b, 1, n, f);
    if (bytes_read == 0) {
        lua_pushliteral(L, "");
        lua_pushinteger(L, (lua_Integer) l_ftell(f));
        return 2;
    }
    char *nul = memchr(b, '\0', bytes_read);
    size_t len = nul ? (size_t) (nul - b) : bytes_read;
    luaL_addsize(&buf, len);
    luaL_pushresult(&buf);
    lua_pushinteger(L, (lua_Integer) l_ftell(f));
    return 2;
}

static int siolib_readnstring(lua_State *L)
{
    size_t p, l;
    int mode;
    const char *s = siolib_okay(L, 0, &p, &l, &mode);
    lua_Integer max_n = luaL_checkinteger(L, 2);
    if (s) {
        size_t i = p;
        size_t n = 0;
        int found_nul = 0;
        while (p < l && (lua_Integer)n < max_n) {
            int c = uchar(s[p++]);
            if (c == '\0') {
                found_nul = 1;
                break;
            } else {
                n++;
            }
        }
        if (n > 0 || found_nul) {
            /* also skip the nul when found */
            size_t consumed = found_nul ? n + 1 : n;
            siolib_done(L, mode, consumed);
            lua_pushlstring(L, &s[i], n);
        } else {
            siolib_done(L, mode, 1);
            lua_pushliteral(L, "");
        }
        lua_pushinteger(L, p + 1);
        return 2;
    }
    siolib_done(L, mode, 1);
    lua_pushnil(L);
    return 1;
}

/* will be completed */

static int fiolib_writecardinal1(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) (n & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal1(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[1] = { (char) (n & 0xFF) };
    lua_pushlstring(L, buffer, 1);
    return 1;
}

static int fiolib_writecardinal2(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) ((n >> 8) & 0xFF), f);
        putc((char) ( n       & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal2(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[2] = {
        (char) ((n >> 8) & 0xFF),
        (char) ( n       & 0xFF)
    };
    lua_pushlstring(L, buffer, 2);
    return 1;
}

static int fiolib_writecardinal2_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) ( n       & 0xFF), f);
        putc((char) ((n >> 8) & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal2_le(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[2] = {
        (char) ( n       & 0xFF),
        (char) ((n >> 8) & 0xFF)
    };
    lua_pushlstring(L, buffer, 2);
    return 1;
}

static int fiolib_writecardinal3(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) ((n >> 16) & 0xFF), f);
        putc((char) ((n >>  8) & 0xFF), f);
        putc((char) ( n        & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal3(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[3] = {
        (char) ((n >> 16) & 0xFF),
        (char) ((n >>  8) & 0xFF),
        (char) ( n        & 0xFF)
    };
    lua_pushlstring(L, buffer, 3);
    return 1;
}

static int fiolib_writecardinal3_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) ( n        & 0xFF), f);
        putc((char) ((n >>  8) & 0xFF), f);
        putc((char) ((n >> 16) & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal3_le(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[3] = {
        (char) ( n        & 0xFF),
        (char) ((n >>  8) & 0xFF),
        (char) ((n >> 16) & 0xFF)
    };
    lua_pushlstring(L, buffer, 3);
    return 1;
}

static int fiolib_writecardinal4(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) ((n >> 24) & 0xFF), f);
        putc((char) ((n >> 16) & 0xFF), f);
        putc((char) ((n >>  8) & 0xFF), f);
        putc((char) ( n        & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal4(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[4] = {
        (char) ((n >> 24) & 0xFF),
        (char) ((n >> 16) & 0xFF),
        (char) ((n >>  8) & 0xFF),
        (char) ( n        & 0xFF)
    };
    lua_pushlstring(L, buffer, 4);
    return 1;
}

static int fiolib_writecardinal4_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        uint64_t n = (uint64_t) lua_tointeger(L, 2);
        putc((char) ( n        & 0xFF), f);
        putc((char) ((n >>  8) & 0xFF), f);
        putc((char) ((n >> 16) & 0xFF), f);
        putc((char) ((n >> 24) & 0xFF), f);
    }
    return 0;
}

static int siolib_tocardinal4_le(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[4] = {
        (char) ( n        & 0xFF),
        (char) ((n >>  8) & 0xFF),
        (char) ((n >> 16) & 0xFF),
        (char) ((n >> 24) & 0xFF)
    };
    lua_pushlstring(L, buffer, 4);
    return 1;
}

static int siolib_tocardinal8(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[8] = {
        (char) (n >> 56),
        (char) (n >> 48),
        (char) (n >> 40),
        (char) (n >> 32),
        (char) (n >> 24),
        (char) (n >> 16),
        (char) (n >>  8),
        (char) (n & 0xFF)
    };
    lua_pushlstring(L, buffer, 8);
    return 1;
}

static int siolib_tocardinal8_le(lua_State *L)
{
    uint64_t n = (uint64_t) lua_tointeger(L, 1);
    char buffer[8] = {
        (char) (n & 0xFF),
        (char) (n >>  8),
        (char) (n >> 16),
        (char) (n >> 24),
        (char) (n >> 32),
        (char) (n >> 40),
        (char) (n >> 48),
        (char) (n >> 56)
    };
    lua_pushlstring(L, buffer, 8);
    return 1;
}
/* */

static const luaL_Reg fiolib_function_list[] = {
    /* helpers */

    { "readcardinal1",     fiolib_readcardinal1     },
    { "readcardinal2",     fiolib_readcardinal2     },
    { "readcardinal3",     fiolib_readcardinal3     },
    { "readcardinal4",     fiolib_readcardinal4     },

    { "readcardinal1le",   fiolib_readcardinal1     },
    { "readcardinal2le",   fiolib_readcardinal2_le  },
    { "readcardinal3le",   fiolib_readcardinal3_le  },
    { "readcardinal4le",   fiolib_readcardinal4_le  },

    { "readcardinaltable", fiolib_readcardinaltable },

    { "readinteger1",      fiolib_readinteger1      },
    { "readinteger2",      fiolib_readinteger2      },
    { "readinteger3",      fiolib_readinteger3      },
    { "readinteger4",      fiolib_readinteger4      },

    { "readinteger1le",    fiolib_readinteger1      },
    { "readinteger2le",    fiolib_readinteger2_le   },
    { "readinteger3le",    fiolib_readinteger3_le   },
    { "readinteger4le",    fiolib_readinteger4_le   },

    { "readintegertable",  fiolib_readintegertable  },

    { "readfixed2",        fiolib_readfixed2        },
    { "readfixed4",        fiolib_readfixed4        },

    { "readfloat",         fiolib_readfloat         },
    { "readdouble",        fiolib_readdouble        },
    { "readfloatle",       fiolib_readfloatle       },
    { "readdoublele",      fiolib_readdoublele      },

    { "read2dot14",        fiolib_read2dot14        },

    { "setposition",       fiolib_setposition       },
    { "getposition",       fiolib_getposition       },
    { "skipposition",      fiolib_skipposition      },

    { "readbytes",         fiolib_readbytes         },
    { "readbytetable",     fiolib_readbytetable     },

    { "readcline",         fiolib_readcline         },
    { "readcstring",       fiolib_readcstring       },
    { "readnstring",       fiolib_readnstring       },

    { "writecardinal1",    fiolib_writecardinal1    },
    { "writecardinal2",    fiolib_writecardinal2    },
    { "writecardinal3",    fiolib_writecardinal3    },
    { "writecardinal4",    fiolib_writecardinal4    },

    { "writecardinal1le",  fiolib_writecardinal1    },
    { "writecardinal2le",  fiolib_writecardinal2_le },
    { "writecardinal3le",  fiolib_writecardinal3_le },
    { "writecardinal4le",  fiolib_writecardinal4_le },

    { "writefloat",        fiolib_writefloat        },
    { "writedouble",       fiolib_writedouble       },
    { "writefloatle",      fiolib_writefloatle      },
    { "writedoublele",     fiolib_writedoublele     },

    { NULL,                NULL                     }
};

static const luaL_Reg siolib_function_list[] = {

    { "readcardinal1",     siolib_readcardinal1     },
    { "readcardinal2",     siolib_readcardinal2     },
    { "readcardinal3",     siolib_readcardinal3     },
    { "readcardinal4",     siolib_readcardinal4     },

    { "readcardinal1le",   siolib_readcardinal1     },
    { "readcardinal2le",   siolib_readcardinal2_le  },
    { "readcardinal3le",   siolib_readcardinal3_le  },
    { "readcardinal4le",   siolib_readcardinal4_le  },

    { "readcardinaltable", siolib_readcardinaltable },

    { "readinteger1",      siolib_readinteger1      },
    { "readinteger2",      siolib_readinteger2      },
    { "readinteger3",      siolib_readinteger3      },
    { "readinteger4",      siolib_readinteger4      },

    { "readinteger1le",    siolib_readinteger1      },
    { "readinteger2le",    siolib_readinteger2_le   },
    { "readinteger3le",    siolib_readinteger3_le   },
    { "readinteger4le",    siolib_readinteger4_le   },

    { "readintegertable",  siolib_readintegertable  },

    { "readfixed2",        siolib_readfixed2        },
    { "readfixed4",        siolib_readfixed4        },
    { "read2dot14",        siolib_read2dot14        },

    { "readfloat",         siolib_readfloat         },
    { "readdouble",        siolib_readdouble        },
    { "readfloatle",       siolib_readfloatle       },
    { "readdoublele",      siolib_readdoublele      },

    { "readfloatle6",      siolib_readfloatle6      },
    { "readfloatle12",     siolib_readfloatle12     },

    { "readbytes",         siolib_readbytes         },
    { "readbytetable",     siolib_readbytetable     },

    { "readcline",         siolib_readcline         },
    { "readcstring",       siolib_readcstring       },
    { "readnstring",       siolib_readnstring       },

    { "tocardinal1",       siolib_tocardinal1       },
    { "tocardinal2",       siolib_tocardinal2       },
    { "tocardinal3",       siolib_tocardinal3       },
    { "tocardinal4",       siolib_tocardinal4       },
    { "tocardinal8",       siolib_tocardinal8       },

    { "tocardinal1le",     siolib_tocardinal1       },
    { "tocardinal2le",     siolib_tocardinal2_le    },
    { "tocardinal3le",     siolib_tocardinal3_le    },
    { "tocardinal4le",     siolib_tocardinal4_le    },
    { "tocardinal8le",     siolib_tocardinal8_le    },

    { "tointeger1",        siolib_tocardinal1       },
    { "tointeger2",        siolib_tocardinal2       },
    { "tointeger3",        siolib_tocardinal3       },
    { "tointeger4",        siolib_tocardinal4       },
    { "tointeger8",        siolib_tocardinal8       },

    { "tointeger1le",      siolib_tocardinal1       },
    { "tointeger2le",      siolib_tocardinal2_le    },
    { "tointeger3le",      siolib_tocardinal3_le    },
    { "tointeger4le",      siolib_tocardinal4_le    },
    { "tointeger8le",      siolib_tocardinal8_le    },

    { NULL,                NULL                     }
};

/*tex

    The sio helpers might be handy at some point. Speed-wise there is no gain over file access
    because with ssd and caching we basically operate in memory too. We keep them as complement to
    the file ones. I did consider using an userdata object for the position etc but some simple
    tests demonstrated that there is no real gain and the current ones permits to wrap up whatever
    interface one likes.

*/

int luaopen_fio(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, fiolib_function_list, 0);
    return 1;
}

int luaopen_sio(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, siolib_function_list, 0);
    return 1;
}

/* We patch a function in the standard |io| library. */

/*tex

    The following code overloads the |io.open| function to deal with so called wide characters on
    windows.

*/

/* a variant on read_line but with nothing catched */

static int io_gobble(lua_State *L) 
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        int c;
        int n = 0;
        while ((c = getc(f)) != EOF && c != '\n') {
            n = 1;
        }
        lua_pushboolean(L, ((c == '\n') || n));
    } else { 
        lua_pushnil(L);
    }
    return 1;
}

# define tolstream(L) ((LStream *) luaL_checkudata(L, 1, LUA_FILEHANDLE))

/*
    single arw | single + | only b's at the end

    r rb w w+ w+b a+bb
*/

static int l_checkmode(const char *mode)
{
    return (
         mode
     && *mode != '\0'
     && strchr("rwa", *(mode++))
     && (*mode != '+' || ((void) (++mode), 1))
     && (strspn(mode, "b") == strlen(mode))
    );
}

typedef luaL_Stream LStream;

static LStream *newprefile(lua_State *L)
{
    LStream *p = (LStream *) lua_newuserdatauv(L, sizeof(LStream), 0);
    p->closef = NULL;
    luaL_setmetatable(L, LUA_FILEHANDLE);
    return p;
}

static int io_fclose(lua_State *L)
{
    LStream *p = tolstream(L);
    int res = fclose(p->f);
    return luaL_fileresult(L, (res == 0), NULL);
}

static LStream *newfile(lua_State *L)
{
    LStream *p = newprefile(L);
    p->f = NULL;
    p->closef = &io_fclose;
    return p;
}

/*tex
    Watch out: |+| means update so |w+| and |r+| open files for reading and writing.
*/

static inline int io_aux_check_open(lua_State *L, const char **filename, const char **mode)
{
    *filename = luaL_checkstring(L, 1);
    *mode     = luaL_optstring(L, 2, "r");
    luaL_argcheck(L, l_checkmode(*mode), 2, "invalid mode");
    int is_write = (strchr(*mode, 'w') != NULL || strchr(*mode, 'a') != NULL || strchr(*mode, '+') != NULL);
    int is_read  = (strchr(*mode, 'r') != NULL                               || strchr(*mode, '+') != NULL);
    if (is_read && ! lmt_valid_target(L, security_readable, *filename, security_open_file)) {
        errno = EACCES;
        return 0;
    }
    if (is_write && ! lmt_valid_target(L, security_writable, *filename, security_open_file)) {
        errno = EACCES;
        return 0;
    }
    return 1;
}

static inline int io_aux_check_popen(lua_State *L, const char **filename, const char **mode)
{
    *filename = luaL_checkstring(L, 1);
    *mode     = luaL_optstring(L, 2, "r");
    luaL_argcheck(L, l_checkmode(*mode), 2, "invalid mode");
    if (! lmt_valid_target(L, security_executable, *filename, security_open_pipe)) {
        errno = EACCES;
        return 0;
    }
    return 1;
}

static int io_open(lua_State *L)
{
    const char *filename, *mode;
    if (! io_aux_check_open(L, &filename, &mode)) {
        return luaL_fileresult(L, 0, filename);
    }
    LStream *p = newfile(L);
# ifdef _WIN32
    p->f = aux_utf8_fopen(filename, mode);
# else
    p->f = fopen(filename, mode);
# endif
    return (p->f) ? 1 : luaL_fileresult(L, 0, filename);
}

static int io_pclose(lua_State *L)
{
    LStream *p = tolstream(L);
# ifdef _WIN32
    int stat = _pclose(p->f);
# else
    int stat = pclose(p->f);
# endif
    return luaL_execresult(L, stat);
}

static int io_popen(lua_State *L)
{
    const char *filename, *mode;
    if (! io_aux_check_popen(L, &filename, &mode)) {
        return luaL_fileresult(L, 0, filename);
    }
    LStream *p = newprefile(L);
# ifdef _WIN32
    /* strip '+' and map 'a' -> 'w' to prevent parameter validation aborts */
    char win_mode[8];
    int idx = 0;
    for (const char *m = mode; *m != '\0' && idx < (int) sizeof(win_mode) - 1; m++) {
        if (*m == '+') { \
            /* drop the read/write update modifier */
            continue;
        } else if (*m == 'a') {
            /* convert append to write */
            win_mode[idx++] = 'w';
        } else {
            /* keep the mode */
            win_mode[idx++] = *m;
        }
    }
    win_mode[idx] = '\0';
    p->f = aux_utf8_popen(filename, win_mode);
# else
    p->f = popen(filename, mode);
# endif
    p->closef = &io_pclose;
    return (p->f) ? 1 : luaL_fileresult(L, 0, filename);
}

# ifndef _WIN32
    # include <sys/resource.h>
# endif

int luaextend_io(lua_State *L)
{
    lua_getglobal(L, "io");
    lua_pushcfunction(L, io_open);   lua_setfield(L, -2, "open");
    lua_pushcfunction(L, io_popen);  lua_setfield(L, -2, "popen");
    lua_pushcfunction(L, io_gobble); lua_setfield(L, -2, "gobble");
    lua_pop(L, 1);
# ifdef _WIN32
    if (_setmaxstdio(2048) < 0) {
        /*tex
            More than this doesn't work and if we can't raise that much we fall back to 512. It
            looks like normally we're fine. For \TEX\ these limits mostly concerns image inclusion.
        */
        _setmaxstdio(512);
    }
# else
    /*tex
        We raise the soft limit on POSIX systems to 2048 or keep the maximum allowed hard limit.
    */
    struct rlimit rl;
    if (getrlimit(RLIMIT_NOFILE, &rl) == 0) {
        if (rl.rlim_cur < 2048) {
            rlim_t target = 2048;
            /* cannot exceed hard limit (rlim_max) without root privileges */
            rl.rlim_cur = (rl.rlim_max < target) ? rl.rlim_max : target;
            setrlimit(RLIMIT_NOFILE, &rl);
        }
    }
# endif
    return 1;
}
