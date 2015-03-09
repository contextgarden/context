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

local hyphenate  = lang.hyphenate
local ligaturing = node.ligaturing
local kerning    = node.kerning

kernel.originals = {
    hyphenate  = hyphenate,
    ligaturing = ligaturing,
    kerning    = kerning,
}

function kernel.hyphenation(head)
    local done = hyphenate(head)
    return head, done
end

function kernel.ligaturing(head)
    local head, tail, done = ligaturing(head) -- we return 3 values indeed
    return head, done
end

function kernel.kerning(head)
    local head, tail, done = kerning(head) -- we return 3 values indeed
    return head, done
end

callbacks.register('hyphenate' , false, "normal hyphenation routine, called elsewhere")
callbacks.register('ligaturing', false, "normal ligaturing routine, called elsewhere")
callbacks.register('kerning'   , false, "normal kerning routine, called elsewhere")
