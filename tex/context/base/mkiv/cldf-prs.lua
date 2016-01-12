if not modules then modules = { } end modules ['cldf-bas'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in chem-ini.lua

local lpegmatch, patterns = lpeg.match, lpeg.patterns
local P, R, V, Cc, Cs = lpeg.P, lpeg.R, lpeg.V, lpeg.Cc, lpeg.Cs
local format = string.format

local cpatterns     = patterns.context or { }
patterns.context    = cpatterns

local utf8character = patterns.utf8character
local cardinal      = patterns.cardinal

local leftbrace     = P("{")
local rightbrace    = P("}")
local backslash     = P("\\")
local csname        = backslash * P(1) * (1-backslash-leftbrace)^0 * P(" ")^0
local sign          = P("+") / "\\textplus "
                    + P("-") / "\\textminus "
local nested        = P { leftbrace * (V(1) + (1-rightbrace))^0 * rightbrace }
local subscript     = P("_")
local superscript   = P("^")

-- local scripts    = P { "start",
--                        start     = V("csname") + V("lowfirst") + V("highfirst"),
--                        csname    = csname,
--                        content   = Cs(V("csname") + nested + sign^-1 * (cardinal + utf8character)),
--                        lowfirst  = subscript   * ( Cc("\\lohi{%s}{%s}") * V("content") * superscript + Cc("\\low{%s}" ) ) * V("content") / format,
--                        highfirst = superscript * ( Cc("\\hilo{%s}{%s}") * V("content") * subscript   + Cc("\\high{%s}") ) * V("content") / format,
--                    }

-- local scripts    = P { "start",
--                           start     = (V("csname") + V("lowfirst") + V("highfirst"))^1,
--                           csname    = csname,
--                           content   = Cs(V("csname") + nested + sign^-1 * (cardinal + utf8character)),
--                           lowfirst  = (subscript  /"") * ( Cc("\\lohi{") * V("content") * Cc("}{") * (superscript/"") + Cc("\\low{" ) ) * V("content") * Cc("}"),
--                           highfirst = (superscript/"") * ( Cc("\\hilo{") * V("content") * Cc("}{") * (subscript  /"") + Cc("\\high{") ) * V("content") * Cc("}"),
--                       }

local scripted      = Cs { "start",
                          start     = (V("csname") + V("nested") + V("lowfirst") + V("highfirst") + V("character"))^1,
                          rest      = V("csname") + V("nested") + V("lowfirst") + V("highfirst"),
                          csname    = csname,
                          character = utf8character,
                       -- nested    = leftbrace * (V("rest") + (V("character")-rightbrace))^0 * rightbrace,
                          nested    = leftbrace * (V("start") -rightbrace)^0 * rightbrace,
                       -- content   = Cs(V("nested") + sign^-1 * (cardinal + V("character"))),
                          content   = V("nested") + sign^-1 * (cardinal + V("character")) + sign,
                          lowfirst  = (subscript  /"") * ( Cc("\\lohi{") * V("content") * Cc("}{") * (superscript/"") + Cc("\\low{" ) ) * V("content") * Cc("}"),
                          highfirst = (superscript/"") * ( Cc("\\hilo{") * V("content") * Cc("}{") * (subscript  /"") + Cc("\\high{") ) * V("content") * Cc("}"),
                      }

cpatterns.csname    = csname
cpatterns.scripted  = scripted
cpatterns.nested    = nested

-- print(lpegmatch(scripted,"10^-3_x"))
-- print(lpegmatch(scripted,"\\L {C_5}"))
-- print(lpegmatch(scripted,"\\SL{}"))
-- print(lpegmatch(scripted,"\\SL{C_5}"))
-- print(lpegmatch(scripted,"\\SL{C_5}"))
-- print(lpegmatch(scripted,"{C_5}"))
-- print(lpegmatch(scripted,"{\\C_5}"))
-- print(lpegmatch(scripted,"10^-a"))

