if not modules then modules = { } end modules ['strc-syn'] = {
    version   = 1.001,
    comment   = "companion to str-syn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format = string.format
local allocate = utilities.storage.allocate

-- interface to tex end

local context      = context
local sorters      = sorters

local structures   = structures
local synonyms     = structures.synonyms
local tags         = structures.tags

local collected    = allocate()
local tobesaved    = allocate()

local firstofsplit = sorters.firstofsplit
local strip        = sorters.strip
local splitter     = sorters.splitters.utf

synonyms.collected = collected
synonyms.tobesaved = tobesaved

local function initializer()
    collected = synonyms.collected
    tobesaved = synonyms.tobesaved
end

local function finalizer()
    for entry, data in next, tobesaved do
        data.hash = nil
    end
end

job.register('structures.synonyms.collected', tobesaved, initializer, finalizer)

-- todo: allocate becomes metatable

local function allocate(class)
    local d = tobesaved[class]
    if not d then
        d = {
            metadata = {
                language = 'en',
                sorted   = false,
                class    = class
            },
            entries  = {
            },
            hash = {
            }
        }
        tobesaved[class] = d
    end
    return d
end

function synonyms.define(class,kind)
    local data = allocate(class)
    data.metadata.kind = kind
end

function synonyms.register(class,kind,spec)
    local data = allocate(class)
    data.metadata.kind = kind -- runtime, not saved in format (yet)
    if not data.hash[spec.definition.tag or ""] then
        data.entries[#data.entries+1] = spec
        data.hash[spec.definition.tag or ""] = spec
    end
end

function synonyms.registerused(class,tag)
    local data = allocate(class)
    local dht = data.hash[tag]
    if dht then
        dht.definition.used = true
    end
end

function synonyms.synonym(class,tag)
    local data = allocate(class).hash
    local d = data[tag]
    if d then
        local de = d.definition
        de.used = true
        context(de.synonym)
    end
end

function synonyms.meaning(class,tag)
    local data = allocate(class).hash
    local d = data[tag]
    if d then
        local de = d.definition
        de.used = true
        context(de.meaning)
    end
end

synonyms.compare = sorters.comparers.basic -- (a,b)

function synonyms.filter(data,options)
    local result = { }
    local entries = data.entries
    local all = options and options.criterium == interfaces.variables.all
    for i=1,#entries do
        local entry = entries[i]
        if all or entry.definition.used then
            result[#result+1] = entry
        end
    end
    data.result = result
end

function synonyms.prepare(data)
    local result = data.result
    if result then
        for i=1, #result do
            local r = result[i]
            local rd = r.definition
            if rd then
                local rt = rd.tag
                local sortkey = rt and rt ~= "" and rt or rd.synonym
                r.split = splitter(strip(sortkey))
            end
        end
    end
end

function synonyms.sort(data,options)
    sorters.sort(data.result,synonyms.compare)
end

function synonyms.finalize(data,options)
    local result = data.result
    data.metadata.nofsorted = #result
    local split = { }
    for k=1,#result do
        local v = result[k]
        local entry, tag = firstofsplit(v)
        local s = split[entry] -- keeps track of change
        local d
        if not s then
            d = { }
            s = { tag = tag, data = d }
            split[entry] = s
        else
            d = s.data
        end
        d[#d+1] = v
    end
    data.result = split
end

-- for now, maybe at some point we will do a multipass or so
-- maybe pass the settings differently

local ctx_synonymentry = context.synonymentry

function synonyms.flush(data,options)
    local kind = data.metadata.kind -- hack, will be done better
    local result = data.result
    local sorted = table.sortedkeys(result)
    for k=1,#sorted do
        local letter = sorted[k]
        local sublist = result[letter]
        local data = sublist.data
        for d=1,#data do
            local entry = data[d].definition
            ctx_synonymentry(d,entry.tag,entry.synonym,entry.meaning or "")
        end
    end
    data.result = nil
    data.metadata.sorted = false
end

function synonyms.analyzed(class,options)
    local data = synonyms.collected[class]
    if data and data.entries then
        options = options or { }
        sorters.setlanguage(options.language,options.method)
        synonyms.filter(data,options)   -- filters entries to result
        synonyms.prepare(data,options)  -- adds split table parallel to list table
        synonyms.sort(data,options)     -- sorts entries in result
        synonyms.finalize(data,options) -- do things with data.entries
        data.metadata.sorted = true
    end
    return data and data.metadata.sorted and data.result and next(data.result)
end

function synonyms.process(class,options)
    if synonyms.analyzed(class,options) then
        synonyms.flush(synonyms.collected[class],options)
    end
end

commands.registersynonym     = synonyms.register
commands.registerusedsynonym = synonyms.registerused
commands.synonymmeaning      = synonyms.meaning
commands.synonymname         = synonyms.synonym
commands.processsynonyms     = synonyms.process
