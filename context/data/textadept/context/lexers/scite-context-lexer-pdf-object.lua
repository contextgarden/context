local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf objects",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- no longer used: nesting lexers with whitespace in start/stop is unreliable

local P, R, S, C, V = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.V

local lexer             = require("scite-context-lexer")
local context           = lexer.context
local patterns          = context.patterns

local token             = lexer.token

local pdfobjectlexer    = lexer.new("pdfobj","scite-context-lexer-pdf-object")
local whitespace        = pdfobjectlexer.whitespace

local space             = patterns.space
local spacing           = patterns.spacing
local nospacing         = patterns.nospacing
local anything          = patterns.anything
local newline           = patterns.eol
local real              = patterns.real
local cardinal          = patterns.cardinal

local lparent           = P("(")
local rparent           = P(")")
local langle            = P("<")
local rangle            = P(">")
local escape            = P("\\")
local unicodetrigger    = P("feff")

local nametoken         = 1 - space - S("<>/[]()")
local name              = P("/") * nametoken^1

local p_string          = P { ( escape * anything + lparent * V(1) * rparent + (1 - rparent) )^0 }

local t_spacing         = token(whitespace, spacing)
local t_spaces          = token(whitespace, spacing)^0
local t_rest            = token("default",  nospacing) -- anything

local p_stream          = P("stream")
local p_endstream       = P("endstream")
local p_obj             = P("obj")
local p_endobj          = P("endobj")
local p_reference       = P("R")

local p_objectnumber    = patterns.cardinal
local p_comment         = P("%") * (1-S("\n\r"))^0

local t_string          = token("quote",    lparent)
                        * token("string",   p_string)
                        * token("quote",    rparent)
local t_unicode         = token("quote",    langle)
                        * token("plain",    unicodetrigger)
                        * token("string",   (1-rangle)^1)
                        * token("quote",    rangle)
local t_whatsit         = token("quote",    langle)
                        * token("string",   (1-rangle)^1)
                        * token("quote",    rangle)
local t_keyword         = token("command",  name)
local t_constant        = token("constant", name)
local t_number          = token("number",   real)
--    t_reference       = token("number",   cardinal)
--                      * t_spacing
--                      * token("number",   cardinal)
local t_reserved        = token("number",   P("true") + P("false") + P("NULL"))
local t_reference       = token("warning",  cardinal)
                        * t_spacing
                        * token("warning",  cardinal)
                        * t_spacing
                        * token("keyword",  p_reference)

local t_comment         = token("comment",  p_comment)

local t_openobject      = token("warning",  p_objectnumber * spacing)
--                         * t_spacing
                        * token("warning",  p_objectnumber * spacing)
--                         * t_spacing
                        * token("keyword",  p_obj)
local t_closeobject     = token("keyword",  p_endobj)

local t_opendictionary  = token("grouping", P("<<"))
local t_closedictionary = token("grouping", P(">>"))

local t_openarray       = token("grouping", P("["))
local t_closearray      = token("grouping", P("]"))

-- todo: comment

local t_stream          = token("keyword", p_stream)
--                      * token("default", newline * (1-newline*p_endstream*newline)^1 * newline)
--                         * token("text", (1 - p_endstream)^1)
                        * (token("text", (1 - p_endstream-spacing)^1) + t_spacing)^1
                        * token("keyword", p_endstream)

local t_dictionary      = { "dictionary",
                            dictionary = t_opendictionary * (t_spaces * t_keyword * t_spaces * V("whatever"))^0 * t_spaces * t_closedictionary,
                            array      = t_openarray * (t_spaces * V("whatever"))^0 * t_spaces * t_closearray,
                            whatever   = V("dictionary") + V("array") + t_constant + t_reference + t_string + t_unicode + t_number + t_reserved + t_whatsit,
                        }

----- t_object          = { "object", -- weird that we need to catch the end here (probably otherwise an invalid lpeg)
-----                       object     = t_spaces * (V("dictionary") * t_spaces * t_stream^-1 + V("array") + V("number") + t_spaces) * t_spaces * t_closeobject,
-----                       dictionary = t_opendictionary * (t_spaces * t_keyword * t_spaces * V("whatever"))^0 * t_spaces * t_closedictionary,
-----                       array      = t_openarray * (t_spaces * V("whatever"))^0 * t_spaces * t_closearray,
-----                       whatever   = V("dictionary") + V("array") + t_constant + t_reference + t_string + t_unicode + t_number + t_reserved + t_whatsit,
-----                       number     = t_number,
-----                   }

local t_object          = { "object", -- weird that we need to catch the end here (probably otherwise an invalid lpeg)
                            dictionary = t_dictionary.dictionary,
                            array      = t_dictionary.array,
                            whatever   = t_dictionary.whatever,
                            object     = t_openobject^-1 * t_spaces * (V("dictionary") * t_spaces * t_stream^-1 + V("array") + V("number") + t_spaces) * t_spaces * t_closeobject,
                            number     = t_number,
                        }

pdfobjectlexer._shared = {
    dictionary  = t_dictionary,
    object      = t_object,
    stream      = t_stream,
}

pdfobjectlexer._rules = {
    { "whitespace", t_spacing }, -- in fact, here we don't want whitespace as it's top level lexer work
    { "object",     t_object  },
}

pdfobjectlexer._tokenstyles = context.styleset

return pdfobjectlexer
