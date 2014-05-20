if not modules then modules = { } end modules ['publ-fnd'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, next = tonumber, next
local P, R, C, Cs, Carg = lpeg.P, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Carg
local lpegmatch = lpeg.match
local concat = table.concat
local find = string.find

local formatters = string.formatters
local lowercase  = characters.lower

local colon   = P(":")
local dash    = P("-")
local lparent = P("(")
local rparent = P(")")
local space   = lpeg.patterns.whitespace
local valid   = 1 - colon - space - lparent - rparent
local key     = C(valid^1)
local key     = C(R("az","AZ")^1)
local word    = Cs(lpeg.patterns.unquoted + valid^1)
local number  = C(valid^1)

----- f_string_key = formatters["  local s_%s = entry[%q]"]
local f_string_key = formatters["  local s_%s = entry[%q] if s_%s then s_%s = lower(s_%s) end "]
local f_number_key = formatters["  local n_%s = tonumber(entry[%q]) or 0"]
local f_field_key  = formatters["  local f_%s = entry[%q] or ''"]

----- f_string_match = formatters["(s_%s and find(lower(s_%s),%q))"]
local f_string_match = formatters["(s_%s and find(s_%s,%q))"]
local f_number_match = formatters["(n_%s and n_%s >= %s and n_%s <= %s)"]
local f_field_match  = formatters["f_%s"]

local match  = key * (colon/"") * word * Carg(1) / function(key,_,word,keys)
 -- keys[key] = f_string_key(key,key)
    keys[key] = f_string_key(key,key,key,key,key)
    return f_string_match(key,key,lowercase(word))
end

local range  = key * (colon/"") * number * (dash/"") * number * Carg(1)  / function(key,_,first,_,last,keys)
    keys[key] = f_number_key(key,key)
    return f_number_match(key,key,tonumber(first) or 0,key,tonumber(last) or 0)
end

local field  = (P("field:")/"") * key * Carg(1) / function(_,key,keys)
    keys[key] = f_field_key(key,key)
    return f_field_match(key)
end

----- pattern = Cs((field + range + match + P(1))^1)
----- b_match = P("match")/"" * lparent
local b_match = lparent
local e_match = rparent * P(-1)
local pattern = Cs(b_match * ((field + range + match + P(1))-e_match)^1 * e_match)

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --

local tolower  = lpeg.patterns.tolower
local lower    = string.lower

local allascii = R("\000\127")^1 * P(-1)

function characters.checkedlower(str)
    return lpegmatch(allascii,str) and lower(str) or lpegmatch(tolower,str) or str
end

-- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- --

local f_template = string.formatters[ [[
local find = string.find
local lower = characters.checkedlower
return function(entry)
%s
return %s and true or false
end
]] ]

local function compile(expr,start)
    local keys        = { }
    local expression  = lpegmatch(pattern,expr,start,keys)
 -- print("!!!!",expression)
    local definitions = { }
    for k, v in next, keys do
        definitions[#definitions+1] = v
    end
    definitions = concat(definitions,"\n")
    local code = f_template(definitions,expression)
 -- print(code)
    code = loadstring(code)
    if type(code) == "function" then
        code = code()
        if type(code) == "function" then
            return code
        end
    end
    print("no valid expression",expression)
    return false
end

local cache = { } -- todo: make weak, or just remember the last one (trial typesetting)

local function finder(expression)
    local b, e = find(expression,"^match")
    if e then
        local found  = cache[expression]
        if found == nil then
            found = compile(expression,e+1) or false
            cache[expression] = found
        end
        return found
    end
end

publications.finder = finder

function publications.search(dataset,expression)
    local find   = finder(expression)
    local source = dataset.luadata
    if find then
        local target = { }
        for k, v in next, source do
            if find(v) then
                target[k] = v
            end
        end
        return target
    else
        return { source[expression] }
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
