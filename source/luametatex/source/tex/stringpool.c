/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

    Control sequence names and diagnostic messages are variable-length strings of
    eight|-|bit characters. Since \PASCAL\ did not have a well-developed string
    mechanism, \TEX\ did all of its string processing by homegrown methods.

    Elaborate facilities for dynamic strings are not needed, so all of the
    necessary operations can be handled with a simple data structure. The array
    |str_pool| contains all of the (eight-bit) bytes off all of the strings, and
    the array |str_start| contains indices of the starting points of each string.
    Strings are referred to by integer numbers, so that string number |s|
    comprises the characters |str_pool[j]| for |str_start_macro(s) <= j <
    str_start_macro(s+1)|. Additional integer variables |pool_ptr| and |str_ptr|
    indicate the number of entries used so far in |str_pool| and |str_start|,
    respectively; locations |str_pool[pool_ptr]| and |str_start_macro(str_ptr)|
    are ready for the next string to be allocated.

    String numbers 0 to |biggest_char| are reserved for strings that correspond
    to single \UNICODE\ characters. This is in accordance with the conventions of
    \WEB\ which converts single-character strings into the ASCII code number of
    the single character involved.

    The stringpool variables are collected in:

*/

string_pool_info string_pool_state = { NULL, NULL, 0, 0, NULL, 0, 0, 0 };

/*tex

The array of strings is |string_pool|, the number of the current string being
created is |str_ptr|, the starting value of |str_ptr| is |init_str_ptr|, and the
current string buffer, the current index in that buffer, the mallocedsize of
|cur_string| and the occupied byte count are kept in |cur_string|, |cur_length|,
|cur_string_size| and |pool_size|.

Once a sequence of characters has been appended to |cur_string|, it officially
becomes a string when the function |make_string| is called. This function returns
the identification number of the new string as its value.

*/

void reset_cur_string(void)
{
    cur_length = 0;
    cur_string_size = 255;
    cur_string = (unsigned char *) malloc(256);
    memset(cur_string, 0, 256);
}

str_number make_string(void)
{
    if (string_pool_state.str_ptr == (main_state.max_strings + STRING_OFFSET)) {
        overflow(
            "number of strings",
             (unsigned) (main_state.max_strings - string_pool_state.init_str_ptr + STRING_OFFSET)
        );
    }
    str_room(1);
    cur_string[cur_length] = '\0';  /* this makes now |lstring.s| a valid \CCODE\ string */
    str_string(string_pool_state.str_ptr) = (unsigned char *) cur_string;
    str_length(string_pool_state.str_ptr) = cur_length;
    string_pool_state.pool_size += cur_length;
    reset_cur_string();
    string_pool_state.str_ptr++;
    return (string_pool_state.str_ptr - 1);
}

/*tex

    The following subroutine compares string |s| with another string of the same
    length that appears in |buffer| starting at position |k|; the result is
    |true| if and only if the strings are equal. Empirical tests indicate that
    |str_eq_buf| is used in such a way that it tends to return |true| about 80
    percent of the time.

    \startyping
    unsigned char *j = str_string(s);
    unsigned char *l = j + str_length(s);
    while (j < l) {
        if (*j++ != buffer[k++])
            return 0;
    }
    \stoptyping

*/

int str_eq_buf(str_number s, int k, int n)
{
    if (s < STRING_OFFSET) {
        if (buffer_to_unichar(k) != (unsigned int) s)
            return 0;
    } else {
        return (memcmp(str_string(s),&iobuffer[k],n) == 0);
    }
    return 1;
}

/*tex

    Here is a similar routine, but it compares two strings in the string pool,
    and it does not assume that they have the same length.

    \starttyping
    k = str_string(t);
    j = str_string(s);
    l = j + str_length(s);
    while (j < l) {
        if (*j++ != *k++)
            return 0;
    }
    \stoptyping
*/

int str_eq_str(str_number s, str_number t)
{
    if (s < STRING_OFFSET) {
        if (t >= STRING_OFFSET) {
            unsigned char *k = str_string(t);
            if (s <= 0x7F && (str_length(t) == 1) && *k == s) {
                return 1;
            } else if ((str_number) str2uni(k) != s) {
                return 0;
            }
        } else if (t != s) {
            return 0;
        }
    } else if (t < STRING_OFFSET) {
        unsigned char *j = str_string(s);
        if (t <= 0x7F && (str_length(s) == 1) && *j == t) {
            return 1;
        } else if ((str_number) str2uni(j) != t) {
            return 0;
        }
    } else {
        unsigned int l = str_length(s);
        if (l != str_length(t)) {
            return 0;
        } else {
            return (memcmp(str_string(s),str_string(t),l) == 0);
        }
    }
    return 1;
}

/*tex A string compare helper: */

int str_eq_cstr(str_number r, const char *s, size_t l)
{
    if (l != (size_t) str_length(r)) {
        return 0;
    } else {
        return (strncmp((const char *) (str_string(r)), s, l) == 0);
    }
}


/*tex

    The initial values of |str_pool|, |str_start|, |pool_ptr|, and |str_ptr| are
    computed by the \INITEX\ program, based in part on the information that \WEB\
    has output while processing \TEX.

    The first |string_offset| strings are single-characters strings matching
    Unicode. There is no point in generating all of these. But |str_ptr| has
    initialized properly, otherwise |print_char| cannot see the difference
    between characters and strings.

*/

int get_strings_started(void)
{
    reset_cur_string();
    return 1;
}

/*tex

    The string recycling routines. \TEX\ uses 2 upto 4 {\em new} strings when
    scanning a filename in an |\input|, |\openin|, or |\openout| operation. These
    strings are normally lost because the reference to them are not saved after
    finishing the operation. |search_string| searches through the string pool for
    the given string and returns either 0 or the found string number.

*/

str_number search_string(str_number search)
{
    size_t len = str_length(search);
    if (len == 0) {
        return get_nullstr();
    } else {
        /*tex We start the search with newest string below |s|; |search>1|! */
        str_number s = search - 1;
        while (s >= STRING_OFFSET) {
            /* The first |string_offset| of strings depend on the implementation! */
            if (str_length(s) == len)
                if (str_eq_str(s, search))
                    return s;
            s--;
        }
    }
    return 0;
}

str_number maketexstring(const char *s)
{
    if (s == NULL || *s == 0) {
        return get_nullstr();
    } else {
        return maketexlstring(s, strlen(s));
    }
}

str_number maketexlstring(const char *s, size_t l)
{
    if (s == NULL || l == 0) {
        return get_nullstr();
    } else {
        str_string(string_pool_state.str_ptr) = malloc((unsigned) (l + 1));
        memcpy(str_string(string_pool_state.str_ptr), s, (l + 1));
        str_length(string_pool_state.str_ptr) = (unsigned) l;
        string_pool_state.str_ptr++;
        return (string_pool_state.str_ptr - 1);
    }
}

/*tex

    This appends a C string to a \TEX\ string:

*/

void append_string(const unsigned char *s, unsigned l)
{
    if (s == NULL || *s == 0) {
        return;
    } else {
        l = (unsigned) strlen((const char *) s);
        str_room(l);
        memcpy(cur_string + cur_length, s, l);
        cur_length += l;
        return;
    }
}

char *makeclstring(int s, size_t * len)
{
    if (s < STRING_OFFSET) {
        *len = (size_t) utf8_size(s);
        return (char *) uni2str((unsigned) s);
    } else {
        unsigned l = (unsigned) str_length(s);
        char *cstrbuf = malloc(l + 1);
        memcpy(cstrbuf, str_string(s), l);
        cstrbuf[l] = '\0';
        *len = (size_t) l;
        return cstrbuf;
    }
}

char *makecstring(int s)
{
    if (s < STRING_OFFSET) {
        return (char *) uni2str((unsigned) s);
    } else {
        unsigned l = (unsigned) str_length(s);
        char *cstrbuf = malloc(l + 1);
        memcpy(cstrbuf, str_string(s), l);
        cstrbuf[l] = '\0';
        return cstrbuf;
    }
}

int dump_string_pool(void)
{
    int j;
    int k = string_pool_state.str_ptr;
    dump_int(k - STRING_OFFSET);
    for (j = STRING_OFFSET + 1; j < k; j++) {
        int l = (int) str_length(j);
        if (str_string(j) == NULL)
            l = -1;
        dump_int(l);
        if (l > 0)
            dump_things(*str_string(j), str_length(j));
    }
    return (k - STRING_OFFSET);
}

int undump_string_pool(void)
{
    int j;
    int x;
    undump_int(string_pool_state.str_ptr);
    if (main_state.max_strings < string_pool_state.str_ptr + main_state.strings_free)
        main_state.max_strings = string_pool_state.str_ptr + main_state.strings_free;
    string_pool_state.str_ptr += STRING_OFFSET;
    if (main_state.ini_version) {
        free(string_pool);
    }
    init_string_pool_array((unsigned) main_state.max_strings);
    for (j = STRING_OFFSET + 1; j < string_pool_state.str_ptr; j++) {
        undump_int(x);
        if (x >= 0) {
            str_length(j) = (unsigned) x;
            string_pool_state.pool_size += (unsigned) x;
            str_string(j) = mallocarray(unsigned char, (unsigned) (x + 1));
            undump_things(*str_string(j), (unsigned) x);
            *(str_string(j) + str_length(j)) = '\0';
        } else {
            str_length(j) = 0;
        }
    }
    string_pool_state.init_str_ptr = string_pool_state.str_ptr;
    return string_pool_state.str_ptr;
}

void init_string_pool(void)
{
    string_pool_state.str_ptr = (STRING_OFFSET + 1);
}

void init_string_pool_array(unsigned s)
{
    string_pool = mallocarray(lstring, s);
    _string_pool = string_pool - STRING_OFFSET;
    memset(string_pool, 0, s * sizeof(lstring));
    /* seed the null string */
    string_pool[0].s = malloc(1);
    string_pool[0].s[0] = '\0';
}

/*tex To destroy an already made string, we say |flush_str|. */

void flush_str(str_number s)
{
    if (s > STRING_OFFSET) {
        /*tex Don't ever delete the null string! */
        string_pool_state.pool_size -= (unsigned) str_length(s);
        str_length(s) = 0;
        free(str_string(s));
        str_string(s) = NULL;
    }
    while (str_string((string_pool_state.str_ptr - 1)) == NULL) {
        string_pool_state.str_ptr--;
    }
}
