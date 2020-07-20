if not modules then modules = { } end modules ['node-gmc'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tostring = type, tostring

local nodes          = nodes
local nodecodes      = nodes.nodecodes
local ligature_code  = nodes.glyphcodes.ligature
local nuts           = nodes.nuts

local getnext        = nuts.getnext
local getsubtype     = nuts.getsubtype
local getprev        = nuts.getprev
local setlink        = nuts.setlink
local nextglyph      = nuts.traversers.glyph
local copy_node      = nuts.copy
local isglyph        = nuts.isglyph

local report_error   = logs.reporter("node-aux:error")

local get_components = node.direct.getcomponents
local set_components = node.direct.setcomponents

local function copy_no_components(g,copyinjection)
    local components = get_components(g)
    if components then
        set_components(g)
        local n = copy_node(g)
        if copyinjection then
            copyinjection(n,g)
        end
        set_components(g,components)
        -- maybe also upgrade the subtype but we don't use it anyway
        return n
    else
        local n = copy_node(g)
        if copyinjection then
            copyinjection(n,g)
        end
        return n
    end
end

local function copy_only_glyphs(current)
    local head     = nil
    local previous = nil
    for n in nextglyph, current do
        n = copy_node(n)
        if head then
            setlink(previous,n)
        else
            head = n
        end
        previous = n
    end
    return head
end

-- start is a mark and we need to keep that one

local function count_components(start,marks)
    local char = isglyph(start)
    if char then
        if getsubtype(start) == ligature_code then
            local n = 0
            local components = get_components(start)
            while components do
                n = n + count_components(components,marks)
                components = getnext(components)
            end
            return n
        elseif not marks[char] then
            return 1
        end
    end
    return 0
end

nuts.set_components     = set_components
nuts.get_components     = get_components
nuts.copy_only_glyphs   = copy_only_glyphs
nuts.copy_no_components = copy_no_components
nuts.count_components   = count_components

nuts.setcomponents = function() report_error("unsupported: %a","setcomponents") end
nuts.getcomponents = function() report_error("unsupported: %a","getcomponents") end
