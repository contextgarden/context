if not modules then modules = { } end modules ['mlib-lua'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is very preliminary code!

-- maybe we need mplib.model, but how with instances

local type, tostring, select, loadstring = type, tostring, select, loadstring
local find, match, gsub, gmatch = string.find, string.match, string.gsub, string.gmatch

local formatters   = string.formatters
local concat       = table.concat
local lpegmatch    = lpeg.match
local lpegpatterns = lpeg.patterns

local P, S, Ct, Cs, Cc, C = lpeg.P, lpeg.S, lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.C

local report_luarun  = logs.reporter("metapost","lua")
local report_message = logs.reporter("metapost")

local trace_luarun   = false  trackers.register("metapost.lua",function(v) trace_luarun = v end)
local trace_enabled  = true

local be_tolerant    = true   directives.register("metapost.lua.tolerant",function(v) be_tolerant = v end)

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
local f_integer   = formatters["%i"]
local f_pair      = formatters["(%.16f,%.16f)"]
local f_triplet   = formatters["(%.16f,%.16f,%.16f)"]
local f_quadruple = formatters["(%.16f,%.16f,%.16f,%.16f)"]

local function mpprint(...) -- we can optimize for n=1
    for i=1,select("#",...) do
        local value = select(i,...)
        if value ~= nil then
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

local r = P('%')  / "percent"
        + P('"')  / "dquote"
        + P('\n') / "crlf"
     -- + P(' ')  / "space"
local a = Cc("&")
local q = Cc('"')
local p = Cs(q * (r * a)^-1 * (a * r * (P(-1) + a) + P(1))^0 * q)

local function mpvprint(...) -- variable print
    for i=1,select("#",...) do
        local value = select(i,...)
        if value ~= nil then
            n = n + 1
            local t = type(value)
            if t == "number" then
                buffer[n] = f_numeric(value)
            elseif t == "string" then
                buffer[n] = lpegmatch(p,value)
            elseif t == "table" then
                local m = #t
                if m == 2 then
                    buffer[n] = f_pair(unpack(t))
                elseif m == 3 then
                    buffer[n] = f_triplet(unpack(t))
                elseif m == 4 then
                    buffer[n] = f_quadruple(unpack(t))
                else -- error
                    buffer[n] = ""
                end
            else -- boolean or whatever
                buffer[n] = tostring(value)
            end
        end
    end
end

mp.print  = mpprint
mp.vprint = mpvprint

-- We had this:
--
--   table.setmetatablecall(mp,function(t,k) mpprint(k) end)
--
-- but the next one is more interesting because we cannot use calls like:
--
--   lua.mp.somedefdname("foo")
--
-- which is due to expansion of somedefdname during suffix creation. So:
--
--   lua.mp("somedefdname","foo")

table.setmetatablecall(mp,function(t,k,...) return t[k](...) end)

function mp.boolean(b)
    n = n + 1
    buffer[n] = b and "true" or "false"
end

function mp.numeric(f)
    n = n + 1
    buffer[n] = f and f_numeric(f) or "0"
end

function mp.integer(i)
    n = n + 1
 -- buffer[n] = i and f_integer(i) or "0"
    buffer[n] = i or "0"
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

local mpnamedcolor = attributes.colors.mpnamedcolor

mp.NamedColor = function(str)
    mpprint(mpnamedcolor(str))
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

function mp.fprint(fmt,...)
    n = n + 1
    if not find(fmt,"%",1,true) then
        fmt = lpegmatch(replacer,fmt)
    end
    buffer[n] = formatters[fmt](...)
end

local function mpquoted(fmt,s,...)
    n = n + 1
    if s then
        if not find(fmt,"%",1,true) then
            fmt = lpegmatch(replacer,fmt)
        end
     -- buffer[n] = '"' .. formatters[fmt](s,...) .. '"'
        buffer[n] = lpegmatch(p,formatters[fmt](s,...))
    elseif fmt then
     -- buffer[n] = '"' .. fmt .. '"'
        buffer[n] = lpegmatch(p,fmt)
    else
        -- something is wrong
    end
end

mp.quoted = mpquoted

function mp.n(t)
    return type(t) == "table" and #t or 0
end

local whitespace = lpegpatterns.whitespace
local newline    = lpegpatterns.newline
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
                result = f_numeric(result)
            elseif t ~= "string" then
                result = tostring(result)
            end
            if trace then
                report_luarun("result: %s",result)
            end
            return result
        elseif trace then
            report_luarun("no result")
        end
    else
        report_luarun("no result, invalid code: %s",code)
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

-- texts:

local factor       = 65536*(7227/7200)
local textexts     = nil
local mptriplet    = mp.triplet
local nbdimensions = nodes.boxes.dimensions

function mp.tt_initialize(tt)
    textexts = tt
end

-- function mp.tt_wd(n)
--     local box = textexts and textexts[n]
--     mpprint(box and box.width/factor or 0)
-- end
-- function mp.tt_ht(n)
--     local box = textexts and textexts[n]
--     mpprint(box and box.height/factor or 0)
-- end
-- function mp.tt_dp(n)
--     local box = textexts and textexts[n]
--     mpprint(box and box.depth/factor or 0)
-- end

function mp.tt_dimensions(n)
    local box = textexts and textexts[n]
    if box then
        -- could be made faster with nuts but not critical
        mptriplet(box.width/factor,box.height/factor,box.depth/factor)
    else
        mptriplet(0,0,0)
    end
end

function mp.tb_dimensions(category,name)
    local w, h, d = nbdimensions(category,name)
    mptriplet(w/factor,h/factor,d/factor)
end

function mp.report(a,b)
    if b then
        report_message("%s : %s",a,b)
    elseif a then
        report_message("%s : %s","message",a)
    end
end

--

local hashes = { }

function mp.newhash()
    for i=1,#hashes+1 do
        if not hashes[i] then
            hashes[i] = { }
            mpprint(i)
            return
        end
    end
end

function mp.disposehash(n)
    hashes[n] = nil
end

function mp.inhash(n,key)
    local h = hashes[n]
    mpprint(h and h[key] and true or false)
end

function mp.tohash(n,key)
    local h = hashes[n]
    if h then
        h[key] = true
    end
end

local modes       = tex.modes
local systemmodes = tex.systemmodes

function mp.mode(s)
    mpprint(modes[s] and true or false)
end

function mp.systemmode(s)
    mpprint(systemmodes[s] and true or false)
end

-- for alan's nodes:

function mp.isarray(str)
     mpprint(find(str,"%d") and true or false)
end

function mp.prefix(str)
     mpquoted(match(str,"^(.-)[%d%[]") or str)
end

-- function mp.dimension(str)
--     local n = 0
--     for s in gmatch(str,"%[?%-?%d+%]?") do --todo: lpeg
--         n = n + 1
--     end
--     mpprint(n)
-- end

mp.dimension = lpeg.counter(P("[") * lpegpatterns.integer * P("]") + lpegpatterns.integer,mpprint)

-- faster and okay as we don't have many variables but probably only
-- basename makes sense and even then it's not called that often

-- local hash  = table.setmetatableindex(function(t,k)
--     local v = find(k,"%d") and true or false
--     t[k] = v
--     return v
-- end)
--
-- function mp.isarray(str)
--      mpprint(hash[str])
-- end
--
-- local hash  = table.setmetatableindex(function(t,k)
--     local v = '"' .. (match(k,"^(.-)%d") or k) .. '"'
--     t[k] = v
--     return v
-- end)
--
-- function mp.prefix(str)
--      mpprint(hash[str])
-- end

local getdimen  = tex.getdimen
local getcount  = tex.getcount
local gettoks   = tex.gettoks
local setdimen  = tex.setdimen
local setcount  = tex.setcount
local settoks   = tex.settoks

local mpprint   = mp.print
local mpquoted  = mp.quoted

local factor    = number.dimenfactors.bp

-- more helpers

function mp.getdimen(k)   mpprint (getdimen(k)*factor) end
function mp.getcount(k)   mpprint (getcount(k)) end
function mp.gettoks (k)   mpquoted(gettoks (k)) end
function mp.setdimen(k,v) setdimen(k,v/factor) end
function mp.setcount(k,v) setcount(k,v) end
function mp.settoks (k,v) settoks (k,v) end

-- def foo = lua.mp.foo ... enddef ; % loops due to foo in suffix

mp._get_dimen_ = mp.getdimen
mp._get_count_ = mp.getcount
mp._get_toks_  = mp.gettoks
mp._set_dimen_ = mp.setdimen
mp._set_count_ = mp.setcount
mp._set_toks_  = mp.settoks

-- position fun

do

    local mprint      = mp.print
    local fprint      = mp.fprint
    local qprint      = mp.quoted
    local getwhd      = job.positions.whd
    local getxy       = job.positions.xy
    local getposition = job.positions.position
    local getpage     = job.positions.page
    local getregion   = job.positions.region
    local getmacro    = tokens.getters.macro

    function mp.positionpath(name)
        local w, h, d = getwhd(name)
        if w then
            fprint("((%p,%p)--(%p,%p)--(%p,%p)--(%p,%p)--cycle)",0,-d,w,-d,w,h,0,h)
        else
            mprint("(origin--cycle)")
        end
    end

    function mp.positioncurve(name)
        local w, h, d = getwhd(name)
        if w then
            fprint("((%p,%p)..(%p,%p)..(%p,%p)..(%p,%p)..cycle)",0,-d,w,-d,w,h,0,h)
        else
            mprint("(origin--cycle)")
        end
    end

    function mp.positionbox(name)
        local p, x, y, w, h, d = getposition(name)
        if p then
            fprint("((%p,%p)--(%p,%p)--(%p,%p)--(%p,%p)--cycle)",x,y-d,x+w,y-d,x+w,y+h,x,y+h)
        else
            mprint("(%p,%p)",x,y)
        end
    end

    function mp.positionxy(name)
        local x, y = getxy(name)
        if x then
            fprint("(%p,%p)",x,y)
        else
            mprint("origin")
        end
    end

    function mp.positionpage(name)
        local p = getpage(name)
        if p then
            fprint("%p",p)
        else
            mprint("0")
        end
    end

    function mp.positionregion(name)
        local r = getregion(name)
        if r then
            qprint(r)
        else
            qprint("unknown")
        end
    end

    function mp.positionwhd(name)
        local w, h, d = getwhd(name)
        if w then
            fprint("(%p,%p,%p)",w,h,d)
        else
            mprint("(0,0,0)")
        end
    end

    function mp.positionpxy(name)
        local p, x, y = getposition(name)
        if p then
            fprint("(%p,%p,%p)",p,x,y)
        else
            mprint("(0,0,0)")
        end
    end

    function mp.positionanchor()
        qprint(getmacro("MPanchorid"))
    end

end

do

    local mprint   = mp.print
    local qprint   = mp.quoted
    local getmacro = tokens.getters.macro

    function mp.texvar(name)
        mprint(getmacro(metapost.namespace .. name))
    end

    function mp.texstr(name)
        qprint(getmacro(metapost.namespace .. name))
    end

end

do

    local mpvprint = mp.vprint

    local stores = { }

    function mp.newstore(name)
        stores[name] = { }
    end

    function mp.disposestore(name)
        stores[name] = nil
    end

    function mp.tostore(name,key,value)
        stores[name][key] = value
    end

    function mp.fromstore(name,key)
        mpvprint(stores[name][key]) -- type specific
    end

    interfaces.implement {
        name      = "getMPstored",
        arguments = { "string", "string" },
        actions   = function(name,key)
            context(stores[name][key])
        end
    }

end

do

    local mpprint  = mp.print
    local texmodes = tex.modes

    function mp.processingmode(s)
        mpprint(tostring(texmodes[s]))
    end

end
