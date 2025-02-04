if not modules then modules = { } end modules ['char-ran'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable = setmetatable
local formatters = string.formatters

characters   = characters or { }
local ranges = characters.ranges or { }

-- Nushu

do

 -- local variants = {
 -- }

    local common = {
        category    = "lo",
        cjkwd       = "w",
        description = "<NUSHU CHARACTER>",
        direction   = "l",
        linebreak   = "id",
    }

    local metatable = {
        __index = common
    }

    local function extender(k)
        local t = {
         -- shcode      = shcode,
            unicodeslot = k,
         -- variants    = variants[k],
         -- description = formatters["NUSHU CHARACTER-%05X"](k)
        }
        setmetatable(t,metatable)
        return t
    end

    ranges[#ranges+1] = {
        name     = "nushu character",
        first    = 0x1B170,
        last     = 0x1B2FF,
        common   = common,
        extender = extender,
    }

end

-- Egyptian

do

 -- local variants = {
 -- }

    local common = {
        category    = "lo",
        description = "<EGYPTIAN HIEROGLYPHS EXTENDED A>",
        direction   = "l",
        linebreak   = "al",
    }

    local metatable = {
        __index = common
    }

    local function extender(k)
        local t = {
            unicodeslot = k,
         -- variants    = variants[k],
         -- description = formatters["EGYPTIAN HIEROGLYPH-%05X"](k)
        }
        setmetatable(t,metatable)
        return t
    end

    ranges[#ranges+1] = {
        name     = "egyptian hieroglyphs extended a",
        first    = 0x13460,
        last     = 0x143FF,
        common   = common,
        extender = extender,
    }

end

-- Khitan

do

 -- local variants = {
 -- }

    local common = {
      category    = "lo",
      cjkwd       = "w",
      description = "<KHITAN SMALL SCRIPT CHARACTER>",
      direction   = "l",
      linebreak   = "al",
    }

    local metatable = {
        __index = common
    }

    local function extender(k)
        local t = {
            unicodeslot = k,
         -- variants    = variants[k],
         -- description = formatters["KHITAN SMALL SCRIPT CHARACTER-%05X"](k)
        }
        setmetatable(t,metatable)
        return t
    end

    ranges[#ranges+1] = {
        name     = "khytan small script character",
        first    = 0x18B00,
        last     = 0x18CFF,
        common   = common,
        extender = extender,
    }

end
