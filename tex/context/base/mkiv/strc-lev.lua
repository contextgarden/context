if not modules then modules = { } end modules ['strc-lev'] = {
    version   = 1.001,
    comment   = "companion to strc-lev.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local insert, remove = table.insert, table.remove
local settings_to_array = utilities.parsers.settings_to_array

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
    list = settings_to_array(list)
    for i=1,#list do
        list[i] = settings_to_array(list[i])
    end
    levels[category] = list
end

local ctx_nostarthead = context.nostarthead
local ctx_dostarthead = context.dostarthead
local ctx_nostophead  = context.nostophead
local ctx_dostophead  = context.dostophead

local function startsectionlevel(n,category,current)
    category = category ~= "" and category or v_default
    local lc = levels[category]
    for i=1,#lc do
        local lcl = lc[i]
        if (lcl[n] or lcl[1]) == current then
            level = i
            break
        end
    end
    level = level + 1
    if not lc or level > #lc then
        ctx_nostarthead { f_two_colon(category,level) }
    else
        local lcl = lc[level]
        if n > #lcl then
            n = #lcl
        end
        ctx_dostarthead { lc[level][n] }
    end
    insert(categories,{ category, n })
end

local function stopsectionlevel()
    local top = remove(categories)
    if top then
        local category = top[1]
        local n = top[2]
        local lc = levels[category]
        if not lc or level > #lc then
            ctx_nostophead { f_two_colon(category,level) }
        else
            ctx_dostophead { lc[level][n] }
        end
        level = level - 1
    else
        -- error
    end
end

implement {
    name      = "definesectionlevels",
    actions   = definesectionlevels,
    arguments = "2 strings",
}

implement {
    name      = "startsectionlevel",
    actions   = startsectionlevel,
    arguments = { "integer", "string", "string" },
}

implement {
    name      = "stopsectionlevel",
    actions   = stopsectionlevel,
}
