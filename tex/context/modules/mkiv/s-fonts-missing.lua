if not modules then modules = { } end modules ['s-fonts-missing'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-missing.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts         = moduledata.fonts         or { }
moduledata.fonts.missing = moduledata.fonts.missing or { }

local function legend(id)
    local privates = fonts.helpers.getprivates(id)
    if privates then
        local categories = table.swapped(fonts.loggers.category_to_placeholder)
        context.starttabulate { "|c|l|" }
            context.HL()
            context.NC()
            context.bold("symbol")
            context.NC()
            context.bold("name")
            context.NC()
            context.NR()
            context.HL()
            for k, v in table.sortedhash(privates) do
                local tag = characters.categorytags[categories[k]]
                if tag and tag ~= "" then
                    context.NC()
                    context.dontleavehmode()
                    context.char(v)
                    context.NC()
                    context(k)
                    context.NC()
                    context.NR()
                end
            end
            context.HL()
        context.stoptabulate()
    end
end

function moduledata.fonts.missing.showlegend(specification)
    specification = interfaces.checkedspecification(specification)
    context.begingroup()
    context.definedfont { "Mono*missing" } -- otherwise no privates added
    context(function() legend(specification.id or font.current()) end)
    context.endgroup()
end

local function missings()
    local collected = fonts.checkers.getmissing()
    for filename, list in table.sortedhash(collected) do
        if #list > 0 then
            context.starttabulate { "|l|l|" }
                context.NC()
                context.bold("filename")
                context.NC()
                context(file.basename(filename))
                context.NC()
                context.NR()
                context.NC()
                context.bold("missing")
                context.NC()
                context(#list)
                context.NC()
                context.NR()
            context.stoptabulate()
            context.starttabulate { "|l|c|l|" }
                for i=1,#list do
                    local u = list[i]
                    context.NC()
                    context("%U",u)
                    context.NC()
                    context.char(u)
                    context.NC()
                    context(characters.data[u].description)
                    context.NC()
                    context.NR()
                end
            context.stoptabulate()
        end
    end
end

function moduledata.fonts.missing.showcharacters(specification)
    context.begingroup()
    context.definedfont { "Mono*missing" } -- otherwise no privates added
    context(function() missings() end)
    context.endgroup()
end
