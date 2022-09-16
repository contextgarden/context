/*
    This small C package is made of an independent set of routines dedicated to manipulating AVL
    trees (files avl.c, avl.h), and of an extension module for Python that builds upon it (file
    avlmodule.c). Unlike collectionsmodule.c, the latter file contains only Python bindings: it
    adds nothing to the underlying implementation.

    license: this package, pyavl, is donated to the public domain
    author : Richard McGraw
    Email  : dasnar@fastmail.fm
*/

/*
    This file is reformatted a little. As there has not been any changed in the original we assume
    this is okay. No changes means that the code is fine and we never ran into issues. Also, we
    always check for NULL here.

    The avl code is used for hashing strings. It is also used in the backend of luatex but in
    luametatex we don't have that, so its use is now only in mplib. Actually there are two modules
    used in luatex: one for metapost an done for tex, and they are somewhat different. So, I took
    the most extensive one.

    Todo: Rename some variables to avoid a compiler warning.
    Todo: Maybe abstract the error messages and make them a callback.
    Todo: Maybe some more if/else/local (likely branch prediction).
    Todo: Maybe turn some common code into functions (just for fun, will make the source smaller).
*/

# include "avl.h"

# ifdef AVL_SHOW_ERROR_ON
    # define AVL_SHOW_ERROR(fmt,arg) fprintf(stderr, "! avl.c: " fmt, arg)
# else
    # define AVL_SHOW_ERROR(fmt,arg) (void) (fmt), (void) (arg)
# endif

const void *avl_default_item_copy(const void *item)
{
    return (const void *) item;
}

void *avl_default_item_dispose(void *item)
{
    (void) item;
    return (void *) NULL;
}

/* integral type to encode rank and skew bits */

typedef uint32_t rbal_t;

/* avl_node structure */

typedef struct avl_node { /* aligned */
    struct avl_node *sub[2];
    struct avl_node *up;
    void            *item;
    rbal_t           rbal;
    int              padding;
} avl_node;

/*
 * avl_tree structure
 */

struct avl_tree_ { /* aligned */
    avl_node              *root;
    avl_size_t             count;    /* how many nodes in tree rooted at [root] */
    int                    padding;  /* alignment */
    avl_compare_func       compare;  /* compare items */
    avl_item_copy_func     copy;
    avl_item_dispose_func  dispose;
    avl_alloc_func         alloc;    /* to allocate memory (same signature as malloc) */
    avl_dealloc_func       dealloc;  /* to deallocate memory (same signature as free) */
    void *param;
};

# define item_compare(cmp, tree, item1, item2) (*cmp)(tree->param, item1, item2)

# define sub_left(a)  (a)->sub[0]
# define sub_right(a) (a)->sub[1]
# define get_item(a)  (a)->item

/* RANK(a) = size of left subtree + 1 */

# define rbal(a)         (a)->rbal
# define rzero(a)        (rbal(a) & ~3)
# define get_bal(a)      (rbal(a) & 3)
# define is_lskew(a)     (rbal(a) & 1)
# define is_rskew(a)     (rbal(a)>>1 & 1)
# define set_lskew(a)    (rbal(a) |= 1)
# define set_rskew(a)    (rbal(a) |= 2)
# define set_skew(a,d)   (rbal(a) |= (1 << d))
# define unset_lskew(a)  (rbal(a) &= ~1)
# define unset_rskew(a)  (rbal(a) &= ~2)
# define get_rank(a)     (rbal(a) >> 2)
# define set_rank(a,r)   (rbal(a) = (r<<2 | get_bal(a)))
# define incr_rank(a,r)  (rbal(a) += r<<2)
# define decr_rank(a,r)  (rbal(a) -= r<<2)

# define AVL_MIN_DEPTH   0

/* helper structure */

typedef enum {
    OP_BACKUP,
    OP_DETACH,
    OP_FREE
} whichop_t;

typedef struct ptr_handler { /* swapped and aligned */
    void      *ptr;
    whichop_t  whichop;
    int        padding;
} ptr_handler;

static void clear_node(avl_node *a)
{
    sub_left(a) = NULL;
    sub_right(a) = NULL;
    (a)->up = NULL;
    rbal(a) = 4u;
}

/* Called by 'avl_ins', 'avl_dup', 'node_slice' */

static avl_node *new_node(void *item, avl_node *up, avl_tree t)
{
    avl_node *a = (*t->alloc)(sizeof(avl_node));
    if (a) {
        sub_left(a) = NULL;
        sub_right(a) = NULL;
        a->up = up;
        a->rbal = 4u;
        a->item = (*t->copy)(item);
    } else {
        AVL_SHOW_ERROR("%s\n", "couldn't allocate node");
    }
    return a;
}

static void free_node(avl_node *a, avl_tree t)
{
    a->item = (*t->dispose)(a->item);
    (*t->dealloc)(a);
}

/* function to detach node [a] from tree [t]  (compiler will inline if needed) */

static void detach_node(avl_node *a, avl_tree t, struct ptr_handler *h)
{
    clear_node(a);
    do {
        if (! h) {
            /* nothing */
        } else if (h->whichop == OP_DETACH) {
            h->ptr = a;
            break;
        } else if (h->whichop == OP_BACKUP) {
            h->ptr = (*t->copy)(a->item);
        }
        free_node(a, t);
    } while (0);
    t->count--;
}

/* Tree methods */

avl_tree avl_create (
    avl_compare_func       compare,
    avl_item_copy_func     copy,
    avl_item_dispose_func  dispose,
    avl_alloc_func         alloc,
    avl_dealloc_func       dealloc,
    void                  *param
)
{
    avl_tree t = (*alloc)(sizeof(struct avl_tree_));
    if (t) {
        t->root = NULL;
        t->count = 0;
        t->param = param;
        t->compare = compare;
        t->copy = copy;
        t->dispose = dispose;
        t->alloc = alloc;
        t->dealloc = dealloc;
    } else {
        AVL_SHOW_ERROR("%s\n", "couldn't create new handle in avl_create()");
    }
    return t;
}

/* Empty the tree, using rotations */

static void node_empty(avl_tree t)
{
    avl_node *a, *p;
    for (a = t->root; a != NULL;) {
        p = a;
        if (! sub_right(a)) {
            a = sub_left(a);
        } else {
            while (sub_left(a)) {
                /* rotR(a) */
                a = sub_left(a);
                sub_left(p) = sub_right(a);
                sub_right(a) = p;
                p = a;
            }
            a = sub_right(p);
        }
        free_node(p, t);
        t->count--;
    }
    t->root = NULL;
}

/* [t] is an existing tree handle; this function invokes node_empty() */

void avl_reset (
    avl_tree              t,
    avl_compare_func      compare,
    avl_item_copy_func    copy,
    avl_item_dispose_func dispose,
    avl_alloc_func        alloc,
    avl_dealloc_func      dealloc
)
{
    if (t) {
        node_empty(t);
        t->compare = compare;
        t->copy = copy;
        t->dispose = dispose;
        t->alloc = alloc;
        t->dealloc = dealloc;
    }
}

void avl_empty(avl_tree t)
{
    if (t) {
        node_empty(t);
    }
}

/* Destroy nodes, free handle */

void avl_destroy(avl_tree t)
{
    if (t) {
        node_empty(t);
        (*t->dealloc)(t);
    }
}

avl_tree avl_dup(avl_tree t, void *param)
{
    if (t) {
        avl_tree tt = avl_create(t->compare, t->copy, t->dispose, t->alloc, t->dealloc, param);
        if (tt) {
            tt->count = t->count;
            if (t->root == NULL) {
                return tt;
            } else {
                avl_node *a, *c, *s;
                a = t->root;
                tt->root = c = new_node(get_item(a), NULL, t);
                if (c) {
                    sub_right(c) = NULL;
                    rbal(c) = rbal(a);
                    while (1) {
                        while (sub_left(a) != NULL) {
                            a = sub_left(a);
                            sub_left(c) = s = new_node(get_item(a), NULL, t);
                            if (s) {
                                s->up = c;
                                sub_right(s) = c;
                                c = s;
                                rbal(c) = rbal(a);
                            } else {
                                goto recover;
                            }
                        }
                        sub_left(c) = NULL;
                        while (sub_right(a) == NULL) {
                            s = sub_right(c);
                            sub_right(c) = NULL;
                            c = s;
                            /* Find successor of [a] in original tree */
                            do  {
                                s = a;
                                a = s->up;
                                if (a == NULL) {
                                    return tt;
                                }
                            }
                            while (s != sub_left(a));
                        }
                        a = sub_right(a);
                        s = new_node(get_item(a), NULL, t);
                        if (s) {
                            sub_right(s) = sub_right(c);
                            sub_right(c) = s;
                            s->up = c;
                            c = s;
                            rbal(c) = rbal(a);
                        } else {
                            goto recover;
                        }
                    }
                    /* recovery code     */
                  recover:
                    while (1) {
                        s = sub_right(c);
                        sub_right(c) = NULL;
                        if (s) {
                            c = s;
                        } else {
                            break;
                        }
                    }
                    node_empty(tt);
                  abort:
                    (*t->dealloc)(tt);
                    AVL_SHOW_ERROR("%s\n", "couldn't allocate node in avl_dup()");
                    return NULL;
                } else {
                    goto abort;
                }
            }
        } else {
            AVL_SHOW_ERROR("%s\n", "couldn't create new handle in avl_dup()");
       }
    }
    return NULL;
}

avl_bool_t avl_isempty(avl_tree t)
{
     return t == NULL || t->root == NULL;
}

avl_size_t avl_size(avl_tree t)
{
    return t == NULL ? 0 : t->count;
}

static int depth(avl_node *a)
{
    int h = AVL_MIN_DEPTH;
    for (; a != NULL; ++h) {
        a = a->sub[is_rskew(a)];
    }
    return h;
}

static avl_node *node_first(avl_node *a)
{
    while (sub_left(a)) {
        a = sub_left(a);
    }
    return a;
}

static avl_node *node_last(avl_node *a)
{
    while (sub_right(a)) {
        a = sub_right(a);
    }
    return a;
}

/* [a] : non-null */

static avl_node *node_next(avl_node *a)
{
    if (sub_right(a)) {
        return node_first (sub_right(a));
    } else {
        avl_node *p;
        do {
            p = a;
            a = p->up;
        } while (a && sub_right(a) == p);
        return a;
    }
}

/* [a] : non-null */

static avl_node *node_prev(avl_node *a)
{
    if (sub_left(a)) {
        return node_last (sub_left(a));
    } else {
        avl_node *p;
        do {
            p = a;
            a = p->up;
        } while (a && sub_left(a) == p);
        return a;
    }
}

static avl_node *node_find(const void *item, avl_tree t)
{
    avl_node *a = t->root;
    avl_compare_func cmp = t->compare;
    while (a) {
        int c = item_compare(cmp, t, item, get_item(a));
        if (c < 0) {
            a = sub_left(a);
        } else if (c) {
            a = sub_right(a);
        } else {
            break;
        }
    }
    return a;
}

static avl_size_t get_index(avl_node *a)
{
    avl_size_t n = get_rank(a);
    avl_node *p;
    while ((p = a->up)) {
        if (a != sub_left(p)) {
            n += get_rank(p);
        }
        a = p;
    }
    return n;
}

/* Find item by index */

static avl_node *node_find_index(avl_size_t idx, avl_tree t)
{
    avl_node *a = t->root;
    if (idx == 0 || idx > t->count) {
        return NULL;
    } else if (idx == 1) {
        return node_first(a);
    } else if (idx == t->count) {
        return node_last(a);
    } else {
        int c;
        while ((c = (int) (idx - get_rank(a))) != 0) {
            if (c < 0) {
                a = sub_left(a);
            } else {
                idx = (avl_size_t) c;
                a = sub_right(a);
            }
        }
        return a;
    }
}

/* Rebalance starting from node [a] where a->sub[d_] is deeper post-insertion */

static avl_code_t rebalance_ins(avl_node *a, int dir, avl_tree t)
{
    if (a) {
        avl_node *p;
        while (1) {
            incr_rank(a, (rbal_t) (!dir));
            if (get_bal(a)) {
                break;
            } else {
                set_skew(a, dir);
                p = a->up;
                if (p) {
                    dir = a != sub_left(p);
                    a = p;
                } else {
                    return 2;
                }
            }
        }
        /* Now bal(a) == -1 or +1 */
        /* Rotate if need be */
        if (dir == 0) {
            if (is_rskew(a))
                unset_rskew(a);
            else {
                avl_node *u = a->up;
                avl_node **r = u ? &u->sub[a != sub_left(u)] : &t->root;
                p = a;
                if (is_lskew(sub_left(p))) {
                    /* rotR(p) */
                    a = sub_left(p);
                    sub_left(p) = sub_right(a);
                    if (sub_right(a)) {
                        sub_right(a)->up = p;
                    }
                    sub_right(a) = p;
                    unset_lskew(p);
                    rbal(p) -= rzero(a);
                } else {
                    /* rotLR(p) */
                    a = sub_right(sub_left(p));
                    sub_right(sub_left(p)) = sub_left(a);
                    if (sub_left(a)) {
                        sub_left(a)->up = sub_left(p);
                    }
                    sub_left(p)->up = a;
                    sub_left(a) = sub_left(p);
                    sub_left(p) = sub_right(a);
                    if (sub_right(a)) {
                        sub_right(a)->up = p;
                    }
                    sub_right(a) = p;
                    switch (get_bal(a)) {
                        case 0: /* not skewed */
                            unset_lskew(p);
                            unset_rskew(sub_left(a));
                            break;
                        case 1: /* left skew */
                            unset_lskew(p);
                            set_rskew(p);
                            unset_rskew(sub_left(a));
                            break;
                        case 2: /* right skew */
                            unset_lskew(p);
                            unset_rskew(sub_left(a));
                            set_lskew(sub_left(a));
                            break;
                    }
                    rbal(a) += rzero(sub_left(a));
                    rbal(p) -= rzero(a);
                }
                rbal(a) &= ~3;
                a->up = u;
                p->up = a;
                *r = a;
            }
        } else if (is_lskew(a)) {
            unset_lskew(a);
        } else {
            avl_node *u = a->up;
            avl_node **r = u != NULL ? &u->sub[a != sub_left(u)] : &t->root;
            p = a;
            if (is_rskew(sub_right(p))) {
                /* rotL(p) */
                a = sub_right(p);
                sub_right(p) = sub_left(a);
                if (sub_left(a)) {
                    sub_left(a)->up = p;
                }
                sub_left(a) = p;
                unset_rskew(p);
                rbal(a) += rzero(p);
            } else {
                /* rotRL(p) */
                a = sub_left(sub_right(p));
                sub_left(sub_right(p)) = sub_right(a);
                if (sub_right(a)) {
                    sub_right(a)->up = sub_right(p);
                }
                sub_right(p)->up = a;
                sub_right(a) = sub_right(p);
                sub_right(p) = sub_left(a);
                if (sub_left(a)) {
                    sub_left(a)->up = p;
                }
                sub_left(a) = p;
                switch (get_bal(a)) {
                    case 0:	/* not skewed */
                        unset_rskew(p);
                        unset_lskew(sub_right(a));
                        break;
                    case 1:	/* left skew */
                        unset_rskew(p);
                        unset_lskew(sub_right(a));
                        set_rskew(sub_right(a));
                        break;
                    case 2:	/* right skew */
                        unset_rskew(p);
                        set_lskew(p);
                        unset_lskew(sub_right(a));
                        break;
                }
                rbal(sub_right(a)) -= rzero(a);
                rbal(a) += rzero(p);
            }
            rbal(a) &= ~3;
            a->up = u;
            p->up = a;
            *r = a;
        }
        /* The tree rooted at 'a' is now valid */
        /* Finish adjusting ranks */
        while ((p = a->up)) {
            incr_rank(p, (rbal_t)(a == sub_left(p)));
            a = p;
        }
        return 1;
    }
    return 2;
}

/* detach [p] : non-null; only the linkage is tweaked */

static avl_code_t rebalance_del(avl_node *p, avl_tree t, void **backup)
{
    rbal_t bal;
    int dir = 0;
    avl_node *a = p->up;
    avl_node **r = a ? &a->sub[dir = p != sub_left(a)] : &t->root;
    avl_node *c = sub_right(p);
    if (! c && ! sub_left(p)) {
        *r = NULL;
    } else if (! c || ! sub_left(p)) {
        *r = c ? c : sub_left(p);
        (*r)->up = a;
    } else {
        if (sub_left(c)) {
            do {
                c = sub_left(c);
            } while (sub_left(c));
            a = c->up;
            dir = 0;
            sub_left(a) = sub_right(c);
            if (sub_right(c)) {
                sub_right(c)->up = a;
            }
            sub_right(c) = sub_right(p);
            sub_right(c)->up = c;
        } else {
            a = c;
            dir = 1;
        }
        sub_left(c) = sub_left(p);
        sub_left(c)->up = c;
        c->up = p->up;
        rbal(c) = rbal(p);
        *r = c;
    }
    if (backup) {
        *backup = (*t->copy)(p->item);
    }
    detach_node(p, t, NULL);
    /* Start backtracking : subtree of [a] in direction [dir] is less deep */
    for (;; a = (*r)->up) {
        if (a == NULL) {
            return 2;
        } else {
            decr_rank(a, (rbal_t)(!dir));
            bal = get_bal(a);
            if (dir == 0) {
                if (bal == 0) {
                    set_rskew(a);
                    break;
                }
                if (a->up) {
                    dir = a != sub_left(a->up);
                    r = &a->up->sub[dir];
                } else {
                    r = &t->root;
                }
                if (bal & 1) {
                    unset_lskew(a);
                }
                if (get_bal(a)) {
                    p = a;
                    bal = get_bal(sub_right(p));
                    if (! (bal & 1)) {
                        /* bal = 0 or +1 */
                        /* rotL(p) */
                        a = sub_right(p);
                        sub_right(p) = sub_left(a);
                        if (sub_left(a)) {
                            sub_left(a)->up = p;
                        }
                        sub_left(a) = p;
                        if (bal) {
                            unset_rskew(p);
                            unset_rskew(a);
                        } else {
                            set_lskew(a);
                        }
                        rbal(a) += rzero(p);
                    } else {
                        /* rotRL(p) */
                        a = sub_left(sub_right(p));
                        sub_left(sub_right(p)) = sub_right(a);
                        if (sub_right(a)) {
                            sub_right(a)->up = sub_right(p);
                        }
                        sub_right(p)->up = a;
                        sub_right(a) = sub_right(p);
                        sub_right(p) = sub_left(a);
                        if (sub_left(a)) {
                            sub_left(a)->up = p;
                        }
                        sub_left(a) = p;
                        switch (get_bal(a)) {
                            case 0: /* not skewed */
                                unset_rskew(p);
                                unset_lskew(sub_right(a));
                                break;
                            case 1: /* left skew */
                                unset_rskew(p);
                                unset_lskew(sub_right(a));
                                set_rskew(sub_right(a));
                                break;
                            case 2: /* right skew */
                                unset_rskew(p);
                                set_lskew(p);
                                unset_lskew(sub_right(a));
                                break;
                        }
                        rbal(a) &= ~3;
                        rbal(sub_right(a)) -= rzero(a);
                        rbal(a) += rzero(p);
                    }
                    a->up = p->up;
                    p->up = a;
                    /* Done with rotation */
                    *r = a;
                    if (bal == 0) {
                        break;
                    }
                }
            } else {
                /* dir == 1 */
                if (bal == 0) {
                    set_lskew(a);
                    break;
                }
                if (a->up == NULL) {
                    r = &t->root;
                } else {
                    dir = a != sub_left(a->up);
                    r = &a->up->sub[dir];
                }
                if (bal & 2) {
                    unset_rskew(a);
                }
                if (get_bal(a)) {
                    p = a;
                    bal = get_bal(sub_left(p));
                    if (! (bal & 2)) {
                        /* bal = 0 or -1 */
                        /* rotR(p) */
                        a = sub_left(p);
                        sub_left(p) = sub_right(a);
                        if (sub_right(a)) {
                            sub_right(a)->up = p;
                        }
                        sub_right(a) = p;
                        if (bal) {
                            unset_lskew(p);
                            unset_lskew(a);
                        } else {
                            set_rskew(a);
                        }
                        rbal(p) -= rzero(a);
                    } else {
                        /* rotLR(p) */
                        a = sub_right(sub_left(p));
                        sub_right(sub_left(p)) = sub_left(a);
                        if (sub_left(a)) {
                            sub_left(a)->up = sub_left(p);
                        }
                        sub_left(p)->up = a;
                        sub_left(a) = sub_left(p);
                        sub_left(p) = sub_right(a);
                        if (sub_right(a) != NULL) {
                            sub_right(a)->up = p;
                        }
                        sub_right(a) = p;
                        switch (get_bal(a)) {
                            case 0: /* not skewed */
                                unset_lskew(p);
                                unset_rskew(sub_left(a));
                                break;
                            case 1: /* left skew */
                                unset_lskew(p);
                                set_rskew(p);
                                unset_rskew(sub_left(a));
                                break;
                            case 2: /* right skew */
                                unset_lskew(p);
                                unset_rskew(sub_left(a));
                                set_lskew(sub_left(a));
                                break;
                        }
                        rbal(a) &= ~3;
                        rbal(a) += rzero(sub_left(a));
                        rbal(p) -= rzero(a);
                    }
                    a->up = p->up;
                    p->up = a;
                    /* Done with rotation */
                    *r = a;
                    if (bal == 0) {
                        break;
                    }
                }
            }
        }
    }
    /* Finish adjusting ranks */
    while ((p = a->up)) {
        decr_rank(p, (rbal_t)(a == sub_left(p)));
        a = p;
    }
    return 1;
}

void *avl_first(avl_tree t)
{
    if (t && t->root) {
        return get_item(node_first(t->root));
    } else {
        return NULL;
    }
}

void *avl_last(avl_tree t)
{
    if (t && t->root) {
        return get_item(node_last(t->root));
    } else {
        return NULL;
    }
}

void *avl_find(const void *item, avl_tree t)
{
    if (t) {
        avl_node *a = node_find(item, t);
        return a ? get_item(a) : NULL;
    } else {
        return NULL;
    }
}

/*
    Return smallest index i in [1:len] s.t. tree[i] matches [item], or zero if
    not found
*/

avl_size_t avl_index(const void *item, avl_tree t)
{
    if (item && t && t->root) {
        avl_compare_func cmp = t->compare;
        avl_node *a, *p;
        avl_size_t idx = 0, n = 0;
        for (a = t->root;;) {
            int c = item_compare(cmp, t, item, get_item(a));
            if (! c) {
                idx = n + get_rank(a);
            } else if (c > 0) {
                n += get_rank(a);
            }
            p = a->sub[c > 0];
            if (p) {
                a = p;
            } else {
                return idx;
            }
        }
    } else {
        return 0;
    }
}

/*
    (lo,hi) where lo smallest index s.t. t[lo] >= lo_item, or t->count+1 and hi
    greatest index s.t. t[hi] <= hi_item, or 0
*/

avl_code_t avl_span(const void *lo_item, const void *hi_item, avl_tree t, avl_size_t *lo_idx, avl_size_t *hi_idx)
{
    if (t) {
        *lo_idx = t->count + 1;
        *hi_idx = 0;
        if (t->root) {
            avl_compare_func cmp = t->compare;
            avl_node *a;
            avl_size_t n = 0;
            int c = item_compare(cmp, t, lo_item, hi_item) > 0;
            if (c > 0) {
                const void *temp = lo_item;
                lo_item = hi_item;
                hi_item = temp;
            }
            a = t->root;
            do {
                c = item_compare(cmp, t, lo_item, get_item(a));
                if (c > 0) {
                    n += get_rank(a);
                    a = sub_right(a);
                } else {
                    *lo_idx = n + get_rank(a);
                    a = sub_left(a);
                }
            } while (a);
            a = t->root;
            do {
                c = item_compare(cmp, t, hi_item, get_item(a));
                if (c < 0) {
                    a = sub_left(a);
                } else {
                    *hi_idx += get_rank(a);
                    a = sub_right(a);
                }
            } while (a);
            return 0;
        }
    }
    return -1;
}

/* Find the smallest item in tree [t] that is GEQ the passed item */

void *avl_find_atleast(const void *item, avl_tree t)
{
    if (t && t->root) {
        avl_compare_func cmp = t->compare;
        avl_node *a = t->root;
        void *p = NULL;
        do {
            int c = item_compare(cmp, t, item, get_item(a));
            if (c > 0) {
                a = sub_right(a);
            } else {
                p = get_item(a);
                a = sub_left(a);
            }
        } while (a);
        return p;
    } else {
        return NULL;
    }
}

/* Find the greatest item in tree [t] that is LEQ the passed item */

void *avl_find_atmost(const void *item, avl_tree t)
{
    if (t && t->root) {
        avl_compare_func cmp = t->compare;
        avl_node *a = t->root;
        void *p = NULL;
        do {
            int c = item_compare(cmp, t, item, get_item(a));
            if (c < 0) {
                a = sub_left(a);
            } else {
                p = get_item(a);
                a = sub_right(a);
            }
        } while (a);
        return p;
    } else {
        return NULL;
    }
}

/* Retrieve item of index [idx] in tree [t] */

void *avl_find_index(avl_size_t idx, avl_tree t)
{
    if (t) {
        avl_node *a = node_find_index(idx, t);
        return a ? get_item(a) : NULL;
    } else {
        return NULL;
    }
}

/* Iterative insertion */

avl_code_t avl_ins (void *item, avl_tree t, avl_bool_t allow_duplicates)
{
    if (t) {
        avl_compare_func cmp = t->compare;
        avl_node **r, *a;
        int dir = 0;
        for (r = &t->root, a = NULL; *r != NULL; r = &a->sub[dir = dir > 0]) {
            a = *r;
            dir = item_compare(cmp, t, item, get_item(a));
            if (!dir && !allow_duplicates)
                return 0;
        }
        *r = new_node(item, a, t);
        if (*r) {
            t->count++;
            return rebalance_ins(a, dir, t);
        } else {
            return -1;
        }
    } else {
        return 0;
    }
}

avl_code_t avl_del(void *item, avl_tree t, void **backup)
{
    if (t && t->root) {
        avl_node *a = node_find(item, t);
        if (a) {
            return rebalance_del(a, t, backup);
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

/* helper function */

static avl_code_t node_del_first(avl_tree t, struct ptr_handler *h)
{
    avl_node *c;
    avl_node *p = node_first (t->root);
    avl_node *a = p->up;
    if (sub_right(p)) {
        sub_right(p)->up = a;
    }
    if (a == NULL) {
        t->root = sub_right(p);
    } else {
        sub_left(a) = sub_right(p);
    }
    detach_node (p, t, h);
    /* Start backtracking : subtree of [a] in direction [0] is less deep */
    for (;; a = c) {
        if (a) {
            rbal_t bal;
            decr_rank(a, 1);
            bal = get_bal(a);
            if (bal == 0) {
                set_rskew(a);
                break;
            } else {
                if (bal & 1) {
                    unset_lskew(a);
                }
                c = a->up;
                if (get_bal(a)) {
                    p = a;
                    bal = get_bal(sub_right(p));
                    if (! (bal & 1)) {
                        /* bal = 0 or +1 */
                        /* rotL(p) */
                        a = sub_right(p);
                        sub_right(p) = sub_left(a);
                        if (sub_left(a)) {
                            sub_left(a)->up = p;
                        }
                        sub_left(a) = p;
                        if (bal) {
                            unset_rskew(p);
                            unset_rskew(a);
                        } else {
                            set_lskew(a);
                        }
                        rbal(a) += rzero(p);
                    } else {
                        /* rotRL(p) */
                        a = sub_left(sub_right(p));
                        sub_left(sub_right(p)) = sub_right(a);
                        if (sub_right(a)) {
                            sub_right(a)->up = sub_right(p);
                        }
                        sub_right(p)->up = a;
                        sub_right(a) = sub_right(p);
                        sub_right(p) = sub_left(a);
                        if (sub_left(a)) {
                            sub_left(a)->up = p;
                        }
                        sub_left(a) = p;
                        switch (get_bal(a)) {
                            case 0: /* not skewed */
                                unset_rskew(p);
                                unset_lskew(sub_right(a));
                                break;
                            case 1: /* left skew */
                                unset_rskew(p);
                                unset_lskew(sub_right(a));
                                set_rskew(sub_right(a));
                                break;
                            case 2: /* right skew */
                                unset_rskew(p);
                                set_lskew(p);
                                unset_lskew(sub_right(a));
                                break;
                        }
                        rbal(a) &= ~3;
                        rbal(sub_right(a)) -= rzero(a);
                        rbal(a) += rzero(p);
                    }
                    a->up = p->up;
                    p->up = a;
                    /* Done with rotation */
                    if (c) {
                        sub_left(c) = a;
                    } else {
                        t->root = a;
                    }
                    if (bal == 0) {
                        break;
                    }
                }
            }
        } else {
            return 2;
        }
    }
    /* Finish adjusting ranks */
    while ((a = a->up)) {
        decr_rank(a, 1);
    }
    return 1;
}

/* helper function */

static avl_code_t node_del_last(avl_tree t, struct ptr_handler *h)
{

    avl_node *c;
    avl_node *p = node_last (t->root);
    avl_node *a = p->up;
    if (sub_left(p)) {
        sub_left(p)->up = a;
    }
    if (a) {
        sub_right(a) = sub_left(p);
    } else {
        t->root = sub_left(p);
    }
    detach_node(p, t, h);
    /* Start backtracking : subtree of [a] in direction [1] is less deep */
    for (;; a = c) {
        if (a) {
            rbal_t bal = get_bal(a);
            if (bal == 0) {
                set_lskew(a);
                break;
            } else {
                if (bal & 2) {
                    unset_rskew(a);
                }
                c = a->up;
                if (get_bal(a)) {
                    p = a;
                    bal = get_bal(sub_left(p));
                    if (! (bal & 2)) {
                        /* bal = 0 or -1 */
                        /* rotR(p) */
                        a = sub_left(p);
                        sub_left(p) = sub_right(a);
                        if (sub_right(a)) {
                            sub_right(a)->up = p;
                        }
                        sub_right(a) = p;
                        if (bal) {
                            unset_lskew(p);
                            unset_lskew(a);
                        } else {
                            set_rskew(a);
                        }
                        rbal(p) -= rzero(a);
                    } else {
                        /* rotLR(p) */
                        a = sub_right(sub_left(p));
                        sub_right(sub_left(p)) = sub_left(a);
                        if (sub_left(a) != NULL)
                        sub_left(a)->up = sub_left(p);
                        sub_left(p)->up = a;
                        sub_left(a) = sub_left(p);
                        sub_left(p) = sub_right(a);
                        if (sub_right(a)) {
                            sub_right(a)->up = p;
                        }
                        sub_right(a) = p;
                        switch (get_bal(a)) {
                            case 0: /* not skewed */
                                unset_lskew(p);
                                unset_rskew(sub_left(a));
                                break;
                            case 1: /* left skew */
                                unset_lskew(p);
                                set_rskew(p);
                                unset_rskew(sub_left(a));
                                break;
                            case 2: /* right skew */
                                unset_lskew(p);
                                unset_rskew(sub_left(a));
                                set_lskew(sub_left(a));
                                break;
                        }
                        rbal(a) &= ~3;
                        rbal(a) += rzero(sub_left(a));
                        rbal(p) -= rzero(a);
                    }
                    a->up = p->up;
                    p->up = a;
                    /* Done with rotation */
                    if (c) {
                        sub_right(c) = a;
                    } else {
                        t->root = a;
                    }
                    if (bal == 0) {
                        break;
                    }
                }
            }
        } else {
            return 2;
        }
    }
    return 1;
}

/*
    [p] : juncture node(zeroed out)
    [n] : rank of [p] in resulting tree
    [delta] = depth_1 - depth_0
*/

static avl_code_t join_left(avl_node *p, avl_node **r0, avl_node *r1, int delta, int n)
{
    avl_node *a = NULL;
    avl_node **r = r0;
    if (r1) {
        while (delta < -1) {
            a = *r;
            delta += (int) (is_lskew(a) + 1);
            n -= (int) get_rank(a);
            r = &sub_right(a);
        }
        r1->up = p;
        if (*r) {
            (*r)->up = p;
        }
        if (delta) {
            set_lskew(p);
        }
    } else {
        while (*r != NULL) {
            a = *r;
            n -= (int) get_rank(a);
            r = &sub_right(a);
        }
    }
    /* at this point bal(*r) = -1 or 0 */
    sub_left(p) = *r;
    sub_right(p) = r1;
    p->up = a;
    set_rank(p, n);
    *r = p;
    for (;;) {
        if (! a) {
            return 2;
        } else if (get_bal(a)) {
            break;
        } else {
            set_rskew(a);
            a = a->up;
        }
    }
    /* Rotate if need be */
    /* No (+2,0) rotation to do */
    if (is_lskew(a)) {
        unset_lskew(a);
    } else {
        p = a;
        if (is_rskew(sub_right(p))) {
            /* rotL(p) */
            a = sub_right(p);
            sub_right(p) = sub_left(a);
            if (sub_left(a)) {
                sub_left(a)->up = p;
            }
            sub_left(a) = p;
            unset_rskew(p);
            rbal(a) += rzero(p);
        } else {
            /* rotRL(p) */
            a = sub_left(sub_right(p));
            sub_left(sub_right(p)) = sub_right(a);
            if (sub_right(a)) {
                sub_right(a)->up = sub_right(p);
            }
            sub_right(p)->up = a;
            sub_right(a) = sub_right(p);
            sub_right(p) = sub_left(a);
            if (sub_left(a)) {
                sub_left(a)->up = p;
            }
            sub_left(a) = p;
            switch (get_bal(a)) {
                case 0: /* not skewed */
                    unset_rskew(p);
                    unset_lskew(sub_right(a));
                    break;
                case 1: /* left skew */
                    unset_rskew(p);
                    unset_lskew(sub_right(a));
                    set_rskew(sub_right(a));
                    break;
                case 2: /* right skew */
                    unset_rskew(p);
                    set_lskew(p);
                    unset_lskew(sub_right(a));
                    break;
            }
            rbal(sub_right(a)) -= rzero(a);
            rbal(a) += rzero(p);
        }
        rbal(a) &= ~3;
        a->up = p->up;
        p->up = a;
        if (a->up) {
            sub_right(a->up) = a;
        } else {
            *r0 = a;
        }
    }
    return 1;
}

/*
    [p] : juncture node
    [n] : rank of [p] in resulting tree
*/

static avl_code_t join_right(avl_node *p, avl_node *r0, avl_node **r1, int delta, int n)
{
    avl_node *a = NULL;
    avl_node **r = r1;
    if (r0) {
        while (delta > +1) {
            a = *r;
            delta -= (int) (is_rskew(a) + 1);
            incr_rank(a, (rbal_t)n);
            r = &sub_left(a);
        }
        r0->up = p;
        if (*r != NULL) {
            (*r)->up = p;
        }
        if (delta) {
            set_rskew(p);
        }
    } else {
        while (*r) {
            a = *r;
            incr_rank(a, (rbal_t) n);
            r = &sub_left(a);
        }
        n = 1;
    }
    /* at this point bal(*r) = +1 or 0 */
    sub_left(p) = r0;
    sub_right(p) = *r;
    set_rank(p, n);
    p->up = a;
    *r = p;
    for (;;) {
        if (! a) {
            return 2;
        } else if (get_bal(a)) {
            break;
        } else {
            set_lskew(a);
            a = a->up;
        }
    }
    /* Rotate if need be */
    /* No (-2,0) rotation to do */
    if (is_rskew(a)) {
        unset_rskew(a);
    } else {
        p = a;
        if (is_lskew(sub_left(p))) {
            /* rotR(p) */
            a = sub_left(p);
            sub_left(p) = sub_right(a);
            if (sub_right(a)) {
                sub_right(a)->up = p;
            }
            sub_right(a) = p;
            unset_lskew(p);
            rbal(p) -= rzero(a);
        } else {
            /* rotLR(p) */
            a = sub_right(sub_left(p));
            sub_right(sub_left(p)) = sub_left(a);
            if (sub_left(a)) {
                sub_left(a)->up = sub_left(p);
            }
            sub_left(p)->up = a;
            sub_left(a) = sub_left(p);
            sub_left(p) = sub_right(a);
            if (sub_right(a)) {
                sub_right(a)->up = p;
            }
            sub_right(a) = p;
            switch (get_bal(a)) {
                case 0: /* not skewed */
                    unset_lskew(p);
                    unset_rskew(sub_left(a));
                    break;
                case 1: /* left skew */
                    unset_lskew(p);
                    set_rskew(p);
                    unset_rskew(sub_left(a));
                    break;
                case 2: /* right skew */
                    unset_lskew(p);
                    unset_rskew(sub_left(a));
                    set_lskew(sub_left(a));
                    break;
            }
            rbal(a) += rzero(sub_left(a));
            rbal(p) -= rzero(a);
        }
        rbal(a) &= ~3;
        a->up = p->up;
        p->up = a;
        if (a->up != NULL) {
            sub_left(a->up) = a;
        } else {
            *r1 = a;
        }
    }
    return 1;
}

avl_code_t avl_del_first(avl_tree t, void **backup)
{
    if (t && t->root) {
        avl_code_t rv;
        if (backup) {
            ptr_handler h = { NULL, OP_BACKUP };
            rv = node_del_first(t, &h);
            *backup = h.ptr;
        } else {
            rv = node_del_first(t, NULL);
        }
        return rv;
    } else {
        return 0;
    }
}

avl_code_t avl_del_last(avl_tree t, void **backup)
{
    if (t && t->root) {
        if (backup == NULL) {
            return node_del_last(t, NULL);
        } else {
            ptr_handler h = { NULL, OP_BACKUP };
            avl_code_t rv = node_del_last(t, &h);
            *backup = h.ptr;
            return rv;
        }
    } else {
        return 0;
    }
}

avl_code_t avl_ins_index(void *item, avl_size_t idx, avl_tree t)
{
    if (idx == 0 || t == NULL || idx > t->count + 1) {
        return 0;
    } else {
        avl_node *p = new_node(item, NULL, t);
        if (p) {
            t->count++;
            /* Note: 'attach_node' macro increments t->count */
            if (idx == 1) {
                return join_right(p, (avl_node *) NULL, &t->root, /*delta= */ 0, 1);
            } else if (idx == t->count) {
                return join_left(p, &t->root, (avl_node *) NULL, /*delta= */ 0, (int) t->count);
            } else {
                avl_node *a = node_find_index(idx - 1, t);
                int dir;
                if (sub_right(a)) {
                    a = node_first(sub_right(a));
                    sub_left(a) = p;
                    dir = 0;
                } else {
                    sub_right(a) = p;
                    dir = 1;
                }
                p->up = a;
                return rebalance_ins(a, dir, t);
            }
        } else {
            return -1;
        }
    }
}

avl_code_t avl_del_index(avl_size_t idx, avl_tree t, void **backup)
{
    if (! t) {
        return 0;
    } else if (idx == 0 || idx > t->count) {
        return 0;
    } else if (idx == 1) {
        return avl_del_first(t, backup);
    } else if (idx == t->count) {
        return avl_del_last(t, backup);
    } else {
        avl_node *a = node_find_index(idx, t);
        return rebalance_del(a, t, backup);
    }
}

/* Outcome: [t0] handles the concatenation of [t0] and [t1] */

void avl_cat(avl_tree t0, avl_tree t1)
{
    if (! t0 || ! t1 ||! t1->root) {
        return;
    } else if (t0->root) {
        int delta = depth(t1->root) - depth(t0->root);
        ptr_handler h = { NULL, OP_DETACH };
        if (delta <= 0) {
            if (node_del_first (t1, &h) == 2) {
                --delta;
            }
            (void) join_left((avl_node *) h.ptr, &t0->root, t1->root, delta, (int) (t0->count + 1));
        } else {
            if (node_del_last(t0, &h) == 2) {
                ++delta;
            }
            (void) join_right((avl_node *) h.ptr, t0->root, &t1->root, delta, (int) (t0->count + 1));
            t0->root = t1->root;
        }
        t1->root = NULL;
        t0->count += t1->count + 1;
        t1->count = 0;
    } else {
        t0->root = t1->root;
        t0->count = t1->count;
        t1->root = NULL;
        t1->count = 0;
    }
}

/*
    - [t0] and [t1] are existing handles
    - See Donald Knuth, TAOCP Vol.3 "Sorting and searching"
*/

avl_code_t avl_split(const void *item, avl_tree t, avl_tree t0, avl_tree t1)
{
    if (t && t->root) {
        t0->root = NULL;
        t1->root = NULL;
        t0->count = 0;
        t1->count = 0;
        avl_compare_func cmp = t->compare;
        avl_node *a, *p, *sn; /* sn: split node */
        int k, na, an[AVL_STACK_CAPACITY];
        /* invariant: [na]= size of tree rooted at [a] plus one */
        for (a = t->root, na = (int) (t->count + 1), k = 0;;) {
            int d_ = item_compare(cmp, t, item, get_item(a));
            if (d_) {
                p = a->sub[d_ = d_ > 0];
                if (p) {
                    an[k++] = na;
                    if (d_) {
                        na -= (int) get_rank(a);
                    } else {
                        na = (int) get_rank(a);
                    }
                    a = p;
                } else {
                    return 0;
                }
            } else {
                break;
            }
        }
        /* record split node */
        sn = a;
        if (k == 0) {
            t0->root = sub_left(a);
            t1->root = sub_right(a);
            if (t0->root) {
                t0->root->up = NULL;
            }
            if (t1->root) {
                t1->root->up = NULL;
            }
            t0->count = get_rank(a) - 1;
            t1->count = t->count - get_rank(a);
        } else {
            avl_node *r[2];
            int h[2], ha;
            avl_size_t n[2];
            int d_;
            r[0] = sub_left(a);
            r[1] = sub_right(a);
            if (r[0]) {
                r[0]->up = NULL;
            }
            if (r[1]) {
                r[1]->up = NULL;
            }
            ha = depth(a);
            h[0] = ha - (is_rskew(a) ? 2 : 1);
            h[1] = ha - (is_lskew(a) ? 2 : 1);
            n[0] = get_rank(a);           /* size of r[0] plus one */
            n[1] = (avl_size_t) na - n[0];  /* size of r[1] plus one */
            for (p = a->up, d_ = a != sub_left(p);;) {
                a = p; /* a: juncture node */
                p = a->up;
                if (d_ == 0) {
                    int hh = h[1];
                    int nn;
                    ha += (is_rskew(a) ? 2 : 1);
                    h[1] = ha - (is_lskew(a) ? 2 : 1);
                    nn = n[1];
                    n[1] += (avl_size_t) (an[k - 1] - (int) get_rank(a));
                    if (p) {
                        d_ = a != sub_left(p);
                    }
                    rbal(a) = 0;
                    if (h[1] >= hh) {
                        avl_node *rr = r[1];
                        r[1] = sub_right(a);
                        if (r[1]) {
                            r[1]->up = NULL;
                        }
                        h[1] += (2 == join_right(a, rr, r + 1, h[1] - hh, (int) nn));
                    } else {
                        h[1] = hh + (2 == join_left(a, r + 1, sub_right(a), h[1] - hh, (int) nn));
                  }
            } else {
                int hh = h[0];
                int nn;
                ha += (is_lskew(a) ? 2 : 1);
                h[0] = ha - (is_rskew(a) ? 2 : 1);
                nn = get_rank(a);
                n[0] += nn;
                if (p) {
                    d_ = a != sub_left(p);
                }
                rbal(a) = 0;
                if (h[0] >= hh) {
                    avl_node *rr = r[0];
                    r[0] = sub_left(a);
                    if (r[0]) {
                        r[0]->up = NULL;
                    }
                    h[0] += (2 == join_left(a, r, rr, hh - h[0], (int) nn));
                } else {
                    h[0] = hh + (2 == join_right(a, sub_left(a), r, hh - h[0], (int) nn));
                }
            }
            if (--k == 0)
                break;
            }
            t0->root = r[0];
            t1->root = r[1];
            t0->count = n[0] - 1;
            t1->count = n[1] - 1;
        }
        /* Detach split node */
        detach_node(sn, t, NULL);
        t->root = NULL;
        t->count = 0;
        return 1;
    } else {
        return 0;
    }
}

/* Inorder traversal */

void avl_walk(avl_tree t, avl_item_func proc, void *param)
{
    if (t && t->root) {
        avl_node *a = t->root, *p;
        while (1) {
            while (sub_left(a)) {
                a = sub_left(a);
            }
            while (1) {
                (*proc)(get_item(a), param);
                if (sub_right(a)) {
                    break;
                } else {
                    do {
                        p = a;
                        a = p->up;
                        if (! a) {
                            return;
                        }
                    }
                    while (p != sub_left(a));
                }
            }
            a = sub_right(a);
        }
    }
}

/* recursive helper for 'avl_slice' */

static int node_slice(avl_node **root, avl_node **cur, avl_tree tree, avl_size_t len)
{
    avl_size_t mid = len / 2;
    if (mid == 0) {
        if ((*root = new_node ((*cur)->item, /*parent */ NULL, tree)) == NULL) {
            return -1;
        } else {
            sub_left(*root) = NULL;
            sub_right(*root) = NULL;
            rbal(*root) = 4;
            *cur = node_next(*cur);
            return 0;
        }
    } else if ((*root = new_node(NULL, /*parent */ NULL, tree))) {
        avl_node *p = *root;
        int h0, h1 = -1;
        rbal(p) = (mid + 1) << 2;
        if ((h0 = node_slice(&sub_left(p), cur, tree, mid)) < 0) {
            return -1;
        } else {
            p->item = (*tree->copy) ((*cur)->item);
            sub_left(p)->up = p;
            *cur = node_next(*cur);
            if (len -= mid + 1) {
                if ((h1 = node_slice(&sub_right(p), cur, tree, len)) < 0) {
                    return -1;
                } else {
                    sub_right(p)->up = p;
                }
            }
            if (h0 > h1) {
                set_lskew(p);
            } else if (h0 < h1) {
                set_rskew(p);
                return 1 + h1;
            }
            return 1 + h0;
        }
    } else {
        return -1;
    }
}

/* Return a slice t[lo,hi) as a new tree */

avl_tree avl_slice(avl_tree t, avl_size_t lo_idx, avl_size_t hi_idx, void *param)
{
    if (! t || (lo_idx > hi_idx) || (lo_idx > t->count))  {
        return NULL;
    } else {
        if (lo_idx < 1) {
            lo_idx = 1;
        }
        if (hi_idx > t->count + 1) {
            hi_idx = t->count + 1;
        }
        {
            avl_tree tt = avl_create(t->compare, t->copy, t->dispose, t->alloc, t->dealloc, param);
            if (tt) {
                if (lo_idx < hi_idx) {
                    avl_node *cur = node_find_index(lo_idx, t);
                    if (node_slice(&tt->root, &cur, t, tt->count = hi_idx - lo_idx) < 0) {
                        AVL_SHOW_ERROR("%s\n", "couldn't allocate node in avl_slice()");
                        node_empty(tt);
                        (*t->dealloc)(tt);
                        return NULL;
                    } else {
                        tt->root->up = NULL;
                    }
                }
                return tt;
            } else {
                AVL_SHOW_ERROR("%s\n", "couldn't allocate new handle in avl_slice()");
                return NULL;
            }
        }
    }
}

/* recursive helper for 'avl_xload' */

static int node_load(avl_node **root, avl_itersource cur, void **pres, avl_tree desc, avl_size_t len)
{
    avl_size_t mid = len / 2;
    if (mid == 0) {
        if (0 != (*cur->f) (cur, pres) || (*root = new_node (*pres, /*parent */ NULL, desc)) == NULL) {
            return -1;
        } else {
            sub_left(*root) = NULL;
            sub_right(*root) = NULL;
            rbal(*root) = 4;
            return 0;
        }
    } else if ((*root = new_node (NULL, /*parent */ NULL, desc))) {
        avl_node *p = *root;
        int h0, h1 = -1;
        rbal(p) = (mid + 1) << 2;
        if ((h0 = node_load(&sub_left(p), cur, pres, desc, mid)) < 0) {
            return -1;
        } else if (0 != (*cur->f)(cur, pres)) {
            return -1;
        } else {
            p->item = (*desc->copy)(*pres);
            sub_left(p)->up = p;
            if (len -= mid + 1) {
                if ((h1 = node_load(&sub_right(p), cur, pres, desc, len)) < 0) {
                    return -1;
                } else {
                    sub_right(p)->up = p;
                }
            }
            if (h0 > h1) {
                set_lskew(p);
            } else if (h0 < h1) {
                set_rskew(p);
                return 1 + h1;
            }
            return 1 + h0;
        }
    } else {
        return -1;
    }
}

/* Load 'len' items from itersource */

avl_tree avl_xload(avl_itersource src, void **pres, avl_size_t len, avl_config conf, void *tree_param)
{
    if (src) {
        avl_tree tt = avl_create(conf->compare, conf->copy, conf->dispose, conf->alloc, conf->dealloc, tree_param);
        if (! tt) {
            AVL_SHOW_ERROR("%s\n", "couldn't allocate new handle in avl_load()");
            return NULL;
        } if (len) {
            if (node_load(&tt->root, src, pres, tt, tt->count = len) < 0) {
                AVL_SHOW_ERROR("%s\n", "couldn't allocate node in avl_load()");
                node_empty(tt);
                (*tt->dealloc)(tt);
                return NULL;
            } else {
                tt->root->up = NULL;
            }
        }
        return tt;
    } else {
        return NULL;
    }
}

/* ITERATORS */

typedef enum {
    AVL_ITERATOR_PRE,
    AVL_ITERATOR_POST,
    AVL_ITERATOR_INTREE
} avl_status_t;

struct avl_iterator_
{
    avl_node     *pos;
    avl_tree      tree;
    avl_status_t  status;
};

# define get_root(i)          i->tree->root
# define is_pre(i)            i->status == AVL_ITERATOR_PRE
# define is_post(i)           i->status == AVL_ITERATOR_POST
# define set_pre_iterator(i)  i->status = AVL_ITERATOR_PRE
# define set_post_iterator(i) i->status = AVL_ITERATOR_POST
# define set_in_iterator(i)   i->status = AVL_ITERATOR_INTREE

/*
    Position existing iterator [iter] at node matching [item] in its own tree,
    if it exists ; otherwise do nothing
*/

void avl_iterator_seek(const void *item, avl_iterator iter)
{
    avl_node *p = node_find(item, iter->tree);
    if (p) {
        set_in_iterator(iter);
        iter->pos = p;
    }
}

void avl_iterator_seek_index(avl_size_t idx, avl_iterator iter)
{
    avl_node *p = node_find_index(idx, iter->tree);
    if (p) {
        set_in_iterator(iter);
        iter->pos = p;
    }
}

/* Return item pointer at current position */

void *avl_iterator_cur(avl_iterator iter)
{
    return iter->pos ? get_item(iter->pos) : NULL;
}

avl_size_t avl_iterator_count(avl_iterator iter)
{
    return iter->tree->count;
}

avl_size_t avl_iterator_index(avl_iterator iter)
{
    if (iter->pos) {
        return get_index(iter->pos);
    } else if (is_pre(iter)) {
        return 0;
    } else {
        return iter->tree->count + 1;
    }
}

/* Rustic: */

avl_iterator avl_iterator_new(avl_tree t, avl_ini_t ini, ...)
{
    va_list args;
    avl_iterator iter = NULL;
    va_start(args, ini);
    if (! t) {
        /* okay */
    } else if ((iter = (*t->alloc) (sizeof(struct avl_iterator_)))) {
        iter->pos = NULL;
        iter->tree = t;
        if (ini != AVL_ITERATOR_INI_INTREE) {
            iter->status = (ini == AVL_ITERATOR_INI_PRE) ? AVL_ITERATOR_PRE : AVL_ITERATOR_POST;
        } else {
            const void *item = NULL;
            item = va_arg(args, const void *);
            set_pre_iterator(iter);
            if (item == NULL) {
                AVL_SHOW_ERROR("%s\n", "missing argument to avl_iterator_new()");
            } else {
                avl_iterator_seek(item, iter);
            }
        }
    } else {
        AVL_SHOW_ERROR("%s\n", "couldn't create iterator");
    }
    va_end(args);
    return iter;
}

/*
    The following used to write to memory after it was freed. Corrected by: David
    Turner <novalis@openplans.org>
*/

void avl_iterator_kill(avl_iterator iter)
{
    if (iter != NULL) {
        avl_dealloc_func dealloc = iter->tree->dealloc;
        iter->pos = NULL;
        iter->tree = NULL;
        (*dealloc)(iter);
    }
}

void *avl_iterator_next(avl_iterator iter)
{
    if (is_post(iter)) {
        return NULL;
    } else {
        avl_node *a = iter->pos;
        if (is_pre(iter)) {
            a = get_root(iter);
            if (a) {
                a = node_first(a);
                set_in_iterator(iter);
            }
        } else {
            a = node_next(a);
            if (! a) {
                set_post_iterator(iter);
            }
        }
        iter->pos = a;
        return a != NULL ? get_item(a) : NULL;
    }
}

void *avl_iterator_prev(avl_iterator iter)
{
    if (is_pre(iter)) {
        return NULL;
    } else {
        avl_node *a = iter->pos;
        if (is_post(iter)) {
            a = get_root(iter);
            if (a) {
                a = node_last(a);
                set_in_iterator(iter);
            }
        } else {
            a = node_prev(a);
            if (! a) {
                set_pre_iterator(iter);
            }
        }
        iter->pos = a;
        return a ? get_item(a) : NULL;
    }
}

/* Remove node at current position and move cursor to next position */

avl_code_t avl_iterator_del(avl_iterator iter, void **backup)
{
    if (iter == NULL || iter->pos == NULL) {
        return 0;
    } else {
        avl_node *a = iter->pos, *p;
        p = node_next(a);
        if (! p) {
            set_post_iterator(iter);
        }
        iter->pos = p;
        return rebalance_del(a, iter->tree, backup);
    }
}
