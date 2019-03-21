if not modules then modules = { } end modules ['mtx-dvi'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is just a tool that I use for checking dvi issues in LuaTeX and it has
-- no real use otherwise. When needed (or on request) I can extend this script.
-- Speed is hardly an issue and I didn't spend much time on generalizing the
-- code either.

local formatters = string.formatters
local byte = string.byte

local P, R, S, C, Cc, Ct, Cmt = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.Cmt
local lpegmatch = lpeg.match

local readbyte      = utilities.files.readbyte
local readcardinal1 = utilities.files.readcardinal1
local readcardinal2 = utilities.files.readcardinal2
local readcardinal3 = utilities.files.readcardinal3
local readcardinal4 = utilities.files.readcardinal4
local readinteger1  = utilities.files.readinteger1
local readinteger2  = utilities.files.readinteger2
local readinteger3  = utilities.files.readinteger3
local readinteger4  = utilities.files.readinteger4
local readstring    = utilities.files.readstring

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-dvi</entry>
  <entry name="detail">ConTeXt DVI Helpers</entry>
  <entry name="version">0.01</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="list"><short>list dvi commands</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-dvi",
    banner   = "ConTeXt DVI Helpers 0.10",
    helpinfo = helpinfo,
}

local report = application.report

local f_set_char_fast   = formatters["set char fast    %C"]
local f_set_char        = formatters["set char         %C"]
local f_set_rule        = formatters["set rule         height=%p width=%p (%s %s)"]
local f_put_char        = formatters["put char         %C"]
local f_put_rule        = formatters["put rule         height=%p width=%p (%s %s)"]
local f_set_font        = formatters["set font         %i"]
local f_set_font_fast   = formatters["set font fast    %i"]
local f_right           = formatters["right            %p (%s)"]
local f_right_w         = formatters["right            w"]
local f_right_x         = formatters["right            x"]
local f_right_w_set     = formatters["right set        w %p (%s)"]
local f_right_x_set     = formatters["right set        x %p (%s)"]
local f_down            = formatters["down             %p (%s)"]
local f_down_y          = formatters["down             y"]
local f_down_z          = formatters["down             z"]
local f_down_y_set      = formatters["down set         y %p (%s)"]
local f_down_z_set      = formatters["down set         z %p (%s)"]
local f_page_begin      = formatters["page begin       (% t) %i"]
local f_page_end        = formatters["page end"]
local f_nop             = formatters["nop"]
local f_push            = formatters["push             %i"]
local f_pop             = formatters["pop              %i"]
local f_special         = formatters["special          %s"]
local f_preamble        = formatters["preamble         version=%s numerator=%s denominator=%s mag=%s comment=%s"]
local f_postamble_begin = formatters["postamble"]
local f_postamble_end   = formatters["postamble end    offset=%s version=%s"]
local f_define_font     = formatters["define font      k=%i checksum=%i scale=%p designsize=%p area=%s name=%s"]

local currentdepth = 0
local usedprinter  = (logs and logs.writer) or (texio and texio.write_nl) or print

local handler = { } for i=0,255 do handler[i] = false end

local function define_font(f,size)
    local k = size == 1 and readcardinal1(f)
           or size == 2 and readcardinal2(f)
           or size == 3 and readcardinal3(f)
           or               readcardinal4(f)
    local c = readcardinal4(f)
    local s = readcardinal4(f)
    local d = readcardinal4(f)
    local a = readcardinal1(f)
    local l = readcardinal1(f)
    local a = readstring(f,a)
    local l = readstring(f,l)
    usedprinter(f_define_font(k,c,s,d,area,name))
end

handler[000] = function(f,b)
    usedprinter(f_set_char_fast(b))
end

handler[128] = function(f)
    usedprinter(f_set_char(readcardinal1(f)))
end
handler[129] = function(f)
    usedprinter(f_set_char(readcardinal2(f)))
end
handler[130] = function(f)
    usedprinter(f_set_char(readcardinal3(f)))
end
handler[131] = function(f)
    usedprinter(f_set_char(readcardinal4(f)))
end

handler[132] = function(f)
    usedprinter(f_set_rule(readinteger4(f),readinteger4(f)))
end

handler[133] = function(f)
    usedprinter(f_put_char(readcardinal1(f)))
end
handler[134] = function(f)
    usedprinter(f_put_char(readcardinal2(f)))
end
handler[135] = function(f)
    usedprinter(f_put_char(readcardinal3(f)))
end
handler[136] = function(f)
    usedprinter(f_put_char(readcardinal4(f)))
end

handler[137] = function(f)
    usedprinter(f_put_rule(readinteger4(f),readinteger4(f)))
end

handler[138] = function(f)
    usedprinter(f_nop())
end

handler[139] = function(f)
    local pages = { }
    for i=0,9 do
        pages[i] = readinteger4(f)
    end
    usedprinter(f_page_begin(pages,readinteger4(f)))
end
handler[140] = function()
    usedprinter(f_page_end())
end

handler[141] = function()
    currentdepth = currentdepth + 1
    usedprinter(f_push(currentdepth))
end
handler[142] = function()
    usedprinter(f_pop(currentdepth))
    currentdepth = currentdepth - 1
end

handler[143] = function(f)
    local d = readinteger1(f)
    usedprinter(f_right(d,d))
end
handler[144] = function(f)
    local d = readinteger2(f)
    usedprinter(f_right(d,d))
end
handler[145] = function(f)
    local d = readinteger3(f)
    usedprinter(f_right(d,d))
end
handler[146] = function(f)
    local d = readinteger4(f)
    usedprinter(f_right(d,d))
end

handler[147] = function()
    usedprinter(f_right_w())
end

handler[148] = function(f)
    local d = readinteger1(f)
    usedprinter(f_right_w_set(d,d))
end
handler[149] = function(f)
    local d = readinteger2(f)
    usedprinter(f_right_w_set(d,d))
end
handler[150] = function(f)
    local d = readinteger3(f)
    usedprinter(f_right_w_set(d,d))
end
handler[151] = function(f)
    local d = readinteger4(f)
    usedprinter(f_right_w_set(d,d))
end

handler[152] = function()
    handlers.right_x()
end

handler[153] = function(f)
    local d = readinteger1(f)
    usedprinter(f_right_x_set(d,d))
end
handler[154] = function(f)
    local d = readinteger2(f)
    usedprinter(f_right_x_set(d,d))
end
handler[155] = function(f)
    local d = readinteger3(f)
    usedprinter(f_right_x_set(d,d))
end
handler[156] = function(f)
    local d = readinteger4(f)
    usedprinter(f_right_x_set(d,d))
end

handler[157] = function(f)
    local d = readinteger1(f)
    usedprinter(f_down(d,d))
end

handler[158] = function(f)
    local d = readinteger2(f)
    usedprinter(f_down(d,d))
end
handler[159] = function(f)
    local d = readinteger3(f)
    usedprinter(f_down(d,d))
end
handler[160] = function(f)
    local d = readinteger4(f)
    usedprinter(f_down(d,d))
end
handler[161] = function()
    usedprinter(f_down_y())
end

handler[162] = function(f)
    local d = readinteger1(f)
    usedprinter(f_down_y_set(d,d))
end
handler[163] = function(f)
    local d = readinteger2(f)
    usedprinter(f_down_y_set(d,d))
end
handler[164] = function(f)
    local d = readinteger3(f)
    usedprinter(f_down_y_set(d,d))
end
handler[165] = function(f)
    local d = readinteger4(f)
    usedprinter(f_down_y_set(d,d))
end

handler[166] = function()
    handlers.down_z()
end

handler[167] = function(f)
    local d = readinteger1(f)
    usedprinter(f_down_z_set(d,d))
end
handler[168] = function(f)
    local d = readinteger2(f)
    usedprinter(f_down_z_set(d,d))
end
handler[169] = function(f)
    local d = readinteger3(f)
    usedprinter(f_down_z_set(d,d))
end
handler[170] = function(f)
    local d = readinteger4(f)
    usedprinter(f_down_z_set(d,d))
end

handler[171] = function(f,b)
    usedprinter(f_set_font_fast(b))
end

handler[235] = function(f)
    usedprinter(f_set_font(readcardinal1(f)))
end
handler[236] = function(f)
    usedprinter(f_set_font(readcardinal2(f)))
end
handler[237] = function(f)
    usedprinter(f_set_font(readcardinal3(f)))
end
handler[238] = function(f)
    usedprinter(f_set_font(readcardinal4(f)))
end

handler[239] = function(f)
    usedprinter(f_special(readstring(readcardinal1(f))))
end
handler[240] = function(f)
    usedprinter(f_special(readstring(readcardinal2(f))))
end
handler[241] = function(f)
    usedprinter(f_special(readstring(readcardinal3(f))))
end
handler[242] = function(f)
    usedprinter(f_special(readstring(readcardinal4(f))))
end

handler[243] = function(f)
    define_font(f,1)
end
handler[244] = function(f)
    define_font(f,2)
end
handler[245] = function(f)
    define_font(f,3)
end
handler[246] = function(f)
    define_font(f,4)
end

handler[247] = function(f)
    usedprinter(f_preamble(
        readcardinal1(f),
        readcardinal4(f),
        readcardinal4(f),
        readcardinal4(f),
        readstring(f,readcardinal1(f))
    ))
end

handler[248] = function(f)
    usedprinter(f_postamble_begin(
        readcardinal4(f), -- p
        readcardinal4(f), -- num
        readcardinal4(f), -- den
        readcardinal4(f), -- mag
        readcardinal4(f), -- l
        readcardinal4(f), -- u
        readcardinal2(f), -- s
        readcardinal2(f)  -- t
    ))
    while true do
        local b = readbyte(f)
        if b == 249 then
            break
        else
            handler[b](f,b)
        end
    end
    usedprinter(f_postamble_end(
        readcardinal4(f),
        readcardinal1(f)
    ))
    -- now 223's follow
end

handler[250] = function()
end

for i=   1,127 do handler[i] = handler[  0] end
for i= 172,234 do handler[i] = handler[171] end
for i= 251,255 do handler[i] = handler[250] end

scripts     = scripts     or { }
scripts.dvi = scripts.dvi or { }

function scripts.dvi.list(filename,printer)
    currentdepth = 0
    local f = io.open(filename)
    if f then
        local filesize = f:seek("end")
        local position = 0
        f:seek("set",position)
        local format = formatters["%0" .. #tostring(filesize) .. "i :  %s"]
        local flush  = printer or usedprinter
        usedprinter = function(str)
            flush(format(position,str))
            position = f:seek()
        end
        while true do
            local b = readbyte(f)
            if b == 223 then
                return
            else
                handler[b](f,b)
            end
        end
        f:close()
    else
        report("invalid filename %a",filename)
    end
end

local filename = environment.files[1] or ""

if filename == "" then
    application.help()
elseif environment.argument("list") then
    scripts.dvi.list(filename)
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),filename)
else
    application.help()
end
