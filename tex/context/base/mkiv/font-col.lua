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

local type, next, toboolean = type, next, toboolean
local gmatch = string.gmatch
local fastcopy = table.fastcopy

local nuts               = nodes.nuts
local tonut              = nuts.tonut

local getfont            = nuts.getfont
local getchar            = nuts.getchar

local setfield           = nuts.setfield
local setchar            = nuts.setchar

local traverse_id        = nuts.traverse_id

local settings_to_hash   = utilities.parsers.settings_to_hash

local trace_collecting   = false  trackers.register("fonts.collecting", function(v) trace_collecting = v end)

local report_fonts       = logs.reporter("fonts","collections")

local collections        = fonts.collections or { }
fonts.collections        = collections

local definitions        = collections.definitions or { }
collections.definitions  = definitions

local vectors            = collections.vectors or { }
collections.vectors      = vectors

local fontdata           = fonts.hashes.identifiers
local chardata           = fonts.hashes.characters
local glyph_code         = nodes.nodecodes.glyph
local currentfont        = font.current

local fontpatternhassize = fonts.helpers.fontpatternhassize

local implement          = interfaces.implement

local list               = { }
local current            = 0
local enabled            = false

local function checkenabled()
    -- a bit ugly but nicer than a fuzzy state while defining math
    if next(vectors) then
        if not enabled then
            nodes.tasks.enableaction("processors","fonts.collections.process")
            enabled = true
        end
    else
        if enabled then
            nodes.tasks.disableaction("processors","fonts.collections.process")
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
    for s in gmatch(ranges,"[^, ]+") do
        local start, stop, description, gaps = characters.getrange(s)
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
            local offset = details.offset
            if type(offset) == "string" then
                local start = characters.getrange(offset)
                offset = start or false
            else
                offset = tonumber(offset) or false
            end
            d[#d+1] = {
                font   = font,
                start  = start,
                stop   = stop,
                gaps   = gaps,
                offset = offset,
                rscale = tonumber (details.rscale) or 1,
                force  = toboolean(details.force,true),
                check  = toboolean(details.check,true),
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
        local remap      = definition.remap
        local cloneid    = list[i]
        local oldchars   = fontdata[current].characters
        local newchars   = fontdata[cloneid].characters
        if trace_collecting then
            report_fonts("remapping font %a to %a for range %U - %U",current,cloneid,start,stop)
        end
        if check then
            for unicode = start, stop do
                local unic = unicode + offset - start
                if not newchars[unicode] then
                    -- not in font
                elseif force or (not vector[unic] and not oldchars[unic]) then
                    if remap then
                        vector[unic] = { cloneid, remap[unicode] }
                    else
                        vector[unic] = cloneid
                    end
                end
            end
        else
            for unicode = start, stop do
                local unic = unicode + offset - start
                if force or (not vector[unic] and not oldchars[unic]) then
                    if remap then
                        vector[unic] = { cloneid, remap[unicode] }
                    else
                        vector[unic] = cloneid
                    end
                end
            end
        end
    end
    if trace_collecting then
        report_fonts("activating collection %a for font %a",name,current)
    end
    checkenabled()
    statistics.stoptiming(fonts)
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
    if fontdata[current].mathparameters then
        return
    end
    local d = definitions[name]
    if d then
        if trace_collecting then
            local filename = file.basename(fontdata[current].properties.filename or "?")
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
    elseif trace_collecting then
        local filename = file.basename(fontdata[current].properties.filename or "?")
        report_fonts("error while applying collection %a to %a, file %a",name,current,filename)
    end
end

function collections.report(message)
    if trace_collecting then
        report_fonts("tex: %s",message)
    end
end

function collections.process(head) -- this way we keep feature processing
    local done = false
    for n in traverse_id(glyph_code,tonut(head)) do
        local font   = getfont(n)
        local vector = vectors[font]
        if vector then
            local char = getchar(n)
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
                setfield(n,"font",newfont)
                setchar(n,newchar)
                done = true
            else
                if trace_collecting then
                    report_fonts("remapping font %a to %a for character %C%s",
                        font,vect,char,not chardata[vect][char] and " (missing)" or ""
                    )
                end
                setfield(n,"font",vect)
                done = true
            end
        end
    end
    return head, done
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
    arguments = { "string", "string", "string", "string" }
}

implement {
    name      = "fontcollectionreset",
    actions   = collections.reset,
    arguments = { "string", "string" }
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
