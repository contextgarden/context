if not modules then modules = { } end modules ['typo-inj'] = { -- was node-par
    version   = 1.001,
    comment   = "companion to typo-inj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber

local context           = context
local implement         = interfaces.implement

local injectors         = { }
typesetters.injectors   = injectors
local list              = { }
injectors.list          = list
local showall           = false

local settings_to_array = utilities.parsers.settings_to_array

local variables         = interfaces.variables
local v_next            = variables.next
local v_previous        = variables.previous

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

function injectors.check(name,n) -- we could also accent n = number : +/- 2
    local injector = list[name]
    if not n or n == "" or n == v_next then
        n = injector.counter + 1
    elseif n == v_previous then
        n = injector.counter
    else
        n = tonumber(n) or 0
    end
    local action = injector.actions[n]
    if action then
        context(action)
    end
end

implement { name = "resetinjector",         actions = injectors.reset, arguments = "string" }
implement { name = "showinjector",          actions = injectors.show,  arguments = "string" }
implement { name = "setinjector",           actions = injectors.set,   arguments = "3 strings" }
implement { name = "markinjector",          actions = injectors.mark,  arguments = "string" }
implement { name = "checkinjector",         actions = injectors.check, arguments = "2 strings" }
--------- { name = "checkpreviousinjector", actions = injectors.check, arguments = { "string", tokens.constant(v_previous) } }
--------- { name = "checknextinjector",     actions = injectors.check, arguments = { "string", tokens.constant(v_next) } }
