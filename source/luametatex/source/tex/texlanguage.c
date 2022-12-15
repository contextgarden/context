/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    We no longer dump the patterns and exeptions as they as supposed to be loaded runtime. There is
    no gain getting them from the format. But we do dump some of the properties.

    There were all kind of checks for simple characters i.e. not ligatures but there is no need for
    that in \LUAMETATEX. We have separated stages and the hyphenator sees just glyphs. And when a
    traditional font has glyphs we can assume that the old school font encoding matches the patterns
    i.e. that ligatures are not in the normal character slots.

    Exceptions are stored at the \LUA\ end. We cannot easilly go dynamic because fonts are stored
    in the eqtb so we would have to use some more indirect mechanism (doable as we do it for other
    items) too.

*/

language_state_info lmt_language_state = {
    .languages        = NULL,
    .language_data    = {
        .minimum      = min_language_size,
        .maximum      = max_language_size,
        .size         = memory_data_unset,
        .step         = stp_language_size,
        .allocated    = 0,
        .itemsize     = 1,
        .top          = 0,
        .ptr          = 0,
        .initial      = memory_data_unset,
        .offset       = 0,
    },
    .handler_table_id = 0,
    .handler_count    = 0,
};

/*tex
    We can enforce a language id but we want to be sequential so we accept holes! So one
    has to define bottom-up. As with fonts, we have a zero language but that one normally
    is not set.
*/

static void tex_aux_reset_language(halfword id)
{
    tex_language *lang = lmt_language_state.languages[id];
    lang->id = id;
    lang->exceptions = 0;
    lang->patterns = NULL;
    lang->wordhandler = 0;
    lang->pre_hyphen_char = '-';
    lang->post_hyphen_char = 0;
    lang->pre_exhyphen_char = 0;
    lang->post_exhyphen_char = 0;
    lang->hyphenation_min = -1;
    lang->hjcode_head = NULL;
}

/*tex
    A value below zero will bump the language id. Because we have a rather limited number of
    languages there is no configuration, size is just maximum.
*/

static halfword tex_aux_new_language_id(halfword id)
{
    int top;
    if (id >= 0) {
        if (id <= lmt_language_state.language_data.top) {
            if (lmt_language_state.languages[id]) {
                return tex_formatted_error("languages", "the language with id %d is already created", id);
            } else {
                return id;
            }
        } else if (id > lmt_language_state.language_data.maximum) {
            goto OVERFLOWERROR;
        } else {
            top = id;
        }
    } else if (lmt_language_state.language_data.ptr < lmt_language_state.language_data.top) {
        ++lmt_language_state.language_data.ptr;
        return lmt_language_state.language_data.ptr;
    } else if (lmt_language_state.language_data.top >= lmt_language_state.language_data.maximum) {
        goto OVERFLOWERROR;
    } else if (lmt_language_state.language_data.top + lmt_language_state.language_data.step > lmt_language_state.language_data.maximum) {
        top = lmt_language_state.language_data.maximum;
    } else {
        top = lmt_language_state.language_data.top + lmt_language_state.language_data.step;
    }
    /*tex Finally we can bump memory. */
    {
        tex_language **tmp = aux_reallocate_array(lmt_language_state.languages, sizeof(tex_language *), top, 0);
        if (tmp) {
            for (int i = lmt_language_state.language_data.top + 1; i <= top; i++) {
                tmp[i] = NULL;
            }
            lmt_language_state.languages = tmp;
            lmt_language_state.language_data.allocated += ((size_t) top - lmt_language_state.language_data.top) * sizeof(tex_language *);
            lmt_language_state.language_data.top = top;
            lmt_language_state.language_data.ptr += 1;
            return lmt_language_state.language_data.ptr;
        }
    }
  OVERFLOWERROR:
    tex_overflow_error("languages", lmt_language_state.language_data.maximum);
    return 0;
}

void tex_initialize_languages(void)
{
    tex_language **tmp = aux_allocate_clear_array(sizeof(tex_language *), lmt_language_state.language_data.minimum, 0);
    if (tmp) {
        for (int i = 0; i < lmt_language_state.language_data.minimum; i++) {
            tmp[i] = NULL;
        }
        lmt_language_state.languages = tmp;
        lmt_language_state.language_data.allocated += lmt_language_state.language_data.minimum * sizeof(tex_language *);
        lmt_language_state.language_data.top = lmt_language_state.language_data.minimum;
    } else {
        tex_overflow_error("languages", lmt_language_state.language_data.minimum);
    }
}

/*
halfword tex_aux_maximum_language_id(void)
{
    return language_state.language_data.maximum;
}
*/

int tex_is_valid_language(halfword n)
{
    if (n == 0) {
        return 1;
    } else if (n > 0 && n <= lmt_language_state.language_data.top) {
        return lmt_language_state.languages[n] ? 1 : 0;
    } else {
        return 0;
    }
}

tex_language *tex_new_language(halfword n)
{
    halfword id = tex_aux_new_language_id(n);
    if (id >= 0) {
        tex_language *lang = lmt_memory_malloc(sizeof(struct tex_language));
        if (lang) {
            lmt_language_state.languages[id] = lang;
            lmt_language_state.language_data.allocated += sizeof(struct tex_language);
            tex_aux_reset_language(id);
            if (saving_hyph_codes_par) {
                /*tex
                    For now, we might just use specific value for whatever task. This will become
                    obsolete.
                */
                tex_hj_codes_from_lc_codes(id);
            }
        } else {
            tex_overflow_error("language", sizeof(struct tex_language));
        }
        return lang;
    } else {
        return NULL;
    }
}

tex_language *tex_get_language(halfword n)
{
    if (n >= 0) {
        if (n <= lmt_language_state.language_data.top && lmt_language_state.languages[n]) {
            return lmt_language_state.languages[n];
        }
        if (n <= lmt_language_state.language_data.maximum) {
            return tex_new_language(n);
        }
    }
    return NULL;
}

/*tex
    Freeing, dumping, undumping languages:
*/

/*
void free_languages(void)
{
    for (int i = 0; i < language_state.language_data.top; i++) {
        if (language_state.languages[i]) {
            lmt_memory_free(language_state.languages[i]);
            language_state.languages[i] = NULL;
        }
    }
}
*/

void tex_dump_language_data(dumpstream f)
{
    dump_int(f, lmt_language_state.language_data.top);
    dump_int(f, lmt_language_state.language_data.ptr);
    if (lmt_language_state.language_data.top > 0) {
        for (int i = 0; i < lmt_language_state.language_data.top; i++) {
            tex_language *lang = lmt_language_state.languages[i];
            if (lang) {
                dump_via_int(f, 1);
                dump_int(f, lang->id);
                dump_int(f, lang->pre_hyphen_char);
                dump_int(f, lang->post_hyphen_char);
                dump_int(f, lang->pre_exhyphen_char);
                dump_int(f, lang->post_exhyphen_char);
                dump_int(f, lang->hyphenation_min);
                tex_dump_language_hj_codes(f, i);
            } else {
                dump_via_int(f, 0);
            }
        }
    }
}

void tex_undump_language_data(dumpstream f)
{
    int top, ptr;
    undump_int(f, top);
    undump_int(f, ptr);
    if (top > 0) {
        tex_language **tmp = aux_allocate_clear_array(sizeof(tex_language *), top, 0);
        if (tmp) {
            lmt_language_state.language_data.top = top;
            lmt_language_state.language_data.ptr = ptr;
            lmt_language_state.languages = tmp;
            for (int i = 0; i < top; i++) {
                int x;
                undump_int(f, x);
                if (x == 1) {
                    tex_language *lang = lmt_memory_malloc(sizeof(struct tex_language));
                    if (lang) {
                        lmt_language_state.languages[i] = lang;
                        lmt_language_state.language_data.allocated += sizeof(struct tex_language);
                        lang->exceptions = 0;
                        lang->patterns = NULL;
                        lang->wordhandler = 0;
                        lang->hjcode_head = NULL;
                        undump_int(f, lang->id);
                        undump_int(f, lang->pre_hyphen_char);
                        undump_int(f, lang->post_hyphen_char);
                        undump_int(f, lang->pre_exhyphen_char);
                        undump_int(f, lang->post_exhyphen_char);
                        undump_int(f, lang->hyphenation_min);
                        tex_undump_language_hj_codes(f, i);
                        if (lang->id != i) {
                            tex_formatted_warning("languages", "undumped language id mismatch: %d <> %d", lang->id, i);
                            lang->id = i;
                        }
                    } else {
                        tex_overflow_error("languages", i);
                    }
                    tmp[i] = lang;
                } else {
                    tmp[i] = NULL;
                }
            }
            lmt_language_state.language_data.initial = lmt_language_state.language_data.ptr;
        } else {
            tex_overflow_error("languages", top);
            lmt_language_state.language_data.initial = 0;
        }
    } else {
        /*tex Indeed we can have no languages stored. */
        tex_initialize_languages();
    }
}

/*tex All kind of accessors. */

void tex_set_pre_hyphen_char(halfword n, halfword v)
{
    struct tex_language *l = tex_get_language(n);
    if (l) {
        l->pre_hyphen_char = v;
    }
}

void tex_set_post_hyphen_char(halfword n, halfword v)
{
    struct tex_language *l = tex_get_language(n);
    if (l) {
        l->post_hyphen_char = v;
    }
}

void tex_set_pre_exhyphen_char(halfword n, halfword v)
{
    struct tex_language *l = tex_get_language(n);
    if (l) {
        l->pre_exhyphen_char = v;
    }
}

void tex_set_post_exhyphen_char(halfword n, halfword v)
{
    struct tex_language *l = tex_get_language(n);
    if (l) {
        l->post_exhyphen_char = v;
    }
}

halfword tex_get_pre_hyphen_char(halfword n)
{
    struct tex_language *l = tex_get_language(n);
    return l ? l->pre_hyphen_char : -1;
}

halfword tex_get_post_hyphen_char(halfword n)
{
    struct tex_language *l = tex_get_language(n);
    return l ? l->post_hyphen_char : -1;
}

halfword tex_get_pre_exhyphen_char(halfword n)
{
    struct tex_language *l = tex_get_language(n);
    return l ? l->pre_exhyphen_char : -1;
}

halfword tex_get_post_exhyphen_char(halfword n)
{
    struct tex_language *l = tex_get_language(n);
    return (l) ? (int) l->post_exhyphen_char : -1;
}

void tex_set_hyphenation_min(halfword n, halfword v)
{
    struct tex_language *l = tex_get_language(n);
    if (l) {
        l->hyphenation_min = v;
    }
}

halfword tex_get_hyphenation_min(halfword n)
{
    struct tex_language *l = tex_get_language((int) n);
    return l ? l->hyphenation_min : -1;
}

void tex_load_patterns(struct tex_language *lang, const unsigned char *buff)
{
    if ((! lang) || (! buff) || strlen((const char *) buff) == 0) {
        return;
    } else {
        if (! lang->patterns) {
            lang->patterns = hnj_dictionary_new();
        }
        hnj_dictionary_load(lang->patterns, buff, tracing_hyphenation_par > 0);
    }
}

void tex_clear_patterns(struct tex_language *lang)
{
    if (lang && lang->patterns) {
        hnj_dictionary_clear(lang->patterns);
    }
}

void tex_load_tex_patterns(halfword curlang, halfword head)
{
    char *s = tex_tokenlist_to_tstring(head, 1, NULL, 0, 0, 0, 0);
    if (s) {
        tex_load_patterns(tex_get_language(curlang), (unsigned char *) s);
    }
}

/*
    This cleans one word which is returned in |cleaned|, returns the new offset into |buffer|.
*/

/* define tex_isspace(c) (c == ' ' || c == '\t') */
#  define tex_isspace(c) (c == ' ')

const char *tex_clean_hyphenation(halfword id, const char *buff, char **cleaned)
{
    int items = 0;
    /*tex Work buffer for bytes: */
    unsigned char word[max_size_of_word + 1];
    /*tex Work buffer for \UNICODE: */
    unsigned uword[max_size_of_word + 1] = { 0 };
    /*tex The \UNICODE\ buffer value: */
    int i = 0;
    char *uindex = (char *) word;
    const char *s = buff;
    while (*s && ! tex_isspace((unsigned char)*s)) {
        word[i++] = (unsigned char) *s;
        s++;
        if ((s-buff) > max_size_of_word) {
            /*tex Todo: this is too strict, should count \UNICODE, not bytes. */
            *cleaned = NULL;
            tex_handle_error(
                normal_error_type,
                "Exception too long",
                NULL
            );
            return s;
        }
    }
    /*tex Now convert the input to \UNICODE. */
    word[i] = '\0';
    aux_splitutf2uni(uword, (const char *)word);
    /*tex
        Build the new word string. The hjcode values < 32 indicate a length, so that
        for instance \|hjcode`ܽ2| makes that ligature count okay.
    */
    i = 0;
    while (uword[i] > 0) {
        int u = uword[i++];
        if (u == '-') {
            /*tex Skip. */
        } else if (u == '=') {
            unsigned c = tex_get_hj_code(id, '-');
            uindex = aux_uni2string(uindex, (! c || c <= 32) ? '-' : c);
        } else if (u == '{') {
            u = uword[i++];
            items = 0;
            while (u && u != '}') {
                u = uword[i++];
            }
            if (u == '}') {
                items++;
                u = uword[i++];
            }
            while (u && u != '}') {
                u = uword[i++];
            }
            if (u == '}') {
                items++;
                u = uword[i++];
            }
            if (u == '{') {
                u = uword[i++];
            }
            while (u && u != '}') {
                unsigned c = tex_get_hj_code(id, u);
                uindex = aux_uni2string(uindex, (! c || c <= 32) ? u : c);
                u = uword[i++];
            }
            if (u == '}') {
                items++;
            }
            if (items != 3) {
                /* hm, we intercept that elsewhere in a better way so why here? Best remove the test here or move the other one here. */
                *cleaned = NULL;
                tex_handle_error(
                    normal_error_type,
                    "Exception syntax error, a discretionary has three components: {}{}{}.",
                    NULL
                );
                return s;
            } else {
                /* skip replacement (chars) */
                if (uword[i] == '(') {
                    while (uword[++i] && uword[i] != ')') { };
                    if (uword[i] != ')') {
                        tex_handle_error(
                            normal_error_type,
                            "Exception syntax error, an alternative replacement is defined as (text).",
                            NULL
                        );
                        return s;
                    } else if (uword[i]) {
                        i++;
                   }
                }
                /* skip penalty: [digit] but we intercept multiple digits */
                if (uword[i] == '[') {
                    if (uword[i+1] && uword[i+1] >= '0' && uword[i+1] <= '9' && uword[i+2] && uword[i+2] == ']') {
                        i += 3;
                    } else {
                        tex_handle_error(
                            normal_error_type,
                            "Exception syntax error, a penalty is defined as [digit].",
                            NULL
                        );
                        return s;
                    }
                }
            }
        } else {
            unsigned c = tex_get_hj_code(id, u);
            uindex = aux_uni2string(uindex, (! c || c <= 32) ? u : c);
        }
    }
    *uindex = '\0';
    *cleaned = lmt_memory_strdup((char *) word);
    return s;
}

void tex_load_hyphenation(struct tex_language *lang, const unsigned char *buff)
{
    if (lang) {
        lua_State *L = lmt_lua_state.lua_instance;
        const char *s = (const char *) buff;
        char *cleaned = NULL;
        int id = lang->id;
        if (lang->exceptions == 0) {
            lua_newtable(L);
            lang->exceptions = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, lang->exceptions);
        while (*s) {
            while (tex_isspace((unsigned char) *s)) {
                s++;
            }
            if (*s) {
                const char *value = s;
                s = tex_clean_hyphenation(id, s, &cleaned);
                if (cleaned) {
                    size_t len = s - value;
                    if (len > 0) {
                        lua_pushstring(L, cleaned);
                        lua_pushlstring(L, value, len);
                        lua_rawset(L, -3);
                    }
                    lmt_memory_free(cleaned);
                } else {
                    /* tex_formatted_warning("hyphenation","skipping invalid hyphenation exception: %s", value); */
                }
            }
        }
        lua_pop(L, 1);
    }
}

void tex_clear_hyphenation(struct tex_language *lang)
{
    if (lang && lang->exceptions != 0) {
        lua_State *L = lmt_lua_state.lua_instance;
        luaL_unref(L, LUA_REGISTRYINDEX, lang->exceptions);
        lang->exceptions = 0;
    }
}

void tex_load_tex_hyphenation(halfword curlang, halfword head)
{
    char *s = tex_tokenlist_to_tstring(head, 1, NULL, 0, 0, 0, 0);
    if (s) {
        tex_load_hyphenation(tex_get_language(curlang), (unsigned char *) s);
    }
}

static halfword tex_aux_insert_discretionary(halfword t, halfword pre, halfword post, halfword replace, quarterword subtype, int penalty)
{
    /*tex For compound words following explicit hyphens we take the current font. */
    halfword d = tex_new_disc_node(subtype);
    halfword a = node_attr(t) ;
    disc_penalty(d) = penalty;
    if (t == replace) {
        /*tex We have |prev disc next-next|. */
        tex_try_couple_nodes(d, node_next(t));
        tex_try_couple_nodes(node_prev(t), d);
        node_prev(t) = null;
        node_next(t) = null;
        replace = t;
    } else {
        /*tex We have |prev disc next|. */
        tex_try_couple_nodes(d, node_next(t));
        tex_couple_nodes(t, d);
    }
    if (a) {
        tex_attach_attribute_list_attribute(d, a);
    }
    tex_set_disc_field(d, pre_break_code, pre);
    tex_set_disc_field(d, post_break_code, post);
    tex_set_disc_field(d, no_break_code, replace);
    return d;
}

static halfword tex_aux_insert_syllable_discretionary(halfword t, lang_variables *lan)
{
    halfword n = tex_new_disc_node(syllable_discretionary_code);
    disc_penalty(n) = hyphen_penalty_par;
    tex_couple_nodes(n, node_next(t));
    tex_couple_nodes(t, n);
    tex_attach_attribute_list_attribute(n, get_attribute_list(t));
    if (lan->pre_hyphen_char > 0) {
        halfword g = tex_new_glyph_node(glyph_unset_subtype, glyph_font(t), lan->pre_hyphen_char, t);
        tex_set_disc_field(n, pre_break_code, g);
    }
    if (lan->post_hyphen_char > 0) {
        halfword g = tex_new_glyph_node(glyph_unset_subtype, glyph_font(t), lan->post_hyphen_char, t);
        tex_set_disc_field(n, post_break_code, g);
    }
    return n;
}

static halfword tex_aux_compound_word_break(halfword t, halfword clang, halfword chr)
{
    halfword prechar, postchar, pre, post, disc;
    if (chr == ex_hyphen_char_par) {
        halfword pre_exhyphen_char = tex_get_pre_exhyphen_char(clang);
        halfword post_exhyphen_char = tex_get_post_exhyphen_char(clang);
        prechar  = pre_exhyphen_char  > 0 ? pre_exhyphen_char  : ex_hyphen_char_par;
        postchar = post_exhyphen_char > 0 ? post_exhyphen_char : null;
    } else {
        /* we need a flag : use pre/post cf language spec */
        prechar  = chr;
        postchar = null;
    }
    pre  = prechar  > 0 ? tex_new_glyph_node(glyph_unset_subtype, glyph_font(t), prechar,  t) : null;
    post = postchar > 0 ? tex_new_glyph_node(glyph_unset_subtype, glyph_font(t), postchar, t) : null;
    disc = tex_aux_insert_discretionary(t, pre, post, t, automatic_discretionary_code, tex_automatic_disc_penalty(glyph_hyphenate(t)));
    return disc;
}

static char *tex_aux_hyphenation_exception(int exceptions, char *w)
{
    lua_State *L = lmt_lua_state.lua_instance;
    char *ret = NULL;
    if (lua_rawgeti(L, LUA_REGISTRYINDEX, exceptions) == LUA_TTABLE) {
        /*tex Word table: */
        lua_pushstring(L, w);
        lua_rawget(L, -2);
        if (lua_type(L, -1) == LUA_TSTRING) {
            ret = lmt_memory_strdup(lua_tostring(L, -1));
        }
        lua_pop(L, 2);
    } else {
        lua_pop(L, 1);
    }
    return ret;
}

/*tex

    The sequence from |wordstart| to |r| can contain only normal characters it could be faster to
    modify a halfword pointer and return an integer

*/

# define zws  0x200B /* zero width space makes no sense */
# define zwnj 0x200C
# define zwj  0x200D

static halfword tex_aux_find_exception_part(unsigned int *j, unsigned int *uword, int len, halfword parent, char final)
{
    halfword head = null;
    halfword tail = null;
    unsigned i = *j;
    int noligature = 0;
    int nokerning = 0;
    /*tex This puts uword[i] on the |{|. */
    i++;
    while (i < (unsigned) len && uword[i + 1] != (unsigned int) final) {
        if (tail) {
            switch (uword[i + 1]) {
                case zwj:
                    noligature = 1;
                    nokerning = 0;
                    break;
                case zwnj:
                    noligature = 1;
                    nokerning = 1;
                    break;
                default:
                    {
                        halfword s = tex_new_glyph_node(glyph_unset_subtype, glyph_font(parent), (int) uword[i + 1], parent); /* todo: data */
                        tex_couple_nodes(tail, s);
                        if (noligature) {
                            tex_add_glyph_option(tail, glyph_option_no_right_ligature);
                            tex_add_glyph_option(s, glyph_option_no_left_ligature);
                            noligature = 0;
                        }
                        if (nokerning) {
                            tex_add_glyph_option(tail, glyph_option_no_right_kern);
                            tex_add_glyph_option(s, glyph_option_no_left_kern);
                            nokerning = 0;
                        }
                        tail = node_next(tail);
                        break;
                    }
            }
        } else {
            head = tex_new_glyph_node(glyph_unset_subtype, glyph_font(parent), (int) uword[i + 1], parent); /* todo: data */
            tail = head;
        }
        i++;
    }
    *j = ++i;
    return head;
}

static int tex_aux_count_exception_part(unsigned int *j, unsigned int *uword, int len)
{
    int n = 0;
    unsigned i = *j;
    /*tex This puts uword[i] on the |{|. */
    i++;
    while (i < (unsigned) len && uword[i + 1] != '}') {
        n++;
        i++;
    }
    *j = ++i;
    return n;
}

static void tex_aux_show_exception_error(const char *part)
{
    tex_handle_error(
        normal_error_type,
        "Invalid %s part in exception",
        part,
        "Exception discretionaries should contain three pairs of braced items.\n"
        "No intervening spaces are allowed."
    );
}

/*tex

    The exceptions are taken as-is: no min values are taken into account. One can add normal
    patterns on-the-fly if needed.

*/

static void tex_aux_do_exception(halfword wordstart, halfword r, char *replacement)
{
    halfword t = wordstart;
    lang_variables langdata;
    unsigned uword[max_size_of_word + 1] = { 0 };
    unsigned len = aux_splitutf2uni(uword, replacement);
    int clang = get_glyph_language(wordstart);
    langdata.pre_hyphen_char = tex_get_pre_hyphen_char(clang);
    langdata.post_hyphen_char = tex_get_post_hyphen_char(clang);
    for (unsigned i = 0; i < len; i++) {
        if (uword[i + 1] == 0 ) {
            /*tex We ran out of the exception pattern. */
            break;
        } else if (uword[i + 1] == '-') {
            /*tex A hyphen follows. */
            if (node_next(t) == r) {
                break;
            } else {
                tex_aux_insert_syllable_discretionary(t, &langdata);
                /*tex Skip the new disc */
                t = node_next(t);
            }
        } else if (uword[i + 1] == '=') {
            /*tex We skip a disc. */
            t = node_next(t);
        } else if (uword[i + 1] == '{') {
            /*tex We ran into an exception |{}{}{}| or |{}{}{}[]|. */
            halfword pre = null;
            halfword post = null;
            halfword replace = null;
            int count = 0;
            int alternative = null;
            halfword penalty;
            /*tex |pre| */
            pre = tex_aux_find_exception_part(&i, uword, (int) len, wordstart, '}');
            if (i == len || uword[i + 1] != '{') {
                tex_aux_show_exception_error("pre");
            }
            /*tex |post| */
            post = tex_aux_find_exception_part(&i, uword, (int) len, wordstart, '}');
            if (i == len || uword[i + 1] != '{') {
                tex_aux_show_exception_error("post");
            }
            /*tex |replace| */
            count = tex_aux_count_exception_part(&i, uword, (int) len);
            if (i == len) {
                tex_aux_show_exception_error("replace");
            } else if (uword[i] && uword[i + 1] == '(') {
                alternative = tex_aux_find_exception_part(&i, uword, (int) len, wordstart, ')');;
            }
            /*tex Play safe. */
            if (node_next(t) == r) {
                break;
            } else {
                /*tex Let's deal with an (optional) replacement. */
                if (count > 0) {
                    /*tex Assemble the replace stream. */
                    halfword q = t;
                    replace = node_next(q);
                    while (count > 0 && q) {
                        halfword t = node_type(q);
                        q = node_next(q);
                        if (t == glyph_node || t == disc_node) {
                            count--;
                        } else {
                            break ;
                        }
                    }
                    /*tex Remove it from the main stream */
                    tex_try_couple_nodes(t, node_next(q));
                    /*tex and finish it in the replace. */
                    node_next(q) = null;
                    if (alternative) {
                        tex_flush_node_list(replace);
                        replace = alternative;
                    } else {
                        /*tex Sanitize the replace stream (we could use the flattener instead). */
                        q = replace ;
                        while (q) {
                            halfword n = node_next(q);
                            if (node_type(q) == disc_node) {
                                /*tex Beware: the replacement starts after the no_break pointer. */
                                halfword nb = disc_no_break_head(q);
                                disc_no_break_head(q) = null;
                                node_prev(nb) = null ; /* used at all? */
                                /*tex Insert the replacement glyph. */
                                if (q == replace) {
                                    replace = nb;
                                } else {
                                    tex_try_couple_nodes(node_prev(q), nb);
                                }
                                /*tex Append the glyph (one). */
                                tex_try_couple_nodes(nb, n);
                                /*tex Flush the disc. */
                                tex_flush_node(q);
                            }
                            q = n ;
                        }
                    }
                }
                /*tex Let's check if we have a penalty spec. If we have more then we're toast, we just ignore them. */
                if (uword[i] && uword[i + 1] == '[') {
                    i += 2;
                    if (uword[i] && uword[i] >= '0' && uword[i] <= '9') {
                        if (exception_penalty_par > 0) {
                            if (exception_penalty_par > infinite_penalty) {
                                penalty = exception_penalty_par;
                            } else {
                                penalty = (uword[i] - '0') * exception_penalty_par ;
                            }
                        } else {
                            penalty = hyphen_penalty_par;
                        }
                        ++i;
                        while (uword[i] && uword[i] != ']') {
                            ++i;
                        }
                    } else {
                        penalty = hyphen_penalty_par;
                    }
                } else {
                    penalty = hyphen_penalty_par;
                }
                /*tex And now we insert a disc node (this was |syllable_discretionary_code|). */
                t = tex_aux_insert_discretionary(t, pre, post, replace, normal_discretionary_code, penalty);
                /*tex We skip the new disc node. */
                t = node_next(t);
                /*tex 
                    We need to check if we have two discretionaries in a row, test case: |\hyphenation 
                    {a{>}{<}{b}{>}{<}{c}de} \hsize 1pt abcde \par| which gives |a> <> <de|. 
                */
                if (uword[i] && uword[i + 1] == '{') {
                    i--;
                    t = node_prev(t); /*tex Tricky! */
                }
            }
        } else {
            t = node_next(t);
        }
        /*tex Again we play safe. */
        if (! t || node_next(t) == r) {
            break;
        }
    }
}

/*tex

    The following description is no longer valid for \LUATEX. Although we use the same algorithm
    for hyphenation, it is not integrated in the par builder. Instead it is a separate run over
    the node list, preceding the line-breaking routine, possibly replaced by a callback. We keep
    the description here because the principles remain.

    \startnarrower

    When the line-breaking routine is unable to find a feasible sequence of breakpoints, it makes
    a second pass over the paragraph, attempting to hyphenate the hyphenatable words. The goal of
    hyphenation is to insert discretionary material into the paragraph so that there are more
    potential places to break.

    The general rules for hyphenation are somewhat complex and technical, because we want to be
    able to hyphenate words that are preceded or followed by punctuation marks, and because we
    want the rules to work for languages other than English. We also must contend with the fact
    that hyphens might radically alter the ligature and kerning structure of a word.

    A sequence of characters will be considered for hyphenation only if it belongs to a \quotation
    {potentially hyphenatable part} of the current paragraph. This is a sequence of nodes $p_0p_1
    \ldots p_m$ where $p_0$ is a glue node, $p_1\ldots p_{m-1}$ are either character or ligature
    or whatsit or implicit kern nodes, and $p_m$ is a glue or penalty or insertion or adjust or
    mark or whatsit or explicit kern node. (Therefore hyphenation is disabled by boxes, math
    formulas, and discretionary nodes already inserted by the user.) The ligature nodes among $p_1
    \ldots p_{m-1}$ are effectively expanded into the original non-ligature characters; the kern
    nodes and whatsits are ignored. Each character |c| is now classified as either a nonletter (if
    |lc_code(c)=0|), a lowercase letter (if |lc_code(c)=c|), or an uppercase letter (otherwise); an
    uppercase letter is treated as if it were |lc_code(c)| for purposes of hyphenation. The
    characters generated by $p_1\ldots p_{m-1}$ may begin with nonletters; let $c_1$ be the first
    letter that is not in the middle of a ligature. Whatsit nodes preceding $c_1$ are ignored; a
    whatsit found after $c_1$ will be the terminating node $p_m$. All characters that do not have
    the same font as $c_1$ will be treated as nonletters. The |hyphen_char| for that font must be
    between 0 and 255, otherwise hyphenation will not be attempted. \TeX\ looks ahead for as many
    consecutive letters $c_1\ldots c_n$ as possible; however, |n| must be less than 64, so a
    character that would otherwise be $c_{64}$ is effectively not a letter. Furthermore $c_n$ must
    not be in the middle of a ligature. In this way we obtain a string of letters $c_1\ldots c_n$
    that are generated by nodes $p_a\ldots p_b$, where |1<=a<=b+1<=m|. If |n>=l_hyf+r_hyf|, this
    string qualifies for hyphenation; however, |uc_hyph| must be positive, if $c_1$ is uppercase.

    The hyphenation process takes place in three stages. First, the candidate sequence $c_1 \ldots
    c_n$ is found; then potential positions for hyphens are determined by referring to hyphenation
    tables; and finally, the nodes $p_a\ldots p_b$ are replaced by a new sequence of nodes that
    includes the discretionary breaks found.

    Fortunately, we do not have to do all this calculation very often, because of the way it has
    been taken out of \TEX's inner loop. For example, when the second edition of the author's
    700-page book {\sl Seminumerical Algorithms} was typeset by \TEX, only about 1.2 hyphenations
    needed to be tried per paragraph, since the line breaking algorithm needed to use two passes on
    only about 5 per cent of the paragraphs. (This is not true in \LUATEX: we always hyphenate the
    whole list.)

    When a word been set up to contain a candidate for hyphenation, \TEX\ first looks to see if it
    is in the user's exception dictionary. If not, hyphens are inserted based on patterns that
    appear within the given word, using an algorithm due to Frank~M. Liang.

    \stopnarrower

    This is incompatible with \TEX\ because the first word of a paragraph can be hyphenated, but
    most European users seem to agree that prohibiting hyphenation there was not the best idea ever.

    To be documented: |\hyphenationmode| (a bit set).

    \startbuffer
    \parindent0pt \hsize=1.1cm
    12-34-56 \par
    12-34-\hbox{56} \par
    12-34-\vrule width 1em height 1.5ex \par
    12-\hbox{34}-56 \par
    12-\vrule width 1em height 1.5ex-56 \par
    \hjcode`\1=`\1 \hjcode`\2=`\2 \hjcode`\3=`\3 \hjcode`\4=`\4 \vskip.5cm
    12-34-56 \par
    12-34-\hbox{56} \par
    12-34-\vrule width 1em height 1.5ex \par
    12-\hbox{34}-56 \par
    12-\vrule width 1em height 1.5ex-56 \par
    \stopbuffer

    \typebuffer

    \startpacked \getbuffer \stopbuffer

    We only accept an explicit hyphen when there is a preceding glyph and we skip a sequence of
    explicit hyphens as that normally indicates a \type {--} or \type {---} ligature in which case
    we can in a worse case usage get bad node lists later on due to messed up ligature building as
    these dashes are ligatures in base fonts. This is a side effect of the separating the
    hyphenation, ligaturing and kerning steps. A test is cmr with \type {------}.

    A font handler can collapse successive hyphens but it's not nice to put the burden there. A
    somewhat messy border case is \type {----} but in \LUATEX\ we don't treat \type {--} and \type
    {---} special. Also, traditional \TEX\ will break a line at \type {-foo} but this can be
    disabled by setting the automatic mode to \type {1}.

*/

inline static halfword tex_aux_is_hyphen_char(halfword chr)
{
    if (tex_get_hc_code(chr)) {
        return tex_get_hc_code(chr);
    } else if (chr == ex_hyphen_char_par) {
        return ex_hyphen_char_par;
    } else {
        return null;
    }
}

static halfword tex_aux_find_next_wordstart(halfword r, halfword first_language)
{
    int start_ok = 1;
    halfword lastglyph = r;
    while (r) {
        switch (node_type(r)) {
            case boundary_node:
                if (node_subtype(r) == word_boundary) {
                    start_ok = 1;
                }
                break;
            case disc_node:
                start_ok = has_disc_option(r, disc_option_post_word);
                break;
            case hlist_node:
            case vlist_node:
            case rule_node:
            case dir_node:
            case whatsit_node:
                if (hyphenation_permitted(glyph_hyphenate(lastglyph), strict_start_hyphenation_mode)) {
                    start_ok = 0;
                }
                break;
            case glue_node:
                start_ok = 1;
                break;
            case math_node:
                if (node_subtype(r) == begin_inline_math) {
                    int mathlevel = 1;
                    while (mathlevel > 0) {
                        r = node_next(r);
                        if (! r) {
                            return r;
                        } else if (node_type(r) == math_node) {
                            if (node_subtype(r) == begin_inline_math) {
                                mathlevel++;
                            } else {
                                mathlevel--;
                            }
                        }
                    }
                }
                break;
            case glyph_node:
                {
                    /*tex
                        When we have no word yet and meet a hyphen (equivalent) we should just
                        keep going. This is not compatible but it does make sense.
                    */
                    int chr = glyph_character(r);
                    int hyp = tex_aux_is_hyphen_char(chr);
                    lastglyph = r;
                    if (hyp) {
                        if (hyphenation_permitted(glyph_hyphenate(r), ignore_bounds_hyphenation_mode)) {
                            /* maybe some tracing */
                        } else {
                            /* todo: already check if we have hj chars left/right i.e. no digits and minus mess */
                            halfword t = node_next(r) ;
                            /*tex Kind of weird that we have the opposite flag test here. */
                            if (t && (node_type(t) == glyph_node) && (! tex_aux_is_hyphen_char(glyph_character(t))) && ! hyphenation_permitted(glyph_hyphenate(r), automatic_hyphenation_mode)) {
                                /*tex We have no word yet and the next character is a non hyphen. */
                                r = tex_aux_compound_word_break(r, get_glyph_language(r), hyp);
                                // test case: \automatichyphenmode0 10\high{-6-1-2-4}
                                start_ok = 1; // todo: also in luatex
                            } else {
                                /*tex We jump over the sequence of hyphens. */
                                while (t && (node_type(t) == glyph_node) && tex_aux_is_hyphen_char(glyph_character(t))) {
                                    r = t ;
                                    t = node_next(r) ;
                                }
                                if (t) {
                                    /*tex We need a restart. */
                                    start_ok = 0;
                                } else {
                                    /*tex We reached the end of the list so we have no word start. */
                                    return null;
                                }
                            }
                        }
                    } else if (start_ok && (get_glyph_language(r) >= first_language) && get_glyph_dohyph(r)) {
                        int l = tex_get_hj_code(get_glyph_language(r), chr);
                        if (l > 0) {
                            if (l == chr || l <= 32 || get_glyph_uchyph(r)) {
                                return r;
                            } else {
                                start_ok = 0;
                            }
                        } else {
                            /*tex We go on. */
                        }
                    } else {
                        /*tex We go on. */
                    }
                }
                break;
            default:
                start_ok = 0;
                break;
        }
        r = node_next(r);
    }
    return r; /* null */
}

/*tex

    This is the original test, extended with bounds, but still the complex expression turned into
    a function.  However, it actually is part of the old mechanism where hyphenation was mixed
    with ligature building and kerning, so there was this skipping over a font kern whuch is no
    longer needed as we have separate steps.

    We keep this as reference:

    \starttyping
    static int valid_wordend(halfword s, halfword strict_bound)
    {
        if (s) {
            halfword r = s;
            int clang = get_glyph_language(s);
            while ( (r) &&
                   (    (type(r) == glyph_node && clang == get_glyph_language(r))
                     || (type(r) == kern_node && (subtype(r) == font_kern))
                    )
                   ) {
                r = node_next(r);
            }
            return (! r || (type(r) == glyph_node && clang != get_glyph_language(r))
                        ||  type(r) == glue_node
                        ||  type(r) == penalty_node
                        || (type(r) == kern_node && (subtype(r) == explicit_kern ||
                                                     subtype(r) == italic_kern   ||
                                                     subtype(r) == accent_kern   ))
                        ||  ((type(r) == hlist_node   ||
                              type(r) == vlist_node   ||
                              type(r) == rule_node    ||
                              type(r) == dir_node     ||
                              type(r) == whatsit_node ||
                              type(r) == insert_node  ||
                              type(r) == adjust_node
                             ) && ! (strict_bound == 2 || strict_bound == 3))
                        ||  type(r) == boundary_node
                );
        } else {
            return 1;
        }
    }
    \stopttyping

*/

static int tex_aux_valid_wordend(halfword end_word, halfword r)
{
    if (r) {
        switch (node_type(r)) {
         // case glyph_node:
         // case glue_node:
         // case penalty_node:
         // case kern_node:
         //     return 1;
            case disc_node:
                return has_disc_option(r, disc_option_pre_word);
            case hlist_node:
            case vlist_node:
            case rule_node:
            case dir_node:
            case whatsit_node:
            case insert_node:
            case adjust_node:
                return ! hyphenation_permitted(glyph_hyphenate(end_word), strict_end_hyphenation_mode);
        }
    }
    return 1;
}

void tex_handle_hyphenation(halfword head, halfword tail)
{
    if (head && node_next(head)) {
        int callback_id = lmt_callback_defined(hyphenate_callback);
        if (callback_id > 0) {
            lua_State *L = lmt_lua_state.lua_instance;
            int top = 0;
            if (lmt_callback_okay(L, callback_id, &top)) {
                int i;
                lmt_node_list_to_lua(L, head);
                lmt_node_list_to_lua(L, tail);
                i = lmt_callback_call(L, 2, 0, top);
                if (i) {
                    lmt_callback_error(L, top, i);
                } else {
                    lmt_callback_wrapup(L, top);
                }
            }
        } else if (callback_id == 0) {
            tex_hyphenate_list(head, tail);
        } else {
            /* -1 : disabled */
        }
    }
}

static int tex_aux_hnj_hyphen_hyphenate(
    hjn_dictionary *dict,
    halfword        first,
    halfword        last,
    int             length,
    halfword        left,
    halfword        right,
    lang_variables *lan
)
{
    /*tex +2 for dots at each end, +1 for points outside characters. */
    int ext_word_len = length + 2;
    int hyphen_len = ext_word_len + 1;
    /*tex Because we have a limit of 64 characters we could just use a static array here: */
    char *hyphens = lmt_memory_calloc(hyphen_len, sizeof(unsigned char));
    if (hyphens) {
        halfword here;
        int state = 0;
        int char_num = 0;
        int done = 0;
        /*tex Add a '.' to beginning and end to facilitate matching. */
        node_next(begin_period) = first;
        node_next(end_period) = node_next(last);
        node_next(last) = end_period;

     // for (int i = 0; i < hyphen_len; i++) {
     //     hyphens[i] = '0';
     // }
     // hyphens[hyphen_len] = 0;

        /*tex Now, run the finite state machine. */
        for (char_num = 0, here = begin_period; here != node_next(end_period); here = node_next(here)) {
            int ch;
            if (here == begin_period || here == end_period) {
                ch = '.';
            } else {
                ch = tex_get_hj_code(get_glyph_language(here), glyph_character(here));
                if (ch <= 32) {
                    ch = glyph_character(here);
                }
            }
            while (state != -1) {
                hjn_state *hstate = &dict->states[state];
                for (int k = 0; k < hstate->num_trans; k++) {
                    if (hstate->trans[k].uni_ch == ch) {
                        char *match;
                        state = hstate->trans[k].new_state;
                        match = dict->states[state].match;
                        if (match) {
                            /*tex
                                We add +2 because 1 string length is one bigger than offset and 1
                                hyphenation starts before first character.

                                Why not store the length in states[state] instead of calculating
                                it each time? Okay, performance is okay but still ...
                            */
                            int offset = (int) (char_num + 2 - (int) strlen(match));
                            for (int m = 0; match[m]; m++) {
                                if (hyphens[offset + m] < match[m]) {
                                    hyphens[offset + m] = match[m];
                                }
                            }
                        }
                        goto NEXTLETTER;
                    }
                }
                state = hstate->fallback_state;
            }
            /*tex Nothing worked, let's go to the next character. */
            state = 0;
        NEXTLETTER:;
            char_num++;
        }
        /*tex Restore the correct pointers. */
        node_next(last) = node_next(end_period);
        /*tex
            Pattern is |.word.| and |word_len| is 4, |ext_word_len| is 6 and |hyphens| is 7; drop first
            two and stop after |word_len-1|.
         */
        for (here = first, char_num = 2; here != left; here = node_next(here)) {
            char_num++;
        }
        for (; here != right; here = node_next(here)) {
            if (hyphens[char_num] & 1) {
                here = tex_aux_insert_syllable_discretionary(here, lan);
                done += 1;
            }
            char_num++;
        }
        lmt_memory_free(hyphens);
        return done;
    } else {
        tex_overflow_error("patterns", hyphen_len);
        return 0;
    }
}

/* we can also check the original */

static int tex_aux_still_okay(halfword f, halfword l, halfword r, int n, const char *utf8original) {
    if (_valid_node_(f) && _valid_node_(l) && node_next(l) == r) {
        int i = 0;
        while (f) {
            ++i;
            if (node_type(f) != glyph_node) {
                tex_normal_warning("language", "the hyphenated word contains non-glyphs, skipping");
                return 0;
            } else {
                int cl; 
                halfword c = (halfword) aux_str2uni_len((const unsigned char *) utf8original, &cl);
                utf8original += cl;
                if (! (c && c == glyph_character(f))) {
                    tex_normal_warning("language", "the hyphenated word contains different characters, skipping");
                    return 0;
                } else if (f != l) {
                    f = node_next(f);
                } else if (i == n) {
                    return 1;
                } else {
                    tex_normal_warning("language", "the hyphenated word changed length, skipping");
                    return 0;
                }
            }
        }
    }
    tex_normal_warning("language", "the hyphenation list is messed up, skipping");
    return 0;
}

static void tex_aux_hyphenate_show(halfword beg, halfword end)
{
    if (_valid_node_(beg) && _valid_node_(end)) {
        halfword nxt = node_next(end);
        node_next(end) = null;
        tex_show_node_list(beg, 100, 10000);
        node_next(end) = nxt;
    }
}

/* maybe split: first a processing run */

inline static int is_traditional_hyphen(halfword n)
{
    return (
        (glyph_character(n) == ex_hyphen_char_par)                             /*tex parameter */
     && (has_font_text_control(glyph_font(n),text_control_collapse_hyphens))   /*tex font driven */
     && (hyphenation_permitted(glyph_hyphenate(n), collapse_hyphenation_mode)) /*tex language driven */
    );
}

int tex_collapse_list(halfword head, halfword c1, halfword c2, halfword c3) /* ex_hyphen_char_par 0x2013 0x2014 */
{
    /*tex Let's play safe: */
    halfword found = 0;
    if (head && c1 && c2 && c3) {
        halfword n1 = head;
        while (n1) {
            halfword n2 = node_next(n1);
            switch (node_type(n1)) {
                case glyph_node:
                    if (is_traditional_hyphen(n1)) {
                        set_glyph_discpart(n1, glyph_discpart_always);
                        if (n2 && node_type(n2) == glyph_node && is_traditional_hyphen(n2) && glyph_font(n1) == glyph_font(n2)) {
                            halfword n3 = node_next(n2);
                            if (n3 && node_type(n3) == glyph_node && is_traditional_hyphen(n3) && glyph_font(n1) == glyph_font(n3)) {
                                halfword n4 = node_next(n3);
                                glyph_character(n1) = c3;
                                tex_try_couple_nodes(n1, n4);
                                tex_flush_node(n2);
                                tex_flush_node(n3);
                                n1 = n4;
                            } else {
                                glyph_character(n1) = c2;
                                tex_try_couple_nodes(n1, n3);
                                tex_flush_node(n2);
                                n1 = n3;
                            }
                            found = 1;
                            goto AGAIN;
                        } else {
                            glyph_character(n1) = c1; /* can become language dependent */
                        }
                    }
                    break;
                case disc_node:
                    {
                        halfword done = 0;
                        if (disc_pre_break_head(n1) && tex_collapse_list(disc_pre_break_head(n1), c1, c2, c3)) {
                            ++done;
                        }
                        if (disc_post_break_head(n1) && tex_collapse_list(disc_post_break_head(n1), c1, c2, c3)) {
                            ++done;
                        }
                        if (disc_no_break_head(n1) && tex_collapse_list(disc_no_break_head(n1), c1, c2, c3)) {
                            ++done;
                        }
                        if (done) {
                            tex_check_disc_field(n1);
                        }
                        break;
                    }
                default:
                    break;
            }
            n1 = n2;
          AGAIN:;
        }
    }
    return found;
}

void tex_hyphenate_list(halfword head, halfword tail)
{
    /*tex Let's play safe: */
    if (tail) {
        halfword first_language = first_valid_language_par; /* combine with check below */
        halfword trace = tracing_hyphenation_par;
        halfword r = head;
        /*tex
            This first movement assures two things:

            \startitemize
                \startitem
                    That we won't waste lots of time on something that has been handled already (in
                    that case, none of the glyphs match |simple_character|).
                \stopitem
                \startitem
                    That the first word can be hyphenated. If the movement was not explicit, then
                    the indentation at the start of a paragraph list would make |find_next_wordstart()|
                    look too far ahead.
                \stopitem
            \stopitemize
        */
        while (r && node_type(r) != glyph_node) {
            r = node_next(r);
        }
        if (r) {
            r = tex_aux_find_next_wordstart(r, first_language);
            if (r) {
                lang_variables langdata;
                char utf8word[(4 * max_size_of_word) + 1] = { 0 };
                char utf8original[(4 * max_size_of_word) + 1] = { 0 };
                char *utf8ptr = utf8word;
                char *utf8ori = utf8original;
                int word_length = 0;
                int explicit_hyphen = 0;
                int last_char = 0;
                int valid = 0;
                halfword explicit_start = null;
                halfword saved_tail = node_next(tail);
                halfword penalty = tex_new_penalty_node(0, word_penalty_subtype);
                /* kind of curious hack, this addition that we later remove */
                tex_attach_attribute_list_copy(penalty, r);
                tex_couple_nodes(tail, penalty); /* todo: attrobute */
                while (r) {
                    halfword word_start = r;
                    int word_language = get_glyph_language(word_start);
                    if (tex_is_valid_language(word_language)) {
                        halfword word_end = r;
                        int lhmin = get_glyph_lhmin(word_start);
                        int rhmin = get_glyph_rhmin(word_start);
                        int hmin = tex_get_hyphenation_min(word_language);
                        halfword word_font = glyph_font(word_start);
                        if (! tex_is_valid_font(word_font) || font_hyphen_char(word_font) < 0) {
                            /*tex For backward compatibility we set: */
                            word_font = 0;
                        }
                        langdata.pre_hyphen_char = tex_get_pre_hyphen_char(word_language);
                        langdata.post_hyphen_char = tex_get_post_hyphen_char(word_language);
                        while (r && node_type(r) == glyph_node && word_language == get_glyph_language(r)) {
                            halfword chr = glyph_character(r);
                            halfword hyp = tex_aux_is_hyphen_char(chr);
                            if (word_language >= first_language) {
                                last_char = tex_get_hj_code(word_language, chr);
                                if (last_char > 0) {
                                    goto GOFORWARD;
                                }
                            }
                            if (hyp) {
                                last_char = hyp;
                             // if (last_char) {
                             //     goto GOFORWARD;
                             // }
                            } else {
                                break;
                            }
                          GOFORWARD:
                         // explicit_hyphen = is_hyphen_char(chr);
                            explicit_hyphen = hyp;
                            if (explicit_hyphen && node_next(r) && node_type(node_next(r)) != glyph_node && hyphenation_permitted(glyph_hyphenate(r), ignore_bounds_hyphenation_mode)) {
                                /* maybe some tracing */
                                explicit_hyphen = 0;
                            }
                            if (explicit_hyphen) {
                                break;
                            } else {
                                word_length++;
                                if (word_length >= max_size_of_word) {
                                    /* tex_normal_warning("language", "ignoring long word"); */
                                    while (r && node_type(r) == glyph_node) {
                                        r = node_next(r);
                                    }
                                    goto PICKUP;
                                } else {
                                    if (last_char <= 32) {
                                        if (last_char == 32) {
                                            last_char = 0 ;
                                        }
                                        if (word_length <= lhmin) {
                                            lhmin = lhmin - last_char + 1 ;
                                            if (lhmin < 0) {
                                                lhmin = 1;
                                            }
                                        }
                                        if (word_length >= rhmin) {
                                            rhmin = rhmin - last_char + 1 ;
                                            if (rhmin < 0) {
                                                rhmin = 1;
                                            }
                                        }
                                        hmin = hmin - last_char + 1 ;
                                        if (hmin < 0) {
                                            rhmin = 1;
                                        }
                                        last_char = chr ;
                                    }
                                    utf8ori = aux_uni2string(utf8ori, (unsigned) chr);
                                    utf8ptr = aux_uni2string(utf8ptr, (unsigned) last_char);
                                    word_end = r;
                                    r = node_next(r);
                                }
                            }
                        }
                        if (explicit_hyphen) {
                            /*tex We are not at the start, so we only need to look ahead. */
                            if ((get_glyph_discpart(r) == glyph_discpart_replace && ! hyphenation_permitted(glyph_hyphenate(r), syllable_hyphenation_mode))) {
                                /*tex
                                    This can be the consequence of inhibition too, see |finish_discretionary|
                                    in which case the replace got injected which can have a hyphen. And we want
                                    to run the callback if set in order to replace.
                                */
                                valid = 1;
                                goto MESSYCODE;
                            } else {
                                /*tex Maybe we should get rid of this ----- stuff. */
                                halfword t = node_next(r);
                                if (t && node_type(t) == glyph_node && ! tex_aux_is_hyphen_char(glyph_character(t)) && hyphenation_permitted(glyph_hyphenate(t), automatic_hyphenation_mode)) {
                                    /*tex we have a word already but the next character may not be a hyphen too */
                                    halfword g = r;
                                    r = tex_aux_compound_word_break(r, get_glyph_language(g), explicit_hyphen);
                                    if (trace > 1) {
                                        *utf8ori = 0;
                                        tex_begin_diagnostic();
                                        tex_print_format("[language: compound word break after %s]", utf8original);
                                        tex_end_diagnostic();
                                    }
                                    if (hyphenation_permitted(glyph_hyphenate(g), compound_hyphenation_mode)) {
                                        explicit_hyphen = 0;
                                        if (hyphenation_permitted(glyph_hyphenate(g), force_handler_hyphenation_mode) || hyphenation_permitted(glyph_hyphenate(g), feedback_compound_hyphenation_mode)) {
                                            set_disc_option(r, disc_option_pre_word | disc_option_post_word);
                                            explicit_start = null;
                                            valid = 1;
                                            goto MESSYCODE;
                                        } else {
                                            if (! explicit_start) {
                                                explicit_start = word_start;
                                            }
                                            /*tex For exceptions. */
                                            utf8ptr = aux_uni2string(utf8ptr, '-');
                                            r = t;
                                            continue;
                                        }
                                    }
                                } else {
                                    /*tex We jump over the sequence of hyphens ... traditional. */
                                    while (t && node_type(t) == glyph_node && tex_aux_is_hyphen_char(glyph_character(t))) {
                                        r = t;
                                        t = node_next(r);
                                    }
                                    if (! t) {
                                        /*tex we reached the end of the list and will quit the loop later */
                                        r = null;
                                    }
                                }
                            }
                        } else {
                            valid = tex_aux_valid_wordend(word_end, r);
                          MESSYCODE:
                            /*tex We have a word, r is at the next node. */
                            if (word_font && word_language >= first_language) {
                                /*tex We have a language, actually we already tested that. */
                                struct tex_language *lang = lmt_language_state.languages[word_language];
                                if (lang) {
                                    char *replacement = NULL;
                                    halfword start = explicit_start ? explicit_start : word_start;
                                    int okay = word_length >= lhmin + rhmin && (hmin <= 0 || word_length >= hmin) && hyphenation_permitted(glyph_hyphenate(start), syllable_hyphenation_mode);
                                    *utf8ptr = 0;
                                    *utf8ori = 0;
                                    if (lang->wordhandler && hyphenation_permitted(glyph_hyphenate(start), force_handler_hyphenation_mode)) {
                                        halfword restart = node_prev(start); /*tex before the word. */
                                        int done = lmt_handle_word(lang, utf8original, utf8word, word_length, start, word_end, &replacement);
                                        if (replacement) {
                                            if (tex_aux_still_okay(start, word_end, r, word_length, utf8original)) {
                                                goto EXCEPTIONS2;
                                            } else {
                                                goto PICKUP;
                                            }
                                        } else {
                                            /* 1: restart 2: exceptions+patterns 3: patterns *: next word */
                                            switch (done) {
                                                case 1:
                                                    if (_valid_node_(restart)) {
                                                        r = restart;
                                                    } else if (_valid_node_(start)) {
                                                        r = node_prev(start);
                                                    }
                                                    if (! r) {
                                                        if (_valid_node_(head)) {
                                                            tex_normal_warning("language", "the hyphenation list is messed up, recovering");
                                                            r = head;
                                                        } else {
                                                            tex_normal_error("language", "the hyphenated head is messed up, aborting");
                                                            return;
                                                        }
                                                    }
                                                    goto PICKUP;
                                                case 2:
                                                    if (tex_aux_still_okay(start, word_end, r, word_length, utf8original)) {
                                                        goto EXCEPTIONS1;
                                                    } else {
                                                        goto PICKUP;
                                                    }
                                                case 3:
                                                    if (tex_aux_still_okay(start, word_end, r, word_length, utf8original)) {
                                                        goto PATTERNS;
                                                    } else {
                                                        goto PICKUP;
                                                    }
                                                default:
                                                    if (_valid_node_(r)) { /* or word_end */
                                                        goto PICKUP;
                                                    } else if (_valid_node_(tail)) {
                                                        tex_normal_warning("language", "the hyphenation list is messed up, quitting");
                                                        goto ABORT;
                                                    } else {
                                                        // tex_normal_error("language","the hyphenated tail is messed up, aborting");
                                                        return;
                                                    }
                                            }
                                        }
                                    }
                                    if (! okay || ! valid) {
                                        goto PICKUP;
                                    }
                                    /*tex
                                        This is messy and nasty: we can have a word with a - in it which is why
                                        we have two branches. Also, every word that suits the length criteria
                                        is checked via \LUA. Optimizing this because tests have demonstrated
                                        that checking against the min and max lengths of exception strings has
                                        no gain.
                                    */
                                  EXCEPTIONS1:
                                    if (lang->exceptions) {
                                        replacement = tex_aux_hyphenation_exception(lang->exceptions, utf8word);
                                    }
                                  EXCEPTIONS2:
                                    if (replacement) {
                                        /*tex handle the exception and go on to the next word */
                                        halfword start = explicit_start ? explicit_start : word_start;
                                        halfword beg = node_prev(start);
                                        tex_aux_do_exception(start, r, replacement); // r == next_node(word_end)
                                        if (trace > 1) {
                                            tex_begin_diagnostic();
                                            tex_print_format("[language: exception %s to %s]", utf8original, replacement);
                                            if (trace > 2) {
                                                tex_aux_hyphenate_show(node_next(beg), node_prev(r));
                                            }
                                            tex_end_diagnostic();
                                        }
                                        lmt_memory_free(replacement);
                                        goto PICKUP;
                                    }
                                    PATTERNS:
                                    if (lang->patterns) {
                                        if (explicit_start) {
                                            /*tex We're done already */
                                        } else if (hyphenation_permitted(glyph_hyphenate(word_start), syllable_hyphenation_mode)) {
                                            halfword left = word_start;
                                            halfword right = r; /*tex We're one after |word_end|. */
                                            for (int i = lhmin; i > 1; i--) {
                                                left = node_next(left);
                                                if (! left || left == right) {
                                                    goto PICKUP;
                                                }
                                            }
                                            if (right != left) {
                                                int done = 0;
                                                for (int i = rhmin; i > 0; i--) {
                                                    right = node_prev(right);
                                                    if (! right || right == left) {
                                                        goto PICKUP;
                                                    }
                                                }
                                                done = tex_aux_hnj_hyphen_hyphenate(lang->patterns, word_start, word_end, word_length, left, right, &langdata);
                                                if (trace > 1) {
                                                    tex_begin_diagnostic();
                                                    if (done) {
                                                        tex_print_format("[language: hyphenated %s at %i positions]", utf8original, done);
                                                        if (trace > 2) {
                                                            tex_aux_hyphenate_show(node_next(left), node_prev(right));
                                                        }
                                                    } else {
                                                        tex_print_format("[language: not hyphenated %s]", utf8original);
                                                    }
                                                    tex_end_diagnostic();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                  PICKUP:
                    explicit_start = null ;
                    explicit_hyphen = 0;
                    word_length = 0;
                    utf8ptr = utf8word;
                    utf8ori = utf8original;
                    if (r) {
                        r = tex_aux_find_next_wordstart(r, first_language);
                    } else {
                        break;
                    }
                }
              ABORT:
                tex_flush_node(node_next(tail));
                node_next(tail) = saved_tail;
            }
        }
    }
}

halfword tex_glyph_to_discretionary(halfword glyph, quarterword code, int keepkern)
{
    halfword prev = node_prev(glyph);
    halfword next = node_next(glyph);
    halfword disc = tex_new_disc_node(code);
    halfword kern = null;
    if (keepkern && next && node_type(next) == kern_node && node_subtype(next) == italic_kern_subtype) {
        kern = node_next(next);
        next = node_next(kern);
        node_next(kern) = null;
    } else { 
        node_next(glyph) = null;
    }
    node_prev(glyph) = null;
    tex_attach_attribute_list_copy(disc, glyph);
    tex_set_disc_field(disc, pre_break_code, tex_copy_node_list(glyph, null));
    tex_set_disc_field(disc, post_break_code, tex_copy_node_list(glyph, null));
    tex_set_disc_field(disc, no_break_code, glyph);
    tex_try_couple_nodes(prev, disc);
    tex_try_couple_nodes(disc, next);
    return disc; 
}