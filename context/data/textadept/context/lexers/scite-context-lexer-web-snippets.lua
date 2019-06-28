local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for web snippets",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S, C, Cg, Cb, Cs, Cmt, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cg, lpeg.Cb, lpeg.Cs, lpeg.Cmt, lpeg.match

local lexer        = require("scite-context-lexer")
local context      = lexer.context
local patterns     = context.patterns

local token        = lexer.token

local websnippets  = { }

local space        = patterns.space -- S(" \n\r\t\f\v")
local any          = patterns.any
local restofline   = patterns.restofline
local startofline  = patterns.startofline

local squote       = P("'")
local dquote       = P('"')
local period       = P(".")

local t_whitespace = token(whitespace, space^1)
local t_spacing    = token("default", space^1)
local t_rest       = token("default", any)

-- the web subset

local p_beginofweb = P("@")
local p_endofweb   = P("@>")

-- @, @/ @| @# @+ @; @[ @]

local p_directive_1 = p_beginofweb * S(",/|#+;[]")
local t_directive_1 = token("label",p_directive_1)

-- @.text @>(monospaced)
-- @:text @>(macro driven)
-- @= verbose@>
-- @! underlined @>
-- @t text @> (hbox)
-- @q ignored @>

local p_typeset = p_beginofweb * S(".:=!tq")
local t_typeset = token("label",p_typeset) * token("warning",(1-p_endofweb)^1) * token("label",p_endofweb)

-- @^index@>

local p_index = p_beginofweb * P("^")
local t_index = token("label",p_index) * token("function",(1-p_endofweb)^1) * token("label",p_endofweb)

-- @f text renderclass

local p_render = p_beginofweb * S("f")
local t_render = token("label",p_render) * t_spacing * token("warning",(1-space)^1) * t_spacing * token("label",(1-space)^1)

-- @s idem
-- @p idem
-- @& strip (spaces before)
-- @h

local p_directive_2 = p_beginofweb * S("sp&h")
local t_directive_2 = token("label",p_directive_2)

-- @< ... @> [=|+=|]
-- @(foo@>

local p_reference = p_beginofweb * S("<(")
local t_reference = token("label",p_reference) * token("function",(1-p_endofweb)^1) * token("label",p_endofweb * (P("+=") + P("="))^-1)

-- @'char' (ascii code)

local p_character = p_beginofweb * squote
local t_character = token("label",p_character) * token("reserved",(1-squote)^1) * token("label",squote)

-- @l nonascii

local p_nonascii = p_beginofweb * S("l")
local t_nonascii = token("label",p_nonascii) * t_spacing * token("reserved",(1-space)^1)

-- @x @y @z changefile
-- @i webfile

local p_filename = p_beginofweb * S("xyzi")
local t_filename = token("label",p_filename) * t_spacing * token("reserved",(1-space)^1)

-- @@  escape

local p_escape = p_beginofweb * p_beginofweb
local t_escape = token("text",p_escape)

-- structure

-- @* title.

-- local p_section = p_beginofweb * P("*")^1
-- local t_section = token("label",p_section) * t_spacing * token("function",(1-period)^1) * token("label",period)

-- @  explanation

-- local p_explanation = p_beginofweb
-- local t_explanation = token("label",p_explanation) * t_spacing^1

-- @d macro

-- local p_macro = p_beginofweb * P("d")
-- local t_macro = token("label",p_macro)

-- @c code

-- local p_code = p_beginofweb * P("c")
-- local t_code = token("label",p_code)

websnippets.pattern = P (
    t_typeset
  + t_index
  + t_render
  + t_reference
  + t_filename
  + t_directive_1
  + t_directive_2
  + t_character
  + t_nonascii
  + t_escape
)

return websnippets
