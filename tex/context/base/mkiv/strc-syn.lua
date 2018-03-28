if not modules then modules = { } end modules ['strc-syn'] = {
    version   = 1.001,
    comment   = "companion to str-syn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type

local context      = context
local implement    = interfaces.implement

local allocate     = utilities.storage.allocate

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

table.setmetatableindex(tobesaved,function(t,k)
    local v = {
        metadata = {
            language = 'en',
            sorted   = false,
            class    = v
        },
        entries  = {
        },
        hash = {
        }
    }
    t[k] = v
    return v
end)

function synonyms.define(class,kind)
    local data = tobesaved[class]
    data.metadata.kind = kind
end

function synonyms.register(class,kind,spec)
    local data       = tobesaved[class]
    local hash       = data.hash
    local definition = spec.definition
    local tag        = definition.tag or ""
    data.metadata.kind = kind -- runtime, not saved in format (yet)
    if not hash[tag] then
        if definition.used == nil then
            definition.used = false
        end
        if definition.shown == nil then
            definition.shown = false
        end
        local entries = data.entries
        entries[#entries+1] = spec
        hash[tag] = spec
    end
end

function synonyms.registerused(class,tag)
    local data = tobesaved[class]
    local okay = data.hash[tag]
    if okay then
        local definition = okay.definition
        definition.used = true
        definition.list = true
    end
end

function synonyms.registershown(class,tag)
    local data = tobesaved[class]
    local okay = data.hash[tag]
    if okay then
        local definition = okay.definition
        definition.shown = true
        definition.list  = true
    end
end

function synonyms.isused(class,tag)
    local data = tobesaved[class]
    local okay = data.hash[tag]
    return okay and okay.definition.used
end

function synonyms.isshown(class,tag)
    local data = tobesaved[class]
    local okay = data.hash[tag]
    return okay and okay.definition.shown
end

function synonyms.resetused(class)
    for tag, data in next, tobesaved[class].hash do
        data.definition.used = false
    end
end

function synonyms.resetshown(class)
    for tag, data in next, tobesaved[class].hash do
        data.definition.shown = false
    end
end

function synonyms.synonym(class,tag)
    local data = tobesaved[class]
    local okay = data.hash[tag]
    if okay then
        local definition = okay.definition
        definition.used = true
        definition.list = true
        context(definition.synonym)
    end
end

function synonyms.meaning(class,tag)
    local data = tobesaved[class]
    local okay = data.hash[tag]
    if okay then
        local definition = okay.definition
        definition.shown = true
        definition.list  = true
        context(definition.meaning)
    end
end

synonyms.compare = sorters.comparers.basic -- (a,b)

function synonyms.filter(data,options)
    local result  = { }
    local entries = data.entries
    local all     = options and options.criterium == interfaces.variables.all
    if all then
        for i=1,#entries do
            result[i] = entries[i]
        end
    else
        for i=1,#entries do
            local entry      = entries[i]
            local definition = entry.definition
            if definition.list then
                result[#result+1] = entry
            end
        end
    end
    data.result = result
end

function synonyms.prepare(data)
    local result = data.result
    if result then
        for i=1, #result do
            local entry      = result[i]
            local definition = entry.definition
            if definition then
                local tag = definition.tag
                local key = tag ~= "" and tag or definition.synonym
                entry.split = splitter(strip(key))
            end
        end
    end
end

function synonyms.sort(data,options)
    sorters.sort(data.result,synonyms.compare)
    data.metadata.sorted = true
end

function synonyms.finalize(data,options) -- mostly the same as registers so we will generalize it: sorters.split
    local result   = data.result
    local split    = { }
    local nofsplit = 0
    local lasttag  = nil
    local lasttag  = nil
    local nofdone  = 0
    for k=1,#result do
        local entry = result[k]
        local first, tag = firstofsplit(entry)
        if tag ~= lasttag then
         -- if trace_registers then
         --     report_registers("splitting at %a",tag)
         -- end
            done     = { }
            nofdone  = 0
            nofsplit = nofsplit + 1
            lasttag  = tag
            split[nofsplit] = { tag = tag, data = done }
        end
        nofdone = nofdone + 1
        done[nofdone] = entry
    end
    data.result = split
end

-- for now, maybe at some point we will do a multipass or so
-- maybe pass the settings differently

local ctx_synonymentry = context.synonymentry

function synonyms.flush(data,options)
    local result = data.result
    for i=1,#result do
        local sublist = result[i]
        local data    = sublist.data
        for d=1,#data do
            local entry = data[d].definition
            ctx_synonymentry(d,entry.tag,entry.synonym,entry.meaning or "")
        end
    end
    data.result          = nil
    data.metadata.sorted = false
end

function synonyms.analyzed(class,options)
    local data = collected[class]
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
        synonyms.flush(collected[class],options)
    end
end

-- todo: local higher up

implement { name = "registerusedsynonym",  actions = synonyms.registerused,  arguments = "2 strings" }
implement { name = "registershownsynonym", actions = synonyms.registershown, arguments = "2 strings" }
implement { name = "synonymmeaning",       actions = synonyms.meaning,       arguments = "2 strings" }
implement { name = "synonymname",          actions = synonyms.synonym,       arguments = "2 strings" }
implement { name = "resetusedsynonyms",    actions = synonyms.resetused,     arguments = "string" }
implement { name = "resetshownsynonyms",   actions = synonyms.resetshown,    arguments = "string" }

implement {
    name      = "doifelsesynonymused",
    actions   = { synonyms.isused, commands.doifelse },
    arguments = "2 strings",
}

implement {
    name      = "doifelsesynonymshown",
    actions   = { synonyms.isshown, commands.doifelse },
    arguments = "2 strings",
}

implement {
    name      = "registersynonym",
    actions   = synonyms.register,
    arguments = {
        "string",
        "string",
        {
            { "metadata", {
                    { "catcodes", "integer" },
                    { "coding" },
                    { "xmlroot" }
                }
            },
            {
                "definition", {
                    { "tag" },
                    { "synonym" },
                    { "meaning" },
                    { "used", "boolean" }
                }
            }
        }
    }
}

implement {
    name      = "processsynonyms",
    actions   = synonyms.process,
    arguments = {
        "string",
        {
            { "criterium" },
            { "language" },
            { "method" }
        }
    }
}
