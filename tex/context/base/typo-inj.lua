if not modules then modules = { } end modules ['typo-inj'] = { -- was node-par
    version   = 1.001,
    comment   = "companion to typo-inj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local context, commands = context, commands

local injectors       = { }
typesetters.injectors = injectors
local list            = { }
injectors.list        = list
local showall         = false

local settings_to_array      = utilities.parsers.settings_to_array

local ctx_domarkinjector     = context.domarkinjector
local ctx_doactivateinjector = context.doactivateinjector

table.setmetatableindex(list,function(t,k)
    local v = {
        counter = 0,
        actions = { },
        show    = false,
        active  = false,
    }
    t[k] = v
    return v
end)

function injectors.reset(name)
    list[name] = nil
end

function injectors.set(name,numbers,command)
    local injector = list[name]
    local actions = injector.actions
    local places  = settings_to_array(numbers)
    for i=1,#places do
        actions[tonumber(places[i])] = command
    end
    if not injector.active then
        ctx_doactivateinjector(name)
        injector.active = true
    end
end

function injectors.show(name)
    if not name or name == "" then
        showall = true
    else
        local list = settings_to_array(name)
        for i=1,#list do
            list[list[i]].show = true
        end
    end
end

function injectors.mark(name,show)
    local injector = list[name]
    local n = injector.counter + 1
    injector.counter = n
    if showall or injector.show then
        ctx_domarkinjector(injector.actions[n] and 1 or 0,n)
    end
end

function injectors.check(name,n)
    local injector = list[name]
    if n == false then
        n = injector.counter
    elseif n == nil then
        n = injector.counter + 1 -- next (upcoming)
    else
        n = tonumber(n) or 0
    end
    local action = injector.actions[n]
    if action then
        context(action)
    end
end

commands.resetinjector  = injectors.reset
commands.showinjector   = injectors.show
commands.setinjector    = injectors.set
commands.markinjector   = injectors.mark
commands.checkinjector  = injectors.check
