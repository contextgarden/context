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

local lexer        = require("scite-context-lexer")
local context      = lexer.context
local patterns     = context.patterns

local token        = lexer.token

local dummylexer   = lexer.new("dummy","scite-context-lexer-dummy")
local whitespace   = dummylexer.whitespace

local space        = patterns.space
local nospace      = (1-space)

local t_spacing    = token(whitespace, space  ^1)
local t_rest       = token("default",  nospace^1)

dummylexer._rules = {
    { "whitespace", t_spacing },
    { "rest",       t_rest    },
}

dummylexer._tokenstyles = context.styleset

return dummylexer
