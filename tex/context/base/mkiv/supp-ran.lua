if not modules then modules = { } end modules ['supp-ran'] = {
    version   = 1.001,
    comment   = "companion to supp-ran.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We cannot ask for the current seed, so we need some messy hack here.

local report_system = logs.reporter("system","randomizer")

local trace_random  = false  trackers.register("system.randomizer",         function(v) trace_random  = v end)
local trace_details = false  trackers.register("system.randomizer.details", function(v) trace_details = v end)

local insert, remove = table.insert, table.remove

local math       = math
local context    = context
local implement  = interfaces.implement

local random     = math.random
local randomseed = math.randomseed
local round      = math.round
local stack      = { }
local last       = 1
local maxcount   = 0x3FFFFFFF -- 2^30-1

math.random = function(...)
    local n = random(...)
    if trace_details then
        report_system("math %s",n)
    end
    return n
end

local function setrandomseedi(n)
    if n <= 1 then
        n = n * maxcount
    elseif n < 1000 then
        n = n * 1000
    end
    n = round(n)
    randomseed(n)
    last = random(0,maxcount) -- we need an initial value
    if trace_details then
        report_system("seed %s from %s",last,n)
    elseif trace_random then
        report_system("setting seed %s",n)
    end
end

math.setrandomseedi = setrandomseedi

local function getrandomnumber(min,max)
    last = random(min,max)
    if trace_details then
        report_system("number %s",last)
    end
    return last
end

local function setrandomseed(n)
    last = n
    setrandomseedi(n)
end

local function getrandomseed()
    return last
end

-- local function getmprandomnumber()
--     last = random(0,4095)
--     if trace_details then
--         report_system("mp number %s",last)
--     end
--     return last
-- end

-- maybe stack

local function pushrandomseed()
    insert(stack,last)
    if trace_random or trace_details then
        report_system("pushing seed %s",last)
    end
end

local function reuserandomseed(n)
    local seed = stack[#stack]
    if seed then
        if trace_random or trace_details then
            report_system("reusing seed %s",last)
        end
        randomseed(seed)
    end
end

local function poprandomseed()
    local seed = remove(stack)
    if seed then
        if trace_random or trace_details then
            report_system("popping seed %s",seed)
        end
        randomseed(seed)
    end
end

local function getrandom(where,...)
    if type(where) == "string" then
        local n = random(...)
        if trace_details then
            report_system("%s %s",where,n)
        end
        return n
    else
        local n = random(where,...)
        if trace_details then
            report_system("utilities %s",n)
        end
        return n
    end
end

utilities.randomizer = {
    setseedi    = setrandomseedi,
    getnumber   = getrandomnumber,
    setseed     = setrandomseed,
    getseed     = getrandomseed,
 -- getmpnumber = getmprandomnumber,
    pushseed    = pushrandomseed,
    reuseseed   = reuserandomseed,
    popseed     = poprandomseed,
    get         = getrandom,
}

-- todo: also open up in utilities.randomizer.*

implement { name = "getrandomnumber",   actions = { getrandomnumber, context }, arguments = { "integer", "integer" } }
implement { name = "getrandomdimen",    actions = { getrandomnumber, context }, arguments = { "dimen", "dimen" } }
implement { name = "getrandomfloat",    actions = { getrandomnumber, context }, arguments = { "number", "number" } }
--------- { name = "getmprandomnumber", actions = { getmprandomnumber, context } }
implement { name = "setrandomseed",     actions = { setrandomseed },            arguments = { "integer" } }
implement { name = "getrandomseed",     actions = { getrandomseed, context } }
implement { name = "pushrandomseed",    actions = { pushrandomseed  } }
implement { name = "poprandomseed",     actions = { poprandomseed } }
implement { name = "reuserandomseed",   actions = { reuserandomseed } }

