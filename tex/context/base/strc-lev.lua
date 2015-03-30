if not modules then modules = { } end modules ['strc-lev'] = {
    version   = 1.001,
    comment   = "companion to strc-lev.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local insert, remove = table.insert, table.remove

local context     = context
local interfaces  = interfaces

local sections    = structures.sections
local implement   = interfaces.implement

local v_default   = interfaces.variables.default

sections.levels   = sections.levels or { }

local level       = 0
local levels      = sections.levels
local categories  = { }

local f_two_colon = string.formatters["%s:%s"]

storage.register("structures/sections/levels", levels, "structures.sections.levels")

local function definesectionlevels(category,list)
    levels[category] = utilities.parsers.settings_to_array(list)
end

local function startsectionlevel(category)
    category = category ~= "" and category or v_default
    level = level + 1
    local lc = levels[category]
    if not lc or level > #lc then
        context.nostarthead { f_two_colon(category,level) }
    else
        context.dostarthead { lc[level] }
    end
    insert(categories,category)
end

local function stopsectionlevel()
    local category = remove(categories)
    if category then
        local lc = levels[category]
        if not lc or level > #lc then
            context.nostophead { f_two_colon(category,level) }
        else
            context.dostophead { lc[level] }
        end
        level = level - 1
    else
        -- error
    end
end

implement {
    name      = "definesectionlevels",
    actions   = definesectionlevels,
    arguments = { "string", "string" }
}

implement {
    name      = "startsectionlevel",
    actions   = startsectionlevel,
    arguments = "string"
}

implement {
    name      = "stopsectionlevel",
    actions   = stopsectionlevel,
}
