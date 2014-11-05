if not modules then modules = { } end modules ['meta-tex'] = {
    version   = 1.001,
    comment   = "companion to meta-tex.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gsub, find, match = string.format, string.gsub, string.find, string.match
local formatters = string.formatters
local P, S, R, C, Cs, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.match

metapost = metapost or { }

-- local left     = P("[")
-- local right    = P("]")
-- local space    = P(" ")
-- local argument = left * C((1-right)^1) * right
-- local pattern  = (argument + space)^0

-- function metapost.sometxt(optional,str)
--     if optional == "" then
--         context.sometxta(str)
--     else
--         local one, two = lpegmatch(pattern,optional)
--         if two then
--             context.sometxtc(one,two,str)
--         elseif one then
--             context.sometxtb(one,str)
--         else
--             context.sometxta(str)
--         end
--     end
-- end

local pattern = Cs((P([[\"]]) + P([["]])/"\\quotedbl{}" + P(1))^0) -- or \char

function metapost.escaped(str)
    context(lpegmatch(pattern,str))
end

local simplify = true

-- local function strip(n,e)
--     -- get rid of e(0)
--     -- get rid of e(+*)
--     e = gsub(e,"^+","")
--     -- remove leading zeros
--     e = gsub(e,"^([+-]*)0+(%d)","%1%2")
--     if not simplify then
--         -- take it as it is
--     elseif n == "1" then
--         return format("10^{%s}",e)
--     end
--     return format("%s\\times10^{%s}",n,e)
-- end
--
-- function metapost.format_n(fmt,...)
--     fmt = gsub(fmt,"@","%%")
--     local initial, hasformat, final = match(fmt,"^(.-)(%%.-[%a])(.-)$")
--     if hasformat then
--         str = format(fmt,...)
--         str = gsub(str,"(.-)e(.-)$",strip)
--         str = format("%s\\mathematics{%s}%s",initial,str,final)
--     elseif not find(fmt,"%%") then
--         str = format("%"..fmt,...)
--         str = gsub(str,"(.-)e(.-)$",strip)
--         str = format("\\mathematics{%s}",str)
--     end
--     context(str)
-- end

-- todo: proper lpeg

-- local function strip(n,e)
--     -- get rid of e(0)
--     -- get rid of e(+*)
--     e = gsub(e,"^+","")
--     -- remove leading zeros
--     e = gsub(e,"^([+-]*)0+(%d)","%1%2")
--     if not simplify then
--         -- take it as it is
--     elseif n == "1" then
--         return format("\\mathematics{10^{%s}}",e)
--     end
--     return format("\\mathematics{%s\\times10^{%s}}",n,e)
-- end
--
-- function metapost.format_n(fmt,...)
--     fmt = gsub(fmt,"@","%%")
--     if find(fmt,"%%") then
--         str = format(fmt,...)
--     else -- yes or no
--         str = format("%"..fmt,...)
--     end
--     str = gsub(str,"([%-%+]-[%.%d]+)e([%-%+]-[%.%d]+)",strip)
--     context(str)
-- end
--
-- function metapost.format_v(fmt,str)
--     metapost.format_n(fmt,metapost.untagvariable(str,false))
-- end

-- -- --

local number  = C((S("+-")^0 * R("09","..")^1))
local enumber = number * S("eE") * number

local cleaner = Cs((P("@@")/"@" + P("@")/"%%" + P(1))^0)

context = context or { exponent = function(...) print(...) end }

function metapost.format_string(fmt,...)
    context(lpegmatch(cleaner,fmt),...)
end

function metapost.format_number(fmt,num)
    local number = tonumber(num)
    if number then
        local base, exponent = lpegmatch(enumber,formatters[lpegmatch(cleaner,fmt)](number))
        if base and exponent then
            context.MPexponent(base,exponent)
        else
            context(number)
        end
    else
        context(tostring(num))
    end
end

-- This is experimental and will change!

function metapost.svformat(fmt,str)
    metapost.format_string(fmt,metapost.untagvariable(str,false))
end

function metapost.nvformat(fmt,str)
    metapost.format_number(fmt,metapost.untagvariable(str,false))
end

-- local function test(fmt,n)
--     logs.report("mp format test","fmt: %s, n: %s, result: %s, \\exponent{%s}{%s}",fmt,n,
--         formatters[lpegmatch(cleaner,fmt)](n),
--         lpegmatch(enumber,formatters[lpegmatch(cleaner,fmt)](n))
--     )
-- end
--
-- test("@j","1e-8")
-- test("@j",1e-8)
-- test("@j","1e+8")
-- test("@j","1e-10")
-- test("@j",1e-10)
-- test("@j","1e+10")
-- test("@j","1e-12")
-- test("@j","1e+12")
-- test("@j","1e-0")
-- test("@j","1e+0")
-- test("@j","1")
-- test("@j test","1")
-- test("@j","-1")
-- test("@j","1e-102")
-- test("@1.4j","1e+102")
-- test("@j","1.2e+102")
-- test("@j","1.23e+102")
-- test("@j","1.234e+102")
