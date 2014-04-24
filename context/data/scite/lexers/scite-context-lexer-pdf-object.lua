local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S, C, V = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.V

local lexer             = require("lexer")
local context           = lexer.context
local patterns          = context.patterns

local token             = lexer.token

local pdfobjectlexer    = lexer.new("pdf-object","scite-context-lexer-pdf-object")
local whitespace        = pdfobjectlexer.whitespace

local space             = patterns.space
local somespace         = space^1

local newline           = paterns.eol
local real              = patterns.real
local cardinal          = patterns.cardinal

local lparent           = P("(")
local rparent           = P(")")
local langle            = P("<")
local rangle            = P(">")
local escape            = P("\\")
local anything          = P(1)
local unicodetrigger    = P("feff")

local nametoken         = 1 - space - S("<>/[]()")
local name              = P("/") * nametoken^1

local p_string          = P { ( escape * anything + lparent * V(1) * rparent + (1 - rparent) )^0 }

local t_spacing         = token(whitespace, space^1)
local t_spaces          = token(whitespace, space^1)^0

local p_stream          = P("stream")
local p_endstream       = P("endstream")
----- p_obj             = P("obj")
local p_endobj          = P("endobj")
local p_reference       = P("R")

local p_objectnumber    = patterns.cardinal
local p_comment         = P('%') * (1-S("\n\r"))^0

local string            = token("quote",    lparent)
                        * token("string",   p_string)
                        * token("quote",    rparent)
local unicode           = token("quote",    langle)
                        * token("plain",    unicodetrigger)
                        * token("string",   (1-rangle)^1)
                        * token("quote",    rangle)
local whatsit           = token("quote",    langle)
                        * token("string",   (1-rangle)^1)
                        * token("quote",    rangle)
local keyword           = token("command",  name)
local constant          = token("constant", name)
local number            = token('number',   real)
-- local reference         = token("number",   cardinal)
--                         * t_spacing
--                         * token("number",   cardinal)
local reserved          = token("number", P("true") + P("false") + P("NULL"))
local reference         = token("warning",   cardinal)
                        * t_spacing
                        * token("warning",   cardinal)
                        * t_spacing
                        * token("keyword",  p_reference)
local t_comment         = token("comment",  p_comment)

--    t_openobject      = token("number",  p_objectnumber)
--                      * t_spacing
--                      * token("number",  p_objectnumber)
--                      * t_spacing
--                      * token("keyword", p_obj)
local t_closeobject     = token("keyword", p_endobj)

local t_opendictionary  = token("grouping", P("<<"))
local t_closedictionary = token("grouping", P(">>"))

local t_openarray       = token("grouping", P("["))
local t_closearray      = token("grouping", P("]"))

local t_stream          = token("keyword", p_stream)
--                         * token("default", newline * (1-newline*p_endstream*newline)^1 * newline)
                        * token("default", (1 - p_endstream)^1)
                        * token("keyword", p_endstream)

local t_dictionary      = { "dictionary",
                            dictionary = t_opendictionary * (t_spaces * keyword * t_spaces * V("whatever"))^0 * t_spaces * t_closedictionary,
                            array      = t_openarray * (t_spaces * V("whatever"))^0 * t_spaces * t_closearray,
                            whatever   = V("dictionary") + V("array") + constant + reference + string + unicode + number + whatsit,
                        }

local t_object          = { "object", -- weird that we need to catch the end here (probably otherwise an invalid lpeg)
                            object     = t_spaces * (V("dictionary") * t_spaces * t_stream^-1 + V("array") + V("number") + t_spaces) * t_spaces * t_closeobject,
                            dictionary = t_opendictionary * (t_spaces * keyword * t_spaces * V("whatever"))^0 * t_spaces * t_closedictionary,
                            array      = t_openarray * (t_spaces * V("whatever"))^0 * t_spaces * t_closearray,
                            number     = number,
                            whatever   = V("dictionary") + V("array") + constant + reference + string + unicode + number + reserved + whatsit,
                        }

pdfobjectlexer._shared = {
    dictionary = t_dictionary,
}

pdfobjectlexer._rules = {
    { 'whitespace', t_spacing },
    { 'object',     t_object  },
}

pdfobjectlexer._tokenstyles = context.styleset

return pdfobjectlexer
