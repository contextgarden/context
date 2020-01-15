if not modules then modules = { } end modules ['lpdf-col'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- slants also page ?

local type, next, tostring, tonumber = type, next, tostring, tonumber
local char, byte, format, gsub, rep, gmatch = string.char, string.byte, string.format, string.gsub, string.rep, string.gmatch
local settings_to_array, settings_to_numbers = utilities.parsers.settings_to_array, utilities.parsers.settings_to_numbers
local concat = table.concat
local round = math.round
local formatters = string.formatters

local backends, lpdf, nodes = backends, lpdf, nodes

local allocate                = utilities.storage.allocate

local nodeinjections          = backends.pdf.nodeinjections
local codeinjections          = backends.pdf.codeinjections
local registrations           = backends.pdf.registrations

local nodepool                = nodes.nuts.pool
local register                = nodepool.register
local pageliteral             = nodepool.pageliteral

local pdfconstant             = lpdf.constant
local pdfdictionary           = lpdf.dictionary
local pdfarray                = lpdf.array
local pdfreference            = lpdf.reference
local pdfverbose              = lpdf.verbose
local pdfflushobject          = lpdf.flushobject
local pdfdelayedobject        = lpdf.delayedobject
local pdfflushstreamobject    = lpdf.flushstreamobject

local pdfshareobjectreference = lpdf.shareobjectreference

local addtopageattributes     = lpdf.addtopageattributes
local adddocumentcolorspace   = lpdf.adddocumentcolorspace
local adddocumentextgstate    = lpdf.adddocumentextgstate

local colors                  = attributes.colors
local registercolor           = colors.register
local colorsvalue             = colors.value
local forcedmodel             = colors.forcedmodel
local getpagecolormodel       = colors.getpagecolormodel
local colortoattributes       = colors.toattributes

local transparencies          = attributes.transparencies
local registertransparancy    = transparencies.register
local transparenciesvalue     = transparencies.value
local transparencytoattribute = transparencies.toattribute

local unsetvalue              = attributes.unsetvalue

local setmetatableindex       = table.setmetatableindex

local c_transparency          = pdfconstant("Transparency")

local f_gray   = formatters["%.3N g %.3N G"]
local f_rgb    = formatters["%.3N %.3N %.3N rg %.3N %.3N %.3N RG"]
local f_cmyk   = formatters["%.3N %.3N %.3N %.3N k %.3N %.3N %.3N %.3N K"]
local f_spot   = formatters["/%s cs /%s CS %s SCN %s scn"]
local f_tr     = formatters["Tr%s"]
local f_cm     = formatters["q %.6N %.6N %.6N %.6N %.6N %.6N cm"]
local f_effect = formatters["%s Tc %s w %s Tr"] -- %.6N ?
local f_tr_gs  = formatters["/Tr%s gs"]
local f_num_1  = formatters["%.3N %.3N"]
local f_num_2  = formatters["%.3N %.3N"]
local f_num_3  = formatters["%.3N %.3N %.3N"]
local f_num_4  = formatters["%.3N %.3N %.3N %.3N"]

local report_color = logs.reporter("colors","backend")

-- page groups (might move to lpdf-ini.lua)

local colorspaceconstants = allocate { -- v_none is ignored
    gray = pdfconstant("DeviceGray"),
    rgb  = pdfconstant("DeviceRGB"),
    cmyk = pdfconstant("DeviceCMYK"),
    all  = pdfconstant("DeviceRGB"), -- brr
}

local transparencygroups = { }

lpdf.colorspaceconstants = colorspaceconstants
lpdf.transparencygroups  = transparencygroups

setmetatableindex(transparencygroups, function(transparencygroups,colormodel)
    local cs = colorspaceconstants[colormodel]
    if cs then
        local d = pdfdictionary {
            S  = c_transparency,
            CS = cs,
            I  = true,
        }
     -- local g = pdfreference(pdfflushobject(tostring(d)))
        local g = pdfreference(pdfdelayedobject(tostring(d)))
        transparencygroups[colormodel] = g
        return g
    else
        transparencygroups[colormodel] = false
        return false
    end
end)

local function addpagegroup()
    local model = getpagecolormodel()
    if model then
        local g = transparencygroups[model]
        if g then
            addtopageattributes("Group",g)
        end
    end
end

lpdf.registerpagefinalizer(addpagegroup,3,"pagegroup")

-- injection code (needs a bit reordering)

-- color injection

function nodeinjections.rgbcolor(r,g,b)
    return register(pageliteral(f_rgb(r,g,b,r,g,b)))
end

function nodeinjections.cmykcolor(c,m,y,k)
    return register(pageliteral(f_cmyk(c,m,y,k,c,m,y,k)))
end

function nodeinjections.graycolor(s) -- caching 0/1 does not pay off
    return register(pageliteral(f_gray(s,s)))
end

function nodeinjections.spotcolor(n,f,d,p)
    if type(p) == "string" then
        p = gsub(p,","," ") -- brr misuse of spot
    end
    return register(pageliteral(f_spot(n,n,p,p)))
end

function nodeinjections.transparency(n)
    return register(pageliteral(f_tr_gs(n)))
end

-- a bit weird but let's keep it here for a while

local effects = {
    normal = 0,
    inner  = 0,
    outer  = 1,
    both   = 2,
    hidden = 3,
}

local bp = number.dimenfactors.bp

function nodeinjections.effect(effect,stretch,rulethickness)
    -- always, no zero test (removed)
    rulethickness = bp * rulethickness
    effect = effects[effect] or effects['normal']
    return register(pageliteral(f_effect(stretch,rulethickness,effect))) -- watch order
end

-- spot- and indexcolors

local pdf_separation  = pdfconstant("Separation")
local pdf_indexed     = pdfconstant("Indexed")
local pdf_device_n    = pdfconstant("DeviceN")
local pdf_device_rgb  = pdfconstant("DeviceRGB")
local pdf_device_cmyk = pdfconstant("DeviceCMYK")
local pdf_device_gray = pdfconstant("DeviceGray")
local pdf_extgstate   = pdfconstant("ExtGState")

local pdf_rgb_range   = pdfarray { 0, 1, 0, 1, 0, 1 }
local pdf_cmyk_range  = pdfarray { 0, 1, 0, 1, 0, 1, 0, 1 }
local pdf_gray_range  = pdfarray { 0, 1 }

local f_rgb_function  = formatters["dup %s mul exch dup %s mul exch %s mul"]
local f_cmyk_function = formatters["dup %s mul exch dup %s mul exch dup %s mul exch %s mul"]
local f_gray_function = formatters["%s mul"]

local documentcolorspaces = pdfdictionary()

local spotcolorhash       = { } -- not needed
local spotcolornames      = { }
local indexcolorhash      = { }
local delayedindexcolors  = { }

function registrations.spotcolorname(name,e)
    spotcolornames[name] = e or name
end

function registrations.getspotcolorreference(name)
    return spotcolorhash[name]
end

-- beware: xpdf/okular/evince cannot handle the spot->process shade

-- This should become delayed i.e. only flush when used; in that case we need
-- need to store the specification and then flush them when accesssomespotcolor
-- is called. At this moment we assume that splotcolors that get defined are
-- also used which keeps the overhad small anyway. Tricky for mp ...

local processcolors

local function registersomespotcolor(name,noffractions,names,p,colorspace,range,funct)
    noffractions = tonumber(noffractions) or 1 -- to be checked
    if noffractions == 0 then
        -- can't happen
    elseif noffractions == 1 then
        local dictionary = pdfdictionary {
            FunctionType = 4,
            Domain       = { 0, 1 },
            Range        = range,
        }
        local calculations = pdfflushstreamobject(format("{ %s }",funct),dictionary)
     -- local calculations = pdfobject {
     --     type      = "stream",
     --     immediate = true,
     --     string    = format("{ %s }",funct),
     --     attr      = dictionary(),
     -- }
        local array = pdfarray {
            pdf_separation,
            pdfconstant(spotcolornames[name] or name),
            colorspace,
            pdfreference(calculations),
        }
        local m = pdfflushobject(array)
        local mr = pdfreference(m)
        spotcolorhash[name] = m
        documentcolorspaces[name] = mr
        adddocumentcolorspace(name,mr)
    else
        local cnames = pdfarray()
        local domain = pdfarray()
        local colorants = pdfdictionary()
        for n in gmatch(names,"[^,]+") do
            local name = spotcolornames[n] or n
            -- the cmyk names assume that they are indeed these colors
            if n == "cyan" then
                name = "Cyan"
            elseif n == "magenta" then
                name = "Magenta"
            elseif n == "yellow" then
                name = "Yellow"
            elseif n == "black" then
                name = "Black"
            else
                local sn = spotcolorhash[name] or spotcolorhash[n]
                if not sn then
                    report_color("defining %a as colorant",name)
                    colors.definespotcolor("",name,"p=1",true)
                    sn = spotcolorhash[name] or spotcolorhash[n]
                end
                if sn then
                    colorants[name] = pdfreference(sn)
                else
                    -- maybe some day generate colorants (spot colors for multi) automatically
                    report_color("unknown colorant %a, using black instead",name or n)
                    name = "Black"
                end
            end
            cnames[#cnames+1] = pdfconstant(name)
            domain[#domain+1] = 0
            domain[#domain+1] = 1
        end
        if not processcolors then
            local specification = pdfdictionary {
                ColorSpace = pdfconstant("DeviceCMYK"),
                Components = pdfarray {
                    pdfconstant("Cyan"),
                    pdfconstant("Magenta"),
                    pdfconstant("Yellow"),
                    pdfconstant("Black")
                }
            }
            processcolors = pdfreference(pdfflushobject(specification))
        end
        local dictionary = pdfdictionary {
            FunctionType = 4,
            Domain       = domain,
            Range        = range,
        }
        local calculation = pdfflushstreamobject(format("{ %s %s }",rep("pop ",noffractions),funct),dictionary)
        local channels = pdfdictionary {
            Subtype   = pdfconstant("NChannel"),
            Colorants = colorants,
            Process   = processcolors,
        }
        local array = pdfarray {
            pdf_device_n,
            cnames,
            colorspace,
            pdfreference(calculation),
            pdfshareobjectreference(tostring(channels)), -- optional but needed for shades
        }
        local m = pdfflushobject(array)
        local mr = pdfreference(m)
        spotcolorhash[name] = m
        documentcolorspaces[name] = mr
        adddocumentcolorspace(name,mr)
    end
end

-- wrong name

local function registersomeindexcolor(name,noffractions,names,p,colorspace,range,funct)
    noffractions = tonumber(noffractions) or 1 -- to be checked
    local cnames = pdfarray()
    local domain = pdfarray()
    local names  = settings_to_array(#names == 0 and name or names)
    local values = settings_to_numbers(p)
    names [#names +1] = "None"
    values[#values+1] = 1
    -- check for #names == #values
    for i=1,#names do
        local name = names[i]
        local spot = spotcolornames[name]
        cnames[#cnames+1] = pdfconstant(spot ~= "" and spot or name)
        domain[#domain+1] = 0
        domain[#domain+1] = 1
    end
    local dictionary = pdfdictionary {
        FunctionType = 4,
        Domain       = domain,
        Range        = range,
    }
    local n = pdfflushstreamobject(format("{ %s %s }",rep("exch pop ",noffractions),funct),dictionary) -- exch pop
    local a = pdfarray {
        pdf_device_n,
        cnames,
        colorspace,
        pdfreference(n),
    }
    local vector = { }
    local set    = { }
    local n      = #values
    for i=255,0,-1 do
        for j=1,n do
            set[j] = format("%02X",round(values[j]*i))
        end
        vector[#vector+1] = concat(set)
    end
    vector = pdfverbose { "<", concat(vector, " "), ">" }
    local n = pdfflushobject(pdfarray{ pdf_indexed, a, 255, vector })
    adddocumentcolorspace(format("%s_indexed",name),pdfreference(n))
    return n
end

-- actually, names (parent) is the hash

local function delayindexcolor(name,names,func)
    local hash = (names ~= "" and names) or name
    delayedindexcolors[hash] = func
end

local function indexcolorref(name) -- actually, names (parent) is the hash
    local parent = colors.spotcolorparent(name)
    local data   = indexcolorhash[name]
    if data == nil then
        local delayedindexcolor = delayedindexcolors[parent]
        if type(delayedindexcolor) == "function" then
            data = delayedindexcolor()
            delayedindexcolors[parent] = true
        end
        indexcolorhash[parent] = data or false
    end
    return data
end

function registrations.rgbspotcolor(name,noffractions,names,p,r,g,b)
    if noffractions == 1 then
        registersomespotcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rgb_range,f_rgb_function(r,g,b))
    else
        registersomespotcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rgb_range,f_num_3(r,g,b))
    end
    delayindexcolor(name,names,function()
        return registersomeindexcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rgb_range,f_rgb_function(r,g,b))
    end)
end

function registrations.cmykspotcolor(name,noffractions,names,p,c,m,y,k)
    if noffractions == 1 then
        registersomespotcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,f_cmyk_function(c,m,y,k))
    else
        registersomespotcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,f_num_4(c,m,y,k))
    end
    delayindexcolor(name,names,function()
        return registersomeindexcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,f_cmyk_function(c,m,y,k))
    end)
end

function registrations.grayspotcolor(name,noffractions,names,p,s)
    if noffractions == 1 then
        registersomespotcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,f_gray_function(s))
    else
        registersomespotcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,f_num_1(s))
    end
    delayindexcolor(name,names,function()
        return registersomeindexcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,f_gray_function(s))
    end)
end

function registrations.rgbindexcolor(name,noffractions,names,p,r,g,b)
    registersomeindexcolor(name,noffractions,names,p,pdf_device_rgb,pdf_rgb_range,f_rgb_function(r,g,b))
end

function registrations.cmykindexcolor(name,noffractions,names,p,c,m,y,k)
    registersomeindexcolor(name,noffractions,names,p,pdf_device_cmyk,pdf_cmyk_range,f_cmyk_function(c,m,y,k))
end

function registrations.grayindexcolor(name,noffractions,names,p,s)
    registersomeindexcolor(name,noffractions,names,p,pdf_device_gray,pdf_gray_range,f_gray_function(s))
end

function codeinjections.setfigurecolorspace(data,figure)
    local color = data.request.color
    if color then -- != v_default
        local ref = indexcolorref(color)
        if ref then
            figure.colorspace = ref
            data.used.color    = color
            data.used.colorref = ref
        end
    end
end

-- transparency

local pdftransparencies = { [0] =
    pdfconstant("Normal"),
    pdfconstant("Normal"),
    pdfconstant("Multiply"),
    pdfconstant("Screen"),
    pdfconstant("Overlay"),
    pdfconstant("SoftLight"),
    pdfconstant("HardLight"),
    pdfconstant("ColorDodge"),
    pdfconstant("ColorBurn"),
    pdfconstant("Darken"),
    pdfconstant("Lighten"),
    pdfconstant("Difference"),
    pdfconstant("Exclusion"),
    pdfconstant("Hue"),
    pdfconstant("Saturation"),
    pdfconstant("Color"),
    pdfconstant("Luminosity"),
    pdfconstant("Compatible"), -- obsolete; 'Normal' is used in this case
}

local documenttransparencies = { }
local transparencyhash       = { } -- share objects

local done, signaled = false, false

function registrations.transparency(n,a,t)
    if not done then
        local d = pdfdictionary {
              Type = pdf_extgstate,
              ca   = 1,
              CA   = 1,
              BM   = pdftransparencies[1],
              AIS  = false,
            }
        local m = pdfflushobject(d)
        local mr = pdfreference(m)
        transparencyhash[0] = m
        documenttransparencies[0] = mr
        adddocumentextgstate("Tr0",mr)
        done = true
    end
    if n > 0 and not transparencyhash[n] then
        local d = pdfdictionary {
              Type = pdf_extgstate,
              ca   = tonumber(t),
              CA   = tonumber(t),
              BM   = pdftransparencies[tonumber(a)] or pdftransparencies[0],
              AIS  = false,
            }
        local m = pdfflushobject(d)
        local mr = pdfreference(m)
        transparencyhash[n] = m
        documenttransparencies[n] = mr
        adddocumentextgstate(f_tr(n),mr)
    end
end

statistics.register("page group warning", function()
    if done then
        local model = getpagecolormodel()
        if model and not transparencygroups[model] then
            return "transparencies are used but no pagecolormodel is set"
        end
    end
end)

-- Literals needed to inject code in the mp stream, we cannot use attributes there
-- since literals may have qQ's, much may go away once we have mplib code in place.
--
-- This module assumes that some functions are defined in the colors namespace
-- which most likely will be loaded later.

local function lpdfcolor(model,ca,default) -- todo: use gray when no color
    if colors.supported then
        local cv = colorsvalue(ca)
        if cv then
            if model == 1 then
                model = cv[1]
            end
            model = forcedmodel(model)
            if model == 2 then
                local s = cv[2]
                return f_gray(s,s)
            elseif model == 3 then
                local r = cv[3]
                local g = cv[4]
                local b = cv[5]
                return f_rgb(r,g,b,r,g,b)
            elseif model == 4 then
                local c = cv[6]
                local m = cv[7]
                local y = cv[8]
                local k = cv[9]
                return f_cmyk(c,m,y,k,c,m,y,k)
            else
                local n = cv[10]
                local f = cv[11]
                local d = cv[12]
                local p = cv[13]
                if type(p) == "string" then
                    p = gsub(p,","," ") -- brr misuse of spot
                end
                return f_spot(n,n,p,p)
            end
        else
            return f_gray(default or 0,default or 0)
        end
    else
        return ""
    end
end

lpdf.color = lpdfcolor

interfaces.implement {
    name      = "lpdf_color",
    actions   = { lpdfcolor, context },
    arguments = "integer"
}

function lpdf.colorspec(model,ca,default)
    if ca and ca > 0 then
        local cv = colors.value(ca)
        if cv then
            if model == 1 then
                model = cv[1]
            end
            if model == 2 then
                return pdfarray { cv[2] }
            elseif model == 3 then
                return pdfarray { cv[3],cv[4],cv[5] }
            elseif model == 4 then
                return pdfarray { cv[6],cv[7],cv[8],cv[9] }
            elseif model == 5 then
                return pdfarray { cv[13] }
            end
        end
    end
    if default then
        return default
    end
end

function lpdf.pdfcolor(attribute) -- bonus, for pgf and friends
    return lpdfcolor(1,attribute)
end

function lpdf.transparency(ct,default) -- kind of overlaps with transparencycode
    -- beware, we need this hack because normally transparencies are not
    -- yet registered and therefore the number is not not known ... we
    -- might use the attribute number itself in the future
    if transparencies.supported then
        local ct = transparenciesvalue(ct)
        if ct then
            return f_tr_gs(registertransparancy(nil,ct[1],ct[2],true))
        else
            return f_tr_gs(0)
        end
    else
        return ""
    end
end

function lpdf.colorvalue(model,ca,default)
    local cv = colorsvalue(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
        if model == 2 then
            return f_num_1(cv[2])
        elseif model == 3 then
            return f_num_3(cv[3],cv[4],cv[5])
        elseif model == 4 then
            return f_num_4(cv[6],cv[7],cv[8],cv[9])
        else
            return f_num_1(cv[13])
        end
    else
        return f_num_1(default or 0)
    end
end

function lpdf.colorvalues(model,ca,default)
    local cv = colorsvalue(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
        if model == 2 then
            return cv[2]
        elseif model == 3 then
            return cv[3], cv[4], cv[5]
        elseif model == 4 then
            return cv[6], cv[7], cv[8], cv[9]
        elseif model == 5 then
            return cv[13]
        end
    else
        return default or 0
    end
end

function lpdf.transparencyvalue(ta,default)
    local tv = transparenciesvalue(ta)
    if tv then
        return tv[2]
    else
        return default or 1
    end
end

function lpdf.colorspace(model,ca)
    local cv = colorsvalue(ca)
    if cv then
        if model == 1 then
            model = cv[1]
        end
        model = forcedmodel(model)
        if model == 2 then
            return "DeviceGray"
        elseif model == 3 then
            return "DeviceRGB"
        elseif model == 4 then
            return "DeviceCMYK"
        end
    end
    return "DeviceGRAY"
end

-- by registering we getconversion for free (ok, at the cost of overhead)

local intransparency = false
local pdfcolor       = lpdf.color

function lpdf.rgbcode(model,r,g,b)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'rgb',r,g,b))
    else
        return ""
    end
end

function lpdf.cmykcode(model,c,m,y,k)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'cmyk',c,m,y,k))
    else
        return ""
    end
end

function lpdf.graycode(model,s)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'gray',s))
    else
        return ""
    end
end

function lpdf.spotcode(model,n,f,d,p)
    if colors.supported then
        return pdfcolor(model,registercolor(nil,'spot',n,f,d,p)) -- incorrect
    else
        return ""
    end
end

function lpdf.transparencycode(a,t)
    if transparencies.supported then
        intransparency = true
        return f_tr_gs(registertransparancy(nil,a,t,true)) -- true forces resource
    else
        return ""
    end
end

function lpdf.finishtransparencycode()
    if transparencies.supported and intransparency then
        intransparency = false
        return f_tr_gs(0) -- we happen to know this -)
    else
        return ""
    end
end

-- this will move to lpdf-spe.lua an dwe then can also add a metatable with
-- normal context colors

do

    local pdfcolor        = lpdf.color
    local pdftransparency = lpdf.transparency

    local f_slant = formatters["q 1 0 %N 1 0 0 cm"]

 -- local fillcolors = {
 --     red        = { "pdf", "page", "1 0 0 rg" },
 --     green      = { "pdf", "page", "0 1 0 rg" },
 --     blue       = { "pdf", "page", "0 0 1 rg" },
 --     gray       = { "pdf", "page", ".5 g" },
 --     black      = { "pdf", "page", "0 g" },
 --     palered    = { "pdf", "page", "1 .75 .75 rg" },
 --     palegreen  = { "pdf", "page", ".75 1 .75 rg" },
 --     paleblue   = { "pdf", "page", ".75 .75 1 rg" },
 --     palegray   = { "pdf", "page", ".75 g" },
 -- }
 --
 -- local strokecolors = {
 --     red        = { "pdf", "page", "1 0 0 RG" },
 --     green      = { "pdf", "page", "0 1 0 RG" },
 --     blue       = { "pdf", "page", "0 0 1 RG" },
 --     gray       = { "pdf", "page", ".5 G" },
 --     black      = { "pdf", "page", "0 G" },
 --     palered    = { "pdf", "page", "1 .75 .75 RG" },
 --     palegreen  = { "pdf", "page", ".75 1 .75 RG" },
 --     paleblue   = { "pdf", "page", ".75 .75 1 RG" },
 --     palegray   = { "pdf", "page", ".75 G" },
 -- }
 --
 -- backends.pdf.tables.vfspecials = allocate { -- todo: distinguish between glyph and rule color
 --
 --     red          = { "pdf", "page", "1 0 0 rg 1 0 0 RG" },
 --     green        = { "pdf", "page", "0 1 0 rg 0 1 0 RG" },
 --     blue         = { "pdf", "page", "0 0 1 rg 0 0 1 RG" },
 --     gray         = { "pdf", "page", ".75 g .75 G" },
 --     black        = { "pdf", "page", "0 g 0 G" },
 --
 --  -- rulecolors   = fillcolors,
 --  -- fillcolors   = fillcolors,
 --  -- strokecolors = strokecolors,
 --
 --     startslant   = function(a) return { "pdf", "origin", f_slant(a) } end,
 --     stopslant    = { "pdf", "origin", "Q" },
 --
 -- }

    local slants = setmetatableindex(function(t,k)
        local v = { "pdf", "origin", f_slant(a) }
        t[k] = v
        return k
    end)

    local function startslant(a)
        return slants[a]
    end

    local c_cache = setmetatableindex(function(t,m)
        local v = setmetatableindex(function(t,c)
            local p = { "pdf", "page", "q " .. pdfcolor(m,c) }
            t[c] = p
            return p
        end)
        t[m] = v
        return v
    end)

    -- we inherit the outer transparency

    local t_cache = setmetatableindex(function(t,transparency)
        local p = pdftransparency(transparency)
        local v = setmetatableindex(function(t,colormodel)
            local v = setmetatableindex(function(t,color)
                local v = { "pdf", "page", "q " .. pdfcolor(colormodel,color) .. " " .. p }
                t[color] = v
                return v
            end)
            t[colormodel] = v
            return v
        end)
        t[transparency] = v
        return v
    end)

    local function startcolor(k)
        local m, c = colortoattributes(k)
        local t = transparencytoattribute(k)
        if t then
            return t_cache[t][m][c]
        else
            return c_cache[m][c]
        end
    end

    backends.pdf.tables.vfspecials = allocate { -- todo: distinguish between glyph and rule color

        startcolor = startcolor,
     -- stopcolor  = { "pdf", "page", "0 g 0 G Q" },
        stopcolor  = { "pdf", "page", "Q" },

        startslant = startslant,
        stopslant  = { "pdf", "origin", "Q" },

    }

end
