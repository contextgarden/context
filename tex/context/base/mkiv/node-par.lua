if not modules then modules = { } end modules ['node-par'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local starttiming = statistics.starttiming
local stoptiming  = statistics.stoptiming

local actions = nodes.tasks.actions("everypar")

local function everypar(head)
    starttiming(builders)
    head = actions(head)
    stoptiming(builders)
    return head
end

callback.register("insert_local_par",everypar,"paragraph start")
