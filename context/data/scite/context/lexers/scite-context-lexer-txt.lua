local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for plain text (with spell checking)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, S, Cmt, Cp = lpeg.P, lpeg.S, lpeg.Cmt, lpeg.Cp
local find, match = string.find, string.match

local lexers         = require("scite-context-lexer")

local patterns       = lexers.patterns
local token          = lexers.token
local styleofword    = lexers.styleofword
local setwordlist    = lexers.setwordlist

local textlexer      = lexers.new("txt","scite-context-lexer-txt")
local textwhitespace = textlexer.whitespace

local space          = patterns.space
local any            = patterns.any
local wordtoken      = patterns.wordtoken
local wordpattern    = patterns.wordpattern


local validwords   = false
local validminimum = 3

-- [#!-%] language=uk (space before key is mandate)

local p_preamble = Cmt((S("#!-%") * P(" ") + P(true)), function(input,i)
    validwords   = false
    validminimum = 3
    local s, e, line = find(input,"^[#!%-%%](.+)[\n\r]",1)
    if line then
        local language = match(line," language=([a-z]+)")
        if language then
            validwords, validminimum = setwordlist(language)
        end
    end
    return false -- so we go back and now handle the line as text
end)

local t_preamble =
    token("preamble", p_preamble)

local t_word =
    C(wordpattern) * Cp() / function(s,p) return styleofword(validwords,validminimum,s,p) end -- a bit of a hack

local t_text =
    token("default", wordtoken^1)

local t_rest =
    token("default", (1-wordtoken-space)^1)

local t_spacing =
    token(textwhitespace, space^1)

textlexer.rules = {
    { "whitespace", t_spacing  },
    { "preamble",   t_preamble },
    { "word",       t_word     }, -- words >= 3
    { "text",       t_text     }, -- non words
    { "rest",       t_rest     },
}

return textlexer
