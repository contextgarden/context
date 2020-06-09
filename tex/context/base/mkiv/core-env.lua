if not modules then modules = { } end modules ['core-env'] = {
    version   = 1.001,
    comment   = "companion to core-env.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe this will move to the context name space although the
-- plurals are unlikely to clash with future tex primitives
--
-- if tex.modes['xxxx'] then .... else .... end

local rawset = rawset

local P, C, S, lpegmatch, patterns = lpeg.P, lpeg.C, lpeg.S, lpeg.match, lpeg.patterns

local context              = context
local ctxcore              = context.core

local texgetcount          = tex.getcount

local allocate             = utilities.storage.allocate
local setmetatableindex    = table.setmetatableindex
local setmetatablenewindex = table.setmetatablenewindex
local setmetatablecall     = table.setmetatablecall

local createtoken          = token.create
local isdefined            = tokens.isdefined

texmodes                   = allocate { }  tex.modes        = texmodes
texsystemmodes             = allocate { }  tex.systemmodes  = texsystemmodes
texconstants               = allocate { }  tex.constants    = texconstants
texconditionals            = allocate { }  tex.conditionals = texconditionals
texifs                     = allocate { }  tex.ifs          = texifs
texisdefined               = allocate { }  tex.isdefined    = texisdefined

local modes                = { }
local systemmodes          = { }

-- we could use the built-in tex.is[count|dimen|skip|toks] here but caching
-- at the lua end is not that bad (and we need more anyway)

local cache = tokens.cache

-- we can have a modes cache too

local iftrue        = cache["iftrue"].mode

local dimencode     = cache["scratchdimen"]    .command -- tokens.commands.assign_dimen
local countcode     = cache["scratchcounter"]  .command -- tokens.commands.assign_int
local tokencode     = cache["scratchtoken"]    .command -- tokens.commands.assign_toks
local skipcode      = cache["scratchskip"]     .command -- tokens.commands.assign_glue
local muskipcode    = cache["scratchmuskip"]   .command -- tokens.commands.assign_mu_glue
----- attributecode = cache["scratchattribute"].command -- tokens.commands.assign_attr
local conditioncode = cache["iftrue"]          .command -- tokens.commands.if_test

local types = {
    [dimencode]     = "dimen",
    [countcode]     = "count",
    [tokencode]     = "token",
    [skipcode]      = "skip",
    [muskipcode]    = "muskip",
 -- [attributecode] = "attribute",
    [conditioncode] = "condition"
}

setmetatableindex(texmodes, function(t,k)
    local m = modes[k]
    if m then
        return m()
    elseif k then
        local n = "mode>" .. k
        if isdefined(n) then
            rawset(modes,k, function() return texgetcount(n) == 1 end)
            return texgetcount(n) == 1 -- 2 is prevented
        else
            return false
        end
    else
        return false
    end
end)

setmetatablenewindex(texmodes, function(t,k)
    report_mode("you cannot set the %s named %a this way","mode",k)
end)

setmetatableindex(texsystemmodes, function(t,k)
    local m = systemmodes[k]
    if m then
        return m()
    else
        local n = "mode>*" .. k
        if isdefined(n) then
            rawset(systemmodes,k,function() return texgetcount(n) == 1 end)
            return texgetcount(n) == 1 -- 2 is prevented
        else
            return false
        end
    end
end)
setmetatablenewindex(texsystemmodes, function(t,k)
    report_mode("you cannot set the %s named %a this way","systemmode",k)
end)

setmetatableindex(texconstants, function(t,k)
    return cache[k].mode ~= 0 and texgetcount(k) or 0
end)
setmetatablenewindex(texconstants, function(t,k)
    report_mode("you cannot set the %s named %a this way","constant",k)
end)

setmetatableindex(texconditionals, function(t,k) -- 0 == true
    return cache[k].mode ~= 0 and texgetcount(k) == 0
end)
setmetatablenewindex(texconditionals, function(t,k)
    report_mode("you cannot set the %s named %a this way","conditional",k)
end)

table.setmetatableindex(texifs, function(t,k)
    return cache[k].mode == iftrue
end)
setmetatablenewindex(texifs, function(t,k)
    -- just ignore
end)

if CONTEXTLMTXMODE > 0 then

    iftrue = cache["iftrue"].index

    -- if we really need performance we can have a dedicated cache for each
    -- kind of variable

    setmetatableindex(texconstants, function(t,k)
        return cache[k].command == countcode and texgetcount(k) or 0
    end)

    setmetatableindex(texconditionals, function(t,k) -- 0 == true
        return cache[k].command == countcode and texgetcount(k) == 0
    end)

    table.setmetatableindex(texifs, function(t,k)
        local c = cache[k]
        print(k)
        inspect(c)
        return c.command == conditioncode and c.index == iftrue
    end)

end

tex.isdefined = isdefined

function tex.isdimen(name)
    local hit = cache[name]
    return hit.command == dimencode and hit.index or true
end

function tex.iscount(name)
    local hit = cache[name]
    return hit.command == countcode and hit.index or true
end

function tex.istoken(name)
    local hit = cache[name]
    return hit.command == tokencode and hit.index or true
end

function tex.isskip(name)
    local hit = cache[name]
    return hit.command == skipcode and hit.index or true
end

function tex.ismuskip(name)
    local hit = cache[name]
    return hit.command == muskipcode and hit.index or true
end

function tex.type(name)
    return types[cache[name].command] or "macro"
end

function context.setconditional(name,value)
    if value then
        ctxcore.settruevalue(name)
    else
        ctxcore.setfalsevalue(name)
    end
end

function context.setmode(name,value)
    if value then
        ctxcore.setmode(name)
    else
        ctxcore.resetmode(name)
    end
end

function context.setsystemmode(name,value)
    if value then
        ctxcore.setsystemmode(name)
    else
        ctxcore.resetsystemmode(name)
    end
end

context.modes        = texmodes
context.systemmodes  = texsystemmodes
context.conditionals = texconditionals
-------.constants    = texconstants
-------.ifs          = texifs

local sep = S("), ")
local str = C((1-sep)^1)
local tag = P("(") * C((1-S(")" ))^1) * P(")")
local arg = P("(") * C((1-S("){"))^1) * P("{") * C((1-P("}"))^0) * P("}") * P(")")

local pattern = (
     P("lua") * tag        / ctxcore.luasetup
  +  P("xml") * arg        / ctxcore.setupwithargument -- or xmlw as xmlsetup has swapped arguments
  + (P("tex") * tag + str) / ctxcore.texsetup
  +             sep^1
)^1

interfaces.implement {
    name      = "autosetups",
    actions   = function(str) lpegmatch(pattern,str) end,
    arguments = "string"
}
