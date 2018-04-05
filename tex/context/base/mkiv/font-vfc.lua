if not modules then modules = { } end modules ['font-vfc'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local select = select
local insert = table.insert

local fonts             = fonts
local helpers           = fonts.helpers

local setmetatableindex = table.setmetatableindex

-- helpers dealing with virtual fonts

local push  = { "push" }
local pop   = { "pop" }
local dummy = { "comment" }

function helpers.prependcommands(commands,...)
    insert(commands,1,push)
    for i=select("#",...),1,-1 do
        local s = select(i,...)
        if s then
            insert(commands,1,s)
        end
    end
    insert(commands,pop)
    return commands
end

function helpers.appendcommands(commands,...)
    insert(commands,1,push)
    insert(commands,pop)
    for i=1,select("#",...) do
        local s = select(i,...)
        if s then
            insert(commands,s)
        end
    end
    return commands
end

local char = setmetatableindex(function(t,k)   -- todo: weak
    local v = { "char", k }
    t[k] = v
    return v
end)

local right = setmetatableindex(function(t,k)  -- todo: weak
    local v = { "right", k }
    t[k] = v
    return v
end)

local left = setmetatableindex(function(t,k)   -- todo: weak
    local v = { "right", -k }
    t[k] = v
    return v
end)

local down = setmetatableindex(function(t,k)   -- todo: weak
    local v = { "down", k }
    t[k] = v
    return v
end)

local up = setmetatableindex(function(t,k)     -- todo: weak
    local v = { "down", -k }
    t[k] = v
    return v
end)

helpers.commands = utilities.storage.allocate {
    char  = char,
    right = right,
    left  = left,
    down  = down,
    up    = up,
    push  = push,
    pop   = pop,
    dummy = dummy,
}

