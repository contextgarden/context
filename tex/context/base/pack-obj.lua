if not modules then modules = { } end modules ['pack-obj'] = {
    version   = 1.001,
    comment   = "companion to pack-obj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save object references in the main utility table. jobobjects are
reusable components.</p>
--ldx]]--

local context        = context

local implement      = interfaces.implement

local allocate       = utilities.storage.allocate

local collected      = allocate()
local tobesaved      = allocate()

local jobobjects     = {
    collected = collected,
    tobesaved = tobesaved,
}

job.objects          = jobobjects

local function initializer()
    collected = jobobjects.collected
    tobesaved = jobobjects.tobesaved
end

job.register('job.objects.collected', tobesaved, initializer, nil)

local function saveobject(tag,number,page)
    local t = { number, page }
    tobesaved[tag], collected[tag] = t, t
end

local function setobject(tag,number,page)
    collected[tag] = { number, page }
end

local function getobject(tag)
    return collected[tag] or tobesaved[tag]
end

local function getobjectnumber(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[1] or default
end

local function getobjectpage(tag,default)
    local o = collected[tag] or tobesaved[tag]
    return o and o[2] or default
end

jobobjects.save   = saveobject
jobobjects.set    = setobject
jobobjects.get    = getobject
jobobjects.number = getobjectnumber
jobobjects.page   = getobjectpage

implement {
    name      = "saveobject",
    actions   = saveobject
}

implement {
    name      = "setobject",
    actions   = setobject,
    arguments = { "string", "integer", "integer" }
}

implement {
    name      = "objectnumber",
    actions   = { getobjectnumber, context },
    arguments = { "string", "string" },
}

implement {
    name      = "objectpage",
    actions   = { getobjectpage, context },
    arguments = { "string", "string" },
}

implement {
    name      = "doifelseobjectreferencefound",
    actions   = { jobobjects.get, commands.doifelse },
    arguments = "string"
}
