/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    The principal computations performed by \TEX\ are done entirely in terms of integers less than
    $2^{31}$ in magnitude; and divisions are done only when both dividend and divisor are
    nonnegative. Thus, the arithmetic specified in this program can be carried out in exactly the
    same way on a wide variety of computers, including some small ones. Why? Because the arithmetic
    calculations need to be spelled out precisely in order to guarantee that \TEX\ will produce
    identical output on different machines.

    If some quantities were rounded differently in different implementations, we would find that
    line breaks and even page breaks might occur in different places. Hence the arithmetic of \TEX\
    has been designed with care, and systems that claim to be implementations of \TEX82 should
    follow precisely the \TEX82\ calculations as they appear in the present program.

    Actually there are three places where \TEX\ uses |div| with a possibly negative numerator.
    These are harmless; see |div| in the index. Also if the user sets the |\time| or the |\year| to
    a negative value, some diagnostic information will involve negative|-|numerator division. The
    same remarks apply for |mod| as well as for |div|.

    The |half| routine, defined in the header file, calculates half of an integer, using an
    unambiguous convention with respect to signed odd numbers.

    The |round_decimals| function, defined in the header file, is used to create a scaled integer
    from a given decimal fraction $(.d_0d_1 \ldots d_{k-1})$, where |0 <= k <= 17|. The digit $d_i$
    is given in |dig[i]|, and the calculation produces a correctly rounded result.

    Keep in mind that in spite of these precautions results can be different over time. For
    instance, fonts and hyphenation patterns do evolve over, and actually did in the many decades
    that \TEX\ has been around. Also, delegating work to \LUA, which uses doubles, can have
    consequences.

*/

/*tex

    % This needs to be adapted to new variable names! It's the old documentation.

    Physical sizes that a \TEX\ user specifies for portions of documents are represented internally
    as scaled points. Thus, if we define an |sp| (scaled point) as a unit equal to $2^{-16}$
    printer's points, every dimension inside of \TEX\ is an integer number of sp. There are exactly
    4,736,286.72 sp per inch. Users are not allowed to specify dimensions larger than $2^{30} - 1$
    sp, which is a distance of about 18.892 feet (5.7583 meters); two such quantities can be added
    without overflow on a 32-bit computer.

    The present implementation of \TEX\ does not check for overflow when dimensions are added or
    subtracted. This could be done by inserting a few dozen tests of the form |if x >= 010000000000|
    then |report_overflow|, but the chance of overflow is so remote that such tests do not seem
    worthwhile.

    \TEX\ needs to do only a few arithmetic operations on scaled quantities, other than addition and
    subtraction, and the following subroutines do most of the work. A single computation might use
    several subroutine calls, and it is desirable to avoid producing multiple error messages in case
    of arithmetic overflow; so the routines set the |arithmetic_error| field in |lmt_scanner_state|
    to |1| instead of reporting errors directly to the user. An optional out-parameter holds the
    remainder after a division.

    The first arithmetical subroutine we need computes $nx+y$, where |x| and~|y| are |scaled| and
    |n| is an integer. We will also use it to multiply integers.

    Helpers like this evolve as one sometimes reads about how compilers and processors deal with
    this (it's interesting to see progress when one started with microprocessors as kid). When
    searching a bit on compiler optimizations llm's recognize these integer based \TEX\ paradigms
    but also see that we do things differently already so we mostly stick to what we have now.

*/

static inline scaled tex_aux_m_and_a(int n, scaled x, scaled y, scaled max_answer)
{
    if (n == 0) {
        return y;
    }
    // 64-bit widening: 0 division cycles, perfectly safe against overflow
    long long res = (long long) n * (long long) x + (long long) y;
    if (res >= -((long long) max_answer) && res <= (long long) max_answer) {
        return (scaled)res;
    } else {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    }
}

scaled tex_multiply_and_add  (int n, scaled x, scaled y, scaled max_answer) { return tex_aux_m_and_a(n, x, y, max_answer); }
scaled tex_nx_plus_y         (int n, scaled x, scaled y)                    { return tex_aux_m_and_a(n, x, y, 0x3FFFFFFF); } //  07777777777
scaled tex_multiply_integers (int n, scaled x)                              { return tex_aux_m_and_a(n, x, 0, 0x7FFFFFFF); } // 017777777777

scaled tex_x_over_n_r(scaled x, int n, int *remainder)
{
    /*tex The optional |remainder| has the sign of the dividend. */
    if (n == 0) {
        lmt_scanner_state.arithmetic_error = 1;
        if (remainder) {
            *remainder = x;
        }
        return 0;
    } else {
        if (remainder) {
            *remainder = x % n;
        }
        return x / n;
    }
}

scaled tex_x_over_n(scaled x, int n)
{
    if (n == 0) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    } else {
        return x / n;
    }
}

scaled tex_x_over_n_unity(scaled x)
{
    return x / unity;
}

scaled tex_x_over_n_factor(scaled x)
{
    return x / scaling_factor;
}

/*tex

    Then comes the multiplication of a scaled number by a fraction |n/d|, where |n| and |d| are
    nonnegative integers |<= 2^16| and |d| is positive. It would be too dangerous to multiply by~|n|
    and then divide by~|d|, in separate operations, since overflow might well occur; and it would
    be too inaccurate to divide by |d| and then multiply by |n|. Hence this subroutine simulates
    1.5-precision arithmetic.

*/

scaled tex_xn_over_d_r(scaled x, int n, int d, int *remainder)
{
    if (d == 0) {
        lmt_scanner_state.arithmetic_error = 1;
        if (remainder) {
            *remainder = x;
        }
        return 0;
    }
    if (x == 0) {
        if (remainder) {
            *remainder = 0;
        }
        return 0;
    } else {
        long long v = (long long) x * (long long) n;
        long long q = v / d;
        long long r = v % d;
        if (q < (long long) min_dimension || q > (long long) max_dimension) {
            lmt_scanner_state.arithmetic_error = 1;
            if (remainder) {
                *remainder = (scaled) r;
            }
            return 0;
        }
        if (remainder) {
            *remainder = (scaled) r;
        }
        return (scaled) q;
    }
}

scaled tex_xn_over_d(scaled x, int n, int d)
{
    if (d == 0) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    }
    if (x == 0) {
        return 0;
    }
    long long q = ((long long) x * (long long) n) / d;
    if (q < (long long) min_dimension || q > (long long) max_dimension) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    }
    return (scaled) q;
}

/*tex

    When \TEX\ packages a list into a box, it needs to calculate the proportionality ratio by which
    the glue inside the box should stretch or shrink. This calculation does not affect \TEX's
    decision making, so the precise details of rounding, etc., in the glue calculation are not of
    critical importance for the consistency of results on different computers.

    We shall use the type |glue_ratio| for such proportionality ratios. A glue ratio should take the
    same amount of memory as an |integer| (usually 32 bits) if it is to blend smoothly with \TEX's
    other data structures. Thus |glue_ratio| should be equivalent to |short_real| in some
    implementations of \PASCAL. Alternatively, it is possible to deal with glue ratios using nothing
    but fixed-point arithmetic; see {\em TUGboat \bf3},1 (March 1982), 10--27. (But the routines
    cited there must be modified to allow negative glue ratios.)

*/

/*
    this (double) constant integer ... will the compiler optimize that?
*/

static inline scaled tex_aux_checked_scaledround(double value, scaled lo, scaled hi)
{
    if (value == 0) {
        return 0;
    } else if (! isfinite(value)) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    } else {
        double rounded = value >= 0.0 ? value + 0.5 : value - 0.5;
        if (rounded < (double) lo || rounded > (double) hi) {
            lmt_scanner_state.arithmetic_error = 1;
            return 0;
        }
        return (scaled) rounded;
    }
}

# if lmt_float_math

    scaled tex_round_xn_over_d(scaled x, int n, unsigned int d)
    {
        if (d == 0) {
            lmt_scanner_state.arithmetic_error = 1;
            return 0;
        } else if (x == 0 || (n >= 0 && (unsigned int) n == d && x >= min_dimension && x <= max_dimension)) {
            return x;
        } else {
            return tex_aux_checked_scaledround((1.0 / d) * n * x, min_dimension, max_dimension);
        }
    }

# else

    scaled tex_round_xn_over_d(scaled x, int n, unsigned int d)
    {
        if (d == 0) {
            lmt_scanner_state.arithmetic_error = 1;
            return 0;
        }
        if (x == 0 || (n >= 0 && (unsigned int) n == d && x >= min_dimension && x <= max_dimension)) {
            return x;
        }
        /* 64-bit widening allows exact integer multiplication without overflow */
        long long prod = (long long) x * (long long) n;
        long long half = (long long) d / 2;
        /* Symmetric rounding matching TeX's exact rounding convention */
        long long q = (prod >= 0) ? (prod + half) / (long long) d
                                  : (prod - half) / (long long) d;
        if (q < (long long) min_dimension || q > (long long) max_dimension) {
            lmt_scanner_state.arithmetic_error = 1;
            return 0;
        }
        return (scaled) q;
    }

# endif

/*tex

    The return value is a decimal number with the point |dd| places from the back, |scaled_out| is
    the number of scaled points corresponding to that.

*/

scaled tex_divide_scaled_n(double sd, double md, double n)
{
    if (md == 0.0) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    } else {
        return tex_aux_checked_scaledround(sd / md * n, min_integer, max_integer);
    }
}

scaled tex_ext_xn_over_d(scaled x, scaled n, scaled d)
{
    if (d == 0) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    } else {
        double r = (((double) x) * ((double) n)) / ((double) d);
        if (r > (double) max_integer || r < (double) min_integer) {
            tex_normal_warning("internal", "arithmetic number too big");
        }
        return tex_aux_checked_scaledround(r, min_integer, max_integer);
    }
}

scaled tex_nx_plus_y_posit(halfword p, scaled x, scaled y)
{
    if (p == 0) {
        return y;
    } else {
        double d = tex_posit_to_double(p) * x + y;
        long long r = llround(d);
        if (r < -0x3FFFFFFF || r > 0x3FFFFFFF) {
            lmt_scanner_state.arithmetic_error = 1;
            return 0;
        } else {
            return (halfword) r;
            }
    }
}

scaled tex_divide_scaled_factor(scaled sd, scaled md)
{
    if (md == 0) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    }
    if (sd == 0) {
        return 0;
    }
    /* Multiply by 1000 in 64-bit space to prevent overflow */
    long long num  = (long long) sd * 1000LL;
    long long half = (long long) md / 2LL;
    /* Symmetric round-to-nearest integer division */
    long long res = (num >= 0) ? (num + half) / (long long) md
                               : (num - half) / (long long) md;
    if (res < (long long) min_integer || res > (long long) max_integer) {
        lmt_scanner_state.arithmetic_error = 1;
        return 0;
    }
    return (scaled) res;
}
