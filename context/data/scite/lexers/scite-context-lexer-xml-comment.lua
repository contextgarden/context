local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml comments",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P = lpeg.P

local lexer           = require("lexer")
local context         = lexer.context
local patterns        = context.patterns

local token           = lexer.token

local xmlcommentlexer = lexer.new("xml-comment","scite-context-lexer-xml-comment")
local whitespace      = xmlcommentlexer.whitespace

local space           = patterns.space
local nospace         = 1 - space - P("-->")

local p_spaces        = token(whitespace, space  ^1)
local p_comment       = token("comment",  nospace^1)

xmlcommentlexer._rules = {
    { "whitespace", p_spaces  },
    { "comment",    p_comment },
}

xmlcommentlexer._tokenstyles = context.styleset

xmlcommentlexer._foldpattern = P("<!--") + P("-->")

xmlcommentlexer._foldsymbols = {
    _patterns = {
        "<%!%-%-", "%-%->", -- comments
    },
    ["comment"] = {
        ["<!--"] = 1,
        ["-->" ] = -1,
    }
}

return xmlcommentlexer
