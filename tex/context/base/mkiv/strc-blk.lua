if not modules then modules = { } end modules ['strc-blk'] = {
    version   = 1.001,
    comment   = "companion to strc-blk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one runs on top of buffers and structure

local type, next = type, next
local find, formatters, validstring = string.find, string.formatters, string.valid
local settings_to_set, settings_to_array = utilities.parsers.settings_to_set, utilities.parsers.settings_to_array
local allocate = utilities.storage.allocate

local context     = context
local commands    = commands

local implement   = interfaces.implement

local structures  = structures

structures.blocks = structures.blocks or { }

local blocks      = structures.blocks
local sections    = structures.sections
local lists       = structures.lists
local helpers     = structures.helpers

local collected   = allocate()
local tobesaved   = allocate()
local states      = allocate()

blocks.collected  = collected
blocks.tobesaved  = tobesaved
blocks.states     = states

local function initializer()
    collected = blocks.collected
    tobesaved = blocks.tobesaved
end

job.register('structures.blocks.collected', tobesaved, initializer)

local listitem = utilities.parsers.listitem
local f_block  = formatters["block.%s"]

function blocks.uservariable(index,key,default)
    local c = collected[index]
    if c then
        local u = c.userdata
        if u then
            local v = u[key] or default
            if v then
                context(v)
            end
        end
    end
end

local function printblock(index,name,data,hide)
    if hide then
        context.dostarthiddenblock(index,name)
    else
        context.dostartnormalblock(index,name)
    end
    context.viafile(data,f_block(validstring(name,"noname")))
    if hide then
        context.dostophiddenblock()
    else
        context.dostopnormalblock()
    end
end

blocks.print = printblock

function blocks.define(name)
    states[name] = { all = "hide" }
end

function blocks.setstate(state,name,tag)
    local all  = tag == ""
    local tags = not all and settings_to_array(tag)
    for n in listitem(name) do
        local sn = states[n]
        if not sn then
            -- error
        elseif all then
            sn.all = state
        else
            for _, tag in next, tags do
                sn[tag] = state
            end
        end
    end
end

function blocks.select(state,name,tag,criterium)
    criterium = criterium or "text"
    if find(tag,"=",1,true) then
        tag = ""
    end
    local names  = settings_to_set(name)
    local all    = tag == ""
    local tags   = not all and settings_to_set(tag)
    local hide   = state == "process"
    local result = lists.filter {
        names     = "all",
        criterium = criterium,
        number    = sections.numberatdepth(criterium), -- not needed
        collected = collected,
    }
    for i=1,#result do
        local ri = result[i]
        local metadata = ri.metadata
        if names[metadata.name] then
            if all then
                printblock(ri.index,name,ri.data,hide)
            else
                local mtags = metadata.tags
                if mtags then
                    for tag, sta in next, tags do
                        if mtags[tag] then
                            printblock(ri.index,name,ri.data,hide)
                            break
                        end
                    end
                end
            end
        end
    end
end

function blocks.save(name,tag,userdata,buffer) -- wrong, not yet adapted
    local data  = buffers.getcontent(buffer)
    local tags  = settings_to_set(tag)
    local plus  = false
    local minus = false
    local last  = #tobesaved + 1
    local all   = states[name].all
    if tags['+'] then
        plus      = true
        tags['+'] = nil
    end
    if tags['-'] then
        minus     = true
        tags['-'] = nil
    end
    tobesaved[last] = helpers.simplify {
        metadata   = {
            name  = name,
            tags  = tags,
            plus  = plus,
            minus = minus,
        },
        index      = last,
        data       = data or "error",
        userdata   = userdata and type(userdata) == "string" and helpers.touserdata(userdata),
        references = {
            section = sections.currentid(),
        },
    }
    if not next(tags) then
        if all ~= "hide" then
            printblock(last,name,data)
        elseif plus then
            printblock(last,name,data,true)
        end
    else
        local sn = states[name]
        for tag, _ in next, tags do
            if sn[tag] == nil then
                if all ~= "hide" then
                    printblock(last,name,data)
                    break
                end
            elseif sn[tag] ~= "hide" then
                printblock(last,name,data)
                break
            end
        end
    end
    buffers.erase(buffer)
end

-- interface

implement { name = "definestructureblock",       actions = blocks.define,       arguments = "string" }
implement { name = "savestructureblock",         actions = blocks.save,         arguments = "4 strings" }
implement { name = "selectstructureblock",       actions = blocks.select,       arguments = "4 strings" }
implement { name = "setstructureblockstate",     actions = blocks.setstate,     arguments = "3 strings" }
implement { name = "structureblockuservariable", actions = blocks.uservariable, arguments = { "integer", "string" } }
