local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cpp web",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexers      = require("scite-context-lexer")

local patterns    = lexers.patterns
local token       = lexers.token

local cppweblexer = lexers.new("cpp-web","scite-context-lexer-cpp")
local cpplexer    = lexers.load("scite-context-lexer-cpp")

-- can probably be done nicer now, a bit of a hack

-- setmetatable(cppweblexer, { __index = cpplexer })

cppweblexer.rules      = cpplexer.rules_web
cppweblexer.embedded   = cpplexer.embedded
-- cppweblexer.whitespace = cpplexer.whitespace
cppweblexer.folding    = cpplexer.folding
cppweblexer.directives = cpplexer.directives

return cppweblexer
