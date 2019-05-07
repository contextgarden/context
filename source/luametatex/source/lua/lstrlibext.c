/*
    See license.txt in the root of this project.
*/

/*tex

    The relative ordering of the header files is important here, otherwise some
    of the defines that are needed for lua_sdump come out wrong.

*/

# include "luatex-common.h"

static int bytepairs_aux(lua_State *L) {
    size_t ls;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    int ind       = lua_tointeger(L, lua_upvalueindex(2));
    if (ind < (int)ls) {
        unsigned char i;
        if (ind+1<(int)ls) {
            lua_pushinteger(L, (ind+2));  /* iterator */
        } else {
            lua_pushinteger(L, (ind+1));  /* iterator */
        }
        lua_replace(L, lua_upvalueindex(2));
        i = (unsigned char)*(s+ind);
        lua_pushinteger(L, i);            /* byte one */
        if (ind + 1 < (int)ls) {
            i = (unsigned char)*(s+ind+1);
            lua_pushinteger(L, i);        /* byte two */
        } else {
            lua_pushnil(L);               /* odd string length */
        }
        return 2;
    }
    return 0;                             /* string ended */
}

static int str_bytepairs(lua_State *L) {
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, bytepairs_aux, 2);
    return 1;
}

static int bytes_aux(lua_State *L) {
    size_t ls;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    int ind = lua_tointeger(L, lua_upvalueindex(2));
    if (ind<(int)ls) {
        unsigned char i;
        lua_pushinteger(L, (ind+1));  /* iterator */
        lua_replace(L, lua_upvalueindex(2));
        i = (unsigned char)*(s+ind);
        lua_pushinteger(L, i);        /* byte */
        return 1;
    }
    return 0;                         /* string ended */
}

static int str_bytes(lua_State *L) {
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, bytes_aux, 2);
    return 1;
}

static int utf_failed(lua_State *L, int new_ind) {
    static char fffd [3] = { 0xEF, 0xBF, 0xBD };
    lua_pushinteger(L, new_ind);  /* iterator */
    lua_replace(L, lua_upvalueindex(2));
    lua_pushlstring(L, fffd, 3);
    return 1;
}

static int utfcharacters_aux(lua_State *L) {
    static const unsigned char mask[4] = { 0x80, 0xE0, 0xF0, 0xF8 };
    static const unsigned char mequ[4] = { 0x00, 0xC0, 0xE0, 0xF0 };
    size_t ls;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    int ind = lua_tointeger(L, lua_upvalueindex(2));
    if (ind >= (int)ls) {
        return 0; /* end of string */
    } else {
        unsigned char c = (unsigned) s[ind];
        int j;
        for (j=0;j<4;j++) {
            if ((c&mask[j])==mequ[j]) {
                int k;
                if (ind+1+j>(int)ls)
                    return utf_failed(L,ls); /* will not fit */
                for (k=1; k<=j; k++) {
                    c = (unsigned) s[ind+k];
                    if ((c&0xC0)!=0x80)
                        return utf_failed(L,ind+k); /* bad follow */
                }
                lua_pushinteger(L, ind+1+j);  /* iterator */
                lua_replace(L, lua_upvalueindex(2));
                lua_pushlstring(L, s+ind, 1+j);
                return 1;
            }
        }
        return utf_failed(L,ind+1); /* we found a follow byte! */
    }
}

static int str_utfcharacters(lua_State *L) {
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, utfcharacters_aux, 2);
    return 1;
}

static int utfvalues_aux(lua_State *L) {
    size_t ls;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    int ind = lua_tointeger(L, lua_upvalueindex(2));
    if (ind < (int)ls) {
        int numbytes = 1;
        unsigned char i = *(s+ind);
        unsigned int  v = 0xFFFD;
        if (i<0x80) {
            v = i;
        } else if (i>=0xF0) {
            if ((ind+3)<(int)ls && ((unsigned)*(s+ind+1))>=0x80 && ((unsigned)*(s+ind+2))>=0x80 && ((unsigned)*(s+ind+3))>=0x80) {
                unsigned char j = ((unsigned)*(s+ind+1))-128;
                unsigned char k = ((unsigned)*(s+ind+2))-128;
                unsigned char l = ((unsigned)*(s+ind+3))-128;
                v = (((((i-0xF0)*64) + j)*64) + k)*64 + l;
                numbytes  = 4;
            }
        } else if (i>=0xE0) {
            if ((ind+2)<(int)ls && ((unsigned)*(s+ind+1))>=0x80 && ((unsigned)*(s+ind+2))>=0x80) {
                unsigned char j = ((unsigned)*(s+ind+1))-128;
                unsigned char k = ((unsigned)*(s+ind+2))-128;
                v = (((i-0xE0)*64) + j)*64 + k;
                numbytes  = 3;
            }
        } else if (i>=0xC0) {
            if ((ind+1)<(int)ls && ((unsigned)*(s+ind+1))>=0x80) {
                unsigned char j = ((unsigned)*(s+ind+1))-128;
                v = ((i-0xC0)*64) + j;
                numbytes  = 2;
            }
        }
        lua_pushinteger(L, (ind+numbytes));  /* iterator */
        lua_replace(L, lua_upvalueindex(2));
        lua_pushinteger(L, v);
        return 1;
    }
    return 0;  /* string ended */
}

static int str_utfvalues (lua_State *L) {
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, utfvalues_aux, 2);
    return 1;
}

static int characterpairs_aux(lua_State *L) {
    size_t ls;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    int ind       = lua_tointeger(L, lua_upvalueindex(2));
    if (ind<(int)ls) {
        char b[2];
        if (ind+1<(int)ls) {
            lua_pushinteger(L, (ind+2));  /* iterator */
        } else {
            lua_pushinteger(L, (ind+1));  /* iterator */
        }
        lua_replace(L, lua_upvalueindex(2));
        b[0] = *(s+ind);
        b[1] = 0;
        lua_pushlstring(L, b, 1);
        if (ind+1<(int)ls) {
            b[0] = *(s+ind+1);
            lua_pushlstring(L, b, 1);
        } else {
            lua_pushlstring(L, b+1, 0);
        }
        return 2;
    }
    return 0;  /* string ended */
}

static int str_characterpairs(lua_State *L) {
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, characterpairs_aux, 2);
    return 1;
}

static int characters_aux(lua_State *L) {
    size_t ls;
    const char *s = lua_tolstring(L, lua_upvalueindex(1), &ls);
    int ind  = lua_tointeger(L, lua_upvalueindex(2));
    if (ind<(int)ls) {
        char b[2];
        lua_pushinteger(L, (ind+1));  /* iterator */
        lua_replace(L, lua_upvalueindex(2));
        b[0] = *(s+ind);
        b[1] = 0;
        lua_pushlstring(L, b, 1);
        return 1;
    }
    return 0;  /* string ended */
}

static int str_characters(lua_State *L) {
    luaL_checkstring(L, 1);
    lua_settop(L, 1);
    lua_pushinteger(L, 0);
    lua_pushcclosure(L, characters_aux, 2);
    return 1;
}

static int str_bytetable(lua_State *L) {
    size_t l;
    size_t i;
    const char *s = luaL_checklstring(L, 1, &l);
    lua_createtable(L,l,0);
    for (i=0;i<l;i++) {
        lua_pushinteger(L,(unsigned char)*(s+i));
        lua_rawseti(L,-2,i+1);
    }
    return 1;
}

/*tex

    We provide a few helpers that we derived from the lua utf8 module
    and slunicode. That way we're sort of covering a decent mix.

*/

#define MAXUNICODE	0x10FFFF

/*tex

    This is a combination of slunicode and utf8 converters but without mode
    and a bit faster on the average than the utf8 one.

*/

static int str_character(lua_State *L) {
    int n = lua_gettop(L);
    int i;
    luaL_Buffer b;
    luaL_buffinit(L,&b);
 /* luaL_buffinitsize(L, &b, n*4); */
    for (i = 1; i <= n; i++) {
        unsigned c = (unsigned) lua_tointeger(L, i);
        if (c <= MAXUNICODE) {
            if (0x80 > c) {
                luaL_addchar(&b, c);
            } else {
                if (0x800 > c)
                    luaL_addchar(&b, 0xC0|(c>>6));
                else {
                    if (0x10000 > c)
                        luaL_addchar(&b, 0xE0|(c>>12));
                    else {
                        luaL_addchar(&b, 0xF0|(c>>18));
                        luaL_addchar(&b, 0x80|(0x3F&(c>>12)));
                    }
                    luaL_addchar(&b, 0x80|(0x3F&(c>>6)));
                }
                luaL_addchar(&b, 0x80|(0x3F&c));
            }
        }
    }
    luaL_pushresult(&b);
    return 1;
}

/*tex

    The \UTF8 codepoint function takes two arguments, being positions in the
    string, while slunicode byte takes two arguments representing the number of
    utf characters. The variant below always returns all codepoints.

*/

static int str_utfvalue(lua_State *L) {
    size_t ls;
    int ind = 0;
    int num = 0;
    const char *s = lua_tolstring(L, 1, &ls);
    while (ind<(int)ls) {
        unsigned char i = (unsigned)*(s+ind);
        if (i<0x80) {
            lua_pushinteger(L, i);
            num += 1;
            ind += 1;
        } else if (i>=0xF0) {
            if ((ind+3)<(int)ls && ((unsigned)*(s+ind+1))>=0x80 && ((unsigned)*(s+ind+2))>=0x80 && ((unsigned)*(s+ind+3))>=0x80) {
                unsigned char j = ((unsigned)*(s+ind+1))-128;
                unsigned char k = ((unsigned)*(s+ind+2))-128;
                unsigned char l = ((unsigned)*(s+ind+3))-128;
                lua_pushinteger(L, (((((i-0xF0)*64) + j)*64) + k)*64 + l);
                num += 1;
            }
            ind += 4;
        } else if (i>=0xE0) {
            if ((ind+2)<(int)ls && ((unsigned)*(s+ind+1))>=0x80 && ((unsigned)*(s+ind+2))>=0x80) {
                unsigned char j = ((unsigned)*(s+ind+1))-128;
                unsigned char k = ((unsigned)*(s+ind+2))-128;
                lua_pushinteger(L, (((i-0xE0)*64) + j)*64 + k);
                num += 1;
            }
            ind += 3;
        } else if (i>=0xC0) {
            if ((ind+1)<(int)ls && ((unsigned)*(s+ind+1))>=0x80) {
                unsigned char j = ((unsigned)*(s+ind+1))-128;
                lua_pushinteger(L, ((i-0xC0)*64) + j);
                num += 1;
            }
            ind += 2;
        } else {
            ind += 1;
        }
    }
    return num;
}

/*tex This is a simplified version of utf8.len but without range. */

static int str_utflength(lua_State *L) {
    size_t ls;
    int ind = 0;
    int num = 0;
    const char *s = lua_tolstring(L, 1, &ls);
    while (ind<(int)ls) {
        unsigned char i = (unsigned)*(s+ind);
        if (i<0x80) {
            ind += 1;
        } else if (i>=0xF0) {
            ind += 4;
        } else if (i>=0xE0) {
            ind += 3;
        } else if (i>=0xC0) {
            ind += 2;
        } else {
            /*tex bad news, stupid recovery */
            ind += 1;
        }
        num += 1;
    }
    lua_pushinteger(L, num);
    return 1;
}

/* test */

/*
static int str_format_f9(lua_State *L) {
    char s[128];
    int i;
    if (lua_isnumber(L,1)) {
        double n = lua_tonumber(L,1);
        if (fmod(n,1) == 0) {
            snprintf(s, 128, "%i", (int) n);
        } else {
            if (lua_isstring(L,2)) {
                const char *f = lua_tostring(L, 2);
                snprintf(s, 128, f, n);
            } else {
                snprintf(s, 128, "%0.9f", n);
            }
            i = strlen(s) - 1;
            while (i>1) {
                if (s[i-1] == '.') {
                    break;
                } else if (s[i] == '0') {
                    s[i] = '\0';
                } else {
                    break;
                }
                i--;
            }
        }
    } else {
        return 0;
    }
    lua_pushstring(L,s);
    return 1;
}
*/

/*tex end of convenience inclusion */

static const luaL_Reg strlibext[] = {
    { "utfvalues",      str_utfvalues },
    { "utfcharacters",  str_utfcharacters },
    { "characters",     str_characters },
    { "characterpairs", str_characterpairs },
    { "bytes",          str_bytes },
    { "bytepairs",      str_bytepairs },
    { "bytetable",      str_bytetable },
 /* { "explode",        str_split }, */ /* moved to a lua function that also handles utf8 */
    { "utfcharacter",   str_character },
    { "utfvalue",       str_utfvalue },
    { "utflength",      str_utflength },
 /* { "f9",             str_format_f9 }, */
    { NULL,             NULL }
};

int luaextend_string(lua_State * L)
{
    const luaL_Reg *lib;
    lua_getglobal(L, "string");
    for (lib=strlibext;lib->name;lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L,1);
    return 1;
}
