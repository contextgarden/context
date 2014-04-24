local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexer             = require("lexer")
local context           = lexer.context
local patterns          = context.patterns

local token             = lexer.token

local pdflexer          = lexer.new("pdf","scite-context-lexer-pdf")
local whitespace        = pdflexer.whitespace

local pdfobjectlexer    = lexer.load("scite-context-lexer-pdf-object")
local pdfxreflexer      = lexer.load("scite-context-lexer-pdf-xref")

local space             = patterns.space
local spacing           = patterns.spacing
local nospacing         = patterns.nospacing
local anything          = patterns.anything
local restofline        = patterns.restofline

local t_spacing         = token(whitespace, spacing)
local t_rest            = token("default",  nospacing) -- anything

local p_obj             = P("obj")
local p_endobj          = P("endobj")
local p_xref            = P("xref")
local p_startxref       = P("startxref")
local p_eof             = P("%%EOF")
local p_trailer         = P("trailer")

local p_objectnumber    = patterns.cardinal
local p_comment         = P('%') * restofline

local t_comment         = token("comment", p_comment)
local t_openobject      = token("warning", p_objectnumber)
                        * t_spacing
                        * token("warning", p_objectnumber)
                        * t_spacing
                        * token("keyword", p_obj)
                        * t_spacing^0
local t_closeobject     = token("keyword", p_endobj)

-- We could do clever xref parsing but why should we (i.e. we should check for
-- the xref body. As a pdf file is not edited, we could do without a nested
-- lexer anyway.

local t_trailer         = token("keyword", p_trailer)
                        * t_spacing
                        * pdfobjectlexer._shared.dictionary

local t_openxref        = token("plain", p_xref)
local t_closexref       = token("plain", p_startxref)
                        + token("comment", p_eof)
                        + t_trailer
local t_startxref       = token("plain", p_startxref)
                        * t_spacing
                        * token("number", R("09")^1)

lexer.embed_lexer(pdflexer, pdfobjectlexer, t_openobject, t_closeobject)
lexer.embed_lexer(pdflexer, pdfxreflexer,   t_openxref,   t_closexref)

pdflexer._rules = {
    { 'whitespace', t_spacing  },
    { 'comment',    t_comment  },
    { 'xref',       t_startxref },
    { 'rest',       t_rest     },
}

pdflexer._tokenstyles = context.styleset

return pdflexer
