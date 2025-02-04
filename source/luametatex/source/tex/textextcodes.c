/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Contrary to traditional \TEX\ we have catcode tables so that we can switch catcode regimes very
    fast. We can have many such regimes and they're stored in trees.

*/

/*tex

    Using nibbles for catcodes is somewhat more messy but saves 230MB on the format file so it is
    worth the trouble.

*/

# define nibbled_catcodes 1 

# define CATCODESTACK     8
# define CATCODESTEP      8
# define CATCODEDEFAULT  12

# if nibbled_catcodes
    # define CATCODEDEFAULTS 0xCCCCCCCC /*tex Used as |dflt| value in |sa| struct. */
# else 
    # define CATCODEDEFAULTS 0x0C0C0C0C /*tex Used as |dflt| value in |sa| struct. */
# endif 

typedef struct catcode_state_info {
    sa_tree       *catcode_heads;
    unsigned char *catcode_valid;
    int            catcode_max;
    int            padding;
} catcode_state_info;

static catcode_state_info lmt_catcode_state = {
    .catcode_heads = NULL,
    .catcode_valid = NULL,
    .catcode_max   = 0,
    .padding       = 0,
} ;

static void tex_aux_allocate_catcodes(void)
{
    lmt_catcode_state.catcode_heads = sa_malloc_array(sizeof(sa_tree), max_n_of_catcode_tables);
    lmt_catcode_state.catcode_valid = sa_malloc_array(sizeof(unsigned char), max_n_of_catcode_tables);
    if (lmt_catcode_state.catcode_heads && lmt_catcode_state.catcode_valid) {
        sa_wipe_array(lmt_catcode_state.catcode_heads, sizeof(sa_tree), max_n_of_catcode_tables);
        sa_wipe_array(lmt_catcode_state.catcode_valid, sizeof(unsigned char), max_n_of_catcode_tables);
    } else {
        tex_overflow_error("catcodes", max_n_of_catcode_tables);
    }
}

static void tex_aux_initialize_catcodes(void)
{
    sa_tree_item item = { .uint_value = CATCODEDEFAULTS };
    lmt_catcode_state.catcode_max = 0;
    tex_aux_allocate_catcodes();
    lmt_catcode_state.catcode_valid[0] = 1;
# if nibbled_catcodes
    lmt_catcode_state.catcode_heads[0] = sa_new_tree(catcode_sparse_identifier, CATCODESTACK, CATCODESTEP, 0, item);
# else 
    lmt_catcode_state.catcode_heads[0] = sa_new_tree(catcode_sparse_identifier, CATCODESTACK, CATCODESTEP, 1, item);
# endif 
}

void tex_set_cat_code(int h, int n, halfword v, int gl)
{
    sa_tree_item item = { .uint_value = CATCODEDEFAULTS };
    sa_tree tree = lmt_catcode_state.catcode_heads[h];
    if (! tree) {
        if (h > lmt_catcode_state.catcode_max) {
            lmt_catcode_state.catcode_max = h;
        }
# if nibbled_catcodes
        tree = sa_new_tree(catcode_sparse_identifier, CATCODESTACK, CATCODESTEP, 0, item);
# else 
        tree = sa_new_tree(catcode_sparse_identifier, CATCODESTACK, CATCODESTEP,1, item);
# endif 
        lmt_catcode_state.catcode_heads[h] = tree;
    }
# if nibbled_catcodes
    sa_set_item_0(tree, n, v, gl);
# else 
    sa_set_item_1(tree, n, v, gl);
# endif 
}

halfword tex_get_cat_code(int h, int n)
{
    sa_tree_item item = { .uint_value = CATCODEDEFAULTS };
    sa_tree tree = lmt_catcode_state.catcode_heads[h];
    if (! tree) {
        if (h > lmt_catcode_state.catcode_max) {
            lmt_catcode_state.catcode_max = h;
        }
# if nibbled_catcodes
        tree = sa_new_tree(catcode_sparse_identifier, CATCODESTACK, CATCODESTEP, 0, item);
# else 
        tree = sa_new_tree(catcode_sparse_identifier, CATCODESTACK, CATCODESTEP, 1, item);
# endif 
        lmt_catcode_state.catcode_heads[h] = tree;
    }
# if nibbled_catcodes
    return sa_return_item_0(tree, n);
# else 
    return sa_return_item_1(tree, n);
# endif 
}

void tex_unsave_cat_codes(int h, int gl)
{
    if (h > lmt_catcode_state.catcode_max) {
        lmt_catcode_state.catcode_max = h;
    }
    for (int k = 0; k <= lmt_catcode_state.catcode_max; k++) {
        if (lmt_catcode_state.catcode_heads[k]) {
            sa_restore_stack(lmt_catcode_state.catcode_heads[k], gl);
        }
    }
}

void tex_restore_cat_codes(int h, int level)
{
    if (h > lmt_catcode_state.catcode_max) {
        lmt_catcode_state.catcode_max = h;
    }
    for (int k = 0; k <= lmt_catcode_state.catcode_max; k++) {
        if (lmt_catcode_state.catcode_heads[k]) {
            sa_reinit_stack(lmt_catcode_state.catcode_heads[k], level);
        }
    }
}

static void tex_aux_dump_catcodes(dumpstream f)
{
    int total = 0;
    for (int k = 0; k <= lmt_catcode_state.catcode_max; k++) {
        if (lmt_catcode_state.catcode_valid[k]) {
            total++;
        }
    }
    dump_int(f, lmt_catcode_state.catcode_max);
    dump_int(f, total);
    dump_via_int(f, nibbled_catcodes);
    for (int k = 0; k <= lmt_catcode_state.catcode_max; k++) {
        if (lmt_catcode_state.catcode_valid[k]) {
            dump_int(f, k);
            sa_dump_tree(f, lmt_catcode_state.catcode_heads[k]);
        }
    }
}

static void tex_aux_undump_catcodes(dumpstream f)
{
    int total, nibbled;
    sa_free_array(lmt_catcode_state.catcode_heads);
    sa_free_array(lmt_catcode_state.catcode_valid);
    tex_aux_allocate_catcodes();
    undump_int(f, lmt_catcode_state.catcode_max);
    undump_int(f, total);
    undump_int(f, nibbled);
    if (nibbled == nibbled_catcodes) { 
        for (int k = 0; k < total; k++) {
            int x;
            undump_int(f, x);
            lmt_catcode_state.catcode_heads[x] = sa_undump_tree(f);
            lmt_catcode_state.catcode_valid[x] = 1;
        }
    } else { 
        tex_fatal_undump_error("nibbled catcodes mismatch");
    }
}

int tex_valid_catcode_table(int h)
{
    return (h >= 0 && h < max_n_of_catcode_tables && lmt_catcode_state.catcode_valid[h]);
}

void tex_copy_cat_codes(int from, int to)
{
    if (from < 0 || from >= max_n_of_catcode_tables || lmt_catcode_state.catcode_valid[from] == 0) {
        exit(EXIT_FAILURE);
    } else {
        if (to > lmt_catcode_state.catcode_max) {
            lmt_catcode_state.catcode_max = to;
        }
        sa_destroy_tree(lmt_catcode_state.catcode_heads[to]);
        lmt_catcode_state.catcode_heads[to] = sa_copy_tree(lmt_catcode_state.catcode_heads[from]);
        lmt_catcode_state.catcode_valid[to] = 1;
    }
}

/*
void set_cat_code_table_default(int h, int dflt)
{
    if (valid_catcode_table(h)) {
        catcode_state.catcode_heads[h]->dflt.uchar_value[0] = (unsigned char) dflt;
        catcode_state.catcode_heads[h]->dflt.uchar_value[1] = (unsigned char) dflt;
        catcode_state.catcode_heads[h]->dflt.uchar_value[2] = (unsigned char) dflt;
        catcode_state.catcode_heads[h]->dflt.uchar_value[3] = (unsigned char) dflt;
    }
}

int get_cat_code_table_default(int h)
{
    if (valid_catcode_table(h)) {
        return catcode_state.catcode_heads[h]->dflt.uchar_value[0];
    } else {
        return CATCODEDEFAULT;
    }
}
*/

void tex_initialize_cat_codes(int h)
{
    if (h > lmt_catcode_state.catcode_max) {
        lmt_catcode_state.catcode_max = h;
    }
    sa_destroy_tree(lmt_catcode_state.catcode_heads[h]);
    lmt_catcode_state.catcode_heads[h] = NULL;
    tex_set_cat_code(h, '\r', end_line_cmd, 1);
    tex_set_cat_code(h, ' ', spacer_cmd, 1);
    tex_set_cat_code(h, '\\', escape_cmd, 1);
    tex_set_cat_code(h, '%', comment_cmd, 1);
    tex_set_cat_code(h, 127, invalid_char_cmd, 1);
    tex_set_cat_code(h, 0, ignore_cmd, 1);
    tex_set_cat_code(h, 0xFEFF, ignore_cmd, 1);
    for (int k = 'A'; k <= 'Z'; k++) {
        tex_set_cat_code(h, k, letter_cmd, 1);
        tex_set_cat_code(h, k + 'a' - 'A', letter_cmd, 1);
    }
    lmt_catcode_state.catcode_valid[h] = 1;
}

static void tex_aux_free_catcodes(void)
{
    for (int k = 0; k <= lmt_catcode_state.catcode_max; k++) {
        if (lmt_catcode_state.catcode_valid[k]) {
            sa_destroy_tree(lmt_catcode_state.catcode_heads[k]);
        }
    }
    lmt_catcode_state.catcode_heads = sa_free_array(lmt_catcode_state.catcode_heads);
    lmt_catcode_state.catcode_valid = sa_free_array(lmt_catcode_state.catcode_valid);
}

/*tex

    We have a whole bunch of character related codes. We could consider packign them all in one big
    character blob but this more fits in teh way \TEX\ is designed.  

*/

# define LCCODESTACK      8
# define LCCODESTEP       8
# define LCCODEDEFAULT    0

# define UCCODESTACK      8
# define UCCODESTEP       8
# define UCCODEDEFAULT    0

# define SFCODESTACK      8
# define SFCODESTEP       8
# define SFCODEDEFAULT    default_space_factor

# define HCCODESTACK      8
# define HCCODESTEP       8
# define HCCODEDEFAULT    0

# define HMCODESTACK      8
# define HMCODESTEP       8
# define HMCODEDEFAULT    0

# define AMCODESTACK      8
# define AMCODESTEP       8
# define AMCODEDEFAULT    0

# define CCCODESTACK      8 /* no need for stack */
# define CCCODESTEP       8 /* no need for stack */
# define CCCODEDEFAULT    default_character_control

typedef struct luscode_state_info {
    sa_tree uccode_head;
    sa_tree lccode_head;
    sa_tree sfcode_head;
    sa_tree hccode_head;
    sa_tree hmcode_head;
    sa_tree amcode_head;
    sa_tree cccode_head;
} luscode_state_info;

static luscode_state_info lmt_luscode_state = {
    .uccode_head = NULL,
    .lccode_head = NULL,
    .sfcode_head = NULL,
    .hccode_head = NULL,
    .hmcode_head = NULL,
    .amcode_head = NULL,
    .cccode_head = NULL,
};

/*tex

    The lowercase mapping codes are also stored in a tree. Let's keep them close for cache hits,
    maybe also with hjcodes.

*/

void tex_set_lc_code(int n, halfword v, int gl)
{
    sa_tree_item item = { .int_value = v };
    sa_set_item_4(lmt_luscode_state.lccode_head, n, item, gl);
}

halfword tex_get_lc_code(int n)
{
    return sa_return_item_4(lmt_luscode_state.lccode_head, n);
}

static void tex_aux_unsave_lccodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.lccode_head, gl);
}

static void tex_aux_initialize_lccodes(void)
{
    sa_tree_item item = {.int_value = LCCODEDEFAULT };
    lmt_luscode_state.lccode_head = sa_new_tree(lccode_sparse_identifier, LCCODESTACK, LCCODESTEP, 4, item);
}

static void tex_aux_dump_lccodes(dumpstream f)
{
    sa_dump_tree(f, lmt_luscode_state.lccode_head);
}

static void tex_aux_undump_lccodes(dumpstream f)
{
    lmt_luscode_state.lccode_head = sa_undump_tree(f);
}

static void tex_aux_free_lccodes(void)
{
    sa_destroy_tree(lmt_luscode_state.lccode_head);
}

/*tex

    And the uppercase mapping codes are again stored in a tree.

*/

void tex_set_uc_code(int n, halfword v, int gl)
{
    sa_tree_item item = { .int_value = v };
    sa_set_item_4(lmt_luscode_state.uccode_head, n, item, gl);
}

halfword tex_get_uc_code(int n)
{
    return sa_return_item_4(lmt_luscode_state.uccode_head, n);
}

static void tex_aux_unsave_uccodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.uccode_head, gl);
}

static void tex_aux_initialize_uccodes(void)
{
    sa_tree_item item = { .int_value = UCCODEDEFAULT };
    lmt_luscode_state.uccode_head = sa_new_tree(uccode_sparse_identifier, UCCODESTACK, UCCODESTEP, 4, item);
}

static void tex_aux_dump_uccodes(dumpstream f)
{
    sa_dump_tree(f,lmt_luscode_state.uccode_head);
}

static void tex_aux_undump_uccodes(dumpstream f)
{
    lmt_luscode_state.uccode_head = sa_undump_tree(f);
}

static void tex_aux_free_uccodes(void)
{
    sa_destroy_tree(lmt_luscode_state.uccode_head);
}

/*tex

    By now it will be no surprise that the space factors get stored in a tree.

*/

void tex_set_sf_code(int n, halfword v, int gl)
{
    sa_tree_item item = { .int_value = v };
    sa_set_item_4(lmt_luscode_state.sfcode_head, n, item, gl);
}

halfword tex_get_sf_code(int n)
{
    return sa_return_item_4(lmt_luscode_state.sfcode_head, n);
}

static void tex_aux_unsave_sfcodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.sfcode_head, gl);
}

static void tex_aux_initialize_sfcodes(void)
{
    sa_tree_item item = { .int_value = SFCODEDEFAULT };
    lmt_luscode_state.sfcode_head = sa_new_tree(sfcode_sparse_identifier, SFCODESTACK, SFCODESTEP, 4, item);
}

static void tex_aux_dump_sfcodes(dumpstream f)
{
    sa_dump_tree(f, lmt_luscode_state.sfcode_head);
}

static void tex_aux_undump_sfcodes(dumpstream f)
{
    lmt_luscode_state.sfcode_head = sa_undump_tree(f);
}

static void tex_aux_free_sfcodes(void)
{
    sa_destroy_tree(lmt_luscode_state.sfcode_head);
}

/*tex

    Finaly the hyphen character codes, a rather small sparse array.

*/

void tex_set_hc_code(int n, halfword v, int gl)
{
    sa_tree_item item = { .int_value = v };
    sa_set_item_4(lmt_luscode_state.hccode_head, n, item, gl);
}

halfword tex_get_hc_code(int n)
{
    return sa_return_item_4(lmt_luscode_state.hccode_head, n);
}

static void tex_aux_unsave_hccodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.hccode_head, gl);
}

static void tex_aux_initialize_hccodes(void)
{
    sa_tree_item item = { .int_value = HCCODEDEFAULT };
    lmt_luscode_state.hccode_head = sa_new_tree(hccode_sparse_identifier, HCCODESTACK, HCCODESTEP, 4, item);
}

static void tex_aux_dump_hccodes(dumpstream f)
{
    sa_dump_tree(f, lmt_luscode_state.hccode_head);
}

static void tex_aux_undump_hccodes(dumpstream f)
{
    lmt_luscode_state.hccode_head = sa_undump_tree(f);
}

static void tex_aux_free_hccodes(void)
{
    sa_destroy_tree(lmt_luscode_state.hccode_head);
}

/*tex 
    The same is true for math hyphenation but here we have a small options set. 
*/

void tex_set_hm_code(int n, halfword v, int gl)
{
    sa_set_item_1(lmt_luscode_state.hmcode_head, n, v, gl);
}

halfword tex_get_hm_code(int n)
{
    return sa_return_item_1(lmt_luscode_state.hmcode_head, n);
}

static void tex_aux_unsave_hmcodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.hmcode_head, gl);
}

static void tex_aux_initialize_hmcodes(void)
{
    sa_tree_item item = { .int_value = HMCODEDEFAULT };
    lmt_luscode_state.hmcode_head = sa_new_tree(hmcode_sparse_identifier, HMCODESTACK, HMCODESTEP, 1, item);
}

static void tex_aux_dump_hmcodes(dumpstream f)
{
    sa_dump_tree(f, lmt_luscode_state.hmcode_head);
}

static void tex_aux_undump_hmcodes(dumpstream f)
{
    lmt_luscode_state.hmcode_head = sa_undump_tree(f);
}

static void tex_aux_free_hmcodes(void)
{
    sa_destroy_tree(lmt_luscode_state.hmcode_head);
}

/*tex Experiment. */


void tex_set_am_code(int n, halfword v, int gl)
{
    sa_set_item_1(lmt_luscode_state.amcode_head, n, v, gl);
}

halfword tex_get_am_code(int n)
{
    return sa_return_item_1(lmt_luscode_state.amcode_head, n);
}

static void tex_aux_unsave_amcodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.amcode_head, gl);
}

static void tex_aux_initialize_amcodes(void)
{
    sa_tree_item item = { .int_value = AMCODEDEFAULT };
    lmt_luscode_state.amcode_head = sa_new_tree(amcode_sparse_identifier, AMCODESTACK, AMCODESTEP, 1, item);
}

static void tex_aux_dump_amcodes(dumpstream f)
{
    sa_dump_tree(f, lmt_luscode_state.amcode_head);
}

static void tex_aux_undump_amcodes(dumpstream f)
{
    lmt_luscode_state.amcode_head = sa_undump_tree(f);
}

static void tex_aux_free_amcodes(void)
{
    sa_destroy_tree(lmt_luscode_state.amcode_head);
}

/*tex 

    This is not yet used. 

*/

void tex_set_cc_code(int n, halfword v, int gl)
{
    sa_set_item_2(lmt_luscode_state.cccode_head, n, v, gl);
}

halfword tex_get_cc_code(int n)
{
    return sa_return_item_2(lmt_luscode_state.cccode_head, n);
}

static void tex_aux_unsave_cccodes(int gl)
{
    sa_restore_stack(lmt_luscode_state.cccode_head, gl);
}

static void tex_aux_initialize_cccodes(void)
{
    sa_tree_item item = {.int_value = CCCODEDEFAULT };
    lmt_luscode_state.cccode_head = sa_new_tree(lccode_sparse_identifier, CCCODESTACK, CCCODESTEP, 2, item);
}

static void tex_aux_dump_cccodes(dumpstream f)
{
    sa_dump_tree(f, lmt_luscode_state.cccode_head);
}

static void tex_aux_undump_cccodes(dumpstream f)
{
    lmt_luscode_state.cccode_head = sa_undump_tree(f);
}

static void tex_aux_free_cccodes(void)
{
    sa_destroy_tree(lmt_luscode_state.cccode_head);
}

/*tex

    The hyphenation codes are indeed stored in a tree and are used instead of lowercase codes when
    deciding what characters to take into acccount when hyphenating. They are bound to upto
    |HJCODE_MAX| languages. In the end I decided to put the hash pointer in the language record
    so that we can do better lean memory management. Actually, the hjcode handling already was more
    efficient than in \LUATEX\ because I kept track of usage and allocated (dumped) only the
    languages that were used. A typical example of nicely cleaned up code that in the end was
    ditched but that happens often (and of course goes unnoticed). Actually, in \CONTEXT\ we don't
    dump language info at all, so I might as wel drop language dumping, just like fonts.

*/

# define HJCODESTACK   8
# define HJCODESTEP    8
# define HJCODEDEFAULT 0

void tex_set_hj_code(int h, int n, halfword v, int gl)
{
    if (h >= 0 && h <= lmt_language_state.language_data.top) {
        sa_tree_item item = { .int_value = HJCODEDEFAULT };
        sa_tree tree = lmt_language_state.languages[h]->hjcode_head;
        if (! tree) {
            tree = sa_new_tree(hjcode_sparse_identifier, HJCODESTACK, HJCODESTEP, 4, item);
            lmt_language_state.languages[h]->hjcode_head = tree;
        }
        if (tree) {
            item.int_value = (int) v;
            sa_set_item_4(tree, n, item, gl);
        }
    }
}

/*tex We just return the lccodes when nothing is set. */

halfword tex_get_hj_code(int h, int n)
{
    if (h >= 0 && h <= lmt_language_state.language_data.top) {
        sa_tree tree = lmt_language_state.languages[h]->hjcode_head;
        if (! tree) {
            tree = lmt_luscode_state.lccode_head;
        }
        return sa_return_item_4(tree, n);
    } else {
        return 0;
    }
}

void tex_dump_language_hj_codes(dumpstream f, int h)
{
    if (h >= 0 && h <= lmt_language_state.language_data.top) {
        sa_tree tree = lmt_language_state.languages[h]->hjcode_head;
        if (tree) {
            dump_via_uchar(f, 1);
            sa_dump_tree(f, tree);
        } else {
            dump_via_uchar(f, 0);
        }
    } else {
       /* error */
    }
}

void tex_undump_language_hj_codes(dumpstream f, int h)
{
    if (h >= 0 && h <= lmt_language_state.language_data.top) {
        unsigned char marker;
        undump_uchar(f, marker);
        if (marker) {
            sa_free_array(lmt_language_state.languages[h]->hjcode_head);
            lmt_language_state.languages[h]->hjcode_head = sa_undump_tree(f);
        } else {
            lmt_language_state.languages[h]->hjcode_head = NULL;
        }
    } else {
       /* error */
    }
}

void tex_hj_codes_from_lc_codes(int h)
{
    if (h >= 0 && h <= lmt_language_state.language_data.top) {
        sa_tree tree = lmt_language_state.languages[h]->hjcode_head;
        if (tree) {
            sa_destroy_tree(tree);
        }
        tree = sa_copy_tree(lmt_luscode_state.lccode_head);
        lmt_language_state.languages[h]->hjcode_head = tree ? tree : NULL;
    }
}

/*tex The public management functions. */

void tex_unsave_text_codes(int grouplevel)
{
    tex_aux_unsave_lccodes(grouplevel);
    tex_aux_unsave_uccodes(grouplevel);
    tex_aux_unsave_sfcodes(grouplevel);
    tex_aux_unsave_hccodes(grouplevel);
    tex_aux_unsave_hmcodes(grouplevel);
    tex_aux_unsave_amcodes(grouplevel);
    tex_aux_unsave_cccodes(grouplevel);
}

void tex_initialize_text_codes(void)
{
    tex_aux_initialize_catcodes();
    tex_aux_initialize_lccodes();
    tex_aux_initialize_uccodes();
    tex_aux_initialize_sfcodes();
    tex_aux_initialize_hccodes();
    tex_aux_initialize_hmcodes();
    tex_aux_initialize_amcodes();
    tex_aux_initialize_cccodes();
 /* initializehjcodes(); */
}

void tex_free_text_codes(void)
{
    tex_aux_free_catcodes();
    tex_aux_free_lccodes();
    tex_aux_free_uccodes();
    tex_aux_free_sfcodes();
    tex_aux_free_hccodes();
    tex_aux_free_hmcodes();
    tex_aux_free_amcodes();
    tex_aux_free_cccodes();
 /* freehjcodes(); */
}

void tex_dump_text_codes(dumpstream f)
{
    tex_aux_dump_catcodes(f);
    tex_aux_dump_lccodes(f);
    tex_aux_dump_uccodes(f);
    tex_aux_dump_sfcodes(f);
    tex_aux_dump_hccodes(f);
    tex_aux_dump_hmcodes(f);
    tex_aux_dump_amcodes(f);
    tex_aux_dump_cccodes(f);
 /* dumphjcodes(f); */
}

void tex_undump_text_codes(dumpstream f)
{
    tex_aux_undump_catcodes(f);
    tex_aux_undump_lccodes(f);
    tex_aux_undump_uccodes(f);
    tex_aux_undump_sfcodes(f);
    tex_aux_undump_hccodes(f);
    tex_aux_undump_hmcodes(f);
    tex_aux_undump_amcodes(f);
    tex_aux_undump_cccodes(f);
 /* undumphjcodes(f); */
}

void tex_initialize_xx_codes(void)
{
    /*tex We're compatible. */
    for (int u = 'A'; u <= 'Z'; u++) {
        int l = u + 32;
        tex_set_lc_code(u, l, level_one);
        tex_set_lc_code(l, l, level_one);
        tex_set_uc_code(u, u, level_one);
        tex_set_uc_code(l, u, level_one);
        tex_set_sf_code(u, special_space_factor, level_one);
    }
    /*tex A good start but not compatible. */
 /* set_hc_code(0x002D, 0x002D, level_one); */
 /* set_hc_code(0x2010, 0x2010, level_one); */
}

void tex_run_case_shift(halfword code)
{
    int upper = code == upper_case_code;
    halfword l = tex_scan_toks_normal(0, NULL);
    halfword p = token_link(l);
    while (p) {
        halfword t = token_info(p);
        if (t < cs_token_flag) {
            halfword c = t % cs_offset_value;
            halfword i = upper ? tex_get_uc_code(c) : tex_get_lc_code(c);
            if (i) {
                set_token_info(p, t - c + i);
            }
        } else if (tex_is_active_cs(cs_text(t - cs_token_flag))) {
            halfword c = active_cs_value(cs_text(t - cs_token_flag));
            halfword i = upper ? tex_get_uc_code(c) : tex_get_lc_code(c);
            if (i) {
                set_token_info(p, tex_active_to_cs(i, 1) + cs_token_flag);
            }
        }
        p = token_link(p);
    }
    if (token_link(l)) {
        tex_begin_backed_up_list(token_link(l));
    }
    tex_put_available_token(l);
}

/*tex
    Maybe some day: |sparse_identifier|, |fontchar_identifier|, |mathfont_identifier| and/or 
    |mathparam_identifier|.
*/

void tex_show_code_stack()
{
    sa_tree head = NULL;
    tex_get_token();
    switch (cur_cmd) { 
        case define_char_code_cmd:
            switch (cur_chr) {
                case amcode_charcode: 
                    head = lmt_luscode_state.amcode_head; 
                    break;
                case cccode_charcode: 
                    head = lmt_luscode_state.cccode_head; 
                    break;
                case catcode_charcode: 
                    if (cat_code_table_par >= 0 && cat_code_table_par < max_n_of_catcode_tables) {
                        head = lmt_catcode_state.catcode_heads[cat_code_table_par];
                    }
                    break;   
                case delcode_charcode: 
                case extdelcode_charcode: 
                    /* maybe */
                    break;
                case hccode_charcode: 
                    head = lmt_luscode_state.hccode_head; 
                    break;    
                case hmcode_charcode: 
                    head = lmt_luscode_state.hmcode_head; 
                    break;    
                case lccode_charcode: 
                    head = lmt_luscode_state.lccode_head; 
                    break;    
                case mathcode_charcode:
                case extmathcode_charcode: 
                    /* maybe */
                    break;
                case sfcode_charcode     : 
                    head = lmt_luscode_state.sfcode_head; 
                    break;    
                case uccode_charcode     : 
                    head = lmt_luscode_state.uccode_head; 
                    break;    
            }
            break;
        case internal_integer_cmd: 
            switch (cur_chr) {
                case cat_code_table_code:
                    if (cat_code_table_par >= 0 && cat_code_table_par < max_n_of_catcode_tables) {
                        head = lmt_catcode_state.catcode_heads[cat_code_table_par];
                    }
            }
            break;
        case hyphenation_cmd:
            switch (cur_chr) {
                case hjcode_code: 
                    if (language_par >= 0 && language_par <= lmt_language_state.language_data.top) {
                        head = lmt_language_state.languages[language_par]->hjcode_head;
                    }
                    break;
            }
            break;
    }
    if (head) {
        sa_show_stack(head);
    }
}

