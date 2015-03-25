if not modules then modules = { } end modules ['syst-aux'] = {
    version   = 1.001,
    comment   = "companion to syst-aux.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- slower than lpeg:
--
-- utfmatch(str,"(.?)(.*)$")
-- utf.sub(str,1,1)

local tonumber = tonumber
local format = string.format
local utfsub = utf.sub
local P, S, R, C, Cc, Cs, Carg, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Carg, lpeg.match
local todimen = number.todimen

local commands          = commands
local context           = context

local setcatcode        = tex.setcatcode

local utf8character     = lpeg.patterns.utf8character
local settings_to_array = utilities.parsers.settings_to_array

local setvalue          = context.setvalue

local pattern           = C(utf8character^-1) * C(P(1)^0)

function commands.getfirstcharacter(str)
    local first, rest = lpegmatch(pattern,str)
    setvalue("firstcharacter",first)
    setvalue("remainingcharacters",rest)
end

function commands.thefirstcharacter(str)
    local first, rest = lpegmatch(pattern,str)
    context(first)
end
function commands.theremainingcharacters(str)
    local first, rest = lpegmatch(pattern,str)
    context(rest)
end

local pattern = C(utf8character^-1)

function commands.doiffirstcharelse(chr,str)
    commands.doifelse(lpegmatch(pattern,str) == chr)
end

function commands.getsubstring(str,first,last)
    context(utfsub(str,tonumber(first),tonumber(last)))
end

-- function commands.addtocommalist(list,item)
--     if list == "" then
--         context(item)
--     else
--         context("%s,%s",list,item) -- using tex.print is some 10% faster
--     end
-- end
--
-- function commands.removefromcommalist(list,item)
--     if list == "" then
--         context(item)
--     else
--         -- okay, using a proper lpeg is probably faster
--         -- we could also check for #l = 1
--         local l = settings_to_array(list)
--         local t, n = { }
--         for i=1,#l do
--             if l[i] ~= item then
--                 n = n + 1
--                 t[n] = item
--             end
--         end
--         if n == 0 then
--             context(item)
--         else
--             context(concat(list,","))
--         end
--     end
-- end

local pattern = (C((1-P("%"))^1) * Carg(1)) /function(n,d) return format("%.0fsp",d * tonumber(n)/100) end * P("%") * P(-1) -- .0 ?

-- commands.percentageof("10%",65536*10)

function commands.percentageof(str,dim)
    context(lpegmatch(pattern,str,1,dim) or str)
end

-- \gdef\setpercentdimen#1#2%
--   {#1=\ctxcommand{percentageof("#2",\number#1)}\relax}

local spaces    = P(" ")^0 / ""
local nohash    = 1 - P("#")
local digit     = R("09")
local double    = P("##") / "#"
local single    = P("#")
local sentinel  = spaces * (nohash^1 / "\\%0")
local sargument = (single * digit)^1
local dargument = (double * digit)^1

local usespaces   = nil
local texpreamble = nil

local pattern = Cs( -- ^-1
    ( P("spaces") / function() usespaces = true return "" end )^0
  * spaces
  * ( P("nospaces") / function() usespaces = false return "" end )^0
  * spaces
  * ( P("global") / "\\global" )^0
  * spaces
  * ( P("unexpanded") / "\\unexpanded" )^0
  * spaces
  * Cc("\\expandafter\\")
  * spaces
  * ( P("expanded") / "e" )^0
  * spaces
  * ( P((1-S(" #"))^1) / "def\\csname %0\\endcsname" )
  * spaces
  * (
   --   (double * digit)^1 * sentinel^-1 * double^-1
   -- + (single * digit)^1 * sentinel^-1 * single^-1
        ( P("[") * dargument * P("]") + dargument)^1 * sentinel^-1 * double^-1
      + ( P("[") * sargument * P("]") + sargument)^1 * sentinel^-1 * single^-1
      + sentinel^-1 * (double+single)^-1
    )
)

local ctx_dostarttexdefinition = context.dostarttexdefinition

function commands.texdefinition_1(str)
    usespaces   = nil
    texpreamble = lpegmatch(pattern,str)
    if usespaces == true then
        setcatcode(32,10) -- space
        setcatcode(13, 5) -- endofline
    elseif usespaces == false then
        setcatcode(32, 9) -- ignore
        setcatcode(13, 9) -- ignore
    else
        -- this is default
     -- setcatcode(32,10) -- space
     -- setcatcode(13, 9) -- ignore
    end
    ctx_dostarttexdefinition()
end

function commands.texdefinition_2()
    context(texpreamble)
end

local upper, lower, strip = utf.upper, utf.lower, string.strip

function commands.upper(s) context(upper(s)) end
function commands.lower(s) context(lower(s)) end
function commands.strip(s) context(strip(s)) end

function commands.converteddimen(dimen,unit) context(todimen(dimen,unit or "pt","%0.5f")) end -- no unit appended (%F)
