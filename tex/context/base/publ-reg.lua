if not modules then modules = { } end modules ['publ-reg'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local formatters = string.formatters
local concat     = table.concat
local sortedhash = table.sortedhash
local lpegmatch  = lpeg.match

local context        = context
local commands       = commands

local variables      = interfaces.variables

local v_once         = variables.once
local v_stop         = variables.stop
local v_all          = variables.all

local publications   = publications
local datasets       = publications.datasets
local specifications = publications.specifications
local writers        = publications.writers
local getcasted      = publications.getcasted

local registrations  = { }
local sequence       = { }
local flushers       = table.setmetatableindex(function(t,k) local v = t.default t[k] = v return v end)

function commands.setbtxregister(specification)
    local name     = specification.name
    local register = specification.register
    local dataset  = specification.dataset
    local field    = specification.field
    if not field or field == "" or not register or register == "" then
        return
    end
    if not dataset or dataset == "" then
        dataset = v_all
    end
    -- could be metatable magic
    local s = registrations[register]
    if not s then
        s = { }
        registrations[register] = s
    end
    local processors = name ~= register and name or ""
    if processor == "" then
        processor = nil
    elseif processor then
        processor = "btx:r:" .. processor
    end
    local datasets = utilities.parsers.settings_to_array(dataset)
    for i=1,#datasets do
        local dataset = datasets[i]
        local d = s[dataset]
        if not d then
            d = { }
            s[dataset] = d
        end
        --
        -- check all
        --
        d.active      = specification.state ~= v_stop
        d.once        = specification.method == v_once or false
        d.field       = field
        d.processor   = processor
        d.alternative = d.alternative or specification.alternative
        d.register    = register
        d.dataset     = dataset
        d.done        = d.done or { }
    end
    --
    sequence   = { }
    for register, s in sortedhash(registrations) do
        for dataset, d in sortedhash(s) do
            if d.active then
                sequence[#sequence+1] = d
            end
        end
    end
end

function commands.btxtoregister(dataset,tag)
    local current = datasets[dataset]
    for i=1,#sequence do
        local step = sequence[i]
        local dset = step.dataset
        if dset == v_all or dset == dataset then
            local done = step.done
            if not done[tag] then
                local value, field, kind = getcasted(current,tag,step.field,specifications[step.specification])
                if value then
                    flushers[kind](step,field,value)
                end
                done[tag] = true
            end
        end
    end
end

-- context.setregisterentry (
--     { register },
--     {
--         ["entries:1"] = value,
--         ["keys:1"]    = value,
--     }
-- )

local ctx_dosetfastregisterentry = context.dosetfastregisterentry -- register entry key

----- p_keywords = lpeg.tsplitat(lpeg.patterns.whitespace^0 * lpeg.P(";") * lpeg.patterns.whitespace^0)
local components = publications.components.author
local f_author   = formatters[ [[\btxindexedauthor{%s}{%s}{%s}{%s}{%s}{%s}]] ]

function flushers.string(step,field,value)
    if type(value) == "string" and value ~= "" then
        ctx_dosetfastregisterentry(step.register,value or "","",step.processor or "","")
    end
end

flushers.default = flushers.string

local shorts = {
    normalshort   = "normalshort",
    invertedshort = "invertedshort",
}

function flushers.author(step,field,value)
    if type(value) == "table" and #value > 0 then
        local register    = step.register
        local processor   = step.processor
        local alternative = shorts[step.alternative or "invertedshort"] or "invertedshort"
        for i=1,#value do
            local a = value[i]
            local k = writers[field] { a }
            local e = f_author(alternative,components(a,short))
            ctx_dosetfastregisterentry(register,e,k,processor or "","")
        end
    end
end

function flushers.keyword(step,field,value)
    if type(value) == "table" and #value > 0 then
        local register  = step.register
        local processor = step.processor
        for i=1,#value do
            ctx_dosetfastregisterentry(register,value[i],"",processor or "","")
        end
    end
end
