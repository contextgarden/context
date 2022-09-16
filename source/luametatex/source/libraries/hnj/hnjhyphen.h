/*
    See license.txt in the root of this project.
*/

/*

    The code is derived from LibHnj which is is dual licensed under LGPL and MPL. Boilerplate for
    both licenses follows.

*/

/*

    LibHnj - a library for high quality hyphenation and justification

    Copyright (C) 1998 Raph Levien, (C) 2001 ALTLinux, Moscow

    This library is free software; you can redistribute it and/or modify it under the terms of the
    GNU Library General Public License as published by the Free Software Foundation; either version
    2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
    without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
    the GNU Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License along with this
    library; if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA 02111-1307 USA.

*/

/*
    The contents of this file are subject to the Mozilla Public License Version 1.0 (the "MPL");
    you may not use this file except in compliance with the MPL. You may obtain a copy of the MPL
    at http://www.mozilla.org/MPL/

    Software distributed under the MPL is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
    KIND, either express or implied. See the MPL for the specific language governing rights and
    limitations under the MPL.

 */

# ifndef LMT_HNJHYPHEN_H
# define LMT_HNJHYPHEN_H

/*tex

    First some type definitions and a little bit of a hash table implementation. This simply maps
    strings to state numbers. In \LUATEX\ we have node related code in |hnjhyphen.c| but in
    \LUAMETATEX\ we moved that to |texlanguage.c| so we need to make some type definitions public.

*/

# define HNJ_MAXPATHS  40960
# define HNJ_HASH_SIZE 31627
# define HNJ_MAX_CHARS   256
# define HNJ_MAX_NAME     24

typedef struct _hjn_hashtable    hjn_hashtable;
typedef struct _hjn_hashentry    hjn_hashentry;
typedef struct _hjn_hashiterator hjn_hashiterator;
typedef union  _hjn_hashvalue    hjn_hashvalue;

/*tex A cheap, but effective, hack. */

struct _hjn_hashtable {
    hjn_hashentry *entries[HNJ_HASH_SIZE];
};

union _hjn_hashvalue {
    char *hyppat;
    int   state;
    int   padding;
};

struct _hjn_hashentry {
    hjn_hashentry *next;
    unsigned char *key;
    hjn_hashvalue  u;
};

struct _hjn_hashiterator {
    hjn_hashentry **e;
    hjn_hashentry  *cur;
    int             ndx;
    int             padding;
};

/*tex The state state machine. */

typedef struct _hjn_transition hjn_transition;
typedef struct _hjn_state      hjn_state;
typedef struct _hjn_dictionary hjn_dictionary;

struct _hjn_transition {
    int uni_ch;
    int new_state;
};

struct _hjn_state {
    char           *match;
    int             fallback_state;
    int             num_trans;
    hjn_transition *trans;
};

struct _hjn_dictionary {
    int            num_states;
    int            pat_length;
    char           cset[HNJ_MAX_NAME];
    hjn_state     *states;
    hjn_hashtable *patterns;
    hjn_hashtable *merged;
    hjn_hashtable *state_num;
};

extern hjn_dictionary *hnj_dictionary_new      (void);
extern void            hnj_dictionary_load     (hjn_dictionary *dict, const unsigned char *fn, int trace);
extern void            hnj_dictionary_free     (hjn_dictionary *dict);
extern void            hnj_dictionary_clear    (hjn_dictionary *dict);
extern unsigned char  *hnj_dictionary_tostring (hjn_dictionary *dict);

# endif
