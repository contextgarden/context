/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"


/*tex

    The 5- and 6-byte UTF-8 sequences generate integers that are outside
    of the valid UCS range, and therefore unsupported. We recover from
    an error with |0xFFFD|.

*/

unsigned str2uni(const unsigned char *k)
{
    int ch;
    const unsigned char *text = k;
    if ((ch = *text++) < 0x80) {
        return (unsigned) ch;
    } else if (ch <= 0xbf) {
        return 0xFFFD;
    } else if (ch <= 0xdf) {
        if (*text >= 0x80 && *text < 0xc0) {
            return (unsigned) (((ch & 0x1f) << 6) | (*text++ & 0x3f));
        }
    } else if (ch <= 0xef) {
        if (*text >= 0x80 && *text < 0xc0 && text[1] >= 0x80 && text[1] < 0xc0) {
            return (unsigned) (((ch & 0xf) << 12) | ((text[0] & 0x3f) << 6) | (text[1] & 0x3f));
        }
    } else if (ch <= 0xf7) {
        if (*text <  0x80 || text[1] <  0x80 || text[2] <  0x80 ||
            *text >= 0xc0 || text[1] >= 0xc0 || text[2] >= 0xc0) {
            return 0xFFFD;
        } else {
            int w1 = (((ch & 0x7) << 2) | ((text[0] & 0x30) >> 4)) - 1;
            int w2 = ((text[1] & 0xf) << 6) | (text[2] & 0x3f);
            w1 = (w1 << 6) | ((text[0] & 0xf) << 2) | ((text[1] & 0x30) >> 4);
            return (unsigned) (w1 * 0x400 + w2 + 0x10000);
        }
    }
    return 0xFFFD;
}

/*tex A real basic helper. */

unsigned char *uni2str(unsigned unic)
{
    unsigned char *buf = malloc(5);
    unsigned char *pt = buf;
    if (likely(unic < 0x80)) {
        *pt++ = (unsigned char) unic;
    } else if (unic < 0x800) {
        *pt++ = (unsigned char) (0xc0 | (unic >> 6));
        *pt++ = (unsigned char) (0x80 | (unic & 0x3f));
    } else if (unic >= 0x110000) {
        *pt++ = (unsigned char) (unic - 0x110000);
    } else if (unic < 0x10000) {
        *pt++ = (unsigned char) (0xe0 | (unic >> 12));
        *pt++ = (unsigned char) (0x80 | ((unic >> 6) & 0x3f));
        *pt++ = (unsigned char) (0x80 | (unic & 0x3f));
    } else {
        unsigned val = unic - 0x10000;
        int u = (int) (((val & 0xf0000) >> 16) + 1);
        int z = (int)  ((val & 0x0f000) >> 12);
        int y = (int)  ((val & 0x00fc0) >> 6);
        int x = (int)   (val & 0x0003f);
        *pt++ = (unsigned char) (0xf0 | (u >> 2));
        *pt++ = (unsigned char) (0x80 | ((u & 3) << 4) | z);
        *pt++ = (unsigned char) (0x80 | y);
        *pt++ = (unsigned char) (0x80 | x);
    }
    *pt = '\0';
    return buf;
}

/*tex

    Function |buffer_to_unichar| converts a sequence of bytes in the |buffer|
    into a unicode character value. It does not check for overflow of the
    |buffer|, but it is careful to check the validity of the \UTF-8 encoding.

*/

char *uni2string(char *utf8_text, unsigned ch)
{
    /*tex Increment and deposit character: */
    if (ch <= 127)
        *utf8_text++ = (char) ch;
    else if (ch <= 0x7ff) {
        *utf8_text++ = (char) (0xc0 | (ch >> 6));
        *utf8_text++ = (char) (0x80 | (ch & 0x3f));
    } else if (ch <= 0xffff) {
        *utf8_text++ = (char) (0xe0 | (ch >> 12));
        *utf8_text++ = (char) (0x80 | ((ch >> 6) & 0x3f));
        *utf8_text++ = (char) (0x80 | (ch & 0x3f));
    } else if (ch < 17 * 65536) {
        unsigned val = ch - 0x10000;
        unsigned u = ((val & 0xf0000) >> 16) + 1;
        unsigned z =  (val & 0x0f000) >> 12;
        unsigned y =  (val & 0x00fc0) >> 6;
        unsigned x =   val & 0x0003f;
        *utf8_text++ = (char) (0xf0 | (u >> 2));
        *utf8_text++ = (char) (0x80 | ((u & 3) << 4) | z);
        *utf8_text++ = (char) (0x80 | y);
        *utf8_text++ = (char) (0x80 | x);
    }
    return (utf8_text);
}

unsigned u_length(unsigned int *str) /*tex This one is only used once in |texlang.c|. */
{
    unsigned len = 0;
    while (*str++ != '\0')
        ++len;
    return (len);
}

void utf2uni_strcpy(unsigned int *ubuf, const char *utf8buf)
{
    int len = (int) strlen(utf8buf) + 1;
    unsigned int *upt = ubuf, *uend = ubuf + len - 1;
    const unsigned char *pt = (const unsigned char *) utf8buf, *end = pt + strlen(utf8buf);
    int w, w2;
    while (pt < end && *pt != '\0' && upt < uend) {
        if (*pt <= 127)
            *upt = *pt++;
        else if (*pt <= 0xdf) {
            *upt = (unsigned int) (((*pt & 0x1f) << 6) | (pt[1] & 0x3f));
            pt += 2;
        } else if (*pt <= 0xef) {
            *upt = (unsigned int) (((*pt & 0xf) << 12) | ((pt[1] & 0x3f) << 6) | (pt[2] & 0x3f));
            pt += 3;
        } else {
            w = (((*pt & 0x7) << 2) | ((pt[1] & 0x30) >> 4)) - 1;
            w = (w << 6) | ((pt[1] & 0xf) << 2) | ((pt[2] & 0x30) >> 4);
            w2 = ((pt[2] & 0xf) << 6) | (pt[3] & 0x3f);
            *upt = (unsigned int) (w * 0x400 + w2 + 0x10000);
            pt += 4;
        }
        ++upt;
    }
    *upt = '\0';
}
