local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua longstrings",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token

local stringlexer = lexer.new("lua-longstring","scite-context-lexer-lua-longstring")
local whitespace  = stringlexer.whitespace

local space       = patterns.space
local nospace     = 1 - space

local p_spaces    = token(whitespace, space  ^1)
local p_string    = token("string",   nospace^1)

stringlexer._rules = {
    { "whitespace", p_spaces },
    { "string",     p_string },
}

stringlexer._tokenstyles = context.styleset

return stringlexer
