if not modules then modules = { } end modules ['font-phb-imp-library'] = {
    version   = 1.000, -- 2020.01.08,
    comment   = "companion to font-txt.mkiv",
    original  = "derived from a prototype by Kai Eigner",
    author    = "Hans Hagen", -- so don't blame KE
    copyright = "TAT Zetwerk / PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- The hb library comes in versions and the one I tested in 2016 was part of the inkscape
-- suite. In principle one can have incompatibilities due to updates but that is the nature
-- of a library. When a library ie expected one has better use the system version, if only
-- to make sure that different programs behave the same.
--
-- The main reason for testing this approach was that when Idris was working on his fonts,
-- we wanted to know how different shapers deal with it and the hb command line program
-- could provide uniscribe output. For the context shaper uniscribe is the reference, also
-- because Idris started out with Volt a decade ago.
--
-- We treat the lib as a black box as it should be. At some point Kai Eigner made an ffi
-- binding and that one was adapted to the plugin approach of context. It saved me the
-- trouble of looking at source files to figure it all out. Below is the adapted code.
--
-- Keep in mind that this file is for mkiv only. It won't work in lmtx where instead of
-- ffi we use simple optional libraries with delayed bindings. In principle this mechanism
-- is generic but because other macropackages follow another route we don't spend time
-- on that code path here.

local next, tonumber, pcall = next, tonumber, pcall
local reverse = table.reverse
local loaddata = io.loaddata

local report      = utilities.hb.report or print
local packtoutf32 = utilities.hb.helpers.packtoutf32

if not FFISUPPORTED or not ffi then
    report("no ffi support")
    return
elseif CONTEXTLMTXMODE and CONTEXTLMTXMODE > 0 then
    report("no ffi support")
    return
elseif not context then
    return
end

local harfbuzz = ffilib(os.name == "windows" and "libharfbuzz-0" or "libharfbuzz")

if not harfbuzz then
    report("no hb library found")
    return
end

-- jit.on() : on very long (hundreds of pages) it looks faster but
-- the normal font processor slows down ... this is consistent with
-- earlier observations that turning it on is often slower on these
-- one-shot tex runs (also because we don't use many math and/or
-- string helpers and therefore the faster vm of luajit gives most
-- benefits (given the patched hasher)

-- Here is Kai's ffi mapping, a bit reorganized. We only define what we
-- need. I'm happy that Kai did the deciphering of the api that I could
-- then build upon.

ffi.cdef [[

typedef struct hb_blob_t hb_blob_t ;

typedef enum {
    HB_MEMORY_MODE_DUPLICATE,
    HB_MEMORY_MODE_READONLY,
    HB_MEMORY_MODE_WRITABLE,
    HB_MEMORY_MODE_READONLY_MAY_MAKE_WRITABLE
} hb_memory_mode_t ;

typedef void (*hb_destroy_func_t) (
    void *user_data
) ;

typedef struct hb_face_t hb_face_t ;

typedef const struct hb_language_impl_t *hb_language_t ;

typedef struct hb_buffer_t hb_buffer_t ;

typedef enum {
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
} hb_script_t ;

typedef enum {
    HB_DIRECTION_INVALID,
    HB_DIRECTION_LTR,
    HB_DIRECTION_RTL,
    HB_DIRECTION_TTB,
    HB_DIRECTION_BTT
} hb_direction_t ;

typedef int hb_bool_t ;

typedef uint32_t hb_tag_t ;

typedef struct hb_feature_t {
    hb_tag_t      tag;
    uint32_t      value;
    unsigned int  start;
    unsigned int  end;
} hb_feature_t ;

typedef struct hb_font_t hb_font_t ;

typedef uint32_t hb_codepoint_t ;
typedef int32_t  hb_position_t ;
typedef uint32_t hb_mask_t ;

typedef union _hb_var_int_t {
    uint32_t u32;
    int32_t  i32;
    uint16_t u16[2];
    int16_t  i16[2];
    uint8_t  u8[4];
    int8_t   i8[4];
} hb_var_int_t ;

typedef struct hb_glyph_info_t {
    hb_codepoint_t codepoint ;
    hb_mask_t      mask ;
    uint32_t       cluster ;
    /*< private >*/
    hb_var_int_t   var1 ;
    hb_var_int_t   var2 ;
} hb_glyph_info_t ;

typedef struct hb_glyph_position_t {
    hb_position_t  x_advance ;
    hb_position_t  y_advance ;
    hb_position_t  x_offset ;
    hb_position_t  y_offset ;
    /*< private >*/
    hb_var_int_t   var ;
} hb_glyph_position_t ;

const char * hb_version_string (
    void
) ;

hb_blob_t * hb_blob_create (
    const char        *data,
    unsigned int       length,
    hb_memory_mode_t   mode,
    void              *user_data,
    hb_destroy_func_t  destroy
) ;

void hb_blob_destroy (
    hb_blob_t *blob
) ;

hb_face_t * hb_face_create (
    hb_blob_t    *blob,
    unsigned int  index
) ;

void hb_face_destroy (
    hb_face_t *face
) ;

hb_language_t hb_language_from_string (
    const char *str,
    int        len
) ;

void hb_buffer_set_language (
    hb_buffer_t   *buffer,
    hb_language_t  language
) ;

hb_script_t hb_script_from_string (
    const char *s,
    int         len
) ;

void hb_buffer_set_script (
    hb_buffer_t *buffer,
    hb_script_t  script
) ;

hb_direction_t hb_direction_from_string (
    const char *str,
    int         len
) ;

void hb_buffer_set_direction (
    hb_buffer_t     *buffer,
    hb_direction_t   direction
) ;

hb_bool_t hb_feature_from_string (
    const char   *str,
    int           len,
    hb_feature_t *feature
) ;

hb_bool_t hb_shape_full (
    hb_font_t          *font,
    hb_buffer_t        *buffer,
    const hb_feature_t *features,
    unsigned int        num_features,
    const char * const *shaper_list
) ;


hb_buffer_t * hb_buffer_create (
    void
) ;

void hb_buffer_destroy (
    hb_buffer_t *buffer
) ;

void hb_buffer_add_utf8 (
    hb_buffer_t  *buffer,
    const char   *text,
    int           text_length,
    unsigned int  item_offset,
    int           item_length
) ;

void hb_buffer_add_utf32 (
    hb_buffer_t  *buffer,
    const char   *text,
    int           text_length,
    unsigned int  item_offset,
    int           item_length
) ;

void hb_buffer_add (
    hb_buffer_t    *buffer,
    hb_codepoint_t  codepoint,
    unsigned int    cluster
) ;

unsigned int hb_buffer_get_length (
    hb_buffer_t *buffer
) ;

hb_glyph_info_t * hb_buffer_get_glyph_infos (
    hb_buffer_t  *buffer,
    unsigned int *length
) ;

hb_glyph_position_t *hb_buffer_get_glyph_positions (
    hb_buffer_t  *buffer,
    unsigned int *length
) ;

void hb_buffer_reverse (
    hb_buffer_t *buffer
) ;

void hb_buffer_reset (
    hb_buffer_t *buffer
) ;

void hb_buffer_guess_segment_properties (
    hb_buffer_t *buffer
) ;

hb_font_t * hb_font_create (
    hb_face_t *face
) ;

void hb_font_destroy (
    hb_font_t *font
) ;

void hb_font_set_scale (
    hb_font_t *font,
    int        x_scale,
    int        y_scale
) ;

void hb_ot_font_set_funcs (
    hb_font_t *font
) ;

unsigned int hb_face_get_upem (
    hb_face_t *face
) ;

const char ** hb_shape_list_shapers (
    void
);
]]

-- The library must be somewhere accessible. The calls to the library are similar to
-- the ones in the prototype but we organize things a bit differently. I tried to alias
-- the functions in the harfbuzz namespace (luajittex will optimize this anyway but
-- normal luatex not) but it crashes luajittex so I revered that.

do

    local l = harfbuzz.hb_shape_list_shapers()
    local s = { }

    for i=0,9 do
        local str = l[i]
        if str == ffi.NULL then
            break
        else
            s[#s+1] = ffi.string(str)
        end
    end

    report("using hb library version %a, supported shapers: %,t",ffi.string(harfbuzz.hb_version_string()),s)

end

-- we don't want to store userdata in the public data blob

local fontdata = fonts.hashes.identifiers

local loaded   = { }
local shared   = { }
local featured = { }

local function loadfont(font)
    local tfmdata   = fontdata[font]
    local resources = tfmdata.resources
    local filename  = resources.filename
    local instance  = shared[filename]
    if not instance then
        local wholefont = io.loaddata(filename)
        local wholeblob = ffi.gc(harfbuzz.hb_blob_create(wholefont,#wholefont,0,nil,nil),harfbuzz.hb_blob_destroy)
        local wholeface = ffi.gc(harfbuzz.hb_face_create(wholeblob,font),harfbuzz.hb_face_destroy)
        local scale     = harfbuzz.hb_face_get_upem(wholeface)
              instance  = ffi.gc(harfbuzz.hb_font_create(wholeface),harfbuzz.hb_font_destroy)
        harfbuzz.hb_font_set_scale(instance,scale,scale)
        harfbuzz.hb_ot_font_set_funcs(instance)
        shared[filename] = instance
    end
    return instance
end

local function loadfeatures(data)
    local featureset  = data.featureset or { }
    local feature     = ffi.new("hb_feature_t[?]",#featureset)
    local featurespec = feature[0]
    local noffeatures = 0
    for i=1,#featureset do
        local f = featureset[i]
        harfbuzz.hb_feature_from_string(f,#f,feature[noffeatures])
        noffeatures = noffeatures + 1
    end
    return {
        noffeatures = #featureset,
        featureblob = feature,
        featurespec = featurespec,
    }
end

local function crap(t)
    return ffi.new("const char *[?]", #t, t)
end

local shapers = {
    native    = crap { "ot", "uniscribe", "fallback" },
    uniscribe = crap { "uniscribe", "ot", "fallback" },
 -- uniscribe = crap { "uniscribe", "fallback" }, -- stalls without fallback when no uniscribe present
    fallback  = crap { "fallback" },
}

-- Reusing a buffer doesn't make a difference in performance so we forget
-- about it and keep things simple. Todo: check if using locals makes sense.

function utilities.hb.methods.library(font,data,rlmode,text,leading,trailing)
    local instance = loaded[font]
    if not instance then
        instance     = loadfont(font)
        loaded[font] = instance
    end
    -- todo: dflt -> DFLT ?
    -- todo: whatever -> Whatever ?
    local language  = data.language or "dflt"
    local script    = data.script or "dflt"
    local direction = rlmode < 0 and "rtl" or "ltr"
    local shaper    = shapers[data.shaper]
    local featurehash = data.features
    local featuredata = featured[featurehash]
    if not featuredata then
        featuredata           = loadfeatures(data)
        featured[featurehash] = featuredata
    end

    local buffer = ffi.gc(harfbuzz.hb_buffer_create(),harfbuzz.hb_buffer_destroy)

 -- if false then
 --     -- i have no time to look into this now but something like this should
 --     -- be possible .. it probably doesn't make a difference in performance
 --     local n = 0 -- here we also start at 0
 --     if leading then
 --         harfbuzz.hb_buffer_add(buffer,[todo: 0x20],n)
 --     end
 --     for i=1,#text do
 --         n = n + 1
 --         harfbuzz.hb_buffer_add(buffer,[todo: text[i] ],n)
 --     end
 --     if trailing then
 --         n = n + 1
 --         harfbuzz.hb_buffer_add(buffer,[todo: 0x20 ],n)
 --     end
 -- else
        -- maybe also utf 8 clusters here like on the command line but i have no time
        -- to figure that out
        text = packtoutf32(text,leading,trailing)
        local size = #text/4
        text = text .. "\000\000\000\000\000\000\000\000" -- trial and error: avoid crash
        harfbuzz.hb_buffer_add_utf32(buffer,text,#text,0,size)
 -- end

    -- maybe: hb_buffer_set_segment_properties(buffer,...)

    harfbuzz.hb_buffer_set_language(buffer,harfbuzz.hb_language_from_string(language,#language))
    harfbuzz.hb_buffer_set_script(buffer,harfbuzz.hb_script_from_string(script,#script))
    harfbuzz.hb_buffer_set_direction(buffer,harfbuzz.hb_direction_from_string(direction,#direction))

    harfbuzz.hb_buffer_guess_segment_properties(buffer) -- why is this needed (we already set them)
    harfbuzz.hb_shape_full(instance,buffer,featuredata.featurespec,featuredata.noffeatures,shaper)

    if rlmode < 0 then
        harfbuzz.hb_buffer_reverse(buffer)
    end

    local size      = harfbuzz.hb_buffer_get_length(buffer)
    local infos     = harfbuzz.hb_buffer_get_glyph_infos(buffer, nil)
    local positions = harfbuzz.hb_buffer_get_glyph_positions(buffer, nil)

    local result = { }
    for i=1,size do
        local info     = infos[i-1]
        local position = positions[i-1]
        result[i] = {
               info.codepoint,
               info.cluster,
               position.x_offset,
               position.y_offset,
               position.x_advance,
               position.y_advance,
           }
    end
 -- inspect(result)
    return result

end
