local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for bibtex",
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

local bibtexlexer = lexer.new("bib","scite-context-lexer-bibtex")
local whitespace  = bibtexlexer.whitespace

local escape, left, right = P("\\"), P('{'), P('}')

patterns.balanced = P {
    [1] = ((escape * (left+right)) + (1 - (left+right)) + V(2))^0,
    [2] = left * V(1) * right
}

-- taken from bibl-bib.lua

local anything     = patterns.anything
local percent      = P("%")
local start        = P("@")
local comma        = P(",")
local hash         = P("#")
local escape       = P("\\")
local single       = P("'")
local double       = P('"')
local left         = P('{')
local right        = P('}')
local lineending   = S("\n\r")
local space        = S(" \t\n\r\f")
local spaces       = space^1
local equal        = P("=")

local keyword      = (R("az","AZ","09") + S("@_:-"))^1
----- s_quoted     = ((escape*single) + spaces + (1-single))^0
----- d_quoted     = ((escape*double) + spaces + (1-double))^0
local s_quoted     = ((escape*single) + (1-single))^0
local d_quoted     = ((escape*double) + (1-double))^0

local balanced     = patterns.balanced

local t_spacing    = token(whitespace, space^1)
local t_optionalws = token("default", space^1)^0

local t_equal      = token("operator",equal)
local t_left       = token("grouping",left)
local t_right      = token("grouping",right)
local t_comma      = token("operator",comma)
local t_hash       = token("operator",hash)

local t_s_value    = token("operator",single)
                   * token("text",s_quoted)
                   * token("operator",single)
local t_d_value    = token("operator",double)
                   * token("text",d_quoted)
                   * token("operator",double)
local t_b_value    = token("operator",left)
                   * token("text",balanced)
                   * token("operator",right)
local t_r_value    = token("text",keyword)

local t_keyword    = token("keyword",keyword)
local t_key        = token("command",keyword)
local t_label      = token("warning",keyword)

local t_somevalue  = t_s_value + t_d_value + t_b_value + t_r_value
local t_value      = t_somevalue
                   * ((t_optionalws * t_hash * t_optionalws) * t_somevalue)^0

local t_assignment = t_optionalws
                   * t_key
                   * t_optionalws
                   * t_equal
                   * t_optionalws
                   * t_value

local t_shortcut   = t_keyword
                   * t_optionalws
                   * t_left
                   * t_optionalws
                   * (t_assignment * t_comma^0)^0
                   * t_optionalws
                   * t_right

local t_definition = t_keyword
                   * t_optionalws
                   * t_left
                   * t_optionalws
                   * t_label
                   * t_optionalws
                   * t_comma
                   * (t_assignment * t_comma^0)^0
                   * t_optionalws
                   * t_right

local t_comment    = t_keyword
                   * t_optionalws
                   * t_left
                   * token("text",(1-t_right)^0)
                   * t_optionalws
                   * t_right

local t_forget     = token("comment",percent^1 * (1-lineending)^0)

local t_rest       = token("default",anything)

-- this kind of lexing seems impossible as the size of the buffer passed to the lexer is not
-- large enough .. but we can cheat and use this:
--
-- function OnOpen(filename) editor:Colourise(1,editor.TextLength) end -- or is it 0?

-- somehow lexing fails on this more complex lexer when we insert something, there is no
-- backtracking to whitespace when we have no embedded lexer, so we fake one ... this works
-- to some extend but not in all cases (e.g. editing inside line fails) .. maybe i need to
-- patch the dll ... (better not)

local dummylexer = lexer.load("scite-context-lexer-dummy","bib-dum")

local dummystart = token("embedded",P("\001")) -- an unlikely to be used character
local dummystop  = token("embedded",P("\002")) -- an unlikely to be used character

lexer.embed_lexer(bibtexlexer,dummylexer,dummystart,dummystop)

-- maybe we need to define each functional block as lexer (some 4) so i'll do that when
-- this issue is persistent ... maybe consider making a local lexer options (not load,
-- just lexer.new or so) .. or maybe do the reverse, embed the main one in a dummy child

bibtexlexer._rules = {
    { "whitespace",  t_spacing    },
    { "forget",      t_forget     },
    { "shortcut",    t_shortcut   },
    { "definition",  t_definition },
    { "comment",     t_comment    },
    { "rest",        t_rest       },
}

-- local t_assignment = t_key
--                    * t_optionalws
--                    * t_equal
--                    * t_optionalws
--                    * t_value
--
-- local t_shortcut   = t_keyword
--                    * t_optionalws
--                    * t_left
--
-- local t_definition = t_keyword
--                    * t_optionalws
--                    * t_left
--                    * t_optionalws
--                    * t_label
--                    * t_optionalws
--                    * t_comma
--
-- bibtexlexer._rules = {
--     { "whitespace",  t_spacing    },
--     { "assignment",  t_assignment },
--     { "definition",  t_definition },
--     { "shortcut",    t_shortcut   },
--     { "right",       t_right      },
--     { "comma",       t_comma      },
--     { "forget",      t_forget     },
--     { "comment",     t_comment    },
--     { "rest",        t_rest       },
-- }

bibtexlexer._tokenstyles = context.styleset

bibtexlexer._foldpattern = P("{") + P("}")

bibtexlexer._foldsymbols = {
    _patterns = {
        "{",
        "}",
    },
    ["grouping"] = {
        ["{"] =  1,
        ["}"] = -1,
    },
}

return bibtexlexer
