if not modules then modules = { } end modules ['lxml-inf'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This file will be loaded runtime by x-pending.tex.

local next, tostring, type = next, tostring, type
local concat = table.concat

local xmlwithelements = xml.withelements
local getid = lxml.getid

local status, stack

local function get(e,d)
    local ns   = e.ns
    local tg   = e.tg
    local name = tg
    if ns ~= "" then name = ns .. ":" .. tg end
    stack[d] = name
    local ec = e.command
    if ec == true then
        ec = "system: text"
    elseif ec == false then
        ec = "system: skip"
    elseif ec == nil then
        ec = "system: not set"
    elseif type(ec) == "string" then
        ec = "setup: " .. ec
    else -- function
        ec = tostring(ec)
    end
    local tag = concat(stack," => ",1,d)
    local s = status[tag]
    if not s then
        s = { }
        status[tag] = s
    end
    s[ec] = (s[ec] or 0) + 1
end

local function get_command_status(id)
    status, stack = {}, {}
    if id then
        xmlwithelements(getid(id),get)
        return status
    else
        local t = { }
        for id, _ in next, loaded do
            t[id] = get_command_status(id)
        end
        return t
    end
end

lxml.get_command_status = get_command_status
