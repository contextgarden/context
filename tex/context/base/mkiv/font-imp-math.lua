if not modules then modules = { } end modules ['font-imp-math'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, type, tonumber = next, type, tonumber

local fonts              = fonts
local helpers            = fonts.helpers
local registerotffeature = fonts.handlers.otf.features.register

local setmetatableindex  = table.setmetatableindex

-- requested for latex but not supported unless really needed in context:
--
-- registerotffeature {
--     name         = "ignoremathconstants",
--     description  = "ignore math constants table",
--     initializers = {
--         base = function(tfmdata,value)
--             if value then
--                 tfmdata.mathparameters = nil
--             end
--         end
--     }
-- }

-- tfmdata.properties.mathnolimitsmode = tonumber(value) or 0

local splitter  = lpeg.splitat(",",tonumber)
local lpegmatch = lpeg.match

local function initialize(tfmdata,value)
    local mathparameters = tfmdata.mathparameters
    if mathparameters then
        local sup, sub
        if type(value) == "string" then
            sup, sub = lpegmatch(splitter,value)
            if not sup then
                sub, sup = 0, 0
            elseif not sub then
                sub, sup = sup, 0
            end
        elseif type(value) == "number" then
            sup, sub = 0, value
        end
        if sup then
            mathparameters.NoLimitSupFactor = sup
        end
        if sub then
            mathparameters.NoLimitSubFactor = sub
        end
    end
end

registerotffeature {
    name         = "mathnolimitsmode",
    description  = "influence nolimits placement",
    initializers = {
        base = initialize,
        node = initialize,
    }
}

local function initialize(tfmdata,value)
    tfmdata.properties.nostackmath = value and true
end

registerotffeature {
    name        = "nostackmath",
    description = "disable math stacking mechanism",
    initializers = {
        base = initialize,
        node = initialize,
    }
}
