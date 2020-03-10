if not modules then modules = { } end modules ['font-imp-tweaks'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local addfeature = fonts.handlers.otf.addfeature

addfeature {
    name    = "uppercasing",
    type    = "substitution",
    prepend = true,
    data    = characters.uccodes
}

addfeature {
    name    = "lowercasing",
    type    = "substitution",
    prepend = true,
    data    = characters.lccodes
}
