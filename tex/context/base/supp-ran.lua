if not modules then modules = { } end modules ['supp-ran'] = {
    version   = 1.001,
    comment   = "companion to supp-ran.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We cannot ask for the current seed, so we need some messy hack here.

local report_system = logs.reporter("system","randomizer")

local math       = math
local context    = context
local implement  = interfaces.implement

local random     = math.random
local randomseed = math.randomseed
local round      = math.round
local seed       = false
local last       = 1
local maxcount   = 2^30-1 -- 1073741823

local function setrandomseedi(n,comment)
    if not n then
 --     n = 0.5 -- hack
    end
    if n <= 1 then
        n = n * maxcount
    end
    n = round(n)
    if false then
        report_system("setting seed to %s (%s)",n,comment or "normal")
    end
    randomseed(n)
    last = random(0,maxcount) -- we need an initial value
end

math.setrandomseedi = setrandomseedi

local function getrandomnumber(min,max)
    last = random(min,max)
    return last
end

local function setrandomseed(n)
    last = n
    setrandomseedi(n)
end

local function getrandomseed()
    return last
end

-- maybe stack

local function freezerandomseed(n)
    if seed == false or seed == nil then
        seed = last
        setrandomseedi(seed,"freeze",seed)
    end
    if n then
        randomseed(n)
    end
end

local function defrostrandomseed()
    if seed ~= false then
        setrandomseedi(seed,"defrost",seed) -- was last (bug)
        seed = false
    end
end

implement { name = "getrandomnumber",   actions = { getrandomnumber, context }, arguments = { "integer", "integer" } }
implement { name = "getrandomdimen",    actions = { getrandomnumber, context }, arguments = { "dimen", "dimen" } }
implement { name = "getrandomfloat",    actions = { getrandomnumber, context }, arguments = { "number", "number" } }
implement { name = "setrandomseed",     actions = { setrandomseed },            arguments = { "integer" } }
implement { name = "getrandomseed",     actions = { getrandomseed, context } }
implement { name = "freezerandomseed",  actions = { freezerandomseed  } }
implement { name = "defrostrandomseed", actions = { defrostrandomseed } }

