local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for xml",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- adapted from the regular context pretty printer code (after all, lexing
-- boils down to much of the same and there are only so many ways to do
-- things). Simplified a bit as we have a different nesting model.

-- todo: parse entities in attributes

local global, string, table, lpeg = _G, string, table, lpeg
local P, R, S, C, Cmt, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cmt, lpeg.Cp
local type = type
local match, find = string.match, string.find

local lexer            = require("scite-context-lexer")
local context          = lexer.context
local patterns         = context.patterns

local token            = lexer.token
local exact_match      = lexer.exact_match

local xmllexer         = lexer.new("xml","scite-context-lexer-xml")
local whitespace       = xmllexer.whitespace

local xmlcommentlexer  = lexer.load("scite-context-lexer-xml-comment")
local xmlcdatalexer    = lexer.load("scite-context-lexer-xml-cdata")
local xmlscriptlexer   = lexer.load("scite-context-lexer-xml-script")
local lualexer         = lexer.load("scite-context-lexer-lua")

local space            = patterns.space
local any              = patterns.any

local dquote           = P('"')
local squote           = P("'")
local colon            = P(":")
local semicolon        = P(";")
local equal            = P("=")
local ampersand        = P("&")

local name             = (R("az","AZ","09") + S("_-."))^1
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
local opendoctype      = P("<!DOCTYPE") -- could grab the whole doctype
local closedoctype     = P("]>") + P(">")
local openscript       = openbegin * (P("script") + P("SCRIPT")) * (1-closeend)^0 * closeend -- begin
local closescript      = openend   * (P("script") + P("SCRIPT"))                  * closeend

local openlua          = "<?lua"
local closelua         = "?>"

-- <!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
-- <!DOCTYPE Something PUBLIC "... ..." "..." >
-- <!DOCTYPE Something SYSTEM "... ..." [ ... ] >
-- <!DOCTYPE Something SYSTEM "... ..." >
-- <!DOCTYPE Something [ ... ] >
-- <!DOCTYPE Something >

local entity           = ampersand * (1-semicolon)^1 * semicolon

local utfchar          = context.utfchar
local wordtoken        = context.patterns.wordtoken
local iwordtoken       = context.patterns.iwordtoken
local wordpattern      = context.patterns.wordpattern
local iwordpattern     = context.patterns.iwordpattern
local invisibles       = context.patterns.invisibles
local checkedword      = context.checkedword
local styleofword      = context.styleofword
local setwordlist      = context.setwordlist
local validwords       = false
local validminimum     = 3

-- <?xml version="1.0" encoding="UTF-8" language="uk" ?>
--
-- <?context-directive editor language us ?>

local t_preamble = Cmt(P("<?xml "), function(input,i,_) -- todo: utf bomb, no longer #
    if i < 200 then
        validwords, validminimum = false, 3
        local language = match(input,"^<%?xml[^>]*%?>%s*<%?context%-directive%s+editor%s+language%s+(..)%s+%?>")
     -- if not language then
     --     language = match(input,"^<%?xml[^>]*language=[\"\'](..)[\"\'][^>]*%?>",i)
     -- end
        if language then
            validwords, validminimum = setwordlist(language)
        end
    end
    return false
end)

local t_word =
--     Ct( iwordpattern / function(s) return styleofword(validwords,validminimum,s) end * Cp() ) -- the function can be inlined
    iwordpattern / function(s) return styleofword(validwords,validminimum,s) end * Cp() -- the function can be inlined

local t_rest =
    token("default", any)

local t_text =
    token("default", (1-S("<>&")-space)^1)

local t_spacing =
    token(whitespace, space^1)

local t_optionalwhitespace =
    token("default", space^1)^0

local t_localspacing =
    token("default", space^1)

-- Because we want a differently colored open and close we need an embedded lexer (whitespace
-- trigger). What is actually needed is that scintilla applies the current whitespace style.
-- Even using different style keys is not robust as they can be shared. I'll fix the main
-- lexer code.

local t_sstring =
    token("quote",dquote)
  * token("string",(1-dquote)^0)        -- different from context
  * token("quote",dquote)

local t_dstring =
    token("quote",squote)
  * token("string",(1-squote)^0)        -- different from context
  * token("quote",squote)

-- local t_comment =
--     token("command",opencomment)
--   * token("comment",(1-closecomment)^0) -- different from context
--   * token("command",closecomment)

-- local t_cdata =
--     token("command",opencdata)
--   * token("comment",(1-closecdata)^0)   -- different from context
--   * token("command",closecdata)

-- maybe cdata just text (then we don't need the extra lexer as we only have one comment then)

-- <!DOCTYPE Something PUBLIC "... ..." "..." [ ... ] >
-- <!DOCTYPE Something PUBLIC "... ..." "..." >
-- <!DOCTYPE Something SYSTEM "... ..." [ ... ] >
-- <!DOCTYPE Something SYSTEM "... ..." >
-- <!DOCTYPE Something [ ... ] >
-- <!DOCTYPE Something >

-- <!ENTITY xxxx SYSTEM "yyyy" NDATA zzzz>
-- <!ENTITY xxxx PUBLIC "yyyy" >
-- <!ENTITY xxxx "yyyy" >

local t_docstr  = t_dstring + t_sstring

local t_docent  = token("command",P("<!ENTITY"))
                * t_optionalwhitespace
                * token("keyword",name)
                * t_optionalwhitespace
                * (
                    (
                        token("constant",P("SYSTEM"))
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      * token("constant",P("NDATA"))
                      * t_optionalwhitespace
                      * token("keyword",name)
                    ) + (
                        token("constant",P("PUBLIC"))
                      * t_optionalwhitespace
                      * t_docstr
                    ) + (
                        t_docstr
                    )
                  )
                * t_optionalwhitespace
                * token("command",P(">"))

local t_docele  = token("command",P("<!ELEMENT"))
                * t_optionalwhitespace
                * token("keyword",name)
                * t_optionalwhitespace
                * token("command",P("("))
                * (
                    t_localspacing
                  + token("constant",P("#CDATA") + P("#PCDATA") + P("ANY"))
                  + token("text",P(","))
                  + token("comment",(1-S(",)"))^1)
                  )^1
                * token("command",P(")"))
                * t_optionalwhitespace
                * token("command",P(">"))

local t_docset  = token("command",P("["))
                * t_optionalwhitespace
                * ((t_optionalwhitespace * (t_docent + t_docele))^1 + token("comment",(1-P("]"))^0))
                * t_optionalwhitespace
                * token("command",P("]"))

local t_doctype = token("command",P("<!DOCTYPE"))
                * t_optionalwhitespace
                * token("keyword",name)
                * t_optionalwhitespace
                * (
                    (
                        token("constant",P("PUBLIC"))
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      ) + (
                        token("constant",P("SYSTEM"))
                      * t_optionalwhitespace
                      * t_docstr
                      * t_optionalwhitespace
                      )
                  )^-1
                * t_docset^-1
                * t_optionalwhitespace
                * token("command",P(">"))

lexer.embed_lexer(xmllexer, lualexer,        token("command", openlua),     token("command", closelua))
lexer.embed_lexer(xmllexer, xmlcommentlexer, token("command", opencomment), token("command", closecomment))
lexer.embed_lexer(xmllexer, xmlcdatalexer,   token("command", opencdata),   token("command", closecdata))
lexer.embed_lexer(xmllexer, xmlscriptlexer,  token("command", openscript),  token("command", closescript))

-- local t_name =
--     token("plain",name)
--   * (
--         token("default",colon)
--       * token("keyword",name)
--     )
--   + token("keyword",name)

local t_name = -- more robust
    token("plain",name * colon)^-1
  * token("keyword",name)

-- local t_key =
--     token("plain",name)
--   * (
--         token("default",colon)
--       * token("constant",name)
--     )
--   + token("constant",name)

local t_key =
    token("plain",name * colon)^-1
  * token("constant",name)

local t_attributes = (
    t_optionalwhitespace
  * t_key
  * t_optionalwhitespace
  * token("plain",equal)
  * t_optionalwhitespace
  * (t_dstring + t_sstring)
  * t_optionalwhitespace
)^0

local t_open =
    token("keyword",openbegin)
  * (
        t_name
      * t_optionalwhitespace
      * t_attributes
      * token("keyword",closebegin)
      +
      token("error",(1-closebegin)^1)
    )

local t_close =
    token("keyword",openend)
  * (
        t_name
      * t_optionalwhitespace
      * token("keyword",closeend)
      +
      token("error",(1-closeend)^1)
    )

local t_entity =
    token("constant",entity)

local t_instruction =
    token("command",openinstruction * P("xml"))
  * t_optionalwhitespace
  * t_attributes
  * t_optionalwhitespace
  * token("command",closeinstruction)
  + token("command",openinstruction * name)
  * token("default",(1-closeinstruction)^1)
  * token("command",closeinstruction)

local t_invisible =
    token("invisible",invisibles^1)

-- local t_preamble =
--     token("preamble",  t_preamble   )

xmllexer._rules = {
    { "whitespace",  t_spacing     },
    { "preamble",    t_preamble    },
    { "word",        t_word        },
 -- { "text",        t_text        },
 -- { "comment",     t_comment     },
 -- { "cdata",       t_cdata       },
    { "doctype",     t_doctype     },
    { "instruction", t_instruction },
    { "close",       t_close       },
    { "open",        t_open        },
    { "entity",      t_entity      },
    { "invisible",   t_invisible   },
    { "rest",        t_rest        },
}

xmllexer._tokenstyles = context.styleset

xmllexer._foldpattern = P("</") + P("<") + P("/>") -- separate entry else interference
+ P("<!--") + P("-->")

xmllexer._foldsymbols = {
    _patterns = {
        "</",
        "/>",
        "<",
    },
    ["keyword"] = {
        ["</"] = -1,
        ["/>"] = -1,
        ["<"]  =  1,
    },
    ["command"] = {
        ["</"]   = -1,
        ["/>"]   = -1,
        ["<!--"] =  1,
        ["-->"]  = -1,
        ["<"]    =  1,
    },
}

return xmllexer
