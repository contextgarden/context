local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cld",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer    = require("scite-context-lexer")
local context  = lexer.context
local patterns = context.patterns

local cldlexer = lexer.new("cld","scite-context-lexer-cld")
local lualexer = lexer.load("scite-context-lexer-lua")

-- can probably be done nicer now, a bit of a hack

cldlexer._rules       = lualexer._rules_cld
cldlexer._tokenstyles = lualexer._tokenstyles
cldlexer._foldsymbols = lualexer._foldsymbols
cldlexer._directives  = lualexer._directives

return cldlexer
