if not modules then modules = { } end modules ['font-imp-properties'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, type, tonumber, select = next, type, tonumber, select
local byte, find, formatters = string.byte, string.find, string.formatters
local utfchar = utf.char
local sortedhash, sortedkeys, sort = table.sortedhash, table.sortedkeys, table.sort
local insert = table.insert

local context            = context
local fonts              = fonts
local utilities          = utilities

local helpers            = fonts.helpers

local handlers           = fonts.handlers
local hashes             = fonts.hashes
local otf                = handlers.otf
local afm                = handlers.afm

local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register

local fontdata           = hashes.identifiers
local fontproperties     = hashes.properties

local constructors       = fonts.constructors
local getprivate         = constructors.getprivate

local allocate           = utilities.storage.allocate

local setmetatableindex  = table.setmetatableindex

local implement          = interfaces.implement

do

    local P, lpegpatterns, lpegmatch  = lpeg.P, lpeg.patterns, lpeg.match

    local amount, stretch, shrink, extra

    local factor  = lpegpatterns.unsigned
    local space   = lpegpatterns.space
    local pattern = (
                                            (factor / function(n) amount  = tonumber(n) or amount  end)
        + (P("+") + P("plus" )) * space^0 * (factor / function(n) stretch = tonumber(n) or stretch end)
        + (P("-") + P("minus")) * space^0 * (factor / function(n) shrink  = tonumber(n) or shrink  end)
        + (         P("extra")) * space^0 * (factor / function(n) extra   = tonumber(n) or extra   end)
        + space^1
    )^1

    local function initialize(tfmdata,key,value)
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        if type(value) == "string" then
            local emwidth = parameters.quad
            amount, stretch, shrink, extra = 0, 0, 0, false
            lpegmatch(pattern,value)
            if not extra then
                if shrink ~= 0 then
                    extra = shrink
                elseif stretch ~= 0 then
                    extra = stretch
                else
                    extra = amount
                end
            end
            parameters.space         = amount  * emwidth
            parameters.space_stretch = stretch * emwidth
            parameters.space_shrink  = shrink  * emwidth
            parameters.extra_space   = extra   * emwidth
        end
    end

    -- 1.1 + 1.2 - 1.3 minus 1.4 plus 1.1 extra 1.4 -- last one wins

    registerotffeature {
        name        = "spacing",
        description = "space settings",
        manipulators = {
            base = initialize,
            node = initialize,
        }
    }

end

do

    local function initialize(tfmdata,value)
        local properties = tfmdata.properties
        if properties then
            properties.identity = value == "vertical" and "vertical" or "horizontal"
        end
    end

    registerotffeature {
        name         = "identity",
        description  = "set font identity",
        initializers = {
            base = initialize,
            node = initialize,
        }
    }

    local function initialize(tfmdata,value)
        local properties = tfmdata.properties
        if properties then
            properties.writingmode = value == "vertical" and "vertical" or "horizontal"
        end
    end

    registerotffeature {
        name         = "writingmode",
        description  = "set font direction",
        initializers = {
            base = initialize,
            node = initialize,
        }
    }

end
