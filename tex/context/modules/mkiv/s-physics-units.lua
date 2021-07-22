if not modules then modules = { } end modules ['s-physics-units'] = {
    version   = 1.001,
    comment   = "companion to s-physics-units.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.physics       = moduledata.physics       or { }
moduledata.physics.units = moduledata.physics.units or { }

local tables    = physics.units.tables
local units     = tables.units
local shortcuts = tables.shortcuts

local HL = context.HL
local NC = context.NC
local NR = context.NR

local function typeset(list,followup,name,category)
    if list then
        if followup then
            context.TB()
        end
        if category then
            HL()
            NC()
            context.rlap(category .. ":" .. name)
            NC()
            NC()
            NR()
            HL()
        end
        for k, v in table.sortedhash(list) do
            NC()
            context(k)
            NC()
            if isunit then
                context(v)
            else
                context.type(v)
            end
            NC()
            if name == "units" or name == "symbols" or name == "packaged" then
                context.unittext(v)
            elseif name == "prefixes" then
                context.prefixtext(v)
            elseif name == "operators" then
                context.operatortext(v)
            elseif name == "suffixes" then
                context.suffixtext(v)
            end
            NC()
            NR()
        end
        if category and name then
            HL()
        end
    end
end

function moduledata.physics.units.showlist(name)
    specification = interfaces.checkedspecification(specification)
    context.starttabulate { "|lT|l|c|" }
    local name = specification.name
    if name and name ~= "" then
        local first, second = string.match(name,"(.-):(.-)") -- [units|shortcuts]:[units|...]
        if first then
            typeset(tables[first] and tables[first][second],false)
        else
            typeset(units[name],false)
            typeset(shortcuts[name],true)
        end
    else
        local done = false
        for what, list in table.sortedhash(units) do
            typeset(list,done,what,"units")
            done = true
        end
        for what, list in table.sortedhash(shortcuts) do
            typeset(list,done,what,"shortcuts")
            done = true
        end
    end
    context.stoptabulate()
end
