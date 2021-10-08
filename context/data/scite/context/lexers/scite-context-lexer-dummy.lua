local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer that triggers whitespace backtracking",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- the lexer dll doesn't backtrack when there is no embedded lexer so
-- we need to trigger that, for instance in the bibtex lexer, but still
-- we get failed lexing

local lexers          = require("scite-context-lexer")

local patterns        = lexers.patterns
local token           = lexers.token

local dummylexer      = lexers.new("dummy","scite-context-lexer-dummy")
local dummywhitespace = dummylexer.whitespace

local space      = patterns.space
local nospace    = (1-space)

local t_spacing  = token(dummywhitespace, space^1)
local t_rest     = token("default",       nospace^1)

dummylexer.rules = {
    { "whitespace", t_spacing },
    { "rest",       t_rest    },
}

return dummylexer
