if not modules then modules = { } end modules ['typo-wrp'] = {
    version   = 1.001,
    comment   = "companion to typo-wrp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- begin/end par wrapping stuff ... more to come

local nodecodes              = nodes.nodecodes
local gluecodes              = nodes.gluecodes
local penaltycodes           = nodes.penaltycodes
local boundarycodes          = nodes.boundarycodes

local glue_code              = nodecodes.glue
local penalty_code           = nodecodes.penalty
local boundary_code          = nodecodes.boundary

local parfillskip_code       = gluecodes.parfillskip

local userpenalty_code       = penaltycodes.userpenalty
local linepenalty_code       = penaltycodes.linepenalty
local linebreakpenalty_code  = penaltycodes.linebreakpenalty

local wordboundary_code      = boundarycodes.word

local nuts                   = nodes.nuts

local find_node_tail         = nuts.tail
local getprev                = nuts.getprev
local getid                  = nuts.getid
local getsubtype             = nuts.getsubtype
local getpenalty             = nuts.getpenalty
local remove_node            = nuts.remove

local enableaction           = nodes.tasks.enableaction

local wrappers               = { }
typesetters.wrappers         = wrappers

local trace_wrappers         = trackers.register("typesetters.wrappers",function(v) trace_wrappers = v end)

local report                 = logs.reporter("paragraphs","wrappers")

-- we really need to pass tail too ... but then we need to check all the plugins
-- bah ... slowdown

-- This check is very tight to the crlf definition. We check for:
--
-- [break -10000] [wordboundary] [line(break)penalty] [parfillskip]
--
-- If needed we can extend this checker for other cases but then we will also
-- use attributes.

local function remove_dangling_crlf(head,tail)
    if head and tail and getid(tail) == glue_code and getsubtype(tail) == parfillskip_code then
        tail = getprev(tail)
        if tail and getid(tail) == penalty_code then
            local subtype = getsubtype(tail)
            if subtype == linepenalty_code or subtype == linebreakpenalty_code then
                tail = getprev(tail)
                if tail and getid(tail) == boundary_code and getsubtype(tail) == wordboundary_code then
                    tail = getprev(tail)
                    if tail ~= head and getid(tail) == penalty_code and getsubtype(tail) == userpenalty_code and getpenalty(tail) == -10000 then
                        if trace_wrappers then
                            report("removing a probably unwanted end-of-par break in line %s (guess)",tex.inputlineno)
                        end
                        remove_node(head,tail,true)
                        return head, tail
                    end
                end
            end
        end
    end
    return head, tail
end

function wrappers.handler(head)
    if head then
        local tail = find_node_tail(head)
        head, tail = remove_dangling_crlf(head,tail) -- will be action chain
    end
    return head
end

interfaces.implement {
    name     = "enablecrlf",
    onlyonce = true,
    actions  = function()
        enableaction("processors","typesetters.wrappers.handler")
    end
}
