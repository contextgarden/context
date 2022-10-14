/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_SPARSEARRAY_H
# define LMT_UTILITIES_SPARSEARRAY_H

/*tex

    This file originally was called |managed-sa| but becauss it kind of a library and also used in
    \LUATEX\ it's better to use a different name. In this variant dumping is more sparse (resulting
    in somewhat smaller format files). This might be backported but only after testing it here for a
    long time. Of course the principles are the same, it's just extended.

*/

/*tex

    The next two sets of three had better match up exactly, but using bare numbers is easier on the
    \CCODE\ compiler. Here are some format sizes (for ConTeXt) with different values:

     64 : 17562942
    128 : 17548150 <= best value
    256 : 17681398

*/

# define LMT_SA_HIGHPART 128
# define LMT_SA_MIDPART  128
# define LMT_SA_LOWPART  128

# define LMT_SA_H_PART(a) (((a)>>14)&127)
# define LMT_SA_M_PART(a) (((a)>> 7)&127)
# define LMT_SA_L_PART(a) ( (a)     &127)

/*tex

    In the early days of \LUATEX\ we had just simple items, all 32 bit values. Then we put the
    delcodes in trees too which saved memory and format size but it introduced 32 bit slack in all
    the other code arrays. We then also had to dump selectively, but it was no big deal. Eventually,
    once it became clear that the concepts would not change a variant was made for \LUAMETATEX: we
    just use a two times larger lower array when we have delimiters. This saves some memory. The
    price we pay is that a stack entry now has two values but that is not really an issue.

    By packing the math code values we loose the option to store an active state but that's no big
    deal.

    todo: consider simple char array for catcodes.

    The code here is somewhat messy because we generalized it a bit. Maybe I'll redo it some day.

 */

typedef struct sparse_state_info {
    memory_data sparse_data;
} sparse_state_info;

extern sparse_state_info lmt_sparse_state;

typedef struct sa_mathblob {
    unsigned int class_value:math_class_bits;
    unsigned int family_value:math_family_bits;
    unsigned int character_value:math_character_bits;
} sa_mathblob;

typedef struct sa_mathspec {
    unsigned short properties;
    unsigned short group;
    unsigned int   index;
} sa_mathspec;

typedef struct packed_math_character {
    union {
        sa_mathblob sa_value;
        unsigned    ui_value;
    };
} packed_math_character;

typedef union sa_tree_item {
    unsigned int   uint_value;
    int            int_value;
    sa_mathblob    math_code_value;
    sa_mathspec    math_spec_value;
    unsigned short ushort_value[2];
    unsigned char  uchar_value[4];
} sa_tree_item;

typedef struct sa_stack_item {
    int          code;
    int          level;
    sa_tree_item value_1;
    sa_tree_item value_2;
} sa_stack_item;

typedef struct sa_tree_head {
    int              sa_stack_size; /*tex initial stack size   */
    int              sa_stack_step; /*tex increment stack step */
    int              sa_stack_ptr;  /*tex current stack point  */
    sa_tree_item     dflt;          /*tex default item value   */
    sa_tree_item  ***tree;          /*tex item tree head       */
    sa_stack_item   *stack;         /*tex stack tree head      */
    int              bytes;         /*tex the number of items per entry */
    int              padding;
} sa_tree_head;

typedef sa_tree_head *sa_tree;

extern int          sa_get_item_1    (const sa_tree head, int n);
extern int          sa_get_item_2    (const sa_tree head, int n);
extern sa_tree_item sa_get_item_4    (const sa_tree head, int n);
extern sa_tree_item sa_get_item_8    (const sa_tree head, int n, sa_tree_item * v2);
extern void         sa_set_item_1    (sa_tree head, int n, int v, int gl);
extern void         sa_set_item_2    (sa_tree head, int n, int v, int gl);
extern void         sa_set_item_4    (sa_tree head, int n, sa_tree_item v, int gl);
extern void         sa_set_item_8    (sa_tree head, int n, sa_tree_item v1, sa_tree_item v2, int gl);
extern sa_tree      sa_new_tree      (int size, int bytes, sa_tree_item dflt);
extern sa_tree      sa_copy_tree     (sa_tree head);
extern void         sa_destroy_tree  (sa_tree head);
extern void         sa_dump_tree     (dumpstream f, sa_tree a);
extern sa_tree      sa_undump_tree   (dumpstream f);
extern void         sa_restore_stack (sa_tree a, int gl);
extern void         sa_clear_stack   (sa_tree a);

extern void         sa_set_item_n    (const sa_tree head, int n, int v, int gl);
extern int          sa_get_item_n    (const sa_tree head, int n);

inline static halfword sa_return_item_1(sa_tree head, halfword n)
{
    if (head->tree) {
        int hp = LMT_SA_H_PART(n);
        if (head->tree[hp]) {
            int mp = LMT_SA_M_PART(n);
            if (head->tree[hp][mp]) {
                return (halfword) head->tree[hp][mp][LMT_SA_L_PART(n)/4].uchar_value[n%4];
            }
        }
    }
    return (halfword) head->dflt.uchar_value[0];
}

inline static halfword sa_return_item_2(sa_tree head, halfword n)
{
    if (head->tree) {
        int hp = LMT_SA_H_PART(n);
        if (head->tree[hp]) {
            int mp = LMT_SA_M_PART(n);
            if (head->tree[hp][mp]) {
                return (halfword) head->tree[hp][mp][LMT_SA_L_PART(n)/2].ushort_value[n%2];
            }
        }
    }
    return (halfword) head->dflt.ushort_value[0];
}

inline static halfword sa_return_item_4(sa_tree head, halfword n)
{
    if (head->tree) {
        int hp = LMT_SA_H_PART(n);
        if (head->tree[hp]) {
            int mp = LMT_SA_M_PART(n);
            if (head->tree[hp][mp]) {
                return (halfword) head->tree[hp][mp][LMT_SA_L_PART(n)].int_value;
            }
        }
    }
    return (halfword) head->dflt.int_value;
}

inline static void sa_rawset_item_1(sa_tree head, halfword n, unsigned char v)
{
    head->tree[LMT_SA_H_PART(n)][LMT_SA_M_PART(n)][LMT_SA_L_PART(n)/4].uchar_value[n%4] = v;
}

inline static void sa_rawset_item_2(sa_tree head, halfword n, unsigned short v)
{
    head->tree[LMT_SA_H_PART(n)][LMT_SA_M_PART(n)][LMT_SA_L_PART(n)/2].ushort_value[n%2] = v;
}

inline static void sa_rawset_item_4(sa_tree head, halfword n, sa_tree_item v)
{
    head->tree[LMT_SA_H_PART(n)][LMT_SA_M_PART(n)][LMT_SA_L_PART(n)] = v;
}

inline static void sa_rawset_item_8(sa_tree head, halfword n, sa_tree_item v1, sa_tree_item v2)
{
    sa_tree_item *low = head->tree[LMT_SA_H_PART(n)][LMT_SA_M_PART(n)];
    int l = 2*LMT_SA_L_PART(n);
    low[l] = v1;
    low[l+1] = v2;
}

// inline them

extern void *sa_malloc_array  (int recordsize, int size);
extern void *sa_realloc_array (void *p, int recordsize, int size, int step);
extern void *sa_calloc_array  (int recordsize, int size);
extern void *sa_free_array    (void *p);
extern void  sa_wipe_array    (void *head, int recordsize, int size);

# endif
