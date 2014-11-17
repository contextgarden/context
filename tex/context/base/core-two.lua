if not modules then modules = { } end modules ['core-two'] = {
    version   = 1.001,
    comment   = "companion to core-two.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

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

local function allocate(id)
    local p = tobesaved[id]
    if not p then
        p = { }
        tobesaved[id] = p
    end
    return p
end

jobpasses.define = allocate

function jobpasses.save(id,str,index)
    local jti = allocate(id)
    if index then
        jti[index] = str
    else
        jti[#jti+1] = str
    end
end

function jobpasses.savetagged(id,tag,str)
    local jti = allocate(id)
    jti[tag] = str
end

function jobpasses.getdata(id,index,default)
    local jti = collected[id]
    local value = jti and jti[index]
    return value ~= "" and value or default or ""
end

function jobpasses.getfield(id,index,tag,default)
    local jti = collected[id]
    jti = jti and jti[index]
    local value = jti and jti[tag]
    return value ~= "" and value or default or ""
end

function jobpasses.getcollected(id)
    return collected[id] or { }
end

function jobpasses.gettobesaved(id)
    return allocate(id)
end

local function get(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        return remove(jti,1)
    end
end

local function first(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        return jti[1]
    end
end

local function last(id)
    local jti = collected[id]
    if jti and #jti > 0 then
        return jti[#jti]
    end
end

local function find(id,n)
    local jti = collected[id]
    if jti and jti[n] then
        return jti[n]
    end
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

--

jobpasses.get    = get
jobpasses.first  = first
jobpasses.last   = last
jobpasses.find   = find
jobpasses.list   = list
jobpasses.count  = count
jobpasses.check  = check
jobpasses.inlist = inlist

-- interface

function commands.gettwopassdata     (id)   local r = get  (id)   if r then context(r) end end
function commands.getfirsttwopassdata(id)   local r = first(id)   if r then context(r) end end
function commands.getlasttwopassdata (id)   local r = last (id)   if r then context(r) end end
function commands.findtwopassdata    (id,n) local r = find (id,n) if r then context(r) end end
function commands.gettwopassdatalist (id)   local r = list (id)   if r then context(r) end end
function commands.counttwopassdata   (id)   local r = count(id)   if r then context(r) end end
function commands.checktwopassdata   (id)   local r = check(id)   if r then context(r) end end

commands.definetwopasslist     = jobpasses.define
commands.savetwopassdata       = jobpasses.save
commands.savetaggedtwopassdata = jobpasses.savetagged

function commands.doifelseintwopassdata(id,str)
    commands.doifelse(inlist(id,str))
end
