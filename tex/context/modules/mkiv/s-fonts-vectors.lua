if not modules then modules = { } end modules ['s-fonts-vectors'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-vectors.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts             = moduledata.fonts             or { }
moduledata.fonts.protrusions = moduledata.fonts.protrusions or { }
moduledata.fonts.expansions  = moduledata.fonts.expansions  or { }

local NC, NR = context.NC, context.NR

local classes = fonts.protrusions.classes
local vectors = fonts.protrusions.vectors

function moduledata.fonts.protrusions.showvector(specification)
    specification = interfaces.checkedspecification(specification)
    local vector = vectors[specification.name or "?"]
    if vector then
        context.blank()
        context.startcolumns { n = specification.columns or 3, balance="yes"  }
            context.starttabulate { "|T||cw(.5em)||" }
                for unicode, values in table.sortedhash(vector) do
                    NC() context("%U",unicode)
                    NC() context("%.02f",values[1])
                    NC() context("%c",unicode)
                    NC() context("%.02f",values[2])
                    NC() NR()
                end
            context.stoptabulate()
        context.stopcolumns()
        context.blank()
    end
end

function moduledata.fonts.protrusions.showclass(specification)
    specification = interfaces.checkedspecification(specification)
    local class = specification.name and classes[specification.name]
    local classes = class and { class} or classes
    context.starttabulate { "|l|l|r|r|r|" }
        NC() context.bold("name")
        NC() context.bold("vector")
        NC() context.bold("factor")
        NC() context.bold("left")
        NC() context.bold("right")
        NC() NR()
        for name, class in table.sortedhash(classes) do
            NC() context(name)
            NC() context(class.vector)
            NC() context("%.02f",class.factor)
            NC() context("%.02f",class.left)
            NC() context("%.02f",class.right)
            NC() NR()
        end
    context.stoptabulate()
end

local classes = fonts.expansions.classes
local vectors = fonts.expansions.vectors

function moduledata.fonts.expansions.showvector(specification)
    specification = interfaces.checkedspecification(specification)
    local vector = vectors[specification.name or "?"]
    if vector then
        context.blank()
        context.startcolumns { n = specification.columns or 3, balance="yes"  }
            context.starttabulate { "|T|cw(.5em)||" }
                for unicode, value in table.sortedhash(vector) do
                    NC() context("%U",unicode)
                    NC() context("%c",unicode)
                    NC() context("%.02f",value)
                    NC() NR()
                end
            context.stoptabulate()
        context.stopcolumns()
        context.blank()
    end
end

function moduledata.fonts.expansions.showclass(specification)
    specification = interfaces.checkedspecification(specification)
    local class = specification.name and classes[specification.name]
    local classes = class and { class} or classes
    context.starttabulate { "|l|l|r|r|r|" }
        NC() context.bold("name")
        NC() context.bold("vector")
        NC() context.bold("step")
        NC() context.bold("factor")
        NC() context.bold("stretch")
        NC() context.bold("shrink")
        NC() NR()
        for name, class in table.sortedhash(classes) do
            NC() context(name)
            NC() context(class.vector)
            NC() context("%.02f",class.step)
            NC() context("%.02f",class.factor)
            NC() context("% 2i",class.stretch)
            NC() context("% 2i",class.shrink)
            NC() NR()
        end
    context.stoptabulate()
end
