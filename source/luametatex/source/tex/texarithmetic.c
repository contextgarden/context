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
    of arithmetic overflow; so the routines set the global variable |arith_error| to |true| instead
    of reporting errors directly to the user. Another global variable, |tex_remainder|, holds the
    remainder after a division.

    The first arithmetical subroutine we need computes $nx+y$, where |x| and~|y| are |scaled| and
    |n| is an integer. We will also use it to multiply integers.

*/

inline static scaled tex_aux_m_and_a(int n, scaled x, scaled y, scaled max_answer)
{
    if (n == 0) {
        return y;
    } else {
        if (n < 0) {
            x = -x;
            n = -n;
        }
        if (((x <= (max_answer - y) / n) && (-x <= (max_answer + y) / n))) {
            return n * x + y;
        } else {
            lmt_scanner_state.arithmic_error = 1;
            return 0;
        }
    }
}

scaled tex_multiply_and_add  (int n, scaled x, scaled y, scaled max_answer) { return tex_aux_m_and_a(n, x, y,   max_answer); }
scaled tex_nx_plus_y         (int n, scaled x, scaled y)                    { return tex_aux_m_and_a(n, x, y,  07777777777); }
scaled tex_multiply_integers (int n, scaled x)                              { return tex_aux_m_and_a(n, x, 0, 017777777777); }

/*tex We also need to divide scaled dimensions by integers. */

/*
scaled tex_x_over_n_r(scaled x, int n, int *remainder)
{
    if (n == 0) {
        lmt_scanner_state.arithmic_error = 1;
        if (remainder) {
            *remainder = x;
        }
        return 0;
    } else {
        int negative = 0;
        if (n < 0) {
            x = -x;
            n = -n;
            negative = 1;
        }
        if (x >= 0) {
            int r = x % n;
            if (remainder) {
                if (negative) {
                    r = -r;
                }
                *remainder = r;
            }
            return (x / n);
        } else {
            int r = -((-x) % n);
            if (remainder) {
                if (negative) {
                    r = -r;
                }
                *remainder = r;
            }
            return -((-x) / n);
        }
    }
}
*/

scaled tex_x_over_n_r(scaled x, int n, int *remainder)
{
    /*tex Should |tex_remainder| be negated? */
    if (n == 0) {
        lmt_scanner_state.arithmic_error = 1;
        *remainder = x;
        return 0;
    } else {
        *remainder = x % n;
        return x/n;
    }
}

/*
scaled tex_x_over_n(scaled x, int n)
{
     if (n == 0) {
        lmt_scanner_state.arithmic_error = 1;
        return 0;
    } else {
        if (n < 0) {
            x = -x;
            n = -n;
        }
        if (x >= 0) {
            return (x / n);
        } else {
            return -((-x) / n);
        }
    }
}
*/

scaled tex_x_over_n(scaled x, int n)
{
     if (n == 0) {
        lmt_scanner_state.arithmic_error = 1;
        return 0;
    } else {
        return x/n;
    }
}

/*tex

    Then comes the multiplication of a scaled number by a fraction |n/d|, where |n| and |d| are
    nonnegative integers |<= 2^16| and |d| is positive. It would be too dangerous to multiply by~|n|
    and then divide by~|d|, in separate operations, since overflow might well occur; and it would
    be too inaccurate to divide by |d| and then multiply by |n|. Hence this subroutine simulates
    1.5-precision arithmetic.

*/

/*
scaled tex_xn_over_d_r(scaled x, int n, int d, int *remainder)
{
    if (x == 0) {
        if (remainder) {
            *remainder = 0;
        }
        return 0;
    } else {
        int positive = 1;
        unsigned int t, u, v, xx, dd;
        if (x < 0) {
            x = -x;
            positive = 0;
        }
        xx = (unsigned int) x;
        dd = (unsigned int) d;
        t = ((xx % 0100000) * (unsigned int) n);
        u = ((xx / 0100000) * (unsigned int) n + (t / 0100000));
        v = (u % dd) * 0100000 + (t % 0100000);
        if (u / dd >= 0100000) {
            lmt_scanner_state.arithmic_error = 1;
        } else {
            u = 0100000 * (u / dd) + (v / dd);
        }
        if (positive) {
            if (remainder) {
                *remainder = (int) (v % dd);
            }
            return (scaled) u;
        } else {
            if (remainder) {
                *remainder = - (int) (v % dd);
            }
            return - (scaled) u;
        }
    }
}
*/

scaled tex_xn_over_d_r(scaled x, int n, int d, int *remainder)
{
    if (x == 0) {
        *remainder = 0;
        return 0;
    } else {
        long long v = (long long) x * (long long) n;
        *remainder = (scaled) (v % d);
        return (scaled) (v / d); 
    }
}

/*
scaled tex_xn_over_d(scaled x, int n, int d)
{
    if (x == 0) {
        return 0;
    } else {
        int positive = 1;
        unsigned int t, u, v, xx, dd;
        if (x < 0) {
            x = -x;
            positive = 0;
        }
        xx = (unsigned int) x;
        dd = (unsigned int) d;
        t = ((xx % 0100000) * (unsigned int) n);
        u = ((xx / 0100000) * (unsigned int) n + (t / 0100000));
        v = (u % dd) * 0100000 + (t % 0100000);
        if (u / dd >= 0100000) {
            lmt_scanner_state.arithmic_error = 1;
        } else {
            u = 0100000 * (u / dd) + (v / dd);
        }
        if (positive) {
            return (scaled) u;
        } else {
            return - (scaled) u;
        }
    }
}
*/

scaled tex_xn_over_d(scaled x, int n, int d)
{
    if (x == 0) {
        return 0;
    } else {
        long long v = (long long) x * (long long) n;
        return (scaled) (v / d); 
    }
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
scaled tex_round_xn_over_d(scaled x, int n, unsigned int d)
{
    if (x == 0) {
        return 0;
    } else if (n == d) {
        return x;
    } else {
        int positive = 1;
        unsigned t, u, v;
        if (x < 0) {
            positive = ! positive;
            x = -x;
        }
        if (n < 0) {
            positive = ! positive;
            n = -n;
        }
        t = (unsigned) ((x % 0100000) * n);
        u = (unsigned) (((unsigned) (x) / 0100000) * (unsigned) n + (t / 0100000));
        v = (u % d) * 0100000 + (t % 0100000);
        if (u / d >= 0100000) {
            scanner_state.arithmic_error = 1;
        } else {
            u = 0100000 * (u / d) + (v / d);
        }
        v = v % d;
        if (2 * v >= d) {
            u++;
        }
        return positive ? (scaled) u : - (scaled) u;
    }
}
*/

/*
scaled tex_round_xn_over_d(scaled x, int n, unsigned int d)
{
    if (x == 0|| n == d) {
        return x;
    } else {
        double v = (1.0 / d) * n * x;
        return (v < 0.0) ? (int) (v - 0.5) : (int) (v + 0.5);
    }
}
*/

scaled tex_round_xn_over_d(scaled x, int n, unsigned int d)
{
    if (x == 0 || (unsigned int) n == d) {
        return x;
    } else {
        return scaledround((1.0 / d) * n * x);
    }
}

/*tex

    The return value is a decimal number with the point |dd| places from the back, |scaled_out| is
    the number of scaled points corresponding to that.

*/

/* not used:

scaled tex_divide_scaled(scaled s, scaled m, int dd)
{
    if (s == 0) {
        return 0;
    } else {
        scaled q, r;
        int sign = 1;
        if (s < 0) {
            sign = -sign;
            s = -s;
        }
        if (m < 0) {
            sign = -sign;
            m = -m;
        }
        if (m == 0) {
            normal_error("arithmetic", "divided by zero");
        } else if (m >= (max_integer / 10)) {
            normal_error("arithmetic", "number too big");
        }
        q = s / m;
        r = s % m;
        for (int i = 1; i <= (int) dd; i++) {
            q = 10 * q + (10 * r) / m;
            r =          (10 * r) % m;
        }
        if (2 * r >= m) {
            q++; // rounding
        }
        return sign * q;
    }
}
*/

/*
scaled divide_scaled_n(double sd, double md, double n)
{
    scaled di = 0;
    double dd = sd / md * n;
    if (dd > 0.0) {
        di =  ifloor(  dd  + 0.5);
    } else if (dd < 0.0) {
        di = -ifloor((-dd) + 0.5);
    }
    return di;
}
*/

scaled tex_divide_scaled_n(double sd, double md, double n)
{
    return scaledround(sd / md * n);
}

/*
scaled tex_ext_xn_over_d(scaled x, scaled n, scaled d)
{
    double r = (((double) x) * ((double) n)) / ((double) d);
    if (r > DBL_EPSILON) {
        r += 0.5;
    } else {
        r -= 0.5;
    }
    if (r >= (double) max_integer || r <= -(double) max_integer) {
        tex_normal_warning("internal", "arithmetic number too big");
    }
    return (scaled) r;
}
*/

scaled tex_ext_xn_over_d(scaled x, scaled n, scaled d)
{
    double r = (((double) x) * ((double) n)) / ((double) d);
    if (r >= (double) max_integer || r <= -(double) max_integer) {
        /* can we really run into this? */
        tex_normal_warning("internal", "arithmetic number too big");
    }
    return scaledround(r);
}
