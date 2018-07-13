if not modules then modules = { } end modules ['back-inc'] = {
    version   = 1.001,
    comment   = "companion to back-exp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experiment. If it's really useful then I'll make a more efficient
-- local export facility.

local tonumber, next = tonumber, next
local utfbyte, utfchar, utfsplit = utf.byte, utf.char, utf.split
local match, gsub = string.match, string.gsub
local nspaces = string.nspaces
local concat = table.concat
local xmltext = xml.text
local undent = buffers.undent

local f_entity = string.formatters["&x%X;"]
local f_blob   = string.formatters['<?xml version="2.0"?>\n\n<!-- formula %i -->\n\n%s']

local all  = nil
local back = nil

local function unmath(s)
    local t = utfsplit(s)
    for i=1,#t do
        local ti = t[i]
        local bi = utfbyte(ti)
        if bi > 0xFFFF then
            local ch = back[bi]
            t[i] = ch and utfchar(ch) or f_entity(bi)
        end
    end
    s = concat(t)
    return s
end

local function beautify(s)
    local b = match(s,"^( *)<m:math")
    local e = match(s,"( *)</m:math>%s*$")
    if b and e then
        b = #b
        e = #e
        if e > b then
            s = undent(nspaces[e-b] .. s)
        elseif e < b then
            s = undent((gsub(s,"^( *)",nspaces[b-e])))
        end
    end
    return s
end

local function getblob(n)
    if all == nil then
        local name = file.nameonly(tex.jobname)
        local full = name .. "-export/" .. name .. "-raw.xml"
        if lfs.isfile(full) then
            all  = { }
            back = { }
            local root  = xml.load(full)
            for c in xml.collected(root,"formulacontent") do
                local index = tonumber(c.at.n)
                all[index] = f_blob(index,beautify(xmltext(c,"math") or ""))
            end
            local it = mathematics.alphabets.regular.it
            for k, v in next, it.digits    do back[v] = k end
            for k, v in next, it.ucletters do back[v] = k end
            for k, v in next, it.lcletters do back[v] = k end
        else
            all = false
        end
    end
    if all == false then
        return ""
    end
    return unmath(all[n] or "")
end

interfaces.implement {
    name      = "xmlformulatobuffer",
    arguments = { "integer", "string" },
    actions   = function(n,target)
        buffers.assign(target,getblob(n))
    end
}
