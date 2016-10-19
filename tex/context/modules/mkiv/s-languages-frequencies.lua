if not modules then modules = { } end modules ['s-languages-frequencies'] = {
    version   = 1.001,
    comment   = "companion to s-languages-frequencies.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages             = moduledata.languages             or { }
moduledata.languages.frequencies = moduledata.languages.frequencies or { }

function moduledata.languages.frequencies.showlist(specification)
    specification = interfaces.checkedspecification(specification)
    local t = languages.frequencies.getdata(specification.language or languages.current())
    context.starttabulate { "|lT|cw(2em)|r|" }
    context.NC()
    context.formatted.rlap("%s: %p",t.language,languages.frequencies.averagecharwidth(t.language))
    context.NC()
    context.NC()
    context.NR()
    context.HL()
    for k, v in table.sortedhash(t.frequencies) do
        context.NC()
        context("%U",k)
        context.NC()
        context("%c",k)
        context.NC()
        context("%0.3f",v)
        context.NC()
        context.NR()
    end
    context.stoptabulate()
end

-- function MP.frqc(language,slot)
--     mp.print(languages.frequencies.getdata(language).frequencies[slot])
-- end
