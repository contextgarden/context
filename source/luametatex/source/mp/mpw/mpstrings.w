% This file is part of MetaPost. The MetaPost program is in the public domain.

@* String handling.

@ First, we will need some stuff from other files.
@c
# include "mpconfig.h"
# include "mpstrings.h"

@ Then there is some stuff we need to prepare ourselves.

@(mpstrings.h@>=
# ifndef MPSTRINGS_H
# define MPSTRINGS_H 1

# include "mp.h"

@<Definitions@>

# endif

@ Here are the functions needed for the avl construction.

@<Definitions@>=
void *mp_aux_copy_strings_entry (const void *p);

@ An earlier version of this function used |strncmp|, but that produces wrong
results in some cases.

@c
# define STRCMP_RESULT(a) ((a) < 0 ? -1 : ((a) > 0 ? 1 : 0))

static int mp_aux_comp_strings_entry(void *p, const void *pa, const void *pb)
{
    const mp_lstring *a = (const mp_lstring *) pa;
    const mp_lstring *b = (const mp_lstring *) pb;
    unsigned char *s = a->str;
    unsigned char *t = b->str;
    size_t l = a->len <= b->len ? a->len : b->len;
    (void) p;
    while (l-- > 0) {
        if (*s != *t) {
           return STRCMP_RESULT(*s - *t);
        } else {
            s++;
            t++;
        }
    }
    return STRCMP_RESULT((int)(a->len - b->len));
}

void *mp_aux_copy_strings_entry(const void *p)
{
    mp_string ff = mp_memory_allocate(sizeof(mp_lstring));
    if (ff) {
        const mp_lstring *fp = (const mp_lstring *) p;
        ff->str = mp_memory_allocate((size_t) fp->len + 1);
        if (ff->str) {
            memcpy((char *) ff->str, (char *) fp->str, fp->len + 1);
            ff->len = fp->len;
            ff->refs = 0;
            return ff;
        }
    }
    return NULL;
}

static void *delete_strings_entry(void *p)
{
    mp_string ff = (mp_string) p;
    mp_memory_free(ff->str);
    mp_memory_free(ff);
    return NULL;
}

@ Actually creating strings is done by |make_string|, but in order to do so it
needs a way to create a new, empty string structure.

@ @c
static mp_string new_strings_entry(void)
{
    mp_string ff = mp_memory_allocate(sizeof(mp_lstring));
    ff->str = NULL;
    ff->len = 0;
    ff->refs = 0;
    return ff;
}

@ Some even more low-level functions are these:

@<Definitions@>=
extern char *mp_strdup  (const char *s);
extern char *mp_strndup (const char *s, size_t l);
extern int   mp_strcmp  (const char *a, const char *b);

@ @c
char *mp_strdup(const char *s)
{
    if (s) {
        char *w = lmt_memory_strdup(s);
        if (w) {
            return w;
        } else {
            printf("mplib ran out of memory, case 3");
            exit(EXIT_FAILURE);
        }
    }
    return NULL;
}


char *mp_strndup(const char *p, size_t l)
{
    if (p) {
        char *r = mp_memory_allocate(l * sizeof(char) + 1);
        if (r) {
            char *s = memcpy(r, p, l);
            *(s + l) = '\0';
            return s;
        } else {
            printf("mplib ran out of memory, case 4");
            exit(EXIT_FAILURE);
        }
    }
    return NULL;
}

/*
char *mp_strndup(const char *p, size_t l)
{
    if (p) {
        char *w = strndup(p, l);
        if (w) {
            return w;
        } else {
            printf("mplib ran out of memory, case 4");
            exit(EXIT_FAILURE);
        }
    }
    return NULL;
}
*/

int mp_strcmp(const char *a, const char *b)
{
    return a == NULL ? (b == NULL ? 0 : -1) : (b == NULL ? 1 : strcmp(a, b));
}

@ @c
void mp_initialize_strings(MP mp)
{
    mp->strings = avl_create(mp_aux_comp_strings_entry, mp_aux_copy_strings_entry, delete_strings_entry, mp_memory_allocate, mp_memory_free, NULL);
    mp->cur_string = NULL;
    mp->cur_length = 0;
    mp->cur_string_size = 0;
}

@ @c
void mp_dealloc_strings(MP mp)
{
    if (mp->strings != NULL) {
        avl_destroy(mp->strings);
    } else {
        mp->strings = NULL;
        mp_memory_free(mp->cur_string);
        mp->cur_string = NULL;
        mp->cur_length = 0;
        mp->cur_string_size = 0;
    }
}

@ Here are the definitions:

@<Definitions@>=
extern void mp_initialize_strings (MP mp);
extern void mp_dealloc_strings    (MP mp);

@ Most printing is done from |char *|s, but sometimes not. Here are functions
that convert an internal string into a |char *| for use by the printing routines,
and vice versa.

@<Definitions@>=
char      *mp_str         (MP mp, mp_string s);
mp_string  mp_rtsl        (MP mp, const char *s, size_t l);
mp_string  mp_rts         (MP mp, const char *s);
mp_string  mp_make_string (MP mp);

@ @c
char *mp_str(MP mp, mp_string ss)
{
    (void) mp;
    return (char *) ss->str;
}

@ @c
mp_string mp_rtsl(MP mp, const char *s, size_t l)
{
    mp_string nstr;
    mp_string str = new_strings_entry();
    str->str = (unsigned char *) mp_strndup(s, l);
    str->len = l;
    nstr = (mp_string) avl_find(str, mp->strings);
    if (nstr == NULL) {
        avl_ins(str, mp->strings, avl_false);
        nstr = (mp_string) avl_find(str, mp->strings);
    }
    delete_strings_entry(str);
    add_str_ref(nstr);
    return nstr;
}

@ @c
mp_string mp_rts(MP mp, const char *s)
{
    return mp_rtsl(mp, s, strlen(s));
}

@ Strings are created by appending character codes to |cur_string|. The
|mp_append_char| function, defined here, does not check to see if the buffer overflows;
this test is supposed to be made before |mp_append_char| is used.

To test if there is room to append |l| more characters to |cur_string|, we shall
write |str_room(l)|, which tries to make sure there is enough room in the
|cur_string|.

@<Definitions@>=
extern void mp_append_char (MP mp, unsigned char c);
extern void mp_append_str  (MP mp, const char *s);
extern void mp_str_room    (MP mp, int wsize);

@ @c
# define EXTRA_STRING 500

void mp_str_room(MP mp, int wsize)
{
    /* we always add one more */
    if ((mp->cur_length + (size_t) wsize + 1) > mp->cur_string_size) {
        size_t nsize = mp->cur_string_size + mp->cur_string_size / 5 + EXTRA_STRING;
        if (nsize < (size_t) wsize) {
            nsize = (size_t) wsize + EXTRA_STRING;
        }
        mp->cur_string = (unsigned char *) mp_memory_reallocate(mp->cur_string, (size_t) nsize * sizeof(unsigned char));
        memset(mp->cur_string + mp->cur_length, 0, nsize-mp->cur_length);
        mp->cur_string_size = nsize;
    }
}

void mp_append_char(MP mp, unsigned char c)
{
    *(mp->cur_string + mp->cur_length) = c;
    mp->cur_length++;
}

void mp_append_str(MP mp, const char *s)
{
    int j = 0;
    while ((unsigned char) s[j]) {
        *(mp->cur_string + mp->cur_length) = s[j++];
        mp->cur_length++;
    }
}

@ At the very start of the metapost run and each time after |make_string| has
stored a new string in the avl tree, the |cur_string| variable has to be prepared
so that it will be ready to start creating a new string. The initial size is
fairly arbitrary, but setting it a little higher than expected helps prevent
|reallocs|.

@<Definitions@>=
void mp_reset_cur_string (MP mp);

@ @c
void mp_reset_cur_string(MP mp)
{
    mp_memory_free(mp->cur_string);
    mp->cur_length = 0;
    mp->cur_string_size = 63;
    mp->cur_string = (unsigned char *) mp_memory_allocate(64 * sizeof(unsigned char));
    memset(mp->cur_string, 0, 64);
}

@ \MP's string expressions are implemented in a brute-force way: Every new string
or substring that is needed is simply stored into the string pool. Space is
eventually reclaimed using the aid of a simple system system of reference counts.
@^reference counts@>

The number of references to string number |s| will be |s->refs|. The special
value |s->refs=MAX_STR_REF=127| is used to denote an unknown positive number of
references; such strings will never be recycled. If a string is ever referred to
more than 126 times, simultaneously, we put it in this category.

@<Definitions@>=
# define MAX_STR_REF    127 /* \quote {infinite} number of references */
# define add_str_ref(A) { if ( (A)->refs < MAX_STR_REF ) ((A)->refs)++; }

@ Here's what we do when a string reference disappears:

@<Definitions@>=
# define delete_str_ref(A) do {  \
    if ((A)->refs < MAX_STR_REF) { \
        if ((A)->refs > 1) \
            ((A)->refs)--;  \
        else \
            mp_flush_string(mp, (A)); \
    } \
  } while (0)

@ @<Definitions@>=
void mp_flush_string (MP mp, mp_string s);

@ @c
void mp_flush_string(MP mp, mp_string s) {
    if (s->refs == 0) {
        mp->strs_in_use--;
        mp->pool_in_use = mp->pool_in_use - (int) s->len;
        avl_del(s, mp->strings, NULL);
    }
}

@ Some C literals that are used as values cannot be simply added, their reference
count has to be set such that they can not be flushed.

@c
mp_string mp_intern(MP mp, const char *s)
{
    mp_string r = mp_rts(mp, s);
    r->refs = MAX_STR_REF;
    return r;
}

@ @<Definitions@>=
mp_string mp_intern (MP mp, const char *s);

@ Once a sequence of characters has been appended to |cur_string|, it officially
becomes a string when the function |make_string| is called. This function returns
a pointer to the new string as its value.

@<Definitions@>=
mp_string mp_make_string (MP mp);

@ @c
mp_string mp_make_string(MP mp)
{
    /* current string enters the pool */
    mp_string str;
    mp_lstring tmp;
    tmp.str = mp->cur_string;
    tmp.len = mp->cur_length;
    str = (mp_string) avl_find(&tmp, mp->strings);
    if (str == NULL) {
        str = mp_memory_allocate(sizeof(mp_lstring));
        str->str = mp->cur_string;
        str->len = tmp.len;
        avl_ins(str, mp->strings, avl_false);
        str = (mp_string) avl_find(&tmp, mp->strings);
        mp->pool_in_use = mp->pool_in_use + (int) str->len;
        if (mp->pool_in_use > mp->max_pl_used) {
            mp->max_pl_used = mp->pool_in_use;
        }
        mp->strs_in_use++;
        if (mp->strs_in_use > mp->max_strs_used) {
            mp->max_strs_used = mp->strs_in_use;
        }
    }
    add_str_ref(str);
    mp_reset_cur_string (mp);
    return str;
}

@ Here is a routine that compares two strings in the string pool, and it does not
assume that they have the same length. If the first string is lexicographically
greater than, less than, or equal to the second, the result is respectively
positive, negative, or zero.

@<Definitions@>=
int mp_str_vs_str (MP mp, mp_string s, mp_string t);

@ @c
int mp_str_vs_str(MP mp, mp_string s, mp_string t)
{
    (void) mp;
    return mp_aux_comp_strings_entry(NULL, (const void *) s, (const void *) t);
}

@ @<Definitions@>=
mp_string mp_cat (MP mp, mp_string a, mp_string b);

@ @c
mp_string mp_cat(MP mp, mp_string a, mp_string b)
{
    mp_string str;
    size_t saved_cur_length = mp->cur_length;
    unsigned char *saved_cur_string = mp->cur_string;
    size_t saved_cur_string_size = mp->cur_string_size;
    size_t needed = a->len + b->len;
    mp->cur_length = 0;
    /* |mp->cur_string = NULL;|  needs malloc, spotted by clang */
    mp->cur_string = (unsigned char *) mp_memory_allocate((size_t) (needed + 1) * sizeof(unsigned char));
    mp->cur_string_size = 0;
    mp_str_room(mp, (int) needed + 1);
    memcpy(mp->cur_string, a->str, a->len);
    memcpy(mp->cur_string + a->len, b->str, b->len);
    mp->cur_length = needed;
    mp->cur_string[needed] = '\0';
    str = mp_make_string(mp);
    mp_memory_free(mp->cur_string); /* created by |mp_make_string| */
    mp->cur_length = saved_cur_length;
    mp->cur_string = saved_cur_string;
    mp->cur_string_size = saved_cur_string_size;
    return str;
}

@ @<Definitions@>=
mp_string mp_chop_string (MP mp, mp_string s, int a, int b);

@ @c
mp_string mp_chop_string(MP mp, mp_string s, int a, int b)
{
    int l = (int) s->len;
    int reversed;
    if (a <= b) {
        reversed = 0;
    } else {
        int k = a;
        a = b;
        b = k;
        reversed = 1;
    }
    if (a < 0) {
        a = 0;
        if (b < 0) {
            b = 0;
        }
    }
    if (b > l) {
        b = l;
        if (a > l) {
            a = l;
        }
    }
    mp_str_room(mp, (b - a));
    if (reversed) {
        for (int k = b - 1; k >= a; k--) {
            mp_append_char(mp, *(s->str + k));
        }
    } else {
        for (int k = a; k < b; k++) {
            mp_append_char(mp, *(s->str + k));
        }
    }
    return mp_make_string(mp);
}
