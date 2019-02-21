if not modules then modules = { } end modules ['core-dat'] = {
    version   = 1.001,
    comment   = "companion to core-dat.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module provides a (multipass) container for arbitrary data. It
replaces the twopass data mechanism.</p>
--ldx]]--

local tonumber, tostring, type = tonumber, tostring, type

local context          = context
local commands         = commands
local ctx_latelua      = context.latelua

local trace_datasets   = false  trackers.register("job.datasets" ,  function(v) trace_datasets   = v end)
local trace_pagestates = false  trackers.register("job.pagestates", function(v) trace_pagestates = v end)

local report_dataset   = logs.reporter("dataset")
local report_pagestate = logs.reporter("pagestate")

local allocate         = utilities.storage.allocate
local settings_to_hash = utilities.parsers.settings_to_hash

local texgetcount      = tex.getcount
local texsetcount      = tex.setcount

local formatters       = string.formatters

local v_yes            = interfaces.variables.yes

local new_latelua      = nodes.pool.latelua

local implement        = interfaces.implement
local getnamespace     = interfaces.getnamespace

local collected = allocate()
local tobesaved = allocate()

local datasets = {
    collected = collected,
    tobesaved = tobesaved,
}

job.datasets = datasets

local function initializer()
    collected = datasets.collected
    tobesaved = datasets.tobesaved
end

job.register('job.datasets.collected', tobesaved, initializer, nil)

local sets = { }

table.setmetatableindex(tobesaved, function(t,k)
    local v = { }
    t[k] = v
    return v
end)

table.setmetatableindex(sets, function(t,k)
    local v = {
        index = 0,
        order = 0,
    }
    t[k] = v
    return v
end)

local function setdata(settings)
    local name = settings.name
    local tag  = settings.tag
    local data = settings.data
    local list = tobesaved[name]
    if settings.convert and type(data) == "string" then
        data = settings_to_hash(data)
    end
    if type(data) ~= "table" then
        data = { data = data }
    end
    if not tag then
        tag = #list + 1
    else
        tag = tonumber(tag) or tag -- autonumber saves keys
    end
    list[tag] = data
    if settings.delay == v_yes then
        local set = sets[name]
        local index = set.index + 1
        set.index = index
        data.index = index
        data.order = index
        data.realpage = texgetcount("realpageno")
        if trace_datasets then
            report_dataset("action %a, name %a, tag %a, index %a","assign delayed",name,tag,index)
        end
    elseif trace_datasets then
        report_dataset("action %a, name %a, tag %a","assign immediate",name,tag)
    end
    return name, tag, data
end

datasets.setdata = setdata

function datasets.extend(name,tag)
    if type(name) == "table" then
        name, tag = name.name, name.tag
    end
    local set = sets[name]
    local order = set.order + 1
    local realpage = texgetcount("realpageno")
    set.order = order
    local t = tobesaved[name][tag]
    t.realpage = realpage
    t.order = order
    if trace_datasets then
        report_dataset("action %a, name %a, tag %a, page %a, index %a","flush by order",name,tag,t.index or 0,order,realpage)
    end
end

function datasets.getdata(name,tag,key,default)
    local t = collected[name]
    if t == nil then
        if trace_datasets then
            report_dataset("error: unknown dataset, name %a",name)
        end
    elseif type(t) ~= "table" then
        return t
    else
        t = t[tag] or t[tonumber(tag)]
        if not t then
            if trace_datasets then
                report_dataset("error: unknown dataset, name %a, tag %a",name,tag)
            end
        elseif key then
            return t[key] or default
        else
            return t
        end
    end
    return default
end

local function setdataset(settings)
    settings.convert = true
    local name, tag = setdata(settings)
    if settings.delay ~= v_yes then
        --
    else
        context(new_latelua { action = job.datasets.extend, name = name, tag = tag })
    end
end

local function datasetvariable(name,tag,key)
    local t = collected[name]
    if t == nil then
        if trace_datasets then
            report_dataset("error: unknown dataset, name %a, tag %a, not passed to tex",name) -- no tag
        end
    elseif type(t) ~= "table" then
        context(tostring(t))
    else
        t = t and (t[tag] or t[tonumber(tag)])
        if not t then
            if trace_datasets then
                report_dataset("error: unknown dataset, name %a, tag %a, not passed to tex",name,tag)
            end
        elseif type(t) == "table" then
            local s = t[key]
            if type(s) ~= "table" then
                context(tostring(s))
            elseif trace_datasets then
                report_dataset("error: unknown dataset, name %a, tag %a, not passed to tex",name,tag)
            end
        end
    end
end

implement {
    name      = "setdataset",
    actions   = setdataset,
    arguments = {
        {
            { "name" },
            { "tag" },
            { "delay" },
            { "data" },
        }
    }
}

implement {
    name      = "datasetvariable",
    actions   = datasetvariable,
    arguments = "3 strings",
}

--[[ldx--
<p>We also provide an efficient variant for page states.</p>
--ldx]]--

local collected = allocate()
local tobesaved = allocate()

local pagestates = {
    collected = collected,
    tobesaved = tobesaved,
}

job.pagestates = pagestates

local function initializer()
    collected = pagestates.collected
    tobesaved = pagestates.tobesaved
end

job.register('job.pagestates.collected', tobesaved, initializer, nil)

table.setmetatableindex(tobesaved, function(t,k)
    local v = { }
    t[k] = v
    return v
end)

local function setstate(settings)
    local name = settings.name
    local tag  = settings.tag
    local list = tobesaved[name]
    if not tag then
        tag = #list + 1
    else
        tag = tonumber(tag) or tag -- autonumber saves keys
    end
    local realpage = texgetcount("realpageno")
    local data = realpage
    list[tag] = data
    if trace_pagestates then
        report_pagestate("action %a, name %a, tag %a, preset %a","set",name,tag,realpage)
    end
    return name, tag, data
end

local function extend(name,tag)
    local realpage = texgetcount("realpageno")
    if trace_pagestates then
        report_pagestate("action %a, name %a, tag %a, preset %a","synchronize",name,tag,realpage)
    end
    tobesaved[name][tag] = realpage
end

local function realpage(name,tag,default)
    local t = collected[name]
    if t then
        t = t[tag] or t[tonumber(tag)]
        if t then
            return tonumber(t or default)
        elseif trace_pagestates then
            report_pagestate("error: unknown dataset, name %a, tag %a",name,tag)
        end
    elseif trace_pagestates then
        report_pagestate("error: unknown dataset, name %a, tag %a",name) -- nil
    end
    return default
end

local function realpageorder(name,tag)
    local t = collected[name]
    if t then
        local p = t[tag]
        if p then
            local n = 1
            for i=tag-1,1,-1 do
                if t[i] == p then
                    n = n  +1
                end
            end
            return n
        end
    end
    return 0
end

pagestates.setstate      = setstate
pagestates.extend        = extend
pagestates.realpage      = realpage
pagestates.realpageorder = realpageorder

function pagestates.countervalue(name)
    return name and texgetcount(getnamespace("pagestatecounter") .. name) or 0
end

local function setpagestate(settings)
    local name, tag = setstate(settings)
 -- context(new_latelua(function() extend(name,tag) end))
    ctx_latelua(function() extend(name,tag) end)
end

local function setpagestaterealpageno(name,tag)
    local t = collected[name]
    t = t and (t[tag] or t[tonumber(tag)])
    texsetcount("realpagestateno",t or texgetcount("realpageno"))
end

implement {
    name      = "setpagestate",
    actions   = setpagestate,
    arguments = {
        {
            { "name" },
            { "tag" },
            { "delay" },
        }
    }
}

implement {
    name      = "pagestaterealpage",
    actions   = { realpage, context },
    arguments = "2 strings",
}

implement {
    name      = "setpagestaterealpageno",
    actions   = setpagestaterealpageno,
    arguments = "2 strings",
}

implement {
    name      = "pagestaterealpageorder",
    actions   = { realpageorder, context },
    arguments = { "string", "integer" }
}
