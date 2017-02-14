if not modules then modules = { } end modules ['typo-wrp'] = {
    version   = 1.001,
    comment   = "companion to typo-wrp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- begin/end par wrapping stuff ... more to come

local nodecodes         = nodes.nodecodes

local glue_code         = nodecodes.glue
local penalty_code      = nodecodes.penalty
local parfill_skip_code = nodes.gluecodes.parfillskip
local user_penalty_code = nodes.penaltycodes.userpenalty

local nuts              = nodes.nuts
local tonut             = nodes.tonut
local tonode            = nodes.tonode

local find_node_tail    = nuts.tail
local getprev           = nuts.getprev
local getid             = nuts.getid
local getsubtype        = nuts.getsubtype
local getpenalty        = nuts.getpenalty
local remove            = nuts.remove

local enableaction      = nodes.tasks.enableaction

local wrappers          = { }
typesetters.wrappers    = wrappers

local trace_wrappers    = trackers.register("typesetters.wrappers",function(v) trace_wrappers = v end)

local report            = logs.reporter("paragraphs","wrappers")

-- we really need to pass tail too ... but then we need to check all the plugins
-- bah ... slowdown

local function remove_dangling_crlf(head,tail)
    if tail and getid(tail) == glue_code and getsubtype(tail) == parfill_skip_code then
        tail = getprev(tail)
        if tail and getid(tail) == penalty_code and getsubtype(tail) == user_penalty_code and getpenalty(tail) == 10000 then
            tail = getprev(tail)
            if tail and getid(tail) == penalty_code and getsubtype(tail) == user_penalty_code and getpenalty(tail) == -10000 then
                if tail == head then
                    -- can't happen
                else
                    if trace_wrappers then
                        report("removing a probably unwanted end-of-par break in line %s (guess)",tex.inputlineno)
                    end
                    remove(head,tail,true)
                    return head, tail, true
                end
            end
        end
    end
    return head, tail, false
end

function wrappers.handler(head)
    local head = tonut(head)
    if head then
        local tail = find_node_tail(head)
        local done = false
        head, tail, done = remove_dangling_crlf(head,tail) -- will be action chain
    end
    return head, true
end

interfaces.implement {
    name     = "enablecrlf",
    onlyonce = true,
    actions  = function()
        enableaction("processors","typesetters.wrappers.handler")
    end
}
