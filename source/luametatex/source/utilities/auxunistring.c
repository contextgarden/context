/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    The 5- and 6-byte UTF-8 sequences generate integers that are outside of the valid UCS range,
    and therefore unsupported. We recover from an error with |0xFFFD|.

*/

unsigned aux_str2uni(const unsigned char *text)
{
    if (text[0] < 0x80) {
        return (unsigned) text[0];
    } else if (text[0] <= 0xBF) {
        return 0xFFFD;
    } else if (text[0] <= 0xDF) {
        if (text[1] >= 0x80 && text[1] < 0xC0) {
            return (unsigned) (((text[0] & 0x1F) << 6) | (text[1] & 0x3F));
        }
    } else if (text[0] <= 0xEF) {
        if (text[1] >= 0x80 && text[1] < 0xC0 && text[2] >= 0x80 && text[2] < 0xC0) {
            return (unsigned) (((text[0] & 0xF) << 12) | ((text[1] & 0x3F) << 6) | (text[2] & 0x3F));
        }
    } else if (text[0] <= 0xF7) {
        if (text[1] <  0x80 || text[2] <  0x80 || text[3] <  0x80 ||
            text[1] >= 0xC0 || text[2] >= 0xC0 || text[3] >= 0xC0) {
            return 0xFFFD;
        } else {
            int w1 = (((text[0] & 0x7) << 2) | ((text[1] & 0x30) >> 4)) - 1;
            int w2 = ((text[2] & 0xF) << 6) | (text[3] & 0x3F);
            w1 = (w1 << 6) | ((text[1] & 0xF) << 2) | ((text[2] & 0x30) >> 4);
            return (unsigned) (w1 * 0x400 + w2 + 0x10000);
        }
    }
    return 0xFFFD;
}

unsigned aux_str2uni_len(const unsigned char *text, int *len)
{
    if (text[0] < 0x80) {
        *len = 1;
        return (unsigned) text[0];
    } else if (text[0] <= 0xBF) {
        *len = 1;
        return 0xFFFD;
    } else if (text[0] <= 0xDF) {
        if (text[1] >= 0x80 && text[1] < 0xC0) {
            *len = 2;
            return (unsigned) (((text[0] & 0x1F) << 6) | (text[1] & 0x3F));
        }
    } else if (text[0] <= 0xEF) {
        if (text[1] >= 0x80 && text[1] < 0xC0 && text[2] >= 0x80 && text[2] < 0xC0) {
            *len = 3;
            return (unsigned) (((text[0] & 0xF) << 12) | ((text[1] & 0x3F) << 6) | (text[2] & 0x3F));
        }
    } else if (text[0] <= 0xF7) {
        if (text[1] <  0x80 || text[2] <  0x80 || text[3] <  0x80 ||
            text[1] >= 0xC0 || text[2] >= 0xC0 || text[3] >= 0xC0) {
            *len = 4;
            return 0xFFFD;
        } else {
            int w1 = (((text[0] & 0x7) << 2) | ((text[1] & 0x30) >> 4)) - 1;
            int w2 = ((text[2] & 0xF) << 6) | (text[3] & 0x3F);
            w1 = (w1 << 6) | ((text[1] & 0xF) << 2) | ((text[2] & 0x30) >> 4);
            *len = 4;
            return (unsigned) (w1 * 0x400 + w2 + 0x10000);
        }
    }
    *len = 1;
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
            buf[0] = (unsigned char) (0xC0 | (unic >> 6));
            buf[1] = (unsigned char) (0x80 | (unic & 0x3F));
            buf[2] = '\0';
        } else if (unic < 0x10000) {
            buf[0] = (unsigned char) (0xE0 | (unic >> 12));
            buf[1] = (unsigned char) (0x80 | ((unic >> 6) & 0x3F));
            buf[2] = (unsigned char) (0x80 | (unic & 0x3F));
            buf[3] = '\0';
        } else if (unic < 0x110000) {
            int u; 
            unic -= 0x10000;
            u = (int) (((unic & 0xF0000) >> 16) + 1);
            buf[0] = (unsigned char) (0xF0 | (u >> 2));
            buf[1] = (unsigned char) (0x80 | ((u & 3) << 4) | ((unic & 0xF000) >> 12));
            buf[2] = (unsigned char) (0x80 | ((unic & 0xFC0) >> 6));
            buf[3] = (unsigned char) (0x80 | (unic & 0x3F));
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
        unsigned u; 
        unic -= 0x10000;
        u = ((unic & 0xF0000) >> 16) + 1;
        *utf8_text++ = (char) (0xF0 | (u >> 2));
        *utf8_text++ = (char) (0x80 | ((u & 3) << 4) | ((unic & 0xF000) >> 12));
        *utf8_text++ = (char) (0x80 | ((unic & 0xFC0) >> 6));
        *utf8_text++ = (char) (0x80 | (unic & 0x3F));
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
        if (*pt <= 0x7F) {
            *upt = *pt++;
        } else if (*pt <= 0xDF) {
            *upt = (unsigned int) (((*pt & 0x1F) << 6) | (pt[1] & 0x3F));
            pt += 2;
        } else if (*pt <= 0xEF) {
            *upt = (unsigned int) (((*pt & 0xF) << 12) | ((pt[1] & 0x3F) << 6) | (pt[2] & 0x3F));
            pt += 3;
        } else {
            int w1 = (((*pt & 0x7) << 2) | ((pt[1] & 0x30) >> 4)) - 1;
            int w2 = ((pt[2] & 0xF) << 6) | (pt[3] & 0x3F);
            w1 = (w1 << 6) | ((pt[1] & 0xF) << 2) | ((pt[2] & 0x30) >> 4);
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
    size_t ind = 0;
    size_t num = 0;
    while (ind < size) {
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
