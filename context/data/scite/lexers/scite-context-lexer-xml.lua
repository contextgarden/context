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
local P, R, S, V, C, Cmt, Ct, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt, lpeg.Ct, lpeg.Cp
local type = type
local match, find = string.match, string.find

local lexer            = require("lexer")
local context          = lexer.context
local patterns         = context.patterns

local token            = lexer.token
local exact_match      = lexer.exact_match

local xmllexer         = lexer.new("xml","scite-context-lexer-xml")
local whitespace       = xmllexer.whitespace

local xmlcommentlexer  = lexer.load("scite-context-lexer-xml-comment") -- indirect (some issue with the lexer framework)
local xmlcdatalexer    = lexer.load("scite-context-lexer-xml-cdata")   -- indirect (some issue with the lexer framework)
local xmlscriptlexer   = lexer.load("scite-context-lexer-xml-script")  -- indirect (some issue with the lexer framework)
local lualexer         = lexer.load("scite-context-lexer-lua")         --

local space            = patterns.space
local any              = patterns.any

local dquote           = P('"')
local squote           = P("'")
local colon            = P(":")
local semicolon        = P(";")
local equal            = P("=")
local ampersand        = P("&")

local name             = (R("az","AZ","09") + S('_-.'))^1
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

local p_preamble = Cmt(#P("<?xml "), function(input,i,_) -- todo: utf bomb
    if i < 200 then
        validwords, validminimum = false, 3
        local language = match(input,"^<%?xml[^>]*%?>%s*<%?context%-directive%s+editor%s+language%s+(..)%s+%?>")
     -- if not language then
     --     language = match(input,'^<%?xml[^>]*language=[\"\'](..)[\"\'][^>]*%?>',i)
     -- end
        if language then
            validwords, validminimum = setwordlist(language)
        end
    end
    return false
end)

local p_word =
--     Ct( iwordpattern / function(s) return styleofword(validwords,validminimum,s) end * Cp() ) -- the function can be inlined
    iwordpattern / function(s) return styleofword(validwords,validminimum,s) end * Cp() -- the function can be inlined

local p_rest =
    token("default", any)

local p_text =
    token("default", (1-S("<>&")-space)^1)

local p_spacing =
    token(whitespace, space^1)
--     token("whitespace", space^1)

local p_optionalwhitespace =
    p_spacing^0

local p_localspacing =
    token("default", space^1)

-- Because we want a differently colored open and close we need an embedded lexer (whitespace
-- trigger). What is actually needed is that scintilla applies the current whitespace style.
-- Even using different style keys is not robust as they can be shared. I'll fix the main
-- lexer code.

local p_sstring =
    token("quote",dquote)
  * token("string",(1-dquote)^0)        -- different from context
  * token("quote",dquote)

local p_dstring =
    token("quote",squote)
  * token("string",(1-squote)^0)        -- different from context
  * token("quote",squote)

-- local p_comment =
--     token("command",opencomment)
--   * token("comment",(1-closecomment)^0) -- different from context
--   * token("command",closecomment)

-- local p_cdata =
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

local p_docstr  = p_dstring + p_sstring

local p_docent  = token("command",P("<!ENTITY"))
                * p_optionalwhitespace
                * token("keyword",name)
                * p_optionalwhitespace
                * (
                    (
                        token("constant",P("SYSTEM"))
                      * p_optionalwhitespace
                      * p_docstr
                      * p_optionalwhitespace
                      * token("constant",P("NDATA"))
                      * p_optionalwhitespace
                      * token("keyword",name)
                    ) + (
                        token("constant",P("PUBLIC"))
                      * p_optionalwhitespace
                      * p_docstr
                    ) + (
                        p_docstr
                    )
                  )
                * p_optionalwhitespace
                * token("command",P(">"))

local p_docele  = token("command",P("<!ELEMENT"))
                * p_optionalwhitespace
                * token("keyword",name)
                * p_optionalwhitespace
                * token("command",P("("))
                * (
                    p_spacing
                  + token("constant",P("#CDATA") + P("#PCDATA") + P("ANY"))
                  + token("text",P(","))
                  + token("comment",(1-S(",)"))^1)
                  )^1
                * token("command",P(")"))
                * p_optionalwhitespace
                * token("command",P(">"))

local p_docset  = token("command",P("["))
                * p_optionalwhitespace
                * ((p_optionalwhitespace * (p_docent + p_docele))^1 + token("comment",(1-P("]"))^0))
                * p_optionalwhitespace
                * token("command",P("]"))

local p_doctype = token("command",P("<!DOCTYPE"))
                * p_optionalwhitespace
                * token("keyword",name)
                * p_optionalwhitespace
                * (
                    (
                        token("constant",P("PUBLIC"))
                      * p_optionalwhitespace
                      * p_docstr
                      * p_optionalwhitespace
                      * p_docstr
                      * p_optionalwhitespace
                      ) + (
                        token("constant",P("SYSTEM"))
                      * p_optionalwhitespace
                      * p_docstr
                      * p_optionalwhitespace
                      )
                  )^-1
                * p_docset^-1
                * p_optionalwhitespace
                * token("command",P(">"))

lexer.embed_lexer(xmllexer, lualexer,        token("command", openlua),     token("command", closelua))
lexer.embed_lexer(xmllexer, xmlcommentlexer, token("command", opencomment), token("command", closecomment))
lexer.embed_lexer(xmllexer, xmlcdatalexer,   token("command", opencdata),   token("command", closecdata))
lexer.embed_lexer(xmllexer, xmlscriptlexer,  token("command", openscript),  token("command", closescript))

-- local p_name =
--     token("plain",name)
--   * (
--         token("default",colon)
--       * token("keyword",name)
--     )
--   + token("keyword",name)

local p_name = -- more robust
    token("plain",name * colon)^-1
  * token("keyword",name)

-- local p_key =
--     token("plain",name)
--   * (
--         token("default",colon)
--       * token("constant",name)
--     )
--   + token("constant",name)

local p_key =
    token("plain",name * colon)^-1
  * token("constant",name)

local p_attributes = (
    p_optionalwhitespace
  * p_key
  * p_optionalwhitespace
  * token("plain",equal)
  * p_optionalwhitespace
  * (p_dstring + p_sstring)
  * p_optionalwhitespace
)^0

local p_open =
    token("keyword",openbegin)
  * (
        p_name
      * p_optionalwhitespace
      * p_attributes
      * token("keyword",closebegin)
      +
      token("error",(1-closebegin)^1)
    )

local p_close =
    token("keyword",openend)
  * (
        p_name
      * p_optionalwhitespace
      * token("keyword",closeend)
      +
      token("error",(1-closeend)^1)
    )

local p_entity =
    token("constant",entity)

local p_instruction =
    token("command",openinstruction * P("xml"))
  * p_optionalwhitespace
  * p_attributes
  * p_optionalwhitespace
  * token("command",closeinstruction)
  + token("command",openinstruction * name)
  * token("default",(1-closeinstruction)^1)
  * token("command",closeinstruction)

local p_invisible =
    token("invisible",invisibles^1)

-- local p_preamble =
--     token('preamble',  p_preamble   )

xmllexer._rules = {
    { "whitespace",  p_spacing     },
    { "preamble",    p_preamble    },
    { "word",        p_word        },
 -- { "text",        p_text        },
 -- { "comment",     p_comment     },
 -- { "cdata",       p_cdata       },
    { "doctype",     p_doctype     },
    { "instruction", p_instruction },
    { "close",       p_close       },
    { "open",        p_open        },
    { "entity",      p_entity      },
    { "invisible",   p_invisible   },
    { "rest",        p_rest        },
}

xmllexer._tokenstyles = context.styleset

xmllexer._foldpattern = P("</") + P("<") + P("/>") -- separate entry else interference

xmllexer._foldsymbols = { -- somehow doesn't work yet
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
}

return xmllexer
