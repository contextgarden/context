local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf xref",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- xref
-- cardinal cardinal [character]
-- ..
-- %%EOF | startxref | trailer

local P, R = lpeg.P, lpeg.R

local lexer          = require("lexer")
local context        = lexer.context
local patterns       = context.patterns

local token          = lexer.token

local pdfxreflexer   = lexer.new("pdf-xref","scite-context-lexer-pdf-xref")
local whitespace     = pdfxreflexer.whitespace

local pdfobjectlexer = lexer.load("scite-context-lexer-pdf-object")

local spacing        = patterns.spacing

local t_spacing      = token(whitespace, spacing)

local p_trailer      = P("trailer")

local t_number       = token("number", R("09")^1)
                     * t_spacing
                     * token("number", R("09")^1)
                     * t_spacing
                     * (token("keyword", R("az","AZ")) * t_spacing)^-1

local t_xref         = t_number^1

--    t_xref         = token("default", (1-p_trailer)^1)
--                   * token("keyword", p_trailer)
--                   * t_spacing
--                   * pdfobjectlexer._shared.dictionary

pdfxreflexer._rules = {
    { 'whitespace', t_spacing },
    { 'xref',       t_xref    },
}

pdfxreflexer._tokenstyles = context.styleset

return pdfxreflexer
