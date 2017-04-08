local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml cdata",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P = lpeg.P

local lexer         = require("scite-context-lexer")
local context       = lexer.context
local patterns      = context.patterns

local token         = lexer.token

local xmlcdatalexer = lexer.new("xml-cdata","scite-context-lexer-xml-cdata")
local whitespace    = xmlcdatalexer.whitespace

local space         = patterns.space
local nospace       = 1 - space - P("]]>")

local t_spaces      = token(whitespace, space  ^1)
local t_cdata       = token("comment",  nospace^1)

xmlcdatalexer._rules = {
    { "whitespace", t_spaces },
    { "cdata",      t_cdata  },
}

xmlcdatalexer._tokenstyles = context.styleset

return xmlcdatalexer
