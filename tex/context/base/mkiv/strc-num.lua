if not modules then modules = { } end modules ['strc-num'] = {
    version   = 1.001,
    comment   = "companion to strc-num.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local next, type, tonumber = next, type, tonumber
local min, max = math.min, math.max
local insert, remove, copy = table.insert, table.remove, table.copy
local texsetcount = tex.setcount

-- Counters are managed here. They can have multiple levels which makes it easier to synchronize
-- them. Synchronization is sort of special anyway, as it relates to document structuring.

local context           = context

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local setmetatablecall  = table.setmetatablecall

local trace_counters    = false  trackers.register("structures.counters", function(v) trace_counters = v end)
local report_counters   = logs.reporter("structure","counters")

local implement         = interfaces.implement

local structures        = structures
local helpers           = structures.helpers
local sections          = structures.sections
local counters          = structures.counters
local documents         = structures.documents

local variables         = interfaces.variables
local v_start           = variables.start
local v_page            = variables.page
local v_reverse         = variables.reverse
local v_first           = variables.first
local v_next            = variables.next
local v_previous        = variables.previous
local v_prev            = variables.prev
local v_last            = variables.last
----- v_no              = variables.no

-- states: start stop none reset

-- specials are used for counters that are set and incremented in special ways, like
-- pagecounters that get this treatment in the page builder

counters.specials       = counters.specials or { }
local counterspecials   = counters.specials

local counterranges, tbs = { }, 0

counters.collected = allocate()
counters.tobesaved = counters.tobesaved or { }
counters.data      = counters.data or { }

storage.register("structures/counters/data",      counters.data,      "structures.counters.data")
storage.register("structures/counters/tobesaved", counters.tobesaved, "structures.counters.tobesaved")

local collected   = counters.collected
local tobesaved   = counters.tobesaved
local counterdata = counters.data

local function initializer() -- not really needed
    collected   = counters.collected
    tobesaved   = counters.tobesaved
    counterdata = counters.data
end

local function finalizer()
    for name, cd in next, counterdata do
        local cs = tobesaved[name]
        local data = cd.data
        for i=1,#data do
            local d = data[i]
            local r = d.range
            cs[i][r] = d.number
            d.range = r + 1
        end
    end
end

job.register('structures.counters.collected', tobesaved, initializer, finalizer)

local constructor = { -- maybe some day we will provide an installer for more variants

    last = function(t,name,i)
        local cc = collected[name]
        local stop = (cc and cc[i] and cc[i][t.range]) or 0 -- stop is available for diagnostics purposes only
        t.stop = stop
        if t.offset then
            return stop - t.step
        else
            return stop
        end
    end,

    first = function(t,name,i)
        local start = t.start
        if start > 0 then
            return start -- brrr
        elseif t.offset then
            return start + t.step + 1
        else
            return start + 1
        end
    end,

    prev = function(t,name,i)
        return max(t.first,t.number-1) -- todo: step
    end,

    previous = function(t,name,i)
        return max(t.first,t.number-1) -- todo: step
    end,

    next = function(t,name,i)
        return min(t.last,t.number+1) -- todo: step
    end,

    backward =function(t,name,i)
        if t.number - 1 < t.first then
            return t.last
        else
            return t.previous
        end
    end,

    forward = function(t,name,i)
        if t.number + 1 > t.last then
            return t.first
        else
            return t.next
        end
    end,

    subs = function(t,name,i)
        local cc = collected[name]
        t.subs = (cc and cc[i+1] and cc[i+1][t.range]) or 0
        return t.subs
    end,

}

local function dummyconstructor(t,name,i)
    return nil -- was 0, but that is fuzzy in testing for e.g. own
end

setmetatableindex(constructor,function(t,k)
 -- if trace_counters then
 --     report_counters("unknown constructor %a",k)
 -- end
    return dummyconstructor
end)

local function enhance()
    for name, cd in next, counterdata do
        local data = cd.data
        for i=1,#data do
            local ci = data[i]
            setmetatableindex(ci, function(t,s) return constructor[s](t,name,i) end)
        end
    end
    enhance = nil
end

local function allocate(name,i) -- can be metatable but it's a bit messy
    local cd = counterdata[name]
    if not cd then
        cd = {
            level   = 1,
         -- block   = "", -- todo
            numbers = nil,
            state   = v_start, -- true
            data    = { },
            saved   = { },
        }
        tobesaved[name]   = { }
        counterdata[name] = cd
    end
    cd = cd.data
    local ci = cd[i]
    if not ci then
        for i=1,i do
            if not cd[i] then
                ci = {
                    number = 0,
                    start  = 0,
                    saved  = 0,
                    step   = 1,
                    range  = 1,
                    offset = false,
                    stop   = 0, -- via metatable: last, first, stop only for tracing
                }
                setmetatableindex(ci, function(t,s) return constructor[s](t,name,i) end)
                cd[i] = ci
                tobesaved[name][i] = { }
            end
        end
    elseif enhance then
        enhance() -- not stored in bytecode
    end
    return ci
end

local pattern   = lpeg.P(variables.by)^-1 * lpeg.C(lpeg.P(1)^1)
local lpegmatch = lpeg.match

function counters.way(way)
    if not way or way == "" then
        return ""
    else
        return lpegmatch(pattern,way)
    end
end

implement {
    name      = "way",
    actions   = { counters.way, context },
    arguments = "string"
}


function counters.record(name,i)
    return allocate(name,i or 1)
end

local function savevalue(name,i)
    if name then
        local cd = counterdata[name].data[i]
        local cs = tobesaved[name][i]
        local cc = collected[name]
        if trace_counters then
            report_counters("action %a, counter %s, value %s","save",name,cd.number)
        end
        local cr = cd.range
        local old = (cc and cc[i] and cc[i][cr]) or 0
        local number = cd.number
        if cd.method == v_page then
            -- we can be one page ahead
            number = number - 1
        end
        cs[cr] = (number >= 0) and number or 0
        cd.range = cr + 1
        return old
    else
        return 0
    end
end

function counters.define(specification)
    local name = specification.name
    if name and name ~= "" then
        -- todo: step
        local d = allocate(name,1)
        d.start = tonumber(specification.start) or 0
        d.state = v_state or ""
        local counter = specification.counter
        if counter and counter ~= "" then
            d.counter = counter -- only for special purposes, cannot be false
            d.method  = specification.method -- frozen at define time
        end
    end
end

function counters.raw(name)
    return counterdata[name]
end

function counters.compact(name,level,onlynumbers)
    local cd = counterdata[name]
    if cd then
        local data    = cd.data
        local compact = { }
        for i=1,level or #data do
            local d = data[i]
            if d.number ~= 0 then
                compact[i] = (onlynumbers and d.number) or d
            end
        end
        return compact
    end
end

-- depends on when incremented, before or after (driven by d.offset)

function counters.previous(name,n)
    return allocate(name,n).previous
end

function counters.next(name,n)
    return allocate(name,n).next
end

counters.prev = counters.previous

function counters.currentvalue(name,n)
    return allocate(name,n).number
end

function counters.first(name,n)
    return allocate(name,n).first
end

function counters.last(name,n)
    return allocate(name,n).last
end

function counters.subs(name,n)
    return counterdata[name].data[n].subs or 0
end

local function setvalue(name,tag,value)
    local cd = counterdata[name]
    if cd then
        cd[tag] = value
    end
end

counters.setvalue = setvalue

function counters.setstate(name,value) -- true/false
    value = variables[value]
    if value then
        setvalue(name,"state",value)
    end
end

function counters.setlevel(name,value)
    setvalue(name,"level",value)
end

function counters.setoffset(name,value)
    setvalue(name,"offset",value)
end

local function synchronize(name,d)
    local dc = d.counter
    if dc then
        if trace_counters then
            report_counters("action %a, name %a, counter %a, value %a","synchronize",name,dc,d.number)
        end
        texsetcount("global",dc,d.number)
    end
    local cs = counterspecials[name]
    if cs then
        if trace_counters then
            report_counters("action %a, name %a, counter %a","synccommand",name,dc)
        end
        cs(name)
    end
end

local function reset(name,n)
    local cd = counterdata[name]
    if cd then
        for i=n or 1,#cd.data do
            local d = cd.data[i]
            savevalue(name,i)
            local number = d.start or 0
            d.number = number
            d.own = nil
            if trace_counters then
                report_counters("action %a, name %a, sub %a, value %a","reset",name,i,number)
            end
            synchronize(name,d)
        end
        cd.numbers = nil
    else
    end
end

local function set(name,n,value)
    local cd = counterdata[name]
    if cd then
        local d = allocate(name,n)
        local number = value or 0
        d.number = number
        d.own = nil
        if trace_counters then
            report_counters("action %a, name %a, sub %a, value %a","set",name,"no",number)
        end
        synchronize(name,d)
    end
end

local function check(name,data,start,stop)
    for i=start or 1,stop or #data do
        local d = data[i]
        savevalue(name,i)
        local number = d.start or 0
        d.number = number
        d.own = nil
        if trace_counters then
            report_counters("action %a, name %a, sub %a, value %a","check",name,i,number)
        end
        synchronize(name,d)
    end
end


local function setown(name,n,value)
    local cd = counterdata[name]
    if cd then
        local d = allocate(name,n)
        d.own = value
        d.number = (d.number or d.start or 0) + (d.step or 0)
        local level = cd.level
        if not level or level == -1 then
            -- -1 is signal that we reset manually
        elseif level > 0 or level == -3 then
            check(name,d,n+1)
        elseif level == 0 then
            -- happens elsewhere, check this for block
        end
        synchronize(name,d)
    end
end

local function restart(name,n,newstart,noreset)
    local cd = counterdata[name]
    if cd then
        newstart = tonumber(newstart)
        if newstart then
            local d = allocate(name,n)
            d.start = newstart
            if not noreset then  -- why / when needed ?
                reset(name,n) -- hm
            end
        end
    end
end

function counters.save(name) -- or just number
    local cd = counterdata[name]
    if cd then
        insert(cd.saved,copy(cd.data))
    end
end

function counters.restore(name)
    local cd = counterdata[name]
    if not cd then
        report_counters("invalid restore, no counter %a",name)
        return
    end
    local saved = cd.saved
    if not saved then
        -- is ok
    elseif #saved > 0 then
        cd.data = remove(saved)
    else
        report_counters("restore without save for counter %a",name)
    end
end

local function add(name,n,delta)
    local cd = counterdata[name]
    if cd and (cd.state == v_start or cd.state == "") then
        local data = cd.data
        local d = allocate(name,n)
        d.number = (d.number or d.start or 0) + delta*(d.step or 0)
     -- d.own = nil
        local level = cd.level
        if not level or level == -1 then
            -- -1 is signal that we reset manually
            if trace_counters then
                report_counters("action %a, name %a, sub %a, how %a","add",name,"no","no checking")
            end
        elseif level == -2 then
            -- -2 is signal that we work per text
            if trace_counters then
                report_counters("action %a, name %a, sub %a, how %a","add",name,"text","checking")
            end
            check(name,data,n+1)
        elseif level > 0 or level == -3 then
            -- within countergroup
            if trace_counters then
                report_counters("action %a, name %a, sub %a, how %a","add",name,level,"checking within group")
            end
            check(name,data,n+1)
        elseif level == 0 then
            -- happens elsewhere
            if trace_counters then
                report_counters("action %a, name %a, sub %a, how %a","add",name,level,"no checking")
            end
        else
            if trace_counters then
                report_counters("action %a, name %a, sub %a, how %a","add",name,"unknown","no checking")
            end
        end
        synchronize(name,d)
        return d.number -- not needed
    end
    return 0
end

function counters.check(level)
    for name, cd in next, counterdata do
        if level > 0 and cd.level == -3 then -- could become an option
            if trace_counters then
                report_counters("action %a, name %a, sub %a, detail %a","reset",name,level,"head")
            end
            reset(name)
        elseif cd.level == level then
            if trace_counters then
                report_counters("action %a, name %a, sub %a, detail %a","reset",name,level,"normal")
            end
            reset(name)
        end
    end
end

local function get(name,n,key)
    local d = allocate(name,n)
    d = d and d[key]
    if not d then
        return 0
    elseif type(d) == "function" then
        return d()
    else
        return d
    end
end

counters.reset   = reset
counters.set     = set
counters.add     = add
counters.get     = get
counters.setown  = setown
counters.restart = restart

function counters.value(name,n) -- what to do with own
    return get(name,n or 1,'number') or 0
end

function counters.converted(name,spec) -- name can be number and reference to storage
    local cd
    if type(name) == "number" then
        cd = specials.retrieve("counter",name)
        if cd then
            cd = cd.counter
        end
    else
        cd = counterdata[name]
    end
    if cd then
        local spec       = spec or { }
        local numbers    = { }
        local ownnumbers = { }
        local reverse    = spec.order == v_reverse
        local kind       = spec.type or "number"
        local data       = cd.data
        for k=1,#data do
            local v = data[k]
            -- somewhat messy, what if subnr? only last must honour kind?
            local vn
            if v.own then
                numbers[k]    = v.number
                ownnumbers[k] = v.own
            else
                if kind == v_first then
                    vn = v.first
                elseif kind == v_next then
                    vn = v.next
                elseif kind == v_prev or kind == v_previous then
                    vn = v.prev
                elseif kind == v_last then
                    vn = v.last
                else
                    vn = v.number
                    if reverse then
                        local vf = v.first
                        local vl = v.last
                        if vl > 0 then
                        --  vn = vl - vn + 1 + vf
                            vn = vl - vn + vf -- see testbed for test
                        end
                    end
                end
                numbers[k]    = vn or v.number
                ownnumbers[k] = nil
            end
        end
        cd.numbers    = numbers
        cd.ownnumbers = ownnumbers
        sections.typesetnumber(cd,'number',spec)
        cd.numbers    = nil
        cd.ownnumbers = nil
    end
end

-- interfacing

local function showcounter(name)
    local cd = counterdata[name]
    if cd then
        context("[%s:",name)
        local data = cd.data
        for i=1,#data do
            local d = data[i]
            context(" (%s: %s,%s,%s s:%s r:%s)",i,d.start or 0,d.number or 0,d.last,d.step or 0,d.range or 0)
        end
        context("]")
    end
end

-- the noreset is somewhat messy ... always false messes up e.g. itemize but true the pagenumbers
--
-- if this fails i'll clean up this still somewhat experimental mechanism (but i need use cases)

local function checkcountersetup(name,level,start,state)
    local noreset = true -- level > 0 -- was true
    counters.restart(name,1,start,noreset) -- was true
    counters.setstate(name,state)
    counters.setlevel(name,level)
    sections.setchecker(name,level,counters.reset)
end

--

implement { name = "addcounter",              actions = add,     arguments = { "string", "integer", "integer" } }
implement { name = "setcounter",              actions = set,     arguments = { "string", 1, "integer" } }
implement { name = "setowncounter",           actions = setown,  arguments = { "string", 1, "string" } }
implement { name = "restartcounter",          actions = restart, arguments = { "string", 1, "integer" } }
implement { name = "resetcounter",            actions = reset,   arguments = { "string", 1 } }
implement { name = "incrementcounter",        actions = add,     arguments = { "string", 1,  1 } }
implement { name = "decrementcounter",        actions = add,     arguments = { "string", 1, -1 } }

implement { name = "setsubcounter",           actions = set,     arguments = { "string", "integer", "integer" } }
implement { name = "setownsubcounter",        actions = setown,  arguments = { "string", "integer", "string" } }
implement { name = "restartsubcounter",       actions = restart, arguments = { "string", "integer", "integer" } }
implement { name = "resetsubcounter",         actions = reset,   arguments = { "string", "integer" } }
implement { name = "incrementsubcounter",     actions = add,     arguments = { "string", "integer",  1 } }
implement { name = "decrementsubcounter",     actions = add,     arguments = { "string", "integer", -1 } }

implement { name = "rawcountervalue",         actions = { counters.raw     , context }, arguments = { "string", 1 } }
implement { name = "countervalue",            actions = { counters.value   , context }, arguments = { "string", 1 } }
implement { name = "lastcountervalue",        actions = { counters.last    , context }, arguments = { "string", 1 } }
implement { name = "firstcountervalue",       actions = { counters.first   , context }, arguments = { "string", 1 } }
implement { name = "nextcountervalue",        actions = { counters.next    , context }, arguments = { "string", 1 } }
implement { name = "previouscountervalue",    actions = { counters.previous, context }, arguments = { "string", 1 } }
implement { name = "subcountervalues",        actions = { counters.subs    , context }, arguments = { "string", 1 } }

implement { name = "rawsubcountervalue",      actions = { counters.raw     , context }, arguments = { "string", "integer" } }
implement { name = "subcountervalue",         actions = { counters.value   , context }, arguments = { "string", "integer" } }
implement { name = "lastsubcountervalue",     actions = { counters.last    , context }, arguments = { "string", "integer" } }
implement { name = "firstsubcountervalue",    actions = { counters.first   , context }, arguments = { "string", "integer" } }
implement { name = "nextsubcountervalue",     actions = { counters.next    , context }, arguments = { "string", "integer" } }
implement { name = "previoussubcountervalue", actions = { counters.previous, context }, arguments = { "string", "integer" } }
implement { name = "subsubcountervalues",     actions = { counters.subs    , context }, arguments = { "string", "integer" } }

implement { name = "savecounter",             actions = counters.save,    arguments = "string" }
implement { name = "restorecounter",          actions = counters.restore, arguments = "string" }

implement { name = "incrementedcounter",      actions = { add, context }, arguments = { "string", 1,  1 } }
implement { name = "decrementedcounter",      actions = { add, context }, arguments = { "string", 1, -1 } }

implement { name = "showcounter",             actions = showcounter,       arguments = "string" }  -- todo
implement { name = "checkcountersetup",       actions = checkcountersetup, arguments = { "string", "integer", "integer", "string" } }

setmetatablecall(counterdata,function(t,k) return t[k] end)

implement { name = "doifelsecounter", actions = { counterdata, commands.doifelse }, arguments = "string" }
implement { name = "doifcounter",     actions = { counterdata, commands.doif     }, arguments = "string" }
implement { name = "doifnotcounter",  actions = { counterdata, commands.doifnot  }, arguments = "string" }

implement {
    name      = "definecounter",
    actions   = counters.define,
    arguments = {
        {
            { "name" } ,
            { "start", "integer" },
            { "counter" },
            { "method" },
        }
    }
}

------------------------------------------------------------------
------------------------------------------------------------------

-- -- move to strc-pag.lua
--
-- function counters.analyze(name,counterspecification)
--     local cd = counterdata[name]
--     -- safeguard
--     if not cd then
--         return false, false, "no counter data"
--     end
--     -- section data
--     local sectiondata = sections.current()
--     if not sectiondata then
--         return cd, false, "not in section"
--     end
--     local references = sectiondata.references
--     if not references then
--         return cd, false, "no references"
--     end
--     local section = references.section
--     if not section then
--         return cd, false, "no section"
--     end
--     sectiondata = sections.collected[references.section]
--     if not sectiondata then
--         return cd, false, "no section data"
--     end
--     -- local preferences
--     local no = v_no
--     if counterspecification and counterspecification.prefix == no then
--         return cd, false, "current spec blocks prefix"
--     end
--     -- stored preferences (not used)
--     if cd.prefix == no then
--         return cd, false, "entry blocks prefix"
--     end
--     -- sectioning
--     -- if sectiondata.prefix == no then
--     --     return false, false, "sectiondata blocks prefix"
--     -- end
--     -- final verdict
--     return cd, sectiondata, "okay"
-- end
--
-- function counters.prefixedconverted(name,prefixspec,numberspec)
--     local cd, prefixdata, result = counters.analyze(name,prefixspec)
--     if cd then
--         if prefixdata then
--             sections.typesetnumber(prefixdata,"prefix",prefixspec or false,cd or false)
--         end
--         counters.converted(name,numberspec)
--     end
-- end
