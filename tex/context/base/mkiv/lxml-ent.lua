if not modules then modules = { } end modules ['lxml-ent'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local byte, format = string.byte, string.format
local setmetatableindex = table.setmetatableindex

--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>

<p>We do things different now but it's still somewhat experimental</p>
--ldx]]--

local trace_entities = false  trackers.register("xml.entities", function(v) trace_entities = v end)

local report_xml = logs.reporter("xml")

local xml = xml

xml.entities = xml.entities or { }

storage.register("xml/entities", xml.entities, "xml.entities" )

local entities = xml.entities  -- maybe some day properties

function xml.registerentity(key,value)
    entities[key] = value
    if trace_entities then
        report_xml("registering entity %a as %a",key,value)
    end
end

if characters and characters.entities then

    -- the big entity table also has amp, quot, apos, lt, gt in them

    local loaded = false

    function characters.registerentities(forcecopy)
        if loaded then
            return
        end
        if forcecopy then
            setmetatableindex(entities,nil)
            for name, value in next, characters.entities do
                if not entities[name] then
                    entities[name] = value
                end
            end
        else
            setmetatableindex(entities,characters.entities)
        end
        loaded = true
    end

end
