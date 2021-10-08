local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for cpp",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- looks liks the original cpp lexer but web ready (so nothing special here yet)

local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexers        = require("scite-context-lexer")

local patterns      = lexers.patterns
local token         = lexers.token

local cpplexer      = lexers.new("cpp","scite-context-lexer-cpp")
local cppwhitespace = cpplexer.whitespace

local keywords = { -- copied from cpp.lua
    -- c
    "asm", "auto", "break", "case", "const", "continue", "default", "do", "else",
    "extern", "false", "for", "goto", "if", "inline", "register", "return",
    "sizeof", "static", "switch", "true", "typedef", "volatile", "while",
    "restrict",
    -- hm
    "_Bool", "_Complex", "_Pragma", "_Imaginary",
    "boolean",
    -- c++.
    "catch", "class", "const_cast", "delete", "dynamic_cast", "explicit",
    "export", "friend", "mutable", "namespace", "new", "operator", "private",
    "protected", "public", "signals", "slots", "reinterpret_cast",
    "static_assert", "static_cast", "template", "this", "throw", "try", "typeid",
    "typename", "using", "virtual"
}

local datatypes = { -- copied from cpp.lua
    "bool", "char", "double", "enum", "float", "int", "long", "short", "signed",
    "struct", "union", "unsigned", "void"
}

local macros = { -- copied from cpp.lua
    "define", "elif", "else", "endif", "error", "if", "ifdef", "ifndef", "import",
    "include", "line", "pragma", "undef", "using", "warning"
}

local luatexs = {
    "word", "halfword", "quarterword", "scaledwhd", "scaled", "pointer", "glueratio", "strnumber",
    "dumpstream", "memoryword",
}

local space         = patterns.space -- S(" \n\r\t\f\v")
local any           = patterns.any
local restofline    = patterns.restofline
local startofline   = patterns.startofline
local exactmatch    = patterns.exactmatch

local squote        = P("'")
local dquote        = P('"')
local period        = P(".")
local escaped       = P("\\") * P(1)
local slashes       = P("//")
local begincomment  = P("/*")
local endcomment    = P("*/")
local percent       = P("%")

local hexadecimal   = patterns.hexadecimal
local decimal       = patterns.decimal
local float         = patterns.float
local integer       = P("-")^-1 * (hexadecimal + decimal) -- also in patterns ?

local spacing       = token(cppwhitespace, space^1)
local rest          = token("default", any)

local shortcomment  = token("comment", slashes * restofline^0)
local longcomment   = token("comment", begincomment * (1-endcomment)^0 * endcomment^-1)

local shortstring   = token("quote",  dquote) -- can be shared
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)

local number        = token("number", float + integer)

local validword     = R("AZ","az","__") * R("AZ","az","__","09")^0
local identifier    = token("default",validword)

local operator      = token("special", S("+-*/%^!=<>;:{}[]().&|?~"))

----- optionalspace = spacing^0

local p_keywords    = exactmatch(keywords)
local p_datatypes   = exactmatch(datatypes)
local p_macros      = exactmatch(macros)
local p_luatexs     = exactmatch(luatexs)

local keyword       = token("keyword", p_keywords)
local datatype      = token("keyword", p_datatypes)
local identifier    = token("default", validword)
local luatex        = token("command", p_luatexs)

local macro         = token("data", #P("#") * startofline * P("#") * S("\t ")^0 * p_macros)

cpplexer.rules = {
    { "whitespace",   spacing      },
    { "keyword",      keyword      },
    { "type",         datatype     },
    { "luatex",       luatex       },
    { "identifier",   identifier   },
    { "string",       shortstring  },
    { "longcomment",  longcomment  },
    { "shortcomment", shortcomment },
    { "number",       number       },
    { "macro",        macro        },
    { "operator",     operator     },
    { "rest",         rest         },
}

local web = lexers.loadluafile("scite-context-lexer-web-snippets")

if web then

 -- lexers.report("supporting web snippets in cpp lexer")

    cpplexer.rules_web = {
        { "whitespace",   spacing      },
        { "keyword",      keyword      },
        { "type",         datatype     },
        { "luatex",       luatex       },
        { "identifier",   identifier   },
        { "string",       shortstring  },
        { "longcomment",  longcomment  },
        { "shortcomment", shortcomment },
        { "web",          web.pattern  },
        { "number",       number       },
        { "macro",        macro        },
        { "operator",     operator     },
        { "rest",         rest         },
    }

else

 -- lexers.report("not supporting web snippets in cpp lexer")

    cpplexer.rules_web = {
        { "whitespace",   spacing      },
        { "keyword",      keyword      },
        { "type",         datatype     },
        { "luatex",       luatex       },
        { "identifier",   identifier   },
        { "string",       shortstring  },
        { "longcomment",  longcomment  },
        { "shortcomment", shortcomment },
        { "number",       number       },
        { "macro",        macro        },
        { "operator",     operator     },
        { "rest",         rest         },
    }

end

cpplexer.folding = {
 -- ["region"]    = { ["data"]    =  1 },
 -- ["endregion"] = { ["data"]    = -1 },
 -- ["if"]        = { ["data"]    =  1 },
 -- ["ifdef"]     = { ["data"]    =  1 },
 -- ["ifndef"]    = { ["data"]    =  1 },
 -- ["endif"]     = { ["data"]    = -1 },
    ["{"]         = { ["special"] =  1 },
    ["}"]         = { ["special"] = -1 },
    ["/*"]        = { ["comment"] =  1 },
    ["*/"]        = { ["comment"] = -1 },
}

return cpplexer
