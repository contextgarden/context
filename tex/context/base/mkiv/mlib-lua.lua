if not modules then modules = { } end modules ['mlib-lua'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is very preliminary code!

-- maybe we need mplib.model, but how with instances

local type, tostring, tonumber, select, loadstring = type, tostring, tonumber, select, loadstring
local find, match, gsub, gmatch = string.find, string.match, string.gsub, string.gmatch
local concat, insert, remove = table.concat, table.insert, table.remove

local formatters   = string.formatters
local lpegmatch    = lpeg.match
local lpegpatterns = lpeg.patterns

local P, S, Ct, Cs, Cc, C = lpeg.P, lpeg.S, lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.C

local report_luarun  = logs.reporter("metapost","lua")
local report_script  = logs.reporter("metapost","script")
local report_message = logs.reporter("metapost")

local trace_luarun   = false  trackers.register("metapost.lua",function(v) trace_luarun = v end)

local be_tolerant    = true   directives.register("metapost.lua.tolerant", function(v) be_tolerant = v end)

local get, set, aux, scan = { }, { }, { }, { }

mp = mp or {  -- system namespace
    set  = set,
    get  = get,
    aux  = aux,
    scan = scan,
}

MP = MP or { -- user namespace
}

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
table.setmetatablecall(MP,function(t,k,...) return t[k](...) end)

do

    local currentmpx = nil
    local stack      = { }

    if CONTEXTLMTXMODE > 0 then

        local scan_next       = mplib.scan_next
        local scan_expression = mplib.scan_expression
        local scan_token      = mplib.scan_token
        local scan_symbol     = mplib.scan_symbol
        local scan_numeric    = mplib.scan_numeric
        local scan_integer    = mplib.scan_integer
        local scan_boolean    = mplib.scan_boolean
        local scan_string     = mplib.scan_string
        local scan_pair       = mplib.scan_pair
        local scan_color      = mplib.scan_color
        local scan_cmykcolor  = mplib.scan_cmykcolor
        local scan_transform  = mplib.scan_transform
        local scan_path       = mplib.scan_path
        local scan_pen        = mplib.scan_pen

        scan.next       = function(k)   return scan_next      (currentmpx,k)   end
        scan.expression = function(k)   return scan_expression(currentmpx,k)   end
        scan.token      = function(k)   return scan_token     (currentmpx,k)   end
        scan.symbol     = function(k,e) return scan_symbol    (currentmpx,k,e) end
        scan.numeric    = function()    return scan_numeric   (currentmpx)     end
        scan.number     = function()    return scan_numeric   (currentmpx)     end
        scan.integer    = function()    return scan_integer   (currentmpx)     end
        scan.boolean    = function()    return scan_boolean   (currentmpx)     end
        scan.string     = function()    return scan_string    (currentmpx)     end
        scan.pair       = function(t)   return scan_pair      (currentmpx,t)   end
        scan.color      = function(t)   return scan_color     (currentmpx,t)   end
        scan.cmykcolor  = function(t)   return scan_cmykcolor (currentmpx,t)   end
        scan.transform  = function(t)   return scan_transform (currentmpx,t)   end
        scan.path       = function(t)   return scan_path      (currentmpx,t)   end
        scan.pen        = function(t)   return scan_pen       (currentmpx,t)   end

    else

        local get_numeric = mplib.get_numeric
        local get_integer = mplib.get_integer
        local get_string  = mplib.get_string
        local get_boolean = mplib.get_boolean
        local get_path    = mplib.get_path
        local set_path    = mplib.set_path

        get.numeric = function(s)   return get_numeric(currentmpx,s)   end
        get.number  = function(s)   return get_numeric(currentmpx,s)   end
        get.integer = function(s)   return get_integer(currentmpx,s)   end
        get.string  = function(s)   return get_string (currentmpx,s)   end
        get.boolean = function(s)   return get_boolean(currentmpx,s)   end
        get.path    = function(s)   return get_path   (currentmpx,s)   end
        set.path    = function(s,t) return set_path   (currentmpx,s,t) end -- not working yet

    end

    function metapost.pushscriptrunner(mpx)
        insert(stack,mpx)
        currentmpx = mpx
    end

    function metapost.popscriptrunner()
        currentmpx = remove(stack,mpx)
    end

    function metapost.currentmpx()
        return currentmpx
    end

    local status = mplib.status

    function metapost.currentmpxstatus()
        return status and status(currentmpx) or 0
    end

end

do

    -- serializers

    local f_integer      = formatters["%i"]
    local f_numeric      = formatters["%F"]

    -- no %n as that can produce -e notation and that is not so nice for scaled butmaybe we
    -- should then switch between ... i.e. make a push/pop for the formatters here ... not now.

    local f_integer      = formatters["%i"]
    local f_numeric      = formatters["%F"]
    local f_pair         = formatters["(%F,%F)"]
    local f_ctrl         = formatters["(%F,%F) .. controls (%F,%F) and (%F,%F)"]
    local f_triplet      = formatters["(%F,%F,%F)"]
    local f_quadruple    = formatters["(%F,%F,%F,%F)"]
    local f_transform    = formatters["totransform(%F,%F,%F,%F,%F,%F)"]
    local f_pen          = formatters["(pencircle transformed totransform(%F,%F,%F,%F,%F,%F))"]

    local f_points       = formatters["%p"]
    local f_pair_pt      = formatters["(%p,%p)"]
    local f_ctrl_pt      = formatters["(%p,%p) .. controls (%p,%p) and (%p,%p)"]
    local f_triplet_pt   = formatters["(%p,%p,%p)"]
    local f_quadruple_pt = formatters["(%p,%p,%p,%p)"]

    local r = P('%')  / "percent"
            + P('"')  / "dquote"
            + P('\n') / "crlf"
         -- + P(' ')  / "space"
    local a = Cc("&")
    local q = Cc('"')
    local p = Cs(q * (r * a)^-1 * (a * r * (P(-1) + a) + P(1))^0 * q)

    mp.cleaned = function(s) return lpegmatch(p,s) or s end

    -- management

    -- sometimes we gain (e.g. .5 sec on the sync test)

    local cache = table.makeweak()

    local runscripts = { }
    local runnames   = { }
    local nofscripts = 0

    function metapost.registerscript(name,f)
        nofscripts = nofscripts + 1
        if f then
            runscripts[nofscripts] = f
            runnames[name] = nofscripts
        else
            runscripts[nofscripts] = name
        end
        return nofscripts
    end

    function metapost.scriptindex(name)
        return runnames[name] or 0
    end

    -- The gbuffer sharing and such is not really needed now but make a dent when
    -- we have a high volume of simpel calls (loops) so we keep it around for a
    -- while.

    local nesting = 0
    local runs    = 0
    local gbuffer = { }
    local buffer  = gbuffer
    local n       = 0

    local function mpdirect1(a)
        n = n + 1 buffer[n] = a
    end
    local function mpdirect2(a,b)
        n = n + 1 buffer[n] = a
        n = n + 1 buffer[n] = b
    end
    local function mpdirect3(a,b,c)
        n = n + 1 buffer[n] = a
        n = n + 1 buffer[n] = b
        n = n + 1 buffer[n] = c
    end
    local function mpdirect4(a,b,c,d)
        n = n + 1 buffer[n] = a
        n = n + 1 buffer[n] = b
        n = n + 1 buffer[n] = c
        n = n + 1 buffer[n] = d
    end
    local function mpdirect5(a,b,c,d,e)
        n = n + 1 buffer[n] = a
        n = n + 1 buffer[n] = b
        n = n + 1 buffer[n] = c
        n = n + 1 buffer[n] = d
        n = n + 1 buffer[n] = e
    end

    local function mpflush(separator)
        buffer[1] = concat(buffer,separator or "",1,n)
        n = 1
    end

    function metapost.runscript(code)
        nesting = nesting + 1
        runs    = runs + 1

        local index = type(code) == "number"
        local f
        local result

        if index then
            f = runscripts[code]
            if not f then
                report_luarun("%i: bad index: %s",nesting,code)
            elseif trace_luarun then
                report_luarun("%i: index: %i",nesting,code)
            end
        else
            if trace_luarun then
                report_luarun("%i: code: %s",nesting,code)
            end
            f = cache[code]
            if not f then
                f = loadstring("return " .. code)
                if f then
                    cache[code] = f
                elseif be_tolerant then
                    f = loadstring(code)
                    if f then
                        cache[code] = f
                    end
                end
            end
        end

        -- returning nil is more efficient and a signal not to scan in mp

        if f then

            local lbuffer, ln

            if nesting == 1 then
                buffer = gbuffer
                n      = 0
            else
                lbuffer = buffer
                ln      = n
                buffer  = { }
                n       = 0
            end

            result = f()

            if result then
                local t = type(result)
                if t == "number" then
                    result = f_numeric(result)
                elseif t == "table" then
                    result = concat(result) -- no spaces here
                else
                    result = tostring(result)
                end
                if trace_luarun then
                    report_luarun("%i: %s result: %s",nesting,t,result)
                end
            elseif n == 0 then
                result = ""
                if trace_luarun then
                    report_luarun("%i: no buffered result",nesting)
                end
            elseif n == 1 then
                result = buffer[1]
                if trace_luarun then
                    report_luarun("%i: 1 buffered result: %s",nesting,result)
                end
            else
                -- the space is why we sometimes have collectors
                if nesting == 1 then
                    result = concat(buffer," ",1,n)
                    if n > 500 or #result > 10000 then
                        gbuffer = { } -- newtable(20,0)
                        lbuffer = gbuffer
                    end
                else
                    result = concat(buffer," ")
                end
                if trace_luarun then
                    report_luarun("%i: %i buffered results: %s",nesting,n,result)
                end
            end

            if nesting == 1 then
                n = 0
            else
                buffer = lbuffer
                n      = ln
            end

        else
            report_luarun("%i: no result, invalid code: %s",nesting,code)
            result = ""
        end

        nesting = nesting - 1

        return result
    end

    function metapost.nofscriptruns()
        return runs
    end

    -- writers

    local function mpp(value)
        n = n + 1
        local t = type(value)
        if t == "number" then
            buffer[n] = f_numeric(value)
        elseif t == "string" then
            buffer[n] = value
        elseif t == "table" then
            if #t == 6 then
                buffer[n] = "totransform(" .. concat(value,",") .. ")"
            else
                buffer[n] = "(" .. concat(value,",") .. ")"
            end
        else -- boolean or whatever
            buffer[n] = tostring(value)
        end
    end

    local function mpprint(first,second,...)
        if second == nil then
            if first ~= nil then
                mpp(first)
            end
        else
            for i=1,select("#",first,second,...) do
                local value = (select(i,first,second,...))
                if value ~= nil then
                    mpp(value)
                end
            end
        end
    end

    local function mpp(value)
        n = n + 1
        local t = type(value)
        if t == "number" then
            buffer[n] = f_numeric(value)
        elseif t == "string" then
            buffer[n] = lpegmatch(p,value)
        elseif t == "table" then
            if #t > 4 then
                buffer[n] = ""
            else
                buffer[n] = "(" .. concat(value,",") .. ")"
            end
        else -- boolean or whatever
            buffer[n] = tostring(value)
        end
    end

    local function mpvprint(first,second,...) -- variable print
        if second == nil then
            if first ~= nil then
                mpp(first)
            end
        else
            for i=1,select("#",first,second,...) do
                local value = (select(i,first,second,...))
                if value ~= nil then
                    mpp(value)
                end
            end
        end
    end

    local function mpstring(value)
        n = n + 1
        buffer[n] = lpegmatch(p,value)
    end

    local function mpboolean(b)
        n = n + 1
        buffer[n] = b and "true" or "false"
    end

    local function mpnumeric(f)
        n = n + 1
        if not f or f == 0 then
            buffer[n] = "0"
        else
            buffer[n] = f_numeric(f)
        end
    end

    local function mpinteger(i)
        n = n + 1
     -- buffer[n] = i and f_integer(i) or "0"
        buffer[n] = i or "0"
    end

    local function mppoints(i)
        n = n + 1
        if not i or i == 0 then
            buffer[n] = "0pt"
        else
            buffer[n] = f_points(i)
        end
    end

    local function mppair(x,y)
        n = n + 1
        if type(x) == "table" then
            buffer[n] = f_pair(x[1],x[2])
        else
            buffer[n] = f_pair(x,y)
        end
    end

    local function mppairpoints(x,y)
        n = n + 1
        if type(x) == "table" then
            buffer[n] = f_pair_pt(x[1],x[2])
        else
            buffer[n] = f_pair_pt(x,y)
        end
    end

    local function mptriplet(x,y,z)
        n = n + 1
        if type(x) == "table" then
            buffer[n] = f_triplet(x[1],x[2],x[3])
        else
            buffer[n] = f_triplet(x,y,z)
        end
    end

    local function mptripletpoints(x,y,z)
        n = n + 1
        if type(x) == "table" then
            buffer[n] = f_triplet_pt(x[1],x[2],x[3])
        else
            buffer[n] = f_triplet_pt(x,y,z)
        end
    end

    local function mpquadruple(w,x,y,z)
        n = n + 1
        if type(w) == "table" then
            buffer[n] = f_quadruple(w[1],w[2],w[3],w[4])
        else
            buffer[n] = f_quadruple(w,x,y,z)
        end
    end

    local function mpquadruplepoints(w,x,y,z)
        n = n + 1
        if type(w) == "table" then
            buffer[n] = f_quadruple_pt(w[1],w[2],w[3],w[4])
        else
            buffer[n] = f_quadruple_pt(w,x,y,z)
        end
    end

    local function mptransform(x,y,xx,xy,yx,yy)
        n = n + 1
        if type(x) == "table" then
            buffer[n] = f_transform(x[1],x[2],x[3],x[4],x[5],x[6])
        else
            buffer[n] = f_transform(x,y,xx,xy,yx,yy)
        end
    end

    local function mpcolor(c,m,y,k)
        n = n + 1
        if type(c) == "table" then
            local l = #c
            if l == 4 then
                buffer[n] = f_quadruple(c[1],c[2],c[3],c[4])
            elseif l == 3 then
                buffer[n] = f_triplet(c[1],c[2],c[3])
            else
                buffer[n] = f_numeric(c[1])
            end
        else
            if k then
                buffer[n] = f_quadruple(c,m,y,k)
            elseif y then
                buffer[n] = f_triplet(c,m,y)
            else
                buffer[n] = f_numeric(c)
            end
        end
    end

    -- we have three kind of connectors:
    --
    -- .. ... -- (true)

    local function mp_path(f2,f6,t,connector,cycle)
        if type(t) == "table" then
            local tn = #t
            if tn == 1 then
                local t1 = t[1]
                n = n + 1
                if t.pen then
                    buffer[n] = f_pen(unpack(t1))
                else
                    buffer[n] = f2(t1[1],t1[2])
                end
            elseif tn > 0 then
                if connector == true or connector == nil then
                    connector = ".."
                elseif connector == false then
                    connector = "--"
                end
                if cycle == nil then
                    cycle = t.cycle
                    if cycle == nil then
                        cycle = true
                    end
                end
                local six      = connector == ".." -- otherwise we use whatever gets asked for
                local controls = connector         -- whatever
                local a = t[1]
                local b = t[2]
                n = n + 1
                buffer[n] = "("
                n = n + 1
                if six and #a == 6 and #b == 6 then
                    buffer[n] = f6(a[1],a[2],a[5],a[6],b[3],b[4])
                    controls  = ".."
                else
                    buffer[n] = f2(a[1],a[2])
                    controls  = connector
                end
                for i=2,tn-1 do
                    a = b
                    b = t[i+1]
                    n = n + 1
                    buffer[n] = connector
                    n = n + 1
                    if six and #a == 6 and #b == 6 then
                        buffer[n] = f6(a[1],a[2],a[5],a[6],b[3],b[4])
                        controls  = ".."
                    else
                        buffer[n] = f2(a[1],a[2])
                        controls  = connector
                    end
                end
                n = n + 1
                buffer[n] = connector
                a = b
                b = t[1]
                n = n + 1
                if cycle then
                    if six and #a == 6 and #b == 6 then
                        buffer[n] = f6(a[1],a[2],a[5],a[6],b[3],b[4])
                        controls  = ".."
                    else
                        buffer[n] = f2(a[1],a[2])
                        controls  = connector
                    end
                    n = n + 1
                    buffer[n] = connector
                    n = n + 1
                    buffer[n] = "cycle"
                else
                    buffer[n] = f2(a[1],a[2])
                end
                n = n + 1
                buffer[n] = ")"
            end
        end
    end

    local function mppath(...)
        mp_path(f_pair,f_ctrl,...)
    end

    local function mppathpoints(...)
        mp_path(f_pair_pt,f_ctrl_pt,...)
    end

    local function mpsize(t)
        n = n + 1
        buffer[n] = type(t) == "table" and f_numeric(#t) or "0"
    end

    local replacer = lpeg.replacer("@","%%")

    local function mpfprint(fmt,...)
        n = n + 1
        if not find(fmt,"%",1,true) then
            fmt = lpegmatch(replacer,fmt)
        end
        buffer[n] = formatters[fmt](...)
    end

    local function mpquoted(fmt,s,...)
        if s then
            n = n + 1
            if not find(fmt,"%",1,true) then
                fmt = lpegmatch(replacer,fmt)
            end
         -- buffer[n] = '"' .. formatters[fmt](s,...) .. '"'
            buffer[n] = lpegmatch(p,formatters[fmt](s,...))
        elseif fmt then
            n = n + 1
         -- buffer[n] = '"' .. fmt .. '"'
            buffer[n] = lpegmatch(p,fmt)
        else
            -- something is wrong
        end
    end

    aux.direct          = mpdirect1
    aux.direct1         = mpdirect1
    aux.direct2         = mpdirect2
    aux.direct3         = mpdirect3
    aux.direct4         = mpdirect4
    aux.flush           = mpflush

    aux.print           = mpprint
    aux.vprint          = mpvprint
    aux.boolean         = mpboolean
    aux.string          = mpstring
    aux.numeric         = mpnumeric
    aux.number          = mpnumeric
    aux.integer         = mpinteger
    aux.points          = mppoints
    aux.pair            = mppair
    aux.pairpoints      = mppairpoints
    aux.triplet         = mptriplet
    aux.tripletpoints   = mptripletpoints
    aux.quadruple       = mpquadruple
    aux.quadruplepoints = mpquadruplepoints
    aux.path            = mppath
    aux.pathpoints      = mppathpoints
    aux.size            = mpsize
    aux.fprint          = mpfprint
    aux.quoted          = mpquoted
    aux.transform       = mptransform
    aux.color           = mpcolor

    -- for the moment

    local function mpdraw(lines,list) -- n * 4
        if list then
            local c = #lines
            for i=1,c do
                local ci = lines[i]
                local ni = #ci
                n = n + 1 buffer[n] = i < c and "d(" or "D("
                for j=1,ni,2 do
                    local l = j + 1
                    n = n + 1 buffer[n] = ci[j]
                    n = n + 1 buffer[n] = ","
                    n = n + 1 buffer[n] = ci[l]
                    n = n + 1 buffer[n] = l < ni and ")--(" or ");"
                end
            end
        else
            local l = #lines
            local m = l - 4
            for i=1,l,4 do
                n = n + 1 buffer[n] = i < m and "d(" or "D("
                n = n + 1 buffer[n] = lines[i]
                n = n + 1 buffer[n] = ","
                n = n + 1 buffer[n] = lines[i+1]
                n = n + 1 buffer[n] = ")--("
                n = n + 1 buffer[n] = lines[i+2]
                n = n + 1 buffer[n] = ","
                n = n + 1 buffer[n] = lines[i+3]
                n = n + 1 buffer[n] = ");"
            end
        end
    end

    local function mpfill(lines,list)
        if list then
            local c = #lines
            for i=1,c do
                local ci = lines[i]
                local ni = #ci
                n = n + 1 buffer[n] = i < c and "f(" or "F("
                for j=1,ni,2 do
                    local l = j + 1
                    n = n + 1 buffer[n] = ci[j]
                    n = n + 1 buffer[n] = ","
                    n = n + 1 buffer[n] = ci[l]
                    n = n + 1 buffer[n] = l < ni and ")--(" or ")--C;"
                end
            end
        else
            local l = #lines
            local m = l - 4
            for i=1,l,4 do
                n = n + 1 buffer[n] = i < m and "f(" or "F("
                n = n + 1 buffer[n] = lines[i]
                n = n + 1 buffer[n] = ","
                n = n + 1 buffer[n] = lines[i+1]
                n = n + 1 buffer[n] = ")--("
                n = n + 1 buffer[n] = lines[i+2]
                n = n + 1 buffer[n] = ","
                n = n + 1 buffer[n] = lines[i+3]
                n = n + 1 buffer[n] = ")--C;"
            end
        end
    end

    aux.draw = mpdraw
    aux.fill = mpfill

    for k, v in next, aux do mp[k] = v end

end

do

    -- Another experimental feature:

    local mpnumeric   = mp.numeric
    local scanstring  = scan.string
    local scriptindex = metapost.scriptindex

    function mp.mf_script_index(name)
        local index = scriptindex(name)
     -- report_script("method %i, name %a, index %i",1,name,index)
        mpnumeric(index)
    end

    -- once bootstrapped ... (needs pushed mpx instances)

    metapost.registerscript("scriptindex",function()
        local name  = scanstring()
        local index = scriptindex(name)
     -- report_script("method %i, name %a, index %i",2,name,index)
        mpnumeric(index)
    end)

end

-- the next will move to mlib-lmp.lua

do

    local mpnamedcolor = attributes.colors.mpnamedcolor
    local mpprint      = aux.print
    local scanstring   = scan.string

    mp.mf_named_color = function(str)
        mpprint(mpnamedcolor(str))
    end

    metapost.registerscript("namedcolor",function()
        mpprint(mpnamedcolor(scanstring()))
-- test: return mpnamedcolor(scanstring())
    end)

end

function mp.n(t) -- used ?
    return type(t) == "table" and #t or 0
end

do

    -- experiment: names can change

    local mppath     = aux.path
    local mpsize     = aux.size

    local whitespace = lpegpatterns.whitespace
    local newline    = lpegpatterns.newline
    local setsep     = newline^2
    local comment    = (S("#%") + P("--")) * (1-newline)^0 * (whitespace - setsep)^0
    local value      = (1-whitespace)^1 / tonumber
    local entry      = Ct( value * whitespace * value)
    local set        = Ct((entry * (whitespace-setsep)^0 * comment^0)^1)
    local series     = Ct((set * whitespace^0)^1)

    local pattern    = whitespace^0 * series

    local datasets   = { }
    mp.datasets      = datasets

    function mp.dataset(str)
        return lpegmatch(pattern,str)
    end

    function datasets.load(tag,filename)
        if not filename then
            tag, filename = file.basename(tag), tag
        end
        local data = lpegmatch(pattern,io.loaddata(filename) or "")
        datasets[tag] = {
            data = data,
            line = function(n) mppath(data[n or 1]) end,
            size = function()  mpsize(data)         end,
        }
    end

    table.setmetatablecall(datasets,function(t,k,f,...)
        local d = datasets[k]
        local t = type(d)
        if t == "table" then
            d = d[f]
            if type(d) == "function" then
                d(...)
            else
                mpvprint(...)
            end
        elseif t == "function" then
            d(f,...)
        end
    end)

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

-- texts:

do

    local mptriplet    = mp.triplet

    local bpfactor     = number.dimenfactors.bp
    local textexts     = nil
    local mptriplet    = mp.triplet
    local nbdimensions = nodes.boxes.dimensions

    function mp.mf_tt_initialize(tt)
        textexts = tt
    end

    function mp.mf_tt_dimensions(n)
        local box = textexts and textexts[n]
        if box then
            -- could be made faster with nuts but not critical
            mptriplet(box.width*bpfactor,box.height*bpfactor,box.depth*bpfactor)
        else
            mptriplet(0,0,0)
        end
    end

    function mp.mf_tb_dimensions(category,name)
        local w, h, d = nbdimensions(category,name)
        mptriplet(w*bpfactor,h*bpfactor,d*bpfactor)
    end

    function mp.report(a,b,c,...)
        if c then
            report_message("%s : %s",a,formatters[(gsub(b,"@","%%"))](c,...))
        elseif b then
            report_message("%s : %s",a,b)
        elseif a then
            report_message("%s : %s","message",a)
        end
    end

end

do

    local mpprint     = aux.print
    local modes       = tex.modes
    local systemmodes = tex.systemmodes

    function mp.mode(s)
        mpprint(modes[s] and true or false)
    end

    function mp.systemmode(s)
        mpprint(systemmodes[s] and true or false)
    end

    mp.processingmode = mp.mode

end

-- for alan's nodes:

do

    local mpprint  = aux.print
    local mpquoted = aux.quoted

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

end

do

    local getmacro  = tex.getmacro
    local getdimen  = tex.getdimen
    local getcount  = tex.getcount
    local gettoks   = tex.gettoks
    local setmacro  = tex.setmacro
    local setdimen  = tex.setdimen
    local setcount  = tex.setcount
    local settoks   = tex.settoks

    local mpprint   = mp.print
    local mpquoted  = mp.quoted

    local bpfactor  = number.dimenfactors.bp

    -- more helpers

    local function getmacro(k)   mpprint (getmacro(k)) end
    local function getdimen(k)   mpprint (getdimen(k)*bpfactor) end
    local function getcount(k)   mpprint (getcount(k)) end
    local function gettoks (k)   mpquoted(gettoks (k)) end

    local function setmacro(k,v) setmacro(k,v) end
    local function setdimen(k,v) setdimen(k,v/bpfactor) end
    local function setcount(k,v) setcount(k,v) end
    local function settoks (k,v) settoks (k,v) end

    -- def foo = lua.mp.foo ... enddef ; % loops due to foo in suffix

    mp._get_macro_ = getmacro   mp.getmacro = getmacro
    mp._get_dimen_ = getdimen   mp.getdimen = getdimen
    mp._get_count_ = getcount   mp.getcount = getcount
    mp._get_toks_  = gettoks    mp.gettoks  = gettoks

    mp._set_macro_ = setmacro   mp.setmacro = setmacro
    mp._set_dimen_ = setdimen   mp.setdimen = setdimen
    mp._set_count_ = setcount   mp.setcount = setcount
    mp._set_toks_  = settoks    mp.settoks  = settoks

end

-- position fun

do

    local mprint       = mp.print
    local fprint       = mp.fprint
    local qprint       = mp.quoted
    local jobpositions = job.positions
    local getwhd       = jobpositions.whd
    local getxy        = jobpositions.xy
    local getposition  = jobpositions.position
    local getpage      = jobpositions.page
    local getregion    = jobpositions.region
    local getmacro     = tokens.getters.macro

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
        fprint("%i",getpage(name) or 0)
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

    local mppair = mp.pair

    function mp.textextanchor(s)
        local x, y = match(s,"tx_anchor=(%S+) (%S+)") -- todo: make an lpeg
        if x and y then
            x = tonumber(x)
            y = tonumber(y)
        end
        mppair(x or 0,y or 0)
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

    local mpprint  = aux.print
    local mpvprint = aux.vprint

    local hashes   = { }

    function mp.newhash(name)
        if name then
            hashes[name] = { }
        else
            for i=1,#hashes+1 do
                if not hashes[i] then
                    hashes[i] = { }
                    mpvprint(i)
                    return
                end
            end
        end
    end

    function mp.disposehash(n)
        if tonumber(n) then
            hashes[n] = false
        else
            hashes[n] = nil
        end
    end

    function mp.inhash(n,key)
        local h = hashes[n]
        mpvprint(h and h[key] and true or false)
    end

    function mp.tohash(n,key,value)
        local h = hashes[n]
        if h then
            if value == nil then
                h[key] = true
            else
                h[key] = value
            end
        end
    end

    function mp.fromhash(n,key)
        local h = hashes[n]
        mpvprint(h and h[key] or false)
    end

    interfaces.implement {
        name      = "MPfromhash",
        arguments = "2 strings",
        actions   = function(name,key)
            local h = hashes[name] or hashes[tonumber(name)]
            if h then
                local v = h[key] or h[tonumber(key)]
                if v then
                    context(v)
                end
            end
        end
    }

end

do

    -- a bit overkill: just a find(str,"mf_object=") can be enough
    --
    -- todo : share with mlib-pps.lua metapost,isobject

    local mpboolean = aux.boolean

    local p1        = P("mf_object=")
    local p2        = lpegpatterns.eol * p1
    local pattern   = (1-p2)^0 * p2 + p1

    function mp.isobject(str)
        mpboolean(pattern and str ~= "" and lpegmatch(pattern,str))
    end

end

function mp.flatten(t)
    local tn = #t

    local t1 = t[1]
    local t2 = t[2]
    local t3 = t[3]
    local t4 = t[4]

    for i=1,tn-5,2 do
        local t5 = t[i+4]
        local t6 = t[i+5]
        if t1 == t3 and t3 == t5 and ((t2 <= t4 and t4 <= t6) or (t6 <= t4 and t4 <= t2)) then
            t[i+3] = t2
            t4     = t2
            t[i]   = false
            t[i+1] = false
        elseif t2 == t4 and t4 == t6 and ((t1 <= t3 and t3 <= t5) or (t5 <= t3 and t3 <= t1)) then
            t[i+2] = t1
            t3     = t1
            t[i]   = false
            t[i+1] = false
        end
        t1 = t3
        t2 = t4
        t3 = t5
        t4 = t6
    end

    -- remove duplicates

    local t1 = t[1]
    local t2 = t[2]
    for i=1,tn-2,2 do
        local t3 = t[i+2]
        local t4 = t[i+3]
        if t1 == t3 and t2 == t4 then
            t[i]   = false
            t[i+1] = false
        end
        t1 = t3
        t2 = t4
    end

    -- move coordinates

    local m = 0
    for i=1,tn,2 do
        if t[i] then
            m = m + 1 t[m] = t[i]
            m = m + 1 t[m] = t[i+1]
        end
    end

    -- prune the table (not gc'd)

    for i=tn,m+1,-1 do
        t[i] = nil
    end

    -- safeguard so that we have at least one segment

    if m == 2 then
        t[3] = t[1]
        t[4] = t[2]
    end

end

