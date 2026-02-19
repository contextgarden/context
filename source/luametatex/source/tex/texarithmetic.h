/*
    See license.txt in the root of this project.
*/

# ifndef LMT_ARITHMETIC_H
# define LMT_ARITHMETIC_H

/*tex

    Fixed-point arithmetic is done on {\em scaled integers} that are multiples of $2^{-16}$. In
    other words, a binary point is assumed to be sixteen bit positions from the right end of a
    binary computer word.

*/

extern scaled tex_multiply_and_add  (int n, scaled x, scaled y, scaled max_answer);
extern scaled tex_nx_plus_y         (int n, scaled x, scaled y);
extern scaled tex_multiply_integers (int n, scaled x);
extern scaled tex_x_over_n_r        (scaled x, int n, int *remainder);        /* used once */
extern scaled tex_x_over_n          (scaled x, int n);                        /* used a few times, maybe use scaledround instead to prevent wrap around */
extern scaled tex_x_over_n_unity    (scaled x);                               /* not used */
extern scaled tex_x_over_n_factor   (scaled x);                               /* rarely used */
extern scaled tex_xn_over_d_r       (scaled x, int n, int d, int *remainder); /* seldom kicks in */
/*     scaled tex_xn_over_d         (scaled x, int n, int d);     */          /* inlined */
/*     scaled tex_xn_over_d_unity   (scaled x, int n);            */          /* inlined */
/*     scaled tex_xn_over_d_factor  (scaled x, int n);            */          /* inlined */
/*     scaled tex_divide_scaled     (scaled s, scaled m, int dd); */          /* inlined */
extern scaled tex_divide_scaled_n   (double s, double m, double d);
extern scaled tex_ext_xn_over_d     (scaled x, scaled n, scaled d);
extern scaled tex_round_xn_over_d   (scaled x, int n, unsigned int d);

static inline scaled tex_round_decimals_digits(const unsigned char *digits, unsigned k)
{
     int a = 0;
     while (k-- > 0) {
         a = (a + digits[k] * two) / 10;
     }
     return (a + 1) / 2;
}

static inline int tex_half_scaled(int x)
{
    return odd(x) ? ((x + 1) / 2) : (x / 2);
}

extern scaled tex_nx_plus_y_posit(halfword p, scaled x, scaled y);

/* */

static inline scaled tex_xn_over_d(scaled x, int n, int d)
{
    if (x == 0) {
        return 0;
    } else {
        long long v = (long long) x * (long long) n;
        return (scaled) (v / d);
    }
}

static inline scaled tex_xn_over_d_unity(scaled x, int n)
{
    if (x == 0) {
        return 0;
    } else {
        long long v = (long long) x * (long long) n;
        return (scaled) (v / unity);
    }
}



static inline scaled tex_xn_over_d_factor(scaled x, int n)
{
    if (x == 0) {
        return 0;
    } else {
        long long v = (long long) x * (long long) n;
        return (scaled) (v / scaling_factor);
    }
}

# endif
