if not modules then modules = { } end modules ['blob-ini'] = {
    version   = 1.001,
    comment   = "companion to blob-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module is just a playground. Occasionally we need to typeset at the lua and and
-- this is one method. In principle we can construct pages this way too which sometimes
-- makes sense in dumb cases. Actually, if one only needs this, one does not really need
-- tex, okay maybe the parbuilder but that one can be simplified as well then.

-- set fonts, attributes
-- rest already done in packers etc
-- add local par whatsit (or wait till cleaned up)
-- collapse or new pars
-- interline spacing etc

-- blob.char
-- blob.line
-- blob.paragraph
-- blob.page

local type, tostring = type, tostring
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local report_blobs    = logs.reporter("blobs")

local flush_node_list = node.flush_list
local hpack_node_list = node.hpack
----- vpack_node_list = node.vpack
local write_node      = node.write

local typesetters     = nodes.typesetters
local tonodes         = typesetters.tonodes
local tohpack         = typesetters.tohpack
local tovpack         = typesetters.tovpack

local implement       = interfaces.implement

-- provide copies here (nicer for manuals)

blobs             = blobs or  { }
local blobs       = blobs

blobs.tonodes     = tonodes
blobs.tohpack     = tohpack
blobs.tovpack     = tovpack

-- end of helpers

local newline = lpeg.patterns.newline
local space   = lpeg.patterns.spacer
local newpar  = (space^0*newline*space^0)^2

local ctxtextcapture = lpeg.Ct ( ( space^0 * ( newpar + lpeg.Cs(((space^1/" " + 1)-newpar)^1) ) )^0)

function blobs.new()
    return {
        list = { },
    }
end

function blobs.dispose(t)
    local list = t.list
    for i=1,#list do
        local li = list[i]
        local pack = li.pack
        if pack then
            flush_node_list(pack)
            li.pack = nil
        end
    end
end

function blobs.append(t,str) -- compare concat and link
    local typ = type(str)
    local dummy = nil
    if typ == "number" then
        str = tostring(str)
        typ = "string"
    end
    if typ == "string" then
        local pars = lpegmatch(ctxtextcapture,str)
        local list = t.list
        for p=1,#pars do
            local head, tail = tonodes(pars[p],nil,nil)
            list[#list+1] = { head = head, tail = tail }
        end
    end
end

function blobs.pack(t,how)
    local list = t.list
    for i=1,#list do
        local pack = list[i].pack
        if pack then
            flush_node_list(node.pack)
        end
        if how == "vertical" then
            -- we need to prepend a local par node
            -- list[i].pack = vpack_node_list(list[i].head,"exactly")
            report_blobs("vpack not yet supported")
        else
            list[i].pack = hpack_node_list(list[i].head,"exactly")
        end
    end
end

function blobs.write(t)
    local list = t.list
    for i=1,#list do
        local li = list[i]
        local pack = li.pack
        if pack then
            write_node(pack)
            flush_node_list(pack)
            li.pack = nil
        end
    end
end

function blobs.dimensions(t)
    local list = t.list
    local first = list and list[1]
    if first then
        local pack = first.pack
        return pack.width, pack.height, pack.depth
    else
        return 0, 0, 0
    end
end

-- blob.char
-- blob.line: head, tail
-- blob.paragraph
-- blob.page

-- local lineblob = {
--     type = "line",
--     head = false,
--     tail = false,
--     pack = false,
--     properties = { },
-- end

-- local parblob = {
--     type = "line",
--     head = false,
--     tail = false,
--     pack = false,
--     properties = { },
-- end

-- for the moment here:

local function strwd(str)
    local l = tohpack(str)
    local w = l.width
    flush_node_list(l)
    return w
end

local function strht(str)
    local l = tohpack(str)
    local h = l.height
    flush_node_list(l)
    return h
end

local function strdp(str)
    local l = tohpack(str)
    local d = l.depth
    flush_node_list(l)
    return d
end

local function strhd(str)
    local l = tohpack(str)
    local s = l.height + l.depth
    flush_node_list(l)
    return s
end

blobs.strwd = strwd
blobs.strht = strht
blobs.strdp = strdp
blobs.strhd = strhd

implement { name = "strwd", arguments = "string", actions = { strwd, context } }
implement { name = "strht", arguments = "string", actions = { strht, context } }
implement { name = "strdp", arguments = "string", actions = { strdp, context } }
implement { name = "strhd", arguments = "string", actions = { strhd, context } }
