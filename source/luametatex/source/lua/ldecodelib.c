/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    Some png helpers, I could have introduced a userdata for blobs at some point but
    it's not that useful as string sare also sequences of bytes and lua handles those
    well.

    These are experimental interfaces that can change any time we like without notice
    till we like what we have.

*/

/* t xsize ysize bpp (includes mask) */

static int pnglib_applyfilter(lua_State * L)
{
    size_t size;
    const char *s = luaL_checklstring(L, 1, &size);
    int xsize     = lua_tointeger(L,2);
    int ysize     = lua_tointeger(L,3);
    int slice     = lua_tointeger(L,4);
    int len       = xsize * slice + 1; /* filter byte */
    int n         = 0;
    int m         = len - 1;
    int i, j;
    unsigned char *t;
    if (ysize * len != (int) size) {
        formatted_warning("png filter","sizes don't match: %i expected, %i provided",ysize * len,size);
        return 0;
    }
    t = malloc(size);
    memcpy(t, s, size);
    for (i=0; i<ysize; i++) {
        switch (t[n]) {
            case 0 :
                break;
            case 1 :
                for (j=n+slice+1; j<=n+m; j++) {
                    t[j] = (unsigned char) (t[j] + t[j-slice]);
                }
                break;
            case 2 :
                if (i>0) {
                    for (j=n+1; j<=n+m; j++) {
                        t[j] = (unsigned char) (t[j] + t[j-len]);
                    }
                }
                break;
            case 3 :
                if (i>0) {
                    for (j=n+1; j<=n+slice; j++) {
                        t[j] = (unsigned char) (t[j] + t[j-len]/2);
                    }
                    for (j=n+slice+1; j<=n+m; j++) {
                        t[j] = (unsigned char) (t[j] + (t[j-slice] + t[j-len])/2);
                    }
                } else {
                    for (j=n+slice+1; j<=n+m; j++) {
                        t[j] = (unsigned char) (t[j] + t[j-slice]/2);
                    }
                }
                break;
            case 4 :
                for (j=n+1; j<=n+slice; j++) {
                    int p = j - len;
                    t[j] = (unsigned char) (t[j] + t[p]);
                }
                for (j=n+slice+1; j<=n+m; j++) {
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
                break;
            default:
                break;
        }
        n = n + len;
    }
    /* wipe out filter byte */
    j = 0; /* source */
    n = 0; /* target */
    for (i=0; i<ysize; i++) {
        (void) memcpy(&t[n],&t[j+1],len-1); /* target source size */
        j += len;
        n += len - 1;
    }
    lua_pushlstring(L,(char *)t,size-ysize);
    free(t);
    return 1;
}

/* t xsize ysize bpp (includes mask) bytes */

static int pnglib_splitmask(lua_State * L)
{
    size_t size;
    const char *t  = luaL_checklstring(L, 1, &size);
    int xsize      = lua_tointeger(L,2);
    int ysize      = lua_tointeger(L,3);
    int bpp        = lua_tointeger(L,4); /* 1 or 3 */
    int bytes      = lua_tointeger(L,5); /* 1 or 2 */
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
    int i;
    /* we assume that the filter byte is gone */
    if (ysize * len != (int) size) {
        formatted_warning("png split","sizes don't match: %i expected, %i provided",ysize * len,size);
        return 0;
    }
    b = malloc(bsize);
    m = malloc(msize);
    /* a bit optimized */
    if (blen == 3) {
        /* 8 bit rgb graphics */
        for (i=0; i<ysize*xsize; i++) {
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
    } else if (blen == 1) {
        /* 8 bit gray or indexed graphics */
        for (i=0; i<ysize*xsize; i++) {
            b[nb++] = t[nt++];
            m[nm++] = t[nt++];
        }
    } else {
        /* everything else */
        for (i=0; i<ysize*xsize; i++) {
            /*
            int k;
            for (k=0; k<blen; k++) {
                b[nb++] = t[nt++];
            }
            for (k=0; k<mlen; k++) {
                m[nm++] = t[nt++];
            }
            */
            memcpy(&b[nb], &t[nt], blen);
            nt += blen;
            nb += blen;
            memcpy(&m[nm], &t[nt], mlen);
            nt += mlen;
            nm += mlen;
        }
    }
    lua_pushlstring(L,b,bsize);
    free(b);
    lua_pushlstring(L,m,msize);
    free(m);
    return 2;
}

/* output input xsize ysize slice pass filter */

static int xstarts[] = { 0, 4, 0, 2, 0, 1, 0 };
static int ystarts[] = { 0, 0, 4, 0, 2, 0, 1 };
static int xsteps[]  = { 8, 8, 4, 4, 2, 2, 1 };
static int ysteps[]  = { 8, 8, 8, 4, 4, 2, 2 };

static int pnglib_interlace(lua_State * L)
{
    size_t isize, psize;
    const char *inp;
    const char *pre;
    char *out;
    int xsize, ysize, xstep, ystep, xstart, ystart, slice, pass, nx, ny;
    int target, start, step, size;
    int i, j ;
    /* dimensions */
    xsize  = lua_tointeger(L,1);
    ysize  = lua_tointeger(L,2);
    slice  = lua_tointeger(L,3);
    pass   = lua_tointeger(L,4);
    if (pass < 1 || pass > 7) {
        formatted_warning("png interlace","bass pass: %i (1..7)",pass);
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
            formatted_warning("png interlace","output sizes don't match: %i expected, %i provided",psize,size);
            return 0;
        }
    }
    /* todo: some more checking */
    out = malloc(size);
    if (pass == 0) {
        memset(out,0,size);
    } else {
        memcpy(out,pre,psize);
    }
    if (slice == 1) {
        for (j=0;j<ny;j++) {
            int t = target + j * ystep;
            for (i=t;i<t+step;i+=xstep) {
                out[i] = inp[start];
                start = start + slice;
            }
        }
    } else if (slice == 2) {
        for (j=0;j<ny;j++) {
            int t = target + j * ystep;
            for (i=t;i<t+step;i+=xstep) {
                out[i]   = inp[start];
                out[i+1] = inp[start+1];
                start = start + slice;
            }
        }
    } else if (slice == 3) {
        for (j=0;j<ny;j++) {
            int t = target + j * ystep;
            for (i=t;i<t+step;i+=xstep) {
                out[i]   = inp[start];
                out[i+1] = inp[start+1];
                out[i+2] = inp[start+2];
                start = start + slice;
            }
        }
    } else {
        for (j=0;j<ny;j++) {
            int t = target + j * ystep;
            for (i=t;i<t+step;i+=xstep) {
                memcpy(&out[i],&inp[start],slice);
                start = start + slice;
            }
        }
    }
    lua_pushlstring(L,out,size);
    free(out);
    return 1;
}

/* content xsize ysize parts run factor */

# define extract1(a,b) ((a >> b) & 0x01)
# define extract2(a,b) ((a >> b) & 0x03)
# define extract4(a,b) ((a >> b) & 0x0F)

static int pnglib_expand(lua_State * L)
{
    size_t tsize;
    const char *t = luaL_checklstring(L, 1, &tsize);
    char *o       = NULL;
    int n         = 0;
    int k         = 0;
    int i, j, b;
    int xsize     = lua_tointeger(L,2);
    int ysize     = lua_tointeger(L,3);
    int parts     = lua_tointeger(L,4);
    int xline     = lua_tointeger(L,5);
    int factor    = lua_toboolean(L,6);
    int size      = ysize * xsize;
    int extra     = ysize * xsize + 16; /* probably a few bytes is enough */
    if (xline*ysize > (int) tsize) {
        formatted_warning("png interlace","expand sizes don't match: %i expected, %i provided",size,parts*tsize);
        return 0;
    }
    o = malloc(extra);
    /* we could use on branch and factor variables ,, saves code, costs cycles */
    if (factor) {
        if (parts == 4) {
            for (i=0;i<ysize;i++) {
                k = i * xsize;
                for (j=n;j<n+xline;j++) {
                    unsigned char v = t[j];
                    o[k++] = (unsigned char) extract4(v,4) * 0x11;
                    o[k++] = (unsigned char) extract4(v,0) * 0x11;
                }
                n = n + xline;
            }
        } else if (parts == 2) {
            for (i=0;i<ysize;i++) {
                k = i * xsize;
                for (j=n;j<n+xline;j++) {
                    unsigned char v = t[j];
                    for (b=6;b>=0;b-=2) {
                        o[k++] = (unsigned char) extract2(v,b) * 0x55;
                    }
                }
                n = n + xline;
            }
        } else {
            for (i=0;i<ysize;i++) {
                k = i * xsize;
                for (j=n;j<n+xline;j++) {
                    unsigned char v = t[j];
                    for (b=7;b>=0;b--) {
                        o[k++] = (unsigned char) extract1(v,b) * 0xFF;
                    }
                }
                n = n + xline;
            }
        }
    } else {
        if (parts == 4) {
            for (i=0;i<ysize;i++) {
                k = i * xsize;
                for (j=n;j<n+xline;j++) {
                    unsigned char v = t[j];
                    o[k++] = (unsigned char) extract4(v,4);
                    o[k++] = (unsigned char) extract4(v,0);
                }
                n = n + xline;
            }
        } else if (parts == 2) {
            for (i=0;i<ysize;i++) {
                k = i * xsize;
                for (j=n;j<n+xline;j++) {
                    unsigned char v = t[j];
                    for (b=6;b>=0;b-=2) {
                        o[k++] = (unsigned char) extract2(v,b);
                    }
                }
                n = n + xline;
            }
        } else {
            for (i=0;i<ysize;i++) {
                k = i * xsize;
                for (j=n;j<n+xline;j++) {
                    unsigned char v = t[j];
                    for (b=7;b>=0;b--) {
                        o[k++] = (unsigned char) extract1(v,b);
                    }
                }
                n = n + xline;
            }
        }
    }
    lua_pushlstring(L,o,size);
    free(o);
    return 1;
}

static const struct luaL_Reg pngdecodelib[] = {
    { "applyfilter", pnglib_applyfilter },
    { "splitmask",   pnglib_splitmask },
    { "interlace",   pnglib_interlace },
    { "expand",      pnglib_expand },
    { NULL,          NULL }
};

int luaopen_pngdecode(lua_State * L)
{
    lua_newtable(L);
    luaL_setfuncs(L, pngdecodelib, 0);
    return 1;
}

static const struct luaL_Reg pdfdecodelib[] = {
    { NULL, NULL }
};

int luaopen_pdfdecode(lua_State * L)
{
    lua_newtable(L);
    luaL_setfuncs(L, pdfdecodelib, 0);
    return 1;
}
