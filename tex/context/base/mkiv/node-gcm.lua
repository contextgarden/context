if not modules then modules = { } end modules ['node-gmc'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tostring = type, tostring

local nodes         = nodes
local nodecodes     = nodes.nodecodes
local ligature_code = nodes.glyphcodes.ligature
local nuts          = nodes.nuts

local getnext       = nuts.getnext
local getsubtype    = nuts.getsubtype
local getprev       = nuts.getprev
local setlink       = nuts.setlink
local nextglyph     = nuts.traversers.glyph
local copynode      = nuts.copy
local isglyph       = nuts.isglyph

local report_error  = logs.reporter("node-aux:error")

local getcomponents = node.direct.getcomponents
local setcomponents = node.direct.setcomponents

local function copynocomponents(g,copyinjection)
    local components = getcomponents(g)
    if components then
        setcomponents(g)
        local n = copynode(g)
        if copyinjection then
            copyinjection(n,g)
        end
        setcomponents(g,components)
        -- maybe also upgrade the subtype but we don't use it anyway
        return n
    else
        local n = copynode(g)
        if copyinjection then
            copyinjection(n,g)
        end
        return n
    end
end

local function copyonlyglyphs(current)
    local head     = nil
    local previous = nil
    for n in nextglyph, current do
        n = copynode(n)
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

local function countcomponents(start,marks)
    local char = isglyph(start)
    if char then
        if getsubtype(start) == ligature_code then
            local n = 0
            local components = getcomponents(start)
            while components do
                n = n + countcomponents(components,marks)
                components = getnext(components)
            end
            return n
        elseif not marks[char] then
            return 1
        end
    end
    return 0
end

local function flushcomponents()
    -- this is a no-op in mkiv / generic
end

nuts.components = {
    set              = setcomponents,
    get              = getcomponents,
    copyonlyglyphs   = copyonlyglyphs,
    copynocomponents = copynocomponents,
    count            = countcomponents,
    flush            = flushcomponents,
}

nuts.setcomponents = function() report_error("unsupported: %a","setcomponents") end
nuts.getcomponents = function() report_error("unsupported: %a","getcomponents") end
