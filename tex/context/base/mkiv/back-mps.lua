if not modules then modules = { } end modules ['back-mps'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fontproperties    = fonts.hashes.properties
local fontparameters    = fonts.hashes.parameters

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local bpfactor          = number.dimenfactors.bp
local texgetbox         = tex.getbox
local formatters        = string.formatters

local rulecodes         = nodes.rulecodes
local normalrule_code   = rulecodes.normal
----- boxrule_code      = rulecodes.box
----- imagerule_code    = rulecodes.image
----- emptyrule_code    = rulecodes.empty
----- userrule_code     = rulecodes.user
----- overrule_code     = rulecodes.over
----- underrule_code    = rulecodes.under
----- fractionrule_code = rulecodes.fraction
----- radicalrule_code  = rulecodes.radical
local outlinerule_code  = rulecodes.outline

local fonts     = { }
local pages     = { }
local buffer    = { }
local b         = 0
local converter = nil

local function reset()
    buffer = { }
    b      = 0
end

local f_font    = formatters[ "\\definefont[%s][file:%s*none @ %sbp]\n" ]

local f_glyph   = formatters[ [[draw textext.drt("\%s\char%i\relax") shifted (%N,%N);]] ]
local f_rule    = formatters[ [[fill unitsquare xscaled %N yscaled %N shifted (%N,%N);]] ]
local f_outline = formatters[ [[draw unitsquare xscaled %N yscaled %N shifted (%N,%N);]] ]

-- actions

local function outputfilename(driver)
    return tex.jobname .. "-output.tex"
end

local function save() -- might become a driver function that already is plugged into stopactions
    starttiming(drivers)
    if #pages > 0 then
        local filename = outputfilename()
        drivers.report("saving result in %a",filename)
        reset()
        b = b + 1
        buffer[b] = "\\starttext\n"
        for k, v in table.sortedhash(fonts) do
            b = b + 1
            buffer[b] = f_font(v.name,v.filename,v.size)
        end
        for i=1,#pages do
            b = b + 1
            buffer[b] = pages[i]
        end
        b = b + 1
        buffer[b] = "\\stoptext\n"
        io.savedata(filename,table.concat(buffer,"",1,b))
    end
    stoptiming(drivers)
end

local function prepare(driver)
    converter = drivers.converters.lmtx
    luatex.registerstopactions(1,function()
        save()
    end)
end

local function initialize(driver,details)
    reset()
    b = b + 1
    buffer[b] = "\n\\startMPpage"
end

local function finalize(driver,details)
    b = b + 1
    buffer[b] = "\\stopMPpage\n"
    pages[details.pagenumber] = table.concat(buffer,"\n",1,b)
end

local function wrapup(driver)
end

local function cleanup(driver)
    reset()
end

local function convert(driver,boxnumber,pagenumber)
    converter(driver,texgetbox(boxnumber),"page",pagenumber)
end

-- flushers

local last

local function updatefontstate(id)
    if fonts[id] then
        last = fonts[id].name
    else
        last = "MPSfont" .. converters.Characters(id)
        fonts[id] = {
            filename = file.basename(fontproperties[id].filename),
            size     = fontparameters[id].size * bpfactor,
            name     = last,
        }
    end
end

local function flushcharacter(current, pos_h, pos_v, pod_r, font, char)
    b = b + 1
    buffer[b] = f_glyph(last,char,pos_h*bpfactor,pos_v*bpfactor)
end

local function flushrule(current, pos_h, pos_v, pod_r, size_h, size_v, subtype)
    if subtype == normalrule_code then
        b = b + 1
        buffer[b] = f_rule(size_h*bpfactor,size_v*bpfactor,pos_h*bpfactor,pos_v*bpfactor)
    elseif subtype == outlinerule_code then
        b = b + 1
        buffer[b] = f_outline(size_h*bpfactor,size_v*bpfactor,pos_h*bpfactor,pos_v*bpfactor)
    end
end

local function flushsimplerule(current, pos_h, pos_v, pod_r, size_h, size_v)
    b = b + 1
    buffer[b] = f_rule(size_h*bpfactor,size_v*bpfactor,pos_h*bpfactor,pos_v*bpfactor)
end

-- installer

drivers.install {
    name    = "mps",
    actions = {
        prepare         = prepare,
        initialize      = initialize,
        finalize        = finalize,
        wrapup          = wrapup,
        cleanup         = cleanup,
        convert         = convert,
        outputfilename  = outputfilename,
    },
    flushers = {
        updatefontstate = updatefontstate,
        character       = flushcharacter,
        rule            = flushrule,
        simplerule      = flushsimplerule,
    }
}

-- extras

-- if not mp then
--     return
-- end
--
-- local mpprint    = mp.print
-- local formatters = string.formatters
--
-- local f_glyph = formatters[ [[draw textext.drt("\setfontid%i\relax\char%i\relax") shifted (%N,%N);]] ]
-- local f_rule  = formatters[ [[fill unitsquare xscaled %N yscaled %N shifted (%N,%N);]] ]
--
-- local current = nil
-- local size    = 0
--
-- function mp.place_buffermake(box)
--     drivers.convert("mps",box)
--     current = drivers.action("mps","fetch")
--     size    = #current
-- end
--
-- function mp.place_buffersize()
--     mpprint(size)
-- end
--
-- function mp.place_bufferslot(i)
--     if i > 0 and i <= size then
--         local b = buffer[i]
--         local t = b[1]
--         if t == "glyph" then
--             mpprint(f_glyph(b[2],b[3],b[4]*bpfactor,b[5]*bpfactor))
--         elseif t == "rule" then
--             mpprint(f_rule(b[2]*bpfactor,b[3]*bpfactor,b[4]*bpfactor,b[5]*bpfactor))
--         end
--     end
-- end
--
-- function mp.place_bufferwipe()
--     current = nil
--     size    = 0
-- end
