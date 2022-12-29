/*
    See license.txt in the root of this project.
*/

# ifndef LMT_DUMPDATA_H
# define LMT_DUMPDATA_H

/*tex

    Originally the dump file was a memory dump, in \TEX\ called a format and in \NETAFONT\ a base
    and in \METAPOST\ a mem file. The \TEX\ program could reload that dump file and have a fast
    start. In addition a pool file was used to store strings. Because it was a memory dump. It was
    also pretty system dependent.

    When \WEBC\ showed up, \TEX\ installations got distributed on \CDROM\ and later \DVD, and
    because one could run them from that medium, format files were shared. In order to do that the
    file had to be endian neutral. Unfortunately the choice was such that for the most commonly
    architecture (intel) the dump items had to be swapped. This could slow down a startup, depending
    on how rigourous a compiler of operating system was in testing (it is a reason why startup on
    \MSWINDOWS\ was somewhat slower).

    Because in \LUATEX\ we can also store \LUA\ bytecodes it made no sense to take that portability
    aspect into account. The format file also got gzipped which at that time sped up loading. Later
    in the project the endian swappign was removed so we gained a bit more.

    Because a format file that doesn't match an engine can actually result in a crash, we decided to
    come up with amore robust approach: we use a magic number to register the version of the format!
    Normally this number only increments when we add a new primitive of change command codes. At
    some point in \LUATEX\ development we started with 907 which is the sum of the values of the
    bytes of \quote {don knuth}.

    We sometimes also bump when the binary format (bytecode) of \LUA\ has changed in such a way that
    the loader doesn't detect it. But that doesn't always help either because the cache is still
    problematic then. There we actually hard code a different number then (a simple patch of a \LUA\
    file).

    By the time that the \LUAMETATEX\ code as in a state to be released, it became time to think
    about a number that was definitely different from \LUATEX\ so here it is:

    \starttyping
    initial = 2020//4 - 2020//100 + 2020//400 = 490
    \stoptyping

    Although \LUAMETATEX\ is already a bit older, we sort of released in leapyear 2020 so we take
    the number of leapyears since zero (which is kind of \type {\undefined} as starting point). This
    number actually jumps whenever something affects the format file (which can be an extra command or
    some reshuffling of codes) so it is not always an indication of something really need.

    So to summarize: we don't share formats across architectures and operating systems, we use the
    native endian property of an architecture, we don't compress, and we bump a magic number so that
    we can intercept a potential crash. So much for a bit of history.

    We also bump the fingerprint when we have a new version of \LUA, just to play safe in case some 
    bytecodes have changed. 

*/

# define luametatex_format_fingerprint 682

/* These end up in the string pool. */

typedef struct dump_state_info {
    int fingerprint;
    int padding;
} dump_state_info;

extern dump_state_info lmt_dump_state;

extern void tex_store_fmt_file         (void);
extern int  tex_load_fmt_file          (void);
extern int  tex_fatal_undump_error     (const char *s);
extern void tex_initialize_dump_state  (void);

//define   dump_items(f,p,item_size,nitems)       fwrite((void *) p, (size_t) item_size, (size_t) nitems, f)
//define undump_items(f,p,item_size,nitems) { if (fread ((void *) p, (size_t) item_size, (size_t) nitems, f)) { } }

# define   dump_items(f,p,item_size,nitems) fwrite((void *) p, (size_t) item_size, (size_t) nitems, f)
# define undump_items(f,p,item_size,nitems) fread ((void *) p, (size_t) item_size, (size_t) nitems, f)

# define   dump_things(f,base,len)   dump_items(f, (char *) &(base), sizeof (base), (int) (len))
# define undump_things(f,base,len) undump_items(f, (char *) &(base), sizeof (base), (int) (len))

# define   dump_int(f,x)   dump_things(f,x,1)
# define undump_int(f,x) undump_things(f,x,1)

/*tex

    Because sometimes we dump constants or the result of a function call we have |dump_via_int|
    that puts the number into a variable first. Most integers come from structs and arrays.
    Performance wise there is not that much gain.

*/

# define dump_via_int(f,x) do { \
    int x_val = (x); \
    dump_int(f,x_val); \
} while (0)

# define dump_string(f,a) \
    if (a) { \
        int x = (int)strlen(a) + 1; \
        dump_int(f,x); \
        dump_things(f,*a, x); \
    } else { \
        dump_via_int(f,0); \
    }

# endif
