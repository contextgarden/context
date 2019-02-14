if not modules then modules = { } end modules ['grph-pat'] = {
    version   = 1.001,
    comment   = "companion to grph-pat.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is just a proof of concept. Viewers behave different (offsets) and Acrobat doesn't
-- show xform based patterns.
--
-- This module will be cleaned up and use codeinjections and such.

local texsetbox   = tex.setbox
local texgetbox   = tex.getbox

local nodepool    = nodes.pool
local new_literal = nodepool.originliteral -- really ?
local new_hlist   = nodepool.hlist

local names       = { }

interfaces.implement {
    name      = "registerpattern",
    arguments = { {
        { "name" },
        { "number", "integer" },
        { "width", "dimension" },
        { "height", "dimension" },
        { "hoffset", "dimension" },
        { "voffset", "dimension" },
    } },
    actions   = function(specification)
        local number = specification.number
        local name   = specification.name
        local box    = texgetbox(number)
        if not name or name == "" then
            return
        end
        nodes.handlers.finalizebox(number)
        names[name] = lpdf.registerpattern {
            number  = number,
            width   = specification.width  or  box.width,
            height  = specification.height or (box.height + box.depth) ,
            hoffset = specification.hoffset,
            voffset = specification.voffset,
        }
    end
}

interfaces.implement {
    name      = "applypattern",
    arguments = { {
        { "name" },
        { "number", "integer" },
        { "width", "dimension" },
        { "height", "dimension" },
    } },
    actions   = function(specification)
        local number = specification.number
        local name   = specification.name
        local width  = specification.width
        local height = specification.height
        if not name or name == "" then
            return
        end
        local p = names[name]
        if p then
            local l = new_literal(lpdf.patternstream(p,width,height))
            local h = new_hlist(l,width,height)
            texsetbox(number,h)
        end
    end
}
