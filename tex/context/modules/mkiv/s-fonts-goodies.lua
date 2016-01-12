if not modules then modules = { } end modules['s-fonts-goodies'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-goodies.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts         = moduledata.fonts         or { }
moduledata.fonts.goodies = moduledata.fonts.goodies or { }

local NC, NR, HL = context.NC, context.NR, context.HL

local function initialized(specification)
    specification = interfaces.checkedspecification(specification)
    local name = specification.name
    if name then
        local goodies = fonts.goodies.load(name)
        if goodies then
            return specification, goodies
        end
    end
end

function moduledata.fonts.goodies.showstylistics(specification)
    local specification, goodies = initialized(specification)
    if goodies then
        local stylistics = goodies.stylistics
        if stylistics then
            context.starttabulate { "|Tl|Tpl|" }
            HL()
            NC() context.bold("feature")
            NC() context.bold("meaning")
            NC() NR()
            HL()
            for feature, meaning in table.sortedpairs(stylistics) do
                NC() context(feature)
                NC() context(string.lower(meaning))
                NC() NR()
            end
            HL()
            context.stoptabulate()
        end
    end
end

function moduledata.fonts.goodies.showfeaturesets(specification)
    local specification, goodies = initialized(specification)
    if goodies then
        local featuresets = goodies.featuresets
        if featuresets then
            context.starttabulate { "|Tl|Tpl|" }
            HL()
            NC() context.bold("featureset")
            NC() context.bold("definitions")
            NC() NR()
            HL()
            for featureset, definitions in table.sortedpairs(featuresets) do
                NC() context.type(featureset) NC()
                for k, v in table.sortedpairs(definitions) do
                    context("%s=%S",k,v)
                    context.quad()
                end
                NC() NR()
            end
            HL()
            context.stoptabulate()
        end
    end
end

function moduledata.fonts.goodies.showcolorschemes(specification)
    local specification, goodies = initialized(specification)
    if goodies then
        local colorschemes = goodies.colorschemes
        if colorschemes then
            context.starttabulate { "|Tl|Tpl|" }
            HL()
            NC() context.bold("colorscheme")
            NC() context.bold("numbers")
            NC() NR()
            HL()
            for colorscheme, numbers in table.sortedpairs(colorschemes) do
                NC() context.type(colorscheme) NC()
                for i=1,#numbers do
                    context(i)
                    context.quad()
                end
                NC() NR()
            end
            HL()
            context.stoptabulate()
        end
    end
end

function moduledata.fonts.goodies.showfiles(specification)
    local specification, goodies = initialized(specification)
    if goodies then
        local files = goodies.files
        if files and files.list then
            for filename, specification in table.sortedpairs(files.list) do
                context.start()
                context.dontleavehmode()
                context.definedfont{ filename .. "*default" }
                context("%s-%s-%s-%s-%s",
                    specification.name    or files.name,
                    specification.weight  or "normal",
                    specification.style   or "normal",
                    specification.width   or "normal",
                    specification.variant or "normal")
                context.par()
                context.stop()
            end
        end
    end
end
