/*
    See license.txt in the root of this project.
*/

# ifndef MANAGED_SA_H
# define MANAGED_SA_H 1

/*tex

    The next two sets of three had better match up exactly, but using bare
    numbers is easier on the \CCODE\ compiler

*/

# define HIGHPART 128
# define MIDPART  128
# define LOWPART  128

# define HIGHPART_PART(a) (((a)>>14)&127)
# define MIDPART_PART(a)  (((a)>>7)&127)
# define LOWPART_PART(a)  ((a)&127)

typedef union {
    unsigned int uint_value;
    int int_value;
    struct {
        int value_1;
        int value_2;
    } dump_int;
    struct {
        unsigned int value_1;
        unsigned int value_2;
    } dump_uint;
    struct {
        unsigned int character_value:21;
        unsigned int family_value:8;
        unsigned int class_value:3;
    } math_code_value;
    struct {
        unsigned int small_character_value:21;
        unsigned int small_family_value:8;
        unsigned int class_value:3;
        unsigned int large_character_value:21;
        unsigned int large_family_value:8;
        unsigned int dummy_value:3;
    } del_code_value;
} sa_tree_item;

typedef struct {
    int code;
    int level;
    sa_tree_item value;
} sa_stack_item;

typedef struct {
    int sa_stack_size;    /*tex initial stack size   */
    int sa_stack_step;    /*tex increment stack step */
    int sa_stack_type;
    int sa_stack_ptr;     /*tex current stack point  */
    sa_tree_item ***tree; /*tex item tree head       */
    sa_stack_item *stack; /*tex stack tree head      */
    sa_tree_item dflt;    /*tex default item value   */
} sa_tree_head;

typedef sa_tree_head *sa_tree;

extern sa_tree_item get_sa_item(const sa_tree head, const int n);
extern void set_sa_item(sa_tree head, int n, sa_tree_item v, int gl);
/*     void rawset_sa_item(sa_tree head, int n, sa_tree_item v); */

# define return_sa_item(head,n) do { \
    if (head->tree != NULL) { \
        int hp = HIGHPART_PART(n); \
        if (head->tree[hp] != NULL) { \
            int mp = MIDPART_PART(n); \
            if (head->tree[hp][mp] != NULL) { \
                return (halfword) head->tree[hp][mp][LOWPART_PART(n)].int_value; \
            } \
        } \
    } \
    return (halfword) head->dflt.int_value; \
} while (0)

# define rawset_sa_item(head,n,v) \
    head->tree[HIGHPART_PART(n)][MIDPART_PART(n)][LOWPART_PART(n)] = v;

extern sa_tree new_sa_tree(int size, int type, sa_tree_item dflt);

extern sa_tree copy_sa_tree(sa_tree head);
extern void destroy_sa_tree(sa_tree head);

extern void dump_sa_tree(sa_tree a);
extern sa_tree undump_sa_tree(void);

extern void restore_sa_stack(sa_tree a, int gl);
extern void clear_sa_stack(sa_tree a);

# endif
