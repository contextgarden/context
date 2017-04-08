local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for tex web",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local texweblexer = lexer.new("tex-web","scite-context-lexer-tex")
local texlexer    = lexer.load("scite-context-lexer-tex")

-- can probably be done nicer now, a bit of a hack

texweblexer._rules       = texlexer._rules_web
texweblexer._tokenstyles = texlexer._tokenstyles
texweblexer._foldsymbols = texlexer._foldsymbols
texweblexer._directives  = texlexer._directives

return texweblexer
