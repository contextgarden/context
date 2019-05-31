if not modules then modules = { } end modules ['font-imp-dimensions'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, type, tonumber = next, type, tonumber

local fonts              = fonts
local utilities          = utilities

local helpers            = fonts.helpers
local prependcommands    = helpers.prependcommands
local charcommand        = helpers.commands.char
local rightcommand       = helpers.commands.right

local handlers           = fonts.handlers
local otf                = handlers.otf
local afm                = handlers.afm

local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register

local settings_to_array  = utilities.parsers.settings_to_array
local gettexdimen        = tex.getdimen

-- For Wolfgang Schuster:
--
-- \definefontfeature[thisway][default][script=hang,language=zhs,dimensions={2,2,2}]
-- \definedfont[file:kozminpr6nregular*thisway]

local function initialize(tfmdata,key,value)
    if type(value) == "string" and value ~= "" then
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        local emwidth    = parameters.quad
        local exheight   = parameters.xheight
        local newwidth   = false
        local newheight  = false
        local newdepth   = false
        if value == "strut" then
            newheight = gettexdimen("strutht")
            newdepth  = gettexdimen("strutdp")
        elseif value == "mono" then
            newwidth  = emwidth
        else
            local spec = settings_to_array(value)
            newwidth  = tonumber(spec[1])
            newheight = tonumber(spec[2])
            newdepth  = tonumber(spec[3])
            if newwidth  then newwidth  = newwidth  * emwidth  end
            if newheight then newheight = newheight * exheight end
            if newdepth  then newdepth  = newdepth  * exheight end
        end
        if newwidth or newheight or newdepth then
            for unicode, character in next, characters do
                local oldwidth  = character.width
                local oldheight = character.height
                local olddepth  = character.depth
                local width  = newwidth  or oldwidth  or 0
                local height = newheight or oldheight or 0
                local depth  = newdepth  or olddepth  or 0
                if oldwidth ~= width or oldheight ~= height or olddepth ~= depth then
                    character.width  = width
                    character.height = height
                    character.depth  = depth
                    if oldwidth ~= width then
                        local commands = character.commands
                        local hshift   = rightcommand[(width - oldwidth) / 2]
                        if commands then
                            character.commands = prependcommands (
                                commands,
                                hshift
                            )
                        else
                            character.commands = {
                                hshift,
                                charcommand[unicode],
                            }
                        end
                    end
                end
            end
        end
    end
end

local specification = {
    name        = "dimensions",
    description = "force dimensions",
    manipulators = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

local function initialize(tfmdata,value)
    tfmdata.properties.realdimensions = value and true
end

registerotffeature {
    name        = "realdimensions",
    description = "accept negative dimensions",
    initializers = {
        base = initialize,
        node = initialize,
    }
}
