if not modules then modules = { } end modules ['trac-jus'] = {
    version   = 1.001,
    comment   = "companion to trac-jus.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local checkers        = typesetters.checkers or { }
typesetters.checkers  = checkers

----- report_justification = logs.reporter("visualize","justification")

local a_alignstate    = attributes.private("alignstate")
local a_justification = attributes.private("justification")

local nuts            = nodes.nuts

local getfield        = nuts.getfield
local getlist         = nuts.getlist
local getattr         = nuts.getattr
local setattr         = nuts.setattr
local setlist         = nuts.setlist
local setlink         = nuts.setlink
local getwidth        = nuts.getwidth
local findtail        = nuts.tail

local nexthlist       = nuts.traversers.hlist

local getdimensions   = nuts.dimensions
local copy_list       = nuts.copy_list

local tracedrule      = nodes.tracers.pool.nuts.rule

local nodepool        = nuts.pool

local new_hlist       = nodepool.hlist
local new_kern        = nodepool.kern

local hlist_code      = nodes.nodecodes.hlist

local texsetattribute = tex.setattribute
local unsetvalue      = attributes.unsetvalue

local enableaction    = nodes.tasks.enableaction

local min_threshold   = 0
local max_threshold   = 0

local function set(n)
    enableaction("mvlbuilders", "typesetters.checkers.handler")
    enableaction("vboxbuilders","typesetters.checkers.handler")
    texsetattribute(a_justification,n or 1)
    function typesetters.checkers.set(n)
        texsetattribute(a_justification,n or 1)
    end
end

local function reset()
    texsetattribute(a_justification,unsetvalue)
end

checkers.set   = set
checkers.reset = reset

interfaces.implement {
    name    = "showjustification",
    actions = set
}

trackers.register("visualizers.justification", function(v)
    if v then
        set(1)
    else
        reset()
    end
end)

function checkers.handler(head)
    for current in nexthlist, head do
        if getattr(current,a_justification) == 1 then
            setattr(current,a_justification,0) -- kind of reset
            local width = getwidth(current)
            if width > 0 then
                local list = getlist(current)
                if list then
                    local naturalwidth, naturalheight, naturaldepth = getdimensions(list)
                    local delta = naturalwidth - width
                    if naturalwidth == 0 or delta == 0 then
                        -- special box
                    elseif delta >= max_threshold then
                        local rule = new_hlist(tracedrule(delta,naturalheight,naturaldepth,getfield(list,"glue_set") == 1 and "trace:dr" or "trace:db"))
                        setlink(findtail(list),rule)
                        setlist(current,list)
                    elseif delta <= min_threshold then
                        local alignstate = getattr(list,a_alignstate)
                        if alignstate == 1 then
                            local rule = new_hlist(tracedrule(-delta,naturalheight,naturaldepth,"trace:dc"))
                            setlink(rule,list)
                            setlist(current,rule)
                        elseif alignstate == 2 then
                            local lrule = new_hlist(tracedrule(-delta/2,naturalheight,naturaldepth,"trace:dy"))
                            local rrule = copy_list(lrule)
                            setlink(lrule,list)
                            setlink(findtail(list),new_kern(delta/2),rrule)
                            setlist(current,lrule)
                        elseif alignstate == 3 then
                            local rule = new_hlist(tracedrule(-delta,naturalheight,naturaldepth,"trace:dm"))
                            setlink(findtail(list),new_kern(delta),rule)
                            setlist(current,list)
                        else
                            local rule = new_hlist(tracedrule(-delta,naturalheight,naturaldepth,"trace:dg"))
                            setlink(findtail(list),new_kern(delta),rule)
                            setlist(current,list)
                        end
                    end
                end
            end
        end
    end
    return head
end
