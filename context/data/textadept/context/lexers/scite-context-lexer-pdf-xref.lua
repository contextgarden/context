local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for pdf xref",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- no longer used: nesting lexers with whitespace in start/stop is unreliable

local P, R = lpeg.P, lpeg.R

local lexer          = require("scite-context-lexer")
local context        = lexer.context
local patterns       = context.patterns

local token          = lexer.token

local pdfxreflexer   = lexer.new("pdfxref","scite-context-lexer-pdf-xref")
local whitespace     = pdfxreflexer.whitespace

local spacing        = patterns.spacing
local cardinal       = patterns.cardinal
local alpha          = patterns.alpha

local t_spacing      = token(whitespace, spacing)

local p_xref         = P("xref")
local t_xref         = token("keyword",p_xref)
                     * token("number", cardinal * spacing * cardinal * spacing)

local t_number       = token("number", cardinal * spacing * cardinal * spacing)
                     * token("keyword", alpha)

pdfxreflexer._rules = {
    { "whitespace", t_spacing },
    { "xref",       t_xref    },
    { "number",     t_number  },
}

pdfxreflexer._tokenstyles = context.styleset

return pdfxreflexer
