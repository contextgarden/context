/*
    See license.txt in the root of this project.
*/

/*tex

    Here we implement sparse arrays with an embedded save stack. These functions are called very
    often but a few days of experimenting proved that there is not much to gain (if at all) from
    using macros or optimizations like preallocating and fast access to the first 128 entries. In
    practice the overhead is mostly in accessing memory and not in (probably inlined) calls. So, we
    should accept fate and wait for faster memory. It's the price we pay for being unicode on the
    one hand and sparse on the other.

*/

/*  
    
    We could do this: 

        v // 4  v % 4  =>  v >> 2  v & 3

    but let's just assume that the compiler optimzes it. 

    We could also pack the catcodes in single bytes but then we need to work with 
    
        nn = odd(n) ? n + 1 : n; 

    and things like:

        >> 1 
        & 0xF

    and for the setter that is more work because we need to overwrite the existing byte that now has
    two values and we also have the stack to deal with. We would save some memory but not that much. 

*/

# include "luametatex.h"

sparse_state_info lmt_sparse_state = {
    .sparse_data = {
        .minimum   = memory_data_unset,
        .maximum   = memory_data_unset,
        .size      = memory_data_unset,
        .step      = memory_data_unset,
        .allocated = 0,
        .itemsize  = 1,
        .top       = memory_data_unset,
        .ptr       = memory_data_unset,
        .initial   = memory_data_unset,
        .offset    = 0,
}
};

void *sa_malloc_array(int recordsize, int size)
{
    int allocated = recordsize * size;
    lmt_sparse_state.sparse_data.allocated += allocated;
    return lmt_memory_malloc((size_t) allocated);
}

void *sa_realloc_array(void *p, int recordsize, int size, int step)
{
    int deallocated = recordsize * size;
    int allocated = recordsize * (size + step);
    lmt_sparse_state.sparse_data.allocated += (allocated - deallocated);
    return lmt_memory_realloc(p, (size_t) allocated);
}

void *sa_calloc_array(int recordsize, int size)
{
    int allocated = recordsize * size;
    lmt_sparse_state.sparse_data.allocated += allocated;
    return lmt_memory_calloc((size_t) size, recordsize);
}

void sa_wipe_array(void *head, int recordsize, int size)
{
    memset(head, 0, recordsize * ((size_t) size));
}

void *sa_free_array(void *p)
{
    lmt_memory_free(p);
    return NULL;
}

/*tex

    Once we have two variants allocated we can dump and undump a |LOWPART| array in one go. But
    not yet. Currently the waste of one extra dummy int is cheaper than multiple functions.

*/

static void sa_aux_store_stack(const sa_tree head, int n, sa_tree_item v1, sa_tree_item v2, int gl)
{
    sa_stack_item st = {
        .code    = n,
        .value_1 = v1,
        .value_2 = v2,
        .level   = gl
    };
 // if (head->sa_stack_ptr && 
 //     head->stack[head->sa_stack_ptr].code == n && 
 //     head->stack[head->sa_stack_ptr].value_1.int_value == v1.int_value &&
 //     head->stack[head->sa_stack_ptr].value_2.int_value == v2.int_value &&
 //     head->stack[head->sa_stack_ptr].level == gl 
 //     ) {
 //     return;
 // }
    if (! head->stack) {
        head->stack = sa_malloc_array(sizeof(sa_stack_item), head->sa_stack_size);
    } else if (((head->sa_stack_ptr) + 1) >= head->sa_stack_size) {
        head->stack = sa_realloc_array(head->stack, sizeof(sa_stack_item), head->sa_stack_size, head->sa_stack_step);
        head->sa_stack_size += head->sa_stack_step;
    }
 // printf("store %i: code %i, v1 %i, v2 %i, level %i\n",head->identifier,st.code,st.value_1.int_value,st.value_2.int_value,st.level);
    (head->sa_stack_ptr)++;
    head->stack[head->sa_stack_ptr] = st;
}

static void sa_aux_skip_in_stack(const sa_tree head, int n)
{
    if (head->stack) {
        int p = head->sa_stack_ptr;
        while (p > 0) {
            if (head->stack[p].code == n && head->stack[p].level > 0) {
                head->stack[p].level = -(head->stack[p].level);
            }
         // printf("skip %i: code %i, v1 %i, v2 %i, level %i\n",head->identifier,head->stack[p].code,head->stack[p].value_1.int_value,head->stack[p].value_2.int_value,head->stack[p].level);
            p--;
        }
    }
}

// # define LMT_SA_L_PART_1(n) (LMT_SA_L_PART(n)/4)
// # define LMT_SA_L_SLOT_1(n) (n%4)
// # define LMT_SA_LOWPART_1   (LMT_SA_LOWPART/4)
// 
// # define LMT_SA_L_PART_2(n) (LMT_SA_L_PART(n)/2)
// # define LMT_SA_L_SLOT_2(n) (n%2)
// # define LMT_SA_LOWPART_2   (LMT_SA_LOWPART/2)
// 
// # define LMT_SA_L_PART_4(n) (LMT_SA_L_PART(n))
// # define LMT_SA_L_SLOT_4(n) (n)
// # define LMT_SA_LOWPART_4   (LMT_SA_LOWPART)

int sa_get_item_1(const sa_tree head, int n)
{
    // if (head->tree) {
        int h = LMT_SA_H_PART(n);
        if (head->tree[h]) {
            int m = LMT_SA_M_PART(n);
            if (head->tree[h][m]) {
                return head->tree[h][m][LMT_SA_L_PART(n)/4].uchar_value[n%4];
            }
        }
    // }
    return (int) head->dflt.uchar_value[0];
}

int sa_get_item_2(const sa_tree head, int n)
{
    // if (head->tree) {
        int h = LMT_SA_H_PART(n);
        if (head->tree[h]) {
            int m = LMT_SA_M_PART(n);
            if (head->tree[h][m]) {
                return head->tree[h][m][LMT_SA_L_PART(n)/2].ushort_value[n%2];
            }
        }
    // }
    return (int) head->dflt.ushort_value[0];
}

int sa_get_item_4(const sa_tree head, int n, sa_tree_item *v)
{
    // if (head->tree) {
        int h = LMT_SA_H_PART(n);
        if (head->tree[h]) {
            int m = LMT_SA_M_PART(n);
            if (head->tree[h][m]) {
                *v = head->tree[h][m][LMT_SA_L_PART(n)];
                return 1;
            }
        }
    // }
    *v = head->dflt;
    return 0;
}

int sa_get_item_8(const sa_tree head, int n, sa_tree_item *v1, sa_tree_item *v2)
{
    // if (head->tree) {
        int h = LMT_SA_H_PART(n);
        if (head->tree[h]) {
            int m = LMT_SA_M_PART(n);
            if (head->tree[h][m]) {
                int l = 2*LMT_SA_L_PART(n);
                *v1 = head->tree[h][m][l];
                *v2 = head->tree[h][m][l+1];
                return 1;
            }
        }
    // }
    *v1 = head->dflt;
    *v2 = head->dflt;
    return 0;
}

void sa_set_item_1(const sa_tree head, int n, int v, int gl)
{
    int h = LMT_SA_H_PART(n);
    int m = LMT_SA_M_PART(n);
    int l = LMT_SA_L_PART(n);
 // if (! head->tree) {
 //     head->tree = (sa_tree_item ***) sa_calloc_array(sizeof(sa_tree_item **), LMT_SA_HIGHPART);
 // }
    if (! head->tree[h]) {
        head->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(sa_tree_item *), LMT_SA_MIDPART);
    }
    if (! head->tree[h][m]) {
        head->tree[h][m] = (sa_tree_item *) sa_malloc_array(sizeof(sa_tree_item), LMT_SA_LOWPART/4);
        for (int i = 0; i < LMT_SA_LOWPART/4; i++) {
            head->tree[h][m][i] = head->dflt;
        }
    }
    if (gl <= 1) {
        sa_aux_skip_in_stack(head, n);
    } else {
        sa_aux_store_stack(head, n, head->tree[h][m][l/4], (sa_tree_item) { 0 }, gl);
    }
    head->tree[h][m][l/4].uchar_value[n%4] = (unsigned char) v;
}

void sa_set_item_2(const sa_tree head, int n, int v, int gl)
{
    int h = LMT_SA_H_PART(n);
    int m = LMT_SA_M_PART(n);
    int l = LMT_SA_L_PART(n);
 // if (! head->tree) {
 //     head->tree = (sa_tree_item ***) sa_calloc_array(sizeof(sa_tree_item **), LMT_SA_HIGHPART);
 // }
    if (! head->tree[h]) {
        head->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(sa_tree_item *), LMT_SA_MIDPART);
    }
    if (! head->tree[h][m]) {
        head->tree[h][m] = (sa_tree_item *) sa_malloc_array(sizeof(sa_tree_item), LMT_SA_LOWPART/2);
        for (int i = 0; i < LMT_SA_LOWPART/2; i++) {
            head->tree[h][m][i] = head->dflt;
        }
    }
    if (gl <= 1) {
        sa_aux_skip_in_stack(head, n);
    } else {
        sa_aux_store_stack(head, n, head->tree[h][m][l/2], (sa_tree_item) { 0 }, gl);
    }
    head->tree[h][m][l/2].ushort_value[n%2] = (unsigned short) v;
}

void sa_set_item_4(const sa_tree head, int n, sa_tree_item v, int gl)
{
    int h = LMT_SA_H_PART(n);
    int m = LMT_SA_M_PART(n);
    int l = LMT_SA_L_PART(n);
 // if (! head->tree) {
 //     head->tree = (sa_tree_item ***) sa_calloc_array(sizeof(sa_tree_item **), LMT_SA_HIGHPART);
 // }
    if (! head->tree[h]) {
        head->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(sa_tree_item *), LMT_SA_MIDPART);
    }
    if (! head->tree[h][m]) {
        head->tree[h][m] = (sa_tree_item *) sa_malloc_array(sizeof(sa_tree_item), LMT_SA_LOWPART);
        for (int i = 0; i < LMT_SA_LOWPART; i++) {
            head->tree[h][m][i] = head->dflt;
        }
    }
    if (gl <= 1) {
        sa_aux_skip_in_stack(head, n);
    } else {
        sa_aux_store_stack(head, n, head->tree[h][m][l], (sa_tree_item) { 0 }, gl);
    }
    head->tree[h][m][l] = v;
}

void sa_set_item_8(const sa_tree head, int n, sa_tree_item v1, sa_tree_item v2, int gl)
{
    int h = LMT_SA_H_PART(n);
    int m = LMT_SA_M_PART(n);
    int l = 2*LMT_SA_L_PART(n);
 // if (! head->tree) {
 //     head->tree = (sa_tree_item ***) sa_calloc_array(sizeof(sa_tree_item **), LMT_SA_HIGHPART);
 // }
    if (! head->tree[h]) {
        head->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(sa_tree_item *), LMT_SA_MIDPART);
    }
    if (! head->tree[h][m]) {
        head->tree[h][m] = (sa_tree_item *) sa_malloc_array(sizeof(sa_tree_item), 2 * LMT_SA_LOWPART);
        for (int i = 0; i < 2 * LMT_SA_LOWPART; i++) {
            head->tree[h][m][i] = head->dflt;
        }
    }
    if (gl <= 1) {
        sa_aux_skip_in_stack(head, n);
    } else {
        sa_aux_store_stack(head, n, head->tree[h][m][l], head->tree[h][m][l+1], gl);
    }
    head->tree[h][m][l] = v1;
    head->tree[h][m][l+1] = v2;
}

void sa_set_item_n(const sa_tree head, int n, int v, int gl)
{
    int h = LMT_SA_H_PART(n);
    int m = LMT_SA_M_PART(n);
    int l = LMT_SA_L_PART(n);
    int d = head->bytes == 1 ? 4 : (head->bytes == 2 ? 2 : 1);
 // if (! head->tree) {
 //     head->tree = (sa_tree_item ***) sa_calloc_array(sizeof(sa_tree_item **), LMT_SA_HIGHPART);
 // }
    if (! head->tree[h]) {
        head->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(sa_tree_item *), LMT_SA_MIDPART);
    }
    if (! head->tree[h][m]) {
        head->tree[h][m] = (sa_tree_item *) sa_malloc_array(sizeof(sa_tree_item), LMT_SA_LOWPART/d);
        for (int i = 0; i < LMT_SA_LOWPART/d; i++) {
            head->tree[h][m][i] = head->dflt;
        }
    }
    if (gl <= 1) {
        sa_aux_skip_in_stack(head, n);
    } else {
        sa_aux_store_stack(head, n, head->tree[h][m][l/d], (sa_tree_item) { 0 }, gl);
    }
    switch (head->bytes) {
        case 1:
            head->tree[h][m][l/4].uchar_value[n%4] = (unsigned char) (v < 0 ? 0 : (v > 0xFF ? 0xFF : v));
            break;
        case 2:
            head->tree[h][m][l/2].ushort_value[n%2] = (unsigned char) (v < 0 ? 0 : (v > 0xFFFF ? 0xFFFF : v));
            break;
        case 4:
            head->tree[h][m][l].int_value = v;
            break;
    }
}

int sa_get_item_n(const sa_tree head, int n)
{
 // if (head->tree) {
        int h = LMT_SA_H_PART(n);
        if (head->tree[h]) {
            int m = LMT_SA_M_PART(n);
            if (head->tree[h][m]) {
                switch (head->bytes) {
                    case 1 : return (int) head->tree[h][m][LMT_SA_L_PART(n)/4].uchar_value[n%4];
                    case 2 : return (int) head->tree[h][m][LMT_SA_L_PART(n)/2].ushort_value[n%2];
                    case 4 : return (int) head->tree[h][m][LMT_SA_L_PART(n)  ].int_value;
                }
            }
        }
 // }
    switch (head->bytes) {
        case 1 : return (int) head->dflt.uchar_value[n%4];
        case 2 : return (int) head->dflt.ushort_value[n%2];
        case 4 : return (int) head->dflt.int_value;
        default: return 0;
    }
}

void sa_clear_stack(const sa_tree a)
{
    if (a) {
        a->stack = sa_free_array(a->stack);
        a->sa_stack_ptr = 0;
        a->sa_stack_size = a->sa_stack_step;
    }
}

void sa_destroy_tree(sa_tree a)
{
    if (a) {
  //   if (a->tree) {
            for (int h = 0; h < LMT_SA_HIGHPART; h++) {
                if (a->tree[h]) {
                    for (int m = 0; m < LMT_SA_MIDPART; m++) {
                        a->tree[h][m] = sa_free_array(a->tree[h][m]);
                    }
                    a->tree[h] = sa_free_array(a->tree[h]);
                }
            }
  //        a->tree = sa_free_array(a->tree);
  //    }
        a->stack = sa_free_array(a->stack);
        a = sa_free_array(a);
    }
}

sa_tree sa_copy_tree(const sa_tree b)
{
    sa_tree a = (sa_tree) sa_malloc_array(sizeof(sa_tree_head), 1);
    a->sa_stack_step = b->sa_stack_step;
    a->sa_stack_size = b->sa_stack_size;
    a->bytes = b->bytes;
    a->identifier = b->identifier;
    a->dflt = b->dflt;
    a->stack = NULL;
    a->sa_stack_ptr = 0;
    sa_wipe_array(a->tree, sizeof(sa_tree_item *), LMT_SA_HIGHPART);
 // a->tree = NULL;
 // if (b->tree) {
 //     a->tree = (sa_tree_item ***) sa_calloc_array(sizeof(void *), LMT_SA_HIGHPART);
        for (int h = 0; h < LMT_SA_HIGHPART; h++) {
            if (b->tree[h]) {
                int slide = LMT_SA_LOWPART;
                switch (b->bytes) {
                    case 1: slide =   LMT_SA_LOWPART/4; break;
                    case 2: slide =   LMT_SA_LOWPART/2; break;
                    case 4: slide =   LMT_SA_LOWPART  ; break;
                    case 8: slide = 2*LMT_SA_LOWPART  ; break;
                }
                a->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(void *), LMT_SA_MIDPART);
                for (int m = 0; m < LMT_SA_MIDPART; m++) {
                    if (b->tree[h][m]) {
                        a->tree[h][m] = sa_malloc_array(sizeof(sa_tree_item), slide);
                        memcpy(a->tree[h][m], b->tree[h][m], sizeof(sa_tree_item) * slide);
                    }
                }
            }
        }
 // }
    return a;
}

/*tex

    The main reason to fill in the lowest entry branches here immediately is that most of the sparse
    arrays have a bias toward \ASCII\ values. Allocating those here immediately improves the chance
    of the structure |a->tree[0][0][x]| being close together in actual memory locations. We could
    save less for type 0 stacks.

*/

sa_tree sa_new_tree(int identifier, int size, int bytes, sa_tree_item dflt)
{
    sa_tree_head *a = (sa_tree_head *) lmt_memory_malloc(sizeof(sa_tree_head));
    a->dflt = dflt;
    a->stack = NULL;
 // a->tree = (sa_tree_item ***) sa_calloc_array(sizeof(sa_tree_item **), LMT_SA_HIGHPART);
    sa_wipe_array(a->tree, sizeof(sa_tree_item *), LMT_SA_HIGHPART);
    a->tree[0] = (sa_tree_item **) sa_calloc_array(sizeof(sa_tree_item *), LMT_SA_MIDPART);
    a->sa_stack_size = size;
    a->sa_stack_step = size;
    a->bytes = bytes;
    a->identifier = identifier;
    a->sa_stack_ptr = 0;
    return (sa_tree) a;
}

void sa_restore_stack(const sa_tree head, int gl)
{
    if (head->stack) {
        while (head->sa_stack_ptr > 0 && abs(head->stack[head->sa_stack_ptr].level) >= gl) {
            sa_stack_item st = head->stack[head->sa_stack_ptr];
            if (st.level > 0) {
                int code = st.code;
                switch (head->bytes) {
                    case 1:
                        {
                            int c = code % 4;
                            head->tree[LMT_SA_H_PART(code)][LMT_SA_M_PART(code)][LMT_SA_L_PART(code)/4].uchar_value[c] = st.value_1.uchar_value[c];
                        }
                        break;
                    case 2:
                        {
                            int c = code % 2;
                            head->tree[LMT_SA_H_PART(code)][LMT_SA_M_PART(code)][LMT_SA_L_PART(code)/2].ushort_value[c] = st.value_1.ushort_value[c];
                        }
                        break;
                    case 4:
                        {
                            head->tree[LMT_SA_H_PART(code)][LMT_SA_M_PART(code)][LMT_SA_L_PART(code)] = st.value_1;
                        }
                        break;
                    case 8:
                        {
                            int l = 2 * LMT_SA_L_PART(code);
                            head->tree[LMT_SA_H_PART(code)][LMT_SA_M_PART(code)][l] = st.value_1;
                            head->tree[LMT_SA_H_PART(code)][LMT_SA_M_PART(code)][l+1] = st.value_2;
                        }
                        break;

                }
            }
            (head->sa_stack_ptr)--;
        }
    }
}
void sa_reinit_stack(const sa_tree head, int level)
{
    if (head->stack) {
        /*tex Stack slot 0 is a dummy. */
        for(int i = head->sa_stack_ptr; i > 0 ; i--) {
            sa_stack_item st = head->stack[i];
            if (st.level > 0) {
             // printf("reinit %i: code %i, v1 %i, v2 %i, level %i\n",head->identifier,st.code,st.value_1.int_value,st.value_2.int_value,st.level);
                switch (head->bytes) {
                    case 1 : sa_set_item_1(head, st.code, st.value_1.uchar_value[st.code%4], level); break;
                    case 2 : sa_set_item_2(head, st.code, st.value_1.ushort_value[st.code%2], level); break;
                    case 4 : sa_set_item_4(head, st.code, st.value_1, level); break;
                }
            }
        }
    }
}

void sa_show_stack(const sa_tree head)
{
    if (head->stack) {
        /*tex Stack slot 0 is a dummy. */
     // tex_print_format("%l[codestack %i, size %i]\n", head->identifier, head->sa_stack_ptr - 1);
        tex_print_format("[codestack %i, size %i]\n", head->identifier, head->sa_stack_ptr - 1);
        for (int i = 1; i <= head->sa_stack_ptr; i++) {
            sa_stack_item st = head->stack[i];
            int value = 0;
            switch (head->bytes) {
                case 1 : value = st.value_1.uchar_value[st.code%4]; break;
                case 2 : value = st.value_1.ushort_value[st.code%2]; break;
                case 4 : value = st.value_1.int_value; break;
            }
            tex_print_format("%l[%i: level %i, code %i, value %i]\n",i, st.level,st.code,value);
        }
        tex_print_format("%l[codestack %i bottom]\n", head->identifier);
    }
}

void sa_dump_tree(dumpstream f, sa_tree a)
{
    unsigned char bytes = (unsigned char) a->bytes;
    dump_int(f, a->identifier);
    dump_int(f, a->sa_stack_step);
    dump_int(f, a->dflt.int_value);
 // if (a->tree) {
 //     int bytes = a->bytes;
        /*tex A marker: */
        dump_via_uchar(f, 1);
        dump_via_uchar(f, bytes);
        for (int h = 0; h < LMT_SA_HIGHPART; h++) {
            if (a->tree[h]) {
                for (int m = 0; m < LMT_SA_MIDPART; m++) {
                    if (a->tree[h][m]) {
                        /*tex
                            It happens a lot that the value is the same as the index, for instance
                            with case mappings.

                            Using mode 3 for the case where all values are the default value saves
                            In \CONTEXT\ some 128 * 5 dumps which is not worth the trouble but it
                            is neat anyway.

                            1 : values are kind of unique
                            2 : for all values : value == self
                            3 : for all values : value == default

                            Actually, we could decide not to save at all in the third mode because
                            unset equals default.
                        */
                        unsigned char mode = 1;
                        if (bytes != 8) {
                            /*tex Check for default values. */
                            int slide = bytes == 1 ? LMT_SA_LOWPART/4 : (bytes == 2 ? LMT_SA_LOWPART/2 : LMT_SA_LOWPART);
                            mode = 3;
                            for (int l = 0; l < slide; l++) {
                                if (a->tree[h][m][l].uint_value != a->dflt.uint_value) {
                                    mode = 1;
                                    break;
                                }
                            }
                        }
                        if (mode == 1 && bytes == 4) {
                            /*tex Check for identity values. */
                            unsigned int hm = h * LMT_SA_HIGHPART + m * LMT_SA_MIDPART * LMT_SA_LOWPART ;
                            mode = 2;
                            for (int l = 0; l < LMT_SA_LOWPART; l++) {
                                if (a->tree[h][m][l].uint_value == hm) {
                                    hm++;
                                } else {
                                    mode = 1;
                                    break;
                                }
                            }
                        }
                        dump_via_uchar(f, (unsigned char) h);
                        dump_via_uchar(f, (unsigned char) m);
                        dump_uchar(f, mode);
                        if (mode == 1) {
                            /*tex
                                We have unique values. By avoiding this branch we save some 85 Kb
                                on the \CONTEXT\ format. We could actually save this property in
                                the tree but there is not that much to gain.
                            */
                            int slide = LMT_SA_LOWPART;
                            switch (bytes) {
                                case 1: slide =   LMT_SA_LOWPART/4; break;
                                case 2: slide =   LMT_SA_LOWPART/2; break;
                                case 4: slide =   LMT_SA_LOWPART  ; break;
                                case 8: slide = 2*LMT_SA_LOWPART  ; break;
                            }
                            dump_items(f, &a->tree[h][m][0], sizeof(sa_tree_item), slide);
                        } else {
                            /*tex We have a self value or defaults. */
                        }
                    }
                }
            }
        }
 // }
    dump_via_uchar(f, 0xFF);
    dump_via_uchar(f, 0xFF);
    dump_via_uchar(f, 0xFF);
}

sa_tree sa_undump_tree(dumpstream f)
{
    unsigned char marker;
    sa_tree a = (sa_tree) sa_malloc_array(sizeof(sa_tree_head), 1);
    undump_int(f, a->identifier);
    undump_int(f, a->sa_stack_step);
    undump_int(f, a->dflt.int_value);
    a->sa_stack_size = a->sa_stack_step;
    a->stack = sa_calloc_array(sizeof(sa_stack_item), a->sa_stack_size);
    a->sa_stack_ptr = 0;
 // a->tree = NULL;
    sa_wipe_array(a->tree, sizeof(sa_tree_item **), LMT_SA_HIGHPART);
    /*tex The marker: */
    undump_uchar(f, marker);
    if (marker != 0) {
        unsigned char bytes;
  //    a->tree = (sa_tree_item ***) sa_calloc_array(sizeof(void *), LMT_SA_HIGHPART);
        undump_uchar(f, bytes);
        a->bytes = bytes;
        while (1) {
            unsigned char h = 0; 
            unsigned char m = 0; 
            unsigned char mode;
            undump_uchar(f, h);
            undump_uchar(f, m);
            undump_uchar(f, mode);
            if (mode == 0xFF) {
                if (h != 0xFF || m != 0xFF) {
                    printf("\nfatal format error, mode %i, bytes %i, high %i, middle %i\n", mode, bytes, h, m);
                    tex_fatal_undump_error("bad sa tree");
                }
                break;
            } else { 
                if (! a->tree[h]) {
                    a->tree[h] = (sa_tree_item **) sa_calloc_array(sizeof(void *), LMT_SA_MIDPART);
                }
                switch (mode) {
                    case 1:
                        /*tex
                            We have a unique values.
                        */
                        {
                            int slide = LMT_SA_LOWPART;
                            switch (bytes) {
                                case 1: slide =   LMT_SA_LOWPART/4; break;
                                case 2: slide =   LMT_SA_LOWPART/2; break;
                                case 4: slide =   LMT_SA_LOWPART  ; break;
                                case 8: slide = 2*LMT_SA_LOWPART  ; break;
                            }
                            if (! a->tree[h][m]) {
                                a->tree[h][m] = sa_calloc_array(sizeof(sa_tree_item), slide);
                            }
                            undump_items(f, &a->tree[h][m][0], sizeof(sa_tree_item), slide);
                        }
                        break;
                    case 2:
                        /*tex
                            We have a self value. We only have this when we have integers. Other
                            cases are math anyway, so not much to gain.
                        */
                        {
                            if (bytes == 4) {
                                int hm = h * 128 * LMT_SA_HIGHPART + m * LMT_SA_MIDPART;
                                if (! a->tree[h][m]) {
                                    a->tree[h][m] = sa_malloc_array(sizeof(sa_tree_item), LMT_SA_LOWPART);
                                }
                                for (int l = 0; l < LMT_SA_LOWPART; l++) {
                                    a->tree[h][m][l].int_value = hm;
                                    hm++;
                                }
                            } else {
                                printf("\nfatal format error, mode %i, bytes %i\n", mode, bytes);
                                tex_fatal_undump_error("bad sa tree");
                            }
                        }
                        break;
                    case 3:
                        /*tex
                            We have all default values. so no need to set them. In fact, we
                            cannot even end up here.
                        */
                        break;
                    default:
                        /*tex
                            We have no values set.
                        */
                        break;
                }
            }
        }
    }
    return a;
}
