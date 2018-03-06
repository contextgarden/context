if not modules then modules = { } end modules ['s-domotica-settings'] = {
    version   = 1.001,
    comment   = "companion to s-domotica-settings.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.domotica          = moduledata.domotica          or { }
moduledata.domotica.settings = moduledata.domotica.settings or { }

-- bah, no proper wrapper around value|help

moduledata.zwave = moduledata.zwave or { }
moduledata.hue   = moduledata.hue   or { }

local NC = context.NC
local BC = context.BC
local NR = context.NR

function moduledata.zwave.show_settings(pattern)

    local function show(setting)

        context.starttabulate { "|r|r|r|r|l|p|" }
            BC() context("index")
         -- BC() context("genre")
         -- BC() context("instance")
            BC() context("value")
            BC() context("min")
            BC() context("max")
            BC() context("type")
            BC() context("label")
            BC() NR()
            for value in xml.collected(setting,"/Value") do
                local at = value.at
                NC() context(at.index)
             -- NC() context(at.genre)
             -- NC() context(at.instance)
                NC() context(at.value)
                NC() context(at.min)
                NC() context(at.max)
                NC() context(at.type)
                NC() context.escaped(at.label)
                NC() NR()
           end
        context.stoptabulate()

    end

    if string.find(pattern,"*",1,true) then

        local list = dir.glob(pattern)
        local last = nil

        for i=1,#list do

            local filename = list[i]
            local root     = xml.load(filename)
            local settings = xml.all(root,"/Product/CommandClass[@id='112']")

            if settings then

                local brand  = file.nameonly(file.pathpart(filename))
                local device = file.nameonly(filename)

                if last ~= brand then
                    context.startchapter { title = brand }
                end

                context.startsection { title = device }
                    for i=1,#settings do
                        show(settings[i])
                    end
                context.stopsection()

                if last ~= brand then
                    last = brand
                    context.stopchapter()
                end

            end

        end

    else

        local root     = xml.load(pattern)
        local settings = xml.all(root,"/Product/CommandClass[@id='112']")

        if settings then
            for i=1,#settings do
                show(settings[i])
            end
        end

    end

end

function moduledata.hue.show_state(filename)

    require("control-common")
    require("control-hue")

    local specification = domotica.hue.check(filename)
    local instances     = specification.instances

    local ctx_NC, ctx_BC, ctx_NR = context.NC, context.BC, context.NR

    for i=1,#instances do
        local known = instances[i].knowndevices

        if #instances > 1 then
            context.subject("instance %i",i)
        end

        context.starttabulate { "|l|c|c|c|c|c|l|" }
            ctx_BC() context("light name")
            ctx_BC() context("id")
            ctx_BC() context("state")
            ctx_BC() context("level")
            ctx_BC() context("color")
            ctx_BC() context("seen")
            ctx_BC() context("internal")
            ctx_BC() ctx_NR()
            for id, entry in table.sortedhash(known.lights) do
                if entry.used then
                    local state    = entry.state
                    local name     = entry.name
                    local internal = entry.internalname
                    ctx_NC() context(entry.name)
                    ctx_NC() context(entry.identifier)
                    ctx_NC() context(state.on and "on " or "off")
                    ctx_NC() context(state.brightness or 0)
                    ctx_NC() context(state.temperature or 0)
                    ctx_NC() context((state.reachable or entry.reachable) and "yes" or "no ")
                    ctx_NC() if name == internal then context(name) else context.emphasized(internal) end
                    ctx_NC() ctx_NR()
                end
            end
        context.stoptabulate()
        context.starttabulate { "|l|c|c|c|l|" }
        ctx_BC() context("sensor name")
        ctx_BC() context("id")
        ctx_BC() context("seen")
        ctx_BC() context("battery")
        ctx_BC() context("internal")
        ctx_BC() ctx_NR()
        for id, entry in table.sortedhash(known.sensors) do
            if entry.used then
                local state    = entry.state
                local name     = entry.name
                local internal = entry.internalname
                ctx_NC() context(name)
                ctx_NC() context(entry.identifier)
                ctx_NC() context((state.reachable or entry.reachable) and "yes" or "no ")
                ctx_NC() context(entry.battery or "")
                ctx_NC() if name == internal then context(name) else context.emphasized(internal) end
                ctx_NC() ctx_NR()
            end
        end
        context.stoptabulate()
    end
end
