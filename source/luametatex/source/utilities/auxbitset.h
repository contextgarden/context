/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_BITSET_H
# define LMT_UTILITIES_BITSET_H

typedef struct bitset {
    int             max;
    unsigned char * set;
} bitset;

static bitset newbitset(int max)
{
    bitset b; /* play safe */
    b.set = lmt_memory_malloc((max + 1) / 8);
    if (b.set) {
        b.max = max;
        memset(b.set, 0, (max + 1) / 8);
    } else {
        b.max = 0;
    }
    return b;
}

static void disposebitset(bitset b)
{
    if (b.set) {
        lmt_memory_free(b.set);
    }
    b.set = NULL;
    b.max = 0;
}

static void wipebitset(bitset b)
{
    if (b.set) {
        memset(b.set, 0, (b.max + 1) / 8);
    }
}

inline static void setbit(bitset b, int i)
{
    if (b.set && i > 0 && i <= b.max) {
        b.set[i/8] += 1 << (i % 8);
    }
}

inline static int hasbit(bitset b, int i)
{
    return b.set && i > 0 && i <= b.max ? (b.set[i/8] & (1 << (i % 8))) != 0 : 0;
}

# endif 
