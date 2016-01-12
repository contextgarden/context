if not modules then modules = { } end modules ['m-markdown'] = {
    version   = 1.002,
    comment   = "companion to m-markdown.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "see below",
    license   = "see context related readme files"
}

--[[
Copyright (C) 2009 John MacFarlane / Khaled Hosny / Hans Hagen

The main parser is derived from the lunamark parser written by John MacFarlane. You
can download lunamark from:

    http://github.com/jgm/lunamark.git

Khaled Hosny provided the context writer for lunamark and that was used as starting
point for the mapping. The original code can be fetched from the above location.

While playing with the original code I got the feeling that lpeg could perform better.
The slowdown was due to the fact that the parser's lpeg was reconstructed each time a
nested parse was needed. After changing that code a bit I could bring down parsing of
some test code from 2 seconds to less than 0.1 second so I decided to stick to this
parser instead of writing my own. After all, the peg code looks pretty impressive and
visiting Johns pandoc pages is worth the effort:

    http://johnmacfarlane.net/pandoc/

The code here is mostly meant for processing snippets embedded in a context
documents and is no replacement for pandoc at all. Therefore an alternative is to use
pandoc in combination with Aditya's filter module.

As I changed (and optimized) the original code, it will be clear that all errors
are mine. Eventually I might also adapt the parser code a bit more. When I ran into of
closure stack limitations I decided to flatten the code. The following implementation
seems to be a couple of hundred times faster than what I started with which is not that
bad.

This is a second rewrite. The mentioned speed gain largely depended on the kind of
content: blocks, references and items can be rather demanding. Also, There were
some limitations with respect to the captures. So, table storage has been removed in
favor of strings, and nesting has been simplified. The first example at the end of this
file now takes .33 seconds for 567KB code (resulting in over 1MB) so we're getting there.

There will be a third rewrite eventually.
]]--

-- todo: we have better quote and tag scanners in ctx
-- todo: provide an xhtml mapping
-- todo: add a couple of extensions
-- todo: check patches to the real peg

local type, next, tonumber = type, next, tonumber
local lower, upper, gsub, rep, gmatch, format, length = string.lower, string.upper, string.gsub, string.rep, string.gmatch, string.format, string.len
local concat = table.concat
local P, R, S, V, C, Ct, Cg, Cb, Cmt, Cc, Cf, Cs = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cb, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cs
local lpegmatch = lpeg.match
local utfbyte, utfchar = utf.byte, utf.char

moduledata          = moduledata or { }
moduledata.markdown = moduledata.markdown or { }
local markdown      = moduledata.markdown

local nofruns, nofbytes, nofhtmlblobs = 0, 0, 0

---------------------------------------------------------------------------------------------

local nestedparser
local syntax

nestedparser = function(str) return lpegmatch(syntax,str) end

---------------------------------------------------------------------------------------------

local asterisk               = P("*")
local dash                   = P("-")
local plus                   = P("+")
local underscore             = P("_")
local period                 = P(".")
local hash                   = P("#")
local ampersand              = P("&")
local backtick               = P("`")
local less                   = P("<")
local more                   = P(">")
local space                  = P(" ")
local squote                 = P("'")
local dquote                 = P('"')
local lparent                = P("(")
local rparent                = P(")")
local lbracket               = P("[")
local rbracket               = P("]")
local slash                  = P("/")
local equal                  = P("=")
local colon                  = P(":")
local semicolon              = P(";")
local exclamation            = P("!")

local digit                  = R("09")
local hexdigit               = R("09","af","AF")
local alphanumeric           = R("AZ","az","09")

local doubleasterisks        = P("**")
local doubleunderscores      = P("__")
local fourspaces             = P("    ")

local any                    = P(1)
local always                 = P("")

local tab                    = P("\t")
local spacechar              = S("\t ")
local spacing                = S(" \n\r\t")
local newline                = P("\r")^-1 * P("\n")
local spaceornewline         = spacechar + newline
local nonspacechar           = any - spaceornewline
local optionalspace          = spacechar^0
local spaces                 = spacechar^1
local eof                    = - any
local nonindentspace         = space^-3
local blankline              = optionalspace * C(newline)
local blanklines             = blankline^0
local skipblanklines         = (optionalspace * newline)^0
local linechar               = P(1 - newline)
local indent                 = fourspaces + (nonindentspace * tab) / ""
local indentedline           = indent    /"" * C(linechar^1 * (newline + eof))
local optionallyindentedline = indent^-1 /"" * C(linechar^1 * (newline + eof))
local spnl                   = optionalspace * (newline * optionalspace)^-1
local specialchar            = S("*_`*&[]<!\\")
local normalchar             = any - (specialchar + spaceornewline)
local line                   = C((any - newline)^0 * newline)
                             + C(any^1 * eof)
local nonemptyline           = (any - newline)^1 * newline

---------------------------------------------------------------------------------------------

local function lineof(c)
    return (nonindentspace * (P(c) * optionalspace)^3 * newline * blankline^1)
end

local lineof_asterisks       = lineof(asterisk)
local lineof_dashes          = lineof(dash)
local lineof_underscores     = lineof(underscore)

local bullet                 = nonindentspace * (plus + (asterisk - lineof_asterisks) + (dash - lineof_dashes)) * spaces
local enumerator             = nonindentspace * digit^1 * period * spaces

---------------------------------------------------------------------------------------------

local openticks              = Cg(backtick^1, "ticks")
local closeticks             = space^-1 * Cmt(C(backtick^1) * Cb("ticks"), function(s,i,a,b) return #a == #b and i end)
local intickschar            = (any - S(" \n\r`"))
                             + (newline * -blankline)
                             + (space - closeticks)
                             + (backtick^1 - closeticks)
local inticks                = openticks * space^-1 * C(intickschar^1) * closeticks

---------------------------------------------------------------------------------------------

local leader         = space^-3
local nestedbrackets = P { lbracket * ((1 - lbracket - rbracket) + V(1))^0 * rbracket }
local tag            = lbracket * C((nestedbrackets + 1 - rbracket)^0) * rbracket
local url            = less * C((1-more)^0) * more
                     + C((1-spacing- rparent)^1) -- sneaky: ) for resolver
local title_s        = squote  * lpeg.C((1-squote )^0) * squote
local title_d        = dquote  * lpeg.C((1-dquote )^0) * dquote
local title_p        = lparent * lpeg.C((1-rparent)^0) * rparent
local title          = title_s + title_d + title_p
local optionaltitle  = ((spacing^0 * title * spacechar^0) + lpeg.Cc(""))

local references = { }

local function register_link(tag,url,title)
    tag = lower(gsub(tag, "[ \n\r\t]+", " "))
    references[tag] = { url, title }
end

local function direct_link(label,url,title) -- title is typical html thing
    return label, url, title
end

local function indirect_link(label,tag)
    if tag == "" then
        tag = label
    end
    tag = lower(gsub(tag, "[ \n\r\t]+", " "))
    local r = references[tag]
    if r then
        return label, r[1], r[2]
    else
        return label, tag, ""
    end
end

local define_reference_parser = (leader * tag * colon * spacechar^0 * url * optionaltitle)             / register_link
local direct_link_parser      = tag * spacechar^0 * lparent * (url + Cc("")) * optionaltitle * rparent / direct_link
local indirect_link_parser    = tag * spacechar^0 * tag                                                / indirect_link

local rparser = (define_reference_parser+1)^0

local function referenceparser(str)
    references = { }
    lpegmatch(rparser,str)
end

-- local reftest = [[
-- [1]: <http://example.com/>
-- [3]:http://example.com/  (Optional Title Here)
-- [2]: http://example.com/  'Optional Title Here'
-- [a]: http://example.com/  "Optional *oeps* Title Here"
-- ]]
--
-- local linktest = [[
-- [This link] (http://example.net/)
-- [an example] (http://example.com/ "Title")
-- [an example][1]
-- [an example] [2]
-- ]]
--
-- lpeg.match((define_reference_parser+1)^0,reftest)
--
-- inspect(references)
--
-- lpeg.match((direct_link_parser/print + indirect_link_parser/print + 1)^0,linktest)

---------------------------------------------------------------------------------------------

local blocktags = table.tohash {
    "address", "blockquote" , "center", "dir", "div", "p", "pre",
    "li", "ol", "ul", "dl", "dd",
    "form", "fieldset", "isindex", "menu", "noframes", "frameset",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "hr", "ht", "script", "noscript",
    "table", "tbody", "tfoot", "thead", "th", "td", "tr",
}

----- htmlattributevalue     = squote * C((any - (blankline + squote))^0) * squote
-----                        + dquote * C((any - (blankline + dquote))^0) * dquote
-----                        + (any - S("\t >"))^1 -- any - tab - space - more
----- htmlattribute          = (alphanumeric + S("_-"))^1 * spnl * (equal * spnl * htmlattributevalue)^-1 * spnl
----- htmlcomment            = P("<!--") * (any - P("-->"))^0 * P("-->")

----- htmltag                = less * spnl * slash^-1 * alphanumeric^1 * spnl * htmlattribute^0 * slash^-1 * spnl * more
-----
----- blocktag               = Cmt(C(alphanumeric^1), function(s,i,a) return blocktags[lower(a)] and i, a end)
-----
----- openblocktag           = less * Cg(blocktag, "opentag") * spnl * htmlattribute^0 * more
----- closeblocktag          = less * slash * Cmt(C(alphanumeric^1) * Cb("opentag"), function(s,i,a,b) return lower(a) == lower(b) and i end) * spnl * more
----- selfclosingblocktag    = less * blocktag * spnl * htmlattribute^0 * slash * more
-----
----- displayhtml            = Cs { "HtmlBlock",
-----                           InBlockTags = openblocktag * (V("HtmlBlock") + (any - closeblocktag))^0 * closeblocktag,
-----                           HtmlBlock   = C(V("InBlockTags") + selfclosingblocktag + htmlcomment),
-----                        }
-----
----- inlinehtml             = Cs(htmlcomment + htmltag)

-- There is no reason to support crappy html, so we expect proper attributes.

local htmlattributevalue     = squote * C((any - (blankline + squote))^0) * squote
                             + dquote * C((any - (blankline + dquote))^0) * dquote
local htmlattribute          = (alphanumeric + S("_-"))^1 * spnl * equal * spnl * htmlattributevalue * spnl

local htmlcomment            = P("<!--") * (any - P("-->"))^0 * P("-->")
local htmlinstruction        = P("<?")   * (any - P("?>" ))^0 * P("?>" )

-- We don't care too much about matching elements and there is no reason why display elements could not
-- have inline elements so the above should be patched then. Well, markdown mixed with html is not meant
-- for anything else than webpages anyway.

local blocktag               = Cmt(C(alphanumeric^1), function(s,i,a) return blocktags[lower(a)] and i, a end)

local openelement            = less * alphanumeric^1 * spnl * htmlattribute^0 * more
local closeelement           = less * slash * alphanumeric^1 * spnl * more
local emptyelement           = less * alphanumeric^1 * spnl * htmlattribute^0 * slash * more

local displaytext            = (any - less)^1
local inlinetext             = displaytext / nestedparser

local displayhtml            = #(less * blocktag * spnl * htmlattribute^0 * more)
                             * Cs { "HtmlBlock",
                                InBlockTags = openelement * (V("HtmlBlock") + displaytext)^0 * closeelement,
                                HtmlBlock   = (V("InBlockTags") + emptyelement + htmlcomment + htmlinstruction),
                             }

local inlinehtml             = Cs { "HtmlBlock",
                                InBlockTags = openelement * (V("HtmlBlock") + inlinetext)^0 * closeelement,
                                HtmlBlock   = (V("InBlockTags") + emptyelement + htmlcomment + htmlinstruction),
                              }

---------------------------------------------------------------------------------------------

local hexentity = ampersand * hash * S("Xx") * C(hexdigit    ^1) * semicolon
local decentity = ampersand * hash           * C(digit       ^1) * semicolon
local tagentity = ampersand *                  C(alphanumeric^1) * semicolon

---------------------------------------------------------------------------------------------

-- --[[

local escaped = {
    ["{" ] = "",
    ["}" ] = "",
    ["$" ] = "",
    ["&" ] = "",
    ["#" ] = "",
    ["~" ] = "",
    ["|" ] = "",
    ["%%"] = "",
    ["\\"] = "",
}

for k, v in next, escaped do
    escaped[k] = "\\char" .. utfbyte(k) .. "{}"
end

local function c_string(s) -- has to be done more often
    return (gsub(s,".",escaped))
end

local c_linebreak = "\\crlf\n" -- is this ok?
local c_space     = " "

local function c_paragraph(c)
    return c .. "\n\n" -- { "\\startparagraph ", c, " \\stopparagraph\n" }
end

local function listitem(c)
    return format("\n\\startitem\n%s\n\\stopitem\n",nestedparser(c))
end

local function c_tightbulletlist(c)
    return format("\n\\startmarkdownitemize[packed]\n%s\\stopmarkdownitemize\n",c)
end

local function c_loosebulletlist(c)
    return format("\n\\startmarkdownitemize\n\\stopmarkdownitemize\n",c)
end

local function c_tightorderedlist(c)
    return format("\n\\startmarkdownitemize[n,packed]\n%s\\stopmarkdownitemize\n",c)
end

local function c_looseorderedlist(c)
    return format("\n\\startmarkdownitemize[n]\n%s\\stopmarkdownitemize\n",c)
end

local function c_inline_html(content)
    nofhtmlblobs = nofhtmlblobs + 1
    return format("\\markdowninlinehtml{%s}",content)
end

local function c_display_html(content)
    nofhtmlblobs = nofhtmlblobs + 1
    return format("\\startmarkdowndisplayhtml\n%s\n\\stopmarkdowndisplayhtml",content)
end

local function c_emphasis(c)
    return format("\\markdownemphasis{%s}",c)
end

local function c_strong(c)
    return format("\\markdownstrong{%s}",c)
end

local function c_blockquote(c)
    return format("\\startmarkdownblockquote\n%s\\stopmarkdownblockquote\n",nestedparser(c))
end

local function c_verbatim(c)
    return format("\\startmarkdowntyping\n%s\\stopmarkdowntyping\n",c)
end

local function c_code(c)
    return format("\\markdowntype{%s}",c)
end

local levels  = { "", "", "", "", "", "" }

local function c_start_document()
    levels = { "", "", "", "", "", "" }
    return ""
end

local function c_stop_document()
    return concat(levels,"\n") or ""
end

local function c_heading(level,c)
    if level > #levels then
        level = #levels
    end
    local finish = concat(levels,"\n",level) or ""
    for i=level+1,#levels do
        levels[i] = ""
    end
    levels[level] = "\\stopstructurelevel"
    return format("%s\\startstructurelevel[markdown][title={%s}]\n",finish,c)
end

local function c_hrule()
    return "\\markdownrule\n"
end

local function c_link(lab,src,tit)
    return format("\\goto{%s}[url(%s)]",nestedparser(lab),src)
end

local function c_image(lab,src,tit)
    return format("\\externalfigure[%s]",src)
end

local function c_email_link(address)
    return format("\\goto{%s}[url(mailto:%s)]",c_string(address),address)
end

local function c_url_link(url)
    return format("\\goto{%s}[url(%s)]",c_string(url),url)
end

local function f_heading(c,n)
    return c_heading(n,c)
end

local function c_hex_entity(s)
    return utfchar(tonumber(s,16))
end

local function c_dec_entity(s)
    return utfchar(tonumber(s))
end

local function c_tag_entity(s)
    return s -- we can use the default resolver
end

--]]

---------------------------------------------------------------------------------------------

--[[

local escaped = {
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ["&"] = "&amp;",
    ['"'] = "&quot;",
}

local function c_string(s) -- has to be done more often
    return (gsub(s,".",escaped))
end

local c_linebreak = "<br/>"
local c_space     = " "

local function c_paragraph(c)
    return format("<p>%s</p>\n", c)
end

local function listitem(c)
    return format("<li>%s</li>",nestedparser(c))
end

local function c_tightbulletlist(c)
    return format("<ul>\n%s\n</ul>\n",c)
end

local function c_loosebulletlist(c)
    return format("<ul>\n%s\n</ul>\n",c)
end

local function c_tightorderedlist(c)
    return format("<ol>\n%s\n</ol>\n",c)
end

local function c_looseorderedlist(c)
    return format("<ol>\n%s\n</ol>\n",c)
end

local function c_inline_html(content)
    nofhtmlblobs = nofhtmlblobs + 1
    return content
end

local function c_display_html(content)
    nofhtmlblobs = nofhtmlblobs + 1
    return format("\n%s\n",content)
end

local function c_emphasis(c)
    return format("<em>%s</em>",c)
end

local function c_strong(c)
    return format("<strong>%s</strong>",c)
end

local function c_blockquote(c)
    return format("<blockquote>\n%s\n</blockquote>",nestedparser(c))
end

local function c_verbatim(c)
    return format("<pre><code>%s</code></pre>",c)
end

local function c_code(c)
    return format("<code>%s</code>",c)
end

local c_start_document = ""
local c_stop_document  = ""

local function c_heading(level,c)
    return format("<h%d>%s</h%d>\n",level,c,level)
end

local function c_hrule()
    return "<hr/>\n"
end

local function c_link(lab,src,tit)
    local titattr = #tit > 0 and format(" title=%q",tit) or ""
    return format("<a href=%q%s>%s</a>",src,titattr,nestedparser(lab))
end

local function c_image(lab,src,tit)
    return format("<img href=%q title=%q>%s</a>",src,tit,nestedparser(lab))
end

local function c_email_link(address)
    return format("<a href=%q>%s</a>","mailto:",address,c_escape(address))
end

local function c_url_link(url)
    return format("<a href=%q>%s</a>",url,c_string(url))
end

local function f_heading(c,n)
    return c_heading(n,c)
end

local function c_hex_entity(s)
    return utfchar(tonumber(s,16))
end

local function c_dec_entity(s)
    return utfchar(tonumber(s))
end

local function c_tag_entity(s)
    return format("&%s;",s)
end

--]]

---------------------------------------------------------------------------------------------

local Str              = normalchar^1 / c_string
local Space            = spacechar^1  / c_space
local Symbol           = specialchar  / c_string
local Code             = inticks      / c_code

local HeadingStart     = C(hash * hash^-5) / length
local HeadingStop      = optionalspace * hash^0 * optionalspace * newline * blanklines
local HeadingLevel     = equal^3 * Cc(1)
                       + dash ^3 * Cc(2)

local NormalEndline    = optionalspace * newline * -(
                             blankline
                           + more
                           + HeadingStart
                           + ( line * (P("===")^3 + P("---")^3) * newline )
                         ) / c_space

local LineBreak        = P("  ") * NormalEndline / c_linebreak

local TerminalEndline  = optionalspace * newline * eof / ""

local Endline          = LineBreak
                       + TerminalEndline
                       + NormalEndline

local AutoLinkUrl      = less * C(alphanumeric^1 * P("://") * (any - (newline + more))^1)            * more / c_url_link
local AutoLinkEmail    = less * C((alphanumeric + S("-_+"))^1 * P("@") * (any - (newline + more))^1) * more / c_email_link

local DirectLink       = direct_link_parser   / c_link
local IndirectLink     = indirect_link_parser / c_link

local ImageLink        = exclamation * (direct_link_parser + indirect_link_parser) / c_image -- we can combine this with image ... smaller lpeg

local UlOrStarLine     = asterisk^4
                       + underscore^4
                       + (spaces * S("*_")^1 * #spaces) / c_string

local EscapedChar      = P("\\") * C(P(1 - newline)) / c_string

local InlineHtml       = inlinehtml  / c_inline_html
local DisplayHtml      = displayhtml / c_display_html
local HtmlEntity       = hexentity / c_hex_entity
                       + decentity / c_dec_entity
                       + tagentity / c_tag_entity

local NestedList       = Cs(optionallyindentedline - (bullet + enumerator))^1 / nestedparser

local ListBlockLine    = -blankline * -(indent^-1 * (bullet + enumerator)) * optionallyindentedline

local Verbatim         = Cs(blanklines * (indentedline - blankline)^1)  / c_verbatim
                       * (blankline^1 + eof) -- not really needed, probably capture trailing? we can do that beforehand

local Blockquote       = Cs((
                            ((nonindentspace * more * space^-1)/"" * linechar^0 * newline)^1
                          * ((linechar - blankline)^1 * newline)^0
                          * blankline^0
                         )^1) / c_blockquote

local HorizontalRule   = (lineof_asterisks + lineof_dashes + lineof_underscores) / c_hrule

local Reference        = define_reference_parser / ""

-- could be a mini grammar

local ListBlock             = line * ListBlockLine^0
local ListContinuationBlock = blanklines * indent * ListBlock
local ListItem              = Cs(ListBlock * (NestedList + ListContinuationBlock^0)) / listitem

---- LeadingLines  = blankline^0 / ""
---- TrailingLines = blankline^1 * #(any) / "\n"

syntax = Cs { "Document",

    Document              = V("Display")^0,

    Display               = blankline -- ^1/"\n"
                          + Blockquote
                          + Verbatim
                          + Reference
                          + HorizontalRule
                          + HeadingStart * optionalspace * Cs((V("Inline") - HeadingStop)^1) * HeadingStop / c_heading
                          + Cs((V("Inline") - Endline)^1) * newline * HeadingLevel * newline * blanklines  / f_heading
                          + Cs((bullet     /"" * ListItem)^1) *   blanklines * -bullet     / c_tightbulletlist
                          + Cs((bullet     /"" * ListItem     * C(blanklines))^1)          / c_loosebulletlist
                          + Cs((enumerator /"" * ListItem)^1) *   blanklines * -enumerator / c_tightorderedlist
                          + Cs((enumerator /"" * ListItem     * C(blanklines))^1)          / c_looseorderedlist
                          + DisplayHtml
                          + nonindentspace * Cs(V("Inline")^1)* newline * blankline^1 / c_paragraph
                          + V("Inline")^1,

    Inline                = Str
                          + Space
                          + Endline
                          + UlOrStarLine -- still needed ?
                          + doubleasterisks   * -spaceornewline * Cs((V("Inline") - doubleasterisks  )^1) * doubleasterisks   / c_strong
                          + doubleunderscores * -spaceornewline * Cs((V("Inline") - doubleunderscores)^1) * doubleunderscores / c_strong
                          + asterisk          * -spaceornewline * Cs((V("Inline") - asterisk         )^1) * asterisk          / c_emphasis
                          + underscore        * -spaceornewline * Cs((V("Inline") - underscore       )^1) * underscore        / c_emphasis
                          + ImageLink
                          + DirectLink
                          + IndirectLink
                          + AutoLinkUrl
                          + AutoLinkEmail
                          + Code
                          + InlineHtml
                          + HtmlEntity
                          + EscapedChar
                          + Symbol,

}

---------------------------------------------------------------------------------------------

local function convert(str)
    nofruns = nofruns + 1
    nofbytes = nofbytes + #str
    statistics.starttiming(markdown)
    referenceparser(str)
    local result = c_start_document() .. nestedparser(str) .. c_stop_document()
    statistics.stoptiming(markdown)
    return result
end

markdown.convert = convert

function markdown.typesetstring(data)
    if data and data ~= "" then
        local result = convert(data)
        context.viafile(result)
    end
end

function markdown.typesetbuffer(name)
    markdown.typesetstring(buffers.getcontent(name))
end

function markdown.typesetfile(name)
    local fullname = resolvers.findctxfile(name)
    if fullname and fullname ~= "" then
        markdown.typesetstring(io.loaddata(fullname))
    end
end

statistics.register("markdown",function()
    if nofruns > 0 then
        return format("%s bytes converted, %s runs, %s html blobs, %s seconds used",
            nofbytes, nofruns, nofhtmlblobs, statistics.elapsedtime(markdown))
    end
end)

---------------------------------------------------------------------------------------------

--~ context.starttext()
--~     moduledata.markdown.convert(str)
--~ context.stoptext()

if not tex.jobname then

    local one = [[
Test *123*
==========

<b>BOLD *BOLD* BOLD</b>

<pre>PRE <b>PRE</b> PRE</pre>


* Test
** Test
* Test1
    * Test2
* Test

Test
====

> test
> test **123** *123*
> test `code`

test

Test
====

> test
> test
> test

test
oeps

more

    code
    code

oeps

[an example][a]

[an example] [2]

[a]: http://example.com/  "Optional *oeps* Title Here"
[2]: http://example.com/  'Optional Title Here'
[3]: http://example.com/  (Optional Title Here)

[an example][a]

[an example] [2]

[an [tricky] example](http://example.com/ "Title")

[This **xx** link](http://example.net/)
    ]]

-- This snippet takes some 4 seconds in the original parser (the one that is
-- a bit clearer from the perspective of grammars but somewhat messy with
-- respect to the captures. In the above parser it takes .1 second. Also,
-- in the later case only memory is the limit.

    local two = [[
Test
====
* Test
** Test
* Test
** Test
* Test

Test
====

> test
> test
> test

test

Test
====

> test
> test
> test

test
    ]]

    local function test(str)
        local n = 1 -- 000
        local t = os.clock()
        local one = convert(str)
     -- print("runtime",1,#str,#one,os.clock()-t)
        str = string.rep(str,n)
        local t = os.clock()
        local two = convert(str)
        print(two)
     -- print("runtime",n,#str,#two,os.clock()-t)
     -- print(format("==============\n%s\n==============",one))
    end

 -- test(one)
 -- test(two)
 -- test(io.read("*all"))


end
