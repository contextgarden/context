/*tex

    This is just an exercise to see what is involved in using an interval number system. We use a
    relative simple library, the one we also use in \LUA. There are a few concepts that are not
    really available in the interval concept so in the end it makes little sense. So it currently
    is just a few hours untested and unfinished coding. Implementation wise it's a bit of a mix
    between double, posit and decimal so kind of a mess but that might eventually be resolved. One
    has to realize that conditions don't work as expected, here is a test:

    \starttyping
    \startMPextensions
        primarydef a ~ b =
            abs(a - b) < epsilon
        enddef ;
    \stopMPextensions

    \startMPpage[instance=intervalfun]
        draw image (
            fill fullsquare   scaled 3cm withcolor green ;
            fill fullcircle   scaled 3cm withcolor red ;
            fill fulltriangle scaled 3cm withcolor blue ;
        ) rotated 10 ;
        numeric n ; n := 3 ;
        numeric m ; m := 3 ;
        if n = n : draw textext("\strut \type{n=n}") shifted (0, 10) withcolor .5 ; fi ;
        if n ~ m : draw textext("\strut \type{n~m}") shifted (0,  0) withcolor .5 ; fi ;
        if n = 3 : draw textext("\strut \type{n=3}") shifted (0,-10) withcolor .5 ; fi ;
    \stopMPpage
    \stoptyping

    In order to have this feature you need to rename |mpmathinterval.c| to for instance
    |mpmathinterval-keep.c| and |mpmathexperiment.c| to |mpmathinterval.c|. We currently
    see no reasons to have in on board by default. The main reason anyway for playing
    with this is that interval math was mentioned as possible solution for an accuracy
    issue in scaled mode, one that was solved by using larger integers. In order to deal
    with for instance very close points in to-be-connected paths we already have a few
    new operators, like |&&|, and also \quote {double} calculations are already rather
    roundtrip.

    Remark: in stock \METAPOST\ we have scaled, double, binary, decimal and (work in
    progress) interval. In the library used in \LUAMETATEX\ we dropped binary, added
    posit and now an optional interval. The interval that we use is not the same as in
    stock \METAPOST: where \LUA\ decimal support started from \METAPOST\ decimal, for
    interval it is the reverse, we started with a \LUA\ interval module. I didn't look
    into the other interval plugin yet (it uses mpfr) and just modelled the \LUAMETATEX\
    one after decimal, posit and double; the code bases are just too different by now.

    Once interval is stable in stock \METAPOST\ I'll check it but first we need examples
    where it really makes senst to use it. At that moment we will decide to go forward
    with this or not.

*/

# include "mpmathinterval.h"

# include <fi_lib.h>

# define  mp_fraction_multiplier    4096
# define  mp_angle_multiplier       16

# define  mp_interval_epsilon       pow(2.0,-52.0)
# define  mp_interval_warning_limit pow(2.0, 52.0)
# define  mp_interval_double_max    DBL_MAX // 1e17
# define  mp_interval_double_min    DBL_MIN // 1e-17

# define  two_to_the(A)  (1 << (unsigned)(A))
# define  set_cur_cmd(A) mp->cur_mod_->command = (A)
# define  set_cur_mod(A) memcpy(mp->cur_mod_->data.n.data.num, &(A), sizeof(interval))

typedef interval * inum;

# define to_internum(num) (interval) { ((inum) (num))->INF, ((inum) (num))->SUP }

static inline interval to_interval(const mp_number *i)
{
    return (interval) { ((inum) (i->data.num))->INF, ((inum) (i->data.num))->SUP };
}

static inline interval to_constant(const double c)
{
    return (interval) { c, c };
}

static inline inum mp_new_inum(const interval i)
{
    inum num = mp_memory_allocate(sizeof(interval));
    memcpy(num, &i, sizeof(interval));
    return num;
}

static inline interval interval_neg(const interval i)
{
    return (interval) { - i.SUP, - i.INF };
}

static inline interval interval_mod(const interval a, const interval b)
{
    if (b.INF <= 0.0 && b.SUP >= 0.0) {
        return (interval){ -mp_interval_double_max, mp_interval_double_max };
    }
    double d;
    interval i = div_ii(a, b);
    i.INF = modf(i.INF, &d);
    i.SUP = modf(i.SUP, &d);
    return mul_ii(i, b);
}

# define interval_trace_compare_eq 0
# define interval_trace_compare_gt 0
# define interval_trace_compare_lt 0

static inline int interval_eq(const interval a, const interval b)
{
    # if interval_trace_compare_eq
        printf("EQ [%3.24g %3.24g] [%3.24g %3.24g] %i\n",a.INF,a.SUP,b.INF,b.SUP,a.INF == b.INF && a.SUP == b.SUP);
    # endif
    return a.INF == b.INF && a.SUP == b.SUP;
}

static inline int interval_gt(const interval a, const interval b)
{
    # if interval_trace_compare_gt
        printf("GT [%3.24g %3.24g] [%3.24g %3.24g] %i\n",a.INF,a.SUP,b.INF,b.SUP,a.INF > b.SUP);
    # endif
    return a.INF > b.SUP;
}

static inline int interval_lt(const interval a, const interval b)
{
    # if interval_trace_compare_lt
        printf("LT [%3.24g %3.24g] [%3.24g %3.24g] %i\n",a.INF,a.SUP,b.INF,b.SUP,a.SUP < b.INF);
    # endif
    return a.SUP < b.INF;
}

static inline int interval_ge(const interval a, const interval b)
{
    return interval_gt(a,b) || interval_eq(a,b);
}

static inline int interval_le(const interval a, const interval b)
{
    return interval_lt(a,b) || interval_eq(a,b);
}

typedef struct mp_interval_info {
    interval unity;
    interval zero;
    interval one;
    interval two;
    interval three;
    interval four;
    interval five;
    interval eight;
    interval seven;
    interval sixteen;
    interval half_unit;
    interval minusone;
    interval three_quarter_unit;
    interval d16;
    interval d64;
    interval d256;
    interval d4096;
    interval d65536;
    interval dp90;
    interval dp180;
    interval dp270;
    interval dp360;
    interval dm90;
    interval dm180;
    interval dm270;
    interval dm360;
    interval fraction_multiplier;
    interval negative_fraction_multiplier; /* todo: also in decimal */
    interval angle_multiplier;
    interval fraction_one;
    interval fraction_two;
    interval fraction_three;
    interval fraction_four;
    interval fraction_half;
    interval fraction_one_and_half;
    interval one_eighty_degrees;
    interval negative_one_eighty_degrees;
    interval three_sixty_degrees;
    interval no_crossing;
    interval one_crossing;
    interval zero_crossing;
    interval error_correction;
    interval pi;
    interval pi_divided_by_180;
    interval epsilon;
    interval EL_GORDO;
    interval negative_EL_GORDO;
    interval one_third_EL_GORDO;
    interval coef;
    interval coef_bound;
    interval scaled_threshold;
    interval fraction_threshold;
    interval equation_threshold;
    interval near_zero_angle;
    interval p_over_v_threshold;
    interval warning_limit;
    interval sqrt_two_mul_fraction_one;
    interval sqrt_five_minus_one_mul_fraction_one_and_half;
    interval three_minus_sqrt_five_mul_fraction_one_and_half;
    interval d180_divided_by_pi_mul_angle;
    int      initialized;
} mp_interval_info;

static mp_interval_info mp_interval_data = {
    .initialized = 0,
};

static inline interval mp_interval_aux_make_fraction (const interval p, const interval q) { return mul_id(div_ii(p,q), mp_fraction_multiplier); }
static inline interval mp_interval_aux_take_fraction (const interval p, const interval q) { return div_id(mul_ii(p,q), mp_fraction_multiplier); }
static inline interval mp_interval_aux_make_scaled   (const interval p, const interval q) { return div_ii(p,q); }

/*tex Here we don't optimize for zero's. */

static inline interval mp_interval_make_fraction(const interval p, const interval q)
{
    return mul_id(div_ii(p, q), mp_fraction_multiplier);
}

static inline interval mp_interval_take_fraction(const interval p, const interval q)
{
    return div_id(mul_ii(p, q), mp_fraction_multiplier);
}

static inline interval mp_interval_make_scaled(const interval p, const interval q)
{
    /* probably not ok, see usage */
    return div_ii(p, q);
}

static void mp_interval_allocate_number(MP mp, mp_number *n, mp_number_type t)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(to_constant(0));
}

static void mp_interval_allocate_clone(MP mp, mp_number *n, mp_number_type t, const mp_number *v)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(to_interval(v));
}

static void mp_interval_allocate_abs(MP mp, mp_number *n, mp_number_type t, const mp_number *v)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(j_abs(to_interval(v)));
}

static void mp_interval_allocate_div(MP mp, mp_number *n, mp_number_type t, const mp_number *a, const mp_number *b)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(div_ii(to_interval(a), to_interval(b)));
}

static void mp_interval_allocate_mul(MP mp, mp_number *n, mp_number_type t, const mp_number *a, const mp_number *b)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(mul_ii(to_interval(a), to_interval(b)));
}

static void mp_interval_allocate_add(MP mp, mp_number *n, mp_number_type t, const mp_number *a, const mp_number *b)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(add_ii(to_interval(a), to_interval(b)));
}

static void mp_interval_allocate_sub(MP mp, mp_number *n, mp_number_type t, const mp_number *a, const mp_number *b)
{
    (void) mp;
    n->type = t;
    n->data.num = mp_new_inum(sub_ii(to_interval(a), to_interval(b)));
}

static void mp_interval_allocate_double(MP mp, mp_number *n, const double v)
{
    (void) mp;
    n->type = mp_scaled_type;
    n->data.num = mp_new_inum(to_constant(v));
}

static void mp_interval_free_number(MP mp, mp_number *n)
{
    (void) mp;
    if (n->data.num) {
        mp_memory_free(n->data.num);
        n->data.num = NULL;
    }
    n->type = mp_nan_type;
}

static inline void mp_interval_set_from_int(mp_number *a, const mp_scaled_t b)
{
    interval i = { (double) b, (double) b };
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_boolean(mp_number *a, const mp_scaled_t b)
{
    interval i = { (double) b, (double) b };
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_scaled(mp_number *a, const mp_scaled_t b)
{
    double d = b == 0 ? 0.0 : b / 65536.0;
    interval i = { d, d };
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_double(mp_number *a, const double b)
{
    interval i = { b, b };
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_addition(mp_number *a, const mp_number *b, const mp_number *c)
{
    interval i = add_ii(to_interval(b), to_interval(c));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_half_from_addition(mp_number *a, const mp_number *b, const mp_number *c)
{
    interval i = div_id(add_ii(to_interval(b), to_interval(c)), 2.0);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_subtraction(mp_number *a, const mp_number *b, const mp_number *c)
{
    interval i = sub_ii(to_interval(b), to_interval(c));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_half_from_subtraction(mp_number *a, const mp_number *b, const mp_number *c)
{
    interval i = div_id(sub_ii(to_interval(b), to_interval(c)), 2.0);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_div(mp_number *a, const mp_number *b, const mp_number *c)
{
    interval i = div_ii(to_interval(b), to_interval(c));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_mul(mp_number *a, const mp_number *b, const mp_number *c)
{
    interval i = mul_ii(to_interval(b), to_interval(c));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_int_div(mp_number *a, const mp_number *b, const mp_scaled_t c)
{
    interval i = div_id(to_interval(b), c);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_int_mul(mp_number *a, const mp_number *b, const mp_scaled_t c)
{
    interval i = mul_id(to_interval(b), c);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_set_from_of_the_way(MP mp, mp_number *a, const mp_number *t, const mp_number *b, const mp_number *c)
{
    (void) mp;
    interval d = sub_ii(to_interval(b), to_interval(c));
    interval i = sub_ii(to_interval(b), mp_interval_take_fraction(d, to_interval(t)));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_negate(mp_number *a)
{
    interval i = interval_neg(to_interval(a));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_add(mp_number *a, const mp_number *b)
{
    interval i = add_ii(to_interval(a), to_interval(b));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_subtract(mp_number *a, const mp_number *b)
{
    interval i = sub_ii(to_interval(a), to_interval(b));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_half(mp_number *a)
{
    interval i = div_id(to_interval(a), 2.0);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_double(mp_number *a)
{
    interval i = mul_id(to_interval(a), 2.0);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_add_scaled(mp_number *a, const mp_scaled_t b)
{
    interval i = add_id(to_interval(a), b / 65536.0);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_multiply_int(mp_number *a, const mp_scaled_t b)
{
    interval i = mul_id(to_interval(a), b);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_divide_int(mp_number *a, const mp_scaled_t b)
{
    interval i = div_id(to_interval(a), b);
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_abs(mp_number *a)
{
    interval i = j_abs(to_interval(a));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_clone(mp_number *a, const mp_number *b)
{
    if (!a->data.num) {
        a->data.num = mp_new_inum(to_interval(b));
    } else {
        memcpy(a->data.num, b->data.num, sizeof(interval));
    }
}

static inline void mp_interval_negated_clone(mp_number *a, const mp_number *b)
{
    interval i = interval_neg(to_interval(b));
    if (!a->data.num) {
        a->data.num = mp_new_inum(i);
    } else {
        memcpy(a->data.num, &i, sizeof(interval));
    }
}

static inline void mp_interval_abs_clone(mp_number *a, const mp_number *b)
{
    interval i = j_abs(to_interval(b));
    if (!a->data.num) {
        a->data.num = mp_new_inum(i);
    } else {
        memcpy(a->data.num, &i, sizeof(interval));
    }
}

static inline void mp_interval_swap(mp_number *a, mp_number *b)
{
    interval swap_tmp = to_interval(a);
    memcpy(a->data.num, b->data.num, sizeof(interval));
    memcpy(b->data.num, &swap_tmp, sizeof(interval));
}

static inline void mp_interval_fraction_to_scaled(mp_number *a)
{
    interval i = div_id(to_interval(a), mp_fraction_multiplier);
    memcpy(a->data.num, &i, sizeof(interval));
    a->type = mp_scaled_type;
}

static inline void mp_interval_angle_to_scaled(mp_number *a)
{
    interval i = div_id(to_interval(a), mp_angle_multiplier);
    memcpy(a->data.num, &i, sizeof(interval));
    a->type = mp_scaled_type;
}

static inline void mp_interval_scaled_to_fraction(mp_number *a)
{
    interval i = mul_id(to_interval(a), mp_fraction_multiplier);
    memcpy(a->data.num, &i, sizeof(interval));
    a->type = mp_fraction_type;
}

static inline void mp_interval_scaled_to_angle(mp_number *a)
{
    interval i = mul_id(to_interval(a), mp_angle_multiplier);
    memcpy(a->data.num, &i, sizeof(interval));
    a->type = mp_angle_type;
}

static inline mp_scaled_t mp_interval_to_scaled(const mp_number *a)
{
    return (mp_scaled_t) mpscaledround(q_mid(to_interval(a)) * 65536.0);
}

static inline mp_scaled_t mp_interval_to_int(const mp_number *a)
{
    return (mp_scaled_t) q_mid(to_interval(a));
}

static inline mp_scaled_t mp_interval_to_boolean(const mp_number *a)
{
    return (mp_scaled_t) q_mid(to_interval(a));
}

static inline double mp_interval_to_double(const mp_number *a)
{
    return q_mid(to_interval(a));
}

static inline int mp_interval_odd(const mp_number *a)
{
    return odd_long(lround(q_mid(to_interval(a))));
}

static inline int mp_interval_equal(const mp_number *a, const mp_number *b)
{
    return interval_eq(to_interval(a), to_interval(b));
}

static inline int mp_interval_greater(const mp_number *a, const mp_number *b)
{
    return interval_gt(to_interval(a), to_interval(b));
}

static inline int mp_interval_less(const mp_number *a, const mp_number *b)
{
    return interval_lt(to_interval(a), to_interval(b));
}

static inline int mp_interval_non_equal_abs(const mp_number *a, const mp_number *b)
{
    return ! interval_eq(j_abs(to_interval(a)), j_abs(to_interval(b)));
}

static char *mp_interval_number_tostring(MP mp, const mp_number *n)
{
    static char set[64];
    int l = 0;
    char *ret = mp_memory_allocate(64);
    (void) mp;
    snprintf(set, 64, mp->less_digits ? "%.3g" : "%.17g", q_mid(to_interval(n)));
    while (set[l] == ' ') {
        l++;
    }
    strcpy(ret, set+l);
    return ret;
}

static void mp_interval_print_number(MP mp, const mp_number *n)
{
    char *str = mp_interval_number_tostring(mp, n);
    mp_print_e_str(mp, str);
    mp_memory_free(str);
}

static inline void mp_interval_slow_add(MP mp, mp_number *ret, const mp_number *x, const mp_number *y)
{
    (void) mp;
    interval i = add_ii(to_interval(x), to_interval(y));
    memcpy(ret->data.num, &i, sizeof(interval));
}

static inline void mp_interval_slow_sub(MP mp, mp_number *ret, const mp_number *x, const mp_number *y)
{
    (void) mp;
    interval i = sub_ii(to_interval(x), to_interval(y));
    memcpy(ret->data.num, &i, sizeof(interval));
}

static inline void mp_interval_number_make_fraction(MP mp, mp_number *ret, const mp_number *p, const mp_number *q)
{
    (void) mp;
    interval i = mp_interval_make_fraction(to_interval(p), to_interval(q));
    memcpy(ret->data.num, &i, sizeof(interval));
}

static inline void mp_interval_number_take_fraction(MP mp, mp_number *ret, const mp_number *p, const mp_number *q)
{
    (void) mp;
    interval i = mp_interval_take_fraction(to_interval(p), to_interval(q));
    memcpy(ret->data.num, &i, sizeof(interval));
}

static inline void mp_interval_number_take_scaled(MP mp, mp_number *ret, const mp_number *p, const mp_number *q)
{
    (void) mp;
    interval i = mul_ii(to_interval(p), to_interval(q));
    memcpy(ret->data.num, &i, sizeof(interval));
}

static inline void mp_interval_number_make_scaled(MP mp, mp_number *ret, const mp_number *p, const mp_number *q)
{
    (void) mp;
    interval i = div_ii(to_interval(p), to_interval(q));
    memcpy(ret->data.num, &i, sizeof(interval));
}

/*tex

    These are the same as double and posit so we need to share them eventually!
*/

/*tex
    The input format is the same as for the C language, so we just collect valid bytes in the
    buffer, then call |strtod()|. It looks like we have no buffer overflow check here.
*/

static void mp_wrapup_numeric_token(MP mp, unsigned char *start, unsigned char *stop)
{
    double result;
    char *end = (char *) stop;
    errno = 0;
    result = strtod((char *) start, &end);
    if (errno == 0) {
        interval i = to_constant(result);
        set_cur_mod(i);
        if (result >= mp_interval_warning_limit) {
         // if (q_mid(to_internum(internal_value(mp_warning_check_internal).data.num)) > 0 && (mp->scanner_status != mp_tex_flushing_state)) {
            if (q_mid(to_internum(internal_value(mp_warning_check_internal).data.num)) > 0) {
                char msg[256];
                snprintf(msg, 256, "Number is too large (%g)", result);
                mp_error(
                    mp,
                    msg,
                    "Continue and I'll try to cope with that big value; but it might be dangerous."
                    "(Set warningcheck := 0 to suppress this message.)"
                );
            }
        }
 // } else if (mp->scanner_status != mp_tex_flushing_state) {
    } else {
        mp_error(
            mp,
            "Enormous number has been reduced.",
            "I could not handle this number specification probably because it is out of"
            "range."
        );
        set_cur_mod(mp_interval_data.EL_GORDO);
    }
    set_cur_cmd(mp_numeric_command);
}

static void mp_interval_aux_find_exponent(MP mp)
{
    if (mp->buffer[mp->cur_input.loc_field] == 'e' || mp->buffer[mp->cur_input.loc_field] == 'E') {
        mp->cur_input.loc_field++;
        if (!(mp->buffer[mp->cur_input.loc_field] == '+'
           || mp->buffer[mp->cur_input.loc_field] == '-'
           || mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class)) {
            mp->cur_input.loc_field--;
            return;
        }
        if (mp->buffer[mp->cur_input.loc_field] == '+'
         || mp->buffer[mp->cur_input.loc_field] == '-') {
            mp->cur_input.loc_field++;
        }
        while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
            mp->cur_input.loc_field++;
        }
    }
}

static void mp_interval_scan_fractional_token(MP mp, mp_scaled_t n) /* n is scaled */
{
    unsigned char *start = &mp->buffer[mp->cur_input.loc_field -1];
    unsigned char *stop;
    (void) n;
    while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
        mp->cur_input.loc_field++;
    }
    mp_interval_aux_find_exponent(mp);
    stop = &mp->buffer[mp->cur_input.loc_field-1];
    mp_wrapup_numeric_token(mp, start, stop);
}

static void mp_interval_scan_numeric_token(MP mp, mp_scaled_t n)
{
    unsigned char *start = &mp->buffer[mp->cur_input.loc_field -1];
    unsigned char *stop;
    (void) n;
    while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
        mp->cur_input.loc_field++;
    }
    if (mp->buffer[mp->cur_input.loc_field] == '.' && mp->buffer[mp->cur_input.loc_field+1] != '.') {
        mp->cur_input.loc_field++;
        while (mp->char_class[mp->buffer[mp->cur_input.loc_field]] == mp_digit_class) {
            mp->cur_input.loc_field++;
        }
    }
    mp_interval_aux_find_exponent(mp);
    stop = &mp->buffer[mp->cur_input.loc_field-1];
    mp_wrapup_numeric_token(mp, start, stop);
}

/*tex
    The similarities end here.
*/

static void mp_interval_velocity(MP mp, mp_number *ret, const mp_number *st, const mp_number *ct, const mp_number *sf, const mp_number *cf, const mp_number *t)
{
    interval sti = to_interval(st);
    interval cti = to_interval(ct);
    interval sfi = to_interval(sf);
    interval cfi = to_interval(cf);
    interval ti  = to_interval(t);
    interval acc, num, denom; /* registers for intermediate calculations */
    (void) mp;
    acc = mp_interval_aux_take_fraction(
        mp_interval_aux_take_fraction(
            sub_ii(sti, div_ii(sfi, mp_interval_data.sixteen)),
            sub_ii(sfi, div_ii(sti, mp_interval_data.sixteen))
        ),
        sub_ii(cti, cfi)
    );
    num = add_ii(
        mp_interval_data.fraction_two,
        mp_interval_aux_take_fraction(
            acc,
            mp_interval_data.sqrt_two_mul_fraction_one
        )
    );
    denom = add_ii(
        mp_interval_data.fraction_three,
        add_ii(
            mp_interval_aux_take_fraction(
                cti,
                mp_interval_data.sqrt_five_minus_one_mul_fraction_one_and_half
            ),
            mp_interval_aux_take_fraction(
                cfi,
                mp_interval_data.three_minus_sqrt_five_mul_fraction_one_and_half
            )
        )
    );
    if (! interval_eq(ti, mp_interval_data.unity)) {
        num = mp_interval_aux_make_scaled(num, ti);
    }
    if (interval_ge(div_ii(num, mp_interval_data.four), denom)) {
        memcpy(ret->data.num, &mp_interval_data.fraction_four, sizeof(interval));
    } else {
        ti = mp_interval_aux_make_fraction(num, denom);
        memcpy(ret->data.num, &ti, sizeof(interval));
    }
}

static inline int mp_interval_ab_vs_cd(const mp_number *a_orig, const mp_number *b_orig, const mp_number *c_orig, const mp_number *d_orig)
{
    interval ab = mul_ii(to_interval(a_orig), to_interval(b_orig));
    interval cd = mul_ii(to_interval(c_orig), to_interval(d_orig));
    if (interval_gt(ab, cd)) {
        return 1;
    } else if (interval_lt(ab, cd)) {
        return -1;
    } else {
        return 0;
    }
}

static void mp_interval_crossing_point(MP mp, mp_number *ret, const mp_number *aa, const mp_number *bb, const mp_number *cc)
{
    interval ai = to_interval(aa);
    interval bi = to_interval(bb);
    interval ci = to_interval(cc);
    (void) mp;
    if (interval_lt(ai, mp_interval_data.zero)) {
        memcpy(ret->data.num, &mp_interval_data.zero_crossing, sizeof(interval));
        return;
    } else if (interval_ge(ci, mp_interval_data.zero)) {
        if (interval_ge(bi, mp_interval_data.zero)) {
            if (interval_gt(ci, mp_interval_data.zero)) {
                memcpy(ret->data.num, &mp_interval_data.no_crossing, sizeof(interval));
            } else if (interval_eq(ai, mp_interval_data.zero) && interval_eq(bi, mp_interval_data.zero)) {
                memcpy(ret->data.num, &mp_interval_data.no_crossing, sizeof(interval));
            } else {
                memcpy(ret->data.num, &mp_interval_data.one_crossing, sizeof(interval));
            }
            return;
        } else if (interval_eq(ai, mp_interval_data.zero)) {
            memcpy(ret->data.num, &mp_interval_data.zero_crossing, sizeof(interval));
            return;
        }
    } else if (interval_eq(ai, mp_interval_data.zero) && interval_le(bi, mp_interval_data.zero)) {
        memcpy(ret->data.num, &mp_interval_data.zero_crossing, sizeof(interval));
        return;
    }
    /* Use bisection to find the crossing point... */
    {
        interval d = mp_interval_data.epsilon;
        interval x0 = ai;
        interval x1 = sub_ii(ai, bi);
        interval x2 = sub_ii(bi, ci);
        do {
            interval x = div_id(add_ii(x1, x2), 2.0 + 1E-12);
            if (interval_gt(sub_ii(x1, x0), x0)) {
                x2 = x;
                x0 = add_ii(x0, x0);
                d = add_ii(d, d);
            } else {
                interval xx = sub_ii(add_ii(x1, x), x0);
                if (interval_gt(xx, x0)) {
                    x2 = x;
                    x0 = add_ii(x0, x0);
                    d = add_ii(d, d);
                } else {
                    x0 = sub_ii(x0, xx);
                    if (interval_le(x, x0) && interval_le(add_ii(x, x2), x0)) {
                        memcpy(ret->data.num, &mp_interval_data.no_crossing, sizeof(interval));
                        return;
                    }
                    x1 = x;
                    d = add_ii(add_ii(d, d), mp_interval_data.epsilon);
                }
            }
        } while (interval_lt(d, mp_interval_data.fraction_one));
        d = sub_ii(d, mp_interval_data.fraction_one);
        memcpy(ret->data.num, &d, sizeof(interval));
    }
}

static inline mp_scaled_t mp_interval_unscaled(const mp_number *v)
{
    return (mp_scaled_t) mpscaledround(q_mid(to_interval(v)));
}

static inline void mp_interval_floor(mp_number *v)
{
    interval i = to_interval(v);
    i.INF = floor(i.INF);
    i.SUP = floor(i.SUP);
}

static inline void mp_interval_fraction_to_round_scaled(mp_number *v)
{
    interval i = div_id(to_interval(v), mp_fraction_multiplier);
    v->type = mp_scaled_type;
    memcpy(v->data.num, &i, sizeof(interval));
}

static void mp_interval_square_rt(MP mp, mp_number *ret, const mp_number *v)
{
    interval i = to_interval(v);
    if (interval_gt(i, mp_interval_data.zero)) {
        i = j_sqrt(i);
        memcpy(ret->data.num, &i, sizeof(interval));
    } else {
        if (interval_lt(i, mp_interval_data.zero)) {
            char msg[256];
            char *str = mp_interval_number_tostring(mp, v);
            snprintf(msg, 256, "Square root of %s has been replaced by 0", str);
            mp_memory_free(str);
            mp_error(
                mp,
                msg,
                "Since I don't take square roots of negative numbers, I'm zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        }
        memcpy(ret->data.num, &(mp_interval_data.zero), sizeof(interval));
    }
}

static void mp_interval_pyth_add(MP mp, mp_number *ret, const mp_number *a, const mp_number *b)
{
    (void) mp;
    interval ia = j_abs(to_interval(a));
    interval ib = j_abs(to_interval(b));
    interval rt = j_sqrt(add_ii(mul_ii(ia, ia), mul_ii(ib, ib)));
    memcpy(ret->data.num, &rt, sizeof(interval));
}

static void mp_interval_pyth_add3(MP mp, mp_number *ret, const mp_number *a, const mp_number *b, const mp_number *c)
{
    (void) mp;
    interval ia = j_abs(to_interval(a));
    interval ib = j_abs(to_interval(b));
    interval ic = j_abs(to_interval(c));
    interval rt = j_sqrt(add_ii(add_ii(mul_ii(ia, ia), mul_ii(ib, ib)), mul_ii(ic, ic)));
    memcpy(ret->data.num, &rt, sizeof(interval));
}

static void mp_interval_pyth_sub(MP mp, mp_number *ret, mp_number *a, const mp_number *b)
{
    interval ia = j_abs(to_interval(a));
    interval ib = j_abs(to_interval(b));
    interval rt;
    if (interval_gt(ia, ib)) {
        rt = j_sqrt(sub_ii(mul_ii(ia, ia), mul_ii(ib, ib)));
        memcpy(ret->data.num, &rt, sizeof(interval));
    } else {
        if (interval_lt(ia, ib)) {
            char msg[256];
            char *astr = mp_interval_number_tostring(mp, a);
            char *bstr = mp_interval_number_tostring(mp, b);
            snprintf(msg, 256, "Pythagorean subtraction %s+-+%s has been replaced by 0", astr, bstr);
            mp_memory_free(astr);
            mp_memory_free(bstr);
            mp_error(
                mp,
                msg,
                "Since I don't take square roots of negative numbers, I'm zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        }
        memcpy(ret->data.num, &(mp_interval_data.zero), sizeof(interval));
    }
}

static void mp_interval_power_of(MP mp, mp_number *ret, const mp_number *a_orig, const mp_number *b_orig)
{
    (void) mp;
    interval ri = j_exp(mul_ii(to_interval(b_orig), j_log(to_interval(a_orig))));
    memcpy(ret->data.num, &(ri), sizeof(interval));
}

static void mp_interval_m_log(MP mp, mp_number *ret, const mp_number *x)
{
    interval i = j_abs(to_interval(x));
    if (interval_gt(i, mp_interval_data.zero)) {
        i = mul_id(j_log(i), 256);
        memcpy(ret->data.num, &i, sizeof(interval));
    } else {
        char msg[256];
        char *str = mp_interval_number_tostring(mp, x);
        snprintf(msg, 256, "Logarithm of %s has been replaced by 0", str);
        mp_memory_free(str);
        mp_error(
            mp,
            msg,
            "Since I don't take logs of non-positive numbers, I'm zeroing this one.\n"
            "Proceed, with fingers crossed."
        );
        memcpy(ret->data.num, &(mp_interval_data.zero), sizeof(interval));
    }
}

static void mp_interval_m_exp(MP mp, mp_number *ret, const mp_number *x)
{
    interval i;
    interval xi = to_interval(x);
    errno = 0;
    i = j_exp(div_ii(xi, mp_interval_data.d256));
    if (! errno) {
        memcpy(ret->data.num, &i, sizeof(interval));
    } else if (interval_gt(xi, mp_interval_data.zero)) {
        mp->arithmic_error = mp_error_code(mp, 5);
        memcpy(ret->data.num, &mp_interval_data.EL_GORDO, sizeof(interval));
    } else {
        memcpy(ret->data.num, &mp_interval_data.zero, sizeof(interval));
    }
}

static void mp_interval_n_arg(MP mp, mp_number *ret, const mp_number *x_orig, const mp_number *y_orig)
{
    interval xi = to_interval(x_orig);
    interval yi = to_interval(y_orig);
    interval ri;
    if (interval_eq(xi, mp_interval_data.zero) && interval_eq(yi, mp_interval_data.zero)) {
        ri = to_internum(internal_value(mp_default_zero_angle_internal).data.num);
        if (interval_le(ri, mp_interval_data.zero)) {
            mp_error(
                mp,
                "angle(0,0) is taken as zero",
                "The 'angle' between two identical points is undefined. I'm zeroing this one.\n"
                "Proceed, with fingers crossed."
            );
        } else {
            ri = mp_interval_data.zero;
        }
    } else {
        ret->type = mp_angle_type;
        ri = mul_id(mul_ii(
            to_constant(atan2(q_mid(yi), q_mid(xi))),
            div_ii(mp_interval_data.dp180, mp_interval_data.pi)
        ), mp_angle_multiplier);
    }
    memcpy(ret->data.num, &ri, sizeof(interval));
}

static void mp_interval_sin_cos(MP mp, const mp_number *z_orig, mp_number *n_cos, mp_number *n_sin)
{
    interval rad = div_id(to_interval(z_orig), mp_angle_multiplier); /* still degrees */
    (void) mp;
    if (interval_eq(rad, mp_interval_data.dp90) || interval_eq(rad, mp_interval_data.dm270)) {
        memcpy(n_cos->data.num, &(mp_interval_data.zero), sizeof(interval));
        memcpy(n_sin->data.num, &mp_interval_data.fraction_multiplier, sizeof(interval));
    } else if (interval_eq(rad, mp_interval_data.dm90) || interval_eq(rad, mp_interval_data.dp270)) {
        memcpy(n_cos->data.num, &(mp_interval_data.zero), sizeof(interval));
        memcpy(n_sin->data.num, &mp_interval_data.negative_fraction_multiplier, sizeof(interval));
    } else if (interval_eq(rad, mp_interval_data.dp180) || interval_eq(rad, mp_interval_data.dm180)) {
        memcpy(n_cos->data.num, &mp_interval_data.negative_fraction_multiplier, sizeof(interval));
        memcpy(n_sin->data.num, &(mp_interval_data.zero), sizeof(interval));
    } else {
        interval ic, is;
        rad = div_ii(mul_ii(rad, mp_interval_data.pi), mp_interval_data.dp180);
        ic = mul_id(j_cos(rad), mp_fraction_multiplier);
        is = mul_id(j_sin(rad), mp_fraction_multiplier);
        memcpy(n_cos->data.num, &ic, sizeof(interval));
        memcpy(n_sin->data.num, &is, sizeof(interval));
    }
}

/*tex
    This is the |http://www-cs-faculty.stanford.edu/~uno/programs/rng.c| with small cosmetic
    modifications. The code only documented here as the other non scaled number models use the
    same method.
*/

static void mp_interval_aux_ran_array(MP mp, long aa[], int n)
{
    int i, j;
    for (j = 0; j < mp_random_KK; j++) {
        aa[j] = mp->random_data.x[j];
    }
    for (; j < n; j++) {
        aa[j] = mp_random_mod_diff(aa[j - mp_random_KK], aa[j - mp_random_LL]);
    }
    for (i = 0; i < mp_random_LL; i++, j++) {
        mp->random_data.x[i] = mp_random_mod_diff(aa[j - mp_random_KK], aa[j - mp_random_LL]);
    }
    for (; i < mp_random_KK; i++, j++) {
        mp->random_data.x[i] = mp_random_mod_diff(aa[j - mp_random_KK], mp->random_data.x[i - mp_random_LL]);
    }
}

static void mp_interval_aux_ran_start(MP mp, long seed)
{
    int t, j;
    long x[mp_random_KK + mp_random_KK - 1];
    long ss = (seed + 2) & (mp_random_MM - 2);
    for (j = 0; j < mp_random_KK; j++) {
        x[j] = ss;
        ss <<= 1;
        if (ss >= mp_random_MM) {
            ss -= mp_random_MM - 2;
        }
    }
    x[1]++;
    for (ss = seed & (mp_random_MM - 1), t = mp_random_TT - 1; t;) {
        for (j = mp_random_KK - 1; j > 0; j--) {
            x[j + j] = x[j];
            x[j + j - 1] = 0;
        }
        for (j = mp_random_KK + mp_random_KK - 2; j >= mp_random_KK; j--) {
            x[j - (mp_random_KK -mp_random_LL)] = mp_random_mod_diff(x[j - (mp_random_KK - mp_random_LL)], x[j]);
            x[j - mp_random_KK] = mp_random_mod_diff(x[j - mp_random_KK], x[j]);
        }
        if (odd_long(ss)) {
            for (j = mp_random_KK; j > 0; j--) {
                x[j] = x[j-1];
            }
            x[0] = x[mp_random_KK];
            x[mp_random_LL] = mp_random_mod_diff(x[mp_random_LL], x[mp_random_KK]);
        }
        if (ss) {
            ss >>= 1;
        } else {
            t--;
        }
    }
    for (j = 0; j < mp_random_LL; j++) {
        mp->random_data.x[j + mp_random_KK - mp_random_LL] = x[j];
    }
    for (;j < mp_random_KK; j++) {
        mp->random_data.x[j - mp_random_LL] = x[j];
    }
    for (j = 0; j < 10; j++) {
        mp_interval_aux_ran_array(mp, x, mp_random_KK + mp_random_KK - 1);
    }
    mp->random_data.ptr = &mp->random_data.started;
}

static long mp_interval_aux_ran_arr_cycle(MP mp)
{
    if (mp->random_data.ptr == &mp->random_data.dummy) {
        mp_interval_aux_ran_start(mp, 314159L);
    }
    mp_interval_aux_ran_array(mp, mp->random_data.buf, QUALITY);
    mp->random_data.buf[mp_random_KK] = -1;
    mp->random_data.ptr = mp->random_data.buf + 1;
    return mp->random_data.buf[0];
}

static void mp_interval_init_randoms(MP mp, int seed)
{
    mp->random_data = (mp_random_info) {
        .dummy   = -1,
        .started = -1,
        .ptr     = &mp->random_data.dummy
    };
    int k = 1;
    int j = abs(seed);
    int f = (int) mp_fraction_multiplier;
    while (j >= f) {
        j = j / 2;
    }
    for (int i = 0; i <= 54; i++) {
        int jj = k;
        k = j - k;
        j = jj;
        if (k < 0) {
            k += f;
        }
        mp->randoms[(i * 21) % 55].data.num = mp_new_inum(to_constant(j));
    }
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    mp_new_randoms(mp);
    mp_interval_aux_ran_start((unsigned long) seed);
}

static inline void mp_interval_modulo(mp_number *a, const mp_number *b)
{
    interval i = interval_mod(to_interval(a), to_interval(b));
    memcpy(a->data.num, &i, sizeof(interval));
}

static inline void mp_interval_aux_next_unif_random(MP mp, mp_number *ret)
{
    unsigned long int op = (unsigned) (*mp->random_data.ptr >= 0 ? *mp->random_data.ptr++ : mp_interval_aux_ran_arr_cycle(mp));
    double a = op / (mp_random_MM * 1.0);
    interval i = to_constant(a);
    memcpy(ret->data.num, &i, sizeof(interval));
    (void) mp;
}

static inline void mp_interval_aux_next_random(MP mp, mp_number *ret)
{
    if (mp->j_random == 0) {
        mp_new_randoms(mp);
    } else {
        mp->j_random = mp->j_random - 1;
    }
    mp_interval_clone(ret, &(mp->randoms[mp->j_random]));
}

static void mp_interval_m_unif_rand(MP mp, mp_number *ret, const mp_number *x_orig)
{
    mp_number x, abs_x, u, y;
    mp_interval_allocate_number(mp, &y, mp_fraction_type);
    mp_interval_allocate_clone(mp, &x, mp_scaled_type, x_orig);
    mp_interval_allocate_abs(mp, &abs_x, mp_scaled_type, &x);
    mp_interval_allocate_number(mp, &u, mp_scaled_type);
    mp_interval_aux_next_unif_random(mp, &u);
    mp_interval_set_from_mul(&y, &abs_x, &u);
    mp_interval_free_number(mp, &u);
    if (mp_interval_equal(&y, &abs_x)) {
        mp_interval_clone(ret, &((math_data *)mp->math)->md_zero_t);
    } else if (mp_interval_greater(&x, &((math_data *)mp->math)->md_zero_t)) {
        mp_interval_clone(ret, &y);
    } else {
        mp_interval_negated_clone(ret, &y);
    }
    mp_interval_free_number(mp, &abs_x);
    mp_interval_free_number(mp, &x);
    mp_interval_free_number(mp, &y);
}

static void mp_interval_m_norm_rand(MP mp, mp_number *ret)
{
    mp_number abs_x, u, r, la, xa;
    mp_interval_allocate_number(mp, &la, mp_scaled_type);
    mp_interval_allocate_number(mp, &xa, mp_scaled_type);
    mp_interval_allocate_number(mp, &abs_x, mp_scaled_type);
    mp_interval_allocate_number(mp, &u, mp_scaled_type);
    mp_interval_allocate_number(mp, &r, mp_scaled_type);
    do {
        do {
            mp_number v;
            mp_interval_allocate_number(mp, &v, mp_scaled_type);
            mp_interval_aux_next_random(mp, &v);
            mp_interval_subtract(&v, &((math_data *)mp->math)->md_fraction_half_t);
            mp_interval_number_take_fraction(mp, &xa, &((math_data *)mp->math)->md_sqrt_8_e_k, &v);
            mp_interval_free_number(mp, &v);
            mp_interval_aux_next_random(mp, &u);
            mp_interval_clone(&abs_x, &xa);
            mp_interval_abs(&abs_x);
        } while (! mp_interval_less(&abs_x, &u));
        mp_interval_number_make_fraction(mp, &r, &xa, &u);
        mp_interval_clone(&xa, &r);
        mp_interval_m_log(mp, &la, &u);
        mp_interval_set_from_subtraction(&la, &((math_data *)mp->math)->md_twelve_ln_2_k, &la);
    } while (mp_interval_ab_vs_cd(&((math_data *)mp->math)->md_one_k, &la, &xa, &xa) < 0);
    mp_interval_clone(ret, &xa);
    mp_interval_free_number(mp, &r);
    mp_interval_free_number(mp, &abs_x);
    mp_interval_free_number(mp, &la);
    mp_interval_free_number(mp, &xa);
    mp_interval_free_number(mp, &u);
}

static inline void mp_interval_set_precision(MP mp)
{
    (void) mp;
}

static void mp_interval_free_math(MP mp)
{
    mp_interval_free_number(mp, &(mp->math->md_three_sixty_deg_t));
    mp_interval_free_number(mp, &(mp->math->md_one_eighty_deg_t));
    mp_interval_free_number(mp, &(mp->math->md_negative_one_eighty_deg_t));
    mp_interval_free_number(mp, &(mp->math->md_fraction_one_t));
    mp_interval_free_number(mp, &(mp->math->md_zero_t));
    mp_interval_free_number(mp, &(mp->math->md_half_unit_t));
    mp_interval_free_number(mp, &(mp->math->md_three_quarter_unit_t));
    mp_interval_free_number(mp, &(mp->math->md_unity_t));
    mp_interval_free_number(mp, &(mp->math->md_two_t));
    mp_interval_free_number(mp, &(mp->math->md_three_t));
    mp_interval_free_number(mp, &(mp->math->md_one_third_inf_t));
    mp_interval_free_number(mp, &(mp->math->md_inf_t));
    mp_interval_free_number(mp, &(mp->math->md_negative_inf_t));
    mp_interval_free_number(mp, &(mp->math->md_warning_limit_t));
    mp_interval_free_number(mp, &(mp->math->md_one_k));
    mp_interval_free_number(mp, &(mp->math->md_sqrt_8_e_k));
    mp_interval_free_number(mp, &(mp->math->md_twelve_ln_2_k));
    mp_interval_free_number(mp, &(mp->math->md_coef_bound_k));
    mp_interval_free_number(mp, &(mp->math->md_coef_bound_minus_1));
    mp_interval_free_number(mp, &(mp->math->md_fraction_threshold_t));
    mp_interval_free_number(mp, &(mp->math->md_half_fraction_threshold_t));
    mp_interval_free_number(mp, &(mp->math->md_scaled_threshold_t));
    mp_interval_free_number(mp, &(mp->math->md_half_scaled_threshold_t));
    mp_interval_free_number(mp, &(mp->math->md_near_zero_angle_t));
    mp_interval_free_number(mp, &(mp->math->md_p_over_v_threshold_t));
    mp_interval_free_number(mp, &(mp->math->md_equation_threshold_t));
    mp_memory_free(mp->math);
}

math_data *mp_initialize_interval_math(MP mp)
{
    math_data *math = (math_data *) mp_memory_allocate(sizeof(math_data));
    if (! mp_interval_data.initialized) {
        mp_interval_data.initialized                  = 1;
        mp_interval_data.unity                        = to_constant(1);
        mp_interval_data.zero                         = to_constant(0);
        mp_interval_data.one                          = to_constant(1);
        mp_interval_data.two                          = to_constant(2);
        mp_interval_data.three                        = to_constant(3);
        mp_interval_data.four                         = to_constant(4);
        mp_interval_data.five                         = to_constant(5);
        mp_interval_data.seven                        = to_constant(7);
        mp_interval_data.eight                        = to_constant(8);
        mp_interval_data.sixteen                      = to_constant(16);
        mp_interval_data.dp90                         = to_constant(90);
        mp_interval_data.dp180                        = to_constant(180);
        mp_interval_data.dp270                        = to_constant(270);
        mp_interval_data.dp360                        = to_constant(360);
        mp_interval_data.dm90                         = to_constant(-90);
        mp_interval_data.dm180                        = to_constant(-180);
        mp_interval_data.dm270                        = to_constant(-270);
        mp_interval_data.dm360                        = to_constant(-360);
        mp_interval_data.d16                          = to_constant(16);
        mp_interval_data.d64                          = to_constant(64);
        mp_interval_data.d256                         = to_constant(256);
        mp_interval_data.d4096                        = to_constant(4096);
        mp_interval_data.d65536                       = to_constant(65536);
        mp_interval_data.minusone                     = to_constant(-1);
        mp_interval_data.half_unit                    = div_ii(mp_interval_data.unity, mp_interval_data.two);
        mp_interval_data.three_quarter_unit           = mul_ii(mp_interval_data.three, div_ii(mp_interval_data.unity,mp_interval_data.four));
        mp_interval_data.fraction_multiplier          = to_constant(mp_fraction_multiplier);
        mp_interval_data.negative_fraction_multiplier = to_constant(-mp_fraction_multiplier);
        mp_interval_data.angle_multiplier             = to_constant(mp_angle_multiplier);
        mp_interval_data.fraction_one                 = mp_interval_data.fraction_multiplier;
        mp_interval_data.fraction_two                 = mul_di(mp_fraction_multiplier, mp_interval_data.two);
        mp_interval_data.fraction_three               = mul_di(mp_fraction_multiplier, mp_interval_data.three);
        mp_interval_data.fraction_four                = mul_di(mp_fraction_multiplier, mp_interval_data.four);
        mp_interval_data.fraction_half                = div_di(mp_fraction_multiplier, mp_interval_data.two);
        mp_interval_data.fraction_one_and_half        = add_di(mp_fraction_multiplier, mp_interval_data.fraction_half);
        mp_interval_data.one_eighty_degrees           = mul_di(mp_angle_multiplier, mp_interval_data.dp180);
        mp_interval_data.negative_one_eighty_degrees  = mul_di(mp_angle_multiplier, mp_interval_data.dm180);
        mp_interval_data.three_sixty_degrees          = mul_di(mp_angle_multiplier, mp_interval_data.dp360);
        mp_interval_data.no_crossing                  = add_di(mp_fraction_multiplier, mp_interval_data.one);
        mp_interval_data.one_crossing                 = mp_interval_data.fraction_multiplier;
        mp_interval_data.zero_crossing                = mp_interval_data.zero;
        mp_interval_data.error_correction             = to_constant(1E-12);
        mp_interval_data.warning_limit                = to_constant(mp_interval_warning_limit);
        mp_interval_data.pi                           = to_constant(3.1415926535897932384626433832795028841971);
        mp_interval_data.pi_divided_by_180            = div_ii(mp_interval_data.pi, mp_interval_data.dp180);
        mp_interval_data.epsilon                      = to_constant(mp_interval_epsilon);
        mp_interval_data.EL_GORDO                     = sub_ii(div_di(mp_interval_double_max, mp_interval_data.two), mp_interval_data.one);
        mp_interval_data.negative_EL_GORDO            = sub_ii(div_di(mp_interval_double_min, mp_interval_data.two), mp_interval_data.one);
        mp_interval_data.one_third_EL_GORDO           = div_ii(mp_interval_data.EL_GORDO, mp_interval_data.three);
        mp_interval_data.coef                         = div_ii(mp_interval_data.seven, mp_interval_data.three);
        mp_interval_data.coef_bound                   = mul_id(mp_interval_data.coef, mp_fraction_multiplier);
        mp_interval_data.scaled_threshold             = to_constant(0.000122);
        mp_interval_data.near_zero_angle              = mul_di(0.0256, mp_interval_data.angle_multiplier);
        mp_interval_data.p_over_v_threshold           = to_constant(0x80000);
        mp_interval_data.equation_threshold           = to_constant(0.001);
        mp_interval_data.sqrt_two_mul_fraction_one =
            mul_ii(
                j_sqrt(mp_interval_data.two),
                mp_interval_data.fraction_one
            );
        mp_interval_data.sqrt_five_minus_one_mul_fraction_one_and_half =
            mul_ii(
                mul_ii(
                    mp_interval_data.three,
                    mp_interval_data.fraction_half
                ),
                sub_ii(
                    j_sqrt(mp_interval_data.five),
                    mp_interval_data.one
                )
            );
        mp_interval_data.three_minus_sqrt_five_mul_fraction_one_and_half =
            mul_ii(
                mul_ii(
                    mp_interval_data.three,
                    mp_interval_data.fraction_half
                ),
                sub_ii(
                    mp_interval_data.three,
                    j_sqrt(mp_interval_data.five)
                )
            );
        mp_interval_data.d180_divided_by_pi_mul_angle =
            mul_id(
                div_ii(
                    mp_interval_data.dp180,
                    mp_interval_data.pi
                ),
                mp_angle_multiplier
            );
    }
   /* alloc */
    math->md_allocate        = mp_interval_allocate_number;
    math->md_free            = mp_interval_free_number;
    math->md_allocate_clone  = mp_interval_allocate_clone;
    math->md_allocate_abs    = mp_interval_allocate_abs;
    math->md_allocate_div    = mp_interval_allocate_div;
    math->md_allocate_mul    = mp_interval_allocate_mul;
    math->md_allocate_add    = mp_interval_allocate_add;
    math->md_allocate_sub    = mp_interval_allocate_sub;
    math->md_allocate_double = mp_interval_allocate_double;
    /* precission */
    mp_interval_allocate_number(mp, &math->md_precision_default, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_precision_max, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_precision_min, mp_scaled_type);
    /* here are the constants for |scaled| objects */
    mp_interval_allocate_number(mp, &math->md_epsilon_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_inf_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_negative_inf_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_warning_limit_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_one_third_inf_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_unity_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_two_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_three_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_half_unit_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_three_quarter_unit_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_zero_t, mp_scaled_type);
    /* |fractions| */
    mp_interval_allocate_number(mp, &math->md_arc_tol_k, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_fraction_one_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_fraction_half_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_fraction_three_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_fraction_four_t, mp_fraction_type);
    /* |angles| */
    mp_interval_allocate_number(mp, &math->md_three_sixty_deg_t, mp_angle_type);
    mp_interval_allocate_number(mp, &math->md_one_eighty_deg_t, mp_angle_type);
    mp_interval_allocate_number(mp, &math->md_negative_one_eighty_deg_t, mp_angle_type);
    /* various approximations */
    mp_interval_allocate_number(mp, &math->md_one_k, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_sqrt_8_e_k, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_twelve_ln_2_k, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_coef_bound_k, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_coef_bound_minus_1, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_twelvebits_3, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_twentysixbits_sqrt2_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_twentyeightbits_d_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_twentysevenbits_sqrt2_d_t, mp_fraction_type);
    /* thresholds */
    mp_interval_allocate_number(mp, &math->md_fraction_threshold_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_half_fraction_threshold_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_scaled_threshold_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_half_scaled_threshold_t, mp_scaled_type);
    mp_interval_allocate_number(mp, &math->md_near_zero_angle_t, mp_angle_type);
    mp_interval_allocate_number(mp, &math->md_p_over_v_threshold_t, mp_fraction_type);
    mp_interval_allocate_number(mp, &math->md_equation_threshold_t, mp_scaled_type);
    /* initializations */
    math->md_precision_default.data.num         = mp_new_inum(mul_ii(mp_interval_data.d16, mp_interval_data.unity));
    math->md_precision_max.data.num             = mp_new_inum(mul_ii(mp_interval_data.d16, mp_interval_data.unity));
    math->md_precision_min.data.num             = mp_new_inum(mul_ii(mp_interval_data.d16, mp_interval_data.unity));
    math->md_epsilon_t.data.num                 = mp_new_inum(mp_interval_data.epsilon);
    math->md_inf_t.data.num                     = mp_new_inum(mp_interval_data.EL_GORDO);
    math->md_negative_inf_t.data.num            = mp_new_inum(mp_interval_data.negative_EL_GORDO);
    math->md_one_third_inf_t.data.num           = mp_new_inum(mp_interval_data.one_third_EL_GORDO);
    math->md_warning_limit_t.data.num           = mp_new_inum(mp_interval_data.warning_limit);
    math->md_unity_t.data.num                   = mp_new_inum(mp_interval_data.unity);
    math->md_two_t.data.num                     = mp_new_inum(mp_interval_data.two);
    math->md_three_t.data.num                   = mp_new_inum(mp_interval_data.three);
    math->md_half_unit_t.data.num               = mp_new_inum(mp_interval_data.half_unit);
    math->md_three_quarter_unit_t.data.num      = mp_new_inum(mp_interval_data.three_quarter_unit);
    math->md_arc_tol_k.data.num                 = mp_new_inum(div_ii(mp_interval_data.unity,mp_interval_data.d4096));
    math->md_fraction_one_t.data.num            = mp_new_inum(mp_interval_data.fraction_one);
    math->md_fraction_half_t.data.num           = mp_new_inum(mp_interval_data.fraction_half);
    math->md_fraction_three_t.data.num          = mp_new_inum(mp_interval_data.fraction_three);
    math->md_fraction_four_t.data.num           = mp_new_inum(mp_interval_data.fraction_four);
    math->md_three_sixty_deg_t.data.num         = mp_new_inum(mp_interval_data.three_sixty_degrees);
    math->md_one_eighty_deg_t.data.num          = mp_new_inum(mp_interval_data.one_eighty_degrees);
    math->md_negative_one_eighty_deg_t.data.num = mp_new_inum(mp_interval_data.negative_one_eighty_degrees);
    math->md_one_k.data.num                     = mp_new_inum(div_ii(mp_interval_data.one, mp_interval_data.d64));
    math->md_sqrt_8_e_k.data.num                = mp_new_inum(to_constant(1.71552776992141359295));
    math->md_twelve_ln_2_k.data.num             = mp_new_inum(mul_di(8.31776616671934371292, mp_interval_data.d256));
    math->md_twelvebits_3.data.num              = mp_new_inum(div_di(1365, mp_interval_data.unity));
    math->md_twentysixbits_sqrt2_t.data.num     = mp_new_inum(div_di(94906266, mp_interval_data.d65536));
    math->md_twentyeightbits_d_t.data.num       = mp_new_inum(div_di(35596755, mp_interval_data.d65536));
    math->md_twentysevenbits_sqrt2_d_t.data.num = mp_new_inum(div_di(25170707, mp_interval_data.d65536));
    math->md_coef_bound_k.data.num              = mp_new_inum(mp_interval_data.coef_bound);
    math->md_coef_bound_minus_1.data.num        = mp_new_inum(sub_ii(mp_interval_data.coef_bound, div_ii(mp_interval_data.one, mp_interval_data.d65536)));
    math->md_fraction_threshold_t.data.num      = mp_new_inum(to_constant(0.04096));
    math->md_half_fraction_threshold_t.data.num = mp_new_inum(div_ii(mp_interval_data.fraction_threshold, mp_interval_data.two));
    math->md_scaled_threshold_t.data.num        = mp_new_inum(mp_interval_data.scaled_threshold);
    math->md_half_scaled_threshold_t.data.num   = mp_new_inum(div_ii(mp_interval_data.scaled_threshold,mp_interval_data.two));
    math->md_near_zero_angle_t.data.num         = mp_new_inum(mp_interval_data.near_zero_angle);
    math->md_p_over_v_threshold_t.data.num      = mp_new_inum(mp_interval_data.p_over_v_threshold);
    math->md_equation_threshold_t.data.num      = mp_new_inum(mp_interval_data.equation_threshold);
    /* functions */
    math->md_from_int                 = mp_interval_set_from_int;
    math->md_from_boolean             = mp_interval_set_from_boolean;
    math->md_from_scaled              = mp_interval_set_from_scaled;
    math->md_from_double              = mp_interval_set_from_double;
    math->md_from_addition            = mp_interval_set_from_addition;
    math->md_half_from_addition       = mp_interval_set_half_from_addition;
    math->md_from_subtraction         = mp_interval_set_from_subtraction;
    math->md_half_from_subtraction    = mp_interval_set_half_from_subtraction;
    math->md_from_of_the_way          = mp_interval_set_from_of_the_way;
    math->md_from_div                 = mp_interval_set_from_div;
    math->md_from_mul                 = mp_interval_set_from_mul;
    math->md_from_int_div             = mp_interval_set_from_int_div;
    math->md_from_int_mul             = mp_interval_set_from_int_mul;
    math->md_negate                   = mp_interval_negate;
    math->md_add                      = mp_interval_add;
    math->md_subtract                 = mp_interval_subtract;
    math->md_half                     = mp_interval_half;
    math->md_do_double                = mp_interval_double;
    math->md_abs                      = mp_interval_abs;
    math->md_clone                    = mp_interval_clone;
    math->md_negated_clone            = mp_interval_negated_clone;
    math->md_abs_clone                = mp_interval_abs_clone;
    math->md_swap                     = mp_interval_swap;
    math->md_add_scaled               = mp_interval_add_scaled;
    math->md_multiply_int             = mp_interval_multiply_int;
    math->md_divide_int               = mp_interval_divide_int;
    math->md_to_int                   = mp_interval_to_int;
    math->md_to_boolean               = mp_interval_to_boolean;
    math->md_to_scaled                = mp_interval_to_scaled;
    math->md_to_double                = mp_interval_to_double;
    math->md_odd                      = mp_interval_odd;
    math->md_equal                    = mp_interval_equal;
    math->md_less                     = mp_interval_less;
    math->md_greater                  = mp_interval_greater;
    math->md_non_equal_abs            = mp_interval_non_equal_abs;
    math->md_round_unscaled           = mp_interval_unscaled;
    math->md_floor_scaled             = mp_interval_floor;
    math->md_fraction_to_round_scaled = mp_interval_fraction_to_round_scaled;
    math->md_make_scaled              = mp_interval_number_make_scaled;
    math->md_make_fraction            = mp_interval_number_make_fraction;
    math->md_take_fraction            = mp_interval_number_take_fraction;
    math->md_take_scaled              = mp_interval_number_take_scaled;
    math->md_velocity                 = mp_interval_velocity;
    math->md_n_arg                    = mp_interval_n_arg;
    math->md_m_log                    = mp_interval_m_log;
    math->md_m_exp                    = mp_interval_m_exp;
    math->md_m_unif_rand              = mp_interval_m_unif_rand;
    math->md_m_norm_rand              = mp_interval_m_norm_rand;
    math->md_pyth_add                 = mp_interval_pyth_add;
    math->md_pyth_add3                = mp_interval_pyth_add3;
    math->md_pyth_sub                 = mp_interval_pyth_sub;
    math->md_power_of                 = mp_interval_power_of;
    math->md_fraction_to_scaled       = mp_interval_fraction_to_scaled;
    math->md_scaled_to_fraction       = mp_interval_scaled_to_fraction;
    math->md_scaled_to_angle          = mp_interval_scaled_to_angle;
    math->md_angle_to_scaled          = mp_interval_angle_to_scaled;
    math->md_init_randoms             = mp_interval_init_randoms;
    math->md_sin_cos                  = mp_interval_sin_cos;
    math->md_slow_add                 = mp_interval_slow_add;
    math->md_slow_sub                 = mp_interval_slow_sub;
    math->md_sqrt                     = mp_interval_square_rt;
    math->md_print                    = mp_interval_print_number;
    math->md_tostring                 = mp_interval_number_tostring;
    math->md_modulo                   = mp_interval_modulo;
    math->md_ab_vs_cd                 = mp_interval_ab_vs_cd;
    math->md_crossing_point           = mp_interval_crossing_point;
    math->md_scan_numeric             = mp_interval_scan_numeric_token;
    math->md_scan_fractional          = mp_interval_scan_fractional_token;
    /* housekeeping */
    math->md_free_math                = mp_interval_free_math;
    math->md_set_precision            = mp_interval_set_precision;
    return math;
}