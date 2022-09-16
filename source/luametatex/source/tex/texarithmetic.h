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
extern scaled tex_x_over_n_r        (scaled x, int n, int *remainder);
extern scaled tex_x_over_n          (scaled x, int n);
extern scaled tex_xn_over_d         (scaled x, int n, int d);
extern scaled tex_xn_over_d_r       (scaled x, int n, int d, int *remainder);
/*     scaled tex_divide_scaled     (scaled s, scaled m, int dd); */
extern scaled tex_divide_scaled_n   (double s, double m, double d);
extern scaled tex_ext_xn_over_d     (scaled, scaled, scaled);
extern scaled tex_round_xn_over_d   (scaled x, int n, unsigned int d);

inline static scaled tex_round_decimals_digits(const unsigned char *digits, unsigned k)
{
     int a = 0;
     while (k-- > 0) {
         a = (a + digits[k] * two) / 10;
     }
     return (a + 1) / 2;
}

inline static int tex_half_scaled(int x)
{
    return odd(x) ? ((x + 1) / 2) : (x / 2);
}

# endif
