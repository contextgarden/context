if not modules then modules = { } end modules ['colo-run'] = {
    version   = 1.000,
    comment   = "companion to colo-run.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- For historic reasons the core has a couple of tracing features. Nowadays
-- these would end up in modules.

local colors, commands, context, utilities = colors, commands, context, utilities

local colors= attributes.colors

function commands.showcolorset(name)
    local set = colors.setlist(name)
    context.starttabulate { "|l|l|l|l|l|l|l|" }
    for i=1,#set do
        local s = set[i]
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
    context.stoptabulate()
end

