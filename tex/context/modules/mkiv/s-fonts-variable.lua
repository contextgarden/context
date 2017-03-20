if not modules then modules = { } end modules ['s-fonts-variable'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-variable.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts          = moduledata.fonts          or { }
moduledata.fonts.variable = moduledata.fonts.variable or { }

local format      = string.format
local stripstring = string.nospaces
local lower       = string.lower
local rep         = string.rep

local context = context
local NC, NR, HL = context.NC, context.NR, context.HL
local bold, monobold, mono, formattedmono = context.bold, context.monobold, context.mono, context.formatted.mono

function moduledata.fonts.variable.showvariations(specification)

    specification = interfaces.checkedspecification(specification)

    local fontfile = specification.font
    local fontname = format("testfont-%s",i)
    local fontsize = tex.dimen.bodyfontsize
    if not fontfile then
        return
    end

    local id, fontdata = fonts.definers.define {
        name = fontfile,
        size = fontsize,
        cs   = fontname,
    }

    local resources = fontdata.resources

    if not resources then
        return
    end

    local variabledata = resources.variabledata

    if not variabledata then
        return
    end

    context.starttitle { title = fontdata.shared.rawdata.metadata.fullname }

    local parameters = fontdata.parameters

    context.startsubject { title = "parameters" }
        if parameters then
            context.starttabulate { "|||" }
                NC() monobold("ascender")  NC() context("%p",parameters.ascender)     NC() NR()
                NC() monobold("descender") NC() context("%p",parameters.descender)    NC() NR()
                NC() monobold("emwidth")   NC() context("%p",parameters.em)           NC() NR()
                NC() monobold("exheight")  NC() context("%p",parameters.ex)           NC() NR()
                NC() monobold("size")      NC() context("%p",parameters.size)         NC() NR()
                NC() monobold("slant")     NC() context("%s",parameters.slant)        NC() NR()
                NC() monobold("space")     NC() context("%p",parameters.space)        NC() NR()
                NC() monobold("shrink")    NC() context("%p",parameters.spaceshrink)  NC() NR()
                NC() monobold("stretch")   NC() context("%p",parameters.spacestretch) NC() NR()
                NC() monobold("units")     NC() context("%s",parameters.units)        NC() NR()
            context.stoptabulate()
        else
            context("no parameters")
        end
    context.stopsubject()

    local features = fontdata.shared.rawdata.resources.features

    context.startsubject { title = "features" }
        if features then
            local function f(g)
                if g then
                    local t = table.sortedkeys(g)
                    local n = 0
                    for i=1,#t do
                        if #t[i] <= 4 then
                            n = n + 1
                            t[n] = t[i]
                        end
                    end
                    return table.concat(t," ",1,n)
                end
            end
            context.starttabulate { "||p|" }
                NC() monobold("gpos")  NC() mono(f(features.gpos)) NC() NR()
                NC() monobold("gsub")  NC() mono(f(features.gsub)) NC() NR()
            context.stoptabulate()
        else
            context("no features")
        end
    context.stopsubject()

    local designaxis = variabledata.designaxis

    context.startsubject { title = "design axis" }
        if designaxis then
            context.starttabulate { "||||c|c|c|c|c|" }
                NC() bold("tag")
                NC() bold("name")
                NC() bold("variant")
                NC() bold("flags")
                NC() bold("value")
                NC() bold("min")
                NC() bold("max")
                NC() bold("link")
                NC() NR()
                HL()
                for k=1,#designaxis do
                    local axis      = designaxis[k]
                    local tag       = axis.tag
                    local name      = axis.name
                    local variants  = axis.variants
                    local haslimits = variants[1].maximum
                    local haslink   = variants[1].link
                    for i=1,#variants do
                        local variant = variants[i]
                        NC() monobold(tag)
                        NC() context(name)
                        NC() context(variant.name)
                        NC() formattedmono("0x%04x",variant.flags)
                        NC() context(variant.value)
                        NC() context(variant.minimum or "-")
                        NC() context(variant.maximum or "-")
                        NC() context(variant.link or "-")
                        NC() NR()
                        tag  = nil
                        name = nil
                    end
                end
            context.stoptabulate()
        else
            context("no design axis defined (no \\type{stat} table)")
        end
    context.stopsubject()

    local axis      = variabledata.axis
    local instances = variabledata.instances
    local list      = { }

    context.startsubject { title = "axis" }
        if axis then
            context.starttabulate { "|||c|c|c|" }
                NC() bold("tag")
                NC() bold("name")
                NC() bold("min")
                NC() bold("def")
                NC() bold("max")
                NC() NR()
                HL()
                for k=1,#axis do
                    local a = axis[k]
                    NC() monobold(a.tag)
                    NC() context(a.name)
                    NC() context(a.minimum)
                    NC() context(a.default)
                    NC() context(a.maximum)
                    NC() NR()
                    list[#list+1] = a.tag
                end
            context.stoptabulate()
        else
            context("no axis defined, incomplete \\type{fvar} table")
        end
    context.stopsubject()

    local collected = { }

    context.startsubject { title = "instances" }
        if instances and #list > 0 then
            context.starttabulate { "||" .. rep("c|",#list) .. "|" }
                NC()
                for i=1,#list do
                    NC() monobold(list[i])
                end
                NC()
                local fullname = lower(stripstring(fontdata.shared.rawdata.metadata.fullname))
                formattedmono("%s*",fullname)
                NC() NR()
                HL()
                for k=1,#instances do
                    local i = instances[k]
                    NC() monobold(i.subfamily)
                    local values = i.values
                    local hash = { }
                    for k=1,#values do
                        local v = values[k]
                        hash[v.axis] = v.value
                    end
                    for i=1,#list do
                        NC() context(hash[list[i]])
                    end
                    NC()
                    local instance = lower(stripstring(i.subfamily))
                    mono(instance)
                    collected[#collected+1] = fullname .. instance
                    NC() NR()
                end
            context.stoptabulate()
        else
            context("no instances defined, incomplete \\type{fvar} table")
        end
    context.stopsubject()

    for i=1,#collected do

        local instance = collected[i]
        context.startsubject { title = instance }
            context.start()
            context.definedfont { "name:" .. instance .. "*default" }
            context.input("zapf.tex")
            context.par()
            context.stop()
        context.stopsubject()
    end

 -- local function showregions(tag)
 --
 --     local regions = variabledata[tag]
 --
 --     context.startsubject { title = tag }
 --         if regions then
 --             context.starttabulate { "|r|c|r|r|r|" }
 --             NC() bold("n")
 --             NC() bold("axis")
 --             NC() bold("start")
 --             NC() bold("peak")
 --             NC() bold("stop")
 --             NC() NR()
 --             HL()
 --             local designaxis = designaxis or axis
 --             for i=1,#regions do
 --                 local axis = regions[i]
 --                 for j=1,#axis do
 --                     local a = axis[j]
 --                     NC() monobold(i)
 --                     NC() monobold(designaxis[j].tag)
 --                     NC() context("%0.3f",a.start)
 --                     NC() context("%0.3f",a.peak)
 --                     NC() context("%0.3f",a.stop)
 --                     NC() NR()
 --                     i = nil
 --                 end
 --             end
 --             context.stoptabulate()
 --         else
 --             context("no %s defined",tag)
 --         end
 --     context.stopsubject()
 --
 -- end
 --
 -- showregions("gregions")
 -- showregions("mregions")
 -- showregions("hregions")

    context.stoptitle()

end
