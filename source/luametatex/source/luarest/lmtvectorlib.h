/*
    See license.txt in the root of this project.
*/

# ifndef LUAVECTORLIB_H
# define LUAVECTORLIB_H

/* 

    We could use unsigned for rows and columns but it is more work and although it might be a bit 
    more efficient for now we stick to int. We assume sane vectors so the next maxima are actually
    already over the top. 

*/

# define max_vector_rows     24000000 /* we can have many rows if we use vectors for graphic but still ... */
# define max_vector_columns  24000000 /* normally there are only a few columns involved so ... */
# define max_vector         240000000 /* so we stay way below |max_vector_rows * max_vector_columns| */

typedef enum vector_classification {
    generic_type,
    zero_type,
    identity_type,     // definer product
    translation_type,  // definer product inverse determinant
    scaling_type,      // definer product inverse determinant
    rotation_type,     // definer product inverse determinant
    affine_type,       // definer product inverse determinant
    points_type,
    point_type,
} vector_classification;

typedef struct vectordata {
    int    rows;
    int    columns;
    int    type;
    int    stacking;
    int    index;
    int    size;
    double data[1];
} vectordata;

typedef vectordata *vector;

# define max_mesh 4 * 1024 * 1024

typedef enum mesh_classification {
    no_mesh_type         = 0x00,
    dot_mesh_type        = 0x01,
    line_mesh_type       = 0x02,
    triangle_mesh_type   = 0x03,
    quad_mesh_type       = 0x04,
    /* these are virtual that is: point indices calculated on demand */
    triangle_5_mesh_type = 0x05,  /* [ 1 2 3 ] [ 4 5 6 ] */
    triangle_6_mesh_type = 0x06,  /* [ u / v ]  */
    triangle_7_mesh_type = 0x07,  /* [ 1 2 3 ] [ 1 3 4 ] */
} mesh_classification;

# define virtual_mesh_type(t) (t > quad_mesh_type)

typedef struct meshdata {
    int        size;
    int        type;
    /* used for virtual meshes */
    int        rows;
    int        columns;
    /* */
    int        index;
    int        dimension;
    /* */
    double    *average;
    unsigned  *points;
    /* */
    size_t     averagebytes;
    size_t     pointsbytes;
} meshdata;

typedef meshdata *mesh;

typedef struct pointdata {
    double x;
    double y;
    double z;
    double nx;
    double ny;
    double nz;
    /* do we actually use these */
 // double u;
 // double v;
} pointdata;

typedef pointdata *point;

typedef struct pointsdata {
    int    rows;
    int    columns;
    int    type;
    int    stacking;
    int    index;
    int    size;
    point  data;
    size_t bytes;
} pointsdata;

typedef pointsdata *points;

/*tex

    In |lmtzbufferlib| we depend on this library so we have to provide a minimal set of helpers for
    that one. The memory helpers are somewhat inefficient but we need it because zbuffers take a
    lot memory. We can always comment the calls.

*/

extern vector   vectorlib_get                      (lua_State *L, int index);

extern mesh     vectorlib_mesh_aux_get             (lua_State *L, int index);
extern int      vectorlib_contour_aux_makemesh     (lua_State *L, int columns, int rows, int type);
extern points   vectorlib_points_aux_get           (lua_State *L, int index);
extern points   vectorlib_points_aux_push          (lua_State *L, int r, int c, int wipe);
extern int      vectorlib_points_aux_grow          (lua_State *L, points p, int step);

extern int      vectorlib_mesh_aux_get_points_okay (const mesh triangles, const points vertices, int index, int t[3]);
extern void     vectorlib_mesh_aux_get_points      (const mesh triangles, int index, int t[3]);

extern void   * vectorlib_memory_malloc            (size_t n);
extern void   * vectorlib_memory_realloc           (void *p, size_t n, size_t m);
extern void   * vectorlib_memory_calloc            (size_t n, size_t m);
extern void     vectorlib_memory_free              (void * p, size_t n);

# endif
