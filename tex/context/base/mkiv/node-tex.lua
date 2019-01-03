if not modules then modules = { } end modules ['node-tex'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

builders          = builders        or { }
local kernel      = builders.kernel or { }
builders.kernel   = kernel

local nuts        = nodes.nuts

local hyphenate   = lang.hyphenate
local hyphenating = nuts.hyphenating
local ligaturing  = nuts.ligaturing
local kerning     = nuts.kerning
local cleanup     = nuts.flush_components

function kernel.hyphenation(head)
    return (hyphenate(head)) -- nodes !
end

function kernel.hyphenating(head)
    return (hyphenating(head))
end

function kernel.ligaturing(head)
    return (ligaturing(head))
end

function kernel.kerning(head)
    return (kerning(head))
end

if cleanup then

    function kernel.cleanup(head)
        return (cleanup(head))
    end

end

callbacks.register('hyphenate' , false, "normal hyphenation routine, called elsewhere")
callbacks.register('ligaturing', false, "normal ligaturing routine, called elsewhere")
callbacks.register('kerning'   , false, "normal kerning routine, called elsewhere")
