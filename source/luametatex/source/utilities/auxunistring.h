/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_UNISTRING_H
# define LMT_UTILITIES_UNISTRING_H

extern unsigned char *aux_uni2str         (unsigned unic);
extern int            aux_uni2strlen      (unsigned unic, char *buf);
extern void           aux_uni2str_callback(unsigned unic, void (*handle) (int));
extern unsigned       aux_str2uni         (const unsigned char *text);
extern unsigned       aux_str2uni_len     (const unsigned char *text, size_t size, int *len);
extern char          *aux_uni2string      (char *utf8_text, unsigned ch);
extern unsigned       aux_splitutf2uni    (unsigned int *ubuf, const char *utf8buf);
extern size_t         aux_utf8len         (const char *text, size_t size);

# define is_utf8_follow(a)    (a >= 0x80 && a < 0xC0)

static inline unsigned aux_utf8_size(unsigned a)
{
    if (a > 0x10FFFF || (a >= 0xD800 && a <= 0xDFFF)) {
        return 3;
    } else if (a > 0xFFFF) {
        return 4;
    } else if (a > 0x7FF) {
        return 3;
    } else if (a > 0x7F) {
        return 2;
    } else {
        return 1;
    }
}

# define utf8_size(a)         aux_utf8_size((unsigned) (a))
# define buffer_to_unichar(k) aux_str2uni((const unsigned char *)(lmt_fileio_state.io_buffer+k))

# endif
