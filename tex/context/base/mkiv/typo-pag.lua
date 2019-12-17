if not modules then modules = { } end modules ['typo-pag'] = {
    version   = 1.001,
    comment   = "companion to typo-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


builders                  = builders or { }
local builders            = builders

builders.paragraphs       = builders.paragraphs or { }
local parbuilders         = builders.paragraphs

local nodes               = nodes
local nodecodes           = nodes.nodecodes

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glue_code           = nodecodes.glue
local kern_code           = nodecodes.kern
local penalty_code        = nodecodes.penalty

local unsetvalue          = attributes.unsetvalue
local a_keeptogether      = attributes.private("keeptogether")

local nuts                = nodes.nuts

local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getid               = nuts.getid
local getattr             = nuts.getattr
local takeattr            = nuts.takeattr
local setattr             = nuts.setattr
local getwhd              = nuts.getwhd
local getkern             = nuts.getkern
local setpenalty          = nuts.setpenalty
local getwidth            = nuts.getwidth
local getdepth            = nuts.getdepth

local insert_node_after   = nuts.insert_after
local new_penalty         = nuts.pool.penalty

local trace_keeptogether  = false
local report_keeptogether = logs.reporter("parbuilders","keeptogether")

local enableaction        = nodes.tasks.enableaction

local cache               = { }
local last                = 0
local enabled             = false

trackers.register("parbuilders.keeptogether", function(v) trace_keeptogether  = v end)

-- todo: also support lines = 3 etc (e.g. dropped caps) but how to set that
-- when no hlists are there ?

function parbuilders.registertogether(line,specification) -- might change
    if not specification then
        return
    end
    if not enabled then
        enableaction("finalizers","builders.paragraphs.keeptogether")
    end
    local a = getattr(line,a_keeptogether)
    local c = a and cache[a]
    if c then
        local height = specification.height
        local depth  = specification.depth
        local slack  = specification.slack
        if height and height > c.height then
            c.height = height
        end
        if depth and depth > c.depth then
            c.depth = depth
        end
        if slack and slack > c.slack then
            c.slack = slack
        end
    else
        last = last + 1
        cache[last] = specification
        if not specification.height then
            specification.height = 0
        end
        if not specification.depth then
            specification.depth = 0
        end
        if not specification.slack then
            specification.slack = 0
        end
        setattr(line,a_keeptogether,last)
    end
    if trace_keeptogether then
        local a = a or last
        local c = cache[a]
        local noflines = specification.lineheight
        local height = c.height
        local depth = c.depth
        local slack = c.slack
        if not noflines or noflines == 0 then
            noflines = "unknown"
        else
            noflines = math.round((height + depth - slack) / noflines)
        end
        report_keeptogether("registered, index %s, height %p, depth %p, slack %p, noflines %a",a,height,depth,slack,noflines)
    end
end

local function keeptogether(start,a,specification)
    local current   = getnext(start)
    local previous  = start
    local total     = getdepth(previous)
    local slack     = specification.slack
    local threshold = specification.depth - slack
    if trace_keeptogether then
        report_keeptogether("%s, index %s, total %p, threshold %p, slack %p","list",a,total,threshold,slack)
    end
    while current do
        local id = getid(current)
        if id == vlist_code or id == hlist_code then
            local wd, ht, dp = getwhd(current)
            total = total + ht + dp
            if trace_keeptogether then
                report_keeptogether("%s, index %s, total %p, threshold %p","list",a,total,threshold)
            end
            if total <= threshold then
                if getid(previous) == penalty_code then
                    setpenalty(previous,10000)
                else
                    insert_node_after(head,previous,new_penalty(10000))
                end
            else
                break
            end
        elseif id == glue_code then
            -- hm, breakpoint, maybe turn this into kern
            total = total + getwidth(current)
            if trace_keeptogether then
                report_keeptogether("%s, index %s, total %p, threshold %p","glue",a,total,threshold)
            end
            if total <= threshold then
                if getid(previous) == penalty_code then
                    setpenalty(previous,10000)
                else
                    insert_node_after(head,previous,new_penalty(10000))
                end
            else
                break
            end
        elseif id == kern_code then
            total = total + getkern(current)
            if trace_keeptogether then
                report_keeptogether("%s, index %s, total %s, threshold %s","kern",a,total,threshold)
            end
            if total <= threshold then
                if getid(previous) == penalty_code then
                    setpenalty(previous,10000)
                else
                    insert_node_after(head,previous,new_penalty(10000))
                end
            else
                break
            end
        elseif id == penalty_code then
            if total <= threshold then
                if getid(previous) == penalty_code then
                    setpenalty(previous,10000)
                end
                setpenalty(current,10000)
            else
                break
            end
        end
        previous = current
        current = getnext(current)
    end
end

-- also look at first non glue/kern node e.g for a dropped caps

function parbuilders.keeptogether(head)
    local done    = false -- can go
    local current = head
    while current do
        if getid(current) == hlist_code then
            local a = takeattr(current,a_keeptogether)
            if a and a > 0 then
                local specification = cache[a]
                if specification then
                    keeptogether(current,a,specification)
                    -- this is tricky ... we need a better resetter, maybe some
                    -- injected latelua or a gc method on a property (interesting
                    -- experiment)
                    cache[a] = nil
                    done = true
                end
            end
        end
        current = getnext(current)
    end
    return head, done
end
