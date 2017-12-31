if not modules then modules = { } end modules ['x-calcmath'] = {
    version   = 1.001,
    comment   = "companion to x-calcmath.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this really needs to be redone

local next, type = next, type
local format, lower, upper, gsub, sub = string.format, string.lower, string.upper, string.gsub, string.sub
local concat = table.concat
local lpegmatch = lpeg.match

local calcmath      = { }
local moduledata    = moduledata or { }
moduledata.calcmath = calcmath

local context       = context

local list_1 = {
    "median", "min", "max", "round", "ln", "log",
    "sin", "cos", "tan", "sinh", "cosh", "tanh"
}
local list_2 = {
    "int", "sum", "prod"
}
local list_3 = {
    "f", "g"
}
local list_4 = {
    "pi", "inf"
}

local list_1_1 = { }
local list_2_1 = { }
local list_2_2 = { }
local list_2_3 = { }
local list_4_1 = { }

local frozen = false

local function freeze()
    for k=1,#list_1 do
        local v = list_1[k]
        list_1_1[v] = "\\".. upper(v) .." "
    end
    for k=1,#list_2 do
        local v = list_2[k]
        list_2_1[v .. "%((.-),(.-),(.-)%)"] = "\\" .. upper(v) .. "^{%1}_{%2}{%3}"
        list_2_2[v .. "%((.-),(.-)%)"]      = "\\" .. upper(v) .. "^{%1}{%2}"
        list_2_3[v .. "%((.-)%)"]           = "\\" .. upper(v) .. "{%1}"
    end
    for k=1,#list_4 do
        local v = list_4[k]
        list_4_1[v] = "\\" .. upper(v)
    end
    frozen = true
end

local entities = {
    ['gt'] = '>',
    ['lt'] = '<',
}

local symbols = {
    ["<="] = "\\LE ",
    [">="] = "\\GE ",
    ["=<"] = "\\LE ",
    ["=>"] = "\\GE ",
    ["=="] = "\\EQ ",
    ["<" ] = "\\LT ",
    [">" ] = "\\GT ",
    ["="]  = "\\EQ ",
}

local function nsub(str,tag,pre,post)
    return (gsub(str,tag .. "(%b())", function(body)
        return pre .. nsub(sub(body,2,-2),tag,pre,post) .. post
    end))
end

local function totex(str,mode)
    if not frozen then freeze() end
    local n = 0
    -- crap
    str = gsub(str,"%s+",' ')
    -- xml
    str = gsub(str,"&(.-);",entities)
    -- ...E...
    str = gsub(str,"([%-%+]?[%d%.%+%-]+)E([%-%+]?[%d%.]+)", "{\\SCINOT{%1}{%2}}")
    -- ^-..
    str = gsub(str,"%^([%-%+]*%d+)", "^{%1}")
    -- ^(...)
    str = nsub(str,"%^", "^{", "}")
    -- 1/x^2
    repeat
        str, n = gsub(str,"([%d%w%.]+)/([%d%w%.]+%^{[%d%w%.]+})", "\\frac{%1}{%2}")
    until n == 0
    -- todo: autoparenthesis
    -- int(a,b,c)
    for k, v in next, list_2_1 do
        repeat str, n = gsub(str,k,v) until n == 0
    end
    -- int(a,b)
    for k, v in next, list_2_2 do
        repeat str, n = gsub(str,k,v) until n == 0
    end
    -- int(a)
    for k, v in next, list_2_3 do
        repeat str, n = gsub(str,k,v) until n == 0
    end
    -- sin(x) => {\\sin(x)}
    for k, v in next, list_1_1 do
        repeat str, n = gsub(str,k,v) until n == 0
    end
    -- mean
    str = nsub(str, "mean", "\\OVERLINE{", "}")
    -- (1+x)/(1+x) => \\FRAC{1+x}{1+x}
    repeat
        str, n = gsub(str,"(%b())/(%b())", function(a,b)
            return "\\FRAC{" .. sub(a,2,-2) .. "}{" .. sub(b,2,-2) .. "}"
        end )
    until n == 0
    -- (1+x)/x => \\FRAC{1+x}{x}
    repeat
        str, n = gsub(str,"(%b())/([%+%-]?[%.%d%w]+)", function(a,b)
            return "\\FRAC{" .. sub(a,2,-2) .. "}{" .. b .. "}"
        end )
    until n == 0
    -- 1/(1+x) => \\FRAC{1}{1+x}
    repeat
        str, n = gsub(str,"([%.%d%w]+)/(%b())", function(a,b)
            return "\\FRAC{" .. a .. "}{" .. sub(b,2,-2) .. "}"
        end )
    until n == 0
    -- 1/x => \\FRAC{1}{x}
    repeat
        str, n = gsub(str,"([%.%d%w]+)/([%+%-]?[%.%d%w]+)", "\\FRAC{%1}{%2}")
    until n == 0
    -- times
    str = gsub(str,"%*", " ")
    -- symbols -- we can use a table substitution here
    str = gsub(str,"([<>=][<>=]*)", symbols)
    -- functions
    str = nsub(str,"sqrt", "\\SQRT{", "}")
    str = nsub(str,"exp", "e^{", "}")
    str = nsub(str,"abs", "\\left|", "\\right|")
    -- d/D
    str = nsub(str,"D", "{\\FRAC{\\MBOX{d}}{\\MBOX{d}x}{(", ")}}")
    str = gsub(str,"D([xy])", "\\FRAC{{\\RM d}%1}{{\\RM d}x}")
    -- f/g
    for k,v in next, list_3 do -- todo : prepare k,v
        str = nsub(str,"D"..v,"{\\RM "..v.."}^{\\PRIME}(",")")
        str = nsub(str,v,"{\\RM "..v.."}(",")")
    end
    -- more symbols
    for k,v in next, list_4_1 do
        str = gsub(str,k,v)
    end
    -- parenthesis (optional)
    if mode == 2 then
      str = gsub(str,"%(", "\\left(")
      str = gsub(str,"%)", "\\right)")
    end
    -- csnames
    str = gsub(str,"(\\[A-Z]+)", lower)
    -- report
    return str
end

calcmath.totex      = totex

function calcmath.tex(str,mode)
    context(totex(str))
end

function calcmath.xml(id,mode)
    context(totex(lxml.id(id).dt[1],mode))
end

-- work in progress ... lpeg variant

if false then

    -- todo:

    -- maybe rewrite to current lpeg, i.e. string replacement and no Cc's

    -- table approach we have now is less efficient but more flexible

    -- D          \frac  {\rm d}   {{\rm d}x}
    -- Dx Dy      \frac {{\rm d}y} {{\rm d}x}
    -- Df Dg      {\rm f}^{\prime}
    -- f() g()    {\rm f}()

    -- valid utf8

    local S, P, R, C, V, Cc, Ct  = lpeg.S, lpeg.P, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Ct

    local space      = S(" \n\r\t")^0
    local integer    = P("-")^-1 * R("09")^1
    local realpart   = P("-")^-1 * R("09")^1 * S(".")^1 * R("09")^1
    local number     = Cc("number")     * C(integer) * space
    local real       = Cc("real")       * C(realpart) * space
    local float      = Cc("float")      * C(realpart) * lpeg.P("E") * lpeg.C(integer) * space
    local identifier = Cc("identifier") * C(R("az","AZ")) * space
    local compareop  = Cc("compare")    * C(P("<") + P("=") + P(">") + P(">=") + P("<=") + P("&gt;") + P("&lt;")) * space
    local factorop   = Cc("factor")     * C(S("+-^_,")) * space
    local termop     = Cc("term")       * C(S("*/")) * space
    local constant   = Cc("constant")   * C(P("pi") + lpeg.P("inf")) * space
    local functionop = Cc("function")   * C(R("az")^1) * space
    local open       = P("(") * space
    local close      = P(")") * space

    local grammar = P {
        "expression",
        expression = Ct(V("factor") * ((factorop+compareop) * V("factor"))^0),
        factor     = Ct(V("term") * (termop * V("term"))^0),
        term       = Ct(
            float + real + number +
            (open * V("expression") * close) +
            (functionop * open * (V("expression") * (P(",") * V("expression"))^0) * close) +
            (functionop * V("term")) +
            constant + identifier
        ),
    }

    local parser = space * grammar * -1

    local function has_factor(t)
        for i=1,#t do
            if t[i] == "factor" then
                return true
            end
        end
    end

    -- can be sped up if needed ...

    function totex(t)
        if t then
            local one = t[1]
            if type(one) == "string" then
                local two, three = t[2], t[3]
                if one == "number" then
                    context(two)
                elseif one == "real" then
                    context(two)
                elseif one == "float" then
                    context("\\scinot{",two,"}{",three,"}")
                elseif one == "identifier" then
                    context(two)
                elseif one == "constant" then
                    context("\\"..two)
                elseif one == "function" then
                    if two == "sqrt" then
                        context("\\sqrt{")
                        totex(three)
                        context("}")
                    elseif two == "exp" then
                        context(" e^{")
                        totex(three)
                        context("}")
                    elseif two == "abs" then
                        context("\\left|")
                        totex(three)
                        context("\\right|")
                    elseif two == "mean" then
                        context("\\overline{")
                        totex(three)
                        context("}")
                    elseif two == "int" or two == "prod" or two == "sum" then
                        local four, five = t[4], t[5]
                        if five then
                            context("\\"..two.."^{") -- context[two]("{")
                            totex(three)
                            context("}_{")
                            totex(four)
                            context("}")
                            totex(five)
                        elseif four then
                            context("\\"..two.."^{")
                            totex(three)
                            context("}")
                            totex(four)
                        elseif three then
                            context("\\"..two.." ") -- " " not needed
                            totex(three)
                        else
                            context("\\"..two)
                        end
                    else
                        context("\\"..two.."(")
                        totex(three)
                        context(")")
                    end
                end
            else
                local nt = #t
                local hasfactor = has_factor(t)
                if hasfactor then
                    context("\\left(")
                end
                totex(one)
                for i=2,nt,3 do
                    local what, how, rest = t[i], t[i+1], t[i+2]
                    if what == "factor" then
                        if how == '^' or how == "_" then
                            context(how)
                            context("{")
                            totex(rest)
                            context("}")
                        else
                            context(how)
                            totex(rest)
                        end
                    elseif what == "term" then
                        if how == '/' then
                            context("\\frac{")
                            totex(rest)
                            context("}{")
                            totex(t[i+3] or "")
                            context("}")
                        elseif how == '*' then
                            context("\\times")
                            totex(rest)
                        else
                            context(how)
                            totex(three)
                        end
                    elseif what == "compare" then
                        if two == ">=" then
                            context("\\ge")
                        elseif two == "<=" then
                            context("\\le")
                        elseif two == "&gt;" then
                            context(">")
                        elseif two == "&lt;" then
                            context("<")
                        end
                        totex(three)
                    end
                end
                if hasfactor then
                    context("\\right)")
                end
            end
        end
    end

    calcmath = { }

    function calcmath.parse(str)
        return lpegmatch(parser,str)
    end

    function calcmath.tex(str)
        str = totex(lpegmatch(parser,str))
        return (str == "" and "[error]") or str
    end

end
