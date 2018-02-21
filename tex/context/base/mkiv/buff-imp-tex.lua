if not modules then modules = { } end modules ['buff-imp-tex'] = {
    version   = 1.001,
    comment   = "companion to v-tex.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs an update, use mult-low

local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns

local context               = context
local verbatim              = context.verbatim
local makepattern           = visualizers.makepattern
local makenested            = visualizers.makenested
local getvisualizer         = visualizers.getvisualizer

local TexSnippet            = context.TexSnippet
local startTexSnippet       = context.startTexSnippet
local stopTexSnippet        = context.stopTexSnippet

local TexSnippetName        = verbatim.TexSnippetName
local TexSnippetGroup       = verbatim.TexSnippetGroup
local TexSnippetBoundary    = verbatim.TexSnippetBoundary
local TexSnippetSpecial     = verbatim.TexSnippetSpecial
local TexSnippetComment     = verbatim.TexSnippetComment
local TexSnippetCommentText = verbatim.TexSnippetCommentText

local handler = visualizers.newhandler {
    startinline  = function() TexSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startTexSnippet() end,
    stopdisplay  = function() stopTexSnippet() end ,
    name         = function(s) TexSnippetName(s) end,
    group        = function(s) TexSnippetGroup(s) end,
    boundary     = function(s) TexSnippetBoundary(s) end,
    special      = function(s) TexSnippetSpecial(s) end,
    comment      = function(s) TexSnippetComment(s) end,
    commenttext  = function(s) TexSnippetCommentText(s) end,
}

-- todo: unicode letters in control sequences (slow as we need to test the nature)

local comment  = S("%")
local name     = P("\\") * (patterns.letter + S("@!?_") + patterns.utf8two + patterns.utf8three + patterns.utf8four)^1
local escape   = P("\\") * (patterns.anything - patterns.newline)^-1 -- else we get \n
local group    = S("${}")
local boundary = S('[]()<>#="')
local special  = S("/^_-&+'`|")

local p_comment     = makepattern(handler,"comment",comment)
                    * makepattern(handler,"commenttext",(patterns.anything - patterns.newline)^0)
local p_name        = makepattern(handler,"name",name)
local p_escape      = makepattern(handler,"name",escape)
local p_group       = makepattern(handler,"group",group)
local p_boundary    = makepattern(handler,"boundary",boundary)
local p_special     = makepattern(handler,"special",special)
local p_somespace   = V("newline") * V("emptyline")^0 * V("beginline")
                    + V("space")

--~ local pattern = visualizers.pattern

local grammar = visualizers.newgrammar("default", { "visualizer",

    comment     = p_comment,
    name        = p_name,
    escape      = p_escape,
    group       = p_group,
    boundary    = p_boundary,
    special     = p_special,
    somespace   = p_somespace,

    pattern     = V("comment")
                + V("name") + V("escape") + V("group") + V("boundary") + V("special")
                + V("newline") * V("emptyline")^0 * V("beginline")
                + V("space")
                + V("default"),

    visualizer  = V("pattern")^1

} )

local parser = P(grammar)

visualizers.register("tex", { parser = parser, handler = handler, grammar = grammar } )

local function makecommand(handler,how,start,left,right)
    local c, l, r, f = P(start), P(left), P(right), how
    local n = ( P { l * ((1 - (l + r)) + V(1))^0 * r } + P(1-r) )^0
    if type(how) == "string" then
        f = function(s) getvisualizer(how,"direct")(s) end
    end
    return makepattern(handler,"name",c)
         * V("somespace")^0
         * makepattern(handler,"group",l)
         * (n/f)
         * makepattern(handler,"group",r)
end

local grammar = visualizers.newgrammar("default", { "visualizer",

    comment     = p_comment,
    name        = p_name,
    escape      = p_escape,
    group       = p_group,
    boundary    = p_boundary,
    special     = p_special,
    somespace   = p_somespace,

    mpcode      = makenested(handler,"mp","\\startMPcode","\\stopMPcode")
                + makenested(handler,"mp","\\startMPgraphic","\\stopMPgraphic")
                + makenested(handler,"mp","\\startuseMPgraphic","\\stopuseMPgraphic")
                + makenested(handler,"mp","\\startreusableMPgraphic","\\stopreusableMPgraphic")
                + makenested(handler,"mp","\\startuniqueMPgraphic","\\stopuniqueMPgraphic")
                + makenested(handler,"mp","\\startMPpage","\\stopMPpage"),

    luacode     = makenested (handler,"lua","\\startluacode","\\stopluacode")
                + makecommand(handler,"lua","\\ctxlua","{","}"),

    pattern     = V("comment")
                + V("mpcode") + V("luacode")
                + V("name") + V("escape") + V("group") + V("boundary") + V("special")
                + V("newline") * V("emptyline")^0 * V("beginline")
                + V("space")
                + V("default"),

    visualizer  = V("pattern")^1

} )

local parser = P(grammar)

visualizers.register("context", { parser = parser, handler = handler, grammar = grammar } )
