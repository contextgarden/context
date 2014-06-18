if not modules then modules = { } end modules ['typo-man'] = {
    version   = 1.001,
    comment   = "companion to typo-prc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not characters then
    -- for testing stand-alone
    require("char-def")
    require("char-ini")
end

local lpegmatch  = lpeg.match
local P, R, C, Ct, Cs, Carg = lpeg.P, lpeg.R, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Carg
local global = global or _G

local methods = {
    uppercase = characters.upper,
    lowercase = characters.lower,
    Word      = converters.Word,
    Words     = converters.Words,
}

local function nothing(s) return s end -- we already have that one somewhere

-- table.setmetatableindex(methods,function(t,k)
--     t[k] = nothing
--     return nothing
-- end)

local splitter = lpeg.tsplitat(".")

table.setmetatableindex(methods,function(t,k)
    local s = lpegmatch(splitter,k)
    local v = global
    for i=1,#s do
        v = v[s[i]]
        if not v then
            break
        end
    end
    if not v or v == global then
        v = nothing
    end
    t[k] = v
    return v
end)

local whitespace = lpeg.patterns.whitespace^0
local separator  = whitespace * P("->") * whitespace
local pair       = C((1-separator)^1) * separator * C(P(1)^0)
local list       = Ct((C((1-separator)^1) * separator)^1) * C(P(1)^0)

local pattern = Carg(1) * pair / function(methods,operation,str)
    return methods[operation](str) or str
end

local function apply(str,m)
    return lpegmatch(pattern,str,1,m or methods) or str
end

local function splitspecification(field,m)
    local m, f = lpegmatch(list,field,1,m or methods)
    if m then
        return m, f or field
    else
        return nil, field
    end
end

local function applyspecification(actions,str)
    if actions then
        for i=1,#actions do
            local action = methods[actions[i]]
            if action then
                str = action(str) or str
            end
        end
    end
    return str
end

if not typesetters then typesetters = { } end

typesetters.manipulators = {
    methods            = methods,
    apply              = apply,
    patterns           = {
        pair = pair,
        list = list,
    },
    splitspecification = splitspecification,
    applyspecification = applyspecification,
}

local pattern = Cs((1 - P(1) * P(-1))^0 * (P(".")/"" + P(1)))

methods.stripperiod = function(str) return lpegmatch(pattern,str) end

-- print(apply("hans"))
-- print(apply("uppercase->hans"))
-- print(apply("string.reverse -> hans"))
-- print(apply("uppercase->hans",{ uppercase = string.reverse } ))

-- print(applyspecification(splitspecification("hans")))
-- print(applyspecification(splitspecification("lowercase->uppercase->hans")))
-- print(applyspecification(splitspecification("uppercase->stripperiod->hans.")))

function commands.manipulated(str)
    context(apply(str))
end
