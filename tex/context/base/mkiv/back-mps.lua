if not modules then modules = { } end modules ['back-mps'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The basics are the same as the lua variant.

local formatters = string.formatters
local bpfactor   = number.dimenfactors.bp

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

local function flushrule(current, pos_h, pos_v, pod_r, size_h, size_v)
    b = b + 1 ; buffer[b] = { "rule", size_h, size_v, pos_h, pos_v, pos_r }
end

drivers.install {
    name    = "mps",
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

if not mp then
    return
end

local mpprint = mp.print

local f_glyph = formatters[ [[draw textext.drt("\setfontid%i\relax\char%i\relax") shifted (%N,%N);]] ]
local f_rule  = formatters[ [[fill unitsquare xscaled %N yscaled %N shifted (%N,%N);]] ]

local current = nil
local size    = 0

function mp.place_buffermake(box)
    drivers.convert("mps",box)
    current = drivers.action("mps","fetch")
    size    = #current
end

function mp.place_buffersize()
    mpprint(size)
end

function mp.place_bufferslot(i)
    if i > 0 and i <= size then
        local b = buffer[i]
        local t = b[1]
        if t == "glyph" then
            mpprint(f_glyph(b[2],b[3],b[4]*bpfactor,b[5]*bpfactor))
        elseif t == "rule" then
            mpprint(f_rule(b[2]*bpfactor,b[3]*bpfactor,b[4]*bpfactor,b[5]*bpfactor))
        end
    end
end

function mp.place_bufferwipe()
    current = nil
    size    = 0
end
