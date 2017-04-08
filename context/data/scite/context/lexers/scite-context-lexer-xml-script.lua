local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml script",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P = lpeg.P

local lexer          = require("scite-context-lexer")
local context        = lexer.context
local patterns       = context.patterns

local token          = lexer.token

local xmlscriptlexer = lexer.new("xml-script","scite-context-lexer-xml-script")
local whitespace     = xmlscriptlexer.whitespace

local space          = patterns.space
local nospace        = 1 - space - (P("</") * P("script") + P("SCRIPT")) * P(">")

local t_spaces       = token(whitespace, space  ^1)
local t_script       = token("default",  nospace^1)

xmlscriptlexer._rules = {
    { "whitespace", t_spaces },
    { "script",     t_script },
}

xmlscriptlexer._tokenstyles = context.styleset

return xmlscriptlexer
