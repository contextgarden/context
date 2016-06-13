if not modules then modules = { } end modules ['cldf-ini'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- also see cldf-tod.* !
-- old code moved to cldf-old.lua

-- maybe:
--
-- 0.528 local foo = tex.ctxcatcodes
-- 0.651 local foo = getcount("ctxcatcodes")
-- 0.408 local foo = getcount(ctxcatcodes) -- local ctxcatcodes = tex.iscount("ctxcatcodes")

-- This started as an experiment: generating context code at the lua end. After all
-- it is surprisingly simple to implement due to metatables. I was wondering if
-- there was a more natural way to deal with commands at the lua end. Of course it's
-- a bit slower but often more readable when mixed with lua code. It can also be handy
-- when generating documents from databases or when constructing large tables or so.
--
-- maybe optional checking against interface
-- currently no coroutine trickery
-- we could always use prtcatcodes (context.a_b_c) but then we loose protection
-- tflush needs checking ... sort of weird that it's not a table
-- __flushlines is an experiment and rather ugly so it will go away
--
-- tex.print == line with endlinechar appended

-- todo: context("%bold{total: }%s",total)
-- todo: context.documentvariable("title")

-- during the crited project we ran into the situation that luajittex was 10-20 times
-- slower that luatex ... after 3 days of testing and probing we finally figured out that
-- the the differences between the lua and luajit hashers can lead to quite a slowdown
-- in some cases.

-- context(lpeg.match(lpeg.patterns.texescape,"${}"))
-- context(string.formatters["%!tex!"]("${}"))
-- context("%!tex!","${}")

local format, stripstring = string.format, string.strip
local next, type, tostring, tonumber, setmetatable, unpack, select, rawset = next, type, tostring, tonumber, setmetatable, unpack, select, rawset
local insert, remove, concat = table.insert, table.remove, table.concat
local lpegmatch, lpegC, lpegS, lpegP, lpegV, lpegCc, lpegCs, patterns = lpeg.match, lpeg.C, lpeg.S, lpeg.P, lpeg.V, lpeg.Cc, lpeg.Cs, lpeg.patterns
local formatters = string.formatters -- using formatters is slower in this case

context                 = context    or { }
commands                = commands   or { }
interfaces              = interfaces or { }

local context           = context
local commands          = commands
local interfaces        = interfaces

local loaddata          = io.loaddata

local tex               = tex
local texsprint         = tex.sprint    -- just appended (no space,eol treatment)
local texprint          = tex.print     -- each arg a separate line (not last in directlua)
----- texwrite          = tex.write     -- all 'space' and 'character'
local texgetcount       = tex.getcount

-- local function texsprint(...) print("sprint",...) tex.sprint(...) end
-- local function texprint (...) print("print", ...) tex.print (...) end

local isnode            = node.is_node
local writenode         = node.write
local copynodelist      = node.copy_list

local catcodenumbers    = catcodes.numbers

local ctxcatcodes       = catcodenumbers.ctxcatcodes
local prtcatcodes       = catcodenumbers.prtcatcodes
local texcatcodes       = catcodenumbers.texcatcodes
local txtcatcodes       = catcodenumbers.txtcatcodes
local vrbcatcodes       = catcodenumbers.vrbcatcodes
local xmlcatcodes       = catcodenumbers.xmlcatcodes

local flush             = texsprint   -- snippets
local flushdirect       = texprint    -- lines
----- flushraw          = texwrite

local report_context    = logs.reporter("cld","tex")
local report_cld        = logs.reporter("cld","stack")

local processlines      = true -- experiments.register("context.processlines", function(v) processlines = v end)

-- In earlier experiments a function tables was referred to as lua.calls and the
-- primitive \luafunctions was \luacall.

local luafunctions   = lua.get_functions_table and lua.get_functions_table()
local usedstack      = nil
local showstackusage = false

-- luafunctions = false

trackers.register("context.stack",function(v) showstackusage = v end)

local storefunction, flushfunction
local storenode, flushnode
local registerfunction, unregisterfunction, reservefunction, knownfunctions, callfunctiononce

-- if luafunctions then

    local freed, nofused, noffreed = { }, 0, 0 -- maybe use the number of @@trialtypesetting

    usedstack = function()
        return nofused, noffreed
    end

    flushfunction = function(slot,arg)
        if arg() then
            -- keep
        elseif texgetcount("@@trialtypesetting") == 0 then  -- @@trialtypesetting is private!
            noffreed = noffreed + 1
            freed[noffreed] = slot
            luafunctions[slot] = false
        else
            -- keep
        end
    end

    storefunction = function(arg)
        local f = function(slot) flushfunction(slot,arg) end
        if noffreed > 0 then
            local n = freed[noffreed]
            freed[noffreed] = nil
            noffreed = noffreed - 1
            luafunctions[n] = f
            return n
        else
            nofused = nofused + 1
            luafunctions[nofused] = f
            return nofused
        end
    end

    flushnode = function(slot,arg)
        if texgetcount("@@trialtypesetting") == 0 then  -- @@trialtypesetting is private!
            writenode(arg)
            noffreed = noffreed + 1
            freed[noffreed] = slot
            luafunctions[slot] = false
        else
            writenode(copynodelist(arg))
        end
    end

    storenode = function(arg)
        local f = function(slot) flushnode(slot,arg) end
        if noffreed > 0 then
            local n = freed[noffreed]
            freed[noffreed] = nil
            noffreed = noffreed - 1
            luafunctions[n] = f
            return n
        else
            nofused = nofused + 1
            luafunctions[nofused] = f
            return nofused
        end
    end

 -- registerfunction = function(f)
 --     if type(f) == "string" then
 --         f = loadstring(f)
 --     end
 --     if type(f) ~= "function" then
 --         f = function() report_cld("invalid function %A",f) end
 --     end
 --     if noffreed > 0 then
 --         local n = freed[noffreed]
 --         freed[noffreed] = nil
 --         noffreed = noffreed - 1
 --         luafunctions[n] = f
 --         return n
 --     else
 --         nofused = nofused + 1
 --         luafunctions[nofused] = f
 --         return nofused
 --     end
 -- end

    storage.storedfunctions = storage.storedfunctions or { }
    local storedfunctions   = storage.storedfunctions
    local initex            = environment.initex

    storage.register("storage/storedfunctions", storedfunctions, "storage.storedfunctions")

    local f_resolve = nil
    local p_resolve  = ((1-lpegP("."))^1 / function(s) f_resolve = f_resolve[s] end * lpegP(".")^0)^1

    local function resolvestoredfunction(str)
        f_resolve = global
        lpegmatch(p_resolve,str)
        return f_resolve
    end

    local function expose(slot,f,...) -- so we can register yet undefined functions
        local func = resolvestoredfunction(f)
        if not func then
            func = function() report_cld("beware: unknown function %i called: %s",slot,f) end
        end
        luafunctions[slot] = func
        return func(...)
    end

    if initex then
        -- todo: log stored functions
    else
        local slots = table.sortedkeys(storedfunctions)
        local last  = #slots
        if last > 0 then
            -- we restore the references
            for i=1,last do
                local slot = slots[i]
                local data = storedfunctions[slot]
                luafunctions[slot] = function(...)
                    -- print(data) -- could be trace
                    return expose(slot,data,...)
                end
            end
            -- we now know how many are defined
            nofused = slots[last]
            -- normally there are no holes in the list yet
            for i=1,nofused do
                if not luafunctions[i] then
                    noffreed = noffreed + 1
                    freed[noffreed] = i
                end
            end
         -- report_cld("%s registered functions, %s freed slots",last,noffreed)
        end
    end

    registerfunction = function(f,direct) -- either f=code or f=namespace,direct=name
        local slot, func
        if noffreed > 0 then
            slot = freed[noffreed]
            freed[noffreed] = nil
            noffreed = noffreed - 1
        else
            nofused = nofused + 1
            slot = nofused
        end
        if direct then
            if initex then
                func = function(...)
                    expose(slot,f,...)
                end
                if initex then
                    storedfunctions[slot] = f
                end
            else
                func = resolvestoredfunction(f)
            end
            if type(func) ~= "function" then
                func = function() report_cld("invalid resolve %A",f) end
            end
        elseif type(f) == "string" then
            func = loadstring(f)
            if type(func) ~= "function" then
                func = function() report_cld("invalid code %A",f) end
            end
        elseif type(f) == "function" then
            func = f
        else
            func = function() report_cld("invalid function %A",f) end
        end
        luafunctions[slot] = func
        return slot
    end

 -- do
 --     commands.test = function(str) report_cld("test function: %s", str) end
 --     if initex then
 --         registerfunction("commands.test") -- number 1
 --     end
 --     luafunctions[1]("okay")
 -- end

    unregisterfunction = function(slot)
        if luafunctions[slot] then
            noffreed = noffreed + 1
            freed[noffreed] = slot
            luafunctions[slot] = false
        else
            report_cld("invalid function slot %A",slot)
        end
    end

    reservefunction = function()
        if noffreed > 0 then
            local n = freed[noffreed]
            freed[noffreed] = nil
            noffreed = noffreed - 1
            return n
        else
            nofused = nofused + 1
            return nofused
        end
    end

    callfunctiononce = function(slot)
        luafunctions[slot](slot)
        noffreed = noffreed + 1
        freed[noffreed] = slot
        luafunctions[slot] = false
    end

    table.setmetatablecall(luafunctions,function(t,n) return luafunctions[n](n) end)

    knownfunctions = luafunctions

    -- The next hack is a convenient way to define scanners at the Lua end and
    -- get them available at the TeX end. There is some dirty magic needed to
    -- prevent overload during format loading.

    -- interfaces.scanners.foo = function() context("[%s]",tokens.scanners.string()) end : \scan_foo

    interfaces.storedscanners = interfaces.storedscanners or { }
    local storedscanners      = interfaces.storedscanners

    storage.register("interfaces/storedscanners", storedscanners, "interfaces.storedscanners")

    local interfacescanners = table.setmetatablenewindex(function(t,k,v)
        if storedscanners[k] then
         -- report_cld("warning: scanner %a is already set",k)
         -- os.exit()
            -- \scan_<k> is already in the format
         -- report_cld("using interface scanner: %s",k)
        else
            -- todo: allocate slot here and pass it
            storedscanners[k] = true
         -- report_cld("installing interface scanner: %s",k)
            context("\\installctxscanner{clf_%s}{interfaces.scanners.%s}",k,k)
        end
        rawset(t,k,v)
    end)

    interfaces.scanners = interfacescanners

-- else -- by now this is obsolete
--
--     local luafunctions, noffunctions = { }, 0
--     local luanodes, nofnodes = { }, 0
--
--     usedstack = function()
--         return noffunctions + nofnodes, 0
--     end
--
--     flushfunction = function(n)
--         local sn = luafunctions[n]
--         if not sn then
--             report_cld("data with id %a cannot be found on stack",n)
--         elseif not sn() and texgetcount("@@trialtypesetting") == 0 then  -- @@trialtypesetting is private!
--             luafunctions[n] = nil
--         end
--     end
--
--     storefunction = function(ti)
--         noffunctions = noffunctions + 1
--         luafunctions[noffunctions] = ti
--         return noffunctions
--     end
--
--  -- freefunction = function(n)
--  --     luafunctions[n] = nil
--  -- end
--
--     flushnode = function(n)
--         local sn = luanodes[n]
--         if not sn then
--             report_cld("data with id %a cannot be found on stack",n)
--         elseif texgetcount("@@trialtypesetting") == 0 then  -- @@trialtypesetting is private!
--             writenode(sn)
--             luanodes[n] = nil
--         else
--             writenode(copynodelist(sn))
--         end
--     end
--
--     storenode = function(ti)
--         nofnodes = nofnodes + 1
--         luanodes[nofnodes] = ti
--         return nofnodes
--     end
--
--     _cldf_ = flushfunction -- global
--     _cldn_ = flushnode     -- global
--  -- _cldl_ = function(n) return luafunctions[n]() end -- luafunctions(n)
--     _cldl_ = luafunctions
--
--     registerfunction = function(f)
--         if type(f) == "string" then
--             f = loadstring(f)
--         end
--         if type(f) ~= "function" then
--             f = function() report_cld("invalid function %A",f) end
--         end
--         noffunctions = noffunctions + 1
--         luafunctions[noffunctions] = f
--         return noffunctions
--     end
--
--     unregisterfunction = function(slot)
--         if luafunctions[slot] then
--             luafunctions[slot] = nil
--         else
--             report_cld("invalid function slot %A",slot)
--         end
--     end
--
--     reservefunction = function()
--         noffunctions = noffunctions + 1
--         return noffunctions
--     end
--
--     callfunctiononce = function(slot)
--         luafunctions[slot](slot)
--         luafunctions[slot] = nil
--     end
--
--     table.setmetatablecall(luafunctions,function(t,n) return luafunctions[n](n) end)
--
--     knownfunctions = luafunctions
--
-- end

context.registerfunction   = registerfunction
context.unregisterfunction = unregisterfunction
context.reservefunction    = reservefunction
context.knownfunctions     = knownfunctions
context.callfunctiononce   = callfunctiononce   _cldo_ = callfunctiononce
context.storenode          = storenode -- private helper

function commands.ctxfunction(code,namespace)
    context(registerfunction(code,namespace))
end

function commands.ctxscanner(name,code,namespace)
    local n = registerfunction(code,namespace)
    if storedscanners[name] then
        storedscanners[name] = n
    end
    context(n)
end

local function dummy() end

function commands.ctxresetter(name)
    return function()
        if storedscanners[name] then
            rawset(interfacescanners,name,dummy)
            context.resetctxscanner("clf_" .. name)
        end
    end
end

function context.trialtypesetting()
    return texgetcount("@@trialtypesetting") ~= 0
end

-- Should we keep the catcodes with the function?

local catcodestack    = { }
local currentcatcodes = ctxcatcodes
local contentcatcodes = ctxcatcodes

local catcodes = {
    ctx = ctxcatcodes, ctxcatcodes = ctxcatcodes, context  = ctxcatcodes,
    prt = prtcatcodes, prtcatcodes = prtcatcodes, protect  = prtcatcodes,
    tex = texcatcodes, texcatcodes = texcatcodes, plain    = texcatcodes,
    txt = txtcatcodes, txtcatcodes = txtcatcodes, text     = txtcatcodes,
    vrb = vrbcatcodes, vrbcatcodes = vrbcatcodes, verbatim = vrbcatcodes,
    xml = xmlcatcodes, xmlcatcodes = xmlcatcodes,
}

-- maybe just increment / decrement

-- local function pushcatcodes(c)
--     insert(catcodestack,currentcatcodes)
--     currentcatcodes = (c and catcodes[c] or tonumber(c)) or currentcatcodes
--     contentcatcodes = currentcatcodes
-- end
--
-- local function popcatcodes()
--     currentcatcodes = remove(catcodestack) or currentcatcodes
--     contentcatcodes = currentcatcodes
-- end

local catcodelevel = 0

local function pushcatcodes(c)
    catcodelevel = catcodelevel + 1
    catcodestack[catcodelevel] = currentcatcodes
    currentcatcodes = (c and catcodes[c] or tonumber(c)) or currentcatcodes
    contentcatcodes = currentcatcodes
end

local function popcatcodes()
    if catcodelevel > 0 then
        currentcatcodes = catcodestack[catcodelevel] or currentcatcodes
        catcodelevel = catcodelevel - 1
    end
    contentcatcodes = currentcatcodes
end

context.catcodes     = catcodes
context.pushcatcodes = pushcatcodes
context.popcatcodes  = popcatcodes

-- -- --

local newline       = patterns.newline
local space         = patterns.spacer
local spacing       = newline * space^0
local content       = lpegC((1-spacing)^1)            -- texsprint
local emptyline     = space^0 * newline^2             -- texprint("")
local endofline     = space^0 * newline * space^0     -- texsprint(" ")
local simpleline    = endofline * lpegP(-1)           --

local verbose       = lpegC((1-space-newline)^1)
local beginstripper = (lpegS(" \t")^1 * newline^1) / ""
local endstripper   = beginstripper * lpegP(-1)

local justaspace    = space * lpegCc("")
local justanewline  = newline * lpegCc("")

local function n_content(s)
    flush(contentcatcodes,s)
end

local function n_verbose(s)
    flush(vrbcatcodes,s)
end

local function n_endofline()
    flush(currentcatcodes," \r")
end

local function n_emptyline()
    flushdirect(currentcatcodes,"\r")
end

local function n_simpleline()
    flush(currentcatcodes," \r")
end

local n_exception = ""

-- better a table specification

function context.newtexthandler(specification) -- can also be used for verbose
    specification = specification or { }
    --
    local s_catcodes   = specification.catcodes
    --
    local f_before     = specification.before
    local f_after      = specification.after
    --
    local f_endofline  = specification.endofline  or n_endofline
    local f_emptyline  = specification.emptyline  or n_emptyline
    local f_simpleline = specification.simpleline or n_simpleline
    local f_content    = specification.content    or n_content
    local f_space      = specification.space
    --
    local p_exception  = specification.exception
    --
    if s_catcodes then
        f_content = function(s)
            flush(s_catcodes,s)
        end
    end
    --
    local pattern
    if f_space then
        if p_exception then
            local content = lpegC((1-spacing-p_exception)^1)
            pattern =
              (
                    justaspace   / f_space
                  + justanewline / f_endofline
                  + p_exception
                  + content      / f_content
                )^0
        else
            local content = lpegC((1-space-endofline)^1)
            pattern =
                (
                    justaspace   / f_space
                  + justanewline / f_endofline
                  + content      / f_content
                )^0
        end
    else
        if p_exception then
            local content = lpegC((1-spacing-p_exception)^1)
            pattern =
                simpleline / f_simpleline
              +
              (
                    emptyline  / f_emptyline
                  + endofline  / f_endofline
                  + p_exception
                  + content    / f_content
                )^0
        else
            local content = lpegC((1-spacing)^1)
            pattern =
                simpleline / f_simpleline
                +
                (
                    emptyline / f_emptyline
                  + endofline / f_endofline
                  + content   / f_content
                )^0
        end
    end
    --
    if f_before then
        pattern = (P(true) / f_before) * pattern
    end
    --
    if f_after then
        pattern = pattern * (P(true) / f_after)
    end
    --
    return function(str) return lpegmatch(pattern,str) end, pattern
end

function context.newverbosehandler(specification) -- a special variant for e.g. cdata in lxml-tex
    specification = specification or { }
    --
    local f_line    = specification.line    or function() flushdirect("\r") end
    local f_space   = specification.space   or function() flush(" ") end
    local f_content = specification.content or n_verbose
    local f_before  = specification.before
    local f_after   = specification.after
    --
    local pattern =
        justanewline / f_line    -- so we get call{}
      + verbose      / f_content
      + justaspace   / f_space   -- so we get call{}
    --
    if specification.strip then
        pattern = beginstripper^0 * (endstripper + pattern)^0
    else
        pattern = pattern^0
    end
    --
    if f_before then
        pattern = (lpegP(true) / f_before) * pattern
    end
    --
    if f_after then
        pattern = pattern * (lpegP(true) / f_after)
    end
    --
    return function(str) return lpegmatch(pattern,str) end, pattern
end

local flushlines = context.newtexthandler {
    content    = n_content,
    endofline  = n_endofline,
    emptyline  = n_emptyline,
    simpleline = n_simpleline,
}

context.__flushlines  = flushlines       -- maybe context.helpers.flushtexlines
context.__flush       = flush
context.__flushdirect = flushdirect

-- The next variant is only used in rare cases (buffer to mp):

local printlines_ctx = (
    (newline)     / function()  texprint("") end +
    (1-newline)^1 / function(s) texprint(ctxcatcodes,s) end * newline^-1
)^0

local printlines_raw = (
    (newline)     / function()  texprint("") end +
    (1-newline)^1 / function(s) texprint(s)  end * newline^-1
)^0

function context.printlines(str,raw)     -- todo: see if via file is useable
    if raw then
        lpegmatch(printlines_raw,str)
    else
        lpegmatch(printlines_ctx,str)
    end
end

-- -- -- "{" .. ti .. "}" is somewhat slower in a cld-mkiv run than "{",ti,"}"

local containseol = patterns.containseol

local writer    = nil
local prtwriter = nil

-- if luafunctions then

    writer = function (parent,command,...) -- already optimized before call
        flush(currentcatcodes,command) -- todo: ctx|prt|texcatcodes
        local direct = false
     -- local t = { ... }
     -- for i=1,#t do
     --     local ti = t[i]
        for i=1,select("#",...) do
            local ti = (select(i,...))
            if direct then
                local typ = type(ti)
                if typ == "string" or typ == "number" then
                    flush(currentcatcodes,ti)
                else -- node.write
                    report_context("error: invalid use of direct in %a, only strings and numbers can be flushed directly, not %a",command,typ)
                end
                direct = false
            elseif ti == nil then
                -- nothing
            elseif ti == "" then
                flush(currentcatcodes,"{}")
            else
                local typ = type(ti)
                if typ == "string" then
                    -- is processlines seen ?
                    if processlines and lpegmatch(containseol,ti) then
                        flush(currentcatcodes,"{")
                        local flushlines = parent.__flushlines or flushlines
                        flushlines(ti)
                        flush(currentcatcodes,"}")
                    elseif currentcatcodes == contentcatcodes then
                        flush(currentcatcodes,"{",ti,"}")
                    else
                        flush(currentcatcodes,"{")
                        flush(contentcatcodes,ti)
                        flush(currentcatcodes,"}")
                    end
                elseif typ == "number" then
                    -- numbers never have funny catcodes
                    flush(currentcatcodes,"{",ti,"}")
                elseif typ == "table" then
                    local tn = #ti
                    if tn == 0 then
                        local done = false
                        for k, v in next, ti do
                            if done then
                                if v == "" then
                                    flush(currentcatcodes,",",k,'=')
                                else
                                    flush(currentcatcodes,",",k,"={",v,"}")
                                end
                            else
                                if v == "" then
                                    flush(currentcatcodes,"[",k,"=")
                                else
                                    flush(currentcatcodes,"[",k,"={",v,"}")
                                end
                                done = true
                            end
                        end
                        if done then
                            flush(currentcatcodes,"]")
                        else
                            flush(currentcatcodes,"[]")
                        end
                    elseif tn == 1 then -- some 20% faster than the next loop
                        local tj = ti[1]
                        if type(tj) == "function" then
                            flush(currentcatcodes,"[\\cldl",storefunction(tj),"]")
                         -- flush(currentcatcodes,"[",storefunction(tj),"]")
                        else
                            flush(currentcatcodes,"[",tj,"]")
                        end
                    else -- is concat really faster than flushes here? probably needed anyway (print artifacts)
                        flush(currentcatcodes,"[")
                        for j=1,tn do
                            local tj = ti[j]
                            if type(tj) == "function" then
                                if j == tn then
                                    flush(currentcatcodes,"\\cldl",storefunction(tj),"]")
                                 -- flush(currentcatcodes,"",storefunction(tj),"]")
                                else
                                    flush(currentcatcodes,"\\cldl",storefunction(tj),",")
                                 -- flush(currentcatcodes,"",storefunction(tj),",")
                                end
                            else
                                if j == tn then
                                    flush(currentcatcodes,tj,"]")
                                else
                                    flush(currentcatcodes,tj,",")
                                end
                            end
                        end
                    end
                elseif typ == "function" then
                    flush(currentcatcodes,"{\\cldl ",storefunction(ti),"}") -- todo: ctx|prt|texcatcodes
                 -- flush(currentcatcodes,"{",storefunction(ti),"}") -- todo: ctx|prt|texcatcodes
                elseif typ == "boolean" then
                    if ti then
                        flushdirect(currentcatcodes,"\r")
                    else
                        direct = true
                    end
                elseif typ == "thread" then
                    report_context("coroutines not supported as we cannot yield across boundaries")
                elseif isnode(ti) then -- slow
                    flush(currentcatcodes,"{\\cldl",storenode(ti),"}")
                 -- flush(currentcatcodes,"{",storenode(ti),"}")
                else
                    report_context("error: %a gets a weird argument %a",command,ti)
                end
            end
        end
    end

    -- if performance really matters we can consider a compiler but it will never
    -- pay off

    prtwriter = function (command,...) -- already optimized before call
        flush(prtcatcodes,command)
        for i=1,select("#",...) do
            local ti = (select(i,...))
            if ti == nil then
                -- nothing
            elseif ti == "" then
                flush(prtcatcodes,"{}")
            else
                local tp = type(ti)
                if tp == "string" or tp == "number"then
                    flush(prtcatcodes,"{",ti,"}")
                elseif tp == "function" then
                    flush(prtcatcodes,"{\\cldl ",storefunction(ti),"}")
                 -- flush(currentcatcodes,"{",storefunction(ti),"}") -- todo: ctx|prt|texcatcodes
                elseif isnode(ti) then
                    flush(prtcatcodes,"{\\cldl",storenode(ti),"}")
                 -- flush(currentcatcodes,"{",storenode(ti),"}")
                else
                    report_context("fatal error: prt %a gets a weird argument %a",command,ti)
                end
            end
        end
    end

-- else
--
--     writer = function (parent,command,first,...) -- already optimized before call
--         local t = { first, ... }
--         flush(currentcatcodes,command) -- todo: ctx|prt|texcatcodes
--         local direct = false
--         for i=1,#t do
--             local ti = t[i]
--             local typ = type(ti)
--             if direct then
--                 if typ == "string" or typ == "number" then
--                     flush(currentcatcodes,ti)
--                 else -- node.write
--                     report_context("error: invalid use of direct in %a, only strings and numbers can be flushed directly, not %a",command,typ)
--                 end
--                 direct = false
--             elseif ti == nil then
--                 -- nothing
--             elseif ti == "" then
--                 flush(currentcatcodes,"{}")
--             elseif typ == "string" then
--                 -- is processelines seen ?
--                 if processlines and lpegmatch(containseol,ti) then
--                     flush(currentcatcodes,"{")
--                     local flushlines = parent.__flushlines or flushlines
--                     flushlines(ti)
--                     flush(currentcatcodes,"}")
--                 elseif currentcatcodes == contentcatcodes then
--                     flush(currentcatcodes,"{",ti,"}")
--                 else
--                     flush(currentcatcodes,"{")
--                     flush(contentcatcodes,ti)
--                     flush(currentcatcodes,"}")
--                 end
--             elseif typ == "number" then
--                 -- numbers never have funny catcodes
--                 flush(currentcatcodes,"{",ti,"}")
--             elseif typ == "table" then
--                 local tn = #ti
--                 if tn == 0 then
--                     local done = false
--                     for k, v in next, ti do
--                         if done then
--                             if v == "" then
--                                 flush(currentcatcodes,",",k,'=')
--                             else
--                                 flush(currentcatcodes,",",k,"={",v,"}")
--                             end
--                         else
--                             if v == "" then
--                                 flush(currentcatcodes,"[",k,"=")
--                             else
--                                 flush(currentcatcodes,"[",k,"={",v,"}")
--                             end
--                             done = true
--                         end
--                     end
--                     if done then
--                         flush(currentcatcodes,"]")
--                     else
--                         flush(currentcatcodes,"[]")
--                     end
--                 elseif tn == 1 then -- some 20% faster than the next loop
--                     local tj = ti[1]
--                     if type(tj) == "function" then
--                         flush(currentcatcodes,"[\\cldf{",storefunction(tj),"}]")
--                     else
--                         flush(currentcatcodes,"[",tj,"]")
--                     end
--                 else -- is concat really faster than flushes here? probably needed anyway (print artifacts)
--                     for j=1,tn do
--                         local tj = ti[j]
--                         if type(tj) == "function" then
--                             ti[j] = "\\cldf{" .. storefunction(tj) .. "}"
--                         end
--                     end
--                     flush(currentcatcodes,"[",concat(ti,","),"]")
--                 end
--             elseif typ == "function" then
--                 flush(currentcatcodes,"{\\cldf{",storefunction(ti),"}}") -- todo: ctx|prt|texcatcodes
--             elseif typ == "boolean" then
--                 if ti then
--                     flushdirect(currentcatcodes,"\r")
--                 else
--                     direct = true
--                 end
--             elseif typ == "thread" then
--                 report_context("coroutines not supported as we cannot yield across boundaries")
--             elseif isnode(ti) then -- slow
--                 flush(currentcatcodes,"{\\cldn{",storenode(ti),"}}")
--             else
--                 report_context("error: %a gets a weird argument %a",command,ti)
--             end
--         end
--     end
--
-- end

local generics   = { }  context.generics = generics
local indexer    = nil
local prtindexer = nil

-- if environment.initex then

    indexer = function(parent,k)
        if type(k) == "string" then
            local c = "\\" .. tostring(generics[k] or k)
            local f = function(first,...)
                if first == nil then
                    flush(currentcatcodes,c)
                else
                    return writer(parent,c,first,...)
                end
            end
            parent[k] = f
            return f
        else
            return context -- catch
        end
    end

-- else
--
--     local create   = token.create
--     local twrite   = token.write
--
--     indexer = function(parent,k)
--         if type(k) == "string" then
--             local s = tostring(generics[k] or k)
--             local t = create(s)
--             if t.cmdname == "undefined_cs" then
--                 report_cld("macro \\%s is not yet defined",s)
--                 token.set_macro(s,"")
--                 t = create(s)
--             end
--             local i = t.id
--             local f = function(first,...)
--                 twrite(t.tok) --= we need to keep t uncollected
--                 if first ~= nil then
--                     return writer(parent,first,...)
--                 end
--             end
--             parent[k] = f
--             return f
--         else
--             return context -- catch
--         end
--     end
--
-- end

-- Potential optimization: after the first call we know if there will be an
-- argument. Of course there is the side effect that for instance abuse like
-- context.NC(str) fails as well as optional arguments. So, we don't do this
-- in practice. We just keep the next trick commented. The gain on some
-- 100000 calls is not that large: 0.100 => 0.95 which is neglectable.
--
-- local function constructor(parent,k,c,first,...)
--     if first == nil then
--         local f = function()
--             flush(currentcatcodes,c)
--         end
--         parent[k] = f
--         return f()
--     else
--         local f = function(...)
--             return writer(parent,c,...)
--         end
--         parent[k] = f
--         return f(first,...)
--     end
-- end
--
-- local function indexer(parent,k)
--     local c = "\\" .. tostring(generics[k] or k)
--     local f = function(...)
--         return constructor(parent,k,c,...)
--     end
--     parent[k] = f
--     return f
-- end

-- only for internal usage:

do

    function context.constructcsonly(k) -- not much faster than the next but more mem efficient
        local c = "\\" .. tostring(generics[k] or k)
        local v = function()
            flush(prtcatcodes,c)
        end
        rawset(context,k,v) -- context namespace
        return v
    end

    function context.constructcs(k)
        local c = "\\" .. tostring(generics[k] or k)
        local v = function(first,...)
            if first == nil then
                flush(prtcatcodes,c)
            else
                return prtwriter(c,first,...)
            end
        end
        rawset(context,k,v) -- context namespace
        return v
    end

    local function prtindexer(t,k)
        local c = "\\" .. tostring(generics[k] or k)
        local v = function(first,...)
            if first == nil then
                flush(prtcatcodes,c)
            else
                return prtwriter(c,first,...)
            end
        end
        rawset(t,k,v) -- protected namespace
        return v
    end

    context.protected = { } -- we could check for _ in the context namespace

    setmetatable(context.protected, { __index = prtindexer, __call = prtwriter } )

end

-- local splitformatters = utilities.strings.formatters.new(true) -- not faster (yet)

local caller

-- if luafunctions then

    caller = function(parent,f,a,...)
        if not parent then
            -- so we don't need to test in the calling (slower but often no issue)
        elseif f ~= nil then
            local typ = type(f)
            if typ == "string" then
                if f == "" then
                    -- new, can save a bit sometimes
                 -- if trace_context then
                 --     report_context("empty argument to context()")
                 -- end
                elseif a then
                    flush(contentcatcodes,formatters[f](a,...)) -- was currentcatcodes
                 -- flush(contentcatcodes,splitformatters[f](a,...)) -- was currentcatcodes
                elseif processlines and lpegmatch(containseol,f) then
                    local flushlines = parent.__flushlines or flushlines
                    flushlines(f)
                else
                    flush(contentcatcodes,f)
                end
            elseif typ == "number" then
                if a then
                    flush(currentcatcodes,f,a,...)
                else
                    flush(currentcatcodes,f)
                end
            elseif typ == "function" then
                -- ignored: a ...
                flush(currentcatcodes,"{\\cldl",storefunction(f),"}") -- todo: ctx|prt|texcatcodes
             -- flush(currentcatcodes,"{",storefunction(f),"}") -- todo: ctx|prt|texcatcodes
            elseif typ == "boolean" then
                if f then
                    if a ~= nil then
                        local flushlines = parent.__flushlines or flushlines
                        flushlines(a)
                    else
                        flushdirect(currentcatcodes,"\n") -- no \r, else issues with \startlines ... use context.par() otherwise
                    end
                else
                    if a ~= nil then
                        -- no command, same as context(a,...)
                        writer(parent,"",a,...)
                    else
                        -- ignored
                    end
                end
            elseif typ == "thread" then
                report_context("coroutines not supported as we cannot yield across boundaries")
            elseif isnode(f) then -- slow
             -- writenode(f)
                flush(currentcatcodes,"\\cldl",storenode(f)," ")
             -- flush(currentcatcodes,"",storenode(f)," ")
            else
                report_context("error: %a gets a weird argument %a","context",f)
            end
        end
    end

    function context.flushnode(n)
        flush(currentcatcodes,"\\cldl",storenode(n)," ")
     -- flush(currentcatcodes,"",storenode(n)," ")
    end

-- else
--
--     caller = function(parent,f,a,...)
--         if not parent then
--             -- so we don't need to test in the calling (slower but often no issue)
--         elseif f ~= nil then
--             local typ = type(f)
--             if typ == "string" then
--                 if f == "" then
--                     -- new, can save a bit sometimes
--                  -- if trace_context then
--                  --     report_context("empty argument to context()")
--                  -- end
--                 elseif a then
--                     flush(contentcatcodes,formatters[f](a,...)) -- was currentcatcodes
--                  -- flush(contentcatcodes,splitformatters[f](a,...)) -- was currentcatcodes
--                 elseif processlines and lpegmatch(containseol,f) then
--                     local flushlines = parent.__flushlines or flushlines
--                     flushlines(f)
--                 else
--                     flush(contentcatcodes,f)
--                 end
--             elseif typ == "number" then
--                 if a then
--                     flush(currentcatcodes,f,a,...)
--                 else
--                     flush(currentcatcodes,f)
--                 end
--             elseif typ == "function" then
--                 -- ignored: a ...
--                 flush(currentcatcodes,"{\\cldf{",storefunction(f),"}}") -- todo: ctx|prt|texcatcodes
--             elseif typ == "boolean" then
--                 if f then
--                     if a ~= nil then
--                         local flushlines = parent.__flushlines or flushlines
--                         flushlines(a)
--                     else
--                         flushdirect(currentcatcodes,"\n") -- no \r, else issues with \startlines ... use context.par() otherwise
--                     end
--                 else
--                     if a ~= nil then
--                         -- no command, same as context(a,...)
--                         writer(parent,"",a,...)
--                     else
--                         -- ignored
--                     end
--                 end
--             elseif typ == "thread" then
--                 report_context("coroutines not supported as we cannot yield across boundaries")
--             elseif isnode(f) then -- slow
--              -- writenode(f)
--                 flush(currentcatcodes,"\\cldn{",storenode(f),"}")
--             else
--                 report_context("error: %a gets a weird argument %a","context",f)
--             end
--         end
--     end
--
--     function context.flushnode(n)
--         flush(currentcatcodes,"\\cldn{",storenode(n),"}")
--     end
--
-- end

local defaultcaller = caller

setmetatable(context, { __index = indexer, __call = caller } )

-- now we tweak unprotect and protect

function context.unprotect()
    -- at the lua end
    insert(catcodestack,currentcatcodes)
    currentcatcodes = prtcatcodes
    contentcatcodes = currentcatcodes
    -- at the tex end
    flush("\\unprotect")
end

function context.protect()
    -- at the tex end
    flush("\\protect")
    -- at the lua end
    currentcatcodes = remove(catcodestack) or currentcatcodes
    contentcatcodes = currentcatcodes
end

function context.sprint(...) -- takes catcodes as first argument
    flush(...)
end

function context.fprint(catcodes,fmt,first,...)
    if type(catcodes) == "number" then
        if first then
            flush(catcodes,formatters[fmt](first,...))
        else
            flush(catcodes,fmt)
        end
    else
        if fmt then
            flush(formatters[catcodes](fmt,first,...))
        else
            flush(catcodes)
        end
    end
end

function tex.fprint(fmt,first,...) -- goodie
    if first then
        flush(currentcatcodes,formatters[fmt](first,...))
    else
        flush(currentcatcodes,fmt)
    end
end

-- logging

local trace_stack   = { }

local normalflush       = flush
local normalflushdirect = flushdirect
----- normalflushraw    = flushraw
local normalwriter      = writer
local currenttrace      = nil
local nofwriters        = 0
local nofflushes        = 0

local tracingpermitted  = true

local visualizer = lpeg.replacer {
    { "\n","<<newline>>" },
    { "\r","<<par>>" },
}

statistics.register("traced context", function()
    local used, freed = usedstack()
    local unreachable = used - freed
    if nofwriters > 0 or nofflushes > 0 then
        return format("writers: %s, flushes: %s, maxstack: %s",nofwriters,nofflushes,used,freed,unreachable)
    elseif showstackusage or unreachable > 0 then
        return format("maxstack: %s, freed: %s, unreachable: %s",used,freed,unreachable)
    end
end)

local tracedwriter = function(parent,...) -- also catcodes ?
    nofwriters = nofwriters + 1
    local savedflush       = flush
    local savedflushdirect = flushdirect -- unlikely to be used here
    local t, n = { "w : - : " }, 1
    local traced = function(catcodes,...) -- todo: check for catcodes
        local s = concat({...})
        s = lpegmatch(visualizer,s)
        n = n + 1
        t[n] = s
    end
    flush = function(...)
        normalflush(...)
        if tracingpermitted then
            traced(...)
        end
    end
    flushdirect = function(...)
        normalflushdirect(...)
        if tracingpermitted then
            traced(...)
        end
    end
    normalwriter(parent,...)
    flush       = savedflush
    flushdirect = savedflushdirect
    currenttrace(concat(t))
end

-- we could reuse collapsed

local traced = function(one,two,...)
    if two ~= nil then
        -- only catcodes if 'one' is number
        local catcodes = type(one) == "number" and one
        local arguments = catcodes and { two, ... } or { one, two, ... }
        local collapsed, c = { formatters["f : %s : "](catcodes or '-') }, 1
        for i=1,#arguments do
            local argument = arguments[i]
            local argtype = type(argument)
            c = c + 1
            if argtype == "string" then
                collapsed[c] = lpegmatch(visualizer,argument)
            elseif argtype == "number" then
                collapsed[c] = argument
            else
                collapsed[c] = formatters["<<%S>>"](argument)
            end
        end
        currenttrace(concat(collapsed))
    elseif one ~= nil then
        -- no catcodes
        local argtype = type(one)
        if argtype == "string" then
            currenttrace(formatters["f : - : %s"](lpegmatch(visualizer,one)))
        elseif argtype == "number" then
            currenttrace(formatters["f : - : %s"](one))
        else
            currenttrace(formatters["f : - : <<%S>>"](one))
        end
    end
end

local tracedflush = function(one,two,...)
    nofflushes = nofflushes + 1
    if two ~= nil then
        normalflush(one,two,...)
    else
        normalflush(one)
    end
    if tracingpermitted then
        traced(one,two,...)
    end
end

local tracedflushdirect = function(one,two,...)
    nofflushes = nofflushes + 1
    if two ~= nil then
        normalflushdirect(one,two,...)
    else
        normalflushdirect(one)
    end
    if tracingpermitted then
        traced(one,two,...)
    end
end

local function pushlogger(trace)
    trace = trace or report_context
    insert(trace_stack,currenttrace)
    currenttrace = trace
    --
    flush       = tracedflush
    flushdirect = tracedflushdirect
    writer      = tracedwriter
    --
    context.__flush       = flush
    context.__flushdirect = flushdirect
    --
    return flush, writer, flushdirect
end

local function poplogger()
    currenttrace = remove(trace_stack)
    if not currenttrace then
        flush       = normalflush
        flushdirect = normalflushdirect
        writer      = normalwriter
        --
        context.__flush       = flush
        context.__flushdirect = flushdirect
    end
    return flush, writer, flushdirect
end

local function settracing(v)
    if v then
        return pushlogger(report_context)
    else
        return poplogger()
    end
end

-- todo: share flushers so that we can define in other files

trackers.register("context.trace",settracing)

context.pushlogger  = pushlogger
context.poplogger   = poplogger
context.settracing  = settracing

-- -- untested, no time now:
--
-- local tracestack, tracestacktop = { }, false
--
-- function context.pushtracing(v)
--     insert(tracestack,tracestacktop)
--     if type(v) == "function" then
--         pushlogger(v)
--         v = true
--     else
--         pushlogger()
--     end
--     tracestacktop = v
--     settracing(v)
-- end
--
-- function context.poptracing()
--     poplogger()
--     tracestacktop = remove(tracestack) or false
--     settracing(tracestacktop)
-- end

function context.getlogger()
    return flush, writer, flush_direct
end

local trace_cld = false  trackers.register("context.files", function(v) trace_cld = v end)

do

    -- This is the most reliable way to deal with nested buffers and other
    -- catcode sensitive data.

    local resolve     = resolvers.savers.byscheme
    local validstring = string.valid
    local input       = context.input

    local function viafile(data,tag)
        if data and data ~= "" then
            local filename = resolve("virtual",validstring(tag,"viafile"),data)
         -- context.startregime { "utf" }
            input(filename)
         -- context.stopregime()
        end
    end

    context.viafile    = viafile

    -- experiment for xtables, don't use it elsewhere yet

    local collected    = nil
    local nofcollected = 0
    local sentinel     = string.char(26) -- ASCII SUB character : endoffileasciicode : ignorecatcode
    local level        = 0

    local function collect(c,...) -- can be optimized
        -- snippets
        for i=1,select("#",...) do
            nofcollected = nofcollected + 1
            collected[nofcollected] = (select(i,...))
        end
    end

    -- local function collectdirect(c,...) -- can be optimized
    --     -- lines
    --     for i=1,select("#",...) do
    --         n = n + 1
    --         t[n] = (select(i,...))
    --         n = n + 1
    --         t[n] = "\r"
    --     end
    -- end

    local collectdirect = collect
    local permitted     = true

    -- doesn't work well with tracing do we need to avoid that when
    -- collecting stuff

    function context.startcollecting()
        if level == 0 then
            collected    = { }
            nofcollected = 0
            --
            flush        = collect
            flushdirect  = collectdirect
            permitted    = tracingpermitted
            --
            context.__flush       = flush
            context.__flushdirect = flushdirect
        end
        level = level + 1
    end

    function context.stopcollecting()
        level = level - 1
        if level < 1 then
            flush            = normalflush
            flushdirect      = normalflushdirect
            tracingpermitted = permitted
            --
            context.__flush       = flush
            context.__flushdirect = flushdirect
            --
            viafile(concat(collected,sentinel))
            --
            collected    = nil
            nofcollected = 0
            level        = 0
        end
    end

end

--

function context.runfile(filename)
    local foundname = resolvers.findtexfile(file.addsuffix(filename,"cld")) or ""
    if foundname ~= "" then
        local ok = dofile(foundname)
        if type(ok) == "function" then
            if trace_cld then
                report_context("begin of file %a (function call)",foundname)
            end
            ok()
            if trace_cld then
                report_context("end of file %a (function call)",foundname)
            end
        elseif ok then
            report_context("file %a is processed and returns true",foundname)
        else
            report_context("file %a is processed and returns nothing",foundname)
        end
    else
        report_context("unknown file %a",filename)
    end
end

function context.loadfile(filename)
    context(stripstring(loaddata(resolvers.findfile(filename))))
end

-- some functions

function context.direct(first,...)
    if first ~= nil then
        return writer(context,"",first,...)
    end
end

-- context.delayed (todo: lines)

local delayed = { } context.delayed = delayed -- creates function (maybe also store them)

local function indexer(parent,k)
    local f = function(...)
        local a = { ... }
        return function()
            return context[k](unpack(a))
        end
    end
    parent[k] = f
    return f
end

local function caller(parent,...) -- todo: nodes
    local a = { ... }
    return function()
        return context(unpack(a))
    end
end

-- local function indexer(parent,k)
--     local f = function(a,...)
--         if not a then
--             return function()
--                 return context[k]()
--             end
--         elseif select("#",...) == 0 then
--             return function()
--                 return context[k](a)
--             end
--         elseif a then
--             local t = { ... }
--             return function()
--                 return context[k](a,unpack(t))
--             end
--         end
--     end
--     parent[k] = f
--     return f
-- end
--
-- local function caller(parent,a,...) -- todo: nodes
--     if not a then
--         return function()
--             return context()
--         end
--     elseif select("#",...) == 0 then
--         return function()
--             return context(a)
--         end
--     elseif a then
--         local t = { ... }
--         return function()
--             return context(a,unpack(t))
--         end
--     end
-- end

setmetatable(delayed, { __index = indexer, __call = caller } )

-- context.nested (todo: lines)

local nested = { } context.nested = nested -- creates strings

local function indexer(parent,k) -- not ok when traced
    local f = function(...)
        local t, savedflush, n = { }, flush, 0
        flush = function(c,f,s,...) -- catcodes are ignored
            n = n + 1
            t[n] = s and concat{f,s,...} or f -- optimized for #args == 1
        end
        context[k](...)
        flush = savedflush
        return concat(t)
    end
    parent[k] = f
    return f
end

local function caller(parent,...)
    local t, savedflush, n = { }, flush, 0
    flush = function(c,f,s,...) -- catcodes are ignored
        n = n + 1
        t[n] = s and concat{f,s,...} or f -- optimized for #args == 1
    end
    context(...)
    flush = savedflush
    return concat(t)
end

setmetatable(nested, { __index = indexer, __call = caller } )

-- verbatim

function context.newindexer(catcodes)
    local handler = { }

    local function indexer(parent,k)
        local command = context[k]
        local f = function(...)
            local savedcatcodes = contentcatcodes
            contentcatcodes = catcodes
            command(...)
            contentcatcodes = savedcatcodes
        end
        parent[k] = f
        return f
    end

    local function caller(parent,...)
        local savedcatcodes = contentcatcodes
        contentcatcodes = catcodes
        defaultcaller(parent,...)
        contentcatcodes = savedcatcodes
    end

    setmetatable(handler, { __index = indexer, __call = caller } )

    return handler
end

context.verbatim  = context.newindexer(vrbcatcodes)
context.puretext  = context.newindexer(txtcatcodes)
-------.protected = context.newindexer(prtcatcodes)

-- formatted

local formatted = { }  context.formatted = formatted

-- local function indexer(parent,k)
--     local command = context[k]
--     local f = function(fmt,...)
--         command(formatters[fmt](...))
--     end
--     parent[k] = f
--     return f
-- end

local function indexer(parent,k)
    if type(k) == "string" then
        local c = "\\" .. tostring(generics[k] or k)
        local f = function(first,second,...)
            if first == nil then
                flush(currentcatcodes,c)
            elseif second then
                return writer(parent,c,formatters[first](second,...))
            else
                return writer(parent,c,first)
            end
        end
        parent[k] = f
        return f
    else
        return context -- catch
    end
end

-- local function caller(parent,...)
--     context.fprint(...)
-- end

local function caller(parent,catcodes,fmt,first,...)
    if type(catcodes) == "number" then
        if first then
            flush(catcodes,formatters[fmt](first,...))
        else
            flush(catcodes,fmt)
        end
    else
        if fmt then
            flush(formatters[catcodes](fmt,first,...))
        else
            flush(catcodes)
        end
    end
end

setmetatable(formatted, { __index = indexer, __call = caller } )

-- metafun (this will move to another file)

local metafun = { } context.metafun = metafun

local mpdrawing = "\\MPdrawing"

local function caller(parent,f,a,...)
    if not parent then
        -- skip
    elseif f then
        local typ = type(f)
        if typ == "string" then
            if a then
                flush(currentcatcodes,mpdrawing,"{",formatters[f](a,...),"}")
            else
                flush(currentcatcodes,mpdrawing,"{",f,"}")
            end
        elseif typ == "number" then
            if a then
                flush(currentcatcodes,mpdrawing,"{",f,a,...,"}")
            else
                flush(currentcatcodes,mpdrawing,"{",f,"}")
            end
        elseif typ == "function" then
            -- ignored: a ...
            flush(currentcatcodes,mpdrawing,"{\\cldl",store_(f),"}")
         -- flush(currentcatcodes,mpdrawing,"{",store_(f),"}")
        elseif typ == "boolean" then
            -- ignored: a ...
            if f then
                flush(currentcatcodes,mpdrawing,"{^^M}")
            else
                report_context("warning: %a gets argument 'false' which is currently unsupported","metafun")
            end
        else
            report_context("error: %a gets a weird argument %a","metafun",tostring(f))
        end
    end
end

setmetatable(metafun, { __call = caller } )

function metafun.start()
    context.resetMPdrawing()
end

function metafun.stop()
    context.MPdrawingdonetrue()
    context.getMPdrawing()
end

function metafun.color(name)
    return formatters[ [[\MPcolor{%s}]] ](name)
end

-- metafun.delayed

local delayed = { } metafun.delayed = delayed

local function indexer(parent,k)
    local f = function(...)
        local a = { ... }
        return function()
            return metafun[k](unpack(a))
        end
    end
    parent[k] = f
    return f
end


local function caller(parent,...)
    local a = { ... }
    return function()
        return metafun(unpack(a))
    end
end

setmetatable(delayed, { __index = indexer, __call = caller } )

-- helpers:

function context.concat(...)
    context(concat(...))
end

local p_texescape = patterns.texescape

function context.escaped(s)
    return context(lpegmatch(p_texescape,s) or s)
end

-- templates

local single  = lpegP("%")
local double  = lpegP("%%")
local lquoted = lpegP("%[")
local rquoted = lpegP("]%")

local start = [[
local texescape = lpeg.patterns.texescape
local lpegmatch = lpeg.match
return function(variables) return
]]

local stop  = [[
end
]]

local replacer = lpegP { "parser",
    parser   = lpegCs(lpegCc(start) * lpegV("step") * (lpegCc("..") * lpegV("step"))^0 * lpegCc(stop)),
    unquoted = (lquoted/'') * ((lpegC((1-rquoted)^1)) / "lpegmatch(texescape,variables['%0'] or '')" ) * (rquoted/''),
    escape   = double/'%%',
    key      = (single/'') * ((lpegC((1-single)^1)) / "(variables['%0'] or '')" ) * (single/''),
    step     = lpegV("unquoted")
             + lpegV("escape")
             + lpegV("key")
             + lpegCc("\n[===[") * (1 - lpegV("unquoted") - lpegV("escape") - lpegV("key"))^1 * lpegCc("]===]\n"),
}

local templates = { }

local function indexer(parent,k)
    local v = lpegmatch(replacer,k)
    if not v then
        v = "error: no valid template (1)"
    else
        v = loadstring(v)
        if type(v) ~= "function" then
            v = "error: no valid template (2)"
        else
            v = v()
            if not v then
                v = "error: no valid template (3)"
            end
        end
    end
    if type(v) == "function" then
        local f = function(first,second)
            if second then
                pushcatcodes(first)
                flushlines(v(second))
                popcatcodes()
            else
                flushlines(v(first))
            end
        end
        parent[k] = f
        return f
    else
        return function()
            flush(v)
        end
    end

end

local function caller(parent,k,...)
    return parent[k](...)
end

setmetatable(templates, { __index = indexer, __call = caller } )

function context.template(template,...)
    context(templates[template](...))
end

context.templates = templates

-- The above is a bit over the top as we could also stick to a simple context.replace
-- which is fast enough anyway, but the above fits in nicer, also with the catcodes.
--
-- local replace = utilities.templates.replace
--
-- function context.template(template,variables)
--     context(replace(template,variables))
-- end
