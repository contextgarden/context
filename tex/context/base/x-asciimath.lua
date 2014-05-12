if not modules then modules = { } end modules ['x-asciimath'] = {
    version   = 1.001,
    comment   = "companion to x-asciimath.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Some backgrounds are discussed in <t>x-asciimath.mkiv</t>.</p>
--ldx]]--

local trace_mapping = false  if trackers then trackers.register("modules.asciimath.mapping", function(v) trace_mapping = v end) end

local asciimath      = { }
local moduledata     = moduledata or { }
moduledata.asciimath = asciimath

local report_asciimath = logs.reporter("mathematics","asciimath")

local format = string.format
local lpegmatch = lpeg.match
local S, P, R, C, V, Cc, Ct, Cs = lpeg.S, lpeg.P, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Ct, lpeg.Cs

local letter     = lpeg.patterns.utf8
local space      = S(" \n\r\t")
local spaces     = space^0/""
local integer    = P("-")^-1 * R("09")^1
local realpart   = P("-")^-1 * R("09")^1 * S(".")^1 * R("09")^1
local number     = integer -- so we can support nice formatting if needed
local real       = realpart -- so we can support nice formatting if needed
local float      = realpart * P("E") * integer -- so we can support nice formatting if needed
local texnic     = P("\\") * (R("az","AZ")^1)

local premapper = Cs ( (

    P("@")    / "\\degrees " +
    P("O/")   / "\\varnothing " +
    P("o+")   / "\\oplus " +
    P("o.")   / "\\ocirc " +
    P("!in")  / "\\not\\in "  +
    P("!=")   / "\\neq " +
    P("**")   / "\\star " +
    P("*")    / "\\cdot " +
    P("//")   / "\\slash " +
    P("/_")   / "\\angle " +
    P("\\\\") / "\\backslash " +
    P("^^^")  / "\\wedge " +
    P("^^")   / "\\wedge " +
    P("<<")   / "\\left\\langle " +
    P(">>")   / "\\right\\rangle " +
    P("<=")   / "\\leq " +
    P(">=")   / "\\geq " +
    P("-<")   / "\\precc " +
    P(">-")   / "\\succ " +
    P("~=")   / "\\cong " +
    P("~~")   / "\\approx " +
    P("=>")   / "\\Rightarrow " +
    P("(:")   / "\\left\\langle " +
    P(":)")   / "\\right\\rangle " +
    P(":.")   / "\\therefore " +
    P("~|")   / "\\right\\rceil " +
    P("_|_")  / "\\bot " +
    P("_|")   / "\\right\\rfloor " +
    P("+-")   / "\\pm " +
    P("|--")  / "\\vdash " +
    P("|==")  / "\\models " +
    P("|_")   / "\\left\\lfloor " +
    P("|~")   / "\\left\\lceil " +
    P("-:")   / "\\div " +
    P("_=")   / "\\equiv " +

    P("|")    / "\\middle\\| " +

    P("dx")   / "(dx)" +
    P("dy")   / "(dy)" +
    P("dz")   / "(dz)" +

    letter + P(1)

)^0 )

local reserved = {
    ["aleph"] = "\\aleph ",
    ["vdots"] = "\\vdots ",
    ["ddots"] = "\\ddots ",
    ["oint"]  = "\\oint ",
    ["grad"]  = "\\nabla ",
    ["prod"]  = "\\prod ",
    ["prop"]  = "\\propto ",
    ["sube"]  = "\\subseteq ",
    ["supe"]  = "\\supseteq ",
    ["sinh"]  = "\\sinh ",
    ["cosh"]  = "\\cosh ",
    ["tanh"]  = "\\tanh ",
    ["sum"]   = "\\sum ",
    ["vvv"]   = "\\vee ",
    ["nnn"]   = "\\cap ",
    ["uuu"]   = "\\cup ",
    ["sub"]   = "\\subset ",
    ["sup"]   = "\\supset ",
    ["not"]   = "\\lnot ",
    ["iff"]   = "\\Leftrightarrow ",
    ["int"]   = "\\int ",
    ["del"]   = "\\partial ",
    ["and"]   = "\\and ",
    ["not"]   = "\\not ",
    ["sin"]   = "\\sin ",
    ["cos"]   = "\\cos ",
    ["tan"]   = "\\tan ",
    ["csc"]   = "\\csc ",
    ["sec"]   = "\\sec ",
    ["cot"]   = "\\cot ",
    ["log"]   = "\\log ",
    ["det"]   = "\\det ",
    ["lim"]   = "\\lim ",
    ["mod"]   = "\\mod ",
    ["gcd"]   = "\\gcd ",
    ["lcm"]   = "\\lcm ",
    ["min"]   = "\\min ",
    ["max"]   = "\\max ",
    ["xx"]    = "\\times ",
    ["in"]    = "\\in ",
    ["ox"]    = "\\otimes ",
    ["vv"]    = "\\vee ",
    ["nn"]    = "\\cap ",
    ["uu"]    = "\\cup ",
    ["oo"]    = "\\infty ",
    ["ln"]    = "\\ln ",
    ["or"]    = "\\or ",

    ["AA"]    = "\\forall ",
    ["EE"]    = "\\exists ",
    ["TT"]    = "\\top ",
    ["CC"]    = "\\Bbb{C}",
    ["NN"]    = "\\Bbb{N}",
    ["QQ"]    = "\\Bbb{Q}",
    ["RR"]    = "\\Bbb{R}",
    ["ZZ"]    = "\\Bbb{Z}",

}

table.setmetatableindex(reserved,characters.entities)

local postmapper = Cs ( (

    P("\\mathoptext ") * spaces * (P("\\bgroup ")/"{") * (1-P("\\egroup "))^1 * (P("\\egroup ")/"}") +

    (P("\\bgroup ")) / "{" +
    (P("\\egroup ")) / "}" +

    P("\\") * (R("az","AZ")^2) +

    (R("AZ","az")^2) / reserved +

    P("{:")          / "\\left." +
    P(":}")          / "\\right." +
    P("(")           / "\\left(" +
    P(")")           / "\\right)" +
    P("[")           / "\\left[" +
    P("]")           / "\\right]" +
    P("{")           / "\\left\\{" +
    P("}")           / "\\right\\}" +

    letter + P(1)
)^0 )

local parser

local function converted(original,totex)
    local ok, result
    if trace_mapping then
        report_asciimath("original : %s",original)
    end
    local premapped = lpegmatch(premapper,original)
    if premapped then
        if trace_mapping then
            report_asciimath("prepared : %s",premapped)
        end
        local parsed = lpegmatch(parser,premapped)
        if parsed then
            if trace_mapping then
                report_asciimath("parsed   : %s",parsed)
            end
            local postmapped = lpegmatch(postmapper,parsed)
            if postmapped then
                if trace_mapping then
                    report_asciimath("finalized: %s",postmapped)
                end
                result, ok = postmapped, true
            else
                result = "error in postmapping"
            end
        else
            result = "error in mapping"
        end
    else
        result = "error in premapping"
    end
    if totex then
        if ok then
            context.mathematics(result)
        else
            context.type(result) -- some day monospaced
        end
    else
        return result
    end
end

local function onlyconverted(str)
    local parsed = lpegmatch(parser,str)
    return parsed or str
end

local sqrt          = P("sqrt")     / "\\rootradical \\bgroup \\egroup "
local root          = P("root")     / "\\rootradical "
local frac          = P("frac")     / "\\frac "
local stackrel      = P("stackrel") / "\\stackrel "
local text          = P("text")     / "\\mathoptext "
local hat           = P("hat")      / "\\widehat "
local overbar       = P("bar")      / "\\overbar "
local underline     = P("ul")       / "\\underline "
local vec           = P("vec")      / "\\overrightarrow "
local dot           = P("dot")      / "\\dot "
local ddot          = P("ddot")     / "\\ddot "

local left          = P("(:") + P("{:") + P("(") + P("[") + P("{")
local right         = P(":)") + P(":}") + P(")") + P("]") + P("}")
local leftnorright  = 1 - left - right
local singles       = sqrt + text + hat + underline + overbar + vec + ddot + dot
local doubles       = root + frac + stackrel
local ignoreleft    = (left/"") * spaces * spaces
local ignoreright   = spaces * (right/"") * spaces
local ignoreslash   = spaces * (P("/")/"") * spaces
local comma         = P(",")
local nocomma       = 1-comma
local anychar       = P(1)
local openmatrix    = left * spaces * Cc("\\matrix\\bgroup ")
local closematrix   = Cc("\\egroup ") * spaces * right
local nextcolumn    = spaces * (comma/"&") * spaces
local nextrow       = spaces * (comma/"\\cr ") * spaces
local finishrow     = Cc("\\cr ")
local opengroup     = left/"\\bgroup "
local closegroup    = right/"\\egroup "
local somescript    = S("^_") * spaces
local beginargument = Cc("\\bgroup ")
local endargument   = Cc("\\egroup ")

parser = Cs { "main",

    scripts     = somescript * V("argument"),
    division    = Cc("\\frac") * V("argument") * spaces * ignoreslash * spaces * V("argument"),
    double      = doubles * spaces * V("argument") * spaces * V("argument"),
    single      = singles * spaces * V("argument"),

    balanced    = opengroup * (C((leftnorright + V("balanced"))^0)/onlyconverted) * closegroup,
    argument    = V("balanced") + V("token"),

    element     = (V("step") + (V("argument") + V("step")) - ignoreright - nextcolumn - comma)^1,
    commalist   = ignoreleft * V("element") * (nextcolumn * spaces * V("element"))^0 * ignoreright,
    matrix      = openmatrix * spaces * (V("commalist") * (nextrow * V("commalist"))^0) * finishrow * closematrix,

    token       = beginargument * (texnic + float + real + number + letter) * endargument,

    step        = V("scripts") + V("division") + V("single") + V("double"),
    main        = (V("matrix") + V("step") + anychar)^0,

}

asciimath.reserved = reserved
asciimath.convert  = converted

commands.convert = converted
