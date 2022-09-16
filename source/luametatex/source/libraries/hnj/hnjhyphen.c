/*
    See license.txt in the root of this project.
*/

/*

    This file is derived from libhnj which is is dual licensed under LGPL and MPL. Boilerplate
    for both licenses follows.

    LibHnj - a library for high quality hyphenation and justification

    (C) 1998 Raph Levien,
    (C) 2001 ALTLinux, Moscow (http://www.alt-linux.org),
    (C) 2001 Peter Novodvorsky (nidd@cs.msu.su)

    This library is free software; you can redistribute it and/or modify it under the terms of the
    GNU Library General Public License as published by the Free Software Foundation; either version
    2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
    without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
    the GNU Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License along with this
    library; if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA 02111-1307 USA.

    The contents of this file are subject to the Mozilla Public License Version 1.0 (the "MPL");
    you may not use this file except in compliance with the MPL. You may obtain a copy of the MPL
    at http://www.mozilla.org/MPL/

    Software distributed under the MPL is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
    KIND, either express or implied. See the MPL for the specific language governing rights and
    limitations under the MPL.

    Remark: I'm not sure if something fundamental was adapted in the perspective of using this
    library in LuaTeX. However, for instance error reporting has been hooked into the Lua(Meta)TeX
    error reporting mechanisms. Also a bit of reformatting was done. This module won't change.
    Also, the code has been adapted a little in order to fit in the rest (function names etc)
    because it is more exposed. We use the alternative memory allocator.

*/

/*tex We need the warning subsystem, so: */

# include "luametatex.h"

/*tex A few helpers (from |hnjalloc|): */

static void *hnj_malloc(int size)
{
    void *p = lmt_memory_malloc((size_t) size);
    if (! p) {
        tex_formatted_error("hyphenation", "allocating %d bytes failed\n", size);
    }
    return p;
}

static void *hnj_realloc(void *p, int size)
{
    void *n = lmt_memory_realloc(p, (size_t) size);
    if (! n) {
        tex_formatted_error("hyphenation", "reallocating %d bytes failed\n", size);
    }
    return n;
}

static void hnj_free(void *p)
{
    lmt_memory_free(p);
}

static unsigned char *hnj_strdup(const unsigned char *s)
{
    size_t l = strlen((const char *) s);
    unsigned char *n = hnj_malloc((int) l + 1);
    memcpy(n, s, l);
    n[l] = 0;
    return n;
}

/*tex

    Combine two right-aligned number patterns, 04000 + 020 becomes 04020. This works also for utf8
    sequences because the substring is identical to the last |substring - length| bytes of expr
    except for the (single byte) hyphenation encoders

*/

static char *combine_patterns(char *expr, const char *subexpr)
{
    size_t l1 = strlen(expr);
    size_t l2 = strlen(subexpr);
    size_t off = l1 - l2;
    for (unsigned j = 0; j < l2; j++) {
        if (expr[off + j] < subexpr[j]) {
            expr[off + j] = subexpr[j];
        }
    }
    return expr;
}

/*tex Some original code: */

static hjn_hashiterator *new_hashiterator(hjn_hashtable *h)
{
    hjn_hashiterator *i = hnj_malloc(sizeof(hjn_hashiterator));
    i->e = h->entries;
    i->cur = NULL;
    i->ndx = -1;
    return i;
}

static int nexthashstealpattern(hjn_hashiterator *i, unsigned char **word, char **pattern)
{
    while (i->cur == NULL) {
        if (i->ndx >= HNJ_HASH_SIZE - 1) {
            return 0;
        } else {
            i->cur = i->e[++i->ndx];
        }
    }
    *word = i->cur->key;
    *pattern = i->cur->u.hyppat;
    i->cur->u.hyppat = NULL;
    i->cur = i->cur->next;
    return 1;
}

static int nexthash(hjn_hashiterator *i, unsigned char **word)
{
    while (! i->cur) {
        if (i->ndx >= HNJ_HASH_SIZE - 1) {
            return 0;
        } else {
            i->cur = i->e[++i->ndx];
        }
    }
    *word = i->cur->key;
    i->cur = i->cur->next;
    return 1;
}

static int eachhash(hjn_hashiterator *i, unsigned char **word, char **pattern)
{
    while (! i->cur) {
        if (i->ndx >= HNJ_HASH_SIZE - 1) {
            return 0;
        } else {
            i->cur = i->e[++i->ndx];
        }
    }
    *word = i->cur->key;
    *pattern = i->cur->u.hyppat;
    i->cur = i->cur->next;
    return 1;
}

static void delete_hashiterator(hjn_hashiterator *i)
{
    hnj_free(i);
}

/*tex A |char*| hash function from ASU, adapted from |Gtk+|: */

static unsigned int string_hash(const unsigned char *s)
{
    const unsigned char *p = s;
    unsigned int h = 0, g;
    for (; *p != '\0'; p += 1) {
        h = (h << 4) + *p;
        g = h & 0xf0000000;
        if (g) {
            h = h ^ (g >> 24);
            h = h ^ g;
        }
    }
    return h;
}

/*tex This assumes that key is not already present! */

static void state_insert(hjn_hashtable *hashtab, unsigned char *key, int state)
{
    int i = (int) (string_hash(key) % HNJ_HASH_SIZE);
    hjn_hashentry* e = hnj_malloc(sizeof(hjn_hashentry));
    e->next = hashtab->entries[i];
    e->key = key;
    e->u.state = state;
    hashtab->entries[i] = e;
}

/*tex This also assumes that key is not already present! */

static void insert_pattern(hjn_hashtable *hashtab, unsigned char *key, char *hyppat, int trace)
{
    hjn_hashentry *e;
    int i = (int) (string_hash(key) % HNJ_HASH_SIZE);
    for (e = hashtab->entries[i]; e; e = e->next) {
        if (strcmp((char *) e->key, (char *) key) == 0) {
            if (e->u.hyppat) {
                if (trace && hyppat && strcmp((char *) e->u.hyppat, (char *) hyppat) != 0) {
                    tex_formatted_warning("hyphenation", "a conflicting pattern '%s' has been ignored", hyppat);
                }
                hnj_free(e->u.hyppat);
            }
            e->u.hyppat = hyppat;
            hnj_free(key);
            return;
        }
    }
    e = hnj_malloc(sizeof(hjn_hashentry));
    e->next = hashtab->entries[i];
    e->key = key;
    e->u.hyppat = hyppat;
    hashtab->entries[i] = e;
}

/*tex We return |state| if found, otherwise |-1|. */

static int state_lookup(hjn_hashtable *hashtab, const unsigned char *key)
{
    int i = (int) (string_hash(key) % HNJ_HASH_SIZE);
    for (hjn_hashentry *e = hashtab->entries[i]; e; e = e->next) {
        if (! strcmp((const char *) key, (const char *) e->key)) {
            return e->u.state;
        }
    }
    return -1;
}

/*tex We return |state| if found, otherwise |-1|. The 256 should be enough. */

static char *lookup_pattern(hjn_hashtable * hashtab, const unsigned char *chars, int l)
{
    int i;
    unsigned char key[256];
    strncpy((char *) key, (const char *) chars, (size_t) l);
    key[l] = 0;
    i = (int) (string_hash(key) % HNJ_HASH_SIZE);
    for (hjn_hashentry *e = hashtab->entries[i]; e; e = e->next) {
        if (! strcmp((char *) key, (char *) e->key)) {
            return e->u.hyppat;
        }
    }
    return NULL;
}

/*tex Get the state number, allocating a new state if necessary. */

static int hnj_get_state(hjn_dictionary *dict, const unsigned char *str, int *state_num)
{
    *state_num = state_lookup(dict->state_num, str);
    if (*state_num >= 0) {
        return *state_num;
    } else {
        state_insert(dict->state_num, hnj_strdup(str), dict->num_states);
        /*tex The predicate is true if |dict->num_states| is a power of two: */
        if (! (dict->num_states & (dict->num_states - 1))) {
            dict->states = hnj_realloc(dict->states, (int) ((dict->num_states << 1) * (int) sizeof(hjn_state)));
        }
        dict->states[dict->num_states] = (hjn_state) { .match = NULL, .fallback_state = -1, .num_trans = 0, .trans = NULL };
        return dict->num_states++;
    }
}

/*tex

    Add a transition from state1 to state2 through ch - assumes that the transition does not
    already exist.

*/

static void hnj_add_trans(hjn_dictionary *dict, int state1, int state2, int chr)
{
    /*tex

        This test was a bit too strict, it is quite normal for old patterns to have chars in the
        range 0-31 or 127-159 (inclusive). To ease the transition, let's only disallow |nul| for
        now, which probably is a requirement of the code anyway.

    */
    if (chr) {
        int num_trans = dict->states[state1].num_trans;
        if (num_trans == 0) {
            dict->states[state1].trans = hnj_malloc(sizeof(hjn_transition));
        } else {
            /*tex

                The old version did:

                \starttyping
                } else if (!(num_trans & (num_trans - 1))) {
                    ... = hnj_realloc(dict->states[state1].trans,
                            (int) ((num_trans << 1) * sizeof(HyphenTrans)));
                \stoptyping

                but that is incredibly nasty when adding patters one-at-a-time. Controlled growth
                would be nicer than the current +1, but if no one complains, and no one did in a
                decade, this is good enough.

            */
            dict->states[state1].trans = hnj_realloc(dict->states[state1].trans, (int) ((num_trans + 1) * sizeof(hjn_transition)));
        }
        dict->states[state1].trans[num_trans].uni_ch = chr;
        dict->states[state1].trans[num_trans].new_state = state2;
        dict->states[state1].num_trans++;
    } else {
        tex_normal_error("hyphenation","a nul character is not permited");
    }
}

/*tex

    We did change the semantics a bit here: |hnj_hyphen_load| used to operate on a file, but now
    the argument is a string buffer.

*/

/* define tex_isspace(c) (c == ' ' || c == '\t') */
#  define tex_isspace(c) (c == ' ')

static const unsigned char *next_pattern(size_t* length, const unsigned char** buf)
{
    const unsigned char *here, *rover = *buf;
    while (*rover && tex_isspace(*rover)) {
        rover++;
    }
    here = rover;
    while (*rover) {
        if (tex_isspace(*rover)) {
            *length = (size_t) (rover - here);
            *buf = rover;
            return here;
        } else {
            rover++;
        }
    }
    *length = (size_t) (rover - here);
    *buf = rover;
    return *length ? here : NULL;
}

static void init_hash(hjn_hashtable **h)
{
    if (! *h) {
        *h = hnj_malloc(sizeof(hjn_hashtable));
        for (int i = 0; i < HNJ_HASH_SIZE; i++) {
            (*h)->entries[i] = NULL;
        }
    }
}

static void clear_state_hash(hjn_hashtable **h)
{
    if (*h) {
        for (int i = 0; i < HNJ_HASH_SIZE; i++) {
            hjn_hashentry *e, *next;
            for (e = (*h)->entries[i]; e; e = next) {
                next = e->next;
                hnj_free(e->key);
                hnj_free(e);
            }
        }
        hnj_free(*h);
        *h = NULL;
    }
}

static void clear_pattern_hash(hjn_hashtable **h)
{
    if (*h) {
        for (int i = 0; i < HNJ_HASH_SIZE; i++) {
            hjn_hashentry *e, *next;
            for (e = (*h)->entries[i]; e; e = next) {
                next = e->next;
                hnj_free(e->key);
                if (e->u.hyppat) {
                    hnj_free(e->u.hyppat);
                }
                hnj_free(e);
            }
        }
        hnj_free(*h);
        *h = NULL;
    }
}

static void init_dictionary(hjn_dictionary *dict)
{
    dict->num_states = 1;
    dict->pat_length = 0;
    dict->states = hnj_malloc(sizeof(hjn_state));
    dict->states[0] = (hjn_state) { .match = NULL, .fallback_state = -1, .num_trans = 0, .trans = NULL };
    dict->patterns = NULL;
    dict->merged = NULL;
    dict->state_num = NULL;
    init_hash(&dict->patterns);
}

static void clear_dictionary(hjn_dictionary *dict)
{
    for (int state_num = 0; state_num < dict->num_states; state_num++) {
        hjn_state *hstate = &dict->states[state_num];
        if (hstate->match) {
            hnj_free(hstate->match);
        }
        if (hstate->trans) {
            hnj_free(hstate->trans);
        }
    }
    hnj_free(dict->states);
    clear_pattern_hash(&dict->patterns);
    clear_pattern_hash(&dict->merged);
    clear_state_hash(&dict->state_num);
}

hjn_dictionary *hnj_dictionary_new(void)
{
    hjn_dictionary *dict = hnj_malloc(sizeof(hjn_dictionary));
    init_dictionary(dict);
    return dict;
}

void hnj_dictionary_clear(hjn_dictionary *dict)
{
    clear_dictionary(dict);
    init_dictionary(dict);
}

void hnj_dictionary_free(hjn_dictionary *dict)
{
    clear_dictionary(dict);
    hnj_free(dict);
}

unsigned char *hnj_dictionary_tostring(hjn_dictionary *dict)
{
    unsigned char *word;
    char *pattern;
    unsigned char *buf = hnj_malloc(dict->pat_length);
    unsigned char *cur = buf;
    hjn_hashiterator *v = new_hashiterator(dict->patterns);
    while (eachhash(v, &word, &pattern)) {
        int i = 0;
        int e = 0;
        while (word[e + i]) {
            if (pattern[i] != '0') {
                *cur++ = (unsigned char) pattern[i];
            }
            *cur++ = word[e + i++];
            while (is_utf8_follow(word[e + i])) {
                *cur++ = word[i + e++];
            }
        }
        if (pattern[i] != '0') {
            *cur++ = (unsigned char) pattern[i];
        }
        *cur++ = ' ';
    }
    delete_hashiterator(v);
    *cur = 0;
    return buf;
}

/*tex

    In hyphenation patterns we use signed bytes where |0|, or actually any negative number,
    indicates end:

    \starttyping
    prio(1+),startpos,length,len1,[replace],len2,[replace]
    \starttyping

    A basic example is:

    \starttyping
    p n 0 0 0
    \starttyping

    for a hyphenation point between characters.

*/

void hnj_dictionary_load(hjn_dictionary *dict, const unsigned char *f, int trace)
{
    int state_num, last_state;
    int ch;
    int found;
    hjn_hashiterator *v;
    unsigned char *word;
    char *pattern;
    size_t l = 0;
    const unsigned char *format;
    const unsigned char *begin = f;
    while ((format = next_pattern(&l, &f)) != NULL) {
        if (l > 0 && l < 255) {
            int i, j, e1;
            for (i = 0, j = 0, e1 = 0; (unsigned) i < l; i++) {
                if (format[i] >= '0' && format[i] <= '9') {
                    j++;
                }
                if (is_utf8_follow(format[i])) {
                    e1++;
                }
            }
            /*tex
                Here |l-e1| is the number of {\em characters} not {\em bytes}, |l-j| the number of
                pattern bytes and |l-e1-j| the number of pattern characters.
            */
            {
                unsigned char *pat = (unsigned char *) hnj_malloc((1 + (int) l - j));
                char *org = (char *) hnj_malloc(2 + (int) l - e1 - j);
                /*tex Remove hyphenation encoders (digits) from pat. */
                org[0] = '0';
                for (i = 0, j = 0, e1 = 0; (unsigned) i < l; i++) {
                    unsigned char c = format[i];
                    if (is_utf8_follow(c)) {
                        pat[j + e1++] = c;
                    } else if (c < '0' || c > '9') {
                        pat[e1 + j++] = c;
                        org[j] = '0';
                    } else {
                        org[j] = (char) c;
                    }
                }
                pat[e1 + j] = 0;
                org[j + 1] = 0;
                insert_pattern(dict->patterns, pat, org, trace);
            }
        } else {
           tex_normal_warning("hyphenation", "a pattern of more than 254 bytes is ignored");
        }
    }
    /*tex We add 2 bytes for spurious spaces. */
    dict->pat_length += (int) ((f - begin) + 2);
    init_hash(&dict->merged);
    v = new_hashiterator(dict->patterns);
    while (nexthash(v, &word)) {
        int wordsize = (int) strlen((char *) word);
        for (int l1 = 1; l1 <= wordsize; l1++) {
            if (is_utf8_follow(word[l1])) {
                /*tex Do not clip an utf8 sequence. */
            } else {
                for (int j1 = 1; j1 <= l1; j1++) {
                    int i1 = l1 - j1;
                    if (is_utf8_follow(word[i1])) {
                        /*tex Do not start halfway an utf8 sequence. */
                    } else {
                        char *subpat_pat = lookup_pattern(dict->patterns, word + i1, j1);
                        if (subpat_pat) {
                            char *newpat_pat = lookup_pattern(dict->merged, word, l1);
                            if (! newpat_pat) {
                                char *neworg;
                                unsigned char *newword = (unsigned char *) hnj_malloc((size_t) (l1 + 1));
                                int e1 = 0;
                                strncpy((char *) newword, (char *) word, (size_t) l1);
                                newword[l1] = 0;
                                for (i1 = 0; i1 < l1; i1++) {
                                    if (is_utf8_follow(newword[i1])) {
                                        e1++;
                                    }
                                }
                                neworg = hnj_malloc((size_t) (l1 + 2 - e1));
                                /*tex Fill with right amount of zeros: */
                                sprintf(neworg, "%0*d", l1 + 1 - e1, 0);
                                insert_pattern(dict->merged, newword, combine_patterns(neworg, subpat_pat), trace);
                            } else {
                                combine_patterns(newpat_pat, subpat_pat);
                            }
                        }
                    }
                }
            }
        }
    }
    delete_hashiterator(v);
    init_hash(&dict->state_num);
    state_insert(dict->state_num, hnj_strdup((const unsigned char *) ""), 0);
    v = new_hashiterator(dict->merged);
    while (nexthashstealpattern(v, &word, &pattern)) {
        static unsigned char mask[] = { 0x3F, 0x1F, 0xF, 0x7 };
        int j1 = (int) strlen((char *) word);
        state_num = hnj_get_state(dict, word, &found);
        dict->states[state_num].match = pattern;
        /*tex Now, put in the prefix transitions. */
        while (found < 0) {
            j1--;
            last_state = state_num;
            ch = word[j1];
            if (ch >= 0x80) { /* why not is_utf8_follow(ch) here */
                int m;
                int i1 = 1;
                while (is_utf8_follow(word[j1 - i1])) {
                    i1++;
                }
                ch = word[j1 - i1] & mask[i1];
                m = j1 - i1;
                while (i1--) {
                    ch = (ch << 6) + (0x3F & word[j1 - i1]);
                }
                j1 = m;
            }
            word[j1] = '\0';
            state_num = hnj_get_state(dict, word, &found);
            hnj_add_trans(dict, state_num, last_state, ch);
        }
    }
    delete_hashiterator(v);
    clear_pattern_hash(&dict->merged);
    /*tex Put in the fallback states. */
    for (int i = 0; i < HNJ_HASH_SIZE; i++) {
        for (hjn_hashentry *e = dict->state_num->entries[i]; e; e = e->next) {
            /*tex Do not do |state == 0| otherwise things get confused. */
            if (e->u.state) {
                for (int j = 1; 1; j++) {
                    state_num = state_lookup(dict->state_num, e->key + j);
                    if (state_num >= 0) {
                        break;
                    }
                }
                dict->states[e->u.state].fallback_state = state_num;
            }
        }
    }
    clear_state_hash(&dict->state_num);
}
