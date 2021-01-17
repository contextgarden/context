if not modules then modules = { } end modules ['font-imp-tracing'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, type = next, type
local concat = table.concat
local formatters = string.formatters

local fonts              = fonts

local handlers           = fonts.handlers
local registerotffeature = handlers.otf.features.register
local registerafmfeature = handlers.afm.features.register

local settings_to_array  = utilities.parsers.settings_to_array
local setmetatableindex  = table.setmetatableindex

local helpers            = fonts.helpers
local appendcommandtable = helpers.appendcommandtable
local prependcommands    = helpers.prependcommands
local charcommand        = helpers.commands.char

local variables          = interfaces.variables

local v_background       = variables.background
local v_frame            = variables.frame
local v_empty            = variables.empty
local v_none             = variables.none

-- for zhichu chen (see mailing list archive): we might add a few more variants
-- in due time
--
-- \definefontfeature[boxed][default][boundingbox=yes] % paleblue
--
-- maybe:
--
-- \definecolor[DummyColor][s=.75,t=.5,a=1] {\DummyColor test} \nopdfcompression
--
-- local gray  = { "pdf", "origin", "/Tr1 gs .75 g" }
-- local black = { "pdf", "origin", "/Tr0 gs 0 g" }

-- boundingbox={yes|background|frame|empty|<color>}

local backgrounds = nil
local outlines    = nil
local startcolor  = nil
local stopcolor   = nil

local function initialize(tfmdata,key,value)
    if value then
        if not backgrounds then
            local vfspecials = backends.pdf.tables.vfspecials
            startcolor  = vfspecials.startcolor
            stopcolor   = vfspecials.stopcolor
            backgrounds = vfspecials.backgrounds
            outlines    = vfspecials.outlines
        end
        local characters = tfmdata.characters
        local rulecache  = backgrounds
        local showchar   = true
        local color      = "palegray"
        if type(value) == "string" then
            value = settings_to_array(value)
            for i=1,#value do
                local v = value[i]
                if v == v_frame then
                    rulecache = outlines
                elseif v == v_background then
                    rulecache = backgrounds
                elseif v == v_empty then
                    showchar = false
                elseif v == v_none then
                    color = nil
                else
                    color = v
                end
            end
        end
        local gray  = color and startcolor(color) or nil
        local black = gray and stopcolor or nil
        for unicode, character in next, characters do
            local width  = character.width  or 0
            local height = character.height or 0
            local depth  = character.depth  or 0
            local rule   = rulecache[height][depth][width]
            if showchar then
                local commands = character.commands
                if commands then
                    if gray then
                        character.commands = prependcommands (
                            commands, gray, rule, black
                        )
                    else
                        character.commands = prependcommands (
                            commands, rule
                        )
                    end
                else
                    local char = charcommand[unicode]
                    if gray then
                        character.commands = {
                            gray, rule, black, char
                        }
                     else
                        character.commands = {
                            rule, char
                        }
                    end
                end
            else
                if gray then
                    character.commands = {
                        gray, rule, black
                    }
                else
                    character.commands = {
                        rule
                    }
                end
            end
        end
    end
end

local specification = {
    name        = "boundingbox",
    description = "show boundingbox",
    manipulators = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)
