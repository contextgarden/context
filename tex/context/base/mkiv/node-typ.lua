if not modules then modules = { } end modules ['node-typ'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- code has been moved to blob-ini.lua

local typesetters     = nodes.typesetters or { }
nodes.typesetters     = typesetters

local nuts            = nodes.nuts
local tonode          = nuts.tonode
local tonut           = nuts.tonut

local setlink         = nuts.setlink
local setchar         = nuts.setchar
local setattrlist     = nuts.setattrlist

local getfont         = nuts.getfont
local getattrlist     = nuts.getattrlist

local hpack_node_list = nuts.hpack
local vpack_node_list = nuts.vpack
local full_hpack_list = nuts.fullhpack

local nodepool        = nuts.pool
local new_glyph       = nodepool.glyph
local new_glue        = nodepool.glue

local utfvalues       = utf.values

local currentfont     = font.current      -- mabe nicer is fonts     .current
local currentattr     = node.current_attr -- mabe nicer is attributes.current
local fontparameters  = fonts.hashes.parameters

-- when attrid == true then take from glyph or current else use the given value

local function tonodes(str,fontid,spacing,templateglyph,attrid) -- quick and dirty
    local head, prev = nil, nil
    if not fontid then
        if templateglyph then
            fontid = getfont(templateglyph)
        else
            fontid = currentfont()
        end
    end
    if attrid == true then
        if templateglyph then
            attrid = false -- we copy with the glyph
        else
            attrid = currentattr()
        end
    end
    local fp = fontparameters[fontid]
    local s, p, m
    if spacing then
        s, p, m = spacing, 0, 0
    else
        s, p, m = fp.space, fp.space_stretch, fp.space_shrink
    end
    local spacedone = false
    for c in utfvalues(str) do
        local next
        if c == 32 then
            if not spacedone then
                next = new_glue(s,p,m)
                spacedone = true
            end
        elseif templateglyph then
            next = copy_glyph(templateglyph)
            setchar(next,c)
            spacedone = false
        else
            next = new_glyph(fontid or 1,c)
            spacedone = false
        end
        if not next then
            -- nothing
        elseif not head then
            if attrid then
                setattrlist(next,attrid)
            end
            head = next
        else
            if attrid then
                setattrlist(next,attrid)
            end
            setlink(prev,next)
        end
        prev = next
    end
    return head
end

local function tohpack(str,fontid,spacing)
    return hpack_node_list(tonodes(str,fontid,spacing),"exactly")
end

local function tohbox(str,fontid,spacing)
    return full_hpack_list(tonodes(str,fontid,spacing),"exactly")
end

local function tovpack(str,fontid,spacing)
    -- vpack is just a hack, and a proper implemtation is on the agenda
    -- as it needs more info etc than currently available
    return vpack_node_list(tonodes(str,fontid,spacing))
end

local tovbox = tovpack -- for now no vpack filter

local tnuts       = { }
nuts.typesetters  = tnuts

tnuts.tonodes     = tonodes
tnuts.tohpack     = tohpack
tnuts.tohbox      = tohbox
tnuts.tovpack     = tovpack
tnuts.tovbox      = tovbox

typesetters.tonodes  = function(...) local h, b = tonodes(...) return tonode(h), b end
typesetters.tohpack  = function(...) local h, b = tohpack(...) return tonode(h), b end
typesetters.tohbox   = function(...) local h, b = tohbox (...) return tonode(h), b end
typesetters.tovpack  = function(...) local h, b = tovpack(...) return tonode(h), b end
typesetters.tovbox   = function(...) local h, b = tovbox (...) return tonode(h), b end

typesetters.hpack    = typesetters.tohpack  -- obsolete
typesetters.hbox     = typesetters.tohbox   -- obsolete
typesetters.vpack    = typesetters.tovpack  -- obsolete

-- node.write(nodes.typesetters.tohpack("Hello World!"))
-- node.write(nodes.typesetters.tohbox ("Hello World!"))
-- node.write(nodes.typesetters.tohpack("Hello World!",1,100*1024*10))
-- node.write(nodes.typesetters.tohbox ("Hello World!",1,100*1024*10))

string.tonodes = function(...) return tonode(tonodes(...)) end  -- quite convenient
