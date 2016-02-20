if not modules then modules = { } end modules ['grph-rul'] = {
    version   = 1.001,
    comment   = "companion to grph-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local attributes     = attributes
local nodes          = nodes
local context        = context

local ruleactions    = nodes.rules.ruleactions
local userrule       = nodes.rules.userrule
local bpfactor       = number.dimenfactors.bp
local pdfprint       = pdf.print

local getattribute   = tex.getattribute

local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colorspace   = attributes.private('colormodel')

local mpcolor        = attributes.colors.mpcolor

local floor          = math.floor
local random         = math.random

do

    local simplemetapost = metapost.simple
    local cachesize      = 0
    local maxcachesize   = 256*1024
    local cachethreshold = 1024

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

    local makecode = utilities.templates.replacer [[
        beginfig(1);
            RuleWidth := %width% ;
            RuleHeight := %height% ;
            RuleDepth := %depth% ;
            RuleThickness := %line% ;
            RuleFactor := %factor% ;
            RuleOffset := %offset% ;
            def RuleColor = %color% enddef ;
            %data%;
        endfig ;
    ]]

    local predefined = {
        ["fake:word"] = [[
fill unitsquare xscaled RuleWidth yscaled RuleHeight withcolor RuleColor ;
draw (0,RuleDepth+RuleThickness/2) -- (RuleWidth,RuleDepth+RuleThickness/2) withpen pencircle scaled RuleThickness withcolor white ;
        ]],
        ["fake:rule"] = [[
fill unitsquare xscaled RuleWidth yscaled RuleHeight withcolor RuleColor ;
        ]],
    }

    ruleactions.mp = function(p,h,v,i,n)
        local name = p.name
        local code = makecode {
            data   = name and predefined[name] or p.data or "",
            width  = p.width * bpfactor,
            height = p.height * bpfactor,
            depth  = p.depth * bpfactor,
            factor = (p.factor or 0) * bpfactor, -- needs checking
            offset = p.offset or 0,
            line   = (p.line or 65536) * bpfactor,
            color  = mpcolor(p.ma,p.ca,p.ta),
        }
        local m = cache[code]
        if m and m ~= "" then
            pdfprint("direct",m)
        end
    end

end

do

    local f_rectangle = string.formatters["%F w %F %F %F %F re %s"]
    local f_radtangle = string.formatters[ [[
        %F w %F %F m
        %F %F l %F %F %F %F y
        %F %F l %F %F %F %F y
        %F %F l %F %F %F %F y
        %F %F l %F %F %F %F y
        h %s
    ]] ]

    ruleactions.fill = function(p,h,v,i,n)
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

    ruleactions.draw   = ruleactions.fill
    ruleactions.stroke = ruleactions.fill

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
    } } ,
    actions = function(t)
        if t.type == "mp" then
            t.ma = getattribute(a_colorspace) or 1
            t.ca = getattribute(a_color)
            t.ta = getattribute(a_transparency)
        end
        local r = userrule(t)
        context(r)
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
        local rule   = userrule {
            height = 1.25*factor,
            depth  = 0.25*factor,
            width  = floor(random(t.min,t.max)/10000) * 10000,
            line   = 0.10*factor,
            ma     = getattribute(a_colorspace) or 1,
            ca     = getattribute(a_color),
            ta     = getattribute(a_transparency),
            type   = "mp",
            name   = t.name,
        }
        context(rule)
    end
}


