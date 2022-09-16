/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Control sequence names and diagnostic messages are variable length strings of eight bit
    characters. Since \PASCAL\ did not have a well-developed string mechanism, \TEX\ did all of its
    string processing by homegrown methods.

    Elaborate facilities for dynamic strings are not needed, so all of the necessary operations can
    be handled with a simple data structure. The array |str_pool| contains all of the (eight-bit)
    bytes off all of the strings, and the array |str_start| contains indices of the starting points
    of each string. Strings are referred to by integer numbers, so that string number |s| comprises
    the characters |str_pool[j]| for |str_start_macro(s) <= j < str_start_macro (s + 1)|. Additional
    integer variables |pool_ptr| and |str_ptr| indicate the number of entries used so far in
    |str_pool| and |str_start|, respectively; locations |str_pool[pool_ptr]| and |str_start_macro
    (str_ptr)| are ready for the next string to be allocated.

    String numbers 0 to |biggest_char| are reserved for strings that correspond to single \UNICODE\
    characters. This is in accordance with the conventions of \WEB\ which converts single-character
    strings into the ASCII code number of the single character involved.

    The stringpool variables are collected in:

*/

string_pool_info lmt_string_pool_state = {
    .string_pool           = NULL,
    .string_pool_data      = {
        .minimum   = min_pool_size,
        .maximum   = max_pool_size,
        .size      = siz_pool_size,
        .step      = stp_pool_size,
        .allocated = 0,
        .itemsize  = sizeof(lstring),
        .top       = 0,
        .ptr       = 0,
        .initial   = 0,
        .offset    = cs_offset_value,
    },
    .string_body_data      = {
        .minimum   = min_body_size,
        .maximum   = max_body_size,
        .size      = siz_body_size,
        .step      = stp_body_size,
        .allocated = 0,
        .itemsize  = sizeof(unsigned char),
        .top       = memory_data_unset,
        .ptr       = memory_data_unset,
        .initial   = 0,
        .offset    = 0,
    },
    .reserved              = 0,
    .string_max_length     = 0,
    .string_temp           = NULL,
    .string_temp_allocated = 0,
    .string_temp_top       = 0,
};

/*tex

    The array of strings is |string_pool|, the number of the current string being created is
    |str_ptr|, the starting value of |str_ptr| is |init_str_ptr|, and the current string buffer,
    the current index in that buffer, the mallocedsize of |cur_string| and the occupied byte count
    are kept in |cur_string|, |cur_length|, |cur_string_size| and |pool_size|.

    Once a sequence of characters has been appended to |cur_string|, it officially becomes a string
    when the function |make_string| is called. This function returns the identification number of
    the new string as its value.

    Strings end with a zero character which makes \TEX\ string also valid \CCODE\ strings. The
    |string_temp*| fields deal with a temporary string (building).

    The |ptr| is always one ahead. This is kind of a safeguard: an overflow happens already when we
    still assemble a new string.

*/

# define initial_temp_string_slots  256
# define reserved_temp_string_slots   2

static inline void tex_aux_increment_pool_string(int n)
{
    lmt_string_pool_state.string_body_data.allocated += n;
    if (lmt_string_pool_state.string_body_data.allocated > lmt_string_pool_state.string_body_data.size) {
        tex_overflow_error("poolbody", lmt_string_pool_state.string_body_data.allocated);
    }
}

static inline void tex_aux_decrement_pool_string(int n)
{
    lmt_string_pool_state.string_body_data.allocated -= n;
}

static void tex_aux_flush_cur_string(void)
{
    if (lmt_string_pool_state.string_temp) {
        aux_deallocate_array(lmt_string_pool_state.string_temp);
    }
    lmt_string_pool_state.string_temp = NULL;
    lmt_string_pool_state.string_temp_top = 0;
    lmt_string_pool_state.string_temp_allocated = 0;
}

void tex_reset_cur_string(void)
{
    unsigned char *tmp = aux_allocate_clear_array(sizeof(unsigned char), initial_temp_string_slots, reserved_temp_string_slots);
    if (tmp) {
        lmt_string_pool_state.string_temp = tmp;
        lmt_string_pool_state.string_temp_top = 0;
        lmt_string_pool_state.string_temp_allocated = initial_temp_string_slots;
    } else {
        tex_overflow_error("pool", initial_temp_string_slots);
    }
}

static int tex_aux_room_in_string(int wsize)
{
    /* no callback here */
    if (! lmt_string_pool_state.string_temp) {
        tex_reset_cur_string();
    }
    if ((lmt_string_pool_state.string_temp_top + wsize) > lmt_string_pool_state.string_temp_allocated) {
        unsigned char *tmp = NULL;
        int size = lmt_string_pool_state.string_temp_allocated + lmt_string_pool_state.string_temp_allocated / 5 + STRING_EXTRA_AMOUNT;
        if (size < wsize) {
            size = wsize + STRING_EXTRA_AMOUNT;
        }
        tmp = aux_reallocate_array(lmt_string_pool_state.string_temp, sizeof(unsigned char), size, reserved_temp_string_slots);
        if (tmp) {
            lmt_string_pool_state.string_temp = tmp;
            memset(tmp + lmt_string_pool_state.string_temp_top, 0, (size_t) size - lmt_string_pool_state.string_temp_top);
        } else {
            tex_overflow_error("pool", size);
        }
        lmt_string_pool_state.string_temp_allocated = size;
    }
    return 1;
}

# define reserved_string_slots 1

/*tex Messy: ptr and top have cs_offset_value included */

void tex_initialize_string_mem(void)
{
    int size = lmt_string_pool_state.string_pool_data.minimum;
    if (lmt_main_state.run_state == initializing_state) {
        size = lmt_string_pool_state.string_pool_data.minimum;
        lmt_string_pool_state.string_pool_data.ptr = cs_offset_value;
    } else {
        size = lmt_string_pool_state.string_pool_data.allocated;
        lmt_string_pool_state.string_pool_data.initial = lmt_string_pool_state.string_pool_data.ptr;
    }
    if (size > 0) {
        lstring *pool = aux_allocate_clear_array(sizeof(lstring), size, reserved_string_slots);
        if (pool) {
            lmt_string_pool_state.string_pool = pool;
            lmt_string_pool_state.string_pool_data.allocated = size;
        } else {
            tex_overflow_error("pool", size);
        }
    }
}

void tex_initialize_string_pool(void)
{
    unsigned char *nullstring = lmt_memory_malloc(1);
    int size = lmt_string_pool_state.string_pool_data.allocated;
    if (size && nullstring) {
        lmt_string_pool_state.string_pool[0].s = nullstring;
        nullstring[0] = '\0';
        lmt_string_pool_state.string_pool_data.ptr += 1;
        tex_reset_cur_string();
    } else {
        tex_overflow_error("pool", size);
    }
}

static int tex_aux_room_in_string_pool(int n)
{
    int top = lmt_string_pool_state.string_pool_data.ptr + n;
    if (top > lmt_string_pool_state.string_pool_data.top) {
        lmt_string_pool_state.string_pool_data.top = top;
        top -=  cs_offset_value;
        if (top > lmt_string_pool_state.string_pool_data.allocated) {
            lstring *tmp = NULL;
            top = lmt_string_pool_state.string_pool_data.allocated;
            do {
                top += lmt_string_pool_state.string_pool_data.step;
                n -= lmt_string_pool_state.string_pool_data.step;
            } while (n > 0);
            if (top > lmt_string_pool_state.string_pool_data.size) {
                top = lmt_string_pool_state.string_pool_data.size;
            }
            if (top > lmt_string_pool_state.string_pool_data.allocated) {
                lmt_string_pool_state.string_pool_data.allocated = top;
                tmp = aux_reallocate_array(lmt_string_pool_state.string_pool, sizeof(lstring), top, reserved_string_slots);
                lmt_string_pool_state.string_pool = tmp;
            }
            lmt_run_memory_callback("pool", tmp ? 1 : 0);
            if (! tmp) {
                tex_overflow_error("pool", top);
                return 0;
            }
        }
    }
    return 1;
}

/*tex

    Checking for the last one to be the same as the previous one doesn't save much some 10K on a
    \CONTEXT\ format.

*/

strnumber tex_make_string(void)
{
    if (tex_aux_room_in_string(1)) {
        int ptr = lmt_string_pool_state.string_pool_data.ptr;
        lmt_string_pool_state.string_temp[lmt_string_pool_state.string_temp_top] = '\0';
        str_string(ptr) = lmt_string_pool_state.string_temp;
        str_length(ptr) = lmt_string_pool_state.string_temp_top;
        tex_aux_increment_pool_string(lmt_string_pool_state.string_temp_top);
        tex_reset_cur_string();
        if (tex_aux_room_in_string_pool(1)) {
            lmt_string_pool_state.string_pool_data.ptr++;
        }
        return ptr;
    } else {
        return get_nullstr();
    }
}

strnumber tex_push_string(const unsigned char *s, int l)
{
    if (tex_aux_room_in_string_pool(1)) {
        unsigned char *t = lmt_memory_malloc(sizeof(char) * ((size_t) l + 1));
        if (t) {
            int ptr = lmt_string_pool_state.string_pool_data.ptr;
            memcpy(t, s, l);
            t[l] = '\0';
            str_string(ptr) = t;
            str_length(ptr) = l;
            lmt_string_pool_state.string_pool_data.ptr++;
            tex_aux_increment_pool_string(l);
            return ptr;
        }
    }
    return get_nullstr();
}

char *tex_take_string(int *len)
{
    char* ptr = NULL;
    if (tex_aux_room_in_string(1)) {
        lmt_string_pool_state.string_temp[lmt_string_pool_state.string_temp_top] = '\0';
        if (len) {
            *len = lmt_string_pool_state.string_temp_top;
        }
        ptr = (char *) lmt_string_pool_state.string_temp;
        tex_reset_cur_string();
    }
    return ptr;
}

/*tex

    The following subroutine compares string |s| with another string of the same length that appears
    in |buffer| starting at position |k|; the result is |true| if and only if the strings are equal.
    Empirical tests indicate that |str_eq_buf| is used in such a way that it tends to return |true|
    about 80 percent of the time.

    \startyping
    unsigned char *j = str_string(s);
    unsigned char *l = j + str_length(s);
    while (j < l) {
        if (*j++ != buffer[k++])
            return 0;
    }
    \stoptyping

*/

int tex_str_eq_buf(strnumber s, int k, int n)
{
    if (s < cs_offset_value) {
        return buffer_to_unichar(k) == (unsigned int) s;
    } else {
        return memcmp(str_string(s), &lmt_fileio_state.io_buffer[k], n) == 0;
    }
}

/*tex

    Here is a similar routine, but it compares two strings in the string pool, and it does not
    assume that they have the same length.

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

int tex_str_eq_str(strnumber s, strnumber t)
{
    if (s >= cs_offset_value) {
        if (t >= cs_offset_value) {
            /* s and t are strings, this is the most likely test */
            return (str_length(s) == str_length(t)) && ! memcmp(str_string(s), str_string(t), str_length(s));
        } else {
            /* s is a string and t an unicode character, happens seldom */
            return (strnumber) aux_str2uni(str_string(s)) == t;
        }
    } else if (t >= cs_offset_value) {
        /* s is an unicode character and t is a string, happens seldom */
        return (strnumber) aux_str2uni(str_string(t)) == s;
    } else {
        /* s and t are unicode characters */
        return s == t;
    }
}

/*tex A string compare helper: */

int tex_str_eq_cstr(strnumber r, const char *s, size_t l)
{
    return (l == str_length(r)) && ! strncmp((const char *) (str_string(r)), s, l);
}

/*tex

    The initial values of |str_pool|, |str_start|, |pool_ptr|, and |str_ptr| are computed set in
    \INITEX\ mode. The first |string_offset| strings are single characters strings matching Unicode.
    There is no point in generating all of these. But |str_ptr| has initialized properly, otherwise
    |print_char| cannot see the difference between characters and strings.

*/

int tex_get_strings_started(void)
{
    tex_reset_cur_string();
    return 1;
}

/*tex

    The string recycling routines. \TEX\ uses 2 upto 4 {\em new} strings when scanning a filename
    in an |\input|, |\openin|, or |\openout| operation. These strings are normally lost because the
    reference to them are not saved after finishing the operation. |search_string| searches through
    the string pool for the given string and returns either 0 or the found string number. However,
    in \LUAMETATEX\ filenames (and fontnames) are implemented more efficiently so that code is gone.

*/

strnumber tex_maketexstring(const char *s)
{
    if (s && *s) {
        return tex_maketexlstring(s, strlen(s));
    } else {
        return get_nullstr();
    }
}

strnumber tex_maketexlstring(const char *s, size_t l)
{
    if (s && l > 0) {
        int ptr = lmt_string_pool_state.string_pool_data.ptr;
        size_t len = l + 1;
        unsigned char *tmp = lmt_memory_malloc(len);
        if (tmp) {
            str_length(ptr) = l;
            str_string(ptr) = tmp;
            tex_aux_increment_pool_string((int) l);
            memcpy(tmp, s, len);
            if (tex_aux_room_in_string_pool(1)) {
                lmt_string_pool_state.string_pool_data.ptr += 1;
            }
            return ptr;
        } else {
            tex_overflow_error("string pool", (int) len);
        }
    }
    return get_nullstr();
}

/*tex
    These two functions appends bytes to the current \TEX\ string. There is no checking on what
    gets appended nd as in \LUA\ zero bytes are okay. Unlike the other engines we don't provide
    |^^| escaping, which is already optional in \LUATEX.
*/

void tex_append_string(const unsigned char *s, unsigned l)
{
    if (s && l > 0 && tex_aux_room_in_string(l)) {
        memcpy(lmt_string_pool_state.string_temp + lmt_string_pool_state.string_temp_top, s, l);
        lmt_string_pool_state.string_temp_top += l;
    }
}

void tex_append_char(unsigned char c)
{
    if (tex_aux_room_in_string(1)) {
        lmt_string_pool_state.string_temp[lmt_string_pool_state.string_temp_top++] = (unsigned char) c;
    }
}

char *tex_makeclstring(int s, size_t *len)
{
    if (s < cs_offset_value) {
        *len = (size_t) utf8_size(s);
        return (char *) aux_uni2str((unsigned) s);
    } else {
        size_t l = (size_t) str_length(s);
        char *tmp = lmt_memory_malloc(l + 1);
        if (tmp) {
            memcpy(tmp, str_string(s), l);
            tmp[l] = '\0';
            *len = l;
            return tmp;
        } else {
            tex_overflow_error("string pool", (int) l);
            *len = 0;
            return NULL;
        }
    }
}

char *tex_makecstring(int s)
{
    if (s < cs_offset_value) {
        return (char *) aux_uni2str((unsigned) s);
    } else {
        return lmt_memory_strdup((str_length(s) > 0) ? (const char *) str_string(s) : "");
    }
}

/*tex

    We can save some 150 K on the format file size by using a signed char as length (after checking)
    because the max size of a string in \CONTEXT\ is around 70. A flag could indicate if we use 1 or
    4 bytes for the length. But not yet (preroll needed). Dumping and undumping all strings in a
    block (where we need to zero terminate them) doesn't really work out any better. Okay, in the end
    it was done.

*/

/*tex We use the real accessors here, not the macros that use |cs_offset_value|. */

void tex_compact_string_pool(void)
{
    int n_of_strings = lmt_string_pool_state.string_pool_data.ptr - cs_offset_value;
    int max_length = 0;
    for (int j = 1; j < n_of_strings; j++) {
        if (lmt_string_pool_state.string_pool[j].l > (unsigned int) max_length) {
            max_length = (int) lmt_string_pool_state.string_pool[j].l;
        }
    }
    lmt_string_pool_state.string_max_length = max_length;
    tex_print_format("max string length %i, ", max_length);
}

void tex_dump_string_pool(dumpstream f)
{
    int n_of_strings = lmt_string_pool_state.string_pool_data.ptr - cs_offset_value;
    int total_length = lmt_string_pool_state.string_body_data.allocated;
    int max_length = lmt_string_pool_state.string_max_length;
    dump_via_int(f, lmt_string_pool_state.string_pool_data.allocated);
    dump_via_int(f, lmt_string_pool_state.string_pool_data.top); /* includes cs_offset_value */
    dump_via_int(f, lmt_string_pool_state.string_pool_data.ptr); /* includes cs_offset_value */
    dump_via_int(f, n_of_strings);
    dump_via_int(f, max_length);
    dump_via_int(f, total_length);
    if (max_length > 0 && max_length < 126) {
        /*tex We only have short strings. */
        for (int j = 0; j < n_of_strings; j++) {
            int l = (int) lmt_string_pool_state.string_pool[j].l;
            char c;
            if (! lmt_string_pool_state.string_pool[j].s) {
                l = -1;
            }
            c = (char) l;
            dump_things(f, c, 1);
            if (l > 0) {
                dump_things(f, *lmt_string_pool_state.string_pool[j].s, l);
            }
        }
    } else {
        /*tex We also have long strings. */
        for (int j = 0; j < n_of_strings; j++) {
            int l = (int) lmt_string_pool_state.string_pool[j].l;
            if (! lmt_string_pool_state.string_pool[j].s) {
                l = -1;
            }
            dump_int(f, l);
            if (l > 0) {
                dump_things(f, *lmt_string_pool_state.string_pool[j].s, l);
            }
        }
    }
}

void tex_undump_string_pool(dumpstream f)
{
    int n_of_strings;
    int max_length;
    int total_length;
    undump_int(f, lmt_string_pool_state.string_pool_data.allocated);
    undump_int(f, lmt_string_pool_state.string_pool_data.top); /* includes cs_offset_value */
    undump_int(f, lmt_string_pool_state.string_pool_data.ptr); /* includes cs_offset_value */
    undump_int(f, n_of_strings);
    undump_int(f, max_length);
    undump_int(f, total_length);
    lmt_string_pool_state.string_max_length = max_length;
    tex_initialize_string_mem();
    {
        int a = 0;
        int compact = max_length > 0 && max_length < 126;
        for (int j = 0; j < n_of_strings; j++) {
            int x;
            if (compact) {
                /*tex We only have short strings. */
                char c;
                undump_things(f, c, 1);
                x = c;
            } else {
                /*tex We also have long strings. */
                undump_int(f, x);
            }
            if (x >= 0) {
                /* we can overflow reserved_string_slots */
                int n = x + 1;
                unsigned char *s = aux_allocate_clear_array(sizeof(unsigned char), n, reserved_string_slots);
                if (s) {
                    lmt_string_pool_state.string_pool[j].s = s;
                    undump_things(f, s[0], x);
                    s[x] = '\0';
                    a += n;
                } else {
                    tex_overflow_error("string pool", n);
                    x = 0;
                }
            } else {
                x = 0;
            }
            lmt_string_pool_state.string_pool[j].l = x;
        }
        lmt_string_pool_state.string_body_data.allocated = a;
        lmt_string_pool_state.string_body_data.initial = a;
    }
}

/*tex To destroy an already made string, we say |flush_str|. */

void tex_flush_str(strnumber s)
{
    if (s > cs_offset_value) {
        /*tex Don't ever delete the null string! */
        tex_aux_decrement_pool_string((int) str_length(s));
        str_length(s) = 0;
        lmt_memory_free(str_string(s));
        str_string(s) = NULL;
     // string_pool_state.string_pool_data.ptr--;
    }
    /* why a loop and not in previous branch */
    while (! str_string((lmt_string_pool_state.string_pool_data.ptr - 1))) {
        lmt_string_pool_state.string_pool_data.ptr--;
    }
}

/*
    In the old filename code we had the following, but I suspect some mem issue there (as we ran
    into GB leaks for thousands of names):

    u = save_cur_string();
    get_x_token();
    restore_cur_string(u);
*/

strnumber tex_save_cur_string(void)
{
    return (lmt_string_pool_state.string_temp_top > 0 ? tex_make_string() : 0);
}

void tex_restore_cur_string(strnumber u)
{
    if (u) {
        /*tex Beware, we have no 0 termination here! */
        int ul = (int) str_length(u);
        tex_aux_flush_cur_string();
        if (tex_aux_room_in_string(u)) {
            memcpy(lmt_string_pool_state.string_temp, str_string(u), ul);
            lmt_string_pool_state.string_temp_allocated = ul;
            lmt_string_pool_state.string_temp_top = ul;
            tex_flush_str(u);
        }
    }
}
