if not modules then modules = { } end modules ['publ-reg'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local formatters = string.formatters
local sortedhash = table.sortedhash

local context        = context
local commands       = commands

local variables      = interfaces.variables

local v_once         = variables.once
local v_standard     = variables.standard
local v_stop         = variables.stop
local v_all          = variables.all

local datasets       = publications.datasets
local specifications = { }
local sequence       = { }
local flushers       = { }

function commands.setbtxregister(specification)
    local name     = specification.name or "unset"
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
    local s = specifications[register]
    if not s then
        s = { }
        specifications[register] = s
    end
    local d = s[dataset]
    if not d then
        d = { }
        s[dataset] = d
    end
    --
    -- check all
    --
    local alternative = specification.alternative or d.alternative
    if not alternative or alternative == "" then
        alternative = field
    end
    --
    d.active      = specification.state ~= v_stop
    d.once        = specification.method == v_once or false
    d.field       = field
    d.alternative = alternative
    d.register    = register
    d.dataset     = dataset
    d.done        = d.done or { }
    --
    sequence   = { }
    for register, s in sortedhash(specifications) do
        for dataset, d in sortedhash(s) do
            if d.active then
                sequence[#sequence+1] = d
            end
        end
    end
end

function commands.btxtoregister(dataset,tag)
    for i=1,#sequence do
        local step = sequence[i]
        local dset = step.dataset
        if dset == v_all or dset == dataset then
            local done = step.done
            if not done[tag] then
                local current = datasets[dataset]
                local entry   = current.luadata[tag]
                if entry then
                    local register    = step.register
                    local field       = step.field
                    local alternative = step.alternative
                    local flusher     = flushers[field] or flushers.default
                    flusher(register,dataset,tag,field,alternative,current,entry,current.details[tag])
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

local f_field  = formatters[ [[\dobtxindexedfield{%s}{%s}{%s}{%s}{%s}]] ]
local f_author = formatters[ [[\dobtxindexedauthor{%s}{%s}{%s}{%s}{%s}]] ]

local writer   = publications.serializeauthor

function flushers.default(register,dataset,tag,field,alternative,current,entry,detail)
    local value = detail[field] or entry[field]
    if value then
        local e = f_field(dataset,tag,field,alternative,value)
        ctx_dosetfastregisterentry(register,e,value) -- last value can be ""
    end
end

function flushers.author(register,dataset,tag,field,alternative,current,entry,detail)
    if detail then
        local author = detail[field]
        if author then
            for i=1,#author do
                local a = author[i]
                local k = writer{a}
                local e = f_author(dataset,tag,field,alternative,i)
                ctx_dosetfastregisterentry(register,e,k)
            end
        end
    end
end
