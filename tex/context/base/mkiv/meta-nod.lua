if not modules then modules = { } end modules ['meta-nod'] = {
    version   = 1.001,
    comment   = "companion to meta-nod.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local references = { }

metapost.nodes = {

    initialize = function()
        references = { }
    end,

    register = function(s,r)
        references[s] = r
    end,

    resolve = function(s)
        context(references[s] or ("\\number " .. (tonumber(s) or 0)))
    end,

    reset = function()
        references = { }
    end,

}
