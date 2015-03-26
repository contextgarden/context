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
local commands       = commands

local compilescanner = tokens.compile
local scanners       = interfaces.scanners

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

-- interface

commands.saveobject = saveobject
commands.setobject  = setobject

function commands.objectnumber(tag,default)
    context(getobjectnumber(tag,default))
end

function commands.objectpage(tag,default)
    context(getobjectpage  (tag,default))
end

function commands.doifobjectreferencefoundelse(tag)
    commands.doifelse(getobject(tag))
end

-- new

scanners.saveobject = saveobject

scanners.setobject = compilescanner {
    actions   = setobject,
    arguments = { "string", "integer", "integer" }
}

scanners.objectnumber = compilescanner {
    actions   = { getobjectnumber, context },
    arguments = { "string", "string" },
}

scanners.objectpage = compilescanner {
    actions   = { getobjectpage, context },
    arguments = { "string", "string" },
}

scanners.doifobjectreferencefoundelse = compilescanner {
    actions   = { jobobjects.get, commands.doifelse },
    arguments = "string"
}
