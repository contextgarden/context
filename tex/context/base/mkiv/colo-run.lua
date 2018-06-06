if not modules then modules = { } end modules ['colo-run'] = {
    version   = 1.000,
    comment   = "companion to colo-run.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- For historic reasons the core has a couple of tracing features. Nowadays
-- these would end up in modules.

local utilities = utilities
local commands  = commands
local context   = context
local colors    = attributes.colors

local private   = table.tohash { "c_o_l_o_r", "maintextcolor", "themaintextcolor" }

function commands.showcolorset(name)
    local set = colors.setlist(name)
    context.starttabulate { "|l|l|l|l|l|l|l|" }
    for i=1,#set do
        local s = set[i]
        if not private[s] then
            local r = { width = "4em", height = "max", depth = "max", color = s }
            context.NC()
            context.setcolormodel { "gray" }
            context.blackrule(r)
            context.NC()
            context.blackrule(r)
            context.NC()
            context.grayvalue(s)
            context.NC()
            context.colorvalue(s)
            context.NC()
            context(s)
            context.NC()
            context.NR()
        end
    end
    context.stoptabulate()
end

function commands.showcolorcomponents(list)
    local set = utilities.parsers.settings_to_array(list)
    context.starttabulate { "|lT|lT|lT|lT|" }
        context.NC()
        context("color")
        context.NC()
        context("name")
        context.NC()
        context("transparency")
        context.NC()
        context("specification ")
        context.NC()
        context.NR()
        context.TB()
        for i=1,#set do
            local s = set[i]
            if not private[s] then
                context.NC()
                context.showcolorbar { s }
                context.NC()
                context(s)
                context.NC()
                context.transparencycomponents(s)
                context.NC()
                context.colorcomponents(s)
                context.NC()
                context.NR()
            end
        end
    context.stoptabulate()
end

