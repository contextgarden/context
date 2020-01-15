if not modules then modules = { } end modules ['grph-rul'] = {
    version   = 1.001,
    comment   = "companion to grph-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, next, type = tonumber, next, type
local concat = table.concat

local attributes       = attributes
local nodes            = nodes
local context          = context

local bpfactor         = number.dimenfactors.bp

local nuts             = nodes.nuts
local nodepool         = nuts.pool
local userrule         = nuts.rules.userrule
local outlinerule      = nuts.pool.outlinerule
local ruleactions      = nuts.rules.ruleactions

local setattrlist      = nuts.setattrlist
local setattr          = nuts.setattr
local tonode           = nuts.tonode

local getattribute     = tex.getattribute
local getwhd           = nuts.getwhd
local setwhd           = nuts.setwhd

local lefttoright_code = nodes.dirvalues.lefttoright

local a_color          = attributes.private('color')
local a_transparency   = attributes.private('transparency')
local a_colormodel     = attributes.private('colormodel')

local mpcolor          = attributes.colors.mpcolor

local trace_mp         = false  trackers.register("rules.mp", function(v) trace_mp = v end)

local report_mp        = logs.reporter("rules","mp")

local floor            = math.floor
local getrandom        = utilities.randomizer.get
local formatters       = string.formatters

-- This is very pdf specific. Maybe move some to lpdf-rul.lua some day.

local pdfprint

pdfprint = function(...) pdfprint = lpdf.print return pdfprint(...) end

updaters.register("backend.update",function()
    pdfprint = lpdf.print
end)

do

    local simplemetapost = metapost.simple
    local cachesize      = 0
    local maxcachesize   = 256*1024
    local cachethreshold = 1024
    local caching        = false -- otherwise random issues so we need a dedicated randomizer first

 -- local maxcachesize   = 8*1024
 -- local cachethreshold = 1024/2

    local cache = table.setmetatableindex(function(t,k)
        local v = simplemetapost("rulefun",k) -- w, h, d
        cachesize = cachesize + #v
        if cachesize > maxcachesize then
         -- print("old",cachesize)
            for k, v in next, t do
                local n = #v
                if n > cachethreshold then
                    t[k] = nil
                    cachesize = cachesize - n
                end
            end
         -- print("new",cachesize)
        end
     -- print(cachesize,maxcachesize,cachethreshold,#v)
        t[k] = v
        return v
    end)

    local replacer = utilities.templates.replacer

    local predefined = {
        ["fake:word"] = replacer [[
FakeWord(%width%,%height%,%depth%,%line%,%color%);
        ]],
        ["fake:rule"] = replacer[[
%initializations%
FakeRule(%width%,%height%,%depth%,%line%,%color%);
        ]],
        ["fake:rest"] = replacer [[
RuleDirection := "%direction%" ;
RuleOption := "%option%" ;
RuleWidth := %width% ;
RuleHeight := %height% ;
RuleDepth := %depth% ;
RuleH := %h% ;
RuleV := %v% ;
RuleThickness := %line% ;
RuleFactor := %factor% ;
RuleOffset := %offset% ;
def RuleColor = %color% enddef ;
%data%;
        ]]
    }

    local initialized = false ;

    ruleactions.mp = function(p,h,v,i,n)
        local name = p.name or "fake:rest"
        local code = (predefined[name] or predefined["fake:rest"]) {
            data      = p.data or "",
            width     = p.width * bpfactor,
            height    = p.height * bpfactor,
            depth     = p.depth * bpfactor,
            factor    = (p.factor or 0) * bpfactor, -- needs checking
            offset    = p.offset or 0,
            line      = (p.line or 65536) * bpfactor,
            color     = mpcolor(p.ma,p.ca,p.ta),
            option    = p.option or "",
            direction = p.direction or lefttoright_code,
            h         = h * bpfactor,
            v         = v * bpfactor,
        }
        if not initialized then
            initialized = true
            simplemetapost("rulefun",formatters["randomseed := %s;"](getrandom("rulefun",0,4095)))
        end
        local pdf = caching and cache[code] or simplemetapost("rulefun",code) -- w, h, d
        if trace_mp then
            report_mp("code: %s",code)
            report_mp("pdf : %s",pdf)
        end
        if pdf and pdf ~= "" then
            pdfprint("direct",pdf)
        end
    end

end

do

    -- This is the old oval method that we keep it for compatibility reasons. Of
    -- course one can use mp instead. It could be improved but at the cost of more
    -- code than I'm willing to add for something hardly used.

    local function round(p,kind)
        local method = tonumber(p.corner) or 0
        if method < 0 or method > 27 then
            method = 0
        end
        local width  = p.width or 0
        local height = p.height or 0
        local depth  = p.depth or 0
        local total  = height + depth
        local radius = p.radius or 655360
        local line   = p.line or 65536
        local how    = (method > 8 or kind ~= "fill") and "S" or "f"
        local half   = line / 2
        local xmin   =            half  * bpfactor
        local xmax   = ( width  - half) * bpfactor
        local ymax   = ( height - half) * bpfactor
        local ymin   = (-depth  + half) * bpfactor
        local full   = ( radius + half)
        local xxmin  =            full  * bpfactor
        local xxmax  = ( width  - full) * bpfactor
        local yymax  = ( height - full) * bpfactor
        local yymin  = (-depth  + full) * bpfactor
              line   =            line  * bpfactor
        if xxmin <= xxmax and yymin <= yymax then
            local list = nil
            if method == 0 then
                list = {
                    "q", line, "w", xxmin, ymin, "m", xxmax, ymin, "l", xmax, ymin, xmax, yymin, "y",
                    xmax, yymax, "l", xmax, ymax, xxmax, ymax, "y", xxmin, ymax, "l", xmin, ymax,
                    xmin, yymax, "y", xmin, yymin, "l", xmin, ymin, xxmin, ymin, "y", "h", how, "Q",
                }
            elseif method == 1 then
                list = {
                    "q", line, "w", xxmin, ymin, "m", xxmax, ymin, "l", xmax, ymin, xmax, yymin, "y",
                    xmax, ymax, "l", xmin, ymax, "l", xmin, yymin, "l", xmin, ymin, xxmin, ymin, "y",
                    "h", how, "Q",
                }
            elseif method == 2 then
                list = {
                    "q", line, "w", xxmin, ymin, "m", xmax, ymin, "l", xmax, ymax, "l", xxmin, ymax,
                    "l", xmin, ymax, xmin, yymax, "y", xmin, yymin, "l", xmin, ymin, xxmin, ymin,
                    "y", "h", how, "Q",
                }
            elseif method == 3 then
                list = {
                    "q", line, "w", xmin, ymin, "m", xmax, ymin, "l", xmax, yymax, "l", xmax, ymax,
                    xxmax, ymax, "y", xxmin, ymax, "l", xmin, ymax, xmin, yymax, "y", xmin, ymin,
                    "l", "h", how, "Q",
                }

            elseif method == 4 then
                list = {
                    "q", line, "w", xmin, ymin, "m", xxmax, ymin, "l", xmax, ymin, xmax, yymin, "y",
                    xmax, yymax, "l", xmax, ymax, xxmax, ymax, "y", xmin, ymax, "l", xmin, ymin, "l",
                    "h", how, "Q",
                }
            elseif method == 5 then
                list = {
                    "q", line, "w", xmin, ymin, "m", xmax, ymin, "l", xmax, yymax, "l", xmax, ymax,
                    xxmax, ymax, "y", xmin, ymax, "l", xmin, ymin, "l", "h", how, "Q",
                }
            elseif method == 6 then
                list = {
                    "q", line, "w", xmin, ymin, "m", xxmax, ymin, "l", xmax, ymin, xmax, yymin, "y",
                    xmax, ymax, "l", xmin, ymax, "l", xmin, ymin, "l", "h", how, "Q",
                }
            elseif method == 7 then
                list = {
                    "q", line, "w", xxmin, ymin, "m", xmax, ymin, "l", xmax, ymax, "l", xmin, ymax,
                    "l", xmin, yymin, "l", xmin, ymin, xxmin, ymin, "y", "h", how, "Q",
                }
            elseif method == 8 then
                list = {
                    "q", line, "w", xmin, ymin, "m", xmax, ymin, "l", xmax, ymax, "l", xxmin, ymax,
                    "l", xmin, ymax, xmin, yymax, "y", xmin, ymin, "l", "h", how, "Q",
                }
            elseif method == 9 then
                list = {
                    "q", line, "w", xmin, ymax, "m", xmin, yymin, "l", xmin, ymin, xxmin, ymin, "y",
                    xxmax, ymin, "l", xmax, ymin, xmax, yymin, "y", xmax, ymax, "l", how, "Q",
                }
            elseif method == 10 then
                list = {
                    "q", line, "w", xmax, ymax, "m", xxmin, ymax, "l", xmin, ymax, xmin, yymax, "y",
                    xmin, yymin, "l", xmin, ymin, xxmin, ymin, "y", xmax, ymin, "l", how, "Q",
                }
            elseif method == 11 then
                list = {
                    "q", line, "w", xmax, ymin, "m", xmax, yymax, "l", xmax, ymax, xxmax, ymax, "y",
                    xxmin, ymax, "l", xmin, ymax, xmin, yymax, "y", xmin, ymin, "l", how, "Q",
                }
            elseif method == 12 then
                list = {
                    "q", line, "w", xmin, ymax, "m", xxmax, ymax, "l", xmax, ymax, xmax, yymax, "y",
                    xmax, yymin, "l", xmax, ymin, xxmax, ymin, "y", xmin, ymin, "l", how, "Q",
                }
            elseif method == 13 then
                list = {
                    "q", line, "w", xmin, ymax, "m", xxmax, ymax, "l", xmax, ymax, xmax, yymax, "y",
                    xmax, ymin, "l", how, "Q",
                }
            elseif method == 14 then
                list = {
                    "q", line, "w", xmax, ymax, "m", xmax, yymin, "l", xmax, ymin, xxmax, ymin, "y",
                    xmin, ymin, "l", how, "Q",
                }
            elseif method == 15 then
                list = {
                    "q", line, "w", xmax, ymin, "m", xxmin, ymin, "l", xmin, ymin, xmin, yymin, "y",
                    xmin, ymax, "l", how, "Q",
                }
            elseif method == 16 then
                list = {
                    "q", line, "w", xmin, ymin, "m", xmin, yymax, "l", xmin, ymax, xxmin, ymax, "y",
                    xmax, ymax, "l", how, "Q",
                }
            elseif method == 17 then
                list = {
                    "q", line, "w", xxmax, ymax, "m", xmax, ymax, xmax, yymax, "y", how, "Q",
                }
            elseif method == 18 then
                list = {
                    "q", line, "w", xmax, yymin, "m", xmax, ymin, xxmax, ymin, "y", how, "Q",
                }
            elseif method == 19 then
                list = {
                    "q", line, "w", xxmin, ymin, "m", xmin, ymin, xmin, yymin, "y", how, "Q",
                }
            elseif method == 20 then
                list = {
                    "q", line, "w", xmin, yymax, "m", xmin, ymax, xxmin, ymax, "y", how, "Q",
                }
            elseif method == 21 then
                list = {
                    "q", line, "w", xxmax, ymax, "m", xmax, ymax, xmax, yymax, "y", xmin, yymax, "m",
                    xmin, ymax, xxmin, ymax, "y", how, "Q",
                }
            elseif method == 22 then
                list = {
                    "q", line, "w", xxmax, ymax, "m", xmax, ymax, xmax, yymax, "y", xmax, yymin, "m",
                    xmax, ymin, xxmax, ymin, "y", how, "Q",
                }
            elseif method == 23 then
                list = {
                    "q", line, "w", xmax, yymin, "m", xmax, ymin, xxmax, ymin, "y", xxmin, ymin, "m",
                    xmin, ymin, xmin, yymin, "y", how, "Q",
                }
            elseif method == 24 then
                list = {
                    "q", line, "w", xxmin, ymin, "m", xmin, ymin, xmin, yymin, "y", xmin, yymax, "m",
                    xmin, ymax, xxmin, ymax, "y", how, "Q",
                }
            elseif method == 25 then
                list = {
                    "q", line, "w", xxmax, ymax, "m", xmax, ymax, xmax, yymax, "y", xmax, yymin, "m",
                    xmax, ymin, xxmax, ymin, "y", xxmin, ymin, "m", xmin, ymin, xmin, yymin, "y",
                    xmin, yymax, "m", xmin, ymax, xxmin, ymax, "y", how, "Q",
                }
            elseif method == 26 then
                list = {
                    "q", line, "w", xmax, yymin, "m", xmax, ymin, xxmax, ymin, "y", xmin, yymax, "m",
                    xmin, ymax, xxmin, ymax, "y", how, "Q",
                }

            elseif method == 27 then
                list = {
                    "q", line, "w", xxmax, ymax, "m", xmax, ymax, xmax, yymax, "y", xxmin, ymin, "m",
                    xmin, ymin, xmin, yymin, "y", how, "Q",
                }
            end
            pdfprint("direct",concat(list," "))
        end
    end

    local f_rectangle = formatters["%.6N w %.6N %.6N %.6N %.6N re %s"]
    local f_baselined = formatters["%.6N w %.6N %.6N %.6N %.6N re s %.6N %.6N m %.6N %.6N l s"]
    local f_dashlined = formatters["%.6N w %.6N %.6N %.6N %.6N re s [%.6N %.6N] 2 d %.6N %.6N m %.6N %.6N l s"]
    local f_radtangle = formatters[
[[%.6N w %.6N %.6N m
%.6N %.6N l %.6N %.6N %.6N %.6N y
%.6N %.6N l %.6N %.6N %.6N %.6N y
%.6N %.6N l %.6N %.6N %.6N %.6N y
%.6N %.6N l %.6N %.6N %.6N %.6N y
h %s]]
        ]

    ruleactions.fill = function(p,h,v,i,n)
        if p.corner then
            return round(p,i)
        else
            local l = (p.line or 65536)*bpfactor
            local r = p and (p.radius or 0)*bpfactor or 0
            local w = h * bpfactor
            local h = v * bpfactor
            local m = nil
            local t = i == "fill" and "f" or "s"
            local o = l / 2
            if r > 0 then
                w = w - o
                h = h - o
                m = f_radtangle(l, r,o, w-r,o, w,o,w,r, w,h-r, w,h,w-r,h, r,h, o,h,o,h-r, o,r, o,o,r,o, t)
            else
                w = w - l
                h = h - l
                m = f_rectangle(l,o,o,w,h,t)
            end
            pdfprint("direct",m)
        end
    end

    ruleactions.draw   = ruleactions.fill
    ruleactions.stroke = ruleactions.fill

    ruleactions.box = function(p,h,v,i,n)
        local w, h, d = getwhd(n)
        local line = p.line or 65536
        local l = line *bpfactor
        local w = w * bpfactor
        local h = h * bpfactor
        local d = d * bpfactor
        local o = l / 2
        if (d >= 0 and h >= 0) or (d <= 0 and h <= 0) then
            local dashed = tonumber(p.dashed)
            if dashed and dashed > 5*line then
                dashed = dashed * bpfactor
                local delta = (w - 2*dashed*floor(w/(2*dashed)))/2
                pdfprint("direct",f_dashlined(l,o,o,w-l,h+d-l,dashed,dashed,delta,d,w-delta,d))
            else
                pdfprint("direct",f_baselined(l,o,o,w-l,h+d-l,0,d,w,d))
            end
        else
            pdfprint("direct",f_rectangle(l,o,o,w-l,h+d-l))
        end
    end

end

interfaces.implement {
    name      = "frule",
    arguments = { {
        { "width",  "dimension" },
        { "height", "dimension" },
        { "depth",  "dimension" },
        { "radius", "dimension" },
        { "line",   "dimension" },
        { "type",   "string" },
        { "data",   "string" },
        { "name",   "string" },
        { "radius", "dimension" },
        { "corner", "string" },
    } } ,
    actions = function(t)
        local rule = userrule(t)
        if t.type == "mp" then
            t.ma = getattribute(a_colormodel) or 1
            t.ca = getattribute(a_color)
            t.ta = getattribute(a_transparency)
        else
            setattrlist(rule,true)
        end
        context(tonode(rule)) -- will become context.nodes.flush
    end
}

interfaces.implement {
    name      = "outlinerule",
    public    = true,
    protected = true,
    arguments = { {
        { "width",  "dimension" },
        { "height", "dimension" },
        { "depth",  "dimension" },
        { "line",   "dimension" },
    } } ,
    actions = function(t)
        local rule = outlinerule(t.width,t.height,t.depth,t.line)
        setattrlist(rule,true)
        context(tonode(rule)) -- will become context.nodes.flush
    end
}

interfaces.implement {
    name      = "framedoutline",
    arguments = { "dimension", "dimension", "dimension", "dimension" },
    actions   = function(w,h,d,l)
        local rule = outlinerule(w,h,d,l)
        setattrlist(rule,true)
        context(tonode(rule)) -- will become context.nodes.flush
    end
}

interfaces.implement {
    name      = "fakeword",
    arguments = { {
        { "factor", "dimension" },
        { "name",   "string" }, -- can be type
        { "min",    "dimension" },
        { "max",    "dimension" },
        { "n",      "integer" },
    } } ,
    actions = function(t)
        local factor = t.factor or 0
        local amount = getrandom("fakeword",t.min,t.max)
        local rule   = userrule {
            height = 1.25*factor,
            depth  = 0.25*factor,
            width  = floor(amount/10000) * 10000,
            line   = 0.10*factor,
            ma     = getattribute(a_colormodel) or 1,
            ca     = getattribute(a_color),
            ta     = getattribute(a_transparency),
            type   = "mp",
            name   = t.name,
        }
        setattrlist(rule,true)
        context(tonode(rule))
    end
}
