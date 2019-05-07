/*
    See license.txt in the root of this project.
*/

# ifndef ARITHMETIC_H
# define ARITHMETIC_H

# undef half
# undef negate

# define negate(A) (A)=-(A) /*tex change the sign of a variable */

extern int half(int x);

/*tex

Fixed-point arithmetic is done on {\em scaled integers} that are multiples of
$2^{-16}$. In other words, a binary point is assumed to be sixteen bit positions
from the right end of a binary computer word.

*/

# define unity   0200000 /*tex $2^{16}$, represents 1.00000 */
# define two     0400000 /*tex $2^{17}$, represents 2.00000 */
# define inf_bad   10000 /*tex infinitely bad value */

typedef unsigned int nonnegative_integer; /*tex $0\L x<2^{31}$ */

/*tex These two are part of the scanner_state:

\starttyping
extern int arith_error;
extern scaled tex_remainder;
\stoptyping
*/

extern scaled round_decimals(int k);
extern void print_scaled(scaled s);

extern scaled mult_and_add(int n, scaled x, scaled y, scaled max_answer);

# define nx_plus_y(A,B,C) mult_and_add((A),(B),(C),07777777777)
# define mult_integers(A,B) mult_and_add((A),(B),0,017777777777)

extern scaled x_over_n(scaled x, int n);
extern scaled xn_over_d(scaled x, int n, int d);

extern halfword badness(scaled t, scaled s);

# define set_glue_ratio_zero(A) (A)=0.0  /*tex store the representation of zero ratio */
# define set_glue_ratio_one(A) (A)=1.0   /*tex store the representation of unit ratio */
# define float_cast(A) (float)(A)        /*tex convert from |glue_ratio| to type |real| */
# define unfloat(A) (glue_ratio)(A)      /*tex convert from |real| to type |glue_ratio| */
# define float_constant(A) (float)A      /*tex convert |integer| constant to |real| */

/* # define float_round round */

extern scaled divide_scaled(scaled s, scaled m, int dd);
extern scaled divide_scaled_n(double s, double m, double d);
extern scaled ext_xn_over_d(scaled, scaled, scaled);
extern scaled round_xn_over_d(scaled x, int n, unsigned int d);

# endif
