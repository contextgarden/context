/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    Control sequences are stored and retrieved by means of a fairly standard hash table algorithm
    called the method of \quote {coalescing lists} (cf.\ Algorithm 6.4C in {\em The Art of
    Computer Programming}). Once a control sequence enters the table, it is never removed, because
    there are complicated situations involving |\gdef| where the removal of a control sequence at
    the end of a group would be a mistake preventable only by the introduction of a complicated
    reference-count mechanism.

    The actual sequence of letters forming a control sequence identifier is stored in the |str_pool|
    array together with all the other strings. An auxiliary array |hash| consists of items with two
    halfword fields per word. The first of these, called |next(p)|, points to the next identifier
    belonging to the same coalesced list as the identifier corresponding to~|p|; and the other,
    called |text(p)|, points to the |str_start| entry for |p|'s identifier. If position~|p| of the
    hash table is empty, we have |text(p)=0|; if position |p| is either empty or the end of a
    coalesced hash list, we have |next(p) = 0|. An auxiliary pointer variable called |hash_used| is
    maintained in such a way that all locations |p >= hash_used| are nonempty. The global variable
    |cs_count| tells how many multiletter control sequences have been defined, if statistics are
    being kept.

    A boolean variable called |no_new_control_sequence| is set to |true| during the time that new
    hash table entries are forbidden.

    The other variables in the following state structure are: the hash table: |hash|, the allocation
    pointer |hash_used| for |hash|, |hash_extra| above |eqtb_size|, the maximum of the hash array
    |hash_top|, the pointer to the next high hash location |hash_high|, the mentioned flag that says
    if new identifiers are legal |no_new_control_sequence| and the total number of known identifiers:
    |cs_count|.

*/

hash_state_info lmt_hash_state = {
    .hash      = NULL,
    .hash_data = {
        .minimum   = min_hash_size,
        .maximum   = max_hash_size,
        .size      = siz_hash_size,
        .step      = stp_hash_size,
        .allocated = 0,
        .itemsize  = sizeof(memoryword) + sizeof(memoryword),
        .top       = 0,
        .ptr       = 0,
        .initial   = 0,
        .offset    = 0, // eqtb_size,
    },
    .eqtb_data = {
        .minimum   = min_hash_size,
        .maximum   = max_hash_size,
        .size      = siz_hash_size,
        .step      = stp_hash_size,
        .allocated = memory_data_unset,
        .itemsize  = memory_data_unset,
        .top       = frozen_control_sequence,
        .ptr       = 0,
        .initial   = 0,
        .offset    = 0,
    },
    .eqtb      = NULL,
    .no_new_cs = 1,
    .padding   = 0,
};

/*tex

    The arrays |prim| and |prim_eqtb| are used for |name -> cmd, chr| lookups. The are modelled
    after |hash| and |eqtb|, except that primitives do not have an |eq_level|, that field is
    replaced by |origin|. Furthermore we have a link for coalesced lists: |prim_next (a)|; the
    string number for control sequence name: |prim_text (a)|; test if all positions are occupied:
    |prim_is_full|; some fields: |prim_origin_field (a)|, |prim_eq_type_field (a)| and
    |prim_equiv_field(a)|; the level of definition: |prim_origin (a)|; the command code for
    equivalent: |prim_eq_type(a)|; the equivalent value: |prim_equiv(a)|; the allocation pointer
    for |prim|: |prim_used|; the primitives tables: |two_halves prim [(prim_size + 1)]| and
    |memoryword prim_eqtb [(prim_size + 1)]|. The array |prim_data| works the other way around, it
    is used for |cmd, chr| to name lookups.

*/

primitive_state_info lmt_primitive_state;

/*tex Test if all positions are occupied: */

# define prim_base           1
# define reserved_hash_slots 1

/*tex Initialize the memory arrays: */

void tex_initialize_primitives(void)
{
    memset(lmt_primitive_state.prim_data, 0, sizeof(prim_info)  * (last_cmd  + 1));
    memset(lmt_primitive_state.prim,      0, sizeof(memoryword) * (prim_size + 1));
    memset(lmt_primitive_state.prim_eqtb, 0, sizeof(memoryword) * (prim_size + 1));
    for (int k = 0; k <= prim_size; k++) {
        prim_eq_type(k) = undefined_cs_cmd;
    }
    lmt_primitive_state.prim_used = prim_size;
}

void tex_initialize_hash_mem(void)
{
    if (lmt_main_state.run_state == initializing_state) {
        if (lmt_hash_state.hash_data.minimum == 0) {
            tex_emergency_message("startup error", "you need at least some hash size");
        } else {
            lmt_hash_state.hash_data.allocated = lmt_hash_state.hash_data.minimum;
            lmt_hash_state.hash_data.top = eqtb_size + lmt_hash_state.hash_data.minimum;
        }
    }
    {
        int size = lmt_hash_state.hash_data.top + 1;
        memoryword *hash = aux_allocate_clear_array(sizeof(memoryword), size, reserved_hash_slots);
        memoryword *eqtb = aux_allocate_clear_array(sizeof(memoryword), size, reserved_hash_slots);
        if (hash && eqtb) {
            lmt_hash_state.hash = hash;
            lmt_hash_state.eqtb = eqtb;
            if (lmt_main_state.run_state == initializing_state) {
                /*tex Initialization happens elsewhere. */
            } else {
                tex_initialize_undefined_cs();
                for (int i = eqtb_size + 1; i <= lmt_hash_state.hash_data.top; i++) {
                    copy_eqtb_entry(i, undefined_control_sequence);
                }
            }
        } else {
            tex_overflow_error("hash", size);
        }
    }
}

static int tex_aux_room_in_hash(void)
{
    if (lmt_hash_state.hash_data.allocated + lmt_hash_state.hash_data.step <= lmt_hash_state.hash_data.size) {
        int size = lmt_hash_state.hash_data.top + lmt_hash_state.hash_data.step + 1;
        memoryword *hash = aux_reallocate_array(lmt_hash_state.hash, sizeof(memoryword), size, reserved_hash_slots);
        memoryword *eqtb = aux_reallocate_array(lmt_hash_state.eqtb, sizeof(memoryword), size, reserved_hash_slots);
        if (hash && eqtb) {
            memset(hash + lmt_hash_state.hash_data.top + 1, 0, sizeof(memoryword) * (size_t) lmt_hash_state.hash_data.step);
            memset(eqtb + lmt_hash_state.hash_data.top + 1, 0, sizeof(memoryword) * (size_t) lmt_hash_state.hash_data.step);
            lmt_hash_state.hash = hash;
            lmt_hash_state.eqtb = eqtb;
            /*tex
                This is not really needed because we now dp this when a new id is created which
                is a better place anyway. But we play safe and still do it:
            */
            for (int i = lmt_hash_state.hash_data.top + 1; i <= size; i++) {
                copy_eqtb_entry(i, undefined_control_sequence);
            }
            lmt_hash_state.hash_data.allocated += lmt_hash_state.hash_data.step;
            lmt_hash_state.hash_data.top += lmt_hash_state.hash_data.step;
            lmt_run_memory_callback("hash", 1);
            return 1;
        } else {
            lmt_run_memory_callback("hash", 0);
            tex_overflow_error("hash", size);
        }
    }
    return 0;
}

/*tex

    The value of |hash_prime| should be roughly 85\%! of |hash_size|, and it should be a prime
    number. The theory of hashing tells us to expect fewer than two table probes, on the average,
    when the search is successful. [See J.~S. Vitter, {\sl Journal of the ACM\/ \bf30} (1983),
    231--258.]

    https://en.wikipedia.org/wiki/Coalesced_hashing

    Because we seldom use uppercase we get many misses, multiplying a chr j[k] by k actually gives
    a better spread.

    Making a \CONTEXT\ format takes some 250.000 hash calculations while the \LUAMETATEX\ needs
    some 1.7 million for just over 250 pages (with an average string length of 15).

    The primitive hash lookups are needed when we initialize and when we lookup an internal
    variable.

*/

inline static halfword tex_aux_compute_hash(const char *j, int l)
{
    halfword h = (unsigned const char) j[0];
    for (unsigned k = 1; k < l; k++) {
        h = (h + h + (unsigned const char) j[k]) % hash_prime;
    }
    return h;
}

inline static halfword tex_aux_compute_prim(const char *j, unsigned l)
{
    halfword h = (unsigned const char) j[0];
    for (unsigned k = 1; k < l; k++) {
        h = (h + h + (unsigned const char) j[k]) % prim_prime;
    }
    return h;
}

halfword tex_prim_lookup(strnumber s)
{
    /*tex The index in the |hash| array: */
    if (s >= cs_offset_value) {
        unsigned char *j = str_string(s);
        unsigned l = (unsigned) str_length(s);
        halfword h = tex_aux_compute_prim((char *) j, l);
        /*tex We start searching here; note that |0 <= h < hash_prime|. */
        halfword p = h + 1;
        while (1) {
            if (prim_text(p) > 0 && str_length(prim_text(p)) == l && tex_str_eq_str(prim_text(p), s)) {
                return p;
            } else if (prim_next(p)) {
                p = prim_next(p);
            } else if (lmt_hash_state.no_new_cs) {
                return undefined_primitive;
            } else {
                /*tex Insert a new primitive after |p|, then make |p| point to it. */
                if (prim_text(p) > 0) {
                    /*tex Search for an empty location in |prim| */
                    do {
                        if (lmt_primitive_state.prim_used > prim_base) {
                            --lmt_primitive_state.prim_used;
                        } else {
                            tex_overflow_error("primitive size", prim_size);
                        }
                    } while (prim_text(lmt_primitive_state.prim_used));
                    prim_next(p) = lmt_primitive_state.prim_used;
                    p = lmt_primitive_state.prim_used;
                }
                prim_text(p) = s;
                break;
            }
        }
        return p;
    } else if ((s < 0) || (s == undefined_control_sequence)) {
        return undefined_primitive;
    } else {
        return s;
    }
}

/*tex How to test a csname for primitive-ness? */

/*
int tex_cs_is_primitive(strnumber csname)
{
    int m = prim_lookup(csname);
    if (m != undefined_primitive) {
        char *ss = makecstring(csname);
        int n = string_locate(ss, str_length(csname), 0);
        lmt_memory_free(ss);
        return ((n != undefined_cs_cmd) && (eq_type(n) == prim_eq_type(m)) && (eq_value(n) == prim_equiv(m)));
    } else {
        return 0;
    }
}
*/

/*tex Dumping and undumping. */

/* We cheat! It should be dump_things(f, prim_state.prim[p], 1); */

void tex_dump_primitives(dumpstream f)
{
    /*
    for (int p = 0; p <= prim_size; p++) {
        dump_mem(f, prim_state.prim[p]);
    }
    for (int p = 0; p <= prim_size; p++) {
        dump_mem(f, prim_state.prim_eqtb[p]);
    }
    */
    dump_things(f, lmt_primitive_state.prim[0], prim_size + 1);
    dump_things(f, lmt_primitive_state.prim_eqtb[0], prim_size + 1);
    for (int p = 0; p <= last_cmd; p++) {
        dump_int(f, lmt_primitive_state.prim_data[p].offset);
        dump_int(f, lmt_primitive_state.prim_data[p].subids);
        for (int q = 0; q < lmt_primitive_state.prim_data[p].subids; q++) {
            dump_int(f, lmt_primitive_state.prim_data[p].names[q]);
        }
    }
}

void tex_undump_primitives(dumpstream f)
{
    undump_things(f, lmt_primitive_state.prim[0], prim_size + 1);
    undump_things(f, lmt_primitive_state.prim_eqtb[0], prim_size + 1);
    for (int p = 0; p <= last_cmd; p++) {
        undump_int(f, lmt_primitive_state.prim_data[p].offset);
        undump_int(f, lmt_primitive_state.prim_data[p].subids);
        if (lmt_primitive_state.prim_data[p].subids > 0) {
            int size = lmt_primitive_state.prim_data[p].subids;
            strnumber *names = aux_allocate_clear_array(sizeof(strnumber *), size, 1);
            if (names) {
                lmt_primitive_state.prim_data[p].names = names;
                for (int q = 0; q < lmt_primitive_state.prim_data[p].subids; q++) {
                    undump_int(f, names[q]);
                }
            } else {
                tex_overflow_error("primitives", size * sizeof(strnumber *));
            }
        }
    }
}

/*tex

    Dump the hash table, A different scheme is used to compress the hash table, since its lower
    region is usually sparse. When |text (p) <> 0| for |p <= hash_used|, we output two words,
    |p| and |hash[p]|. The hash table is, of course, densely packed for |p >= hash_used|, so the
    remaining entries are output in a~block.

*/

void tex_dump_hashtable(dumpstream f)
{
    dump_int(f, lmt_hash_state.eqtb_data.top);
    lmt_hash_state.eqtb_data.ptr = frozen_control_sequence - 1 - lmt_hash_state.eqtb_data.top + lmt_hash_state.hash_data.ptr;
    /* the root entries, i.e. the direct hash slots */
    for (halfword p = hash_base; p <= lmt_hash_state.eqtb_data.top; p++) {
        if (cs_text(p)) {
            dump_int(f, p);
            dump_int(f, lmt_hash_state.hash[p]);
            ++lmt_hash_state.eqtb_data.ptr;
        }
    }
    /* the chain entries, i.e. the follow up list slots => eqtb */
    dump_things(f, lmt_hash_state.hash[lmt_hash_state.eqtb_data.top + 1], special_sequence_base - lmt_hash_state.eqtb_data.top);
    if (lmt_hash_state.hash_data.ptr > 0) {
        dump_things(f, lmt_hash_state.hash[eqtb_size + 1], lmt_hash_state.hash_data.ptr);
    }
    dump_int(f, lmt_hash_state.eqtb_data.ptr);
}

void tex_undump_hashtable(dumpstream f)
{
    undump_int(f, lmt_hash_state.eqtb_data.top);
    if (lmt_hash_state.eqtb_data.top >= hash_base && lmt_hash_state.eqtb_data.top <= frozen_control_sequence) {
        halfword p = hash_base - 1;
        do {
            halfword q;
            undump_int(f, q);
            if (q >= (p + 1) && q <= lmt_hash_state.eqtb_data.top) {
                undump_int(f, lmt_hash_state.hash[q]);
                p = q;
            } else {
                goto BAD;
            }
        } while (p != lmt_hash_state.eqtb_data.top);
        undump_things(f, lmt_hash_state.hash[lmt_hash_state.eqtb_data.top + 1], special_sequence_base - lmt_hash_state.eqtb_data.top);
        if (lmt_hash_state.hash_data.ptr > 0) {
            /* we get a warning on possible overrun here */
            undump_things(f, lmt_hash_state.hash[eqtb_size + 1], lmt_hash_state.hash_data.ptr);
        }
        undump_int(f, lmt_hash_state.eqtb_data.ptr);
        lmt_hash_state.eqtb_data.initial = lmt_hash_state.eqtb_data.ptr;
        return;
    }
  BAD:
    tex_fatal_undump_error("hash");
}

/*tex

    We need to put \TEX's \quote {primitive} control sequences into the hash table, together with
    their command code (which will be the |eq_type|) and an operand (which will be the |equiv|).
    The |primitive| procedure does this, in a way that no \TEX\ user can. The global value |cur_val|
    contains the new |eqtb| pointer after |primitive| has acted.

    Because the definitions of the actual user-accessible name of a primitive can be postponed until
    runtime, the function |primitive_def| is needed that does nothing except creating the control
    sequence name.

*/

void tex_primitive_def(const char *str, size_t length, singleword cmd, halfword chr)
{
    /*tex This creates the |text()| string: */
    cur_val = tex_string_locate(str, length, 1);
    set_eq_level(cur_val, level_one);
    set_eq_type(cur_val, cmd);
    set_eq_flag(cur_val, primitive_flag_bit);
    set_eq_value(cur_val, chr);
}

/*tex

    The function |store_primitive_name| sets up the bookkeeping for the reverse lookup. It is
    quite paranoid, because it is easy to mess this up accidentally.

    The |offset| is needed because sometimes character codes (in |o|) are indices into |eqtb|
    or are offset by a magical value to make sure they do not conflict with something else. We
    don't want the |prim_data[c].names| to have too many entries as it will just be wasted room,
    so |offset| is substracted from |o| before creating or accessing the array.

*/

static void tex_aux_store_primitive_name(strnumber s, singleword cmd, halfword chr, halfword offset)
{
    lmt_primitive_state.prim_data[cmd].offset = offset;
    if (lmt_primitive_state.prim_data[cmd].subids < (chr + 1)) {
        /*tex Not that efficient as each primitive triggers this now but only at ini time so ... */
        strnumber *newstr = aux_allocate_clear_array(sizeof(strnumber *), chr + 1, 1);
        if (lmt_primitive_state.prim_data[cmd].names) {
            memcpy(newstr, lmt_primitive_state.prim_data[cmd].names, (unsigned) (lmt_primitive_state.prim_data[cmd].subids) * sizeof(strnumber));
            aux_deallocate_array(lmt_primitive_state.prim_data[cmd].names);
        }
        lmt_primitive_state.prim_data[cmd].names = newstr;
        lmt_primitive_state.prim_data[cmd].subids = chr + 1;
    }
    lmt_primitive_state.prim_data[cmd].names[chr] = s;
}

/*tex

    Compared to \TEX82, |primitive| has two extra parameters. The |off| is an offset that will be
    passed on to |store_primitive_name|, the |cmd_origin| is the bit that is used to group
    primitives by originator. So the next function is called for each primitive and fills |prim_eqtb|.

    Contrary to \LUATEX\ we define (using |primitive_def|) all primitives beforehand, so not only
    those with |cmd_origin| values |core| and |tex|. As side effect, we don't get redundant string
    entries as in \LUATEX.

*/

void tex_primitive(int cmd_origin, const char *str, singleword cmd, halfword chr, halfword offset)
{
    int prim_val;
    strnumber ss;
    if (cmd_origin != no_command) {
        tex_primitive_def(str, strlen(str), cmd, offset + chr);
        /*tex Indeed, |cur_val| has the latest primitive. */
        ss = cs_text(cur_val);
    } else {
        ss = tex_maketexstring(str);
    }
    prim_val = tex_prim_lookup(ss);
    prim_origin(prim_val) = (quarterword) cmd_origin;
    prim_eq_type(prim_val) = cmd;
    prim_equiv(prim_val) = offset + chr;
    tex_aux_store_primitive_name(ss, cmd, chr, offset);
}

/*tex

    Here is a helper that does the actual hash insertion. This code far from ideal: the existence
    of |hash_extra| changes all the potential (short) coalesced lists into a single (long) one.
    This will create a slowdown.

    Here |hash_state.hash_used| starts out as the maximum \quote {normal} hash, not extra.

*/

static halfword tex_aux_insert_id(halfword p, const unsigned char *j, unsigned int l)
{
    if (cs_text(p) > 0) {
     RESTART:
        if (lmt_hash_state.hash_data.ptr < lmt_hash_state.hash_data.allocated) {
            ++lmt_hash_state.hash_data.ptr;
            cs_next(p) = lmt_hash_state.hash_data.ptr + eqtb_size;
            p = cs_next(p);
        } else if (tex_aux_room_in_hash()) {
            goto RESTART;
        } else {
            /*tex
                Search for an empty location in |hash|. This actually makes the direct first hit
                in such a hash slot invalid but we check for the string anyway. As we now use a
                hash size that is rather minimal, we don't really need this branch. It is a last
                resort anyway.
            */
            do {
                if (lmt_hash_state.eqtb_data.top == hash_base) {
                    /*tex We cannot go lower than this. */
                    tex_overflow_error("hash size", hash_size + lmt_hash_state.hash_data.allocated);
                }
                --lmt_hash_state.eqtb_data.top;
            } while (cs_text(lmt_hash_state.eqtb_data.top) != 0);
            cs_next(p) = lmt_hash_state.eqtb_data.top;
            p = lmt_hash_state.eqtb_data.top;
        }
    }
    cs_text(p) = tex_push_string(j, l);
    copy_eqtb_entry(p, undefined_control_sequence);
    ++lmt_hash_state.eqtb_data.ptr;
    return p;
}

/*tex

    Here is the subroutine that searches the hash table for an identifier that matches a given
    string of length |l > 1| appearing in |buffer[j .. (j + l - 1)]|. If the identifier is found,
    the corresponding hash table address is returned. Otherwise, if the global variable
    |no_new_control_sequence| is |true|, the dummy address |undefined_control_sequence| is returned.
    Otherwise the identifier is inserted into the hash table and its location is returned.

    On the \LUAMETATEX\ manual we have 250K hits and 400K misses. Adapting the max and prime does
    bring down the misses but also no gain in performance. In practice we seldom follow the chain.

*/

halfword tex_id_locate(int j, int l, int create)
{
    /*tex The index in |hash| array: */
    halfword h = tex_aux_compute_hash((char *) (lmt_fileio_state.io_buffer + j), l);
    /*tex We start searching here. Note that |0 <= h < hash_prime|: */
    halfword p = h + hash_base;
    /*tex The next one in a list: */
    while (1) {
        strnumber s = cs_text(p);
        if ((s > 0) && (str_length(s) == (unsigned) l) && tex_str_eq_buf(s, j, l)) {
            return p;
        } else {
            halfword n = cs_next(p);
            if (n) {
                p = n;
            } else if (create) {
                return tex_aux_insert_id(p, (lmt_fileio_state.io_buffer + j), (unsigned) l);
            } else {
                break;
            }
        }
    }
    return undefined_control_sequence;
}

/*tex

    Here is a similar subroutine for finding a primitive in the hash. This one is based on a \CCODE\
    string.

*/

halfword tex_string_locate(const char *s, size_t l, int create)
{
    /*tex The hash code: */
    halfword h = tex_aux_compute_hash(s, (int) l);
    /*tex The index in |hash| array. We start searching here. Note that |0 <= h < hash_prime|: */
    halfword p = h + hash_base;
    while (1) {
        if (cs_text(p) > 0 && tex_str_eq_cstr(cs_text(p), s, (int) l)) {
            return p;
        } else {
            halfword n = cs_next(p);
            if (n) {
                p = n;
            } else if (create) {
                return tex_aux_insert_id(p, (const unsigned char *) s, (unsigned) l);
            } else {
                break;
            }
        }
    }
    return undefined_control_sequence;
}

halfword tex_located_string(const char *s)
{
    size_t l = strlen(s);
    return tex_string_locate(s, l, 0);
}

/*tex

    The |print_cmd_chr| routine prints a symbolic interpretation of a command code and its modifier.
    This is used in certain \quotation {You can\'t} error messages, and in the implementation of
    diagnostic routines like |\show|.

    The body of |print_cmd_chr| use to be a rather tedious listing of print commands, and most of it
    was essentially an inverse to the |primitive| routine that enters a \TEX\ primitive into |eqtb|.

    Thanks to |prim_data|, there is no need for all that tediousness. What is left of |primt_cnd_chr|
    are just the exceptions to the general rule that the |cmd,chr_code| pair represents in a single
    primitive command.

*/

static void tex_aux_print_chr_cmd(const char *s, halfword cmd, halfword chr)
{
    tex_print_str(s);
    if (chr) {
        tex_print_str(cmd == letter_cmd ? " letter " : " character ");
        tex_print_uhex(chr);
        tex_print_char(' ');
        /*
            By using the the unicode (ascii) names for some we can better support syntax
            highlighting (which often involves parsing). The names are enclused in single
            quotes. For the chr codes above 128 we assume \UNICODE\ support.
        */
        /*tex
            We already intercepted the line feed here so that it doesn't give a side effect here
            in the original |tex_print_tex_str(chr)| call but we have now inlined similar code
            but without side effects.
        */
        if (chr < 32 || chr == 127) {
            return;
        } else if (chr <= 0x7F) {
            switch (chr) {
                case '\n' : tex_print_str("'line feed'");            return;
                case '\r' : tex_print_str("'carriage return'");      return;
                case ' '  : tex_print_str("'space'");                return;
                case '!'  : tex_print_str("'exclamation mark'");     return;
                case '\"' : tex_print_str("'quotation mark'");       return;
                case '#'  : tex_print_str("'hash tag'");             return;
                case '$'  : tex_print_str("'dollar sign'");          return;
                case '%'  : tex_print_str("'percent sign'");         return;
                case '&'  : tex_print_str("'ampersand'");            return;
                case '\'' : tex_print_str("'apostrophe'");           return;
                case '('  : tex_print_str("'left parenthesis'");     return;
                case ')'  : tex_print_str("'right parenthesis'");    return;
                case '*'  : tex_print_str("'asterisk'");             return;
                case '+'  : tex_print_str("'plus sign'");            return;
                case ','  : tex_print_str("'comma'");                return;
                case '-'  : tex_print_str("'hyphen minus'");         return;
                case '.'  : tex_print_str("'full stop'");            return;
                case '/'  : tex_print_str("'slash'");                return;
                case ':'  : tex_print_str("'colon'");                return;
                case ';'  : tex_print_str("'semicolon'");            return;
                case '<'  : tex_print_str("'less than sign'");       return;
                case '='  : tex_print_str("'equal sign'");           return;
                case '>'  : tex_print_str("'more than sign'");       return;
                case '?'  : tex_print_str("'question mark'");        return;
                case '@'  : tex_print_str("'at sign'");              return;
                case '['  : tex_print_str("'left square bracket'");  return;
                case '\\' : tex_print_str("'backslash'");            return;
                case ']'  : tex_print_str("'right square bracket'"); return;
                case '^'  : tex_print_str("'circumflex accent'");    return;
                case '_'  : tex_print_str("'low line'");             return;
                case '`'  : tex_print_str("'grave accent'");         return;
                case '{'  : tex_print_str("'left curly bracket'");   return;
                case '|'  : tex_print_str("'vertical bar'");         return;
                case '}'  : tex_print_str("'right curly bracket'");  return;
                case '~'  : tex_print_str("'tilde'");                return;
            }
            tex_print_char(chr);
        } else if (chr <= 0x7FF) {
            tex_print_char(0xC0 + (chr / 0x40));
            tex_print_char(0x80 + (chr % 0x40));
        } else if (chr <= 0xFFFF) {
            tex_print_char(0xE0 +  (chr / 0x1000));
            tex_print_char(0x80 + ((chr % 0x1000) / 0x40));
            tex_print_char(0x80 + ((chr % 0x1000) % 0x40));
        } else if (chr <= 0x10FFFF) {
            tex_print_char(0xF0 +   (chr / 0x40000));
            tex_print_char(0x80 +  ((chr % 0x40000) / 0x1000));
            tex_print_char(0x80 + (((chr % 0x40000) % 0x1000) / 0x40));
            tex_print_char(0x80 + (((chr % 0x40000) % 0x1000) % 0x40));
        }
    }
}

/*tex |\TEX82| Didn't print the |cmd,idx| information, but it may be useful. */

static void tex_aux_prim_cmd_chr(quarterword cmd, halfword chr)
{
    if (cmd <= last_visible_cmd) {
        int idx = chr - lmt_primitive_state.prim_data[cmd].offset;
        if (idx >= 0 && idx < lmt_primitive_state.prim_data[cmd].subids) {
            if (lmt_primitive_state.prim_data[cmd].names && lmt_primitive_state.prim_data[cmd].names[idx]) {
                tex_print_tex_str_esc(lmt_primitive_state.prim_data[cmd].names[idx]);
            } else {
                tex_print_format("[warning: cmd %i, chr %i, no name]", cmd, idx);
            }
        } else if (cmd == internal_int_cmd && idx < number_int_pars) {
            /* a special case */
            tex_print_format("[integer: chr %i, class specific]", cmd);
        } else {
            tex_print_format("[warning: cmd %i, chr %i, out of range]", cmd, idx);
        }
    } else {
        tex_print_format("[warning: cmd %i, invalid]", cmd);
    }
}

static void tex_aux_show_lua_call(const char *what, int slot)
{
    int callback_id = lmt_callback_defined(show_lua_call_callback);
    if (callback_id) {
        char *ss = NULL;
        int lua_retval = lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "Sd->S", what, slot, &ss);
        if (lua_retval && ss && strlen(ss) > 0) {
            tex_print_str(ss);
            lmt_memory_free(ss);
            return;
        }
    }
    tex_print_format("%s %i", what, slot);
}

void tex_print_cmd_flags(halfword cs, halfword cmd, int flags, int escaped)
{
    if (flags) {
        flags = eq_flag(cs);
        if (is_frozen   (flags)) { (escaped ? tex_print_str_esc : tex_print_str)("frozen "   ); }
        if (is_permanent(flags)) { (escaped ? tex_print_str_esc : tex_print_str)("permanent "); }
        if (is_immutable(flags)) { (escaped ? tex_print_str_esc : tex_print_str)("immutable "); }
        if (is_primitive(flags)) { (escaped ? tex_print_str_esc : tex_print_str)("primitive "); }
        if (is_mutable  (flags)) { (escaped ? tex_print_str_esc : tex_print_str)("mutable "  ); }
        if (is_noaligned(flags)) { (escaped ? tex_print_str_esc : tex_print_str)("noaligned "); }
        if (is_instance (flags)) { (escaped ? tex_print_str_esc : tex_print_str)("instance " ); }
        if (is_untraced (flags)) { (escaped ? tex_print_str_esc : tex_print_str)("untraced " ); }
    }
    if (is_tolerant_cmd (cmd)) {
        (escaped ? tex_print_str_esc : tex_print_str)("tolerant " );
    }
    if (is_protected_cmd(cmd)) {
        (escaped ? tex_print_str_esc : tex_print_str)("protected ");
    } else if (is_semi_protected_cmd(cmd)) {
        (escaped ? tex_print_str_esc : tex_print_str)("semiprotected ");
    }
}

void tex_print_cmd_chr(singleword cmd, halfword chr)
{
    switch (cmd) {
        case left_brace_cmd:
            tex_aux_print_chr_cmd("begin group", cmd, chr);
            break;
        case right_brace_cmd:
            tex_aux_print_chr_cmd("end group", cmd, chr);
            break;
        case math_shift_cmd:
            tex_aux_print_chr_cmd("math shift", cmd, chr);
            break;
        case alignment_tab_cmd:
            tex_aux_print_chr_cmd("alignment tab", cmd, chr);
            break;
        case parameter_cmd:
            tex_aux_print_chr_cmd("parameter", cmd, chr);
            break;
        case superscript_cmd:
            tex_aux_print_chr_cmd("superscript", cmd, chr);
            break;
        case subscript_cmd:
            tex_aux_print_chr_cmd("subscript", cmd, chr);
            break;
        case spacer_cmd:
            tex_aux_print_chr_cmd("blank space", cmd, chr);
            break;
        case letter_cmd:
        case other_char_cmd:
            tex_aux_print_chr_cmd("the", cmd, chr);
            break;
        /*
        case active_char_cmd:
        case comment_cmd:
        case invalid_char_cmd:
            break;
        */
        case end_template_cmd:
            /*tex Kind of special: |chr| points to |null_list). */
            tex_print_str_esc("endtemplate");
         // tex_print_str("end of alignment template");
            break;
        case if_test_cmd:
            if (chr <= last_if_test_code) {
                tex_aux_prim_cmd_chr(cmd, chr);
            } else {
                tex_aux_show_lua_call("luacondition", chr - last_if_test_code);
            }
            break;
        case char_given_cmd:
            tex_print_str_esc("char");
            tex_print_qhex(chr);
            break;
        case lua_call_cmd:
            tex_aux_show_lua_call("luacall", chr);
            break;
        case lua_local_call_cmd:
            tex_aux_show_lua_call("local luacall", chr);
            break;
        case lua_protected_call_cmd:
            tex_aux_show_lua_call("protected luacall", chr);
            break;
        case lua_value_cmd:
            tex_aux_show_lua_call("luavalue", chr);
            break;
        case set_font_cmd:
            tex_print_str("select font ");
            tex_print_font(chr);
            break;
        case undefined_cs_cmd:
            tex_print_str("undefined");
            break;
        case call_cmd:
        case protected_call_cmd:
        case semi_protected_call_cmd:
        case tolerant_call_cmd:
        case tolerant_protected_call_cmd:
        case tolerant_semi_protected_call_cmd:
            tex_print_cmd_flags(cur_cs, cur_cmd, 1, 0);
            tex_print_str("macro");
            break;
        case internal_toks_cmd:
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
        case register_toks_cmd:
            tex_print_str_esc("toks");
            tex_print_int(register_toks_number(chr));
            break;
        case internal_int_cmd:
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
        case register_int_cmd:
            tex_print_str_esc("count");
            tex_print_int(register_int_number(chr));
            break;
        case internal_attribute_cmd:
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
        case register_attribute_cmd:
            tex_print_str_esc("attribute");
            tex_print_int(register_attribute_number(chr));
            break;
        case internal_dimen_cmd:
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
        case register_dimen_cmd:
            tex_print_str_esc("dimen");
            tex_print_int(register_dimen_number(chr));
            break;
        case internal_glue_cmd:
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
        case register_glue_cmd:
            tex_print_str_esc("skip");
            tex_print_int(register_glue_number(chr));
            break;
        case internal_mu_glue_cmd:
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
        case register_mu_glue_cmd:
            tex_print_str_esc("muskip");
            tex_print_int(register_mu_glue_number(chr));
            break;
        case node_cmd:
            tex_print_str(node_token_flagged(chr) ? "large" : "small");
            tex_print_str(" node reference");
            break;
        case integer_cmd:
            tex_print_str("integer ");
            tex_print_int(chr);
            break;
        case dimension_cmd:
            tex_print_str("dimension ");
            tex_print_dimension(chr, pt_unit);
            break;
        case gluespec_cmd:
            tex_print_str("gluespec ");
            tex_print_spec(chr, pt_unit);
            break;
        case mugluespec_cmd:
            tex_print_str("mugluespec ");
            tex_print_spec(chr, mu_unit);
            break;
        case mathspec_cmd:
            switch (node_subtype(chr)) {
                case tex_mathcode:
                    tex_print_str_esc("mathchar");
                    break;
                case umath_mathcode:
             /* case umathnum_mathcode: */
                    tex_print_str_esc("Umathchar");
                    break;
                case mathspec_mathcode:
                    tex_print_str("mathspec ");
            }
            tex_print_mathspec(chr);
            break;
        case fontspec_cmd:
            {
                /* We don't check for validity here. */
                tex_print_str("fontspec ");
                tex_print_fontspec(chr);
            }
            break;
        case deep_frozen_end_template_cmd:
            /*tex Kind of special: |chr| points to |null_list). */
            tex_print_str_esc("endtemplate");
            break;
        case deep_frozen_dont_expand_cmd:
            /*tex Kind of special. */
            tex_print_str_esc("notexpanded");
            break;
        /*
        case string_cmd:
            print_str("string:->");
            print(cs_offset_value + chr);
            break;
        */
        case internal_box_reference_cmd:
            tex_print_str_esc("hiddenlocalbox");
            break;
        default:
            /*tex These are most commands, actually. Todo: local boxes*/
            tex_aux_prim_cmd_chr(cmd, chr);
            break;
    }
}
