/*
    See license.txt in the root of this project.
*/

/*tex

    Lua doesn't have cardinals so basically we could stick to integers and accept that we have a
    limited range.

*/

# include "luametatex.h"

# ifdef _WIN32

    # define lua_popen(L,c,m)   ((void)L, _popen(c,m))
    # define lua_pclose(L,file) ((void)L, _pclose(file))

# else

    # define lua_popen(L,c,m)   ((void)L, fflush(NULL), popen(c,m))
    # define lua_pclose(L,file) ((void)L, pclose(file))

# endif

/* Mojca: we need to sort this out! */

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

/*tex

    A few helpers to avoid reading numbers as strings. For now we put them in their own namespace.
    We also have a few helpers that can make \IO\ functions \TEX\ friendly.

*/

static int fiolib_readcardinal1(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
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

static int siolib_readcardinal1(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p =  luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if (p >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, a);
    }
    return 1;
}

static int fiolib_readcardinal2(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        lua_Integer b = getc(f);
        if (b == EOF) {
            lua_pushnil(L);
        } else {
            /* (a<<8) | b */
            lua_pushinteger(L, 0x100 * a + b);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readcardinal2_le(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer b = getc(f);
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else {
            /* (a<<8) | b */
            lua_pushinteger(L, 0x100 * a + b);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal2(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 1) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p]);
        lua_pushinteger(L, 0x100 * a + b);
    }
    return 1;
}

static int siolib_readcardinal2_le(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 1) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, 0x100 * a + b);
    }
    return 1;
}

static int fiolib_readcardinal3(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        lua_Integer b = getc(f);
        lua_Integer c = getc(f);
        if (c == EOF) {
            lua_pushnil(L);
        } else {
            /* (a<<16) | (b<<8) | c */
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readcardinal3_le(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer c = getc(f);
        lua_Integer b = getc(f);
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else {
            /* (a<<16) | (b<<8) | c */
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal3(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 2) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p]);
        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
    }
    return 1;
}

static int siolib_readcardinal3_le(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 2) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
    }
    return 1;
}

static int fiolib_readcardinal4(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        lua_Integer b = getc(f);
        lua_Integer c = getc(f);
        lua_Integer d = getc(f);
        if (d == EOF) {
            lua_pushnil(L);
        } else {
            /* (a<<24) | (b<<16) | (c<<8) | d */
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readcardinal4_le(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer d = getc(f);
        lua_Integer c = getc(f);
        lua_Integer b = getc(f);
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else {
            /* (a<<24) | (b<<16) | (c<<8) | d */
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readcardinal4(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 3) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer d = uchar(s[p]);
        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
    }
    return 1;
}

static int siolib_readcardinal4_le(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 3) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer d = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
    }
    return 1;
}

static int fiolib_readcardinaltable(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        lua_Integer m = lua_tointeger(L, 3);
        lua_createtable(L, (int) n, 0);
        switch (m) {
            case 1:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
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
                    lua_Integer a = getc(f);
                    lua_Integer b = getc(f);
                    if (b == EOF) {
                        break;
                    } else {
                        /* (a<<8) | b */
                        lua_pushinteger(L, 0x100 * a + b);
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 3:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
                    lua_Integer b = getc(f);
                    lua_Integer c = getc(f);
                    if (c == EOF) {
                        break;
                    } else {
                        /* (a<<16) | (b<<8) | c */
                        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
                        lua_rawseti(L, -2, i);
                    }
                }
                break;
            case 4:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
                    lua_Integer b = getc(f);
                    lua_Integer c = getc(f);
                    lua_Integer d = getc(f);
                    if (d == EOF) {
                        break;
                    } else {
                        /* (a<<24) | (b<<16) | (c<<8) | d */
                        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
                        lua_rawseti(L, -2, i);
                    }
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

static int siolib_readcardinaltable(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer n = lua_tointeger(L, 3);
    lua_Integer m = lua_tointeger(L, 4);
    lua_Integer l = (lua_Integer) ls;
    lua_createtable(L, (int) n, 0);
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
                if ((p + 1) >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    lua_Integer b = uchar(s[p++]);
                    lua_pushinteger(L, 0x100 * a + b);
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        case 3:
            for (lua_Integer i = 1; i <= n; i++) {
                if ((p + 2) >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    lua_Integer b = uchar(s[p++]);
                    lua_Integer c = uchar(s[p++]);
                    lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        case 4:
            for (lua_Integer i = 1; i <= n; i++) {
                if ((p + 3) >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    lua_Integer b = uchar(s[p++]);
                    lua_Integer c = uchar(s[p++]);
                    lua_Integer d = uchar(s[p++]);
                    lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        default:
            break;
    }
    return 1;
}

static int fiolib_readinteger1(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, a - 0x100);
        } else {
            lua_pushinteger(L, a);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger1(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if (p >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, a - 0x100);
        } else {
            lua_pushinteger(L, a);
        }
    }
    return 1;
}

static int fiolib_readinteger2(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        lua_Integer b = getc(f);
        if (b == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, 0x100 * a + b - 0x10000);
        } else {
            lua_pushinteger(L, 0x100 * a + b);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readinteger2_le(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer b = getc(f);
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, 0x100 * a + b - 0x10000);
        } else {
            lua_pushinteger(L, 0x100 * a + b);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger2(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 1) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, 0x100 * a + b - 0x10000);
        } else {
            lua_pushinteger(L, 0x100 * a + b);
        }
    }
    return 1;
}

static int siolib_readinteger2_le(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 1) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, 0x100 * a + b - 0x10000);
        } else {
            lua_pushinteger(L, 0x100 * a + b);
        }
    }
    return 1;
}

static int fiolib_readinteger3(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        lua_Integer b = getc(f);
        lua_Integer c = getc(f);
        if (c == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c - 0x1000000);
        } else {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readinteger3_le(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer c = getc(f);
        lua_Integer b = getc(f);
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c - 0x1000000);
        } else {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger3(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 2) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c - 0x1000000);
        } else {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
        }
    }
    return 1;
}

static int siolib_readinteger3_le(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 2) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c - 0x1000000);
        } else {
            lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
        }
    }
    return 1;
}

static int fiolib_readinteger4(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer a = getc(f);
        lua_Integer b = getc(f);
        lua_Integer c = getc(f);
        lua_Integer d = getc(f);
        if (d == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d - 0x100000000);
        } else {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readinteger4_le(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer d = getc(f);
        lua_Integer c = getc(f);
        lua_Integer b = getc(f);
        lua_Integer a = getc(f);
        if (a == EOF) {
            lua_pushnil(L);
        } else if (a >= 0x80) {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d - 0x100000000);
        } else {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readinteger4(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 3) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer a = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer d = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d - 0x100000000);
        } else {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
        }
    }
    return 1;
}

static int siolib_readinteger4_le(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 3) >= l) {
        lua_pushnil(L);
    } else {
        lua_Integer d = uchar(s[p++]);
        lua_Integer c = uchar(s[p++]);
        lua_Integer b = uchar(s[p++]);
        lua_Integer a = uchar(s[p]);
        if (a >= 0x80) {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d - 0x100000000);
        } else {
            lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
        }
    }
    return 1;
}

static int fiolib_readintegertable(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        lua_Integer m = lua_tointeger(L, 3);
        lua_createtable(L, (int) n, 0);
        switch (m) {
            case 1:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
                    if (a == EOF) {
                        break;
                    } else if (a >= 0x80) {
                        lua_pushinteger(L, a - 0x100);
                    } else {
                        lua_pushinteger(L, a);
                    }
                    lua_rawseti(L, -2, i);
                }
                break;
            case 2:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
                    lua_Integer b = getc(f);
                    if (b == EOF) {
                        break;
                    } else if (a >= 0x80) {
                        lua_pushinteger(L, 0x100 * a + b - 0x10000);
                    } else {
                        lua_pushinteger(L, 0x100 * a + b);
                    }
                    lua_rawseti(L, -2, i);
                }
                break;
            case 3:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
                    lua_Integer b = getc(f);
                    lua_Integer c = getc(f);
                    if (c == EOF) {
                        break;
                    } else if (a >= 0x80) {
                        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c - 0x1000000);
                    } else {
                        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
                    }
                    lua_rawseti(L, -2, i);
                }
                break;
            case 4:
                for (lua_Integer i = 1; i <= n; i++) {
                    lua_Integer a = getc(f);
                    lua_Integer b = getc(f);
                    lua_Integer c = getc(f);
                    lua_Integer d = getc(f);
                    if (d == EOF) {
                        break;
                    } else if (a >= 0x80) {
                        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d - 0x100000000);
                    } else {
                        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
                    }
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

static int siolib_readintegertable(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer n = lua_tointeger(L, 3);
    lua_Integer m = lua_tointeger(L, 4);
    lua_Integer l = (lua_Integer) ls;
    lua_createtable(L, (int) n, 0);
    switch (m) {
        case 1:
            for (lua_Integer i = 1; i <= n; i++) {
                if (p >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    if (a >= 0x80) {
                        lua_pushinteger(L, a - 0x100);
                    } else {
                        lua_pushinteger(L, a);
                    }
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        case 2:
            for (lua_Integer i = 1; i <= n; i++) {
                if ((p + 1) >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    lua_Integer b = uchar(s[p++]);
                    if (a >= 0x80) {
                        lua_pushinteger(L, 0x100 * a + b - 0x10000);
                    } else {
                        lua_pushinteger(L, 0x100 * a + b);
                    }
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        case 3:
            for (lua_Integer i = 1; i <= n; i++) {
                if ((p + 2) >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    lua_Integer b = uchar(s[p++]);
                    lua_Integer c = uchar(s[p++]);
                    if (a >= 0x80) {
                        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c - 0x1000000);
                    } else {
                        lua_pushinteger(L, 0x10000 * a + 0x100 * b + c);
                    }
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        case 4:
            for (lua_Integer i = 1; i <= n; i++) {
                if ((p + 3) >= l) {
                    break;
                } else {
                    lua_Integer a = uchar(s[p++]);
                    lua_Integer b = uchar(s[p++]);
                    lua_Integer c = uchar(s[p++]);
                    lua_Integer d = uchar(s[p++]);
                    if (a >= 0x80) {
                        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d - 0x100000000);
                    } else {
                        lua_pushinteger(L, 0x1000000 * a + 0x10000 * b + 0x100 * c + d);
                    }
                    lua_rawseti(L, -2, i);
                }
            }
            break;
        default:
            break;
    }
    return 1;
}

/* from ff */

static int fiolib_readfixed2(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        int b = getc(f);
        if (b == EOF) {
            lua_pushnil(L);
        } else {
            int n = 0x100 * a + b; /* really an int because we shift */
            lua_pushnumber(L, (double) ((n>>8) + ((n&0xff)/256.0)));
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readfixed2(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 3) >= l) {
        lua_pushnil(L);
    } else {
        int a = uchar(s[p++]);
        int b = uchar(s[p]);
        int n = 0x100 * a + b; /* really an int because we shift */
        lua_pushnumber(L, (double) ((n>>8) + ((n&0xff)/256.0)));
    }
    return 1;
}

static int fiolib_readfixed4(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        int b = getc(f);
        int c = getc(f);
        int d = getc(f);
        if (d == EOF) {
            lua_pushnil(L);
        } else {
            int n = 0x1000000 * a + 0x10000 * b + 0x100 * c + d; /* really an int because we shift */
            lua_pushnumber(L, (double) ((n>>16) + ((n&0xffff)/65536.0)));
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readfixed4(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 3) >= l) {
        lua_pushnil(L);
    } else {
        int a = uchar(s[p++]);
        int b = uchar(s[p++]);
        int c = uchar(s[p++]);
        int d = uchar(s[p]);
        int n = 0x1000000 * a + 0x10000 * b + 0x100 * c + d; /* really an int because we shift */
        lua_pushnumber(L, (double) ((n>>16) + ((n&0xffff)/65536.0)));
    }
    return 1;
}

static int fiolib_read2dot14(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        int a = getc(f);
        int b = getc(f);
        if (b == EOF) {
            lua_pushnil(L);
        } else {
            int n = 0x100 * a + b; /* really an int because we shift */
            /* from ff */
            lua_pushnumber(L, (double) (((n<<16)>>(16+14)) + ((n&0x3fff)/16384.0)));
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_read2dot14(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if ((p + 1) >= l) {
        lua_pushnil(L);
    } else {
        int a = uchar(s[p++]);
        int b = uchar(s[p]);
        int n = 0x100 * a + b; /* really an int because we shift */
        lua_pushnumber(L, (double) (((n<<16)>>(16+14)) + ((n&0x3fff)/16384.0)));
    }
    return 1;
}

static int fiolib_getposition(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        long p = ftell(f);
        if (p < 0) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, p);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_setposition(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        long p = lmt_tolong(L, 2);
        p = fseek(f, p, SEEK_SET);
        if (p < 0) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, p);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_skipposition(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        long p = lmt_tolong(L, 2);
        p = fseek(f, ftell(f) + p, SEEK_SET);
        if (p < 0) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, p);
        }
        return 1;
    } else {
        return 0;
    }
}

static int fiolib_readbytetable(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        lua_createtable(L, (int) n, 0);
        for (lua_Integer i = 1; i <= n; i++) {
            lua_Integer a = getc(f);
            if (a == EOF) {
                break;
            } else {
                /*
                    lua_pushinteger(L, i);
                    lua_pushinteger(L, a);
                    lua_rawset(L, -3);
                */
                lua_pushinteger(L, a);
                lua_rawseti(L, -2, i);
            }
        }
        return 1;
    } else {
        return 0;
    }
}

static int siolib_readbytetable(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer n = lua_tointeger(L, 3);
    lua_Integer l = (lua_Integer) ls;
    if (p >= l) {
        lua_pushnil(L);
    } else {
        if (p + n >= l) {
            n = l - p ;
        }
        lua_createtable(L, (int) n, 0);
        for (lua_Integer i = 1; i <= n; i++) {
            lua_Integer a = uchar(s[p++]);
            lua_pushinteger(L, a);
            lua_rawseti(L, -2, i);
        }
    }
    return 1;
}

static int fiolib_readbytes(lua_State *L) {
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        for (lua_Integer i = 1; i <= n; i++) {
            lua_Integer a = getc(f);
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

static int siolib_readbytes(lua_State *L) {
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer n = lua_tointeger(L, 3);
    lua_Integer l = (lua_Integer) ls;
    if (p >= l) {
        return 0;
    } else {
        if (p + n >= l) {
            n = l - p ;
        }
        lua_createtable(L, (int) n, 0);
        for (lua_Integer i = 1; i <= n; i++) {
            lua_Integer a = uchar(s[p++]);
            lua_pushinteger(L, a);
        }
        return (int) n;
    }
}

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
                        ungetc((int) c, f);
                    }
                    goto GOOD;
                } else {
                    n++;
                    b[i++] = (char) c;
                }
            }
        }  while (c != EOF);
        goto BAD;
      GOOD:
        if (n > 0) {
            luaL_addsize(&buf, n);
            luaL_pushresult(&buf);
        } else {
            lua_pushnil(L);
        }
        lua_pushinteger(L, ftell(f));
        return 2;
    }
  BAD:
    lua_pushnil(L);
    return 1;
}


static int siolib_readcline(lua_State *L)
{
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if (p < l) {
        lua_Integer i = p;
        int n = 0;
        while  (p < l) {
            int c = uchar(s[p++]);
            if (c == '\n') {
                goto GOOD;
            } else if (c == '\r') {
                if (p < l) {
                    c = uchar(s[p++]);
                    if (c != EOF && c != '\n') {
                        --p;
                    }
                }
                goto GOOD;
            } else {
                n++;
            }
        }
        goto BAD;
      GOOD:
        if (n > 0) {
            lua_pushlstring(L, &s[i], n);
            lua_pushinteger(L, p);
            return 2;
        }
    }
  BAD:
    lua_pushnil(L);
    lua_pushinteger(L, p + 1);
    return 2;
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
                } else {
                    n++;
                    b[i++] = (char) c;
                }
            }
        }  while (c != EOF);
        goto BAD;
      GOOD:
        if (n > 0) {
            luaL_addsize(&buf, n);
            luaL_pushresult(&buf);
        } else {
            lua_pushliteral(L,"");
        }
        lua_pushinteger(L, ftell(f));
        return 2;
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

static int siolib_readcstring(lua_State *L)
{
    size_t ls = 0;
    const char *s = luaL_checklstring(L, 1, &ls);
    lua_Integer p = luaL_checkinteger(L, 2) - 1;
    lua_Integer l = (lua_Integer) ls;
    if (p < l) {
        lua_Integer i = p;
        int n = 0;
        while (p < l) {
            int c = uchar(s[p++]);
            if (c == '\0') {
                goto GOOD;
            } else {
                n++;
            }
        };
        goto BAD;
      GOOD:
        if (n > 0) {
            lua_pushlstring(L, &s[i], n);
        } else {
            lua_pushliteral(L,"");
        }
        lua_pushinteger(L, p + 1);
        return 2;
    }
  BAD:
    lua_pushnil(L);
    lua_pushinteger(L, p + 1);
    return 2;
}

/* will be completed */

static int fiolib_writecardinal1(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc(n & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal1(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[1] = { n & 0xFF };
    lua_pushlstring(L, buffer, 1);
    return 1;
}

static int fiolib_writecardinal2(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc((n >> 8) & 0xFF, f);
        putc( n       & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal2(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[2] = { (n >> 8) & 0xFF, n & 0xFF };
    lua_pushlstring(L, buffer, 2);
    return 1;
}

static int fiolib_writecardinal2_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc( n       & 0xFF, f);
        putc((n >> 8) & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal2_le(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[2] = { n & 0xFF, (n >> 8) & 0xFF };
    lua_pushlstring(L, buffer, 2);
    return 1;
}

static int fiolib_writecardinal3(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc((n >> 16) & 0xFF, f);
        putc((n >>  8) & 0xFF, f);
        putc( n        & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal3(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[3] = { (n >> 16) & 0xFF, (n >>  8) & 0xFF, n & 0xFF };
    lua_pushlstring(L, buffer, 3);
    return 1;
}


static int fiolib_writecardinal3_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc( n        & 0xFF, f);
        putc((n >>  8) & 0xFF, f);
        putc((n >> 16) & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal3_le(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[3] = { n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF };
    lua_pushlstring(L, buffer, 3);
    return 1;
}

static int fiolib_writecardinal4(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc((n >> 24) & 0xFF, f);
        putc((n >> 16) & 0xFF, f);
        putc((n >>  8) & 0xFF, f);
        putc( n        & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal4(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[4] = { (n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >>  8) & 0xFF, n & 0xFF };
    lua_pushlstring(L, buffer, 4);
    return 1;
}

static int fiolib_writecardinal4_le(lua_State *L)
{
    FILE *f = lmt_valid_file(L);
    if (f) {
        lua_Integer n = lua_tointeger(L, 2);
        putc( n        & 0xFF, f);
        putc((n >>  8) & 0xFF, f);
        putc((n >> 16) & 0xFF, f);
        putc((n >> 24) & 0xFF, f);
    }
    return 0;
}

static int siolib_tocardinal4_le(lua_State *L)
{
    lua_Integer n = lua_tointeger(L, 1);
    char buffer[4] = { n & 0xFF, (n >>  8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF };
    lua_pushlstring(L, buffer, 4);
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

    { "read2dot14",        fiolib_read2dot14        },

    { "setposition",       fiolib_setposition       },
    { "getposition",       fiolib_getposition       },
    { "skipposition",      fiolib_skipposition      },

    { "readbytes",         fiolib_readbytes         },
    { "readbytetable",     fiolib_readbytetable     },

    { "readcline",         fiolib_readcline         },
    { "readcstring",       fiolib_readcstring       },

    { "writecardinal1",    fiolib_writecardinal1    },
    { "writecardinal2",    fiolib_writecardinal2    },
    { "writecardinal3",    fiolib_writecardinal3    },
    { "writecardinal4",    fiolib_writecardinal4    },

    { "writecardinal1le",  fiolib_writecardinal1    },
    { "writecardinal2le",  fiolib_writecardinal2_le },
    { "writecardinal3le",  fiolib_writecardinal3_le },
    { "writecardinal4le",  fiolib_writecardinal4_le },

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

    { "readbytes",         siolib_readbytes         },
    { "readbytetable",     siolib_readbytetable     },

    { "readcline",         siolib_readcline         },
    { "readcstring",       siolib_readcstring       },

    { "tocardinal1",       siolib_tocardinal1       },
    { "tocardinal2",       siolib_tocardinal2       },
    { "tocardinal3",       siolib_tocardinal3       },
    { "tocardinal4",       siolib_tocardinal4       },

    { "tocardinal1le",     siolib_tocardinal1       },
    { "tocardinal2le",     siolib_tocardinal2_le    },
    { "tocardinal3le",     siolib_tocardinal3_le    },
    { "tocardinal4le",     siolib_tocardinal4_le    },

    { NULL,                NULL                     }
};

/*tex

    The sio helpers might be handy at some point. Speed-wise there is no gain over file access
    because with ssd and caching we basically operate in memory too. We keep them as complement to
    the file ones. I did consider using an userdata object for the position etc but some simple
    tests demonstrated that there is no real gain and the current ones permits to wrap up whatever
    interface one likes.

*/

int luaopen_fio(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, fiolib_function_list, 0);
    return 1;
}

int luaopen_sio(lua_State *L) {
    lua_newtable(L);
    luaL_setfuncs(L, siolib_function_list, 0);
    return 1;
}

/* We patch a function in the standard |io| library. */

/*tex

    The following code overloads the |io.open| function to deal with so called wide characters on
    windows.

*/

# if _WIN32

#   define tolstream(L) ((LStream *)luaL_checkudata(L, 1, LUA_FILEHANDLE))

    static int l_checkmode(const char *mode) {
        return (
            *mode != '\0'
         && strchr("rwa", *(mode++))
         && (*mode != '+' || ((void)(++mode), 1))
         && (strspn(mode, "b") == strlen(mode))
        );
    }

    typedef luaL_Stream LStream;

    static LStream *newprefile(lua_State *L) {
        LStream *p = (LStream *)lua_newuserdatauv(L, sizeof(LStream), 0);
        p->closef = NULL;
        luaL_setmetatable(L, LUA_FILEHANDLE);
        return p;
    }

    static int io_fclose(lua_State *L) {
        LStream *p = tolstream(L);
        int res = fclose(p->f);
        return luaL_fileresult(L, (res == 0), NULL);
    }

    static LStream *newfile(lua_State *L) {
        /*tex Watch out: lua 5.4 has different closers. */
        LStream *p = newprefile(L);
        p->f = NULL;
        p->closef = &io_fclose;
        return p;
    }

    static int io_open(lua_State *L)
    {
        const char *filename = luaL_checkstring(L, 1);
        const char *mode = luaL_optstring(L, 2, "r");
        LStream *p = newfile(L);
        const char *md = mode;  /* to traverse/check mode */
        luaL_argcheck(L, l_checkmode(md), 2, "invalid mode");
        p->f = aux_utf8_fopen(filename, mode);
        return (p->f) ? 1 : luaL_fileresult(L, 0, filename);
    }

    static int io_pclose(lua_State *L) {
        LStream *p = tolstream(L);
        return luaL_execresult(L, _pclose(p->f));
    }

    static int io_popen(lua_State *L)
    {
        const char *filename = luaL_checkstring(L, 1);
        const char *mode = luaL_optstring(L, 2, "r");
        LStream *p = newprefile(L);
        p->f = aux_utf8_popen(filename, mode);
        p->closef = &io_pclose;
        return (p->f) ? 1 : luaL_fileresult(L, 0, filename);
    }

    int luaextend_io(lua_State *L)
    {
        lua_getglobal(L, "io");
        lua_pushcfunction(L, io_open);  lua_setfield(L, -2, "open");
        lua_pushcfunction(L, io_popen); lua_setfield(L, -2, "popen");
        lua_pop(L, 1);
         /*tex
            Larger doesn't work and limits to 512 but then no amount is okay as there's always more
            to demand.
        */
        _setmaxstdio(2048);
        return 1;
    }

# else

    int luaextend_io(lua_State *L)
    {
        (void) L;
        return 1;
    }

# endif
