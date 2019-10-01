if not modules then modules = { } end modules ['mlib-svg'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- As usual with these standards, things like a path can be very compact while the rest is
-- very verbose which defeats the point. This is a first attempt. There will be a converter
-- to MP as well as directly to PDF. This module was made for one of the dangerous curves
-- talks at the 2019 CTX meeting. I will do the font when I need it (not that hard).
--
-- There is no real need to boost performance here .. we can always make a fast variant
-- when really needed. I will also do some of the todo's when I run into proper fonts.

-- Written with Anne Clark on speakers as distraction.

-- Todo when I run into an example:
--
-- var(color,color)
-- --color<decimal>
-- currentColor : when i run into an example
-- some more fonts
--
-- Todo: some day
--
-- optimize
-- instances
-- withpen -> pickup
--
-- Todo: when i am motivated
--
-- shading
-- "none" -> false
-- clip = [ auto | rect(llx,lly,urx,ury) ] (in svg)
-- xlink url ... whatever

-- The fact that in the more recent versions of SVG the older text related elements
-- are depricated and not even supposed to be supported, combined with the fact that
-- the text element assumes css styling, demonstrates that there is not so much as a
-- standard. It basically means that whatever technology dominates at some point
-- (probably combined with some libraries that at that point exist) determine what
-- is standard. Anyway, it probably also means that these formats are not that
-- suitable for long term archival purposes. So don't take the next implementation
-- too serious.

-- We can do a direct conversion to PDF but then we also loose the abstraction which
-- in the future will be used.

local type, tonumber = type, tonumber

local P, S, R, C, Ct, Cs, Cc, Cp, Carg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.Cp, lpeg.Carg

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local pi, sin, cos, asin, sind, cosd, tan, abs, sqrt = math.pi, math.sin, math.cos, math.asin, math.sind, math.cosd, math.tan, math.abs, math.sqrt
local concat, setmetatableindex = table.concat, table.setmetatableindex
local gmatch, gsub, find, match, rep = string.gmatch, string.gsub, string.find, string.match, string.rep
local formatters = string.formatters
local extract = bit32.extract

local xmlconvert, xmlcollected, xmlcount, xmlfirst, xmlroot, xmltext = xml.convert, xml.collected, xml.count, xml.first, xml.root, xml.text

metapost       = metapost or { }
local metapost = metapost
local context  = context

local report = logs.reporter("metapost","svg")

local trace  = false
-- local trace  = true

-- todo: also a high res mode
-- todo: optimize (no hurry)

local f_rectangle       = formatters['unitsquare xyscaled (%.3N,%.3N) shifted (%.3N,%.3N)']
local f_rounded         = formatters['roundedsquarexy(%.3N,%.3N,%.3N,%.3N) shifted (%.3N,%.3N)']
local f_ellipse         = formatters['(fullcircle xyscaled (%.3N,%.3N) shifted (%.3N,%.3N))']
local f_circle          = formatters['(fullcircle scaled %.3N shifted (%.3N,%.3N))']
local f_line            = formatters['((%.3N,%.3N)--(%.3N,%.3N))']
local f_fill            = formatters['fill %s(%s--cycle)%s%s%s ;']    -- play safe
local f_fill_cycle_c    = formatters['fill %s(%s..cycle)%s%s%s ;']
local f_fill_cycle_l    = formatters['fill %s(%s--cycle)%s%s%s ;']
local f_eofill          = formatters['eofill %s(%s--cycle)%s%s%s ;']  -- play safe
local f_eofill_cycle_c  = formatters['eofill %s(%s..cycle)%s%s%s ;']
local f_eofill_cycle_l  = formatters['eofill %s(%s--cycle)%s%s%s ;']
local f_nofill          = formatters['nofill %s(%s--cycle)%s ;']      -- play safe
local f_nofill_cycle_c  = formatters['nofill %s(%s..cycle)%s ;']
local f_nofill_cycle_l  = formatters['nofill %s(%s--cycle)%s ;']
local f_draw            = formatters['draw %s(%s)%s%s%s%s%s ;']
local f_nodraw          = formatters['nodraw %s(%s)%s ;']

-- local f_fill            = formatters['F %s(%s--C)%s%s%s ;']  -- play safe
-- local f_fill_cycle_c    = formatters['F %s(%s..C)%s%s%s ;']
-- local f_fill_cycle_l    = formatters['F %s(%s--C)%s%s%s ;']
-- local f_eofill          = formatters['E %s(%s--C)%s%s%s ;']  -- play safe
-- local f_eofill_cycle_c  = formatters['E %s(%s..C)%s%s%s ;']
-- local f_eofill_cycle_l  = formatters['E %s(%s--C)%s%s%s ;']
-- local f_nofill          = formatters['f %s(%s--C)%s ;']      -- play safe
-- local f_nofill_cycle_c  = formatters['f %s(%s..C)%s ;']
-- local f_nofill_cycle_l  = formatters['f %s(%s--C)%s ;']
-- local f_draw            = formatters['D %s(%s)%s%s%s%s%s ;']
-- local f_nodraw          = formatters['d %s(%s)%s ;']

local f_color           = formatters[' withcolor "%s"']
local f_rgb             = formatters[' withcolor (%.3N,%.3N,%.3N)']
local f_rgba            = formatters[' withcolor (%.3N,%.3N,%.3N) withtransparency (1,%3N)']
local f_triplet         = formatters['(%.3N,%.3N,%.3N)']
local f_gray            = formatters[' withcolor %.3N']
local f_opacity         = formatters[' withtransparency (1,%.3N)']
local f_pen             = formatters[' withpen pencircle scaled %.3N']

local f_dashed_n        = formatters[" dashed dashpattern (%s ) "]
local f_dashed_y        = formatters[" dashed dashpattern (%s ) shifted (%.3N,0) "]

local f_moveto          = formatters['(%N,%n)']
local f_curveto_z       = formatters[' controls (%.3N,%.3N) and (%.3N,%.3N) .. (%.3N,%.3N)']
local f_curveto_n       = formatters['.. controls (%.3N,%.3N) and (%.3N,%.3N) .. (%.3N,%.3N)']
local f_lineto_z        = formatters['(%.3N,%.3N)']
local f_lineto_n        = formatters['-- (%.3N,%.3N)']

local f_rotatedaround   = formatters[" ) rotatedaround((%.3N,%.3N),%.3N)"]
local f_rotated         = formatters[" ) rotated(%.3N)"]
local f_shifted         = formatters[" ) shifted(%.3N,%.3N)"]
local f_slanted_x       = formatters[" ) xslanted(%.3N)"]
local f_slanted_y       = formatters[" ) yslanted(%.3N)"]
local f_scaled          = formatters[" ) scaled(%.3N)"]
local f_xyscaled        = formatters[" ) xyscaled(%.3N,%.3N)"]
local f_matrix          = formatters[" ) transformed bymatrix(%.3N,%.3N,%.3N,%.3N,%.3N,%.3N)"]

-- penciled    n     -> withpen pencircle scaled n
-- applied     (...) -> transformed bymatrix (...)
-- withopacity n     -> withtransparency (1,n)

local s_clip_start      = 'draw image ('
local f_clip_stop       = formatters[') ; clip currentpicture to (%s) ;']
local f_eoclip_stop     = formatters[') ; eoclip currentpicture to (%s) ;']

local f_transform_start = formatters["draw %s image ( "]
local f_transform_stop  = formatters[") %s ;"]

local s_offset_start    = "draw image ( "
local f_offset_stop     = formatters[") shifted (%.3N,%.3N) ;"]

local s_scaled_start    = "draw image ( "
local f_scaled_stop     = formatters[") scaled %.3N ;"]

local s_hacked_start    = "draw image ("
local f_hacked_stop     = formatters[") shifted (0,%.3N) scaled %.3N ;"]
-- local f_hacked_stop     = formatters[") scaled %.3N ;"]

local f_viewport_start  = "draw image ("
local f_viewport_stop   = ") ;"
local f_viewport_shift  = formatters["currentpicture := currentpicture shifted (%03N,%03N);"]
local f_viewport_clip   = formatters["clip currentpicture to (unitsquare xyscaled (%03N,%03N));"]

local f_linecap         = formatters["interim linecap := %s ;"]
local f_linejoin        = formatters["interim linejoin := %s ;"]
local f_miterlimit      = formatters["interim miterlimit := %s ;"]

local s_begingroup      = "begingroup;"
local s_endgroup        = "endgroup;"

-- make dedicated macro

local s_shade_linear    = ' withshademethod "linear" '
local s_shade_circular  = ' withshademethod "circular" '
local f_shade_step      = formatters['withshadestep ( withshadefraction %.3N withshadecolors(%s,%s) )']
local f_shade_one       = formatters['withprescript "sh_center_a=%.3N %.3N"']
local f_shade_two       = formatters['withprescript "sh_center_b=%.3N %.3N"']

local f_text_scaled     = formatters['(textext.drt("%s") scaled %.3N shifted (%.3N,%.3N))']
local f_text_normal     = formatters['(textext.drt("%s") shifted (%.3N,%.3N))']

-- We can actually use the svg color definitions from the tex end but maybe a user doesn't
-- want those replace the normal definitions.

local svgcolors = {
    black                = 0x000000,
    navy                 = 0x000080,
    darkblue             = 0x00008B,
    mediumblue           = 0x0000CD,
    blue                 = 0x0000FF,
    darkgreen            = 0x006400,
    green                = 0x008000,
    teal                 = 0x008080,
    darkcyan             = 0x008B8B,
    deepskyblue          = 0x00BFFF,
    darkturquoise        = 0x00CED1,
    mediumspringgreen    = 0x00FA9A,
    lime                 = 0x00FF00,
    springgreen          = 0x00FF7F,
    cyan                 = 0x00FFFF,
    aqua                 = 0x00FFFF,
    midnightblue         = 0x191970,
    dodgerblue           = 0x1E90FF,
    lightseagreen        = 0x20B2AA,
    forestgreen          = 0x228B22,
    seagreen             = 0x2E8B57,
    darkslategray        = 0x2F4F4F,
    darkslategrey        = 0x2F4F4F,
    limegreen            = 0x32CD32,
    mediumseagreen       = 0x3CB371,
    turquoise            = 0x40E0D0,
    royalblue            = 0x4169E1,
    steelblue            = 0x4682B4,
    darkslateblue        = 0x483D8B,
    mediumturquoise      = 0x48D1CC,
    indigo               = 0x4B0082,
    darkolivegreen       = 0x556B2F,
    cadetblue            = 0x5F9EA0,
    cornflowerblue       = 0x6495ED,
    mediumaquamarine     = 0x66CDAA,
    dimgrey              = 0x696969,
    dimgray              = 0x696969,
    slateblue            = 0x6A5ACD,
    olivedrab            = 0x6B8E23,
    slategrey            = 0x708090,
    slategray            = 0x708090,
    lightslategray       = 0x778899,
    lightslategrey       = 0x778899,
    mediumslateblue      = 0x7B68EE,
    lawngreen            = 0x7CFC00,
    chartreuse           = 0x7FFF00,
    aquamarine           = 0x7FFFD4,
    maroon               = 0x800000,
    purple               = 0x800080,
    olive                = 0x808000,
    gray                 = 0x808080,
    grey                 = 0x808080,
    skyblue              = 0x87CEEB,
    lightskyblue         = 0x87CEFA,
    blueviolet           = 0x8A2BE2,
    darkred              = 0x8B0000,
    darkmagenta          = 0x8B008B,
    saddlebrown          = 0x8B4513,
    darkseagreen         = 0x8FBC8F,
    lightgreen           = 0x90EE90,
    mediumpurple         = 0x9370DB,
    darkviolet           = 0x9400D3,
    palegreen            = 0x98FB98,
    darkorchid           = 0x9932CC,
    yellowgreen          = 0x9ACD32,
    sienna               = 0xA0522D,
    brown                = 0xA52A2A,
    darkgray             = 0xA9A9A9,
    darkgrey             = 0xA9A9A9,
    lightblue            = 0xADD8E6,
    greenyellow          = 0xADFF2F,
    paleturquoise        = 0xAFEEEE,
    lightsteelblue       = 0xB0C4DE,
    powderblue           = 0xB0E0E6,
    firebrick            = 0xB22222,
    darkgoldenrod        = 0xB8860B,
    mediumorchid         = 0xBA55D3,
    rosybrown            = 0xBC8F8F,
    darkkhaki            = 0xBDB76B,
    silver               = 0xC0C0C0,
    mediumvioletred      = 0xC71585,
    indianred            = 0xCD5C5C,
    peru                 = 0xCD853F,
    chocolate            = 0xD2691E,
    tan                  = 0xD2B48C,
    lightgray            = 0xD3D3D3,
    lightgrey            = 0xD3D3D3,
    thistle              = 0xD8BFD8,
    orchid               = 0xDA70D6,
    goldenrod            = 0xDAA520,
    palevioletred        = 0xDB7093,
    crimson              = 0xDC143C,
    gainsboro            = 0xDCDCDC,
    plum                 = 0xDDA0DD,
    burlywood            = 0xDEB887,
    lightcyan            = 0xE0FFFF,
    lavender             = 0xE6E6FA,
    darksalmon           = 0xE9967A,
    violet               = 0xEE82EE,
    palegoldenrod        = 0xEEE8AA,
    lightcoral           = 0xF08080,
    khaki                = 0xF0E68C,
    aliceblue            = 0xF0F8FF,
    honeydew             = 0xF0FFF0,
    azure                = 0xF0FFFF,
    sandybrown           = 0xF4A460,
    wheat                = 0xF5DEB3,
    beige                = 0xF5F5DC,
    whitesmoke           = 0xF5F5F5,
    mintcream            = 0xF5FFFA,
    ghostwhite           = 0xF8F8FF,
    salmon               = 0xFA8072,
    antiquewhite         = 0xFAEBD7,
    linen                = 0xFAF0E6,
    lightgoldenrodyellow = 0xFAFAD2,
    oldlace              = 0xFDF5E6,
    red                  = 0xFF0000,
    fuchsia              = 0xFF00FF,
    magenta              = 0xFF00FF,
    deeppink             = 0xFF1493,
    orangered            = 0xFF4500,
    tomato               = 0xFF6347,
    hotpink              = 0xFF69B4,
    coral                = 0xFF7F50,
    darkorange           = 0xFF8C00,
    lightsalmon          = 0xFFA07A,
    orange               = 0xFFA500,
    lightpink            = 0xFFB6C1,
    pink                 = 0xFFC0CB,
    gold                 = 0xFFD700,
    peachpuff            = 0xFFDAB9,
    navajowhite          = 0xFFDEAD,
    moccasin             = 0xFFE4B5,
    bisque               = 0xFFE4C4,
    mistyrose            = 0xFFE4E1,
    blanchedalmond       = 0xFFEBCD,
    papayawhip           = 0xFFEFD5,
    lavenderblush        = 0xFFF0F5,
    seashell             = 0xFFF5EE,
    cornsilk             = 0xFFF8DC,
    lemonchiffon         = 0xFFFACD,
    floralwhite          = 0xFFFAF0,
    snow                 = 0xFFFAFA,
    yellow               = 0xFFFF00,
    lightyellow          = 0xFFFFE0,
    ivory                = 0xFFFFF0,
    white                = 0xFFFFFF,
}

local svgcolor = setmetatableindex(function(t,k)
    -- we delay building all these strings
    local v = svgcolors[k]
    if v then
        v = f_rgb(extract(v,16,8),extract(v,8,8),extract(v,0,8))
    else
        v = false
    end
    t[k] = v
    return v
end)

local p_digit    = lpegpatterns.digit
local p_hexdigit = lpegpatterns.hexdigit
local p_space    = lpegpatterns.whitespace

local p_hexcolor = P("#") * C(p_hexdigit*p_hexdigit)^1 / function(r,g,b)
    r = tonumber(r,16)/255
    if g then
        g = tonumber(g,16)/255
    end
    if b then
        b = tonumber(b,16)/255
    end
    if b then
        return f_rgb(r,g,b)
    else
        return f_gray(r)
    end
end

local p_hexcolor3 = P("#") * C(p_hexdigit*p_hexdigit)^1 / function(r,g,b)
    r =       tonumber(r,16)/255
    g = g and tonumber(g,16)/255 or r
    b = b and tonumber(b,16)/255 or g
    return f_triplet(r,g,b)
end

local function hexcolor(c)
    return lpegmatch(p_hexcolor,c)
end

local function hexcolor3(c)
    return lpegmatch(p_hexcolor3,c)
end

-- gains a little:

-- local hexhash  = setmetatableindex(function(t,k) local v = lpegmatch(p_hexcolor, k) t[k] = v return v end)  -- per file
-- local hexhash3 = setmetatableindex(function(t,k) local v = lpegmatch(p_hexcolor3,k) t[k] = v return v end)  -- per file
--
-- local function hexcolor (c) return hexhash [c] end -- directly do hexhash [c]
-- local function hexcolor3(c) return hexhash3[c] end -- directly do hexhash3[c]

-- Most of the conversion is rather trivial code till I ran into a file with arcs. A bit
-- of searching lead to the a2c javascript function but it has some puzzling thingies
-- (like sin and cos definitions that look like leftovers). Anyway, we can if needed
-- optimize it a bit more. Here does it come from:

-- http://www.w3.org/TR/SVG11/implnote.html#ArcImplementationNotes
-- https://github.com/adobe-webplatform/Snap.svg/blob/b242f49e6798ac297a3dad0dfb03c0893e394464/src/path.js

local d120 = (pi * 120) / 180
local pi2  = 2 * pi

local function a2c(x1, y1, rx, ry, angle, large, sweep, x2, y2, f1, f2, cx, cy)

    local recursive = f1

    if rx == 0 or ry == 0 then
        return { x1, y1, x2, y2, x2, y2 }
    end

    if x1 == x2 and y1 == y2 then
        return { x1, y1, x2, y2, x2, y2 }
    end

    local rad = pi / 180 * angle
    local res = nil

    local cosrad = cos(-rad) -- local cosrad = cosd(angle)
    local sinrad = sin(-rad) -- local sinrad = sind(angle)

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

        if sweep ~= 0 and f1 > f2 then
            f1 = f1 - pi2
        end
        if sweep == 0 and f2 > f1 then
            f2 = f2 - pi2
        end

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

-- incredible: we can find .123.456 => 0.123 0.456 ...

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

local p_command_x  = C(S("Hh"))
local p_command_y  = C(S("Vv"))
local p_command_xy = C(S("CcLlMmQqSsTt"))
local p_command_a  = C(S("Aa"))
local p_command    = C(S("Zz"))

local p_separator  = S("\t\n\r ,")^1
local p_number     = (S("+-")^0 * (p_digit^0 * P(".") * p_digit^1 + p_digit^1 * P(".") + p_digit^1) )

local function convert   (n)   n =   tonumber(n)                                                                           return n     end
local function convert_r (n,u) n =   tonumber(n) if u == true then return percentage_r * n elseif u then return u * n else return n end end
local function convert_x (n,u) n =   tonumber(n) if u == true then return percentage_x * n elseif u then return u * n else return n end end
local function convert_y (n,u) n =   tonumber(n) if u == true then return percentage_y * n elseif u then return u * n else return n end end
local function convert_vx(n,u) n =   tonumber(n) if u == true then return percentage_x * n elseif u then return u * n else return n end end
local function convert_vy(n,u) n = - tonumber(n) if u == true then return percentage_y * n elseif u then return u * n else return n end end

local p_unit      = ( P("p") * S("txc") + P("e") * S("xm") + S("mc") * P("m") + P("in")) / factors
local p_percent   = P("%") * Cc(true)

local c_number_n = C(p_number)
local c_number_u = C(p_number) * (p_unit + p_percent)^-1

local p_number_n  = c_number_n / convert
local p_number_x  = c_number_u / convert_x
local p_number_vx = c_number_u / convert_vx
local p_number_y  = c_number_u / convert_y
local p_number_vy = c_number_u / convert_vy
local p_number_r  = c_number_u / convert_r

-- local p_number    = p_number_r -- maybe no percent here

local function asnumber   (s) return lpegmatch(p_number,   s) end
local function asnumber_r (s) return lpegmatch(p_number_r, s) end
local function asnumber_x (s) return lpegmatch(p_number_x, s) end
local function asnumber_y (s) return lpegmatch(p_number_y, s) end
local function asnumber_vx(s) return lpegmatch(p_number_vx,s) end
local function asnumber_vy(s) return lpegmatch(p_number_vy,s) end

local p_numbersep = p_number_n + p_separator
local p_numbers   = p_separator^0 * P("(") * p_numbersep^0 * p_separator^0 * P(")")
local p_four      = p_numbersep^4

-- local p_path      = Ct((p_command + (p_number_x * p_separator^0 * p_number_y * p_separator^0) + p_separator)^1)

local p_path      = Ct ( (
      p_command_xy * (p_separator^0 * p_number_vx *
                      p_separator^0 * p_number_vy )^1
    + p_command_x  * (p_separator^0 * p_number_vx )^1
    + p_command_y  * (p_separator^0 * p_number_vy )^1
    + p_command_a  * (p_separator^0 * p_number_vx *
                      p_separator^0 * p_number_vy *
                      p_separator^0 * p_number_r  *
                      p_separator^0 * p_number_n  * -- flags
                      p_separator^0 * p_number_n  * -- flags
                      p_separator^0 * p_number_vx *
                      p_separator^0 * p_number_vy )^1
    + p_command
    + p_separator
)^1 )

local p_rgbacolor = P("rgba(") * (C(p_number) + p_separator)^1 * P(")")

local function rgbacolor(s)
    local r, g, b, a = lpegmatch(p_rgbacolor,s)
    if a then
        return f_rgba(r/255,g/255,b/255,a)
    end
end

local function viewbox(v)
    local x, y, w, h = lpegmatch(p_four,v)
    if h then
        return x, y, w, h
    end
end

-- actually we can loop faster because we can go to the last one

local function grabpath(str)
    local p     = lpegmatch(p_path,str)
    local np    = #p
    local t     = { } -- no real saving here if we share
    local n     = 0
    local all   = { entries = np, closed = false, curve = false }
    local a     = 0
    local i     = 0
    local last  = "M"
    local prev  = last
    local kind  = "L"
    local x     = 0
    local y     = 0
    local x1    = 0
    local y1    = 0
    local x2    = 0
    local y2    = 0
    local rx    = 0
    local ry    = 0
    local ar    = 0
    local al    = 0
    local as    = 0
    local ac    = nil
    while i < np do
        i = i + 1
        local pi = p[i]
        if type(pi) ~= "number" then
            last = pi
            i    = i + 1
            pi   = p[i]
        end
        -- most often
      ::restart::
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
                a      = a + 1
                all[a] = concat(t,"",1,n)
                n      = 0
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
            if i == n then
                break
            else
                i = i - 1
            end
            kind = prev
            prev = "Z"
        ::continue::
    end
    if n > 0 then
        a = a + 1 ; all[a] = concat(t,"",1,n) ; n = 0
    end
    if prev == "Z" then
        all.closed = true
    end
    all.curve = (kind == "C" or kind == "A")
    return all
end

local transform  do

    --todo: better lpeg

    local n = 0

    local function rotate(r,x,y)
        if x then
            n = n + 1
            return r and f_rotatedaround(x,-(y or x),-r)
        elseif r then
            n = n + 1
            return f_rotated(-r)
        else
            return ""
        end
    end

    local function translate(x,y)
        if y then
            n = n + 1
            return f_shifted(x,-y)
        elseif x then
            n = n + 1
            return f_shifted(x,0)
        else
            return ""
        end
    end

    local function scale(x,y)
        if y then
            n = n + 1
            return f_xyscaled(x,y)
        elseif x then
            n = n + 1
            return f_scaled(x)
        else
            return ""
        end
    end

    local function skewx(x)
        if x then
            n = n + 1
            return f_slanted_x(math.sind(-x))
        else
            return ""
        end
    end

    local function skewy(y)
        if y then
            n = n + 1
            return f_slanted_y(math.sind(-y))
        else
            return ""
        end
    end

    local function matrix(rx,sx,sy,ry,tx,ty)
        n = n + 1
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

    transform = function(t,image)
        n = 0
        local e = lpegmatch(p_transform,t)
        local b = rep("( ",n)
        if image then
            return f_transform_start(b), f_transform_stop(e)
        else
            return b, e
        end
    end

end

local dashed  do

    -- actually commas are mandate but we're tolerant

    local p_number = p_separator^0/"" * p_number_r
    local p_on     = Cc(" on ")  * p_number
    local p_off    = Cc(" off ") * p_number
    local p_dashed = Cs((p_on * p_off^-1)^1)

    dashed = function(s,o)
        if not find(s,",") then
            -- a bit of a hack:
            s = s .. " " .. s
        end
        return (o and f_dashed_y or f_dashed_n)(lpegmatch(p_dashed,s),o)
    end

end

do

    local defaults = {
        x  = 0, x1 = 0, x2 = 0, cx = 0, rx = 0,
        y  = 0, y1 = 0, y2 = 0, cy = 0, ry = 0,
        r  = 0,

        width   = 0,
        height  = 0,

        stroke  = "none",
        fill    = "black",
        opacity = "none",

        ["stroke-width"]      = 1,
        ["stroke-linecap"]    = "none",
        ["stroke-linejoin"]   = "none",
        ["stroke-dasharray"]  = "none",
        ["stroke-dashoffset"] = "none",
        ["stroke-miterlimit"] = "none",
        ["stroke-opacity"]    = "none",

        ["fill-opacity"]      = "none",
     -- ["fill-rule"]         = "nonzero",
     -- ["clip-rule"]         = "nonzero",
    }

    local handlers    = { }
    local process     = false
    local root        = false
    local result      = false
    local r           = false
    local definitions = false
    local styles      = false
    local bodyfont    = false

    -- todo: check use ... and make definitions[id] self resolving

    local function locate(id)
        local ref = gsub(id,"^url%(#(.-)%)$","%1")
        local ref = gsub(ref,"^#","")
        local res = xmlfirst(root,"**[@id='"..ref.."']")
        if res then
            definitions[id] = res
            return res
        else
            -- warning
        end
    end

    local function clippath(id,a)
        local spec = definitions[id] or locate(id)
        if spec then
            local kind = spec.tg
            if kind == "clipPath" then
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
                                        p.evenodd = sa["clip-rule"] == "evenodd" or a["clip-rule"] == "evenodd"
                                        return p
                                    else
                                        goto done
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
                            p.evenodd = ca["clip-rule"] == "evenodd" or a["clip-rule"] == "evenodd"
                            return p
                        else
                            goto done
                        end
                    else
                        -- inherit?
                    end
                end
              ::done::
            else
                report("unknown clip %a",id)
            end
        end
    end

    local function gradient(id)
        local spec = definitions[id]
        if spec then
            local kind  = spec.tg
            local shade = nil
            local n     = 1
            local a     = spec.at
            if kind == "linearGradient" then
                shade = { s_shade_linear }
                --
                local x1 = a.x1
                local y1 = a.y1
                local x2 = a.x2
                local y2 = a.y2
                if x1 and y1 then
                    n = n + 1 shade[n] = f_shade_one(asnumber_vx(x1),asnumber_vy(y1))
                end
                if x2 and y2 then
                    n = n + 1 shade[n] = f_shade_one(asnumber_vx(x2),asnumber_vy(y2))
                end
                --
            elseif kind == "radialGradient" then
                shade = { s_shade_circular }
                --
                local cx = a.cx -- x center
                local cy = a.cy -- y center
                local r  = a.r  -- radius
                local fx = a.fx -- focal points
                local fy = a.fy -- focal points
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
            for c in xmlcollected(spec,"/stop") do
                local a       = c.at
                local offset  = a.offset
                local colorb  = a["stop-color"]
                local opacity = a["stop-opacity"]

                colorb = colorb and (hexcolor3(colorb) or svgcolor[colorb] or colorb)
                colora = colora or colorb

                -- what if no percentage

                local fraction = offset and asnumber_r(offset)

                if not fraction then
                 -- offset = tonumber(offset)
                    -- for now
                    fraction = xmlcount(spec,"/stop")/100
                end

                n = n + 1 shade[n] = f_shade_step(fraction,colora,colorb)

                prevcolor = color
            end
            return concat(shade)
        end
    end

    local function drawproperties(stroke,a)
        local w = a["stroke-width"]
        if w then
            w = f_pen(asnumber_r(w))
        else
            w = ""
        end
        local d = a["stroke-dasharray"]
        if d ~= "none" then
            local o = a["stroke-dashoffset"]
            if o ~= "none" then
                o = asnumber_r(o)
            else
                o = false
            end
            d = dashed(d,o)
        else
            d = ""
        end
        local c = hexcolor(stroke)
        if not c then
            c = rgbacolor(stroke)
            if not c then
                c = f_color(svgcolor[stroke] or stroke)
            end
        end
        local o = a["stroke-opacity"] or a.opacity
        if o ~= "none" then
            o = asnumber_r(o)
            if o and o ~= 1 then
                o = f_opacity(o)
            else
                o = ""
            end
        else
            o = ""
        end
        return w, d, c, o
    end

    local function fillproperties(fill,a)
        local c = gradient(fill)
        if not c then
            c = hexcolor(fill)
            if not c then
                c = f_color(svgcolor[fill] or fill)
            end
        end
        local o = a["fill-opacity"] or a.opacity
        if o == "none" then
            o = asnumber_r(o)
            if o and o ~= 1 then
                o = f_opacity(asnumber_r(o))
            else
                o = ""
            end
        else
            o = ""
        end
        return c, o
    end

    -- todo: clip = [ auto | rect(llx,lly,urx,ury) ]

    local function offset(a)
        local x = a.x
        local y = a.y
        if x then x = asnumber_vx(x) end
        if y then y = asnumber_vy(y) end
        if not x then x = 0 end
        if not y then y = 0 end
        if x ~= 0 or y ~= 0 then
            r = r + 1 ; result[r] = s_offset_start
            return function()
                r = r + 1 ; result[r] = f_offset_stop(x,-y)
            end
        end
    end

    local function viewport(x,y,w,h,noclip)
        r = r + 1 ; result[r] = f_viewport_start
        return function()
            if x ~= 0 or y ~= 0 then
                r = r + 1 ; result[r] = f_viewport_shift(-x,y)
            end
            if not noclip then
                r = r + 1 ; result[r] = f_viewport_clip(w,-h)
            end
            r = r + 1 ; result[r] = f_viewport_stop
        end
    end

    function handlers.defs(c,top)
        for c in xmlcollected(c,"/*") do
            local a  = c.at
            local id = a.id
         -- setmetatableindex(a,top)
            if id then
                definitions["#"     .. id       ] = c
                definitions["url(#" .. id .. ")"] = c
            end
        end
    end

    function handlers.use(c,top)
        local a  = setmetatableindex(c.at,top)
        local id = a["xlink:href"] -- better a rawget
        if id then
            local d = definitions[id]
            if d then
                local h = handlers[d.tg]
                if h then
                    h(d,a)
                end
            else
                local res = locate(id)
                if res then
                    local wrapup = offset(a)
                    process(res,"/*",top)
                    if wrapup then
                        wrapup()
                    end
                else
                    report("unknown definition %a",id)
                end
            end
        end
    end

    local linecaps  = { butt  = "butt",    square = "squared", round = "rounded" }
    local linejoins = { miter = "mitered", bevel  = "beveled", round = "rounded" }

    local function stoplineproperties()
        r = r + 1 result[r] = s_endgroup
    end

    local function startlineproperties(a)
        local cap   = a["stroke-linecap"]
        local join  = a["stroke-linejoin"]
        local limit = a["stroke-miterlimit"]
        cap   = cap   ~= "none" and linecaps [cap]  or false
        join  = join  ~= "none" and linejoins[join] or false
        limit = limit ~= "none" and asnumber_r(limit) or false
        if cap or join or limit then
            r = r + 1 result[r] = s_begingroup
            if cap then
                r = r + 1 result[r] = f_linecap(cap)
            end
            if join then
                r = r + 1 result[r] = f_linejoin(join)
            end
            if limit then
                r = r + 1 result[r] = f_miterlimit(limit)
            end
            return stoplineproperties
        end
    end

    local function flush(a,shape,nofill)
        local fill   = not nofill and a.fill
        local stroke = a.stroke
        local cpath  = a["clip-path"]
        local trans  = a.transform
        local b, e   = "", ""
        if cpath then
            cpath = clippath(cpath,a)
        end
        if cpath then
            r = r + 1 result[r] = s_clip_start
        end
        if trans then
            b, e = transform(trans)
        end
        if fill and fill ~= "none" then
            r = r + 1 result[r] = (a["fill-rule"] == "evenodd" and f_eofill or f_fill)(b,shape,e,fillproperties(fill,a))
        end
        if stroke and stroke ~= "none" and stroke ~= 0 then
            local wrapup = startlineproperties(a)
            r = r + 1 result[r] = f_draw(b,shape,e,drawproperties(stroke,a))
            if wrapup then
                wrapup()
            end
        end
        if cpath then
            r = r + 1 result[r] = (cpath.evenodd and f_eoclip_stop or f_clip_stop)(cpath[1])
        end
    end

    -- todo: strokes in:

    local function flushpath(a,shape)
        local fill   = a.fill
        local stroke = a.stroke
        local cpath  = a["clip-path"]
        local trans  = a.transform
        local b, e   = "", ""
        if cpath then
            cpath = definitions[cpath]
        end
        if cpath then
            r = r + 1 result[r] = s_clip_start
        end
        -- todo: image (nicer for transform too)
        if trans then
            b, e = transform(trans)
        end
        if fill and fill ~= "none" then
            local n = #shape
            for i=1,n do
                r = r + 1
                if i == n then
                    local f = a["fill-rule"] == "evenodd"
                    if shape.closed then
                        f = f and f_eofill or f_fill
                    elseif shape.curve then
                        f = f and f_eofill_cycle_c or f_fill_cycle_c
                    else
                        f = f and f_eofill_cycle_l or f_fill_cycle_l
                    end
                    result[r] = f(b,shape[i],e,fillproperties(fill,a))
                else
                    result[r] = f_nofill(b,shape[i],e)
                end
            end
        end
        if stroke and stroke ~= "none" and stroke ~= 0 then
            local wrapup = startlineproperties(a)
            local n = #shape
            for i=1,n do
                r = r + 1
                if i == n then
                    result[r] = f_draw(b,shape[i],e,drawproperties(stroke,a))
                else
                    result[r] = f_nodraw(b,shape[i],e)
                end
            end
            if wrapup then
                wrapup()
            end
        end
        if cpath then
            r = r + 1 result[r] = f_clip_stop(cpath[1])
        end
    end

    function handlers.line(c,top)
        local a  = setmetatableindex(c.at,top)
        local x1 = asnumber_vx(a.x1)
        local y1 = asnumber_vy(a.y1)
        local x2 = asnumber_vx(a.x2)
        local y2 = asnumber_vy(a.y2)
        if trace then
            report("line: x1 %.3N, y1 %.3N, x2 %.3N, x3 %.3N",x1,y1,x2,y2)
        end
        flush(a,f_line(x1,y1,x2,y2),true)
    end

    function handlers.rect(c,top)
        local a = setmetatableindex(c.at,top)
        local w = asnumber_x(a.width)
        local h = asnumber_y(a.height)
        local x = asnumber_vx(a.x)
        local y = asnumber_vy(a.y) - h
        local rx = a.rx
        local ry = a.ry
        if rx == 0 then rx = false end -- maybe no default 0
        if ry == 0 then ry = false end -- maybe no default 0
        if rx or ry then
            rx = asnumber_x(rx or ry)
            ry = asnumber_y(ry or rx)
            if trace then
                report("rect: x %.3N, y %.3N, w %.3N, h %.3N, rx %.3N, ry %.3N",x,y,w,h,rx,ry)
            end
            flush(a,f_rounded(w,h,rx,ry,x,y))
        else
            if trace then
                report("rect: x %.3N, y %.3N, w %.3N, h %.3N",x,y,w,h)
            end
            flush(a,f_rectangle(w,h,x,y))
        end
    end

    function handlers.ellipse(c,top)
        local a  = setmetatableindex(c.at,top)
        local x  = asnumber_vx(a.cx)
        local y  = asnumber_vy(a.cy)
        local rx = asnumber_x (a.rx)
        local ry = asnumber_y (a.ry)
        if trace then
            report("ellipse: x %.3N, y %.3N, rx %.3N, ry %.3N",x,y,rx,ry)
        end
        flush(a,f_ellipse(2*rx,2*ry,x,y))
    end

    function handlers.circle(c,top)
        local a = setmetatableindex(c.at,top)
        local x = asnumber_vx(a.cx)
        local y = asnumber_vy(a.cy)
        local r = asnumber_r (a.r)
        if trace then
            report("circle: x %.3N, y %.3N, r %.3N",x,y,r)
        end
        flush(a,f_circle(2*r,x,y))
    end

    function handlers.path(c,top)
        local a = setmetatableindex(c.at,top)
        local d = a.d
        if d then
            local p = grabpath(d)
            if trace then
                report("path: %i entries, %sclosed",p.entries,p.closed and "" or "not ")
            end
            flushpath(a,p)
        end
    end

    do

        local p_pair     = p_separator^0 * p_number_vx * p_separator^0 * p_number_vy
        local p_pair_z   = p_pair / f_lineto_z
        local p_pair_n   = p_pair / f_lineto_n
        local p_open     = Cc("(")
        local p_close    = Carg(1) * P(true) / function(s) return s end
        local p_polyline = Cs(p_open * p_pair_z * p_pair_n^0 * p_close)

        function handlers.polyline(c,top)
            local a = setmetatableindex(c.at,top)
            local p = a.points
            if p then
                flush(a,lpegmatch(p_polyline,p,1,")"),true)
            end
        end

        function handlers.polygon(c,top)
            local a = setmetatableindex(c.at,top)
            local p = a.points
            if p then
                flush(a,lpegmatch(p_polyline,p,1,"--cycle)"))
            end
        end

    end

    function handlers.g(c,top)
        local a = c.at
        setmetatableindex(a,top)
        process(c,"/*",a)
    end

    function handlers.symbol(c,top)
        report("todo: %s","symbol")
    end

    -- We only need to filter classes .. I will complete this when I really need
    -- it. Not hard to do but kind of boring.

    local p_class = P(".") * C((R("az","AZ","09","__","--")^1))
    local p_spec  = P("{") * C((1-P("}"))^1) * P("}")

    local p_grab = ((Carg(1) * p_class * p_space^0 * p_spec / function(t,k,v) t[k] = v end) + p_space^1 + P(1))^1

    function handlers.style(c,top)
        local s = xmltext(c)
        lpegmatch(p_grab,s,1,styles)
        for k, v in next, styles do
            -- todo: lpeg
            local t = { }
            for k, v in gmatch(v,"%s*([^:]+):%s*([^;]+);") do
                if k == "font" then
                    v = xml.css.fontspecification(v)
                end
                t[k] = v
            end
            styles[k] = t
        end
        bodyfont = tex.getdimen("bodyfontsize") / 65536
    end

    -- this will never really work out

    function handlers.text(c,top)
        local a     = c.at
        local x     = asnumber_vx(a.x)
        local y     = asnumber_vy(a.y)
        local text  = xmltext(c)
        local size  = false
        local fill  = a.fill
        -- escape text or keep it at the tex end
        local class = a.class
        if class then
            local style = styles[class]
            if style and next(style) then
                local font = style.font
                local s_family = font and font.family
                local s_style  = font and font.style
                local s_weight = font and font.weight
                local s_size   = font and font.size
                if s_size then
                    local f = factors[s_size[2]]
                    if f then
                        size = f * s_size[1]
                    end
                end
                -- todo: family: serif | sans-serif | monospace : use mapping
                if s_family then
                    if s_family == "serif" then
                        text = "\\rm " .. text
                    elseif s_family == "sans-serif" then
                        text = "\\ss " .. text
                    else
                        text = "\\tt " .. text
                    end
                end
                if s_style or s_weight then
                    text = formatters['\\style[%s%s]{%s}'](s_weight or "",s_style or "",text)
                end
                fill = style.fill or fill
            end
        end
        if size then
            -- bodyfontsize
            size = size/bodyfont
            text = f_text_scaled(text,size,x,y)
        else
            text = f_text_normal(text,x,y)
        end
        if fill and fill ~= "none" then
            text = f_draw("",text,"",fillproperties(fill,a))
        else
            text = f_draw("",text,"","","","","")
        end
        if trace then
            report("text: x %.3N, y %.3N, text %s",x,y,text)
        end
        r = r + 1 ; result[r] = text
    end

    function handlers.svg(c,top,x,y,w,h,noclip,notransform,normalize)
        local a = setmetatableindex(c.at,top)
        local v = a.viewBox
        local t = a.transform
        local wrapupoffset
        local wrapupviewport
        local btransform
        local etransform
        local bhacked
        local ehacked
        local wd = w
     -- local ex, em
        local xpct, ypct, rpct
        if notransform then
--             t = nil
        end
        if trace then
            report("view: %s, xpct %.3N, ypct %.3N","before",percentage_x,percentage_y)
        end
        if v then
            x, y, w, h = viewbox(v)
            if trace then
                report("viewbox: x %.3N, y %.3N, width %.3N, height %.3N",x,y,w,h)
            end
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
                report("view: %s, xpct %.3N, ypct %.3N","inside",percentage_x,percentage_y)
            end
            wrapupviewport = viewport(x,y,w,h,noclip)
        end
        -- todo: combine transform and offset here
        if t then
            btransform, etransform = transform(t,true)
        end
        -- some fonts need this (bad transforms + viewbox)
        if v and normalize and w and wd and w ~= wd and w > 0 and wd > 0 then
            bhacked = s_hacked_start
            ehacked = f_hacked_stop(y or 0,wd/w)
        end
        if btransform then
            r = r + 1 ; result[r] = btransform
        end
        if bhacked then
            r = r + 1 ; result[r] = bhacked
        end
        wrapupoffset = offset(a)
        process(c,"/*",top or defaults)
        if wrapupoffset then
            wrapupoffset()
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
            report("view: %s, xpct %.3N, ypct %.3N","after",percentage_x,percentage_y)
        end
    end

    process = function(x,p,top)
        for c in xmlcollected(x,p) do
            local h = handlers[c.tg]
            if h then
                h(c,top)
            end
        end
    end

    function metapost.svgtomp(specification,pattern,notransform,normalize)
        local mps = ""
        local svg = specification.data
        if type(svg) == "string" then
            svg = xmlconvert(svg)
        end
        if svg then
            local c = xmlfirst(svg,pattern or "/svg")
            if c then
                root, result, r, definitions, styles, bodyfont = svg, { }, 0, { }, { }, 12
             -- print("default",x,y,w,h)
                handlers.svg (
                    c,
                    nil,
                    specification.x,
                    specification.y,
                    specification.width,
                    specification.height,
                    specification.noclip,
                    notransform,
                    normalize
                )
                mps = concat(result," ")
                root, result, r, definitions, styles, bodyfont = false, false, false, false, false, false
            else
                report("missing svg root element")
            end
        else
            report("bad svg blob")
        end
        return mps
    end

end

-- These helpers might move to their own module .. some day ...

function metapost.showsvgpage(data)
    local dd = data.data
    if type(dd) == "table" then
        local comment = dd.comment
        local offset  = dd.pageoffset
        for i=1,#dd do
            local d = setmetatableindex( {
                data       = dd[i],
                comment    = comment and i or false,
                pageoffset = offset or nil,
            }, data)
            metapost.showsvgpage(d)
        end
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

function metapost.svgtopdf(data,...)
    local mps = metapost.svgtomp(data,...)
    if mps then
        local pdf = metapost.simple("metafun",mps,true) -- todo: special instance, only basics needed
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
        n = n + 1 ; t[n] = "\\enabledirectives[pdf.stripzeros,metapost.stripzeros]"
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
                data = decompress(data,128*1024) or data
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
                data = decompress(data,128*1024) or data
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
                                unicode = utf.byte(unicode)
                            end
                            local chardata = tfmdata.characters[unicode]
                            local index    = chardata and chardata.index
                            if index then
                                for i=1,#svgshapes do
                                    local entry = svgshapes[i]
                                    if index >= entry.first and index <= entry.last then
                                        local data  = entry.data
                                        if data then
                                            local root = xml.convert(gzip.decompress(data,128*1024) or data)
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
