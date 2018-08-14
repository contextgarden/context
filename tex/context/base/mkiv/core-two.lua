if not modules then modules = { } end modules ['core-two'] = {
    version   = 1.001,
    comment   = "companion to core-two.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local remove, concat = table.remove, table.concat
local allocate = utilities.storage.allocate

--[[ldx--
<p>We save multi-pass information in the main utility table. This is a
bit of a mess because we support old and new methods.</p>
--ldx]]--

local collected = allocate()
local tobesaved = allocate()

local jobpasses = {
    collected = collected,
    tobesaved = tobesaved,
}

job.passes = jobpasses

local function initializer()
    collected = jobpasses.collected
    tobesaved = jobpasses.tobesaved
end

job.register('job.passes.collected', tobesaved, initializer, nil)

local function define(id)
    local p = tobesaved[id]
    if not p then
        p = { }
        tobesaved[id] = p
    end
    return p
end

local function save(id,str,index)
    local jti = define(id)
    if index then
        jti[index] = str
    else
        jti[#jti+1] = str
    end
end

local function savetagged(id,tag,str)
    local jti = define(id)
    jti[tag] = str
end

local function getdata(id,index,default)
    local jti = collected[id]
    local value = jti and jti[index]
    return value ~= "" and value or default or ""
end

local function getfield(id,index,tag,default)
    local jti = collected[id]
    jti = jti and jti[index]
    local value = jti and jti[tag]
    return value ~= "" and value or default or ""
end

local function getcollected(id)
    return collected[id] or { }
end

local function gettobesaved(id)
    return define(id)
end

local function get(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        return remove(jti,1)
    end
end

local function first(id)
    local jti = collected[id]
    return jti and jti[1]
end

local function last(id)
    local jti = collected[id]
    return jti and jti[#jti]
end

local function find(id,n)
    local jti = collected[id]
    return jti and jti[n] or nil
end

local function count(id)
    local jti = collected[id]
    return jti and #jti or 0
end

local function list(id)
    local jti = collected[id]
    if jti then
        return concat(jti,',')
    end
end

local function inlist(id,str)
    local jti = collected[id]
    if jti then
        for _, v in next, jti do
            if v == str then
                return true
            end
        end
    end
    return false
end

local check = first

jobpasses.define       = define
jobpasses.save         = save
jobpasses.savetagged   = savetagged
jobpasses.getdata      = getdata
jobpasses.getfield     = getfield
jobpasses.getcollected = getcollected
jobpasses.gettobesaved = gettobesaved
jobpasses.get          = get
jobpasses.first        = first
jobpasses.last         = last
jobpasses.find         = find
jobpasses.list         = list
jobpasses.count        = count
jobpasses.check        = check
jobpasses.inlist       = inlist

-- interface

local implement = interfaces.implement

implement { name = "gettwopassdata",     actions = { get,   context }, arguments = "string" }
implement { name = "getfirsttwopassdata",actions = { first, context }, arguments = "string" }
implement { name = "getlasttwopassdata", actions = { last,  context }, arguments = "string" }
implement { name = "findtwopassdata",    actions = { find,  context }, arguments = "2 strings" }
implement { name = "gettwopassdatalist", actions = { list,  context }, arguments = "string" }
implement { name = "counttwopassdata",   actions = { count, context }, arguments = "string" }
implement { name = "checktwopassdata",   actions = { check, context }, arguments = "string" }

implement {
    name      = "definetwopasslist",
    actions   = define,
    arguments = "string"
}

implement {
    name      = "savetwopassdata",
    actions   = save,
    arguments = "2 strings",
}

implement {
    name      = "savetaggedtwopassdata",
    actions   = savetagged,
    arguments = "3 strings",
}

implement {
    name      = "doifelseintwopassdata",
    actions   = { inlist, commands.doifelse },
    arguments = "2 strings",
}

-- local ctx_latelua = context.latelua

-- implement {
--     name      = "lazysavetwopassdata",
--     arguments = "3 strings",
--     public    = true,
--     actions   = function(a,b,c)
--         ctx_latelua(function() save(a,c) end)
--     end,
-- }

-- implement {
--     name      = "lazysavetaggedtwopassdata",
--     arguments = "3 strings",
--     public    = true,
--     actions   = function(a,b,c)
--         ctx_latelua(function() savetagged(a,b,c) end)
--     end,
-- }
