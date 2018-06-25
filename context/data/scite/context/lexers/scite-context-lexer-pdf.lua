local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- pdf is normally static .. i.e. not edited so we don't really
-- need embedded lexers.

local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V

local lexer             = require("scite-context-lexer")
local context           = lexer.context
local patterns          = context.patterns

local token             = lexer.token

local pdflexer          = lexer.new("pdf","scite-context-lexer-pdf")
local whitespace        = pdflexer.whitespace

----- pdfobjectlexer    = lexer.load("scite-context-lexer-pdf-object")
----- pdfxreflexer      = lexer.load("scite-context-lexer-pdf-xref")

local anything          = patterns.anything
local space             = patterns.space
local spacing           = patterns.spacing
local nospacing         = patterns.nospacing
local anything          = patterns.anything
local restofline        = patterns.restofline

local t_whitespace      = token(whitespace, spacing)
local t_spacing         = token("default",  spacing)
----- t_rest            = token("default",  nospacing)
local t_rest            = token("default",  anything)

local p_comment         = P("%") * restofline
local t_comment         = token("comment", p_comment)

-- whatever

local space             = patterns.space
local spacing           = patterns.spacing
local nospacing         = patterns.nospacing
local anything          = patterns.anything
local newline           = patterns.eol
local real              = patterns.real
local cardinal          = patterns.cardinal
local alpha             = patterns.alpha

local lparent           = P("(")
local rparent           = P(")")
local langle            = P("<")
local rangle            = P(">")
local escape            = P("\\")
local unicodetrigger    = P("feff")

local nametoken         = 1 - space - S("<>/[]()")
local name              = P("/") * nametoken^1

local p_string          = P { ( escape * anything + lparent * V(1) * rparent + (1 - rparent) )^0 }

local t_spacing         = token("default", spacing)
local t_spaces          = token("default", spacing)^0
local t_rest            = token("default", nospacing) -- anything

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
local t_reserved        = token("number",   P("true") + P("false") + P("null"))
--    t_reference       = token("warning",  cardinal * spacing * cardinal * spacing)
--                      * token("keyword",  p_reference)
local t_reference       = token("warning",  cardinal)
                        * t_spacing
                        * token("warning",  cardinal)
                        * t_spacing
                        * token("keyword",  p_reference)

local t_comment         = token("comment",  p_comment)

local t_openobject      = token("warning",  p_objectnumber)
                        * t_spacing
                        * token("warning",  p_objectnumber)
                        * t_spacing
                        * token("keyword",  p_obj)
--    t_openobject      = token("warning",  p_objectnumber * spacing)
--                      * token("warning",  p_objectnumber * spacing)
--                      * token("keyword",  p_obj)
local t_closeobject     = token("keyword",  p_endobj)

local t_opendictionary  = token("grouping", P("<<"))
local t_closedictionary = token("grouping", P(">>"))

local t_openarray       = token("grouping", P("["))
local t_closearray      = token("grouping", P("]"))

local t_stream          = token("keyword", p_stream)
                        * token("text",    (1 - p_endstream)^1)
                        * token("keyword", p_endstream)

local t_other           = t_constant + t_reference + t_string + t_unicode + t_number + t_reserved + t_whatsit

local t_dictionary      = { "dictionary",
                            dictionary = t_opendictionary
                                       * (t_spaces * t_keyword * t_spaces * V("whatever"))^0
                                       * t_spaces
                                       * t_closedictionary,
                            array      = t_openarray
                                       * (t_spaces * V("whatever"))^0
                                       * t_spaces
                                       * t_closearray,
                            whatever   = V("dictionary")
                                       + V("array")
                                       + t_other,
                        }

local t_object          = { "object", -- weird that we need to catch the end here (probably otherwise an invalid lpeg)
                            dictionary = t_dictionary.dictionary,
                            array      = t_dictionary.array,
                            whatever   = t_dictionary.whatever,
                            object     = t_openobject
                                       * t_spaces
                                       * (V("dictionary") * t_spaces * t_stream^-1 + V("array") + t_other)
                                       * t_spaces
                                       * t_closeobject,
                            number     = t_number,
                        }

-- objects ... sometimes NUL characters play havoc ... and in xref we have
-- issues with embedded lexers that have spaces in the start and stop
-- conditions and this cannot be handled well either ... so, an imperfect
-- solution ... but anyway, there is not that much that can end up in
-- the root of the tree see we're sort of safe

local p_trailer         = P("trailer")
local t_trailer         = token("keyword", p_trailer)
                        * t_spacing
                        * t_dictionary
--    t_trailer         = token("keyword", p_trailer * spacing)
--                      * t_dictionary

local p_startxref       = P("startxref")
local t_startxref       = token("keyword", p_startxref)
                        * t_spacing
                        * token("number", cardinal)
--    t_startxref       = token("keyword", p_startxref * spacing)
--                      * token("number", cardinal)

local p_xref            = P("xref")
local t_xref            = token("keyword",p_xref)
                        * t_spacing
                        * token("number", cardinal)
                        * t_spacing
                        * token("number", cardinal)
                        * spacing
--    t_xref            = token("keyword",p_xref)
--                      * token("number", spacing * cardinal * spacing * cardinal * spacing)

local t_number          = token("number", cardinal)
                        * t_spacing
                        * token("number", cardinal)
                        * t_spacing
                        * token("keyword", S("fn"))
--    t_number          = token("number", cardinal * spacing * cardinal * spacing)
--                      * token("keyword", S("fn"))

pdflexer._rules = {
    { "whitespace", t_whitespace },
    { "object",     t_object     },
    { "comment",    t_comment    },
    { "trailer",    t_trailer    },
    { "startxref",  t_startxref  },
    { "xref",       t_xref       },
    { "number",     t_number     },
    { "rest",       t_rest       },
}

pdflexer._tokenstyles = context.styleset

-- lexer.inspect(pdflexer)

-- collapser: obj endobj stream endstream

pdflexer._foldpattern = p_obj + p_endobj + p_stream + p_endstream

pdflexer._foldsymbols = {
    ["keyword"] = {
        ["obj"]       =  1,
        ["endobj"]    = -1,
        ["stream"]    =  1,
        ["endstream"] = -1,
    },
}

return pdflexer
