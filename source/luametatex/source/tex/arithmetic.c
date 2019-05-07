/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    The principal computations performed by \TEX\ are done entirely in terms of
    integers less than $2^{31}$ in magnitude; and divisions are done only when
    both dividend and divisor are nonnegative. Thus, the arithmetic specified in
    this program can be carried out in exactly the same way on a wide variety of
    computers, including some small ones. Why? Because the arithmetic
    calculations need to be spelled out precisely in order to guarantee that
    \TEX\ will produce identical output on different machines. If some quantities
    were rounded differently in different implementations, we would find that
    line breaks and even page breaks might occur in different places. Hence the
    arithmetic of \TEX\ has been designed with care, and systems that claim to be
    implementations of \TEX82 should follow precisely the \TEX82\ calculations as
    they appear in the present program.

    Actually there are three places where \TEX\ uses |div| with a possibly
    negative numerator. These are harmless; see |div| in the index. Also if the
    user sets the |\time| or the |\year| to a negative value, some diagnostic
    information will involve negative|-|numerator division. The same remarks apply
    for |mod| as well as for |div|.

    Here is a routine that calculates half of an integer, using an unambiguous
    convention with respect to signed odd numbers.

    Somehow this doesn't work:

    \starttyping
    # define half(x) (odd(x) ? ((x + 1) / 2) : (x / 2))
    \stoptyping
*/

int half(int x)
{
    if (odd(x))
        return ((x + 1) / 2);
    else
        return (x / 2);
}

/*tex

    The following function is used to create a scaled integer from a given
    decimal fraction $(.d_0d_1\ldots d_{k-1})$, where |0 <= k <= 17|. The digit
    $d_i$ is given in |dig[i]|, and the calculation produces a correctly rounded
    result.

*/

scaled round_decimals(int k)
{
    int a = 0;
    while (k-- > 0) {
        a = (a + dig[k] * two) / 10;
    }
    return ((a + 1) / 2);
}

/*tex

    Conversely, here is a procedure analogous to |print_int|. If the output of
    this procedure is subsequently read by \TEX\ and converted by the
    |round_decimals| routine above, it turns out that the original value will be
    reproduced exactly; the \quote {simplest} such decimal number is output, but
    there is always at least one digit following the decimal point.

    The invariant relation in the |repeat| loop is that a sequence of decimal
    digits yet to be printed will yield the original number if and only if they
    form a fraction~$f$ in the range $s-\delta\L10\cdot2^{16}f<s$. We can stop if
    and only if $f=0$ satisfies this condition; the loop will terminate before
    $s$ can possibly become zero.

    The next one prints a scaled real, rounded to five digits.

*/

void print_scaled(scaled s)
{
    /*tex The amount of allowable inaccuracy: */
    scaled delta;
    char buffer[20];
    int i = 0;
    if (s < 0) {
        /*tex Print the sign, if negative. */
        print_char('-');
        negate(s);
    }
    /*tex Print the integer part. */
    print_int(s / unity);
    buffer[i++] = '.';
    s = 10 * (s % unity) + 5;
    delta = 10;
    do {
        if (delta > unity) {
            /*tex Round the last digit. */
            s = s + 0100000 - 50000;
        }
        buffer[i++] = '0' + (s / unity);
        s = 10 * (s % unity);
        delta = delta * 10;
    } while (s > delta);
    buffer[i++] = '\0';
    tprint(buffer);
}

/*tex

    Physical sizes that a \TEX\ user specifies for portions of documents are
    represented internally as scaled points. Thus, if we define an `sp' (scaled
    point) as a unit equal to $2^{-16}$ printer's points, every dimension inside
    of \TEX\ is an integer number of sp. There are exactly 4,736,286.72 sp per
    inch. Users are not allowed to specify dimensions larger than $2^{30}-1$ sp,
    which is a distance of about 18.892 feet (5.7583 meters); two such quantities
    can be added without overflow on a 32-bit computer.

    The present implementation of \TEX\ does not check for overflow when
    dimensions are added or subtracted. This could be done by inserting a few
    dozen tests of the form |if x >= 010000000000| then |report_overflow|, but
    the chance of overflow is so remote that such tests do not seem worthwhile.

    \TEX\ needs to do only a few arithmetic operations on scaled quantities,
    other than addition and subtraction, and the following subroutines do most of
    the work. A single computation might use several subroutine calls, and it is
    desirable to avoid producing multiple error messages in case of arithmetic
    overflow; so the routines set the global variable |arith_error| to |true|
    instead of reporting errors directly to the user. Another global variable,
    |tex_remainder|, holds the remainder after a division.

    The first arithmetical subroutine we need computes $nx+y$, where |x| and~|y|
    are |scaled| and |n| is an integer. We will also use it to multiply integers.

*/

scaled mult_and_add(int n, scaled x, scaled y, scaled max_answer)
{
    if (n == 0) {
        return y;
    } else {
        if (n < 0) {
            negate(x);
            negate(n);
        }
        if (((x <= (max_answer - y) / n) && (-x <= (max_answer + y) / n))) {
            return (n * x + y);
        } else {
            scanner_state.arith_error = 1;
            return 0;
        }
    }
}

/*tex We also need to divide scaled dimensions by integers. */

scaled x_over_n(scaled x, int n)
{
    /*tex Should |tex_remainder| be negated? */
    int negative = 0;
    if (n == 0) {
        scanner_state.arith_error = 1;
        scanner_state.tex_remainder = x;
        return 0;
    } else {
        if (n < 0) {
            negate(x);
            negate(n);
            negative = 1;
        }
        if (x >= 0) {
            scanner_state.tex_remainder = x % n;
            if (negative)
                negate(scanner_state.tex_remainder);
            return (x / n);
        } else {
            scanner_state.tex_remainder = -((-x) % n);
            if (negative)
                negate(scanner_state.tex_remainder);
            return (-((-x) / n));
        }
    }
}

/*tex

    Then comes the multiplication of a scaled number by a fraction |n/d|, where
    |n| and |d| are nonnegative integers |<=@t$2^{16}$@>| and |d| is positive. It
    would be too dangerous to multiply by~|n| and then divide by~|d|, in separate
    operations, since overflow might well occur; and it would be too inaccurate
    to divide by |d| and then multiply by |n|. Hence this subroutine simulates
    1.5-precision arithmetic.

*/

scaled xn_over_d(scaled x, int n, int d)
{
    nonnegative_integer t, u, v, xx, dd;
    int positive = 1;
    if (x < 0) {
        negate(x);
        positive = 0;
    }
    xx = (nonnegative_integer) x;
    dd = (nonnegative_integer) d;
    t = ((xx % 0100000) * (nonnegative_integer) n);
    u = ((xx / 0100000) * (nonnegative_integer) n + (t / 0100000));
    v = (u % dd) * 0100000 + (t % 0100000);
    if (u / dd >= 0100000)
        scanner_state.arith_error = 1;
    else
        u = 0100000 * (u / dd) + (v / dd);
    if (positive) {
        scanner_state.tex_remainder = (int) (v % dd);
        return (scaled) u;
    } else {
        /*tex The casts are for ms cl. */
        scanner_state.tex_remainder = -(int) (v % dd);
        return -(scaled) (u);
    }
}

/*tex

    The next subroutine is used to compute the badness of glue, when a total |t|
    is supposed to be made from amounts that sum to~|s|. According to {\em The
    \TEX book}, the badness of this situation is $100(t/s)^3$; however, badness
    is simply a heuristic, so we need not squeeze out the last drop of accuracy
    when computing it. All we really want is an approximation that has similar
    properties.

    The actual method used to compute the badness is easier to read from the
    program than to describe in words. It produces an integer value that is a
    reasonably close approximation to $100(t/s)^3$, and all implementations of
    \TEX\ should use precisely this method. Any badness of $2^{13}$ or more is
    treated as infinitely bad, and represented by 10000.

    It is not difficult to prove that $$\hbox{|badness(t+1,s)>=badness(t,s) >=
    badness(t,s+1)|}.$$ The badness function defined here is capable of computing
    at most 1095 distinct values, but that is plenty.

*/

halfword badness(scaled t, scaled s)
{
    /*tex Approximation to $\alpha t/s$, where $\alpha^3\approx 100\cdot2^{18}$ */
    if (t == 0) {
        return 0;
    } else if (s <= 0) {
        return inf_bad;
    } else {
        int r;
        /*tex $297^3=99.94\times2^{18}$ */
        if (t <= 7230584) {
            r = (t * 297) / s;
        } else if (s >= 1663497) {
            r = t / (s / 297);
        } else {
            r = t;
        }
        if (r > 1290) {
            /*tex $1290^3<2^{31}<1291^3$ */
            return inf_bad;
        } else {
            /*tex This is $r^3/2^{18}$, rounded to the nearest integer. */
            return ((r * r * r + 0400000) / 01000000);
        }
    }
}

/*tex

    When \TEX\ packages a list into a box, it needs to calculate the
    proportionality ratio by which the glue inside the box should stretch or
    shrink. This calculation does not affect \TEX's decision making, so the
    precise details of rounding, etc., in the glue calculation are not of
    critical importance for the consistency of results on different computers.

    We shall use the type |glue_ratio| for such proportionality ratios. A glue
    ratio should take the same amount of memory as an |integer| (usually 32 bits)
    if it is to blend smoothly with \TEX's other data structures. Thus
    |glue_ratio| should be equivalent to |short_real| in some implementations of
    \PASCAL. Alternatively, it is possible to deal with glue ratios using nothing
    but fixed-point arithmetic; see {\em TUGboat \bf3},1 (March 1982), 10--27.
    (But the routines cited there must be modified to allow negative glue
    ratios.)

*/

scaled round_xn_over_d(scaled x, int n, unsigned int d)
{
    int positive = 1;
    unsigned t, u, v;
    if (x < 0) {
        positive = !positive;
        x = -(x);
    }
    if (n < 0) {
        positive = !positive;
        n = -(n);
    }
    t = (unsigned) ((x % 0100000) * n);
    u = (unsigned) (((unsigned) (x) / 0100000) * (unsigned) n + (t / 0100000));
    v = (u % d) * 0100000 + (t % 0100000);
    if (u / d >= 0100000)
        scanner_state.arith_error = 1;
    else
        u = 0100000 * (u / d) + (v / d);
    v = v % d;
    if (2 * v >= d)
        u++;
    if (positive)
        return (scaled) u;
    else
        return (-(scaled) u);
}

/*tex

    The return value is a decimal number with the point |dd| places from the
    back, |scaled_out| is the number of scaled points corresponding to that.

*/

scaled divide_scaled(scaled s, scaled m, int dd)
{
    scaled q, r;
    int i;
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
    for (i = 1; i <= (int) dd; i++) {
        q = 10 * q + (10 * r) / m;
        r = (10 * r) % m;
    }
    /*tex Rounding: */
    if (2 * r >= m) {
        q++;
    }
    return sign * q;
}

scaled divide_scaled_n(double sd, double md, double n)
{
    double dd, di = 0.0;
    dd = sd / md * n;
    if (dd > 0.0)
        di = floor(dd + 0.5);
    else if (dd < 0.0)
        di = -floor((-dd) + 0.5);
    return (scaled) di;
}

scaled ext_xn_over_d(scaled x, scaled n, scaled d)
{
    double r = (((double) x) * ((double) n)) / ((double) d);
    if (r > DBL_EPSILON) /* from float.h */
        r += 0.5;
    else
        r -= 0.5;
    if (r >= (double) max_integer || r <= -(double) max_integer)
        normal_warning("internal","arithmetic number too big");
    return (scaled) r;
}
