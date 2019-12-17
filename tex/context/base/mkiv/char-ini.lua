if not modules then modules = { } end modules ['char-ini'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: make two files, one for format generation, one for format use
-- todo: move some to char-utf

-- we can remove the tag range starting at 0xE0000 (special applications)

local utfchar, utfbyte, utfvalues, ustring, utotable = utf.char, utf.byte, utf.values, utf.ustring, utf.totable
local concat, unpack, tohash, insert = table.concat, table.unpack, table.tohash, table.insert
local next, tonumber, type, rawget, rawset = next, tonumber, type, rawget, rawset
local format, lower, gsub, find = string.format, string.lower, string.gsub, string.find
local P, R, S, C, Cs, Ct, Cc, V = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.V
local formatters = string.formatters

if not characters then require("char-def") end

local lpegpatterns          = lpeg.patterns
local lpegmatch             = lpeg.match
local utf8byte              = lpegpatterns.utf8byte
local utf8character         = lpegpatterns.utf8character

local utfchartabletopattern = lpeg.utfchartabletopattern

local allocate              = utilities.storage.allocate
local mark                  = utilities.storage.mark

local setmetatableindex     = table.setmetatableindex

local trace_defining        = false  trackers.register("characters.defining", function(v) characters_defining = v end)

local report_defining       = logs.reporter("characters")

--[[ldx--
<p>This module implements some methods and creates additional datastructured
from the big character table that we use for all kind of purposes:
<type>char-def.lua</type>.</p>

<p>We assume that at this point <type>characters.data</type> is already
loaded!</p>
--ldx]]--

-- todo: in 'char-def.lua' assume defaults:
--
-- directtions = l
-- cjkwd       = a
-- linebreak   = al

characters       = characters or { }
local characters = characters
local data       = characters.data

if data then
    mark(data) -- why does this fail
else
    report_defining("fatal error: 'char-def.lua' is not loaded")
    os.exit()
end

--[[ldx--
Extending the table.
--ldx]]--

if context and not characters.private then

    require("char-prv")

    for unicode, d in next, characters.private do
        data[unicode] = d
    end

end

--[[ldx--
<p>This converts a string (if given) into a number.</p>
--ldx]]--

local pattern = (P("0x") + P("U+")) * ((R("09","AF")^1 * P(-1)) / function(s) return tonumber(s,16) end)

lpegpatterns.chartonumber = pattern

local function chartonumber(k)
    if type(k) == "string" then
        local u = lpegmatch(pattern,k)
        if u then
            return utfbyte(u)
        else
            return utfbyte(k) or 0
        end
    else
        return k or 0
    end
end

local function charfromnumber(k)
    if type(k) == "number" then
        return utfchar(k) or ""
    else
        local u = lpegmatch(pattern,k)
        if u then
            return utfchar(u)
        else
            return k
        end
    end
end

--~ print(chartonumber(97), chartonumber("a"), chartonumber("0x61"), chartonumber("U+61"))

characters.tonumber   = chartonumber
characters.fromnumber = charfromnumber

local private = {
    description = "PRIVATE SLOT",
}

local ranges      = allocate()
characters.ranges = ranges

setmetatableindex(data, function(t,k)
    local tk = type(k)
    if tk == "string" then
        k = lpegmatch(pattern,k) or utfbyte(k)
        if k then
            local v = rawget(t,k)
            if v then
                return v
            else
                tk = "number" -- fall through to range
            end
        else
            return private
        end
    end
    if tk == "number" and k < 0xF0000 then
        for r=1,#ranges do
            local rr = ranges[r]
            if k >= rr.first and k <= rr.last then
                local extender = rr.extender
                if extender then
                    local v = extender(k)
                    t[k] = v
                    return v
                end
            end
        end
    end
    return private -- handy for when we loop over characters in fonts and check for a property
end)

local variant_selector_metatable = {
    category  = "mn",
    cjkwd     = "a",
    direction = "nsm",
    linebreak = "cm",
}

-- This saves a bit of memory and also serves as example.

local f_variant = string.formatters["VARIATION SELECTOR-0x%04X"]

insert(characters.ranges,{
    first    = 0xFE00,
    last     = 0xFE0F,
    name     = "variant selector",
    extender = function(k)
        local t = {
            description = f_variant(k - 0xFE00 + 0x0001),
            unicodeslot = k,
        }
        setmetatable(t,variant_selector_metatable)
        return t
    end,
})

insert(characters.ranges,{
    first    = 0xE0100,
    last     = 0xE01EF,
    name     = "variant selector extension",
    extender = function(k)
        local t = {
            description = f_variant(k - 0xE0100 + 0x0011),
            unicodeslot = k,
        }
        setmetatable(t,variant_selector_metatable)
        return t
    end,
})


local blocks = allocate {
    ["adlam"]                                      = { first = 0x1E900, last = 0x1E95F,             description = "Adlam" },
    ["aegeannumbers"]                              = { first = 0x10100, last = 0x1013F,             description = "Aegean Numbers" },
    ["ahom"]                                       = { first = 0x11700, last = 0x1173F,             description = "Ahom" },
    ["alchemicalsymbols"]                          = { first = 0x1F700, last = 0x1F77F,             description = "Alchemical Symbols" },
    ["alphabeticpresentationforms"]                = { first = 0x0FB00, last = 0x0FB4F, otf="latn", description = "Alphabetic Presentation Forms" },
    ["anatolianhieroglyphs"]                       = { first = 0x14400, last = 0x1467F,             description = "Anatolian Hieroglyphs" },
    ["ancientgreekmusicalnotation"]                = { first = 0x1D200, last = 0x1D24F, otf="grek", description = "Ancient Greek Musical Notation" },
    ["ancientgreeknumbers"]                        = { first = 0x10140, last = 0x1018F, otf="grek", description = "Ancient Greek Numbers" },
    ["ancientsymbols"]                             = { first = 0x10190, last = 0x101CF, otf="grek", description = "Ancient Symbols" },
    ["arabic"]                                     = { first = 0x00600, last = 0x006FF, otf="arab", description = "Arabic" },
    ["arabicextendeda"]                            = { first = 0x008A0, last = 0x008FF,             description = "Arabic Extended-A" },
    ["arabicmathematicalalphabeticsymbols"]        = { first = 0x1EE00, last = 0x1EEFF,             description = "Arabic Mathematical Alphabetic Symbols" },
    ["arabicpresentationformsa"]                   = { first = 0x0FB50, last = 0x0FDFF, otf="arab", description = "Arabic Presentation Forms-A" },
    ["arabicpresentationformsb"]                   = { first = 0x0FE70, last = 0x0FEFF, otf="arab", description = "Arabic Presentation Forms-B" },
    ["arabicsupplement"]                           = { first = 0x00750, last = 0x0077F, otf="arab", description = "Arabic Supplement" },
    ["armenian"]                                   = { first = 0x00530, last = 0x0058F, otf="armn", description = "Armenian" },
    ["arrows"]                                     = { first = 0x02190, last = 0x021FF,             description = "Arrows" },
    ["avestan"]                                    = { first = 0x10B00, last = 0x10B3F,             description = "Avestan" },
    ["balinese"]                                   = { first = 0x01B00, last = 0x01B7F, otf="bali", description = "Balinese" },
    ["bamum"]                                      = { first = 0x0A6A0, last = 0x0A6FF,             description = "Bamum" },
    ["bamumsupplement"]                            = { first = 0x16800, last = 0x16A3F,             description = "Bamum Supplement" },
    ["basiclatin"]                                 = { first = 0x00000, last = 0x0007F, otf="latn", description = "Basic Latin" },
    ["bassavah"]                                   = { first = 0x16AD0, last = 0x16AFF,             description = "Bassa Vah" },
    ["batak"]                                      = { first = 0x01BC0, last = 0x01BFF,             description = "Batak" },
    ["bengali"]                                    = { first = 0x00980, last = 0x009FF, otf="beng", description = "Bengali" },
    ["bhaiksuki"]                                  = { first = 0x11C00, last = 0x11C6F,             description = "Bhaiksuki" },
    ["blockelements"]                              = { first = 0x02580, last = 0x0259F, otf="bopo", description = "Block Elements" },
    ["bopomofo"]                                   = { first = 0x03100, last = 0x0312F, otf="bopo", description = "Bopomofo" },
    ["bopomofoextended"]                           = { first = 0x031A0, last = 0x031BF, otf="bopo", description = "Bopomofo Extended" },
    ["boxdrawing"]                                 = { first = 0x02500, last = 0x0257F,             description = "Box Drawing" },
    ["brahmi"]                                     = { first = 0x11000, last = 0x1107F,             description = "Brahmi" },
    ["braillepatterns"]                            = { first = 0x02800, last = 0x028FF, otf="brai", description = "Braille Patterns" },
    ["buginese"]                                   = { first = 0x01A00, last = 0x01A1F, otf="bugi", description = "Buginese" },
    ["buhid"]                                      = { first = 0x01740, last = 0x0175F, otf="buhd", description = "Buhid" },
    ["byzantinemusicalsymbols"]                    = { first = 0x1D000, last = 0x1D0FF, otf="byzm", description = "Byzantine Musical Symbols" },
    ["carian"]                                     = { first = 0x102A0, last = 0x102DF,             description = "Carian" },
    ["caucasianalbanian"]                          = { first = 0x10530, last = 0x1056F,             description = "Caucasian Albanian" },
    ["chakma"]                                     = { first = 0x11100, last = 0x1114F,             description = "Chakma" },
    ["cham"]                                       = { first = 0x0AA00, last = 0x0AA5F,             description = "Cham" },
    ["cherokee"]                                   = { first = 0x013A0, last = 0x013FF, otf="cher", description = "Cherokee" },
    ["cherokeesupplement"]                         = { first = 0x0AB70, last = 0x0ABBF,             description = "Cherokee Supplement" },
    ["chesssymbols"]                               = { first = 0x1FA00, last = 0x1FA6F,             description = "Chess Symbols" },
    ["cjkcompatibility"]                           = { first = 0x03300, last = 0x033FF, otf="hang", description = "CJK Compatibility" },
    ["cjkcompatibilityforms"]                      = { first = 0x0FE30, last = 0x0FE4F, otf="hang", description = "CJK Compatibility Forms" },
    ["cjkcompatibilityideographs"]                 = { first = 0x0F900, last = 0x0FAFF, otf="hang", description = "CJK Compatibility Ideographs" },
    ["cjkcompatibilityideographssupplement"]       = { first = 0x2F800, last = 0x2FA1F, otf="hang", description = "CJK Compatibility Ideographs Supplement" },
    ["cjkradicalssupplement"]                      = { first = 0x02E80, last = 0x02EFF, otf="hang", description = "CJK Radicals Supplement" },
    ["cjkstrokes"]                                 = { first = 0x031C0, last = 0x031EF, otf="hang", description = "CJK Strokes" },
    ["cjksymbolsandpunctuation"]                   = { first = 0x03000, last = 0x0303F, otf="hang", description = "CJK Symbols and Punctuation" },
    ["cjkunifiedideographs"]                       = { first = 0x04E00, last = 0x09FFF, otf="hang", description = "CJK Unified Ideographs", catcode = "letter" },
    ["cjkunifiedideographsextensiona"]             = { first = 0x03400, last = 0x04DBF, otf="hang", description = "CJK Unified Ideographs Extension A" },
    ["cjkunifiedideographsextensionb"]             = { first = 0x20000, last = 0x2A6DF, otf="hang", description = "CJK Unified Ideographs Extension B" },
    ["cjkunifiedideographsextensionc"]             = { first = 0x2A700, last = 0x2B73F,             description = "CJK Unified Ideographs Extension C" },
    ["cjkunifiedideographsextensiond"]             = { first = 0x2B740, last = 0x2B81F,             description = "CJK Unified Ideographs Extension D" },
    ["cjkunifiedideographsextensione"]             = { first = 0x2B820, last = 0x2CEAF,             description = "CJK Unified Ideographs Extension E" },
    ["cjkunifiedideographsextensionf"]             = { first = 0x2CEB0, last = 0x2EBEF,             description = "CJK Unified Ideographs Extension F" },
    ["combiningdiacriticalmarks"]                  = { first = 0x00300, last = 0x0036F,             description = "Combining Diacritical Marks" },
    ["combiningdiacriticalmarksextended"]          = { first = 0x01AB0, last = 0x01AFF,             description = "Combining Diacritical Marks Extended" },
    ["combiningdiacriticalmarksforsymbols"]        = { first = 0x020D0, last = 0x020FF,             description = "Combining Diacritical Marks for Symbols" },
    ["combiningdiacriticalmarkssupplement"]        = { first = 0x01DC0, last = 0x01DFF,             description = "Combining Diacritical Marks Supplement" },
    ["combininghalfmarks"]                         = { first = 0x0FE20, last = 0x0FE2F,             description = "Combining Half Marks" },
    ["commonindicnumberforms"]                     = { first = 0x0A830, last = 0x0A83F,             description = "Common Indic Number Forms" },
    ["controlpictures"]                            = { first = 0x02400, last = 0x0243F,             description = "Control Pictures" },
    ["coptic"]                                     = { first = 0x02C80, last = 0x02CFF, otf="copt", description = "Coptic" },
    ["copticepactnumbers"]                         = { first = 0x102E0, last = 0x102FF,             description = "Coptic Epact Numbers" },
    ["countingrodnumerals"]                        = { first = 0x1D360, last = 0x1D37F,             description = "Counting Rod Numerals" },
    ["cuneiform"]                                  = { first = 0x12000, last = 0x123FF, otf="xsux", description = "Cuneiform" },
    ["cuneiformnumbersandpunctuation"]             = { first = 0x12400, last = 0x1247F, otf="xsux", description = "Cuneiform Numbers and Punctuation" },
    ["currencysymbols"]                            = { first = 0x020A0, last = 0x020CF,             description = "Currency Symbols" },
    ["cypriotsyllabary"]                           = { first = 0x10800, last = 0x1083F, otf="cprt", description = "Cypriot Syllabary" },
    ["cyrillic"]                                   = { first = 0x00400, last = 0x004FF, otf="cyrl", description = "Cyrillic" },
    ["cyrillicextendeda"]                          = { first = 0x02DE0, last = 0x02DFF, otf="cyrl", description = "Cyrillic Extended-A" },
    ["cyrillicextendedb"]                          = { first = 0x0A640, last = 0x0A69F, otf="cyrl", description = "Cyrillic Extended-B" },
    ["cyrillicextendedc"]                          = { first = 0x01C80, last = 0x01C8F,             description = "Cyrillic Extended-C" },
    ["cyrillicsupplement"]                         = { first = 0x00500, last = 0x0052F, otf="cyrl", description = "Cyrillic Supplement" },
    ["deseret"]                                    = { first = 0x10400, last = 0x1044F, otf="dsrt", description = "Deseret" },
    ["devanagari"]                                 = { first = 0x00900, last = 0x0097F, otf="deva", description = "Devanagari" },
    ["devanagariextended"]                         = { first = 0x0A8E0, last = 0x0A8FF,             description = "Devanagari Extended" },
    ["digitsarabicindic"]                          = { first = 0x00660, last = 0x00669, math = true },
 -- ["digitsbengali"]                              = { first = 0x009E6, last = 0x009EF, math = true },
    ["digitsbold"]                                 = { first = 0x1D7CE, last = 0x1D7D8, math = true },
 -- ["digitsdevanagari"]                           = { first = 0x00966, last = 0x0096F, math = true },
    ["digitsdoublestruck"]                         = { first = 0x1D7D8, last = 0x1D7E2, math = true },
 -- ["digitsethiopic"]                             = { first = 0x01369, last = 0x01371, math = true },
    ["digitsextendedarabicindic"]                  = { first = 0x006F0, last = 0x006F9, math = true },
 -- ["digitsgujarati"]                             = { first = 0x00AE6, last = 0x00AEF, math = true },
 -- ["digitsgurmukhi"]                             = { first = 0x00A66, last = 0x00A6F, math = true },
 -- ["digitskannada"]                              = { first = 0x00CE6, last = 0x00CEF, math = true },
 -- ["digitskhmer"]                                = { first = 0x017E0, last = 0x017E9, math = true },
 -- ["digitslao"]                                  = { first = 0x00ED0, last = 0x00ED9, math = true },
    ["digitslatin"]                                = { first = 0x00030, last = 0x00039, math = true },
 -- ["digitsmalayalam"]                            = { first = 0x00D66, last = 0x00D6F, math = true },
 -- ["digitsmongolian"]                            = { first = 0x01810, last = 0x01809, math = true },
    ["digitsmonospace"]                            = { first = 0x1D7F6, last = 0x1D80F, math = true },
 -- ["digitsmyanmar"]                              = { first = 0x01040, last = 0x01049, math = true },
    ["digitsnormal"]                               = { first = 0x00030, last = 0x00039, math = true },
 -- ["digitsoriya"]                                = { first = 0x00B66, last = 0x00B6F, math = true },
    ["digitssansserifbold"]                        = { first = 0x1D7EC, last = 0x1D805, math = true },
    ["digitssansserifnormal"]                      = { first = 0x1D7E2, last = 0x1D7EC, math = true },
 -- ["digitstamil"]                                = { first = 0x00030, last = 0x00039, math = true }, -- no zero
 -- ["digitstelugu"]                               = { first = 0x00C66, last = 0x00C6F, math = true },
 -- ["digitsthai"]                                 = { first = 0x00E50, last = 0x00E59, math = true },
 -- ["digitstibetan"]                              = { first = 0x00F20, last = 0x00F29, math = true },
    ["dingbats"]                                   = { first = 0x02700, last = 0x027BF,              description = "Dingbats" },
    ["dogra"]                                      = { first = 0x11800, last = 0x1184F,              description = "Dogra" },
    ["dominotiles"]                                = { first = 0x1F030, last = 0x1F09F,              description = "Domino Tiles" },
    ["duployan"]                                   = { first = 0x1BC00, last = 0x1BC9F,              description = "Duployan" },
    ["earlydynasticcuneiform"]                     = { first = 0x12480, last = 0x1254F,              description = "Early Dynastic Cuneiform" },
    ["egyptianhieroglyphformatcontrols"]           = { first = 0x13430, last = 0x1343F,              description = "Egyptian Hieroglyph Format Controls" },
    ["egyptianhieroglyphs"]                        = { first = 0x13000, last = 0x1342F,              description = "Egyptian Hieroglyphs" },
    ["elbasan"]                                    = { first = 0x10500, last = 0x1052F,              description = "Elbasan" },
    ["elymaic"]                                    = { first = 0x10FE0, last = 0x10FFF,              description = "Elymaic" },
    ["emoticons"]                                  = { first = 0x1F600, last = 0x1F64F,              description = "Emoticons" },
    ["enclosedalphanumerics"]                      = { first = 0x02460, last = 0x024FF,              description = "Enclosed Alphanumerics" },
    ["enclosedalphanumericsupplement"]             = { first = 0x1F100, last = 0x1F1FF,              description = "Enclosed Alphanumeric Supplement" },
    ["enclosedcjklettersandmonths"]                = { first = 0x03200, last = 0x032FF,              description = "Enclosed CJK Letters and Months" },
    ["enclosedideographicsupplement"]              = { first = 0x1F200, last = 0x1F2FF,              description = "Enclosed Ideographic Supplement" },
    ["ethiopic"]                                   = { first = 0x01200, last = 0x0137F, otf="ethi",  description = "Ethiopic" },
    ["ethiopicextended"]                           = { first = 0x02D80, last = 0x02DDF, otf="ethi",  description = "Ethiopic Extended" },
    ["ethiopicextendeda"]                          = { first = 0x0AB00, last = 0x0AB2F,              description = "Ethiopic Extended-A" },
    ["ethiopicsupplement"]                         = { first = 0x01380, last = 0x0139F, otf="ethi",  description = "Ethiopic Supplement" },
    ["generalpunctuation"]                         = { first = 0x02000, last = 0x0206F,              description = "General Punctuation" },
    ["geometricshapes"]                            = { first = 0x025A0, last = 0x025FF, math = true, description = "Geometric Shapes" },
    ["geometricshapesextended"]                    = { first = 0x1F780, last = 0x1F7FF,              description = "Geometric Shapes Extended" },
    ["georgian"]                                   = { first = 0x010A0, last = 0x010FF, otf="geor",  description = "Georgian" },
    ["georgianextended"]                           = { first = 0x01C90, last = 0x01CBF,              description = "Georgian Extended" },
    ["georgiansupplement"]                         = { first = 0x02D00, last = 0x02D2F, otf="geor",  description = "Georgian Supplement" },
    ["glagolitic"]                                 = { first = 0x02C00, last = 0x02C5F, otf="glag",  description = "Glagolitic" },
    ["glagoliticsupplement"]                       = { first = 0x1E000, last = 0x1E02F,              description = "Glagolitic Supplement" },
    ["gothic"]                                     = { first = 0x10330, last = 0x1034F, otf="goth",  description = "Gothic" },
    ["grantha"]                                    = { first = 0x11300, last = 0x1137F,              description = "Grantha" },
    ["greekandcoptic"]                             = { first = 0x00370, last = 0x003FF, otf="grek",  description = "Greek and Coptic" },
    ["greekextended"]                              = { first = 0x01F00, last = 0x01FFF, otf="grek",  description = "Greek Extended" },
    ["gujarati"]                                   = { first = 0x00A80, last = 0x00AFF, otf="gujr",  description = "Gujarati" },
    ["gunjalagondi"]                               = { first = 0x11D60, last = 0x11DAF,              description = "Gunjala Gondi" },
    ["gurmukhi"]                                   = { first = 0x00A00, last = 0x00A7F, otf="guru",  description = "Gurmukhi" },
    ["halfwidthandfullwidthforms"]                 = { first = 0x0FF00, last = 0x0FFEF,              description = "Halfwidth and Fullwidth Forms" },
    ["hangulcompatibilityjamo"]                    = { first = 0x03130, last = 0x0318F, otf="jamo",  description = "Hangul Compatibility Jamo" },
    ["hanguljamo"]                                 = { first = 0x01100, last = 0x011FF, otf="jamo",  description = "Hangul Jamo" },
    ["hanguljamoextendeda"]                        = { first = 0x0A960, last = 0x0A97F,              description = "Hangul Jamo Extended-A" },
    ["hanguljamoextendedb"]                        = { first = 0x0D7B0, last = 0x0D7FF,              description = "Hangul Jamo Extended-B" },
    ["hangulsyllables"]                            = { first = 0x0AC00, last = 0x0D7AF, otf="hang",  description = "Hangul Syllables" },
    ["hanifirohingya"]                             = { first = 0x10D00, last = 0x10D3F,              description = "Hanifi Rohingya" },
    ["hanunoo"]                                    = { first = 0x01720, last = 0x0173F, otf="hano",  description = "Hanunoo" },
    ["hatran"]                                     = { first = 0x108E0, last = 0x108FF,              description = "Hatran" },
    ["hebrew"]                                     = { first = 0x00590, last = 0x005FF, otf="hebr",  description = "Hebrew" },
    ["highprivateusesurrogates"]                   = { first = 0x0DB80, last = 0x0DBFF,              description = "High Private Use Surrogates" },
    ["highsurrogates"]                             = { first = 0x0D800, last = 0x0DB7F,              description = "High Surrogates" },
    ["hiragana"]                                   = { first = 0x03040, last = 0x0309F, otf="kana",  description = "Hiragana" },
    ["ideographicdescriptioncharacters"]           = { first = 0x02FF0, last = 0x02FFF,              description = "Ideographic Description Characters" },
    ["ideographicsymbolsandpunctuation"]           = { first = 0x16FE0, last = 0x16FFF,              description = "Ideographic Symbols and Punctuation" },
    ["imperialaramaic"]                            = { first = 0x10840, last = 0x1085F,              description = "Imperial Aramaic" },
    ["indicsiyaqnumbers"]                          = { first = 0x1EC70, last = 0x1ECBF,              description = "Indic Siyaq Numbers" },
    ["inscriptionalpahlavi"]                       = { first = 0x10B60, last = 0x10B7F,              description = "Inscriptional Pahlavi" },
    ["inscriptionalparthian"]                      = { first = 0x10B40, last = 0x10B5F,              description = "Inscriptional Parthian" },
    ["ipaextensions"]                              = { first = 0x00250, last = 0x002AF,              description = "IPA Extensions" },
    ["javanese"]                                   = { first = 0x0A980, last = 0x0A9DF,              description = "Javanese" },
    ["kaithi"]                                     = { first = 0x11080, last = 0x110CF,              description = "Kaithi" },
    ["kanaextendeda"]                              = { first = 0x1B100, last = 0x1B12F,              description = "Kana Extended-A" },
    ["kanasupplement"]                             = { first = 0x1B000, last = 0x1B0FF,              description = "Kana Supplement" },
    ["kanbun"]                                     = { first = 0x03190, last = 0x0319F,              description = "Kanbun" },
    ["kangxiradicals"]                             = { first = 0x02F00, last = 0x02FDF,              description = "Kangxi Radicals" },
    ["kannada"]                                    = { first = 0x00C80, last = 0x00CFF, otf="knda",  description = "Kannada" },
    ["katakana"]                                   = { first = 0x030A0, last = 0x030FF, otf="kana",  description = "Katakana" },
    ["katakanaphoneticextensions"]                 = { first = 0x031F0, last = 0x031FF, otf="kana",  description = "Katakana Phonetic Extensions" },
    ["kayahli"]                                    = { first = 0x0A900, last = 0x0A92F,              description = "Kayah Li" },
    ["kharoshthi"]                                 = { first = 0x10A00, last = 0x10A5F, otf="khar",  description = "Kharoshthi" },
    ["khmer"]                                      = { first = 0x01780, last = 0x017FF, otf="khmr",  description = "Khmer" },
    ["khmersymbols"]                               = { first = 0x019E0, last = 0x019FF, otf="khmr",  description = "Khmer Symbols" },
    ["khojki"]                                     = { first = 0x11200, last = 0x1124F,              description = "Khojki" },
    ["khudawadi"]                                  = { first = 0x112B0, last = 0x112FF,              description = "Khudawadi" },
    ["lao"]                                        = { first = 0x00E80, last = 0x00EFF, otf="lao",   description = "Lao" },
    ["latinextendeda"]                             = { first = 0x00100, last = 0x0017F, otf="latn",  description = "Latin Extended-A" },
    ["latinextendedadditional"]                    = { first = 0x01E00, last = 0x01EFF, otf="latn",  description = "Latin Extended Additional" },
    ["latinextendedb"]                             = { first = 0x00180, last = 0x0024F, otf="latn",  description = "Latin Extended-B" },
    ["latinextendedc"]                             = { first = 0x02C60, last = 0x02C7F, otf="latn",  description = "Latin Extended-C" },
    ["latinextendedd"]                             = { first = 0x0A720, last = 0x0A7FF, otf="latn",  description = "Latin Extended-D" },
    ["latinextendede"]                             = { first = 0x0AB30, last = 0x0AB6F,              description = "Latin Extended-E" },
    ["latinsupplement"]                            = { first = 0x00080, last = 0x000FF, otf="latn",  description = "Latin-1 Supplement" },
    ["lepcha"]                                     = { first = 0x01C00, last = 0x01C4F,              description = "Lepcha" },
    ["letterlikesymbols"]                          = { first = 0x02100, last = 0x0214F, math = true, description = "Letterlike Symbols" },
    ["limbu"]                                      = { first = 0x01900, last = 0x0194F, otf="limb",  description = "Limbu" },
    ["lineara"]                                    = { first = 0x10600, last = 0x1077F,              description = "Linear A" },
    ["linearbideograms"]                           = { first = 0x10080, last = 0x100FF, otf="linb",  description = "Linear B Ideograms" },
    ["linearbsyllabary"]                           = { first = 0x10000, last = 0x1007F, otf="linb",  description = "Linear B Syllabary" },
    ["lisu"]                                       = { first = 0x0A4D0, last = 0x0A4FF,              description = "Lisu" },
    ["lowercasebold"]                              = { first = 0x1D41A, last = 0x1D433, math = true },
    ["lowercaseboldfraktur"]                       = { first = 0x1D586, last = 0x1D59F, math = true },
    ["lowercasebolditalic"]                        = { first = 0x1D482, last = 0x1D49B, math = true },
    ["lowercaseboldscript"]                        = { first = 0x1D4EA, last = 0x1D503, math = true },
    ["lowercasedoublestruck"]                      = { first = 0x1D552, last = 0x1D56B, math = true },
    ["lowercasefraktur"]                           = { first = 0x1D51E, last = 0x1D537, math = true },
    ["lowercasegreekbold"]                         = { first = 0x1D6C2, last = 0x1D6DB, math = true },
    ["lowercasegreekbolditalic"]                   = { first = 0x1D736, last = 0x1D74F, math = true },
    ["lowercasegreekitalic"]                       = { first = 0x1D6FC, last = 0x1D715, math = true },
    ["lowercasegreeknormal"]                       = { first = 0x003B1, last = 0x003CA, math = true },
    ["lowercasegreeksansserifbold"]                = { first = 0x1D770, last = 0x1D789, math = true },
    ["lowercasegreeksansserifbolditalic"]          = { first = 0x1D7AA, last = 0x1D7C3, math = true },
    ["lowercaseitalic"]                            = { first = 0x1D44E, last = 0x1D467, math = true },
    ["lowercasemonospace"]                         = { first = 0x1D68A, last = 0x1D6A3, math = true },
    ["lowercasenormal"]                            = { first = 0x00061, last = 0x0007A, math = true },
    ["lowercasesansserifbold"]                     = { first = 0x1D5EE, last = 0x1D607, math = true },
    ["lowercasesansserifbolditalic"]               = { first = 0x1D656, last = 0x1D66F, math = true },
    ["lowercasesansserifitalic"]                   = { first = 0x1D622, last = 0x1D63B, math = true },
    ["lowercasesansserifnormal"]                   = { first = 0x1D5BA, last = 0x1D5D3, math = true },
    ["lowercasescript"]                            = { first = 0x1D4B6, last = 0x1D4CF, math = true },
    ["lowsurrogates"]                              = { first = 0x0DC00, last = 0x0DFFF,              description = "Low Surrogates" },
    ["lycian"]                                     = { first = 0x10280, last = 0x1029F,              description = "Lycian" },
    ["lydian"]                                     = { first = 0x10920, last = 0x1093F,              description = "Lydian" },
    ["mahajani"]                                   = { first = 0x11150, last = 0x1117F,              description = "Mahajani" },
    ["mahjongtiles"]                               = { first = 0x1F000, last = 0x1F02F,              description = "Mahjong Tiles" },
    ["makasar"]                                    = { first = 0x11EE0, last = 0x11EFF,              description = "Makasar" },
    ["malayalam"]                                  = { first = 0x00D00, last = 0x00D7F, otf="mlym",  description = "Malayalam" },
    ["mandaic"]                                    = { first = 0x00840, last = 0x0085F, otf="mand",  description = "Mandaic" },
    ["manichaean"]                                 = { first = 0x10AC0, last = 0x10AFF,              description = "Manichaean" },
    ["marchen"]                                    = { first = 0x11C70, last = 0x11CBF,              description = "Marchen" },
    ["masaramgondi"]                               = { first = 0x11D00, last = 0x11D5F,              description = "Masaram Gondi" },
    ["mathematicalalphanumericsymbols"]            = { first = 0x1D400, last = 0x1D7FF, math = true, description = "Mathematical Alphanumeric Symbols" },
    ["mathematicaloperators"]                      = { first = 0x02200, last = 0x022FF, math = true, description = "Mathematical Operators" },
    ["mayannumerals"]                              = { first = 0x1D2E0, last = 0x1D2FF,              description = "Mayan Numerals" },
    ["medefaidrin"]                                = { first = 0x16E40, last = 0x16E9F,              description = "Medefaidrin" },
    ["meeteimayek"]                                = { first = 0x0ABC0, last = 0x0ABFF,              description = "Meetei Mayek" },
    ["meeteimayekextensions"]                      = { first = 0x0AAE0, last = 0x0AAFF,              description = "Meetei Mayek Extensions" },
    ["mendekikakui"]                               = { first = 0x1E800, last = 0x1E8DF,              description = "Mende Kikakui" },
    ["meroiticcursive"]                            = { first = 0x109A0, last = 0x109FF,              description = "Meroitic Cursive" },
    ["meroitichieroglyphs"]                        = { first = 0x10980, last = 0x1099F,              description = "Meroitic Hieroglyphs" },
    ["miao"]                                       = { first = 0x16F00, last = 0x16F9F,              description = "Miao" },
    ["miscellaneousmathematicalsymbolsa"]          = { first = 0x027C0, last = 0x027EF, math = true, description = "Miscellaneous Mathematical Symbols-A" },
    ["miscellaneousmathematicalsymbolsb"]          = { first = 0x02980, last = 0x029FF, math = true, description = "Miscellaneous Mathematical Symbols-B" },
    ["miscellaneoussymbols"]                       = { first = 0x02600, last = 0x026FF, math = true, description = "Miscellaneous Symbols" },
    ["miscellaneoussymbolsandarrows"]              = { first = 0x02B00, last = 0x02BFF, math = true, description = "Miscellaneous Symbols and Arrows" },
    ["miscellaneoussymbolsandpictographs"]         = { first = 0x1F300, last = 0x1F5FF,              description = "Miscellaneous Symbols and Pictographs" },
    ["miscellaneoustechnical"]                     = { first = 0x02300, last = 0x023FF, math = true, description = "Miscellaneous Technical" },
    ["modi"]                                       = { first = 0x11600, last = 0x1165F,              description = "Modi" },
    ["modifiertoneletters"]                        = { first = 0x0A700, last = 0x0A71F,              description = "Modifier Tone Letters" },
    ["mongolian"]                                  = { first = 0x01800, last = 0x018AF, otf="mong",  description = "Mongolian" },
    ["mongoliansupplement"]                        = { first = 0x11660, last = 0x1167F,              description = "Mongolian Supplement" },
    ["mro"]                                        = { first = 0x16A40, last = 0x16A6F,              description = "Mro" },
    ["multani"]                                    = { first = 0x11280, last = 0x112AF,              description = "Multani" },
    ["musicalsymbols"]                             = { first = 0x1D100, last = 0x1D1FF, otf="musc",  description = "Musical Symbols" },
    ["myanmar"]                                    = { first = 0x01000, last = 0x0109F, otf="mymr",  description = "Myanmar" },
    ["myanmarextendeda"]                           = { first = 0x0AA60, last = 0x0AA7F,              description = "Myanmar Extended-A" },
    ["myanmarextendedb"]                           = { first = 0x0A9E0, last = 0x0A9FF,              description = "Myanmar Extended-B" },
    ["nabataean"]                                  = { first = 0x10880, last = 0x108AF,              description = "Nabataean" },
    ["nandinagari"]                                = { first = 0x119A0, last = 0x119FF,              description = "Nandinagari" },
    ["newa"]                                       = { first = 0x11400, last = 0x1147F,              description = "Newa" },
    ["newtailue"]                                  = { first = 0x01980, last = 0x019DF,              description = "New Tai Lue" },
    ["nko"]                                        = { first = 0x007C0, last = 0x007FF, otf="nko",   description = "NKo" },
    ["numberforms"]                                = { first = 0x02150, last = 0x0218F,              description = "Number Forms" },
    ["nushu"]                                      = { first = 0x1B170, last = 0x1B2FF,              description = "Nushu" },
    ["nyiakengpuachuehmong"]                       = { first = 0x1E100, last = 0x1E14F,              description = "Nyiakeng Puachue Hmong" },
    ["ogham"]                                      = { first = 0x01680, last = 0x0169F, otf="ogam",  description = "Ogham" },
    ["olchiki"]                                    = { first = 0x01C50, last = 0x01C7F,              description = "Ol Chiki" },
    ["oldhungarian"]                               = { first = 0x10C80, last = 0x10CFF,              description = "Old Hungarian" },
    ["olditalic"]                                  = { first = 0x10300, last = 0x1032F, otf="ital",  description = "Old Italic" },
    ["oldnortharabian"]                            = { first = 0x10A80, last = 0x10A9F,              description = "Old North Arabian" },
    ["oldpermic"]                                  = { first = 0x10350, last = 0x1037F,              description = "Old Permic" },
    ["oldpersian"]                                 = { first = 0x103A0, last = 0x103DF, otf="xpeo",  description = "Old Persian" },
    ["oldsogdian"]                                 = { first = 0x10F00, last = 0x10F2F,              description = "Old Sogdian" },
    ["oldsoutharabian"]                            = { first = 0x10A60, last = 0x10A7F,              description = "Old South Arabian" },
    ["oldturkic"]                                  = { first = 0x10C00, last = 0x10C4F,              description = "Old Turkic" },
    ["opticalcharacterrecognition"]                = { first = 0x02440, last = 0x0245F,              description = "Optical Character Recognition" },
    ["oriya"]                                      = { first = 0x00B00, last = 0x00B7F, otf="orya",  description = "Oriya" },
    ["ornamentaldingbats"]                         = { first = 0x1F650, last = 0x1F67F,              description = "Ornamental Dingbats" },
    ["osage"]                                      = { first = 0x104B0, last = 0x104FF,              description = "Osage" },
    ["osmanya"]                                    = { first = 0x10480, last = 0x104AF, otf="osma",  description = "Osmanya" },
    ["ottomansiyaqnumbers"]                        = { first = 0x1ED00, last = 0x1ED4F,              description = "Ottoman Siyaq Numbers" },
    ["pahawhhmong"]                                = { first = 0x16B00, last = 0x16B8F,              description = "Pahawh Hmong" },
    ["palmyrene"]                                  = { first = 0x10860, last = 0x1087F,              description = "Palmyrene" },
    ["paucinhau"]                                  = { first = 0x11AC0, last = 0x11AFF,              description = "Pau Cin Hau" },
    ["phagspa"]                                    = { first = 0x0A840, last = 0x0A87F, otf="phag",  description = "Phags-pa" },
    ["phaistosdisc"]                               = { first = 0x101D0, last = 0x101FF,              description = "Phaistos Disc" },
    ["phoenician"]                                 = { first = 0x10900, last = 0x1091F, otf="phnx",  description = "Phoenician" },
    ["phoneticextensions"]                         = { first = 0x01D00, last = 0x01D7F,              description = "Phonetic Extensions" },
    ["phoneticextensionssupplement"]               = { first = 0x01D80, last = 0x01DBF,              description = "Phonetic Extensions Supplement" },
    ["playingcards"]                               = { first = 0x1F0A0, last = 0x1F0FF,              description = "Playing Cards" },
    ["privateusearea"]                             = { first = 0x0E000, last = 0x0F8FF,              description = "Private Use Area" },
    ["psalterpahlavi"]                             = { first = 0x10B80, last = 0x10BAF,              description = "Psalter Pahlavi" },
    ["rejang"]                                     = { first = 0x0A930, last = 0x0A95F,              description = "Rejang" },
    ["ruminumeralsymbols"]                         = { first = 0x10E60, last = 0x10E7F,              description = "Rumi Numeral Symbols" },
    ["runic"]                                      = { first = 0x016A0, last = 0x016FF, otf="runr",  description = "Runic" },
    ["samaritan"]                                  = { first = 0x00800, last = 0x0083F,              description = "Samaritan" },
    ["saurashtra"]                                 = { first = 0x0A880, last = 0x0A8DF,              description = "Saurashtra" },
    ["sharada"]                                    = { first = 0x11180, last = 0x111DF,              description = "Sharada" },
    ["shavian"]                                    = { first = 0x10450, last = 0x1047F, otf="shaw",  description = "Shavian" },
    ["shorthandformatcontrols"]                    = { first = 0x1BCA0, last = 0x1BCAF,              description = "Shorthand Format Controls" },
    ["siddham"]                                    = { first = 0x11580, last = 0x115FF,              description = "Siddham" },
    ["sinhala"]                                    = { first = 0x00D80, last = 0x00DFF, otf="sinh",  description = "Sinhala" },
    ["sinhalaarchaicnumbers"]                      = { first = 0x111E0, last = 0x111FF,              description = "Sinhala Archaic Numbers" },
    ["smallformvariants"]                          = { first = 0x0FE50, last = 0x0FE6F,              description = "Small Form Variants" },
    ["smallkanaextension"]                         = { first = 0x1B130, last = 0x1B16F,              description = "Small Kana Extension" },
    ["sogdian"]                                    = { first = 0x10F30, last = 0x10F6F,              description = "Sogdian" },
    ["sorasompeng"]                                = { first = 0x110D0, last = 0x110FF,              description = "Sora Sompeng" },
    ["soyombo"]                                    = { first = 0x11A50, last = 0x11AAF,              description = "Soyombo" },
    ["spacingmodifierletters"]                     = { first = 0x002B0, last = 0x002FF,              description = "Spacing Modifier Letters" },
    ["specials"]                                   = { first = 0x0FFF0, last = 0x0FFFF,              description = "Specials" },
    ["sundanese"]                                  = { first = 0x01B80, last = 0x01BBF,              description = "Sundanese" },
    ["sundanesesupplement"]                        = { first = 0x01CC0, last = 0x01CCF,              description = "Sundanese Supplement" },
    ["superscriptsandsubscripts"]                  = { first = 0x02070, last = 0x0209F,              description = "Superscripts and Subscripts" },
    ["supplementalarrowsa"]                        = { first = 0x027F0, last = 0x027FF, math = true, description = "Supplemental Arrows-A" },
    ["supplementalarrowsb"]                        = { first = 0x02900, last = 0x0297F, math = true, description = "Supplemental Arrows-B" },
    ["supplementalarrowsc"]                        = { first = 0x1F800, last = 0x1F8FF, math = true, description = "Supplemental Arrows-C" },
    ["supplementalmathematicaloperators"]          = { first = 0x02A00, last = 0x02AFF, math = true, description = "Supplemental Mathematical Operators" },
    ["supplementalpunctuation"]                    = { first = 0x02E00, last = 0x02E7F,              description = "Supplemental Punctuation" },
    ["supplementalsymbolsandpictographs"]          = { first = 0x1F900, last = 0x1F9FF,              description = "Supplemental Symbols and Pictographs" },
    ["supplementaryprivateuseareaa"]               = { first = 0xF0000, last = 0xFFFFF,              description = "Supplementary Private Use Area-A" },
    ["supplementaryprivateuseareab"]               = { first = 0x100000,last = 0x10FFFF,             description = "Supplementary Private Use Area-B" },
    ["suttonsignwriting"]                          = { first = 0x1D800, last = 0x1DAAF,              description = "Sutton SignWriting" },
    ["sylotinagri"]                                = { first = 0x0A800, last = 0x0A82F, otf="sylo",  description = "Syloti Nagri" },
    ["symbolsandpictographsextendeda"]             = { first = 0x1FA70, last = 0x1FAFF,              description = "Symbols and Pictographs Extended-A" },
    ["syriac"]                                     = { first = 0x00700, last = 0x0074F, otf="syrc",  description = "Syriac" },
    ["syriacsupplement"]                           = { first = 0x00860, last = 0x0086F,              description = "Syriac Supplement" },
    ["tagalog"]                                    = { first = 0x01700, last = 0x0171F, otf="tglg",  description = "Tagalog" },
    ["tagbanwa"]                                   = { first = 0x01760, last = 0x0177F, otf="tagb",  description = "Tagbanwa" },
    ["tags"]                                       = { first = 0xE0000, last = 0xE007F,              description = "Tags" },
    ["taile"]                                      = { first = 0x01950, last = 0x0197F, otf="tale",  description = "Tai Le" },
    ["taitham"]                                    = { first = 0x01A20, last = 0x01AAF,              description = "Tai Tham" },
    ["taiviet"]                                    = { first = 0x0AA80, last = 0x0AADF,              description = "Tai Viet" },
    ["taixuanjingsymbols"]                         = { first = 0x1D300, last = 0x1D35F,              description = "Tai Xuan Jing Symbols" },
    ["takri"]                                      = { first = 0x11680, last = 0x116CF,              description = "Takri" },
    ["tamil"]                                      = { first = 0x00B80, last = 0x00BFF, otf="taml",  description = "Tamil" },
    ["tamilsupplement"]                            = { first = 0x11FC0, last = 0x11FFF,              description = "Tamil Supplement" },
    ["tangut"]                                     = { first = 0x17000, last = 0x187FF,              description = "Tangut" },
    ["tangutcomponents"]                           = { first = 0x18800, last = 0x18AFF,              description = "Tangut Components" },
    ["telugu"]                                     = { first = 0x00C00, last = 0x00C7F, otf="telu",  description = "Telugu" },
    ["thaana"]                                     = { first = 0x00780, last = 0x007BF, otf="thaa",  description = "Thaana" },
    ["thai"]                                       = { first = 0x00E00, last = 0x00E7F, otf="thai",  description = "Thai" },
    ["tibetan"]                                    = { first = 0x00F00, last = 0x00FFF, otf="tibt",  description = "Tibetan" },
    ["tifinagh"]                                   = { first = 0x02D30, last = 0x02D7F, otf="tfng",  description = "Tifinagh" },
    ["tirhuta"]                                    = { first = 0x11480, last = 0x114DF,              description = "Tirhuta" },
    ["transportandmapsymbols"]                     = { first = 0x1F680, last = 0x1F6FF,              description = "Transport and Map Symbols" },
    ["ugaritic"]                                   = { first = 0x10380, last = 0x1039F, otf="ugar",  description = "Ugaritic" },
    ["unifiedcanadianaboriginalsyllabics"]         = { first = 0x01400, last = 0x0167F, otf="cans",  description = "Unified Canadian Aboriginal Syllabics" },
    ["unifiedcanadianaboriginalsyllabicsextended"] = { first = 0x018B0, last = 0x018FF,              description = "Unified Canadian Aboriginal Syllabics Extended" },
    ["uppercasebold"]                              = { first = 0x1D400, last = 0x1D419, math = true },
    ["uppercaseboldfraktur"]                       = { first = 0x1D56C, last = 0x1D585, math = true },
    ["uppercasebolditalic"]                        = { first = 0x1D468, last = 0x1D481, math = true },
    ["uppercaseboldscript"]                        = { first = 0x1D4D0, last = 0x1D4E9, math = true },
    ["uppercasedoublestruck"]                      = { first = 0x1D538, last = 0x1D551, math = true }, -- gaps are filled in elsewhere
    ["uppercasefraktur"]                           = { first = 0x1D504, last = 0x1D51D, math = true },
    ["uppercasegreekbold"]                         = { first = 0x1D6A8, last = 0x1D6C1, math = true },
    ["uppercasegreekbolditalic"]                   = { first = 0x1D71C, last = 0x1D735, math = true },
    ["uppercasegreekitalic"]                       = { first = 0x1D6E2, last = 0x1D6FB, math = true },
    ["uppercasegreeknormal"]                       = { first = 0x00391, last = 0x003AA, math = true },
    ["uppercasegreeksansserifbold"]                = { first = 0x1D756, last = 0x1D76F, math = true },
    ["uppercasegreeksansserifbolditalic"]          = { first = 0x1D790, last = 0x1D7A9, math = true },
    ["uppercaseitalic"]                            = { first = 0x1D434, last = 0x1D44D, math = true },
    ["uppercasemonospace"]                         = { first = 0x1D670, last = 0x1D689, math = true },
    ["uppercasenormal"]                            = { first = 0x00041, last = 0x0005A, math = true },
    ["uppercasesansserifbold"]                     = { first = 0x1D5D4, last = 0x1D5ED, math = true },
    ["uppercasesansserifbolditalic"]               = { first = 0x1D63C, last = 0x1D655, math = true },
    ["uppercasesansserifitalic"]                   = { first = 0x1D608, last = 0x1D621, math = true },
    ["uppercasesansserifnormal"]                   = { first = 0x1D5A0, last = 0x1D5B9, math = true },
    ["uppercasescript"]                            = { first = 0x1D49C, last = 0x1D4B5, math = true },
    ["vai"]                                        = { first = 0x0A500, last = 0x0A63F,              description = "Vai" },
    ["variationselectors"]                         = { first = 0x0FE00, last = 0x0FE0F,              description = "Variation Selectors" },
    ["variationselectorssupplement"]               = { first = 0xE0100, last = 0xE01EF,              description = "Variation Selectors Supplement" },
    ["vedicextensions"]                            = { first = 0x01CD0, last = 0x01CFF,              description = "Vedic Extensions" },
    ["verticalforms"]                              = { first = 0x0FE10, last = 0x0FE1F,              description = "Vertical Forms" },
    ["wancho"]                                     = { first = 0x1E2C0, last = 0x1E2FF,              description = "Wancho" },
    ["warangciti"]                                 = { first = 0x118A0, last = 0x118FF,              description = "Warang Citi" },
    ["yijinghexagramsymbols"]                      = { first = 0x04DC0, last = 0x04DFF, otf="yi",    description = "Yijing Hexagram Symbols" },
    ["yiradicals"]                                 = { first = 0x0A490, last = 0x0A4CF, otf="yi",    description = "Yi Radicals" },
    ["yisyllables"]                                = { first = 0x0A000, last = 0x0A48F, otf="yi",    description = "Yi Syllables" },
    ["zanabazarsquare"]                            = { first = 0x11A00, last = 0x11A4F,              description = "Zanabazar Square" },
}

-- moved from math-act.lua to here:

-- operators    : 0x02200
-- symbolsa     : 0x02701
-- symbolsb     : 0x02901
-- supplemental : 0x02A00

blocks.lowercaseitalic.gaps = {
    [0x1D455] = 0x0210E, -- ℎ h
}

blocks.uppercasescript.gaps = {
    [0x1D49D] = 0x0212C, -- ℬ script B
    [0x1D4A0] = 0x02130, -- ℰ script E
    [0x1D4A1] = 0x02131, -- ℱ script F
    [0x1D4A3] = 0x0210B, -- ℋ script H
    [0x1D4A4] = 0x02110, -- ℐ script I
    [0x1D4A7] = 0x02112, -- ℒ script L
    [0x1D4A8] = 0x02133, -- ℳ script M
    [0x1D4AD] = 0x0211B, -- ℛ script R
}

blocks.lowercasescript.gaps = {
    [0x1D4BA] = 0x0212F, -- ℯ script e
    [0x1D4BC] = 0x0210A, -- ℊ script g
    [0x1D4C4] = 0x02134, -- ℴ script o
}

blocks.uppercasefraktur.gaps = {
    [0x1D506] = 0x0212D, -- ℭ fraktur C
    [0x1D50B] = 0x0210C, -- ℌ fraktur H
    [0x1D50C] = 0x02111, -- ℑ fraktur I
    [0x1D515] = 0x0211C, -- ℜ fraktur R
    [0x1D51D] = 0x02128, -- ℨ fraktur Z
}

blocks.uppercasedoublestruck.gaps = {
    [0x1D53A] = 0x02102, -- ℂ bb C
    [0x1D53F] = 0x0210D, -- ℍ bb H
    [0x1D545] = 0x02115, -- ℕ bb N
    [0x1D547] = 0x02119, -- ℙ bb P
    [0x1D548] = 0x0211A, -- ℚ bb Q
    [0x1D549] = 0x0211D, -- ℝ bb R
    [0x1D551] = 0x02124, -- ℤ bb Z
}

characters.blocks = blocks

function characters.blockrange(name)
    local b = blocks[name]
    if b then
        return b.first, b.last
    else
        return 0, 0
    end
end

setmetatableindex(blocks, function(t,k) -- we could use an intermediate table if called often
    return k and rawget(t,lower(gsub(k,"[^a-zA-Z]","")))
end)

local otfscripts      = utilities.storage.allocate()
characters.otfscripts = otfscripts

setmetatableindex(otfscripts,function(t,unicode)
    for k, v in next, blocks do
        local first = v.first
        local last  = v.last
        if unicode >= first and unicode <= last then
            local script = v.otf or "dflt"
            for u=first,last do
                t[u] = script
            end
            return script
        end
    end
    -- pretty slow when we're here
    t[unicode] = "dflt"
    return "dflt"
end)

local splitter1 = lpeg.splitat(S(":-"))
local splitter2 = lpeg.splitat(S(" +-"),true)

function characters.getrange(name,expression) -- used in font fallback definitions (name or range)
    local range = rawget(blocks,lower(gsub(name,"[^a-zA-Z0-9]","")))
    if range then
        return range.first, range.last, range.description, range.gaps
    end
    name = gsub(name,'"',"0x") -- goodie: tex hex notation
    local start, stop
    if expression then
        local n = tonumber(name)
        if n then
            return n, n, nil
        else
            local first, rest = lpegmatch(splitter2,name)
            local range = rawget(blocks,lower(gsub(first,"[^a-zA-Z0-9]","")))
            if range then
                local s = loadstring("return 0 " .. rest)
                if type(s) == "function" then
                    local d = s()
                    if type(d) == "number" then
                        return range.first + d, range.last + d, nil
                    end
                end
            end
        end
    end
    local start, stop = lpegmatch(splitter1,name)
    if start and stop then
        start = tonumber(start,16) or tonumber(start)
        stop  = tonumber(stop, 16) or tonumber(stop)
        if start and stop then
            return start, stop, nil
        end
    end
    local slot = tonumber(name,16) or tonumber(name)
    return slot, slot, nil
end

-- print(characters.getrange("lowercaseitalic + 123",true))
-- print(characters.getrange("lowercaseitalic + 124",true))

local categorytags = allocate {
    lu = "Letter Uppercase",
    ll = "Letter Lowercase",
    lt = "Letter Titlecase",
    lm = "Letter Modifier",
    lo = "Letter Other",
    mn = "Mark Nonspacing",
    mc = "Mark Spacing Combining",
    me = "Mark Enclosing",
    nd = "Number Decimal Digit",
    nl = "Number Letter",
    no = "Number Other",
    pc = "Punctuation Connector",
    pd = "Punctuation Dash",
    ps = "Punctuation Open",
    pe = "Punctuation Close",
    pi = "Punctuation Initial Quote",
    pf = "Punctuation Final Quote",
    po = "Punctuation Other",
    sm = "Symbol Math",
    sc = "Symbol Currency",
    sk = "Symbol Modifier",
    so = "Symbol Other",
    zs = "Separator Space",
    zl = "Separator Line",
    zp = "Separator Paragraph",
    cc = "Other Control",
    cf = "Other Format",
    cs = "Other Surrogate",
    co = "Other Private Use",
    cn = "Other Not Assigned",
}

local detailtags = allocate {
    sl = "small letter",
    bl = "big letter",
    im = "iteration mark",
    pm = "prolonged sound mark"
}

characters.categorytags = categorytags
characters.detailtags   = detailtags

-- sounds : voiced unvoiced semivoiced

--~ special   : cf (softhyphen) zs (emspace)
--~ characters: ll lm lo lt lu mn nl no pc pd pe pf pi po ps sc sk sm so

local is_character = allocate ( tohash {
    "lu","ll","lt","lm","lo",
    "nd","nl","no",
    "mn",
    "nl","no",
    "pc","pd","ps","pe","pi","pf","po",
    "sm","sc","sk","so"
} )

local is_letter = allocate ( tohash {
    "ll","lm","lo","lt","lu"
} )

local is_command = allocate ( tohash {
    "cf","zs"
} )

local is_spacing = allocate ( tohash {
    "zs", "zl","zp",
} )

local is_mark = allocate ( tohash {
    "mn", "ms",
} )

local is_punctuation = allocate ( tohash {
    "pc","pd","ps","pe","pi","pf","po",
} )

local is_symbol = allocate ( tohash {
    "sm", "sc", "sk", "so",
} )

-- to be redone: store checked characters

characters.is_character   = is_character
characters.is_letter      = is_letter
characters.is_command     = is_command
characters.is_spacing     = is_spacing
characters.is_mark        = is_mark
characters.is_punctuation = is_punctuation
characters.is_symbol      = is_symbol

local mti = function(t,k)
    if type(k) == "number" then
        local c = data[k].category
        return c and rawget(t,c)
    else
        -- avoid auto conversion in data.characters lookups
    end
end

setmetatableindex(characters.is_character,  mti)
setmetatableindex(characters.is_letter,     mti)
setmetatableindex(characters.is_command,    mti)
setmetatableindex(characters.is_spacing,    mti)
setmetatableindex(characters.is_punctuation,mti)

-- todo: also define callers for the above

-- linebreak: todo: hash
--
-- normative   : BK CR LF CM SG GL CB SP ZW NL WJ JL JV JT H2 H3
-- informative : XX OP CL CP QU NS EX SY IS PR PO NU AL ID IN HY BB BA SA AI B2 HL CJ RI
--
-- comments taken from standard:

characters.linebreaks = allocate {

    -- non-tailorable line breaking classes

    ["bk"]  = "mandatory break",                             -- nl, ps : cause a line break (after)
    ["cr"]  = "carriage return",                             -- cr : cause a line break (after), except between cr and lf
    ["lf"]  = "line feed",                                   -- lf : cause a line break (after)
    ["cm"]  = "combining mark",                              -- combining marks, control codes : prohibit a line break between the character and the preceding character
    ["nl"]  = "next line",                                   -- nel : cause a line break (after)
    ["sg"]  = "surrogate",                                   -- surrogates :do not occur in well-formed text
    ["wj"]  = "word joiner",                                 -- wj : prohibit line breaks before and after
    ["zw"]  = "zero width space",                            -- zwsp : provide a break opportunity
    ["gl"]  = "non-breaking (glue)",                         -- cgj, nbsp, zwnbsp : prohibit line breaks before and after
    ["sp"]  = "space",                                       -- space : enable indirect line breaks
    ["zwj"] = "zero width joiner",                           -- prohibit line breaks within joiner sequences

    -- break opportunities

    ["b2"] = "break opportunity before and after",           -- em dash : provide a line break opportunity before and after the character
    ["ba"] = "break after",                                  -- spaces, hyphens : generally provide a line break opportunity after the character
    ["bb"] = "break before",                                 -- punctuation used in dictionaries : generally provide a line break opportunity before the character
    ["hy"] = "hyphen",                                       -- hyphen-minus : provide a line break opportunity after the character, except in numeric context
    ["cb"] = "contingent break opportunity",                 -- inline objects : provide a line break opportunity contingent on additional information

    -- characters prohibiting certain breaks

    ["cl"] = "close punctuation",                            -- “}”, “❳”, “⟫” etc. : prohibit line breaks before
    ["cp"] = "close parenthesis",                            -- “)”, “]” : prohibit line breaks before
    ["ex"] = "exclamation/interrogation",                    -- “!”, “?”, etc. : prohibit line breaks before
    ["in"] = "inseparable",                                  -- leaders : allow only indirect line breaks between pairs
    ["ns"] = "nonstarter",                                   -- “‼”, “‽”, “⁇”, “⁉”, etc. : allow only indirect line breaks before
    ["op"] = "open punctuation",                             -- “(“, “[“, “{“, etc. : prohibit line breaks after
    ["qu"] = "quotation",                                    -- quotation marks : act like they are both opening and closing

    -- numeric context

    ["is"] = "infix numeric separator",                      -- . , : prevent breaks after any and before numeric
    ["nu"] = "numeric",                                      -- digits : form numeric expressions for line breaking purposes
    ["po"] = "postfix numeric",                              -- %, ¢ : do not break following a numeric expression
    ["pr"] = "prefix numeric",                               -- $, £, ¥, etc. : do not break in front of a numeric expression
    ["sy"] = "symbols allowing break after",                 -- / : prevent a break before, and allow a break after

    -- other characters

    ["ai"] = "ambiguous (alphabetic or ideographic)",        -- characters with ambiguous east asian width : act like al when the resolved eaw is n; otherwise, act as id
    ["al"] = "alphabetic",                                   -- alphabets and regular symbols : are alphabetic characters or symbols that are used with alphabetic characters
    ["cj"] = "conditional japanese starter",                 -- small kana : treat as ns or id for strict or normal breaking.
    ["eb"] = "emoji base",                                   -- all emoji allowing modifiers, do not break from following emoji modifier
    ["em"] = "emoji modifier",                               -- skin tone modifiers, do not break from preceding emoji base
    ["h2"] = "hangul lv syllable",                           -- hangul : form korean syllable blocks
    ["h3"] = "hangul lvt syllable",                          -- hangul : form korean syllable blocks
    ["hl"] = "hebrew letter",                                -- hebrew : do not break around a following hyphen; otherwise act as alphabetic
    ["id"] = "ideographic",                                  -- ideographs : break before or after, except in some numeric context
    ["jl"] = "hangul l jamo",                                -- conjoining jamo : form korean syllable blocks
    ["jv"] = "hangul v jamo",                                -- conjoining jamo : form korean syllable blocks
    ["jt"] = "hangul t jamo",                                -- conjoining jamo : form korean syllable blocks
    ["ri"] = "regional indicator",                           -- regional indicator symbol letter a .. z : keep together, break before and after from others
    ["sa"] = "complex context dependent (south east asian)", -- south east asian: thai, lao, khmer : provide a line break opportunity contingent on additional, language-specific context analysis
    ["xx"] = "unknown",                                      -- most unassigned, private-use : have as yet unknown line breaking behavior or unassigned code positions

}

-- east asian width:
--
-- N A H W F Na

characters.bidi = allocate {
    l   = "Left-to-Right",
    lre = "Left-to-Right Embedding",
    lro = "Left-to-Right Override",
    r   = "Right-to-Left",
    al  = "Right-to-Left Arabic",
    rle = "Right-to-Left Embedding",
    rlo = "Right-to-Left Override",
    pdf = "Pop Directional Format",
    en  = "European Number",
    es  = "European Number Separator",
    et  = "European Number Terminator",
    an  = "Arabic Number",
    cs  = "Common Number Separator",
    nsm = "Non-Spacing Mark",
    bn  = "Boundary Neutral",
    b   = "Paragraph Separator",
    s   = "Segment Separator",
    ws  = "Whitespace",
    on  = "Other Neutrals",
}

--[[ldx--
<p>At this point we assume that the big data table is loaded. From this
table we derive a few more.</p>
--ldx]]--

if not characters.fallbacks then

    characters.fallbacks = allocate {
        [0x0308] = 0x00A8, [0x00A8] = 0x0308, -- dieresiscmb      dieresis
        [0x0304] = 0x00AF, [0x00AF] = 0x0304, -- macroncmb        macron
        [0x0301] = 0x00B4, [0x00B4] = 0x0301, -- acutecomb        acute
        [0x0327] = 0x00B8, [0x00B8] = 0x0327, -- cedillacmb       cedilla
        [0x0302] = 0x02C6, [0x02C6] = 0x0302, -- circumflexcmb    circumflex
        [0x030C] = 0x02C7, [0x02C7] = 0x030C, -- caroncmb         caron
        [0x0306] = 0x02D8, [0x02D8] = 0x0306, -- brevecmb         breve
        [0x0307] = 0x02D9, [0x02D9] = 0x0307, -- dotaccentcmb     dotaccent
        [0x030A] = 0x02DA, [0x02DA] = 0x030A, -- ringcmb          ring
        [0x0328] = 0x02DB, [0x02DB] = 0x0328, -- ogonekcmb        ogonek
        [0x0303] = 0x02DC, [0x02DC] = 0x0303, -- tildecomb        tilde
        [0x030B] = 0x02DD, [0x02DD] = 0x030B, -- hungarumlautcmb  hungarumlaut
        [0x0305] = 0x203E, [0x203E] = 0x0305, -- overlinecmb      overline
        [0x0300] = 0x0060, [0x0060] = 0x0333, -- gravecomb        grave
    }

    -- not done (would mess up mapping):
    --
    -- 0X0301/0X0384 0X0314/0X1FFE 0X0313/0X1FBD 0X0313/0X1FBF 0X0342/0X1FC0
    -- 0X3099/0X309B 0X309A/0X309C 0X0333/0X2017 0X0345/0X037A

end

if storage then
    storage.register("characters/fallbacks", characters.fallbacks, "characters.fallbacks") -- accents and such
end

characters.directions  = { }

setmetatableindex(characters.directions,function(t,k)
    local d = data[k]
    if d then
        local v = d.direction
        if v then
            t[k] = v
            return v
        end
    end
    t[k] = false -- maybe 'l'
    return false
end)

characters.mirrors  = { }

setmetatableindex(characters.mirrors,function(t,k)
    local d = data[k]
    if d then
        local v = d.mirror
        if v then
            t[k] = v
            return v
        end
    end
    t[k] = false
    return false
end)

characters.textclasses  = { }

setmetatableindex(characters.textclasses,function(t,k)
    local d = data[k]
    if d then
        local v = d.textclass
        if v then
            t[k] = v
            return v
        end
    end
    t[k] = false
    return false
end)

--[[ldx--
<p>Next comes a whole series of helper methods. These are (will be) part
of the official <l n='api'/>.</p>
--ldx]]--

-- we could make them virtual: characters.contextnames[n]

function characters.contextname(n) return data[n] and data[n].contextname or "" end
function characters.adobename  (n) return data[n] and data[n].adobename   or "" end
function characters.description(n) return data[n] and data[n].description or "" end
-------- characters.category   (n) return data[n] and data[n].category    or "" end

function characters.category(n,verbose)
    local c = data[n].category
    if not c then
        return ""
    elseif verbose then
        return categorytags[c]
    else
        return c
    end
end

-- -- some day we will make a table .. not that many calls to utfchar
--
-- local utfchar = utf.char
-- local utfbyte = utf.byte
-- local utfbytes = { }
-- local utfchars = { }
--
-- table.setmetatableindex(utfbytes,function(t,k) local v = utfchar(k) t[k] = v return v end)
-- table.setmetatableindex(utfchars,function(t,k) local v = utfbyte(k) t[k] = v return v end)

local function toutfstring(s)
    if type(s) == "table" then
        return utfchar(unpack(s)) -- concat { utfchar( unpack(s) ) }
    else
        return utfchar(s)
    end
end

utf.tostring = toutfstring

local categories = allocate()  characters.categories = categories -- lazy table

setmetatableindex(categories, function(t,u) if u then local c = data[u] c = c and c.category or u t[u] = c return c end end)

-- todo: overloads (these register directly in the tables as number and string) e.g. for greek
-- todo: for string do a numeric lookup in the table itself

local lccodes = allocate()  characters.lccodes = lccodes -- lazy table
local uccodes = allocate()  characters.uccodes = uccodes -- lazy table
local shcodes = allocate()  characters.shcodes = shcodes -- lazy table
local fscodes = allocate()  characters.fscodes = fscodes -- lazy table

setmetatableindex(lccodes, function(t,u) if u then local c = data[u] c = c and c.lccode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)
setmetatableindex(uccodes, function(t,u) if u then local c = data[u] c = c and c.uccode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)
setmetatableindex(shcodes, function(t,u) if u then local c = data[u] c = c and c.shcode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)
setmetatableindex(fscodes, function(t,u) if u then local c = data[u] c = c and c.fscode or (type(u) == "string" and utfbyte(u)) or u t[u] = c return c end end)

local lcchars = allocate()  characters.lcchars = lcchars -- lazy table
local ucchars = allocate()  characters.ucchars = ucchars -- lazy table
local shchars = allocate()  characters.shchars = shchars -- lazy table
local fschars = allocate()  characters.fschars = fschars -- lazy table

setmetatableindex(lcchars, function(t,u) if u then local c = data[u] c = c and c.lccode c = c and toutfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)
setmetatableindex(ucchars, function(t,u) if u then local c = data[u] c = c and c.uccode c = c and toutfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)
setmetatableindex(shchars, function(t,u) if u then local c = data[u] c = c and c.shcode c = c and toutfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)
setmetatableindex(fschars, function(t,u) if u then local c = data[u] c = c and c.fscode c = c and toutfstring(c) or (type(u) == "number" and utfchar(u)) or u t[u] = c return c end end)

local decomposed = allocate()  characters.decomposed = decomposed   -- lazy table
local specials   = allocate()  characters.specials   = specials     -- lazy table

setmetatableindex(decomposed, function(t,u) -- either a table or false
    if u then
        local c = data[u]
        local s = c and c.decomposed or false -- could fall back to specials
        t[u] = s
        return s
    end
end)

setmetatableindex(specials, function(t,u) -- either a table or false
    if u then
        local c = data[u]
        local s = c and c.specials or false
        t[u] = s
        return s
    end
end)

local specialchars = allocate()  characters.specialchars = specialchars -- lazy table
local descriptions = allocate()  characters.descriptions = descriptions -- lazy table
local synonyms     = allocate()  characters.synonyms     = synonyms     -- lazy table

setmetatableindex(specialchars, function(t,u)
    if u then
        local c = data[u]
        local s = c and c.specials
        if s then
            local tt  = { }
            local ttn = 0
            for i=2,#s do
                local si = s[i]
                local c = data[si]
                if is_letter[c.category] then
                    ttn = ttn + 1
                    tt[ttn] = utfchar(si)
                end
            end
            c = concat(tt)
            t[u] = c
            return c
        else
            if type(u) == "number" then
                u = utfchar(u)
            end
            t[u] = u
            return u
        end
    end
end)

setmetatableindex(descriptions, function(t,k)
    -- 0.05 - 0.10 sec
    for u, c in next, data do
        local d = c.description
        if d then
            if find(d," ",1,true) then
                d = gsub(d," ","")
            end
            d = lower(d)
            t[d] = u
        end
    end
    local d = rawget(t,k)
    if not d then
        t[k] = k
    end
    return d
end)

setmetatableindex(synonyms, function(t,k)
    for u, c in next, data do
        local s = c.synonyms
        if s then
            if find(s," ",1,true) then
                s = gsub(s," ","")
            end
         -- s = lower(s) -- is already lowercase
            t[s] = u
        end
    end
    local s = rawget(t,k)
    if not s then
        t[s] = s
    end
    return s
end)

function characters.unicodechar(asked)
    local n = tonumber(asked)
    if n then
        return n
    elseif type(asked) == "string" then
        return descriptions[asked] or descriptions[gsub(asked," ","")]
    end
end

-- function characters.lower(str)
--     local new, n = { }, 0
--     for u in utfvalues(str) do
--         n = n + 1
--         new[n] = lcchars[u]
--     end
--     return concat(new)
-- end
--
-- function characters.upper(str)
--     local new, n = { }, 0
--     for u in utfvalues(str) do
--         n = n + 1
--         new[n] = ucchars[u]
--     end
--     return concat(new)
-- end
--
-- function characters.shaped(str)
--     local new, n = { }, 0
--     for u in utfvalues(str) do
--         n = n + 1
--         new[n] = shchars[u]
--     end
--     return concat(new)
-- end

----- tolower = Cs((utf8byte/lcchars)^0)
----- toupper = Cs((utf8byte/ucchars)^0)
----- toshape = Cs((utf8byte/shchars)^0)

local tolower = Cs((utf8character/lcchars)^0) -- no need to check spacing
local toupper = Cs((utf8character/ucchars)^0) -- no need to check spacing
local toshape = Cs((utf8character/shchars)^0) -- no need to check spacing

lpegpatterns.tolower = tolower -- old ones ... will be overloaded
lpegpatterns.toupper = toupper -- old ones ... will be overloaded
lpegpatterns.toshape = toshape -- old ones ... will be overloaded

-- function characters.lower (str) return lpegmatch(tolower,str) end
-- function characters.upper (str) return lpegmatch(toupper,str) end
-- function characters.shaped(str) return lpegmatch(toshape,str) end

--     local superscripts = allocate()   characters.superscripts = superscripts
--     local subscripts   = allocate()   characters.subscripts   = subscripts

--     if storage then
--         storage.register("characters/superscripts", superscripts, "characters.superscripts")
--         storage.register("characters/subscripts",   subscripts,   "characters.subscripts")
--     end

-- end

if not characters.splits then

    local char   = allocate()
    local compat = allocate()

    local splits = {
        char   = char,
        compat = compat,
    }

    characters.splits = splits

    -- [0x013F] = { 0x004C, 0x00B7 }
    -- [0x0140] = { 0x006C, 0x00B7 }

    for unicode, data in next, characters.data do
        local specials = data.specials
        if specials and #specials > 2 then
            local kind = specials[1]
            if kind == "compat" then
                compat[unicode] = { unpack(specials,2) }
            elseif kind == "char" then
                char  [unicode] = { unpack(specials,2) }
            end
        end
    end

    if storage then
        storage.register("characters/splits", splits, "characters.splits")
    end

end

if not characters.lhash then

    local lhash = allocate()   characters.lhash = lhash -- nil if no conversion
    local uhash = allocate()   characters.uhash = uhash -- nil if no conversion
    local shash = allocate()   characters.shash = shash -- nil if no conversion

    for k, v in next, characters.data do
     -- if k < 0x11000 then
            local l = v.lccode
            if l then
                -- we have an uppercase
                if type(l) == "number" then
                    lhash[utfchar(k)] = utfchar(l)
                elseif #l == 2 then
                    lhash[utfchar(k)] = utfchar(l[1]) .. utfchar(l[2])
             -- else
             --     inspect(v)
                end
            else
                local u = v.uccode
                if u then
                    -- we have an lowercase
                    if type(u) == "number" then
                        uhash[utfchar(k)] = utfchar(u)
                    elseif #u == 2 then
                        uhash[utfchar(k)] = utfchar(u[1]) .. utfchar(u[2])
                 -- else
                 --     inspect(v)
                    end
                end
            end
            local s = v.shcode
            if s then
                if type(s) == "number" then
                    shash[utfchar(k)] = utfchar(s)
                elseif #s == 2 then
                    shash[utfchar(k)] = utfchar(s[1]) .. utfchar(s[2])
             -- else
             --     inspect(v)
                end
            end
     -- end
    end

    if storage then
        storage.register("characters/lhash", lhash, "characters.lhash")
        storage.register("characters/uhash", uhash, "characters.uhash")
        storage.register("characters/shash", shash, "characters.shash")
    end

end

local lhash = characters.lhash mark(lhash)
local uhash = characters.uhash mark(uhash)
local shash = characters.shash mark(shash)

local utf8lowercharacter = utfchartabletopattern(lhash) / lhash
local utf8uppercharacter = utfchartabletopattern(uhash) / uhash
local utf8shapecharacter = utfchartabletopattern(shash) / shash

local utf8lower = Cs((utf8lowercharacter + utf8character)^0)
local utf8upper = Cs((utf8uppercharacter + utf8character)^0)
local utf8shape = Cs((utf8shapecharacter + utf8character)^0)

lpegpatterns.utf8lowercharacter = utf8lowercharacter -- one character
lpegpatterns.utf8uppercharacter = utf8uppercharacter -- one character
lpegpatterns.utf8shapecharacter = utf8shapecharacter -- one character

lpegpatterns.utf8lower = utf8lower -- string
lpegpatterns.utf8upper = utf8upper -- string
lpegpatterns.utf8shape = utf8shape -- string

function characters.lower (str) return str and lpegmatch(utf8lower,str) or "" end
function characters.upper (str) return str and lpegmatch(utf8upper,str) or "" end
function characters.shaped(str) return str and lpegmatch(utf8shape,str) or "" end

lpeg.setutfcasers(characters.lower,characters.upper)

-- local str = [[
--     ÀÁÂÃÄÅàáâãäå àáâãäåàáâãäå ÀÁÂÃÄÅÀÁÂÃÄÅ AAAAAAaaaaaa
--     ÆÇæç         æçæç         ÆÇÆÇ         AECaec
--     ÈÉÊËèéêë     èéêëèéêë     ÈÉÊËÈÉÊË     EEEEeeee
--     ÌÍÎÏÞìíîïþ   ìíîïþìíîïþ   ÌÍÎÏÞÌÍÎÏÞ   IIIIÞiiiiþ
--     Ðð           ðð           ÐÐ           Ðð
--     Ññ           ññ           ÑÑ           Nn
--     ÒÓÔÕÖòóôõö   òóôõöòóôõö   ÒÓÔÕÖÒÓÔÕÖ   OOOOOooooo
--     Øø           øø           ØØ           Oo
--     ÙÚÛÜùúûü     ùúûüùúûü     ÙÚÛÜÙÚÛÜ     UUUUuuuu
--     Ýýÿ          ýýÿ          ÝÝŸ          Yyy
--     ß            ß            SS           ss
--     Ţţ           ţţ           ŢŢ           Tt
-- ]]
--
-- local lower  = characters.lower   print(lower(str))
-- local upper  = characters.upper   print(upper(str))
-- local shaped = characters.shaped  print(shaped(str))
--
-- local c, n = os.clock(), 10000
-- for i=1,n do lower(str) upper(str) shaped(str) end -- 2.08 => 0.77
-- print(os.clock()-c,n*#str*3)

-- maybe: (twice as fast when much ascii)
--
-- local tolower  = lpeg.patterns.tolower
-- local lower    = string.lower
--
-- local allascii = R("\000\127")^1 * P(-1)
--
-- function characters.checkedlower(str)
--     return lpegmatch(allascii,str) and lower(str) or lpegmatch(tolower,str) or str
-- end

function characters.lettered(str,spacing)
    local new, n = { }, 0
    if spacing then
        local done = false
        for u in utfvalues(str) do
            local c = data[u].category
            if is_letter[c] then
                if done and n > 1 then
                    n = n + 1
                    new[n] = " "
                    done = false
                end
                n = n + 1
                new[n] = utfchar(u)
            elseif spacing and is_spacing[c] then
                done = true
            end
        end
    else
        for u in utfvalues(str) do
            if is_letter[data[u].category] then
                n = n + 1
                new[n] = utfchar(u)
            end
        end
    end
    return concat(new)
end

--[[ldx--
<p>Requesting lower and uppercase codes:</p>
--ldx]]--

function characters.uccode(n) return uccodes[n] end -- obsolete
function characters.lccode(n) return lccodes[n] end -- obsolete

function characters.shape(n)
    local shcode = shcodes[n]
    if not shcode then
        return n, nil
    elseif type(shcode) == "table" then
        return shcode[1], shcode[#shcode]
    else
        return shcode, nil
    end
end

-- -- some day we might go this route, but it does not really save that much
-- -- so not now (we can generate a lot using mtx-unicode that operates on the
-- -- database)
--
-- -- category cjkwd direction linebreak
--
-- -- adobename comment contextcommand contextname description fallback lccode
-- -- mathclass mathfiller mathname mathspec mathstretch mathsymbol mirror
-- -- range shcode specials uccode uccodes unicodeslot
--
-- local data = {
--     ['one']={
--         common = {
--             category="cc",
--             direction="bn",
--             linebreak="cm",
--         },
--         vector = {
--             [0x0000] = {
--                 description="NULL",
--                 group='one',
--                 unicodeslot=0x0000,
--             },
--             {
--                 description="START OF HEADING",
--                 group='one',
--                 unicodeslot=0x0001,
--             },
--         }
--     }
-- }
--
-- local chardata, groupdata = { }, { }
--
-- for group, gdata in next, data do
--     local common, vector = { __index = gdata.common }, gdata.vector
--     for character, cdata in next, vector do
--         chardata[character] = cdata
--         setmetatable(cdata,common)
--     end
--     groupdata[group] = gdata
-- end

-- characters.data, characters.groups = chardata, groupdata

--  [0xF0000]={
--   category="co",
--   cjkwd="a",
--   description="<Plane 0x000F Private Use, First>",
--   direction="l",
--   unicodeslot=0xF0000,
--  },
--  [0xFFFFD]={
--   category="co",
--   cjkwd="a",
--   description="<Plane 0x000F Private Use, Last>",
--   direction="l",
--   unicodeslot=0xFFFFD,
--  },
--  [0x100000]={
--   category="co",
--   cjkwd="a",
--   description="<Plane 0x0010 Private Use, First>",
--   direction="l",
--   unicodeslot=0x100000,
--  },
--  [0x10FFFD]={
--   category="co",
--   cjkwd="a",
--   description="<Plane 0x0010 Private Use, Last>",
--   direction="l",
--   unicodeslot=0x10FFFD,
--  },

if not characters.superscripts then

    local superscripts = allocate()   characters.superscripts = superscripts
    local subscripts   = allocate()   characters.subscripts   = subscripts
    local fractions    = allocate()   characters.fractions    = fractions

    -- skipping U+02120 (service mark) U+02122 (trademark)

    for k, v in next, data do
        local specials = v.specials
        if specials then
            local what = specials[1]
            if what == "super" then
                if #specials == 2 then
                    superscripts[k] = specials[2]
                elseif trace_defining then
                    report_defining("ignoring %s %a, char %c, description %a","superscript",ustring(k),k,v.description)
                end
            elseif what == "sub" then
                if #specials == 2 then
                    subscripts[k] = specials[2]
                elseif trace_defining then
                    report_defining("ignoring %s %a, char %c, description %a","subscript",ustring(k),k,v.description)
                end
            elseif what == "fraction" then
                if #specials > 1 then
                    fractions[k] = { unpack(specials,2) }
                elseif trace_defining then
                    report_defining("ignoring %s %a, char %c, description %a","fraction",ustring(k),k,v.description)
                end
            end
        end
    end

 -- print(table.serialize(superscripts, "superscripts", { hexify = true }))
 -- print(table.serialize(subscripts,   "subscripts",   { hexify = true }))
 -- print(table.serialize(fractions,    "fractions",    { hexify = true }))

    if storage then
        storage.register("characters/superscripts", superscripts, "characters.superscripts")
        storage.register("characters/subscripts",   subscripts,   "characters.subscripts")
        storage.register("characters/fractions",    fractions,    "characters.fractions")
    end

end

function characters.showstring(str)
    local list = utotable(str)
    for i=1,#list do
        report_defining("split % 3i : %C",i,list[i])
    end
end

do

    -- There is no need to preload this table.

    local any       = P(1)
    local special   = S([['".,:;-+()]])
                    + P('“') + P('”')
    local apostrofe = P("’") + P("'")

    local pattern = Cs ( (
        (P("medium light") / "medium-light" + P("medium dark")  / "medium-dark") * P(" skin tone")
        + (apostrofe * P("s"))/""
        + special/""
        + any
    )^1)

    local function load()
        local name = resolvers.findfile("char-emj.lua")
        local data = name and name ~= "" and dofile(name) or { }
        local hash = { }
        for d, c in next, data do
            local k = lpegmatch(pattern,d) or d
            local u = { }
            for i=1,#c do
                u[i] = utfchar(c[i])
            end
            u = concat(u)
            hash[k] = u
        end
        return data, hash
    end

    local data, hash = nil, nil

    function characters.emojized(name)
        local t = lpegmatch(pattern,name)
        if t then
            return t
        else
            return { name }
        end
    end

    local start     = P(" ")
    local finish    = P(-1) + P(" ")
    local skintone  = P("medium ")^0 * (P("light ") + P("dark "))^0 * P("skin tone")
    local gender    = P("woman") + P("man")
    local expanded  = (
                            P("m-l-")/"medium-light"
                          + P("m-d-")/"medium-dark"
                          + P("l-")  /"light"
                          + P("m-")  /"medium"
                          + P("d-")  /"dark"
                      )
                    * (P("s-t")/" skin tone")
    local compacted = (
                        (P("medium-")/"m-" * (P("light")/"l" + P("dark")/"d"))
                      + (P("medium")/"m"   +  P("light")/"l" + P("dark")/"d")
                      )
                    * (P(" skin tone")/"-s-t")

    local pattern_0 = Cs((expanded + any)^1)
    local pattern_1 = Cs(((start * skintone + skintone * finish)/"" + any)^1)
    local pattern_2 = Cs(((start * gender   + gender   * finish)/"" + any)^1)
    local pattern_4 = Cs((compacted + any)^1)

 -- print(lpegmatch(pattern_0,"kiss woman l-s-t man d-s-t"))
 -- print(lpegmatch(pattern_0,"something m-l-s-t"))
 -- print(lpegmatch(pattern_0,"something m-s-t"))
 -- print(lpegmatch(pattern_4,"something medium-light skin tone"))
 -- print(lpegmatch(pattern_4,"something medium skin tone"))

    local skin =
        P("light skin tone")        / utfchar(0x1F3FB)
      + P("medium-light skin tone") / utfchar(0x1F3FC)
      + P("medium skin tone")       / utfchar(0x1F3FD)
      + P("medium-dark skin tone")  / utfchar(0x1F3FE)
      + P("dark skin tone")         / utfchar(0x1F3FF)

    local parent =
        P("man")   / utfchar(0x1F468)
      + P("woman") / utfchar(0x1F469)

    local child =
        P("baby")  / utfchar(0x1F476)
      + P("boy")   / utfchar(0x1F466)
      + P("girl")  / utfchar(0x1F467)

    local zwj   = utfchar(0x200D)
    local heart = utfchar(0x2764) .. utfchar(0xFE0F) .. zwj
    local kiss  = utfchar(0x2764) .. utfchar(0xFE0F) .. utfchar(0x200D) .. utfchar(0x1F48B) .. zwj

    ----- member = parent + child

    local space = P(" ")
    local final = P(-1)

    local p_done   = (space^1/zwj) + P(-1)
    local p_rest   = space/"" * (skin * p_done) + p_done
    local p_parent = parent * p_rest
    local p_child  = child  * p_rest

    local p_family = Cs ( (P("family")            * space^1)/"" * p_parent^-2 * p_child^-2 )
    local p_couple = Cs ( (P("couple with heart") * space^1)/"" * p_parent * Cc(heart) * p_parent )
    local p_kiss   = Cs ( (P("kiss")              * space^1)/"" * p_parent * Cc(kiss)  * p_parent )

    local p_special = p_family + p_couple + p_kiss

 -- print(lpeg.match(p_special,"family man woman girl"))
 -- print(lpeg.match(p_special,"family man dark skin tone woman girl girl"))

 -- local p_special = P { "all",
 --     all    = Cs (V("family") + V("couple") + V("kiss")),
 --     family = C("family")            * space^1 * V("parent")^-2 * V("child")^-2,
 --     couple = P("couple with heart") * space^1 * V("parent") * Cc(heart) * V("parent"),
 --     kiss   = P("kiss")              * space^1 * V("parent") * Cc(kiss) * V("parent"),
 --     parent = parent * V("rest"),
 --     child  = child  * V("rest"),
 --     rest   = (space * skin)^0/"" * ((space^1/zwj) + P(-1)),
 -- }

    local emoji      = { }
    characters.emoji = emoji

local cache = setmetatable({ }, { __mode = "k" } )

    function emoji.resolve(name)
        if not hash then
            data, hash = load()
        end
        local h = hash[name]
        if h then
            return h
        end
        local h = cache[name]
        if h then
            return h
        elseif h == false then
            return
        end
        -- expand shortcuts
        local name = lpegmatch(pattern_0,name) or name
        -- expand some 25K variants
        local h = lpegmatch(p_special,name)
        if h then
            cache[name] = h
            return h
        end
        -- simplify
        local s = lpegmatch(pattern_1,name)
        local h = hash[s]
        if h then
            cache[name] = h
            return h
        end
        -- simplify
        local s = lpegmatch(pattern_2,name)
        local h = hash[s]
        if h then
            cache[name] = h
            return h
        end
        cache[name] = false
    end

    function emoji.known()
        if not hash then
            data, hash = load()
        end
        return hash, data
    end

    function emoji.compact(name)
        return lpegmatch(pattern_4,name) or name
    end

end

-- code moved to char-tex.lua

return characters
