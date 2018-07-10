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
local concat, insert, remove = table.concat, table.insert, table.remove

local formatters   = string.formatters
local lpegmatch    = lpeg.match
local lpegpatterns = lpeg.patterns

local P, S, Ct, Cs, Cc, C = lpeg.P, lpeg.S, lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.C

local report_luarun  = logs.reporter("metapost","lua")
local report_message = logs.reporter("metapost")

local trace_luarun   = false  trackers.register("metapost.lua",function(v) trace_luarun = v end)
local trace_enabled  = true

local be_tolerant    = true   directives.register("metapost.lua.tolerant", function(v) be_tolerant = v end)

local get, set, aux = { }, { }, { }

mp = mp or {  -- system namespace
    set = set,
    get = get,
    aux = aux,
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

    local currentmpx  = nil
    local stack       = { }

    local get_numeric = mplib.get_numeric
    local get_string  = mplib.get_string
    local get_boolean = mplib.get_boolean
    local get_path    = mplib.get_path
    local set_path    = mplib.set_path

    get.numeric = function(s) return get_numeric(currentmpx,s) end
    get.string  = function(s) return get_string (currentmpx,s) end
    get.boolean = function(s) return get_boolean(currentmpx,s) end
    get.path    = function(s) return get_path   (currentmpx,s) end
    get.number  = function(s) return get_numeric(currentmpx,s) end

    set.path    = function(s,t) return set_path(currentmpx,s,t) end -- not working yet

    function metapost.pushscriptrunner(mpx)
        insert(stack,mpx)
        currentmpx = mpx
    end

    function metapost.popscriptrunner()
        currentmpx = remove(stack,mpx)
    end

end

do

    local buffer  = { }
    local n       = 0
    local max     = 20 -- we reuse upto max
    local nesting = 0
    local runs    = 0

    local function _f_()
        if trace_enabled and trace_luarun then
            local result = concat(buffer," ",1,n)
            if n > max then
                buffer = { }
            end
            n = 0
            report_luarun("%i: data: %s",nesting,result)
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

    mp._f_    = _f_ -- convenient to have it in a top module
    aux.flush = _f_

    local f_code         = formatters["%s return mp._f_()"]

    local f_integer      = formatters["%i"]
 -- local f_numeric      = formatters["%.16f"]
 -- local f_pair         = formatters["(%.16f,%.16f)"]
 -- local f_triplet      = formatters["(%.16f,%.16f,%.16f)"]
 -- local f_quadruple    = formatters["(%.16f,%.16f,%.16f,%.16f)"]

    -- %N

    local f_numeric      = formatters["%n"]
    local f_pair         = formatters["(%n,%n)"]
    local f_ctrl         = formatters["(%n,%n) .. controls (%n,%n) and (%n,%n)"]
    local f_triplet      = formatters["(%n,%n,%n)"]
    local f_quadruple    = formatters["(%n,%n,%n,%n)"]

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

    local function mpboolean(b)
        n = n + 1
        buffer[n] = b and "true" or "false"
    end

    local function mpnumeric(f)
        n = n + 1
        buffer[n] = f and f_numeric(f) or "0"
    end

    local function mpinteger(i)
        n = n + 1
     -- buffer[n] = i and f_integer(i) or "0"
        buffer[n] = i or "0"
    end

    local function mppoints(i)
        n = n + 1
        buffer[n] = i and f_points(i) or "0pt"
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

 -- local function mp_path(f2,f6,t,connector,cycle)
 --     if type(t) == "table" then
 --         local tn = #t
 --         if tn > 0 then
 --             if connector == true then
 --                 connector = "--"
 --                 cycle     = true
 --             elseif not connector then
 --                 connector = "--"
 --             end
 --             local ti = t[1]
 --             n = n + 1 ;
 --             if #ti == 6 then
 --                 local tn = t[2] or t[1]
 --                 buffer[n] = f6(ti[1],ti[2],ti[5],ti[6],tn[3],tn[4])
 --             else
 --                 buffer[n] = f2(ti[1],ti[2])
 --             end
 --             for i=2,tn do
 --                 local ti = t[i]
 --                 n = n + 1 ; buffer[n] = connector
 --                 n = n + 1 ;
 --                 if #ti == 6 and (i < tn or cycle) then
 --                     local tn = t[i+1] or t[1]
 --                     buffer[n] = f6(ti[1],ti[2],ti[5],ti[6],tn[3],tn[4])
 --                 else
 --                     buffer[n] = f2(ti[1],ti[2])
 --                 end
 --             end
 --             if cycle then
 --                 n = n + 1 ; buffer[n] = connector
 --                 n = n + 1 ; buffer[n] = "cycle"
 --             end
 --         end
 --     end
 -- end

    local function mp_path(f2,f6,t,connector,cycle)
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
                n = n + 1 ;
                if #ti == 6 then
                    buffer[n] = f6(ti[1],ti[2],ti[3],ti[4],ti[5],ti[6])
                else
                    buffer[n] = f2(ti[1],ti[2])
                end
                for i=2,tn do
                    local ti = t[i]
                    n = n + 1 ; buffer[n] = connector
                    n = n + 1 ;
                    if #ti == 6 then
                        buffer[n] = f6(ti[1],ti[2],ti[3],ti[4],ti[5],ti[6])
                    else
                        buffer[n] = f2(ti[1],ti[2])
                    end
                end
                if cycle then
                    n = n + 1 ; buffer[n] = connector
                    n = n + 1 ; buffer[n] = "cycle"
                end
            end
        end
    end

    local function mppath(...)
        mp_path(f_pair,f_pair_ctrl,...)
    end

    local function mppathpoints(...)
        mp_path(f_pair_pt,f_pair_pt_ctrl,...)
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

    aux.print           = mpprint
    aux.vprint          = mpvprint
    aux.boolean         = mpboolean
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

    -- we need access to the variables

    function metapost.nofscriptruns()
        return runs
    end

    -- there is no gain in:
    --
    -- local cache = table.makeweak()
    --
    -- f = cache[code]
    -- if not f then
    --     f = loadstring(f_code(code))
    --     if f then
    --         cache[code] = f
    --     elseif be_tolerant then
    --         f = loadstring(code)
    --         if f then
    --             cache[code] = f
    --         end
    --     end
    -- end

    function metapost.runscript(code)
        nesting = nesting + 1
        local trace = trace_enabled and trace_luarun
        if trace then
            report_luarun("%i: code: %s",nesting,code)
        end
        runs = runs + 1
        local f = loadstring(f_code(code))
        if not f and be_tolerant then
            f = loadstring(code)
        end
        if f then
            local _buffer_, _n_ = buffer, n
            buffer, n = { }, 0
            local result = f()
            if result then
                local t = type(result)
                if t == "number" then
                    result = f_numeric(result)
                elseif t ~= "string" then
                    result = tostring(result)
                end
                if trace then
                    if #result == 0 then
                        report_luarun("%i: no result",nesting)
-- print(debug.traceback())
                    else
                        report_luarun("%i: result: %s",nesting,result)
                    end
                end
                buffer, n = _buffer_, _n_
                nesting = nesting - 1
                return result
            elseif trace then
                report_luarun("%i: no result",nesting)
-- print(debug.traceback())
            end
            buffer, n = _buffer_, _n_
        else
            report_luarun("%i: no result, invalid code: %s",nesting,code)
        end
        nesting = nesting - 1
        return ""
    end

    -- for the moment

    for k, v in next, aux do mp[k] = v end

end

do

    local mpnamedcolor = attributes.colors.mpnamedcolor
    local mpprint      = aux.print

    mp.mf_named_color = function(str)
        mpprint(mpnamedcolor(str))
    end

end

function mp.n(t) -- used ?
    return type(t) == "table" and #t or 0
end

do

    -- experiment: names can change

    local mppath     = aux.mppath
    local mpsize     = aux.mpsize

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
            Data = data,
            Line = function(n) mppath(data[n or 1]) end,
            Size = function()  mpsize(data)         end,
        }
    end

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

    function mp.report(a,b)
        if b then
            report_message("%s : %s",a,b)
        elseif a then
            report_message("%s : %s","message",a)
        end
    end

end

do

    local mpprint  = aux.print
    local mpvprint = aux.vprint

    local hashes   = { }

    function mp.newhash()
        for i=1,#hashes+1 do
            if not hashes[i] then
                hashes[i] = { }
                mpvprint(i)
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

    local getdimen  = tex.getdimen
    local getcount  = tex.getcount
    local gettoks   = tex.gettoks
    local setdimen  = tex.setdimen
    local setcount  = tex.setcount
    local settoks   = tex.settoks

    local mpprint   = mp.print
    local mpquoted  = mp.quoted

    local bpfactor  = number.dimenfactors.bp

    -- more helpers

    function mp.getdimen(k)   mpprint (getdimen(k)*bpfactor) end
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

end

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

    local stores   = { }

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
        arguments = "2 strings",
        actions   = function(name,key)
            context(stores[name][key])
        end
    }

end

do

    -- a bit overkill: just a find(str,"mf_object=") can be enough

    local mpboolean = aux.boolean

    local p1        = P("mf_object=")
    local p2        = lpegpatterns.eol * p1
    local pattern   = (1-p2)^0 * p2 + p1

    function mp.isobject(str)
        mpboolean(pattern and str ~= "" and lpegmatch(p,str))
    end

end

do

    local mpnumeric = aux.numeric
    local mppair    = aux.pair
    local mpgetpath = get.path

    local p = nil
    local n = 0

    local function mf_path_length(name)
        p = mpgetpath(name)
        n = p and #p or 0
        mpnumeric(n)
    end

    local function mf_path_point(i)
        if i > 0 and i <= n then
            local pi = p[i]
            mppair(pi[1],pi[2])
        end
    end

    local function mf_path_left(i)
        if i > 0 and i <= n then
            local pi = p[i]
            mppair(pi[5],pi[6])
        end
    end

    local function mf_path_right(i)
        if i > 0 and i <= n then
            local pn
            if i == 1 then
                pn = p[2] or p[1]
            else
                pn = p[i+1] or p[1]
            end
            mppair(pn[3],pn[4])
        end
    end

    local function mf_path_reset()
        p = nil
        n = 0
    end

    mp.mf_path_length = mf_path_length   mp.pathlength = mf_path_length
    mp.mf_path_point  = mf_path_point    mp.pathpoint  = mf_path_point
    mp.mf_path_left   = mf_path_left     mp.pathleft   = mf_path_left
    mp.mf_path_right  = mf_path_right    mp.pathright  = mf_path_right
    mp.mf_path_reset  = mf_path_reset    mp.pathreset  = mf_path_reset

end
