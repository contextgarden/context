if not modules then modules = { } end modules ['node-pag'] = {
    version   = 1.001,
    comment   = "companion to node-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this callback might disappear and come back in the same way
-- as par builders

pagebuilders = pagebuilders or { }

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local actions = nodes.tasks.actions("pagebuilders")

local function processor(head,groupcode,size,packtype,maxdepth,direction)
    starttiming(pagebuilders)
    local _, done = actions(head,groupcode,size,packtype,maxdepth,direction)
    stoptiming(pagebuilders)
    return (done and head) or true
--  return vpack(head)
end

--~ callbacks.register('pre_output_filter', processor, "preparing output box")

--~ statistics.register("output preparation time", function()
--~     return statistics.elapsedseconds(pagebuilders)
--~ end)
