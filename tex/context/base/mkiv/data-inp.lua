if not modules then modules = { } end modules ['data-inp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate  = utilities.storage.allocate
local resolvers = resolvers

local methodhandler  = resolvers.methodhandler
local registermethod = resolvers.registermethod

local finders = allocate { helpers = { }, notfound = function() end }
local openers = allocate { helpers = { }, notfound = function() end }
local loaders = allocate { helpers = { }, notfound = function() return false, nil, 0 end }

registermethod("finders", finders, "uri")
registermethod("openers", openers, "uri")
registermethod("loaders", loaders, "uri")

resolvers.finders = finders
resolvers.openers = openers
resolvers.loaders = loaders
