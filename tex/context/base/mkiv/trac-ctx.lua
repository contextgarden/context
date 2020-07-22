if not modules then modules = { } end modules ['trac-ctx'] = {
    version   = 1.001,
    comment   = "companion to trac-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next

local context        = context
local implement      = interfaces.implement
local register       = trackers.register

local textrackers    = tex.trackers    or { }
local texdirectives  = tex.directives  or { }
local texexperiments = tex.experiments or { }

tex.trackers         = textrackers
tex.directives       = texdirectives
tex.experiments      = texexperiments

storage.register("tex/trackers",   textrackers,   "tex.trackers")
storage.register("tex/directives", texdirectives, "tex.directives")
storage.register("tex/experiments",texexperiments,"tex.experiments")

local function doit(category,tag,v)
    local tt = category[tag]
    if tt then
        context.unprotect()
        context(v and tt[1] or tt[2]) -- could be one call
        context.protect()
    end
end

local function initialize(category,register)
    for tag, commands in next, category do
        register(tag, function(v) doit(category,tag,v) end) -- todo: v,tag in caller
    end
end

local function install(category,register,tag,enable,disable)
    category[tag] = { enable, disable }
    register(tag, function(v) doit(category,tag,v) end) -- todo: v,tag in caller
end

implement {
    name    = "initializetextrackers",
    actions = function()
        initialize(textrackers,trackers.register)
    end
}

implement {
    name    = "initializetexdirectives",
    actions = function()
        initialize(texdirectives,directives.register)
    end
}

implement {
    name    = "initializetexexperiments",
    actions = function()
        initialize(texexperiments,experiments.register)
    end
}

implement {
    name    = "installtextracker",
    arguments = "3 strings",
    actions = function(tag,enable,disable)
        install(textrackers,trackers.register,tag,enable,disable)
    end,
}

implement {
    name      = "installtexdirective",
    arguments = "3 strings",
    actions   = function(tag,enable,disable)
        install(texdirectives,directives.register,tag,enable,disable)
    end,
}

implement {
    name      = "installtexexperiment",
    arguments = "3 strings",
    actions   = function(tag,enable,disable)
        install(texexperiments,experiments.register,tag,enable,disable)
    end,
}

-- this one might move

interfaces.implement {
    name    = "unsupportedcs",
    public  = true,
    actions = function()
        logs.newline()
        logs.report("fatal error","unsupported cs \\%s",tokens.scanners.csname())
        logs.newline()
        luatex.abort()
    end
}

