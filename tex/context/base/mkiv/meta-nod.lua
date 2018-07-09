if not modules then modules = { } end modules ['meta-nod'] = {
    version   = 1.001,
    comment   = "companion to meta-nod.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local P, R, Cs, lpegmatch = lpeg.P, lpeg.R, lpeg.Cs, lpeg.match

local references = { }
local trace      = false
local report     = logs.reporter("metapost","nodes")

local context    = context
local implement  = interfaces.implement

trackers.register("metapost.nodes", function(v) trace = v end)

local word     = R("AZ","az","__")^1

local pattern = Cs (
    (
        word / function(s) return references[s] or s end
      + P("{") / "["
      + P("}") / "]"
      + P(1)
    )^1
)

implement {
    name    = "grph_nodes_initialize",
    actions = function()
        references = { }
    end
}

implement {
    name    = "grph_nodes_reset",
    actions = function()
        references = { }
    end
}

implement {
    name      = "grph_nodes_register",
    arguments = { "string", "integer" },
    actions   = function(s,r)
        if not tonumber(s) then
            if trace then
                report("register %i as %a",t,s)
            end
            references[s] = r
        end
    end
}

implement {
    name      = "grph_nodes_resolve",
    arguments = "string",
    actions   = function(s)
        local r = references[s]
        if r then
            if trace then
                report("resolve %a to %i",s,r)
            end
            context(r)
            return
        end
        local n = lpegmatch(pattern,s)
        if s ~= n then
            if trace then
                report("resolve '%s' to %s",s,n)
            end
            context(n)
            return
        end
        context(s)
    end
}
