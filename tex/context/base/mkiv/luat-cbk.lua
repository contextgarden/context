if not modules then modules = { } end modules ['luat-cbk'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local insert, remove, concat = table.insert, table.remove, table.concat
local find, format = string.find, string.format
local collectgarbage, type, next = collectgarbage, type, next
local round = math.round
local sortedhash, sortedkeys, tohash = table.sortedhash, table.sortedkeys, table.tohash

--[[ldx--
<p>Callbacks are the real asset of <l n='luatex'/>. They permit you to hook
your own code into the <l n='tex'/> engine. Here we implement a few handy
auxiliary functions.</p>
--ldx]]--

callbacks       = callbacks or { }
local callbacks = callbacks

--[[ldx--
<p>When you (temporarily) want to install a callback function, and after a
while wants to revert to the original one, you can use the following two
functions. This only works for non-frozen ones.</p>
--ldx]]--

local trace_callbacks   = false  trackers.register("system.callbacks", function(v) trace_callbacks = v end)
local trace_calls       = false  -- only used when analyzing performance and initializations
local trace_checking    = false  trackers.register("memory.checking", function(v) trace_checking = v end)

local report_system     = logs.reporter("system")
local report_callbacks  = logs.reporter("system","callbacks")
local report_memory     = logs.reporter("system","memory")

local register_callback = callback.register
local find_callback     = callback.find
local list_callbacks    = callback.list
local register_usercall = false
local original_register = register_callback

local frozen            = { }
local stack             = { }
local list              = callbacks.list
local permit_overloads  = false
local block_overloads   = false

--[[ldx--
<p>By now most callbacks are frozen and most provide a way to plug in your own code. For instance
all node list handlers provide before/after namespaces and the file handling code can be extended
by adding schemes and if needed I can add more hooks. So there is no real need to overload a core
callback function. It might be ok for quick and dirty testing but anyway you're on your own if
you permanently overload callback functions.</p>
--ldx]]--

-- This might become a configuration file only option when it gets abused too much.

directives.register("system.callbacks.permitoverloads", function(v)
    if block_overloads or permit_overloads then
        -- once bad news, always bad news
    elseif v then
        permit_overloads = { }
        report_system()
        report_system("The callback system has been brought in an unprotected state. As a result of directly")
        report_system("setting of callbacks subsystems of ConTeXt can stop working. There is no support for")
        report_system("bugs resulting from this state. It's better to use the official extension mechanisms.")
        report_system()
    end
end)

sandbox.initializer {
    category = "functions",
    action   = function()
        block_overloads = true
    end
}

if not list then -- otherwise counters get reset

    list = utilities.storage.allocate(list_callbacks())

    local supported = { }

    for k in next, list do
        list[k]      = 0
        supported[k] = true
    end

    callbacks.list      = list
    callbacks.supported = supported

end

local delayed = tohash {
    "buildpage_filter",
}

if trace_calls then

    local functions = { }

    register_callback = function(name,func)
        if type(func) == "function" then
            if functions[name] then
                functions[name] = func
                return find_callback(name)
            else
                functions[name] = func
                local cnuf = function(...)
                    list[name] = list[name] + 1
                    return functions[name](...)
                end
                return original_register(name,cnuf)
            end
        else
            return original_register(name,func)
        end
    end

end

-- temporary, not public:

callbacks.functions = { }

-- till here

local reported = { }

local function register_usercall(what,name,func)
    if list[name] then
        if trace_callbacks or not reported[name] then
            report_system()
            report_system("disabling core code by %s user function into callback '%s' (reported only once)",what,name)
            report_system()
            reported[name] = true
        end
        permit_overloads[name] = true
        return original_register(name,function(...)
            if trace_callbacks then
                report_callbacks("calling user function from '%s'",name)
            end
            return func(...)
        end)
    else
        report_callbacks("not %s function into invalid callback '%s'",name)
        return nil, format("unknown callback '%s'",name)
    end
end

local function frozen_callback(name)
    report_callbacks("not %s frozen %a","registering",name)
    return nil, format("callback '%s' is frozen",name) -- no formatter yet
end

local function state(name)
    local f = find_callback(name)
    if f == false then
        return "disabled"
    elseif f then
        return "enabled"
    else
        return "undefined"
    end
end

function callbacks.known(name)
    return list[name]
end

function callbacks.report()
    for name, _ in sortedhash(list) do
        local str = frozen[name]
        if str then
            report_callbacks("%s: %s -> %s",state(name),name,str)
        else
            report_callbacks("%s: %s",state(name),name)
        end
    end
end

function callbacks.freeze(name,freeze)
    if not permit_overloads then
        freeze = type(freeze) == "string" and freeze
        if find(name,"*",1,true) then
            local pattern = name
            for name, _ in next, list do
                if find(name,pattern) then
                    frozen[name] = freeze or frozen[name] or "frozen"
                end
            end
        else
            frozen[name] = freeze or frozen[name] or "frozen"
        end
    end
end

function callbacks.register(name,func,freeze)
    if frozen[name] then
        if permit_overloads then
            return register_usercall("registering",name,func)
        else
            return frozen_callback(name)
        end
    elseif freeze then
        frozen[name] = type(freeze) == "string" and freeze or "registered"
    end
    if delayed[name] and environment.initex then
        return nil
    end
    return register_callback(name,func)
end

function callback.register(name,func) -- original
    if not frozen[name] then
        return register_callback(name,func)
    elseif permit_overloads then
        return register_usercall("registering",name,func)
    else
        return frozen_callback(name)
    end
end

function callbacks.push(name,func)
    if not frozen[name] or permit_overloads then
        local sn = stack[name]
        if not sn then
            sn = { }
            stack[name] = sn
        end
        insert(sn,find_callback(name))
        if permit_overloads then
            register_usercall("pushing",name,func)
        else
            register_callback(name,func)
        end
    else
        report_callbacks("not %s frozen %a","pushing",name)
    end
end

function callbacks.pop(name)
    if not frozen[name] or permit_overloads then
        local sn = stack[name]
        if not sn or #sn == 0 then
            -- some error
            register_callback(name,nil) -- ! really needed
        else
         -- this fails: register_callback(name, remove(stack[name]))
            local func = remove(sn)
            register_callback(name,func)
        end
    end
end

if trace_calls then
    statistics.register("callback details", function()
        local t = { } -- todo: pass function to register and quit at nil
        for name, n in sortedhash(list) do
            if n > 0 then
                t[#t+1] = format("%s -> %s",name,n)
            end
        end
        return concat(t," ")
    end)
end

statistics.register("callbacks overloaded by user", function()
    if permit_overloads then
        return concat(sortedkeys(permit_overloads)," ")
    end
end)

-- -- somehow crashes later on
--
-- callbacks.freeze("find_.*_file","finding file")
-- callbacks.freeze("read_.*_file","reading file")
-- callbacks.freeze("open_.*_file","opening file")

--[[ldx--
<p>The simple case is to remove the callback:</p>

<code>
callbacks.push('linebreak_filter')
... some actions ...
callbacks.pop('linebreak_filter')
</code>

<p>Often, in such case, another callback or a macro call will pop
the original.</p>

<p>In practice one will install a new handler, like in:</p>

<code>
callbacks.push('linebreak_filter', function(...)
    return something_done(...)
end)
</code>

<p>Even more interesting is:</p>

<code>
callbacks.push('linebreak_filter', function(...)
    callbacks.pop('linebreak_filter')
    return something_done(...)
end)
</code>

<p>This does a one-shot.</p>
--ldx]]--

--[[ldx--
<p>Callbacks may result in <l n='lua'/> doing some hard work
which takes time and above all resourses. Sometimes it makes
sense to disable or tune the garbage collector in order to
keep the use of resources acceptable.</p>

<p>At some point in the development we did some tests with counting
nodes (in this case 121049).</p>

<table>
<tr><td>setstepmul</td><td>seconds</td><td>megabytes</td></tr>
<tr><td>200</td><td>24.0</td><td>80.5</td></tr>
<tr><td>175</td><td>21.0</td><td>78.2</td></tr>
<tr><td>150</td><td>22.0</td><td>74.6</td></tr>
<tr><td>160</td><td>22.0</td><td>74.6</td></tr>
<tr><td>165</td><td>21.0</td><td>77.6</td></tr>
<tr><td>125</td><td>21.5</td><td>89.2</td></tr>
<tr><td>100</td><td>21.5</td><td>88.4</td></tr>
</table>

<p>The following code is kind of experimental. In the documents
that describe the development of <l n='luatex'/> we report
on speed tests. One observation is thta it sometimes helps to
restart the collector. Okay, experimental code has been removed,
because messing aroudn with the gc is too unpredictable.</p>
--ldx]]--

-- For the moment we keep this here and not in util-gbc.lua or so.

utilities                  = utilities or { }
utilities.garbagecollector = utilities.garbagecollector or { }
local garbagecollector     = utilities.garbagecollector

garbagecollector.enabled   = false -- could become a directive
garbagecollector.criterium = 4*1024*1024

-- Lua allocates up to 12 times the amount of memory needed for
-- handling a string, and for large binary chunks (like chinese otf
-- files) we get a prominent memory consumption. Even when a variable
-- is nilled, there is some delay in freeing the associated memory (the
-- hashed string) because if we do the same thing directly afterwards,
-- we see only a slight increase in memory. For that reason it makes
-- sense to do a collector pass after a huge file.
--
-- test file:
--
-- function test()
--     local b = collectgarbage("count")
--     local s = io.loaddata("some font table, e.g. a big tmc file")
--     local a = collectgarbage("count")
--     print(">>> STATUS",b,a,a-b,#s,1000*(a-b)/#s)
-- end
--
-- test() test() test() test() collectgarbage("collect") test() test() test() test()
--
-- As a result of this, LuaTeX now uses an optimized version of f:read("*a"),
-- one that does not use the 4K allocations but allocates in one step.

function garbagecollector.check(size,criterium)
    if garbagecollector.enabled then
        criterium = criterium or garbagecollector.criterium
        if not size or (criterium and criterium > 0 and size > criterium) then
            if trace_checking then
                local b = collectgarbage("count")
                collectgarbage("collect")
                local a = collectgarbage("count")
                report_memory("forced sweep, collected: %s MB, used: %s MB",round((b-a)/1000),round(a/1000))
            else
                collectgarbage("collect")
            end
        end
    end
end

-- this will move to a module

commands = commands or { }

function commands.showcallbacks()
    local NC, NR, verbatim = context.NC, context.NR, context.type
    context.starttabulate { "|l|l|p|" }
    for name, _ in sortedhash(list) do
        NC() verbatim(name) NC() verbatim(state(name)) NC() context(frozen[name] or "") NC() NR()
    end
    context.stoptabulate()
end
