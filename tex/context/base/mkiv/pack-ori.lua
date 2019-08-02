if not modules then modules = { } end modules ['pack-ori'] = {
    version   = 1.001,
    comment   = "companion to supp-box.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local context   = context
local implement = interfaces.implement
local variables = interfaces.variables

local settings_to_array = utilities.parsers.settings_to_array

local orientation = {
    [variables.up]     = 0x000,
    [variables.left]   = 0x001,
    [variables.down]   = 0x002,
    [variables.right]  = 0x003,
    [variables.top]    = 0x004,
    [variables.bottom] = 0x005,
}
local vertical = {
    [variables.line]   = 0x000,
    [variables.top]    = 0x010,
    [variables.bottom] = 0x020,
    [variables.middle] = 0x030,
}
local horizontal = {
    [variables.middle]     = 0x000,
    [variables.flushleft]  = 0x100,
    [variables.flushright] = 0x200,
    [variables.left]       = 0x300,
    [variables.right]      = 0x400,
}

implement {
    name      = "toorientation",
    public    = true,
    arguments = {
        {
            { "horizontal",  "string" },
            { "vertical",    "string" },
            { "orientation", "string" },
        }
    },
    actions   = function(t)
        local n = 0
        local m = t.horizontal  if m then n = n | (horizontal [m] or 0) end
        local m = t.vertical    if m then n = n | (vertical   [m] or 0) end
        local m = t.orientation if m then n = n | (orientation[m] or 0) end
     -- logs.report("orientation","0x%03X : %s",n,table.sequenced(t))
        context(n)
    end,
}

implement {
    name      = "stringtoorientation",
    public    = true,
    arguments = "string",
    actions   = function(s)
        local n = 0
        local t = settings_to_array(s)
        local m = t[1] if m then n = n | (horizontal [m] or 0) end
        local m = t[2] if m then n = n | (vertical   [m] or 0) end
        local m = t[3] if m then n = n | (orientation[m] or 0) end
     -- logs.report("orientation","0x%03X : %s",n,s)
        context(n)
    end,
}
