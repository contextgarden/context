if not modules then modules = { } end modules ['meta-tex'] = {
    version   = 1.001,
    comment   = "companion to meta-tex.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring, tonumber = tostring, tonumber
local format = string.format
local formatters = string.formatters
local P, S, R, C, Cs, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.match

metapost        = metapost or { }
local metapost  = metapost
local context   = context

local implement = interfaces.implement

do

    local pattern = Cs((P([[\"]]) + P([["]])/"\\quotedbl{}" + P(1))^0) -- or \char

    function metapost.escaped(str)
        context(lpegmatch(pattern,str))
    end

    implement {
        name      = "metapostescaped",
        actions   = metapost.escaped,
        arguments = "string"
    }

end

do

    local simplify = true
    local number   = C((S("+-")^0 * R("09","..")^1))
    local enumber  = number * S("eE") * number
    local cleaner  = Cs((P("@@")/"@" + P("@")/"%%" + P(1))^0)

    local function format_string(fmt,...)
        context(lpegmatch(cleaner,fmt),...)
    end

    local function format_number(fmt,num)
        if not num then
            num = fmt
            fmt = "%e"
        end
        local number = tonumber(num)
        if number then
            local base, exponent = lpegmatch(enumber,formatters[lpegmatch(cleaner,fmt)](number))
            if base and exponent then
                context.MPexponent(base,exponent)
            else
                context(number)
            end
        else
            context(tostring(num))
        end
    end

    -- This is experimental and will change!

    metapost.format_string = format_string
    metapost.format_number = format_number

    function metapost.svformat(fmt,str)
        format_string(fmt,metapost.untagvariable(str,false))
    end

    function metapost.nvformat(fmt,str)
        format_number(fmt,metapost.untagvariable(str,false))
    end

    local f_exponent = formatters["\\MPexponent{%s}{%s}"]

    -- can be a weak one: mpformatters

    local mpformatters = table.setmetatableindex(function(t,k)
        local v = formatters[lpegmatch(cleaner,k)]
        t[k] = v
        return v
    end)

    function metapost.texexp(num,bfmt,efmt)
        local number = tonumber(num)
        if number then
            local base, exponent = lpegmatch(enumber,format("%e",number))
            if base and exponent then
                if bfmt then
                 -- base = formatters[lpegmatch(cleaner,bfmt)](base)
                    base = mpformatters[bfmt](base)
                else
                    base = format("%f",base)
                end
                if efmt then
                 -- exponent = formatters[lpegmatch(cleaner,efmt)](exponent)
                    exponent = mpformatters[efmt](exponent)
                else
                    exponent = format("%i",exponent)
                end
                return f_exponent(base,exponent)
            elseif bfmt then
             -- return formatters[lpegmatch(cleaner,bfmt)](number)
                return mpformatters[bfmt](number)
            else
                return number
            end
        else
            return num
        end
    end

    implement {
        name      = "metapostformatted",
        actions   = metapost.svformat,
        arguments = "2 strings",
    }

    implement {
        name      = "metapostgraphformat",
        actions   = metapost.nvformat,
        arguments = "2 strings",
    }

    utilities.strings.formatters.add(formatters,"texexp", [[texexp(...)]],      { texexp = metapost.texexp })

    local f_textext = formatters[ [[textext("%s")]] ]
    local f_mthtext = formatters[ [[textext("\mathematics{%s}")]] ]
    local f_exptext = formatters[ [[textext("\mathematics{%s\times10^{%s}}")]] ]

    local mpprint   = mp.print

    function mp.format(fmt,str) -- bah, this overloads mp.format in mlib-lua.lua
        fmt = lpegmatch(cleaner,fmt)
        mpprint(f_textext(formatters[fmt](metapost.untagvariable(str,false))))
    end

    function mp.formatted(fmt,...) -- svformat
        fmt = lpegmatch(cleaner,fmt)
        mpprint(f_textext(formatters[fmt](...)))
    end

    function mp.graphformat(fmt,num) -- nvformat
        fmt = lpegmatch(cleaner,fmt)
        local number = tonumber(num)
        if number then
            local base, exponent = lpegmatch(enumber,number)
            if base and exponent then
                mpprint(f_exptext(base,exponent))
            else
                mpprint(f_mthtext(num))
            end
        else
            mpprint(f_textext(tostring(num)))
        end
    end

end
