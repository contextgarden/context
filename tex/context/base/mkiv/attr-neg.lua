if not modules then modules = { } end modules ['attr-neg'] = {
    version   = 1.001,
    comment   = "companion to attr-neg.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is being reconstructed and code will move to other places
-- we can also do the nsnone via a metatable and then also se index 0

local format = string.format

local attributes, nodes, utilities, logs, backends = attributes, nodes, utilities, logs, backends
local commands, context, interfaces = commands, context, interfaces
local tex = tex

local states            = attributes.states
local enableaction      = nodes.tasks.enableaction
local nodeinjections    = backends.nodeinjections
local texsetattribute   = tex.setattribute
local variables         = interfaces.variables
local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

--- negative / positive

attributes.negatives    = attributes.negatives or { }
local negatives         = attributes.negatives

local a_negative        = attributes.private("negative")

local v_none            = interfaces.variables.none

negatives.data          = allocate()
negatives.attribute     = a_negative

negatives.registered = allocate {
    [variables.positive] = 1,
    [variables.negative] = 2,
}

local data       = negatives.data
local registered = negatives.registered

local function extender(negatives,key)
    if key == "none" then -- v_none then
        local d = data[1]
        negatives.none = d
        return d
    end
end

local function reviver(data,n)
    if n == 1 then
        local d = nodeinjections.positive() -- called once
        data[1] = d
        return d
    elseif n == 2 then
        local d = nodeinjections.negative() -- called once
        data[2] = d
        return d
    end
end

setmetatableindex(negatives,      extender)
setmetatableindex(negatives.data, reviver)

negatives.handler = nodes.installattributehandler {
    name        = "negative",
    namespace   = negatives,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

local function register(stamp)
    return registered[stamp] or registered.positive
end

local function enable()
    enableaction("shipouts","attributes.negatives.handler")
end

negatives.register = register
negatives.enable   = enable

-- interface

local enabled = false

function negatives.set(stamp)
    if not enabled then
        enable()
        enabled = true
    end
    texsetattribute(a_negative,register(stamp))
end

interfaces.implement {
    name      = "setnegative",
    actions   = negatives.set,
    arguments = "string",
}
