if not modules then modules = { } end modules ['publ-inc'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fullstrip = string.fullstrip
local datasets, savers = publications.datasets, publications.savers
local assignbuffer = buffers.assign

interfaces.implement {
    name      = "btxentrytobuffer",
    arguments = "3 strings",
    actions   = function(dataset,tag,target)
        local d = datasets[dataset]
        if d then
            d = d.luadata[tag]
        end
        if d then
            d = fullstrip(savers.bib(dataset,false,{ [tag] = d }))
        end
        assignbuffer(target,d or "")
    end
}
