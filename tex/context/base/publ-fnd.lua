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
local P, R, C, Cs, Cp, Cc, Carg = lpeg.P, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Cp, lpeg.Cc, lpeg.Carg
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local concat = table.concat

local formatters = string.formatters
local lowercase  = characters.lower

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

----- f_string_key = formatters["  local s_%s = entry[%q]"]
local f_string_key = formatters["  local s_%s = entry[%q] if s_%s then s_%s = lower(s_%s) end "]
local f_number_key = formatters["  local n_%s = tonumber(entry[%q]) or 0"]
local f_field_key  = formatters["  local f_%s = entry[%q] or ''"]

----- f_string_match = formatters["(s_%s and find(lower(s_%s),%q))"]
local f_string_match = formatters["(s_%s and find(s_%s,%q))"]
local f_number_match = formatters["(n_%s and n_%s >= %s and n_%s <= %s)"]
local f_field_match  = formatters["f_%s"]

local f_all_match = formatters["anywhere(entry,%q)"]

local match  = ( (key + wildcard) * (colon/"") ) * word * Carg(1) / function(key,_,word,keys)
    if key == "*" or key == "any" then
        keys.anywhere = true
        return f_all_match(lowercase(word))
    else
        keys[key] = f_string_key(key,key,key,key,key)
        return f_string_match(key,key,lowercase(word))
    end
end

local default = simple * Carg(1) / function(word,keys)
    keys.anywhere = true
    return f_all_match(lowercase(word))
end

local range  = key * (colon/"") * number * (dash/"") * number * Carg(1)  / function(key,_,first,_,last,keys)
    keys[key] = f_number_key(key,key)
    return f_number_match(key,key,tonumber(first) or 0,key,tonumber(last) or 0)
end

local field  = (P("field:")/"") * key * Carg(1) / function(_,key,keys)
    keys[key] = f_field_key(key,key)
    return f_field_match(key)
end

----- b_match = lparent
----- e_match = rparent * space^0 * P(-1)
----- pattern = Cs(b_match * ((field + range + match + space + P(1))-e_match)^1 * e_match)

local b_match = lparent
local e_match = rparent * space^0 * (#P(-1) + P(",")/" or ") -- maybe also + -> and
local f_match = ((field + range + match + space + P(1))-e_match)^1
local p_match = b_match * default * e_match +
b_match * f_match * e_match

local pattern = Cs(Cc("(") * (P("match")/"" * space^0 * p_match)^1 * Cc(")"))

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --

-- no longer faster
--
-- local tolower  = lpegpatterns.tolower
-- local lower    = string.lower
--
-- local allascii = R("\000\127")^1 * P(-1)
--
-- function characters.checkedlower(str)
--     return lpegmatch(allascii,str) and lower(str) or lpegmatch(tolower,str) or str
-- end

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --

function publications.anywhere(entry,str) -- helpers
    for k, v in next, entry do
        if find(lowercase(v),str) then
            return true
        end
    end
end

local f_template = string.formatters[ [[
local find = string.find
local lower = characters.lower
local anywhere = publications.anywhere
return function(entry)
%s
  return %s and true or false
end
]] ]

----- function compile(expr,start)
local function compile(expr)
    local keys        = { }
 -- local expression  = lpegmatch(pattern,expr,start,keys)
    local expression  = lpegmatch(pattern,expr,1,keys)
    if trace_match then
        report("compiling expression: %s",expr)
    end
    local definitions = { }
    local anywhere    = false
    for k, v in next, keys do
        if k == "anywhere" then
            anywhere = true
        else
            definitions[#definitions+1] = v
        end
    end
    if not anywhere and #definitions == 0 then
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
    code = loadstring(code)
    if type(code) == "function" then
        code = code()
        if type(code) == "function" then
            return code
        end
    end
    report("invalid expression: %s",expr)
    return false
end

-- print(lpegmatch(pattern,"match ( author:cleveland and year:1993 ) "),1,{})

-- compile([[match(key:"foo bar")]])
-- compile([[match(key:'foo bar')]])
-- compile([[match(key:{foo bar})]])

local cache = { } -- todo: make weak, or just remember the last one (trial typesetting)

local check = P("match") -- * space^0 * Cp()

local function finder(expression)
    local found = cache[expression]
    if found == nil then
     -- local e = lpegmatch(check,expression)
     -- found = e and compile(expression,e) or false
        found = lpegmatch(check,expression) and compile(expression) or false
        if found then
            local okay, message = pcall(found,{})
            if not okay then
                found = false
                report("error in match: %s",message)
            end
        end
        cache[expression] = found
    end
    return found
end

-- finder("match(author:foo)")
-- finder("match(author:foo and author:bar)")
-- finder("match(author:foo or (author:bar and page:123))")
-- finder("match(author:foo),match(author:foo)")

publications.finder = finder

function publications.search(dataset,expression)
    local find = finder(expression)
    if find then
        local ordered = dataset.ordered
        local target  = { }
        for i=1,#ordered do
            local entry = ordered[i]
            if find(entry) then
                target[entry.tag] = entry
            end
        end
        return target
    else
        return { } -- { dataset.luadata[expression] } -- ?
    end
end

-- local dataset = publications.new()
-- publications.load(dataset,"t:/manuals/hybrid/tugboat.bib")
--
-- local n = 500
--
-- local function test(dataset,str)
--     local found
--     local start = os.clock()
--     for i=1,n do
--         found = search(dataset,str)
--     end
--     local elapsed = os.clock() - start
--     print(elapsed,elapsed/500,#table.keys(dataset.luadata),str)
--     print(table.concat(table.sortedkeys(found)," "))
--     return found
-- end
--
-- local found = test(dataset,[[match(author:hagen)]])
-- local found = test(dataset,[[match(author:hagen and author:hoekwater and year:1990-2010)]])
-- local found = test(dataset,[[match(author:"Bogusław Jackowski")]])
-- local found = test(dataset,[[match(author:"Bogusław Jackowski" and (tonumber(field:year) or 0) > 2000)]])
-- local found = test(dataset,[[Hagen:TB19-3-304]])

-- 1.328	0.002656	2710	author:hagen
-- Berdnikov:TB21-2-129 Guenther:TB5-1-24 Hagen:TB17-1-54 Hagen:TB19-3-304 Hagen:TB19-3-311 Hagen:TB19-3-317 Hagen:TB22-1-58 Hagen:TB22-3-118 Hagen:TB22-3-136 Hagen:TB22-3-160 Hagen:TB23-1-49 Hagen:TB25-1-108 Hagen:TB25-1-48 Hagen:TB26-2-152

-- 1.812	0.003624	2710	author:hagen and author:hoekwater and year:1990-2010
-- Berdnikov:TB21-2-129

-- 1.344	0.002688	2710	author:"Bogusław Jackowski"
-- Berdnikov:TB21-2-129 Jackowski:TB16-4-388 Jackowski:TB19-3-267 Jackowski:TB19-3-272 Jackowski:TB20-2-104 Jackowski:TB24-1-64 Jackowski:TB24-3-575 Nowacki:TB19-3-242 Rycko:TB14-3-171

-- 1.391	0.002782	2710	author:"Bogusław Jackowski" and (tonumber(field:year) or 0) > 2000
-- Jackowski:TB24-1-64 Jackowski:TB24-3-575
