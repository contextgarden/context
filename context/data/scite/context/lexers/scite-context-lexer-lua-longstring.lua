local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua longstrings",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This one is needed because we have spaces in strings and partial lexing depends
-- on them being different.

local lexers      = require("scite-context-lexer")

local patterns    = lexers.patterns
local token       = lexers.token

local stringlexer = lexers.new("lua-longstring","scite-context-lexer-lua-longstring")

local space       = patterns.space
local nospace     = 1 - space

local p_spaces    = token("whitespace", space^1)
local p_string    = token("string",     nospace^1)

stringlexer.rules = {
    { "whitespace", p_spaces },
    { "string",     p_string },
}

return stringlexer
