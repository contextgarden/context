if not modules then modules = { } end modules ['font-col'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- possible optimization: delayed initialization of vectors
-- we should also share equal vectors (math)

local context, commands, trackers, logs = context, commands, trackers, logs
local node, nodes, fonts, characters = node, nodes, fonts, characters
local file, lpeg, table, string = file, lpeg, table, string

local type, next, tonumber, toboolean = type, next, tonumber, toboolean
local gmatch = string.gmatch
local fastcopy = table.fastcopy
local formatters = string.formatters

local nuts               = nodes.nuts

local setfont            = nuts.setfont

----- traverse_char      = nuts.traverse_char
local nextchar           = nuts.traversers.char

local settings_to_hash   = utilities.parsers.settings_to_hash

local trace_collecting   = false  trackers.register("fonts.collecting", function(v) trace_collecting = v end)

local report_fonts       = logs.reporter("fonts","collections")

local enableaction       = nodes.tasks.enableaction
local disableaction      = nodes.tasks.disableaction

local collections        = fonts.collections or { }
fonts.collections        = collections

local definitions        = collections.definitions or { }
collections.definitions  = definitions

local vectors            = collections.vectors or { }
collections.vectors      = vectors

local helpers            = fonts.helpers
local charcommand        = helpers.commands.char
local rightcommand       = helpers.commands.right
local addprivate         = helpers.addprivate
local hasprivate         = helpers.hasprivate
local fontpatternhassize = helpers.fontpatternhassize

local hashes             = fonts.hashes
local fontdata           = hashes.identifiers
local fontquads          = hashes.quads
local chardata           = hashes.characters
local propdata           = hashes.properties
local mathparameters     = hashes.mathparameters

local currentfont        = font.current
local addcharacters      = font.addcharacters

local implement          = interfaces.implement

local list               = { }
local current            = 0
local enabled            = false

local validvectors       = table.setmetatableindex(function(t,k)
    local v = false
    if not mathparameters[k] then
        v = vectors[k]
    end
    t[k] = v
    return v
end)

local function checkenabled()
    -- a bit ugly but nicer than a fuzzy state while defining math
    if next(vectors) then
        if not enabled then
            enableaction("processors","fonts.collections.process")
            enabled = true
        end
    else
        if enabled then
            disableaction("processors","fonts.collections.process")
            enabled = false
        end
    end
end

collections.checkenabled = checkenabled

function collections.reset(name,font)
    if font and font ~= "" then
        local d = definitions[name]
        if d then
            d[font] = nil
            if not next(d) then
                definitions[name] = nil
            end
        end
    else
        definitions[name] = nil
    end
end

function collections.define(name,font,ranges,details)
    -- todo: details -> method=force|conditional rscale=
    -- todo: remap=name
    local d = definitions[name]
    if not d then
        d = { }
        definitions[name] = d
    end
    if name and trace_collecting then
        report_fonts("extending collection %a using %a",name,font)
    end
    details = settings_to_hash(details)
    -- todo, combine per font start/stop as arrays
    local offset = details.offset
    if type(offset) == "string" then
        offset = characters.getrange(offset,true) or false
    else
        offset = tonumber(offset) or false
    end
    local target = details.target
    if type(target) == "string" then
        target = characters.getrange(target,true) or false
    else
        target = tonumber(target) or false
    end
    local rscale   = tonumber (details.rscale) or 1
    local force    = toboolean(details.force,true)
    local check    = toboolean(details.check,true)
    local factor   = tonumber(details.factor)
    local features = details.features
    for s in gmatch(ranges,"[^, ]+") do
        local start, stop, description, gaps = characters.getrange(s,true)
        if start and stop then
            if trace_collecting then
                if description then
                    report_fonts("using range %a, slots %U - %U, description %a)",s,start,stop,description)
                end
                for i=1,#d do
                    local di = d[i]
                    if (start >= di.start and start <= di.stop) or (stop >= di.start and stop <= di.stop) then
                        report_fonts("overlapping ranges %U - %U and %U - %U",start,stop,di.start,di.stop)
                    end
                end
            end
            d[#d+1] = {
                font     = font,
                start    = start,
                stop     = stop,
                gaps     = gaps,
                offset   = offset,
                target   = target,
                rscale   = rscale,
                force    = force,
                check    = check,
                method   = details.method,
                factor   = factor,
                features = features,
            }
        end
    end
end

-- todo: provide a lua variant (like with definefont)

function collections.registermain(name)
    local last = currentfont()
    if trace_collecting then
        report_fonts("registering font %a with name %a",last,name)
    end
    list[#list+1] = last
end

-- check: when true, only set when present in font
-- force: when false, then not set when already set

local uccodes = characters.uccodes
local lccodes = characters.lccodes

local methods = {
    lowercase = function(oldchars,newchars,vector,start,stop,cloneid)
        for k, v in next, oldchars do
            if k >= start and k <= stop then
                local lccode = lccodes[k]
                if k ~= lccode and newchars[lccode] then
                    vector[k] = { cloneid, lccode }
                end
            end
        end
    end,
    uppercase = function(oldchars,newchars,vector,start,stop,cloneid)
        for k, v in next, oldchars do
            if k >= start and k <= stop then
                local uccode = uccodes[k]
                if k ~= uccode and newchars[uccode] then
                    vector[k] = { cloneid, uccode }
                end
            end
        end
    end,
}

function collections.clonevector(name)
    statistics.starttiming(fonts)
    if trace_collecting then
        report_fonts("processing collection %a",name)
    end
    local definitions = definitions[name]
    local vector      = { }
    vectors[current]  = vector
    for i=1,#definitions do
        local definition = definitions[i]
        local name       = definition.font
        local start      = definition.start
        local stop       = definition.stop
        local check      = definition.check
        local force      = definition.force
        local offset     = definition.offset or start
        local remap      = definition.remap -- not used
        local target     = definition.target
        local method     = definition.method
        local cloneid    = list[i]
        local oldchars   = fontdata[current].characters
        local newchars   = fontdata[cloneid].characters
        local factor     = definition.factor
        if factor then
            vector.factor = factor
        end
        if trace_collecting then
            if target then
                report_fonts("remapping font %a to %a for range %U - %U, offset %X, target %U",current,cloneid,start,stop,offset,target)
            else
                report_fonts("remapping font %a to %a for range %U - %U, offset %X",current,cloneid,start,stop,offset)
            end
        end
        if method then
            method = methods[method]
        end
        if method then
            method(oldchars,newchars,vector,start,stop,cloneid)
        elseif check then
            if target then
                for unicode = start, stop do
                    local unic = unicode + offset - start
                    if not newchars[target] then
                        -- not in font
                    elseif force or (not vector[unic] and not oldchars[unic]) then
                        vector[unic] = { cloneid, target }
                    end
                    target = target + 1
                end
            elseif remap then
                -- not used
            else
                for unicode = start, stop do
                    local unic = unicode + offset - start
                    if not newchars[unicode] then
                        -- not in font
                    elseif force or (not vector[unic] and not oldchars[unic]) then
                        vector[unic] = cloneid
                    end
                end
            end
        else
            if target then
                for unicode = start, stop do
                    local unic = unicode + offset - start
                    if force or (not vector[unic] and not oldchars[unic]) then
                        vector[unic] = { cloneid, target }
                    end
                    target = target + 1
                end
            elseif remap then
                for unicode = start, stop do
                    local unic = unicode + offset - start
                    if force or (not vector[unic] and not oldchars[unic]) then
                        vector[unic] = { cloneid, remap[unicode] }
                    end
                end
            else
                for unicode = start, stop do
                    local unic = unicode + offset - start
                    if force or (not vector[unic] and not oldchars[unic]) then
                        vector[unic] = cloneid
                    end
                end
            end
        end
    end
    if trace_collecting then
        report_fonts("activating collection %a for font %a",name,current)
    end
    statistics.stoptiming(fonts)
    -- for WS: needs checking
    if validvectors[current] then
        checkenabled()
    end
end

-- we already have this parser
--
-- local spec = (P("sa") + P("at") + P("scaled") + P("at") + P("mo")) * P(" ")^1 * (1-P(" "))^1 * P(" ")^0 * -1
-- local okay = ((1-spec)^1 * spec * Cc(true)) + Cc(false)
--
-- if lpegmatch(okay,name) then

function collections.prepare(name) -- we can do this in lua now .. todo
    current = currentfont()
    if vectors[current] then
        return
    end
    local properties = propdata[current]
    local mathsize   = properties.mathsize
    if mathsize == 1 or mathsize == 2 or mathsize == 3 then
        return
    end
    local d = definitions[name]
    if d then
        if trace_collecting then
            local filename = file.basename(properties.filename or "?")
            report_fonts("applying collection %a to %a, file %a",name,current,filename)
        end
        list = { }
        context.pushcatcodes("prt") -- context.unprotect()
        context.font_fallbacks_start_cloning()
        for i=1,#d do
            local f = d[i]
            local name = f.font
            local scale = f.rscale or 1
            if fontpatternhassize(name) then
                context.font_fallbacks_clone_unique(name,scale)
            else
                context.font_fallbacks_clone_inherited(name,scale)
            end
            context.font_fallbacks_register_main(name)
        end
        context.font_fallbacks_prepare_clone_vectors(name)
        context.font_fallbacks_stop_cloning()
        context.popcatcodes() -- context.protect()
    end
end

function collections.report(message)
    if trace_collecting then
        report_fonts("tex: %s",message)
    end
end

local function monoslot(font,char,parent,factor)
    local tfmdata     = fontdata[font]
    local privatename = formatters["faked mono %s"](char)
    local privateslot = hasprivate(tfmdata,privatename)
    if privateslot then
        return privateslot
    else
        local characters = tfmdata.characters
        local properties = tfmdata.properties
        local width      = factor * fontquads[parent]
        local character  = characters[char]
        if character then
            -- runtime patching of the font (can only be new characters)
            -- instead of messing with existing dimensions
            local data = {
                -- no features so a simple copy
                width    = width,
                height   = character.height,
                depth    = character.depth,
                commands = {
                    rightcommand[(width - character.width or 0)/2],
                    charcommand[char],
                }
            }
            local u = addprivate(tfmdata, privatename, data)
            addcharacters(properties.id, {
                type       = "real",
                characters = {
                    [u] = data
                },
            } )
            return u
        else
            return char
        end
    end
end

function collections.process(head) -- this way we keep feature processing
    for n, char, font in nextchar, head do
        local vector = validvectors[font]
        if vector then
            local vect = vector[char]
            if not vect then
                -- keep it
            elseif type(vect) == "table" then
                local newfont = vect[1]
                local newchar = vect[2]
                if trace_collecting then
                    report_fonts("remapping character %C in font %a to character %C in font %a%s",
                        char,font,newchar,newfont,not chardata[newfont][newchar] and " (missing)" or ""
                    )
                end
                setfont(n,newfont,newchar)
            else
                local fakemono = vector.factor
                if trace_collecting then
                    report_fonts("remapping font %a to %a for character %C%s",
                        font,vect,char,not chardata[vect][char] and " (missing)" or ""
                    )
                end
                if fakemono then
                    setfont(n,vect,monoslot(vect,char,font,fakemono))
                else
                    setfont(n,vect)
                end
            end
        end
    end
    return head
end

function collections.found(font,char) -- this way we keep feature processing
    if not char then
        font, char = currentfont(), font
    end
    if chardata[font][char] then
        return true -- in normal font
    else
        local v = vectors[font]
        return v and v[char] and true or false
    end
end

-- interface

implement {
    name      = "fontcollectiondefine",
    actions   = collections.define,
    arguments = "4 strings",
}

implement {
    name      = "fontcollectionreset",
    actions   = collections.reset,
    arguments = "2 strings",
}

implement {
    name      = "fontcollectionprepare",
    actions   = collections.prepare,
    arguments = "string"
}

implement {
    name      = "fontcollectionreport",
    actions   = collections.report,
    arguments = "string"
}

implement {
    name      = "fontcollectionregister",
    actions   = collections.registermain,
    arguments = "string"
}

implement {
    name      = "fontcollectionclone",
    actions   = collections.clonevector,
    arguments = "string"
}

implement {
    name      = "doifelsecharinfont",
    actions   = { collections.found, commands.doifelse },
    arguments = { "integer" }
}
