if not modules then modules = { } end modules ['s-math-coverage'] = {
    version   = 1.001,
    comment   = "companion to s-math-coverage.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.math            = moduledata.math            or { }
moduledata.math.parameters = moduledata.math.parameters or { }

local tables = utilities.tables.definedtable("math","tracing","spacing","tables")

tables.styleaxis = {
    "ord", "op", "bin", "rel", "open", "close", "punct", "inner",
}

tables.parameters = {
    "quad", "axis", "operatorsize",
    "overbarkern", "overbarrule", "overbarvgap",
    "underbarkern", "underbarrule", "underbarvgap",
    "radicalkern", "radicalrule", "radicalvgap",
    "radicaldegreebefore", "radicaldegreeafter", "radicaldegreeraise",
    "stackvgap", "stacknumup", "stackdenomdown",
    "fractionrule", "fractionnumvgap", "fractionnumup",
    "fractiondenomvgap", "fractiondenomdown", "fractiondelsize",
    "limitabovevgap", "limitabovebgap", "limitabovekern",
    "limitbelowvgap", "limitbelowbgap", "limitbelowkern",
    "underdelimitervgap", "underdelimiterbgap",
    "overdelimitervgap", "overdelimiterbgap",
    "subshiftdrop", "supshiftdrop", "subshiftdown",
    "subsupshiftdown", "subtopmax", "supshiftup",
    "supbottommin", "supsubbottommax", "subsupvgap",
    "spaceafterscript", "connectoroverlapmin",
}

tables.styles = {
    "display",
    "text",
    "script",
    "scriptscript",
}

function tables.stripmu(str)
    str = string.gsub(str,"mu","")
    str = string.gsub(str," ","")
    str = string.gsub(str,"plus","+")
    str = string.gsub(str,"minus","-")
    return str
end

function tables.strippt(old)
    local new = string.gsub(old,"pt","")
    if new ~= old then
        new = string.format("%0.4f",tonumber(new))
    end
    return new
end

function moduledata.math.parameters.showspacing()

    local styles    = tables.styles
    local styleaxis = tables.styleaxis

    context.starttabulate { "|Tl|Tl|" .. string.rep("Tc|",(#styles*2)) }
        context.HL()
        context.NC()
        context.NC()
        context.NC()
        for i=1,#styles do
            context.bold(styles[i])
            context.NC()
            context.bold("(cramped)")
            context.NC()
        end
        context.NR()
        context.HL()
        for i=1,#styleaxis do
         -- print(key,tex.getmath(key,"text"))
            local one = styleaxis[i]
            for j=1,#styleaxis do
                local two = styleaxis[j]
                context.NC()
                if j == 1 then
                    context.bold(one)
                end
                context.NC()
                context.bold(two)
                context.NC()
                for i=1,#styles do
                    context("\\ctxlua{context(math.tracing.spacing.tables.stripmu('\\the\\Umath%s%sspacing\\%sstyle'))}",one,two,styles[i])
                    context.NC()
                    context("\\ctxlua{context(math.tracing.spacing.tables.stripmu('\\the\\Umath%s%sspacing\\cramped%sstyle'))}",one,two,styles[i])
                    context.NC()
                end
                context.NR()
            end
        end
    context.stoptabulate()
end

function moduledata.math.parameters.showparameters()

    local styles     = tables.styles
    local parameters = tables.parameters

    context.starttabulate { "|l|" .. string.rep("Tc|",(#styles*2)) }
        context.HL()
        context.NC()
        context.NC()
        for i=1,#styles do
            context.bold(styles[i])
            context.NC()
            context.bold("(cramped)")
            context.NC()
        end
        context.NR()
        context.HL()
        for i=1,#parameters do
            local parameter = parameters[i]
         -- print(parameter,tex.getmath(parameter,"text"))
            context.NC()
            context.type(parameter)
            context.NC()
            for i=1,#styles do
                context("\\ctxlua{context(math.tracing.spacing.tables.strippt('\\the\\Umath%s\\%sstyle'))}",parameter,styles[i])
                context.NC()
                context("\\ctxlua{context(math.tracing.spacing.tables.strippt('\\the\\Umath%s\\cramped%sstyle'))}",parameter,styles[i])
                context.NC()
            end
            context.NR()
        end
    context.stoptabulate()

end
