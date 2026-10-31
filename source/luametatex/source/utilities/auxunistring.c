/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Invalid UTF-8 sequences and values outside the Unicode scalar range are unsupported. We recover
    from an error with |0xFFFD|.

*/

static inline int aux_is_utf8_follow(unsigned char c)
{
    return c >= 0x80 && c <= 0xBF;
}

static inline unsigned aux_normalize_unicode(unsigned unic)
{
    return unic <= 0x10FFFF && !(unic >= 0xD800 && unic <= 0xDFFF) ? unic : 0xFFFD;
}

unsigned aux_str2uni_len(const unsigned char *text, size_t size, int *len)
{
    unsigned char first;

    if (size == 0) {
        *len = 0;
        return 0xFFFD;
    }
    first = text[0];
    if (first < 0x80) {
        *len = 1;
        return (unsigned) first;
    } else if (first >= 0xC2 && first <= 0xDF) {
        if (size >= 2 && aux_is_utf8_follow(text[1])) {
            *len = 2;
            return (unsigned) (((first & 0x1F) << 6) | (text[1] & 0x3F));
        }
    } else if (first >= 0xE0 && first <= 0xEF) {
        if (size >= 3 && aux_is_utf8_follow(text[1]) && aux_is_utf8_follow(text[2]) &&
         ! (first == 0xE0 && text[1] < 0xA0) && !(first == 0xED && text[1] >= 0xA0)) {
            *len = 3;
            return (unsigned) (((first & 0x0F) << 12) | ((text[1] & 0x3F) << 6) | (text[2] & 0x3F));
        }
    } else if (first >= 0xF0 && first <= 0xF4) {
        if (size >= 4 && aux_is_utf8_follow(text[1]) && aux_is_utf8_follow(text[2]) && aux_is_utf8_follow(text[3]) &&
         ! (first == 0xF0 && text[1] < 0x90) && !(first == 0xF4 && text[1] > 0x8F)) {
            *len = 4;
            return (unsigned) (((first & 0x07) << 18) | ((text[1] & 0x3F) << 12) | ((text[2] & 0x3F) << 6) | (text[3] & 0x3F));
        }
    }
    *len = 1;
    return 0xFFFD;
}

unsigned aux_str2uni(const unsigned char *text)
{
    int len;
    return aux_str2uni_len(text, 4, &len);
}

unsigned char *aux_uni2str(unsigned unic)
{
    unsigned char *buf = lmt_memory_malloc(5);
    if (buf) {
        unic = aux_normalize_unicode(unic);
        if (unic < 0x80) {
            buf[0] = (unsigned char) unic;
            buf[1] = '\0';
        } else if (unic < 0x800) {
            buf[0] = (unsigned char) (0xC0 | (unic >> 6));
            buf[1] = (unsigned char) (0x80 | (unic & 0x3F));
            buf[2] = '\0';
        } else if (unic < 0x10000) {
            buf[0] = (unsigned char) (0xE0 |  (unic >> 12));
            buf[1] = (unsigned char) (0x80 | ((unic >>  6) & 0x3F));
            buf[2] = (unsigned char) (0x80 |  (unic        & 0x3F));
            buf[3] = '\0';
        } else if (unic < 0x110000) {
            buf[0] = (unsigned char) (0xF0 |  (unic >> 18));
            buf[1] = (unsigned char) (0x80 | ((unic >> 12) & 0x3F));
            buf[2] = (unsigned char) (0x80 | ((unic >>  6) & 0x3F));
            buf[3] = (unsigned char) (0x80 |  (unic        & 0x3F));
            buf[4] = '\0';
        }
    }
    return buf;
}

int aux_uni2strlen(unsigned unic, char *buf)
{
    unic = aux_normalize_unicode(unic);
    if (unic < 0x80) {
        buf[0] = (unsigned char) unic;
        buf[1] = '\0';
        return 1;
    } else if (unic < 0x800) {
        buf[0] = (unsigned char) (0xC0 | (unic >> 6));
        buf[1] = (unsigned char) (0x80 | (unic & 0x3F));
        buf[2] = '\0';
        return 2;
    } else if (unic < 0x10000) {
        buf[0] = (unsigned char) (0xE0 |  (unic >> 12));
        buf[1] = (unsigned char) (0x80 | ((unic >>  6) & 0x3F));
        buf[2] = (unsigned char) (0x80 |  (unic        & 0x3F));
        buf[3] = '\0';
        return 3;
    } else if (unic < 0x110000) {
        buf[0] = (unsigned char) (0xF0 |  (unic >> 18));
        buf[1] = (unsigned char) (0x80 | ((unic >> 12) & 0x3F));
        buf[2] = (unsigned char) (0x80 | ((unic >>  6) & 0x3F));
        buf[3] = (unsigned char) (0x80 |  (unic        & 0x3F));
        buf[4] = '\0';
        return 4;
    } else { 
        buf[0] = '\0';
        return 0;
    }
}

void aux_uni2str_callback(unsigned unic, void (*handle) (int))
{
    unic = aux_normalize_unicode(unic);
    if (unic < 0x80) {
        handle((unsigned char) unic);
    } else if (unic < 0x800) {
        handle((unsigned char) (0xC0 | (unic >> 6)));
        handle((unsigned char) (0x80 | (unic & 0x3F)));
    } else if (unic < 0x10000) {
        handle((unsigned char) (0xE0 | (unic >> 12)));
        handle((unsigned char) (0x80 | ((unic >> 6) & 0x3F)));
        handle((unsigned char) (0x80 | (unic & 0x3F)));
    } else if (unic < 0x110000) {
        handle((unsigned char) (0xF0 |  (unic >> 18)));
        handle((unsigned char) (0x80 | ((unic >> 12) & 0x3F)));
        handle((unsigned char) (0x80 | ((unic >>  6) & 0x3F)));
        handle((unsigned char) (0x80 |  (unic        & 0x3F)));
    }
}

/*tex

    Function |buffer_to_unichar| converts a sequence of bytes in the |buffer| into a \UNICODE\
    character value. It does not check for overflow of the |buffer|, but it is careful to check
    the validity of the \UTF-8 encoding. For historical reasons all these small helpers look a bit
    different but that has a certain charm so we keep it.

*/

char *aux_uni2string(char *utf8_text, unsigned unic)
{
    unic = aux_normalize_unicode(unic);
    /*tex Increment and deposit character: */
    if (unic <= 0x7F) {
        *utf8_text++ = (char) unic;
    } else if (unic <= 0x7FF) {
        *utf8_text++ = (char) (0xC0 | (unic >> 6));
        *utf8_text++ = (char) (0x80 | (unic & 0x3F));
    } else if (unic <= 0xFFFF) {
        *utf8_text++ = (char) (0xe0 | (unic >> 12));
        *utf8_text++ = (char) (0x80 | ((unic >> 6) & 0x3F));
        *utf8_text++ = (char) (0x80 | (unic & 0x3F));
    } else if (unic < 0x110000) {
        *utf8_text++ = (char) (0xF0 |  (unic >> 18));
        *utf8_text++ = (char) (0x80 | ((unic >> 12) & 0x3F));
        *utf8_text++ = (char) (0x80 | ((unic >>  6) & 0x3F));
        *utf8_text++ = (char) (0x80 |  (unic        & 0x3F));
    }
    return utf8_text;
}

/*tex This one could be more efficient because we know a bit more. */

unsigned aux_splitutf2uni(unsigned int *ubuf, const char *utf8buf)
{
    size_t len = strlen(utf8buf);
    unsigned int *upt = ubuf;
    unsigned int *uend = ubuf + len;
    const unsigned char *pt = (const unsigned char *) utf8buf;
    const unsigned char *end = pt + len;
    while (pt < end && upt < uend) {
        int ulen;
        *upt = aux_str2uni_len(pt, (size_t) (end - pt), &ulen);
        pt += (size_t) ulen;
        ++upt;
    }
    *upt = 0; /*tex We have integers here, so assigning |\0| is a bit misleading. */
    return (unsigned int) (upt - ubuf);
}

size_t aux_utf8len(const char *text, size_t size)
{
    size_t ind = 0;
    size_t num = 0;
    while (ind < size) {
        int len;
        aux_str2uni_len((const unsigned char *) text + ind, size - ind, &len);
        ind += (size_t) len;
        num += 1;
    }
    return num;
}

/*tex
    We can process 8 bytes at a time on 64-bit architectures. The memcpy is needed because
    we dont operate with (aligned) copies on the stack so we need to obey strict alignment
    conditions. We use the fact that > 127 means one bit is set. And the accumulator check
    does that for 8 bytes at once.

    Checking inside the loop gives bad branch prediction and we seldom have a hit and
    compilers will optimize this kind of loops anyway.

*/

# ifdef _MSC_VER
    # define fast_memcpy(dest, src, count) memcpy(dest, src, count)
# else
    # define fast_memcpy(dest, src, count) __builtin_memcpy(dest, src, count)
# endif

/*tex

    As we can apply this to whole files chunking makes more sense, so we add an extra outer
    loop. As usual this one went through a few steps, like figuring out how to optimize for
    small strings.

*/

inline int aux_onlyascii(const char *str, size_t len)
{

    if (! str) {
        return 0;
    }

    const unsigned char *s = (const unsigned char *) str;

    size_t   i   = 0;
    uint64_t acc = 0;

    /* fast (8 byte) word loop (automatically skipped if len < 8) */

    for (; i + 8 <= len; i += 8) {
        uint64_t chunk;
        fast_memcpy(&chunk, s + i, 8);
        acc |= chunk;
    }

    /* set initial status based on the accumulator */

    if ((acc & 0x8080808080808080ULL) != 0) {
        return 0;
    }

    /* only check the remainder (< 8 bytes) if the main chunks were clean */

    for (; i < len; i++) {
        if (s[i] > 127) {
            return 0;
        }
    }

    return 1;
}