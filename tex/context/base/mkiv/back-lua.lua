if not modules then modules = { } end modules ['back-lua'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fontproperties = fonts.hashes.properties
local fontparameters = fonts.hashes.parameters

local bpfactor       = number.dimenfactors.bp

local buffer = { }
local b      = 0
local fonts  = { }

local function reset()
    fonts  = { }
    buffer = { }
    b      = 0
end

local function cleanup()
--     print("cleanup lua")
    reset()
end

local function prepare()
--     print("prepare lua")
    reset()
end

local function initialize(specification)
--     print("initialize lua")
--     reset()
end

local function finalize()
--     print("finalize lua")
end

local function wrapup()
--     print("wrapup lua")
end

local function convert(boxnumber)
--     print("convert lua")
    lpdf.convert(tex.box[boxnumber],"page")
    local page = {
        metadata = {
            page = tex.getcount("realpageno"),
            unit = "bp",
        },
        fonts    = fonts,
        stream   = buffer,
    }
    reset()
    if not utilities.json then
        require("util-jsn")
        io.savedata(tex.jobname .. ".json",utilities.json.tojson(page))
    end
--     inspect(page)
    return page
end

local function outputfilename()
    return "temp.lua"
end

local function updatefontstate(id)
    if not fonts[id] then
        fonts[id] = {
            filename = fontproperties[id].filename,
            size     = fontparameters[id].size * bpfactor,
        }
    end
end

local function flushcharacter(current, pos_h, pos_v, pos_r, font, char)
    b = b + 1 ; buffer[b] = {
        "glyph",
        font,
        char,
        pos_h * bpfactor,
        pos_v * bpfactor,
        pos_r
    }
end

local function flushrule(current, pos_h, pos_v, pos_r, size_h, size_v)
    b = b + 1 ; buffer[b] = {
        "rule",
        size_h,
        size_v,
        pos_h * bpfactor,
        pos_v * bpfactor,
        pos_r
    }
end

-- file stuff too
-- todo: default flushers

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
