local info = {
    version   = 1.003,
    comment   = "scintilla lpeg lexer for web",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexers        = require("scite-context-lexer")

local patterns      = lexers.patterns
local token         = lexers.token

local weblexer      = lexers.new("web","scite-context-lexer-web")
local webwhitespace = weblexer.whitespace

local space       = patterns.space -- S(" \n\r\t\f\v")
local any         = patterns.any
local restofline  = patterns.restofline
local eol         = patterns.eol

local period      = P(".")
local percent     = P("%")

local spacing     = token(webwhitespace, space^1)
local rest        = token("default", any)

local eop         = P("@>")
local eos         = eop * P("+")^-1 * P("=")

-- we can put some of the next in the web-snippets file
-- is f okay here?

-- This one is hard to handle partial because trailing spaces are part of the tex part as well
-- as the c part so they are bound to that. We could have some special sync signal like a label
-- with space-like properties (more checking then) or styles that act as boundary (basically any
-- style + 128 or so). A sunday afternoon challenge. Maybe some newline trickery? Or tag lines
-- which is possible in scite. Or how about a function hook: foolexer.backtracker(str) where str
-- matches at the beginning of a line: foolexer.backtracker("@ @c") or a pattern, maybe even a
-- match from start.

-- local backtracker = ((lpeg.Cp() * lpeg.P("@ @c")) / function(p) n = p end + lpeg.P(1))^1
-- local c = os.clock() print(#s) print(lpeg.match(backtracker,s)) print(n) print(c)

-- local backtracker = (lpeg.Cmt(lpeg.P("@ @c"),function(_,p) n = p end) + lpeg.P(1))^1
-- local c = os.clock() print(#s) print(lpeg.match(backtracker,s)) print(n) print(c)

----- somespace   = spacing
----- somespace   = token("whitespace",space^1)
local somespace   = space^1

local texpart     = token("label",P("@")) * #somespace
                  + token("label",P("@") * P("*")^1) * token("function",(1-period)^1) * token("label",period)
local midpart     = token("label",P("@d")) * #somespace
                  + token("label",P("@f")) * #somespace
local cpppart     = token("label",P("@c")) * #somespace
                  + token("label",P("@p")) * #somespace
                  + token("label",P("@") * S("<(")) * token("function",(1-eop)^1) * token("label",eos)

local anypart     = P("@") * ( P("*")^1 + S("dfcp") + space^1 + S("<(") * (1-eop)^1 * eos )
local limbo       = 1 - anypart - percent

weblexer.backtracker =                 eol^1 * P("@ @c")
-- weblexer.foretracker = (space-eol)^0 * eol^1 * P("@") * space + anypart
weblexer.foretracker = anypart

local texlexer    = lexers.load("scite-context-lexer-tex-web")
local cpplexer    = lexers.load("scite-context-lexer-cpp-web")

-- local texlexer    = lexers.load("scite-context-lexer-tex")
-- local cpplexer    = lexers.load("scite-context-lexer-cpp")

lexers.embed(weblexer, texlexer, texpart + limbo,   #anypart)
lexers.embed(weblexer, cpplexer, cpppart + midpart, #anypart)

local texcomment = token("comment", percent * restofline^0)

weblexer.rules = {
    { "whitespace", spacing    },
    { "texcomment", texcomment }, -- else issues with first tex section
    { "rest",       rest       },
}

return weblexer
