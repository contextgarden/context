/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_SERIALIZE_H
# define LMT_UTILITIES_SERIALIZE_H

# include <lua.h>

extern int    double_to_string_f  (double val, char *buf, int n);
extern int    double_to_string_g  (double val, char *buf, int n);
extern int    double_to_string_z  (double val, char *buf, size_t buf_size, int n);
extern int    double_to_string_r  (double val, char *buf);
extern int    double_to_string_m  (double val, char *buf, const char *thousand_sep, size_t thousand_sep_len, char decimal_sep);
extern int    double_to_string_j  (double val, char *dest, size_t dest_size, char exp_char, int req_prec);

extern int    integer_to_string_v (lua_Integer val, char *buf, const char *thousand_sep, size_t thousand_sep_len);

# endif
