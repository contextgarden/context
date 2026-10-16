/*
    See license.txt in the root of this project.
*/

# ifndef LMT_COMPILER_H
# define LMT_COMPILER_H

# include <stdbool.h>
# include <stdint.h>
# include <math.h>

/*tex

    Let's see if C 23 works out ok. We have to make sure that some assumed to be present functions
    like \type {readlink} and a few math ones are defined. The extensions flag below ensures that
    we're okay. CMake will fall back to older versions if needed, which is fine, until of course
    we start using more recent language features.

    \starttyping
    set(CMAKE_C_STANDARD          23)
    set(CMAKE_C_STANDARD_REQUIRED OFF) # OFF is default
    ###(CMAKE_C_EXTENSIONS        ON)  # ON is default
    \stoptyping

    This doesn't work:

    \starttyping
    // # define _POSIX_C_SOURCE 200809L  // Exposes POSIX.1-2008 APIs including readlink
    // # define _GNU_SOURCE              // or _DEFAULT_SOURCE
    // # include <unistd.h>
    \stoptyping

    Let's assume that CMake handles all of this.

*/

/*tex

    Because \LUA\ (and mimalloc) uses it, why not also use it. The main gain is that the \quote
    {cold} brache code is move out of the way so that the cache is less stressed. The performance
    gains can probably be neglected. We mostly put these directives on catching errors. In \CPP\
    we actually have a cleaner way \type {[[unlikely]]} that we can put after a condition, \type
    {else}, \type {label:} in a switch etc. But it didn't make it into C (yet), so we're stick
    with singular, unchained conditionals usage; I'm not going to cripple the code for more of
    this. So, for now, consider it an experiment, which is why we (can) report it being enabled.

*/

# if defined(__GNUC__) || defined(__clang__)
    # define lmt_likely(x)   (__builtin_expect(!!(x),1))
    # define lmt_unlikely(x) (__builtin_expect(!!(x),0))
    # define LMT_LIKELY_USED 1
# elif (defined(__cplusplus) && (__cplusplus >= 202002L)) || (defined(_MSVC_LANG) && _MSVC_LANG >= 202002L)
    # define lmt_likely(x)   (x) [[likely]]
    # define lmt_unlikely(x) (x) [[unlikely]]
    # define LMT_LIKELY_USED 1
# else
    # define lmt_likely(x)   (x)
    # define lmt_unlikely(x) (x)
    # define LMT_LIKELY_USED 0
# endif

/*tex

    We keep track of the \CCODE\ version being used, just in case we need to see what a locally
    compiled version actually uses. It is not relevant at all for the working of the engine.

*/

# ifndef LMT_COMPILER_USED
    # define LMT_COMPILER_USED "unknown"
# endif

#if defined(__STDC_VERSION__)
    // 202000L catches GCC 14 / Clang experimental C23; 202311L is final C23
    # if __STDC_VERSION__ >= 202000L
        # define LMT_CVERSION_USED 23
    # elif __STDC_VERSION__ >= 201710L
        # define LMT_CVERSION_USED 17
    # elif __STDC_VERSION__ >= 201112L
        # define LMT_CVERSION_USED 11
    # elif __STDC_VERSION__ >= 199901L
        # define LMT_CVERSION_USED 99
    # elif __STDC_VERSION__ >= 199409L
        # define LMT_CVERSION_USED 95
    # else
        # define LMT_CVERSION_USED 89
    # endif
# else
    # define LMT_CVERSION_USED 89
# endif

/*tex
    It would be nice if we could test if musl is used. Comments in the web indicate that there
    never be some macro to check for that (argument: it shouldn't matter code/api wise). Well it
    does matter if you have to make a choice for a binary (set path to a tree), as needed in a
    TeX distribution that ships a lot. A bit lack of imagination I guess or maybe it's only for
    people who compile themselves. So if no one cares, I don't either. Maybe CMAKE can help some
    day.
*/

// # ifndef LMT_LIBC_USED
//    # if defined(__GLIBC__)
//        # define LMT_LIBC_USED "glibc"
//    # elif defined(__UCLIBC__)
//        # define LMT_LIBC_USED "uclibc"
//    # else
//        # define LMT_LIBC_USED "unknown"
//    # endif
// # endif

/*tex

    We don't want to see these messages when we compile. With C23 we suddenly got them back in the
    MS compiler.

*/

# ifndef __has_c_attribute
    # define __has_c_attribute(x) 0
# endif

/* Ensure __has_c_attribute is safely defined so older preprocessors don't crash */
# ifndef __has_c_attribute
    # define __has_c_attribute(x) 0
# endif
/* Standard C23 attribute */
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
    # define FALLTHROUGH [[fallthrough]];
/* C23 attribute check for compilers supporting __has_c_attribute */
# elif __has_c_attribute(fallthrough)
    # define FALLTHROUGH [[fallthrough]];
/* GNU / Clang extension fallback */
# elif defined(__GNUC__) && (__GNUC__ >= 7)
    # define FALLTHROUGH __attribute__((fallthrough));
/* MSVC fallback */
# elif defined(_MSC_VER) && (_MSC_VER >= 1910)
    # define FALLTHROUGH __fallthrough;
/* No-op fallback for older standard C compilers */
# else
    # define FALLTHROUGH ((void) 0);
# endif

# if (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L) || defined(_MSC_VER)

    # define lmt_hypot hypot

# else

    static inline double lmt_hypot(double x, double y)
    {
        double ax = fabs(x);
        double ay = fabs(y);
        if (ax == 0.0 && ay == 0.0) {
            return 0.0;
        } else if (ax > ay) {
            double r = ay / ax;
            return ax * sqrt(1.0 + r * r);
        } else {
            double r = ax / ay;
            return ay * sqrt(1.0 + r * r);
        }
    }

# endif

static inline bool odd_int    (int                a) { return (a & 1) != 0; }
static inline bool odd_uint   (unsigned int       a) { return (a & 1u) != 0; }
static inline bool odd_long   (long long          a) { return (a & 1ll) != 0; }
static inline bool odd_ulong  (unsigned long long a) { return (a & 1ull) != 0; }
static inline bool odd_double (double             a) { return fabs(fmod(a, 2.0)) == 1.0; }

/* some day:

# define odd(X) _Generic((X),       \
    unsigned int:       odd_uint,   \
    unsigned long:      odd_ulong,  \
    unsigned long long: odd_ulong,  \
    float:              odd_double, \
    double:             odd_double, \
    long double:        odd_double, \
    default:            odd_long    \
)(X)

*/

# define SAFE __attribute__((annotate("safe")))

// void enforce_fpu_consistency(void)
// {
//     /* Force round-to-nearest (IEEE-754 default). */
//     fesetround(FE_TONEAREST);
//     // Flush Denormals To Zero (FTZ) and Denormals Are Zero (DAZ) if needed.
//     // Denormal behavior varies between x86 and ARM processors. Disabling
//     // denormals ensures both speed and deterministic behavior.
// # if defined(__x86_64__) || defined(_M_X64)
//     _mm_setcsr(_mm_getcsr() | 0x8000 | 0x0040); // Sets FTZ and DAZ on SSE/AVX
// # endif
// }
//
// # include <fenv.h>
//
// void enforce_cross_platform_fpu()
// {
//     // Force standard IEEE round-to-nearest
//     std::fesetround(FE_TONEAREST);
// # if defined(__x86_64__) || defined(_M_X64)
//     // Enable Flush-to-Zero (FTZ) and Denormals-are-Zero (DAZ) on x86
//     _mm_setcsr(_mm_getcsr() | 0x8000 | 0x0040);
// # elif defined(__aarch64__)
//     // Enable Flush-to-Zero on ARM64 FPSCR register
//     uint64_t fpcr;
//     asm volatile("mrs %0, fpcr" : "=r"(fpcr));
//     fpcr |= (1ULL << 24); // Set FZ bit
//     asm volatile("msr fpcr, %0" :: "r"(fpcr));
// # endif
// }

# endif
