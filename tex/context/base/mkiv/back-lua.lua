if not modules then modules = { } end modules ['back-lua'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local buffer = { }
local b      = 0

local function reset()
    buffer = { }
    b      = 0
end

local function initialize(specification)
    reset()
end

local function finalize()
end

local function fetch()
    local saved = buffer
    reset()
    return saved
end

local function flushcharacter(current, pos_h, pos_v, pod_r, font, char)
    b = b + 1 ; buffer[b] = { "glyph", font, char, pos_h, pos_v, pos_r }
end

local function flushrule(current, pos_h, pos_v, pos_r, size_h, size_v)
    b = b + 1 ; buffer[b] = { "rule", size_h, size_v, pos_h, pos_v, pos_r }
end

-- file stuff too

drivers.install {
    name    = "lua",
    actions = {
        initialize = initialize,
        finalize   = finalize,
        fetch      = fetch,
        reset      = reset,
    },
    flushers = {
        character = flushcharacter,
        rule      = flushrule,
    }
}
