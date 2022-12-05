/*
    See license.txt in the root of this project.
*/

/*tex

    This file hosts the encapsulated \PDF\ support code used for inclusion and access from \LUA.

*/

# include "luametatex.h"

// # define PDFE_METATABLE_INSTANCE   "pdfe.instance"
// # define PDFE_METATABLE_DICTIONARY "pdfe.dictionary"
// # define PDFE_METATABLE_ARRAY      "pdfe.array"
// # define PDFE_METATABLE_STREAM     "pdfe.stream"
// # define PDFE_METATABLE_REFERENCE  "pdfe.reference"

# include "../libraries/pplib/pplib.h"

/*tex

    We start with some housekeeping. Dictionaries, arrays, streams and references get userdata,
    while strings, names, integers, floats and booleans become regular \LUA\ objects. We need to
    define a few metatable identifiers too.

*/

typedef struct pdfe_document {
    ppdoc *document;
    int    open;
    int    isfile;
    char  *memstream;
    int    pages;
    int    index;
} pdfe_document ;

typedef struct pdfe_dictionary {
    ppdict *dictionary;
} pdfe_dictionary;

typedef struct pdfe_array {
    pparray *array;
} pdfe_array;

typedef struct pdfe_stream {
    ppstream *stream;
    int       decode;
    int       open;
} pdfe_stream;

typedef struct pdfe_reference {
 /* ppref  *reference; */
    ppxref *xref;
    int     onum;
} pdfe_reference;

/*tex

    We need to check if we have the right userdata. A similar warning is issued when encounter a
    problem. We don't exit.

*/

static void pdfe_invalid_object_warning(const char *detail)
{
    tex_formatted_warning("pdfe lib", "lua <pdfe %s> expected",detail);
}

/* todo: use luaL_checkudata */

static pdfe_document *pdfelib_aux_check_isdocument(lua_State *L, int n)
{
    pdfe_document *p = (pdfe_document *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(pdfe_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    pdfe_invalid_object_warning("document");
    return NULL;
}

static pdfe_dictionary *pdfelib_aux_check_isdictionary(lua_State *L, int n)
{
    pdfe_dictionary *p = (pdfe_dictionary *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(pdfe_dictionary_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    pdfe_invalid_object_warning("dictionary");
    return NULL;
}

static pdfe_array *pdfelib_aux_check_isarray(lua_State *L, int n)
{
    pdfe_array *p = (pdfe_array *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(pdfe_array_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    pdfe_invalid_object_warning("array");
    return NULL;
}

static pdfe_stream *pdfelib_aux_check_isstream(lua_State *L, int n)
{
    pdfe_stream *p = (pdfe_stream *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(pdfe_stream_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    pdfe_invalid_object_warning("stream");
    return NULL;
}

static pdfe_reference *pdfelib_aux_check_isreference(lua_State *L, int n)
{
    pdfe_reference *p = (pdfe_reference *) lua_touserdata(L, n);
    if (p && lua_getmetatable(L, n)) {
        lua_get_metatablelua(pdfe_reference_instance);
        if (! lua_rawequal(L, -1, -2)) {
            p = NULL;
        }
        lua_pop(L, 2);
        if (p) {
            return p;
        }
    }
    pdfe_invalid_object_warning("reference");
    return NULL;
}

/*tex

    Reporting the type of a userdata is just a sequence of tests till we find the right one. We
    return nothing is it is no pdfe type.

 \starttyping
    t = pdfe.type(<pdfe document|dictionary|array|reference|stream>)
 \stoptyping

*/

/*
# define check_type(field,meta,name) do { \
    lua_get_metatablelua(meta); \
    if (lua_rawequal(L, -1, -2)) { \
        lua_pushstring(L, name); \
        return 1; \
    } \
    lua_pop(L, 1); \
} while (0)

static int pdfelib_type(lua_State *L)
{
    void *p = lua_touserdata(L, 1);
    if (p && lua_getmetatable(L, 1)) {
        check_type(document,   pdfe_instance,   PDFE_METATABLE_INSTANCE);
        check_type(dictionary, pdfe_dictionary, PDFE_METATABLE_DICTIONARY);
        check_type(array,      pdfe_array,      PDFE_METATABLE_ARRAY);
        check_type(reference,  pdfe_reference,  PDFE_METATABLE_REFERENCE);
        check_type(stream,     pdfe_stream,     PDFE_METATABLE_STREAM);
    }
    return 0;
}
*/

# define check_type(field,meta) do { \
    lua_get_metatablelua(meta); \
    if (lua_rawequal(L, -1, -2)) { \
        lua_push_key(meta); \
        return 1; \
    } \
    lua_pop(L, 1); \
} while (0)

static int pdfelib_type(lua_State *L)
{
    void *p = lua_touserdata(L, 1);
    if (p && lua_getmetatable(L, 1)) {
        check_type(document, pdfe_instance);
        check_type(dictionary, pdfe_dictionary_instance);
        check_type(array, pdfe_array_instance);
        check_type(reference, pdfe_reference_instance);
        check_type(stream, pdfe_stream_instance);
    }
    return 0;
}

/*tex

    The \type {tostring} metamethods are similar and report a pdfe type plus a pointer value, as is
    rather usual in \LUA. I ditched the macro that defined them and are now verbose.

*/

static int pdfelib_document_tostring(lua_State *L) {
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        lua_pushfstring(L, "<pdfe.document %p>", p->document);
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_dictionary_tostring(lua_State *L) {
    pdfe_dictionary *p = pdfelib_aux_check_isdictionary(L, 1);
    if (p) {
        lua_pushfstring(L, "<pdfe.dictionary %p>", p->dictionary);
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_array_tostring(lua_State *L) {
    pdfe_array *p = pdfelib_aux_check_isarray(L, 1);
    if (p) {
        lua_pushfstring(L, "<pdfe.array %p>", p->array);
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_stream_tostring(lua_State *L) {
    pdfe_stream *p = pdfelib_aux_check_isstream(L, 1);
    if (p) {
        lua_pushfstring(L, "<pdfe.stream %p>", p->stream);
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_reference_tostring(lua_State *L) {
    pdfe_reference *p = pdfelib_aux_check_isreference(L, 1);
    if (p) {
        lua_pushfstring(L, "<pdfe.reference %d>", p->onum);
        return 1;
    } else {
        return 0;
    }
}

/*tex

    The pushers look rather similar. We have two variants, one that just pushes the object, and
    another that also pushes some extra information.

*/

inline static void pdfe_push_dictionary(lua_State *L, ppdict *dictionary)
{
    pdfe_dictionary *d = (pdfe_dictionary *) lua_newuserdatauv(L, sizeof(pdfe_dictionary), 0);
 // luaL_getmetatable(L, PDFE_METATABLE_DICTIONARY);
    lua_get_metatablelua(pdfe_dictionary_instance);
    lua_setmetatable(L, -2);
    d->dictionary = dictionary;
}

static int pdfelib_aux_pushdictionary(lua_State *L, ppdict *dictionary)
{
    if (dictionary) {
        pdfe_push_dictionary(L, dictionary);
        lua_pushinteger(L, (lua_Integer) dictionary->size);
        return 2;
    } else {
        return 0;
    }
}

static int pdfelib_aux_pushdictionaryonly(lua_State *L, ppdict *dictionary)
{
    if (dictionary) {
        pdfe_push_dictionary(L, dictionary);
        return 1;
    } else {
        return 0;
    }
}

inline static void pdfe_push_array(lua_State *L, pparray *array)
{
    pdfe_array *a = (pdfe_array *) lua_newuserdatauv(L, sizeof(pdfe_array), 0);
 // luaL_getmetatable(L, PDFE_METATABLE_ARRAY);
    lua_get_metatablelua(pdfe_array_instance);
    lua_setmetatable(L, -2);
    a->array = array;
}

static int pdfelib_aux_pusharray(lua_State *L, pparray *array)
{
    if (array) {
        pdfe_push_array(L, array);
        lua_pushinteger(L, (lua_Integer) array->size);
        return 2;
    } else {
        return 0;
    }
}

static int pdfelib_aux_pusharrayonly(lua_State *L, pparray *array)
{
    if (array) {
        pdfe_push_array(L, array);
        return 1;
    } else {
        return 0;
    }
}

inline static void pdfe_push_stream(lua_State *L, ppstream *stream)
{
    pdfe_stream *s = (pdfe_stream *) lua_newuserdatauv(L, sizeof(pdfe_stream), 0);
 // luaL_getmetatable(L, PDFE_METATABLE_STREAM);
    lua_get_metatablelua(pdfe_stream_instance);
    lua_setmetatable(L, -2);
    s->stream = stream;
    s->open = 0;
    s->decode = 0;
}

static int pdfelib_aux_pushstream(lua_State *L, ppstream *stream)
{
    if (stream) {
        pdfe_push_stream(L, stream);
        if (pdfelib_aux_pushdictionary(L, stream->dict) > 0) {
            return 3;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}

static int pdfelib_aux_pushstreamonly(lua_State *L, ppstream *stream)
{
    if (stream) {
        pdfe_push_stream(L, stream);
        if (pdfelib_aux_pushdictionaryonly(L, stream->dict) > 0) {
            return 2;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}

inline static void pdfe_push_reference(lua_State *L, ppref *reference)
{
    pdfe_reference *r = (pdfe_reference *) lua_newuserdatauv(L, sizeof(pdfe_reference), 0);
 // luaL_getmetatable(L, PDFE_METATABLE_REFERENCE);
    lua_get_metatablelua(pdfe_reference_instance);
    lua_setmetatable(L, -2);
    r->xref = reference->xref;
    r->onum = (int) reference->number;
 }

static int pdfelib_aux_pushreference(lua_State *L, ppref *reference)
{
    if (reference && reference->number != 0) {
        pdfe_push_reference(L, reference);
        lua_pushinteger(L, (lua_Integer) reference->number);
        return 2;
    } else {
        return 0;
    }
}

/*tex

    The next function checks for the type and then pushes the matching data on the stack.

    \starttabulate[|c|l|l|l|]
        \BC type \BC meaning \BC value \BC detail \NC \NR
        \NC \type {0} \NC none \NC nil \NC \NC \NR
        \NC \type {1} \NC null \NC nil \NC \NC \NR
        \NC \type {2} \NC boolean \NC boolean \NC \NC \NR
        \NC \type {3} \NC boolean \NC integer \NC \NC \NR
        \NC \type {4} \NC number \NC float \NC \NC \NR
        \NC \type {5} \NC name \NC string \NC \NC \NR
        \NC \type {6} \NC string \NC string \NC type \NC \NR
        \NC \type {7} \NC array \NC arrayobject \NC size \NC \NR
        \NC \type {8} \NC dictionary \NC dictionaryobject \NC size \NC \NR
        \NC \type {9} \NC stream \NC streamobject \NC dictionary size \NC \NR
        \NC \type {10} \NC reference \NC integer \NC \NC \NR
        \LL
    \stoptabulate

    A name and string can be distinguished by the extra type value that a string has.

*/

static int pdfelib_aux_pushvalue(lua_State *L, ppobj *object)
{
    switch (object->type) {
        case PPNONE:
        case PPNULL:
            lua_pushnil(L);
            return 1;
        case PPBOOL:
            lua_pushboolean(L, (int) object->integer);
            return 1;
        case PPINT:
            lua_pushinteger(L, (lua_Integer) object-> integer);
            return 1;
        case PPNUM:
            lua_pushnumber(L, (double) object->number);
            return 1;
        case PPNAME:
            {
                ppname *n = ppname_decoded(object->name) ;
                lua_pushlstring(L, ppname_data(n), ppname_size(n));
                return 1;
            }
        case PPSTRING:
            lua_pushlstring(L, ppstring_data(object->string), ppstring_size(object->string));
            lua_pushboolean(L, ppstring_hex(object->string));
            return 2;
        case PPARRAY:
            return pdfelib_aux_pusharray(L, object->array);
        case PPDICT:
            return pdfelib_aux_pushdictionary(L, object->dict);
        case PPSTREAM:
            return pdfelib_aux_pushstream(L, object->stream);
        case PPREF:
            return pdfelib_aux_pushreference(L, object->ref);
    }
    return 0;
}

/*tex

    We need to start someplace when we traverse a document's tree. There are three places:

    \starttyping
    catalogdictionary = getcatalog(documentobject)
    trailerdictionary = gettrailer(documentobject)
    infodictionary    = getinfo   (documentobject)
    \stoptyping

*/

static int pdfelib_getcatalog(lua_State *L)
{
    pdfe_document* p = pdfelib_aux_check_isdocument (L, 1);
    if (p) {
        return pdfelib_aux_pushdictionaryonly (L, ppdoc_catalog (p->document));
    } else {
        return 0;
    }
}

static int pdfelib_gettrailer(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        return pdfelib_aux_pushdictionaryonly (L, ppdoc_trailer (p->document));
    } else {
        return 0;
    }
}

static int pdfelib_getinfo(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        return pdfelib_aux_pushdictionaryonly (L, ppdoc_info (p->document));
    } else {
        return 0;
    }
}

/*tex

    We have three more helpers.

    \starttyping
    [key,] type, value, detail = getfromdictionary(dictionaryobject,name|index)
           type, value, detail = getfromarray     (arrayobject,index)
    [key,] type, value, detail = getfromstream    (streamobject,name|index)
    \stoptyping

*/

static int pdfelib_getfromarray(lua_State *L)
{
    pdfe_array *a = pdfelib_aux_check_isarray(L, 1);
    if (a) {
        unsigned int index = lmt_checkinteger(L, 2) - 1;
        if (index < a->array->size) {
            ppobj *object = pparray_at(a->array,index);
            if (object) {
                lua_pushinteger(L, (lua_Integer) object->type);
                return 1 + pdfelib_aux_pushvalue(L, object);
            }
        }
    }
    return 0;
}

static int pdfelib_getfromdictionary(lua_State *L)
{
    pdfe_dictionary *d = pdfelib_aux_check_isdictionary(L, 1);
    if (d) {
        if (lua_type(L, 2) == LUA_TSTRING) {
            const char *name = luaL_checkstring(L, 2);
            ppobj *object = ppdict_get_obj(d->dictionary, name);
            if (object) {
                lua_pushinteger(L, (lua_Integer) object->type);
                return 1 + pdfelib_aux_pushvalue(L, object);
            }
        } else {
            unsigned int index = lmt_checkinteger(L, 2) - 1;
            if (index < d->dictionary->size) {
                ppobj *object = ppdict_at(d->dictionary,index);
                if (object) {
                    ppname *key = ppname_decoded(ppdict_key(d->dictionary, index));
                    lua_pushlstring(L, ppname_data(key), ppname_size(key));
                    lua_pushinteger(L, (lua_Integer) object->type);
                    return 2 + pdfelib_aux_pushvalue(L, object);
                }
            }
        }
    }
    return 0;
}

static int pdfelib_getfromstream(lua_State *L)
{
    pdfe_stream *s = (pdfe_stream *) lua_touserdata(L, 1);
 // pdfe_stream *s = check_isstream(L, 1);
    if (s) {
        ppdict *d = s->stream->dict;
        if (lua_type(L, 2) == LUA_TSTRING) {
            const char *name = luaL_checkstring(L, 2);
            ppobj *object = ppdict_get_obj(d, name);
            if (object) {
                lua_pushinteger(L, (lua_Integer) object->type);
                return 1 + pdfelib_aux_pushvalue(L, object);
            }
        } else {
            unsigned int index = lmt_checkinteger(L, 2) - 1;
            if (index < d->size) {
                ppobj *object = ppdict_at(d, index);
                if (object) {
                    ppname *key = ppname_decoded(ppdict_key(d, index));
                    lua_pushlstring(L, ppname_data(key), ppname_size(key));
                    lua_pushinteger(L, (lua_Integer) object->type);
                    return 2 + pdfelib_aux_pushvalue(L, object);
                }
            }
        }
    }
    return 0;
}

/*tex

    An indexed table with all entries in an array can be fetched with::

    \starttyping
    t = arraytotable(arrayobject)
    \stoptyping

    An hashed table with all entries in an dictionary can be fetched with::

    \starttyping
    t = dictionarytotable(arrayobject)
    \stoptyping

*/

static void pdfelib_totable(lua_State *L, ppobj *object, int flat)
{
    int n = pdfelib_aux_pushvalue(L, object);
    if (flat && n < 2) {
        return;
    } else {
        /* [value] [extra] [more] */
        lua_createtable(L, n + 1, 0);
        if (n == 1) {
            /* value { nil, nil } */
            lua_insert(L, -2);
            /* { nil, nil } value */
            lua_rawseti(L, -2, 2);
            /* { nil , value } */
        } else if (n == 2) {
            /* value extra { nil, nil, nil } */
            lua_insert(L, -3);
            /* { nil, nil, nil } value extra */
            lua_rawseti(L, -3, 3);
            /* { nil, nil, extra } value */
            lua_rawseti(L, -2, 2);
            /* { nil, value, extra } */
        } else if (n == 3) {
            /* value extra more { nil, nil, nil, nil } */
            lua_insert(L, -4);
            /* { nil, nil, nil, nil, nil } value extra more */
            lua_rawseti(L, -4, 4);
            /* { nil, nil, nil, more } value extra */
            lua_rawseti(L, -3, 3);
            /* { nil, nil, extra, more } value */
            lua_rawseti(L, -2, 2);
            /* { nil, value, extra, more } */
        }
        lua_pushinteger(L, (lua_Integer) object->type);
        /* { nil, [value], [extra], [more] } type */
        lua_rawseti(L, -2, 1);
        /* { type, [value], [extra], [more] } */
    }
}

static int pdfelib_arraytotable(lua_State *L)
{
    pdfe_array *a = pdfelib_aux_check_isarray(L, 1);
    if (a) {
        int flat = lua_isboolean(L, 2);
        int j = 0;
        lua_createtable(L, (int) a->array->size, 0);
        /* table */
        for (unsigned int i = 0; i < a->array->size; i++) {
            ppobj *object = pparray_at(a->array,i);
            if (object) {
                pdfelib_totable(L, object,flat);
                /* table { type, [value], [extra], [more] } */
                lua_rawseti(L, -2, ++j);
                /* table[i] = { type, [value], [extra], [more] } */
            }
        }
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_dictionarytotable(lua_State *L)
{
    pdfe_dictionary *d = pdfelib_aux_check_isdictionary(L, 1);
    if (d) {
        int flat = lua_isboolean(L, 2);
        lua_createtable(L, 0, (int) d->dictionary->size);
        /* table */
        for (unsigned int i = 0; i < d->dictionary->size; i++) {
            ppobj *object = ppdict_at(d->dictionary, i);
            if (object) {
                ppname *key = ppname_decoded(ppdict_key(d->dictionary, i));
                lua_pushlstring(L, ppname_data(key), ppname_size(key));
                /* table key */
                pdfelib_totable(L, object, flat);
                /* table key { type, [value], [extra], [more] } */
                lua_rawset(L, -3);
                /* table[key] = { type, [value], [extra] } */
            }
        }
        return 1;
    } else {
        return 0;
    }
}

/*tex

    All pages are collected with:

    \starttyping
    { { dict, size, objnum }, ... } = pagestotable(document)
    \stoptyping

*/

static int pdfelib_pagestotable(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        ppdoc *d = p->document;
        int i = 1;
        int j = 0;
        lua_createtable(L, (int) ppdoc_page_count(d), 0);
        /* pages[1..n] */
        for (ppref *r = ppdoc_first_page(d); r; r = ppdoc_next_page(d), ++i) {
            lua_createtable(L, 3, 0);
            if (ppref_obj(r)) {
                pdfelib_aux_pushdictionary(L, ppref_obj(r)->dict);
                /* table dictionary n */
                lua_rawseti(L, -3, 2);
                /* table dictionary */
                lua_rawseti(L, -2, 1);
                /* table */
                lua_pushinteger(L, r->number);
                /* table reference */
                lua_rawseti(L, -2, 3);
                /* table */
                lua_rawseti(L, -2, ++j);
                /* pages[i] = { dictionary, size, objnum } */
            }
        }
        return 1;
    } else {
        return 0;
    }
}

/*tex

    Streams can be fetched on one go:

    \starttyping
    string, n = readwholestream(streamobject,decode)
    \stoptyping

*/

static int pdfelib_stream_readwhole(lua_State *L)
{
    pdfe_stream *s = pdfelib_aux_check_isstream(L, 1);
    if (s) {
        uint8_t *b = NULL;
        int decode = 0;
        size_t n = 0;
        if (s->open > 0) {
            ppstream_done(s->stream);
            s->open = 0;
            s->decode = 0;
        }
        if (lua_gettop(L) > 1 && lua_isboolean(L, 2)) {
            decode = lua_toboolean(L, 2);
        }
        b = ppstream_all(s->stream, &n, decode);
        lua_pushlstring(L, (const char *) b, n);
        lua_pushinteger(L, (lua_Integer) n);
        ppstream_done(s->stream);
        return 2;
    } else {
        return 0;
    }
}

/*tex

    Alternatively streams can be fetched stepwise:

    \starttyping
    okay = openstream(streamobject,[decode])
    string, n = readfromstream(streamobject)
    closestream(streamobject)
    \stoptyping

*/

static int pdfelib_stream_open(lua_State *L)
{
    pdfe_stream *s = pdfelib_aux_check_isstream(L, 1);
    if (s) {
        if (s->open == 0) {
            if (lua_gettop(L) > 1) {
                s->decode = lua_isboolean(L, 2);
            }
            s->open = 1;
        }
        lua_pushboolean(L,1);
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_stream_close(lua_State *L)
{
    pdfe_stream *s = pdfelib_aux_check_isstream(L, 1);
    if (s && s->open > 0) {
        ppstream_done(s->stream);
        s->open = 0;
        s->decode = 0;
    }
    return 0;
}

static int pdfelib_stream_read(lua_State *L)
{
    pdfe_stream *s = pdfelib_aux_check_isstream(L, 1);
    if (s) {
        size_t n = 0;
        uint8_t *d = NULL;
        if (s->open == 1) {
            d = ppstream_first(s->stream, &n, s->decode);
            s->open = 2;
        } else if (s->open == 2) {
            d = ppstream_next(s->stream, &n);
        } else {
            return 0;
        }
        lua_pushlstring(L, (const char *) d, n);
        lua_pushinteger(L, (lua_Integer) n);
        return 2;
    } else {
        return 0;
    }
}

/*tex

    There are two methods for opening a document: files and strings.

    \starttyping
    documentobject = open(filename)
    documentobject = new(string,length)
    \stoptyping

    Closing happens with:

    \starttyping
    close(documentobject)
    \stoptyping

    When the \type {new} function gets a peudo filename as third argument, no user data will be
    created but the stream is accessible as image.

*/

/*
static int pdfelib_test(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    ppdoc *d = ppdoc_load(filename);
    if (d) {
        lua_pushboolean(L,1);
        ppdoc_free(d);
    } else {
        lua_pushboolean(L,0);
    }
    return 1;
}
*/

static void aux_pdfelib_open(lua_State *L, FILE *f)
{
    pdfe_document *p = (pdfe_document *) lua_newuserdatauv(L, sizeof(pdfe_document), 0);
    ppdoc *d = ppdoc_filehandle(f, 1);
 // luaL_getmetatable(L, PDFE_METATABLE_INSTANCE);
    lua_get_metatablelua(pdfe_instance);
    lua_setmetatable(L, -2);
    p->document = d;
    p->open = 1;
    p->isfile = 1;
    p->memstream = NULL;
}

static int pdfelib_open(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    FILE *f = aux_utf8_fopen(filename, "rb");
    if (f) {
        aux_pdfelib_open(L, f);
        return 1;
    } else {
        tex_formatted_warning("pdfe lib", "no valid pdf file '%s'", filename);
        return 0;
    }
}

static int pdfelib_openfile(lua_State *L)
{
    luaL_Stream *fs = ((luaL_Stream *) luaL_checkudata(L, 1, LUA_FILEHANDLE));
    FILE *f = (fs->closef) ? fs->f : NULL;
    if (f) {
        aux_pdfelib_open(L, f);
        /*tex We trick \LUA\ in believing the file is closed. */
        fs->closef = NULL;
        return 1;
    } else {
        tex_formatted_warning("pdfe lib", "no valid file handle");
        return 0;
    }
}

static int pdfelib_new(lua_State *L)
{
    size_t streamsize = 0;
    const char *docstream = NULL;
    switch (lua_type(L, 1)) {
        case LUA_TSTRING:
            docstream = lua_tolstring(L, 1, &streamsize);
            if (! docstream) {
                tex_normal_warning("pdfe lib", "invalid string");
                return 0;
            } else {
                break;
            }
        case LUA_TLIGHTUSERDATA:
            /*tex
                The stream comes as a sequence of bytes. This could happen from a library (we used
                this for swiglib gm output tests).
            */
            docstream = (const char *) lua_touserdata(L, 1);
            if (! docstream) {
                tex_normal_warning("pdfe lib", "invalid lightuserdata");
                return 0;
            } else {
                break;
            }
        default:
            tex_normal_warning("pdfe lib", "string or lightuserdata expected");
            return 0;
    }
    streamsize = luaL_optinteger(L, 2, streamsize);
    if (streamsize > 0) {
        char *memstream = lmt_generic_malloc((unsigned) (streamsize + 1)); /* we have no hook into pdfe free */
        if (memstream) {
            ppdoc *d = NULL;
            memcpy(memstream, docstream, (streamsize + 1));
            memstream[streamsize] = '\0';
            d = ppdoc_mem(memstream, streamsize);
            if (d) {
                pdfe_document *p = (pdfe_document *) lua_newuserdatauv(L, sizeof(pdfe_document), 0);
             // luaL_getmetatable(L, PDFE_METATABLE_INSTANCE);
                lua_get_metatablelua(pdfe_instance);
                lua_setmetatable(L, -2);
                p->document = d;
                p->open = 1;
                p->isfile = 0;
                p->memstream = memstream;
                return 1;
            } else {
                tex_normal_warning("pdfe lib", "unable to handle stream");
            }
        } else {
            tex_normal_warning("pdfe lib", "not enough memory for new stream");
        }
    } else {
        tex_normal_warning("pdfe lib", "stream with size > 0 expected");
    }
    return 0;
}

/*

    There is no garbage collection needed as the library itself manages the objects. Normally
    objects don't take much space. Streams use buffers so (I assume) that they are not
    persistent. The only collector is in the parent object (the document).

*/

static int pdfelib_document_free(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p && p->open) {
        if (p->document) {
            ppdoc_free(p->document);
            p->document = NULL;
        }
        if (p->memstream) {
         /* pplib does this: xfree(p->memstream); */
            p->memstream = NULL;
        }
        p->open = 0;
    }
    return 0;
}

static int pdfelib_close(lua_State *L)
{
    return pdfelib_document_free(L);
}

/*tex

    A document is can be uncrypted with:

    \starttyping
    status = unencrypt(documentobject,user,owner)
    \stoptyping

    Instead of a password \type {nil} can be passed, so there are three possible useful combinations.

*/

static int pdfelib_unencrypt(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        size_t u = 0;
        size_t o = 0;
        const char* user = NULL;
        const char* owner = NULL;
        int top = lua_gettop(L);
        if (top > 1) {
            if (lua_type(L,2) == LUA_TSTRING) {
                user = lua_tolstring(L, 2, &u);
            } else {
                /*tex we're not too picky but normally it will be nil or false */
            }
            if (top > 2) {
                if (lua_type(L,3) == LUA_TSTRING) {
                    owner = lua_tolstring(L, 3, &o);
                } else {
                    /*tex we're not too picky but normally it will be nil or false */
                }
            }
            lua_pushinteger(L, (lua_Integer) ppdoc_crypt_pass(p->document, user, u, owner, o));
            return 1;
        }
    }
    lua_pushinteger(L, (lua_Integer) PPCRYPT_FAIL);
    return 1;
}

/*tex

    There are a couple of ways to get information about the document:

    \starttyping
    n             = getsize       (documentobject)
    major, minor  = getversion    (documentobject)
    status        = getstatus     (documentobject)
    n             = getnofobjects (documentobject)
    n             = getnofpages   (documentobject)
    bytes, waste  = getmemoryusage(documentobject)
    \stoptyping

*/

static int pdfelib_getsize(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        lua_pushinteger(L, (lua_Integer) ppdoc_file_size(p->document));
        return 1;
    } else {
        return 0;
    }
}


static int pdfelib_getversion(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        int minor;
        int major = ppdoc_version_number(p->document, &minor);
        lua_pushinteger(L, (lua_Integer) major);
        lua_pushinteger(L, (lua_Integer) minor);
        return 2;
    } else {
        return 0;
    }
}

static int pdfelib_getstatus(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        lua_pushinteger(L, (lua_Integer) ppdoc_crypt_status(p->document));
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_getnofobjects(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        lua_pushinteger(L, (lua_Integer) ppdoc_objects(p->document));
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_getnofpages(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        lua_pushinteger(L, (lua_Integer) ppdoc_page_count(p->document));
        return 1;
    } else {
        return 0;
    }
}

static int pdfelib_getmemoryusage(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        size_t w = 0;
        size_t m = ppdoc_memory(p->document, &w);
        lua_pushinteger(L, (lua_Integer) m);
        lua_pushinteger(L, (lua_Integer) w);
        return 2;
    } else {
        return 0;
    }
}

/*
    A specific page dictionary can be filtered with the next command. So, there is no need to parse
    the document page tree (with these \type {kids} arrays).

    \starttyping
    dictionaryobject = getpage(documentobject,pagenumber)
    \stoptyping

*/

static int pdfelib_aux_pushpage(lua_State *L, ppdoc *d, int page)
{
    if ((page <= 0) || (page > ((int) ppdoc_page_count(d)))) {
        return 0;
    } else {
        ppref *pp = ppdoc_page(d, page);
        return pdfelib_aux_pushdictionaryonly(L, ppref_obj(pp)->dict);
    }
}

static int pdfelib_getpage(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        return pdfelib_aux_pushpage(L, p->document, lmt_checkinteger(L, 2));
    } else {
        return 0;
    }
}

static int pdfelib_aux_pushpages(lua_State *L, ppdoc *d)
{
    int i = 1;
    lua_createtable(L, (int) ppdoc_page_count(d), 0);
    /* pages[1..n] */
    for (ppref *r = ppdoc_first_page(d); r; r = ppdoc_next_page(d), ++i) {
        pdfelib_aux_pushdictionaryonly(L,ppref_obj(r)->dict);
        lua_rawseti(L, -2, i);
    }
    return 1 ;
}

static int pdfelib_getpages(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        return pdfelib_aux_pushpages(L, p->document);
    } else {
        return 0;
    }
}

/*tex

    The boundingbox (\type {MediaBox) and similar boxes can be available in a (page) doctionary but
    also in a parent object. Therefore a helper is available that does the (backtracked) lookup.

    \starttyping
    { lx, ly, rx, ry } = getbox(dictionaryobject)
    \stoptyping

*/

static int pdfelib_getbox(lua_State *L)
{
    if (lua_gettop(L) > 1 && lua_type(L,2) == LUA_TSTRING) {
        pdfe_dictionary *p = pdfelib_aux_check_isdictionary(L, 1);
        if (p) {
            const char *key = lua_tostring(L, 2);
            pprect box = { 0, 0, 0, 0 };
            pprect *r = ppdict_get_box(p->dictionary, key, &box);
            if (r) {
                lua_createtable(L, 4, 0);
                lua_pushnumber(L, r->lx);
                lua_rawseti(L, -2, 1);
                lua_pushnumber(L, r->ly);
                lua_rawseti(L, -2, 2);
                lua_pushnumber(L, r->rx);
                lua_rawseti(L, -2, 3);
                lua_pushnumber(L, r->ry);
                lua_rawseti(L, -2, 4);
                return 1;
            }
        }
    }
    return 0;
}

/*tex

    This one is needed when you use the detailed getters and run into an object reference. The
    regular getters resolve this automatically.

    \starttyping
    [dictionary|array|stream]object = getfromreference(referenceobject)
    \stoptyping

*/

static int pdfelib_getfromreference(lua_State *L)
{
    pdfe_reference *r = pdfelib_aux_check_isreference(L, 1);
    if (r && r->xref) {
        ppref *rr = ppxref_find(r->xref, (ppuint) r->onum);
        if (rr) {
            ppobj *o = ppref_obj(rr);
            if (o) {
                lua_pushinteger(L, (lua_Integer) o->type);
                return 1 + pdfelib_aux_pushvalue(L, o);
            }
        }
    }
    return 0;
}

static int pdfelib_getfromobject(lua_State *L)
{
    pdfe_document *p = pdfelib_aux_check_isdocument(L, 1);
    if (p) {
        ppref *rr = ppxref_find(p->document->xref, lua_tointeger(L, 2));
        if (rr) {
             ppobj *o = ppref_obj(rr);
             if (o) {
                 lua_pushinteger(L, (lua_Integer) o->type);
                 return 1 + pdfelib_aux_pushvalue(L, o);
             }
        }
    }
    return 0;
}

/*tex

    Here are some convenient getters:

    \starttyping
    <string>         = getstring    (array|dict|ref,index|key)
    <integer>        = getinteger   (array|dict|ref,index|key)
    <number>         = getnumber    (array|dict|ref,index|key)
    <boolan>         = getboolean   (array|dict|ref,index|key)
    <string>         = getname      (array|dict|ref,index|key)
    <dictionary>     = getdictionary(array|dict|ref,index|key)
    <array>          = getarray     (array|dict|ref,index|key)
    <stream>, <dict> = getstream    (array|dict|ref,index|key)
    \stoptyping

    We report issues when reasonable but are silent when it makes sense. We don't error on this
    because we expect the user code to act reasonable on a return value.

*/

static int pdfelib_valid_index(lua_State *L, void **p, int *t)
{
    *t = lua_type(L, 2);
    *p = lua_touserdata(L, 1);
    lua_settop(L, 2);
    if (! *p) {
        switch (*t) {
            case LUA_TSTRING:
                tex_normal_warning("pdfe lib", "lua <pdfe dictionary> expected");
                break;
            case LUA_TNUMBER:
                tex_normal_warning("pdfe lib", "lua <pdfe array> expected");
                break;
            default:
                tex_normal_warning("pdfe lib", "invalid arguments");
                break;
        }
        return 0;
    } else if (! lua_getmetatable(L, 1)) {
        tex_normal_warning("pdfe lib", "first argument should be a <pde array> or <pde dictionary>");
        return 0;
    } else {
        return 1;
    }
}

static void pdfelib_invalid_index_warning(void)
{
    tex_normal_warning("pdfe lib", "second argument should be integer or string");
}

/*tex

    The direct fetcher returns the result or |NULL| when there is nothing found. The indirect
    fetcher passes a pointer to the target variable and returns success state.

    The next two functions used to be macros but as we try to avoid large ones with much code, they
    are now functions.

*/

typedef void * (*pp_a_direct)   (void *a, size_t      index);
typedef void * (*pp_d_direct)   (void *d, const char *key);
typedef int    (*pp_a_indirect) (void *a, size_t      index, void **value);
typedef int    (*pp_d_indirect) (void *d, const char *key,   void **value);

static int pdfelib_get_value_direct(lua_State *L, void **value, pp_d_direct get_d, pp_a_direct get_a)
{
    int t = 0;
    void *p = NULL;
    if (pdfelib_valid_index(L, &p, &t)) {
        switch (t) {
            case LUA_TSTRING:
                {
                    const char *key = lua_tostring(L, 2);
                    lua_get_metatablelua(pdfe_dictionary_instance);
                    if (lua_rawequal(L, -1, -2)) {
                        *value = get_d(((pdfe_dictionary *) p)->dictionary, key);
                        return 1;
                    } else {
                        lua_get_metatablelua(pdfe_reference_instance);
                        if (lua_rawequal(L, -1, -3)) {
                            ppref *r = (((pdfe_reference *) p)->xref) ? ppxref_find(((pdfe_reference *) p)->xref, (ppuint) (((pdfe_reference *) p)->onum)) : NULL; \
                            ppobj *o = (r) ? ppref_obj(r) : NULL;
                            if (o && o->type == PPDICT) {
                                *value = get_d((ppdict *) o->dict, key);
                                return 1;
                            }
                        }
                    }
                }
                break;
            case LUA_TNUMBER:
                {
                    size_t index = lua_tointeger(L, 2);
                    lua_get_metatablelua(pdfe_array_instance);
                    if (lua_rawequal(L, -1, -2)) {
                        *value = get_a(((pdfe_array *) p)->array, index);
                        return 2;
                    } else {
                        lua_get_metatablelua(pdfe_reference_instance);
                        if (lua_rawequal(L, -1, -3)) {
                            ppref *r = (((pdfe_reference *) p)->xref) ? ppxref_find(((pdfe_reference *) p)->xref, (ppuint) (((pdfe_reference *) p)->onum)) : NULL; \
                            ppobj *o = (r) ? ppref_obj(r) : NULL;
                            if (o && o->type == PPARRAY) {
                                *value = get_a((pparray *) o->array, index);
                                return 2;
                            }
                        }
                    }
                }
                break;
            default:
                pdfelib_invalid_index_warning();
                break;
        }
    }
    return 0;
}

static int pdfelib_get_value_indirect(lua_State *L, void **value, pp_d_indirect get_d, pp_a_indirect get_a)
{
    int t = 0;
    void *p = NULL;
    if (pdfelib_valid_index(L, &p, &t)) {
        switch (t) {
            case LUA_TSTRING:
                {
                    const char *key = lua_tostring(L, 2);
                    lua_get_metatablelua(pdfe_dictionary_instance);
                    if (lua_rawequal(L, -1, -2)) {
                        return get_d(((pdfe_dictionary *) p)->dictionary, key, value);
                    } else {
                        lua_get_metatablelua(pdfe_reference_instance);
                        if (lua_rawequal(L, -1, -3)) {
                            ppref *r = (((pdfe_reference *) p)->xref) ? ppxref_find(((pdfe_reference *) p)->xref, (ppuint) (((pdfe_reference *) p)->onum)) : NULL;
                            ppobj *o = (r) ? ppref_obj(r) : NULL;
                            if (o && o->type == PPDICT)
                                return get_d(o->dict, key, value);
                        }
                    }
                }
                break;
            case LUA_TNUMBER:
                {
                    size_t index = lua_tointeger(L, 2);
                    lua_get_metatablelua(pdfe_array_instance);
                    if (lua_rawequal(L, -1, -2)) {
                        return get_a(((pdfe_array *) p)->array, index, value);
                    } else {
                        lua_get_metatablelua(pdfe_reference_instance);
                        if (lua_rawequal(L, -1, -3)) {
                            ppref *r = (((pdfe_reference *) p)->xref) ? ppxref_find(((pdfe_reference *) p)->xref, (ppuint) (((pdfe_reference *) p)->onum)) : NULL;
                            ppobj *o = (r) ? ppref_obj(r) : NULL;
                            if (o && o->type == PPARRAY)
                                return get_a(o->array, index, value);
                        }
                    }
                }
                break;
            default:
                pdfelib_invalid_index_warning();
                break;
        }
    }
    return 0;
}

static int pdfelib_getstring(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        ppstring *value = NULL;
        int okay = 0;
        int how = 0;
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            if (lua_toboolean(L, 3)) {
                how = 1;
            } else {
                how = 2;
            }
        }
        okay = pdfelib_get_value_direct(L, (void *) &value, (void *) &ppdict_rget_string, (void *) &pparray_rget_string);
        if (okay && value) {
            if (how == 1) {
                value = ppstring_decoded(value);
            }
            /*tex This used to return one value but we made it \LUATEX\ compatible. */
            lua_pushlstring(L, ppstring_data(value), ppstring_size(value));
            if (how == 2) {
                lua_pushboolean(L, ppstring_hex(value));
                return 2;
            } else {
                return 1;
            }
        }
    }
    return 0;
}

static int pdfelib_getinteger(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        ppint value = 0;
        if (pdfelib_get_value_indirect(L, (void *) &value, (void *) &ppdict_rget_int, (void *) &pparray_rget_int)) {
            lua_pushinteger(L, (lua_Integer) value);
            return 1;
        }
    }
    return 0;
}

static int pdfelib_getnumber(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        ppnum value = 0;
        if (pdfelib_get_value_indirect(L, (void *) &value, (void *) &ppdict_rget_num, (void *) &pparray_rget_num)) {
            lua_pushnumber(L, value);
            return 1;
        }
    }
    return 0;
}

static int pdfelib_getboolean(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        int value = 0;
        if (pdfelib_get_value_indirect(L, (void *) &value, (void *) &ppdict_rget_bool, (void *) &pparray_rget_bool)) {
            lua_pushboolean(L, value);
            return 1;
        }
    }
    return 0;
}

static int pdfelib_getname(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        ppname *value = NULL;
        pdfelib_get_value_direct(L, (void *) &value, (void *) &ppdict_rget_name, (void *) &pparray_rget_name);
        if (value) {
            value = ppname_decoded(value) ;
            lua_pushlstring(L, ppname_data(value), ppname_size(value));
            return 1;
        }
    }
    return 0;
}

static int pdfelib_getdictionary(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        ppdict *value = NULL;
        pdfelib_get_value_direct(L, (void *) &value, (void *) &ppdict_rget_dict, (void *) &pparray_rget_dict);
        if (value) {
            return pdfelib_aux_pushdictionaryonly(L, value);
        }
    }
    return 0;
}

static int pdfelib_getarray(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        pparray *value = NULL;
        pdfelib_get_value_direct(L, (void *) &value, (void *) &ppdict_rget_array, (void *) &pparray_rget_array);
        if (value) {
            return pdfelib_aux_pusharrayonly(L, value);
        }
    }
    return 0;
}

static int pdfelib_getstream(lua_State *L)
{
    if (lua_gettop(L) > 1) {
        ppobj *value = NULL;
        pdfelib_get_value_direct(L, (void *) &value, (void *) &ppdict_rget_obj, (void *) &pparray_rget_obj);
        if (value && value->type == PPSTREAM) {
            return pdfelib_aux_pushstreamonly(L, (ppstream *) value->stream);
        }
    }
    return 0;
}

/*tex

    The generic pushed that does a similar job as the previous getters acts upon
    the type.

*/

static int pdfelib_pushvalue(lua_State *L, ppobj *object)
{
    switch (object->type) {
        case PPNONE:
        case PPNULL:
            lua_pushnil(L);
            break;
        case PPBOOL:
            lua_pushboolean(L, (int) object->integer);
            break;
        case PPINT:
            lua_pushinteger(L, (lua_Integer) object->integer);
            break;
        case PPNUM:
            lua_pushnumber(L, (double) object->number);
            break;
        case PPNAME:
            {
                ppname *n = ppname_decoded(object->name) ;
                lua_pushlstring(L, ppname_data(n), ppname_size(n));
            }
            break;
        case PPSTRING:
            lua_pushlstring(L, ppstring_data(object->string), ppstring_size(object->string));
            break;
        case PPARRAY:
            return pdfelib_aux_pusharrayonly(L, object->array);
        case PPDICT:
            return pdfelib_aux_pushdictionary(L, object->dict);
        case PPSTREAM:
            return pdfelib_aux_pushstream(L, object->stream);
        case PPREF:
            pdfelib_aux_pushreference(L, object->ref);
            break;
        /*tex We get a funny message in clang about covering all cases. */
        /*
        default:
            lua_pushnil(L);
            break;
        */
    }
    return 1;
}

/*tex

    Finally we arrived at the acessors for the userdata objects. The use previously defined helpers.

*/

static int pdfelib_document_access(lua_State *L)
{
    if (lua_type(L, 2) == LUA_TSTRING) {
        pdfe_document *p = (pdfe_document *) lua_touserdata(L, 1);
        const char *s = lua_tostring(L, 2);
        if (lua_key_eq(s, catalog) || lua_key_eq(s, Catalog)) {
            return pdfelib_aux_pushdictionaryonly(L, ppdoc_catalog(p->document));
        } else if (lua_key_eq(s, info) || lua_key_eq(s, Info)) {
            return pdfelib_aux_pushdictionaryonly(L, ppdoc_info(p->document));
        } else if (lua_key_eq(s, trailer) || lua_key_eq(s, Trailer)) {
            return pdfelib_aux_pushdictionaryonly(L, ppdoc_trailer(p->document));
        } else if (lua_key_eq(s, pages) || lua_key_eq(s, Pages)) {
            return pdfelib_aux_pushpages(L, p->document);
        }
    }
    return 0;
}

static int pdfelib_array_access(lua_State *L)
{
    if (lua_type(L, 2) == LUA_TNUMBER) {
        pdfe_array *p = (pdfe_array *) lua_touserdata(L, 1);
        ppint index = lua_tointeger(L, 2) - 1;
        ppobj *o = pparray_rget_obj(p->array, index);
        if (o) {
            return pdfelib_pushvalue(L, o);
        }
    }
    return 0;
}

static int pdfelib_dictionary_access(lua_State *L)
{
    pdfe_dictionary *p = (pdfe_dictionary *) lua_touserdata(L, 1);
    switch (lua_type(L, 2)) {
        case LUA_TSTRING:
            {
                const char *key = lua_tostring(L, 2);
                ppobj *o = ppdict_rget_obj(p->dictionary, key);
                if (o) {
                    return pdfelib_pushvalue(L, o);
                }
            }
            break;
        case LUA_TNUMBER:
            {
                ppint index = lua_tointeger(L, 2) - 1;
                ppobj *o = ppdict_at(p->dictionary, index);
                if (o) {
                    return pdfelib_pushvalue(L, o);
                }
            }
            break;
    }
    return 0;
}

static int pdfelib_stream_access(lua_State *L)
{
    pdfe_stream *p = (pdfe_stream *) lua_touserdata(L, 1);
    switch (lua_type(L, 2)) {
        case LUA_TSTRING:
            {
                const char *key = lua_tostring(L, 2);
                ppobj *o = ppdict_rget_obj(p->stream->dict, key);
                if (o) {
                    return pdfelib_pushvalue(L, o);
                }
            }
            break;
        case LUA_TNUMBER:
            {
                ppint index = lua_tointeger(L, 2) - 1;
                ppobj *o = ppdict_at(p->stream->dict, index);
                if (o) {
                    return pdfelib_pushvalue(L, o);
                }
            }
            break;
    }
    return 0;
}

/*tex

    The length metamethods are defined last.

*/

static int pdfelib_array_size(lua_State *L)
{
    pdfe_array *p = (pdfe_array *) lua_touserdata(L, 1);
    lua_pushinteger(L, (lua_Integer) p->array->size);
    return 1;
}

static int pdfelib_dictionary_size(lua_State *L)
{
    pdfe_dictionary *p = (pdfe_dictionary *) lua_touserdata(L, 1);
    lua_pushinteger(L, (lua_Integer) p->dictionary->size);
    return 1;
}

static int pdfelib_stream_size(lua_State *L)
{
    pdfe_stream *p = (pdfe_stream *) lua_touserdata(L, 1);
    lua_pushinteger(L, (lua_Integer) p->stream->dict->size);
    return 1;
}

/*tex

    We now initialize the main interface. We might add few more informational helpers but this is
    it.

*/

static const struct luaL_Reg pdfelib_function_list[] = {
    /* management */
    { "type",               pdfelib_type              },
    { "open",               pdfelib_open              },
    { "openfile",           pdfelib_openfile          },
    { "new",                pdfelib_new               },
    { "close",              pdfelib_close             },
    { "unencrypt",          pdfelib_unencrypt         },
    /* statistics */
    { "getversion",         pdfelib_getversion        },
    { "getstatus",          pdfelib_getstatus         },
    { "getsize",            pdfelib_getsize           },
    { "getnofobjects",      pdfelib_getnofobjects     },
    { "getnofpages",        pdfelib_getnofpages       },
    { "getmemoryusage",     pdfelib_getmemoryusage    },
    /* getters */
    { "getcatalog",         pdfelib_getcatalog        },
    { "gettrailer",         pdfelib_gettrailer        },
    { "getinfo",            pdfelib_getinfo           },
    { "getpage",            pdfelib_getpage           },
    { "getpages",           pdfelib_getpages          },
    { "getbox",             pdfelib_getbox            },
    { "getfromreference",   pdfelib_getfromreference  },
    { "getfromdictionary",  pdfelib_getfromdictionary },
    { "getfromarray",       pdfelib_getfromarray      },
    { "getfromstream",      pdfelib_getfromstream     },
    /* handy too */
    { "getfromobject",      pdfelib_getfromobject     },
    /* collectors */
    { "dictionarytotable",  pdfelib_dictionarytotable },
    { "arraytotable",       pdfelib_arraytotable      },
    { "pagestotable",       pdfelib_pagestotable      },
    /* more getters */
    { "getstring",          pdfelib_getstring         },
    { "getinteger",         pdfelib_getinteger        },
    { "getnumber",          pdfelib_getnumber         },
    { "getboolean",         pdfelib_getboolean        },
    { "getname",            pdfelib_getname           },
    { "getdictionary",      pdfelib_getdictionary     },
    { "getarray",           pdfelib_getarray          },
    { "getstream",          pdfelib_getstream         },
    /* streams */
    { "readwholestream",    pdfelib_stream_readwhole  },
    /* not really needed */
    { "openstream",         pdfelib_stream_open       },
    { "readfromstream",     pdfelib_stream_read       },
    { "closestream",        pdfelib_stream_close      },
    /* only for me, a test hook */
 /* { "test",               pdfelib_test              }, */
    /* done */
    { NULL,                 NULL                      }
};

/*tex

    The user data metatables are defined as follows. Watch how only the document needs a garbage
    collector.

*/

static const struct luaL_Reg pdfelib_instance_metatable[] = {
    { "__tostring", pdfelib_document_tostring },
    { "__gc",       pdfelib_document_free     },
    { "__index",    pdfelib_document_access   },
    { NULL,         NULL                      },
};

static const struct luaL_Reg pdfelib_dictionary_metatable[] = {
    { "__tostring", pdfelib_dictionary_tostring },
    { "__index",    pdfelib_dictionary_access   },
    { "__len",      pdfelib_dictionary_size     },
    { NULL,         NULL                        },
};

static const struct luaL_Reg pdfelib_array_metatable[] = {
    { "__tostring", pdfelib_array_tostring },
    { "__index",    pdfelib_array_access   },
    { "__len",      pdfelib_array_size     },
    { NULL,         NULL                   },
};

static const struct luaL_Reg pdfelib_stream_metatable[] = {
    { "__tostring", pdfelib_stream_tostring  },
    { "__index",    pdfelib_stream_access    },
    { "__len",      pdfelib_stream_size      },
    { "__call",     pdfelib_stream_readwhole },
    { NULL,         NULL                     },
};

static const struct luaL_Reg pdfelib_reference_metatable[] = {
    { "__tostring", pdfelib_reference_tostring },
    { NULL,         NULL                       },
};

/*tex

    Finally we have arrived at the main initialiser that will be called as part of \LUATEX's
    initializer.

*/

/*tex

    Here we hook in the error handler.

*/

static void pdfelib_message(const char *message, void *alien)
{
    (void) (alien);
    tex_normal_warning("pdfe", message);
}

int luaopen_pdfe(lua_State *L)
{
    /*tex First the four userdata object get their metatables defined. */

    luaL_newmetatable(L, PDFE_METATABLE_DICTIONARY);
    luaL_setfuncs(L, pdfelib_dictionary_metatable, 0);

    luaL_newmetatable(L, PDFE_METATABLE_ARRAY);
    luaL_setfuncs(L, pdfelib_array_metatable, 0);

    luaL_newmetatable(L, PDFE_METATABLE_STREAM);
    luaL_setfuncs(L, pdfelib_stream_metatable, 0);

    luaL_newmetatable(L, PDFE_METATABLE_REFERENCE);
    luaL_setfuncs(L, pdfelib_reference_metatable, 0);

    /*tex Then comes the main (document) metatable: */

    luaL_newmetatable(L, PDFE_METATABLE_INSTANCE);
    luaL_setfuncs(L, pdfelib_instance_metatable, 0);

    /*tex Last the library opens up itself to the world. */

    lua_newtable(L);
    luaL_setfuncs(L, pdfelib_function_list, 0);

    pplog_callback(pdfelib_message, stderr);

    return 1;
}
