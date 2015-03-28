if not modules then modules = { } end modules ['math-act'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we tweak some font properties (if needed).

local type, next = type, next
local fastcopy = table.fastcopy
local formatters = string.formatters

local trace_defining   = false  trackers.register("math.defining",   function(v) trace_defining   = v end)
local trace_collecting = false  trackers.register("math.collecting", function(v) trace_collecting = v end)

local report_math      = logs.reporter("mathematics","initializing")

local context          = context
local commands         = commands
local mathematics      = mathematics
local texsetdimen      = tex.setdimen
local abs              = math.abs

local sequencers       = utilities.sequencers
local appendgroup      = sequencers.appendgroup
local appendaction     = sequencers.appendaction

local fontchars        = fonts.hashes.characters

local mathfontparameteractions = sequencers.new {
    name      = "mathparameters",
    arguments = "target,original",
}

appendgroup("mathparameters","before") -- user
appendgroup("mathparameters","system") -- private
appendgroup("mathparameters","after" ) -- user

function fonts.constructors.assignmathparameters(original,target)
    local runner = mathfontparameteractions.runner
    if runner then
        runner(original,target)
    end
end

function mathematics.initializeparameters(target,original)
    local mathparameters = original.mathparameters
    if mathparameters and next(mathparameters) then
        target.mathparameters = mathematics.dimensions(mathparameters)
    end
end

sequencers.appendaction("mathparameters","system","mathematics.initializeparameters")

local how = {
 -- RadicalKernBeforeDegree         = "horizontal",
 -- RadicalKernAfterDegree          = "horizontal",
    ScriptPercentScaleDown          = "unscaled",
    ScriptScriptPercentScaleDown    = "unscaled",
    RadicalDegreeBottomRaisePercent = "unscaled"
}

function mathematics.scaleparameters(target,original)
    if not target.properties.math_is_scaled then
        local mathparameters = target.mathparameters
        if mathparameters and next(mathparameters) then
            local parameters = target.parameters
            local factor  = parameters.factor
            local hfactor = parameters.hfactor
            local vfactor = parameters.vfactor
            for name, value in next, mathparameters do
                local h = how[name]
                if h == "unscaled" then
                    -- kept
                elseif h == "horizontal" then
                    value = value * hfactor
                elseif h == "vertical"then
                    value = value * vfactor
                else
                    value = value * factor
                end
               mathparameters[name] = value
            end
        end
        target.properties.math_is_scaled = true
    end
end

sequencers.appendaction("mathparameters","system","mathematics.scaleparameters")

function mathematics.checkaccentbaseheight(target,original)
    local mathparameters = target.mathparameters
    if mathparameters and mathparameters.AccentBaseHeight == 0 then
        mathparameters.AccentBaseHeight = target.parameters.x_height -- needs checking
    end
end

sequencers.appendaction("mathparameters","system","mathematics.checkaccentbaseheight") -- should go in lfg instead

function mathematics.checkprivateparameters(target,original)
    local mathparameters = target.mathparameters
    if mathparameters then
        local parameters = target.parameters
        local properties = target.properties
        if parameters then
            local size = parameters.size
            if size then
                if not mathparameters.FractionDelimiterSize then
                    mathparameters.FractionDelimiterSize = 1.01 * size
                end
                if not mathparameters.FractionDelimiterDisplayStyleSize then
                    mathparameters.FractionDelimiterDisplayStyleSize = 2.40 * size
                end
            elseif properties then
                report_math("invalid parameters in font %a",properties.fullname or "?")
            else
                report_math("invalid parameters in font")
            end
        elseif properties then
            report_math("no parameters in font %a",properties.fullname or "?")
        else
            report_math("no parameters and properties in font")
        end
    end
end

sequencers.appendaction("mathparameters","system","mathematics.checkprivateparameters")

function mathematics.overloadparameters(target,original)
    local mathparameters = target.mathparameters
    if mathparameters and next(mathparameters) then
        local goodies = target.goodies
        if goodies then
            for i=1,#goodies do
                local goodie = goodies[i]
                local mathematics = goodie.mathematics
                local parameters  = mathematics and mathematics.parameters
                if parameters then
                    if trace_defining then
                        report_math("overloading math parameters in %a @ %p",target.properties.fullname,target.parameters.size)
                    end
                    for name, value in next, parameters do
                        local tvalue = type(value)
                        if tvalue == "string" then
                            report_math("comment for math parameter %a: %s",name,value)
                        else
                            local oldvalue = mathparameters[name]
                            local newvalue = oldvalue
                            if oldvalue then
                                if tvalue == "number" then
                                    newvalue = value
                                elseif tvalue == "function" then
                                    newvalue = value(oldvalue,target,original)
                                elseif not tvalue then
                                    newvalue = nil
                                end
                                if trace_defining and oldvalue ~= newvalue then
                                    report_math("overloading math parameter %a: %S => %S",name,oldvalue,newvalue)
                                end
                            else
                                report_math("invalid math parameter %a",name)
                            end
                            mathparameters[name] = newvalue
                        end
                    end
                end
            end
        end
    end
end

sequencers.appendaction("mathparameters","system","mathematics.overloadparameters")

local function applytweaks(when,target,original)
    local goodies = original.goodies
    if goodies then
        for i=1,#goodies do
            local goodie = goodies[i]
            local mathematics = goodie.mathematics
            local tweaks = mathematics and mathematics.tweaks
            if tweaks then
                tweaks = tweaks[when]
                if tweaks then
                    if trace_defining then
                        report_math("tweaking math of %a @ %p (%s)",target.properties.fullname,target.parameters.size,when)
                    end
                    for i=1,#tweaks do
                        local tweak= tweaks[i]
                        local tvalue = type(tweak)
                        if tvalue == "function" then
                            tweak(target,original)
                        end
                    end
                end
            end
        end
    end
end

function mathematics.tweakbeforecopyingfont(target,original)
    local mathparameters = target.mathparameters -- why not hasmath
    if mathparameters then
        applytweaks("beforecopying",target,original)
    end
end

function mathematics.tweakaftercopyingfont(target,original)
    local mathparameters = target.mathparameters -- why not hasmath
    if mathparameters then
        applytweaks("aftercopying",target,original)
    end
end

sequencers.appendaction("beforecopyingcharacters","system","mathematics.tweakbeforecopyingfont")
sequencers.appendaction("aftercopyingcharacters", "system","mathematics.tweakaftercopyingfont")

function mathematics.overloaddimensions(target,original,set)
    local goodies = target.goodies
    if goodies then
        for i=1,#goodies do
            local goodie = goodies[i]
            local mathematics = goodie.mathematics
            local dimensions  = mathematics and mathematics.dimensions
            if dimensions then
                if trace_defining then
                    report_math("overloading dimensions in %a @ %p",target.properties.fullname,target.parameters.size)
                end
                local characters = target.characters
                local parameters = target.parameters
                local factor     = parameters.factor
                local hfactor    = parameters.hfactor
                local vfactor    = parameters.vfactor
                local addprivate = fonts.helpers.addprivate
                local function overload(dimensions)
                    for unicode, data in next, dimensions do
                        local character = characters[unicode]
                        if character then
                            --
                            local width  = data.width
                            local height = data.height
                            local depth  = data.depth
                            if trace_defining and (width or height or depth) then
                                report_math("overloading dimensions of %C, width %a, height %a, depth %a",unicode,width,height,depth)
                            end
                            if width   then character.width  = width  * hfactor end
                            if height  then character.height = height * vfactor end
                            if depth   then character.depth  = depth  * vfactor end
                            --
                            local xoffset = data.xoffset
                            local yoffset = data.yoffset
                            if xoffset then
                                xoffset = { "right", xoffset * hfactor }
                            end
                            if yoffset then
                                yoffset = { "down", -yoffset * vfactor }
                            end
                            if xoffset or yoffset then
                                local slot = { "slot", 1, addprivate(target,nil,fastcopy(character)) }
                                if xoffset and yoffset then
                                    character.commands = { xoffset, yoffset, slot }
                                elseif xoffset then
                                    character.commands = { xoffset, slot }
                                else
                                    character.commands = { yoffset, slot }
                                end
                                character.index = nil
                            end
                        elseif trace_defining then
                            report_math("no overloading dimensions of %C, not in font",unicode)
                        end
                    end
                end
                if set == nil then
                    set = { "default" }
                end
                if set == "all" or set == true then
                    for name, set in next, dimensions do
                        overload(set)
                    end
                else
                    if type(set) == "string" then
                        set = utilities.parsers.settings_to_array(set)
                    end
                    if type(set) == "table" then
                        for i=1,#set do
                            local d = dimensions[set[i]]
                            if d then
                                overload(d)
                            end
                        end
                    end
                end
            end
        end
    end
end

sequencers.appendaction("aftercopyingcharacters", "system","mathematics.overloaddimensions")

-- a couple of predefined tweaks:

local tweaks       = { }
mathematics.tweaks = tweaks

-- function tweaks.fixbadprime(target,original)
--     target.characters[0xFE325] = target.characters[0x2032]
-- end

-- these could go to math-fbk

-- local function accent_to_extensible(target,newchr,original,oldchr,height,depth,swap)
--     local characters = target.characters
--  -- if not characters[newchr] then -- xits needs an enforce
--     local addprivate = fonts.helpers.addprivate
--         local olddata = characters[oldchr]
--         if olddata then
--             if swap then
--                 swap = characters[swap]
--                 height = swap.depth
--                 depth  = 0
--             else
--                 height = height or 0
--                 depth  = depth  or 0
--             end
--             local correction = swap and { "down", (olddata.height or 0) - height } or { "down", olddata.height }
--             local newdata = {
--                 commands = { correction, { "slot", 1, oldchr } },
--                 width    = olddata.width,
--                 height   = height,
--                 depth    = depth,
--             }
--             characters[newchr] = newdata
--             local nextglyph = olddata.next
--             while nextglyph do
--                 local oldnextdata = characters[nextglyph]
--                 local newnextdata = {
--                     commands = { correction, { "slot", 1, nextglyph } },
--                     width    = oldnextdata.width,
--                     height   = height,
--                     depth    = depth,
--                 }
--                 local newnextglyph = addprivate(target,formatters["original-%H"](nextglyph),newnextdata)
--                 newdata.next = newnextglyph
--                 local nextnextglyph = oldnextdata.next
--                 if nextnextglyph == nextglyph then
--                     break
--                 else
--                     olddata   = oldnextdata
--                     newdata   = newnextdata
--                     nextglyph = nextnextglyph
--                 end
--             end
--             local hv = olddata.horiz_variants
--             if hv then
--                 hv = fastcopy(hv)
--                 newdata.horiz_variants = hv
--                 for i=1,#hv do
--                     local hvi = hv[i]
--                     local oldglyph = hvi.glyph
--                     local olddata = characters[oldglyph]
--                     local newdata = {
--                         commands = { correction, { "slot", 1, oldglyph } },
--                         width    = olddata.width,
--                         height   = height,
--                         depth    = depth,
--                     }
--                     hvi.glyph = addprivate(target,formatters["original-%H"](oldglyph),newdata)
--                 end
--             end
--         end
--  -- end
-- end

-- function tweaks.fixoverline(target,original)
--     local height, depth = 0, 0
--     local mathparameters = target.mathparameters
--     if mathparameters then
--         height = mathparameters.OverbarVerticalGap
--         depth  = mathparameters.UnderbarVerticalGap
--     else
--         height = target.parameters.xheight/4
--         depth  = height
--     end
--     accent_to_extensible(target,0x203E,original,0x0305,height,depth)
--     -- also crappy spacing for our purpose: push to top of baseline
--     accent_to_extensible(target,0xFE3DE,original,0x23DE,height,depth,0x23DF)
--     accent_to_extensible(target,0xFE3DC,original,0x23DC,height,depth,0x23DD)
--     accent_to_extensible(target,0xFE3B4,original,0x23B4,height,depth,0x23B5)
--     -- for symmetry
--     target.characters[0xFE3DF] = original.characters[0x23DF]
--     target.characters[0xFE3DD] = original.characters[0x23DD]
--     target.characters[0xFE3B5] = original.characters[0x23B5]
--  -- inspect(fonts.helpers.expandglyph(target.characters,0x203E))
--  -- inspect(fonts.helpers.expandglyph(target.characters,0x23DE))
-- end

-- sequencers.appendaction("aftercopyingcharacters", "system","mathematics.tweaks.fixoverline") -- for the moment always

-- helpers

local setmetatableindex  = table.setmetatableindex
local family_font        = node.family_font

local fontcharacters     = fonts.hashes.characters
local fontdescriptions   = fonts.hashes.descriptions
local extensibles        = utilities.storage.allocate()
fonts.hashes.extensibles = extensibles

local chardata           = characters.data
local extensibles        = mathematics.extensibles

-- we use numbers at the tex end (otherwise we could stick to chars)

local e_left       = extensibles.left
local e_right      = extensibles.right
local e_horizontal = extensibles.horizontal
local e_vertical   = extensibles.vertical
local e_mixed      = extensibles.mixed
local e_unknown    = extensibles.unknown

local unknown      = { e_unknown, false, false }

local function extensiblecode(font,unicode)
    local characters = fontcharacters[font]
    local character = characters[unicode]
    if not character then
        return unknown
    end
    local first = character.next
    local code = unicode
    local next = first
    while next do
        code = next
        character = characters[next]
        next = character.next
    end
    local char = chardata[unicode]
    if not char then
        return unknown
    end
    if character.horiz_variants then
        if character.vert_variants then
            return { e_mixed, code, character }
        else
            local m = char.mathextensible
            local e = m and extensibles[m]
            return e and { e, code, character } or unknown
        end
    elseif character.vert_variants then
        local m = char.mathextensible
        local e = m and extensibles[m]
        return e and { e, code, character } or unknown
    elseif first then
        -- assume accent (they seldom stretch .. sizes)
        local m = char.mathextensible or char.mathstretch
        local e = m and extensibles[m]
        return e and { e, code, character } or unknown
    else
        return unknown
    end
end

setmetatableindex(extensibles,function(extensibles,font)
    local codes = { }
    setmetatableindex(codes, function(codes,unicode)
        local status = extensiblecode(font,unicode)
        codes[unicode] = status
        return status
    end)
    extensibles[font] = codes
    return codes
end)

local function extensiblecode(family,unicode)
    return extensibles[family_font(family or 0)][unicode][1]
end

-- left       : [head] ...
-- right      : ... [head]
-- horizontal : [head] ... [head]
--
-- abs(right["start"] - right["end"]) | right.advance | characters[right.glyph].width

local function horizontalcode(family,unicode)
    local font    = family_font(family or 0)
    local data    = extensibles[font][unicode]
    local kind    = data[1]
    local loffset = 0
    local roffset = 0
    if kind == e_left then
        local charlist = data[3].horiz_variants
        if charlist then
            local left = charlist[1]
            loffset = abs((left["start"] or 0) - (left["end"] or 0))
        end
    elseif kind == e_right then
        local charlist = data[3].horiz_variants
        local right = charlist[#charlist]
        roffset = abs((right["start"] or 0) - (right["end"] or 0))
     elseif kind == e_horizontal then
        local charlist = data[3].horiz_variants
        if charlist then
            local left = charlist[1]
            local right = charlist[#charlist]
            loffset = abs((left ["start"] or 0) - (left ["end"] or 0))
            roffset = abs((right["start"] or 0) - (right["end"] or 0))
        end
    end
    return kind, loffset, roffset
end

mathematics.extensiblecode = extensiblecode
mathematics.horizontalcode = horizontalcode

interfaces.implement {
    name      = "extensiblecode",
    arguments = { "integer", "integer" },
    actions   = { extensiblecode, context }
}

interfaces.implement {
    name      = "horizontalcode",
    arguments = { "integer", "integer" },
    actions   = function(family,unicode)
        local kind, loffset, roffset = horizontalcode(family,unicode)
        texsetdimen("scratchleftoffset", loffset)
        texsetdimen("scratchrightoffset",roffset)
        context(kind)
    end
}

-- experiment

-- check: when true, only set when present in font
-- force: when false, then not set when already set

local blocks = characters.blocks -- this will move to char-ini

blocks["uppercasenormal"]                     = { first = 0x00041, last = 0x0005A }
blocks["uppercasebold"]                       = { first = 0x1D400, last = 0x1D419 }
blocks["uppercaseitalic"]                     = { first = 0x1D434, last = 0x1D44D }
blocks["uppercasebolditalic"]                 = { first = 0x1D468, last = 0x1D481 }
blocks["uppercasescript"]                     = { first = 0x1D49C, last = 0x1D4B5 }
blocks["uppercaseboldscript"]                 = { first = 0x1D4D0, last = 0x1D4E9 }
blocks["uppercasefraktur"]                    = { first = 0x1D504, last = 0x1D51D }
blocks["uppercasedoublestruck"]               = { first = 0x1D538, last = 0x1D551 }
blocks["uppercaseboldfraktur"]                = { first = 0x1D56C, last = 0x1D585 }
blocks["uppercasesansserifnormal"]            = { first = 0x1D5A0, last = 0x1D5B9 }
blocks["uppercasesansserifbold"]              = { first = 0x1D5D4, last = 0x1D5ED }
blocks["uppercasesansserifitalic"]            = { first = 0x1D608, last = 0x1D621 }
blocks["uppercasesansserifbolditalic"]        = { first = 0x1D63C, last = 0x1D655 }
blocks["uppercasemonospace"]                  = { first = 0x1D670, last = 0x1D689 }
blocks["uppercasegreeknormal"]                = { first = 0x00391, last = 0x003AA }
blocks["uppercasegreekbold"]                  = { first = 0x1D6A8, last = 0x1D6C1 }
blocks["uppercasegreekitalic"]                = { first = 0x1D6E2, last = 0x1D6FB }
blocks["uppercasegreekbolditalic"]            = { first = 0x1D71C, last = 0x1D735 }
blocks["uppercasegreeksansserifbold"]         = { first = 0x1D756, last = 0x1D76F }
blocks["uppercasegreeksansserifbolditalic"]   = { first = 0x1D790, last = 0x1D7A9 }

blocks["lowercasenormal"]                     = { first = 0x00061, last = 0x0007A }
blocks["lowercasebold"]                       = { first = 0x1D41A, last = 0x1D433 }
blocks["lowercaseitalic"]                     = { first = 0x1D44E, last = 0x1D467 }
blocks["lowercasebolditalic"]                 = { first = 0x1D482, last = 0x1D49B }
blocks["lowercasescript"]                     = { first = 0x1D4B6, last = 0x1D4CF }
blocks["lowercaseboldscript"]                 = { first = 0x1D4EA, last = 0x1D503 }
blocks["lowercasefraktur"]                    = { first = 0x1D51E, last = 0x1D537 }
blocks["lowercasedoublestruck"]               = { first = 0x1D552, last = 0x1D56B }
blocks["lowercaseboldfraktur"]                = { first = 0x1D586, last = 0x1D59F }
blocks["lowercasesansserifnormal"]            = { first = 0x1D5BA, last = 0x1D5D3 }
blocks["lowercasesansserifbold"]              = { first = 0x1D5EE, last = 0x1D607 }
blocks["lowercasesansserifitalic"]            = { first = 0x1D622, last = 0x1D63B }
blocks["lowercasesansserifbolditalic"]        = { first = 0x1D656, last = 0x1D66F }
blocks["lowercasemonospace"]                  = { first = 0x1D68A, last = 0x1D6A3 }
blocks["lowercasegreeknormal"]                = { first = 0x003B1, last = 0x003CA }
blocks["lowercasegreekbold"]                  = { first = 0x1D6C2, last = 0x1D6DB }
blocks["lowercasegreekitalic"]                = { first = 0x1D6FC, last = 0x1D715 }
blocks["lowercasegreekbolditalic"]            = { first = 0x1D736, last = 0x1D74F }
blocks["lowercasegreeksansserifbold"]         = { first = 0x1D770, last = 0x1D789 }
blocks["lowercasegreeksansserifbolditalic"]   = { first = 0x1D7AA, last = 0x1D7C3 }

blocks["digitsnormal"]                        = { first = 0x00030, last = 0x00039 }
blocks["digitsbold"]                          = { first = 0x1D7CE, last = 0x1D7D8 }
blocks["digitsdoublestruck"]                  = { first = 0x1D7D8, last = 0x1D7E2 }
blocks["digitssansserifnormal"]               = { first = 0x1D7E2, last = 0x1D7EC }
blocks["digitssansserifbold"]                 = { first = 0x1D7EC, last = 0x1D805 }
blocks["digitsmonospace"]                     = { first = 0x1D7F6, last = 0x1D80F }

blocks["mathematicaloperators"]               = { first = 0x02200, last = 0x022FF }
blocks["miscellaneousmathematicalsymbolsa"]   = { first = 0x027C0, last = 0x027EF }
blocks["miscellaneousmathematicalsymbolsb"]   = { first = 0x02980, last = 0x029FF }
blocks["supplementalmathematicaloperators"]   = { first = 0x02A00, last = 0x02AFF }
blocks["letterlikesymbols"]                   = { first = 0x02100, last = 0x0214F }
blocks["miscellaneoustechnical"]              = { first = 0x02308, last = 0x0230B }
blocks["geometricshapes"]                     = { first = 0x025A0, last = 0x025FF }
blocks["miscellaneoussymbolsandarrows"]       = { first = 0x02B30, last = 0x02B4C }
blocks["mathematicalalphanumericsymbols"]     = { first = 0x00400, last = 0x1D7FF }

blocks["digitslatin"]                         = { first = 0x00030, last = 0x00039 }
blocks["digitsarabicindic"]                   = { first = 0x00660, last = 0x00669 }
blocks["digitsextendedarabicindic"]           = { first = 0x006F0, last = 0x006F9 }
------["digitsdevanagari"]                    = { first = 0x00966, last = 0x0096F }
------["digitsbengali"]                       = { first = 0x009E6, last = 0x009EF }
------["digitsgurmukhi"]                      = { first = 0x00A66, last = 0x00A6F }
------["digitsgujarati"]                      = { first = 0x00AE6, last = 0x00AEF }
------["digitsoriya"]                         = { first = 0x00B66, last = 0x00B6F }
------["digitstamil"]                         = { first = 0x00030, last = 0x00039 } -- no zero
------["digitstelugu"]                        = { first = 0x00C66, last = 0x00C6F }
------["digitskannada"]                       = { first = 0x00CE6, last = 0x00CEF }
------["digitsmalayalam"]                     = { first = 0x00D66, last = 0x00D6F }
------["digitsthai"]                          = { first = 0x00E50, last = 0x00E59 }
------["digitslao"]                           = { first = 0x00ED0, last = 0x00ED9 }
------["digitstibetan"]                       = { first = 0x00F20, last = 0x00F29 }
------["digitsmyanmar"]                       = { first = 0x01040, last = 0x01049 }
------["digitsethiopic"]                      = { first = 0x01369, last = 0x01371 }
------["digitskhmer"]                         = { first = 0x017E0, last = 0x017E9 }
------["digitsmongolian"]                     = { first = 0x01810, last = 0x01809 }

-- operators    : 0x02200
-- symbolsa     : 0x02701
-- symbolsb     : 0x02901
-- supplemental : 0x02A00

-- from mathematics.gaps:

blocks["lowercaseitalic"].gaps = {
    [0x1D455] = 0x0210E, -- ℎ h
}

blocks["uppercasescript"].gaps = {
    [0x1D49D] = 0x0212C, -- ℬ script B
    [0x1D4A0] = 0x02130, -- ℰ script E
    [0x1D4A1] = 0x02131, -- ℱ script F
    [0x1D4A3] = 0x0210B, -- ℋ script H
    [0x1D4A4] = 0x02110, -- ℐ script I
    [0x1D4A7] = 0x02112, -- ℒ script L
    [0x1D4A8] = 0x02133, -- ℳ script M
    [0x1D4AD] = 0x0211B, -- ℛ script R
}

blocks["lowercasescript"].gaps = {
    [0x1D4BA] = 0x0212F, -- ℯ script e
    [0x1D4BC] = 0x0210A, -- ℊ script g
    [0x1D4C4] = 0x02134, -- ℴ script o
}

blocks["uppercasefraktur"].gaps = {
    [0x1D506] = 0x0212D, -- ℭ fraktur C
    [0x1D50B] = 0x0210C, -- ℌ fraktur H
    [0x1D50C] = 0x02111, -- ℑ fraktur I
    [0x1D515] = 0x0211C, -- ℜ fraktur R
    [0x1D51D] = 0x02128, -- ℨ fraktur Z
}

blocks["uppercasedoublestruck"].gaps = {
    [0x1D53A] = 0x02102, -- ℂ bb C
    [0x1D53F] = 0x0210D, -- ℍ bb H
    [0x1D545] = 0x02115, -- ℕ bb N
    [0x1D547] = 0x02119, -- ℙ bb P
    [0x1D548] = 0x0211A, -- ℚ bb Q
    [0x1D549] = 0x0211D, -- ℝ bb R
    [0x1D551] = 0x02124, -- ℤ bb Z
}

-- todo: tounicode

function mathematics.injectfallbacks(target,original)
    local properties = original.properties
    if properties and properties.hasmath then
        local specification = target.specification
        if specification then
            local fallbacks = specification.fallbacks
            if fallbacks then
                local definitions = fonts.collections.definitions[fallbacks]
                if definitions then
                    if trace_collecting then
                        report_math("adding fallback characters to font %a",specification.hash)
                    end
                    local definedfont = fonts.definers.internal
                    local copiedglyph = fonts.handlers.vf.math.copy_glyph
                    local fonts       = target.fonts
                    local size        = specification.size -- target.size
                    local characters  = target.characters
                    if not fonts then
                        fonts = { }
                        target.fonts = fonts
                        target.type = "virtual"
                        target.properties.virtualized = true
                    end
                    if #fonts == 0 then
                        fonts[1] = { id = 0, size = size } -- sel, will be resolved later
                    end
                    local done = { }
                    for i=1,#definitions do
                        local definition = definitions[i]
                        local name   = definition.font
                        local start  = definition.start
                        local stop   = definition.stop
                        local gaps   = definition.gaps
                        local check  = definition.check
                        local force  = definition.force
                        local rscale = definition.rscale or 1
                        local offset = definition.offset or start
                        local id     = definedfont { name = name, size = size * rscale }
                        local index  = #fonts + 1
                        fonts[index] = { id = id, size = size }
                        local chars  = fontchars[id]
                        local function remap(unic,unicode,gap)
                            local unic = unicode + offset - start
                            if check and not chars[unicode] then
                                -- not in font
                            elseif force or (not done[unic] and not characters[unic]) then
                                if trace_collecting then
                                    report_math("remapping math character, vector %a, font %a, character %C%s%s",
                                        fallbacks,name,unic,check and ", checked",gap and ", gap plugged")
                                end
                                characters[unic] = copiedglyph(target,characters,chars,unicode,index)
                                done[unic] = true
                            end
                        end
                        for unicode = start, stop do
                            local unic = unicode + offset - start
                            remap(unic,unicode,false)
                        end
                        if gaps then
                            for unic, unicode in next, gaps do
                                remap(unic,unicode,true)
                            end
                        end
                    end
                end
            end
        end
    end
end

sequencers.appendaction("aftercopyingcharacters", "system","mathematics.injectfallbacks")
