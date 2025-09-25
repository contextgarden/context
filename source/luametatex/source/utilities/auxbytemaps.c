/*
    See license.txt in the root of this project.
*/

# include "auxbytemaps.h"
# include "auxmemory.h"
# include <math.h>


/* 
    todo: set nz to zero when no data so we have a test less 
    todo: round keep in integer domain (see end of decodelib)
*/

static inline unsigned char max_of_three(unsigned char a, unsigned char b, unsigned char c)
{
    if (a > b && a > c) {
        return a;
    } else if (a > c) {
        return a;
    } else if (b > c) {
        return b;
    } else {
        return c;
    }
}

static inline unsigned char min_of_three(unsigned char a, unsigned char b, unsigned char c)
{
    if (a < b && a < c) {
        return a;
    } else if (a < c) {
        return a;
    } else if (b < c) {
        return b;
    } else {
        return c;
    }
}

static inline int weighted(int r, int g, int b)
{
    return round(0.299 * r + 0.587 * g + 0.114 * b);
}

int bytemap_reset(bytemap_data *bytemap, size_t *count)
{
    int done = 0;
    if (bytemap) {
        if (bytemap->data) { 
            lmt_memory_free(bytemap->data);
            if (count) {
                *count -= bytemap->nx * bytemap->ny * bytemap->nz;
            }
            done = 1;
        }
        *bytemap = (bytemap_data) {
            .data    = NULL,
            .nx      = 0,
            .ny      = 0,
            .nz      = 0,
            .ox      = 0,
            .oy      = 0,
            .options = 0,
        };
    }
    return done; 
}

void bytemap_reduce(bytemap_data *bytemap, int method, size_t *count)
{
    if (bytemap) {
        int nz = bytemap->nz;
        if (nz == 3) {
            int nx = bytemap->nx;
            int ny = bytemap->ny;
            unsigned char *color = bytemap->data;
            unsigned char *gray = lmt_memory_malloc(nx*ny);
            unsigned c = 0;
            switch (method) {
                case bytemap_reduction_average:
                    for (int g = 0; g < nx * ny; g++) {
                        int s = round( (double) (
                              (unsigned char) color[c]
                            + (unsigned char) color[c+1]
                            + (unsigned char) color[c+2]
                        ) / 3.0);
                        c += 3;
                        gray[g] = s > 255 ? 255 : (unsigned char) s;
                    }
                    break;
                case bytemap_reduction_minmax:
                    for (int g = 0; g < nx * ny; g++) {
                        int s = round( (double) (
                              max_of_three(color[c], color[c+1], color[c+2]),
                            + min_of_three(color[c], color[c+1], color[c+2])
                        ) / 2.0);
                        c += 3;
                        gray[g] = s > 255 ? 255 : (unsigned char) s;
                    }
                    break;
             // case bytemap_reduction_weighted:
             //     /* fall through */
                default:
                    for (int g = 0; g < nx * ny; g++) {
                        int s = round(
                              0.299 * (unsigned char) color[c]
                            + 0.587 * (unsigned char) color[c+1]
                            + 0.114 * (unsigned char) color[c+2]
                        );
                        c += 3;
                        gray[g] = s > 255 ? 255 : (unsigned char) s;
                    }
                    break;
            }
            if (count) { 
                *count -= nx * ny * 2;
            }
            lmt_memory_free(color);
            *bytemap = (bytemap_data) {
                .data    = gray,
                .nx      = nx,
                .ny      = ny,
                .nz      = 1,
                .ox      = 0,
                .oy      = 0,
                .options = 0,
            };
        }
    }
}

void bytemap_slice_gray(bytemap_data *bytemap, int x, int y, int dx, int dy, int s)
{
    if (dx > 0 && dy > 0) {
        switch (bytemap->nz) {
            case 1:
                {
                    unsigned char *p = bytemap->data;
                    int w = bytemap->nx;
                    int o = x;
                    if (x + dx > bytemap->nx) {
                        dx = bytemap->nx - x;
                    }
                    if (y + dy > bytemap->ny) {
                        dy = bytemap->ny - y;
                    }
                    o += bm_current_y(bytemap->ny,y) * w;
                    memset(p + o, valid_byte(s), dx);
                    for (int i = bm_first_y(bytemap->ny,y,dy); i <= bm_last_y(bytemap->ny,y,dy); i++) {
                        memcpy(p + x + i * w, p + o, dx);
                    }
                }
                break;
            case 3:
                bytemap_slice_rgb(bytemap, x, y, dx, dy, s, s, s);
                break;
        }

    }
}

void bytemap_slice_rgb(bytemap_data *bytemap, int x, int y, int dx, int dy, int r, int g, int b)
{
    if (dx > 0 && dy > 0) {
        switch (bytemap->nz) {
            case 1:
                bytemap_slice_gray(bytemap, x, y, dx, dy, weighted(r,g,b));
                break;
            case 3:
                {
                    unsigned char *p = bytemap->data;
                    int w = 3 * bytemap->nx;
                    int o = 3 * x;
                    if (x + dx > bytemap->nx) {
                        dx = bytemap->nx - x;
                    }
                    if (y + dy > bytemap->ny) {
                        dy = bytemap->ny - y;
                    }
                    o += bm_current_y(bytemap->ny,y) * w;
                    bytemap->data[o+0] = valid_byte(r);
                    bytemap->data[o+1] = valid_byte(g);
                    bytemap->data[o+2] = valid_byte(b);
                    for (int i = 1; i < dx; i++) {
                        memcpy(p + o + i * 3, p + o, 3);
                    }
                    for (int i = bm_first_y(bytemap->ny,y,dy); i <= bm_last_y(bytemap->ny,y,dy); i++) {
                        memcpy(p + 3 * x + i * w, p + o, 3 * dx);
                    }
                }
                break;
        }
    }
}

void bytemap_slice_range(bytemap_data *bytemap, int x, int y, int dx, int dy, int min, int max)
{
    if (dx > 0 && dy > 0) {
        switch (bytemap->nz) {
            case 1:
            case 3:
                {
                    int w = bytemap->nx * bytemap->nz;
                    double p = min; 
                    double m = (max - min) / 255.0; 
                    y = bm_first_y(bytemap->ny,y,dy);
                    dx += x; 
                    dy += y; 
                    if (dx > bytemap->nx) {
                        dx = bytemap->nx - x;
                    }
                    if (dy > bytemap->ny) {
                        dy = bytemap->ny - y;
                    }
                    for (int j = y; j <= dy ; j++) {
                        int o = bm_current_y(bytemap->ny,j) * w + x;
                        for (int i = x; i <= dx; i++) {
                            /* I need to check this with Mikael. */
                            int b = lround((double) bytemap->data[o] * m + p);
                            bytemap->data[o++] = b > max ? max : b < min ? min : b;
                        }
                    }
                }
                break;
        }
    }
}

int bytemap_aux_bounds(bytemap_data *bytemap, int value, int *lx, int *ly, int *rx, int *ry)
{
    unsigned char *d = bytemap->data;
    int nx = bytemap->nx;
    int ny = bytemap->ny;
    int nz = bytemap->nz;
    /* bounds */
    int llx = nx - 1;
    int lly = ny - 1;
    int urx = 0;
    int ury = 0;
    switch (nz) {
        case 1:
            for (int y = 0; y < ny; y++) {
                for (int x = 0; x < nx; x++) {
                    /* here posit */
                    if (*d != value) {
                        if (y < lly) { lly = y; }
                        if (y > ury) { ury = y; }
                        if (x < llx) { llx = x; }
                        if (x > urx) { urx = x; }
                    }
                    d = d + 1;
                }
                if (llx == 0 && urx == nx && lly == 0 && ury == ny) {
                    goto DONE;
                }
            }
            break;
        case 3:
            for (int y = 0; y < ny; y++) {
                for (int x = 0; x < nx; x++) {
                    /* here posit */
                    if (*d != value || *(d+1) != value || *(d+2) != value) {
                        if (y < lly) { lly = y; }
                        if (y > ury) { ury = y; }
                        if (x < llx) { llx = x; }
                        if (x > urx) { urx = x; }
                    }
                    d = d + 3;
                    if (llx == 0 && urx == nx && lly == 0 && ury == ny) {
                        goto DONE;
                    }
                }
            }
            break;
    }
    DONE:
    lly = bm_current_y(ny,lly);
    ury = bm_current_y(ny,ury);
    if (urx < llx || ury < lly) {
        *lx = 0;
        *ly = 0;
        *rx = nx - 1;
        *ry = ny - 1;
    } else {
        *lx = llx;
        *ly = lly;
        *rx = urx;
        *ry = ury;
    }
    return (*lx > 0 || *ly > 0 || *rx < nx || *ry < ny);
}

int bytemap_bounds(bytemap_data *bytemap, int value, int *llx, int *lly, int *urx, int *ury)
{
    if (bytemap) {
        *llx = bytemap->nx - 1;
        *lly = bytemap->ny - 1;
        *urx = 0;
        *ury = 0;
        return bytemap_aux_bounds(bytemap, value, llx, lly, urx, ury);
    } else { 
        return 0;
    }
}

void bytemap_clip(bytemap_data *bytemap, int value, size_t *count)
{
    if (bytemap) {
        int llx = 0;
        int lly = 0;
        int urx = bytemap->nx;
        int ury = bytemap->ny;
        if (bytemap_aux_bounds(bytemap, value, &llx, &lly, &urx, &ury)) {
            int oldnx = bytemap->nx;
            int oldny = bytemap->ny;
            int oldnz = bytemap->nz;
            int newnx = urx - llx + 1;
            int newny = ury - lly + 1;
            unsigned char *p = bytemap->data + lly * oldnx * oldnz + llx;
            unsigned char *c = lmt_memory_malloc(newnx * newny * oldnz);
            unsigned char *d = c;
            for (int y=1; y <= newny; y++) {
                memcpy(c, p, newnx * oldnz);
                c = c + newnx * oldnz;
                p = p + oldnx * oldnz;
            }
            lmt_memory_free(bytemap->data);
            if (count) { 
                /* todo : *count */
                *count -= oldnx * oldny * oldnz;
                *count += newnx * newny * oldnz;
            }
            bytemap->data = d;
            bytemap->ox   = 0;
            bytemap->oy   = 0;
            bytemap->nx   = newnx;
            bytemap->ny   = newny;
        }
    }
}

void bytemap_wipe(bytemap_data *bytemap)
{
    if (bytemap) { 
        *bytemap = (bytemap_data) {
            .data    = NULL,
            .nx      = 0,
            .ny      = 0,
            .nz      = 0,
            .ox      = 0,
            .oy      = 0,
            .options = 0,
        };
    }
}

void bytemap_allocate(bytemap_data *bytemap, int nx, int ny, int nz, size_t *count)
{
    if (bytemap) {
        int size = nx * ny * nz;
        *bytemap = (bytemap_data) {
            .data    = lmt_memory_malloc(size),
            .nx      = nx,
            .ny      = ny,
            .nz      = nz,
            .ox      = 0,
            .oy      = 0,
            .options = 0,
        };
        if (count) { 
            *count += size;
        }
    }
}

void bytemap_copy(bytemap_data *source, bytemap_data *target, size_t *count)
{
    if (source && target) {
        int size = source->nx * source->ny * source->nz;
        if (target->data) {
            lmt_memory_free(target->data);
        }
        *target = (bytemap_data) {
            .data    = lmt_memory_malloc(size),
            .nx      = source->nx,
            .ny      = source->ny,
            .nz      = source->nz,
            .ox      = source->ox,
            .oy      = source->oy,
            .options = 0,
        };
        if (source->data && target->data) {
            memcpy(target->data, source->data, size);
        }
    }
}

/*tex We assume that bytemap has a value and we hope for inlining. */

inline void bytemap_set_gray(bytemap_data *bytemap, int x, int y, int s)
{
    if (x >= 0 && y >= 0 && x < bytemap->nx && y < bytemap->ny) {
        switch (bytemap->nz) {
            case 1:
                bytemap->data[bm_current_y(bytemap->ny,y) * bytemap->nx + x] = valid_byte(s);
                break;
            case 3:
                memset(bytemap->data + (bm_current_y(bytemap->ny,y) * bytemap->nx + x) * 3, valid_byte(s), 3);
                break;
        }
    }
}

inline void bytemap_set_rgb(bytemap_data *bytemap, int x, int y, int r, int g, int b)
{
    if (x >= 0 && y >= 0 && x < bytemap->nx && y < bytemap->ny) {
        switch (bytemap->nz) {
            case 1:
                bytemap->data[bm_current_y(bytemap->ny,y) * bytemap->nx + x] = valid_byte(weighted(r, g, b));
                break;
            case 3:
                {
                    int offset = (bm_current_y(bytemap->ny,y) * bytemap->nx + x) * 3;
                    bytemap->data[offset+0] = valid_byte(r);
                    bytemap->data[offset+1] = valid_byte(g);
                    bytemap->data[offset+2] = valid_byte(b);
                }
                break;
        }
    }
}

int bytemap_has_byte_gray(bytemap_data *bytemap, int s)
{
    if (bytemap) {
        switch (bytemap->nz) {
            case 1:
                for (int i = 0; i < bytemap->nx * bytemap->ny; i++) {
                    if (bytemap->data[i] == (unsigned char) s) {
                        return 1;
                    }
                }
                return 0;
            case 3:
                return bytemap_has_byte_rgb(bytemap, s, s, s);
        }
    }
    return 0;
}

int bytemap_has_byte_range(bytemap_data *bytemap, int min, int max)
{
    if (bytemap && bytemap->data) { 
        switch (bytemap->nz) {
            case 1:
                for (int i = 0; i < bytemap->nx * bytemap->ny; i++) {
                    if  (bytemap->data[i] >= (unsigned char) min && bytemap->data[i] <= (unsigned char) max) {
                        return 1;
                    }
                }
                return 0;
            case 3:
                return 0;
        }
    }
    return 0;
}

int bytemap_has_byte_rgb(bytemap_data *bytemap, int r, int g, int b)
{
    if (bytemap && bytemap->data) { 
        switch (bytemap->nz) {
            case 1:
                return bytemap_has_byte_gray(bytemap, weighted(r, g, b));
            case 3:
                /* todo: fast search in mem range */
                for (int i = 0; i < bytemap->nx * bytemap->ny * bytemap->nz; i += 3) {
                    if (bytemap->data[i+0] == (unsigned char) r &&
                        bytemap->data[i+1] == (unsigned char) g &&
                        bytemap->data[i+2] == (unsigned char) b
                    ) {
                        return 1;
                    }
                }
                return 0;
        }
    }
    return 0;
}

int bytemap_get_byte(bytemap_data *bytemap, int x, int y, int z)
{
    if (bytemap && bytemap->data) {
        int nx = bytemap->nx;
        int ny = bytemap->ny;
        if (x >= 0 && y >= 0 && x < nx && y < ny) {
            int nz = bytemap->nz;
            switch (nz) {
                case 1:
                    return bytemap->data[bm_current_y(ny,y) * nx + x];
                case 3:
                    {
                        int p = bm_current_y(ny,y) * ny * nz + x;
                        if (z >= 1 && z <= 3) { 
                            return bytemap->data[p+z-1];
                        } else {
                            return weighted (
                                bytemap->data[p+0],
                                bytemap->data[p+1],
                                bytemap->data[p+2]
                            );
                        }
                    }
            }
        }
    }
    return 0;
}

void bytemap_get_bytes(bytemap_data *bytemap, int x, int y, unsigned char *b1, unsigned char *b2, unsigned char *b3)
{
    if (bytemap && bytemap->data) {
        int nx = bytemap->nx;
        int ny = bytemap->ny;
        if (x >= 0 && y >= 0 && x < nx && y < ny) {
            int nz = bytemap->nz;
            switch (nz) {
                case 1:
                    {
                        *b1 = bytemap->data[bm_current_y(ny,y) * nx + x];
                        *b2 = '\0';
                        *b3 = '\0';
                        return;
                    }
                case 3:
                    {
                        int p = bm_current_y(ny,y) * ny * nz + x;
                        *b1 = bytemap->data[p++];
                        *b2 = bytemap->data[p++];
                        *b3 = bytemap->data[p];
                        return;
                    }
            }
        }
    }
    *b1 = '\0';;
    *b2 = '\0';
    *b3 = '\0';
}

char *bytemap_get_value(bytemap_data *bytemap, int *nx, int *ny, int *nz) /* todo */
{
    if (bytemap && bytemap->data) {
        *nx = bytemap->nx;
        *ny = bytemap->ny;
        *nz = bytemap->nz;
        if (nx > 0 && ny > 0) {
            size_t length = (size_t) ((*nx) * (*ny) * (*nz));
            char *result = lmt_memory_malloc(length);
            memcpy(result, bytemap->data, length);
            return result;
        }
    }
    *nx = 0;
    *ny = 0;
    *nz = 0;
    return NULL;
}

void bytemap_downsample(bytemap_data *source, bytemap_data *target, int r)
{
    /* 
        Todo: when source and target are the same, we have to use a temporary bytemap. 
    */
    if (source && target && source != target && source->data != target->data && source->data) {
        int nx = source->nx;
        int ny = source->ny; 
        int nz = source->nz;
        int dy = nx * nz; 
        int mx = nx / r;
        int my = ny / r;
        nx = mx * r;
        ny = my * r;
        if (r > nx) {
            r = 0;
        } else if (r < 2) { 
            r = 2;
        } else if (r > (nx * nz) / 2) {
            r = (nx * nz) / 2;
        }
        if (r > 1) {
            unsigned char *q = lmt_memory_malloc(mx * my * nz);
            if (q) {
                int rr = r * r;
                if (target->data) {
                    lmt_memory_free(target->data);
                }
                *target = (bytemap_data) {
                    .data    = q,
                    .nx      = mx,
                    .ny      = my,
                    .nz      = nz,
                    .ox      = 0,
                    .oy      = 0,
                    .options = 0,
                };
                if (nz == 1) {
                    for (int y = 0; y < ny; y += r) {
                        for (int x = 0; x < nx; x += r) {
                            int s = 0;
                            for (int j = y; j < y + r; j++) {
                                unsigned char *p = &(source->data[j*dy+x]);
                                for (int i = 0; i < r; i++) {
                                    s += (unsigned char) *(p++);
                                }
                            }
                          *(q++) = (unsigned char) (s / rr);
                        }
                    }
                } else {
                    for (int y = 0; y < ny; y += r) {
                        for (int x = 0; x < nx; x += r) {
                            int rc = 0;
                            int gc = 0;
                            int bc = 0;
                            int dx = x * nz;
                            for (int j = y; j < y + r; j++) {
                                unsigned char *p = &(source->data[j*dy+dx]);
                                for (int i = 0; i < r; i++) {
                                    rc += (unsigned char) *(p++);
                                    gc += (unsigned char) *(p++);
                                    bc += (unsigned char) *(p++);
                                }
                            }
                            *(q++) = (unsigned char) (rc / rr);
                            *(q++) = (unsigned char) (gc / rr);
                            *(q++) = (unsigned char) (bc / rr);
                        }
                    }
                }
            }
        }
    }
}

void bytemap_downgrade(bytemap_data *source, bytemap_data *target, int r)
{
    /* 
        Todo: when source and target are the same, we have to use a temporary bytemap. 
    */
    if (source && target && source != target && source->data != target->data && source->data) {
        int nx = source->nx;
        int ny = source->ny; 
        int nz = source->nz;
        if (r > 255) {
            r = 255;
        } else if (r < 1) {
            r = 1; 
        }
        unsigned char *q = lmt_memory_malloc(nx * ny * nz);
        if (q) {
            unsigned char *p = source->data;
            if (target->data) {
                lmt_memory_free(target->data);
            }
            *target = (bytemap_data) {
                .data    = q,
                .nx      = nx,
                .ny      = ny,
                .nz      = nz,
                .ox      = 0,
                .oy      = 0,
                .options = 0,
            };
            /* todo: fast path for 2 and 4 */
            for (int i = 0; i < nx * ny * nz; i++) {
                int l = r * lround(((double) ((unsigned char) p[i]))/r);
                q[i] = l > 0xFF ? 0xFF : (unsigned char) l;
            }
        }
    }
}
