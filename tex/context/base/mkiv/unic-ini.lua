if not modules then modules = { } end modules ['unic-ini'] = {
    version   = 1.001,
    comment   = "companion to unic-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local context = context
local utfchar = utf.char

-- Beware, initializing unicodechar happens at first usage and takes
-- 0.05 -- 0.1 second (lots of function calls).

interfaces.implement {
    name      = "unicodechar",
    arguments = "string",
    actions   = function(asked)
        local n = characters.unicodechar(asked)
        if n then
            context(utfchar(n))
        end
    end
}
