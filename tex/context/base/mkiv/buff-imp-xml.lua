if not modules then modules = { } end modules ['buff-imp-xml'] = {
    version   = 1.001,
    comment   = "companion to v-xml.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns

local context            = context
local verbatim           = context.verbatim
local makepattern        = visualizers.makepattern

local XmlSnippet         = context.XmlSnippet
local startXmlSnippet    = context.startXmlSnippet
local stopXmlSnippet     = context.stopXmlSnippet

local XmlSnippetName     = verbatim.XmlSnippetName
local XmlSnippetKey      = verbatim.XmlSnippetKey
local XmlSnippetBoundary = verbatim.XmlSnippetBoundary
local XmlSnippetString   = verbatim.XmlSnippetString
local XmlSnippetEqual    = verbatim.XmlSnippetEqual
local XmlSnippetEntity   = verbatim.XmlSnippetEntity
local XmlSnippetComment  = verbatim.XmlSnippetComment
local XmlSnippetCdata    = verbatim.XmlSnippetCdata

local handler = visualizers.newhandler {
    startinline  = function() XmlSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startXmlSnippet() end,
    stopdisplay  = function() stopXmlSnippet () end,
    name         = function(s) XmlSnippetName(s) end,
    key          = function(s) XmlSnippetKey(s) end,
    boundary     = function(s) XmlSnippetBoundary(s) end,
    string       = function(s) XmlSnippetString(s) end,
    equal        = function(s) XmlSnippetEqual(s) end,
    entity       = function(s) XmlSnippetEntity(s) end,
    comment      = function(s) XmlSnippetComment(s) end,
    cdata        = function(s) XmlSnippetCdata(s) end,
}

local comment          = P("--")
local alsoname         = patterns.utf8two + patterns.utf8three + patterns.utf8four
----- alsoname         = R("\128\255") -- basically any encoding without checking (fast)
local name             = (patterns.letter + patterns.digit + S('_-.') + alsoname)^1
local entity           = P("&") * (1-P(";"))^1 * P(";")
local openbegin        = P("<")
local openend          = P("</")
local closebegin       = P("/>") + P(">")
local closeend         = P(">")
local opencomment      = P("<!--")
local closecomment     = P("-->")
local openinstruction  = P("<?")
local closeinstruction = P("?>")
local opencdata        = P("<![CDATA[")
local closecdata       = P("]]>")

local grammar = visualizers.newgrammar("default", { "visualizer",
    sstring =
        makepattern(handler,"string",patterns.dquote)
      * (V("whitespace") + makepattern(handler,"default",(1-patterns.dquote)^0))
      * makepattern(handler,"string",patterns.dquote),
    dstring =
        makepattern(handler,"string",patterns.squote)
      * (V("whitespace") + makepattern(handler,"default",(1-patterns.squote)^0))
      * makepattern(handler,"string",patterns.squote),
    entity =
        makepattern(handler,"entity",entity),
    name =
        makepattern(handler,"name",name)
      * (
            makepattern(handler,"default",patterns.colon)
          * makepattern(handler,"name",name)
        )^0,
    key =
        makepattern(handler,"key",name)
      * (
            makepattern(handler,"default",patterns.colon)
          * makepattern(handler,"key",name)
        )^0,
    attributes = (
        V("optionalwhitespace")
      * V("key")
      * V("optionalwhitespace")
      * makepattern(handler,"equal",patterns.equal)
      * V("optionalwhitespace")
      * (V("dstring") + V("sstring"))
      * V("optionalwhitespace")
    )^0,
    open =
        makepattern(handler,"boundary",openbegin)
      * V("name")
      * V("optionalwhitespace")
      * V("attributes")
      * makepattern(handler,"boundary",closebegin),
    close =
        makepattern(handler,"boundary",openend)
      * V("name")
      * V("optionalwhitespace")
      * makepattern(handler,"boundary",closeend),
    comment =
        makepattern(handler,"boundary",opencomment)
      * (V("whitespace") + makepattern(handler,"comment",(1-closecomment)^1))^0 -- slow
      * makepattern(handler,"boundary",closecomment),
    cdata =
        makepattern(handler,"boundary",opencdata)
      * (V("whitespace") + makepattern(handler,"comment",(1-closecdata)^1))^0 -- slow
      * makepattern(handler,"boundary",closecdata),
    instruction =
        makepattern(handler,"boundary",openinstruction)
      * V("name")
      * V("optionalwhitespace")
      * V("attributes")
      * V("optionalwhitespace")
      * makepattern(handler,"boundary",closeinstruction),

    pattern =
        V("comment")
      + V("instruction")
      + V("cdata")
      + V("close")
      + V("open")
      + V("entity")
      + V("space")
      + V("line")
      + V("default"),

    visualizer =
        V("pattern")^1
} )

local parser = P(grammar)

visualizers.register("xml", { parser = parser, handler = handler, grammar = grammar } )
