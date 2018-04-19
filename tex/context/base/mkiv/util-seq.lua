if not modules then modules = { } end modules ['util-seq'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Here we implement a mechanism for chaining the special functions
that we use in <l n="context"> to deal with mode list processing. We
assume that namespaces for the functions are used, but for speed we
use locals to refer to them when compiling the chain.</p>
--ldx]]--

-- todo: delayed: i.e. we register them in the right order already but delay usage

-- todo: protect groups (as in tasks)

local gsub, concat, gmatch = string.gsub, table.concat, string.gmatch
local type, load = type, load

utilities               = utilities or { }
local tables            = utilities.tables
local allocate          = utilities.storage.allocate

local formatters        = string.formatters
local replacer          = utilities.templates.replacer

local sequencers        = { }
utilities.sequencers    = sequencers

local functions         = allocate()
sequencers.functions    = functions

local removevalue       = tables.removevalue
local replacevalue      = tables.replacevalue
local insertaftervalue  = tables.insertaftervalue
local insertbeforevalue = tables.insertbeforevalue

local function validaction(action)
    if type(action) == "string" then
        local g = _G
        for str in gmatch(action,"[^%.]+") do
            g = g[str]
            if not g then
                return false
            end
        end
    end
    return true
end

local compile

local known = { } -- just a convenience, in case we want public access (only to a few methods)

function sequencers.new(t) -- was reset
    local s = {
        list   = { },
        order  = { },
        kind   = { },
        askip  = { },
        gskip  = { },
        dirty  = true,
        runner = nil,
    }
    if t then
        s.arguments    = t.arguments
        s.templates    = t.templates
        s.returnvalues = t.returnvalues
        s.results      = t.results
        local name     = t.name
        if name and name ~= "" then
            s.name      = name
            known[name] = s
        end
    end
    table.setmetatableindex(s,function(t,k)
        -- this will automake a dirty runner
        if k == "runner" then
            local v = compile(t,t.compiler)
            return v
        end
    end)
    known[s] = s -- saves test for string later on
    return s
end

function sequencers.prependgroup(t,group,where)
    t = known[t]
    if t then
        local order = t.order
        removevalue(order,group)
        insertbeforevalue(order,where,group)
        t.list[group] = { }
        t.dirty       = true
        t.runner      = nil
    end
end

function sequencers.appendgroup(t,group,where)
    t = known[t]
    if t then
        local order = t.order
        removevalue(order,group)
        insertaftervalue(order,where,group)
        t.list[group] = { }
        t.dirty       = true
        t.runner      = nil
    end
end

function sequencers.prependaction(t,group,action,where,kind,force)
    t = known[t]
    if t then
        local g = t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            insertbeforevalue(g,where,action)
            t.kind[action] = kind
            t.dirty        = true
            t.runner       = nil
        end
    end
end

function sequencers.appendaction(t,group,action,where,kind,force)
    t = known[t]
    if t then
        local g = t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            insertaftervalue(g,where,action)
            t.kind[action] = kind
            t.dirty        = true
            t.runner       = nil
        end
    end
end

function sequencers.enableaction(t,action)
    t = known[t]
    if t then
        t.askip[action] = false
        t.dirty         = true
        t.runner        = nil
    end
end

function sequencers.disableaction(t,action)
    t = known[t]
    if t then
        t.askip[action] = true
        t.dirty         = true
        t.runner        = nil
    end
end

function sequencers.enablegroup(t,group)
    t = known[t]
    if t then
        t.gskip[action] = false
        t.dirty         = true
        t.runner        = nil
    end
end

function sequencers.disablegroup(t,group)
    t = known[t]
    if t then
        t.gskip[action] = true
        t.dirty         = true
        t.runner        = nil
    end
end

function sequencers.setkind(t,action,kind)
    t = known[t]
    if t then
        t.kind[action]  = kind
        t.dirty         = true
        t.runner        = nil
    end
end

function sequencers.removeaction(t,group,action,force)
    t = known[t]
    local g = t and t.list[group]
    if g and (force or validaction(action)) then
        removevalue(g,action)
        t.dirty  = true
        t.runner = nil
    end
end

function sequencers.replaceaction(t,group,oldaction,newaction,force)
    t = known[t]
    if t then
        local g = t.list[group]
        if g and (force or validaction(oldaction)) then
            replacevalue(g,oldaction,newaction)
            t.dirty  = true
            t.runner = nil
        end
    end
end

local function localize(str)
    return (gsub(str,"[%.: ]+","_"))
end

local function construct(t)
    local list, order, kind, gskip, askip = t.list, t.order, t.kind, t.gskip, t.askip
    local arguments, returnvalues, results = t.arguments or "...", t.returnvalues, t.results
    local variables, calls, n = { }, { }, 0
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    local localized
                    if type(action) == "function" then
                        local name = localize(tostring(action))
                        functions[name] = action
                        action = formatters["utilities.sequencers.functions.%s"](name)
                        localized = localize(name) -- shorter than action
                    else
                        localized = localize(action)
                    end
                    n = n + 1
                    variables[n] = formatters["local %s = %s"](localized,action)
                    if not returnvalues then
                        calls[n] = formatters["%s(%s)"](localized,arguments)
                    elseif n == 1 then
                        calls[n] = formatters["local %s = %s(%s)"](returnvalues,localized,arguments)
                    else
                        calls[n] = formatters["%s = %s(%s)"](returnvalues,localized,arguments)
                    end
                end
            end
        end
    end
    t.dirty = false
    if n == 0 then
        t.compiled = ""
    else
        variables = concat(variables,"\n")
        calls = concat(calls,"\n")
        if results then
            t.compiled = formatters["%s\nreturn function(%s)\n%s\nreturn %s\nend"](variables,arguments,calls,results)
        else
            t.compiled = formatters["%s\nreturn function(%s)\n%s\nend"](variables,arguments,calls)
        end
    end
    return t.compiled -- also stored so that we can trace
end

sequencers.tostring = construct
sequencers.localize = localize

compile = function(t,compiler,n) -- already referred to in sequencers.new
    local compiled
    if not t or type(t) == "string" then
        -- weird ... t.compiled = t .. so
        return false
    end
    if compiler then
        compiled = compiler(t,n)
        t.compiled = compiled
    else
        compiled = construct(t,n)
    end
    local runner
    if compiled == "" then
        runner = false
    else
        runner = compiled and load(compiled)() -- we can use loadstripped here
    end
    t.runner = runner
    return runner
end

sequencers.compile = compile

-- we used to deal with tail as well but now that the lists are always
-- double linked and the kernel function no longer expect tail as
-- argument we stick to head and done (done can probably also go
-- as luatex deals with return values efficiently now .. in the
-- past there was some copying involved, but no longer)

-- todo: use sequencer (can have arguments and returnvalues etc now)

local template_yes_state = [[
%s
return function(head%s)
  local ok, done = false, false
%s
  return head, done
end]]

local template_yes_nostate = [[
%s
return function(head%s)
%s
  return head, true
end]]

local template_nop = [[
return function()
  return false, false
end]]

local function nodeprocessor(t,nofarguments) -- todo: handle 'kind' in plug into tostring
    local list, order, kind, gskip, askip = t.list, t.order, t.kind, t.gskip, t.askip
    local nostate = t.nostate
    local vars, calls, args, n = { }, { }, nil, 0
    if nofarguments == 0 then
        args = ""
    elseif nofarguments == 1 then
        args = ",one"
    elseif nofarguments == 2 then
        args = ",one,two"
    elseif nofarguments == 3 then -- from here on probably slower than ...
        args = ",one,two,three"
    elseif nofarguments == 4 then
        args = ",one,two,three,four"
    elseif nofarguments == 5 then
        args = ",one,two,three,four,five"
    else
        args = ",..."
    end
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    local localized = localize(action)
                    n = n + 1
                    vars[n] = formatters["local %s = %s"](localized,action)
                    -- only difference with tostring is kind and rets (why no return)
                    if nostate then
                        if kind[action] == "nohead" then
                            calls[n] = formatters["         %s(head%s)"](localized,args)
                        else
                            calls[n] = formatters["  head = %s(head%s)"](localized,args)
                        end
                    else
                        if kind[action] == "nohead" then
                            calls[n] = formatters["        ok = %s(head%s) if ok then done = true end"](localized,args)
                        else
                            calls[n] = formatters["  head, ok = %s(head%s) if ok then done = true end"](localized,args)
                        end
                    end
                end
            end
        end
    end
    local processor = #calls > 0 and formatters[nostate and template_yes_nostate or template_yes_state](concat(vars,"\n"),args,concat(calls,"\n")) or template_nop
 -- print(processor)
    return processor
end

function sequencers.nodeprocessor(t,nofarguments)
    local kind = type(nofarguments)
    if kind == "number" then
        return nodeprocessor(t,nofarguments)
    elseif kind ~= "table" then
        return
    end
    --
    local templates = nofarguments
    local process   = templates.process
    local step      = templates.step
    --
    if not process or not step then
        return ""
    end
    --
    local construct = replacer(process)
    local newaction = replacer(step)
    local calls     = { }
    local aliases   = { }
    local n         = 0
    --
    local list  = t.list
    local order = t.order
    local kind  = t.kind
    local gskip = t.gskip
    local askip = t.askip
    --
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    local localized = localize(action)
                    n = n + 1
                    aliases[n] = formatters["local %s = %s"](localized,action)
                    calls[n]   = newaction { action = localized }
                end
            end
        end
    end
    if n == 0 then
        return templates.default or construct { }
    end
    local processor = construct {
        localize = concat(aliases,"\n"),
        actions  = concat(calls,"\n"),
    }
    return processor
end
