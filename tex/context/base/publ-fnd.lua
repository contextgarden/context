if not modules then modules = { } end modules ['publ-fnd'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not characters then
    dofile(resolvers.findfile("char-def.lua"))
    dofile(resolvers.findfile("char-utf.lua"))
end

-- this tracker is only for real debugging and not for the average user

local trace_match = false  trackers.register("publications.match", function(v) trace_match = v end)

local publications = publications

local tonumber, next, type = tonumber, next, type
local find = string.find
local P, R, S, C, Cs, Cp, Cc, Carg, Ct, V = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cp, lpeg.Cc, lpeg.Carg, lpeg.Ct, lpeg.V
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local concat = table.concat

local formatters = string.formatters
local lowercase  = characters.lower
local topattern  = string.topattern

publications = publications or { } -- for testing

local report     = logs.reporter("publications","match")

local colon    = P(":")
local dash     = P("-")
local lparent  = P("(")
local rparent  = P(")")
local space    = lpegpatterns.whitespace
local utf8char = lpegpatterns.utf8character
local valid    = 1 - colon - space - lparent - rparent
----- key      = C(valid^1)
local key      = C(R("az","AZ")^1)
local wildcard = C("*")
local word     = Cs(lpegpatterns.unquoted + lpegpatterns.argument + valid^1)
local simple   = C(valid^1)
local number   = C(valid^1)

local key      = C(R("az","AZ")^1)
local contains = S(":~")
local exact    = P("=")
local valid    = (1 - space - lparent -rparent)^1
local wildcard = P("*") / ".*"
local single   = P("?") / "."
local dash     = P("-") / "%."
local percent  = P("-") / "%%"
local word     = Cs(lpegpatterns.unquoted + lpegpatterns.argument + valid)
local range    = P("<") * space^0 * C((1-space)^1) * space^1 * C((1-space- P(">"))^1) * space^0 * P(">")

local f_key_fld      = formatters["  local kf_%s = get(entry,%q)           \n  if kf_%s then kf_%s = lower(kf_%s) end"]
local f_key_set      = formatters["  local ks_%s = get(entry,%q,categories)\n  if ks_%s then ks_%s = lower(ks_%s) end"]
local f_number_fld   = formatters["  local nf_%s = tonumber(get(entry,%q))"]
local f_number_set   = formatters["  local ns_%s = tonumber(get(entry,%q,categories))"]

local f_fld_exact    = formatters["(kf_%s == %q)"]
local f_set_exact    = formatters["(ks_%s == %q)"]
local f_fld_contains = formatters["(kf_%s and find(kf_%s,%q))"]
local f_set_contains = formatters["(ks_%s and find(ks_%s,%q))"]
local f_fld_between  = formatters["(nf_%s and nf_%s >= %s and nf_%s <= %s)"]
local f_set_between  = formatters["(ns_%s and ns_%s >= %s and ns_%s <= %s)"]

local f_all_match    = formatters["anywhere(entry,%q)"]

local function test_key_value(keys,where,key,first,last)
    if not key or key == "" then
        return "(false)"
    elseif key == "*" then
        last = "^.*" .. topattern(lowercase(last)) .. ".*$" -- todo: make an lpeg
        return f_all_match(last)
    elseif first == false then
        -- exact
        last = lowercase(last)
        if where == "set" then
            keys[key] = f_key_set(key,key,key,key,key)
            return f_set_exact(key,last)
        else
            keys[key] = f_key_fld(key,key,key,key,key)
            return f_fld_exact(key,last)
        end
    elseif first == true then
        -- contains
        last = "^.*" .. topattern(lowercase(last)) .. ".*$"
        if where == "set" then
            keys[key] = f_key_set(key,key,key,key,key)
            return f_set_contains(key,key,last)
        else
            keys[key] = f_key_fld(key,key,key,key,key)
            return f_fld_contains(key,key,last)
        end
    else
        -- range
        if where == "set" then
            keys[key] = f_number_set(key,key)
            return f_set_between(key,key,tonumber(first),key,tonumber(last))
        else
            keys[key] = f_number_fld(key,key)
            return f_fld_between(key,key,tonumber(first),key,tonumber(last))
        end
    end
end

local p_compare = P { "all",
    all      = (V("one") + V("operator") + V("nested") + C(" "))^1,
    nested   = C("(") * V("all") * C(")"), -- C really needed?
    operator = C("and")
             + C("or")
             + C("not"),
    one      = Carg(1)
             * V("where")
             * V("key")
             * (V("how") * V("word") + V("range"))
             / test_key_value,
    key      = key
             + C("*"),
    where    = C("set") * P(":")
             + Cc(""),
    how      = contains * Cc(true)
             + exact * Cc(false),
    word     = word,
    range    = range,
}

-- local p_combine = space^0 * (P(",")/" or ") * space^0

-- local  pattern = Cs((P("match")/"" * space^0 * p_compare + p_combine)^1)

local comma        = P(",")
local p_spaces     = space^0
local p_combine    = p_spaces * comma * p_spaces / " or "
local p_expression = P("match")/"" * Cs(p_compare)
                   + Carg(1)
                   * Cc("")
                   * Cc("tag")
                   * Cc(false)
                   * (
                        P("tag") * p_spaces * P("(") * Cs((1-S(")")-space)^1) * p_spaces * P(")")
                      + p_spaces * Cs((1-space-comma)^1) * p_spaces
                     ) / test_key_value

local pattern = Cs {
    [1] = V(2) * (p_combine * V(2))^0,
    [2] = p_expression,
}

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --

function publications.anywhere(entry,str) -- helpers
    for k, v in next, entry do
        if find(lowercase(v),str) then
            return true
        end
    end
end

-- todo: use an environment instead of

-- table={
--  { "match", "((kf_editor and find(kf_editor,\"^.*braslau.*$\")))" },
--  { "hash", "foo1234" },
--  { "tag", "bar5678" },
-- }

local f_template = formatters[ [[
local find = string.find
local lower = characters.lower
local anywhere = publications.anywhere
local get = publications.getfuzzy
local specification = publications.currentspecification
local categories = specification and specification.categories
return function(entry)
%s
  return %s and true or false
end
]] ]

local function compile(dataset,expr)
    local keys        = { }
 -- local expression  = lpegmatch(pattern,expr,start,keys)
    local expression  = lpegmatch(pattern,expr,1,keys)
    if trace_match then
        report("compiling expression: %s",expr)
    end
    local definitions = { }
    for k, v in next, keys do
        definitions[#definitions+1] = v
    end
    if #definitions == 0 then
        report("invalid expression: %s",expr)
    elseif trace_match then
        for i=1,#definitions do
            report("% 3i : %s",i,definitions[i])
        end
    end
    definitions = concat(definitions,"\n")
    local code = f_template(definitions,expression)
    if trace_match then
        report("generated code: %s",code)
    end
    local finder = loadstring(code) -- use an environment
    if type(finder) == "function" then
        finder = finder()
        if type(finder) == "function" then
            return finder, code
        end
    end
    report("invalid expression: %s",expr)
    return false
end

-- local function test(str)
--     local keys        = { }
--     local definitions = { }
--     local expression  = lpegmatch(pattern,str,1,keys)
--     for k, v in next, keys do
--         definitions[#definitions+1] = v
--     end
--     definitions = concat(definitions,"\n")
--     print(f_template(definitions,expression))
-- end

-- test("match(foo:bar and (foo:bar or foo:bar))")
-- test("match(foo=bar and (foo=bar or foo=bar))")
-- test("match(set:foo:bar),match(set:foo:bar)")
-- test("match(set:foo=bar)")
-- test("match(foo:{bar bar})")
-- test("match(foo={bar bar})")
-- test("match(set:foo:'bar bar')")
-- test("match(set:foo='bar bar')")
-- test("match(set:foo<1000 2000>)")
-- test("match(set:foo<1000 2000>)")
-- test("match(*:foo)")
-- test("match(*:*)")

local trigger = (P("match") + P("tag")) * p_spaces * P("(")
local check   = (1-trigger)^0 * trigger

local function finder(dataset,expression)
    local found = lpegmatch(check,expression) and compile(dataset,expression) or false
    if found then
        local okay, message = pcall(found,{})
        if not okay then
            found = false
            report("error in match: %s",message)
        end
    end
    return found
end

-- finder("match(author:foo)")
-- finder("match(author:foo and author:bar)")
-- finder("match(author:foo or (author:bar and page:123))")
-- finder("match(author:foo),match(author:foo)")

publications.finder = finder

function publications.search(dataset,expression)
    local find = finder(dataset,expression)
    if find then
        local ordered = dataset.ordered
        local target  = { }
        for i=1,#ordered do
            local entry = ordered[i]
            if find(entry) then
                local tag = entry.tag
                if not target[tag] then
                    -- we always take the first
                    target[tag] = entry
                end
            end
        end
        return target
    else
        return { } -- { dataset.luadata[expression] } -- ?
    end
end

-- local d = publications.datasets.default
--
-- local d = publications.load {
--     dataset   = "default",
--     filename = "t:/manuals/mkiv/hybrid/tugboat.bib"
-- }
--
-- inspect(publications.search(d,[[match(author:hagen)]]))
-- inspect(publications.search(d,[[match(author:hagen and author:hoekwater and year:1990-2010)]]))
-- inspect(publications.search(d,[[match(author:"Bogusław Jackowski")]]))
-- inspect(publications.search(d,[[match(author:"Bogusław Jackowski" and (tonumber(field:year) or 0) > 2000)]]))
-- inspect(publications.search(d,[[Hagen:TB19-3-304]]))
