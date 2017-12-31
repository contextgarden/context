if not modules then modules = { } end modules ['buff-imp-parsed-xml'] = {
    version   = 1.001,
    comment   = "companion to buff-imp-parsed-xml.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local format = string.format

local context                     = context
local verbatim                    = context.verbatim

local write                       = visualizers.write
local writespace                  = visualizers.writespace
local writeargument               = visualizers.writeargument

local ParsedXmlSnippetKey         = context.ParsedXmlSnippetKey
local ParsedXmlSnippetValue       = context.ParsedXmlSnippetValue

local ParsedXmlSnippetElement     = verbatim.ParsedXmlSnippetElement
local ParsedXmlSnippetInstruction = verbatim.ParsedXmlSnippetInstruction
local ParsedXmlSnippetComment     = verbatim.ParsedXmlSnippetComment
local ParsedXmlSnippetCdata       = verbatim.ParsedXmlSnippetCdata
local ParsedXmlSnippetDoctype     = verbatim.ParsedXmlSnippetDoctype

local startParsedXmlSnippet       = context.startParsedXmlSnippet
local stopParsedXmlSnippet        = context.stopParsedXmlSnippet

local parsedxmlhandler = xml.newhandlers { -- todo: treat spaces and tabs
    name = "parsedxml",
    handle = function(...)
        print("error:",...) -- we need a handler as fallback, even if not used
    end,
    functions  = {
        ["@el@"] = function(e,handler)
            local at = e.at
            if at and next(at) then
                ParsedXmlSnippetElement(format("<%s",e.tg))
                for k, v in next, at do
                    writespace()
                    ParsedXmlSnippetKey()
                    writeargument(k)
                    verbatim("=")
                    ParsedXmlSnippetValue()
                    writeargument(format("%q",k))
                end
                ParsedXmlSnippetElement(">")
            else
                ParsedXmlSnippetElement(format("<%s>",e.tg))
            end
            handler.serialize(e.dt,handler)
            ParsedXmlSnippetElement(format("</%s>",e.tg))
        end,
        ["@pi@"] = function(e,handler)
            ParsedXmlSnippetInstruction("<?")
            write(e.dt[1])
            ParsedXmlSnippetInstruction("?>")
        end ,
        ["@cm@"] = function(e,handler)
            ParsedXmlSnippetComment("<!--")
            write(e.dt[1])
            ParsedXmlSnippetComment("-->")
        end,
        ["@cd@"] = function(e,handler)
            ParsedXmlSnippetCdata("<![CDATA[")
            write(e.dt[1])
            ParsedXmlSnippetCdata("]]>")
        end,
        ["@dt@"] = function(e,handler)
            ParsedXmlSnippetDoctype("<!DOCTYPE")
            write(e.dt[1])
            ParsedXmlSnippetDoctype(">")
        end,
        ["@tx@"] = function(s,handler)
            write(s)
        end,
    }
}

local function parsedxml(root,pattern)
    if root then
        if pattern then
            root = xml.filter(root,pattern)
        end
        if root then
            context.startParsedXmlSnippet()
            xml.serialize(root,parsedxmlhandler)
            context.stopParsedXmlSnippet()
        end
    end
end

local function parser(str,settings)
    parsedxml(xml.convert(string.strip(str)),settings and settings.pattern)
end

visualizers.parsedxml = parsedxml -- for use at the lua end (maybe namespace needed)

visualizers.register("parsed-xml", { parser = parser } )

