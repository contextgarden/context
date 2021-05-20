if not modules then modules = { } end modules ['syst-con'] = {
    version   = 1.001,
    comment   = "companion to syst-con.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local math = math
local utfchar = utf.char
local gsub = string.gsub

converters       = converters or { }
local converters = converters

local context    = context
local commands   = commands
local implement  = interfaces.implement

local formatters = string.formatters

--[[ldx--
<p>For raw 8 bit characters, the offset is 0x110000 (bottom of plane 18) at
the top of <l n='luatex'/>'s char range but outside the unicode range.</p>
--ldx]]--

function converters.hexstringtonumber(n) tonumber(n,16) end
function converters.octstringtonumber(n) tonumber(n, 8) end

function converters.rawcharacter     (n) utfchar(0x110000+n) end

local f_lchexnumber  = formatters["%x"]
local f_uchexnumber  = formatters["%X"]
local f_lchexnumbers = formatters["%02x"]
local f_uchexnumbers = formatters["%02X"]
local f_octnumber    = formatters["%03o"]
local   nicenumber   = formatters["%0.6F"] -- or N

local lchexnumber  = function(n) if n < 0 then n = 0x100000000 + n end return f_lchexnumber (n) end
local uchexnumber  = function(n) if n < 0 then n = 0x100000000 + n end return f_uchexnumber (n) end
local lchexnumbers = function(n) if n < 0 then n = 0x100000000 + n end return f_lchexnumbers(n) end
local uchexnumbers = function(n) if n < 0 then n = 0x100000000 + n end return f_uchexnumbers(n) end
local octnumber    = function(n) if n < 0 then n = 0x100000000 + n end return f_octnumber   (n) end

converters.lchexnumber  = lchexnumber
converters.uchexnumber  = uchexnumber
converters.lchexnumbers = lchexnumbers
converters.uchexnumbers = uchexnumbers
converters.octnumber    = octnumber
converters.nicenumber   = nicenumber

implement { name = "hexstringtonumber", actions = { tonumber, context }, arguments = { "integer", 16 } }
implement { name = "octstringtonumber", actions = { tonumber, context }, arguments = { "integer",  8 } }

implement { name = "rawcharacter", actions = function(n) context(utfchar(0x110000+n)) end, arguments = "integer" }

implement { name = "lchexnumber",  actions = { lchexnumber,  context }, arguments = "integer" }
implement { name = "uchexnumber",  actions = { uchexnumber,  context }, arguments = "integer" }
implement { name = "lchexnumbers", actions = { lchexnumbers, context }, arguments = "integer" }
implement { name = "uchexnumbers", actions = { uchexnumbers, context }, arguments = "integer" }
implement { name = "octnumber",    actions = { octnumber,    context }, arguments = "integer" }

implement { name = "sin",  actions = { math.sin,  nicenumber, context }, arguments = "number" }
implement { name = "cos",  actions = { math.cos,  nicenumber, context }, arguments = "number" }
implement { name = "tan",  actions = { math.tan,  nicenumber, context }, arguments = "number" }

implement { name = "sind", actions = { math.sind, nicenumber, context }, arguments = "number" }
implement { name = "cosd", actions = { math.cosd, nicenumber, context }, arguments = "number" }
implement { name = "tand", actions = { math.tand, nicenumber, context }, arguments = "number" }

-- only as commands

function commands.format(fmt,...) context((gsub(fmt,"@","%%")),...) end

implement {
    name      = "formatone",
    public    = true,
    protected = true,
    arguments = "2 strings",
    actions   = function(f,s) context((gsub(f,"@","%%")),s) end,
}
