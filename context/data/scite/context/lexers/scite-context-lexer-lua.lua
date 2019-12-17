local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- beware: all multiline is messy, so even if it's no lexer, it should be an embedded lexer
-- we probably could use a local whitespace variant but this is cleaner

local P, R, S, C, Cmt, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cmt, lpeg.Cp
local match, find = string.match, string.find
local setmetatable = setmetatable

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token
local exact_match = lexer.exact_match
local just_match  = lexer.just_match

local lualexer    = lexer.new("lua","scite-context-lexer-lua")
local whitespace  = lualexer.whitespace

local stringlexer = lexer.load("scite-context-lexer-lua-longstring")
----- labellexer  = lexer.load("scite-context-lexer-lua-labelstring")

local directives  = { } -- communication channel

-- this will be extended

-- we could combine some in a hash that returns the class that then makes the token
-- this can save time on large files

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

-- local tokenmappings = { }
--
-- for i=1,#keywords  do tokenmappings[keywords [i]] = "keyword"  }
-- for i=1,#functions do tokenmappings[functions[i]] = "function" }
-- for i=1,#constants do tokenmappings[constants[i]] = "constant" }

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

local squote        = P("'")
local dquote        = P('"')
local escaped       = P("\\") * P(1)
local dashes        = P("--")

local spacing       = token(whitespace, space^1)
local rest          = token("default",  any)

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

lexer.embed_lexer(lualexer, stringlexer, token("quote",longtwostart), token("string",longtwostring_body) * token("quote",longtwostring_end))

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

local structure     = token("special", S('{}[]()'))

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

----- p_keywords    = exact_match(keywords)
----- p_functions   = exact_match(functions)
----- p_constants   = exact_match(constants)
----- p_internals   = P("__")
-----               * exact_match(internals)

local p_finish      = #(1-R("az","AZ","__"))
local p_keywords    = lexer.helpers.utfchartabletopattern(keywords)  * p_finish -- exact_match(keywords)
local p_functions   = lexer.helpers.utfchartabletopattern(functions) * p_finish -- exact_match(functions)
local p_constants   = lexer.helpers.utfchartabletopattern(constants) * p_finish -- exact_match(constants)
local p_internals   = P("__")
                    * lexer.helpers.utfchartabletopattern(internals) * p_finish -- exact_match(internals)

local p_csnames     = lexer.helpers.utfchartabletopattern(csnames) -- * p_finish -- just_match(csnames)
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

-- local t = { } for k, v in next, tokenmappings do t[#t+1] = k end t = table.concat(t)
-- -- local experimental =  (S(t)^1) / function(s) return tokenmappings[s] end * Cp()
--
-- local experimental =  Cmt(S(t)^1, function(_,i,s)
--     local t = tokenmappings[s]
--     if t then
--         return true, t, i
--     end
-- end)

lualexer._rules = {
    { "whitespace",   spacing      },
    { "keyword",      keyword      }, -- can be combined
 -- { "structure",    structure    },
    { "function",     builtin      }, -- can be combined
    { "constant",     constant     }, -- can be combined
 -- { "experimental", experimental }, -- works but better split
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

-- -- experiment
--
-- local idtoken = R("az","AZ","__")
--
-- function context.one_of_match(specification)
--     local pattern = idtoken -- the concat catches _ etc
--     local list = { }
--     for i=1,#specification do
--        local style = specification[i][1]
--        local words = specification[i][2]
--        pattern = pattern + S(table.concat(words))
--        for i=1,#words do
--            list[words[i]] = style
--        end
--    end
--    return Cmt(pattern^1, function(_,i,s)
--         local style = list[s]
--         if style then
--             return true, { style, i } -- and i or nil
--         else
--             -- fail
--         end
--    end)
-- end
--
-- local whatever = context.one_of_match {
--     { "keyword", keywords  }, -- keyword
--     { "plain",   functions }, -- builtin
--     { "data",    constants }, -- constant
-- }
--
-- lualexer._rules = {
--     { "whitespace",   spacing      },
--     { "whatever",     whatever     },
--     { "csname",       csname       },
--     { "goto",         gotokeyword  },
--     { "identifier",   identifier   },
--     { "string",       string       },
--     { "number",       number       },
--     { "longcomment",  longcomment  },
--     { "shortcomment", shortcomment },
--     { "label",        gotolabel    },
--     { "operator",     operator     },
--     { "rest",         rest         },
-- }

lualexer._tokenstyles = context.styleset

-- lualexer._foldpattern = R("az")^2 + S("{}[]") -- separate entry else interference

lualexer._foldpattern = (P("end") + P("if") + P("do") + P("function") + P("repeat") + P("until")) * P(#(1 - R("az")))
                      + S("{}[]")

lualexer._foldsymbols = {
    _patterns = {
        "[a-z][a-z]+",
        "[{}%[%]]",
    },
    ["keyword"] = { -- challenge:  if=0  then=1  else=-1  elseif=-1
        ["if"]       =  1, -- if .. [then|else] .. end
        ["do"]       =  1, -- [while] do .. end
        ["function"] =  1, -- function .. end
        ["repeat"]   =  1, -- repeat .. until
        ["until"]    = -1,
        ["end"]      = -1,
      },
    ["comment"] = {
        ["["] = 1, ["]"] = -1,
    },
 -- ["quote"] = { -- confusing
 --     ["["] = 1, ["]"] = -1,
 -- },
    ["special"] = {
     -- ["("] = 1, [")"] = -1,
        ["{"] = 1, ["}"] = -1,
    },
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

----- texcommand      = token("user", texcsname)
local texcommand      = token("warning", texcsname)

-- local texstring    = token("quote", longthreestart)
--                    * (texcommand + token("string",P(1-texcommand-longthreestop)^1) - longthreestop)^0 -- we match long non-\cs sequences
--                    * token("quote", longthreestop)

-- local whitespace    = "whitespace"
-- local spacing       = token(whitespace, space^1)

lualexer._directives = directives

lualexer._rules_cld = {
    { "whitespace",   spacing      },
    { "texstring",    texstring    },
    { "texcomment",   texcomment   },
    { "texcommand",   texcommand   },
 -- { "structure",    structure    },
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
