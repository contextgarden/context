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

local setfield        = nuts.setfield
local setlink         = nuts.setlink
local setchar         = nuts.setchar

local getfont         = nuts.getfont

local hpack_node_list = nuts.hpack
local vpack_node_list = nuts.vpack
local fast_hpack_list = nuts.fasthpack
local copy_node       = nuts.copy

local nodepool        = nuts.pool
local new_glyph       = nodepool.glyph
local new_glue        = nodepool.glue

local utfvalues       = utf.values

local currentfont     = font.current
local fontparameters  = fonts.hashes.parameters

local function tonodes(str,fontid,spacing,templateglyph) -- quick and dirty
    local head, prev = nil, nil
    if not fontid then
        if templateglyph then
            fontid = getfont(templateglyph)
        else
            fontid = currentfont()
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
            head = next
        else
            setlink(prev,next)
        end
        prev = next
    end
    return head
end

local function tohpack(str,fontid,spacing)
    return hpack_node_list(tonodes(str,fontid,spacing),"exactly")
end

local function tohpackfast(str,fontid,spacing)
    return fast_hpack_list(tonodes(str,fontid,spacing),"exactly")
end

local function tovpack(str,fontid,spacing)
    -- vpack is just a hack, and a proper implentation is on the agenda
    -- as it needs more info etc than currently available
    return vpack_node_list(tonodes(str,fontid,spacing))
end

local tovpackfast = tovpack

local tnuts       = { }
nuts.typesetters  = tnuts

tnuts.tonodes     = tonodes
tnuts.tohpack     = tohpack
tnuts.tohpackfast = tohpackfast
tnuts.tovpack     = tovpack
tnuts.tovpackfast = tovpackfast

tnuts.hpack       = tohpack     -- obsolete
tnuts.fast_hpack  = tohpackfast -- obsolete
tnuts.vpack       = tovpack     -- obsolete

typesetters.tonodes     = function(...) local h, b = tonodes    (...) return tonode(h), b end
typesetters.tohpack     = function(...) local h, b = tohpack    (...) return tonode(h), b end
typesetters.tohpackfast = function(...) local h, b = tohpackfast(...) return tonode(h), b end
typesetters.tovpack     = function(...) local h, b = tovpack    (...) return tonode(h), b end
typesetters.tovpackfast = function(...) local h, b = tovpackfast(...) return tonode(h), b end

typesetters.hpack       = typesetters.tohpack     -- obsolete
typesetters.fast_hpack  = typesetters.tofasthpack -- obsolete
typesetters.vpack       = typesetters.tovpack     -- obsolete

-- node.write(nodes.typesetters.hpack("Hello World!"))
-- node.write(nodes.typesetters.hpack("Hello World!",1,100*1024*10))

string.tonodes = function(...) return tonode(tonodes(...)) end  -- quite convenient
