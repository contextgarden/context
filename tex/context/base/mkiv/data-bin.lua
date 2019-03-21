if not modules then modules = { } end modules ['data-bin'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local resolvers = resolvers
local methodhandler = resolvers.methodhandler

function resolvers.findbinfile(filename,filetype)
    return methodhandler('finders',filename,filetype)
end

function resolvers.openbinfile(filename)
    return methodhandler('loaders',filename) -- a bit weird: load
end

function resolvers.loadbinfile(filename,filetype)
    local fname = methodhandler('finders',filename,filetype)
    if fname and fname ~= "" then
        return resolvers.openbinfile(fname) -- a bit weird: open
    else
        return resolvers.loaders.notfound()
    end
end
