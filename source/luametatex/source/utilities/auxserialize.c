/*tex

    See license.txt in the root of this project. The credits for the basics of this code
    (the inline functions go to wherever gemini got it from. In principle it is published
    code based on some research. The two public helpers are tuned for our purpose,
    especially striping the redundant zeros and precision. Here is a Gemini wrapup of the
    inline functions:

    \startquotation
    The technique implemented here uses a two-digit lookup table optimization—frequently
    associated with Terence Parr's dtoa algorithm and popularized by Milo Yip's rapidjson
    library as well as Ryu/Grisu variant implementations. The primary goal of the
    200-character array |DIGIT_TABLE| is to eliminate slow division and modulo operations
    during binary-to-decimal string formatting. Rather than dividing a number by 10 in a
    loop to extract one digit at a time, the code processes numbers two digits (base 100)
    at a time. The DIGIT_TABLE array stores all two-digit decimal combinations from |00|
    to |99| continuously (100 pairs = 200 characters). By taking |(val % 100) * 2| as the
    array index, the routine directly retrieves both ASCII characters simultaneously.
    Because CPU instruction sets execute division by 100 faster via fixed-point
    multiplication tricks, processing numbers in pairs halves the total number of division
    instructions, significantly boosting performance in low-latency and high-throughput
    C code.
    \stopquotaiton

*/

/*tex 

    In the meantiem we added soem more than \quote {f} and \quote {g} formatting because I 
    decided to use al this in the formatting helpers. So more might end up here. All this 
    is rather \CONTEXT\ specific. 

*/

# include <stdint.h>
# include <stdbool.h>
# include <string.h>
# include <stdio.h>
# include <limits.h>
# include <lua.h>

typedef struct {
    uint64_t significand;
    int32_t  exponent;
} decimal_rep_t;

static const char DIGIT_TABLE[] =
    "0001020304050607080910111213141516171819"
    "2021222324252627282930313233343536373839"
    "4041424344454647484950515253545556575859"
    "6061626364656667686970717273747576777879"
    "8081828384858687888990919293949596979899";

static const double POW10[] = {
    1e0,  1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7,  1e8,  1e9,
    1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19
};

# define pow_10_max 19
# define max_decimal_precision (INT_MAX - 350)

static inline int normalize_decimal_precision(int precision)
{
    if (precision < 0) {
        return 0;
    } else if (precision > max_decimal_precision) {
        return max_decimal_precision;
    } else {
        return precision;
    }
}

static inline decimal_rep_t fast_double_to_decimal(double v, bool *is_neg)
{
    union { double d; uint64_t u; } bits = { v };
    *is_neg = (bits.u >> 63) != 0;
    if (*is_neg) v = -v;
    decimal_rep_t dec = {0, 0};
    if (v == 0.0) {
        return dec;
    }
    // fast integer scaling to extract exact 15-17 significant decimal digits
    int exp10 = 0;
    // scale into normalized double range [1e14, 1e15)
    if (v >= 1e15) {
        while (v >= 1e23) { v /= 1e8;  exp10 += 8; }
        while (v >= 1e15) { v /= 10.0; exp10++; }
    } else if (v <  1e14) {
        while (v <  1e6 ) { v *= 1e8;  exp10 -= 8; }
        while (v <  1e14) { v *= 10.0; exp10--; }
    }
    // fast rounding to nearest integer
    uint64_t sig = (uint64_t) (v + 0.5);
    // strip trailing zeros to keep representation minimal
    while (sig > 0 && (sig % 10 == 0)) {
        sig /= 10;
        exp10++;
    }
    dec.significand = sig;
    dec.exponent = exp10;
    return dec;
}

static inline int render_digits(uint64_t val, char *buf)
{
    if (val == 0) {
        buf[0] = '0';
        buf[1] = '\0';
        return 1;
    }
    char temp[32];
    int  pos = 0;
    while (val >= 100) {
        uint32_t ind = (uint32_t) ((val % 100) * 2);
        val /= 100;
        temp[pos++] = DIGIT_TABLE[ind + 1];
        temp[pos++] = DIGIT_TABLE[ind];
    }
    if (val < 10) {
        temp[pos++] = (char) ('0' + val);
    } else {
        uint32_t ind = (uint32_t) (val * 2);
        temp[pos++] = DIGIT_TABLE[ind + 1];
        temp[pos++] = DIGIT_TABLE[ind];
    }
    for (int i = 0; i < pos; i++) {
        buf[i] = temp[pos - 1 - i];
    }
    buf[pos] = '\0';
    return pos;
}

int double_to_string_f(double val, char *buf, int precision)
{
    precision = normalize_decimal_precision(precision);
    bool is_neg;
    union { double d; uint64_t u; } bits = { val };
    uint32_t exp = (bits.u >> 52) & 0x7FF;
    if (exp == 0x7FF) {
        if (bits.u & 0x000FFFFFFFFFFFFFULL) {
            buf[0]='N'; buf[1]='a'; buf[2]='N'; buf[3]='\0';
            return 3;
        } else if (bits.u >> 63) {
            buf[0]='-'; buf[1]='I'; buf[2]='n'; buf[3]='f'; buf[4]='\0';
            return 4;
        } else {
            buf[0]='I'; buf[1]='n'; buf[2]='f'; buf[3]='\0';
            return 3;
        }
    }
    decimal_rep_t dec = fast_double_to_decimal(val, &is_neg);
    char digits[32];
    int len = render_digits(dec.significand, digits);
    int dot_pos = len + dec.exponent;
    if (dot_pos < len) {
        // total fractional digits after '.' includes leading zeros when dot_pos <= 0
        int avail_frac = len - dot_pos;
        if (avail_frac > precision) {
            int drop = avail_frac - precision;
            if (drop > 0) {
                if (drop <= pow_10_max) {
                    uint64_t p10 = (uint64_t) POW10[drop];
                    dec.significand = (dec.significand + (p10 / 2)) / p10;
                    dec.exponent += drop;
                } else {
                    dec.significand = 0;
                    dec.exponent = -precision;
                }
                len = render_digits(dec.significand, digits);
                dot_pos = len + dec.exponent;
            }
        }
    }
    int p = 0;
    if (is_neg && val != 0.0) buf[p++] = '-';
    if (dot_pos <= 0) {
        buf[p++] = '0';
        buf[p++] = '.';
        for (int i = 0; i < -dot_pos; i++) {
            buf[p++] = '0';
        }
        for (int i = 0; i < len; i++) {
            buf[p++] = digits[i];
        }
    } else if (dot_pos >= len) {
        for (int i = 0; i < len; i++) {
            buf[p++] = digits[i];
        }
        for (int i = 0; i < (dot_pos - len); i++) {
            buf[p++] = '0';
        }
    } else {
        for (int i = 0; i < len; i++) {
            if (i == dot_pos) {
                buf[p++] = '.';
            }
            buf[p++] = digits[i];
        }
    }
    buf[p] = '\0';
    // trim trailing zeros after the decimal point
    if (memchr(buf, '.', p)) {
        while (p > 0 && buf[p - 1] == '0') {
            p--;
        }
        if (p > 0 && buf[p - 1] == '.') {
            p--;
        }
        buf[p] = '\0';
    }
    return p;
}

int double_to_string_g(double val, char *buf, int precision)
{
    precision = normalize_decimal_precision(precision);
    if (precision == 0) {
        precision = 1;
    } else if (precision > 17) {
        precision = 17;
    }
    union { double d; uint64_t u; } bits = { val };
    uint32_t exp = (bits.u >> 52) & 0x7FF;
    if (exp == 0x7FF) {
        if (bits.u & 0x000FFFFFFFFFFFFFULL) {
            buf[0]='N'; buf[1]='a'; buf[2]='N'; buf[3]='\0';
            return 3;
        }
        if (bits.u >> 63) {
            buf[0]='-'; buf[1]='I'; buf[2]='n'; buf[3]='f'; buf[4]='\0';
            return 4;
        }
        buf[0]='I'; buf[1]='n'; buf[2]='f'; buf[3]='\0';
        return 3;
    }
    char formatted[64];
    int len = snprintf(formatted, sizeof(formatted), "%.*g", precision, val);
    if (len <= 0 || len >= (int) sizeof(formatted)) {
        buf[0] = '\0';
        return 0;
    }
    memcpy(buf, formatted, (size_t) len + 1);
    return len;
}

int double_to_string_z(double val, char *buf, size_t buf_size, int precision)
{
    precision = normalize_decimal_precision(precision);
    bool is_neg;
    union { double d; uint64_t u; } bits = { val };
    uint32_t exp = (bits.u >> 52) & 0x7FF;
    if (exp == 0x7FF) {
        if (bits.u & 0x000FFFFFFFFFFFFFULL) {
            if (buf_size < 4) {
                return -1;
            }
            buf[0]='N'; buf[1]='a'; buf[2]='N'; buf[3]='\0';
            return 3;
        } else if (bits.u >> 63) {
            if (buf_size < 5) {
                return -1;
            }
            buf[0]='-'; buf[1]='I'; buf[2]='n'; buf[3]='f'; buf[4]='\0';
            return 4;
        } else {
            if (buf_size < 4) {
                return -1;
            }
            buf[0]='I'; buf[1]='n'; buf[2]='f'; buf[3]='\0';
            return 3;
        }
    }
    decimal_rep_t dec = fast_double_to_decimal(val, &is_neg);
    char digits[32];
    int len = render_digits(dec.significand, digits);
    int dot_pos = len + dec.exponent;
    if (dot_pos < len) {
        // total fractional digits after '.' includes leading zeros when dot_pos <= 0
        int avail_frac = len - dot_pos;
        if (avail_frac > precision) {
            int drop = avail_frac - precision;
            if (drop > 0) {
                if (drop <= pow_10_max) {
                    uint64_t p10 = (uint64_t) POW10[drop];
                    dec.significand = (dec.significand + (p10 / 2)) / p10;
                    dec.exponent += drop;
                } else {
                    dec.significand = 0;
                    dec.exponent = -precision;
                }
                len = render_digits(dec.significand, digits);
                dot_pos = len + dec.exponent;
            }
        }
    }
    size_t required = (is_neg && val != 0.0) ? 1 : 0;
    if (dot_pos <= 0) {
        required += 1;
        if (precision > 0) {
            int leading = -dot_pos;
            if (leading > precision) {
                leading = precision;
            }
            size_t fractional = (size_t) leading + (size_t) len;
            required += 1 + fractional;
            if ((size_t) precision > fractional) {
                required += (size_t) precision - fractional;
            }
        }
    } else if (dot_pos >= len) {
        required += (size_t) dot_pos;
        if (precision > 0) {
            required += 1 + (size_t) precision;
        }
    } else {
        required += (size_t) len;
        if (precision > 0) {
            required += 1;
            if ((size_t) precision > (size_t) (len - dot_pos)) {
                required += (size_t) precision - (size_t) (len - dot_pos);
            }
        }
    }
    if (required >= buf_size) {
        if (buf_size > 0) {
            buf[0] = '\0';
        }
        return -1;
    }
    int p = 0;
    if (is_neg && val != 0.0) buf[p++] = '-';
    if (dot_pos <= 0) {
        buf[p++] = '0';
        if (precision > 0) {
            buf[p++] = '.';
            for (int i = 0; i < -dot_pos && (p - (is_neg ? 3 : 2)) < precision; i++) {
                buf[p++] = '0';
            }
            for (int i = 0; i < len; i++) {
                buf[p++] = digits[i];
            }
        }
    } else if (dot_pos >= len) {
        for (int i = 0; i < len; i++) {
            buf[p++] = digits[i];
        }
        for (int i = 0; i < (dot_pos - len); i++) {
            buf[p++] = '0';
        }
        if (precision > 0) {
            buf[p++] = '.';
        }
    } else {
        for (int i = 0; i < len; i++) {
            if (i == dot_pos && precision > 0) {
                buf[p++] = '.';
            }
            buf[p++] = digits[i];
        }
    }
    if (precision > 0) {
        int dot_idx = -1;
        for (int i = 0; i < p; i++) {
            if (buf[i] == '.') {
                dot_idx = i;
                break;
            }
        }
        if (dot_idx != -1) {
            int current_frac_digits = p - (dot_idx + 1);
            for (int i = current_frac_digits; i < precision; i++) {
                buf[p++] = '0';
            }
        }
    }
    buf[p] = '\0';
    return p;
}

/*tex
    The rounding formatter.
*/

int double_to_string_r(double val, char *buf)
{
    // fast path for NaN / Inf
    union { double d; uint64_t u; } bits = { val };
    uint32_t exp = (bits.u >> 52) & 0x7FF;
    if (exp == 0x7FF) {
        if (bits.u & 0x000FFFFFFFFFFFFFULL) {
            buf[0]='N'; buf[1]='a'; buf[2]='N'; buf[3]='\0';
            return 3;
        } else if (bits.u >> 63) {
            buf[0]='-'; buf[1]='I'; buf[2]='n'; buf[3]='f'; buf[4]='\0';
            return 4;
        } else {
            buf[0]='I'; buf[1]='n'; buf[2]='f'; buf[3]='\0';
            return 3;
        }
    }
    bool is_neg = (bits.u >> 63) != 0;
    if (is_neg) {
        val = -val;
    }
    // standard half-up rounding to nearest integer
    double rounded = val + 0.5;
    // safe upper bound strictly less than 2^64 (18446744073709551616.0)
    if (rounded >= 0.0 && rounded < 18446744073709551616.0) {
        uint64_t uval = (uint64_t) rounded;
        int p = 0;
        if (is_neg && uval != 0) {
            buf[p++] = '-';
        }
        p += render_digits(uval, buf + p);
        return p;
    }
    // fallback for extremely large doubles: use double_to_string_f with 0 precision
    return double_to_string_f(is_neg ? -val : val, buf, 0);
}

/*tex
    We need a formatter for money and countries differ wrt command and periods. We also want to
    seperate thousands. A |string.formatter| that we did ith |lpeg|.
*/

int double_to_string_m(double val, char *buf, const char *thousand_sep, size_t thousand_sep_len, char decimal_sep)
{
    // fast path for NaN / Inf
    union { double d; uint64_t u; } bits = { val };
    uint32_t exp = (bits.u >> 52) & 0x7FF;
    if (exp == 0x7FF) {
        if (bits.u & 0x000FFFFFFFFFFFFFULL) {
            buf[0]='N'; buf[1]='a'; buf[2]='N'; buf[3]='\0'; return 3;
        } else if (bits.u >> 63) {
            buf[0]='-'; buf[1]='I'; buf[2]='n'; buf[3]='f'; buf[4]='\0'; return 4;
        } else {
            buf[0]='I'; buf[1]='n'; buf[2]='f'; buf[3]='\0'; return 3;
        }
    }
    bool is_neg = (bits.u >> 63) != 0;
    if (is_neg) {
        val = -val;
    }
    // round to 2 decimal places: val * 100 + 0.5 but beyond 2^53 we let the c library do that
    double   scaled = val * 100.0 + 0.5;
    char     raw_digits[320];
    int      raw_len;
    uint32_t frac;
    if (scaled < 9007199254740992.0) {
        uint64_t cents = (uint64_t) scaled;
        raw_len = render_digits(cents / 100, raw_digits);
        frac    = (uint32_t) (cents % 100);
    } else {
        // at most 309 digits, a period and two decimals
        raw_len = snprintf(raw_digits, sizeof(raw_digits), "%.2f", val) - 3;
        frac    = (uint32_t) ((raw_digits[raw_len + 1] - '0') * 10 + (raw_digits[raw_len + 2] - '0'));
    }
    int p = 0;
    if (is_neg && (raw_len > 1 || raw_digits[0] != '0' || frac != 0)) {
        buf[p++] = '-';
    }
    // insert thousands separators during integer rendering
    for (int i = 0; i < raw_len; i++) {
        int remaining = raw_len - i;
        if (i > 0 && (remaining % 3 == 0)) {
            memcpy(buf + p, thousand_sep, thousand_sep_len);
            p += thousand_sep_len;
        }
        buf[p++] = raw_digits[i];
    }
    // append decimal separator and 2 fixed decimal places
    buf[p++] = decimal_sep;
    buf[p++] = DIGIT_TABLE[frac * 2];
    buf[p++] = DIGIT_TABLE[frac * 2 + 1];
    buf[p]   = '\0';
    return p;
}

/*tex
    Another formatter turned C, this time integer thousands seperators.
*/

int integer_to_string_v(lua_Integer val, char *buf, const char *thousand_sep, size_t thousand_sep_len)
{
    bool is_neg = (val < 0);
    uint64_t uval = is_neg ? (uint64_t)(-(val + 1)) + 1 : (uint64_t)val;
    char raw_digits[32];
    int raw_len = render_digits(uval, raw_digits);
    int p = 0;
    if (is_neg) {
        buf[p++] = '-';
    }
    for (int i = 0; i < raw_len; i++) {
        int remaining = raw_len - i;
        if (i > 0 && (remaining % 3 == 0)) {
            memcpy(buf + p, thousand_sep, thousand_sep_len);
            p += thousand_sep_len;
        }
        buf[p++] = raw_digits[i];
    }
    buf[p] = '\0';
    return p;
}

/*tex
    This is the |string.formatters| lpeg turned into C.
*/

int double_to_string_j(double val, char *dest, size_t dest_size, char exp_char, int req_prec)
{
    if (dest_size == 0) {
        return -1;
    }
    req_prec = normalize_decimal_precision(req_prec);
    /* we format in place (the caller has room for the precision) so we can only get shorter */
    int len = snprintf(dest, dest_size, "%.*e", req_prec, val);
    if (len <= 0 || (size_t) len >= dest_size) {
        dest[0] = '\0';
        return -1;
    }
    /* find decimal point and exponent marker, without the latter we have inf or nan */
    char *dot = strchr(dest, '.');
    char *exp = strchr(dest, 'e');
    if (! exp) {
        return len;
    }
    /* parse exponent part (e.g. "+004", "-005", "+000") */
    char *e_ptr = exp + 1;
    int sign = 1;
    if (*e_ptr == '+') {
        sign = 1;
        e_ptr++;
    } else if (*e_ptr == '-') {
        sign = -1;
        e_ptr++;
    }
    int exp_val = 0;
    while (*e_ptr >= '0' && *e_ptr <= '9') {
        exp_val = (exp_val * 10) + (*e_ptr - '0');
        e_ptr++;
    }
    /* trim trailing zeros between '.' and 'e', and the decimal point if all fractional digits were zero */
    char *end = exp;
    if (dot) {
        while (end - 1 > dot && end[-1] == '0') {
            end--;
        }
        if (end - 1 == dot) {
            end--;
        }
    }
    /* append sparse exponent only if exp_val != 0 */
    if (exp_val != 0) {
        *end++ = exp_char;
        if (sign < 0) {
            *end++ = '-';
        }
        end += snprintf(end, dest_size - (size_t) (end - dest), "%d", exp_val);
    }
    *end = '\0';
    return (int) (end - dest);
}
