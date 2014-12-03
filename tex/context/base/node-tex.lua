if not modules then modules = { } end modules ['node-tex'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

builders        = builders        or { }
builders.kernel = builders.kernel or { }
local kernel    = builders.kernel

local hyphenate, ligaturing, kerning = lang.hyphenate, node.ligaturing, node.kerning

function kernel.hyphenation(head)
    local done = hyphenate(head)
    return head, done
end

function kernel.ligaturing(head,tail)
    if tail then
        local head, tail, done = ligaturing(head,tail)
        return head, done
    else -- sensitive for second arg nil
        local head, tail, done = ligaturing(head)
        return head, done
    end
end

function kernel.kerning(head,tail)
    if tail then
        local head, tail, done = kerning(head,tail)
        return head, done
    else -- sensitive for second arg nil
        local head, tail, done = kerning(head)
        return head, done
    end
end

callbacks.register('hyphenate' , false, "normal hyphenation routine, called elsewhere")
callbacks.register('ligaturing', false, "normal ligaturing routine, called elsewhere")
callbacks.register('kerning'   , false, "normal kerning routine, called elsewhere")
