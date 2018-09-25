if not modules then modules = { } end modules ['lang-def'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
 -- dataonly  = true, -- saves 10K
}

local rawget = rawget
local lower = string.lower

languages               = languages or { }
local languages         = languages
languages.data          = languages.data or { }
local data              = languages.data

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

-- The specifications are based on an analysis done by Arthur. The
-- names of tags were changed by Hans. The data is not yet used but
-- will be some day.
--
-- description
--
-- The description is only meant as an indication; for example 'no' is
-- "Norwegian, undetermined" because that's really what it is.
--
-- script
--
-- This is the 4-letter script tag according to ISO 15924, the
-- official standard.
--
-- bibliographical and terminological
--
-- Then we have *two* ISO-639 3-letter tags: one is supposed to be used
-- for "bibliographical" purposes, the other for "terminological".  The
-- first one is quite special (and mostly used in American libraries),
-- and the more interesting one is the other (apparently it's that one
-- we find everywhere).
--
-- context
--
-- These are the ones used in ConteXt. Kind of numberplate ones.
--
-- opentype
--
-- This is the 3-letter OpenType language tag, obviously.
--
-- variant
--
-- This is actually the rfc4646: an extension of ISO-639 that also defines
-- codes for variants like de-1901 for "German, 1901 orthography" or zh-Hans for
-- "Chinese, simplified characters" ('Hans' is the ISO-15924 tag for
-- "HAN ideographs, Simplified" :-)  As I said yesterday, I think this
-- should be the reference since it's exactly what we want: it's really
-- standard (it's a RFC) and it's more than simply languages.  To my
-- knowledge this is the only system that addresses this issue.
--
-- Warning: it's not unique!  Because we have two "German" languages
-- (and could, potentially, have two Chinese, etc.)
--
-- Beware: the abbreviations are lowercased, which makes it more
-- convenient to use them.
--
-- todo: add default features

local specifications = allocate {
    {
        ["description"] = "Dutch",
        ["script"] = "latn",
     -- ["bibliographical"] = "nld",
     -- ["terminological"] = "nld",
        ["context"] = "nl",
        ["opentype"] = "nld",
        ["variant"] = "nl",
    },
    {
        ["description"] = "Basque",
        ["script"] = "latn",
        ["bibliographical"] = "baq",
        ["terminological"] = "eus",
        ["context"] = "ba",
        ["opentype"] = "euq",
        ["variant"] = "eu",
    },
    {
        ["description"] = "Welsh",
        ["script"] = "latn",
        ["bibliographical"] = "wel",
        ["terminological"] = "cym",
        ["context"] = "cy",
        ["opentype"] = "wel",
        ["variant"] = "cy",
    },
    {
        ["description"] = "Icelandic",
        ["script"] = "latn",
        ["bibliographical"] = "ice",
        ["terminological"] = "isl",
        ["context"] = "is",
        ["opentype"] = "isl",
        ["variant"] = "is",
    },
    {
        ["description"] = "Norwegian, undetermined",
        ["script"] = "latn",
        ["bibliographical"] = "nor",
        ["terminological"] = "nor",
        ["context"] = "no",
        ["variant"] = "no",
    },
    {
        ["description"] = "Norwegian bokmal",
        ["script"] = "latn",
        ["bibliographical"] = "nob",
        ["terminological"] = "nob",
        ["opentype"] = "nor", -- not sure!
        ["variant"] = "nb",
    },
    {
        ["description"] = "Norwegian nynorsk",
        ["script"] = "latn",
        ["bibliographical"] = "nno",
        ["terminological"] = "nno",
        ["opentype"] = "nny",
        ["variant"] = "nn",
    },
    {
        ["description"] = "Ancient Greek",
        ["script"] = "grek",
        ["bibliographical"] = "grc",
        ["terminological"] = "grc",
        ["context"] = "agr",
        ["variant"] = "grc",
    },
    {
        ["description"] = "German, 1901 orthography",
        ["script"] = "latn",
        ["terminological"] = "deu",
        ["context"] = "deo",
        ["opentype"] = "deu",
        ["variant"] = "de-1901",
    },
    {
        ["description"] = "German, 1996 orthography",
        ["script"] = "latn",
        ["bibliographical"] = "ger",
        ["terminological"] = "deu",
        ["context"] = "de",
        ["opentype"] = "deu",
        ["variant"] = "de-1996",
    },
    {
        ["description"] = "Afrikaans",
        ["script"] = "latn",
        ["bibliographical"] = "afr",
        ["terminological"] = "afr",
        ["context"] = "af",
        ["opentype"] = "afk",
        ["variant"] = "af",
    },
    {
        ["description"] = "Catalan",
        ["script"] = "latn",
        ["bibliographical"] = "cat",
        ["terminological"] = "cat",
        ["context"] = "ca",
        ["opentype"] = "cat",
        ["variant"] = "ca",
    },
    {
        ["description"] = "Czech",
        ["script"] = "latn",
        ["bibliographical"] = "cze",
        ["terminological"] = "ces",
        ["context"] = "cz",
        ["opentype"] = "csy",
        ["variant"] = "cs",
    },
    {
        ["description"] = "Greek",
        ["script"] = "grek",
        ["bibliographical"] = "gre",
        ["terminological"] = "ell",
        ["context"] = "gr",
        ["opentype"] = "ell",
        ["variant"] = "el",
    },
    {
        ["description"] = "American English",
        ["script"] = "latn",
        ["bibliographical"] = "eng",
        ["terminological"] = "eng",
        ["context"] = "us",
        ["opentype"] = "eng",
        ["variant"] = "en-US",
    },
    {
        ["description"] = "British English",
        ["script"] = "latn",
        ["bibliographical"] = "eng",
        ["terminological"] = "eng",
        ["context"] = "uk",
        ["opentype"] = "eng",
        ["variant"] = "en-UK", -- Could be en-GB as well ...
    },
    {
        ["description"] = "Spanish",
        ["script"] = "latn",
        ["bibliographical"] = "spa",
        ["terminological"] = "spa",
        ["context"] = "es",
        ["opentype"] = "esp",
        ["variant"] = "es",
    },
    {
        ["description"] = "Finnish",
        ["script"] = "latn",
        ["bibliographical"] = "fin",
        ["terminological"] = "fin",
        ["context"] = "fi",
        ["opentype"] = "fin",
        ["variant"] = "fi",
    },
    {
        ["description"] = "Estonian",
        ["script"] = "latn",
        ["bibliographical"] = "est",
        ["terminological"] = "est",
        ["context"] = "et",
        ["opentype"] = "est",
        ["variant"] = "et",
    },
    {
        ["description"] = "French",
        ["script"] = "latn",
        ["bibliographical"] = "fre",
        ["terminological"] = "fra",
        ["context"] = "fr",
        ["opentype"] = "fra",
        ["variant"] = "fr",
    },
    {
        ["description"] = "Croatian",
        ["script"] = "latn",
        ["bibliographical"] = "scr",
        ["terminological"] = "hrv",
        ["context"] = "hr",
        ["opentype"] = "hrv",
        ["variant"] = "hr",
    },
    {
        ["description"] = "Hungarian",
        ["script"] = "latn",
        ["bibliographical"] = "hun",
        ["terminological"] = "hun",
        ["context"] = "hu",
        ["opentype"] = "hun",
        ["variant"] = "hu",
    },
    {
        ["description"] = "Italian",
        ["script"] = "latn",
        ["bibliographical"] = "ita",
        ["terminological"] = "ita",
        ["context"] = "it",
        ["opentype"] = "ita",
        ["variant"] = "it",
    },
    {
        ["description"] = "Japanese",
        ["script"] = "jpan",
        ["bibliographical"] = "jpn",
        ["terminological"] = "jpn",
        ["context"] = "ja",
        ["opentype"] = "jan",
        ["variant"] = "ja",
    },
    {
        ["description"] = "Latin",
        ["script"] = "latn",
        ["bibliographical"] = "lat",
        ["terminological"] = "lat",
        ["context"] = "la",
        ["opentype"] = "lat",
        ["variant"] = "la",
    },
    {
        ["description"] = "Portuguese",
        ["script"] = "latn",
        ["bibliographical"] = "por",
        ["terminological"] = "por",
        ["context"] = "pt",
        ["opentype"] = "ptg",
        ["variant"] = "pt",
    },
    {
        ["description"] = "Polish",
        ["script"] = "latn",
        ["bibliographical"] = "pol",
        ["terminological"] = "pol",
        ["context"] = "pl",
        ["opentype"] = "plk",
        ["variant"] = "pl",
    },
    {
        ["description"] = "Romanian",
        ["script"] = "latn",
        ["bibliographical"] = "rum",
        ["terminological"] = "ron",
        ["context"] = "ro",
        ["opentype"] = "rom",
        ["variant"] = "ro",
    },
    {
        ["description"] = "Russian",
        ["script"] = "cyrl",
        ["bibliographical"] = "rus",
        ["terminological"] = "rus",
        ["context"] = "ru",
        ["opentype"] = "rus",
        ["variant"] = "ru",
    },
    {
        ["description"] = "Slovak",
        ["script"] = "latn",
        ["bibliographical"] = "slo",
        ["terminological"] = "slk",
        ["context"] = "sk",
        ["opentype"] = "sky",
        ["variant"] = "sk",
    },
    {
        ["description"] = "Slovenian",
        ["script"] = "latn",
        ["bibliographical"] = "slv",
        ["terminological"] = "slv",
        ["context"] = "sl",
        ["opentype"] = "slv",
        ["variant"] = "sl",
    },
    {
        ["description"] = "Swedish",
        ["script"] = "latn",
        ["bibliographical"] = "swe",
        ["terminological"] = "swe",
        ["context"] = "sv",
        ["opentype"] = "sve",
        ["variant"] = "sv",
    },
    {
        ["description"] = "Thai",
        ["script"] = "thai",
     -- ["bibliographical"] = "",
     -- ["terminological"] = "",
        ["context"] = "th",
        ["opentype"] = "tha",
     -- ["variant"] = "",
    },
    {
        ["description"] = "Turkish",
        ["script"] = "latn",
        ["bibliographical"] = "tur",
        ["terminological"] = "tur",
        ["context"] = "tr",
        ["opentype"] = "trk",
        ["variant"] = "tr",
    },
    {
        ["description"] = "Vietnamese",
        ["script"] = "latn",
        ["bibliographical"] = "vie",
        ["terminological"] = "vie",
        ["context"] = "vn",
        ["opentype"] = "vit",
        ["variant"] = "vi",
    },
    {
        ["description"] = "Chinese, simplified",
        ["script"] = "hans",
        ["opentypescript"] = "hani",
        ["bibliographical"] = "chi",
        ["terminological"] = "zho",
        ["context"] = "cn",
        ["opentype"] = "zhs",
        ["variant"] = "zh-hans",
    },
}

data.specifications = specifications

local variants        = { }   data.variants        = variants
local contexts        = { }   data.contexts        = contexts
local records         = { }   data.records         = records
local scripts         = { }   data.scripts         = scripts
local opentypes       = { }   data.opentypes       = opentypes
local opentypescripts = { }   data.opentypescripts = opentypescripts

for k=1,#specifications do
    local specification = specifications[k]
    local variant = specification.variant
    if variant then
        variants[lower(variant)] = specification
    end
    local opentype = specification.opentype
    if opentype then
        opentypes[lower(opentype)] = specification
    end
    local script = specification.script
    if script then
        scripts[lower(script)] = specification
    end
    local opentypescript = specification.opentypescript
    if opentypescript then
        opentypescripts[lower(opentypescript)] = specification
    end
    local context = context
    if context then
        if type(context) == "table" then
            for k=1,#context do
                contexts[context[k]] = specification
            end
        else
            contexts[context] = specification
        end
    end
end

local defaultvariant = variants["en-us"]

local function get(k,key)
    local v = rawget(variants,k) or rawget(opentypes,k) or rawget(contexts,k)
    return v and v[key]
end

setmetatableindex(variants, function(t,k)
    k = lower(k)
    local v = get(k,"language") or defaultvariant.language
    t[k] = v
    return v
end)

setmetatableindex(opentypes, function(t,k)
    k = lower(k)
    local v = get(k,"opentype") or "dflt"
    t[k] = v
    return v
end)

setmetatableindex(opentypescripts, function(t,k)
    k = lower(k)
    local v = get(k,"opentypescript") or get(k,"script") or defaultvariant.opentypescript or defaultvariant.script
    t[k] = v
    return v
end)

setmetatableindex(contexts, function(t,k)
    k = lower(str)
    local v = get(k,"context") or defaultvariant.context
    v = type(v) == "table" and v[1] or v
    t[k] = v
    return v
end)

setmetatableindex(records, function(t,k) -- how useful is this one?
    k = lower(k)
    local v = get(k) or defaultvariant
    t[k] = v
    return v
end)

-- print(opentypes.nl,opentypescripts.nl)
-- print(opentypes.de,opentypescripts.de)
