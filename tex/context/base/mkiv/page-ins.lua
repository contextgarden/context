if not modules then modules = { } end modules ['page-ins'] = {
    version   = 1.001,
    comment   = "companion to page-mix.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local next = next

structures           = structures or { }
structures.inserts   = structures.inserts or { }
local inserts        = structures.inserts

local allocate       = utilities.storage.allocate

inserts.stored       = inserts.stored or allocate { } -- combining them in one is inefficient in the
inserts.data         = inserts.data   or allocate { } -- bytecode storage pool

local variables      = interfaces.variables
local v_page         = variables.page

local context        = context
local implement      = interfaces.implement

storage.register("structures/inserts/stored", inserts.stored, "structures.inserts.stored")

local data           = inserts.data
local stored         = inserts.stored

for name, specification in next, stored do
    data[specification.number] = specification
    data[name]                 = specification
end

function inserts.define(name,specification)
    specification.name= name
    local number = specification.number or 0
    data[name]   = specification
    data[number] = specification
    -- only needed at runtime as this get stored in a bytecode register
    stored[name] = specification
    if not specification.location then
        specification.location = v_page
    end
    return specification
end

function inserts.setup(name,settings)
    local specification = data[name]
    for k, v in next, settings do
        -- maybe trace change
        specification[k] = v
    end
    return specification
end

function inserts.setlocation(name,location) -- a practical fast one
    data[name].location = location
end

function inserts.getlocation(name,location)
    return data[name].location or v_page
end

function inserts.getdata(name) -- or number
    return data[name]
end

function inserts.getname(number)
    return data[name].name
end

function inserts.getnumber(name)
    return data[name].number
end

-- interface

implement {
    name      = "defineinsertion",
    actions   = inserts.define,
    arguments = {
        "string",
        {
            { "number", "integer" }
        }
    }
}

implement {
    name      = "setupinsertion",
    actions   = inserts.setup,
    arguments = {
        "string",
        {
            { "location" }
        }
    }
}

implement {
    name      = "setinsertionlocation",
    actions   = inserts.setlocation,
    arguments = "2 strings",
}

implement {
    name      = "insertionnumber",
    actions   = function(name) context(data[name].number or 0) end,
    arguments = "string"
}

