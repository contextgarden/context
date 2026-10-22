if not modules then modules = { } end modules ['trac-inf'] = {
    version   = 1.001,
    comment   = "companion to trac-inf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- As we want to protect the global tables, we no longer store the timing
-- in the tables themselves but in a hidden timers table so that we don't
-- get warnings about assignments. This is more efficient than using rawset
-- and rawget.

local type, tonumber, select = type, tonumber, select
local format, lower, find = string.format, string.lower, string.find
local concat = table.concat
local clock  = os.gettimeofday or os.clock -- should go in environment

local setmetatableindex = table.setmetatableindex
local serialize         = table.serialize
local formatters        = string.formatters

statistics              = statistics or { }
local statistics        = statistics

statistics.enable       = true

statistics.threshold    = 0.01

local starttiming = statistics.starttiming
local stoptiming  = statistics.stoptiming
local elapsedtime = statistics.elapsedtime

starttiming(statistics)

-- general function .. we might split this module

local registered = { }
local statusinfo = { }
local n          = 0

function statistics.register(tag,fnc)
    if statistics.enable and type(fnc) == "function" then
        local rt = registered[tag] or (#statusinfo + 1)
        statusinfo[rt] = { tag, fnc }
        registered[tag] = rt
        if #tag > n then n = #tag end
    end
end

local report = logs.reporter("mkiv lua stats")

function statistics.show()
    if statistics.enable then
        -- this code will move
        local register = statistics.register
        register("used platform", function()
            return format("%s, type: %s, binary subtree: %s",
                os.platform or "unknown",os.type or "unknown", environment.texos or "unknown")
        end)
        register("used engine", function()
            return format("%s version: %s, functionality level: %s, banner: %s",
                environment.luatexengine,
                environment.luatexversion,
                environment.luatexfunctionality,
                lower(status.banner)
            )
        end)
        register("used hash slots", function()
            return format("%s of %s + %s", status.cs_count, status.hash_size,status.hash_extra)
        end)
        register("callbacks", statistics.callbacks)
        if JITSUPPORTED then
            local jitstatus = jit.status
            if jitstatus then
                local jitstatus = { jitstatus() }
                if jitstatus[1] then
                    register("luajit options", concat(jitstatus," ",2))
                end
            end
        end
        -- so far
        register("lua properties",function()
            local hash = 2^status.luatex_hashchars
            local mask = load([[τεχ = 1]]) and "utf" or "ascii"
            return format("engine: %s %s, used memory: %s, hash chars: min(%i,40), symbol mask: %s (%s)",
                jit and "luajit" or "lua", LUAVERSION, statistics.memused(), hash, mask, mask == "utf" and "τεχ" or "tex")
        end)
        register("runtime",statistics.runtime)
        logs.newline() -- initial newline
        for i=1,#statusinfo do
            local s = statusinfo[i]
            local r = s[2]()
            if r then
                report("%s: %s",s[1],r)
            end
        end
     -- logs.newline() -- final newline
        statistics.enable = false
    end
end

function statistics.memused() -- no math.round yet -)
    local round = math.round or math.floor
    return format("%s MB, ctx: %s MB, max: %s MB",
        round(collectgarbage("count")/1000),
        round(status.luastate_bytes/1000000),
        status.luastate_bytes_max and round(status.luastate_bytes_max/1000000) or "unknown"
    )
end

function statistics.formatruntime(runtime) -- indirect so it can be overloaded and
    return format("%s seconds", runtime)   -- indeed that happens in cure-uti.lua
end

function statistics.runtime()
    stoptiming(statistics)
    local runtime = lua.getruntime and lua.getruntime() or elapsedtime(statistics)
    return statistics.formatruntime(runtime)
end

local report = logs.reporter("system")

function statistics.timed(action,all)
    starttiming("run")
    action()
    stoptiming("run")
    local runtime = tonumber(elapsedtime("run"))
    if all then
        local alltime = tonumber(lua.getruntime and lua.getruntime() or elapsedtime(statistics))
        if alltime and alltime > 0 then
            report("total runtime: %0.3f seconds of %0.3f seconds",runtime,alltime)
            return
        end
    end
    report("total runtime: %0.3f seconds",runtime)
end

-- goodie

function statistics.tracefunction(base,tag,...)
    for i=1,select("#",...) do
        local name = select(i,...)
        local stat = { }
        local func = base[name]
        setmetatableindex(stat,function(t,k) t[k] = 0 return 0 end)
        base[name] = function(n,k,v) stat[k] = stat[k] + 1 return func(n,k,v) end
        statistics.register(formatters["%s.%s"](tag,name),function() return serialize(stat,"calls") end)
    end
end

function status.getreadstate()
    return {
        filename   = status.filename   or "?",
        linenumber = status.linenumber or 0,
        iocode     = status.inputid    or 0,
    }
end
