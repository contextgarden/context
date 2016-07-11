if not modules then modules = { } end modules ['lpdf-grp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local formatters, gsub = string.formatters, string.gsub
local concat = table.concat
local round = math.round

local backends, lpdf = backends, lpdf

local nodeinjections = backends.pdf.nodeinjections

local colors         = attributes.colors
local basepoints     = number.dimenfactors.bp

local nodeinjections = backends.pdf.nodeinjections
local codeinjections = backends.pdf.codeinjections
local registrations  = backends.pdf.registrations

local pdfdictionary  = lpdf.dictionary
local pdfarray       = lpdf.array
local pdfconstant    = lpdf.constant
local pdfboolean     = lpdf.boolean
local pdfreference   = lpdf.reference
local pdfflushobject = lpdf.flushobject

-- can also be done indirectly:
--
-- 12 : << /AntiAlias false /ColorSpace  8 0 R /Coords [ 0.0 0.0 1.0 0.0 ] /Domain [ 0.0 1.0 ] /Extend [ true true ] /Function 22 0 R /ShadingType 2 >>
-- 22 : << /Bounds [ ] /Domain [ 0.0 1.0 ] /Encode [ 0.0 1.0 ] /FunctionType 3 /Functions [ 31 0 R ] >>
-- 31 : << /C0 [ 1.0 0.0 ] /C1 [ 0.0 1.0 ] /Domain [ 0.0 1.0 ] /FunctionType 2 /N 1.0 >>

local function shade(stype,name,domain,color_a,color_b,n,colorspace,coordinates,separation,steps)
    if steps then
        color_a = color_a[1]
        color_b = color_b[1]
    end
    local f = pdfdictionary {
        FunctionType = 2,
        Domain       = pdfarray(domain), -- domain is actually a string
        C0           = pdfarray(color_a),
        C1           = pdfarray(color_b),
        N            = tonumber(n),
    }
    separation = separation and registrations.getspotcolorreference(separation)
    local s = pdfdictionary {
        ShadingType = stype,
        ColorSpace  = separation and pdfreference(separation) or pdfconstant(colorspace),
        Function    = pdfreference(pdfflushobject(f)),
        Coords      = pdfarray(coordinates),
        Extend      = pdfarray { true, true },
        AntiAlias   = pdfboolean(true),
    }
    lpdf.adddocumentshade(name,pdfreference(pdfflushobject(s)))
end

local function shade(stype,name,domain,color_a,color_b,n,colorspace,coordinates,separation,steps,fractions)
    local func = nil
    if steps then
        local list   = pdfarray()
        local bounds = pdfarray()
        local encode = pdfarray()
        for i=1,steps do
            bounds[i]     = fractions[i] or 1
            encode[2*i-1] = 0
            encode[2*i]   = 1
            list  [i]     = pdfdictionary {
                FunctionType = 2,
                Domain       = pdfarray(domain), -- domain is actually a string
                C0           = pdfarray(color_a[i]),
                C1           = pdfarray(color_b[i]),
                N            = tonumber(n),
            }
        end
        func = pdfdictionary {
            FunctionType = 3,
            Bounds       = bounds,
            Encode       = encode,
            Functions    = list,
            Domain       = pdfarray(domain), -- domain is actually a string
        }
    else
        func = pdfdictionary {
            FunctionType = 2,
            Domain       = pdfarray(domain), -- domain is actually a string
            C0           = pdfarray(color_a),
            C1           = pdfarray(color_b),
            N            = tonumber(n),
        }
    end
    separation = separation and registrations.getspotcolorreference(separation)
    local s = pdfdictionary {
        ShadingType = stype,
        ColorSpace  = separation and pdfreference(separation) or pdfconstant(colorspace),
        Function    = pdfreference(pdfflushobject(func)),
        Coords      = pdfarray(coordinates),
        Extend      = pdfarray { true, true },
        AntiAlias   = pdfboolean(true),
    }
    lpdf.adddocumentshade(name,pdfreference(pdfflushobject(s)))
end

function lpdf.circularshade(name,domain,color_a,color_b,n,colorspace,coordinates,separation,steps,fractions)
    shade(3,name,domain,color_a,color_b,n,colorspace,coordinates,separation,steps,fractions)
end

function lpdf.linearshade(name,domain,color_a,color_b,n,colorspace,coordinates,separation,steps,fractions)
    shade(2,name,domain,color_a,color_b,n,colorspace,coordinates,separation,steps,fractions)
end

-- inline bitmaps but xform'd
--
-- we could derive the colorspace if we strip the data
-- and divide by x*y

local template = "q BI %s ID %s > EI Q"
local factor   = 72/300

function nodeinjections.injectbitmap(t)
    -- encoding is ascii hex, no checking here
    local xresolution, yresolution = t.xresolution or 0, t.yresolution or 0
    if xresolution == 0 or yresolution == 0 then
        return -- fatal error
    end
    local colorspace = t.colorspace
    if colorspace ~= "rgb" and colorspace ~= "cmyk" and colorspace ~= "gray" then
        -- not that efficient but ok
        local d = gsub(t.data,"[^0-9a-f]","")
        local b = math.round(#d / (xresolution * yresolution))
        if b == 2 then
            colorspace = "gray"
        elseif b == 6 then
            colorspace = "rgb"
        elseif b == 8 then
            colorspace = "cmyk"
        end
    end
    colorspace = lpdf.colorspaceconstants[colorspace]
    if not colorspace then
        return -- fatal error
    end
    local d = pdfdictionary {
        W   = xresolution,
        H   = yresolution,
        CS  = colorspace,
        BPC = 8,
        F   = pdfconstant("AHx"),
     -- CS  = nil,
     -- BPC = 1,
     -- IM = true,
    }
    -- for some reasons it only works well if we take a 1bp boundingbox
    local urx, ury = 1/basepoints, 1/basepoints
 -- urx = (xresolution/300)/basepoints
 -- ury = (yresolution/300)/basepoints
    local width, height = t.width or 0, t.height or 0
    if width == 0 and height == 0 then
        width  = factor * xresolution / basepoints
        height = factor * yresolution / basepoints
    elseif width == 0 then
        width  = height * xresolution / yresolution
    elseif height == 0 then
        height = width  * yresolution / xresolution
    end
    local image = img.new {
        stream = formatters[template](d(),t.data),
        width  = width,
        height = height,
        bbox   = { 0, 0, urx, ury },
    }
    return img.node(image)
end

-- general graphic helpers

function codeinjections.setfigurealternative(data,figure)
    local request = data.request
    local display = request.display
    if display and display ~= ""  then
        local nested = figures.push {
            name   = display,
            page   = request.page,
            size   = request.size,
            prefix = request.prefix,
            cache  = request.cache,
            width  = request.width,
            height = request.height,
        }
        figures.identify()
        local displayfigure = figures.check()
        if displayfigure then
        --  figure.aform = true
            img.immediatewrite(figure)
            local a = pdfarray {
                pdfdictionary {
                    Image              = pdfreference(figure.objnum),
                    DefaultForPrinting = true,
                }
            }
            local d = pdfdictionary {
                Alternates = pdfreference(pdfflushobject(a)),
            }
            displayfigure.attr = d()
            figures.pop()
            return displayfigure, nested
        else
            figures.pop()
        end
    end
end

function codeinjections.getpreviewfigure(request)
    local figure = figures.initialize(request)
    if not figure then
        return
    end
    figure = figures.identify(figure)
    if not (figure and figure.status and figure.status.fullname) then
        return
    end
    figure = figures.check(figure)
    if not (figure and figure.status and figure.status.fullname) then
        return
    end
    local image = figure.status.private
    if image then
        img.immediatewrite(image)
    end
    return figure
end

function codeinjections.setfiguremask(data,figure) -- mark
    local request = data.request
    local mask = request.mask
    if mask and mask ~= ""  then
        figures.push {
            name   = mask,
            page   = request.page,
            size   = request.size,
            prefix = request.prefix,
            cache  = request.cache,
            width  = request.width,
            height = request.height,
        }
        figures.identify()
        local maskfigure = figures.check()
        if maskfigure then
            local image = maskfigure.status.private
            if image then
                img.immediatewrite(image)
                local d = pdfdictionary {
                    Interpolate  = false,
                    SMask        = pdfreference(image.objnum),
                }
                figure.attr = d()
            end
        end
        figures.pop()
    end
end

-- temp hack

function img.package(image) -- see lpdf-u3d **
    local boundingbox = image.bbox
    local imagetag    = "Im" .. image.index
    local resources   = pdfdictionary {
        ProcSet = pdfarray {
            pdfconstant("PDF"),
            pdfconstant("ImageC")
        },
        Resources = pdfdictionary {
            XObject = pdfdictionary {
                [imagetag] = pdfreference(image.objnum)
            }
        }
    }
    local width = boundingbox[3]
    local height = boundingbox[4]
    local xform = img.scan {
        attr   = resources(),
        stream = formatters["%F 0 0 %F 0 0 cm /%s Do"](width,height,imagetag),
        bbox   = { 0, 0, width/basepoints, height/basepoints },
    }
    img.immediatewrite(xform)
    return xform
end

-- experimental

local nofpatterns = 0
local f_pattern   = formatters["q /Pattern cs /%s scn 0 0 %F %F re f Q"] -- q Q is not really needed

local texsavebox  = tex.saveboxresource

function lpdf.registerpattern(specification)
    nofpatterns = nofpatterns + 1
    local d = pdfdictionary {
        Type        = pdfconstant("Pattern"),
        PatternType = 1,
        PaintType   = 1,
        TilingType  = 2,
        XStep       = (specification.width  or 10) * basepoints,
        YStep       = (specification.height or 10) * basepoints,
        Matrix      = {
            1, 0, 0, 1,
            (specification.hoffset or 0) * basepoints,
            (specification.voffset or 0) * basepoints,
        },
    }
    local resources  = lpdf.collectedresources{ patterns = false }
    local attributes = d()
    local onlybounds = 1
    local patternobj = texsavebox(specification.number,attributes,resources,true,onlybounds)
    lpdf.adddocumentpattern("Pt" .. nofpatterns,lpdf.reference(patternobj ))
    return nofpatterns
end

function lpdf.patternstream(n,width,height)
    return f_pattern("Pt" .. n,width*basepoints,height*basepoints)
end
