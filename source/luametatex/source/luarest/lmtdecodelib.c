/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Some png helpers, I could have introduced a userdata for blobs at some point but it's not that
    useful as strings are also sequences of bytes and lua handles those well. These are interfaces
    can change any time we like without notice till we like what we have.

    There is some redundancy due to the fact that we also have a bytemap library so at some point
    we might combine some. It also deopends on combining some at the \CONTEXT\ end.

*/

/*
    This can be done in a few more places and already gains quite a bit on a dozen extreme ones;
    the smaller gray easier on the pdf zipping etc (so there we win back):

    normal     : 8.9 (8.6 with conversion to gray)
    experiment : 8.2 (7.9 with conversion to gray)
*/

static int experiment = 0;

static int pnglib_setexperiment(lua_State *L)
{
    experiment = lmt_optinteger(L, 1, 0);
    return 0;
}

static void * pnglib_memory_malloc(size_t size)
{
    if (experiment & 1) {
        return lmt_memory_malloc(size + 1);
    } else {
        return lmt_memory_malloc(size);
    }
}

static void pnglib_pushlstring(lua_State *L, char *s, size_t l)
{
    if (experiment & 1) {
        s[l] = '\0';
        lua_pushexternalstring(L, s, l, lua_getallocf(L, NULL), NULL);
    } else {
        lua_pushlstring(L, s, l);
        lmt_memory_free(s);
    }
}

/* t xsize ysize bpp (includes mask) */

# if 1

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
    t = pnglib_memory_malloc(size);
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
            (void) memmove(&t[m], &t[j+1], (size_t) len - 1); /* target source size */
            j += len;
            m += len - 1;
        }
        pnglib_pushlstring(L, (char *) t, size - ysize);
    }
    return 1;
}

# else

/*tex
    There is no real gain here but it's a bit less messy and needs double or even tripple
    checking with the above which I'll do when I'm really bored.
*/

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
    t = pnglib_memory_malloc(size);
    if (! t) {
        tex_normal_warning("png filter", "not enough memory");
        return 0;
    }
    memcpy(t, s, size);
    for (int i = 0; i < ysize; i++) {
        int k = n + 1;
        switch (t[n]) {
            case 0 :
                break;
            case 1 :
                for (int j = k + slice; j <= n + m; j++) {
                    t[j] = (unsigned char) (t[j] + t[k++]);
                }
                break;
            case 2 :
                if (i > 0) {
                    k -= len;
                    for (int j = k; j <= n + m; j++) {
                        t[j] = (unsigned char) (t[j] + t[k++]);
                    }
                }
                break;
            case 3 :
                if (i > 0) {
                    int l = k - len;
                    for (int j = k; j <= n + slice; j++) {
                        t[j] = (unsigned char) (t[j] + t[l++]/2);
                    }
                    for (int j = k + slice; j <= n + m; j++) {
                        t[j] = (unsigned char) (t[j] + (t[k++] + t[l++])/2);
                    }
                } else {
                    for (int j = k + slice; j <= n + m; j++) {
                        t[j] = (unsigned char) (t[j] + t[k++]/2);
                    }
                }
                break;
            case 4 :
                if (i > 0) {
                    int l = k - len;
                    int o; // o = n + slice - l + 1;
                    for (int j = k; j <= n + slice; j++) {
                        t[j] = (unsigned char) (t[j] + t[l++]);
                    }
                    o = l - slice;
                    for (int j = k + slice; j <= n + m; j++) {
                        unsigned char a = t[k++];
                        unsigned char b = t[l++];
                        unsigned char c = t[o++];
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
        pnglib_pushlstring(L, (char *) t, size - ysize);
    }
    return 1;
}

# endif

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
    b = pnglib_memory_malloc(bsize);
    m = pnglib_memory_malloc(msize);
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
    pnglib_pushlstring(L, b, bsize);
    pnglib_pushlstring(L, m, msize);
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
    out = pnglib_memory_malloc(size);
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
                for (int i = t; i < t + step; i += xstep) {
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
    pnglib_pushlstring(L, out, size);
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
    o = pnglib_memory_malloc(extra);
    if (! o) {
        tex_normal_warning ("png expand", "not enough memory");
        return 0;
    }
    /* we could use on branch and factor variables, saves code, costs cycles */
    if (factor) {
        switch (parts) {
            case 4:
                for (int i = 0; i < ysize; i++) {
                    k = i * xsize;
                    for (int j = n; j < n + xline; j++) {
                        unsigned char v = t[j];
                        o[k++] = (unsigned char) extract4(v, 4) * 0x11;
                        o[k++] = (unsigned char) extract4(v, 0) * 0x11;
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
                            o[k++] = (unsigned char) extract2(v, b) * 0x55;
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
                            o[k++] = (unsigned char) extract1(v, b) * 0xFF;
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
                        o[k++] = (unsigned char) extract4(v, 4);
                        o[k++] = (unsigned char) extract4(v, 0);
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
                            o[k++] = (unsigned char) extract2(v, b);
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
                            o[k++] = (unsigned char) extract1(v, b);
                        }
                    }
                    n = n + xline;
                }
                break;
        }
    }
    pnglib_pushlstring(L, o, size);
    return 1;
}

/*tex
     For now we only expand indexed rgba. I'll do the rest when we have one.
*/

static int pnglib_palettemask(lua_State *L)
{
    size_t csize, tsize;
    const char *content = luaL_checklstring(L, 1, &csize);
    const char *transparent = lua_gettop(L) > 3 ? luaL_checklstring(L, 4, &tsize) : NULL;
    if (csize > 0 && tsize > 0 && tsize <= 256) {
        int bytes = lmt_tointeger(L, 2);
        int paths = lmt_tointeger(L, 3);
        switch (bytes) {
            case 3:
                switch (paths) {
                    case 4:
                        break;
                    case 2:
                        break;
                    default:
                        {
                            char *mask = pnglib_memory_malloc(csize);
                            if (mask) {
                                unsigned char alphamap[256] = { 0x00 };
                                memcpy(alphamap, transparent, tsize);
                                for (size_t i = 0; i < csize; i++) {
                                    mask[i] = alphamap[(unsigned char) content[i]];
                                }
                                pnglib_pushlstring(L, mask, csize);
                                return 1;
                            }
                        }
                        break;
                }
                break;
        }
    }
    return 0;
}

/* content bytes depth transparent */

static int pnglib_transparentmask(lua_State *L)
{
    size_t csize;
    const char *content = luaL_checklstring(L, 1, &csize);
    if (csize > 0) {
        size_t tsize;
        int depth = lmt_tointeger(L, 3);
        if (depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16) {
            const char *transparent = lua_gettop(L) > 3 ? luaL_checklstring(L, 4, &tsize) : NULL;
            if (transparent) {
                int bytes = lmt_tointeger(L, 2);
                char *mask = NULL;
                int size = 8;
                size_t msize = 0;
                switch (bytes) {
                    case 1:
                        if (tsize == 2) {
                            switch (depth) {
                                case 1:
                                    size = 1;
                                    mask = pnglib_memory_malloc(csize + 1);
                                    if (mask) {
                                        unsigned char t = transparent[1] & 0x01;
                                        for (size_t i = 0; i < csize; i += 1) {
                                            unsigned char c = (unsigned char) content[i];
                                            mask[msize++] = (unsigned char) ( (t == ((c >> 7) & 0x01) ? 0x00 : 0x80)
                                                                            + (t == ((c >> 6) & 0x01) ? 0x00 : 0x40)
                                                                            + (t == ((c >> 5) & 0x01) ? 0x00 : 0x20)
                                                                            + (t == ((c >> 4) & 0x01) ? 0x00 : 0x10)
                                                                            + (t == ((c >> 3) & 0x01) ? 0x00 : 0x08)
                                                                            + (t == ((c >> 2) & 0x01) ? 0x00 : 0x04)
                                                                            + (t == ((c >> 1) & 0x01) ? 0x00 : 0x02)
                                                                            + (t == ( c       & 0x01) ? 0x00 : 0x01) );
                                        }
                                    }
                                    break;
                                case 2:
                                    size = 2;
                                    mask = pnglib_memory_malloc(csize + 1);
                                    if (mask) {
                                        unsigned char t = transparent[1] & 0x07;
                                        for (size_t i = 0; i < csize; i += 1) {
                                            unsigned char c = (unsigned char) content[i];
                                            mask[msize++] = (unsigned char) ( (t == ((c >> 6) & 0x07) ? 0x00 : 0xC0)
                                                                            + (t == ((c >> 4) & 0x07) ? 0x00 : 0x30)
                                                                            + (t == ((c >> 2) & 0x07) ? 0x00 : 0x0C)
                                                                            + (t == ( c       & 0x07) ? 0x00 : 0x03) );
                                        }
                                    }
                                    break;
                                case 4:
                                    size = 4;
                                    mask = pnglib_memory_malloc(csize + 1);
                                    if (mask) {
                                        unsigned char t = transparent[1] & 0x0F;
                                        for (size_t i = 0; i < csize; i += 1) {
                                            unsigned char c = (unsigned char) content[i];
                                            mask[msize++] = (unsigned char) ( (t == ((c >> 4) & 0x0F) ? 0x00 : 0xF0)
                                                                            + (t == ( c       & 0x0F) ? 0x00 : 0x0F) );
                                        }
                                    }
                                    break;
                                case 8:
                                    mask = pnglib_memory_malloc(csize + 1);
                                    if (mask) {
                                        unsigned char t = transparent[1];
                                        for (size_t i = 0; i < csize; i += 1) {
                                            mask[msize++] = ( t == (unsigned char) content[i] ) ? 0xFF : 0x00;
                                        }
                                    }
                                    break;
                            }
                        }
                        break;
                    case 2:
                        if (tsize == 2 && depth == 16) {
                            mask = pnglib_memory_malloc(csize/2 + 1);
                            if (mask) {
                                unsigned char t1 = transparent[0];
                                unsigned char t2 = transparent[1];
                                for (size_t i = 0; i < csize; i += 2) {
                                    if ( t1 == (unsigned char) content[i  ] &&
                                         t2 == (unsigned char) content[i+1] ) {
                                        mask[msize++] = 0x00;
                                    } else {
                                        mask[msize++] = 0xFF;
                                    }
                                }
                            }
                        }
                        break;
                    case 3:
                        if (tsize == 6 && depth == 8) {
                            mask = pnglib_memory_malloc(csize/3 + 1);
                            if (mask) {
                                unsigned char tr = transparent[1];
                                unsigned char tg = transparent[3];
                                unsigned char tb = transparent[5];
                                for (size_t i = 0; i < csize; i += 3) {
                                    mask[msize++] = ( tr == (unsigned char) content[i  ] &&
                                                      tg == (unsigned char) content[i+1] &&
                                                      tb == (unsigned char) content[i+2] )
                                                  ? 0x00 : 0xFF;
                                }
                            }
                        }
                        break;
                    case 6:
                        if (tsize == 6 && depth == 16) {
                            mask = pnglib_memory_malloc(csize/6 + 1);
                            if (mask) {
                                unsigned char tr1 = transparent[0];
                                unsigned char tr2 = transparent[1];
                                unsigned char tg1 = transparent[2];
                                unsigned char tg2 = transparent[3];
                                unsigned char tb1 = transparent[4];
                                unsigned char tb2 = transparent[5];
                                for (size_t i = 0; i < csize; i += 6) {
                                    if ( tr1 == (unsigned char) content[i  ] && tr2 == (unsigned char) content[i+1] &&
                                         tg1 == (unsigned char) content[i+2] && tg2 == (unsigned char) content[i+3] &&
                                         tb1 == (unsigned char) content[i+4] && tb2 == (unsigned char) content[i+5] ) {
                                        mask[msize++] = 0x00;
                                    } else {
                                        mask[msize++] = 0xFF;
                                    }
                                }
                           }
                        }
                        break;
                }
                if (mask) {
                    /*
                        Actually we can pack as we have one bit only but this kind of transparency
                        is seldom used so we don't bother now.
                    */
                    pnglib_pushlstring(L, mask, msize);
                    lua_pushinteger(L, size);
                    return 2;
                }
            }
        }
    }
    return 0;
}

static int pnglib_frompalette(lua_State *L)
{
    size_t csize, psize;
    const char *content = luaL_checklstring(L, 1, &csize);
    const char *palette = luaL_checklstring(L, 2, &psize);
    if (csize > 0 && psize > 0) {
        size_t tsize;
        const char *transparent = lua_gettop(L) > 4 ? luaL_checklstring(L, 5, &tsize) : NULL;
        int bytes = lmt_tointeger(L, 3);
        int paths = lmt_tointeger(L, 4);
        switch (bytes) {
            case 3:
                switch (paths) {
                    case 4:
                        break;
                    case 2:
                        break;
                    default:
                        if (psize <= (256 * 3)) {
                            char *expand = pnglib_memory_malloc(csize * 3);
                            if (expand) {
                                unsigned char indexmap[256 * 3] = { 0x00 };
                                size_t esize = 0;
                                memcpy(indexmap, palette, psize);
                                for (size_t i = 0; i < csize; i++) {
                                    size_t index = 3 * (unsigned char) content[i];
                                    expand[esize++] = indexmap[index++];
                                    expand[esize++] = indexmap[index++];
                                    expand[esize++] = indexmap[index  ];
                                }
                                pnglib_pushlstring(L, expand, esize);
                                if (transparent && tsize <= 256) {
                                    char *mask = pnglib_memory_malloc(csize);
                                    if (mask) {
                                        unsigned char alphamap[256] = { 0x00 };
                                        memcpy(alphamap, transparent, tsize);
                                        for (size_t i = 0; i < csize; i++) {
                                            mask[i] = alphamap[(unsigned char) content[i]];
                                        }
                                        pnglib_pushlstring(L, mask, csize);
                                        return 2;
                                    }
                                }
                                return 1;
                            }
                        }
                        break;
                }
                break;
        }
    }
    return 0;
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
            o = pnglib_memory_malloc(4 * (tfloor(tsize/3) + 1)); /*tex Plus some slack. */
        } else {
            o = pnglib_memory_malloc(8 * (tfloor(tsize/6) + 1)); /*tex Plus some slack. */
        }
        if (! o) {
            tex_normal_warning("png tocmyk", "not enough memory");
            return 0;
        } else if (depth == 8) {
            for (size_t i = 0; i < tsize; ) {
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = '\0';
            }
        } else {
            /*tex This needs checking, probably not ok! */
            for (size_t i = 0; i < tsize; ) {
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = (unsigned char) (0xFF - t[i++]);
                o[osize++] = '\0';
                o[osize++] = '\0';
            }
        }
        pnglib_pushlstring(L, o, osize);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

// 0.2126 * r + 0.7152 * g + 0.0722 * b
// 0.299  * r + 0.587  * g + 0.114  * b
// 0.212  * r + 0.701  * g + 0.087  * b

static int pnglib_togray(lua_State *L)
{
    size_t tsize;
    const char *t = luaL_checklstring(L, 1, &tsize);
    int depth = lmt_optinteger(L, 2, 0);
    if ((tsize > 0) && (depth == 8 || depth == 16)) {
        int average = lua_toboolean(L, 3);
        size_t osize = 0;
        char *o = pnglib_memory_malloc(tsize/3 + 1); /*tex Plus some slack. */
        if (! o) {
            tex_normal_warning("png tocmyk", "not enough memory");
            return 0;
        } else if (depth == 8) {
            if (average) {
                for (size_t i = 0; i < tsize; ) {
                    unsigned r = (unsigned char) t[i++];
                    unsigned g = (unsigned char) t[i++];
                    unsigned b = (unsigned char) t[i++];
                    o[osize++] = (unsigned char) ((r + g + b) / 3);
                }
            } else {
                for (size_t i = 0; i < tsize; ) {
                    unsigned r = (unsigned char) t[i++];
                    unsigned g = (unsigned char) t[i++];
                    unsigned b = (unsigned char) t[i++];
                    o[osize++] = (unsigned char) round(0.299 * r + 0.587 * g + 0.114 * b);
                }
            }
        } else {
            if (average) {
                for (size_t i = 0; i < tsize; ) {
                    unsigned r = (unsigned char) t[i++] ; r = (r * 256) + (unsigned char) t[i++];
                    unsigned g = (unsigned char) t[i++] ; g = (g * 256) + (unsigned char) t[i++];
                    unsigned b = (unsigned char) t[i++] ; b = (b * 256) + (unsigned char) t[i++];
                    unsigned s = (r + g + b) / 3;
                    o[osize++] = (unsigned char) (s / 256);
                    o[osize++] = (unsigned char) (s % 256);
                }
            } else {
                for (size_t i = 0; i < tsize; ) {
                    unsigned r = (unsigned char) t[i++] ; r = (r * 256) + (unsigned char) t[i++];
                    unsigned g = (unsigned char) t[i++] ; g = (g * 256) + (unsigned char) t[i++];
                    unsigned b = (unsigned char) t[i++] ; b = (b * 256) + (unsigned char) t[i++];
                    unsigned s = round(0.299 * r + 0.587 * g + 0.114 * b);
                    o[osize++] = (unsigned char) (s / 256);
                    o[osize++] = (unsigned char) (s % 256);
                }
            }
        }
        pnglib_pushlstring(L, o, osize);
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
    if (osize == tsize) {
        /* todo: v can be static array c[256] = { 0xFF } */
        char *o    = pnglib_memory_malloc(osize);
        char *v    = lmt_memory_malloc(256);
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
                        unsigned char c = (unsigned char) t[j];
                        o[k++] = (char) v[c];
                    }
                    break;
                case 4:
                    for (size_t j = f; j < l; j++) {
                        unsigned char c = (unsigned char) t[j];
                        o[k++] = (char) v[(c >> 4) & 0x0F];
                        o[k++] = (char) v[(c >> 0) & 0x0F];
                    }
                    break;
                case 2:
                    for (size_t j = f; j < l; j++) {
                        unsigned char c = (unsigned char) t[j];
                        o[k++] = (char) v[(c >> 6) & 0x03];
                        o[k++] = (char) v[(c >> 4) & 0x03];
                        o[k++] = (char) v[(c >> 2) & 0x03];
                        o[k++] = (char) v[(c >> 0) & 0x03];
                    }
                    break;
                default:
                    for (size_t j = f; j < l; j++) {
                        unsigned char c = (unsigned char) t[j];
                        o[k++] = (char) v[(c >> 7) & 0x01];
                        o[k++] = (char) v[(c >> 6) & 0x01];
                        o[k++] = (char) v[(c >> 5) & 0x01];
                        o[k++] = (char) v[(c >> 4) & 0x01];
                        o[k++] = (char) v[(c >> 3) & 0x01];
                        o[k++] = (char) v[(c >> 2) & 0x01];
                        o[k++] = (char) v[(c >> 1) & 0x01];
                        o[k++] = (char) v[(c >> 0) & 0x01];
                    }
                    break;
            }
        }
        pnglib_pushlstring(L, o, osize);
        lmt_memory_free(v);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int pnglib_makemask(lua_State *L) /* for palette */
{
    size_t size;
    const char *content  = luaL_checklstring(L, 1, &size);
    char mapping[256] = { 0x00 };
    char *mask = pnglib_memory_malloc(size);
    switch (lua_type(L, 2)) {
        case LUA_TNUMBER:
            {
                int n = lmt_tointeger(L, 2);
                n = n < 0 ? 0 : n > 255 ? 255 : n;
                for (int i = 0; i <= n; i++) {
                    mapping[i] = 0xFF;
                }
            }
            break;
        case LUA_TTABLE:
            {
                int n = (int) lua_rawlen(L, 2);
                for (int i = 1; i <= n; i++) {
                    if (lua_rawgeti(L, 2, i) == LUA_TTABLE) {
                        int m = (int) lua_rawlen(L, -1);
                        if (m == 3) { 
                            int b, e, v; 
                            lua_rawgeti(L, -1, 1);
                            lua_rawgeti(L, -2, 2);
                            lua_rawgeti(L, -3, 3);
                            b = lmt_tointeger(L, -3);
                            e = lmt_tointeger(L, -2);
                            v = lmt_tointeger(L, -1);
                            b = b < 0 ? 0 : b > 255 ? 255 : b;
                            e = e < 0 ? 0 : e > 255 ? 255 : e;
                            v = v < 0 ? 0 : v > 255 ? 255 : v;
                            for (int i = b; i <= e; i++) {
                                mapping[i] = (char) v;
                            }
                            lua_pop(L, 3);
                        }
                    }
                    lua_pop(L, 1);
                }
            }
        case LUA_TSTRING:
            {
                size_t l = 0;
                const char *m  = luaL_checklstring(L, 1, &l);
                memcpy(mask, m, l > size ? size : l);               
            }
            break;
        default:
            break;
    }
    for (int i = 0; i < (int) size; i++) {
        mask[i] = (unsigned char) mapping[(unsigned char) content[i]];
    }
    pnglib_pushlstring(L, mask, size);
    lua_pushlstring(L, mapping, 256);
    return 2;
}

/*
    I tested reduction to two bytes but it's too slow for runtime usage and also useless in terms
    of quality. Rendering is also slower. So we only kept the half option. We know that we're below 
    max int because we only have bytemaps here.
*/

static int pnglib_reduce(lua_State *L)
{
    size_t size; 
    const char * data = lua_tolstring(L, 1, &size);
    if (data && size) {
        int nx = lmt_tointeger(L, 2);
        int ny = lmt_tointeger(L, 3);
        int nz = lmt_tointeger(L, 4);
        if (nx * ny * nz == (int) size) {
            unsigned char *result;
            int dx = nx * nz;
            int mx = dx / 2;
            int more = 0;
            if (dx % 2 == 1) { 
                more = 1;
                size = (mx + 1) * ny;
            } else { 
                size = mx * ny;
            }
            result = pnglib_memory_malloc(size);
            if (result) {
                int accurate = lua_toboolean(L, 5);
                int r = 0;
                int d = 0;
                if (accurate) {
                    for (int y = 0; y < ny; y++) {
                        d = y * dx;
                        for (int x = 0; x < mx; x++) {
                            unsigned char b1 = (unsigned char) data[d++];
                            unsigned char b2 = (unsigned char) data[d++];
                            b1 = b1 > 0xF7 ? 0xF0 :  ((b1 + 0x07) & 0xF0);
                            b2 = b2 > 0xF7 ? 0x0F : (((b2 + 0x07) & 0xF0) >> 4);
                            result[r++] = (unsigned char) (b1 + b2);
                        }
                        if (more) { 
                            unsigned char b1 = (unsigned char) data[d++];
                            b1 = b1 > 0xF7 ? 0xF0 : ((b1 + 0x07) & 0xF0);
                            result[r++] = b1;
                        }
                    }
                } else { 
                    /* we go for speed so no round etc here */
                    for (int y = 0; y < ny; y++) {
                        d = y * dx;
                        for (int x = 0; x < mx; x++) {
                            unsigned char b1 = ((unsigned char) data[d++]) & 0xF0;
                            unsigned char b2 = ((unsigned char) data[d++]) & 0xF0;
                            result[r++] = (unsigned char) (b1 + (b2 >> 4));
                        }
                        if (more) { 
                            unsigned char b1 = ((unsigned char) data[d++]) & 0xF0;
                            result[r++] = (unsigned char) b1;
                        }
                    }
                }
                pnglib_pushlstring(L, (char *) result, size);
                return 1;
            }
        }
    }
    return 0;
}

static const struct luaL_Reg pngdecodelib_function_list[] = {
    { "applyfilter",     pnglib_applyfilter     },
    { "splitmask",       pnglib_splitmask       },
    { "interlace",       pnglib_interlace       },
    { "expand",          pnglib_expand          },
    { "tocmyk",          pnglib_tocmyk          },
    { "togray",          pnglib_togray          },
    { "tomask",          pnglib_tomask          },
    { "makemask",        pnglib_makemask        },
    { "reduce",          pnglib_reduce          },
    { "frompalette",     pnglib_frompalette     },
    { "palettemask",     pnglib_palettemask     },
    { "transparentmask", pnglib_transparentmask },
    { "setexperiment",   pnglib_setexperiment   },
    { NULL,              NULL                   },
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
