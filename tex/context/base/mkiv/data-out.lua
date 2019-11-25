if not modules then modules = { } end modules ['data-out'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate       = utilities.storage.allocate

local resolvers      = resolvers
local registermethod = resolvers.registermethod

local savers         = allocate { helpers = { } }
resolvers.savers     = savers

registermethod("savers", savers, "uri")
