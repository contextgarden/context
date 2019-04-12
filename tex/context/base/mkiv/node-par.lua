if not modules then modules = { } end modules ['node-par'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local starttiming = statistics.starttiming
local stoptiming  = statistics.stoptiming

local sequencers  = utilities.sequencers

-- This are called a lot!

local actions = nodes.tasks.actions("everypar")

local function everypar(head)
    starttiming(builders)
    head = actions(head)
    stoptiming(builders)
    return head
end

callbacks.register("insert_local_par",everypar,"after paragraph start")

local actions = sequencers.new {
    name         = "newgraf",
    arguments    = "mode,indented",
    returnvalues = "indented",
    results      = "indented",
}

sequencers.appendgroup(actions,"before") -- user
sequencers.appendgroup(actions,"system") -- private
sequencers.appendgroup(actions,"after" ) -- user

local function newgraf(mode,indented)
    local runner = actions.runner
    if runner then
        starttiming(builders)
        indented = runner(mode,indented)
        stoptiming(builders)
    end
    return indented
end

callbacks.register("new_graf",newgraf,"before paragraph start")
