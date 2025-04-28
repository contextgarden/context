if not modules then modules = { } end modules ['util-sig'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, dofile = type, dofile
local format = string.format
local resultof = os.resultof

utilities         = utilities or {}
utilities.signals = utilities.signals or { }
local signals     = utilities.signals

-- return {
--     name    = "runner",
--     trigger = function(state,run)
--         print((state,run)
--     end
-- }

local loaded = table.setmetatableindex(function(t,signal)
    local signalled = false
    if type(signal) == "string" then
        local found = resolvers.findfile("util-sig-imp-"..signal..".lua") or ""
        if found ~= "" then
            local triggers = dofile(found)
            if triggers then
                signalled = triggers.trigger
            end
        end
        if type(signalled) ~= "function" then
            signalled = function(state,run)
                local c = format("mtxrun --script %s --state=%s --run=%i",signal,state,run)
                resultof(c)
            end
        end
    end
    t[signal] = signalled
    return signalled
end)

utilities.signals.version = 1.001

-- function signals.loadstate()
--     local cache = containers.define("system", "signals", version, true)
--     local data  = containers.read(cache,"presets")
--     if data then
--         return data
--     else
--         return { }
--     end
-- end

-- function signals.savestate(data)
--     local cache = containers.define("system", "signals", version, true)
--     containers.write(cache,"presets",data)
-- end

-- table={
--     servers = {
--         conbee = {
--             protocol = "deconz",
--             token    = "10 hex digits",
--             url      = "http://127.0.0.1",
--         },
--         hue = {
--             protocol = "hue",
--             token    = "uuid",
--             url      = "http://127.0.0.1",
--         }
--
--     },
--     signals = {
--         distribution = {
--             lamps = { 2, 3 },
--         },
--         runner = {
--             enabled = true,
--             lamps   = { 1, 2, 3, 4 },
--         },
--         testsuite={
--             lamps = { 1, 4 },
--         },
--         },
--     }
-- }

local configuration   = "ctxsignals.lua"
signals.configuration = configuration

function signals.loadstate()
    local name = resolvers.findfile(configuration)
    if name then
        local data = table.load(name)
        if data then
            return data, name
        end
    end
end

function signals.savestate(data)
    if data then
        local name = resolvers.findfile(configuration) or ""
        if name == "" then
            name = configuration
        end
        table.save(name,data)
        return name
    end
end

function signals.initialize(signal)
    if signal then
        local data = signals.loadstate()
        if not data then
            -- no signals defined
        elseif not data.signals or not data.signals[signal] then
            -- unknown signal
        elseif data.usage.enabled == false then
            return false
        elseif data.signals[signal].enabled == false then
            return false
        else
            return loaded[signal] or false
        end
    else
        return false
    end
end

signals.report = logs.reporter("signal")
