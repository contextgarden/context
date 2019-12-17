if not modules then modules = { } end modules ["page-mix"] = {
    version   = 1.001,
    comment   = "companion to page-mix.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- inserts.getname(name)

-- local node, tex = node, tex
-- local nodes, interfaces, utilities = nodes, interfaces, utilities
-- local trackers, logs, storage = trackers, logs, storage
-- local number, table = number, table

-- todo: explore vsplit (for inserts)

local next, type = next, type
local concat = table.concat
local ceil = math.ceil

local trace_state   = false  trackers.register("mixedcolumns.trace",   function(v) trace_state   = v end)
local trace_details = false  trackers.register("mixedcolumns.details", function(v) trace_details = v end)

local report_state = logs.reporter("mixed columns")

local context             = context

local nodecodes           = nodes.nodecodes

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local kern_code           = nodecodes.kern
local glue_code           = nodecodes.glue
local penalty_code        = nodecodes.penalty
local insert_code         = nodecodes.ins
local mark_code           = nodecodes.mark
local rule_code           = nodecodes.rule

local nuts                = nodes.nuts
local tonode              = nuts.tonode
local listtoutf           = nodes.listtoutf

local vpack               = nuts.vpack
local flushnode           = nuts.flush
local concatnodes         = nuts.concat
local slidenodes          = nuts.slide -- ok here as we mess with prev links intermediately

local setlink             = nuts.setlink
local setlist             = nuts.setlist
local setnext             = nuts.setnext
local setprev             = nuts.setprev
local setbox              = nuts.setbox
local setwhd              = nuts.setwhd
local setheight           = nuts.setheight
local setdepth            = nuts.setdepth

local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getid               = nuts.getid
local getlist             = nuts.getlist
local getsubtype          = nuts.getsubtype
local getbox              = nuts.getbox
local getattribute        = nuts.getattribute
local getwhd              = nuts.getwhd
local getkern             = nuts.getkern
local getpenalty          = nuts.getpenalty
local getwidth            = nuts.getwidth
local getheight           = nuts.getheight
local getdepth            = nuts.getdepth

local theprop             = nuts.theprop

local nodepool            = nuts.pool

local new_hlist           = nodepool.hlist
local new_vlist           = nodepool.vlist
local new_glue            = nodepool.glue

local points              = number.points

local settings_to_hash    = utilities.parsers.settings_to_hash

local variables           = interfaces.variables
local v_yes               = variables.yes
local v_global            = variables["global"]
local v_local             = variables["local"]
local v_none              = variables.none
local v_halfline          = variables.halfline

local context             = context
local implement           = interfaces.implement

pagebuilders              = pagebuilders or { }
pagebuilders.mixedcolumns = pagebuilders.mixedcolumns or { }
local mixedcolumns        = pagebuilders.mixedcolumns

local a_checkedbreak      = attributes.private("checkedbreak")
local forcedbreak         = -123

-- initializesplitter(specification)
-- cleanupsplitter()

-- Inserts complicate matters a lot. In order to deal with them well, we need to
-- distinguish several cases.
--
-- (1) full page columns: firstcolumn, columns, lastcolumn, page
-- (2) mid page columns : firstcolumn, columns, lastcolumn, page
--
-- We need to collect them accordingly.

local function collectinserts(result,nxt,nxtid)
    local inserts, currentskips, nextskips, inserttotal = { }, 0, 0, 0
    local i = result.i
    if not i then
        i = 0
        result.i = i
    end
    while nxt do
        if nxtid == insert_code then
            i = i + 1
            result.i = i
            inserttotal = inserttotal + getheight(nxt) -- height includes depth (hm, still? needs checking)
            local s = getsubtype(nxt)
            local c = inserts[s]
            if trace_details then
                report_state("insert of class %s found",s)
            end
            if not c then
                local width = structures.notes.check_spacing(s,i) -- before
                c = { }
                inserts[s] = c
                if not result.inserts[s] then
                    currentskips = currentskips + width
                end
                nextskips = nextskips + width
            end
            c[#c+1] = nxt
        elseif nxtid == mark_code then
            if trace_details then
                report_state("mark found")
            end
        else
            break
        end
        nxt = getnext(nxt)
        if nxt then
            nxtid = getid(nxt)
        else
            break
        end
    end
    return nxt, inserts, currentskips, nextskips, inserttotal
end

local function appendinserts(ri,inserts)
    for class, collected in next, inserts do
        local ric = ri[class]
        if not ric then
            -- assign to collected
            ri[class] = collected
        else
            -- append to collected
            for j=1,#collected do
                ric[#ric+1] = collected[j]
            end
        end
    end
end

local function discardtopglue(current,discarded)
    local size = 0
    while current do
        local id = getid(current)
        if id == glue_code then
            size = size + getwidth(current)
            discarded[#discarded+1] = current
            current = getnext(current)
        elseif id == penalty_code then
            if getpenalty(current) == forcedbreak then
                discarded[#discarded+1] = current
                current = getnext(current)
                while current and getid(current) == glue_code do
                    size = size + getwidth(current)
                    discarded[#discarded+1] = current
                    current = getnext(current)
                end
            else
                discarded[#discarded+1] = current
                current = getnext(current)
            end
        else
            break
        end
    end
    if current then
        setprev(current) -- prevent look back
    end
    return current, size
end

local function stripbottomglue(results,discarded)
    local height = 0
    for i=1,#results do
        local r = results[i]
        local t = r.tail
        while t and t ~= r.head do
            local prev = getprev(t)
            if not prev then
                break
            end
            local id = getid(t)
            if id == penalty_code then
                if getpenalty(t) == forcedbreak then
                    break
                else
                    discarded[#discarded+1] = t
                    r.tail = prev
                    t = prev
                end
            elseif id == glue_code then
                discarded[#discarded+1] = t
                local width = getwidth(t)
                if trace_state then
                    report_state("columns %s, discarded bottom glue %p",i,width)
                end
                r.height = r.height - width
                r.tail = prev
                t = prev
            else
                break
            end
        end
        if r.height > height then
            height = r.height
        end
    end
    return height
end

local function preparesplit(specification) -- a rather large function
    local box = specification.box
    if not box then
        report_state("fatal error, no box")
        return
    end
    local list = getbox(box)
    if not list then
        report_state("fatal error, no list")
        return
    end
    local head = getlist(list) or specification.originalhead
    if not head then
        report_state("fatal error, no head")
        return
    end
    slidenodes(head) -- we can have set prev's to nil to prevent backtracking
    local discarded      = { }
    local originalhead   = head
    local originalwidth  = specification.originalwidth  or getwidth(list)
    local originalheight = specification.originalheight or getheight(list)
    local current        = head
    local skipped        = 0
    local height         = 0
    local depth          = 0
    local skip           = 0
    local handlenotes    = specification.notes or false
    local splitmethod    = specification.splitmethod or false
    if splitmethod == v_none then
        splitmethod = false
    end
    local options     = settings_to_hash(specification.option or "")
    local stripbottom = specification.alternative == v_local
    local cycle       = specification.cycle or 1
    local nofcolumns  = specification.nofcolumns or 1
    if nofcolumns == 0 then
        nofcolumns = 1
    end
    local preheight  = specification.preheight or 0
    local extra      = specification.extra or 0
    local maxheight  = specification.maxheight
    local optimal    = originalheight/nofcolumns
    local noteheight = specification.noteheight or 0

    maxheight = maxheight - noteheight

    if specification.balance ~= v_yes then
        optimal = maxheight
    end
    local topback   = 0
    local target    = optimal + extra
    local overflow  = target > maxheight - preheight
    local threshold = specification.threshold or 0
    if overflow then
        target = maxheight - preheight
    end
    if trace_state then
        report_state("cycle %s, maxheight %p, preheight %p, target %p, overflow %a, extra %p",
            cycle, maxheight, preheight , target, overflow, extra)
    end
    local results = { }
    for i=1,nofcolumns do
        results[i] = {
            head    = false,
            tail    = false,
            height  = 0,
            depth   = 0,
            inserts = { },
            delta   = 0,
            back    = 0,
        }
    end

    local column      = 1
    local line        = 0
    local result      = results[1]
    local lasthead    = nil
    local rest        = nil
    local lastlocked  = nil
    local lastcurrent = nil
    local lastcontent = nil
    local backtracked = false

    if trace_state then
        report_state("setting collector to column %s",column)
    end

    local function unlock(case,penalty)
        if lastlocked then
            if trace_state then
                report_state("penalty %s, unlocking in column %s, case %i",penalty or "-",column,case)
            end
            lastlocked  = nil
        else
            if trace_state then
                report_state("penalty %s, ignoring in column %s, case %i",penalty or "-",column,case)
            end
        end
        lastcurrent = nil
        lastcontent = nil
    end

    local function lock(case,penalty,current)
        if trace_state then
            report_state("penalty %s, locking in column %s, case %i",penalty,column,case)
        end
        lastlocked  = penalty
        lastcurrent = current or lastcurrent
        lastcontent = nil
    end

    local function backtrack(start)
        local current = start
        -- first skip over glue and penalty
        while current do
            local id = getid(current)
            if id == glue_code then
                if trace_state then
                    report_state("backtracking over %s in column %s, value %p","glue",column,getwidth(current))
                end
                current = getprev(current)
            elseif id == penalty_code then
                if trace_state then
                    report_state("backtracking over %s in column %s, value %i","penalty",column,getpenalty(current))
                end
                current = getprev(current)
            else
                break
            end
        end
        -- then skip over content
        while current do
            local id = getid(current)
            if id == glue_code then
                if trace_state then
                    report_state("quitting at %s in column %s, value %p","glue",column,getwidth(current))
                end
                break
            elseif id == penalty_code then
                if trace_state then
                    report_state("quitting at %s in column %s, value %i","penalty",column,getpenalty(current))
                end
                break
            else
                current = getprev(current)
            end
        end
        if not current then
            if trace_state then
                report_state("no effective backtracking in column %s",column)
            end
            current = start
        end
        return current
    end

    local function gotonext()
        if lastcurrent then
            if current ~= lastcurrent then
                if trace_state then
                    report_state("backtracking to preferred break in column %s",column)
                end
                -- todo: also remember height/depth
                if true then -- todo: option to disable this
                    current = backtrack(lastcurrent) -- not ok yet
                else
                    current = lastcurrent
                end
                backtracked = true
            end
            lastcurrent = nil
            if lastlocked then
                if trace_state then
                    report_state("unlocking in column %s",column)
                end
                lastlocked = nil
            end
        end
        if head == lasthead then
            if trace_state then
                report_state("empty column %s, needs more work",column)
            end
            rest = current
            return false, 0
        else
            lasthead = head
            result.head = head
            if current == head then
                result.tail = head
            else
                result.tail = getprev(current)
            end
            result.height = height
            result.depth  = depth
        end
        head   = current
        height = 0
        depth  = 0
        if column == nofcolumns then
            column = 0 -- nicer in trace
            rest   = head
            return false, 0
        else
            local skipped
            column = column + 1
            result = results[column]
            if trace_state then
                report_state("setting collector to column %s",column)
            end
            current, skipped = discardtopglue(current,discarded)
            if trace_details and skipped ~= 0 then
                report_state("check > column 1, discarded %p",skipped)
            end
            head = current
            return true, skipped
        end
    end

    local function checked(advance,where,locked)
        local total   = skip + height + depth + advance
        local delta   = total - target
        local state   = "same"
        local okay    = false
        local skipped = 0
        local curcol  = column
        if delta > threshold then
            result.delta = delta
            okay, skipped = gotonext()
            if okay then
                state = "next"
            else
                state = "quit"
            end
        end
        if trace_details then
            report_state("%-8s > column %s, delta %p, threshold %p, advance %p, total %p, target %p => %a (height %p, depth %p, skip %p)",
                where,curcol,delta,threshold,advance,total,target,state,height,depth,skip)
        end
        return state, skipped
    end

    current, skipped = discardtopglue(current,discarded)
    if trace_details and skipped ~= 0 then
        report_state("check > column 1, discarded %p",skipped)
    end

    -- problem: when we cannot break after a list (and we only can expect same-page situations as we don't
    -- care too much about weighted breaks here) we should sort of look ahead or otherwise be able to push
    -- back inserts and so
    --
    -- ok, we could use vsplit but we don't have that one opened up yet .. maybe i should look into the c-code
    -- .. something that i try to avoid so let's experiment more before we entry dirty trick mode
    --
    -- what if we can do a preroll in lua, get head and tail and then slice of a bit and push that ahead

    head = current

    local function process_skip(current,nxt)
        local advance = getwidth(current)
        if advance ~= 0 then
            local state, skipped = checked(advance,"glue")
            if trace_state then
                report_state("%-8s > column %s, state %a, advance %p, height %p","glue",column,state,advance,height)
                if skipped ~= 0 then
                    report_state("%-8s > column %s, discarded %p","glue",column,skipped)
                end
            end
            if state == "quit" then
                return true
            end
            height = height + depth + skip
            depth  = 0
            if advance < 0 then
                height = height + advance
                skip = 0
                if height < 0 then
                    height = 0
                end
            else
                skip = height > 0 and advance or 0
            end
            if trace_state then
                report_state("%-8s > column %s, height %p, depth %p, skip %p","glue",column,height,depth,skip)
            end
        else
            -- what else? ignore? treat as valid as usual?
        end
        if lastcontent then
            unlock(1)
        end
    end

    local function process_kern(current,nxt)
        local advance = getkern(current)
        if advance ~= 0 then
            local state, skipped = checked(advance,"kern")
            if trace_state then
                report_state("%-8s > column %s, state %a, advance %p, height %p, state %a","kern",column,state,advance,height)
                if skipped ~= 0 then
                    report_state("%-8s > column %s, discarded %p","kern",column,skipped)
                end
            end
            if state == "quit" then
                return true
            end
            height = height + depth + skip + advance
            depth  = 0
            skip   = 0
            if trace_state then
                report_state("%-8s > column %s, height %p, depth %p, skip %p","kern",column,height,depth,skip)
            end
        end
    end

    local function process_rule(current,nxt)
        -- simple variant of h|vlist
        local advance = getheight(current) -- + getdepth(current)
        if advance ~= 0 then
            local state, skipped = checked(advance,"rule")
            if trace_state then
                report_state("%-8s > column %s, state %a, rule, advance %p, height %p","rule",column,state,advance,inserttotal,height)
                if skipped ~= 0 then
                    report_state("%-8s > column %s, discarded %p","rule",column,skipped)
                end
            end
            if state == "quit" then
                return true
            end
            height = height + depth + skip + advance
         -- if state == "next" then
         --     height = height + nextskips
         -- else
         --     height = height + currentskips
         -- end
            depth = getdepth(current)
            skip  = 0
        end
        lastcontent = current
    end

    -- okay, here we could do some badness like magic but we want something
    -- predictable and even better: strategies .. so eventually this will
    -- become installable
    --
    -- [chapter] [penalty] [section] [penalty] [first line]

    local function process_penalty(current,nxt)
        local penalty = getpenalty(current)
        if penalty == 0 then
            unlock(2,penalty)
        elseif penalty == forcedbreak then
            local needed  = getattribute(current,a_checkedbreak)
            local proceed = not needed or needed == 0
            if not proceed then
                local available = target - height
                proceed = needed >= available
                if trace_state then
                    report_state("cycle: %s, column %s, available %p, needed %p, %s break",cycle,column,available,needed,proceed and "forcing" or "ignoring")
                end
            end
            if proceed then
                unlock(3,penalty)
                local okay, skipped = gotonext()
                if okay then
                    if trace_state then
                        report_state("cycle: %s, forced column break, same page",cycle)
                        if skipped ~= 0 then
                            report_state("%-8s > column %s, discarded %p","penalty",column,skipped)
                        end
                    end
                else
                    if trace_state then
                        report_state("cycle: %s, forced column break, next page",cycle)
                        if skipped ~= 0 then
                            report_state("%-8s > column %s, discarded %p","penalty",column,skipped)
                        end
                    end
                    return true
                end
            end
        elseif penalty < 0 then
            -- we don't care too much
            unlock(4,penalty)
        elseif penalty >= 10000 then
            if not lastcurrent then
                lock(1,penalty,current)
            elseif penalty > lastlocked then
                lock(2,penalty)
            elseif trace_state then
                report_state("penalty %s, ignoring in column %s, case %i",penalty,column,3)
            end
        else
            unlock(5,penalty)
        end
    end

    local function process_list(current,nxt)
        local nxtid = nxt and getid(nxt)
        line = line + 1
        local inserts, insertskips, nextskips, inserttotal = nil, 0, 0, 0
        local wd, ht, dp = getwhd(current)
        local advance = ht
        local more = nxt and (nxtid == insert_code or nxtid == mark_code)
        if trace_state then
            report_state("%-8s > column %s, content: %s","line (1)",column,listtoutf(getlist(current),true,true))
        end
        if more and handlenotes then
            nxt, inserts, insertskips, nextskips, inserttotal = collectinserts(result,nxt,nxtid)
        end
        local state, skipped = checked(advance+inserttotal+insertskips,more and "line (2)" or "line only",lastlocked)
        if trace_state then
            report_state("%-8s > column %s, state %a, line %s, advance %p, insert %p, height %p","line (3)",column,state,line,advance,inserttotal,height)
            if skipped ~= 0 then
                report_state("%-8s > column %s, discarded %p","line (4)",column,skipped)
            end
        end
        if state == "quit" then
            return true
        end
     -- if state == "next" then -- only when profile
     --     local unprofiled = theprop(current).unprofiled
     --     if unprofiled then
     --         local h = unprofiled.height
     --         local s = unprofiled.strutht
     --         local t = s/2
     -- print("profiled",h,s)
     -- local snapped = theprop(current).snapped
     -- if snapped then
     --     inspect(snapped)
     -- end
     --         if h < s + t then
     --             result.back = - (h - s)
     --             advance     = s
     --         end
     --     end
     -- end
        height = height + depth + skip + advance + inserttotal
        if state == "next" then
            height = height + nextskips
        else
            height = height + insertskips
        end
        depth = dp
        skip  = 0
        if inserts then
            -- so we already collect them ... makes backtracking tricky ... alternatively
            -- we can do that in a separate loop ... no big deal either
            appendinserts(result.inserts,inserts)
        end
        if trace_state then
            report_state("%-8s > column %s, height %p, depth %p, skip %p","line (5)",column,height,depth,skip)
        end
        lastcontent = current
    end

    while current do

        local id  = getid(current)
        local nxt = getnext(current)

        if trace_state then
            report_state("%-8s > column %s, height %p, depth %p, id %s","node",column,height,depth,nodecodes[id])
        end

        backtracked = false

        if id == hlist_code or id == vlist_code then
            if process_list(current,nxt) then break end
        elseif id == glue_code then
            if process_skip(current,nxt) then break end
        elseif id == kern_code then
            if process_kern(current,nxt) then break end
        elseif id == penalty_code then
            if process_penalty(current,nxt) then break end
        elseif id == rule_code then
            if process_rule(current,nxt) then break end
        else
            -- skip inserts and such
        end

        if backtracked then
            nxt = current
        end

        if nxt then
            current = nxt
        elseif head == lasthead then
            -- to be checked but break needed as otherwise we have a loop
            if trace_state then
                report_state("quit as head is lasthead")
            end
            break
        else
            local r = results[column]
            r.head   = head
            r.tail   = current
            r.height = height
            r.depth  = depth
            break
        end
    end

    if not current then
        if trace_state then
            report_state("nothing left")
        end
        -- needs well defined case
     -- rest = nil
    elseif rest == lasthead then
        if trace_state then
            report_state("rest equals lasthead")
        end
        -- test case: x\index{AB} \index{AA}x \blank \placeindex
        -- makes line disappear: rest = nil
    end

    if stripbottom then
        local height = stripbottomglue(results,discarded)
        if height > 0 then
            target = height
        end
    end

    specification.results        = results
    specification.height         = target
    specification.originalheight = originalheight
    specification.originalwidth  = originalwidth
    specification.originalhead   = originalhead
    specification.targetheight   = target or 0
    specification.rest           = rest
    specification.overflow       = overflow
    specification.discarded      = discarded

    setlist(getbox(specification.box))

    return specification
end

local function finalize(result)
    if result then
        local results  = result.results
        local columns  = result.nofcolumns
        local maxtotal = 0
        for i=1,columns do
            local r = results[i]
            local h = r.head
            if h then
                setprev(h)
                if r.back then
                    local k = new_glue(r.back)
                    setlink(k,h)
                    h = k
                    r.head = h
                end
                local t = r.tail
                if t then
                    setnext(t)
                else
                    setnext(h)
                    r.tail = h
                end
                for c, list in next, r.inserts do
                    local t = { }
                    for i=1,#list do
                        local l = list[i]
                        local h = new_vlist() -- was hlist but that's wrong
                        local g = getlist(l)
                        t[i] = h
                        setlist(h,g)
                        local ht = getheight(l)
                        local dp = getdepth(l)
                        local wd = getwidth(g)
                        setwhd(h,wd,ht,dp)
                        setlist(l)
                    end
                    setprev(t[1])  -- needs checking
                    setnext(t[#t]) -- needs checking
                    r.inserts[c] = t
                end
            end
            local total = r.height + r.depth
            if total > maxtotal then
                maxtotal = total
            end
            r.total = total
        end
        result.maxtotal = maxtotal
        for i=1,columns do
            local r = results[i]
            r.extra = maxtotal - r.total
        end
    end
end

local splitruns = 0

local function report_deltas(result,str)
    local t = { }
    for i=1,result.nofcolumns do
        t[#t+1] = points(result.results[i].delta or 0)
    end
    report_state("%s, cycles %s, deltas % | t",str,result.cycle or 1,t)
end

local function setsplit(specification)
    splitruns = splitruns + 1
    if trace_state then
        report_state("split run %s",splitruns)
    end
    local result = preparesplit(specification)
    if result then
        if result.overflow then
            if trace_state then
                report_deltas(result,"overflow")
            end
            -- we might have some rest
        elseif result.rest and specification.balance == v_yes then
            local step = specification.step or 65536*2
            local cycle = 1
            local cycles = specification.cycles or 100
            while result.rest and cycle <= cycles do
                specification.extra = cycle * step
                result = preparesplit(specification) or result
                if trace_state then
                    report_state("cycle: %s.%s, original height %p, total height %p",
                        splitruns,cycle,result.originalheight,result.nofcolumns*result.targetheight)
                end
                cycle = cycle + 1
                specification.cycle = cycle
            end
            if cycle > cycles then
                report_deltas(result,"too many balancing cycles")
            elseif trace_state then
                report_deltas(result,"balanced")
            end
        elseif trace_state then
            report_deltas(result,"done")
        end
        return result
    elseif trace_state then
        report_state("no result")
    end
end

local function getsplit(result,n)
    if not result then
        report_state("flush, column %s, %s",n,"no result")
        return
    end
    local r = result.results[n]
    if not r then
        report_state("flush, column %s, %s",n,"empty")
    end
    local h = r.head
    if not h then
        return new_glue(result.originalwidth)
    end

    setprev(h) -- move up
    local strutht    = result.strutht
    local strutdp    = result.strutdp
    local lineheight = strutht + strutdp
    local isglobal   = result.alternative == v_global

    local v = new_vlist()
    setlist(v,h)

 -- local v = vpack(h,"exactly",height)

    if isglobal then -- option
        result.height = result.maxheight
    end

    local ht = 0
    local dp = 0
    local wd = result.originalwidth

    local grid         = result.grid
    local internalgrid = result.internalgrid
    local httolerance  = .25
    local dptolerance  = .50
    local lineheight   = internalgrid == v_halfline and lineheight/2 or lineheight

    local function amount(r,s,t)
        local l = ceil((r-t)/lineheight)
        local a = lineheight * l
        if a > s then
            return a - s
        else
            return s
        end
    end
    if grid then
        -- print(n,result.maxtotal,r.total,r.extra)
        if isglobal then
            local rh = r.height
         -- ht = (lineheight * ceil(result.height/lineheight) - strutdp
            ht = amount(rh,strutdp,0)
            dp = strutdp
        else
            -- natural dimensions
            local rh = r.height
            local rd = r.depth
            if rh > ht then
                ht = amount(rh,strutdp,httolerance*strutht)
            end
            if rd > dp then
                dp = amount(rd,strutht,dptolerance*strutdp)
            end
            -- forced dimensions
            local rh = result.height or 0
            local rd = result.depth or 0
            if rh > ht then
                ht = amount(rh,strutdp,httolerance*strutht)
            end
            if rd > dp then
                dp = amount(rd,strutht,dptolerance*strutdp)
            end
            -- always one line at least
            if ht < strutht then
                ht = strutht
            end
            if dp < strutdp then
                dp = strutdp
            end
        end
    else
        ht = result.height
        dp = result.depth
    end

    setwhd(v,wd,ht,dp)

    if trace_state then
        local id = getid(h)
        if id == hlist_code then
            report_state("flush, column %s, grid %a, width %p, height %p, depth %p, %s: %s",n,grid,wd,ht,dp,"top line",listtoutf(getlist(h)))
        else
            report_state("flush, column %s, grid %a, width %p, height %p, depth %p, %s: %s",n,grid,wd,ht,dp,"head node",nodecodes[id])
        end
    end

    for c, list in next, r.inserts do
        local l = concatnodes(list)
        for i=1,#list-1 do
            setdepth(list[i],0)
        end
        local b = vpack(l)    -- multiple arguments, todo: fastvpack
        setbox("global",c,b)  -- when we wrap in a box
        r.inserts[c] = nil
    end

    return v
end

local function getrest(result)
    local rest = result and result.rest
    result.rest = nil -- to be sure
    return rest
end

local function getlist(result)
    local originalhead = result and result.originalhead
    result.originalhead = nil -- to be sure
    return originalhead
end

local function cleanup(result)
    local discarded = result.discarded
    for i=1,#discarded do
        flushnode(discarded[i])
    end
    result.discarded = { }
end

mixedcolumns.setsplit = setsplit
mixedcolumns.getsplit = getsplit
mixedcolumns.finalize = finalize
mixedcolumns.getrest  = getrest
mixedcolumns.getlist  = getlist
mixedcolumns.cleanup  = cleanup

-- interface --

local result

implement {
    name      = "mixsetsplit",
    actions   = function(specification)
        if result then
            for k, v in next, specification do
                result[k] = v
            end
            result = setsplit(result)
        else
            result = setsplit(specification)
        end
    end,
    arguments = {
        {
           { "box", "integer" },
           { "nofcolumns", "integer" },
           { "maxheight", "dimen" },
           { "noteheight", "dimen" },
           { "step", "dimen" },
           { "cycles", "integer" },
           { "preheight", "dimen" },
           { "prebox", "integer" },
           { "strutht", "dimen" },
           { "strutdp", "dimen" },
           { "threshold", "dimen" },
           { "splitmethod" },
           { "balance" },
           { "alternative" },
           { "internalgrid" },
           { "grid", "boolean" },
           { "notes", "boolean" },
        }
    }
}

implement {
    name      = "mixgetsplit",
    arguments = "integer",
    actions   = function(n)
        if result then
            context(tonode(getsplit(result,n)))
        end
    end,
}

implement {
    name    = "mixfinalize",
    actions = function()
        if result then
            finalize(result)
        end
    end
}

implement {
    name    = "mixflushrest",
    actions = function()
        if result then
            context(tonode(getrest(result)))
        end
    end
}

implement {
    name = "mixflushlist",
    actions = function()
        if result then
            context(tonode(getlist(result)))
        end
    end
}

implement {
    name    = "mixstate",
    actions = function()
        context(result and result.rest and 1 or 0)
    end
}

implement {
    name = "mixcleanup",
    actions = function()
        if result then
            cleanup(result)
            result = nil
        end
    end
}
