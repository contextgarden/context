if not modules then modules = { } end modules ['back-lua'] = {
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

local pages     = { }
local fonts     = { }
local buffer    = { }
local b         = 0
local converter = nil

local sparse    = true
local compact   = false -- true

local x, y, d, f, c, w, h, t, r, o

local function reset()
    buffer = { }
    b      = 0
    t      = nil
    x      = nil
    y      = nil
    d      = nil
    f      = nil
    c      = nil
    w      = nil
    h      = nil
    r      = nil
    o      = nil
end

local function result()
    return {
        metadata = {
            page = pagenumber,
            unit = "bp",
        },
        fonts = fonts,
        pages = pages,
    }
end

-- actions

local function outputfilename(driver)
    return tex.jobname .. "-output.lua"
end

local function save() -- might become a driver function that already is plugged into stopactions
    local filename = outputfilename()
    drivers.report("saving result in %a",filename)
    starttiming(drivers)
    local data = result()
    if data then
        io.savedata(filename,table.serialize(data))
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
end

local function finalize(driver,details)
    pages[details.pagenumber] = buffer
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

local function updatefontstate(id)
    if not fonts[id] then
        for i=1,id-1 do
            if not fonts[i] then
                fonts[i] = false -- so we're not sparse and have numbers as index (in json)
            end
        end
        local properties = fontproperties[id]
        local parameters = fontparameters[id]
        fonts[id] = {
            filename = file.basename(properties.filename),
            name     = properties.fullname or properties.fontname,
            size     = parameters.size * bpfactor,
        }
    end
end

local function flushcharacter(current, pos_h, pos_v, pos_r, font, char)
    b = b + 1
    if sparse then
        buffer[b] = {
            t = "glyph" ~= t and "glyph" or nil,
            f = font    ~= f and font or nil,
            c = char    ~= c and char or nil,
            x = pos_h   ~= x and (pos_h * bpfactor) or nil,
            y = pos_v   ~= y and (pos_v * bpfactor) or nil,
            d = pos_r   ~= d and (pos_r == 1 and "r2l" or "l2r") or nil,
        }
        t = "glyph"
        f = font
        c = char
        x = pos_h
        y = pos_v
        d = pos_r
    else
        buffer[b] = {
            "glyph",
            font,
            char,
            pos_h * bpfactor,
            pos_v * bpfactor,
            pos_r
        }
    end
end

local function rule(pos_h, pos_v, pos_r, size_h, size_v, rule_s, rule_o)
    b = b + 1
    if sparse then
        buffer[b] = {
            t = "rule" ~= t and "rule" or nil,
            r = rule_s ~= r and rule_s or nil,
            o = rule_s == "outline" and rule_o ~= o and (rule_o * bpfactor) or nil,
            w = size_h ~= w and (size_h * bpfactor) or nil,
            h = size_v ~= h and (size_v * bpfactor) or nil,
            x = pos_h  ~= x and (pos_h  * bpfactor) or nil,
            y = pos_v  ~= y and (pos_v  * bpfactor) or nil,
            d = pos_r  ~= d and (pos_r == 1 and "r2l" or "l2r") or nil,
        }
        t = "rule"
        w = size_h
        h = size_v
        x = pos_h
        y = pos_v
        d = pos_r
    else
        buffer[b] = {
            "rule",
            size_h,
            size_v,
            pos_h * bpfactor,
            pos_v * bpfactor,
            pos_r,
            rule_s,
            rule_s = "outline" and rule_o
        }
    end
end

local function flushrule(current, pos_h, pos_v, pos_r, size_h, size_v, subtype)
    local rule_s, rule_o
    if subtype == normalrule_code then
        rule_s = "normal"
    elseif subtype == outlinerule_code then
        rule_s = "outline"
        rule_o = getdata(current)
    else
        return
    end
    return rule(pos_h, pos_v, pos_r, size_h, size_v, rule_s, rule_o)
end

local function flushsimplerule(current, pos_h, pos_v, pos_r, size_h, size_v)
    return rule(pos_h, pos_v, pos_r, size_h, size_v, "normal", nil)
end

-- file stuff too
-- todo: default flushers
-- json also here
-- sparse, only deltas
-- also color (via hash)

-- installer

drivers.install {
    name    = "lua",
    actions = {
        prepare         = prepare,
        initialize      = initialize,
        finalize        = finalize,
        updatefontstate = updatefontstate,
        wrapup          = wrapup,
        cleanup         = cleanup,
        convert         = convert,
        outputfilename  = outputfilename,
    },
    flushers = {
        character = flushcharacter,
        rule      = flushrule,
    }
}

-- actions

local function outputfilename(driver)
    return tex.jobname .. "-output.json"
end

local function save() -- might become a driver function that already is plugged into stopactions
    local filename = outputfilename()
    drivers.report("saving result in %a",filename)
    starttiming(drivers)
    local data = result()
    if data then
        if not utilities.json then
            require("util-jsn")
        end
        io.savedata(filename,utilities.json.tostring(data,not compact))
    end
    stoptiming(drivers)
end

local function prepare(driver)
    converter = drivers.converters.lmtx
    luatex.registerstopactions(1,function()
        save()
    end)
end

-- installer

drivers.install {
    name    = "json",
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
    }
}
