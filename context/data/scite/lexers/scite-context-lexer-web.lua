local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for w",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- this will be extended

local P, R, S, C, Cg, Cb, Cs, Cmt, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cg, lpeg.Cb, lpeg.Cs, lpeg.Cmt, lpeg.match
local setmetatable = setmetatable

local lexer       = require("lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token
local exact_match = lexer.exact_match

local weblexer    = lexer.new("web","scite-context-lexer-web")
local whitespace  = weblexer.whitespace

local keywords = { -- copied from cpp.lua
    -- c
    'asm', 'auto', 'break', 'case', 'const', 'continue', 'default', 'do', 'else',
    'extern', 'false', 'for', 'goto', 'if', 'inline', 'register', 'return',
    'sizeof', 'static', 'switch', 'true', 'typedef', 'volatile', 'while',
    'restrict',
    -- hm
    '_Bool', '_Complex', '_Pragma', '_Imaginary',
    -- c++.
    'catch', 'class', 'const_cast', 'delete', 'dynamic_cast', 'explicit',
    'export', 'friend', 'mutable', 'namespace', 'new', 'operator', 'private',
    'protected', 'public', 'signals', 'slots', 'reinterpret_cast',
    'static_assert', 'static_cast', 'template', 'this', 'throw', 'try', 'typeid',
    'typename', 'using', 'virtual'
}

local datatypes = { -- copied from cpp.lua
    'bool', 'char', 'double', 'enum', 'float', 'int', 'long', 'short', 'signed',
    'struct', 'union', 'unsigned', 'void'
}

local macros = { -- copied from cpp.lua
    'define', 'elif', 'else', 'endif', 'error', 'if', 'ifdef', 'ifndef', 'import',
    'include', 'line', 'pragma', 'undef', 'using', 'warning'
}

local space         = patterns.space -- S(" \n\r\t\f\v")
local any           = patterns.any
local restofline    = patterns.restofline
local startofline   = patterns.startofline

local squote        = P("'")
local dquote        = P('"')
local escaped       = P("\\") * P(1)
local slashes       = P('//')
local begincomment  = P("/*")
local endcomment    = P("*/")
local percent       = P("%")

local hexadecimal   = patterns.hexadecimal
local decimal       = patterns.decimal
local float         = patterns.float
local integer       = P("-")^-1 * (hexadecimal + decimal) -- also in patterns ?

local spacing       = token(whitespace, space^1)
local rest          = token("default", any)

local shortcomment  = token("comment", slashes * restofline^0)
local longcomment   = token("comment", begincomment * (1-endcomment)^0 * endcomment^-1)
local texcomment    = token("comment", percent * restofline^0)

local shortstring   = token("quote",  dquote) -- can be shared
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)

local number        = token("number", float + integer)

local validword     = R("AZ","az","__") * R("AZ","az","__","09")^0
local identifier    = token("default",validword)

local operator      = token("special", S('+-*/%^!=<>;:{}[]().&|?~'))

----- optionalspace = spacing^0

local p_keywords    = exact_match(keywords )
local p_datatypes   = exact_match(datatypes)
local p_macros      = exact_match(macros)

local keyword       = token("keyword", p_keywords)
local datatype      = token("keyword", p_datatypes)
local identifier    = token("default", validword)

local macro         = token("data", #P('#') * startofline * P('#') * S('\t ')^0 * p_macros)

local beginweb      = P("@")
local endweb        = P("@c")

local webcomment    = token("comment", #beginweb * startofline * beginweb * (1-endweb)^0 * endweb)

-- local texlexer      = lexer.load('scite-context-lexer-tex')

-- lexer.embed_lexer(weblexer, texlexer, #beginweb * startofline * token("comment",beginweb), token("comment",endweb))

weblexer._rules = {
    { 'whitespace',   spacing      },
    { 'keyword',      keyword      },
    { 'type',         datatype     },
    { 'identifier',   identifier   },
    { 'string',       shortstring  },
 -- { 'webcomment',   webcomment   },
    { 'texcomment',   texcomment   },
    { 'longcomment',  longcomment  },
    { 'shortcomment', shortcomment },
    { 'number',       number       },
    { 'macro',        macro        },
    { 'operator',     operator     },
    { 'rest',         rest         },
}

weblexer._tokenstyles = context.styleset

weblexer._foldpattern = P("/*") + P("*/") + S("{}") -- separate entry else interference

weblexer._foldsymbols = {
    _patterns = {
        '[{}]',
        '/%*',
        '%*/',
    },
 -- ["data"] = { -- macro
 --     ['region']    =  1,
 --     ['endregion'] = -1,
 --     ['if']        =  1,
 --     ['ifdef']     =  1,
 --     ['ifndef']    =  1,
 --     ['endif']     = -1,
 -- },
    ["special"] = { -- operator
        ['{'] =  1,
        ['}'] = -1,
    },
    ["comment"] = {
        ['/*'] =  1,
        ['*/'] = -1,
    }
}

-- -- by indentation:

weblexer._foldpatterns = nil
weblexer._foldsymbols  = nil

return weblexer
