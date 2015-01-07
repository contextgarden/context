if not modules then modules = { } end modules ['mlib-pdf'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is very preliminary code!

-- maybe we need mplib.model, but how with instances

local type, tostring, select, loadstring = type, tostring, select, loadstring
local find, gsub = string.find, string.gsub

local formatters = string.formatters
local concat     = table.concat
local lpegmatch  = lpeg.match

local P, S, Ct = lpeg.P, lpeg.S, lpeg.Ct

local report_luarun = logs.reporter("metapost","lua")

local trace_luarun  = false  trackers.register("metapost.lua",function(v) trace_luarun = v end)
local trace_enabled = true

local be_tolerant   = true   directives.register("metapost.lua.tolerant",function(v) be_tolerant = v end)

mp = mp or { } -- system namespace
MP = MP or { } -- user namespace

local buffer, n, max = { }, 0, 10 -- we reuse upto max

function mp._f_()
    if trace_enabled and trace_luarun then
        local result = concat(buffer," ",1,n)
        if n > max then
            buffer = { }
        end
        n = 0
        report_luarun("data: %s",result)
        return result
    else
        if n == 0 then
            return ""
        end
        local result
        if n == 1 then
            result = buffer[1]
        else
            result = concat(buffer," ",1,n)
        end
        if n > max then
            buffer = { }
        end
        n = 0
        return result
    end
end

local f_code      = formatters["%s return mp._f_()"]

local f_numeric   = formatters["%.16f"]
local f_pair      = formatters["(%.16f,%.16f)"]
local f_triplet   = formatters["(%.16f,%.16f,%.16f)"]
local f_quadruple = formatters["(%.16f,%.16f,%.16f,%.16f)"]

function mp.print(...)
    for i=1,select("#",...) do
        local value = select(i,...)
        if value then
            n = n + 1
            local t = type(value)
            if t == "number" then
                buffer[n] = f_numeric(value)
            elseif t == "string" then
                buffer[n] = value
            elseif t == "table" then
                buffer[n] = "(" .. concat(value,",") .. ")"
            else -- boolean or whatever
                buffer[n] = tostring(value)
            end
        end
    end
end

function mp.numeric(n)
    n = n + 1
    buffer[n] = n and f_numeric(n) or "0"
end

function mp.pair(x,y)
    n = n + 1
    if type(x) == "table" then
        buffer[n] = f_pair(x[1],x[2])
    else
        buffer[n] = f_pair(x,y)
    end
end

function mp.triplet(x,y,z)
    n = n + 1
    if type(x) == "table" then
        buffer[n] = f_triplet(x[1],x[2],x[3])
    else
        buffer[n] = f_triplet(x,y,z)
    end
end

function mp.quadruple(w,x,y,z)
    n = n + 1
    if type(w) == "table" then
        buffer[n] = f_quadruple(w[1],w[2],w[3],w[4])
    else
        buffer[n] = f_quadruple(w,x,y,z)
    end
end

function mp.path(t,connector,cycle)
    if type(t) == "table" then
        local tn = #t
        if tn > 0 then
            if connector == true then
                connector = "--"
                cycle     = true
            elseif not connector then
                connector = "--"
            end
            local ti = t[1]
            n = n + 1 ; buffer[n] = f_pair(ti[1],ti[2])
            for i=2,tn do
                local ti = t[i]
                n = n + 1 ; buffer[n] = connector
                n = n + 1 ; buffer[n] = f_pair(ti[1],ti[2])
            end
            if cycle then
                n = n + 1 ; buffer[n] = connector
                n = n + 1 ; buffer[n] = "cycle"
            end
        end
    end
end

function mp.size(t)
    n = n + 1
    buffer[n] = type(t) == "table" and f_numeric(#t) or "0"
end

-- experiment: names can change

local datasets = { }
mp.datasets    = datasets

function datasets.load(tag,filename)
    if not filename then
        tag, filename = file.basename(tag), tag
    end
    local data = mp.dataset(io.loaddata(filename) or "")
    datasets[tag] = {
        Data = data,
        Line = function(n) mp.path(data[n or 1]) end,
        Size = function()  mp.size(data)         end,
    }
end

--

local replacer = lpeg.replacer("@","%%")

function mp.format(fmt,...)
    n = n + 1
    if not find(fmt,"%%") then
        fmt = lpegmatch(replacer,fmt)
    end
    buffer[n] = formatters[fmt](...)
end

function mp.quoted(fmt,s,...)
    n = n + 1
    if s then
        if not find(fmt,"%%") then
            fmt = lpegmatch(replacer,fmt)
        end
        buffer[n] = '"' .. formatters[fmt](s,...) .. '"'
    else
        buffer[n] = '"' .. fmt .. '"'
    end
end

function mp.n(t)
    return type(t) == "table" and #t or 0
end

local whitespace = lpeg.patterns.whitespace
local newline    = lpeg.patterns.newline
local setsep     = newline^2
local comment    = (S("#%") + P("--")) * (1-newline)^0 * (whitespace - setsep)^0
local value      = (1-whitespace)^1 / tonumber
local entry      = Ct( value * whitespace * value)
local set        = Ct((entry * (whitespace-setsep)^0 * comment^0)^1)
local series     = Ct((set * whitespace^0)^1)

local pattern    = whitespace^0 * series

function mp.dataset(str)
    return lpegmatch(pattern,str)
end

-- \startluacode
--     local str = [[
--         10 20 20 20
--         30 40 40 60
--         50 10
--
--         10 10 20 30
--         30 50 40 50
--         50 20 -- the last one
--
--         10 20 % comment
--         20 10
--         30 40 # comment
--         40 20
--         50 10
--     ]]
--
--     MP.myset = mp.dataset(str)
--
--     inspect(MP.myset)
-- \stopluacode
--
-- \startMPpage
--     color c[] ; c[1] := red ; c[2] := green ; c[3] := blue ;
--     for i=1 upto lua("mp.print(mp.n(MP.myset))") :
--         draw lua("mp.path(MP.myset[" & decimal i & "])") withcolor c[i] ;
--     endfor ;
-- \stopMPpage

-- function metapost.runscript(code)
--     local f = loadstring(f_code(code))
--     if f then
--         local result = f()
--         if result then
--             local t = type(result)
--             if t == "number" then
--                 return f_numeric(result)
--             elseif t == "string" then
--                 return result
--             else
--                 return tostring(result)
--             end
--         end
--     end
--     return ""
-- end

local cache, n = { }, 0 -- todo: when > n then reset cache or make weak

function metapost.runscript(code)
    local trace = trace_enabled and trace_luarun
    if trace then
        report_luarun("code: %s",code)
    end
    local f
    if n > 100 then
        cache = nil -- forget about caching
        f = loadstring(f_code(code))
        if not f and be_tolerant then
            f = loadstring(code)
        end
    else
        f = cache[code]
        if not f then
            f = loadstring(f_code(code))
            if f then
                n = n + 1
                cache[code] = f
            elseif be_tolerant then
                f = loadstring(code)
                if f then
                    n = n + 1
                    cache[code] = f
                end
            end
        end
    end
    if f then
        local result = f()
        if result then
            local t = type(result)
            if t == "number" then
                t = f_numeric(result)
            elseif t == "string" then
                t = result
            else
                t = tostring(result)
            end
            if trace then
                report_luarun("result: %s",code)
            end
            return t
        elseif trace then
            report_luarun("no result")
        end
    else
        report_luarun("no result, invalid code")
    end
    return ""
end

-- function metapost.initializescriptrunner(mpx)
--     mp.numeric = function(s) return mpx:get_numeric(s) end
--     mp.string  = function(s) return mpx:get_string (s) end
--     mp.boolean = function(s) return mpx:get_boolean(s) end
--     mp.number  = mp.numeric
-- end

local get_numeric = mplib.get_numeric
local get_string  = mplib.get_string
local get_boolean = mplib.get_boolean
local get_number  = get_numeric

-- function metapost.initializescriptrunner(mpx)
--     mp.numeric = function(s) return get_numeric(mpx,s) end
--     mp.string  = function(s) return get_string (mpx,s) end
--     mp.boolean = function(s) return get_boolean(mpx,s) end
--     mp.number  = mp.numeric
-- end

local currentmpx = nil

local get = { }
mp.get    = get

get.numeric = function(s) return get_numeric(currentmpx,s) end
get.string  = function(s) return get_string (currentmpx,s) end
get.boolean = function(s) return get_boolean(currentmpx,s) end
get.number  = mp.numeric

function metapost.initializescriptrunner(mpx,trialrun)
    currentmpx = mpx
    if trace_luarun then
        report_luarun("type of run: %s", trialrun and "trial" or "final")
    end
 -- trace_enabled = not trialrun blocks too much
end
