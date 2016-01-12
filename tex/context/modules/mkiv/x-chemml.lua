if not modules then modules = { } end modules ['x-chemml'] = {
    version   = 1.001,
    comment   = "companion to x-chemml.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- not yet acceptable cld

local format, lower, upper, gsub, sub, match = string.format, string.lower, string.upper, string.gsub, string.sub, string.match
local concat = table.concat

local chemml      = { }
local moduledata  = moduledata or { }
moduledata.chemml = chemml

function chemml.pi(id)
    local str = xml.content(lxml.id(id))
    local _, class, key, value = match(str,"^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*$")
    if key and value then
        context("\\setupCMLappearance[%s][%s=%s]",class, key, value)
    end
end

function chemml.do_graphic(id)
    local t = { }
    for r, d, k in xml.elements(lxml.id(id),"cml:graphic") do
        t[#t+1] = xml.tostring(d[k].dt)
    end
    context(concat(t,","))
end

function chemml.no_graphic(id)
    local t = { }
    for r, d, k in xml.elements(lxml.id(id),"cml:text|cml:oxidation|cml:annotation") do
        local dk = d[k]
        if dk.tg == "oxidation" then
            t[#t+1] = format("\\chemicaloxidation{%s}{%s}{%s}",r.at.sign or "",r.at.n or 1,xml.tostring(dk.dt))
        elseif dk.tg == "annotation" then
            local location = r.at.location or "r"
            local caption  = xml.content(xml.first(dk,"cml:caption"))
            local text     = xml.content(xml.first(dk,"cml:text"))
            t[#t+1] = format("\\doCMLannotation{%s}{%s}{%s}",location,caption,text)
        else
            t[#t+1] = xml.tostring(dk.dt) or ""
        end
    end
    context(concat(t,","))
end

