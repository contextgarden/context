if not modules then modules = { } end modules ['math-act'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we tweak some font properties (if needed). Per mid octover 2022 we also provide
-- an lmtx emulation mode which means that we removed some other code. Some of that was
-- experimental, some transitional, some is now obsolete). Using emulation mode also
-- means that we are unlikely to test some aspects of the math engines extensively.

local type, next = type, next
local fastcopy, insert, remove, copytable = table.fastcopy, table.insert, table.remove, table.copy
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
        mathparameters = mathematics.dimensions(mathparameters)
        if not mathparameters.SpaceBeforeScript then
            mathparameters.SpaceBeforeScript = mathparameters.SpaceAfterScript
        end
        if not mathparameters.SubscriptShiftDownWithSuperscript then
            mathparameters.SubscriptShiftDownWithSuperscript = mathparameters.SubscriptShiftDown * 1.5
        end
        target.mathparameters = mathparameters
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

local function scaleparameters(mathparameters,parameters)
    if mathparameters and next(mathparameters) and parameters then
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
end

function mathematics.scaleparameters(target,original)
    if not target.properties.math_is_scaled then
        scaleparameters(target.mathparameters,target.parameters)
        target.properties.math_is_scaled = true
    end
end

-- -- AccentBaseHeight vs FlattenedAccentBaseHeight
--
-- function mathematics.checkaccentbaseheight(target,original)
--     local mathparameters = target.mathparameters
--     if mathparameters and mathparameters.AccentBaseHeight == 0 then
--         mathparameters.AccentBaseHeight = target.parameters.x_height -- needs checking
--     end
-- end

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
                 -- for name, value in next, parameters do
                 --     local tvalue = type(value)
                 --     if tvalue == "string" then
                 --         report_math("comment for math parameter %a: %s",name,value)
                 --     else
                 --         local oldvalue = mathparameters[name]
                 --         local newvalue = oldvalue
                 --         if oldvalue then
                 --             if tvalue == "number" then
                 --                 newvalue = value
                 --             elseif tvalue == "function" then
                 --                 newvalue = value(oldvalue,target,original)
                 --             elseif not tvalue then
                 --                 newvalue = nil
                 --             end
                 --             if trace_defining and oldvalue ~= newvalue then
                 --                 report_math("overloading math parameter %a: %S => %S",name,oldvalue,newvalue)
                 --             end
                 --         else
                 --          -- report_math("invalid math parameter %a",name)
                 --         end
                 --         mathparameters[name] = newvalue
                 --     end
                 -- end
                    for name, value in next, parameters do
                        local tvalue   = type(value)
                        local oldvalue = mathparameters[name]
                        local newvalue = oldvalue
                        if tvalue == "number" then
                            newvalue = value
                        elseif tvalue == "string" then
                            -- delay till all set
                        elseif tvalue == "function" then
                            newvalue = value(oldvalue,target,original)
                        elseif not tvalue then
                            newvalue = nil
                        end
                        if trace_defining and oldvalue ~= newvalue then
                            report_math("overloading math parameter %a: %S => %S",name,oldvalue or 0,newvalue)
                        end
                        mathparameters[name] = newvalue
                    end
                    for name, value in next, parameters do
                        local tvalue = type(value)
                        if tvalue == "string" then
                            local newvalue = mathparameters[value]
                            if not newvalue then
                                local code = loadstring("return " .. value,"","t",mathparameters)
                                if type(code) == "function" then
                                    local okay, v = pcall(code)
                                    if okay then
                                        newvalue = v
                                    end
                                end
                            end
                            if newvalue then
                                -- split in number and string
                                mathparameters[name] = newvalue
                            elseif trace_defining then
                                report_math("ignoring math parameter %a: %S",name,value)
                            end
                        end
                    end
                end
            end
        end
    end
end

local mathtweaks   = { subsets = table.setmetatableindex("table") }
mathematics.tweaks = mathtweaks

local apply_tweaks = true

directives.register("math.applytweaks", function(v)
    apply_tweaks = v;
end)

local function applytweaks(when,target,original)
    if apply_tweaks then
        local goodies = original.goodies
        if goodies then
            local tweaked = target.tweaked or { }
            if tweaked[when] then
                if trace_defining then
                    report_math("tweaking math of %a @ %p (%s: %s)",target.properties.fullname,target.parameters.size,when,"done")
                end
            else
                for i=1,#goodies do
                    local goodie = goodies[i]
                    local mathematics = goodie.mathematics
                    local tweaks = mathematics and mathematics.tweaks
                    if type(tweaks) == "table" then
                        tweaks = tweaks[when]
                        if type(tweaks) == "table" then
                            if trace_defining then
                                report_math("tweaking math of %a @ %p (%s: %s)",target.properties.fullname,target.parameters.size,when,"okay")
                            end
                            for i=1,#tweaks do
                                local tweak  = tweaks[i]
                                local tvalue = type(tweak)
                                if type(tweak) == "table" then
                                    local action = mathtweaks[tweak.tweak or ""]
                                    if action then
                                        local feature  = tweak.feature
                                        local features = target.specification.features.normal
                                        if not feature or features[feature] == true then
                                            local version = tweak.version
                                            if version and version ~= target.tweakversion then
                                                report_math("skipping tweak %a version %a",tweak.tweak,version)
                                            elseif original then
                                                action(target,original,tweak)
                                            else
                                                action(target,tweak)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                tweaked[when] = true
                target.tweaked = tweaked
            end
        end
    else
        report_math("not tweaking math of %a @ %p (%s)",target.properties.fullname,target.parameters.size,when)
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

sequencers.appendaction("mathparameters","system","mathematics.overloadparameters")
sequencers.appendaction("mathparameters","system","mathematics.scaleparameters")
----------.appendaction("mathparameters","system","mathematics.checkaccentbaseheight")  -- should go in lfg instead
sequencers.appendaction("mathparameters","system","mathematics.checkprivateparameters") -- after scaling !

sequencers.appendaction("beforecopyingcharacters","system","mathematics.tweakbeforecopyingfont")
sequencers.appendaction("aftercopyingcharacters", "system","mathematics.tweakaftercopyingfont")

do

    -- More than a year of testing, development, tweaking (and improving) fonts has resulted
    -- in a math engine in \LUAMETATEX\ that is quite flexible. Basically we can drop italic
    -- correction there. In \MKIV\ we can emulate this to some extend but we still need a bit
    -- of mix because \LUAMETATEX\ lacks some features. A variant of the tweak below is now
    -- also used in the plain code we ship. In \MKIV\ we dropped a few features that were a
    -- prelude to this and, because most users switched to \LMTX, it is unlikely that other
    -- tweaks wil be backported. There is also no need to adapt \LUATEX\ and eventually all
    -- italic code might be removed from \LUAMETATEX\ (unless we want to be able to test the
    -- alternative; I can live with a little ballast, especially because it took time to load
    -- it).

    local italics   = nil
    local integrals = table.tohash {
        0x0222B, 0x0222C, 0x0222D, 0x0222E, 0x0222F, 0x02230, 0x02231, 0x02232, 0x02233,
        0x02A0B, 0x02A0C, 0x02A0D, 0x02A0E, 0x02A0F, 0x02A10, 0x02A11, 0x02A12, 0x02A13,
        0x02A14, 0x02A15, 0x02A16, 0x02A17, 0x02A18, 0x02A19, 0x02A1A, 0x02A1B, 0x02A1C,
        0x02320, 0x02321
    }

    function mathtweaks.emulatelmtx(target,original,parameters)
        -- gaps are not known yet
        if not italic then
            italics = { }
            local gaps = mathematics.gaps
            for name, data in next, characters.blocks do
                if data.math and data.italic then
                    for i=data.first,data.last do
                        italics[i] = true
                        local g = gaps[i]
                        if g then
                            italics[g] = true
                        end
                    end
                end
            end
--             table.save("temp.log", table.sortedkeys(italics))
        end
        --
        local targetcharacters   = target.characters
        local targetdescriptions = target.descriptions
        local factor             = target.parameters.factor
        local function getllx(u)
            local d = targetdescriptions[u]
            if d then
                local b = d.boundingbox
                if b then
                    local llx = b[1]
                    if llx < 0 then
                        return - llx
                    end
                end
            end
            return false
        end
        -- beware: here we also do the weird ones
        for u, c in next, targetcharacters do
            local uc = c.unicode or u
            if integrals[uc] then
                -- skip this one
            else
                local accent = c.top_accent
                local italic = c.italic
                local width  = c.width  or 0
                local llx    = getllx(u)
                local bl, br, tl, tr
                if llx then
                    llx   = llx * factor
                    width = width + llx
                    bl    = - llx
                    tl    = bl
                    c.commands = { rightcommand[llx], charcommand[u] }
                    if accent then
                        accent = accent + llx
                    end
                end
                if accent then
                    if italics[uc] then
                        c.top_accent = accent
                    else
                        c.top_accent = nil
                    end
                end
                if italic and italic ~= 0 then
                    width = width + italic
                    br    = - italic
                end
                c.width = width
                if italic then
                    c.italic = nil
                end
                if bl or br or tl or tr then
                    -- watch out: singular and _ because we are post copying / scaling
                    c.mathkern = {
                        bottom_left  = bl and { { height = 0,             kern = bl } } or nil,
                        bottom_right = br and { { height = 0,             kern = br } } or nil,
                        top_left     = tl and { { height = c.height or 0, kern = tl } } or nil,
                        top_right    = tr and { { height = c.height or 0, kern = tr } } or nil,
                    }
                end
            end
        end
    end

    function mathtweaks.parameters(target,original,parameters)
        local newparameters = parameters.list
        local oldparameters = target.mathparameters
        if newparameters and oldparameters then
            newparameters = copytable(newparameters)
            scaleparameters(newparameters,target.parameters)
            for name, newvalue in next, newparameters do
                oldparameters[name] = newvalue
            end
        end
    end

end

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
            --
            target.type = "virtual"
            target.properties.virtualized = true
            --
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
