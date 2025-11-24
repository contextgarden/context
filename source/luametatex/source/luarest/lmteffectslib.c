/*
    See license.txt in the root of this project.
*/

/*tex

   Here we collect some graphical effects we like to play with and that can make documents more
   attractive.

   We start with perlin like noise as explored by Keith McKay who discussed it in articles and
   presentations. These are part of the (*luameta)fun explorations.

*/

# include <math.h>

# include <luametatex.h>

/*tex

    Perlin noise:

        https://mrl.cs.nyu.edu/~perlin/noise/

    Also discussed in:

        https://github.com/stegu/noiseisbeautiful/tree/main?tab=readme-ov-file
        https://adrianb.io/2014/08/09/perlinnoise.html

    Simplex noise:

        https://github.com/stegu/perlin-noise.git

    The simplex code is derived from code by Stefan Gustavson, 2003-2005 and is released
    in the public domain (GPL until 2011). Comment by Stefan:

        This implementation is "Simplex Noise" as presented by Ken Perlin at a relatively
        obscure and not often cited course session "Real-Time Shading" at Siggraph 2001
        (before real time shading actually took off), under the title "hardware noise".
        The 3D function is numerically equivalent to his Java reference code available in
        the PDF course notes, although I re-implemented it from scratch to get more readable
        code. The 1D, 2D and 4D cases were implemented from scratch by me from Ken Perlin's
        text.

    Searching the web will bring you to more documents and articles by Stefan, including 
    mesmerizing examples.   
    
    Note: 

    We kept our version of the perlin noise but might try the other variant that has no
    recursion. We also use the permutation table that we already entered and share that 
    between the functions.

    Interfacing:

    More details can be found in the \LUAMETAFUN\ manual, articles and examples. We hook the 
    noice generators into \METAPOST\ via \LUA. 
    
    I wanted to get the terminology right so searched a bit and saw these comments in as
    answer on https://gamedev.stackexchange.com/ (message 197861):

        Persistence (also called gain) is a value in the range (0, 1) that controls how 
        quickly the later octaves "die out". Something around 0.5 is pretty conventional 
        here.

        Lacunarity is a value greater than 1 that controls how much finer a scale each 
        subsequent octave should use. Something around 2.0 is a conventional choice.

    So we replaces "scale" in our code by "lacunarity" because it sounds better and is 
    less confusing. 

    There are a few more optimizations (for instance precalculated sin and cos) and we might 
    at some point pass a struct instead of individual parameters / variables. 

    Authors: 

    Keith McKay
    Mikael Sundqvist
    Hans Hagen

*/

/*

    We use an byte table so that the binary doesn't grow by more Kbytes than needed. After
    all, keeping the binary small is a LuaMetaTeX objective. I don't expect a difference in
    performance on modern architectures and compilers.

*/

static const unsigned char pmap[512] = {
    151, 160, 137,  91,  90,  15, 131,  13, 201,  95,  96,  53, 194, 233,   7, 225,
    140,  36, 103,  30,  69, 142,   8,  99,  37, 240,  21,  10,  23, 190,   6, 148,
    247, 120, 234,  75,   0,  26, 197,  62,  94, 252, 219, 203, 117,  35,  11,  32,
     57, 177,  33,  88, 237, 149,  56,  87, 174,  20, 125, 136, 171, 168,  68, 175,
     74, 165,  71, 134, 139,  48,  27, 166,  77, 146, 158, 231,  83, 111, 229, 122,
     60, 211, 133, 230, 220, 105,  92,  41,  55,  46, 245,  40, 244, 102, 143,  54,
     65,  25,  63, 161,   1, 216,  80,  73, 209,  76, 132, 187, 208,  89,  18, 169,
    200, 196, 135, 130, 116, 188, 159,  86, 164, 100, 109, 198, 173, 186,   3,  64,
     52, 217, 226, 250, 124, 123,   5, 202,  38, 147, 118, 126, 255,  82,  85, 212,
    207, 206,  59, 227,  47,  16,  58,  17, 182, 189,  28,  42, 223, 183, 170, 213,
    119, 248, 152,   2,  44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172,   9,
    129,  22,  39, 253,  19,  98, 108, 110,  79, 113, 224, 232, 178, 185, 112, 104,
    218, 246,  97, 228, 251,  34, 242, 193, 238, 210, 144,  12, 191, 179, 162, 241,
     81,  51, 145, 235, 249,  14, 239, 107,  49, 192, 214,  31, 181, 199, 106, 157,
    184,  84, 204, 176, 115, 121,  50,  45, 127,   4, 150, 254, 138, 236, 205,  93,
    222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180,
    /*tex We just copy so we don't need to initialize with a loop then. */
    151, 160, 137,  91,  90,  15, 131,  13, 201,  95,  96,  53, 194, 233,   7, 225,
    140,  36, 103,  30,  69, 142,   8,  99,  37, 240,  21,  10,  23, 190,   6, 148,
    247, 120, 234,  75,   0,  26, 197,  62,  94, 252, 219, 203, 117,  35,  11,  32,
     57, 177,  33,  88, 237, 149,  56,  87, 174,  20, 125, 136, 171, 168,  68, 175,
     74, 165,  71, 134, 139,  48,  27, 166,  77, 146, 158, 231,  83, 111, 229, 122,
     60, 211, 133, 230, 220, 105,  92,  41,  55,  46, 245,  40, 244, 102, 143,  54,
     65,  25,  63, 161,   1, 216,  80,  73, 209,  76, 132, 187, 208,  89,  18, 169,
    200, 196, 135, 130, 116, 188, 159,  86, 164, 100, 109, 198, 173, 186,   3,  64,
     52, 217, 226, 250, 124, 123,   5, 202,  38, 147, 118, 126, 255,  82,  85, 212,
    207, 206,  59, 227,  47,  16,  58,  17, 182, 189,  28,  42, 223, 183, 170, 213,
    119, 248, 152,   2,  44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172,   9,
    129,  22,  39, 253,  19,  98, 108, 110,  79, 113, 224, 232, 178, 185, 112, 104,
    218, 246,  97, 228, 251,  34, 242, 193, 238, 210, 144,  12, 191, 179, 162, 241,
     81,  51, 145, 235, 249,  14, 239, 107,  49, 192, 214,  31, 181, 199, 106, 157,
    184,  84, 204, 176, 115, 121,  50,  45, 127,   4, 150, 254, 138, 236, 205,  93,
    222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180,
};

/*tex

    Originally we had perlin noise codes in \LUA\ and the next is more of less the
    same as we had there.

*/

static inline double fade(double t)
{
    return t * t * t * (t * (t * 6 - 15) + 10);
}

static inline double lerp(double t, double a, double b)
{
    return a + t * (b - a);
}

/*
    Convert the lower 4 bits of hash code into 12 gradient directions:
*/

static double grad(int hash, double x, double y, double z) /* we can avoid one h check */
{
   int h = hash & 15;
   double u = h < 8 ? x : y;
   double v = h < 4 ? y : h == 12 || h == 14 ? x : z;
   return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
}

static double effectslib_perlin_noise_3(double x, double y, double z)
{
    /* Find unit cube that contains point: */
    int X = lfloor(x) & 0xFF;
    int Y = lfloor(y) & 0xFF;
    int Z = lfloor(z) & 0xFF;
    /* Find relative x,y,z of point in cube: */
    x -= floor(x);
    y -= floor(y);
    z -= floor(z);
    /* Compute fade curves for each of x, y, z: */
    double u = fade(x);
    double v = fade(y);
    double w = fade(z);
    /* Hash coordinates of the 8 cube corners: */
    int A = pmap[X  ] + Y; int AA = pmap[A] + Z; int AB = pmap[A+1] + Z;
    int B = pmap[X+1] + Y; int BA = pmap[B] + Z; int BB = pmap[B+1] + Z;
    /* Add blended results from  8 corners of cube: */
    return lerp(w, lerp(v, lerp(u, grad(pmap[AA  ], x  , y  , z  ),
                                   grad(pmap[BA  ], x-1, y  , z  )),
                           lerp(u, grad(pmap[AB  ], x  , y-1, z  ),
                                   grad(pmap[BB  ], x-1, y-1, z  ))),
                   lerp(v, lerp(u, grad(pmap[AA+1], x  , y  , z-1),
                                   grad(pmap[BA+1], x-1, y  , z-1)),
                           lerp(u, grad(pmap[AB+1], x  , y-1, z-1),
                                   grad(pmap[BB+1], x-1, y-1, z-1))));
}

static int effectslib_perlinnoise(lua_State *L)
{
    double x = lua_tonumber(L, 1);
    double y = lua_tonumber(L, 2);
    double z = lua_type(L, 3) == LUA_TNUMBER ? lua_tonumber(L, 3) : 0.0;
    lua_push_number(L, effectslib_perlin_noise_3(x, y, z));
    return 1;
}

/*tex

    Original comment by Stefan:

    Helper functions to compute gradients-dot-residualvectors (1D to 4D). Note that these generate
    gradients of more than unit length. To make a close match with the value range of classic
    Perlin noise, the final noise values need to be rescaled to fit nicely within [-1,1]. The
    simplex noise functions as such also have different scaling.)  Note also that these noise
    functions are the most practical and useful signed version of Perlin noise. To return values
    according to the RenderMan specification from the |SLnoise()| and |pnoise()| functions, the
    noise values need to be scaled and offset to [0,1], like this: |float SLnoise = (noise(x, y, z)
    + 1.0) * 0.5;|.

*/

/*tex

    The code has been adapted to doubles because that's what we use all over the place. I also
    reformatted it a bit. Is nowadays |FASTFLOOR| still faster than lfloor? Casting also comes
    at a price.
*/

/* # define FASTFLOOR(x) ( ((int) (x) <= (x)) ? ((int) x) : (((int) x) - 1) ) */

inline int FASTFLOOR(double x) {
    return (int) (x) <= x ? (int) x : (int) x - 1;
}

/*
    We get a gradient value 1.0, 2.0, ..., 8.0 with a random sign, multiplied with the distance.
*/

static inline double grad1(int hash, double x)
{
    int h = hash & 15;
    double grad = 1.0 + (h & 7);
    if (h & 8) {
        grad = -grad;
    }
    return grad * x;
}

/*
    Convert low 3 bits of hash code into 8 simple gradient directions and compute the dot product
    with (x,y).
*/

static inline double grad2(int hash, double x, double y)
{
    int h = hash & 7;
    double u = h < 4 ? x : y;
    double v = h < 4 ? y : x;
    return ((h & 1) ? -u : u) + ((h & 2) ? -2.0 * v : 2.0 * v);
}

/*
    Convert low 4 bits of hash code into 12 simple gradient directions and compute dot product.
*/

static inline double grad3(int hash, double x, double y , double z)
{
    int h = hash & 15;
    double u = h < 8 ? x : y;
    double v = h < 4 ? y : h == 12 || h == 14 ? x : z; // Fix repeats at h = 12 to 15
    return ((h & 1) ? -u : u) + ((h & 2) ? -v : v);
}

/*
    Convert low 5 bits of hash code into 32 simple gradient directions and compute dot product.
*/

static inline double grad4(int hash, double  x, double y, double z, double t)
{
    int h = hash & 31;
    double u = h<24 ? x : y;
    double v = h<16 ? y : z;
    double w = h<8 ? z : t;
    return ((h & 1) ? -u : u) + ((h & 2) ? -v : v) + ((h & 4) ? -w : w);
}

/*
    A lookup table to traverse the simplex around a given point in 4D. Details can be
    found where this table is used, in the 4D noise method.
*/

static unsigned char simplex[64][4] = {
    {0,1,2,3}, {0,1,3,2}, {0,0,0,0}, {0,2,3,1}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {1,2,3,0},
    {0,2,1,3}, {0,0,0,0}, {0,3,1,2}, {0,3,2,1}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {1,3,2,0},
    {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0},
    {1,2,0,3}, {0,0,0,0}, {1,3,0,2}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {2,3,0,1}, {2,3,1,0},
    {1,0,2,3}, {1,0,3,2}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {2,0,3,1}, {0,0,0,0}, {2,1,3,0},
    {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0},
    {2,0,1,3}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {3,0,1,2}, {3,0,2,1}, {0,0,0,0}, {3,1,2,0},
    {2,1,0,3}, {0,0,0,0}, {0,0,0,0}, {0,0,0,0}, {3,1,0,2}, {0,0,0,0}, {3,2,0,1}, {3,2,1,0}
};

/*tex
    There are four variants of the simplex noise generator.
*/

/*
    The maximum value of this noise is 8*(3/4)^4 = 2.53125. A factor of 0.395 would scale to fit
    exactly within [-1,1], but we want to match PRMan's 1D noise, so we scale it down some more.
*/

static double effectslib_simplex_noise_1(double x)
{
    int i0 = FASTFLOOR(x);
    int i1 = i0 + 1;
    double n0, n1;
    double x0 = x - i0;
    double x1 = x0 - 1.0;
    double t0 = 1.0 - x0 * x0;
    double t1 = 1.0 - x1 * x1;
    t0 *= t0;
    t1 *= t1;
    n0 = t0 * t0 * grad1(pmap[ i0 & 0xFF ], x0);
    n1 = t1 * t1 * grad1(pmap[ i1 & 0xFF ], x1);
    return 0.25 * (n0 + n1);
}

# define F2 0.366025403 // F2 = 0.5*(sqrt(3.0)-1.0)
# define G2 0.211324865 // G2 = (3.0-Math.sqrt(3.0))/6.0

static double effectslib_simplex_noise_2(double x, double y)
{
    /* noise contributions from the three corners */
    double n0, n1, n2;
    /* skew the input space to determine which simplex cell we're in */
    double s = (x + y) * F2;
    double xs = x + s;
    double ys = y + s;
    int i = FASTFLOOR(xs);
    int j = FASTFLOOR(ys);
    double t = (double) (i + j) * G2;
    /* unskew the cell origin back to (x,y) space */
    double X0 = i - t;
    double Y0 = j - t;
    /* the x,y distances from the cell origin */
    double x0 = x - X0;
    double y0 = y - Y0;
    /*
        For the 2D case, the simplex shape is an equilateral triangle. Determine which simplex we
        are in. Offsets for second (middle) corner of simplex in (i,j) coordinates:
    */
    int i1, j1;
    if (x0 > y0) {
        /* lower triangle, XY order: (0,0)->(1,0)->(1,1) */
        i1 = 1;
        j1 = 0;
    } else {
        /* upper triangle, YX order: (0,0)->(0,1)->(1,1) */
        i1 = 0;
        j1 = 1;
    }
    /*
        A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and a step of (0,1) in (i,j)
        means a step of (-c,1-c) in (x,y), where c = (3-sqrt(3))/6
    */
    /* offsets for middle corner in (x,y) unskewed coords */
    double x1 = x0 - i1 + G2;
    double y1 = y0 - j1 + G2;
    /* offsets for last corner in (x,y) unskewed coords */
    double x2 = x0 - 1.0 + 2.0 * G2;
    double y2 = y0 - 1.0 + 2.0 * G2;
    /* wrapped integer indices at 256, to avoid indexing pmap[] out of bounds */
    int ii = i & 0xFF;
    int jj = j & 0xFF;
    /* calculate the contribution from the three corners */
    double t0 = 0.5 - x0 * x0 - y0 * y0;
    double t1 = 0.5 - x1 * x1 - y1 * y1;
    double t2 = 0.5 - x2 * x2 - y2 * y2;
    if (t0 < 0.0) {
        n0 = 0.0;
    } else {
        t0 *= t0;
        n0 = t0 * t0 * grad2(pmap[ ii + pmap[ jj ] ], x0, y0);
    }
    if (t1 < 0.0) {
        n1 = 0.0;
    } else {
        t1 *= t1;
        n1 = t1 * t1 * grad2(pmap[ ii + i1 + pmap[ jj + j1 ] ], x1, y1);
    }
    if (t2 < 0.0) {
        n2 = 0.0;
    } else {
        t2 *= t2;
        n2 = t2 * t2 * grad2(pmap[ ii + 1 + pmap[ jj + 1 ] ], x2, y2);
    }
    /*
        Add contributions from each corner to get the final noise value. The result is scaled to
        return values in the interval [-1,1]. TODO: The scale factor is preliminary!
    */
    return 40.0 * (n0 + n1 + n2);
}

# define F3 0.333333333
# define G3 0.166666667

static double effectslib_simplex_noise_3(double x, double y, double z)
{
    /* simple skewing factors for the 3D case; noise contributions from the four corners */
    double n0, n1, n2, n3;
    /* skew the input space to determine which simplex cell we're in */
    double s = (x + y + z) * F3;
    double xs = x + s;
    double ys = y + s;
    double zs = z + s;
    int i = FASTFLOOR(xs);
    int j = FASTFLOOR(ys);
    int k = FASTFLOOR(zs);
    double t = (double) (i + j + k) * G3;
    /* unskew the cell origin back to (x,y,z) space */
    double X0 = i - t;
    double Y0 = j - t;
    double Z0 = k - t;
    /* the x,y,z distances from the cell origin */
    double x0 = x - X0;
    double y0 = y - Y0;
    double z0 = z - Z0;
    /*
        For the 3D case, the simplex shape is a slightly irregular tetrahedron. Determine which
        simplex we are in.
    */
    /* offsets for second corner of simplex in (i,j,k) coords */
    int i1, j1, k1;
    /* offsets for third corner of simplex in (i,j,k) coords */
    int i2, j2, k2;
    /* this code would benefit from a backport from the GLSL version */
    if (x0 >= y0) {
        if (y0 >= z0) {
            /* X Y Z order */
            i1 = 1; j1 = 0; k1 = 0;
            i2 = 1; j2 = 1; k2 = 0;
        } else if (x0 >= z0) {
            /* X Z Y order */
            i1 = 1; j1 = 0; k1 = 0;
            i2 = 1; j2 = 0; k2 = 1;
        } else {
            /* Z X Y order */
            i1 = 0; j1 = 0; k1 = 1;
            i2 = 1; j2 = 0; k2 = 1;
        }
    } else {
        if (y0 < z0) {
            /* Z Y X order */
            i1 = 0; j1 = 0; k1 = 1;
            i2 = 0; j2 = 1; k2 = 1;
        } else if (x0 < z0) {
            /* Y Z X order */
            i1 = 0; j1 = 1; k1 = 0;
            i2 = 0; j2 = 1; k2 = 1;
        } else {
            /* Y X Z order */
            i1 = 0; j1 = 1; k1 = 0;
            i2 = 1; j2 = 1; k2 = 0;
        }
    }
    /*
        A step of (1,0,0) in (i,j,k) means a step of (1-c,-c,-c) in (x,y,z),
        a step of (0,1,0) in (i,j,k) means a step of (-c,1-c,-c) in (x,y,z), and
        a step of (0,0,1) in (i,j,k) means a step of (-c,-c,1-c) in (x,y,z), where
        c = 1/6.
    */
    /* offsets for second corner in (x,y,z) coords */
    double x1 = x0 - i1 + G3;
    double y1 = y0 - j1 + G3;
    double z1 = z0 - k1 + G3;
    /* offsets for third corner in (x,y,z) coords */
    double x2 = x0 - i2 + 2.0 * G3;
    double y2 = y0 - j2 + 2.0 * G3;
    double z2 = z0 - k2 + 2.0 * G3;
    /* offsets for last corner in (x,y,z) coords */
    double x3 = x0 - 1.0 + 3.0 * G3;
    double y3 = y0 - 1.0 + 3.0 * G3;
    double z3 = z0 - 1.0 + 3.0 * G3;
    /* wrap the integer indices at 256, to avoid indexing pmap[] out of bounds */
    int ii = i & 0xFF;
    int jj = j & 0xFF;
    int kk = k & 0xFF;
    /* calculate the contribution from the four corners */
    double t0 = 0.5 - x0 * x0 - y0 * y0 - z0 * z0;
    double t1 = 0.5 - x1 * x1 - y1 * y1 - z1 * z1;
    double t2 = 0.5 - x2 * x2 - y2 * y2 - z2 * z2;
    double t3 = 0.5 - x3 * x3 - y3 * y3 - z3 * z3;
    if (t0 < 0.0) {
        n0 = 0.0;
    } else {
        t0 *= t0;
        n0 = t0 * t0 * grad3(pmap[ ii + pmap[ jj + pmap[ kk ] ] ], x0, y0, z0);
    }
    if (t1 < 0.0) {
        n1 = 0.0;
    } else {
        t1 *= t1;
        n1 = t1 * t1 * grad3(pmap[ ii + i1 + pmap[ jj + j1 + pmap[ kk + k1 ] ] ], x1, y1, z1);
    }
    if (t2 < 0.0) {
        n2 = 0.0;
    } else {
        t2 *= t2;
        n2 = t2 * t2 * grad3(pmap[ ii + i2 + pmap[ jj + j2 + pmap[ kk + k2 ] ] ], x2, y2, z2);
    }
    if (t3 < 0.0) {
        n3 = 0.0;
    } else {
        t3 *= t3;
        n3 = t3 * t3 * grad3(pmap[ ii + 1 + pmap[ jj + 1 + pmap[ kk + 1 ] ] ], x3, y3, z3);
    }
    /*
        Add contributions from each corner to get the final noise value. The result is scaled to
        stay just inside [-1,1]
    */
    return 72.0 * (n0 + n1 + n2 + n3);
}

/*
    Original comment:

    For the 4D case, the simplex is a 4D shape I won't even try to describe. To find out which of
    the 24 possible simplices we're in, we need to determine the magnitude ordering of x0, y0, z0
    and w0. The method below is a good way of finding the ordering of x,y,z,w and then find the
    correct traversal order for the simplex we're in. First, six pair-wise comparisons are performed
    between each possible pair of the four coordinates, and the results are used to add up binary bits
    for an integer index.

    In the code below  simplex[c] is a 4-vector with the numbers 0, 1, 2 and 3 in some order. Many
    values of c will never occur, since e.g. x>y>z>w makes x<z, y<w and x < w impossible. Only the 24
    indices which have non-zero entries make any sense. We use a thresholding to set the coordinates
    in turn from the largest magnitude. The number 3 in the "simplex" array is at the position of the
    largest coordinate.

    The skewing and unskewing factors are hairy again for the 4D case.

*/

# define F4 0.309016994 // F4 = (Math.sqrt(5.0)-1.0)/4.0
# define G4 0.138196601 // G4 = (5.0-Math.sqrt(5.0))/20.0

static double effectslib_simplex_noise_4(double x, double y, double z, double w)
{
    /* noise contributions from the five corners */
    double n0, n1, n2, n3, n4;
    /* skew the (x,y,z,w) space to determine which cell of 24 simplices we're in */
    double s = (x + y + z + w) * F4;
    double xs = x + s;
    double ys = y + s;
    double zs = z + s;
    double ws = w + s;
    int i = FASTFLOOR(xs);
    int j = FASTFLOOR(ys);
    int k = FASTFLOOR(zs);
    int l = FASTFLOOR(ws);
    /* factor for 4D unskewing */
    double t = (i + j + k + l) * G4;
    /* unskew the cell origin back to (x,y,z,w) space */
    double X0 = i - t;
    double Y0 = j - t;
    double Z0 = k - t;
    double W0 = l - t;
    /* the x,y,z,w distances from the cell origin */
    double x0 = x - X0;
    double y0 = y - Y0;
    double z0 = z - Z0;
    double w0 = w - W0;
    /* */
    int c1 = (x0 > y0) ? 32 : 0;
    int c2 = (x0 > z0) ? 16 : 0;
    int c3 = (y0 > z0) ? 8 : 0;
    int c4 = (x0 > w0) ? 4 : 0;
    int c5 = (y0 > w0) ? 2 : 0;
    int c6 = (z0 > w0) ? 1 : 0;
    int c = c1 + c2 + c3 + c4 + c5 + c6;
    /* the integer offsets for the second, third and fourth simplex corners */
    int i1, j1, k1, l1;
    int i2, j2, k2, l2;
    int i3, j3, k3, l3;
    /* see comment above */
    i1 = simplex[c][0] >= 3 ? 1 : 0;
    j1 = simplex[c][1] >= 3 ? 1 : 0;
    k1 = simplex[c][2] >= 3 ? 1 : 0;
    l1 = simplex[c][3] >= 3 ? 1 : 0;
    /* the number 2 in the "simplex" array is at the second largest coordinate */
    i2 = simplex[c][0] >= 2 ? 1 : 0;
    j2 = simplex[c][1] >= 2 ? 1 : 0;
    k2 = simplex[c][2] >= 2 ? 1 : 0;
    l2 = simplex[c][3] >= 2 ? 1 : 0;
    /* the number 1 in the "simplex" array is at the second smallest coordinate */
    i3 = simplex[c][0] >= 1 ? 1 : 0;
    j3 = simplex[c][1] >= 1 ? 1 : 0;
    k3 = simplex[c][2] >= 1 ? 1 : 0;
    l3 = simplex[c][3] >= 1 ? 1 : 0;
    /* the fifth corner has all coordinate offsets = 1, so no need to look that up */
    /* */
    /* offsets for second corner in (x,y,z,w) coords */
    double x1 = x0 - i1 + G4;
    double y1 = y0 - j1 + G4;
    double z1 = z0 - k1 + G4;
    double w1 = w0 - l1 + G4;
    /* offsets for third corner in (x,y,z,w) coords */
    double x2 = x0 - i2 + 2.0 * G4;
    double y2 = y0 - j2 + 2.0 * G4;
    double z2 = z0 - k2 + 2.0 * G4;
    double w2 = w0 - l2 + 2.0 * G4;
    /* offsets for fourth corner in (x,y,z,w) coords. */
    double x3 = x0 - i3 + 3.0 * G4;
    double y3 = y0 - j3 + 3.0 * G4;
    double z3 = z0 - k3 + 3.0 * G4;
    double w3 = w0 - l3 + 3.0 * G4;
    /* offsets for last corner in (x,y,z,w) coords. */
    double x4 = x0 - 1.0 + 4.0 * G4;
    double y4 = y0 - 1.0 + 4.0 * G4;
    double z4 = z0 - 1.0 + 4.0 * G4;
    double w4 = w0 - 1.0 + 4.0 * G4;
    /* Wrap the integer indices at 256, to avoid indexing pmap[] out of bounds */
    int ii = i & 0xFF;
    int jj = j & 0xFF;
    int kk = k & 0xFF;
    int ll = l & 0xFF;
    /* calculate the contribution from the five corners */
    double t0 = 0.5 - x0 * x0 - y0 * y0 - z0 * z0 - w0 * w0;
    double t1 = 0.5 - x1 * x1 - y1 * y1 - z1 * z1 - w1 * w1;
    double t2 = 0.5 - x2 * x2 - y2 * y2 - z2 * z2 - w2 * w2;
    double t3 = 0.5 - x3 * x3 - y3 * y3 - z3 * z3 - w3 * w3;
    double t4 = 0.5 - x4 * x4 - y4 * y4 - z4 * z4 - w4 * w4;
    if (t0 < 0.0) {
        n0 = 0.0;
    } else {
        t0 *= t0;
        n0 = t0 * t0 * grad4(pmap[ ii + pmap[ jj + pmap[ kk + pmap[ ll ] ] ] ], x0, y0, z0, w0);
    }
    if (t1 < 0.0) {
        n1 = 0.0;
    } else {
        t1 *= t1;
        n1 = t1 * t1 * grad4(pmap[ ii + i1 + pmap[ jj + j1 + pmap[ kk + k1 + pmap[ ll + l1 ] ] ] ], x1, y1, z1, w1);
    }
    if (t2 < 0.0) {
        n2 = 0.0;
    } else {
        t2 *= t2;
        n2 = t2 * t2 * grad4(pmap[ ii + i2 + pmap[ jj + j2 + pmap[ kk + k2 + pmap[ ll + l2 ] ] ] ], x2, y2, z2, w2);
    }
    if(t3 < 0.0) {
        n3 = 0.0;
    } else {
        t3 *= t3;
        n3 = t3 * t3 * grad4(pmap[ ii + i3 + pmap[ jj + j3 + pmap[ kk + k3 + pmap[ ll + l3 ] ] ] ], x3, y3, z3, w3);
    }
    if (t4 < 0.0) {
        n4 = 0.0;
    } else {
        t4 *= t4;
        n4 = t4 * t4 * grad4(pmap[ ii + 1 + pmap[ jj + 1 + pmap[ kk + 1 + pmap[ ll + 1 ] ] ] ], x4, y4, z4, w4);
    }
    /* sum up and scale the result to cover the range [-1,1] */
    return 62.0 * (n0 + n1 + n2 + n3 + n4);
}

/* 
    The code is a bit adapted and made a bit more conistent with the rest. Like NULL testing and 
    clipping & 0xFF vs % 256). We also went double. 
*/

/*
    This is an implementation of Perlin "simplex noise" over two dimensions (x,y) and three 
    dimensions (x,y,z). One extra parameter 't' rotates the underlying gradients of the grid, 
    which gives a swirling, flow-like motion. The derivative is returned, to make it possible 
    to do pseudo-advection and implement "flow noise", as presented by Ken Perlin and Fabrice 
    Neyret at Siggraph 2001. When not animated and presented in one octave only, this noise
    looks exactly the same as the plain version of simplex noise.

    It's nothing magical by itself, although the extra animation parameter 't' is useful. Fun 
    stuff starts to happen when you do fractal sums of several octaves, with different rotation 
    speeds and an advection of smaller scales by larger scales (or even the other way around it
    you feel adventurous).

    The gradient rotations that can be performed by this noise function and the true analytic
    derivatives are required to do flow noise. You can't do it properly with regular Perlin 
    noise. The 3D version is my own creation. It's a hack, because unlike the 2D version the 
    gradients rotate around different axes, and therefore they don't remain uncorrelated through
    the rotation, but it looks OK.
*/

/*
    Gradient tables. These could be programmed the Ken Perlin way with some clever bit-twiddling, 
    but this is more clear, and not really slower.
*/

static double grad2m[8][2] = {
    { -1.0, -1.0 }, { 1.0,  0.0 }, { -1.0, 0.0 }, { 1.0,  1.0 },
    { -1.0,  1.0 }, { 0.0, -1.0 }, {  0.0, 1.0 }, { 1.0, -1.0 },
};

/*
    For 3D, we define two orthogonal vectors in the desired rotation plane. These vectors are based
    on the midpoints of the 12 edges of a cube, they all rotate in their own plane and are never 
    coincident or collinear. A larger array of random vectors would also do the job, but these 12
    (including 4 repeats to make the array length a power of two) work better. They are not random, 
    they are carefully chosen to represent a small isotropic set of directions for any rotation 
    angle.
*/

# define a 0.81649658f /* a = sqrt(2)/sqrt(3) = 0.816496580 */

static double grad3u[16][3] = {
  {  1.0,  0.0,  1.0 }, {  0.0,  1.0,  1.0 }, // 12 cube edges
  { -1.0,  0.0,  1.0 }, {  0.0, -1.0,  1.0 },
  {  1.0,  0.0, -1.0 }, {  0.0,  1.0, -1.0 },
  { -1.0,  0.0, -1.0 }, {  0.0, -1.0, -1.0 },
  {  a,    a,    a   }, { -a,    a,   -a   },
  { -a,   -a,    a   }, {  a,   -a,   -a   },
  { -a,    a,    a   }, {  a,   -a,    a   },
  {  a,   -a,   -a   }, { -a,    a,   -a   },
};

static double grad3v[16][3] = {
  { -a,    a,    a   }, { -a,   -a,    a   },
  {  a,   -a,    a   }, {  a,    a,    a   },
  { -a,   -a,   -a   }, {  a,   -a,   -a   },
  {  a,    a,   -a   }, { -a,    a,   -a   },
  {  1.0, -1.0,  0.0 }, {  1.0,  1.0,  0.0 },
  { -1.0,  1.0,  0.0 }, { -1.0, -1.0,  0.0 },
  {  1.0,  0.0,  1.0 }, { -1.0,  0.0,  1.0 }, // 4 repeats to make 16
  {  0.0,  1.0, -1.0 }, {  0.0, -1.0, -1.0 },
};

# undef a

/*
    Helper functions to compute rotated gradients and gradients-dot-residualvectors in 2D and 3D.
*/

static void gradrot2(int hash, double sin_t, double cos_t, double *gx, double *gy)
{
    int h = hash & 7;
    double gx0 = grad2m[h][0];
    double gy0 = grad2m[h][1];
    *gx = cos_t * gx0 - sin_t * gy0;
    *gy = sin_t * gx0 + cos_t * gy0;
    return;
}

static void gradrot3(int hash, double sin_t, double cos_t, double *gx, double *gy, double *gz)
{
    int h = hash & 15;
    double gux = grad3u[h][0];
    double guy = grad3u[h][1];
    double guz = grad3u[h][2];
    double gvx = grad3v[h][0];
    double gvy = grad3v[h][1];
    double gvz = grad3v[h][2];
    *gx = cos_t * gux + sin_t * gvx;
    *gy = cos_t * guy + sin_t * gvy;
    *gz = cos_t * guz + sin_t * gvz;
    return;
}

static double graddotp2(double gx, double gy, double x, double y)
{
    return gx * x + gy * y;
}

static double graddotp3(double gx, double gy, double gz, double x, double y, double z)
{
    return gx * x + gy * y + gz * z;
}

/*
    If the last two arguments are not null, the analytic derivative (the 2D gradient of the total 
    noise field) is also calculated.
*/

/*tex Most comments have been removed because they are the same as above. */

static double effectslib_simplex_detail_2(double x, double y, double sin_t, double cos_t, double *dx, double *dy)
{
    double n0, n1, n2; /* Noise contributions from the three simplex corners */
    double gx0, gy0, gx1, gy1, gx2, gy2; /* Gradients at simplex corners */
    double s = (x + y) * F2; /* Hairy factor for 2D */
    double xs = x + s;
    double ys = y + s;
    int i = FASTFLOOR(xs);
    int j = FASTFLOOR(ys);
    double t = (double) (i + j) * G2;
    double X0 = i - t;
    double Y0 = j - t;
    double x0 = x - X0;
    double y0 = y - Y0;
    int i1, j1;
    if (x0 > y0) {
        i1 = 1;
        j1 = 0;
    } else {
        i1 = 0;
        j1 = 1;
    }
    double x1 = x0 - i1 + G2;
    double y1 = y0 - j1 + G2;
    double x2 = x0 - 1.0 + 2.0 * G2;
    double y2 = y0 - 1.0 + 2.0 * G2;
    int ii = i & 0xFF;
    int jj = j & 0xFF;
    double t0 = 0.5 - x0 * x0 - y0 * y0;
    double t20, t40;
    if (t0 < 0.0) {
        t40 = t20 = t0 = n0 = gx0 = gy0 = 0.0;
    } else {
        gradrot2(pmap[ ii + pmap[ jj ] ], sin_t, cos_t, &gx0, &gy0);
        t20 = t0 * t0;
        t40 = t20 * t20;
        n0 = t40 * graddotp2(gx0, gy0, x0, y0);
    }
    double t1 = 0.5 - x1 * x1 - y1 * y1;
    double t2 = 0.5 - x2 * x2 - y2 * y2;
    double t21, t41;
    double t22, t42;
    if (t1 < 0.0) {
        t21 = t41 = t1 = n1 = gx1 = gy1 = 0.0;
    } else {
        gradrot2(pmap[ ii + i1 + pmap[ jj + j1 ] ], sin_t, cos_t, &gx1, &gy1);
        t21 = t1 * t1;
        t41 = t21 * t21;
        n1 = t41 * graddotp2(gx1, gy1, x1, y1);
    }
    if (t2 < 0.0) {
        t42 = t22 = t2 = n2 = gx2 = gy2 = 0.0;
    } else {
        gradrot2(pmap[ ii + 1 + pmap[ jj + 1 ] ], sin_t, cos_t, &gx2, &gy2);
        t22 = t2 * t2;
        t42 = t22 * t22;
        n2 = t42 * graddotp2(gx2, gy2, x2, y2);
    }
    double noise = 40.0 * (n0 + n1 + n2);
    if (dx && dy) {
        double temp0 = t20 * t0 * graddotp2(gx0, gy0, x0, y0);
        double temp1 = t21 * t1 * graddotp2(gx1, gy1, x1, y1);
        double temp2 = t22 * t2 * graddotp2(gx2, gy2, x2, y2);
        *dx = temp0 * x0 + temp1 * x1 + temp2 * x2;
        *dy = temp0 * y0 + temp1 * y1 + temp2 * y2;
        *dx *= -8.0;
        *dy *= -8.0;
        *dx += t40 * gx0 + t41 * gx1 + t42 * gx2;
        *dy += t40 * gy0 + t41 * gy1 + t42 * gy2;
        *dx *= 40.0;
        *dy *= 40.0;
    }
    return noise;
}

/*tex Most comments have been removed because they are the same as above. */

static double effectslib_simplex_detail_3(double x, double y, double z, double sin_t, double cos_t, double *dx, double *dy, double *dz)
{
    double n0, n1, n2, n3;
    double noise;
    double gx0, gy0, gz0, gx1, gy1, gz1;
    double gx2, gy2, gz2, gx3, gy3, gz3;
    double s = (x + y + z) * F3;
    double xs = x + s;
    double ys = y + s;
    double zs = z + s;
    int i = FASTFLOOR(xs);
    int j = FASTFLOOR(ys);
    int k = FASTFLOOR(zs);
    double t = (double) (i + j + k) * G3;
    double X0 = i - t;
    double Y0 = j - t;
    double Z0 = k - t;
    double x0 = x - X0;
    double y0 = y - Y0;
    double z0 = z - Z0;
    int i1, j1, k1;
    int i2, j2, k2;
    if (x0 >= y0) {
        if (y0 >= z0) {
            i1 = 1; j1 = 0; k1 = 0;
            i2 = 1; j2 = 1; k2 = 0;
        } else if (x0 >= z0) {
            i1 = 1; j1 = 0; k1 = 0;
            i2 = 1; j2 = 0; k2 = 1;
        } else {
            i1 = 0; j1 = 0; k1 = 1;
            i2 = 1; j2 = 0; k2 = 1;
        }
    } else {
        if (y0 < z0) {
            i1 = 0; j1 = 0; k1 = 1;
            i2 = 0; j2 = 1; k2 = 1;
        } else if (x0 < z0) {
            i1 = 0; j1 = 1; k1 = 0;
            i2 = 0; j2 = 1; k2 = 1;
        } else {
            i1 = 0; j1 = 1; k1 = 0;
            i2 = 1; j2 = 1; k2 = 0;
        }
    }
    double x1 = x0 - i1 + G3;
    double y1 = y0 - j1 + G3;
    double z1 = z0 - k1 + G3;
    double x2 = x0 - i2 + 2.0 * G3;
    double y2 = y0 - j2 + 2.0 * G3;
    double z2 = z0 - k2 + 2.0 * G3;
    double x3 = x0 - 1.0 + 3.0 * G3;
    double y3 = y0 - 1.0 + 3.0 * G3;
    double z3 = z0 - 1.0 + 3.0 * G3;
    int ii = i & 0xFF;
    int jj = j & 0xFF;
    int kk = k & 0xFF;
    double t0 = 0.5 - x0 * x0 - y0 * y0 - z0 * z0;
    double t20, t40;
    if (t0 < 0.0) {
        n0 = t0 = t20 = t40 = gx0 = gy0 = gz0 = 0.0;
    } else {
        gradrot3(pmap[ ii + pmap[ jj + pmap[ kk ] ] ], sin_t, cos_t, &gx0, &gy0, &gz0);
        t20 = t0 * t0;
        t40 = t20 * t20;
        n0 = t40 * graddotp3(gx0, gy0, gz0, x0, y0, z0);
    }
    double t1 = 0.5 - x1*x1 - y1*y1 - z1*z1;
    double t2 = 0.5 - x2*x2 - y2*y2 - z2*z2;
    double t3 = 0.5 - x3*x3 - y3*y3 - z3*z3;
    double t21, t41;
    double t22, t42;
    double t23, t43;
    if (t1 < 0.0) {
        n1 = t1 = t21 = t41 = gx1 = gy1 = gz1 = 0.0;
    } else {
      gradrot3(pmap[ ii + i1 + pmap[ jj + j1 + pmap[ kk + k1 ] ] ], sin_t, cos_t, &gx1, &gy1, &gz1);
      t21 = t1 * t1;
      t41 = t21 * t21;
      n1 = t41 * graddotp3(gx1, gy1, gz1, x1, y1, z1);
    }
    if (t2 < 0.0) {
        n2 = t2 = t22 = t42 = gx2 = gy2 = gz2 = 0.0;
    } else {
        gradrot3(pmap[ ii + i2 + pmap[ jj + j2 + pmap[ kk + k2 ] ] ], sin_t, cos_t, &gx2, &gy2, &gz2);
        t22 = t2 * t2;
        t42 = t22 * t22;
        n2 = t42 * graddotp3(gx2, gy2, gz2, x2, y2, z2);
    }
    if (t3 < 0.0) {
        n3 = t3 = t23 = t43 = gx3 = gy3 = gz3 = 0.0;
    } else {
        gradrot3(pmap[ ii + 1 + pmap[ jj + 1 + pmap[ kk + 1 ] ] ], sin_t, cos_t, &gx3, &gy3, &gz3);
        t23 = t3 * t3;
        t43 = t23 * t23;
        n3 = t43 * graddotp3(gx3, gy3, gz3, x3, y3, z3);
    }
    /* add contributions from each corner to get the final noise value and scale down to [-1,1] */
    noise = 72.0 * (n0 + n1 + n2 + n3);
    /* compute derivative, if requested by supplying non-null pointers for the last three arguments */
    if (dx && dy && dz) {
        double temp0 = t20 * t0 * graddotp3(gx0, gy0, gz0, x0, y0, z0);
        double temp1 = t21 * t1 * graddotp3(gx1, gy1, gz1, x1, y1, z1);
        double temp2 = t22 * t2 * graddotp3(gx2, gy2, gz2, x2, y2, z2);
        double temp3 = t23 * t3 * graddotp3(gx3, gy3, gz3, x3, y3, z3);
        *dx = temp0 * x0 + temp1 * x1 + temp2 * x2 + temp3 * x3;
        *dy = temp0 * y0 + temp1 * y1 + temp2 * y2 + temp3 * y3;
        *dz = temp0 * z0 + temp1 * z1 + temp2 * z2 + temp3 * z3;
        *dx *= -8.0;
        *dy *= -8.0;
        *dz *= -8.0;
        *dx += t40 * gx0 + t41 * gx1 + t42 * gx2 + t43 * gx3;
        *dy += t40 * gy0 + t41 * gy1 + t42 * gy2 + t43 * gy3;
        *dz += t40 * gz0 + t41 * gz1 + t42 * gz2 + t43 * gz3;
        *dx *= 72.0;
        *dy *= 72.0;
        *dz *= 72.0;
    }
    return noise;
}

/*tex 
    We've now come to the \LUA\ interfacing. 
*/

/* x [ y [ z [ w ] ] ] */

static int effectslib_simplexnoise(lua_State *L)
{
    int top = lua_gettop(L);
    double x = top == 1 ? lua_tonumber(L, 1) : 0.0;
    double y = top == 2 ? lua_tonumber(L, 2) : 0.0;
    double z = top == 3 ? lua_tonumber(L, 3) : 0.0;
    double w = top == 4 ? lua_tonumber(L, 4) : 0.0;
    double n ;
    switch (top) {
        case 4  : n = effectslib_simplex_noise_4(x, y, z, w); break;
        case 3  : n = effectslib_simplex_noise_3(x, y, z);    break;
        case 2  : n = effectslib_simplex_noise_2(x, y);       break;
        case 1  : n = effectslib_simplex_noise_1(x);          break;
        default : n = 0.0;                                    break;
    }
    lua_push_number(L, n);
    return 1;
}

/* angle x y [ z ] */

static int effectslib_simplexangle(lua_State *L)
{
    int three = lua_type(L, 4) == LUA_TNUMBER;
    double angle = lua_tonumber(L, 1);
    double x = lua_tonumber(L, 2);
    double y = lua_tonumber(L, 3);
    double z = three ? lua_tonumber(L, 4) : 0.0;
    double sin_t = sin(angle);
    double cos_t = cos(angle);
    double noise; 
    if (three) { 
        noise = effectslib_simplex_detail_3(x, y, z, sin_t, cos_t, NULL, NULL, NULL);
    } else {
        noise = effectslib_simplex_detail_2(x, y, sin_t, cos_t, NULL, NULL);
    }
    lua_push_number(L, noise);
    return 1;
}

static int effectslib_simplexdetail(lua_State *L)
{
    int three = lua_type(L, 4) == LUA_TNUMBER;
    double angle = lua_tonumber(L, 1);
    double x = lua_tonumber(L, 2);
    double y = lua_tonumber(L, 3);
    double z = three ? lua_tonumber(L, 4) : 0.0;
    double dx = 0.0;
    double dy = 0.0;
    double dz = 0.0;
    double sin_t = sin(angle);
    double cos_t = cos(angle);
    double noise; 
    if (three) { 
        noise = effectslib_simplex_detail_3(x, y, z, sin_t, cos_t, &dx, &dy, &dz);
    } else {
        noise = effectslib_simplex_detail_2(x, y, sin_t, cos_t, &dx, &dy);
    }
    lua_pushnumber(L, noise);
    lua_pushnumber(L, dx);
    lua_pushnumber(L, dy);
    if (three) { 
        lua_push_number(L, dz);
        return 4;
    } else {
        return 3;
    }
}

# define OCTAVE_METATABLE "noise octave"

typedef enum octave_method { 
    octave_perlin  = 1,
    octave_simplex = 2,
    octave_angle   = 3,
    octave_detail  = 4,
} octave_method;

# define first_octave_method octave_perlin
# define last_octave_method  octave_detail

typedef enum octave_loop { /* same as bytemap_loop */
    octave_loop_xy, 
    octave_loop_yx,
} octave_loop;

# define first_octave_loop octave_loop_xy
# define last_octave_loop  octave_loop_yx

typedef enum octave_variant { 
    octave_perlin_noise_3   = 0,
    octave_simplex_noise_1  = 1,
    octave_simplex_noise_2  = 2,
    octave_simplex_noise_3  = 3,
    octave_simplex_noise_4  = 4,
    octave_simplex_detail_2 = 5,
    octave_simplex_detail_3 = 6,
} octave_variant;

typedef struct octave { 
    /* properties */
    int    iterations;   //  1
    double amplitude;    //  1.0
    double frequency;    //  1.0
    double persistence;  //  0.5
    double lacunarity;   //  2.0
    double angle;        //  0
    double minimum;      //  0
    double maximum;      //  255
    int    method;       //  1
    /* calculated */
    int    detail;
    int    count;
    /* changes as we go */
    double x;
    double y;
    double z;
    double w;
    /* */
    int    existing;
    double noise; 
    int    zset;
    int    wset;
    int    variant;
    int    loop;
    /* */
    double sin;
    double cos;
    /* */
    double dx;
    double dy;
    double dz;
    /* */
    int    b1;
    int    b2;
    int    b3;
} octave;

static int effectslib_octave_methods(lua_State *L)
{
    lua_createtable(L, 4, 0);
    lua_set_string_by_index(L, octave_perlin,  "perlin");
    lua_set_string_by_index(L, octave_simplex, "simplex");
    lua_set_string_by_index(L, octave_angle,   "angle");
    lua_set_string_by_index(L, octave_detail,  "detail");
    return 1;
}

static int effectslib_octave_loops(lua_State *L)
{
    lua_createtable(L, 2, 0);
    lua_set_string_by_index(L, octave_loop_xy, "xy");
    lua_set_string_by_index(L, octave_loop_yx, "yx");
    return 1;
}

static int effectslib_octave_variants(lua_State *L)
{
    lua_createtable(L, 5, 2);
    lua_set_string_by_index(L, octave_perlin_noise_3,   "perlin 3");   
    lua_set_string_by_index(L, octave_simplex_noise_1,  "simplex 1"); 
    lua_set_string_by_index(L, octave_simplex_noise_2,  "simplex 2"); 
    lua_set_string_by_index(L, octave_simplex_noise_3,  "simplex 3"); 
    lua_set_string_by_index(L, octave_simplex_noise_4,  "simplex 4"); 
    lua_set_string_by_index(L, octave_simplex_detail_2, "simplex 2 derivative"); 
    lua_set_string_by_index(L, octave_simplex_detail_3, "simplex 3 derivative"); 
    return 1;
}

static int effectslib_octave_aux_set(lua_State *L, octave *o, int direct)
{
    /* todo: also accept a table */
    o->method      = lmt_tointeger(L, 1);
    o->iterations  = lmt_tointeger(L, 2);
    o->amplitude   = lua_tonumber(L, 3);
    o->frequency   = lua_tonumber(L, 4);
    o->persistence = lua_tonumber(L, 5);
    o->lacunarity  = lua_tonumber(L, 6); /* we used scale before */
    o->angle       = lua_tonumber(L, 7);
    o->minimum     = lua_tonumber(L, 8);
    o->maximum     = lua_tonumber(L, 9);
    o->loop        = octave_loop_xy;
    o->variant     = octave_perlin_noise_3;
    o->sin         = sin(o->angle);
    o->cos         = cos(o->angle);
    o->x           = 0.0;
    o->y           = 0.0;
    if (direct) {
        o->z    = 0.0;
        o->w    = 0.0;
        o->zset = 0;
        o->wset = 0;
        direct  = 0;
    } else { 
        o->z    = lua_tonumber(L, 10);
        o->w    = lua_tonumber(L, 11);
        o->zset = lua_type(L, 10) == LUA_TNUMBER;
        o->wset = lua_type(L, 11) == LUA_TNUMBER;
        direct  = 11;
     // o->loop = lua_tointeger(L, 12); /* we then need to adapt elsewhere */
     // direct  = 12;
    }
    /* check */
    if (o->loop < first_octave_loop || o->method > last_octave_loop) {
        o->loop = first_octave_loop;
    }
    if (o->method < first_octave_method || o->method > last_octave_method) {
        o->method = first_octave_method;
    }
    o->detail = o->method == octave_detail;
    o->count  = 0;
    /* safeguards */
    if (o->persistence < 0.0) { 
        o->persistence = 1.0;
    } else if (o->persistence > 1.0) { 
        o->persistence = 1.0;
    }
    if (o->amplitude <= 0.0) { 
        o->amplitude = 1.0;
    }
    if (o->lacunarity < 1.0) { 
        o->lacunarity = 1.0;
    }
    /* done */
    return direct;
}

/*tex 
    We can optimize this: We can even keep already set values. 
*/

static void effectslib_octave_aux_use(lua_State *L, octave *o, int index, int count)
{
    switch (count) { 
        case 1: 
            o->x = lua_tonumber(L, index++);
            o->y = 0.0;
            o->z = 0.0;
            o->w = 0.0;
            o->count = 1;
            break;
        case 2: 
            o->x = lua_tonumber(L, index++);
            o->y = lua_tonumber(L, index++);
            o->z = 0.0;
            o->w = 0.0;
            o->count = 2;
            break;
        case 3: 
            o->x = lua_tonumber(L, index++);
            o->y = lua_tonumber(L, index++);
            o->z = lua_tonumber(L, index++);
            o->w = 0.0;
            o->count = 3;
            break;
        case 4:
            o->x = lua_tonumber(L, index++);
            o->y = lua_tonumber(L, index++);
            o->z = lua_tonumber(L, index++);
            o->w = lua_tonumber(L, index++);
            o->count = 4;
            break;
        default: 
            o->x = 0.0;
            o->y = 0.0;
            o->z = 0.0;
            o->w = 0.0;
            o->count = 0;
            break;
    }
}

static int effectslib_octave_aux_return(lua_State *L, octave *o)
{
    lua_pushnumber(L, o->noise);
    if (o->detail) { 
        switch (o->count) { 
            case 1:
                lua_pushnumber(L, o->dx);
                return 2;
            case 2:
                lua_pushnumber(L, o->dx);
                lua_pushnumber(L, o->dy);
                return 3;
            case 3:
                lua_pushnumber(L, o->dx);
                lua_pushnumber(L, o->dy);
                lua_pushnumber(L, o->dz);
                return 4;
        }
    }
    return 1;
}

static int effectslib_octave_aux_push(lua_State *L, octave *o)
{
    int n = 3;
    lua_pushnumber(L, o->noise);
    lua_pushnumber(L, o->x);
    lua_pushnumber(L, o->y);
    if (o->detail) { 
        switch (o->count) { 
            case 1:
                lua_pushnumber(L, o->dx);
                n += 1;
                break;
            case 2:
            case 3: /* todo dz */
            case 4: /* todo dz */
                lua_pushnumber(L, o->dx);
                lua_pushnumber(L, o->dy);
                n += 2;
                break;
        }
    }
    if (o->existing == 3) {
        lua_pushinteger(L, o->b1);
        lua_pushinteger(L, o->b2);
        lua_pushinteger(L, o->b3);
        n += 3;
    } else if (o->existing == 1) {
        lua_pushinteger(L, o->b1);
        n += 1;
    }
    return n;
}

static void effectslib_octave_aux_get(octave *o)
{
    int    variant      = 2; 
    double amplitude    = o->amplitude;
    double frequency    = o->frequency;
    double maxamplitude = 0.0;
    double noise        = 0.0;
    switch (o->method) { 
        case octave_perlin:  
            variant = octave_perlin_noise_3;
            break;
        case octave_simplex:
         // octave_simplex_noise_1 .. octave_simplex_noise_4
            variant = o->count;
            break;
        case octave_angle:  
        case octave_detail:  
            variant = o->count > 2 ? octave_simplex_detail_3 : octave_simplex_detail_2;
            break;
    }

    /*tex Optimizing for n=1 gives us some on extensive tests. */

 // if (1) {
    if (o->iterations > 1) {

        for (int i = 0; i < o->iterations; i++) {
            double result; 
            switch (variant) {
                case octave_perlin_noise_3: 
                    result = effectslib_perlin_noise_3 (o->x * frequency, o->y * frequency, o->z * frequency); 
                    break;
                case octave_simplex_noise_1: 
                    result = effectslib_simplex_noise_1(o->x * frequency); 
                    break;
                case octave_simplex_noise_2: 
                    result = effectslib_simplex_noise_2(o->x * frequency, o->y * frequency); 
                    break;
                case octave_simplex_noise_3: 
                    result = effectslib_simplex_noise_3(o->x * frequency, o->y * frequency, o->z * frequency); 
                    break;
                case octave_simplex_noise_4: 
                    result = effectslib_simplex_noise_4(o->x * frequency, o->y * frequency, o->z * frequency, o->w * frequency); 
                    break;
                case octave_simplex_detail_2: 
                    if (o->detail && i == o->iterations - 1) {
                        result = effectslib_simplex_detail_2(o->x * frequency, o->y * frequency, o->sin, o->cos, NULL, NULL); 
                    } else {
                        result = effectslib_simplex_detail_2(o->x * frequency, o->y * frequency, o->sin, o->cos, &o->dx, &o->dy); 
                    }
                    break;
                case octave_simplex_detail_3: 
                    if (o->detail && i == o->iterations - 1) {
                        result = effectslib_simplex_detail_3(o->x * frequency, o->y * frequency, o->z * frequency, o->sin, o->cos, NULL, NULL, NULL); 
                    } else { 
                        result = effectslib_simplex_detail_3(o->x * frequency, o->y * frequency, o->z * frequency, o->sin, o->cos, &o->dx, &o->dy, &o->dz); 
                    }
                    break;
                default: 
                    result = 0.0;
                    break;
            }
            noise        += amplitude * result; 
            maxamplitude += amplitude;
            amplitude    *= o->persistence;
            frequency    *= o->lacunarity;
        }

        noise = noise / maxamplitude;

    } else { 

        switch (variant) {
            case octave_perlin_noise_3: 
                noise = effectslib_perlin_noise_3 (o->x * frequency, o->y * frequency, o->z * frequency); 
                break;
            case octave_simplex_noise_1: 
                noise = effectslib_simplex_noise_1(o->x * frequency); 
                break;
            case octave_simplex_noise_2: 
                noise = effectslib_simplex_noise_2(o->x * frequency, o->y * frequency); 
                break;
            case octave_simplex_noise_3: 
                noise = effectslib_simplex_noise_3(o->x * frequency, o->y * frequency, o->z * frequency); 
                break;
            case octave_simplex_noise_4: 
                noise = effectslib_simplex_noise_4(o->x * frequency, o->y * frequency, o->z * frequency, o->w * frequency); 
                break;
            case octave_simplex_detail_2: 
                noise = effectslib_simplex_detail_2(o->x * frequency, o->y * frequency, o->sin, o->cos, NULL, NULL); 
                break;
            case octave_simplex_detail_3: 
                noise = effectslib_simplex_detail_3(o->x * frequency, o->y * frequency, o->z * frequency, o->sin, o->cos, NULL, NULL, NULL); 
                break;
            default: 
                noise = 0.0;
                break;
        }

    }
    /* we normalize the result to the range minimum .. maximum */
    noise = noise * (o->maximum - o->minimum) + (o->maximum + o->minimum); /* can be precalculated: no gain  */
    noise = noise / 2;
    /* and make sure we fit inside the range */
    if (noise > o->maximum) {
        noise = o->maximum;
    } else if (noise < o->minimum) {
        noise = o->minimum;
    }
    o->variant = variant;
    o->noise = noise;
}

static inline octave * effectslib_octave_aux_valid(lua_State *L, int i)
{
    // we need a fast one for this 
    return (octave *) luaL_checkudata(L, i, OCTAVE_METATABLE);
}

static int effectslib_octave_direct(lua_State *L)
{
    octave o; 
    int done = effectslib_octave_aux_set(L, &o, 1);
    effectslib_octave_aux_use(L, &o, done + 1, lua_gettop(L) - done);
    effectslib_octave_aux_get(&o);
    return effectslib_octave_aux_return(L, &o);
}

static inline int effectslib_octave_new(lua_State *L)
{
    /* todo: also initialize from table */
    octave *o = lua_newuserdatauv(L, sizeof(octave), 0);
    luaL_setmetatable(L, OCTAVE_METATABLE);
    /* The user data object now sits at the top! */
    effectslib_octave_aux_set(L, o, 0);
    return 1;
}

static int effectslib_octave_step(lua_State *L)
{
    octave *o = effectslib_octave_aux_valid(L, 1);
    if (o) {
        effectslib_octave_aux_use(L, o, 2, lua_gettop(L) - 1);
        effectslib_octave_aux_get(o);
        return effectslib_octave_aux_return(L, o);
    } else {
        return 0;
    }
}

static void effectslib_octave_aux_loop(lua_State *L, octave * o, int nx, int ny, int nz, unsigned char * bytemap, int slot)
{
    int fn = lua_type(L, slot) == LUA_TFUNCTION;
    if (o->wset) {
        o->count = 4; 
    } else if (o->zset) {
        o->count = 3;
    } else {
        o->count = 2;
    }
    if (o->loop == octave_loop_yx) { 
        unsigned char * p = bytemap;
        for (int y = 0; y < ny; y++) {
            o->y = y;
            for (int x = 0; x < nx; x++) {
                o->x = x;
                effectslib_octave_aux_get(o);
                if (fn) {
                    /* we need to retain the function */
                    lua_pushvalue(L, slot);
                    /* pass to function */
                    if (o->existing == 3) {
                        o->b1 = (int) *p;
                        o->b2 = (int) *(p+1);
                        o->b3 = (int) *(p+2);
                    } else if (o->existing == 1) { 
                        o->b1 = (int) *p;
                    }
                    /* call function */
                    { 
                        int n = effectslib_octave_aux_push(L, o);
                        if (lua_pcall(L, n, nz, 0) != 0) { 
                            tex_formatted_warning("effectslib", "run octave: %s", lua_tostring(L, -1));
                         // lua_pushliteral(L, "error running octave");
                         // lua_error(L);
                        }
                    }
                    /* use results */
                    if (nz == 3) { 
                        *p++ = (unsigned char) lmt_roundnumber(L, -3); /* slot + 1 */
                        *p++ = (unsigned char) lmt_roundnumber(L, -2); /* slot + 2 */
                     // *p++ = (unsigned char) lmt_roundnumber(L, -3); /* slot + 3 */
                    } else { 
                     // *p++ = (unsigned char) lmt_roundnumber(L, -1); /* slot + 1 */
                    }
                    *p++ = (unsigned char) lmt_roundnumber(L, -1);     /* slot + . */
                    /* wrap up */
                    lua_settop(L, slot);
                } else { 
                    unsigned char c = (unsigned char) lround(o->noise);
                    *p++ = c;
                    if (nz == 3) {
                        *p++ = c;
                        *p++ = c;
                    }
                }
            }
        }
    } else {
        for (int x = 0; x < nx; x++) {
            o->x = x;
            for (int y = 0; y < ny; y++) {
                int p = ((ny - y - 1) * nx * nz) + x * nz;
                o->y = y;
                effectslib_octave_aux_get(o);
                if (fn) {
                    /* we need to retain the function */
                    lua_pushvalue(L, slot);
                    /* pass to function */
                    if (o->existing == 3) {
                        o->b1 = (int) bytemap[p  ];
                        o->b2 = (int) bytemap[p+1];
                        o->b3 = (int) bytemap[p+2];
                    } else if (o->existing == 1) { 
                        o->b1 = (int) bytemap[p  ];
                    }
                    /* call function */
                    {
                        int n = effectslib_octave_aux_push(L, o);
                        if (lua_pcall(L, n, nz, 0) != 0) { 
                         // lua_pushliteral(L, "error running octave");
                            lua_error(L);
                        }
                    }
                    /* use results */
                    if (nz == 3) { 
                        bytemap[p  ] = (unsigned char) lmt_roundnumber(L, -3); /* slot + 1 */
                        bytemap[p+1] = (unsigned char) lmt_roundnumber(L, -2); /* slot + 2 */
                        bytemap[p+2] = (unsigned char) lmt_roundnumber(L, -1); /* slot + 3 */
                    } else { 
                        bytemap[p  ] = (unsigned char) lmt_roundnumber(L, -1); /* slot + 1 */
                    }
                    /* wrap up */
                    lua_settop(L, slot);
                } else { 
                    unsigned char c = (unsigned char) lround(o->noise);
                    bytemap[p] = c;
                    if (nz == 3) {
                        bytemap[p+1] = c;
                        bytemap[p+2] = c;
                    }
                }
            }
        }
    }
}

static int effectslib_octave_bytemap(lua_State *L)
{
    octave *o = effectslib_octave_aux_valid(L, 1);
    if (o) {
        int nx = lmt_tointeger(L, 2);
        int ny = lmt_tointeger(L, 3);
        int nz = lmt_tointeger(L, 4);
        if (nx > 0 && ny > 0 && (nz == 1 || nz == 3)) {
            size_t length = nx * ny * nz; /* todo: check this for overflow */
            unsigned char *bytemap = NULL; 
            o->existing = 0;
            bytemap = lmt_memory_malloc(length);
            if (lua_type(L, 6) == LUA_TSTRING) { 
                size_t l = 0;
                const char *s = lua_tolstring(L, 6, &l);
                if (l == length) { 
                    memcpy(bytemap, s, length);
                    o->existing = nz;
                } else {
                    bytemap = NULL;
                }
            }
            if (bytemap) {
                effectslib_octave_aux_loop(L, o, nx, ny, nz, bytemap, 5);
            }
            lua_pushlstring(L, (char *) bytemap, length);
            lua_pushinteger(L, length);
            lmt_memory_free(bytemap);
            return 2; 
        }
    }
    return 0;
}

int effectslib_octave_bytemapped(lua_State * L, unsigned char * bytemap, int nx, int ny, int nz, int slot)
{
    if (bytemap && nx > 0 && ny > 0 && (nz == 1 || nz == 3)) {
        octave *o = effectslib_octave_aux_valid(L, slot++);
        if (o) {
            o->existing = nz;
            effectslib_octave_aux_loop(L, o, nx, ny, nz, bytemap, slot);
            return 1; 
        }
    }
    return 0;
}

static int effectslib_octave_getstatus(lua_State *L)
{
    octave *o = effectslib_octave_aux_valid(L, 1);
    if (o) { 
        lua_createtable(L, 0, 22);
        lua_set_integer_by_key(L, "iterations",  o->iterations);
        lua_set_number_by_key (L, "amplitude",   o->amplitude);
        lua_set_number_by_key (L, "frequency",   o->frequency);
        lua_set_number_by_key (L, "persistence", o->persistence);
        lua_set_number_by_key (L, "lacunarity",  o->lacunarity);
        lua_set_number_by_key (L, "angle",       o->angle);
        lua_set_number_by_key (L, "maximum",     o->maximum);
        lua_set_number_by_key (L, "minimum",     o->minimum);
        lua_set_integer_by_key(L, "method",      o->method);
        lua_set_integer_by_key(L, "detail",      o->detail);
        lua_set_integer_by_key(L, "count",       o->count);
        lua_set_integer_by_key(L, "variant",     o->variant);
        lua_set_integer_by_key(L, "existing",    o->existing);
        lua_set_boolean_by_key(L, "zset",        o->zset);
        lua_set_boolean_by_key(L, "wset",        o->wset);
        lua_set_number_by_key (L, "x",           o->x);
        lua_set_number_by_key (L, "y",           o->y);
        lua_set_number_by_key (L, "z",           o->z);
        lua_set_number_by_key (L, "w",           o->w);
        lua_set_number_by_key (L, "dx",          o->dx);
        lua_set_number_by_key (L, "dy",          o->dy);
        lua_set_number_by_key (L, "dz",          o->dz);
        return 1;
    } else { 
        return 0;
    }
}

// static int effectslib_test(lua_State *L)
// {
//     /* 
//         Calculating the sin and cos of an angle takes time. On one of our tests, the 
//         500x500 TEX logo with 1 iteration 100 pages went from 7 to 6 seconds. This gain
//         was confirmed by this test and actually a loop in \LUA\ wasn't that much worse.
// 
//         int n = lua_tointeger(L, 1);
//         double d = 0.0;
//         printf("testing n=%i ...", n);
//         for (int i = 0; i < n; i++) {
//             d += sin(i);
//         }
//         lua_pushnumber(L, d);
//         printf(" done\n");
//         return 1; 
// 
//         But of course I might be wrong. However, 100 * 500 * 500 * 2 == 50.000.000 so 
//         a lot indeed. 
//     */
//     return 0;
// }

static int effectslib_octave_tostring(lua_State *L)
{
    octave *o = effectslib_octave_aux_valid(L, 1);
    if (o) {
        lua_pushfstring(L, "<octave %p>", o);
        return 1;
    } else {
        return 0;
    }
    return 0;
}

static const luaL_Reg effectslib_octave_metatable[] =
{
 /* { "__index",    effectslib_octave_getvalue }, */
 /* { "__newindex", effectslib_octave_setvalue }, */
    { "__tostring", effectslib_octave_tostring },
    { NULL,         NULL                       },
};
 
static void effectslib_octave_initialize(lua_State *L)
{
    luaL_newmetatable(L, OCTAVE_METATABLE);
    luaL_setfuncs(L, effectslib_octave_metatable, 0);
}

/* The library: (todo: namespaces) */

static struct luaL_Reg effectslib_function_list[] = {
    /* */
    { "perlinnoise",       effectslib_perlinnoise      },
    { "simplexnoise",      effectslib_simplexnoise     },
    { "simplexangle",      effectslib_simplexangle     },
    { "simplexdetail",     effectslib_simplexdetail    },
    /* */                            
    { "newoctave",         effectslib_octave_new       },  
    { "stepoctave",        effectslib_octave_step      },  
    { "octave",            effectslib_octave_direct    },
    { "octavebytemap",     effectslib_octave_bytemap   },
    { "getoctavestatus",   effectslib_octave_getstatus },
    { "getoctavemethods",  effectslib_octave_methods   },
    { "getoctaveloops",    effectslib_octave_loops     },
    { "getoctavevariants", effectslib_octave_variants  },
    /* */
 // { "test",              effectslib_test             },
    /* */
    { NULL,                NULL                        },
};

int luaopen_effects(lua_State *L)
{
    effectslib_octave_initialize(L);
    lua_newtable(L);
    luaL_setfuncs(L, effectslib_function_list, 0);
    return 1;
}
