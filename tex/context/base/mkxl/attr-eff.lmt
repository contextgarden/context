if not modules then modules = { } end modules ['attr-eff'] = {
    version   = 1.001,
    comment   = "companion to attr-eff.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local attributes, nodes, backends, utilities = attributes, nodes, backends, utilities
local tex = tex

local states            = attributes.states
local enableaction      = nodes.tasks.enableaction
local nodeinjections    = backends.nodeinjections
local texsetattribute   = tex.setattribute
local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters

local interfaces        = interfaces
local implement         = interfaces.implement

local variables         = interfaces.variables
local v_normal          = variables.normal

attributes.effects      = attributes.effects or { }
local effects           = attributes.effects

local a_effect          = attributes.private('effect')

effects.data            = allocate()
effects.values          = effects.values     or { }
effects.registered      = effects.registered or { }
effects.attribute       = a_effect

local data              = effects.data
local registered        = effects.registered
local values            = effects.values

local f_stamp           = formatters["%s:%s:%s"]

storage.register("attributes/effects/registered", registered, "attributes.effects.registered")
storage.register("attributes/effects/values",     values,     "attributes.effects.values")

-- valid effects: normal inner outer both hidden (stretch,rulethickness,effect)

local function effect(...) effect = nodeinjections.effect return effect(...) end

local function extender(effects,key)
    if key == "none" then
        local d = effect(0,0,0)
        effects.none = d
        return d
    end
end

local function reviver(data,n)
    local e = values[n] -- we could nil values[n] now but hardly needed
    local d = effect(e[1],e[2],e[3])
    data[n] = d
    return d
end

setmetatableindex(effects,      extender)
setmetatableindex(effects.data, reviver)

effects.handler = nodes.installattributehandler {
    name        = "effect",
    namespace   = effects,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

local function register(specification)
    local alternative, stretch, rulethickness
    if specification then
        alternative   = specification.alternative or v_normal
        stretch       = specification.stretch or 0
        rulethickness = specification.rulethickness or 0
    else
        alternative   = v_normal
        stretch       = 0
        rulethickness = 0
    end
    local stamp = f_stamp(alternative,stretch,rulethickness)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = { alternative, stretch, rulethickness }
        registered[stamp] = n
    end
    return n
end

local enabled = false

local function enable()
    if not enabled then
        enableaction("shipouts","attributes.effects.handler")
        enabled = true
    end
end

effects.register = register
effects.enable   = enable

-- interface

implement {
    name      = "seteffect",
    actions   = function(specification)
        if not enabled then
            enable()
        end
        texsetattribute(a_effect,register(specification))
    end,
    arguments = {
        {
            { "alternative",   "string"  },
            { "stretch",       "integer" },
            { "rulethickness", "dimen"   }
        }
    }
}

implement {
    name      = "reseteffect",
    actions   = function()
        if enabled then
            texsetattribute(a_effect,register())
        end
    end
}
