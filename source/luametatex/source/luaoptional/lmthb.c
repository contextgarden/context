/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    This is using similar c-lua-interfacing code as that Kai Eigner wrote for ffi. I cleaned it up
    a bit but the principles remain because that way we are downward compatible. Don't expect
    miracles here. We use function pointers as we delay binding to the module. We use the system
    library as it comes, because after all, that is what is expected: shaping conform what the
    system offers.

    This interface is only for testing. We load the font in \LUA\ anyway, so we don't need to
    collect information here. The code runs on top of the \CONTEXT\ font plugin interface that
    itself was written for testing purposes. When we wanted to test uniscribe the hb command
    line program could be used for that, but more direct support was also added. The tests that
    were done at that time (irr it was when xetex switched to hb and folks used that as reference)
    ended up in articles. Later we used this mechanism to check how Idris advanced Arabic font
    behaves in different shapers (context, uniscribe, hb, ...) as we try to follow uniscribe when
    possible and this gave the glue to that. It showed interesting differences and overlap in
    interpretation (and made us wonder when bugs - in whatever program or standard - get turned
    into features, but that's another  matter, and we can always adapt and provide variants and
    overloads if needed).

    The following code is not dependent on h files so we don't need to install a whole bunch of
    dependencies. Also, because we delay loading, there is no default overhead in startup. The
    loading of the library happens (as usual) at the \LUA\ end, but in order for it to work okay
    the initializer needs to be called, so that the functions get resolved. So, it works a bit
    like the ffi interface: delayed loading, but (maybe) with a bit less overhead. I should
    probably look at the latest api to see if things can be done with less code but on the other
    hand there is no real reason to change something that already worked okay some years ago.

    I guess that the script enumeration is no longer right but it probably doesn't matter as
    numbers are passed anyway. We can probably make that into an integer (I need to test that
    some day) as these enumerations are just that: integers, and the less hard-coding we have
    here the better.

    When this module is used (which is triggered via loading an optional module and setting the
    mode in a font definition) other features of the \CONTEXT\ font handler are lost for that
    specific font instance, simply because these mechanism operate independently. But that is
    probably what a user expects anyway: no interference from other code, just the results from
    a library. It makes no sense to complicate the machinery even more. This is comparable with
    basemode and nodemode that are also seperated code paths.

    So, we could probably simplify the following typedefs, but this is what Kai started with so
    I stick to it. From the enumerations only the direction constant is used.

*/

typedef struct hb_blob_t hb_blob_t;

/* typedef int hb_memory_mode_t; */

typedef enum hb_memory_mode_t {
    HB_MEMORY_MODE_DUPLICATE,
    HB_MEMORY_MODE_READONLY,
    HB_MEMORY_MODE_WRITABLE,
    HB_MEMORY_MODE_READONLY_MAY_MAKE_WRITABLE
} hb_memory_mode_t;

typedef void (*hb_destroy_func_t) (
    void *user_data
);

typedef struct       hb_face_t           hb_face_t;
typedef const struct hb_language_impl_t *hb_language_t;
typedef struct       hb_buffer_t         hb_buffer_t;

/* typedef int hb_script_t; */
/* typedef int hb_direction_t; */

/*
    The content of this enum doesn't really matter here because we don't use it. Integers are
    passed around. So, even if the following is not up to date we're okay.
*/

typedef enum hb_script_t {
    HB_SCRIPT_COMMON, HB_SCRIPT_INHERITED, HB_SCRIPT_UNKNOWN,

    HB_SCRIPT_ARABIC, HB_SCRIPT_ARMENIAN, HB_SCRIPT_BENGALI, HB_SCRIPT_CYRILLIC,
    HB_SCRIPT_DEVANAGARI, HB_SCRIPT_GEORGIAN, HB_SCRIPT_GREEK,
    HB_SCRIPT_GUJARATI, HB_SCRIPT_GURMUKHI, HB_SCRIPT_HANGUL, HB_SCRIPT_HAN,
    HB_SCRIPT_HEBREW, HB_SCRIPT_HIRAGANA, HB_SCRIPT_KANNADA, HB_SCRIPT_KATAKANA,
    HB_SCRIPT_LAO, HB_SCRIPT_LATIN, HB_SCRIPT_MALAYALAM, HB_SCRIPT_ORIYA,
    HB_SCRIPT_TAMIL, HB_SCRIPT_TELUGU, HB_SCRIPT_THAI, HB_SCRIPT_TIBETAN,
    HB_SCRIPT_BOPOMOFO, HB_SCRIPT_BRAILLE, HB_SCRIPT_CANADIAN_SYLLABICS,
    HB_SCRIPT_CHEROKEE, HB_SCRIPT_ETHIOPIC, HB_SCRIPT_KHMER, HB_SCRIPT_MONGOLIAN,
    HB_SCRIPT_MYANMAR, HB_SCRIPT_OGHAM, HB_SCRIPT_RUNIC, HB_SCRIPT_SINHALA,
    HB_SCRIPT_SYRIAC, HB_SCRIPT_THAANA, HB_SCRIPT_YI, HB_SCRIPT_DESERET,
    HB_SCRIPT_GOTHIC, HB_SCRIPT_OLD_ITALIC, HB_SCRIPT_BUHID, HB_SCRIPT_HANUNOO,
    HB_SCRIPT_TAGALOG, HB_SCRIPT_TAGBANWA, HB_SCRIPT_CYPRIOT, HB_SCRIPT_LIMBU,
    HB_SCRIPT_LINEAR_B, HB_SCRIPT_OSMANYA, HB_SCRIPT_SHAVIAN, HB_SCRIPT_TAI_LE,
    HB_SCRIPT_UGARITIC, HB_SCRIPT_BUGINESE, HB_SCRIPT_COPTIC,
    HB_SCRIPT_GLAGOLITIC, HB_SCRIPT_KHAROSHTHI, HB_SCRIPT_NEW_TAI_LUE,
    HB_SCRIPT_OLD_PERSIAN, HB_SCRIPT_SYLOTI_NAGRI, HB_SCRIPT_TIFINAGH,
    HB_SCRIPT_BALINESE, HB_SCRIPT_CUNEIFORM, HB_SCRIPT_NKO, HB_SCRIPT_PHAGS_PA,
    HB_SCRIPT_PHOENICIAN, HB_SCRIPT_CARIAN, HB_SCRIPT_CHAM, HB_SCRIPT_KAYAH_LI,
    HB_SCRIPT_LEPCHA, HB_SCRIPT_LYCIAN, HB_SCRIPT_LYDIAN, HB_SCRIPT_OL_CHIKI,
    HB_SCRIPT_REJANG, HB_SCRIPT_SAURASHTRA, HB_SCRIPT_SUNDANESE, HB_SCRIPT_VAI,
    HB_SCRIPT_AVESTAN, HB_SCRIPT_BAMUM, HB_SCRIPT_EGYPTIAN_HIEROGLYPHS,
    HB_SCRIPT_IMPERIAL_ARAMAIC, HB_SCRIPT_INSCRIPTIONAL_PAHLAVI,
    HB_SCRIPT_INSCRIPTIONAL_PARTHIAN, HB_SCRIPT_JAVANESE, HB_SCRIPT_KAITHI,
    HB_SCRIPT_LISU, HB_SCRIPT_MEETEI_MAYEK, HB_SCRIPT_OLD_SOUTH_ARABIAN,
    HB_SCRIPT_OLD_TURKIC, HB_SCRIPT_SAMARITAN, HB_SCRIPT_TAI_THAM,
    HB_SCRIPT_TAI_VIET, HB_SCRIPT_BATAK, HB_SCRIPT_BRAHMI, HB_SCRIPT_MANDAIC,
    HB_SCRIPT_CHAKMA, HB_SCRIPT_MEROITIC_CURSIVE, HB_SCRIPT_MEROITIC_HIEROGLYPHS,
    HB_SCRIPT_MIAO, HB_SCRIPT_SHARADA, HB_SCRIPT_SORA_SOMPENG, HB_SCRIPT_TAKRI,
    HB_SCRIPT_BASSA_VAH, HB_SCRIPT_CAUCASIAN_ALBANIAN, HB_SCRIPT_DUPLOYAN,
    HB_SCRIPT_ELBASAN, HB_SCRIPT_GRANTHA, HB_SCRIPT_KHOJKI, HB_SCRIPT_KHUDAWADI,
    HB_SCRIPT_LINEAR_A, HB_SCRIPT_MAHAJANI, HB_SCRIPT_MANICHAEAN,
    HB_SCRIPT_MENDE_KIKAKUI, HB_SCRIPT_MODI, HB_SCRIPT_MRO, HB_SCRIPT_NABATAEAN,
    HB_SCRIPT_OLD_NORTH_ARABIAN, HB_SCRIPT_OLD_PERMIC, HB_SCRIPT_PAHAWH_HMONG,
    HB_SCRIPT_PALMYRENE, HB_SCRIPT_PAU_CIN_HAU, HB_SCRIPT_PSALTER_PAHLAVI,
    HB_SCRIPT_SIDDHAM, HB_SCRIPT_TIRHUTA, HB_SCRIPT_WARANG_CITI, HB_SCRIPT_AHOM,
    HB_SCRIPT_ANATOLIAN_HIEROGLYPHS, HB_SCRIPT_HATRAN, HB_SCRIPT_MULTANI,
    HB_SCRIPT_OLD_HUNGARIAN, HB_SCRIPT_SIGNWRITING, HB_SCRIPT_ADLAM,
    HB_SCRIPT_BHAIKSUKI, HB_SCRIPT_MARCHEN, HB_SCRIPT_OSAGE, HB_SCRIPT_TANGUT,
    HB_SCRIPT_NEWA, HB_SCRIPT_MASARAM_GONDI, HB_SCRIPT_NUSHU, HB_SCRIPT_SOYOMBO,
    HB_SCRIPT_ZANABAZAR_SQUARE, HB_SCRIPT_DOGRA, HB_SCRIPT_GUNJALA_GONDI,
    HB_SCRIPT_HANIFI_ROHINGYA, HB_SCRIPT_MAKASAR, HB_SCRIPT_MEDEFAIDRIN,
    HB_SCRIPT_OLD_SOGDIAN, HB_SCRIPT_SOGDIAN, HB_SCRIPT_ELYMAIC,
    HB_SCRIPT_NANDINAGARI, HB_SCRIPT_NYIAKENG_PUACHUE_HMONG, HB_SCRIPT_WANCHO,

    HB_SCRIPT_INVALID, _HB_SCRIPT_MAX_VALUE, _HB_SCRIPT_MAX_VALUE_SIGNED,
} hb_script_t;

typedef enum hb_direction_t {
    HB_DIRECTION_INVALID,
    HB_DIRECTION_LTR,
    HB_DIRECTION_RTL,
    HB_DIRECTION_TTB,
    HB_DIRECTION_BTT
} hb_direction_t;

typedef int hb_bool_t;

typedef uint32_t hb_tag_t;

typedef struct hb_feature_t {
    hb_tag_t      tag;
    uint32_t      value;
    unsigned int  start;
    unsigned int  end;
} hb_feature_t;

typedef struct hb_font_t hb_font_t;

typedef uint32_t hb_codepoint_t;
typedef int32_t  hb_position_t;
typedef uint32_t hb_mask_t;

typedef union _hb_var_int_t {
    uint32_t u32;
    int32_t  i32;
    uint16_t u16[2];
    int16_t  i16[2];
    uint8_t  u8[4];
    int8_t   i8[4];
} hb_var_int_t;

typedef struct hb_glyph_info_t {
    hb_codepoint_t codepoint;
    hb_mask_t      mask;
    uint32_t       cluster;
    /* private */
    hb_var_int_t   var1;
    hb_var_int_t   var2;
} hb_glyph_info_t;

typedef struct hb_glyph_position_t {
    hb_position_t  x_advance;
    hb_position_t  y_advance;
    hb_position_t  x_offset;
    hb_position_t  y_offset;
    /* private */
    hb_var_int_t   var;
} hb_glyph_position_t;

/*tex

    We only need to initialize the font and call a shaper. There is no need to interface more as we
    won't use those features. I never compiled this library myself and just took it from the system
    (e.g from inkscape). Keep in mind that names can be different on windows and linux.

    If needed we can reuse buffers and cache a bit more but it probably doesn't make much difference
    performance wise. Also, in a bit more complex document font handling is not the most time
    critical and when you use specific scripts in \TEX\ that are not supported otherwise and
    therefore demand a library run time is probably the least of your problems. So best is that we
    keep it all abstract.

*/

# define HBLIB_METATABLE  "optional.hblib"

typedef struct hblib_data {
    hb_font_t *font;
} hblib_data;

typedef struct hblib_state_info {

    int initialized;
    int padding;

    const char * (*hb_version_string) (
        void
    );

    hb_blob_t * (*hb_blob_create) (
        const char        *data,
        unsigned int       length,
        hb_memory_mode_t   mode, /* Could be int I guess. */
        void              *user_data,
        hb_destroy_func_t  destroy
    );

    void (*hb_blob_destroy) (
        hb_blob_t *blob
    );

    hb_face_t * (*hb_face_create) (
        hb_blob_t    *blob,
        unsigned int  index
    );

    void (*hb_face_destroy) (
        hb_face_t *face
    );

    hb_language_t (*hb_language_from_string) (
        const char *str,
        int         len
    );

    void (*hb_buffer_set_language) (
        hb_buffer_t   *buffer,
        hb_language_t  language
    );

    hb_script_t (*hb_script_from_string) (
        const char *s,
        int         len
    );

    void (*hb_buffer_set_script) (
        hb_buffer_t *buffer,
        hb_script_t  script
    );

    hb_direction_t (*hb_direction_from_string) (
        const char *str,
        int         len
    );

    void (*hb_buffer_set_direction) (
        hb_buffer_t    *buffer,
        hb_direction_t  direction
    );

    hb_bool_t (*hb_feature_from_string) (
        const char   *str,
        int           len,
        hb_feature_t *feature
    );

    hb_bool_t (*hb_shape_full) (
        hb_font_t          *font,
        hb_buffer_t        *buffer,
        const hb_feature_t *features,
        unsigned int        num_features,
        const char * const *shaper_list
    );

    hb_buffer_t * (*hb_buffer_create )(
        void
    );

    void (*hb_buffer_destroy)(
        hb_buffer_t *buffer
    );

    void (*hb_buffer_add_utf8) (
        hb_buffer_t  *buffer,
        const char   *text,
        int           text_length,
        unsigned int  item_offset,
        int           item_length
    );

    void (*hb_buffer_add_utf32) (
        hb_buffer_t  *buffer,
        const char   *text,
        int           text_length,
        unsigned int  item_offset,
        int           item_length
    );

    /* void (*hb_buffer_add) (
        hb_buffer_t    *buffer,
        hb_codepoint_t  codepoint,
        unsigned int    cluster
    ); */

    unsigned int (*hb_buffer_get_length) (
        hb_buffer_t *buffer
    );

    hb_glyph_info_t * (*hb_buffer_get_glyph_infos) (
        hb_buffer_t  *buffer,
        unsigned int *length
    );

    hb_glyph_position_t * (*hb_buffer_get_glyph_positions) (
        hb_buffer_t  *buffer,
        unsigned int *length
    );

    void (*hb_buffer_reverse) (
        hb_buffer_t *buffer
    );

    void (*hb_buffer_reset) (
        hb_buffer_t *buffer
    );

    void (*hb_buffer_guess_segment_properties) (
        hb_buffer_t *buffer
    );

    hb_font_t * (*hb_font_create) (
        hb_face_t *face
    );

    void (*hb_font_destroy) (
        hb_font_t *font
    );

    void (*hb_font_set_scale) (
        hb_font_t *font,
        int        x_scale,
        int        y_scale
    );

    void (*hb_ot_font_set_funcs) (
        hb_font_t *font
    );

    unsigned int (*hb_face_get_upem) (
        hb_face_t *face
    );

    const char ** (*hb_shape_list_shapers) (
        void
    );

} hblib_state_info;

static hblib_state_info hblib_state = {

    .initialized                        = 0,
    .padding                            = 0,

    .hb_version_string                  = NULL,
    .hb_blob_create                     = NULL,
    .hb_blob_destroy                    = NULL,
    .hb_face_create                     = NULL,
    .hb_face_destroy                    = NULL,
    .hb_language_from_string            = NULL,
    .hb_buffer_set_language             = NULL,
    .hb_script_from_string              = NULL,
    .hb_buffer_set_script               = NULL,
    .hb_direction_from_string           = NULL,
    .hb_buffer_set_direction            = NULL,
    .hb_feature_from_string             = NULL,
    .hb_shape_full                      = NULL,
    .hb_buffer_create                   = NULL,
    .hb_buffer_destroy                  = NULL,
    .hb_buffer_add_utf8                 = NULL,
    .hb_buffer_add_utf32                = NULL,
 /* .hb_buffer_add                      = NULL, */
    .hb_buffer_get_length               = NULL,
    .hb_buffer_get_glyph_infos          = NULL,
    .hb_buffer_get_glyph_positions      = NULL,
    .hb_buffer_reverse                  = NULL,
    .hb_buffer_reset                    = NULL,
    .hb_buffer_guess_segment_properties = NULL,
    .hb_font_create                     = NULL,
    .hb_font_destroy                    = NULL,
    .hb_font_set_scale                  = NULL,
    .hb_ot_font_set_funcs               = NULL,
    .hb_face_get_upem                   = NULL,
    .hb_shape_list_shapers              = NULL,

};

/* <boolean> = initialize(full_path_of_library) */

static int hblib_initialize(lua_State * L)
{
    if (! hblib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            hblib_state.hb_version_string                  = lmt_library_find(lib, "hb_version_string");
            hblib_state.hb_language_from_string            = lmt_library_find(lib, "hb_language_from_string");
            hblib_state.hb_script_from_string              = lmt_library_find(lib, "hb_script_from_string");
            hblib_state.hb_direction_from_string           = lmt_library_find(lib, "hb_direction_from_string");
            hblib_state.hb_feature_from_string             = lmt_library_find(lib, "hb_feature_from_string");

            hblib_state.hb_buffer_set_language             = lmt_library_find(lib, "hb_buffer_set_language");
            hblib_state.hb_buffer_set_script               = lmt_library_find(lib, "hb_buffer_set_script");
            hblib_state.hb_buffer_set_direction            = lmt_library_find(lib, "hb_buffer_set_direction");

            hblib_state.hb_buffer_create                   = lmt_library_find(lib, "hb_buffer_create");
            hblib_state.hb_buffer_destroy                  = lmt_library_find(lib, "hb_buffer_destroy");
            hblib_state.hb_buffer_reverse                  = lmt_library_find(lib, "hb_buffer_reverse");
            hblib_state.hb_buffer_get_length               = lmt_library_find(lib, "hb_buffer_get_length");
            hblib_state.hb_buffer_reset                    = lmt_library_find(lib, "hb_buffer_reset");
            hblib_state.hb_buffer_add_utf8                 = lmt_library_find(lib, "hb_buffer_add_utf8");
            hblib_state.hb_buffer_add_utf32                = lmt_library_find(lib, "hb_buffer_add_utf32");

            hblib_state.hb_blob_create                     = lmt_library_find(lib, "hb_blob_create");
            hblib_state.hb_blob_destroy                    = lmt_library_find(lib, "hb_blob_destroy");

            hblib_state.hb_face_create                     = lmt_library_find(lib, "hb_face_create");
            hblib_state.hb_face_destroy                    = lmt_library_find(lib, "hb_face_destroy");
            hblib_state.hb_face_get_upem                   = lmt_library_find(lib, "hb_face_get_upem");

            hblib_state.hb_font_create                     = lmt_library_find(lib, "hb_font_create");
            hblib_state.hb_font_destroy                    = lmt_library_find(lib, "hb_font_destroy");
            hblib_state.hb_font_set_scale                  = lmt_library_find(lib, "hb_font_set_scale");

            hblib_state.hb_shape_list_shapers              = lmt_library_find(lib, "hb_shape_list_shapers");
            hblib_state.hb_shape_full                      = lmt_library_find(lib, "hb_shape_full");

            hblib_state.hb_ot_font_set_funcs               = lmt_library_find(lib, "hb_ot_font_set_funcs");

            hblib_state.hb_buffer_guess_segment_properties = lmt_library_find(lib, "hb_buffer_guess_segment_properties");
            hblib_state.hb_buffer_get_glyph_positions      = lmt_library_find(lib, "hb_buffer_get_glyph_positions");
            hblib_state.hb_buffer_get_glyph_infos          = lmt_library_find(lib, "hb_buffer_get_glyph_infos");

            hblib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, hblib_state.initialized);
    return 1;
}

/* <string> = getversion() */

static int hblib_get_version(lua_State * L)
{
    if (hblib_state.initialized) {
        lua_pushstring(L, hblib_state.hb_version_string());
        return 1;
    } else {
        return 0;
    }
}

/* <instance> = loadfont(identifier, fontdata) */

static int hblib_load_font(lua_State * L)
{
    if (hblib_state.initialized) {
        int id = (int) lua_tointeger(L, 1);
        const char *str= lua_tostring(L, 2);
        int size = (int) lua_rawlen(L, 2);
        hb_blob_t *blob = hblib_state.hb_blob_create(str, size, 0, NULL, NULL);
        hb_face_t *face = hblib_state.hb_face_create(blob, id);
        unsigned int scale = hblib_state.hb_face_get_upem(face);
        hb_font_t *font = hblib_state.hb_font_create(face);
        hblib_state.hb_font_set_scale(font, scale, scale);
        hblib_state.hb_ot_font_set_funcs(font);
        hblib_data *data = lua_newuserdatauv(L, sizeof(data), 0);
        data->font = font;
        luaL_getmetatable(L, HBLIB_METATABLE);
        lua_setmetatable(L, -2);
        hblib_state.hb_blob_destroy(blob);
        hblib_state.hb_face_destroy(face);
        return 1;
    } else {
        return 0;
    }
}

/* <table> = shapestring(instance, script, language, direction, { shapers }, { features }, text, reverse) */

static int hblib_utf8len(const char *text, size_t size) /* todo: take from utilities */
{
    size_t ls = size;
    int ind = 0;
    int num = 0;
    while (ind < (int) ls) {
        unsigned char i = (unsigned char) *(text + ind);
        if (i < 0x80) {
            ind += 1;
        } else if (i >= 0xF0) {
            ind += 4;
        } else if (i >= 0xE0) {
            ind += 3;
        } else if (i >= 0xC0) {
            ind += 2;
        } else {
            ind += 1;
        }
        num += 1;
    }
    return num;
}

static int hblib_utf32len(const char *text, size_t size)
{
    /* not okay, hb doesn't stop at \0 */
 /* (void) s; */
 /* return (int) size / 4; */
    /* so we do this instead */
    size_t ls = size;
    int ind = 0;
    int num = 0;
    while (ind < (int) ls) {
        unsigned char i = (unsigned char) *(text + ind);
        if (i) {
            ind += 4;
        } else {
            break;
        }
        num += 1;
    }
    return num;
}

/*tex

    Maybe with |utfbits == 0| take a table with code points, but then we might also need cluster
    stuff, so there is no gain here.

    I remember some issues with passing features (maybe because some defaults are always set) but
    it's not really that important because one actually expects the library to handle them that way
    (read: only enable additional ones). But I will look into it when needed.

*/

static int hblib_shape_string(lua_State * L)
{
    if (hblib_state.initialized) {
        hblib_data *data = luaL_checkudata(L, 1, HBLIB_METATABLE);
        if (data == NULL) {
            lua_pushnil(L);
        } else {
            /* Maybe we can better take a table, so it's a yet undecided api. */
            size_t          nofscript    = 0;
            const char     *script       = lua_tolstring(L, 2, &nofscript);
            size_t          noflanguage  = 0;
            const char     *language     = lua_tolstring(L, 3, &noflanguage);
            size_t          nofdirection = 0;
            const char     *direction    = lua_tolstring(L, 4, &nofdirection);
            int             nofshapers   = 0;
            const char   * *shapers      = NULL; /* slot 5 */
            int             noffeatures  = 0;
            hb_feature_t   *features     = NULL; /* slot 6 */
            size_t          noftext      = 0;
            const char     *text         = lua_tolstring(L, 7, &noftext);
            int             reverse      = lua_toboolean(L, 8);
            int             utfbits      = (int) luaL_optinteger(L, 9, 8);
            hb_buffer_t    *buffer       = NULL;
            /*
                Shapers are passed as a table; why not pass the length here too ... simpler in
                ffi -) Maybe I'll make this more static: a general setshaper or so, which is
                more natural than having it as argument to the shape function.

                MSVC wants |char**| for the shapers and gcc wants |const char**| i.e.\ doesn't
                like a cast so we just accept the less annoying  MSVC warning.
            */
            if (lua_istable(L,5)) {
                lua_Unsigned n = lua_rawlen(L, 5);
                if (n > 0) {
                    shapers = malloc((size_t) (n + 1) * sizeof(char *));
                    if (shapers) {
                        for (lua_Unsigned i = 0; i < n; i++) {
                            lua_rawgeti(L, 5, i + 1);
                            if (lua_isstring(L, -1)) {
                                shapers[nofshapers] = lua_tostring(L, -1);
                                nofshapers += 1;
                            }
                            lua_pop(L, 1);
                        }
                    } else {
                        luaL_error(L, "optional hblib: unable to allocate shaper memory");
                    }
                    /* sentinal */
                    shapers[nofshapers] = NULL;
                }
            }
            /*
                Features need to be converted to a table of features (manual work); simpler in
                ffi -) Maybe I'll move this to the loadfont function.
            */
            if (lua_istable(L, 6)) {
                lua_Unsigned n = lua_rawlen(L, 6);
                if (n > 0) {
                    features = malloc((size_t) n * sizeof(hb_feature_t));
                    if (features) {
                        for (lua_Unsigned i = 0; i < n; i++) {
                            lua_rawgeti(L, 6, i + 1);
                            if (lua_isstring(L, -1)) {
                                size_t l = 0;
                                const char *s = lua_tolstring(L, -1, &l);
                                hblib_state.hb_feature_from_string(s, (int) l, &features[noffeatures]);
                                noffeatures += 1;
                            }
                            lua_pop(L, 1);
                        }
                    } else {
                        luaL_error(L, "optional hblib: unable to allocate feature memory");
                    }
                }
            }
            /* Some preparations (see original ffi variant). */
            buffer =hblib_state. hb_buffer_create(); /* we could put this in the data blob */
            /*
                When using ffi we used to use utf32 plus some slack because utf8 crashed. It would
                be more handy if we could pass an array of integers (maybe we can).
            */
            if (utfbits == 32) {
                hblib_state.hb_buffer_add_utf32(buffer, text, (int) noftext, 0, hblib_utf32len(text, noftext));
            } else { /* 8 */
                hblib_state.hb_buffer_add_utf8(buffer, text, (int) noftext, 0, hblib_utf8len(text, noftext));
            }
            hblib_state.hb_buffer_set_language(buffer, hblib_state.hb_language_from_string(language, (int) noflanguage));
            hblib_state.hb_buffer_set_script(buffer, hblib_state.hb_script_from_string(script, (int) nofscript));
            hblib_state.hb_buffer_set_direction(buffer, hblib_state.hb_direction_from_string(direction, (int) nofdirection));
            hblib_state.hb_buffer_guess_segment_properties(buffer);
            /* Do it! */
            hblib_state.hb_shape_full(data->font, buffer, features, noffeatures, shapers);
            /* Fixup. */
            if (reverse) {
                hblib_state.hb_buffer_reverse(buffer);
            }
            /* Convert the result: plain and simple.*/
            {
                unsigned length = hblib_state.hb_buffer_get_length(buffer);
                hb_glyph_info_t *infos = hblib_state.hb_buffer_get_glyph_infos(buffer, NULL);
                hb_glyph_position_t *positions = hblib_state.hb_buffer_get_glyph_positions(buffer, NULL);
                lua_createtable(L, length, 0);
                for (unsigned i = 0; i < length; i++) {
                    lua_createtable(L, 6, 0);
                    lua_pushinteger(L, infos[i].codepoint);
                    lua_rawseti(L, -2, 1);
                    lua_pushinteger(L, infos[i].cluster);
                    lua_rawseti(L, -2, 2);
                    lua_pushinteger(L, positions[i].x_offset);
                    lua_rawseti(L, -2, 3);
                    lua_pushinteger(L, positions[i].y_offset);
                    lua_rawseti(L, -2, 4);
                    lua_pushinteger(L, positions[i].x_advance);
                    lua_rawseti(L, -2, 5);
                    lua_pushinteger(L, positions[i].y_advance);
                    lua_rawseti(L, -2, 6);
                    lua_rawseti(L, -2, i + 1);
               }
            }
            hblib_state.hb_buffer_destroy(buffer);
            free((void *) shapers); /* we didn't make copies of the lua strings, ms compiler gives warning */
            free((void *) features);
        }
        return 1;
    } else {
        return 0;
    }
}

/* <table> = getshapers() */

static int hblib_get_shapers(lua_State * L)
{
    if (hblib_state.initialized) {
        const char * *shapers = hblib_state.hb_shape_list_shapers();
        if (shapers) {
            int nofshapers = 0;
            lua_createtable(L, 1, 0);
            while (1) {
                const char *s = shapers[nofshapers];
                if (s) {
                    nofshapers++;
                    lua_pushstring(L, s);
                    lua_rawseti(L, -2, nofshapers);
                } else {
                    break;
                }
            }
            return 1;
        }
    }
    return 0;
}

/* private */

static int hblib_free(lua_State * L)
{
    if (hblib_state.initialized) {
        hblib_data *data = luaL_checkudata(L, 1, HBLIB_METATABLE);
        if (data) {
            hblib_state.hb_font_destroy(data->font);
        }
    }
    return 0;
}

/* <string> = tostring(instance) */

static int hblib_tostring(lua_State * L)
{
    if (hblib_state.initialized) {
        hblib_data *data = luaL_checkudata(L, 1, HBLIB_METATABLE);
        if (data) {
            lua_pushfstring(L, "<optional.hblib.instance %p>", data);
        } else {
            lua_pushnil(L);
        }
        return 1;
    } else {
        return 0;
    }
}

/*tex We can do with a rather mimimal user data object. */

static const struct luaL_Reg hblib_metatable[] = {
    { "__tostring", hblib_tostring },
    { "__gc",       hblib_free     },
    { NULL,         NULL           },
};

/*tex

    Idem, just the collected calls of the ffi variant. The less the better because that way there
    is no tricky code needed at the \LUA\ end.

*/

static struct luaL_Reg hblib_function_list[] = {
    { "initialize",  hblib_initialize   },
    { "getversion",  hblib_get_version  },
    { "getshapers",  hblib_get_shapers  },
    { "loadfont",    hblib_load_font    },
    { "shapestring", hblib_shape_string },
    { NULL,          NULL               },
};

int luaopen_hb(lua_State *L)
{
    luaL_newmetatable(L, HBLIB_METATABLE);
    luaL_setfuncs(L, hblib_metatable, 0);
    lmt_library_register(L, "hb", hblib_function_list);
    return 0;
}
