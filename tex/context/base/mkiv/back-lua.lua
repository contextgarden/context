if not modules then modules = { } end modules ['back-lua'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we can remap fonts

local fontproperties    = fonts.hashes.properties
local fontparameters    = fonts.hashes.parameters
local fontshapes        = fonts.hashes.shapes

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

-- todo : per instance

local pages     = { }
local fonts     = { }
local names     = { }
local mapping   = { }
local used      = { }
local shapes    = { }
local glyphs    = { }
local buffer    = { }
local b         = 0
local converter = nil

local compact   = false -- true
local shapestoo = true

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
    -- todo: we're now still in the pdf backend but need different codeinjections
    local codeinjections = backends.pdf.codeinjections
    local getvariable    = codeinjections.getidentityvariable or function() end
    local jobname        = environment.jobname or tex.jobname or "unknown"
    return {
        metadata = {
            unit     = "bp",
            jobname  = jobname,
            title    = getvariable("title") or jobname,
            subject  = getvariable("subject"),
            author   = getvariable("author"),
            keywords = getvariable("keywords"),
            time     = os.date("%Y-%m-%d %H:%M"),
            engine   = environment.luatexengine .. " " .. environment.luatexversion,
            context  = environment.version,
        },
        fonts  = fonts,
        pages  = pages,
        shapes = shapes,
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
    local n = details.pagenumber
    local b = details.boundingbox
    pages[n] = {
        number      = n,
        content     = buffer,
        boundingbox = {
            b[1] * bpfactor,
            b[2] * bpfactor,
            b[3] * bpfactor,
            b[4] * bpfactor,
        },
    }
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
    if not mapping[id] then
        local fn = #fonts + 1
        mapping[id] = fn
        local properties = fontproperties[id]
        local parameters = fontparameters[id]
        local filename   = file.basename(properties.filename)
        local fontname   = properties.fullname or properties.fontname
        if shapestoo then
            if not names[fontname] then
                local sn = #shapes+1
                names[fontname] = sn
                shapes[sn] = { }
                glyphs[sn] = fontshapes[id].glyphs
            end
        end
        fonts[fn] = {
            filename = filename,
            name     = fontname,
            size     = parameters.size * bpfactor,
            shapes   = shapestoo and names[fontname] or nil,
        }
    end
end

local function flushcharacter(current, pos_h, pos_v, pos_r, font, char)
    local fnt = mapping[font]
    b = b + 1
    buffer[b] = {
        t = "glyph" ~= t and "glyph" or nil,
        f = font    ~= f and fnt or nil,
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
    if shapestoo then
        -- can be sped up if needed
        local sn = fonts[fnt].shapes
        local shp = shapes[sn]
        if not shp[char] then
            shp[char] = glyphs[sn][char]
        end
    end
end

local function rule(pos_h, pos_v, pos_r, size_h, size_v, rule_s, rule_o)
    b = b + 1
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
-- also color (via hash)

-- installer

drivers.install {
    name    = "lua",
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

-- actions

local function outputfilename(driver)
    return tex.jobname .. "-output.js"
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
        io.savedata(filename,
            "const JSON_CONTEXT = JSON.parse ( `" ..
            utilities.json.tostring(data,not compact) ..
            "` ) ;\n"
        )
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
    name    = "js",
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
