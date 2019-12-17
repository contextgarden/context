local info = {
    version   = 1.001,
    comment   = "scintilla lpeg lexer for sas",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo: make this ok for the sas syntax as now it's sql

local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token
local exact_match = lexer.exact_match

local saslexer    = lexer.new("sas","scite-context-lexer-sAs")
local whitespace  = saslexer.whitespace

local keywords_standard = {
    "anova" , "data", "run", "proc",
}

local keywords_dialects = {
    "class" , "do", "end" , "int" , "for" , "model" , "rannor" , "to" , "output"
}

local space         = patterns.space -- S(" \n\r\t\f\v")
local any           = patterns.any
local restofline    = patterns.restofline
local startofline   = patterns.startofline

local squote        = P("'")
local dquote        = P('"')
local bquote        = P('`')
local escaped       = P("\\") * P(1)

local begincomment  = P("/*")
local endcomment    = P("*/")

local decimal       = patterns.decimal
local float         = patterns.float
local integer       = P("-")^-1 * decimal

local spacing       = token(whitespace, space^1)
local rest          = token("default", any)

local shortcomment  = token("comment", (P("#") + P("--")) * restofline^0)
local longcomment   = token("comment", begincomment * (1-endcomment)^0 * endcomment^-1)

local identifier    = token("default",lexer.helpers.utfidentifier)

local shortstring   = token("quote",  dquote) -- can be shared
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)
                    + token("quote",  bquote)
                    * token("string", (escaped + (1-bquote))^0)
                    * token("quote",  bquote)

local p_keywords_s  = exact_match(keywords_standard,nil,true)
local p_keywords_d  = exact_match(keywords_dialects,nil,true)
local keyword_s     = token("keyword", p_keywords_s)
local keyword_d     = token("command", p_keywords_d)

local number        = token("number", float + integer)
local operator      = token("special", S("+-*/%^!=<>;:{}[]().&|?~"))

saslexer._tokenstyles = context.styleset

saslexer._foldpattern = P("/*") + P("*/") + S("{}") -- separate entry else interference

saslexer._foldsymbols = {
    _patterns = {
        "/%*",
        "%*/",
    },
    ["comment"] = {
        ["/*"] =  1,
        ["*/"] = -1,
    }
}

saslexer._rules = {
    { "whitespace",   spacing      },
    { "keyword-s",    keyword_s    },
    { "keyword-d",    keyword_d    },
    { "identifier",   identifier   },
    { "string",       shortstring  },
    { "longcomment",  longcomment  },
    { "shortcomment", shortcomment },
    { "number",       number       },
    { "operator",     operator     },
    { "rest",         rest         },
}

return saslexer
