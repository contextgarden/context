local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml comments",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P = lpeg.P

local lexers          = require("scite-context-lexer")

local patterns        = lexers.patterns
local token           = lexers.token

local xmlcommentlexer = lexers.new("xml-comment","scite-context-lexer-xml-comment")

local space           = patterns.space
local nospace         = 1 - space - P("-->")

local t_spaces        = token("whitespace", space^1)
local t_comment       = token("comment",    nospace^1)

xmlcommentlexer.rules = {
    { "whitespace", t_spaces  },
    { "comment",    t_comment },
}

return xmlcommentlexer
