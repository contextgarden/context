local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S, C, Cmt, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cmt, lpeg.Cp
local match, find = string.match, string.find
local setmetatable = setmetatable

local lexers        = require("scite-context-lexer")

local patterns      = lexers.patterns
local token         = lexers.token

local lualexer      = lexers.new("lua","scite-context-lexer-lua")

local luawhitespace = lualexer.whitespace

local stringlexer   = lexers.load("scite-context-lexer-lua-longstring")
----- labellexer    = lexers.load("scite-context-lexer-lua-labelstring")

local directives = { } -- communication channel

local keywords = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", -- "goto",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while",
}

local functions = {
    "assert", "collectgarbage", "dofile", "error", "getmetatable",
    "ipairs", "load", "loadfile", "module", "next", "pairs",
    "pcall", "print", "rawequal", "rawget", "rawset", "require",
    "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall", "select",

    "string", "table", "coroutine", "debug", "file", "io", "lpeg", "math", "os", "package", "bit32", "utf8",
}

local constants = {
    "_G", "_VERSION", "_M", "...", "_ENV",
    -- here too
    "__add", "__call", "__concat", "__div", "__idiv", "__eq", "__gc", "__index",
    "__le", "__lt", "__metatable", "__mode", "__mul", "__newindex",
    "__pow", "__sub", "__tostring", "__unm", "__len",
    "__pairs", "__ipairs",
    "__close",
    "NaN",
   "<const>", "<toclose>",
}

local internals = { -- __
    "add", "call", "concat", "div", "idiv", "eq", "gc", "index",
    "le", "lt", "metatable", "mode", "mul", "newindex",
    "pow", "sub", "tostring", "unm", "len",
    "pairs", "ipairs",
    "close",
}

local depricated = {
    "arg", "arg.n",
    "loadstring", "setfenv", "getfenv",
    "pack",
}

local csnames = { -- todo: option
    "commands",
    "context",
 -- "ctxcmd",
 -- "ctx",
    "metafun",
    "metapost",
}

local level         = nil
local setlevel      = function(_,i,s) level = s return i end

local equals        = P("=")^0

local longonestart  = P("[[")
local longonestop   = P("]]")
local longonestring = (1-longonestop)^0

local longtwostart  = P("[") * Cmt(equals,setlevel) * P("[")
local longtwostop   = P("]") *     equals           * P("]")

local sentinels = { } setmetatable(sentinels, { __index = function(t,k) local v = "]" .. k .. "]" t[k] = v return v end })

local longtwostring = P(function(input,index)
    if level then
     -- local sentinel = "]" .. level .. "]"
        local sentinel = sentinels[level]
        local _, stop = find(input,sentinel,index,true)
        return stop and stop + 1 - #sentinel or #input + 1
    end
end)

local longtwostring_body = longtwostring

local longtwostring_end = P(function(input,index)
    if level then
     -- local sentinel = "]" .. level .. "]"
        local sentinel = sentinels[level]
        local _, stop = find(input,sentinel,index,true)
        return stop and stop + 1 or #input + 1
    end
end)

local longcomment = Cmt(#("[[" + ("[" * C(equals) * "[")), function(input,index,level)
 -- local sentinel = "]" .. level .. "]"
    local sentinel = sentinels[level]
    local _, stop = find(input,sentinel,index,true)
    return stop and stop + 1 or #input + 1
end)

local space         = patterns.space -- S(" \n\r\t\f\v")
local any           = patterns.any
local eol           = patterns.eol
local exactmatch    = patterns.exactmatch
local justmatch     = patterns.justmatch

local squote        = P("'")
local dquote        = P('"')
local escaped       = P("\\") * P(1)
local dashes        = P("--")

local spacing       = token(luawhitespace, space^1)
local rest          = token("default", any)

local shortcomment  = token("comment", dashes * (1-eol)^0)
local longcomment   = token("comment", dashes * longcomment)

-- fails on very long string with \ at end of lines (needs embedded lexer)
-- and also on newline before " but it makes no sense to waste time on it

local shortstring   = token("quote",  dquote)
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)

----- longstring    = token("quote",  longonestart)
-----               * token("string", longonestring)
-----               * token("quote",  longonestop)
-----               + token("quote",  longtwostart)
-----               * token("string", longtwostring)
-----               * token("quote",  longtwostop)

local string        = shortstring
-----               + longstring

lexers.embed(lualexer, stringlexer, token("quote",longtwostart), token("string",longtwostring_body) * token("quote",longtwostring_end))

local integer       = P("-")^-1 * (patterns.hexadecimal + patterns.decimal)
local number        = token("number", patterns.float + integer)
                    * (token("error",R("AZ","az","__")^1))^0

-- officially 127-255 are ok but not utf so useless

----- validword     = R("AZ","az","__") * R("AZ","az","__","09")^0

local utf8character = P(1) * R("\128\191")^1
local validword     = (R("AZ","az","__") + utf8character) * (R("AZ","az","__","09") + utf8character)^0
local validsuffix   = (R("AZ","az")      + utf8character) * (R("AZ","az","__","09") + utf8character)^0

local identifier    = token("default",validword)

----- operator      = token("special", P('..') + P('~=') + S('+-*/%^#=<>;:,.{}[]()')) -- maybe split off {}[]()
----- operator      = token("special", S('+-*/%^#=<>;:,{}[]()') + P('..') + P('.') + P('~=') ) -- maybe split off {}[]()
----- operator      = token("special", S('+-*/%^#=<>;:,{}[]().') + P('~=') ) -- no ^1 because of nested lexers
local operator      = token("special", S('+-*/%^#=<>;:,{}[]().|~')) -- no ^1 because of nested lexers

local optionalspace = spacing^0
local hasargument   = #S("{([")

-- ideal should be an embedded lexer ..

local gotokeyword   = token("keyword", P("goto"))
                    * spacing
                    * token("grouping",validword)
local gotolabel     = token("keyword", P("::"))
                    * (spacing + shortcomment)^0
                    * token("grouping",validword)
                    * (spacing + shortcomment)^0
                    * token("keyword", P("::"))

local p_keywords    = exactmatch(keywords)
local p_functions   = exactmatch(functions)
local p_constants   = exactmatch(constants)
local p_internals   = P("__")
                    * exactmatch(internals)

local p_finish      = #(1-R("az","AZ","__"))

local p_csnames     = justmatch(csnames)
local p_ctnames     = P("ctx") * R("AZ","az","__")^0
local keyword       = token("keyword", p_keywords)
local builtin       = token("plain",   p_functions)
local constant      = token("data",    p_constants)
local internal      = token("data",    p_internals)
local csname        = token("user",    p_csnames + p_ctnames)
                    * p_finish * optionalspace * (
                        hasargument
                      + ( token("special", S(".:")) * optionalspace * token("user", validword) )^1
                      )^-1

-- we could also check S(".:") * p_keyword etc, could be faster

local identifier    = token("default", validword)
                    * ( optionalspace * token("special", S(".:")) * optionalspace * (
                            token("warning", p_keywords) +
                            token("data", p_internals) + -- needs checking
                            token("default", validword )
                    ) )^0

lualexer.rules = {
    { "whitespace",   spacing      },
    { "keyword",      keyword      }, -- can be combined
    { "function",     builtin      }, -- can be combined
    { "constant",     constant     }, -- can be combined
    { "csname",       csname       },
    { "goto",         gotokeyword  },
    { "identifier",   identifier   },
    { "string",       string       },
    { "number",       number       },
    { "longcomment",  longcomment  },
    { "shortcomment", shortcomment },
    { "label",        gotolabel    },
    { "operator",     operator     },
    { "rest",         rest         },
}

lualexer.folding = {
    -- challenge:  if=0  then=1  else=-1  elseif=-1
    ["if"]       = { ["keyword"] =  1 }, -- if .. [then|else] .. end
    ["do"]       = { ["keyword"] =  1 }, -- [while] do .. end
    ["function"] = { ["keyword"] =  1 }, -- function .. end
    ["repeat"]   = { ["keyword"] =  1 }, -- repeat .. until
    ["until"]    = { ["keyword"] = -1 },
    ["end"]      = { ["keyword"] = -1 },
 -- ["else"]     = { ["keyword"] =  1 },
 -- ["elseif"]   = { ["keyword"] =  1 }, -- already catched by if
 -- ["elseif"]   = { ["keyword"] =  0 },
    ["["] = {
        ["comment"] =  1,
     -- ["quote"]   =  1, -- confusing
    },
    ["]"] = {
        ["comment"] = -1
     -- ["quote"]   = -1, -- confusing
    },
 -- ["("] = { ["special"] =  1 },
 -- [")"] = { ["special"] = -1 },
    ["{"] = { ["special"] =  1 },
    ["}"] = { ["special"] = -1 },
}

-- embedded in tex:

local cstoken         = R("az","AZ","\127\255") + S("@!?_")
local texcsname       = P("\\") * cstoken^1
local commentline     = P("%") * (1-S("\n\r"))^0

local texcomment      = token("comment", Cmt(commentline, function() return directives.cld_inline end))

local longthreestart  = P("\\!!bs")
local longthreestop   = P("\\!!es")
local longthreestring = (1-longthreestop)^0

local texstring       = token("quote",  longthreestart)
                      * token("string", longthreestring)
                      * token("quote",  longthreestop)

local texcommand      = token("warning", texcsname)

lualexer.directives = directives

lualexer.rules_cld = {
    { "whitespace",   spacing      },
    { "texstring",    texstring    },
    { "texcomment",   texcomment   },
    { "texcommand",   texcommand   },
    { "keyword",      keyword      },
    { "function",     builtin      },
    { "csname",       csname       },
    { "goto",         gotokeyword  },
    { "constant",     constant     },
    { "identifier",   identifier   },
    { "string",       string       },
    { "longcomment",  longcomment  },
    { "shortcomment", shortcomment }, -- should not be used inline so best signal it as comment (otherwise complex state till end of inline)
    { "number",       number       },
    { "label",        gotolabel    },
    { "operator",     operator     },
    { "rest",         rest         },
}

return lualexer
