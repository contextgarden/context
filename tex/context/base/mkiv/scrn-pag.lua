if not modules then modules = { } end modules ['scrn-pag'] = {
    version   = 1.001,
    comment   = "companion to scrn-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interactions         = interactions or { }
interactions.pages   = interactions.pages or { }
local pages          = interactions.pages

local implement      = interfaces.implement

local codeinjections = backends.codeinjections

function pages.setupcanvas(specification)
    codeinjections.setupcanvas(specification)
end

function pages.setpagetransition(specification)
    codeinjections.setpagetransition(specification)
end

implement {
    name      = "setupcanvas",
    actions   = pages.setupcanvas,
    arguments = {
        {
            { "mode" },
            { "singlesided", "boolean" },
            { "doublesided", "boolean" },
            { "leftoffset", "dimen" },
            { "topoffset", "dimen" },
            { "width", "dimen" },
            { "height", "dimen" },
            { "paperwidth", "dimen" },
            { "paperheight", "dimen" },
            { "cropoffset", "dimen" },
            { "bleedoffset", "dimen" },
            { "artoffset", "dimen" },
            { "trimoffset", "dimen" },
            { "copies", "integer" },
            { "print", "string" }, -- , tohash
        }
    }
}

implement {
    name      = "setpagetransition",
    actions   = pages.setpagetransition,
    arguments = {
        {
            { "n" },
            { "delay", "integer" },
        }
    }
}
