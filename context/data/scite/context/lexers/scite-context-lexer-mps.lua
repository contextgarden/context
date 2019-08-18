local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local global, string, table, lpeg = _G, string, table, lpeg
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local type = type

local lexer              = require("scite-context-lexer")
local context            = lexer.context
local patterns           = context.patterns

local token              = lexer.token
local exact_match        = lexer.exact_match

local metafunlexer       = lexer.new("mps","scite-context-lexer-mps")
local whitespace         = metafunlexer.whitespace

local metapostprimitives = { }
local metapostinternals  = { }
local metapostshortcuts  = { }
local metapostcommands   = { }

local metafuninternals   = { }
local metafunshortcuts   = { }
local metafuncommands    = { }

local mergedshortcuts    = { }
local mergedinternals    = { }

do

    local definitions = context.loaddefinitions("scite-context-data-metapost")

    if definitions then
        metapostprimitives = definitions.primitives or { }
        metapostinternals  = definitions.internals  or { }
        metapostshortcuts  = definitions.shortcuts  or { }
        metapostcommands   = definitions.commands   or { }
    end

    local definitions = context.loaddefinitions("scite-context-data-metafun")

    if definitions then
        metafuninternals  = definitions.internals or { }
        metafunshortcuts  = definitions.shortcuts or { }
        metafuncommands   = definitions.commands  or { }
    end

    for i=1,#metapostshortcuts do
        mergedshortcuts[#mergedshortcuts+1] = metapostshortcuts[i]
    end
    for i=1,#metafunshortcuts do
        mergedshortcuts[#mergedshortcuts+1] = metafunshortcuts[i]
    end

    for i=1,#metapostinternals do
        mergedinternals[#mergedinternals+1] = metapostinternals[i]
    end
    for i=1,#metafuninternals do
        mergedinternals[#mergedinternals+1] = metafuninternals[i]
    end

end

local space      = patterns.space -- S(" \n\r\t\f\v")
local any        = patterns.any

local dquote     = P('"')
local cstoken    = patterns.idtoken
local mptoken    = patterns.alpha
local leftbrace  = P("{")
local rightbrace = P("}")
local number     = patterns.real

local cstokentex = R("az","AZ","\127\255") + S("@!?_")

-- we could collapse as in tex

local spacing    = token(whitespace,  space^1)
local rest       = token("default",   any)
local comment    = token("comment",   P("%") * (1-S("\n\r"))^0)
local internal   = token("reserved",  exact_match(mergedshortcuts,false))
local shortcut   = token("data",      exact_match(mergedinternals))

local helper     = token("command",   exact_match(metafuncommands))
local plain      = token("plain",     exact_match(metapostcommands))
local quoted     = token("quote",     dquote)
                 * token("string",    P(1-dquote)^0)
                 * token("quote",     dquote)
local separator  = P(" ") + S("\n\r")^1
local btex       = (P("btex") + P("verbatimtex")) * separator
local etex       = separator * P("etex")
local texstuff   = token("quote",     btex)
                 * token("string",    (1-etex)^0)
                 * token("quote",     etex)
local primitive  = token("primitive", exact_match(metapostprimitives))
local identifier = token("default",   cstoken^1)
local number     = token("number",    number)
local grouping   = token("grouping",  S("()[]{}")) -- can be an option
local suffix     = token("number",    P("#@") + P("@#") + P("#"))
local special    = token("special",   P("#@") + P("@#") + S("#()[]{}<>=:\"")) -- or else := <> etc split
local texlike    = token("warning",   P("\\") * cstokentex^1)
local extra      = token("extra",     P("+-+") + P("++") + S("`~%^&_-+*/\'|\\"))

local nested     = P { leftbrace * (V(1) + (1-rightbrace))^0 * rightbrace }
local texlike    = token("embedded", P("\\") * (P("MP") + P("mp")) * mptoken^1)
                 * spacing^0
                 * token("grouping", leftbrace)
                 * token("default",  (nested + (1-rightbrace))^0 )
                 * token("grouping", rightbrace)
                 + token("warning",  P("\\") * cstokentex^1)

-- lua: we assume: lua ( "lua code" )

local cldlexer     = lexer.load("scite-context-lexer-cld","mps-cld")

local startlua     = P("lua") * space^0 * P('(') * space^0 * P('"')
local stoplua      = P('"') * space^0 * P(')')

local startluacode = token("embedded", startlua)
local stopluacode  = #stoplua * token("embedded", stoplua)

lexer.embed_lexer(metafunlexer, cldlexer, startluacode, stopluacode)

local luacall      = token("embedded",P("lua") * ( P(".") * R("az","AZ","__")^1 )^1)

local keyword      = token("default", (R("AZ","az","__")^1) * # P(space^0 * P("=")))

metafunlexer._rules = {
    { "whitespace", spacing    },
    { "comment",    comment    },
    { "keyword",    keyword    },  -- experiment, maybe to simple
    { "internal",   internal   },
    { "shortcut",   shortcut   },
    { "luacall",    luacall    },
    { "helper",     helper     },
    { "plain",      plain      },
    { "primitive",  primitive  },
    { "texstuff",   texstuff   },
    { "suffix",     suffix     },
    { "identifier", identifier },
    { "number",     number     },
    { "quoted",     quoted     },
 -- { "grouping",   grouping   }, -- can be an option
    { "special",    special    },
    { "texlike",    texlike    },
    { "extra",      extra      },
    { "rest",       rest       },
}

metafunlexer._tokenstyles = context.styleset

metafunlexer._foldpattern = patterns.lower^2 -- separate entry else interference

metafunlexer._foldsymbols = {
    _patterns = {
        "[a-z][a-z]+",
    },
    ["plain"] = {
        ["beginfig"]      =  1,
        ["endfig"]        = -1,
        ["beginglyph"]    =  1,
        ["endglyph"]      = -1,
     -- ["begingraph"]    =  1,
     -- ["endgraph"]      = -1,
    },
    ["primitive"] = {
        ["def"]           =  1,
        ["vardef"]        =  1,
        ["primarydef"]    =  1,
        ["secondarydef" ] =  1,
        ["tertiarydef"]   =  1,
        ["enddef"]        = -1,
        ["if"]            =  1,
        ["fi"]            = -1,
        ["for"]           =  1,
        ["forever"]       =  1,
        ["endfor"]        = -1,
    }
}

-- if inspect then inspect(metafunlexer) end

return metafunlexer
