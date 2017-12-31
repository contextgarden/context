if not modules then modules = { } end modules ['trac-pro'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local getmetatable, setmetatable, rawset, type, next = getmetatable, setmetatable, rawset, type, next

-- The protection implemented here is probably not that tight but good enough to catch
-- problems due to naive usage.
--
-- There's a more extensive version (trac-xxx.lua) that supports nesting.
--
-- This will change when we have _ENV in lua 5.2+

local trace_namespaces = false  trackers.register("system.namespaces", function(v) trace_namespaces = v end)

local report_system = logs.reporter("system","protection")

namespaces       = namespaces or { }
local namespaces = namespaces

local registered = { }

local function report_index(k,name)
    if trace_namespaces then
        report_system("reference to %a in protected namespace %a: %s",k,name)
        debugger.showtraceback(report_system)
    else
        report_system("reference to %a in protected namespace %a",k,name)
    end
end

local function report_newindex(k,name)
    if trace_namespaces then
        report_system("assignment to %a in protected namespace %a: %s",k,name)
        debugger.showtraceback(report_system)
    else
        report_system("assignment to %a in protected namespace %a",k,name)
    end
end

local function register(name)
    local data = name == "global" and _G or _G[name]
    if not data then
        return -- error
    end
    registered[name] = data
    local m = getmetatable(data)
    if not m then
        m = { }
        setmetatable(data,m)
    end
    local index, newindex = { }, { }
    m.__saved__index = m.__index
    m.__no__index = function(t,k)
        if not index[k] then
            index[k] = true
            report_index(k,name)
        end
        return nil
    end
    m.__saved__newindex = m.__newindex
    m.__no__newindex = function(t,k,v)
        if not newindex[k] then
            newindex[k] = true
            report_newindex(k,name)
        end
        rawset(t,k,v)
    end
    m.__protection__depth = 0
end

local function private(name) -- maybe save name
    local data = registered[name]
    if not data then
        data = _G[name]
        if not data then
            data = { }
            _G[name] = data
        end
        register(name)
    end
    return data
end

local function protect(name)
    local data = registered[name]
    if not data then
        return
    end
    local m = getmetatable(data)
    local pd = m.__protection__depth
    if pd > 0 then
        m.__protection__depth = pd + 1
    else
        m.__save_d_index, m.__saved__newindex = m.__index, m.__newindex
        m.__index, m.__newindex = m.__no__index, m.__no__newindex
        m.__protection__depth = 1
    end
end

local function unprotect(name)
    local data = registered[name]
    if not data then
        return
    end
    local m = getmetatable(data)
    local pd = m.__protection__depth
    if pd > 1 then
        m.__protection__depth = pd - 1
    else
        m.__index, m.__newindex = m.__saved__index, m.__saved__newindex
        m.__protection__depth = 0
    end
end

local function protectall()
    for name, _ in next, registered do
        if name ~= "global" then
            protect(name)
        end
    end
end

local function unprotectall()
    for name, _ in next, registered do
        if name ~= "global" then
            unprotect(name)
        end
    end
end

namespaces.register     = register        -- register when defined
namespaces.private      = private         -- allocate and register if needed
namespaces.protect      = protect
namespaces.unprotect    = unprotect
namespaces.protectall   = protectall
namespaces.unprotectall = unprotectall

namespaces.private("namespaces") registered = { } register("global") -- unreachable

directives.register("system.protect", function(v)
    if v then
        protectall()
    else
        unprotectall()
    end
end)

directives.register("system.checkglobals", function(v)
    if v then
        report_system("enabling global namespace guard")
        protect("global")
    else
        report_system("disabling global namespace guard")
        unprotect("global")
    end
end)

-- dummy section (will go to luat-dum.lua)

--~ if not namespaces.private then
--~     -- somewhat protected
--~     local registered = { }
--~     function namespaces.private(name)
--~         local data = registered[name]
--~         if data then
--~             return data
--~         end
--~         local data = _G[name]
--~         if not data then
--~             data = { }
--~             _G[name] = data
--~         end
--~         registered[name] = data
--~         return data
--~     end
--~     function namespaces.protectall(list)
--~         for name, data in next, list or registered do
--~             setmetatable(data, { __newindex = function() print(string.format("table %s is protected",name)) end })
--~         end
--~     end
--~     namespaces.protectall { namespaces = namespaces }
--~ end

--~ directives.enable("system.checkglobals")

--~ namespaces.register("resolvers","trackers")
--~ namespaces.protect("resolvers")
--~ namespaces.protect("resolvers")
--~ namespaces.protect("resolvers")
--~ namespaces.unprotect("resolvers")
--~ namespaces.unprotect("resolvers")
--~ namespaces.unprotect("resolvers")
--~ namespaces.protect("trackers")

--~ resolvers.x = true
--~ resolvers.y = true
--~ trackers.a  = ""
--~ resolvers.z = true
--~ oeps        = { }

--~ resolvers = namespaces.private("resolvers")
--~ fonts = namespaces.private("fonts")
--~ directives.enable("system.protect")
--~ namespaces.protectall()
--~ resolvers.xx = { }
