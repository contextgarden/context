if not modules then modules = { } end modules ['scrn-ini'] = {
    version   = 1.001,
    comment   = "companion to scrn-int.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next

interactions         = { }
interactions.general = interactions.general or { }
local general        = interactions.general

local codeinjections = backends.codeinjections

local identitydata   = { }

function general.setupidentity(specification)
    for k, v in next, specification do
        identitydata[k] = v
    end
    codeinjections.setupidentity(specification)
end

function general.getidentity()
    return identitydata
end

interfaces.implement {
    name      = "setupidentity",
    actions   = general.setupidentity,
    arguments = {
        {
            { "title" },
            { "subtitle" },
            { "author" },
            { "creator" },
            { "date" },
            { "keywords" },
        }
    }
}
