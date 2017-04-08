local info = {
    version   = 1.003,
    comment   = "scintilla lpeg lexer for web",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token
local exact_match = lexer.exact_match

local weblexer    = lexer.new("web","scite-context-lexer-web")
local whitespace  = weblexer.whitespace

local space       = patterns.space -- S(" \n\r\t\f\v")
local any         = patterns.any
local restofline  = patterns.restofline
local startofline = patterns.startofline

local period      = P(".")
local percent     = P("%")

local spacing     = token(whitespace, space^1)
local rest        = token("default", any)

local eop         = P("@>")
local eos         = eop * P("+")^-1 * P("=")

-- we can put some of the next in the web-snippets file
-- is f okay here?

local texcomment  = token("comment", percent * restofline^0)

local texpart     = token("label",P("@"))  * #spacing
                  + token("label",P("@") * P("*")^1) * token("function",(1-period)^1) * token("label",period)
local midpart     = token("label",P("@d")) * #spacing
                  + token("label",P("@f")) * #spacing
local cpppart     = token("label",P("@c")) * #spacing
                  + token("label",P("@p")) * #spacing
                  + token("label",P("@") * S("<(")) * token("function",(1-eop)^1) * token("label",eos)

local anypart     = P("@") * ( P("*")^1 + S("dfcp") + space^1 + S("<(") * (1-eop)^1 * eos )
local limbo       = 1 - anypart - percent

local texlexer    = lexer.load("scite-context-lexer-tex-web")
local cpplexer    = lexer.load("scite-context-lexer-cpp-web")

lexer.embed_lexer(weblexer, texlexer, texpart + limbo,   #anypart)
lexer.embed_lexer(weblexer, cpplexer, cpppart + midpart, #anypart)

local texcomment    = token("comment", percent * restofline^0)

weblexer._rules = {
    { "whitespace", spacing    },
    { "texcomment", texcomment }, -- else issues with first tex section
    { "rest",       rest       },
}

weblexer._tokenstyles = context.styleset

return weblexer
