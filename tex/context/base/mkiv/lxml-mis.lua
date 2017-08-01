if not modules then modules = { } end modules ['lxml-mis'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local xml, lpeg, string = xml, lpeg, string

local type = type
local concat = table.concat
local format, gsub, match = string.format, string.gsub, string.match
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, S, R, C, V, Cc, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Cs

lpegpatterns.xml  = lpegpatterns.xml or { }
local xmlpatterns = lpegpatterns.xml

--[[ldx--
<p>The following helper functions best belong to the <t>lxml-ini</t>
module. Some are here because we need then in the <t>mk</t>
document and other manuals, others came up when playing with
this module. Since this module is also used in <l n='mtxrun'/> we've
put them here instead of loading mode modules there then needed.</p>
--ldx]]--

local function xmlgsub(t,old,new) -- will be replaced
    local dt = t.dt
    if dt then
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "string" then
                dt[k] = gsub(v,old,new)
            else
                xmlgsub(v,old,new)
            end
        end
    end
end

-- xml.gsub = xmlgsub

function xml.stripleadingspaces(dk,d,k) -- cosmetic, for manual
    if d and k then
        local dkm = d[k-1]
        if dkm and type(dkm) == "string" then
            local s = match(dkm,"\n(%s+)")
            xmlgsub(dk,"\n"..rep(" ",#s),"\n")
        end
    end
end

-- xml.escapes   = { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }
-- xml.unescapes = { } for k,v in next, xml.escapes do xml.unescapes[v] = k end

-- function xml.escaped  (str) return (gsub(str,"(.)"   , xml.escapes  )) end
-- function xml.unescaped(str) return (gsub(str,"(&.-;)", xml.unescapes)) end
-- function xml.cleansed (str) return (gsub(str,"<.->"  , ''           )) end -- "%b<>"

-- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
--
-- 1021:0335:0287:0247

-- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
--
-- 1559:0257:0288:0190 (last one suggested by roberto)

----- escaped = Cs((S("<&>") / xml.escapes + 1)^0)
----- escaped = Cs((S("<")/"&lt;" + S(">")/"&gt;" + S("&")/"&amp;" + 1)^0)
local normal  = (1 - S("<&>"))^0
local special = P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;"
local escaped = Cs(normal * (special * normal)^0)

-- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

local normal    = (1 - S"&")^0
local special   = P("&lt;")/"<" + P("&gt;")/">" + P("&amp;")/"&"
local unescaped = Cs(normal * (special * normal)^0)

-- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

local cleansed = Cs(((P("<") * (1-P(">"))^0 * P(">"))/"" + 1)^0)

xmlpatterns.escaped   = escaped
xmlpatterns.unescaped = unescaped
xmlpatterns.cleansed  = cleansed

function xml.escaped  (str) return lpegmatch(escaped,str)   end
function xml.unescaped(str) return lpegmatch(unescaped,str) end
function xml.cleansed (str) return lpegmatch(cleansed,str)  end

-- this might move

function xml.fillin(root,pattern,str,check)
    local e = xml.first(root,pattern)
    if e then
        local n = #e.dt
        if not check or n == 0 or (n == 1 and e.dt[1] == "") then
            e.dt = { str }
        end
    end
end
