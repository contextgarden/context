if not modules then modules = { } end modules ['font-log'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, format, lower, concat = next, string.format, string.lower, table.concat

local trace_defining  = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local report_defining = logs.reporter("fonts","defining")

local basename = file.basename

local fonts       = fonts
local loggers     = { }
fonts.loggers     = loggers
local usedfonts   = utilities.storage.allocate()
----- loadedfonts = utilities.storage.allocate()

--[[ldx--
<p>The following functions are used for reporting about the fonts
used. The message itself is not that useful in regular runs but since
we now have several readers it may be handy to know what reader is
used for which font.</p>
--ldx]]--

function loggers.onetimemessage(font,char,message,reporter)
    local tfmdata = fonts.hashes.identifiers[font]
    local shared = tfmdata.shared
    local messages = shared.messages
    if not messages then
        messages = { }
        shared.messages = messages
    end
    local category = messages[message]
    if not category then
        category = { }
        messages[message] = category
    end
    if not category[char] then
        if not reporter then
            reporter = report_defining
        end
        reporter("char %U in font %a with id %s: %s",char,tfmdata.properties.fullname,font,message)
        category[char] = true
    end
end

function loggers.register(tfmdata,source,specification) -- save file name in spec here ! ! ! ! ! !
    if tfmdata and specification and specification.specification then
        local name = lower(specification.name)
        if trace_defining and not usedfonts[name] then
            report_defining("registering %a as %a, used %a",file.basename(specification.name),source,file.basename(specification.filename))
        end
        specification.source = source
     -- loadedfonts[lower(specification.specification)] = specification
        usedfonts[lower(specification.filename or specification.name)] = source
    end
end

function loggers.format(name) -- should be avoided
    return usedfonts[name] or "unknown"
end

-- maybe move this to font-ctx.lua

statistics.register("loaded fonts", function()
    if next(usedfonts) then
        local t, n = { }, 0
        local treatmentdata = fonts.treatments.data
        for name, used in table.sortedhash(usedfonts) do
            n = n + 1
            local base = basename(name)
            if complete then
                t[n] = format("%s -> %s",used,base)
            else
                t[n] = base
            end
            local treatment = treatmentdata[base]
            if treatment and treatment.comment then
                 t[n] = format("%s (%s)",t[n],treatment.comment)
            end
        end
        return n > 0 and format("%s files: %s",n,concat(t,", ")) or "none"
    end
end)
