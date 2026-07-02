/*
    See license.txt in the root of this project.
*/

# ifndef LUAZBUFFERLIB_H
# define LUAZBUFFERLIB_H

# ifdef LMT_ZBUFFER_FLOAT_RGB
    typedef float  zcolor;     /* some 5 % runtime, and way less memory */
    typedef float  zstipp;
# else
    typedef double zcolor;
    typedef double zstipp;
# endif

typedef pointsdata *points;

typedef struct zbuffervector {
    double x;
    double y;
    double z;
} zbuffervector;

typedef struct zbuffercolor {
    zcolor r;
    zcolor g;
    zcolor b;
} zbuffercolor;

typedef struct zbuffertexture {
    double x; /* could be a float */
    double y; /* could be a float */
    double z; /* could be a float */
    int    t; /* texture identifier */
} zbuffertexture;

typedef enum zbuffervectorstates {
    zbuffer_vector_state_visible   = 0x01,
    zbuffer_vector_state_behind    = 0x02,
    zbuffer_vector_state_hasnormal = 0x04,
} zbuffervectorstates;

typedef struct zbuffervectorn {
    double x;
    double y;
    double z;
    double nx;
    double ny;
    double nz;
    double vx;
    double vy;
    double vz;
    double sx;
    double sy;
    int     state;
 // int     padding;
} zbuffervectorn;

# define zbuffer_maxnoffragments 128
# define zstipple_maxnoflevels    16
# define zstipple_minnoflevels     3

typedef struct zstippledata {
    int    radius;
    double value;
    zcolor red;
    zcolor green;
    zcolor blue;
} zstippledata;

typedef enum zbufferstates {
    zbuffer_target_set = 0x01,
} zbufferstates;

typedef struct zbuffersetup {
    struct {
        zbuffervector right;
        zbuffervector up;
        zbuffervector forward;
        zbuffervector eye;
        zbuffervector target;
        zbuffervector ortho;
    } projection;
    /* */
    struct {
        zbuffercolor diffuse;
        zbuffercolor specular;
        double       shininess;
        double       ambient;
        double       opacity; // zcolor
        double       dx;
        double       dy;
        double       depth;
        int          twosided;
        int          texture;
    } material;
    /* */
    struct {
        zbuffervector direction;
        double        intensity;
        zbuffervector normal;
    } light;
    /* */
    int perspective;
    int usespecular;
    int state;
    /* */
    struct {
        double x;
        double y;
        double scale;
    } transform;
    /* */
    struct {
        double       width;
        double       height;
        int          xmin;
        int          xmax;
        int          ymin;
        int          ymax;
        int          supersample;
        int          maxfragment;
        int          done;
        zbuffercolor backgroundcolor;
    } viewport;
    /* */
    struct {
        double nearby;
        double faraway;
        double scale;
        double tanhalf;
    } camera;
    /* */
    struct {
        int          usenormal;
        int          nobackground;
        zbuffercolor backgroundcolor;
        zbuffercolor color;
        double       creaseangle;
        double       sameangle;
        double       dzsamemultiplier;
        double       dzedgemultiplier;
        double       mindepthstep;
        zbuffercolor luminance;
        double       edgeboost;
        double       coveragegamma;
        double       minimumcoverage;
        double       maximumcoverage;
        int          serpentine;
        double       errorthreshold;
        int          dotradius;
        int          clipdots;
        zstippledata levels[zstipple_maxnoflevels];
        int          noflevels;
        int          tonedots;
        int          outline;
        double       outlinethreshold;
        int          outlineradius;
        /* internal */
        double       dzsame;
        double       dzedge;
        double       median;
        double       cossame;
        double       coscrease;
    } stipple;
} zbuffersetup;

typedef struct zbufferentry {
    struct {
        double depth;
        zcolor red;
        zcolor green;
        zcolor blue;
        zcolor opacity;
        double nx;
        double ny;
        double nz;
    };
} zbufferentry;

typedef zbufferentry *zentry;

typedef struct zbufferstipple {
    struct {
        zstipp coverage;
        zstipp error;
        zstipp edge;
        zstipp intensity;
    };
} zbufferstipple;

typedef zbufferstipple *zstipple;

typedef struct zbufferstackentry {
    struct {
        double depth;
        zcolor red;
        zcolor green;
        zcolor blue;
        zcolor opacity;
    };
} zbufferstackentry;

typedef zbufferstackentry *zstackentry;

typedef struct zbufferstack {
    unsigned short     size;
    unsigned short     last;
    zbufferstackentry *data;
} zbufferstack;

typedef struct zbufferdata {
    int             rows;
    int             columns;
    int             size;
    int             composed;
    zbuffersetup    setup;
    zbufferstack   *stack;
    zbufferentry   *data;
    zbufferstipple *stipple;
    zbuffertexture *texture;
    size_t          stackbytes;
    size_t          databytes;
    size_t          stipplebytes;
    size_t          texturebytes;
    size_t          recordbytes;
} zbufferdata;

typedef zbufferdata *zbuffer;

typedef enum zbuffer_point_methods {
    connect_points_method  = 0x00,
    isolated_points_method = 0x01,
    segment_points_method  = 0x02,
    axis_points_method     = 0x03, /* not used yet, so 0x00 */
    stitch_points_method   = 0x04, /* just use 0x00 */
} zbuffer_point_methods;

# endif
