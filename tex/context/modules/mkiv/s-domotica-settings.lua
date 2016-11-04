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

    if string.find(pattern,"%*") then

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
