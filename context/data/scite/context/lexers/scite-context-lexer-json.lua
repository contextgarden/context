local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for json",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local global, string, table, lpeg = _G, string, table, lpeg
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local type = type

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token
local exact_match = lexer.exact_match

local jsonlexer   = lexer.new("json","scite-context-lexer-json")
local whitespace  = jsonlexer.whitespace

local anything     = patterns.anything
local comma        = P(",")
local colon        = P(":")
local escape       = P("\\")
----- single       = P("'")
local double       = P('"')
local openarray    = P('[')
local closearray   = P(']')
local openhash     = P('{')
local closehash    = P('}')
----- lineending   = S("\n\r")
local space        = S(" \t\n\r\f")
local spaces       = space^1
local operator     = S(':,{}[]')
local fence        = openarray + closearray + openhash + closehash

local escape_un    = P("\\u") * S("09","AF","af")
local escape_bs    = P("\\") * P(1)
----- content      = (escape_un + escape_bs + (1-double))^0
local content      = (escape_bs + (1-double))^0

local reserved     = P("true")
                   + P("false")
                   + P("null")

local integer      = P("-")^-1 * (patterns.hexadecimal + patterns.decimal)
local float        = patterns.float

local t_number     = token("number", float + integer)
                   * (token("error",R("AZ","az","__")^1))^0

local t_spacing    = token(whitespace, space^1)
local t_optionalws = token("default", space^1)^0

local t_operator   = token("special", operator)

local t_string     = token("operator",double)
                   * token("string",content)
                   * token("operator",double)

local t_key        = token("operator",double)
                   * token("text",content)
                   * token("operator",double)
                   * t_optionalws
                   * token("operator",colon)

local t_fences     = token("operator",fence) -- grouping

local t_reserved   = token("primitive",reserved)

local t_rest       = token("default",anything)

jsonlexer._rules = {
    { "whitespace", t_spacing  },
    { "reserved",   t_reserved },
    { "key",        t_key      },
    { "number",     t_number   },
    { "string",     t_string   },
    { "fences",     t_fences   },
    { "operator",   t_operator },
    { "rest",       t_rest     },
}

jsonlexer._tokenstyles = context.styleset

jsonlexer._foldpattern = fence

jsonlexer._foldsymbols = {
    _patterns = {
        "{", "}",
        "[", "]",
    },
    ["grouping"] = {
        ["{"] = 1, ["}"] = -1,
        ["["] = 1, ["]"] = -1,
    },
}

return jsonlexer
