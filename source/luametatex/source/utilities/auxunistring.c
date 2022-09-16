/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    The 5- and 6-byte UTF-8 sequences generate integers that are outside of the valid UCS range,
    and therefore unsupported. We recover from an error with |0xFFFD|.

*/

unsigned aux_str2uni(const unsigned char *k)
{
    const unsigned char *text = k;
    int ch = *text++;
    if (ch < 0x80) {
        return (unsigned) ch;
    } else if (ch <= 0xbf) {
        return 0xFFFD;
    } else if (ch <= 0xdf) {
        if (text[0] >= 0x80 && text[0] < 0xc0) {
            return (unsigned) (((ch & 0x1f) << 6) | (text[0] & 0x3f));
        }
    } else if (ch <= 0xef) {
        if (text[0] >= 0x80 && text[0] < 0xc0 && text[1] >= 0x80 && text[1] < 0xc0) {
            return (unsigned) (((ch & 0xf) << 12) | ((text[0] & 0x3f) << 6) | (text[1] & 0x3f));
        }
    } else if (ch <= 0xf7) {
        if (text[0] <  0x80 || text[1] <  0x80 || text[2] <  0x80 ||
            text[0] >= 0xc0 || text[1] >= 0xc0 || text[2] >= 0xc0) {
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

unsigned char *aux_uni2str(unsigned unic)
{
    unsigned char *buf = lmt_memory_malloc(5);
    if (buf) {
        if (unic < 0x80) {
            buf[0] = (unsigned char) unic;
            buf[1] = '\0';
        } else if (unic < 0x800) {
            buf[0] = (unsigned char) (0xc0 | (unic >> 6));
            buf[1] = (unsigned char) (0x80 | (unic & 0x3f));
            buf[2] = '\0';
        } else if (unic >= 0x110000) {
            buf[0] = (unsigned char) (unic - 0x110000);
            buf[1] = '\0';
        } else if (unic < 0x10000) {
            buf[0] = (unsigned char) (0xe0 | (unic >> 12));
            buf[1] = (unsigned char) (0x80 | ((unic >> 6) & 0x3f));
            buf[2] = (unsigned char) (0x80 | (unic & 0x3f));
            buf[3] = '\0';
        } else {
            unic -= 0x10000;
            int u = (int) (((unic & 0xf0000) >> 16) + 1);
            buf[0] = (unsigned char) (0xf0 | (u >> 2));
            buf[1] = (unsigned char) (0x80 | ((u & 3) << 4) | ((unic & 0x0f000) >> 12));
            buf[2] = (unsigned char) (0x80 | ((unic & 0x00fc0) >> 6));
            buf[3] = (unsigned char) (0x80 | (unic & 0x0003f));
            buf[4] = '\0';
        }
    }
    return buf;
}

/*tex

    Function |buffer_to_unichar| converts a sequence of bytes in the |buffer| into a \UNICODE\
    character value. It does not check for overflow of the |buffer|, but it is careful to check
    the validity of the \UTF-8 encoding. For historical reasons all these small helpers look a bit
    different but that has a certain charm so we keep it.

*/

char *aux_uni2string(char *utf8_text, unsigned unic)
{
    /*tex Increment and deposit character: */
    if (unic <= 0x7f) {
        *utf8_text++ = (char) unic;
    } else if (unic <= 0x7ff) {
        *utf8_text++ = (char) (0xc0 | (unic >> 6));
        *utf8_text++ = (char) (0x80 | (unic & 0x3f));
    } else if (unic <= 0xffff) {
        *utf8_text++ = (char) (0xe0 | (unic >> 12));
        *utf8_text++ = (char) (0x80 | ((unic >> 6) & 0x3f));
        *utf8_text++ = (char) (0x80 | (unic & 0x3f));
    } else if (unic < 0x110000) {
        unic -= 0x10000;
        unsigned u = ((unic & 0xf0000) >> 16) + 1;
        *utf8_text++ = (char) (0xf0 | (u >> 2));
        *utf8_text++ = (char) (0x80 | ((u & 3) << 4) | ((unic & 0x0f000) >> 12));
        *utf8_text++ = (char) (0x80 | ((unic & 0x00fc0) >> 6));
        *utf8_text++ = (char) (0x80 | (unic & 0x0003f));
    }
    return (utf8_text);
}

unsigned aux_splitutf2uni(unsigned int *ubuf, const char *utf8buf)
{
    int len = (int) strlen(utf8buf);
    unsigned int *upt = ubuf;
    unsigned int *uend = ubuf + len;
    const unsigned char *pt = (const unsigned char *) utf8buf;
    const unsigned char *end = pt + len;
    while (pt < end && *pt != '\0' && upt < uend) {
        if (*pt <= 127) {
            *upt = *pt++;
        } else if (*pt <= 0xdf) {
            *upt = (unsigned int) (((*pt & 0x1f) << 6) | (pt[1] & 0x3f));
            pt += 2;
        } else if (*pt <= 0xef) {
            *upt = (unsigned int) (((*pt & 0xf) << 12) | ((pt[1] & 0x3f) << 6) | (pt[2] & 0x3f));
            pt += 3;
        } else {
            int w1 = (((*pt & 0x7) << 2) | ((pt[1] & 0x30) >> 4)) - 1;
            int w2 = ((pt[2] & 0xf) << 6) | (pt[3] & 0x3f);
            w1 = (w1 << 6) | ((pt[1] & 0xf) << 2) | ((pt[2] & 0x30) >> 4);
            *upt = (unsigned int) (w1 * 0x400 + w2 + 0x10000);
            pt += 4;
        }
        ++upt;
    }
    *upt = '\0';
    return (unsigned int) (upt - ubuf);
}

size_t aux_utf8len(const char *text, size_t size)
{
    size_t ls = size;
    size_t ind = 0;
    size_t num = 0;
    while (ind < ls) {
        unsigned char i = (unsigned char) *(text + ind);
        if (i < 0x80) {
            ind += 1;
        } else if (i >= 0xF0) {
            ind += 4;
        } else if (i >= 0xE0) {
            ind += 3;
        } else if (i >= 0xC0) {
            ind += 2;
        } else {
            ind += 1;
        }
        num += 1;
    }
    return num;
}
