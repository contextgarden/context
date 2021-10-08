local info = {
    version   = 1.001,
    comment   = "scintilla lpeg lexer for bnf",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- will replace the one in metafun

local lpeg = lpeg
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexers        = require("scite-context-lexer")

local patterns      = lexers.patterns
local token         = lexers.token

local bnflexer      = lexers.new("bnf","scite-context-lexer-bnf")
local bnfwhitespace = bnflexer.whitespace

-- from wikipedia:
--
-- <syntax>         ::= <rule> | <rule> <syntax>
-- <rule>           ::= <opt-whitespace> "<" <rule-name> ">" <opt-whitespace> "::=" <opt-whitespace> <expression> <line-end>
-- <opt-whitespace> ::= " " <opt-whitespace> | ""
-- <expression>     ::= <list> | <list> <opt-whitespace> "|" <opt-whitespace> <expression>
-- <line-end>       ::= <opt-whitespace> <EOL> | <line-end> <line-end>
-- <list>           ::= <term> | <term> <opt-whitespace> <list>
-- <term>           ::= <literal> | "<" <rule-name> ">"
-- <literal>        ::= '"' <text1> '"' | "'" <text2> "'"
-- <text1>          ::= "" | <character1> <text1>
-- <text2>          ::= "" | <character2> <text2>
-- <character>      ::= <letter> | <digit> | <symbol>
-- <letter>         ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
-- <digit>          ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
-- <symbol>         ::= "|" | " " | "-" | "!" | "#" | "$" | "%" | "&" | "(" | ")" | "*" | "+" | "," | "-" | "." | "/" | ":" | ";" | ">" | "=" | "<" | "?" | "@" | "[" | "\" | "]" | "^" | "_" | "`" | "{" | "}" | "~"
-- <character1>     ::= <character> | "'"
-- <character2>     ::= <character> | '"'
-- <rule-name>      ::= <letter> | <rule-name> <rule-char>
-- <rule-char>      ::= <letter> | <digit> | "-"

local anything  = patterns.anything
local separator = P("|")
local left      = P("<")
local right     = P(">")
local space     = S(" \t\n\r\f")
local spaces    = space^1
local letter    = R("AZ","az")
local digit     = R("09")
local symbol    = S([[| -!#$%&()*+,-./:;>=<?@[\]^_`{}~]])
local text      = (letter + digit + symbol^0)
local name      = letter * (letter + digit + P("-"))^0
local becomes   = P("::=")
local extra     = P("|")
local single    = P("'")
local double    = P('"')

local t_spacing = token(bnfwhitespace,space^1)
local t_term    = token("command",left)
                * token("text",name)
                * token("command",right)
local t_text    = token("quote",single)
                * token("text",text)
                * token("quote",single)
                + token("quote",double)
                * token("text",text)
                * token("quote",double)
local t_becomes = token("operator",becomes)
local t_extra   = token("extra",extra)
local t_rest    = token("default",anything)

bnflexer.rules = {
    { "whitespace", t_spacing },
    { "term",       t_term    },
    { "text",       t_text    },
    { "becomes",    t_becomes },
    { "extra",      t_extra   },
    { "rest",       t_rest    },
}

bnflexer.folding = {
    ["<"] = { ["grouping"] =  1 },
    [">"] = { ["grouping"] = -1 },
}

return bnflexer
