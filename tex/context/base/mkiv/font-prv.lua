if not modules then modules = { } end modules ['font-prv'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, rawget = type, rawget
local formatters = string.formatters

local fonts             = fonts
local helpers           = fonts.helpers
local fontdata          = fonts.hashes.identifiers

local setmetatableindex = table.setmetatableindex

local currentprivate    = fonts.privateoffsets.textextrabase
local maximumprivate    = currentprivate + 0xFFF

local extraprivates     = { }
helpers.extraprivates   = extraprivates

function fonts.helpers.addextraprivate(name,f)
    extraprivates[#extraprivates+1] = { name, f }
end

-- if we run out of space we can think of another range but by sharing we can
-- use these privates for mechanisms like alignments-on-character and such

local sharedprivates = setmetatableindex(function(t,k)
    local v = currentprivate
    if currentprivate < maximumprivate then
        currentprivate = currentprivate + 1
    else
        -- reuse last slot, todo: warning
    end
    t[k] = v
    return v
end)

function helpers.addprivate(tfmdata,name,characterdata)
    local properties = tfmdata.properties
    local characters = tfmdata.characters
    local privates   = properties.privates
    if not privates then
        privates = { }
        properties.privates = privates
    end
    if not name then
        name = formatters["anonymous_private_0x%05X"](currentprivate)
    end
    local usedprivate = sharedprivates[name]
    privates[name] = usedprivate
    characters[usedprivate] = characterdata
    return usedprivate
end

function helpers.getprivates(tfmdata)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    local properties = tfmdata.properties
    return properties and properties.privates
end

function helpers.hasprivate(tfmdata,name)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    local properties = tfmdata.properties
    local privates = properties and properties.privates
    return privates and privates[name] or false
end

function helpers.privateslot(name)
    return rawget(sharedprivates,name)
end

function helpers.newprivateslot(name)
    return sharedprivates[name]
end
