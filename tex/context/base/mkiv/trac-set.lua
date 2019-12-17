if not modules then modules = { } end modules ['trac-set'] = { -- might become util-set.lua
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe this should be util-set.lua

local type, next, tostring, tonumber = type, next, tostring, tonumber
local print = print
local concat, sortedhash = table.concat, table.sortedhash
local formatters, find, lower, gsub, topattern = string.formatters, string.find, string.lower, string.gsub, string.topattern
local is_boolean = string.is_boolean
local settings_to_hash = utilities.parsers.settings_to_hash
local allocate = utilities.storage.allocate

utilities         = utilities or { }
local utilities   = utilities

local setters     = utilities.setters or { }
utilities.setters = setters

local data        = { }

-- We can initialize from the cnf file. This is sort of tricky as
-- later defined setters also need to be initialized then. If set
-- this way, we need to ensure that they are not reset later on.
--
-- The sorting is needed to get a predictable setters in case of *.

local trace_initialize = false -- only for testing during development
local frozen           = true  -- this needs checking

function setters.initialize(filename,name,values) -- filename only for diagnostics
    local setter = data[name]
    if setter then
     -- trace_initialize = true
        local data = setter.data
        if data then
            for key, newvalue in sortedhash(values) do
                local newvalue = is_boolean(newvalue,newvalue,true) -- strict
                local functions = data[key]
                if functions then
                    local oldvalue = functions.value
                    if functions.frozen then
                        if trace_initialize then
                            setter.report("%s: %a is %s to %a",filename,key,"frozen",oldvalue)
                        end
                    elseif #functions > 0 and not oldvalue then
--                     elseif #functions > 0 and oldvalue == nil then
                        if trace_initialize then
                            setter.report("%s: %a is %s to %a",filename,key,"set",newvalue)
                        end
                        for i=1,#functions do
                            functions[i](newvalue)
                        end
                        functions.value = newvalue
                        functions.frozen = functions.frozen or frozen
                    else
                        if trace_initialize then
                            setter.report("%s: %a is %s as %a",filename,key,"kept",oldvalue)
                        end
                    end
                else
                    -- we do a simple preregistration i.e. not in the
                    -- list as it might be an obsolete entry
                    functions = { default = newvalue, frozen = frozen }
                    data[key] = functions
                    if trace_initialize then
                        setter.report("%s: %a is %s to %a",filename,key,"defaulted",newvalue)
                    end
                end
            end
            return true
        end
    end
end

-- user interface code

local function set(t,what,newvalue)
    local data = t.data
    if not data.frozen then
        local done = t.done
        if type(what) == "string" then
            what = settings_to_hash(what) -- inefficient but ok
        end
        if type(what) ~= "table" then
            return
        end
        if not done then -- catch ... why not set?
            done = { }
            t.done = done
        end
        for w, value in sortedhash(what) do
            if value == "" then
                value = newvalue
            elseif not value then
                value = false -- catch nil
            else
                value = is_boolean(value,value,true) -- strict
            end
            w = topattern(w,true,true)
            for name, functions in sortedhash(data) do
                if done[name] then
                    -- prevent recursion due to wildcards
                elseif find(name,w) then
                    done[name] = true
                    for i=1,#functions do
                        functions[i](value)
                    end
                    functions.value = value
                end
            end
        end
    end
end

local function reset(t)
    local data = t.data
    if not data.frozen then
        for name, functions in sortedthash(data) do
            for i=1,#functions do
                functions[i](false)
            end
            functions.value = false
        end
    end
end

local function enable(t,what)
    set(t,what,true)
end

local function disable(t,what)
    local data = t.data
    if not what or what == "" then
        t.done = { }
        reset(t)
    else
        set(t,what,false)
    end
end

function setters.register(t,what,...)
    local data = t.data
    what = lower(what)
    local functions = data[what]
    if not functions then
        functions = { }
        data[what] = functions
        if trace_initialize then
            t.report("defining %a",what)
        end
    end
    local default = functions.default -- can be set from cnf file
    for i=1,select("#",...) do
        local fnc = select(i,...)
        local typ = type(fnc)
        if typ == "string" then
            if trace_initialize then
                t.report("coupling %a to %a",what,fnc)
            end
            local s = fnc -- else wrong reference
            fnc = function(value) set(t,s,value) end
        elseif typ ~= "function" then
            fnc = nil
        end
        if fnc then
            functions[#functions+1] = fnc
            -- default: set at command line or in cnf file
            -- value  : set in tex run (needed when loading runtime)
            local value = functions.value or default
            if value ~= nil then
                fnc(value)
                functions.value = value
            end
        end
    end
    return false -- so we can use it in an assignment
end

function setters.enable(t,what)
    local e = t.enable
    t.enable, t.done = enable, { }
    enable(t,what)
    t.enable, t.done = e, { }
end

function setters.disable(t,what)
    local e = t.disable
    t.disable, t.done = disable, { }
    disable(t,what)
    t.disable, t.done = e, { }
end

function setters.reset(t)
    t.done = { }
    reset(t)
end

function setters.list(t) -- pattern
    local list = table.sortedkeys(t.data)
    local user, system = { }, { }
    for l=1,#list do
        local what = list[l]
        if find(what,"^%*") then
            system[#system+1] = what
        else
            user[#user+1] = what
        end
    end
    return user, system
end

function setters.show(t)
    local list = setters.list(t)
    t.report()
    for k=1,#list do
        local name = list[k]
        local functions = t.data[name]
        if functions then
            local value   = functions.value
            local default = functions.default
            local modules = #functions
            if default == nil then
                default = "unset"
            elseif type(default) == "table" then
                default = concat(default,"|")
            else
                default = tostring(default)
            end
            if value == nil then
                value = "unset"
            elseif type(value) == "table" then
                value = concat(value,"|")
            else
                value = tostring(value)
            end
            t.report(name)
            t.report("    modules : %i",modules)
            t.report("    default : %s",default)
            t.report("    value   : %s",value)
            t.report()
        end
    end
end

-- we could have used a bit of oo and the trackers:enable syntax but
-- there is already a lot of code around using the singular tracker

-- we could make this into a module but we also want the rest avaliable

local enable, disable, register, list, show = setters.enable, setters.disable, setters.register, setters.list, setters.show

function setters.report(setter,fmt,...)
    print(formatters["%-15s : %s\n"](setter.name,formatters[fmt](...)))
end

local function default(setter,name)
    local d = setter.data[name]
    return d and d.default
end

local function value(setter,name)
    local d = setter.data[name]
    return d and (d.value or d.default)
end

function setters.new(name) -- we could use foo:bar syntax (but not used that often)
    local setter -- we need to access it in setter itself
    setter = {
        data     = allocate(), -- indexed, but also default and value fields
        name     = name,
        report   = function(...) setters.report  (setter,...) end,
        enable   = function(...)         enable  (setter,...) end,
        disable  = function(...)         disable (setter,...) end,
        reset    = function(...)         reset   (setter,...) end, -- can be dangerous
        register = function(...)         register(setter,...) end,
        list     = function(...)  return list    (setter,...) end,
        show     = function(...)         show    (setter,...) end,
        default  = function(...)  return default (setter,...) end,
        value    = function(...)  return value   (setter,...) end,
    }
    data[name] = setter
    return setter
end

trackers    = setters.new("trackers")
directives  = setters.new("directives")
experiments = setters.new("experiments")

local t_enable, t_disable = trackers   .enable, trackers   .disable
local d_enable, d_disable = directives .enable, directives .disable
local e_enable, e_disable = experiments.enable, experiments.disable

-- nice trick: we overload two of the directives related functions with variants that
-- do tracing (itself using a tracker) .. proof of concept

local trace_directives  = false local trace_directives  = false  trackers.register("system.directives",  function(v) trace_directives  = v end)
local trace_experiments = false local trace_experiments = false  trackers.register("system.experiments", function(v) trace_experiments = v end)

function directives.enable(...)
    if trace_directives then
        directives.report("enabling: % t",{...})
    end
    d_enable(...)
end

function directives.disable(...)
    if trace_directives then
        directives.report("disabling: % t",{...})
    end
    d_disable(...)
end

function experiments.enable(...)
    if trace_experiments then
        experiments.report("enabling: % t",{...})
    end
    e_enable(...)
end

function experiments.disable(...)
    if trace_experiments then
        experiments.report("disabling: % t",{...})
    end
    e_disable(...)
end

-- a useful example

directives.register("system.nostatistics", function(v)
    if statistics then
        statistics.enable = not v
    else
        -- forget about it
    end
end)

directives.register("system.nolibraries", function(v)
    if libraries then
        libraries = nil -- we discard this tracing for security
    else
        -- no libraries defined
    end
end)

-- experiment

if environment then

    -- The engineflags are known earlier than environment.arguments but maybe we
    -- need to handle them both as the later are parsed differently. The c: prefix
    -- is used by mtx-context to isolate the flags from those that concern luatex.

    local engineflags = environment.engineflags

    if engineflags then
        local list = engineflags["c:trackers"] or engineflags["trackers"]
        if type(list) == "string" then
            setters.initialize("commandline flags","trackers",settings_to_hash(list))
         -- t_enable(list)
        end
        local list = engineflags["c:directives"] or engineflags["directives"]
        if type(list) == "string" then
            setters.initialize("commandline flags","directives", settings_to_hash(list))
         -- d_enable(list)
        end
    end

end

-- here

if texconfig then

    -- this happens too late in ini mode but that is no problem

    local function set(k,v)
        v = tonumber(v)
        if v then
            texconfig[k] = v
        end
    end

    directives.register("luatex.expanddepth",  function(v) set("expand_depth",v)   end)
    directives.register("luatex.hashextra",    function(v) set("hash_extra",v)     end)
    directives.register("luatex.nestsize",     function(v) set("nest_size",v)      end)
    directives.register("luatex.maxinopen",    function(v) set("max_in_open",v)    end)
    directives.register("luatex.maxprintline", function(v) set("max_print_line",v) end)
    directives.register("luatex.maxstrings",   function(v) set("max_strings",v)    end)
    directives.register("luatex.paramsize",    function(v) set("param_size",v)     end)
    directives.register("luatex.savesize",     function(v) set("save_size",v)      end)
    directives.register("luatex.stacksize",    function(v) set("stack_size",v)     end)

end

-- for now here:

local data = table.setmetatableindex("table")

updaters = {
    register = function(what,f)
        local d = data[what]
        d[#d+1] = f
    end,
    apply = function(what,...)
        local d = data[what]
        for i=1,#d do
            d[i](...)
        end
    end,
}
