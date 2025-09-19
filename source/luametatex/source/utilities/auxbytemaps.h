/*
    See license.txt in the root of this project.
*/

/*tex
    This code started out as being part of MP but it make sense to isolate it. We have 
    several components that need to access bytemaps so we can share some. 
*/ 

# ifndef LMT_UTILITIES_BYTEMAPS_H
# define LMT_UTILITIES_BYTEMAPS_H

# include <ctype.h>
# include <stddef.h>

# define bytemap_min 0x0001
# define bytemap_max 0x2000 /* 8K : already becomes pretty slow */

typedef enum bytemap_options {
    bytemap_option_persistent = 1,
    bytemap_option_posit      = 2,
} bytemap_options;

typedef enum bytemap_reductions {
    bytemap_reduction_weighted = 0,
    bytemap_reduction_average  = 1,
    bytemap_reduction_minmax   = 2,
} bytemap_reductions;

typedef struct bytemap_data {
    unsigned char *data;
    int            nx;
    int            ny;
    int            nz;
    int            ox;
    int            oy;
    int            options; 
} bytemap_data;

# define bm_current_y(ny,y)  (ny-y-1)
# define bm_first_y(ny,y,dy) (bm_current_y(ny,y)-dy+1)
# define bm_last_y(ny,y,dy)  (bm_current_y(ny,y)-1)

static inline unsigned char valid_byte(int value)
{
    if (value < 0) {
        return 0;
    } else if (value > 255) {
        return 255;
    } else {
        return (unsigned char) value;
    }
}

static inline int bytemap_okay(int nx, int ny, int nz)
{
    return 
        nx >= 1 && nx <= bytemap_max &&
        ny >= 1 && ny <= bytemap_max &&
       (nz == 1 || nz == 3);
}

extern void   bytemap_wipe           (bytemap_data *bytemap);
extern void   bytemap_allocate       (bytemap_data *bytemap, int nx, int ny, int nz, size_t *count);
extern int    bytemap_reset          (bytemap_data *bytemap, size_t *count);
extern void   bytemap_reduce         (bytemap_data *bytemap, int method, size_t *count);
extern void   bytemap_slice_gray     (bytemap_data *bytemap, int x, int y, int dx, int dy, int s);
extern void   bytemap_slice_rgb      (bytemap_data *bytemap, int x, int y, int dx, int dy, int r, int g, int b);
extern void   bytemap_slice_range    (bytemap_data *bytemap, int x, int y, int dx, int dy, int min, int max);
extern int    bytemap_bounds         (bytemap_data *bytemap, int value, int *lx, int *ly, int *rx, int *ry);
extern void   bytemap_clip           (bytemap_data *bytemap, int value, size_t *count);
extern void   bytemap_copy           (bytemap_data *source, bytemap_data *target, size_t *count);
              
extern int    bytemap_has_byte_gray  (bytemap_data *bytemap, int s);
extern int    bytemap_has_byte_range (bytemap_data *bytemap, int min, int max);
extern int    bytemap_has_byte_rgb   (bytemap_data *bytemap, int r, int g, int b);

/*tex We assume that bytemap has a value and we hope for inlining. */

extern void   bytemap_set_gray       (bytemap_data *bytemap, int x, int y, int s);
extern void   bytemap_set_rgb        (bytemap_data *bytemap, int x, int y, int r, int g, int b);

/*tex beware: returns an allocated copy*/

extern int    bytemap_get_byte       (bytemap_data *bytemap, int x, int y, int z);
extern void   bytemap_get_bytes      (bytemap_data *bytemap, int x, int y, unsigned char *b1, unsigned char *b2, unsigned char *b3);
extern char * bytemap_get_value      (bytemap_data *bytemap, int *nx, int *ny, int *nz);

extern void   bytemap_downsample     (bytemap_data *source, bytemap_data *target, int r);

# endif
