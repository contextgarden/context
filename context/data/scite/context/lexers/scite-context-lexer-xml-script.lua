local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml script",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P = lpeg.P

local lexers         = require("scite-context-lexer")

local patterns       = lexers.patterns
local token          = lexers.token

local xmlscriptlexer = lexers.new("xml-script","scite-context-lexer-xml-script")

local space          = patterns.space
local nospace        = 1 - space - (P("</") * P("script") + P("SCRIPT")) * P(">")

local t_spaces       = token("whitespace", space^1)
local t_script       = token("default",    nospace^1)

xmlscriptlexer.rules = {
    { "whitespace", t_spaces },
    { "script",     t_script },
}

return xmlscriptlexer
