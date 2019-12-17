if not modules then modules = { } end modules ['mtx-unicode'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is very old code that I started writing in 2005 but occasionally
-- extended. Don't use it yourself, it's just a sort of reference. The
-- data that we use in ConTeXt is more extensive.
--
-- In my local tree I keep files in places like this:
--
--    e:/tex-context/tex/texmf-local/data/unicode/blocks.txt
--
-- curl -o arabicshaping.txt             http://www.unicode.org/Public/UNIDATA/ArabicShaping.txt
-- curl -o bidibrackets.txt              http://www.unicode.org/Public/UNIDATA/BidiBrackets.txt
-- curl -o bidicharactertest.txt         http://www.unicode.org/Public/UNIDATA/BidiCharacterTest.txt
-- curl -o bidimirroring.txt             http://www.unicode.org/Public/UNIDATA/BidiMirroring.txt
-- curl -o biditest.txt                  http://www.unicode.org/Public/UNIDATA/BidiTest.txt
-- curl -o blocks.txt                    http://www.unicode.org/Public/UNIDATA/Blocks.txt
-- curl -o cjkradicals.txt               http://www.unicode.org/Public/UNIDATA/CJKRadicals.txt
-- curl -o casefolding.txt               http://www.unicode.org/Public/UNIDATA/CaseFolding.txt
-- curl -o compositionexclusions.txt     http://www.unicode.org/Public/UNIDATA/CompositionExclusions.txt
-- curl -o derivedage.txt                http://www.unicode.org/Public/UNIDATA/DerivedAge.txt
-- curl -o derivedcoreproperties.txt     http://www.unicode.org/Public/UNIDATA/DerivedCoreProperties.txt
-- curl -o derivednormalizationprops.txt http://www.unicode.org/Public/UNIDATA/DerivedNormalizationProps.txt
-- curl -o eastasianwidth.txt            http://www.unicode.org/Public/UNIDATA/EastAsianWidth.txt
-- curl -o emojisources.txt              http://www.unicode.org/Public/UNIDATA/EmojiSources.txt
-- curl -o hangulsyllabletype.txt        http://www.unicode.org/Public/UNIDATA/HangulSyllableType.txt
-- curl -o index.txt                     http://www.unicode.org/Public/UNIDATA/Index.txt
-- curl -o indicpositionalcategory.txt   http://www.unicode.org/Public/UNIDATA/IndicPositionalCategory.txt
-- curl -o indicsyllabiccategory.txt     http://www.unicode.org/Public/UNIDATA/IndicSyllabicCategory.txt
-- curl -o jamo.txt                      http://www.unicode.org/Public/UNIDATA/Jamo.txt
-- curl -o linebreak.txt                 http://www.unicode.org/Public/UNIDATA/LineBreak.txt
-- curl -o namealiases.txt               http://www.unicode.org/Public/UNIDATA/NameAliases.txt
-- curl -o namedsequences.txt            http://www.unicode.org/Public/UNIDATA/NamedSequences.txt
-- curl -o namedsequencesprov.txt        http://www.unicode.org/Public/UNIDATA/NamedSequencesProv.txt
-- curl -o nameslist.html                http://www.unicode.org/Public/UNIDATA/NamesList.html
-- curl -o nameslist.txt                 http://www.unicode.org/Public/UNIDATA/NamesList.txt
-- curl -o normalizationcorrections.txt  http://www.unicode.org/Public/UNIDATA/NormalizationCorrections.txt
-- curl -o normalizationtest.txt         http://www.unicode.org/Public/UNIDATA/NormalizationTest.txt
-- curl -o proplist.txt                  http://www.unicode.org/Public/UNIDATA/PropList.txt
-- curl -o propertyaliases.txt           http://www.unicode.org/Public/UNIDATA/PropertyAliases.txt
-- curl -o propertyvaluealiases.txt      http://www.unicode.org/Public/UNIDATA/PropertyValueAliases.txt
-- curl -o readme.txt                    http://www.unicode.org/Public/UNIDATA/ReadMe.txt
-- curl -o scriptextensions.txt          http://www.unicode.org/Public/UNIDATA/ScriptExtensions.txt
-- curl -o scripts.txt                   http://www.unicode.org/Public/UNIDATA/Scripts.txt
-- curl -o specialcasing.txt             http://www.unicode.org/Public/UNIDATA/SpecialCasing.txt
-- curl -o standardizedvariants.html     http://www.unicode.org/Public/UNIDATA/StandardizedVariants.html
-- curl -o standardizedvariants.txt      http://www.unicode.org/Public/UNIDATA/StandardizedVariants.txt
-- curl -o tangutsources.txt             http://www.unicode.org/Public/UNIDATA/TangutSources.txt
-- curl -o ucd.zip                       http://www.unicode.org/Public/UNIDATA/UCD.zip
-- curl -o usourcedata.txt               http://www.unicode.org/Public/UNIDATA/USourceData.txt
-- curl -o usourceglyphs.pdf             http://www.unicode.org/Public/UNIDATA/USourceGlyphs.pdf
-- curl -o unicodedata.txt               http://www.unicode.org/Public/UNIDATA/UnicodeData.txt
-- curl -o unihan.zip                    http://www.unicode.org/Public/UNIDATA/Unihan.zip
--
-- curl -o emoji-data.txt                http://unicode.org/Public/emoji/12.0/emoji-data.txt
-- curl -o emoji-sequences.txt           http://unicode.org/Public/emoji/12.0/emoji-sequences.txt
-- curl -o emoji-variation-sequences.txt http://unicode.org/Public/emoji/12.0/emoji-variation-sequences.txt
-- curl -o emoji-zwj-sequences.txt       http://unicode.org/Public/emoji/12.0/emoji-zwj-sequences.txt
-- curl -o emoji-test.txt                http://unicode.org/Public/emoji/12.0/emoji-test.txt
--
-- todo:
--
--    specialcasing ?

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-unicode</entry>
  <entry name="detail">Checker for char-dat.lua</entry>
  <entry name="version">1.02</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="whatever"><short>do whatever</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-unicode",
    banner   = "Checker for char-def.lua 1.02",
    helpinfo = helpinfo,
}

local gmatch, match, gsub, find, lower, upper, format = string.gmatch, string.match, string.gsub, string.find, string.lower, string.upper, string.format
local concat, sort = table.concat, table.sort
local split, splitlines, strip = string.split, string.splitlines, string.strip
local are_equal = table.are_equal
local tonumber, tostring, rawget = tonumber, tostring, rawget
local lpegmatch = lpeg.match
local P, C, S, R, Cs, Ct, Cg, Cf, Cc = lpeg.P, lpeg.C, lpeg.S, lpeg.R, lpeg.Cs, lpeg.Ct, lpeg.Cg, lpeg.Cf, lpeg.Cc
local formatters = string.formatters
local utfchar = utf.char

local report = application.report

scripts         = scripts         or { }
scripts.unicode = scripts.unicode or { }

characters      = characters      or { }
characters.data = characters.data or { }

fonts           = fonts           or { }
fonts.encodings = fonts.encodings or { }

local textfiles = { }
local textdata  = { }

local sparse = false

local split_space_table = lpeg.tsplitat(" ")
local split_space_two   = lpeg.splitat (" ")
local split_range_two   = lpeg.splitat ("..")
local split_colon_table = lpeg.tsplitat(P(" ")^0 * P(";") * P(" ")^0)

local skipped = {
    [0x002C6] = true, -- MODIFIER LETTER CIRCUMFLEX ACCENT
    [0x002C7] = true, -- CARON
}

for i=0x0FE00,0x0FE0F do skipped[i] = true end -- variant selector
for i=0xE0100,0xE01EF do skipped[i] = true end -- variant selector extension

-- This can be done:
--
--   for i=0x1B170,0x1B2FF do skipped[i] = true end -- nushu
--
-- but then also adapt char-cjk.lua bottom part!

function scripts.unicode.update()
    local unicodedata          = texttables.unicodedata
    local bidimirroring        = texttables.bidimirroring
    local linebreak            = texttables.linebreak
    local eastasianwidth       = texttables.eastasianwidth
    local standardizedvariants = texttables.standardizedvariants
    local arabicshaping        = texttables.arabicshaping
    local index                = texttables.index
    local characterdata        = characters.data
    --
    for unicode, ud in table.sortedpairs(unicodedata) do
        if not skipped[unicode] then
            local char = rawget(characterdata,unicode)
            local description = ud[2] or formatters["UNICODE ENTRY %U"](unicode)
            if not find(description,"^<") then
                local ld        = linebreak[unicode]
                local bd        = bidimirroring[unicode]
                local ed        = eastasianwidth[unicode]
                local category  = lower(ud[3] or "?")
                local combining = tonumber(ud[4])
                local direction = lower(ud[5] or "l") -- we could omit 'l' being the default
                local linebreak = ld and lower(ld[2] or "xx")
                local specials  = ud[6] or ""
                local cjkwd     = ed and lower(ed[2] or "n")
                local mirror    = bd and tonumber(bd[2],16)
                local arabic    = nil
                if sparse and direction == "l" then
                    direction = nil
                end
                if linebreak == "xx" then
                    linebreak = nil
                end
                if specials == "" then
                    specials = nil
                else
                    specials = lpegmatch(split_space_table,specials) -- split(specials," ")
                    if tonumber(specials[1],16) then
                        for i=#specials,1,-1 do
                            specials[i+1] = tonumber(specials[i],16)
                        end
                        specials[1] = "char"
                    else
                        specials[1] = lower(gsub(specials[1],"[<>]",""))
                        for i=2,#specials do
                            specials[i] = tonumber(specials[i],16)
                        end
                    end
                end
                if cjkwd == "n" then
                    cjkwd = nil
                end
                local comment
                if find(description,"MATHEMATICAL") then
                    comment = "check math properties"
                end
                -- there are more than arabic
                local as = arabicshaping[unicode]
                if as then
                    arabic = lower(as[3])
                end
                --
                if not combining or combining == 0 then
                    combining = nil
                end
                if not char then
                    report("%U : adding entry %a",unicode,description)
                    char = {
                     -- adobename   = ,
                        category    = category,
                        comment     = comment,
                        cjkwd       = cjkwd,
                        description = description,
                        direction   = direction,
                        mirror      = mirror,
                        linebreak   = linebreak,
                        unicodeslot = unicode,
                        specials    = specials,
                        arabic      = arabic,
                        combining   = combining,
                    }
                    characterdata[unicode] = char
                else
                    if direction then
                        if char.direction ~= direction then
                            report("%U : setting direction to %a, %a",unicode,direction,description)
                            char.direction = direction
                        end
                    else
                        if char.direction then
                            report("%U : resetting direction from %a, %a",unicode,char.direction,description)
                            char.direction = nil
                        end
                    end
                    if mirror then
                        if mirror ~= char.mirror then
                            report("%U : setting mirror to %a, %a",unicode,mirror,description)
                            char.mirror = mirror
                        end
                    else
                        if char.mirror then
                            report("%U : resetting mirror from %a, %a",unicode,char.mirror,description)
                            char.mirror = nil
                        end
                    end
                    if linebreak then
                        if linebreak ~= char.linebreak then
                            report("%U : setting linebreak to %a, %a",unicode,linebreak,description)
                            char.linebreak = linebreak
                        end
                    else
                        if char.linebreak then
                            report("%U : resetting linebreak from %a, %a",unicode,char.linebreak,description)
                            char.linebreak = nil
                        end
                    end
                    if cjkwd then
                        if cjkwd ~= char.cjkwd then
                            report("%U : setting cjkwd of to %a, %a",unicode,cjkwd,description)
                            char.cjkwd = cjkwd
                        end
                    else
                        if char.cjkwd then
                            report("%U : resetting cjkwd of from %a, %a",unicode,char.cjkwd,description)
                            char.cjkwd = nil
                        end
                    end
                    if arabic then
                        if arabic ~= char.arabic then
                            report("%U : setting arabic to %a, %a",unicode,arabic,description)
                            char.arabic = arabic
                        end
                    else
                        if char.arabic then
                            report("%U : resetting arabic from %a, %a",unicode,char.arabic,description)
                            char.arabic = nil
                        end
                    end
                    if combining then
                        if combining ~= char.combining then
                            report("%U : setting combining to %a, %a",unicode,combining,description)
                            char.combining = combining
                        end
                    else
                        if char.combining then
                            report("%U : resetting combining from %a, %a",unicode,char.combining,description)
                        end
                    end
                    if specials then
                        if not char.specials or not are_equal(specials,char.specials) then
                            local t = { specials[1] } for i=2,#specials do t[i] = formatters["%U"](specials[i]) end
                            report("%U : setting specials to % + t, %a",unicode,t,description)
                            char.specials = specials
                        end
                    else
                        local specials = char.specials
                        if specials then
                            local t = { } for i=2,#specials do t[i] = formatters["%U"](specials[i]) end
                            if false then
                                char.comment = nil
                                report("%U : resetting specials from % + t, %a",unicode,t,description)
                            else
                                local comment = char.comment
                                if not comment then
                                    char.comment = "check special"
                                elseif not find(comment,"check special") then
                                    char.comment = comment .. ", check special"
                                end
                                report("%U : check specials % + t, %a",unicode,t,description)
                            end
                        end
                    end
                end
                --
                local visual = char.visual
                if not visual and find(description,"MATH") then
                    if find(description,"BOLD ITALIC") then
                        visual = "bi"
                    elseif find(description,"ITALIC") then
                        visual = "it"
                    elseif find(description,"BOLD") then
                        visual = "bf"
                    end
                    if visual then
                        report("%U : setting visual to %a, %a",unicode,visual,description)
                        char.visual = visual
                    end
                end
                -- mathextensible
                if category == "sm" or (category == "so" and char.mathclass) then
                    local mathextensible = char.mathextensible
                    if mathextensible then
                        -- already done
                    elseif find(description,"ABOVE") then
                        -- skip
                    elseif find(description,"ARROWHEAD") then
                        -- skip
                    elseif find(description,"HALFWIDTH") then
                        -- skip
                    elseif find(description,"ANGLE") then
                        -- skip
                    elseif find(description,"THROUGH") then
                        -- skip
                    elseif find(description,"ARROW") then
                            -- skip
                        local u = find(description,"UP")
                        local d = find(description,"DOWN")
                        local l = find(description,"LEFT")
                        local r = find(description,"RIGHT")
                        if find(description,"ARROWHEAD") then
                            -- skip
                        elseif find(description,"HALFWIDTH") then
                            -- skip
                        elseif u and d then
                            if l or r then
                                mathextensible = 'm' -- mixed
                            else
                                mathextensible = 'v' -- vertical
                            end
                        elseif u then
                            if l or r then
                                mathextensible = 'm' -- mixed
                            else
                                mathextensible = "u"     -- up
                            end
                        elseif d then
                            if l or r then
                                mathextensible = 'm' -- mixed
                            else
                                mathextensible = "d"     -- down
                            end
                        elseif l and r then
                            mathextensible = "h"     -- horizontal
                        elseif r then
                            mathextensible = "r"     -- right
                        elseif l then
                            mathextensible = "l"     -- left
                        end
                        if mathextensible then
                            report("%U : setting mathextensible to %a, %a",unicode,mathextensible,description)
                            char.mathextensible = mathextensible
                        end
                    end
                end
            end
        end
    end
    for i=1,#standardizedvariants do
        local si = standardizedvariants[i]
        local pair, addendum = si[1], strip(si[2])
        local first, second = lpegmatch(split_space_two,pair) -- string.splitup(pair," ")
        first = tonumber(first,16)
        second = tonumber(second,16)
        if first then
            local d = characterdata[first]
            if d then
                local v = d.variants
                local v = rawget(d,"variants")
                if not v then
                    v = { }
                    d.variants = v
                end
                if not v[second] then
                    report("%U : adding variant %U as %s, %a",first,second,addendum,d.description)
                    v[second] = addendum
                end
            end
        end
    end
    for unicode, ud in table.sortedpairs(characterdata) do
        if not rawget(ud,"category") and rawget(ud,"variants") then
            report("stripping %U (variant, takes from metacharacter)",unicode)
            characterdata[unicode] = nil
        end
    end
end

local preamble

local function splitdefinition(str,index)
    local l = splitlines(str)
    local t = { }
    if index then
        for i=1,#l do
            local s = gsub(l[i]," *#.*$","")
            if s ~= "" then
                local d = lpegmatch(split_colon_table,s) -- split(s,";")
                local o = d[1]
                local u = tonumber(o,16)
                if u then
                    t[u] = d
                else
                 -- local b, e = match(o,"^([^%.]+)%.%.([^%.]+)$")
                    local b, e = lpegmatch(split_range_two,o)
                    if b and e then
                        b = tonumber(b,16)
                        e = tonumber(e,16)
                        for k=b,e do
                            t[k] = d
                        end
                    else
                        report("problem: %s",s)
                    end
                end
            end
        end
    else
        local n = 0
        for i=1,#l do
            local s = gsub(l[i]," *#.*$","")
            if s ~= "" then
                n = n + 1
                t[n] = lpegmatch(split_colon_table,s) -- split(s,";")
            end
        end
    end
    return t
end

local function splitindex(str)
    -- ok, quick and dirty ... could be a nice lpeg instead
    local l = splitlines(str)
    local n = { }
    for i=1,#l do
        local a, b, c = match(l[i],"([^%,]+)%,?(.-)\t(.*)")
        if a and b and c then
            local name = b .. " " .. a
            name = strip(name)
            name = gsub(name,"%s+"," ")
            n[name] = tonumber(c,16)
        end
    end
    return n
end

function scripts.unicode.load()
    local fullname = resolvers.findfile("char-def.lua")
    report("using: %s",fullname)
    local data = io.loaddata(fullname)
    if data then
        loadstring(data)()
        --
        local fullname = resolvers.findfile("char-ini.lua")
        report("using: %s",fullname)
        dofile(fullname)
        --
        local fullname = resolvers.findfile("char-utf.lua")
        report("using: %s",fullname)
        dofile(fullname)
        --
        local fullname = resolvers.findfile("char-cjk.lua")
        report("using: %s",fullname)
        dofile(fullname)
        --
        preamble = gsub(data,"characters%.data%s*=%s*%{.*","")
        --
        textfiles = {
            unicodedata          = resolvers.findfile("unicodedata.txt")          or "",
            bidimirroring        = resolvers.findfile("bidimirroring.txt")        or "",
            linebreak            = resolvers.findfile("linebreak.txt")            or "",
            eastasianwidth       = resolvers.findfile("eastasianwidth.txt")       or "",
            standardizedvariants = resolvers.findfile("standardizedvariants.txt") or "",
            arabicshaping        = resolvers.findfile("arabicshaping.txt")        or "",
            index                = resolvers.findfile("index.txt")                or "",
        }
        --
        textdata = {
            unicodedata          = textfiles.unicodedata          ~= "" and io.loaddata(textfiles.unicodedata)          or "",
            bidimirroring        = textfiles.bidimirroring        ~= "" and io.loaddata(textfiles.bidimirroring)        or "",
            linebreak            = textfiles.linebreak            ~= "" and io.loaddata(textfiles.linebreak)            or "",
            eastasianwidth       = textfiles.eastasianwidth       ~= "" and io.loaddata(textfiles.eastasianwidth)       or "",
            standardizedvariants = textfiles.standardizedvariants ~= "" and io.loaddata(textfiles.standardizedvariants) or "",
            arabicshaping        = textfiles.arabicshaping        ~= "" and io.loaddata(textfiles.arabicshaping)        or "",
            index                = textfiles.index                ~= "" and io.loaddata(textfiles.index)                or "",
        }
        texttables = {
            unicodedata          = splitdefinition(textdata.unicodedata,true),
            bidimirroring        = splitdefinition(textdata.bidimirroring,true),
            linebreak            = splitdefinition(textdata.linebreak,true),
            eastasianwidth       = splitdefinition(textdata.eastasianwidth,true),
            standardizedvariants = splitdefinition(textdata.standardizedvariants,false),
            arabicshaping        = splitdefinition(textdata.arabicshaping,true),
            index                = splitindex(textdata.index),
        }
        return true
    else
        preamble = nil
        return false
    end
end

-- local variants_emoji={
--   [0xFE0E]="text style",
--   [0xFE0F]="emoji style",
-- }
--
-- local variants_forms={
--    [0xFE00]="corner-justified form",
--    [0xFE01]="centered form",
-- }

function scripts.unicode.save(filename)
    if preamble then
        local data = table.serialize(characters.data,"characters.data", { hexify = true, noquotes = true })
        data = gsub(data,"%{%s+%[0xFE0E%]=\"text style\",%s+%[0xFE0F%]=\"emoji style\",%s+%}","variants_emoji")
        data = gsub(data,"%{%s+%[0xFE00%]=\"corner%-justified form\",%s+%[0xFE01%]=\"centered form\",%s+%}","variants_forms")
        io.savedata(filename,preamble .. data)
    end
end

function scripts.unicode.extras() -- old code
    --
    -- 0000..007F; Basic Latin
    -- 0080..00FF; Latin-1 Supplement
    -- 0100..017F; Latin Extended-A
    --
    local fullname = resolvers.findfile("blocks.txt") or ""
    if fullname ~= "" then
        local data   = io.loaddata(fullname)
        local lines  = splitlines(data)
        local map    = { }
        local blocks = characters.blocks
        local result = { }
        for i=1,#lines do
            local line = gsub(lines[i]," *#.*$","")
            if line ~= "" then
                local specification = lpegmatch(split_colon_table,line) -- split(s,";")
                local range         = specification[1]
                local description   = specification[2]
                if range and description then
                    local start, stop = lpegmatch(split_range_two,range)
                    if start and stop then
                        local start = tonumber(start,16)
                        local stop  = tonumber(stop,16)
                        local name  = gsub(lower(description),"[^a-z]+","")
                        if start and stop then
                            local b = blocks[name]
                            if not b then
                                result[#result+1] = formatters[ [[+ block: ["%s"] = { first = 0x%05X, last = 0x%05X, description = "%S" }]] ](name,start,stop,description)
                                blocks[name] = { first = start, last = stop, description = description }
                            elseif b.first ~= start or b.last ~= stop or b.description ~= description then
                                result[#result+1] = formatters[ [[? block: ["%s"] = { first = 0x%05X, last = 0x%05X, description = "%S" }]] ](name,start,stop,description)
                            end
                        end
                        map[#map+1] = name
                    end
                end
            end
        end
        sort(result)
        for i=1,#result do
            report(result[i])
        end
        sort(map)
        for i=1,#map do
            local m = map[i]
            if not blocks[m] then
                report("obsolete block %a",m)
            end
        end
    end
    --
    local index  = texttables.index
    local blocks = characters.blocks
    local data   = characters.data
    for k, v in next, index do
        if k ~= lower(k) then
            index[k] = nil
        end
    end
 -- for k, v in next, data do
 --     v.synonym  = nil
 --     v.synonyms = nil
 -- end
    for k, v in table.sortedhash(index) do
        local d = data[v]
        if d and d.description ~= upper(k) then
            local synonyms = d.synonyms
            if synonyms then
                local n = #synonyms
                local f = false
                for i=1,n do
                    if synonyms[i] == k then
                        f = true
                        break
                    end
                end
                if not f then
                    synonyms[n+1] = k
                end
             -- synonyms = table.unique(synonyms)
             -- d.synonyms = synonyms
                sort(synonyms)
            else
                d.synonyms = { k }
            end
        end
    end
end

do

    local space       = P(" ")
    local spaces      = space^0
    local semicolon   = P(";")
    local hash        = P("#")
    local newline     = S("\n\r")

    local unicode     = Cs(R("09","AF")^1)/function(n) return tonumber(n,16) end
                      * spaces
    local components  = Ct (unicode^1)

 -- local rubish_a    = semicolon
 --                   * spaces
 --                   * P("Emoji_ZWJ_Sequence")
 --                   * spaces
 --                   * semicolon
 --                   * spaces
 -- local description = C((1 - (spaces * (hash+newline)))^1)
 -- local rubish_b    = (1-newline)^0
 --                   * newline^1
 --
 -- local pattern_1   = Ct ( (
 --     Cf ( Ct("") *
 --         Cg (Cc("components") * components)
 --       * rubish_a
 --       * Cg (Cc("description") * description )
 --       * rubish_b
 --     , rawset)
 --     + P(1) )^1 )

    local rubish_a    = semicolon
                      * spaces
                      * P("non-")^0 * P("fully-qualified")
                      * spaces
                      * hash
                      * spaces
    local textstring  = C((1 - space)^1)
                      * spaces
    local description = ((1 - (spaces * newline))^1) / string.lower
    local rubish_b    = (1-newline)^0
                      * newline^1

    local pattern_2   = Ct ( (
        Cf ( Ct("") *
            Cg (Cc("components") * components)
          * rubish_a
          * Cg (Cc("textstring") * textstring)
          * Cg (Cc("description") * description )
          * rubish_b
        , rawset)
        + P(1) )^1 )

    function scripts.unicode.emoji(filename)

        local name = resolvers.findfile("emoji-test.txt") or ""
        if name == "" then
            return
        end
        local l = io.loaddata(name)
        local t = lpegmatch(pattern_2,l)

        local hash = { }

        local replace = lpeg.replacer {
            ["#"] = "hash",
            ["*"] = "asterisk"
        }

        for i=1,#t do
            local v = t[i]
            local d = v.description
            local k = lpegmatch(replace,d) or d
            hash[k] = v.components
        end
        local new = table.serialize(hash,"return", { hexify = true })
        local old = io.loaddata(resolvers.findfile("char-emj.lua"))
        if old and old ~= "" then
            new = gsub(old,"^(.-)return .*$","%1" .. new)
        end
        io.savedata(filename,new)
    end

end

-- the action

local filename = environment.files[1]

if environment.arguments.exporthelp then
    application.export(environment.arguments.exporthelp,filename)
else
    report("start working on %a, input char-def.lua",lfs.currentdir())
    if scripts.unicode.load() then
        scripts.unicode.update()
        scripts.unicode.extras()
        scripts.unicode.save("char-def-new.lua")
        scripts.unicode.emoji("char-emj-new.lua")
        report("saved file %a","char-def-new.lua")
        report("saved file %a (current 12.0, check for updates, see above!)","char-emj-new.lua")
    else
        report("nothing to do")
    end
    report("stop working on %a\n",lfs.currentdir())
end
