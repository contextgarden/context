if not modules then modules = { } end modules ['char-ini'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: make two files, one for format generation, one for format use

-- we can remove the tag range starting at 0xE0000 (special applications)

local utfchar, utfbyte, utfvalues, ustring, utotable = utf.char, utf.byte, utf.values, utf.ustring, utf.totable
local concat, unpack, tohash = table.concat, table.unpack, table.tohash
local next, tonumber, type, rawget, rawset = next, tonumber, type, rawget, rawset
local format, lower, gsub, match, gmatch = string.format, string.lower, string.gsub, string.match, string.match, string.gmatch
local P, R, Cs, lpegmatch, patterns = lpeg.P, lpeg.R, lpeg.Cs, lpeg.match, lpeg.patterns

local utf8byte          = patterns.utf8byte
local utf8char          = patterns.utf8char

local allocate          = utilities.storage.allocate
local mark              = utilities.storage.mark

local setmetatableindex = table.setmetatableindex

local trace_defining    = false  trackers.register("characters.defining", function(v) characters_defining = v end)

local report_defining   = logs.reporter("characters")

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
<p>This converts a string (if given) into a number.</p>
--ldx]]--

local pattern = (P("0x") + P("U+")) * ((R("09","AF")^1 * P(-1)) / function(s) return tonumber(s,16) end)

patterns.chartonumber = pattern

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
                    local v = extender(k,v)
                    t[k] = v
                    return v
                end
            end
        end
    end
    return private -- handy for when we loop over characters in fonts and check for a property
end)

local blocks = allocate {
    ["aegeannumbers"]                              = { first = 0x10100, last = 0x1013F,             description = "Aegean Numbers" },
    ["alchemicalsymbols"]                          = { first = 0x1F700, last = 0x1F77F,             description = "Alchemical Symbols" },
    ["alphabeticpresentationforms"]                = { first = 0x0FB00, last = 0x0FB4F, otf="latn", description = "Alphabetic Presentation Forms" },
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
    ["blockelements"]                              = { first = 0x02580, last = 0x0259F, otf="bopo", description = "Block Elements" },
    ["bopomofo"]                                   = { first = 0x03100, last = 0x0312F, otf="bopo", description = "Bopomofo" },
    ["bopomofoextended"]                           = { first = 0x031A0, last = 0x031BF, otf="bopo", description = "Bopomofo Extended" },
    ["boxdrawing"]                                 = { first = 0x02500, last = 0x0257F,             description = "Box Drawing" },
    ["brahmi"]                                     = { first = 0x11000, last = 0x1107F,             description = "Brahmi" },
    ["braillepatterns"]                            = { first = 0x02800, last = 0x028FF, otf="brai", description = "Braille Patterns" },
    ["buginese"]                                   = { first = 0x01A00, last = 0x01A1F, otf="bugi", description = "Buginese" },
    ["buhid"]                                      = { first = 0x01740, last = 0x0175F, otf="buhd", description = "Buhid" },
    ["byzantinemusicalsymbols"]                    = { first = 0x1D000, last = 0x1D0FF, otf="byzm", description = "Byzantine Musical Symbols" },
    ["caucasianalbanian"]                          = { first = 0x10530, last = 0x1056F,             description = "Caucasian Albanian" },
    ["commonindicnumberforms"]                     = { first = 0x0A830, last = 0x0A83F,             description = "Common Indic Number Forms" },
    ["carian"]                                     = { first = 0x102A0, last = 0x102DF,             description = "Carian" },
    ["chakma"]                                     = { first = 0x11100, last = 0x1114F,             description = "Chakma" },
    ["cham"]                                       = { first = 0x0AA00, last = 0x0AA5F,             description = "Cham" },
    ["cherokee"]                                   = { first = 0x013A0, last = 0x013FF, otf="cher", description = "Cherokee" },
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
    ["combiningdiacriticalmarks"]                  = { first = 0x00300, last = 0x0036F,             description = "Combining Diacritical Marks" },
    ["combiningdiacriticalmarksextended"]          = { first = 0x01AB0, last = 0x01AFF,             description = "Combining Diacritical Marks Extended" },
    ["combiningdiacriticalmarksforsymbols"]        = { first = 0x020D0, last = 0x020FF,             description = "Combining Diacritical Marks for Symbols" },
    ["combiningdiacriticalmarkssupplement"]        = { first = 0x01DC0, last = 0x01DFF,             description = "Combining Diacritical Marks Supplement" },
    ["combininghalfmarks"]                         = { first = 0x0FE20, last = 0x0FE2F,             description = "Combining Half Marks" },
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
    ["cyrillicsupplement"]                         = { first = 0x00500, last = 0x0052F, otf="cyrl", description = "Cyrillic Supplement" },
    ["deseret"]                                    = { first = 0x10400, last = 0x1044F, otf="dsrt", description = "Deseret" },
    ["devanagari"]                                 = { first = 0x00900, last = 0x0097F, otf="deva", description = "Devanagari" },
    ["devanagariextended"]                         = { first = 0x0A8E0, last = 0x0A8FF,             description = "Devanagari Extended" },
    ["dingbats"]                                   = { first = 0x02700, last = 0x027BF,             description = "Dingbats" },
    ["dominotiles"]                                = { first = 0x1F030, last = 0x1F09F,             description = "Domino Tiles" },
    ["duployan"]                                   = { first = 0x1BC00, last = 0x1BC9F,             description = "Duployan" },
    ["egyptianhieroglyphs"]                        = { first = 0x13000, last = 0x1342F,             description = "Egyptian Hieroglyphs" },
    ["elbasan"]                                    = { first = 0x10500, last = 0x1052F,             description = "Elbasan" },
    ["emoticons"]                                  = { first = 0x1F600, last = 0x1F64F,             description = "Emoticons" },
    ["enclosedalphanumericsupplement"]             = { first = 0x1F100, last = 0x1F1FF,             description = "Enclosed Alphanumeric Supplement" },
    ["enclosedalphanumerics"]                      = { first = 0x02460, last = 0x024FF,             description = "Enclosed Alphanumerics" },
    ["enclosedcjklettersandmonths"]                = { first = 0x03200, last = 0x032FF,             description = "Enclosed CJK Letters and Months" },
    ["enclosedideographicsupplement"]              = { first = 0x1F200, last = 0x1F2FF,             description = "Enclosed Ideographic Supplement" },
    ["ethiopic"]                                   = { first = 0x01200, last = 0x0137F, otf="ethi", description = "Ethiopic" },
    ["ethiopicextended"]                           = { first = 0x02D80, last = 0x02DDF, otf="ethi", description = "Ethiopic Extended" },
    ["ethiopicextendeda"]                          = { first = 0x0AB00, last = 0x0AB2F,             description = "Ethiopic Extended-A" },
    ["ethiopicsupplement"]                         = { first = 0x01380, last = 0x0139F, otf="ethi", description = "Ethiopic Supplement" },
    ["generalpunctuation"]                         = { first = 0x02000, last = 0x0206F,             description = "General Punctuation" },
    ["geometricshapes"]                            = { first = 0x025A0, last = 0x025FF,             description = "Geometric Shapes" },
    ["geometricshapesextended"]                    = { first = 0x1F780, last = 0x1F7FF,             description = "Geometric Shapes Extended" },
    ["georgian"]                                   = { first = 0x010A0, last = 0x010FF, otf="geor", description = "Georgian" },
    ["georgiansupplement"]                         = { first = 0x02D00, last = 0x02D2F, otf="geor", description = "Georgian Supplement" },
    ["glagolitic"]                                 = { first = 0x02C00, last = 0x02C5F, otf="glag", description = "Glagolitic" },
    ["gothic"]                                     = { first = 0x10330, last = 0x1034F, otf="goth", description = "Gothic" },
    ["grantha"]                                    = { first = 0x11300, last = 0x1137F,             description = "Grantha" },
    ["greekandcoptic"]                             = { first = 0x00370, last = 0x003FF, otf="grek", description = "Greek and Coptic" },
    ["greekextended"]                              = { first = 0x01F00, last = 0x01FFF, otf="grek", description = "Greek Extended" },
    ["gujarati"]                                   = { first = 0x00A80, last = 0x00AFF, otf="gujr", description = "Gujarati" },
    ["gurmukhi"]                                   = { first = 0x00A00, last = 0x00A7F, otf="guru", description = "Gurmukhi" },
    ["halfwidthandfullwidthforms"]                 = { first = 0x0FF00, last = 0x0FFEF,             description = "Halfwidth and Fullwidth Forms" },
    ["hangulcompatibilityjamo"]                    = { first = 0x03130, last = 0x0318F, otf="jamo", description = "Hangul Compatibility Jamo" },
    ["hanguljamo"]                                 = { first = 0x01100, last = 0x011FF, otf="jamo", description = "Hangul Jamo" },
    ["hanguljamoextendeda"]                        = { first = 0x0A960, last = 0x0A97F,             description = "Hangul Jamo Extended-A" },
    ["hanguljamoextendedb"]                        = { first = 0x0D7B0, last = 0x0D7FF,             description = "Hangul Jamo Extended-B" },
    ["hangulsyllables"]                            = { first = 0x0AC00, last = 0x0D7AF, otf="hang", description = "Hangul Syllables" },
    ["hanunoo"]                                    = { first = 0x01720, last = 0x0173F, otf="hano", description = "Hanunoo" },
    ["hebrew"]                                     = { first = 0x00590, last = 0x005FF, otf="hebr", description = "Hebrew" },
    ["highprivateusesurrogates"]                   = { first = 0x0DB80, last = 0x0DBFF,             description = "High Private Use Surrogates" },
    ["highsurrogates"]                             = { first = 0x0D800, last = 0x0DB7F,             description = "High Surrogates" },
    ["hiragana"]                                   = { first = 0x03040, last = 0x0309F, otf="kana", description = "Hiragana" },
    ["ideographicdescriptioncharacters"]           = { first = 0x02FF0, last = 0x02FFF,             description = "Ideographic Description Characters" },
    ["imperialaramaic"]                            = { first = 0x10840, last = 0x1085F,             description = "Imperial Aramaic" },
    ["inscriptionalpahlavi"]                       = { first = 0x10B60, last = 0x10B7F,             description = "Inscriptional Pahlavi" },
    ["inscriptionalparthian"]                      = { first = 0x10B40, last = 0x10B5F,             description = "Inscriptional Parthian" },
    ["ipaextensions"]                              = { first = 0x00250, last = 0x002AF,             description = "IPA Extensions" },
    ["javanese"]                                   = { first = 0x0A980, last = 0x0A9DF,             description = "Javanese" },
    ["kaithi"]                                     = { first = 0x11080, last = 0x110CF,             description = "Kaithi" },
    ["kanasupplement"]                             = { first = 0x1B000, last = 0x1B0FF,             description = "Kana Supplement" },
    ["kanbun"]                                     = { first = 0x03190, last = 0x0319F,             description = "Kanbun" },
    ["kangxiradicals"]                             = { first = 0x02F00, last = 0x02FDF,             description = "Kangxi Radicals" },
    ["kannada"]                                    = { first = 0x00C80, last = 0x00CFF, otf="knda", description = "Kannada" },
    ["katakana"]                                   = { first = 0x030A0, last = 0x030FF, otf="kana", description = "Katakana" },
    ["katakanaphoneticextensions"]                 = { first = 0x031F0, last = 0x031FF, otf="kana", description = "Katakana Phonetic Extensions" },
    ["kayahli"]                                    = { first = 0x0A900, last = 0x0A92F,             description = "Kayah Li" },
    ["kharoshthi"]                                 = { first = 0x10A00, last = 0x10A5F, otf="khar", description = "Kharoshthi" },
    ["khmer"]                                      = { first = 0x01780, last = 0x017FF, otf="khmr", description = "Khmer" },
    ["khmersymbols"]                               = { first = 0x019E0, last = 0x019FF, otf="khmr", description = "Khmer Symbols" },
    ["khojki"]                                     = { first = 0x11200, last = 0x1124F,             description = "Khojki" },
    ["khudawadi"]                                  = { first = 0x112B0, last = 0x112FF,             description = "Khudawadi" },
    ["lao"]                                        = { first = 0x00E80, last = 0x00EFF, otf="lao",  description = "Lao" },
    ["latinextendeda"]                             = { first = 0x00100, last = 0x0017F, otf="latn", description = "Latin Extended-A" },
    ["latinextendedadditional"]                    = { first = 0x01E00, last = 0x01EFF, otf="latn", description = "Latin Extended Additional" },
    ["latinextendedb"]                             = { first = 0x00180, last = 0x0024F, otf="latn", description = "Latin Extended-B" },
    ["latinextendedc"]                             = { first = 0x02C60, last = 0x02C7F, otf="latn", description = "Latin Extended-C" },
    ["latinextendedd"]                             = { first = 0x0A720, last = 0x0A7FF, otf="latn", description = "Latin Extended-D" },
    ["latinextendede"]                             = { first = 0x0AB30, last = 0x0AB6F,             description = "Latin Extended-E" },
    ["latinsupplement"]                            = { first = 0x00080, last = 0x000FF, otf="latn", description = "Latin-1 Supplement" },
    ["lepcha"]                                     = { first = 0x01C00, last = 0x01C4F,             description = "Lepcha" },
    ["letterlikesymbols"]                          = { first = 0x02100, last = 0x0214F,             description = "Letterlike Symbols" },
    ["limbu"]                                      = { first = 0x01900, last = 0x0194F, otf="limb", description = "Limbu" },
    ["lineara"]                                    = { first = 0x10600, last = 0x1077F,             description = "Linear A" },
    ["linearbideograms"]                           = { first = 0x10080, last = 0x100FF, otf="linb", description = "Linear B Ideograms" },
    ["linearbsyllabary"]                           = { first = 0x10000, last = 0x1007F, otf="linb", description = "Linear B Syllabary" },
    ["lisu"]                                       = { first = 0x0A4D0, last = 0x0A4FF,             description = "Lisu" },
    ["lowsurrogates"]                              = { first = 0x0DC00, last = 0x0DFFF,             description = "Low Surrogates" },
    ["lycian"]                                     = { first = 0x10280, last = 0x1029F,             description = "Lycian" },
    ["lydian"]                                     = { first = 0x10920, last = 0x1093F,             description = "Lydian" },
    ["mahajani"]                                   = { first = 0x11150, last = 0x1117F,             description = "Mahajani" },
    ["mahjongtiles"]                               = { first = 0x1F000, last = 0x1F02F,             description = "Mahjong Tiles" },
    ["malayalam"]                                  = { first = 0x00D00, last = 0x00D7F, otf="mlym", description = "Malayalam" },
    ["mandaic"]                                    = { first = 0x00840, last = 0x0085F, otf="mand", description = "Mandaic" },
    ["manichaean"]                                 = { first = 0x10AC0, last = 0x10AFF,             description = "Manichaean" },
    ["mathematicalalphanumericsymbols"]            = { first = 0x1D400, last = 0x1D7FF,             description = "Mathematical Alphanumeric Symbols" },
    ["mathematicaloperators"]                      = { first = 0x02200, last = 0x022FF,             description = "Mathematical Operators" },
    ["meeteimayek"]                                = { first = 0x0ABC0, last = 0x0ABFF,             description = "Meetei Mayek" },
    ["meeteimayekextensions"]                      = { first = 0x0AAE0, last = 0x0AAFF,             description = "Meetei Mayek Extensions" },
    ["mendekikakui"]                               = { first = 0x1E800, last = 0x1E8DF,             description = "Mende Kikakui" },
    ["meroiticcursive"]                            = { first = 0x109A0, last = 0x109FF,             description = "Meroitic Cursive" },
    ["meroitichieroglyphs"]                        = { first = 0x10980, last = 0x1099F,             description = "Meroitic Hieroglyphs" },
    ["miao"]                                       = { first = 0x16F00, last = 0x16F9F,             description = "Miao" },
    ["miscellaneousmathematicalsymbolsa"]          = { first = 0x027C0, last = 0x027EF,             description = "Miscellaneous Mathematical Symbols-A" },
    ["miscellaneousmathematicalsymbolsb"]          = { first = 0x02980, last = 0x029FF,             description = "Miscellaneous Mathematical Symbols-B" },
    ["miscellaneoussymbols"]                       = { first = 0x02600, last = 0x026FF,             description = "Miscellaneous Symbols" },
    ["miscellaneoussymbolsandarrows"]              = { first = 0x02B00, last = 0x02BFF,             description = "Miscellaneous Symbols and Arrows" },
    ["miscellaneoussymbolsandpictographs"]         = { first = 0x1F300, last = 0x1F5FF,             description = "Miscellaneous Symbols and Pictographs" },
    ["miscellaneoustechnical"]                     = { first = 0x02300, last = 0x023FF,             description = "Miscellaneous Technical" },
    ["modi"]                                       = { first = 0x11600, last = 0x1165F,             description = "Modi" },
    ["modifiertoneletters"]                        = { first = 0x0A700, last = 0x0A71F,             description = "Modifier Tone Letters" },
    ["mongolian"]                                  = { first = 0x01800, last = 0x018AF, otf="mong", description = "Mongolian" },
    ["mro"]                                        = { first = 0x16A40, last = 0x16A6F,             description = "Mro" },
    ["musicalsymbols"]                             = { first = 0x1D100, last = 0x1D1FF, otf="musc", description = "Musical Symbols" },
    ["myanmar"]                                    = { first = 0x01000, last = 0x0109F, otf="mymr", description = "Myanmar" },
    ["myanmarextendeda"]                           = { first = 0x0AA60, last = 0x0AA7F,             description = "Myanmar Extended-A" },
    ["myanmarextendedb"]                           = { first = 0x0A9E0, last = 0x0A9FF,             description = "Myanmar Extended-B" },
    ["nabataean"]                                  = { first = 0x10880, last = 0x108AF,             description = "Nabataean" },
    ["newtailue"]                                  = { first = 0x01980, last = 0x019DF,             description = "New Tai Lue" },
    ["nko"]                                        = { first = 0x007C0, last = 0x007FF, otf="nko",  description = "NKo" },
    ["numberforms"]                                = { first = 0x02150, last = 0x0218F,             description = "Number Forms" },
    ["ogham"]                                      = { first = 0x01680, last = 0x0169F, otf="ogam", description = "Ogham" },
    ["olchiki"]                                    = { first = 0x01C50, last = 0x01C7F,             description = "Ol Chiki" },
    ["olditalic"]                                  = { first = 0x10300, last = 0x1032F, otf="ital", description = "Old Italic" },
    ["oldnortharabian"]                            = { first = 0x10A80, last = 0x10A9F,             description = "Old North Arabian" },
    ["oldpermic"]                                  = { first = 0x10350, last = 0x1037F,             description = "Old Permic" },
    ["oldpersian"]                                 = { first = 0x103A0, last = 0x103DF, otf="xpeo", description = "Old Persian" },
    ["oldsoutharabian"]                            = { first = 0x10A60, last = 0x10A7F,             description = "Old South Arabian" },
    ["oldturkic"]                                  = { first = 0x10C00, last = 0x10C4F,             description = "Old Turkic" },
    ["opticalcharacterrecognition"]                = { first = 0x02440, last = 0x0245F,             description = "Optical Character Recognition" },
    ["oriya"]                                      = { first = 0x00B00, last = 0x00B7F, otf="orya", description = "Oriya" },
    ["ornamentaldingbats"]                         = { first = 0x1F650, last = 0x1F67F,             description = "Ornamental Dingbats" },
    ["osmanya"]                                    = { first = 0x10480, last = 0x104AF, otf="osma", description = "Osmanya" },
    ["pahawhhmong"]                                = { first = 0x16B00, last = 0x16B8F,             description = "Pahawh Hmong" },
    ["palmyrene"]                                  = { first = 0x10860, last = 0x1087F,             description = "Palmyrene" },
    ["paucinhau"]                                  = { first = 0x11AC0, last = 0x11AFF,             description = "Pau Cin Hau" },
    ["phagspa"]                                    = { first = 0x0A840, last = 0x0A87F, otf="phag", description = "Phags-pa" },
    ["phaistosdisc"]                               = { first = 0x101D0, last = 0x101FF,             description = "Phaistos Disc" },
    ["phoenician"]                                 = { first = 0x10900, last = 0x1091F, otf="phnx", description = "Phoenician" },
    ["phoneticextensions"]                         = { first = 0x01D00, last = 0x01D7F,             description = "Phonetic Extensions" },
    ["phoneticextensionssupplement"]               = { first = 0x01D80, last = 0x01DBF,             description = "Phonetic Extensions Supplement" },
    ["playingcards"]                               = { first = 0x1F0A0, last = 0x1F0FF,             description = "Playing Cards" },
    ["privateusearea"]                             = { first = 0x0E000, last = 0x0F8FF,             description = "Private Use Area" },
    ["psalterpahlavi"]                             = { first = 0x10B80, last = 0x10BAF,             description = "Psalter Pahlavi" },
    ["rejang"]                                     = { first = 0x0A930, last = 0x0A95F,             description = "Rejang" },
    ["ruminumeralsymbols"]                         = { first = 0x10E60, last = 0x10E7F,             description = "Rumi Numeral Symbols" },
    ["runic"]                                      = { first = 0x016A0, last = 0x016FF, otf="runr", description = "Runic" },
    ["samaritan"]                                  = { first = 0x00800, last = 0x0083F,             description = "Samaritan" },
    ["saurashtra"]                                 = { first = 0x0A880, last = 0x0A8DF,             description = "Saurashtra" },
    ["sharada"]                                    = { first = 0x11180, last = 0x111DF,             description = "Sharada" },
    ["shavian"]                                    = { first = 0x10450, last = 0x1047F, otf="shaw", description = "Shavian" },
    ["shorthandformatcontrols"]                    = { first = 0x1BCA0, last = 0x1BCAF,             description = "Shorthand Format Controls" },
    ["siddham"]                                    = { first = 0x11580, last = 0x115FF,             description = "Siddham" },
    ["sinhala"]                                    = { first = 0x00D80, last = 0x00DFF, otf="sinh", description = "Sinhala" },
    ["sinhalaarchaicnumbers"]                      = { first = 0x111E0, last = 0x111FF,             description = "Sinhala Archaic Numbers" },
    ["smallformvariants"]                          = { first = 0x0FE50, last = 0x0FE6F,             description = "Small Form Variants" },
    ["sorasompeng"]                                = { first = 0x110D0, last = 0x110FF,             description = "Sora Sompeng" },
    ["spacingmodifierletters"]                     = { first = 0x002B0, last = 0x002FF,             description = "Spacing Modifier Letters" },
    ["specials"]                                   = { first = 0x0FFF0, last = 0x0FFFF,             description = "Specials" },
    ["sundanese"]                                  = { first = 0x01B80, last = 0x01BBF,             description = "Sundanese" },
    ["sundanesesupplement"]                        = { first = 0x01CC0, last = 0x01CCF,             description = "Sundanese Supplement" },
    ["superscriptsandsubscripts"]                  = { first = 0x02070, last = 0x0209F,             description = "Superscripts and Subscripts" },
    ["supplementalarrowsa"]                        = { first = 0x027F0, last = 0x027FF,             description = "Supplemental Arrows-A" },
    ["supplementalarrowsb"]                        = { first = 0x02900, last = 0x0297F,             description = "Supplemental Arrows-B" },
    ["supplementalarrowsc"]                        = { first = 0x1F800, last = 0x1F8FF,             description = "Supplemental Arrows-C" },
    ["supplementalmathematicaloperators"]          = { first = 0x02A00, last = 0x02AFF,             description = "Supplemental Mathematical Operators" },
    ["supplementalpunctuation"]                    = { first = 0x02E00, last = 0x02E7F,             description = "Supplemental Punctuation" },
    ["supplementaryprivateuseareaa"]               = { first = 0xF0000, last = 0xFFFFF,             description = "Supplementary Private Use Area-A" },
    ["supplementaryprivateuseareab"]               = { first = 0x100000,last = 0x10FFFF,            description = "Supplementary Private Use Area-B" },
    ["sylotinagri"]                                = { first = 0x0A800, last = 0x0A82F, otf="sylo", description = "Syloti Nagri" },
    ["syriac"]                                     = { first = 0x00700, last = 0x0074F, otf="syrc", description = "Syriac" },
    ["tagalog"]                                    = { first = 0x01700, last = 0x0171F, otf="tglg", description = "Tagalog" },
    ["tagbanwa"]                                   = { first = 0x01760, last = 0x0177F, otf="tagb", description = "Tagbanwa" },
    ["tags"]                                       = { first = 0xE0000, last = 0xE007F,             description = "Tags" },
    ["taile"]                                      = { first = 0x01950, last = 0x0197F, otf="tale", description = "Tai Le" },
    ["taitham"]                                    = { first = 0x01A20, last = 0x01AAF,             description = "Tai Tham" },
    ["taiviet"]                                    = { first = 0x0AA80, last = 0x0AADF,             description = "Tai Viet" },
    ["taixuanjingsymbols"]                         = { first = 0x1D300, last = 0x1D35F,             description = "Tai Xuan Jing Symbols" },
    ["takri"]                                      = { first = 0x11680, last = 0x116CF,             description = "Takri" },
    ["tamil"]                                      = { first = 0x00B80, last = 0x00BFF, otf="taml", description = "Tamil" },
    ["telugu"]                                     = { first = 0x00C00, last = 0x00C7F, otf="telu", description = "Telugu" },
    ["thaana"]                                     = { first = 0x00780, last = 0x007BF, otf="thaa", description = "Thaana" },
    ["thai"]                                       = { first = 0x00E00, last = 0x00E7F, otf="thai", description = "Thai" },
    ["tibetan"]                                    = { first = 0x00F00, last = 0x00FFF, otf="tibt", description = "Tibetan" },
    ["tifinagh"]                                   = { first = 0x02D30, last = 0x02D7F, otf="tfng", description = "Tifinagh" },
    ["tirhuta"]                                    = { first = 0x11480, last = 0x114DF,             description = "Tirhuta" },
    ["transportandmapsymbols"]                     = { first = 0x1F680, last = 0x1F6FF,             description = "Transport and Map Symbols" },
    ["ugaritic"]                                   = { first = 0x10380, last = 0x1039F, otf="ugar", description = "Ugaritic" },
    ["unifiedcanadianaboriginalsyllabics"]         = { first = 0x01400, last = 0x0167F, otf="cans", description = "Unified Canadian Aboriginal Syllabics" },
    ["unifiedcanadianaboriginalsyllabicsextended"] = { first = 0x018B0, last = 0x018FF,             description = "Unified Canadian Aboriginal Syllabics Extended" },
    ["vai"]                                        = { first = 0x0A500, last = 0x0A63F,             description = "Vai" },
    ["variationselectors"]                         = { first = 0x0FE00, last = 0x0FE0F,             description = "Variation Selectors" },
    ["variationselectorssupplement"]               = { first = 0xE0100, last = 0xE01EF,             description = "Variation Selectors Supplement" },
    ["vedicextensions"]                            = { first = 0x01CD0, last = 0x01CFF,             description = "Vedic Extensions" },
    ["verticalforms"]                              = { first = 0x0FE10, last = 0x0FE1F,             description = "Vertical Forms" },
    ["warangciti"]                                 = { first = 0x118A0, last = 0x118FF,             description = "Warang Citi" },
    ["yijinghexagramsymbols"]                      = { first = 0x04DC0, last = 0x04DFF, otf="yi",   description = "Yijing Hexagram Symbols" },
    ["yiradicals"]                                 = { first = 0x0A490, last = 0x0A4CF, otf="yi",   description = "Yi Radicals" },
    ["yisyllables"]                                = { first = 0x0A000, last = 0x0A48F, otf="yi",   description = "Yi Syllables" },
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
        local first, last = v.first, v.last
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

function characters.getrange(name) -- used in font fallback definitions (name or range)
    local range = blocks[name]
    if range then
        return range.first, range.last, range.description, range.gaps
    end
    name = gsub(name,'"',"0x") -- goodie: tex hex notation
    local start, stop = match(name,"^(.-)[%-%:](.-)$")
    if start and stop then
        start, stop = tonumber(start,16) or tonumber(start), tonumber(stop,16) or tonumber(stop)
        if start and stop then
            return start, stop, nil
        end
    end
    local slot = tonumber(name,16) or tonumber(name)
    return slot, slot, nil
end

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

characters.categorytags = categorytags

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

-- to be redone: store checked characters

characters.is_character   = is_character
characters.is_letter      = is_letter
characters.is_command     = is_command
characters.is_spacing     = is_spacing
characters.is_mark        = is_mark
characters.is_punctuation = is_punctuation

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

characters.linebreaks = {

    -- non-tailorable line breaking classes

    ["bk"] = "mandatory break",                              -- nl, ps : cause a line break (after)
    ["cr"] = "carriage return",                              -- cr : cause a line break (after), except between cr and lf
    ["lf"] = "line feed",                                    -- lf : cause a line break (after)
    ["cm"] = "combining mark",                               -- combining marks, control codes : prohibit a line break between the character and the preceding character
    ["nl"] = "next line",                                    -- nel : cause a line break (after)
    ["sg"] = "surrogate",                                    -- surrogates :do not occur in well-formed text
    ["wj"] = "word joiner",                                  -- wj : prohibit line breaks before and after
    ["zw"] = "zero width space",                             -- zwsp : provide a break opportunity
    ["gl"] = "non-breaking (glue)",                          -- cgj, nbsp, zwnbsp : prohibit line breaks before and after
    ["sp"] = "space",                                        -- space : enable indirect line breaks

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

    characters.fallbacks = { } -- not than many

    local fallbacks = characters.fallbacks

    for k, d in next, data do
        local specials = d.specials
        if specials and specials[1] == "compat" and specials[2] == 0x0020 then
            local s = specials[3]
            if s then
                fallbacks[k] = s
                fallbacks[s] = k
            end
        end
    end

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
    return v
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
    return v
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
    return v
end)

--[[ldx--
<p>Next comes a whole series of helper methods. These are (will be) part
of the official <l n='api'/>.</p>
--ldx]]--

-- we could make them virtual: characters.contextnames[n]

function characters.contextname(n) return data[n].contextname or "" end
function characters.adobename  (n) return data[n].adobename   or "" end
function characters.description(n) return data[n].description or "" end
-------- characters.category   (n) return data[n].category    or "" end

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

setmetatableindex(specialchars, function(t,u)
    if u then
        local c = data[u]
        local s = c and c.specials
        if s then
            local tt, ttn = { }, 0
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
            d = gsub(d," ","")
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

local tolower = Cs((utf8char/lcchars)^0)
local toupper = Cs((utf8char/ucchars)^0)
local toshape = Cs((utf8char/shchars)^0)

patterns.tolower = tolower
patterns.toupper = toupper
patterns.toshape = toshape

function characters.lower (str) return lpegmatch(tolower,str) end
function characters.upper (str) return lpegmatch(toupper,str) end
function characters.shaped(str) return lpegmatch(toshape,str) end

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

function characters.safechar(n)
    local c = data[n]
    if c and c.contextname then
        return "\\" .. c.contextname
    else
        return utfchar(n)
    end
end

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

--~ characters.data, characters.groups = chardata, groupdata

--~  [0xF0000]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x000F Private Use, First>",
--~   direction="l",
--~   unicodeslot=0xF0000,
--~  },
--~  [0xFFFFD]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x000F Private Use, Last>",
--~   direction="l",
--~   unicodeslot=0xFFFFD,
--~  },
--~  [0x100000]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x0010 Private Use, First>",
--~   direction="l",
--~   unicodeslot=0x100000,
--~  },
--~  [0x10FFFD]={
--~   category="co",
--~   cjkwd="a",
--~   description="<Plane 0x0010 Private Use, Last>",
--~   direction="l",
--~   unicodeslot=0x10FFFD,
--~  },

if not characters.superscripts then

    local superscripts = allocate()   characters.superscripts = superscripts
    local subscripts   = allocate()   characters.subscripts   = subscripts

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
            end
        end
    end

 -- print(table.serialize(superscripts, "superscripts", { hexify = true }))
 -- print(table.serialize(subscripts,   "subscripts",   { hexify = true }))

    if storage then
        storage.register("characters/superscripts", superscripts, "characters.superscripts")
        storage.register("characters/subscripts",   subscripts,   "characters.subscripts")
    end

end

-- for the moment only a few

local tracedchars = utilities.strings.tracers

tracedchars[0x00] = "[signal]"
tracedchars[0x0A] = "[linefeed]"
tracedchars[0x0B] = "[tab]"
tracedchars[0x0C] = "[formfeed]"
tracedchars[0x0D] = "[return]"
tracedchars[0x20] = "[space]"

function characters.showstring(str)
    local list = utotable(str)
    for i=1,#list do
        report_defining("split % 3i : %C",i,list[i])
    end
end

-- the following code will move to char-tex.lua

-- tex

if not tex or not context or not commands then return characters end

local tex           = tex
local texsetlccode  = tex.setlccode
local texsetuccode  = tex.setuccode
local texsetsfcode  = tex.setsfcode
local texsetcatcode = tex.setcatcode

local contextsprint = context.sprint
local ctxcatcodes   = catcodes.numbers.ctxcatcodes

--[[ldx--
<p>Instead of using a <l n='tex'/> file to define the named glyphs, we
use the table. After all, we have this information available anyway.</p>
--ldx]]--

function commands.makeactive(n,name) --
    contextsprint(ctxcatcodes,format("\\catcode%s=13\\unexpanded\\def %s{\\%s}",n,utfchar(n),name))
 -- context("\\catcode%s=13\\unexpanded\\def %s{\\%s}",n,utfchar(n),name)
end

function commands.utfchar(c,n)
    if n then
     -- contextsprint(c,charfromnumber(n))
        contextsprint(c,utfchar(n))
    else
     -- contextsprint(charfromnumber(c))
        contextsprint(utfchar(c))
    end
end

function commands.safechar(n)
    local c = data[n]
    if c and c.contextname then
        contextsprint("\\" .. c.contextname) -- context[c.contextname]()
    else
        contextsprint(utfchar(n))
    end
end

tex.uprint = commands.utfchar

local forbidden = tohash { -- at least now
    0x00A0,
    0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x200B, 0x200C, 0x200D,
    0x202F,
    0x205F,
 -- 0xFEFF,
}

function characters.define(tobelettered, tobeactivated) -- catcodetables

    if trace_defining then
        report_defining("defining active character commands")
    end

    local activated, a = { }, 0

    for u, chr in next, data do -- these will be commands
        local fallback = chr.fallback
        if fallback then
            contextsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\checkedchar{",u,"}{",fallback,"}}}")
            a = a + 1
            activated[a] = u
        else
            local contextname = chr.contextname
            if contextname then
                local category = chr.category
                if is_character[category] then
                    if chr.unicodeslot < 128 then
                        if is_letter[category] then
                            contextsprint(ctxcatcodes,format("\\def\\%s{%s}",contextname,utfchar(u))) -- has no s
                        else
                            contextsprint(ctxcatcodes,format("\\chardef\\%s=%s",contextname,u)) -- has no s
                        end
                    else
                        contextsprint(ctxcatcodes,format("\\def\\%s{%s}",contextname,utfchar(u))) -- has no s
                    end
                elseif is_command[category] and not forbidden[u] then
                    contextsprint("{\\catcode",u,"=13\\unexpanded\\gdef ",utfchar(u),"{\\"..contextname,"}}")
                    a = a + 1
                    activated[a] = u
                end
            end
        end
    end

    if tobelettered then -- shared
        local saved = tex.catcodetable
        for i=1,#tobelettered do
            tex.catcodetable = tobelettered[i]
            if trace_defining then
                report_defining("defining letters (global, shared)")
            end
            for u, chr in next, data do
                if not chr.fallback and is_letter[chr.category] and u >= 128 and u <= 65536 then
                    texsetcatcode(u,11)
                end
                local range = chr.range
                if range then
                    for i=1,range.first,range.last do -- tricky as not all are letters
                        texsetcatcode(i,11)
                    end
                end
            end
            texsetcatcode(0x200C,11) -- non-joiner
            texsetcatcode(0x200D,11) -- joiner
            for k, v in next, blocks do
                if v.catcode == "letter" then
                    for i=v.first,v.last do
                        texsetcatcode(i,11)
                    end
                end
            end
        end
        tex.catcodetable = saved
    end

    local nofactivated = #tobeactivated
    if tobeactivated and nofactivated > 0 then
        for i=1,nofactivated do
            local u = activated[i]
            if u then
                report_defining("character %U is active in set %a, containing %a",u,data[u].description,tobeactivated)
            end
        end
        local saved = tex.catcodetable
        for i=1,#tobeactivated do
            local vector = tobeactivated[i]
            if trace_defining then
                report_defining("defining %a active characters in vector %a",nofactivated,vector)
            end
            tex.catcodetable = vector
            for i=1,nofactivated do
                local u = activated[i]
                if u then
                    texsetcatcode(u,13)
                end
            end
        end
        tex.catcodetable = saved
    end

end

--[[ldx--
<p>Setting the lccodes is also done in a loop over the data table.</p>
--ldx]]--

local sfmode = "unset" -- unset, traditional, normal

function characters.setcodes()
    if trace_defining then
        report_defining("defining lc and uc codes")
    end
    local traditional = sfstate == "traditional" or sfstate == "unset"
    for code, chr in next, data do
        local cc = chr.category
        if is_letter[cc] then
            local range = chr.range
            if range then
                for i=range.first,range.last do
                    texsetcatcode(i,11) -- letter
                    texsetlccode(i,i,i) -- self self
                end
            else
                local lc, uc = chr.lccode, chr.uccode
                if not lc then
                    chr.lccode, lc = code, code
                elseif type(lc) == "table" then
                    lc = code
                end
                if not uc then
                    chr.uccode, uc = code, code
                elseif type(uc) == "table" then
                    uc = code
                end
                texsetcatcode(code,11)   -- letter
                texsetlccode(code,lc,uc)
                if traditional and cc == "lu" then
                    texsetsfcode(code,999)
                end
            end
        elseif is_mark[cc] then
            texsetlccode(code,code,code) -- for hyphenation
        end
    end
    if traditional then
        sfstate = "traditional"
    end
end

-- If this is something that is not documentwide and used a lot, then we
-- need a more clever approach (trivial but not now).

local function setuppersfcodes(v,n)
    if sfstate ~= "unset" then
        report_defining("setting uppercase sf codes to %a",n)
        for code, chr in next, data do
            if chr.category == "lu" then
                texsetsfcode(code,n)
            end
        end
    end
    sfstate = v
end

directives.register("characters.spaceafteruppercase",function(v)
    if v == "traditional" then
        setuppersfcodes(v,999)
    elseif v == "normal" then
        setuppersfcodes(v,1000)
    end
end)

-- tex

function commands.chardescription(slot)
    local d = data[slot]
    if d then
        context(d.description)
    end
end

-- xml

characters.activeoffset = 0x10000 -- there will be remapped in that byte range

function commands.remapentity(chr,slot)
    contextsprint(format("{\\catcode%s=13\\xdef%s{\\string%s}}",slot,utfchar(slot),chr))
end

-- xml.entities = xml.entities or { }
--
-- storage.register("xml/entities",xml.entities,"xml.entities") -- this will move to lxml
--
-- function characters.setmkiventities()
--     local entities = xml.entities
--     entities.lt  = "<"
--     entities.amp = "&"
--     entities.gt  = ">"
-- end
--
-- function characters.setmkiientities()
--     local entities = xml.entities
--     entities.lt  = utfchar(characters.activeoffset + utfbyte("<"))
--     entities.amp = utfchar(characters.activeoffset + utfbyte("&"))
--     entities.gt  = utfchar(characters.activeoffset + utfbyte(">"))
-- end

commands.definecatcodetable = characters.define
commands.setcharactercodes  = characters.setcodes
