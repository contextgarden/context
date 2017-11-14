local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cpp web",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local cppweblexer = lexer.new("cpp-web","scite-context-lexer-cpp")
local cpplexer    = lexer.load("scite-context-lexer-cpp")

-- can probably be done nicer now, a bit of a hack

cppweblexer._rules       = cpplexer._rules_web
cppweblexer._tokenstyles = cpplexer._tokenstyles
cppweblexer._foldsymbols = cpplexer._foldsymbols
cppweblexer._directives  = cpplexer._directives

return cppweblexer
