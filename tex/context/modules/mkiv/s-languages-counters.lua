if not modules then modules = { } end modules ['s-languages-counters'] = {
    version   = 1.001,
    comment   = "companion to s-languages-counters.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages          = moduledata.languages          or { }
moduledata.languages.counters = moduledata.languages.counters or { }

local data = converters.verbose.data

function moduledata.languages.counters.showverbose(specification)
    specification = interfaces.checkedspecification(specification)
    local list = utilities.parsers.settings_to_array(specification.language or "")
    if #list == 0 then
        return
    end
    local used = { }
    local words = { }
    for i=1,#list do
        local ai = list[i]
        local di = data[ai]
        if di and di.words then
            used[#used+1] = ai
            table.merge(words,di.words)
        end
    end
    context.starttabulate { string.rep("|l",#used) .. "|r|" }
    context.HL()
    context.NC()
    for i=1,#used do
        context.bold(used[i])
        context.NC()
    end
    context.bold("number")
    context.NC()
    context.NR()
    context.HL()
    for k, v in table.sortedhash(words) do
        context.NC()
        for i=1,#used do
            context(data[used[i]].words[k] or "")
            context.NC()
        end
        context(k)
        context.NC()
        context.NR()
    end
    context.stoptabulate()
end
