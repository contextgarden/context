if not modules then modules = { } end modules ['meta-ini'] = {
    version   = 1.001,
    comment   = "companion to meta-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format = string.format
local concat = table.concat
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, Cs, R, S, C, Cc = lpeg.P, lpeg.Cs, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc

metapost       = metapost or { }
local metapost = metapost
local context  = context

local colorhash = attributes.list[attributes.private('color')]
local textype   = tex.type
local MPcolor   = context.MPcolor

do

    local dimenorname  =
        lpegpatterns.validdimen / function(s)
            context("\\the\\dimexpr %s",s)
        end
      + (C(lpegpatterns.float) + Cc(1)) * lpegpatterns.space^0 * P("\\") * C(lpegpatterns.letter^1) / function(f,s)
            local t = textype(s)
            if t == "dimen" then
                context("\\the\\dimexpr %s\\%s\\relax",f,s)
            elseif t == "count" then
                context("\\the\\numexpr \\%s * %s\\relax",s,f) -- <n>\scratchcounter is not permitted
            end
        end

    local splitter = lpeg.splitat("::",true)

    interfaces.implement {
        name      = "prepareMPvariable",
        arguments = "string",
        actions   = function(v)
            if v == "" then
             -- MPcolor("black")
                context("black")
            else
                local typ, var = lpegmatch(splitter,v)
                if not var then
                    -- parse
                    if colorhash[v] then
                     -- MPcolor(v)
                        context("%q",var)
                    elseif tonumber(v) then
                        context(v)
                    elseif not lpegmatch(dimenorname,v) then
                        context("\\number %s",v) -- 0.4 ...
                    end
                elseif typ == "d" then -- to be documented
                    -- dimension
                    context("\\the\\dimexpr %s\\relax",var)
                elseif typ == "n" then -- to be documented
                    -- number
                    context("\\the\\numexpr %s\\relax",var)
                elseif typ == "s" then -- to be documented
                    -- string
                 -- context(var)
                    context("%q",var)
                elseif typ == "c" then -- to be documented
                    -- color
                 -- MPcolor(var)
                    context("%q",var)
                else
                    context(var)
                end
            end
        end
    }

end

do

    local ctx_mathematics = context.mathematics

    -- function metapost.formatnumber(f,n) -- just lua format
    --     f = gsub(f,"@(%d)","%%.%1")
    --     f = gsub(f,"@","%%")
    --     f = format(f,tonumber(n) or 0)
    --     f = gsub(f,"e([%+%-%d]+)",function(s)
    --         return format("\\times10^{%s}",tonumber(s) or s) -- strips leading zeros
    --     end)
    --     context.mathematics(f)
    -- end

    -- formatters["\\times10^{%N}"](s) -- strips leading zeros too

    local one = Cs((P("@")/"%%." * (R("09")^1) + P("@")/"%%" + 1)^0)
    local two = Cs((P("e")/"" * ((S("+-")^0 * R("09")^1) / function(s)
     -- return format("\\times10^{%s}",tonumber(s) or s)
        return "\\times10^{" .. (tonumber(s) or s) .."}"
    end) + 1)^1)

    -- local two = Cs((P("e")/"" * ((S("+-")^0 * R("09")^1) / formatters["\\times10^{%N}"]) + 1)^1)

    function metapost.formatnumber(fmt,n) -- just lua format
        ctx_mathematics(lpegmatch(two,format(lpegmatch(one,fmt),n)))
    end

end

do

    -- this is an old pass-data-to-tex mechanism

    local ctx_printtable = context.printtable

    local data = false

    function mp.mf_start_saving_data(n)
        data = { }
    end

    function mp.mf_stop_saving_data()
        if data then
            -- nothing
        end
    end

    function mp.mf_finish_saving_data()
        if data then
            -- nothing
        end
    end

    function mp.mf_save_data(str)
        if data then
            data[#data+1] = str
        end
    end

    interfaces.implement {
        name    = "getMPdata",
        actions = function()
            if data then
                ctx_printtable(data,"\r")
            end
        end
    }

end
