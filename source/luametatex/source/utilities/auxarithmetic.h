/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_ARITHMETIC_H
# define LMT_UTILITIES_ARITHMETIC_H

/* The |fabs| macro is used in mp. */

/*tex

There has always be much attention on accuracy in \TEX, especially in the perspective of portability. 
Keep in mind that \TEX\ was written when there was no IEEE floating point defined so all happens in 
16.16, or actually in 14.16 precision. We could actually consider going 16.16 if we use long integers 
in some places but it needs some checking first. We could just accept wrapping around as that already
happens in some places anyway (not all dimension calculation are checked).

In \LUATEX\ and \LUAMETATEX\ we have the \LUA\ engine and that one was exclusively using doubles till 
5.3 when it went for a more hybrid approach. Because we go a lot between \TEX\ and \LUA\ (in \CONTEXT) 
that had some consequences and rounding happens all over the place. It is also for that reason that 
we now use doubles and rounding in some more places in the \TEX\ part: it is more consistent with what 
happens at the \LUA\ end. And, because IEEE is common now, we are (afaiks) portable enough. 

We don't use round but lround as that one rounds away from zero. In a few places we use llround. Also 
in some places we clip to the official maxima but not always. 

*/


/*
# undef abs
# undef fabs

# define abs(x)    ((int)(x) >= 0 ? (int)(x) : (int)-(x))
# define fabs(x)   ((x) >= 0.0 ? (x) : -(x))
*/

# define odd(x)    ((x) & 1)

# define lfloor(x) ( (lua_Integer)(floor((double)(x))) )
# define tfloor(x) ( (size_t)     (floor((double)(x))) )
# define ifloor(x) ( (int)        (floor((double)(x))) )

static inline int fastfloor (double x) { return (int) x <= x ? (int) x : (int) x - 1; }
static inline int fastfloord(double x) { return (int) x <= x ? (int) x : (int) x - 1; }
static inline int fastfloorf(float  x) { return (int) x <= x ? (int) x : (int) x - 1; }
static inline int fastceil  (double x) { return (int) x >= x ? (int) x : (int) x + 1; }

// static inline int fastfloor (float x) { int i = (int) x;  return i - (x < (float) i); }
// static inline int fastfloorf(float x) { int i = (int) x;  return i - (x < (float) i); }

//define lround(x) ( ((double) x >= 0.0) ? (lua_Integer) ((double) x + 0.5) : (lua_Integer) ((double) x - 0.5) )
//define tround(x) ( ((double) x >= 0.0) ? (size_t)      ((double) x + 0.5) : (size_t)      ((double) x - 0.5) )
//define iround(x) ( ((double) x >= 0.0) ? (int)         ((double) x + 0.5) : (int)         ((double) x - 0.5) )
//define sround(x) ( ((double) x >= 0.0) ? (int)         ((double) x + 0.5) : (int)         ((double) x - 0.5) )

//define lround(x) ( ((double) x >= 0.0) ? (lua_Integer) ((double) x + 0.5) : (lua_Integer) ((double) x - 0.5) )
//define tround(x) ( ((double) x >= 0.0) ? (size_t)      ((double) x + 0.5) : (size_t)      ((double) x - 0.5) )
//define iround(x) ( (int) lround((double) x) )

//define zround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : ((r >= 0.0) ? (int)(r + 0.5) : ((int)(r-0.5)))))
//define zround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : (int) lround(r)))

//define scaledround(x)  ((scaled) lround((double) (x)))
# define longlonground   llround
# define clippedround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : (int) lround(r)))
# define glueround(x)    clippedround((double) (x))

static inline scaled scaledround(double x) { return (scaled) lround(x); }

# if lmt_float_math

    /* nothing */

# else

    /*
        The float path evaluates these expressions in double precision.  On compilers with
        __int128, keep the integer path exact until the final division instead of multiplying
        in long long first.  The largest dimension products use four scale factors, so 64 bits
        are not sufficient.  The fallback keeps the wider intermediate in long double.
    */

    static inline long long tex_aux_round_product(long long value, long long a, long long b, long long c, long long d, long long divisor)
    {
        if (! value || ! a || ! b || ! c || ! d) {
            return 0;
        }
    # if defined(__SIZEOF_INT128__)
        __int128 numerator = (__int128) value;
        numerator *= a;
        numerator *= b;
        numerator *= c;
        numerator *= d;
        int negative = numerator < 0;
        if (negative) {
            numerator = -numerator;
        }
        __int128 denominator = divisor < 0 ? -(__int128) divisor : (__int128) divisor;
        __int128 quotient = numerator / denominator;
        __int128 remainder = numerator % denominator;
        if (remainder >= denominator - remainder) {
            ++quotient;
        }
        if (negative) {
            quotient = -quotient;
        }
        if (quotient > LLONG_MAX) {
            return LLONG_MAX;
        } else if (quotient < LLONG_MIN) {
            return LLONG_MIN;
        } else {
            return (long long) quotient;
        }
    # else
        long double result = ((long double) value * (long double) a * (long double) b * (long double) c * (long double) d) / (long double) divisor;
        long double rounded = result >= 0.0L ? result + 0.5L : result - 0.5L;
        if (rounded >= (long double) LLONG_MAX) {
            return LLONG_MAX;
        } else if (rounded <= (long double) LLONG_MIN) {
            return LLONG_MIN;
        } else {
            return (long long) rounded;
        }
    # endif
    }

    static inline long long tex_aux_round_sum_products(long long value, long long a, long long b, long long c, long long d, long long divisor)
    {
        if (! value || (! a && ! c) || (! b && ! d)) {
            return 0;
        }
    # if defined(__SIZEOF_INT128__)
        __int128 numerator = (__int128) value * a * b + (__int128) value * c * d;
        int negative = numerator < 0;
        if (negative) {
            numerator = -numerator;
        }
        __int128 denominator = divisor < 0 ? -(__int128) divisor : (__int128) divisor;
        __int128 quotient = numerator / denominator;
        __int128 remainder = numerator % denominator;
        if (remainder >= denominator - remainder) {
            ++quotient;
        }
        if (negative) {
            quotient = -quotient;
        }
        if (quotient > LLONG_MAX) {
            return LLONG_MAX;
        } else if (quotient < LLONG_MIN) {
            return LLONG_MIN;
        } else {
            return (long long) quotient;
        }
    # else
        long double result = ((long double) value * (long double) a * (long double) b + (long double) value * (long double) c * (long double) d) / (long double) divisor;
        long double rounded = result >= 0.0L ? result + 0.5L : result - 0.5L;
        if (rounded >= (long double) LLONG_MAX) {
            return LLONG_MAX;
        } else if (rounded <= (long double) LLONG_MIN) {
            return LLONG_MIN;
        } else {
            return (long long) rounded;
        }
    # endif
    }

    /* Explicit scale: zero remains zero. */

    static inline scaled tex_aux_scale_1000(scaled v, long long scale)
    {
        return (scaled) tex_aux_round_product(v, scale, 1, 1, 1, 1000);
    }

    /* A zero scale means the default 100% scale in these font and glyph paths. */

    static inline scaled tex_aux_scale_1000_default(scaled v, long long scale)
    {
        return tex_aux_scale_1000(v, scale ? scale : 1000LL);
    }

    static inline scaled tex_aux_scale_1e6(scaled value, long long s1, long long s2)
    {
        return (scaled) tex_aux_round_product(value, s1 ? s1 : 1000LL, s2 ? s2 : 1000LL, 1, 1, 1000000);
    }

    /* The first two scales default to 100%, the explicit third scale may be zero. */

    static inline scaled tex_aux_scale_1e9(scaled value, long long s1, long long s2, long long s3)
    {
        return (scaled) tex_aux_round_product(value, s1 ? s1 : 1000LL, s2 ? s2 : 1000LL, s3, 1, 1000000000);
    }

# endif

# endif
