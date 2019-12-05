if not modules then modules = { } end modules ['math-act'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we tweak some font properties (if needed).

local type, next = type, next
local fastcopy, insert, remove = table.fastcopy, table.insert, table.remove
local formatters = string.formatters

local trace_defining   = false  trackers.register("math.defining",   function(v) trace_defining   = v end)
local trace_collecting = false  trackers.register("math.collecting", function(v) trace_collecting = v end)

local report_math      = logs.reporter("mathematics","initializing")

local context          = context
local commands         = commands
local mathematics      = mathematics
local texsetdimen      = tex.setdimen
local abs              = math.abs

local helpers          = fonts.helpers
local upcommand        = helpers.commands.up
local rightcommand     = helpers.commands.right
local charcommand      = helpers.commands.char
local prependcommands  = helpers.prependcommands

local sequencers       = utilities.sequencers
local appendgroup      = sequencers.appendgroup
local appendaction     = sequencers.appendaction

local fontchars        = fonts.hashes.characters
local fontproperties   = fonts.hashes.properties

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
    RadicalDegreeBottomRaisePercent = "unscaled",
    NoLimitSupFactor                = "unscaled",
    NoLimitSubFactor                = "unscaled",
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

-- AccentBaseHeight vs FlattenedAccentBaseHeight

function mathematics.checkaccentbaseheight(target,original)
    local mathparameters = target.mathparameters
    if mathparameters and mathparameters.AccentBaseHeight == 0 then
        mathparameters.AccentBaseHeight = target.parameters.x_height -- needs checking
    end
end

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

local function applytweaks(when,target,original)
    local goodies = original.goodies
    if goodies then
        for i=1,#goodies do
            local goodie = goodies[i]
            local mathematics = goodie.mathematics
            local tweaks = mathematics and mathematics.tweaks
            if type(tweaks) == "table" then
                tweaks = tweaks[when]
                if type(tweaks) == "table" then
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

sequencers.appendaction("mathparameters","system","mathematics.scaleparameters")
sequencers.appendaction("mathparameters","system","mathematics.checkaccentbaseheight")  -- should go in lfg instead
sequencers.appendaction("mathparameters","system","mathematics.checkprivateparameters") -- after scaling !
sequencers.appendaction("mathparameters","system","mathematics.overloadparameters")

sequencers.appendaction("beforecopyingcharacters","system","mathematics.tweakbeforecopyingfont")
sequencers.appendaction("aftercopyingcharacters", "system","mathematics.tweakaftercopyingfont")

local virtualized = mathematics.virtualized

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
                local characters   = target.characters
                local descriptions = target.descriptions
                local parameters   = target.parameters
                local factor       = parameters.factor
                local hfactor      = parameters.hfactor
                local vfactor      = parameters.vfactor
                -- to be sure
                target.type = "virtual"
                target.properties.virtualized = true
                --
                local function overload(dimensions)
                    for unicode, data in next, dimensions do
                        local character = characters[unicode]
                        if not character then
                            local c = virtualized[unicode]
                            if c then
                                character = characters[c]
                            end
                        end
                        if character then
                            --
                            local width  = data.width
                            local height = data.height
                            local depth  = data.depth
                            if trace_defining and (width or height or depth) then
                                report_math("overloading dimensions of %C, width %p, height %p, depth %p",
                                    unicode,width or 0,height or 0,depth or 0)
                            end
                            if width  then character.width  = width  * hfactor end
                            if height then character.height = height * vfactor end
                            if depth  then character.depth  = depth  * vfactor end
                            --
                            local xoffset = data.xoffset
                            local yoffset = data.yoffset
                            if xoffset == "llx" then
                                local d = descriptions[unicode]
                                if d then
                                    xoffset         = - d.boundingbox[1] * hfactor
                                    character.width = character.width + xoffset
                                    xoffset         = rightcommand[xoffset]
                                else
                                    xoffset = nil
                                end
                            elseif xoffset and xoffset ~= 0 then
                                xoffset = rightcommand[xoffset * hfactor]
                            else
                                xoffset = nil
                            end
                            if yoffset and yoffset ~= 0 then
                                yoffset = upcommand[yoffset * vfactor]
                            else
                                yoffset = nil
                            end
                            if xoffset or yoffset then
                                local commands = characters.commands
                                if commands then
                                    prependcommands(commands,yoffset,xoffset)
                                else
                                    local slot = charcommand[unicode]
                                    if xoffset and yoffset then
                                        character.commands = { xoffset, yoffset, slot }
                                    elseif xoffset then
                                        character.commands = { xoffset, slot }
                                    else
                                        character.commands = { yoffset, slot }
                                    end
                                end
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

-- no, it's a feature now (see good-mth):
--
-- sequencers.appendaction("aftercopyingcharacters", "system","mathematics.overloaddimensions")

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

local getfontoffamily    = tex.getfontoffamily

local fontcharacters     = fonts.hashes.characters
local extensibles        = utilities.storage.allocate()
fonts.hashes.extensibles = extensibles

local chardata           = characters.data
local extensibles        = mathematics.extensibles

-- we use numbers at the tex end (otherwise we could stick to chars)

local e_left       = extensibles.left
local e_right      = extensibles.right
local e_horizontal = extensibles.horizontal
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
    return extensibles[getfontoffamily(family or 0)][unicode][1]
end

-- left       : [head] ...
-- right      : ... [head]
-- horizontal : [head] ... [head]
--
-- abs(right["start"] - right["end"]) | right.advance | characters[right.glyph].width

local function horizontalcode(family,unicode)
    local font    = getfontoffamily(family or 0)
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
        if charlist then
            local right = charlist[#charlist]
            roffset = abs((right["start"] or 0) - (right["end"] or 0))
        end
     elseif kind == e_horizontal then
        local charlist = data[3].horiz_variants
        if charlist then
            local left  = charlist[1]
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

-- todo: tounicode

-- function mathematics.injectfallbacks(target,original)
--     local properties = original.properties
--     if properties and properties.hasmath then
--         local specification = target.specification
--         if specification then
--             local fallbacks = specification.fallbacks
--             if fallbacks then
--                 local definitions = fonts.collections.definitions[fallbacks]
--                 if definitions then
--                     if trace_collecting then
--                         report_math("adding fallback characters to font %a",specification.hash)
--                     end
--                     local definedfont = fonts.definers.internal
--                     local copiedglyph = fonts.handlers.vf.math.copy_glyph
--                     local fonts       = target.fonts
--                     local size        = specification.size -- target.size
--                     local characters  = target.characters
--                     if not fonts then
--                         fonts = { }
--                         target.fonts = fonts
--                         target.type = "virtual"
--                         target.properties.virtualized = true
--                     end
--                     if #fonts == 0 then
--                         fonts[1] = { id = 0, size = size } -- sel, will be resolved later
--                     end
--                     local done = { }
--                     for i=1,#definitions do
--                         local definition = definitions[i]
--                         local name   = definition.font
--                         local start  = definition.start
--                         local stop   = definition.stop
--                         local gaps   = definition.gaps
--                         local check  = definition.check
--                         local force  = definition.force
--                         local rscale = definition.rscale or 1
--                         local offset = definition.offset or start
--                         local id     = definedfont { name = name, size = size * rscale }
--                         local index  = #fonts + 1
--                         fonts[index] = { id = id, size = size }
--                         local chars  = fontchars[id]
--                         local function remap(unic,unicode,gap)
--                          -- local unic = unicode + offset - start
--                             if check and not chars[unicode] then
--                                 -- not in font
--                             elseif force or (not done[unic] and not characters[unic]) then
--                                 if trace_collecting then
--                                     report_math("remapping math character, vector %a, font %a, character %C%s%s",
--                                         fallbacks,name,unic,check and ", checked",gap and ", gap plugged")
--                                 end
--                                 characters[unic] = copiedglyph(target,characters,chars,unicode,index)
--                                 done[unic] = true
--                             end
--                         end
--                         for unicode = start, stop do
--                             local unic = unicode + offset - start
--                             remap(unic,unicode,false)
--                         end
--                         if gaps then
--                             for unic, unicode in next, gaps do
--                                 remap(unic,unicode,true)
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- end
--
-- sequencers.appendaction("aftercopyingcharacters", "system","mathematics.finishfallbacks")

local stack = { }

function mathematics.registerfallbackid(n,id,name)
    if trace_collecting then
        report_math("resolved fallback font %i, name %a, id %a, used %a",
            n,name,id,fontproperties[id].fontname)
    end
    stack[#stack][n] = id
end

interfaces.implement { -- will be shared with text
    name      = "registerfontfallbackid",
    arguments = { "integer", "integer", "string" },
    actions   = mathematics.registerfallbackid,
}

function mathematics.resolvefallbacks(target,specification,fallbacks)
    local definitions = fonts.collections.definitions[fallbacks]
    if definitions then
        local size = specification.size -- target.size
        local list = { }
        insert(stack,list)
        context.pushcatcodes("prt") -- context.unprotect()
        for i=1,#definitions do
            local definition = definitions[i]
            local name       = definition.font
            local features   = definition.features or ""
            local size       = size * (definition.rscale or 1)
            context.font_fallbacks_register_math(i,name,features,size)
            if trace_collecting then
                report_math("registering fallback font %i, name %a, size %a, features %a",i,name,size,features)
            end
        end
        context.popcatcodes()
    end
end

function mathematics.finishfallbacks(target,specification,fallbacks)
    local list = remove(stack)
    if list and #list > 0 then
        local definitions = fonts.collections.definitions[fallbacks]
        if definitions and #definitions > 0 then
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
            end
            target.type = "virtual"
            target.properties.virtualized = true
            if #fonts == 0 then
                fonts[1] = { id = 0, size = size } -- self, will be resolved later
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
                local id     = list[i]
                if id then
                    local index  = #fonts + 1
                    fonts[index] = { id = id, size = size }
                    local chars  = fontchars[id]
                    local function remap(unic,unicode,gap)
                        if check and not chars[unicode] then
                            return
                        end
                        if force or (not done[unic] and not characters[unic]) then
                            if trace_collecting then
                                report_math("replacing math character %C by %C using vector %a and font id %a for %a%s%s",
                                    unic,unicode,fallbacks,id,fontproperties[id].fontname,check and ", checked",gap and ", gap plugged")
                            end
                            characters[unic] = copiedglyph(target,characters,chars,unicode,index)
                            done[unic] = true
                        end
                    end
                    local step = offset - start
                    for unicode = start, stop do
                        remap(unicode + step,unicode,false)
                    end
                    if gaps then
                        for unic, unicode in next, gaps do
                            remap(unic,unicode,true)
                            remap(unicode,unicode,true)
                        end
                    end
                end
            end
        elseif trace_collecting then
            report_math("no fallback characters added to font %a",specification.hash)
        end
    end
end
