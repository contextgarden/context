/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Some png helpers, I could have introduced a userdata for blobs at some point but it's not that
    useful as string sare also sequences of bytes and lua handles those well. These are interfaces
    can change any time we like without notice till we like what we have.

*/

/* t xsize ysize bpp (includes mask) */

static int pnglib_applyfilter(lua_State *L)
{
    size_t size;
    const char *s = luaL_checklstring(L, 1, &size);
    int xsize     = lmt_tointeger(L, 2);
    int ysize     = lmt_tointeger(L, 3);
    int slice     = lmt_tointeger(L, 4);
    int len       = xsize * slice + 1; /* filter byte */
    int n         = 0;
    int m         = len - 1;
    unsigned char *t;
    if (ysize * len != (int) size) {
        tex_formatted_warning("png filter", "sizes don't match: %i expected, %i provided", ysize *len, size);
        return 0;
    }
    t = lmt_memory_malloc(size);
    if (! t) {
        tex_normal_warning("png filter", "not enough memory");
        return 0;
    }
    memcpy(t, s, size);
    for (int i = 0; i < ysize; i++) {
        switch (t[n]) {
            case 0 :
                break;
            case 1 :
                for (int j = n + slice + 1; j <= n + m; j++) {
                    t[j] = (unsigned char) (t[j] + t[j-slice]);
                }
                break;
            case 2 :
                if (i > 0) {
                    for (int j = n + 1; j <= n + m; j++) {
                        t[j] = (unsigned char) (t[j] + t[j-len]);
                    }
                }
                break;
            case 3 :
                if (i > 0) {
                    for (int j = n + 1; j <= n + slice; j++) {
                        t[j] = (unsigned char) (t[j] + t[j-len]/2);
                    }
                    for (int j = n + slice + 1; j <= n + m; j++) {
                        t[j] = (unsigned char) (t[j] + (t[j-slice] + t[j-len])/2);
                    }
                } else {
                    for (int j = n + slice + 1; j <= n + m; j++) {
                        t[j] = (unsigned char) (t[j] + t[j-slice]/2);
                    }
                }
                break;
            case 4 :
                if (i > 0) {
                    for (int j = n + 1; j <= n + slice; j++) {
                        int p = j - len;
                        t[j] = (unsigned char) (t[j] + t[p]);
                    }
                    for (int j = n + slice + 1; j <= n + m; j++) {
                        int p = j - len;
                        unsigned char a = t[j-slice];
                        unsigned char b = t[p];
                        unsigned char c = t[p-slice];
                        int pa = b - c;
                        int pb = a - c;
                        int pc = pa + pb;
                        if (pa < 0) { pa = - pa; }
                        if (pb < 0) { pb = - pb; }
                        if (pc < 0) { pc = - pc; }
                        t[j] = (unsigned char) (t[j] + ((pa <= pb && pa <= pc) ? a : ((pb <= pc) ? b : c)));
                    }
                } else {
                    /* What to do here? */
                    /*
                    for (int j = n + slice + 1; j <= n + m; j++) {
                        int p = j - len;
                        unsigned char a = t[j-slice];
                        unsigned char b = t[p];
                        unsigned char c = t[p-slice];
                        int pa = b - c;
                        int pb = a - c;
                        int pc = pa + pb;
                        if (pa < 0) { pa = - pa; }
                        if (pb < 0) { pb = - pb; }
                        if (pc < 0) { pc = - pc; }
                        t[j] = (unsigned char) (t[j] + ((pa <= pb && pa <= pc) ? a : ((pb <= pc) ? b : c)));
                    }
                    */
                }
                break;
            default:
                break;
        }
        n = n + len;
    }
    /* wipe out filter byte */
    {
        int j = 0; /* source */
        int m = 0; /* target */
        for (int i = 0; i < ysize; i++) {
            // (void) memcpy(&t[m], &t[j+1], len-1); /* target source size */
            (void) memmove(&t[m], &t[j+1], (size_t)len - 1); /* target source size */
            j += len;
            m += len - 1;
        }
        lua_pushlstring(L, (char *) t, size-ysize);
        /*
        int j = 0;
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        for (int i = 0; i < ysize; i++) {
            luaL_addlstring(&b, (const char *)&t[j+1], len-1);
            j += len;
        }
        luaL_pushresult(&b);
        */
    }
    lmt_memory_free(t);
    return 1;
}

/* t xsize ysize bpp (includes mask) bytes */

static int pnglib_splitmask(lua_State *L)
{
    size_t size;
    const char *t  = luaL_checklstring(L, 1, &size);
    int xsize      = lmt_tointeger(L, 2);
    int ysize      = lmt_tointeger(L, 3);
    int bpp        = lmt_tointeger(L, 4); /* 1 or 3 */
    int bytes      = lmt_tointeger(L, 5); /* 1 or 2 */
    int slice      = (bpp + 1) * bytes;
    int len        = xsize * slice;
    int blen       = bpp * bytes;
    int mlen       = bytes;
    int nt         = 0;
    int nb         = 0;
    int nm         = 0;
    int bsize      = ysize * xsize * blen;
    int msize      = ysize * xsize * mlen;
    char *b, *m;
    /* we assume that the filter byte is gone */
    if (ysize * len != (int) size) {
        tex_formatted_warning("png split", "sizes don't match: %i expected, %i provided", ysize * len, size);
        return 0;
    }
    b = lmt_memory_malloc(bsize);
    m = lmt_memory_malloc(msize);
    if (! (b && m)) {
        tex_normal_warning("png split mask", "not enough memory");
        return 0;
    }
    /* a bit optimized */
    switch (blen) {
        case 1:
            /* 8 bit gray or indexed graphics */
            for (int i = 0; i < ysize * xsize; i++) {
                b[nb++] = t[nt++];
                m[nm++] = t[nt++];
            }
            break;
        case 3:
            /* 8 bit rgb graphics */
            for (int i = 0; i < ysize * xsize; i++) {
                /*
                b[nb++] = t[nt++];
                b[nb++] = t[nt++];
                b[nb++] = t[nt++];
                */
                memcpy(&b[nb], &t[nt], 3);
                nt += 3;
                nb += 3;
                m[nm++] = t[nt++];
            }
            break;
        default:
            /* everything else */
            for (int i = 0; i < ysize * xsize; i++) {
                memcpy (&b[nb], &t[nt], blen);
                nt += blen;
                nb += blen;
                memcpy (&m[nm], &t[nt], mlen);
                nt += mlen;
                nm += mlen;
            }
            break;
    }
    lua_pushlstring(L, b, bsize);
    lmt_memory_free(b);
    lua_pushlstring(L, m, msize);
    lmt_memory_free(m);
    return 2;
}

/* output input xsize ysize slice pass filter */

static int pnglib_interlace(lua_State *L)
{
    int xstarts[] = { 0, 4, 0, 2, 0, 1, 0 };
    int ystarts[] = { 0, 0, 4, 0, 2, 0, 1 };
    int xsteps[]  = { 8, 8, 4, 4, 2, 2, 1 };
    int ysteps[]  = { 8, 8, 8, 4, 4, 2, 2 };
    size_t isize = 0;
    size_t psize = 0;
    const char *inp;
    const char *pre;
    char *out;
    int xsize, ysize, xstep, ystep, xstart, ystart, slice, pass, nx, ny;
    int target, start, step, size;
    /* dimensions */
    xsize  = lmt_tointeger(L, 1);
    ysize  = lmt_tointeger(L, 2);
    slice  = lmt_tointeger(L, 3);
    pass   = lmt_tointeger(L, 4);
    if (pass < 1 || pass > 7) {
        tex_formatted_warning("png interlace", "bass pass: %i (1..7)", pass);
        return 0;
    }
    pass   = pass - 1;
    /* */
    nx     = (xsize + xsteps[pass] - xstarts[pass] - 1) / xsteps[pass];
    ny     = (ysize + ysteps[pass] - ystarts[pass] - 1) / ysteps[pass];
    /* */
    xstart = xstarts[pass];
    xstep  = xsteps[pass];
    ystart = ystarts[pass];
    ystep  = ysteps[pass];
    /* */
    xstep  = xstep * slice;
    xstart = xstart * slice;
    xsize  = xsize * slice;
    target = ystart * xsize + xstart;
    ystep  = ystep * xsize;
    /* */
    step   = nx * xstep;
    size   = ysize * xsize;
    start  = 0;
    /* */
    inp    = luaL_checklstring(L, 5, &isize);
    pre    = NULL;
    out    = NULL;
    if (pass > 0) {
        pre = luaL_checklstring(L, 6, &psize);
        if ((int) psize < size) {
            tex_formatted_warning("png interlace", "output sizes don't match: %i expected, %i provided", psize, size);
            return 0;
        }
    }
    /* todo: some more checking */
    out = lmt_memory_malloc(size);
    if (out) {
        if (pass == 0) {
            memset(out, 0, size);
        }
        else {
            memcpy(out, pre, psize);
        }
    } else {
        tex_normal_warning("png interlace", "not enough memory");
        return 0;
    }
    switch (slice) {
        case 1:
            for (int j = 0; j < ny; j++) {
                int t = target + j * ystep;
                for (int i = t; i < t + step; i += xstep) {
                    out[i] = inp[start];
                    start = start + slice;
                }
            }
            break;
        case 2:
            for (int j = 0; j < ny; j++) {
                int t = target + j * ystep;
                for (int i = t; i < t + step; i += xstep) {
                    out[i]   = inp[start];
                    out[i+1] = inp[start+1];
                    start = start + slice;
                }
            }
            break;
        case 3:
            for (int j = 0; j < ny; j++) {
                int t = target + j * ystep;
                for (int i = t; i < t + step;i += xstep) {
                    out[i]   = inp[start];
                    out[i+1] = inp[start+1];
                    out[i+2] = inp[start+2];
                    start = start + slice;
                }
            }
            break;
        default:
            for (int j = 0; j < ny; j++) {
                int t = target + j * ystep;
                for (int i = t; i < t + step; i += xstep) {
                    memcpy(&out[i], &inp[start], slice);
                    start = start + slice;
                }
            }
            break;
    }
    lua_pushlstring(L, out, size);
    lmt_memory_free(out);
    return 1;
}

/* content xsize ysize parts run factor */

# define extract1(a,b) ((a >> b) & 0x01)
# define extract2(a,b) ((a >> b) & 0x03)
# define extract4(a,b) ((a >> b) & 0x0F)

static int pnglib_expand(lua_State *L)
{
    size_t tsize;
    const char *t = luaL_checklstring(L, 1, &tsize);
    char *o       = NULL;
    int n         = 0;
    int k         = 0;
    int xsize     = lmt_tointeger(L, 2);
    int ysize     = lmt_tointeger(L, 3);
    int parts     = lmt_tointeger(L, 4);
    int xline     = lmt_tointeger(L, 5);
    int factor    = lua_toboolean(L, 6);
    int size      = ysize * xsize;
    int extra     = ysize * xsize + 16; /* probably a few bytes is enough */
    if (xline*ysize > (int) tsize) {
        tex_formatted_warning("png expand","expand sizes don't match: %i expected, %i provided",size,parts*tsize);
        return 0;
    }
    o = lmt_memory_malloc(extra);
    if (! o) {
        tex_normal_warning ("png expand", "not enough memory");
        return 0;
    }
    /* we could use on branch and factor variables ,, saves code, costs cycles */
    if (factor) {
        switch (parts) {
            case 4:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        o[k++] = (unsigned char) extract4 (v, 4) * 0x11;
                        o[k++] = (unsigned char) extract4 (v, 0) * 0x11;
                    }
                    n = n + xline;
                }
                break;
            case 2:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        for (int b = 6; b >= 0; b -= 2) {
                            o[k++] = (unsigned char) extract2 (v, b) * 0x55;
                        }
                    }
                    n = n + xline;
                }
                break;
            default:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        for (int b = 7; b >= 0; b--) {
                            o[k++] = (unsigned char) extract1 (v, b) * 0xFF;
                        }
                    }
                    n = n + xline;
                }
                break;
        }
    } else {
        switch (parts) {
            case 4:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        o[k++] = (unsigned char) extract4 (v, 4);
                        o[k++] = (unsigned char) extract4 (v, 0);
                    }
                    n = n + xline;
                }
                break;
            case 2:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        for (int b = 6; b >= 0; b -= 2) {
                            o[k++] = (unsigned char) extract2 (v, b);
                        }
                    }
                    n = n + xline;
                }
                break;
            default:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        for (int b = 7; b >= 0; b--) {
                            o[k++] = (unsigned char) extract1 (v, b);
                        }
                    }
                    n = n + xline;
                }
                break;
        }
    }
    lua_pushlstring(L, o, size);
    lmt_memory_free(o);
    return 1;
}

/*tex
    This is just a quick and dirty experiment. We need to satisfy pdf standards
    and simple graphics can be converted this way. Maybe add some more control
    over calculating |k|.
*/

static int pnglib_tocmyk(lua_State *L)
{
    size_t tsize;
    const char *t = luaL_checklstring(L, 1, &tsize);
    int depth = lmt_optinteger(L, 2, 0);
    if ((tsize > 0) && (depth == 8 || depth == 16)) {
        size_t osize = 0;
        char *o = NULL;
        if (depth == 8) {
            o = lmt_memory_malloc(4 * (tfloor(tsize/3) + 1)); /*tex Plus some slack. */
        } else {
            o = lmt_memory_malloc(8 * (tfloor(tsize/6) + 1)); /*tex Plus some slack. */
        }
        if (! o) {
            tex_normal_warning ("png tocmyk", "not enough memory");
            return 0;
        } else if (depth == 8) {
            /*
            for (size_t i = 0; i < tsize; i += 3) {
                o[osize++] = (const char) (0xFF - t[i]);
                o[osize++] = (const char) (0xFF - t[i + 1]);
                o[osize++] = (const char) (0xFF - t[i + 2]);
                o[osize++] = '\0';
            }
            */
            for (size_t i = 0; i < tsize; ) {
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = '\0';
            }
        } else {
            /*tex This needs checking! */
            /*
            for (size_t i = 0; i < tsize; i += 6) {
                o[osize++] = (const char) (0xFF - t[i]);
                o[osize++] = (const char) (0xFF - t[i + 1]);
                o[osize++] = (const char) (0xFF - t[i + 2]);
                o[osize++] = (const char) (0xFF - t[i + 3]);
                o[osize++] = (const char) (0xFF - t[i + 4]);
                o[osize++] = (const char) (0xFF - t[i + 5]);
                o[osize++] = '\0';
                o[osize++] = '\0';
            }
            */
            for (size_t i = 0; i < tsize; ) {
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = (const char) (0xFF - t[i++]);
                o[osize++] = '\0';
                o[osize++] = '\0';
            }
        }
        lua_pushlstring(L, o, osize-1);
        lmt_memory_free(o);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex Make a mask for a pallete. */

static int pnglib_tomask(lua_State *L) /* for palette */
{
    size_t tsize, ssize;
    const char *t  = luaL_checklstring(L, 1, &tsize);
    const char *s  = luaL_checklstring(L, 2, &ssize);
    size_t xsize   = lmt_tosizet(L, 3);
    size_t ysize   = lmt_tosizet(L, 4);
    int colordepth = lmt_tointeger(L, 5);
    size_t osize   = xsize * ysize;
    if (osize  == tsize) {
        char *o    = lmt_memory_malloc(osize);
        char *v    = lmt_memory_calloc(256,1);
        size_t len = xsize * colordepth / 8; // ceil
        size_t k   = 0;
        memset(v, 0xFF, 256);
        memcpy(v, s, ssize > 256 ? 256 : ssize);
        for (size_t i = 0; i < ysize; i++) {
            size_t f = i * len;
            size_t l = f + len;
            switch (colordepth) {
                case 8:
                    for (size_t j = f; j < l; j++) {
                        int c = t[j];
                        o[k++] =  (unsigned char) v[c];
                    }
                    break;
                case 4:
                    for (size_t j = f; j < l; j++) {
                        int c = t[j];
                        o[k++] = (unsigned char) v[(c >> 4) & 0x0F];
                        o[k++] = (unsigned char) v[(c >> 0) & 0x0F];
                    }
                    break;
                case 2:
                    for (size_t j = f; j < l; j++) {
                        int c = t[j];
                        o[k++] = (unsigned char) v[(c >> 6) & 0x03];
                        o[k++] = (unsigned char) v[(c >> 4) & 0x03];
                        o[k++] = (unsigned char) v[(c >> 2) & 0x03];
                        o[k++] = (unsigned char) v[(c >> 0) & 0x03];
                    }
                    break;
                default:
                    for (size_t j = f; j < l; j++) {
                        int c = t[j];
                        o[k++] = (unsigned char) v[(c >> 7) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 6) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 5) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 4) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 3) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 2) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 1) & 0x01];
                        o[k++] = (unsigned char) v[(c >> 0) & 0x01];
                    }
                    break;
            }
        }
        lua_pushlstring(L, o, osize);
        lmt_memory_free(o);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static const struct luaL_Reg pngdecodelib_function_list[] = {
    { "applyfilter", pnglib_applyfilter },
    { "splitmask",   pnglib_splitmask   },
    { "interlace",   pnglib_interlace   },
    { "expand",      pnglib_expand      },
    { "tocmyk",      pnglib_tocmyk      },
    { "tomask",      pnglib_tomask      },
    { NULL,          NULL               },
};

int luaopen_pngdecode(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, pngdecodelib_function_list, 0);
    return 1;
}

/*tex This is a placeholder! */

static const struct luaL_Reg pdfdecodelib_function_list[] = {
    { NULL, NULL }
};

int luaopen_pdfdecode(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, pdfdecodelib_function_list, 0);
    return 1;
}
