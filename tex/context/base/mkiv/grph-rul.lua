if not modules then modules = { } end modules ['grph-rul'] = {
    version   = 1.001,
    comment   = "companion to grph-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, next, type = tonumber, next, type

local attributes     = attributes
local nodes          = nodes
local context        = context

local ruleactions    = nodes.rules.ruleactions
local userrule       = nodes.rules.userrule
local bpfactor       = number.dimenfactors.bp
local pdfprint       = pdf.print

local current_attr   = nodes.current_attr
local setfield       = nodes.setfield

local getattribute   = tex.getattribute

local a_color        = attributes.private('color')
local a_transparency = attributes.private('transparency')
local a_colormodel   = attributes.private('colormodel')

local mpcolor        = attributes.colors.mpcolor

local trace_mp       = false  trackers.register("rules.mp", function(v) trace_mp = v end)

local report_mp      = logs.reporter("rules","mp")

local floor          = math.floor
local getrandom      = utilities.randomizer.get
local formatters     = string.formatters

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
            data            = p.data or "",
            width           = p.width * bpfactor,
            height          = p.height * bpfactor,
            depth           = p.depth * bpfactor,
            factor          = (p.factor or 0) * bpfactor, -- needs checking
            offset          = p.offset or 0,
            line            = (p.line or 65536) * bpfactor,
            color           = mpcolor(p.ma,p.ca,p.ta),
            option          = p.option or "",
            direction       = p.direction or "TLT",
            h               = h * bpfactor,
            v               = v * bpfactor,
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

    -- maybe %.6F

    local f_rectangle = formatters["%.6F w %.6F %.6F %.6F %.6F re %s"]
    local f_baselined = formatters["%.6F w %.6F %.6F %.6F %.6F re s %.6F %.6F m %.6F %.6F l s"]
    local f_dashlined = formatters["%.6F w %.6F %.6F %.6F %.6F re s [%.6F %.6F] 2 d %.6F %.6F m %.6F %.6F l s"]
    local f_radtangle = formatters[ [[
        %.6F w %.6F %.6F m
        %.6F %.6F l %.6F %.6F %.6F %.6F y
        %.6F %.6F l %.6F %.6F %.6F %.6F y
        %.6F %.6F l %.6F %.6F %.6F %.6F y
        %.6F %.6F l %.6F %.6F %.6F %.6F y
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

    local getwhd = nodes.nuts.getwhd

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
    } } ,
    actions = function(t)
        -- no nuts !
        local rule = userrule(t)
        local ma = getattribute(a_colormodel) or 1
        local ca = getattribute(a_color)
        local ta = getattribute(a_transparency)
        setfield(rule,"attr",current_attr())
        if t.type == "mp" then
            t.ma = ma
            t.ca = ca
            t.ta = ta
        else
            rule[a_colormodel]   = ma
            rule[a_color]        = ca
            rule[a_transparency] = ta
        end
        context(rule)
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
        setfield(rule,"attr",current_attr())
        context(rule)
    end
}


