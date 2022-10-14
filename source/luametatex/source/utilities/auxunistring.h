/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_UNISTRING_H
# define LMT_UTILITIES_UNISTRING_H

extern unsigned char *aux_uni2str      (unsigned);
extern unsigned       aux_str2uni      (const unsigned char *);
extern char          *aux_uni2string   (char *utf8_text, unsigned ch);
extern unsigned       aux_splitutf2uni (unsigned int *ubuf, const char *utf8buf);
extern size_t         aux_utf8len      (const char *text, size_t size);

# define is_utf8_follow(a)    (a >= 0x80 && a < 0xC0)
# define utf8_size(a)         (a > 0xFFFF ? 4 : (a > 0x7FF ? 3 : (a > 0x7F ? 2 : 1)))
# define buffer_to_unichar(k) aux_str2uni((const unsigned char *)(lmt_fileio_state.io_buffer+k))

# endif
