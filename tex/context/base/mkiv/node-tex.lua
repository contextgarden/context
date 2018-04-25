if not modules then modules = { } end modules ['node-tex'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

builders         = builders        or { }
local kernel     = builders.kernel or { }
builders.kernel  = kernel

local nuts       = nodes.nuts

local hyphenate  = lang.hyphenate
local ligaturing = nuts.ligaturing
local kerning    = nuts.kerning

kernel.originals = {
    hyphenate  = hyphenate,
    ligaturing = ligaturing,
    kerning    = kerning,
}

function kernel.hyphenation(head)
    hyphenate(head)
    return head
end

function kernel.ligaturing(head)
    local head, tail = ligaturing(head)
    return head
end

function kernel.kerning(head)
    local head, tail = kerning(head)
    return head
end

callbacks.register('hyphenate' , false, "normal hyphenation routine, called elsewhere")
callbacks.register('ligaturing', false, "normal ligaturing routine, called elsewhere")
callbacks.register('kerning'   , false, "normal kerning routine, called elsewhere")
