local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for tex web",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexers      = require("scite-context-lexer")

local texweblexer = lexers.new("tex-web","scite-context-lexer-tex")
local texlexer    = lexers.load("scite-context-lexer-tex")

-- can probably be done nicer now, a bit of a hack

texweblexer.rules      = texlexer.rules_web
texweblexer.embedded   = texlexer.embedded
-- texweblexer.whitespace = texlexer.whitespace
texweblexer.folding    = texlexer.folding
texweblexer.directives = texlexer.directives

return texweblexer
