if not modules then modules = { } end modules ['font-otr'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- When looking into a cid font relates issue in the ff library I wondered if
-- it made sense to use Lua to filter the information from the otf and ttf
-- files. Quite some ff code relates to special fonts and in practice we only
-- use rather normal opentype fonts.
--
-- The code here is based on the documentation (and examples) at the microsoft
-- website. The code will be extended and improved stepwise. After some experiments
-- I decided to convert to a format more suitable for the context font handler
-- because it makes no sense to rehash all those lookups again.
--
-- Currently we can use this code for getting basic info about the font, loading
-- shapes and loading the extensive table. I'm not sure if I will provide a ff
-- compatible output as well (We're not that far from it as currently I can load
-- all data reasonable fast.)

-- This code is not yet ready for generic i.e. I want to be free to change the
-- keys and values. Especially the gpos/gsub/gdef/math needs checking (this
-- is implemented in font-dsp.lua).

-- We can omit redundant glyphs names i.e. ones that match the agl or
-- are just a unicode string but it doesn't save that much. It will be an option
-- some day.

-- Optimizing the widths wil be done anyway as it save quite some on a cjk font
-- and the existing (old) code if okay.

-- todo: more messages (only if really needed)
--
-- considered, in math:
--
-- start -> first (so we can skip the first same-size one)
-- end   -> last
--
-- Widths and weights are kind of messy: for instance lmmonolt has a pfmweight of
-- 400 while it should be 300. So, for now we mostly stick to the old compromis.

-- We don't really need all those language tables so they might be dropped some
-- day.

-- The new reader is faster on some aspects and slower on other. The memory footprint
-- is lower. The string reader is a  bit faster than the file reader. The new reader
-- gives more efficient tables and has bit more analysis. In practice these times are
-- not that relevant because we cache. The otf files take a it more time because we
-- need to calculate the boundingboxes. In theory the processing of text should be
-- somewhat faster especially for complex fonts with many lookups.
--
--                        old    new    str reader
-- lmroman12-regular.otf  0.103  0.203  0.195
-- latinmodern-math.otf   0.454  0.768  0.712
-- husayni.ttf            1.142  1.526  1.259
--
-- If there is demand I will consider making a ff compatible table dumper but it's
-- probably more fun to provide a way to show features applied.

-- I experimented a bit with f:readbyte(n) and f:readshort() and so and it is indeed
-- faster but it might not be the real bottleneck as we still need to juggle data. It
-- is probably more memory efficient as no intermediate strings are involved.

if not characters then
    require("char-def")
    require("char-ini")
end

local next, type, unpack = next, type, unpack
local byte, lower, char, strip, gsub = string.byte, string.lower, string.char, string.strip, string.gsub
local bittest = bit32.btest
local concat, remove = table.concat, table.remove
local floor, mod, abs, sqrt, round = math.floor, math.mod, math.abs, math.sqrt, math.round
local P, R, S, C, Cs, Cc, Ct, Carg, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Ct, lpeg.Carg, lpeg.Cmt
local lpegmatch = lpeg.match

local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters
local sortedkeys        = table.sortedkeys
local sortedhash        = table.sortedhash
local stripstring       = string.strip
local utf16_to_utf8_be  = utf.utf16_to_utf8_be

local report            = logs.reporter("otf reader")

local trace_cmap        = false -- only for checking issues

fonts                   = fonts or { }
local handlers          = fonts.handlers or { }
fonts.handlers          = handlers
local otf               = handlers.otf or { }
handlers.otf            = otf
local readers           = otf.readers or { }
otf.readers             = readers

----- streamreader      = utilities.streams -- faster on big files
local streamreader      = utilities.files   -- faster on identify

readers.streamreader    = streamreader

local openfile          = streamreader.open
local closefile         = streamreader.close
local skipbytes         = streamreader.skip
local setposition       = streamreader.setposition
local skipshort         = streamreader.skipshort
local readbytes         = streamreader.readbytes
local readstring        = streamreader.readstring
local readbyte          = streamreader.readcardinal1  --  8-bit unsigned integer
local readushort        = streamreader.readcardinal2  -- 16-bit unsigned integer
local readuint          = streamreader.readcardinal3  -- 24-bit unsigned integer
local readulong         = streamreader.readcardinal4  -- 24-bit unsigned integer
local readchar          = streamreader.readinteger1   --  8-bit   signed integer
local readshort         = streamreader.readinteger2   -- 16-bit   signed integer
local readlong          = streamreader.readinteger4   -- 24-bit unsigned integer
local readfixed         = streamreader.readfixed4
local readfword         = readshort                   -- 16-bit   signed integer that describes a quantity in FUnits
local readufword        = readushort                  -- 16-bit unsigned integer that describes a quantity in FUnits
local readoffset        = readushort
local read2dot14        = streamreader.read2dot14     -- 16-bit signed fixed number with the low 14 bits of fraction (2.14) (F2DOT14)

function streamreader.readtag(f)
    return lower(strip(readstring(f,4)))
end

-- date represented in number of seconds since 12:00 midnight, January 1, 1904. The value is represented as a
-- signed 64-bit integer

local function readlongdatetime(f)
    local a, b, c, d, e, f, g, h = readbytes(f,8)
    return 0x100000000 * d + 0x1000000 * e + 0x10000 * f + 0x100 * g + h
end

local tableversion      = 0.002
local privateoffset     = fonts.constructors and fonts.constructors.privateoffset or 0xF0000 -- 0x10FFFF

readers.tableversion    = tableversion

local reportedskipped   = { }

local function reportskippedtable(tag)
    if not reportedskipped[tag] then
        report("loading of table %a skipped (reported once only)",tag)
        reportedskipped[tag] = true
    end
end

-- We have quite some data tables. We are somewhat ff compatible with names but as I used
-- the information form the microsoft site there can be differences. Eventually I might end
-- up with a different ordering and naming.

local reservednames = { [0] =
    "copyright",
    "family",
    "subfamily",
    "uniqueid",
    "fullname",
    "version",
    "postscriptname",
    "trademark",
    "manufacturer",
    "designer",
    "description", -- descriptor in ff
    "venderurl",
    "designerurl",
    "license",
    "licenseurl",
    "reserved",
    "typographicfamily",    -- preffamilyname
    "typographicsubfamily", -- prefmodifiers
    "compatiblefullname", -- for mac
    "sampletext",
    "cidfindfontname",
    "wwsfamily",
    "wwssubfamily",
    "lightbackgroundpalette",
    "darkbackgroundpalette",
}

-- more at: https://www.microsoft.com/typography/otspec/name.htm

-- setmetatableindex(reservednames,function(t,k)
--     local v = "name_" .. k
--     t[k] =  v
--     return v
-- end)

local platforms = { [0] =
    "unicode",
    "macintosh",
    "iso",
    "windows",
    "custom",
}

local encodings = {
    -- these stay:
    unicode = { [0] =
        "unicode 1.0 semantics",
        "unicode 1.1 semantics",
        "iso/iec 10646",
        "unicode 2.0 bmp",             -- cmap subtable formats 0, 4, 6
        "unicode 2.0 full",            -- cmap subtable formats 0, 4, 6, 10, 12
        "unicode variation sequences", -- cmap subtable format 14).
        "unicode full repertoire",     -- cmap subtable formats 0, 4, 6, 10, 12, 13
    },
    -- these can go:
    macintosh = { [0] =
        "roman", "japanese", "chinese (traditional)", "korean", "arabic", "hebrew", "greek", "russian",
        "rsymbol", "devanagari", "gurmukhi", "gujarati", "oriya", "bengali", "tamil", "telugu", "kannada",
        "malayalam", "sinhalese", "burmese", "khmer", "thai", "laotian", "georgian", "armenian",
        "chinese (simplified)", "tibetan", "mongolian", "geez", "slavic", "vietnamese", "sindhi",
        "uninterpreted",
    },
    -- these stay:
    iso = { [0] =
        "7-bit ascii",
        "iso 10646",
        "iso 8859-1",
    },
    -- these stay:
    windows = { [0] =
        "symbol",
        "unicode bmp", -- this is utf16
        "shiftjis",
        "prc",
        "big5",
        "wansung",
        "johab",
        "reserved 7",
        "reserved 8",
        "reserved 9",
        "unicode ucs-4",
    },
    custom = {
        --custom: 0-255 : otf windows nt compatibility mapping
    }
}

local decoders = {
    unicode   = { },
    macintosh = { },
    iso       = { },
    windows   = {
        ["unicode bmp"] = utf16_to_utf8_be
    },
    custom    = { },
}

-- This is bit over the top as we can just look for either windows, unicode or macintosh
-- names (in that order). A font with no english name is probably a weird one anyway.

local languages = {
    -- these stay:
    unicode = {
        [  0] = "english",
    },
    -- english can stay:
    macintosh = {
        [  0] = "english",
     -- [  1] = "french",
     -- [  2] = "german",
     -- [  3] = "italian",
     -- [  4] = "dutch",
     -- [  5] = "swedish",
     -- [  6] = "spanish",
     -- [  7] = "danish",
     -- [  8] = "portuguese",
     -- [  9] = "norwegian",
     -- [ 10] = "hebrew",
     -- [ 11] = "japanese",
     -- [ 12] = "arabic",
     -- [ 13] = "finnish",
     -- [ 14] = "greek",
     -- [ 15] = "icelandic",
     -- [ 16] = "maltese",
     -- [ 17] = "turkish",
     -- [ 18] = "croatian",
     -- [ 19] = "chinese (traditional)",
     -- [ 20] = "urdu",
     -- [ 21] = "hindi",
     -- [ 22] = "thai",
     -- [ 23] = "korean",
     -- [ 24] = "lithuanian",
     -- [ 25] = "polish",
     -- [ 26] = "hungarian",
     -- [ 27] = "estonian",
     -- [ 28] = "latvian",
     -- [ 29] = "sami",
     -- [ 30] = "faroese",
     -- [ 31] = "farsi/persian",
     -- [ 32] = "russian",
     -- [ 33] = "chinese (simplified)",
     -- [ 34] = "flemish",
     -- [ 35] = "irish gaelic",
     -- [ 36] = "albanian",
     -- [ 37] = "romanian",
     -- [ 38] = "czech",
     -- [ 39] = "slovak",
     -- [ 40] = "slovenian",
     -- [ 41] = "yiddish",
     -- [ 42] = "serbian",
     -- [ 43] = "macedonian",
     -- [ 44] = "bulgarian",
     -- [ 45] = "ukrainian",
     -- [ 46] = "byelorussian",
     -- [ 47] = "uzbek",
     -- [ 48] = "kazakh",
     -- [ 49] = "azerbaijani (cyrillic script)",
     -- [ 50] = "azerbaijani (arabic script)",
     -- [ 51] = "armenian",
     -- [ 52] = "georgian",
     -- [ 53] = "moldavian",
     -- [ 54] = "kirghiz",
     -- [ 55] = "tajiki",
     -- [ 56] = "turkmen",
     -- [ 57] = "mongolian (mongolian script)",
     -- [ 58] = "mongolian (cyrillic script)",
     -- [ 59] = "pashto",
     -- [ 60] = "kurdish",
     -- [ 61] = "kashmiri",
     -- [ 62] = "sindhi",
     -- [ 63] = "tibetan",
     -- [ 64] = "nepali",
     -- [ 65] = "sanskrit",
     -- [ 66] = "marathi",
     -- [ 67] = "bengali",
     -- [ 68] = "assamese",
     -- [ 69] = "gujarati",
     -- [ 70] = "punjabi",
     -- [ 71] = "oriya",
     -- [ 72] = "malayalam",
     -- [ 73] = "kannada",
     -- [ 74] = "tamil",
     -- [ 75] = "telugu",
     -- [ 76] = "sinhalese",
     -- [ 77] = "burmese",
     -- [ 78] = "khmer",
     -- [ 79] = "lao",
     -- [ 80] = "vietnamese",
     -- [ 81] = "indonesian",
     -- [ 82] = "tagalong",
     -- [ 83] = "malay (roman script)",
     -- [ 84] = "malay (arabic script)",
     -- [ 85] = "amharic",
     -- [ 86] = "tigrinya",
     -- [ 87] = "galla",
     -- [ 88] = "somali",
     -- [ 89] = "swahili",
     -- [ 90] = "kinyarwanda/ruanda",
     -- [ 91] = "rundi",
     -- [ 92] = "nyanja/chewa",
     -- [ 93] = "malagasy",
     -- [ 94] = "esperanto",
     -- [128] = "welsh",
     -- [129] = "basque",
     -- [130] = "catalan",
     -- [131] = "latin",
     -- [132] = "quenchua",
     -- [133] = "guarani",
     -- [134] = "aymara",
     -- [135] = "tatar",
     -- [136] = "uighur",
     -- [137] = "dzongkha",
     -- [138] = "javanese (roman script)",
     -- [139] = "sundanese (roman script)",
     -- [140] = "galician",
     -- [141] = "afrikaans",
     -- [142] = "breton",
     -- [143] = "inuktitut",
     -- [144] = "scottish gaelic",
     -- [145] = "manx gaelic",
     -- [146] = "irish gaelic (with dot above)",
     -- [147] = "tongan",
     -- [148] = "greek (polytonic)",
     -- [149] = "greenlandic",
     -- [150] = "azerbaijani (roman script)",
    },
    -- these can stay:
    iso = {
    },
    -- english can stay:
    windows = {
     -- [0x0436] = "afrikaans - south africa",
     -- [0x041c] = "albanian - albania",
     -- [0x0484] = "alsatian - france",
     -- [0x045e] = "amharic - ethiopia",
     -- [0x1401] = "arabic - algeria",
     -- [0x3c01] = "arabic - bahrain",
     -- [0x0c01] = "arabic - egypt",
     -- [0x0801] = "arabic - iraq",
     -- [0x2c01] = "arabic - jordan",
     -- [0x3401] = "arabic - kuwait",
     -- [0x3001] = "arabic - lebanon",
     -- [0x1001] = "arabic - libya",
     -- [0x1801] = "arabic - morocco",
     -- [0x2001] = "arabic - oman",
     -- [0x4001] = "arabic - qatar",
     -- [0x0401] = "arabic - saudi arabia",
     -- [0x2801] = "arabic - syria",
     -- [0x1c01] = "arabic - tunisia",
     -- [0x3801] = "arabic - u.a.e.",
     -- [0x2401] = "arabic - yemen",
     -- [0x042b] = "armenian - armenia",
     -- [0x044d] = "assamese - india",
     -- [0x082c] = "azeri (cyrillic) - azerbaijan",
     -- [0x042c] = "azeri (latin) - azerbaijan",
     -- [0x046d] = "bashkir - russia",
     -- [0x042d] = "basque - basque",
     -- [0x0423] = "belarusian - belarus",
     -- [0x0845] = "bengali - bangladesh",
     -- [0x0445] = "bengali - india",
     -- [0x201a] = "bosnian (cyrillic) - bosnia and herzegovina",
     -- [0x141a] = "bosnian (latin) - bosnia and herzegovina",
     -- [0x047e] = "breton - france",
     -- [0x0402] = "bulgarian - bulgaria",
     -- [0x0403] = "catalan - catalan",
     -- [0x0c04] = "chinese - hong kong s.a.r.",
     -- [0x1404] = "chinese - macao s.a.r.",
     -- [0x0804] = "chinese - people's republic of china",
     -- [0x1004] = "chinese - singapore",
     -- [0x0404] = "chinese - taiwan",
     -- [0x0483] = "corsican - france",
     -- [0x041a] = "croatian - croatia",
     -- [0x101a] = "croatian (latin) - bosnia and herzegovina",
     -- [0x0405] = "czech - czech republic",
     -- [0x0406] = "danish - denmark",
     -- [0x048c] = "dari - afghanistan",
     -- [0x0465] = "divehi - maldives",
     -- [0x0813] = "dutch - belgium",
     -- [0x0413] = "dutch - netherlands",
     -- [0x0c09] = "english - australia",
     -- [0x2809] = "english - belize",
     -- [0x1009] = "english - canada",
     -- [0x2409] = "english - caribbean",
     -- [0x4009] = "english - india",
     -- [0x1809] = "english - ireland",
     -- [0x2009] = "english - jamaica",
     -- [0x4409] = "english - malaysia",
     -- [0x1409] = "english - new zealand",
     -- [0x3409] = "english - republic of the philippines",
     -- [0x4809] = "english - singapore",
     -- [0x1c09] = "english - south africa",
     -- [0x2c09] = "english - trinidad and tobago",
     -- [0x0809] = "english - united kingdom",
        [0x0409] = "english - united states",
     -- [0x3009] = "english - zimbabwe",
     -- [0x0425] = "estonian - estonia",
     -- [0x0438] = "faroese - faroe islands",
     -- [0x0464] = "filipino - philippines",
     -- [0x040b] = "finnish - finland",
     -- [0x080c] = "french - belgium",
     -- [0x0c0c] = "french - canada",
     -- [0x040c] = "french - france",
     -- [0x140c] = "french - luxembourg",
     -- [0x180c] = "french - principality of monoco",
     -- [0x100c] = "french - switzerland",
     -- [0x0462] = "frisian - netherlands",
     -- [0x0456] = "galician - galician",
     -- [0x0437] = "georgian -georgia",
     -- [0x0c07] = "german - austria",
     -- [0x0407] = "german - germany",
     -- [0x1407] = "german - liechtenstein",
     -- [0x1007] = "german - luxembourg",
     -- [0x0807] = "german - switzerland",
     -- [0x0408] = "greek - greece",
     -- [0x046f] = "greenlandic - greenland",
     -- [0x0447] = "gujarati - india",
     -- [0x0468] = "hausa (latin) - nigeria",
     -- [0x040d] = "hebrew - israel",
     -- [0x0439] = "hindi - india",
     -- [0x040e] = "hungarian - hungary",
     -- [0x040f] = "icelandic - iceland",
     -- [0x0470] = "igbo - nigeria",
     -- [0x0421] = "indonesian - indonesia",
     -- [0x045d] = "inuktitut - canada",
     -- [0x085d] = "inuktitut (latin) - canada",
     -- [0x083c] = "irish - ireland",
     -- [0x0434] = "isixhosa - south africa",
     -- [0x0435] = "isizulu - south africa",
     -- [0x0410] = "italian - italy",
     -- [0x0810] = "italian - switzerland",
     -- [0x0411] = "japanese - japan",
     -- [0x044b] = "kannada - india",
     -- [0x043f] = "kazakh - kazakhstan",
     -- [0x0453] = "khmer - cambodia",
     -- [0x0486] = "k'iche - guatemala",
     -- [0x0487] = "kinyarwanda - rwanda",
     -- [0x0441] = "kiswahili - kenya",
     -- [0x0457] = "konkani - india",
     -- [0x0412] = "korean - korea",
     -- [0x0440] = "kyrgyz - kyrgyzstan",
     -- [0x0454] = "lao - lao p.d.r.",
     -- [0x0426] = "latvian - latvia",
     -- [0x0427] = "lithuanian - lithuania",
     -- [0x082e] = "lower sorbian - germany",
     -- [0x046e] = "luxembourgish - luxembourg",
     -- [0x042f] = "macedonian (fyrom) - former yugoslav republic of macedonia",
     -- [0x083e] = "malay - brunei darussalam",
     -- [0x043e] = "malay - malaysia",
     -- [0x044c] = "malayalam - india",
     -- [0x043a] = "maltese - malta",
     -- [0x0481] = "maori - new zealand",
     -- [0x047a] = "mapudungun - chile",
     -- [0x044e] = "marathi - india",
     -- [0x047c] = "mohawk - mohawk",
     -- [0x0450] = "mongolian (cyrillic) - mongolia",
     -- [0x0850] = "mongolian (traditional) - people's republic of china",
     -- [0x0461] = "nepali - nepal",
     -- [0x0414] = "norwegian (bokmal) - norway",
     -- [0x0814] = "norwegian (nynorsk) - norway",
     -- [0x0482] = "occitan - france",
     -- [0x0448] = "odia (formerly oriya) - india",
     -- [0x0463] = "pashto - afghanistan",
     -- [0x0415] = "polish - poland",
     -- [0x0416] = "portuguese - brazil",
     -- [0x0816] = "portuguese - portugal",
     -- [0x0446] = "punjabi - india",
     -- [0x046b] = "quechua - bolivia",
     -- [0x086b] = "quechua - ecuador",
     -- [0x0c6b] = "quechua - peru",
     -- [0x0418] = "romanian - romania",
     -- [0x0417] = "romansh - switzerland",
     -- [0x0419] = "russian - russia",
     -- [0x243b] = "sami (inari) - finland",
     -- [0x103b] = "sami (lule) - norway",
     -- [0x143b] = "sami (lule) - sweden",
     -- [0x0c3b] = "sami (northern) - finland",
     -- [0x043b] = "sami (northern) - norway",
     -- [0x083b] = "sami (northern) - sweden",
     -- [0x203b] = "sami (skolt) - finland",
     -- [0x183b] = "sami (southern) - norway",
     -- [0x1c3b] = "sami (southern) - sweden",
     -- [0x044f] = "sanskrit - india",
     -- [0x1c1a] = "serbian (cyrillic) - bosnia and herzegovina",
     -- [0x0c1a] = "serbian (cyrillic) - serbia",
     -- [0x181a] = "serbian (latin) - bosnia and herzegovina",
     -- [0x081a] = "serbian (latin) - serbia",
     -- [0x046c] = "sesotho sa leboa - south africa",
     -- [0x0432] = "setswana - south africa",
     -- [0x045b] = "sinhala - sri lanka",
     -- [0x041b] = "slovak - slovakia",
     -- [0x0424] = "slovenian - slovenia",
     -- [0x2c0a] = "spanish - argentina",
     -- [0x400a] = "spanish - bolivia",
     -- [0x340a] = "spanish - chile",
     -- [0x240a] = "spanish - colombia",
     -- [0x140a] = "spanish - costa rica",
     -- [0x1c0a] = "spanish - dominican republic",
     -- [0x300a] = "spanish - ecuador",
     -- [0x440a] = "spanish - el salvador",
     -- [0x100a] = "spanish - guatemala",
     -- [0x480a] = "spanish - honduras",
     -- [0x080a] = "spanish - mexico",
     -- [0x4c0a] = "spanish - nicaragua",
     -- [0x180a] = "spanish - panama",
     -- [0x3c0a] = "spanish - paraguay",
     -- [0x280a] = "spanish - peru",
     -- [0x500a] = "spanish - puerto rico",
     -- [0x0c0a] = "spanish (modern sort) - spain",
     -- [0x040a] = "spanish (traditional sort) - spain",
     -- [0x540a] = "spanish - united states",
     -- [0x380a] = "spanish - uruguay",
     -- [0x200a] = "spanish - venezuela",
     -- [0x081d] = "sweden - finland",
     -- [0x041d] = "swedish - sweden",
     -- [0x045a] = "syriac - syria",
     -- [0x0428] = "tajik (cyrillic) - tajikistan",
     -- [0x085f] = "tamazight (latin) - algeria",
     -- [0x0449] = "tamil - india",
     -- [0x0444] = "tatar - russia",
     -- [0x044a] = "telugu - india",
     -- [0x041e] = "thai - thailand",
     -- [0x0451] = "tibetan - prc",
     -- [0x041f] = "turkish - turkey",
     -- [0x0442] = "turkmen - turkmenistan",
     -- [0x0480] = "uighur - prc",
     -- [0x0422] = "ukrainian - ukraine",
     -- [0x042e] = "upper sorbian - germany",
     -- [0x0420] = "urdu - islamic republic of pakistan",
     -- [0x0843] = "uzbek (cyrillic) - uzbekistan",
     -- [0x0443] = "uzbek (latin) - uzbekistan",
     -- [0x042a] = "vietnamese - vietnam",
     -- [0x0452] = "welsh - united kingdom",
     -- [0x0488] = "wolof - senegal",
     -- [0x0485] = "yakut - russia",
     -- [0x0478] = "yi - prc",
     -- [0x046a] = "yoruba - nigeria",
    },
    custom = {
    },
}

local standardromanencoding = { [0] = -- taken from wikipedia
    "notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl",
    "numbersign", "dollar", "percent", "ampersand", "quotesingle", "parenleft",
    "parenright", "asterisk", "plus", "comma", "hyphen", "period", "slash",
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "colon", "semicolon", "less", "equal", "greater", "question", "at",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
    "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "bracketleft",
    "backslash", "bracketright", "asciicircum", "underscore", "grave", "a", "b",
    "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
    "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar",
    "braceright", "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute",
    "Ntilde", "Odieresis", "Udieresis", "aacute", "agrave", "acircumflex",
    "adieresis", "atilde", "aring", "ccedilla", "eacute", "egrave",
    "ecircumflex", "edieresis", "iacute", "igrave", "icircumflex", "idieresis",
    "ntilde", "oacute", "ograve", "ocircumflex", "odieresis", "otilde", "uacute",
    "ugrave", "ucircumflex", "udieresis", "dagger", "degree", "cent", "sterling",
    "section", "bullet", "paragraph", "germandbls", "registered", "copyright",
    "trademark", "acute", "dieresis", "notequal", "AE", "Oslash", "infinity",
    "plusminus", "lessequal", "greaterequal", "yen", "mu", "partialdiff",
    "summation", "product", "pi", "integral", "ordfeminine", "ordmasculine",
    "Omega", "ae", "oslash", "questiondown", "exclamdown", "logicalnot",
    "radical", "florin", "approxequal", "Delta", "guillemotleft",
    "guillemotright", "ellipsis", "nonbreakingspace", "Agrave", "Atilde",
    "Otilde", "OE", "oe", "endash", "emdash", "quotedblleft", "quotedblright",
    "quoteleft", "quoteright", "divide", "lozenge", "ydieresis", "Ydieresis",
    "fraction", "currency", "guilsinglleft", "guilsinglright", "fi", "fl",
    "daggerdbl", "periodcentered", "quotesinglbase", "quotedblbase",
    "perthousand", "Acircumflex", "Ecircumflex", "Aacute", "Edieresis", "Egrave",
    "Iacute", "Icircumflex", "Idieresis", "Igrave", "Oacute", "Ocircumflex",
    "apple", "Ograve", "Uacute", "Ucircumflex", "Ugrave", "dotlessi",
    "circumflex", "tilde", "macron", "breve", "dotaccent", "ring", "cedilla",
    "hungarumlaut", "ogonek", "caron", "Lslash", "lslash", "Scaron", "scaron",
    "Zcaron", "zcaron", "brokenbar", "Eth", "eth", "Yacute", "yacute", "Thorn",
    "thorn", "minus", "multiply", "onesuperior", "twosuperior", "threesuperior",
    "onehalf", "onequarter", "threequarters", "franc", "Gbreve", "gbreve",
    "Idotaccent", "Scedilla", "scedilla", "Cacute", "cacute", "Ccaron", "ccaron",
    "dcroat",
}

local weights = {
    [100] = "thin",
    [200] = "extralight",
    [300] = "light",
    [400] = "normal",
    [500] = "medium",
    [600] = "semibold",
    [700] = "bold",
    [800] = "extrabold",
    [900] = "black",
}

local widths = {
    [1] = "ultracondensed",
    [2] = "extracondensed",
    [3] = "condensed",
    [4] = "semicondensed",
    [5] = "normal",
    [6] = "semiexpanded",
    [7] = "expanded",
    [8] = "extraexpanded",
    [9] = "ultraexpanded",
}

setmetatableindex(weights, function(t,k)
    local r = floor((k + 50) / 100) * 100
    local v = (r > 900 and "black") or rawget(t,r) or "normal"
-- print("weight:",k,r,v)
    return v
end)

setmetatableindex(widths,function(t,k)
-- print("width:",k)
    return "normal"
end)

local panoseweights = {
    [ 0] = "normal",
    [ 1] = "normal",
    [ 2] = "verylight",
    [ 3] = "light",
    [ 4] = "thin",
    [ 5] = "book",
    [ 6] = "medium",
    [ 7] = "demi",
    [ 8] = "bold",
    [ 9] = "heavy",
    [10] = "black",
}

local panosewidths = {
    [ 0] = "normal",
    [ 1] = "normal",
    [ 2] = "normal",
    [ 3] = "normal",
    [ 4] = "normal",
    [ 5] = "expanded",
    [ 6] = "condensed",
    [ 7] = "veryexpanded",
    [ 8] = "verycondensed",
    [ 9] = "monospaced",
}

-- We implement a reader per table.

-- The name table is probably the first one to load. After all this one provides
-- useful information about what we deal with. The complication is that we need
-- to filter the best one available.

function readers.name(f,fontdata)
    local datatable = fontdata.tables.name
    if datatable then
        setposition(f,datatable.offset)
        local format   = readushort(f)
        local nofnames = readushort(f)
        local offset   = readushort(f)
        -- we can also provide a raw list as extra, todo as option
        local namelists = {
            unicode   = { },
            windows   = { },
            macintosh = { },
         -- iso       = { },
         -- windows   = { },
        }
        for i=1,nofnames do
            local platform = platforms[readushort(f)]
            if platform then
                local namelist = namelists[platform]
                if namelist then
                    local encoding  = readushort(f)
                    local language  = readushort(f)
                    local encodings = encodings[platform]
                    local languages = languages[platform]
                    if encodings and languages then
                        local encoding = encodings[encoding]
                        local language = languages[language]
                        if encoding and language then
                            local name = reservednames[readushort(f)]
                            if name then
                                namelist[#namelist+1] = {
                                    platform = platform,
                                    encoding = encoding,
                                    language = language,
                                    name     = name,
                                    length   = readushort(f),
                                    offset   = readushort(f),
                                }
                            else
                                skipshort(f,2)
                            end
                        else
                            skipshort(f,3)
                        end
                    else
                        skipshort(f,3)
                    end
                else
                    skipshort(f,5)
                end
            else
                skipshort(f,5)
            end
        end
     -- if format == 1 then
     --     local noftags = readushort(f)
     --     for i=1,noftags do
     --        local length = readushort(f)
     --        local offset = readushort(f)
     --     end
     -- end
        --
        -- we need to choose one we like, for instance an unicode one
        --
        local start = datatable.offset + offset
        local names = { }
        local done  = { }
        --
        -- there is quite some logic in ff ... hard to follow so we start simple
        -- and extend when we run into it (todo: proper reverse hash) .. we're only
        -- interested in english anyway
        --
        local function filter(platform,e,l)
            local namelist = namelists[platform]
            for i=1,#namelist do
                local name    = namelist[i]
                local nametag = name.name
                if not done[nametag] then
                    local encoding = name.encoding
                    local language = name.language
                    if (not e or encoding == e) and (not l or language == l) then
                        setposition(f,start+name.offset)
                        local content = readstring(f,name.length)
                        local decoder = decoders[platform]
                        if decoder then
                            decoder = decoder[encoding]
                        end
                        if decoder then
                            content = decoder(content)
                        end
                        names[nametag] = {
                            content  = content,
                            platform = platform,
                            encoding = encoding,
                            language = language,
                        }
                        done[nametag] = true
                    end
                end
            end
        end
        --
        filter("windows","unicode bmp","english - united states")
     -- filter("unicode") -- which one ?
        filter("macintosh","roman","english")
        filter("windows")
        filter("macintosh")
        filter("unicode")
        --
        fontdata.names = names
    else
        fontdata.names = { }
    end
end

-- This table is an original windows (with its precursor os/2) table. In ff this one is
-- part of the pfminfo table but here we keep it separate (for now). We will create a
-- properties table afterwards.

readers["os/2"] = function(f,fontdata)
    local datatable = fontdata.tables["os/2"]
    if datatable then
        setposition(f,datatable.offset)
        local version = readushort(f)
        local windowsmetrics = {
            version            = version,
            averagewidth       = readshort(f),
            weightclass        = readushort(f),
            widthclass         = readushort(f),
            fstype             = readushort(f),
            subscriptxsize     = readshort(f),
            subscriptysize     = readshort(f),
            subscriptxoffset   = readshort(f),
            subscriptyoffset   = readshort(f),
            superscriptxsize   = readshort(f),
            superscriptysize   = readshort(f),
            superscriptxoffset = readshort(f),
            superscriptyoffset = readshort(f),
            strikeoutsize      = readshort(f),
            strikeoutpos       = readshort(f),
            familyclass        = readshort(f),
            panose             = { readbytes(f,10) },
            unicoderanges      = { readulong(f), readulong(f), readulong(f), readulong(f) },
            vendor             = readstring(f,4),
            fsselection        = readushort(f),
            firstcharindex     = readushort(f),
            lastcharindex      = readushort(f),
            typoascender       = readshort(f),
            typodescender      = readshort(f),
            typolinegap        = readshort(f),
            winascent          = readushort(f),
            windescent         = readushort(f),
        }
        if version >= 1 then
            windowsmetrics.codepageranges = { readulong(f), readulong(f) }
        end
        if version >= 3 then
            windowsmetrics.xheight               = readshort(f)
            windowsmetrics.capheight             = readshort(f)
            windowsmetrics.defaultchar           = readushort(f)
            windowsmetrics.breakchar             = readushort(f)
         -- windowsmetrics.maxcontexts           = readushort(f)
         -- windowsmetrics.loweropticalpointsize = readushort(f)
         -- windowsmetrics.upperopticalpointsize = readushort(f)
        end
        --
        -- todo: unicoderanges
        --
        windowsmetrics.weight = windowsmetrics.weightclass and weights[windowsmetrics.weightclass]
        windowsmetrics.width  = windowsmetrics.widthclass and  widths [windowsmetrics.widthclass]
        --
        windowsmetrics.panoseweight = panoseweights[windowsmetrics.panose[3]]
        windowsmetrics.panosewidth  = panosewidths [windowsmetrics.panose[4]]
        --
        fontdata.windowsmetrics = windowsmetrics
    else
        fontdata.windowsmetrics = { }
    end
end

readers.head = function(f,fontdata)
    local datatable = fontdata.tables.head
    if datatable then
        setposition(f,datatable.offset)
        local fontheader = {
            version          = readfixed(f),
            revision         = readfixed(f),
            checksum         = readulong(f),
            magic            = readulong(f),
            flags            = readushort(f),
            units            = readushort(f),
            created          = readlongdatetime(f),
            modified         = readlongdatetime(f),
            xmin             = readshort(f),
            ymin             = readshort(f),
            xmax             = readshort(f),
            ymax             = readshort(f),
            macstyle         = readushort(f),
            smallpixels      = readushort(f),
            directionhint    = readshort(f),
            indextolocformat = readshort(f),
            glyphformat      = readshort(f),
        }
        fontdata.fontheader = fontheader
    else
        fontdata.fontheader = { }
    end
    fontdata.nofglyphs  = 0
end

-- This table is a rather simple one. No treatment of values is needed here. Most
-- variables are not used but nofhmetrics is quite important.

readers.hhea = function(f,fontdata,specification)
    if specification.details then
        local datatable = fontdata.tables.hhea
        if datatable then
            setposition(f,datatable.offset)
            fontdata.horizontalheader = {
                version             = readfixed(f),
                ascender            = readfword(f),
                descender           = readfword(f),
                linegap             = readfword(f),
                maxadvancewidth     = readufword(f),
                minleftsidebearing  = readfword(f),
                minrightsidebearing = readfword(f),
                maxextent           = readfword(f),
                caretsloperise      = readshort(f),
                caretsloperun       = readshort(f),
                caretoffset         = readshort(f),
                reserved_1          = readshort(f),
                reserved_2          = readshort(f),
                reserved_3          = readshort(f),
                reserved_4          = readshort(f),
                metricdataformat    = readshort(f),
                nofhmetrics         = readushort(f),
            }
        else
            fontdata.horizontalheader = {
                nofhmetrics = 0,
            }
        end
    end
end

-- We probably never need all these variables, but we do need the nofglyphs when loading other
-- tables. Again we use the microsoft names but see no reason to have "max" in each name.

-- fontdata.maximumprofile can be bad

readers.maxp = function(f,fontdata,specification)
    if specification.details then
        local datatable = fontdata.tables.maxp
        if datatable then
            setposition(f,datatable.offset)
            local version      = readfixed(f)
            local nofglyphs    = readushort(f)
            fontdata.nofglyphs = nofglyphs
            if version == 0.5 then
                fontdata.maximumprofile = {
                    version   = version,
                    nofglyphs = nofglyphs,
                }
                return
            elseif version == 1.0 then
                fontdata.maximumprofile = {
                    version            = version,
                    nofglyphs          = nofglyphs,
                    points             = readushort(f),
                    contours           = readushort(f),
                    compositepoints    = readushort(f),
                    compositecontours  = readushort(f),
                    zones              = readushort(f),
                    twilightpoints     = readushort(f),
                    storage            = readushort(f),
                    functiondefs       = readushort(f),
                    instructiondefs    = readushort(f),
                    stackelements      = readushort(f),
                    sizeofinstructions = readushort(f),
                    componentelements  = readushort(f),
                    componentdepth     = readushort(f),
                }
                return
            end
        end
        fontdata.maximumprofile = {
            version   = version,
            nofglyphs = 0,
        }
    end
end

-- Here we filter the (advance) widths (that can be different from the boundingbox width of
-- course).

readers.hmtx = function(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.hmtx
        if datatable then
            setposition(f,datatable.offset)
            local nofmetrics      = fontdata.horizontalheader.nofhmetrics
            local glyphs          = fontdata.glyphs
            local nofglyphs       = fontdata.nofglyphs
            local nofrepeated     = nofglyphs - nofmetrics
            local width           = 0 -- advance
            local leftsidebearing = 0
            for i=0,nofmetrics-1 do
                local glyph     = glyphs[i]
                width           = readshort(f)
                leftsidebearing = readshort(f)
                if advance ~= 0 then
                    glyph.width = width
                end
             -- if leftsidebearing ~= 0 then
             --     glyph.lsb = leftsidebearing
             -- end
            end
            -- The next can happen in for instance a monospace font or in a cjk font
            -- with fixed widths.
            for i=nofmetrics,nofrepeated do
                local glyph     = glyphs[i]
                if width ~= 0 then
                    glyph.width = width
                end
             -- if leftsidebearing ~= 0 then
             --     glyph.lsb = leftsidebearing
             -- end
            end
        end
    end
end

-- The post table relates to postscript (printing) but has some relevant properties for other
-- usage as well. We just use the names from the microsoft specification. The version 2.0
-- description is somewhat fuzzy but it is a hybrid with overloads.

readers.post = function(f,fontdata,specification)
    local datatable = fontdata.tables.post
    if datatable then
        setposition(f,datatable.offset)
        local version = readfixed(f)
        fontdata.postscript = {
            version            = version,
            italicangle        = round(1000*readfixed(f))/1000,
            underlineposition  = readfword(f),
            underlinethickness = readfword(f),
            monospaced         = readulong(f),
            minmemtype42       = readulong(f),
            maxmemtype42       = readulong(f),
            minmemtype1        = readulong(f),
            maxmemtype1        = readulong(f),
        }
        if not specification.glyphs then
            -- enough done
        elseif version == 1.0 then
            -- mac encoding (258 glyphs)
            for index=0,#standardromanencoding do
                glyphs[index].name = standardromanencoding[index]
            end
        elseif version == 2.0 then
            local glyphs    = fontdata.glyphs
            local nofglyphs = readushort(f)
            local indices   = { }
            local names     = { }
            local maxnames  = 0
            for i=0,nofglyphs-1 do
                local nameindex = readushort(f)
                if nameindex >= 258 then
                    maxnames = maxnames + 1
                    nameindex = nameindex - 257
                    indices[nameindex] = i
                else
                    glyphs[i].name = standardromanencoding[nameindex]
                end
            end
            for i=1,maxnames do
                local mapping = indices[i]
                if not mapping then
                    report("quit post name fetching at %a of %a: %s",i,maxnames,"no index")
                    break
                else
                    local length  = readbyte(f)
                    if length > 0 then
                        glyphs[mapping].name = readstring(f,length)
                    else
                        report("quit post name fetching at %a of %a: %s",i,maxnames,"overflow")
                        break
                    end
                end
            end
        elseif version == 2.5 then
            -- depricated, will be done when needed
        elseif version == 3.0 then
            -- no ps name information
        end
    else
        fontdata.postscript = { }
    end
end

readers.cff = function(f,fontdata,specification)
    if specification.glyphs then
        reportskippedtable("cff")
    end
end

-- Not all cmaps make sense .. e.g. dfont is obsolete and probably more are not relevant. Let's see
-- what we run into. There is some weird calculation going on here because we offset in a table
-- being a blob of memory or file. Anyway, I can't stand lunatic formats like this esp when there
-- is no real gain.

local formatreaders = { }
local duplicatestoo = true

formatreaders[4] = function(f,fontdata,offset)
    setposition(f,offset+2) -- skip format
    --
    local length      = readushort(f) -- in bytes of subtable
    local language    = readushort(f)
    local nofsegments = readushort(f) / 2
    --
    skipshort(f,3) -- searchrange entryselector rangeshift
    --
    local endchars   = { }
    local startchars = { }
    local deltas     = { }
    local offsets    = { }
    local indices    = { }
    local mapping    = fontdata.mapping
    local glyphs     = fontdata.glyphs
    local duplicates = fontdata.duplicates
    --
    for i=1,nofsegments do
        endchars[i] = readushort(f)
    end
    local reserved = readushort(f) -- 0
    for i=1,nofsegments do
        startchars[i] = readushort(f)
    end
    for i=1,nofsegments do
        deltas[i] = readshort(f)
    end
    for i=1,nofsegments do
        offsets[i] = readushort(f)
    end
    -- format length language nofsegments searchrange entryselector rangeshift 4-tables
    local size = (length - 2 * 2 - 5 * 2 - 4 * nofsegments * 2) / 2
    for i=1,size-1 do
        indices[i] = readushort(f)
    end
    --
    for segment=1,nofsegments do
        local startchar = startchars[segment]
        local endchar   = endchars[segment]
        local offset    = offsets[segment]
        local delta     = deltas[segment]
        if startchar == 0xFFFF and endchar == 0xFFFF then
            break
        elseif offset == 0 then
            if trace_cmap then
                report("format 4.%i from %C to %C at index %H",1,startchar,endchar,mod(startchar + delta,65536))
            end
            for unicode=startchar,endchar do
                index = mod(unicode + delta,65536)
                if index and index > 0 then
                    local glyph = glyphs[index]
                    if glyph then
                        local gu = glyph.unicode
                        if not gu then
                            glyph.unicode = unicode
                        elseif gu ~= unicode then
                            if duplicatestoo then
                                local d = duplicates[gu]
                                if d then
                                    d[unicode] = true
                                else
                                    duplicates[gu] = { [unicode] = true }
                                end
                            else
                                -- no duplicates ... weird side effects in lm
                                report("duplicate case 1: %C %04i %s",unicode,index,glyphs[index].name)
                            end
                        end
                        if not mapping[index] then
                            mapping[index] = unicode
                        end
                    end
                end
            end
        else
            local shift = (segment-nofsegments+offset/2) - startchar
            if trace_cmap then
                report("format 4.%i from %C to %C at index %H",2,startchar,endchar,mod(indices[shift+startchar]+delta,65536))
            end
            for unicode=startchar,endchar do
                local slot  = shift + unicode
                local index = indices[slot]
                if index and index > 0 then
                    index = mod(index + delta,65536)
                    local glyph = glyphs[index]
                    if glyph then
                        local gu = glyph.unicode
                        if not gu then
                            glyph.unicode = unicode
                        elseif gu ~= unicode then
                            if duplicatestoo then
                                local d = duplicates[gu]
                                if d then
                                    d[unicode] = true
                                else
                                    duplicates[gu] = { [unicode] = true }
                                end
                            else
                                -- no duplicates ... weird side effects in lm
                                report("duplicate case 2: %C %04i %s",unicode,index,glyphs[index].name)
                            end
                        end
                        if not mapping[index] then
                            mapping[index] = unicode
                        end
                    end
                end
            end
        end
    end

end

formatreaders[6] = function(f,fontdata,offset)
    setposition(f,offset) -- + 2 + 2 + 2 -- skip format length language
    local format     = readushort(f)
    local length     = readushort(f)
    local language   = readushort(f)
    local mapping    = fontdata.mapping
    local glyphs     = fontdata.glyphs
    local duplicates = fontdata.duplicates
    local start      = readushort(f)
    local count      = readushort(f)
    local stop       = start+count-1
    if trace_cmap then
        report("format 6 from %C to %C",2,start,stop)
    end
    for unicode=start,stop do
        local index = readushort(f)
        if index > 0 then
            local glyph = glyphs[index]
            if glyph then
                local gu = glyph.unicode
                if not gu then
                    glyph.unicode = unicode
                elseif gu ~= unicode then
                    -- report("format 6 overloading %C to %C",gu,unicode)
                    -- glyph.unicode = unicode
                    -- no duplicates ... weird side effects in lm
                end
                if not mapping[index] then
                    mapping[index] = unicode
                end
            end
        end
    end
end

formatreaders[12] = function(f,fontdata,offset)
    setposition(f,offset+2+2+4+4) -- skip format reserved length language
    local mapping    = fontdata.mapping
    local glyphs     = fontdata.glyphs
    local duplicates = fontdata.duplicates
    local nofgroups  = readulong(f)
    for i=1,nofgroups do
        local first = readulong(f)
        local last  = readulong(f)
        local index = readulong(f)
        if trace_cmap then
            report("format 12 from %C to %C",first,last)
        end
        for unicode=first,last do
            local glyph = glyphs[index]
            if glyph then
                local gu = glyph.unicode
                if not gu then
                    glyph.unicode = unicode
                elseif gu ~= unicode then
                    -- e.g. sourcehan fonts need this
                    local d = duplicates[gu]
                    if d then
                        d[unicode] = true
                    else
                        duplicates[gu] = { [unicode] = true }
                    end
                end
                if not mapping[index] then
                    mapping[index] = unicode
                end
            end
            index = index + 1
         end
    end
end

formatreaders[14] = function(f,fontdata,offset)
    if offset and offset ~= 0 then
        setposition(f,offset)
        local format      = readushort(f)
        local length      = readulong(f)
        local nofrecords  = readulong(f)
        local records     = { }
        local variants    = { }
        fontdata.variants = variants
        for i=1,nofrecords do
            records[i] = {
                selector = readuint(f),
                default  = readulong(f), -- default offset
                other    = readulong(f), -- non-default offset
            }
        end
        for i=1,nofrecords do
            local record   = records[i]
            local selector = record.selector
            local default  = record.default
            local other    = record.other
            --
            -- there is no need to map the defaults to themselves
            --
         -- if default ~= 0 then
         --     setposition(f,offset+default)
         --     local nofranges = readulong(f)
         --     for i=1,nofranges do
         --         local start = readuint(f)
         --         local extra = readbyte(f)
         --         for i=start,start+extra do
         --             mapping[i] = i
         --         end
         --     end
         -- end
            local other = record.other
            if other ~= 0 then
                setposition(f,offset+other)
                local mapping = { }
                local count   = readulong(f)
                for i=1,count do
                    mapping[readuint(f)] = readushort(f)
                end
                variants[selector] = mapping
            end
        end
    end
end

local function checkcmap(f,fontdata,records,platform,encoding,format)
    local data = records[platform]
    if not data then
        return
    end
    data = data[encoding]
    if not data then
        return
    end
    data = data[format]
    if not data then
        return
    end
    local reader = formatreaders[format]
    if not reader then
        return
    end
    report("checking cmap: platform %a, encoding %a, format %a",platform,encoding,format)
    reader(f,fontdata,data)
    return true
end

function readers.cmap(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.cmap
        if datatable then
            local tableoffset = datatable.offset
            setposition(f,tableoffset)
            local version      = readushort(f)
            local noftables    = readushort(f)
            local records      = { }
            local unicodecid   = false
            local variantcid   = false
            local variants     = { }
            local duplicates   = fontdata.duplicates or { }
            fontdata.duplicates = duplicates
            for i=1,noftables do
                local platform = readushort(f)
                local encoding = readushort(f)
                local offset   = readulong(f)
                local record   = records[platform]
                if not record then
                    records[platform] = {
                        [encoding] = {
                            offsets = { offset },
                            formats = { },
                        }
                    }
                else
                    local subtables = record[encoding]
                    if not subtables then
                        record[encoding] = {
                            offsets = { offset },
                            formats = { },
                        }
                    else
                        local offsets = subtables.offsets
                        offsets[#offsets+1] = offset
                    end
                end
            end
            for platform, record in next, records do
                for encoding, subtables in next, record do
                    local offsets = subtables.offsets
                    local formats = subtables.formats
                    for i=1,#offsets do
                        local offset = tableoffset + offsets[i]
                        setposition(f,offset)
                        formats[readushort(f)] = offset
                    end
                    record[encoding] = formats
                end
            end
            --
            local ok = false
            ok = checkcmap(f,fontdata,records,3, 1, 4) or ok
            ok = checkcmap(f,fontdata,records,3,10,12) or ok
            ok = checkcmap(f,fontdata,records,0, 3, 4) or ok
            ok = checkcmap(f,fontdata,records,0, 1, 4) or ok
            ok = checkcmap(f,fontdata,records,0, 0, 6) or ok
            ok = checkcmap(f,fontdata,records,3, 0, 6) or ok
         -- ok = checkcmap(f,fontdata,records,3, 0, 4) or ok -- maybe
            -- 1 0 0
            if not ok then
                local list = { }
                for k1, v1 in next, records do
                    for k2, v2 in next, v1 do
                        for k3, v3 in next, v2 do
                            list[#list+1] = formatters["%s.%s.%s"](k1,k2,k3)
                        end
                    end
                end
                table.sort(list)
                report("no unicode cmap record loaded, found tables: % t",list)
            end
            checkcmap(f,fontdata,records,0,5,14) -- variants
            --
            fontdata.cidmaps = {
                version   = version,
                noftables = noftables,
                records   = records,
            }
        else
            fontdata.cidmaps = { }
        end
    end
end

-- The glyf table depends on the loca table. We have one entry to much in the locations table (the
-- last one is a dummy) because we need to calculate the size of a glyph blob from the delta,
-- although we not need it in our usage (yet). We can remove the locations table when we're done.

function readers.loca(f,fontdata,specification)
    if specification.glyphs then
        reportskippedtable("loca")
    end
end

function readers.glyf(f,fontdata,specification) -- part goes to cff module
    if specification.glyphs then
        reportskippedtable("glyf")
    end
end

-- Here we have a table that we really need for later processing although a more advanced gpos table
-- can also be available. Todo: we need a 'fake' lookup for this (analogue to ff).

function readers.kern(f,fontdata,specification)
    if specification.kerns then
        local datatable = fontdata.tables.kern
        if datatable then
            setposition(f,datatable.offset)
            local version   = readushort(f)
            local noftables = readushort(f)
            for i=1,noftables do
                local version  = readushort(f)
                local length   = readushort(f)
                local coverage = readushort(f)
                -- bit 8-15 of coverage: format 0 or 2
                local format   = bit32.rshift(coverage,8) -- is this ok?
                if format == 0 then
                    local nofpairs      = readushort(f)
                    local searchrange   = readushort(f)
                    local entryselector = readushort(f)
                    local rangeshift    = readushort(f)
                    local kerns  = { }
                    local glyphs = fontdata.glyphs
                    for i=1,nofpairs do
                        local left  = readushort(f)
                        local right = readushort(f)
                        local kern  = readfword(f)
                        local glyph = glyphs[left]
                        local kerns = glyph.kerns
                        if kerns then
                            kerns[right] = kern
                        else
                            glyph.kerns = { [right] = kern }
                        end
                    end
                elseif format == 2 then
                    report("todo: kern classes")
                else
                    report("todo: kerns")
                end
            end
        end
    end
end

function readers.gdef(f,fontdata,specification)
    if specification.details then
        reportskippedtable("gdef")
    end
end

function readers.gsub(f,fontdata,specification)
    if specification.details then
        reportskippedtable("gsub")
    end
end

function readers.gpos(f,fontdata,specification)
    if specification.details then
        reportskippedtable("gpos")
    end
end

function readers.math(f,fontdata,specification)
    if specification.glyphs then
        reportskippedtable("math")
    end
end

-- Goodie. A sequence instead of segments costs a bit more memory, some 300K on a
-- dejavu serif and about the same on a pagella regular.

local function packoutlines(data,makesequence)
    local subfonts = data.subfonts
    if subfonts then
        for i=1,#subfonts do
            packoutlines(subfonts[i],makesequence)
        end
        return
    end
    local common = data.segments
    if common then
        return
    end
    local glyphs = data.glyphs
    if not glyphs then
        return
    end
    if makesequence then
        for index=1,#glyphs do
            local glyph = glyphs[index]
            local segments = glyph.segments
            if segments then
                local sequence    = { }
                local nofsequence = 0
                for i=1,#segments do
                    local segment    = segments[i]
                    local nofsegment = #segment
                    nofsequence = nofsequence + 1
                    sequence[nofsequence] = segment[nofsegment]
                    for i=1,nofsegment-1 do
                        nofsequence = nofsequence + 1
                        sequence[nofsequence] = segment[i]
                    end
                end
                glyph.sequence = sequence
                glyph.segments = nil
            end
        end
    else
        local hash    = { }
        local common  = { }
        local reverse = { }
        local last    = 0
        for index=1,#glyphs do
            local segments = glyphs[index].segments
            if segments then
                for i=1,#segments do
                    local h = concat(segments[i]," ")
                    hash[h] = (hash[h] or 0) + 1
                end
            end
        end
        for index=1,#glyphs do
            local segments = glyphs[index].segments
            if segments then
                for i=1,#segments do
                    local segment = segments[i]
                    local h = concat(segment," ")
                    if hash[h] > 1 then -- minimal one shared in order to hash
                        local idx = reverse[h]
                        if not idx then
                            last = last + 1
                            reverse[h] = last
                            common[last] = segment
                            idx = last
                        end
                        segments[i] = idx
                    end
                end
            end
        end
        if last > 0 then
            data.segments = common
        end
    end
end

local function unpackoutlines(data)
    local subfonts = data.subfonts
    if subfonts then
        for i=1,#subfonts do
            unpackoutlines(subfonts[i])
        end
        return
    end
    local common = data.segments
    if not common then
        return
    end
    local glyphs = data.glyphs
    if not glyphs then
        return
    end
    for index=1,#glyphs do
        local segments = glyphs[index].segments
        if segments then
            for i=1,#segments do
                local c = common[segments[i]]
                if c then
                    segments[i] = c
                end
            end
        end
    end
    data.segments = nil
end

otf.packoutlines   = packoutlines
otf.unpackoutlines = unpackoutlines

-- Now comes the loader. The order of reading these matters as we need to know
-- some properties in order to read following tables. When details is true we also
-- initialize the glyphs data.

----- validutf = lpeg.patterns.utf8character^0 * P(-1)
local validutf = lpeg.patterns.validutf8

local function getname(fontdata,key)
    local names = fontdata.names
    if names then
        local value = names[key]
        if value then
            local content = value.content
            return lpegmatch(validutf,content) and content or nil
        end
    end
end

local function getinfo(maindata,sub)
    local fontdata = sub and maindata.subfonts and maindata.subfonts[sub] or maindata
    local names = fontdata.names
    if names then
        local metrics    = fontdata.windowsmetrics or { }
        local postscript = fontdata.postscript or { }
        local fontheader = fontdata.fontheader or { }
        local cffinfo    = fontdata.cffinfo or { }
        local filename   = fontdata.filename
        local weight     = getname(fontdata,"weight") or cffinfo.weight or metrics.weight
        local width      = getname(fontdata,"width")  or cffinfo.width  or metrics.width
        return { -- we inherit some inconsistencies/choices from ff
            subfontindex = fontdata.subfontindex or sub or 0,
         -- filename     = filename,
         -- version      = name("version"),
         -- format       = fontdata.format,
            fontname     = getname(fontdata,"postscriptname"),
            fullname     = getname(fontdata,"fullname"), -- or file.nameonly(filename)
            familyname   = getname(fontdata,"typographicfamily") or getname(fontdata,"family"),
            subfamily    = getname(fontdata,"subfamily"),
            modifiers    = getname(fontdata,"typographicsubfamily"),
            weight       = weight and lower(weight),
            width        = width and lower(width),
            pfmweight    = metrics.weightclass or 400, -- will become weightclass
            pfmwidth     = metrics.widthclass or 5,    -- will become widthclass
            panosewidth  = metrics.panosewidth,
            panoseweight = metrics.panoseweight,
            italicangle  = postscript.italicangle or 0,
            units        = fontheader.units or 0,
            designsize   = fontdata.designsize,
            minsize      = fontdata.minsize,
            maxsize      = fontdata.maxsize,
            monospaced   = (tonumber(postscript.monospaced or 0) > 0) or metrics.panosewidth == "monospaced",
            averagewidth = metrics.averagewidth,
            xheight      = metrics.xheight,
            ascender     = metrics.typoascender,
            descender    = metrics.typodescender,
        }
    elseif n then
        return {
            filename = fontdata.filename,
            comment  = "there is no info for subfont " .. n,
        }
    else
        return {
            filename = fontdata.filename,
            comment  = "there is no info",
        }
    end
end

local function loadtables(f,specification,offset)
    if offset then
        setposition(f,offset)
    end
    local tables   = { }
    local basename = file.basename(specification.filename)
    local filesize = specification.filesize
    local filetime = specification.filetime
    local fontdata = { -- some can/will go
        filename      = basename,
        filesize      = filesize,
        filetime      = filetime,
        version       = readstring(f,4),
        noftables     = readushort(f),
        searchrange   = readushort(f), -- not needed
        entryselector = readushort(f), -- not needed
        rangeshift    = readushort(f), -- not needed
        tables        = tables,
    }
    for i=1,fontdata.noftables do
        local tag      = lower(stripstring(readstring(f,4)))
        local checksum = readulong(f) -- not used
        local offset   = readulong(f)
        local length   = readulong(f)
        if offset + length > filesize then
            report("bad %a table in file %a",tag,basename)
        end
        tables[tag] = {
            checksum = checksum,
            offset   = offset,
            length   = length,
        }
    end
    if tables.cff then
        fontdata.format = "opentype"
    else
        fontdata.format = "truetype"
    end
    return fontdata
end

local function prepareglyps(fontdata)
    local glyphs = setmetatableindex(function(t,k)
        local v = {
            -- maybe more defaults
            index = k,
        }
        t[k] = v
        return v
    end)
    fontdata.glyphs  = glyphs
    fontdata.mapping = { }
end

local function readdata(f,offset,specification)
    local fontdata = loadtables(f,specification,offset)
    if specification.glyphs then
        prepareglyps(fontdata)
    end
    --
    readers["name"](f,fontdata,specification)
    --
    local askedname = specification.askedname
    if askedname then
        local fullname  = getname(fontdata,"fullname") or ""
        local cleanname = gsub(askedname,"[^a-zA-Z0-9]","")
        local foundname = gsub(fullname,"[^a-zA-Z0-9]","")
        if lower(cleanname) ~= lower(foundname) then
            return -- keep searching
        end
    end
    --
    readers["os/2"](f,fontdata,specification)
    readers["head"](f,fontdata,specification)
    readers["maxp"](f,fontdata,specification)
    readers["hhea"](f,fontdata,specification)
    readers["hmtx"](f,fontdata,specification)
    readers["post"](f,fontdata,specification)
    readers["cff" ](f,fontdata,specification)
    readers["cmap"](f,fontdata,specification)
    readers["loca"](f,fontdata,specification)
    readers["glyf"](f,fontdata,specification)
    readers["kern"](f,fontdata,specification)
    readers["gdef"](f,fontdata,specification)
    readers["gsub"](f,fontdata,specification)
    readers["gpos"](f,fontdata,specification)
    readers["math"](f,fontdata,specification)
    --
    fontdata.locations    = nil
    fontdata.tables       = nil
    fontdata.cidmaps      = nil
    fontdata.dictionaries = nil
    -- fontdata.cff = nil
    return fontdata
end

local function loadfontdata(specification)
    local filename = specification.filename
    local fileattr = lfs.attributes(filename)
    local filesize = fileattr and fileattr.size or 0
    local filetime = fileattr and fileattr.modification or 0
    local f = openfile(filename,true) -- zero based
    if not f then
        report("unable to open %a",filename)
    elseif filesize == 0 then
        report("empty file %a",filename)
        closefile(f)
    else
        specification.filesize = filesize
        specification.filetime = filetime
        local version  = readstring(f,4)
        local fontdata = nil
        if version == "OTTO" or version == "true" or version == "\0\1\0\0" then
            fontdata = readdata(f,0,specification)
        elseif version == "ttcf" then
            local subfont     = tonumber(specification.subfont)
            local offsets     = { }
            local ttcversion  = readulong(f)
            local nofsubfonts = readulong(f)
            for i=1,nofsubfonts do
                offsets[i] = readulong(f)
            end
            if subfont then -- a number of not
                if subfont >= 1 and subfont <= nofsubfonts then
                    fontdata = readdata(f,offsets[subfont],specification)
                else
                    report("no subfont %a in file %a",subfont,filename)
                end
            else
                subfont = specification.subfont
                if type(subfont) == "string" and subfont ~= "" then
                    specification.askedname = subfont
                    for i=1,nofsubfonts do
                        fontdata = readdata(f,offsets[i],specification)
                        if fontdata then
                            fontdata.subfontindex = i
                            report("subfont named %a has index %a",subfont,i)
                            break
                        end
                    end
                    if not fontdata then
                        report("no subfont named %a",subfont)
                    end
                else
                    local subfonts = { }
                    fontdata = {
                        filename    = filename,
                        filesize    = filesize,
                        filetime    = filetime,
                        version     = version,
                        subfonts    = subfonts,
                        ttcversion  = ttcversion,
                        nofsubfonts = nofsubfonts,
                    }
                    for i=1,fontdata.nofsubfonts do
                        subfonts[i] = readdata(f,offsets[i],specification)
                    end
                end
            end
        else
            report("unknown version %a in file %a",version,filename)
        end
        closefile(f)
        return fontdata or { }
    end
end

local function loadfont(specification,n)
    if type(specification) == "string" then
        specification = {
            filename    = specification,
            info        = true, -- always true (for now)
            details     = true,
            glyphs      = true,
            shapes      = true,
            kerns       = true,
            globalkerns = true,
            lookups     = true,
            -- true or number:
            subfont     = n or true,
            tounicode   = false,
        }
    end
    -- if shapes only then
    if specification.shapes or specification.lookups or specification.kerns then
        specification.glyphs = true
    end
    if specification.glyphs then
        specification.details = true
    end
    if specification.details then
        specification.info = true
    end
    local function message(str)
        report("fatal error in file %a: %s\n%s",specification.filename,str,debug.traceback())
    end
    local ok, result = xpcall(loadfontdata,message,specification)
    if ok then
        return result
    end
end

-- we need even less, but we can have a 'detail' variant

function readers.loadshapes(filename,n)
    local fontdata = loadfont {
        filename = filename,
        shapes   = true,
        subfont  = n,
    }
    return fontdata and {
     -- version  = 0.123 -- todo
        filename = filename,
        format   = fontdata.format,
        glyphs   = fontdata.glyphs,
        units    = fontdata.fontheader.units,
    } or {
        filename = filename,
        format   = "unknown",
        glyphs   = { },
        units    = 0,
    }
end

function readers.loadfont(filename,n)
    local fontdata = loadfont {
        filename    = filename,
        glyphs      = true,
        shapes      = false,
        lookups     = true,
     -- kerns       = true,
     -- globalkerns = true, -- only for testing, e.g. cambria has different gpos and kern
        subfont     = n,
    }
    if fontdata then
        --
        return {
            tableversion  = tableversion,
            creator       = "context mkiv",
            size          = fontdata.filesize,
            time          = fontdata.filetime,
            glyphs        = fontdata.glyphs,
            descriptions  = fontdata.descriptions,
            format        = fontdata.format,
            goodies       = { },
            metadata      = getinfo(fontdata,n),
            properties    = {
                hasitalics = fontdata.hasitalics or false,
            },
            resources     = {
             -- filename      = fontdata.filename,
                filename      = filename,
                private       = privateoffset,
                duplicates    = fontdata.duplicates  or { },
                features      = fontdata.features    or { }, -- we need to add these in the loader
                sublookups    = fontdata.sublookups  or { }, -- we need to add these in the loader
                marks         = fontdata.marks       or { }, -- we need to add these in the loader
                markclasses   = fontdata.markclasses or { }, -- we need to add these in the loader
                marksets      = fontdata.marksets    or { }, -- we need to add these in the loader
                sequences     = fontdata.sequences   or { }, -- we need to add these in the loader
                variants      = fontdata.variants, -- variant -> unicode -> glyph
                version       = getname(fontdata,"version"),
                cidinfo       = fontdata.cidinfo,
                mathconstants = fontdata.mathconstants,
            },
        }
    end
end

function readers.getinfo(filename,n,details)
    local fontdata = loadfont {
        filename = filename,
        details  = true,
    }
    if fontdata then
        local subfonts = fontdata.subfonts
        if not subfonts then
            return getinfo(fontdata)
        elseif type(n) ~= "number" then
            local info = { }
            for i=1,#subfonts do
                info[i] = getinfo(fontdata,i)
            end
            return info
        elseif n > 1 and n <= subfonts then
            return getinfo(fontdata,n)
        else
            return {
                filename = filename,
                comment  = "there is no subfont " .. n .. " in this file"
            }
        end
    else
        return {
            filename = filename,
            comment  = "the file cannot be opened for reading",
        }
    end
end

function readers.rehash(fontdata,hashmethod)
    report("the %a helper is not yet implemented","rehash")
end

function readers.checkhash(fontdata)
    report("the %a helper is not yet implemented","checkhash")
end

function readers.pack(fontdata,hashmethod)
    report("the %a helper is not yet implemented","pack")
end

function readers.unpack(fontdata)
    report("the %a helper is not yet implemented","unpack")
end

function readers.expand(fontdata)
    report("the %a helper is not yet implemented","unpack")
end

function readers.compact(fontdata)
    report("the %a helper is not yet implemented","compact")
end

--

if fonts.hashes then

    local identifiers = fonts.hashes.identifiers
    local loadshapes  = readers.loadshapes

    readers.version  = 0.006
    readers.cache    = containers.define("fonts", "shapes", readers.version, true)

    -- todo: loaders per format

    local function load(filename,sub)
        local base = file.basename(filename)
        local name = file.removesuffix(base)
        local kind = file.suffix(filename)
        local attr = lfs.attributes(filename)
        local size = attr and attr.size or 0
        local time = attr and attr.modification or 0
        local sub  = tonumber(sub)
        if size > 0 and (kind == "otf" or kind == "ttf" or kind == "tcc") then
            local hash = containers.cleanname(base) -- including suffix
            if sub then
                hash = hash .. "-" .. sub
            end
            data = containers.read(readers.cache,hash)
            if not data or data.time ~= time or data.size  ~= size then
                data = loadshapes(filename,sub)
                if data then
                    data.size   = size
                    data.format = data.format or (kind == "otf" and "opentype") or "truetype"
                    data.time   = time
                    packoutlines(data)
                    containers.write(readers.cache,hash,data)
                    data = containers.read(readers.cache,hash) -- frees old mem
                end
            end
            unpackoutlines(data)
        else
            data = {
                filename = filename,
                size     = 0,
                time     = time,
                format   = "unknown",
                units    = 1000,
                glyphs   = { }
            }
        end
        return data
    end

    fonts.hashes.shapes = table.setmetatableindex(function(t,k)
        local d = identifiers[k]
        local v = load(d.properties.filename,d.subindex)
        t[k] = v
        return v
    end)

end