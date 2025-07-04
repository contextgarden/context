/*
    See license.txt in the root of this project.
*/

# ifndef LNVECTORLIB_H
# define LNVECTORLIB_H

/* 

    We could use unsigned for rows and columns but it is more work and although it might be a bit 
    more efficient for now we stick to int. We assume sane vectors so the next maxima are actually
    already over the top. 

*/

# define max_vector_rows     0x00FFFFFF /* we can have many rows if we use vectors for graphic but still ... */
# define max_vector_columns  0x00FFFFFF /* normally there are only a few columns involved so ... */
# define max_vector          0x0FFFFFFF /* so we stay way below |max_vector_rows * max_vector_columns| */

typedef enum vector_classification {
    generic_type,
    zero_type,
    identity_type,     // definer product
    translation_type,  // definer product inverse determinant
    scaling_type,      // definer product inverse determinant
    rotation_type,     // definer product inverse determinant
    affine_type,       // definer product inverse determinant
} vector_classification;

typedef struct vectordata {
    int    rows;
    int    columns;
    int    type;
    int    stacking;
    int    index;
    int    padding;
    double data[1];
} vectordata;

typedef vectordata *vector;

# define max_mesh 0xFFFF

typedef enum mesh_classification {
    triangle_mesh_type,     
    quad_mesh_type,     
} mesh_classification;

typedef struct meshentry {
    unsigned short points[4];
    double         average;
} meshentry;

typedef struct meshdata {
    int       rows;
    int       type;
    meshentry data[1];
} meshdata;

typedef meshdata *mesh;

extern vector vectorlib_get (lua_State *L, int index);

# endif
