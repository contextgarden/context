/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

/*tex

Contrary to traditional \TEX\ we have catcode tables so that we can switch
catcode regimes very fast. We can have many such regimes and they're stored in
trees.

*/

# define CATCODESTACK     8
# define CATCODEDEFAULT  12
# define CATCODE_MAX    256  /*tex This was 32767 but we can stick to 256 as with math families. */

# define malloc_sa_array(a,b) malloc((unsigned)((unsigned)(b)*sizeof(a)))

typedef struct catcode_state_info {
    sa_tree *catcode_heads;
    int catcode_max;
    unsigned char *catcode_valid;
} catcode_state_info;

static catcode_state_info catcode_state = { NULL, 0, NULL } ;

# define catcode_heads catcode_state.catcode_heads
# define catcode_max   catcode_state.catcode_max
# define catcode_valid catcode_state.catcode_valid

void set_cat_code(int h, int n, halfword v, quarterword gl)
{
    sa_tree_item sa_value = { 0 };
    sa_tree s = catcode_heads[h];
    if (h > catcode_max)
        catcode_max = h;
    if (s == NULL) {
        sa_value.int_value = CATCODEDEFAULT;
        s = new_sa_tree(CATCODESTACK, 1, sa_value);
        catcode_heads[h] = s;
    }
    sa_value.int_value = (int) v;
    set_sa_item(s, n, sa_value, gl);
}

halfword get_cat_code(int h, int n)
{
    sa_tree_item sa_value = { 0 };
    sa_tree s = catcode_heads[h];
    if (h > catcode_max)
        catcode_max = h;
    if (s == NULL) {
        sa_value.int_value = CATCODEDEFAULT;
        s = new_sa_tree(CATCODESTACK, 1, sa_value);
        catcode_heads[h] = s;
    }
    return_sa_item(s,n);
}

void unsave_cat_codes(int h, quarterword gl)
{
    int k;
    if (h > catcode_max)
        catcode_max = h;
    for (k = 0; k <= catcode_max; k++) {
        if (catcode_heads[k] != NULL)
            restore_sa_stack(catcode_heads[k], gl);
    }
}

static void initializecatcodes(void)
{
    sa_tree_item sa_value = { 0 };
    catcode_max = 0;
    catcode_heads = malloc_sa_array(sa_tree, (CATCODE_MAX + 1));
    catcode_valid = malloc_sa_array(unsigned char, (CATCODE_MAX + 1));
    memset(catcode_heads, 0, sizeof(sa_tree) * (CATCODE_MAX + 1));
    memset(catcode_valid, 0, sizeof(unsigned char) * (CATCODE_MAX + 1));
    catcode_valid[0] = 1;
    sa_value.int_value = CATCODEDEFAULT;
    catcode_heads[0] = new_sa_tree(CATCODESTACK, 1, sa_value);
}

static void dumpcatcodes(void)
{
    int total = 0;
    int k;
    for (k = 0; k <= catcode_max; k++) {
        if (catcode_valid[k]) {
            total++;
        }
    }
    dump_int(catcode_max);
    dump_int(total);
    for (k = 0; k <= catcode_max; k++) {
        if (catcode_valid[k]) {
            dump_int(k);
            dump_sa_tree(catcode_heads[k]);
        }
    }
}

static void undumpcatcodes(void)
{
    int total, k, x;
    free(catcode_heads);
    free(catcode_valid);
    catcode_heads = malloc_sa_array(sa_tree, (CATCODE_MAX + 1));
    catcode_valid = malloc_sa_array(unsigned char, (CATCODE_MAX + 1));
    memset(catcode_heads, 0, sizeof(sa_tree) * (CATCODE_MAX + 1));
    memset(catcode_valid, 0, sizeof(unsigned char) * (CATCODE_MAX + 1));
    undump_int(catcode_max);
    undump_int(total);
    for (k = 0; k < total; k++) {
        undump_int(x);
        catcode_heads[x] = undump_sa_tree();
        catcode_valid[x] = 1;
    }
}

int valid_catcode_table(int h)
{
    if (h <= CATCODE_MAX && h >= 0 && catcode_valid[h]) {
        return 1;
    }
    return 0;
}

void copy_cat_codes(int from, int to)
{
    if (from < 0 || from > CATCODE_MAX || catcode_valid[from] == 0) {
        exit(EXIT_FAILURE);
    }
    if (to > catcode_max)
        catcode_max = to;
    destroy_sa_tree(catcode_heads[to]);
    catcode_heads[to] = copy_sa_tree(catcode_heads[from]);
    catcode_valid[to] = 1;
}

void initex_cat_codes(int h)
{
    int k;
    if (h > catcode_max)
        catcode_max = h;
    destroy_sa_tree(catcode_heads[h]);
    catcode_heads[h] = NULL;
    set_cat_code(h, '\r', car_ret_cmd, 1);
    set_cat_code(h, ' ', spacer_cmd, 1);
    set_cat_code(h, '\\', escape_cmd, 1);
    set_cat_code(h, '%', comment_cmd, 1);
    set_cat_code(h, 127, invalid_char_cmd, 1);
    set_cat_code(h, 0, ignore_cmd, 1);
    set_cat_code(h, 0xFEFF, ignore_cmd, 1);
    for (k = 'A'; k <= 'Z'; k++) {
        set_cat_code(h, k, letter_cmd, 1);
        set_cat_code(h, k + 'a' - 'A', letter_cmd, 1);
    }
    catcode_valid[h] = 1;
}

static void freecatcodes(void)
{
    int k;
    for (k = 0; k <= catcode_max; k++) {
        if (catcode_valid[k]) {
            destroy_sa_tree(catcode_heads[k]);
        }
    }
    free(catcode_heads);
    free(catcode_valid);
    catcode_heads = NULL;
    catcode_valid = NULL;
}

/*tex

The lowercase mapping codes are also stored in a tree.

*/

/*tex

    Let's keep them close for cache hits, maybe also with hjcodes.

*/

# define LCCODESTACK      8
# define LCCODEDEFAULT    0

# define UCCODESTACK      8
# define UCCODEDEFAULT    0

# define SFCODESTACK      8
# define SFCODEDEFAULT 1000

typedef struct luscode_state_info {
    sa_tree uccode_head;
    sa_tree lccode_head;
    sa_tree sfcode_head;
} luscode_state_info;

static luscode_state_info luscode_state = { NULL, NULL, NULL } ;

# define uccode_head luscode_state.uccode_head
# define lccode_head luscode_state.lccode_head
# define sfcode_head luscode_state.sfcode_head

void set_lc_code(int n, halfword v, quarterword gl)
{
    sa_tree_item sa_value = { 0 };
    sa_value.int_value = (int) v;
    set_sa_item(lccode_head, n, sa_value, gl);
}

halfword get_lc_code(int n)
{
    return_sa_item(lccode_head,n);
}

static void unsavelccodes(quarterword gl)
{
    restore_sa_stack(lccode_head, gl);
}

static void initializelccodes(void)
{
    sa_tree_item sa_value = { 0 };
    sa_value.int_value = LCCODEDEFAULT;
    lccode_head = new_sa_tree(LCCODESTACK, 1, sa_value);
}

static void dumplccodes(void)
{
    dump_sa_tree(lccode_head);
}

static void undumplccodes(void)
{
    lccode_head = undump_sa_tree();
}

static void freelccodes(void)
{
    destroy_sa_tree(lccode_head);
}

/*tex

And the uppercase mapping codes are again stored in a tree.

*/

void set_uc_code(int n, halfword v, quarterword gl)
{
    sa_tree_item sa_value = { 0 };
    sa_value.int_value = (int) v;
    set_sa_item(uccode_head, n, sa_value, gl);
}

halfword get_uc_code(int n)
{
    return_sa_item(uccode_head,n);
}

static void unsaveuccodes(quarterword gl)
{
    restore_sa_stack(uccode_head, gl);
}

static void initializeuccodes(void)
{
    sa_tree_item sa_value = { 0 };
    sa_value.int_value = UCCODEDEFAULT;
    uccode_head = new_sa_tree(UCCODESTACK, 1, sa_value);
}

static void dumpuccodes(void)
{
    dump_sa_tree(uccode_head);
}

static void undumpuccodes(void)
{
    uccode_head = undump_sa_tree();
}

static void freeuccodes(void)
{
    destroy_sa_tree(uccode_head);
}

/*tex

By now it will be no surprise that the space factors get stored in a tree.

*/

void set_sf_code(int n, halfword v, quarterword gl)
{
    sa_tree_item sa_value = { 0 };
    sa_value.int_value = (int) v;
    set_sa_item(sfcode_head, n, sa_value, gl);
}

halfword get_sf_code(int n)
{
    return_sa_item(sfcode_head,n);
}

static void unsavesfcodes(quarterword gl)
{
    restore_sa_stack(sfcode_head, gl);
}

static void initializesfcodes(void)
{
    sa_tree_item sa_value = { 0 };
    sa_value.int_value = SFCODEDEFAULT;
    sfcode_head = new_sa_tree(SFCODESTACK, 1, sa_value);
}

static void dumpsfcodes(void)
{
    dump_sa_tree(sfcode_head);
}

static void undumpsfcodes(void)
{
    sfcode_head = undump_sa_tree();
}

static void freesfcodes(void)
{
    destroy_sa_tree(sfcode_head);
}

/*tex

The hyphenation codes are indeed stored in a tree and are used instead of
lowercase codes when deciding what characters to take into acccount when
hyphenating. They are bound to upto |HJCODE_MAX| languages.

*/

# define HJCODESTACK       8
# define HJCODEDEFAULT     0
# define HJCODE_MAX    16383

typedef struct hjcode_state_info {
    sa_tree *hjcode_heads;
    int hjcode_max;
    unsigned char *hjcode_valid;
} hjcode_state_info;

static hjcode_state_info hjcode_state = { NULL, 0, NULL } ;

# define hjcode_heads hjcode_state.hjcode_heads
# define hjcode_max   hjcode_state.hjcode_max
# define hjcode_valid hjcode_state.hjcode_valid


/*tex

Here we set codes but we don't initialize from lccodes.

*/

void set_hj_code(int h, int n, halfword v, quarterword gl)
{
    sa_tree_item sa_value = { 0 };
    sa_tree s = hjcode_heads[h];
    if (h > hjcode_max)
        hjcode_max = h;
    if (s == NULL) {
        sa_value.int_value = HJCODEDEFAULT;
        s = new_sa_tree(HJCODESTACK, 1, sa_value);
        hjcode_heads[h] = s;
    }
    sa_value.int_value = (int) v;
    set_sa_item(s, n, sa_value, gl);
}

/*tex

We just return the lccodes when nothing is set.

*/

halfword get_hj_code(int h, int n)
{
    sa_tree s = hjcode_heads[h];
    if (s == NULL) {
        s = lccode_head;
    }
    return_sa_item(s,n);
}

/*tex

We don't restore as we can have more languages in a paragraph and hyphenation
takes place at a later stage so we would get weird grouping side effects .. so,
one can overload settings but management is then upto the used, so no:

*/

/*
    static void unsavehjcodes(quarterword gl) { }
*/

static void initializehjcodes(void)
{
    /*
        sa_tree_item sa_value = { 0 };
    */
    hjcode_max = 0;
    hjcode_heads = malloc_sa_array(sa_tree, (HJCODE_MAX + 1));
    hjcode_valid = malloc_sa_array(unsigned char, (HJCODE_MAX + 1));
    memset(hjcode_heads, 0, sizeof(sa_tree) * (HJCODE_MAX + 1));
    memset(hjcode_valid, 0, sizeof(unsigned char) * (HJCODE_MAX + 1));
    /*
        hjcode_valid[0] = 1;
        sa_value.int_value = HJCODEDEFAULT;
        hjcode_heads[0] = new_sa_tree(HJCODESTACK, 1, sa_value);
    */
}

void hj_codes_from_lc_codes(int h)
{
    sa_tree_item sa_value = { 0 };
    sa_tree s = hjcode_heads[h];
    if (s != NULL) {
        destroy_sa_tree(s);
    } else if (h > hjcode_max) {
        hjcode_max = h;
    }
    if (s == NULL) {
        sa_value.int_value = HJCODEDEFAULT;
        s = new_sa_tree(HJCODESTACK, 1, sa_value);
        hjcode_heads[h] = s;
    }
    hjcode_heads[h] = copy_sa_tree(lccode_head);
    hjcode_valid[h] = 1;
}

static void dumphjcodes(void)
{
    int total = 0;
    int k;
    for (k = 0; k <= hjcode_max; k++) {
        if (hjcode_valid[k]) {
            total++;
        }
    }
    dump_int(hjcode_max);
    dump_int(total);
    for (k = 0; k <= hjcode_max; k++) {
        if (hjcode_valid[k]) {
            dump_int(k);
            dump_sa_tree(hjcode_heads[k]);
        }
    }
}

static void undumphjcodes(void)
{
    int total, k, x;
    free(hjcode_heads);
    free(hjcode_valid);
    hjcode_heads = malloc_sa_array(sa_tree, (HJCODE_MAX + 1));
    hjcode_valid = malloc_sa_array(unsigned char, (HJCODE_MAX + 1));
    memset(hjcode_heads, 0, sizeof(sa_tree) * (HJCODE_MAX + 1));
    memset(hjcode_valid, 0, sizeof(unsigned char) * (HJCODE_MAX + 1));
    undump_int(hjcode_max);
    undump_int(total);
    for (k = 0; k < total; k++) {
        undump_int(x);
        hjcode_heads[x] = undump_sa_tree();
        hjcode_valid[x] = 1;
    }
}

static void freehjcodes(void)
{
    int k;
    for (k = 0; k <= hjcode_max; k++) {
        if (hjcode_valid[k]) {
            destroy_sa_tree(hjcode_heads[k]);
        }
    }
    free(hjcode_heads);
    free(hjcode_valid);
    hjcode_heads = NULL;
    hjcode_valid = NULL;
}

/*tex

The public management functions.

*/

void unsave_text_codes(quarterword grouplevel)
{
    unsavelccodes(grouplevel);
    unsaveuccodes(grouplevel);
    unsavesfcodes(grouplevel);
}

void initialize_text_codes(void)
{
    initializecatcodes();
    initializelccodes();
    initializeuccodes();
    initializesfcodes();
    initializehjcodes();
}

void free_text_codes(void)
{
    freecatcodes();
    freelccodes();
    freeuccodes();
    freesfcodes();
    freehjcodes();
}

void dump_text_codes(void)
{
    dumpcatcodes();
    dumplccodes();
    dumpuccodes();
    dumpsfcodes();
    dumphjcodes();
}

void undump_text_codes(void)
{
    undumpcatcodes();
    undumplccodes();
    undumpuccodes();
    undumpsfcodes();
    undumphjcodes();
}
