if not modules then modules = { } end modules ['buff-imp-mp'] = {
    version   = 1.001,
    comment   = "companion to buff-imp-mp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Now that we also use lpeg lexers in scite, we can share the keywords
-- so we have moved the keyword lists to mult-mps.lua. Don't confuse the
-- scite lexers with the ones we use here. Of course all those lexers
-- boil down to doing similar things, but here we need more control over
-- the rendering and have a different way of nesting. It is no coincidence
-- that the coloring looks similar: both are derived from earlier lexing (in
-- texedit, mkii and the c++ scite lexer).
--
-- In the meantime we have lpeg based lexers in scite! And, as all this
-- lexing boils down to the same principles (associating symbolic rendering
-- with ranges of characters) and as the scite lexers do nesting, it makes
-- sense at some point to share code. However, keep in mind that the pretty
-- printers are also supposed to support invalid code (for educational
-- purposes). The scite lexers are more recent and there a different color
-- scheme is used. So, we might move away from the traditional coloring.

local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns

local context                      = context
local verbatim                     = context.verbatim
local makepattern                  = visualizers.makepattern

local MetapostSnippet              = context.MetapostSnippet
local startMetapostSnippet         = context.startMetapostSnippet
local stopMetapostSnippet          = context.stopMetapostSnippet

local MetapostSnippetConstructor   = verbatim.MetapostSnippetConstructor
local MetapostSnippetBoundary      = verbatim.MetapostSnippetBoundary
local MetapostSnippetSpecial       = verbatim.MetapostSnippetSpecial
local MetapostSnippetComment       = verbatim.MetapostSnippetComment
local MetapostSnippetCommentText   = verbatim.MetapostSnippetCommentText
local MetapostSnippetQuote         = verbatim.MetapostSnippetQuote
local MetapostSnippetString        = verbatim.MetapostSnippetString
local MetapostSnippetNamePrimitive = verbatim.MetapostSnippetNamePrimitive
local MetapostSnippetNamePlain     = verbatim.MetapostSnippetNamePlain
local MetapostSnippetNameMetafun   = verbatim.MetapostSnippetNameMetafun
local MetapostSnippetName          = verbatim.MetapostSnippetName

local primitives, plain, metafun

local function initialize()
    local mps = dofile(resolvers.findfile("mult-mps.lua","tex")) or {
        primitives = { },
        plain      = { },
        metafun    = { },
    }
    primitives = table.tohash(mps.primitives)
    plain      = table.tohash(mps.plain)
    metafun    = table.tohash(mps.metafun)
end

local function visualizename(s)
    if not primitives then
        initialize()
    end
    if primitives[s] then
        MetapostSnippetNamePrimitive(s)
    elseif plain[s] then
        MetapostSnippetNamePlain(s)
    elseif metafun[s] then
        MetapostSnippetNameMetafun(s)
    else
        MetapostSnippetName(s)
    end
end

local handler = visualizers.newhandler {
    startinline  = function() MetapostSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startMetapostSnippet() end,
    stopdisplay  = function() stopMetapostSnippet() end ,
    constructor  = function(s) MetapostSnippetConstructor(s) end,
    boundary     = function(s) MetapostSnippetBoundary(s) end,
    special      = function(s) MetapostSnippetSpecial(s) end,
    comment      = function(s) MetapostSnippetComment(s) end,
    commenttext  = function(s) MetapostSnippetCommentText(s) end,
    string       = function(s) MetapostSnippetString(s) end,
    quote        = function(s) MetapostSnippetQuote(s) end,
    name         = visualizename,
}

local comment     = P("%")
local name        = (patterns.letter + S("_"))^1
local constructor = S("$@#")
local boundary    = S('()[]:=<>;"')
local special     = S("-+/*|`!?^&%.,")

local grammar = visualizers.newgrammar("default", { "visualizer",

    comment     = makepattern(handler,"comment",comment)
                * makepattern(handler,"commenttext",(patterns.anything - patterns.newline)^0),
    dstring     = makepattern(handler,"quote",patterns.dquote)
                * makepattern(handler,"string",patterns.nodquote)
                * makepattern(handler,"quote",patterns.dquote),
    name        = makepattern(handler,"name",name),
    constructor = makepattern(handler,"constructor",constructor),
    boundary    = makepattern(handler,"boundary",boundary),
    special     = makepattern(handler,"special",special),

    pattern     =
        V("comment") + V("dstring") + V("name") + V("constructor") + V("boundary") + V("special")
      + V("newline") * V("emptyline")^0 * V("beginline")
      + V("space")
      + V("default"),

    visualizer  =
        V("pattern")^1

} )

local parser = P(grammar)

visualizers.register("mp", { parser = parser, handler = handler, grammar = grammar } )
