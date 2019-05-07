/*
    See license.txt in the root of this project.
*/

# ifndef UTILS_UNISTRING_H
# define UTILS_UNISTRING_H

extern unsigned char *uni2str(unsigned);
extern unsigned str2uni(const unsigned char *);

extern char *uni2string(char *utf8_text, unsigned ch);
extern unsigned u_length(register unsigned int *str);
extern void utf2uni_strcpy(unsigned int *ubuf, const char *utf8buf);

# define is_utf8_follow(A) (A >= 0x80 && A < 0xC0)
# define utf8_size(a) (a>0xFFFF ? 4 : (a>0x7FF ? 3 : (a>0x7F? 2 : 1)))

# define buffer_to_unichar(k) str2uni((const unsigned char *)(iobuffer+k))

# endif

