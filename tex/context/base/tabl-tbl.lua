if not modules then modules = { } end modules ['tabl-tbl'] = {
    version   = 1.001,
    comment   = "companion to tabl-tbl.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A couple of hacks ... easier to do in Lua than in regular TeX. More will
-- follow.

local tonumber = tonumber
local gsub, rep, sub, find = string.gsub, string.rep, string.sub, string.find
local P, C, Cc, Ct, lpegmatch = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.match

local context     = context
local commands    = commands

local texsetcount = tex.setcount

local separator   = P("|")
local nested      = lpeg.patterns.nested
local pattern     = Ct((separator * (C(nested) + Cc("")) * C((1-separator)^0))^0)

local ctx_settabulatelastentry = context.settabulatelastentry
local ctx_settabulateentry     = context.settabulateentry

local function presettabulate(preamble)
    preamble = gsub(preamble,"~","d") -- let's get rid of ~ mess here
    if find(preamble,"*",1,true) then
        -- todo: lpeg but not now
        preamble = gsub(preamble, "%*(%b{})(%b{})", function(n,p)
            return rep(sub(p,2,-2),tonumber(sub(n,2,-2)) or 1)
        end)
    end
    local t = lpegmatch(pattern,preamble)
    local m = #t - 2
    texsetcount("global","c_tabl_tabulate_nofcolumns", m/2)
    texsetcount("global","c_tabl_tabulate_has_rule_spec_first", t[1] == "" and 0 or 1)
    texsetcount("global","c_tabl_tabulate_has_rule_spec_last", t[m+1] == "" and 0 or 1)
    for i=1,m,2 do
        ctx_settabulateentry(t[i],t[i+1])
    end
    ctx_settabulatelastentry(t[m+1])
end

interfaces.implement {
    name      = "presettabulate",
    actions   = presettabulate,
    arguments = "string",
    scope     = "private",
}
