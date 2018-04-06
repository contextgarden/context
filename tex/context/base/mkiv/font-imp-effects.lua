if not modules then modules = { } end modules ['font-imp-effects'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type, tonumber = next, type, tonumber

local fonts              = fonts

local handlers           = fonts.handlers
local registerotffeature = handlers.otf.features.register
local registerafmfeature = handlers.afm.features.register

local settings_to_hash   = utilities.parsers.settings_to_hash

local helpers            = fonts.helpers
local prependcommands    = helpers.prependcommands
local charcommand        = helpers.commands.char
local rightcommand       = helpers.commands.right

local report_effect      = logs.reporter("fonts","effect")
local report_extend      = logs.reporter("fonts","extend")
local report_slant       = logs.reporter("fonts","slant")

local trace              = false

trackers.register("fonts.effect", function(v) trace = v end)
trackers.register("fonts.slant",  function(v) trace = v end)
trackers.register("fonts.extend", function(v) trace = v end)

local function initialize(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  1 then
        value =  1
    elseif value < -1 then
        value = -1
    end
    if trace then
        report_slant("applying %0.3f",value)
    end
    tfmdata.parameters.slantfactor = value
end

local specification = {
    name        = "slant",
    description = "slant glyphs",
    initializers = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

local function initialize(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  10 then
        value =  10
    elseif value < -10 then
        value = -10
    end
    if trace then
        report_slant("applying %0.3f",value)
    end
    tfmdata.parameters.extendfactor = value
end

local specification = {
    name        = "extend",
    description = "scale glyphs horizontally",
    initializers = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

local effects = {
    inner   = 0,
    normal  = 0,
    outer   = 1,
    outline = 1,
    both    = 2,
    hidden  = 3,
}

local function initializeeffect(tfmdata,value)
    local spec
    if type(value) == "number" then
        spec = { width = value }
    else
        spec = settings_to_hash(value)
    end
    local effect = spec.effect or "both"
    local width  = tonumber(spec.width) or 0
    local mode   = effects[effect]
    if not mode then
        report_effect("invalid effect %a",effect)
    elseif width == 0 and mode == 0 then
        report_effect("invalid width %a for effect %a",width,effect)
    else
        local parameters = tfmdata.parameters
        local properties = tfmdata.properties
        parameters.mode  = mode
        parameters.width = width * 1000
        local factor  = tonumber(spec.factor) or 0
        local hfactor = tonumber(spec.vfactor) or factor
        local vfactor = tonumber(spec.hfactor) or factor
        local delta   = tonumber(spec.delta) or 1
        local wdelta  = tonumber(spec.wdelta) or delta
        local hdelta  = tonumber(spec.hdelta) or delta
        local ddelta  = tonumber(spec.ddelta) or hdelta
        properties.effect = {
            effect  = effect,
            width   = width,
            factor  = factor,
            hfactor = hfactor,
            vfactor = vfactor,
            wdelta  = wdelta,
            hdelta  = hdelta,
            ddelta  = ddelta,
        }
    end
end

local function manipulateeffect(tfmdata)
    local effect = tfmdata.properties.effect
    if effect then
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        local multiplier = effect.width * 100
        local wdelta = effect.wdelta * parameters.hfactor * multiplier
        local hdelta = effect.hdelta * parameters.vfactor * multiplier
        local ddelta = effect.ddelta * parameters.vfactor * multiplier
        local hshift = wdelta / 2
        local factor  = (1 + effect.factor)  * parameters.factor
        local hfactor = (1 + effect.hfactor) * parameters.hfactor
        local vfactor = (1 + effect.vfactor) * parameters.vfactor
        for unicode, character in next, characters do
            local oldwidth  = character.width
            local oldheight = character.height
            local olddepth  = character.depth
            if oldwidth and oldwidth > 0 then
                character.width = oldwidth + wdelta
                local commands = character.commands
                local hshift   = rightcommand[hshift]
                if commands then
                    prependcommands ( commands,
                        hshift
                    )
                else
                    character.commands = {
                        hshift,
                        charcommand[unicode],
                    }
                end
            end
            if oldheight and oldheight > 0 then
                character.height = oldheight + hdelta
            end
            if olddepth and olddepth > 0 then
                character.depth = olddepth + ddelta
            end
        end
        parameters.factor  = factor
        parameters.hfactor = hfactor
        parameters.vfactor = vfactor
        if trace then
            report_effect("applying")
            report_effect("  effect  : %s", effect.effect)
            report_effect("  width   : %s => %s", effect.width,  multiplier)
            report_effect("  factor  : %s => %s", effect.factor, factor )
            report_effect("  hfactor : %s => %s", effect.hfactor,hfactor)
            report_effect("  vfactor : %s => %s", effect.vfactor,vfactor)
            report_effect("  wdelta  : %s => %s", effect.wdelta, wdelta)
            report_effect("  hdelta  : %s => %s", effect.hdelta, hdelta)
            report_effect("  ddelta  : %s => %s", effect.ddelta, ddelta)
        end
    end
end

local specification = {
    name        = "effect",
    description = "apply effects to glyphs",
    initializers = {
        base = initializeeffect,
        node = initializeeffect,
    },
    manipulators = {
        base = manipulateeffect,
        node = manipulateeffect,
    },
}

registerotffeature(specification)
registerafmfeature(specification)

local function initializeoutline(tfmdata,value)
    value = tonumber(value)
    if not value then
        value = 0
    else
        value = tonumber(value) or 0
    end
    local parameters = tfmdata.parameters
    local properties = tfmdata.properties
    parameters.mode  = effects.outline
    parameters.width = value * 1000
    properties.effect = {
        effect = effect,
        width  = width,
    }
end

local specification = {
    name        = "outline",
    description = "outline glyphs",
    initializers = {
        base = initializeoutline,
        node = initializeoutline,
    }
}

registerotffeature(specification)
registerafmfeature(specification)
