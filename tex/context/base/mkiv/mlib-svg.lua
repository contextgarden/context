if not modules then modules = { } end modules ['mlib-svg'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- Just a few notes:
--
-- There is no real need to boost performance here .. we can always make a fast
-- variant when really needed. I will also do some of the todo's when I run into
-- proper fonts. I need to optimize this a bit but will do that once I'm satisfied
-- with the outcome and don't need more hooks and plugs. At some point I will
-- optimize the MetaPost part because now we probably have more image wrapping
-- than needed.
--
-- As usual with these standards, things like a path can be very compact while the
-- rest is very verbose which defeats the point. This is a first attempt. There will
-- be a converter to MP as well as directly to PDF. This module was made for one of
-- the dangerous curves talks at the 2019 CTX meeting. I will do the font when I
-- need it (not that hard).
--
-- The fact that in the more recent versions of SVG the older text related elements
-- are depricated and not even supposed to be supported, combined with the fact that
-- the text element assumes css styling, demonstrates that there is not so much as a
-- standard. It basically means that whatever technology dominates at some point
-- (probably combined with some libraries that at that point exist) determine what
-- is standard. Anyway, it probably also means that these formats are not that
-- suitable for long term archival purposes. So don't take the next implementation
-- too serious. So in the end we now have (1) attributes for properties (which is
-- nice and clean and what attributes are for, (2) a style attribute that needs to
-- be parsed, (3) classes that map to styles and (4) element related styles, plus a
-- kind of inheritance (given the limited number of elements sticking to only <g> as
-- wrapper would have made much sense. Anyway, we need to deal with it. With all
-- these style things going on, one can wonder where it will end. Basically svg
-- became just a html element that way and less clean too. The same is true for
-- tspan, which means that text itself is nested xml.
--
-- We can do a direct conversion to PDF but then we also loose the abstraction which
-- in the future will be used, and for fonts we need to spawn out to TeX anyway, so
-- the little overhead of calling MetaPost is okay I guess. Also, we want to
-- overload labels, share fonts with the main document, etc. and are not aiming at a
-- general purpose SVG converter. For going to PDF one can just use InkScape.
--
-- Written with Anne Clark on speakers as distraction.
--
-- Todo when I run into an example (but ony when needed and reasonable):
--
--   var(color,color)
--   --color<decimal>
--   currentColor : when i run into an example
--   a bit more shading
--   clip = [ auto | rect(llx,lly,urx,ury) ] (in svg)
--   xlink url ... whatever
--   masks
--   opacity per group (i need to add that to metafun first, inefficient pdf but
--   maybe filldraw can help here)
--
-- Maybe in metafun:
--
--   penciled    n     -> withpen pencircle scaled n
--   applied     (...) -> transformed bymatrix (...)
--   withopacity n     -> withtransparency (1,n)

-- When testing mbo files:
--
--   empty paths
--   missing control points
--   funny fontnames like abcdefverdana etc
--   paths representing glyphs but also with style specs
--   all kind of attributes
--   very weird and inefficient shading

-- One can run into pretty crazy images, like lines that are fills being clipped
-- to some width. That's the danger of hiding yourself behind an interface I guess.

local rawget, type, tonumber, tostring, next, setmetatable = rawget, type, tonumber, tostring, next, setmetatable

local P, S, R, C, Ct, Cs, Cc, Cp, Carg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.Cp, lpeg.Carg

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local pi, sin, cos, asin, sind, cosd, tan, abs, sqrt = math.pi, math.sin, math.cos, math.asin, math.sind, math.cosd, math.tan, math.abs, math.sqrt
local concat, setmetatableindex, sortedhash = table.concat, table.setmetatableindex, table.sortedhash
local gmatch, gsub, find, match, rep = string.gmatch, string.gsub, string.find, string.match, string.rep
local formatters, fullstrip = string.formatters, string.fullstrip
local extract = bit32.extract
local utfsplit, utfbyte = utf.split, utf.byte

local xmlconvert, xmlcollected, xmlcount, xmlfirst, xmlroot = xml.convert, xml.collected, xml.count, xml.first, xml.root
local xmltext, xmltextonly = xml.text, xml.textonly
local css = xml.css or { } -- testing

local bpfactor = number.dimenfactors.bp

local function xmlinheritattributes(c,pa)
    local at = c.at
    local dt = c.dt
    if at and dt then
        if pa then
            setmetatableindex(at,pa)
        end
        for i=1,#dt do
            local dti = dt[i]
            if type(dti) == "table" then
                xmlinheritattributes(dti,at)
            end
        end
    else
        -- comment of so
    end
end

xml.inheritattributes = xmlinheritattributes

-- Maybe some day helpers will move to the metapost.svg namespace!

metapost       = metapost or { }
local metapost = metapost
local context  = context

local report       = logs.reporter("metapost","svg")

local trace        = false  trackers.register("metapost.svg",        function(v) trace        = v end)
local trace_text   = false  trackers.register("metapost.svg.text",   function(v) trace_text   = v end)
local trace_path   = false  trackers.register("metapost.svg.path",   function(v) trace_path   = v end)
local trace_result = false  trackers.register("metapost.svg.result", function(v) trace_result = v end)

local pathtracer = {
    ["stroke"]         = "darkred",
    ["stroke-opacity"] = ".5",
    ["stroke-width"]   = ".5",
    ["fill"]           = "darkgray",
    ["fill-opacity"]   = ".75",
}

-- We have quite some closures because otherwise we run into the local variable
-- limitations. It doesn't always look pretty now, sorry. I'll clean up this mess
-- some day (the usual nth iteration of code).
--
-- Most of the conversion is rather trivial code till I ran into a file with arcs. A
-- bit of searching lead to the a2c javascript function but it has some puzzling
-- thingies (like sin and cos definitions that look like leftovers and possible
-- division by zero). Anyway, we can if needed optimize it a bit more. Here does it
-- come from:

-- http://www.w3.org/TR/SVG11/implnote.html#ArcImplementationNotes
-- https://github.com/adobe-webplatform/Snap.svg/blob/b242f49e6798ac297a3dad0dfb03c0893e394464/src/path.js

local a2c  do

    local d120 = (pi * 120) / 180
    local pi2  = 2 * pi

    a2c = function(x1, y1, rx, ry, angle, large, sweep, x2, y2, f1, f2, cx, cy)

        if (rx == 0 or ry == 0 ) or (x1 == x2 and y1 == y2) then
            return { x1, y1, x2, y2, x2, y2 }
        end

        local recursive = f1
        local rad       = pi / 180 * angle
        local res       = nil
        local cosrad    = cos(-rad) -- local cosrad = cosd(angle)
        local sinrad    = sin(-rad) -- local sinrad = sind(angle)

        if not recursive then

            x1, y1 = x1 * cosrad - y1 * sinrad, x1 * sinrad + y1 * cosrad
            x2, y2 = x2 * cosrad - y2 * sinrad, x2 * sinrad + y2 * cosrad

            local x  = (x1 - x2) / 2
            local y  = (y1 - y2) / 2
            local xx = x * x
            local yy = y * y
            local h  = xx / (rx * rx) + yy / (ry * ry)

            if h > 1 then
                h  = sqrt(h)
                rx = h * rx
                ry = h * ry
            end

            local rx2   = rx * rx
            local ry2   = ry * ry
            local ry2xx = ry2 * xx
            local rx2yy = rx2 * yy
            local total = rx2yy + ry2xx -- otherwise overflow

            local k     = total == 0 and 0 or sqrt(abs((rx2 * ry2 - rx2yy - ry2xx) / total))

            if large == sweep then
                k = -k
            end

            cx = k *  rx * y / ry + (x1 + x2) / 2
            cy = k * -ry * x / rx + (y1 + y2) / 2

            f1 = (y1 - cy) / ry -- otherwise crash on a tiny eps
            f2 = (y2 - cy) / ry -- otherwise crash on a tiny eps

            f1 = asin((f1 < -1.0 and -1.0) or (f1 > 1.0 and 1.0) or f1)
            f2 = asin((f2 < -1.0 and -1.0) or (f2 > 1.0 and 1.0) or f2)

            if x1 < cx then f1 = pi  - f1 end
            if x2 < cx then f2 = pi  - f2 end

            if f1 < 0  then f1 = pi2 + f1 end
            if f2 < 0  then f2 = pi2 + f2 end

            if sweep ~= 0 and f1 > f2 then f1 = f1 - pi2 end
            if sweep == 0 and f2 > f1 then f2 = f2 - pi2 end

        end

        if abs(f2 - f1) > d120 then
            local f2old = f2
            local x2old = x2
            local y2old = y2
            f2 = f1 + d120 * ((sweep ~= 0 and f2 > f1) and 1 or -1)
            x2 = cx + rx * cos(f2)
            y2 = cy + ry * sin(f2)
            res = a2c(x2, y2, rx, ry, angle, 0, sweep, x2old, y2old, f2, f2old, cx, cy)
        end

        local c1 = cos(f1)
        local s1 = sin(f1)
        local c2 = cos(f2)
        local s2 = sin(f2)

        local t  = tan((f2 - f1) / 4)
        local hx = 4 * rx * t / 3
        local hy = 4 * ry * t / 3

        local r = { x1 - hx * s1, y1 + hy * c1, x2 + hx * s2, y2 - hy * c2, x2, y2, unpack(res or { }) }

        if not recursive then -- we can also check for sin/cos being 0/1
            cosrad = cos(rad)
            sinrad = sin(rad)
         -- cosrad = cosd(angle)
         -- sinrad = sind(angle)
            for i0=1,#r,2 do
                local i1 = i0 + 1
                local x  = r[i0]
                local y  = r[i1]
                r[i0] = x * cosrad - y * sinrad
                r[i1] = x * sinrad + y * cosrad
            end
        end

        return r
    end

end

-- We share some patterns.

local p_digit    = lpegpatterns.digit
local p_hexdigit = lpegpatterns.hexdigit
local p_space    = lpegpatterns.whitespace

local factors  = {
    ["pt"] =  1.25,
    ["mm"] =  3.543307,
    ["cm"] = 35.43307,
    ["px"] =  1,
    ["pc"] = 15,
    ["in"] = 90,
    ["em"] = 12 * 1.25,
    ["ex"] =  8 * 1.25,
}

local percentage_r = 1/100
local percentage_x = percentage_r
local percentage_y = percentage_r

-- incredible: we can find .123.456 => 0.123 0.456 ...

local p_command_x  = C(S("Hh"))
local p_command_y  = C(S("Vv"))
local p_command_xy = C(S("CcLlMmQqSsTt"))
local p_command_a  = C(S("Aa"))
local p_command    = C(S("Zz"))

local p_optseparator = S("\t\n\r ,")^0
local p_separator    = S("\t\n\r ,")^1
local p_number       = (S("+-")^0 * (p_digit^0 * P(".") * p_digit^1 + p_digit^1 * P(".") + p_digit^1))
                     * (P("e") * S("+-")^0 * p_digit^1)^-1

local function convert   (n)   n =   tonumber(n)                                                                           return n     end
local function convert_r (n,u) n =   tonumber(n) if u == true then return percentage_r * n elseif u then return u * n else return n end end
local function convert_x (n,u) n =   tonumber(n) if u == true then return percentage_x * n elseif u then return u * n else return n end end
local function convert_y (n,u) n =   tonumber(n) if u == true then return percentage_y * n elseif u then return u * n else return n end end
local function convert_vx(n,u) n =   tonumber(n) if u == true then return percentage_x * n elseif u then return u * n else return n end end
local function convert_vy(n,u) n = - tonumber(n) if u == true then return percentage_y * n elseif u then return u * n else return n end end

local p_unit      = (P("p") * S("txc") + P("e") * S("xm") + S("mc") * P("m") + P("in")) / factors
local p_percent   = P("%") * Cc(true)

local c_number_n  = C(p_number)
local c_number_u  = C(p_number) * (p_unit + p_percent)^-1

local p_number_n  = c_number_n / convert
local p_number_x  = c_number_u / convert_x
local p_number_vx = c_number_u / convert_vx
local p_number_y  = c_number_u / convert_y
local p_number_vy = c_number_u / convert_vy
local p_number_r  = c_number_u / convert_r

local function asnumber   (s) return s and lpegmatch(p_number,   s) or 0 end
local function asnumber_r (s) return s and lpegmatch(p_number_r, s) or 0 end
local function asnumber_x (s) return s and lpegmatch(p_number_x, s) or 0 end
local function asnumber_y (s) return s and lpegmatch(p_number_y, s) or 0 end
local function asnumber_vx(s) return s and lpegmatch(p_number_vx,s) or 0 end
local function asnumber_vy(s) return s and lpegmatch(p_number_vy,s) or 0 end

local p_number_vx_t = Ct { (p_number_vx + p_separator)^1 }
local p_number_vy_t = Ct { (p_number_vy + p_separator)^1 }

local zerotable = { 0 }

local function asnumber_vx_t(s) return s and lpegmatch(p_number_vx_t,s) or zerotable end
local function asnumber_vy_t(s) return s and lpegmatch(p_number_vy_t,s) or zerotable end

local p_numbersep   = p_number_n + p_separator
local p_numbers     = p_optseparator * P("(") * p_numbersep^0 * p_optseparator * P(")")
local p_fournumbers = p_numbersep^4
local p_path        = Ct ( (
      p_command_xy * (p_optseparator * p_number_vx *
                      p_optseparator * p_number_vy )^1
    + p_command_x  * (p_optseparator * p_number_vx )^1
    + p_command_y  * (p_optseparator * p_number_vy )^1
    + p_command_a  * (p_optseparator * p_number_vx *
                      p_optseparator * p_number_vy *
                      p_optseparator * p_number_r  *
                      p_optseparator * p_number_n  * -- flags
                      p_optseparator * p_number_n  * -- flags
                      p_optseparator * p_number_vx *
                      p_optseparator * p_number_vy )^1
    + p_command
    + p_separator
)^1 )

-- We can actually use the svg color definitions from the tex end but maybe a user
-- doesn't want those replace the normal definitions.
--
-- local hexhash  = setmetatableindex(function(t,k) local v = lpegmatch(p_hexcolor, k) t[k] = v return v end)  -- per file
-- local hexhash3 = setmetatableindex(function(t,k) local v = lpegmatch(p_hexcolor3,k) t[k] = v return v end)  -- per file
--
-- local function hexcolor (c) return hexhash [c] end -- directly do hexhash [c]
-- local function hexcolor3(c) return hexhash3[c] end -- directly do hexhash3[c]

local rgbcomponents, withcolor, thecolor  do

    local svgcolors = {
        aliceblue       = 0xF0F8FF, antiquewhite      = 0xFAEBD7, aqua                  = 0x00FFFF, aquamarine       = 0x7FFFD4,
        azure           = 0xF0FFFF, beige             = 0xF5F5DC, bisque                = 0xFFE4C4, black            = 0x000000,
        blanchedalmond  = 0xFFEBCD, blue              = 0x0000FF, blueviolet            = 0x8A2BE2, brown            = 0xA52A2A,
        burlywood       = 0xDEB887, cadetblue         = 0x5F9EA0, hartreuse             = 0x7FFF00, chocolate        = 0xD2691E,
        coral           = 0xFF7F50, cornflowerblue    = 0x6495ED, cornsilk              = 0xFFF8DC, crimson          = 0xDC143C,
        cyan            = 0x00FFFF, darkblue          = 0x00008B, darkcyan              = 0x008B8B, darkgoldenrod    = 0xB8860B,
        darkgray        = 0xA9A9A9, darkgreen         = 0x006400, darkgrey              = 0xA9A9A9, darkkhaki        = 0xBDB76B,
        darkmagenta     = 0x8B008B, darkolivegreen    = 0x556B2F, darkorange            = 0xFF8C00, darkorchid       = 0x9932CC,
        darkred         = 0x8B0000, darksalmon        = 0xE9967A, darkseagreen          = 0x8FBC8F, darkslateblue    = 0x483D8B,
        darkslategray   = 0x2F4F4F, darkslategrey     = 0x2F4F4F, darkturquoise         = 0x00CED1, darkviolet       = 0x9400D3,
        deeppink        = 0xFF1493, deepskyblue       = 0x00BFFF, dimgray               = 0x696969, dimgrey          = 0x696969,
        dodgerblue      = 0x1E90FF, firebrick         = 0xB22222, floralwhite           = 0xFFFAF0, forestgreen      = 0x228B22,
        fuchsia         = 0xFF00FF, gainsboro         = 0xDCDCDC, ghostwhite            = 0xF8F8FF, gold             = 0xFFD700,
        goldenrod       = 0xDAA520, gray              = 0x808080, green                 = 0x008000, greenyellow      = 0xADFF2F,
        grey            = 0x808080, honeydew          = 0xF0FFF0, hotpink               = 0xFF69B4, indianred        = 0xCD5C5C,
        indigo          = 0x4B0082, ivory             = 0xFFFFF0, khaki                 = 0xF0E68C, lavender         = 0xE6E6FA,
        lavenderblush   = 0xFFF0F5, lawngreen         = 0x7CFC00, lemonchiffon          = 0xFFFACD, lightblue        = 0xADD8E6,
        lightcoral      = 0xF08080, lightcyan         = 0xE0FFFF, lightgoldenrodyellow  = 0xFAFAD2, lightgray        = 0xD3D3D3,
        lightgreen      = 0x90EE90, lightgrey         = 0xD3D3D3, lightpink             = 0xFFB6C1, lightsalmon      = 0xFFA07A,
        lightseagreen   = 0x20B2AA, lightskyblue      = 0x87CEFA, lightslategray        = 0x778899, lightslategrey   = 0x778899,
        lightsteelblue  = 0xB0C4DE, lightyellow       = 0xFFFFE0, lime                  = 0x00FF00, limegreen        = 0x32CD32,
        linen           = 0xFAF0E6, magenta           = 0xFF00FF, maroon                = 0x800000, mediumaquamarine = 0x66CDAA,
        mediumblue      = 0x0000CD, mediumorchid      = 0xBA55D3, mediumpurple          = 0x9370DB, mediumseagreen   = 0x3CB371,
        mediumslateblue = 0x7B68EE, mediumspringgreen = 0x00FA9A, mediumturquoise       = 0x48D1CC, mediumvioletred  = 0xC71585,
        midnightblue    = 0x191970, mintcream         = 0xF5FFFA, mistyrose             = 0xFFE4E1, moccasin         = 0xFFE4B5,
        navajowhite     = 0xFFDEAD, navy              = 0x000080, oldlace               = 0xFDF5E6, olive            = 0x808000,
        olivedrab       = 0x6B8E23, orange            = 0xFFA500, orangered             = 0xFF4500, orchid           = 0xDA70D6,
        palegoldenrod   = 0xEEE8AA, palegreen         = 0x98FB98, paleturquoise         = 0xAFEEEE, palevioletred    = 0xDB7093,
        papayawhip      = 0xFFEFD5, peachpuff         = 0xFFDAB9, peru                  = 0xCD853F, pink             = 0xFFC0CB,
        plum            = 0xDDA0DD, powderblue        = 0xB0E0E6, purple                = 0x800080, red              = 0xFF0000,
        rosybrown       = 0xBC8F8F, royalblue         = 0x4169E1, saddlebrown           = 0x8B4513, salmon           = 0xFA8072,
        sandybrown      = 0xF4A460, seagreen          = 0x2E8B57, seashell              = 0xFFF5EE, sienna           = 0xA0522D,
        silver          = 0xC0C0C0, skyblue           = 0x87CEEB, slateblue             = 0x6A5ACD, slategray        = 0x708090,
        slategrey       = 0x708090, snow              = 0xFFFAFA, springgreen           = 0x00FF7F, steelblue        = 0x4682B4,
        tan             = 0xD2B48C, teal              = 0x008080, thistle               = 0xD8BFD8, tomato           = 0xFF6347,
        turquoise       = 0x40E0D0, violet            = 0xEE82EE, wheat                 = 0xF5DEB3, white            = 0xFFFFFF,
        whitesmoke      = 0xF5F5F5, yellow            = 0xFFFF00, yellowgreen           = 0x9ACD32,
    }

    local f_rgb      = formatters['withcolor svgcolor(%.3N,%.3N,%.3N)']
    local f_gray     = formatters['withcolor svggray(%.3N)']
    local f_rgba     = formatters['withcolor svgcolor(%.3N,%.3N,%.3N) withtransparency (1,%.3N)']
    local f_graya    = formatters['withcolor svggray(%.3N) withtransparency (1,%.3N)']
    local f_name     = formatters['withcolor "%s"']
    local f_svgcolor = formatters['svgcolor(%.3N,%.3N,%.3N)']
    local f_svggray  = formatters['svggray(%.3N)']
    local f_svgname  = formatters['"%s"']

    local triplets = setmetatableindex(function(t,k)
        -- we delay building all these strings
        local v = svgcolors[k]
        if v then
            v = { extract(v,16,8)/255, extract(v,8,8)/255, extract(v,0,8)/255 }
        else
            v = false
        end
        t[k] = v
        return v
    end)

    local p_fraction  = C(p_number) * C("%")^-1 / function(a,b)
        a = tonumber(a) return a / (b and 100 or 255)
    end
    local p_hexcolor  = P("#") * C(p_hexdigit*p_hexdigit)^1 / function(r,g,b)
        return r and tonumber(r,16)/255 or nil, g and tonumber(g,16)/255 or nil, b and tonumber(b,16)/255 or nil
    end
    local p_rgbacolor = P("rgb") * (P("a")^-1) * P("(") * (p_fraction  + p_separator)^1 * P(")")

    rgbcomponents = function(color)
        local h = lpegmatch(p_hexcolor,color)
        if h then
            return h
        end
        local r, g, b, a = lpegmatch(p_rgbacolor,color)
        if r then
            return r, g or r, b or r
        end
        local t = triplets[color]
        return t[1], t[2], t[3]

    end

    withcolor = function(color)
        local r, g, b = lpegmatch(p_hexcolor,color)
        if b and not (r == g and g == b) then
            return f_rgb(r,g,b)
        elseif r then
            return f_gray(r)
        end
        local r, g, b, a = lpegmatch(p_rgbacolor,color)
        if a then
            if a == 1 then
                if r == g and g == b then
                    return f_gray(r)
                else
                    return f_rgb(r,g,b)
                end
            else
                if r == g and g == b then
                    return f_graya(r,a)
                else
                    return f_rgba(r,g,b,a)
                end
            end
        end
        if not r then
            local t = triplets[color]
            if t then
                r, g, b = t[1], t[2], t[3]
            end
        end
        if r then
            if r == g and g == b then
                return f_gray(r)
            elseif g and b then
                return f_rgb(r,g,b)
            else
                return f_gray(r)
            end
        end
        return f_name(color)
    end

    thecolor = function(color)
        local h = lpegmatch(p_hexcolor,color)
        if h then
            return h
        end
        local r, g, b, a = lpegmatch(p_rgbacolor,color)
        if not r then
            local t = triplets[color]
            if t then
                r, g, b = t[1], t[2], t[3]
            end
        end
        if r then
            if r == g and g == b then
                return f_svggray(r)
            elseif g and b then
                return f_svgcolor(r,g,b)
            else
                return f_svggray(r)
            end
        end
        return f_svgname(color)
    end

end

-- actually we can loop faster because we can go to the last one

local grabpath, grablist  do

    local f_moveto    = formatters['(%N,%N)']
    local f_curveto_z = formatters['controls(%N,%N)and(%N,%N)..(%N,%N)']
    local f_curveto_n = formatters['..controls(%N,%N)and(%N,%N)..(%N,%N)']
    local f_lineto_z  = formatters['(%N,%N)']
    local f_lineto_n  = formatters['--(%N,%N)']

    local m = { __index = function() return 0 end }

    grabpath = function(str)
        local p   = lpegmatch(p_path,str) or { }
        local np  = #p
        local all = { entries = np, closed = false, curve = false }
        if np == 0 then
            return all
        end
        setmetatable(p,m)
        local t      = { }    -- no real saving here if we share
        local n      = 0
        local a      = 0
        local i      = 0
        local last   = "M"
        local prev   = last
        local kind   = "L"
        local x, y   = 0, 0
        local x1, y1 = 0, 0
        local x2, y2 = 0, 0
        local rx, ry = 0, 0
        local ar, al = 0, 0
        local as, ac = 0, nil
        local mx, my = 0, 0
        while i < np do
            i = i + 1
            local pi = p[i]
            if type(pi) ~= "number" then
                last = pi
                i    = i + 1
                pi   = p[i]
            end
            -- most often
            if last == "c" then
                            x1 = x + pi
                i = i + 1 ; y1 = y + p[i]
                i = i + 1 ; x2 = x + p[i]
                i = i + 1 ; y2 = y + p[i]
                i = i + 1 ; x  = x + p[i]
                i = i + 1 ; y  = y + p[i]
                goto curveto
            elseif last == "l" then
                            x = x + pi
                i = i + 1 ; y = y + p[i]
                goto lineto
            elseif last == "h" then
                x = x + pi
                goto lineto
            elseif last == "v" then
                y = y + pi
                goto lineto
            elseif last == "a" then
                            x1 =     x
                            y1 =     y
                            rx =     pi
                i = i + 1 ; ry =     p[i]
                i = i + 1 ; ar =     p[i]
                i = i + 1 ; al =     p[i]
                i = i + 1 ; as =     p[i]
                i = i + 1 ; x  = x + p[i]
                i = i + 1 ; y  = y + p[i]
                goto arc
            elseif last == "s" then
                if prev == "C" then
                    x1 = 2 * x - x2
                    y1 = 2 * y - y2
                else
                    x1 = x
                    y1 = y
                end
                            x2 = x + pi
                i = i + 1 ; y2 = y + p[i]
                i = i + 1 ; x  = x + p[i]
                i = i + 1 ; y  = y + p[i]
                goto curveto
            elseif last == "m" then
                if n > 0 then
                    a = a + 1 ; all[a] = concat(t,"",1,n) ; n = 0
                end
                            x = x + pi
                i = i + 1 ; y = y + p[i]
                goto moveto
            elseif last == "z" then
                goto close
            -- less frequent
            elseif last == "C" then
                            x1 = pi
                i = i + 1 ; y1 = p[i]
                i = i + 1 ; x2 = p[i]
                i = i + 1 ; y2 = p[i]
                i = i + 1 ; x  = p[i]
                i = i + 1 ; y  = p[i]
                goto curveto
            elseif last == "L" then
                            x = pi
                i = i + 1 ; y = p[i]
                goto lineto
            elseif last == "H" then
                x = pi
                goto lineto
            elseif last == "V" then
                y = pi
                goto lineto
            elseif last == "A" then
                            x1 = x
                            y1 = y
                            rx = pi
                i = i + 1 ; ry = p[i]
                i = i + 1 ; ar = p[i]
                i = i + 1 ; al = p[i]
                i = i + 1 ; as = p[i]
                i = i + 1 ; x  = p[i]
                i = i + 1 ; y  = p[i]
                goto arc
            elseif last == "S" then
                if prev == "C" then
                    x1 = 2 * x - x2
                    y1 = 2 * y - y2
                else
                    x1 = x
                    y1 = y
                end
                            x2 = pi
                i = i + 1 ; y2 = p[i]
                i = i + 1 ; x  = p[i]
                i = i + 1 ; y  = p[i]
                goto curveto
            elseif last == "M" then
                if n > 0 then
                    a = a + 1 ; all[a] = concat(t,"",1,n) ; n = 0
                end
                            x = pi ;
                i = i + 1 ; y = p[i]
                goto moveto
            elseif last == "Z" then
                goto close
            -- very seldom
            elseif last == "q" then
                            x1 = x + pi
                i = i + 1 ; y1 = y + p[i]
                i = i + 1 ; x2 = x + p[i]
                i = i + 1 ; y2 = y + p[i]
                goto quadratic
            elseif last == "t" then
                if prev == "C" then
                    x1 = 2 * x - x1
                    y1 = 2 * y - y1
                else
                    x1 = x
                    y1 = y
                end
                            x2 = x + pi
                i = i + 1 ; y2 = y + p[i]
                goto quadratic
            elseif last == "Q" then
                            x1 = pi
                i = i + 1 ; y1 = p[i]
                i = i + 1 ; x2 = p[i]
                i = i + 1 ; y2 = p[i]
                goto quadratic
            elseif last == "T" then
                if prev == "C" then
                    x1 = 2 * x - x1
                    y1 = 2 * y - y1
                else
                    x1 = x
                    y1 = y
                end
                            x2 = pi
                i = i + 1 ; y2 = p[i]
                goto quadratic
            else
                goto continue
            end
            ::moveto::
                n = n + 1 ; t[n] = f_moveto(x,y)
                last = last == "M" and "L" or "l"
                prev = "M"
                mx = x
                my = y
                goto continue
            ::lineto::
                n = n + 1 ; t[n] = (n > 0 and f_lineto_n or f_lineto_z)(x,y)
                prev = "L"
                goto continue
            ::curveto::
                n = n + 1 ; t[n] = (n > 0 and f_curveto_n or f_curveto_z)(x1,y1,x2,y2,x,y)
                prev = "C"
                goto continue
            ::arc::
                ac = a2c(x1,y1,rx,ry,ar,al,as,x,y)
                for i=1,#ac,6 do
                    n = n + 1 ; t[n] = (n > 0 and f_curveto_n or f_curveto_z)(
                        ac[i],ac[i+1],ac[i+2],ac[i+3],ac[i+4],ac[i+5]
                    )
                end
                prev = "A"
                goto continue
            ::quadratic::
                n = n + 1 ; t[n] = (n > 0 and f_curveto_n or f_curveto_z)(
                    x  + 2/3 * (x1-x ), y  + 2/3 * (y1-y ),
                    x2 + 2/3 * (x1-x2), y2 + 2/3 * (y1-y2),
                    x2,                 y2
                )
                x = x2
                y = y2
                prev = "C"
                goto continue
            ::close::
            --  n = n + 1 ; t[n] = prev == "C" and "..cycle" or "--cycle"
                n = n + 1 ; t[n] = "--cycle"
                if n > 0 then
                    a = a + 1 ; all[a] = concat(t,"",1,n) ; n = 0
                end
                if i == np then
                    break
                else
                    i = i - 1
                end
                kind = prev
                prev = "Z"
                -- this is kind of undocumented: a close also moves back
                x = mx
                y = my
            ::continue::
        end
        if n > 0 then
            a = a + 1 ; all[a] = concat(t,"",1,n) ; n = 0
        end
        if prev == "Z" then
            all.closed = true
        end
        all.curve = (kind == "C" or kind == "A")
        return all, p
    end

    -- this is a bit tricky as what are points for a mark ... the next can be simplified
    -- a lot

    grablist = function(p)
        local np  = #p
        if np == 0 then
            return nil
        end
        local t      = { }
        local n      = 0
        local a      = 0
        local i      = 0
        local last   = "M"
        local prev   = last
        local kind   = "L"
        local x, y   = 0, 0
        local x1, y1 = 0, 0
        local x2, y2 = 0, 0
        local rx, ry = 0, 0
        local ar, al = 0, 0
        local as, ac = 0, nil
        local mx, my = 0, 0
        while i < np do
            i = i + 1
            local pi = p[i]
            if type(pi) ~= "number" then
                last = pi
                i    = i + 1
                pi   = p[i]
            end
            -- most often
            if last == "c" then
                            x1 = x + pi
                i = i + 1 ; y1 = y + p[i]
                i = i + 1 ; x2 = x + p[i]
                i = i + 1 ; y2 = y + p[i]
                i = i + 1 ; x  = x + p[i]
                i = i + 1 ; y  = y + p[i]
                goto curveto
            elseif last == "l" then
                            x = x + pi
                i = i + 1 ; y = y + p[i]
                goto lineto
            elseif last == "h" then
                x = x + pi
                goto lineto
            elseif last == "v" then
                y = y + pi
                goto lineto
            elseif last == "a" then
                            x1 =     x
                            y1 =     y
                            rx =     pi
                i = i + 1 ; ry =     p[i]
                i = i + 1 ; ar =     p[i]
                i = i + 1 ; al =     p[i]
                i = i + 1 ; as =     p[i]
                i = i + 1 ; x  = x + p[i]
                i = i + 1 ; y  = y + p[i]
                goto arc
            elseif last == "s" then
                if prev == "C" then
                    x1 = 2 * x - x2
                    y1 = 2 * y - y2
                else
                    x1 = x
                    y1 = y
                end
                            x2 = x + pi
                i = i + 1 ; y2 = y + p[i]
                i = i + 1 ; x  = x + p[i]
                i = i + 1 ; y  = y + p[i]
                goto curveto
            elseif last == "m" then
                            x = x + pi
                i = i + 1 ; y = y + p[i]
                goto moveto
            elseif last == "z" then
                goto close
            -- less frequent
            elseif last == "C" then
                            x1 = pi
                i = i + 1 ; y1 = p[i]
                i = i + 1 ; x2 = p[i]
                i = i + 1 ; y2 = p[i]
                i = i + 1 ; x  = p[i]
                i = i + 1 ; y  = p[i]
                goto curveto
            elseif last == "L" then
                            x = pi
                i = i + 1 ; y = p[i]
                goto lineto
            elseif last == "H" then
                x = pi
                goto lineto
            elseif last == "V" then
                y = pi
                goto lineto
            elseif last == "A" then
                            x1 = x
                            y1 = y
                            rx = pi
                i = i + 1 ; ry = p[i]
                i = i + 1 ; ar = p[i]
                i = i + 1 ; al = p[i]
                i = i + 1 ; as = p[i]
                i = i + 1 ; x  = p[i]
                i = i + 1 ; y  = p[i]
                goto arc
            elseif last == "S" then
                if prev == "C" then
                    x1 = 2 * x - x2
                    y1 = 2 * y - y2
                else
                    x1 = x
                    y1 = y
                end
                            x2 = pi
                i = i + 1 ; y2 = p[i]
                i = i + 1 ; x  = p[i]
                i = i + 1 ; y  = p[i]
                goto curveto
            elseif last == "M" then
                            x = pi ;
                i = i + 1 ; y = p[i]
                goto moveto
            elseif last == "Z" then
                goto close
            -- very seldom
            elseif last == "q" then
                            x1 = x + pi
                i = i + 1 ; y1 = y + p[i]
                i = i + 1 ; x2 = x + p[i]
                i = i + 1 ; y2 = y + p[i]
                goto quadratic
            elseif last == "t" then
                if prev == "C" then
                    x1 = 2 * x - x1
                    y1 = 2 * y - y1
                else
                    x1 = x
                    y1 = y
                end
                            x2 = x + pi
                i = i + 1 ; y2 = y + p[i]
                goto quadratic
            elseif last == "Q" then
                            x1 = pi
                i = i + 1 ; y1 = p[i]
                i = i + 1 ; x2 = p[i]
                i = i + 1 ; y2 = p[i]
                goto quadratic
            elseif last == "T" then
                if prev == "C" then
                    x1 = 2 * x - x1
                    y1 = 2 * y - y1
                else
                    x1 = x
                    y1 = y
                end
                            x2 = pi
                i = i + 1 ; y2 = p[i]
                goto quadratic
            else
                goto continue
            end
            ::moveto::
                n = n + 1 ; t[n] = x
                n = n + 1 ; t[n] = y
                last = last == "M" and "L" or "l"
                prev = "M"
                mx = x
                my = y
                goto continue
            ::lineto::
                n = n + 1 ; t[n] = x
                n = n + 1 ; t[n] = y
                prev = "L"
                goto continue
            ::curveto::
                n = n + 1 ; t[n] = x
                n = n + 1 ; t[n] = y
                prev = "C"
                goto continue
            ::arc::
                ac = a2c(x1,y1,rx,ry,ar,al,as,x,y)
                for i=1,#ac,6 do
                    n = n + 1 ; t[n] = ac[i+4]
                    n = n + 1 ; t[n] = ac[i+5]
                end
                prev = "A"
                goto continue
            ::quadratic::
                n = n + 1 ; t[n] = x2
                n = n + 1 ; t[n] = y2
                x = x2
                y = y2
                prev = "C"
                goto continue
            ::close::
                n = n + 1 ; t[n] = mx
                n = n + 1 ; t[n] = my
                if i == np then
                    break
                end
                kind = prev
                prev = "Z"
                x = mx
                y = my
            ::continue::
        end
        return t
    end

end

-- todo: viewbox helper

local s_wrapped_start = "draw image ("
local f_wrapped_stop  = formatters[") shifted (0,%N) scaled %N ;"]

local handletransform, handleviewbox  do

    --todo: better lpeg

    local f_rotatedaround   = formatters[" rotatedaround((%N,%N),%N)"]
    local f_rotated         = formatters[" rotated(%N)"]
    local f_shifted         = formatters[" shifted(%N,%N)"]
    local f_slanted_x       = formatters[" xslanted(%N)"]
    local f_slanted_y       = formatters[" yslanted(%N)"]
    local f_scaled          = formatters[" scaled(%N)"]
    local f_xyscaled        = formatters[" xyscaled(%N,%N)"]
    local f_matrix          = formatters[" transformed bymatrix(%N,%N,%N,%N,%N,%N)"]

    local s_transform_start = "draw image ( "
    local f_transform_stop  = formatters[")%s ;"]

    local function rotate(r,x,y)
        if x then
            return r and f_rotatedaround(x,-(y or x),-r)
        elseif r then
            return f_rotated(-r)
        else
            return ""
        end
    end

    local function translate(x,y)
        if y then
            return f_shifted(x,-y)
        elseif x then
            return f_shifted(x,0)
        else
            return ""
        end
    end

    local function scale(x,y)
        if y then
            return f_xyscaled(x,y)
        elseif x then
            return f_scaled(x)
        else
            return ""
        end
    end

    local function skewx(x)
        if x then
            return f_slanted_x(math.sind(-x))
        else
            return ""
        end
    end

    local function skewy(y)
        if y then
            return f_slanted_y(math.sind(-y))
        else
            return ""
        end
    end

    local function matrix(rx,sx,sy,ry,tx,ty)
        return f_matrix(rx or 1, sx or 0, sy or 0, ry or 1, tx or 0, - (ty or 0))
    end

    -- how to deal with units here?

    local p_transform = Cs ( (
        P("translate") * p_numbers / translate       -- maybe xy
      + P("scale")     * p_numbers / scale
      + P("rotate")    * p_numbers / rotate
      + P("matrix")    * p_numbers / matrix
      + P("skewX")     * p_numbers / skewx
      + P("skewY")     * p_numbers / skewy
   -- + p_separator
      + P(1)/""
    )^1)

    handletransform = function(at)
        local t = at.transform
        if t then
            local e = lpegmatch(p_transform,t)
            return s_transform_start, f_transform_stop(e), t
        end
    end

    handleviewbox = function(v)
        if v then
            local x, y, w, h = lpegmatch(p_fournumbers,v)
            if h then
                return x, y, w, h
            end
        end
    end

end

local dashed  do

    -- actually commas are mandate but we're tolerant

    local f_dashed_n = formatters[" dashed dashpattern (%s ) "]
    local f_dashed_y = formatters[" dashed dashpattern (%s ) shifted (%N,0) "]

    local p_number   = p_optseparator/"" * p_number_r
    local p_on       = Cc(" on ")  * p_number
    local p_off      = Cc(" off ") * p_number
    local p_dashed   = Cs((p_on * p_off^-1)^1)

    dashed = function(s,o)
        if not find(s,",") then
            -- a bit of a hack:
            s = s .. " " .. s
        end
        return (o and f_dashed_y or f_dashed_n)(lpegmatch(p_dashed,s),o)
    end

end

do

    local handlers    = { }
    local process     = false
    local root        = false
    local result      = false
    local r           = false
    local definitions = false
    local classstyles = false
    local tagstyles   = false

    local tags = {
        ["a"]                  = true,
     -- ["altgGlyph"]          = true,
     -- ["altgGlyphDef"]       = true,
     -- ["altgGlyphItem"]      = true,
     -- ["animate"]            = true,
     -- ["animateColor"]       = true,
     -- ["animateMotion"]      = true,
     -- ["animateTransform"]   = true,
        ["circle"]             = true,
        ["clipPath"]           = true,
     -- ["color-profile"]      = true,
     -- ["cursor"]             = true,
        ["defs"]               = true,
     -- ["desc"]               = true,
        ["ellipse"]            = true,
     -- ["filter"]             = true,
     -- ["font"]               = true,
     -- ["font-face"]          = true,
     -- ["font-face-format"]   = true,
     -- ["font-face-name"]     = true,
     -- ["font-face-src"]      = true,
     -- ["font-face-uri"]      = true,
     -- ["foreignObject"]      = true,
        ["g"]                  = true,
     -- ["glyph"]              = true,
     -- ["glyphRef"]           = true,
     -- ["hkern"]              = true,
        ["image"]              = true,
        ["line"]               = true,
        ["linearGradient"]     = true,
        ["marker"]             = true,
     -- ["mask"]               = true,
     -- ["metadata"]           = true,
     -- ["missing-glyph"]      = true,
     -- ["mpath"]              = true,
        ["path"]               = true,
     -- ["pattern"]            = true,
        ["polygon"]            = true,
        ["polyline"]           = true,
        ["radialGradient"]     = true,
        ["rect"]               = true,
     -- ["script"]             = true,
     -- ["set"]                = true,
        ["stop"]               = true,
        ["style"]              = true,
        ["svg"]                = true,
     -- ["switch"]             = true,
        ["symbol"]             = true,
        ["text"]               = true,
     -- ["textPath"]           = true,
     -- ["title"]              = true,
        ["tspan"]              = true,
        ["use"]                = true,
     -- ["view"]               = true,
     -- ["vkern"]              = true,
    }

    local function handlechains(c)
        if tags[c.tg] then
            local at = c.at
            local dt = c.dt
            if at and dt then
             -- at["inkscape:connector-curvature"] = nil -- cleare entry and might prevent table growth
                local estyle = rawget(at,"style")
                if estyle and estyle ~= "" then
                    for k, v in gmatch(estyle,"%s*([^:]+):%s*([^;]+);?") do
                        at[k] = v
                    end
                end
                local eclass = rawget(at,"class")
                if eclass and eclass ~= "" then
                    for c in gmatch(eclass,"[^ ]+") do
                        local s = classstyles[c]
                        if s then
                            for k, v in next, s do
                                at[k] = v
                            end
                        end
                    end
                end
                local tstyle = tagstyles[tag]
                if tstyle then
                    for k, v in next, tstyle do
                        at[k] = v
                    end
                end
                if trace_path and pathtracer then
                    for k, v in next, pathtracer do
                        at[k] = v
                    end
                end
                for i=1,#dt do
                    local dti = dt[i]
                    if type(dti) == "table" then
                        handlechains(dti)
                    end
                end
            end
        end
    end

    local handlestyle  do

        -- It can also be CDATA but that is probably dealt with because we only
        -- check for style entries and ignore the rest. But maybe we also need
        -- to check a style at the outer level?

        local p_key   = C((R("az","AZ","09","__","--")^1))
        local p_spec  = P("{") * C((1-P("}"))^1) * P("}")
        local p_valid = Carg(1) * P(".") * p_key + Carg(2) * p_key
        local p_grab  = ((p_valid * p_space^0 * p_spec / rawset) + p_space^1 + P(1))^1

        local fontspecification = css.fontspecification

        handlestyle = function(c)
            local s = xmltext(c)
            lpegmatch(p_grab,s,1,classstyles,tagstyles)
            for k, v in next, classstyles do
                local t = { }
                for k, v in gmatch(v,"%s*([^:]+):%s*([^;]+);?") do
                    if k == "font" then
                        local s = fontspecification(v)
                        for k, v in next, s do
                            t["font-"..k] = v
                        end
                    else
                        t[k] = v
                    end
                end
                classstyles[k] = t
            end
            for k, v in next, tagstyles do
                local t = { }
                for k, v in gmatch(v,"%s*([^:]+):%s*([^;]+);?") do
                    if k == "font" then
                        local s = fontspecification(v)
                        for k, v in next, s do
                            t["font-"..k] = v
                        end
                    else
                        t[k] = v
                    end
                end
                tagstyles[k] = t
            end
        end

        function handlers.style()
            -- ignore
        end

    end

    -- We can have root in definitions and then do a metatable lookup but use
    -- is not used that often I guess.

    local function locate(id)
        local res = definitions[id]
        if res then
            return res
        end
        local ref = gsub(id,"^url%(#(.-)%)$","%1")
        local ref = gsub(ref,"^#","")
        -- we can make a fast id lookup
        local res = xmlfirst(root,"**[@id='"..ref.."']")
        if res then
            definitions[id] = res
        end
        return res
    end

    -- also locate

    local function handleclippath(at)
        local clippath = at["clip-path"]

        if not clippath then
            return
        end

        local spec = definitions[clippath] or locate(clippath)

        -- do we really need thsi crap
        if not spec then
            local index = match(clippath,"(%d+)")
            if index then
                spec = xmlfirst(root,"clipPath["..tostring(tonumber(index) or 0).."]")
            end
        end
        -- so far for the crap

        if not spec then
            report("unknown clip %a",clippath)
            return
        elseif spec.tg ~= "clipPath" then
            report("bad clip %a",clippath)
            return
        end

      ::again::
        for c in xmlcollected(spec,"/(path|use|g)") do
            local tg = c.tg
            if tg == "use" then
                local ca = c.at
                local id = ca["xlink:href"]
                if id then
                    spec = locate(id)
                    if spec then
                        local sa = spec.at
                        setmetatableindex(sa,ca)
                        if spec.tg == "path" then
                            local d = sa.d
                            if d then
                                local p = grabpath(d)
                                p.evenodd = sa["clip-rule"] == "evenodd"
                                p.close = true
                                return p, clippath
                            else
                                return
                            end
                        else
                            goto again
                        end
                    end
                end
             -- break
            elseif tg == "path" then
                local ca = c.at
                local d  = ca.d
                if d then
                    local p = grabpath(d)
                    p.evenodd = ca["clip-rule"] == "evenodd"
                    p.close   = true
                    return p, clippath
                else
                    return
                end
            else
                -- inherit?
            end
        end
    end

    local s_shade_linear   = ' withshademethod "linear" '
    local s_shade_circular = ' withshademethod "circular" '
    local f_shade_step     = formatters['withshadestep ( withshadefraction %N withshadecolors(%s,%s) )']
    local f_shade_one      = formatters['withprescript "sh_center_a=%N %N"']
    local f_shade_two      = formatters['withprescript "sh_center_b=%N %N"']

    local f_color          = formatters['withcolor "%s"']
    local f_opacity        = formatters['withtransparency (1,%N)']
    local f_pen            = formatters['withpen pencircle scaled %N']

    -- todo: gradient unfinished
    -- todo: opacity but first we need groups in mp

    local function gradient(id)
        local spec = definitions[id] -- no locate !
        if spec then
            local kind  = spec.tg
            local shade = nil
            local n     = 1
            local a     = spec.at
            if kind == "linearGradient" then
                shade = { s_shade_linear }
                --
                local x1 = rawget(a,"x1")
                local y1 = rawget(a,"y1")
                local x2 = rawget(a,"x2")
                local y2 = rawget(a,"y2")
                if x1 and y1 then
                    n = n + 1 ; shade[n] = f_shade_one(asnumber_vx(x1),asnumber_vy(y1))
                end
                if x2 and y2 then
                    n = n + 1 ; shade[n] = f_shade_one(asnumber_vx(x2),asnumber_vy(y2))
                end
                --
            elseif kind == "radialGradient" then
                shade = { s_shade_circular }
                --
                local cx = rawget(a,"cx") -- x center
                local cy = rawget(a,"cy") -- y center
                local r  = rawget(a,"r" ) -- radius
                local fx = rawget(a,"fx") -- focal points
                local fy = rawget(a,"fy") -- focal points
                --
                if cx and cy then
                    -- todo
                end
                if r then
                    -- todo
                end
                if fx and fy then
                    -- todo
                end
            else
                report("unknown gradient %a",id)
                return
            end
         -- local gu = a.gradientUnits
         -- local gt = a.gradientTransform
         -- local sm = a.spreadMethod
            local colora, colorb
            -- startcolor ?
            for c in xmlcollected(spec,"/stop") do
                local a       = c.at
                local offset  = rawget(a,"offset")
                local colorb  = rawget(a,"stop-color")
                local opacity = rawget(a,"stop-opacity")
                if colorb then
                    colorb = thecolor(colorb)
                end
                if not colora then
                    colora = colorb
                end
                -- what if no percentage

                local fraction = offset and asnumber_r(offset)
                if not fraction then
                 -- offset = tonumber(offset)
                    -- for now
                    fraction = xmlcount(spec,"/stop")/100
                end

                if colora and colorb and color_a ~= "" and color_b ~= "" then
                    n = n + 1 ; shade[n] = f_shade_step(fraction,colora,colorb)
                end

                colora = colorb
            end
            return concat(shade," ")
        end
    end

    local function drawproperties(stroke,at,opacity)
        local p = at["stroke-width"]
        if p then
            p = f_pen(asnumber_r(p))
        end
        local d = at["stroke-dasharray"]
        if d == "none" then
            d = nil
        elseif d then
            local o = at["stroke-dashoffset"]
            if o and o ~= "none" then
                o = asnumber_r(o)
            else
                o = false
            end
            d = dashed(d,o)
        end
        local c = withcolor(stroke)
        local o = at["stroke-opacity"] or (opacity and at["opacity"])
        if o == "none" then
            o = nil
        elseif o then
            o = asnumber_r(o)
            if o and o ~= 1 then
                o = f_opacity(o)
            else
                o = nil
            end
        end
        return p, d, c, o
    end

    local s_opacity_start = "draw image ("
    local f_opacity_stop  = formatters["setgroup currentpicture to boundingbox currentpicture withtransparency (1,%N)) ;"]

    local function sharedopacity(at)
        local o = at["opacity"]
        if o and o ~= "none" then
            o = asnumber_r(o)
            if o and o ~= 1 then
                return s_opacity_start, f_opacity_stop(o)
            end
        end
    end

    local function fillproperties(fill,at,opacity)
        local c = c ~= "none" and (gradient(fill) or withcolor(fill)) or nil
        local o = at["fill-opacity"] or (opacity and at["opacity"])
        if o and o ~= "none" then
            o = asnumber_r(o)
            if o == 1 then
                return c
            elseif o then
                return c, f_opacity(o), o == 0
            end
        end
        return c
    end

    -- todo: clip = [ auto | rect(llx,lly,urx,ury) ]

    local s_offset_start    = "draw image ( "
    local f_offset_stop     = formatters[") shifted (%N,%N) ;"]
    local s_rotation_start  = "draw image ( "
    local f_rotation_stop   = formatters[") rotatedaround((0,0),-angle((%N,%N))) ;"]
    local f_rotation_angle  = formatters[") rotatedaround((0,0),-%N) ;"]

    local function offset(at)
        local x = asnumber_vx(rawget(at,"x"))
        local y = asnumber_vy(rawget(at,"y"))
        if x ~= 0 or y ~= 0 then
            return s_offset_start, f_offset_stop(x,y)
        end
    end

    local s_viewport_start  = "draw image ("
    local s_viewport_stop   = ") ;"
    local f_viewport_shift  = formatters["currentpicture := currentpicture shifted (%03N,%03N);"]
    local f_viewport_scale  = formatters["currentpicture := currentpicture xysized (%03N,%03N);"]
    local f_viewport_clip   = formatters["clip currentpicture to (unitsquare xyscaled (%03N,%03N));"]

    local function viewport(x,y,w,h,noclip,scale)
        r = r + 1 ; result[r] = s_viewport_start
        return function()
            local okay = w ~= 0 and h ~= 0
            if okay and scale then
                r = r + 1 ; result[r] = f_viewport_scale(w,h)
            end
            if x ~= 0 or y ~= 0 then
                r = r + 1 ; result[r] = f_viewport_shift(-x,y)
            end
            if okay and not noclip then
                r = r + 1 ; result[r] = f_viewport_clip(w,-h)
            end

            r = r + 1 ; result[r] = s_viewport_stop
        end
    end

    -- maybe forget about defs and just always locate (and then backtrack
    -- over <g> if needed)

    function handlers.defs(c)
        for c in xmlcollected(c,"/*") do
            local a = c.at
            if a then
                local id = rawget(a,"id")
                if id then
                    definitions["#"     .. id       ] = c
                    definitions["url(#" .. id .. ")"] = c
                end
            end
        end
    end

    function handlers.symbol(c)
        if uselevel == 0 then
            local id = rawget(c.at,"id")
            if id then
                definitions["#"     .. id       ] = c
                definitions["url(#" .. id .. ")"] = c
            end
        else
            handlers.g(c)
        end
    end

    local uselevel = 0

    function handlers.use(c)
        local at  = c.at
        local id  = rawget(at,"href") or rawget(at,"xlink:href") -- better a rawget
        local res = locate(id)
        if res then
            -- width height ?
            uselevel = uselevel + 1
            local boffset, eoffset = offset(at)
            local btransform, etransform, transform = handletransform(at)

            if boffset then
                r = r + 1 result[r] = boffset
            end

         -- local clippath  = at.clippath

            if btransform then
                r = r + 1 result[r] = btransform
            end

            local _transform = transform
            local _clippath  = clippath
            at["transform"] = false
         -- at["clip-path"] = false

            process(res,"/*")

            at["transform"] = _transform
         -- at["clip-path"] = _clippath

            if etransform then
                r = r + 1 ; result[r] = etransform
            end

            if eoffset then
                r = r + 1 result[r] = eoffset
            end

            uselevel = uselevel - 1
        else
            report("use: unknown definition %a",id)
        end
    end

    local f_no_draw       = formatters['nodraw (%s)']
    local f_do_draw       = formatters['draw (%s)']
    local f_no_fill_c     = formatters['nofill (%s..cycle)']
    local f_do_fill_c     = formatters['fill (%s..cycle)']
    local f_eo_fill_c     = formatters['eofill (%s..cycle)']
    local f_no_fill_l     = formatters['nofill (%s--cycle)']
    local f_do_fill_l     = formatters['fill (%s--cycle)']
    local f_eo_fill_l     = formatters['eofill (%s--cycle)']
    local f_do_fill       = f_do_fill_c
    local f_eo_fill       = f_eo_fill_c
    local f_no_fill       = f_no_fill_c
    local s_clip_start    = 'draw image ('
    local f_clip_stop_c   = formatters[') ; clip currentpicture to (%s..cycle) ;']
    local f_clip_stop_l   = formatters[') ; clip currentpicture to (%s--cycle) ;']
    local f_clip_stop     = f_clip_stop_c
    local f_eoclip_stop_c = formatters[') ; eoclip currentpicture to (%s..cycle) ;']
    local f_eoclip_stop_l = formatters[') ; eoclip currentpicture to (%s--cycle) ;']
    local f_eoclip_stop   = f_eoclip_stop_c

    -- could be shared and then beginobject | endobject

    local function flushobject(object,at,c,o)
        local btransform, etransform = handletransform(at)
        local cpath = handleclippath(at)

        if cpath then
            r = r + 1 ; result[r] = s_clip_start
        end

        if btransform then
            r = r + 1 ; result[r] = btransform
        end

        r = r + 1 ; result[r] = f_do_draw(object)

        if c then
            r = r + 1 ; result[r] = c
        end

        if o then
            r = r + 1 ; result[r] = o
        end

        if etransform then
            r = r + 1 ; result[r] = etransform
        end

        r = r + 1 ; result[r] = ";"

        if cpath then
            local f_done = cpath.evenodd
            if cpath.curve then
                f_done = f_done and f_eoclip_stop_c or f_clip_stop_c
            else
                f_done = f_done and f_eoclip_stop_l or f_clip_stop_l
            end
            r = r + 1 ; result[r] = f_done(cpath[1])
        end
    end

    do

        local flush

        local f_linecap    = formatters["interim linecap := %s ;"]
        local f_linejoin   = formatters["interim linejoin := %s ;"]
        local f_miterlimit = formatters["interim miterlimit := %s ;"]

        local s_begingroup = "begingroup;"
        local s_endgroup   = "endgroup;"

        local linecaps  = { butt  = "butt",    square = "squared", round = "rounded" }
        local linejoins = { miter = "mitered", bevel  = "beveled", round = "rounded" }

        local function startlineproperties(at)
            local cap   = at["stroke-linecap"]
            local join  = at["stroke-linejoin"]
            local limit = at["stroke-miterlimit"]
            cap   = cap   and linecaps [cap]
            join  = join  and linejoins[join]
            limit = limit and asnumber_r(limit)
            if cap or join or limit then
                r = r + 1 ; result[r] = s_begingroup
                if cap then
                    r = r + 1 ; result[r] = f_linecap(cap)
                end
                if join then
                    r = r + 1 ; result[r] = f_linejoin(join)
                end
                if limit then
                    r = r + 1 ; result[r] = f_miterlimit(limit)
                end
                return function()
                    at["stroke-linecap"]    = false
                    at["stroke-linejoin"]   = false
                    at["stroke-miterlimit"] = false
                    r = r + 1 ; result[r] = s_endgroup
                    at["stroke-linecap"]    = cap
                    at["stroke-linejoin"]   = join
                    at["stroke-miterlimit"] = limit
                end
            end
        end

        -- markers are a quite rediculous thing .. let's assume simple usage for now

        function handlers.marker()
            -- todo: is just a def too
        end

        -- kind of local svg ... so make a generic one
        --
        -- todo: combine more (offset+scale+rotation)

        local function makemarker(where,c,x1,y1,x2,y2,x3,y3)
            local at     = c.at
            local refx   = rawget(at,"refX")
            local refy   = rawget(at,"refY")
            local width  = rawget(at,"markerWidth")
            local height = rawget(at,"markerHeight")
            local view   = rawget(at,"viewBox")
            local orient = rawget(at,"orient")
         -- local ratio  = rawget(at,"preserveAspectRatio")
            local units  = at["markerUnits"]
            local height = at["markerHeight"]
            local angx   = 0
            local angy   = 0
            local angle  = 0

            if where == "beg" then
                if orient == "auto" then -- unchecked
                    -- no angle
                    angx = x2 - x3
                    angy = y2 - y3
                elseif orient == "auto-start-reverse" then -- checked
                    -- points to start
                    angx = x3 - x2
                    angy = y3 - y2
                elseif orient then -- unchecked
                    angle = asnumber_r(orient)
                end
            elseif where == "end" then
                if orient == "auto" then -- unchecked
                    -- no angle ?
                    angx = x1 - x2
                    angy = y1 - y2
                elseif orient == "auto-start-reverse" then -- unchecked
                    -- points to end
                    angx = x2 - x1
                    angy = y2 - y1
                elseif orient then -- unchecked
                    angle = asnumber_r(orient)
                end
            elseif orient then -- unchecked
                angle = asnumber_r(orient)
            end

            -- what wins: viewbox or w/h

            refx = asnumber_x(refx)
            refy = asnumber_y(refy)

            width  = width  and asnumber_x(width)  or 3 -- defaults
            height = height and asnumber_y(height) or 3 -- defaults

            local x = 0
            local y = 0
            local w = width
            local h = height

            -- kind of like the main svg

            r = r + 1 ; result[r] = s_offset_start

            local wrapupviewport
-- todo : better viewbox code
            local xpct, ypct, rpct
            if view then
                x, y, w, h = handleviewbox(view)
            end

            if width ~= 0 then
                w = width
            end
            if height ~= 0 then
                h = height
            end

            if h then
                xpct           = percentage_x
                ypct           = percentage_y
                rpct           = percentage_r
                percentage_x   = w / 100
                percentage_y   = h / 100
                percentage_r   = (sqrt(w^2 + h^2) / sqrt(2)) / 100
                wrapupviewport = viewport(x,y,w,h,true,true) -- no clip
            end

            -- we can combine a lot here:

            local hasref = refx ~= 0 or refy ~= 0
            local hasrot = angx ~= 0 or angy ~= 0 or angle ~= 0

            local btransform, etransform, transform = handletransform(at)

            if btransform then
                r = r + 1 ; result[r] = btransform
            end

            if hasrot then
                r = r + 1 ; result[r] = s_rotation_start
            end

            if hasref then
                r = r + 1 ; result[r] = s_offset_start
            end

            local _transform = transform
            at["transform"] = false

            handlers.g(c)

            at["transform"] = _transform

            if hasref then
                r = r + 1 ; result[r] = f_offset_stop(-refx,refy)
            end

            if hasrot then
                if angle ~= 0 then
                    r = r + 1 ; result[r] = f_rotation_angle(angle)
                else
                    r = r + 1 ; result[r] = f_rotation_stop(angx,angy)
                end
            end

            if etransform then
                r = r + 1 ; result[r] = etransform
            end

            if h then
                percentage_x = xpct
                percentage_y = ypct
                percentage_r = rpct
                if wrapupviewport then
                    wrapupviewport()
                end
            end
            r = r + 1 ; result[r] = f_offset_stop(x2,y2)

        end

        local function addmarkers(list,begmarker,midmarker,endmarker)
            local n = #list
            if n > 3 then
                if begmarker then
                    local m = locate(begmarker)
                    if m then
                        makemarker("beg",m,false,false,list[1],list[2],list[3],list[4])
                    end
                end
                if midmarker then
                    local m = locate(midmarker)
                    if m then
                        for i=3,n-2,2 do
                            makemarker("mid",m,list[i-2],list[i-1],list[i],list[i+1],list[i+2],list[i+3])
                        end
                    end
                end
                if endmarker then
                    local m = locate(endmarker)
                    if m then
                        makemarker("end",m,list[n-3],list[n-2],list[n-1],list[n],false,false)
                    end
                end
            else
                -- no line
            end
        end

        local function flush(shape,dofill,at,list,begmarker,midmarker,endmarker)

            local fill   = dofill and (at["fill"] or "black")
            local stroke = at["stroke"] or "none"

            local btransform, etransform = handletransform(at)
            local cpath = handleclippath(at)

            if cpath then
                r = r + 1 ; result[r] = s_clip_start
            end

            local has_stroke = stroke and stroke ~= "none"
            local has_fill   = fill and fill ~= "none"

            local bopacity, eopacity
            if has_stroke and has_fill then
                bopacity, eopacity = sharedopacity(at)
            end

            if bopacity then
                r = r + 1 ; result[r] = bopacity
            end

            if has_fill then
                local color, opacity = fillproperties(fill,at,not has_stroke)
                local f_xx_fill = at["fill-rule"] == "evenodd" and f_eo_fill or f_do_fill
                if btransform then
                    r = r + 1 ; result[r] = btransform
                end
                r = r + 1 result[r] = f_xx_fill(shape)
                if color   then
                    r = r + 1 ; result[r] = color
                end
                if opacity then
                    r = r + 1 ; result[r] = opacity
                end
                r = r + 1 ; result[r] = etransform or ";"
            end

            if has_stroke then
                local wrapup = startlineproperties(at)
                local pen, dashing, color, opacity = drawproperties(stroke,at,not has_fill)
                if btransform then
                    r = r + 1 ; result[r] = btransform
                end
                r = r + 1 ; result[r] = f_do_draw(shape)
                if pen     then
                    r = r + 1 ; result[r] = pen
                end
                if dashing then
                    r = r + 1 ; result[r] = dashing
                end
                if color then
                    r = r + 1 ; result[r] = color
                end
                if opacity then
                    r = r + 1 ; result[r] = opacity
                end
                r = r + 1 ; result[r] = etransform or ";"
                --
                if list then
                    addmarkers(list,begmarker,midmarker,endmarker)
                end
                --
                if wrapup then
                    wrapup()
                end
            end

            if eopacity then
                r = r + 1 ; result[r] = eopacity
            end

            if cpath then
                r = r + 1 ; result[r] = (cpath.evenodd and f_eoclip_stop or f_clip_stop)(cpath[1])
            end

        end

        local f_rectangle = formatters['unitsquare xyscaled (%N,%N) shifted (%N,%N)']
        local f_rounded   = formatters['roundedsquarexy(%N,%N,%N,%N) shifted (%N,%N)']
        local f_line      = formatters['((%N,%N)--(%N,%N))']
        local f_ellipse   = formatters['(fullcircle xyscaled (%N,%N) shifted (%N,%N))']
        local f_circle    = formatters['(fullcircle scaled %N shifted (%N,%N))']

        function handlers.line(c)
            local at = c.at
            local x1 = rawget(at,"x1")
            local y1 = rawget(at,"y1")
            local x2 = rawget(at,"x2")
            local y2 = rawget(at,"y2")

            x1 = x1 and asnumber_vx(x1) or 0
            y1 = y1 and asnumber_vy(y1) or 0
            x2 = x2 and asnumber_vx(x2) or 0
            y2 = y2 and asnumber_vy(y2) or 0

            flush(f_line(x1,y1,x2,y2),false,at)
        end

        function handlers.rect(c)
            local at     = c.at
            local width  = rawget(at,"width")
            local height = rawget(at,"height")
            local x      = rawget(at,"x")
            local y      = rawget(at,"y")
            local rx     = rawget(at,"rx")
            local ry     = rawget(at,"ry")

            width  = width  and asnumber_x(width)  or 0
            height = height and asnumber_y(height) or 0
            x      = x      and asnumber_vx(x) or 0
            y      = y      and asnumber_vy(y) or 0

            y      = y - height

            if rx then rx = asnumber(rx) end
            if ry then ry = asnumber(ry) end

            if rx or ry then
                if not rx then rx = ry end
                if not ry then ry = rx end
                flush(f_rounded(width,height,rx,ry,x,y),true,at)
            else
                flush(f_rectangle(width,height,x,y),true,at)
            end
        end

        function handlers.ellipse(c)
            local at = c.at
            local cx = rawget(at,"cx")
            local cy = rawget(at,"cy")
            local rx = rawget(at,"rx")
            local ry = rawget(at,"ry")

            cx = cx and asnumber_vx(cx) or 0
            cy = cy and asnumber_vy(cy) or 0
            rx = rx and asnumber_r (rx) or 0
            ry = ry and asnumber_r (ry) or 0

            flush(f_ellipse(2*rx,2*ry,cx,cy),true,at)
        end

        function handlers.circle(c)
            local at = c.at
            local cx = rawget(at,"cx")
            local cy = rawget(at,"cy")
            local r  = rawget(at,"r")

            cx = cx and asnumber_vx(cx) or 0
            cy = cy and asnumber_vy(cy) or 0
            r  = r  and asnumber_r (r)  or 0

            flush(f_circle(2*r,cx,cy),true,at)
        end

        local f_lineto_z  = formatters['(%N,%N)']
        local f_lineto_n  = formatters['--(%N,%N)']

        local p_pair     = p_optseparator * p_number_vx * p_optseparator * p_number_vy
        local p_open     = Cc("(")
        local p_close    = Carg(1) * P(true) / function(s) return s end
        local p_polyline = Cs(p_open * (p_pair / f_lineto_z) * (p_pair / f_lineto_n)^0 * p_close)
        local p_polypair = Ct(p_pair^0)

        local function poly(c,final)
            local at     = c.at
            local points = rawget(at,"points")
            if points then
                local path = lpegmatch(p_polyline,points,1,final)
                local list = nil
                local begmarker = rawget(at,"marker-start")
                local midmarker = rawget(at,"marker-mid")
                local endmarker = rawget(at,"marker-end")
                if begmarker or midmarker or endmarker then
                    list = lpegmatch(p_polypair,points)
                end
                flush(path,true,at,list,begmarker,midmarker,endmarker)
            end
        end

        function handlers.polyline(c) poly(c,       ")") end
        function handlers.polygon (c) poly(c,"--cycle)") end

        local s_image_start = "draw image ("
        local s_image_stop  = ") ;"

        function handlers.path(c)
            local at = c.at
            local d  = rawget(at,"d")
            if d then
                local shape, l = grabpath(d)
                local fill     = at["fill"] or "black"
                local stroke   = at["stroke"] or "none"
                local n        = #shape

                local btransform, etransform = handletransform(at)
                local cpath = handleclippath(at)

                if cpath then
                    r = r + 1 ; result[r] = s_clip_start
                end

                -- todo: image (nicer for transform too)

                if fill and fill ~= "none" then
                    local color, opacity = fillproperties(fill,at)
                    local f_xx_fill = at["fill-rule"] == "evenodd"
                    if shape.closed then
                        f_xx_fill = f_xx_fill and f_eo_fill   or f_do_fill
                    elseif shape.curve then
                        f_xx_fill = f_xx_fill and f_eo_fill_c or f_do_fill_c
                    else
                        f_xx_fill = f_xx_fill and f_eo_fill_l or f_do_fill_l
                    end
                    if n == 1 then
                        if btransform then
                            r = r + 1 ; result[r] = btransform
                        end
                        r = r + 1 result[r] = f_xx_fill(shape[1])
                        if color then
                            r = r + 1 ; result[r] = color
                        end
                        if opacity then
                            r = r + 1 ; result[r] = opacity
                        end
                        r = r + 1 ; result[r] = etransform or ";"
                    else
                        r = r + 1 ; result[r] = btransform or s_image_start
                        for i=1,n do
                            if i == n then
                                r = r + 1 ; result[r] = f_xx_fill(shape[i])
                                if color then
                                    r = r + 1 ; result[r] = color
                                end
                                if opacity then
                                    r = r + 1 ; result[r] = opacity
                                end
                            else
                                r = r + 1 ; result[r] = f_no_fill(shape[i])
                            end
                            r = r + 1 ; result[r] = ";"
                        end
                        r = r + 1 ; result[r] = etransform or s_image_stop
                    end
                end

                if stroke and stroke ~= "none" then
                    local begmarker = rawget(at,"marker-start")
                    local midmarker = rawget(at,"marker-mid")
                    local endmarker = rawget(at,"marker-end")
                    if begmarker or midmarker or endmarker then
                        list = grablist(l)
                    end
                    local wrapup = startlineproperties(at)
                    local pen, dashing, color, opacity = drawproperties(stroke,at)
                    if n == 1 and not list then
                        if btransform then
                            r = r + 1 ; result[r] = btransform
                        end
                        r = r + 1 result[r] = f_do_draw(shape[1])
                        if pen then
                            r = r + 1 ; result[r] = pen
                        end
                        if dashing then
                            r = r + 1 ; result[r] = dashing
                        end
                        if color then
                            r = r + 1 ; result[r] = color
                        end
                        if opacity then
                            r = r + 1 ; result[r] = opacity
                        end
                        r = r + 1 result[r] = etransform or ";"
                    else
                        r = r + 1 result[r] = btransform or "draw image ("
                        for i=1,n do
                            r = r + 1 result[r] = f_do_draw(shape[i])
                            if pen then
                                r = r + 1 ; result[r] = pen
                            end
                            if dashing then
                                r = r + 1 ; result[r] = dashing
                            end
                            if color then
                                r = r + 1 ; result[r] = color
                            end
                            if opacity then
                                r = r + 1 ; result[r] = opacity
                            end
                            r = r + 1 ; result[r] = ";"
                        end
                        if list then
                            addmarkers(list,begmarker,midmarker,endmarker)
                        end
                        r = r + 1 ; result[r] = etransform or ") ;"
                    end
                    if wrapup then
                        wrapup()
                    end
                end

                if cpath then
                    r = r + 1 ; result[r] = f_clip_stop(cpath[1])
                end

            end
        end

    end

    -- kind of special

    do

        -- some day:
        --
        -- specification = identifiers.jpg(data."string")
        -- specification.data = data
        -- inclusion takes from data
        -- specification.data = false

        local f_image = formatters[ [[figure("%s") xysized (%N,%N) shifted (%N,%N)]] ]

        local nofimages = 0

        function handlers.image(c)
            local at = c.at
            local im = rawget(at,"xlink:href")
            if im then
                local kind, data = match(im,"^data:image/([a-z]+);base64,(.*)$")
                if kind == "png" then
                    -- ok
                elseif kind == "jpeg" then
                    kind = "jpg"
                else
                    kind = false
                end
                if kind and data then
                    local w  = rawget(at,"width")
                    local h  = rawget(at,"height")
                    local x  = rawget(at,"x")
                    local y  = rawget(at,"y")
                    w = w and asnumber_x(w)
                    h = h and asnumber_y(h)
                    x = x and asnumber_vx(x) or 0
                    y = y and asnumber_vy(y) or 0
                    nofimages = nofimages + 1
                    local name = "temp-svg-image-" .. nofimages .. "." .. kind
                    local data = mime.decode("base64")(data)
                    io.savedata(name,data)
                    if not w or not h then
                        local info = graphics.identifiers[kind](data,"string")
                        if info then
                            -- todo: keep aspect ratio attribute
                            local xsize = info.xsize
                            local ysize = info.ysize
                            if not w then
                                if not h then
                                    w = xsize
                                    h = ysize
                                else
                                    w = (h / ysize) * xsize
                                end
                            else
                                h = (w / xsize) * ysize
                            end
                        end
                    end
                    -- safeguard:
                    if not w then w = h or 1 end
                    if not h then h = w or 1 end
                    luatex.registertempfile(name)
                    -- done:
                    flushobject(f_image(name,w,h,x,y - h),at)
                else
                    -- nothing done
                end
            end
        end

    end

    -- these transform: g a text svg symbol

    do

        function handlers.a(c)
            process(c,"/*")
        end

        function handlers.g(c) -- much like flushobject so better split and share
            local at = c.at

            local btransform, etransform, transform = handletransform(at)
            local cpath, clippath = handleclippath(at)

            if cpath then
                r = r + 1 ; result[r] = s_clip_start
            end

            if btransform then
                r= r + 1 result[r] = btransform
            end

            local _transform = transform
            local _clippath  = clippath
            at["transform"] = false
            at["clip-path"] = false

            process(c,"/*")

            at["transform"] = _transform
            at["clip-path"] = _clippath

            if etransform then
                r = r + 1 ; result[r] = etransform
            end

            if cpath then
                local f_done = cpath.evenodd
                if cpath.curve then
                    f_done = f_done and f_eoclip_stop_c or f_clip_stop_c
                else
                    f_done = f_done and f_eoclip_stop_l or f_clip_stop_l
                end
                r = r + 1 ; result[r] = f_done(cpath[1])
            end
        end

        -- this will never really work out
        --
        -- todo: register text in lua in mapping with id, then draw mapping unless overloaded
        --       using lmt_svglabel with family,style,weight,size,id passed

        -- nested tspans are messy: they can have displacements but in inkscape we also
        -- see x and y (inner and outer element)

        -- The size is a bit of an issue. I assume that the specified size relates to the
        -- designsize but we want to be able to use other fonts.

        do

            local f_styled  = formatters["\\svgstyled{%s}{%s}{%s}{%s}"]
            local f_colored = formatters["\\svgcolored{%.3N}{%.3N}{%.3N}{"]
            local f_placed  = formatters["\\svgplaced{%.3N}{%.3N}{}{"]
            local f_poschar = formatters["\\svgposchar{%.3N}{%.3N}{%s}"]
            local f_char    = formatters["\\svgchar{%s}"]

            local f_scaled  = formatters["\\svgscaled{%N}{%s}{%s}{%s}"]
            local f_normal  = formatters["\\svgnormal{%s}{%s}{%s}"]

            -- We move to the outer (x,y) and when we have an inner offset we
            -- (need to) compensate for that outer offset.

         -- local f_text_scaled_svg = formatters['(svgtext("%s") scaled %N shifted (%N,%N))']
         -- local f_text_normal_svg = formatters['(svgtext("%s") shifted (%N,%N))']
         -- local f_text_simple_svg = formatters['svgtext("%s")']

            local f_text_normal_svg   = formatters['(textext.drt("%s") shifted (%N,%N))']
            local f_text_simple_svg   = formatters['textext.drt("%s")']

            -- or just maptext

            local f_mapped_normal_svg = formatters['(svgtext("%s") shifted (%N,%N))']
            local f_mapped_simple_svg = formatters['svgtext("%s")']

            local cssfamily  = css.family
            local cssstyle   = css.style
            local cssweight  = css.weight
            local csssize    = css.size

            local usedfonts  = setmetatableindex(function(t,k)
                local v = setmetatableindex("table")
                t[k] = v
                return v
            end)

            local p_texescape = lpegpatterns.texescape

            -- For now as I need it for my (some 1500) test files.

            local function checkedfamily(name)
                if find(name,"^.-verdana.-$") then
                    name = "verdana"
                end
                return name
            end

            -- todo: only escape some chars and handle space

            local defaultsize = 10

            local function collect(t,c,x,y,size,scale,family,tx,ty)
                local at       = c.at
                local ax       = rawget(at,"x")
                local ay       = rawget(at,"y")
                local dx       = rawget(at,"dx")
                local dy       = rawget(at,"dy")
                local v_fill   = at["fill"]
                local v_family = at["font-family"]
                local v_style  = at["font-style"]
                local v_weight = at["font-weight"]
                local v_size   = at["font-size"]
                --
                ax = ax and asnumber_vx(ax) or x
                ay = ay and asnumber_vy(ay) or y
                dx = dx and asnumber_vx(dx) or 0
                dy = dy and asnumber_vy(dy) or 0
                --
                if v_family then v_family = cssfamily(v_family) end
                if v_style  then v_style  = cssstyle (v_style)  end
                if v_weight then v_weight = cssweight(v_weight) end
                if v_size   then v_size   = csssize  (v_size,factors) end
                --
                ax = ax - x
                ay = ay - y
                --
                local elayered = ax ~= 0 or ay ~= 0 or false
                local eplaced  = dx ~= 0 or dy ~= 0 or false

                local usedsize, usedscaled

                if elayered then
                    -- we're now at the outer level again so we need to scale
                    -- back to the outer level values
                    t[#t+1] = formatters["\\svgsetlayer{%0N}{%0N}{"](ax,-ay)
                    usedsize  = v_size or defaultsize
                    usedscale = usedsize / defaultsize
                else
                    -- we're nested so we can be scaled
                    usedsize  = v_size or size
                    usedscale = (usedsize / defaultsize) / scale
                end
                --
                -- print("element       ",c.tg)
                -- print("  layered     ",elayered)
                -- print("  font   size ",v_size)
                -- print("  parent size ",size)
                -- print("  parent scale",scale)
                -- print("  used size   ",usedsize)
                -- print("  used scale  ",usedscale)
                --
                if eplaced then
                    t[#t+1] = f_placed(dx,dy)
                end
                --
                if not v_family then v_family = family   end
                if not v_weight then v_weight = "normal" end
                if not v_style  then v_style  = "normal" end
                --
                if v_family then
                    v_family = fonts.names.cleanname(v_family)
                    v_family = checkedfamily(v_family)
                end
                --
                usedfonts[v_family][v_weight][v_style] = true
                --
--                 if usedscale == 1 then
--                     t[#t+1] = f_normal(          v_family,v_weight,v_style)
--                 else
                    t[#t+1] = f_scaled(usedscale,v_family,v_weight,v_style)
--                 end
                t[#t+1] = "{"
                --
                local ecolored = v_fill and v_fill ~= "" or false
                if ecolored then
                    -- todo
                    local r, g, b = rgbcomponents(v_fill)
                    if r and g and b then
                        t[#t+1] = f_colored(r,g,b)
                    else
                        ecolored = false
                    end
                end
                --
                local dt = c.dt
                local nt = #dt
                for i=1,nt do
                    local di = dt[i]
                    if type(di) == "table" then
                        -- can be a tspan (should we pass dx too)
                        collect(t,di,x,y,usedsize,usedscale,v_family)
                    else
                        if i == 1 then
                            di = gsub(di,"^%s+","")
                        end
                        if i == nt then
                            di = gsub(di,"%s+$","")
                        end
                        local chars = utfsplit(di)
                        if tx then
                            for i=1,#chars do
                                chars[i] = f_poschar(
                                    (tx[i] or 0) - x,
                                    (ty[i] or 0) - y,
                                    utfbyte(chars[i])
                                )
                            end
                            di = "{" .. concat(chars) .. "}"
                        else
                            -- this needs to be texescaped ! and even quotes and newlines
                            -- or we could register it but that's a bit tricky as we nest
                            -- and don't know what we can expect here
                         -- di = lpegmatch(p_texescape,di) or di
                            for i=1,#chars do
                                chars[i] = f_char(utfbyte(chars[i]))
                            end
                            di = concat(chars)
                        end
                        t[#t+1] = di
                    end
                end
                --
                if ecolored then
                    t[#t+1] = "}"
                end
                --
                t[#t+1] = "}"
                --
                if eplaced then
                    t[#t+1] = "}"
                end
                if elayered then
                    t[#t+1] = "}"
                end
                --
                return t
            end

            local s_startlayer = "\\svgstartlayer "
            local s_stoplayer  = "\\svgstoplayer "

            function handlers.text(c)
                local only = fullstrip(xmltextonly(c))
             -- if metapost.processing() then
                    local at = c.at
                    local x  = rawget(at,"x")
                    local y  = rawget(at,"y")

                    local tx = asnumber_vx_t(x)
                    local ty = asnumber_vy_t(y)

                    x = tx[1] or 0 -- catch bad x/y spec
                    y = ty[1] or 0 -- catch bad x/y spec

                    local v_fill = at["fill"]
                    if not v_fill or v_fill == "none" then
                        v_fill = "black"
                    end
                    local color, opacity, invisible = fillproperties(v_fill,at)
                    local r = metapost.remappedtext(only)
                    if r then
                        if x == 0 and y == 0 then
                            only = f_mapped_simple_svg(r.index)
                        else
                            only = f_mapped_normal_svg(r.index,x,y)
                        end
                        flushobject(only,at,color,opacity)
                        if trace_text then
                            report("text: %s",only)
                        end
                    elseif not invisible then -- can be an option
                        local scale  = 1
                        local textid = 0
                        local result = { }
                        local nx     = #tx
                        local ny     = #ty
                        --
                        result[#result+1] = s_startlayer
                        if nx > 1 or ny > 1 then
                            concat(collect(result,c,x,y,defaultsize,1,"serif",tx,ty))
                        else
                            concat(collect(result,c,x,y,defaultsize,1,"serif"))
                        end
                        result[#result+1] = s_stoplayer
                        result = concat(result)
                        if x == 0 and y == 0 then
                            result = f_text_simple_svg(result)
                        else
                            result = f_text_normal_svg(result,x,y)
                        end
                        flushobject(result,at,color,opacity)
                        if trace_text then
                            report("text: %s",result)
                        end
                    elseif trace_text then
                        report("invisible text: %s",only)
                    end
             -- elseif trace_text then
             --     report("ignored text: %s",only)
             -- end
            end

            function metapost.reportsvgfonts()
                for family, weights in sortedhash(usedfonts) do
                    for weight, styles in sortedhash(weights) do
                        for style in sortedhash(styles) do
                            report("used font: %s-%s-%s",family,weight,style)
                        end
                    end
                end
            end

            statistics.register("used svg fonts",function()
                if next(usedfonts) then
                    -- also in log file
                    logs.startfilelogging(report,"used svg fonts")
                    local t = { }
                    for family, weights in sortedhash(usedfonts) do
                        for weight, styles in sortedhash(weights) do
                            for style in sortedhash(styles) do
                                report("%s-%s-%s",family,weight,style)
                                t[#t+1] = formatters["%s-%s-%s"](family,weight,style)
                            end
                        end
                    end
                    logs.stopfilelogging()
                    return concat(t," ")
                end
            end)

        end

        function handlers.svg(c,x,y,w,h,noclip,notransform,normalize,usetextindex)
            local at      = c.at

            local wrapupviewport
            local bhacked
            local ehacked
            local wd = w
         -- local ex, em
            local xpct, ypct, rpct

            local btransform, etransform, transform = handletransform(at)

            if trace then
                report("view: %s, xpct %N, ypct %N","before",percentage_x,percentage_y)
            end

            local viewbox = at.viewBox

            if viewbox then
                x, y, w, h = handleviewbox(viewbox)
                if trace then
                    report("viewbox: x %N, y %N, width %N, height %N",x,y,w,h)
                end
            end
            if not w or not h or w == 0 or h == 0 then
                noclip = true
            end
            if h then
                --
             -- em = factors["em"]
             -- ex = factors["ex"]
             -- factors["em"] = em
             -- factors["ex"] = ex
                --
                xpct = percentage_x
                ypct = percentage_y
                rpct = percentage_r
                percentage_x = w / 100
                percentage_y = h / 100
                percentage_r = (sqrt(w^2 + h^2) / sqrt(2)) / 100
                if trace then
                    report("view: %s, xpct %N, ypct %N","inside",percentage_x,percentage_y)
                end
                wrapupviewport = viewport(x,y,w,h,noclip)
            end
            -- todo: combine transform and offset here

            -- some fonts need this (bad transforms + viewbox)
            if v and normalize and w and wd and w ~= wd and w > 0 and wd > 0 then
                bhacked = s_wrapped_start
                ehacked = f_wrapped_stop(y or 0,wd/w)
            end
            if btransform then
                r = r + 1 ; result[r] = btransform
            end
            if bhacked then
                r = r + 1 ; result[r] = bhacked
            end
            local boffset, eoffset = offset(at)
            if boffset then
                r = r + 1 result[r] = boffset
            end
            textindex    = usetextindex and 0 or false

            at["transform"] = false
            at["viewBox"]   = false

            process(c,"/*")

            at["transform"] = transform
            at["viewBox"]   = viewbox

            if eoffset then
                r = r + 1 result[r] = eoffset
            end
            if ehacked then
                r = r + 1 ; result[r] = ehacked
            end
            if etransform then
                r = r + 1 ; result[r] = etransform
            end
            if h then
                --
             -- factors["em"] = em
             -- factors["ex"] = ex
                --
                percentage_x = xpct
                percentage_y = ypct
                percentage_r = rpct
                if wrapupviewport then
                    wrapupviewport()
                end
            end
            if trace then
                report("view: %s, xpct %N, ypct %N","after",percentage_x,percentage_y)
            end
        end

    end

    process = function(x,p)
        for c in xmlcollected(x,p) do
            local tg = c.tg
            local h  = handlers[c.tg]
            if h then
                h(c)
            end
        end
    end

    -- For huge inefficient files there can be lots of garbage to collect so
    -- maybe we should run the collector when a file is larger than say 50K.

    function metapost.svgtomp(specification,pattern,notransform,normalize)
        local mps = ""
        local svg = specification.data
        if type(svg) == "string" then
            svg = xmlconvert(svg)
        end
        if svg then
            local c = xmlfirst(svg,pattern or "/svg")
            if c then
                root        = svg
                result      = { }
                r           = 0
                definitions = { }
                tagstyles   = { }
                classstyles = { }
                for s in xmlcollected(c,"/style") do
                    handlestyle(c)
                end
                handlechains(c)
                xmlinheritattributes(c) -- put this in handlechains
                handlers.svg (
                    c,
                    specification.x,
                    specification.y,
                    specification.width,
                    specification.height,
                    specification.noclip,
                    notransform,
                    normalize,
                    specification.remap
                )
                if trace_result then
                    report("result graphic:\n    %\n    t",result)
                end
                mps = concat(result," ")
                root, result, r, definitions, styles = false, false, false, false, false
            else
                report("missing svg root element")
            end
        else
            report("bad svg blob")
        end
        return mps
    end

end

-- These helpers might move to their own module .. some day ... also they will become
-- a bit more efficient, because we now go to mp and back which is kind of redundant,
-- but for now it will do.

function metapost.includesvgfile(filename,offset) -- offset in sp
    if lfs.isfile(filename) then
        context.startMPcode("doublefun")
            context('draw lmt_svg [ filename = "%s", offset = %N ] ;',filename,(offset or 0)*bpfactor)
        context.stopMPcode()
    end
end

function metapost.includesvgbuffer(name,offset) -- offset in sp
    context.startMPcode("doublefun")
        context('draw lmt_svg [ buffer = "%s", offset = %N ] ;',name or "",(offset or 0)*bpfactor)
    context.stopMPcode()
end

interfaces.implement {
    name      = "includesvgfile",
    actions   = metapost.includesvgfile,
    arguments = { "string", "dimension" },
}

interfaces.implement {
    name      = "includesvgbuffer",
    actions   = metapost.includesvgbuffer,
    arguments = { "string", "dimension" },
}

function metapost.showsvgpage(data)
    local dd = data.data
    if not dd then
        local fn = data.filename
        dd = fn and table.load(fn)
    end
    if type(dd) == "table" then
        local comment = data.comment
        local offset  = data.pageoffset
        local index   = data.index
        local first   = math.max(index or 1,1)
        local last    = math.min(index or #dd,#dd)
        for i=first,last do
            local d = setmetatableindex( {
                data       = dd[i],
                comment    = comment and i or false,
                pageoffset = offset or nil,
            }, data)
            metapost.showsvgpage(d)
        end
    elseif data.method == "code" then
        context.startMPcode(doublefun)
            context(metapost.svgtomp(data))
        context.stopMPcode()
    else
        context.startMPpage { instance = "doublefun", offset = data.pageoffset or nil }
            context(metapost.svgtomp(data))
            local comment = data.comment
            if comment then
                context("draw boundingbox currentpicture withcolor .6red ;")
                context('draw textext.bot("\\strut\\tttf %s") ysized (10pt) shifted center bottomboundary currentpicture ;',comment)
            end
        context.stopMPpage()
    end
end

function metapost.typesvgpage(data)
    local dd = data.data
    if not dd then
        local fn = data.filename
        dd = fn and table.load(fn)
    end
    if type(dd) == "table" then
        local index = data.index
        if index and index > 0 and index <= #dd then
            data = dd[index]
        else
            data = nil
        end
    end
    if type(data) == "string" and data ~= "" then
        buffers.assign("svgpage",data)
        context.typebuffer ({ "svgpage" }, { option = "XML", strip = "yes" })
    end
end

function metapost.svgtopdf(data,...)
    local mps = metapost.svgtomp(data,...)
    if mps then
        -- todo: special instance, only basics needed
        local pdf = metapost.simple("metafun",mps,true,false,"svg")
        if pdf then
            return pdf
        else
            -- message
        end
    else
        -- message
    end
end

do

    local runner = sandbox.registerrunner {
        name     = "otfsvg2pdf",
        program  = "context",
        template = "--batchmode --purgeall --runs=2 %filename%",
        reporter = report_svg,
    }

    -- By using an independent pdf file instead of pdf streams we can use resources and still
    -- cache. This is the old method updated. Maybe a future version will just do this runtime
    -- but for now this is the most efficient method.

    local decompress = gzip.decompress
    local compress   = gzip.compress

    function metapost.svgshapestopdf(svgshapes,pdftarget,report_svg)
        local texname   = "temp-otf-svg-to-pdf.tex"
        local pdfname   = "temp-otf-svg-to-pdf.pdf"
        local tucname   = "temp-otf-svg-to-pdf.tuc"
        local nofshapes = #svgshapes
        local pdfpages  = { filename = pdftarget }
        local pdfpage   = 0
        local t         = { }
        local n         = 0
        --
        os.remove(texname)
        os.remove(pdfname)
        os.remove(tucname)
        --
        if report_svg then
            report_svg("processing %i svg containers",nofshapes)
            statistics.starttiming(pdfpages)
        end
        --
        -- can be option:
        --
     -- n = n + 1 ; t[n] = "\\nopdfcompression"
        --
        n = n + 1 ; t[n] = "\\starttext"
        n = n + 1 ; t[n] = "\\setupMPpage[alternative=offset,instance=doublefun]"
        --
        for i=1,nofshapes do
            local entry = svgshapes[i]
            local data  = entry.data
            if decompress then
                data = decompress(data) or data
            end
            local specification = {
                data   = xmlconvert(data),
                x      = 0,
                y      = 1000,
                width  = 1000,
                height = 1000,
                noclip = true,
            }
            for index=entry.first,entry.last do
                if not pdfpages[index] then
                    pdfpage = pdfpage + 1
                    pdfpages[index] = pdfpage
                    local pattern = "/svg[@id='glyph" .. index .. "']"
                    n = n + 1 ; t[n] = "\\startMPpage"
                    n = n + 1 ; t[n] = metapost.svgtomp(specification,pattern,true,true) or ""
                    n = n + 1 ; t[n] = "\\stopMPpage"
                end
            end
        end
        n = n + 1 ; t[n] = "\\stoptext"
        io.savedata(texname,concat(t,"\n"))
        runner { filename = texname }
        os.remove(pdftarget)
        file.copy(pdfname,pdftarget)
        if report_svg then
            statistics.stoptiming(pdfpages)
            report_svg("svg conversion time %s",statistics.elapsedseconds(pdfpages))
        end
        os.remove(texname)
        os.remove(pdfname)
        os.remove(tucname)
        return pdfpages
    end

    function metapost.svgshapestomp(svgshapes,report_svg)
        local nofshapes = #svgshapes
        local mpshapes = { }
        if report_svg then
            report_svg("processing %i svg containers",nofshapes)
            statistics.starttiming(mpshapes)
        end
        for i=1,nofshapes do
            local entry = svgshapes[i]
            local data  = entry.data
            if decompress then
                data = decompress(data) or data
            end
            local specification = {
                data   = xmlconvert(data),
                x      = 0,
                y      = 1000,
                width  = 1000,
                height = 1000,
                noclip = true,
            }
            for index=entry.first,entry.last do
                if not mpshapes[index] then
                    local pattern = "/svg[@id='glyph" .. index .. "']"
                    local mpcode  = metapost.svgtomp(specification,pattern,true,true) or ""
                    if mpcode ~= "" and compress then
                        mpcode = compress(mpcode) or mpcode
                    end
                    mpshapes[index] = mpcode
                end
            end
        end
        if report_svg then
            statistics.stoptiming(mpshapes)
            report_svg("svg conversion time %s",statistics.elapsedseconds(mpshapes))
        end
        return mpshapes
    end

    function metapost.svgglyphtomp(fontname,unicode)
        if fontname and unicode then
            local id = fonts.definers.internal { name = fontname }
            if id then
                local tfmdata = fonts.hashes.identifiers[id]
                if tfmdata then
                    local properties = tfmdata.properties
                    local svg        = properties.svg
                    local hash       = svg and svg.hash
                    local timestamp  = svg and svg.timestamp
                    if hash then
                        local svgfile   = containers.read(fonts.handlers.otf.svgcache,hash)
                        local svgshapes = svgfile and svgfile.svgshapes
                        if svgshapes then
                            if type(unicode) == "string" then
                                unicode = utfbyte(unicode)
                            end
                            local chardata = tfmdata.characters[unicode]
                            local index    = chardata and chardata.index
                            if index then
                                for i=1,#svgshapes do
                                    local entry = svgshapes[i]
                                    if index >= entry.first and index <= entry.last then
                                        local data  = entry.data
                                        if data then
                                            local root = xml.convert(gzip.decompress(data) or data)
                                            return metapost.svgtomp (
                                                {
                                                    data   = root,
                                                    x      = 0,
                                                    y      = 1000,
                                                    width  = 1000,
                                                    height = 1000,
                                                    noclip = true,
                                                },
                                                "/svg[@id='glyph" .. index .. "']",
                                                true,
                                                true
                                            )
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

end
